#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v45_longbench_v2_small_slice/slice_001"
RETURN_DIR="$RUN_DIR/official_return"
SUMMARY_CSV="$RESULTS_DIR/v45_longbench_v2_small_slice_summary.csv"
DECISION_CSV="$RESULTS_DIR/v45_longbench_v2_small_slice_decision.csv"

"$ROOT_DIR/experiments/run_v45_longbench_v2_small_slice.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def read_jsonl(path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v45 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_ones = [
    "v45_longbench_v2_small_slice_ready",
    "official_source_snapshot_ready",
    "official_evaluator_ready",
    "route_memory_prediction_lineage_ready",
    "v18_candidate_external_benchmark_result_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v45 {field}: expected 1, got {summary.get(field)}")
expected_counts = {
    "raw_prediction_rows": "6",
    "prediction_lineage_rows": "6",
    "task_categories": "6",
    "oracle_prediction_used": "0",
    "raw_input_extractor_used": "0",
    "real_external_benchmark_verified": "0",
    "human_review_completed": "0",
    "real_release_package_ready": "0",
}
for field, expected in expected_counts.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v45 {field}: expected {expected}, got {summary.get(field)}")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v45-longbench-v2-small-slice",
    "official-source-evaluator",
    "small-slice-rows",
    "route-memory-lineage",
    "no-oracle-no-extractor",
    "v18-official-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v45 gate should pass: {gate}")
