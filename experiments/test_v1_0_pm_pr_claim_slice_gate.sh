#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate_decision.csv"

"$ROOT_DIR/experiments/run_v1_0_pm_pr_claim_slice_gate.sh" >/dev/null

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
    "v1_0_pm_pr_claim_slice_gate_ready": "1",
    "recommended_pr_slice_rows": "10",
    "merge_condition_defined_rows": "10",
    "merge_gate_rows": "30",
    "blocker_false_positive_pass_rows": "10",
    "pm_roadmap_requirement_rows": "20",
    "pm_roadmap_ready_rows": "14",
    "pm_roadmap_blocked_rows": "6",
    "pm_foundation_ready": "1",
    "v53_foundation_freeze_certificate_rows": "10",
    "v53_foundation_machine_freeze_ready": "1",
    "v53_foundation_query_span_binding_audit_ready": "1",
    "v53_foundation_query_span_binding_audit_rows": "1000",
    "v53_foundation_query_span_binding_pass_rows": "1000",
    "v53_foundation_direct_pinned_manifest_ready": "1",
    "v53_foundation_direct_repo_manifest_rows": "10",
    "v53_foundation_direct_file_manifest_rows": "11266",
    "v53_foundation_direct_content_snapshot_rows": "11266",
    "v53_pm_acceptance_evidence_rows": "10",
    "v53_pm_acceptance_evidence_ready_rows": "10",
    "v53_pm_acceptance_evidence_tests_only_rows": "0",
    "h10_real_label_acceptance_evidence_rows": "6",
    "h10_real_label_acceptance_evidence_ready_rows": "6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows": "0",
    "h10_real_label_acceptance_evidence_tests_only_rows": "0",
    "pm_pr_slice_file_rows": "41",
    "pm_pr_slice_file_existing_rows": "41",
    "pm_pr_slices_with_file_rows": "10",
    "pm_pr_slice_verification_rows": "17",
    "pm_pr_slices_with_verification_rows": "10",
    "pm_pr_claim_boundary_rows": "10",
    "pm_pr_claim_boundary_pass_rows": "10",
    "pm_pr_review_packet_rows": "10",
    "pm_pr_review_packet_files": "10",
    "pm_pr_review_packet_ready_rows": "10",
    "pm_pr_review_packet_blocked_slice_rows": "1",
    "pm_pr_acceptance_evidence_rows": "10",
    "pm_pr_acceptance_evidence_ready_rows": "9",
    "pm_pr_acceptance_evidence_blocked_rows": "1",
    "pm_pr_acceptance_evidence_tests_only_rows": "0",
    "v56_replay_acceptance_evidence_rows": "4",
    "v56_replay_acceptance_evidence_ready_rows": "0",
    "v56_replay_acceptance_evidence_blocked_rows": "4",
    "v56_replay_acceptance_evidence_tests_only_rows": "0",
    "v56_replay_acceptance_evidence_fixture_allowed_rows": "0",
    "v56_replay_acceptance_evidence_approval_rows": "4",
    "pm_blocker_closure_queue_rows": "6",
    "pm_blocker_closure_deferred_rows": "6",
    "pm_blocker_closure_approval_required_rows": "6",
    "pm_blocker_closure_packet_rows": "6",
    "pm_blocker_closure_packet_files": "6",
    "pm_blocker_closure_packet_ready_rows": "6",
    "pm_blocker_closure_packet_approval_rows": "6",
    "pm_blocker_required_artifact_rows": "26",
    "pm_blocker_required_artifact_approval_rows": "26",
    "pm_blocker_required_artifact_fixture_allowed_rows": "0",
    "pm_execution_lock_rows": "10",
    "pm_execution_lock_active_rows": "10",
    "pm_scope_drift_allowed": "0",
    "pm_new_scaffold_default_allowed": "0",
    "pm_external_return_template_rows": "26",
    "pm_external_return_template_files": "26",
    "pm_external_return_template_ready_rows": "26",
    "pm_external_return_template_fixture_allowed_rows": "0",
    "pm_external_return_template_approval_rows": "26",
    "draft_pr_2_split_required": "1",
    "tests_only_merge_condition_rows": "0",
    "full_v1_release_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"PM PR slice gate {field}: expected {value}, got {summary.get(field)}")
if int(summary["current_merge_ready_rows"]) < 8:
    raise SystemExit("PM PR slice gate should make most current slices reviewable")
if int(summary["claim_boundary_pass_rows"]) < 9:
    raise SystemExit("PM PR slice gate should keep claim boundaries explicit")

slice_rows = read_csv(run_dir / "pm_pr_slice_rows.csv")
expected_order = [
    "docs/v1-roadmap",
    "v52-baseline-registry-contract",
    "v53-public-repo-source-manifest",
    "v53-query-instantiation-1000",
    "v53-system-a-b-g-h-measured",
    "v54-routehint-generation-contract",
    "v56-ruler-longbench-expanded",
    "v58-blind-eval-contract",
    "v59-one-command-demo",
    "v61-ssd-moe-runtime-roadmap",
]
if [row["slice_id"] for row in slice_rows] != expected_order:
    raise SystemExit("PM PR slice order mismatch")
if any(row["merge_condition_defined"] != "1" for row in slice_rows):
    raise SystemExit("every PM PR slice must define a merge condition")
if any(row["blocker_false_positive_closed"] != "1" for row in slice_rows):
    raise SystemExit("every PM PR slice must close false-positive blockers")
if any(row["merge_condition"].strip().lower() in {"tests pass", "test pass", "tests"} for row in slice_rows):
    raise SystemExit("tests-only merge conditions are forbidden")

claim_boundary_rows = read_csv(run_dir / "pm_pr_claim_boundary_rows.csv")
if len(claim_boundary_rows) != 10:
    raise SystemExit("PM PR claim boundary ledger should have ten rows")
if [row["slice_id"] for row in claim_boundary_rows] != expected_order:
    raise SystemExit("PM PR claim boundary order mismatch")
if any(row["claim_boundary_status"] != "pass" for row in claim_boundary_rows):
    raise SystemExit("every PM PR claim boundary row should pass")
claim_by_id = {row["slice_id"]: row for row in claim_boundary_rows}
for slice_id, forbidden in {
    "docs/v1-roadmap": "Transformer replacement",
    "v53-system-a-b-g-h-measured": "public comparison claim",
    "v56-ruler-longbench-expanded": "leaderboard claim",
    "v59-one-command-demo": "full v59 public challenge demo",
    "v61-ssd-moe-runtime-roadmap": "near-frontier quality",
}.items():
    if forbidden not in claim_by_id[slice_id]["blocked_claim"]:
        raise SystemExit(f"claim boundary should block {forbidden} for {slice_id}")
if "public-source download/refresh readiness" not in claim_by_id["v59-one-command-demo"]["blocked_claim"]:
    raise SystemExit("v59 claim boundary should block public-source download/refresh readiness")
if claim_by_id["v59-one-command-demo"]["evidence_path"] != "source_v59e/public_source_replay_policy_rows.csv":
    raise SystemExit("v59 claim boundary should bind to public source replay policy rows")
if claim_by_id["v53-public-repo-source-manifest"]["evidence_path"] != "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv":
    raise SystemExit("v53 source-manifest claim boundary should bind to direct repo coverage rows")

by_id = {row["slice_id"]: row for row in slice_rows}
for snippet in ["repo_manifest_rows=10", "file_manifest_rows=11266", "content_snapshot_rows=11266"]:
    if snippet not in by_id["v53-public-repo-source-manifest"]["reason"]:
        raise SystemExit(f"v53 source-manifest slice should expose direct manifest count: {snippet}")
if by_id["v53-system-a-b-g-h-measured"]["current_status"] != "ready-for-review":
    raise SystemExit("A/B/G/H slice should be ready for internal pre-baseline review")
if by_id["v59-one-command-demo"]["current_status"] != "pm-foundation-ready-full-demo-blocked":
    raise SystemExit("v59 slice should expose PM foundation readiness while blocking full demo")
