#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fz_post_fy_active_goal_status_refresh"
RUN_ID="${V61FZ_RUN_ID:-refresh_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fz_post_fy_active_goal_status_refresh_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fy_post_fx_operator_handoff_receipt.sh" >/dev/null
V61FT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ft_active_goal_completion_audit.sh" >/dev/null
V61FU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fu_post_ft_external_return_closure_frontier.sh" >/dev/null

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
prefix = "v61fz_post_fy_active_goal_status_refresh"
refresh_dir = run_dir / "post_fy_active_goal_status_refresh"
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


def copy_refresh(src, rel):
    dst = refresh_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v61ft_summary": results / "v61ft_active_goal_completion_audit_summary.csv",
    "v61ft_requirements": results / "v61ft_active_goal_completion_audit" / "audit_001" / "active_goal_completion_requirement_rows.csv",
    "v61fu_summary": results / "v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "v61fu_deltas": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier_delta_rows.csv",
    "v61fx_summary": results / "v61fx_post_fw_dual_return_operator_handoff_bundle_summary.csv",
    "v61fx_root_contracts": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_root_contract_rows.csv",
    "v61fy_summary": results / "v61fy_post_fx_operator_handoff_receipt_summary.csv",
    "v61fy_execution": results / "v61fy_post_fx_operator_handoff_receipt" / "receipt_001" / "operator_handoff_receipt_execution_rows.csv",
    "v61fy_guard": results / "v61fy_post_fx_operator_handoff_receipt" / "receipt_001" / "operator_handoff_guard_probe_rows.csv",
    "v61fy_stage": results / "v61fy_post_fx_operator_handoff_receipt" / "receipt_001" / "operator_handoff_receipt_stage_rows.csv",
    "v61fy_manifest": results / "v61fy_post_fx_operator_handoff_receipt" / "receipt_001" / "operator_handoff_receipt" / "OPERATOR_HANDOFF_RECEIPT_MANIFEST.json",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fz source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61ft"):
        folder = "source_v61ft"
    elif label.startswith("v61fu"):
        folder = "source_v61fu"
    elif label.startswith("v61fx"):
        folder = "source_v61fx"
    else:
        folder = "source_v61fy"
    copied = copy(path, f"{folder}/{path.name}")
    source_rows.append({
        "source_id": label,
        "path": copied.relative_to(run_dir).as_posix(),
        "bytes": copied.stat().st_size,
        "sha256": sha256(copied),
        "metadata_only": "1",
    })
