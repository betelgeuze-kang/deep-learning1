#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
BUNDLE_DIR="$RESULTS_DIR/v26_external_send_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v26_external_send_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v26_external_send_bundle_decision.csv"

"$ROOT_DIR/experiments/run_v26_external_send_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$BUNDLE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
bundle_dir = Path(sys.argv[2])
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
    raise SystemExit(f"expected one v26 summary row, got {len(rows)}")
summary = rows[0]
for field in ["send_bundle_ready", "single_directory_send_ready", "bundle_hashes_match", "receiver_integrity_check_ready", "v18_verify_instructions_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v26 {field}: expected 1 got {summary.get(field)}")
if int(summary.get("bundle_file_rows", "0")) <= 0:
    raise SystemExit("v26 bundle file rows should be positive")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v26 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["external-send-bundle", "bundle-hash-check", "receiver-integrity-check"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v26 gate should pass: {gate}")
for gate in ["third-party-rerun-return", "official-benchmark-return", "commercial-closed-corpus-poc-return"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v26 return gate should remain blocked: {gate}")

required_files = [
    "SEND_BUNDLE_README.md",
    "send_bundle/BUNDLE_FILE_MANIFEST.csv",
    "send_bundle/BUNDLE_SHA256SUMS.txt",
    "verify/VERIFY_RETURN_WITH_V18.md",
    "source_manifests/v25_outbound_send_manifest.json",
    "send_bundle_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = bundle_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v26 artifact: {rel}")

checks = {
    "SEND_BUNDLE_README.md": [
        "results/v26_external_send_bundle/bundle_001/",
        "sha256sum -c",
        "V18_THIRD_PARTY_RERUN_DIR",
    ],
    "verify/VERIFY_RETURN_WITH_V18.md": [
        "V18_OFFICIAL_BENCHMARK_DIR",
        "V18_COMMERCIAL_POC_DIR",
    ],
}
for rel, snippets in checks.items():
    text = (bundle_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v26 artifact {rel} missing snippet: {snippet}")

with (bundle_dir / "send_bundle" / "BUNDLE_FILE_MANIFEST.csv").open(newline="", encoding="utf-8") as handle:
    bundle_rows = list(csv.DictReader(handle))
if {row["packet"] for row in bundle_rows} != {"v21_dispatch_kit", "v22_clean_machine_execution_kit"}:
    raise SystemExit("v26 bundle packet set mismatch")
if any(row["sha256_match"] != "1" for row in bundle_rows):
    raise SystemExit("v26 bundle hash match should be 1 for every copied file")
for row in bundle_rows:
    src = root / row["source_path"]
    dst = bundle_dir / row["bundle_path"]
    if not src.is_file() or not dst.is_file():
        raise SystemExit(f"v26 copied file missing: {row['source_path']}")
    if sha256(src) != row["source_sha256"] or sha256(dst) != row["bundle_sha256"]:
        raise SystemExit(f"v26 copied file hash mismatch: {row['source_path']}")

manifest = json.loads((bundle_dir / "send_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("bundle_file_rows") != len(bundle_rows):
    raise SystemExit("v26 manifest bundle row count mismatch")
for field in ["send_bundle_ready", "single_directory_send_ready", "bundle_hashes_match", "receiver_integrity_check_ready", "v18_verify_instructions_ready"]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v26 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v26 manifest overstated readiness: {field}")

with (bundle_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v26 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(bundle_dir / rel):
        raise SystemExit(f"v26 artifact hash mismatch: {rel}")
PY

echo "v26 external send bundle smoke passed"
