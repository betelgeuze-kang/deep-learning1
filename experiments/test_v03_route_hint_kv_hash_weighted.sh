#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_hash_weighted_fixture.txt"
WEIGHTED_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_weighted_smoke.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_PATH" <<'DATA'
@3002=Q;
@3015=Q;
@3046=Q;
@3059=Z;
................................................................
?3002=Q.
DATA

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/tmp/v03_kv_hash_weighted_cmake.log
cmake --build "$BUILD_DIR" --target dmv02 -j >/tmp/v03_kv_hash_weighted_build.log

"$BUILD_DIR/dmv02" \
  --input "$FIXTURE_PATH" \
  --N "$(wc -c < "$FIXTURE_PATH")" \
  --epochs 8 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --lambda-b 0.1 \
  --eta-b 0.02 \
  --proposal-count 30 \
  --route-mode hint-kv-hash \
  --K-route 4 \
  --route-hash-bits 4 \
  --route-hint-agg weighted-vote \
  --route-candidate-score value-vote \
  --lambda-route 5.0 \
  --csv "$WEIGHTED_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("route_hint_correct_value_vote_share_mean route_hint_vote_entropy_mean route_hint_unique_values_mean fixture_query_byte_acc route_candidate_recall_rate route_candidate_top1_rate", required, " ")
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
      print "expected weighted smoke top-K recall near one" > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_candidate_top1_rate"]] + 0 > 0.01) {
      print "expected weighted smoke top1 to miss" > "/dev/stderr"
      exit 4
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 < 0.99) {
      print "expected weighted-vote to solve the query" > "/dev/stderr"
      exit 5
    }
    if (row[idx["route_hint_correct_value_vote_share_mean"]] + 0 < 0.85) {
      printf "expected correct value vote share >= 0.85, got %s\n", row[idx["route_hint_correct_value_vote_share_mean"]] > "/dev/stderr"
      exit 6
    }
    if (row[idx["route_hint_unique_values_mean"]] + 0 < 1.99 ||
        row[idx["route_hint_unique_values_mean"]] + 0 > 2.01) {
      printf "expected two unique values, got %s\n", row[idx["route_hint_unique_values_mean"]] > "/dev/stderr"
      exit 7
    }
    if (row[idx["route_hint_vote_entropy_mean"]] + 0 <= 0.0) {
      printf "expected positive entropy, got %s\n", row[idx["route_hint_vote_entropy_mean"]] > "/dev/stderr"
      exit 8
    }
  }
' "$WEIGHTED_CSV"

echo "route hint kv hash weighted smoke passed"
