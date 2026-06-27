#!/usr/bin/env bash
# Run the deterministic, hardware-free experiment test suite on a GitHub-hosted
# (or any clean) runner. This removes the self-hosted runner as the gate for
# everything except the GPU/HIP/ROCm tests.
#
# A test is EXCLUDED (left to the self-hosted/GPU lane) when the test file, or a
# run_*.sh it references, mentions GPU/accelerator or NVMe hardware.
#
# In --local-only mode we also exclude tests that are not clean-run standalone on
# ephemeral GitHub-hosted runners: staged external evidence intake/return,
# benchmark/review packets, baseline-war evidence slices, blind-eval intake,
# and known scale/stress/checkpoint-hotset tests that routinely exceed the
# lightweight CI shard budget or require prepared artifacts. Those tests remain
# runnable directly and in the self-hosted/evidence lanes.
#
# Usage:
#   scripts/run_offline_suite.sh --list              # print the selected tests
#   scripts/run_offline_suite.sh --limit 20          # run at most 20 (smoke)
#   scripts/run_offline_suite.sh --shard 1/8         # run shard 1 of 8
#   scripts/run_offline_suite.sh --local-only        # clean-run CI-safe subset
#   scripts/run_offline_suite.sh --timings           # print per-test elapsed seconds
#   scripts/run_offline_suite.sh --jobs 4            # run up to 4 tests in parallel
#   scripts/run_offline_suite.sh                     # run the whole offline suite
#
# The full suite is large; shard it across parallel GitHub-hosted runners with
# --shard INDEX/TOTAL (round-robin, 1-based INDEX).
#
# Env:
#   OFFLINE_SUITE_TIMEOUT                 per-test timeout seconds (default 300)
#   OFFLINE_SUITE_LOCAL_ONLY_EXCLUDE_RE   override the --local-only skip regex
#   OFFLINE_SUITE_LOG_DIR                 directory for failed-test logs
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PER_TEST_TIMEOUT="${OFFLINE_SUITE_TIMEOUT:-300}"
HARDWARE_RE='hip|rocm|cuda|gpu|nvme|/dev/kfd'
NETWORK_RE='git (fetch|clone)|curl |wget |https?://'
DEFAULT_LOCAL_ONLY_CI_EXCLUDE_RE='(^|/)test_.*(external|benchmark|ruler|longbench|github_actions|commercial|codebase_auditor|routehint_generation_1000|tiny_non_attention_generator_hint|7b14b|complete_source|canary_query|ah_answer|review_return|source_system_h|clean_machine|handoff|return_tracker|real_nlg_transcript|query_instantiation|hotset_tensor_slice|doc_code_conflict|scale|v52|v58|v61aa|v61ab|v61af|v61hv).*\.sh$|route_hint_kv_hash_route_code_fallback|route_source_credit_(retry_policy|fallback_policy|source_aware_scale)|route_memory_abstain_retry_guardrail|route_memory_promotion_gate'
LOCAL_ONLY_CI_EXCLUDE_RE="${OFFLINE_SUITE_LOCAL_ONLY_EXCLUDE_RE:-$DEFAULT_LOCAL_ONLY_CI_EXCLUDE_RE}"

mode="run"
limit=0
shard_index=1
shard_total=1
local_only=0
timings=0
jobs=1
while [ $# -gt 0 ]; do
  case "$1" in
    --list) mode="list"; shift ;;
    --limit) limit="${2:-0}"; shift 2 ;;
    --shard) IFS='/' read -r shard_index shard_total <<< "${2:-1/1}"; shift 2 ;;
    --local-only) local_only=1; shift ;;
    --timings) timings=1; shift ;;
    --jobs) jobs="${2:-1}"; shift 2 ;;
    *) shift ;;
  esac
done
: "${shard_index:=1}"
: "${shard_total:=1}"

is_hardware_test() {
  local test_file="$1"
  if grep -qiE "$HARDWARE_RE" "$test_file"; then
    return 0
  fi
  local ref
  for ref in $(grep -oE 'experiments/run_[A-Za-z0-9_]+\.sh' "$test_file" | sort -u); do
    if [ -f "$ref" ] && grep -qiE "$HARDWARE_RE" "$ref"; then
      return 0
    fi
  done
  return 1
}

