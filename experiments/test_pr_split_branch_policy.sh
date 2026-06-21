#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

GOOD="$TMPDIR/pr2-good.json"
cp pr_slices/pr2.json "$GOOD"
tools/verify_artifact.py pr-split "$GOOD" >/dev/null

make_case() {
  local mode="$1"
  local dest="$2"
  MODE="$mode" DEST="$dest" python3 - <<'PY'
import json
import os
from pathlib import Path

data = json.loads(Path("pr_slices/pr2.json").read_text(encoding="utf-8"))
policy = data["branch_integration_policy"]
mode = os.environ["MODE"]

if mode == "not-main":
    policy["source_of_truth_ref"] = "codex/route-memory-local-energy-policy"
elif mode == "giant-ahead-limit":
    policy["max_ahead_commits_per_pr"] = 449
elif mode == "missing-product-group":
    policy["required_pr_groups"] = ["v52", "v53", "v54", "v58", "v61"]
elif mode == "readiness-without-artifact":
    policy["readiness_increase_requires_artifact"] = False
elif mode == "unblocked-large-risk":
    policy["current_development_branch_risk"]["status"] = "ready-for-merge"
else:
    raise SystemExit(f"unknown mode: {mode}")

Path(os.environ["DEST"]).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

expect_fail() {
  local mode="$1"
  local pattern="$2"
  local case_path="$TMPDIR/$mode.json"
  local out="$TMPDIR/$mode.out"
  make_case "$mode" "$case_path"
  if tools/verify_artifact.py pr-split "$case_path" >"$out" 2>&1; then
    echo "expected pr-split branch policy failure for $mode" >&2
    exit 1
  fi
  grep -F "$pattern" "$out" >/dev/null
}

expect_fail "not-main" "source_of_truth_ref must be main"
expect_fail "giant-ahead-limit" "max_ahead_commits_per_pr must be an integer between 1 and 80"
expect_fail "missing-product-group" "required_pr_groups must be exactly product, v52, v53, v54, v58, v61"
expect_fail "readiness-without-artifact" "readiness_increase_requires_artifact must be true"
expect_fail "unblocked-large-risk" "current_development_branch_risk.status must be blocked-large-branch"

echo "pr-split branch policy negative controls passed"
