#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v10_h10_real_label_promotion_readiness_gate"
RUN_ID="${V10_H10_REAL_LABEL_PROMOTION_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V10_H10_REAL_LABEL_PROMOTION_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" && -s "$RUN_DIR/source_v53ap/abgh_evaluator_rows.csv" && -s "$RUN_DIR/source_v53aq/abgh_evaluator_rows.csv" ]] \
  && grep -q 'v53aq_evaluator_rows' "$SUMMARY_CSV"; then
  echo "v10_h10_real_label_promotion_readiness_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" --smoke >/dev/null
V53Q_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53q_complete_source_symmetric_scorer_policy.sh" >/dev/null
V53AP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ap_complete_source_abgh_same_query_measured.sh" >/dev/null
V53AQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53aq_complete_source_abgh_real_adapter_measured.sh" >/dev/null
V54C_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v54c_complete_source_grounded_generation_1000.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "${V10_H10_REAL_LABEL_EVIDENCE_CSV:-}" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
supplied_label_csv_arg = sys.argv[5]
results = root / "results"

H10_EVIDENCE_FIELDS = [
    "label_evidence_id",
    "label_scope",
    "label_source",
    "label_source_uri",
    "label_artifact_sha256",
    "reviewer_id",
    "reviewer_conflict_checked",
    "human_reviewed",
    "external_source_verified",
    "non_fixture_declared",
    "fixture_or_synthetic_declared",
    "query_rows",
    "label_rows",
    "coherent_wrong_key_labels",
    "chunk_exact_labels",
    "near_miss_labels",
    "missing_query_labels",
    "source_provenance_labels",
    "acceptance_summary_sha256",
    "routing_trigger_rate",
    "active_jump_rate",
]


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


def first_row(path):
    rows = read_csv(path)
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}")
    return rows[0]


def as_int(row, key, default="0"):
    return int(float(row.get(key, default) or default))


def as_float(row, key, default="0"):
    return float(row.get(key, default) or default)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def sha_like(value):
    return re.fullmatch(r"sha256:[0-9a-f]{64}", value or "") is not None


def https_uri(value):
    return (value or "").startswith("https://")


h10s_summary_path = results / "v10_source_verified_learned_chunk_scorer_eval_gate_smoke_summary.csv"
h10s_decision_path = results / "v10_source_verified_learned_chunk_scorer_eval_gate_smoke_decision.csv"
v53q_summary_path = results / "v53q_complete_source_symmetric_scorer_policy_summary.csv"
v53ap_summary_path = results / "v53ap_complete_source_abgh_same_query_measured_summary.csv"
v53aq_summary_path = results / "v53aq_complete_source_abgh_real_adapter_measured_summary.csv"
v54c_summary_path = results / "v54c_complete_source_grounded_generation_1000_summary.csv"
v53q_dir = results / "v53q_complete_source_symmetric_scorer_policy" / "score_001"
v53ap_dir = results / "v53ap_complete_source_abgh_same_query_measured" / "measured_001"
v53aq_dir = results / "v53aq_complete_source_abgh_real_adapter_measured" / "measured_001"
v54c_dir = results / "v54c_complete_source_grounded_generation_1000" / "generation_001"

h10s = first_row(h10s_summary_path)
v53q = first_row(v53q_summary_path)
v53ap = first_row(v53ap_summary_path)
v53aq = first_row(v53aq_summary_path)
v54c = first_row(v54c_summary_path)

if v53q.get("v53q_complete_source_symmetric_scorer_policy_ready") != "1":
    raise SystemExit("h10 PM gate requires v53q symmetric scorer/policy readiness")
if v53ap.get("v53ap_complete_source_abgh_same_query_measured_ready") != "1":
    raise SystemExit("h10 PM gate requires v53ap A/B/G/H same-query readiness")
if v53aq.get("v53aq_complete_source_abgh_real_adapter_measured_ready") != "1":
    raise SystemExit("h10 PM gate requires v53aq A/B/G/H real-adapter readiness")
if v54c.get("v54c_complete_source_grounded_generation_1000_ready") != "1":
    raise SystemExit("h10 PM gate requires v54c grounded generation readiness")

