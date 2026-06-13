#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ds_schema_preflight_acceptance_handoff_gate"
RUN_ID="${V61DS_RUN_ID:-handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ds_schema_preflight_acceptance_handoff_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null

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


def ready(condition):
    return "ready" if condition else "blocked"


sources = {
    "v61dr_summary": results / "v61dr_return_bundle_schema_preflight_gate_summary.csv",
    "v61dr_decision": results / "v61dr_return_bundle_schema_preflight_gate_decision.csv",
    "v61dr_family": results / "v61dr_return_bundle_schema_preflight_gate/preflight_001/return_bundle_schema_preflight_family_rows.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_decision": results / "v53am_complete_source_return_acceptance_replay_decision.csv",
    "v53am_steps": results / "v53am_complete_source_return_acceptance_replay/replay_001/return_acceptance_replay_step_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ds source {key}: {path}")

copy(sources["v61dr_summary"], "source_v61dr/v61dr_return_bundle_schema_preflight_gate_summary.csv")
copy(sources["v61dr_decision"], "source_v61dr/v61dr_return_bundle_schema_preflight_gate_decision.csv")
copy(sources["v61dr_family"], "source_v61dr/return_bundle_schema_preflight_family_rows.csv")
copy(sources["v53am_summary"], "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv")
copy(sources["v53am_decision"], "source_v53am/v53am_complete_source_return_acceptance_replay_decision.csv")
copy(sources["v53am_steps"], "source_v53am/return_acceptance_replay_step_rows.csv")

v61dr = read_csv(sources["v61dr_summary"])[0]
v53am = read_csv(sources["v53am_summary"])[0]
v61dr_family_rows = read_csv(sources["v61dr_family"])

if v61dr.get("v61dr_return_bundle_schema_preflight_gate_ready") != "1":
    raise SystemExit("v61ds requires v61dr ready")
if v53am.get("v53am_complete_source_return_acceptance_replay_ready") != "1":
    raise SystemExit("v61ds requires v53am ready")

schema_preflight_surface_ready = as_int(v61dr, "schema_preflight_artifact_rows") == 81
schema_preflight_pass = as_int(v61dr, "schema_preflight_pass")
bundle_supplied = as_int(v61dr, "return_bundle_dir_supplied")
bundle_exists = as_int(v61dr, "return_bundle_dir_exists")
dispatch_ready = as_int(v53am, "accepted_dispatch_receipt_rows") == as_int(v53am, "dispatch_receipt_template_rows") and as_int(v53am, "dispatch_receipt_template_rows") > 0
chunk_ready = as_int(v53am, "accepted_chunk_return_artifact_rows") == as_int(v53am, "review_chunk_return_artifact_rows") and as_int(v53am, "review_chunk_return_artifact_rows") > 0
review_ready = as_int(v53am, "review_return_ready")
v53_ready = as_int(v53am, "v53_ready")
full_runtime_ready = as_int(v53am, "full_shard_prerequisites_closed") and as_int(v53am, "runtime_admission_accepted_rows") == 1000
generation_execution_ready = as_int(v53am, "generation_execution_admitted_rows") == as_int(v53am, "generation_execution_admission_rows") and as_int(v53am, "generation_execution_admission_rows") > 0
generation_artifact_ready = as_int(v53am, "accepted_generation_result_artifacts") == as_int(v53am, "expected_generation_result_artifacts") and as_int(v53am, "expected_generation_result_artifacts") > 0
generation_result_ready = as_int(v53am, "generation_result_accepted_rows") == as_int(v53am, "generation_result_acceptance_rows") and as_int(v53am, "generation_result_acceptance_rows") > 0
actual_generation_ready = as_int(v53am, "actual_model_generation_ready")

