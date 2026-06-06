#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
TRACKER_DIR="$RESULTS_DIR/v20_external_return_tracker/tracker_001"
SUMMARY_CSV="$RESULTS_DIR/v20_external_return_tracker_summary.csv"
DECISION_CSV="$RESULTS_DIR/v20_external_return_tracker_decision.csv"

"$ROOT_DIR/experiments/run_v20_external_return_tracker.sh" >/dev/null

python3 - "$TRACKER_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

tracker_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v20 summary row, got {len(rows)}")
summary = rows[0]
for field in ["tracker_ready", "submission_bundle_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v20 {field}: expected 1 got {summary.get(field)}")
if summary.get("external_return_dirs_supplied") != "0":
    raise SystemExit("v20 default should not have supplied external dirs")
if summary.get("return_requirement_rows") != "24":
    raise SystemExit(f"v20 expected 24 requirement rows, got {summary.get('return_requirement_rows')}")
if int(summary.get("blocker_rows", "0")) < 3:
    raise SystemExit("v20 default should report at least one blocker per track")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v20 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("external-return-tracker") != "pass":
    raise SystemExit("v20 tracker gate should pass")
for gate in [
    "third-party-rerun-return",
    "official-benchmark-return",
    "commercial-poc-return",
    "real-external-benchmark",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v20 default decision should be blocked: {gate}")

required_files = [
    "return_requirement_rows.csv",
    "blocker_rows.csv",
    "next_action_rows.csv",
    "RETURN_TRACKER.md",
    "return_tracker_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = tracker_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v20 artifact: {rel}")

text = (tracker_dir / "RETURN_TRACKER.md").read_text(encoding="utf-8")
for snippet in [
    "independent_rerun_actual_ready=1",
    "candidate_external_benchmark_result_ready=1",
    "closed_corpus_poc_actual_ready=1",
    "V20_THIRD_PARTY_RERUN_DIR",
    "official source snapshot",
    "local evidence-bound QA/audit system",
]:
    if snippet not in text:
        raise SystemExit(f"v20 tracker doc missing snippet: {snippet}")

manifest = json.loads((tracker_dir / "return_tracker_manifest.json").read_text(encoding="utf-8"))
if manifest.get("tracker_ready") != 1:
    raise SystemExit("v20 manifest tracker_ready should be 1")
if manifest.get("return_requirement_rows") != 24:
    raise SystemExit("v20 manifest should count 24 requirements")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v20 manifest overstated readiness: {field}")

with (tracker_dir / "return_requirement_rows.csv").open(newline="", encoding="utf-8") as handle:
    requirements = list(csv.DictReader(handle))
if {row["track"] for row in requirements} != {"third_party_rerun", "official_benchmark_reconciliation", "commercial_local_poc"}:
    raise SystemExit("v20 requirement track set mismatch")
if any(row["return_dir_supplied"] != "0" or row["file_present"] != "0" or row["status"] != "blocked" for row in requirements):
    raise SystemExit("v20 default requirements should be blocked without supplied dirs")

with (tracker_dir / "next_action_rows.csv").open(newline="", encoding="utf-8") as handle:
    actions = list(csv.DictReader(handle))
if len(actions) != 3:
    raise SystemExit("v20 expected three next action rows")
if not any("codebase QA" in row["recommended_next_action"] for row in actions):
    raise SystemExit("v20 should recommend codebase QA for commercial attachment")

with (tracker_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v20 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(tracker_dir / rel):
        raise SystemExit(f"v20 artifact hash mismatch: {rel}")
PY

echo "v20 external return tracker smoke passed"
