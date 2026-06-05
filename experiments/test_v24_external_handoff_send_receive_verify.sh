#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
HANDOFF_DIR="$RESULTS_DIR/v24_external_handoff_send_receive_verify/handoff_001"
SUMMARY_CSV="$RESULTS_DIR/v24_external_handoff_send_receive_verify_summary.csv"
DECISION_CSV="$RESULTS_DIR/v24_external_handoff_send_receive_verify_decision.csv"

"$ROOT_DIR/experiments/run_v24_external_handoff_send_receive_verify.sh" >/dev/null

python3 - "$HANDOFF_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

handoff_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v24 summary row, got {len(rows)}")
summary = rows[0]
for field in ["handoff_ready", "send_packet_ready", "return_inbox_ready", "v18_verification_commands_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v24 {field}: expected 1 got {summary.get(field)}")
if summary.get("handoff_rows") != "3":
    raise SystemExit(f"v24 expected three handoff rows, got {summary.get('handoff_rows')}")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v24 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("send-receive-verify-handoff") != "pass":
    raise SystemExit("v24 handoff gate should pass")
for gate in [
    "third-party-rerun-return",
    "official-benchmark-return",
    "commercial-closed-corpus-poc-return",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v24 actual gate should remain blocked: {gate}")

required_files = [
    "send/SEND_PACKET.md",
    "receive/RETURN_INBOX.md",
    "verify/VERIFY_WITH_V18.md",
    "verify/VERIFY_ANY_RETURN_WITH_V18.sh",
    "CURRENT_BLOCKERS.md",
    "handoff_rows.csv",
    "handoff_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = handoff_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v24 artifact: {rel}")

checks = {
    "send/SEND_PACKET.md": [
        "results/v21_external_review_dispatch_kit/dispatch_001/",
        "results/v22_clean_machine_execution_kit/kit_001/",
    ],
    "receive/RETURN_INBOX.md": [
        "third_party_return",
        "official_return",
        "commercial_return",
        "privacy/reliability review",
    ],
    "verify/VERIFY_WITH_V18.md": [
        "V18_THIRD_PARTY_RERUN_DIR",
        "V18_OFFICIAL_BENCHMARK_DIR",
        "V18_COMMERCIAL_POC_DIR",
    ],
    "CURRENT_BLOCKERS.md": [
        "independent_rerun_actual_ready=0",
        "candidate_external_benchmark_result_ready=0",
        "closed_corpus_poc_actual_ready=0",
    ],
}
for rel, snippets in checks.items():
    text = (handoff_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v24 artifact {rel} missing snippet: {snippet}")

manifest = json.loads((handoff_dir / "handoff_manifest.json").read_text(encoding="utf-8"))
for field in ["handoff_ready", "send_packet_ready", "return_inbox_ready", "v18_verification_commands_ready"]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v24 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v24 manifest overstated readiness: {field}")

with (handoff_dir / "handoff_rows.csv").open(newline="", encoding="utf-8") as handle:
    handoff_rows = list(csv.DictReader(handle))
if {row["return_env"] for row in handoff_rows} != {"V18_THIRD_PARTY_RERUN_DIR", "V18_OFFICIAL_BENCHMARK_DIR", "V18_COMMERCIAL_POC_DIR"}:
    raise SystemExit("v24 handoff rows should use V18 env vars")
if any(row["current_value"] != "0" for row in handoff_rows):
    raise SystemExit("v24 current values should remain blocked")

with (handoff_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v24 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(handoff_dir / rel):
        raise SystemExit(f"v24 artifact hash mismatch: {rel}")
PY

echo "v24 external handoff send/receive/verify smoke passed"
