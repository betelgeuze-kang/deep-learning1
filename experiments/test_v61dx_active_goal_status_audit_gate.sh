#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dx_active_goal_status_audit_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DX_REUSE_EXISTING="${V61DX_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dx_active_goal_status_audit_gate.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61dx summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61dx_active_goal_status_audit_gate_ready": "1",
    "v52y_f_optional_final_policy_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "v61dh_post_full_shard_claim_audit_gate_ready": "1",
    "v61dw_return_bundle_operator_handoff_bundle_ready": "1",
    "objective_section_rows": "3",
    "machine_ready_section_rows": "2",
    "final_ready_section_rows": "0",
    "blocked_final_section_rows": "3",
    "objective_requirement_rows": "24",
    "ready_objective_requirement_rows": "14",
    "blocked_objective_requirement_rows": "10",
    "claim_boundary_rows": "10",
    "allowed_claim_boundary_rows": "3",
    "blocked_claim_boundary_rows": "7",
    "next_action_rows": "5",
    "blocked_next_action_rows": "5",
    "v52_ready": "0",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "comparison_30b_150b_wording_status": "blocked",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "review_packet_ready": "1",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "v53_ready": "0",
    "v61_post_full_shard_runtime_evidence_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "checkpoint_shard_rows": "59",
    "ready_checkpoint_materialization_shard_rows": "59",
    "promotion_identity_verified_bytes": "281241493344",
    "full_safetensors_page_hash_binding_ready": "1",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "gpu_page_dequant_matmul_measurement_ready": "1",
    "kv_cache_policy_ready": "1",
    "kv_eviction_trace_ready": "1",
    "v61j_source_bound_qa_command_pass": "1",
    "source_bound_query_rows": "37",
    "source_bound_query_pass_rows": "37",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "return_handoff_bundle_ready": "1",
    "handoff_bundle_file_rows": "11",
    "metadata_only_bundle_file_rows": "11",
    "missing_payload_rows": "17483",
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dx {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "active_goal_objective_section_rows.csv",
    "active_goal_requirement_rows.csv",
    "active_goal_claim_boundary_rows.csv",
    "active_goal_next_action_rows.csv",
    "V61DX_ACTIVE_GOAL_STATUS_AUDIT_GATE_BOUNDARY.md",
    "v61dx_active_goal_status_audit_gate_manifest.json",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
    "source_v52y/f_optional_final_rows.csv",
    "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v53t/complete_source_audit_claim_rows.csv",
    "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "source_v61dg/post_full_shard_runtime_evidence_rows.csv",
    "source_v61dh/v61dh_post_full_shard_claim_audit_gate_summary.csv",
    "source_v61dh/post_full_shard_claim_audit_rows.csv",
    "source_v61dw/v61dw_return_bundle_operator_handoff_bundle_summary.csv",
    "source_v61dw/return_bundle_operator_handoff_bundle_file_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dx artifact: {rel}")

sections = {row["section_id"]: row for row in read_csv(run_dir / "active_goal_objective_section_rows.csv")}
if set(sections) != {
    "v52-f-optional-and-v52-ready",
    "v53-complete-source-audit-surface",
    "v61-real-model-evidence",
}:
    raise SystemExit("v61dx section id set mismatch")
if sections["v52-f-optional-and-v52-ready"]["final_ready"] != "0":
    raise SystemExit("v61dx v52 section should remain blocked until D/E PM/release readiness")
if sections["v53-complete-source-audit-surface"]["final_ready"] != "0":
    raise SystemExit("v61dx v53 final readiness should remain blocked")
if sections["v61-real-model-evidence"]["final_ready"] != "0":
    raise SystemExit("v61dx v61 final readiness should remain generation-blocked")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "active_goal_requirement_rows.csv")}
if len(requirements) != 24:
    raise SystemExit("v61dx expected 24 requirement rows")
ready_ids = {key for key, row in requirements.items() if row["status"] == "ready"}
blocked_ids = {key for key, row in requirements.items() if row["status"] == "blocked"}
for requirement_id in [
    "v52-f-disposition-defined",
    "v53-complete-source-repo-lock",
    "v53-complete-source-query-set",
    "v53-core-answer-citation-resource-surface",
    "v53-symmetric-scorer-policy-surface",
    "v53-review-packet-ready",
    "v61-real-manifest-fixture-replacement",
    "v61-full-checkpoint-materialization",
    "v61-full-safetensors-page-hash-binding",
    "v61-rocm-page-kernel-measurement",
    "v61-kv-residency-eviction-policy",
    "v61-source-bound-qa-command-pass",
    "v61-complete-source-runtime-admission",
    "v61-return-bundle-handoff-ready",
]:
    if requirement_id not in ready_ids:
        raise SystemExit(f"v61dx requirement should be ready: {requirement_id}")
for requirement_id in [
    "v52-ready-condition-passes",
    "v52-30b-150b-wording-disclosure",
    "v53-human-review-return-accepted",
    "v53-adjudication-return-accepted",
    "v61-generation-execution-admission",
    "v61-generation-result-artifact-acceptance",
    "v61-actual-model-generation",
    "v61-production-latency-claim",
    "v61-near-frontier-quality-claim",
    "v61-release-package-ready",
]:
    if requirement_id not in blocked_ids:
        raise SystemExit(f"v61dx requirement should stay blocked: {requirement_id}")

claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "active_goal_claim_boundary_rows.csv")}
for claim_id in [
    "v53-machine-complete-source-surface",
    "v61-full-shard-runtime-evidence",
    "v61-return-bundle-operator-handoff",
]:
    if not claims[claim_id].startswith("allowed"):
        raise SystemExit(f"v61dx claim should be allowed/boundary: {claim_id}")
for claim_id in [
    "v52-30b-150b-comparison-wording",
    "v53-ready",
    "actual-mixtral-generation",
    "production-latency",
    "near-frontier-quality",
    "v1.0-comparison-ready",
    "real-release-package",
]:
    if claims[claim_id] != "blocked":
        raise SystemExit(f"v61dx claim should be blocked: {claim_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "active-goal-status-audit",
    "v52-f-optional-final-policy",
    "v53-machine-complete-source-surface",
    "v61-real-model-runtime-evidence",
    "v61-return-handoff-bundle",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dx decision should pass: {gate}")
for gate in [
    "v52-ready-condition",
    "v53-review-return",
    "v61-actual-model-generation",
    "v1-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dx decision should stay blocked: {gate}")

boundary = (run_dir / "V61DX_ACTIVE_GOAL_STATUS_AUDIT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v52_ready=0",
    "F=deferred-with-reason-final",
    "comparison_30b_150b_wording_status=blocked",
    "v53_machine_complete_source_surface_ready=1",
    "complete_source_query_rows=1000",
    "v61_post_full_shard_runtime_evidence_ready=1",
    "ready_checkpoint_materialization_shard_rows=59/59",
    "total_verified_page_hash_rows=134161/134161",
    "source_bound_query_pass_rows=37/37",
    "runtime_admission_accepted_rows=1000/1000",
    "return_handoff_bundle_ready=1",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dx boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dx_active_goal_status_audit_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dx_active_goal_status_audit_gate_ready") != 1:
    raise SystemExit("v61dx manifest readiness mismatch")
if manifest.get("v53_ready") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dx manifest must keep v53/generation blocked")
if manifest.get("v1_0_comparison_ready") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v61dx manifest must keep v1/release blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dx manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dx sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dx produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dx active goal status audit gate smoke passed"
