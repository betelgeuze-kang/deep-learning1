#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
DISPATCH_DIR="$RESULTS_DIR/v21_external_review_dispatch_kit/dispatch_001"
SUMMARY_CSV="$RESULTS_DIR/v21_external_review_dispatch_kit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v21_external_review_dispatch_kit_decision.csv"

"$ROOT_DIR/experiments/run_v21_external_review_dispatch_kit.sh" >/dev/null

python3 - "$DISPATCH_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

dispatch_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v21 summary row, got {len(rows)}")
summary = rows[0]
for field in ["dispatch_packet_ready", "reviewer_packet_index_ready", "return_layout_ready", "verify_return_commands_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v21 {field}: expected 1 got {summary.get(field)}")
if summary.get("return_requirement_rows") != "24":
    raise SystemExit(f"v21 expected 24 return requirements, got {summary.get('return_requirement_rows')}")
if summary.get("blocker_rows") != "3":
    raise SystemExit(f"v21 expected 3 blocker rows, got {summary.get('blocker_rows')}")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v21 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("external-review-dispatch-kit") != "pass":
    raise SystemExit("v21 dispatch kit gate should pass")
for gate in [
    "third-party-rerun-actual",
    "candidate-external-benchmark-result",
    "closed-corpus-poc-actual",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v21 actual gate should remain blocked: {gate}")

required_files = [
    "dispatch/README_FOR_EXTERNAL_REVIEWERS.md",
    "dispatch/REVIEWER_PACKET_INDEX.csv",
    "dispatch/THIRD_PARTY_RERUN_REQUEST.md",
    "dispatch/OFFICIAL_BENCHMARK_REQUEST.md",
    "dispatch/COMMERCIAL_POC_REQUEST.md",
    "dispatch/RETURN_DIRECTORY_LAYOUT.md",
    "dispatch/TRACKER_SUMMARY.md",
    "source_manifests/v19_submission_manifest.json",
    "source_manifests/v20_return_tracker_manifest.json",
    "return_templates/third_party_required_return_files.csv",
    "return_templates/official_benchmark_required_return_files.csv",
    "return_templates/commercial_poc_acceptance_criteria.csv",
    "verification/VERIFY_RETURN_COMMANDS.sh",
    "dispatch_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = dispatch_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v21 artifact: {rel}")

checks = {
    "dispatch/README_FOR_EXTERNAL_REVIEWERS.md": [
        "independent_rerun_actual_ready=1",
        "candidate_external_benchmark_result_ready=1",
        "closed_corpus_poc_actual_ready=1",
        "codebase QA",
    ],
    "dispatch/THIRD_PARTY_RERUN_REQUEST.md": [
        "clean-machine",
        "metric delta tolerance",
        "stdout/stderr",
    ],
    "dispatch/OFFICIAL_BENCHMARK_REQUEST.md": [
        "official source snapshot",
        "no oracle",
        "RouteMemory-derived prediction lineage",
    ],
    "dispatch/COMMERCIAL_POC_REQUEST.md": [
        "local evidence-bound QA/audit system",
        "not an LLM replacement",
        "wrong-answer guard",
    ],
    "verification/VERIFY_RETURN_COMMANDS.sh": [
        "V20_THIRD_PARTY_RERUN_DIR",
        "experiments/run_v20_external_return_tracker.sh",
    ],
}
for rel, snippets in checks.items():
    text = (dispatch_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v21 artifact {rel} missing snippet: {snippet}")

manifest = json.loads((dispatch_dir / "dispatch_manifest.json").read_text(encoding="utf-8"))
for field in ["dispatch_packet_ready", "reviewer_packet_index_ready", "return_layout_ready", "verify_return_commands_ready"]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v21 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v21 manifest overstated readiness: {field}")

with (dispatch_dir / "dispatch" / "REVIEWER_PACKET_INDEX.csv").open(newline="", encoding="utf-8") as handle:
    packets = list(csv.DictReader(handle))
if len(packets) != 3:
    raise SystemExit("v21 expected three reviewer packet rows")
if {row["target_flag"] for row in packets} != {"independent_rerun_actual_ready", "candidate_external_benchmark_result_ready", "closed_corpus_poc_actual_ready"}:
    raise SystemExit("v21 reviewer packet target flags mismatch")

with (dispatch_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v21 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(dispatch_dir / rel):
        raise SystemExit(f"v21 artifact hash mismatch: {rel}")
PY

echo "v21 external review dispatch kit smoke passed"
