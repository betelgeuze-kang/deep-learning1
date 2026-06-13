#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ex_generation_acceptance_closure_work_order"
RUN_ID="${V61EX_RUN_ID:-work_order_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BRIDGE_RUN_DIR_ARG="${V61EX_ACCEPTANCE_BRIDGE_RUN_DIR:-}"

if [[ "${V61EX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ex_generation_acceptance_closure_work_order_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ew_downstream_replay_to_acceptance_bridge.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
V61CU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null
V61CT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$BRIDGE_RUN_DIR_ARG" <<'PY'
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
bridge_arg = sys.argv[5].strip()
results = root / "results"
default_bridge_dir = results / "v61ew_downstream_replay_to_acceptance_bridge" / "bridge_001"
bridge_dir = Path(bridge_arg).expanduser().resolve() if bridge_arg else default_bridge_dir


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


def row_ready(flag):
    return "ready" if flag else "blocked"


def decision_status(flag):
    return "pass" if flag else "blocked"


source_paths = {
    "v61ew_summary": results / "v61ew_downstream_replay_to_acceptance_bridge_summary.csv",
    "v61ew_decision": results / "v61ew_downstream_replay_to_acceptance_bridge_decision.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "v61cu_summary": results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "v61ct_summary": results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
    "selected_bridge_stage_rows": bridge_dir / "downstream_replay_to_acceptance_stage_rows.csv",
    "selected_bridge_requirement_rows": bridge_dir / "downstream_replay_to_acceptance_requirement_rows.csv",
    "selected_bridge_command_rows": bridge_dir / "downstream_replay_to_acceptance_command_rows.csv",
    "selected_bridge_manifest": bridge_dir / "v61ew_downstream_replay_to_acceptance_bridge_manifest.json",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ex source {key}: {path}")
    folder = "selected_acceptance_bridge" if key.startswith("selected_bridge") else "source_summaries"
    copy(path, f"{folder}/{path.name}")

bridge_stage_rows = read_csv(source_paths["selected_bridge_stage_rows"])
bridge_ready_by_stage = {row["stage_id"]: as_int(row, "ready") for row in bridge_stage_rows}
bridge_manifest = json.loads(source_paths["selected_bridge_manifest"].read_text(encoding="utf-8"))
v61bt = read_csv(source_paths["v61bt_summary"])[0]
v61de = read_csv(source_paths["v61de_summary"])[0]
v61cu = read_csv(source_paths["v61cu_summary"])[0]
v61ct = read_csv(source_paths["v61ct_summary"])[0]

selected_downstream_candidate = bridge_ready_by_stage.get("01-downstream-replay-candidate", 0)
selected_downstream_real = bridge_ready_by_stage.get("02-downstream-replay-real", 0)
selected_bridge_candidate = bridge_ready_by_stage.get(
    "06-acceptance-bridge-candidate",
    int(bridge_manifest.get("acceptance_bridge_candidate_ready", 0)),
)
selected_bridge_real = bridge_ready_by_stage.get(
    "07-acceptance-bridge-real",
    int(bridge_manifest.get("acceptance_bridge_real_ready", 0)),
)

bt_prereq_ready = as_int(v61bt, "prerequisite_binding_ready")
bt_expected_artifacts = as_int(v61bt, "expected_generation_result_artifacts")
bt_accepted_artifacts = as_int(v61bt, "accepted_generation_result_artifacts")
bt_expected_rows = as_int(v61bt, "expected_generation_rows")
bt_accepted_rows = as_int(v61bt, "accepted_generation_rows")
bt_artifacts_ready = int(bt_accepted_artifacts == bt_expected_artifacts and bt_expected_artifacts > 0)
bt_rows_ready = int(bt_accepted_rows == bt_expected_rows and bt_expected_rows > 0)
bt_result_intake_ready = int(bt_prereq_ready and bt_artifacts_ready and bt_rows_ready)

de_review_ready = as_int(v61de, "review_return_ready")
de_admission_rows = as_int(v61de, "generation_execution_admission_rows")
de_admitted_rows = as_int(v61de, "generation_execution_admitted_rows")
de_expected_artifacts = as_int(v61de, "expected_generation_result_artifacts")
de_accepted_artifacts = as_int(v61de, "accepted_generation_result_artifacts")
de_execution_ready = int(de_admitted_rows == de_admission_rows and de_admission_rows > 0)
de_artifacts_ready = int(de_accepted_artifacts == de_expected_artifacts and de_expected_artifacts > 0)
de_post_review_handoff_ready = int(de_review_ready and de_execution_ready and de_artifacts_ready)

cu_admission_ready = as_int(v61cu, "generation_execution_admission_ready")
cu_acceptance_rows = as_int(v61cu, "generation_result_acceptance_rows")
cu_accepted_rows = as_int(v61cu, "generation_result_accepted_rows")
cu_actual_ready = as_int(v61cu, "actual_model_generation_ready")
cu_result_rows_ready = int(cu_accepted_rows == cu_acceptance_rows and cu_acceptance_rows > 0)
cu_result_acceptance_ready = int(cu_admission_ready and cu_result_rows_ready and cu_actual_ready)

ct_bundle_ready = as_int(v61ct, "v61ct_complete_source_generation_execution_operator_bundle_ready")
closure_ready = int(selected_bridge_real and bt_result_intake_ready and de_post_review_handoff_ready and cu_result_acceptance_ready)

work_rows = [
    {
        "work_item_id": "01-selected-v61ew-bridge",
        "family": "bridge",
        "status": "ready",
        "ready": "1",
        "required_evidence": "selected v61ew bridge artifacts exist",
        "actual_value": f"bridge_dir={bridge_dir}",
        "next_action": "inspect selected bridge stage rows",
    },
    {
        "work_item_id": "02-bridge-candidate",
        "family": "bridge",
        "status": row_ready(selected_bridge_candidate),
        "ready": str(selected_bridge_candidate),
        "required_evidence": "v61ew acceptance_bridge_candidate_ready=1",
        "actual_value": f"candidate={selected_bridge_candidate}; downstream_candidate={selected_downstream_candidate}",
        "next_action": "supply/replay a return bundle through v61ev/v61ew",
    },
    {
        "work_item_id": "03-bridge-real",
        "family": "bridge",
        "status": row_ready(selected_bridge_real),
        "ready": str(selected_bridge_real),
        "required_evidence": "v61ew acceptance_bridge_real_ready=1",
        "actual_value": f"real={selected_bridge_real}; downstream_real={selected_downstream_real}",
        "next_action": "replace fixture replay with real non-fixture evidence",
    },
    {
        "work_item_id": "04-v61bt-prerequisite-binding",
        "family": "v61bt",
        "status": row_ready(bt_prereq_ready),
        "ready": str(bt_prereq_ready),
        "required_evidence": "v61bt prerequisite_binding_ready=1",
        "actual_value": f"ready={bt_prereq_ready}; source={v61bt.get('prerequisite_binding_source', '')}",
        "next_action": "bind v61bt to non-fixture prerequisite summaries",
    },
    {
        "work_item_id": "05-v61bt-result-artifacts",
        "family": "v61bt",
        "status": row_ready(bt_artifacts_ready),
        "ready": str(bt_artifacts_ready),
        "required_evidence": "v61bt accepted_generation_result_artifacts=expected",
        "actual_value": f"accepted={bt_accepted_artifacts}/{bt_expected_artifacts}",
        "next_action": "return all five real generation-result artifacts",
    },
    {
        "work_item_id": "06-v61bt-result-rows",
        "family": "v61bt",
        "status": row_ready(bt_rows_ready),
        "ready": str(bt_rows_ready),
        "required_evidence": "v61bt accepted_generation_rows=expected_generation_rows",
        "actual_value": f"accepted={bt_accepted_rows}/{bt_expected_rows}",
        "next_action": "return 1000 accepted source-bound generation rows",
    },
    {
        "work_item_id": "07-v61de-review-return",
        "family": "v61de",
        "status": row_ready(de_review_ready),
        "ready": str(de_review_ready),
        "required_evidence": "v61de review_return_ready=1",
        "actual_value": f"ready={de_review_ready}; accepted_review={v61de.get('answer_review_accepted_rows', '0')}/{v61de.get('expected_human_review_rows', '0')}",
        "next_action": "supply accepted review/adjudication return rows",
    },
    {
        "work_item_id": "08-v61ct-operator-bundle",
        "family": "v61ct",
        "status": row_ready(ct_bundle_ready),
        "ready": str(ct_bundle_ready),
        "required_evidence": "v61ct operator bundle exists and verifies",
        "actual_value": f"ready={ct_bundle_ready}",
        "next_action": "use only after admission opens",
    },
    {
        "work_item_id": "09-v61de-generation-execution",
        "family": "v61de",
        "status": row_ready(de_execution_ready),
        "ready": str(de_execution_ready),
        "required_evidence": "v61de generation_execution_admitted_rows=admission rows",
        "actual_value": f"admitted={de_admitted_rows}/{de_admission_rows}",
        "next_action": "rerun v61de after review/result prerequisites are accepted",
    },
    {
        "work_item_id": "10-v61de-result-artifacts",
        "family": "v61de",
        "status": row_ready(de_artifacts_ready),
        "ready": str(de_artifacts_ready),
        "required_evidence": "v61de accepted_generation_result_artifacts=expected",
        "actual_value": f"accepted={de_accepted_artifacts}/{de_expected_artifacts}",
        "next_action": "refresh v61de after v61bt accepts result artifacts",
    },
    {
        "work_item_id": "11-v61cu-generation-admission",
        "family": "v61cu",
        "status": row_ready(cu_admission_ready),
        "ready": str(cu_admission_ready),
        "required_evidence": "v61cu generation_execution_admission_ready=1",
        "actual_value": f"ready={cu_admission_ready}",
        "next_action": "refresh v61cu after v61de admits generation execution",
    },
    {
        "work_item_id": "12-v61cu-result-rows",
        "family": "v61cu",
        "status": row_ready(cu_result_rows_ready),
        "ready": str(cu_result_rows_ready),
        "required_evidence": "v61cu generation_result_accepted_rows=acceptance rows",
        "actual_value": f"accepted={cu_accepted_rows}/{cu_acceptance_rows}",
        "next_action": "refresh v61cu after v61bt/v61de accept returned rows",
    },
    {
        "work_item_id": "13-actual-generation-claim",
        "family": "claim",
        "status": row_ready(cu_actual_ready),
        "ready": str(cu_actual_ready),
        "required_evidence": "v61cu actual_model_generation_ready=1",
        "actual_value": f"actual_model_generation_ready={cu_actual_ready}",
        "next_action": "do not claim actual generation until all acceptance rows close",
    },
]
write_csv(run_dir / "generation_acceptance_closure_work_order_rows.csv", list(work_rows[0].keys()), work_rows)

blocker_rows = [
    {
        "blocker_id": row["work_item_id"],
        "family": row["family"],
        "blocking_reason": row["next_action"],
        "actual_value": row["actual_value"],
    }
    for row in work_rows
    if row["ready"] == "0"
]
write_csv(
    run_dir / "generation_acceptance_closure_blocker_rows.csv",
    ["blocker_id", "family", "blocking_reason", "actual_value"],
    blocker_rows,
)

command_rows = [
    {
        "command_id": "refresh-selected-bridge",
        "command": "V61EW_REUSE_EXISTING=1 ./experiments/test_v61ew_downstream_replay_to_acceptance_bridge.sh",
        "ready_to_run_now": "1",
        "purpose": "verify the current bridge mechanics",
    },
    {
        "command_id": "preflight-return-bundle",
        "command": "V61ET_RETURN_BUNDLE_DIR=/path/to/real_return_bundle ./experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh",
        "ready_to_run_now": "0",
        "purpose": "bind the real one-root return bundle",
    },
    {
        "command_id": "fanout-return-bundle",
        "command": "V61EU_RETURN_BUNDLE_DIR=/path/to/real_return_bundle ./experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh",
        "ready_to_run_now": str(selected_bridge_candidate),
        "purpose": "fan out the non-fixture return bundle",
    },
    {
        "command_id": "replay-return-bundle",
        "command": "V61EV_RETURN_BUNDLE_DIR=/path/to/real_return_bundle ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh",
        "ready_to_run_now": str(selected_bridge_candidate),
        "purpose": "replay the non-fixture return bundle downstream",
    },
    {
        "command_id": "accept-v61bt-results",
        "command": "V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_results V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_binding ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(selected_bridge_real),
        "purpose": "accept five artifacts and 1000 source-bound rows",
    },
    {
        "command_id": "refresh-v61de-handoff",
        "command": "V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_results V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_binding ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": str(bt_result_intake_ready),
        "purpose": "admit post-review generation execution/result handoff",
    },
    {
        "command_id": "refresh-v61cu-acceptance",
        "command": "./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh",
        "ready_to_run_now": str(de_post_review_handoff_ready),
        "purpose": "close final generation result acceptance rows",
    },
    {
        "command_id": "claim-boundary",
        "command": "Do not claim actual generation until v61ex generation_acceptance_closure_ready=1",
        "ready_to_run_now": str(closure_ready),
        "purpose": "claim control",
    },
]
write_csv(run_dir / "generation_acceptance_closure_command_rows.csv", list(command_rows[0].keys()), command_rows)

ready_work_order_rows = sum(1 for row in work_rows if row["ready"] == "1")
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")
summary = {
    "v61ex_generation_acceptance_closure_work_order_ready": "1",
    "selected_acceptance_bridge_candidate_ready": str(selected_bridge_candidate),
    "selected_acceptance_bridge_real_ready": str(selected_bridge_real),
    "selected_downstream_replay_real_ready": str(selected_downstream_real),
    "v61bt_result_intake_ready": str(bt_result_intake_ready),
    "v61de_post_review_handoff_ready": str(de_post_review_handoff_ready),
    "v61cu_result_acceptance_ready": str(cu_result_acceptance_ready),
    "ready_work_order_rows": str(ready_work_order_rows),
    "open_blocker_rows": str(len(blocker_rows)),
    "closure_command_rows": str(len(command_rows)),
    "ready_closure_command_rows": str(ready_command_rows),
    "accepted_generation_result_artifacts": str(bt_accepted_artifacts),
    "expected_generation_result_artifacts": str(bt_expected_artifacts),
    "generation_execution_admitted_rows": str(de_admitted_rows),
    "generation_execution_admission_rows": str(de_admission_rows),
    "generation_result_accepted_rows": str(cu_accepted_rows),
    "generation_result_acceptance_rows": str(cu_acceptance_rows),
    "generation_acceptance_closure_ready": str(closure_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ex": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "work-order-shape", "status": "pass", "reason": "v61ex emitted closure rows, commands, boundary, manifest, and hashes"},
    {"gate": "bridge-candidate", "status": decision_status(selected_bridge_candidate), "reason": f"candidate={selected_bridge_candidate}"},
    {"gate": "bridge-real", "status": decision_status(selected_bridge_real), "reason": f"real={selected_bridge_real}"},
    {"gate": "v61bt-result-intake", "status": decision_status(bt_result_intake_ready), "reason": f"ready={bt_result_intake_ready}"},
    {"gate": "v61de-post-review-handoff", "status": decision_status(de_post_review_handoff_ready), "reason": f"ready={de_post_review_handoff_ready}"},
    {"gate": "v61cu-result-acceptance", "status": decision_status(cu_result_acceptance_ready), "reason": f"ready={cu_result_acceptance_ready}"},
    {"gate": "generation-acceptance-closure", "status": decision_status(closure_ready), "reason": f"ready={closure_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "work order does not create actual generation evidence"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata work order only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EX_GENERATION_ACCEPTANCE_CLOSURE_WORK_ORDER_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ex Generation Acceptance Closure Work Order Boundary",
            "",
            f"- selected_acceptance_bridge_candidate_ready={selected_bridge_candidate}",
            f"- selected_acceptance_bridge_real_ready={selected_bridge_real}",
            f"- v61bt_result_intake_ready={bt_result_intake_ready}",
            f"- v61de_post_review_handoff_ready={de_post_review_handoff_ready}",
            f"- v61cu_result_acceptance_ready={cu_result_acceptance_ready}",
            f"- generation_acceptance_closure_ready={closure_ready}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- The remaining v61bt/v61de/v61cu acceptance blockers are enumerated as a work order.",
            "- A fixture bridge can only advance candidate logistics.",
            "",
            "Blocked wording:",
            "- Do not claim actual generation, production latency, near-frontier quality, or release readiness from v61ex alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61ex-generation-acceptance-closure-work-order",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61ex_generation_acceptance_closure_work_order_ready": 1,
    "selected_acceptance_bridge_candidate_ready": selected_bridge_candidate,
    "selected_acceptance_bridge_real_ready": selected_bridge_real,
    "ready_work_order_rows": ready_work_order_rows,
    "open_blocker_rows": len(blocker_rows),
    "generation_acceptance_closure_ready": closure_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ex_generation_acceptance_closure_work_order_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ex_generation_acceptance_closure_work_order_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
