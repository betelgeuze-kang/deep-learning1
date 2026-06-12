#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cg_ubuntu1_source_bound_generation_operator_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cg_ubuntu1_source_bound_generation_operator_bundle_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CG_REUSE_EXISTING="${V61CG_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cg_ubuntu1_source_bound_generation_operator_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = sys.argv[4]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": "1",
    "target_root_path": ubuntu1_target,
    "execution_packet_rows": "1000",
    "prompt_manifest_rows": "4",
    "return_manifest_rows": "5",
    "carried_operator_command_rows": "6",
    "bundle_operator_command_rows": "4",
    "total_operator_command_rows": "10",
    "operator_bundle_file_rows": "4",
    "complete_source_query_rows": "1000",
    "expected_generation_result_artifacts": "5",
    "generation_closure_return_intake_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_execution_ready": "0",
    "generation_execution_admitted_rows": "0",
    "blocked_execution_rows": "1000",
    "operator_bundle_handoff_ready": "1",
    "generation_operator_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cg {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "source_bound_generation_operator_bundle_file_rows.csv",
    "source_bound_generation_operator_bundle_command_rows.csv",
    "source_bound_generation_operator_bundle_requirement_rows.csv",
    "source_bound_generation_operator_bundle_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CG_UBUNTU1_SOURCE_BOUND_GENERATION_OPERATOR_BUNDLE_BOUNDARY.md",
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/RETURN_MANIFEST_TEMPLATE.csv",
    "operator_bundle/GENERATION_RETURN_CHECKLIST.md",
    "operator_bundle/VERIFY_EXECUTION_PACKET.sh",
    "sha256_manifest.csv",
    "source_v61cf/source_bound_generation_execution_packet_rows.csv",
    "source_v61cf/source_bound_generation_return_manifest_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cg artifact: {rel}")

verify_script = run_dir / "operator_bundle/VERIFY_EXECUTION_PACKET.sh"
if not os.access(verify_script, os.X_OK):
    raise SystemExit("v61cg verify script must be executable")
subprocess.run([str(verify_script)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

file_rows = read_csv(run_dir / "source_bound_generation_operator_bundle_file_rows.csv")
command_rows = read_csv(run_dir / "source_bound_generation_operator_bundle_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "source_bound_generation_operator_bundle_requirement_rows.csv")}
metric = read_csv(run_dir / "source_bound_generation_operator_bundle_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(file_rows) != 4:
    raise SystemExit("v61cg bundle file row count mismatch")
if len(command_rows) != 4:
    raise SystemExit("v61cg bundle command row count mismatch")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in file_rows):
    raise SystemExit("v61cg must not commit checkpoint payload bytes")
if {row["bundle_file"] for row in file_rows} != {
    "operator_bundle/README.md",
    "operator_bundle/RETURN_MANIFEST_TEMPLATE.csv",
    "operator_bundle/GENERATION_RETURN_CHECKLIST.md",
    "operator_bundle/VERIFY_EXECUTION_PACKET.sh",
}:
    raise SystemExit("v61cg bundle file set mismatch")
if [row["execution_ready"] for row in command_rows] != ["1", "0", "0", "0"]:
    raise SystemExit("v61cg command readiness mismatch")

for requirement_id in ["v61cf-execution-packet-input", "operator-bundle-shape", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cg requirement should pass: {requirement_id}")
for requirement_id in [
    "source-bound-generation-execution-ready",
    "operator-generation-execution-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cg requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cg_") or field.startswith("v61cf_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cg metric {field}: expected {value}, got {metric[field]}")

for gate in ["v61cf-execution-packet-input", "operator-bundle-shape", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cg gate should pass: {gate}")
for gate in [
    "source-bound-generation-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cg gate should stay blocked: {gate}")

for gap in ["v61cf-execution-packet-input", "operator-bundle-shape"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cg gap should be ready: {gap}")
for gap in [
    "source-bound-generation-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cg gap should stay blocked: {gap}")

boundary = (run_dir / "V61CG_UBUNTU1_SOURCE_BOUND_GENERATION_OPERATOR_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "execution_packet_rows=1000",
    "prompt_manifest_rows=4",
    "return_manifest_rows=5",
    "carried_operator_command_rows=6",
    "bundle_operator_command_rows=4",
    "total_operator_command_rows=10",
    "operator_bundle_file_rows=4",
    "operator_bundle_handoff_ready=1",
    "generation_operator_execution_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cg=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cg boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cg_ubuntu1_source_bound_generation_operator_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cg_ubuntu1_source_bound_generation_operator_bundle_ready") != 1:
    raise SystemExit("v61cg manifest readiness mismatch")
if manifest.get("execution_packet_rows") != 1000:
    raise SystemExit("v61cg manifest packet count mismatch")
if manifest.get("operator_bundle_file_rows") != 4:
    raise SystemExit("v61cg manifest bundle file count mismatch")
if manifest.get("operator_bundle_handoff_ready") != 1:
    raise SystemExit("v61cg manifest handoff mismatch")
if manifest.get("generation_operator_execution_ready") != 0:
    raise SystemExit("v61cg manifest execution should remain blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cg manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61cg") != 0:
    raise SystemExit("v61cg manifest must keep downloaded bytes at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cg manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cg sha256 mismatch: {rel}")
PY

echo "v61cg ubuntu-1 source-bound generation operator bundle smoke passed"
