#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-v56-replay-negative.XXXXXX")"

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
  python3 - "$ROOT_DIR/v56/replay_contract.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "replay-ready":
    data["policy"]["replay_artifact_ready"] = True
elif mutation == "v56-ready":
    data["policy"]["v56_contract_ready"] = True
elif mutation == "external-verified":
    data["policy"]["real_external_benchmark_verified"] = True
elif mutation == "release-ready":
    data["policy"]["real_release_package_ready"] = True
elif mutation == "blocked-count":
    data["policy"]["blocked_replay_artifact_count"] = 0
elif mutation == "artifact-order":
    artifacts = data["replay_artifacts"]
    artifacts[0], artifacts[1] = artifacts[1], artifacts[0]
elif mutation == "validation-command-drop":
    data["replay_artifacts"][0]["validation_command"] = ""
elif mutation == "missing-seed-count":
    data["seed_dependency"]["missing_seed_artifact_count"] = 19
elif mutation == "implicit-rebuild":
    data["seed_dependency"]["implicit_seed_rebuild_allowed"] = True
elif mutation == "download-not-required":
    data["seed_dependency"]["network_or_download_approval_required"] = False
elif mutation == "seed-path-drop":
    data["seed_dependency"]["missing_seed_artifact_paths"] = data["seed_dependency"]["missing_seed_artifact_paths"][:-1]
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_path="$(bad_json replay_ready_bad replay-ready)"
expect_fail_with \
  "policy.replay_artifact_ready expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json v56_ready_bad v56-ready)"
expect_fail_with \
  "policy.v56_contract_ready expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json external_verified_bad external-verified)"
expect_fail_with \
  "policy.real_external_benchmark_verified expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json release_ready_bad release-ready)"
expect_fail_with \
  "policy.real_release_package_ready expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json blocked_count_bad blocked-count)"
expect_fail_with \
  "policy.blocked_replay_artifact_count expected 4, got 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json artifact_order_bad artifact-order)"
expect_fail_with \
  "replay_artifacts order must match v56 replay artifact blockers" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json validation_command_drop_bad validation-command-drop)"
expect_fail_with \
  "artifact_path_or_env, validation_command, and claim_boundary must be non-empty" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json missing_seed_count_bad missing-seed-count)"
expect_fail_with \
  "seed_dependency.missing_seed_artifact_count expected 20, got 19" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json implicit_rebuild_bad implicit-rebuild)"
expect_fail_with \
  "seed_dependency.implicit_seed_rebuild_allowed expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json download_not_required_bad download-not-required)"
expect_fail_with \
  "seed_dependency.network_or_download_approval_required expected True, got False" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

bad_path="$(bad_json seed_path_drop_bad seed-path-drop)"
expect_fail_with \
  "seed_dependency.missing_seed_artifact_paths must match the fail-closed v56 seed list" \
  "$ROOT_DIR/tools/verify_artifact.py" v56-replay "$bad_path"

echo "p0 v56 replay negative controls passed"
