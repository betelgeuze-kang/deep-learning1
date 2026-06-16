#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v60_architecture_challenge_release_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v60_architecture_challenge_release_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v60_architecture_challenge_release_contract_decision.csv"

"$ROOT_DIR/experiments/run_v60_architecture_challenge_release_contract.sh" >/dev/null

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
    raise SystemExit(f"expected one v60 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v60_release_contract_ready": "1",
    "v60_ready": "0",
    "release_requirement_rows": "14",
    "release_requirement_ready_rows": "6",
    "release_requirement_blocked_rows": "8",
    "allowed_claim_rows": "3",
    "forbidden_claim_rows": "11",
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "source_snapshot_replay_used": "1",
    "public_source_download_executed": "0",
    "public_source_download_approval_required": "1",
    "full_public_source_download_ready": "0",
    "pm_pr_claim_slice_bundle_ready": "1",
    "pm_scope_drift_allowed": "0",
    "pm_external_return_template_rows": "24",
    "one_command_replay_preflight_ready": "1",
    "v59_ready": "0",
    "required_30b_70b_baselines_ready": "0",
    "real_30b_70b_rows_ready": "0",
    "public_repo_query_scale_ready": "1",
    "local_abgh_prebaseline_ready": "1",
    "h10_real_label_promotion_ready": "0",
    "h10_source_verified_eval_ready": "0",
    "h10_external_human_label_evidence_ready": "0",
    "h10_pm_criteria_rows": "6",
    "h10_pm_criteria_ready": "1",
    "h10_pm_external_label_blocked": "1",
    "h10_pm_source_provenance_binding_ready": "1",
    "h10_pm_copied_files": "10",
    "routehint_generation_main_ready": "1",
    "scaling_law_main_ready": "0",
    "expanded_benchmark_ready": "0",
    "domain_expert_pack_ready": "0",
    "v58c_blind_response_intake_ready": "0",
    "v58c_intake_artifact_available": "0",
    "v58c_dependency_blocker_ready": "1",
    "v58d_blind_review_return_intake_ready": "0",
    "v58d_review_artifact_available": "0",
    "v58d_dependency_blocker_ready": "1",
    "v58d_human_blind_review_ready": "0",
    "v58d_inter_rater_rows_ready": "0",
    "blind_eval_ready": "0",
    "one_command_pm_foundation_ready": "1",
    "one_command_real_replay_ready": "0",
    "human_release_review_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v60 {field}: expected {value}, got {summary.get(field)}")
if summary.get("v59_one_command_challenge_demo_contract_ready") not in {"0", "1"}:
    raise SystemExit("v60 legacy v59 contract readiness should be explicit")
if summary.get("legacy_v59_contract_source_ready") not in {"0", "1"}:
    raise SystemExit("v60 legacy v59 source readiness should be explicit")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v60-release-contract",
    "v59e-pm-foundation-input",
    "pm-pr-claim-slice-input",
    "claim-boundary",
    "v53-foundation-freeze",
    "local-abgh-prebaseline",
    "v54-grounded-generation-1000",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v60 gate should pass: {gate}")
if decisions.get("v59-contract-input") not in {"pass", "blocked"}:
    raise SystemExit("v60 legacy v59 input gate should be explicit")
