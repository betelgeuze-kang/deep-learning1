#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53z_complete_source_review_return_v61_handoff_bridge"
RUN_ID="${V53Z_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
CHUNK_RETURN_DIR="${V53Z_REVIEW_CHUNK_RETURN_DIR:-}"
REVIEW_RETURN_DIR="${V53Z_REVIEW_RETURN_DIR:-}"

if [[ "${V53Z_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53z_complete_source_review_return_v61_handoff_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null
if [[ -n "$CHUNK_RETURN_DIR" ]]; then
  V53X_REVIEW_CHUNK_RETURN_DIR="$CHUNK_RETURN_DIR" V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
else
  V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
fi
if [[ -n "$REVIEW_RETURN_DIR" ]]; then
  V53Y_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
  V61DD_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V61DD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null
else
  V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
  V61DD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$CHUNK_RETURN_DIR" "$REVIEW_RETURN_DIR" <<'PY'
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
chunk_return_arg = sys.argv[5]
review_return_arg = sys.argv[6]
chunk_return_dir = Path(chunk_return_arg).expanduser().resolve() if chunk_return_arg else None
review_return_dir = Path(review_return_arg).expanduser().resolve() if review_return_arg else None
results = root / "results"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)


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


def status(flag):
    return "pass" if flag else "blocked"


summary_paths = {
    "v53w": results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv",
    "v53x": results / "v53x_complete_source_review_chunk_return_intake_summary.csv",
    "v53y": results / "v53y_complete_source_review_return_refresh_gate_summary.csv",
    "v61dd": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
}
decision_paths = {
    "v53w": results / "v53w_complete_source_review_return_chunk_execution_queue_decision.csv",
    "v53x": results / "v53x_complete_source_review_chunk_return_intake_decision.csv",
    "v53y": results / "v53y_complete_source_review_return_refresh_gate_decision.csv",
    "v61dd": results / "v61dd_review_return_generation_refresh_bridge_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for name, ready_field in [
    ("v53w", "v53w_complete_source_review_return_chunk_execution_queue_ready"),
    ("v53x", "v53x_complete_source_review_chunk_return_intake_ready"),
    ("v53y", "v53y_complete_source_review_return_refresh_gate_ready"),
    ("v61dd", "v61dd_review_return_generation_refresh_bridge_ready"),
]:
    if summaries[name].get(ready_field) != "1":
        raise SystemExit(f"v53z requires {ready_field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

source_files = [
    ("v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_execution_rows.csv", "source_v53w/review_return_chunk_execution_rows.csv"),
    ("v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_artifact_rows.csv", "source_v53w/review_return_chunk_artifact_rows.csv"),
    ("v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_aggregate_artifact_rows.csv", "source_v53w/review_return_aggregate_artifact_rows.csv"),
    ("v53x_complete_source_review_chunk_return_intake/intake_001/review_return_chunk_artifact_status_rows.csv", "source_v53x/review_return_chunk_artifact_status_rows.csv"),
    ("v53x_complete_source_review_chunk_return_intake/intake_001/review_return_aggregate_artifact_status_rows.csv", "source_v53x/review_return_aggregate_artifact_status_rows.csv"),
    ("v53y_complete_source_review_return_refresh_gate/refresh_001/complete_source_review_return_refresh_stage_rows.csv", "source_v53y/complete_source_review_return_refresh_stage_rows.csv"),
    ("v53y_complete_source_review_return_refresh_gate/refresh_001/runtime_gap_rows.csv", "source_v53y/runtime_gap_rows.csv"),
    ("v61dd_review_return_generation_refresh_bridge/bridge_001/review_return_generation_refresh_stage_rows.csv", "source_v61dd/review_return_generation_refresh_stage_rows.csv"),
    ("v61dd_review_return_generation_refresh_bridge/bridge_001/runtime_gap_rows.csv", "source_v61dd/runtime_gap_rows.csv"),
]
for src_rel, dst_rel in source_files:
    copy(results / src_rel, dst_rel)

v53w = summaries["v53w"]
v53x = summaries["v53x"]
v53y = summaries["v53y"]
v61dd = summaries["v61dd"]

chunk_return_dir_supplied = int(chunk_return_dir is not None)
chunk_return_dir_exists = int(chunk_return_dir is not None and chunk_return_dir.is_dir())
review_return_dir_supplied = int(review_return_dir is not None)
review_return_dir_exists = int(review_return_dir is not None and review_return_dir.is_dir())

machine_surface_ready = as_int(v53y, "machine_complete_source_surface_ready")
chunk_dispatch_ready = as_int(v53w, "chunk_dispatch_ready")
full_shard_runtime_ready = int(
    as_int(v61dd, "full_shard_prerequisites_closed")
    and as_int(v61dd, "complete_source_runtime_admission_execution_ready")
)
chunk_return_ready = as_int(v53x, "chunk_return_intake_ready")
aggregate_review_ready = as_int(v53x, "aggregate_review_return_ready") and as_int(v53y, "review_return_ready")
v61_review_unblock_ready = as_int(v61dd, "v61_review_unblock_ready")
actual_generation_ready = as_int(v61dd, "actual_model_generation_ready")

stage_rows = [
    {
        "handoff_stage_id": "01-machine-complete-source-surface",
        "source_gate": "v53y",
        "stage_status": "ready" if machine_surface_ready else "blocked",
        "expected_return": "machine_complete_source_surface_ready=1",
        "actual_return": f"machine_complete_source_surface_ready={machine_surface_ready}",
        "blocking_reason": "ready" if machine_surface_ready else "machine complete-source audit surface incomplete",
    },
    {
        "handoff_stage_id": "02-review-chunk-dispatch-surface",
        "source_gate": "v53w",
        "stage_status": "ready" if chunk_dispatch_ready else "blocked",
        "expected_return": "ready_review_chunk_dispatch_rows=21",
        "actual_return": f"ready_review_chunk_dispatch_rows={v53w['ready_review_chunk_dispatch_rows']}/{v53w['review_chunk_rows']}",
        "blocking_reason": "ready" if chunk_dispatch_ready else "review chunks are not dispatch-ready",
    },
    {
        "handoff_stage_id": "03-full-shard-runtime-prerequisites",
        "source_gate": "v61dd",
        "stage_status": "ready" if full_shard_runtime_ready else "blocked",
        "expected_return": "full_shard_prerequisites_closed=1 and runtime_admission_accepted_rows=1000",
        "actual_return": f"full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}",
        "blocking_reason": "ready" if full_shard_runtime_ready else "full-shard/runtime prerequisites are incomplete",
    },
    {
        "handoff_stage_id": "04-review-chunk-return-intake",
        "source_gate": "v53x",
        "stage_status": "ready" if chunk_return_ready else "blocked",
        "expected_return": "accepted_chunk_return_artifact_rows=50",
        "actual_return": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}",
        "blocking_reason": "ready" if chunk_return_ready else "review chunk return artifacts are missing or invalid",
    },
    {
        "handoff_stage_id": "05-aggregate-review-return",
        "source_gate": "v53x/v53y",
        "stage_status": "ready" if aggregate_review_ready else "blocked",
        "expected_return": "answer_review_accepted_rows=7000",
        "actual_return": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}",
        "blocking_reason": "ready" if aggregate_review_ready else "aggregate review return is not accepted",
    },
    {
        "handoff_stage_id": "06-v61-review-unblock",
        "source_gate": "v61dd",
        "stage_status": "ready" if v61_review_unblock_ready else "blocked",
        "expected_return": "v61_review_unblock_ready=1",
        "actual_return": f"v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}",
        "blocking_reason": "ready" if v61_review_unblock_ready else "v61 remains blocked by review return",
    },
    {
        "handoff_stage_id": "07-actual-generation-ready",
        "source_gate": "v61dd",
        "stage_status": "ready" if actual_generation_ready else "blocked",
        "expected_return": "actual_model_generation_ready=1",
        "actual_return": f"actual_model_generation_ready={v61dd['actual_model_generation_ready']}",
        "blocking_reason": "ready" if actual_generation_ready else "actual generation remains unproven",
    },
]
write_csv(run_dir / "review_return_v61_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(1 for row in stage_rows if row["stage_status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

command_rows = [
    {
        "command_id": "verify-v53z-handoff-bridge",
        "command": "results/v53z_complete_source_review_return_v61_handoff_bridge/bridge_001/operator_bundle/VERIFY_REVIEW_RETURN_V61_HANDOFF.sh",
        "ready_to_run_now": "1",
        "expected_return": "v53z handoff shape verified",
    },
    {
        "command_id": "dispatch-review-chunks",
        "command": "results/v53w_complete_source_review_return_chunk_execution_queue/queue_001/operator_bundle/VERIFY_CHUNK_QUEUE.sh",
        "ready_to_run_now": str(chunk_dispatch_ready),
        "expected_return": "21 review chunks are dispatch-ready",
    },
    {
        "command_id": "intake-review-chunk-returns",
        "command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/v53_review_chunk_return V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
        "ready_to_run_now": str(chunk_return_dir_exists),
        "expected_return": "50 chunk return artifacts accepted",
    },
    {
        "command_id": "refresh-aggregate-review-return",
        "command": "V53Y_REVIEW_RETURN_DIR=/path/to/v53_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "ready_to_run_now": str(review_return_dir_exists),
        "expected_return": "7000 answer reviews and 1000 adjudications accepted",
    },
    {
        "command_id": "refresh-v61-after-review-return",
        "command": "V61DD_REVIEW_RETURN_DIR=/path/to/v53_review_return V61DD_REUSE_EXISTING=0 ./experiments/run_v61dd_review_return_generation_refresh_bridge.sh",
        "ready_to_run_now": str(review_return_dir_exists),
        "expected_return": "v61 review blocker refreshes after accepted review return",
    },
]
write_csv(run_dir / "review_return_v61_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

requirement_rows = [
    {"requirement_id": "machine-complete-source-surface", "status": status(machine_surface_ready), "required_value": "1", "actual_value": str(machine_surface_ready), "reason": "v53 machine complete-source audit surface must be present"},
    {"requirement_id": "review-chunk-dispatch-surface", "status": status(chunk_dispatch_ready), "required_value": "21", "actual_value": v53w["ready_review_chunk_dispatch_rows"], "reason": "external review chunks must be dispatchable"},
    {"requirement_id": "full-shard-runtime-prerequisites", "status": status(full_shard_runtime_ready), "required_value": "1", "actual_value": str(full_shard_runtime_ready), "reason": "v61 full-shard/runtime state must stay closed"},
    {"requirement_id": "review-chunk-return-directory", "status": status(chunk_return_dir_exists), "required_value": "existing chunk return directory", "actual_value": str(chunk_return_dir) if chunk_return_dir else "", "reason": "external chunk return path is optional but required for chunk intake"},
    {"requirement_id": "review-chunk-return-accepted", "status": status(chunk_return_ready), "required_value": v53x["review_chunk_return_artifact_rows"], "actual_value": v53x["accepted_chunk_return_artifact_rows"], "reason": "v53x must accept all review chunk artifacts"},
    {"requirement_id": "aggregate-review-return-directory", "status": status(review_return_dir_exists), "required_value": "existing aggregate review return directory", "actual_value": str(review_return_dir) if review_return_dir else "", "reason": "v53y/v61dd require aggregate review returns"},
    {"requirement_id": "aggregate-review-return-accepted", "status": status(aggregate_review_ready), "required_value": v53y["expected_human_review_rows"], "actual_value": v53y["answer_review_accepted_rows"], "reason": "v53y must accept 7000 answer review rows before v61 can unblock"},
    {"requirement_id": "v61-review-unblock", "status": status(v61_review_unblock_ready), "required_value": "1", "actual_value": v61dd["v61_review_unblock_ready"], "reason": "v61 actual-generation path remains review-gated"},
    {"requirement_id": "actual-generation-ready", "status": status(actual_generation_ready), "required_value": "1", "actual_value": v61dd["actual_model_generation_ready"], "reason": "actual generation requires review, execution, and result acceptance"},
]
write_csv(run_dir / "review_return_v61_handoff_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "machine-complete-source-surface", "status": "ready" if machine_surface_ready else "blocked", "reason": f"machine_complete_source_surface_ready={machine_surface_ready}"},
    {"gap": "review-chunk-dispatch-surface", "status": "ready" if chunk_dispatch_ready else "blocked", "reason": f"ready_review_chunk_dispatch_rows={v53w['ready_review_chunk_dispatch_rows']}/{v53w['review_chunk_rows']}"},
    {"gap": "full-shard-runtime-prerequisites", "status": "ready" if full_shard_runtime_ready else "blocked", "reason": f"full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}"},
    {"gap": "review-chunk-return-directory", "status": "ready" if chunk_return_dir_exists else "blocked", "reason": f"chunk_return_dir_supplied={chunk_return_dir_supplied}; chunk_return_dir_exists={chunk_return_dir_exists}"},
    {"gap": "review-chunk-return-accepted", "status": "ready" if chunk_return_ready else "blocked", "reason": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}"},
    {"gap": "aggregate-review-return-directory", "status": "ready" if review_return_dir_exists else "blocked", "reason": f"review_return_dir_supplied={review_return_dir_supplied}; review_return_dir_exists={review_return_dir_exists}"},
    {"gap": "aggregate-review-return-accepted", "status": "ready" if aggregate_review_ready else "blocked", "reason": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}"},
    {"gap": "v61-review-unblock", "status": "ready" if v61_review_unblock_ready else "blocked", "reason": f"v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}"},
    {"gap": "actual-generation-ready", "status": "ready" if actual_generation_ready else "blocked", "reason": f"actual_model_generation_ready={v61dd['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53z_complete_source_review_return_v61_handoff_bridge_metrics",
    "model_id": v61dd["model_id"],
    "chunk_return_dir_supplied": str(chunk_return_dir_supplied),
    "chunk_return_dir_exists": str(chunk_return_dir_exists),
    "review_return_dir_supplied": str(review_return_dir_supplied),
    "review_return_dir_exists": str(review_return_dir_exists),
    "v53w_complete_source_review_return_chunk_execution_queue_ready": v53w["v53w_complete_source_review_return_chunk_execution_queue_ready"],
    "v53x_complete_source_review_chunk_return_intake_ready": v53x["v53x_complete_source_review_chunk_return_intake_ready"],
    "v53y_complete_source_review_return_refresh_gate_ready": v53y["v53y_complete_source_review_return_refresh_gate_ready"],
    "v61dd_review_return_generation_refresh_bridge_ready": v61dd["v61dd_review_return_generation_refresh_bridge_ready"],
    "handoff_stage_rows": str(len(stage_rows)),
    "ready_handoff_stage_rows": str(ready_stage_rows),
    "blocked_handoff_stage_rows": str(blocked_stage_rows),
    "handoff_command_rows": str(len(command_rows)),
    "ready_handoff_command_rows": str(ready_command_rows),
    "machine_complete_source_surface_ready": v53y["machine_complete_source_surface_ready"],
    "review_chunk_rows": v53w["review_chunk_rows"],
    "ready_review_chunk_dispatch_rows": v53w["ready_review_chunk_dispatch_rows"],
    "review_chunk_task_rows": v53w["review_chunk_task_rows"],
    "review_chunk_return_artifact_rows": v53x["review_chunk_return_artifact_rows"],
    "accepted_chunk_return_artifact_rows": v53x["accepted_chunk_return_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53x["aggregate_review_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53x["accepted_aggregate_review_return_artifact_rows"],
    "expected_human_review_rows": v53y["expected_human_review_rows"],
    "accepted_human_review_rows": v53y["accepted_human_review_rows"],
    "expected_adjudication_rows": v53y["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53y["accepted_adjudication_rows"],
    "answer_review_accepted_rows": v53y["answer_review_accepted_rows"],
    "review_return_ready": v53y["review_return_ready"],
    "v61_review_unblock_ready": v61dd["v61_review_unblock_ready"],
    "full_shard_prerequisites_closed": v61dd["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v61dd["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61dd["complete_source_runtime_admission_execution_ready"],
    "generation_execution_admission_rows": v61dd["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61dd["generation_execution_admitted_rows"],
    "generation_result_acceptance_rows": v61dd["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v61dd["generation_result_accepted_rows"],
    "actual_model_generation_ready_rows": v61dd["actual_model_generation_ready_rows"],
    "actual_model_generation_ready": v61dd["actual_model_generation_ready"],
    "v53_ready": v53y["v53_ready"],
    "v1_0_comparison_ready": v53y["v1_0_comparison_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53z": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "review_return_v61_handoff_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "machine-complete-source-surface", "status": status(machine_surface_ready), "reason": f"machine_complete_source_surface_ready={machine_surface_ready}"},
    {"gate": "review-chunk-dispatch-surface", "status": status(chunk_dispatch_ready), "reason": f"ready_review_chunk_dispatch_rows={v53w['ready_review_chunk_dispatch_rows']}/{v53w['review_chunk_rows']}"},
    {"gate": "full-shard-runtime-prerequisites", "status": status(full_shard_runtime_ready), "reason": f"full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}"},
    {"gate": "review-chunk-return-directory", "status": status(chunk_return_dir_exists), "reason": f"chunk_return_dir_exists={chunk_return_dir_exists}"},
    {"gate": "review-chunk-return-accepted", "status": status(chunk_return_ready), "reason": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}"},
    {"gate": "aggregate-review-return-directory", "status": status(review_return_dir_exists), "reason": f"review_return_dir_exists={review_return_dir_exists}"},
    {"gate": "aggregate-review-return-accepted", "status": status(aggregate_review_ready), "reason": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}"},
    {"gate": "v61-review-unblock", "status": status(v61_review_unblock_ready), "reason": f"v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}"},
    {"gate": "actual-model-generation", "status": status(actual_generation_ready), "reason": f"actual_model_generation_ready={v61dd['actual_model_generation_ready']}"},
    {"gate": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53y['v53_ready']}"},
    {"gate": "v1.0-comparison-ready", "status": "blocked", "reason": f"v1_0_comparison_ready={v53y['v1_0_comparison_ready']}"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

(operator_dir / "README.md").write_text(
    "# v53z Complete-Source Review Return to v61 Handoff Bridge\n\n"
    "This bundle ties the v53 review-return execution path to the v61 actual-generation refresh path. "
    "It does not create review judgments, generation results, latency rows, quality claims, or release evidence.\n",
    encoding="utf-8",
)
verify_script = operator_dir / "VERIFY_REVIEW_RETURN_V61_HANDOFF.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/review_return_v61_handoff_stage_rows.csv"
  "$BUNDLE_DIR/review_return_v61_handoff_command_rows.csv"
  "$BUNDLE_DIR/review_return_v61_handoff_requirement_rows.csv"
  "$BUNDLE_DIR/review_return_v61_handoff_metric_rows.csv"
  "$BUNDLE_DIR/runtime_gap_rows.csv"
  "$BUNDLE_DIR/source_v53w/review_return_chunk_execution_rows.csv"
  "$BUNDLE_DIR/source_v53x/review_return_chunk_artifact_status_rows.csv"
  "$BUNDLE_DIR/source_v53y/complete_source_review_return_refresh_stage_rows.csv"
  "$BUNDLE_DIR/source_v61dd/review_return_generation_refresh_stage_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53z handoff bridge file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/review_return_v61_handoff_stage_rows.csv" | tr -d ' ')" == "8" ]] || { echo "expected seven handoff stage rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_v61_handoff_command_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected five handoff command rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v53z bundle" >&2
  exit 1
fi

echo "v53z review return to v61 handoff bridge shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

boundary = f"""# v53z Complete Source Review Return to v61 Handoff Bridge Boundary

This artifact ties the v53 complete-source review-return path to the v61
post-full-shard actual-generation refresh chain. It does not fabricate review
rows, generation rows, latency rows, quality claims, or release evidence.

Evidence emitted:

- chunk_return_dir_supplied={chunk_return_dir_supplied}
- chunk_return_dir_exists={chunk_return_dir_exists}
- review_return_dir_supplied={review_return_dir_supplied}
- review_return_dir_exists={review_return_dir_exists}
- handoff_stage_rows={len(stage_rows)}
- ready_handoff_stage_rows={ready_stage_rows}
- blocked_handoff_stage_rows={blocked_stage_rows}
- handoff_command_rows={len(command_rows)}
- ready_handoff_command_rows={ready_command_rows}
- machine_complete_source_surface_ready={v53y['machine_complete_source_surface_ready']}
- ready_review_chunk_dispatch_rows={v53w['ready_review_chunk_dispatch_rows']}
- review_chunk_return_artifact_rows={v53x['review_chunk_return_artifact_rows']}
- accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}
- aggregate_review_return_artifact_rows={v53x['aggregate_review_return_artifact_rows']}
- accepted_aggregate_review_return_artifact_rows={v53x['accepted_aggregate_review_return_artifact_rows']}
- expected_human_review_rows={v53y['expected_human_review_rows']}
- accepted_human_review_rows={v53y['accepted_human_review_rows']}
- answer_review_accepted_rows={v53y['answer_review_accepted_rows']}
- review_return_ready={v53y['review_return_ready']}
- v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}
- full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}
- generation_execution_admitted_rows={v61dd['generation_execution_admitted_rows']}
- generation_result_accepted_rows={v61dd['generation_result_accepted_rows']}
- actual_model_generation_ready={v61dd['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v53z=0

Allowed wording: v53 review-return to v61 handoff bridge is ready and names the
remaining blockers.

Blocked wording: accepted review return, actual generation, production latency,
near-frontier quality, v1.0 comparison readiness, or release readiness.
"""
(run_dir / "V53Z_COMPLETE_SOURCE_REVIEW_RETURN_V61_HANDOFF_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53z-complete-source-review-return-v61-handoff-bridge",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": 1,
    "chunk_return_dir_supplied": chunk_return_dir_supplied,
    "chunk_return_dir_exists": chunk_return_dir_exists,
    "review_return_dir_supplied": review_return_dir_supplied,
    "review_return_dir_exists": review_return_dir_exists,
    "handoff_stage_rows": len(stage_rows),
    "ready_handoff_stage_rows": ready_stage_rows,
    "blocked_handoff_stage_rows": blocked_stage_rows,
    "ready_review_chunk_dispatch_rows": as_int(v53w, "ready_review_chunk_dispatch_rows"),
    "accepted_chunk_return_artifact_rows": as_int(v53x, "accepted_chunk_return_artifact_rows"),
    "accepted_aggregate_review_return_artifact_rows": as_int(v53x, "accepted_aggregate_review_return_artifact_rows"),
    "answer_review_accepted_rows": as_int(v53y, "answer_review_accepted_rows"),
    "v61_review_unblock_ready": as_int(v61dd, "v61_review_unblock_ready"),
    "actual_model_generation_ready": as_int(v61dd, "actual_model_generation_ready"),
    "source_v53y_summary_sha256": sha256(summary_paths["v53y"]),
    "source_v61dd_summary_sha256": sha256(summary_paths["v61dd"]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53z_complete_source_review_return_v61_handoff_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53z_complete_source_review_return_v61_handoff_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
