#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v59e_one_command_pm_foundation_demo/pm_foundation_001"
SUMMARY_CSV="$RESULTS_DIR/v59e_one_command_pm_foundation_demo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v59e_one_command_pm_foundation_demo_decision.csv"
PR_SLICE_RUN_DIR="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate/gate_001"
PR_SLICE_SUMMARY_CSV="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate_summary.csv"

"$ROOT_DIR/examples/v1_0_architecture_challenge_pm_foundation_demo.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PR_SLICE_RUN_DIR" "$PR_SLICE_SUMMARY_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
pr_slice_run_dir = Path(sys.argv[4])
pr_slice_summary_csv = Path(sys.argv[5])


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
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "v59_ready": "0",
    "one_command_entrypoint_ready": "1",
    "challenge_bundle_ready": "1",
    "stage_rows": "6",
    "ready_stage_rows": "6",
    "full_ready_stage_rows": "1",
    "pinned_public_sources_verified": "1",
    "pm_v53_freeze_ready": "1",
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "local_abgh_baseline_run_ready": "1",
    "local_abgh_row_contract_replay_ready": "0",
    "local_abgh_deterministic_adapter_ready": "1",
    "v53ap_expected_answer_oracle_replay": "0",
    "v53ap_deterministic_source_span_adapter_execution": "1",
    "v53ap_deterministic_source_span_adapter_rows": "4000",
    "v53ap_actual_adapter_execution_ready": "1",
    "v53ap_real_system_performance_claim_ready": "0",
    "same_query_abgh_ready": "1",
    "route_memory_artifact_ready": "1",
    "v54c_complete_source_grounded_generation_1000_ready": "1",
    "grounded_generation_outputs_ready": "1",
    "v54c_v53ap_evaluator_provenance_ready": "1",
    "v54c_v53ap_evaluator_provenance_rows": "1000",
    "v54c_v53ap_answer_eval_separate_rows": "1000",
    "v54c_v53ap_citation_eval_separate_rows": "1000",
    "v54c_v53ap_resource_eval_separate_rows": "1000",
    "h10_real_label_readiness_gate_ready": "1",
    "h10_real_label_promotion_ready": "0",
    "v58_pm_blind_eval_blocker_ready": "1",
    "v58c_intake_artifact_available": "0",
    "v58c_dependency_blocker_ready": "1",
    "v58c_blind_response_evidence_intake_ready": "0",
    "v58c_expected_blind_response_rows": "0",
    "v58c_required_blind_response_ready": "0",
    "v58c_blind_response_absorb_ready": "0",
    "v58c_human_blind_review_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "answer_citation_separate_eval": "1",
    "blocker_false_positive_closed": "1",
    "undocumented_local_state_required": "0",
    "private_fixture_required": "0",
    "manual_postprocessing_required": "0",
    "network_required": "0",
    "downloads_required": "0",
    "full_v1_public_demo_ready": "0",
    "real_release_package_ready": "0",
    "pm_pr_claim_slice_gate_ready": "1",
    "pm_pr_claim_slice_bundle_ready": "1",
    "pm_pr_recommended_slice_rows": "10",
    "pm_pr_merge_gate_rows": "30",
    "pm_pr_current_merge_ready_rows": "9",
    "pm_pr_current_blocked_rows": "1",
    "pm_pr_tests_only_merge_condition_rows": "0",
    "pm_pr_review_packet_rows": "10",
    "pm_pr_review_packet_files": "10",
    "pm_pr_review_packet_bundle_ready": "1",
    "pm_blocker_closure_packet_rows": "6",
    "pm_blocker_closure_packet_files": "6",
    "pm_blocker_closure_packet_bundle_ready": "1",
    "pm_blocker_required_artifact_rows": "22",
    "pm_blocker_required_artifact_fixture_allowed_rows": "0",
    "pm_execution_lock_rows": "10",
    "pm_execution_lock_active_rows": "10",
    "pm_scope_drift_allowed": "0",
    "pm_new_scaffold_default_allowed": "0",
    "pm_external_return_template_rows": "22",
    "pm_external_return_template_files": "22",
    "pm_external_return_template_fixture_allowed_rows": "0",
    "pm_external_return_template_approval_rows": "22",
    "pm_external_return_template_bundle_ready": "1",
    "pm_roadmap_requirement_rows": "19",
    "pm_roadmap_ready_rows": "13",
    "pm_roadmap_blocked_rows": "6",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v59e {field}: expected {value}, got {summary.get(field)}")
