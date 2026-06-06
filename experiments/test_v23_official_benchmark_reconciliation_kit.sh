#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
KIT_DIR="$RESULTS_DIR/v23_official_benchmark_reconciliation_kit/kit_001"
SUMMARY_CSV="$RESULTS_DIR/v23_official_benchmark_reconciliation_kit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v23_official_benchmark_reconciliation_kit_decision.csv"

"$ROOT_DIR/experiments/run_v23_official_benchmark_reconciliation_kit.sh" >/dev/null

python3 - "$KIT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

kit_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v23 summary row, got {len(rows)}")
summary = rows[0]
for field in [
    "official_benchmark_reconciliation_kit_ready",
    "official_source_snapshot_template_ready",
    "official_evaluator_container_contract_ready",
    "no_oracle_no_extractor_contract_ready",
    "raw_predictions_template_ready",
    "prediction_lineage_template_ready",
    "metrics_provenance_templates_ready",
    "official_return_preflight_ready",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v23 {field}: expected 1 got {summary.get(field)}")
for field in [
    "candidate_external_benchmark_result_ready",
    "independent_rerun_actual_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v23 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("official-benchmark-reconciliation-kit") != "pass":
    raise SystemExit("v23 official benchmark kit gate should pass")
for gate in ["candidate-external-benchmark-result", "real-external-benchmark", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v23 actual gate should remain blocked: {gate}")

required_files = [
    "official_benchmark/OFFICIAL_SLICE_RECONCILIATION_RUNBOOK.md",
    "official_benchmark/RETURN_DIRECTORY_LAYOUT.md",
    "official_benchmark/NO_ORACLE_NO_EXTRACTOR_CONTRACT.md",
    "official_benchmark/EVALUATOR_CONTAINER_CONTRACT.json",
    "templates/official_source_snapshot.json",
    "templates/official_evaluator_status.json",
    "templates/raw_predictions.jsonl",
    "templates/prediction_lineage.jsonl",
    "templates/metrics.json",
    "templates/provenance_manifest.json",
    "templates/reproducibility_package_manifest.json",
    "templates/candidate_result_rows.csv",
    "verification/CHECK_OFFICIAL_RETURN_FILES.sh",
    "verification/VERIFY_WITH_V20.md",
    "official_benchmark_reconciliation_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = kit_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v23 artifact: {rel}")

checks = {
    "official_benchmark/OFFICIAL_SLICE_RECONCILIATION_RUNBOOK.md": [
        "candidate_external_benchmark_result_ready=1",
        "official evaluator/container",
        "RouteMemory-derived prediction lineage",
    ],
    "official_benchmark/NO_ORACLE_NO_EXTRACTOR_CONTRACT.md": [
        "oracle_prediction_used=0",
        "raw_input_extractor_used=0",
        "route_memory_prediction_lineage_ready=1",
    ],
    "verification/CHECK_OFFICIAL_RETURN_FILES.sh": [
        "official_source_snapshot.json",
        "prediction_lineage.jsonl",
        "nonzero_guard",
    ],
    "verification/VERIFY_WITH_V20.md": [
        "V20_OFFICIAL_BENCHMARK_DIR",
        "candidate_external_benchmark_result_ready=1",
    ],
}
for rel, snippets in checks.items():
    text = (kit_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v23 artifact {rel} missing snippet: {snippet}")

manifest = json.loads((kit_dir / "official_benchmark_reconciliation_manifest.json").read_text(encoding="utf-8"))
for field in [
    "official_benchmark_reconciliation_kit_ready",
    "official_source_snapshot_template_ready",
    "official_evaluator_container_contract_ready",
    "no_oracle_no_extractor_contract_ready",
    "raw_predictions_template_ready",
    "prediction_lineage_template_ready",
    "official_return_preflight_ready",
]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v23 manifest should set {field}=1")
for field in [
    "candidate_external_benchmark_result_ready",
    "independent_rerun_actual_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v23 manifest overstated readiness: {field}")

metrics = json.loads((kit_dir / "templates" / "metrics.json").read_text(encoding="utf-8"))
provenance = json.loads((kit_dir / "templates" / "provenance_manifest.json").read_text(encoding="utf-8"))
if metrics.get("oracle_prediction_used") != 0 or metrics.get("raw_input_extractor_used") != 0:
    raise SystemExit("v23 metrics template should default no oracle/no extractor")
if provenance.get("oracle_prediction_used") != 0 or provenance.get("raw_input_extractor_used") != 0:
    raise SystemExit("v23 provenance template should default no oracle/no extractor")

with (kit_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v23 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(kit_dir / rel):
        raise SystemExit(f"v23 artifact hash mismatch: {rel}")
PY

echo "v23 official benchmark reconciliation kit smoke passed"