copy(h10s_summary_path, "source_h10s/v10_source_verified_learned_chunk_scorer_eval_gate_smoke_summary.csv")
copy(h10s_decision_path, "source_h10s/v10_source_verified_learned_chunk_scorer_eval_gate_smoke_decision.csv")
copy(v53q_summary_path, "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv")
copy(v53q_dir / "symmetric_system_metric_rows.csv", "source_v53q/symmetric_system_metric_rows.csv")
copy(v53q_dir / "symmetric_scorer_rows.csv", "source_v53q/symmetric_scorer_rows.csv")
copy(v53q_dir / "sha256_manifest.csv", "source_v53q/sha256_manifest.csv")
copy(v53ap_summary_path, "source_v53ap/v53ap_complete_source_abgh_same_query_measured_summary.csv")
copy(v53ap_dir / "abgh_system_metric_rows.csv", "source_v53ap/abgh_system_metric_rows.csv")
copy(v53ap_dir / "abgh_adapter_trace_rows.csv", "source_v53ap/abgh_adapter_trace_rows.csv")
copy(v53ap_dir / "abgh_evaluator_rows.csv", "source_v53ap/abgh_evaluator_rows.csv")
copy(v53ap_dir / "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md", "source_v53ap/V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md")
copy(v53aq_summary_path, "source_v53aq/v53aq_complete_source_abgh_real_adapter_measured_summary.csv")
copy(v53aq_dir / "adapter_selection_contract_rows.csv", "source_v53aq/adapter_selection_contract_rows.csv")
copy(v53aq_dir / "abgh_system_metric_rows.csv", "source_v53aq/abgh_system_metric_rows.csv")
copy(v53aq_dir / "abgh_adapter_trace_rows.csv", "source_v53aq/abgh_adapter_trace_rows.csv")
copy(v53aq_dir / "abgh_evaluator_rows.csv", "source_v53aq/abgh_evaluator_rows.csv")
copy(v53aq_dir / "abgh_wrong_answer_guard_rows.csv", "source_v53aq/abgh_wrong_answer_guard_rows.csv")
copy(v53aq_dir / "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md", "source_v53aq/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md")
copy(v54c_summary_path, "source_v54c/v54c_complete_source_grounded_generation_1000_summary.csv")
copy(v54c_dir / "answer_rows.csv", "source_v54c/answer_rows.csv")
copy(v54c_dir / "citation_rows.csv", "source_v54c/citation_rows.csv")
copy(v54c_dir / "unsupported_claim_rows.csv", "source_v54c/unsupported_claim_rows.csv")
copy(v54c_dir / "abstain_rows.csv", "source_v54c/abstain_rows.csv")
copy(v54c_dir / "wrong_answer_guard_rows.csv", "source_v54c/wrong_answer_guard_rows.csv")
copy(v54c_dir / "sha256sums.txt", "source_v54c/sha256sums.txt")

template_path = run_dir / "h10_real_label_evidence_template.csv"
write_csv(template_path, H10_EVIDENCE_FIELDS, [])

supplied_rows = []
label_source_status = "missing"
if supplied_label_csv_arg:
    supplied_path = Path(supplied_label_csv_arg)
    if not supplied_path.is_file() or supplied_path.stat().st_size == 0:
        raise SystemExit("V10_H10_REAL_LABEL_EVIDENCE_CSV must point to a non-empty CSV")
    supplied_rows = read_csv(supplied_path)
    if not supplied_rows:
        raise SystemExit("V10_H10_REAL_LABEL_EVIDENCE_CSV must include at least one data row")
    missing = [field for field in H10_EVIDENCE_FIELDS if field not in supplied_rows[0]]
    if missing:
        raise SystemExit("missing h10 real-label evidence columns: " + ",".join(missing))
    copy(supplied_path, "supplied_h10_real_label_evidence.csv")
    label_source_status = "provided"