is_network_test() {
  local test_file="$1"
  if grep -qiE "$NETWORK_RE" "$test_file"; then
    return 0
  fi
  local ref
  for ref in $(grep -oE 'experiments/run_[A-Za-z0-9_]+\.sh' "$test_file" | sort -u); do
    if [ -f "$ref" ] && grep -qiE "$NETWORK_RE" "$ref"; then
      return 0
    fi
  done
  return 1
}

is_local_only_ci_excluded_test() {
  local test_file="$1"
  if [[ "$test_file" =~ $LOCAL_ONLY_CI_EXCLUDE_RE ]]; then
    return 0
  fi
  return 1
}

selected=()
for test_file in $(ls experiments/test_*.sh 2>/dev/null | sort); do
  if is_hardware_test "$test_file"; then
    continue
  fi
  if [ "$local_only" -eq 1 ]; then
    if is_network_test "$test_file"; then
      continue
    fi
    if is_local_only_ci_excluded_test "$test_file"; then
      continue
    fi
  fi
  selected+=("$test_file")
done

if [ "$shard_total" -gt 1 ]; then
  sharded=()
  for i in "${!selected[@]}"; do
    if [ "$(( i % shard_total ))" -eq "$(( shard_index - 1 ))" ]; then
      sharded+=("${selected[$i]}")
    fi
  done
  selected=("${sharded[@]}")
fi

if [ "$limit" -gt 0 ] && [ "${#selected[@]}" -gt "$limit" ]; then
  selected=("${selected[@]:0:$limit}")
fi

if [ "$mode" = "list" ]; then
  printf '%s\n' "${selected[@]}"
  echo "offline-suite: ${#selected[@]} deterministic test(s) selected" >&2
  exit 0
fi

echo "==> offline-suite: running ${#selected[@]} deterministic test(s) (per-test timeout ${PER_TEST_TIMEOUT}s, jobs=$jobs)"

run_one() {
  local test_file="$1"
  local t_start t_end elapsed rc log_dir safe_name log_file
  t_start=$(date +%s)
  log_dir="${OFFLINE_SUITE_LOG_DIR:-${RUNNER_TEMP:-/tmp}/offline-suite-logs}"
  mkdir -p "$log_dir"
  safe_name="${test_file//\//__}"
  safe_name="${safe_name//[^A-Za-z0-9_.-]/_}"
  log_file="$log_dir/${safe_name}.log"
  timeout "$PER_TEST_TIMEOUT" bash "$test_file" >"$log_file" 2>&1; rc=$?
  t_end=$(date +%s)
  elapsed=$((t_end - t_start))
  if [ "$rc" -eq 0 ]; then
    if [ "$timings" -eq 1 ]; then
      echo "PASS ${elapsed}s $test_file"
    fi
    rm -f "$log_file"
    return 0
  else
    if [ "$rc" -eq 124 ]; then
      echo "FAIL ${elapsed}s $test_file (timeout after ${PER_TEST_TIMEOUT}s)"
    else
      echo "FAIL ${elapsed}s $test_file (exit $rc)"
    fi
    echo "---- output: $test_file ----"
    sed -n '1,200p' "$log_file" || true
    echo "---- end output: $test_file ----"
    return 1
  fi
}

pass=0
fail=0
failed_tests=()

if [ "$jobs" -le 1 ]; then
  for test_file in "${selected[@]}"; do
    if run_one "$test_file"; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
      failed_tests+=("$test_file")
    fi
  done
else
  # Parallel execution via xargs (GNU coreutils).
  export PER_TEST_TIMEOUT timings OFFLINE_SUITE_LOG_DIR
  export -f run_one
  results_file=$(mktemp)
  printf '%s\n' "${selected[@]}" | xargs -P "$jobs" -I {} bash -c '
    run_one "$@" && echo PASS >> '"$results_file"' || echo FAIL >> '"$results_file"'
  ' _ {}
  pass=$(grep -c PASS "$results_file" 2>/dev/null || echo 0)
  fail=$(grep -c FAIL "$results_file" 2>/dev/null || echo 0)
  rm -f "$results_file"
fi

echo "==> offline-suite: pass=$pass fail=$fail of ${#selected[@]}"
if [ "$fail" -gt 0 ]; then
  if [ ${#failed_tests[@]} -gt 0 ]; then
    printf 'failed: %s\n' "${failed_tests[@]}"
  fi
  exit 1
fi
echo "offline-suite ok"
