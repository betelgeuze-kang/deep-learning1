#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ek_preflight_to_generation_intake_handoff_guard"
RUN_ID="${V61EK_RUN_ID:-guard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PREFLIGHT_RUN_DIR_ARG="${V61EK_PREFLIGHT_RUN_DIR:-}"

if [[ "${V61EK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ek_preflight_to_generation_intake_handoff_guard_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
V61EH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eh_real_generation_result_return_packet.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PREFLIGHT_RUN_DIR_ARG" <<'PY'
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
preflight_arg = sys.argv[5].strip()
results = root / "results"
default_preflight_dir = results / "v61ej_real_generation_return_receiver_preflight" / "preflight_001"
selected_preflight_dir = Path(preflight_arg).expanduser().resolve() if preflight_arg else default_preflight_dir


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


def ready_status(flag):
    return "ready" if flag else "blocked"


def pass_status(flag):
    return "pass" if flag else "blocked"


source_files = {
    "v61ej_summary": results / "v61ej_real_generation_return_receiver_preflight_summary.csv",
    "v61ej_decision": results / "v61ej_real_generation_return_receiver_preflight_decision.csv",
    "v61eh_summary": results / "v61eh_real_generation_result_return_packet_summary.csv",
    "v61eh_decision": results / "v61eh_real_generation_result_return_packet_decision.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
}
for key, path in source_files.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ek source {key}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_metric_path = selected_preflight_dir / "receiver_preflight_metric_rows.csv"
selected_artifact_path = selected_preflight_dir / "receiver_preflight_artifact_rows.csv"
selected_query_path = selected_preflight_dir / "receiver_preflight_query_rows.csv"
for path in [selected_metric_path, selected_artifact_path, selected_query_path]:
    if not path.is_file():
        raise SystemExit(f"missing selected v61ej preflight artifact: {path}")
copy(selected_metric_path, "selected_preflight/receiver_preflight_metric_rows.csv")
copy(selected_artifact_path, "selected_preflight/receiver_preflight_artifact_rows.csv")
copy(selected_query_path, "selected_preflight/receiver_preflight_query_rows.csv")

v61ej = read_csv(source_files["v61ej_summary"])[0]
v61eh = read_csv(source_files["v61eh_summary"])[0]
v61bt = read_csv(source_files["v61bt_summary"])[0]
v61de = read_csv(source_files["v61de_summary"])[0]
selected_metric = read_csv(selected_metric_path)[0]

selected_preflight_ready = as_int(selected_metric, "generation_result_receiver_preflight_ready")
real_prerequisite_binding_ready = as_int(v61eh, "real_prerequisite_binding_ready")
real_review_return_ready = as_int(v61eh, "real_review_return_ready")
real_generation_execution_admission_ready = as_int(v61eh, "real_generation_execution_admission_ready")
v61bt_handoff_ready = int(selected_preflight_ready and real_prerequisite_binding_ready)
v61de_handoff_ready = int(selected_preflight_ready and real_prerequisite_binding_ready and real_review_return_ready)
acceptance_refresh_ready = int(v61bt_handoff_ready and v61de_handoff_ready)

stage_rows = [
    {
        "stage_id": "01-v61ej-preflight-input",
        "status": "ready",
        "ready": "1",
        "evidence_source": "v61ej",
        "actual_value": v61ej["v61ej_real_generation_return_receiver_preflight_ready"],
        "blocking_reason": "",
    },
    {
        "stage_id": "02-selected-preflight-result",
        "status": ready_status(selected_preflight_ready),
        "ready": str(selected_preflight_ready),
        "evidence_source": "selected v61ej run",
        "actual_value": f"{selected_metric['preflight_pass_generation_result_artifacts']}/{selected_metric['expected_generation_result_artifacts']} artifacts; {selected_metric['receiver_preflight_query_pass_rows']}/{selected_metric['receiver_preflight_query_rows']} queries",
        "blocking_reason": "" if selected_preflight_ready else "returned generation-result directory has not passed receiver preflight",
    },
    {
        "stage_id": "03-real-prerequisite-binding",
        "status": ready_status(real_prerequisite_binding_ready),
        "ready": str(real_prerequisite_binding_ready),
        "evidence_source": "v61eh",
        "actual_value": v61eh["real_prerequisite_binding_ready"],
        "blocking_reason": "" if real_prerequisite_binding_ready else "real review return and generation execution admission are not ready",
    },
    {
        "stage_id": "04-v61bt-intake-handoff",
        "status": ready_status(v61bt_handoff_ready),
        "ready": str(v61bt_handoff_ready),
        "evidence_source": "v61ej/v61eh",
        "actual_value": f"preflight={selected_preflight_ready}; real_prerequisite_binding={real_prerequisite_binding_ready}",
        "blocking_reason": "" if v61bt_handoff_ready else "requires both receiver preflight and real prerequisite binding",
    },
    {
        "stage_id": "05-v61de-post-review-handoff",
        "status": ready_status(v61de_handoff_ready),
        "ready": str(v61de_handoff_ready),
        "evidence_source": "v61ej/v61eh",
        "actual_value": f"preflight={selected_preflight_ready}; binding={real_prerequisite_binding_ready}; review={real_review_return_ready}",
        "blocking_reason": "" if v61de_handoff_ready else "requires preflight, real prerequisite binding, and real review return",
    },
    {
        "stage_id": "06-actual-generation-acceptance",
        "status": "blocked",
        "ready": "0",
        "evidence_source": "v61bt/v61de",
        "actual_value": f"v61bt_actual={v61bt['actual_model_generation_ready']}; v61de_actual={v61de['actual_model_generation_ready']}",
        "blocking_reason": "not accepted actual generation",
    },
]
write_csv(run_dir / "preflight_to_generation_intake_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {
        "command_id": "verify-selected-v61ej-preflight",
        "command": "V61EJ_REUSE_EXISTING=1 ./experiments/test_v61ej_real_generation_return_receiver_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "verify the receiver preflight mechanics and canonical restoration",
    },
    {
        "command_id": "run-v61bt-intake-after-preflight-and-binding",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(v61bt_handoff_ready),
        "purpose": "accept real generation-result artifacts only after preflight and prerequisite binding",
    },
    {
        "command_id": "run-v61de-handoff-after-preflight-and-binding",
        "command": "V61DE_REUSE_EXISTING=0 V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": str(v61de_handoff_ready),
        "purpose": "refresh post-review generation handoff over real returned artifacts",
    },
    {
        "command_id": "refresh-v61cu-generation-result-acceptance",
        "command": "V61CU_REUSE_EXISTING=0 ./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh",
        "ready_to_run_now": str(acceptance_refresh_ready),
        "purpose": "promote accepted generation rows after v61bt/v61de real intake",
    },
    {
        "command_id": "audit-post-intake-claims",
        "command": "./experiments/test_v61ei_active_goal_post_eh_status_refresh.sh",
        "ready_to_run_now": "1",
        "purpose": "confirm active-goal claims remain boundary-correct",
    },
]
write_csv(run_dir / "preflight_to_generation_intake_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {"requirement_id": "v61ej-preflight-input", "status": "pass", "required_value": "1", "actual_value": v61ej["v61ej_real_generation_return_receiver_preflight_ready"], "reason": "v61ej preflight gate is bound"},
    {"requirement_id": "selected-preflight-ready", "status": pass_status(selected_preflight_ready), "required_value": "1", "actual_value": str(selected_preflight_ready), "reason": "selected returned generation-result directory must pass preflight"},
    {"requirement_id": "real-prerequisite-binding", "status": pass_status(real_prerequisite_binding_ready), "required_value": "1", "actual_value": str(real_prerequisite_binding_ready), "reason": "fixture binding is not accepted as real prerequisite binding"},
    {"requirement_id": "v61bt-intake-handoff-ready", "status": pass_status(v61bt_handoff_ready), "required_value": "1", "actual_value": str(v61bt_handoff_ready), "reason": "requires selected preflight and real prerequisite binding"},
    {"requirement_id": "v61de-handoff-ready", "status": pass_status(v61de_handoff_ready), "required_value": "1", "actual_value": str(v61de_handoff_ready), "reason": "requires preflight, real binding, and real review return"},
    {"requirement_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "handoff guard is not a generation acceptance gate"},
]
write_csv(run_dir / "preflight_to_generation_intake_handoff_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
blocked_stage_rows = len(stage_rows) - ready_stage_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)

summary = {
    "v61ek_preflight_to_generation_intake_handoff_guard_ready": "1",
    "v61ej_real_generation_return_receiver_preflight_ready": v61ej["v61ej_real_generation_return_receiver_preflight_ready"],
    "v61eh_real_generation_result_return_packet_ready": v61eh["v61eh_real_generation_result_return_packet_ready"],
    "selected_preflight_run_dir_supplied": str(int(bool(preflight_arg))),
    "selected_preflight_run_dir": str(selected_preflight_dir),
    "selected_generation_result_receiver_preflight_ready": str(selected_preflight_ready),
    "selected_preflight_pass_generation_result_artifacts": selected_metric["preflight_pass_generation_result_artifacts"],
    "selected_expected_generation_result_artifacts": selected_metric["expected_generation_result_artifacts"],
    "selected_receiver_preflight_query_pass_rows": selected_metric["receiver_preflight_query_pass_rows"],
    "selected_receiver_preflight_query_rows": selected_metric["receiver_preflight_query_rows"],
    "real_prerequisite_binding_ready": str(real_prerequisite_binding_ready),
    "real_review_return_ready": str(real_review_return_ready),
    "real_generation_execution_admission_ready": str(real_generation_execution_admission_ready),
    "v61bt_intake_handoff_ready": str(v61bt_handoff_ready),
    "v61de_generation_result_handoff_ready": str(v61de_handoff_ready),
    "acceptance_refresh_ready": str(acceptance_refresh_ready),
    "handoff_stage_rows": str(len(stage_rows)),
    "ready_handoff_stage_rows": str(ready_stage_rows),
    "blocked_handoff_stage_rows": str(blocked_stage_rows),
    "handoff_command_rows": str(len(command_rows)),
    "ready_handoff_command_rows": str(ready_command_rows),
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ek": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ej-preflight-input", "status": "pass", "reason": "v61ej gate is bound"},
    {"gate": "selected-preflight-ready", "status": pass_status(selected_preflight_ready), "reason": f"preflight={selected_preflight_ready}"},
    {"gate": "real-prerequisite-binding", "status": pass_status(real_prerequisite_binding_ready), "reason": f"real_prerequisite_binding_ready={real_prerequisite_binding_ready}"},
    {"gate": "v61bt-intake-handoff", "status": pass_status(v61bt_handoff_ready), "reason": f"preflight={selected_preflight_ready}; binding={real_prerequisite_binding_ready}"},
    {"gate": "v61de-generation-result-handoff", "status": pass_status(v61de_handoff_ready), "reason": f"preflight={selected_preflight_ready}; binding={real_prerequisite_binding_ready}; review={real_review_return_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "handoff guard does not accept generation"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only guard"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = f"""# v61ek Preflight to Generation Intake Handoff Guard

This guard connects a selected v61ej receiver preflight result to the v61bt and
v61de intake commands. It does not run intake and does not accept generation.
Preflight success alone is insufficient: real prerequisite binding and real
review return must also be ready.

- selected_generation_result_receiver_preflight_ready={selected_preflight_ready}
- selected_preflight_pass_generation_result_artifacts={selected_metric['preflight_pass_generation_result_artifacts']}/{selected_metric['expected_generation_result_artifacts']}
- selected_receiver_preflight_query_pass_rows={selected_metric['receiver_preflight_query_pass_rows']}/{selected_metric['receiver_preflight_query_rows']}
- real_prerequisite_binding_ready={real_prerequisite_binding_ready}
- real_review_return_ready={real_review_return_ready}
- v61bt_intake_handoff_ready={v61bt_handoff_ready}
- v61de_generation_result_handoff_ready={v61de_handoff_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ek=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: preflight-to-intake handoff commands are guarded.
Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61EK_PREFLIGHT_TO_GENERATION_INTAKE_HANDOFF_GUARD_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ek_preflight_to_generation_intake_handoff_guard",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ek_preflight_to_generation_intake_handoff_guard_ready": 1,
    "selected_generation_result_receiver_preflight_ready": selected_preflight_ready,
    "real_prerequisite_binding_ready": real_prerequisite_binding_ready,
    "v61bt_intake_handoff_ready": v61bt_handoff_ready,
    "v61de_generation_result_handoff_ready": v61de_handoff_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ek": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ek_preflight_to_generation_intake_handoff_guard_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ek_preflight_to_generation_intake_handoff_guard_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