if by_id["v61-ssd-moe-runtime-roadmap"]["current_status"] != "ready-for-rd-review":
    raise SystemExit("v61 slice should stay R&D-scoped")

gate_rows = read_csv(run_dir / "pm_pr_merge_gate_rows.csv")
if len(gate_rows) != 30:
    raise SystemExit("expected three gate rows per PR slice")
for slice_id in expected_order:
    gates = {row["gate"]: row["status"] for row in gate_rows if row["slice_id"] == slice_id}
    if set(gates) != {"claim-boundary", "replay-artifact", "blocker-false-positive"}:
        raise SystemExit(f"missing PR merge gates for {slice_id}")
    if gates["blocker-false-positive"] != "pass":
        raise SystemExit(f"false-positive blocker should pass for {slice_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for slice_id in ["docs/v1-roadmap", "v53-query-instantiation-1000", "v53-system-a-b-g-h-measured", "v54-routehint-generation-contract", "v59-one-command-demo"]:
    if decisions.get(slice_id) != "pass":
        raise SystemExit(f"core PM slice should pass current review gate: {slice_id}")

roadmap_rows = read_csv(run_dir / "pm_roadmap_requirement_rows.csv")
if len(roadmap_rows) != 20:
    raise SystemExit("PM roadmap requirement ledger should cover 20 current requirements")
roadmap_by_id = {row["requirement_id"]: row for row in roadmap_rows}
for requirement_id in [
    "pr-split-ledger",
    "merge-condition-boundary",
    "pinned-public-repo-manifest",
    "source-span-query-freeze",
    "negative-and-conflict-controls",
    "answer-citation-separated",
    "abgh-same-query-measured",
    "abgh-real-system-adapter-execution",
    "internal-pre-baseline-boundary",
    "h10-readiness-ledger",
    "v54-grounded-generation-outputs",
    "no-raw-prompt-stuffing",
    "v58-blind-eval-blocker-ledger",
    "v59-one-command-foundation",
]:
    if roadmap_by_id.get(requirement_id, {}).get("status") != "ready":
        raise SystemExit(f"PM roadmap requirement should be ready: {requirement_id}")
pinned_manifest_row = roadmap_by_id["pinned-public-repo-manifest"]
if pinned_manifest_row["evidence_path"] != "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv":
    raise SystemExit("PM pinned source manifest should bind directly to v53t copied repo coverage rows")
for snippet in [
    "foundation_direct_pinned_manifest_ready=1",
    "repo_manifest_rows=10",
    "file_manifest_rows=11266",
    "content_snapshot_rows=11266",
]:
    if snippet not in pinned_manifest_row["reason"]:
        raise SystemExit(f"PM pinned source manifest should expose {snippet}")
source_span_row = roadmap_by_id["source-span-query-freeze"]
if source_span_row["evidence_path"] != "source_v53t/complete_source_query_span_binding_audit_rows.csv":
    raise SystemExit("PM source-span query freeze should bind directly to the v53t binding audit rows")
for snippet in [
    "binding_audit_ready=1",
    "binding_audit_rows=1000",
    "binding_audit_pass_rows=1000",
]:
    if snippet not in source_span_row["reason"]:
        raise SystemExit(f"PM source-span query freeze should expose {snippet}")
answer_citation_row = roadmap_by_id["answer-citation-separated"]
if answer_citation_row["evidence_path"] != "source_v53t/source_v53ap/abgh_evaluator_rows.csv":
    raise SystemExit("PM answer/citation separation should bind directly to the v53t copied evaluator rows")
if "direct_separate_evaluator_rows=4000" not in answer_citation_row["reason"]:
    raise SystemExit("PM answer/citation separation should expose direct v53 evaluator row counts")
abgh_ready_row = roadmap_by_id["abgh-same-query-measured"]
if "deterministic_source_span_adapter_execution=1" not in abgh_ready_row["reason"]:
    raise SystemExit("PM A/B/G/H ready row should disclose deterministic source-span adapter execution")
if "real_system_performance_claim_ready=0" not in abgh_ready_row["reason"]:
    raise SystemExit("PM A/B/G/H ready row should keep real performance claim boundary closed")
abgh_real_row = roadmap_by_id["abgh-real-system-adapter-execution"]
if abgh_real_row["status"] != "ready":
    raise SystemExit("PM A/B/G/H real adapter execution should be ready after v53aq real-adapter run")
if abgh_real_row["evidence_path"] != "source_v59e/local_abgh_row_contract_replay_rows.csv":
    raise SystemExit("PM A/B/G/H real adapter row should bind directly to the v59e row-contract replay ledger")
for snippet in [
    "real_adapter_execution_ready=1",
    "actual_adapter_execution_ready=1",
    "selection_question_text_only=1",
    "selection_oracle_field_used=0",
    "deterministic_source_span_adapter_execution=0",
    "real_system_performance_claim_ready=1",
    "same_query_internal_prebaseline_rows_ready=1",
    "same_query_internal_prebaseline_rows=1000",
    "local_abgh_row_contract_replay_ready=1",
    "local_abgh_row_contract_replay_rows=2",
    "local_abgh_row_contract_replay_pass_rows=2",
    "answer_hash_match_rows=3713",
    "coherent_wrong_key_rows=287",
]:
    if snippet not in abgh_real_row["reason"]:
        raise SystemExit(f"PM A/B/G/H real adapter row should expose {snippet}")
h10_readiness_row = roadmap_by_id["h10-readiness-ledger"]
if h10_readiness_row["evidence_path"] != "source_h10_pm/pm_h10_real_label_acceptance_rows.csv":
    raise SystemExit("PM h10 readiness should bind directly to the h10 acceptance rows")
for snippet in [
    "criteria_rows=6",
    "return_contract_rows=6",
    "return_contract_ready_rows=6",
    "return_contract_pass_rows=0",
    "acceptance_evidence_rows=6",
    "acceptance_evidence_ready_rows=6",
    "acceptance_evidence_promotion_ready_rows=0",
    "acceptance_evidence_tests_only_rows=0",
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
    "v53aq_same_query_internal_prebaseline_rows=1000",
    "v53aq_same_query_internal_prebaseline_rows_ready=1",
]:
    if snippet not in h10_readiness_row["reason"]:
        raise SystemExit(f"PM h10 readiness row should expose {snippet}")
h10_acceptance_rows = read_csv(run_dir / "source_h10_pm/pm_h10_real_label_acceptance_rows.csv")
if len(h10_acceptance_rows) != 6:
    raise SystemExit("PM h10 acceptance source rows should expose six criteria")
h10_criteria = {row["criterion"]: row for row in h10_acceptance_rows}
h10_return_contract_rows = read_csv(run_dir / "source_h10_pm/h10_real_label_return_contract_rows.csv")
h10_return_contract_by_criterion = {row["criterion"]: row for row in h10_return_contract_rows}
h10_acceptance_evidence_rows = read_csv(run_dir / "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv")
h10_acceptance_evidence_by_criterion = {row["criterion"]: row for row in h10_acceptance_evidence_rows}
for criterion in [
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
]:
    if criterion not in h10_criteria:
        raise SystemExit(f"PM h10 acceptance source missing criterion: {criterion}")
if set(h10_return_contract_by_criterion) != set(h10_criteria):
    raise SystemExit("PM h10 return contract should cover the same six criteria as the acceptance rows")
if set(h10_acceptance_evidence_by_criterion) != set(h10_criteria):
    raise SystemExit("PM h10 acceptance evidence should cover the same six criteria as the acceptance rows")
if len(h10_acceptance_evidence_rows) != 6:
    raise SystemExit("PM h10 acceptance evidence source rows should expose six criteria")
for criterion, row in h10_acceptance_evidence_by_criterion.items():
    if row["claim_boundary_status"] != "pass" or row["output_artifact_replay_status"] != "pass":
        raise SystemExit(f"PM h10 acceptance evidence should pass claim/replay for {criterion}")
    if row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"PM h10 acceptance evidence should pass blocker false-positive closure for {criterion}")
    if row["acceptance_ready"] != "1" or row["promotion_ready"] != "0":
        raise SystemExit(f"PM h10 acceptance evidence should be contract-ready but promotion-blocked for {criterion}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"PM h10 acceptance evidence should not be tests-only for {criterion}")
    if row["pm_acceptance_row_path"] != "pm_h10_real_label_acceptance_rows.csv":
        raise SystemExit(f"PM h10 acceptance evidence should bind PM acceptance rows for {criterion}")
    if row["return_contract_path"] != "h10_real_label_return_contract_rows.csv":
        raise SystemExit(f"PM h10 acceptance evidence should bind return contract rows for {criterion}")
if any(row["fixture_allowed"] != "0" or row["approval_required"] != "1" for row in h10_return_contract_rows):
    raise SystemExit("PM h10 return contract should preserve no-fixture approval-required boundaries")
if any(row["contract_ready"] != "1" or row["acceptance_status"] != "blocked" for row in h10_return_contract_rows):
    raise SystemExit("PM h10 return contract should be ready but blocked without accepted labels")
if h10_return_contract_by_criterion["source-provenance-binding"]["evidence_column"] != "source_provenance_labels":
    raise SystemExit("PM h10 return contract should bind source provenance labels")
if "query_rows>=1000" not in h10_return_contract_by_criterion["external-human-label-evidence"]["external_label_dependency"]:
    raise SystemExit("PM h10 return contract should require 1000 query rows for external/human labels")
if h10_criteria["external-human-label-evidence"]["real_label_status"] != "blocked":
    raise SystemExit("PM h10 acceptance source should keep external/human evidence blocked")
if "v53ap_evaluator_rows=4000" not in h10_criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("PM h10 acceptance source should cite v53ap evaluator provenance")
if "v53aq_same_query_internal_prebaseline_rows=1000" not in h10_criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("PM h10 acceptance source should cite v53aq same-query prebaseline rows")
if "v53aq_same_query_internal_prebaseline_rows_ready=1" not in h10_criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("PM h10 acceptance source should cite v53aq same-query prebaseline readiness")
h10_v53aq_prebaseline_rows = read_csv(run_dir / "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
if len(h10_v53aq_prebaseline_rows) != 1000:
    raise SystemExit("PM h10 source bundle should carry 1000 v53aq same-query prebaseline rows")
if any(
    row["same_query_all_systems"] != "1"
    or row["same_evaluator_contract"] != "1"
    or row["same_resource_bound"] != "1"
    or row["selection_question_text_only_all"] != "1"
    or row["selection_oracle_field_used_any"] != "0"
    or row["expected_answer_oracle_replay_any"] != "0"
    or row["deterministic_source_span_adapter_execution_any"] != "0"
    or row["g_h_routehint_no_raw_context"] != "1"
    or row["public_comparison_claim_ready"] != "0"
    for row in h10_v53aq_prebaseline_rows
):
    raise SystemExit("PM h10 source bundle should preserve v53aq same-query/no-oracle/no-public-claim boundary")
v54_slice = by_id["v54-routehint-generation-contract"]
for snippet in ["answer=1000", "citation=1000", "unsupported=160", "abstain=160", "resource=1000", "guard=1000"]:
    if snippet not in v54_slice["reason"]:
        raise SystemExit(f"PM v54 slice should expose recommended output count: {snippet}")
v54_roadmap_row = roadmap_by_id["v54-grounded-generation-outputs"]
for snippet in [
    "answer_rows=1000",
    "citation_rows=1000",
    "unsupported_claim_rows=160",
    "abstain_rows=160",
    "generator_resource_rows=1000",
    "wrong_answer_guard_rows=1000",
]:
    if snippet not in v54_roadmap_row["reason"]:
        raise SystemExit(f"PM v54 roadmap row should expose recommended output count: {snippet}")
abgh_surface_row = roadmap_by_id["abgh-same-query-measured"]
for snippet in ["same_query=1", "same_source=1", "same_evaluator=1", "same_resource=1"]:
    if snippet not in abgh_surface_row["reason"]:
        raise SystemExit(f"PM A/B/G/H same-surface row should expose {snippet}")
v59_foundation_row = roadmap_by_id["v59-one-command-foundation"]
for snippet in ["local_abgh_row_contract_replay_ready=1", "public_source_download_executed=0", "full_public_source_download_ready=0", "policy_blocker=blocked-full-public-demo"]:
    if snippet not in v59_foundation_row["reason"]:
        raise SystemExit(f"PM v59 foundation row should expose {snippet}")
expected_blocked = {
    "v56-replay-artifact": "v56-replay-artifact-missing",
    "de-30b70b-symmetric-baselines": "de-30b70b-baselines-missing",
    "h10-real-label-promotion": "external-human-label-evidence-missing",
    "v58c-blind-response-intake-artifact": "v58c-intake-artifact-missing",
    "v58-full-blind-eval": "v58-real-blind-eval-missing",
    "v60-public-release-gate": "v60-release-evidence-missing",
}
for requirement_id, blocker in expected_blocked.items():
    row = roadmap_by_id.get(requirement_id)
    if row is None:
        raise SystemExit(f"missing PM roadmap blocker row: {requirement_id}")
    if row["status"] != "blocked" or row["blocker_class"] != blocker:
        raise SystemExit(f"PM roadmap blocker mismatch for {requirement_id}: {row}")

file_rows = read_csv(run_dir / "pm_pr_slice_file_rows.csv")
if len(file_rows) != 41:
    raise SystemExit("PM PR file ledger should have 41 rows")
if len({row["slice_id"] for row in file_rows}) != 10:
    raise SystemExit("PM PR file ledger should cover all ten slices")
if any(row["exists"] != "1" for row in file_rows):
    missing = [row for row in file_rows if row["exists"] != "1"]
    raise SystemExit(f"PM PR file ledger should only reference existing files: {missing}")
file_key = {(row["slice_id"], row["file_path"]): row for row in file_rows}
for key in [
    ("docs/v1-roadmap", "docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md"),
    ("v53-query-instantiation-1000", "experiments/run_v53i_complete_source_query_instantiation.sh"),
    ("v53-system-a-b-g-h-measured", "experiments/run_v53ap_complete_source_abgh_same_query_measured.sh"),
    ("v53-system-a-b-g-h-measured", "experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh"),
    ("v54-routehint-generation-contract", "experiments/run_v54c_complete_source_grounded_generation_1000.sh"),
    ("v56-ruler-longbench-expanded", "experiments/run_v56b_ruler_longbench_expanded_scale.sh"),
    ("v59-one-command-demo", "examples/v1_0_architecture_challenge_pm_foundation_demo.sh"),
]:
    if key not in file_key:
        raise SystemExit(f"PM PR file ledger missing {key}")

verification_rows = read_csv(run_dir / "pm_pr_slice_verification_rows.csv")
if len(verification_rows) != 17:
    raise SystemExit("PM PR verification ledger should have 17 rows")
if len({row["slice_id"] for row in verification_rows}) != 10:
    raise SystemExit("PM PR verification ledger should cover all ten slices")
verification_key = {(row["slice_id"], row["command"]): row for row in verification_rows}
for key in [
    ("v53-system-a-b-g-h-measured", "experiments/test_v53ap_complete_source_abgh_same_query_measured.sh"),
    ("v53-system-a-b-g-h-measured", "experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh"),
    ("v54-routehint-generation-contract", "experiments/test_v54c_complete_source_grounded_generation_1000.sh"),
    ("v56-ruler-longbench-expanded", "experiments/test_v56b_ruler_longbench_expanded_scale.sh"),
    ("v59-one-command-demo", "experiments/test_v59e_one_command_pm_foundation_demo.sh"),
]:
    if key not in verification_key:
        raise SystemExit(f"PM PR verification ledger missing {key}")
if verification_key[("v58-blind-eval-contract", "experiments/test_v58c_blind_response_evidence_intake.sh")]["execution_policy"] != "defer-until-real-response-evidence":
    raise SystemExit("v58 real response intake should be marked deferred until real evidence exists")

review_packet_rows = read_csv(run_dir / "pm_pr_review_packet_rows.csv")
if len(review_packet_rows) != 10:
    raise SystemExit("PM PR review packet ledger should have ten rows")
if [row["slice_id"] for row in review_packet_rows] != expected_order:
    raise SystemExit("PM PR review packet order mismatch")
for row in review_packet_rows:
    if row["packet_ready"] != "1":
        raise SystemExit(f"PM PR review packet should be ready: {row}")
    packet_path = run_dir / row["packet_path"]
    if not packet_path.is_file() or packet_path.stat().st_size == 0:
        raise SystemExit(f"missing PM PR review packet file: {row['packet_path']}")
    packet_text = packet_path.read_text(encoding="utf-8")
    for snippet in [
        "## Merge Condition",
        "This is not a tests-only merge condition",
        "## Allowed Claim",
        "## Blocked Claim",
        "## Verification",
    ]:
        if snippet not in packet_text:
            raise SystemExit(f"PM PR review packet missing snippet {snippet}: {row['packet_path']}")
    if row["packet_sha256"] != sha256(packet_path):
        raise SystemExit(f"PM PR review packet sha mismatch: {row['packet_path']}")
review_packet_by_id = {row["slice_id"]: row for row in review_packet_rows}
if review_packet_by_id["v56-ruler-longbench-expanded"]["next_action"] != "hold-until-replay-artifact-or-real-evidence":
    raise SystemExit("v56 review packet should stay held until replay artifact exists")
if review_packet_by_id["v53-system-a-b-g-h-measured"]["next_action"] != "review-local-slice":
    raise SystemExit("A/B/G/H review packet should be reviewable")
if "experiments/test_v58c_blind_response_evidence_intake.sh" not in review_packet_by_id["v58-blind-eval-contract"]["deferred_commands"]:
    raise SystemExit("v58 review packet should carry the deferred real-response command")
v59_packet_text = (run_dir / review_packet_by_id["v59-one-command-demo"]["packet_path"]).read_text(encoding="utf-8")
for snippet in ["public-source download/refresh readiness", "pinned-source snapshot replay", "network, downloads"]:
    if snippet not in v59_packet_text:
        raise SystemExit(f"v59 review packet should expose public-source replay boundary: {snippet}")

acceptance_rows = read_csv(run_dir / "pm_pr_acceptance_evidence_rows.csv")
if len(acceptance_rows) != 10:
    raise SystemExit("PM PR acceptance evidence ledger should have ten rows")
if [row["slice_id"] for row in acceptance_rows] != expected_order:
    raise SystemExit("PM PR acceptance evidence order mismatch")
acceptance_by_id = {row["slice_id"]: row for row in acceptance_rows}
if sum(row["acceptance_ready"] == "1" for row in acceptance_rows) != 9:
    raise SystemExit("PM PR acceptance evidence should mark nine slices ready")
if sum(row["acceptance_ready"] == "0" for row in acceptance_rows) != 1:
    raise SystemExit("PM PR acceptance evidence should mark one slice blocked")
if any(row["tests_only_merge_condition"] != "0" for row in acceptance_rows):
    raise SystemExit("PM PR acceptance evidence should forbid tests-only merge conditions")
if any(row["claim_boundary_status"] != "pass" for row in acceptance_rows):
    raise SystemExit("PM PR acceptance evidence should keep all claim boundaries passing")
if acceptance_by_id["v56-ruler-longbench-expanded"]["acceptance_ready"] != "0":
    raise SystemExit("v56 acceptance evidence should remain blocked until replay artifact evidence closes")
v56_replay_acceptance_rows = read_csv(run_dir / "v56_replay_acceptance_evidence_rows.csv")
if len(v56_replay_acceptance_rows) != 4:
    raise SystemExit("v56 replay acceptance evidence should cover four required artifacts")
v56_replay_artifacts = {row["artifact_id"]: row for row in v56_replay_acceptance_rows}
for artifact_id in ["v56-contract-summary", "v56-contract-artifacts", "v56b-scale-summary", "v56b-scale-artifacts"]:
    row = v56_replay_artifacts.get(artifact_id)
    if not row:
        raise SystemExit(f"v56 replay acceptance missing artifact row: {artifact_id}")
    if row["slice_id"] != "v56-ruler-longbench-expanded":
        raise SystemExit(f"v56 replay acceptance should stay bound to v56 slice: {artifact_id}")
    if row["claim_boundary_status"] != "pass":
        raise SystemExit(f"v56 claim boundary should remain closed for {artifact_id}")
    if row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"v56 blocker false-positive status should pass for {artifact_id}")
    if row["fixture_allowed"] != "0" or row["approval_required"] != "1":
        raise SystemExit(f"v56 replay artifact should require approval and forbid fixtures: {artifact_id}")
    if row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v56 replay artifact should not use tests-only acceptance: {artifact_id}")
    if row["acceptance_ready"] != "0" or row["acceptance_status"] != "blocked":
        raise SystemExit(f"v56 replay artifact should remain blocked without replay evidence: {artifact_id}")
    if row["output_artifact_replay_status"] != "blocked":
        raise SystemExit(f"v56 replay artifact status should be blocked until artifact is present: {artifact_id}")
if v56_replay_artifacts["v56b-scale-summary"]["artifact_path_or_env"] != "results/v56b_ruler_longbench_expanded_scale_summary.csv":
    raise SystemExit("v56b scale summary row should bind to the required summary path")
if "V56B_ALLOW_CONTRACT_REBUILD=1" not in v56_replay_artifacts["v56b-scale-artifacts"]["validation_command"]:
    raise SystemExit("v56b scale artifact row should expose the approval-gated validation command")
for slice_id in [
    "docs/v1-roadmap",
    "v53-public-repo-source-manifest",
    "v53-query-instantiation-1000",
    "v53-system-a-b-g-h-measured",
    "v54-routehint-generation-contract",
    "v59-one-command-demo",
]:
    row = acceptance_by_id[slice_id]
    if row["acceptance_ready"] != "1" or row["replay_artifact_status"] != "pass" or row["blocker_false_positive_status"] != "pass":
        raise SystemExit(f"PM PR acceptance evidence should make {slice_id} review-ready: {row}")
    if row["replay_artifact_present"] != "1":
        raise SystemExit(f"PM PR acceptance evidence should point {slice_id} at a copied replay artifact")
    if not (run_dir / row["review_packet_path"]).is_file():
        raise SystemExit(f"PM PR acceptance evidence should point {slice_id} at a review packet")
if acceptance_by_id["v53-query-instantiation-1000"]["replay_artifact_path"] != "source_v53t/complete_source_query_span_binding_audit_rows.csv":
    raise SystemExit("v53 query acceptance should bind directly to the 1000-row span-binding audit")
if acceptance_by_id["v53-system-a-b-g-h-measured"]["replay_artifact_path"] != "source_v59e/local_abgh_row_contract_replay_rows.csv":
    raise SystemExit("A/B/G/H acceptance should bind directly to the local row-contract replay ledger")
if "experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh" not in acceptance_by_id["v53-system-a-b-g-h-measured"]["local_smoke_commands"]:
    raise SystemExit("A/B/G/H acceptance should expose the v53aq real-adapter smoke command")
if acceptance_by_id["v59-one-command-demo"]["replay_artifact_path"] != "source_v59e/public_source_replay_policy_rows.csv":
    raise SystemExit("v59 acceptance should bind directly to public source replay policy rows")
if acceptance_by_id["v59-one-command-demo"]["blocker_evidence_path"] != "source_v59e/public_source_replay_policy_rows.csv":
    raise SystemExit("v59 acceptance blocker evidence should keep download/refresh readiness explicit")

closure_rows = read_csv(run_dir / "pm_blocker_closure_queue_rows.csv")
if len(closure_rows) != 6:
    raise SystemExit("PM blocker closure queue should cover the six current blockers")
closure_by_blocker = {row["blocker_class"]: row for row in closure_rows}
for blocker in expected_blocked.values():
    if blocker not in closure_by_blocker:
        raise SystemExit(f"missing blocker closure row: {blocker}")
for blocker, command_snippet in {
    "v56-replay-artifact-missing": "V56B_ALLOW_CONTRACT_REBUILD=1",
    "de-30b70b-baselines-missing": "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR>",
    "external-human-label-evidence-missing": "V10_H10_REAL_LABEL_EVIDENCE_CSV=<LABEL_CSV>",
    "v58c-intake-artifact-missing": "V58C_REUSE_EXISTING=0",
    "v58-real-blind-eval-missing": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR>",
    "v60-release-evidence-missing": "experiments/test_v60_architecture_challenge_release_contract.sh",
}.items():
    row = closure_by_blocker[blocker]
    if command_snippet not in row["local_intake_or_verification_command"]:
        raise SystemExit(f"blocker closure command mismatch for {blocker}: {row}")
    if not row["execution_policy"].startswith("defer-"):
        raise SystemExit(f"blocker closure should be deferred until real evidence: {blocker}")
    if "required" not in row["approval_required"]:
        raise SystemExit(f"blocker closure should require approval: {blocker}")
    if not row["claim_until_closed"]:
        raise SystemExit(f"blocker closure must state claim boundary: {blocker}")

blocker_packet_rows = read_csv(run_dir / "pm_blocker_closure_packet_rows.csv")
if len(blocker_packet_rows) != 6:
    raise SystemExit("PM blocker closure packet ledger should have six rows")
if [row["blocker_class"] for row in blocker_packet_rows] != list(expected_blocked.values()):
    raise SystemExit("PM blocker closure packet order mismatch")
for row in blocker_packet_rows:
    if row["packet_ready"] != "1":
        raise SystemExit(f"PM blocker closure packet should be ready: {row}")
    if not row["execution_policy"].startswith("defer-"):
        raise SystemExit(f"PM blocker closure packet should be deferred: {row}")
    if "required" not in row["approval_required"]:
        raise SystemExit(f"PM blocker closure packet should require approval: {row}")
    packet_path = run_dir / row["packet_path"]
    if not packet_path.is_file() or packet_path.stat().st_size == 0:
        raise SystemExit(f"missing PM blocker closure packet file: {row['packet_path']}")
    packet_text = packet_path.read_text(encoding="utf-8")
    for snippet in [
        "## Approval Required",
        "Do not execute automatically",
        "## Required Artifact Checklist",
        "## Local Intake Or Verification Command",
        "## Claim Until Closed",
    ]:
        if snippet not in packet_text:
            raise SystemExit(f"PM blocker closure packet missing snippet {snippet}: {row['packet_path']}")
    if row["packet_sha256"] != sha256(packet_path):
        raise SystemExit(f"PM blocker closure packet sha mismatch: {row['packet_path']}")
blocker_packet_by_id = {row["blocker_class"]: row for row in blocker_packet_rows}
if blocker_packet_by_id["de-30b70b-baselines-missing"]["required_artifact_rows"] != "4":
    raise SystemExit("D/E blocker packet should list four required artifact rows")
if blocker_packet_by_id["v60-release-evidence-missing"]["required_artifact_rows"] != "7":
    raise SystemExit("v60 blocker packet should list seven required artifact rows")
if blocker_packet_by_id["v58c-intake-artifact-missing"]["required_artifact_rows"] != "3":
    raise SystemExit("v58c blocker packet should list three required artifact rows")
if blocker_packet_by_id["v58-real-blind-eval-missing"]["required_artifact_rows"] != "5":
    raise SystemExit("v58 blocker packet should list five required artifact rows")
if "V58C_BLIND_RESPONSE_EVIDENCE_DIR" not in blocker_packet_by_id["v58-real-blind-eval-missing"]["local_intake_or_verification_command"]:
    raise SystemExit("v58 blocker packet should carry the real blind response intake command")
if "V58C_REUSE_EXISTING=0" not in blocker_packet_by_id["v58c-intake-artifact-missing"]["local_intake_or_verification_command"]:
    raise SystemExit("v58c blocker packet should carry the intake artifact rebuild command")

required_artifact_rows = read_csv(run_dir / "pm_blocker_required_artifact_rows.csv")
if len(required_artifact_rows) != 26:
    raise SystemExit("PM blocker required artifact ledger should have 26 rows")
if {row["blocker_class"] for row in required_artifact_rows} != set(expected_blocked.values()):
    raise SystemExit("PM blocker required artifact ledger should cover the six blocker classes")
if any(row["fixture_allowed"] != "0" for row in required_artifact_rows):
    raise SystemExit("PM blocker required artifacts should not allow fixture evidence")
if any(row["approval_required"] != "1" for row in required_artifact_rows):
    raise SystemExit("PM blocker required artifacts should require approval")
artifact_key = {(row["blocker_class"], row["artifact_id"]): row for row in required_artifact_rows}
for key in [
    ("v56-replay-artifact-missing", "v56b-scale-artifacts"),
    ("de-30b70b-baselines-missing", "d-model-identity"),
    ("de-30b70b-baselines-missing", "e-answer-citation-resource"),
    ("external-human-label-evidence-missing", "h10-label-evidence-csv"),
    ("v58c-intake-artifact-missing", "v58c-intake-summary"),
    ("v58c-intake-artifact-missing", "v58c-intake-artifacts"),
    ("v58c-intake-artifact-missing", "v58c-source-v58b-freeze"),
    ("v58-real-blind-eval-missing", "v58-blind-response-rows"),
    ("v58-real-blind-eval-missing", "v58d-review-return-intake"),
    ("v60-release-evidence-missing", "v59e-replay-preflight"),
    ("v60-release-evidence-missing", "v59e-local-abgh-row-contract-replay"),
    ("v60-release-evidence-missing", "v59-public-source-download-refresh"),
    ("v60-release-evidence-missing", "v60-human-release-review"),
]:
    if key not in artifact_key:
        raise SystemExit(f"missing required artifact row: {key}")
if "llm_rag_answer_rows.csv" not in artifact_key[("de-30b70b-baselines-missing", "d-answer-citation-resource")]["artifact_path_or_env"]:
    raise SystemExit("D evidence artifact row should name answer/citation/resource files")
if "H10_EVIDENCE_FIELDS" not in artifact_key[("external-human-label-evidence-missing", "h10-label-evidence-csv")]["required_shape"]:
    raise SystemExit("h10 label evidence row should name the required H10 field contract")
if "blind_response_rows.csv" not in artifact_key[("v58-real-blind-eval-missing", "v58-blind-response-rows")]["artifact_path_or_env"]:
    raise SystemExit("v58 response artifact row should name blind_response_rows.csv")
if "v58d_blind_review_return_intake" not in artifact_key[("v58-real-blind-eval-missing", "v58d-review-return-intake")]["artifact_path_or_env"]:
    raise SystemExit("v58d review return artifact row should name the v58d intake directory")
if "v58c_blind_response_evidence_intake_summary.csv" not in artifact_key[("v58c-intake-artifact-missing", "v58c-intake-summary")]["artifact_path_or_env"]:
    raise SystemExit("v58c intake summary row should name the v58c summary")
if "pm_foundation_replay_preflight_rows.csv" not in artifact_key[("v60-release-evidence-missing", "v59e-replay-preflight")]["artifact_path_or_env"]:
    raise SystemExit("v59e replay preflight artifact row should name the preflight rows")
if "local_abgh_row_contract_replay_rows.csv" not in artifact_key[("v60-release-evidence-missing", "v59e-local-abgh-row-contract-replay")]["artifact_path_or_env"]:
    raise SystemExit("v59e local A/B/G/H row-contract artifact row should name the row-contract replay rows")
if "local_abgh_row_contract_replay_ready=1" not in artifact_key[("v60-release-evidence-missing", "v59e-local-abgh-row-contract-replay")]["acceptance_signal"]:
    raise SystemExit("v59e local A/B/G/H row-contract artifact should close only when row-contract replay is ready")
if "public source download/refresh evidence bundle" not in artifact_key[("v60-release-evidence-missing", "v59-public-source-download-refresh")]["artifact_path_or_env"]:
    raise SystemExit("public-source download/refresh required artifact should be explicit")
if "full_public_source_download_ready=1" not in artifact_key[("v60-release-evidence-missing", "v59-public-source-download-refresh")]["acceptance_signal"]:
    raise SystemExit("public-source download/refresh artifact should close only full_public_source_download_ready")

execution_lock_rows = read_csv(run_dir / "pm_execution_lock_rows.csv")
if len(execution_lock_rows) != 10:
    raise SystemExit("PM execution lock should have ten rows")
expected_lock_ids = [
    "no-new-v62-v63-default",
    "v53-foundation-freeze-first",
    "abgh-internal-prebaseline-only",
    "de-baselines-real-evidence-only",
    "h10-real-label-only",
    "v54-grounded-generation-no-raw-context",
    "v56-replay-artifact-before-benchmark-claim",
    "v58-real-blind-eval-only",
    "v59-foundation-not-public-demo",
    "v60-release-gate-last",
]
if [row["lock_id"] for row in execution_lock_rows] != expected_lock_ids:
    raise SystemExit("PM execution lock order mismatch")
if any(row["status"] != "locked" for row in execution_lock_rows):
    raise SystemExit("every PM execution lock row should be locked")
lock_by_id = {row["lock_id"]: row for row in execution_lock_rows}
if "v62/v63" not in lock_by_id["no-new-v62-v63-default"]["forbidden_next_action"]:
    raise SystemExit("PM execution lock should forbid v62/v63 scope drift")
if "public comparison" not in lock_by_id["abgh-internal-prebaseline-only"]["forbidden_next_action"]:
    raise SystemExit("A/B/G/H execution lock should forbid public comparison")
if "external/human labels" not in lock_by_id["h10-real-label-only"]["required_focus"]:
    raise SystemExit("h10 execution lock should require external/human labels")
if "raw retrieved context prompt stuffing" not in lock_by_id["v54-grounded-generation-no-raw-context"]["forbidden_next_action"]:
    raise SystemExit("v54 execution lock should forbid raw prompt stuffing")
if "release" not in lock_by_id["v60-release-gate-last"]["scope"]:
    raise SystemExit("v60 execution lock should cover the release gate")

template_rows = read_csv(run_dir / "pm_external_return_template_rows.csv")
if len(template_rows) != 26:
    raise SystemExit("PM external return template ledger should have 26 rows")
if any(row["template_ready"] != "1" for row in template_rows):
    raise SystemExit("all PM external return templates should be ready")
if any(row["fixture_allowed"] != "0" for row in template_rows):
    raise SystemExit("PM external return templates should not allow fixture evidence")
if any(row["approval_required"] != "1" for row in template_rows):
    raise SystemExit("PM external return templates should require approval")
template_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in template_rows}
for key in artifact_key:
    if key not in template_by_key:
        raise SystemExit(f"missing return template for required artifact: {key}")
