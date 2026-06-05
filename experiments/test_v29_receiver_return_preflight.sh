#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFLIGHT_DIR="$RESULTS_DIR/v29_receiver_return_preflight/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v29_receiver_return_preflight_summary.csv"
DECISION_CSV="$RESULTS_DIR/v29_receiver_return_preflight_decision.csv"

"$ROOT_DIR/experiments/run_v29_receiver_return_preflight.sh" >/dev/null

python3 - "$PREFLIGHT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

preflight_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v29 summary row, got {len(rows)}")
summary = rows[0]
if summary.get("receiver_return_preflight_ready") != "1":
    raise SystemExit("v29 receiver preflight should be ready")
if summary.get("preflight_tracks") != "3":
    raise SystemExit("v29 should check three tracks")
if summary.get("return_dirs_detected") != "0":
    raise SystemExit("v29 default should not detect return dirs")
if summary.get("complete_return_dirs") != "0":
    raise SystemExit("v29 default should not complete return dirs")
if summary.get("missing_file_rows") != "24":
    raise SystemExit(f"v29 expected 24 missing file rows, got {summary.get('missing_file_rows')}")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v29 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("receiver-return-preflight") != "pass":
    raise SystemExit("v29 preflight gate should pass")
for gate in [
    "third-party-rerun-return-preflight",
    "official-benchmark-return-preflight",
    "commercial-poc-return-preflight",
    "v18-actual-readiness",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v29 default gate should remain blocked: {gate}")

required_files = [
    "receiver/RECEIVER_RETURN_PREFLIGHT.md",
    "receiver/preflight_rows.csv",
    "receiver/missing_file_rows.csv",
    "verify/VERIFY_AFTER_PREFLIGHT.md",
    "receiver_return_preflight_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = preflight_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v29 artifact: {rel}")

text = (preflight_dir / "receiver" / "RECEIVER_RETURN_PREFLIGHT.md").read_text(encoding="utf-8")
for snippet in [
    "V29_THIRD_PARTY_RETURN_DIR",
    "V29_OFFICIAL_RETURN_DIR",
    "V29_COMMERCIAL_RETURN_DIR",
    "V18_THIRD_PARTY_RERUN_DIR",
    "results/v28_inbound_return_inbox/inbox_001/returns/third_party_return/",
    "results/v28_inbound_return_inbox/inbox_001/returns/official_return/",
    "results/v28_inbound_return_inbox/inbox_001/returns/commercial_return/",
]:
    if snippet not in text:
        raise SystemExit(f"v29 preflight doc missing snippet: {snippet}")

with (preflight_dir / "receiver" / "preflight_rows.csv").open(newline="", encoding="utf-8") as handle:
    preflight_rows = list(csv.DictReader(handle))
if len(preflight_rows) != 3:
    raise SystemExit("v29 expected three preflight rows")
if {row["v18_env"] for row in preflight_rows} != {"V18_THIRD_PARTY_RERUN_DIR", "V18_OFFICIAL_BENCHMARK_DIR", "V18_COMMERCIAL_POC_DIR"}:
    raise SystemExit("v29 v18 env set mismatch")
if any(row["return_preflight_complete"] != "0" or row["return_detected"] != "0" for row in preflight_rows):
    raise SystemExit("v29 default preflight should not detect or complete returns")

with (preflight_dir / "receiver" / "missing_file_rows.csv").open(newline="", encoding="utf-8") as handle:
    missing_rows = list(csv.DictReader(handle))
if len(missing_rows) != 24:
    raise SystemExit(f"v29 expected 24 missing rows, got {len(missing_rows)}")

manifest = json.loads((preflight_dir / "receiver_return_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("complete_return_dirs") != 0 or manifest.get("missing_file_rows") != 24:
    raise SystemExit("v29 manifest row counts mismatch")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v29 manifest overstated readiness: {field}")

with (preflight_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v29 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(preflight_dir / rel):
        raise SystemExit(f"v29 artifact hash mismatch: {rel}")
PY

echo "v29 receiver return preflight smoke passed"