handoff_rows = [
    {
        "handoff_stage_id": "01-schema-preflight-surface",
        "source_gate": "v61dr",
        "status": ready(schema_preflight_surface_ready),
        "actual_value": f"schema_preflight_artifact_rows={v61dr['schema_preflight_artifact_rows']}",
        "blocking_reason": "ready" if schema_preflight_surface_ready else "v61dr schema surface is incomplete",
        "next_command": "V61DR_REUSE_EXISTING=0 ./experiments/run_v61dr_return_bundle_schema_preflight_gate.sh",
    },
    {
        "handoff_stage_id": "02-return-bundle-supplied",
        "source_gate": "v61dr",
        "status": ready(bundle_supplied and bundle_exists),
        "actual_value": f"return_bundle_dir_supplied={bundle_supplied}; return_bundle_dir_exists={bundle_exists}",
        "blocking_reason": "final return bundle directory is not supplied" if not bundle_supplied else "final return bundle directory does not exist",
        "next_command": "V61DR_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DR_REUSE_EXISTING=0 ./experiments/run_v61dr_return_bundle_schema_preflight_gate.sh",
    },
    {
        "handoff_stage_id": "03-schema-preflight-pass",
        "source_gate": "v61dr",
        "status": ready(schema_preflight_pass),
        "actual_value": f"schema_preflight_pass_rows={v61dr['schema_preflight_pass_rows']}/{v61dr['schema_preflight_artifact_rows']}",
        "blocking_reason": "full return bundle schema preflight has not passed",
        "next_command": "results/v61dr_return_bundle_schema_preflight_gate/preflight_001/VERIFY_RETURN_SCHEMA_PREFLIGHT.sh /path/to/final_return_bundle",
    },
    {
        "handoff_stage_id": "04-dispatch-receipts-accepted",
        "source_gate": "v53am/v53ad",
        "status": ready(dispatch_ready),
        "actual_value": f"accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}",
        "blocking_reason": "dispatch receipts are not accepted by downstream intake",
        "next_command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
    },
    {
        "handoff_stage_id": "05-review-chunks-accepted",
        "source_gate": "v53am/v53x",
        "status": ready(chunk_ready),
        "actual_value": f"accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}",
        "blocking_reason": "review chunk return artifacts are not accepted by downstream intake",
        "next_command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
    },
    {
        "handoff_stage_id": "06-aggregate-review-accepted",
        "source_gate": "v53am/v53y",
        "status": ready(review_ready),
        "actual_value": f"answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}; accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}",
        "blocking_reason": "aggregate human/source review and adjudication are not accepted",
        "next_command": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
    },
    {
        "handoff_stage_id": "07-v53-review-ready",
        "source_gate": "v53am/v53v",
        "status": ready(v53_ready),
        "actual_value": f"review_return_ready={v53am['review_return_ready']}; v53_ready={v53am['v53_ready']}",
        "blocking_reason": "v53 complete-source review acceptance is not closed",
        "next_command": "V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
    },
    {
        "handoff_stage_id": "08-full-shard-runtime-closed",
        "source_gate": "v53am/v61",
        "status": ready(full_runtime_ready),
        "actual_value": f"full_shard_prerequisites_closed={v53am['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v53am['runtime_admission_accepted_rows']}",
        "blocking_reason": "ready" if full_runtime_ready else "full-shard/runtime context is incomplete",
        "next_command": "V61DG_REUSE_EXISTING=1 ./experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh",
    },
    {
        "handoff_stage_id": "09-generation-execution-admitted",
        "source_gate": "v53am/v61de",
        "status": ready(generation_execution_ready),
        "actual_value": f"generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}",
        "blocking_reason": "generation execution is not admitted",
        "next_command": "V61DE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
    },
    {
        "handoff_stage_id": "10-generation-result-artifacts-accepted",
        "source_gate": "v53am/v61bt",
        "status": ready(generation_artifact_ready),
        "actual_value": f"accepted_generation_result_artifacts={v53am['accepted_generation_result_artifacts']}/{v53am['expected_generation_result_artifacts']}",
        "blocking_reason": "generation result artifacts are not accepted",
        "next_command": "V61BT_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
    },
    {
        "handoff_stage_id": "11-generation-result-rows-accepted",
        "source_gate": "v53am/v61cu",
        "status": ready(generation_result_ready),
        "actual_value": f"generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}",
        "blocking_reason": "generation result rows are not accepted",
        "next_command": "V61CU_REUSE_EXISTING=0 ./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh",
    },
    {
        "handoff_stage_id": "12-actual-generation-ready",
        "source_gate": "v53am/v61de",
        "status": ready(actual_generation_ready),
        "actual_value": f"actual_model_generation_ready={v53am['actual_model_generation_ready']}",
        "blocking_reason": "actual generation remains unproven",
        "next_command": "V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
    },
]
write_csv(run_dir / "schema_preflight_acceptance_handoff_stage_rows.csv", list(handoff_rows[0].keys()), handoff_rows)

family_rows = []
for row in v61dr_family_rows:
    family_rows.append(
        {
            "schema_family": row["schema_family"],
            "schema_preflight_ready": row["schema_preflight_ready"],
            "schema_preflight_pass_artifact_rows": row["schema_preflight_pass_artifact_rows"],
            "expected_artifact_rows": row["expected_artifact_rows"],
            "expected_row_instances": row["expected_row_instances"],
            "observed_row_instances": row["observed_row_instances"],
            "accepted_payload_rows": row["accepted_payload_rows"],
            "acceptance_ready": row["acceptance_ready"],
            "validator_gate": row["validator_gate"],
        }
    )
write_csv(run_dir / "schema_preflight_acceptance_family_handoff_rows.csv", list(family_rows[0].keys()), family_rows)