for row in template_rows:
    template_path = run_dir / row["template_path"]
    if not template_path.is_file() or template_path.stat().st_size == 0:
        raise SystemExit(f"missing PM external return template: {row['template_path']}")
    if row["template_sha256"] != sha256(template_path):
        raise SystemExit(f"PM external return template sha mismatch: {row['template_path']}")
d_model_template = (run_dir / template_by_key[("de-30b70b-baselines-missing", "d-model-identity")]["template_path"]).read_text(encoding="utf-8")
if '"system_id": "D"' not in d_model_template or '"external_api_used": 0' not in d_model_template:
    raise SystemExit("D model identity template should pin system_id D and external_api_used=0")
h10_template = (run_dir / template_by_key[("external-human-label-evidence-missing", "h10-label-evidence-csv")]["template_path"]).read_text(encoding="utf-8")
for header in ["human_reviewed", "external_source_verified", "non_fixture_declared", "acceptance_summary_sha256"]:
    if header not in h10_template:
        raise SystemExit(f"h10 label template missing header: {header}")
v58_template = (run_dir / template_by_key[("v58-real-blind-eval-missing", "v58-blind-response-rows")]["template_path"]).read_text(encoding="utf-8")
if "blind_response_id" not in v58_template or "identity_key_sha256" in v58_template:
    raise SystemExit("v58 blind response template should contain response fields without identity key")
