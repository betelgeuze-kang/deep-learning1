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

PREFIX="v06_route_memory_abstain_retry_guardrail"
SOURCE_PREFIX="v06_route_memory_wrong_candidate_robustness"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_abstain_retry_guardrail_smoke"
  SOURCE_PREFIX="v06_route_memory_wrong_candidate_robustness_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
if [[ ! -s "$SOURCE_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_wrong_candidate_robustness.sh" "${RUN_ARGS[@]}" >/dev/null
fi

POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"

awk -F, -v policy_csv="$POLICY_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("chunk_ready source_safe fallback_not_keyshape_only combined_ready recommendation source_noisy_selected source_retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing abstain/retry source column: " required[i], 2)
    }
    print "guardrail,guardrail_action,default_promotion,diagnostic_only,weak_hint_or_abstain,chunk_ready,source_safe,fallback_not_keyshape_only,combined_ready,noisy_selection_clean,routing_trigger_rate,active_jump_rate" > policy_csv
    next
  }
  {
    rows++
    chunk_ready = $idx["chunk_ready"] + 0
    source_safe = $idx["source_safe"] + 0
    fallback_not_keyshape_only = $idx["fallback_not_keyshape_only"] + 0
    combined_ready = $idx["combined_ready"] + 0
    noisy_clean = (($idx["source_noisy_selected"] + 0) == 0.0 &&
      ($idx["source_retry_noisy_selected"] + 0) == 0.0) ? 1 : 0
    if (combined_ready && source_safe && chunk_ready && fallback_not_keyshape_only && noisy_clean) {
      action = "promotion-candidate"
      default_promotion = 1
      diagnostic_only = 0
      weak_hint_or_abstain = 0
    } else if (source_safe && noisy_clean && !chunk_ready) {
      action = "abstain-or-weak-hint"
      default_promotion = 0
      diagnostic_only = 1
      weak_hint_or_abstain = 1
    } else {
      action = "source-blocked"
      default_promotion = 0
      diagnostic_only = 1
      weak_hint_or_abstain = 0
    }
    printf "utility-w0p75-chunk-source,%s,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f\n",
      action,
      default_promotion,
      diagnostic_only,
      weak_hint_or_abstain,
      chunk_ready,
      source_safe,
      fallback_not_keyshape_only,
      combined_ready,
      noisy_clean,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0 >> policy_csv
  }
  END {
    if (rows != 1) die("expected one abstain/retry source row", 3)
  }
' "$SOURCE_SUMMARY_CSV"

echo "policy: $POLICY_CSV"
