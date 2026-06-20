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

for required in \
  "pipelines/v61.yaml" \
  "v61/one_token_path.json" \
  "operations/review_return_workflow.json" \
  "docs/PIPELINE_MIGRATION.md" \
  "docs/PR2_SPLIT_PLAN.md" \
  "tools/verify_artifact.py pr-split pr_slices/pr2.json"
do
  if ! grep -F "$required" "$ROOT_DIR/README.md" >/dev/null; then
    echo "README.md missing reviewer contract entrypoint: $required" >&2
    exit 1
  fi
done

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

echo "p0 README cleanup negative controls passed"
