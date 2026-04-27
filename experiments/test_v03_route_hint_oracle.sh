#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_fixture.txt"
OFF_CSV="$TMP_DIR/off.csv"
ON_CSV="$TMP_DIR/on.csv"

cat > "$FIXTURE_PATH" <<'FIXTURE'
@17=Q; filler filler filler filler filler ?17=Q
@23=Z; filler filler filler filler filler ?23=Z
FIXTURE

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

COMMON_ARGS=(
  --input "$FIXTURE_PATH"
  --N 128
  --epochs 6
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0
  --eta-b 0
  --eta-h 0
  --proposal-count 30
)

"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" --route-mode off --csv "$OFF_CSV"
"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" --route-mode hint-oracle --lambda-route 5.0 --csv "$ON_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    required[1] = "route_hint_applied_rate"
    required[2] = "route_hint_weight_mean"
    required[3] = "route_hint_query_count"
    required[4] = "route_hint_value_match_rate"
    required[5] = "fixture_query_acc"
    required[6] = "fixture_query_byte_acc"
    required[7] = "fixture_query_field_acc"
    required[8] = "fixture_query_joint_acc"
    for (i = 1; i <= 8; i++) {
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
    if (row[idx["route_hint_query_count"]] + 0 <= 0) {
      print "expected oracle query hints" > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_hint_applied_rate"]] + 0 < 0.99) {
      print "expected hint-oracle to apply hints" > "/dev/stderr"
      exit 4
    }
    if (row[idx["route_hint_weight_mean"]] + 0 < 0.99) {
      print "expected unit oracle hint weights" > "/dev/stderr"
      exit 5
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
      printf "hint-oracle query byte acc regressed: off=%f on=%f\n", off_acc, on_acc > "/dev/stderr"
      exit 6
    }
  }
' "$OFF_CSV" "$ON_CSV"

echo "route hint oracle smoke passed"
