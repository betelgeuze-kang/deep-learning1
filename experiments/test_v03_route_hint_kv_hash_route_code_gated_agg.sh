#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_gated_agg_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_gated_agg.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_hint_agg route_aggregation_confidence route_confidence_threshold fixture_query_byte_acc damage_vs_clean route_candidate_corrupt_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_wrong_strength_mean route_highconf_wrong_strength_mean route_agg_policy_vote_rate route_agg_policy_weighted_rate route_wrong_hint_strength_mean", required, " ")
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        printf "missing column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    row_count++
    scenario = $idx["scenario"]
    if (scenario == "corrupt-unscaled") {
      unscaled_seen = 1
      unscaled_qacc = $idx["fixture_query_byte_acc"] + 0
      unscaled_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      unscaled_corrupt = $idx["route_candidate_corrupt_rate"] + 0
    } else if (scenario == "corrupt-valueconf") {
      valueconf_seen = 1
    } else if (scenario == "corrupt-agreement") {
      agreement_seen = 1
      agreement_qacc = $idx["fixture_query_byte_acc"] + 0
    } else if (scenario == "corrupt-gated-agg") {
      gated_seen = 1
      gated_qacc = $idx["fixture_query_byte_acc"] + 0
      gated_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      low_rate = $idx["route_lowconf_query_rate"] + 0
      high_rate = $idx["route_highconf_query_rate"] + 0
      low_qacc = $idx["route_lowconf_qacc"] + 0
      high_qacc = $idx["route_highconf_qacc"] + 0
      vote_rate = $idx["route_agg_policy_vote_rate"] + 0
      weighted_rate = $idx["route_agg_policy_weighted_rate"] + 0
    }
  }
  END {
    if (row_count != 5 || !unscaled_seen || !valueconf_seen || !agreement_seen || !gated_seen) {
      printf "expected clean/unscaled/valueconf/agreement/gated rows, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    if (unscaled_corrupt < 0.20) {
      printf "expected visible corruption, got %f\n", unscaled_corrupt > "/dev/stderr"
      exit 4
    }
    if (low_rate <= 0.0 || high_rate <= 0.0) {
      printf "expected both low/high confidence buckets, low=%f high=%f\n",
        low_rate, high_rate > "/dev/stderr"
      exit 5
    }
    if (vote_rate <= 0.0 || weighted_rate <= 0.0) {
      printf "expected both vote and weighted aggregation policies, vote=%f weighted=%f\n",
        vote_rate, weighted_rate > "/dev/stderr"
      exit 6
    }
    if (low_qacc <= 0.0 && high_qacc <= 0.0) {
      printf "expected qacc split metrics to be populated\n" > "/dev/stderr"
      exit 7
    }
    if (gated_wrong_strength > unscaled_wrong_strength + 1.0) {
      printf "expected gated wrong strength not to catastrophically exceed unscaled, unscaled=%f gated=%f\n",
        unscaled_wrong_strength, gated_wrong_strength > "/dev/stderr"
      exit 8
    }
    if (gated_qacc + 0.05 < agreement_qacc) {
      printf "expected gated aggregation not to catastrophically trail agreement, agreement=%f gated=%f\n",
        agreement_qacc, gated_qacc > "/dev/stderr"
      exit 9
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code confidence-gated aggregation smoke passed"
