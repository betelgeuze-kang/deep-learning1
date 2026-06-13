#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ab_complete_source_review_dispatch_receipt_packet"
RUN_ID="${V53AB_RUN_ID:-dispatch_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ab_complete_source_review_dispatch_receipt_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61df_external_review_generation_return_operator_packet.sh" >/dev/null
V53AA_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53aa_complete_source_review_chunk_work_packet.sh" >/dev/null

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
dispatch_dir = run_dir / "operator_dispatch"
dispatch_dir.mkdir(parents=True, exist_ok=True)


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


def pass_block(flag):
    return "pass" if flag else "blocked"


v53aa_summary_path = results / "v53aa_complete_source_review_chunk_work_packet_summary.csv"
v53aa_decision_path = results / "v53aa_complete_source_review_chunk_work_packet_decision.csv"
v61df_summary_path = results / "v61df_external_review_generation_return_operator_packet_summary.csv"
v61df_decision_path = results / "v61df_external_review_generation_return_operator_packet_decision.csv"
v53aa_dir = results / "v53aa_complete_source_review_chunk_work_packet" / "work_packet_001"
v61df_dir = results / "v61df_external_review_generation_return_operator_packet" / "packet_001"

v53aa = read_csv(v53aa_summary_path)[0]
v61df = read_csv(v61df_summary_path)[0]
if v53aa["v53aa_complete_source_review_chunk_work_packet_ready"] != "1":
    raise SystemExit("v53ab requires v53aa work packet readiness")
if v61df["v61df_external_review_generation_return_operator_packet_ready"] != "1":
    raise SystemExit("v53ab requires v61df external return operator packet readiness")

for src, rel in [
    (v53aa_summary_path, "source_v53aa/v53aa_complete_source_review_chunk_work_packet_summary.csv"),
    (v53aa_decision_path, "source_v53aa/v53aa_complete_source_review_chunk_work_packet_decision.csv"),
    (v53aa_dir / "complete_source_review_chunk_packet_rows.csv", "source_v53aa/complete_source_review_chunk_packet_rows.csv"),
    (v53aa_dir / "complete_source_review_chunk_packet_file_rows.csv", "source_v53aa/complete_source_review_chunk_packet_file_rows.csv"),
    (v53aa_dir / "complete_source_review_chunk_packet_requirement_rows.csv", "source_v53aa/complete_source_review_chunk_packet_requirement_rows.csv"),
    (v61df_summary_path, "source_v61df/v61df_external_review_generation_return_operator_packet_summary.csv"),
    (v61df_decision_path, "source_v61df/v61df_external_review_generation_return_operator_packet_decision.csv"),
    (v61df_dir / "external_return_operator_stage_rows.csv", "source_v61df/external_return_operator_stage_rows.csv"),
    (v61df_dir / "external_return_operator_command_rows.csv", "source_v61df/external_return_operator_command_rows.csv"),
]:
    copy(src, rel)

embedded_work_packet = dispatch_dir / "review_work_packet"
if embedded_work_packet.exists():
    shutil.rmtree(embedded_work_packet)
shutil.copytree(v53aa_dir / "operator_packet", embedded_work_packet)

chunk_packet_rows = read_csv(v53aa_dir / "complete_source_review_chunk_packet_rows.csv")
aggregate_rows = read_csv(v53aa_dir / "operator_packet" / "AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv")
embedded_file_rows = read_csv(v53aa_dir / "complete_source_review_chunk_packet_file_rows.csv")

