#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
ARCHIVE_DIR="$RESULTS_DIR/v39_human_review_dispatch_archive/archive_001"
SUMMARY_CSV="$RESULTS_DIR/v39_human_review_dispatch_archive_summary.csv"
DECISION_CSV="$RESULTS_DIR/v39_human_review_dispatch_archive_decision.csv"

"$ROOT_DIR/experiments/run_v39_human_review_dispatch_archive.sh" >/dev/null

python3 - "$ARCHIVE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
import tarfile
from pathlib import Path

archive_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
archive_path = archive_dir / "archive" / "v38_human_review_dispatch_bundle_bundle_001.tar.gz"

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v39 summary row, got {len(rows)}")
summary = rows[0]
for field in [
    "v39_human_review_dispatch_archive_ready",
    "v38_human_review_dispatch_bundle_ready",
    "archive_ready",
    "archive_sha256_ready",
    "archive_file_list_ready",
    "required_members_present",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v39 {field}: expected 1, got {summary.get(field)}")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v39 should keep human review and release blocked")
if int(summary.get("archive_member_files", "0")) < 14:
    raise SystemExit("v39 archive should contain the v38 bundle files")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v39-human-review-dispatch-archive",
    "v38-dispatch-bundle",
    "archive-file",
    "archive-sha256",
    "archive-members",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v39 gate should pass: {gate}")
for gate in ["human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v39 should leave {gate} blocked")

required_files = [
    "SEND_ARCHIVE_README.md",
    "human_review_dispatch_archive_manifest.json",
    "artifact_manifest.csv",
    "sha256_manifest.csv",
    "archive/ARCHIVE_FILE_LIST.txt",
    "archive/ARCHIVE_SHA256SUMS.txt",
    "archive/v38_human_review_dispatch_bundle_bundle_001.tar.gz",
]
for rel in required_files:
    path = archive_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v39 missing archive artifact: {rel}")

manifest = json.loads((archive_dir / "human_review_dispatch_archive_manifest.json").read_text(encoding="utf-8"))
if manifest.get("human_review_dispatch_archive_ready") != 1:
    raise SystemExit("v39 manifest should be ready")
if manifest.get("archive_sha256") != sha256(archive_path):
    raise SystemExit("v39 manifest archive sha mismatch")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v39 manifest should keep review/release blocked")

sha_text = (archive_dir / "archive" / "ARCHIVE_SHA256SUMS.txt").read_text(encoding="utf-8")
if sha256(archive_path) not in sha_text:
    raise SystemExit("v39 archive checksum file should include archive sha")

with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())
for suffix in [
    "review_packet/HUMAN_REVIEW_REQUEST.md",
    "review_packet/human_review_template.csv",
    "review_packet/RELEASE_CLAIM_AUDIT.md",
    "return/human_review_rows.csv",
    "verify/VERIFY_RETURN.sh",
]:
    if not any(member.endswith(suffix) for member in members):
        raise SystemExit(f"v39 archive missing member suffix: {suffix}")

readme = (archive_dir / "SEND_ARCHIVE_README.md").read_text(encoding="utf-8")
for snippet in [
    "Send the archive",
    "sha256sum -c ARCHIVE_SHA256SUMS.txt",
    "verify/VERIFY_RETURN.sh",
    "does not complete human review",
]:
    if snippet not in readme:
        raise SystemExit(f"v39 send readme missing: {snippet}")

with (archive_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v39 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(archive_dir / rel):
        raise SystemExit(f"v39 sha mismatch for {rel}")
PY

echo "v39 human review dispatch archive smoke passed"
