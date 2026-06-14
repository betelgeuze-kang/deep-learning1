#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fu_post_ft_external_return_closure_frontier"
RUN_ID="${V61FU_RUN_ID:-frontier_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fu_post_ft_external_return_closure_frontier_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ft_active_goal_completion_audit.sh" >/dev/null
V61EZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ez_active_goal_post_ey_status_refresh.sh" >/dev/null
V61FD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh" >/dev/null
V61FC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null

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
prefix = "v61fu_post_ft_external_return_closure_frontier"
frontier_dir = run_dir / "external_return_closure_frontier"
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


def status(flag):
    return "ready" if flag else "blocked"


source_paths = {
    "v61ft_summary": results / "v61ft_active_goal_completion_audit_summary.csv",
    "v61ft_decision": results / "v61ft_active_goal_completion_audit_decision.csv",
    "v61ft_requirements": results / "v61ft_active_goal_completion_audit" / "audit_001" / "active_goal_completion_requirement_rows.csv",
    "v61ez_summary": results / "v61ez_active_goal_post_ey_status_refresh_summary.csv",
    "v61ez_decision": results / "v61ez_active_goal_post_ey_status_refresh_decision.csv",
    "v61ez_requirements": results / "v61ez_active_goal_post_ey_status_refresh" / "refresh_001" / "post_ey_requirement_rows.csv",
    "v61ez_actions": results / "v61ez_active_goal_post_ey_status_refresh" / "refresh_001" / "post_ey_next_action_rows.csv",
    "v61fd_summary": results / "v61fd_post_fc_real_return_closure_delta_ledger_summary.csv",
    "v61fd_decision": results / "v61fd_post_fc_real_return_closure_delta_ledger_decision.csv",
    "v61fd_deltas": results / "v61fd_post_fc_real_return_closure_delta_ledger" / "ledger_001" / "post_fc_real_return_closure_delta_rows.csv",
    "v61fd_blockers": results / "v61fd_post_fc_real_return_closure_delta_ledger" / "ledger_001" / "post_fc_real_return_closure_blocker_rows.csv",
    "v61fd_commands": results / "v61fd_post_fc_real_return_closure_delta_ledger" / "ledger_001" / "post_fc_real_return_closure_command_rows.csv",
    "v61fd_frontier": results / "v61fd_post_fc_real_return_closure_delta_ledger" / "ledger_001" / "real_return_closure_delta_ledger" / "REAL_RETURN_CLOSURE_FRONTIER.json",
    "v61fc_summary": results / "v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "v61fc_decision": results / "v61fc_post_fb_dual_external_return_operator_packet_decision.csv",
    "v61fc_required_artifacts": results / "v61fc_post_fb_dual_external_return_operator_packet" / "packet_001" / "dual_external_return_required_artifact_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fu source {label}: {path}")

for label, path in source_paths.items():
    if label.startswith("v61ft"):
        folder = "source_v61ft"
    elif label.startswith("v61ez"):
        folder = "source_v61ez"
    elif label.startswith("v61fd"):
        folder = "source_v61fd"
    else:
        folder = "source_v61fc"
    copy(path, f"{folder}/{path.name}")

v61ft = read_csv(source_paths["v61ft_summary"])[0]
v61ez = read_csv(source_paths["v61ez_summary"])[0]
v61fd = read_csv(source_paths["v61fd_summary"])[0]
v61fc = read_csv(source_paths["v61fc_summary"])[0]
delta_rows = read_csv(source_paths["v61fd_deltas"])
command_rows = read_csv(source_paths["v61fd_commands"])

