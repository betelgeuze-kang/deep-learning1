#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ac_complete_source_review_dispatch_archive"
RUN_DIR="$RESULTS_DIR/$PREFIX/archive_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ARCHIVE_PATH="$RUN_DIR/archive/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz"

V53AC_REUSE_EXISTING="${V53AC_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ac_complete_source_review_dispatch_archive.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ARCHIVE_PATH" <<'PY'
import csv
import hashlib
import json
import sys
import tarfile
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
archive_path = Path(sys.argv[4])


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
    "v53ac_complete_source_review_dispatch_archive_ready": "1",
    "v53ab_complete_source_review_dispatch_receipt_packet_ready": "1",
    "archive_ready": "1",
    "archive_sha256_ready": "1",
    "archive_file_list_ready": "1",
    "send_readme_ready": "1",
    "required_archive_member_rows": "9",
    "required_members_present": "1",
    "payload_like_archive_member_rows": "0",
    "dispatch_chunk_rows": "21",
    "dispatch_task_rows": "8000",
    "dispatch_return_artifact_rows": "50",
    "dispatch_receipt_template_rows": "21",
    "accepted_dispatch_receipt_rows": "0",
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
        raise SystemExit(f"v53ac {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("archive_member_files", "0")) < 78:
    raise SystemExit("v53ac archive should include the embedded work packet files")

required_files = [
    "archive/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz",
    "archive/ARCHIVE_FILE_LIST.txt",
    "archive/ARCHIVE_SHA256SUMS.txt",
    "SEND_REVIEW_DISPATCH_ARCHIVE.md",
    "complete_source_review_dispatch_archive_member_rows.csv",
    "complete_source_review_dispatch_archive_artifact_rows.csv",
    "complete_source_review_dispatch_archive_requirement_rows.csv",
    "complete_source_review_dispatch_archive_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AC_COMPLETE_SOURCE_REVIEW_DISPATCH_ARCHIVE_BOUNDARY.md",
    "v53ac_complete_source_review_dispatch_archive_manifest.json",
    "source_v53ab/v53ab_complete_source_review_dispatch_receipt_packet_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ac artifact: {rel}")

artifact_rows = read_csv(run_dir / "complete_source_review_dispatch_archive_artifact_rows.csv")
member_rows = read_csv(run_dir / "complete_source_review_dispatch_archive_member_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_review_dispatch_archive_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_review_dispatch_archive_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(artifact_rows) != 4 or any(row["artifact_ready"] != "1" for row in artifact_rows):
    raise SystemExit("v53ac archive artifact rows mismatch")
if not member_rows or sum(int(row["payload_like_member"]) for row in member_rows) != 0:
    raise SystemExit("v53ac archive must not contain payload-like members")
if sum(int(row["required_member"]) for row in member_rows) < 9:
    raise SystemExit("v53ac archive required members missing")

with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())
for suffix in [
    "README.md",
    "VERIFY_REVIEW_DISPATCH_PACKET.sh",
    "DISPATCH_CHUNK_ROWS.csv",
    "DISPATCH_RECEIPT_TEMPLATE_ROWS.csv",
    "REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv",
    "REVIEW_RETURN_REFRESH_COMMAND_ROWS.csv",
    "review_work_packet/CHUNK_PACKET_INDEX.csv",
    "review_work_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv",
    "review_work_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh",
]:
    if not any(member.endswith(suffix) for member in members):
        raise SystemExit(f"v53ac archive missing member suffix: {suffix}")
if any(member.endswith((".safetensors", ".bin", ".pt")) for member in members):
    raise SystemExit("v53ac archive includes model/checkpoint payload-like member")

sha_text = (run_dir / "archive" / "ARCHIVE_SHA256SUMS.txt").read_text(encoding="utf-8")
if sha256(archive_path) not in sha_text:
    raise SystemExit("v53ac checksum file should include archive sha")
file_list = (run_dir / "archive" / "ARCHIVE_FILE_LIST.txt").read_text(encoding="utf-8")
if "DISPATCH_CHUNK_ROWS.csv" not in file_list or "review_work_packet/CHUNK_PACKET_INDEX.csv" not in file_list:
    raise SystemExit("v53ac archive file list missing expected members")

readme = (run_dir / "SEND_REVIEW_DISPATCH_ARCHIVE.md").read_text(encoding="utf-8")
for snippet in [
    "Send the archive",
    "sha256sum -c ARCHIVE_SHA256SUMS.txt",
    "tar -tzf v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz",
    "does not complete review return",
]:
    if snippet not in readme:
        raise SystemExit(f"v53ac send readme missing: {snippet}")

for field, value in expected.items():
    if field.startswith("v53ac_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ac metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53ab-dispatch-packet-input",
    "archive-file",
    "archive-sha256",
    "archive-required-members",
    "manifest-only-no-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ac requirement should pass: {requirement_id}")
for requirement_id in ["review-return-accepted", "actual-generation"]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ac requirement should stay blocked: {requirement_id}")

for gate in ["v53ab-dispatch-packet-input", "dispatch-archive", "archive-sha256", "no-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ac decision should pass: {gate}")
for gate in ["review-return-accepted", "actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ac decision should stay blocked: {gate}")

if gaps.get("dispatch-archive") != "ready":
    raise SystemExit("v53ac dispatch-archive gap should be ready")
for gap in ["dispatch-receipts", "review-return-accepted", "actual-generation"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ac gap should stay blocked: {gap}")

boundary = (run_dir / "V53AC_COMPLETE_SOURCE_REVIEW_DISPATCH_ARCHIVE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "archive_ready=1",
    "archive_sha256_ready=1",
    "archive_file_list_ready=1",
    "send_readme_ready=1",
    "required_members_present=1",
    "payload_like_archive_member_rows=0",
    "dispatch_chunk_rows=21",
    "dispatch_task_rows=8000",
    "dispatch_return_artifact_rows=50",
    "dispatch_receipt_template_rows=21",
    "accepted_dispatch_receipt_rows=0",
    "answer_review_accepted_rows=0",
    "review_return_ready=0",
    "v53_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ac boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ac_complete_source_review_dispatch_archive_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ac_complete_source_review_dispatch_archive_ready") != 1:
    raise SystemExit("v53ac manifest readiness mismatch")
if manifest.get("archive_sha256") != sha256(archive_path):
    raise SystemExit("v53ac manifest archive sha mismatch")
if manifest.get("payload_like_archive_member_rows") != 0:
    raise SystemExit("v53ac manifest must keep payload-like members at zero")
if manifest.get("answer_review_accepted_rows") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ac manifest must keep review/generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ac sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ac produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ac complete-source review dispatch archive smoke passed"
