#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dv_return_bundle_operator_work_order"
RUN_ID="${V61DV_RUN_ID:-work_order_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dv_return_bundle_operator_work_order_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61du_return_bundle_acceptance_delta_ledger.sh" >/dev/null

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


sources = {
    "v61du_summary": results / "v61du_return_bundle_acceptance_delta_ledger_summary.csv",
    "v61du_decision": results / "v61du_return_bundle_acceptance_delta_ledger_decision.csv",
    "v61du_stage": results / "v61du_return_bundle_acceptance_delta_ledger/delta_001/return_bundle_acceptance_delta_stage_rows.csv",
    "v61du_family": results / "v61du_return_bundle_acceptance_delta_ledger/delta_001/return_bundle_acceptance_delta_family_rows.csv",
    "v61du_command": results / "v61du_return_bundle_acceptance_delta_ledger/delta_001/return_bundle_acceptance_delta_command_rows.csv",
    "v61dq_artifacts": results / "v61dq_return_schema_remediation_packet_gate/packet_001/return_schema_remediation_artifact_rows.csv",
    "v53ak_checklist": results / "v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_checklist_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dv source {key}: {path}")

copy(sources["v61du_summary"], "source_v61du/v61du_return_bundle_acceptance_delta_ledger_summary.csv")
copy(sources["v61du_decision"], "source_v61du/v61du_return_bundle_acceptance_delta_ledger_decision.csv")
copy(sources["v61du_stage"], "source_v61du/return_bundle_acceptance_delta_stage_rows.csv")
copy(sources["v61du_family"], "source_v61du/return_bundle_acceptance_delta_family_rows.csv")
copy(sources["v61du_command"], "source_v61du/return_bundle_acceptance_delta_command_rows.csv")
copy(sources["v61dq_artifacts"], "source_v61dq/return_schema_remediation_artifact_rows.csv")
copy(sources["v53ak_checklist"], "source_v53ak/external_return_operator_checklist_rows.csv")

v61du = read_csv(sources["v61du_summary"])[0]
artifact_source_rows = read_csv(sources["v61dq_artifacts"])
checklist_source_rows = read_csv(sources["v53ak_checklist"])
command_source_rows = read_csv(sources["v61du_command"])

if v61du.get("v61du_return_bundle_acceptance_delta_ledger_ready") != "1":
    raise SystemExit("v61dv requires v61du ready")
if len(artifact_source_rows) != 81:
    raise SystemExit("v61dv requires the 81-artifact return schema")
if len(checklist_source_rows) != 81:
    raise SystemExit("v61dv requires the 81-artifact v53ak checklist")

family_priority = {
    "dispatch-receipt-json": ("02-dispatch-receipts", "1", "prepare-valid-json-payloads"),
    "review-chunk-return-csv": ("03-review-chunk-returns", "1", "prepare-review-chunk-csv-payloads"),
    "aggregate-review-return": ("04-aggregate-review-return", "1", "prepare-human-review-adjudication-return"),
    "generation-result-return": ("08-generation-result-return", "0", "blocked-until-generation-execution"),
}
artifact_rows = []
for index, row in enumerate(artifact_source_rows, start=1):
    work_order_id, ready_to_prepare, operator_action = family_priority[row["schema_family"]]
    artifact_rows.append(
        {
            "artifact_work_order_id": f"artifact_{index:03d}",
            "work_order_id": work_order_id,
            "schema_family": row["schema_family"],
            "artifact_path": row["artifact_path"],
            "expected_rows": row["expected_rows"],
            "required_fields": row["required_fields"],
            "validator_gate": row["validator_gate"],
            "ready_to_prepare_now": ready_to_prepare,
            "operator_action": operator_action,
            "template_source": row["template_source"],
        }
    )
