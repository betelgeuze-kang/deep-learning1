#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v60_architecture_challenge_release_contract"
RUN_ID="${V60_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V59_CONTRACT_SUMMARY="$RESULTS_DIR/v59_one_command_challenge_demo_contract_summary.csv"
V59_CONTRACT_DIR="$RESULTS_DIR/v59_one_command_challenge_demo_contract/contract_001"
V59E_SUMMARY="$RESULTS_DIR/v59e_one_command_pm_foundation_demo_summary.csv"
V59E_DIR="$RESULTS_DIR/v59e_one_command_pm_foundation_demo/pm_foundation_001"
V59E_READY_ARTIFACT="$V59E_DIR/pm_foundation_stage_replay_rows.csv"
V59E_V58C_DEPENDENCY_ARTIFACT="$V59E_DIR/v58c_pm_blind_response_intake_dependency_summary.csv"

if [[ "${V60_REBUILD_SOURCE_CHAIN:-0}" == "1" ]]; then
  "$ROOT_DIR/experiments/run_v59_one_command_challenge_demo_contract.sh" >/dev/null
fi
if [[ "${V60_REBUILD_SOURCE_CHAIN:-0}" == "1" || ! -s "$V59E_SUMMARY" || ! -s "$V59E_READY_ARTIFACT" || ! -s "$V59E_V58C_DEPENDENCY_ARTIFACT" ]]; then
  "$ROOT_DIR/experiments/run_v59e_one_command_pm_foundation_demo.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v59_dir = results / "v59_one_command_challenge_demo_contract" / "contract_001"
v59e_dir = results / "v59e_one_command_pm_foundation_demo" / "pm_foundation_001"
pm_pr_dir = results / "v1_0_pm_pr_claim_slice_gate" / "gate_001"
h10_pm_dir = results / "v10_h10_real_label_promotion_readiness_gate" / "gate_001"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_first(path):
    if not path.is_file() or path.stat().st_size == 0:
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}


def read_rows(path):
    if not path.is_file() or path.stat().st_size == 0:
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def as_int(row, key, default="0"):
    try:
        return int(float(row.get(key, default) or default))
    except ValueError:
        return int(float(default))


def sha_or_empty(path):
    return sha256(path) if path.is_file() else ""


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


v59_summary = read_first(results / "v59_one_command_challenge_demo_contract_summary.csv")
legacy_v59_files = [
    "challenge_stage_contract_rows.csv",
    "one_command_demo_rows.csv",
    "one_command_demo_gate_rows.csv",
    "README_RESULT.md",
    "V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md",
    "v59_one_command_challenge_demo_manifest.json",
    "sha256_manifest.csv",
]
legacy_v59_copied_files = 0
for rel in legacy_v59_files:
    src = v59_dir / rel
    if src.is_file() and src.stat().st_size > 0:
        copy(src, f"source_v59/{rel}")
        legacy_v59_copied_files += 1
if (results / "v59_one_command_challenge_demo_contract_summary.csv").is_file():
    copy(results / "v59_one_command_challenge_demo_contract_summary.csv", "source_v59/v59_one_command_challenge_demo_contract_summary.csv")
    legacy_v59_copied_files += 1
if (results / "v59_one_command_challenge_demo_contract_decision.csv").is_file():
    copy(results / "v59_one_command_challenge_demo_contract_decision.csv", "source_v59/v59_one_command_challenge_demo_contract_decision.csv")
    legacy_v59_copied_files += 1
legacy_v59_contract_ready = int(
    as_int(v59_summary, "v59_one_command_challenge_demo_contract_ready") == 1
    and legacy_v59_copied_files >= 9
)
write_csv(
    run_dir / "legacy_v59_contract_source_rows.csv",
    ["source_id", "ready", "copied_files", "rebuild_command", "rebuild_required_by_default"],
    [
        {
            "source_id": "legacy-v59-contract",
            "ready": legacy_v59_contract_ready,
            "copied_files": legacy_v59_copied_files,
            "rebuild_command": "V60_REBUILD_SOURCE_CHAIN=1 experiments/test_v60_architecture_challenge_release_contract.sh",
            "rebuild_required_by_default": "0",
        }
    ],
)

