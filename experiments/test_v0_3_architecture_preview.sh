#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREVIEW_DIR="$RESULTS_DIR/v0_3_architecture_preview"
SUMMARY_CSV="$RESULTS_DIR/v0_3_architecture_preview_summary.csv"
DECISION_CSV="$RESULTS_DIR/v0_3_architecture_preview_decision.csv"

"$ROOT_DIR/experiments/run_v0_3_architecture_preview.sh" >/dev/null

expect_summary_value() {
  local field="$1"
  local expected="$2"
  awk -F, -v field="$field" -v expected="$expected" '
    function die(text, code) { print text > "/dev/stderr"; exit code }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v0.3 summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die("v0.3 " field " expected " expected " got " $idx[field], 3)
    }
    END { if (rows != 1) die("expected one v0.3 summary row", 4) }
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
      if ($idx["status"] != expected) die("v0.3 decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END { if (!found) die("missing v0.3 decision gate: " gate, 6) }
  ' "$DECISION_CSV"
}

expect_summary_value "v0_3_architecture_preview_ready" "1"
expect_summary_value "one_command_repo_audit_ready" "1"
expect_summary_value "baseline_war_ready" "1"
expect_summary_value "routehint_generator_mainline_ready" "1"
expect_summary_value "local_codebase_intelligence_box_ready" "1"
expect_summary_value "audit_report_ready" "1"
expect_summary_value "reproduce_ready" "1"
expect_summary_value "baseline_rows" "8"
expect_summary_value "raw_prompt_context_bytes" "0"
expect_summary_value "attention_blocks" "0"
expect_summary_value "transformer_blocks" "0"
expect_summary_value "oracle_prediction_used" "0"
expect_summary_value "raw_input_extractor_used" "0"
expect_summary_value "real_release_package_ready" "0"
expect_summary_value "gpu_speedup_claim" "deferred"

expect_decision_status "v0.3-architecture-preview" "pass"
expect_decision_status "baseline-war" "pass"
expect_decision_status "audit-my-repo-ux" "pass"
expect_decision_status "routehint-generator-mainline" "pass"
expect_decision_status "no-raw-prompt-stuffing" "pass"
expect_decision_status "no-attention-transformer" "pass"
expect_decision_status "real-release-package" "blocked"
expect_decision_status "gpu-speedup-claim" "blocked"

for file in \
  README_RESULT.md \
  AUDIT_REPORT.md \
  BASELINE_COMPARISON.md \
  LOCAL_SCALING_SUMMARY.md \
  ARCHITECTURE_TRACE.md \
  baseline_summary.md \
  baseline_metrics.csv \
  per_query_comparison.jsonl \
  routehint_vs_rag.csv \
  wrong_answer_guard_rows.csv \
  unsupported_claim_rows.csv \
  baseline_claim_boundary.md \
  prediction_lineage.jsonl \
  compact_route_hint_rows.csv \
  grounded_generation_rows.csv \
  citation_spans.jsonl \
  abstain_rows.csv \
  resource_envelope.json \
  reproduce.sh \
  sha256sums.txt
do
  if [[ ! -s "$PREVIEW_DIR/$file" ]]; then
    echo "missing v0.3 architecture preview artifact: $file" >&2
    exit 20
  fi
done

python3 - "$PREVIEW_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

preview_dir = Path(sys.argv[1])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

manifest = {}
with (preview_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            digest, rel = line.strip().split(None, 1)
            manifest[rel] = digest

for rel in [
    "AUDIT_REPORT.md",
    "ARCHITECTURE_TRACE.md",
    "baseline_metrics.csv",
    "compact_route_hint_rows.csv",
    "grounded_generation_rows.csv",
    "resource_envelope.json",
]:
    if manifest.get(rel) != sha256(preview_dir / rel):
        raise SystemExit(f"sha256 manifest mismatch: {rel}")

with (preview_dir / "compact_route_hint_rows.csv").open(newline="", encoding="utf-8") as handle:
    routehint_rows = list(csv.DictReader(handle))
with (preview_dir / "grounded_generation_rows.csv").open(newline="", encoding="utf-8") as handle:
    generation_rows = list(csv.DictReader(handle))
with (preview_dir / "baseline_metrics.csv").open(newline="", encoding="utf-8") as handle:
    baseline_rows = list(csv.DictReader(handle))

if not routehint_rows or not generation_rows or not baseline_rows:
    raise SystemExit("preview rows should not be empty")
if len(routehint_rows) != len(generation_rows):
    raise SystemExit("RouteHint rows should match generation rows")
if any(row["raw_context_appended"] != "0" or row["proposal_hint_used"] != "1" for row in routehint_rows):
    raise SystemExit("RouteHint rows should avoid raw context and use proposal hints")
if any(row["attention_blocks"] != "0" or row["transformer_blocks"] != "0" or row["raw_prompt_context_bytes"] != "0" for row in generation_rows):
    raise SystemExit("generation rows should stay non-attention and no raw prompt stuffing")
baseline_ids = {row["baseline_id"] for row in baseline_rows}
required = {
    "ripgrep_literal",
    "bm25_lexical",
    "small_rag_boundary",
    "tiny_generator_only",
    "route_memory_retrieval_only",
    "route_memory_exact",
    "route_memory_compact_routehint",
    "route_memory_scorer_offline_policy",
}
if not required.issubset(baseline_ids):
    raise SystemExit(f"baseline id set missing required rows: {required - baseline_ids}")
if len(baseline_rows) != 8:
    raise SystemExit(f"expected 8 preview baseline rows, got {len(baseline_rows)}")
by_baseline = {row["baseline_id"]: row for row in baseline_rows}
if by_baseline["small_rag_boundary"]["raw_prompt_context_bytes"] != "nonzero-or-unbounded":
    raise SystemExit("small RAG boundary should document nonzero/unbounded raw prompt context")
for baseline_id in ["route_memory_exact", "route_memory_compact_routehint", "route_memory_scorer_offline_policy"]:
    row = by_baseline[baseline_id]
    if row["route_memory_store_used"] != "1" or row["citation_audit_trail_required"] != "1" or row["abstain_required"] != "1":
        raise SystemExit(f"RouteMemory preview baseline missing evidence-bound controls: {baseline_id}")
if by_baseline["route_memory_compact_routehint"]["compact_routehint_used"] != "1" or by_baseline["route_memory_compact_routehint"]["tiny_non_attention_generator_used"] != "1":
    raise SystemExit("RouteHint preview baseline should use compact RouteHint and tiny generator")

trace = (preview_dir / "ARCHITECTURE_TRACE.md").read_text(encoding="utf-8")
for snippet in [
    "RouteMemory evidence -> compact RouteHint",
    "raw_prompt_context_bytes=0",
    "attention_blocks=0",
    "transformer_blocks=0",
]:
    if snippet not in trace:
        raise SystemExit(f"architecture trace missing {snippet}")

boundary = (preview_dir / "baseline_claim_boundary.md").read_text(encoding="utf-8")
for snippet in ["Transformer replacement", "production release", "GPU acceleration proven"]:
    if snippet not in boundary:
        raise SystemExit(f"claim boundary missing {snippet}")

resource = json.loads((preview_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if resource.get("external_network_used") != 0 or resource.get("raw_prompt_context_bytes") != 0:
    raise SystemExit("resource envelope boundary mismatch")
PY

echo "v0.3 architecture preview smoke passed"
