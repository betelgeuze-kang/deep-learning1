#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fq_post_fp_v1_comparison_readiness_refresh"
RUN_ID="${V61FQ_RUN_ID:-refresh_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fq_post_fp_v1_comparison_readiness_refresh_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null
V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V61DH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dh_post_full_shard_claim_audit_gate.sh" >/dev/null
V61FP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger.sh" >/dev/null

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
prefix = "v61fq_post_fp_v1_comparison_readiness_refresh"
refresh_dir = run_dir / "post_fp_v1_comparison_readiness_refresh"
refresh_dir.mkdir(parents=True, exist_ok=True)


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def ready(flag):
    return "ready" if flag else "blocked"


def pass_or_blocked(flag):
    return "pass" if flag else "blocked"


sources = {
    "v52y_summary": results / "v52y_f_optional_final_policy_summary.csv",
    "v52y_decision": results / "v52y_f_optional_final_policy_decision.csv",
    "v53t_summary": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53t_decision": results / "v53t_complete_source_audit_readiness_gate_decision.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_decision": results / "v53am_complete_source_return_acceptance_replay_decision.csv",
    "v61dh_summary": results / "v61dh_post_full_shard_claim_audit_gate_summary.csv",
    "v61dh_decision": results / "v61dh_post_full_shard_claim_audit_gate_decision.csv",
    "v61fp_summary": results / "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_summary.csv",
    "v61fp_decision": results / "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fq source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

source_artifacts = {
    "v52y_f_optional_final_rows.csv": results / "v52y_f_optional_final_policy" / "policy_001" / "f_optional_final_rows.csv",
    "v52y_comparison_wording_rows.csv": results / "v52y_f_optional_final_policy" / "policy_001" / "comparison_wording_rows.csv",
    "v53t_requirement_rows.csv": results / "v53t_complete_source_audit_readiness_gate" / "gate_001" / "complete_source_audit_readiness_requirement_rows.csv",
    "v53am_replay_step_rows.csv": results / "v53am_complete_source_return_acceptance_replay" / "replay_001" / "return_acceptance_replay_step_rows.csv",
    "v61dh_claim_rows.csv": results / "v61dh_post_full_shard_claim_audit_gate" / "audit_001" / "post_full_shard_claim_audit_rows.csv",
    "v61fp_ledger_rows.csv": results / "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger" / "ledger_001" / "post_fo_full_shard_to_real_review_replay_closure_ledger_rows.csv",
}
for rel, path in source_artifacts.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fq source artifact: {path}")
    copy(path, f"source_artifacts/{rel}")

v52y = read_csv(sources["v52y_summary"])[0]
v53t = read_csv(sources["v53t_summary"])[0]
v53am = read_csv(sources["v53am_summary"])[0]
v61dh = read_csv(sources["v61dh_summary"])[0]
v61fp = read_csv(sources["v61fp_summary"])[0]

required_ready = {
    "v52y_f_optional_final_policy_ready": v52y,
    "v53t_complete_source_audit_readiness_gate_ready": v53t,
    "v53am_complete_source_return_acceptance_replay_ready": v53am,
    "v61dh_post_full_shard_claim_audit_gate_ready": v61dh,
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready": v61fp,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v61fq requires {key}=1")

v52_ready = as_int(v52y, "v52_ready")
f_optional_final_disposition = v52y.get("f_optional_final_disposition", "")
f_optional_final_disposition_ready = as_int(v52y, "f_optional_final_disposition_ready")
f_final_deferred_with_reason = as_int(v52y, "f_final_deferred_with_reason")
comparison_wording_status = v52y.get("comparison_30b_150b_wording_status", "")
required_30b_baseline_ready = as_int(v52y, "required_30b_baseline_ready")
required_70b_baseline_ready = as_int(v52y, "required_70b_baseline_ready")

machine_complete_source_surface_ready = as_int(v53t, "machine_complete_source_surface_ready")
complete_source_repo_count = as_int(v53t, "complete_source_repo_count")
complete_source_query_rows = as_int(v53t, "complete_source_query_rows")
core_answer_rows = as_int(v53t, "core_answer_rows")
review_packet_ready = as_int(v53t, "review_packet_ready")
expected_human_review_rows = as_int(v53t, "expected_human_review_rows")
accepted_human_review_rows = as_int(v53t, "accepted_human_review_rows")
expected_adjudication_rows = as_int(v53t, "expected_adjudication_rows")
accepted_adjudication_rows = as_int(v53t, "accepted_adjudication_rows")
v53_review_return_ready = as_int(v53t, "review_return_ready")
v53_ready = as_int(v53t, "v53_ready")

return_acceptance_replay_ready = as_int(v53am, "return_acceptance_replay_ready")
return_bundle_preflight_pass = as_int(v53am, "return_bundle_preflight_pass")
return_acceptance_replay_closed = as_int(v53am, "return_acceptance_replay_closed")
accepted_dispatch_receipt_rows = as_int(v53am, "accepted_dispatch_receipt_rows")
accepted_chunk_return_artifact_rows = as_int(v53am, "accepted_chunk_return_artifact_rows")
accepted_aggregate_review_return_artifact_rows = as_int(v53am, "accepted_aggregate_review_return_artifact_rows")

claim_audit_ready = as_int(v61dh, "claim_audit_ready")
claim_rows = as_int(v61dh, "claim_rows")
allowed_claim_rows = as_int(v61dh, "allowed_claim_rows")
blocked_claim_rows = as_int(v61dh, "blocked_claim_rows")
claim_invariant_pass_rows = as_int(v61dh, "claim_invariant_pass_rows")
claim_invariant_rows = as_int(v61dh, "claim_invariant_rows")

full_shard_prerequisites_closed = as_int(v61fp, "full_shard_prerequisites_closed")
full_checkpoint_materialization_ready = as_int(v61fp, "full_checkpoint_materialization_ready")
full_safetensors_page_hash_binding_ready = as_int(v61fp, "full_safetensors_page_hash_binding_ready")
post_full_shard_runtime_evidence_ready = as_int(v61fp, "post_full_shard_runtime_evidence_ready")
runtime_execution_admitted_rows = as_int(v61fp, "runtime_execution_admitted_rows")
runtime_admission_accepted_rows = as_int(v61fp, "runtime_admission_accepted_rows")
replay_entrypoint_ready = as_int(v61fp, "replay_entrypoint_ready")
external_review_return_ready = as_int(v61fp, "external_review_return_ready")
real_return_replay_admission_ready = as_int(v61fp, "real_return_replay_admission_ready")
row_acceptance_ready = as_int(v61fp, "row_acceptance_ready")
generation_execution_admission_rows = as_int(v61fp, "generation_execution_admission_rows")
generation_execution_admitted_rows = as_int(v61fp, "generation_execution_admitted_rows")
expected_generation_result_artifacts = as_int(v61fp, "expected_generation_result_artifacts")
accepted_generation_result_artifacts = as_int(v61fp, "accepted_generation_result_artifacts")
actual_model_generation_ready = 0

comparison_wording_allowed_with_disclosure = int(comparison_wording_status == "allowed-with-disclosure")
complete_source_review_rows_ready = int(
    accepted_human_review_rows == expected_human_review_rows
    and expected_human_review_rows > 0
    and accepted_adjudication_rows == expected_adjudication_rows
    and expected_adjudication_rows > 0
)
generation_execution_ready = int(
    generation_execution_admitted_rows == generation_execution_admission_rows
    and generation_execution_admission_rows > 0
)
generation_result_acceptance_ready = int(
    accepted_generation_result_artifacts == expected_generation_result_artifacts
    and expected_generation_result_artifacts > 0
)
v1_0_comparison_ready = int(
    v52_ready
    and machine_complete_source_surface_ready
    and complete_source_review_rows_ready
    and full_shard_prerequisites_closed
    and generation_execution_ready
    and generation_result_acceptance_ready
    and actual_model_generation_ready
)
comparison_wording_claim_ready = int(v52_ready and comparison_wording_allowed_with_disclosure)
release_claim_ready = 0

readiness_rows = [
    {"row_id": "01-v52-ready", "status": ready(v52_ready), "ready": str(v52_ready), "evidence": f"v52_ready={v52_ready}", "blocked_reason": ""},
    {"row_id": "02-f-optional-final-disposition", "status": ready(f_optional_final_disposition_ready), "ready": str(f_optional_final_disposition_ready), "evidence": f"f_optional_final_disposition={f_optional_final_disposition}", "blocked_reason": ""},
    {"row_id": "03-f-deferred-with-reason", "status": ready(f_final_deferred_with_reason), "ready": str(f_final_deferred_with_reason), "evidence": f"f_final_deferred_with_reason={f_final_deferred_with_reason}", "blocked_reason": ""},
    {"row_id": "04-required-30b-baseline", "status": ready(required_30b_baseline_ready), "ready": str(required_30b_baseline_ready), "evidence": f"required_30b_baseline_ready={required_30b_baseline_ready}", "blocked_reason": ""},
    {"row_id": "05-required-70b-baseline", "status": ready(required_70b_baseline_ready), "ready": str(required_70b_baseline_ready), "evidence": f"required_70b_baseline_ready={required_70b_baseline_ready}", "blocked_reason": ""},
    {"row_id": "06-30b-150b-wording", "status": ready(comparison_wording_claim_ready), "ready": str(comparison_wording_claim_ready), "evidence": f"comparison_30b_150b_wording_status={comparison_wording_status}; v52_ready={v52_ready}", "blocked_reason": "requires required D/E PM/release readiness"},
    {"row_id": "07-complete-source-surface", "status": ready(machine_complete_source_surface_ready), "ready": str(machine_complete_source_surface_ready), "evidence": f"repos={complete_source_repo_count}; queries={complete_source_query_rows}; core_answers={core_answer_rows}", "blocked_reason": ""},
    {"row_id": "08-review-packet-ready", "status": ready(review_packet_ready), "ready": str(review_packet_ready), "evidence": f"review_packet_ready={review_packet_ready}", "blocked_reason": ""},
    {"row_id": "09-human-review-return", "status": ready(complete_source_review_rows_ready), "ready": str(complete_source_review_rows_ready), "evidence": f"human={accepted_human_review_rows}/{expected_human_review_rows}; adjudication={accepted_adjudication_rows}/{expected_adjudication_rows}", "blocked_reason": "requires real human review and adjudication rows"},
    {"row_id": "10-return-acceptance-replay", "status": ready(return_acceptance_replay_closed), "ready": str(return_acceptance_replay_closed), "evidence": f"return_bundle_preflight_pass={return_bundle_preflight_pass}; accepted_dispatch_receipts={accepted_dispatch_receipt_rows}; accepted_chunks={accepted_chunk_return_artifact_rows}; accepted_aggregate={accepted_aggregate_review_return_artifact_rows}", "blocked_reason": "requires accepted external return bundle"},
    {"row_id": "11-v53-ready", "status": ready(v53_ready), "ready": str(v53_ready), "evidence": f"v53_ready={v53_ready}; review_return_ready={v53_review_return_ready}", "blocked_reason": "complete-source review return is not accepted"},
    {"row_id": "12-full-shard-prerequisites", "status": ready(full_shard_prerequisites_closed), "ready": str(full_shard_prerequisites_closed), "evidence": f"full_checkpoint={full_checkpoint_materialization_ready}; full_page_hash={full_safetensors_page_hash_binding_ready}; runtime={post_full_shard_runtime_evidence_ready}", "blocked_reason": ""},
    {"row_id": "13-runtime-admission", "status": ready(runtime_admission_accepted_rows == 1000), "ready": str(int(runtime_admission_accepted_rows == 1000)), "evidence": f"runtime_seed={runtime_execution_admitted_rows}; runtime_admission={runtime_admission_accepted_rows}", "blocked_reason": ""},
    {"row_id": "14-replay-entrypoint", "status": ready(replay_entrypoint_ready), "ready": str(replay_entrypoint_ready), "evidence": f"replay_entrypoint_ready={replay_entrypoint_ready}", "blocked_reason": ""},
    {"row_id": "15-real-review-return", "status": ready(external_review_return_ready), "ready": str(external_review_return_ready), "evidence": f"external_review_return_ready={external_review_return_ready}", "blocked_reason": "requires real external review return provenance"},
    {"row_id": "16-real-return-replay", "status": ready(real_return_replay_admission_ready and row_acceptance_ready), "ready": str(int(real_return_replay_admission_ready and row_acceptance_ready)), "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}; row_acceptance_ready={row_acceptance_ready}", "blocked_reason": "requires accepted real return replay rows"},
    {"row_id": "17-generation-execution", "status": ready(generation_execution_ready), "ready": str(generation_execution_ready), "evidence": f"generation_execution_admitted_rows={generation_execution_admitted_rows}/{generation_execution_admission_rows}", "blocked_reason": "requires accepted review return before generation execution"},
    {"row_id": "18-generation-result-acceptance", "status": ready(generation_result_acceptance_ready), "ready": str(generation_result_acceptance_ready), "evidence": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}", "blocked_reason": "requires real generation result artifacts"},
    {"row_id": "19-actual-generation", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0", "blocked_reason": "actual model generation remains unproven"},
    {"row_id": "20-v1-comparison-ready", "status": ready(v1_0_comparison_ready), "ready": str(v1_0_comparison_ready), "evidence": f"v1_0_comparison_ready={v1_0_comparison_ready}", "blocked_reason": "requires v53 review return and v61 generation evidence"},
    {"row_id": "21-release-claims", "status": "blocked", "ready": "0", "evidence": "near_frontier_claim_ready=0; production_latency_claim_ready=0; real_release_package_ready=0", "blocked_reason": "requires external review, latency, quality, and release package evidence"},
]
write_csv(run_dir / "post_fp_v1_comparison_readiness_rows.csv", list(readiness_rows[0].keys()), readiness_rows)

claim_rows_refresh = [
    {"claim_id": "01-f-optional", "claim_status": "allowed", "wording_status": "allowed-with-disclosure", "evidence": f"F optional disposition is {f_optional_final_disposition}", "boundary": "F is deferred with reason, not supplied 100B+ evidence"},
    {
        "claim_id": "02-30b-150b-comparison-wording",
        "claim_status": "allowed" if comparison_wording_claim_ready else "blocked",
        "wording_status": comparison_wording_status,
        "evidence": f"v52_ready={v52_ready}; required_30b_baseline_ready={required_30b_baseline_ready}; required_70b_baseline_ready={required_70b_baseline_ready}",
        "boundary": "wording requires D/E PM/release readiness; absorbed artifacts alone are insufficient",
    },
    {"claim_id": "03-complete-source-machine-surface", "claim_status": "allowed", "wording_status": "machine-surface-ready", "evidence": f"repos={complete_source_repo_count}; queries={complete_source_query_rows}; answer_rows={core_answer_rows}", "boundary": "not human-reviewed"},
    {"claim_id": "04-full-shard-runtime-evidence", "claim_status": "allowed", "wording_status": "post-full-shard-evidence-ready", "evidence": f"full_shard_prerequisites_closed={full_shard_prerequisites_closed}; runtime_admission={runtime_admission_accepted_rows}", "boundary": "not actual generation"},
    {"claim_id": "05-v1-comparison", "claim_status": "blocked", "wording_status": "not-ready", "evidence": f"v1_0_comparison_ready={v1_0_comparison_ready}", "boundary": "requires accepted review and generation evidence"},
    {"claim_id": "06-near-frontier", "claim_status": "blocked", "wording_status": "not-ready", "evidence": "near_frontier_claim_ready=0", "boundary": "quality equivalence not externally reviewed"},
    {"claim_id": "07-production-latency", "claim_status": "blocked", "wording_status": "not-ready", "evidence": "production_latency_claim_ready=0", "boundary": "production latency evidence missing"},
    {"claim_id": "08-release-package", "claim_status": "blocked", "wording_status": "not-ready", "evidence": "real_release_package_ready=0", "boundary": "release review/package missing"},
]
write_csv(run_dir / "post_fp_v1_comparison_claim_boundary_rows.csv", list(claim_rows_refresh[0].keys()), claim_rows_refresh)

next_action_rows = [
    {"action_id": "01-send-v53-return-bundle", "ready_to_run_now": "1", "command": "./experiments/test_v53ah_complete_source_external_review_send_bundle.sh", "purpose": "send complete-source review/return bundle"},
    {"action_id": "02-preflight-return-bundle", "ready_to_run_now": "1", "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh", "purpose": "check returned 81-artifact bundle when available"},
    {"action_id": "03-replay-v53-return-acceptance", "ready_to_run_now": str(return_bundle_preflight_pass), "command": "V53AM_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53am_complete_source_return_acceptance_replay.sh", "purpose": "requires returned bundle preflight"},
    {"action_id": "04-run-v61-real-review-return-entrypoint", "ready_to_run_now": str(external_review_return_ready), "command": "V61FO_REVIEW_RETURN_DIR=/path/to/real-review-return V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return ./results/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/entrypoint_001/real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh", "purpose": "requires real v61 review-return root"},
    {"action_id": "05-run-generation-result-acceptance", "ready_to_run_now": str(generation_execution_ready), "command": "run v61bt/v61de/v61cu after generation execution", "purpose": "requires admitted generation execution"},
    {"action_id": "06-refresh-v1-comparison", "ready_to_run_now": str(v1_0_comparison_ready), "command": "./experiments/run_v61fq_post_fp_v1_comparison_readiness_refresh.sh", "purpose": "refresh only after review/generation evidence closes"},
]
write_csv(run_dir / "post_fp_v1_comparison_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

metric_rows = [{
    "v52_ready": v52_ready,
    "f_optional_final_disposition": f_optional_final_disposition,
    "f_final_deferred_with_reason": f_final_deferred_with_reason,
    "comparison_30b_150b_wording_status": comparison_wording_status,
    "comparison_wording_claim_ready": comparison_wording_claim_ready,
    "v53_machine_complete_source_surface_ready": machine_complete_source_surface_ready,
    "complete_source_repo_count": complete_source_repo_count,
    "complete_source_query_rows": complete_source_query_rows,
    "core_answer_rows": core_answer_rows,
    "expected_human_review_rows": expected_human_review_rows,
    "accepted_human_review_rows": accepted_human_review_rows,
    "expected_adjudication_rows": expected_adjudication_rows,
    "accepted_adjudication_rows": accepted_adjudication_rows,
    "complete_source_review_rows_ready": complete_source_review_rows_ready,
    "return_acceptance_replay_ready": return_acceptance_replay_ready,
    "return_acceptance_replay_closed": return_acceptance_replay_closed,
    "v53_ready": v53_ready,
    "claim_audit_ready": claim_audit_ready,
    "claim_rows": claim_rows,
    "allowed_claim_rows": allowed_claim_rows,
    "blocked_claim_rows": blocked_claim_rows,
    "claim_invariant_pass_rows": claim_invariant_pass_rows,
    "claim_invariant_rows": claim_invariant_rows,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "full_checkpoint_materialization_ready": full_checkpoint_materialization_ready,
    "full_safetensors_page_hash_binding_ready": full_safetensors_page_hash_binding_ready,
    "post_full_shard_runtime_evidence_ready": post_full_shard_runtime_evidence_ready,
    "runtime_execution_admitted_rows": runtime_execution_admitted_rows,
    "runtime_admission_accepted_rows": runtime_admission_accepted_rows,
    "replay_entrypoint_ready": replay_entrypoint_ready,
    "external_review_return_ready": external_review_return_ready,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "row_acceptance_ready": row_acceptance_ready,
    "generation_execution_admission_rows": generation_execution_admission_rows,
    "generation_execution_admitted_rows": generation_execution_admitted_rows,
    "expected_generation_result_artifacts": expected_generation_result_artifacts,
    "accepted_generation_result_artifacts": accepted_generation_result_artifacts,
    "actual_model_generation_ready": actual_model_generation_ready,
    "v1_0_comparison_ready": v1_0_comparison_ready,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": release_claim_ready,
    "checkpoint_payload_bytes_downloaded_by_v61fq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}]
write_csv(run_dir / "post_fp_v1_comparison_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

shutil.copy2(run_dir / "post_fp_v1_comparison_readiness_rows.csv", refresh_dir / "V1_COMPARISON_READINESS_ROWS.csv")
shutil.copy2(run_dir / "post_fp_v1_comparison_claim_boundary_rows.csv", refresh_dir / "V1_COMPARISON_CLAIM_BOUNDARY_ROWS.csv")
shutil.copy2(run_dir / "post_fp_v1_comparison_next_action_rows.csv", refresh_dir / "V1_COMPARISON_NEXT_ACTION_ROWS.csv")
refresh_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52_ready": v52_ready,
    "comparison_30b_150b_wording_status": comparison_wording_status,
    "v53_machine_complete_source_surface_ready": machine_complete_source_surface_ready,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "v1_0_comparison_ready": v1_0_comparison_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(refresh_dir / "V1_COMPARISON_REFRESH_MANIFEST.json").write_text(json.dumps(refresh_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(refresh_dir / "V1_COMPARISON_REFRESH.md").write_text(
    "\n".join(
        [
            "# v61fq post-v61fp v1.0 comparison readiness refresh",
            "",
            f"- v52_ready={v52_ready}",
            f"- f_optional_final_disposition={f_optional_final_disposition}",
            f"- comparison_30b_150b_wording_status={comparison_wording_status}",
            f"- v53_machine_complete_source_surface_ready={machine_complete_source_surface_ready}",
            f"- complete_source_repo_count={complete_source_repo_count}",
            f"- complete_source_query_rows={complete_source_query_rows}",
            f"- accepted_human_review_rows={accepted_human_review_rows}/{expected_human_review_rows}",
            f"- accepted_adjudication_rows={accepted_adjudication_rows}/{expected_adjudication_rows}",
            f"- full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
            f"- runtime_admission_accepted_rows={runtime_admission_accepted_rows}",
            f"- generation_execution_admitted_rows={generation_execution_admitted_rows}/{generation_execution_admission_rows}",
            f"- accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}",
            f"- v1_0_comparison_ready={v1_0_comparison_ready}",
            "- actual_model_generation_ready=0",
            "",
            "The 30B-150B comparison wording is blocked until D/E PM/release baseline readiness is accepted. The v1.0 comparison itself remains blocked until real complete-source review/adjudication return and real generation result acceptance close.",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script = refresh_dir / "VERIFY_V1_COMPARISON_REFRESH.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -s \"$DIR/V1_COMPARISON_REFRESH_MANIFEST.json\"",
            "test -s \"$DIR/V1_COMPARISON_READINESS_ROWS.csv\"",
            "test -s \"$DIR/V1_COMPARISON_CLAIM_BOUNDARY_ROWS.csv\"",
            "test -s \"$DIR/V1_COMPARISON_NEXT_ACTION_ROWS.csv\"",
            "test -s \"$DIR/V1_COMPARISON_REFRESH.md\"",
            "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
            "  echo 'payload-like file referenced in v1 comparison refresh package' >&2",
            "  exit 1",
            "fi",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

package_files = sorted(path for path in refresh_dir.rglob("*") if path.is_file())
file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "post_fp_v1_comparison_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": 1,
    "v52y_f_optional_final_policy_ready": 1,
    "v53t_complete_source_audit_readiness_gate_ready": 1,
    "v53am_complete_source_return_acceptance_replay_ready": 1,
    "v61dh_post_full_shard_claim_audit_gate_ready": 1,
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready": 1,
    **metric_rows[0],
    "readiness_rows": len(readiness_rows),
    "ready_readiness_rows": sum(row["status"] == "ready" for row in readiness_rows),
    "blocked_readiness_rows": sum(row["status"] == "blocked" for row in readiness_rows),
    "comparison_claim_rows": len(claim_rows_refresh),
    "allowed_comparison_claim_rows": sum(row["claim_status"] == "allowed" for row in claim_rows_refresh),
    "blocked_comparison_claim_rows": sum(row["claim_status"] == "blocked" for row in claim_rows_refresh),
    "next_action_rows": len(next_action_rows),
    "ready_next_action_rows": sum(row["ready_to_run_now"] == "1" for row in next_action_rows),
    "blocked_next_action_rows": sum(row["ready_to_run_now"] == "0" for row in next_action_rows),
    "refresh_package_file_rows": len(file_rows),
    "metadata_only_refresh_package_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_refresh_package_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": len(sources),
    "source_artifact_file_rows": len(source_artifacts),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v52-ready", "status": pass_or_blocked(v52_ready), "actual_value": str(v52_ready), "required_value": "1", "reason": "F optional final disposition is explicit"},
    {"gate": "30b-150b-wording", "status": pass_or_blocked(comparison_wording_claim_ready), "actual_value": comparison_wording_status, "required_value": "allowed-with-disclosure plus v52_ready=1", "reason": "wording allowed only after D/E readiness and disclosure"},
    {"gate": "v53-machine-complete-source-surface", "status": pass_or_blocked(machine_complete_source_surface_ready), "actual_value": str(machine_complete_source_surface_ready), "required_value": "1", "reason": "10 repos, 1000 queries, 7000 answer rows ready"},
    {"gate": "complete-source-review-return", "status": pass_or_blocked(complete_source_review_rows_ready), "actual_value": f"{accepted_human_review_rows}/{expected_human_review_rows};{accepted_adjudication_rows}/{expected_adjudication_rows}", "required_value": "7000/7000;1000/1000", "reason": "real review/adjudication rows missing"},
    {"gate": "full-shard-prerequisites", "status": pass_or_blocked(full_shard_prerequisites_closed), "actual_value": str(full_shard_prerequisites_closed), "required_value": "1", "reason": "v61fp closes full-shard/page-hash/runtime prerequisites"},
    {"gate": "real-review-return", "status": pass_or_blocked(external_review_return_ready), "actual_value": str(external_review_return_ready), "required_value": "1", "reason": "real external review return missing"},
    {"gate": "generation-execution", "status": pass_or_blocked(generation_execution_ready), "actual_value": f"{generation_execution_admitted_rows}/{generation_execution_admission_rows}", "required_value": "1000/1000", "reason": "generation execution not admitted"},
    {"gate": "generation-result-acceptance", "status": pass_or_blocked(generation_result_acceptance_ready), "actual_value": f"{accepted_generation_result_artifacts}/{expected_generation_result_artifacts}", "required_value": "5/5", "reason": "generation result artifacts missing"},
    {"gate": "v1-comparison", "status": pass_or_blocked(v1_0_comparison_ready), "actual_value": str(v1_0_comparison_ready), "required_value": "1", "reason": "review and generation evidence remain blocked"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual model generation remains unproven"},
    {"gate": "release-claims", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "production, near-frontier, and release evidence missing"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only refresh"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FQ_POST_FP_V1_COMPARISON_READINESS_REFRESH_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# V61FQ Post-v61fp v1.0 Comparison Readiness Refresh Boundary",
            "",
            "- v61fq_post_fp_v1_comparison_readiness_refresh_ready=1",
            f"- v52_ready={v52_ready}",
            f"- f_optional_final_disposition={f_optional_final_disposition}",
            f"- f_final_deferred_with_reason={f_final_deferred_with_reason}",
            f"- comparison_30b_150b_wording_status={comparison_wording_status}",
            f"- comparison_wording_claim_ready={comparison_wording_claim_ready}",
            f"- v53_machine_complete_source_surface_ready={machine_complete_source_surface_ready}",
            f"- complete_source_repo_count={complete_source_repo_count}",
            f"- complete_source_query_rows={complete_source_query_rows}",
            f"- core_answer_rows={core_answer_rows}",
            f"- accepted_human_review_rows={accepted_human_review_rows}/{expected_human_review_rows}",
            f"- accepted_adjudication_rows={accepted_adjudication_rows}/{expected_adjudication_rows}",
            f"- full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
            f"- runtime_admission_accepted_rows={runtime_admission_accepted_rows}",
            f"- generation_execution_admitted_rows={generation_execution_admitted_rows}/{generation_execution_admission_rows}",
            f"- accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}",
            f"- v1_0_comparison_ready={v1_0_comparison_ready}",
            "- actual_model_generation_ready=0",
            f"- readiness_rows={len(readiness_rows)}",
            f"- ready_readiness_rows={summary['ready_readiness_rows']}",
            f"- blocked_readiness_rows={summary['blocked_readiness_rows']}",
            f"- comparison_claim_rows={len(claim_rows_refresh)}",
            f"- allowed_comparison_claim_rows={summary['allowed_comparison_claim_rows']}",
            f"- blocked_comparison_claim_rows={summary['blocked_comparison_claim_rows']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Blocked wording: 30B-150B-class comparison wording is allowed only with F optional disclosure. v1.0 comparison, near-frontier, production latency, release, and actual generation claims remain blocked until real review/adjudication and generation-result evidence are accepted.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **summary,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "bytes", "sha256"], sha_rows)

print(f"v61fq_post_fp_v1_comparison_readiness_refresh_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