v58c_template = (run_dir / template_by_key[("v58c-intake-artifact-missing", "v58c-intake-summary")]["template_path"]).read_text(encoding="utf-8")
if "v58c_blind_response_evidence_intake_ready" not in v58c_template or "human_blind_review_ready" not in v58c_template:
    raise SystemExit("v58c intake summary template should name readiness and review fields")
v58d_template = (run_dir / template_by_key[("v58-real-blind-eval-missing", "v58d-review-return-intake")]["template_path"]).read_text(encoding="utf-8")
for header in ["review_template_path", "adjudication_template_path", "failure_case_rows_path", "sha256_manifest_path"]:
    if header not in v58d_template:
        raise SystemExit(f"v58d review return intake template missing header: {header}")
v59e_preflight_template = (run_dir / template_by_key[("v60-release-evidence-missing", "v59e-replay-preflight")]["template_path"]).read_text(encoding="utf-8")
for header in ["one_command_replay_preflight_ready", "full_public_source_download_ready", "preflight_rows_sha256"]:
    if header not in v59e_preflight_template:
        raise SystemExit(f"v59e replay preflight template missing header: {header}")
v59e_abgh_template = (run_dir / template_by_key[("v60-release-evidence-missing", "v59e-local-abgh-row-contract-replay")]["template_path"]).read_text(encoding="utf-8")
for header in ["contract_id", "source_stage", "answer_rows", "evaluator_rows", "public_comparison_claim_ready"]:
    if header not in v59e_abgh_template:
        raise SystemExit(f"v59e local A/B/G/H row-contract template missing header: {header}")
