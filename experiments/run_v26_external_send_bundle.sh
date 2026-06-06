#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v26_external_send_bundle"
BUNDLE_ID="${V26_BUNDLE_ID:-bundle_001}"
BUNDLE_DIR="${V26_BUNDLE_DIR:-$RESULTS_DIR/${PREFIX}/$BUNDLE_ID}"
V25_PACKET_DIR="${V25_PACKET_DIR:-$RESULTS_DIR/v25_outbound_send_manifest/packet_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$BUNDLE_DIR"

"$ROOT_DIR/experiments/run_v25_outbound_send_manifest.sh" >/dev/null

python3 - "$ROOT_DIR" "$BUNDLE_DIR" "$V25_PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
bundle_dir = Path(sys.argv[2])
v25_packet_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
bundle_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["send_bundle", "verify", "source_manifests"]:
    ensure(bundle_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

def copy_file(src, rel):
    dst = bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

v25_manifest = read_json(v25_packet_dir / "outbound_send_manifest.json")
copy_file(v25_packet_dir / "outbound_send_manifest.json", "source_manifests/v25_outbound_send_manifest.json")
copy_file(v25_packet_dir / "outbound" / "OUTBOUND_FILE_MANIFEST.csv", "source_manifests/v25_outbound_file_manifest.csv")
copy_file(v25_packet_dir / "outbound" / "OUTBOUND_SHA256SUMS.txt", "source_manifests/v25_outbound_sha256sums.txt")

with (v25_packet_dir / "outbound" / "OUTBOUND_FILE_MANIFEST.csv").open(newline="", encoding="utf-8") as handle:
    outbound_rows = list(csv.DictReader(handle))

copy_rows = []
for row in outbound_rows:
    src = root / row["path"]
    if not src.is_file():
        raise SystemExit(f"outbound source missing: {row['path']}")
    dst_rel = Path("send_bundle") / row["path"]
    dst = copy_file(src, dst_rel)
    source_sha = sha256(src)
    copied_sha = sha256(dst)
    copy_rows.append(
        {
            "packet": row["packet"],
            "source_path": row["path"],
            "bundle_path": str(dst.relative_to(bundle_dir)),
            "source_sha256": source_sha,
            "bundle_sha256": copied_sha,
            "sha256_match": int(source_sha == copied_sha == row["sha256"]),
            "bytes": dst.stat().st_size,
        }
    )

with (bundle_dir / "send_bundle" / "BUNDLE_FILE_MANIFEST.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=["packet", "source_path", "bundle_path", "source_sha256", "bundle_sha256", "sha256_match", "bytes"],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(copy_rows)

with (bundle_dir / "send_bundle" / "BUNDLE_SHA256SUMS.txt").open("w", encoding="utf-8") as handle:
    for row in copy_rows:
        handle.write(f"{row['bundle_sha256'].replace('sha256:', '')}  {row['bundle_path']}\n")

(bundle_dir / "SEND_BUNDLE_README.md").write_text(
    "\n".join(
        [
            "# v26 External Send Bundle",
            "",
            "This directory is the single outbound unit for the current external-validation loop.",
            "",
            "It contains copied files from:",
            "- `results/v21_external_review_dispatch_kit/dispatch_001/`",
            "- `results/v22_clean_machine_execution_kit/kit_001/`",
            "- the v25 outbound manifest files that describe and verify the send packet",
            "",
            "Send this whole `results/v26_external_send_bundle/bundle_001/` directory to the external reviewer, benchmark runner, or PoC owner.",
            "",
            "Receiver integrity check from the repository root:",
            "",
            "```bash",
            "sha256sum -c results/v26_external_send_bundle/bundle_001/send_bundle/BUNDLE_SHA256SUMS.txt",
            "```",
            "",
            "Return one of:",
            "- third-party rerun return directory",
            "- official benchmark return directory",
            "- commercial closed-corpus PoC return directory",
            "",
            "Verification remains direct v18 intake with `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, and `V18_COMMERCIAL_POC_DIR`.",
            "",
        ]
    ),
    encoding="utf-8",
)

(bundle_dir / "verify" / "VERIFY_RETURN_WITH_V18.md").write_text(
    "\n".join(
        [
            "# Verify Returned Directory With v18",
            "",
            "Third-party rerun:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Official benchmark reconciliation:",
            "",
            "```bash",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Commercial closed-corpus PoC:",
            "",
            "```bash",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

send_bundle_ready = 1
all_hashes_match = int(all(row["sha256_match"] == 1 for row in copy_rows))
manifest = {
    "manifest_scope": "v26-external-send-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v25_outbound_send_manifest_sha256": sha256(v25_packet_dir / "outbound_send_manifest.json"),
    "send_bundle_ready": send_bundle_ready,
    "single_directory_send_ready": 1,
    "bundle_file_rows": len(copy_rows),
    "bundle_hashes_match": all_hashes_match,
    "receiver_integrity_check_ready": 1,
    "v18_verify_instructions_ready": 1,
    "independent_rerun_actual_ready": bool_int(v25_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v25_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v25_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v25_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v25_manifest.get("real_release_package_ready", 0)),
    "claim": "single-directory external send bundle ready; actual readiness requires returned external directories verified by v18",
}
(bundle_dir / "send_bundle_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "SEND_BUNDLE_README.md",
    "send_bundle/BUNDLE_FILE_MANIFEST.csv",
    "send_bundle/BUNDLE_SHA256SUMS.txt",
    "verify/VERIFY_RETURN_WITH_V18.md",
    "source_manifests/v25_outbound_send_manifest.json",
    "source_manifests/v25_outbound_file_manifest.csv",
    "source_manifests/v25_outbound_sha256sums.txt",
    "send_bundle_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = bundle_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (bundle_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "bundle_id": bundle_dir.name,
        "send_bundle_ready": send_bundle_ready,
        "single_directory_send_ready": 1,
        "bundle_file_rows": len(copy_rows),
        "bundle_hashes_match": all_hashes_match,
        "receiver_integrity_check_ready": 1,
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
    ("external-send-bundle", "pass", "v21/v22/v25 outbound files are copied into one send directory"),
    ("bundle-hash-check", "pass" if all_hashes_match else "fail", "all copied files must match v25 sha256s"),
    ("receiver-integrity-check", "pass", "receiver can run sha256sum -c on BUNDLE_SHA256SUMS.txt"),
    ("third-party-rerun-return", "blocked", "requires returned third-party rerun directory"),
    ("official-benchmark-return", "blocked", "requires returned official benchmark directory"),
    ("commercial-closed-corpus-poc-return", "blocked", "requires returned commercial PoC directory"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v26_external_send_bundle_dir: $BUNDLE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