accepted_label_rows = []
rejected_label_rows = []
for row in supplied_rows:
    label_rows = as_int(row, "label_rows")
    source_provenance_labels = as_int(row, "source_provenance_labels")
    query_rows = as_int(row, "query_rows")
    checks = {
        "https-source-uri": https_uri(row.get("label_source_uri", "")),
        "artifact-sha": sha_like(row.get("label_artifact_sha256", "")),
        "acceptance-sha": sha_like(row.get("acceptance_summary_sha256", "")),
        "human-reviewed": as_int(row, "human_reviewed") == 1,
        "external-source-verified": as_int(row, "external_source_verified") == 1,
        "reviewer-conflict-checked": as_int(row, "reviewer_conflict_checked") == 1,
        "non-fixture": as_int(row, "non_fixture_declared") == 1 and as_int(row, "fixture_or_synthetic_declared") == 0,
        "row-target": query_rows >= 1000 and label_rows >= 1000,
        "coherent-wrong-labels": as_int(row, "coherent_wrong_key_labels") > 0,
        "chunk-exact-labels": as_int(row, "chunk_exact_labels") >= label_rows,
        "near-miss-labels": as_int(row, "near_miss_labels") > 0,
        "missing-query-labels": as_int(row, "missing_query_labels") > 0,
        "source-provenance-labels": source_provenance_labels >= label_rows,
        "jump-guard": as_float(row, "routing_trigger_rate") == 0.0 and as_float(row, "active_jump_rate") == 0.0,
    }
    status = "accepted" if all(checks.values()) else "rejected"
    out = dict(row)
    out["acceptance_status"] = status
    out["failed_checks"] = ";".join(key for key, ok in checks.items() if not ok)
    if status == "accepted":
        accepted_label_rows.append(out)
    else:
        rejected_label_rows.append(out)

if supplied_rows:
    write_csv(run_dir / "h10_real_label_evidence_acceptance_rows.csv", H10_EVIDENCE_FIELDS + ["acceptance_status", "failed_checks"], accepted_label_rows + rejected_label_rows)
else:
    write_csv(run_dir / "h10_real_label_evidence_acceptance_rows.csv", H10_EVIDENCE_FIELDS + ["acceptance_status", "failed_checks"], [])

external_human_label_evidence_ready = int(len(accepted_label_rows) > 0)
accepted_human_reviewed_rows = sum(1 for row in accepted_label_rows if as_int(row, "human_reviewed") == 1)
accepted_label_row_total = sum(as_int(row, "label_rows") for row in accepted_label_rows)
fixture_or_synthetic_rows = sum(1 for row in supplied_rows if as_int(row, "fixture_or_synthetic_declared") == 1)
v53ap_adapter_trace_rows = read_csv(v53ap_dir / "abgh_adapter_trace_rows.csv")
v53ap_evaluator_rows = read_csv(v53ap_dir / "abgh_evaluator_rows.csv")
v53aq_adapter_trace_rows = read_csv(v53aq_dir / "abgh_adapter_trace_rows.csv")
v53aq_evaluator_rows = read_csv(v53aq_dir / "abgh_evaluator_rows.csv")
v53aq_metric_rows = read_csv(v53aq_dir / "abgh_system_metric_rows.csv")
v53aq_metrics_by_system = {row["system_id"]: row for row in v53aq_metric_rows}
v53ap_adapter_trace_provenance_ready = int(
    as_int(v53ap, "system_distinct_adapter_trace_ready") == 1
    and as_int(v53ap, "adapter_trace_rows") == 4000
    and len(v53ap_adapter_trace_rows) == 4000
    and {row["system_id"] for row in v53ap_adapter_trace_rows} == {"A", "B", "G", "H"}
    and all(row["source_span_binding_match"] == "1" for row in v53ap_adapter_trace_rows)
    and all(row["expected_answer_oracle_replay"] == "0" for row in v53ap_adapter_trace_rows)
    and all(row["real_system_performance_claim_ready"] == "0" for row in v53ap_adapter_trace_rows)
)
v53ap_evaluator_provenance_ready = int(
    as_int(v53ap, "same_evaluator_contract_all_local_systems") == 1
    and as_int(v53ap, "same_resource_contract_all_local_systems") == 1
    and as_int(v53ap, "evaluator_rows") == 4000
    and len(v53ap_evaluator_rows) == 4000
    and {row["system_id"] for row in v53ap_evaluator_rows} == {"A", "B", "G", "H"}
    and {row["evaluator_contract_id"] for row in v53ap_evaluator_rows} == {"v53ap-source-bound-answer-citation-resource-v1"}
    and all(row["answer_eval_separate"] == "1" for row in v53ap_evaluator_rows)
    and all(row["citation_eval_separate"] == "1" for row in v53ap_evaluator_rows)
    and all(row["resource_eval_separate"] == "1" for row in v53ap_evaluator_rows)
    and all(row["source_span_binding_match"] == "1" for row in v53ap_evaluator_rows)
    and all(row["expected_answer_oracle_replay"] == "0" for row in v53ap_evaluator_rows)
    and all(row["real_system_performance_claim_ready"] == "0" for row in v53ap_evaluator_rows)
)
v53aq_real_adapter_provenance_ready = int(
    as_int(v53aq, "v53aq_complete_source_abgh_real_adapter_measured_ready") == 1
    and as_int(v53aq, "real_adapter_execution_ready") == 1
    and as_int(v53aq, "selection_question_text_only") == 1
    and as_int(v53aq, "selection_oracle_field_used") == 0
    and as_int(v53aq, "expected_answer_oracle_replay") == 0
    and as_int(v53aq, "deterministic_source_span_adapter_execution") == 0
    and len(v53aq_adapter_trace_rows) == 4000
    and len(v53aq_evaluator_rows) == 4000
    and {row["system_id"] for row in v53aq_adapter_trace_rows} == {"A", "B", "G", "H"}
    and {row["system_id"] for row in v53aq_evaluator_rows} == {"A", "B", "G", "H"}
    and all(row["selection_question_text_used"] == "1" for row in v53aq_adapter_trace_rows)
    and all(row["selection_oracle_field_used"] == "0" for row in v53aq_adapter_trace_rows)
    and all(row["expected_answer_oracle_replay"] == "0" for row in v53aq_adapter_trace_rows)
    and all(row["deterministic_source_span_adapter_execution"] == "0" for row in v53aq_adapter_trace_rows)
    and all(row["answer_eval_separate"] == "1" for row in v53aq_evaluator_rows)
    and all(row["citation_eval_separate"] == "1" for row in v53aq_evaluator_rows)
    and all(row["resource_eval_separate"] == "1" for row in v53aq_evaluator_rows)
    and all(row["selection_question_text_only"] == "1" for row in v53aq_evaluator_rows)
    and all(row["selection_oracle_field_used"] == "0" for row in v53aq_evaluator_rows)
    and all(row["real_system_performance_claim_ready"] == "1" for row in v53aq_evaluator_rows)
)
v53aq_wrong_key_signal_ready = int(
    v53aq_real_adapter_provenance_ready == 1
    and as_int(v53aq, "coherent_wrong_key_rows") > 0
    and as_int(v53aq, "wrong_answer_rows") == as_int(v53aq, "coherent_wrong_key_rows")
    and as_int(v53aq_metrics_by_system.get("A", {}), "coherent_wrong_key_rows") > 0
    and as_int(v53aq_metrics_by_system.get("H", {}), "coherent_wrong_key_rows") == 0
    and any(row["system_id"] == "H" for row in v53aq_adapter_trace_rows)
    and all(
        row["source_verified_scorer_used"] == "1" and row["domain_policy_used"] == "1"
        for row in v53aq_adapter_trace_rows
        if row["system_id"] == "H"
    )
)

