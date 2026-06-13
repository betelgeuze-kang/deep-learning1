#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate"
RUN_ID="${V61FN_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_INTAKE_RUN_DIR_ARG="${V61FN_RETURN_INTAKE_RUN_DIR:-}"
HANDOFF_RUN_DIR_ARG="${V61FN_HANDOFF_RUN_DIR:-}"

if [[ "${V61FN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh" >/dev/null
V61FL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null
V61FE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_INTAKE_RUN_DIR_ARG" "$HANDOFF_RUN_DIR_ARG" <<'PY'
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
return_arg = sys.argv[5].strip()
handoff_arg = sys.argv[6].strip()
results = root / "results"
default_return_dir = results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001"
default_handoff_dir = results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard" / "guard_001"
return_dir = Path(return_arg).expanduser().resolve() if return_arg else default_return_dir
handoff_dir = Path(handoff_arg).expanduser().resolve() if handoff_arg else default_handoff_dir


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


def ready(flag):
    return "ready" if flag else "blocked"


sources = {
    "v61fm_summary": results / "v61fm_post_fl_real_manifest_external_review_return_work_order_summary.csv",
    "v61fm_decision": results / "v61fm_post_fl_real_manifest_external_review_return_work_order_decision.csv",
    "v61fh_summary": results / "v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
    "v61fh_decision": results / "v61fh_post_fg_real_manifest_external_review_return_intake_decision.csv",
    "v61fi_summary": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_summary.csv",
    "v61fi_decision": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_decision.csv",
    "v61fl_summary": results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_summary.csv",
    "v61fl_decision": results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_decision.csv",
    "v61fe_summary": results / "v61fe_post_fd_real_return_replay_admission_guard_summary.csv",
    "v61fe_decision": results / "v61fe_post_fd_real_return_replay_admission_guard_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fn source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_return_files = {
    "return_artifact_status_rows.csv": return_dir / "real_manifest_external_review_return_artifact_status_rows.csv",
    "return_acceptance_rows.csv": return_dir / "real_manifest_external_review_return_acceptance_rows.csv",
    "return_requirement_rows.csv": return_dir / "real_manifest_external_review_return_requirement_rows.csv",
    "return_manifest.json": return_dir / "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json",
}
for rel, path in selected_return_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61fn return artifact: {path}")
    copy(path, f"selected_return_intake/{rel}")

selected_handoff_files = {
    "handoff_metric_rows.csv": handoff_dir / "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv",
    "handoff_stage_rows.csv": handoff_dir / "post_fk_real_manifest_external_review_return_handoff_stage_rows.csv",
    "handoff_manifest.json": handoff_dir / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_manifest.json",
}
for rel, path in selected_handoff_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61fn handoff artifact: {path}")
    copy(path, f"selected_handoff/{rel}")

v61fm = read_csv(sources["v61fm_summary"])[0]
v61fi = read_csv(sources["v61fi_summary"])[0]
v61fl = read_csv(sources["v61fl_summary"])[0]
v61fe = read_csv(sources["v61fe_summary"])[0]
if v61fm.get("v61fm_post_fl_real_manifest_external_review_return_work_order_ready") != "1":
    raise SystemExit("v61fn requires v61fm readiness")
if v61fi.get("v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready") != "1":
    raise SystemExit("v61fn requires v61fi readiness")
if v61fl.get("v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready") != "1":
    raise SystemExit("v61fn requires v61fl readiness")
if v61fe.get("v61fe_post_fd_real_return_replay_admission_guard_ready") != "1":
    raise SystemExit("v61fn requires v61fe readiness")

return_manifest = json.loads((return_dir / "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json").read_text(encoding="utf-8"))
return_status_rows = read_csv(return_dir / "real_manifest_external_review_return_artifact_status_rows.csv")
handoff_metric = read_csv(handoff_dir / "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv")[0]

selected_return_source_class = "canonical-no-return"
if return_manifest.get("candidate_external_review_return_ready") == 1:
    selected_return_source_class = "candidate-preflight-only"
if return_manifest.get("external_review_return_ready") == 1:
    selected_return_source_class = "real-external-review-return"

selected_return_artifacts = len(return_status_rows)
selected_return_artifacts_preflight_pass = sum(row["artifact_preflight_pass"] == "1" for row in return_status_rows)
candidate_external_review_return_ready = int(return_manifest.get("candidate_external_review_return_ready", 0))
external_review_return_ready = int(return_manifest.get("external_review_return_ready", 0))
accepted_review_return_artifacts = int(return_manifest.get("accepted_review_return_artifacts", 0))
missing_review_return_artifacts = int(return_manifest.get("missing_review_return_artifacts", 0))
dispatch_receipt_candidate_preflight_ready = as_int(handoff_metric, "dispatch_receipt_candidate_preflight_ready")
real_dispatch_receipt_ready = as_int(handoff_metric, "real_dispatch_receipt_ready")
receipt_to_review_return_handoff_ready = int(real_dispatch_receipt_ready and external_review_return_ready)
acceptance_bridge_ready = as_int(v61fi, "external_review_return_ready")
real_return_replay_admission_ready = as_int(v61fe, "real_return_replay_admission_ready")
row_acceptance_ready = as_int(v61fe, "row_acceptance_ready")
actual_model_generation_ready = 0

stage_rows = [
    {"stage_id": "01-work-order-issued", "status": "ready", "ready": "1", "actual_value": f"work_order_rows={v61fm['work_order_rows']}", "blocking_reason": ""},
    {"stage_id": "02-return-intake-selected", "status": "ready", "ready": "1", "actual_value": str(return_dir), "blocking_reason": ""},
    {"stage_id": "03-return-candidate-preflight", "status": ready(candidate_external_review_return_ready), "ready": str(candidate_external_review_return_ready), "actual_value": f"candidate_external_review_return_ready={candidate_external_review_return_ready}", "blocking_reason": "" if candidate_external_review_return_ready else "no selected return passed candidate preflight"},
    {"stage_id": "04-external-review-return-accepted", "status": ready(external_review_return_ready), "ready": str(external_review_return_ready), "actual_value": f"external_review_return_ready={external_review_return_ready}", "blocking_reason": "" if external_review_return_ready else "candidate return is not certified real external review"},
    {"stage_id": "05-acceptance-bridge-refresh", "status": ready(acceptance_bridge_ready), "ready": str(acceptance_bridge_ready), "actual_value": f"v61fi.external_review_return_ready={acceptance_bridge_ready}", "blocking_reason": "" if acceptance_bridge_ready else "acceptance bridge remains blocked"},
    {"stage_id": "06-handoff-refresh", "status": ready(receipt_to_review_return_handoff_ready), "ready": str(receipt_to_review_return_handoff_ready), "actual_value": f"real_receipt={real_dispatch_receipt_ready}; external_review_return={external_review_return_ready}", "blocking_reason": "requires real receipt and accepted review return"},
    {"stage_id": "07-replay-admission", "status": ready(real_return_replay_admission_ready), "ready": str(real_return_replay_admission_ready), "actual_value": f"real_return_replay_admission_ready={real_return_replay_admission_ready}", "blocking_reason": "requires accepted real return roots"},
    {"stage_id": "08-row-acceptance", "status": ready(row_acceptance_ready), "ready": str(row_acceptance_ready), "actual_value": f"row_acceptance_ready={row_acceptance_ready}", "blocking_reason": "requires accepted replay rows"},
    {"stage_id": "09-generation-execution", "status": "blocked", "ready": "0", "actual_value": "generation_execution_admitted_rows=0", "blocking_reason": "generation execution not admitted"},
    {"stage_id": "10-actual-generation", "status": "blocked", "ready": "0", "actual_value": "actual_model_generation_ready=0", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "v61fm-work-order", "status": "pass", "required_value": "1", "actual_value": v61fm["v61fm_post_fl_real_manifest_external_review_return_work_order_ready"], "reason": "work order is ready"},
    {"requirement_id": "selected-return-intake", "status": "pass", "required_value": "1", "actual_value": "1", "reason": "selected return intake run exists"},
    {"requirement_id": "return-candidate-preflight", "status": status(candidate_external_review_return_ready), "required_value": "1", "actual_value": str(candidate_external_review_return_ready), "reason": "selected return must pass candidate preflight"},
    {"requirement_id": "external-review-return", "status": status(external_review_return_ready), "required_value": "1", "actual_value": str(external_review_return_ready), "reason": "candidate return is not enough"},
    {"requirement_id": "acceptance-bridge-refresh", "status": status(acceptance_bridge_ready), "required_value": "1", "actual_value": str(acceptance_bridge_ready), "reason": "v61fi remains blocked until real return is accepted"},
    {"requirement_id": "receipt-to-review-return-handoff", "status": status(receipt_to_review_return_handoff_ready), "required_value": "1", "actual_value": str(receipt_to_review_return_handoff_ready), "reason": "requires real receipt plus accepted review return"},
    {"requirement_id": "real-return-replay-admission", "status": status(real_return_replay_admission_ready), "required_value": "1", "actual_value": str(real_return_replay_admission_ready), "reason": "v61fe remains fail-closed"},
    {"requirement_id": "row-acceptance", "status": status(row_acceptance_ready), "required_value": "1", "actual_value": str(row_acceptance_ready), "reason": "row acceptance remains blocked"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
    {"requirement_id": "repo-checkpoint-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "metadata-only replay gate"},
]
write_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

command_rows = [
    {"command_id": "verify-work-order", "command": "V61FM_REUSE_EXISTING=1 ./experiments/test_v61fm_post_fl_real_manifest_external_review_return_work_order.sh", "ready_to_run_now": "1", "purpose": "verify work order and selected sources"},
    {"command_id": "run-return-intake", "command": "V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/real/review-return ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh", "ready_to_run_now": "0", "purpose": "requires real review-return root"},
    {"command_id": "refresh-acceptance-bridge", "command": "./experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh", "ready_to_run_now": str(external_review_return_ready), "purpose": "refresh v61fi after accepted review return"},
    {"command_id": "refresh-handoff-guard", "command": "./experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh", "ready_to_run_now": str(external_review_return_ready), "purpose": "refresh handoff after accepted review return"},
    {"command_id": "replay-real-return-admission", "command": "./experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh", "ready_to_run_now": str(real_return_replay_admission_ready), "purpose": "run only after real roots are supplied"},
    {"command_id": "run-generation-chain", "command": "run guarded generation only after replay, row acceptance, and generation-result evidence close", "ready_to_run_now": "0", "purpose": "generation remains blocked"},
]
write_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_command_rows.csv", list(command_rows[0].keys()), command_rows)

blocker_rows = [
    {"blocker_id": "candidate-return-preflight", "status": "closed" if candidate_external_review_return_ready else "open", "reason": "selected return intake candidate preflight"},
    {"blocker_id": "real-external-review-return", "status": "closed" if external_review_return_ready else "open", "reason": "requires non-fixture accepted external review decision"},
    {"blocker_id": "acceptance-bridge-refresh", "status": "closed" if acceptance_bridge_ready else "open", "reason": "v61fi external review acceptance bridge remains blocked"},
    {"blocker_id": "receipt-to-review-return-handoff", "status": "closed" if receipt_to_review_return_handoff_ready else "open", "reason": "requires real dispatch receipt and accepted review return"},
    {"blocker_id": "real-return-replay-admission", "status": "closed" if real_return_replay_admission_ready else "open", "reason": "v61fe fail-closed replay admission remains blocked"},
    {"blocker_id": "row-acceptance", "status": "closed" if row_acceptance_ready else "open", "reason": "row acceptance remains blocked"},
    {"blocker_id": "actual-generation", "status": "open", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
open_blocker_rows = sum(row["status"] == "open" for row in blocker_rows)
summary = {
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": "1",
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": v61fm["v61fm_post_fl_real_manifest_external_review_return_work_order_ready"],
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": v61fi["v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready"],
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": v61fl["v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready"],
    "v61fe_post_fd_real_return_replay_admission_guard_ready": v61fe["v61fe_post_fd_real_return_replay_admission_guard_ready"],
    "selected_return_source_class": selected_return_source_class,
    "selected_return_artifacts": str(selected_return_artifacts),
    "selected_return_artifacts_preflight_pass": str(selected_return_artifacts_preflight_pass),
    "candidate_external_review_return_ready": str(candidate_external_review_return_ready),
    "external_review_return_ready": str(external_review_return_ready),
    "accepted_review_return_artifacts": str(accepted_review_return_artifacts),
    "missing_review_return_artifacts": str(missing_review_return_artifacts),
    "dispatch_receipt_candidate_preflight_ready": str(dispatch_receipt_candidate_preflight_ready),
    "real_dispatch_receipt_ready": str(real_dispatch_receipt_ready),
    "receipt_to_review_return_handoff_ready": str(receipt_to_review_return_handoff_ready),
    "acceptance_bridge_refresh_ready": str(acceptance_bridge_ready),
    "real_return_replay_admission_ready": str(real_return_replay_admission_ready),
    "row_acceptance_ready": str(row_acceptance_ready),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(ready_stage_rows),
    "blocked_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "blocker_rows": str(len(blocker_rows)),
    "open_blocker_rows": str(open_blocker_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "blocked_command_rows": str(len(command_rows) - ready_command_rows),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_fm_real_manifest_external_review_acceptance_replay_metric_rows.csv", list(summary.keys()), [summary])
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["requirement_id"], "status": row["status"], "reason": row["reason"]}
    for row in requirement_rows
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FN_POST_FM_REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_REPLAY_GATE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fn Post-v61fm Real Manifest External Review Acceptance Replay Gate Boundary",
            "",
            f"- selected_return_source_class={summary['selected_return_source_class']}",
            f"- selected_return_artifacts_preflight_pass={summary['selected_return_artifacts_preflight_pass']}/{summary['selected_return_artifacts']}",
            f"- candidate_external_review_return_ready={summary['candidate_external_review_return_ready']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- receipt_to_review_return_handoff_ready={summary['receipt_to_review_return_handoff_ready']}",
            f"- acceptance_bridge_refresh_ready={summary['acceptance_bridge_refresh_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fn replays the review-return acceptance boundary without accepting candidate or fixture evidence as real.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fn alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
