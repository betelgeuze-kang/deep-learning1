#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_hash_joint_code_fixture.txt"
CSV_PATH="$RESULTS_DIR/v03_route_hint_kv_hash_joint_code_smoke.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_PATH" <<'DATA'
@3002=Q;
................................................................
?3002=Q.
DATA

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/tmp/v03_kv_hash_joint_code_cmake.log
cmake --build "$BUILD_DIR" --target dmv02 -j >/tmp/v03_kv_hash_joint_code_build.log

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
  --route-hash-source joint-code-key \
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
    split("fixture_query_byte_acc route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean key_region_count key_region_joint_decode_acc raw_key_unique_count joint_key_unique_count joint_signature_collision_rate joint_vs_raw_candidate_overlap_rate", required, " ")
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
    if (row[idx["route_candidate_query_count"]] + 0 < 0.99) {
      print "expected one joint-code route query" > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_candidate_recall_rate"]] + 0 < 0.99) {
      print "expected joint-code top-K recall near one" > "/dev/stderr"
      exit 4
    }
    if (row[idx["route_candidate_top1_rate"]] + 0 < 0.99) {
      print "expected joint-code top1 near one" > "/dev/stderr"
      exit 5
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 < 0.99) {
      print "expected joint-code route hint to solve the query" > "/dev/stderr"
      exit 6
    }
    if (row[idx["route_candidate_rank_mean"]] + 0 > 1.01) {
      print "expected joint-code correct candidate at rank 1" > "/dev/stderr"
      exit 7
    }
    if (row[idx["key_region_count"]] + 0 < 7.99 ||
        row[idx["key_region_count"]] + 0 > 8.01) {
      printf "expected eight key-region bytes, got %s\n", row[idx["key_region_count"]] > "/dev/stderr"
      exit 8
    }
    if (row[idx["key_region_joint_decode_acc"]] + 0 < 0.0 ||
        row[idx["key_region_joint_decode_acc"]] + 0 > 1.0) {
      printf "expected decode acc in [0,1], got %s\n", row[idx["key_region_joint_decode_acc"]] > "/dev/stderr"
      exit 9
    }
    if (row[idx["raw_key_unique_count"]] + 0 < 0.99 ||
        row[idx["raw_key_unique_count"]] + 0 > 1.01) {
      printf "expected one raw key, got %s\n", row[idx["raw_key_unique_count"]] > "/dev/stderr"
      exit 10
    }
    if (row[idx["joint_key_unique_count"]] + 0 < 0.99 ||
        row[idx["joint_key_unique_count"]] + 0 > 1.01) {
      printf "expected one joint signature, got %s\n", row[idx["joint_key_unique_count"]] > "/dev/stderr"
      exit 11
    }
    if (row[idx["joint_signature_collision_rate"]] + 0 != 0.0) {
      printf "expected no joint signature collision for one key, got %s\n", row[idx["joint_signature_collision_rate"]] > "/dev/stderr"
      exit 12
    }
    if (row[idx["joint_vs_raw_candidate_overlap_rate"]] + 0 < 0.99) {
      printf "expected joint/raw candidate overlap near one, got %s\n", row[idx["joint_vs_raw_candidate_overlap_rate"]] > "/dev/stderr"
      exit 13
    }
  }
' "$CSV_PATH"

echo "route hint kv hash joint-code smoke passed"
