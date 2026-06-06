#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
INTAKE_DIR="$RESULTS_DIR/v18_external_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v18_external_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v18_external_evidence_intake_decision.csv"

"$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

intake_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v18 summary row, got {len(rows)}")
summary = rows[0]
expected_zero = [
    "third_party_rerun_supplied",
    "independent_rerun_actual_ready",
    "official_benchmark_supplied",
    "candidate_external_benchmark_result_ready",
    "commercial_poc_supplied",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]
for field in expected_zero:
    if summary.get(field) != "0":
        raise SystemExit(f"v18 default {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in [
    "third-party-rerun-intake",
    "independent-rerun-actual",
    "official-benchmark-intake",
    "candidate-external-benchmark-result",
    "commercial-poc-intake",
    "closed-corpus-poc-actual",
    "real-external-benchmark",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v18 default decision should be blocked: {gate}")

required = ["intake_manifest.json", "track_intake_rows.csv", "artifact_manifest.csv"]
for rel in required:
    path = intake_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v18 artifact: {rel}")

manifest = json.loads((intake_dir / "intake_manifest.json").read_text(encoding="utf-8"))
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v18 manifest overstated readiness: {field}")

with (intake_dir / "track_intake_rows.csv").open(newline="", encoding="utf-8") as handle:
    track_rows = list(csv.DictReader(handle))
if {row["track"] for row in track_rows} != {"third_party_rerun", "official_benchmark_reconciliation", "commercial_local_poc"}:
    raise SystemExit("v18 track set mismatch")
if any(row["supplied"] != "0" or row["ready"] != "0" for row in track_rows):
    raise SystemExit("v18 default track readiness should be zero")

with (intake_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in ["track_intake_rows.csv", "intake_manifest.json"]:
    if rel not in by_path:
        raise SystemExit(f"v18 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(intake_dir / rel):
        raise SystemExit(f"v18 artifact hash mismatch: {rel}")
PY

echo "v18 external evidence intake smoke passed"