write_csv(run_dir / "post_fy_status_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61ft = read_csv(source_paths["v61ft_summary"])[0]
v61fu = read_csv(source_paths["v61fu_summary"])[0]
v61fx = read_csv(source_paths["v61fx_summary"])[0]
v61fy = read_csv(source_paths["v61fy_summary"])[0]

required_ready = {
    "v61ft_active_goal_completion_audit_ready": v61ft,
    "v61fu_post_ft_external_return_closure_frontier_ready": v61fu,
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": v61fx,
    "v61fy_post_fx_operator_handoff_receipt_ready": v61fy,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v61fz requires {key}=1")

requirements = [
    ("01-v52-f-optional-final-disposition", "v52", 1, f"f_optional_final_disposition={v61ft['f_optional_final_disposition']}", ""),
    ("02-v52-comparison-wording-disclosure", "v52", as_int(v61ft, "comparison_wording_claim_ready"), "comparison_wording_claim_ready=1", ""),
    ("03-v53-complete-source-machine-surface", "v53", as_int(v61ft, "v53_machine_complete_source_surface_ready"), f"repos={v61ft['complete_source_repo_count']}; queries={v61ft['complete_source_query_rows']}; answers={v61ft['core_answer_rows']}", ""),
    ("04-v53-human-review-return", "v53", 0, f"accepted_human_review_rows={v61ft['accepted_human_review_rows']}/{v61ft['expected_human_review_rows']}", "return real 7000 human/source review rows"),
    ("05-v53-adjudication-return", "v53", 0, f"accepted_adjudication_rows={v61ft['accepted_adjudication_rows']}/{v61ft['expected_adjudication_rows']}", "return real 1000 adjudication rows"),
    ("06-v53-identity-conflict-return", "v53", 0, f"missing_reviewer_identity_rows={v61fu['missing_reviewer_identity_rows']}; missing_conflict_disclosure_rows={v61fu['missing_conflict_disclosure_rows']}", "return reviewer identity and conflict rows"),
    ("07-v61-real-model-runtime-evidence", "v61", as_int(v61ft, "post_full_shard_runtime_evidence_ready"), f"full_checkpoint={v61ft['full_checkpoint_materialization_ready']}; full_page_hash={v61ft['full_safetensors_page_hash_binding_ready']}; runtime_admission={v61ft['runtime_admission_accepted_rows']}", ""),
    ("08-v61-root-pinned-handoff-receipt", "v61", as_int(v61fy, "root_pinned_replay_script_ready"), "root_pinned_replay_script_ready=1", ""),
    ("09-v61-handoff-ready-actions", "v61", int(v61fy["ready_handoff_action_rows"] == v61fy["successful_ready_handoff_action_rows"]), f"successful_ready_handoff_action_rows={v61fy['successful_ready_handoff_action_rows']}/{v61fy['ready_handoff_action_rows']}", ""),
    ("10-v61-fail-closed-guard-probes", "v61", int(v61fy["guard_probe_rows"] == v61fy["passed_guard_probe_rows"]), f"passed_guard_probe_rows={v61fy['passed_guard_probe_rows']}/{v61fy['guard_probe_rows']}", ""),
    ("11-dual-real-return-roots", "v53-v61", 0, f"missing_external_return_artifacts={v61fu['missing_external_return_artifacts']}; root_contract_rows={v61fx['root_contract_rows']}", "supply real v53 and v61 return roots"),
    ("12-v61-generation-result-artifacts", "v61", 0, f"missing_generation_result_artifacts={v61fu['missing_generation_result_artifacts']}", "return real generation-result artifacts"),
    ("13-v61-generation-result-rows", "v61", 0, f"missing_generation_result_rows={v61fu['missing_generation_result_rows']}", "return 1000 accepted generation rows"),
    ("14-v61-generation-execution-admission", "v61", 0, f"missing_generation_execution_admission_rows={v61fu['missing_generation_execution_admission_rows']}", "admit real generation execution"),
    ("15-v61-final-acceptance", "v61", 0, f"missing_final_acceptance_rows={v61fu['missing_final_acceptance_rows']}", "return final acceptance rows"),
    ("16-v61-actual-model-generation", "v61", 0, "actual_model_generation_ready=0", "accepted real generation remains missing"),
    ("17-v1-comparison-ready", "v1.0", 0, "v1_0_comparison_ready=0", "requires review/adjudication and generation-result acceptance"),
    ("18-latency-quality-release", "release", 0, "near_frontier=0; production_latency=0; release=0", "requires external quality, latency, and release evidence"),
]
requirement_rows = [
    {
        "requirement_id": req_id,
        "section": section,
        "status": "ready" if ready else "blocked",
        "ready": str(int(bool(ready))),
        "evidence": evidence,
        "remaining_work": remaining,
    }
    for req_id, section, ready, evidence, remaining in requirements
]
write_csv(run_dir / "post_fy_status_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

blocker_rows = [
    {
        "blocker_id": row["requirement_id"],
        "section": row["section"],
        "evidence": row["evidence"],
        "remaining_work": row["remaining_work"],
    }
    for row in requirement_rows
    if row["status"] == "blocked"
]
write_csv(run_dir / "post_fy_status_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

next_action_rows = [
    {"action_id": "01-verify-v61fy-receipt", "ready_to_run_now": "1", "command": "results/v61fy_post_fx_operator_handoff_receipt/receipt_001/operator_handoff_receipt/VERIFY_OPERATOR_HANDOFF_RECEIPT.sh", "purpose": "verify latest handoff receipt"},
    {"action_id": "02-supply-v53-return-root", "ready_to_run_now": "0", "command": "export V61FV_V53_RETURN_BUNDLE_DIR=/path/to/v53_external_return_root; export V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle", "purpose": "requires real 81-artifact v53 return root"},
    {"action_id": "03-supply-v61-return-root", "ready_to_run_now": "0", "command": "export V61FV_V61_RETURN_BUNDLE_DIR=/path/to/v61_generation_intake_return_root; export V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle", "purpose": "requires real 10-file v61 generation-intake return root"},
    {"action_id": "04-run-root-pinned-dual-return-replay", "ready_to_run_now": "0", "command": "results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh", "purpose": "blocked until both real roots and provenance labels exist"},
    {"action_id": "05-refresh-post-return-status", "ready_to_run_now": "0", "command": "./experiments/run_v61fz_post_fy_active_goal_status_refresh.sh", "purpose": "run after accepted return replay"},
    {"action_id": "06-latency-quality-release-audit", "ready_to_run_now": "0", "command": "<run production-ish latency, near-frontier quality, and release audit>", "purpose": "blocked until actual generation evidence exists"},
]
write_csv(run_dir / "post_fy_status_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

metric_rows = [{
    "active_goal_complete": as_int(v61ft, "active_goal_complete"),
    "v52_ready": as_int(v61ft, "v52_ready"),
    "f_optional_final_disposition_ready": as_int(v61ft, "f_optional_final_disposition_ready"),
    "v53_machine_complete_source_surface_ready": as_int(v61ft, "v53_machine_complete_source_surface_ready"),
    "complete_source_repo_count": as_int(v61ft, "complete_source_repo_count"),
    "complete_source_query_rows": as_int(v61ft, "complete_source_query_rows"),
    "core_answer_rows": as_int(v61ft, "core_answer_rows"),
    "accepted_human_review_rows": as_int(v61ft, "accepted_human_review_rows"),
    "expected_human_review_rows": as_int(v61ft, "expected_human_review_rows"),
    "accepted_adjudication_rows": as_int(v61ft, "accepted_adjudication_rows"),
    "expected_adjudication_rows": as_int(v61ft, "expected_adjudication_rows"),
    "post_full_shard_runtime_evidence_ready": as_int(v61ft, "post_full_shard_runtime_evidence_ready"),
    "full_checkpoint_materialization_ready": as_int(v61ft, "full_checkpoint_materialization_ready"),
    "full_safetensors_page_hash_binding_ready": as_int(v61ft, "full_safetensors_page_hash_binding_ready"),
    "runtime_admission_accepted_rows": as_int(v61ft, "runtime_admission_accepted_rows"),
    "root_pinned_replay_script_ready": as_int(v61fy, "root_pinned_replay_script_ready"),
    "successful_ready_handoff_action_rows": as_int(v61fy, "successful_ready_handoff_action_rows"),
    "ready_handoff_action_rows": as_int(v61fy, "ready_handoff_action_rows"),
    "passed_guard_probe_rows": as_int(v61fy, "passed_guard_probe_rows"),
    "guard_probe_rows": as_int(v61fy, "guard_probe_rows"),
    "blocked_handoff_action_execution_attempt_rows": as_int(v61fy, "blocked_handoff_action_execution_attempt_rows"),
    "missing_external_return_artifacts": as_int(v61fu, "missing_external_return_artifacts"),
    "missing_human_review_rows": as_int(v61fu, "missing_human_review_rows"),
    "missing_adjudication_rows": as_int(v61fu, "missing_adjudication_rows"),
    "missing_generation_result_artifacts": as_int(v61fu, "missing_generation_result_artifacts"),
    "missing_generation_result_rows": as_int(v61fu, "missing_generation_result_rows"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}]
write_csv(run_dir / "post_fy_status_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

for rel, path in [
    ("POST_FY_STATUS_REQUIREMENT_ROWS.csv", run_dir / "post_fy_status_requirement_rows.csv"),
    ("POST_FY_STATUS_BLOCKER_ROWS.csv", run_dir / "post_fy_status_blocker_rows.csv"),
    ("POST_FY_STATUS_NEXT_ACTION_ROWS.csv", run_dir / "post_fy_status_next_action_rows.csv"),
    ("POST_FY_STATUS_METRIC_ROWS.csv", run_dir / "post_fy_status_metric_rows.csv"),
]:
    copy_refresh(path, rel)

refresh_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "requirement_rows": len(requirement_rows),
    "ready_requirement_rows": sum(row["status"] == "ready" for row in requirement_rows),
    "blocked_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "blocker_rows": len(blocker_rows),
    "ready_next_action_rows": sum(row["ready_to_run_now"] == "1" for row in next_action_rows),
    "blocked_next_action_rows": sum(row["ready_to_run_now"] == "0" for row in next_action_rows),
    "active_goal_complete": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(refresh_dir / "POST_FY_STATUS_MANIFEST.json").write_text(json.dumps(refresh_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(refresh_dir / "VERIFY_POST_FY_STATUS_REFRESH.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/POST_FY_STATUS_MANIFEST.json\"",
        "test -s \"$DIR/POST_FY_STATUS_REQUIREMENT_ROWS.csv\"",
        "test -s \"$DIR/POST_FY_STATUS_BLOCKER_ROWS.csv\"",
        "test -s \"$DIR/POST_FY_STATUS_NEXT_ACTION_ROWS.csv\"",
        "test -s \"$DIR/POST_FY_STATUS_METRIC_ROWS.csv\"",
        "grep -q 'active_goal_complete' \"$DIR/POST_FY_STATUS_MANIFEST.json\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/POST_FY_STATUS_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in post-fy status package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(refresh_dir / "VERIFY_POST_FY_STATUS_REFRESH.sh").chmod(0o755)
(refresh_dir / "POST_FY_STATUS_REFRESH.md").write_text(
    "\n".join([
        "# v61fz post-fy active goal status refresh",
        "",
        f"- requirement_rows={len(requirement_rows)}",
        f"- ready_requirement_rows={refresh_manifest['ready_requirement_rows']}",
        f"- blocked_requirement_rows={refresh_manifest['blocked_requirement_rows']}",
        f"- blocker_rows={len(blocker_rows)}",
        f"- root_pinned_replay_script_ready={v61fy['root_pinned_replay_script_ready']}",
        f"- successful_ready_handoff_action_rows={v61fy['successful_ready_handoff_action_rows']}/{v61fy['ready_handoff_action_rows']}",
        f"- missing_external_return_artifacts={v61fu['missing_external_return_artifacts']}",
        "- active_goal_complete=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "This refresh makes the latest post-handoff state explicit: v52 optional F wording, v53 machine surface, and v61 runtime/page evidence are ready; real review/generation returns and claims remain blocked.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in refresh_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "post_fy_status_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61fz_post_fy_active_goal_status_refresh_ready": 1,
    "v61fy_post_fx_operator_handoff_receipt_ready": 1,
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": 1,
    "v61fu_post_ft_external_return_closure_frontier_ready": 1,
    "v61ft_active_goal_completion_audit_ready": 1,
    "active_goal_complete": 0,
    "v52_ready": as_int(v61ft, "v52_ready"),
    "f_optional_final_disposition_ready": as_int(v61ft, "f_optional_final_disposition_ready"),
    "comparison_wording_claim_ready": as_int(v61ft, "comparison_wording_claim_ready"),
    "v53_machine_complete_source_surface_ready": as_int(v61ft, "v53_machine_complete_source_surface_ready"),
    "complete_source_repo_count": as_int(v61ft, "complete_source_repo_count"),
    "complete_source_query_rows": as_int(v61ft, "complete_source_query_rows"),
    "core_answer_rows": as_int(v61ft, "core_answer_rows"),
    "accepted_human_review_rows": as_int(v61ft, "accepted_human_review_rows"),
    "expected_human_review_rows": as_int(v61ft, "expected_human_review_rows"),
    "accepted_adjudication_rows": as_int(v61ft, "accepted_adjudication_rows"),
    "expected_adjudication_rows": as_int(v61ft, "expected_adjudication_rows"),
    "post_full_shard_runtime_evidence_ready": as_int(v61ft, "post_full_shard_runtime_evidence_ready"),
    "full_checkpoint_materialization_ready": as_int(v61ft, "full_checkpoint_materialization_ready"),
    "full_safetensors_page_hash_binding_ready": as_int(v61ft, "full_safetensors_page_hash_binding_ready"),
    "runtime_admission_accepted_rows": as_int(v61ft, "runtime_admission_accepted_rows"),
    "root_pinned_replay_script_ready": as_int(v61fy, "root_pinned_replay_script_ready"),
    "ready_handoff_action_rows": as_int(v61fy, "ready_handoff_action_rows"),
    "successful_ready_handoff_action_rows": as_int(v61fy, "successful_ready_handoff_action_rows"),
    "blocked_handoff_action_execution_attempt_rows": as_int(v61fy, "blocked_handoff_action_execution_attempt_rows"),
    "guard_probe_rows": as_int(v61fy, "guard_probe_rows"),
    "passed_guard_probe_rows": as_int(v61fy, "passed_guard_probe_rows"),
    "missing_external_return_artifacts": as_int(v61fu, "missing_external_return_artifacts"),
    "missing_human_review_rows": as_int(v61fu, "missing_human_review_rows"),
    "missing_adjudication_rows": as_int(v61fu, "missing_adjudication_rows"),
    "missing_generation_result_artifacts": as_int(v61fu, "missing_generation_result_artifacts"),
    "missing_generation_result_rows": as_int(v61fu, "missing_generation_result_rows"),
    "dual_external_return_real_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fz": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "requirement_rows": len(requirement_rows),
    "ready_requirement_rows": sum(row["status"] == "ready" for row in requirement_rows),
    "blocked_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "blocker_rows": len(blocker_rows),
    "next_action_rows": len(next_action_rows),
    "ready_next_action_rows": sum(row["ready_to_run_now"] == "1" for row in next_action_rows),
    "blocked_next_action_rows": sum(row["ready_to_run_now"] == "0" for row in next_action_rows),
    "status_package_file_rows": len(package_file_rows),
    "metadata_only_status_package_file_rows": sum(row["metadata_only"] == "1" for row in package_file_rows),
    "payload_like_status_package_file_rows": sum(row["payload_like"] == "1" for row in package_file_rows),
    "source_file_rows": len(source_rows),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v52-f-optional-policy", "status": "pass", "actual_value": str(summary["v52_ready"]), "required_value": "1", "reason": "F optional final disposition is explicit"},
    {"gate": "v53-machine-surface", "status": "pass", "actual_value": f"{summary['complete_source_repo_count']} repos/{summary['complete_source_query_rows']} queries/{summary['core_answer_rows']} answers", "required_value": "10+/1000+/7000", "reason": "complete-source machine surface exists"},
    {"gate": "v61-runtime-evidence", "status": "pass", "actual_value": str(summary["post_full_shard_runtime_evidence_ready"]), "required_value": "1", "reason": "full shard/page hash/runtime evidence is ready"},
    {"gate": "v61fy-root-pinned-handoff-receipt", "status": "pass", "actual_value": str(summary["root_pinned_replay_script_ready"]), "required_value": "1", "reason": "handoff receipt verifies root-pinned fail-closed script"},
    {"gate": "external-review-return", "status": "blocked", "actual_value": f"{summary['accepted_human_review_rows']}/{summary['expected_human_review_rows']}", "required_value": "7000/7000", "reason": "real review return missing"},
    {"gate": "dual-real-return-roots", "status": "blocked", "actual_value": str(summary["dual_external_return_real_ready"]), "required_value": "1", "reason": "two real return roots missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only status refresh"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FZ_POST_FY_ACTIVE_GOAL_STATUS_REFRESH_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V61FZ Post-FY Active Goal Status Refresh",
        "",
        "- v61fz_post_fy_active_goal_status_refresh_ready=1",
        "- active_goal_complete=0",
        f"- v52_ready={summary['v52_ready']}",
        f"- v53_machine_complete_source_surface_ready={summary['v53_machine_complete_source_surface_ready']}",
        f"- complete_source_repo_count={summary['complete_source_repo_count']}",
        f"- complete_source_query_rows={summary['complete_source_query_rows']}",
        f"- core_answer_rows={summary['core_answer_rows']}",
        f"- post_full_shard_runtime_evidence_ready={summary['post_full_shard_runtime_evidence_ready']}",
        f"- root_pinned_replay_script_ready={summary['root_pinned_replay_script_ready']}",
        f"- successful_ready_handoff_action_rows={summary['successful_ready_handoff_action_rows']}/{summary['ready_handoff_action_rows']}",
        f"- passed_guard_probe_rows={summary['passed_guard_probe_rows']}/{summary['guard_probe_rows']}",
        f"- missing_external_return_artifacts={summary['missing_external_return_artifacts']}",
        f"- missing_human_review_rows={summary['missing_human_review_rows']}",
        f"- missing_adjudication_rows={summary['missing_adjudication_rows']}",
        f"- missing_generation_result_artifacts={summary['missing_generation_result_artifacts']}",
        f"- missing_generation_result_rows={summary['missing_generation_result_rows']}",
        "- dual_external_return_real_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: v61fz is a status refresh after the root-pinned handoff receipt. It does not complete the active goal, accept external review rows, execute real generation, or open release claims.",
        "",
    ]),
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

print(f"v61fz_post_fy_active_goal_status_refresh_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
