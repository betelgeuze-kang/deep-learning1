#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKAGE_DIR="$RESULTS_DIR/v15a_independent_reproduction_package/package_001"
SUMMARY_CSV="$RESULTS_DIR/v15a_independent_reproduction_package_summary.csv"
DECISION_CSV="$RESULTS_DIR/v15a_independent_reproduction_package_decision.csv"

"$ROOT_DIR/experiments/run_v15a_independent_reproduction_package.sh" >/dev/null

python3 - "$PACKAGE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

package_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

if not package_dir.is_dir():
    raise SystemExit("missing v15-a package dir")

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    summary_rows = list(csv.DictReader(handle))
if {row["stage"] for row in summary_rows} != {"v14-b-lite", "v14-c", "v14-d", "v14-e"}:
    raise SystemExit("v15-a summary stage set mismatch")
for row in summary_rows:
    if row["stage_ready"] != "1":
        raise SystemExit(f"v15-a stage not ready: {row['stage']}")
    if row["candidate_external_benchmark_result_ready"] != "0" or row["real_external_benchmark_verified"] != "0" or row["real_release_package_ready"] != "0":
        raise SystemExit(f"v15-a stage promoted real/candidate/release unexpectedly: {row['stage']}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in [
    "v15-a-stage-summaries",
    "v15-a-one-command-reproducer",
    "v15-a-artifact-manifest",
    "v15-a-non-claim-docs",
    "v15-a-independent-reproduction-package",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v15-a decision did not pass: {gate}")
for gate in ["candidate-external-benchmark-result", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v15-a decision should remain blocked: {gate}")

manifest = json.loads((package_dir / "package_manifest.json").read_text(encoding="utf-8"))
if manifest.get("package_ready") != 1 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v15-a package manifest readiness mismatch")
if manifest.get("artifact_rows", 0) < 30:
    raise SystemExit("v15-a package manifest has too few artifacts")

required = [
    "REPRODUCE.sh",
    "artifact_manifest.csv",
    "environment_manifest.json",
    "docs/FAILURE_MODES.md",
    "docs/WHAT_THIS_DOES_NOT_CLAIM.md",
    "expected_summaries/v14-b-lite_summary.csv",
    "expected_summaries/v14-c_summary.csv",
    "expected_summaries/v14-d_summary.csv",
    "expected_summaries/v14-e_summary.csv",
    "expected_decisions/v14-b-lite_decision.csv",
    "expected_decisions/v14-c_decision.csv",
    "expected_decisions/v14-d_decision.csv",
    "expected_decisions/v14-e_decision.csv",
    "frozen_queries/v14-b-lite_lite_001_queries.jsonl",
    "frozen_queries/v14-c_comparison_001_queries.jsonl",
    "frozen_queries/v14-d_scale_100_queries.jsonl",
    "frozen_queries/v14-d_scale_150_queries.jsonl",
    "frozen_queries/v14-e_niah_lite_001_queries.jsonl",
    "frozen_queries/v14-e_niah_lite_001_ruler_niah_dataset.jsonl",
]
for rel in required:
    path = package_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v15-a package artifact: {rel}")

with (package_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required:
    if rel not in by_path:
        raise SystemExit(f"artifact manifest missing {rel}")
    if rel != "artifact_manifest.csv" and by_path[rel]["sha256"] != sha256(package_dir / rel):
        raise SystemExit(f"artifact manifest hash mismatch: {rel}")

reproduce = (package_dir / "REPRODUCE.sh").read_text(encoding="utf-8")
if "../../.." not in reproduce:
    raise SystemExit("reproducer does not resolve from package dir back to repo root")
for command in [
    "experiments/test_v14b_lite_prediction_lineage.sh",
    "experiments/test_v14c_baseline_comparison.sh",
    "experiments/test_v14d_routeqa_mini_scale.sh",
    "experiments/test_v14e_ruler_niah_lite.sh",
]:
    if command not in reproduce:
        raise SystemExit(f"reproducer missing command: {command}")

non_claims = (package_dir / "docs" / "WHAT_THIS_DOES_NOT_CLAIM.md").read_text(encoding="utf-8")
if "does not claim independent RULER" not in non_claims:
    raise SystemExit("v15-a non-claim notes missing benchmark disclaimer")
failure_modes = (package_dir / "docs" / "FAILURE_MODES.md").read_text(encoding="utf-8")
if "sha256 mismatch" not in failure_modes:
    raise SystemExit("v15-a failure modes missing hash mismatch note")
PY

echo "v15-a independent reproduction package smoke passed"
