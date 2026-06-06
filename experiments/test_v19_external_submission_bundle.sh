#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
BUNDLE_DIR="$RESULTS_DIR/v19_external_submission_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v19_external_submission_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v19_external_submission_bundle_decision.csv"

"$ROOT_DIR/experiments/run_v19_external_submission_bundle.sh" >/dev/null

python3 - "$BUNDLE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

bundle_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v19 summary row, got {len(rows)}")
summary = rows[0]
for field in [
    "submission_bundle_ready",
    "third_party_submission_ready",
    "official_benchmark_submission_ready",
    "commercial_poc_submission_ready",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v19 {field}: expected 1 got {summary.get(field)}")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v19 {field}: expected 0 got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in [
    "external-submission-bundle",
    "third-party-submission-ready",
    "official-benchmark-submission-ready",
    "commercial-poc-submission-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v19 decision should pass: {gate}")
for gate in [
    "independent-rerun-actual",
    "candidate-external-benchmark-result",
    "closed-corpus-poc-actual",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v19 decision should remain blocked: {gate}")

required_files = [
    "SUBMISSION_README.md",
    "source_manifests/v17_handoff_manifest.json",
    "source_manifests/v18_intake_manifest.json",
    "third_party_submission/EXTERNAL_REPRODUCE.sh",
    "third_party_submission/SUBMIT_THIRD_PARTY_RERUN.md",
    "third_party_submission/CLEAN_MACHINE_RUNBOOK.md",
    "third_party_submission/RETURN_MANIFEST_TEMPLATE.json",
    "third_party_submission/REQUIRED_RETURN_FILES.csv",
    "official_benchmark_submission/SUBMIT_OFFICIAL_BENCHMARK.md",
    "official_benchmark_submission/OFFICIAL_SLICE_REQUIREMENTS.csv",
    "official_benchmark_submission/CANDIDATE_RESULT_TEMPLATE.csv",
    "commercial_poc_submission/SUBMIT_COMMERCIAL_POC.md",
    "commercial_poc_submission/DOMAIN_INTAKE_TEMPLATE.csv",
    "commercial_poc_submission/POC_ACCEPTANCE_CRITERIA.csv",
    "roadmap/POST_V18_RESEARCH_ROADMAP.md",
    "verifier/V18_INTAKE_COMMANDS.md",
    "track_rows.csv",
    "submission_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = bundle_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v19 artifact: {rel}")

checks = {
    "SUBMISSION_README.md": [
        "V18_THIRD_PARTY_RERUN_DIR",
        "candidate_external_benchmark_result_ready=1",
    ],
    "third_party_submission/SUBMIT_THIRD_PARTY_RERUN.md": [
        "independent_rerun_actual_ready=1",
        "clean machine",
    ],
    "official_benchmark_submission/SUBMIT_OFFICIAL_BENCHMARK.md": [
        "official source snapshot",
        "Do not use oracle predictions",
    ],
    "commercial_poc_submission/SUBMIT_COMMERCIAL_POC.md": [
        "local evidence-bound QA/audit system",
        "not an LLM replacement",
    ],
    "roadmap/POST_V18_RESEARCH_ROADMAP.md": [
        "Recommended first attachment: codebase QA",
        "real_release_package_ready=0",
    ],
}
for rel, snippets in checks.items():
    text = (bundle_dir / rel).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            raise SystemExit(f"v19 artifact {rel} missing snippet: {snippet}")

manifest = json.loads((bundle_dir / "submission_manifest.json").read_text(encoding="utf-8"))
for field in [
    "submission_bundle_ready",
    "third_party_submission_ready",
    "official_benchmark_submission_ready",
    "commercial_poc_submission_ready",
]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v19 manifest should set {field}=1")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v19 manifest overstated readiness: {field}")

with (bundle_dir / "track_rows.csv").open(newline="", encoding="utf-8") as handle:
    tracks = list(csv.DictReader(handle))
if {row["track"] for row in tracks} != {"third_party_rerun", "official_benchmark_reconciliation", "commercial_local_poc"}:
    raise SystemExit("v19 track set mismatch")
if any(row["submission_ready"] != "1" or row["actual_ready_value"] != "0" for row in tracks):
    raise SystemExit("v19 tracks should be submission-ready but actual-blocked")

with (bundle_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v19 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(bundle_dir / rel):
        raise SystemExit(f"v19 artifact hash mismatch: {rel}")
PY

echo "v19 external submission bundle smoke passed"
