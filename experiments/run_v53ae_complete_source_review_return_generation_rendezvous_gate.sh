#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ae_complete_source_review_return_generation_rendezvous_gate"
RUN_ID="${V53AE_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
DISPATCH_RECEIPT_DIR="${V53AE_DISPATCH_RECEIPT_DIR:-}"
REVIEW_CHUNK_RETURN_DIR="${V53AE_REVIEW_CHUNK_RETURN_DIR:-}"
REVIEW_RETURN_DIR="${V53AE_REVIEW_RETURN_DIR:-}"
GENERATION_RESULT_DIR="${V53AE_GENERATION_RESULT_DIR:-}"

if [[ "${V53AE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ae_complete_source_review_return_generation_rendezvous_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$DISPATCH_RECEIPT_DIR" ]]; then
  V53AD_DISPATCH_RECEIPT_DIR="$DISPATCH_RECEIPT_DIR" V53AD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null
else
  V53AD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null
fi

if [[ -n "$REVIEW_CHUNK_RETURN_DIR" && -n "$REVIEW_RETURN_DIR" ]]; then
  V53Z_REVIEW_CHUNK_RETURN_DIR="$REVIEW_CHUNK_RETURN_DIR" V53Z_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
elif [[ -n "$REVIEW_CHUNK_RETURN_DIR" ]]; then
  V53Z_REVIEW_CHUNK_RETURN_DIR="$REVIEW_CHUNK_RETURN_DIR" V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
elif [[ -n "$REVIEW_RETURN_DIR" ]]; then
  V53Z_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
else
  V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
fi

if [[ -n "$REVIEW_RETURN_DIR" && -n "$GENERATION_RESULT_DIR" ]]; then
  V61DE_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V61DE_GENERATION_RESULT_DIR="$GENERATION_RESULT_DIR" V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
elif [[ -n "$REVIEW_RETURN_DIR" ]]; then
  V61DE_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
elif [[ -n "$GENERATION_RESULT_DIR" ]]; then
  V61DE_GENERATION_RESULT_DIR="$GENERATION_RESULT_DIR" V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
else
  V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
fi

V61CX_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cx_post_full_shard_actual_generation_closure_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$DISPATCH_RECEIPT_DIR" "$REVIEW_CHUNK_RETURN_DIR" "$REVIEW_RETURN_DIR" "$GENERATION_RESULT_DIR" <<'PY'
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
dispatch_receipt_arg = sys.argv[5]
review_chunk_return_arg = sys.argv[6]
review_return_arg = sys.argv[7]
generation_result_arg = sys.argv[8]
dispatch_receipt_dir = Path(dispatch_receipt_arg).expanduser().resolve() if dispatch_receipt_arg else None
review_chunk_return_dir = Path(review_chunk_return_arg).expanduser().resolve() if review_chunk_return_arg else None
review_return_dir = Path(review_return_arg).expanduser().resolve() if review_return_arg else None
generation_result_dir = Path(generation_result_arg).expanduser().resolve() if generation_result_arg else None
results = root / "results"


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


