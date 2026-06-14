#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53an_complete_source_actual_review_return_frontier"
RUN_ID="${V53AN_RUN_ID:-frontier_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53an_complete_source_actual_review_return_frontier_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V53AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null
V53AL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
V61FZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fz_post_fy_active_goal_status_refresh.sh" >/dev/null

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
prefix = "v53an_complete_source_actual_review_return_frontier"
frontier_dir = run_dir / "actual_review_return_frontier"
frontier_dir.mkdir(parents=True, exist_ok=True)


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


def copy_frontier(src, rel):
    dst = frontier_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_steps": results / "v53am_complete_source_return_acceptance_replay" / "replay_001" / "return_acceptance_replay_step_rows.csv",
    "v53am_commands": results / "v53am_complete_source_return_acceptance_replay" / "replay_001" / "return_acceptance_replay_command_rows.csv",
    "v53ak_summary": results / "v53ak_complete_source_external_return_operator_checklist_summary.csv",
    "v53ak_checklist": results / "v53ak_complete_source_external_return_operator_checklist" / "checklist_001" / "external_return_operator_checklist_rows.csv",
    "v53al_summary": results / "v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "v53al_preflight": results / "v53al_complete_source_external_return_bundle_preflight" / "preflight_001" / "external_return_bundle_preflight_rows.csv",
    "v61fz_summary": results / "v61fz_post_fy_active_goal_status_refresh_summary.csv",
    "v61fz_requirements": results / "v61fz_post_fy_active_goal_status_refresh" / "refresh_001" / "post_fy_status_requirement_rows.csv",
    "v61fz_blockers": results / "v61fz_post_fy_active_goal_status_refresh" / "refresh_001" / "post_fy_status_blocker_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v53an source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    if label.startswith("v53am"):
        folder = "source_v53am"
    elif label.startswith("v53ak"):
        folder = "source_v53ak"
    elif label.startswith("v53al"):
        folder = "source_v53al"
    else:
        folder = "source_v61fz"
    copied = copy(path, f"{folder}/{path.name}")
    source_rows.append({
        "source_id": label,
        "path": copied.relative_to(run_dir).as_posix(),
        "bytes": copied.stat().st_size,
        "sha256": sha256(copied),
        "metadata_only": "1",
    })
write_csv(run_dir / "actual_review_return_frontier_source_rows.csv", list(source_rows[0].keys()), source_rows)

v53am = read_csv(source_paths["v53am_summary"])[0]
v53ak = read_csv(source_paths["v53ak_summary"])[0]
v53al = read_csv(source_paths["v53al_summary"])[0]
v61fz = read_csv(source_paths["v61fz_summary"])[0]

