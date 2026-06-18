#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ft_active_goal_completion_audit"
RUN_ID="${V61FT_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ft_active_goal_completion_audit_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null
V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
V61FQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fq_post_fp_v1_comparison_readiness_refresh.sh" >/dev/null
V61FS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fs_post_fr_ready_command_execution_receipt.sh" >/dev/null

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
prefix = "v61ft_active_goal_completion_audit"
audit_dir = run_dir / "active_goal_completion_audit"
audit_dir.mkdir(parents=True, exist_ok=True)


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


def status(flag):
    return "pass" if flag else "blocked"


sources = {
    "v52y_summary": results / "v52y_f_optional_final_policy_summary.csv",
    "v52y_decision": results / "v52y_f_optional_final_policy_decision.csv",
    "v53t_summary": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53t_decision": results / "v53t_complete_source_audit_readiness_gate_decision.csv",
    "v61dg_summary": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "v61dg_decision": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv",
    "v61fq_summary": results / "v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "v61fq_decision": results / "v61fq_post_fp_v1_comparison_readiness_refresh_decision.csv",
    "v61fs_summary": results / "v61fs_post_fr_ready_command_execution_receipt_summary.csv",
    "v61fs_decision": results / "v61fs_post_fr_ready_command_execution_receipt_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ft source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

source_artifacts = {
    "v52y_f_optional_final_rows.csv": results / "v52y_f_optional_final_policy" / "policy_001" / "f_optional_final_rows.csv",
    "v52y_v52_ready_condition_rows.csv": results / "v52y_f_optional_final_policy" / "policy_001" / "v52_ready_condition_rows.csv",
    "v53t_requirement_rows.csv": results / "v53t_complete_source_audit_readiness_gate" / "gate_001" / "complete_source_audit_readiness_requirement_rows.csv",
    "v61dg_runtime_evidence_rows.csv": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate" / "gate_001" / "post_full_shard_runtime_evidence_rows.csv",
    "v61fq_readiness_rows.csv": results / "v61fq_post_fp_v1_comparison_readiness_refresh" / "refresh_001" / "post_fp_v1_comparison_readiness_rows.csv",
    "v61fs_execution_rows.csv": results / "v61fs_post_fr_ready_command_execution_receipt" / "receipt_001" / "post_fr_ready_command_execution_rows.csv",
}
for rel, path in source_artifacts.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ft source artifact: {path}")
    copy(path, f"source_artifacts/{rel}")

v52y = read_csv(sources["v52y_summary"])[0]
v53t = read_csv(sources["v53t_summary"])[0]
v61dg = read_csv(sources["v61dg_summary"])[0]
v61fq = read_csv(sources["v61fq_summary"])[0]
v61fs = read_csv(sources["v61fs_summary"])[0]

required_ready = {
    "v52y_f_optional_final_policy_ready": v52y,
    "v53t_complete_source_audit_readiness_gate_ready": v53t,
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": v61dg,
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": v61fq,
    "v61fs_post_fr_ready_command_execution_receipt_ready": v61fs,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v61ft requires {key}=1")

v52_ready = as_int(v52y, "v52_ready")
f_optional_final_disposition = v52y.get("f_optional_final_disposition", "")
f_optional_final_disposition_ready = as_int(v52y, "f_optional_final_disposition_ready")
comparison_wording_claim_ready = as_int(v61fq, "comparison_wording_claim_ready")
comparison_30b_150b_wording_status = v52y.get("comparison_30b_150b_wording_status", "")

complete_source_repo_count = as_int(v53t, "complete_source_repo_count")
complete_source_query_rows = as_int(v53t, "complete_source_query_rows")
core_answer_rows = as_int(v53t, "core_answer_rows")
review_packet_ready = as_int(v53t, "review_packet_ready")
machine_complete_source_surface_ready = as_int(v53t, "machine_complete_source_surface_ready")
expected_human_review_rows = as_int(v53t, "expected_human_review_rows")
accepted_human_review_rows = as_int(v53t, "accepted_human_review_rows")
expected_adjudication_rows = as_int(v53t, "expected_adjudication_rows")
accepted_adjudication_rows = as_int(v53t, "accepted_adjudication_rows")
v53_ready = as_int(v53t, "v53_ready")

real_manifest_fixture_replacement_ready = as_int(v61dg, "real_manifest_fixture_replacement_ready")
gpu_page_dequant_matmul_measurement_ready = as_int(v61dg, "gpu_page_dequant_matmul_measurement_ready")
kv_cache_policy_ready = as_int(v61dg, "kv_cache_policy_ready")
v61j_source_bound_qa_command_pass = as_int(v61dg, "v61j_source_bound_qa_command_pass")
full_checkpoint_materialization_ready = as_int(v61dg, "full_checkpoint_materialization_ready")
full_safetensors_page_hash_binding_ready = as_int(v61dg, "full_safetensors_page_hash_binding_ready")
runtime_admission_accepted_rows = as_int(v61dg, "runtime_admission_accepted_rows")
post_full_shard_runtime_evidence_ready = as_int(v61dg, "post_full_shard_runtime_evidence_ready")
actual_model_generation_ready = 0
v1_0_comparison_ready = as_int(v61fq, "v1_0_comparison_ready")
successful_ready_command_rows = as_int(v61fs, "successful_ready_command_rows")
ready_command_rows = as_int(v61fs, "ready_command_rows")
present_external_input_rows = as_int(v61fs, "present_external_input_rows")
required_external_input_rows = as_int(v61fs, "required_external_input_rows")

requirement_rows = [
    {"requirement_id": "01-v52-f-optional-final-disposition", "objective_section": "v52", "status": status(f_optional_final_disposition_ready), "evidence": f"f_optional_final_disposition={f_optional_final_disposition}", "remaining_work": ""},
    {"requirement_id": "02-v52-ready-condition", "objective_section": "v52", "status": status(v52_ready), "evidence": f"v52_ready={v52_ready}", "remaining_work": ""},
    {"requirement_id": "03-30b-150b-wording-disclosure", "objective_section": "v52", "status": status(comparison_wording_claim_ready), "evidence": f"comparison_30b_150b_wording_status={comparison_30b_150b_wording_status}", "remaining_work": ""},
    {"requirement_id": "04-complete-source-repo-count", "objective_section": "v53", "status": status(complete_source_repo_count >= 10), "evidence": f"complete_source_repo_count={complete_source_repo_count}", "remaining_work": ""},
    {"requirement_id": "05-complete-source-query-count", "objective_section": "v53", "status": status(complete_source_query_rows >= 1000), "evidence": f"complete_source_query_rows={complete_source_query_rows}", "remaining_work": ""},
    {"requirement_id": "06-core-a-b-c-d-e-g-h-answer-rows", "objective_section": "v53", "status": status(core_answer_rows >= 7000), "evidence": f"core_answer_rows={core_answer_rows}", "remaining_work": ""},
    {"requirement_id": "07-review-packet-ready", "objective_section": "v53", "status": status(review_packet_ready), "evidence": f"review_packet_ready={review_packet_ready}", "remaining_work": ""},
    {"requirement_id": "08-human-review-return", "objective_section": "v53", "status": status(accepted_human_review_rows == expected_human_review_rows and expected_human_review_rows > 0), "evidence": f"accepted_human_review_rows={accepted_human_review_rows}/{expected_human_review_rows}", "remaining_work": "real human/source review rows"},
    {"requirement_id": "09-adjudication-return", "objective_section": "v53", "status": status(accepted_adjudication_rows == expected_adjudication_rows and expected_adjudication_rows > 0), "evidence": f"accepted_adjudication_rows={accepted_adjudication_rows}/{expected_adjudication_rows}", "remaining_work": "real adjudication rows"},
    {"requirement_id": "10-v53-ready", "objective_section": "v53", "status": status(v53_ready), "evidence": f"v53_ready={v53_ready}", "remaining_work": "accepted complete-source review return"},
    {"requirement_id": "11-real-model-page-manifest", "objective_section": "v61", "status": status(real_manifest_fixture_replacement_ready), "evidence": f"real_manifest_fixture_replacement_ready={real_manifest_fixture_replacement_ready}", "remaining_work": ""},
    {"requirement_id": "12-gpu-rocm-page-dequant-matmul", "objective_section": "v61", "status": status(gpu_page_dequant_matmul_measurement_ready), "evidence": f"gpu_page_dequant_matmul_measurement_ready={gpu_page_dequant_matmul_measurement_ready}; avg_ms={v61dg.get('gpu_kernel_avg_ms')}", "remaining_work": ""},
    {"requirement_id": "13-kv-cache-policy", "objective_section": "v61", "status": status(kv_cache_policy_ready), "evidence": f"kv_cache_policy_ready={kv_cache_policy_ready}", "remaining_work": ""},
    {"requirement_id": "14-v61j-source-bound-qa", "objective_section": "v61", "status": status(v61j_source_bound_qa_command_pass), "evidence": f"v61j_source_bound_qa_command_pass={v61j_source_bound_qa_command_pass}", "remaining_work": ""},
    {"requirement_id": "15-full-shard-page-hash-runtime", "objective_section": "v61", "status": status(post_full_shard_runtime_evidence_ready and full_checkpoint_materialization_ready and full_safetensors_page_hash_binding_ready), "evidence": f"full_checkpoint={full_checkpoint_materialization_ready}; full_page_hash={full_safetensors_page_hash_binding_ready}; runtime_admission={runtime_admission_accepted_rows}", "remaining_work": ""},
    {"requirement_id": "16-ready-command-receipts", "objective_section": "v61", "status": status(ready_command_rows == successful_ready_command_rows and ready_command_rows > 0), "evidence": f"successful_ready_command_rows={successful_ready_command_rows}/{ready_command_rows}", "remaining_work": ""},
    {"requirement_id": "17-external-return-inputs", "objective_section": "v53-v61", "status": status(present_external_input_rows == required_external_input_rows and required_external_input_rows > 0), "evidence": f"present_external_input_rows={present_external_input_rows}/{required_external_input_rows}", "remaining_work": "real returned evidence roots"},
    {"requirement_id": "18-actual-model-generation", "objective_section": "v61", "status": status(actual_model_generation_ready), "evidence": "actual_model_generation_ready=0", "remaining_work": "admitted generation execution and accepted generation-result artifacts"},
    {"requirement_id": "19-v1-comparison-ready", "objective_section": "v1.0", "status": status(v1_0_comparison_ready), "evidence": f"v1_0_comparison_ready={v1_0_comparison_ready}", "remaining_work": "accepted review/adjudication and generation evidence"},
    {"requirement_id": "20-near-frontier-production-release", "objective_section": "release", "status": "blocked", "evidence": "near_frontier_claim_ready=0; production_latency_claim_ready=0; real_release_package_ready=0", "remaining_work": "external quality, latency, and release review evidence"},
]
write_csv(run_dir / "active_goal_completion_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

section_rows = [
    {"section_id": "01-v52-f-optional-and-v52-ready", "status": "pass" if all(row["status"] == "pass" for row in requirement_rows[:3]) else "blocked", "evidence": "F optional final disposition is explicit; D/E PM/release readiness is required for v52_ready", "remaining_work": "accepted 30B and 70B PM/release baseline evidence"},
    {"section_id": "02-v53-complete-source-audit", "status": "blocked", "evidence": f"machine_surface={machine_complete_source_surface_ready}; accepted_human_review={accepted_human_review_rows}/{expected_human_review_rows}; accepted_adjudication={accepted_adjudication_rows}/{expected_adjudication_rows}", "remaining_work": "real complete-source review/adjudication return"},
    {"section_id": "03-v61-real-model-evidence", "status": "blocked", "evidence": f"post_full_shard_runtime_evidence_ready={post_full_shard_runtime_evidence_ready}; actual_model_generation_ready=0", "remaining_work": "real review return, generation execution, and result acceptance"},
]
write_csv(run_dir / "active_goal_completion_section_rows.csv", list(section_rows[0].keys()), section_rows)

blocker_rows = [
    {
        "blocker_id": row["requirement_id"],
        "objective_section": row["objective_section"],
        "evidence": row["evidence"],
        "remaining_work": row["remaining_work"],
    }
    for row in requirement_rows
    if row["status"] == "blocked"
]
write_csv(run_dir / "active_goal_completion_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

next_action_rows = [
    {"action_id": "01-use-v61fs-receipts", "ready_to_run_now": "1", "command": "./experiments/test_v61fs_post_fr_ready_command_execution_receipt.sh", "purpose": "verify local-ready command receipts"},
    {"action_id": "02-send-v53-review-bundle", "ready_to_run_now": "1", "command": "bash results/v53ah_complete_source_external_review_send_bundle/bundle_001/send_bundle/VERIFY_SEND_BUNDLE.sh", "purpose": "verify send bundle before external review"},
    {"action_id": "03-intake-v53-return-bundle", "ready_to_run_now": "0", "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh", "purpose": "requires returned 81-artifact bundle"},
    {"action_id": "04-run-v61-real-review-return", "ready_to_run_now": "0", "command": "V61FO_REVIEW_RETURN_DIR=/path/to/real-review-return V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return results/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/entrypoint_001/real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh", "purpose": "requires real review-return root"},
    {"action_id": "05-refresh-completion-audit", "ready_to_run_now": "0", "command": "./experiments/run_v61ft_active_goal_completion_audit.sh", "purpose": "run after external evidence closes"},
]
write_csv(run_dir / "active_goal_completion_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

metric_rows = [{
    "v52_ready": v52_ready,
    "f_optional_final_disposition_ready": f_optional_final_disposition_ready,
    "f_optional_final_disposition": f_optional_final_disposition,
    "comparison_wording_claim_ready": comparison_wording_claim_ready,
    "v53_machine_complete_source_surface_ready": machine_complete_source_surface_ready,
    "complete_source_repo_count": complete_source_repo_count,
    "complete_source_query_rows": complete_source_query_rows,
    "core_answer_rows": core_answer_rows,
    "accepted_human_review_rows": accepted_human_review_rows,
    "expected_human_review_rows": expected_human_review_rows,
    "accepted_adjudication_rows": accepted_adjudication_rows,
    "expected_adjudication_rows": expected_adjudication_rows,
    "v53_ready": v53_ready,
    "real_manifest_fixture_replacement_ready": real_manifest_fixture_replacement_ready,
    "gpu_page_dequant_matmul_measurement_ready": gpu_page_dequant_matmul_measurement_ready,
    "kv_cache_policy_ready": kv_cache_policy_ready,
    "v61j_source_bound_qa_command_pass": v61j_source_bound_qa_command_pass,
    "full_checkpoint_materialization_ready": full_checkpoint_materialization_ready,
    "full_safetensors_page_hash_binding_ready": full_safetensors_page_hash_binding_ready,
    "runtime_admission_accepted_rows": runtime_admission_accepted_rows,
    "post_full_shard_runtime_evidence_ready": post_full_shard_runtime_evidence_ready,
    "successful_ready_command_rows": successful_ready_command_rows,
    "ready_command_rows": ready_command_rows,
    "present_external_input_rows": present_external_input_rows,
    "required_external_input_rows": required_external_input_rows,
    "actual_model_generation_ready": actual_model_generation_ready,
    "v1_0_comparison_ready": v1_0_comparison_ready,
    "active_goal_complete": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ft": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}]
write_csv(run_dir / "active_goal_completion_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

shutil.copy2(run_dir / "active_goal_completion_requirement_rows.csv", audit_dir / "ACTIVE_GOAL_REQUIREMENT_ROWS.csv")
shutil.copy2(run_dir / "active_goal_completion_section_rows.csv", audit_dir / "ACTIVE_GOAL_SECTION_ROWS.csv")
shutil.copy2(run_dir / "active_goal_completion_blocker_rows.csv", audit_dir / "ACTIVE_GOAL_BLOCKER_ROWS.csv")
shutil.copy2(run_dir / "active_goal_completion_next_action_rows.csv", audit_dir / "ACTIVE_GOAL_NEXT_ACTION_ROWS.csv")
audit_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "active_goal_complete": 0,
    "requirement_rows": len(requirement_rows),
    "pass_requirement_rows": sum(row["status"] == "pass" for row in requirement_rows),
    "blocked_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "objective_section_rows": len(section_rows),
    "pass_objective_section_rows": sum(row["status"] == "pass" for row in section_rows),
    "blocked_objective_section_rows": sum(row["status"] == "blocked" for row in section_rows),
    "actual_model_generation_ready": actual_model_generation_ready,
    "v1_0_comparison_ready": v1_0_comparison_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(audit_dir / "ACTIVE_GOAL_COMPLETION_AUDIT_MANIFEST.json").write_text(json.dumps(audit_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(audit_dir / "VERIFY_ACTIVE_GOAL_COMPLETION_AUDIT.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -s \"$DIR/ACTIVE_GOAL_COMPLETION_AUDIT_MANIFEST.json\"",
            "test -s \"$DIR/ACTIVE_GOAL_REQUIREMENT_ROWS.csv\"",
            "test -s \"$DIR/ACTIVE_GOAL_SECTION_ROWS.csv\"",
            "test -s \"$DIR/ACTIVE_GOAL_BLOCKER_ROWS.csv\"",
            "test -s \"$DIR/ACTIVE_GOAL_NEXT_ACTION_ROWS.csv\"",
            "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
            "  echo 'payload-like file referenced in active goal audit package' >&2",
            "  exit 1",
            "fi",
            "",
        ]
    ),
    encoding="utf-8",
)
(audit_dir / "VERIFY_ACTIVE_GOAL_COMPLETION_AUDIT.sh").chmod(0o755)
(audit_dir / "ACTIVE_GOAL_COMPLETION_AUDIT.md").write_text(
    "\n".join(
        [
            "# v61ft active goal completion audit",
            "",
            f"- active_goal_complete=0",
            f"- requirement_rows={len(requirement_rows)}",
            f"- pass_requirement_rows={audit_manifest['pass_requirement_rows']}",
            f"- blocked_requirement_rows={audit_manifest['blocked_requirement_rows']}",
            f"- objective_section_rows={len(section_rows)}",
            f"- pass_objective_section_rows={audit_manifest['pass_objective_section_rows']}",
            f"- blocked_objective_section_rows={audit_manifest['blocked_objective_section_rows']}",
            f"- v52_ready={v52_ready}",
            f"- v53_machine_complete_source_surface_ready={machine_complete_source_surface_ready}",
            f"- post_full_shard_runtime_evidence_ready={post_full_shard_runtime_evidence_ready}",
            f"- v1_0_comparison_ready={v1_0_comparison_ready}",
            "- actual_model_generation_ready=0",
            "",
            "The goal is not complete. F optional disposition is explicit, but v52_ready and 30B-150B wording remain blocked until D/E PM/release baseline evidence is accepted; v53 review/adjudication return and v61 actual generation evidence also remain missing.",
            "",
        ]
    ),
    encoding="utf-8",
)

package_files = sorted(path for path in audit_dir.rglob("*") if path.is_file())
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
write_csv(run_dir / "active_goal_completion_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61ft_active_goal_completion_audit_ready": 1,
    "v52y_f_optional_final_policy_ready": 1,
    "v53t_complete_source_audit_readiness_gate_ready": 1,
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": 1,
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": 1,
    "v61fs_post_fr_ready_command_execution_receipt_ready": 1,
    **metric_rows[0],
    "requirement_rows": len(requirement_rows),
    "pass_requirement_rows": sum(row["status"] == "pass" for row in requirement_rows),
    "blocked_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "objective_section_rows": len(section_rows),
    "pass_objective_section_rows": sum(row["status"] == "pass" for row in section_rows),
    "blocked_objective_section_rows": sum(row["status"] == "blocked" for row in section_rows),
    "blocker_rows": len(blocker_rows),
    "next_action_rows": len(next_action_rows),
    "ready_next_action_rows": sum(row["ready_to_run_now"] == "1" for row in next_action_rows),
    "blocked_next_action_rows": sum(row["ready_to_run_now"] == "0" for row in next_action_rows),
    "audit_package_file_rows": len(file_rows),
    "metadata_only_audit_package_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_audit_package_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": len(sources),
    "source_artifact_file_rows": len(source_artifacts),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v52-f-optional-and-ready", "status": status(f_optional_final_disposition_ready and v52_ready and comparison_wording_claim_ready), "actual_value": f"{f_optional_final_disposition}; v52_ready={v52_ready}; comparison_wording_claim_ready={comparison_wording_claim_ready}", "required_value": "explicit final disposition; D/E PM/release readiness; comparison wording ready", "reason": "v52 comparison wording remains blocked without required D/E readiness"},
    {"gate": "v53-machine-complete-source-surface", "status": "pass", "actual_value": f"repos={complete_source_repo_count}; queries={complete_source_query_rows}; answers={core_answer_rows}", "required_value": "10+ repos; 1000+ queries; 7000 answer rows", "reason": "machine complete-source surface is ready"},
    {"gate": "v53-review-return", "status": "blocked", "actual_value": f"human={accepted_human_review_rows}/{expected_human_review_rows}; adjudication={accepted_adjudication_rows}/{expected_adjudication_rows}", "required_value": "7000/7000;1000/1000", "reason": "real review/adjudication return missing"},
    {"gate": "v61-real-model-runtime-evidence", "status": "pass", "actual_value": f"manifest={real_manifest_fixture_replacement_ready}; gpu={gpu_page_dequant_matmul_measurement_ready}; kv={kv_cache_policy_ready}; v61j={v61j_source_bound_qa_command_pass}; runtime={post_full_shard_runtime_evidence_ready}", "required_value": "all ready", "reason": "v61 immediate real-model evidence targets are ready"},
    {"gate": "external-return-inputs", "status": "blocked", "actual_value": f"{present_external_input_rows}/{required_external_input_rows}", "required_value": "5/5", "reason": "external returned evidence roots missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual model generation remains unproven"},
    {"gate": "v1-comparison", "status": "blocked", "actual_value": str(v1_0_comparison_ready), "required_value": "1", "reason": "review and generation evidence missing"},
    {"gate": "active-goal-complete", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": f"{len(blocker_rows)} requirements remain blocked"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only audit"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FT_ACTIVE_GOAL_COMPLETION_AUDIT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# V61FT Active Goal Completion Audit Boundary",
            "",
            "- v61ft_active_goal_completion_audit_ready=1",
            "- active_goal_complete=0",
            f"- requirement_rows={summary['requirement_rows']}",
            f"- pass_requirement_rows={summary['pass_requirement_rows']}",
            f"- blocked_requirement_rows={summary['blocked_requirement_rows']}",
            f"- objective_section_rows={summary['objective_section_rows']}",
            f"- pass_objective_section_rows={summary['pass_objective_section_rows']}",
            f"- blocked_objective_section_rows={summary['blocked_objective_section_rows']}",
            f"- v52_ready={v52_ready}",
            f"- f_optional_final_disposition={f_optional_final_disposition}",
            f"- comparison_wording_claim_ready={comparison_wording_claim_ready}",
            f"- v53_machine_complete_source_surface_ready={machine_complete_source_surface_ready}",
            f"- complete_source_repo_count={complete_source_repo_count}",
            f"- complete_source_query_rows={complete_source_query_rows}",
            f"- core_answer_rows={core_answer_rows}",
            f"- accepted_human_review_rows={accepted_human_review_rows}/{expected_human_review_rows}",
            f"- accepted_adjudication_rows={accepted_adjudication_rows}/{expected_adjudication_rows}",
            f"- real_manifest_fixture_replacement_ready={real_manifest_fixture_replacement_ready}",
            f"- gpu_page_dequant_matmul_measurement_ready={gpu_page_dequant_matmul_measurement_ready}",
            f"- kv_cache_policy_ready={kv_cache_policy_ready}",
            f"- v61j_source_bound_qa_command_pass={v61j_source_bound_qa_command_pass}",
            f"- post_full_shard_runtime_evidence_ready={post_full_shard_runtime_evidence_ready}",
            f"- successful_ready_command_rows={successful_ready_command_rows}/{ready_command_rows}",
            f"- present_external_input_rows={present_external_input_rows}/{required_external_input_rows}",
            f"- v1_0_comparison_ready={v1_0_comparison_ready}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Blocked wording: this audit does not mark the active goal complete. v52 is closed for the measured-registry wording boundary, but v53 review/adjudication return, v61 actual generation, v1.0 comparison, production latency, near-frontier, and release claims remain blocked.",
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

print(f"v61ft_active_goal_completion_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
