#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

SOURCE_MODE_ARG=()
PREFIX="v05_route_quality_candidate_level"
SOURCE_PREFIX="v05_route_quality_source_norm"
if [[ "$MODE" == "smoke" ]]; then
  SOURCE_MODE_ARG=(--smoke)
  PREFIX="v05_route_quality_candidate_level_smoke"
  SOURCE_PREFIX="v05_route_quality_source_norm_smoke"
elif [[ "$MODE" == "full" ]]; then
  SOURCE_MODE_ARG=(--full)
fi

"$ROOT_DIR/experiments/run_v05_route_quality_source_norm.sh" "${SOURCE_MODE_ARG[@]}"

SOURCE_SUMMARY="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"

awk -F, '
  BEGIN {
    OFS = ","
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scenario arm quality_apply quality_beta channel_weight normalization key_count seed noisy_source_rate qacc route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate route_quality_selected_raw_qacc lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing candidate-level source column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    print "scenario","arm","quality_apply","quality_beta","channel_weight","normalization","key_count","seed","noisy_source_rate","qacc","candidate_weight_correct","candidate_weight_wrong","candidate_weight_gap","candidate_best_correct_rate","selected_raw_rate","selected_keyshape_rate","selected_noisy_rate","selected_raw_qacc","lookup_count","read_distance","routing_trigger_rate","active_jump_rate"
    next
  }
  {
    print $idx["scenario"],
          $idx["arm"],
          $idx["quality_apply"],
          $idx["quality_beta"],
          $idx["channel_weight"],
          $idx["normalization"],
          $idx["key_count"],
          $idx["seed"],
          $idx["noisy_source_rate"],
          $idx["qacc"],
          $idx["route_quality_candidate_weight_correct_mean"],
          $idx["route_quality_candidate_weight_wrong_mean"],
          $idx["route_quality_candidate_weight_gap"],
          $idx["route_quality_candidate_best_correct_rate"],
          $idx["route_quality_selected_raw_rate"],
          $idx["route_quality_selected_keyshape_rate"],
          $idx["route_quality_selected_noisy_rate"],
          $idx["route_quality_selected_raw_qacc"],
          $idx["lookup_count"],
          $idx["read_distance"],
          $idx["routing_trigger_rate"],
          $idx["active_jump_rate"]
  }
' "$SOURCE_SUMMARY" >"$SUMMARY_CSV"

echo "wrote $SUMMARY_CSV"