for gate in [
    "real-30b-70b-baselines",
    "h10-real-label-promotion",
    "v56-replay-artifact",
    "v58c-blind-response-intake",
    "v58-real-blind-eval",
    "full-v59-public-demo",
    "human-release-review",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v60 gate should remain blocked: {gate}")

required_files = [
    "release_requirement_rows.csv",
    "allowed_claim_rows.csv",
    "forbidden_claim_rows.csv",
    "release_decision_rows.csv",
    "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md",
    "v60_architecture_challenge_release_manifest.json",
    "sha256_manifest.csv",
    "legacy_v59_contract_source_rows.csv",
    "source_v59e/pm_foundation_stage_replay_rows.csv",
    "source_v59e/pm_foundation_one_command_rows.csv",
    "source_v59e/pm_foundation_replay_preflight_rows.csv",
    "source_v59e/public_source_replay_policy_rows.csv",
    "source_v59e/challenge_bundle_file_rows.csv",
    "source_v59e/pm_foundation_demo_gate_rows.csv",
    "source_v59e/README_RESULT.md",
    "source_v59e/V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md",
    "source_v59e/v59e_one_command_pm_foundation_demo_manifest.json",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_slice_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_pr_review_packet_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_closure_queue_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_template.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_v59e/source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_v59e/source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v59e/source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v59e/source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_query_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_span_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_answer_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_citation_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_evaluator_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_resource_rows.csv",
    "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v59e/v58c_pm_blind_response_intake_dependency_summary.csv",
    "source_v59e/v58c_pm_blind_response_intake_dependency_rows.csv",
    "source_v59e/v58d_pm_blind_review_return_dependency_summary.csv",
    "source_v59e/v58d_pm_blind_review_return_dependency_rows.csv",
    "source_v59e/v59e_one_command_pm_foundation_demo_summary.csv",
    "source_pm_pr/v1_0_pm_pr_claim_slice_gate_summary.csv",
    "source_summaries/v52_llm_rag_baseline_war_summary.csv",
    "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "source_summaries/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
    "source_summaries/v10_h10_real_label_promotion_readiness_gate_summary.csv",
    "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_h10_pm/h10_real_label_evidence_template.csv",
    "source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v60 artifact: {rel}")

v60_pm_v53t_real_adapter_rows = {
    row["criterion_id"]: row
    for row in read_csv(run_dir / "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")
}
if len(v60_pm_v53t_real_adapter_rows) != 4:
    raise SystemExit("v60 should carry four v53t real-adapter freeze rows through v59e/PM sidecar")
if v60_pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["status"] != "pass":
    raise SystemExit("v60 should carry passing v53t real-adapter execution evidence")
if "coherent_wrong_key_rows=288" not in v60_pm_v53t_real_adapter_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("v60 should preserve v53aq coherent wrong-key evidence")
if "public_comparison_claim_ready=0" not in v60_pm_v53t_real_adapter_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("v60 should preserve v53aq public comparison blocker")

requirements = read_csv(run_dir / "release_requirement_rows.csv")
if len(requirements) != 14:
    raise SystemExit("v60 should list fourteen release requirements")
ready_reqs = {row["requirement"] for row in requirements if row["ready"] == "1" and row["status"] == "pass"}
expected_ready = {
    "v52_baseline_registry_contract",
    "v53_public_repo_source_bound_1000_corpus",
    "v53_abgh_same_query_internal_prebaseline",
    "v54_grounded_generation_1000",
    "v59_pm_foundation_one_command_bundle",
    "pm_pr_claim_slice_gate_and_execution_lock",
}
if ready_reqs != expected_ready:
    raise SystemExit(f"v60 ready requirements mismatch: {ready_reqs}")
blocked_reqs = {row["requirement"] for row in requirements if row["ready"] == "0" and row["status"] == "blocked"}
for requirement in [
    "required_30b_70b_symmetric_baselines",
    "h10_real_label_source_verified_scorer",
    "v56_expanded_ruler_longbench_replay_artifact",
    "v58c_blind_response_intake_artifact",
    "v58_real_blind_eval",
    "full_v59_public_demo_real_replay",
    "human_release_review",
    "release_artifact_package",
]:
    if requirement not in blocked_reqs:
        raise SystemExit(f"v60 requirement should remain blocked: {requirement}")
for row in requirements:
    evidence_path = run_dir / row["evidence_path"]
    if not evidence_path.is_file() or evidence_path.stat().st_size == 0:
        raise SystemExit(f"v60 requirement evidence path is not replayable: {row['requirement']} -> {row['evidence_path']}")
h10_req = next(row for row in requirements if row["requirement"] == "h10_real_label_source_verified_scorer")
if h10_req["evidence_path"] != "source_h10_pm/pm_h10_real_label_acceptance_rows.csv":
    raise SystemExit("v60 h10 requirement should point directly at PM h10 criteria rows")
h10_rows = read_csv(run_dir / h10_req["evidence_path"])
expected_h10_criteria = {
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
}
if {row["criterion"] for row in h10_rows} != expected_h10_criteria:
    raise SystemExit("v60 h10 PM criteria rows should cover all six PM scorer criteria")
h10_by_criterion = {row["criterion"]: row for row in h10_rows}
if h10_by_criterion["source-provenance-binding"]["machine_evidence_status"] != "pass":
    raise SystemExit("v60 h10 source provenance criterion should carry pass machine evidence")
if "v53ap_evaluator_rows=4000" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53ap evaluator rows")
if "v53t_real_adapter_freeze_rows=4" not in h10_by_criterion["source-provenance-binding"]["evidence"]:
    raise SystemExit("v60 h10 source provenance criterion should bind v53t real-adapter freeze rows")
if h10_by_criterion["external-human-label-evidence"]["real_label_status"] != "blocked":
    raise SystemExit("v60 h10 external/human label criterion should remain blocked")

allowed = read_csv(run_dir / "allowed_claim_rows.csv")
for claim in ["architecture-challenge-contract-scaffold", "pm-foundation-replay-bundle", "local-architecture-preview"]:
    if claim not in {row["claim_id"] for row in allowed}:
        raise SystemExit(f"v60 allowed claim missing {claim}")

forbidden = {row["claim_id"] for row in read_csv(run_dir / "forbidden_claim_rows.csv")}
for claim in [
    "v1_0_release_ready",
    "beats_30b_150b_llm_rag",
    "public_comparison_win",
    "h10_scientific_contribution_claim",
    "v59_public_demo_complete",
    "transformer_replacement",
    "frontier_local_llm_equivalence",
    "long_context_solved",
    "gpu_or_hip_acceleration",
    "expert_replacement",
    "production_release",
]:
    if claim not in forbidden:
        raise SystemExit(f"v60 forbidden claim missing {claim}")

manifest = json.loads((run_dir / "v60_architecture_challenge_release_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v60_release_contract_ready") != 1 or manifest.get("v60_ready") != 0:
    raise SystemExit("v60 manifest readiness boundary mismatch")
if manifest.get("real_release_package_ready") != 0 or manifest.get("release_requirement_blocked_rows") != 8:
    raise SystemExit("v60 manifest should keep release blocked")
if manifest.get("release_requirement_ready_rows") != 6:
    raise SystemExit("v60 manifest should record six PM-foundation ready requirements")
if manifest.get("h10_pm_criteria_rows") != 6 or manifest.get("h10_pm_criteria_ready") != 1:
    raise SystemExit("v60 manifest should record direct h10 PM criteria evidence")
if manifest.get("h10_pm_external_label_blocked") != 1 or manifest.get("h10_pm_source_provenance_binding_ready") != 1:
    raise SystemExit("v60 manifest should preserve h10 blocker/provenance boundary")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v60 sha256 mismatch: {rel}")

boundary = (run_dir / "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed v1.0 Architecture Challenge Release",
    "Allowed wording",
    "v53 10-repo / 1000 source-span-bound query PM freeze",
    "real 30B/70B LLM+RAG comparison rows",
    "h10 real external/human label promotion evidence",
    "h10 PM criteria rows",
    "v58c blind-response intake artifact",
    "v58d blind-review/adjudication return artifact",
    "approved public-source download/refresh evidence",
    "Do not publish v1.0 release",
]:
    if snippet not in boundary:
        raise SystemExit(f"v60 boundary missing {snippet}")
PY

echo "v60 architecture challenge release contract smoke passed"
