#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53t_complete_source_audit_readiness_gate"
RUN_ID="${V53T_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53T_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" && -s "$RUN_DIR/complete_source_pm_freeze_check_rows.csv" && -s "$RUN_DIR/complete_source_foundation_freeze_rows.csv" && -s "$RUN_DIR/complete_source_pm_acceptance_evidence_rows.csv" && -s "$RUN_DIR/complete_source_abgh_real_adapter_freeze_rows.csv" && -s "$RUN_DIR/complete_source_query_span_binding_audit_rows.csv" && -s "$RUN_DIR/source_v53i/complete_source_query_rows.csv" && -s "$RUN_DIR/source_v53i/complete_source_span_rows.csv" && -s "$RUN_DIR/source_v53i/source_v53h/complete_source_content_repo_rows.csv" && -s "$RUN_DIR/source_v53i/source_v53h/complete_source_content_snapshot_rows.csv" && -s "$RUN_DIR/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv" && -s "$RUN_DIR/source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv" && -s "$RUN_DIR/source_v53ap/abgh_system_metric_rows.csv" && -s "$RUN_DIR/source_v53ap/abgh_evaluator_rows.csv" && -s "$RUN_DIR/source_v53ap/abgh_adapter_trace_rows.csv" && -s "$RUN_DIR/source_v53aq/abgh_system_metric_rows.csv" && -s "$RUN_DIR/source_v53aq/abgh_evaluator_rows.csv" && -s "$RUN_DIR/source_v53aq/adapter_selection_contract_rows.csv" && -s "$RUN_DIR/source_v53aq/abgh_same_query_internal_prebaseline_rows.csv" ]] && grep -q 'missing_specific_control_rows=30' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'pm_acceptance_evidence_rows=10' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'abgh_same_query_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'v53ap_deterministic_source_span_adapter_execution=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'v53ap_actual_adapter_execution_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_machine_freeze_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_direct_evidence_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_query_span_binding_audit_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_direct_pinned_manifest_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_real_adapter_evidence_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'foundation_real_adapter_same_query_ledger_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md" && grep -q 'v53aq_real_adapter_execution_ready=1' "$RUN_DIR/V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md"; then
  echo "v53t_complete_source_audit_readiness_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null
V53AP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ap_complete_source_abgh_same_query_measured.sh" >/dev/null
V53AQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh" >/dev/null
V53S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
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


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


