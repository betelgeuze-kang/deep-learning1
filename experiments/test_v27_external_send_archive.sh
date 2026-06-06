#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
ARCHIVE_DIR="$RESULTS_DIR/v27_external_send_archive/archive_001"
SUMMARY_CSV="$RESULTS_DIR/v27_external_send_archive_summary.csv"
DECISION_CSV="$RESULTS_DIR/v27_external_send_archive_decision.csv"

"$ROOT_DIR/experiments/run_v27_external_send_archive.sh" >/dev/null

python3 - "$ROOT_DIR" "$ARCHIVE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
archive_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v27 summary row, got {len(rows)}")
summary = rows[0]
for field in ["external_send_archive_ready", "send_bundle_ready", "archive_listing_ready", "archive_integrity_check_ready", "v18_verify_instructions_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v27 {field}: expected 1 got {summary.get(field)}")
if int(summary.get("archive_file_count", "0")) <= 0:
    raise SystemExit("v27 archive file count should be positive")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v27 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["external-send-archive", "archive-integrity-check", "return-verification-instructions"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v27 gate should pass: {gate}")
for gate in ["third-party-rerun-return", "official-benchmark-return", "commercial-closed-corpus-poc-return"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v27 return gate should remain blocked: {gate}")

required_files = [
    "archive/v26_external_send_bundle_bundle_001.tar.gz",
    "archive/ARCHIVE_SHA256SUMS.txt",
    "archive/ARCHIVE_FILE_LIST.txt",
    "SEND_ARCHIVE_README.md",
    "verify/VERIFY_ARCHIVE_AND_RETURNS.md",
    "send_archive_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = archive_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v27 artifact: {rel}")

checks = {
    "SEND_ARCHIVE_README.md": [
        "v26_external_send_bundle_bundle_001.tar.gz",
        "sha256sum -c",
        "V18_THIRD_PARTY_RERUN_DIR",
    ],
    "verify/VERIFY_ARCHIVE_AND_RETURNS.md": [
        "V18_OFFICIAL_BENCHMARK_DIR",
        "V18_COMMERCIAL_POC_DIR",
    ],
}
for rel, snippets in checks.items():
    text = (archive_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v27 artifact {rel} missing snippet: {snippet}")

archive_path = archive_dir / "archive" / "v26_external_send_bundle_bundle_001.tar.gz"
manifest = json.loads((archive_dir / "send_archive_manifest.json").read_text(encoding="utf-8"))
if manifest.get("archive_sha256") != sha256(archive_path):
    raise SystemExit("v27 archive sha256 mismatch")
for field in ["external_send_archive_ready", "archive_listing_ready", "archive_integrity_check_ready", "v18_verify_instructions_ready"]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v27 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v27 manifest overstated readiness: {field}")

listing = subprocess.check_output(["tar", "-tzf", str(archive_path)], text=True).splitlines()
if "results/v26_external_send_bundle/bundle_001/SEND_BUNDLE_README.md" not in listing:
    raise SystemExit("v27 archive missing send bundle README")
if not any(path.endswith("send_bundle/BUNDLE_FILE_MANIFEST.csv") for path in listing):
    raise SystemExit("v27 archive missing bundle file manifest")
if manifest.get("archive_file_count") != len([line for line in listing if line.strip()]):
    raise SystemExit("v27 archive file count mismatch")

with (archive_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v27 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(archive_dir / rel):
        raise SystemExit(f"v27 artifact hash mismatch: {rel}")
PY

echo "v27 external send archive smoke passed"
