#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-readme-cleanup-negative.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

check_readme_cleanup() {
  if rg -n "test_v61hv|test_v61ea|test_v61j_one_command|Current v61 prototype smoke|현재 v61 prototype smoke" "$@" >/dev/null; then
    echo "README must not reintroduce stale v61 prototype/stage-entrypoint wording" >&2
    return 1
  fi
  if rg -n "^(The )?v61[a-z]{1,3}\\b" "$@" >/dev/null; then
    echo "README must not reintroduce line-start v61 stage dumps" >&2
    return 1
  fi
}

check_required_contract_entrypoints() {
  for readme_path in "$@"; do
    for required in \
      "pipelines/v61.yaml" \
      "v61/one_token_path.json" \
      "operations/review_return_workflow.json" \
      "docs/PIPELINE_MIGRATION.md" \
      "docs/PR2_SPLIT_PLAN.md" \
      "tools/verify_artifact.py pr-split pr_slices/pr2.json"
    do
      if ! grep -F "$required" "$readme_path" >/dev/null; then
        echo "$readme_path missing reviewer contract entrypoint: $required" >&2
        return 1
      fi
    done
  done
}

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

check_readme_cleanup "$ROOT_DIR/README.md" "$ROOT_DIR/README.ko.md"
check_required_contract_entrypoints "$ROOT_DIR/README.md" "$ROOT_DIR/README.ko.md"

printf '%s\n' "Current v61 prototype smoke: ./experiments/test_v61j_one_command_ssd_resident_demo.sh" >"$TMP_DIR/stale_named_readme.md"
expect_fail_with \
  "README must not reintroduce stale v61 prototype/stage-entrypoint wording" \
  check_readme_cleanup "$TMP_DIR/stale_named_readme.md"

printf '%s\n' "v61hv post-HU first real slice readiness pipeline" >"$TMP_DIR/stage_dump_readme.md"
expect_fail_with \
  "README must not reintroduce line-start v61 stage dumps" \
  check_readme_cleanup "$TMP_DIR/stage_dump_readme.md"

printf '%s\n' "The v61ea route admission scaffold" >"$TMP_DIR/the_stage_dump_readme.md"
expect_fail_with \
  "README must not reintroduce line-start v61 stage dumps" \
  check_readme_cleanup "$TMP_DIR/the_stage_dump_readme.md"

cp "$ROOT_DIR/README.md" "$TMP_DIR/readme_missing_pr2_plan.md"
python3 - "$TMP_DIR/readme_missing_pr2_plan.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = [
    line for line in path.read_text(encoding="utf-8").splitlines()
    if "docs/PR2_SPLIT_PLAN.md" not in line
]
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "missing reviewer contract entrypoint: docs/PR2_SPLIT_PLAN.md" \
  check_required_contract_entrypoints "$TMP_DIR/readme_missing_pr2_plan.md"

cp "$ROOT_DIR/README.ko.md" "$TMP_DIR/readme_ko_missing_pr_split_command.md"
python3 - "$TMP_DIR/readme_ko_missing_pr_split_command.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8").replace(
    "tools/verify_artifact.py pr-split pr_slices/pr2.json",
    "tools/verify_artifact.py pr-split"
)
path.write_text(text, encoding="utf-8")
PY
expect_fail_with \
  "missing reviewer contract entrypoint: tools/verify_artifact.py pr-split pr_slices/pr2.json" \
  check_required_contract_entrypoints "$TMP_DIR/readme_ko_missing_pr_split_command.md"

echo "p0 README cleanup negative controls passed"
