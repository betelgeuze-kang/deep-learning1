#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_parsed_fixture.txt"
OFF_CSV="$TMP_DIR/off.csv"
ON_CSV="$TMP_DIR/on.csv"

cat > "$FIXTURE_PATH" <<'FIXTURE'
@17=Q; neutral neutral neutral neutral neutral neutral before ?17=Q.
@23=Z; neutral neutral neutral neutral neutral neutral before ?23=Z.
@31=M; neutral neutral neutral neutral neutral neutral before ?31=M.
FIXTURE

FIXTURE_N="$(wc -c < "$FIXTURE_PATH")"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

COMMON_ARGS=(
  --input "$FIXTURE_PATH"
  --N "$FIXTURE_N"
  --epochs 8
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0
  --eta-b 0
  --eta-h 0
  --proposal-count 30
)

"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" --route-mode off --csv "$OFF_CSV"
"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" --route-mode hint-parsed --lambda-route 5.0 --csv "$ON_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    required[1] = "route_hint_query_count"
    required[2] = "route_hint_applied_rate"
    required[3] = "route_hint_candidate_lookup_count"
    required[4] = "route_hint_candidate_hit_rate"
    required[5] = "route_hint_value_read_distance_mean"
    required[6] = "fixture_query_byte_acc"
    for (i = 1; i <= 6; i++) {
      if (!(required[i] in idx)) {
        printf "missing column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  { last = $0 }
  END {
    split(last, row, FS)
    query_count = row[idx["route_hint_query_count"]] + 0
    if (query_count < 3) {
      printf "expected three parsed query hints, got %f\n", query_count > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_hint_candidate_lookup_count"]] + 0 < query_count) {
      print "expected every parsed query to have a candidate lookup" > "/dev/stderr"
      exit 4
    }
    if (row[idx["route_hint_candidate_hit_rate"]] + 0 < 0.99) {
      print "expected parsed candidate hit rate near one" > "/dev/stderr"
      exit 5
    }
    if (row[idx["route_hint_value_read_distance_mean"]] + 0 <= 0) {
      print "expected positive nonlocal value read distance" > "/dev/stderr"
      exit 6
    }
    if (row[idx["route_hint_applied_rate"]] + 0 < 0.99) {
      print "expected hint-parsed to apply candidate-derived hints" > "/dev/stderr"
      exit 7
    }
  }
' "$ON_CSV"

awk -F, '
  FNR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[FILENAME,$i] = i
    }
    next
  }
  { last[FILENAME] = $0 }
  END {
    split(last[ARGV[1]], off, FS)
    split(last[ARGV[2]], on, FS)
    off_acc = off[idx[ARGV[1],"fixture_query_byte_acc"]] + 0
    on_acc = on[idx[ARGV[2],"fixture_query_byte_acc"]] + 0
    if (on_acc < off_acc) {
      printf "hint-parsed query byte acc regressed: off=%f on=%f\n", off_acc, on_acc > "/dev/stderr"
      exit 8
    }
  }
' "$OFF_CSV" "$ON_CSV"

echo "route hint parsed smoke passed"
