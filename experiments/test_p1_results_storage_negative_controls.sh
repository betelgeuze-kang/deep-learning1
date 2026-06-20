#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p1-results-storage.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"

ALLOWLIST="ci/tracked_results_allowlist.txt"
TRACKED_LIST="$TMP_DIR/tracked.txt"
git ls-files 'results/**' | LC_ALL=C sort -u > "$TRACKED_LIST"

tools/check_tracked_results_policy.sh "$ALLOWLIST" "$TRACKED_LIST" >/dev/null

expect_fail() {
  local name="$1"
  local expected="$2"
  shift 2
  local stdout_file="$TMP_DIR/${name}.stdout"
  local stderr_file="$TMP_DIR/${name}.stderr"
  if "$@" >"$stdout_file" 2>"$stderr_file"; then
    echo "negative control unexpectedly passed: $name" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$stderr_file" >/dev/null; then
    echo "negative control failed with wrong diagnostic: $name" >&2
    cat "$stderr_file" >&2
    exit 1
  fi
}

EXTRA_TRACKED="$TMP_DIR/extra-tracked.txt"
cp "$TRACKED_LIST" "$EXTRA_TRACKED"
printf '%s\n' "results/generated_run/summary.csv" >> "$EXTRA_TRACKED"
expect_fail "extra-tracked" "tracked generated results are forbidden outside allowlist" \
  tools/check_tracked_results_policy.sh "$ALLOWLIST" "$EXTRA_TRACKED"

MISSING_ALLOW="$TMP_DIR/missing-allow.txt"
grep -vF "results/.gitkeep" "$ALLOWLIST" > "$MISSING_ALLOW"
expect_fail "missing-allow" "tracked generated results are forbidden outside allowlist" \
  tools/check_tracked_results_policy.sh "$MISSING_ALLOW" "$TRACKED_LIST"

STALE_ALLOW="$TMP_DIR/stale-allow.txt"
cp "$ALLOWLIST" "$STALE_ALLOW"
printf '%s\n' "results/stale_summary.csv" >> "$STALE_ALLOW"
expect_fail "stale-allow" "tracked results allowlist contains missing paths" \
  tools/check_tracked_results_policy.sh "$STALE_ALLOW" "$TRACKED_LIST"

PAYLOAD_TRACKED="$TMP_DIR/payload-tracked.txt"
PAYLOAD_ALLOW="$TMP_DIR/payload-allow.txt"
cp "$TRACKED_LIST" "$PAYLOAD_TRACKED"
cp "$ALLOWLIST" "$PAYLOAD_ALLOW"
printf '%s\n' "results/checkpoints/model.safetensors" >> "$PAYLOAD_TRACKED"
printf '%s\n' "results/checkpoints/model.safetensors" >> "$PAYLOAD_ALLOW"
expect_fail "payload-tracked" "tracked checkpoint/model payload path is forbidden under results/" \
  tools/check_tracked_results_policy.sh "$PAYLOAD_ALLOW" "$PAYLOAD_TRACKED"

TRAVERSAL_ALLOW="$TMP_DIR/traversal-allow.txt"
cp "$ALLOWLIST" "$TRAVERSAL_ALLOW"
printf '%s\n' "results/../escape.csv" >> "$TRAVERSAL_ALLOW"
expect_fail "traversal-allow" "tracked results allowlist path must not contain traversal segments" \
  tools/check_tracked_results_policy.sh "$TRAVERSAL_ALLOW" "$TRACKED_LIST"

echo "p1 results storage negative controls passed"