summary_paths = {
    "v53ad": results / "v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_summary.csv",
    "v61de": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "v61cx": results / "v61cx_post_full_shard_actual_generation_closure_queue_summary.csv",
}
decision_paths = {
    "v53ad": results / "v53ad_complete_source_review_dispatch_receipt_intake_decision.csv",
    "v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_decision.csv",
    "v61de": results / "v61de_post_review_generation_result_handoff_bridge_decision.csv",
    "v61cx": results / "v61cx_post_full_shard_actual_generation_closure_queue_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for name, ready_field in [
    ("v53ad", "v53ad_complete_source_review_dispatch_receipt_intake_ready"),
    ("v53z", "v53z_complete_source_review_return_v61_handoff_bridge_ready"),
    ("v61de", "v61de_post_review_generation_result_handoff_bridge_ready"),
    ("v61cx", "v61cx_post_full_shard_actual_generation_closure_queue_ready"),
]:
    if summaries[name].get(ready_field) != "1":
        raise SystemExit(f"v53ae requires {ready_field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

source_files = [
    ("v53ad_complete_source_review_dispatch_receipt_intake/intake_001/complete_source_review_dispatch_receipt_status_rows.csv", "source_v53ad/complete_source_review_dispatch_receipt_status_rows.csv"),
    ("v53ad_complete_source_review_dispatch_receipt_intake/intake_001/runtime_gap_rows.csv", "source_v53ad/runtime_gap_rows.csv"),
    ("v53z_complete_source_review_return_v61_handoff_bridge/bridge_001/review_return_v61_handoff_stage_rows.csv", "source_v53z/review_return_v61_handoff_stage_rows.csv"),
    ("v53z_complete_source_review_return_v61_handoff_bridge/bridge_001/review_return_v61_handoff_command_rows.csv", "source_v53z/review_return_v61_handoff_command_rows.csv"),
    ("v61de_post_review_generation_result_handoff_bridge/bridge_001/post_review_generation_result_handoff_stage_rows.csv", "source_v61de/post_review_generation_result_handoff_stage_rows.csv"),
    ("v61de_post_review_generation_result_handoff_bridge/bridge_001/post_review_generation_result_handoff_command_rows.csv", "source_v61de/post_review_generation_result_handoff_command_rows.csv"),
    ("v61cx_post_full_shard_actual_generation_closure_queue/queue_001/post_full_shard_generation_closure_queue_rows.csv", "source_v61cx/post_full_shard_generation_closure_queue_rows.csv"),
    ("v61cx_post_full_shard_actual_generation_closure_queue/queue_001/post_full_shard_generation_next_action_rows.csv", "source_v61cx/post_full_shard_generation_next_action_rows.csv"),
]
for src_rel, dst_rel in source_files:
    copy(results / src_rel, dst_rel)

v53ad = summaries["v53ad"]
v53z = summaries["v53z"]
v61de = summaries["v61de"]
v61cx = summaries["v61cx"]

dispatch_receipt_dir_supplied = int(dispatch_receipt_dir is not None)
dispatch_receipt_dir_exists = int(dispatch_receipt_dir is not None and dispatch_receipt_dir.is_dir())
review_chunk_return_dir_supplied = int(review_chunk_return_dir is not None)
review_chunk_return_dir_exists = int(review_chunk_return_dir is not None and review_chunk_return_dir.is_dir())
review_return_dir_supplied = int(review_return_dir is not None)
review_return_dir_exists = int(review_return_dir is not None and review_return_dir.is_dir())
generation_result_dir_supplied = int(generation_result_dir is not None)
generation_result_dir_exists = int(generation_result_dir is not None and generation_result_dir.is_dir())

dispatch_archive_surface_ready = int(
    as_int(v53ad, "dispatch_archive_ready")
    and as_int(v53ad, "archive_sha256_ready")
    and as_int(v53ad, "payload_like_archive_member_rows") == 0
)
dispatch_receipt_trace_ready = as_int(v53ad, "dispatch_receipt_intake_ready")
chunk_dispatch_surface_ready = int(
    as_int(v53z, "machine_complete_source_surface_ready")
    and as_int(v53z, "ready_review_chunk_dispatch_rows") == as_int(v53z, "review_chunk_rows")
)
chunk_return_ready = int(
    as_int(v53z, "accepted_chunk_return_artifact_rows") == as_int(v53z, "review_chunk_return_artifact_rows")
    and as_int(v53z, "review_chunk_return_artifact_rows") > 0
)
aggregate_review_ready = int(
    as_int(v53z, "review_return_ready")
    and as_int(v53z, "answer_review_accepted_rows") == as_int(v53z, "expected_human_review_rows")
    and as_int(v53z, "accepted_adjudication_rows") == as_int(v53z, "expected_adjudication_rows")
)
full_shard_runtime_ready = int(
    as_int(v61cx, "full_shard_prerequisites_closed")
    and as_int(v61cx, "complete_source_runtime_admission_execution_ready")
    and as_int(v61de, "complete_source_runtime_admission_execution_ready")
    and as_int(v61de, "runtime_admission_accepted_rows") == 1000
)
v61_generation_admission_ready = int(
    as_int(v61de, "v61_review_unblock_ready")
    and as_int(v61de, "generation_execution_admitted_rows") == as_int(v61de, "generation_execution_admission_rows")
)
generation_result_ready = int(
    as_int(v61de, "accepted_generation_result_artifacts") == as_int(v61de, "expected_generation_result_artifacts")
    and as_int(v61de, "generation_result_accepted_rows") == as_int(v61de, "generation_result_acceptance_rows")
)
actual_generation_ready = as_int(v61de, "actual_model_generation_ready")

stage_rows = [
    {
        "rendezvous_stage_id": "01-dispatch-archive-surface",
        "source_gate": "v53ad",
        "stage_status": "ready" if dispatch_archive_surface_ready else "blocked",
        "expected_return": "dispatch archive sha256 and zero-payload member check ready",
        "actual_return": f"dispatch_archive_ready={v53ad['dispatch_archive_ready']}; archive_sha256_ready={v53ad['archive_sha256_ready']}; payload_like_archive_member_rows={v53ad['payload_like_archive_member_rows']}",
        "blocking_reason": "ready" if dispatch_archive_surface_ready else "dispatch archive surface is incomplete",
    },
    {
        "rendezvous_stage_id": "02-dispatch-receipt-trace",
        "source_gate": "v53ad",
        "stage_status": "ready" if dispatch_receipt_trace_ready else "blocked",
        "expected_return": "accepted_dispatch_receipt_rows=21",
        "actual_return": f"accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}",
        "blocking_reason": "ready" if dispatch_receipt_trace_ready else "dispatch receipts are missing or optional-not-yet-returned",
    },
    {
        "rendezvous_stage_id": "03-review-chunk-dispatch-surface",
        "source_gate": "v53z",
        "stage_status": "ready" if chunk_dispatch_surface_ready else "blocked",
        "expected_return": "21/21 review chunks dispatch-ready",
        "actual_return": f"ready_review_chunk_dispatch_rows={v53z['ready_review_chunk_dispatch_rows']}/{v53z['review_chunk_rows']}",
        "blocking_reason": "ready" if chunk_dispatch_surface_ready else "review chunk dispatch is incomplete",
    },
    {
        "rendezvous_stage_id": "04-review-chunk-return-intake",
        "source_gate": "v53z",
        "stage_status": "ready" if chunk_return_ready else "blocked",
        "expected_return": "accepted_chunk_return_artifact_rows=50",
        "actual_return": f"accepted_chunk_return_artifact_rows={v53z['accepted_chunk_return_artifact_rows']}/{v53z['review_chunk_return_artifact_rows']}",
        "blocking_reason": "ready" if chunk_return_ready else "review chunk return artifacts are missing or invalid",
    },
    {
        "rendezvous_stage_id": "05-aggregate-review-return-accepted",
        "source_gate": "v53z",
        "stage_status": "ready" if aggregate_review_ready else "blocked",
        "expected_return": "7000 answer review rows and 1000 adjudication rows accepted",
        "actual_return": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}; accepted_adjudication_rows={v53z['accepted_adjudication_rows']}/{v53z['expected_adjudication_rows']}",
        "blocking_reason": "ready" if aggregate_review_ready else "aggregate review return is not accepted",
    },
    {
        "rendezvous_stage_id": "06-full-shard-runtime-closed",
        "source_gate": "v61cx/v61de",
        "stage_status": "ready" if full_shard_runtime_ready else "blocked",
        "expected_return": "full_shard_prerequisites_closed=1 and runtime_admission_accepted_rows=1000",
        "actual_return": f"full_shard_prerequisites_closed={v61cx['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61de['runtime_admission_accepted_rows']}",
        "blocking_reason": "ready" if full_shard_runtime_ready else "full-shard/runtime closure is incomplete",
    },
    {
        "rendezvous_stage_id": "07-v61-generation-execution-admission",
        "source_gate": "v61de",
        "stage_status": "ready" if v61_generation_admission_ready else "blocked",
        "expected_return": "generation_execution_admitted_rows=1000",
        "actual_return": f"v61_review_unblock_ready={v61de['v61_review_unblock_ready']}; generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}",
        "blocking_reason": "ready" if v61_generation_admission_ready else "review return has not unlocked generation execution",
    },
    {
        "rendezvous_stage_id": "08-generation-result-accepted",
        "source_gate": "v61de",
        "stage_status": "ready" if generation_result_ready else "blocked",
        "expected_return": "5 result artifacts and 1000 final generation rows accepted",
        "actual_return": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}; generation_result_accepted_rows={v61de['generation_result_accepted_rows']}/{v61de['generation_result_acceptance_rows']}",
        "blocking_reason": "ready" if generation_result_ready else "generation result artifacts are missing or not accepted",
    },
    {
        "rendezvous_stage_id": "09-actual-generation-ready",
        "source_gate": "v61de",
        "stage_status": "ready" if actual_generation_ready else "blocked",
        "expected_return": "actual_model_generation_ready=1",
        "actual_return": f"actual_model_generation_ready={v61de['actual_model_generation_ready']}",
        "blocking_reason": "ready" if actual_generation_ready else "actual generation remains unproven",
    },
]
write_csv(run_dir / "review_return_generation_rendezvous_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(1 for row in stage_rows if row["stage_status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

next_action_rows = [
    {
        "next_action_id": "01-collect-dispatch-receipts",
        "action_status": "ready" if dispatch_archive_surface_ready and not dispatch_receipt_trace_ready else "closed",
        "command": "V53AE_DISPATCH_RECEIPT_DIR=/path/to/dispatch_receipts V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "expected_return": "21 dispatch receipt JSON artifacts accepted",
        "blocking_reason": "dispatch receipts already accepted" if dispatch_receipt_trace_ready else "waiting for receipt directory",
    },
    {
        "next_action_id": "02-collect-review-chunk-returns",
        "action_status": "ready" if chunk_dispatch_surface_ready and not chunk_return_ready else "closed",
        "command": "V53AE_REVIEW_CHUNK_RETURN_DIR=/path/to/review_chunk_returns V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "expected_return": "50 chunk return artifacts accepted",
        "blocking_reason": "review chunk returns already accepted" if chunk_return_ready else "waiting for chunk return directory",
    },
    {
        "next_action_id": "03-collect-aggregate-review-return",
        "action_status": "ready" if chunk_return_ready and not aggregate_review_ready else "blocked",
        "command": "V53AE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "expected_return": "7000 review rows and 1000 adjudication rows accepted",
        "blocking_reason": "chunk returns must close before aggregate review return" if not chunk_return_ready else "waiting for aggregate review return directory",
    },
    {
        "next_action_id": "04-refresh-v61-generation-admission",
        "action_status": "ready" if aggregate_review_ready and not v61_generation_admission_ready else "blocked",
        "command": "V53AE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "expected_return": "1000 generation execution rows admitted",
        "blocking_reason": "aggregate review return must close first" if not aggregate_review_ready else "waiting for v61 refresh",
    },
    {
        "next_action_id": "05-collect-generation-result-return",
        "action_status": "ready" if v61_generation_admission_ready and not generation_result_ready else "blocked",
        "command": "V53AE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return V53AE_GENERATION_RESULT_DIR=/path/to/generation_result_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "expected_return": "5 generation result artifacts and 1000 final rows accepted",
        "blocking_reason": "generation admission must close first" if not v61_generation_admission_ready else "waiting for generation result return directory",
    },
]
write_csv(run_dir / "review_return_generation_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)
ready_next_action_rows = sum(1 for row in next_action_rows if row["action_status"] == "ready")

command_rows = [
    {
        "command_id": "verify-rendezvous-gate",
        "command": "./experiments/test_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "ready_to_run_now": "1",
        "expected_return": "rendezvous gate smoke passes",
    },
    {
        "command_id": "refresh-with-dispatch-receipts",
        "command": "V53AE_DISPATCH_RECEIPT_DIR=/path/to/dispatch_receipts V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "ready_to_run_now": str(dispatch_receipt_dir_exists),
        "expected_return": "dispatch receipts accepted",
    },
    {
        "command_id": "refresh-with-review-chunk-returns",
        "command": "V53AE_REVIEW_CHUNK_RETURN_DIR=/path/to/review_chunk_returns V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "ready_to_run_now": str(review_chunk_return_dir_exists),
        "expected_return": "review chunk returns accepted",
    },
    {
        "command_id": "refresh-with-aggregate-review-return",
        "command": "V53AE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "ready_to_run_now": str(review_return_dir_exists),
        "expected_return": "aggregate review return accepted and v61 generation admission refreshed",
    },
    {
        "command_id": "refresh-with-generation-result-return",
        "command": "V53AE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return V53AE_GENERATION_RESULT_DIR=/path/to/generation_result_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "ready_to_run_now": str(review_return_dir_exists and generation_result_dir_exists),
        "expected_return": "generation result return accepted",
    },
]
write_csv(run_dir / "review_return_generation_rendezvous_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

requirement_rows = [
    {"requirement_id": "dispatch-archive-surface", "status": status(dispatch_archive_surface_ready), "required_value": "1", "actual_value": str(dispatch_archive_surface_ready), "reason": "review dispatch archive must be available and zero-payload"},
    {"requirement_id": "dispatch-receipt-trace", "status": status(dispatch_receipt_trace_ready), "required_value": v53ad["dispatch_receipt_template_rows"], "actual_value": v53ad["accepted_dispatch_receipt_rows"], "reason": "receipt trace is useful but not review evidence"},
    {"requirement_id": "review-chunk-dispatch-surface", "status": status(chunk_dispatch_surface_ready), "required_value": v53z["review_chunk_rows"], "actual_value": v53z["ready_review_chunk_dispatch_rows"], "reason": "review chunks must remain dispatch-ready"},
    {"requirement_id": "review-chunk-return-accepted", "status": status(chunk_return_ready), "required_value": v53z["review_chunk_return_artifact_rows"], "actual_value": v53z["accepted_chunk_return_artifact_rows"], "reason": "chunk review returns are still required"},
    {"requirement_id": "aggregate-review-return-accepted", "status": status(aggregate_review_ready), "required_value": v53z["expected_human_review_rows"], "actual_value": v53z["answer_review_accepted_rows"], "reason": "aggregate human review/adjudication return is still required"},
    {"requirement_id": "full-shard-runtime-closed", "status": status(full_shard_runtime_ready), "required_value": "1", "actual_value": str(full_shard_runtime_ready), "reason": "v61 full-shard and runtime admission closure must stay closed"},
    {"requirement_id": "v61-generation-execution-admitted", "status": status(v61_generation_admission_ready), "required_value": v61de["generation_execution_admission_rows"], "actual_value": v61de["generation_execution_admitted_rows"], "reason": "generation execution waits for accepted review return"},
    {"requirement_id": "generation-result-accepted", "status": status(generation_result_ready), "required_value": v61de["expected_generation_result_artifacts"], "actual_value": v61de["accepted_generation_result_artifacts"], "reason": "generation result artifacts are still required"},
    {"requirement_id": "actual-model-generation", "status": status(actual_generation_ready), "required_value": "1", "actual_value": str(actual_generation_ready), "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "review_return_generation_rendezvous_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "dispatch-archive-surface", "status": "ready" if dispatch_archive_surface_ready else "blocked", "reason": f"dispatch_archive_ready={v53ad['dispatch_archive_ready']}"},
    {"gap": "dispatch-receipt-trace", "status": "ready" if dispatch_receipt_trace_ready else "blocked", "reason": f"accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}"},
    {"gap": "review-chunk-return", "status": "ready" if chunk_return_ready else "blocked", "reason": f"accepted_chunk_return_artifact_rows={v53z['accepted_chunk_return_artifact_rows']}/{v53z['review_chunk_return_artifact_rows']}"},
    {"gap": "aggregate-review-return", "status": "ready" if aggregate_review_ready else "blocked", "reason": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}"},
    {"gap": "full-shard-runtime", "status": "ready" if full_shard_runtime_ready else "blocked", "reason": f"full_shard_prerequisites_closed={v61cx['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61de['runtime_admission_accepted_rows']}"},
    {"gap": "generation-execution-admitted", "status": "ready" if v61_generation_admission_ready else "blocked", "reason": f"generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}"},
    {"gap": "generation-result-accepted", "status": "ready" if generation_result_ready else "blocked", "reason": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}"},
    {"gap": "actual-model-generation", "status": "ready" if actual_generation_ready else "blocked", "reason": f"actual_model_generation_ready={actual_generation_ready}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ae_complete_source_review_return_generation_rendezvous_gate_metrics",
    "model_id": v53z["model_id"],
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": v53ad["v53ad_complete_source_review_dispatch_receipt_intake_ready"],
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": v53z["v53z_complete_source_review_return_v61_handoff_bridge_ready"],
    "v61de_post_review_generation_result_handoff_bridge_ready": v61de["v61de_post_review_generation_result_handoff_bridge_ready"],
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": v61cx["v61cx_post_full_shard_actual_generation_closure_queue_ready"],
    "dispatch_receipt_dir_supplied": str(dispatch_receipt_dir_supplied),
    "dispatch_receipt_dir_exists": str(dispatch_receipt_dir_exists),
    "review_chunk_return_dir_supplied": str(review_chunk_return_dir_supplied),
    "review_chunk_return_dir_exists": str(review_chunk_return_dir_exists),
    "review_return_dir_supplied": str(review_return_dir_supplied),
    "review_return_dir_exists": str(review_return_dir_exists),
    "generation_result_dir_supplied": str(generation_result_dir_supplied),
    "generation_result_dir_exists": str(generation_result_dir_exists),
    "rendezvous_stage_rows": str(len(stage_rows)),
    "ready_rendezvous_stage_rows": str(ready_stage_rows),
    "blocked_rendezvous_stage_rows": str(blocked_stage_rows),
    "next_action_rows": str(len(next_action_rows)),
    "ready_next_action_rows": str(ready_next_action_rows),
    "rendezvous_command_rows": str(len(command_rows)),
    "ready_rendezvous_command_rows": str(ready_command_rows),
    "dispatch_receipt_template_rows": v53ad["dispatch_receipt_template_rows"],
    "accepted_dispatch_receipt_rows": v53ad["accepted_dispatch_receipt_rows"],
    "review_chunk_rows": v53z["review_chunk_rows"],
    "ready_review_chunk_dispatch_rows": v53z["ready_review_chunk_dispatch_rows"],
    "review_chunk_return_artifact_rows": v53z["review_chunk_return_artifact_rows"],
    "accepted_chunk_return_artifact_rows": v53z["accepted_chunk_return_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53z["aggregate_review_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53z["accepted_aggregate_review_return_artifact_rows"],
    "expected_human_review_rows": v53z["expected_human_review_rows"],
    "answer_review_accepted_rows": v53z["answer_review_accepted_rows"],
    "expected_adjudication_rows": v53z["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53z["accepted_adjudication_rows"],
    "review_return_ready": v53z["review_return_ready"],
    "v53_ready": v53z["v53_ready"],
    "full_shard_prerequisites_closed": v61cx["full_shard_prerequisites_closed"],
    "full_checkpoint_materialization_ready": v61cx["full_checkpoint_materialization_ready"],
    "completed_full_safetensors_page_hash_coverage_ready": v61cx["completed_full_safetensors_page_hash_coverage_ready"],
    "full_safetensors_page_hash_binding_ready": v61cx["full_safetensors_page_hash_binding_ready"],
    "runtime_admission_accepted_rows": v61de["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61de["complete_source_runtime_admission_execution_ready"],
    "generation_execution_admission_rows": v61de["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61de["generation_execution_admitted_rows"],
    "expected_generation_result_artifacts": v61de["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61de["accepted_generation_result_artifacts"],
    "generation_result_acceptance_rows": v61de["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v61de["generation_result_accepted_rows"],
    "actual_model_generation_ready": str(actual_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ae": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "review_return_generation_rendezvous_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "dispatch-archive-surface", "status": status(dispatch_archive_surface_ready), "reason": f"dispatch_archive_ready={v53ad['dispatch_archive_ready']}"},
    {"gate": "dispatch-receipt-trace", "status": status(dispatch_receipt_trace_ready), "reason": f"accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}"},
    {"gate": "review-chunk-dispatch-surface", "status": status(chunk_dispatch_surface_ready), "reason": f"ready_review_chunk_dispatch_rows={v53z['ready_review_chunk_dispatch_rows']}/{v53z['review_chunk_rows']}"},
    {"gate": "review-chunk-return-accepted", "status": status(chunk_return_ready), "reason": f"accepted_chunk_return_artifact_rows={v53z['accepted_chunk_return_artifact_rows']}/{v53z['review_chunk_return_artifact_rows']}"},
    {"gate": "aggregate-review-return-accepted", "status": status(aggregate_review_ready), "reason": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}"},
    {"gate": "full-shard-runtime-closed", "status": status(full_shard_runtime_ready), "reason": f"full_shard_prerequisites_closed={v61cx['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61de['runtime_admission_accepted_rows']}"},
    {"gate": "generation-execution-admitted", "status": status(v61_generation_admission_ready), "reason": f"generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}"},
    {"gate": "generation-result-accepted", "status": status(generation_result_ready), "reason": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}"},
    {"gate": "actual-model-generation", "status": status(actual_generation_ready), "reason": f"actual_model_generation_ready={actual_generation_ready}"},
    {"gate": "production-latency", "status": "blocked", "reason": "production latency evidence remains external to this rendezvous gate"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality evidence remains external to this rendezvous gate"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release package evidence remains external to this rendezvous gate"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ae Complete-Source Review Return Generation Rendezvous Gate Boundary

This artifact binds the post-dispatch review return path to the v61 full-shard
actual-generation handoff. It can verify that the full-shard/runtime side is
closed and that the review/generation return surfaces are ready to accept
external evidence. It does not create review judgments, generation outputs,
latency evidence, near-frontier quality evidence, or release readiness.

Evidence emitted:

- dispatch_receipt_dir_supplied={dispatch_receipt_dir_supplied}
- dispatch_receipt_dir_exists={dispatch_receipt_dir_exists}
- review_chunk_return_dir_supplied={review_chunk_return_dir_supplied}
- review_chunk_return_dir_exists={review_chunk_return_dir_exists}
- review_return_dir_supplied={review_return_dir_supplied}
- review_return_dir_exists={review_return_dir_exists}
- generation_result_dir_supplied={generation_result_dir_supplied}
- generation_result_dir_exists={generation_result_dir_exists}
- rendezvous_stage_rows={len(stage_rows)}
- ready_rendezvous_stage_rows={ready_stage_rows}
- blocked_rendezvous_stage_rows={blocked_stage_rows}
- next_action_rows={len(next_action_rows)}
- ready_next_action_rows={ready_next_action_rows}
- dispatch_receipt_template_rows={v53ad['dispatch_receipt_template_rows']}
- accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}
- review_chunk_rows={v53z['review_chunk_rows']}
- ready_review_chunk_dispatch_rows={v53z['ready_review_chunk_dispatch_rows']}
- review_chunk_return_artifact_rows={v53z['review_chunk_return_artifact_rows']}
- accepted_chunk_return_artifact_rows={v53z['accepted_chunk_return_artifact_rows']}
- aggregate_review_return_artifact_rows={v53z['aggregate_review_return_artifact_rows']}
- accepted_aggregate_review_return_artifact_rows={v53z['accepted_aggregate_review_return_artifact_rows']}
- expected_human_review_rows={v53z['expected_human_review_rows']}
- answer_review_accepted_rows={v53z['answer_review_accepted_rows']}
- expected_adjudication_rows={v53z['expected_adjudication_rows']}
- accepted_adjudication_rows={v53z['accepted_adjudication_rows']}
- review_return_ready={v53z['review_return_ready']}
- v53_ready={v53z['v53_ready']}
- full_shard_prerequisites_closed={v61cx['full_shard_prerequisites_closed']}
- full_checkpoint_materialization_ready={v61cx['full_checkpoint_materialization_ready']}
- completed_full_safetensors_page_hash_coverage_ready={v61cx['completed_full_safetensors_page_hash_coverage_ready']}
- full_safetensors_page_hash_binding_ready={v61cx['full_safetensors_page_hash_binding_ready']}
- runtime_admission_accepted_rows={v61de['runtime_admission_accepted_rows']}
- complete_source_runtime_admission_execution_ready={v61de['complete_source_runtime_admission_execution_ready']}
- generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}
- generation_result_accepted_rows={v61de['generation_result_accepted_rows']}
- actual_model_generation_ready={actual_generation_ready}
- checkpoint_payload_bytes_downloaded_by_v53ae=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: full-shard/runtime prerequisites are closed and review/generation
return rendezvous surfaces are defined.
Blocked wording: accepted review return, generation execution, actual generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AE_COMPLETE_SOURCE_REVIEW_RETURN_GENERATION_RENDEZVOUS_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ae-complete-source-review-return-generation-rendezvous-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": 1,
    "model_id": v53z["model_id"],
    "ready_rendezvous_stage_rows": ready_stage_rows,
    "blocked_rendezvous_stage_rows": blocked_stage_rows,
    "ready_next_action_rows": ready_next_action_rows,
    "accepted_dispatch_receipt_rows": as_int(v53ad, "accepted_dispatch_receipt_rows"),
    "accepted_chunk_return_artifact_rows": as_int(v53z, "accepted_chunk_return_artifact_rows"),
    "answer_review_accepted_rows": as_int(v53z, "answer_review_accepted_rows"),
    "full_shard_prerequisites_closed": as_int(v61cx, "full_shard_prerequisites_closed"),
    "runtime_admission_accepted_rows": as_int(v61de, "runtime_admission_accepted_rows"),
    "generation_execution_admitted_rows": as_int(v61de, "generation_execution_admitted_rows"),
    "accepted_generation_result_artifacts": as_int(v61de, "accepted_generation_result_artifacts"),
    "actual_model_generation_ready": actual_generation_ready,
    "source_v53ad_summary_sha256": sha256(summary_paths["v53ad"]),
    "source_v53z_summary_sha256": sha256(summary_paths["v53z"]),
    "source_v61de_summary_sha256": sha256(summary_paths["v61de"]),
    "source_v61cx_summary_sha256": sha256(summary_paths["v61cx"]),
    "checkpoint_payload_bytes_downloaded_by_v53ae": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53ae_complete_source_review_return_generation_rendezvous_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ae_complete_source_review_return_generation_rendezvous_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
