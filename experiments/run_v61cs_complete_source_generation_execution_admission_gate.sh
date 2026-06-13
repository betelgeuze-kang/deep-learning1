#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cs_complete_source_generation_execution_admission_gate"
RUN_ID="${V61CS_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cs_complete_source_generation_execution_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ck_real_generation_unblocker_operator_matrix.sh" >/dev/null
V61CR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null
V61CW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
V61CF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cf_ubuntu1_source_bound_generation_execution_packet.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

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
model_id = "mistralai/Mixtral-8x22B-v0.1"


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


v61ck_dir = results / "v61ck_real_generation_unblocker_operator_matrix" / "matrix_001"
v61cr_dir = results / "v61cr_complete_source_runtime_admission_return_intake" / "intake_001"
v61cw_dir = results / "v61cw_complete_source_runtime_admission_acceptance_bridge" / "bridge_001"
v61cf_dir = results / "v61cf_ubuntu1_source_bound_generation_execution_packet" / "packet_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"

v61ck_summary_path = results / "v61ck_real_generation_unblocker_operator_matrix_summary.csv"
v61cr_summary_path = results / "v61cr_complete_source_runtime_admission_return_intake_summary.csv"
v61cw_summary_path = results / "v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv"
v61cf_summary_path = results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61ck_decision_path = results / "v61ck_real_generation_unblocker_operator_matrix_decision.csv"
v61cr_decision_path = results / "v61cr_complete_source_runtime_admission_return_intake_decision.csv"
v61cw_decision_path = results / "v61cw_complete_source_runtime_admission_acceptance_bridge_decision.csv"
v61cf_decision_path = results / "v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"

v61ck = read_csv(v61ck_summary_path)[0]
v61cr = read_csv(v61cr_summary_path)[0]
v61cw = read_csv(v61cw_summary_path)[0]
v61cf = read_csv(v61cf_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]

for key, row in [
    ("v61ck_real_generation_unblocker_operator_matrix_ready", v61ck),
    ("v61cr_complete_source_runtime_admission_return_intake_ready", v61cr),
    ("v61cw_complete_source_runtime_admission_acceptance_bridge_ready", v61cw),
    ("v61cf_ubuntu1_source_bound_generation_execution_packet_ready", v61cf),
    ("v61bt_ubuntu1_actual_generation_result_intake_ready", v61bt),
]:
    if row.get(key) != "1":
        raise SystemExit(f"v61cs requires {key}=1")

