#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ad_complete_source_review_dispatch_receipt_intake"
RUN_ID="${V53AD_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR="${V53AD_DISPATCH_RECEIPT_DIR:-}"

if [[ "${V53AD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ad_complete_source_review_dispatch_receipt_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ac_complete_source_review_dispatch_archive.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RECEIPT_DIR" <<'PY'
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
receipt_dir_arg = sys.argv[5]
receipt_dir = Path(receipt_dir_arg).expanduser().resolve() if receipt_dir_arg else None
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


def pass_block(flag):
    return "pass" if flag else "blocked"


v53ac_summary_path = results / "v53ac_complete_source_review_dispatch_archive_summary.csv"
v53ac_decision_path = results / "v53ac_complete_source_review_dispatch_archive_decision.csv"
v53ac_dir = results / "v53ac_complete_source_review_dispatch_archive" / "archive_001"
v53ab_dir = results / "v53ab_complete_source_review_dispatch_receipt_packet" / "dispatch_001"
v53ac = read_csv(v53ac_summary_path)[0]
if v53ac["v53ac_complete_source_review_dispatch_archive_ready"] != "1":
    raise SystemExit("v53ad requires v53ac archive readiness")

for src, rel in [
    (v53ac_summary_path, "source_v53ac/v53ac_complete_source_review_dispatch_archive_summary.csv"),
    (v53ac_decision_path, "source_v53ac/v53ac_complete_source_review_dispatch_archive_decision.csv"),
    (v53ac_dir / "complete_source_review_dispatch_archive_metric_rows.csv", "source_v53ac/complete_source_review_dispatch_archive_metric_rows.csv"),
    (v53ac_dir / "complete_source_review_dispatch_archive_artifact_rows.csv", "source_v53ac/complete_source_review_dispatch_archive_artifact_rows.csv"),
    (v53ab_dir / "complete_source_review_dispatch_receipt_template_rows.csv", "source_v53ab/complete_source_review_dispatch_receipt_template_rows.csv"),
    (v53ab_dir / "complete_source_review_dispatch_chunk_rows.csv", "source_v53ab/complete_source_review_dispatch_chunk_rows.csv"),
]:
    copy(src, rel)

receipt_templates = read_csv(v53ab_dir / "complete_source_review_dispatch_receipt_template_rows.csv")
receipt_dir_supplied = int(receipt_dir is not None)
receipt_dir_exists = int(receipt_dir is not None and receipt_dir.is_dir())

receipt_status_rows = []
accepted_receipts = 0
missing_receipts = 0
invalid_receipts = 0
supplied_receipts = 0
seen_chunks = set()

for row in receipt_templates:
    expected_rel = row["expected_receipt_artifact"]
    expected_path = receipt_dir / expected_rel if receipt_dir else None
    file_exists = int(expected_path is not None and expected_path.is_file())
    supplied_receipts += file_exists
    receipt_hash = ""
    receipt_status = "missing"
    errors = []
    received_chunk = ""
    received_archive_sha = ""
    reviewer_or_coordinator_id = ""
    if file_exists:
        receipt_hash = sha256(expected_path)
        try:
            payload = json.loads(expected_path.read_text(encoding="utf-8"))
        except Exception:
            payload = {}
            errors.append("invalid-json")
        received_chunk = str(payload.get("review_chunk_id", ""))
        received_archive_sha = str(payload.get("archive_sha256", ""))
        reviewer_or_coordinator_id = str(payload.get("reviewer_or_coordinator_id", ""))
        if received_chunk != row["review_chunk_id"]:
            errors.append("review-chunk-id-mismatch")
        if not reviewer_or_coordinator_id:
            errors.append("missing-reviewer-or-coordinator-id")
        if not received_archive_sha.startswith("sha256:"):
            errors.append("missing-or-invalid-archive-sha256")
        if row["review_chunk_id"] in seen_chunks:
            errors.append("duplicate-review-chunk-receipt")
        if errors:
            invalid_receipts += 1
            receipt_status = "invalid"
        else:
            accepted_receipts += 1
            seen_chunks.add(row["review_chunk_id"])
            receipt_status = "accepted"
    else:
        missing_receipts += 1
    receipt_status_rows.append(
        {
            "receipt_id": row["receipt_id"],
            "review_chunk_id": row["review_chunk_id"],
            "expected_receipt_artifact": expected_rel,
            "receipt_supplied": str(file_exists),
            "receipt_accepted": str(int(receipt_status == "accepted")),
            "receipt_status": receipt_status,
            "receipt_sha256": receipt_hash,
            "received_review_chunk_id": received_chunk,
            "received_archive_sha256": received_archive_sha,
            "reviewer_or_coordinator_id": reviewer_or_coordinator_id,
            "validation_errors": ";".join(errors),
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "complete_source_review_dispatch_receipt_status_rows.csv", list(receipt_status_rows[0].keys()), receipt_status_rows)

dispatch_receipt_intake_ready = int(accepted_receipts == len(receipt_templates) and invalid_receipts == 0)
review_return_ready = int(v53ac["review_return_ready"])
answer_review_accepted = int(v53ac["answer_review_accepted_rows"])
actual_generation_ready = int(v53ac["actual_model_generation_ready"])

requirement_rows = [
    {"requirement_id": "v53ac-dispatch-archive-input", "status": "pass", "required_value": "1", "actual_value": v53ac["v53ac_complete_source_review_dispatch_archive_ready"], "reason": "v53ac dispatch archive is ready"},
    {"requirement_id": "receipt-directory-supplied", "status": pass_block(receipt_dir_exists), "required_value": "existing receipt directory", "actual_value": str(receipt_dir) if receipt_dir else "", "reason": "external dispatch receipt directory is optional but required to accept receipts"},
    {"requirement_id": "dispatch-receipts-accepted", "status": pass_block(dispatch_receipt_intake_ready), "required_value": str(len(receipt_templates)), "actual_value": str(accepted_receipts), "reason": "all dispatch receipts must validate against chunk ids"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": v53ac["expected_human_review_rows"], "actual_value": str(answer_review_accepted), "reason": "dispatch receipt is not review evidence"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": str(actual_generation_ready), "reason": "actual generation remains gated behind review/generation returns"},
]
write_csv(run_dir / "complete_source_review_dispatch_receipt_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "dispatch-receipt-intake", "status": "ready" if dispatch_receipt_intake_ready else "blocked", "reason": f"accepted_dispatch_receipt_rows={accepted_receipts}/{len(receipt_templates)}"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={answer_review_accepted}/{v53ac['expected_human_review_rows']}"},
    {"gap": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53ac['v53_ready']}"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={actual_generation_ready}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ad_complete_source_review_dispatch_receipt_intake_metrics",
    "v53ac_complete_source_review_dispatch_archive_ready": v53ac["v53ac_complete_source_review_dispatch_archive_ready"],
    "receipt_dir_supplied": str(receipt_dir_supplied),
    "receipt_dir_exists": str(receipt_dir_exists),
    "dispatch_receipt_template_rows": str(len(receipt_templates)),
    "supplied_dispatch_receipt_rows": str(supplied_receipts),
    "accepted_dispatch_receipt_rows": str(accepted_receipts),
    "missing_dispatch_receipt_rows": str(missing_receipts),
    "invalid_dispatch_receipt_rows": str(invalid_receipts),
    "dispatch_receipt_intake_ready": str(dispatch_receipt_intake_ready),
    "dispatch_archive_ready": v53ac["archive_ready"],
    "archive_sha256_ready": v53ac["archive_sha256_ready"],
    "payload_like_archive_member_rows": v53ac["payload_like_archive_member_rows"],
    "dispatch_chunk_rows": v53ac["dispatch_chunk_rows"],
    "dispatch_task_rows": v53ac["dispatch_task_rows"],
    "dispatch_return_artifact_rows": v53ac["dispatch_return_artifact_rows"],
    "expected_human_review_rows": v53ac["expected_human_review_rows"],
    "answer_review_accepted_rows": str(answer_review_accepted),
    "review_return_ready": str(review_return_ready),
    "v53_ready": v53ac["v53_ready"],
    "actual_model_generation_ready": str(actual_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_review_dispatch_receipt_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53ac-dispatch-archive-input", "status": "pass", "reason": "v53ac dispatch archive is ready"},
    {"gate": "dispatch-receipt-intake", "status": "pass" if dispatch_receipt_intake_ready else "blocked", "reason": f"accepted_dispatch_receipt_rows={accepted_receipts}/{len(receipt_templates)}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={answer_review_accepted}/{v53ac['expected_human_review_rows']}"},
    {"gate": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53ac['v53_ready']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={actual_generation_ready}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "dispatch receipts are not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ad Complete-Source Review Dispatch Receipt Intake Boundary

This artifact validates optional external dispatch receipt JSON files for the
v53ac review dispatch archive. It can prove that the archive was acknowledged
for each review chunk, but it does not create review judgments, accepted review
rows, v53 readiness, v61 actual generation, latency evidence, near-frontier
quality, or release readiness.

Evidence emitted:

- receipt_dir_supplied={receipt_dir_supplied}
- receipt_dir_exists={receipt_dir_exists}
- dispatch_receipt_template_rows={len(receipt_templates)}
- supplied_dispatch_receipt_rows={supplied_receipts}
- accepted_dispatch_receipt_rows={accepted_receipts}
- missing_dispatch_receipt_rows={missing_receipts}
- invalid_dispatch_receipt_rows={invalid_receipts}
- dispatch_receipt_intake_ready={dispatch_receipt_intake_ready}
- dispatch_archive_ready={v53ac['archive_ready']}
- archive_sha256_ready={v53ac['archive_sha256_ready']}
- payload_like_archive_member_rows={v53ac['payload_like_archive_member_rows']}
- dispatch_chunk_rows={v53ac['dispatch_chunk_rows']}
- dispatch_task_rows={v53ac['dispatch_task_rows']}
- dispatch_return_artifact_rows={v53ac['dispatch_return_artifact_rows']}
- expected_human_review_rows={v53ac['expected_human_review_rows']}
- answer_review_accepted_rows={answer_review_accepted}
- review_return_ready={review_return_ready}
- v53_ready={v53ac['v53_ready']}
- actual_model_generation_ready={actual_generation_ready}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source review dispatch receipt intake is defined.
Blocked wording: accepted review return, v53 readiness, v61 actual generation,
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AD_COMPLETE_SOURCE_REVIEW_DISPATCH_RECEIPT_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ad-complete-source-review-dispatch-receipt-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": 1,
    "dispatch_receipt_template_rows": len(receipt_templates),
    "supplied_dispatch_receipt_rows": supplied_receipts,
    "accepted_dispatch_receipt_rows": accepted_receipts,
    "missing_dispatch_receipt_rows": missing_receipts,
    "invalid_dispatch_receipt_rows": invalid_receipts,
    "dispatch_receipt_intake_ready": dispatch_receipt_intake_ready,
    "answer_review_accepted_rows": answer_review_accepted,
    "actual_model_generation_ready": actual_generation_ready,
    "source_v53ac_summary_sha256": sha256(v53ac_summary_path),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53ad_complete_source_review_dispatch_receipt_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ad_complete_source_review_dispatch_receipt_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
