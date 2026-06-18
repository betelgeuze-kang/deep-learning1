#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v59e_one_command_pm_foundation_demo"
RUN_ID="${V59E_RUN_ID:-pm_foundation_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V53AP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ap_complete_source_abgh_same_query_measured.sh" >/dev/null
V53AQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh" >/dev/null
V54C_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v54c_complete_source_grounded_generation_1000.sh" >/dev/null
"$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def first_row(path):
    rows = read_csv(path)
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}")
    return rows[0]


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key, default="0"):
    return int(float(row.get(key, default) or default))


LOCAL_ABGH_SYSTEMS = {"A", "B", "G", "H"}
LOCAL_ABGH_SYSTEMS_TEXT = "A/B/G/H"
LOCAL_ABGH_QUERY_ROWS = 1000
LOCAL_ABGH_SYSTEM_ROWS = 4
LOCAL_ABGH_TOTAL_ROWS = LOCAL_ABGH_QUERY_ROWS * LOCAL_ABGH_SYSTEM_ROWS


def count_value(rows, key, value):
    return sum(1 for row in rows if row.get(key, "") == value)


def count_not_value(rows, key, value):
    return sum(1 for row in rows if row.get(key, "") != value)


def complete_query_system_contract(rows):
    by_query = {}
    for row in rows:
        by_query.setdefault(row.get("query_id", ""), set()).add(row.get("system_id", ""))
    by_query.pop("", None)
    return int(
        len(by_query) == LOCAL_ABGH_QUERY_ROWS
        and all(systems == LOCAL_ABGH_SYSTEMS for systems in by_query.values())
    )


def system_text(rows):
    systems = sorted({row.get("system_id", "") for row in rows if row.get("system_id", "")})
    return "/".join(systems)


def build_local_abgh_row_contract(stage, stage_dir, summary_row, ready_field, claim_boundary):
    answer_rows = read_csv(stage_dir / "abgh_answer_rows.csv")
    citation_rows = read_csv(stage_dir / "abgh_citation_rows.csv")
    evaluator_rows = read_csv(stage_dir / "abgh_evaluator_rows.csv")
    resource_rows = read_csv(stage_dir / "abgh_resource_rows.csv")
    answer_ids = {row["answer_id"] for row in answer_rows}
    citation_ids = {row["citation_id"] for row in citation_rows}
    resource_ids = {row["resource_row_id"] for row in resource_rows}
    evaluator_bound_rows = sum(
        1
        for row in evaluator_rows
        if row.get("answer_id") in answer_ids
        and row.get("citation_id") in citation_ids
        and row.get("resource_row_id") in resource_ids
    )
    answer_resource_bound_rows = sum(1 for row in answer_rows if row.get("resource_row_id") in resource_ids)
    same_query_row_contract = int(
        complete_query_system_contract(answer_rows)
        and complete_query_system_contract(citation_rows)
        and complete_query_system_contract(evaluator_rows)
        and complete_query_system_contract(resource_rows)
    )
    answer_eval_separate_rows = count_value(evaluator_rows, "answer_eval_separate", "1")
    citation_eval_separate_rows = count_value(evaluator_rows, "citation_eval_separate", "1")
    resource_eval_separate_rows = count_value(evaluator_rows, "resource_eval_separate", "1")
    resource_row_bound_rows = count_value(evaluator_rows, "resource_row_bound", "1")
    expected_answer_oracle_replay_zero_rows = count_value(evaluator_rows, "expected_answer_oracle_replay", "0")
    expected_answer_oracle_replay_any = count_not_value(evaluator_rows, "expected_answer_oracle_replay", "0")
    no_external_model_rows = count_value(resource_rows, "external_model_used", "0")
    no_external_network_rows = count_value(resource_rows, "external_network_used", "0")
    deterministic_source_span_adapter_execution_rows = count_value(resource_rows, "deterministic_source_span_adapter_execution", "1")
    actual_adapter_execution_ready_rows = count_value(resource_rows, "actual_adapter_execution_ready", "1")
    real_adapter_execution_ready_rows = count_value(resource_rows, "real_adapter_execution_ready", "1")
    real_system_performance_claim_ready_rows = count_value(evaluator_rows, "real_system_performance_claim_ready", "1")
    internal_real_adapter_metric_claim_ready_rows = count_value(evaluator_rows, "internal_real_adapter_metric_claim_ready", "1")
    public_real_system_performance_claim_ready_rows = count_value(evaluator_rows, "public_real_system_performance_claim_ready", "1")
    selection_question_text_only_rows = count_value(evaluator_rows, "selection_question_text_only", "1")
    selection_oracle_field_used_rows = count_value(evaluator_rows, "selection_oracle_field_used", "1")
    common_ready = int(
        as_int(summary_row, ready_field) == 1
        and summary_row.get("systems") == LOCAL_ABGH_SYSTEMS_TEXT
        and system_text(answer_rows) == LOCAL_ABGH_SYSTEMS_TEXT
        and len(answer_rows) == LOCAL_ABGH_TOTAL_ROWS
        and len(citation_rows) == LOCAL_ABGH_TOTAL_ROWS
        and len(evaluator_rows) == LOCAL_ABGH_TOTAL_ROWS
        and len(resource_rows) == LOCAL_ABGH_TOTAL_ROWS
        and same_query_row_contract == 1
        and as_int(summary_row, "same_query_set_all_local_systems") == 1
        and as_int(summary_row, "same_evaluator_contract_all_local_systems") == 1
        and as_int(summary_row, "same_resource_contract_all_local_systems") == 1
        and evaluator_bound_rows == LOCAL_ABGH_TOTAL_ROWS
        and answer_resource_bound_rows == LOCAL_ABGH_TOTAL_ROWS
        and answer_eval_separate_rows == LOCAL_ABGH_TOTAL_ROWS
        and citation_eval_separate_rows == LOCAL_ABGH_TOTAL_ROWS
        and resource_eval_separate_rows == LOCAL_ABGH_TOTAL_ROWS
        and resource_row_bound_rows == LOCAL_ABGH_TOTAL_ROWS
        and expected_answer_oracle_replay_zero_rows == LOCAL_ABGH_TOTAL_ROWS
        and expected_answer_oracle_replay_any == 0
        and no_external_model_rows == LOCAL_ABGH_TOTAL_ROWS
        and no_external_network_rows == LOCAL_ABGH_TOTAL_ROWS
        and as_int(summary_row, "public_comparison_claim_ready") == 0
    )
    if stage == "v53ap":
        stage_ready = int(
            common_ready
            and deterministic_source_span_adapter_execution_rows == LOCAL_ABGH_TOTAL_ROWS
            and actual_adapter_execution_ready_rows == LOCAL_ABGH_TOTAL_ROWS
            and real_adapter_execution_ready_rows == 0
            and real_system_performance_claim_ready_rows == 0
            and as_int(summary_row, "deterministic_source_span_adapter_execution") == 1
            and as_int(summary_row, "real_system_performance_claim_ready") == 0
        )
        prebaseline_rows = 0
        prebaseline_ready = 0
    else:
        prebaseline_rows = as_int(summary_row, "same_query_internal_prebaseline_rows")
        prebaseline_ready = as_int(summary_row, "same_query_internal_prebaseline_rows_ready")
        stage_ready = int(
            common_ready
            and deterministic_source_span_adapter_execution_rows == 0
            and actual_adapter_execution_ready_rows == LOCAL_ABGH_TOTAL_ROWS
            and real_adapter_execution_ready_rows == LOCAL_ABGH_TOTAL_ROWS
            and real_system_performance_claim_ready_rows == LOCAL_ABGH_TOTAL_ROWS
            and internal_real_adapter_metric_claim_ready_rows == LOCAL_ABGH_TOTAL_ROWS
            and public_real_system_performance_claim_ready_rows == 0
            and selection_question_text_only_rows == LOCAL_ABGH_TOTAL_ROWS
            and selection_oracle_field_used_rows == 0
            and as_int(summary_row, "selection_question_text_only") == 1
            and as_int(summary_row, "selection_oracle_field_used") == 0
            and as_int(summary_row, "deterministic_source_span_adapter_execution") == 0
            and as_int(summary_row, "real_adapter_execution_ready") == 1
            and as_int(summary_row, "real_system_performance_claim_ready") == 1
            and as_int(summary_row, "internal_real_adapter_metric_claim_ready") == 1
            and as_int(summary_row, "public_real_system_performance_claim_ready") == 0
            and prebaseline_ready == 1
            and prebaseline_rows == LOCAL_ABGH_QUERY_ROWS
        )
    return {
        "contract_id": f"{stage}-local-abgh-row-contract-replay",
        "source_stage": stage,
        "evidence_path": f"source_{stage}/abgh_evaluator_rows.csv",
        "systems": system_text(answer_rows),
        "expected_query_rows": str(LOCAL_ABGH_QUERY_ROWS),
        "observed_query_rows": str(len({row.get("query_id", "") for row in answer_rows if row.get("query_id", "")})),
        "expected_system_rows": str(LOCAL_ABGH_SYSTEM_ROWS),
        "answer_rows": str(len(answer_rows)),
        "citation_rows": str(len(citation_rows)),
        "evaluator_rows": str(len(evaluator_rows)),
        "resource_rows": str(len(resource_rows)),
        "same_query_row_contract": str(same_query_row_contract),
        "same_evaluator_contract_all_local_systems": str(as_int(summary_row, "same_evaluator_contract_all_local_systems")),
        "same_resource_contract_all_local_systems": str(as_int(summary_row, "same_resource_contract_all_local_systems")),
        "evaluator_bound_rows": str(evaluator_bound_rows),
        "answer_resource_bound_rows": str(answer_resource_bound_rows),
        "answer_eval_separate_rows": str(answer_eval_separate_rows),
        "citation_eval_separate_rows": str(citation_eval_separate_rows),
        "resource_eval_separate_rows": str(resource_eval_separate_rows),
        "resource_row_bound_rows": str(resource_row_bound_rows),
        "expected_answer_oracle_replay_zero_rows": str(expected_answer_oracle_replay_zero_rows),
        "expected_answer_oracle_replay_any": str(expected_answer_oracle_replay_any),
        "no_external_model_rows": str(no_external_model_rows),
        "no_external_network_rows": str(no_external_network_rows),
        "deterministic_source_span_adapter_execution_rows": str(deterministic_source_span_adapter_execution_rows),
        "actual_adapter_execution_ready_rows": str(actual_adapter_execution_ready_rows),
        "real_adapter_execution_ready_rows": str(real_adapter_execution_ready_rows),
        "real_system_performance_claim_ready_rows": str(real_system_performance_claim_ready_rows),
        "internal_real_adapter_metric_claim_ready_rows": str(internal_real_adapter_metric_claim_ready_rows),
        "public_real_system_performance_claim_ready_rows": str(public_real_system_performance_claim_ready_rows),
        "selection_question_text_only_rows": str(selection_question_text_only_rows),
        "selection_oracle_field_used_rows": str(selection_oracle_field_used_rows),
        "same_query_internal_prebaseline_rows": str(prebaseline_rows),
        "same_query_internal_prebaseline_ready": str(prebaseline_ready),
        "public_comparison_claim_ready": str(as_int(summary_row, "public_comparison_claim_ready")),
        "status": "pass" if stage_ready else "blocked",
        "claim_boundary": claim_boundary,
    }


v53t_dir = results / "v53t_complete_source_audit_readiness_gate" / "gate_001"
v53ap_dir = results / "v53ap_complete_source_abgh_same_query_measured" / "measured_001"
v53aq_dir = results / "v53aq_complete_source_abgh_real_adapter_measured" / "measured_001"
v54c_dir = results / "v54c_complete_source_grounded_generation_1000" / "generation_001"
h10_dir = results / "v10_h10_real_label_promotion_readiness_gate" / "gate_001"
v58c_dir = results / "v58c_blind_response_evidence_intake" / "intake_001"
v58d_dir = results / "v58d_blind_review_return_intake" / "intake_001"

