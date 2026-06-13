#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61de_post_review_generation_result_handoff_bridge"
RUN_ID="${V61DE_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REVIEW_RETURN_DIR="${V61DE_REVIEW_RETURN_DIR:-}"
GENERATION_RESULT_DIR="${V61DE_GENERATION_RESULT_DIR:-}"
PREREQUISITE_BINDING_DIR="${V61DE_PREREQUISITE_BINDING_DIR:-}"

if [[ "${V61DE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61de_post_review_generation_result_handoff_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$REVIEW_RETURN_DIR" ]]; then
  V53Z_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
else
  V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
fi

V61CT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null
if [[ -n "$GENERATION_RESULT_DIR" && -n "$PREREQUISITE_BINDING_DIR" ]]; then
  V61BT_GENERATION_RESULT_DIR="$GENERATION_RESULT_DIR" V61BT_PREREQUISITE_BINDING_DIR="$PREREQUISITE_BINDING_DIR" V61BT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
elif [[ -n "$GENERATION_RESULT_DIR" ]]; then
  V61BT_GENERATION_RESULT_DIR="$GENERATION_RESULT_DIR" V61BT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
elif [[ -n "$PREREQUISITE_BINDING_DIR" ]]; then
  V61BT_PREREQUISITE_BINDING_DIR="$PREREQUISITE_BINDING_DIR" V61BT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
else
  V61BT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
fi
V61CU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null
if [[ -n "$REVIEW_RETURN_DIR" ]]; then
  V61DD_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V61DD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null