dispatch_chunk_rows = []
for row in chunk_packet_rows:
    dispatch_chunk_rows.append(
        {
            "dispatch_chunk_id": f"v53ab_dispatch_{row['review_chunk_id']}",
            "review_chunk_id": row["review_chunk_id"],
            "assignment_id": row["assignment_id"],
            "reviewer_slot_id": row["reviewer_slot_id"],
            "system_id": row["system_id"],
            "review_scope": row["review_scope"],
            "task_rows": row["task_rows"],
            "required_return_artifacts": row["required_return_artifacts"],
            "work_packet_dir": f"review_work_packet/{row['packet_dir']}",
            "dispatch_status": "ready-for-external-review",
            "receipt_expected": "1",
            "receipt_accepted": "0",
            "review_return_ready": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(dispatch_dir / "DISPATCH_CHUNK_ROWS.csv", list(dispatch_chunk_rows[0].keys()), dispatch_chunk_rows)
write_csv(run_dir / "complete_source_review_dispatch_chunk_rows.csv", list(dispatch_chunk_rows[0].keys()), dispatch_chunk_rows)

receipt_rows = [
    {
        "receipt_id": f"receipt_{row['review_chunk_id']}",
        "review_chunk_id": row["review_chunk_id"],
        "expected_receipt_artifact": f"dispatch_receipts/{row['review_chunk_id']}_receipt.json",
        "receipt_expected": "1",
        "receipt_accepted": "0",
        "receipt_status": "pending-external-dispatch-receipt",
        "route_jump_rows": "0",
    }
    for row in chunk_packet_rows
]
write_csv(dispatch_dir / "DISPATCH_RECEIPT_TEMPLATE_ROWS.csv", list(receipt_rows[0].keys()), receipt_rows)
write_csv(run_dir / "complete_source_review_dispatch_receipt_template_rows.csv", list(receipt_rows[0].keys()), receipt_rows)

handoff_rows = []
for row in aggregate_rows:
    handoff_rows.append(
        {
            "handoff_artifact": row["aggregate_artifact"],
            "source_chunk_artifact_family": row["source_chunk_artifact_family"],
            "expected_rows": row["expected_rows"],
            "accepted_rows": row["accepted_rows"],
            "target_refresh_env": "V53Y_REVIEW_RETURN_DIR",
            "target_intake": row["target_intake"],
            "handoff_status": "blocked-until-external-review-return",
        }
    )
write_csv(dispatch_dir / "REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv", list(handoff_rows[0].keys()), handoff_rows)
write_csv(run_dir / "complete_source_review_return_handoff_artifact_rows.csv", list(handoff_rows[0].keys()), handoff_rows)

command_rows = [
    {
        "command_id": "verify-dispatch-packet",
        "command": "results/v53ab_complete_source_review_dispatch_receipt_packet/dispatch_001/operator_dispatch/VERIFY_REVIEW_DISPATCH_PACKET.sh",
        "ready_to_run_now": "1",
        "expected_return": "dispatch packet shape verified",
    },
    {
        "command_id": "dispatch-review-work-packet",
        "command": "send operator_dispatch/review_work_packet plus DISPATCH_CHUNK_ROWS.csv to reviewers",
        "ready_to_run_now": "1",
        "expected_return": "21 reviewer chunk packets dispatched",
    },
    {
        "command_id": "collect-dispatch-receipts",
        "command": "collect dispatch_receipts/*.json for each review_chunk_id",
        "ready_to_run_now": "1",
        "expected_return": "21 dispatch receipt artifacts",
    },
    {
        "command_id": "refresh-review-return-after-results",
        "command": "V53Y_REVIEW_RETURN_DIR=/path/to/v53_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "ready_to_run_now": "0",
        "expected_return": "review_return_ready can be rechecked after returned review artifacts exist",
    },
    {
        "command_id": "refresh-v61-external-return-packet",
        "command": "V61DF_REUSE_EXISTING=0 ./experiments/run_v61df_external_review_generation_return_operator_packet.sh",
        "ready_to_run_now": "0",
        "expected_return": "v61 generation chain sees accepted review return only after v53 refresh",
    },
]
write_csv(dispatch_dir / "REVIEW_RETURN_REFRESH_COMMAND_ROWS.csv", list(command_rows[0].keys()), command_rows)
write_csv(run_dir / "complete_source_review_dispatch_command_rows.csv", list(command_rows[0].keys()), command_rows)

(dispatch_dir / "README.md").write_text(
    "# v53ab Complete-Source Review Dispatch Receipt Packet\n\n"
    "This dispatch packet embeds the v53aa review work packet, adds per-chunk "
    "dispatch rows, dispatch receipt templates, aggregate return handoff rows, "
    "and refresh commands. It does not create reviewer judgments or review "
    "acceptance evidence.\n",
    encoding="utf-8",
)

verify_script = dispatch_dir / "VERIFY_REVIEW_DISPATCH_PACKET.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

DISPATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$(cd "$DISPATCH_DIR/.." && pwd)"

required_files=(
  "$DISPATCH_DIR/README.md"
  "$DISPATCH_DIR/DISPATCH_CHUNK_ROWS.csv"
  "$DISPATCH_DIR/DISPATCH_RECEIPT_TEMPLATE_ROWS.csv"
  "$DISPATCH_DIR/REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv"
  "$DISPATCH_DIR/REVIEW_RETURN_REFRESH_COMMAND_ROWS.csv"
  "$DISPATCH_DIR/review_work_packet/CHUNK_PACKET_INDEX.csv"
  "$DISPATCH_DIR/review_work_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv"
  "$DISPATCH_DIR/review_work_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53ab dispatch packet file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$DISPATCH_DIR/DISPATCH_CHUNK_ROWS.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 dispatch chunk rows" >&2; exit 1; }
[[ "$(wc -l < "$DISPATCH_DIR/DISPATCH_RECEIPT_TEMPLATE_ROWS.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 dispatch receipt rows" >&2; exit 1; }
[[ "$(wc -l < "$DISPATCH_DIR/REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv" | tr -d ' ')" == "6" ]] || { echo "expected five handoff artifact rows" >&2; exit 1; }

"$DISPATCH_DIR/review_work_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v53ab dispatch packet" >&2
  exit 1
fi

echo "v53ab review dispatch packet shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

top_files = [
    ("operator_dispatch/README.md", "dispatch instructions"),
    ("operator_dispatch/VERIFY_REVIEW_DISPATCH_PACKET.sh", "dispatch verifier"),
    ("operator_dispatch/DISPATCH_CHUNK_ROWS.csv", "21 dispatch chunk rows"),
    ("operator_dispatch/DISPATCH_RECEIPT_TEMPLATE_ROWS.csv", "21 dispatch receipt templates"),
    ("operator_dispatch/REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv", "aggregate review return handoff artifacts"),
    ("operator_dispatch/REVIEW_RETURN_REFRESH_COMMAND_ROWS.csv", "post-return refresh commands"),
    ("operator_dispatch/review_work_packet/CHUNK_PACKET_INDEX.csv", "embedded v53aa chunk index"),
    ("operator_dispatch/review_work_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv", "embedded aggregate return target rows"),
]
file_rows = []
for rel, purpose in top_files:
    path = run_dir / rel
    file_rows.append(
        {
            "dispatch_file": rel,
            "purpose": purpose,
            "file_ready": str(int(path.is_file() and path.stat().st_size > 0)),
            "sha256": sha256(path) if path.is_file() else "",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "complete_source_review_dispatch_file_rows.csv", list(file_rows[0].keys()), file_rows)

dispatch_task_rows = sum(int(row["task_rows"]) for row in dispatch_chunk_rows)
dispatch_return_artifacts = sum(int(row["required_return_artifacts"]) for row in dispatch_chunk_rows)
ready_dispatch_chunks = sum(1 for row in dispatch_chunk_rows if row["dispatch_status"] == "ready-for-external-review")
ready_receipts = sum(1 for row in receipt_rows if row["receipt_accepted"] == "1")
ready_file_rows = sum(1 for row in file_rows if row["file_ready"] == "1")
ready_embedded_rows = int(v53aa["ready_operator_packet_file_rows"])
embedded_rows = int(v53aa["operator_packet_file_rows"])

requirement_rows = [
    {"requirement_id": "v53aa-work-packet-input", "status": "pass", "required_value": "1", "actual_value": v53aa["v53aa_complete_source_review_chunk_work_packet_ready"], "reason": "v53aa work packet is ready"},
    {"requirement_id": "v61df-external-return-input", "status": "pass", "required_value": "1", "actual_value": v61df["v61df_external_review_generation_return_operator_packet_ready"], "reason": "v61df external return packet is ready"},
    {"requirement_id": "dispatch-chunk-packet", "status": pass_block(ready_dispatch_chunks == 21), "required_value": "21", "actual_value": str(ready_dispatch_chunks), "reason": "all review chunks are dispatch-ready"},
    {"requirement_id": "embedded-work-packet-files", "status": pass_block(ready_embedded_rows == embedded_rows), "required_value": str(embedded_rows), "actual_value": str(ready_embedded_rows), "reason": "embedded v53aa work packet files are ready"},
    {"requirement_id": "dispatch-package-files", "status": pass_block(ready_file_rows == len(file_rows)), "required_value": str(len(file_rows)), "actual_value": str(ready_file_rows), "reason": "dispatch packet top-level files are ready"},
    {"requirement_id": "dispatch-receipts-accepted", "status": "blocked", "required_value": "21", "actual_value": str(ready_receipts), "reason": "external dispatch receipts have not been supplied"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": v53aa["expected_human_review_rows"], "actual_value": v53aa["answer_review_accepted_rows"], "reason": "review return evidence has not been supplied"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v61df["actual_model_generation_ready"], "reason": "actual generation remains gated behind review/generation returns"},
]
write_csv(run_dir / "complete_source_review_dispatch_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "dispatch-packet", "status": "ready", "reason": f"ready_dispatch_chunk_rows={ready_dispatch_chunks}/21"},
    {"gap": "dispatch-receipts", "status": "blocked", "reason": f"accepted_dispatch_receipt_rows={ready_receipts}/21"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53aa['answer_review_accepted_rows']}/{v53aa['expected_human_review_rows']}"},
    {"gap": "v61-review-unblock", "status": "blocked", "reason": f"actual_model_generation_ready={v61df['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ab_complete_source_review_dispatch_receipt_packet_metrics",
    "v53aa_complete_source_review_chunk_work_packet_ready": v53aa["v53aa_complete_source_review_chunk_work_packet_ready"],
    "v61df_external_review_generation_return_operator_packet_ready": v61df["v61df_external_review_generation_return_operator_packet_ready"],
    "dispatch_chunk_rows": str(len(dispatch_chunk_rows)),
    "ready_dispatch_chunk_rows": str(ready_dispatch_chunks),
    "dispatch_task_rows": str(dispatch_task_rows),
    "dispatch_return_artifact_rows": str(dispatch_return_artifacts),
    "aggregate_review_return_artifact_rows": v53aa["aggregate_review_return_artifact_rows"],
    "dispatch_receipt_template_rows": str(len(receipt_rows)),
    "accepted_dispatch_receipt_rows": str(ready_receipts),
    "dispatch_command_rows": str(len(command_rows)),
    "ready_dispatch_command_rows": str(sum(1 for row in command_rows if row["ready_to_run_now"] == "1")),
    "dispatch_package_file_rows": str(len(file_rows)),
    "ready_dispatch_package_file_rows": str(ready_file_rows),
    "embedded_work_packet_file_rows": str(embedded_rows),
    "ready_embedded_work_packet_file_rows": str(ready_embedded_rows),
    "expected_human_review_rows": v53aa["expected_human_review_rows"],
    "answer_review_accepted_rows": v53aa["answer_review_accepted_rows"],
    "review_return_ready": v53aa["review_return_ready"],
    "v53_ready": v53aa["v53_ready"],
    "v1_0_comparison_ready": v53aa["v1_0_comparison_ready"],
    "v61_review_unblock_ready": "0",
    "actual_model_generation_ready": v61df["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_review_dispatch_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ab_complete_source_review_dispatch_receipt_packet_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53aa-work-packet-input", "status": "pass", "reason": "v53aa work packet is ready"},
    {"gate": "v61df-external-return-input", "status": "pass", "reason": "v61df external return packet is ready"},
    {"gate": "dispatch-packet", "status": "pass", "reason": f"ready_dispatch_chunk_rows={ready_dispatch_chunks}/21"},
    {"gate": "dispatch-receipts", "status": "blocked", "reason": f"accepted_dispatch_receipt_rows={ready_receipts}/21"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53aa['answer_review_accepted_rows']}/{v53aa['expected_human_review_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61df['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "dispatch packet is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ab Complete-Source Review Dispatch Receipt Packet Boundary

This artifact packages the v53aa chunk work packet for external dispatch and
adds dispatch rows, receipt templates, aggregate return handoff rows, and
refresh commands. It does not create reviewer judgments, accepted review rows,
v53 readiness, v61 generation readiness, latency evidence, quality superiority,
or release evidence.

Evidence emitted:

- dispatch_chunk_rows={len(dispatch_chunk_rows)}
- ready_dispatch_chunk_rows={ready_dispatch_chunks}
- dispatch_task_rows={dispatch_task_rows}
- dispatch_return_artifact_rows={dispatch_return_artifacts}
- aggregate_review_return_artifact_rows={v53aa['aggregate_review_return_artifact_rows']}
- dispatch_receipt_template_rows={len(receipt_rows)}
- accepted_dispatch_receipt_rows={ready_receipts}
- dispatch_package_file_rows={len(file_rows)}
- ready_dispatch_package_file_rows={ready_file_rows}
- embedded_work_packet_file_rows={embedded_rows}
- ready_embedded_work_packet_file_rows={ready_embedded_rows}
- expected_human_review_rows={v53aa['expected_human_review_rows']}
- answer_review_accepted_rows={v53aa['answer_review_accepted_rows']}
- review_return_ready={v53aa['review_return_ready']}
- v53_ready={v53aa['v53_ready']}
- actual_model_generation_ready={v61df['actual_model_generation_ready']}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source external review dispatch packet is ready.
Blocked wording: accepted review return, v53 readiness, v61 actual generation,
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AB_COMPLETE_SOURCE_REVIEW_DISPATCH_RECEIPT_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ab-complete-source-review-dispatch-receipt-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ab_complete_source_review_dispatch_receipt_packet_ready": 1,
    "dispatch_chunk_rows": len(dispatch_chunk_rows),
    "ready_dispatch_chunk_rows": ready_dispatch_chunks,
    "dispatch_task_rows": dispatch_task_rows,
    "dispatch_return_artifact_rows": dispatch_return_artifacts,
    "dispatch_receipt_template_rows": len(receipt_rows),
    "accepted_dispatch_receipt_rows": ready_receipts,
    "dispatch_package_file_rows": len(file_rows),
    "ready_dispatch_package_file_rows": ready_file_rows,
    "embedded_work_packet_file_rows": embedded_rows,
    "ready_embedded_work_packet_file_rows": ready_embedded_rows,
    "answer_review_accepted_rows": int(v53aa["answer_review_accepted_rows"]),
    "actual_model_generation_ready": int(v61df["actual_model_generation_ready"]),
    "source_v53aa_summary_sha256": sha256(v53aa_summary_path),
    "source_v61df_summary_sha256": sha256(v61df_summary_path),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53ab_complete_source_review_dispatch_receipt_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ab_complete_source_review_dispatch_receipt_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
