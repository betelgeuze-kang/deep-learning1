#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-v50-auditor-negative.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

expect_fail_with() {
  local expected="$1"
  shift
  local out="$TMP_DIR/expect_fail.out"
  if "$@" >"$out" 2>&1; then
    echo "negative control unexpectedly passed: $*" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$out" >/dev/null; then
    echo "negative control failed for the wrong reason: $*" >&2
    echo "expected diagnostic: $expected" >&2
    echo "actual output:" >&2
    cat "$out" >&2
    exit 1
  fi
}

bad_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/audits/v50_public_repo_auditor_correctness.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "artifact-replay-ready":
    data["policy"]["artifact_replay_ready"] = True
elif mutation == "merge-ready":
    data["policy"]["auditor_correctness_merge_ready"] = True
elif mutation == "implicit-refresh":
    data["policy"]["implicit_public_refresh_allowed"] = True
elif mutation == "network-not-required":
    data["policy"]["network_required_to_regenerate"] = False
elif mutation == "required-count":
    data["policy"]["required_artifact_count"] = 7
elif mutation == "present-count":
    data["policy"]["present_required_artifact_count"] = 1
elif mutation == "missing-ids":
    data["policy"]["missing_required_artifact_ids"] = data["policy"]["missing_required_artifact_ids"][:-1]
elif mutation == "artifact-order":
    artifacts = data["required_artifacts"]
    artifacts[0], artifacts[1] = artifacts[1], artifacts[0]
elif mutation == "artifact-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "source-snapshot-rows":
            row["required_columns"].remove("head_sha")
            break
elif mutation == "artifact-not-required":
    data["required_artifacts"][0]["required_for_merge"] = False
elif mutation == "verifier-command":
    data["replay_commands"]["artifact_verifier"] = "tools/verify_artifact.py wrong-command audits/v50_public_repo_auditor_correctness.json"
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_path="$(bad_json replay_ready_bad artifact-replay-ready)"
expect_fail_with \
  "artifact_replay_ready must remain false until required artifacts exist" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json merge_ready_bad merge-ready)"
expect_fail_with \
  "auditor_correctness_merge_ready must remain false" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json implicit_refresh_bad implicit-refresh)"
expect_fail_with \
  "implicit_public_refresh_allowed must be false" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json network_not_required_bad network-not-required)"
expect_fail_with \
  "network_required_to_regenerate must be true for the current v50 runner" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json required_count_bad required-count)"
expect_fail_with \
  "policy.required_artifact_count expected 8" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json present_count_bad present-count)"
expect_fail_with \
  "policy.present_required_artifact_count expected 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json missing_ids_bad missing-ids)"
expect_fail_with \
  "policy.missing_required_artifact_ids expected" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json artifact_order_bad artifact-order)"
expect_fail_with \
  "required_artifacts order must match the v50 correctness contract" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json artifact_column_drop_bad artifact-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v50 runner header" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json artifact_not_required_bad artifact-not-required)"
expect_fail_with \
  "required_for_merge must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

bad_path="$(bad_json verifier_command_bad verifier-command)"
expect_fail_with \
  "replay_commands.artifact_verifier must call v50-auditor-correctness" \
  "$ROOT_DIR/tools/verify_artifact.py" v50-auditor-correctness "$bad_path"

echo "p0 v50 auditor negative controls passed"