for gate in ["real-external-benchmark", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v45 gate should stay blocked: {gate}")

required_files = [
    "V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md",
    "v45_longbench_v2_small_slice_manifest.json",
    "artifact_manifest.csv",
    "sha256_manifest.csv",
    "official_source_snapshot/download_rows.csv",
    "evidence/v18_longbench_v2_summary.csv",
    "evidence/v18_longbench_v2_decision.csv",
    "evidence/v44_tiny_generator_summary.csv",
    "official_return/official_source_snapshot.json",
    "official_return/official_evaluator_status.json",
    "official_return/raw_predictions.jsonl",
    "official_return/prediction_lineage.jsonl",
    "official_return/metrics.json",
    "official_return/provenance_manifest.json",
    "official_return/reproducibility_package_manifest.json",
    "official_return/candidate_result_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v45 missing artifact: {rel}")

manifest = json.loads((run_dir / "v45_longbench_v2_small_slice_manifest.json").read_text(encoding="utf-8"))
if manifest.get("longbench_v2_small_slice_ready") != 1:
    raise SystemExit("v45 manifest should be ready")
if manifest.get("raw_prediction_rows") != 6 or manifest.get("prediction_lineage_rows") != 6:
    raise SystemExit("v45 manifest should record 6 prediction/lineage rows")
if manifest.get("task_categories") != 6:
    raise SystemExit("v45 manifest should record six task categories")
if manifest.get("oracle_prediction_used") != 0 or manifest.get("raw_input_extractor_used") != 0:
    raise SystemExit("v45 manifest should keep oracle/extractor off")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v45 manifest should keep review/release blocked")

download_rows = read_csv(run_dir / "official_source_snapshot" / "download_rows.csv")
if len(download_rows) < 6:
    raise SystemExit("v45 should snapshot at least six LongBench source files")
for row in download_rows:
    path = root / row["path"]
    if row["sha256"] != sha256(path):
        raise SystemExit(f"v45 source snapshot hash mismatch: {row['artifact']}")
for expected_artifact in ["README.md", "LICENSE", "pred.py", "LongBench_eval.py", "LongBench_metrics.py", "model2maxlen.json"]:
    if not any(row["artifact"] == expected_artifact for row in download_rows):
        raise SystemExit(f"v45 source snapshot missing {expected_artifact}")

source = json.loads((return_dir / "official_source_snapshot.json").read_text(encoding="utf-8"))
evaluator = json.loads((return_dir / "official_evaluator_status.json").read_text(encoding="utf-8"))
metrics = json.loads((return_dir / "metrics.json").read_text(encoding="utf-8"))
provenance = json.loads((return_dir / "provenance_manifest.json").read_text(encoding="utf-8"))
repro = json.loads((return_dir / "reproducibility_package_manifest.json").read_text(encoding="utf-8"))
if source.get("benchmark_family") != "LongBench-v2" or source.get("dataset_reference") != "THUDM/LongBench-v2":
    raise SystemExit("v45 source snapshot should identify LongBench-v2")
if source.get("dataset_size_reference") != 503:
    raise SystemExit("v45 source snapshot should record the 503-entry LongBench v2 reference")
if evaluator.get("official_evaluator_ready") != 1 or evaluator.get("task_format") != "multiple-choice":
    raise SystemExit("v45 evaluator should be ready for multiple-choice")
if metrics.get("prediction_rows") != 6 or metrics.get("task_categories") != 6:
    raise SystemExit("v45 metrics should record six rows/categories")
if metrics.get("oracle_prediction_used") != 0 or metrics.get("raw_input_extractor_used") != 0:
    raise SystemExit("v45 metrics should keep oracle/extractor off")
if provenance.get("route_memory_prediction_lineage_ready") != 1:
    raise SystemExit("v45 provenance should mark route memory lineage ready")
if repro.get("reproducibility_package_ready") != 1:
    raise SystemExit("v45 reproducibility package should be ready")

raw_rows = read_jsonl(return_dir / "raw_predictions.jsonl")
lineage_rows = read_jsonl(return_dir / "prediction_lineage.jsonl")
if len(raw_rows) != 6 or len(lineage_rows) != 6:
    raise SystemExit("v45 raw prediction and lineage rows should be 6")
if len({row["task_category"] for row in raw_rows}) != 6:
    raise SystemExit("v45 raw rows should cover six task categories")
if any(row["benchmark_family"] != "LongBench-v2" or row["question_type"] != "multiple-choice" for row in raw_rows):
    raise SystemExit("v45 raw rows should be LongBench-v2 multiple-choice")
if any(row["prediction"] != row["target"] for row in raw_rows):
    raise SystemExit("v45 small slice predictions should match targets")
if any(row["oracle_prediction_used"] != 0 or row["raw_input_extractor_used"] != 0 for row in raw_rows):
    raise SystemExit("v45 raw rows should keep oracle/extractor off")
if any(row["route_memory_prediction_lineage_ready"] != 1 or row["proposal_hint_used"] != 1 for row in lineage_rows):
    raise SystemExit("v45 lineage rows should be RouteMemory proposal-hint rows")

candidate_rows = read_csv(return_dir / "candidate_result_rows.csv")
if len(candidate_rows) != 1:
    raise SystemExit("v45 should write one candidate result row")
candidate = candidate_rows[0]
if candidate.get("benchmark_family") != "LongBench-v2" or candidate.get("candidate_external_benchmark_result_ready") != "1":
    raise SystemExit("v45 candidate row should be LongBench-v2 and ready")
if candidate.get("query_count") != "6" or candidate.get("metric_value") != "1.000000":
    raise SystemExit("v45 candidate row should record six perfect small-slice rows")

with (run_dir / "evidence" / "v18_longbench_v2_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("official_benchmark_supplied") != "1" or v18.get("candidate_external_benchmark_result_ready") != "1":
    raise SystemExit("v45 copied v18 summary should verify official benchmark candidate")
if v18.get("real_external_benchmark_verified") != "0" or v18.get("real_release_package_ready") != "0":
    raise SystemExit("v45 copied v18 summary should keep real external/release blocked")

boundary = (run_dir / "V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Expand beyond the RULER benchmark family",
    "LongBench repository source snapshot",
    "small candidate slice",
    "not the full LongBench v2 benchmark",
]:
    if snippet not in boundary:
        raise SystemExit(f"v45 boundary missing: {snippet}")

with (run_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v45 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(run_dir / rel):
        raise SystemExit(f"v45 sha mismatch for {rel}")
PY

echo "v45 LongBench v2 small slice smoke passed"
