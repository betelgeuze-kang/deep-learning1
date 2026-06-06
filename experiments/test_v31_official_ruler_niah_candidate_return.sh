#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v31_official_ruler_niah_candidate_return/return_001"
RETURN_DIR="$RUN_DIR/official_return"
COMMERCIAL_DIR="$RESULTS_DIR/v30_commercial_codebase_poc_return/return_001/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v31_official_ruler_niah_candidate_return_summary.csv"
DECISION_CSV="$RESULTS_DIR/v31_official_ruler_niah_candidate_return_decision.csv"

"$ROOT_DIR/experiments/run_v30_commercial_codebase_poc_return.sh" >/dev/null
"$ROOT_DIR/experiments/run_v31_official_ruler_niah_candidate_return.sh" >/dev/null
V29_OFFICIAL_RETURN_DIR="$RETURN_DIR" "$ROOT_DIR/experiments/run_v29_receiver_return_preflight.sh" >/dev/null
V18_OFFICIAL_BENCHMARK_DIR="$RETURN_DIR" V18_COMMERCIAL_POC_DIR="$COMMERCIAL_DIR" "$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null
V20_OFFICIAL_BENCHMARK_DIR="$RETURN_DIR" V20_COMMERCIAL_POC_DIR="$COMMERCIAL_DIR" "$ROOT_DIR/experiments/run_v20_external_return_tracker.sh" >/dev/null

python3 - "$RUN_DIR" "$RETURN_DIR" "$COMMERCIAL_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
return_dir = Path(sys.argv[2])
commercial_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
results_dir = Path(sys.argv[6])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v31 summary row, got {len(rows)}")
summary = rows[0]
for field in [
    "official_ruler_niah_candidate_return_ready",
    "official_source_snapshot_ready",
    "official_evaluator_ready",
    "raw_predictions_ready",
    "metrics_ready",
    "route_memory_prediction_lineage_ready",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v31 should set {field}=1")
for field in ["oracle_prediction_used", "raw_input_extractor_used"]:
    if summary.get(field) != "0":
        raise SystemExit(f"v31 should set {field}=0")
if summary.get("candidate_rows") != "1" or summary.get("artifact_rows") != "8":
    raise SystemExit("v31 row counts mismatch")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["official-ruler-niah-candidate-return", "no-oracle-no-extractor", "route-memory-lineage"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v31 gate should pass: {gate}")

required = [
    "official_source_snapshot.json",
    "official_evaluator_status.json",
    "raw_predictions.jsonl",
    "prediction_lineage.jsonl",
    "metrics.json",
    "provenance_manifest.json",
    "reproducibility_package_manifest.json",
    "candidate_result_rows.csv",
]
for rel in required:
    path = return_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v31 official artifact: {rel}")

source = json.loads((return_dir / "official_source_snapshot.json").read_text(encoding="utf-8"))
evaluator = json.loads((return_dir / "official_evaluator_status.json").read_text(encoding="utf-8"))
metrics = json.loads((return_dir / "metrics.json").read_text(encoding="utf-8"))
provenance = json.loads((return_dir / "provenance_manifest.json").read_text(encoding="utf-8"))
repro = json.loads((return_dir / "reproducibility_package_manifest.json").read_text(encoding="utf-8"))
if source.get("source_repo") != "https://github.com/NVIDIA/RULER":
    raise SystemExit("v31 should bind NVIDIA/RULER as source")
if len(str(source.get("source_head_sha", ""))) != 40:
    raise SystemExit("v31 should bind a 40-char RULER HEAD sha")
if evaluator.get("official_evaluator_ready") != 1 or "scripts/eval/evaluate.py" not in evaluator.get("evaluator_source", ""):
    raise SystemExit("v31 evaluator status should bind official evaluate.py")
if metrics.get("oracle_prediction_used") != 0 or provenance.get("raw_input_extractor_used") != 0:
    raise SystemExit("v31 should block oracle/input-extractor use")
if repro.get("reproducibility_package_ready") != 1:
    raise SystemExit("v31 reproducibility package should be ready")

with (return_dir / "candidate_result_rows.csv").open(newline="", encoding="utf-8") as handle:
    candidate_rows = list(csv.DictReader(handle))
if len(candidate_rows) != 1 or candidate_rows[0].get("candidate_external_benchmark_result_ready") != "1":
    raise SystemExit("v31 candidate row should be ready")

with (return_dir / "raw_predictions.jsonl").open(encoding="utf-8") as handle:
    raw_rows = [json.loads(line) for line in handle if line.strip()]
if len(raw_rows) != 1 or raw_rows[0].get("oracle_prediction_used") != 0:
    raise SystemExit("v31 raw predictions should be non-oracle")

with (return_dir / "prediction_lineage.jsonl").open(encoding="utf-8") as handle:
    lineage_rows = [json.loads(line) for line in handle if line.strip()]
if len(lineage_rows) != 1 or lineage_rows[0].get("route_memory_prediction_lineage_ready") != 1:
    raise SystemExit("v31 lineage row should be ready")

manifest = json.loads((run_dir / "official_ruler_candidate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("official_ruler_niah_candidate_return_ready") != 1:
    raise SystemExit("v31 manifest should be ready")

with (run_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_name = {Path(row["path"]).name: row for row in artifact_rows}
for rel in required:
    if rel not in by_name:
        raise SystemExit(f"v31 artifact manifest missing {rel}")
    if by_name[rel]["sha256"] != sha256(return_dir / rel):
        raise SystemExit(f"v31 artifact hash mismatch: {rel}")

if not commercial_dir.is_dir():
    raise SystemExit("v31 test expected v30 commercial return dir")

with (results_dir / "v29_receiver_return_preflight_summary.csv").open(newline="", encoding="utf-8") as handle:
    v29 = list(csv.DictReader(handle))[0]
if v29.get("return_dirs_detected") != "1" or v29.get("complete_return_dirs") != "1":
    raise SystemExit("v29 should detect the v31 official return as complete")

with (results_dir / "v18_external_evidence_intake_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("official_benchmark_supplied") != "1" or v18.get("candidate_external_benchmark_result_ready") != "1":
    raise SystemExit("v18 should mark the v31 official candidate ready")
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v18 should keep the v30 commercial PoC ready")
if v18.get("independent_rerun_actual_ready") != "0" or v18.get("real_external_benchmark_verified") != "0":
    raise SystemExit("v31 should not overclaim third-party rerun or real benchmark readiness")

with (results_dir / "v20_external_return_tracker_summary.csv").open(newline="", encoding="utf-8") as handle:
    v20 = list(csv.DictReader(handle))[0]
if v20.get("external_return_dirs_supplied") != "2":
    raise SystemExit("v20 should track official plus commercial returns")
if v20.get("candidate_external_benchmark_result_ready") != "1" or v20.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v20 should carry official candidate and commercial PoC readiness")
PY

echo "v31 official RULER NIAH candidate return smoke passed"
