#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_credit_fallback_factorial_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_credit_fallback_factorial.sh" --smoke

awk -F, '
  function die(msg, code) {
    printf "%s\n", msg > "/dev/stderr"
    exit code
  }
  function near(a, b, eps) {
    return (a >= b - eps && a <= b + eps)
  }
  BEGIN {
    expected_rows = 18
  }
  NR == 1 {
    split("scenario credit_variant route_credit_learning route_credit_mode route_credit_score_weight route_credit_eta_reward route_credit_eta_slash route_credit_decay route_credit_clip route_fallback_source route_fallback_hi_strength_mult route_fallback_lo_strength_mult route_corrupt_preserve_correct route_corrupt_candidate_rate fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_candidate_corrupt_rate route_primary_recall route_primary_lowconf_rate route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_value_top_correct_rate route_hint_correct_value_vote_share_mean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1 route_agg_policy_vote_rate route_agg_policy_weighted_rate route_abstain_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    scenario = $idx["scenario"]
    variant = $idx["credit_variant"]
    learning = $idx["route_credit_learning"] + 0
    mode = $idx["route_credit_mode"]
    score_weight = $idx["route_credit_score_weight"] + 0
    eta_slash = $idx["route_credit_eta_slash"] + 0
    fallback_source = $idx["route_fallback_source"]
    hi_mult = $idx["route_fallback_hi_strength_mult"] + 0
    lo_mult = $idx["route_fallback_lo_strength_mult"] + 0
    preserve = $idx["route_corrupt_preserve_correct"] + 0
    corrupt_rate = $idx["route_corrupt_candidate_rate"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    clean_qacc = $idx["clean_reference_qacc"] + 0
    damage = $idx["damage_vs_clean"] + 0
    observed_corrupt = $idx["route_candidate_corrupt_rate"] + 0
    primary_recall = $idx["route_primary_recall"] + 0
    credit_gap = $idx["route_credit_gap"] + 0
    rewarded = $idx["route_credit_rewarded_rate"] + 0
    slashed = $idx["route_credit_slashed_rate"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_hi_acc = $idx["route_fallback_hi_acc"] + 0
    fallback_lo_acc = $idx["route_fallback_lo_acc"] + 0
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0
    fallback_hi_strength = $idx["route_fallback_hi_effective_strength_mean"] + 0
    fallback_lo_strength = $idx["route_fallback_lo_effective_strength_mean"] + 0
    low_rate = $idx["route_lowconf_query_rate"] + 0
    high_rate = $idx["route_highconf_query_rate"] + 0
    vote_rate = $idx["route_agg_policy_vote_rate"] + 0
    weighted_rate = $idx["route_agg_policy_weighted_rate"] + 0

    if (variant != "off" && variant != "value-pos" && variant != "query-value") {
      die("unexpected credit variant: " variant, 3)
    }
    if (variant == "off" && (mode != "off" || learning != 0)) {
      die("off variant did not use route-credit-mode off", 4)
    }
    if (variant == "value-pos" && (mode != "value-pos" || learning != 1)) {
      die("value-pos variant has wrong mode/learning", 5)
    }
    if (variant == "query-value" && (mode != "query-value" || learning != 1)) {
      die("query-value variant has wrong mode/learning", 6)
    }
    if (fallback_source != "key-shape" || !near(hi_mult, 5.0, 0.000001) ||
        !near(corrupt_rate, 0.25, 0.000001)) {
      die("factorial fallback/corruption knobs changed unexpectedly", 7)
    }
    if (!(near(lo_mult, 7.5, 0.000001) || near(lo_mult, 10.0, 0.000001) ||
          near(lo_mult, 15.0, 0.000001))) {
      die("unexpected lo multiplier", 8)
    }
    if (preserve != 0 && preserve != 1) {
      die("unexpected preserve flag", 9)
    }
    if (qacc < 0.0 || qacc > 1.0) {
      die("qacc out of range", 10)
    }
    if (clean_qacc < 0.0 || clean_qacc > 1.0 || damage < -1.0 || damage > 1.0 ||
        observed_corrupt < 0.0 || observed_corrupt > 1.0 ||
        primary_recall < 0.0 || primary_recall > 1.0) {
      die("diagnostic qacc/recall fields out of range", 10)
    }
    if (low_rate < 0.0 || low_rate > 1.0 || high_rate < 0.0 || high_rate > 1.0 ||
        vote_rate < 0.0 || vote_rate > 1.0 || weighted_rate < 0.0 ||
        weighted_rate > 1.0) {
      die("confidence split or aggregation policy fields out of range", 10)
    }

    key = preserve ":" lo_mult ":" variant
    seen[key] = 1
    ++rows

    if (variant != "off") {
      if (!(credit_gap > 0.0 && rewarded > 0.0 && slashed > 0.0)) {
        die("credit-on row did not produce separation metrics: " scenario, 11)
      }
      positive_gap[variant] = 1
    } else if (credit_gap < -0.000001) {
      die("credit-off row has negative gap", 12)
    }

    if (preserve == 0) {
      if (!(fallback_used > 0.0 && fallback_recall > 0.0 && fallback_qacc > 0.0 &&
            fallback_hi_acc > 0.0 && fallback_lo_acc > 0.0 &&
            fallback_strength > 0.0 && fallback_hi_strength > 0.0 &&
            fallback_lo_strength > 0.0)) {
        die("remove-correct row did not populate fallback metrics: " scenario, 13)
      }
      if (variant == "off") {
        remove_off_lo_strength[lo_mult] = fallback_lo_strength
      }
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 14)
    }
    split("off value-pos query-value", variants, " ")
    split("7.5 10 15", los, " ")
    for (p = 0; p <= 1; p++) {
      for (l = 1; l <= length(los); l++) {
        for (v = 1; v <= length(variants); v++) {
          key = p ":" los[l] ":" variants[v]
          if (!(key in seen)) {
            die("missing factorial cell: " key, 15)
          }
        }
      }
    }
    if (!positive_gap["value-pos"] || !positive_gap["query-value"]) {
      die("credit-on variants did not show positive credit gaps", 16)
    }
    if (!(remove_off_lo_strength[10] > remove_off_lo_strength[7.5] &&
          remove_off_lo_strength[15] > remove_off_lo_strength[10])) {
      die("remove-correct off rows did not show increasing low-channel strength", 17)
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code credit×fallback factorial smoke passed"
