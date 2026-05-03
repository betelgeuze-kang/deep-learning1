#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_fallback_aggregation_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_fallback_aggregation.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 10 }
  NR == 1 {
    split("scenario arm fallback_source route_hint_agg lowconf_agg highconf_agg key_count seed qacc decode primary_recall fallback_used fallback_recall fallback_qacc fallback_success fallback_hi_acc fallback_lo_acc candidate_top1 candidate_rank correct_vote_share vote_entropy unique_values vote_margin vote_candidate_count lowconf_rate highconf_rate lowconf_qacc highconf_qacc lowconf_top1 highconf_top1 lowconf_vote_share highconf_vote_share agg_vote_rate agg_weighted_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    lowconf_rate = metric("lowconf_rate")
    highconf_rate = metric("highconf_rate")
    lowconf_qacc = metric("lowconf_qacc")
    highconf_qacc = metric("highconf_qacc")
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
        lowconf_rate < 0 || lowconf_rate > 1 ||
        highconf_rate < 0 || highconf_rate > 1 ||
        lowconf_qacc < 0 || lowconf_qacc > 1 ||
        highconf_qacc < 0 || highconf_qacc > 1 ||
        agg_vote_rate < 0 || agg_vote_rate > 1 ||
        agg_weighted_rate < 0 || agg_weighted_rate > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("candidate value_pos/value byte read path should stay populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("fallback aggregation diagnostics must not activate jump-neighbor routing: " scenario, 6)
    }
    if (decode > 0.75) {
      die("weak route-code source should remain weak: " scenario, 7)
    }
    if (!(fallback_used > 0 && fallback_recall > 0 && fallback_success > 0)) {
      die("fallback aggregation arms should recover candidate availability: " scenario, 8)
    }
    if (candidate_rank <= 0) {
      die("candidate-rank metric should be populated: " scenario, 9)
    }

    rows++
    if (source == "raw-key") {
      raw_primary = primary_recall
      if (arm == "raw-top1") {
        raw_top1_seen = 1
        raw_top1_qacc = qacc
        raw_top1_candidate = candidate_top1
      } else if (arm == "raw-vote") {
        raw_vote_seen = 1
        raw_vote_qacc = qacc
        raw_vote_share = correct_vote_share
        raw_vote_entropy = vote_entropy
      } else if (arm == "raw-weighted") {
        raw_weighted_seen = 1
        raw_weighted_qacc = qacc
        raw_weighted_share = correct_vote_share
        raw_weighted_entropy = vote_entropy
      } else if (arm == "raw-gated-vote-weighted") {
        if (agg != "confidence-gated" || low_agg != "vote" || high_agg != "weighted-vote") {
          die("raw gated vote/weighted configuration mismatch: " scenario, 10)
        }
        raw_gated_seen = 1
        raw_gated_qacc = qacc
        raw_gated_vote_rate = agg_vote_rate
        raw_gated_weighted_rate = agg_weighted_rate
      } else if (arm == "raw-gated-weighted-weighted") {
        if (agg != "confidence-gated" || low_agg != "weighted-vote" || high_agg != "weighted-vote") {
          die("raw gated weighted/weighted configuration mismatch: " scenario, 11)
        }
        raw_gated_all_weighted_seen = 1
        raw_gated_all_weighted_qacc = qacc
      } else {
        die("unexpected raw arm: " arm, 12)
      }
    } else if (source == "key-shape") {
      shape_primary = primary_recall
      if (arm == "keyshape-top1") {
        shape_top1_seen = 1
        shape_top1_qacc = qacc
        shape_top1_candidate = candidate_top1
      } else if (arm == "keyshape-vote") {
        shape_vote_seen = 1
        shape_vote_qacc = qacc
        shape_vote_share = correct_vote_share
        shape_vote_entropy = vote_entropy
      } else if (arm == "keyshape-weighted") {
        shape_weighted_seen = 1
        shape_weighted_qacc = qacc
        shape_weighted_share = correct_vote_share
        shape_weighted_entropy = vote_entropy
      } else if (arm == "keyshape-gated-vote-weighted") {
        if (agg != "confidence-gated" || low_agg != "vote" || high_agg != "weighted-vote") {
          die("key-shape gated vote/weighted configuration mismatch: " scenario, 13)
        }
        shape_gated_seen = 1
        shape_gated_qacc = qacc
        shape_gated_vote_rate = agg_vote_rate
        shape_gated_weighted_rate = agg_weighted_rate
      } else if (arm == "keyshape-gated-weighted-weighted") {
        if (agg != "confidence-gated" || low_agg != "weighted-vote" || high_agg != "weighted-vote") {
          die("key-shape gated weighted/weighted configuration mismatch: " scenario, 14)
        }
        shape_gated_all_weighted_seen = 1
        shape_gated_all_weighted_qacc = qacc
      } else {
        die("unexpected key-shape arm: " arm, 15)
      }
    } else {
      die("unexpected fallback source: " source, 16)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 17)
    }
    if (!(raw_top1_seen && raw_vote_seen && raw_weighted_seen &&
          raw_gated_seen && raw_gated_all_weighted_seen &&
          shape_top1_seen && shape_vote_seen && shape_weighted_seen &&
          shape_gated_seen && shape_gated_all_weighted_seen)) {
      die("missing one or more fallback aggregation arms", 18)
    }
    if (raw_primary != shape_primary) {
      die("fallback aggregation arms should not change primary recall", 19)
    }
    if (raw_top1_candidate > 0.20 || shape_top1_candidate > 0.20) {
      die("top1 should remain weak in the fallback aggregation smoke", 20)
    }
    if (raw_weighted_qacc <= raw_vote_qacc + 0.30 ||
        shape_weighted_qacc <= shape_vote_qacc + 0.30) {
      die("weighted-vote should strongly improve over vote", 21)
    }
    if (raw_weighted_share <= raw_vote_share ||
        shape_weighted_share <= shape_vote_share ||
        raw_weighted_entropy >= raw_vote_entropy ||
        shape_weighted_entropy >= shape_vote_entropy) {
      die("weighted-vote should improve value support and entropy", 22)
    }
    if (raw_gated_vote_rate <= 0 || raw_gated_weighted_rate <= 0 ||
        shape_gated_vote_rate <= 0 || shape_gated_weighted_rate <= 0) {
      die("confidence-gated vote/weighted should exercise both aggregation paths", 23)
    }
    if (raw_gated_all_weighted_qacc + 1.0e-6 < raw_weighted_qacc ||
        shape_gated_all_weighted_qacc + 1.0e-6 < shape_weighted_qacc) {
      die("confidence-gated weighted/weighted should preserve weighted-vote baseline", 24)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit fallback aggregation smoke passed"
