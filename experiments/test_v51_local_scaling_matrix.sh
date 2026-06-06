#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SCALING_DIR="$RESULTS_DIR/v51_local_scaling_matrix"
SUMMARY_CSV="$RESULTS_DIR/v51_local_scaling_matrix_summary.csv"
DECISION_CSV="$RESULTS_DIR/v51_local_scaling_matrix_decision.csv"

"$ROOT_DIR/scripts/run_local_scaling_matrix.sh" "$ROOT_DIR" >/dev/null

expect_summary_value() {
  local field="$1"
  local expected="$2"
  awk -F, -v field="$field" -v expected="$expected" '
    function die(text, code) { print text > "/dev/stderr"; exit code }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing local scaling summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die("local scaling " field " expected " expected " got " $idx[field], 3)
    }
    END { if (rows != 1) die("expected one local scaling summary row", 4) }
  ' "$SUMMARY_CSV"
}

expect_decision_status() {
  local gate="$1"
  local expected="$2"
  awk -F, -v gate="$gate" -v expected="$expected" '
    function die(text, code) { print text > "/dev/stderr"; exit code }
    NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
    $idx["gate"] == gate {
      found = 1
      if ($idx["status"] != expected) die("local scaling decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END { if (!found) die("missing local scaling decision gate: " gate, 6) }
  ' "$DECISION_CSV"
}

expect_summary_value "v51_local_scaling_matrix_ready" "1"
expect_summary_value "store_size_curve_rows" "7"
expect_summary_value "topk_curve_rows" "6"
expect_summary_value "cache_budget_curve_rows" "5"
expect_summary_value "routehint_budget_curve_rows" "5"
expect_summary_value "query_count_curve_rows" "4"
expect_summary_value "active_bytes_rows" "27"
expect_summary_value "latency_breakdown_rows" "27"
expect_summary_value "axes_one_at_time" "1"
expect_summary_value "no_oracle" "1"
expect_summary_value "no_raw_input_extractor" "1"
expect_summary_value "route_memory_lineage" "1"
expect_summary_value "raw_prompt_context_bytes" "0"
expect_summary_value "real_release_package_ready" "0"
expect_summary_value "gpu_speedup_claim" "deferred"

expect_decision_status "v51-local-scaling-matrix" "pass"
expect_decision_status "store-size-curve" "pass"
expect_decision_status "topk-curve" "pass"
expect_decision_status "cache-budget-curve" "pass"
expect_decision_status "routehint-budget-curve" "pass"
expect_decision_status "query-count-curve" "pass"
expect_decision_status "no-oracle-no-extractor" "pass"
expect_decision_status "real-release-package" "blocked"
expect_decision_status "gpu-speedup-claim" "blocked"

for file in \
  scaling_summary.md \
  store_size_curve.csv \
  topk_curve.csv \
  cache_budget_curve.csv \
  routehint_budget_curve.csv \
  query_count_curve.csv \
  active_bytes_per_query.csv \
  latency_breakdown.csv \
  measured_source_probe.csv \
  resource_envelope.json \
  claim_boundary.md \
  source_manifest.csv \
  sha256_manifest.csv
do
  if [[ ! -s "$SCALING_DIR/$file" ]]; then
    echo "missing local scaling artifact: $file" >&2
    exit 20
  fi
done

python3 - "$SCALING_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

scaling_dir = Path(sys.argv[1])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def rows(rel):
    with (scaling_dir / rel).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

sha_rows = {row["path"]: row["sha256"] for row in rows("sha256_manifest.csv")}
for rel in [
    "scaling_summary.md",
    "store_size_curve.csv",
    "topk_curve.csv",
    "cache_budget_curve.csv",
    "routehint_budget_curve.csv",
    "query_count_curve.csv",
    "active_bytes_per_query.csv",
    "latency_breakdown.csv",
    "resource_envelope.json",
    "claim_boundary.md",
]:
    if sha_rows.get(rel) != sha256(scaling_dir / rel):
        raise SystemExit(f"sha256 manifest mismatch for {rel}")

store_rows = rows("store_size_curve.csv")
topk_rows = rows("topk_curve.csv")
hint_rows = rows("routehint_budget_curve.csv")
active_rows = rows("active_bytes_per_query.csv")
probe_rows = rows("measured_source_probe.csv")
if len(store_rows) != 7 or len(topk_rows) != 6 or len(hint_rows) != 5 or len(active_rows) != 27 or len(probe_rows) != 1:
    raise SystemExit("local scaling row count mismatch")

store_active = [int(row["active_bytes_per_query"]) for row in store_rows]
if store_active[-1] <= store_active[0]:
    raise SystemExit("store-size active bytes should increase across the curve")
if store_active[-1] >= int(store_rows[-1]["store_size_bytes"]):
    raise SystemExit("active bytes should remain far below store size")

topk_active = [int(row["active_bytes_per_query"]) for row in topk_rows]
if topk_active != sorted(topk_active):
    raise SystemExit("top-k active bytes should be monotonic")

hint_wrong = [float(row["wrong_answer_rate_proxy"]) for row in hint_rows]
if hint_wrong[-1] > hint_wrong[0]:
    raise SystemExit("RouteHint budget should not worsen the proxy wrong-answer curve")

resource = json.loads((scaling_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if resource.get("resource_envelope_ready") != 1 or resource.get("external_network_used") != 0:
    raise SystemExit("resource envelope readiness mismatch")
if resource.get("raw_prompt_context_bytes") != 0 or resource.get("gpu_speedup_claim") != "deferred":
    raise SystemExit("resource envelope claim boundary mismatch")

boundary = (scaling_dir / "claim_boundary.md").read_text(encoding="utf-8")
for snippet in ["GPU acceleration proven", "Transformer replacement", "release-ready product"]:
    if snippet not in boundary:
        raise SystemExit(f"claim boundary missing {snippet}")
PY

echo "v51 local scaling matrix smoke passed"
