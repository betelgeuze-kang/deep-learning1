#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v32_github_actions_third_party_rerun_kit"
KIT_ID="${V32_KIT_ID:-kit_001}"
KIT_DIR="${V32_KIT_DIR:-$RESULTS_DIR/${PREFIX}/$KIT_ID}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORKFLOW="$ROOT_DIR/.github/workflows/third-party-rerun.yml"

mkdir -p "$KIT_DIR"

python3 - "$ROOT_DIR" "$KIT_DIR" "$WORKFLOW" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
kit_dir = Path(sys.argv[2])
workflow = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
kit_dir.mkdir(parents=True, exist_ok=True)
(kit_dir / "workflow").mkdir(parents=True, exist_ok=True)
(kit_dir / "receiver").mkdir(parents=True, exist_ok=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

remote = subprocess.run(["git", "remote", "get-url", "origin"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.strip()
gh_auth = subprocess.run(["gh", "auth", "status"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
workflow_copy = kit_dir / "workflow" / "third-party-rerun.yml"
shutil.copy2(workflow, workflow_copy)

runbook = kit_dir / "GITHUB_ACTIONS_THIRD_PARTY_RERUN.md"
runbook.write_text(
    "\n".join(
        [
            "# v32 GitHub Actions Third-party Rerun Kit",
            "",
            "Purpose: produce a third-party rerun return directory on a GitHub-hosted clean runner, then verify it through v18.",
            "",
            "Prerequisite:",
            "",
            "- Commit and push the current v14-v32 scripts and `.github/workflows/third-party-rerun.yml` to the GitHub remote.",
            "- GitHub Actions must be enabled for the repository.",
            "- The workflow uses `actions/checkout@v4` and `actions/upload-artifact@v4`.",
            "",
            "Run:",
            "",
            "```bash",
            "gh workflow run third-party-rerun.yml -f return_id=github_actions_return_001",
            "gh run list --workflow third-party-rerun.yml --limit 1",
            "gh run watch",
            "```",
            "",
            "Download the return artifact:",
            "",
            "```bash",
            "mkdir -p results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded",
            "gh run download --name third-party-rerun-return --dir results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded",
            "```",
            "",
            "Verify after download:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded/results/github_actions_third_party_rerun/github_actions_return_001/third_party_return \\",
            "V18_OFFICIAL_BENCHMARK_DIR=results/v31_official_ruler_niah_candidate_return/return_001/official_return \\",
            "V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \\",
            "experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Expected target if the workflow artifact is from GitHub-hosted Actions:",
            "",
            "- `independent_rerun_actual_ready=1`",
            "- `candidate_external_benchmark_result_ready=1`",
            "- `closed_corpus_poc_actual_ready=1`",
            "- `real_external_benchmark_verified=1`",
            "",
            "Do not set these flags manually. v18 must derive them from the returned files.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v32-github-actions-third-party-rerun-kit",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "remote": remote,
    "gh_auth_available": int(gh_auth.returncode == 0),
    "workflow_path": ".github/workflows/third-party-rerun.yml",
    "workflow_sha256": sha256(workflow),
    "github_actions_third_party_rerun_kit_ready": 1,
    "actual_return_downloaded": 0,
    "independent_rerun_actual_ready": 0,
    "claim": "workflow/runbook ready; actual third-party readiness requires a downloaded GitHub Actions return artifact verified by v18",
}
(kit_dir / "github_actions_third_party_rerun_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rows = []
for path in [runbook, workflow_copy, kit_dir / "github_actions_third_party_rerun_manifest.json"]:
    artifact_rows.append({"artifact": path.stem, "path": str(path.relative_to(kit_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(kit_dir / "artifact_manifest.csv", ["artifact", "path", "sha256", "bytes"], artifact_rows)

summary_rows = [
    {
        "kit_id": kit_dir.name,
        "github_actions_third_party_rerun_kit_ready": 1,
        "workflow_ready": int(workflow.is_file()),
        "gh_auth_available": int(gh_auth.returncode == 0),
        "actual_return_downloaded": 0,
        "independent_rerun_actual_ready": 0,
        "artifact_rows": len(artifact_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

decision_rows = [
    ("github-actions-third-party-rerun-kit", "pass", "workflow and runbook are generated"),
    ("github-actions-auth", "pass" if gh_auth.returncode == 0 else "blocked", "gh auth status checked"),
    ("actual-github-actions-return", "blocked", "run workflow and download artifact before v18 actual verification"),
    ("independent-rerun-actual", "blocked", "requires downloaded GitHub-hosted return artifact verified by v18"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v32_github_actions_third_party_rerun_kit_dir: $KIT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
