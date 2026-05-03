#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_source_aware_aggregation_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_source_aware_aggregation.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 9 }
  NR == 1 {
    split("scenario arm fallback_source route_hint_agg lowconf_agg highconf_agg source_credit_apply_mode key_count seed qacc decode primary_recall fallback_used fallback_recall fallback_qacc fallback_success candidate_top1 candidate_rank correct_vote_share vote_entropy vote_margin source_gap noisy_mean noisy_slashed noisy_selected selected_fallback strength_mean agg_vote_rate agg_weighted_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    arm = $idx["arm"]
    source = $idx["fallback_source"]
    agg = $idx["route_hint_agg"]
    low_agg = $idx["lowconf_agg"]
    high_agg = $idx["highconf_agg"]
    apply_mode = $idx["source_credit_apply_mode"]
    key_count = metric("key_count")
    seed = metric("seed")
    qacc = metric("qacc")
    decode = metric("decode")
    primary_recall = metric("primary_recall")
    fallback_used = metric("fallback_used")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    fallback_success = metric("fallback_success")
    candidate_top1 = metric("candidate_top1")
    candidate_rank = metric("candidate_rank")
    correct_vote_share = metric("correct_vote_share")
    vote_entropy = metric("vote_entropy")
    source_gap = metric("source_gap")
    noisy_mean = metric("noisy_mean")
    noisy_slashed = metric("noisy_slashed")
    noisy_selected = metric("noisy_selected")
    selected_fallback = metric("selected_fallback")
    strength_mean = metric("strength_mean")
    agg_vote_rate = metric("agg_vote_rate")
    agg_weighted_rate = metric("agg_weighted_rate")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (key_count != 128 || seed != 1) {
      die("smoke should only run key_count=128 seed=1: " scenario, 3)
    }
    if (qacc < 0 || qacc > 1 || decode < 0 || decode > 1 ||
        primary_recall < 0 || primary_recall > 1 ||
        fallback_used < 0 || fallback_used > 1 ||
        fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 ||
        fallback_success < 0 || fallback_success > 1 ||
        candidate_top1 < 0 || candidate_top1 > 1 ||
        correct_vote_share < 0 || correct_vote_share > 1 ||
        noisy_slashed < 0 || noisy_slashed > 1 ||
        noisy_selected < 0 || noisy_selected > 1 ||
        selected_fallback < 0 || selected_fallback > 1 ||
        agg_vote_rate < 0 || agg_vote_rate > 1 ||
        agg_weighted_rate < 0 || agg_weighted_rate > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("candidate value_pos/value byte read path should stay populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("source-aware aggregation diagnostics must not activate jump-neighbor routing: " scenario, 6)
    }
    if (decode > 0.75) {
      die("weak route-code source should remain weak: " scenario, 7)
    }
    if (candidate_rank <= 0) {
      die("candidate-rank metric should be populated: " scenario, 8)
    }

    rows++
    if (arm == "raw-vote") {
      if (source != "raw-key" || agg != "vote" || apply_mode != "off") {
        die("raw-vote configuration mismatch: " scenario, 9)
      }
      raw_vote_seen = 1
      raw_vote_qacc = qacc
      raw_vote_recall = fallback_recall
      raw_vote_share = correct_vote_share
      raw_vote_entropy = vote_entropy
      raw_primary = primary_recall
    } else if (arm == "raw-source-aware") {
      if (source != "raw-key" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("raw-source-aware configuration mismatch: " scenario, 10)
      }
      raw_aware_seen = 1
      raw_aware_qacc = qacc
      raw_aware_recall = fallback_recall
      raw_aware_share = correct_vote_share
      raw_aware_entropy = vote_entropy
      raw_aware_gap = source_gap
    } else if (arm == "raw-gated-safe") {
      if (source != "raw-key" || agg != "confidence-gated" ||
          low_agg != "weighted-vote" || high_agg != "weighted-vote") {
        die("raw-gated-safe configuration mismatch: " scenario, 11)
      }
      raw_gated_safe_seen = 1
      raw_gated_safe_qacc = qacc
      raw_gated_safe_weighted = agg_weighted_rate
    } else if (arm == "keyshape-vote") {
      if (source != "key-shape" || agg != "vote" || apply_mode != "off") {
        die("keyshape-vote configuration mismatch: " scenario, 12)
      }
      shape_vote_seen = 1
      shape_vote_qacc = qacc
      shape_vote_recall = fallback_recall
      shape_vote_share = correct_vote_share
      shape_vote_entropy = vote_entropy
      shape_primary = primary_recall
    } else if (arm == "keyshape-source-aware") {
      if (source != "key-shape" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("keyshape-source-aware configuration mismatch: " scenario, 13)
      }
      shape_aware_seen = 1
      shape_aware_qacc = qacc
      shape_aware_recall = fallback_recall
      shape_aware_share = correct_vote_share
      shape_aware_entropy = vote_entropy
      shape_aware_gap = source_gap
    } else if (arm == "keyshape-gated-safe") {
      if (source != "key-shape" || agg != "confidence-gated" ||
          low_agg != "weighted-vote" || high_agg != "weighted-vote") {
        die("keyshape-gated-safe configuration mismatch: " scenario, 14)
      }
      shape_gated_safe_seen = 1
      shape_gated_safe_qacc = qacc
      shape_gated_safe_weighted = agg_weighted_rate
    } else if (arm == "noisy-vote") {
      if (source != "noisy-route-code" || agg != "vote" || apply_mode != "off") {
        die("noisy-vote configuration mismatch: " scenario, 15)
      }
      noisy_vote_seen = 1
      noisy_vote_qacc = qacc
      noisy_vote_recall = fallback_recall
    } else if (arm == "noisy-source-aware") {
      if (source != "noisy-route-code" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("noisy-source-aware configuration mismatch: " scenario, 16)
      }
      noisy_aware_seen = 1
      noisy_aware_qacc = qacc
      noisy_aware_recall = fallback_recall
      noisy_aware_gap = source_gap
      noisy_aware_mean = noisy_mean
      noisy_aware_slashed = noisy_slashed
      noisy_aware_selected = noisy_selected
      noisy_aware_strength = strength_mean
    } else if (arm == "noisy-gated-safe") {
      if (source != "noisy-route-code" || agg != "confidence-gated" ||
          low_agg != "weighted-vote" || high_agg != "weighted-vote") {
        die("noisy-gated-safe configuration mismatch: " scenario, 17)
      }
      noisy_gated_safe_seen = 1
      noisy_gated_safe_qacc = qacc
      noisy_gated_safe_recall = fallback_recall
    } else {
      die("unexpected arm: " arm, 18)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 19)
    }
    if (!(raw_vote_seen && raw_aware_seen && raw_gated_safe_seen &&
          shape_vote_seen && shape_aware_seen && shape_gated_safe_seen &&
          noisy_vote_seen && noisy_aware_seen && noisy_gated_safe_seen)) {
      die("missing one or more source-aware aggregation arms", 20)
    }
    if (raw_primary != shape_primary) {
      die("raw/key-shape arms should not change primary recall", 21)
    }
    if (raw_vote_recall <= 0 || raw_aware_recall <= 0 ||
        shape_vote_recall <= 0 || shape_aware_recall <= 0) {
      die("symbolic source-aware arms should recover fallback candidates", 22)
    }
    if (raw_aware_qacc <= raw_vote_qacc + 0.30 ||
        shape_aware_qacc <= shape_vote_qacc + 0.30) {
      die("source-aware weighted policy should improve over broad vote on symbolic fallbacks", 23)
    }
    if (raw_aware_share <= raw_vote_share ||
        shape_aware_share <= shape_vote_share ||
        raw_aware_entropy >= raw_vote_entropy ||
        shape_aware_entropy >= shape_vote_entropy) {
      die("source-aware weighted policy should improve support/entropy on symbolic fallbacks", 24)
    }
    if (raw_aware_gap <= 0 || shape_aware_gap <= 0) {
      die("symbolic source-aware policy should produce positive source gap", 25)
    }
    if (raw_gated_safe_qacc + 1.0e-6 < raw_aware_qacc ||
        shape_gated_safe_qacc + 1.0e-6 < shape_aware_qacc ||
        raw_gated_safe_weighted < 0.999 ||
        shape_gated_safe_weighted < 0.999) {
      die("gated safe policy should preserve all-weighted symbolic baseline", 26)
    }
    if (noisy_aware_recall != 0 || noisy_gated_safe_recall != 0 ||
        noisy_aware_gap >= 0 || noisy_aware_mean >= 0 ||
        noisy_aware_slashed <= 0 || noisy_aware_selected != 0 ||
        noisy_aware_strength > 1.000001) {
      die("noisy source-aware policy should detect bad fallback without strengthening it", 27)
    }
    if (noisy_aware_qacc > raw_aware_qacc || noisy_aware_qacc > shape_aware_qacc ||
        noisy_gated_safe_qacc > raw_gated_safe_qacc ||
        noisy_gated_safe_qacc > shape_gated_safe_qacc) {
      die("noisy source-aware policy should not masquerade as symbolic fallback solved", 28)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit source-aware aggregation smoke passed"