for src, rel in [
    (v61ck_summary_path, "source_v61ck/v61ck_real_generation_unblocker_operator_matrix_summary.csv"),
    (v61ck_decision_path, "source_v61ck/v61ck_real_generation_unblocker_operator_matrix_decision.csv"),
    (v61ck_dir / "real_generation_unblocker_matrix_rows.csv", "source_v61ck/real_generation_unblocker_matrix_rows.csv"),
    (v61ck_dir / "real_generation_operator_execution_order_rows.csv", "source_v61ck/real_generation_operator_execution_order_rows.csv"),
    (v61ck_dir / "sha256_manifest.csv", "source_v61ck/sha256_manifest.csv"),
    (v61cr_summary_path, "source_v61cr/v61cr_complete_source_runtime_admission_return_intake_summary.csv"),
    (v61cr_decision_path, "source_v61cr/v61cr_complete_source_runtime_admission_return_intake_decision.csv"),
    (v61cr_dir / "complete_source_runtime_admission_return_artifact_status_rows.csv", "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv"),
    (v61cr_dir / "complete_source_runtime_admission_return_requirement_rows.csv", "source_v61cr/complete_source_runtime_admission_return_requirement_rows.csv"),
    (v61cr_dir / "complete_source_runtime_admission_return_metric_rows.csv", "source_v61cr/complete_source_runtime_admission_return_metric_rows.csv"),
    (v61cr_dir / "sha256_manifest.csv", "source_v61cr/sha256_manifest.csv"),
    (v61cw_summary_path, "source_v61cw/v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv"),
    (v61cw_decision_path, "source_v61cw/v61cw_complete_source_runtime_admission_acceptance_bridge_decision.csv"),
    (v61cw_dir / "complete_source_runtime_admission_acceptance_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv"),
    (v61cw_dir / "complete_source_runtime_admission_acceptance_requirement_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_requirement_rows.csv"),
    (v61cw_dir / "complete_source_runtime_admission_acceptance_metric_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_metric_rows.csv"),
    (v61cw_dir / "sha256_manifest.csv", "source_v61cw/sha256_manifest.csv"),
    (v61cf_summary_path, "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"),
    (v61cf_decision_path, "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"),
    (v61cf_dir / "source_bound_generation_execution_packet_rows.csv", "source_v61cf/source_bound_generation_execution_packet_rows.csv"),
    (v61cf_dir / "source_bound_generation_prompt_manifest_rows.csv", "source_v61cf/source_bound_generation_prompt_manifest_rows.csv"),
    (v61cf_dir / "source_bound_generation_return_manifest_rows.csv", "source_v61cf/source_bound_generation_return_manifest_rows.csv"),
    (v61cf_dir / "source_bound_generation_operator_command_rows.csv", "source_v61cf/source_bound_generation_operator_command_rows.csv"),
    (v61cf_dir / "sha256_manifest.csv", "source_v61cf/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_result_status_rows.csv", "source_v61bt/actual_generation_result_status_rows.csv"),
    (v61bt_dir / "actual_generation_result_metric_rows.csv", "source_v61bt/actual_generation_result_metric_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
]:
    copy(src, rel)

packet_rows = read_csv(v61cf_dir / "source_bound_generation_execution_packet_rows.csv")
if len(packet_rows) != 1000:
    raise SystemExit("v61cs expects 1000 v61cf generation execution packet rows")

target_root = v61ck["target_root_path"]
if v61cf["target_root_path"] != target_root or v61bt["target_root_path"] != target_root:
    raise SystemExit("v61cs requires v61ck/v61cf/v61bt target root match")

full_checkpoint_materialization_ready = as_int(v61ck, "full_checkpoint_materialization_ready")
completed_full_page_hash_coverage_ready = as_int(v61ck, "completed_full_safetensors_page_hash_coverage_ready")
full_page_hash_binding_ready = as_int(v61ck, "full_safetensors_page_hash_binding_ready")
page_hash_ready = int(completed_full_page_hash_coverage_ready and full_page_hash_binding_ready)
review_return_ready = as_int(v61ck, "review_return_ready")
runtime_admission_ready = as_int(v61cw, "complete_source_runtime_admission_execution_ready")
operator_handoff_ready = as_int(v61ck, "generation_operator_bundle_handoff_ready")
execution_packet_ready = as_int(v61cf, "v61cf_ubuntu1_source_bound_generation_execution_packet_ready")
generation_result_artifacts_ready = as_int(v61bt, "generation_packet_artifacts_ready")

generation_execution_admission_ready = int(
    full_checkpoint_materialization_ready
    and page_hash_ready
    and review_return_ready
    and runtime_admission_ready
    and operator_handoff_ready
    and execution_packet_ready
)
actual_model_generation_ready = int(generation_execution_admission_ready and generation_result_artifacts_ready)

admission_rows = []
materialization_blocked_rows = 0
page_hash_blocked_rows = 0
runtime_admission_blocked_rows = 0
review_return_blocked_rows = 0
operator_blocked_rows = 0
generation_result_artifact_blocked_rows = 0
admitted_rows = 0
actual_ready_rows = 0

for index, packet in enumerate(packet_rows):
    materialization_blocked = int(not full_checkpoint_materialization_ready)
    page_hash_blocked = int(not page_hash_ready)
    runtime_blocked = int(not runtime_admission_ready)
    review_blocked = int(not review_return_ready)
    operator_blocked = int(not operator_handoff_ready or not execution_packet_ready)
    artifact_blocked = int(not generation_result_artifacts_ready)
    admitted = int(
        not materialization_blocked
        and not page_hash_blocked
        and not runtime_blocked
        and not review_blocked
        and not operator_blocked
    )
    actual_ready = int(admitted and not artifact_blocked)

    materialization_blocked_rows += materialization_blocked
    page_hash_blocked_rows += page_hash_blocked
    runtime_admission_blocked_rows += runtime_blocked
    review_return_blocked_rows += review_blocked
    operator_blocked_rows += operator_blocked
    generation_result_artifact_blocked_rows += artifact_blocked
    admitted_rows += admitted
    actual_ready_rows += actual_ready

    blocking_reasons = []
    if materialization_blocked:
        blocking_reasons.append("full-checkpoint-materialization-blocked")
    if page_hash_blocked:
        blocking_reasons.append("full-page-hash-coverage-blocked")
    if runtime_blocked:
        blocking_reasons.append("complete-source-runtime-admission-blocked")
    if review_blocked:
        blocking_reasons.append("complete-source-review-return-blocked")
    if operator_blocked:
        blocking_reasons.append("generation-operator-handoff-blocked")
    if artifact_blocked:
        blocking_reasons.append("generation-result-artifacts-missing")

    admission_rows.append(
        {
            "generation_execution_admission_id": f"v61cs-generation-execution-admission-{index:04d}",
            "generation_execution_packet_id": packet["generation_execution_packet_id"],
            "review_query_packet_id": packet["review_query_packet_id"],
            "query_id": packet["query_id"],
            "owner_repo": packet["owner_repo"],
            "audit_type": packet["audit_type"],
            "expected_behavior": packet["expected_behavior"],
            "source_span_id": packet["source_span_id"],
            "source_path": packet["source_path"],
            "source_file_sha256": packet["source_file_sha256"],
            "model_id": packet["model_id"],
            "checkpoint_root": packet["checkpoint_root"],
            "full_checkpoint_materialization_ready": str(full_checkpoint_materialization_ready),
            "completed_full_safetensors_page_hash_coverage_ready": str(completed_full_page_hash_coverage_ready),
            "full_safetensors_page_hash_binding_ready": str(full_page_hash_binding_ready),
            "complete_source_runtime_admission_execution_ready": str(runtime_admission_ready),
            "complete_source_review_return_ready": str(review_return_ready),
            "generation_operator_bundle_handoff_ready": str(operator_handoff_ready),
            "generation_execution_packet_ready": str(execution_packet_ready),
            "generation_result_artifacts_ready": str(generation_result_artifacts_ready),
            "materialization_blocked": str(materialization_blocked),
            "page_hash_blocked": str(page_hash_blocked),
            "runtime_admission_blocked": str(runtime_blocked),
            "review_return_blocked": str(review_blocked),
            "operator_handoff_blocked": str(operator_blocked),
            "generation_result_artifact_blocked": str(artifact_blocked),
            "generation_execution_admitted": str(admitted),
            "actual_model_generation_ready": str(actual_ready),
            "blocking_reason": ";".join(blocking_reasons) if blocking_reasons else "admitted",
            "checkpoint_payload_bytes_downloaded_by_v61cs": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "complete_source_generation_execution_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)

requirement_rows = [
    {"requirement_id": "v61ck-operator-matrix-input", "status": "pass", "required_value": "1", "actual_value": v61ck["v61ck_real_generation_unblocker_operator_matrix_ready"], "reason": "operator matrix is bound"},
    {"requirement_id": "v61cr-runtime-admission-return-input", "status": "pass", "required_value": "1", "actual_value": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"], "reason": "runtime admission return intake is bound"},
    {"requirement_id": "v61cw-runtime-admission-acceptance-input", "status": "pass", "required_value": "1", "actual_value": v61cw["v61cw_complete_source_runtime_admission_acceptance_bridge_ready"], "reason": "runtime admission acceptance bridge is bound"},
    {"requirement_id": "v61cf-generation-execution-packet-input", "status": "pass", "required_value": "1", "actual_value": v61cf["v61cf_ubuntu1_source_bound_generation_execution_packet_ready"], "reason": "generation execution packet is bound"},
    {"requirement_id": "full-checkpoint-materialization", "status": "pass" if full_checkpoint_materialization_ready else "blocked", "required_value": "1", "actual_value": str(full_checkpoint_materialization_ready), "reason": "all checkpoint shards must be materialized and identity verified"},
    {"requirement_id": "completed-full-safetensors-page-hash-coverage", "status": "pass" if page_hash_ready else "blocked", "required_value": "1", "actual_value": str(page_hash_ready), "reason": "all checkpoint pages must be hash verified"},
    {"requirement_id": "complete-source-runtime-admission-execution", "status": "pass" if runtime_admission_ready else "blocked", "required_value": v61cw["runtime_admission_acceptance_rows"], "actual_value": v61cw["runtime_admission_accepted_rows"], "reason": "all complete-source runtime admission acceptance rows must be accepted"},
    {"requirement_id": "complete-source-review-return", "status": "pass" if review_return_ready else "blocked", "required_value": v61ck["expected_human_review_rows"], "actual_value": v61ck["accepted_human_review_rows"], "reason": "human review return must be accepted"},
    {"requirement_id": "generation-operator-handoff", "status": "pass" if operator_handoff_ready and execution_packet_ready else "blocked", "required_value": "1", "actual_value": str(int(operator_handoff_ready and execution_packet_ready)), "reason": "operator bundle and execution packet must be ready"},
    {"requirement_id": "actual-generation-result-artifacts", "status": "pass" if generation_result_artifacts_ready else "blocked", "required_value": v61bt["expected_generation_result_artifacts"], "actual_value": v61bt["accepted_generation_result_artifacts"], "reason": "actual generation artifacts are required before claiming generation ready"},
    {"requirement_id": "complete-source-generation-execution-admission", "status": "pass" if generation_execution_admission_ready else "blocked", "required_value": str(len(packet_rows)), "actual_value": str(admitted_rows), "reason": "execution admission requires materialization, page hash, runtime admission, review return, and operator handoff"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61cs writes metadata and copied evidence only"},
]
write_csv(run_dir / "complete_source_generation_execution_admission_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cs_complete_source_generation_execution_admission_gate_metrics",
    "model_id": model_id,
    "v61ck_real_generation_unblocker_operator_matrix_ready": v61ck["v61ck_real_generation_unblocker_operator_matrix_ready"],
    "v61cr_complete_source_runtime_admission_return_intake_ready": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"],
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": v61cw["v61cw_complete_source_runtime_admission_acceptance_bridge_ready"],
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": v61cf["v61cf_ubuntu1_source_bound_generation_execution_packet_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "complete_source_query_rows": str(len(packet_rows)),
    "full_checkpoint_materialization_ready": str(full_checkpoint_materialization_ready),
    "completed_full_safetensors_page_hash_coverage_ready": str(completed_full_page_hash_coverage_ready),
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_binding_ready),
    "complete_source_runtime_admission_execution_ready": str(runtime_admission_ready),
    "complete_source_review_return_ready": str(review_return_ready),
    "generation_operator_bundle_handoff_ready": str(operator_handoff_ready),
    "generation_execution_packet_ready": str(execution_packet_ready),
    "generation_result_artifacts_ready": str(generation_result_artifacts_ready),
    "generation_execution_admission_ready": str(generation_execution_admission_ready),
    "generation_execution_admission_rows": str(len(packet_rows)),
    "generation_execution_admitted_rows": str(admitted_rows),
    "generation_execution_blocked_rows": str(len(packet_rows) - admitted_rows),
    "materialization_blocked_generation_rows": str(materialization_blocked_rows),
    "page_hash_blocked_generation_rows": str(page_hash_blocked_rows),
    "runtime_admission_blocked_generation_rows": str(runtime_admission_blocked_rows),
    "review_return_blocked_generation_rows": str(review_return_blocked_rows),
    "operator_handoff_blocked_generation_rows": str(operator_blocked_rows),
    "generation_result_artifact_blocked_rows": str(generation_result_artifact_blocked_rows),
    "runtime_admission_acceptance_rows": v61cw["runtime_admission_acceptance_rows"],
    "runtime_admission_accepted_rows": v61cw["runtime_admission_accepted_rows"],
    "runtime_artifact_blocked_acceptance_rows": v61cw["runtime_artifact_blocked_acceptance_rows"],
    "runtime_result_blocked_acceptance_rows": v61cw["runtime_result_blocked_acceptance_rows"],
    "runtime_page_binding_blocked_acceptance_rows": v61cw["runtime_page_binding_blocked_acceptance_rows"],
    "runtime_budget_blocked_acceptance_rows": v61cw["runtime_budget_blocked_acceptance_rows"],
    "runtime_identity_blocked_acceptance_rows": v61cw["runtime_identity_blocked_acceptance_rows"],
    "runtime_safety_blocked_acceptance_rows": v61cw["runtime_safety_blocked_acceptance_rows"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "actual_model_generation_ready_rows": str(actual_ready_rows),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cs": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_generation_execution_admission_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "full-checkpoint-materialization", "status": "ready" if full_checkpoint_materialization_ready else "blocked", "reason": f"full_checkpoint_materialization_ready={full_checkpoint_materialization_ready}"},
    {"gap": "completed-full-safetensors-page-hash-coverage", "status": "ready" if page_hash_ready else "blocked", "reason": f"completed_full_safetensors_page_hash_coverage_ready={completed_full_page_hash_coverage_ready}, full_safetensors_page_hash_binding_ready={full_page_hash_binding_ready}"},
    {"gap": "complete-source-runtime-admission-execution", "status": "ready" if runtime_admission_ready else "blocked", "reason": f"runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}/{v61cw['runtime_admission_acceptance_rows']}"},
    {"gap": "complete-source-review-return", "status": "ready" if review_return_ready else "blocked", "reason": f"accepted_human_review_rows={v61ck['accepted_human_review_rows']}/{v61ck['expected_human_review_rows']}"},
    {"gap": "generation-operator-handoff", "status": "ready" if operator_handoff_ready and execution_packet_ready else "blocked", "reason": f"operator_handoff={operator_handoff_ready}, execution_packet={execution_packet_ready}"},
    {"gap": "actual-generation-result-artifacts", "status": "ready" if generation_result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gap": "complete-source-generation-execution-admission", "status": "ready" if generation_execution_admission_ready else "blocked", "reason": f"generation_execution_admitted_rows={admitted_rows}/{len(packet_rows)}"},
    {"gap": "actual-model-generation", "status": "ready" if actual_model_generation_ready else "blocked", "reason": f"actual_model_generation_ready_rows={actual_ready_rows}/{len(packet_rows)}"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode latency benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61ck-operator-matrix-input", "status": "pass", "reason": "operator matrix is ready"},
    {"gate": "v61cr-runtime-admission-return-input", "status": "pass", "reason": "runtime admission return intake is ready"},
    {"gate": "v61cw-runtime-admission-acceptance-input", "status": "pass", "reason": "runtime admission acceptance bridge is ready"},
    {"gate": "v61cf-generation-execution-packet-input", "status": "pass", "reason": "generation execution packet is ready"},
    {"gate": "full-checkpoint-materialization", "status": "pass" if full_checkpoint_materialization_ready else "blocked", "reason": f"full_checkpoint_materialization_ready={full_checkpoint_materialization_ready}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if page_hash_ready else "blocked", "reason": f"page_hash_ready={page_hash_ready}"},
    {"gate": "complete-source-runtime-admission-execution", "status": "pass" if runtime_admission_ready else "blocked", "reason": f"complete_source_runtime_admission_execution_ready={runtime_admission_ready}"},
    {"gate": "complete-source-review-return", "status": "pass" if review_return_ready else "blocked", "reason": f"review_return_ready={review_return_ready}"},
    {"gate": "generation-operator-handoff", "status": "pass" if operator_handoff_ready and execution_packet_ready else "blocked", "reason": f"operator_handoff={operator_handoff_ready}, execution_packet={execution_packet_ready}"},
    {"gate": "actual-generation-result-artifacts", "status": "pass" if generation_result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gate": "complete-source-generation-execution-admission", "status": "pass" if generation_execution_admission_ready else "blocked", "reason": f"generation_execution_admitted_rows={admitted_rows}/{len(packet_rows)}"},
    {"gate": "actual-model-generation", "status": "pass" if actual_model_generation_ready else "blocked", "reason": f"actual_model_generation_ready_rows={actual_ready_rows}/{len(packet_rows)}"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cs writes metadata and copied evidence only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cs Complete-Source Generation Execution Admission Gate Boundary

This artifact consumes v61ck, v61cw, v61cf, and v61bt to decide whether the
1000-row complete-source generation execution packet can be admitted after
runtime admission acceptance. It is an admission gate only; it does not run the
model and does not claim answer quality or latency.

Evidence emitted:

- complete_source_query_rows={len(packet_rows)}
- generation_execution_admission_rows={len(packet_rows)}
- generation_execution_admitted_rows={admitted_rows}
- generation_execution_blocked_rows={len(packet_rows) - admitted_rows}
- materialization_blocked_generation_rows={materialization_blocked_rows}
- page_hash_blocked_generation_rows={page_hash_blocked_rows}
- runtime_admission_blocked_generation_rows={runtime_admission_blocked_rows}
- review_return_blocked_generation_rows={review_return_blocked_rows}
- operator_handoff_blocked_generation_rows={operator_blocked_rows}
- generation_result_artifact_blocked_rows={generation_result_artifact_blocked_rows}
- runtime_admission_acceptance_rows={v61cw['runtime_admission_acceptance_rows']}
- runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}
- runtime_artifact_blocked_acceptance_rows={v61cw['runtime_artifact_blocked_acceptance_rows']}
- runtime_result_blocked_acceptance_rows={v61cw['runtime_result_blocked_acceptance_rows']}
- runtime_page_binding_blocked_acceptance_rows={v61cw['runtime_page_binding_blocked_acceptance_rows']}
- runtime_budget_blocked_acceptance_rows={v61cw['runtime_budget_blocked_acceptance_rows']}
- runtime_identity_blocked_acceptance_rows={v61cw['runtime_identity_blocked_acceptance_rows']}
- runtime_safety_blocked_acceptance_rows={v61cw['runtime_safety_blocked_acceptance_rows']}
- generation_execution_admission_ready={generation_execution_admission_ready}
- actual_model_generation_ready={actual_model_generation_ready}
- checkpoint_payload_bytes_downloaded_by_v61cs=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source generation execution admission gate over the
real-manifest/operator/runtime-admission evidence. Blocked wording: actual
Mixtral generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61CS_COMPLETE_SOURCE_GENERATION_EXECUTION_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cs_complete_source_generation_execution_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cs_complete_source_generation_execution_admission_gate_ready": 1,
    "complete_source_query_rows": len(packet_rows),
    "generation_execution_admitted_rows": admitted_rows,
    "generation_execution_admission_ready": generation_execution_admission_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "source_v61ck_summary_sha256": sha256(v61ck_summary_path),
    "source_v61cr_summary_sha256": sha256(v61cr_summary_path),
    "source_v61cw_summary_sha256": sha256(v61cw_summary_path),
    "source_v61cf_summary_sha256": sha256(v61cf_summary_path),
    "source_v61bt_summary_sha256": sha256(v61bt_summary_path),
    "checkpoint_payload_bytes_downloaded_by_v61cs": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61cs_complete_source_generation_execution_admission_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cs_complete_source_generation_execution_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
