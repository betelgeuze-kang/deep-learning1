#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_credit_calibration_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_credit_calibration.sh" --smoke

awk -F, '
  function die(msg, code) {
    printf "%s\n", msg > "/dev/stderr"
    exit code
  }
  function near(a, b, eps) {
    return (a >= b - eps && a <= b + eps)
  }
  BEGIN {
    expected_rows = 10
  }
  NR == 1 {
    split("scenario route_credit_learning route_credit_mode route_credit_score_weight route_credit_eta_reward route_credit_eta_slash route_credit_decay route_credit_clip route_fallback_source route_fallback_strength_mode route_fallback_strength_mult route_fallback_hi_strength_mult route_fallback_lo_strength_mult route_fallback_channel_strength_mode route_corrupt_preserve_correct route_corrupt_candidate_rate fixture_query_byte_acc route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_value_top_correct_rate route_hint_correct_value_vote_share_mean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1", required, " ")
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    scenario = $idx["scenario"]
    learning = $idx["route_credit_learning"] + 0
    mode = $idx["route_credit_mode"]
    score_weight = $idx["route_credit_score_weight"] + 0
    eta_reward = $idx["route_credit_eta_reward"] + 0
    eta_slash = $idx["route_credit_eta_slash"] + 0
    decay = $idx["route_credit_decay"] + 0
    clip = $idx["route_credit_clip"] + 0
    fallback_source = $idx["route_fallback_source"]
    fallback_strength_mode = $idx["route_fallback_strength_mode"]
    fallback_strength_mult = $idx["route_fallback_strength_mult"] + 0
    fallback_hi_mult = $idx["route_fallback_hi_strength_mult"] + 0
    fallback_lo_mult = $idx["route_fallback_lo_strength_mult"] + 0
    fallback_channel_mode = $idx["route_fallback_channel_strength_mode"]
    preserve = $idx["route_corrupt_preserve_correct"] + 0
    corrupt_rate = $idx["route_corrupt_candidate_rate"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    correct_mean = $idx["route_credit_correct_mean"] + 0
    wrong_mean = $idx["route_credit_wrong_mean"] + 0
    gap = $idx["route_credit_gap"] + 0
    rewarded = $idx["route_credit_rewarded_rate"] + 0
    slashed = $idx["route_credit_slashed_rate"] + 0
    top1 = $idx["route_credit_top1_rate"] + 0
    credit_qacc = $idx["route_credit_qacc"] + 0
    value_top = $idx["route_value_top_correct_rate"] + 0
    vote_share = $idx["route_hint_correct_value_vote_share_mean"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    fallback_hi_acc = $idx["route_fallback_hi_acc"] + 0
    fallback_lo_acc = $idx["route_fallback_lo_acc"] + 0
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0
    fallback_hi_strength = $idx["route_fallback_hi_effective_strength_mean"] + 0
    fallback_lo_strength = $idx["route_fallback_lo_effective_strength_mean"] + 0
    low_rate = $idx["route_lowconf_query_rate"] + 0
    high_rate = $idx["route_highconf_query_rate"] + 0
    low_qacc = $idx["route_lowconf_qacc"] + 0
    high_qacc = $idx["route_highconf_qacc"] + 0
    low_recall = $idx["route_lowconf_candidate_recall"] + 0
    high_recall = $idx["route_highconf_candidate_recall"] + 0
    low_top1 = $idx["route_lowconf_top1"] + 0
    high_top1 = $idx["route_highconf_top1"] + 0

    if (mode == "off" && learning != 0) {
      die("expected off baseline to use route_credit_learning=0 for " scenario, 3)
    }
    if (mode != "off" && learning != 1) {
      die("expected active credit row to use route_credit_learning=1 for " scenario, 3)
    }
    if (fallback_source != "key-shape" || fallback_strength_mode != "fixed" ||
        fallback_channel_mode != "fixed" || !near(fallback_hi_mult, 5.0, 0.000001) ||
        !near(fallback_strength_mult, 1.0, 0.000001)) {
      die("fallback calibration knobs changed unexpectedly: " scenario, 4)
    }
    if (!(mode == "off" || mode == "value-pos" || mode == "query-value")) {
      die("unexpected credit mode: " mode, 5)
    }
    if (!(near(score_weight, 1.0, 0.000001) || near(score_weight, 2.0, 0.000001))) {
      die("unexpected score weight: " score_weight " for " scenario, 6)
    }
    if (!near(eta_reward, 0.05, 0.000001) ||
        !(near(eta_slash, 0.10, 0.000001) || near(eta_slash, 0.20, 0.000001))) {
      die("unexpected reward/slash knobs: " scenario, 7)
    }
    if (!near(decay, 0.0, 0.000001) || !near(clip, 2.0, 0.000001)) {
      die("unexpected stability knobs: " scenario, 8)
    }
    if (!(near(corrupt_rate, 0.10, 0.000001) || near(corrupt_rate, 0.25, 0.000001))) {
      die("unexpected corruption rate: " scenario, 9)
    }
    if (!(near(fallback_lo_mult, 7.5, 0.000001) || near(fallback_lo_mult, 10.0, 0.000001))) {
      die("unexpected low-channel multiplier: " scenario, 10)
    }
    if (preserve != 0 && preserve != 1) {
      die("unexpected preserve flag: " scenario, 11)
    }
    if (qacc < 0.0 || qacc > 1.0 || credit_qacc < 0.0 || credit_qacc > 1.0 ||
        value_top < 0.0 || value_top > 1.0 || vote_share < 0.0 || vote_share > 1.0 ||
        top1 < 0.0 || top1 > 1.0 || low_rate < 0.0 || low_rate > 1.0 ||
        high_rate < 0.0 || high_rate > 1.0 || low_qacc < 0.0 || low_qacc > 1.0 ||
        high_qacc < 0.0 || high_qacc > 1.0 || low_recall < 0.0 || low_recall > 1.0 ||
        high_recall < 0.0 || high_recall > 1.0 || low_top1 < 0.0 || low_top1 > 1.0 ||
        high_top1 < 0.0 || high_top1 > 1.0) {
      die("diagnostic metric out of range: " scenario, 12)
    }

    if (mode == "off" && !(near(gap, 0.0, 0.000001) && rewarded <= 0.0 && slashed <= 0.0)) {
      die("expected off baseline to remain credit-neutral: " scenario, 13)
    }
    if (mode != "off" && !(gap > 0.0 && correct_mean > wrong_mean && rewarded > 0.0 && slashed > 0.0)) {
      die("expected positive credit separation for active credit: " scenario, 13)
    }

    if (preserve == 0) {
      # We expect the remove-correct rows to expose fallback diagnostics, but
      # we intentionally do not assert any qacc win here.
      if (!(fallback_used > 0.0 && fallback_recall > 0.0 && fallback_qacc > 0.0 &&
            fallback_success > 0.0 && fallback_hi_acc > 0.0 &&
            fallback_lo_acc > 0.0 && fallback_strength > 0.0 &&
            fallback_hi_strength > 0.0 && fallback_lo_strength > 0.0)) {
        die("fallback metrics missing for remove-correct row: " scenario, 14)
      }
    }

    seen[scenario] = 1
    ++rows
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " smoke rows, found " rows, 15)
    }

    split("off-remove-lo7p5-sw1p0-sl0p10-cr0p10 off-remove-lo10-sw1p0-sl0p10-cr0p25 value-pos-preserve-lo7p5-sw1p0-sl0p10-cr0p10 value-pos-remove-lo10-sw1p0-sl0p20-cr0p25 value-pos-preserve-lo10-sw2p0-sl0p10-cr0p25 value-pos-remove-lo7p5-sw2p0-sl0p20-cr0p10 query-value-preserve-lo7p5-sw1p0-sl0p20-cr0p25 query-value-remove-lo10-sw1p0-sl0p10-cr0p10 query-value-preserve-lo10-sw2p0-sl0p20-cr0p10 query-value-remove-lo7p5-sw2p0-sl0p10-cr0p25", expected, " ")
    for (i = 1; i <= length(expected); i++) {
      if (!(expected[i] in seen)) {
        die("missing smoke scenario: " expected[i], 16)
      }
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code credit calibration smoke passed"