h10_diagnostic_scorer_signal_ready = int(
    as_float(h10s, "learned_score_gap") > 0.0
    and as_float(h10s, "coherent_wrong_negative_rate") >= 0.999999
    and as_float(h10s, "correct_reward_rate") >= 0.999999
)
source_provenance_binding_ready = int(
    as_int(v53q, "symmetric_scorer_policy_rows_ready") == 1
    and as_int(v53q, "citation_span_match_rows") == as_int(v53q, "core_answer_rows")
    and as_int(v53q, "resource_row_bound_rows") == as_int(v53q, "core_answer_rows")
    and v53ap_adapter_trace_provenance_ready == 1
    and v53ap_evaluator_provenance_ready == 1
    and v53aq_real_adapter_provenance_ready == 1
    and as_int(v54c, "citation_correct_rows") == as_int(v54c, "generation_rows")
)
missing_query_abstain_ready = int(
    as_int(v53ap, "missing_specific_abstain_rows") == 30
    and as_int(v54c, "missing_specific_abstain_rows") == 30
    and as_int(v54c, "abstain_rows") == as_int(v54c, "unsupported_claim_rows")
)
wrong_answer_guard_ready = int(
    as_int(v53ap, "wrong_answer_guard_rows") == 4000
    and as_int(v54c, "wrong_answer_guard_rows") == 1000
    and as_int(v54c, "wrong_answer_rows") == 0
)
same_query_abgh_ready = int(
    as_int(v53ap, "same_query_set_all_local_systems") == 1
    and as_int(v53ap, "same_source_manifest_all_local_systems") == 1
    and as_int(v53ap, "same_evaluator_contract_all_local_systems") == 1
    and as_int(v53ap, "same_resource_contract_all_local_systems") == 1
    and v53ap_adapter_trace_provenance_ready == 1
    and v53ap_evaluator_provenance_ready == 1
    and v53ap.get("systems") == "A/B/G/H"
)
same_query_real_adapter_ready = int(
    as_int(v53aq, "same_query_set_all_local_systems") == 1
    and as_int(v53aq, "same_source_manifest_all_local_systems") == 1
    and as_int(v53aq, "same_evaluator_contract_all_local_systems") == 1
    and as_int(v53aq, "same_resource_contract_all_local_systems") == 1
    and v53aq_real_adapter_provenance_ready == 1
    and v53aq.get("systems") == "A/B/G/H"
)

