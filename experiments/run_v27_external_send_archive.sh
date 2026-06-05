#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v27_external_send_archive"
ARCHIVE_ID="${V27_ARCHIVE_ID:-archive_001}"
ARCHIVE_DIR="${V27_ARCHIVE_DIR:-$RESULTS_DIR/${PREFIX}/$ARCHIVE_ID}"
V26_BUNDLE_DIR="${V26_BUNDLE_DIR:-$RESULTS_DIR/v26_external_send_bundle/bundle_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$ARCHIVE_DIR"

"$ROOT_DIR/experiments/run_v26_external_send_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$ARCHIVE_DIR" "$V26_BUNDLE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
archive_dir = Path(sys.argv[2])
v26_bundle_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
archive_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["archive", "verify", "source_manifests"]:
    ensure(archive_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = archive_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v26_manifest = read_json(v26_bundle_dir / "send_bundle_manifest.json")
copy(v26_bundle_dir / "send_bundle_manifest.json", "source_manifests/v26_send_bundle_manifest.json")
copy(v26_bundle_dir / "send_bundle" / "BUNDLE_FILE_MANIFEST.csv", "source_manifests/v26_bundle_file_manifest.csv")
copy(v26_bundle_dir / "send_bundle" / "BUNDLE_SHA256SUMS.txt", "source_manifests/v26_bundle_sha256sums.txt")

archive_name = "v26_external_send_bundle_bundle_001.tar.gz"
archive_path = archive_dir / "archive" / archive_name
relative_bundle = v26_bundle_dir.relative_to(root)
subprocess.run(
    [
        "tar",
        "--sort=name",
        "--mtime=UTC 2026-01-01",
        "--owner=0",
        "--group=0",
        "--numeric-owner",
        "-czf",
        str(archive_path),
        "-C",
        str(root),
        str(relative_bundle),
    ],
    check=True,
)

listing = subprocess.check_output(["tar", "-tzf", str(archive_path)], text=True)
(archive_dir / "archive" / "ARCHIVE_FILE_LIST.txt").write_text(listing, encoding="utf-8")
archive_sha = sha256(archive_path)
(archive_dir / "archive" / "ARCHIVE_SHA256SUMS.txt").write_text(
    f"{archive_sha.replace('sha256:', '')}  archive/{archive_name}\n",
    encoding="utf-8",
)

(archive_dir / "SEND_ARCHIVE_README.md").write_text(
    "\n".join(
        [
            "# v27 External Send Archive",
            "",
            "This packet compresses the v26 single send bundle into one archive for transfer.",
            "",
            "Send:",
            f"- `results/v27_external_send_archive/archive_001/archive/{archive_name}`",
            "- `results/v27_external_send_archive/archive_001/archive/ARCHIVE_SHA256SUMS.txt`",
            "- `results/v27_external_send_archive/archive_001/verify/VERIFY_ARCHIVE_AND_RETURNS.md`",
            "",
            "Receiver archive integrity check from `results/v27_external_send_archive/archive_001/`:",
            "",
            "```bash",
            "sha256sum -c archive/ARCHIVE_SHA256SUMS.txt",
            "```",
            "",
            "After unpacking the archive, the receiver can run the v26 bundle integrity check:",
            "",
            "```bash",
            "sha256sum -c results/v26_external_send_bundle/bundle_001/send_bundle/BUNDLE_SHA256SUMS.txt",
            "```",
            "",
            "This archive is send evidence only. Actual readiness still requires a returned third-party, official benchmark, or commercial PoC directory verified by v18.",
            "",
            "Direct v18 return variables: `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and `V18_COMMERCIAL_POC_DIR`.",
            "",
        ]
    ),
    encoding="utf-8",
)

(archive_dir / "verify" / "VERIFY_ARCHIVE_AND_RETURNS.md").write_text(
    "\n".join(
        [
            "# Verify Archive And Returned Evidence",
            "",
            "Archive integrity:",
            "",
            "```bash",
            "cd results/v27_external_send_archive/archive_001",
            "sha256sum -c archive/ARCHIVE_SHA256SUMS.txt",
            "tar -tzf archive/v26_external_send_bundle_bundle_001.tar.gz > /tmp/v27_archive_listing.txt",
            "```",
            "",
            "Returned third-party rerun directory:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Returned official benchmark directory:",
            "",
            "```bash",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Returned commercial closed-corpus PoC directory:",
            "",
            "```bash",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

archive_file_count = len([line for line in listing.splitlines() if line.strip()])
external_send_archive_ready = 1
manifest = {
    "manifest_scope": "v27-external-send-archive",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v26_send_bundle_manifest_sha256": sha256(v26_bundle_dir / "send_bundle_manifest.json"),
    "external_send_archive_ready": external_send_archive_ready,
    "archive_path": str(archive_path.relative_to(root)),
    "archive_sha256": archive_sha,
    "archive_file_count": archive_file_count,
    "archive_listing_ready": 1,
    "archive_integrity_check_ready": 1,
    "v18_verify_instructions_ready": 1,
    "send_bundle_ready": bool_int(v26_manifest.get("send_bundle_ready", 0)),
    "independent_rerun_actual_ready": bool_int(v26_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v26_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v26_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v26_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v26_manifest.get("real_release_package_ready", 0)),
    "claim": "external send archive ready; actual readiness requires returned external directories verified by v18",
}
(archive_dir / "send_archive_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    f"archive/{archive_name}",
    "archive/ARCHIVE_SHA256SUMS.txt",
    "archive/ARCHIVE_FILE_LIST.txt",
    "SEND_ARCHIVE_README.md",
    "verify/VERIFY_ARCHIVE_AND_RETURNS.md",
    "source_manifests/v26_send_bundle_manifest.json",
    "source_manifests/v26_bundle_file_manifest.csv",
    "source_manifests/v26_bundle_sha256sums.txt",
    "send_archive_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = archive_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (archive_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "archive_id": archive_dir.name,
        "external_send_archive_ready": external_send_archive_ready,
        "send_bundle_ready": manifest["send_bundle_ready"],
        "archive_file_count": archive_file_count,
        "archive_listing_ready": 1,
        "archive_integrity_check_ready": 1,
        "v18_verify_instructions_ready": 1,
        "independent_rerun_actual_ready": manifest["independent_rerun_actual_ready"],
        "candidate_external_benchmark_result_ready": manifest["candidate_external_benchmark_result_ready"],
        "closed_corpus_poc_actual_ready": manifest["closed_corpus_poc_actual_ready"],
        "real_external_benchmark_verified": manifest["real_external_benchmark_verified"],
        "real_release_package_ready": manifest["real_release_package_ready"],
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("external-send-archive", "pass", "v26 send bundle is packaged into a transfer archive"),
    ("archive-integrity-check", "pass", "archive sha256sum and listing are packaged"),
    ("return-verification-instructions", "pass", "direct v18 return verification instructions are packaged"),
    ("third-party-rerun-return", "blocked", "requires returned third-party rerun directory"),
    ("official-benchmark-return", "blocked", "requires returned official benchmark directory"),
    ("commercial-closed-corpus-poc-return", "blocked", "requires returned commercial PoC directory"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v27_external_send_archive_dir: $ARCHIVE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
