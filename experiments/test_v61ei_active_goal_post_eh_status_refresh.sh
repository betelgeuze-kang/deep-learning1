#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ei_active_goal_post_eh_status_refresh"
RUN_DIR="$RESULTS_DIR/$PREFIX/refresh_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EI_REUSE_EXISTING="${V61EI_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ei_active_goal_post_eh_status_refresh.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
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


summary = read_csv(summary_csv)[0]
expected = {
    "v61ei_active_goal_post_eh_status_refresh_ready": "1",
    "v61dx_active_goal_status_audit_gate_ready": "1",
    "v61eh_real_generation_result_return_packet_ready": "1",
    "section_rows": "4",
    "ready_section_rows": "4",
    "requirement_rows": "10",
    "ready_requirement_rows": "4",
    "blocked_requirement_rows": "6",
    "claim_boundary_rows": "8",
    "allowed_claim_boundary_rows": "4",
    "blocked_claim_boundary_rows": "4",
    "next_action_rows": "5",
    "v52_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "v53_machine_complete_source_surface_ready": "1",
    "v53_ready": "0",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "real_manifest_runtime_evidence_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "ready_checkpoint_materialization_shard_rows": "59",
    "checkpoint_shard_rows": "59",
    "total_verified_page_hash_rows": "134161",
    "total_required_page_hash_rows": "134161",
    "generation_return_packet_ready": "1",
    "required_generation_result_artifact_rows": "5",
    "required_generation_result_field_rows": "42",
    "real_prerequisite_binding_ready": "0",
    "real_review_return_ready": "0",
    "real_generation_execution_admission_ready": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ei": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ei {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_eh_objective_section_rows.csv",
    "post_eh_requirement_rows.csv",
    "post_eh_claim_boundary_rows.csv",
    "post_eh_next_action_rows.csv",
    "V61EI_ACTIVE_GOAL_POST_EH_STATUS_REFRESH_BOUNDARY.md",
    "v61ei_active_goal_post_eh_status_refresh_manifest.json",
    "source_v61dx/active_goal_requirement_rows.csv",
    "source_v61dx/active_goal_claim_boundary_rows.csv",
    "source_v61eh/real_generation_required_artifact_rows.csv",
    "source_v61eh/real_prerequisite_binding_contract_rows.csv",
    "source_v61eh/real_generation_result_return_packet_stage_rows.csv",
    "source_v61eh/real_generation_result_return_packet_command_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ei artifact: {rel}")

sections = read_csv(run_dir / "post_eh_objective_section_rows.csv")
if len(sections) != 4:
    raise SystemExit("v61ei expected four section rows")
if any(row["ready"] != "1" for row in sections):
    raise SystemExit("v61ei section rows should all be machine-ready")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "post_eh_requirement_rows.csv")}
for requirement_id in [
    "v52-f-optional-final-disposition",
    "v53-complete-source-machine-surface",
    "v61-real-manifest-runtime-evidence",
    "v61-real-generation-return-packet",
]:
    if requirements[requirement_id]["status"] != "ready":
        raise SystemExit(f"v61ei requirement should be ready: {requirement_id}")
for requirement_id in [
    "v53-review-return-accepted",
    "v61-real-prerequisite-binding",
    "v61-generation-execution-admission",
    "v61-real-generation-result-artifacts",
    "v61-actual-model-generation",
    "v1-release-and-quality-claims",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ei requirement should remain blocked: {requirement_id}")

claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "post_eh_claim_boundary_rows.csv")}
for claim_id in [
    "v52-30b-150b-comparison-wording",
    "v53-complete-source-machine-surface",
    "v61-real-model-page-runtime-evidence",
    "v61-real-generation-return-packet",
]:
    if not claims[claim_id].startswith("allowed"):
        raise SystemExit(f"v61ei claim should be allowed/boundary: {claim_id}")
for claim_id in [
    "actual-mixtral-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if claims[claim_id] != "blocked":
        raise SystemExit(f"v61ei claim should be blocked: {claim_id}")

next_actions = read_csv(run_dir / "post_eh_next_action_rows.csv")
if [row["action_id"] for row in next_actions] != [
    "01-real-v53-review-return",
    "02-refresh-real-prerequisite-binding",
    "03-run-real-generation-and-return-five-artifacts",
    "04-intake-and-refresh-v61bt-v61de-v61cu",
    "05-latency-quality-release-audit",
]:
    raise SystemExit("v61ei next action sequence mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "post-eh-status-refresh",
    "v52-f-optional-policy",
    "v53-complete-source-machine-surface",
    "v61-real-model-page-runtime-evidence",
    "v61-generation-return-packet",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ei gate should pass: {gate}")
for gate in [
    "v53-review-return",
    "v61-real-prerequisite-binding",
    "actual-model-generation",
    "latency-quality-release",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ei gate should be blocked: {gate}")

boundary = (run_dir / "V61EI_ACTIVE_GOAL_POST_EH_STATUS_REFRESH_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v52_ready=1",
    "v53_machine_complete_source_surface_ready=1",
    "v53_ready=0",
    "real_manifest_runtime_evidence_ready=1",
    "full checkpoint shards=59/59",
    "full page hashes=134161/134161",
    "generation_return_packet_ready=1",
    "required_generation_result_artifact_rows=5",
    "required_generation_result_field_rows=42",
    "real_prerequisite_binding_ready=0",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ei boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ei_active_goal_post_eh_status_refresh_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ei_active_goal_post_eh_status_refresh_ready") != 1:
    raise SystemExit("v61ei manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ei manifest must keep actual generation blocked")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v61ei manifest must keep release blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ei manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ei sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ei produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ei active goal post-eh status refresh smoke passed"