if int(summary["bundle_files"]) < 35:
    raise SystemExit("v59e should copy a substantial PM foundation bundle")

stage_rows = read_csv(run_dir / "pm_foundation_stage_replay_rows.csv")
if [row["stage"] for row in stage_rows] != ["v53t", "v53ap", "v54c", "h10_pm", "v58c_dependency", "v58_blocker"]:
    raise SystemExit("v59e stage order mismatch")
if any(row["ready"] != "1" for row in stage_rows):
    raise SystemExit("v59e all PM stages should be replay-ready")
if [row["full_ready"] for row in stage_rows] != ["0", "0", "1", "0", "0", "0"]:
    raise SystemExit("v59e should only mark v54 generation as full-ready")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "pinned-public-sources-verified",
    "complete-source-query-freeze",
    "route-memory-artifact-built",
    "local-abgh-baseline-run",
    "local-abgh-deterministic-adapter-run",
    "evaluator-check",
    "grounded-generation-outputs",
    "h10-real-label-readiness-ledger",
    "v58c-intake-dependency-blocker",
    "v58-blind-eval-blocker-ledger",
    "no-hidden-local-state",
    "blocker-false-positive-closed",
    "one-command-entrypoint",
    "challenge-bundle-written",
    "pm-pr-claim-slice-gate",
    "pm-execution-lock",
    "pm-external-return-templates",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v59e gate should pass: {gate}")
