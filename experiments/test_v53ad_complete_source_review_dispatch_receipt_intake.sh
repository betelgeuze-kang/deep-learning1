#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ad_complete_source_review_dispatch_receipt_intake"
RUN_DIR="$RESULTS_DIR/$PREFIX/intake_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AD_REUSE_EXISTING="${V53AD_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": "1",
    "v53ac_complete_source_review_dispatch_archive_ready": "1",
    "receipt_dir_supplied": "0",
    "receipt_dir_exists": "0",
    "dispatch_receipt_template_rows": "21",
    "supplied_dispatch_receipt_rows": "0",
    "accepted_dispatch_receipt_rows": "0",
    "missing_dispatch_receipt_rows": "21",
    "invalid_dispatch_receipt_rows": "0",
    "dispatch_receipt_intake_ready": "0",
    "dispatch_archive_ready": "1",
    "archive_sha256_ready": "1",
    "payload_like_archive_member_rows": "0",
    "dispatch_chunk_rows": "21",
    "dispatch_task_rows": "8000",
    "dispatch_return_artifact_rows": "50",
    "expected_human_review_rows": "7000",
    "answer_review_accepted_rows": "0",
    "review_return_ready": "0",
    "v53_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ad {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_review_dispatch_receipt_status_rows.csv",
    "complete_source_review_dispatch_receipt_requirement_rows.csv",
    "complete_source_review_dispatch_receipt_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AD_COMPLETE_SOURCE_REVIEW_DISPATCH_RECEIPT_INTAKE_BOUNDARY.md",
    "v53ad_complete_source_review_dispatch_receipt_intake_manifest.json",
    "source_v53ac/v53ac_complete_source_review_dispatch_archive_summary.csv",
    "source_v53ab/complete_source_review_dispatch_receipt_template_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ad artifact: {rel}")

receipt_rows = read_csv(run_dir / "complete_source_review_dispatch_receipt_status_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_review_dispatch_receipt_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_review_dispatch_receipt_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(receipt_rows) != 21:
    raise SystemExit("v53ad expected 21 receipt rows")
if any(row["receipt_status"] != "missing" for row in receipt_rows):
    raise SystemExit("v53ad default path should mark all receipts missing")
if sum(int(row["receipt_accepted"]) for row in receipt_rows) != 0:
    raise SystemExit("v53ad default path must accept zero receipts")
if any(row["route_jump_rows"] != "0" for row in receipt_rows):
    raise SystemExit("v53ad route jumps must stay zero")

for field, value in expected.items():
    if field.startswith("v53ad_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ad metric {field}: expected {value}, got {metric[field]}")

if requirements["v53ac-dispatch-archive-input"]["status"] != "pass":
    raise SystemExit("v53ad v53ac input should pass")
for requirement_id in [
    "receipt-directory-supplied",
    "dispatch-receipts-accepted",
    "review-return-accepted",
    "actual-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ad requirement should stay blocked: {requirement_id}")

if decisions["v53ac-dispatch-archive-input"] != "pass":
    raise SystemExit("v53ad v53ac decision should pass")
for gate in [
    "dispatch-receipt-intake",
    "review-return-accepted",
    "v53-ready",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ad gate should stay blocked: {gate}")

for gap in ["dispatch-receipt-intake", "review-return-accepted", "v53-ready", "actual-generation"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ad gap should stay blocked: {gap}")

boundary = (run_dir / "V53AD_COMPLETE_SOURCE_REVIEW_DISPATCH_RECEIPT_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "receipt_dir_supplied=0",
    "receipt_dir_exists=0",
    "dispatch_receipt_template_rows=21",
    "supplied_dispatch_receipt_rows=0",
    "accepted_dispatch_receipt_rows=0",
    "missing_dispatch_receipt_rows=21",
    "dispatch_receipt_intake_ready=0",
    "dispatch_archive_ready=1",
    "archive_sha256_ready=1",
    "payload_like_archive_member_rows=0",
    "dispatch_chunk_rows=21",
    "dispatch_task_rows=8000",
    "dispatch_return_artifact_rows=50",
    "answer_review_accepted_rows=0",
    "review_return_ready=0",
    "v53_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ad boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ad_complete_source_review_dispatch_receipt_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ad_complete_source_review_dispatch_receipt_intake_ready") != 1:
    raise SystemExit("v53ad manifest readiness mismatch")
if manifest.get("accepted_dispatch_receipt_rows") != 0:
    raise SystemExit("v53ad manifest must keep accepted receipts at zero")
if manifest.get("answer_review_accepted_rows") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ad manifest must keep review/generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53ad manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ad sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ad produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ad complete-source review dispatch receipt intake smoke passed"