public_source_refresh_template = (run_dir / template_by_key[("v60-release-evidence-missing", "v59-public-source-download-refresh")]["template_path"]).read_text(encoding="utf-8")
for header in ["repo_url", "pinned_commit_sha", "tree_sha256", "download_transcript_sha256", "network_download_approval_reference", "non_fixture_declared"]:
    if header not in public_source_refresh_template:
        raise SystemExit(f"public-source refresh template missing header: {header}")
v60_template = (run_dir / template_by_key[("v60-release-evidence-missing", "v60-human-release-review")]["template_path"]).read_text(encoding="utf-8")
if "release_review_id" not in v60_template or "accepted_for_public_v1" not in v60_template:
    raise SystemExit("v60 release review template should name release review acceptance fields")

required_files = [
    "pm_pr_slice_rows.csv",
    "pm_pr_merge_gate_rows.csv",
    "pm_roadmap_requirement_rows.csv",
    "pm_execution_lock_rows.csv",
    "pm_external_return_template_rows.csv",
    "pm_pr_slice_file_rows.csv",
    "pm_pr_slice_verification_rows.csv",
    "pm_pr_claim_boundary_rows.csv",
    "pm_pr_review_packet_rows.csv",
    "pm_pr_acceptance_evidence_rows.csv",
    "v56_replay_acceptance_evidence_rows.csv",
    "pm_blocker_closure_queue_rows.csv",
    "pm_blocker_closure_packet_rows.csv",
    "pm_blocker_required_artifact_rows.csv",
    "source_summary_rows.csv",
    "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_h10_pm/h10_real_label_evidence_template.csv",
    "source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_h10_pm/h10_real_label_return_contract_rows.csv",
    "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv",
    "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v59e/public_source_replay_policy_rows.csv",
    "source_v59e/local_abgh_row_contract_replay_rows.csv",
    "source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v53t/complete_source_pm_acceptance_evidence_rows.csv",
    "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v53t/complete_source_query_span_binding_audit_rows.csv",
    "source_v53t/source_v53i/complete_source_query_rows.csv",
    "source_v53t/source_v53i/complete_source_span_rows.csv",
    "source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv",
    "source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv",
    "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_v53t/source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_v53t/source_v53ap/abgh_answer_rows.csv",
    "source_v53t/source_v53ap/abgh_citation_rows.csv",
    "source_v53t/source_v53ap/abgh_evaluator_rows.csv",
    "source_v53t/source_v53ap/abgh_resource_rows.csv",
    "source_v53t/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v53t/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md",
    "v1_0_pm_pr_claim_slice_gate_manifest.json",
    "sha256_manifest.csv",
    "source_docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing PM PR slice gate artifact: {rel}")