for gate in ["v58-blind-response-intake", "real-blind-eval", "full-v59-public-demo", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v59e gate should remain blocked: {gate}")

required_files = [
    "pm_foundation_stage_replay_rows.csv",
    "pm_foundation_one_command_rows.csv",
    "challenge_bundle_file_rows.csv",
    "pm_foundation_demo_gate_rows.csv",
    "pm_foundation_demo.sh",
    "README_RESULT.md",
    "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md",
    "v59e_one_command_pm_foundation_demo_manifest.json",
    "sha256_manifest.csv",
    "source_v53t/complete_source_pm_freeze_check_rows.csv",
    "source_v53ap/abgh_answer_rows.csv",
    "source_v53ap/abgh_citation_rows.csv",
    "source_v53ap/abgh_evaluator_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v54c/answer_rows.csv",
    "source_v54c/generator_input_rows.csv",
    "source_v54c/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v54c/source_v53ap/abgh_evaluator_rows.csv",
    "source_v54c/sha256sums.txt",
    "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_h10_pm/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53ap/abgh_evaluator_rows.csv",
    "source_v58c_dependency/v58c_pm_blind_response_intake_dependency_rows.csv",
    "source_v58_blocker/v58_pm_blind_eval_blocker_rows.csv",
    "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_summary.csv",
    "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_decision.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_slice_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_merge_gate_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_review_packet_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_blocker_closure_packet_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_pm_pr_claim_slice_gate/review_packets/docs__v1-roadmap.md",
    "source_pm_pr_claim_slice_gate/blocker_packets/v58c-intake-artifact-missing.md",
    "source_pm_pr_claim_slice_gate/blocker_packets/v58-real-blind-eval-missing.md",
    "source_pm_pr_claim_slice_gate/return_templates/v58c-intake-artifact-missing/v58c-intake-summary.csv",
    "source_pm_pr_claim_slice_gate/return_templates/external-human-label-evidence-missing/h10-label-evidence-csv.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v59e artifact: {rel}")

manifest = json.loads((run_dir / "v59e_one_command_pm_foundation_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v59e_one_command_pm_foundation_demo_ready") != 1 or manifest.get("v59_ready") != 0:
    raise SystemExit("v59e manifest readiness mismatch")
if "h10-real-label-promotion" not in manifest.get("blocked_claims", []):
    raise SystemExit("v59e manifest should block h10 real-label promotion")
if "real-abgh-system-performance" not in manifest.get("blocked_claims", []):
    raise SystemExit("v59e manifest should block real A/B/G/H system performance claims")
if (
    manifest.get("local_abgh_row_contract_replay_ready") != 0
    or manifest.get("local_abgh_deterministic_adapter_ready") != 1
    or manifest.get("v53ap_expected_answer_oracle_replay") != 0
    or manifest.get("v53ap_deterministic_source_span_adapter_execution") != 1
    or manifest.get("v53ap_deterministic_source_span_adapter_rows") != 4000
    or manifest.get("v53ap_actual_adapter_execution_ready") != 1
):
    raise SystemExit("v59e manifest should preserve the v53ap deterministic adapter boundary")
if (
    manifest.get("v58c_intake_artifact_available") != 0
    or manifest.get("v58c_dependency_blocker_ready") != 1
    or manifest.get("v58c_blind_response_evidence_intake_ready") != 0
    or manifest.get("v58c_expected_blind_response_rows") != 0
    or manifest.get("v58c_required_blind_response_ready") != 0
    or manifest.get("v58c_human_blind_review_ready") != 0
):
    raise SystemExit("v59e manifest should preserve the v58c blind-response intake blocker boundary")
if manifest.get("pm_pr_claim_slice_bundle_ready") != 1:
    raise SystemExit("v59e manifest should include the PM PR sidecar bundle")
if manifest.get("pm_scope_drift_allowed") != 0:
    raise SystemExit("v59e manifest should keep PM scope drift locked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v59e sha256 mismatch: {rel}")

boundary = (run_dir / "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v59e_one_command_pm_foundation_demo_ready=1",
    "pm_v53_freeze_ready=1",
    "local_abgh_row_contract_replay_ready=0",
    "local_abgh_deterministic_adapter_ready=1",
    "v53ap_expected_answer_oracle_replay=0",
    "v53ap_deterministic_source_span_adapter_execution=1",
    "v53ap_deterministic_source_span_adapter_rows=4000",
    "v53ap_actual_adapter_execution_ready=1",
    "v54c_v53ap_evaluator_provenance_ready=1",
    "v54c_v53ap_evaluator_provenance_rows=1000",
    "h10_real_label_promotion_ready=0",
    "v58c_intake_artifact_available=0",
    "v58c_dependency_blocker_ready=1",
    "v58c_blind_response_evidence_intake_ready=0",
    "v58c_expected_blind_response_rows=0",
    "v58c_required_blind_response_ready=0",
    "v58c_human_blind_review_ready=0",
    "v58_full_blind_eval_ready=0",
    "pm_pr_claim_slice_bundle_ready=1",
    "pm_scope_drift_allowed=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v59e boundary missing: {snippet}")

pr_summary = read_csv(pr_slice_summary_csv)[0]
if pr_summary.get("v1_0_pm_pr_claim_slice_gate_ready") != "1":
    raise SystemExit("v59e one-command should refresh the PM PR claim slice gate")
if pr_summary.get("recommended_pr_slice_rows") != "10" or pr_summary.get("merge_gate_rows") != "30":
    raise SystemExit("v59e one-command PR slice gate should expose ten slices and 30 merge gates")
if pr_summary.get("tests_only_merge_condition_rows") != "0":
    raise SystemExit("v59e one-command PR slice gate must keep tests-only merge conditions forbidden")
if pr_summary.get("real_release_package_ready") != "0":
    raise SystemExit("v59e one-command PR slice gate must keep release blocked")
if pr_summary.get("pm_pr_review_packet_files") != "10":
    raise SystemExit("v59e one-command PR slice gate should emit ten review packets")
if pr_summary.get("pm_blocker_closure_packet_files") != "6":
    raise SystemExit("v59e one-command PR slice gate should emit six blocker packets")
if pr_summary.get("pm_execution_lock_rows") != "10" or pr_summary.get("pm_scope_drift_allowed") != "0":
    raise SystemExit("v59e one-command PR slice gate should keep the PM execution lock active")
if pr_summary.get("pm_external_return_template_files") != "22" or pr_summary.get("pm_external_return_template_fixture_allowed_rows") != "0":
    raise SystemExit("v59e one-command PR slice gate should emit no-fixture return templates")

pr_slice_rows = read_csv(pr_slice_run_dir / "pm_pr_slice_rows.csv")
if len(pr_slice_rows) != 10:
    raise SystemExit("v59e one-command should emit ten PM PR slice rows")
v56_rows = [row for row in pr_slice_rows if row["slice_id"] == "v56-ruler-longbench-expanded"]
if len(v56_rows) != 1:
    raise SystemExit("v59e one-command PR slice gate should include v56")
if v56_rows[0]["current_status"] != "blocked-missing-replay-artifact":
    raise SystemExit("v59e one-command should keep v56 blocked when replay artifact is absent")
if v56_rows[0]["replay_artifact_ok"] != "0" or v56_rows[0]["blocker_false_positive_closed"] != "1":
    raise SystemExit("v59e one-command should expose v56 as replay-blocked, not false-positive-open")
PY

echo "v59e one-command PM foundation demo smoke passed"
