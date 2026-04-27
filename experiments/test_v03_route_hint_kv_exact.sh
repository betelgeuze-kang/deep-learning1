#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_PATH="$TMP_DIR/route_hint_kv_fixture.txt"
OFF_CSV="$TMP_DIR/off.csv"
ON_CSV="$TMP_DIR/on.csv"

cat > "$FIXTURE_PATH" <<'FIXTURE'
@17=Q; neutral neutral neutral neutral neutral neutral before ?17=Q.
@23=Z; neutral neutral neutral neutral neutral neutral before ?23=Z.
@23=Y; later duplicate should win for exact lookup before ?23=Y.
?99=X missing key remains a query but should not hit.
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
"$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" --route-mode hint-kv-exact --lambda-route 5.0 --csv "$ON_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    required[1] = "kv_record_count"
    required[2] = "kv_query_count"
    required[3] = "kv_query_hit_rate"
    required[4] = "kv_duplicate_key_rate"
    required[5] = "kv_missing_key_rate"
    required[6] = "route_hint_candidate_lookup_count"
    required[7] = "route_hint_value_read_distance_mean"
    required[8] = "fixture_query_byte_acc"
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
    if (row[idx["kv_record_count"]] + 0 != 3) {
      printf "expected three records, got %s\n", row[idx["kv_record_count"]] > "/dev/stderr"
      exit 3
    }
    if (row[idx["kv_query_count"]] + 0 != 4) {
      printf "expected four queries, got %s\n", row[idx["kv_query_count"]] > "/dev/stderr"
      exit 4
    }
    if (row[idx["kv_query_hit_rate"]] + 0 < 0.74 || row[idx["kv_query_hit_rate"]] + 0 > 0.76) {
      printf "expected hit rate 0.75, got %s\n", row[idx["kv_query_hit_rate"]] > "/dev/stderr"
      exit 5
    }
    if (row[idx["kv_duplicate_key_rate"]] + 0 < 0.32 || row[idx["kv_duplicate_key_rate"]] + 0 > 0.34) {
      printf "expected duplicate key rate about 1/3, got %s\n", row[idx["kv_duplicate_key_rate"]] > "/dev/stderr"
      exit 6
    }
    if (row[idx["kv_missing_key_rate"]] + 0 < 0.24 || row[idx["kv_missing_key_rate"]] + 0 > 0.26) {
      printf "expected missing key rate 0.25, got %s\n", row[idx["kv_missing_key_rate"]] > "/dev/stderr"
      exit 7
    }
    if (row[idx["route_hint_candidate_lookup_count"]] + 0 != 3) {
      printf "expected three candidate lookups, got %s\n", row[idx["route_hint_candidate_lookup_count"]] > "/dev/stderr"
      exit 8
    }
    if (row[idx["route_hint_value_read_distance_mean"]] + 0 <= 0) {
      print "expected positive nonlocal value read distance" > "/dev/stderr"
      exit 9
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
      printf "hint-kv-exact query byte acc regressed: off=%f on=%f\n", off_acc, on_acc > "/dev/stderr"
      exit 10
    }
  }
' "$OFF_CSV" "$ON_CSV"

echo "route hint kv exact smoke passed"
