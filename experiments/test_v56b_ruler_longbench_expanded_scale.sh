#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v56b_ruler_longbench_expanded_scale/scale_001"
SUMMARY_CSV="$RESULTS_DIR/v56b_ruler_longbench_expanded_scale_summary.csv"
DECISION_CSV="$RESULTS_DIR/v56b_ruler_longbench_expanded_scale_decision.csv"

"$ROOT_DIR/experiments/run_v56b_ruler_longbench_expanded_scale.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v56b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v56b_ruler_longbench_expanded_scale_ready": "1",
    "v56_ruler_longbench_expanded_ready": "1",
    "benchmark_family_rows": "2",
    "target_total_rows": "1500",
    "prediction_rows": "1500",
    "lineage_rows": "1500",
    "candidate_rows": "1500",
    "resource_rows": "1500",
    "ruler_rows": "1000",
    "longbench_rows": "500",
    "missing_total_rows": "0",
    "official_source_hash_bound": "1",
    "official_evaluator_hash_bound": "1",
    "oracle_prediction_used": "0",
    "raw_input_extractor_used": "0",
    "route_memory_prediction_lineage_ready": "1",
    "llm_rag_baseline_rows_ready": "0",
    "real_external_benchmark_verified": "0",
    "v56_contract_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v56b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v56b-expanded-benchmark-scale",
    "ruler-expanded-row-target",
    "longbench-expanded-row-target",
    "official-source-evaluator-binding",
    "route-memory-lineage",
    "no-oracle-no-extractor",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v56b gate should pass: {gate}")
for gate in ["llm-rag-baseline-rows", "real-external-benchmark", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v56b gate should remain blocked: {gate}")

required_files = [
    "expanded_prediction_rows.csv",
    "prediction_lineage_rows.csv",
    "candidate_result_rows.csv",
    "benchmark_resource_rows.csv",
    "benchmark_family_rows.csv",
    "expanded_benchmark_metrics.json",
    "V56B_RULER_LONGBENCH_EXPANDED_SCALE_BOUNDARY.md",
    "v56b_ruler_longbench_expanded_scale_manifest.json",
    "sha256_manifest.csv",
    "source_v56_contract/benchmark_family_target_rows.csv",
    "source_v56_contract/expanded_benchmark_artifact_contract_rows.csv",
    "source_v56_contract/benchmark_invariant_rows.csv",
    "source_v56_contract/V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md",
    "source_v56_contract/v56_ruler_longbench_expanded_manifest.json",
    "source_v56_contract/sha256_manifest.csv",
    "source_v56_contract/v56_ruler_longbench_expanded_contract_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v56b artifact: {rel}")

predictions = read_csv(run_dir / "expanded_prediction_rows.csv")
lineage = read_csv(run_dir / "prediction_lineage_rows.csv")
candidates = read_csv(run_dir / "candidate_result_rows.csv")
resources = read_csv(run_dir / "benchmark_resource_rows.csv")
families = read_csv(run_dir / "benchmark_family_rows.csv")
if len(predictions) != 1500 or len(lineage) != 1500 or len(candidates) != 1500 or len(resources) != 1500:
    raise SystemExit("v56b should write 1500 prediction/lineage/candidate/resource rows")
if len({row["sample_id"] for row in predictions}) != 1500:
    raise SystemExit("v56b sample IDs should be unique")
family_counts = Counter(row["benchmark_family"] for row in predictions)
if family_counts["RULER"] != 1000 or family_counts["LongBench"] != 500:
    raise SystemExit("v56b family row counts mismatch")
if any(row["prediction"] != row["target"] or row["correct"] != "1" for row in predictions):
    raise SystemExit("v56b predictions should match targets in candidate scale")
if any(row["oracle_prediction_used"] != "0" or row["raw_input_extractor_used"] != "0" for row in predictions):
    raise SystemExit("v56b predictions should remain no-oracle/no-extractor")
if any(row["route_memory_prediction_lineage_ready"] != "1" for row in predictions):
    raise SystemExit("v56b predictions should be lineage-ready")
if {row["sample_id"] for row in predictions} != {row["sample_id"] for row in lineage}:
    raise SystemExit("v56b prediction/lineage IDs should match")
if any(row["route_memory_prediction_lineage_ready"] != "1" or row["oracle_prediction_used"] != "0" or row["raw_input_extractor_used"] != "0" for row in lineage):
    raise SystemExit("v56b lineage invariants mismatch")
if any(row["candidate_external_benchmark_result_ready"] != "1" for row in candidates):
    raise SystemExit("v56b candidate rows should be ready")
if any(row["external_network_used"] != "0" or row["oracle_prediction_used"] != "0" or row["raw_input_extractor_used"] != "0" or row["raw_prompt_context_bytes"] != "0" for row in resources):
    raise SystemExit("v56b resource rows should preserve local/no-oracle/no-raw-context boundary")
family_rows = {row["benchmark_family"]: row for row in families}
if family_rows["RULER"]["prediction_rows"] != "1000" or family_rows["LongBench"]["prediction_rows"] != "500":
    raise SystemExit("v56b family rows should record targets")

metrics = json.loads((run_dir / "expanded_benchmark_metrics.json").read_text(encoding="utf-8"))
if metrics.get("benchmark_scale_rows") != 1500 or metrics.get("real_external_benchmark_verified") != 0:
    raise SystemExit("v56b metrics boundary mismatch")
manifest = json.loads((run_dir / "v56b_ruler_longbench_expanded_scale_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v56b_ruler_longbench_expanded_scale_ready") != 1 or manifest.get("v56_ruler_longbench_expanded_ready") != 1:
    raise SystemExit("v56b manifest readiness mismatch")
if manifest.get("real_external_benchmark_verified") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v56b manifest should keep external/release blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v56b sha256 mismatch: {rel}")

boundary = (run_dir / "V56B_RULER_LONGBENCH_EXPANDED_SCALE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "deterministic local expanded benchmark-scale evidence run",
    "prediction_rows=1500",
    "ruler_rows=1000",
    "longbench_rows=500",
    "real_external_benchmark_verified=0",
    "Do not publish leaderboard, external benchmark, or 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v56b boundary missing {snippet}")
PY

echo "v56b RULER/LongBench expanded scale smoke passed"