required_ready = {
    "v53am_complete_source_return_acceptance_replay_ready": v53am,
    "v53ak_complete_source_external_return_operator_checklist_ready": v53ak,
    "v53al_complete_source_external_return_bundle_preflight_ready": v53al,
    "v61fz_post_fy_active_goal_status_refresh_ready": v61fz,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v53an requires {key}=1")

requirement_specs = [
    ("01-v52-f-optional-final-policy", "ready", "v61fz", f"v52_ready={v61fz['v52_ready']}; comparison_wording_claim_ready={v61fz['comparison_wording_claim_ready']}", ""),
    ("02-v53-complete-source-machine-surface", "ready", "v61fz", f"repos={v61fz['complete_source_repo_count']}; queries={v61fz['complete_source_query_rows']}; answers={v61fz['core_answer_rows']}", ""),
    ("03-v53-return-operator-checklist", "ready", "v53ak", f"checklist_rows={v53ak['checklist_rows']}; missing_checklist_rows={v53ak['missing_checklist_rows']}", ""),
    ("04-v53-return-preflight-surface", "ready", "v53al", f"preflight_surface_ready={v53al['preflight_surface_ready']}; preflight_rows={v53al['preflight_rows']}", ""),
    ("05-v53am-acceptance-replay-surface", "ready", "v53am", f"return_acceptance_replay_ready={v53am['return_acceptance_replay_ready']}; replay_step_rows={v53am['replay_step_rows']}", ""),
    ("06-v61-runtime-and-handoff-evidence", "ready", "v61fz", f"post_full_shard_runtime_evidence_ready={v61fz['post_full_shard_runtime_evidence_ready']}; root_pinned_replay_script_ready={v61fz['root_pinned_replay_script_ready']}", ""),
    ("07-return-bundle-preflight-pass", "blocked", "v53al", f"preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}", "supply 81 final return artifacts"),
    ("08-dispatch-receipt-return", "blocked", "v53am", f"accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}", "return 21 dispatch receipts"),
    ("09-review-chunk-return", "blocked", "v53am", f"accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}", "return 50 review chunk artifacts"),
    ("10-aggregate-human-review-return", "blocked", "v53am", f"answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}", "return 7000 human/source review rows"),
    ("11-adjudication-return", "blocked", "v53am", f"accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}", "return 1000 adjudication rows"),
    ("12-generation-result-return", "blocked", "v53am", f"accepted_generation_result_artifacts={v53am['accepted_generation_result_artifacts']}/{v53am['expected_generation_result_artifacts']}; generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}", "return five generation-result artifacts and 1000 accepted rows"),
    ("13-generation-execution-admission", "blocked", "v53am", f"generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}", "admit 1000 real generation executions"),
    ("14-v53-ready", "blocked", "v53am", f"review_return_ready={v53am['review_return_ready']}; v53_ready={v53am['v53_ready']}", "complete accepted review/adjudication return"),
    ("15-actual-model-generation", "blocked", "v53am/v61fz", "actual_model_generation_ready=0", "accepted real model generation remains missing"),
    ("16-v1-comparison-latency-release", "blocked", "v61fz", "v1 comparison, production latency, near-frontier, release all blocked", "requires accepted review/generation plus external audit evidence"),
]
requirement_rows = [
    {
        "requirement_id": req_id,
        "status": status,
        "source_gate": source,
        "evidence": evidence,
        "remaining_work": remaining,
    }
    for req_id, status, source, evidence, remaining in requirement_specs
]
write_csv(run_dir / "actual_review_return_frontier_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

blocker_rows = [
    {
        "blocker_id": row["requirement_id"],
        "source_gate": row["source_gate"],
        "evidence": row["evidence"],
        "remaining_work": row["remaining_work"],
    }
    for row in requirement_rows
    if row["status"] == "blocked"
]
write_csv(run_dir / "actual_review_return_frontier_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

action_rows = [
    {"action_id": "01-verify-v53am-replay", "ready_to_run_now": "1", "command": "./experiments/test_v53am_complete_source_return_acceptance_replay.sh", "purpose": "verify the downstream replay surface"},
    {"action_id": "02-verify-v61fz-status", "ready_to_run_now": "1", "command": "./experiments/test_v61fz_post_fy_active_goal_status_refresh.sh", "purpose": "verify the post-handoff status ledger"},
    {"action_id": "03-supply-final-return-bundle", "ready_to_run_now": "0", "command": "export V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle", "purpose": "requires real 81-artifact final return bundle"},
    {"action_id": "04-run-v53am-with-real-return", "ready_to_run_now": "0", "command": "V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh", "purpose": "blocked until the real return bundle exists"},
    {"action_id": "05-run-v61-root-pinned-replay", "ready_to_run_now": "0", "command": "V61FV_V53_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle V61FV_V61_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh", "purpose": "blocked until real return roots and provenance labels exist"},
    {"action_id": "06-refresh-v53an-frontier", "ready_to_run_now": "0", "command": "./experiments/run_v53an_complete_source_actual_review_return_frontier.sh", "purpose": "run after accepted return replay"},
]
write_csv(run_dir / "actual_review_return_frontier_action_rows.csv", list(action_rows[0].keys()), action_rows)

metric_rows = [{
    "v52_ready": as_int(v61fz, "v52_ready"),
    "v53_machine_complete_source_surface_ready": as_int(v61fz, "v53_machine_complete_source_surface_ready"),
    "complete_source_repo_count": as_int(v61fz, "complete_source_repo_count"),
    "complete_source_query_rows": as_int(v61fz, "complete_source_query_rows"),
    "core_answer_rows": as_int(v61fz, "core_answer_rows"),
    "operator_checklist_rows": as_int(v53ak, "checklist_rows"),
    "missing_checklist_rows": as_int(v53ak, "missing_checklist_rows"),
    "preflight_rows": as_int(v53al, "preflight_rows"),
    "preflight_pass_rows": as_int(v53al, "preflight_pass_rows"),
    "return_bundle_preflight_pass": as_int(v53al, "return_bundle_preflight_pass"),
    "replay_step_rows": as_int(v53am, "replay_step_rows"),
    "ready_replay_step_rows": as_int(v53am, "ready_replay_step_rows"),
    "blocked_replay_step_rows": as_int(v53am, "blocked_replay_step_rows"),
    "accepted_dispatch_receipt_rows": as_int(v53am, "accepted_dispatch_receipt_rows"),
    "dispatch_receipt_template_rows": as_int(v53am, "dispatch_receipt_template_rows"),
    "accepted_chunk_return_artifact_rows": as_int(v53am, "accepted_chunk_return_artifact_rows"),
    "review_chunk_return_artifact_rows": as_int(v53am, "review_chunk_return_artifact_rows"),
    "answer_review_accepted_rows": as_int(v53am, "answer_review_accepted_rows"),
    "expected_human_review_rows": as_int(v53am, "expected_human_review_rows"),
    "accepted_adjudication_rows": as_int(v53am, "accepted_adjudication_rows"),
    "expected_adjudication_rows": as_int(v53am, "expected_adjudication_rows"),
    "generation_execution_admitted_rows": as_int(v53am, "generation_execution_admitted_rows"),
    "generation_execution_admission_rows": as_int(v53am, "generation_execution_admission_rows"),
    "accepted_generation_result_artifacts": as_int(v53am, "accepted_generation_result_artifacts"),
    "expected_generation_result_artifacts": as_int(v53am, "expected_generation_result_artifacts"),
    "generation_result_accepted_rows": as_int(v53am, "generation_result_accepted_rows"),
    "generation_result_acceptance_rows": as_int(v53am, "generation_result_acceptance_rows"),
    "actual_model_generation_ready": 0,
    "active_goal_complete": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}]
write_csv(run_dir / "actual_review_return_frontier_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

for rel, path in [
    ("ACTUAL_REVIEW_RETURN_FRONTIER_REQUIREMENT_ROWS.csv", run_dir / "actual_review_return_frontier_requirement_rows.csv"),
    ("ACTUAL_REVIEW_RETURN_FRONTIER_BLOCKER_ROWS.csv", run_dir / "actual_review_return_frontier_blocker_rows.csv"),
    ("ACTUAL_REVIEW_RETURN_FRONTIER_ACTION_ROWS.csv", run_dir / "actual_review_return_frontier_action_rows.csv"),
    ("ACTUAL_REVIEW_RETURN_FRONTIER_METRIC_ROWS.csv", run_dir / "actual_review_return_frontier_metric_rows.csv"),
]:
    copy_frontier(path, rel)

frontier_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "frontier_requirement_rows": len(requirement_rows),
    "ready_frontier_requirement_rows": sum(row["status"] == "ready" for row in requirement_rows),
    "blocked_frontier_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "frontier_blocker_rows": len(blocker_rows),
    "frontier_action_rows": len(action_rows),
    "ready_frontier_action_rows": sum(row["ready_to_run_now"] == "1" for row in action_rows),
    "blocked_frontier_action_rows": sum(row["ready_to_run_now"] == "0" for row in action_rows),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(frontier_dir / "ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json").write_text(json.dumps(frontier_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(frontier_dir / "VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_REQUIREMENT_ROWS.csv\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_BLOCKER_ROWS.csv\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_ACTION_ROWS.csv\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_METRIC_ROWS.csv\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in actual review return frontier package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(frontier_dir / "VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER.sh").chmod(0o755)
(frontier_dir / "ACTUAL_REVIEW_RETURN_FRONTIER.md").write_text(
    "\n".join([
        "# v53an complete-source actual review return frontier",
        "",
        f"- frontier_requirement_rows={len(requirement_rows)}",
        f"- ready_frontier_requirement_rows={frontier_manifest['ready_frontier_requirement_rows']}",
        f"- blocked_frontier_requirement_rows={frontier_manifest['blocked_frontier_requirement_rows']}",
        f"- checklist_rows={v53ak['checklist_rows']}",
        f"- preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}",
        f"- answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}",
        f"- accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "The real return bundle is still required before v53 review acceptance or v61 generation claims can open.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in frontier_dir.rglob("*") if path.is_file())
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
write_csv(run_dir / "actual_review_return_frontier_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v53an_complete_source_actual_review_return_frontier_ready": 1,
    "v53am_complete_source_return_acceptance_replay_ready": 1,
    "v53ak_complete_source_external_return_operator_checklist_ready": 1,
    "v53al_complete_source_external_return_bundle_preflight_ready": 1,
    "v61fz_post_fy_active_goal_status_refresh_ready": 1,
    "active_goal_complete": 0,
    "v52_ready": as_int(v61fz, "v52_ready"),
    "v53_machine_complete_source_surface_ready": as_int(v61fz, "v53_machine_complete_source_surface_ready"),
    "complete_source_repo_count": as_int(v61fz, "complete_source_repo_count"),
    "complete_source_query_rows": as_int(v61fz, "complete_source_query_rows"),
    "core_answer_rows": as_int(v61fz, "core_answer_rows"),
    "operator_checklist_rows": as_int(v53ak, "checklist_rows"),
    "missing_checklist_rows": as_int(v53ak, "missing_checklist_rows"),
    "preflight_rows": as_int(v53al, "preflight_rows"),
    "preflight_pass_rows": as_int(v53al, "preflight_pass_rows"),
    "return_bundle_preflight_pass": as_int(v53al, "return_bundle_preflight_pass"),
    "replay_step_rows": as_int(v53am, "replay_step_rows"),
    "ready_replay_step_rows": as_int(v53am, "ready_replay_step_rows"),
    "blocked_replay_step_rows": as_int(v53am, "blocked_replay_step_rows"),
    "accepted_dispatch_receipt_rows": as_int(v53am, "accepted_dispatch_receipt_rows"),
    "dispatch_receipt_template_rows": as_int(v53am, "dispatch_receipt_template_rows"),
    "accepted_chunk_return_artifact_rows": as_int(v53am, "accepted_chunk_return_artifact_rows"),
    "review_chunk_return_artifact_rows": as_int(v53am, "review_chunk_return_artifact_rows"),
    "answer_review_accepted_rows": as_int(v53am, "answer_review_accepted_rows"),
    "expected_human_review_rows": as_int(v53am, "expected_human_review_rows"),
    "accepted_adjudication_rows": as_int(v53am, "accepted_adjudication_rows"),
    "expected_adjudication_rows": as_int(v53am, "expected_adjudication_rows"),
    "generation_execution_admitted_rows": as_int(v53am, "generation_execution_admitted_rows"),
    "generation_execution_admission_rows": as_int(v53am, "generation_execution_admission_rows"),
    "accepted_generation_result_artifacts": as_int(v53am, "accepted_generation_result_artifacts"),
    "expected_generation_result_artifacts": as_int(v53am, "expected_generation_result_artifacts"),
    "generation_result_accepted_rows": as_int(v53am, "generation_result_accepted_rows"),
    "generation_result_acceptance_rows": as_int(v53am, "generation_result_acceptance_rows"),
    "review_return_ready": as_int(v53am, "review_return_ready"),
    "v53_ready": as_int(v53am, "v53_ready"),
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v53an": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "frontier_requirement_rows": len(requirement_rows),
    "ready_frontier_requirement_rows": sum(row["status"] == "ready" for row in requirement_rows),
    "blocked_frontier_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "frontier_blocker_rows": len(blocker_rows),
    "frontier_action_rows": len(action_rows),
    "ready_frontier_action_rows": sum(row["ready_to_run_now"] == "1" for row in action_rows),
    "blocked_frontier_action_rows": sum(row["ready_to_run_now"] == "0" for row in action_rows),
    "frontier_package_file_rows": len(package_file_rows),
    "metadata_only_frontier_package_file_rows": sum(row["metadata_only"] == "1" for row in package_file_rows),
    "payload_like_frontier_package_file_rows": sum(row["payload_like"] == "1" for row in package_file_rows),
    "source_file_rows": len(source_rows),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53-machine-surface", "status": "pass", "actual_value": f"{summary['complete_source_repo_count']}/{summary['complete_source_query_rows']}/{summary['core_answer_rows']}", "required_value": "10/1000/7000", "reason": "complete-source machine surface is ready"},
    {"gate": "return-operator-checklist", "status": "pass", "actual_value": str(summary["operator_checklist_rows"]), "required_value": "81", "reason": "operator checklist is ready"},
    {"gate": "return-preflight-pass", "status": "blocked", "actual_value": f"{summary['preflight_pass_rows']}/{summary['preflight_rows']}", "required_value": "81/81", "reason": "real return bundle missing"},
    {"gate": "human-review-return", "status": "blocked", "actual_value": f"{summary['answer_review_accepted_rows']}/{summary['expected_human_review_rows']}", "required_value": "7000/7000", "reason": "human/source review rows missing"},
    {"gate": "adjudication-return", "status": "blocked", "actual_value": f"{summary['accepted_adjudication_rows']}/{summary['expected_adjudication_rows']}", "required_value": "1000/1000", "reason": "adjudication rows missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only frontier"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V53AN_COMPLETE_SOURCE_ACTUAL_REVIEW_RETURN_FRONTIER_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V53AN Complete-Source Actual Review Return Frontier",
        "",
        "- v53an_complete_source_actual_review_return_frontier_ready=1",
        "- active_goal_complete=0",
        f"- complete_source_repo_count={summary['complete_source_repo_count']}",
        f"- complete_source_query_rows={summary['complete_source_query_rows']}",
        f"- core_answer_rows={summary['core_answer_rows']}",
        f"- operator_checklist_rows={summary['operator_checklist_rows']}",
        f"- missing_checklist_rows={summary['missing_checklist_rows']}",
        f"- preflight_pass_rows={summary['preflight_pass_rows']}/{summary['preflight_rows']}",
        f"- accepted_dispatch_receipt_rows={summary['accepted_dispatch_receipt_rows']}/{summary['dispatch_receipt_template_rows']}",
        f"- accepted_chunk_return_artifact_rows={summary['accepted_chunk_return_artifact_rows']}/{summary['review_chunk_return_artifact_rows']}",
        f"- answer_review_accepted_rows={summary['answer_review_accepted_rows']}/{summary['expected_human_review_rows']}",
        f"- accepted_adjudication_rows={summary['accepted_adjudication_rows']}/{summary['expected_adjudication_rows']}",
        f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}",
        f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}",
        "- review_return_ready=0",
        "- v53_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: v53an is the actual review-return frontier. It does not accept templates, fixture-only paths, dispatch logistics, or missing review/generation rows as real evidence.",
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

print(f"v53an_complete_source_actual_review_return_frontier_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
