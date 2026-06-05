#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
INBOX_DIR="$RESULTS_DIR/v28_inbound_return_inbox/inbox_001"
SUMMARY_CSV="$RESULTS_DIR/v28_inbound_return_inbox_summary.csv"
DECISION_CSV="$RESULTS_DIR/v28_inbound_return_inbox_decision.csv"

"$ROOT_DIR/experiments/run_v28_inbound_return_inbox.sh" >/dev/null

python3 - "$INBOX_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

inbox_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v28 summary row, got {len(rows)}")
summary = rows[0]
if summary.get("inbound_return_inbox_ready") != "1":
    raise SystemExit("v28 inbox should be ready")
if summary.get("return_dirs_detected") != "0":
    raise SystemExit("v28 default should not detect returns")
if summary.get("complete_return_dirs") != "0":
    raise SystemExit("v28 default should not complete returns")
if summary.get("v18_env_dirs_passed") != "0":
    raise SystemExit("v28 default should not pass empty inbox dirs to v18")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v28 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("inbound-return-inbox") != "pass":
    raise SystemExit("v28 inbox gate should pass")
for gate in ["third-party-rerun-return", "official-benchmark-return", "commercial-closed-corpus-poc-return"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v28 return gate should remain blocked: {gate}")

required_files = [
    "INBOUND_RETURN_INBOX.md",
    "inbox_rows.csv",
    "verify/VERIFY_INBOX_WITH_V18.sh",
    "source_manifests/v18_latest_summary.csv",
    "inbound_return_inbox_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = inbox_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v28 artifact: {rel}")

text = (inbox_dir / "INBOUND_RETURN_INBOX.md").read_text(encoding="utf-8")
for snippet in ["returns/third_party_return", "V18_THIRD_PARTY_RERUN_DIR", "V18_OFFICIAL_BENCHMARK_DIR", "V18_COMMERCIAL_POC_DIR"]:
    if snippet not in text:
        raise SystemExit(f"v28 inbox doc missing snippet: {snippet}")

with (inbox_dir / "inbox_rows.csv").open(newline="", encoding="utf-8") as handle:
    inbox_rows = list(csv.DictReader(handle))
if len(inbox_rows) != 3:
    raise SystemExit("v28 expected three inbox rows")
if {row["v18_env"] for row in inbox_rows} != {"V18_THIRD_PARTY_RERUN_DIR", "V18_OFFICIAL_BENCHMARK_DIR", "V18_COMMERCIAL_POC_DIR"}:
    raise SystemExit("v28 inbox env set mismatch")
if any(row["return_detected"] != "0" or row["passed_to_v18"] != "0" for row in inbox_rows):
    raise SystemExit("v28 default inbox rows should be empty and not passed to v18")

manifest = json.loads((inbox_dir / "inbound_return_inbox_manifest.json").read_text(encoding="utf-8"))
if manifest.get("return_dirs_detected") != 0 or manifest.get("v18_env_dirs_passed") != 0:
    raise SystemExit("v28 manifest should not pass empty dirs")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v28 manifest overstated readiness: {field}")

with (inbox_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v28 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(inbox_dir / rel):
        raise SystemExit(f"v28 artifact hash mismatch: {rel}")
PY

echo "v28 inbound return inbox smoke passed"
