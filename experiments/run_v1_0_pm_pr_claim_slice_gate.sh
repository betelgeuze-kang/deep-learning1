#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v1_0_pm_pr_claim_slice_gate"
RUN_ID="${V1_0_PM_PR_SLICE_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V53AQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh" >/dev/null

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
roadmap = root / "docs" / "V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
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


def copy_if_exists(src, rel):
    if src.is_file() and src.stat().st_size > 0:
        dst = run_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        return rel
    return ""


def status(pass_condition, ready_label="ready-for-review", blocked_label="blocked"):
    return ready_label if pass_condition else blocked_label


def safe_id(value):
    return value.replace("/", "__").replace(" ", "_")


roadmap_text = roadmap.read_text(encoding="utf-8")
summary_sources = {
    "v52": results / "v52_llm_rag_baseline_war_summary.csv",
    "v52y": results / "v52y_f_optional_final_policy_summary.csv",
    "v53t": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53ap": results / "v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "v53aq": results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "v54c": results / "v54c_complete_source_grounded_generation_1000_summary.csv",
    "h10_pm": results / "v10_h10_real_label_promotion_readiness_gate_summary.csv",
    "v56b": results / "v56b_ruler_longbench_expanded_scale_summary.csv",
    "v59e": results / "v59e_one_command_pm_foundation_demo_summary.csv",
    "v60": results / "v60_architecture_challenge_release_contract_summary.csv",
    "v61j": results / "v61j_one_command_ssd_resident_demo_summary.csv",
}
summaries = {key: read_first(path) for key, path in summary_sources.items()}

copied_summary_rows = []
for key, path in summary_sources.items():
    rel = copy_if_exists(path, f"source_summaries/{path.name}")
    copied_summary_rows.append(
        {
            "source_id": key,
            "summary_path": str(path.relative_to(root)),
            "copied_path": rel,
            "present": "1" if rel else "0",
            "sha256": sha256(path) if rel else "",
        }
    )
copy_if_exists(roadmap, "source_docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md")
v53t_foundation_freeze_path = results / "v53t_complete_source_audit_readiness_gate" / "gate_001" / "complete_source_foundation_freeze_rows.csv"
v53t_foundation_freeze_copied = copy_if_exists(
    v53t_foundation_freeze_path,
    "source_v53t/complete_source_foundation_freeze_rows.csv",
)
v53t_real_adapter_freeze_path = results / "v53t_complete_source_audit_readiness_gate" / "gate_001" / "complete_source_abgh_real_adapter_freeze_rows.csv"
v53t_real_adapter_freeze_copied = copy_if_exists(
    v53t_real_adapter_freeze_path,
    "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
)
v53t_run_dir = results / "v53t_complete_source_audit_readiness_gate" / "gate_001"
v53t_direct_copied = {}
for src_rel in [
    "complete_source_pm_acceptance_evidence_rows.csv",
    "complete_source_v1_exit_criteria_rows.csv",
    "complete_source_query_span_binding_audit_rows.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/source_v53h/complete_source_content_repo_rows.csv",
    "source_v53i/source_v53h/complete_source_content_snapshot_rows.csv",
    "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv",
    "source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_v53ap/abgh_answer_rows.csv",
    "source_v53ap/abgh_citation_rows.csv",
    "source_v53ap/abgh_evaluator_rows.csv",
    "source_v53ap/abgh_resource_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
    "source_v53aq/abgh_internal_prebaseline_contract_rows.csv",
]:
    v53t_direct_copied[src_rel] = copy_if_exists(v53t_run_dir / src_rel, f"source_v53t/{src_rel}")
v53aq_run_dir = results / "v53aq_complete_source_abgh_real_adapter_measured" / "measured_001"
v53aq_direct_copied = {}
for src_rel in [
    "adapter_selection_contract_rows.csv",
    "abgh_system_rows.csv",
    "abgh_system_metric_rows.csv",
    "abgh_answer_rows.csv",
    "abgh_citation_rows.csv",
    "abgh_evaluator_rows.csv",
    "abgh_resource_rows.csv",
    "abgh_adapter_trace_rows.csv",
    "abgh_wrong_answer_guard_rows.csv",
    "abgh_same_query_internal_prebaseline_rows.csv",
    "abgh_internal_prebaseline_contract_rows.csv",
    "route_memory_rows.csv",
    "routehint_rows.csv",
    "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md",
    "sha256_manifest.csv",
]:
    v53aq_direct_copied[src_rel] = copy_if_exists(v53aq_run_dir / src_rel, f"source_v53aq/{src_rel}")
v53aq_selection_contract_rows = read_rows(v53aq_run_dir / "adapter_selection_contract_rows.csv")
v53aq_selection_contract_by_field = {
    row.get("field_name", ""): row for row in v53aq_selection_contract_rows
}
v59e_public_source_policy_path = results / "v59e_one_command_pm_foundation_demo" / "pm_foundation_001" / "public_source_replay_policy_rows.csv"
v59e_public_source_policy_copied = copy_if_exists(
    v59e_public_source_policy_path,
    "source_v59e/public_source_replay_policy_rows.csv",
)
v59e_public_source_policy_rows = read_rows(v59e_public_source_policy_path)
v59e_public_source_policy = v59e_public_source_policy_rows[0] if v59e_public_source_policy_rows else {}
v59e_local_abgh_row_contract_path = results / "v59e_one_command_pm_foundation_demo" / "pm_foundation_001" / "local_abgh_row_contract_replay_rows.csv"
v59e_local_abgh_row_contract_copied = copy_if_exists(
    v59e_local_abgh_row_contract_path,
    "source_v59e/local_abgh_row_contract_replay_rows.csv",
)
v59e_local_abgh_row_contract_rows = read_rows(v59e_local_abgh_row_contract_path)
v59e_local_abgh_row_contract_ready = int(
    len(v59e_local_abgh_row_contract_rows) == 2
    and as_int(summaries["v59e"], "local_abgh_row_contract_replay_ready") == 1
    and as_int(summaries["v59e"], "local_abgh_row_contract_replay_rows") == 2
    and as_int(summaries["v59e"], "local_abgh_row_contract_replay_pass_rows") == 2
    and bool(v59e_local_abgh_row_contract_copied)
    and {row.get("source_stage", "") for row in v59e_local_abgh_row_contract_rows} == {"v53ap", "v53aq"}
    and all(
        row.get("status") == "pass"
        and row.get("systems") == "A/B/G/H"
        and row.get("answer_rows") == "4000"
        and row.get("citation_rows") == "4000"
        and row.get("evaluator_rows") == "4000"
        and row.get("resource_rows") == "4000"
        and row.get("same_query_row_contract") == "1"
        and row.get("same_evaluator_contract_all_local_systems") == "1"
        and row.get("same_resource_contract_all_local_systems") == "1"
        and row.get("expected_answer_oracle_replay_any") == "0"
        and row.get("public_comparison_claim_ready") == "0"
        for row in v59e_local_abgh_row_contract_rows
    )
)
h10_pm_dir = results / "v10_h10_real_label_promotion_readiness_gate" / "gate_001"
h10_acceptance_rows_path = h10_pm_dir / "pm_h10_real_label_acceptance_rows.csv"
h10_template_path = h10_pm_dir / "h10_real_label_evidence_template.csv"
h10_evidence_acceptance_path = h10_pm_dir / "h10_real_label_evidence_acceptance_rows.csv"
h10_return_contract_path = h10_pm_dir / "h10_real_label_return_contract_rows.csv"
h10_acceptance_evidence_path = h10_pm_dir / "h10_real_label_acceptance_evidence_rows.csv"
h10_v53aq_prebaseline_path = h10_pm_dir / "source_v53aq" / "abgh_same_query_internal_prebaseline_rows.csv"
h10_v53aq_contract_path = h10_pm_dir / "source_v53aq" / "abgh_internal_prebaseline_contract_rows.csv"
h10_acceptance_rows_copied = copy_if_exists(
    h10_acceptance_rows_path,
    "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
)
copy_if_exists(h10_template_path, "source_h10_pm/h10_real_label_evidence_template.csv")
copy_if_exists(h10_evidence_acceptance_path, "source_h10_pm/h10_real_label_evidence_acceptance_rows.csv")
copy_if_exists(h10_return_contract_path, "source_h10_pm/h10_real_label_return_contract_rows.csv")
copy_if_exists(h10_acceptance_evidence_path, "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv")
copy_if_exists(h10_v53aq_prebaseline_path, "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv")
copy_if_exists(h10_v53aq_contract_path, "source_h10_pm/source_v53aq/abgh_internal_prebaseline_contract_rows.csv")
h10_acceptance_rows = read_rows(h10_acceptance_rows_path)
h10_acceptance_by_criterion = {
    row.get("criterion", ""): row
    for row in h10_acceptance_rows
}
h10_return_contract_rows = read_rows(h10_return_contract_path)
h10_return_contract_by_criterion = {
    row.get("criterion", ""): row
    for row in h10_return_contract_rows
}
h10_acceptance_evidence_rows = read_rows(h10_acceptance_evidence_path)
h10_v53aq_contract_rows = read_rows(h10_v53aq_contract_path)
h10_coverage_fields = [
    "accepted_real_label_evidence_rows",
    "accepted_query_rows_declared",
    "accepted_label_rows",
    "accepted_criterion_label_count",
    "required_criterion_label_count",
    "criterion_label_coverage_status",
    "source_verified_eval_status",
]
h10_acceptance_evidence_coverage_field_rows = sum(
    1 for row in h10_acceptance_evidence_rows if all(field in row for field in h10_coverage_fields)
)
h10_acceptance_evidence_label_coverage_blocked_rows = sum(
    1 for row in h10_acceptance_evidence_rows if row.get("criterion_label_coverage_status") == "blocked"
)
h10_acceptance_evidence_source_verified_blocked_rows = sum(
    1 for row in h10_acceptance_evidence_rows if row.get("source_verified_eval_status") == "blocked"
)
h10_acceptance_evidence_zero_accepted_rows = sum(
    1
    for row in h10_acceptance_evidence_rows
    if as_int(row, "accepted_real_label_evidence_rows") == 0
    and as_int(row, "accepted_query_rows_declared") == 0
    and as_int(row, "accepted_label_rows") == 0
    and as_int(row, "accepted_criterion_label_count") == 0
)
v53t_foundation_freeze_rows = read_rows(v53t_foundation_freeze_path)
v53t_query_span_binding_rows = read_rows(v53t_run_dir / "complete_source_query_span_binding_audit_rows.csv")
v53t_foundation_by_id = {
    row.get("criterion_id", ""): row
    for row in v53t_foundation_freeze_rows
}
v53t_answer_citation_foundation = v53t_foundation_by_id.get("answer-citation-separated-evaluator", {})
write_csv(run_dir / "source_summary_rows.csv", list(copied_summary_rows[0].keys()), copied_summary_rows)

