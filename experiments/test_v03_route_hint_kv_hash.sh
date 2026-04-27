#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_hash_fixture.txt"
CSV_PATH="$RESULTS_DIR/v03_route_hint_kv_hash_smoke.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_PATH" <<'DATA'
@17=Q;................................................................?17=Q.
@18=R;................................................................?18=R.
@19=S;................................................................?19=S.
@20=T;................................................................?20=T.
DATA

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/tmp/v03_kv_hash_cmake.log
cmake --build "$BUILD_DIR" --target dmv02 -j >/tmp/v03_kv_hash_build.log

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
  --K-route 1 \
  --route-hash-bits 16 \
  --lambda-route 5.0 \
  --csv "$CSV_PATH"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_load_mean route_bucket_load_max route_bucket_collision_rate fixture_query_byte_acc", required, " ")
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
      print "expected hashed key candidate recall near one" > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_candidate_top1_rate"]] + 0 < 0.99) {
      print "expected hashed key top-1 candidate rate near one" > "/dev/stderr"
      exit 4
    }
    if (row[idx["route_candidate_rank_mean"]] + 0 < 0.99 ||
        row[idx["route_candidate_rank_mean"]] + 0 > 1.01) {
      printf "expected rank-one candidates, got %s\n", row[idx["route_candidate_rank_mean"]] > "/dev/stderr"
      exit 5
    }
    if (row[idx["route_bucket_load_mean"]] + 0 < 0.99) {
      print "expected non-empty candidate buckets" > "/dev/stderr"
      exit 6
    }
    if (row[idx["route_bucket_load_max"]] + 0 < 1.0) {
      print "expected bucket max load >= 1" > "/dev/stderr"
      exit 7
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 < 0.99) {
      print "expected hash hint to solve query positions" > "/dev/stderr"
      exit 8
    }
  }
' "$CSV_PATH"

echo "route hint kv hash smoke passed"