else
  V61DD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$REVIEW_RETURN_DIR" "$GENERATION_RESULT_DIR" "$PREREQUISITE_BINDING_DIR" <<'PY'
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
review_return_arg = sys.argv[5]
generation_result_arg = sys.argv[6]
binding_arg = sys.argv[7]
review_return_dir = Path(review_return_arg).expanduser().resolve() if review_return_arg else None
generation_result_dir = Path(generation_result_arg).expanduser().resolve() if generation_result_arg else None
prerequisite_binding_dir = Path(binding_arg).expanduser().resolve() if binding_arg else None
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
    "v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_summary.csv",
    "v61ct": results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
    "v61bt": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61cu": results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "v61dd": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
}
decision_paths = {
    "v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_decision.csv",
    "v61ct": results / "v61ct_complete_source_generation_execution_operator_bundle_decision.csv",
    "v61bt": results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv",
    "v61cu": results / "v61cu_complete_source_generation_result_acceptance_bridge_decision.csv",
    "v61dd": results / "v61dd_review_return_generation_refresh_bridge_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for name, ready_field in [
    ("v53z", "v53z_complete_source_review_return_v61_handoff_bridge_ready"),
    ("v61ct", "v61ct_complete_source_generation_execution_operator_bundle_ready"),
    ("v61bt", "v61bt_ubuntu1_actual_generation_result_intake_ready"),
    ("v61cu", "v61cu_complete_source_generation_result_acceptance_bridge_ready"),
    ("v61dd", "v61dd_review_return_generation_refresh_bridge_ready"),
]:
    if summaries[name].get(ready_field) != "1":
        raise SystemExit(f"v61de requires {ready_field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

source_files = [
    ("v53z_complete_source_review_return_v61_handoff_bridge/bridge_001/review_return_v61_handoff_stage_rows.csv", "source_v53z/review_return_v61_handoff_stage_rows.csv"),
    ("v53z_complete_source_review_return_v61_handoff_bridge/bridge_001/runtime_gap_rows.csv", "source_v53z/runtime_gap_rows.csv"),
    ("v61ct_complete_source_generation_execution_operator_bundle/bundle_001/complete_source_generation_execution_operator_command_rows.csv", "source_v61ct/complete_source_generation_execution_operator_command_rows.csv"),
    ("v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv", "source_v61ct/GENERATION_RESULT_RETURN_TEMPLATE.csv"),
    ("v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_status_rows.csv", "source_v61bt/actual_generation_result_status_rows.csv"),
    ("v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_query_result_rows.csv", "source_v61bt/actual_generation_query_result_rows.csv"),
    ("v61cu_complete_source_generation_result_acceptance_bridge/bridge_001/complete_source_generation_result_acceptance_rows.csv", "source_v61cu/complete_source_generation_result_acceptance_rows.csv"),
    ("v61cu_complete_source_generation_result_acceptance_bridge/bridge_001/runtime_gap_rows.csv", "source_v61cu/runtime_gap_rows.csv"),
    ("v61dd_review_return_generation_refresh_bridge/bridge_001/review_return_generation_refresh_stage_rows.csv", "source_v61dd/review_return_generation_refresh_stage_rows.csv"),
    ("v61dd_review_return_generation_refresh_bridge/bridge_001/runtime_gap_rows.csv", "source_v61dd/runtime_gap_rows.csv"),
]
for src_rel, dst_rel in source_files:
    copy(results / src_rel, dst_rel)

v53z = summaries["v53z"]
v61ct = summaries["v61ct"]
v61bt = summaries["v61bt"]
v61cu = summaries["v61cu"]
v61dd = summaries["v61dd"]

review_return_dir_supplied = int(review_return_dir is not None)
review_return_dir_exists = int(review_return_dir is not None and review_return_dir.is_dir())
generation_result_dir_supplied = int(generation_result_dir is not None)
generation_result_dir_exists = int(generation_result_dir is not None and generation_result_dir.is_dir())
prerequisite_binding_dir_supplied = int(prerequisite_binding_dir is not None)
prerequisite_binding_dir_exists = int(prerequisite_binding_dir is not None and prerequisite_binding_dir.is_dir())

handoff_surface_ready = 1
full_shard_runtime_ready = int(
    as_int(v61dd, "full_shard_prerequisites_closed")
    and as_int(v61dd, "complete_source_runtime_admission_execution_ready")
)
operator_result_surface_ready = int(
    as_int(v61ct, "v61ct_complete_source_generation_execution_operator_bundle_ready")
    and as_int(v61bt, "v61bt_ubuntu1_actual_generation_result_intake_ready")
    and as_int(v61cu, "v61cu_complete_source_generation_result_acceptance_bridge_ready")
)
review_return_ready = as_int(v53z, "review_return_ready") and as_int(v61dd, "v61_review_unblock_ready")
generation_execution_admitted = int(as_int(v61cu, "generation_execution_admitted_rows") == as_int(v61cu, "generation_execution_admission_rows"))
guarded_generation_ready = as_int(v61ct, "guarded_generation_command_ready") and as_int(v61ct, "generation_operator_execution_ready")
generation_result_artifacts_ready = int(as_int(v61bt, "accepted_generation_result_artifacts") == as_int(v61bt, "expected_generation_result_artifacts"))
generation_result_acceptance_ready = int(as_int(v61cu, "generation_result_accepted_rows") == as_int(v61cu, "generation_result_acceptance_rows"))
actual_generation_ready = as_int(v61cu, "actual_model_generation_ready") and as_int(v61dd, "actual_model_generation_ready")

stage_rows = [
    {
        "handoff_stage_id": "01-review-return-v61-handoff-surface",
        "source_gate": "v53z",
        "stage_status": "ready" if handoff_surface_ready else "blocked",
        "expected_return": "v53z_complete_source_review_return_v61_handoff_bridge_ready=1",
        "actual_return": f"v53z_ready={v53z['v53z_complete_source_review_return_v61_handoff_bridge_ready']}",
        "blocking_reason": "ready" if handoff_surface_ready else "v53z handoff missing",
    },
    {
        "handoff_stage_id": "02-full-shard-runtime-prerequisites",
        "source_gate": "v61dd",
        "stage_status": "ready" if full_shard_runtime_ready else "blocked",
        "expected_return": "full_shard_prerequisites_closed=1 and runtime_admission_accepted_rows=1000",
        "actual_return": f"full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}",
        "blocking_reason": "ready" if full_shard_runtime_ready else "full-shard/runtime prerequisites incomplete",
    },
    {
        "handoff_stage_id": "03-generation-operator-result-surfaces",
        "source_gate": "v61ct/v61bt/v61cu",
        "stage_status": "ready" if operator_result_surface_ready else "blocked",
        "expected_return": "v61ct/v61bt/v61cu ready",
        "actual_return": f"v61ct={v61ct['v61ct_complete_source_generation_execution_operator_bundle_ready']}; v61bt={v61bt['v61bt_ubuntu1_actual_generation_result_intake_ready']}; v61cu={v61cu['v61cu_complete_source_generation_result_acceptance_bridge_ready']}",
        "blocking_reason": "ready" if operator_result_surface_ready else "operator/result surfaces incomplete",
    },
    {
        "handoff_stage_id": "04-review-return-accepted",
        "source_gate": "v53z/v61dd",
        "stage_status": "ready" if review_return_ready else "blocked",
        "expected_return": "answer_review_accepted_rows=7000 and v61_review_unblock_ready=1",
        "actual_return": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}; v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}",
        "blocking_reason": "ready" if review_return_ready else "actual review return not accepted",
    },
    {
        "handoff_stage_id": "05-generation-execution-admitted",
        "source_gate": "v61cu",
        "stage_status": "ready" if generation_execution_admitted else "blocked",
        "expected_return": "generation_execution_admitted_rows=1000",
        "actual_return": f"generation_execution_admitted_rows={v61cu['generation_execution_admitted_rows']}/{v61cu['generation_execution_admission_rows']}",
        "blocking_reason": "ready" if generation_execution_admitted else "generation execution admission is blocked",
    },
    {
        "handoff_stage_id": "06-guarded-generation-operator-ready",
        "source_gate": "v61ct",
        "stage_status": "ready" if guarded_generation_ready else "blocked",
        "expected_return": "guarded_generation_command_ready=1",
        "actual_return": f"guarded_generation_command_ready={v61ct['guarded_generation_command_ready']}; generation_operator_execution_ready={v61ct['generation_operator_execution_ready']}",
        "blocking_reason": "ready" if guarded_generation_ready else "guarded generation command is closed",
    },
    {
        "handoff_stage_id": "07-generation-result-artifacts-accepted",
        "source_gate": "v61bt",
        "stage_status": "ready" if generation_result_artifacts_ready else "blocked",
        "expected_return": "accepted_generation_result_artifacts=5",
        "actual_return": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}",
        "blocking_reason": "ready" if generation_result_artifacts_ready else "generation result artifacts are missing",
    },
    {
        "handoff_stage_id": "08-actual-generation-accepted",
        "source_gate": "v61cu/v61dd",
        "stage_status": "ready" if actual_generation_ready else "blocked",
        "expected_return": "actual_model_generation_ready=1",
        "actual_return": f"actual_model_generation_ready={v61cu['actual_model_generation_ready']}; v61dd_actual_model_generation_ready={v61dd['actual_model_generation_ready']}",
        "blocking_reason": "ready" if actual_generation_ready else "actual generation is not accepted",
    },
]
write_csv(run_dir / "post_review_generation_result_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(1 for row in stage_rows if row["stage_status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

command_rows = [
    {
        "command_id": "verify-v61de-handoff-bridge",
        "command": "results/v61de_post_review_generation_result_handoff_bridge/bridge_001/operator_bundle/VERIFY_POST_REVIEW_GENERATION_HANDOFF.sh",
        "ready_to_run_now": "1",
        "expected_return": "v61de handoff shape verified",
    },
    {
        "command_id": "refresh-review-return-handoff",
        "command": "V53Z_REVIEW_RETURN_DIR=/path/to/v53_review_return V53Z_REUSE_EXISTING=0 ./experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh",
        "ready_to_run_now": str(review_return_dir_exists),
        "expected_return": "review return accepted and v61 review blocker refreshed",
    },
    {
        "command_id": "run-generation-admission-guard",
        "command": "results/v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/RUN_GENERATION_GUARD.sh",
        "ready_to_run_now": "1",
        "expected_return": "guard refuses until generation execution admission is open",
    },
    {
        "command_id": "run-real-generation-after-admission",
        "command": "DRY_RUN=0 V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return ./operator/run_complete_source_generation.sh",
        "ready_to_run_now": str(int(guarded_generation_ready)),
        "expected_return": "real generation result artifacts are produced externally",
    },
    {
        "command_id": "intake-generation-result-return",
        "command": "V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(generation_result_dir_exists),
        "expected_return": "five generation result artifacts accepted",
    },
    {
        "command_id": "refresh-generation-result-acceptance",
        "command": "V61CU_REUSE_EXISTING=0 ./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh && V61DD_REUSE_EXISTING=0 ./experiments/run_v61dd_review_return_generation_refresh_bridge.sh",
        "ready_to_run_now": str(generation_result_dir_exists),
        "expected_return": "generation result acceptance and actual generation readiness refresh",
    },
]
write_csv(run_dir / "post_review_generation_result_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

requirement_rows = [
    {"requirement_id": "review-return-v61-handoff-surface", "status": status(handoff_surface_ready), "required_value": "1", "actual_value": v53z["v53z_complete_source_review_return_v61_handoff_bridge_ready"], "reason": "v53z handoff bridge is present"},
    {"requirement_id": "full-shard-runtime-prerequisites", "status": status(full_shard_runtime_ready), "required_value": "1", "actual_value": str(full_shard_runtime_ready), "reason": "full-shard and runtime admission must be closed"},
    {"requirement_id": "generation-operator-result-surfaces", "status": status(operator_result_surface_ready), "required_value": "1", "actual_value": str(operator_result_surface_ready), "reason": "operator, intake, and acceptance surfaces must exist"},
    {"requirement_id": "review-return-directory", "status": status(review_return_dir_exists), "required_value": "existing review return directory", "actual_value": str(review_return_dir) if review_return_dir else "", "reason": "external review return must be supplied before generation can unblock"},
    {"requirement_id": "review-return-accepted", "status": status(review_return_ready), "required_value": v53z["expected_human_review_rows"], "actual_value": v53z["answer_review_accepted_rows"], "reason": "accepted review return is required before generation admission"},
    {"requirement_id": "generation-execution-admitted", "status": status(generation_execution_admitted), "required_value": v61cu["generation_execution_admission_rows"], "actual_value": v61cu["generation_execution_admitted_rows"], "reason": "all generation execution rows must be admitted"},
    {"requirement_id": "guarded-generation-operator-ready", "status": status(guarded_generation_ready), "required_value": "1", "actual_value": str(int(guarded_generation_ready)), "reason": "guarded real-generation command must open only after admission"},
    {"requirement_id": "generation-result-directory", "status": status(generation_result_dir_exists), "required_value": "existing generation result directory", "actual_value": str(generation_result_dir) if generation_result_dir else "", "reason": "external generation result return must be supplied after execution"},
    {"requirement_id": "generation-result-artifacts-accepted", "status": status(generation_result_artifacts_ready), "required_value": v61bt["expected_generation_result_artifacts"], "actual_value": v61bt["accepted_generation_result_artifacts"], "reason": "v61bt must accept the returned answer/citation/latency artifacts"},
    {"requirement_id": "generation-result-acceptance-ready", "status": status(generation_result_acceptance_ready), "required_value": v61cu["generation_result_acceptance_rows"], "actual_value": v61cu["generation_result_accepted_rows"], "reason": "v61cu must accept all query-level generation results"},
    {"requirement_id": "actual-model-generation", "status": status(actual_generation_ready), "required_value": "1", "actual_value": str(int(actual_generation_ready)), "reason": "actual model generation requires review, admitted execution, and accepted results"},
]
write_csv(run_dir / "post_review_generation_result_handoff_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "review-return-v61-handoff-surface", "status": "ready" if handoff_surface_ready else "blocked", "reason": f"v53z_ready={v53z['v53z_complete_source_review_return_v61_handoff_bridge_ready']}"},
    {"gap": "full-shard-runtime-prerequisites", "status": "ready" if full_shard_runtime_ready else "blocked", "reason": f"full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}"},
    {"gap": "generation-operator-result-surfaces", "status": "ready" if operator_result_surface_ready else "blocked", "reason": f"v61ct={v61ct['v61ct_complete_source_generation_execution_operator_bundle_ready']}; v61bt={v61bt['v61bt_ubuntu1_actual_generation_result_intake_ready']}; v61cu={v61cu['v61cu_complete_source_generation_result_acceptance_bridge_ready']}"},
    {"gap": "review-return-directory", "status": "ready" if review_return_dir_exists else "blocked", "reason": f"review_return_dir_supplied={review_return_dir_supplied}; review_return_dir_exists={review_return_dir_exists}"},
    {"gap": "review-return-accepted", "status": "ready" if review_return_ready else "blocked", "reason": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}; v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}"},
    {"gap": "generation-execution-admitted", "status": "ready" if generation_execution_admitted else "blocked", "reason": f"generation_execution_admitted_rows={v61cu['generation_execution_admitted_rows']}/{v61cu['generation_execution_admission_rows']}"},
    {"gap": "guarded-generation-operator-ready", "status": "ready" if guarded_generation_ready else "blocked", "reason": f"guarded_generation_command_ready={v61ct['guarded_generation_command_ready']}; generation_operator_execution_ready={v61ct['generation_operator_execution_ready']}"},
    {"gap": "generation-result-directory", "status": "ready" if generation_result_dir_exists else "blocked", "reason": f"generation_result_dir_supplied={generation_result_dir_supplied}; generation_result_dir_exists={generation_result_dir_exists}"},
    {"gap": "generation-result-artifacts-accepted", "status": "ready" if generation_result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gap": "actual-model-generation", "status": "ready" if actual_generation_ready else "blocked", "reason": f"actual_model_generation_ready={v61cu['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61de_post_review_generation_result_handoff_bridge_metrics",
    "model_id": v61dd["model_id"],
    "review_return_dir_supplied": str(review_return_dir_supplied),
    "review_return_dir_exists": str(review_return_dir_exists),
    "generation_result_dir_supplied": str(generation_result_dir_supplied),
    "generation_result_dir_exists": str(generation_result_dir_exists),
    "prerequisite_binding_dir_supplied": str(prerequisite_binding_dir_supplied),
    "prerequisite_binding_dir_exists": str(prerequisite_binding_dir_exists),
    "v61bt_prerequisite_binding_ready": v61bt.get("prerequisite_binding_ready", "0"),
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": v53z["v53z_complete_source_review_return_v61_handoff_bridge_ready"],
    "v61ct_complete_source_generation_execution_operator_bundle_ready": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": v61cu["v61cu_complete_source_generation_result_acceptance_bridge_ready"],
    "v61dd_review_return_generation_refresh_bridge_ready": v61dd["v61dd_review_return_generation_refresh_bridge_ready"],
    "handoff_stage_rows": str(len(stage_rows)),
    "ready_handoff_stage_rows": str(ready_stage_rows),
    "blocked_handoff_stage_rows": str(blocked_stage_rows),
    "handoff_command_rows": str(len(command_rows)),
    "ready_handoff_command_rows": str(ready_command_rows),
    "full_shard_prerequisites_closed": v61dd["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v61dd["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61dd["complete_source_runtime_admission_execution_ready"],
    "answer_review_accepted_rows": v53z["answer_review_accepted_rows"],
    "expected_human_review_rows": v53z["expected_human_review_rows"],
    "review_return_ready": v53z["review_return_ready"],
    "v61_review_unblock_ready": v61dd["v61_review_unblock_ready"],
    "generation_execution_admission_rows": v61cu["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61cu["generation_execution_admitted_rows"],
    "generation_execution_blocked_rows": v61cu["generation_execution_blocked_rows"],
    "guarded_generation_command_ready": v61ct["guarded_generation_command_ready"],
    "generation_operator_execution_ready": v61ct["generation_operator_execution_ready"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "generation_result_supplied_rows": v61cu["generation_result_supplied_rows"],
    "generation_result_acceptance_rows": v61cu["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v61cu["generation_result_accepted_rows"],
    "answer_accepted_rows": v61cu["answer_accepted_rows"],
    "citation_accepted_rows": v61cu["citation_accepted_rows"],
    "latency_accepted_rows": v61cu["latency_accepted_rows"],
    "actual_model_generation_ready_rows": v61cu["actual_model_generation_ready_rows"],
    "actual_model_generation_ready": str(int(actual_generation_ready)),
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61de": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_review_generation_result_handoff_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61de_post_review_generation_result_handoff_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "review-return-v61-handoff-surface", "status": status(handoff_surface_ready), "reason": f"v53z_ready={v53z['v53z_complete_source_review_return_v61_handoff_bridge_ready']}"},
    {"gate": "full-shard-runtime-prerequisites", "status": status(full_shard_runtime_ready), "reason": f"full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}"},
    {"gate": "generation-operator-result-surfaces", "status": status(operator_result_surface_ready), "reason": "v61ct/v61bt/v61cu surfaces are bound"},
    {"gate": "review-return-directory", "status": status(review_return_dir_exists), "reason": f"review_return_dir_exists={review_return_dir_exists}"},
    {"gate": "review-return-accepted", "status": status(review_return_ready), "reason": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}"},
    {"gate": "generation-execution-admitted", "status": status(generation_execution_admitted), "reason": f"generation_execution_admitted_rows={v61cu['generation_execution_admitted_rows']}/{v61cu['generation_execution_admission_rows']}"},
    {"gate": "guarded-generation-operator-ready", "status": status(guarded_generation_ready), "reason": f"guarded_generation_command_ready={v61ct['guarded_generation_command_ready']}"},
    {"gate": "generation-result-directory", "status": status(generation_result_dir_exists), "reason": f"generation_result_dir_exists={generation_result_dir_exists}"},
    {"gate": "generation-result-artifacts-accepted", "status": status(generation_result_artifacts_ready), "reason": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gate": "actual-model-generation", "status": status(actual_generation_ready), "reason": f"actual_model_generation_ready={int(actual_generation_ready)}"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

(operator_dir / "README.md").write_text(
    "# v61de Post-Review Generation Result Handoff Bridge\n\n"
    "This bundle connects accepted v53 review returns to the v61 guarded generation and result-return path. "
    "It does not run generation, fabricate result artifacts, or claim latency/quality/release readiness.\n",
    encoding="utf-8",
)
verify_script = operator_dir / "VERIFY_POST_REVIEW_GENERATION_HANDOFF.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/post_review_generation_result_handoff_stage_rows.csv"
  "$BUNDLE_DIR/post_review_generation_result_handoff_command_rows.csv"
  "$BUNDLE_DIR/post_review_generation_result_handoff_requirement_rows.csv"
  "$BUNDLE_DIR/post_review_generation_result_handoff_metric_rows.csv"
  "$BUNDLE_DIR/runtime_gap_rows.csv"
  "$BUNDLE_DIR/source_v53z/review_return_v61_handoff_stage_rows.csv"
  "$BUNDLE_DIR/source_v61ct/complete_source_generation_execution_operator_command_rows.csv"
  "$BUNDLE_DIR/source_v61bt/actual_generation_result_status_rows.csv"
  "$BUNDLE_DIR/source_v61cu/complete_source_generation_result_acceptance_rows.csv"
  "$BUNDLE_DIR/source_v61dd/review_return_generation_refresh_stage_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v61de handoff bridge file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/post_review_generation_result_handoff_stage_rows.csv" | tr -d ' ')" == "9" ]] || { echo "expected eight handoff stage rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/post_review_generation_result_handoff_command_rows.csv" | tr -d ' ')" == "7" ]] || { echo "expected six handoff command rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v61de bundle" >&2
  exit 1
fi

echo "v61de post-review generation handoff bridge shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

boundary = f"""# v61de Post Review Generation Result Handoff Bridge Boundary

This artifact connects the accepted-review-return path to guarded real-model
generation and returned generation-result acceptance. It does not fabricate
review rows, run the model, fabricate generation results, or claim latency,
near-frontier quality, or release readiness.

Evidence emitted:

- review_return_dir_supplied={review_return_dir_supplied}
- review_return_dir_exists={review_return_dir_exists}
- generation_result_dir_supplied={generation_result_dir_supplied}
- generation_result_dir_exists={generation_result_dir_exists}
- prerequisite_binding_dir_supplied={prerequisite_binding_dir_supplied}
- prerequisite_binding_dir_exists={prerequisite_binding_dir_exists}
- v61bt_prerequisite_binding_ready={v61bt.get('prerequisite_binding_ready', '0')}
- handoff_stage_rows={len(stage_rows)}
- ready_handoff_stage_rows={ready_stage_rows}
- blocked_handoff_stage_rows={blocked_stage_rows}
- full_shard_prerequisites_closed={v61dd['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v61dd['runtime_admission_accepted_rows']}
- answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}
- v61_review_unblock_ready={v61dd['v61_review_unblock_ready']}
- generation_execution_admitted_rows={v61cu['generation_execution_admitted_rows']}/{v61cu['generation_execution_admission_rows']}
- guarded_generation_command_ready={v61ct['guarded_generation_command_ready']}
- accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v61cu['generation_result_accepted_rows']}/{v61cu['generation_result_acceptance_rows']}
- actual_model_generation_ready={int(actual_generation_ready)}
- checkpoint_payload_bytes_downloaded_by_v61de=0

Allowed wording: post-review generation result handoff bridge is ready and names
the remaining blockers.

Blocked wording: accepted review return, real generation execution, accepted
generation results, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61DE_POST_REVIEW_GENERATION_RESULT_HANDOFF_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61de-post-review-generation-result-handoff-bridge",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61de_post_review_generation_result_handoff_bridge_ready": 1,
    "review_return_dir_supplied": review_return_dir_supplied,
    "review_return_dir_exists": review_return_dir_exists,
    "generation_result_dir_supplied": generation_result_dir_supplied,
    "generation_result_dir_exists": generation_result_dir_exists,
    "prerequisite_binding_dir_supplied": prerequisite_binding_dir_supplied,
    "prerequisite_binding_dir_exists": prerequisite_binding_dir_exists,
    "v61bt_prerequisite_binding_ready": int(v61bt.get("prerequisite_binding_ready", "0") or "0"),
    "handoff_stage_rows": len(stage_rows),
    "ready_handoff_stage_rows": ready_stage_rows,
    "blocked_handoff_stage_rows": blocked_stage_rows,
    "answer_review_accepted_rows": as_int(v53z, "answer_review_accepted_rows"),
    "generation_execution_admitted_rows": as_int(v61cu, "generation_execution_admitted_rows"),
    "accepted_generation_result_artifacts": as_int(v61bt, "accepted_generation_result_artifacts"),
    "actual_model_generation_ready": int(actual_generation_ready),
    "source_v53z_summary_sha256": sha256(summary_paths["v53z"]),
    "source_v61cu_summary_sha256": sha256(summary_paths["v61cu"]),
    "source_v61dd_summary_sha256": sha256(summary_paths["v61dd"]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61de_post_review_generation_result_handoff_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61de_post_review_generation_result_handoff_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