required_ready = {
    "v61ft_active_goal_completion_audit_ready": v61ft,
    "v61ez_active_goal_post_ey_status_refresh_ready": v61ez,
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": v61fd,
    "v61fc_post_fb_dual_external_return_operator_packet_ready": v61fc,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v61fu requires {key}=1")

missing = {row["delta_id"]: as_int(row, "missing_count") for row in delta_rows}
active_goal_complete = as_int(v61ft, "active_goal_complete")
actual_model_generation_ready = as_int(v61fd, "actual_model_generation_ready")
generation_acceptance_closure_ready = as_int(v61fd, "generation_acceptance_closure_ready")
dual_external_return_real_ready = as_int(v61fd, "dual_external_return_real_ready")

frontier_requirement_rows = [
    {"requirement_id": "01-v52-f-optional-final-disposition", "status": "ready", "evidence": f"f_optional_final_disposition={v61ft.get('f_optional_final_disposition')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "02-v53-complete-source-machine-surface", "status": "ready", "evidence": f"repos={v61ft.get('complete_source_repo_count')}; queries={v61ft.get('complete_source_query_rows')}; answers={v61ft.get('core_answer_rows')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "03-v61-real-model-runtime-evidence", "status": "ready", "evidence": f"runtime={v61ft.get('post_full_shard_runtime_evidence_ready')}; page_hash={v61ft.get('full_safetensors_page_hash_binding_ready')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "04-v61-generation-return-packet", "status": "ready", "evidence": f"generation_return_packet_ready={v61ez.get('generation_return_packet_ready')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "05-v61-acceptance-handoff-bundle", "status": "ready", "evidence": f"acceptance_closure_handoff_bundle_ready={v61ez.get('acceptance_closure_handoff_bundle_ready')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "06-v61fd-delta-ledger", "status": "ready", "evidence": f"open_delta_rows={v61fd.get('open_delta_rows')}; ready_command_rows={v61fd.get('ready_command_rows')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "07-v61fc-dual-return-packet", "status": "ready", "evidence": f"dual_required_artifact_rows={v61fc.get('dual_required_artifact_rows')}; packet_file_rows={v61fc.get('packet_file_rows')}", "missing_delta": "0", "next_action": ""},
    {"requirement_id": "08-v53-external-return-artifacts", "status": "blocked", "evidence": "v61fd delta 01", "missing_delta": str(missing["01-v53-external-return-artifacts"]), "next_action": "supply the 81-artifact v53 external return root"},
    {"requirement_id": "09-v61-generation-intake-artifacts", "status": "blocked", "evidence": "v61fd delta 02", "missing_delta": str(missing["02-v61-generation-intake-artifacts"]), "next_action": "supply the 10-file v61 generation-intake return root"},
    {"requirement_id": "10-v53-human-review-rows", "status": "blocked", "evidence": "v61fd delta 03", "missing_delta": str(missing["03-v53-human-review-rows"]), "next_action": "return 7000 human/source review rows"},
    {"requirement_id": "11-v53-adjudication-rows", "status": "blocked", "evidence": "v61fd delta 04", "missing_delta": str(missing["04-v53-adjudication-rows"]), "next_action": "return 1000 adjudication rows"},
    {"requirement_id": "12-v61-generation-result-artifacts", "status": "blocked", "evidence": "v61fd delta 09", "missing_delta": str(missing["09-v61-generation-result-artifacts"]), "next_action": "return five real generation-result artifacts"},
    {"requirement_id": "13-v61-generation-result-rows", "status": "blocked", "evidence": "v61fd delta 10", "missing_delta": str(missing["10-v61-generation-result-rows"]), "next_action": "return 1000 accepted source-bound generation rows"},
    {"requirement_id": "14-v61-actual-model-generation", "status": status(actual_model_generation_ready), "evidence": f"actual_model_generation_ready={actual_model_generation_ready}", "missing_delta": str(missing["14-actual-generation-claim"]), "next_action": "close v61bt/v61de/v61cu acceptance before claiming actual generation"},
    {"requirement_id": "15-v1-latency-quality-release", "status": "blocked", "evidence": "near_frontier=0; production_latency=0; release=0", "missing_delta": "3", "next_action": "run latency, quality, and release audit only after actual generation"},
]
write_csv(run_dir / "external_return_closure_frontier_requirement_rows.csv", list(frontier_requirement_rows[0].keys()), frontier_requirement_rows)

frontier_delta_rows = [
    {
        "delta_id": row["delta_id"],
        "family": row["family"],
        "unit": row["unit"],
        "required_count": row["required_count"],
        "accepted_or_supplied_count": row["accepted_or_supplied_count"],
        "missing_count": row["missing_count"],
        "status": row["status"],
        "source_gate": row["source_gate"],
        "next_action": row["next_action"],
    }
    for row in delta_rows
]
write_csv(run_dir / "external_return_closure_frontier_delta_rows.csv", list(frontier_delta_rows[0].keys()), frontier_delta_rows)

frontier_action_rows = [
    {"action_id": "01-verify-v61fc-packet", "ready_to_run_now": "1", "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/VERIFY_DUAL_RETURN_PACKET.sh", "purpose": "verify the 91-artifact dual return packet"},
    {"action_id": "02-print-v61fc-ready-commands", "ready_to_run_now": "1", "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/READY_NOW_COMMANDS.sh", "purpose": "show metadata-only packet commands"},
    {"action_id": "03-verify-v61fd-delta-ledger", "ready_to_run_now": "1", "command": "results/v61fd_post_fc_real_return_closure_delta_ledger/ledger_001/real_return_closure_delta_ledger/VERIFY_DELTA_LEDGER.sh", "purpose": "verify delta ledger package"},
    {"action_id": "04-refresh-v61fu-frontier", "ready_to_run_now": "1", "command": "./experiments/run_v61fu_post_ft_external_return_closure_frontier.sh", "purpose": "refresh frontier after upstream evidence changes"},
    {"action_id": "05-run-dual-real-preflight", "ready_to_run_now": "0", "command": "V61FB_V53_RETURN_BUNDLE_DIR=<v53-return-root> V61FB_V53_RETURN_PROVENANCE=real-external-return-bundle V61FB_V61_RETURN_BUNDLE_DIR=<v61-return-root> V61FB_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle ./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh", "purpose": "requires real v53 and v61 return roots"},
    {"action_id": "06-replay-v53-return-acceptance", "ready_to_run_now": "0", "command": "V53AM_RETURN_BUNDLE_DIR=<v53-return-root> ./experiments/run_v53am_complete_source_return_acceptance_replay.sh", "purpose": "requires complete-source returned review bundle"},
    {"action_id": "07-replay-v61-generation-acceptance", "ready_to_run_now": "0", "command": "V61EV_RETURN_BUNDLE_DIR=<v61-return-root> ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh", "purpose": "requires real generation-intake return bundle"},
]
write_csv(run_dir / "external_return_closure_frontier_action_rows.csv", list(frontier_action_rows[0].keys()), frontier_action_rows)

metric_rows = [{
    "active_goal_complete": active_goal_complete,
    "v61ft_requirement_rows": as_int(v61ft, "requirement_rows"),
    "v61ft_pass_requirement_rows": as_int(v61ft, "pass_requirement_rows"),
    "v61ft_blocked_requirement_rows": as_int(v61ft, "blocked_requirement_rows"),
    "v61ez_requirement_rows": as_int(v61ez, "requirement_rows"),
    "v61ez_ready_requirement_rows": as_int(v61ez, "ready_requirement_rows"),
    "v61ez_blocked_requirement_rows": as_int(v61ez, "blocked_requirement_rows"),
    "v61fd_delta_rows": as_int(v61fd, "delta_rows"),
    "v61fd_open_delta_rows": as_int(v61fd, "open_delta_rows"),
    "v61fd_closed_delta_rows": as_int(v61fd, "closed_delta_rows"),
    "v53_required_artifact_rows": as_int(v61fd, "v53_required_artifact_rows"),
    "v61_required_artifact_rows": as_int(v61fd, "v61_required_artifact_rows"),
    "dual_required_artifact_rows": as_int(v61fd, "dual_required_artifact_rows"),
    "missing_external_return_artifacts": as_int(v61fd, "missing_external_return_artifacts"),
    "missing_human_review_rows": as_int(v61fd, "missing_human_review_rows"),
    "missing_adjudication_rows": as_int(v61fd, "missing_adjudication_rows"),
    "missing_reviewer_identity_rows": as_int(v61fd, "missing_reviewer_identity_rows"),
    "missing_conflict_disclosure_rows": as_int(v61fd, "missing_conflict_disclosure_rows"),
    "missing_generation_result_artifacts": as_int(v61fd, "missing_generation_result_artifacts"),
    "missing_generation_result_rows": as_int(v61fd, "missing_generation_result_rows"),
    "missing_generation_execution_admission_rows": as_int(v61fd, "missing_generation_execution_admission_rows"),
    "missing_final_acceptance_rows": as_int(v61fd, "missing_final_acceptance_rows"),
    "dual_external_return_real_ready": dual_external_return_real_ready,
    "generation_acceptance_closure_ready": generation_acceptance_closure_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "near_frontier_claim_ready": as_int(v61fd, "near_frontier_claim_ready"),
    "production_latency_claim_ready": as_int(v61fd, "production_latency_claim_ready"),
    "real_release_package_ready": as_int(v61fd, "real_release_package_ready"),
    "checkpoint_payload_bytes_downloaded_by_v61fu": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}]
write_csv(run_dir / "external_return_closure_frontier_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

copy_frontier(run_dir / "external_return_closure_frontier_requirement_rows.csv", "FRONTIER_REQUIREMENT_ROWS.csv")
copy_frontier(run_dir / "external_return_closure_frontier_delta_rows.csv", "FRONTIER_DELTA_ROWS.csv")
copy_frontier(run_dir / "external_return_closure_frontier_action_rows.csv", "FRONTIER_ACTION_ROWS.csv")

frontier_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "active_goal_complete": active_goal_complete,
    "requirement_rows": len(frontier_requirement_rows),
    "ready_requirement_rows": sum(row["status"] == "ready" for row in frontier_requirement_rows),
    "blocked_requirement_rows": sum(row["status"] == "blocked" for row in frontier_requirement_rows),
    "delta_rows": len(frontier_delta_rows),
    "open_delta_rows": sum(row["status"] == "open" for row in frontier_delta_rows),
    "ready_action_rows": sum(row["ready_to_run_now"] == "1" for row in frontier_action_rows),
    "blocked_action_rows": sum(row["ready_to_run_now"] == "0" for row in frontier_action_rows),
    "missing_external_return_artifacts": as_int(v61fd, "missing_external_return_artifacts"),
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(frontier_dir / "EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json").write_text(json.dumps(frontier_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(frontier_dir / "VERIFY_FRONTIER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json\"",
        "test -s \"$DIR/FRONTIER_REQUIREMENT_ROWS.csv\"",
        "test -s \"$DIR/FRONTIER_DELTA_ROWS.csv\"",
        "test -s \"$DIR/FRONTIER_ACTION_ROWS.csv\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in frontier package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(frontier_dir / "VERIFY_FRONTIER.sh").chmod(0o755)
(frontier_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61fu ready-now commands are verification/frontier refresh only; real closure requires v53/v61 external return roots.'",
        "echo 'results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/VERIFY_DUAL_RETURN_PACKET.sh'",
        "echo 'results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/READY_NOW_COMMANDS.sh'",
        "echo 'results/v61fd_post_fc_real_return_closure_delta_ledger/ledger_001/real_return_closure_delta_ledger/VERIFY_DELTA_LEDGER.sh'",
        "echo './experiments/run_v61fu_post_ft_external_return_closure_frontier.sh'",
        "",
    ]),
    encoding="utf-8",
)
(frontier_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)
(frontier_dir / "EXTERNAL_RETURN_CLOSURE_FRONTIER.md").write_text(
    "\n".join([
        "# v61fu external return closure frontier",
        "",
        f"- active_goal_complete={active_goal_complete}",
        f"- requirement_rows={len(frontier_requirement_rows)}",
        f"- ready_requirement_rows={frontier_manifest['ready_requirement_rows']}",
        f"- blocked_requirement_rows={frontier_manifest['blocked_requirement_rows']}",
        f"- delta_rows={len(frontier_delta_rows)}",
        f"- open_delta_rows={frontier_manifest['open_delta_rows']}",
        f"- missing_external_return_artifacts={frontier_manifest['missing_external_return_artifacts']}",
        f"- missing_human_review_rows={v61fd.get('missing_human_review_rows')}",
        f"- missing_adjudication_rows={v61fd.get('missing_adjudication_rows')}",
        f"- missing_generation_result_artifacts={v61fd.get('missing_generation_result_artifacts')}",
        f"- missing_generation_result_rows={v61fd.get('missing_generation_result_rows')}",
        "- actual_model_generation_ready=0",
        "",
        "This frontier does not close the active goal. It proves the next real work is external return evidence, not shard/page-hash/runtime evidence.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in frontier_dir.rglob("*") if path.is_file())
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
write_csv(run_dir / "external_return_closure_frontier_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61fu_post_ft_external_return_closure_frontier_ready": 1,
    "v61ft_active_goal_completion_audit_ready": 1,
    "v61ez_active_goal_post_ey_status_refresh_ready": 1,
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": 1,
    "v61fc_post_fb_dual_external_return_operator_packet_ready": 1,
    **metric_rows[0],
    "frontier_requirement_rows": len(frontier_requirement_rows),
    "ready_frontier_requirement_rows": sum(row["status"] == "ready" for row in frontier_requirement_rows),
    "blocked_frontier_requirement_rows": sum(row["status"] == "blocked" for row in frontier_requirement_rows),
    "frontier_delta_rows": len(frontier_delta_rows),
    "open_frontier_delta_rows": sum(row["status"] == "open" for row in frontier_delta_rows),
    "closed_frontier_delta_rows": sum(row["status"] == "closed" for row in frontier_delta_rows),
    "frontier_action_rows": len(frontier_action_rows),
    "ready_frontier_action_rows": sum(row["ready_to_run_now"] == "1" for row in frontier_action_rows),
    "blocked_frontier_action_rows": sum(row["ready_to_run_now"] == "0" for row in frontier_action_rows),
    "frontier_package_file_rows": len(file_rows),
    "metadata_only_frontier_package_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_frontier_package_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": 8,
    "source_artifact_file_rows": 6,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ft-active-goal-audit", "status": "pass", "actual_value": "ready", "required_value": "ready", "reason": "active-goal audit source exists"},
    {"gate": "v61ez-post-ey-status", "status": "pass", "actual_value": "ready", "required_value": "ready", "reason": "generation acceptance handoff status exists"},
    {"gate": "v61fd-delta-ledger", "status": "pass", "actual_value": f"open_delta_rows={v61fd.get('open_delta_rows')}", "required_value": "14 rows", "reason": "real-return closure deltas are enumerated"},
    {"gate": "v61fc-dual-return-packet", "status": "pass", "actual_value": f"dual_required_artifact_rows={v61fc.get('dual_required_artifact_rows')}", "required_value": "91 artifacts", "reason": "dual external return packet exists"},
    {"gate": "dual-external-return-real", "status": "blocked", "actual_value": str(dual_external_return_real_ready), "required_value": "1", "reason": "real v53/v61 return roots are missing"},
    {"gate": "v53-review-return", "status": "blocked", "actual_value": f"human_missing={v61fd.get('missing_human_review_rows')}; adjudication_missing={v61fd.get('missing_adjudication_rows')}", "required_value": "0 missing rows", "reason": "complete-source review return rows are missing"},
    {"gate": "v61-generation-result-return", "status": "blocked", "actual_value": f"artifacts_missing={v61fd.get('missing_generation_result_artifacts')}; rows_missing={v61fd.get('missing_generation_result_rows')}", "required_value": "0 missing rows", "reason": "real generation result evidence is missing"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "actual_value": str(generation_acceptance_closure_ready), "required_value": "1", "reason": "v61bt/v61de/v61cu acceptance rows remain open"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": str(actual_model_generation_ready), "required_value": "1", "reason": "actual model generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only frontier"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FU_POST_FT_EXTERNAL_RETURN_CLOSURE_FRONTIER_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V61FU Post-FT External Return Closure Frontier",
        "",
        "- v61fu_post_ft_external_return_closure_frontier_ready=1",
        f"- active_goal_complete={active_goal_complete}",
        f"- frontier_requirement_rows={summary['frontier_requirement_rows']}",
        f"- ready_frontier_requirement_rows={summary['ready_frontier_requirement_rows']}",
        f"- blocked_frontier_requirement_rows={summary['blocked_frontier_requirement_rows']}",
        f"- frontier_delta_rows={summary['frontier_delta_rows']}",
        f"- open_frontier_delta_rows={summary['open_frontier_delta_rows']}",
        f"- v53_required_artifact_rows={summary['v53_required_artifact_rows']}",
        f"- v61_required_artifact_rows={summary['v61_required_artifact_rows']}",
        f"- dual_required_artifact_rows={summary['dual_required_artifact_rows']}",
        f"- missing_external_return_artifacts={summary['missing_external_return_artifacts']}",
        f"- missing_human_review_rows={summary['missing_human_review_rows']}",
        f"- missing_adjudication_rows={summary['missing_adjudication_rows']}",
        f"- missing_reviewer_identity_rows={summary['missing_reviewer_identity_rows']}",
        f"- missing_conflict_disclosure_rows={summary['missing_conflict_disclosure_rows']}",
        f"- missing_generation_result_artifacts={summary['missing_generation_result_artifacts']}",
        f"- missing_generation_result_rows={summary['missing_generation_result_rows']}",
        f"- missing_generation_execution_admission_rows={summary['missing_generation_execution_admission_rows']}",
        f"- missing_final_acceptance_rows={summary['missing_final_acceptance_rows']}",
        f"- dual_external_return_real_ready={dual_external_return_real_ready}",
        f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
        f"- actual_model_generation_ready={actual_model_generation_ready}",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this frontier keeps the active goal incomplete. The next unlock is real external return evidence: 81 v53 artifacts plus 10 v61 generation-intake artifacts with explicit real provenance.",
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

print(f"v61fu_post_ft_external_return_closure_frontier_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
