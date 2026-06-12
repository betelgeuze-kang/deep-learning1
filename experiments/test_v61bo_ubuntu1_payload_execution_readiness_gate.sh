#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bo_ubuntu1_payload_execution_readiness_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61bo_ubuntu1_payload_execution_readiness_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bo_ubuntu1_payload_execution_readiness_gate_decision.csv"

V61BO_REUSE_EXISTING="${V61BO_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bo_ubuntu1_payload_execution_readiness_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"
curl_resume_marker = "curl -L --fail --retry 5 --continue-at - --output"


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
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bo_ubuntu1_payload_execution_readiness_gate_ready": "1",
    "v61bn_ubuntu1_activation_admission_refresh_gate_ready": "1",
    "selected_capacity_target_id": "ubuntu-1-full-reserve-capacity",
    "selected_activation_target_id": "ubuntu-1-write-witness-admitted",
    "selected_payload_execution_target_id": "ubuntu-1-payload-readiness-pending-approval",
    "selected_target_path": ubuntu1_target,
    "selected_backend_id": "curl-resume",
    "selected_backend_ready": "1",
    "ubuntu1_available_bytes_live": "410581364736",
    "required_with_reserve_bytes": "315601231712",
    "activation_target_admission_ready": "1",
    "activation_target_admitted_rows": "59",
    "activation_target_blocked_rows": "0",
    "payload_execution_preflight_ready": "1",
    "payload_execution_readiness_rows": "59",
    "payload_execution_chunk_rows": "3",
    "target_bound_download_command_rows": "59",
    "curl_resume_command_rows": "59",
    "post_download_verify_command_rows": "59",
    "post_download_full_page_hash_command_rows": "59",
    "post_download_generation_admission_command_rows": "59",
    "payload_execution_ready_rows": "0",
    "payload_execution_blocked_rows": "59",
    "explicit_payload_execution_required": "1",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": "281241493344",
    "p0_remote_moe_sampled_rows": "15",
    "p0_embedding_sampled_rows": "1",
    "p2_checkpoint_backfill_rows": "43",
    "checkpoint_payload_bytes_downloaded_by_v61bo": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bo {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_payload_execution_readiness_rows.csv",
    "ubuntu1_payload_execution_chunk_rows.csv",
    "ubuntu1_payload_execution_requirement_rows.csv",
    "ubuntu1_payload_execution_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BO_UBUNTU1_PAYLOAD_EXECUTION_READINESS_GATE_BOUNDARY.md",
    "v61bo_ubuntu1_payload_execution_readiness_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61bn/ubuntu1_activation_admission_rows.csv",
    "source_v61ba/ubuntu1_activation_handoff_command_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bo artifact: {rel}")

