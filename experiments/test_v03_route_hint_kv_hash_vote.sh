#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_hash_vote_fixture.txt"
TOP1_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_vote_top1_smoke.csv"
VOTE_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_vote_vote_smoke.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_PATH" <<'DATA'
@3002=Q;
@3015=Q;
@3046=Q;
@3059=Z;
................................................................
?3002=Q.
DATA

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/tmp/v03_kv_hash_vote_cmake.log
cmake --build "$BUILD_DIR" --target dmv02 -j >/tmp/v03_kv_hash_vote_build.log

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
  --K-route 4
  --route-hash-bits 4
  --lambda-route 5.0
)

"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" \
  --route-hint-agg top1 \
  --csv "$TOP1_CSV"

"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" \
  --route-hint-agg vote \
  --csv "$VOTE_CSV"

awk -F, '
  function read_last(path, out,    line, n, h, i, idx, row) {
    while ((getline line < path) > 0) {
      if (++n == 1) {
        split(line, h, FS)
        for (i = 1; i <= length(h); i++) {
          idx[h[i]] = i
        }
      } else {
        out["last"] = line
      }
    }
    close(path)
    split(out["last"], row, FS)
    out["query_acc"] = row[idx["fixture_query_byte_acc"]] + 0
    out["recall"] = row[idx["route_candidate_recall_rate"]] + 0
    out["top1"] = row[idx["route_candidate_top1_rate"]] + 0
    out["vote_count"] = row[idx["route_hint_vote_candidate_count_mean"]] + 0
    out["vote_margin"] = row[idx["route_hint_vote_margin_mean"]] + 0
    out["has_vote_count"] = ("route_hint_vote_candidate_count_mean" in idx)
    out["has_vote_margin"] = ("route_hint_vote_margin_mean" in idx)
  }
  BEGIN {
    read_last(ARGV[1], top1)
    read_last(ARGV[2], vote)
    ARGV[1] = ""
    ARGV[2] = ""

    if (!vote["has_vote_count"] || !vote["has_vote_margin"]) {
      print "missing vote aggregation metric columns" > "/dev/stderr"
      exit 2
    }
    if (vote["recall"] < 0.99) {
      print "expected top-K recall near one" > "/dev/stderr"
      exit 3
    }
    if (vote["top1"] > 0.01) {
      print "expected top1 to miss this fixture" > "/dev/stderr"
      exit 4
    }
    if (top1["query_acc"] > 0.01) {
      print "expected top1 aggregation to fail the query" > "/dev/stderr"
      exit 5
    }
    if (vote["query_acc"] < 0.99) {
      print "expected vote aggregation to solve the query" > "/dev/stderr"
      exit 6
    }
    if (vote["vote_count"] < 3.99 || vote["vote_count"] > 4.01) {
      printf "expected four vote candidates, got %f\n", vote["vote_count"] > "/dev/stderr"
      exit 7
    }
    if (vote["vote_margin"] <= 0.0) {
      printf "expected positive vote margin, got %f\n", vote["vote_margin"] > "/dev/stderr"
      exit 8
    }
  }
' "$TOP1_CSV" "$VOTE_CSV"

echo "route hint kv hash vote smoke passed"