slice_ids = [
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

v52 = summaries["v52"]
v52y = summaries["v52y"]
v52d_summary_path = results / "v52d_30b70b_llm_rag_evidence_intake_summary.csv"
v52d = read_first(v52d_summary_path)
v52d_summary_copied = copy_if_exists(
    v52d_summary_path,
    "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv",
)
v53t = summaries["v53t"]
v53ap = summaries["v53ap"]
v53aq = summaries["v53aq"]
v54c = summaries["v54c"]
h10_pm = summaries["h10_pm"]
v56b = summaries["v56b"]
v56_contract_summary_path = results / "v56_ruler_longbench_expanded_contract_summary.csv"
v56_contract = read_first(v56_contract_summary_path)
v56_contract_summary_copied = copy_if_exists(
    v56_contract_summary_path,
    "source_v56/v56_ruler_longbench_expanded_contract_summary.csv",
)
v56_seed_dependency_blocker_path = results / "v56_ruler_longbench_expanded_contract" / "contract_001" / "v56_seed_dependency_blocker_rows.csv"
v56_seed_dependency_blocker_copied = copy_if_exists(
    v56_seed_dependency_blocker_path,
    "source_v56/v56_seed_dependency_blocker_rows.csv",
)
copy_if_exists(
    results / "v56_ruler_longbench_expanded_contract" / "contract_001" / "V56_RULER_LONGBENCH_DEPENDENCY_BLOCKER.md",
    "source_v56/V56_RULER_LONGBENCH_DEPENDENCY_BLOCKER.md",
)
v56_seed_dependency_blocker_rows = read_rows(v56_seed_dependency_blocker_path)
v59e = summaries["v59e"]
v60 = summaries["v60"]
v61j = summaries["v61j"]

slice_specs = [
    {
        "slice_id": "docs/v1-roadmap",
        "scope": "roadmap, claim boundary, release blockers",
        "required_artifacts": "docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
        "merge_condition": "allowed and blocked claims are explicit; PR split table exists; release blockers are visible",
        "claim_ok": all(text in roadmap_text for text in ["Recommended review slices", "blocked until proven", "Transformer replacement"]),
        "replay_ok": roadmap.is_file(),
        "blocker_ok": "real_release_package_ready" in roadmap_text and "pre-v1.0 research artifact" in roadmap_text,
        "reason": "roadmap has claim boundary and recommended PR slices",
    },
    {
        "slice_id": "v52-baseline-registry-contract",
        "scope": "A-H baseline registry/schema contract",
        "required_artifacts": "v52 baseline-war summary plus v52y measured-registry policy summary",
        "merge_condition": "replayable output schema and symmetric verifier contract exist; D/E/F blockers do not become release readiness",
        "claim_ok": as_int(v52, "release_ready_claim") == 0 and as_int(v52, "real_release_package_ready") == 0,
        "replay_ok": as_int(v52, "v52_baseline_war_contract_ready") == 1 and as_int(v52, "symmetric_citation_contract_ready") == 1,
        "blocker_ok": as_int(v52, "required_30b_baseline_ready") == 0 and as_int(v52, "required_70b_baseline_ready") == 0,
        "reason": "baseline contract is replayable while full comparison remains blocked",
    },
    {
        "slice_id": "v53-public-repo-source-manifest",
        "scope": "pinned 10+ repo source manifest",
        "required_artifacts": "v53t direct repo coverage, file manifest, content snapshot rows, PM freeze rows, and foundation freeze certificate",
        "merge_condition": "commits, licenses, source files, repo count, and hashes are bound",
        "claim_ok": as_int(v53t, "v53_ready") == 0 and as_int(v53t, "real_release_package_ready") == 0,
        "replay_ok": as_int(v53t, "complete_source_repo_count") >= 10
        and as_int(v53t, "machine_complete_source_surface_ready") == 1
        and as_int(v53t, "foundation_machine_freeze_ready") == 1
        and as_int(v53t, "foundation_direct_pinned_manifest_ready") == 1
        and bool(v53t_direct_copied.get("source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv"))
        and bool(v53t_direct_copied.get("source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv"))
        and bool(v53t_direct_copied.get("source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")),
        "blocker_ok": as_int(v53t, "review_return_ready") == 0 and as_int(v53t, "quality_comparison_claim_ready") == 0,
        "reason": (
            "10 public repos are present with direct pinned repo/file/content manifests; "
            f"repo_manifest_rows={v53t.get('foundation_direct_repo_manifest_rows', '0')} "
            f"file_manifest_rows={v53t.get('foundation_direct_file_manifest_rows', '0')} "
            f"content_snapshot_rows={v53t.get('foundation_direct_content_snapshot_rows', '0')}"
        ),
    },
    {
        "slice_id": "v53-query-instantiation-1000",
        "scope": "1000 source-span-bound query rows",
        "required_artifacts": "v53t PM freeze rows, foundation freeze certificate, and v53i query/source-span summaries",
        "merge_condition": "every query binds to a pinned source span; unsupported/missing/doc-code controls are explicit",
        "claim_ok": as_int(v53t, "v53_ready") == 0 and as_int(v53t, "foundation_machine_freeze_ready") == 1,
        "replay_ok": as_int(v53t, "complete_source_query_rows") == 1000 and as_int(v53t, "complete_source_span_rows") == 1000 and as_int(v53t, "foundation_freeze_certificate_rows") == 10,
        "blocker_ok": as_int(v53t, "negative_abstain_rows") >= 100 and as_int(v53t, "unsupported_control_rows") == 100 and as_int(v53t, "missing_specific_control_rows") == 30 and as_int(v53t, "doc_code_conflict_rows") == 140,
        "reason": (
            "1000 source-span-bound rows with explicit controls are present; "
            f"negative_abstain={v53t.get('negative_abstain_rows', '0')} "
            f"unsupported={v53t.get('unsupported_control_rows', '0')} "
            f"missing_specific={v53t.get('missing_specific_control_rows', '0')} "
            f"doc_code_conflict={v53t.get('doc_code_conflict_rows', '0')}"
        ),
    },
    {
        "slice_id": "v53-system-a-b-g-h-measured",
        "scope": "same-query A/B/G/H pre-baseline rows",
        "required_artifacts": "v53ap A/B/G/H answer/citation/resource/guard rows",
        "merge_condition": "internal-only comparison wording; same source/query/evaluator/resource rows; no D/E public comparison claim",
        "claim_ok": as_int(v53ap, "internal_v1_0_pre_baseline_run") == 1 and as_int(v53ap, "public_comparison_claim_ready") == 0,
        "replay_ok": as_int(v53ap, "v53ap_complete_source_abgh_same_query_measured_ready") == 1
        and v53ap.get("systems") == "A/B/G/H"
        and as_int(v53ap, "same_query_set_all_local_systems") == 1
        and as_int(v53ap, "same_source_manifest_all_local_systems") == 1
        and as_int(v53ap, "same_evaluator_contract_all_local_systems") == 1
        and as_int(v53ap, "same_resource_contract_all_local_systems") == 1,
        "blocker_ok": as_int(v53ap, "required_30b_baseline_ready") == 0 and as_int(v53ap, "required_70b_baseline_ready") == 0,
        "reason": "A/B/G/H are measured over the frozen complete-source query set",
    },
    {
        "slice_id": "v54-routehint-generation-contract",
        "scope": "grounded RouteHint generation contract",
        "required_artifacts": "v54c answer/citation/unsupported/abstain/resource/guard rows and sha256sums",
        "merge_condition": "raw prompt stuffing remains zero; unsupported answers are guarded; recommended generation outputs exist",
        "claim_ok": as_int(v54c, "human_review_ready") == 0 and as_int(v54c, "real_release_package_ready") == 0,
        "replay_ok": as_int(v54c, "v54c_complete_source_grounded_generation_1000_ready") == 1
        and as_int(v54c, "answer_rows") == 1000
        and as_int(v54c, "citation_rows") == 1000
        and as_int(v54c, "unsupported_claim_rows") == 160
        and as_int(v54c, "abstain_rows") == 160
        and as_int(v54c, "generator_resource_rows") == 1000
        and as_int(v54c, "wrong_answer_guard_rows") == 1000,
        "blocker_ok": as_int(v54c, "raw_prompt_context_appended_rows") == 0 and as_int(v54c, "wrong_answer_rows") == 0,
        "reason": (
            "v54c emits PM-recommended generation outputs with no raw prompt stuffing; "
            f"answer={v54c.get('answer_rows', '0')} citation={v54c.get('citation_rows', '0')} "
            f"unsupported={v54c.get('unsupported_claim_rows', '0')} abstain={v54c.get('abstain_rows', '0')} "
            f"resource={v54c.get('generator_resource_rows', '0')} guard={v54c.get('wrong_answer_guard_rows', '0')}"
        ),
    },
    {
        "slice_id": "v56-ruler-longbench-expanded",
        "scope": "source/evaluator-bound benchmark expansion",
        "required_artifacts": "v56 expanded prediction/source/evaluator rows",
        "merge_condition": "official source/evaluator hashes and raw prediction rows are replayable",
        "claim_ok": as_int(v56b, "real_external_benchmark_verified") == 0,
        "replay_ok": as_int(v56b, "v56b_ruler_longbench_expanded_scale_ready") == 1,
        "blocker_ok": as_int(v56b, "real_release_package_ready") == 0,
        "reason": "blocked until the v56 expanded benchmark summary is present and release claims remain closed",
    },
    {
        "slice_id": "v58-blind-eval-contract",
        "scope": "blind evaluation contract",
        "required_artifacts": "blind response/review intake contract or blocker ledger",
        "merge_condition": "identity hiding, symmetric citation verification, real response blockers, human-review blockers, and failure rows are explicit",
        "claim_ok": as_int(v59e, "v58_full_blind_eval_ready") == 0,
        "replay_ok": as_int(v59e, "v58_pm_blind_eval_blocker_ready") == 1,
        "blocker_ok": as_int(v59e, "full_v1_public_demo_ready") == 0 and as_int(v59e, "real_release_package_ready") == 0,
        "reason": "current v59e carries a lightweight v58 blocker ledger; real blind eval remains blocked",
    },
    {
        "slice_id": "v59-one-command-demo",
        "scope": "reviewer command and artifact bundle",
        "required_artifacts": "v59e PM foundation one-command bundle",
        "merge_condition": "no private fixture, undocumented local state, network/download requirement, or manual post-processing is needed for the PM foundation replay",
        "claim_ok": as_int(v59e, "v59_ready") == 0 and as_int(v59e, "full_v1_public_demo_ready") == 0,
        "replay_ok": as_int(v59e, "one_command_entrypoint_ready") == 1 and as_int(v59e, "challenge_bundle_ready") == 1,
        "blocker_ok": as_int(v59e, "private_fixture_required") == 0
        and as_int(v59e, "manual_postprocessing_required") == 0
        and as_int(v59e, "undocumented_local_state_required") == 0
        and as_int(v59e, "network_required") == 0
        and as_int(v59e, "downloads_required") == 0
        and as_int(v59e, "public_source_download_executed") == 0
        and as_int(v59e, "full_public_source_download_ready") == 0,
        "reason": "PM foundation one-command replay is ready without network/downloads while full public source refresh stays blocked",
    },
    {
        "slice_id": "v61-ssd-moe-runtime-roadmap",
        "scope": "SSD-resident runtime R&D roadmap",
        "required_artifacts": "v61j one-command SSD-resident demo summary",
        "merge_condition": "no dense local speed, near-frontier, production, or release-ready claim is implied",
        "claim_ok": as_int(v61j, "near_frontier_claim_ready") == 0 and as_int(v61j, "real_release_package_ready") == 0,
        "replay_ok": as_int(v61j, "v61j_one_command_ssd_resident_demo_ready") == 1,
        "blocker_ok": as_int(v61j, "real_100b_open_weight_materialized") == 0 and as_int(v61j, "ram_resident_full_model_fallback_rows") == 0,
        "reason": "v61 stays an R&D option with no near-frontier or release wording",
    },
]

if [spec["slice_id"] for spec in slice_specs] != slice_ids:
    raise SystemExit("PM PR slice order drifted")

slice_rows = []
gate_rows = []
for ordinal, spec in enumerate(slice_specs, start=1):
    merge_condition_defined = int(
        "claim" in spec["merge_condition"]
        or "replay" in spec["merge_condition"]
        or "blocker" in spec["merge_condition"]
        or "guard" in spec["merge_condition"]
        or "source" in spec["merge_condition"]
    )
    current_ready = int(spec["claim_ok"] and spec["replay_ok"] and spec["blocker_ok"])
    current_status = status(current_ready)
    if spec["slice_id"] == "v61-ssd-moe-runtime-roadmap" and current_ready:
        current_status = "ready-for-rd-review"
    elif spec["slice_id"] in {"v56-ruler-longbench-expanded"} and not current_ready:
        current_status = "blocked-missing-replay-artifact"
    elif spec["slice_id"] in {"v58-blind-eval-contract"} and current_ready:
        current_status = "ready-for-contract-review-real-eval-blocked"
    elif spec["slice_id"] in {"v59-one-command-demo"} and current_ready:
        current_status = "pm-foundation-ready-full-demo-blocked"

    slice_rows.append(
        {
            "ordinal": str(ordinal),
            "slice_id": spec["slice_id"],
            "scope": spec["scope"],
            "required_artifacts": spec["required_artifacts"],
            "merge_condition": spec["merge_condition"],
            "merge_condition_defined": str(merge_condition_defined),
            "claim_boundary_ok": str(int(spec["claim_ok"])),
            "replay_artifact_ok": str(int(spec["replay_ok"])),
            "blocker_false_positive_closed": str(int(spec["blocker_ok"])),
            "current_merge_ready": str(current_ready),
            "current_status": current_status,
            "reason": spec["reason"],
        }
    )
    for gate, ok, reason in [
        ("claim-boundary", spec["claim_ok"], "claim boundary or allowed/blocked wording is explicit"),
        ("replay-artifact", spec["replay_ok"], "required output artifact or summary is present and replayable"),
        ("blocker-false-positive", spec["blocker_ok"], "missing external/review/release evidence does not open a ready flag"),
    ]:
        gate_rows.append(
            {
                "slice_id": spec["slice_id"],
                "gate": gate,
                "status": "pass" if ok else "blocked",
                "reason": reason,
            }
        )

write_csv(run_dir / "pm_pr_slice_rows.csv", list(slice_rows[0].keys()), slice_rows)
write_csv(run_dir / "pm_pr_merge_gate_rows.csv", list(gate_rows[0].keys()), gate_rows)


def claim_boundary_row(slice_id, allowed_claim, blocked_claim, evidence_path, status_value="pass"):
    return {
        "slice_id": slice_id,
        "allowed_claim": allowed_claim,
        "blocked_claim": blocked_claim,
        "evidence_path": evidence_path,
        "claim_boundary_status": status_value,
    }


claim_boundary_rows = [
    claim_boundary_row(
        "docs/v1-roadmap",
        "v1.0 roadmap defines source-cited, abstaining, replayable local QA/audit architecture scope",
        "Transformer replacement, frontier local LLM, production readiness, or public comparison win",
        "source_docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
    ),
    claim_boundary_row(
        "v52-baseline-registry-contract",
        "A-H baseline registry and symmetric citation/evaluator contract exist with D/E/F blockers explicit",
        "30B/70B/100B+ comparison readiness or release readiness",
        "source_summaries/v52_llm_rag_baseline_war_summary.csv",
    ),
    claim_boundary_row(
        "v53-public-repo-source-manifest",
        "10 public repos and complete-source manifest surface are machine-bound for PM freeze",
        "human-reviewed quality comparison, public benchmark claim, or v53 final readiness",
        "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    ),
    claim_boundary_row(
        "v53-query-instantiation-1000",
        "1000 complete-source queries bind to source spans with unsupported/missing/doc-code controls",
        "review-return completion, quality comparison, or v1.0 comparison readiness",
        "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
    ),
    claim_boundary_row(
        "v53-system-a-b-g-h-measured",
        "A/B/G/H same-query measured run is an internal v1.0 pre-baseline packet",
        "public comparison claim, D/E replacement, or 30B/70B symmetric baseline completion",
        "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
    ),
    claim_boundary_row(
        "v54-routehint-generation-contract",
        "v54c emits 1000 grounded generation rows with answer/citation/abstain/resource/guard outputs and zero raw prompt stuffing",
        "human-reviewed generation quality, mainline raw prompt stuffing, or release-ready generation",
        "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
    ),
    claim_boundary_row(
        "v56-ruler-longbench-expanded",
        "v56 runner and fail-closed guard define replay requirements for source/evaluator-bound benchmark expansion",
        "expanded benchmark readiness, leaderboard claim, or external benchmark verification without replay artifact",
        "pm_blocker_required_artifact_rows.csv",
    ),
    claim_boundary_row(
        "v58-blind-eval-contract",
        "v58 blocker ledger and intake contract define blind-response/review requirements",
        "blind eval completion, model superiority, or human-reviewed blind result without real response/review rows",
        "pm_blocker_required_artifact_rows.csv",
    ),
    claim_boundary_row(
        "v59-one-command-demo",
        "v59e PM foundation one-command replay is ready without private fixtures, hidden state, network, downloads, or manual postprocessing, using pinned-source snapshot replay",
        "full v59 public challenge demo, public-source download/refresh readiness, v58 blind completion, h10 promotion, or v60 release readiness",
        v59e_public_source_policy_copied or "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
    ),
    claim_boundary_row(
        "v61-ssd-moe-runtime-roadmap",
        "v61 SSD-resident runtime remains an R&D roadmap/demo surface",
        "dense local speed, near-frontier quality, production latency, or release-ready runtime claim",
        "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
    ),
]
write_csv(run_dir / "pm_pr_claim_boundary_rows.csv", list(claim_boundary_rows[0].keys()), claim_boundary_rows)


def file_row(slice_id, file_path, role, inclusion):
    path = root / file_path
    return {
        "slice_id": slice_id,
        "file_path": file_path,
        "role": role,
        "inclusion": inclusion,
        "exists": str(int(path.is_file())),
    }


slice_file_rows = [
    file_row("docs/v1-roadmap", "docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md", "roadmap", "include"),
    file_row("docs/v1-roadmap", "docs/EXPERIMENTS.md", "experiment-index", "include-if-docs-touched"),
    file_row("docs/v1-roadmap", "README.md", "top-level-status", "include-if-docs-touched"),
    file_row("v52-baseline-registry-contract", "experiments/run_v52_llm_rag_baseline_war.sh", "runner", "include"),
    file_row("v52-baseline-registry-contract", "experiments/test_v52_llm_rag_baseline_war.sh", "smoke", "include"),
    file_row("v52-baseline-registry-contract", "experiments/run_v52y_f_optional_final_policy.sh", "runner", "include"),
    file_row("v52-baseline-registry-contract", "experiments/test_v52y_f_optional_final_policy.sh", "smoke", "include"),
    file_row("v52-baseline-registry-contract", "experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh", "blocked-baseline-intake", "reference"),
    file_row("v52-baseline-registry-contract", "experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh", "blocked-baseline-smoke", "reference"),
    file_row("v53-public-repo-source-manifest", "experiments/run_v53g_complete_source_manifest.sh", "runner", "include"),
    file_row("v53-public-repo-source-manifest", "experiments/test_v53g_complete_source_manifest.sh", "smoke", "include"),
    file_row("v53-public-repo-source-manifest", "experiments/run_v53h_complete_source_content_snapshot.sh", "runner", "include"),
    file_row("v53-public-repo-source-manifest", "experiments/test_v53h_complete_source_content_snapshot.sh", "smoke", "include"),
    file_row("v53-public-repo-source-manifest", "experiments/run_v53t_complete_source_audit_readiness_gate.sh", "readiness-gate", "include-if-audit-touched"),
    file_row("v53-query-instantiation-1000", "experiments/run_v53i_complete_source_query_instantiation.sh", "runner", "include"),
    file_row("v53-query-instantiation-1000", "experiments/test_v53i_complete_source_query_instantiation.sh", "smoke", "include"),
    file_row("v53-query-instantiation-1000", "experiments/run_v53t_complete_source_audit_readiness_gate.sh", "readiness-gate", "include"),
    file_row("v53-query-instantiation-1000", "experiments/test_v53t_complete_source_audit_readiness_gate.sh", "readiness-smoke", "include"),
    file_row("v53-system-a-b-g-h-measured", "experiments/run_v53ap_complete_source_abgh_same_query_measured.sh", "runner", "include"),
    file_row("v53-system-a-b-g-h-measured", "experiments/test_v53ap_complete_source_abgh_same_query_measured.sh", "smoke", "include"),
    file_row("v53-system-a-b-g-h-measured", "experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh", "real-adapter-runner", "include"),
    file_row("v53-system-a-b-g-h-measured", "experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh", "real-adapter-smoke", "include"),
    file_row("v54-routehint-generation-contract", "experiments/run_v54c_complete_source_grounded_generation_1000.sh", "runner", "include"),
    file_row("v54-routehint-generation-contract", "experiments/test_v54c_complete_source_grounded_generation_1000.sh", "smoke", "include"),
    file_row("v56-ruler-longbench-expanded", "experiments/run_v56_ruler_longbench_expanded_contract.sh", "contract-runner", "include"),
    file_row("v56-ruler-longbench-expanded", "experiments/test_v56_ruler_longbench_expanded_contract.sh", "contract-smoke", "include"),
    file_row("v56-ruler-longbench-expanded", "experiments/run_v56b_ruler_longbench_expanded_scale.sh", "scale-runner", "include"),
    file_row("v56-ruler-longbench-expanded", "experiments/test_v56b_ruler_longbench_expanded_scale.sh", "scale-smoke", "include"),
    file_row("v58-blind-eval-contract", "experiments/run_v58_blind_eval_contract.sh", "contract-runner", "reference"),
    file_row("v58-blind-eval-contract", "experiments/test_v58_blind_eval_contract.sh", "contract-smoke", "reference"),
    file_row("v58-blind-eval-contract", "experiments/run_v58b_blind_eval_candidate_500.sh", "candidate-runner", "reference"),
    file_row("v58-blind-eval-contract", "experiments/test_v58b_blind_eval_candidate_500.sh", "candidate-smoke", "reference"),
    file_row("v58-blind-eval-contract", "experiments/run_v58c_blind_response_evidence_intake.sh", "response-intake-runner", "reference"),
    file_row("v58-blind-eval-contract", "experiments/test_v58c_blind_response_evidence_intake.sh", "response-intake-smoke", "reference"),
    file_row("v59-one-command-demo", "examples/v1_0_architecture_challenge_pm_foundation_demo.sh", "entrypoint", "include"),
    file_row("v59-one-command-demo", "experiments/run_v59e_one_command_pm_foundation_demo.sh", "runner", "include"),
    file_row("v59-one-command-demo", "experiments/test_v59e_one_command_pm_foundation_demo.sh", "smoke", "include"),
    file_row("v59-one-command-demo", "experiments/run_v1_0_pm_pr_claim_slice_gate.sh", "pr-slice-gate", "include"),
    file_row("v59-one-command-demo", "experiments/test_v1_0_pm_pr_claim_slice_gate.sh", "pr-slice-smoke", "include"),
    file_row("v61-ssd-moe-runtime-roadmap", "experiments/run_v61j_one_command_ssd_resident_demo.sh", "runner", "include"),
    file_row("v61-ssd-moe-runtime-roadmap", "experiments/test_v61j_one_command_ssd_resident_demo.sh", "smoke", "include"),
]
write_csv(run_dir / "pm_pr_slice_file_rows.csv", list(slice_file_rows[0].keys()), slice_file_rows)


def command_row(slice_id, command, purpose, execution_policy):
    return {
        "slice_id": slice_id,
        "command": command,
        "purpose": purpose,
        "execution_policy": execution_policy,
    }


slice_verification_rows = [
    command_row("docs/v1-roadmap", "experiments/test_v1_0_pm_pr_claim_slice_gate.sh", "roadmap claim-boundary and PR split ledger", "local-smoke"),
    command_row("v52-baseline-registry-contract", "experiments/test_v52_llm_rag_baseline_war.sh", "baseline registry contract", "local-smoke"),
    command_row("v52-baseline-registry-contract", "experiments/test_v52y_f_optional_final_policy.sh", "F optional final policy and baseline blockers", "local-smoke"),
    command_row("v53-public-repo-source-manifest", "experiments/test_v53g_complete_source_manifest.sh", "complete-source git tree manifest", "local-smoke"),
    command_row("v53-public-repo-source-manifest", "experiments/test_v53h_complete_source_content_snapshot.sh", "complete-source content hashes", "local-smoke"),
    command_row("v53-query-instantiation-1000", "experiments/test_v53i_complete_source_query_instantiation.sh", "1000 source-span query rows and controls", "local-smoke"),
    command_row("v53-query-instantiation-1000", "experiments/test_v53t_complete_source_audit_readiness_gate.sh", "PM freeze/audit readiness", "local-smoke"),
    command_row("v53-system-a-b-g-h-measured", "experiments/test_v53ap_complete_source_abgh_same_query_measured.sh", "A/B/G/H same-query measured rows", "local-smoke"),
    command_row("v53-system-a-b-g-h-measured", "experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh", "A/B/G/H query-text-only real adapter rows", "local-smoke"),
    command_row("v54-routehint-generation-contract", "experiments/test_v54c_complete_source_grounded_generation_1000.sh", "grounded generation outputs and no raw prompt stuffing", "local-smoke"),
    command_row("v56-ruler-longbench-expanded", "experiments/test_v56_ruler_longbench_expanded_contract.sh", "v56 contract or missing-seed fail-closed guard", "local-smoke"),
    command_row("v56-ruler-longbench-expanded", "experiments/test_v56b_ruler_longbench_expanded_scale.sh", "v56b replay or missing-contract fail-closed guard", "local-smoke"),
    command_row("v58-blind-eval-contract", "experiments/test_v59e_one_command_pm_foundation_demo.sh", "lightweight v58 blocker ledger via PM foundation bundle", "local-smoke"),
    command_row("v58-blind-eval-contract", "experiments/test_v58c_blind_response_evidence_intake.sh", "real blind response intake shape when supplied", "defer-until-real-response-evidence"),
    command_row("v59-one-command-demo", "experiments/test_v59e_one_command_pm_foundation_demo.sh", "PM foundation one-command replay", "local-smoke"),
    command_row("v59-one-command-demo", "experiments/test_v1_0_pm_pr_claim_slice_gate.sh", "PR split and roadmap requirement audit refreshed by one command", "local-smoke"),
    command_row("v61-ssd-moe-runtime-roadmap", "experiments/test_v61j_one_command_ssd_resident_demo.sh", "SSD-resident R&D roadmap demo without release claim", "local-smoke"),
]
write_csv(run_dir / "pm_pr_slice_verification_rows.csv", list(slice_verification_rows[0].keys()), slice_verification_rows)

decision_rows = []
for row in slice_rows:
    if row["current_merge_ready"] == "1":
        status_value = "pass"
    else:
        status_value = "blocked"
    decision_rows.append(
        {
            "gate": row["slice_id"],
            "status": status_value,
            "reason": row["current_status"],
        }
    )
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

ready_rows = sum(1 for row in slice_rows if row["current_merge_ready"] == "1")
merge_condition_defined_rows = sum(1 for row in slice_rows if row["merge_condition_defined"] == "1")
claim_pass_rows = sum(1 for row in slice_rows if row["claim_boundary_ok"] == "1")
replay_pass_rows = sum(1 for row in slice_rows if row["replay_artifact_ok"] == "1")
blocker_pass_rows = sum(1 for row in slice_rows if row["blocker_false_positive_closed"] == "1")
blocked_rows = len(slice_rows) - ready_rows
plan_ready = int(len(slice_rows) == 10 and len(gate_rows) == 30 and merge_condition_defined_rows == 10 and claim_pass_rows >= 9 and blocker_pass_rows == 10)


def req(milestone, requirement_id, requirement, ok, evidence_path, reason, blocker_class=""):
    return {
        "milestone": milestone,
        "requirement_id": requirement_id,
        "requirement": requirement,
        "status": "ready" if ok else "blocked",
        "evidence_path": evidence_path,
        "reason": reason,
        "blocker_class": "" if ok else blocker_class,
    }


pm_roadmap_rows = [
    req(
        "M1",
        "pr-split-ledger",
        "draft PR #2 is represented as ten review slices",
        plan_ready and len(slice_rows) == 10,
        "pm_pr_slice_rows.csv",
        f"slice_rows={len(slice_rows)} merge_gate_rows={len(gate_rows)}",
    ),
    req(
        "M1",
        "merge-condition-boundary",
        "merge gates use claim boundary, replay artifacts, and false-positive blocker closure instead of tests-only readiness",
        merge_condition_defined_rows == 10 and len(gate_rows) == 30 and summary_sources and blocker_pass_rows == 10,
        "pm_pr_merge_gate_rows.csv",
        f"merge_condition_defined_rows={merge_condition_defined_rows} tests_only_merge_condition_rows=0",
    ),
    req(
        "M1",
        "v56-replay-artifact",
        "v56 RULER/LongBench PR slice has replayable expanded benchmark artifact rows",
        as_int(v56b, "v56b_ruler_longbench_expanded_scale_ready") == 1,
        "source_summaries/v56b_ruler_longbench_expanded_scale_summary.csv",
        f"v56b_ready={v56b.get('v56b_ruler_longbench_expanded_scale_ready', '0')} real_external_benchmark_verified={v56b.get('real_external_benchmark_verified', '0')}",
        "v56-replay-artifact-missing",
    ),
    req(
        "M2",
        "pinned-public-repo-manifest",
        "v53 has a pinned 10+ public-repo source manifest",
        as_int(v53t, "complete_source_repo_count") >= 10
        and as_int(v53t, "machine_complete_source_surface_ready") == 1
        and as_int(v53t, "foundation_machine_freeze_ready") == 1
        and as_int(v53t, "foundation_direct_pinned_manifest_ready") == 1
        and bool(v53t_direct_copied.get("source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv"))
        and bool(v53t_direct_copied.get("source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv"))
        and bool(v53t_direct_copied.get("source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")),
        v53t_direct_copied.get("source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv") or "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
        (
            f"complete_source_repo_count={v53t.get('complete_source_repo_count', '0')} "
            f"foundation_machine_freeze_ready={v53t.get('foundation_machine_freeze_ready', '0')} "
            f"foundation_direct_pinned_manifest_ready={v53t.get('foundation_direct_pinned_manifest_ready', '0')} "
            f"repo_manifest_rows={v53t.get('foundation_direct_repo_manifest_rows', '0')} "
            f"file_manifest_rows={v53t.get('foundation_direct_file_manifest_rows', '0')} "
            f"content_snapshot_rows={v53t.get('foundation_direct_content_snapshot_rows', '0')}"
        ),
        "v53-source-manifest-missing",
    ),
    req(
        "M2",
        "source-span-query-freeze",
        "v53 has 1000 source-span-bound query rows",
        as_int(v53t, "complete_source_query_rows") == 1000
        and as_int(v53t, "complete_source_span_rows") == 1000
        and as_int(v53t, "foundation_direct_query_rows") == 1000
        and as_int(v53t, "foundation_direct_span_rows") == 1000
        and as_int(v53t, "foundation_query_span_binding_audit_ready") == 1
        and as_int(v53t, "foundation_query_span_binding_pass_rows") == 1000
        and len(v53t_query_span_binding_rows) == 1000
        and all(row.get("binding_status") == "pass" for row in v53t_query_span_binding_rows)
        and bool(v53t_direct_copied.get("complete_source_query_span_binding_audit_rows.csv"))
        and bool(v53t_direct_copied.get("source_v53i/complete_source_query_rows.csv"))
        and bool(v53t_direct_copied.get("source_v53i/complete_source_span_rows.csv")),
        v53t_direct_copied.get("complete_source_query_span_binding_audit_rows.csv") or "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
        (
            f"query_rows={v53t.get('complete_source_query_rows', '0')} "
            f"span_rows={v53t.get('complete_source_span_rows', '0')} "
            f"direct_query_rows={v53t.get('foundation_direct_query_rows', '0')} "
            f"direct_span_rows={v53t.get('foundation_direct_span_rows', '0')} "
            f"binding_audit_ready={v53t.get('foundation_query_span_binding_audit_ready', '0')} "
            f"binding_audit_rows={v53t.get('foundation_query_span_binding_audit_rows', '0')} "
            f"binding_audit_pass_rows={v53t.get('foundation_query_span_binding_pass_rows', '0')}"
        ),
        "v53-query-freeze-missing",
    ),
    req(
        "M2",
        "negative-and-conflict-controls",
        "unsupported, missing-specific, and doc-code conflict controls are present",
        as_int(v53t, "negative_abstain_rows") >= 100
        and as_int(v53t, "unsupported_control_rows") == 100
        and as_int(v53t, "ambiguous_control_rows") == 30
        and as_int(v53t, "missing_specific_control_rows") == 30
        and as_int(v53t, "doc_code_conflict_rows") == 140,
        "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
        (
            f"negative_abstain={v53t.get('negative_abstain_rows', '0')} "
            f"unsupported={v53t.get('unsupported_control_rows', '0')} "
            f"ambiguous={v53t.get('ambiguous_control_rows', '0')} "
            f"missing_specific={v53t.get('missing_specific_control_rows', '0')} "
            f"doc_code_conflict={v53t.get('doc_code_conflict_rows', '0')}"
        ),
        "v53-control-row-missing",
    ),
    req(
        "M2",
        "answer-citation-separated",
        "evaluator separates answer and citation/source checks",
        v53t_answer_citation_foundation.get("status") == "pass"
        and v53t_answer_citation_foundation.get("actual_value") == "direct_separate_evaluator_rows=4000"
        and v53t_answer_citation_foundation.get("evidence_path") == "source_v53ap/abgh_evaluator_rows.csv"
        and as_int(v53t, "foundation_direct_evaluator_separate_rows") == 4000
        and bool(v53t_direct_copied.get("source_v53ap/abgh_evaluator_rows.csv")),
        v53t_direct_copied.get("source_v53ap/abgh_evaluator_rows.csv") or v53t_foundation_freeze_copied or "source_v53t/complete_source_foundation_freeze_rows.csv",
        (
            f"criterion_status={v53t_answer_citation_foundation.get('status', 'missing')} "
            f"actual_value={v53t_answer_citation_foundation.get('actual_value', '')} "
            f"direct_evaluator_rows={v53t.get('foundation_direct_abgh_evaluator_rows', '0')}"
        ),
        "answer-citation-eval-not-separated",
    ),
    req(
        "M3",
        "abgh-same-query-measured",
        "A/B/G/H deterministic source-span adapters are measured on the same complete-source query/source/evaluator/resource surface",
        as_int(v53ap, "v53ap_complete_source_abgh_same_query_measured_ready") == 1
        and v53ap.get("systems") == "A/B/G/H"
        and as_int(v53ap, "same_query_set_all_local_systems") == 1
        and as_int(v53ap, "same_source_manifest_all_local_systems") == 1
        and as_int(v53ap, "same_evaluator_contract_all_local_systems") == 1
        and as_int(v53ap, "same_resource_contract_all_local_systems") == 1
        and as_int(v53ap, "evaluator_rows") == 4000
        and as_int(v53ap, "resource_rows") == 4000,
        "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
        (
            f"systems={v53ap.get('systems', '')} same_query={v53ap.get('same_query_set_all_local_systems', '0')} "
            f"same_source={v53ap.get('same_source_manifest_all_local_systems', '0')} "
            f"same_evaluator={v53ap.get('same_evaluator_contract_all_local_systems', '0')} "
            f"same_resource={v53ap.get('same_resource_contract_all_local_systems', '0')} "
            f"deterministic_source_span_adapter_execution={v53ap.get('deterministic_source_span_adapter_execution', '0')} "
            f"real_system_performance_claim_ready={v53ap.get('real_system_performance_claim_ready', '0')}"
        ),
        "abgh-same-query-missing",
    ),
    req(
        "M3",
        "abgh-real-system-adapter-execution",
        "A/B/G/H actual BM25/local-RAG/RouteMemory adapters run on v53i with sanitized-question-only selection and no expected-answer/source-span oracle replay",
        as_int(v53aq, "v53aq_complete_source_abgh_real_adapter_measured_ready") == 1
        and as_int(v53aq, "real_system_performance_claim_ready") == 0
        and as_int(v53aq, "internal_real_adapter_metric_claim_ready") == 1
        and as_int(v53aq, "public_real_system_performance_claim_ready") == 0
        and as_int(v53aq, "real_adapter_execution_ready") == 1
        and as_int(v53aq, "actual_adapter_execution_ready") == 1
        and as_int(v53aq, "selection_question_text_only") == 1
        and as_int(v53aq, "selection_sanitized_question_only") == 1
        and as_int(v53aq, "source_locator_in_question_removed_rows") == 4000
        and as_int(v53aq, "selection_oracle_field_used") == 0
        and as_int(v53aq, "expected_answer_oracle_replay") == 0
        and as_int(v53aq, "deterministic_source_span_adapter_execution") == 0
        and as_int(v53aq, "evaluator_rows") == 4000
        and as_int(v53aq, "same_query_internal_prebaseline_rows_ready") == 1
        and as_int(v53aq, "same_query_internal_prebaseline_rows") == 1000
        and as_int(v53aq, "internal_prebaseline_contract_ready") == 1
        and as_int(v53aq, "internal_prebaseline_contract_rows") == 4
        and as_int(v53aq, "internal_prebaseline_contract_ready_rows") == 4
        and bool(v53aq_direct_copied.get("abgh_same_query_internal_prebaseline_rows.csv"))
        and bool(v53aq_direct_copied.get("abgh_internal_prebaseline_contract_rows.csv"))
        and v59e_local_abgh_row_contract_ready == 1,
        v59e_local_abgh_row_contract_copied or v53aq_direct_copied.get("abgh_same_query_internal_prebaseline_rows.csv") or "source_summaries/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
        (
            f"real_adapter_execution_ready={v53aq.get('real_adapter_execution_ready', '0')} "
            f"actual_adapter_execution_ready={v53aq.get('actual_adapter_execution_ready', '0')} "
            f"selection_question_text_only={v53aq.get('selection_question_text_only', '0')} "
            f"selection_sanitized_question_only={v53aq.get('selection_sanitized_question_only', '0')} "
            f"source_locator_in_question_removed_rows={v53aq.get('source_locator_in_question_removed_rows', '0')} "
            f"selection_oracle_field_used={v53aq.get('selection_oracle_field_used', '1')} "
            f"expected_answer_oracle_replay={v53aq.get('expected_answer_oracle_replay', '0')} "
            f"deterministic_source_span_adapter_execution={v53aq.get('deterministic_source_span_adapter_execution', '1')} "
            f"real_system_performance_claim_ready={v53aq.get('real_system_performance_claim_ready', '0')} "
            f"internal_real_adapter_metric_claim_ready={v53aq.get('internal_real_adapter_metric_claim_ready', '0')} "
            f"public_real_system_performance_claim_ready={v53aq.get('public_real_system_performance_claim_ready', '1')} "
            f"same_query_internal_prebaseline_rows_ready={v53aq.get('same_query_internal_prebaseline_rows_ready', '0')} "
            f"same_query_internal_prebaseline_rows={v53aq.get('same_query_internal_prebaseline_rows', '0')} "
            f"internal_prebaseline_contract_rows={v53aq.get('internal_prebaseline_contract_rows', '0')} "
            f"internal_prebaseline_contract_ready_rows={v53aq.get('internal_prebaseline_contract_ready_rows', '0')} "
            f"internal_prebaseline_contract_ready={v53aq.get('internal_prebaseline_contract_ready', '0')} "
            f"local_abgh_row_contract_replay_ready={v59e.get('local_abgh_row_contract_replay_ready', '0')} "
            f"local_abgh_row_contract_replay_rows={v59e.get('local_abgh_row_contract_replay_rows', '0')} "
            f"local_abgh_row_contract_replay_pass_rows={v59e.get('local_abgh_row_contract_replay_pass_rows', '0')} "
            f"answer_hash_match_rows={v53aq.get('answer_hash_match_rows', '0')} "
            f"coherent_wrong_key_rows={v53aq.get('coherent_wrong_key_rows', '0')}"
        ),
        "abgh-real-adapter-execution-missing",
    ),
    req(
        "M3",
        "internal-pre-baseline-boundary",
        "A/B/G/H run is internal-only and makes no public comparison claim without D/E",
        as_int(v53ap, "internal_v1_0_pre_baseline_run") == 1
        and as_int(v53ap, "public_comparison_claim_ready") == 0
        and as_int(v53ap, "required_30b_baseline_ready") == 0
        and as_int(v53ap, "required_70b_baseline_ready") == 0
        and as_int(v53aq, "internal_prebaseline_contract_ready") == 1
        and as_int(v53aq, "public_comparison_claim_ready") == 0
        and as_int(v53aq, "required_30b_baseline_ready") == 0
        and as_int(v53aq, "required_70b_baseline_ready") == 0,
        "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
        f"D/E required baselines remain blocked and public comparison claim remains closed; v53aq_internal_prebaseline_contract_ready={v53aq.get('internal_prebaseline_contract_ready', '0')} v53aq_internal_prebaseline_contract_rows={v53aq.get('internal_prebaseline_contract_rows', '0')}",
        "public-comparison-claim-open",
    ),
    req(
        "M3",
        "de-30b70b-symmetric-baselines",
        "30B/70B D/E symmetric baselines are present for public v1.0 comparison",
        as_int(v53ap, "required_30b_baseline_ready") == 1 and as_int(v53ap, "required_70b_baseline_ready") == 1,
        "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
        f"required_30b_baseline_ready={v53ap.get('required_30b_baseline_ready', '0')} required_70b_baseline_ready={v53ap.get('required_70b_baseline_ready', '0')}",
        "de-30b70b-baselines-missing",
    ),
    req(
        "M4",
        "h10-readiness-ledger",
        "h10 scorer promotion criteria are represented as real-label readiness rows",
        as_int(h10_pm, "v10_h10_real_label_promotion_readiness_gate_ready") == 1
        and as_int(h10_pm, "v53aq_same_query_internal_prebaseline_rows_ready") == 1
        and as_int(h10_pm, "v53aq_internal_prebaseline_contract_ready") == 1
        and len(h10_v53aq_contract_rows) == 4
        and len(h10_acceptance_rows) == 6
        and len(h10_return_contract_rows) == 6
        and set(h10_acceptance_by_criterion) == {
            "coherent-wrong-key-reduction",
            "chunk-exact-increase",
            "near-miss-slash",
            "missing-query-abstain",
            "source-provenance-binding",
            "external-human-label-evidence",
        }
        and set(h10_return_contract_by_criterion) == set(h10_acceptance_by_criterion)
        and all(row.get("fixture_allowed") == "0" for row in h10_return_contract_rows)
        and all(row.get("approval_required") == "1" for row in h10_return_contract_rows)
        and all(row.get("contract_ready") == "1" for row in h10_return_contract_rows)
        and all(row.get("acceptance_status") == "blocked" for row in h10_return_contract_rows)
        and len(h10_acceptance_evidence_rows) == 6
        and {row.get("criterion", "") for row in h10_acceptance_evidence_rows} == set(h10_acceptance_by_criterion)
        and all(row.get("acceptance_ready") == "1" for row in h10_acceptance_evidence_rows)
        and all(row.get("promotion_ready") == "0" for row in h10_acceptance_evidence_rows)
        and h10_acceptance_evidence_coverage_field_rows == len(h10_acceptance_evidence_rows)
        and all(row.get("tests_only_merge_condition") == "0" for row in h10_acceptance_evidence_rows),
        h10_acceptance_rows_copied or "source_summaries/v10_h10_real_label_promotion_readiness_gate_summary.csv",
        (
            f"h10_readiness_gate={h10_pm.get('v10_h10_real_label_promotion_readiness_gate_ready', '0')} "
            f"criteria_rows={len(h10_acceptance_rows)} "
            f"return_contract_rows={len(h10_return_contract_rows)} "
            f"return_contract_ready_rows={h10_pm.get('h10_real_label_return_contract_ready_rows', '0')} "
            f"return_contract_pass_rows={h10_pm.get('h10_real_label_return_contract_pass_rows', '0')} "
            f"acceptance_evidence_rows={len(h10_acceptance_evidence_rows)} "
            f"acceptance_evidence_ready_rows={h10_pm.get('h10_real_label_acceptance_evidence_ready_rows', '0')} "
            f"acceptance_evidence_promotion_ready_rows={h10_pm.get('h10_real_label_acceptance_evidence_promotion_ready_rows', '0')} "
            f"acceptance_evidence_tests_only_rows={h10_pm.get('h10_real_label_acceptance_evidence_tests_only_rows', '0')} "
            f"accepted_query_rows_declared={h10_pm.get('accepted_query_rows_declared', '0')} "
            f"accepted_label_rows={h10_pm.get('accepted_label_rows', '0')} "
            f"criterion_label_coverage_blocked_rows={h10_acceptance_evidence_label_coverage_blocked_rows} "
            f"source_verified_eval_blocked_rows={h10_acceptance_evidence_source_verified_blocked_rows} "
            f"criteria={','.join(sorted(h10_acceptance_by_criterion))} "
            f"v53aq_same_query_internal_prebaseline_rows={h10_pm.get('v53aq_same_query_internal_prebaseline_rows', '0')} "
            f"v53aq_same_query_internal_prebaseline_rows_ready={h10_pm.get('v53aq_same_query_internal_prebaseline_rows_ready', '0')} "
            f"v53aq_internal_prebaseline_contract_rows={h10_pm.get('v53aq_internal_prebaseline_contract_rows', '0')} "
            f"v53aq_internal_prebaseline_contract_ready={h10_pm.get('v53aq_internal_prebaseline_contract_ready', '0')}"
        ),
        "h10-readiness-ledger-missing",
    ),
    req(
        "M4",
        "h10-real-label-promotion",
        "h10 real-label promotion has accepted external/human label evidence and source-verified eval readiness",
        as_int(h10_pm, "h10_real_label_promotion_ready") == 1,
        "source_summaries/v10_h10_real_label_promotion_readiness_gate_summary.csv",
        f"external_human_label_evidence_ready={h10_pm.get('external_human_label_evidence_ready', '0')} h10_source_verified_eval_ready={h10_pm.get('h10_source_verified_eval_ready', '0')}",
        "external-human-label-evidence-missing",
    ),
    req(
        "M5",
        "v54-grounded-generation-outputs",
        "v54 emits 1000 grounded answer/citation/unsupported/abstain/resource/guard rows",
        as_int(v54c, "v54c_complete_source_grounded_generation_1000_ready") == 1
        and as_int(v54c, "answer_rows") == 1000
        and as_int(v54c, "citation_rows") == 1000
        and as_int(v54c, "unsupported_claim_rows") == 160
        and as_int(v54c, "abstain_rows") == 160
        and as_int(v54c, "generator_resource_rows") == 1000
        and as_int(v54c, "wrong_answer_guard_rows") == 1000,
        "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
        (
            f"answer_rows={v54c.get('answer_rows', '0')} "
            f"citation_rows={v54c.get('citation_rows', '0')} "
            f"unsupported_claim_rows={v54c.get('unsupported_claim_rows', '0')} "
            f"abstain_rows={v54c.get('abstain_rows', '0')} "
            f"generator_resource_rows={v54c.get('generator_resource_rows', '0')} "
            f"wrong_answer_guard_rows={v54c.get('wrong_answer_guard_rows', '0')}"
        ),
        "v54-grounded-generation-missing",
    ),
    req(
        "M5",
        "no-raw-prompt-stuffing",
        "RouteHint generation keeps raw prompt stuffing at zero",
        as_int(v54c, "raw_prompt_context_appended_rows") == 0 and as_int(v54c, "wrong_answer_rows") == 0,
        "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
        f"raw_prompt_context_appended_rows={v54c.get('raw_prompt_context_appended_rows', '0')} wrong_answer_rows={v54c.get('wrong_answer_rows', '0')}",
        "raw-prompt-stuffing-open",
    ),
    req(
        "M6",
        "v58-blind-eval-blocker-ledger",
        "v58 blind-eval blocker ledger exists and keeps real blind eval blocked until responses/review arrive",
        as_int(v59e, "v58_pm_blind_eval_blocker_ready") == 1 and as_int(v59e, "v58_full_blind_eval_ready") == 0,
        "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
        f"v58_blocker={v59e.get('v58_pm_blind_eval_blocker_ready', '0')} v58_full={v59e.get('v58_full_blind_eval_ready', '0')}",
        "v58-real-blind-eval-missing",
    ),
    req(
        "M6",
        "v58c-blind-response-intake-artifact",
        "v58c blind-response intake artifact exists without implicit v58/v57/v56 seed rebuild",
        as_int(v59e, "v58c_blind_response_evidence_intake_ready") == 1
        and as_int(v59e, "v58c_expected_blind_response_rows") == 2500
        and as_int(v59e, "v58c_required_blind_response_ready") == 0
        and as_int(v59e, "v58c_human_blind_review_ready") == 0,
        "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
        f"v58c_intake_artifact_available={v59e.get('v58c_intake_artifact_available', '0')} v58c_dependency_blocker_ready={v59e.get('v58c_dependency_blocker_ready', '0')}",
        "v58c-intake-artifact-missing",
    ),
    req(
        "M6",
        "v58-full-blind-eval",
        "v58 real blind eval has real D/E/G/H responses, identity hiding, human review, and adjudication rows",
        as_int(v59e, "v58_full_blind_eval_ready") == 1,
        "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
        f"v58_full_blind_eval_ready={v59e.get('v58_full_blind_eval_ready', '0')}",
        "v58-real-blind-eval-missing",
    ),
    req(
        "M6",
        "v59-one-command-foundation",
        "v59 one-command PM foundation replay writes a challenge bundle without hidden local state",
        as_int(v59e, "v59e_one_command_pm_foundation_demo_ready") == 1
        and as_int(v59e, "challenge_bundle_ready") == 1
        and as_int(v59e, "undocumented_local_state_required") == 0
        and as_int(v59e, "network_required") == 0
        and as_int(v59e, "downloads_required") == 0
        and as_int(v59e, "public_source_download_executed") == 0
        and as_int(v59e, "full_public_source_download_ready") == 0,
        "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
        (
            f"v59e_ready={v59e.get('v59e_one_command_pm_foundation_demo_ready', '0')} "
            f"bundle={v59e.get('challenge_bundle_ready', '0')} "
            f"local_abgh_row_contract_replay_ready={v59e.get('local_abgh_row_contract_replay_ready', '0')} "
            f"public_source_download_executed={v59e.get('public_source_download_executed', '0')} "
            f"full_public_source_download_ready={v59e.get('full_public_source_download_ready', '0')} "
            f"policy_blocker={v59e_public_source_policy.get('blocker_status', 'missing')}"
        ),
        "v59-foundation-demo-missing",
    ),
    req(
        "M6",
        "v60-public-release-gate",
        "v60 public release readiness remains closed until v52-v59 plus 30B/70B, generation, blind eval, one-command, and review evidence are all complete",
        as_int(v60, "v60_ready") == 1 and as_int(v60, "real_release_package_ready") == 1,
        "source_summaries/v60_architecture_challenge_release_contract_summary.csv" if v60 else "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md",
        (
            f"v60_release_contract_ready={v60.get('v60_release_contract_ready', '0')} "
            f"v60_ready={v60.get('v60_ready', '0')} "
            f"real_release_package_ready={v60.get('real_release_package_ready', '0')} "
            f"release_requirement_ready_rows={v60.get('release_requirement_ready_rows', '0')} "
            f"release_requirement_blocked_rows={v60.get('release_requirement_blocked_rows', '0')}"
            if v60
            else "v60 release summary is absent in current results; release-ready claim must remain closed"
        ),
        "v60-release-evidence-missing",
    ),
]
write_csv(run_dir / "pm_roadmap_requirement_rows.csv", list(pm_roadmap_rows[0].keys()), pm_roadmap_rows)


def closure_row(
    blocker_class,
    milestone,
    requirement_id,
    required_external_artifacts,
    local_intake_or_verification_command,
    approval_required,
    execution_policy,
    ready_condition,
    claim_until_closed,
):
    return {
        "blocker_class": blocker_class,
        "milestone": milestone,
        "requirement_id": requirement_id,
        "required_external_artifacts": required_external_artifacts,
        "local_intake_or_verification_command": local_intake_or_verification_command,
        "approval_required": approval_required,
        "execution_policy": execution_policy,
        "ready_condition": ready_condition,
        "claim_until_closed": claim_until_closed,
    }


blocker_closure_rows = [
    closure_row(
        "v56-replay-artifact-missing",
        "M1/M6",
        "v56-replay-artifact",
        "hash-bound v56 contract/scale artifact rows with official source snapshots, evaluator hashes, raw prediction rows, lineage rows, candidate rows, resource rows, and sha256 manifest",
        "V56B_ALLOW_CONTRACT_REBUILD=1 experiments/test_v56b_ruler_longbench_expanded_scale.sh",
        "runtime-budget-approval-required",
        "defer-until-v56-seed-or-contract-artifacts-approved",
        "v56b_ruler_longbench_expanded_scale_ready=1 and real_external_benchmark_verified remains correctly bounded",
        "v56 replay artifact missing; no benchmark/leaderboard claim",
    ),
    closure_row(
        "de-30b70b-baselines-missing",
        "M3/M6",
        "de-30b70b-symmetric-baselines",
        "D and E supplied evidence directories with model identity, answer rows, citation rows, retrieval/resource rows, abstain rows, wrong-answer guard rows, frozen query/source rows, transcript/provenance, and sha256 manifests",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR> V52D_70B_LLM_RAG_EVIDENCE_DIR=<E_DIR> experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh",
        "model-runtime-or-external-evidence-approval-required",
        "defer-until-real-30b70b-evidence-supplied",
        "required_30b_baseline_ready=1 and required_70b_baseline_ready=1 on the same frozen query/source/evaluator surface",
        "A/B/G/H internal pre-baseline only; no public comparison claim",
    ),
    closure_row(
        "external-human-label-evidence-missing",
        "M4",
        "h10-real-label-promotion",
        "accepted external/human label CSV with non-fixture provenance, reviewer/source authority, source-verified eval linkage, coherent-wrong-key, chunk-exact, near-miss, missing-abstain, and provenance-binding evidence",
        "V10_H10_REAL_LABEL_EVIDENCE_CSV=<LABEL_CSV> experiments/test_v10_h10_real_label_promotion_readiness_gate.sh",
        "external-review-or-human-label-approval-required",
        "defer-until-real-label-evidence-supplied",
        "h10_real_label_promotion_ready=1 with external_human_label_evidence_ready=1 and h10_source_verified_eval_ready=1",
        "h10 readiness ledger only; no scorer promotion/scientific contribution claim",
    ),
    closure_row(
        "v58-real-blind-eval-missing",
        "M6",
        "v58-full-blind-eval",
        "blind response evidence directory with D/E/G/H responses, identity-hiding keys, symmetric citation verification, human blind review, inter-rater/adjudication rows, and failure rows",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> experiments/test_v58c_blind_response_evidence_intake.sh",
        "external-response-and-human-review-approval-required",
        "defer-until-real-blind-response-evidence-supplied",
        "v58_full_blind_eval_ready=1 with real responses and human blind review/adjudication accepted",
        "v58 blocker ledger only; no blind-eval completion claim",
    ),
    closure_row(
        "v58c-intake-artifact-missing",
        "M6",
        "v58c-blind-response-intake-artifact",
        "v58c blind-response intake summary and intake_001 artifact directory with response templates, run identity templates, validation rows, source_v58b freeze evidence, boundary, manifest, and sha256 manifest",
        "V58C_REUSE_EXISTING=0 experiments/test_v58c_blind_response_evidence_intake.sh",
        "v58-seed-rebuild-or-real-response-intake-approval-required",
        "defer-until-v58c-intake-artifact-or-real-response-evidence-approved",
        "v58c_blind_response_evidence_intake_ready=1 while required_blind_response_ready=0 and human_blind_review_ready=0 remain correctly bounded",
        "v58c intake artifact missing; no blind-response intake or blind-eval completion claim",
    ),
    closure_row(
        "v60-release-evidence-missing",
        "M6",
        "v60-public-release-gate",
        "release packet proving v52-v59 readiness, 30B/70B baselines, 1000+ generation rows, 10+ public repos, blind eval, one-command demo, human/release review, and no forbidden claims",
        "experiments/test_v60_architecture_challenge_release_contract.sh",
        "human-release-review-approval-required",
        "defer-until-all-upstream-blockers-closed",
        "v60_ready=1 and real_release_package_ready=1 only after every upstream blocker is closed",
        "pre-v1.0 research artifact; no release-ready/public-win/production claim",
    ),
]
blocker_order = {
    "v56-replay-artifact-missing": 0,
    "de-30b70b-baselines-missing": 1,
    "external-human-label-evidence-missing": 2,
    "v58c-intake-artifact-missing": 3,
    "v58-real-blind-eval-missing": 4,
    "v60-release-evidence-missing": 5,
}
blocker_closure_rows = sorted(
    blocker_closure_rows,
    key=lambda row: blocker_order[row["blocker_class"]],
)
write_csv(run_dir / "pm_blocker_closure_queue_rows.csv", list(blocker_closure_rows[0].keys()), blocker_closure_rows)


def required_artifact_row(
    blocker_class,
    artifact_id,
    artifact_path_or_env,
    artifact_kind,
    required_shape,
    validation_command,
    acceptance_signal,
    fixture_allowed="0",
    approval_required="1",
):
    return {
        "blocker_class": blocker_class,
        "artifact_id": artifact_id,
        "artifact_path_or_env": artifact_path_or_env,
        "artifact_kind": artifact_kind,
        "required_shape": required_shape,
        "validation_command": validation_command,
        "acceptance_signal": acceptance_signal,
        "fixture_allowed": fixture_allowed,
        "approval_required": approval_required,
    }


blocker_required_artifact_rows = [
    required_artifact_row(
        "v56-replay-artifact-missing",
        "v56-contract-summary",
        "results/v56_ruler_longbench_expanded_contract_summary.csv",
        "summary-csv",
        "v56_ruler_longbench_expanded_contract_ready=1 with release/external claims blocked",
        "experiments/test_v56_ruler_longbench_expanded_contract.sh",
        "v56 contract summary and sha256-bound contract_001 artifacts exist",
    ),
    required_artifact_row(
        "v56-replay-artifact-missing",
        "v56-contract-artifacts",
        "results/v56_ruler_longbench_expanded_contract/contract_001/",
        "artifact-directory",
        "benchmark family target rows, invariant rows, copied source/evaluator evidence, manifest, and sha256_manifest.csv",
        "experiments/test_v56_ruler_longbench_expanded_contract.sh",
        "contract artifact replay passes or fails closed without implicit heavy rebuild",
    ),
    required_artifact_row(
        "v56-replay-artifact-missing",
        "v56b-scale-summary",
        "results/v56b_ruler_longbench_expanded_scale_summary.csv",
        "summary-csv",
        "v56b_ruler_longbench_expanded_scale_ready=1 while real_external_benchmark_verified remains correctly bounded",
        "V56B_ALLOW_CONTRACT_REBUILD=1 experiments/test_v56b_ruler_longbench_expanded_scale.sh",
        "v56b summary marks expanded scale replay ready",
    ),
    required_artifact_row(
        "v56-replay-artifact-missing",
        "v56b-scale-artifacts",
        "results/v56b_ruler_longbench_expanded_scale/scale_001/",
        "artifact-directory",
        "expanded_prediction_rows.csv, prediction_lineage_rows.csv, candidate_result_rows.csv, benchmark_resource_rows.csv, benchmark_family_rows.csv, sha256_manifest.csv",
        "V56B_ALLOW_CONTRACT_REBUILD=1 experiments/test_v56b_ruler_longbench_expanded_scale.sh",
        "scale artifact replay passes and no benchmark/public comparison claim opens",
    ),
    required_artifact_row(
        "de-30b70b-baselines-missing",
        "d-model-identity",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR/model_identity.json",
        "json",
        "system_id=D, baseline_class=30b-open-weight-llm-rag, exact model repository/revision, parameter_count_b in [25,40], quantization, open_weight_license_uri, model_artifact_sha256, runtime/version, hardware, external_api_used=0, non_fixture_declared=1",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR> V52D_70B_LLM_RAG_EVIDENCE_DIR=<E_DIR> experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh",
        "D identity validates as open-weight 30B-class evidence",
    ),
    required_artifact_row(
        "de-30b70b-baselines-missing",
        "d-answer-citation-resource",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR/{llm_rag_answer_rows.csv,llm_rag_citation_rows.csv,llm_rag_resource_rows.csv}",
        "csv-set",
        "one D raw answer/citation row per frozen query with prompt/context/retrieval budget, seed, transcript sha256, source-span-bound citations, resource/evaluator rows, fixture_rows=0, measured_registry_candidate=1",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR> V52D_70B_LLM_RAG_EVIDENCE_DIR=<E_DIR> experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh",
        "D rows pass evidence intake on the frozen query/source surface",
    ),
    required_artifact_row(
        "de-30b70b-baselines-missing",
        "e-model-identity",
        "V52D_70B_LLM_RAG_EVIDENCE_DIR/model_identity.json",
        "json",
        "system_id=E, baseline_class=70b-open-weight-llm-rag, exact model repository/revision, parameter_count_b in [65,80], quantization, open_weight_license_uri, model_artifact_sha256, runtime/version, hardware, external_api_used=0, non_fixture_declared=1",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR> V52D_70B_LLM_RAG_EVIDENCE_DIR=<E_DIR> experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh",
        "E identity validates as open-weight 70B-class evidence",
    ),
    required_artifact_row(
        "de-30b70b-baselines-missing",
        "e-answer-citation-resource",
        "V52D_70B_LLM_RAG_EVIDENCE_DIR/{llm_rag_answer_rows.csv,llm_rag_citation_rows.csv,llm_rag_resource_rows.csv}",
        "csv-set",
        "one E raw answer/citation row per frozen query with prompt/context/retrieval budget, seed, transcript sha256, source-span-bound citations, resource/evaluator rows, fixture_rows=0, measured_registry_candidate=1",
        "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR> V52D_70B_LLM_RAG_EVIDENCE_DIR=<E_DIR> experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh",
        "E rows pass evidence intake on the frozen query/source surface",
    ),
    required_artifact_row(
        "external-human-label-evidence-missing",
        "h10-label-evidence-csv",
        "V10_H10_REAL_LABEL_EVIDENCE_CSV",
        "csv",
        "all H10_EVIDENCE_FIELDS present with >=1000 query/label rows, human_reviewed=1, external_source_verified=1, non_fixture_declared=1",
        "V10_H10_REAL_LABEL_EVIDENCE_CSV=<LABEL_CSV> experiments/test_v10_h10_real_label_promotion_readiness_gate.sh",
        "external_human_label_evidence_ready=1",
    ),
    required_artifact_row(
        "external-human-label-evidence-missing",
        "h10-label-artifact",
        "label_source_uri + label_artifact_sha256",
        "external-source-reference",
        "https URI and sha256-bound source label artifact for coherent wrong-key/chunk-exact/near-miss/missing/provenance labels",
        "V10_H10_REAL_LABEL_EVIDENCE_CSV=<LABEL_CSV> experiments/test_v10_h10_real_label_promotion_readiness_gate.sh",
        "label source passes https/artifact hash checks",
    ),
    required_artifact_row(
        "external-human-label-evidence-missing",
        "h10-acceptance-summary",
        "acceptance_summary_sha256",
        "hash-reference",
        "sha256-bound acceptance summary tying reviewer/conflict/source verification to h10 label rows",
        "V10_H10_REAL_LABEL_EVIDENCE_CSV=<LABEL_CSV> experiments/test_v10_h10_real_label_promotion_readiness_gate.sh",
        "h10_real_label_promotion_ready=1 only with source-verified eval readiness",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-blind-response-rows",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR/blind_response_rows.csv",
        "csv",
        "blind_response_id coverage for required systems, response/citation/abstain fields, output sha256, latency/resource fields",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> experiments/test_v58c_blind_response_evidence_intake.sh",
        "blind response rows validate against frozen blind query IDs",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-run-identity-rows",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR/run_identity_rows.csv",
        "csv",
        "source_system_id D/E/G/H identity rows, model/architecture IDs, size class, credential redaction, run metadata sha256",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> experiments/test_v58c_blind_response_evidence_intake.sh",
        "required run identities validate without unblinding reviewer packets",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-query-split-rows",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR/query_split_rows.csv",
        "csv",
        "per-query repository split rows with unseen_repository flag, frozen query packet sha256, and source manifest sha256",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> experiments/test_v58c_blind_response_evidence_intake.sh",
        "unseen_repository split binds to the frozen blind query packet and source manifest",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-resource-rows",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR/resource_rows.csv",
        "csv",
        "per-(blind_run_id, system_blind_id, query_id) latency, peak memory, and tokens/sec rows with resource sha256, kept separate from answer quality",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> experiments/test_v58c_blind_response_evidence_intake.sh",
        "resource metrics are recorded and sha256-bound without leaking into review rows",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-human-review-rows",
        "blind review/adjudication return bundle",
        "review-return",
        "per-(blind_run_id, system_blind_id, query_id, response_sha256) human blind review rows with reviewer_blinded, reviewer_independent, conflict_disclosure_sha256, and resource columns forbidden",
        "defer to v58 review acceptance gate once response rows validate",
        "v58_full_blind_eval_ready=1 only after human blind review/adjudication acceptance",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-adjudication-rows",
        "blind adjudication return bundle",
        "review-return",
        "per-(blind_run_id, system_blind_id, query_id, response_sha256) adjudication rows with reviewer_a_id, reviewer_b_id, disagreement_type, adjudicator_id, and adjudicated scoring columns, resource columns forbidden",
        "defer to v58 adjudication acceptance gate once review rows validate",
        "v58_full_blind_eval_ready=1 only after disagreement/adjudication acceptance",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58d-review-return-intake",
        "results/v58d_blind_review_return_intake/intake_001/",
        "artifact-directory",
        "blind review/adjudication required-field rows, review/adjudication return templates, validation rows, gate rows, score/failure-case output surfaces, dependency rows, boundary, manifest, and sha256_manifest.csv",
        "experiments/test_v58d_blind_review_return_intake.sh",
        "v58d intake artifact exists while review/adjudication evidence and full blind eval remain blocked unless real returns are supplied",
    ),
    required_artifact_row(
        "v58-real-blind-eval-missing",
        "v58-sha256-manifest",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR/sha256_manifest.csv",
        "csv",
        "hash manifest for supplied blind response and run identity artifacts",
        "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> experiments/test_v58c_blind_response_evidence_intake.sh",
        "blind response evidence is replay/hash-bound",
    ),
    required_artifact_row(
        "v58c-intake-artifact-missing",
        "v58c-intake-summary",
        "results/v58c_blind_response_evidence_intake_summary.csv",
        "summary-csv",
        "v58c_blind_response_evidence_intake_ready=1 with required_blind_response_ready=0 and human_blind_review_ready=0",
        "V58C_REUSE_EXISTING=0 experiments/test_v58c_blind_response_evidence_intake.sh",
        "v58c summary exists and keeps full blind eval blocked",
    ),
    required_artifact_row(
        "v58c-intake-artifact-missing",
        "v58c-intake-artifacts",
        "results/v58c_blind_response_evidence_intake/intake_001/",
        "artifact-directory",
        "blind_response_required_field_rows.csv, blind_response_row_template.csv, run_identity_template_rows.csv, validation/gate rows, boundary, manifest, sha256_manifest.csv",
        "V58C_REUSE_EXISTING=0 experiments/test_v58c_blind_response_evidence_intake.sh",
        "v58c intake artifact directory is replay/hash-bound",
    ),
    required_artifact_row(
        "v58c-intake-artifact-missing",
        "v58c-source-v58b-freeze",
        "results/v58c_blind_response_evidence_intake/intake_001/source_v58b/",
        "artifact-directory",
        "copied v58b blind query freeze, sealed answer/identity keys, blind response templates, evidence budgets, and sha256_manifest.csv",
        "V58C_REUSE_EXISTING=0 experiments/test_v58c_blind_response_evidence_intake.sh",
        "v58c intake binds to the frozen v58b blind-query surface",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v60-upstream-readiness",
        "v52-v59 readiness summaries",
        "summary-set",
        "v52-v59 all ready, including D/E baselines, v53 complete-source, v54 generation, v58 blind eval, and v59 one-command",
        "experiments/test_v60_architecture_challenge_release_contract.sh",
        "v60_ready can only pass after all upstream blockers close",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v60-release-claim-audit",
        "allowed/forbidden claim rows",
        "claim-ledger",
        "allowed claims bounded to source-cited abstaining replayable local QA/audit architecture; forbidden claims remain closed",
        "experiments/test_v60_architecture_challenge_release_contract.sh",
        "release claim audit forbids replacement/frontier/public-win/production claims unless proven",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v60-human-release-review",
        "human/release review return artifact",
        "review-return",
        "human release review and reviewer acceptance evidence for public v1.0 package",
        "defer until upstream evidence and human release review are supplied",
        "real_release_package_ready=1 only after human release acceptance",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v59e-replay-preflight",
        "results/v59e_one_command_pm_foundation_demo/pm_foundation_001/pm_foundation_replay_preflight_rows.csv",
        "csv",
        "entrypoint, generated replay script, pinned-source snapshot replay, no default live download, no private fixture, no manual post-processing, no undocumented local state, PM sidecar packaging, blocker false-positive closure, and no remote mutation checks",
        "experiments/test_v59e_one_command_pm_foundation_demo.sh",
        "one_command_replay_preflight_ready=1 while full v59 public demo and public-source refresh readiness remain blocked",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v59e-local-abgh-row-contract-replay",
        "results/v59e_one_command_pm_foundation_demo/pm_foundation_001/local_abgh_row_contract_replay_rows.csv",
        "csv",
        "two passing v53ap/v53aq local A/B/G/H row-contract replay rows with 4000 answer/citation/evaluator/resource rows each, internal metrics ready, and public performance/comparison closed",
        "experiments/test_v59e_one_command_pm_foundation_demo.sh",
        "local_abgh_row_contract_replay_ready=1, v53aq_internal_real_adapter_metric_claim_ready=1, v53aq_public_real_system_performance_claim_ready=0, and public_comparison_claim_ready=0 for the internal pre-baseline path",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v59-public-source-download-refresh",
        "public source download/refresh evidence bundle",
        "artifact-directory",
        "approved live/downloaded public-source refresh evidence with pinned repo URLs, commit SHAs, tree/content hashes, download command transcript, no private fixture, and sha256 manifest",
        "defer until public-source download/network approval is granted for the full v59 public demo",
        "full_public_source_download_ready=1 only after approved download/refresh evidence is replay/hash-bound",
    ),
    required_artifact_row(
        "v60-release-evidence-missing",
        "v60-release-sha256-manifest",
        "release sha256 manifest",
        "hash-manifest",
        "hashes for release packet, summaries, challenge bundle, and claim ledgers",
        "experiments/test_v60_architecture_challenge_release_contract.sh",
        "release package is replay/hash-bound",
    ),
]
write_csv(run_dir / "pm_blocker_required_artifact_rows.csv", list(blocker_required_artifact_rows[0].keys()), blocker_required_artifact_rows)


def return_template_for_artifact(row):
    artifact_id = row["artifact_id"]
    blocker_class = row["blocker_class"]
    base_rel = f"return_templates/{safe_id(blocker_class)}/{safe_id(artifact_id)}"

    if artifact_id in {"d-model-identity", "e-model-identity"}:
        system_id = "D" if artifact_id.startswith("d-") else "E"
        parameter_range = "[25,40]" if system_id == "D" else "[65,80]"
        return (
            f"{base_rel}.json",
            "json",
            json.dumps(
                {
                    "template_only": True,
                    "fixture_allowed": False,
                    "system_id": system_id,
                    "baseline_class": "30b-open-weight-llm-rag" if system_id == "D" else "70b-open-weight-llm-rag",
                    "model_repository": "<required repository>",
                    "model_revision": "<required exact revision>",
                    "parameter_count_b_range": parameter_range,
                    "quantization": "<required quantization>",
                    "open_weight_license_uri": "https://...",
                    "model_artifact_sha256": "sha256:<required>",
                    "runtime": "<required runtime>",
                    "runtime_version": "<required runtime version>",
                    "hardware": "<required hardware>",
                    "external_api_used": 0,
                    "non_fixture_declared": 1,
                    "query_set_sha256": "<current frozen query set sha256>",
                    "approval_reference": "<required human/runtime approval>",
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
        )
    if artifact_id == "h10-label-artifact":
        return (
            f"{base_rel}.json",
            "json",
            json.dumps(
                {
                    "template_only": True,
                    "fixture_allowed": False,
                    "label_source_uri": "https://...",
                    "label_artifact_sha256": "sha256:<required>",
                    "source_authority": "<external/human authority>",
                    "non_fixture_declared": 1,
                    "approval_reference": "<required external/human-label approval>",
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
        )
    if artifact_id == "h10-acceptance-summary":
        return (
            f"{base_rel}.json",
            "json",
            json.dumps(
                {
                    "template_only": True,
                    "fixture_allowed": False,
                    "accepted_label_rows": "<required>",
                    "external_human_label_evidence_ready": 1,
                    "h10_source_verified_eval_ready": 1,
                    "reviewer_conflict_disclosure_sha256": "sha256:<required>",
                    "acceptance_summary_sha256": "sha256:<required>",
                    "approval_reference": "<required external/human-label approval>",
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
        )

    headers = {
        "v56-contract-summary": "summary_path,v56_ruler_longbench_expanded_contract_ready,real_external_benchmark_verified,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v56-contract-artifacts": "artifact_path,artifact_kind,source_authority_uri,evaluator_sha256,artifact_sha256,bytes,non_fixture_declared,approval_reference",
        "v56b-scale-summary": "summary_path,v56b_ruler_longbench_expanded_scale_ready,real_external_benchmark_verified,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v56b-scale-artifacts": "expanded_prediction_rows_path,prediction_lineage_rows_path,candidate_result_rows_path,benchmark_resource_rows_path,benchmark_family_rows_path,sha256_manifest_path,non_fixture_declared,approval_reference",
        "d-answer-citation-resource": "system_id,query_id,same_query_set_id,prompt_template_sha256,context_budget,retrieval_budget,seed,answer_row_path,citation_row_path,resource_row_path,raw_output_sha256,generation_transcript_sha256,evaluator_version,evaluator_artifact_sha256,answer_rows_sha256,citation_rows_sha256,fixture_rows,measured_registry_candidate,non_fixture_declared,approval_reference",
        "e-answer-citation-resource": "system_id,query_id,same_query_set_id,prompt_template_sha256,context_budget,retrieval_budget,seed,answer_row_path,citation_row_path,resource_row_path,raw_output_sha256,generation_transcript_sha256,evaluator_version,evaluator_artifact_sha256,answer_rows_sha256,citation_rows_sha256,fixture_rows,measured_registry_candidate,non_fixture_declared,approval_reference",
        "h10-label-evidence-csv": "query_id,label_id,coherent_wrong_key_reduced,chunk_exact_label,near_miss_slash_label,missing_query_abstain_label,source_provenance_bound,human_reviewed,external_source_verified,non_fixture_declared,label_source_uri,label_artifact_sha256,reviewer_id_hash,conflict_disclosure_sha256,acceptance_summary_sha256",
        "v58-blind-response-rows": "blind_response_id,blind_query_id,source_system_id,response_text_sha256,citation_rows_path,abstain_flag,latency_ms,resource_units,output_sha256,non_fixture_declared,approval_reference",
        "v58-run-identity-rows": "source_system_id,blind_system_id,model_architecture,size_class,run_metadata_sha256,credential_redacted,identity_key_sha256,non_fixture_declared,approval_reference",
        "v58-query-split-rows": "query_id,repo_id,split_name,unseen_repository,frozen_query_packet_sha256,source_manifest_sha256,non_fixture_declared,approval_reference",
        "v58-resource-rows": "blind_run_id,system_blind_id,query_id,latency_ms,peak_memory_mb,tokens_per_second,resource_sha256,non_fixture_declared,approval_reference",
        "v58-human-review-rows": "blind_run_id,system_blind_id,query_id,response_sha256,reviewer_id,reviewer_blinded,reviewer_independent,conflict_disclosure_sha256,answer_quality_score,citation_score,source_span_exact,unsupported_abstain_score,non_fixture_declared,approval_reference",
        "v58-adjudication-rows": "blind_run_id,system_blind_id,query_id,response_sha256,reviewer_a_id,reviewer_b_id,disagreement_type,adjudicator_id,adjudicated_answer_quality_score,adjudicated_citation_score,adjudicated_source_span_exact,adjudicated_unsupported_abstain_score,non_fixture_declared,approval_reference",
        "v58d-review-return-intake": "artifact_path,required_field_rows_path,review_template_path,adjudication_template_path,validation_rows_path,gate_rows_path,score_rows_path,failure_case_rows_path,boundary_path,manifest_path,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v58-sha256-manifest": "path,sha256,bytes,artifact_role,authority_uri,non_fixture_declared",
        "v58c-intake-summary": "summary_path,v58c_blind_response_evidence_intake_ready,required_blind_response_ready,human_blind_review_ready,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v58c-intake-artifacts": "artifact_path,artifact_kind,required_response_template_rows,validation_rows,boundary_path,manifest_path,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v58c-source-v58b-freeze": "source_v58b_path,blind_query_freeze_rows_path,sealed_identity_key_rows_path,blind_response_template_rows_path,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v60-upstream-readiness": "upstream_id,ready_flag,summary_path,summary_sha256,blocker_class,non_fixture_declared,approval_reference",
        "v60-release-claim-audit": "claim_id,allowed_claim,blocked_claim,evidence_path,evidence_sha256,reviewer_decision,non_fixture_declared,approval_reference",
        "v60-human-release-review": "release_review_id,reviewer_id_hash,release_packet_sha256,accepted_for_public_v1,required_corrections,conflict_disclosure_sha256,non_fixture_declared,approval_reference",
        "v59e-replay-preflight": "check,status,evidence,claim_boundary,preflight_rows_sha256,one_command_replay_preflight_ready,full_public_source_download_ready,non_fixture_declared,approval_reference",
        "v59e-local-abgh-row-contract-replay": "contract_id,source_stage,evidence_path,systems,answer_rows,citation_rows,evaluator_rows,resource_rows,same_query_row_contract,same_evaluator_contract_all_local_systems,same_resource_contract_all_local_systems,expected_answer_oracle_replay_any,public_comparison_claim_ready,status,sha256_manifest_path,non_fixture_declared,approval_reference",
        "v59-public-source-download-refresh": "source_repo_id,repo_url,pinned_commit_sha,tree_sha256,content_manifest_path,download_command_sha256,download_transcript_sha256,sha256_manifest_path,network_download_approval_reference,non_fixture_declared",
        "v60-release-sha256-manifest": "path,sha256,bytes,artifact_role,authority_uri,non_fixture_declared",
    }
    return f"{base_rel}.csv", "csv", headers[artifact_id] + "\n"


external_return_template_rows = []
for row in blocker_required_artifact_rows:
    template_rel, template_kind, template_text = return_template_for_artifact(row)
    template_path = run_dir / template_rel
    template_path.parent.mkdir(parents=True, exist_ok=True)
    template_path.write_text(template_text, encoding="utf-8")
    external_return_template_rows.append(
        {
            "blocker_class": row["blocker_class"],
            "artifact_id": row["artifact_id"],
            "template_path": template_rel,
            "template_kind": template_kind,
            "required_shape": row["required_shape"],
            "validation_command": row["validation_command"],
            "fixture_allowed": "0",
            "approval_required": "1",
            "template_ready": "1",
            "template_sha256": sha256(template_path),
        }
    )
write_csv(run_dir / "pm_external_return_template_rows.csv", list(external_return_template_rows[0].keys()), external_return_template_rows)

claim_by_slice = {row["slice_id"]: row for row in claim_boundary_rows}
files_by_slice = {slice_id: [] for slice_id in slice_ids}
for row in slice_file_rows:
    files_by_slice[row["slice_id"]].append(row)
verification_by_slice = {slice_id: [] for slice_id in slice_ids}
for row in slice_verification_rows:
    verification_by_slice[row["slice_id"]].append(row)

review_packet_rows = []
review_packet_dir = run_dir / "review_packets"
review_packet_dir.mkdir(parents=True, exist_ok=True)
for row in slice_rows:
    slice_id = row["slice_id"]
    claim_row = claim_by_slice[slice_id]
    file_rows_for_slice = files_by_slice[slice_id]
    verification_rows_for_slice = verification_by_slice[slice_id]
    local_commands = [
        command_row["command"]
        for command_row in verification_rows_for_slice
        if command_row["execution_policy"] == "local-smoke"
    ]
    deferred_commands = [
        command_row["command"]
        for command_row in verification_rows_for_slice
        if command_row["execution_policy"] != "local-smoke"
    ]
    packet_rel = f"review_packets/{safe_id(slice_id)}.md"
    packet_path = run_dir / packet_rel
    file_list = "\n".join(
        f"- `{file_row['file_path']}` ({file_row['role']}; {file_row['inclusion']})"
        for file_row in file_rows_for_slice
    )
    command_list = "\n".join(
        f"- `{command_row['command']}` ({command_row['execution_policy']}; {command_row['purpose']})"
        for command_row in verification_rows_for_slice
    )
    deferred_text = "none" if not deferred_commands else " | ".join(deferred_commands)
    next_action = "review-local-slice" if row["current_merge_ready"] == "1" else "hold-until-replay-artifact-or-real-evidence"
    packet_text = f"""# {slice_id}

Scope: {row['scope']}
Current status: {row['current_status']}
Next action: {next_action}

## Merge Condition

{row['merge_condition']}

This is not a tests-only merge condition. The slice must keep claim boundary,
replay artifact evidence, and false-positive blocker closure intact.

## Allowed Claim

{claim_row['allowed_claim']}

## Blocked Claim

{claim_row['blocked_claim']}

## Required Artifacts

{row['required_artifacts']}

## Files

{file_list}

## Verification

{command_list}

Deferred commands: {deferred_text}

## Reviewer Focus

- Claim boundary status: {row['claim_boundary_ok']}
- Replay artifact status: {row['replay_artifact_ok']}
- False-positive blocker closed: {row['blocker_false_positive_closed']}
- Evidence path: {claim_row['evidence_path']}
"""
    packet_path.write_text(packet_text, encoding="utf-8")
    review_packet_rows.append(
        {
            "ordinal": row["ordinal"],
            "slice_id": slice_id,
            "packet_path": packet_rel,
            "pr_title": f"{slice_id}: {row['scope']}",
            "current_status": row["current_status"],
            "next_action": next_action,
            "merge_condition": row["merge_condition"],
            "allowed_claim": claim_row["allowed_claim"],
            "blocked_claim": claim_row["blocked_claim"],
            "required_artifacts": row["required_artifacts"],
            "file_rows": str(len(file_rows_for_slice)),
            "verification_rows": str(len(verification_rows_for_slice)),
            "local_smoke_commands": " | ".join(local_commands),
            "deferred_commands": deferred_text,
            "packet_ready": "1",
            "slice_current_merge_ready": row["current_merge_ready"],
            "packet_sha256": sha256(packet_path),
        }
    )
write_csv(run_dir / "pm_pr_review_packet_rows.csv", list(review_packet_rows[0].keys()), review_packet_rows)

review_packet_by_slice = {row["slice_id"]: row for row in review_packet_rows}
acceptance_replay_path_by_slice = {
    "docs/v1-roadmap": "source_docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
    "v52-baseline-registry-contract": "source_summaries/v52_llm_rag_baseline_war_summary.csv",
    "v53-public-repo-source-manifest": "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
    "v53-query-instantiation-1000": "source_v53t/complete_source_query_span_binding_audit_rows.csv",
    "v53-system-a-b-g-h-measured": "source_v59e/local_abgh_row_contract_replay_rows.csv",
    "v54-routehint-generation-contract": "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
    "v56-ruler-longbench-expanded": "source_summaries/v56b_ruler_longbench_expanded_scale_summary.csv",
    "v58-blind-eval-contract": "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
    "v59-one-command-demo": "source_v59e/public_source_replay_policy_rows.csv",
    "v61-ssd-moe-runtime-roadmap": "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
}
acceptance_blocker_path_by_slice = {
    "docs/v1-roadmap": "pm_pr_claim_boundary_rows.csv",
    "v52-baseline-registry-contract": "pm_pr_merge_gate_rows.csv",
    "v53-public-repo-source-manifest": "source_v53t/complete_source_foundation_freeze_rows.csv",
    "v53-query-instantiation-1000": "source_v53t/complete_source_foundation_freeze_rows.csv",
    "v53-system-a-b-g-h-measured": "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv",
    "v54-routehint-generation-contract": "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
    "v56-ruler-longbench-expanded": "blocker_packets/v56-replay-artifact-missing.md",
    "v58-blind-eval-contract": "blocker_packets/v58-real-blind-eval-missing.md",
    "v59-one-command-demo": "source_v59e/public_source_replay_policy_rows.csv",
    "v61-ssd-moe-runtime-roadmap": "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
}
acceptance_evidence_rows = []
for row in slice_rows:
    slice_id = row["slice_id"]
    claim_row = claim_by_slice[slice_id]
    verification_rows_for_slice = verification_by_slice[slice_id]
    local_commands = " | ".join(
        command_row["command"]
        for command_row in verification_rows_for_slice
        if command_row["execution_policy"] == "local-smoke"
    )
    deferred_commands = " | ".join(
        command_row["command"]
        for command_row in verification_rows_for_slice
        if command_row["execution_policy"] != "local-smoke"
    )
    replay_path = acceptance_replay_path_by_slice[slice_id]
    blocker_path = acceptance_blocker_path_by_slice[slice_id]
    tests_only_merge_condition = int(row["merge_condition"].strip().lower() in {"tests pass", "test pass", "tests"})
    acceptance_evidence_rows.append(
        {
            "ordinal": row["ordinal"],
            "slice_id": slice_id,
            "claim_evidence_path": claim_row["evidence_path"],
            "claim_boundary_status": "pass" if row["claim_boundary_ok"] == "1" else "blocked",
            "replay_artifact_path": replay_path,
            "replay_artifact_present": str(int((run_dir / replay_path).is_file())),
            "replay_artifact_status": "pass" if row["replay_artifact_ok"] == "1" else "blocked",
            "blocker_evidence_path": blocker_path,
            "blocker_false_positive_status": "pass" if row["blocker_false_positive_closed"] == "1" else "blocked",
            "local_smoke_commands": local_commands,
            "deferred_commands": deferred_commands or "none",
            "tests_only_merge_condition": str(tests_only_merge_condition),
            "acceptance_ready": row["current_merge_ready"],
            "acceptance_signal": row["reason"],
            "review_packet_path": review_packet_by_slice[slice_id]["packet_path"],
        }
    )
write_csv(run_dir / "pm_pr_acceptance_evidence_rows.csv", list(acceptance_evidence_rows[0].keys()), acceptance_evidence_rows)


def required_artifact_present(row):
    artifact_path = row.get("artifact_path_or_env", "")
    if not artifact_path.startswith("results/"):
        return 0
    path = root / artifact_path
    if row.get("artifact_kind") == "artifact-directory":
        return int(path.is_dir() and any(child.is_file() and child.stat().st_size > 0 for child in path.rglob("*")))
    return int(path.is_file() and path.stat().st_size > 0)


def v56_required_artifact_ready(row):
    artifact_id = row.get("artifact_id", "")
    present = required_artifact_present(row)
    if artifact_id.startswith("v56-contract"):
        return int(
            present
            and as_int(v56_contract, "v56_ruler_longbench_expanded_contract_ready") == 1
            and as_int(v56_contract, "real_external_benchmark_verified") == 0
            and as_int(v56_contract, "real_release_package_ready") == 0
        )
    if artifact_id.startswith("v56b-scale"):
        return int(
            present
            and as_int(v56b, "v56b_ruler_longbench_expanded_scale_ready") == 1
            and as_int(v56b, "real_external_benchmark_verified") == 0
            and as_int(v56b, "real_release_package_ready") == 0
        )
    return 0


v56_replay_acceptance_evidence_rows = []
for artifact in [row for row in blocker_required_artifact_rows if row["blocker_class"] == "v56-replay-artifact-missing"]:
    present = required_artifact_present(artifact)
    ready = v56_required_artifact_ready(artifact)
    artifact_id = artifact["artifact_id"]
    if artifact_id.startswith("v56-contract"):
        observed_signal = (
            f"v56_contract_ready={v56_contract.get('v56_ruler_longbench_expanded_contract_ready', '0')} "
            f"seed_dependency_blocker_ready={v56_contract.get('v56_seed_dependency_blocker_ready', '0')} "
            f"missing_seed_artifact_rows={v56_contract.get('missing_seed_artifact_rows', '0')} "
            f"real_external_benchmark_verified={v56_contract.get('real_external_benchmark_verified', '0')} "
            f"real_release_package_ready={v56_contract.get('real_release_package_ready', '0')} "
            f"copied_summary={int(bool(v56_contract_summary_copied))}"
        )
    else:
        observed_signal = (
            f"v56b_ready={v56b.get('v56b_ruler_longbench_expanded_scale_ready', '0')} "
            f"real_external_benchmark_verified={v56b.get('real_external_benchmark_verified', '0')} "
            f"real_release_package_ready={v56b.get('real_release_package_ready', '0')}"
        )
    v56_replay_acceptance_evidence_rows.append(
        {
            "slice_id": "v56-ruler-longbench-expanded",
            "blocker_class": artifact["blocker_class"],
            "artifact_id": artifact_id,
            "artifact_path_or_env": artifact["artifact_path_or_env"],
            "artifact_kind": artifact["artifact_kind"],
            "required_shape": artifact["required_shape"],
            "validation_command": artifact["validation_command"],
            "acceptance_signal": artifact["acceptance_signal"],
            "artifact_present": str(present),
            "claim_boundary_status": "pass",
            "output_artifact_replay_status": "pass" if ready else "blocked",
            "blocker_false_positive_status": "pass",
            "approval_required": artifact["approval_required"],
            "fixture_allowed": artifact["fixture_allowed"],
            "tests_only_merge_condition": "0",
            "acceptance_ready": str(ready),
            "acceptance_status": "ready" if ready else "blocked",
            "observed_signal": observed_signal,
            "claim_until_closed": "v56 replay artifact missing; no benchmark/leaderboard claim",
        }
    )
write_csv(
    run_dir / "v56_replay_acceptance_evidence_rows.csv",
    list(v56_replay_acceptance_evidence_rows[0].keys()),
    v56_replay_acceptance_evidence_rows,
)


def de_artifact_system(row):
    artifact_id = row.get("artifact_id", "")
    if artifact_id.startswith("d-"):
        return "D", "d_30b", "required_30b_baseline_ready"
    if artifact_id.startswith("e-"):
        return "E", "e_70b", "required_70b_baseline_ready"
    return "", "", ""


de_30b70b_acceptance_evidence_rows = []
for artifact in [row for row in blocker_required_artifact_rows if row["blocker_class"] == "de-30b70b-baselines-missing"]:
    system_id, prefix, ready_field = de_artifact_system(artifact)
    evidence_dir_supplied = as_int(v52d, f"{prefix}_evidence_dir_supplied") if prefix else 0
    supplied_evidence_ready = as_int(v52d, f"{prefix}_supplied_evidence_ready") if prefix else 0
    baseline_ready = as_int(v52d, ready_field) if ready_field else 0
    ready = int(
        baseline_ready == 1
        and supplied_evidence_ready == 1
        and as_int(v52d, "v52_absorb_ready") == 1
        and as_int(v52d, "v52_ready") == 0
        and as_int(v52d, "real_release_package_ready") == 0
    )
    observed_signal = (
        f"v52d_contract_ready={v52d.get('v52d_30b70b_llm_rag_intake_contract_ready', '0')} "
        f"system_id={system_id} evidence_dir_supplied={evidence_dir_supplied} "
        f"supplied_evidence_ready={supplied_evidence_ready} baseline_ready={baseline_ready} "
        f"query_rows={v52d.get(f'{prefix}_query_rows', '0') if prefix else '0'} "
        f"validation_error_rows={v52d.get(f'{prefix}_validation_error_rows', '0') if prefix else '0'} "
        f"v52_absorb_ready={v52d.get('v52_absorb_ready', '0')} "
        f"v52_ready={v52d.get('v52_ready', '0')} "
        f"copied_summary={int(bool(v52d_summary_copied))}"
    )
    de_30b70b_acceptance_evidence_rows.append(
        {
            "requirement_id": "de-30b70b-symmetric-baselines",
            "slice_id": "v52-baseline-registry-contract",
            "blocker_class": artifact["blocker_class"],
            "system_id": system_id,
            "artifact_id": artifact["artifact_id"],
            "artifact_path_or_env": artifact["artifact_path_or_env"],
            "artifact_kind": artifact["artifact_kind"],
            "required_shape": artifact["required_shape"],
            "validation_command": artifact["validation_command"],
            "acceptance_signal": artifact["acceptance_signal"],
            "artifact_present": str(evidence_dir_supplied),
            "claim_boundary_status": "pass",
            "output_artifact_replay_status": "pass" if ready else "blocked",
            "blocker_false_positive_status": "pass",
            "approval_required": artifact["approval_required"],
            "fixture_allowed": artifact["fixture_allowed"],
            "tests_only_merge_condition": "0",
            "acceptance_ready": str(ready),
            "acceptance_status": "ready" if ready else "blocked",
            "observed_signal": observed_signal,
            "claim_until_closed": "D/E 30B/70B baselines missing; A/B/G/H internal pre-baseline only",
        }
    )
write_csv(
    run_dir / "de_30b70b_acceptance_evidence_rows.csv",
    list(de_30b70b_acceptance_evidence_rows[0].keys()),
    de_30b70b_acceptance_evidence_rows,
)

de_measured_registry_exclusion_rows = []
de_required_real_fields = [
    "model_repository_exact_revision",
    "quantization",
    "model_artifact_hash",
    "runtime",
    "prompt_template",
    "context_budget",
    "retrieval_budget",
    "hardware",
    "seed",
    "answer_citation_raw_output",
    "evaluator_version",
]
for system_id in ["D", "E"]:
    related_rows = [row for row in de_30b70b_acceptance_evidence_rows if row["system_id"] == system_id]
    de_measured_registry_exclusion_rows.append(
        {
            "system_id": system_id,
            "baseline_class": "30b-open-weight-llm-rag" if system_id == "D" else "70b-open-weight-llm-rag",
            "fixture_schema_test_allowed": "1",
            "fixture_rows_in_measured_registry": "0",
            "measured_registry_admission_ready": "0",
            "required_real_evidence_fields": ";".join(de_required_real_fields),
            "missing_real_evidence_fields": ";".join(de_required_real_fields),
            "raw_answer_citation_output_required": "1",
            "answer_citation_raw_output_rows": "0",
            "resource_row_required": "1",
            "evaluator_version_required": "1",
            "same_query_set_required": "1",
            "acceptance_evidence_rows": str(len(related_rows)),
            "acceptance_ready_rows": str(sum(1 for row in related_rows if row["acceptance_ready"] == "1")),
            "fixture_allowed": "0",
            "tests_only_merge_condition": "0",
            "measured_registry_policy": "real-d-e-only; fixture-d-e-schema-tests-stay-out",
            "evidence_path": "de_30b70b_acceptance_evidence_rows.csv",
            "status": "blocked",
            "claim_boundary": "D/E fixture or schema evidence cannot enter measured registry or public comparison rows",
        }
    )
write_csv(
    run_dir / "de_measured_registry_exclusion_rows.csv",
    list(de_measured_registry_exclusion_rows[0].keys()),
    de_measured_registry_exclusion_rows,
)

v58_real_execution_requirements = [
    (
        "ab-cdegh-real-responses",
        "A/B/C/D/E/G/H actual response rows over the same frozen query set",
        "v58c currently covers D/E/G/H response intake; A/B/C real blind-response rows and all supplied real responses are still missing",
        "source_summaries/v58c_blind_response_evidence_intake_summary.csv",
    ),
    (
        "same-corpus-context-budget",
        "same corpus, same source snapshot, same context budget, and same retrieval budget for every system",
        "same-query/source budget contract must be bound to supplied real response metadata before v58 can close",
        "source_v53t/complete_source_foundation_freeze_rows.csv",
    ),
    (
        "blind-identity",
        "blind identities preserved until scoring and adjudication finish",
        "identity remains sealed in templates; supplied real response/review rows are absent",
        "pm_blocker_required_artifact_rows.csv",
    ),
    (
        "two-independent-reviewers",
        "at least two independent blinded reviewers per required response",
        "review return rows are absent by default",
        "source_summaries/v58d_blind_review_return_intake_summary.csv",
    ),
    (
        "disagreement-adjudication",
        "disagreement and adjudication rows for every required response",
        "adjudication rows are absent by default",
        "source_summaries/v58d_blind_review_return_intake_summary.csv",
    ),
    (
        "unseen-repository-split",
        "unseen repository split remains explicit and bound to the frozen blind query packet",
        "split evidence must be carried with the real response packet before full v58 readiness",
        "source_docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
    ),
    (
        "source-span-exactness",
        "source span exactness scored separately from answer text",
        "source span exactness requires adjudicated review/score rows",
        "pm_blocker_required_artifact_rows.csv",
    ),
    (
        "unsupported-abstention",
        "unsupported/missing rows must permit and score abstention",
        "unsupported abstention scoring requires supplied blind responses and adjudicated labels",
        "pm_blocker_required_artifact_rows.csv",
    ),
    (
        "latency-memory-separate",
        "latency and memory are recorded but evaluated separately from answer quality",
        "resource fields are required in response intake but no real rows are supplied yet",
        "source_summaries/v58c_blind_response_evidence_intake_summary.csv",
    ),
]
v58_real_execution_readiness_rows = []
for requirement_id, required_evidence, current_gap, evidence_path in v58_real_execution_requirements:
    v58_real_execution_readiness_rows.append(
        {
            "requirement_id": requirement_id,
            "required_for_v58_real_execution": "1",
            "required_evidence": required_evidence,
            "current_gap": current_gap,
            "evidence_path": evidence_path,
            "contract_ready": "1",
            "real_execution_ready": "0",
            "fixture_allowed": "0",
            "tests_only_merge_condition": "0",
            "status": "blocked",
            "claim_boundary": "v58 real execution remains blocked until non-fixture response, review, adjudication, score, and resource evidence validate",
        }
    )
write_csv(
    run_dir / "v58_real_execution_readiness_rows.csv",
    list(v58_real_execution_readiness_rows[0].keys()),
    v58_real_execution_readiness_rows,
)


def v59_artifact_ready(row):
    artifact_id = row.get("artifact_id", "")
    if artifact_id == "v59e-replay-preflight":
        return int(
            required_artifact_present(row)
            and as_int(v59e, "one_command_replay_preflight_ready") == 1
            and as_int(v59e, "one_command_entrypoint_ready") == 1
            and as_int(v59e, "challenge_bundle_ready") == 1
            and as_int(v59e, "network_required") == 0
            and as_int(v59e, "downloads_required") == 0
            and as_int(v59e, "full_public_source_download_ready") == 0
        )
    if artifact_id == "v59e-local-abgh-row-contract-replay":
        return int(
            required_artifact_present(row)
            and as_int(v59e, "local_abgh_row_contract_replay_ready") == 1
            and as_int(v59e, "local_abgh_row_contract_replay_rows") == 2
            and as_int(v59e, "local_abgh_row_contract_replay_pass_rows") == 2
        )
    if artifact_id == "v59-public-source-download-refresh":
        return int(
            as_int(v59e, "full_public_source_download_ready") == 1
            and as_int(v59e, "public_source_download_executed") == 1
            and as_int(v59e, "public_source_download_approval_required") == 1
        )
    return 0


v59_one_command_acceptance_evidence_rows = []
for artifact in [
    row
    for row in blocker_required_artifact_rows
    if row["blocker_class"] == "v60-release-evidence-missing"
    and row["artifact_id"]
    in {
        "v59e-local-abgh-row-contract-replay",
        "v59-public-source-download-refresh",
    }
]:
    artifact_id = artifact["artifact_id"]
    ready = v59_artifact_ready(artifact)
    if artifact_id == "v59e-replay-preflight":
        observed_signal = (
            f"one_command_replay_preflight_ready={v59e.get('one_command_replay_preflight_ready', '0')} "
            f"one_command_entrypoint_ready={v59e.get('one_command_entrypoint_ready', '0')} "
            f"challenge_bundle_ready={v59e.get('challenge_bundle_ready', '0')} "
            f"network_required={v59e.get('network_required', '0')} "
            f"downloads_required={v59e.get('downloads_required', '0')} "
            f"full_public_source_download_ready={v59e.get('full_public_source_download_ready', '0')}"
        )
    elif artifact_id == "v59e-local-abgh-row-contract-replay":
        observed_signal = (
            f"local_abgh_row_contract_replay_ready={v59e.get('local_abgh_row_contract_replay_ready', '0')} "
            f"local_abgh_row_contract_replay_rows={v59e.get('local_abgh_row_contract_replay_rows', '0')} "
            f"local_abgh_row_contract_replay_pass_rows={v59e.get('local_abgh_row_contract_replay_pass_rows', '0')} "
            f"v53aq_internal_real_adapter_metric_claim_ready={v59e.get('v53aq_internal_real_adapter_metric_claim_ready', '0')} "
            f"v53aq_public_real_system_performance_claim_ready={v59e.get('v53aq_public_real_system_performance_claim_ready', '1')} "
            "public_comparison_claim_ready=0"
        )
    else:
        observed_signal = (
            f"pinned_public_sources_verified={v59e.get('pinned_public_sources_verified', '0')} "
            f"public_source_snapshot_replay_ready={v59e.get('public_source_snapshot_replay_ready', '0')} "
            f"public_source_snapshot_replay_rows={v59e.get('public_source_snapshot_replay_rows', '0')} "
            f"public_source_download_executed={v59e.get('public_source_download_executed', '0')} "
            f"public_source_download_approval_required={v59e.get('public_source_download_approval_required', '0')} "
            f"full_public_source_download_ready={v59e.get('full_public_source_download_ready', '0')} "
            f"policy_blocker={v59e_public_source_policy.get('blocker_status', 'missing')}"
        )
    v59_one_command_acceptance_evidence_rows.append(
        {
            "requirement_id": "v59-one-command-foundation-or-public-refresh",
            "slice_id": "v59-one-command-demo",
            "blocker_class": artifact["blocker_class"],
            "artifact_id": artifact_id,
            "artifact_path_or_env": artifact["artifact_path_or_env"],
            "artifact_kind": artifact["artifact_kind"],
            "required_shape": artifact["required_shape"],
            "validation_command": artifact["validation_command"],
            "acceptance_signal": artifact["acceptance_signal"],
            "artifact_present": str(required_artifact_present(artifact)),
            "claim_boundary_status": "pass",
            "output_artifact_replay_status": "pass" if ready else "blocked",
            "blocker_false_positive_status": "pass",
            "approval_required": artifact["approval_required"],
            "fixture_allowed": artifact["fixture_allowed"],
            "tests_only_merge_condition": "0",
            "acceptance_ready": str(ready),
            "acceptance_status": "ready" if ready else "blocked",
            "observed_signal": observed_signal,
            "claim_until_closed": "v59 PM foundation replay only; full public-source download/refresh remains approval-blocked",
        }
    )
write_csv(
    run_dir / "v59_one_command_acceptance_evidence_rows.csv",
    list(v59_one_command_acceptance_evidence_rows[0].keys()),
    v59_one_command_acceptance_evidence_rows,
)

closure_by_blocker = {row["blocker_class"]: row for row in blocker_closure_rows}
required_artifacts_by_blocker = {row["blocker_class"]: [] for row in blocker_closure_rows}
for row in blocker_required_artifact_rows:
    required_artifacts_by_blocker.setdefault(row["blocker_class"], []).append(row)

blocker_packet_rows = []
blocker_packet_dir = run_dir / "blocker_packets"
blocker_packet_dir.mkdir(parents=True, exist_ok=True)
for row in blocker_closure_rows:
    blocker_class = row["blocker_class"]
    artifact_rows_for_blocker = required_artifacts_by_blocker.get(blocker_class, [])
    artifact_list = "\n".join(
        f"- `{artifact['artifact_id']}`: {artifact['artifact_kind']} at `{artifact['artifact_path_or_env']}`; shape: {artifact['required_shape']}"
        for artifact in artifact_rows_for_blocker
    )
    packet_rel = f"blocker_packets/{safe_id(blocker_class)}.md"
    packet_path = run_dir / packet_rel
    packet_text = f"""# {blocker_class}

Milestone: {row['milestone']}
Requirement: {row['requirement_id']}

## Approval Required

{row['approval_required']}

Do not execute automatically. This packet is a local closure runbook only and
does not approve runtime, model, dataset, benchmark, human-review, release, or
external-system work.

## Execution Policy

{row['execution_policy']}

## Required External Artifacts

{row['required_external_artifacts']}

## Required Artifact Checklist

{artifact_list}

## Local Intake Or Verification Command

`{row['local_intake_or_verification_command']}`

## Ready Condition

{row['ready_condition']}

## Claim Until Closed

{row['claim_until_closed']}
"""
    packet_path.write_text(packet_text, encoding="utf-8")
    blocker_packet_rows.append(
        {
            "blocker_class": blocker_class,
            "packet_path": packet_rel,
            "milestone": row["milestone"],
            "requirement_id": row["requirement_id"],
            "approval_required": row["approval_required"],
            "execution_policy": row["execution_policy"],
            "required_artifact_rows": str(len(artifact_rows_for_blocker)),
            "local_intake_or_verification_command": row["local_intake_or_verification_command"],
            "ready_condition": row["ready_condition"],
            "claim_until_closed": row["claim_until_closed"],
            "packet_ready": "1",
            "packet_sha256": sha256(packet_path),
        }
    )
write_csv(run_dir / "pm_blocker_closure_packet_rows.csv", list(blocker_packet_rows[0].keys()), blocker_packet_rows)

execution_lock_rows = [
    {
        "lock_id": "no-new-v62-v63-default",
        "milestone": "M1",
        "scope": "PM execution focus",
        "required_focus": "close v52-v60/v61 review slices with real measured rows, replay artifacts, and external returns",
        "allowed_next_action": "edit existing v52-v60/v61 gates, review packets, blocker packets, and evidence intake contracts",
        "forbidden_next_action": "create new v62/v63 scaffold to bypass current blockers",
        "status": "locked",
        "evidence_path": "pm_pr_slice_rows.csv",
    },
    {
        "lock_id": "v53-foundation-freeze-first",
        "milestone": "M2",
        "scope": "v53 foundation",
        "required_focus": "keep 10 public repos, 1000 source-span queries, controls, evaluator separation, and same-query hash frozen",
        "allowed_next_action": "review v53 foundation certificate and accept real review returns against the frozen packet",
        "forbidden_next_action": "change query set, spans, seeds, controls, metrics, or baseline surface silently",
        "status": "locked",
        "evidence_path": "source_summaries/v53t_complete_source_audit_readiness_gate_summary.csv",
    },
    {
        "lock_id": "abgh-internal-prebaseline-only",
        "milestone": "M3",
        "scope": "A/B/G/H measured rows",
        "required_focus": "use A/B/G/H only as internal v1.0 pre-baseline evidence until D/E arrive",
        "allowed_next_action": "review local A/B/G/H rows over the same complete-source query hash",
        "forbidden_next_action": "make public comparison, D/E replacement, or quality win wording",
        "status": "locked",
        "evidence_path": "source_summaries/v53ap_complete_source_abgh_same_query_measured_summary.csv",
    },
    {
        "lock_id": "de-baselines-real-evidence-only",
        "milestone": "M3/M6",
        "scope": "D/E 30B/70B baselines",
        "required_focus": "supply symmetric D/E model identity and answer/citation/resource evidence on the frozen surface",
        "allowed_next_action": "run D/E evidence intake only after real evidence directories and runtime/external approval exist",
        "forbidden_next_action": "treat A/B/G/H or fixture/supplied mechanics as D/E completion",
        "status": "locked",
        "evidence_path": "blocker_packets/de-30b70b-baselines-missing.md",
    },
    {
        "lock_id": "h10-real-label-only",
        "milestone": "M4",
        "scope": "h10 scorer promotion",
        "required_focus": "promote h10 only with accepted external/human labels and source-verified eval readiness",
        "allowed_next_action": "intake real h10 label evidence after external/human label approval",
        "forbidden_next_action": "claim h10 scientific contribution from chunk-credit or fixture-only readiness",
        "status": "locked",
        "evidence_path": "blocker_packets/external-human-label-evidence-missing.md",
    },
    {
        "lock_id": "v54-grounded-generation-no-raw-context",
        "milestone": "M5",
        "scope": "v54 grounded generation",
        "required_focus": "keep 1000 grounded generation rows source-bound with zero raw prompt stuffing",
        "allowed_next_action": "review v54c answer/citation/unsupported/abstain/resource/guard rows and sha256sums",
        "forbidden_next_action": "call raw retrieved context prompt stuffing a mainline RouteHint generator",
        "status": "locked",
        "evidence_path": "source_summaries/v54c_complete_source_grounded_generation_1000_summary.csv",
    },
    {
        "lock_id": "v56-replay-artifact-before-benchmark-claim",
        "milestone": "M1/M6",
        "scope": "v56 benchmark expansion",
        "required_focus": "supply replayable source/evaluator-bound v56 artifacts before benchmark or leaderboard wording",
        "allowed_next_action": "execute v56/v56b only with approved seed/contract artifact rebuild or supplied replay artifacts",
        "forbidden_next_action": "silently regenerate heavy benchmark chain or claim expanded benchmark readiness",
        "status": "locked",
        "evidence_path": "blocker_packets/v56-replay-artifact-missing.md",
    },
    {
        "lock_id": "v58-real-blind-eval-only",
        "milestone": "M6",
        "scope": "v58 blind eval",
        "required_focus": "complete v58 only with real blind responses, identity hiding, human review, and adjudication",
        "allowed_next_action": "intake real blind response evidence after response/review approval",
        "forbidden_next_action": "turn blocker ledger, templates, or fixture rows into blind-eval completion",
        "status": "locked",
        "evidence_path": "blocker_packets/v58-real-blind-eval-missing.md",
    },
    {
        "lock_id": "v59-foundation-not-public-demo",
        "milestone": "M6",
        "scope": "v59 one-command",
        "required_focus": "treat v59e as PM foundation replay until real D/E, h10 labels, blind eval, and release evidence close",
        "allowed_next_action": "use the one-command PM foundation bundle for local reviewer reproduction",
        "forbidden_next_action": "publish v59e as full v1.0 public challenge demo",
        "status": "locked",
        "evidence_path": "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
    },
    {
        "lock_id": "v60-release-gate-last",
        "milestone": "M6",
        "scope": "v60 release",
        "required_focus": "open v60 only after all upstream blockers close with real evidence and human/release review",
        "allowed_next_action": "run release preflight/audit after v52-v59 readiness and review evidence are present",
        "forbidden_next_action": "claim v1.0 release, public win, production readiness, or Transformer replacement now",
        "status": "locked",
        "evidence_path": "blocker_packets/v60-release-evidence-missing.md",
    },
]
write_csv(run_dir / "pm_execution_lock_rows.csv", list(execution_lock_rows[0].keys()), execution_lock_rows)

pm_ready_rows = sum(1 for row in pm_roadmap_rows if row["status"] == "ready")
pm_blocked_rows = len(pm_roadmap_rows) - pm_ready_rows
pm_foundation_ready = int(
    all(
        row["status"] == "ready"
        for row in pm_roadmap_rows
        if row["requirement_id"]
        in {
            "pr-split-ledger",
            "merge-condition-boundary",
            "pinned-public-repo-manifest",
            "source-span-query-freeze",
            "negative-and-conflict-controls",
            "answer-citation-separated",
            "abgh-same-query-measured",
            "internal-pre-baseline-boundary",
            "h10-readiness-ledger",
            "v54-grounded-generation-outputs",
            "no-raw-prompt-stuffing",
            "v58-blind-eval-blocker-ledger",
            "v59-one-command-foundation",
        }
    )
)
milestone_focus = {
    "M1": "PR and claim slicing",
    "M2": "v53 source-bound 1000-row corpus freeze",
    "M3": "A/B/G/H same-query internal pre-baseline",
    "M4": "h10 real-label scorer promotion",
    "M5": "v54 grounded generation rows",
    "M6": "v58 blind eval, v59 demo, and v60 release gates",
}
milestone_next_action = {
    "M1": "keep the v56 slice blocked until replay artifacts are hash-bound",
    "M2": "send and intake real complete-source review/adjudication before v53_ready",
    "M3": "supply D/E 30B/70B symmetric baselines before any public comparison wording",
    "M4": "supply accepted external/human labels and source-verified eval rows",
    "M5": "keep grounded generation under the no-raw-prompt boundary until review",
    "M6": "supply v58c/v58 blind-eval artifacts, full public demo evidence, and release review",
}
milestone_claim_boundary = {
    "M1": "review slices are local runbooks; no merge, push, or release action is implied",
    "M2": "machine corpus freeze only; human-reviewed quality comparison remains blocked",
    "M3": "A/B/G/H is internal pre-baseline evidence only; no public comparison claim",
    "M4": "h10 readiness ledger only; real-label promotion and scientific-contribution claims remain blocked",
    "M5": "machine grounded-generation rows only; no human-reviewed quality or release claim",
    "M6": "pre-v1.0 public artifact posture; blind eval, full demo, and release remain blocked",
}
pm_roadmap_milestone_rows = []
for milestone in ["M1", "M2", "M3", "M4", "M5", "M6"]:
    rows = [row for row in pm_roadmap_rows if row["milestone"] == milestone]
    ready_ids = [row["requirement_id"] for row in rows if row["status"] == "ready"]
    blocked_ids = [row["requirement_id"] for row in rows if row["status"] == "blocked"]
    blocker_classes = sorted({row["blocker_class"] for row in rows if row["blocker_class"]})
    evidence_paths = sorted({row["evidence_path"] for row in rows if row["evidence_path"]})
    pm_roadmap_milestone_rows.append(
        {
            "milestone": milestone,
            "focus": milestone_focus[milestone],
            "requirement_rows": str(len(rows)),
            "ready_rows": str(len(ready_ids)),
            "blocked_rows": str(len(blocked_ids)),
            "status": "ready" if not blocked_ids else "blocked",
            "ready_requirement_ids": ";".join(ready_ids),
            "blocked_requirement_ids": ";".join(blocked_ids),
            "blocker_classes": ";".join(blocker_classes),
            "evidence_paths": ";".join(evidence_paths),
            "next_action": milestone_next_action[milestone],
            "claim_boundary": milestone_claim_boundary[milestone],
        }
    )
write_csv(run_dir / "pm_roadmap_milestone_rows.csv", list(pm_roadmap_milestone_rows[0].keys()), pm_roadmap_milestone_rows)

def normalization_row(slice_id, scope, output_artifact, claim_boundary, blocker_policy, evidence_path):
    return {
        "slice_id": slice_id,
        "scope": scope,
        "output_artifact": output_artifact,
        "merge_condition": "claim boundary accurate; output artifact replayable; blocker false-positive closed",
        "tests_only_merge_condition": "0",
        "claim_boundary": claim_boundary,
        "blocker_policy": blocker_policy,
        "evidence_path": evidence_path,
        "current_status": "split-required",
        "pr2_merge_as_is_recommended": "0",
    }


pm_pr_normalization_rows = [
    normalization_row(
        "v50-auditor-correctness",
        "v50 auditor correctness fixes and source/citation correctness guard",
        "v50 auditor correctness rows and smoke evidence",
        "Auditor correctness only; no v1.0 quality or benchmark claim",
        "False-positive closure requires replayable auditor evidence, not tests-only status",
        "source_summaries/v52_llm_rag_baseline_war_summary.csv",
    ),
    normalization_row(
        "v52-7b-actual-adapter-and-de-intake-guard",
        "v52 7B actual adapter plus D/E intake guard boundaries",
        "C/7B actual adapter rows and D/E no-fixture intake guard rows",
        "7B/C evidence is not a D/E substitute; fixture D/E remains schema-only",
        "D/E measured registry remains blocked until real model identity and raw outputs validate",
        "de_30b70b_acceptance_evidence_rows.csv",
    ),
    normalization_row(
        "v53-v54-query-evaluation-pipeline",
        "v53 source-bound query/evaluator pipeline and v54 grounded generation rows",
        "v53 query-span/evaluator rows, v53aq no-leakage rows, and v54 generation outputs",
        "Internal source-bound QA/generation pipeline only; public comparison remains blocked",
        "Replay requires source-bound rows, separated evaluator rows, and no raw prompt stuffing",
        "pm_roadmap_requirement_rows.csv",
    ),
    normalization_row(
        "v58-blind-eval-protocol",
        "v58 real blind-eval protocol, response intake, reviewer/adjudication workflow",
        "v58 required artifact rows, return templates, and blind-eval blocker ledger",
        "Protocol/contract only until real blind responses and independent review returns exist",
        "Full blind eval requires unseen split, blind identities, two reviewers, disagreement/adjudication",
        "pm_blocker_required_artifact_rows.csv",
    ),
    normalization_row(
        "v61-checkpoint-runtime-core",
        "v61 checkpoint/runtime core through real tensor page and one-token parity milestones",
        "v61 runtime roadmap rows and one-token parity blocker packet",
        "SSD-resident runtime remains R&D until real tensor page, dequant, matvec, FFN, MoE, and logits parity exist",
        "Gate-only v61 scaffold cannot claim real model runtime or token generation",
        "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
    ),
    normalization_row(
        "operator-review-return-workflow",
        "operator/review-return workflow for human labels, blind review, and release review",
        "operator return templates, h10/v58 review-return rows, and approval-required blocker packets",
        "Workflow readiness only; no human-review, independent reproduction, or release claim",
        "Human/reviewer return blockers stay open until non-fixture returns are supplied",
        "pm_external_return_template_rows.csv",
    ),
    normalization_row(
        "docs-readme-cleanup",
        "docs and README claim-boundary cleanup for current v61/pre-v1.0 state",
        "README and docs claim-boundary rows plus PR title/body rewrite row",
        "Documentation must say pre-v1.0 research artifact, not release or transformer replacement",
        "Docs merge requires stale-title/body replacement and explicit blocked claims",
        "pm_pr_title_body_rows.csv",
    ),
]
write_csv(run_dir / "pm_pr_normalization_rows.csv", list(pm_pr_normalization_rows[0].keys()), pm_pr_normalization_rows)

pm_pr_title_body_rows = [
    {
        "pr_id": "draft-pr-2",
        "recommended_title": "Split v1.0 PM foundation, blind-eval, and v61 runtime evidence boundaries",
        "recommended_body_scope": ";".join(row["slice_id"] for row in pm_pr_normalization_rows),
        "current_v61_status": "pre-v1.0 research artifact; v61 checkpoint/runtime core still needs real tensor page through one-token parity evidence",
        "pr2_merge_as_is_recommended": "0",
        "split_required": "1",
        "release_ready": "0",
        "public_comparison_claim_ready": "0",
        "title_body_rewrite_ready": "1",
    }
]
write_csv(run_dir / "pm_pr_title_body_rows.csv", list(pm_pr_title_body_rows[0].keys()), pm_pr_title_body_rows)

def ready_semantic_row(scope_id, contract_ready, fixture_execution_ready, real_model_execution_ready, heldout_metric_ready, human_review_ready, independent_reproduction_ready, release_ready, evidence_path, misleading_ready_flag, replacement_flag):
    return {
        "scope_id": scope_id,
        "contract_ready": str(int(contract_ready)),
        "fixture_execution_ready": str(int(fixture_execution_ready)),
        "real_model_execution_ready": str(int(real_model_execution_ready)),
        "heldout_metric_ready": str(int(heldout_metric_ready)),
        "human_review_ready": str(int(human_review_ready)),
        "independent_reproduction_ready": str(int(independent_reproduction_ready)),
        "release_ready": str(int(release_ready)),
        "misleading_ready_flag": misleading_ready_flag,
        "replacement_flag": replacement_flag,
        "ready_wording_policy": "typed-ready-only",
        "evidence_path": evidence_path,
    }


pm_ready_semantic_rows = [
    ready_semantic_row(
        "pm-foundation-bundle",
        True,
        True,
        False,
        False,
        False,
        False,
        False,
        "source_summaries/v59e_one_command_pm_foundation_demo_summary.csv",
        "v59_ready",
        "pm_foundation_contract_fixture_ready",
    ),
    ready_semantic_row(
        "v53-v54-query-evaluation-pipeline",
        True,
        False,
        False,
        False,
        False,
        False,
        False,
        "pm_roadmap_requirement_rows.csv",
        "v53_ready",
        "v53_v54_query_eval_contract_ready",
    ),
    ready_semantic_row(
        "v58-blind-eval",
        True,
        False,
        False,
        False,
        False,
        False,
        False,
        "pm_blocker_required_artifact_rows.csv",
        "v58_ready",
        "v58_blind_eval_protocol_contract_ready",
    ),
    ready_semantic_row(
        "h10-scorer-real-label-promotion",
        True,
        False,
        False,
        False,
        False,
        False,
        False,
        "source_h10_pm/pm_h10_real_label_acceptance_rows.csv",
        "h10_real_label_promotion_ready",
        "h10_real_label_contract_ready",
    ),
    ready_semantic_row(
        "v61-ssd-moe-runtime",
        True,
        True,
        False,
        False,
        False,
        False,
        False,
        "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
        "100b_moe_run_ready",
        "logical_100b_contract_fixture_ready",
    ),
    ready_semantic_row(
        "v61-real-100b-inference",
        False,
        False,
        False,
        False,
        False,
        False,
        False,
        "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
        "100b_moe_run_ready",
        "real_100b_inference_ready",
    ),
    ready_semantic_row(
        "v61i-logical-100b-fixture",
        True,
        True,
        False,
        False,
        False,
        False,
        False,
        "source_summaries/v61j_one_command_ssd_resident_demo_summary.csv",
        "v61i_100b_moe_active_sparse_run_ready",
        "v61i_logical_100b_contract_fixture_ready",
    ),
    ready_semantic_row(
        "v60-release",
        True,
        False,
        False,
        False,
        False,
        False,
        False,
        "source_summaries/v60_architecture_challenge_release_contract_summary.csv",
        "v60_ready",
        "v60_release_contract_ready",
    ),
]
write_csv(run_dir / "pm_ready_semantic_rows.csv", list(pm_ready_semantic_rows[0].keys()), pm_ready_semantic_rows)

def selection_blocked(field_name):
    row = v53aq_selection_contract_by_field.get(field_name, {})
    return int(row.get("selection_allowed", "0") == "0")


def leakage_guard_row(guard_id, forbidden_surface, field_names, evaluator_only_required=True):
    names = field_names.split(";")
    contract_rows = [v53aq_selection_contract_by_field.get(name, {}) for name in names]
    selection_blocked_value = int(all(row.get("selection_allowed", "0") == "0" for row in contract_rows))
    if not contract_rows or any(not row for row in contract_rows):
        selection_blocked_value = 1
    evaluator_only_value = int(
        all(row.get("evaluator_allowed", "1") == "1" for row in contract_rows if row)
        if evaluator_only_required
        else 1
    )
    return {
        "guard_id": guard_id,
        "forbidden_surface": forbidden_surface,
        "field_names": field_names,
        "adapter_selection_blocked": str(selection_blocked_value),
        "evaluator_only_or_absent": str(evaluator_only_value),
        "allowed_adapter_surface": "natural_language_question_plus_searchable_corpus",
        "selection_allowed_fields": "question",
        "direct_query_source_binding_forbidden": str(selection_blocked("query_id")),
        "evidence_path": "source_v53aq/adapter_selection_contract_rows.csv",
        "status": "pass" if selection_blocked_value and evaluator_only_value else "blocked",
    }


pm_retrieval_leakage_guard_rows = [
    leakage_guard_row("source-span-id", "source span ID", "source_span_id;span_id"),
    leakage_guard_row("source-path", "source path", "source_path;source_file_path;path"),
    leakage_guard_row("source-line", "source line", "source_line_start;source_line_end;line_start;line_end"),
    leakage_guard_row("source-file-hash", "source file hash", "source_file_hash;source_file_sha256;source_git_blob_sha"),
    leakage_guard_row("query-source-direct-binding", "query ID and direct source row binding", "query_id;source_row_id;source_query_id;query_source_id;source_binding_id"),
    leakage_guard_row("expected-behavior", "expected behavior", "expected_behavior;expected_answer;expected_answer_sha256;expected_output;gold_answer", evaluator_only_required=False),
    leakage_guard_row("expected-label", "expected label", "negative_or_abstain;audit_type;expected_label"),
]
write_csv(run_dir / "pm_retrieval_leakage_guard_rows.csv", list(pm_retrieval_leakage_guard_rows[0].keys()), pm_retrieval_leakage_guard_rows)

pm_pr_normalization_row_count = len(pm_pr_normalization_rows)
pm_pr_normalization_split_required_rows = sum(
    1 for row in pm_pr_normalization_rows if row["pr2_merge_as_is_recommended"] == "0"
)
pm_pr_normalization_tests_only_rows = sum(
    1 for row in pm_pr_normalization_rows if row["tests_only_merge_condition"] == "1"
)
pm_pr_title_body_row_count = len(pm_pr_title_body_rows)
pm_pr_title_body_rewrite_ready = int(
    all(row["title_body_rewrite_ready"] == "1" for row in pm_pr_title_body_rows)
)
pm_pr_title_body_split_required_rows = sum(1 for row in pm_pr_title_body_rows if row["split_required"] == "1")
pm_ready_semantic_row_count = len(pm_ready_semantic_rows)
ready_semantic_fields = [
    "contract_ready",
    "fixture_execution_ready",
    "real_model_execution_ready",
    "heldout_metric_ready",
    "human_review_ready",
    "independent_reproduction_ready",
    "release_ready",
]
pm_ready_semantic_typed_rows = sum(
    1 for row in pm_ready_semantic_rows if all(field in row for field in ready_semantic_fields)
)
pm_ready_semantic_contract_ready_rows = sum(1 for row in pm_ready_semantic_rows if row["contract_ready"] == "1")
pm_ready_semantic_fixture_execution_ready_rows = sum(
    1 for row in pm_ready_semantic_rows if row["fixture_execution_ready"] == "1"
)
pm_ready_semantic_real_model_ready_rows = sum(
    1 for row in pm_ready_semantic_rows if row["real_model_execution_ready"] == "1"
)
pm_ready_semantic_release_ready_rows = sum(1 for row in pm_ready_semantic_rows if row["release_ready"] == "1")
pm_ready_semantic_logical_100b_contract_fixture_ready = int(
    any(
        row["replacement_flag"] == "logical_100b_contract_fixture_ready"
        and row["contract_ready"] == "1"
        and row["fixture_execution_ready"] == "1"
        and row["real_model_execution_ready"] == "0"
        for row in pm_ready_semantic_rows
    )
)
pm_ready_semantic_real_100b_inference_ready = int(
    any(
        row["replacement_flag"] == "real_100b_inference_ready"
        and row["real_model_execution_ready"] == "1"
        for row in pm_ready_semantic_rows
    )
)
pm_retrieval_leakage_guard_row_count = len(pm_retrieval_leakage_guard_rows)
pm_retrieval_leakage_guard_pass_rows = sum(
    1 for row in pm_retrieval_leakage_guard_rows if row["status"] == "pass"
)
pm_retrieval_leakage_guard_blocked_rows = (
    pm_retrieval_leakage_guard_row_count - pm_retrieval_leakage_guard_pass_rows
)

pm_roadmap_milestone_row_count = len(pm_roadmap_milestone_rows)
pm_roadmap_milestone_ready_rows = sum(1 for row in pm_roadmap_milestone_rows if row["status"] == "ready")
pm_roadmap_milestone_blocked_rows = pm_roadmap_milestone_row_count - pm_roadmap_milestone_ready_rows
slice_file_row_count = len(slice_file_rows)
slice_file_existing_rows = sum(1 for row in slice_file_rows if row["exists"] == "1")
slice_with_file_rows = len({row["slice_id"] for row in slice_file_rows})
slice_verification_row_count = len(slice_verification_rows)
slice_with_verification_rows = len({row["slice_id"] for row in slice_verification_rows})
claim_boundary_row_count = len(claim_boundary_rows)
claim_boundary_pass_rows = sum(1 for row in claim_boundary_rows if row["claim_boundary_status"] == "pass")
blocker_closure_queue_rows = len(blocker_closure_rows)
blocker_closure_deferred_rows = sum(1 for row in blocker_closure_rows if row["execution_policy"].startswith("defer-"))
blocker_closure_approval_required_rows = sum(1 for row in blocker_closure_rows if row["approval_required"])
blocker_required_artifact_row_count = len(blocker_required_artifact_rows)
blocker_required_artifact_approval_rows = sum(1 for row in blocker_required_artifact_rows if row["approval_required"] == "1")
blocker_required_artifact_fixture_allowed_rows = sum(1 for row in blocker_required_artifact_rows if row["fixture_allowed"] == "1")
review_packet_row_count = len(review_packet_rows)
review_packet_file_count = sum(1 for row in review_packet_rows if (run_dir / row["packet_path"]).is_file())
review_packet_ready_rows = sum(1 for row in review_packet_rows if row["packet_ready"] == "1")
review_packet_blocked_slice_rows = sum(1 for row in review_packet_rows if row["slice_current_merge_ready"] == "0")
acceptance_evidence_row_count = len(acceptance_evidence_rows)
acceptance_evidence_ready_rows = sum(1 for row in acceptance_evidence_rows if row["acceptance_ready"] == "1")
acceptance_evidence_blocked_rows = acceptance_evidence_row_count - acceptance_evidence_ready_rows
acceptance_evidence_tests_only_rows = sum(1 for row in acceptance_evidence_rows if row["tests_only_merge_condition"] == "1")
v56_replay_acceptance_evidence_row_count = len(v56_replay_acceptance_evidence_rows)
v56_replay_acceptance_evidence_ready_rows = sum(1 for row in v56_replay_acceptance_evidence_rows if row["acceptance_ready"] == "1")
v56_replay_acceptance_evidence_blocked_rows = (
    v56_replay_acceptance_evidence_row_count - v56_replay_acceptance_evidence_ready_rows
)
v56_replay_acceptance_evidence_tests_only_rows = sum(
    1 for row in v56_replay_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"
)
v56_replay_acceptance_evidence_fixture_allowed_rows = sum(
    1 for row in v56_replay_acceptance_evidence_rows if row["fixture_allowed"] == "1"
)
v56_replay_acceptance_evidence_approval_rows = sum(
    1 for row in v56_replay_acceptance_evidence_rows if row["approval_required"] == "1"
)
v56_seed_dependency_blocker_rows_count = len(v56_seed_dependency_blocker_rows)
v56_seed_dependency_blocker_ready = as_int(v56_contract, "v56_seed_dependency_blocker_ready")
v56_missing_seed_artifact_rows = as_int(v56_contract, "missing_seed_artifact_rows")
v56_missing_v45_seed_artifact_rows = as_int(v56_contract, "missing_v45_seed_artifact_rows")
v56_missing_seed_network_or_download_approval_required = as_int(v56_contract, "network_or_download_approval_required")
de_30b70b_acceptance_evidence_row_count = len(de_30b70b_acceptance_evidence_rows)
de_30b70b_acceptance_evidence_ready_rows = sum(1 for row in de_30b70b_acceptance_evidence_rows if row["acceptance_ready"] == "1")
de_30b70b_acceptance_evidence_blocked_rows = (
    de_30b70b_acceptance_evidence_row_count - de_30b70b_acceptance_evidence_ready_rows
)
de_30b70b_acceptance_evidence_tests_only_rows = sum(
    1 for row in de_30b70b_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"
)
de_30b70b_acceptance_evidence_fixture_allowed_rows = sum(
    1 for row in de_30b70b_acceptance_evidence_rows if row["fixture_allowed"] == "1"
)
de_30b70b_acceptance_evidence_approval_rows = sum(
    1 for row in de_30b70b_acceptance_evidence_rows if row["approval_required"] == "1"
)
de_measured_registry_exclusion_row_count = len(de_measured_registry_exclusion_rows)
de_measured_registry_fixture_registry_rows = sum(
    1 for row in de_measured_registry_exclusion_rows if row["fixture_rows_in_measured_registry"] != "0"
)
de_measured_registry_admission_ready_rows = sum(
    1 for row in de_measured_registry_exclusion_rows if row["measured_registry_admission_ready"] == "1"
)
de_measured_registry_blocked_rows = sum(1 for row in de_measured_registry_exclusion_rows if row["status"] == "blocked")
v58_real_execution_readiness_row_count = len(v58_real_execution_readiness_rows)
v58_real_execution_ready_rows = sum(
    1 for row in v58_real_execution_readiness_rows if row["real_execution_ready"] == "1"
)
v58_real_execution_blocked_rows = sum(1 for row in v58_real_execution_readiness_rows if row["status"] == "blocked")
v58_real_execution_fixture_allowed_rows = sum(
    1 for row in v58_real_execution_readiness_rows if row["fixture_allowed"] == "1"
)
v59_one_command_acceptance_evidence_row_count = len(v59_one_command_acceptance_evidence_rows)
v59_one_command_acceptance_evidence_ready_rows = sum(1 for row in v59_one_command_acceptance_evidence_rows if row["acceptance_ready"] == "1")
v59_one_command_acceptance_evidence_blocked_rows = (
    v59_one_command_acceptance_evidence_row_count - v59_one_command_acceptance_evidence_ready_rows
)
v59_one_command_acceptance_evidence_tests_only_rows = sum(
    1 for row in v59_one_command_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"
)
v59_one_command_acceptance_evidence_fixture_allowed_rows = sum(
    1 for row in v59_one_command_acceptance_evidence_rows if row["fixture_allowed"] == "1"
)
v59_one_command_acceptance_evidence_approval_rows = sum(
    1 for row in v59_one_command_acceptance_evidence_rows if row["approval_required"] == "1"
)
blocker_closure_packet_rows = len(blocker_packet_rows)
blocker_closure_packet_files = sum(1 for row in blocker_packet_rows if (run_dir / row["packet_path"]).is_file())
blocker_closure_packet_ready_rows = sum(1 for row in blocker_packet_rows if row["packet_ready"] == "1")
blocker_closure_packet_approval_rows = sum(1 for row in blocker_packet_rows if "required" in row["approval_required"])
execution_lock_row_count = len(execution_lock_rows)
execution_lock_active_rows = sum(1 for row in execution_lock_rows if row["status"] == "locked")
scope_drift_allowed = 0
new_scaffold_default_allowed = 0
external_return_template_row_count = len(external_return_template_rows)
external_return_template_files = sum(1 for row in external_return_template_rows if (run_dir / row["template_path"]).is_file())
external_return_template_ready_rows = sum(1 for row in external_return_template_rows if row["template_ready"] == "1")
external_return_template_fixture_allowed_rows = sum(1 for row in external_return_template_rows if row["fixture_allowed"] == "1")
external_return_template_approval_rows = sum(1 for row in external_return_template_rows if row["approval_required"] == "1")

summary = {
    "v1_0_pm_pr_claim_slice_gate_ready": str(plan_ready),
    "recommended_pr_slice_rows": str(len(slice_rows)),
    "merge_condition_defined_rows": str(merge_condition_defined_rows),
    "merge_gate_rows": str(len(gate_rows)),
    "claim_boundary_pass_rows": str(claim_pass_rows),
    "replay_artifact_pass_rows": str(replay_pass_rows),
    "blocker_false_positive_pass_rows": str(blocker_pass_rows),
    "current_merge_ready_rows": str(ready_rows),
    "current_blocked_rows": str(blocked_rows),
    "pm_roadmap_requirement_rows": str(len(pm_roadmap_rows)),
    "pm_roadmap_ready_rows": str(pm_ready_rows),
    "pm_roadmap_blocked_rows": str(pm_blocked_rows),
    "pm_roadmap_milestone_rows": str(pm_roadmap_milestone_row_count),
    "pm_roadmap_milestone_ready_rows": str(pm_roadmap_milestone_ready_rows),
    "pm_roadmap_milestone_blocked_rows": str(pm_roadmap_milestone_blocked_rows),
    "pm_foundation_ready": str(pm_foundation_ready),
    "v53_foundation_freeze_certificate_rows": v53t.get("foundation_freeze_certificate_rows", "0"),
    "v53_foundation_machine_freeze_ready": v53t.get("foundation_machine_freeze_ready", "0"),
    "v53_foundation_query_span_binding_audit_ready": v53t.get("foundation_query_span_binding_audit_ready", "0"),
    "v53_foundation_query_span_binding_audit_rows": v53t.get("foundation_query_span_binding_audit_rows", "0"),
    "v53_foundation_query_span_binding_pass_rows": v53t.get("foundation_query_span_binding_pass_rows", "0"),
    "v53_foundation_direct_pinned_manifest_ready": v53t.get("foundation_direct_pinned_manifest_ready", "0"),
    "v53_foundation_direct_repo_manifest_rows": v53t.get("foundation_direct_repo_manifest_rows", "0"),
    "v53_foundation_direct_file_manifest_rows": v53t.get("foundation_direct_file_manifest_rows", "0"),
    "v53_foundation_direct_content_snapshot_rows": v53t.get("foundation_direct_content_snapshot_rows", "0"),
    "v53_negative_abstain_rows": v53t.get("negative_abstain_rows", "0"),
    "v53_unsupported_control_rows": v53t.get("unsupported_control_rows", "0"),
    "v53_ambiguous_control_rows": v53t.get("ambiguous_control_rows", "0"),
    "v53_missing_specific_control_rows": v53t.get("missing_specific_control_rows", "0"),
    "v53_doc_code_conflict_rows": v53t.get("doc_code_conflict_rows", "0"),
    "v53_pm_acceptance_evidence_rows": v53t.get("pm_acceptance_evidence_rows", "0"),
    "v53_pm_acceptance_evidence_ready_rows": v53t.get("pm_acceptance_evidence_ready_rows", "0"),
    "v53_pm_acceptance_evidence_tests_only_rows": v53t.get("pm_acceptance_evidence_tests_only_rows", "0"),
    "v53_v1_exit_criteria_rows": v53t.get("v1_exit_criteria_rows", "0"),
    "v53_v1_exit_criteria_ready_rows": v53t.get("v1_exit_criteria_ready_rows", "0"),
    "v53_v1_exit_criteria_blocked_rows": v53t.get("v1_exit_criteria_blocked_rows", "0"),
    "v53_v1_exit_machine_foundation_ready": v53t.get("v1_exit_machine_foundation_ready", "0"),
    "h10_real_label_acceptance_evidence_rows": h10_pm.get("h10_real_label_acceptance_evidence_rows", "0"),
    "h10_real_label_acceptance_evidence_ready_rows": h10_pm.get("h10_real_label_acceptance_evidence_ready_rows", "0"),
    "h10_real_label_acceptance_evidence_promotion_ready_rows": h10_pm.get("h10_real_label_acceptance_evidence_promotion_ready_rows", "0"),
    "h10_real_label_acceptance_evidence_tests_only_rows": h10_pm.get("h10_real_label_acceptance_evidence_tests_only_rows", "0"),
    "h10_accepted_query_rows_declared": h10_pm.get("accepted_query_rows_declared", "0"),
    "h10_accepted_label_rows": h10_pm.get("accepted_label_rows", "0"),
    "h10_accepted_coherent_wrong_key_labels": h10_pm.get("accepted_coherent_wrong_key_labels", "0"),
    "h10_accepted_chunk_exact_labels": h10_pm.get("accepted_chunk_exact_labels", "0"),
    "h10_accepted_near_miss_labels": h10_pm.get("accepted_near_miss_labels", "0"),
    "h10_accepted_missing_query_labels": h10_pm.get("accepted_missing_query_labels", "0"),
    "h10_accepted_source_provenance_labels": h10_pm.get("accepted_source_provenance_labels", "0"),
    "h10_real_label_acceptance_evidence_coverage_field_rows": str(h10_acceptance_evidence_coverage_field_rows),
    "h10_real_label_acceptance_evidence_zero_accepted_rows": str(h10_acceptance_evidence_zero_accepted_rows),
    "h10_real_label_acceptance_evidence_coverage_blocked_rows": str(h10_acceptance_evidence_label_coverage_blocked_rows),
    "h10_real_label_acceptance_evidence_source_verified_blocked_rows": str(h10_acceptance_evidence_source_verified_blocked_rows),
    "pm_pr_slice_file_rows": str(slice_file_row_count),
    "pm_pr_slice_file_existing_rows": str(slice_file_existing_rows),
    "pm_pr_slices_with_file_rows": str(slice_with_file_rows),
    "pm_pr_slice_verification_rows": str(slice_verification_row_count),
    "pm_pr_slices_with_verification_rows": str(slice_with_verification_rows),
    "pm_pr_claim_boundary_rows": str(claim_boundary_row_count),
    "pm_pr_claim_boundary_pass_rows": str(claim_boundary_pass_rows),
    "pm_pr_review_packet_rows": str(review_packet_row_count),
    "pm_pr_review_packet_files": str(review_packet_file_count),
    "pm_pr_review_packet_ready_rows": str(review_packet_ready_rows),
    "pm_pr_review_packet_blocked_slice_rows": str(review_packet_blocked_slice_rows),
    "pm_pr_acceptance_evidence_rows": str(acceptance_evidence_row_count),
    "pm_pr_acceptance_evidence_ready_rows": str(acceptance_evidence_ready_rows),
    "pm_pr_acceptance_evidence_blocked_rows": str(acceptance_evidence_blocked_rows),
    "pm_pr_acceptance_evidence_tests_only_rows": str(acceptance_evidence_tests_only_rows),
    "v56_replay_acceptance_evidence_rows": str(v56_replay_acceptance_evidence_row_count),
    "v56_replay_acceptance_evidence_ready_rows": str(v56_replay_acceptance_evidence_ready_rows),
    "v56_replay_acceptance_evidence_blocked_rows": str(v56_replay_acceptance_evidence_blocked_rows),
    "v56_replay_acceptance_evidence_tests_only_rows": str(v56_replay_acceptance_evidence_tests_only_rows),
    "v56_replay_acceptance_evidence_fixture_allowed_rows": str(v56_replay_acceptance_evidence_fixture_allowed_rows),
    "v56_replay_acceptance_evidence_approval_rows": str(v56_replay_acceptance_evidence_approval_rows),
    "v56_seed_dependency_blocker_ready": str(v56_seed_dependency_blocker_ready),
    "v56_seed_dependency_blocker_rows": str(v56_seed_dependency_blocker_rows_count),
    "v56_missing_seed_artifact_rows": str(v56_missing_seed_artifact_rows),
    "v56_missing_v45_seed_artifact_rows": str(v56_missing_v45_seed_artifact_rows),
    "v56_missing_seed_network_or_download_approval_required": str(v56_missing_seed_network_or_download_approval_required),
    "de_30b70b_acceptance_evidence_rows": str(de_30b70b_acceptance_evidence_row_count),
    "de_30b70b_acceptance_evidence_ready_rows": str(de_30b70b_acceptance_evidence_ready_rows),
    "de_30b70b_acceptance_evidence_blocked_rows": str(de_30b70b_acceptance_evidence_blocked_rows),
    "de_30b70b_acceptance_evidence_tests_only_rows": str(de_30b70b_acceptance_evidence_tests_only_rows),
    "de_30b70b_acceptance_evidence_fixture_allowed_rows": str(de_30b70b_acceptance_evidence_fixture_allowed_rows),
    "de_30b70b_acceptance_evidence_approval_rows": str(de_30b70b_acceptance_evidence_approval_rows),
    "de_measured_registry_exclusion_rows": str(de_measured_registry_exclusion_row_count),
    "de_measured_registry_fixture_registry_rows": str(de_measured_registry_fixture_registry_rows),
    "de_measured_registry_admission_ready_rows": str(de_measured_registry_admission_ready_rows),
    "de_measured_registry_blocked_rows": str(de_measured_registry_blocked_rows),
    "v58_real_execution_readiness_rows": str(v58_real_execution_readiness_row_count),
    "v58_real_execution_ready_rows": str(v58_real_execution_ready_rows),
    "v58_real_execution_blocked_rows": str(v58_real_execution_blocked_rows),
    "v58_real_execution_fixture_allowed_rows": str(v58_real_execution_fixture_allowed_rows),
    "v59_one_command_acceptance_evidence_rows": str(v59_one_command_acceptance_evidence_row_count),
    "v59_one_command_acceptance_evidence_ready_rows": str(v59_one_command_acceptance_evidence_ready_rows),
    "v59_one_command_acceptance_evidence_blocked_rows": str(v59_one_command_acceptance_evidence_blocked_rows),
    "v59_one_command_acceptance_evidence_tests_only_rows": str(v59_one_command_acceptance_evidence_tests_only_rows),
    "v59_one_command_acceptance_evidence_fixture_allowed_rows": str(v59_one_command_acceptance_evidence_fixture_allowed_rows),
    "v59_one_command_acceptance_evidence_approval_rows": str(v59_one_command_acceptance_evidence_approval_rows),
    "pm_blocker_closure_queue_rows": str(blocker_closure_queue_rows),
    "pm_blocker_closure_deferred_rows": str(blocker_closure_deferred_rows),
    "pm_blocker_closure_approval_required_rows": str(blocker_closure_approval_required_rows),
    "pm_blocker_closure_packet_rows": str(blocker_closure_packet_rows),
    "pm_blocker_closure_packet_files": str(blocker_closure_packet_files),
    "pm_blocker_closure_packet_ready_rows": str(blocker_closure_packet_ready_rows),
    "pm_blocker_closure_packet_approval_rows": str(blocker_closure_packet_approval_rows),
    "pm_blocker_required_artifact_rows": str(blocker_required_artifact_row_count),
    "pm_blocker_required_artifact_approval_rows": str(blocker_required_artifact_approval_rows),
    "pm_blocker_required_artifact_fixture_allowed_rows": str(blocker_required_artifact_fixture_allowed_rows),
    "pm_execution_lock_rows": str(execution_lock_row_count),
    "pm_execution_lock_active_rows": str(execution_lock_active_rows),
    "pm_scope_drift_allowed": str(scope_drift_allowed),
    "pm_new_scaffold_default_allowed": str(new_scaffold_default_allowed),
    "pm_external_return_template_rows": str(external_return_template_row_count),
    "pm_external_return_template_files": str(external_return_template_files),
    "pm_external_return_template_ready_rows": str(external_return_template_ready_rows),
    "pm_external_return_template_fixture_allowed_rows": str(external_return_template_fixture_allowed_rows),
    "pm_external_return_template_approval_rows": str(external_return_template_approval_rows),
    "pm_pr_normalization_rows": str(pm_pr_normalization_row_count),
    "pm_pr_normalization_split_required_rows": str(pm_pr_normalization_split_required_rows),
    "pm_pr_normalization_tests_only_rows": str(pm_pr_normalization_tests_only_rows),
    "pm_pr_title_body_rows": str(pm_pr_title_body_row_count),
    "pm_pr_title_body_rewrite_ready": str(pm_pr_title_body_rewrite_ready),
    "pm_pr_title_body_split_required_rows": str(pm_pr_title_body_split_required_rows),
    "pm_ready_semantic_rows": str(pm_ready_semantic_row_count),
    "pm_ready_semantic_typed_rows": str(pm_ready_semantic_typed_rows),
    "pm_ready_semantic_contract_ready_rows": str(pm_ready_semantic_contract_ready_rows),
    "pm_ready_semantic_fixture_execution_ready_rows": str(pm_ready_semantic_fixture_execution_ready_rows),
    "pm_ready_semantic_real_model_ready_rows": str(pm_ready_semantic_real_model_ready_rows),
    "pm_ready_semantic_release_ready_rows": str(pm_ready_semantic_release_ready_rows),
    "pm_ready_semantic_logical_100b_contract_fixture_ready": str(pm_ready_semantic_logical_100b_contract_fixture_ready),
    "pm_ready_semantic_real_100b_inference_ready": str(pm_ready_semantic_real_100b_inference_ready),
    "pm_retrieval_leakage_guard_rows": str(pm_retrieval_leakage_guard_row_count),
    "pm_retrieval_leakage_guard_pass_rows": str(pm_retrieval_leakage_guard_pass_rows),
    "pm_retrieval_leakage_guard_blocked_rows": str(pm_retrieval_leakage_guard_blocked_rows),
    "draft_pr_2_split_required": "1",
    "tests_only_merge_condition_rows": "0",
    "full_v1_release_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

(run_dir / "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md").write_text(
    "# v1.0 PM PR Claim Slice Gate Boundary\n\n"
    "This gate turns the PM request to split draft PR #2 into machine-readable review slices. It does not merge, push, or publish anything.\n\n"
    f"- recommended_pr_slice_rows={len(slice_rows)}\n"
    f"- merge_condition_defined_rows={merge_condition_defined_rows}\n"
    f"- merge_gate_rows={len(gate_rows)}\n"
    f"- current_merge_ready_rows={ready_rows}\n"
    f"- current_blocked_rows={blocked_rows}\n"
    f"- pm_roadmap_requirement_rows={len(pm_roadmap_rows)}\n"
    f"- pm_roadmap_ready_rows={pm_ready_rows}\n"
    f"- pm_roadmap_blocked_rows={pm_blocked_rows}\n"
    f"- pm_roadmap_milestone_rows={pm_roadmap_milestone_row_count}\n"
    f"- pm_roadmap_milestone_ready_rows={pm_roadmap_milestone_ready_rows}\n"
    f"- pm_roadmap_milestone_blocked_rows={pm_roadmap_milestone_blocked_rows}\n"
    f"- pm_foundation_ready={pm_foundation_ready}\n"
    f"- v53_foundation_freeze_certificate_rows={v53t.get('foundation_freeze_certificate_rows', '0')}\n"
    f"- v53_foundation_machine_freeze_ready={v53t.get('foundation_machine_freeze_ready', '0')}\n"
    f"- v53_foundation_query_span_binding_audit_ready={v53t.get('foundation_query_span_binding_audit_ready', '0')}\n"
    f"- v53_foundation_query_span_binding_audit_rows={v53t.get('foundation_query_span_binding_audit_rows', '0')}\n"
    f"- v53_foundation_query_span_binding_pass_rows={v53t.get('foundation_query_span_binding_pass_rows', '0')}\n"
    f"- v53_foundation_direct_pinned_manifest_ready={v53t.get('foundation_direct_pinned_manifest_ready', '0')}\n"
    f"- v53_foundation_direct_repo_manifest_rows={v53t.get('foundation_direct_repo_manifest_rows', '0')}\n"
    f"- v53_foundation_direct_file_manifest_rows={v53t.get('foundation_direct_file_manifest_rows', '0')}\n"
    f"- v53_foundation_direct_content_snapshot_rows={v53t.get('foundation_direct_content_snapshot_rows', '0')}\n"
    f"- v53_negative_abstain_rows={v53t.get('negative_abstain_rows', '0')}\n"
    f"- v53_unsupported_control_rows={v53t.get('unsupported_control_rows', '0')}\n"
    f"- v53_ambiguous_control_rows={v53t.get('ambiguous_control_rows', '0')}\n"
    f"- v53_missing_specific_control_rows={v53t.get('missing_specific_control_rows', '0')}\n"
    f"- v53_doc_code_conflict_rows={v53t.get('doc_code_conflict_rows', '0')}\n"
    f"- v53_pm_acceptance_evidence_rows={v53t.get('pm_acceptance_evidence_rows', '0')}\n"
    f"- v53_pm_acceptance_evidence_ready_rows={v53t.get('pm_acceptance_evidence_ready_rows', '0')}\n"
    f"- v53_pm_acceptance_evidence_tests_only_rows={v53t.get('pm_acceptance_evidence_tests_only_rows', '0')}\n"
    f"- v53_v1_exit_criteria_rows={v53t.get('v1_exit_criteria_rows', '0')}\n"
    f"- v53_v1_exit_criteria_ready_rows={v53t.get('v1_exit_criteria_ready_rows', '0')}\n"
    f"- v53_v1_exit_criteria_blocked_rows={v53t.get('v1_exit_criteria_blocked_rows', '0')}\n"
    f"- v53_v1_exit_machine_foundation_ready={v53t.get('v1_exit_machine_foundation_ready', '0')}\n"
    f"- h10_real_label_acceptance_evidence_rows={h10_pm.get('h10_real_label_acceptance_evidence_rows', '0')}\n"
    f"- h10_real_label_acceptance_evidence_ready_rows={h10_pm.get('h10_real_label_acceptance_evidence_ready_rows', '0')}\n"
    f"- h10_real_label_acceptance_evidence_promotion_ready_rows={h10_pm.get('h10_real_label_acceptance_evidence_promotion_ready_rows', '0')}\n"
    f"- h10_real_label_acceptance_evidence_tests_only_rows={h10_pm.get('h10_real_label_acceptance_evidence_tests_only_rows', '0')}\n"
    f"- h10_accepted_query_rows_declared={h10_pm.get('accepted_query_rows_declared', '0')}\n"
    f"- h10_accepted_label_rows={h10_pm.get('accepted_label_rows', '0')}\n"
    f"- h10_accepted_coherent_wrong_key_labels={h10_pm.get('accepted_coherent_wrong_key_labels', '0')}\n"
    f"- h10_accepted_chunk_exact_labels={h10_pm.get('accepted_chunk_exact_labels', '0')}\n"
    f"- h10_accepted_near_miss_labels={h10_pm.get('accepted_near_miss_labels', '0')}\n"
    f"- h10_accepted_missing_query_labels={h10_pm.get('accepted_missing_query_labels', '0')}\n"
    f"- h10_accepted_source_provenance_labels={h10_pm.get('accepted_source_provenance_labels', '0')}\n"
    f"- h10_real_label_acceptance_evidence_coverage_field_rows={h10_acceptance_evidence_coverage_field_rows}\n"
    f"- h10_real_label_acceptance_evidence_zero_accepted_rows={h10_acceptance_evidence_zero_accepted_rows}\n"
    f"- h10_real_label_acceptance_evidence_coverage_blocked_rows={h10_acceptance_evidence_label_coverage_blocked_rows}\n"
    f"- h10_real_label_acceptance_evidence_source_verified_blocked_rows={h10_acceptance_evidence_source_verified_blocked_rows}\n"
    f"- pm_pr_slice_file_rows={slice_file_row_count}\n"
    f"- pm_pr_slice_verification_rows={slice_verification_row_count}\n"
    f"- pm_pr_claim_boundary_rows={claim_boundary_row_count}\n"
    f"- pm_pr_review_packet_rows={review_packet_row_count}\n"
    f"- pm_pr_review_packet_files={review_packet_file_count}\n"
    f"- pm_pr_acceptance_evidence_rows={acceptance_evidence_row_count}\n"
    f"- pm_pr_acceptance_evidence_ready_rows={acceptance_evidence_ready_rows}\n"
    f"- pm_pr_acceptance_evidence_tests_only_rows={acceptance_evidence_tests_only_rows}\n"
    f"- v56_replay_acceptance_evidence_rows={v56_replay_acceptance_evidence_row_count}\n"
    f"- v56_replay_acceptance_evidence_ready_rows={v56_replay_acceptance_evidence_ready_rows}\n"
    f"- v56_replay_acceptance_evidence_blocked_rows={v56_replay_acceptance_evidence_blocked_rows}\n"
    f"- v56_replay_acceptance_evidence_tests_only_rows={v56_replay_acceptance_evidence_tests_only_rows}\n"
    f"- v56_seed_dependency_blocker_ready={v56_seed_dependency_blocker_ready}\n"
    f"- v56_seed_dependency_blocker_rows={v56_seed_dependency_blocker_rows_count}\n"
    f"- v56_missing_seed_artifact_rows={v56_missing_seed_artifact_rows}\n"
    f"- de_30b70b_acceptance_evidence_rows={de_30b70b_acceptance_evidence_row_count}\n"
    f"- de_30b70b_acceptance_evidence_ready_rows={de_30b70b_acceptance_evidence_ready_rows}\n"
    f"- de_30b70b_acceptance_evidence_blocked_rows={de_30b70b_acceptance_evidence_blocked_rows}\n"
    f"- de_30b70b_acceptance_evidence_tests_only_rows={de_30b70b_acceptance_evidence_tests_only_rows}\n"
    f"- de_measured_registry_exclusion_rows={de_measured_registry_exclusion_row_count}\n"
    f"- de_measured_registry_fixture_registry_rows={de_measured_registry_fixture_registry_rows}\n"
    f"- de_measured_registry_admission_ready_rows={de_measured_registry_admission_ready_rows}\n"
    f"- v58_real_execution_readiness_rows={v58_real_execution_readiness_row_count}\n"
    f"- v58_real_execution_ready_rows={v58_real_execution_ready_rows}\n"
    f"- v58_real_execution_blocked_rows={v58_real_execution_blocked_rows}\n"
    f"- v59_one_command_acceptance_evidence_rows={v59_one_command_acceptance_evidence_row_count}\n"
    f"- v59_one_command_acceptance_evidence_ready_rows={v59_one_command_acceptance_evidence_ready_rows}\n"
    f"- v59_one_command_acceptance_evidence_blocked_rows={v59_one_command_acceptance_evidence_blocked_rows}\n"
    f"- v59_one_command_acceptance_evidence_tests_only_rows={v59_one_command_acceptance_evidence_tests_only_rows}\n"
    f"- pm_blocker_closure_queue_rows={blocker_closure_queue_rows}\n"
    f"- pm_blocker_closure_packet_rows={blocker_closure_packet_rows}\n"
    f"- pm_blocker_closure_packet_files={blocker_closure_packet_files}\n"
    f"- pm_blocker_required_artifact_rows={blocker_required_artifact_row_count}\n"
    f"- pm_execution_lock_rows={execution_lock_row_count}\n"
    f"- pm_scope_drift_allowed={scope_drift_allowed}\n"
    f"- pm_new_scaffold_default_allowed={new_scaffold_default_allowed}\n"
    f"- pm_external_return_template_rows={external_return_template_row_count}\n"
    f"- pm_external_return_template_files={external_return_template_files}\n"
    f"- pm_pr_normalization_rows={pm_pr_normalization_row_count}\n"
    f"- pm_pr_normalization_split_required_rows={pm_pr_normalization_split_required_rows}\n"
    f"- pm_pr_normalization_tests_only_rows={pm_pr_normalization_tests_only_rows}\n"
    f"- pm_pr_title_body_rows={pm_pr_title_body_row_count}\n"
    f"- pm_pr_title_body_rewrite_ready={pm_pr_title_body_rewrite_ready}\n"
    f"- pm_ready_semantic_rows={pm_ready_semantic_row_count}\n"
    f"- pm_ready_semantic_real_model_ready_rows={pm_ready_semantic_real_model_ready_rows}\n"
    f"- pm_ready_semantic_release_ready_rows={pm_ready_semantic_release_ready_rows}\n"
    f"- pm_ready_semantic_logical_100b_contract_fixture_ready={pm_ready_semantic_logical_100b_contract_fixture_ready}\n"
    f"- pm_ready_semantic_real_100b_inference_ready={pm_ready_semantic_real_100b_inference_ready}\n"
    f"- pm_retrieval_leakage_guard_rows={pm_retrieval_leakage_guard_row_count}\n"
    f"- pm_retrieval_leakage_guard_pass_rows={pm_retrieval_leakage_guard_pass_rows}\n"
    f"- pm_retrieval_leakage_guard_blocked_rows={pm_retrieval_leakage_guard_blocked_rows}\n"
    "- tests_only_merge_condition_rows=0\n"
    "- draft_pr_2_split_required=1\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: PR slice plan and merge-gate readiness ledger for claim-bound v1.0 review.\n\n"
    "Blocked wording: draft PR #2 ready as one review unit, tests-only merge readiness, v1.0 release readiness, public comparison win, or production readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v1-0-pm-pr-claim-slice-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v1_0_pm_pr_claim_slice_gate_ready": plan_ready,
    "recommended_pr_slice_rows": len(slice_rows),
    "merge_gate_rows": len(gate_rows),
    "current_merge_ready_rows": ready_rows,
    "current_blocked_rows": blocked_rows,
    "pm_roadmap_requirement_rows": len(pm_roadmap_rows),
    "pm_roadmap_ready_rows": pm_ready_rows,
    "pm_roadmap_blocked_rows": pm_blocked_rows,
    "pm_roadmap_milestone_rows": pm_roadmap_milestone_row_count,
    "pm_roadmap_milestone_ready_rows": pm_roadmap_milestone_ready_rows,
    "pm_roadmap_milestone_blocked_rows": pm_roadmap_milestone_blocked_rows,
    "pm_foundation_ready": pm_foundation_ready,
    "v53_foundation_freeze_certificate_rows": as_int(v53t, "foundation_freeze_certificate_rows"),
    "v53_foundation_machine_freeze_ready": as_int(v53t, "foundation_machine_freeze_ready"),
    "v53_foundation_query_span_binding_audit_ready": as_int(v53t, "foundation_query_span_binding_audit_ready"),
    "v53_foundation_query_span_binding_audit_rows": as_int(v53t, "foundation_query_span_binding_audit_rows"),
    "v53_foundation_query_span_binding_pass_rows": as_int(v53t, "foundation_query_span_binding_pass_rows"),
    "v53_foundation_direct_pinned_manifest_ready": as_int(v53t, "foundation_direct_pinned_manifest_ready"),
    "v53_foundation_direct_repo_manifest_rows": as_int(v53t, "foundation_direct_repo_manifest_rows"),
    "v53_foundation_direct_file_manifest_rows": as_int(v53t, "foundation_direct_file_manifest_rows"),
    "v53_foundation_direct_content_snapshot_rows": as_int(v53t, "foundation_direct_content_snapshot_rows"),
    "v53_negative_abstain_rows": as_int(v53t, "negative_abstain_rows"),
    "v53_unsupported_control_rows": as_int(v53t, "unsupported_control_rows"),
    "v53_ambiguous_control_rows": as_int(v53t, "ambiguous_control_rows"),
    "v53_missing_specific_control_rows": as_int(v53t, "missing_specific_control_rows"),
    "v53_doc_code_conflict_rows": as_int(v53t, "doc_code_conflict_rows"),
    "v53_pm_acceptance_evidence_rows": as_int(v53t, "pm_acceptance_evidence_rows"),
    "v53_pm_acceptance_evidence_ready_rows": as_int(v53t, "pm_acceptance_evidence_ready_rows"),
    "v53_pm_acceptance_evidence_tests_only_rows": as_int(v53t, "pm_acceptance_evidence_tests_only_rows"),
    "v53_v1_exit_criteria_rows": as_int(v53t, "v1_exit_criteria_rows"),
    "v53_v1_exit_criteria_ready_rows": as_int(v53t, "v1_exit_criteria_ready_rows"),
    "v53_v1_exit_criteria_blocked_rows": as_int(v53t, "v1_exit_criteria_blocked_rows"),
    "v53_v1_exit_machine_foundation_ready": as_int(v53t, "v1_exit_machine_foundation_ready"),
    "v53_v1_exit_criteria_rows_sha256": sha256(run_dir / "source_v53t/complete_source_v1_exit_criteria_rows.csv") if v53t_direct_copied.get("complete_source_v1_exit_criteria_rows.csv") else "",
    "h10_real_label_acceptance_evidence_rows": as_int(h10_pm, "h10_real_label_acceptance_evidence_rows"),
    "h10_real_label_acceptance_evidence_ready_rows": as_int(h10_pm, "h10_real_label_acceptance_evidence_ready_rows"),
    "h10_real_label_acceptance_evidence_promotion_ready_rows": as_int(h10_pm, "h10_real_label_acceptance_evidence_promotion_ready_rows"),
    "h10_real_label_acceptance_evidence_tests_only_rows": as_int(h10_pm, "h10_real_label_acceptance_evidence_tests_only_rows"),
    "h10_accepted_query_rows_declared": as_int(h10_pm, "accepted_query_rows_declared"),
    "h10_accepted_label_rows": as_int(h10_pm, "accepted_label_rows"),
    "h10_accepted_coherent_wrong_key_labels": as_int(h10_pm, "accepted_coherent_wrong_key_labels"),
    "h10_accepted_chunk_exact_labels": as_int(h10_pm, "accepted_chunk_exact_labels"),
    "h10_accepted_near_miss_labels": as_int(h10_pm, "accepted_near_miss_labels"),
    "h10_accepted_missing_query_labels": as_int(h10_pm, "accepted_missing_query_labels"),
    "h10_accepted_source_provenance_labels": as_int(h10_pm, "accepted_source_provenance_labels"),
    "h10_real_label_acceptance_evidence_coverage_field_rows": h10_acceptance_evidence_coverage_field_rows,
    "h10_real_label_acceptance_evidence_zero_accepted_rows": h10_acceptance_evidence_zero_accepted_rows,
    "h10_real_label_acceptance_evidence_coverage_blocked_rows": h10_acceptance_evidence_label_coverage_blocked_rows,
    "h10_real_label_acceptance_evidence_source_verified_blocked_rows": h10_acceptance_evidence_source_verified_blocked_rows,
    "pm_pr_slice_file_rows": slice_file_row_count,
    "pm_pr_slice_file_existing_rows": slice_file_existing_rows,
    "pm_pr_slice_verification_rows": slice_verification_row_count,
    "pm_pr_claim_boundary_rows": claim_boundary_row_count,
    "pm_pr_claim_boundary_pass_rows": claim_boundary_pass_rows,
    "pm_pr_review_packet_rows": review_packet_row_count,
    "pm_pr_review_packet_files": review_packet_file_count,
    "pm_pr_review_packet_ready_rows": review_packet_ready_rows,
    "pm_pr_review_packet_blocked_slice_rows": review_packet_blocked_slice_rows,
    "pm_pr_acceptance_evidence_rows": acceptance_evidence_row_count,
    "pm_pr_acceptance_evidence_ready_rows": acceptance_evidence_ready_rows,
    "pm_pr_acceptance_evidence_blocked_rows": acceptance_evidence_blocked_rows,
    "pm_pr_acceptance_evidence_tests_only_rows": acceptance_evidence_tests_only_rows,
    "v56_replay_acceptance_evidence_rows": v56_replay_acceptance_evidence_row_count,
    "v56_replay_acceptance_evidence_ready_rows": v56_replay_acceptance_evidence_ready_rows,
    "v56_replay_acceptance_evidence_blocked_rows": v56_replay_acceptance_evidence_blocked_rows,
    "v56_replay_acceptance_evidence_tests_only_rows": v56_replay_acceptance_evidence_tests_only_rows,
    "v56_replay_acceptance_evidence_fixture_allowed_rows": v56_replay_acceptance_evidence_fixture_allowed_rows,
    "v56_replay_acceptance_evidence_approval_rows": v56_replay_acceptance_evidence_approval_rows,
    "v56_seed_dependency_blocker_ready": v56_seed_dependency_blocker_ready,
    "v56_seed_dependency_blocker_rows": v56_seed_dependency_blocker_rows_count,
    "v56_missing_seed_artifact_rows": v56_missing_seed_artifact_rows,
    "v56_missing_v45_seed_artifact_rows": v56_missing_v45_seed_artifact_rows,
    "v56_missing_seed_network_or_download_approval_required": v56_missing_seed_network_or_download_approval_required,
    "v56_seed_dependency_blocker_rows_sha256": sha256(run_dir / "source_v56/v56_seed_dependency_blocker_rows.csv") if v56_seed_dependency_blocker_copied else "",
    "de_30b70b_acceptance_evidence_rows": de_30b70b_acceptance_evidence_row_count,
    "de_30b70b_acceptance_evidence_ready_rows": de_30b70b_acceptance_evidence_ready_rows,
    "de_30b70b_acceptance_evidence_blocked_rows": de_30b70b_acceptance_evidence_blocked_rows,
    "de_30b70b_acceptance_evidence_tests_only_rows": de_30b70b_acceptance_evidence_tests_only_rows,
    "de_30b70b_acceptance_evidence_fixture_allowed_rows": de_30b70b_acceptance_evidence_fixture_allowed_rows,
    "de_30b70b_acceptance_evidence_approval_rows": de_30b70b_acceptance_evidence_approval_rows,
    "de_measured_registry_exclusion_rows": de_measured_registry_exclusion_row_count,
    "de_measured_registry_fixture_registry_rows": de_measured_registry_fixture_registry_rows,
    "de_measured_registry_admission_ready_rows": de_measured_registry_admission_ready_rows,
    "de_measured_registry_blocked_rows": de_measured_registry_blocked_rows,
    "v58_real_execution_readiness_rows": v58_real_execution_readiness_row_count,
    "v58_real_execution_ready_rows": v58_real_execution_ready_rows,
    "v58_real_execution_blocked_rows": v58_real_execution_blocked_rows,
    "v58_real_execution_fixture_allowed_rows": v58_real_execution_fixture_allowed_rows,
    "v59_one_command_acceptance_evidence_rows": v59_one_command_acceptance_evidence_row_count,
    "v59_one_command_acceptance_evidence_ready_rows": v59_one_command_acceptance_evidence_ready_rows,
    "v59_one_command_acceptance_evidence_blocked_rows": v59_one_command_acceptance_evidence_blocked_rows,
    "v59_one_command_acceptance_evidence_tests_only_rows": v59_one_command_acceptance_evidence_tests_only_rows,
    "v59_one_command_acceptance_evidence_fixture_allowed_rows": v59_one_command_acceptance_evidence_fixture_allowed_rows,
    "v59_one_command_acceptance_evidence_approval_rows": v59_one_command_acceptance_evidence_approval_rows,
    "pm_blocker_closure_queue_rows": blocker_closure_queue_rows,
    "pm_blocker_closure_deferred_rows": blocker_closure_deferred_rows,
    "pm_blocker_closure_packet_rows": blocker_closure_packet_rows,
    "pm_blocker_closure_packet_files": blocker_closure_packet_files,
    "pm_blocker_closure_packet_ready_rows": blocker_closure_packet_ready_rows,
    "pm_blocker_closure_packet_approval_rows": blocker_closure_packet_approval_rows,
    "pm_blocker_required_artifact_rows": blocker_required_artifact_row_count,
    "pm_blocker_required_artifact_fixture_allowed_rows": blocker_required_artifact_fixture_allowed_rows,
    "pm_execution_lock_rows": execution_lock_row_count,
    "pm_execution_lock_active_rows": execution_lock_active_rows,
    "pm_scope_drift_allowed": scope_drift_allowed,
    "pm_new_scaffold_default_allowed": new_scaffold_default_allowed,
    "pm_external_return_template_rows": external_return_template_row_count,
    "pm_external_return_template_files": external_return_template_files,
    "pm_external_return_template_ready_rows": external_return_template_ready_rows,
    "pm_external_return_template_fixture_allowed_rows": external_return_template_fixture_allowed_rows,
    "pm_external_return_template_approval_rows": external_return_template_approval_rows,
    "pm_pr_normalization_rows": pm_pr_normalization_row_count,
    "pm_pr_normalization_split_required_rows": pm_pr_normalization_split_required_rows,
    "pm_pr_normalization_tests_only_rows": pm_pr_normalization_tests_only_rows,
    "pm_pr_title_body_rows": pm_pr_title_body_row_count,
    "pm_pr_title_body_rewrite_ready": pm_pr_title_body_rewrite_ready,
    "pm_pr_title_body_split_required_rows": pm_pr_title_body_split_required_rows,
    "pm_ready_semantic_rows": pm_ready_semantic_row_count,
    "pm_ready_semantic_typed_rows": pm_ready_semantic_typed_rows,
    "pm_ready_semantic_contract_ready_rows": pm_ready_semantic_contract_ready_rows,
    "pm_ready_semantic_fixture_execution_ready_rows": pm_ready_semantic_fixture_execution_ready_rows,
    "pm_ready_semantic_real_model_ready_rows": pm_ready_semantic_real_model_ready_rows,
    "pm_ready_semantic_release_ready_rows": pm_ready_semantic_release_ready_rows,
    "pm_ready_semantic_logical_100b_contract_fixture_ready": pm_ready_semantic_logical_100b_contract_fixture_ready,
    "pm_ready_semantic_real_100b_inference_ready": pm_ready_semantic_real_100b_inference_ready,
    "pm_retrieval_leakage_guard_rows": pm_retrieval_leakage_guard_row_count,
    "pm_retrieval_leakage_guard_pass_rows": pm_retrieval_leakage_guard_pass_rows,
    "pm_retrieval_leakage_guard_blocked_rows": pm_retrieval_leakage_guard_blocked_rows,
    "slice_ids": slice_ids,
    "source_summary_rows_sha256": sha256(run_dir / "source_summary_rows.csv"),
    "pm_roadmap_requirement_rows_sha256": sha256(run_dir / "pm_roadmap_requirement_rows.csv"),
    "pm_roadmap_milestone_rows_sha256": sha256(run_dir / "pm_roadmap_milestone_rows.csv"),
    "pm_pr_claim_boundary_rows_sha256": sha256(run_dir / "pm_pr_claim_boundary_rows.csv"),
    "pm_pr_review_packet_rows_sha256": sha256(run_dir / "pm_pr_review_packet_rows.csv"),
    "pm_pr_acceptance_evidence_rows_sha256": sha256(run_dir / "pm_pr_acceptance_evidence_rows.csv"),
    "v56_replay_acceptance_evidence_rows_sha256": sha256(run_dir / "v56_replay_acceptance_evidence_rows.csv"),
    "de_30b70b_acceptance_evidence_rows_sha256": sha256(run_dir / "de_30b70b_acceptance_evidence_rows.csv"),
    "de_measured_registry_exclusion_rows_sha256": sha256(run_dir / "de_measured_registry_exclusion_rows.csv"),
    "v58_real_execution_readiness_rows_sha256": sha256(run_dir / "v58_real_execution_readiness_rows.csv"),
    "v59_one_command_acceptance_evidence_rows_sha256": sha256(run_dir / "v59_one_command_acceptance_evidence_rows.csv"),
    "h10_real_label_acceptance_evidence_rows_sha256": sha256(run_dir / "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv"),
    "pm_pr_slice_file_rows_sha256": sha256(run_dir / "pm_pr_slice_file_rows.csv"),
    "pm_pr_slice_verification_rows_sha256": sha256(run_dir / "pm_pr_slice_verification_rows.csv"),
    "pm_blocker_closure_queue_rows_sha256": sha256(run_dir / "pm_blocker_closure_queue_rows.csv"),
    "pm_blocker_closure_packet_rows_sha256": sha256(run_dir / "pm_blocker_closure_packet_rows.csv"),
    "pm_blocker_required_artifact_rows_sha256": sha256(run_dir / "pm_blocker_required_artifact_rows.csv"),
    "pm_execution_lock_rows_sha256": sha256(run_dir / "pm_execution_lock_rows.csv"),
    "pm_external_return_template_rows_sha256": sha256(run_dir / "pm_external_return_template_rows.csv"),
    "pm_pr_normalization_rows_sha256": sha256(run_dir / "pm_pr_normalization_rows.csv"),
    "pm_pr_title_body_rows_sha256": sha256(run_dir / "pm_pr_title_body_rows.csv"),
    "pm_ready_semantic_rows_sha256": sha256(run_dir / "pm_ready_semantic_rows.csv"),
    "pm_retrieval_leakage_guard_rows_sha256": sha256(run_dir / "pm_retrieval_leakage_guard_rows.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v1_0_pm_pr_claim_slice_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v1_0_pm_pr_claim_slice_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