v53t = first_row(results / "v53t_complete_source_audit_readiness_gate_summary.csv")
v53ap = first_row(results / "v53ap_complete_source_abgh_same_query_measured_summary.csv")
v53aq = first_row(results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv")
v54c = first_row(results / "v54c_complete_source_grounded_generation_1000_summary.csv")
h10 = first_row(results / "v10_h10_real_label_promotion_readiness_gate_summary.csv")
h10_acceptance_evidence_rows = read_csv(h10_dir / "h10_real_label_acceptance_evidence_rows.csv")
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
h10_acceptance_evidence_zero_accepted_rows = sum(
    1
    for row in h10_acceptance_evidence_rows
    if as_int(row, "accepted_real_label_evidence_rows") == 0
    and as_int(row, "accepted_query_rows_declared") == 0
    and as_int(row, "accepted_label_rows") == 0
    and as_int(row, "accepted_criterion_label_count") == 0
)
h10_acceptance_evidence_coverage_blocked_rows = sum(
    1 for row in h10_acceptance_evidence_rows if row.get("criterion_label_coverage_status") == "blocked"
)
h10_acceptance_evidence_source_verified_blocked_rows = sum(
    1 for row in h10_acceptance_evidence_rows if row.get("source_verified_eval_status") == "blocked"
)
v58c_summary_path = results / "v58c_blind_response_evidence_intake_summary.csv"
v58c_required_artifacts = [
    v58c_dir / "blind_response_required_field_rows.csv",
    v58c_dir / "blind_response_row_template.csv",
    v58c_dir / "run_identity_template_rows.csv",
    v58c_dir / "blind_response_validation_rows.csv",
    v58c_dir / "blind_response_intake_gate_rows.csv",
    v58c_dir / "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md",
    v58c_dir / "v58c_blind_response_evidence_intake_manifest.json",
    v58c_dir / "sha256_manifest.csv",
]
v58c_available = int(
    os.environ.get("V59E_USE_EXISTING_V58C", "0") == "1"
    and v58c_summary_path.is_file()
    and all(path.is_file() and path.stat().st_size > 0 for path in v58c_required_artifacts)
)
if v58c_available:
    v58c = first_row(v58c_summary_path)
else:
    v58c = {
        "v58c_blind_response_evidence_intake_ready": "0",
        "expected_blind_response_rows": "0",
        "required_blind_response_ready": "0",
        "blind_response_absorb_ready": "0",
        "human_blind_review_ready": "0",
        "v58_full_blind_eval_ready": "0",
    }
v58d_summary_path = results / "v58d_blind_review_return_intake_summary.csv"
v58d_required_artifacts = [
    v58d_dir / "blind_review_required_field_rows.csv",
    v58d_dir / "blind_review_return_template_rows.csv",
    v58d_dir / "blind_adjudication_return_template_rows.csv",
    v58d_dir / "blind_review_validation_rows.csv",
    v58d_dir / "blind_review_intake_gate_rows.csv",
    v58d_dir / "blind_eval_score_rows.csv",
    v58d_dir / "blind_failure_case_report_rows.csv",
    v58d_dir / "v58d_blind_review_dependency_rows.csv",
    v58d_dir / "V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md",
    v58d_dir / "v58d_blind_review_return_intake_manifest.json",
    v58d_dir / "sha256_manifest.csv",
]
v58d_available = int(
    os.environ.get("V59E_USE_EXISTING_V58D", "0") == "1"
    and v58d_summary_path.is_file()
    and all(path.is_file() and path.stat().st_size > 0 for path in v58d_required_artifacts)
)
if v58d_available:
    v58d = first_row(v58d_summary_path)
else:
    v58d = {
        "v58d_blind_review_return_intake_ready": "0",
        "expected_required_review_rows": "0",
        "required_blind_review_ready": "0",
        "required_adjudication_ready": "0",
        "human_blind_review_ready": "0",
        "inter_rater_rows_ready": "0",
        "routehint_advantage_rows_ready": "0",
        "failure_case_report_ready": "0",
        "v58_full_blind_eval_ready": "0",
    }

if v53t.get("pm_v53_freeze_ready") != "1":
    raise SystemExit("v59e requires pm_v53_freeze_ready=1")
if v53ap.get("v53ap_complete_source_abgh_same_query_measured_ready") != "1":
    raise SystemExit("v59e requires v53ap ready")
if v53aq.get("v53aq_complete_source_abgh_real_adapter_measured_ready") != "1":
    raise SystemExit("v59e requires v53aq ready")
if v54c.get("v54c_complete_source_grounded_generation_1000_ready") != "1":
    raise SystemExit("v59e requires v54c ready")
if h10.get("v10_h10_real_label_promotion_readiness_gate_ready") != "1":
    raise SystemExit("v59e requires h10 PM readiness gate")

v58c_dependency_blocker_summary = {
    "v58c_pm_blind_response_intake_dependency_blocker_ready": "1",
    "v58c_intake_artifact_available": str(v58c_available),
    "v58c_blind_response_evidence_intake_ready": v58c["v58c_blind_response_evidence_intake_ready"],
    "v58_full_blind_eval_ready": "0",
    "required_blind_response_ready": v58c["required_blind_response_ready"],
    "human_blind_review_ready": v58c["human_blind_review_ready"],
}
write_csv(
    run_dir / "v58c_pm_blind_response_intake_dependency_summary.csv",
    list(v58c_dependency_blocker_summary.keys()),
    [v58c_dependency_blocker_summary],
)
write_csv(
    run_dir / "v58c_pm_blind_response_intake_dependency_rows.csv",
    ["gate", "status", "reason"],
    [
        {
            "gate": "v58c-intake-artifact",
            "status": "pass" if v58c_available else "blocked",
            "reason": "v58c intake artifact is available" if v58c_available else "v58c intake artifact is not present; refusing implicit v58/v57/v56 seed rebuild",
        },
        {
            "gate": "required-blind-response-ready",
            "status": "pass" if v58c.get("required_blind_response_ready") == "1" else "blocked",
            "reason": "required blind responses validate" if v58c.get("required_blind_response_ready") == "1" else "real D/E/G/H blind response rows are not supplied",
        },
        {
            "gate": "human-blind-review",
            "status": "blocked",
            "reason": "human blind review and adjudication rows are not supplied",
        },
    ],
)

v58d_dependency_blocker_summary = {
    "v58d_pm_blind_review_return_dependency_blocker_ready": "1",
    "v58d_review_artifact_available": str(v58d_available),
    "v58d_blind_review_return_intake_ready": v58d["v58d_blind_review_return_intake_ready"],
    "v58_full_blind_eval_ready": "0",
    "expected_required_review_rows": v58d["expected_required_review_rows"],
    "required_blind_review_ready": v58d["required_blind_review_ready"],
    "required_adjudication_ready": v58d["required_adjudication_ready"],
    "human_blind_review_ready": v58d["human_blind_review_ready"],
    "inter_rater_rows_ready": v58d["inter_rater_rows_ready"],
}
write_csv(
    run_dir / "v58d_pm_blind_review_return_dependency_summary.csv",
    list(v58d_dependency_blocker_summary.keys()),
    [v58d_dependency_blocker_summary],
)
write_csv(
    run_dir / "v58d_pm_blind_review_return_dependency_rows.csv",
    ["gate", "status", "reason"],
    [
        {
            "gate": "v58d-review-artifact",
            "status": "pass" if v58d_available else "blocked",
            "reason": "v58d blind review return artifact is explicitly included" if v58d_available else "v58d review return artifact is not present or not explicitly included",
        },
        {
            "gate": "required-blind-review-ready",
            "status": "pass" if v58d.get("required_blind_review_ready") == "1" else "blocked",
            "reason": "required blind review rows validate" if v58d.get("required_blind_review_ready") == "1" else "two-reviewer blind return rows are not supplied",
        },
        {
            "gate": "adjudication-return-ready",
            "status": "pass" if v58d.get("required_adjudication_ready") == "1" else "blocked",
            "reason": "adjudication rows validate" if v58d.get("required_adjudication_ready") == "1" else "blind adjudication/inter-rater rows are not supplied",
        },
    ],
)

v58_blocker_summary = {
    "v58_pm_blind_eval_blocker_ready": "1",
    "v58_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "required_blind_response_ready": "0",
    "human_blind_review_ready": "0",
    "inter_rater_rows_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(run_dir / "v58_pm_blind_eval_blocker_summary.csv", list(v58_blocker_summary.keys()), [v58_blocker_summary])
write_csv(
    run_dir / "v58_pm_blind_eval_blocker_rows.csv",
    ["gate", "status", "reason"],
    [
        {"gate": "blind-response-evidence", "status": "blocked", "reason": "real D/E/G/H blind response rows are not supplied"},
        {"gate": "human-blind-review", "status": "blocked", "reason": "human blind review and inter-rater/adjudication rows are not supplied"},
        {"gate": "v58-full-blind-eval", "status": "blocked", "reason": "candidate/query-freeze contracts are not enough for v58 completion"},
    ],
)

stage_specs = [
    {
        "stage": "v53t",
        "summary_path": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
        "ready_field": "pm_v53_freeze_ready",
        "full_ready_field": "v53_ready",
        "artifacts": [
            (v53t_dir / "complete_source_pm_freeze_check_rows.csv", "source_v53t/complete_source_pm_freeze_check_rows.csv"),
            (v53t_dir / "complete_source_audit_readiness_requirement_rows.csv", "source_v53t/complete_source_audit_readiness_requirement_rows.csv"),
            (v53t_dir / "complete_source_audit_claim_rows.csv", "source_v53t/complete_source_audit_claim_rows.csv"),
            (v53t_dir / "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md", "source_v53t/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md"),
            (v53t_dir / "sha256_manifest.csv", "source_v53t/sha256_manifest.csv"),
        ],
        "claim_boundary": "v53 complete-source PM freeze gate",
    },
    {
        "stage": "v53ap",
        "summary_path": results / "v53ap_complete_source_abgh_same_query_measured_summary.csv",
        "ready_field": "v53ap_complete_source_abgh_same_query_measured_ready",
        "full_ready_field": "v53_ready",
        "artifacts": [
            (v53ap_dir / "abgh_system_rows.csv", "source_v53ap/abgh_system_rows.csv"),
            (v53ap_dir / "abgh_answer_rows.csv", "source_v53ap/abgh_answer_rows.csv"),
            (v53ap_dir / "abgh_citation_rows.csv", "source_v53ap/abgh_citation_rows.csv"),
            (v53ap_dir / "abgh_evaluator_rows.csv", "source_v53ap/abgh_evaluator_rows.csv"),
            (v53ap_dir / "abgh_adapter_trace_rows.csv", "source_v53ap/abgh_adapter_trace_rows.csv"),
            (v53ap_dir / "abgh_abstain_rows.csv", "source_v53ap/abgh_abstain_rows.csv"),
            (v53ap_dir / "abgh_wrong_answer_guard_rows.csv", "source_v53ap/abgh_wrong_answer_guard_rows.csv"),
            (v53ap_dir / "abgh_resource_rows.csv", "source_v53ap/abgh_resource_rows.csv"),
            (v53ap_dir / "routehint_rows.csv", "source_v53ap/routehint_rows.csv"),
            (v53ap_dir / "source_manifest_rows.csv", "source_v53ap/source_manifest_rows.csv"),
            (v53ap_dir / "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md", "source_v53ap/V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md"),
            (v53ap_dir / "sha256_manifest.csv", "source_v53ap/sha256_manifest.csv"),
        ],
        "claim_boundary": "internal v1.0 pre-baseline A/B/G/H same-query deterministic source-span adapter run; real system performance blocked",
    },
    {
        "stage": "v53aq",
        "summary_path": results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
        "ready_field": "v53aq_complete_source_abgh_real_adapter_measured_ready",
        "full_ready_field": "v53_ready",
        "artifacts": [
            (v53aq_dir / "adapter_selection_contract_rows.csv", "source_v53aq/adapter_selection_contract_rows.csv"),
            (v53aq_dir / "abgh_system_rows.csv", "source_v53aq/abgh_system_rows.csv"),
            (v53aq_dir / "abgh_system_metric_rows.csv", "source_v53aq/abgh_system_metric_rows.csv"),
            (v53aq_dir / "abgh_answer_rows.csv", "source_v53aq/abgh_answer_rows.csv"),
            (v53aq_dir / "abgh_citation_rows.csv", "source_v53aq/abgh_citation_rows.csv"),
            (v53aq_dir / "abgh_evaluator_rows.csv", "source_v53aq/abgh_evaluator_rows.csv"),
            (v53aq_dir / "abgh_adapter_trace_rows.csv", "source_v53aq/abgh_adapter_trace_rows.csv"),
            (v53aq_dir / "abgh_wrong_answer_guard_rows.csv", "source_v53aq/abgh_wrong_answer_guard_rows.csv"),
            (v53aq_dir / "abgh_resource_rows.csv", "source_v53aq/abgh_resource_rows.csv"),
            (v53aq_dir / "abgh_same_query_internal_prebaseline_rows.csv", "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
            (v53aq_dir / "route_memory_rows.csv", "source_v53aq/route_memory_rows.csv"),
            (v53aq_dir / "routehint_rows.csv", "source_v53aq/routehint_rows.csv"),
            (v53aq_dir / "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md", "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md"),
            (v53aq_dir / "sha256_manifest.csv", "source_v53aq/sha256_manifest.csv"),
        ],
        "claim_boundary": "internal v1.0 pre-baseline A/B/G/H query-text-only real adapter run; public comparison remains blocked",
    },
    {
        "stage": "v54c",
        "summary_path": results / "v54c_complete_source_grounded_generation_1000_summary.csv",
        "ready_field": "v54c_complete_source_grounded_generation_1000_ready",
        "full_ready_field": "v54_generation_1000_ready",
        "artifacts": [
            (v54c_dir / "answer_rows.csv", "source_v54c/answer_rows.csv"),
            (v54c_dir / "citation_rows.csv", "source_v54c/citation_rows.csv"),
            (v54c_dir / "unsupported_claim_rows.csv", "source_v54c/unsupported_claim_rows.csv"),
            (v54c_dir / "abstain_rows.csv", "source_v54c/abstain_rows.csv"),
            (v54c_dir / "generator_resource_rows.csv", "source_v54c/generator_resource_rows.csv"),
            (v54c_dir / "wrong_answer_guard_rows.csv", "source_v54c/wrong_answer_guard_rows.csv"),
            (v54c_dir / "grounded_generation_output_contract_rows.csv", "source_v54c/grounded_generation_output_contract_rows.csv"),
            (v54c_dir / "generator_input_rows.csv", "source_v54c/generator_input_rows.csv"),
            (v54c_dir / "compact_routehint_rows.csv", "source_v54c/compact_routehint_rows.csv"),
            (v54c_dir / "source_v53ap/abgh_adapter_trace_rows.csv", "source_v54c/source_v53ap/abgh_adapter_trace_rows.csv"),
            (v54c_dir / "source_v53ap/abgh_evaluator_rows.csv", "source_v54c/source_v53ap/abgh_evaluator_rows.csv"),
            (v54c_dir / "sha256sums.txt", "source_v54c/sha256sums.txt"),
            (v54c_dir / "V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md", "source_v54c/V54C_COMPLETE_SOURCE_GROUNDED_GENERATION_BOUNDARY.md"),
            (v54c_dir / "sha256_manifest.csv", "source_v54c/sha256_manifest.csv"),
        ],
        "claim_boundary": "v54 complete-source grounded generation without raw prompt stuffing",
    },
    {
        "stage": "h10_pm",
        "summary_path": results / "v10_h10_real_label_promotion_readiness_gate_summary.csv",
        "ready_field": "v10_h10_real_label_promotion_readiness_gate_ready",
        "full_ready_field": "h10_real_label_promotion_ready",
        "artifacts": [
            (h10_dir / "pm_h10_real_label_acceptance_rows.csv", "source_h10_pm/pm_h10_real_label_acceptance_rows.csv"),
            (h10_dir / "h10_real_label_evidence_template.csv", "source_h10_pm/h10_real_label_evidence_template.csv"),
            (h10_dir / "h10_real_label_evidence_acceptance_rows.csv", "source_h10_pm/h10_real_label_evidence_acceptance_rows.csv"),
            (h10_dir / "h10_real_label_return_contract_rows.csv", "source_h10_pm/h10_real_label_return_contract_rows.csv"),
            (h10_dir / "h10_real_label_acceptance_evidence_rows.csv", "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv"),
            (h10_dir / "source_v53ap/abgh_adapter_trace_rows.csv", "source_h10_pm/source_v53ap/abgh_adapter_trace_rows.csv"),
            (h10_dir / "source_v53ap/abgh_evaluator_rows.csv", "source_h10_pm/source_v53ap/abgh_evaluator_rows.csv"),
            (h10_dir / "source_v53aq/adapter_selection_contract_rows.csv", "source_h10_pm/source_v53aq/adapter_selection_contract_rows.csv"),
            (h10_dir / "source_v53aq/abgh_adapter_trace_rows.csv", "source_h10_pm/source_v53aq/abgh_adapter_trace_rows.csv"),
            (h10_dir / "source_v53aq/abgh_evaluator_rows.csv", "source_h10_pm/source_v53aq/abgh_evaluator_rows.csv"),
            (h10_dir / "source_v53aq/abgh_system_metric_rows.csv", "source_h10_pm/source_v53aq/abgh_system_metric_rows.csv"),
            (h10_dir / "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv", "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
            (h10_dir / "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv", "source_h10_pm/source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv"),
            (h10_dir / "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv", "source_h10_pm/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv"),
            (h10_dir / "source_v53t/complete_source_foundation_freeze_rows.csv", "source_h10_pm/source_v53t/complete_source_foundation_freeze_rows.csv"),
            (h10_dir / "V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md", "source_h10_pm/V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md"),
            (h10_dir / "sha256_manifest.csv", "source_h10_pm/sha256_manifest.csv"),
        ],
        "claim_boundary": "h10 real-label promotion readiness ledger; promotion still blocked",
    },
]

if v58c_available:
    stage_specs.append(
        {
            "stage": "v58c",
            "summary_path": results / "v58c_blind_response_evidence_intake_summary.csv",
            "ready_field": "v58c_blind_response_evidence_intake_ready",
            "full_ready_field": "v58_full_blind_eval_ready",
            "artifacts": [
                (v58c_dir / "blind_response_required_field_rows.csv", "source_v58c/blind_response_required_field_rows.csv"),
                (v58c_dir / "blind_response_row_template.csv", "source_v58c/blind_response_row_template.csv"),
                (v58c_dir / "run_identity_template_rows.csv", "source_v58c/run_identity_template_rows.csv"),
                (v58c_dir / "blind_response_validation_rows.csv", "source_v58c/blind_response_validation_rows.csv"),
                (v58c_dir / "blind_response_intake_gate_rows.csv", "source_v58c/blind_response_intake_gate_rows.csv"),
                (v58c_dir / "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md", "source_v58c/V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md"),
                (v58c_dir / "v58c_blind_response_evidence_intake_manifest.json", "source_v58c/v58c_blind_response_evidence_intake_manifest.json"),
                (v58c_dir / "sha256_manifest.csv", "source_v58c/sha256_manifest.csv"),
                (v58c_dir / "source_v58b/blind_query_freeze_rows.csv", "source_v58c/source_v58b/blind_query_freeze_rows.csv"),
                (v58c_dir / "source_v58b/sealed_identity_key_rows.csv", "source_v58c/source_v58b/sealed_identity_key_rows.csv"),
                (v58c_dir / "source_v58b/blind_response_template_rows.csv", "source_v58c/source_v58b/blind_response_template_rows.csv"),
                (v58c_dir / "source_v58b/sha256_manifest.csv", "source_v58c/source_v58b/sha256_manifest.csv"),
            ],
            "claim_boundary": "v58 blind response evidence intake; real response rows and human blind review still blocked",
        }
    )
else:
    stage_specs.append(
        {
            "stage": "v58c_dependency",
            "summary_path": run_dir / "v58c_pm_blind_response_intake_dependency_summary.csv",
            "ready_field": "v58c_pm_blind_response_intake_dependency_blocker_ready",
            "full_ready_field": "v58_full_blind_eval_ready",
            "artifacts": [
                (run_dir / "v58c_pm_blind_response_intake_dependency_rows.csv", "source_v58c_dependency/v58c_pm_blind_response_intake_dependency_rows.csv"),
            ],
            "claim_boundary": "v58c blind response intake dependency blocker; implicit v58/v57/v56 seed rebuild is refused",
        }
    )

if v58d_available:
    stage_specs.append(
        {
            "stage": "v58d",
            "summary_path": results / "v58d_blind_review_return_intake_summary.csv",
            "ready_field": "v58d_blind_review_return_intake_ready",
            "full_ready_field": "v58_full_blind_eval_ready",
            "artifacts": [
                (v58d_dir / "blind_review_required_field_rows.csv", "source_v58d/blind_review_required_field_rows.csv"),
                (v58d_dir / "blind_review_return_template_rows.csv", "source_v58d/blind_review_return_template_rows.csv"),
                (v58d_dir / "blind_adjudication_return_template_rows.csv", "source_v58d/blind_adjudication_return_template_rows.csv"),
                (v58d_dir / "blind_review_validation_rows.csv", "source_v58d/blind_review_validation_rows.csv"),
                (v58d_dir / "blind_review_intake_gate_rows.csv", "source_v58d/blind_review_intake_gate_rows.csv"),
                (v58d_dir / "blind_eval_score_rows.csv", "source_v58d/blind_eval_score_rows.csv"),
                (v58d_dir / "blind_failure_case_report_rows.csv", "source_v58d/blind_failure_case_report_rows.csv"),
                (v58d_dir / "v58d_blind_review_dependency_rows.csv", "source_v58d/v58d_blind_review_dependency_rows.csv"),
                (v58d_dir / "V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md", "source_v58d/V58D_BLIND_REVIEW_RETURN_INTAKE_BOUNDARY.md"),
                (v58d_dir / "v58d_blind_review_return_intake_manifest.json", "source_v58d/v58d_blind_review_return_intake_manifest.json"),
                (v58d_dir / "sha256_manifest.csv", "source_v58d/sha256_manifest.csv"),
            ],
            "claim_boundary": "v58 blind review return intake; real review/adjudication still may be blocked",
        }
    )
else:
    stage_specs.append(
        {
            "stage": "v58d_dependency",
            "summary_path": run_dir / "v58d_pm_blind_review_return_dependency_summary.csv",
            "ready_field": "v58d_pm_blind_review_return_dependency_blocker_ready",
            "full_ready_field": "v58_full_blind_eval_ready",
            "artifacts": [
                (run_dir / "v58d_pm_blind_review_return_dependency_rows.csv", "source_v58d_dependency/v58d_pm_blind_review_return_dependency_rows.csv"),
            ],
            "claim_boundary": "v58d blind review return dependency blocker; implicit review evidence is refused",
        }
    )

stage_specs.append(
    {
        "stage": "v58_blocker",
        "summary_path": run_dir / "v58_pm_blind_eval_blocker_summary.csv",
        "ready_field": "v58_pm_blind_eval_blocker_ready",
        "full_ready_field": "v58_full_blind_eval_ready",
        "artifacts": [
            (run_dir / "v58_pm_blind_eval_blocker_rows.csv", "source_v58_blocker/v58_pm_blind_eval_blocker_rows.csv"),
        ],
        "claim_boundary": "v58 blind eval blocker ledger; real blind eval still blocked",
    }
)

stage_rows = []
bundle_rows = []
for spec in stage_specs:
    source_summary = first_row(spec["summary_path"])
    summary_rel = f"source_{spec['stage']}/{spec['summary_path'].name}"
    copy(spec["summary_path"], summary_rel)
    bundle_rows.append({"path": summary_rel, "source_stage": spec["stage"], "artifact_role": "summary"})
    copied = 1
    for src, rel in spec["artifacts"]:
        copy(src, rel)
        bundle_rows.append({"path": rel, "source_stage": spec["stage"], "artifact_role": "evidence"})
        copied += 1
    stage_rows.append(
        {
            "stage": spec["stage"],
            "ready_field": spec["ready_field"],
            "ready": str(as_int(source_summary, spec["ready_field"])),
            "full_ready_field": spec["full_ready_field"],
            "full_ready": str(as_int(source_summary, spec["full_ready_field"])),
            "copied_artifacts": str(copied),
            "claim_boundary": spec["claim_boundary"],
        }
    )

write_csv(run_dir / "pm_foundation_stage_replay_rows.csv", list(stage_rows[0].keys()), stage_rows)
write_csv(run_dir / "challenge_bundle_file_rows.csv", list(bundle_rows[0].keys()), bundle_rows)

command_rows = [
    {
        "command_id": "v1_0_architecture_challenge_pm_foundation_demo",
        "command": "./examples/v1_0_architecture_challenge_pm_foundation_demo.sh",
        "writes_bundle": "results/v59e_one_command_pm_foundation_demo/pm_foundation_001",
        "network_required": "0",
        "downloads_required": "0",
        "private_fixture_required": "0",
        "manual_postprocessing_required": "0",
        "undocumented_local_state_required": "0",
    }
]
write_csv(run_dir / "pm_foundation_one_command_rows.csv", list(command_rows[0].keys()), command_rows)

pm_checks = {row["check_id"]: row for row in read_csv(v53t_dir / "complete_source_pm_freeze_check_rows.csv")}
pinned_public_sources_verified = int(pm_checks.get("pinned-public-repo-manifest", {}).get("status") == "pass")
answer_citation_separate_eval = int(pm_checks.get("answer-citation-separate-eval", {}).get("status") == "pass")
blocker_false_positive_closed = int(pm_checks.get("blocker-false-positive-closed", {}).get("status") == "pass")
repo_coverage_rows = read_csv(v53t_dir / "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv")
file_manifest_rows = read_csv(v53t_dir / "source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv")
content_repo_rows = read_csv(v53t_dir / "source_v53i/source_v53h/complete_source_content_repo_rows.csv")
content_snapshot_rows = read_csv(v53t_dir / "source_v53i/source_v53h/complete_source_content_snapshot_rows.csv")
content_repo_by_id = {row["repo_id"]: row for row in content_repo_rows}
file_rows_by_repo = Counter(row["repo_id"] for row in file_manifest_rows)
content_rows_by_repo = Counter(row["repo_id"] for row in content_snapshot_rows if row.get("content_materialized") == "1")
repo_url_by_id = {}
for row in file_manifest_rows:
    repo_url_by_id.setdefault(row["repo_id"], row.get("repo_url", ""))
public_source_snapshot_replay_rows = []
for repo in sorted(repo_coverage_rows, key=lambda row: int(row["repo_slot"])):
    content_repo = content_repo_by_id.get(repo["repo_id"], {})
    manifest_file_rows = file_rows_by_repo[repo["repo_id"]]
    content_snapshot_file_rows = content_rows_by_repo[repo["repo_id"]]
    replay_ready = int(
        repo.get("complete_source_tree_manifest_ready") == "1"
        and content_repo.get("content_snapshot_ready") == "1"
        and int(content_repo.get("manifest_file_rows", "0") or "0") == manifest_file_rows
        and int(content_repo.get("content_materialized_file_rows", "0") or "0") == content_snapshot_file_rows
    )
    public_source_snapshot_replay_rows.append(
        {
            "repo_slot": repo["repo_slot"],
            "repo_id": repo["repo_id"],
            "owner_repo": repo["owner_repo"],
            "repo_url": repo_url_by_id.get(repo["repo_id"], ""),
            "pinned_commit_sha": repo["head_sha"],
            "manifest_file_rows": str(manifest_file_rows),
            "content_snapshot_rows": str(content_snapshot_file_rows),
            "query_eligible_content_rows": content_repo.get("query_eligible_content_rows", "0"),
            "content_bytes_materialized": content_repo.get("content_bytes_materialized", "0"),
            "tree_manifest_ready": repo.get("complete_source_tree_manifest_ready", "0"),
            "content_snapshot_ready": content_repo.get("content_snapshot_ready", "0"),
            "source_snapshot_replay_used": "1",
            "public_source_download_executed": "0",
            "network_required_by_default": "0",
            "downloads_required_by_default": "0",
            "replay_status": "pass" if replay_ready else "blocked",
            "evidence_path": "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv",
        }
    )
write_csv(run_dir / "public_source_snapshot_replay_rows.csv", list(public_source_snapshot_replay_rows[0].keys()), public_source_snapshot_replay_rows)
public_source_snapshot_replay_pass_rows = sum(1 for row in public_source_snapshot_replay_rows if row["replay_status"] == "pass")
public_source_snapshot_replay_ready = int(
    len(public_source_snapshot_replay_rows) == 10
    and public_source_snapshot_replay_pass_rows == 10
    and pinned_public_sources_verified == 1
)
public_source_policy_rows = [
    {
        "policy_id": "v59e-pm-foundation-source-replay-policy",
        "pinned_public_sources_verified": str(pinned_public_sources_verified),
        "public_source_snapshot_replay_rows": str(len(public_source_snapshot_replay_rows)),
        "public_source_snapshot_replay_pass_rows": str(public_source_snapshot_replay_pass_rows),
        "public_source_snapshot_replay_ready": str(public_source_snapshot_replay_ready),
        "source_snapshot_replay_used": "1",
        "public_source_download_executed": "0",
        "public_source_download_approval_required": "1",
        "network_required_by_default": "0",
        "downloads_required_by_default": "0",
        "full_public_source_download_ready": "0",
        "evidence_path": "public_source_snapshot_replay_rows.csv",
        "blocker_status": "blocked-full-public-demo",
        "reason": "v59e replays the pinned v53 complete-source snapshot; live public-source download/refresh requires explicit approval and belongs to the full v59 public demo path",
    }
]
write_csv(run_dir / "public_source_replay_policy_rows.csv", list(public_source_policy_rows[0].keys()), public_source_policy_rows)
bundle_rows.append(
    {
        "path": "public_source_replay_policy_rows.csv",
        "source_stage": "v59e_core",
        "artifact_role": "source_replay_policy",
    }
)
bundle_rows.append(
    {
        "path": "public_source_snapshot_replay_rows.csv",
        "source_stage": "v59e_core",
        "artifact_role": "source_snapshot_replay",
    }
)
write_csv(run_dir / "challenge_bundle_file_rows.csv", list(bundle_rows[0].keys()), bundle_rows)
route_memory_artifact_ready = int(as_int(v53ap, "routehint_rows") == 2000 and as_int(v53aq, "routehint_rows") == 2000 and as_int(v54c, "compact_routehint_rows") == 1000)
local_abgh_baseline_run_ready = int(
    v53ap.get("systems") == "A/B/G/H"
    and as_int(v53ap, "answer_rows") == 4000
    and as_int(v53ap, "evaluator_rows") == 4000
    and as_int(v53ap, "resource_rows") == 4000
    and as_int(v53ap, "same_evaluator_contract_all_local_systems") == 1
    and as_int(v53ap, "same_resource_contract_all_local_systems") == 1
)
local_abgh_deterministic_adapter_ready = int(
    local_abgh_baseline_run_ready
    and as_int(v53ap, "expected_answer_oracle_replay") == 0
    and as_int(v53ap, "deterministic_source_span_adapter_execution") == 1
    and as_int(v53ap, "deterministic_source_span_adapter_rows") == 4000
    and as_int(v53ap, "actual_adapter_execution_ready") == 1
    and as_int(v53ap, "real_system_performance_claim_ready") == 0
)
local_abgh_real_adapter_ready = int(
    as_int(v53aq, "v53aq_complete_source_abgh_real_adapter_measured_ready") == 1
    and v53aq.get("systems") == "A/B/G/H"
    and as_int(v53aq, "answer_rows") == 4000
    and as_int(v53aq, "evaluator_rows") == 4000
    and as_int(v53aq, "resource_rows") == 4000
    and as_int(v53aq, "selection_question_text_only") == 1
    and as_int(v53aq, "selection_oracle_field_used") == 0
    and as_int(v53aq, "expected_answer_oracle_replay") == 0
    and as_int(v53aq, "deterministic_source_span_adapter_execution") == 0
    and as_int(v53aq, "real_adapter_execution_ready") == 1
    and as_int(v53aq, "real_system_performance_claim_ready") == 1
    and as_int(v53aq, "internal_real_adapter_metric_claim_ready") == 1
    and as_int(v53aq, "public_real_system_performance_claim_ready") == 0
    and as_int(v53aq, "same_query_internal_prebaseline_rows_ready") == 1
    and as_int(v53aq, "same_query_internal_prebaseline_rows") == 1000
)
local_abgh_row_contract_replay_rows = [
    build_local_abgh_row_contract(
        "v53ap",
        v53ap_dir,
        v53ap,
        "v53ap_complete_source_abgh_same_query_measured_ready",
        "internal v1.0 pre-baseline A/B/G/H deterministic source-span adapter row contract; real system performance and public comparison remain blocked",
    ),
    build_local_abgh_row_contract(
        "v53aq",
        v53aq_dir,
        v53aq,
        "v53aq_complete_source_abgh_real_adapter_measured_ready",
        "internal v1.0 pre-baseline A/B/G/H query-text-only real-adapter row contract; public comparison remains blocked until D/E 30B/70B and blind eval evidence exist",
    ),
]
write_csv(
    run_dir / "local_abgh_row_contract_replay_rows.csv",
    list(local_abgh_row_contract_replay_rows[0].keys()),
    local_abgh_row_contract_replay_rows,
)
local_abgh_row_contract_replay_pass_rows = sum(1 for row in local_abgh_row_contract_replay_rows if row["status"] == "pass")
local_abgh_row_contract_replay_ready = int(
    len(local_abgh_row_contract_replay_rows) == 2
    and local_abgh_row_contract_replay_pass_rows == 2
    and local_abgh_baseline_run_ready == 1
    and local_abgh_deterministic_adapter_ready == 1
    and local_abgh_real_adapter_ready == 1
)
bundle_rows.append(
    {
        "path": "local_abgh_row_contract_replay_rows.csv",
        "source_stage": "v59e_core",
        "artifact_role": "local_abgh_row_contract_replay",
    }
)
write_csv(run_dir / "challenge_bundle_file_rows.csv", list(bundle_rows[0].keys()), bundle_rows)
grounded_generation_outputs_ready = int(
    as_int(v54c, "answer_rows") == 1000
    and as_int(v54c, "citation_rows") == 1000
    and as_int(v54c, "wrong_answer_guard_rows") == 1000
    and as_int(v54c, "v53ap_adapter_trace_provenance_rows") == 1000
    and as_int(v54c, "v53ap_evaluator_provenance_rows") == 1000
    and as_int(v54c, "v53ap_answer_eval_separate_rows") == 1000
    and as_int(v54c, "v53ap_citation_eval_separate_rows") == 1000
    and as_int(v54c, "v53ap_resource_eval_separate_rows") == 1000
    and as_int(v54c, "grounded_generation_output_contract_rows") == 9
    and as_int(v54c, "grounded_generation_output_contract_pm_required_rows") == 7
    and as_int(v54c, "grounded_generation_output_contract_raw_prompt_forbidden_rows") == 9
    and as_int(v54c, "sha256sums_pm_recommended_csv_rows") == 6
    and as_int(v54c, "sha256sums_pm_recommended_csv_ready") == 1
    and as_int(v54c, "raw_prompt_context_appended_rows") == 0
)
h10_blocker_ledger_ready = int(as_int(h10, "v10_h10_real_label_promotion_readiness_gate_ready") == 1 and as_int(h10, "h10_real_label_promotion_ready") == 0)
blind_response_intake_ready = int(
    v58c_available
    and
    as_int(v58c, "v58c_blind_response_evidence_intake_ready") == 1
    and as_int(v58c, "expected_blind_response_rows") == 2500
    and as_int(v58c, "required_blind_response_ready") == 0
    and as_int(v58c, "human_blind_review_ready") == 0
)
v58c_dependency_blocker_ready = int(not v58c_available and as_int(v58c_dependency_blocker_summary, "v58c_pm_blind_response_intake_dependency_blocker_ready") == 1)
blind_review_intake_ready = int(
    v58d_available
    and as_int(v58d, "v58d_blind_review_return_intake_ready") == 1
    and as_int(v58d, "v58_full_blind_eval_ready") == 0
)
v58d_dependency_blocker_ready = int(not v58d_available and as_int(v58d_dependency_blocker_summary, "v58d_pm_blind_review_return_dependency_blocker_ready") == 1)
blind_eval_blocker_ready = int(
    (blind_response_intake_ready or v58c_dependency_blocker_ready)
    and (blind_review_intake_ready or v58d_dependency_blocker_ready)
    and as_int(v58_blocker_summary, "v58_pm_blind_eval_blocker_ready") == 1
    and as_int(v58_blocker_summary, "v58_full_blind_eval_ready") == 0
)
no_hidden_state_ready = 1
challenge_bundle_ready = int(all(row["ready"] == "1" for row in stage_rows) and len(bundle_rows) >= 35)

gate_rows = [
    ("pinned-public-sources-verified", "pass" if pinned_public_sources_verified else "blocked", "v53t PM freeze has pinned 10-repo manifest check"),
    ("public-source-replay-policy", "pass", "PM foundation replay uses hash-bound pinned source artifacts and records that live downloads are not executed by default"),
    ("public-source-download-execution", "blocked", "full v59 public demo still needs explicit approval and live/downloaded public-source refresh evidence"),
    ("complete-source-query-freeze", "pass" if as_int(v53t, "pm_v53_freeze_ready") else "blocked", "v53t PM freeze checks pass"),
    ("route-memory-artifact-built", "pass" if route_memory_artifact_ready else "blocked", "v53ap/v54c RouteHint artifacts are replayed"),
    ("local-abgh-baseline-run", "pass" if local_abgh_baseline_run_ready else "blocked", "A/B/G/H answer/citation/resource row-contract rows are copied"),
    ("local-abgh-deterministic-adapter-run", "pass" if local_abgh_deterministic_adapter_ready else "blocked", "v53ap generates A/B/G/H answers from deterministic source-span adapters and keeps real performance comparison blocked"),
    ("local-abgh-real-adapter-run", "pass" if local_abgh_real_adapter_ready else "blocked", "v53aq runs query-text-only A/B/G/H adapters and keeps public comparison blocked"),
    ("local-abgh-row-contract-replay", "pass" if local_abgh_row_contract_replay_ready else "blocked", "v53ap/v53aq answer, citation, evaluator, and resource rows replay as the same 1000-query A/B/G/H contract"),
    ("evaluator-check", "pass" if answer_citation_separate_eval else "blocked", "answer and citation/source checks remain separate"),
    ("grounded-generation-outputs", "pass" if grounded_generation_outputs_ready else "blocked", "v54c recommended output artifacts are copied"),
    ("h10-real-label-readiness-ledger", "pass" if h10_blocker_ledger_ready else "blocked", "h10 real-label promotion blocker ledger is copied"),
    ("v58-blind-response-intake", "pass" if blind_response_intake_ready else "blocked", "v58c response schema/templates/validation rows are copied without fake responses"),
    ("v58c-intake-dependency-blocker", "pass" if (blind_response_intake_ready or v58c_dependency_blocker_ready) else "blocked", "v58c intake is copied when present; otherwise implicit v58/v57/v56 seed rebuild remains blocked"),
    ("v58-blind-review-intake", "pass" if blind_review_intake_ready else "blocked", "v58d review/adjudication schema rows are copied without fake review rows"),
    ("v58d-review-return-dependency-blocker", "pass" if (blind_review_intake_ready or v58d_dependency_blocker_ready) else "blocked", "v58d review return is copied when explicitly included; otherwise review evidence remains blocked"),
    ("v58-blind-eval-blocker-ledger", "pass" if blind_eval_blocker_ready else "blocked", "v58 real-response and human-review blockers are explicit"),
    ("no-hidden-local-state", "pass" if no_hidden_state_ready else "blocked", "no private fixture, download, network, or manual post-processing required for this local replay"),
    ("blocker-false-positive-closed", "pass" if blocker_false_positive_closed else "blocked", "comparison and release blockers remain closed"),
    ("one-command-entrypoint", "pass", "examples/v1_0_architecture_challenge_pm_foundation_demo.sh runs v59e"),
    ("challenge-bundle-written", "pass" if challenge_bundle_ready else "blocked", f"bundle_files={len(bundle_rows)}"),
    ("real-blind-eval", "blocked", "real D/E/G/H blind responses and human blind review are missing"),
    ("full-v59-public-demo", "blocked", "this is a PM foundation replay, not the full v52-v58 public challenge demo"),
    ("real-release-package", "blocked", "v60 release evidence is still missing"),
]
decision_rows = [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
write_csv(run_dir / "pm_foundation_demo_gate_rows.csv", ["gate", "status", "reason"], decision_rows)

demo = run_dir / "pm_foundation_demo.sh"
demo.write_text(
    "#!/usr/bin/env bash\n"
    "set -euo pipefail\n\n"
    "ROOT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/../../..\" && pwd)\"\n"
    "\"$ROOT_DIR/examples/v1_0_architecture_challenge_pm_foundation_demo.sh\"\n",
    encoding="utf-8",
)
demo.chmod(0o755)

summary = {
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "v59_ready": "0",
    "one_command_entrypoint_ready": "1",
    "challenge_bundle_ready": str(challenge_bundle_ready),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(1 for row in stage_rows if row["ready"] == "1")),
    "full_ready_stage_rows": str(sum(1 for row in stage_rows if row["full_ready"] == "1")),
    "bundle_files": str(len(bundle_rows)),
    "pinned_public_sources_verified": str(pinned_public_sources_verified),
    "public_source_snapshot_replay_rows": str(len(public_source_snapshot_replay_rows)),
    "public_source_snapshot_replay_pass_rows": str(public_source_snapshot_replay_pass_rows),
    "public_source_snapshot_replay_ready": str(public_source_snapshot_replay_ready),
    "source_snapshot_replay_used": "1",
    "public_source_download_executed": "0",
    "public_source_download_approval_required": "1",
    "full_public_source_download_ready": "0",
    "pm_v53_freeze_ready": v53t["pm_v53_freeze_ready"],
    "v53_negative_abstain_rows": v53t.get("negative_abstain_rows", "0"),
    "v53_unsupported_control_rows": v53t.get("unsupported_control_rows", "0"),
    "v53_ambiguous_control_rows": v53t.get("ambiguous_control_rows", "0"),
    "v53_missing_specific_control_rows": v53t.get("missing_specific_control_rows", "0"),
    "v53_doc_code_conflict_rows": v53t.get("doc_code_conflict_rows", "0"),
    "v53ap_complete_source_abgh_same_query_measured_ready": v53ap["v53ap_complete_source_abgh_same_query_measured_ready"],
    "v53aq_complete_source_abgh_real_adapter_measured_ready": v53aq["v53aq_complete_source_abgh_real_adapter_measured_ready"],
    "local_abgh_baseline_run_ready": str(local_abgh_baseline_run_ready),
    "local_abgh_row_contract_replay_rows": str(len(local_abgh_row_contract_replay_rows)),
    "local_abgh_row_contract_replay_pass_rows": str(local_abgh_row_contract_replay_pass_rows),
    "local_abgh_row_contract_replay_ready": str(local_abgh_row_contract_replay_ready),
    "local_abgh_deterministic_adapter_ready": str(local_abgh_deterministic_adapter_ready),
    "local_abgh_real_adapter_ready": str(local_abgh_real_adapter_ready),
    "v53ap_expected_answer_oracle_replay": v53ap.get("expected_answer_oracle_replay", "0"),
    "v53ap_deterministic_source_span_adapter_execution": v53ap.get("deterministic_source_span_adapter_execution", "0"),
    "v53ap_deterministic_source_span_adapter_rows": v53ap.get("deterministic_source_span_adapter_rows", "0"),
    "v53ap_actual_adapter_execution_ready": v53ap.get("actual_adapter_execution_ready", "0"),
    "v53ap_real_system_performance_claim_ready": v53ap.get("real_system_performance_claim_ready", "0"),
    "v53aq_selection_question_text_only": v53aq.get("selection_question_text_only", "0"),
    "v53aq_selection_oracle_field_used": v53aq.get("selection_oracle_field_used", "1"),
    "v53aq_expected_answer_oracle_replay": v53aq.get("expected_answer_oracle_replay", "0"),
    "v53aq_deterministic_source_span_adapter_execution": v53aq.get("deterministic_source_span_adapter_execution", "1"),
    "v53aq_real_adapter_execution_ready": v53aq.get("real_adapter_execution_ready", "0"),
    "v53aq_real_system_performance_claim_ready": v53aq.get("real_system_performance_claim_ready", "0"),
    "v53aq_internal_real_adapter_metric_claim_ready": v53aq.get("internal_real_adapter_metric_claim_ready", "0"),
    "v53aq_public_real_system_performance_claim_ready": v53aq.get("public_real_system_performance_claim_ready", "1"),
    "v53aq_same_query_internal_prebaseline_rows_ready": v53aq.get("same_query_internal_prebaseline_rows_ready", "0"),
    "v53aq_same_query_internal_prebaseline_rows": v53aq.get("same_query_internal_prebaseline_rows", "0"),
    "v53aq_answer_hash_match_rows": v53aq.get("answer_hash_match_rows", "0"),
    "v53aq_coherent_wrong_key_rows": v53aq.get("coherent_wrong_key_rows", "0"),
    "same_query_abgh_ready": v53ap["same_query_set_all_local_systems"],
    "route_memory_artifact_ready": str(route_memory_artifact_ready),
    "v54c_complete_source_grounded_generation_1000_ready": v54c["v54c_complete_source_grounded_generation_1000_ready"],
    "grounded_generation_outputs_ready": str(grounded_generation_outputs_ready),
    "v54c_output_contract_rows": v54c.get("grounded_generation_output_contract_rows", "0"),
    "v54c_output_contract_pm_required_rows": v54c.get("grounded_generation_output_contract_pm_required_rows", "0"),
    "v54c_output_contract_raw_prompt_forbidden_rows": v54c.get("grounded_generation_output_contract_raw_prompt_forbidden_rows", "0"),
    "v54c_sha256sums_pm_recommended_csv_rows": v54c.get("sha256sums_pm_recommended_csv_rows", "0"),
    "v54c_sha256sums_pm_recommended_csv_ready": v54c.get("sha256sums_pm_recommended_csv_ready", "0"),
    "v54c_v53ap_evaluator_provenance_ready": v54c.get("v53ap_evaluator_provenance_ready", "0"),
    "v54c_v53ap_evaluator_provenance_rows": v54c.get("v53ap_evaluator_provenance_rows", "0"),
    "v54c_v53ap_answer_eval_separate_rows": v54c.get("v53ap_answer_eval_separate_rows", "0"),
    "v54c_v53ap_citation_eval_separate_rows": v54c.get("v53ap_citation_eval_separate_rows", "0"),
    "v54c_v53ap_resource_eval_separate_rows": v54c.get("v53ap_resource_eval_separate_rows", "0"),
    "h10_real_label_readiness_gate_ready": h10["v10_h10_real_label_promotion_readiness_gate_ready"],
    "h10_real_label_promotion_ready": h10["h10_real_label_promotion_ready"],
    "h10_real_label_acceptance_evidence_rows": h10.get("h10_real_label_acceptance_evidence_rows", "0"),
    "h10_real_label_acceptance_evidence_ready_rows": h10.get("h10_real_label_acceptance_evidence_ready_rows", "0"),
    "h10_real_label_acceptance_evidence_promotion_ready_rows": h10.get("h10_real_label_acceptance_evidence_promotion_ready_rows", "0"),
    "h10_real_label_acceptance_evidence_tests_only_rows": h10.get("h10_real_label_acceptance_evidence_tests_only_rows", "0"),
    "h10_accepted_query_rows_declared": h10.get("accepted_query_rows_declared", "0"),
    "h10_accepted_label_rows": h10.get("accepted_label_rows", "0"),
    "h10_accepted_coherent_wrong_key_labels": h10.get("accepted_coherent_wrong_key_labels", "0"),
    "h10_accepted_chunk_exact_labels": h10.get("accepted_chunk_exact_labels", "0"),
    "h10_accepted_near_miss_labels": h10.get("accepted_near_miss_labels", "0"),
    "h10_accepted_missing_query_labels": h10.get("accepted_missing_query_labels", "0"),
    "h10_accepted_source_provenance_labels": h10.get("accepted_source_provenance_labels", "0"),
    "h10_real_label_acceptance_evidence_coverage_field_rows": str(h10_acceptance_evidence_coverage_field_rows),
    "h10_real_label_acceptance_evidence_zero_accepted_rows": str(h10_acceptance_evidence_zero_accepted_rows),
    "h10_real_label_acceptance_evidence_coverage_blocked_rows": str(h10_acceptance_evidence_coverage_blocked_rows),
    "h10_real_label_acceptance_evidence_source_verified_blocked_rows": str(h10_acceptance_evidence_source_verified_blocked_rows),
    "v58_pm_blind_eval_blocker_ready": v58_blocker_summary["v58_pm_blind_eval_blocker_ready"],
    "v58c_intake_artifact_available": str(v58c_available),
    "v58c_dependency_blocker_ready": str(v58c_dependency_blocker_ready),
    "v58c_blind_response_evidence_intake_ready": v58c["v58c_blind_response_evidence_intake_ready"],
    "v58c_expected_blind_response_rows": v58c["expected_blind_response_rows"],
    "v58c_required_blind_response_ready": v58c["required_blind_response_ready"],
    "v58c_blind_response_absorb_ready": v58c["blind_response_absorb_ready"],
    "v58c_human_blind_review_ready": v58c["human_blind_review_ready"],
    "v58d_review_artifact_available": str(v58d_available),
    "v58d_dependency_blocker_ready": str(v58d_dependency_blocker_ready),
    "v58d_blind_review_return_intake_ready": v58d["v58d_blind_review_return_intake_ready"],
    "v58d_expected_required_review_rows": v58d["expected_required_review_rows"],
    "v58d_required_blind_review_ready": v58d["required_blind_review_ready"],
    "v58d_required_adjudication_ready": v58d["required_adjudication_ready"],
    "v58d_human_blind_review_ready": v58d["human_blind_review_ready"],
    "v58d_inter_rater_rows_ready": v58d["inter_rater_rows_ready"],
    "v58_full_blind_eval_ready": v58_blocker_summary["v58_full_blind_eval_ready"],
    "answer_citation_separate_eval": str(answer_citation_separate_eval),
    "blocker_false_positive_closed": str(blocker_false_positive_closed),
    "undocumented_local_state_required": "0",
    "private_fixture_required": "0",
    "manual_postprocessing_required": "0",
    "network_required": "0",
    "downloads_required": "0",
    "full_v1_public_demo_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

(run_dir / "README_RESULT.md").write_text(
    "# v59e One-Command PM Foundation Demo\n\n"
    "Command:\n\n"
    "```bash\n"
    "./examples/v1_0_architecture_challenge_pm_foundation_demo.sh\n"
    "```\n\n"
    "This bundle replays the current PM foundation: v53 complete-source freeze, "
    "A/B/G/H same-query deterministic source-span adapter rows, query-text-only real adapter rows, v54c grounded generation rows, h10 "
    "real-label promotion readiness ledger, the v58c blind-response intake dependency check, "
    "the v58d blind-review return dependency check, and the v58 blind-eval blocker ledger. "
    "The repository entrypoint then refreshes the PM PR claim-slice gate so the "
    "review split and the v56 replay-artifact blocker are visible beside this bundle. "
    "It is intentionally not the completed v59 public challenge demo.\n\n"
    f"- pm_v53_freeze_ready={summary['pm_v53_freeze_ready']}\n"
    f"- v53_negative_abstain_rows={summary['v53_negative_abstain_rows']}\n"
    f"- v53_unsupported_control_rows={summary['v53_unsupported_control_rows']}\n"
    f"- v53_ambiguous_control_rows={summary['v53_ambiguous_control_rows']}\n"
    f"- v53_missing_specific_control_rows={summary['v53_missing_specific_control_rows']}\n"
    f"- v53_doc_code_conflict_rows={summary['v53_doc_code_conflict_rows']}\n"
    f"- source_snapshot_replay_used={summary['source_snapshot_replay_used']}\n"
    f"- public_source_snapshot_replay_ready={summary['public_source_snapshot_replay_ready']}\n"
    f"- public_source_snapshot_replay_rows={summary['public_source_snapshot_replay_rows']}\n"
    f"- public_source_download_executed={summary['public_source_download_executed']}\n"
    f"- full_public_source_download_ready={summary['full_public_source_download_ready']}\n"
    f"- local_abgh_baseline_run_ready={summary['local_abgh_baseline_run_ready']}\n"
    f"- local_abgh_row_contract_replay_rows={summary['local_abgh_row_contract_replay_rows']}\n"
    f"- local_abgh_row_contract_replay_pass_rows={summary['local_abgh_row_contract_replay_pass_rows']}\n"
    f"- local_abgh_row_contract_replay_ready={summary['local_abgh_row_contract_replay_ready']}\n"
    f"- local_abgh_deterministic_adapter_ready={summary['local_abgh_deterministic_adapter_ready']}\n"
    f"- local_abgh_real_adapter_ready={summary['local_abgh_real_adapter_ready']}\n"
    f"- v53ap_actual_adapter_execution_ready={summary['v53ap_actual_adapter_execution_ready']}\n"
    f"- v53aq_real_adapter_execution_ready={summary['v53aq_real_adapter_execution_ready']}\n"
    f"- v53aq_internal_real_adapter_metric_claim_ready={summary['v53aq_internal_real_adapter_metric_claim_ready']}\n"
    f"- v53aq_public_real_system_performance_claim_ready={summary['v53aq_public_real_system_performance_claim_ready']}\n"
    f"- v53aq_selection_question_text_only={summary['v53aq_selection_question_text_only']}\n"
    f"- v53aq_selection_oracle_field_used={summary['v53aq_selection_oracle_field_used']}\n"
    f"- grounded_generation_outputs_ready={summary['grounded_generation_outputs_ready']}\n"
    f"- v54c_output_contract_rows={summary['v54c_output_contract_rows']}\n"
    f"- v54c_output_contract_pm_required_rows={summary['v54c_output_contract_pm_required_rows']}\n"
    f"- v54c_output_contract_raw_prompt_forbidden_rows={summary['v54c_output_contract_raw_prompt_forbidden_rows']}\n"
    f"- v54c_sha256sums_pm_recommended_csv_rows={summary['v54c_sha256sums_pm_recommended_csv_rows']}\n"
    f"- v54c_sha256sums_pm_recommended_csv_ready={summary['v54c_sha256sums_pm_recommended_csv_ready']}\n"
    f"- v54c_v53ap_evaluator_provenance_ready={summary['v54c_v53ap_evaluator_provenance_ready']}\n"
    f"- v54c_v53ap_evaluator_provenance_rows={summary['v54c_v53ap_evaluator_provenance_rows']}\n"
    f"- h10_real_label_promotion_ready={summary['h10_real_label_promotion_ready']}\n"
    f"- h10_real_label_acceptance_evidence_rows={summary['h10_real_label_acceptance_evidence_rows']}\n"
    f"- h10_real_label_acceptance_evidence_ready_rows={summary['h10_real_label_acceptance_evidence_ready_rows']}\n"
    f"- h10_real_label_acceptance_evidence_promotion_ready_rows={summary['h10_real_label_acceptance_evidence_promotion_ready_rows']}\n"
    f"- h10_real_label_acceptance_evidence_tests_only_rows={summary['h10_real_label_acceptance_evidence_tests_only_rows']}\n"
    f"- h10_accepted_query_rows_declared={summary['h10_accepted_query_rows_declared']}\n"
    f"- h10_accepted_label_rows={summary['h10_accepted_label_rows']}\n"
    f"- h10_real_label_acceptance_evidence_coverage_blocked_rows={summary['h10_real_label_acceptance_evidence_coverage_blocked_rows']}\n"
    f"- h10_real_label_acceptance_evidence_source_verified_blocked_rows={summary['h10_real_label_acceptance_evidence_source_verified_blocked_rows']}\n"
    f"- v58c_intake_artifact_available={summary['v58c_intake_artifact_available']}\n"
    f"- v58c_blind_response_evidence_intake_ready={summary['v58c_blind_response_evidence_intake_ready']}\n"
    f"- v58c_required_blind_response_ready={summary['v58c_required_blind_response_ready']}\n"
    f"- v58d_review_artifact_available={summary['v58d_review_artifact_available']}\n"
    f"- v58d_blind_review_return_intake_ready={summary['v58d_blind_review_return_intake_ready']}\n"
    f"- v58d_human_blind_review_ready={summary['v58d_human_blind_review_ready']}\n"
    f"- v58_full_blind_eval_ready={summary['v58_full_blind_eval_ready']}\n"
    f"- full_v1_public_demo_ready={summary['full_v1_public_demo_ready']}\n\n"
    "Still blocked: accepted external/human h10 labels, real blind responses, human blind review, full v59 public replay, and v60 release review.\n",
    encoding="utf-8",
)

(run_dir / "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md").write_text(
    "# v59e One-Command PM Foundation Boundary\n\n"
    "This one-command bundle exists to make the PM foundation replayable. It must not be used as a v1.0 public challenge or release claim.\n\n"
    f"- v59e_one_command_pm_foundation_demo_ready={summary['v59e_one_command_pm_foundation_demo_ready']}\n"
    f"- pm_v53_freeze_ready={summary['pm_v53_freeze_ready']}\n"
    f"- v53_negative_abstain_rows={summary['v53_negative_abstain_rows']}\n"
    f"- v53_unsupported_control_rows={summary['v53_unsupported_control_rows']}\n"
    f"- v53_ambiguous_control_rows={summary['v53_ambiguous_control_rows']}\n"
    f"- v53_missing_specific_control_rows={summary['v53_missing_specific_control_rows']}\n"
    f"- v53_doc_code_conflict_rows={summary['v53_doc_code_conflict_rows']}\n"
    f"- source_snapshot_replay_used={summary['source_snapshot_replay_used']}\n"
    f"- public_source_snapshot_replay_ready={summary['public_source_snapshot_replay_ready']}\n"
    f"- public_source_snapshot_replay_rows={summary['public_source_snapshot_replay_rows']}\n"
    f"- public_source_download_executed={summary['public_source_download_executed']}\n"
    f"- public_source_download_approval_required={summary['public_source_download_approval_required']}\n"
    f"- full_public_source_download_ready={summary['full_public_source_download_ready']}\n"
    f"- local_abgh_baseline_run_ready={summary['local_abgh_baseline_run_ready']}\n"
    f"- local_abgh_row_contract_replay_rows={summary['local_abgh_row_contract_replay_rows']}\n"
    f"- local_abgh_row_contract_replay_pass_rows={summary['local_abgh_row_contract_replay_pass_rows']}\n"
    f"- local_abgh_row_contract_replay_ready={summary['local_abgh_row_contract_replay_ready']}\n"
    f"- local_abgh_deterministic_adapter_ready={summary['local_abgh_deterministic_adapter_ready']}\n"
    f"- local_abgh_real_adapter_ready={summary['local_abgh_real_adapter_ready']}\n"
    f"- v53ap_expected_answer_oracle_replay={summary['v53ap_expected_answer_oracle_replay']}\n"
    f"- v53ap_deterministic_source_span_adapter_execution={summary['v53ap_deterministic_source_span_adapter_execution']}\n"
    f"- v53ap_deterministic_source_span_adapter_rows={summary['v53ap_deterministic_source_span_adapter_rows']}\n"
    f"- v53ap_actual_adapter_execution_ready={summary['v53ap_actual_adapter_execution_ready']}\n"
    f"- v53ap_real_system_performance_claim_ready={summary['v53ap_real_system_performance_claim_ready']}\n"
    f"- v53aq_real_adapter_execution_ready={summary['v53aq_real_adapter_execution_ready']}\n"
    f"- v53aq_internal_real_adapter_metric_claim_ready={summary['v53aq_internal_real_adapter_metric_claim_ready']}\n"
    f"- v53aq_public_real_system_performance_claim_ready={summary['v53aq_public_real_system_performance_claim_ready']}\n"
    f"- v53aq_selection_question_text_only={summary['v53aq_selection_question_text_only']}\n"
    f"- v53aq_selection_oracle_field_used={summary['v53aq_selection_oracle_field_used']}\n"
    f"- v53aq_answer_hash_match_rows={summary['v53aq_answer_hash_match_rows']}\n"
    f"- v53aq_coherent_wrong_key_rows={summary['v53aq_coherent_wrong_key_rows']}\n"
    f"- route_memory_artifact_ready={summary['route_memory_artifact_ready']}\n"
    f"- grounded_generation_outputs_ready={summary['grounded_generation_outputs_ready']}\n"
    f"- v54c_output_contract_rows={summary['v54c_output_contract_rows']}\n"
    f"- v54c_output_contract_pm_required_rows={summary['v54c_output_contract_pm_required_rows']}\n"
    f"- v54c_output_contract_raw_prompt_forbidden_rows={summary['v54c_output_contract_raw_prompt_forbidden_rows']}\n"
    f"- v54c_sha256sums_pm_recommended_csv_rows={summary['v54c_sha256sums_pm_recommended_csv_rows']}\n"
    f"- v54c_sha256sums_pm_recommended_csv_ready={summary['v54c_sha256sums_pm_recommended_csv_ready']}\n"
    f"- v54c_v53ap_evaluator_provenance_ready={summary['v54c_v53ap_evaluator_provenance_ready']}\n"
    f"- v54c_v53ap_evaluator_provenance_rows={summary['v54c_v53ap_evaluator_provenance_rows']}\n"
    f"- h10_real_label_promotion_ready={summary['h10_real_label_promotion_ready']}\n"
    f"- h10_real_label_acceptance_evidence_rows={summary['h10_real_label_acceptance_evidence_rows']}\n"
    f"- h10_real_label_acceptance_evidence_ready_rows={summary['h10_real_label_acceptance_evidence_ready_rows']}\n"
    f"- h10_real_label_acceptance_evidence_promotion_ready_rows={summary['h10_real_label_acceptance_evidence_promotion_ready_rows']}\n"
    f"- h10_real_label_acceptance_evidence_tests_only_rows={summary['h10_real_label_acceptance_evidence_tests_only_rows']}\n"
    f"- h10_accepted_query_rows_declared={summary['h10_accepted_query_rows_declared']}\n"
    f"- h10_accepted_label_rows={summary['h10_accepted_label_rows']}\n"
    f"- h10_accepted_coherent_wrong_key_labels={summary['h10_accepted_coherent_wrong_key_labels']}\n"
    f"- h10_accepted_chunk_exact_labels={summary['h10_accepted_chunk_exact_labels']}\n"
    f"- h10_accepted_near_miss_labels={summary['h10_accepted_near_miss_labels']}\n"
    f"- h10_accepted_missing_query_labels={summary['h10_accepted_missing_query_labels']}\n"
    f"- h10_accepted_source_provenance_labels={summary['h10_accepted_source_provenance_labels']}\n"
    f"- h10_real_label_acceptance_evidence_coverage_field_rows={summary['h10_real_label_acceptance_evidence_coverage_field_rows']}\n"
    f"- h10_real_label_acceptance_evidence_zero_accepted_rows={summary['h10_real_label_acceptance_evidence_zero_accepted_rows']}\n"
    f"- h10_real_label_acceptance_evidence_coverage_blocked_rows={summary['h10_real_label_acceptance_evidence_coverage_blocked_rows']}\n"
    f"- h10_real_label_acceptance_evidence_source_verified_blocked_rows={summary['h10_real_label_acceptance_evidence_source_verified_blocked_rows']}\n"
    f"- v58c_intake_artifact_available={summary['v58c_intake_artifact_available']}\n"
    f"- v58c_dependency_blocker_ready={summary['v58c_dependency_blocker_ready']}\n"
    f"- v58c_blind_response_evidence_intake_ready={summary['v58c_blind_response_evidence_intake_ready']}\n"
    f"- v58c_expected_blind_response_rows={summary['v58c_expected_blind_response_rows']}\n"
    f"- v58c_required_blind_response_ready={summary['v58c_required_blind_response_ready']}\n"
    f"- v58c_human_blind_review_ready={summary['v58c_human_blind_review_ready']}\n"
    f"- v58d_review_artifact_available={summary['v58d_review_artifact_available']}\n"
    f"- v58d_dependency_blocker_ready={summary['v58d_dependency_blocker_ready']}\n"
    f"- v58d_blind_review_return_intake_ready={summary['v58d_blind_review_return_intake_ready']}\n"
    f"- v58d_expected_required_review_rows={summary['v58d_expected_required_review_rows']}\n"
    f"- v58d_human_blind_review_ready={summary['v58d_human_blind_review_ready']}\n"
    f"- v58_full_blind_eval_ready={summary['v58_full_blind_eval_ready']}\n"
    f"- undocumented_local_state_required={summary['undocumented_local_state_required']}\n"
    f"- private_fixture_required={summary['private_fixture_required']}\n"
    f"- manual_postprocessing_required={summary['manual_postprocessing_required']}\n"
    f"- real_release_package_ready={summary['real_release_package_ready']}\n\n"
    "Allowed wording: replayable PM foundation bundle for v53/v54/h10/v58 intake surfaces.\n\n"
    "Blocked wording: v59 public demo complete, v58 blind-eval complete, h10 real-label promotion, v1.0 release readiness, or public comparison win.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v59e-one-command-pm-foundation-demo",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v59e_one_command_pm_foundation_demo_ready": 1,
    "v59_ready": 0,
    "stage_rows": len(stage_rows),
    "bundle_files": len(bundle_rows),
    "source_snapshot_replay_used": 1,
    "public_source_snapshot_replay_rows": len(public_source_snapshot_replay_rows),
    "public_source_snapshot_replay_pass_rows": public_source_snapshot_replay_pass_rows,
    "public_source_snapshot_replay_ready": public_source_snapshot_replay_ready,
    "public_source_download_executed": 0,
    "public_source_download_approval_required": 1,
    "full_public_source_download_ready": 0,
    "v53_negative_abstain_rows": as_int(v53t, "negative_abstain_rows"),
    "v53_unsupported_control_rows": as_int(v53t, "unsupported_control_rows"),
    "v53_ambiguous_control_rows": as_int(v53t, "ambiguous_control_rows"),
    "v53_missing_specific_control_rows": as_int(v53t, "missing_specific_control_rows"),
    "v53_doc_code_conflict_rows": as_int(v53t, "doc_code_conflict_rows"),
    "source_summary_sha256": {
        "v53t": sha256(results / "v53t_complete_source_audit_readiness_gate_summary.csv"),
        "v53ap": sha256(results / "v53ap_complete_source_abgh_same_query_measured_summary.csv"),
        "v53aq": sha256(results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv"),
        "v54c": sha256(results / "v54c_complete_source_grounded_generation_1000_summary.csv"),
        "h10_pm": sha256(results / "v10_h10_real_label_promotion_readiness_gate_summary.csv"),
        "v58c": sha256(results / "v58c_blind_response_evidence_intake_summary.csv") if v58c_available else sha256(run_dir / "v58c_pm_blind_response_intake_dependency_summary.csv"),
        "v58d": sha256(results / "v58d_blind_review_return_intake_summary.csv") if v58d_available else sha256(run_dir / "v58d_pm_blind_review_return_dependency_summary.csv"),
        "v58_blocker": sha256(run_dir / "v58_pm_blind_eval_blocker_summary.csv"),
    },
    "blocked_claims": [
        "v59-public-demo-complete",
        "v58-blind-eval-complete",
        "h10-real-label-promotion",
        "v1_0-release-ready",
        "public-comparison-win",
        "public-abgh-comparison",
    ],
    "local_abgh_row_contract_replay_rows": len(local_abgh_row_contract_replay_rows),
    "local_abgh_row_contract_replay_pass_rows": local_abgh_row_contract_replay_pass_rows,
    "local_abgh_row_contract_replay_ready": local_abgh_row_contract_replay_ready,
    "local_abgh_row_contract_replay_rows_sha256": sha256(run_dir / "local_abgh_row_contract_replay_rows.csv"),
    "local_abgh_deterministic_adapter_ready": local_abgh_deterministic_adapter_ready,
    "local_abgh_real_adapter_ready": local_abgh_real_adapter_ready,
    "v53ap_expected_answer_oracle_replay": as_int(v53ap, "expected_answer_oracle_replay"),
    "v53ap_deterministic_source_span_adapter_execution": as_int(v53ap, "deterministic_source_span_adapter_execution"),
    "v53ap_deterministic_source_span_adapter_rows": as_int(v53ap, "deterministic_source_span_adapter_rows"),
    "v53ap_actual_adapter_execution_ready": as_int(v53ap, "actual_adapter_execution_ready"),
    "v53ap_real_system_performance_claim_ready": as_int(v53ap, "real_system_performance_claim_ready"),
    "v53aq_complete_source_abgh_real_adapter_measured_ready": as_int(v53aq, "v53aq_complete_source_abgh_real_adapter_measured_ready"),
    "v53aq_selection_question_text_only": as_int(v53aq, "selection_question_text_only"),
    "v53aq_selection_oracle_field_used": as_int(v53aq, "selection_oracle_field_used"),
    "v53aq_expected_answer_oracle_replay": as_int(v53aq, "expected_answer_oracle_replay"),
    "v53aq_deterministic_source_span_adapter_execution": as_int(v53aq, "deterministic_source_span_adapter_execution"),
    "v53aq_real_adapter_execution_ready": as_int(v53aq, "real_adapter_execution_ready"),
    "v53aq_real_system_performance_claim_ready": as_int(v53aq, "real_system_performance_claim_ready"),
    "v53aq_internal_real_adapter_metric_claim_ready": as_int(v53aq, "internal_real_adapter_metric_claim_ready"),
    "v53aq_public_real_system_performance_claim_ready": as_int(v53aq, "public_real_system_performance_claim_ready"),
    "v53aq_answer_hash_match_rows": as_int(v53aq, "answer_hash_match_rows"),
    "v53aq_coherent_wrong_key_rows": as_int(v53aq, "coherent_wrong_key_rows"),
    "v54c_v53ap_evaluator_provenance_ready": as_int(v54c, "v53ap_evaluator_provenance_ready"),
    "v54c_v53ap_evaluator_provenance_rows": as_int(v54c, "v53ap_evaluator_provenance_rows"),
    "v54c_v53ap_answer_eval_separate_rows": as_int(v54c, "v53ap_answer_eval_separate_rows"),
    "v54c_v53ap_citation_eval_separate_rows": as_int(v54c, "v53ap_citation_eval_separate_rows"),
    "v54c_v53ap_resource_eval_separate_rows": as_int(v54c, "v53ap_resource_eval_separate_rows"),
    "v54c_output_contract_rows": as_int(v54c, "grounded_generation_output_contract_rows"),
    "v54c_output_contract_pm_required_rows": as_int(v54c, "grounded_generation_output_contract_pm_required_rows"),
    "v54c_output_contract_raw_prompt_forbidden_rows": as_int(v54c, "grounded_generation_output_contract_raw_prompt_forbidden_rows"),
    "v54c_sha256sums_pm_recommended_csv_rows": as_int(v54c, "sha256sums_pm_recommended_csv_rows"),
    "v54c_sha256sums_pm_recommended_csv_ready": as_int(v54c, "sha256sums_pm_recommended_csv_ready"),
    "h10_real_label_acceptance_evidence_rows": as_int(h10, "h10_real_label_acceptance_evidence_rows"),
    "h10_real_label_acceptance_evidence_ready_rows": as_int(h10, "h10_real_label_acceptance_evidence_ready_rows"),
    "h10_real_label_acceptance_evidence_promotion_ready_rows": as_int(h10, "h10_real_label_acceptance_evidence_promotion_ready_rows"),
    "h10_real_label_acceptance_evidence_tests_only_rows": as_int(h10, "h10_real_label_acceptance_evidence_tests_only_rows"),
    "h10_accepted_query_rows_declared": as_int(h10, "accepted_query_rows_declared"),
    "h10_accepted_label_rows": as_int(h10, "accepted_label_rows"),
    "h10_accepted_coherent_wrong_key_labels": as_int(h10, "accepted_coherent_wrong_key_labels"),
    "h10_accepted_chunk_exact_labels": as_int(h10, "accepted_chunk_exact_labels"),
    "h10_accepted_near_miss_labels": as_int(h10, "accepted_near_miss_labels"),
    "h10_accepted_missing_query_labels": as_int(h10, "accepted_missing_query_labels"),
    "h10_accepted_source_provenance_labels": as_int(h10, "accepted_source_provenance_labels"),
    "h10_real_label_acceptance_evidence_coverage_field_rows": h10_acceptance_evidence_coverage_field_rows,
    "h10_real_label_acceptance_evidence_zero_accepted_rows": h10_acceptance_evidence_zero_accepted_rows,
    "h10_real_label_acceptance_evidence_coverage_blocked_rows": h10_acceptance_evidence_coverage_blocked_rows,
    "h10_real_label_acceptance_evidence_source_verified_blocked_rows": h10_acceptance_evidence_source_verified_blocked_rows,
    "h10_real_label_acceptance_evidence_rows_sha256": sha256(run_dir / "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv"),
    "v58c_intake_artifact_available": v58c_available,
    "v58c_dependency_blocker_ready": v58c_dependency_blocker_ready,
    "v58c_blind_response_evidence_intake_ready": as_int(v58c, "v58c_blind_response_evidence_intake_ready"),
    "v58c_expected_blind_response_rows": as_int(v58c, "expected_blind_response_rows"),
    "v58c_required_blind_response_ready": as_int(v58c, "required_blind_response_ready"),
    "v58c_human_blind_review_ready": as_int(v58c, "human_blind_review_ready"),
    "v58d_review_artifact_available": v58d_available,
    "v58d_dependency_blocker_ready": v58d_dependency_blocker_ready,
    "v58d_blind_review_return_intake_ready": as_int(v58d, "v58d_blind_review_return_intake_ready"),
    "v58d_expected_required_review_rows": as_int(v58d, "expected_required_review_rows"),
    "v58d_required_blind_review_ready": as_int(v58d, "required_blind_review_ready"),
    "v58d_required_adjudication_ready": as_int(v58d, "required_adjudication_ready"),
    "v58d_human_blind_review_ready": as_int(v58d, "human_blind_review_ready"),
    "v58d_inter_rater_rows_ready": as_int(v58d, "inter_rater_rows_ready"),
    "real_release_package_ready": 0,
}
(run_dir / "v59e_one_command_pm_foundation_demo_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v59e_one_command_pm_foundation_demo_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY

"$ROOT_DIR/experiments/run_v1_0_pm_pr_claim_slice_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
pr_run_dir = results / "v1_0_pm_pr_claim_slice_gate" / "gate_001"
pr_summary_csv = results / "v1_0_pm_pr_claim_slice_gate_summary.csv"
pr_decision_csv = results / "v1_0_pm_pr_claim_slice_gate_decision.csv"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def first_row(path):
    rows = read_csv(path)
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}")
    return rows[0]


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key, default="0"):
    return int(float(row.get(key, default) or default))


def copy_bundle_file(src, rel, role):
    copy(src, rel)
    bundle_rows.append(
        {
            "path": rel,
            "source_stage": "pm_pr_claim_slice_gate",
            "artifact_role": role,
        }
    )


if not pr_run_dir.is_dir():
    raise SystemExit(f"missing PM PR claim-slice gate run dir: {pr_run_dir}")

summary = first_row(summary_csv)
pr_summary = first_row(pr_summary_csv)
bundle_rows = read_csv(run_dir / "challenge_bundle_file_rows.csv")

pm_pr_core_files = [
    (pr_summary_csv, "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_summary.csv", "summary"),
    (pr_decision_csv, "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_decision.csv", "decision"),
    (pr_run_dir / "source_summary_rows.csv", "source_pm_pr_claim_slice_gate/source_summary_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_slice_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_slice_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_merge_gate_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_merge_gate_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_claim_boundary_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_claim_boundary_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_slice_file_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_slice_file_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_slice_verification_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_slice_verification_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_review_packet_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_review_packet_rows.csv", "evidence"),
    (pr_run_dir / "pm_pr_acceptance_evidence_rows.csv", "source_pm_pr_claim_slice_gate/pm_pr_acceptance_evidence_rows.csv", "evidence"),
    (pr_run_dir / "v56_replay_acceptance_evidence_rows.csv", "source_pm_pr_claim_slice_gate/v56_replay_acceptance_evidence_rows.csv", "evidence"),
    (pr_run_dir / "source_v56/v56_seed_dependency_blocker_rows.csv", "source_pm_pr_claim_slice_gate/source_v56/v56_seed_dependency_blocker_rows.csv", "evidence"),
    (pr_run_dir / "source_v56/V56_RULER_LONGBENCH_DEPENDENCY_BLOCKER.md", "source_pm_pr_claim_slice_gate/source_v56/V56_RULER_LONGBENCH_DEPENDENCY_BLOCKER.md", "evidence"),
    (pr_run_dir / "de_30b70b_acceptance_evidence_rows.csv", "source_pm_pr_claim_slice_gate/de_30b70b_acceptance_evidence_rows.csv", "evidence"),
    (pr_run_dir / "v59_one_command_acceptance_evidence_rows.csv", "source_pm_pr_claim_slice_gate/v59_one_command_acceptance_evidence_rows.csv", "evidence"),
    (pr_run_dir / "pm_roadmap_requirement_rows.csv", "source_pm_pr_claim_slice_gate/pm_roadmap_requirement_rows.csv", "evidence"),
    (pr_run_dir / "pm_blocker_closure_queue_rows.csv", "source_pm_pr_claim_slice_gate/pm_blocker_closure_queue_rows.csv", "evidence"),
    (pr_run_dir / "pm_blocker_closure_packet_rows.csv", "source_pm_pr_claim_slice_gate/pm_blocker_closure_packet_rows.csv", "evidence"),
    (pr_run_dir / "pm_blocker_required_artifact_rows.csv", "source_pm_pr_claim_slice_gate/pm_blocker_required_artifact_rows.csv", "evidence"),
    (pr_run_dir / "pm_execution_lock_rows.csv", "source_pm_pr_claim_slice_gate/pm_execution_lock_rows.csv", "evidence"),
    (pr_run_dir / "pm_external_return_template_rows.csv", "source_pm_pr_claim_slice_gate/pm_external_return_template_rows.csv", "evidence"),
    (pr_run_dir / "source_h10_pm/pm_h10_real_label_acceptance_rows.csv", "source_pm_pr_claim_slice_gate/source_h10_pm/pm_h10_real_label_acceptance_rows.csv", "evidence"),
    (pr_run_dir / "source_h10_pm/h10_real_label_evidence_template.csv", "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_template.csv", "evidence"),
    (pr_run_dir / "source_h10_pm/h10_real_label_evidence_acceptance_rows.csv", "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_evidence_acceptance_rows.csv", "evidence"),
    (pr_run_dir / "source_h10_pm/h10_real_label_return_contract_rows.csv", "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_return_contract_rows.csv", "evidence"),
    (pr_run_dir / "source_h10_pm/h10_real_label_acceptance_evidence_rows.csv", "source_pm_pr_claim_slice_gate/source_h10_pm/h10_real_label_acceptance_evidence_rows.csv", "evidence"),
    (pr_run_dir / "source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv", "source_pm_pr_claim_slice_gate/source_h10_pm/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/complete_source_foundation_freeze_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/complete_source_foundation_freeze_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/complete_source_pm_acceptance_evidence_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/complete_source_pm_acceptance_evidence_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/complete_source_abgh_real_adapter_freeze_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/complete_source_query_span_binding_audit_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/complete_source_query_span_binding_audit_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/complete_source_query_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_query_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/complete_source_span_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/complete_source_span_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_repo_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53ap/abgh_answer_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_answer_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53ap/abgh_citation_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_citation_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53ap/abgh_evaluator_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_evaluator_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53ap/abgh_resource_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_resource_rows.csv", "evidence"),
    (pr_run_dir / "source_v53t/source_v53ap/abgh_adapter_trace_rows.csv", "source_pm_pr_claim_slice_gate/source_v53t/source_v53ap/abgh_adapter_trace_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/adapter_selection_contract_rows.csv", "source_pm_pr_claim_slice_gate/source_v53aq/adapter_selection_contract_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/abgh_system_metric_rows.csv", "source_pm_pr_claim_slice_gate/source_v53aq/abgh_system_metric_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/abgh_evaluator_rows.csv", "source_pm_pr_claim_slice_gate/source_v53aq/abgh_evaluator_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/abgh_adapter_trace_rows.csv", "source_pm_pr_claim_slice_gate/source_v53aq/abgh_adapter_trace_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv", "source_pm_pr_claim_slice_gate/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/routehint_rows.csv", "source_pm_pr_claim_slice_gate/source_v53aq/routehint_rows.csv", "evidence"),
    (pr_run_dir / "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md", "source_pm_pr_claim_slice_gate/source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md", "boundary"),
    (pr_run_dir / "source_v59e/local_abgh_row_contract_replay_rows.csv", "source_pm_pr_claim_slice_gate/source_v59e/local_abgh_row_contract_replay_rows.csv", "evidence"),
    (pr_run_dir / "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md", "source_pm_pr_claim_slice_gate/V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md", "boundary"),
    (pr_run_dir / "v1_0_pm_pr_claim_slice_gate_manifest.json", "source_pm_pr_claim_slice_gate/v1_0_pm_pr_claim_slice_gate_manifest.json", "manifest"),
]
for src, rel, role in pm_pr_core_files:
    copy_bundle_file(src, rel, role)

review_packet_files = sorted((pr_run_dir / "review_packets").glob("*.md"))
blocker_packet_files = sorted((pr_run_dir / "blocker_packets").glob("*.md"))
return_template_files = sorted(path for path in (pr_run_dir / "return_templates").rglob("*") if path.is_file())

for path in review_packet_files:
    copy_bundle_file(path, f"source_pm_pr_claim_slice_gate/review_packets/{path.name}", "review_packet")
for path in blocker_packet_files:
    copy_bundle_file(path, f"source_pm_pr_claim_slice_gate/blocker_packets/{path.name}", "blocker_packet")
for path in return_template_files:
    rel_path = path.relative_to(pr_run_dir / "return_templates")
    copy_bundle_file(path, f"source_pm_pr_claim_slice_gate/return_templates/{rel_path}", "return_template")

review_packet_ready = int(
    as_int(pr_summary, "pm_pr_review_packet_rows") == 10
    and as_int(pr_summary, "pm_pr_review_packet_files") == len(review_packet_files) == 10
)
blocker_packet_ready = int(
    as_int(pr_summary, "pm_blocker_closure_packet_rows") == 6
    and as_int(pr_summary, "pm_blocker_closure_packet_files") == len(blocker_packet_files) == 6
)
execution_lock_ready = int(
    as_int(pr_summary, "pm_execution_lock_rows") == 10
    and as_int(pr_summary, "pm_execution_lock_active_rows") == 10
    and as_int(pr_summary, "pm_scope_drift_allowed") == 0
    and as_int(pr_summary, "pm_new_scaffold_default_allowed") == 0
)
external_return_template_ready = int(
    as_int(pr_summary, "pm_external_return_template_rows") == len(return_template_files) == 26
    and as_int(pr_summary, "pm_external_return_template_fixture_allowed_rows") == 0
    and as_int(pr_summary, "pm_external_return_template_approval_rows") == 26
)
v58_blocker_classes = {"v58c-intake-artifact-missing", "v58-real-blind-eval-missing"}
pm_required_artifact_rows = read_csv(pr_run_dir / "pm_blocker_required_artifact_rows.csv")
pm_return_template_rows = read_csv(pr_run_dir / "pm_external_return_template_rows.csv")
v58_required_artifact_rows = [
    row for row in pm_required_artifact_rows if row["blocker_class"] in v58_blocker_classes
]
v58_return_template_rows = [
    row for row in pm_return_template_rows if row["blocker_class"] in v58_blocker_classes
]
v58_template_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in v58_return_template_rows}
v58_return_contract_map_rows = []
for row in v58_required_artifact_rows:
    key = (row["blocker_class"], row["artifact_id"])
    template = v58_template_by_key.get(key)
    if template is None:
        raise SystemExit(f"missing v58 return template for required artifact: {key}")
    v58_return_contract_map_rows.append(
        {
            "blocker_class": row["blocker_class"],
            "artifact_id": row["artifact_id"],
            "artifact_path_or_env": row["artifact_path_or_env"],
            "artifact_kind": row["artifact_kind"],
            "required_shape": row["required_shape"],
            "return_template_path": template["template_path"],
            "return_template_kind": template["template_kind"],
            "validation_command": row["validation_command"],
            "acceptance_signal": row["acceptance_signal"],
            "fixture_allowed": row["fixture_allowed"],
            "approval_required": row["approval_required"],
            "template_ready": template["template_ready"],
            "template_sha256": template["template_sha256"],
            "default_acceptance_status": "blocked",
            "status": "ready",
        }
    )
write_csv(run_dir / "v58_blind_eval_required_artifact_rows.csv", list(v58_required_artifact_rows[0].keys()), v58_required_artifact_rows)
write_csv(run_dir / "v58_blind_eval_return_template_rows.csv", list(v58_return_template_rows[0].keys()), v58_return_template_rows)
write_csv(run_dir / "v58_blind_eval_return_contract_map_rows.csv", list(v58_return_contract_map_rows[0].keys()), v58_return_contract_map_rows)
v58_contract_by_artifact = {row["artifact_id"]: row for row in v58_return_contract_map_rows}
v58_acceptance_evidence_rows = []
for row in v58_required_artifact_rows:
    contract = v58_contract_by_artifact[row["artifact_id"]]
    contract_ready = int(
        row["fixture_allowed"] == "0"
        and row["approval_required"] == "1"
        and contract["fixture_allowed"] == "0"
        and contract["approval_required"] == "1"
        and contract["template_ready"] == "1"
        and contract["default_acceptance_status"] == "blocked"
        and contract["status"] == "ready"
    )
    v58_acceptance_evidence_rows.append(
        {
            "blocker_class": row["blocker_class"],
            "artifact_id": row["artifact_id"],
            "claim_boundary_status": "pass",
            "output_artifact_replay_status": "pass",
            "blocker_false_positive_status": "pass",
            "required_artifact_path": "v58_blind_eval_required_artifact_rows.csv",
            "required_artifact_row_count": str(len(v58_required_artifact_rows)),
            "required_artifact_sha256": sha256(run_dir / "v58_blind_eval_required_artifact_rows.csv"),
            "return_contract_map_path": "v58_blind_eval_return_contract_map_rows.csv",
            "return_contract_row_count": str(len(v58_return_contract_map_rows)),
            "return_contract_sha256": sha256(run_dir / "v58_blind_eval_return_contract_map_rows.csv"),
            "return_template_path": contract["return_template_path"],
            "return_template_kind": contract["return_template_kind"],
            "template_sha256": contract["template_sha256"],
            "validation_command": row["validation_command"],
            "acceptance_signal": row["acceptance_signal"],
            "fixture_allowed": row["fixture_allowed"],
            "approval_required": row["approval_required"],
            "template_ready": contract["template_ready"],
            "contract_ready": str(contract_ready),
            "default_acceptance_status": contract["default_acceptance_status"],
            "blind_eval_ready": "0",
            "tests_only_merge_condition": "0",
            "undocumented_local_state_required": "0",
            "private_fixture_required": "0",
            "manual_postprocessing_required": "0",
            "network_required_by_default": "0",
            "downloads_required_by_default": "0",
            "replay_command": "experiments/test_v59e_one_command_pm_foundation_demo.sh",
            "blocker": "real blind response, human review, and adjudication return artifacts are required",
            "claim_boundary": "v58 return artifact contract only; real blind-eval completion and public comparison remain blocked",
        }
    )
write_csv(run_dir / "v58_blind_eval_acceptance_evidence_rows.csv", list(v58_acceptance_evidence_rows[0].keys()), v58_acceptance_evidence_rows)
v58_required_artifact_fixture_allowed_rows = sum(1 for row in v58_required_artifact_rows if row["fixture_allowed"] == "1")
v58_required_artifact_approval_rows = sum(1 for row in v58_required_artifact_rows if row["approval_required"] == "1")
v58_return_template_fixture_allowed_rows = sum(1 for row in v58_return_template_rows if row["fixture_allowed"] == "1")
v58_return_template_ready_rows = sum(1 for row in v58_return_template_rows if row["template_ready"] == "1")
v58_return_contract_map_ready_rows = sum(1 for row in v58_return_contract_map_rows if row["status"] == "ready")
v58_acceptance_evidence_contract_ready_rows = sum(1 for row in v58_acceptance_evidence_rows if row["contract_ready"] == "1")
v58_acceptance_evidence_default_blocked_rows = sum(1 for row in v58_acceptance_evidence_rows if row["default_acceptance_status"] == "blocked")
v58_acceptance_evidence_hidden_state_rows = sum(
    1
    for row in v58_acceptance_evidence_rows
    if row["undocumented_local_state_required"] == "1"
    or row["private_fixture_required"] == "1"
    or row["manual_postprocessing_required"] == "1"
    or row["network_required_by_default"] == "1"
    or row["downloads_required_by_default"] == "1"
)
v58_return_artifact_contract_ready = int(
    len(v58_required_artifact_rows) == 8
    and len(v58_return_template_rows) == 8
    and len(v58_return_contract_map_rows) == 8
    and len(v58_acceptance_evidence_rows) == 8
    and sum(1 for row in v58_required_artifact_rows if row["blocker_class"] == "v58c-intake-artifact-missing") == 3
    and sum(1 for row in v58_required_artifact_rows if row["blocker_class"] == "v58-real-blind-eval-missing") == 5
    and v58_required_artifact_fixture_allowed_rows == 0
    and v58_required_artifact_approval_rows == 8
    and v58_return_template_fixture_allowed_rows == 0
    and v58_return_template_ready_rows == 8
    and v58_return_contract_map_ready_rows == 8
    and all(row["fixture_allowed"] == "0" for row in v58_return_contract_map_rows)
    and all(row["approval_required"] == "1" for row in v58_return_contract_map_rows)
    and all(row["template_ready"] == "1" for row in v58_return_contract_map_rows)
    and all(row["default_acceptance_status"] == "blocked" for row in v58_return_contract_map_rows)
    and v58_acceptance_evidence_contract_ready_rows == 8
    and v58_acceptance_evidence_default_blocked_rows == 8
    and v58_acceptance_evidence_hidden_state_rows == 0
    and all(row["tests_only_merge_condition"] == "0" for row in v58_acceptance_evidence_rows)
    and all(row["blind_eval_ready"] == "0" for row in v58_acceptance_evidence_rows)
)
bundle_rows.extend(
    [
        {
            "path": "v58_blind_eval_required_artifact_rows.csv",
            "source_stage": "v59e_core",
            "artifact_role": "v58_required_artifacts",
        },
        {
            "path": "v58_blind_eval_return_template_rows.csv",
            "source_stage": "v59e_core",
            "artifact_role": "v58_return_templates",
        },
        {
            "path": "v58_blind_eval_return_contract_map_rows.csv",
            "source_stage": "v59e_core",
            "artifact_role": "v58_return_contract_map",
        },
        {
            "path": "v58_blind_eval_acceptance_evidence_rows.csv",
            "source_stage": "v59e_core",
            "artifact_role": "v58_acceptance_evidence",
        },
    ]
)
pm_pr_claim_slice_bundle_ready = int(
    as_int(pr_summary, "v1_0_pm_pr_claim_slice_gate_ready") == 1
    and review_packet_ready
    and blocker_packet_ready
    and execution_lock_ready
    and external_return_template_ready
    and as_int(pr_summary, "tests_only_merge_condition_rows") == 0
    and as_int(pr_summary, "v53_pm_acceptance_evidence_ready_rows") == 10
    and as_int(pr_summary, "v53_pm_acceptance_evidence_tests_only_rows") == 0
    and as_int(pr_summary, "real_release_package_ready") == 0
)

summary["challenge_bundle_ready"] = str(
    int(as_int(summary, "challenge_bundle_ready") == 1 and pm_pr_claim_slice_bundle_ready == 1)
)
summary["bundle_files"] = str(len(bundle_rows))
summary["pm_pr_claim_slice_gate_ready"] = pr_summary["v1_0_pm_pr_claim_slice_gate_ready"]
summary["pm_pr_claim_slice_bundle_ready"] = str(pm_pr_claim_slice_bundle_ready)
summary["pm_pr_recommended_slice_rows"] = pr_summary["recommended_pr_slice_rows"]
summary["pm_pr_merge_gate_rows"] = pr_summary["merge_gate_rows"]
summary["pm_pr_current_merge_ready_rows"] = pr_summary["current_merge_ready_rows"]
summary["pm_pr_current_blocked_rows"] = pr_summary["current_blocked_rows"]
summary["pm_pr_tests_only_merge_condition_rows"] = pr_summary["tests_only_merge_condition_rows"]
summary["pm_pr_v53_query_span_binding_audit_ready"] = pr_summary.get("v53_foundation_query_span_binding_audit_ready", "0")
summary["pm_pr_v53_query_span_binding_audit_rows"] = pr_summary.get("v53_foundation_query_span_binding_audit_rows", "0")
summary["pm_pr_v53_query_span_binding_pass_rows"] = pr_summary.get("v53_foundation_query_span_binding_pass_rows", "0")
summary["pm_pr_v53_direct_pinned_manifest_ready"] = pr_summary.get("v53_foundation_direct_pinned_manifest_ready", "0")
summary["pm_pr_v53_direct_repo_manifest_rows"] = pr_summary.get("v53_foundation_direct_repo_manifest_rows", "0")
summary["pm_pr_v53_direct_file_manifest_rows"] = pr_summary.get("v53_foundation_direct_file_manifest_rows", "0")
summary["pm_pr_v53_direct_content_snapshot_rows"] = pr_summary.get("v53_foundation_direct_content_snapshot_rows", "0")
summary["pm_pr_v53_pm_acceptance_evidence_rows"] = pr_summary.get("v53_pm_acceptance_evidence_rows", "0")
summary["pm_pr_v53_pm_acceptance_evidence_ready_rows"] = pr_summary.get("v53_pm_acceptance_evidence_ready_rows", "0")
summary["pm_pr_v53_pm_acceptance_evidence_tests_only_rows"] = pr_summary.get("v53_pm_acceptance_evidence_tests_only_rows", "0")
summary["pm_pr_review_packet_rows"] = pr_summary["pm_pr_review_packet_rows"]
summary["pm_pr_review_packet_files"] = str(len(review_packet_files))
summary["pm_pr_review_packet_bundle_ready"] = str(review_packet_ready)
summary["pm_pr_acceptance_evidence_rows"] = pr_summary["pm_pr_acceptance_evidence_rows"]
summary["pm_pr_acceptance_evidence_ready_rows"] = pr_summary["pm_pr_acceptance_evidence_ready_rows"]
summary["pm_pr_acceptance_evidence_tests_only_rows"] = pr_summary["pm_pr_acceptance_evidence_tests_only_rows"]
summary["pm_pr_v56_replay_acceptance_evidence_rows"] = pr_summary.get("v56_replay_acceptance_evidence_rows", "0")
summary["pm_pr_v56_replay_acceptance_evidence_ready_rows"] = pr_summary.get("v56_replay_acceptance_evidence_ready_rows", "0")
summary["pm_pr_v56_replay_acceptance_evidence_blocked_rows"] = pr_summary.get("v56_replay_acceptance_evidence_blocked_rows", "0")
summary["pm_pr_v56_replay_acceptance_evidence_tests_only_rows"] = pr_summary.get("v56_replay_acceptance_evidence_tests_only_rows", "0")
summary["pm_pr_v56_replay_acceptance_evidence_fixture_allowed_rows"] = pr_summary.get("v56_replay_acceptance_evidence_fixture_allowed_rows", "0")
summary["pm_pr_v56_replay_acceptance_evidence_approval_rows"] = pr_summary.get("v56_replay_acceptance_evidence_approval_rows", "0")
summary["pm_pr_v56_seed_dependency_blocker_ready"] = pr_summary.get("v56_seed_dependency_blocker_ready", "0")
summary["pm_pr_v56_seed_dependency_blocker_rows"] = pr_summary.get("v56_seed_dependency_blocker_rows", "0")
summary["pm_pr_v56_missing_seed_artifact_rows"] = pr_summary.get("v56_missing_seed_artifact_rows", "0")
summary["pm_pr_v56_missing_v45_seed_artifact_rows"] = pr_summary.get("v56_missing_v45_seed_artifact_rows", "0")
summary["pm_pr_v56_missing_seed_network_or_download_approval_required"] = pr_summary.get("v56_missing_seed_network_or_download_approval_required", "0")
summary["pm_pr_de_30b70b_acceptance_evidence_rows"] = pr_summary.get("de_30b70b_acceptance_evidence_rows", "0")
summary["pm_pr_de_30b70b_acceptance_evidence_ready_rows"] = pr_summary.get("de_30b70b_acceptance_evidence_ready_rows", "0")
summary["pm_pr_de_30b70b_acceptance_evidence_blocked_rows"] = pr_summary.get("de_30b70b_acceptance_evidence_blocked_rows", "0")
summary["pm_pr_de_30b70b_acceptance_evidence_tests_only_rows"] = pr_summary.get("de_30b70b_acceptance_evidence_tests_only_rows", "0")
summary["pm_pr_de_30b70b_acceptance_evidence_fixture_allowed_rows"] = pr_summary.get("de_30b70b_acceptance_evidence_fixture_allowed_rows", "0")
summary["pm_pr_de_30b70b_acceptance_evidence_approval_rows"] = pr_summary.get("de_30b70b_acceptance_evidence_approval_rows", "0")
summary["pm_pr_v59_one_command_acceptance_evidence_rows"] = pr_summary.get("v59_one_command_acceptance_evidence_rows", "0")
summary["pm_pr_v59_one_command_acceptance_evidence_ready_rows"] = pr_summary.get("v59_one_command_acceptance_evidence_ready_rows", "0")
summary["pm_pr_v59_one_command_acceptance_evidence_blocked_rows"] = pr_summary.get("v59_one_command_acceptance_evidence_blocked_rows", "0")
summary["pm_pr_v59_one_command_acceptance_evidence_tests_only_rows"] = pr_summary.get("v59_one_command_acceptance_evidence_tests_only_rows", "0")
summary["pm_pr_v59_one_command_acceptance_evidence_fixture_allowed_rows"] = pr_summary.get("v59_one_command_acceptance_evidence_fixture_allowed_rows", "0")
summary["pm_pr_v59_one_command_acceptance_evidence_approval_rows"] = pr_summary.get("v59_one_command_acceptance_evidence_approval_rows", "0")
summary["pm_blocker_closure_packet_rows"] = pr_summary["pm_blocker_closure_packet_rows"]
summary["pm_blocker_closure_packet_files"] = str(len(blocker_packet_files))
summary["pm_blocker_closure_packet_bundle_ready"] = str(blocker_packet_ready)
summary["pm_blocker_required_artifact_rows"] = pr_summary["pm_blocker_required_artifact_rows"]
summary["pm_blocker_required_artifact_fixture_allowed_rows"] = pr_summary["pm_blocker_required_artifact_fixture_allowed_rows"]
summary["pm_execution_lock_rows"] = pr_summary["pm_execution_lock_rows"]
summary["pm_execution_lock_active_rows"] = pr_summary["pm_execution_lock_active_rows"]
summary["pm_scope_drift_allowed"] = pr_summary["pm_scope_drift_allowed"]
summary["pm_new_scaffold_default_allowed"] = pr_summary["pm_new_scaffold_default_allowed"]
summary["pm_external_return_template_rows"] = pr_summary["pm_external_return_template_rows"]
summary["pm_external_return_template_files"] = str(len(return_template_files))
summary["pm_external_return_template_fixture_allowed_rows"] = pr_summary["pm_external_return_template_fixture_allowed_rows"]
summary["pm_external_return_template_approval_rows"] = pr_summary["pm_external_return_template_approval_rows"]
summary["pm_external_return_template_bundle_ready"] = str(external_return_template_ready)
summary["v58_return_artifact_contract_ready"] = str(v58_return_artifact_contract_ready)
summary["v58_required_artifact_rows"] = str(len(v58_required_artifact_rows))
summary["v58_required_artifact_approval_rows"] = str(v58_required_artifact_approval_rows)
summary["v58_required_artifact_fixture_allowed_rows"] = str(v58_required_artifact_fixture_allowed_rows)
summary["v58_return_template_rows"] = str(len(v58_return_template_rows))
summary["v58_return_template_ready_rows"] = str(v58_return_template_ready_rows)
summary["v58_return_template_fixture_allowed_rows"] = str(v58_return_template_fixture_allowed_rows)
summary["v58_return_contract_map_rows"] = str(len(v58_return_contract_map_rows))
summary["v58_return_contract_map_ready_rows"] = str(v58_return_contract_map_ready_rows)
summary["v58_return_contract_map_default_blocked_rows"] = str(sum(1 for row in v58_return_contract_map_rows if row["default_acceptance_status"] == "blocked"))
summary["v58_acceptance_evidence_rows"] = str(len(v58_acceptance_evidence_rows))
summary["v58_acceptance_evidence_contract_ready_rows"] = str(v58_acceptance_evidence_contract_ready_rows)
summary["v58_acceptance_evidence_default_blocked_rows"] = str(v58_acceptance_evidence_default_blocked_rows)
summary["v58_acceptance_evidence_blind_eval_ready_rows"] = str(sum(1 for row in v58_acceptance_evidence_rows if row["blind_eval_ready"] == "1"))
summary["v58_acceptance_evidence_tests_only_rows"] = str(sum(1 for row in v58_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"))
summary["v58_acceptance_evidence_hidden_state_rows"] = str(v58_acceptance_evidence_hidden_state_rows)
summary["pm_roadmap_requirement_rows"] = pr_summary["pm_roadmap_requirement_rows"]
summary["pm_roadmap_ready_rows"] = pr_summary["pm_roadmap_ready_rows"]
summary["pm_roadmap_blocked_rows"] = pr_summary["pm_roadmap_blocked_rows"]
entrypoint_path = root / "examples/v1_0_architecture_challenge_pm_foundation_demo.sh"
generated_replay_path = run_dir / "pm_foundation_demo.sh"
preflight_specs = [
    (
        "entrypoint-present",
        entrypoint_path.is_file() and bool(entrypoint_path.stat().st_mode & 0o111),
        "examples/v1_0_architecture_challenge_pm_foundation_demo.sh is executable",
        "reviewer command exists in the repository",
    ),
    (
        "generated-replay-script-present",
        generated_replay_path.is_file() and bool(generated_replay_path.stat().st_mode & 0o111),
        "pm_foundation_demo.sh is generated in the bundle",
        "bundle-local replay script exists",
    ),
    (
        "pinned-source-snapshot-replay",
        as_int(summary, "pinned_public_sources_verified") == 1
        and as_int(summary, "source_snapshot_replay_used") == 1
        and as_int(summary, "public_source_snapshot_replay_ready") == 1
        and as_int(summary, "public_source_snapshot_replay_rows") == 10,
        "v53t pinned-source snapshot evidence is replayed for 10 public repos",
        "pinned public sources are checked through replayed hashes",
    ),
    (
        "no-live-download-default",
        as_int(summary, "public_source_download_executed") == 0
        and as_int(summary, "public_source_download_approval_required") == 1
        and as_int(summary, "network_required") == 0
        and as_int(summary, "downloads_required") == 0,
        "network/download execution is not required by default",
        "live public-source refresh remains approval-required",
    ),
    (
        "no-private-fixture",
        as_int(summary, "private_fixture_required") == 0,
        "private_fixture_required=0",
        "one-command PM replay does not require private fixtures",
    ),
    (
        "no-manual-postprocessing",
        as_int(summary, "manual_postprocessing_required") == 0,
        "manual_postprocessing_required=0; reviewer artifact is written by the command",
        "reviewer artifact is written by the command",
    ),
    (
        "no-undocumented-local-state",
        as_int(summary, "undocumented_local_state_required") == 0,
        "undocumented_local_state_required=0",
        "local replay state is described by copied artifacts and summaries",
    ),
    (
        "local-abgh-row-contract-replay",
        as_int(summary, "local_abgh_row_contract_replay_ready") == 1
        and as_int(summary, "local_abgh_row_contract_replay_rows") == 2
        and as_int(summary, "local_abgh_row_contract_replay_pass_rows") == 2,
        "v53ap/v53aq A/B/G/H row contracts replay answer/citation/evaluator/resource rows over 1000 queries",
        "same-query local A/B/G/H replay is row-contract checked without public comparison wording",
    ),
    (
        "pm-pr-sidecar-packaged",
        pm_pr_claim_slice_bundle_ready == 1,
        "PM PR claim-slice sidecar, packets, locks, and templates are copied",
        "review slicing evidence is packaged with the replay",
    ),
    (
        "v58-required-return-artifacts-packaged",
        v58_return_artifact_contract_ready == 1,
        "v58 blind-eval required artifact and return-template rows are packaged",
        "v58 remains blocked until real response/review artifacts are returned",
    ),
    (
        "blocker-false-positive-closed",
        as_int(summary, "blocker_false_positive_closed") == 1 and as_int(summary, "pm_pr_tests_only_merge_condition_rows") == 0,
        "blockers remain explicit and tests-only merge conditions are absent",
        "merge readiness is claim-boundary/replay/blocker based",
    ),
    (
        "no-remote-mutation",
        True,
        "no push/open/merge/release command is executed by v59e",
        "local replay is metadata/artifact generation only",
    ),
]
preflight_rows = [
    {
        "check": check,
        "status": "pass" if passed else "blocked",
        "evidence": evidence,
        "claim_boundary": claim_boundary,
    }
    for check, passed, evidence, claim_boundary in preflight_specs
]
write_csv(run_dir / "pm_foundation_replay_preflight_rows.csv", ["check", "status", "evidence", "claim_boundary"], preflight_rows)
one_command_replay_preflight_ready = int(all(row["status"] == "pass" for row in preflight_rows))
bundle_rows.append(
    {
        "path": "pm_foundation_replay_preflight_rows.csv",
        "source_stage": "v59e_core",
        "artifact_role": "preflight",
    }
)
summary["one_command_replay_preflight_ready"] = str(one_command_replay_preflight_ready)
summary["challenge_bundle_ready"] = str(
    int(as_int(summary, "challenge_bundle_ready") == 1 and pm_pr_claim_slice_bundle_ready == 1 and one_command_replay_preflight_ready == 1)
)
summary["bundle_files"] = str(len(bundle_rows))
write_csv(summary_csv, list(summary.keys()), [summary])

write_csv(run_dir / "challenge_bundle_file_rows.csv", list(bundle_rows[0].keys()), bundle_rows)

decision_rows = read_csv(decision_csv)
decision_rows.extend(
    [
        {
            "gate": "pm-pr-claim-slice-gate",
            "status": "pass" if pm_pr_claim_slice_bundle_ready else "blocked",
            "reason": "PM PR claim-slice gate, review packets, blockers, execution lock, and return templates are copied into the bundle",
        },
        {
            "gate": "pm-execution-lock",
            "status": "pass" if execution_lock_ready else "blocked",
            "reason": "v52-v60/v61 evidence closure remains locked; default v62/v63 scope drift is disallowed",
        },
        {
            "gate": "pm-external-return-templates",
            "status": "pass" if external_return_template_ready else "blocked",
            "reason": "26 no-fixture approval-required return templates are packaged for blocker closure",
        },
        {
            "gate": "v58-required-return-artifacts",
            "status": "pass" if v58_return_artifact_contract_ready else "blocked",
            "reason": "v58-specific response, identity, review, adjudication, intake, sha256 return rows, and required-artifact/template map are packaged with fixture rows forbidden",
        },
        {
            "gate": "one-command-replay-preflight",
            "status": "pass" if one_command_replay_preflight_ready else "blocked",
            "reason": "entrypoint, no-network/default-download, no-private-fixture, no-manual-postprocessing, PM sidecar, and blocker boundaries are machine-checked",
        },
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
write_csv(run_dir / "pm_foundation_demo_gate_rows.csv", ["gate", "status", "reason"], decision_rows)

(run_dir / "README_RESULT.md").write_text(
    (run_dir / "README_RESULT.md").read_text(encoding="utf-8")
    + "\nPM PR claim-slice sidecar:\n\n"
    + f"- pm_pr_claim_slice_gate_ready={summary['pm_pr_claim_slice_gate_ready']}\n"
    + f"- pm_pr_review_packet_files={summary['pm_pr_review_packet_files']}\n"
    + f"- pm_pr_v53_pm_acceptance_evidence_rows={summary['pm_pr_v53_pm_acceptance_evidence_rows']}\n"
    + f"- pm_pr_v53_pm_acceptance_evidence_ready_rows={summary['pm_pr_v53_pm_acceptance_evidence_ready_rows']}\n"
    + f"- pm_pr_v53_pm_acceptance_evidence_tests_only_rows={summary['pm_pr_v53_pm_acceptance_evidence_tests_only_rows']}\n"
    + f"- pm_blocker_closure_packet_files={summary['pm_blocker_closure_packet_files']}\n"
    + f"- pm_execution_lock_rows={summary['pm_execution_lock_rows']}\n"
    + f"- pm_scope_drift_allowed={summary['pm_scope_drift_allowed']}\n"
    + f"- pm_external_return_template_files={summary['pm_external_return_template_files']}\n"
    + f"- v58_return_artifact_contract_ready={summary['v58_return_artifact_contract_ready']}\n"
    + f"- v58_required_artifact_rows={summary['v58_required_artifact_rows']}\n"
    + f"- v58_return_template_rows={summary['v58_return_template_rows']}\n"
    + f"- v58_return_contract_map_rows={summary['v58_return_contract_map_rows']}\n"
    + f"- v58_acceptance_evidence_rows={summary['v58_acceptance_evidence_rows']}\n"
    + f"- v58_acceptance_evidence_contract_ready_rows={summary['v58_acceptance_evidence_contract_ready_rows']}\n"
    + f"- v58_acceptance_evidence_default_blocked_rows={summary['v58_acceptance_evidence_default_blocked_rows']}\n"
    + f"- v58_acceptance_evidence_blind_eval_ready_rows={summary['v58_acceptance_evidence_blind_eval_ready_rows']}\n"
    + f"- v58_acceptance_evidence_hidden_state_rows={summary['v58_acceptance_evidence_hidden_state_rows']}\n"
    + f"- one_command_replay_preflight_ready={summary['one_command_replay_preflight_ready']}\n",
    encoding="utf-8",
)

(run_dir / "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md").write_text(
    (run_dir / "V59E_ONE_COMMAND_PM_FOUNDATION_BOUNDARY.md").read_text(encoding="utf-8")
    + "\nPM PR sidecar boundary:\n\n"
    + f"- pm_pr_claim_slice_gate_ready={summary['pm_pr_claim_slice_gate_ready']}\n"
    + f"- pm_pr_claim_slice_bundle_ready={summary['pm_pr_claim_slice_bundle_ready']}\n"
    + f"- pm_pr_tests_only_merge_condition_rows={summary['pm_pr_tests_only_merge_condition_rows']}\n"
    + f"- pm_pr_v53_pm_acceptance_evidence_rows={summary['pm_pr_v53_pm_acceptance_evidence_rows']}\n"
    + f"- pm_pr_v53_pm_acceptance_evidence_ready_rows={summary['pm_pr_v53_pm_acceptance_evidence_ready_rows']}\n"
    + f"- pm_pr_v53_pm_acceptance_evidence_tests_only_rows={summary['pm_pr_v53_pm_acceptance_evidence_tests_only_rows']}\n"
    + f"- pm_scope_drift_allowed={summary['pm_scope_drift_allowed']}\n"
    + f"- pm_new_scaffold_default_allowed={summary['pm_new_scaffold_default_allowed']}\n"
    + f"- pm_external_return_template_fixture_allowed_rows={summary['pm_external_return_template_fixture_allowed_rows']}\n"
    + f"- v58_return_artifact_contract_ready={summary['v58_return_artifact_contract_ready']}\n"
    + f"- v58_required_artifact_fixture_allowed_rows={summary['v58_required_artifact_fixture_allowed_rows']}\n"
    + f"- v58_return_template_fixture_allowed_rows={summary['v58_return_template_fixture_allowed_rows']}\n"
    + f"- v58_return_contract_map_default_blocked_rows={summary['v58_return_contract_map_default_blocked_rows']}\n"
    + f"- v58_acceptance_evidence_rows={summary['v58_acceptance_evidence_rows']}\n"
    + f"- v58_acceptance_evidence_contract_ready_rows={summary['v58_acceptance_evidence_contract_ready_rows']}\n"
    + f"- v58_acceptance_evidence_default_blocked_rows={summary['v58_acceptance_evidence_default_blocked_rows']}\n"
    + f"- v58_acceptance_evidence_blind_eval_ready_rows={summary['v58_acceptance_evidence_blind_eval_ready_rows']}\n"
    + f"- v58_acceptance_evidence_tests_only_rows={summary['v58_acceptance_evidence_tests_only_rows']}\n"
    + f"- v58_acceptance_evidence_hidden_state_rows={summary['v58_acceptance_evidence_hidden_state_rows']}\n"
    + f"- one_command_replay_preflight_ready={summary['one_command_replay_preflight_ready']}\n",
    encoding="utf-8",
)

manifest_path = run_dir / "v59e_one_command_pm_foundation_demo_manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["bundle_files"] = len(bundle_rows)
manifest["pm_pr_claim_slice_gate_ready"] = as_int(pr_summary, "v1_0_pm_pr_claim_slice_gate_ready")
manifest["pm_pr_claim_slice_bundle_ready"] = pm_pr_claim_slice_bundle_ready
manifest["pm_pr_review_packet_files"] = len(review_packet_files)
manifest["pm_pr_acceptance_evidence_rows"] = as_int(pr_summary, "pm_pr_acceptance_evidence_rows")
manifest["pm_pr_acceptance_evidence_ready_rows"] = as_int(pr_summary, "pm_pr_acceptance_evidence_ready_rows")
manifest["pm_pr_acceptance_evidence_tests_only_rows"] = as_int(pr_summary, "pm_pr_acceptance_evidence_tests_only_rows")
manifest["pm_pr_v56_replay_acceptance_evidence_rows"] = as_int(pr_summary, "v56_replay_acceptance_evidence_rows")
manifest["pm_pr_v56_replay_acceptance_evidence_ready_rows"] = as_int(pr_summary, "v56_replay_acceptance_evidence_ready_rows")
manifest["pm_pr_v56_replay_acceptance_evidence_blocked_rows"] = as_int(pr_summary, "v56_replay_acceptance_evidence_blocked_rows")
manifest["pm_pr_v56_replay_acceptance_evidence_tests_only_rows"] = as_int(pr_summary, "v56_replay_acceptance_evidence_tests_only_rows")
manifest["pm_pr_v56_replay_acceptance_evidence_fixture_allowed_rows"] = as_int(pr_summary, "v56_replay_acceptance_evidence_fixture_allowed_rows")
manifest["pm_pr_v56_replay_acceptance_evidence_approval_rows"] = as_int(pr_summary, "v56_replay_acceptance_evidence_approval_rows")
manifest["pm_pr_v56_seed_dependency_blocker_ready"] = as_int(pr_summary, "v56_seed_dependency_blocker_ready")
manifest["pm_pr_v56_seed_dependency_blocker_rows"] = as_int(pr_summary, "v56_seed_dependency_blocker_rows")
manifest["pm_pr_v56_missing_seed_artifact_rows"] = as_int(pr_summary, "v56_missing_seed_artifact_rows")
manifest["pm_pr_v56_missing_v45_seed_artifact_rows"] = as_int(pr_summary, "v56_missing_v45_seed_artifact_rows")
manifest["pm_pr_v56_missing_seed_network_or_download_approval_required"] = as_int(pr_summary, "v56_missing_seed_network_or_download_approval_required")
manifest["pm_pr_de_30b70b_acceptance_evidence_rows"] = as_int(pr_summary, "de_30b70b_acceptance_evidence_rows")
manifest["pm_pr_de_30b70b_acceptance_evidence_ready_rows"] = as_int(pr_summary, "de_30b70b_acceptance_evidence_ready_rows")
manifest["pm_pr_de_30b70b_acceptance_evidence_blocked_rows"] = as_int(pr_summary, "de_30b70b_acceptance_evidence_blocked_rows")
manifest["pm_pr_de_30b70b_acceptance_evidence_tests_only_rows"] = as_int(pr_summary, "de_30b70b_acceptance_evidence_tests_only_rows")
manifest["pm_pr_de_30b70b_acceptance_evidence_fixture_allowed_rows"] = as_int(pr_summary, "de_30b70b_acceptance_evidence_fixture_allowed_rows")
manifest["pm_pr_de_30b70b_acceptance_evidence_approval_rows"] = as_int(pr_summary, "de_30b70b_acceptance_evidence_approval_rows")
manifest["pm_pr_v59_one_command_acceptance_evidence_rows"] = as_int(pr_summary, "v59_one_command_acceptance_evidence_rows")
manifest["pm_pr_v59_one_command_acceptance_evidence_ready_rows"] = as_int(pr_summary, "v59_one_command_acceptance_evidence_ready_rows")
manifest["pm_pr_v59_one_command_acceptance_evidence_blocked_rows"] = as_int(pr_summary, "v59_one_command_acceptance_evidence_blocked_rows")
manifest["pm_pr_v59_one_command_acceptance_evidence_tests_only_rows"] = as_int(pr_summary, "v59_one_command_acceptance_evidence_tests_only_rows")
manifest["pm_pr_v59_one_command_acceptance_evidence_fixture_allowed_rows"] = as_int(pr_summary, "v59_one_command_acceptance_evidence_fixture_allowed_rows")
manifest["pm_pr_v59_one_command_acceptance_evidence_approval_rows"] = as_int(pr_summary, "v59_one_command_acceptance_evidence_approval_rows")
manifest["pm_pr_v53_query_span_binding_audit_ready"] = as_int(pr_summary, "v53_foundation_query_span_binding_audit_ready")
manifest["pm_pr_v53_query_span_binding_audit_rows"] = as_int(pr_summary, "v53_foundation_query_span_binding_audit_rows")
manifest["pm_pr_v53_query_span_binding_pass_rows"] = as_int(pr_summary, "v53_foundation_query_span_binding_pass_rows")
manifest["pm_pr_v53_direct_pinned_manifest_ready"] = as_int(pr_summary, "v53_foundation_direct_pinned_manifest_ready")
manifest["pm_pr_v53_direct_repo_manifest_rows"] = as_int(pr_summary, "v53_foundation_direct_repo_manifest_rows")
manifest["pm_pr_v53_direct_file_manifest_rows"] = as_int(pr_summary, "v53_foundation_direct_file_manifest_rows")
manifest["pm_pr_v53_direct_content_snapshot_rows"] = as_int(pr_summary, "v53_foundation_direct_content_snapshot_rows")
manifest["pm_pr_v53_pm_acceptance_evidence_rows"] = as_int(pr_summary, "v53_pm_acceptance_evidence_rows")
manifest["pm_pr_v53_pm_acceptance_evidence_ready_rows"] = as_int(pr_summary, "v53_pm_acceptance_evidence_ready_rows")
manifest["pm_pr_v53_pm_acceptance_evidence_tests_only_rows"] = as_int(pr_summary, "v53_pm_acceptance_evidence_tests_only_rows")
manifest["pm_blocker_closure_packet_files"] = len(blocker_packet_files)
manifest["pm_execution_lock_rows"] = as_int(pr_summary, "pm_execution_lock_rows")
manifest["pm_scope_drift_allowed"] = as_int(pr_summary, "pm_scope_drift_allowed")
manifest["pm_external_return_template_files"] = len(return_template_files)
manifest["v58_return_artifact_contract_ready"] = v58_return_artifact_contract_ready
manifest["v58_required_artifact_rows"] = len(v58_required_artifact_rows)
manifest["v58_required_artifact_fixture_allowed_rows"] = v58_required_artifact_fixture_allowed_rows
manifest["v58_return_template_rows"] = len(v58_return_template_rows)
manifest["v58_return_template_ready_rows"] = v58_return_template_ready_rows
manifest["v58_return_template_fixture_allowed_rows"] = v58_return_template_fixture_allowed_rows
manifest["v58_return_contract_map_rows"] = len(v58_return_contract_map_rows)
manifest["v58_return_contract_map_ready_rows"] = v58_return_contract_map_ready_rows
manifest["v58_return_contract_map_default_blocked_rows"] = sum(1 for row in v58_return_contract_map_rows if row["default_acceptance_status"] == "blocked")
manifest["v58_acceptance_evidence_rows"] = len(v58_acceptance_evidence_rows)
manifest["v58_acceptance_evidence_contract_ready_rows"] = v58_acceptance_evidence_contract_ready_rows
manifest["v58_acceptance_evidence_default_blocked_rows"] = v58_acceptance_evidence_default_blocked_rows
manifest["v58_acceptance_evidence_blind_eval_ready_rows"] = sum(1 for row in v58_acceptance_evidence_rows if row["blind_eval_ready"] == "1")
manifest["v58_acceptance_evidence_tests_only_rows"] = sum(1 for row in v58_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1")
manifest["v58_acceptance_evidence_hidden_state_rows"] = v58_acceptance_evidence_hidden_state_rows
manifest["one_command_replay_preflight_ready"] = one_command_replay_preflight_ready
manifest["pm_foundation_replay_preflight_rows_sha256"] = sha256(run_dir / "pm_foundation_replay_preflight_rows.csv")
manifest["local_abgh_row_contract_replay_rows_sha256"] = sha256(run_dir / "local_abgh_row_contract_replay_rows.csv")
manifest["v58_blind_eval_required_artifact_rows_sha256"] = sha256(run_dir / "v58_blind_eval_required_artifact_rows.csv")
manifest["v58_blind_eval_return_template_rows_sha256"] = sha256(run_dir / "v58_blind_eval_return_template_rows.csv")
manifest["v58_blind_eval_return_contract_map_rows_sha256"] = sha256(run_dir / "v58_blind_eval_return_contract_map_rows.csv")
manifest["v58_blind_eval_acceptance_evidence_rows_sha256"] = sha256(run_dir / "v58_blind_eval_acceptance_evidence_rows.csv")
manifest["pm_pr_v56_replay_acceptance_evidence_rows_sha256"] = sha256(run_dir / "source_pm_pr_claim_slice_gate/v56_replay_acceptance_evidence_rows.csv")
manifest["pm_pr_v56_seed_dependency_blocker_rows_sha256"] = sha256(run_dir / "source_pm_pr_claim_slice_gate/source_v56/v56_seed_dependency_blocker_rows.csv")
manifest["pm_pr_de_30b70b_acceptance_evidence_rows_sha256"] = sha256(run_dir / "source_pm_pr_claim_slice_gate/de_30b70b_acceptance_evidence_rows.csv")
manifest["pm_pr_v59_one_command_acceptance_evidence_rows_sha256"] = sha256(run_dir / "source_pm_pr_claim_slice_gate/v59_one_command_acceptance_evidence_rows.csv")
manifest["public_source_snapshot_replay_rows_sha256"] = sha256(run_dir / "public_source_snapshot_replay_rows.csv")
manifest["source_summary_sha256"]["pm_pr_claim_slice_gate"] = sha256(pr_summary_csv)
manifest["pm_pr_claim_slice_gate_manifest_sha256"] = sha256(pr_run_dir / "v1_0_pm_pr_claim_slice_gate_manifest.json")
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v59e PM PR sidecar bundle ready: {pm_pr_claim_slice_bundle_ready}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