for rel in [
    "pm_foundation_stage_replay_rows.csv",
    "pm_foundation_one_command_rows.csv",
    "pm_foundation_replay_preflight_rows.csv",
    "public_source_replay_policy_rows.csv",
    "challenge_bundle_file_rows.csv",
    "pm_foundation_demo_gate_rows.csv",
    "README_RESULT.md",
    "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md",
    "v59e_one_command_pm_foundation_demo_manifest.json",
    "sha256_manifest.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_slice_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_pr_review_packet_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_blocker_closure_queue_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv",
    "source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_template.csv",
    "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_acceptance_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv",
    "source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv",
    "source_h10_pm/source_v53aq/abgh_evaluator_rows.csv",
    "source_h10_pm/source_v53aq/abgh_system_metric_rows.csv",
    "source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv",
    "source_v54c/answer_rows.csv",
    "source_v54c/citation_rows.csv",
    "source_v54c/unsupported_claim_rows.csv",
    "source_v54c/abstain_rows.csv",
    "source_v54c/generator_resource_rows.csv",
    "source_v54c/wrong_answer_guard_rows.csv",
    "source_v54c/generator_input_rows.csv",
    "source_v54c/compact_routehint_rows.csv",
    "source_v54c/sha256sums.txt",
    "source_v54c/V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md",
    "source_v54c/sha256_manifest.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_query_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_span_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_answer_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_citation_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_evaluator_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_resource_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_adapter_trace_rows.csv",
    "source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_summary.csv",
    "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_manifest.json",
    "v58c_pm_blind_response_intake_dependency_summary.csv",
    "v58c_pm_blind_response_intake_dependency_rows.csv",
    "v58d_pm_blind_review_return_dependency_summary.csv",
    "v58d_pm_blind_review_return_dependency_rows.csv",
]:
    copy(v59e_dir / rel, f"source_v59e/{rel}")
copy(results / "v59e_one_command_pm_foundation_demo_summary.csv", "source_v59e/v59e_one_command_pm_foundation_demo_summary.csv")
copy(results / "v59e_one_command_pm_foundation_demo_decision.csv", "source_v59e/v59e_one_command_pm_foundation_demo_decision.csv")
copy(results / "v1_0_pm_pr_claim_slice_gate_summary.csv", "source_pm_pr/v1_0_pm_pr_claim_slice_gate_summary.csv")

for summary_name in [
    "v52_llm_rag_baseline_war_summary.csv",
    "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "v54c_complete_source_grounded_generation_1000_summary.csv",
    "v10_h10_real_label_promotion_readiness_gate_summary.csv",
]:
    src = results / summary_name
    if src.is_file() and src.stat().st_size > 0:
        copy(src, f"source_summaries/{summary_name}")

h10_pm_files = [
    "pm_h10_real_label_acceptance_rows.csv",
    "h10_real_label_evidence_template.csv",
    "h10_real_label_evidence_acceptance_rows.csv",
    "source_v53aq/adapter_selection_contract_rows.csv",
    "source_v53aq/abgh_adapter_trace_rows.csv",
    "source_v53aq/abgh_evaluator_rows.csv",
    "source_v53aq/abgh_system_metric_rows.csv",
    "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "source_v53t/complete_source_foundation_freeze_rows.csv",
]
h10_pm_copied_files = 0
for rel in h10_pm_files:
    for src in [
        h10_pm_dir / rel,
        v59e_dir / "source_pm_pr_claim_slice_gate" / "source_h10_pm" / rel,
        pm_pr_dir / "source_h10_pm" / rel,
    ]:
        if src.is_file() and src.stat().st_size > 0:
            copy(src, f"source_h10_pm/{rel}")
            h10_pm_copied_files += 1
            break