command_rows = [
    {
        "command_id": f"{index:02d}-{row['handoff_stage_id']}",
        "ready_to_run_now": "1" if row["status"] == "ready" or index <= 3 else "0",
        "handoff_stage_id": row["handoff_stage_id"],
        "command": row["next_command"],
        "expected_transition": row["blocking_reason"],
    }
    for index, row in enumerate(handoff_rows, start=1)
]
write_csv(run_dir / "schema_preflight_acceptance_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

ready_stage_rows = sum(row["status"] == "ready" for row in handoff_rows)
blocked_stage_rows = len(handoff_rows) - ready_stage_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
accepted_payload_rows = as_int(v53am, "accepted_dispatch_receipt_rows") + as_int(v53am, "accepted_chunk_return_artifact_rows") + as_int(v53am, "answer_review_accepted_rows") + as_int(v53am, "accepted_adjudication_rows") + as_int(v53am, "generation_result_accepted_rows")

metric = {
    "metric_id": "v61ds_schema_preflight_acceptance_handoff_gate_metrics",
    "v61dr_return_bundle_schema_preflight_gate_ready": v61dr["v61dr_return_bundle_schema_preflight_gate_ready"],
    "v53am_complete_source_return_acceptance_replay_ready": v53am["v53am_complete_source_return_acceptance_replay_ready"],
    "source_gate_rows": "2",
    "handoff_stage_rows": str(len(handoff_rows)),
    "ready_handoff_stage_rows": str(ready_stage_rows),
    "blocked_handoff_stage_rows": str(blocked_stage_rows),
    "handoff_command_rows": str(len(command_rows)),
    "ready_handoff_command_rows": str(ready_command_rows),
    "return_bundle_dir_supplied": v61dr["return_bundle_dir_supplied"],
    "schema_preflight_artifact_rows": v61dr["schema_preflight_artifact_rows"],
    "schema_preflight_pass_rows": v61dr["schema_preflight_pass_rows"],
    "schema_preflight_pass": v61dr["schema_preflight_pass"],
    "schema_family_ready_rows": v61dr["schema_family_ready_rows"],
    "expected_schema_artifact_rows": v61dr["expected_schema_artifact_rows"],
    "expected_artifact_row_instances": v61dr["expected_artifact_row_instances"],
    "observed_artifact_row_instances": v61dr["observed_artifact_row_instances"],
    "expected_payload_rows": v61dr["expected_payload_rows"],
    "accepted_payload_rows": str(accepted_payload_rows),
    "accepted_dispatch_receipt_rows": v53am["accepted_dispatch_receipt_rows"],
    "accepted_chunk_return_artifact_rows": v53am["accepted_chunk_return_artifact_rows"],
    "answer_review_accepted_rows": v53am["answer_review_accepted_rows"],
    "accepted_adjudication_rows": v53am["accepted_adjudication_rows"],
    "generation_execution_admitted_rows": v53am["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53am["accepted_generation_result_artifacts"],
    "generation_result_accepted_rows": v53am["generation_result_accepted_rows"],
    "schema_acceptance_ready": "1" if schema_preflight_pass and accepted_payload_rows == as_int(v61dr, "expected_payload_rows") else "0",
    "return_acceptance_replay_closed": v53am["return_acceptance_replay_closed"],
    "actual_model_generation_ready": v53am["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ds": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "schema_preflight_acceptance_handoff_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ds_schema_preflight_acceptance_handoff_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["handoff_stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]}
    for row in handoff_rows
]
decision_rows.extend(
    [
        {"gate": "schema-to-acceptance-boundary", "status": "pass", "reason": "schema preflight does not imply downstream acceptance"},
        {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
        {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["handoff_stage_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in handoff_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61ds Schema Preflight Acceptance Handoff Gate

This gate binds v61dr's returned-bundle schema preflight to v53am's downstream
acceptance replay. It makes the boundary explicit: schema preflight readiness is
not review acceptance, generation result acceptance, actual generation, latency,
near-frontier quality, or release readiness.

Evidence emitted:

- handoff_stage_rows={len(handoff_rows)}
- ready_handoff_stage_rows={ready_stage_rows}
- blocked_handoff_stage_rows={blocked_stage_rows}
- schema_preflight_pass_rows={v61dr['schema_preflight_pass_rows']}/{v61dr['schema_preflight_artifact_rows']}
- schema_preflight_pass={v61dr['schema_preflight_pass']}
- expected_artifact_row_instances={v61dr['expected_artifact_row_instances']}
- observed_artifact_row_instances={v61dr['observed_artifact_row_instances']}
- expected_payload_rows={v61dr['expected_payload_rows']}
- accepted_payload_rows={accepted_payload_rows}
- schema_acceptance_ready={metric['schema_acceptance_ready']}
- actual_model_generation_ready={v53am['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61ds=0

Allowed wording: the schema-preflight-to-acceptance handoff is audited.
Blocked wording: review accepted, generation accepted, actual generation,
latency, near-frontier quality, v1.0 comparison, or release readiness.
"""
(run_dir / "V61DS_SCHEMA_PREFLIGHT_ACCEPTANCE_HANDOFF_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61ds-schema-preflight-acceptance-handoff-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ds_schema_preflight_acceptance_handoff_gate_ready": 1,
    "handoff_stage_rows": len(handoff_rows),
    "ready_handoff_stage_rows": ready_stage_rows,
    "schema_preflight_pass": as_int(v61dr, "schema_preflight_pass"),
    "accepted_payload_rows": accepted_payload_rows,
    "actual_model_generation_ready": as_int(v53am, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ds_schema_preflight_acceptance_handoff_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ds_schema_preflight_acceptance_handoff_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