h10_source_verified_eval_ready = as_int(h10s, "source_verified_learned_chunk_scorer_eval_ready")
student_only_eval_ready = as_int(h10s, "student_only_eval_ready")
metric_improvement_ready = as_int(h10s, "metric_improvement_ready")
chunk_exact_real_label_ready = int(h10_source_verified_eval_ready == 1 and as_float(h10s, "chunk_exact_delta") > 0.0 and external_human_label_evidence_ready)
near_miss_real_label_ready = int(h10_source_verified_eval_ready == 1 and as_float(h10s, "near_miss_negative_rate") >= 0.999999 and external_human_label_evidence_ready)
coherent_wrong_real_label_ready = int(h10_source_verified_eval_ready == 1 and as_float(h10s, "coherent_wrong_negative_rate") >= 0.999999 and external_human_label_evidence_ready)
missing_abstain_real_label_ready = int(h10_source_verified_eval_ready == 1 and as_float(h10s, "missing_abstain_rate") >= 0.999999 and external_human_label_evidence_ready)

h10_real_label_promotion_ready = int(
    h10_source_verified_eval_ready == 1
    and external_human_label_evidence_ready == 1
    and coherent_wrong_real_label_ready == 1
    and chunk_exact_real_label_ready == 1
    and near_miss_real_label_ready == 1
    and missing_abstain_real_label_ready == 1
    and source_provenance_binding_ready == 1
    and missing_query_abstain_ready == 1
    and wrong_answer_guard_ready == 1
    and same_query_abgh_ready == 1
    and same_query_real_adapter_ready == 1
)

acceptance_rows = [
    {
        "criterion": "coherent-wrong-key-reduction",
        "machine_evidence_status": "diagnostic-pass" if h10_diagnostic_scorer_signal_ready and v53aq_wrong_key_signal_ready else "blocked",
        "real_label_status": "pass" if coherent_wrong_real_label_ready else "blocked",
        "evidence": (
            f"h10s_coherent_wrong_negative_rate={h10s.get('coherent_wrong_negative_rate', '0')}; "
            f"v53aq_coherent_wrong_key_rows={v53aq.get('coherent_wrong_key_rows', '0')}; "
            f"v53aq_A_coherent_wrong_key_rows={v53aq_metrics_by_system.get('A', {}).get('coherent_wrong_key_rows', '0')}; "
            f"v53aq_H_coherent_wrong_key_rows={v53aq_metrics_by_system.get('H', {}).get('coherent_wrong_key_rows', '0')}"
        ),
        "blocker": "real source-verified eval and external/human labels required" if not coherent_wrong_real_label_ready else "",
    },
    {
        "criterion": "chunk-exact-increase",
        "machine_evidence_status": "pass" if metric_improvement_ready and as_float(h10s, "chunk_exact_delta") > 0.0 else "blocked",
        "real_label_status": "pass" if chunk_exact_real_label_ready else "blocked",
        "evidence": f"h10s_chunk_exact_delta={h10s.get('chunk_exact_delta', '0')}",
        "blocker": "student-only source-verified eval with real labels missing" if not chunk_exact_real_label_ready else "",
    },
    {
        "criterion": "near-miss-slash",
        "machine_evidence_status": "pass" if as_float(h10s, "near_miss_negative_rate") >= 0.999999 else "blocked",
        "real_label_status": "pass" if near_miss_real_label_ready else "blocked",
        "evidence": f"h10s_near_miss_negative_rate={h10s.get('near_miss_negative_rate', '0')}",
        "blocker": "near-miss real-label eval rows missing" if not near_miss_real_label_ready else "",
    },
    {
        "criterion": "missing-query-abstain",
        "machine_evidence_status": "pass" if missing_query_abstain_ready else "blocked",
        "real_label_status": "pass" if missing_abstain_real_label_ready else "blocked",
        "evidence": f"v53ap_missing=30; v54c_missing=30; v54c_abstain_rows={v54c.get('abstain_rows')}",
        "blocker": "real-label missing-query eval rows missing" if not missing_abstain_real_label_ready else "",
    },
    {
        "criterion": "source-provenance-binding",
        "machine_evidence_status": "pass" if source_provenance_binding_ready else "blocked",
        "real_label_status": "pass" if source_provenance_binding_ready and external_human_label_evidence_ready else "blocked",
        "evidence": f"v53q_scorer_rows={v53q.get('symmetric_scorer_rows')}; v53ap_adapter_trace_rows={len(v53ap_adapter_trace_rows)}; v53ap_evaluator_rows={len(v53ap_evaluator_rows)}; v53aq_adapter_trace_rows={len(v53aq_adapter_trace_rows)}; v53aq_evaluator_rows={len(v53aq_evaluator_rows)}; v54c_citation_correct={v54c.get('citation_correct_rows')}",
        "blocker": "accepted external/human label evidence must bind provenance rows" if not external_human_label_evidence_ready else "",
    },
    {
        "criterion": "external-human-label-evidence",
        "machine_evidence_status": "blocked",
        "real_label_status": "pass" if external_human_label_evidence_ready else "blocked",
        "evidence": f"accepted_real_label_evidence_rows={len(accepted_label_rows)}",
        "blocker": "real external/human label return missing" if not external_human_label_evidence_ready else "",
    },
]
write_csv(run_dir / "pm_h10_real_label_acceptance_rows.csv", list(acceptance_rows[0].keys()), acceptance_rows)