repo_coverage_rows = read_csv(run_dir / "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv")
file_manifest_rows = read_csv(run_dir / "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv")
content_repo_rows = read_csv(run_dir / "source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv")
content_snapshot_rows = read_csv(run_dir / "source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")
binding_rows = read_csv(run_dir / "source_v53t/complete_source_query_span_binding_audit_rows.csv")
v53aq_prebaseline_rows = read_csv(run_dir / "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
local_abgh_contract_rows = {
    row["source_stage"]: row
    for row in read_csv(run_dir / "source_v59e/local_abgh_row_contract_replay_rows.csv")
}
if len(repo_coverage_rows) != 10 or len(content_repo_rows) != 10:
    raise SystemExit("PM PR sidecar should carry direct 10-repo manifest rows")
if len(file_manifest_rows) != 11266 or len(content_snapshot_rows) != 11266:
    raise SystemExit("PM PR sidecar should carry direct file/content manifest rows")
if len(binding_rows) != 1000 or any(row["binding_status"] != "pass" for row in binding_rows):
    raise SystemExit("PM PR sidecar should carry 1000 passing query-span binding audit rows")
if len(v53aq_prebaseline_rows) != 1000 or any(row["same_evaluator_contract"] != "1" or row["same_resource_bound"] != "1" for row in v53aq_prebaseline_rows):
    raise SystemExit("PM PR sidecar should carry 1000 v53aq same-query evaluator/resource ledger rows")
if set(local_abgh_contract_rows) != {"v53ap", "v53aq"}:
    raise SystemExit("PM PR sidecar should carry v59e local A/B/G/H row-contract rows for v53ap and v53aq")
if any(
    row["status"] != "pass"
    or row["systems"] != "A/B/G/H"
    or row["answer_rows"] != "4000"
    or row["citation_rows"] != "4000"
    or row["evaluator_rows"] != "4000"
    or row["resource_rows"] != "4000"
    or row["same_query_row_contract"] != "1"
    or row["same_evaluator_contract_all_local_systems"] != "1"
    or row["same_resource_contract_all_local_systems"] != "1"
    or row["expected_answer_oracle_replay_any"] != "0"
    or row["public_comparison_claim_ready"] != "0"
    for row in local_abgh_contract_rows.values()
):
    raise SystemExit("PM PR sidecar should preserve passing local A/B/G/H row-contract replay boundaries")
if any(row["complete_source_tree_manifest_ready"] != "1" for row in repo_coverage_rows):
    raise SystemExit("PM PR sidecar repo coverage rows should preserve ready tree manifests")
if any(row["content_snapshot_ready"] != "1" for row in content_repo_rows):
    raise SystemExit("PM PR sidecar content repo rows should preserve ready content snapshots")

v53_pm_acceptance_rows = {row["requirement_id"]: row for row in read_csv(run_dir / "source_v53t/complete_source_pm_acceptance_evidence_rows.csv")}
expected_v53_pm_acceptance_ids = {
    "pinned-public-repo-manifest",
    "source-span-query-freeze",
    "negative-abstain-control-share",
    "unsupported-claim-control",
    "missing-specific-abstain-control",
    "doc-code-conflict-control",
    "answer-citation-separated-evaluator",
    "abgh-same-query-deterministic-prebaseline",
    "abgh-real-adapter-same-query-internal",
    "public-comparison-boundary-closed",
}
if set(v53_pm_acceptance_rows) != expected_v53_pm_acceptance_ids:
    raise SystemExit("PM PR sidecar should carry the full v53 PM acceptance evidence ledger")
if any(row["acceptance_ready"] != "1" for row in v53_pm_acceptance_rows.values()):
    raise SystemExit("PM PR sidecar v53 PM acceptance evidence rows should all be ready")
if any(row["tests_only_merge_condition"] != "0" for row in v53_pm_acceptance_rows.values()):
    raise SystemExit("PM PR sidecar v53 PM acceptance evidence should not use tests-only merge conditions")
if any(
    row["claim_boundary_status"] != "pass"
    or row["replay_artifact_status"] != "pass"
    or row["blocker_false_positive_status"] != "pass"
    for row in v53_pm_acceptance_rows.values()
):
    raise SystemExit("PM PR sidecar v53 PM acceptance evidence should pass claim/replay/blocker gates")
for requirement_id, snippet in {
    "source-span-query-freeze": "binding_audit_pass_rows=1000",
    "answer-citation-separated-evaluator": "separate_evaluator_rows=4000",
    "abgh-same-query-deterministic-prebaseline": "real_system_performance_claim_ready=0",
    "abgh-real-adapter-same-query-internal": "public_comparison_claim_ready=0",
    "public-comparison-boundary-closed": "required_30b_baseline_ready=0",
}.items():
    if snippet not in v53_pm_acceptance_rows[requirement_id]["actual_value"]:
        raise SystemExit(f"PM PR sidecar v53 PM acceptance row should expose {snippet}: {requirement_id}")

real_adapter_freeze_rows = {row["criterion_id"]: row for row in read_csv(run_dir / "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv")}
if len(real_adapter_freeze_rows) != 4:
    raise SystemExit("PM PR sidecar should copy four v53t real-adapter freeze rows")
for criterion_id in [
    "v53aq-same-query-surface",
    "question-only-selection-contract",
    "real-adapter-execution-rows",
    "public-comparison-boundary-closed",
]:
    if real_adapter_freeze_rows.get(criterion_id, {}).get("status") != "pass":
        raise SystemExit(f"PM PR sidecar v53t real-adapter freeze row should pass: {criterion_id}")
if "selection_question_text_only=1" not in real_adapter_freeze_rows["question-only-selection-contract"]["actual_value"]:
    raise SystemExit("PM PR sidecar should expose v53aq question-only selection in v53t freeze evidence")
if "same_query_ledger_ready=1" not in real_adapter_freeze_rows["v53aq-same-query-surface"]["actual_value"]:
    raise SystemExit("PM PR sidecar should expose v53aq same-query ledger readiness in v53t freeze evidence")
if real_adapter_freeze_rows["v53aq-same-query-surface"]["evidence_path"] != "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv":
    raise SystemExit("PM PR sidecar v53t real-adapter freeze should point at the same-query ledger")
if "coherent_wrong_key_rows=287" not in real_adapter_freeze_rows["real-adapter-execution-rows"]["actual_value"]:
    raise SystemExit("PM PR sidecar should expose v53aq coherent wrong-key evidence in v53t freeze evidence")
if "public_comparison_claim_ready=0" not in real_adapter_freeze_rows["public-comparison-boundary-closed"]["actual_value"]:
    raise SystemExit("PM PR sidecar should keep v53aq public comparison blocked in v53t freeze evidence")

manifest = json.loads((run_dir / "v1_0_pm_pr_claim_slice_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("recommended_pr_slice_rows") != 10 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("PM PR manifest readiness mismatch")
if manifest.get("slice_ids") != expected_order:
    raise SystemExit("PM PR manifest slice order mismatch")
if manifest.get("pm_roadmap_requirement_rows") != 20 or manifest.get("pm_foundation_ready") != 1:
    raise SystemExit("PM PR manifest roadmap audit mismatch")
if manifest.get("v53_foundation_freeze_certificate_rows") != 10 or manifest.get("v53_foundation_machine_freeze_ready") != 1:
    raise SystemExit("PM PR manifest v53 foundation freeze mismatch")
if (
    manifest.get("v53_foundation_query_span_binding_audit_ready") != 1
    or manifest.get("v53_foundation_query_span_binding_audit_rows") != 1000
    or manifest.get("v53_foundation_query_span_binding_pass_rows") != 1000
):
    raise SystemExit("PM PR manifest query-span binding audit mismatch")
if (
    manifest.get("v53_foundation_direct_pinned_manifest_ready") != 1
    or manifest.get("v53_foundation_direct_repo_manifest_rows") != 10
    or manifest.get("v53_foundation_direct_file_manifest_rows") != 11266
    or manifest.get("v53_foundation_direct_content_snapshot_rows") != 11266
):
    raise SystemExit("PM PR manifest direct pinned manifest evidence mismatch")
if (
    manifest.get("v53_pm_acceptance_evidence_rows") != 10
    or manifest.get("v53_pm_acceptance_evidence_ready_rows") != 10
    or manifest.get("v53_pm_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("PM PR manifest should record v53 PM acceptance evidence")
if (
    manifest.get("h10_real_label_acceptance_evidence_rows") != 6
    or manifest.get("h10_real_label_acceptance_evidence_ready_rows") != 6
    or manifest.get("h10_real_label_acceptance_evidence_promotion_ready_rows") != 0
    or manifest.get("h10_real_label_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("PM PR manifest should record h10 PM acceptance evidence")
if "h10_real_label_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("PM PR manifest should hash-bind h10 acceptance evidence rows")
if manifest.get("pm_pr_slice_file_rows") != 41 or manifest.get("pm_pr_slice_verification_rows") != 17:
    raise SystemExit("PM PR manifest file/verification ledger mismatch")
if manifest.get("pm_pr_claim_boundary_rows") != 10 or manifest.get("pm_pr_claim_boundary_pass_rows") != 10:
    raise SystemExit("PM PR manifest claim boundary ledger mismatch")
if manifest.get("pm_pr_review_packet_rows") != 10 or manifest.get("pm_pr_review_packet_files") != 10:
    raise SystemExit("PM PR manifest review packet ledger mismatch")
if manifest.get("pm_pr_review_packet_ready_rows") != 10 or manifest.get("pm_pr_review_packet_blocked_slice_rows") != 1:
    raise SystemExit("PM PR manifest review packet readiness mismatch")
if (
    manifest.get("pm_pr_acceptance_evidence_rows") != 10
    or manifest.get("pm_pr_acceptance_evidence_ready_rows") != 9
    or manifest.get("pm_pr_acceptance_evidence_blocked_rows") != 1
    or manifest.get("pm_pr_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("PM PR manifest acceptance evidence ledger mismatch")
if "pm_pr_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("PM PR manifest should hash-bind acceptance evidence rows")
if (
    manifest.get("v56_replay_acceptance_evidence_rows") != 4
    or manifest.get("v56_replay_acceptance_evidence_ready_rows") != 0
    or manifest.get("v56_replay_acceptance_evidence_blocked_rows") != 4
    or manifest.get("v56_replay_acceptance_evidence_tests_only_rows") != 0
    or manifest.get("v56_replay_acceptance_evidence_fixture_allowed_rows") != 0
    or manifest.get("v56_replay_acceptance_evidence_approval_rows") != 4
):
    raise SystemExit("PM PR manifest should record v56 replay acceptance evidence")
if "v56_replay_acceptance_evidence_rows_sha256" not in manifest:
    raise SystemExit("PM PR manifest should hash-bind v56 replay acceptance evidence")
if manifest.get("pm_blocker_closure_queue_rows") != 6:
    raise SystemExit("PM PR manifest blocker closure queue mismatch")
if manifest.get("pm_blocker_closure_packet_rows") != 6 or manifest.get("pm_blocker_closure_packet_files") != 6:
    raise SystemExit("PM PR manifest blocker closure packet mismatch")
if manifest.get("pm_blocker_closure_packet_ready_rows") != 6 or manifest.get("pm_blocker_closure_packet_approval_rows") != 6:
    raise SystemExit("PM PR manifest blocker closure packet readiness mismatch")
if manifest.get("pm_blocker_required_artifact_rows") != 26 or manifest.get("pm_blocker_required_artifact_fixture_allowed_rows") != 0:
    raise SystemExit("PM PR manifest blocker required artifact mismatch")
if manifest.get("pm_execution_lock_rows") != 10 or manifest.get("pm_execution_lock_active_rows") != 10:
    raise SystemExit("PM PR manifest execution lock row mismatch")
if manifest.get("pm_scope_drift_allowed") != 0 or manifest.get("pm_new_scaffold_default_allowed") != 0:
    raise SystemExit("PM PR manifest should disallow scope drift and default new scaffolds")
if manifest.get("pm_external_return_template_rows") != 26 or manifest.get("pm_external_return_template_files") != 26:
    raise SystemExit("PM PR manifest external return template count mismatch")
if manifest.get("pm_external_return_template_ready_rows") != 26 or manifest.get("pm_external_return_template_fixture_allowed_rows") != 0:
    raise SystemExit("PM PR manifest external return template readiness mismatch")
if manifest.get("pm_external_return_template_approval_rows") != 26:
    raise SystemExit("PM PR manifest external return templates should require approval")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"PM PR slice gate sha mismatch: {rel}")

boundary = (run_dir / "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "recommended_pr_slice_rows=10",
    "merge_condition_defined_rows=10",
    "pm_roadmap_requirement_rows=20",
    "pm_foundation_ready=1",
    "v53_foundation_freeze_certificate_rows=10",
    "v53_foundation_machine_freeze_ready=1",
    "v53_foundation_query_span_binding_audit_ready=1",
    "v53_foundation_query_span_binding_audit_rows=1000",
    "v53_foundation_query_span_binding_pass_rows=1000",
    "v53_foundation_direct_pinned_manifest_ready=1",
    "v53_foundation_direct_repo_manifest_rows=10",
    "v53_foundation_direct_file_manifest_rows=11266",
    "v53_foundation_direct_content_snapshot_rows=11266",
    "v53_pm_acceptance_evidence_rows=10",
    "v53_pm_acceptance_evidence_ready_rows=10",
    "v53_pm_acceptance_evidence_tests_only_rows=0",
    "h10_real_label_acceptance_evidence_rows=6",
    "h10_real_label_acceptance_evidence_ready_rows=6",
    "h10_real_label_acceptance_evidence_promotion_ready_rows=0",
    "h10_real_label_acceptance_evidence_tests_only_rows=0",
    "pm_pr_slice_file_rows=41",
    "pm_pr_slice_verification_rows=17",
    "pm_pr_claim_boundary_rows=10",
    "pm_pr_review_packet_rows=10",
    "pm_pr_review_packet_files=10",
    "pm_pr_acceptance_evidence_rows=10",
    "pm_pr_acceptance_evidence_ready_rows=9",
    "pm_pr_acceptance_evidence_tests_only_rows=0",
    "v56_replay_acceptance_evidence_rows=4",
    "v56_replay_acceptance_evidence_ready_rows=0",
    "v56_replay_acceptance_evidence_blocked_rows=4",
    "v56_replay_acceptance_evidence_tests_only_rows=0",
    "pm_blocker_closure_queue_rows=6",
    "pm_blocker_closure_packet_rows=6",
    "pm_blocker_closure_packet_files=6",
    "pm_blocker_required_artifact_rows=26",
    "pm_execution_lock_rows=10",
    "pm_scope_drift_allowed=0",
    "pm_new_scaffold_default_allowed=0",
    "pm_external_return_template_rows=26",
    "pm_external_return_template_files=26",
    "tests_only_merge_condition_rows=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"PM PR slice gate boundary missing: {snippet}")
PY

echo "v1.0 PM PR claim slice gate smoke passed"
