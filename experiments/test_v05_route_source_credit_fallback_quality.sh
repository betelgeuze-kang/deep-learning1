#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_fallback_quality_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_fallback_quality.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 6 }
  NR == 1 {
    split("scenario arm fallback_source route_hint_agg source_credit_apply_mode key_count seed qacc decode primary_recall fallback_used fallback_recall fallback_qacc fallback_success fallback_hi_acc fallback_lo_acc fallback_route_margin fallback_effective_strength fallback_local_margin fallback_hi_local_margin fallback_lo_local_margin candidate_top1 candidate_rank correct_vote_share vote_entropy unique_values vote_margin vote_candidate_count source_gap selected_fallback strength_mean lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    fallback_source = $idx["fallback_source"]
    agg = $idx["route_hint_agg"]
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
    fallback_hi_acc = metric("fallback_hi_acc")
    fallback_lo_acc = metric("fallback_lo_acc")
    candidate_top1 = metric("candidate_top1")
    candidate_rank = metric("candidate_rank")
    correct_vote_share = metric("correct_vote_share")
    vote_entropy = metric("vote_entropy")
    unique_values = metric("unique_values")
    vote_margin = metric("vote_margin")
    vote_candidate_count = metric("vote_candidate_count")
    source_gap = metric("source_gap")
    selected_fallback = metric("selected_fallback")
    strength_mean = metric("strength_mean")
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
        fallback_hi_acc < 0 || fallback_hi_acc > 1 ||
        fallback_lo_acc < 0 || fallback_lo_acc > 1 ||
        candidate_top1 < 0 || candidate_top1 > 1 ||
        correct_vote_share < 0 || correct_vote_share > 1 ||
        vote_margin < 0 || vote_margin > 1 ||
        selected_fallback < 0 || selected_fallback > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("candidate value_pos/value byte read path should stay populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("fallback quality diagnostics must not activate jump-neighbor routing: " scenario, 6)
    }
    if (decode > 0.75) {
      die("weak route-code source should remain weak: " scenario, 7)
    }
    if (!(fallback_used > 0 && fallback_recall > 0 && fallback_success > 0)) {
      die("fallback quality arms should recover candidate availability: " scenario, 8)
    }
    if (candidate_rank <= 0 || vote_candidate_count <= 0 || unique_values <= 0) {
      die("candidate-quality metrics should be populated: " scenario, 9)
    }

    rows++
    if (arm == "raw-vote-off") {
      if (fallback_source != "raw-key" || agg != "vote" || apply_mode != "off") {
        die("raw-vote-off configuration mismatch: " scenario, 10)
      }
      raw_vote_seen = 1
      raw_vote_qacc = qacc
      raw_vote_fallback_qacc = fallback_qacc
      raw_vote_top1 = candidate_top1
      raw_vote_share = correct_vote_share
      raw_vote_entropy = vote_entropy
      raw_vote_rank = candidate_rank
      raw_primary = primary_recall
    } else if (arm == "raw-weighted-off") {
      if (fallback_source != "raw-key" || agg != "weighted-vote" || apply_mode != "off") {
        die("raw-weighted-off configuration mismatch: " scenario, 11)
      }
      raw_weighted_seen = 1
      raw_weighted_qacc = qacc
      raw_weighted_fallback_qacc = fallback_qacc
      raw_weighted_share = correct_vote_share
      raw_weighted_entropy = vote_entropy
      raw_weighted_rank = candidate_rank
    } else if (arm == "raw-weighted-policy") {
      if (fallback_source != "raw-key" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("raw-weighted-policy configuration mismatch: " scenario, 12)
      }
      if (!(source_gap > 0 && selected_fallback > 0 && strength_mean > 1.0)) {
        die("raw-weighted-policy should expose source-credit policy diagnostics: " scenario, 13)
      }
      raw_policy_seen = 1
      raw_policy_qacc = qacc
    } else if (arm == "keyshape-vote-off") {
      if (fallback_source != "key-shape" || agg != "vote" || apply_mode != "off") {
        die("keyshape-vote-off configuration mismatch: " scenario, 14)
      }
      shape_vote_seen = 1
      shape_vote_qacc = qacc
      shape_vote_fallback_qacc = fallback_qacc
      shape_vote_top1 = candidate_top1
      shape_vote_share = correct_vote_share
      shape_vote_entropy = vote_entropy
      shape_vote_rank = candidate_rank
      shape_primary = primary_recall
    } else if (arm == "keyshape-weighted-off") {
      if (fallback_source != "key-shape" || agg != "weighted-vote" || apply_mode != "off") {
        die("keyshape-weighted-off configuration mismatch: " scenario, 15)
      }
      shape_weighted_seen = 1
      shape_weighted_qacc = qacc
      shape_weighted_fallback_qacc = fallback_qacc
      shape_weighted_share = correct_vote_share
      shape_weighted_entropy = vote_entropy
      shape_weighted_rank = candidate_rank
    } else if (arm == "keyshape-weighted-policy") {
      if (fallback_source != "key-shape" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("keyshape-weighted-policy configuration mismatch: " scenario, 16)
      }
      if (!(source_gap > 0 && selected_fallback > 0 && strength_mean > 1.0)) {
        die("keyshape-weighted-policy should expose source-credit policy diagnostics: " scenario, 17)
      }
      shape_policy_seen = 1
      shape_policy_qacc = qacc
    } else {
      die("unexpected arm: " arm, 18)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 19)
    }
    if (!(raw_vote_seen && raw_weighted_seen && raw_policy_seen &&
          shape_vote_seen && shape_weighted_seen && shape_policy_seen)) {
      die("missing one or more fallback quality arms", 20)
    }
    if (raw_primary != shape_primary) {
      die("raw/key-shape fallback arms should not change primary recall", 21)
    }
    if (raw_vote_qacc <= shape_vote_qacc) {
      die("raw-key vote qacc should exceed key-shape vote qacc in the quality-gap smoke", 22)
    }
    if (raw_weighted_qacc <= raw_vote_qacc + 0.30 ||
        shape_weighted_qacc <= shape_vote_qacc + 0.30 ||
        raw_weighted_fallback_qacc <= raw_vote_fallback_qacc + 0.30 ||
        shape_weighted_fallback_qacc <= shape_vote_fallback_qacc + 0.30) {
      die("weighted-vote should expose aggregation quality as the main rescue signal", 23)
    }
    if (raw_weighted_share <= raw_vote_share ||
        shape_weighted_share <= shape_vote_share ||
        raw_weighted_entropy >= raw_vote_entropy ||
        shape_weighted_entropy >= shape_vote_entropy) {
      die("weighted-vote should increase correct value support and lower entropy", 24)
    }
    if (raw_vote_top1 > 0.20 || shape_vote_top1 > 0.20 ||
        raw_vote_rank <= 1.0 || shape_vote_rank <= 1.0) {
      die("quality-gap smoke should show low top1/rank pressure rather than solved top1", 25)
    }
    if (raw_policy_qacc + 1.0e-6 < raw_weighted_qacc ||
        shape_policy_qacc + 1.0e-6 < shape_weighted_qacc) {
      die("source-credit policy should not regress the weighted-vote quality baseline", 26)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit fallback quality smoke passed"
