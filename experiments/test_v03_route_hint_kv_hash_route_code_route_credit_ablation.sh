#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_route_credit_ablation_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_route_credit_ablation.sh" --smoke

awk -F, '
  function die(msg, code) {
    printf "%s\n", msg > "/dev/stderr"
    exit code
  }
  function near(a, b, eps) {
    return (a >= b - eps && a <= b + eps)
  }
  BEGIN {
    fallback_75_lo_strength = 0.0
    query_blocker = ""
  }
  NR == 1 {
    split("scenario route_credit_status route_credit_blocker route_credit_learning route_credit_mode route_credit_score_weight route_credit_eta_reward route_credit_eta_slash route_credit_decay route_credit_clip route_fallback_source route_fallback_strength_mode route_fallback_strength_mult route_fallback_hi_strength_mult route_fallback_lo_strength_mult route_fallback_channel_strength_mode route_corrupt_preserve_correct route_corrupt_candidate_rate fixture_query_byte_acc route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_value_top_correct_rate route_hint_correct_value_vote_share_mean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean", required, " ")
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
    status = $idx["route_credit_status"]
    blocker = $idx["route_credit_blocker"]
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
    preserve_correct = $idx["route_corrupt_preserve_correct"] + 0
    candidate_rate = $idx["route_corrupt_candidate_rate"] + 0
    credit_gap = $idx["route_credit_gap"] + 0
    credit_qacc = $idx["route_credit_qacc"] + 0
    credit_rewarded = $idx["route_credit_rewarded_rate"] + 0
    credit_slashed = $idx["route_credit_slashed_rate"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_hi_acc = $idx["route_fallback_hi_acc"] + 0
    fallback_lo_acc = $idx["route_fallback_lo_acc"] + 0
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0
    fallback_hi_strength = $idx["route_fallback_hi_effective_strength_mean"] + 0
    fallback_lo_strength = $idx["route_fallback_lo_effective_strength_mean"] + 0
    fixture_qacc = $idx["fixture_query_byte_acc"] + 0

    if (scenario == "value-pos-base") {
      saw_base = 1
      if (status != "run" || mode != "value-pos" || learning != 0) {
        die("value-pos-base has the wrong mode/status/learning", 3)
      }
      if (!near(score_weight, 1.0, 0.000001) || !near(eta_reward, 0.05, 0.000001) ||
          !near(eta_slash, 0.10, 0.000001) || !near(decay, 0.001, 0.000001) ||
          !near(clip, 4.0, 0.000001) || fallback_source != "off" ||
          fallback_strength_mode != "fixed" || !near(fallback_strength_mult, 1.0, 0.000001) ||
          !near(fallback_hi_mult, 1.0, 0.000001) || !near(fallback_lo_mult, 1.0, 0.000001) ||
          fallback_channel_mode != "fixed" || preserve_correct != 1 ||
          !near(candidate_rate, 0.25, 0.000001)) {
        die("value-pos-base knob check failed", 4)
      }
      if (credit_gap < -0.000001 || credit_qacc < 0.0 ||
          fixture_qacc < 0.0 || fixture_qacc > 1.0) {
        die("value-pos-base metrics look unparsed", 5)
      }
    } else if (scenario == "value-pos-strong-slash") {
      saw_strong = 1
      if (status != "run" || mode != "value-pos" || learning != 1) {
        die("value-pos-strong-slash has the wrong mode/status/learning", 6)
      }
      if (!near(score_weight, 2.0, 0.000001) || !near(eta_reward, 0.05, 0.000001) ||
          !near(eta_slash, 0.20, 0.000001) || !near(decay, 0.0, 0.000001) ||
          !near(clip, 2.0, 0.000001) || fallback_source != "off" ||
          fallback_strength_mode != "fixed" || !near(fallback_strength_mult, 1.0, 0.000001) ||
          !near(fallback_hi_mult, 1.0, 0.000001) || !near(fallback_lo_mult, 1.0, 0.000001) ||
          fallback_channel_mode != "fixed" || preserve_correct != 1 ||
          !near(candidate_rate, 0.25, 0.000001)) {
        die("value-pos-strong-slash knob check failed", 7)
      }
      if (!(credit_gap > 0.0 && credit_qacc > 0.0 && credit_rewarded > 0.0 && credit_slashed > 0.0)) {
        die("value-pos-strong-slash metrics did not parse", 8)
      }
    } else if (scenario == "fallback-lo7p5-off") {
      saw_fallback_75 = 1
      if (status != "run" || mode != "value-pos" || learning != 0) {
        die("fallback-lo7p5-off has the wrong mode/status/learning", 9)
      }
      if (fallback_source != "key-shape" || fallback_strength_mode != "fixed" ||
          !near(fallback_strength_mult, 1.0, 0.000001) ||
          !near(fallback_hi_mult, 5.0, 0.000001) ||
          !near(fallback_lo_mult, 7.5, 0.000001) ||
          fallback_channel_mode != "fixed" || preserve_correct != 0) {
        die("fallback-lo7p5-off knob check failed", 10)
      }
      if (!(fallback_used > 0.0 && fallback_recall > 0.0 && fallback_qacc > 0.0 &&
            fallback_hi_acc > 0.0 && fallback_lo_acc > 0.0 &&
            fallback_strength > 0.0 && fallback_hi_strength > 0.0 &&
            fallback_lo_strength > 0.0)) {
        die("fallback-lo7p5-off metrics did not parse", 11)
      }
      fallback_75_lo_strength = fallback_lo_strength
    } else if (scenario == "fallback-lo10-on") {
      saw_fallback_10 = 1
      if (status != "run" || mode != "value-pos" || learning != 1) {
        die("fallback-lo10-on has the wrong mode/status/learning", 12)
      }
      if (fallback_source != "key-shape" || fallback_strength_mode != "fixed" ||
          !near(fallback_strength_mult, 1.0, 0.000001) ||
          !near(fallback_hi_mult, 5.0, 0.000001) ||
          !near(fallback_lo_mult, 10.0, 0.000001) ||
          fallback_channel_mode != "fixed" || preserve_correct != 0) {
        die("fallback-lo10-on knob check failed", 13)
      }
      if (!(fallback_used > 0.0 && fallback_recall > 0.0 && fallback_qacc > 0.0 &&
            fallback_hi_acc > 0.0 && fallback_lo_acc > 0.0 &&
            fallback_strength > 0.0 && fallback_hi_strength > 0.0 &&
            fallback_lo_strength > 0.0)) {
        die("fallback-lo10-on metrics did not parse", 14)
      }
      if (!(fallback_lo_strength > fallback_75_lo_strength && fallback_75_lo_strength > 0.0)) {
        die("expected lo=10 effective strength to exceed lo=7.5", 15)
      }
    } else if (scenario == "query-value-probe") {
      saw_query = 1
      if (mode != "query-value" || learning != 1) {
        die("query-value-probe did not keep query-value mode", 16)
      }
      if (status == "blocked") {
        saw_query_blocked = 1
        query_blocker = blocker
        if (blocker == "" || blocker == "-") {
          die("blocked query-value probe did not report a blocker", 17)
        }
      } else if (status == "run") {
        saw_query_run = 1
        if (!(credit_qacc > 0.0 && credit_gap >= 0.0)) {
          die("query-value run did not parse credit metrics", 18)
        }
      } else {
        die("query-value-probe had an unexpected status", 19)
      }
    } else {
      die("unexpected scenario: " scenario, 20)
    }

    ++rows
  }
  END {
    if (rows < 5 || !saw_base || !saw_strong || !saw_fallback_75 || !saw_fallback_10 || !saw_query) {
      die("smoke summary is missing required rows", 21)
    }
    if (!(saw_query_run || saw_query_blocked)) {
      die("query-value probe was neither run nor blocked", 22)
    }
    if (saw_query_blocked) {
      printf "query-value mode blocked: %s\n", query_blocker > "/dev/stderr"
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code route-credit ablation smoke passed"
