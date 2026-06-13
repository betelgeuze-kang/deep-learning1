#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dq_return_schema_remediation_packet_gate"
RUN_ID="${V61DQ_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dq_return_schema_remediation_packet_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dp_return_schema_acceptance_blocker_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import defaultdict
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
    "v61dp_summary": results / "v61dp_return_schema_acceptance_blocker_gate_summary.csv",
    "v61dp_decision": results / "v61dp_return_schema_acceptance_blocker_gate_decision.csv",
    "v61dp_family": results / "v61dp_return_schema_acceptance_blocker_gate/schema_001/return_schema_acceptance_blocker_family_rows.csv",
    "dispatch_receipts": results / "v53ab_complete_source_review_dispatch_receipt_packet/dispatch_001/complete_source_review_dispatch_receipt_template_rows.csv",
    "review_chunk_artifacts": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_artifact_rows.csv",
    "review_required_fields": results / "v53s_complete_source_review_return_intake/intake_001/review_return_required_field_rows.csv",
    "generation_required_fields": results / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_required_field_rows.csv",
    "generation_templates": results / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_template_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dq source {key}: {path}")

copy(sources["v61dp_summary"], "source_v61dp/v61dp_return_schema_acceptance_blocker_gate_summary.csv")
copy(sources["v61dp_decision"], "source_v61dp/v61dp_return_schema_acceptance_blocker_gate_decision.csv")
copy(sources["v61dp_family"], "source_v61dp/return_schema_acceptance_blocker_family_rows.csv")
copy(sources["dispatch_receipts"], "source_v53ab/complete_source_review_dispatch_receipt_template_rows.csv")
copy(sources["review_chunk_artifacts"], "source_v53w/review_return_chunk_artifact_rows.csv")
copy(sources["review_required_fields"], "source_v53s/review_return_required_field_rows.csv")
copy(sources["generation_required_fields"], "source_v61bt/actual_generation_result_required_field_rows.csv")
copy(sources["generation_templates"], "source_v61bt/actual_generation_result_template_rows.csv")

v61dp = read_csv(sources["v61dp_summary"])[0]
families = read_csv(sources["v61dp_family"])
dispatch_receipts = read_csv(sources["dispatch_receipts"])
review_chunk_artifacts = read_csv(sources["review_chunk_artifacts"])
review_fields = read_csv(sources["review_required_fields"])
generation_fields = read_csv(sources["generation_required_fields"])

if v61dp.get("v61dp_return_schema_acceptance_blocker_gate_ready") != "1":
    raise SystemExit("v61dq requires v61dp ready")

review_fields_by_artifact = defaultdict(list)
for row in review_fields:
    if row["field_name"] == "json_document":
        continue
    review_fields_by_artifact[row["return_artifact"]].append(row["field_name"])

generation_fields_by_artifact = defaultdict(list)
for row in generation_fields:
    generation_fields_by_artifact[row["result_artifact"]].append(row["field_name"])

artifact_rows = []
for row in dispatch_receipts:
    artifact_rows.append(
        {
            "schema_family": "dispatch-receipt-json",
            "artifact_path": row["expected_receipt_artifact"],
            "artifact_name": Path(row["expected_receipt_artifact"]).name,
            "expected_rows": "1",
            "required_field_count": "3",
            "required_fields": "review_chunk_id;archive_sha256;reviewer_or_coordinator_id",
            "template_source": "v53ab_complete_source_review_dispatch_receipt_packet",
            "validator_gate": "v53ad_complete_source_review_dispatch_receipt_intake",
            "remediation_status": "needs-valid-json-payload",
        }
    )
for row in review_chunk_artifacts:
    fields = review_fields_by_artifact[row["artifact_family"]]
    artifact_rows.append(
        {
            "schema_family": "review-chunk-return-csv",
            "artifact_path": row["return_artifact"],
            "artifact_name": row["artifact_family"],
            "expected_rows": row["expected_rows"],
            "required_field_count": str(len(fields)),
            "required_fields": ";".join(fields),
            "template_source": "v53w/v53s_review_return_chunk_queue",
            "validator_gate": "v53x_complete_source_review_chunk_return_intake",
            "remediation_status": "needs-csv-fields-and-row-counts",
        }
    )