write_csv(run_dir / "return_bundle_operator_artifact_work_order_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

stage_rows = [
    {
        "work_order_id": "01-create-return-bundle-root",
        "priority": "1",
        "ready_to_execute_now": "1",
        "target": "final return bundle directory",
        "required_count": "1",
        "current_count": v61du["return_bundle_dir_exists"],
        "missing_count": "1" if v61du["return_bundle_dir_exists"] == "0" else "0",
        "blocking_gate": "v61dt-input",
        "operator_command": "mkdir -p /path/to/final_return_bundle",
    },
    {
        "work_order_id": "02-dispatch-receipts",
        "priority": "2",
        "ready_to_execute_now": "1",
        "target": "dispatch receipt JSON artifacts",
        "required_count": v61du["missing_dispatch_receipt_rows"],
        "current_count": "0",
        "missing_count": v61du["missing_dispatch_receipt_rows"],
        "blocking_gate": "v53ad",
        "operator_command": "write dispatch_receipts/*.json then run V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
    },
    {
        "work_order_id": "03-review-chunk-returns",
        "priority": "3",
        "ready_to_execute_now": "1",
        "target": "review chunk return CSV artifacts",
        "required_count": v61du["missing_review_chunk_artifact_rows"],
        "current_count": "0",
        "missing_count": v61du["missing_review_chunk_artifact_rows"],
        "blocking_gate": "v53x",
        "operator_command": "write chunks/* review return CSVs then run V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
    },
    {
        "work_order_id": "04-aggregate-review-return",
        "priority": "4",
        "ready_to_execute_now": "1",
        "target": "aggregate review/adjudication payload rows",
        "required_count": str(as_int(v61du, "missing_answer_review_rows") + as_int(v61du, "missing_adjudication_rows")),
        "current_count": "0",
        "missing_count": str(as_int(v61du, "missing_answer_review_rows") + as_int(v61du, "missing_adjudication_rows")),
        "blocking_gate": "v53y/v53v",
        "operator_command": "write aggregate_review_return/* then run V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
    },
    {
        "work_order_id": "05-schema-and-full-preflight",
        "priority": "5",
        "ready_to_execute_now": "0",
        "target": "81-artifact schema and full preflight",
        "required_count": "81",
        "current_count": "0",
        "missing_count": v61du["schema_preflight_missing_artifact_rows"],
        "blocking_gate": "v61dr/v53al",
        "operator_command": "run V61DT_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DT_REUSE_EXISTING=0 ./experiments/run_v61dt_return_bundle_closure_replay_gate.sh",
    },
    {
        "work_order_id": "06-review-acceptance-replay",
        "priority": "6",
        "ready_to_execute_now": "0",
        "target": "v53 return acceptance closure",
        "required_count": "1",
        "current_count": v61du["return_acceptance_replay_closed"],
        "missing_count": "1",
        "blocking_gate": "v53am",
        "operator_command": "run V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
    },
    {
        "work_order_id": "07-generation-execution-admission",
        "priority": "7",
        "ready_to_execute_now": "0",
        "target": "generation execution admission rows",
        "required_count": v61du["missing_generation_execution_rows"],
        "current_count": "0",
        "missing_count": v61du["missing_generation_execution_rows"],
        "blocking_gate": "v61de",
        "operator_command": "refresh V61DE after accepted review return",
    },
    {
        "work_order_id": "08-generation-result-return",
        "priority": "8",
        "ready_to_execute_now": "0",
        "target": "generation result return artifacts and accepted rows",
        "required_count": str(as_int(v61du, "missing_generation_result_artifacts") + as_int(v61du, "missing_generation_result_rows")),
        "current_count": "0",
        "missing_count": str(as_int(v61du, "missing_generation_result_artifacts") + as_int(v61du, "missing_generation_result_rows")),
        "blocking_gate": "v61bt/v61cu",
        "operator_command": "write generation_result_return/* after guarded generation then rerun v61bt/v61cu",
    },
    {
        "work_order_id": "09-actual-generation-ready",
        "priority": "9",
        "ready_to_execute_now": "0",
        "target": "actual generation readiness",
        "required_count": "1",
        "current_count": v61du["actual_model_generation_ready"],
        "missing_count": "1",
        "blocking_gate": "v61de",
        "operator_command": "blocked until review and generation result acceptance close",
    },
]
write_csv(run_dir / "return_bundle_operator_work_order_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

row_rows = [
    {"row_work_order_id": "row_001", "work_order_id": "01-create-return-bundle-root", "target": "return bundle directory", "required_count": "1", "observed_count": v61du["return_bundle_dir_exists"], "missing_count": "1" if v61du["return_bundle_dir_exists"] == "0" else "0", "unit": "directory"},
    {"row_work_order_id": "row_002", "work_order_id": "05-schema-and-full-preflight", "target": "schema preflight artifacts", "required_count": "81", "observed_count": "0", "missing_count": v61du["schema_preflight_missing_artifact_rows"], "unit": "artifact"},
    {"row_work_order_id": "row_003", "work_order_id": "05-schema-and-full-preflight", "target": "full preflight artifacts", "required_count": "81", "observed_count": "0", "missing_count": v61du["full_preflight_missing_artifact_rows"], "unit": "artifact"},
    {"row_work_order_id": "row_004", "work_order_id": "02-dispatch-receipts", "target": "dispatch receipt JSON", "required_count": "21", "observed_count": "0", "missing_count": v61du["missing_dispatch_receipt_rows"], "unit": "artifact"},
    {"row_work_order_id": "row_005", "work_order_id": "03-review-chunk-returns", "target": "review chunk CSV", "required_count": "50", "observed_count": "0", "missing_count": v61du["missing_review_chunk_artifact_rows"], "unit": "artifact"},
    {"row_work_order_id": "row_006", "work_order_id": "04-aggregate-review-return", "target": "human/source review rows", "required_count": "7000", "observed_count": "0", "missing_count": v61du["missing_answer_review_rows"], "unit": "row"},
    {"row_work_order_id": "row_007", "work_order_id": "04-aggregate-review-return", "target": "adjudication rows", "required_count": "1000", "observed_count": "0", "missing_count": v61du["missing_adjudication_rows"], "unit": "row"},
    {"row_work_order_id": "row_008", "work_order_id": "06-review-acceptance-replay", "target": "accepted payload rows", "required_count": "17483", "observed_count": "0", "missing_count": v61du["missing_payload_rows"], "unit": "row"},
    {"row_work_order_id": "row_009", "work_order_id": "07-generation-execution-admission", "target": "generation execution rows", "required_count": "1000", "observed_count": "0", "missing_count": v61du["missing_generation_execution_rows"], "unit": "row"},
    {"row_work_order_id": "row_010", "work_order_id": "08-generation-result-return", "target": "generation result artifacts", "required_count": "5", "observed_count": "0", "missing_count": v61du["missing_generation_result_artifacts"], "unit": "artifact"},
    {"row_work_order_id": "row_011", "work_order_id": "08-generation-result-return", "target": "generation result accepted rows", "required_count": "1000", "observed_count": "0", "missing_count": v61du["missing_generation_result_rows"], "unit": "row"},
]
write_csv(run_dir / "return_bundle_operator_row_work_order_rows.csv", list(row_rows[0].keys()), row_rows)

command_rows = []
for row in command_source_rows:
    command_rows.append(
        {
            "command_id": row["command_id"],
            "ready_to_run_now": row["ready_to_run_now"],
            "closure_stage_id": row["closure_stage_id"],
            "command": row["command"],
            "expected_transition": row["expected_transition"],
        }
    )
write_csv(run_dir / "return_bundle_operator_work_order_command_rows.csv", list(command_rows[0].keys()), command_rows)

ready_stage_rows = sum(row["ready_to_execute_now"] == "1" for row in stage_rows)
ready_artifact_rows = sum(row["ready_to_prepare_now"] == "1" for row in artifact_rows)
blocked_artifact_rows = len(artifact_rows) - ready_artifact_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)

metric = {
    "metric_id": "v61dv_return_bundle_operator_work_order_metrics",
    "v61du_return_bundle_acceptance_delta_ledger_ready": v61du["v61du_return_bundle_acceptance_delta_ledger_ready"],
    "source_gate_rows": "3",
    "work_order_stage_rows": str(len(stage_rows)),
    "ready_work_order_stage_rows": str(ready_stage_rows),
    "blocked_work_order_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "artifact_work_order_rows": str(len(artifact_rows)),
    "ready_artifact_work_order_rows": str(ready_artifact_rows),
    "blocked_artifact_work_order_rows": str(blocked_artifact_rows),
    "row_work_order_rows": str(len(row_rows)),
    "open_row_work_order_rows": str(sum(row["missing_count"] != "0" for row in row_rows)),
    "work_order_command_rows": str(len(command_rows)),
    "ready_work_order_command_rows": str(ready_command_rows),
    "dispatch_receipt_artifact_work_order_rows": str(sum(row["schema_family"] == "dispatch-receipt-json" for row in artifact_rows)),
    "review_chunk_artifact_work_order_rows": str(sum(row["schema_family"] == "review-chunk-return-csv" for row in artifact_rows)),
    "aggregate_review_artifact_work_order_rows": str(sum(row["schema_family"] == "aggregate-review-return" for row in artifact_rows)),
    "generation_result_artifact_work_order_rows": str(sum(row["schema_family"] == "generation-result-return" for row in artifact_rows)),
    "missing_payload_rows": v61du["missing_payload_rows"],
    "missing_answer_review_rows": v61du["missing_answer_review_rows"],
    "missing_adjudication_rows": v61du["missing_adjudication_rows"],
    "missing_generation_execution_rows": v61du["missing_generation_execution_rows"],
    "missing_generation_result_artifacts": v61du["missing_generation_result_artifacts"],
    "missing_generation_result_rows": v61du["missing_generation_result_rows"],
    "schema_acceptance_ready": v61du["schema_acceptance_ready"],
    "return_acceptance_replay_closed": v61du["return_acceptance_replay_closed"],
    "actual_model_generation_ready": v61du["actual_model_generation_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61dv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_bundle_operator_work_order_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dv_return_bundle_operator_work_order_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["work_order_id"], "status": "pass" if row["ready_to_execute_now"] == "1" else "blocked", "reason": f"missing_count={row['missing_count']} target={row['target']}"}
    for row in stage_rows
]
decision_rows.extend(
    [
        {"gate": "operator-work-order-ready", "status": "pass", "reason": "return bundle delta ledger is converted to staged operator work"},
        {"gate": "generation-result-work", "status": "blocked", "reason": "generation result artifacts are blocked until generation execution is admitted"},
        {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
        {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["work_order_id"], "status": "ready" if row["ready_to_execute_now"] == "1" else "blocked", "reason": row["target"]}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dv Return Bundle Operator Work Order

This gate turns v61du's target/observed/missing deltas into staged operator
work. It does not fabricate returned evidence and does not execute generation.

Evidence emitted:

- work_order_stage_rows={len(stage_rows)}
- ready_work_order_stage_rows={ready_stage_rows}
- blocked_work_order_stage_rows={len(stage_rows) - ready_stage_rows}
- artifact_work_order_rows={len(artifact_rows)}
- ready_artifact_work_order_rows={ready_artifact_rows}
- blocked_artifact_work_order_rows={blocked_artifact_rows}
- row_work_order_rows={len(row_rows)}
- open_row_work_order_rows={metric['open_row_work_order_rows']}
- dispatch_receipt_artifact_work_order_rows={metric['dispatch_receipt_artifact_work_order_rows']}
- review_chunk_artifact_work_order_rows={metric['review_chunk_artifact_work_order_rows']}
- aggregate_review_artifact_work_order_rows={metric['aggregate_review_artifact_work_order_rows']}
- generation_result_artifact_work_order_rows={metric['generation_result_artifact_work_order_rows']}
- missing_payload_rows={v61du['missing_payload_rows']}
- missing_answer_review_rows={v61du['missing_answer_review_rows']}
- missing_adjudication_rows={v61du['missing_adjudication_rows']}
- missing_generation_execution_rows={v61du['missing_generation_execution_rows']}
- missing_generation_result_artifacts={v61du['missing_generation_result_artifacts']}
- missing_generation_result_rows={v61du['missing_generation_result_rows']}
- actual_model_generation_ready={v61du['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dv=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: return-bundle operator work order is ready.
Blocked wording: returned evidence accepted, actual generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DV_RETURN_BUNDLE_OPERATOR_WORK_ORDER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dv-return-bundle-operator-work-order",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dv_return_bundle_operator_work_order_ready": 1,
    "work_order_stage_rows": len(stage_rows),
    "ready_work_order_stage_rows": ready_stage_rows,
    "artifact_work_order_rows": len(artifact_rows),
    "ready_artifact_work_order_rows": ready_artifact_rows,
    "blocked_artifact_work_order_rows": blocked_artifact_rows,
    "missing_payload_rows": as_int(v61du, "missing_payload_rows"),
    "actual_model_generation_ready": as_int(v61du, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_downloaded_by_v61dv": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dv_return_bundle_operator_work_order_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"v61dv_return_bundle_operator_work_order_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
