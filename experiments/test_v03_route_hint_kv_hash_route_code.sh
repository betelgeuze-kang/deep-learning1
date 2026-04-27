#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_hash_route_code_fixture.txt"
CSV_PATH="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_smoke.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_PATH" <<'DATA'
@3000=A;
@3001=B;
@3002=C;
@3003=D;
................................................................
?3000=A.
?3001=B.
?3002=C.
?3003=D.
DATA

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/tmp/v03_kv_hash_route_code_cmake.log
cmake --build "$BUILD_DIR" --target dmv02 -j >/tmp/v03_kv_hash_route_code_build.log

"$BUILD_DIR/dmv02" \
  --input "$FIXTURE_PATH" \
  --N "$(wc -c < "$FIXTURE_PATH")" \
  --epochs 16 \
  --cycles-per-epoch 20 \
  --seed 1 \
  --lambda-v 0 \
  --lambda-b 0.1 \
  --eta-b 0.02 \
  --proposal-count 30 \
  --route-mode hint-kv-hash \
  --route-hash-source route-code-key \
  --route-code-aux 1 \
  --route-code-key-region-only 1 \
  --eta-route-code 0.25 \
  --lambda-route-code-id 1.0 \
  --K-route 1 \
  --route-hash-bits 16 \
  --route-hint-agg top1 \
  --lambda-route 5.0 \
  --csv "$CSV_PATH"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("fixture_query_byte_acc route_candidate_recall_rate route_candidate_top1_rate key_region_route_decode_acc route_key_unique_count route_signature_collision_rate route_vs_raw_candidate_overlap_rate", required, " ")
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        printf "missing column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  { rows[++row_count] = $0 }
  END {
    if (row_count == 0) {
      print "missing route-code rows" > "/dev/stderr"
      exit 3
    }
    start = row_count > 5 ? row_count - 4 : 1
    count = row_count - start + 1
    for (r = start; r <= row_count; r++) {
      split(rows[r], row, FS)
      qacc += row[idx["fixture_query_byte_acc"]] + 0
      recall += row[idx["route_candidate_recall_rate"]] + 0
      top1 += row[idx["route_candidate_top1_rate"]] + 0
      decode += row[idx["key_region_route_decode_acc"]] + 0
      unique += row[idx["route_key_unique_count"]] + 0
      collision += row[idx["route_signature_collision_rate"]] + 0
      overlap += row[idx["route_vs_raw_candidate_overlap_rate"]] + 0
    }
    qacc /= count
    recall /= count
    top1 /= count
    decode /= count
    unique /= count
    collision /= count
    overlap /= count
    if (decode < 0.99) {
      printf "expected route-code key decode near one, got %.6f\n", decode > "/dev/stderr"
      exit 4
    }
    if (unique < 3.99) {
      printf "expected route-code unique signatures to preserve four keys, got %.6f\n", unique > "/dev/stderr"
      exit 5
    }
    if (collision > 0.01) {
      printf "expected route-code signature collision near zero, got %.6f\n", collision > "/dev/stderr"
      exit 6
    }
    if (overlap < 0.99) {
      printf "expected route/raw candidate overlap near one, got %.6f\n", overlap > "/dev/stderr"
      exit 7
    }
    if (recall < 0.99 || top1 < 0.99 || qacc < 0.99) {
      printf "expected route-code retrieval to solve smoke, qacc=%.6f recall=%.6f top1=%.6f\n", qacc, recall, top1 > "/dev/stderr"
      exit 8
    }
  }
' "$CSV_PATH"

echo "route hint kv hash route-code smoke passed"
