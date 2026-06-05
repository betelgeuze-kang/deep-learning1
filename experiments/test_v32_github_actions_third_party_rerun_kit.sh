#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
KIT_DIR="$RESULTS_DIR/v32_github_actions_third_party_rerun_kit/kit_001"
SUMMARY_CSV="$RESULTS_DIR/v32_github_actions_third_party_rerun_kit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v32_github_actions_third_party_rerun_kit_decision.csv"
WORKFLOW="$ROOT_DIR/.github/workflows/third-party-rerun.yml"

"$ROOT_DIR/experiments/run_v32_github_actions_third_party_rerun_kit.sh" >/dev/null

python3 - "$KIT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORKFLOW" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

kit_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
workflow = Path(sys.argv[4])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v32 summary row, got {len(rows)}")
summary = rows[0]
if summary.get("github_actions_third_party_rerun_kit_ready") != "1":
    raise SystemExit("v32 kit should be ready")
if summary.get("workflow_ready") != "1":
    raise SystemExit("v32 workflow should be ready")
if summary.get("actual_return_downloaded") != "0" or summary.get("independent_rerun_actual_ready") != "0":
    raise SystemExit("v32 local kit must not overclaim actual readiness")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
if decisions.get("github-actions-third-party-rerun-kit") != "pass":
    raise SystemExit("v32 kit gate should pass")
for gate in ["actual-github-actions-return", "independent-rerun-actual"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v32 should block {gate} until a workflow artifact is downloaded")

required_files = [
    "GITHUB_ACTIONS_THIRD_PARTY_RERUN.md",
    "workflow/third-party-rerun.yml",
    "github_actions_third_party_rerun_manifest.json",
    "artifact_manifest.csv",
]
for rel in required_files:
    path = kit_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v32 artifact: {rel}")

workflow_text = workflow.read_text(encoding="utf-8")
for snippet in [
    "pull_request:",
    "branches:",
    "main",
    "workflow_dispatch:",
    "runs-on: ubuntu-24.04",
    "RETURN_ID_INPUT",
    "CAPTURE_THIRD_PARTY_RERUN.sh",
    "external_independent_reviewer\": 1",
    "clean_machine\": 1",
    "V18_THIRD_PARTY_RERUN_DIR",
    "actions/upload-artifact@v4",
]:
    if snippet not in workflow_text:
        raise SystemExit(f"v32 workflow missing snippet: {snippet}")

runbook = (kit_dir / "GITHUB_ACTIONS_THIRD_PARTY_RERUN.md").read_text(encoding="utf-8")
for snippet in [
    "PR path:",
    "gh pr create --base main",
    "gh workflow run third-party-rerun.yml",
    "gh run download --name third-party-rerun-return",
    "V18_THIRD_PARTY_RERUN_DIR=",
    "independent_rerun_actual_ready=1",
    "Do not set these flags manually",
]:
    if snippet not in runbook:
        raise SystemExit(f"v32 runbook missing snippet: {snippet}")

manifest = json.loads((kit_dir / "github_actions_third_party_rerun_manifest.json").read_text(encoding="utf-8"))
if manifest.get("workflow_sha256") != sha256(workflow):
    raise SystemExit("v32 manifest workflow hash mismatch")
if manifest.get("independent_rerun_actual_ready") != 0:
    raise SystemExit("v32 manifest should not overclaim independent rerun actual")

with (kit_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required_files:
    if rel == "artifact_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v32 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(kit_dir / rel):
        raise SystemExit(f"v32 artifact hash mismatch: {rel}")
PY

echo "v32 GitHub Actions third-party rerun kit smoke passed"