summary_paths = {
    "v52y": results / "v52y_f_optional_final_policy_summary.csv",
    "v53i": results / "v53i_complete_source_query_instantiation_summary.csv",
    "v53ap": results / "v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "v53aq": results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "v53q": results / "v53q_complete_source_symmetric_scorer_policy_summary.csv",
    "v53r": results / "v53r_complete_source_review_packet_summary.csv",
    "v53s": results / "v53s_complete_source_review_return_intake_summary.csv",
}
decision_paths = {
    "v52y": results / "v52y_f_optional_final_policy_decision.csv",
    "v53q": results / "v53q_complete_source_symmetric_scorer_policy_decision.csv",
    "v53r": results / "v53r_complete_source_review_packet_decision.csv",
    "v53s": results / "v53s_complete_source_review_return_intake_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for key, field in [
    ("v52y", "v52y_f_optional_final_policy_ready"),
    ("v53i", "v53i_complete_source_query_instantiation_ready"),
    ("v53ap", "v53ap_complete_source_abgh_same_query_measured_ready"),
    ("v53aq", "v53aq_complete_source_abgh_real_adapter_measured_ready"),
    ("v53q", "v53q_complete_source_symmetric_scorer_policy_ready"),
    ("v53r", "v53r_complete_source_review_packet_ready"),
    ("v53s", "v53s_complete_source_review_return_intake_ready"),
]:
    if summaries[key].get(field) != "1":
        raise SystemExit(f"v53t requires {field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

v53i_dir = results / "v53i_complete_source_query_instantiation" / "instantiate_001"
v53ap_dir = results / "v53ap_complete_source_abgh_same_query_measured" / "measured_001"
v53aq_dir = results / "v53aq_complete_source_abgh_real_adapter_measured" / "measured_001"
v53q_dir = results / "v53q_complete_source_symmetric_scorer_policy" / "score_001"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v53s_dir = results / "v53s_complete_source_review_return_intake" / "intake_001"
for src, rel in [
    (v53i_dir / "complete_source_query_rows.csv", "source_v53i/complete_source_query_rows.csv"),
    (v53i_dir / "complete_source_span_rows.csv", "source_v53i/complete_source_span_rows.csv"),
    (v53i_dir / "complete_source_query_family_rows.csv", "source_v53i/complete_source_query_family_rows.csv"),
    (v53i_dir / "complete_source_control_family_rows.csv", "source_v53i/complete_source_control_family_rows.csv"),
    (v53i_dir / "complete_source_query_repo_rows.csv", "source_v53i/complete_source_query_repo_rows.csv"),
    (v53i_dir / "source_v53h/complete_source_content_repo_rows.csv", "source_v53i/source_v53h/complete_source_content_repo_rows.csv"),
    (v53i_dir / "source_v53h/complete_source_content_snapshot_rows.csv", "source_v53i/source_v53h/complete_source_content_snapshot_rows.csv"),
    (v53i_dir / "source_v53h/source_v53g/complete_source_repo_coverage_rows.csv", "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv"),
    (v53i_dir / "source_v53h/source_v53g/complete_source_file_manifest_rows.csv", "source_v53i/source_v53h/source_v53g/complete_source_file_manifest_rows.csv"),
    (v53i_dir / "source_v53h/source_v53g/complete_source_query_budget_rows.csv", "source_v53i/source_v53h/source_v53g/complete_source_query_budget_rows.csv"),
    (v53i_dir / "source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv", "source_v53i/source_v53h/source_v53g/v53g_complete_source_manifest_summary.csv"),
    (v53ap_dir / "abgh_system_rows.csv", "source_v53ap/abgh_system_rows.csv"),
    (v53ap_dir / "abgh_answer_rows.csv", "source_v53ap/abgh_answer_rows.csv"),
    (v53ap_dir / "abgh_citation_rows.csv", "source_v53ap/abgh_citation_rows.csv"),
    (v53ap_dir / "abgh_evaluator_rows.csv", "source_v53ap/abgh_evaluator_rows.csv"),
    (v53ap_dir / "abgh_resource_rows.csv", "source_v53ap/abgh_resource_rows.csv"),
    (v53ap_dir / "abgh_adapter_trace_rows.csv", "source_v53ap/abgh_adapter_trace_rows.csv"),
    (v53ap_dir / "abgh_system_metric_rows.csv", "source_v53ap/abgh_system_metric_rows.csv"),
    (v53ap_dir / "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md", "source_v53ap/V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md"),
    (v53aq_dir / "adapter_selection_contract_rows.csv", "source_v53aq/adapter_selection_contract_rows.csv"),
    (v53aq_dir / "abgh_answer_rows.csv", "source_v53aq/abgh_answer_rows.csv"),
    (v53aq_dir / "abgh_citation_rows.csv", "source_v53aq/abgh_citation_rows.csv"),
    (v53aq_dir / "abgh_evaluator_rows.csv", "source_v53aq/abgh_evaluator_rows.csv"),
    (v53aq_dir / "abgh_resource_rows.csv", "source_v53aq/abgh_resource_rows.csv"),
    (v53aq_dir / "abgh_adapter_trace_rows.csv", "source_v53aq/abgh_adapter_trace_rows.csv"),
    (v53aq_dir / "abgh_system_metric_rows.csv", "source_v53aq/abgh_system_metric_rows.csv"),
    (v53aq_dir / "abgh_same_query_internal_prebaseline_rows.csv", "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv"),
    (v53aq_dir / "route_memory_rows.csv", "source_v53aq/route_memory_rows.csv"),
    (v53aq_dir / "routehint_rows.csv", "source_v53aq/routehint_rows.csv"),
    (v53aq_dir / "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md", "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md"),
    (v53q_dir / "symmetric_system_metric_rows.csv", "source_v53q/symmetric_system_metric_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53s_dir / "review_return_metric_rows.csv", "source_v53s/review_return_metric_rows.csv"),
    (v53s_dir / "review_return_artifact_gate_rows.csv", "source_v53s/review_return_artifact_gate_rows.csv"),
    (v53s_dir / "review_return_required_field_rows.csv", "source_v53s/review_return_required_field_rows.csv"),
]:
    copy(src, rel)

v52y = summaries["v52y"]
v53i = summaries["v53i"]
v53ap = summaries["v53ap"]
v53aq = summaries["v53aq"]
v53q = summaries["v53q"]
v53r = summaries["v53r"]
v53s = summaries["v53s"]

v53i_family_rows = read_csv(v53i_dir / "complete_source_query_family_rows.csv")
v53i_query_rows = read_csv(v53i_dir / "complete_source_query_rows.csv")
v53i_span_rows = read_csv(v53i_dir / "complete_source_span_rows.csv")
v53i_content_repo_rows = read_csv(v53i_dir / "source_v53h/complete_source_content_repo_rows.csv")
v53i_content_snapshot_rows = read_csv(v53i_dir / "source_v53h/complete_source_content_snapshot_rows.csv")
v53i_repo_coverage_rows = read_csv(v53i_dir / "source_v53h/source_v53g/complete_source_repo_coverage_rows.csv")
v53i_file_manifest_rows = read_csv(v53i_dir / "source_v53h/source_v53g/complete_source_file_manifest_rows.csv")
v53ap_answer_rows = read_csv(v53ap_dir / "abgh_answer_rows.csv")
v53ap_citation_rows = read_csv(v53ap_dir / "abgh_citation_rows.csv")
v53ap_evaluator_rows = read_csv(v53ap_dir / "abgh_evaluator_rows.csv")
v53ap_resource_rows = read_csv(v53ap_dir / "abgh_resource_rows.csv")
v53ap_adapter_trace_rows = read_csv(v53ap_dir / "abgh_adapter_trace_rows.csv")
v53ap_system_metric_rows = read_csv(v53ap_dir / "abgh_system_metric_rows.csv")
v53aq_answer_rows = read_csv(v53aq_dir / "abgh_answer_rows.csv")
v53aq_citation_rows = read_csv(v53aq_dir / "abgh_citation_rows.csv")
v53aq_evaluator_rows = read_csv(v53aq_dir / "abgh_evaluator_rows.csv")
v53aq_resource_rows = read_csv(v53aq_dir / "abgh_resource_rows.csv")
v53aq_adapter_trace_rows = read_csv(v53aq_dir / "abgh_adapter_trace_rows.csv")
v53aq_system_metric_rows = read_csv(v53aq_dir / "abgh_system_metric_rows.csv")
v53aq_selection_contract_rows = read_csv(v53aq_dir / "adapter_selection_contract_rows.csv")
v53aq_same_query_internal_prebaseline_rows = read_csv(v53aq_dir / "abgh_same_query_internal_prebaseline_rows.csv")
family_query_rows = {
    row["audit_type"]: int(row["complete_source_query_rows"])
    for row in v53i_family_rows
}
system_metric_by_id = {row["system_id"]: row for row in v53ap_system_metric_rows}
unsupported_control_rows = family_query_rows.get("unsupported_claim_abstain", 0)
ambiguous_control_rows = family_query_rows.get("ambiguous_source_abstain", 0)
missing_specific_control_rows = sum(
    count for family, count in family_query_rows.items() if "missing" in family
)
doc_code_conflict_rows = family_query_rows.get("doc_code_conflict", 0)
foundation_direct_repo_manifest_ready = int(
    len(v53i_repo_coverage_rows) == 10
    and all(len(row.get("head_sha", "")) == 40 for row in v53i_repo_coverage_rows)
    and all(row.get("complete_source_tree_manifest_ready") == "1" for row in v53i_repo_coverage_rows)
    and sum(int(row.get("query_eligible_file_rows", "0") or "0") for row in v53i_repo_coverage_rows) > 0
)
foundation_direct_content_snapshot_ready = int(
    len(v53i_content_repo_rows) == 10
    and all(len(row.get("head_sha", "")) == 40 for row in v53i_content_repo_rows)
    and all(row.get("content_snapshot_ready") == "1" for row in v53i_content_repo_rows)
    and sum(int(row.get("content_materialized_file_rows", "0") or "0") for row in v53i_content_repo_rows) > 0
)
foundation_direct_pinned_manifest_ready = int(
    foundation_direct_repo_manifest_ready
    and foundation_direct_content_snapshot_ready
    and len(v53i_file_manifest_rows) > 0
    and len(v53i_content_snapshot_rows) > 0
)
span_by_id = {row["source_span_id"]: row for row in v53i_span_rows}
content_by_source = {
    (row["owner_repo"], row["path"], row["content_sha256"]): row
    for row in v53i_content_snapshot_rows
}
query_span_binding_rows = []
for query in v53i_query_rows:
    span = span_by_id.get(query["source_span_id"], {})
    content = content_by_source.get(
        (query["owner_repo"], query["source_path"], query["source_file_sha256"]),
        {},
    )
    checks = {
        "source_span_required": query.get("source_span_required") == "1",
        "span_row_present": bool(span),
        "query_id_match": span.get("query_id") == query.get("query_id"),
        "owner_repo_match": span.get("owner_repo") == query.get("owner_repo"),
        "head_sha_match": span.get("head_sha") == query.get("head_sha"),
        "path_match": span.get("path") == query.get("source_path"),
        "line_start_match": span.get("line_start") == query.get("source_line_start"),
        "line_end_match": span.get("line_end") == query.get("source_line_end"),
        "source_file_sha256_match": span.get("source_file_sha256") == query.get("source_file_sha256"),
        "git_blob_sha_match": span.get("git_blob_sha") == query.get("source_git_blob_sha"),
        "content_row_present": bool(content),
        "content_row_materialized": content.get("content_materialized") == "1",
    }
    binding_pass = int(all(checks.values()))
    query_span_binding_rows.append(
        {
            "binding_audit_id": f"v53t_bind_{query['query_id']}",
            "query_id": query["query_id"],
            "source_span_id": query["source_span_id"],
            "owner_repo": query["owner_repo"],
            "head_sha": query["head_sha"],
            "source_path": query["source_path"],
            "source_line_start": query["source_line_start"],
            "source_line_end": query["source_line_end"],
            "source_file_sha256": query["source_file_sha256"],
            "source_git_blob_sha": query["source_git_blob_sha"],
            **{key: str(int(value)) for key, value in checks.items()},
            "binding_status": "pass" if binding_pass else "blocked",
            "claim_boundary": "source-span binding audit only; not human-reviewed correctness",
        }
    )
write_csv(
    run_dir / "complete_source_query_span_binding_audit_rows.csv",
    list(query_span_binding_rows[0].keys()),
    query_span_binding_rows,
)
foundation_query_span_binding_audit_rows = len(query_span_binding_rows)
foundation_query_span_binding_pass_rows = sum(1 for row in query_span_binding_rows if row["binding_status"] == "pass")
foundation_query_span_binding_blocked_rows = foundation_query_span_binding_audit_rows - foundation_query_span_binding_pass_rows
foundation_query_span_binding_audit_ready = int(
    foundation_query_span_binding_audit_rows == 1000
    and foundation_query_span_binding_pass_rows == 1000
    and foundation_query_span_binding_blocked_rows == 0
)
current_v53i_query_rows_sha256 = sha256(v53i_dir / "complete_source_query_rows.csv")
v53ap_query_rows_sha256 = v53ap["source_query_rows_sha256"]
v53aq_query_rows_sha256 = v53aq["source_query_rows_sha256"]
same_complete_source_query_hash = int(current_v53i_query_rows_sha256 == v53ap_query_rows_sha256)
v53aq_same_complete_source_query_hash = int(current_v53i_query_rows_sha256 == v53aq_query_rows_sha256)
abgh_systems = ("A", "B", "G", "H")
abgh_same_query_ready = int(
    same_complete_source_query_hash
    and
    all(
        system_metric_by_id.get(system_id, {}).get("answer_rows") == "1000"
        and (
            system_metric_by_id.get(system_id, {}).get("citation_span_match_rows") == "1000"
            or system_metric_by_id.get(system_id, {}).get("citation_correct_rows") == "1000"
        )
        and (
            system_metric_by_id.get(system_id, {}).get("resource_row_bound_rows") == "1000"
            or system_metric_by_id.get(system_id, {}).get("resource_rows") == "1000"
        )
        for system_id in abgh_systems
    )
)
v53i_query_ids = {row["query_id"] for row in v53i_query_rows}
foundation_direct_evaluator_separate_rows = sum(
    1
    for row in v53ap_evaluator_rows
    if row.get("answer_eval_separate") == "1"
    and row.get("citation_eval_separate") == "1"
    and row.get("resource_eval_separate") == "1"
    and row.get("answer_hash_match") == "1"
    and row.get("citation_span_match") == "1"
    and row.get("resource_row_bound") == "1"
    and row.get("source_span_binding_match") == "1"
)
foundation_direct_same_query_rows_ready = int(
    all(
        {row["query_id"] for row in v53ap_evaluator_rows if row["system_id"] == system_id}
        == v53i_query_ids
        for system_id in abgh_systems
    )
)
foundation_direct_evidence_ready = int(
    len(v53i_query_rows) == 1000
    and len(v53i_span_rows) == 1000
    and all(row["source_span_id"] for row in v53i_query_rows)
    and foundation_query_span_binding_audit_ready == 1
    and len(v53ap_answer_rows) == 4000
    and len(v53ap_citation_rows) == 4000
    and len(v53ap_evaluator_rows) == 4000
    and len(v53ap_resource_rows) == 4000
    and len(v53ap_adapter_trace_rows) == 4000
    and foundation_direct_evaluator_separate_rows == 4000
    and foundation_direct_same_query_rows_ready == 1
)
v53aq_selection_contract_by_field = {row["field_name"]: row for row in v53aq_selection_contract_rows}
v53aq_question_only_selection_contract_ready = int(
    v53aq_selection_contract_by_field.get("question", {}).get("selection_allowed") == "1"
    and all(
        v53aq_selection_contract_by_field.get(field, {}).get("selection_allowed") == "0"
        for field in [
            "query_id",
            "expected_answer",
            "expected_answer_sha256",
            "source_span_id",
            "source_path",
            "source_line_start",
            "source_line_end",
        ]
    )
)
foundation_real_adapter_evaluator_rows = sum(
    1
    for row in v53aq_evaluator_rows
    if row.get("answer_eval_separate") == "1"
    and row.get("citation_eval_separate") == "1"
    and row.get("resource_eval_separate") == "1"
    and row.get("resource_row_bound") == "1"
    and row.get("selection_question_text_only") == "1"
    and row.get("selection_oracle_field_used") == "0"
    and row.get("expected_answer_oracle_replay") == "0"
    and row.get("deterministic_source_span_adapter_execution") == "0"
    and row.get("real_system_performance_claim_ready") == "1"
)
foundation_real_adapter_same_query_rows_ready = int(
    all(
        {row["query_id"] for row in v53aq_evaluator_rows if row["system_id"] == system_id}
        == v53i_query_ids
        for system_id in abgh_systems
    )
)
foundation_real_adapter_same_query_ledger_rows = len(v53aq_same_query_internal_prebaseline_rows)
foundation_real_adapter_same_query_ledger_ready = int(
    foundation_real_adapter_same_query_ledger_rows == 1000
    and {row["query_id"] for row in v53aq_same_query_internal_prebaseline_rows} == v53i_query_ids
    and all(row.get("same_query_all_systems") == "1" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("same_evaluator_contract") == "1" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("same_resource_bound") == "1" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("selection_question_text_only_all") == "1" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("selection_oracle_field_used_any") == "0" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("expected_answer_oracle_replay_any") == "0" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("deterministic_source_span_adapter_execution_any") == "0" for row in v53aq_same_query_internal_prebaseline_rows)
    and all(row.get("public_comparison_claim_ready") == "0" for row in v53aq_same_query_internal_prebaseline_rows)
)
foundation_real_adapter_evidence_ready = int(
    v53aq_same_complete_source_query_hash == 1
    and v53aq_question_only_selection_contract_ready == 1
    and foundation_real_adapter_same_query_ledger_ready == 1
    and v53aq.get("v53aq_complete_source_abgh_real_adapter_measured_ready") == "1"
    and v53aq.get("real_adapter_execution_ready") == "1"
    and v53aq.get("actual_adapter_execution_ready") == "1"
    and v53aq.get("selection_question_text_only") == "1"
    and v53aq.get("selection_oracle_field_used") == "0"
    and v53aq.get("expected_answer_oracle_replay") == "0"
    and v53aq.get("deterministic_source_span_adapter_execution") == "0"
    and v53aq.get("public_comparison_claim_ready") == "0"
    and len(v53aq_answer_rows) == 4000
    and len(v53aq_citation_rows) == 4000
    and len(v53aq_evaluator_rows) == 4000
    and len(v53aq_resource_rows) == 4000
    and len(v53aq_adapter_trace_rows) == 4000
    and foundation_real_adapter_evaluator_rows == 4000
    and foundation_real_adapter_same_query_rows_ready == 1
)

requirements = [
    {
        "requirement_id": "f-optional-final-disposition",
        "status": "pass" if v52y["f_optional_final_disposition_ready"] == "1" else "blocked",
        "required_value": "supplied-ready-or-deferred-with-reason-final",
        "actual_value": v52y["f_optional_final_disposition"],
        "reason": "F optional 100B+ baseline must be supplied or explicitly final-deferred",
    },
    {
        "requirement_id": "complete-source-content-and-query-surface",
        "status": "pass" if v53i["complete_source_query_rows_ready"] == "1" and v53i["repo_count"] == "10" and foundation_direct_pinned_manifest_ready else "blocked",
        "required_value": "10 direct pinned repos / 1000 queries / 1000 spans",
        "actual_value": f"{v53i['repo_count']} repos / {v53i['complete_source_query_rows']} queries / {v53i['complete_source_span_rows']} spans / direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}",
        "reason": "complete source snapshot and query/span surface must meet the v1.0 minimum",
    },
    {
        "requirement_id": "core-a-b-c-d-e-g-h-answer-citation-resource",
        "status": "pass" if v53q["answer_citation_resource_rows_ready"] == "1" and v53q["core_answer_rows"] == "7000" else "blocked",
        "required_value": "7000 core A/B/C/D/E/G/H answer/citation/resource rows",
        "actual_value": v53q["core_answer_rows"],
        "reason": "all seven required core systems must supply rows over the same complete-source query set",
    },
    {
        "requirement_id": "symmetric-scorer-policy-surface",
        "status": "pass" if v53q["symmetric_scorer_policy_rows_ready"] == "1" else "blocked",
        "required_value": "7000 scorer rows and 7000 policy rows",
        "actual_value": f"{v53q['symmetric_scorer_rows']} scorer / {v53q['symmetric_policy_rows']} policy",
        "reason": "all core systems must be evaluated under the same source/policy rules",
    },
    {
        "requirement_id": "review-packet-ready",
        "status": "pass" if v53r["review_packet_ready"] == "1" else "blocked",
        "required_value": "1000 query packets / 7000 answer packets / 7000 queue rows",
        "actual_value": f"{v53r['review_query_packet_rows']} query / {v53r['review_answer_packet_rows']} answer / {v53r['review_queue_rows']} queue",
        "reason": "human review surface must be frozen before external review return",
    },
    {
        "requirement_id": "human-review-return-accepted",
        "status": "pass" if v53s["human_review_completed"] == "1" else "blocked",
        "required_value": v53s["expected_human_review_rows"],
        "actual_value": v53s["accepted_human_review_rows"],
        "reason": "all answer packets require accepted human/source review rows",
    },
    {
        "requirement_id": "adjudication-return-accepted",
        "status": "pass" if v53s["adjudication_completed"] == "1" else "blocked",
        "required_value": v53s["expected_adjudication_rows"],
        "actual_value": v53s["accepted_adjudication_rows"],
        "reason": "all p0 mismatch/policy-conflict rows require adjudication",
    },
    {
        "requirement_id": "reviewer-identity-conflict-ready",
        "status": "pass" if v53s["reviewer_identity_ready"] == "1" and v53s["conflict_disclosure_ready"] == "1" else "blocked",
        "required_value": "reviewer identity and conflict disclosures accepted",
        "actual_value": f"identity={v53s['accepted_reviewer_identity_rows']}; conflict={v53s['accepted_conflict_disclosure_rows']}",
        "reason": "human review must include reviewer independence and conflict evidence",
    },
    {
        "requirement_id": "quality-comparison-claim-ready",
        "status": "pass" if v53s["quality_comparison_claim_ready"] == "1" else "blocked",
        "required_value": "1",
        "actual_value": v53s["quality_comparison_claim_ready"],
        "reason": "comparison wording waits for accepted review returns and final audit",
    },
    {
        "requirement_id": "release-package-ready",
        "status": "pass" if v53s["real_release_package_ready"] == "1" else "blocked",
        "required_value": "1",
        "actual_value": v53s["real_release_package_ready"],
        "reason": "v53t is not a release artifact package",
    },
]
write_csv(run_dir / "complete_source_audit_readiness_requirement_rows.csv", list(requirements[0].keys()), requirements)

machine_ready_ids = [
    "f-optional-final-disposition",
    "complete-source-content-and-query-surface",
    "core-a-b-c-d-e-g-h-answer-citation-resource",
    "symmetric-scorer-policy-surface",
    "review-packet-ready",
]
machine_complete_source_surface_ready = int(all(row["status"] == "pass" for row in requirements if row["requirement_id"] in machine_ready_ids))
review_return_ready = int(v53s["review_return_ready"])
v53_ready = int(machine_complete_source_surface_ready and review_return_ready and v53s["quality_comparison_claim_ready"] == "1")

pm_freeze_checks = [
    {
        "check_id": "pinned-public-repo-manifest",
        "status": "pass" if v53i["repo_count"] == "10" and foundation_direct_pinned_manifest_ready else "blocked",
        "required_value": ">=10 direct pinned public repo manifest rows plus content snapshot rows",
        "actual_value": f"repo_count={v53i['repo_count']}; repo_manifest_rows={len(v53i_repo_coverage_rows)}; file_manifest_rows={len(v53i_file_manifest_rows)}; content_repo_rows={len(v53i_content_repo_rows)}; content_snapshot_rows={len(v53i_content_snapshot_rows)}; direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}",
        "reason": "v53 foundation requires direct pinned repo/source/content manifests before comparisons",
    },
    {
        "check_id": "source-span-bound-1000",
        "status": "pass" if v53i["complete_source_query_rows"] == "1000" and v53i["complete_source_span_rows"] == "1000" and foundation_query_span_binding_audit_ready else "blocked",
        "required_value": "1000 query rows, 1000 bound source spans, and 1000 passing binding-audit rows",
        "actual_value": f"{v53i['complete_source_query_rows']} query / {v53i['complete_source_span_rows']} span / binding_audit_pass={foundation_query_span_binding_pass_rows}",
        "reason": "every benchmark query must bind to a pinned source span",
    },
    {
        "check_id": "negative-abstain-control-10pct",
        "status": "pass" if int(v53i["negative_abstain_rows"]) >= 100 else "blocked",
        "required_value": ">=100 negative/abstain rows",
        "actual_value": v53i["negative_abstain_rows"],
        "reason": "negative and abstain controls must be at least 10% of the 1000-row corpus",
    },
    {
        "check_id": "unsupported-claim-control",
        "status": "pass" if unsupported_control_rows > 0 else "blocked",
        "required_value": ">=1 unsupported claim abstain row",
        "actual_value": str(unsupported_control_rows),
        "reason": "unsupported claim controls must be visible as their own row family",
    },
    {
        "check_id": "missing-specific-abstain-control",
        "status": "pass" if missing_specific_control_rows > 0 else "blocked",
        "required_value": ">=1 explicit missing/missing-api abstain row family",
        "actual_value": str(missing_specific_control_rows),
        "reason": "current negative rows cover unsupported and ambiguous claims, but do not name a missing-specific control family",
    },
    {
        "check_id": "doc-code-conflict-control",
        "status": "pass" if doc_code_conflict_rows > 0 else "blocked",
        "required_value": ">=1 doc-code conflict row",
        "actual_value": str(doc_code_conflict_rows),
        "reason": "doc/code conflict rows must be explicit before v53 freeze",
    },
    {
        "check_id": "answer-citation-separate-eval",
        "status": "pass" if v53q["symmetric_scorer_policy_rows_ready"] == "1" else "blocked",
        "required_value": "answer and citation evaluated as separate bound rows",
        "actual_value": f"answer_hash_match_rows={v53q['answer_hash_match_rows']}; citation_span_match_rows={v53q['citation_span_match_rows']}",
        "reason": "the evaluator must separate answer correctness from citation/source correctness",
    },
    {
        "check_id": "abgh-same-query-v53i",
        "status": "pass" if abgh_same_query_ready else "blocked",
        "required_value": "A/B/G/H each have 1000 row-contract answer/citation/resource rows over the current v53i query hash",
        "actual_value": "; ".join(
            f"{system_id}:{system_metric_by_id.get(system_id, {}).get('answer_rows', '0')}"
            for system_id in abgh_systems
        ) + f"; same_query_hash={same_complete_source_query_hash}; expected_answer_oracle_replay={v53ap.get('expected_answer_oracle_replay', '0')}; deterministic_source_span_adapter_execution={v53ap.get('deterministic_source_span_adapter_execution', '0')}; actual_adapter_execution_ready={v53ap.get('actual_adapter_execution_ready', '0')}",
        "reason": "A/B/G/H must use the same complete-source query set; deterministic source-span adapter execution is local/replayable, while public quality comparison remains blocked before D/E and review evidence",
    },
    {
        "check_id": "replayable-artifact-chain",
        "status": "pass" if foundation_direct_evidence_ready and foundation_direct_pinned_manifest_ready and foundation_query_span_binding_audit_ready else "blocked",
        "required_value": "direct repo manifest, query/span, and A/B/G/H answer/citation/evaluator/resource rows copied into v53t",
        "actual_value": f"repo_manifest={len(v53i_repo_coverage_rows)}; file_manifest={len(v53i_file_manifest_rows)}; content_snapshot={len(v53i_content_snapshot_rows)}; query={len(v53i_query_rows)}; span={len(v53i_span_rows)}; binding_audit_pass={foundation_query_span_binding_pass_rows}; evaluator={len(v53ap_evaluator_rows)}; direct_ready={foundation_direct_evidence_ready}; direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}",
        "reason": "output artifacts must be replayable and hash-bound",
    },
    {
        "check_id": "blocker-false-positive-closed",
        "status": "pass" if v53s["quality_comparison_claim_ready"] == "0" and v53s["real_release_package_ready"] == "0" else "blocked",
        "required_value": "comparison/release blockers remain closed",
        "actual_value": f"quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}; real_release_package_ready={v53s['real_release_package_ready']}",
        "reason": "merge conditions must not turn missing review evidence into a false-positive ready state",
    },
]
write_csv(run_dir / "complete_source_pm_freeze_check_rows.csv", list(pm_freeze_checks[0].keys()), pm_freeze_checks)
pm_freeze_pass_rows = sum(1 for row in pm_freeze_checks if row["status"] == "pass")
pm_freeze_blocked_rows = sum(1 for row in pm_freeze_checks if row["status"] == "blocked")
pm_v53_freeze_ready = int(pm_freeze_blocked_rows == 0)

foundation_freeze_rows = [
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "pinned-public-repo-manifest",
        "status": "pass" if v53i["repo_count"] == "10" and foundation_direct_pinned_manifest_ready else "blocked",
        "required_value": "10 direct pinned public repositories with Git tree and content snapshot manifests",
        "actual_value": f"repo_manifest_rows={len(v53i_repo_coverage_rows)}; file_manifest_rows={len(v53i_file_manifest_rows)}; content_repo_rows={len(v53i_content_repo_rows)}; content_snapshot_rows={len(v53i_content_snapshot_rows)}; direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}",
        "evidence_path": "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
        "claim_boundary": "Allows 10-repo public source manifest wording only; does not imply release readiness",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "source-span-bound-query-surface",
        "status": "pass" if v53i["complete_source_query_rows"] == "1000" and v53i["complete_source_span_rows"] == "1000" and foundation_query_span_binding_audit_ready else "blocked",
        "required_value": "1000 source-span-bound query rows with passing binding audit",
        "actual_value": f"{v53i['complete_source_query_rows']} query / {v53i['complete_source_span_rows']} span / binding_audit_pass={foundation_query_span_binding_pass_rows}",
        "evidence_path": "complete_source_query_span_binding_audit_rows.csv",
        "claim_boundary": "Allows complete-source benchmark surface wording; every query remains source-span-bound",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "negative-abstain-control-share",
        "status": "pass" if int(v53i["negative_abstain_rows"]) >= 100 else "blocked",
        "required_value": ">=10% negative/abstain control rows",
        "actual_value": v53i["negative_abstain_rows"],
        "evidence_path": "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
        "claim_boundary": "Allows abstain-control coverage wording; does not imply model quality improvement",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "unsupported-claim-control",
        "status": "pass" if unsupported_control_rows == 100 else "blocked",
        "required_value": "100 unsupported claim abstain rows",
        "actual_value": str(unsupported_control_rows),
        "evidence_path": "source_v53i/complete_source_query_family_rows.csv",
        "claim_boundary": "Allows unsupported-control wording as a corpus property only",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "missing-specific-abstain-control",
        "status": "pass" if missing_specific_control_rows == 30 else "blocked",
        "required_value": "30 missing-specific abstain rows",
        "actual_value": str(missing_specific_control_rows),
        "evidence_path": "source_v53i/complete_source_query_family_rows.csv",
        "claim_boundary": "Allows missing-specific abstain wording as a corpus property only",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "doc-code-conflict-control",
        "status": "pass" if doc_code_conflict_rows == 140 else "blocked",
        "required_value": "140 doc-code conflict rows",
        "actual_value": str(doc_code_conflict_rows),
        "evidence_path": "source_v53i/complete_source_query_family_rows.csv",
        "claim_boundary": "Allows doc-code conflict coverage wording as a corpus property only",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "answer-citation-separated-evaluator",
        "status": "pass" if foundation_direct_evaluator_separate_rows == 4000 else "blocked",
        "required_value": "separate answer and citation/source evaluation rows",
        "actual_value": f"direct_separate_evaluator_rows={foundation_direct_evaluator_separate_rows}",
        "evidence_path": "source_v53ap/abgh_evaluator_rows.csv",
        "claim_boundary": "Allows evaluator-contract wording; does not allow human-reviewed correctness wording",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "abgh-same-query-measured-run",
        "status": "pass" if abgh_same_query_ready else "blocked",
        "required_value": "A/B/G/H deterministic source-span adapter run over the same v53i query hash",
        "actual_value": "; ".join(
            f"{system_id}:{system_metric_by_id.get(system_id, {}).get('answer_rows', '0')}"
            for system_id in abgh_systems
        ) + f"; same_query_hash={same_complete_source_query_hash}; expected_answer_oracle_replay={v53ap.get('expected_answer_oracle_replay', '0')}; deterministic_source_span_adapter_execution={v53ap.get('deterministic_source_span_adapter_execution', '0')}; actual_adapter_execution_ready={v53ap.get('actual_adapter_execution_ready', '0')}",
        "evidence_path": "source_v53ap/abgh_evaluator_rows.csv",
        "claim_boundary": "Allows internal v1.0 pre-baseline A/B/G/H deterministic source-span adapter wording only; real system performance and public comparison remain blocked",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "replayable-artifact-chain",
        "status": "pass" if foundation_direct_evidence_ready and foundation_direct_pinned_manifest_ready and foundation_query_span_binding_audit_ready else "blocked",
        "required_value": "hash-bound direct repo manifest, query/span, and A/B/G/H row artifacts",
        "actual_value": f"direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}; query_span_binding_audit_ready={foundation_query_span_binding_audit_ready}; direct_ready={foundation_direct_evidence_ready}; evaluator_rows={len(v53ap_evaluator_rows)}",
        "evidence_path": "sha256_manifest.csv",
        "claim_boundary": "Allows replayable artifact wording for the emitted local run packet",
    },
    {
        "certificate_id": "v53-complete-source-foundation-freeze",
        "criterion_id": "public-comparison-boundary-closed",
        "status": "pass" if v53s["quality_comparison_claim_ready"] == "0" and v53s["real_release_package_ready"] == "0" else "blocked",
        "required_value": "quality/release claims blocked until D/E, human review, and release evidence exist",
        "actual_value": f"quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}; real_release_package_ready={v53s['real_release_package_ready']}",
        "evidence_path": "source_v53s/v53s_complete_source_review_return_intake_summary.csv",
        "claim_boundary": "Explicitly forbids public comparison, v53-ready, and release-ready wording",
    },
]
write_csv(
    run_dir / "complete_source_foundation_freeze_rows.csv",
    list(foundation_freeze_rows[0].keys()),
    foundation_freeze_rows,
)
foundation_freeze_pass_rows = sum(1 for row in foundation_freeze_rows if row["status"] == "pass")
foundation_freeze_blocked_rows = sum(1 for row in foundation_freeze_rows if row["status"] == "blocked")
foundation_machine_freeze_ready = int(foundation_freeze_blocked_rows == 0)

real_adapter_freeze_rows = [
    {
        "certificate_id": "v53-complete-source-abgh-real-adapter-freeze",
        "criterion_id": "v53aq-same-query-surface",
        "status": "pass" if v53aq_same_complete_source_query_hash and foundation_real_adapter_same_query_rows_ready and foundation_real_adapter_same_query_ledger_ready else "blocked",
        "required_value": "A/B/G/H query-text-only adapter rows over the current v53i query hash with per-query evaluator/resource ledger",
        "actual_value": f"same_query_hash={v53aq_same_complete_source_query_hash}; same_query_rows_ready={foundation_real_adapter_same_query_rows_ready}; same_query_ledger_ready={foundation_real_adapter_same_query_ledger_ready}; same_query_ledger_rows={foundation_real_adapter_same_query_ledger_rows}",
        "evidence_path": "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
        "claim_boundary": "Allows internal real-adapter evidence wording only; no D/E or public comparison claim",
    },
    {
        "certificate_id": "v53-complete-source-abgh-real-adapter-freeze",
        "criterion_id": "question-only-selection-contract",
        "status": "pass" if v53aq_question_only_selection_contract_ready else "blocked",
        "required_value": "adapter selection may read only question text; oracle/source/answer fields forbidden",
        "actual_value": f"selection_question_text_only={v53aq.get('selection_question_text_only', '0')}; selection_oracle_field_used={v53aq.get('selection_oracle_field_used', '1')}",
        "evidence_path": "source_v53aq/adapter_selection_contract_rows.csv",
        "claim_boundary": "Allows no-oracle adapter-selection wording; evaluator-only fields remain forbidden",
    },
    {
        "certificate_id": "v53-complete-source-abgh-real-adapter-freeze",
        "criterion_id": "real-adapter-execution-rows",
        "status": "pass" if foundation_real_adapter_evidence_ready else "blocked",
        "required_value": "4000 real-adapter answer/citation/evaluator/resource rows with separate evaluator checks",
        "actual_value": f"evaluator_rows={len(v53aq_evaluator_rows)}; separate_evaluator_rows={foundation_real_adapter_evaluator_rows}; answer_hash_match_rows={v53aq.get('answer_hash_match_rows', '0')}; coherent_wrong_key_rows={v53aq.get('coherent_wrong_key_rows', '0')}",
        "evidence_path": "source_v53aq/abgh_evaluator_rows.csv",
        "claim_boundary": "Allows internal A/B/G/H real-adapter metric wording; public comparison remains blocked",
    },
    {
        "certificate_id": "v53-complete-source-abgh-real-adapter-freeze",
        "criterion_id": "public-comparison-boundary-closed",
        "status": "pass" if v53aq.get("public_comparison_claim_ready") == "0" and v53aq.get("required_30b_baseline_ready") == "0" and v53aq.get("required_70b_baseline_ready") == "0" else "blocked",
        "required_value": "public comparison, D/E replacement, and release claims blocked",
        "actual_value": f"public_comparison_claim_ready={v53aq.get('public_comparison_claim_ready', '0')}; required_30b_baseline_ready={v53aq.get('required_30b_baseline_ready', '0')}; required_70b_baseline_ready={v53aq.get('required_70b_baseline_ready', '0')}",
        "evidence_path": "source_v53aq/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
        "claim_boundary": "Explicitly forbids public comparison wording until D/E and release evidence exist",
    },
]
write_csv(
    run_dir / "complete_source_abgh_real_adapter_freeze_rows.csv",
    list(real_adapter_freeze_rows[0].keys()),
    real_adapter_freeze_rows,
)
foundation_real_adapter_freeze_pass_rows = sum(1 for row in real_adapter_freeze_rows if row["status"] == "pass")
foundation_real_adapter_freeze_blocked_rows = sum(1 for row in real_adapter_freeze_rows if row["status"] == "blocked")


def evidence_row_count(rel):
    path = run_dir / rel
    if path.suffix == ".csv" and path.is_file():
        return str(len(read_csv(path)))
    return "not-csv"


def pm_acceptance_row(
    requirement_id,
    roadmap_phase,
    status,
    evidence_path,
    actual_value,
    claim_boundary,
    replay_command="experiments/test_v53t_complete_source_audit_readiness_gate.sh",
):
    evidence_file = run_dir / evidence_path
    replay_status = "pass" if evidence_file.is_file() and evidence_file.stat().st_size > 0 else "blocked"
    return {
        "requirement_id": requirement_id,
        "roadmap_phase": roadmap_phase,
        "status": status,
        "evidence_path": evidence_path,
        "evidence_rows": evidence_row_count(evidence_path),
        "evidence_sha256": sha256(evidence_file) if evidence_file.is_file() else "",
        "replay_command": replay_command,
        "claim_boundary_status": "pass" if status == "pass" else "blocked",
        "replay_artifact_status": replay_status,
        "blocker_false_positive_status": "pass",
        "tests_only_merge_condition": "0",
        "acceptance_ready": "1" if status == "pass" and replay_status == "pass" else "0",
        "actual_value": actual_value,
        "claim_boundary": claim_boundary,
    }


pm_acceptance_evidence_rows = [
    pm_acceptance_row(
        "pinned-public-repo-manifest",
        "M2-v53-source-bound-corpus",
        "pass" if foundation_direct_pinned_manifest_ready else "blocked",
        "source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
        f"repo_manifest_rows={len(v53i_repo_coverage_rows)}; file_manifest_rows={len(v53i_file_manifest_rows)}; content_snapshot_rows={len(v53i_content_snapshot_rows)}; direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}",
        "Allows 10 public pinned repo manifest wording only; no release or quality claim",
    ),
    pm_acceptance_row(
        "source-span-query-freeze",
        "M2-v53-source-bound-corpus",
        "pass" if foundation_query_span_binding_audit_ready else "blocked",
        "complete_source_query_span_binding_audit_rows.csv",
        f"query_rows={len(v53i_query_rows)}; span_rows={len(v53i_span_rows)}; binding_audit_pass_rows={foundation_query_span_binding_pass_rows}",
        "Allows 1000 source-span-bound query freeze wording; not human-reviewed correctness",
    ),
    pm_acceptance_row(
        "negative-abstain-control-share",
        "M2-v53-source-bound-corpus",
        "pass" if int(v53i["negative_abstain_rows"]) >= 100 else "blocked",
        "source_v53i/complete_source_query_family_rows.csv",
        f"negative_abstain_rows={v53i['negative_abstain_rows']}; required_min=100",
        "Allows negative/abstain coverage wording as a corpus property only",
    ),
    pm_acceptance_row(
        "unsupported-claim-control",
        "M2-v53-source-bound-corpus",
        "pass" if unsupported_control_rows == 100 else "blocked",
        "source_v53i/complete_source_query_family_rows.csv",
        f"unsupported_control_rows={unsupported_control_rows}",
        "Allows unsupported-claim control wording as a corpus property only",
    ),
    pm_acceptance_row(
        "missing-specific-abstain-control",
        "M2-v53-source-bound-corpus",
        "pass" if missing_specific_control_rows == 30 else "blocked",
        "source_v53i/complete_source_query_family_rows.csv",
        f"missing_specific_control_rows={missing_specific_control_rows}",
        "Allows missing-specific abstain wording as a corpus property only",
    ),
    pm_acceptance_row(
        "doc-code-conflict-control",
        "M2-v53-source-bound-corpus",
        "pass" if doc_code_conflict_rows == 140 else "blocked",
        "source_v53i/complete_source_query_family_rows.csv",
        f"doc_code_conflict_rows={doc_code_conflict_rows}",
        "Allows doc-code conflict coverage wording as a corpus property only",
    ),
    pm_acceptance_row(
        "answer-citation-separated-evaluator",
        "M2-v53-source-bound-corpus",
        "pass" if foundation_direct_evaluator_separate_rows == 4000 else "blocked",
        "source_v53ap/abgh_evaluator_rows.csv",
        f"separate_evaluator_rows={foundation_direct_evaluator_separate_rows}; evaluator_rows={len(v53ap_evaluator_rows)}",
        "Allows separated evaluator-contract wording; not human-reviewed answer quality",
        "experiments/test_v53ap_complete_source_abgh_same_query_measured.sh",
    ),
    pm_acceptance_row(
        "abgh-same-query-deterministic-prebaseline",
        "M3-abgh-same-query-measured-run",
        "pass" if abgh_same_query_ready else "blocked",
        "source_v53ap/abgh_evaluator_rows.csv",
        f"same_query_hash={same_complete_source_query_hash}; answer_rows={len(v53ap_answer_rows)}; evaluator_rows={len(v53ap_evaluator_rows)}; expected_answer_oracle_replay={v53ap.get('expected_answer_oracle_replay', '0')}; deterministic_source_span_adapter_execution={v53ap.get('deterministic_source_span_adapter_execution', '0')}; real_system_performance_claim_ready={v53ap.get('real_system_performance_claim_ready', '0')}",
        "Allows internal v1.0 pre-baseline A/B/G/H same-query deterministic adapter wording only; public comparison remains blocked",
        "experiments/test_v53ap_complete_source_abgh_same_query_measured.sh",
    ),
    pm_acceptance_row(
        "abgh-real-adapter-same-query-internal",
        "M3-abgh-same-query-measured-run",
        "pass" if foundation_real_adapter_same_query_ledger_ready else "blocked",
        "source_v53aq/abgh_same_query_internal_prebaseline_rows.csv",
        f"same_query_ledger_rows={foundation_real_adapter_same_query_ledger_rows}; question_text_only={v53aq.get('selection_question_text_only', '0')}; oracle_field_used={v53aq.get('selection_oracle_field_used', '1')}; coherent_wrong_key_rows={v53aq.get('coherent_wrong_key_rows', '0')}; public_comparison_claim_ready={v53aq.get('public_comparison_claim_ready', '0')}",
        "Allows internal query-text-only A/B/G/H real-adapter evidence wording; no D/E or public comparison claim",
        "experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh",
    ),
    pm_acceptance_row(
        "public-comparison-boundary-closed",
        "M3-abgh-same-query-measured-run",
        "pass" if v53aq.get("public_comparison_claim_ready") == "0" and v53s["quality_comparison_claim_ready"] == "0" else "blocked",
        "complete_source_abgh_real_adapter_freeze_rows.csv",
        f"v53aq_public_comparison_claim_ready={v53aq.get('public_comparison_claim_ready', '0')}; quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}; required_30b_baseline_ready={v53aq.get('required_30b_baseline_ready', '0')}; required_70b_baseline_ready={v53aq.get('required_70b_baseline_ready', '0')}",
        "Explicitly forbids public comparison, v53-ready, and release-ready wording until D/E, review, and release evidence exist",
    ),
]
write_csv(
    run_dir / "complete_source_pm_acceptance_evidence_rows.csv",
    list(pm_acceptance_evidence_rows[0].keys()),
    pm_acceptance_evidence_rows,
)
pm_acceptance_evidence_row_count = len(pm_acceptance_evidence_rows)
pm_acceptance_evidence_ready_rows = sum(1 for row in pm_acceptance_evidence_rows if row["acceptance_ready"] == "1")
pm_acceptance_evidence_tests_only_rows = sum(1 for row in pm_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1")
pm_acceptance_evidence_replay_pass_rows = sum(1 for row in pm_acceptance_evidence_rows if row["replay_artifact_status"] == "pass")
pm_acceptance_evidence_blocker_pass_rows = sum(1 for row in pm_acceptance_evidence_rows if row["blocker_false_positive_status"] == "pass")

claim_rows = [
    {
        "claim_id": "complete-source-machine-surface",
        "status": "allowed-limited" if machine_complete_source_surface_ready else "blocked",
        "reason": "10-repo complete-source query/scoring/review packet surface is machine-prepared, not human-reviewed",
    },
    {
        "claim_id": "human-reviewed-complete-source-audit",
        "status": "blocked",
        "reason": f"review_return_ready={review_return_ready}",
    },
    {
        "claim_id": "30b-150b-quality-comparison",
        "status": "blocked",
        "reason": f"quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}",
    },
    {
        "claim_id": "v53-ready",
        "status": "blocked",
        "reason": f"v53_ready={v53_ready}",
    },
    {
        "claim_id": "pm-v53-freeze",
        "status": "allowed-limited" if pm_v53_freeze_ready else "blocked",
        "reason": f"pm_v53_freeze_ready={pm_v53_freeze_ready}; pm_freeze_blocked_rows={pm_freeze_blocked_rows}",
    },
    {
        "claim_id": "release-ready",
        "status": "blocked",
        "reason": "real_release_package_ready=0",
    },
]
write_csv(run_dir / "complete_source_audit_claim_rows.csv", list(claim_rows[0].keys()), claim_rows)

metric = {
    "metric_id": "v53t_complete_source_audit_readiness_gate_metrics",
    "v52y_f_optional_final_policy_ready": v52y["v52y_f_optional_final_policy_ready"],
    "f_optional_final_disposition": v52y["f_optional_final_disposition"],
    "v53i_complete_source_query_instantiation_ready": v53i["v53i_complete_source_query_instantiation_ready"],
    "v53q_complete_source_symmetric_scorer_policy_ready": v53q["v53q_complete_source_symmetric_scorer_policy_ready"],
    "v53ap_complete_source_abgh_same_query_measured_ready": v53ap["v53ap_complete_source_abgh_same_query_measured_ready"],
    "v53aq_complete_source_abgh_real_adapter_measured_ready": v53aq["v53aq_complete_source_abgh_real_adapter_measured_ready"],
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v53s_complete_source_review_return_intake_ready": v53s["v53s_complete_source_review_return_intake_ready"],
    "complete_source_repo_count": v53i["repo_count"],
    "complete_source_query_rows": v53i["complete_source_query_rows"],
    "complete_source_span_rows": v53i["complete_source_span_rows"],
    "core_system_count": v53q["core_system_count"],
    "core_answer_rows": v53q["core_answer_rows"],
    "symmetric_scorer_rows": v53q["symmetric_scorer_rows"],
    "symmetric_policy_rows": v53q["symmetric_policy_rows"],
    "review_packet_ready": v53r["review_packet_ready"],
    "expected_human_review_rows": v53s["expected_human_review_rows"],
    "accepted_human_review_rows": v53s["accepted_human_review_rows"],
    "expected_adjudication_rows": v53s["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53s["accepted_adjudication_rows"],
    "machine_complete_source_surface_ready": str(machine_complete_source_surface_ready),
    "review_return_ready": str(review_return_ready),
    "human_review_completed": v53s["human_review_completed"],
    "adjudication_completed": v53s["adjudication_completed"],
    "quality_comparison_claim_ready": "0",
    "v53_ready": str(v53_ready),
    "pm_v53_freeze_ready": str(pm_v53_freeze_ready),
    "pm_freeze_check_rows": str(len(pm_freeze_checks)),
    "pm_freeze_pass_rows": str(pm_freeze_pass_rows),
    "pm_freeze_blocked_rows": str(pm_freeze_blocked_rows),
    "foundation_freeze_certificate_rows": str(len(foundation_freeze_rows)),
    "foundation_freeze_pass_rows": str(foundation_freeze_pass_rows),
    "foundation_freeze_blocked_rows": str(foundation_freeze_blocked_rows),
    "pm_acceptance_evidence_rows": str(pm_acceptance_evidence_row_count),
    "pm_acceptance_evidence_ready_rows": str(pm_acceptance_evidence_ready_rows),
    "pm_acceptance_evidence_replay_pass_rows": str(pm_acceptance_evidence_replay_pass_rows),
    "pm_acceptance_evidence_blocker_pass_rows": str(pm_acceptance_evidence_blocker_pass_rows),
    "pm_acceptance_evidence_tests_only_rows": str(pm_acceptance_evidence_tests_only_rows),
    "foundation_machine_freeze_ready": str(foundation_machine_freeze_ready),
    "foundation_direct_evidence_ready": str(foundation_direct_evidence_ready),
    "foundation_query_span_binding_audit_ready": str(foundation_query_span_binding_audit_ready),
    "foundation_query_span_binding_audit_rows": str(foundation_query_span_binding_audit_rows),
    "foundation_query_span_binding_pass_rows": str(foundation_query_span_binding_pass_rows),
    "foundation_query_span_binding_blocked_rows": str(foundation_query_span_binding_blocked_rows),
    "foundation_direct_pinned_manifest_ready": str(foundation_direct_pinned_manifest_ready),
    "foundation_direct_repo_manifest_ready": str(foundation_direct_repo_manifest_ready),
    "foundation_direct_content_snapshot_ready": str(foundation_direct_content_snapshot_ready),
    "foundation_direct_repo_manifest_rows": str(len(v53i_repo_coverage_rows)),
    "foundation_direct_file_manifest_rows": str(len(v53i_file_manifest_rows)),
    "foundation_direct_content_repo_rows": str(len(v53i_content_repo_rows)),
    "foundation_direct_content_snapshot_rows": str(len(v53i_content_snapshot_rows)),
    "foundation_real_adapter_freeze_rows": str(len(real_adapter_freeze_rows)),
    "foundation_real_adapter_freeze_pass_rows": str(foundation_real_adapter_freeze_pass_rows),
    "foundation_real_adapter_freeze_blocked_rows": str(foundation_real_adapter_freeze_blocked_rows),
    "foundation_real_adapter_evidence_ready": str(foundation_real_adapter_evidence_ready),
    "foundation_real_adapter_same_query_rows_ready": str(foundation_real_adapter_same_query_rows_ready),
    "foundation_real_adapter_same_query_ledger_ready": str(foundation_real_adapter_same_query_ledger_ready),
    "foundation_real_adapter_same_query_ledger_rows": str(foundation_real_adapter_same_query_ledger_rows),
    "foundation_real_adapter_evaluator_rows": str(len(v53aq_evaluator_rows)),
    "foundation_real_adapter_evaluator_separate_rows": str(foundation_real_adapter_evaluator_rows),
    "v53aq_question_only_selection_contract_ready": str(v53aq_question_only_selection_contract_ready),
    "v53aq_same_complete_source_query_hash": str(v53aq_same_complete_source_query_hash),
    "v53aq_query_rows_sha256": v53aq_query_rows_sha256,
    "foundation_direct_query_rows": str(len(v53i_query_rows)),
    "foundation_direct_span_rows": str(len(v53i_span_rows)),
    "foundation_direct_abgh_answer_rows": str(len(v53ap_answer_rows)),
    "foundation_direct_abgh_citation_rows": str(len(v53ap_citation_rows)),
    "foundation_direct_abgh_evaluator_rows": str(len(v53ap_evaluator_rows)),
    "foundation_direct_abgh_resource_rows": str(len(v53ap_resource_rows)),
    "foundation_direct_abgh_adapter_trace_rows": str(len(v53ap_adapter_trace_rows)),
    "foundation_direct_evaluator_separate_rows": str(foundation_direct_evaluator_separate_rows),
    "foundation_direct_same_query_rows_ready": str(foundation_direct_same_query_rows_ready),
    "unsupported_control_rows": str(unsupported_control_rows),
    "ambiguous_control_rows": str(ambiguous_control_rows),
    "missing_specific_control_rows": str(missing_specific_control_rows),
    "doc_code_conflict_rows": str(doc_code_conflict_rows),
    "same_complete_source_query_hash": str(same_complete_source_query_hash),
    "current_v53i_query_rows_sha256": current_v53i_query_rows_sha256,
    "v53ap_query_rows_sha256": v53ap_query_rows_sha256,
    "abgh_same_query_ready": str(abgh_same_query_ready),
    "v53ap_expected_answer_oracle_replay": v53ap.get("expected_answer_oracle_replay", "0"),
    "v53ap_deterministic_source_span_adapter_execution": v53ap.get("deterministic_source_span_adapter_execution", "0"),
    "v53ap_deterministic_source_span_adapter_rows": v53ap.get("deterministic_source_span_adapter_rows", "0"),
    "v53ap_actual_adapter_execution_ready": v53ap.get("actual_adapter_execution_ready", "0"),
    "v53ap_real_system_performance_claim_ready": v53ap.get("real_system_performance_claim_ready", "0"),
    "v53aq_selection_question_text_only": v53aq.get("selection_question_text_only", "0"),
    "v53aq_selection_oracle_field_used": v53aq.get("selection_oracle_field_used", "1"),
    "v53aq_expected_answer_oracle_replay": v53aq.get("expected_answer_oracle_replay", "1"),
    "v53aq_deterministic_source_span_adapter_execution": v53aq.get("deterministic_source_span_adapter_execution", "1"),
    "v53aq_actual_adapter_execution_ready": v53aq.get("actual_adapter_execution_ready", "0"),
    "v53aq_real_adapter_execution_ready": v53aq.get("real_adapter_execution_ready", "0"),
    "v53aq_real_system_performance_claim_ready": v53aq.get("real_system_performance_claim_ready", "0"),
    "v53aq_answer_hash_match_rows": v53aq.get("answer_hash_match_rows", "0"),
    "v53aq_coherent_wrong_key_rows": v53aq.get("coherent_wrong_key_rows", "0"),
    "v53aq_public_comparison_claim_ready": v53aq.get("public_comparison_claim_ready", "0"),
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(run_dir / "complete_source_audit_readiness_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v52y-f-final-policy-input", "status": "pass", "reason": f"f_optional_final_disposition={v52y['f_optional_final_disposition']}"},
    {"gate": "v53i-complete-source-query-input", "status": "pass", "reason": f"complete_source_query_rows={v53i['complete_source_query_rows']}"},
    {"gate": "v53ap-abgh-same-query-input", "status": "pass" if abgh_same_query_ready else "blocked", "reason": f"abgh_same_query_ready={abgh_same_query_ready}; same_complete_source_query_hash={same_complete_source_query_hash}"},
    {"gate": "v53aq-abgh-real-adapter-input", "status": "pass" if foundation_real_adapter_evidence_ready else "blocked", "reason": f"foundation_real_adapter_evidence_ready={foundation_real_adapter_evidence_ready}; v53aq_same_complete_source_query_hash={v53aq_same_complete_source_query_hash}; v53aq_question_only_selection_contract_ready={v53aq_question_only_selection_contract_ready}; same_query_ledger_ready={foundation_real_adapter_same_query_ledger_ready}"},
    {"gate": "v53q-core-scorer-policy-input", "status": "pass", "reason": f"core_answer_rows={v53q['core_answer_rows']}"},
    {"gate": "v53r-review-packet-input", "status": "pass", "reason": f"review_packet_ready={v53r['review_packet_ready']}"},
    {"gate": "machine-complete-source-surface", "status": "pass" if machine_complete_source_surface_ready else "blocked", "reason": f"machine_complete_source_surface_ready={machine_complete_source_surface_ready}"},
    {"gate": "v53s-review-return-input", "status": "blocked" if review_return_ready == 0 else "pass", "reason": f"review_return_ready={review_return_ready}"},
    {"gate": "human-reviewed-audit", "status": "blocked", "reason": f"accepted_human_review_rows={v53s['accepted_human_review_rows']}/{v53s['expected_human_review_rows']}"},
    {"gate": "quality-comparison-claim", "status": "blocked", "reason": "quality comparison waits for accepted review return and final audit"},
    {"gate": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53_ready}"},
    {"gate": "pm-v53-freeze", "status": "pass" if pm_v53_freeze_ready else "blocked", "reason": f"pm_freeze_blocked_rows={pm_freeze_blocked_rows}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "v53t is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53t Complete Source Audit Readiness Gate Boundary

This layer audits whether the v53 complete-source path is ready for a v1.0
comparison claim. It confirms the machine-prepared surface and keeps human
review, comparison, v53 readiness, and release claims blocked until real
returned review artifacts are accepted.

Evidence emitted:

- f_optional_final_disposition={v52y['f_optional_final_disposition']}
- complete_source_repo_count={v53i['repo_count']}
- complete_source_query_rows={v53i['complete_source_query_rows']}
- core_answer_rows={v53q['core_answer_rows']}
- symmetric_scorer_rows={v53q['symmetric_scorer_rows']}
- review_packet_ready={v53r['review_packet_ready']}
- expected_human_review_rows={v53s['expected_human_review_rows']}
- accepted_human_review_rows={v53s['accepted_human_review_rows']}
- expected_adjudication_rows={v53s['expected_adjudication_rows']}
- accepted_adjudication_rows={v53s['accepted_adjudication_rows']}
- machine_complete_source_surface_ready={machine_complete_source_surface_ready}
- review_return_ready={review_return_ready}
- quality_comparison_claim_ready=0
- v53_ready={v53_ready}
- pm_v53_freeze_ready={pm_v53_freeze_ready}
- pm_freeze_check_rows={len(pm_freeze_checks)}
- pm_freeze_blocked_rows={pm_freeze_blocked_rows}
- foundation_freeze_certificate_rows={len(foundation_freeze_rows)}
- pm_acceptance_evidence_rows={pm_acceptance_evidence_row_count}
- pm_acceptance_evidence_ready_rows={pm_acceptance_evidence_ready_rows}
- pm_acceptance_evidence_tests_only_rows={pm_acceptance_evidence_tests_only_rows}
- foundation_machine_freeze_ready={foundation_machine_freeze_ready}
- foundation_direct_evidence_ready={foundation_direct_evidence_ready}
- foundation_query_span_binding_audit_ready={foundation_query_span_binding_audit_ready}
- foundation_query_span_binding_audit_rows={foundation_query_span_binding_audit_rows}
- foundation_query_span_binding_pass_rows={foundation_query_span_binding_pass_rows}
- foundation_query_span_binding_blocked_rows={foundation_query_span_binding_blocked_rows}
- foundation_direct_pinned_manifest_ready={foundation_direct_pinned_manifest_ready}
- foundation_direct_repo_manifest_ready={foundation_direct_repo_manifest_ready}
- foundation_direct_content_snapshot_ready={foundation_direct_content_snapshot_ready}
- foundation_direct_repo_manifest_rows={len(v53i_repo_coverage_rows)}
- foundation_direct_file_manifest_rows={len(v53i_file_manifest_rows)}
- foundation_direct_content_repo_rows={len(v53i_content_repo_rows)}
- foundation_direct_content_snapshot_rows={len(v53i_content_snapshot_rows)}
- foundation_real_adapter_freeze_rows={len(real_adapter_freeze_rows)}
- foundation_real_adapter_evidence_ready={foundation_real_adapter_evidence_ready}
- foundation_real_adapter_same_query_rows_ready={foundation_real_adapter_same_query_rows_ready}
- foundation_real_adapter_same_query_ledger_ready={foundation_real_adapter_same_query_ledger_ready}
- foundation_real_adapter_same_query_ledger_rows={foundation_real_adapter_same_query_ledger_rows}
- foundation_real_adapter_evaluator_rows={len(v53aq_evaluator_rows)}
- foundation_real_adapter_evaluator_separate_rows={foundation_real_adapter_evaluator_rows}
- v53aq_question_only_selection_contract_ready={v53aq_question_only_selection_contract_ready}
- v53aq_same_complete_source_query_hash={v53aq_same_complete_source_query_hash}
- foundation_direct_query_rows={len(v53i_query_rows)}
- foundation_direct_span_rows={len(v53i_span_rows)}
- foundation_direct_abgh_evaluator_rows={len(v53ap_evaluator_rows)}
- foundation_direct_evaluator_separate_rows={foundation_direct_evaluator_separate_rows}
- foundation_direct_same_query_rows_ready={foundation_direct_same_query_rows_ready}
- unsupported_control_rows={unsupported_control_rows}
- missing_specific_control_rows={missing_specific_control_rows}
- doc_code_conflict_rows={doc_code_conflict_rows}
- same_complete_source_query_hash={same_complete_source_query_hash}
- abgh_same_query_ready={abgh_same_query_ready}
- v53ap_expected_answer_oracle_replay={v53ap.get('expected_answer_oracle_replay', '0')}
- v53ap_deterministic_source_span_adapter_execution={v53ap.get('deterministic_source_span_adapter_execution', '0')}
- v53ap_deterministic_source_span_adapter_rows={v53ap.get('deterministic_source_span_adapter_rows', '0')}
- v53ap_actual_adapter_execution_ready={v53ap.get('actual_adapter_execution_ready', '0')}
- v53ap_real_system_performance_claim_ready={v53ap.get('real_system_performance_claim_ready', '0')}
- v53aq_selection_question_text_only={v53aq.get('selection_question_text_only', '0')}
- v53aq_selection_oracle_field_used={v53aq.get('selection_oracle_field_used', '1')}
- v53aq_expected_answer_oracle_replay={v53aq.get('expected_answer_oracle_replay', '1')}
- v53aq_deterministic_source_span_adapter_execution={v53aq.get('deterministic_source_span_adapter_execution', '1')}
- v53aq_actual_adapter_execution_ready={v53aq.get('actual_adapter_execution_ready', '0')}
- v53aq_real_adapter_execution_ready={v53aq.get('real_adapter_execution_ready', '0')}
- v53aq_answer_hash_match_rows={v53aq.get('answer_hash_match_rows', '0')}
- v53aq_coherent_wrong_key_rows={v53aq.get('coherent_wrong_key_rows', '0')}
- v53aq_public_comparison_claim_ready={v53aq.get('public_comparison_claim_ready', '0')}
- v1_0_comparison_ready=0
- real_release_package_ready=0

Allowed wording: machine-prepared PM-freeze complete-source benchmark surface
over 10 locked repositories, 1000 source-span-bound queries, explicit
unsupported/missing/doc-code-conflict controls, and internal A/B/G/H
same-query deterministic source-span adapter pre-baseline rows plus internal
query-text-only A/B/G/H real-adapter evidence.

Blocked wording: human-reviewed complete-source audit, 30B-150B quality
comparison, public A/B/G/H-vs-D/E comparison, v53 readiness, v1.0 comparison
readiness, production readiness, or release readiness.
"""
(run_dir / "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53t-complete-source-audit-readiness-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53t_complete_source_audit_readiness_gate_ready": 1,
    "v52y_summary_sha256": sha256(summary_paths["v52y"]),
    "v53ap_summary_sha256": sha256(summary_paths["v53ap"]),
    "v53aq_summary_sha256": sha256(summary_paths["v53aq"]),
    "v53s_summary_sha256": sha256(summary_paths["v53s"]),
    "machine_complete_source_surface_ready": machine_complete_source_surface_ready,
    "review_return_ready": review_return_ready,
    "quality_comparison_claim_ready": 0,
    "v53_ready": v53_ready,
    "pm_v53_freeze_ready": pm_v53_freeze_ready,
    "pm_freeze_blocked_rows": pm_freeze_blocked_rows,
    "foundation_freeze_certificate_rows": len(foundation_freeze_rows),
    "foundation_freeze_blocked_rows": foundation_freeze_blocked_rows,
    "pm_acceptance_evidence_rows": pm_acceptance_evidence_row_count,
    "pm_acceptance_evidence_ready_rows": pm_acceptance_evidence_ready_rows,
    "pm_acceptance_evidence_replay_pass_rows": pm_acceptance_evidence_replay_pass_rows,
    "pm_acceptance_evidence_blocker_pass_rows": pm_acceptance_evidence_blocker_pass_rows,
    "pm_acceptance_evidence_tests_only_rows": pm_acceptance_evidence_tests_only_rows,
    "pm_acceptance_evidence_rows_sha256": sha256(run_dir / "complete_source_pm_acceptance_evidence_rows.csv"),
    "foundation_machine_freeze_ready": foundation_machine_freeze_ready,
    "foundation_direct_evidence_ready": foundation_direct_evidence_ready,
    "foundation_query_span_binding_audit_ready": foundation_query_span_binding_audit_ready,
    "foundation_query_span_binding_audit_rows": foundation_query_span_binding_audit_rows,
    "foundation_query_span_binding_pass_rows": foundation_query_span_binding_pass_rows,
    "foundation_query_span_binding_blocked_rows": foundation_query_span_binding_blocked_rows,
    "foundation_direct_pinned_manifest_ready": foundation_direct_pinned_manifest_ready,
    "foundation_direct_repo_manifest_ready": foundation_direct_repo_manifest_ready,
    "foundation_direct_content_snapshot_ready": foundation_direct_content_snapshot_ready,
    "foundation_direct_repo_manifest_rows": len(v53i_repo_coverage_rows),
    "foundation_direct_file_manifest_rows": len(v53i_file_manifest_rows),
    "foundation_direct_content_repo_rows": len(v53i_content_repo_rows),
    "foundation_direct_content_snapshot_rows": len(v53i_content_snapshot_rows),
    "foundation_real_adapter_freeze_rows": len(real_adapter_freeze_rows),
    "foundation_real_adapter_freeze_blocked_rows": foundation_real_adapter_freeze_blocked_rows,
    "foundation_real_adapter_evidence_ready": foundation_real_adapter_evidence_ready,
    "foundation_real_adapter_same_query_rows_ready": foundation_real_adapter_same_query_rows_ready,
    "foundation_real_adapter_same_query_ledger_ready": foundation_real_adapter_same_query_ledger_ready,
    "foundation_real_adapter_same_query_ledger_rows": foundation_real_adapter_same_query_ledger_rows,
    "foundation_real_adapter_evaluator_rows": len(v53aq_evaluator_rows),
    "foundation_real_adapter_evaluator_separate_rows": foundation_real_adapter_evaluator_rows,
    "v53aq_question_only_selection_contract_ready": v53aq_question_only_selection_contract_ready,
    "v53aq_same_complete_source_query_hash": v53aq_same_complete_source_query_hash,
    "v53aq_query_rows_sha256": v53aq_query_rows_sha256,
    "foundation_direct_query_rows": len(v53i_query_rows),
    "foundation_direct_span_rows": len(v53i_span_rows),
    "foundation_direct_abgh_answer_rows": len(v53ap_answer_rows),
    "foundation_direct_abgh_citation_rows": len(v53ap_citation_rows),
    "foundation_direct_abgh_evaluator_rows": len(v53ap_evaluator_rows),
    "foundation_direct_abgh_resource_rows": len(v53ap_resource_rows),
    "foundation_direct_abgh_adapter_trace_rows": len(v53ap_adapter_trace_rows),
    "foundation_direct_evaluator_separate_rows": foundation_direct_evaluator_separate_rows,
    "foundation_direct_same_query_rows_ready": foundation_direct_same_query_rows_ready,
    "missing_specific_control_rows": missing_specific_control_rows,
    "same_complete_source_query_hash": same_complete_source_query_hash,
    "current_v53i_query_rows_sha256": current_v53i_query_rows_sha256,
    "v53ap_query_rows_sha256": v53ap_query_rows_sha256,
    "abgh_same_query_ready": abgh_same_query_ready,
    "v53ap_expected_answer_oracle_replay": int(v53ap.get("expected_answer_oracle_replay", "0")),
    "v53ap_deterministic_source_span_adapter_execution": int(v53ap.get("deterministic_source_span_adapter_execution", "0")),
    "v53ap_deterministic_source_span_adapter_rows": int(v53ap.get("deterministic_source_span_adapter_rows", "0")),
    "v53ap_actual_adapter_execution_ready": int(v53ap.get("actual_adapter_execution_ready", "0")),
    "v53ap_real_system_performance_claim_ready": int(v53ap.get("real_system_performance_claim_ready", "0")),
    "v53aq_selection_question_text_only": int(v53aq.get("selection_question_text_only", "0")),
    "v53aq_selection_oracle_field_used": int(v53aq.get("selection_oracle_field_used", "1")),
    "v53aq_expected_answer_oracle_replay": int(v53aq.get("expected_answer_oracle_replay", "1")),
    "v53aq_deterministic_source_span_adapter_execution": int(v53aq.get("deterministic_source_span_adapter_execution", "1")),
    "v53aq_actual_adapter_execution_ready": int(v53aq.get("actual_adapter_execution_ready", "0")),
    "v53aq_real_adapter_execution_ready": int(v53aq.get("real_adapter_execution_ready", "0")),
    "v53aq_real_system_performance_claim_ready": int(v53aq.get("real_system_performance_claim_ready", "0")),
    "v53aq_answer_hash_match_rows": int(v53aq.get("answer_hash_match_rows", "0")),
    "v53aq_coherent_wrong_key_rows": int(v53aq.get("coherent_wrong_key_rows", "0")),
    "v53aq_public_comparison_claim_ready": int(v53aq.get("public_comparison_claim_ready", "0")),
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53t_complete_source_audit_readiness_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53t_complete_source_audit_readiness_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
