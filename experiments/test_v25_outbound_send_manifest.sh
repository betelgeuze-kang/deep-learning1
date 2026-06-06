#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKET_DIR="$RESULTS_DIR/v25_outbound_send_manifest/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v25_outbound_send_manifest_summary.csv"
DECISION_CSV="$RESULTS_DIR/v25_outbound_send_manifest_decision.csv"

"$ROOT_DIR/experiments/run_v25_outbound_send_manifest.sh" >/dev/null

python3 - "$ROOT_DIR" "$PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
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
    raise SystemExit(f"expected one v25 summary row, got {len(rows)}")
summary = rows[0]
for field in ["outbound_send_manifest_ready", "receiver_ack_template_ready", "return_options_ready", "v18_verify_instructions_ready", "send_packet_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v25 {field}: expected 1 got {summary.get(field)}")
if int(summary.get("outbound_file_rows", "0")) <= 0:
    raise SystemExit("v25 outbound file rows should be positive")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v25 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["outbound-send-manifest", "receiver-ack-template", "return-verification-instructions"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v25 gate should pass: {gate}")
for gate in ["third-party-rerun-return", "official-benchmark-return", "commercial-closed-corpus-poc-return"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v25 return gate should remain blocked: {gate}")

required_files = [
    "outbound/OUTBOUND_FILE_MANIFEST.csv",
    "outbound/OUTBOUND_SHA256SUMS.txt",
    "outbound/SEND_INSTRUCTIONS.md",
    "receiver/RECEIVER_ACK_TEMPLATE.csv",
    "receiver/RETURN_OPTIONS.md",
    "verify/VERIFY_RETURN_WITH_V18.md",
    "outbound_send_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = packet_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v25 artifact: {rel}")

checks = {
    "outbound/SEND_INSTRUCTIONS.md": [
        "results/v21_external_review_dispatch_kit/dispatch_001/",
        "results/v22_clean_machine_execution_kit/kit_001/",
        "sha256sum -c",
    ],
    "receiver/RETURN_OPTIONS.md": [
        "third_party_return",
        "official_return",
        "commercial_return",
    ],
    "verify/VERIFY_RETURN_WITH_V18.md": [
        "V18_THIRD_PARTY_RERUN_DIR",
        "V18_OFFICIAL_BENCHMARK_DIR",
        "V18_COMMERCIAL_POC_DIR",
    ],
}
for rel, snippets in checks.items():
    text = (packet_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v25 artifact {rel} missing snippet: {snippet}")

with (packet_dir / "outbound" / "OUTBOUND_FILE_MANIFEST.csv").open(newline="", encoding="utf-8") as handle:
    outbound_rows = list(csv.DictReader(handle))
packets = {row["packet"] for row in outbound_rows}
if packets != {"v21_dispatch_kit", "v22_clean_machine_execution_kit"}:
    raise SystemExit(f"v25 outbound packet set mismatch: {packets}")
for row in outbound_rows:
    path = root / row["path"]
    if not path.is_file():
        raise SystemExit(f"v25 outbound manifest references missing file: {row['path']}")
    if row["sha256"] != sha256(path):
        raise SystemExit(f"v25 outbound manifest hash mismatch: {row['path']}")

manifest = json.loads((packet_dir / "outbound_send_manifest.json").read_text(encoding="utf-8"))
if manifest.get("outbound_file_rows") != len(outbound_rows):
    raise SystemExit("v25 manifest outbound row count mismatch")
for field in ["outbound_send_manifest_ready", "receiver_ack_template_ready", "return_options_ready", "v18_verify_instructions_ready"]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v25 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v25 manifest overstated readiness: {field}")

with (packet_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v25 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(packet_dir / rel):
        raise SystemExit(f"v25 artifact hash mismatch: {rel}")
PY

echo "v25 outbound send manifest smoke passed"