summary = {
    "v10_h10_real_label_promotion_readiness_gate_ready": "1",
    "h10_real_label_promotion_ready": str(h10_real_label_promotion_ready),
    "h10_source_verified_eval_ready": str(h10_source_verified_eval_ready),
    "student_only_eval_ready": str(student_only_eval_ready),
    "metric_improvement_ready": str(metric_improvement_ready),
    "h10_diagnostic_scorer_signal_ready": str(h10_diagnostic_scorer_signal_ready),
    "coherent_wrong_real_label_ready": str(coherent_wrong_real_label_ready),
    "chunk_exact_real_label_ready": str(chunk_exact_real_label_ready),
    "near_miss_real_label_ready": str(near_miss_real_label_ready),
    "missing_abstain_real_label_ready": str(missing_abstain_real_label_ready),
    "source_provenance_binding_ready": str(source_provenance_binding_ready),
    "v53ap_adapter_trace_provenance_ready": str(v53ap_adapter_trace_provenance_ready),
    "v53ap_adapter_trace_rows": str(len(v53ap_adapter_trace_rows)),
    "v53ap_evaluator_provenance_ready": str(v53ap_evaluator_provenance_ready),
    "v53ap_evaluator_rows": str(len(v53ap_evaluator_rows)),
    "v53ap_same_evaluator_contract_ready": v53ap.get("same_evaluator_contract_all_local_systems", "0"),
    "v53ap_same_resource_contract_ready": v53ap.get("same_resource_contract_all_local_systems", "0"),
    "v53ap_system_distinct_adapter_trace_ready": v53ap.get("system_distinct_adapter_trace_ready", "0"),
    "v53aq_real_adapter_provenance_ready": str(v53aq_real_adapter_provenance_ready),
    "v53aq_wrong_key_signal_ready": str(v53aq_wrong_key_signal_ready),
    "v53aq_adapter_trace_rows": str(len(v53aq_adapter_trace_rows)),
    "v53aq_evaluator_rows": str(len(v53aq_evaluator_rows)),
    "v53aq_selection_question_text_only": v53aq.get("selection_question_text_only", "0"),
    "v53aq_selection_oracle_field_used": v53aq.get("selection_oracle_field_used", "1"),
    "v53aq_expected_answer_oracle_replay": v53aq.get("expected_answer_oracle_replay", "0"),
    "v53aq_deterministic_source_span_adapter_execution": v53aq.get("deterministic_source_span_adapter_execution", "1"),
    "v53aq_real_adapter_execution_ready": v53aq.get("real_adapter_execution_ready", "0"),
    "v53aq_real_system_performance_claim_ready": v53aq.get("real_system_performance_claim_ready", "0"),
    "v53aq_answer_hash_match_rows": v53aq.get("answer_hash_match_rows", "0"),
    "v53aq_coherent_wrong_key_rows": v53aq.get("coherent_wrong_key_rows", "0"),
    "missing_query_abstain_ready": str(missing_query_abstain_ready),
    "wrong_answer_guard_ready": str(wrong_answer_guard_ready),
    "same_query_abgh_ready": str(same_query_abgh_ready),
    "same_query_real_adapter_ready": str(same_query_real_adapter_ready),
    "external_human_label_evidence_ready": str(external_human_label_evidence_ready),
    "label_source_status": label_source_status,
    "supplied_real_label_evidence_rows": str(len(supplied_rows)),
    "accepted_real_label_evidence_rows": str(len(accepted_label_rows)),
    "rejected_real_label_evidence_rows": str(len(rejected_label_rows)),
    "fixture_or_synthetic_label_evidence_rows": str(fixture_or_synthetic_rows),
    "accepted_human_reviewed_rows": str(accepted_human_reviewed_rows),
    "accepted_label_rows": str(accepted_label_row_total),
    "h10s_reason": h10s.get("reason", ""),
    "learned_score_gap": h10s.get("learned_score_gap", "0"),
    "coherent_wrong_negative_rate": h10s.get("coherent_wrong_negative_rate", "0"),
    "near_miss_negative_rate": h10s.get("near_miss_negative_rate", "0"),
    "missing_abstain_rate": h10s.get("missing_abstain_rate", "0"),
    "chunk_exact_delta": h10s.get("chunk_exact_delta", "0"),
    "v53q_complete_source_symmetric_scorer_policy_ready": v53q["v53q_complete_source_symmetric_scorer_policy_ready"],
    "v53ap_complete_source_abgh_same_query_measured_ready": v53ap["v53ap_complete_source_abgh_same_query_measured_ready"],
    "v53aq_complete_source_abgh_real_adapter_measured_ready": v53aq["v53aq_complete_source_abgh_real_adapter_measured_ready"],
    "v54c_complete_source_grounded_generation_1000_ready": v54c["v54c_complete_source_grounded_generation_1000_ready"],
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53-complete-source-symmetric-scorer-policy", "pass" if source_provenance_binding_ready else "blocked", "source provenance and symmetric scorer rows are bound"),
    ("v53ap-abgh-same-query-prebaseline", "pass" if same_query_abgh_ready else "blocked", "A/B/G/H share v53i complete-source query/source/evaluator/resource set and adapter trace provenance"),
    ("v53aq-abgh-real-adapter-evidence", "pass" if same_query_real_adapter_ready and v53aq_wrong_key_signal_ready else "blocked", "A/B/G/H query-text-only real-adapter rows expose wrong-key and provenance evidence"),
    ("v54c-grounded-generation-guard", "pass" if wrong_answer_guard_ready and missing_query_abstain_ready else "blocked", "wrong-answer and missing/abstain guards are present"),
    ("h10-diagnostic-scorer-signal", "pass" if h10_diagnostic_scorer_signal_ready else "blocked", "local h10 diagnostic scorer separates correct/coherent-wrong rows"),
    ("h10-source-verified-eval", "pass" if h10_source_verified_eval_ready else "blocked", h10s.get("reason", "source-verified eval missing")),
    ("h10-external-human-label-evidence", "pass" if external_human_label_evidence_ready else "blocked", "accepted external/human label return rows are required"),
    ("h10-real-label-promotion", "pass" if h10_real_label_promotion_ready else "blocked", "all PM h10 real-label criteria must pass together"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md").write_text(
    "# h10 Real-Label Promotion Readiness Boundary\n\n"
    "This gate does not promote h10 by itself. It binds the PM h10 scorer criteria to current complete-source artifacts and fails closed until accepted external/human label evidence and h10 source-verified evaluation are both present.\n\n"
    f"- h10_real_label_promotion_ready={h10_real_label_promotion_ready}\n"
    f"- h10_source_verified_eval_ready={h10_source_verified_eval_ready}\n"
    f"- external_human_label_evidence_ready={external_human_label_evidence_ready}\n"
    f"- source_provenance_binding_ready={source_provenance_binding_ready}\n"
    f"- v53ap_adapter_trace_provenance_ready={v53ap_adapter_trace_provenance_ready}\n"
    f"- v53ap_adapter_trace_rows={len(v53ap_adapter_trace_rows)}\n"
    f"- v53ap_evaluator_provenance_ready={v53ap_evaluator_provenance_ready}\n"
    f"- v53ap_evaluator_rows={len(v53ap_evaluator_rows)}\n"
    f"- v53aq_real_adapter_provenance_ready={v53aq_real_adapter_provenance_ready}\n"
    f"- v53aq_wrong_key_signal_ready={v53aq_wrong_key_signal_ready}\n"
    f"- v53aq_adapter_trace_rows={len(v53aq_adapter_trace_rows)}\n"
    f"- v53aq_evaluator_rows={len(v53aq_evaluator_rows)}\n"
    f"- v53aq_selection_question_text_only={v53aq.get('selection_question_text_only', '0')}\n"
    f"- v53aq_selection_oracle_field_used={v53aq.get('selection_oracle_field_used', '1')}\n"
    f"- v53aq_coherent_wrong_key_rows={v53aq.get('coherent_wrong_key_rows', '0')}\n"
    f"- missing_query_abstain_ready={missing_query_abstain_ready}\n"
    f"- wrong_answer_guard_ready={wrong_answer_guard_ready}\n"
    f"- same_query_abgh_ready={same_query_abgh_ready}\n"
    f"- accepted_real_label_evidence_rows={len(accepted_label_rows)}\n\n"
    "Allowed wording: h10 real-label promotion readiness gate; complete-source provenance, missing/abstain, and wrong-answer guard surfaces are machine-bound.\n\n"
    "Blocked wording: h10 real-label promotion, human-reviewed scorer quality, scientific contribution claim, release readiness, or public comparison claim.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v10-h10-real-label-promotion-readiness-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v10_h10_real_label_promotion_readiness_gate_ready": 1,
    "h10_real_label_promotion_ready": h10_real_label_promotion_ready,
    "h10_source_verified_eval_ready": h10_source_verified_eval_ready,
    "external_human_label_evidence_ready": external_human_label_evidence_ready,
    "source_provenance_binding_ready": source_provenance_binding_ready,
    "v53ap_adapter_trace_provenance_ready": v53ap_adapter_trace_provenance_ready,
    "v53ap_adapter_trace_rows": len(v53ap_adapter_trace_rows),
    "v53ap_evaluator_provenance_ready": v53ap_evaluator_provenance_ready,
    "v53ap_evaluator_rows": len(v53ap_evaluator_rows),
    "v53ap_same_evaluator_contract_ready": as_int(v53ap, "same_evaluator_contract_all_local_systems"),
    "v53ap_same_resource_contract_ready": as_int(v53ap, "same_resource_contract_all_local_systems"),
    "v53aq_real_adapter_provenance_ready": v53aq_real_adapter_provenance_ready,
    "v53aq_wrong_key_signal_ready": v53aq_wrong_key_signal_ready,
    "v53aq_adapter_trace_rows": len(v53aq_adapter_trace_rows),
    "v53aq_evaluator_rows": len(v53aq_evaluator_rows),
    "v53aq_selection_question_text_only": as_int(v53aq, "selection_question_text_only"),
    "v53aq_selection_oracle_field_used": as_int(v53aq, "selection_oracle_field_used"),
    "v53aq_real_adapter_execution_ready": as_int(v53aq, "real_adapter_execution_ready"),
    "v53aq_real_system_performance_claim_ready": as_int(v53aq, "real_system_performance_claim_ready"),
    "v53aq_answer_hash_match_rows": as_int(v53aq, "answer_hash_match_rows"),
    "v53aq_coherent_wrong_key_rows": as_int(v53aq, "coherent_wrong_key_rows"),
    "missing_query_abstain_ready": missing_query_abstain_ready,
    "wrong_answer_guard_ready": wrong_answer_guard_ready,
    "same_query_abgh_ready": same_query_abgh_ready,
    "same_query_real_adapter_ready": same_query_real_adapter_ready,
    "accepted_real_label_evidence_rows": len(accepted_label_rows),
    "source_summary_sha256": {
        "h10s": sha256(h10s_summary_path),
        "v53q": sha256(v53q_summary_path),
        "v53ap": sha256(v53ap_summary_path),
        "v53aq": sha256(v53aq_summary_path),
        "v54c": sha256(v54c_summary_path),
    },
    "real_release_package_ready": 0,
}
(run_dir / "v10_h10_real_label_promotion_readiness_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v10_h10_real_label_promotion_readiness_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
