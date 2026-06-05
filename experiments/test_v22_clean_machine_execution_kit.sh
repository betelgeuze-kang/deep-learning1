#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
KIT_DIR="$RESULTS_DIR/v22_clean_machine_execution_kit/kit_001"
SUMMARY_CSV="$RESULTS_DIR/v22_clean_machine_execution_kit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v22_clean_machine_execution_kit_decision.csv"

"$ROOT_DIR/experiments/run_v22_clean_machine_execution_kit.sh" >/dev/null

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
    raise SystemExit(f"expected one v22 summary row, got {len(rows)}")
summary = rows[0]
for field in [
    "clean_machine_execution_kit_ready",
    "container_runbook_ready",
    "host_runbook_ready",
    "return_capture_script_ready",
    "environment_templates_ready",
    "official_benchmark_execution_notes_ready",
    "commercial_poc_execution_notes_ready",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v22 {field}: expected 1 got {summary.get(field)}")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v22 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("clean-machine-execution-kit") != "pass":
    raise SystemExit("v22 clean-machine kit gate should pass")
for gate in [
    "independent-rerun-actual",
    "candidate-external-benchmark-result",
    "closed-corpus-poc-actual",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v22 actual gate should remain blocked: {gate}")

required_files = [
    "clean_machine/Containerfile.clean-machine",
    "clean_machine/HOST_CLEAN_MACHINE_RUNBOOK.md",
    "clean_machine/CONTAINER_CLEAN_MACHINE_RUNBOOK.md",
    "clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh",
    "clean_machine/OFFICIAL_BENCHMARK_EXECUTION_NOTES.md",
    "clean_machine/COMMERCIAL_POC_EXECUTION_NOTES.md",
    "templates/reviewer_identity_template.json",
    "templates/rerun_environment_template.json",
    "templates/official_benchmark_return_manifest_template.json",
    "templates/commercial_poc_return_manifest_template.json",
    "verification/VERIFY_CLEAN_MACHINE_RETURN.md",
    "clean_machine_execution_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = kit_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v22 artifact: {rel}")

checks = {
    "clean_machine/HOST_CLEAN_MACHINE_RUNBOOK.md": [
        "independent_rerun_actual_ready=1",
        "reviewer_identity.json",
        "V20_THIRD_PARTY_RERUN_DIR",
    ],
    "clean_machine/CONTAINER_CLEAN_MACHINE_RUNBOOK.md": [
        "docker build",
        "CAPTURE_THIRD_PARTY_RERUN.sh",
    ],
    "clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh": [
        "experiments/test_v15a_independent_reproduction_package.sh",
        "stdout.txt",
        "rerun_manifest.json",
        "METRIC_DELTA_SRC",
        "review_rows_auto_copied",
    ],
    "clean_machine/OFFICIAL_BENCHMARK_EXECUTION_NOTES.md": [
        "candidate_external_benchmark_result_ready=1",
        "official source snapshot",
        "oracle_prediction_used=0",
    ],
    "clean_machine/COMMERCIAL_POC_EXECUTION_NOTES.md": [
        "closed_corpus_poc_actual_ready=1",
        "local evidence-bound QA/audit system",
        "wrong-answer guard",
    ],
    "verification/VERIFY_CLEAN_MACHINE_RETURN.md": [
        "independent_rerun_actual_ready=1",
        "V20_OFFICIAL_BENCHMARK_DIR",
        "V20_COMMERCIAL_POC_DIR",
    ],
}
for rel, snippets in checks.items():
    text = (kit_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v22 artifact {rel} missing snippet: {snippet}")

manifest = json.loads((kit_dir / "clean_machine_execution_manifest.json").read_text(encoding="utf-8"))
for field in [
    "clean_machine_execution_kit_ready",
    "container_runbook_ready",
    "host_runbook_ready",
    "return_capture_script_ready",
    "environment_templates_ready",
]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v22 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v22 manifest overstated readiness: {field}")

identity = json.loads((kit_dir / "templates" / "reviewer_identity_template.json").read_text(encoding="utf-8"))
environment = json.loads((kit_dir / "templates" / "rerun_environment_template.json").read_text(encoding="utf-8"))
if identity.get("external_independent_reviewer") != 0:
    raise SystemExit("v22 template should not predeclare independent reviewer")
if environment.get("clean_machine") != 0:
    raise SystemExit("v22 template should not predeclare clean machine")

with (kit_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v22 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(kit_dir / rel):
        raise SystemExit(f"v22 artifact hash mismatch: {rel}")
PY

echo "v22 clean-machine execution kit smoke passed"
