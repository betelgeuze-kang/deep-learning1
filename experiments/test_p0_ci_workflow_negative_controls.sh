#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-ci-workflow-negative.XXXXXX")"

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

check_ai_verify_workflow() {
  local path="$1"
  grep -F "pull_request:" "$path" >/dev/null || {
    echo "ai-verify workflow must run on pull_request" >&2
    return 1
  }
  grep -F "push:" "$path" >/dev/null || {
    echo "ai-verify workflow must run on push" >&2
    return 1
  }
  if grep -A10 -F "push:" "$path" | grep -F "branches:" >/dev/null; then
    echo "ai-verify workflow push trigger must not be branch-limited" >&2
    return 1
  fi
  grep -F "workflow_dispatch:" "$path" >/dev/null || {
    echo "ai-verify workflow must support workflow_dispatch" >&2
    return 1
  }
  grep -F "runs-on: ubuntu-24.04" "$path" >/dev/null || {
    echo "ai-verify workflow must pin the runner to ubuntu-24.04" >&2
    return 1
  }
  grep -F "name: ai-verify.sh" "$path" >/dev/null || {
    echo "ai-verify workflow job name must be ai-verify.sh" >&2
    return 1
  }
  grep -F "run: ./scripts/ai-verify.sh" "$path" >/dev/null || {
    echo "ai-verify workflow must execute ./scripts/ai-verify.sh" >&2
    return 1
  }
  grep -F "DLE_VERIFY_ENABLE_HIP: \"OFF\"" "$path" >/dev/null || {
    echo "ai-verify workflow must keep HIP disabled by default" >&2
    return 1
  }
}

check_toolchain_lock() {
  local path="$1"
  python3 -m json.tool "$path" >/dev/null || return 1
  grep -F '"schema_version": "ai_verify_toolchain_lock.v1"' "$path" >/dev/null || {
    echo "ai-verify toolchain lock schema_version must be ai_verify_toolchain_lock.v1" >&2
    return 1
  }
  grep -F '"github_actions_runner": "ubuntu-24.04"' "$path" >/dev/null || {
    echo "ai-verify toolchain lock must pin github_actions_runner=ubuntu-24.04" >&2
    return 1
  }
  grep -F '"container_image_digest": ""' "$path" >/dev/null || {
    echo "ai-verify toolchain lock must keep container_image_digest explicit" >&2
    return 1
  }
  grep -F '"required_env": "DLE_VERIFY_ENABLE_HIP=OFF"' "$path" >/dev/null || {
    echo "ai-verify toolchain lock must keep ROCm/HIP disabled" >&2
    return 1
  }
  grep -F '"version_command": "python3 --version"' "$path" >/dev/null || {
    echo "ai-verify toolchain lock must record python3 version command" >&2
    return 1
  }
  grep -F '"version_command": "g++ --version"' "$path" >/dev/null || {
    echo "ai-verify toolchain lock must record compiler version command" >&2
    return 1
  }
  grep -F '"version_command": "cmake --version"' "$path" >/dev/null || {
    echo "ai-verify toolchain lock must record cmake version command" >&2
    return 1
  }
}

check_third_party_workflow() {
  local path="$1"
  grep -F "workflow_dispatch:" "$path" >/dev/null || {
    echo "third-party rerun workflow must be manually dispatchable" >&2
    return 1
  }
  grep -F "name: third-party-rerun-return-manual" "$path" >/dev/null || {
    echo "third-party rerun job name must remain manual" >&2
    return 1
  }
  if grep -F "pull_request:" "$path" >/dev/null; then
    echo "third-party rerun workflow must stay manual-only: pull_request forbidden" >&2
    return 1
  fi
  if grep -F "push:" "$path" >/dev/null; then
    echo "third-party rerun workflow must stay manual-only: push forbidden" >&2
    return 1
  fi
  if grep -F "schedule:" "$path" >/dev/null; then
    echo "third-party rerun workflow must stay manual-only: schedule forbidden" >&2
    return 1
  fi
  grep -F "V18_THIRD_PARTY_RERUN_DIR=" "$path" >/dev/null || {
    echo "third-party rerun workflow must feed v18 external evidence intake" >&2
    return 1
  }
  grep -F "actions/upload-artifact@v4" "$path" >/dev/null || {
    echo "third-party rerun workflow must upload a return artifact" >&2
    return 1
  }
}

check_ai_verify_workflow "$ROOT_DIR/.github/workflows/ai-verify.yml"
check_toolchain_lock "$ROOT_DIR/ci/ai_verify_toolchain.lock.json"
check_third_party_workflow "$ROOT_DIR/.github/workflows/third-party-rerun.yml"
grep -F "bash -n experiments/test_p0_v56_replay_negative_controls.sh" "$ROOT_DIR/scripts/ai-verify.sh" >/dev/null || {
  echo "ai-verify.sh must syntax-check v56 replay negative controls before execution" >&2
  exit 1
}

cp "$ROOT_DIR/.github/workflows/ai-verify.yml" "$TMP_DIR/ai_verify_no_wrapper.yml"
python3 - "$TMP_DIR/ai_verify_no_wrapper.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("run: ./scripts/ai-verify.sh", "run: ./scripts/ai-preflight.sh")
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "ai-verify workflow must execute ./scripts/ai-verify.sh" \
  check_ai_verify_workflow "$TMP_DIR/ai_verify_no_wrapper.yml"

