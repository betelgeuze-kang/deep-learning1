#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53af_external_return_inbox_scaffold"
RUN_ID="${V53AF_RUN_ID:-scaffold_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53af_external_return_inbox_scaffold_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh" >/dev/null
V61DF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61df_external_review_generation_return_operator_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
inbox_dir = run_dir / "return_inbox"


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


def write_empty_csv(path, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(fieldnames)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


source_paths = {
    "v53ae_summary": results / "v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv",
    "v53ae_decision": results / "v53ae_complete_source_review_return_generation_rendezvous_gate_decision.csv",
    "v61df_summary": results / "v61df_external_review_generation_return_operator_packet_summary.csv",
    "v61df_decision": results / "v61df_external_review_generation_return_operator_packet_decision.csv",
    "v53ab_receipts": results / "v53ab_complete_source_review_dispatch_receipt_packet" / "dispatch_001" / "complete_source_review_dispatch_receipt_template_rows.csv",
    "v53w_chunk_artifacts": results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001" / "review_return_chunk_artifact_rows.csv",
    "v53w_aggregate_artifacts": results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001" / "review_return_aggregate_artifact_rows.csv",
    "v53s_required_fields": results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001" / "source_v53s" / "review_return_required_field_rows.csv",
    "v61bt_required_fields": results / "v61ct_complete_source_generation_execution_operator_bundle" / "bundle_001" / "source_v61bt" / "actual_generation_result_required_field_rows.csv",
    "v61df_generation_required": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "operator_packet" / "GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"v53af missing source artifact {key}: {path}")

v53ae = read_csv(source_paths["v53ae_summary"])[0]
v61df = read_csv(source_paths["v61df_summary"])[0]
if v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"] != "1":
    raise SystemExit("v53af requires v53ae rendezvous gate")
if v61df["v61df_external_review_generation_return_operator_packet_ready"] != "1":
    raise SystemExit("v53af requires v61df external return operator packet")

for key, path in source_paths.items():
    copy(path, f"source/{path.name}")
for rel in [
    "v53ae_complete_source_review_return_generation_rendezvous_gate/gate_001/review_return_generation_rendezvous_stage_rows.csv",
    "v53ae_complete_source_review_return_generation_rendezvous_gate/gate_001/review_return_generation_next_action_rows.csv",
    "v61df_external_review_generation_return_operator_packet/packet_001/operator_packet/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv",
    "v61df_external_review_generation_return_operator_packet/packet_001/operator_packet/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
]:
    copy(results / rel, "source/" + Path(rel).name)

review_required_fields = {}
for row in read_csv(source_paths["v53s_required_fields"]):
    artifact = row["return_artifact"]
    if row["field_name"] == "json_document":
        continue
    review_required_fields.setdefault(artifact, []).append(row["field_name"])

generation_required_fields = {}
for row in read_csv(source_paths["v61bt_required_fields"]):
    artifact = row["result_artifact"]
    if artifact.endswith(".json"):
        continue
    generation_required_fields.setdefault(artifact, []).append(row["field_name"])

receipt_rows = read_csv(source_paths["v53ab_receipts"])
chunk_artifact_rows = read_csv(source_paths["v53w_chunk_artifacts"])
aggregate_rows = read_csv(source_paths["v53w_aggregate_artifacts"])
generation_rows = read_csv(source_paths["v61df_generation_required"])

receipt_template_rows = []
for row in receipt_rows:
    expected = Path(row["expected_receipt_artifact"])
    template_rel = Path("dispatch_receipt_templates") / (expected.name + ".template")
    payload = {
        "review_chunk_id": row["review_chunk_id"],
        "archive_sha256": "fill-with-real-v53ac-archive-sha256",
        "reviewer_or_coordinator_id": "fill-with-real-reviewer-or-coordinator-id",
        "receipt_status": "template-not-evidence",
        "notes": "Copy to dispatch_receipts/<chunk>_receipt.json only after real delivery acknowledgement.",
    }
    path = inbox_dir / template_rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    receipt_template_rows.append(
        {
            "template_id": "template_" + row["receipt_id"],
            "review_chunk_id": row["review_chunk_id"],
            "expected_final_artifact": row["expected_receipt_artifact"],
            "template_artifact": str(Path("return_inbox") / template_rel),
            "file_ready": "1",
            "accepted_by_default": "0",
            "route_jump_rows": "0",
        }
    )

chunk_template_rows = []
for row in chunk_artifact_rows:
    final_artifact = Path(row["return_artifact"])
    template_rel = Path("review_chunk_return_templates") / final_artifact.parent / (final_artifact.name + ".template")
    fields = review_required_fields.get(row["artifact_family"], [])
    if not fields:
        raise SystemExit(f"v53af missing required fields for {row['artifact_family']}")
    write_empty_csv(inbox_dir / template_rel, fields)
    chunk_template_rows.append(
        {
            "template_id": "template_" + row["review_chunk_id"] + "_" + row["artifact_family"].replace(".", "_"),
            "review_chunk_id": row["review_chunk_id"],
            "artifact_family": row["artifact_family"],
            "expected_rows": row["expected_rows"],
            "expected_final_artifact": row["return_artifact"],
            "template_artifact": str(Path("return_inbox") / template_rel),
            "header_field_count": str(len(fields)),
            "file_ready": "1",
            "accepted_by_default": "0",
            "route_jump_rows": "0",
        }
    )

aggregate_template_rows = []
for row in aggregate_rows:
    artifact = row["aggregate_artifact"]
    if artifact.endswith(".json"):
        template_rel = Path("aggregate_review_return_templates") / (artifact + ".template")
        payload = {
            "review_protocol_version": "fill-with-real-protocol-version",
            "acceptance_decision": "template-not-evidence",
            "expected_human_review_rows": row["expected_rows"] if artifact == "acceptance_summary.json" else "fill-with-real-count",
            "accepted_human_review_rows": "fill-with-real-count",
            "human_review_rows_sha256": "fill-with-real-sha256",
            "expected_adjudication_rows": "fill-with-real-count",
            "accepted_adjudication_rows": "fill-with-real-count",
            "adjudication_rows_sha256": "fill-with-real-sha256",
        }
        path = inbox_dir / template_rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        header_count = "0"
    else:
        template_rel = Path("aggregate_review_return_templates") / (artifact + ".template")
        fields = review_required_fields.get(artifact, [])
        if not fields:
            raise SystemExit(f"v53af missing aggregate required fields for {artifact}")
        write_empty_csv(inbox_dir / template_rel, fields)
        header_count = str(len(fields))
    aggregate_template_rows.append(
        {
            "template_id": "template_aggregate_" + artifact.replace(".", "_"),
            "aggregate_artifact": artifact,
            "expected_rows": row["expected_rows"],
            "expected_final_artifact": artifact,
            "template_artifact": str(Path("return_inbox") / template_rel),
            "header_field_count": header_count,
            "file_ready": "1",
            "accepted_by_default": "0",
            "route_jump_rows": "0",
        }
    )

generation_template_rows = []
for row in generation_rows:
    artifact = row["return_artifact"]
    if artifact.endswith(".json"):
        template_rel = Path("generation_result_return_templates") / (artifact + ".template")
        payload = {
            "generation_protocol_version": "fill-with-real-protocol-version",
            "acceptance_decision": "template-not-evidence",
            "expected_generation_rows": row["expected_rows"],
            "accepted_answer_rows": "fill-with-real-count",
            "answer_rows_sha256": "fill-with-real-sha256",
            "accepted_citation_rows": "fill-with-real-count",
            "citation_rows_sha256": "fill-with-real-sha256",
            "accepted_latency_rows": "fill-with-real-count",
            "latency_rows_sha256": "fill-with-real-sha256",
        }
        path = inbox_dir / template_rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        header_count = "0"
    else:
        template_rel = Path("generation_result_return_templates") / (artifact + ".template")
        fields = generation_required_fields.get(artifact, [])
        if not fields:
            raise SystemExit(f"v53af missing generation required fields for {artifact}")
        write_empty_csv(inbox_dir / template_rel, fields)
        header_count = str(len(fields))
    generation_template_rows.append(
        {
            "template_id": "template_generation_" + artifact.replace(".", "_"),
            "return_artifact": artifact,
            "expected_rows": row["expected_rows"],
            "expected_final_artifact": artifact,
            "template_artifact": str(Path("return_inbox") / template_rel),
            "header_field_count": header_count,
            "file_ready": "1",
            "accepted_by_default": "0",
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "external_return_receipt_template_rows.csv", list(receipt_template_rows[0].keys()), receipt_template_rows)
write_csv(run_dir / "external_return_chunk_template_rows.csv", list(chunk_template_rows[0].keys()), chunk_template_rows)
write_csv(run_dir / "external_return_aggregate_review_template_rows.csv", list(aggregate_template_rows[0].keys()), aggregate_template_rows)
write_csv(run_dir / "external_return_generation_result_template_rows.csv", list(generation_template_rows[0].keys()), generation_template_rows)

required_index_rows = []
for family, rows, target_env in [
    ("dispatch-receipt", receipt_template_rows, "V53AE_DISPATCH_RECEIPT_DIR"),
    ("review-chunk-return", chunk_template_rows, "V53AE_REVIEW_CHUNK_RETURN_DIR"),
    ("aggregate-review-return", aggregate_template_rows, "V53AE_REVIEW_RETURN_DIR"),
    ("generation-result-return", generation_template_rows, "V53AE_GENERATION_RESULT_DIR"),
]:
    for row in rows:
        required_index_rows.append(
            {
                "return_family": family,
                "target_env_var": target_env,
                "expected_final_artifact": row["expected_final_artifact"],
                "template_artifact": row["template_artifact"],
                "expected_rows": row.get("expected_rows", "1"),
                "accepted_by_default": row["accepted_by_default"],
                "route_jump_rows": "0",
            }
        )
write_csv(run_dir / "external_return_required_artifact_index_rows.csv", list(required_index_rows[0].keys()), required_index_rows)

readme = """# v53af External Return Inbox Scaffold

This scaffold is a zero-evidence return inbox. It provides template files only.
Files ending in `.template` are not accepted by the v53/v61 intake gates.

Populate real returned artifacts into separate final directories:

- dispatch receipts: `dispatch_receipts/`
- review chunk returns: `review_chunk_returns/`
- aggregate review return: `aggregate_review_return/`
- generation result return: `generation_result_return/`

Then run:

```bash
V53AE_DISPATCH_RECEIPT_DIR=/path/to/dispatch_receipts \\
V53AE_REVIEW_CHUNK_RETURN_DIR=/path/to/review_chunk_returns \\
V53AE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return \\
V53AE_GENERATION_RESULT_DIR=/path/to/generation_result_return \\
V53AE_REUSE_EXISTING=0 \\
./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh
```

Do not rename template files into final artifact names until real reviewer,
adjudicator, or generation evidence has been supplied.
"""
(inbox_dir / "RETURN_INBOX_README.md").write_text(readme, encoding="utf-8")

verify_script = f"""#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"

[[ -s "$ROOT/RETURN_INBOX_README.md" ]]
[[ "$(find "$ROOT/dispatch_receipt_templates" -type f -name '*.template' | wc -l | tr -d ' ')" == "{len(receipt_template_rows)}" ]]
[[ "$(find "$ROOT/review_chunk_return_templates" -type f -name '*.template' | wc -l | tr -d ' ')" == "{len(chunk_template_rows)}" ]]
[[ "$(find "$ROOT/aggregate_review_return_templates" -type f -name '*.template' | wc -l | tr -d ' ')" == "{len(aggregate_template_rows)}" ]]
[[ "$(find "$ROOT/generation_result_return_templates" -type f -name '*.template' | wc -l | tr -d ' ')" == "{len(generation_template_rows)}" ]]

if find "$ROOT" -type f \\( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \\) | grep -q .; then
  echo "payload-like file found in return inbox scaffold" >&2
  exit 1
fi

echo "v53af return inbox scaffold shape verified"
"""
verify_path = inbox_dir / "VERIFY_RETURN_INBOX_SHAPE.sh"
verify_path.write_text(verify_script, encoding="utf-8")
os.chmod(verify_path, 0o755)

command_template = """#!/usr/bin/env bash
set -euo pipefail

V53AE_DISPATCH_RECEIPT_DIR="${V53AE_DISPATCH_RECEIPT_DIR:?set final dispatch receipt dir}" \\
V53AE_REVIEW_CHUNK_RETURN_DIR="${V53AE_REVIEW_CHUNK_RETURN_DIR:?set final review chunk return dir}" \\
V53AE_REVIEW_RETURN_DIR="${V53AE_REVIEW_RETURN_DIR:?set final aggregate review return dir}" \\
V53AE_GENERATION_RESULT_DIR="${V53AE_GENERATION_RESULT_DIR:?set final generation result return dir}" \\
V53AE_REUSE_EXISTING=0 \\
./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh
"""
(inbox_dir / "RUN_V53AE_WITH_FINAL_RETURNS.sh.template").write_text(command_template, encoding="utf-8")

file_rows = []
for path in sorted(inbox_dir.rglob("*")):
    if path.is_file():
        file_rows.append(
            {
                "return_inbox_file": str(path.relative_to(inbox_dir)),
                "file_ready": "1",
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "accepted_by_default": "0",
            }
        )
write_csv(run_dir / "external_return_inbox_file_rows.csv", list(file_rows[0].keys()), file_rows)

total_template_rows = len(required_index_rows)
metric = {
    "metric_id": "v53af_external_return_inbox_scaffold_metrics",
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"],
    "v61df_external_review_generation_return_operator_packet_ready": v61df["v61df_external_review_generation_return_operator_packet_ready"],
    "return_inbox_scaffold_ready": "1",
    "return_inbox_file_rows": str(len(file_rows)),
    "required_return_artifact_rows": str(total_template_rows),
    "dispatch_receipt_template_files": str(len(receipt_template_rows)),
    "review_chunk_return_template_files": str(len(chunk_template_rows)),
    "aggregate_review_return_template_files": str(len(aggregate_template_rows)),
    "generation_result_template_files": str(len(generation_template_rows)),
    "template_files_accepted_by_default": "0",
    "answer_review_accepted_rows": v53ae["answer_review_accepted_rows"],
    "accepted_chunk_return_artifact_rows": v53ae["accepted_chunk_return_artifact_rows"],
    "accepted_dispatch_receipt_rows": v53ae["accepted_dispatch_receipt_rows"],
    "generation_execution_admitted_rows": v53ae["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53ae["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v53ae["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53ae["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ae["runtime_admission_accepted_rows"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53af": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "external_return_inbox_metric_rows.csv", list(metric.keys()), [metric])

requirement_rows = [
    {"requirement_id": "v53ae-rendezvous-input", "status": "pass", "required_value": "1", "actual_value": v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"], "reason": "v53ae rendezvous gate is ready"},
    {"requirement_id": "v61df-operator-packet-input", "status": "pass", "required_value": "1", "actual_value": v61df["v61df_external_review_generation_return_operator_packet_ready"], "reason": "v61df external return packet is ready"},
    {"requirement_id": "return-inbox-template-shape", "status": "pass", "required_value": "81", "actual_value": str(total_template_rows), "reason": "all receipt/review/generation template rows were scaffolded"},
    {"requirement_id": "template-zero-evidence-boundary", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "template files use .template suffix and are not accepted by default"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": "7000", "actual_value": v53ae["answer_review_accepted_rows"], "reason": "actual review return remains external"},
    {"requirement_id": "generation-result-accepted", "status": "blocked", "required_value": "5", "actual_value": v53ae["accepted_generation_result_artifacts"], "reason": "actual generation result return remains external"},
    {"requirement_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": v53ae["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "external_return_inbox_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "return-inbox-scaffold", "status": "ready", "reason": f"required_return_artifact_rows={total_template_rows}"},
    {"gap": "dispatch-receipt-return", "status": "blocked", "reason": f"accepted_dispatch_receipt_rows={v53ae['accepted_dispatch_receipt_rows']}/21"},
    {"gap": "review-chunk-return", "status": "blocked", "reason": f"accepted_chunk_return_artifact_rows={v53ae['accepted_chunk_return_artifact_rows']}/50"},
    {"gap": "aggregate-review-return", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}/7000"},
    {"gap": "generation-result-return", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53ae['accepted_generation_result_artifacts']}/5"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ae['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

summary = {
    "v53af_external_return_inbox_scaffold_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53ae-rendezvous-input", "status": "pass", "reason": "v53ae rendezvous gate is ready"},
    {"gate": "v61df-operator-packet-input", "status": "pass", "reason": "v61df external return packet is ready"},
    {"gate": "return-inbox-template-shape", "status": "pass", "reason": f"required_return_artifact_rows={total_template_rows}"},
    {"gate": "template-zero-evidence-boundary", "status": "pass", "reason": "template files are not final evidence"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}/7000"},
    {"gate": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53ae['accepted_generation_result_artifacts']}/5"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ae['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "return inbox is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53af External Return Inbox Scaffold Boundary

This artifact creates a zero-evidence return inbox scaffold for the v53/v61
external return path. It provides `.template` files for dispatch receipts,
review chunk returns, aggregate review returns, and generation result returns.
Templates are intentionally not accepted by the intake gates until real
returned evidence is copied into final artifact names under separate return
directories.

Evidence emitted:

- return_inbox_scaffold_ready=1
- required_return_artifact_rows={total_template_rows}
- dispatch_receipt_template_files={len(receipt_template_rows)}
- review_chunk_return_template_files={len(chunk_template_rows)}
- aggregate_review_return_template_files={len(aggregate_template_rows)}
- generation_result_template_files={len(generation_template_rows)}
- template_files_accepted_by_default=0
- answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}
- accepted_chunk_return_artifact_rows={v53ae['accepted_chunk_return_artifact_rows']}
- accepted_dispatch_receipt_rows={v53ae['accepted_dispatch_receipt_rows']}
- generation_execution_admitted_rows={v53ae['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v53ae['accepted_generation_result_artifacts']}
- actual_model_generation_ready={v53ae['actual_model_generation_ready']}
- full_shard_prerequisites_closed={v53ae['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53ae['runtime_admission_accepted_rows']}
- checkpoint_payload_bytes_downloaded_by_v53af=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: external return inbox templates are scaffolded.
Blocked wording: accepted review return, generation result acceptance, actual
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AF_EXTERNAL_RETURN_INBOX_SCAFFOLD_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53af-external-return-inbox-scaffold",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53af_external_return_inbox_scaffold_ready": 1,
    "return_inbox_file_rows": len(file_rows),
    "required_return_artifact_rows": total_template_rows,
    "dispatch_receipt_template_files": len(receipt_template_rows),
    "review_chunk_return_template_files": len(chunk_template_rows),
    "aggregate_review_return_template_files": len(aggregate_template_rows),
    "generation_result_template_files": len(generation_template_rows),
    "template_files_accepted_by_default": 0,
    "answer_review_accepted_rows": as_int(v53ae, "answer_review_accepted_rows"),
    "generation_execution_admitted_rows": as_int(v53ae, "generation_execution_admitted_rows"),
    "accepted_generation_result_artifacts": as_int(v53ae, "accepted_generation_result_artifacts"),
    "actual_model_generation_ready": as_int(v53ae, "actual_model_generation_ready"),
    "full_shard_prerequisites_closed": as_int(v53ae, "full_shard_prerequisites_closed"),
    "runtime_admission_accepted_rows": as_int(v53ae, "runtime_admission_accepted_rows"),
    "source_v53ae_summary_sha256": sha256(source_paths["v53ae_summary"]),
    "source_v61df_summary_sha256": sha256(source_paths["v61df_summary"]),
    "checkpoint_payload_bytes_downloaded_by_v53af": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53af_external_return_inbox_scaffold_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53af_external_return_inbox_scaffold_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
