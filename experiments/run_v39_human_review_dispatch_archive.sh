#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v39_human_review_dispatch_archive"
ARCHIVE_ID="${V39_ARCHIVE_ID:-archive_001}"
ARCHIVE_DIR="${V39_ARCHIVE_DIR:-$RESULTS_DIR/${PREFIX}/$ARCHIVE_ID}"
DEFAULT_V38_BUNDLE_DIR="$RESULTS_DIR/v38_human_review_dispatch_bundle/bundle_001"
V38_BUNDLE_DIR="${V39_V38_BUNDLE_DIR:-$DEFAULT_V38_BUNDLE_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [ ! -f "$V38_BUNDLE_DIR/human_review_dispatch_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v38_human_review_dispatch_bundle.sh" >/dev/null
fi

mkdir -p "$ARCHIVE_DIR"

python3 - "$ROOT_DIR" "$ARCHIVE_DIR" "$V38_BUNDLE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
import tarfile
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
archive_dir = Path(sys.argv[2])
v38_bundle_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

if archive_dir.exists():
    shutil.rmtree(archive_dir)
archive_dir.mkdir(parents=True)
archive_subdir = archive_dir / "archive"
archive_subdir.mkdir(parents=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_csv_one(path):
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}, got {len(rows)}")
    return rows[0]

def rel(path):
    return str(path.relative_to(root))

required_bundle_files = [
    "HUMAN_REVIEW_DISPATCH_README.md",
    "human_review_dispatch_manifest.json",
    "sha256_manifest.csv",
    "review_packet/HUMAN_REVIEW_REQUEST.md",
    "review_packet/human_review_template.csv",
    "review_packet/RELEASE_CLAIM_AUDIT.md",
    "return/human_review_rows.csv",
    "verify/VERIFY_RETURN.sh",
]
for rel_name in required_bundle_files:
    path = v38_bundle_dir / rel_name
    if not path.is_file():
        raise SystemExit(f"v39 requires v38 bundle artifact: {path}")

v38_manifest = read_json(v38_bundle_dir / "human_review_dispatch_manifest.json")
v38_summary = read_csv_one(root / "results" / "v38_human_review_dispatch_bundle_summary.csv")
v38_ready = int(v38_manifest.get("human_review_dispatch_bundle_ready") == 1 and v38_summary.get("v38_human_review_dispatch_bundle_ready") == "1")

archive_name = f"v38_human_review_dispatch_bundle_{v38_bundle_dir.name}.tar.gz"
archive_path = archive_subdir / archive_name
archive_root = f"v38_human_review_dispatch_bundle_{v38_bundle_dir.name}"
with tarfile.open(archive_path, "w:gz") as tar:
    for path in sorted(v38_bundle_dir.rglob("*")):
        arcname = Path(archive_root) / path.relative_to(v38_bundle_dir)
        tar.add(path, arcname=str(arcname), recursive=False)

members = []
with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())

file_list_path = archive_subdir / "ARCHIVE_FILE_LIST.txt"
file_list_path.write_text("\n".join(members) + "\n", encoding="utf-8")
sha_path = archive_subdir / "ARCHIVE_SHA256SUMS.txt"
sha_path.write_text(f"{sha256(archive_path)}  {archive_name}\n{sha256(file_list_path)}  ARCHIVE_FILE_LIST.txt\n", encoding="utf-8")

readme = archive_dir / "SEND_ARCHIVE_README.md"
readme.write_text(
    "\n".join(
        [
            "# v39 Human Review Dispatch Archive",
            "",
            "Send the archive under `archive/` to the external reviewer.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "cd archive",
            "sha256sum -c ARCHIVE_SHA256SUMS.txt",
            "tar -tzf v38_human_review_dispatch_bundle_bundle_001.tar.gz",
            "```",
            "",
            "After extraction, fill `return/human_review_rows.csv` and run `verify/VERIFY_RETURN.sh` from the extracted bundle.",
            "",
            "This archive does not complete human review by itself.",
            "",
        ]
    ),
    encoding="utf-8",
)

required_member_suffixes = [
    "review_packet/HUMAN_REVIEW_REQUEST.md",
    "review_packet/human_review_template.csv",
    "review_packet/RELEASE_CLAIM_AUDIT.md",
    "return/human_review_rows.csv",
    "verify/VERIFY_RETURN.sh",
]
member_set = set(members)
required_members_present = int(all(any(member.endswith(suffix) for member in member_set) for suffix in required_member_suffixes))
archive_ready = int(archive_path.is_file() and archive_path.stat().st_size > 0)
archive_sha256_ready = int(sha_path.is_file() and archive_name in sha_path.read_text(encoding="utf-8"))
archive_file_list_ready = int(file_list_path.is_file() and required_members_present)
v39_ready = int(v38_ready and archive_ready and archive_sha256_ready and archive_file_list_ready and readme.is_file())

manifest = {
    "manifest_scope": "v39-human-review-dispatch-archive",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "archive_id": archive_dir.name,
    "v38_bundle_dir": rel(v38_bundle_dir),
    "archive_path": rel(archive_path),
    "archive_sha256": sha256(archive_path),
    "archive_member_files": len(members),
    "required_members_present": required_members_present,
    "human_review_dispatch_archive_ready": v39_ready,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(archive_dir / "human_review_dispatch_archive_manifest.json", manifest)

artifact_rows = []
for artifact in [archive_path, file_list_path, sha_path, readme, archive_dir / "human_review_dispatch_archive_manifest.json"]:
    artifact_rows.append({"artifact": artifact.stem, "path": rel(artifact), "sha256": sha256(artifact), "bytes": artifact.stat().st_size})
write_csv(archive_dir / "artifact_manifest.csv", ["artifact", "path", "sha256", "bytes"], artifact_rows)

sha_rows = []
for path in sorted(archive_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(archive_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(archive_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "archive_id": archive_dir.name,
        "v39_human_review_dispatch_archive_ready": v39_ready,
        "v38_human_review_dispatch_bundle_ready": v38_ready,
        "archive_ready": archive_ready,
        "archive_sha256_ready": archive_sha256_ready,
        "archive_file_list_ready": archive_file_list_ready,
        "required_members_present": required_members_present,
        "archive_member_files": len(members),
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v39-human-review-dispatch-archive", "status": status(v39_ready), "reason": "archive, checksum, file list, and send README are ready" if v39_ready else "dispatch archive incomplete"},
    {"gate": "v38-dispatch-bundle", "status": status(v38_ready), "reason": "v38 bundle is ready"},
    {"gate": "archive-file", "status": status(archive_ready), "reason": rel(archive_path)},
    {"gate": "archive-sha256", "status": status(archive_sha256_ready), "reason": "ARCHIVE_SHA256SUMS.txt written"},
    {"gate": "archive-members", "status": status(required_members_present), "reason": f"{len(members)} files in archive"},
    {"gate": "human-review", "status": "blocked", "reason": "archive is ready to send, but no returned review has been accepted by v37"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release remains blocked until returned human review and any requested rerun"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v39_human_review_dispatch_archive_dir: $ARCHIVE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
