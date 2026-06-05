#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v14c_baseline_comparison_summary.csv"
DECISION_CSV="$RESULTS_DIR/v14c_baseline_comparison_decision.csv"
RUN_DIR="$RESULTS_DIR/v14c_baseline_comparison_runs/comparison_001"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v14-c summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v14-c summary row", 4)
    }
  ' "$summary_csv"
}

expect_decision_status() {
  local decision_csv="$1"
  local gate="$2"
  local expected="$3"

  awk -F, -v gate="$gate" -v expected="$expected" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    $idx["gate"] == gate {
      found = 1
      if ($idx["status"] != expected) die("v14-c decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v14-c decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

"$ROOT_DIR/experiments/run_v14c_baseline_comparison.sh" >/dev/null

expect_summary_value "$SUMMARY_CSV" "dataset_rows" "50" "v14-c dataset rows"
expect_summary_value "$SUMMARY_CSV" "prediction_lineage_ready" "1" "v14-c lineage inherited"
expect_summary_value "$SUMMARY_CSV" "shortcut_negative_suite_ready" "1" "v14-c negative suite inherited"
expect_summary_value "$SUMMARY_CSV" "generator_hint_nlg_ready" "1" "v14-c generator inherited"
expect_summary_value "$SUMMARY_CSV" "resource_envelope_ready" "1" "v14-c resource inherited"
expect_summary_value "$SUMMARY_CSV" "baseline_comparison_ready" "1" "v14-c baseline comparison"
expect_summary_value "$SUMMARY_CSV" "baseline_rows" "6" "v14-c baseline rows"
expect_summary_value "$SUMMARY_CSV" "baseline_negative_case_rows" "66" "v14-c baseline negative rows"
expect_summary_value "$SUMMARY_CSV" "baseline_latency_rows" "6" "v14-c baseline latency rows"
expect_summary_value "$SUMMARY_CSV" "baseline_promotion_guard_rows" "6" "v14-c baseline promotion guard rows"
expect_summary_value "$SUMMARY_CSV" "route_memory_safety_dominates_baselines" "1" "v14-c RouteMemory safety dominance"
expect_summary_value "$SUMMARY_CSV" "input_extractor_baseline_only" "1" "v14-c extractor baseline only"
expect_summary_value "$SUMMARY_CSV" "baseline_promotion_guard_ready" "1" "v14-c promotion guard"
expect_summary_value "$SUMMARY_CSV" "runner_owned_query_result_evaluator_ready" "1" "v14-c runner ready"
expect_summary_value "$SUMMARY_CSV" "candidate_external_benchmark_result_ready" "0" "v14-c candidate external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v14-c real external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v14-c release"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v14-c routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v14-c jump"

expect_decision_status "$DECISION_CSV" "v14-b-lite-baseline-frozen" "pass"
expect_decision_status "$DECISION_CSV" "v14-c-baseline-comparison" "pass"
expect_decision_status "$DECISION_CSV" "v14-c-route-memory-safety-dominates" "pass"
expect_decision_status "$DECISION_CSV" "v14-c-input-extractor-baseline-only" "pass"
expect_decision_status "$DECISION_CSV" "candidate-external-benchmark-result" "blocked"
expect_decision_status "$DECISION_CSV" "real-release-package" "blocked"

for file in \
  benchmark/baseline_comparison_rows.csv \
  benchmark/baseline_negative_case_rows.csv \
  metrics/baseline_comparison_metrics.json \
  resource/baseline_latency_rows.csv \
  promotion/baseline_promotion_guard_rows.csv \
  evidence/execution_chain_manifest.json \
  evidence/objective_requirements_manifest.json \
  evidence/run_layout_manifest.json \
  sha256sums.txt
do
  if [[ ! -s "$RUN_DIR/$file" ]]; then
    echo "missing v14-c artifact: $file" >&2
    exit 20
  fi
done

python3 - "$RUN_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def csv_rows(rel):
    with (run_dir / rel).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

sha_manifest = {}
with (run_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            digest, rel = line.strip().split(None, 1)
            sha_manifest[rel] = "sha256:" + digest

required = [
    "benchmark/baseline_comparison_rows.csv",
    "benchmark/baseline_negative_case_rows.csv",
    "metrics/baseline_comparison_metrics.json",
    "resource/baseline_latency_rows.csv",
    "promotion/baseline_promotion_guard_rows.csv",
]
for rel in required:
    if sha_manifest.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"sha256 manifest does not bind {rel}")

rows = csv_rows("benchmark/baseline_comparison_rows.csv")
negative_rows = csv_rows("benchmark/baseline_negative_case_rows.csv")
latency_rows = csv_rows("resource/baseline_latency_rows.csv")
guard_rows = csv_rows("promotion/baseline_promotion_guard_rows.csv")
metrics = json.loads((run_dir / "metrics" / "baseline_comparison_metrics.json").read_text(encoding="utf-8"))
layout = json.loads((run_dir / "evidence" / "run_layout_manifest.json").read_text(encoding="utf-8"))
objective = json.loads((run_dir / "evidence" / "objective_requirements_manifest.json").read_text(encoding="utf-8"))
chain = json.loads((run_dir / "evidence" / "execution_chain_manifest.json").read_text(encoding="utf-8"))

if len(rows) != 6 or len(negative_rows) != 66 or len(latency_rows) != 6 or len(guard_rows) != 6:
    raise SystemExit("v14-c baseline row counts mismatch")
by_id = {row["baseline_id"]: row for row in rows}
required_ids = {
    "input_extractor",
    "bm25_lexical",
    "route_memory_retrieval_only",
    "route_memory_exact_value_read",
    "route_memory_proposal_hint",
    "tiny_generator_hint_nlg",
}
if set(by_id) != required_ids:
    raise SystemExit("v14-c baseline id set mismatch")
if by_id["input_extractor"]["input_extractor_used"] != "1" or by_id["input_extractor"]["promotion_eligible"] != "0":
    raise SystemExit("input extractor was not baseline-only")
if by_id["bm25_lexical"]["promotion_eligible"] != "0":
    raise SystemExit("BM25/lexical baseline unexpectedly promotion eligible")
for baseline_id in ["route_memory_exact_value_read", "route_memory_proposal_hint", "tiny_generator_hint_nlg"]:
    row = by_id[baseline_id]
    if row["promotion_eligible"] != "1" or row["route_memory_store_used"] != "1" or row["mmap_read_used"] != "1":
        raise SystemExit(f"RouteMemory candidate baseline not promotion-shaped: {baseline_id}")
    if row["wrong_answer_rate"] != "0.000000" or row["shortcut_block_rate"] != "1.000000":
        raise SystemExit(f"RouteMemory candidate baseline not safe: {baseline_id}")
if float(by_id["route_memory_exact_value_read"]["safety_score"]) <= float(by_id["bm25_lexical"]["safety_score"]):
    raise SystemExit("RouteMemory exact did not dominate BM25 safety score")
if float(by_id["route_memory_exact_value_read"]["safety_score"]) <= float(by_id["input_extractor"]["safety_score"]):
    raise SystemExit("RouteMemory exact did not dominate extractor safety score")

guard_by_id = {row["baseline_id"]: row for row in guard_rows}
if guard_by_id["input_extractor"]["promotion_allowed"] != "0" or guard_by_id["input_extractor"]["input_extractor_baseline_only"] != "1":
    raise SystemExit("input extractor promotion guard mismatch")
for baseline_id in ["route_memory_exact_value_read", "route_memory_proposal_hint", "tiny_generator_hint_nlg"]:
    if guard_by_id[baseline_id]["promotion_allowed"] != "1":
        raise SystemExit(f"RouteMemory candidate was not allowed by baseline guard: {baseline_id}")
for row in negative_rows:
    if row["baseline_id"] in {"route_memory_exact_value_read", "route_memory_proposal_hint", "tiny_generator_hint_nlg"} and row["negative_case_blocked"] != "1":
        raise SystemExit("RouteMemory candidate failed negative-case block")
    if row["baseline_id"] == "input_extractor" and row["case_id"] == "raw_input_contains_answer_but_store_masked" and row["candidate_promotion_allowed"] != "0":
        raise SystemExit("input extractor raw-input shortcut promoted")

for key in [
    "baseline_comparison_ready",
    "route_memory_safety_dominates_baselines",
    "input_extractor_baseline_only",
    "baseline_promotion_guard_ready",
]:
    if metrics.get(key) != 1:
        raise SystemExit(f"baseline metrics readiness mismatch: {key}")
if metrics.get("candidate_external_benchmark_result_ready") != 0 or metrics.get("real_release_package_ready") != 0:
    raise SystemExit("baseline metrics promoted external/release unexpectedly")

layout_scopes = {row.get("layout_scope") for row in layout.get("layout_groups", [])}
if "baseline_comparison" not in layout_scopes:
    raise SystemExit("layout manifest missing baseline_comparison scope")
objective_stages = {row.get("stage"): row for row in objective.get("stages", [])}
if objective_stages.get("baseline_comparison", {}).get("ready") != 1:
    raise SystemExit("objective manifest baseline stage is not ready")
artifact_names = {row.get("artifact") for row in chain.get("artifacts", [])}
for artifact in [
    "baseline_comparison_rows",
    "baseline_negative_case_rows",
    "baseline_comparison_metrics",
    "baseline_latency_rows",
    "baseline_promotion_guard_rows",
]:
    if artifact not in artifact_names:
        raise SystemExit(f"execution chain missing {artifact}")
if chain.get("baseline_comparison_ready") != 1 or chain.get("baseline_promotion_guard_ready") != 1:
    raise SystemExit("execution chain does not bind baseline readiness")
if chain.get("candidate_external_benchmark_result_ready") != 0 or chain.get("real_release_package_ready") != 0:
    raise SystemExit("execution chain promoted external/release unexpectedly")
PY

echo "v14-c baseline comparison smoke passed"