for artifact_name in [
    "human_review_rows.csv",
    "adjudication_rows.csv",
    "reviewer_identity_rows.csv",
    "reviewer_conflict_rows.csv",
    "acceptance_summary.json",
]:
    fields = review_fields_by_artifact[artifact_name]
    expected_rows = {
        "human_review_rows.csv": "7000",
        "adjudication_rows.csv": "1000",
        "reviewer_identity_rows.csv": "21",
        "reviewer_conflict_rows.csv": "210",
        "acceptance_summary.json": "1",
    }[artifact_name]
    artifact_rows.append(
        {
            "schema_family": "aggregate-review-return",
            "artifact_path": f"aggregate_review_return/{artifact_name}",
            "artifact_name": artifact_name,
            "expected_rows": expected_rows,
            "required_field_count": str(len(fields)),
            "required_fields": ";".join(fields) if fields else "json_document",
            "template_source": "v53s_complete_source_review_return_intake",
            "validator_gate": "v53s/v53y/v53v",
            "remediation_status": "needs-aggregate-review-artifact",
        }
    )
for artifact_name, fields in sorted(generation_fields_by_artifact.items()):
    expected_rows = "1" if artifact_name.endswith(".json") else "1000"
    artifact_rows.append(
        {
            "schema_family": "generation-result-return",
            "artifact_path": f"generation_result_return/{artifact_name}",
            "artifact_name": artifact_name,
            "expected_rows": expected_rows,
            "required_field_count": str(len(fields)),
            "required_fields": ";".join(fields) if fields else "json_document",
            "template_source": "v61bt_ubuntu1_actual_generation_result_intake",
            "validator_gate": "v61bt/v61cu/v61de",
            "remediation_status": "needs-generation-result-artifact",
        }
    )
