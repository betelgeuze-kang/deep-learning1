#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" --target dmv02 -j

value_for_index() {
  local index="$1"
  local ascii=$((65 + (index % 26)))
  printf "\\$(printf '%03o' "$ascii")"
}

make_fixture() {
  local path="$1"
  local key_count="$2"

  : >"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 96; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fixture_query_byte_acc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_max route_quality_score_gap route_quality_selected_noisy_rate routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing preset metric column: %s\n", required[i] > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    { last = $0 }
    END {
      if (last == "") {
        printf "no data rows in %s\n", FILENAME > "/dev/stderr"
        exit 3
      }
      split(last, row, FS)
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_quality_apply_active"]] + 0,
        row[idx["route_quality_candidate_weight_beta"]] + 0,
        row[idx["route_quality_candidate_weight_factor_gap"]] + 0,
        row[idx["route_quality_candidate_weight_factor_max"]] + 0,
        row[idx["route_quality_score_gap"]] + 0,
        row[idx["route_quality_selected_noisy_rate"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local label="$1"
  local csv_path="$2"
  shift 2

  "$BUILD_DIR/dmv02" \
    --input "$FIXTURE" \
    --N "$N_BYTES" \
    --epochs 4 \
    --cycles-per-epoch 4 \
    --seed 1 \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count 12 \
    --route-mode hint-kv-hash \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --route-code-key-region-keep-prob 0.25 \
    --route-code-aux-noise-rate 0.75 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route 4 \
    --route-hash-bits 16 \
    --route-hint-agg weighted-vote \
    --route-candidate-score recency \
    --route-confidence-threshold 0.75 \
    --route-lowconf-policy aggregate \
    --route-lowconf-agg weighted-vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
    --route-delta-mode target-only \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-strength-confidence weight \
    --route-fallback-source noisy-route-code \
    --route-noisy-source-rate 0.25 \
    --route-source-retry-source off \
    --route-source-retry-policy source-credit \
    --route-source-retry-tiebreak source-order \
    --route-source-retry-priorities raw-key:0.0,key-shape:0.0,noisy-route-code:0.0 \
    --route-source-retry-prior-mode static \
    --route-source-retry-candidates raw-key,key-shape,noisy-route-code \
    --route-source-retry-per-source-limit 4 \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult 1.0 \
    --route-fallback-hi-strength-mult 5.0 \
    --route-fallback-lo-strength-mult 10.0 \
    --route-fallback-channel-strength-mode fixed \
    "$@" \
    --csv "$csv_path" >/dev/null

  printf '%s,%s\n' "$label" "$(metric_line "$csv_path")"
}

FIXTURE="$TMP_DIR/preset_fixture.txt"
make_fixture "$FIXTURE" 32
N_BYTES="$(wc -c <"$FIXTURE")"
SUMMARY="$RESULTS_DIR/v05_route_quality_candidate_preset_summary.csv"
printf 'label,qacc,apply_active,beta,factor_gap,factor_max,quality_score_gap,selected_noisy_rate,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY"

EXPLICIT_FLAGS=(
  --route-quality-diagnostics 1
  --route-quality-feature-set value-only
  --route-quality-apply candidate-weight
  --route-quality-candidate-weight-beta 8.0
  --route-quality-candidate-weight-min 0.5
  --route-quality-candidate-weight-max 8.0
  --route-quality-source-normalization none
  --route-quality-score 1
  --route-quality-logdet-weight 0.0
  --route-quality-entropy-weight 0.0
  --route-quality-vote-margin-weight 1.0
  --route-quality-top-share-weight 0.0
  --route-quality-source-credit-weight 0.0
  --route-quality-edge-credit-weight 0.0
  --route-quality-channel-weight 0.0
)

run_case explicit-base "$RESULTS_DIR/v05_route_quality_candidate_preset_explicit_base.csv" \
  "${EXPLICIT_FLAGS[@]}" \
  --route-quality-candidate-weight-basis base \
  --route-quality-candidate-weight-basis-mix 0.0 >>"$SUMMARY"

run_case preset-base "$RESULTS_DIR/v05_route_quality_candidate_preset_preset_base.csv" \
  --route-quality-candidate-weight-preset base-default >>"$SUMMARY"

run_case explicit-hybrid "$RESULTS_DIR/v05_route_quality_candidate_preset_explicit_hybrid.csv" \
  "${EXPLICIT_FLAGS[@]}" \
  --route-quality-candidate-weight-basis hybrid \
  --route-quality-candidate-weight-basis-mix 0.25 >>"$SUMMARY"

run_case preset-hybrid "$RESULTS_DIR/v05_route_quality_candidate_preset_preset_hybrid.csv" \
  --route-quality-candidate-weight-preset hybrid-safe >>"$SUMMARY"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function abs(x) { return x < 0 ? -x : x }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    label = $idx["label"]
    seen[label] = 1
    for (i = 2; i <= NF; i++) values[label, i] = $i + 0
    if ($idx["apply_active"] + 0 != 1.0 || $idx["beta"] + 0 != 8.0) {
      die("preset should activate candidate weight beta=8: " label, 4)
    }
    if ($idx["routing_trigger_rate"] + 0 != 0 ||
        $idx["active_jump_rate"] + 0 != 0) {
      die("preset must not activate jump-neighbor routing: " label, 5)
    }
  }
  END {
    required_count = split("explicit-base preset-base explicit-hybrid preset-hybrid", required, " ")
    for (r = 1; r <= required_count; r++) {
      if (!seen[required[r]]) {
        die("missing preset row: " required[r], 6)
      }
    }
    for (i = 2; i <= 10; i++) {
      if (abs(values["explicit-base", i] - values["preset-base", i]) > 0.000002) {
        die("base preset mismatch at field " i, 7)
      }
      if (abs(values["explicit-hybrid", i] - values["preset-hybrid", i]) > 0.000002) {
        die("hybrid preset mismatch at field " i, 8)
      }
    }
  }
' "$SUMMARY"

echo "route quality candidate preset smoke passed"
