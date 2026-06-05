#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
REVIEW_DIR="$RESULTS_DIR/v15b_nonfixture_review_independent_rerun/review_001"
SUMMARY_CSV="$RESULTS_DIR/v15b_nonfixture_review_independent_rerun_summary.csv"
DECISION_CSV="$RESULTS_DIR/v15b_nonfixture_review_independent_rerun_decision.csv"

"$ROOT_DIR/experiments/run_v15b_nonfixture_review_independent_rerun.sh" >/dev/null

python3 - "$REVIEW_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

review_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

if not review_dir.is_dir():
    raise SystemExit("missing v15-b review dir")

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v15-b summary row, got {len(rows)}")
summary = rows[0]
expected_values = {
    "review_rows": "8",
    "pass_review_rows": "8",
    "package_hash_bound": "1",
    "reviewer_identity_bound": "1",
    "rerun_environment_bound": "1",
    "rerun_exit_code": "0",
    "summary_match_rows": "4",
    "independent_rerun_mechanics_ready": "1",
    "nonfixture_review_package_ready": "1",
    "external_independent_reviewer": "0",
    "candidate_external_benchmark_result_ready": "0",
    "real_external_benchmark_verified": "0",
    "real_release_package_ready": "0",
}
for field, expected in expected_values.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v15-b {field}: expected {expected}, got {summary.get(field)}")
if int(summary.get("metric_delta_rows", "0")) <= 0:
    raise SystemExit("v15-b metric delta rows missing")
if summary.get("metric_delta_rows") != summary.get("metric_delta_pass_rows"):
    raise SystemExit("v15-b metric delta pass rows mismatch")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in [
    "v15-b-package-hash-bound",
    "v15-b-reviewer-identity",
    "v15-b-rerun-environment",
    "v15-b-rerun-command",
    "v15-b-metric-delta",
    "v15-b-nonfixture-review-independent-rerun",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v15-b decision did not pass: {gate}")
for gate in ["candidate-external-benchmark-result", "real-external-benchmark", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v15-b decision should remain blocked: {gate}")

required = [
    "reviewer_identity.json",
    "rerun_environment.json",
    "rerun_stdout.txt",
    "rerun_stderr.txt",
    "rerun_commands.csv",
    "package_hashes/package_hash_rows.csv",
    "metric_deltas/metric_delta_rows.csv",
    "review/review_rows.csv",
    "review_manifest.json",
    "artifact_manifest.csv",
    "rerun_summaries/v14-b-lite_expected_summary.csv",
    "rerun_summaries/v14-b-lite_rerun_summary.csv",
    "rerun_summaries/v14-c_expected_summary.csv",
    "rerun_summaries/v14-c_rerun_summary.csv",
    "rerun_summaries/v14-d_expected_summary.csv",
    "rerun_summaries/v14-d_rerun_summary.csv",
    "rerun_summaries/v14-e_expected_summary.csv",
    "rerun_summaries/v14-e_rerun_summary.csv",
]
for rel in required:
    path = review_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v15-b artifact: {rel}")

identity = json.loads((review_dir / "reviewer_identity.json").read_text(encoding="utf-8"))
if identity.get("external_independent_reviewer") != 0 or identity.get("independent_rerun_mechanics_declared") != 1:
    raise SystemExit("v15-b reviewer identity flags mismatch")
manifest = json.loads((review_dir / "review_manifest.json").read_text(encoding="utf-8"))
if manifest.get("review_ready") != 1 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v15-b review manifest readiness mismatch")
if manifest.get("external_independent_reviewer") != 0:
    raise SystemExit("v15-b review manifest overstated external reviewer independence")

with (review_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required:
    if rel in {"artifact_manifest.csv", "review_manifest.json"}:
        continue
    if rel not in by_path:
        raise SystemExit(f"v15-b artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(review_dir / rel):
        raise SystemExit(f"v15-b artifact hash mismatch: {rel}")

with (review_dir / "metric_deltas" / "metric_delta_rows.csv").open(newline="", encoding="utf-8") as handle:
    metric_rows = list(csv.DictReader(handle))
if not metric_rows:
    raise SystemExit("v15-b metric delta file empty")
if any(row["delta_within_tolerance"] != "1" for row in metric_rows):
    raise SystemExit("v15-b metric delta outside tolerance")

with (review_dir / "review" / "review_rows.csv").open(newline="", encoding="utf-8") as handle:
    review_rows = list(csv.DictReader(handle))
if len(review_rows) != 8 or any(row["status"] != "pass" for row in review_rows):
    raise SystemExit("v15-b review rows did not all pass")
PY

echo "v15-b nonfixture review / independent rerun smoke passed"