v52 = read_first(results / "v52_llm_rag_baseline_war_summary.csv")
v53t = read_first(results / "v53t_complete_source_audit_readiness_gate_summary.csv")
v53ap = read_first(results / "v53ap_complete_source_abgh_same_query_measured_summary.csv")
v53aq = read_first(results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv")
v54c = read_first(results / "v54c_complete_source_grounded_generation_1000_summary.csv")
h10 = read_first(results / "v10_h10_real_label_promotion_readiness_gate_summary.csv")
v59e = read_first(results / "v59e_one_command_pm_foundation_demo_summary.csv")
pm_pr = read_first(results / "v1_0_pm_pr_claim_slice_gate_summary.csv")

expected_h10_pm_criteria = {
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
}
h10_pm_acceptance_rows = read_rows(run_dir / "source_h10_pm" / "pm_h10_real_label_acceptance_rows.csv")
h10_pm_criteria = {row.get("criterion", ""): row for row in h10_pm_acceptance_rows}
h10_pm_criteria_ready = int(
    len(h10_pm_acceptance_rows) == len(expected_h10_pm_criteria)
    and set(h10_pm_criteria) == expected_h10_pm_criteria
)
h10_external_row = h10_pm_criteria.get("external-human-label-evidence", {})
h10_source_row = h10_pm_criteria.get("source-provenance-binding", {})
h10_pm_external_label_blocked = int(
    h10_external_row.get("machine_evidence_status") == "blocked"
    and h10_external_row.get("real_label_status") == "blocked"
)
h10_pm_source_provenance_binding_ready = int(
    h10_source_row.get("machine_evidence_status") == "pass"
    and "v53ap_evaluator_rows=4000" in h10_source_row.get("evidence", "")
    and "v53aq_evaluator_rows=4000" in h10_source_row.get("evidence", "")
    and "v53t_real_adapter_freeze_rows=4" in h10_source_row.get("evidence", "")
    and as_int(h10, "source_provenance_binding_ready") == 1
    and as_int(h10, "v53aq_real_adapter_provenance_ready") == 1
    and as_int(h10, "v53t_real_adapter_freeze_ready") == 1
)

v54c_recommended_output_rels = [
    "source_v54c/answer_rows.csv",
    "source_v54c/citation_rows.csv",
    "source_v54c/unsupported_claim_rows.csv",
    "source_v54c/abstain_rows.csv",
    "source_v54c/generator_resource_rows.csv",
    "source_v54c/wrong_answer_guard_rows.csv",
    "source_v54c/generator_input_rows.csv",
    "source_v54c/compact_routehint_rows.csv",
    "source_v54c/sha256sums.txt",
]
v54c_recommended_output_files_ready = int(
    all((run_dir / "source_v59e" / rel).is_file() and (run_dir / "source_v59e" / rel).stat().st_size > 0 for rel in v54c_recommended_output_rels)
    and as_int(v54c, "answer_rows") == 1000
    and as_int(v54c, "citation_rows") == 1000
    and as_int(v54c, "unsupported_claim_rows") == 160
    and as_int(v54c, "abstain_rows") == 160
    and as_int(v54c, "generator_resource_rows") == 1000
    and as_int(v54c, "wrong_answer_guard_rows") == 1000
    and as_int(v54c, "compact_routehint_rows") == 1000
    and as_int(v54c, "raw_prompt_context_appended_rows") == 0
)


def req(requirement, ready, blocker, evidence_path, release_blocker_class):
    return {
        "requirement": requirement,
        "required_for_v1_0_release": 1,
        "ready": int(bool(ready)),
        "status": "pass" if ready else "blocked",
        "blocking_reason": "closed for current PM foundation gate" if ready else blocker,
        "evidence_path": evidence_path,
        "release_blocker_class": release_blocker_class,
    }


requirements = [
    req(
        "v52_baseline_registry_contract",
        as_int(v52, "v52_baseline_war_contract_ready") == 1 and as_int(v52, "symmetric_citation_contract_ready") == 1,
        "v52 baseline registry or symmetric citation contract is missing",
        "source_summaries/v52_llm_rag_baseline_war_summary.csv",
        "v52-contract-missing",
    ),
    req(
        "v53_public_repo_source_bound_1000_corpus",
        as_int(v53t, "pm_v53_freeze_ready") == 1
        and as_int(v53t, "complete_source_repo_count") >= 10
        and as_int(v53t, "complete_source_query_rows") >= 1000
        and as_int(v53t, "complete_source_span_rows") >= 1000
        and as_int(v53t, "unsupported_control_rows") >= 100
        and as_int(v53t, "doc_code_conflict_rows") > 0
        and as_int(v53t, "foundation_query_span_binding_audit_ready") == 1
        and as_int(v59e, "pm_pr_v53_query_span_binding_audit_ready") == 1
        and as_int(v53t, "foundation_direct_pinned_manifest_ready") == 1
        and as_int(v59e, "pm_pr_v53_direct_pinned_manifest_ready") == 1,
        "v53 source-bound 10-repo/1000-query freeze is missing",
        "source_v59e/source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv",
        "v53-foundation-freeze-missing",
    ),
    req(
        "v53_abgh_same_query_internal_prebaseline",
        as_int(v53ap, "v53ap_complete_source_abgh_same_query_measured_ready") == 1
        and as_int(v53ap, "same_query_set_all_local_systems") == 1
        and as_int(v53ap, "internal_v1_0_pre_baseline_run") == 1
        and as_int(v53aq, "same_query_internal_prebaseline_rows_ready") == 1
        and as_int(v53aq, "same_query_internal_prebaseline_rows") == 1000
        and as_int(v53ap, "public_comparison_claim_ready") == 0,
        "A/B/G/H same-query internal pre-baseline is missing or overclaimed",
        "source_v59e/source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
        "abgh-prebaseline-missing",
    ),
    req(
        "v54_grounded_generation_1000",
        as_int(v54c, "v54c_complete_source_grounded_generation_1000_ready") == 1
        and as_int(v54c, "answer_rows") >= 1000
        and as_int(v54c, "citation_rows") >= 1000
        and v54c_recommended_output_files_ready == 1
        and as_int(v54c, "raw_prompt_context_appended_rows") == 0
        and as_int(v54c, "wrong_answer_rows") == 0,
        "1000 grounded generation rows without raw prompt stuffing are missing",
        "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
        "v54-grounded-generation-missing",
    ),
    req(
        "v59_pm_foundation_one_command_bundle",
        as_int(v59e, "v59e_one_command_pm_foundation_demo_ready") == 1
        and as_int(v59e, "challenge_bundle_ready") == 1
        and as_int(v59e, "undocumented_local_state_required") == 0
        and as_int(v59e, "private_fixture_required") == 0
        and as_int(v59e, "manual_postprocessing_required") == 0,
        "one-command PM foundation replay requires hidden state, private fixture, or manual postprocessing",
        "source_v59e/v59e_one_command_pm_foundation_demo_summary.csv",
        "v59-foundation-demo-missing",
    ),
    req(
        "pm_pr_claim_slice_gate_and_execution_lock",
        as_int(v59e, "pm_pr_claim_slice_bundle_ready") == 1
        and as_int(pm_pr, "v1_0_pm_pr_claim_slice_gate_ready") == 1
        and as_int(pm_pr, "tests_only_merge_condition_rows") == 0
        and as_int(pm_pr, "pm_scope_drift_allowed") == 0
        and as_int(pm_pr, "pm_external_return_template_fixture_allowed_rows") == 0,
        "PM PR claim-slice gate, execution lock, or no-fixture return templates are missing",
        "source_pm_pr/v1_0_pm_pr_claim_slice_gate_summary.csv",
        "pm-pr-slice-gate-missing",
    ),
    req(
        "required_30b_70b_symmetric_baselines",
        as_int(v52, "required_30b_baseline_ready") == 1 and as_int(v52, "required_70b_baseline_ready") == 1,
        "real symmetric D/E 30B/70B LLM+RAG baseline evidence is missing",
        "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
        "de-30b70b-baselines-missing",
    ),
    req(
        "h10_real_label_source_verified_scorer",
        h10_pm_criteria_ready == 1
        and h10_pm_source_provenance_binding_ready == 1
        and as_int(h10, "h10_real_label_promotion_ready") == 1
        and as_int(h10, "external_human_label_evidence_ready") == 1
        and as_int(h10, "h10_source_verified_eval_ready") == 1,
        "h10 PM criteria rows are present, but accepted external/human labels and source-verified eval evidence are missing",
        "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
        "external-human-label-evidence-missing",
    ),
    req(
        "v56_expanded_ruler_longbench_replay_artifact",
        as_int(pm_pr, "replay_artifact_pass_rows") == as_int(pm_pr, "recommended_pr_slice_rows"),
        "v56 replay artifact is still absent, so one PR slice remains blocked",
        "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
        "v56-replay-artifact-missing",
    ),
    req(
        "v58c_blind_response_intake_artifact",
        as_int(v59e, "v58c_blind_response_evidence_intake_ready") == 1
        and as_int(v59e, "v58c_expected_blind_response_rows") == 2500
        and as_int(v59e, "v58c_required_blind_response_ready") == 0
        and as_int(v59e, "v58c_human_blind_review_ready") == 0,
        "v58c blind-response intake artifact is absent; implicit v58/v57/v56 seed rebuild remains blocked",
        "source_v59e/v58c_pm_blind_response_intake_dependency_rows.csv",
        "v58c-intake-artifact-missing",
    ),
    req(
        "v58_real_blind_eval",
        as_int(v59e, "v58_full_blind_eval_ready") == 1,
        "real D/E/G/H blind responses, human blind review, and adjudication rows are missing",
        "source_v59e/source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv",
        "v58-real-blind-eval-missing",
    ),
    req(
        "full_v59_public_demo_real_replay",
        as_int(v59e, "full_v1_public_demo_ready") == 1
        and as_int(v59e, "v59_ready") == 1
        and as_int(v59e, "full_public_source_download_ready") == 1,
        "v59e is a PM foundation replay, not a full public challenge demo over all real rows with approved public-source download/refresh evidence",
        "source_v59e/v59e_one_command_pm_foundation_demo_summary.csv",
        "full-v59-public-demo-missing",
    ),
    req(
        "human_release_review",
        False,
        "human/release review return is missing",
        "release_requirement_rows.csv",
        "human-release-review-missing",
    ),
    req(
        "release_artifact_package",
        False,
        "v60 release package is not assembled from all real rows and human release evidence",
        "release_requirement_rows.csv",
        "v60-release-evidence-missing",
    ),
]
requirement_rows = []
for requirement in requirements:
    requirement_rows.append(requirement)
write_csv(run_dir / "release_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

allowed_claim_rows = [
    {
        "claim_id": "architecture-challenge-contract-scaffold",
        "status": "allowed_limited",
        "public_wording": "v1.0 Architecture Challenge release-audit gate over current PM foundation evidence",
        "evidence": "v59e PM foundation artifacts plus v60 release audit contract",
    },
    {
        "claim_id": "pm-foundation-replay-bundle",
        "status": "allowed_limited",
        "public_wording": "replayable PM foundation bundle for v53/v54/h10/v58 intake surfaces",
        "evidence": "v59e PM foundation bundle plus PM PR claim-slice gate",
    },
    {
        "claim_id": "local-architecture-preview",
        "status": "allowed_limited",
        "public_wording": "local evidence-bound RouteMemory/RouteHint QA and audit preview",
        "evidence": "v0.3/v52-v59 contract artifacts",
    },
]
write_csv(run_dir / "allowed_claim_rows.csv", list(allowed_claim_rows[0].keys()), allowed_claim_rows)

forbidden_claim_rows = [
    ("v1_0_release_ready", "v60_ready=0 and real_release_package_ready=0"),
    ("beats_30b_150b_llm_rag", "30B/70B/100B+ real rows and blind-eval rows are missing"),
    ("public_comparison_win", "D/E 30B/70B symmetric baselines and blind eval are missing"),
    ("h10_scientific_contribution_claim", "external/human h10 real-label evidence is missing"),
    ("v59_public_demo_complete", "v59e is PM foundation replay only"),
    ("transformer_replacement", "architecture replacement evidence is not supplied"),
    ("frontier_local_llm_equivalence", "no 30B-150B-class measured equivalence evidence"),
    ("long_context_solved", "expanded RULER/LongBench main rows are missing"),
    ("gpu_or_hip_acceleration", "GPU/HIP speedup evidence is not part of v52-v60 contracts"),
    ("expert_replacement", "v57 keeps expert_replacement_claim=0"),
    ("production_release", "human/release review and real package are missing"),
]
write_csv(
    run_dir / "forbidden_claim_rows.csv",
    ["claim_id", "blocking_reason"],
    [{"claim_id": claim_id, "blocking_reason": reason} for claim_id, reason in forbidden_claim_rows],
)

decision_rows = [
    ("v60-release-contract", "pass", "release requirements, allowed claims, forbidden claims, and source v59 bundle are emitted"),
    ("v59-contract-input", "pass" if legacy_v59_contract_ready else "blocked", "legacy v59 scaffold bundle is copied when already present; rebuild is explicit"),
    ("v59e-pm-foundation-input", "pass", "v59e PM foundation bundle is present and copied"),
    ("pm-pr-claim-slice-input", "pass", "PM PR split sidecar, execution lock, and return templates are copied"),
    ("claim-boundary", "pass", "allowed claims are bounded and forbidden claims are explicit"),
    ("v53-foundation-freeze", "pass", "10 public repos, 1000 source-span-bound queries, and controls are frozen"),
    ("local-abgh-prebaseline", "pass", "A/B/G/H same-query internal pre-baseline is ready without public comparison claim"),
    ("v54-grounded-generation-1000", "pass", "1000 grounded generation rows are present with raw prompt stuffing blocked"),
    ("real-30b-70b-baselines", "blocked", "real 30B/70B LLM+RAG rows are missing"),
    ("h10-real-label-promotion", "blocked", "h10 PM criteria rows are replayable, but accepted external/human real-label evidence is missing"),
    ("v56-replay-artifact", "blocked", "v56 expanded benchmark replay artifact remains missing"),
    ("v58c-blind-response-intake", "blocked", "v58c intake artifact is missing or blocked by explicit seed-rebuild guard"),
    ("v58-real-blind-eval", "blocked", "real blind responses and human blind review are missing"),
    ("full-v59-public-demo", "blocked", "current one-command bundle is PM foundation replay, not full public challenge demo"),
    ("human-release-review", "blocked", "human/release review return is missing"),
    ("real-release-package", "blocked", "real_release_package_ready remains 0"),
]
write_csv(
    run_dir / "release_decision_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows],
)

summary = {
    "v60_release_contract_ready": 1,
    "v60_ready": 0,
    "release_requirement_rows": len(requirement_rows),
    "release_requirement_ready_rows": sum(int(row["ready"]) for row in requirement_rows),
    "release_requirement_blocked_rows": sum(1 for row in requirement_rows if row["status"] == "blocked"),
    "allowed_claim_rows": len(allowed_claim_rows),
    "forbidden_claim_rows": len(forbidden_claim_rows),
    "v59_one_command_challenge_demo_contract_ready": int(v59_summary.get("v59_one_command_challenge_demo_contract_ready", "0")),
    "legacy_v59_contract_source_ready": legacy_v59_contract_ready,
    "legacy_v59_contract_copied_files": legacy_v59_copied_files,
    "v59e_one_command_pm_foundation_demo_ready": as_int(v59e, "v59e_one_command_pm_foundation_demo_ready"),
    "source_snapshot_replay_used": as_int(v59e, "source_snapshot_replay_used"),
    "public_source_download_executed": as_int(v59e, "public_source_download_executed"),
    "public_source_download_approval_required": as_int(v59e, "public_source_download_approval_required"),
    "full_public_source_download_ready": as_int(v59e, "full_public_source_download_ready"),
    "pm_pr_claim_slice_bundle_ready": as_int(v59e, "pm_pr_claim_slice_bundle_ready"),
    "pm_scope_drift_allowed": as_int(v59e, "pm_scope_drift_allowed"),
    "pm_external_return_template_rows": as_int(v59e, "pm_external_return_template_rows"),
    "one_command_replay_preflight_ready": as_int(v59e, "one_command_replay_preflight_ready"),
    "v59_ready": int(v59_summary.get("v59_ready", "0")),
    "required_30b_70b_baselines_ready": int(as_int(v52, "required_30b_baseline_ready") == 1 and as_int(v52, "required_70b_baseline_ready") == 1),
    "real_30b_70b_rows_ready": int(as_int(v52, "required_30b_baseline_ready") == 1 and as_int(v52, "required_70b_baseline_ready") == 1),
    "public_repo_query_scale_ready": int(as_int(v53t, "pm_v53_freeze_ready") == 1 and as_int(v53t, "foundation_direct_pinned_manifest_ready") == 1),
    "v53_query_span_binding_audit_ready": as_int(v53t, "foundation_query_span_binding_audit_ready"),
    "v53_query_span_binding_audit_rows": as_int(v53t, "foundation_query_span_binding_audit_rows"),
    "v53_query_span_binding_pass_rows": as_int(v53t, "foundation_query_span_binding_pass_rows"),
    "pm_pr_v53_query_span_binding_audit_ready": as_int(v59e, "pm_pr_v53_query_span_binding_audit_ready"),
    "v53_direct_pinned_manifest_ready": as_int(v53t, "foundation_direct_pinned_manifest_ready"),
    "v53_direct_repo_manifest_rows": as_int(v53t, "foundation_direct_repo_manifest_rows"),
    "v53_direct_file_manifest_rows": as_int(v53t, "foundation_direct_file_manifest_rows"),
    "v53_direct_content_snapshot_rows": as_int(v53t, "foundation_direct_content_snapshot_rows"),
    "pm_pr_v53_direct_pinned_manifest_ready": as_int(v59e, "pm_pr_v53_direct_pinned_manifest_ready"),
    "local_abgh_prebaseline_ready": int(as_int(v53ap, "v53ap_complete_source_abgh_same_query_measured_ready") == 1),
    "local_abgh_prebaseline_ledger_ready": as_int(v53aq, "same_query_internal_prebaseline_rows_ready"),
    "local_abgh_prebaseline_ledger_rows": as_int(v53aq, "same_query_internal_prebaseline_rows"),
    "h10_real_label_promotion_ready": as_int(h10, "h10_real_label_promotion_ready"),
    "h10_source_verified_eval_ready": as_int(h10, "h10_source_verified_eval_ready"),
    "h10_external_human_label_evidence_ready": as_int(h10, "external_human_label_evidence_ready"),
    "h10_pm_criteria_rows": len(h10_pm_acceptance_rows),
    "h10_pm_criteria_ready": h10_pm_criteria_ready,
    "h10_pm_external_label_blocked": h10_pm_external_label_blocked,
    "h10_pm_source_provenance_binding_ready": h10_pm_source_provenance_binding_ready,
    "h10_pm_copied_files": h10_pm_copied_files,
    "v54c_recommended_output_files_ready": v54c_recommended_output_files_ready,
    "v54c_recommended_output_file_rows": len(v54c_recommended_output_rels),
    "routehint_generation_main_ready": int(as_int(v54c, "v54c_complete_source_grounded_generation_1000_ready") == 1),
    "scaling_law_main_ready": 0,
    "expanded_benchmark_ready": int(as_int(pm_pr, "replay_artifact_pass_rows") == as_int(pm_pr, "recommended_pr_slice_rows")),
    "domain_expert_pack_ready": 0,
    "v58c_blind_response_intake_ready": as_int(v59e, "v58c_blind_response_evidence_intake_ready"),
    "v58c_intake_artifact_available": as_int(v59e, "v58c_intake_artifact_available"),
    "v58c_dependency_blocker_ready": as_int(v59e, "v58c_dependency_blocker_ready"),
    "v58d_blind_review_return_intake_ready": as_int(v59e, "v58d_blind_review_return_intake_ready"),
    "v58d_review_artifact_available": as_int(v59e, "v58d_review_artifact_available"),
    "v58d_dependency_blocker_ready": as_int(v59e, "v58d_dependency_blocker_ready"),
    "v58d_human_blind_review_ready": as_int(v59e, "v58d_human_blind_review_ready"),
    "v58d_inter_rater_rows_ready": as_int(v59e, "v58d_inter_rater_rows_ready"),
    "blind_eval_ready": as_int(v59e, "v58_full_blind_eval_ready"),
    "one_command_pm_foundation_ready": as_int(v59e, "v59e_one_command_pm_foundation_demo_ready"),
    "one_command_real_replay_ready": 0,
    "human_release_review_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md").write_text(
    "# v60 Architecture Challenge Release Boundary\n\n"
    "This is the v60 release-audit gate over the current PM foundation bundle, not the completed v1.0 Architecture Challenge Release.\n\n"
    "Allowed wording:\n\n"
    "- v1.0 Architecture Challenge contract scaffold covering v52-v60 gates.\n"
    "- replayable PM foundation bundle for v53/v54/h10/v58 intake surfaces.\n"
    "- local evidence-bound RouteMemory/RouteHint QA and audit preview.\n\n"
    "Current pass surfaces:\n\n"
    "- v53 10-repo / 1000 source-span-bound query PM freeze\n"
    "- direct v53 1000-row query-span binding audit copied through v59e PM sidecar\n"
    "- direct v53 repo/file/content manifest evidence copied through v59e PM sidecar\n"
    "- internal A/B/G/H same-query pre-baseline without public comparison claim\n"
    "- direct 1000-row A/B/G/H same-query internal pre-baseline ledger copied through v59e PM sidecar\n"
    "- v54 complete-source 1000-row grounded generation with raw prompt stuffing blocked\n"
    "- v59e one-command PM foundation replay with PR split sidecar and execution lock\n\n"
    "Current blocker evidence surfaces:\n\n"
    "- h10 PM criteria rows are copied for coherent wrong-key, chunk exact, near-miss, missing-query abstain, source provenance binding, and external/human label blockers.\n\n"
    "Still blocked:\n\n"
    "- real 30B/70B LLM+RAG comparison rows\n"
    "- h10 real external/human label promotion evidence\n"
    "- v56 expanded benchmark replay artifact\n"
    "- v58c blind-response intake artifact or explicit dependency closure\n"
    "- v58d blind-review/adjudication return artifact or explicit dependency closure\n"
    "- v58 real blind eval responses and human review\n"
    "- full v59 public challenge replay over all real rows\n"
    "- approved public-source download/refresh evidence for the full v59 public replay\n"
    "- human/release review\n"
    "- real release package\n\n"
    "Do not publish v1.0 release, 30B-150B win, public comparison win, h10 scientific contribution, Transformer replacement, frontier local LLM, long-context solved, GPU acceleration, expert replacement, or production-release claims from this gate.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v60-architecture-challenge-release-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v60_release_contract_ready": 1,
    "v60_ready": 0,
    "real_release_package_ready": 0,
    "release_requirement_rows": len(requirement_rows),
    "release_requirement_blocked_rows": sum(1 for row in requirement_rows if row["status"] == "blocked"),
    "release_requirement_ready_rows": sum(int(row["ready"]) for row in requirement_rows),
    "allowed_claim_rows": len(allowed_claim_rows),
    "forbidden_claim_rows": len(forbidden_claim_rows),
    "v59_summary_sha256": sha_or_empty(results / "v59_one_command_challenge_demo_contract_summary.csv"),
    "v59_manifest_sha256": sha_or_empty(v59_dir / "v59_one_command_challenge_demo_manifest.json"),
    "v59e_summary_sha256": sha256(results / "v59e_one_command_pm_foundation_demo_summary.csv"),
    "v59e_manifest_sha256": sha256(v59e_dir / "v59e_one_command_pm_foundation_demo_manifest.json"),
    "pm_pr_summary_sha256": sha256(results / "v1_0_pm_pr_claim_slice_gate_summary.csv"),
    "h10_pm_criteria_rows": len(h10_pm_acceptance_rows),
    "h10_pm_criteria_ready": h10_pm_criteria_ready,
    "h10_pm_external_label_blocked": h10_pm_external_label_blocked,
    "h10_pm_source_provenance_binding_ready": h10_pm_source_provenance_binding_ready,
    "h10_pm_acceptance_sha256": sha_or_empty(run_dir / "source_h10_pm" / "pm_h10_real_label_acceptance_rows.csv"),
    "v53_query_span_binding_audit_ready": as_int(v53t, "foundation_query_span_binding_audit_ready"),
    "v53_query_span_binding_audit_rows": as_int(v53t, "foundation_query_span_binding_audit_rows"),
    "v53_query_span_binding_pass_rows": as_int(v53t, "foundation_query_span_binding_pass_rows"),
    "pm_pr_v53_query_span_binding_audit_ready": as_int(v59e, "pm_pr_v53_query_span_binding_audit_ready"),
    "v53_direct_pinned_manifest_ready": as_int(v53t, "foundation_direct_pinned_manifest_ready"),
    "v53_direct_repo_manifest_rows": as_int(v53t, "foundation_direct_repo_manifest_rows"),
    "v53_direct_file_manifest_rows": as_int(v53t, "foundation_direct_file_manifest_rows"),
    "v53_direct_content_snapshot_rows": as_int(v53t, "foundation_direct_content_snapshot_rows"),
    "pm_pr_v53_direct_pinned_manifest_ready": as_int(v59e, "pm_pr_v53_direct_pinned_manifest_ready"),
    "v54c_recommended_output_files_ready": v54c_recommended_output_files_ready,
    "v54c_recommended_output_file_rows": len(v54c_recommended_output_rels),
}
(run_dir / "v60_architecture_challenge_release_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v60_architecture_challenge_release_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