readiness_rows = read_csv(run_dir / "ubuntu1_payload_execution_readiness_rows.csv")
chunk_rows = read_csv(run_dir / "ubuntu1_payload_execution_chunk_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_payload_execution_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_payload_execution_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(readiness_rows) != 59:
    raise SystemExit("v61bo readiness row count mismatch")
if len(chunk_rows) != 3:
    raise SystemExit("v61bo chunk row count mismatch")
if any(row["target_activation_admitted"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all target activation rows must stay admitted")
if any(row["payload_execution_preflight_ready"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all rows must be preflight ready")
if any(row["payload_execution_ready"] != "0" for row in readiness_rows):
    raise SystemExit("v61bo must keep payload execution blocked")
if any(row["download_execution_ready"] != "0" for row in readiness_rows):
    raise SystemExit("v61bo must not claim download execution")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bo"] != "0" for row in readiness_rows):
    raise SystemExit("v61bo must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in readiness_rows):
    raise SystemExit("v61bo must not commit checkpoint payload bytes")
if any(row["target_bound_download_command"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all download commands must be target-bound")
if any(row["curl_resume_command_ready"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all rows must have curl-resume commands")
if any(row["post_download_verify_command_ready"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all rows must have verification commands")
if any(row["post_download_full_page_hash_command_ready"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all rows must have full page-hash commands")
if any(row["post_download_generation_admission_command_ready"] != "1" for row in readiness_rows):
    raise SystemExit("v61bo all rows must have generation admission commands")
if any(not row["target_path"].startswith(ubuntu1_target) for row in readiness_rows):
    raise SystemExit("v61bo all target paths must remain under ubuntu-1")
if any("/tmp/" in row["target_path"] for row in readiness_rows):
    raise SystemExit("v61bo must not contain stale /tmp target paths")
if any(curl_resume_marker not in row["download_command_preview"] for row in readiness_rows):
    raise SystemExit("v61bo curl-resume command preview mismatch")
if any(ubuntu1_target not in row["download_command_preview"] for row in readiness_rows):
    raise SystemExit("v61bo download command must reference ubuntu-1 target")
if any(row["payload_execution_blocked_reason"] != "explicit-operator-approval-required" for row in readiness_rows):
    raise SystemExit("v61bo blocker reason mismatch")

chunk_counts = {row["priority_class"]: row["row_count"] for row in chunk_rows}
expected_chunk_counts = {
    "p0_remote_moe_sampled": "15",
    "p0_embedding_sampled": "1",
    "p2_checkpoint_backfill": "43",
}
if chunk_counts != expected_chunk_counts:
    raise SystemExit(f"v61bo chunk counts mismatch: {chunk_counts}")
for row in chunk_rows:
    if row["payload_execution_preflight_ready"] != "1":
        raise SystemExit("v61bo chunk must be preflight ready")
    if row["payload_execution_ready"] != "0" or row["download_execution_ready"] != "0":
        raise SystemExit("v61bo chunks must keep execution blocked")
    if row["checkpoint_payload_bytes_downloaded_by_v61bo"] != "0":
        raise SystemExit("v61bo chunks must not download checkpoint payload bytes")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bo metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v61bn-activation-admission-input",
    "ubuntu1-activation-target-admitted",
    "target-bound-download-commands",
    "curl-resume-command-plan",
    "post-download-verification-commands",
    "post-download-full-page-hash-commands",
    "post-download-generation-admission-commands",
    "payload-execution-preflight",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bo requirement should pass: {requirement_id}")
for requirement_id in [
    "explicit-payload-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bo requirement should stay blocked: {requirement_id}")

for gate in [
    "v61bn-activation-admission-input",
    "ubuntu1-activation-target-admitted",
    "target-bound-download-commands",
    "curl-resume-command-plan",
    "post-download-verification-commands",
    "payload-execution-preflight",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bo gate should pass: {gate}")
for gate in [
    "explicit-payload-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bo gate should stay blocked: {gate}")

for gap in [
    "v61bn-activation-admission-input",
    "ubuntu1-activation-target-admitted",
    "target-bound-download-commands",
    "curl-resume-command-plan",
    "payload-execution-preflight",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bo gap should be ready: {gap}")
for gap in [
    "explicit-payload-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bo gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bo_ubuntu1_payload_execution_readiness_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bo_ubuntu1_payload_execution_readiness_gate_ready") != 1:
    raise SystemExit("v61bo manifest readiness mismatch")
if manifest.get("payload_execution_preflight_ready") != 1:
    raise SystemExit("v61bo manifest preflight mismatch")
if manifest.get("payload_execution_ready_rows") != 0:
    raise SystemExit("v61bo manifest must keep payload execution blocked")
if manifest.get("download_execution_ready") != 0:
    raise SystemExit("v61bo manifest must keep download execution blocked")

boundary = (run_dir / "V61BO_UBUNTU1_PAYLOAD_EXECUTION_READINESS_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_payload_execution_target_id=ubuntu-1-payload-readiness-pending-approval",
    "activation_target_admission_ready=1",
    "activation_target_admitted_rows=59",
    "payload_execution_preflight_ready=1",
    "payload_execution_readiness_rows=59",
    "payload_execution_chunk_rows=3",
    "target_bound_download_command_rows=59",
    "curl_resume_command_rows=59",
    "post_download_verify_command_rows=59",
    "payload_execution_ready_rows=0",
    "explicit_payload_execution_required=1",
    "download_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bo boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bo sha256 mismatch: {rel}")
PY