write_csv(run_dir / "return_schema_remediation_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

family_source = {row["acceptance_family"]: row for row in families}
family_rows = []
for family in [
    "dispatch-receipt-json",
    "review-chunk-return-csv",
    "aggregate-review-return",
    "generation-result-return",
]:
    related = [row for row in artifact_rows if row["schema_family"] == family]
    source = family_source[family]
    family_rows.append(
        {
            "schema_family": family,
            "remediation_artifact_rows": str(len(related)),
            "expected_artifact_rows": source["expected_artifact_rows"],
            "accepted_artifact_rows": source["accepted_artifact_rows"],
            "missing_artifact_rows": source["missing_artifact_rows"],
            "invalid_artifact_rows": source["invalid_artifact_rows"],
            "expected_payload_rows": source["expected_payload_rows"],
            "accepted_payload_rows": source["accepted_payload_rows"],
            "required_field_total": str(sum(as_int(row, "required_field_count") for row in related)),
            "validator_gate": related[0]["validator_gate"],
            "remediation_ready": "1",
            "acceptance_ready": source["acceptance_ready"],
            "operator_action": source["blocking_reason"],
        }
    )
write_csv(run_dir / "return_schema_remediation_family_rows.csv", list(family_rows[0].keys()), family_rows)

templates_dir = run_dir / "schema_remediation_templates"
templates_dir.mkdir(parents=True, exist_ok=True)
(templates_dir / "dispatch_receipt_template.json").write_text(
    json.dumps(
        {
            "review_chunk_id": "replace-with-review_chunk_id",
            "archive_sha256": "sha256:replace-with-dispatch-archive-sha256",
            "reviewer_or_coordinator_id": "replace-with-operator-id",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
for artifact_name, fields in sorted(review_fields_by_artifact.items()):
    if artifact_name.endswith(".csv") and fields:
        (templates_dir / f"{artifact_name}.header").write_text(",".join(fields) + "\n", encoding="utf-8")
(templates_dir / "acceptance_summary.template.json").write_text(
    json.dumps(
        {
            "accepted_human_review_rows": 0,
            "accepted_adjudication_rows": 0,
            "human_review_rows_sha256": "sha256:replace-with-human-review-rows-hash",
            "adjudication_rows_sha256": "sha256:replace-with-adjudication-rows-hash",
            "reviewer_identity_rows_sha256": "sha256:replace-with-reviewer-identity-rows-hash",
            "reviewer_conflict_rows_sha256": "sha256:replace-with-reviewer-conflict-rows-hash",
            "acceptance_decision": "replace-with-review-acceptance-decision",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
for artifact_name, fields in sorted(generation_fields_by_artifact.items()):
    if artifact_name.endswith(".csv") and fields:
        (templates_dir / f"{artifact_name}.header").write_text(",".join(fields) + "\n", encoding="utf-8")
(templates_dir / "real_model_generation_acceptance_summary.template.json").write_text(
    json.dumps(
        {field: f"replace-with-{field}" for field in generation_fields_by_artifact["real_model_generation_acceptance_summary.json"]},
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

command_rows = [
    {
        "command_id": "01-validate-dispatch-receipts",
        "ready_to_run_now": "1",
        "command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
        "expected_transition": "accepted_dispatch_receipt_rows=21",
    },
    {
        "command_id": "02-validate-review-chunk-returns",
        "ready_to_run_now": "1",
        "command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle/review_chunk_returns V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
        "expected_transition": "accepted_chunk_return_artifact_rows=50",
    },
    {
        "command_id": "03-validate-aggregate-review-return",
        "ready_to_run_now": "1",
        "command": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "expected_transition": "answer_review_accepted_rows=7000 and accepted_adjudication_rows=1000",
    },
    {
        "command_id": "04-validate-generation-result-return",
        "ready_to_run_now": "0",
        "command": "V61BT_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "expected_transition": "accepted_generation_result_artifacts=5 only after guarded generation",
    },
]
write_csv(run_dir / "return_schema_remediation_command_rows.csv", list(command_rows[0].keys()), command_rows)

remediation_artifact_rows = len(artifact_rows)
remediation_family_rows = len(family_rows)
template_file_rows = len(list(templates_dir.iterdir()))
expected_artifact_rows = sum(as_int(row, "expected_artifact_rows") for row in family_rows)
accepted_artifact_rows = sum(as_int(row, "accepted_artifact_rows") for row in family_rows)
expected_payload_rows = sum(as_int(row, "expected_payload_rows") for row in family_rows)
accepted_payload_rows = sum(as_int(row, "accepted_payload_rows") for row in family_rows)

metric = {
    "metric_id": "v61dq_return_schema_remediation_packet_gate_metrics",
    "v61dp_return_schema_acceptance_blocker_gate_ready": v61dp["v61dp_return_schema_acceptance_blocker_gate_ready"],
    "source_gate_rows": "1",
    "remediation_packet_ready": "1",
    "remediation_family_rows": str(remediation_family_rows),
    "remediation_artifact_rows": str(remediation_artifact_rows),
    "template_file_rows": str(template_file_rows),
    "remediation_command_rows": str(len(command_rows)),
    "ready_remediation_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "expected_schema_artifact_rows": str(expected_artifact_rows),
    "accepted_schema_artifact_rows": str(accepted_artifact_rows),
    "expected_payload_rows": str(expected_payload_rows),
    "accepted_payload_rows": str(accepted_payload_rows),
    "schema_acceptance_ready": v61dp["schema_acceptance_ready"],
    "return_bundle_preflight_pass": v61dp["return_bundle_preflight_pass"],
    "preflight_only_gap_detected": v61dp["preflight_only_gap_detected"],
    "actual_model_generation_ready": v61dp["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_schema_remediation_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dq_return_schema_remediation_packet_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "remediation-packet-surface", "status": "pass", "reason": f"remediation_artifact_rows={remediation_artifact_rows}"},
    {"gate": "schema-acceptance", "status": "blocked", "reason": f"accepted_payload_rows={accepted_payload_rows}/{expected_payload_rows}"},
    {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": "schema-remediation-packet", "status": "ready", "reason": f"remediation_artifact_rows={remediation_artifact_rows}"},
    {"gap": "schema-acceptance", "status": "blocked", "reason": f"accepted_schema_artifact_rows={accepted_artifact_rows}/{expected_artifact_rows}"},
    {"gap": "payload-row-acceptance", "status": "blocked", "reason": f"accepted_payload_rows={accepted_payload_rows}/{expected_payload_rows}"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dq Return Schema Remediation Packet Gate

This gate turns the v61dp schema/row blockers into an operator-facing schema
remediation packet. It does not create accepted review rows, generation rows,
latency evidence, near-frontier quality, or release readiness.

Evidence emitted:

- remediation_packet_ready=1
- remediation_family_rows={remediation_family_rows}
- remediation_artifact_rows={remediation_artifact_rows}
- template_file_rows={template_file_rows}
- remediation_command_rows={len(command_rows)}
- ready_remediation_command_rows={metric['ready_remediation_command_rows']}
- expected_schema_artifact_rows={expected_artifact_rows}
- accepted_schema_artifact_rows={accepted_artifact_rows}
- expected_payload_rows={expected_payload_rows}
- accepted_payload_rows={accepted_payload_rows}
- return_bundle_preflight_pass={v61dp['return_bundle_preflight_pass']}
- preflight_only_gap_detected={v61dp['preflight_only_gap_detected']}
- actual_model_generation_ready={v61dp['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dq=0

Allowed wording: schema remediation packet is ready.
Blocked wording: schema accepted, review accepted, generation accepted,
actual generation, v1.0 comparison, latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61DQ_RETURN_SCHEMA_REMEDIATION_PACKET_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dq-return-schema-remediation-packet-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dq_return_schema_remediation_packet_gate_ready": 1,
    "remediation_artifact_rows": remediation_artifact_rows,
    "template_file_rows": template_file_rows,
    "accepted_payload_rows": accepted_payload_rows,
    "actual_model_generation_ready": as_int(v61dp, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dq_return_schema_remediation_packet_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dq_return_schema_remediation_packet_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
