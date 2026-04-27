#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_hash_key_shape_fixture.txt"
BASELINE_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_key_shape_baseline.csv"
KEY_SHAPE_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_key_shape_smoke.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_PATH" <<'DATA'
@3002=Q;
@5=Z;
................................................................
?3002=Q.
DATA

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/tmp/v03_kv_hash_key_shape_cmake.log
cmake --build "$BUILD_DIR" --target dmv02 -j >/tmp/v03_kv_hash_key_shape_build.log

COMMON_ARGS=(
  --input "$FIXTURE_PATH"
  --N "$(wc -c < "$FIXTURE_PATH")"
  --epochs 8
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
  --proposal-count 30
  --route-mode hint-kv-hash
  --K-route 2
  --route-hash-bits 4
  --route-hint-agg top1
  --lambda-route 5.0
)

"$BUILD_DIR/dmv02" \
  "${COMMON_ARGS[@]}" \
  --route-candidate-score insertion \
  --csv "$BASELINE_CSV"

"$BUILD_DIR/dmv02" \
  "${COMMON_ARGS[@]}" \
  --route-candidate-score key-shape \
  --csv "$KEY_SHAPE_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("fixture_query_byte_acc route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean", required, " ")
    for (i = 1; i <= length(required); i++) {
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
    if (row[idx["route_candidate_recall_rate"]] + 0 < 0.99) {
      print "expected insertion baseline top-K recall near one" > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_candidate_top1_rate"]] + 0 > 0.01) {
      print "expected insertion baseline top1 to miss" > "/dev/stderr"
      exit 4
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 > 0.01) {
      print "expected insertion baseline query accuracy to fail" > "/dev/stderr"
      exit 5
    }
    if (row[idx["route_candidate_rank_mean"]] + 0 < 1.99) {
      print "expected insertion baseline correct candidate at rank 2" > "/dev/stderr"
      exit 6
    }
  }
' "$BASELINE_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    next
  }
  { last = $0 }
  END {
    split(last, row, FS)
    if (row[idx["route_candidate_recall_rate"]] + 0 < 0.99) {
      print "expected key-shape top-K recall near one" > "/dev/stderr"
      exit 7
    }
    if (row[idx["route_candidate_top1_rate"]] + 0 < 0.99) {
      print "expected key-shape scorer to promote the correct candidate to top1" > "/dev/stderr"
      exit 8
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 < 0.99) {
      print "expected key-shape scorer to solve the query" > "/dev/stderr"
      exit 9
    }
    if (row[idx["route_candidate_rank_mean"]] + 0 > 1.01) {
      print "expected key-shape correct candidate at rank 1" > "/dev/stderr"
      exit 10
    }
  }
' "$KEY_SHAPE_CSV"

echo "route hint kv hash key-shape smoke passed"