cp "$ROOT_DIR/.github/workflows/ai-verify.yml" "$TMP_DIR/ai_verify_hip_bad.yml"
python3 - "$TMP_DIR/ai_verify_hip_bad.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace('DLE_VERIFY_ENABLE_HIP: "OFF"', 'DLE_VERIFY_ENABLE_HIP: "ON"')
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "ai-verify workflow must keep HIP disabled by default" \
  check_ai_verify_workflow "$TMP_DIR/ai_verify_hip_bad.yml"

cp "$ROOT_DIR/.github/workflows/ai-verify.yml" "$TMP_DIR/ai_verify_runner_bad.yml"
python3 - "$TMP_DIR/ai_verify_runner_bad.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("runs-on: ubuntu-24.04", "runs-on: ubuntu-latest")
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "ai-verify workflow must pin the runner to ubuntu-24.04" \
  check_ai_verify_workflow "$TMP_DIR/ai_verify_runner_bad.yml"

cp "$ROOT_DIR/.github/workflows/ai-verify.yml" "$TMP_DIR/ai_verify_push_branch_limited_bad.yml"
python3 - "$TMP_DIR/ai_verify_push_branch_limited_bad.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("  push:\n  workflow_dispatch:", "  push:\n    branches:\n      - main\n  workflow_dispatch:")
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "ai-verify workflow push trigger must not be branch-limited" \
  check_ai_verify_workflow "$TMP_DIR/ai_verify_push_branch_limited_bad.yml"

cp "$ROOT_DIR/ci/ai_verify_toolchain.lock.json" "$TMP_DIR/toolchain_runner_bad.json"
python3 - "$TMP_DIR/toolchain_runner_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["github_actions_runner"] = "ubuntu-latest"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "ai-verify toolchain lock must pin github_actions_runner=ubuntu-24.04" \
  check_toolchain_lock "$TMP_DIR/toolchain_runner_bad.json"

cp "$ROOT_DIR/ci/ai_verify_toolchain.lock.json" "$TMP_DIR/toolchain_schema_bad.json"
python3 - "$TMP_DIR/toolchain_schema_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["schema_version"] = "ai_verify_toolchain_lock.v0"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "ai-verify toolchain lock schema_version must be ai_verify_toolchain_lock.v1" \
  check_toolchain_lock "$TMP_DIR/toolchain_schema_bad.json"

cp "$ROOT_DIR/ci/ai_verify_toolchain.lock.json" "$TMP_DIR/toolchain_digest_bad.json"
python3 - "$TMP_DIR/toolchain_digest_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["container_image_digest"] = "sha256:" + "a" * 64
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "ai-verify toolchain lock must keep container_image_digest explicit" \
  check_toolchain_lock "$TMP_DIR/toolchain_digest_bad.json"

cp "$ROOT_DIR/ci/ai_verify_toolchain.lock.json" "$TMP_DIR/toolchain_rocm_bad.json"
python3 - "$TMP_DIR/toolchain_rocm_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["rocm"]["required_env"] = "DLE_VERIFY_ENABLE_HIP=ON"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "ai-verify toolchain lock must keep ROCm/HIP disabled" \
  check_toolchain_lock "$TMP_DIR/toolchain_rocm_bad.json"

cp "$ROOT_DIR/ci/ai_verify_toolchain.lock.json" "$TMP_DIR/toolchain_python_command_bad.json"
python3 - "$TMP_DIR/toolchain_python_command_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["python"]["version_command"] = "python --version"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "ai-verify toolchain lock must record python3 version command" \
  check_toolchain_lock "$TMP_DIR/toolchain_python_command_bad.json"

cp "$ROOT_DIR/.github/workflows/third-party-rerun.yml" "$TMP_DIR/third_party_pr_bad.yml"
python3 - "$TMP_DIR/third_party_pr_bad.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("on:\n  workflow_dispatch:", "on:\n  pull_request:\n  workflow_dispatch:")
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "third-party rerun workflow must stay manual-only: pull_request forbidden" \
  check_third_party_workflow "$TMP_DIR/third_party_pr_bad.yml"

cp "$ROOT_DIR/.github/workflows/third-party-rerun.yml" "$TMP_DIR/third_party_push_bad.yml"
python3 - "$TMP_DIR/third_party_push_bad.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("on:\n  workflow_dispatch:", "on:\n  push:\n  workflow_dispatch:")
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "third-party rerun workflow must stay manual-only: push forbidden" \
  check_third_party_workflow "$TMP_DIR/third_party_push_bad.yml"

cp "$ROOT_DIR/.github/workflows/third-party-rerun.yml" "$TMP_DIR/third_party_no_upload_bad.yml"
python3 - "$TMP_DIR/third_party_no_upload_bad.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("actions/upload-artifact@v4", "actions/checkout@v4")
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "third-party rerun workflow must upload a return artifact" \
  check_third_party_workflow "$TMP_DIR/third_party_no_upload_bad.yml"

echo "p0 CI workflow negative controls passed"
