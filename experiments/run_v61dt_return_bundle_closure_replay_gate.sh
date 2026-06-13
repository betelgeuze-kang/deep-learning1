#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dt_return_bundle_closure_replay_gate"
RUN_ID="${V61DT_RUN_ID:-closure_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V61DT_RETURN_BUNDLE_DIR:-}"

if [[ "${V61DT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dt_return_bundle_closure_replay_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V61DR_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V61DR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null
  V53AM_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
else
  V61DR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null
  V53AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
fi
V61DS_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ds_schema_preflight_acceptance_handoff_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" <<'PY'
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
return_bundle_arg = sys.argv[5]
return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
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


def status(condition):
    return "ready" if condition else "blocked"


sources = {
    "v61dr_summary": results / "v61dr_return_bundle_schema_preflight_gate_summary.csv",
    "v61dr_decision": results / "v61dr_return_bundle_schema_preflight_gate_decision.csv",
    "v61dr_artifacts": results / "v61dr_return_bundle_schema_preflight_gate/preflight_001/return_bundle_schema_preflight_artifact_rows.csv",
    "v61dr_families": results / "v61dr_return_bundle_schema_preflight_gate/preflight_001/return_bundle_schema_preflight_family_rows.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_decision": results / "v53am_complete_source_return_acceptance_replay_decision.csv",
    "v53am_steps": results / "v53am_complete_source_return_acceptance_replay/replay_001/return_acceptance_replay_step_rows.csv",
    "v61ds_summary": results / "v61ds_schema_preflight_acceptance_handoff_gate_summary.csv",
    "v61ds_decision": results / "v61ds_schema_preflight_acceptance_handoff_gate_decision.csv",
    "v61ds_stages": results / "v61ds_schema_preflight_acceptance_handoff_gate/handoff_001/schema_preflight_acceptance_handoff_stage_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dt source {key}: {path}")

copy(sources["v61dr_summary"], "source_v61dr/v61dr_return_bundle_schema_preflight_gate_summary.csv")
copy(sources["v61dr_decision"], "source_v61dr/v61dr_return_bundle_schema_preflight_gate_decision.csv")
copy(sources["v61dr_artifacts"], "source_v61dr/return_bundle_schema_preflight_artifact_rows.csv")
copy(sources["v61dr_families"], "source_v61dr/return_bundle_schema_preflight_family_rows.csv")
copy(sources["v53am_summary"], "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv")
copy(sources["v53am_decision"], "source_v53am/v53am_complete_source_return_acceptance_replay_decision.csv")
copy(sources["v53am_steps"], "source_v53am/return_acceptance_replay_step_rows.csv")
copy(sources["v61ds_summary"], "source_v61ds/v61ds_schema_preflight_acceptance_handoff_gate_summary.csv")
copy(sources["v61ds_decision"], "source_v61ds/v61ds_schema_preflight_acceptance_handoff_gate_decision.csv")
copy(sources["v61ds_stages"], "source_v61ds/schema_preflight_acceptance_handoff_stage_rows.csv")

v61dr = read_csv(sources["v61dr_summary"])[0]
v53am = read_csv(sources["v53am_summary"])[0]
v61ds = read_csv(sources["v61ds_summary"])[0]

if v61dr.get("v61dr_return_bundle_schema_preflight_gate_ready") != "1":
    raise SystemExit("v61dt requires v61dr ready")
if v53am.get("v53am_complete_source_return_acceptance_replay_ready") != "1":
    raise SystemExit("v61dt requires v53am ready")
if v61ds.get("v61ds_schema_preflight_acceptance_handoff_gate_ready") != "1":
    raise SystemExit("v61dt requires v61ds ready")

bundle_supplied = return_bundle_dir is not None
bundle_exists = return_bundle_dir is not None and return_bundle_dir.is_dir()
schema_surface_ready = as_int(v61dr, "schema_preflight_artifact_rows") == 81
schema_preflight_pass = as_int(v61dr, "schema_preflight_pass") == 1
handoff_ready = as_int(v61ds, "handoff_stage_rows") == 12
acceptance_replay_ready = as_int(v53am, "return_acceptance_replay_ready") == 1
full_return_preflight_pass = as_int(v53am, "return_bundle_preflight_pass") == 1
dispatch_ready = as_int(v53am, "accepted_dispatch_receipt_rows") == as_int(v53am, "dispatch_receipt_template_rows") and as_int(v53am, "dispatch_receipt_template_rows") > 0
chunk_ready = as_int(v53am, "accepted_chunk_return_artifact_rows") == as_int(v53am, "review_chunk_return_artifact_rows") and as_int(v53am, "review_chunk_return_artifact_rows") > 0
aggregate_ready = as_int(v53am, "review_return_ready") == 1
v53_ready = as_int(v53am, "v53_ready") == 1
full_runtime_ready = as_int(v53am, "full_shard_prerequisites_closed") == 1 and as_int(v53am, "runtime_admission_accepted_rows") == 1000
generation_execution_ready = as_int(v53am, "generation_execution_admitted_rows") == as_int(v53am, "generation_execution_admission_rows") and as_int(v53am, "generation_execution_admission_rows") > 0
generation_artifact_ready = as_int(v53am, "accepted_generation_result_artifacts") == as_int(v53am, "expected_generation_result_artifacts") and as_int(v53am, "expected_generation_result_artifacts") > 0
generation_result_ready = as_int(v53am, "generation_result_accepted_rows") == as_int(v53am, "generation_result_acceptance_rows") and as_int(v53am, "generation_result_acceptance_rows") > 0
actual_generation_ready = as_int(v53am, "actual_model_generation_ready") == 1

closure_rows = [
    {
        "closure_stage_id": "01-return-bundle-supplied",
        "source_gate": "v61dt-input",
        "status": status(bundle_supplied and bundle_exists),
        "actual_value": f"return_bundle_dir_supplied={int(bundle_supplied)}; return_bundle_dir_exists={int(bundle_exists)}",
        "blocking_reason": "final return bundle directory is not supplied" if not bundle_supplied else "final return bundle directory does not exist",
        "next_command": "V61DT_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DT_REUSE_EXISTING=0 ./experiments/run_v61dt_return_bundle_closure_replay_gate.sh",
    },
    {
        "closure_stage_id": "02-schema-preflight-surface",
        "source_gate": "v61dr",
        "status": status(schema_surface_ready),
        "actual_value": f"schema_preflight_artifact_rows={v61dr['schema_preflight_artifact_rows']}",
        "blocking_reason": "ready" if schema_surface_ready else "schema preflight surface is incomplete",
        "next_command": "V61DR_REUSE_EXISTING=0 ./experiments/run_v61dr_return_bundle_schema_preflight_gate.sh",
    },
    {
        "closure_stage_id": "03-schema-preflight-pass",
        "source_gate": "v61dr",
        "status": status(schema_preflight_pass),
        "actual_value": f"schema_preflight_pass_rows={v61dr['schema_preflight_pass_rows']}/{v61dr['schema_preflight_artifact_rows']}",
        "blocking_reason": "returned bundle schema preflight has not passed",
        "next_command": "results/v61dr_return_bundle_schema_preflight_gate/preflight_001/VERIFY_RETURN_SCHEMA_PREFLIGHT.sh /path/to/final_return_bundle",
    },
    {
        "closure_stage_id": "04-schema-acceptance-handoff-audited",
        "source_gate": "v61ds",
        "status": status(handoff_ready),
        "actual_value": f"handoff_stage_rows={v61ds['handoff_stage_rows']}; ready_handoff_stage_rows={v61ds['ready_handoff_stage_rows']}",
        "blocking_reason": "ready" if handoff_ready else "schema-to-acceptance handoff audit is incomplete",
        "next_command": "V61DS_REUSE_EXISTING=0 ./experiments/run_v61ds_schema_preflight_acceptance_handoff_gate.sh",
    },
    {
        "closure_stage_id": "05-acceptance-replay-surface",
        "source_gate": "v53am",
        "status": status(acceptance_replay_ready),
        "actual_value": f"return_acceptance_replay_ready={v53am['return_acceptance_replay_ready']}",
        "blocking_reason": "ready" if acceptance_replay_ready else "return acceptance replay surface is incomplete",
        "next_command": "V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
    },
    {
        "closure_stage_id": "06-full-return-preflight-pass",
        "source_gate": "v53am/v53al",
        "status": status(full_return_preflight_pass),
        "actual_value": f"return_bundle_preflight_pass={v53am['return_bundle_preflight_pass']}; preflight_pass_rows={v53am['preflight_pass_rows']}/{v53am['preflight_rows']}",
        "blocking_reason": "full return bundle presence preflight has not passed",
        "next_command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh",
    },
    {
        "closure_stage_id": "07-dispatch-receipts-accepted",
        "source_gate": "v53am/v53ad",
        "status": status(dispatch_ready),
        "actual_value": f"accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}",
        "blocking_reason": "dispatch receipts are not accepted",
        "next_command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
    },
    {
        "closure_stage_id": "08-review-chunks-accepted",
        "source_gate": "v53am/v53x",
        "status": status(chunk_ready),
        "actual_value": f"accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}",
        "blocking_reason": "review chunk returns are not accepted",
        "next_command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
    },
    {
        "closure_stage_id": "09-aggregate-review-accepted",
        "source_gate": "v53am/v53y",
        "status": status(aggregate_ready),
        "actual_value": f"answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}; accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}",
        "blocking_reason": "aggregate review/adjudication return is not accepted",
        "next_command": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
    },
    {
        "closure_stage_id": "10-v53-review-ready",
        "source_gate": "v53am/v53v",
        "status": status(v53_ready),
        "actual_value": f"review_return_ready={v53am['review_return_ready']}; v53_ready={v53am['v53_ready']}",
        "blocking_reason": "v53 complete-source review acceptance is not closed",
        "next_command": "V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
    },
    {
        "closure_stage_id": "11-full-shard-runtime-closed",
        "source_gate": "v53am/v61",
        "status": status(full_runtime_ready),
        "actual_value": f"full_shard_prerequisites_closed={v53am['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v53am['runtime_admission_accepted_rows']}",
        "blocking_reason": "ready" if full_runtime_ready else "full-shard/runtime prerequisites are incomplete",
        "next_command": "V61DG_REUSE_EXISTING=1 ./experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh",
    },
    {
        "closure_stage_id": "12-generation-execution-admitted",
        "source_gate": "v53am/v61de",
        "status": status(generation_execution_ready),
        "actual_value": f"generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}",
        "blocking_reason": "generation execution is not admitted",
        "next_command": "V61DE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
    },
    {
        "closure_stage_id": "13-generation-result-artifacts-accepted",
        "source_gate": "v53am/v61bt",
        "status": status(generation_artifact_ready),
        "actual_value": f"accepted_generation_result_artifacts={v53am['accepted_generation_result_artifacts']}/{v53am['expected_generation_result_artifacts']}",
        "blocking_reason": "generation result artifacts are not accepted",
        "next_command": "V61BT_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
    },
    {
        "closure_stage_id": "14-generation-result-rows-accepted",
        "source_gate": "v53am/v61cu",
        "status": status(generation_result_ready),
        "actual_value": f"generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}",
        "blocking_reason": "generation result rows are not accepted",
        "next_command": "V61CU_REUSE_EXISTING=0 ./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh",
    },
    {
        "closure_stage_id": "15-actual-generation-ready",
        "source_gate": "v53am/v61de",
        "status": status(actual_generation_ready),
        "actual_value": f"actual_model_generation_ready={v53am['actual_model_generation_ready']}",
        "blocking_reason": "actual model generation remains unproven",
        "next_command": "V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
    },
]
write_csv(run_dir / "return_bundle_closure_replay_stage_rows.csv", list(closure_rows[0].keys()), closure_rows)

command_rows = [
    {"command_id": "01-run-one-command-closure-replay", "ready_to_run_now": "1", "closure_stage_id": "01-return-bundle-supplied", "command": "V61DT_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DT_REUSE_EXISTING=0 ./experiments/run_v61dt_return_bundle_closure_replay_gate.sh", "expected_transition": "single bundle path fans into v61dr/v53am/v61ds"},
    {"command_id": "02-run-schema-preflight", "ready_to_run_now": "1", "closure_stage_id": "03-schema-preflight-pass", "command": "V61DR_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DR_REUSE_EXISTING=0 ./experiments/run_v61dr_return_bundle_schema_preflight_gate.sh", "expected_transition": "schema_preflight_pass=1"},
    {"command_id": "03-run-acceptance-replay", "ready_to_run_now": "1", "closure_stage_id": "05-acceptance-replay-surface", "command": "V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh", "expected_transition": "return_acceptance_replay_closed=1 only after all returned evidence is accepted"},
    {"command_id": "04-run-handoff-audit", "ready_to_run_now": "1", "closure_stage_id": "04-schema-acceptance-handoff-audited", "command": "V61DS_REUSE_EXISTING=0 ./experiments/run_v61ds_schema_preflight_acceptance_handoff_gate.sh", "expected_transition": "schema-to-acceptance boundary remains explicit"},
    {"command_id": "05-validate-full-preflight", "ready_to_run_now": str(int(schema_preflight_pass)), "closure_stage_id": "06-full-return-preflight-pass", "command": "results/v61dr_return_bundle_schema_preflight_gate/preflight_001/VERIFY_RETURN_SCHEMA_PREFLIGHT.sh /path/to/final_return_bundle", "expected_transition": "81/81 schema artifacts pass"},
    {"command_id": "06-ingest-review-returns", "ready_to_run_now": str(int(full_return_preflight_pass)), "closure_stage_id": "09-aggregate-review-accepted", "command": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh", "expected_transition": "answer_review_accepted_rows=7000 and accepted_adjudication_rows=1000"},
    {"command_id": "07-ingest-generation-results", "ready_to_run_now": str(int(aggregate_ready)), "closure_stage_id": "13-generation-result-artifacts-accepted", "command": "V61BT_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh", "expected_transition": "accepted_generation_result_artifacts=5"},
    {"command_id": "08-refresh-post-review-handoff", "ready_to_run_now": str(int(aggregate_ready and generation_artifact_ready)), "closure_stage_id": "12-generation-execution-admitted", "command": "V61DE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V61DE_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh", "expected_transition": "generation_execution_admitted_rows=1000"},
    {"command_id": "09-admit-actual-generation", "ready_to_run_now": str(int(actual_generation_ready)), "closure_stage_id": "15-actual-generation-ready", "command": "blocked until accepted review/generation result evidence exists", "expected_transition": "actual_model_generation_ready=1"},
]
write_csv(run_dir / "return_bundle_closure_replay_command_rows.csv", list(command_rows[0].keys()), command_rows)

ready_stage_rows = sum(row["status"] == "ready" for row in closure_rows)
blocked_stage_rows = len(closure_rows) - ready_stage_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)

metric = {
    "metric_id": "v61dt_return_bundle_closure_replay_gate_metrics",
    "v61dr_return_bundle_schema_preflight_gate_ready": v61dr["v61dr_return_bundle_schema_preflight_gate_ready"],
    "v53am_complete_source_return_acceptance_replay_ready": v53am["v53am_complete_source_return_acceptance_replay_ready"],
    "v61ds_schema_preflight_acceptance_handoff_gate_ready": v61ds["v61ds_schema_preflight_acceptance_handoff_gate_ready"],
    "source_gate_rows": "3",
    "closure_stage_rows": str(len(closure_rows)),
    "ready_closure_stage_rows": str(ready_stage_rows),
    "blocked_closure_stage_rows": str(blocked_stage_rows),
    "closure_command_rows": str(len(command_rows)),
    "ready_closure_command_rows": str(ready_command_rows),
    "return_bundle_dir_supplied": str(int(bundle_supplied)),
    "return_bundle_dir_exists": str(int(bundle_exists)),
    "schema_preflight_artifact_rows": v61dr["schema_preflight_artifact_rows"],
    "schema_preflight_pass_rows": v61dr["schema_preflight_pass_rows"],
    "schema_preflight_pass": v61dr["schema_preflight_pass"],
    "schema_handoff_stage_rows": v61ds["handoff_stage_rows"],
    "ready_schema_handoff_stage_rows": v61ds["ready_handoff_stage_rows"],
    "return_bundle_preflight_pass": v53am["return_bundle_preflight_pass"],
    "preflight_pass_rows": v53am["preflight_pass_rows"],
    "preflight_rows": v53am["preflight_rows"],
    "expected_payload_rows": v61ds["expected_payload_rows"],
    "accepted_payload_rows": v61ds["accepted_payload_rows"],
    "accepted_dispatch_receipt_rows": v53am["accepted_dispatch_receipt_rows"],
    "dispatch_receipt_template_rows": v53am["dispatch_receipt_template_rows"],
    "accepted_chunk_return_artifact_rows": v53am["accepted_chunk_return_artifact_rows"],
    "review_chunk_return_artifact_rows": v53am["review_chunk_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53am["accepted_aggregate_review_return_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53am["aggregate_review_return_artifact_rows"],
    "answer_review_accepted_rows": v53am["answer_review_accepted_rows"],
    "expected_human_review_rows": v53am["expected_human_review_rows"],
    "accepted_adjudication_rows": v53am["accepted_adjudication_rows"],
    "expected_adjudication_rows": v53am["expected_adjudication_rows"],
    "review_return_ready": v53am["review_return_ready"],
    "v53_ready": v53am["v53_ready"],
    "full_shard_prerequisites_closed": v53am["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53am["runtime_admission_accepted_rows"],
    "generation_execution_admitted_rows": v53am["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v53am["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v53am["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v53am["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v53am["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v53am["generation_result_acceptance_rows"],
    "schema_acceptance_ready": v61ds["schema_acceptance_ready"],
    "return_acceptance_replay_closed": v53am["return_acceptance_replay_closed"],
    "actual_model_generation_ready": v53am["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dt": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_bundle_closure_replay_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dt_return_bundle_closure_replay_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["closure_stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]}
    for row in closure_rows
]
decision_rows.extend(
    [
        {"gate": "one-command-return-bundle-replay", "status": "pass", "reason": "v61dt fans one return bundle path into v61dr/v53am/v61ds"},
        {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
        {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["closure_stage_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in closure_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dt Return Bundle Closure Replay Gate

This gate provides a one-command returned-bundle replay surface. A single
`V61DT_RETURN_BUNDLE_DIR` is fanned into v61dr schema preflight, v53am
downstream acceptance replay, and v61ds schema-to-acceptance handoff audit.

Evidence emitted:

- source_gate_rows=3
- closure_stage_rows={len(closure_rows)}
- ready_closure_stage_rows={ready_stage_rows}
- blocked_closure_stage_rows={blocked_stage_rows}
- return_bundle_dir_supplied={int(bundle_supplied)}
- return_bundle_dir_exists={int(bundle_exists)}
- schema_preflight_pass_rows={v61dr['schema_preflight_pass_rows']}/{v61dr['schema_preflight_artifact_rows']}
- schema_preflight_pass={v61dr['schema_preflight_pass']}
- return_bundle_preflight_pass={v53am['return_bundle_preflight_pass']}
- preflight_pass_rows={v53am['preflight_pass_rows']}/{v53am['preflight_rows']}
- accepted_payload_rows={v61ds['accepted_payload_rows']}/{v61ds['expected_payload_rows']}
- accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}
- accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}
- answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}
- accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}
- generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={v53am['accepted_generation_result_artifacts']}/{v53am['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}
- return_acceptance_replay_closed={v53am['return_acceptance_replay_closed']}
- actual_model_generation_ready={v53am['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dt=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: the returned-bundle closure replay surface is wired and
reports current blockers.
Blocked wording: returned review accepted, generation result accepted, actual
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DT_RETURN_BUNDLE_CLOSURE_REPLAY_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dt-return-bundle-closure-replay-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dt_return_bundle_closure_replay_gate_ready": 1,
    "source_gate_rows": 3,
    "closure_stage_rows": len(closure_rows),
    "ready_closure_stage_rows": ready_stage_rows,
    "blocked_closure_stage_rows": blocked_stage_rows,
    "return_bundle_dir_supplied": int(bundle_supplied),
    "schema_preflight_pass": as_int(v61dr, "schema_preflight_pass"),
    "return_bundle_preflight_pass": as_int(v53am, "return_bundle_preflight_pass"),
    "accepted_payload_rows": as_int(v61ds, "accepted_payload_rows"),
    "return_acceptance_replay_closed": as_int(v53am, "return_acceptance_replay_closed"),
    "actual_model_generation_ready": as_int(v53am, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_downloaded_by_v61dt": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dt_return_bundle_closure_replay_gate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"v61dt_return_bundle_closure_replay_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
