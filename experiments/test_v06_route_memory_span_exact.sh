#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$RESULTS_DIR"

FIXTURE="$TMP_DIR/v06_span_exact_fixture.txt"
CSV="$RESULTS_DIR/v06_route_memory_span_exact.csv"

cat >"$FIXTURE" <<'FIXTURE'
@37000=HELLO;
@37001=WORLD;
................................................................
?37000=HELLO.
?37001=WORLD.
FIXTURE

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

N_BYTES="$(wc -c <"$FIXTURE")"

"$BUILD_DIR/dmv02" \
  --input "$FIXTURE" \
  --N "$N_BYTES" \
  --epochs 6 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --lambda-b 0 \
  --eta-b 0 \
  --eta-h 0 \
  --proposal-count 30 \
  --route-mode hint-kv-exact \
  --route-span-hints 1 \
  --lambda-route 5.0 \
  --csv "$CSV" >/dev/null

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return row[idx[name]] + 0 }
  NR == 1 {
    required_count = split("kv_record_count kv_query_count kv_query_hit_rate route_hint_query_count route_hint_applied_rate route_hint_value_read_distance_mean fixture_query_byte_acc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing h6 span-exact column: " required[i], 2)
      }
    }
    next
  }
  { last = $0 }
  END {
    if (last == "") die("no h6 span-exact data row", 3)
    split(last, row, FS)
    if (metric("kv_record_count") != 2) {
      die("expected two multi-byte KV records", 4)
    }
    if (metric("kv_query_count") != 10 || metric("route_hint_query_count") != 10) {
      die("span hints should expose one query per value-span offset", 5)
    }
    if (metric("kv_query_hit_rate") < 0.999999 || metric("route_hint_applied_rate") < 0.999999) {
      die("expected exact span KV route hints to hit and apply", 6)
    }
    if (metric("route_hint_value_read_distance_mean") <= 0) {
      die("span value-bearing route read distance should be populated", 7)
    }
    if (metric("fixture_query_byte_acc") < 0.80) {
      die("expected span exact route hints to solve most routed bytes", 8)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("h6 span exact must not activate jump-neighbor routing", 9)
    }
  }
' "$CSV"

echo "v06 route-memory span exact smoke passed"
