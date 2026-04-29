#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_strength_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_strength.sh" --smoke

awk -F, '
  function abs(x) {
    return (x < 0 ? -x : x)
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_corrupt_preserve_correct route_corrupt_candidate_rate route_fallback_strength_mult route_delta_mode route_pull_scale route_push_scale route_fallback_source fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_candidate_corrupt_rate route_primary_recall route_primary_lowconf_rate route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_abstain_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1 route_fallback_hi_acc route_fallback_lo_acc route_fallback_route_margin_mean route_fallback_effective_strength_mean", required, " ")
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
    preserve = $idx["route_corrupt_preserve_correct"] + 0
    corrupt_rate = $idx["route_corrupt_candidate_rate"] + 0
    mult = $idx["route_fallback_strength_mult"] + 0
    mode = $idx["route_delta_mode"]
    pull = $idx["route_pull_scale"] + 0
    push = $idx["route_push_scale"] + 0
    source = $idx["route_fallback_source"]
    qacc = $idx["fixture_query_byte_acc"] + 0
    clean_ref = $idx["clean_reference_qacc"] + 0
    damage = $idx["damage_vs_clean"] + 0
    primary_recall = $idx["route_primary_recall"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    low_rate = $idx["route_lowconf_query_rate"] + 0
    high_rate = $idx["route_highconf_query_rate"] + 0
    low_qacc = $idx["route_lowconf_qacc"] + 0
    high_qacc = $idx["route_highconf_qacc"] + 0
    low_recall = $idx["route_lowconf_candidate_recall"] + 0
    high_recall = $idx["route_highconf_candidate_recall"] + 0
    low_top1 = $idx["route_lowconf_top1"] + 0
    high_top1 = $idx["route_highconf_top1"] + 0
    fallback_hi = $idx["route_fallback_hi_acc"] + 0
    fallback_lo = $idx["route_fallback_lo_acc"] + 0
    fallback_margin = $idx["route_fallback_route_margin_mean"] + 0
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0

    if (corrupt_rate < 0.24 || corrupt_rate > 0.26) {
      printf "expected smoke corruption 0.25, got %f for %s\n", corrupt_rate, scenario > "/dev/stderr"
      exit 3
    }
    if (source != "key-shape") {
      printf "expected key-shape fallback source, got %s for %s\n", source, scenario > "/dev/stderr"
      exit 4
    }
    if (scenario == "preserve-target-only") {
      preserve_target_seen = 1
      if (preserve != 1 || mode != "target-only" || abs(pull - 1.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 0.99 || mult > 1.01) {
        printf "unexpected preserve-target-only row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 5
      }
      preserve_target_qacc = qacc
      preserve_target_clean = clean_ref
      preserve_target_fallback = fallback_used
      preserve_target_primary = primary_recall
    } else if (scenario == "remove-target-only-m1p0") {
      remove_target_m1_seen = 1
      if (preserve != 0 || mode != "target-only" || abs(pull - 1.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 0.99 || mult > 1.01) {
        printf "unexpected remove-target-only-m1p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 6
      }
      remove_target_m1_qacc = qacc
      remove_target_m1_used = fallback_used
      remove_target_m1_recall = fallback_recall
      remove_target_m1_qacc_fb = fallback_qacc
      remove_target_m1_success = fallback_success
      remove_target_m1_hi = fallback_hi
      remove_target_m1_lo = fallback_lo
      remove_target_m1_margin = fallback_margin
      remove_target_m1_strength = fallback_strength
    } else if (scenario == "remove-target-only-m2p0") {
      remove_target_m2_seen = 1
      if (preserve != 0 || mode != "target-only" || abs(pull - 1.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 1.99 || mult > 2.01) {
        printf "unexpected remove-target-only-m2p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 7
      }
      remove_target_m2_qacc = qacc
      remove_target_m2_used = fallback_used
      remove_target_m2_recall = fallback_recall
      remove_target_m2_qacc_fb = fallback_qacc
      remove_target_m2_success = fallback_success
      remove_target_m2_hi = fallback_hi
      remove_target_m2_lo = fallback_lo
      remove_target_m2_margin = fallback_margin
      remove_target_m2_strength = fallback_strength
    } else if (scenario == "remove-target-only-m5p0") {
      remove_target_m5_seen = 1
      if (preserve != 0 || mode != "target-only" || abs(pull - 1.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 4.99 || mult > 5.01) {
        printf "unexpected remove-target-only-m5p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 8
      }
      remove_target_m5_qacc = qacc
      remove_target_m5_used = fallback_used
      remove_target_m5_recall = fallback_recall
      remove_target_m5_qacc_fb = fallback_qacc
      remove_target_m5_success = fallback_success
      remove_target_m5_hi = fallback_hi
      remove_target_m5_lo = fallback_lo
      remove_target_m5_margin = fallback_margin
      remove_target_m5_strength = fallback_strength
    } else if (scenario == "remove-target-only-m10p0") {
      remove_target_m10_seen = 1
      if (preserve != 0 || mode != "target-only" || abs(pull - 1.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 9.99 || mult > 10.01) {
        printf "unexpected remove-target-only-m10p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 9
      }
      remove_target_m10_qacc = qacc
      remove_target_m10_used = fallback_used
      remove_target_m10_recall = fallback_recall
      remove_target_m10_qacc_fb = fallback_qacc
      remove_target_m10_success = fallback_success
      remove_target_m10_hi = fallback_hi
      remove_target_m10_lo = fallback_lo
      remove_target_m10_margin = fallback_margin
      remove_target_m10_strength = fallback_strength
    } else if (scenario == "preserve-projected-pull2") {
      preserve_projected_seen = 1
      if (preserve != 1 || mode != "projected" || abs(pull - 2.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 0.99 || mult > 1.01) {
        printf "unexpected preserve-projected-pull2 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 10
      }
      preserve_projected_qacc = qacc
      preserve_projected_clean = clean_ref
      preserve_projected_fallback = fallback_used
      preserve_projected_primary = primary_recall
    } else if (scenario == "remove-projected-pull2-m1p0") {
      remove_projected_m1_seen = 1
      if (preserve != 0 || mode != "projected" || abs(pull - 2.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 0.99 || mult > 1.01) {
        printf "unexpected remove-projected-pull2-m1p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 11
      }
      remove_projected_m1_qacc = qacc
      remove_projected_m1_used = fallback_used
      remove_projected_m1_recall = fallback_recall
      remove_projected_m1_qacc_fb = fallback_qacc
      remove_projected_m1_success = fallback_success
      remove_projected_m1_hi = fallback_hi
      remove_projected_m1_lo = fallback_lo
      remove_projected_m1_margin = fallback_margin
      remove_projected_m1_strength = fallback_strength
    } else if (scenario == "remove-projected-pull2-m2p0") {
      remove_projected_m2_seen = 1
      if (preserve != 0 || mode != "projected" || abs(pull - 2.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 1.99 || mult > 2.01) {
        printf "unexpected remove-projected-pull2-m2p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 12
      }
      remove_projected_m2_qacc = qacc
      remove_projected_m2_used = fallback_used
      remove_projected_m2_recall = fallback_recall
      remove_projected_m2_qacc_fb = fallback_qacc
      remove_projected_m2_success = fallback_success
      remove_projected_m2_hi = fallback_hi
      remove_projected_m2_lo = fallback_lo
      remove_projected_m2_margin = fallback_margin
      remove_projected_m2_strength = fallback_strength
    } else if (scenario == "remove-projected-pull2-m5p0") {
      remove_projected_m5_seen = 1
      if (preserve != 0 || mode != "projected" || abs(pull - 2.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 4.99 || mult > 5.01) {
        printf "unexpected remove-projected-pull2-m5p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 13
      }
      remove_projected_m5_qacc = qacc
      remove_projected_m5_used = fallback_used
      remove_projected_m5_recall = fallback_recall
      remove_projected_m5_qacc_fb = fallback_qacc
      remove_projected_m5_success = fallback_success
      remove_projected_m5_hi = fallback_hi
      remove_projected_m5_lo = fallback_lo
      remove_projected_m5_margin = fallback_margin
      remove_projected_m5_strength = fallback_strength
    } else if (scenario == "remove-projected-pull2-m10p0") {
      remove_projected_m10_seen = 1
      if (preserve != 0 || mode != "projected" || abs(pull - 2.0) > 0.001 || abs(push - 1.0) > 0.001 || mult < 9.99 || mult > 10.01) {
        printf "unexpected remove-projected-pull2-m10p0 row preserve=%d mode=%s pull=%f push=%f mult=%f\n", preserve, mode, pull, push, mult > "/dev/stderr"
        exit 14
      }
      remove_projected_m10_qacc = qacc
      remove_projected_m10_used = fallback_used
      remove_projected_m10_recall = fallback_recall
      remove_projected_m10_qacc_fb = fallback_qacc
      remove_projected_m10_success = fallback_success
      remove_projected_m10_hi = fallback_hi
      remove_projected_m10_lo = fallback_lo
      remove_projected_m10_margin = fallback_margin
      remove_projected_m10_strength = fallback_strength
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 15
    }
  }
  END {
    if (row_count != 10 ||
        !preserve_target_seen || !remove_target_m1_seen || !remove_target_m2_seen || !remove_target_m5_seen || !remove_target_m10_seen ||
        !preserve_projected_seen || !remove_projected_m1_seen || !remove_projected_m2_seen || !remove_projected_m5_seen || !remove_projected_m10_seen) {
      printf "expected ten strength-diagnostic rows, got %d\n", row_count > "/dev/stderr"
      exit 16
    }

    if (preserve_target_fallback > 0.01 || preserve_projected_fallback > 0.01) {
      printf "expected preserve fallback to remain unused, target=%f projected=%f\n",
        preserve_target_fallback, preserve_projected_fallback > "/dev/stderr"
      exit 17
    }
    if (preserve_target_qacc < 0.75 || preserve_projected_qacc < 0.75) {
      printf "expected preserve rows not to regress catastrophically under preserve-correct corruption, target=%f clean=%f projected=%f clean=%f\n",
        preserve_target_qacc, preserve_target_clean, preserve_projected_qacc, preserve_projected_clean > "/dev/stderr"
      exit 18
    }

    if (remove_target_m1_used <= 0.0 || remove_target_m2_used <= 0.0 || remove_target_m5_used <= 0.0 || remove_target_m10_used <= 0.0 ||
        remove_projected_m1_used <= 0.0 || remove_projected_m2_used <= 0.0 || remove_projected_m5_used <= 0.0 || remove_projected_m10_used <= 0.0) {
      printf "expected fallback-used rate to stay positive in remove-correct rows\n" > "/dev/stderr"
      exit 19
    }
    if (remove_target_m1_recall < 0.99 || remove_target_m2_recall < 0.99 || remove_target_m5_recall < 0.99 || remove_target_m10_recall < 0.99 ||
        remove_projected_m1_recall < 0.99 || remove_projected_m2_recall < 0.99 || remove_projected_m5_recall < 0.99 || remove_projected_m10_recall < 0.99 ||
        remove_target_m1_success < 0.99 || remove_target_m2_success < 0.99 || remove_target_m5_success < 0.99 || remove_target_m10_success < 0.99 ||
        remove_projected_m1_success < 0.99 || remove_projected_m2_success < 0.99 || remove_projected_m5_success < 0.99 || remove_projected_m10_success < 0.99) {
      printf "expected key-shape fallback availability to remain high in remove rows\n" > "/dev/stderr"
      exit 20
    }

    if (remove_target_m1_strength <= 0.0 || remove_target_m2_strength <= 0.0 || remove_target_m5_strength <= 0.0 || remove_target_m10_strength <= 0.0 ||
        remove_projected_m1_strength <= 0.0 || remove_projected_m2_strength <= 0.0 || remove_projected_m5_strength <= 0.0 || remove_projected_m10_strength <= 0.0 ||
        remove_target_m1_qacc_fb <= 0.0 || remove_target_m2_qacc_fb <= 0.0 || remove_target_m5_qacc_fb <= 0.0 || remove_target_m10_qacc_fb <= 0.0 ||
        remove_projected_m1_qacc_fb <= 0.0 || remove_projected_m2_qacc_fb <= 0.0 || remove_projected_m5_qacc_fb <= 0.0 || remove_projected_m10_qacc_fb <= 0.0 ||
        remove_target_m1_hi <= 0.0 || remove_target_m2_hi <= 0.0 || remove_target_m5_hi <= 0.0 || remove_target_m10_hi <= 0.0 ||
        remove_projected_m1_hi <= 0.0 || remove_projected_m2_hi <= 0.0 || remove_projected_m5_hi <= 0.0 || remove_projected_m10_hi <= 0.0 ||
        remove_target_m1_lo <= 0.0 || remove_target_m2_lo <= 0.0 || remove_target_m5_lo <= 0.0 || remove_target_m10_lo <= 0.0 ||
        remove_projected_m1_lo <= 0.0 || remove_projected_m2_lo <= 0.0 || remove_projected_m5_lo <= 0.0 || remove_projected_m10_lo <= 0.0 ||
        remove_target_m1_margin <= 0.0 || remove_target_m2_margin <= 0.0 || remove_target_m5_margin <= 0.0 || remove_target_m10_margin <= 0.0 ||
        remove_projected_m1_margin <= 0.0 || remove_projected_m2_margin <= 0.0 || remove_projected_m5_margin <= 0.0 || remove_projected_m10_margin <= 0.0) {
      printf "expected populated fallback subset metrics in remove rows\n" > "/dev/stderr"
      exit 21
    }

    if (!(remove_target_m2_strength > remove_target_m1_strength + 0.000001 &&
          remove_target_m5_strength > remove_target_m2_strength + 0.000001 &&
          remove_target_m10_strength > remove_target_m5_strength + 0.000001)) {
      printf "expected target-only fallback effective strength to increase with multiplier: %f %f %f %f\n",
        remove_target_m1_strength, remove_target_m2_strength, remove_target_m5_strength, remove_target_m10_strength > "/dev/stderr"
      exit 22
    }
    if (!(remove_projected_m2_strength > remove_projected_m1_strength + 0.000001 &&
          remove_projected_m5_strength > remove_projected_m2_strength + 0.000001 &&
          remove_projected_m10_strength > remove_projected_m5_strength + 0.000001)) {
      printf "expected projected fallback effective strength to increase with multiplier: %f %f %f %f\n",
        remove_projected_m1_strength, remove_projected_m2_strength, remove_projected_m5_strength, remove_projected_m10_strength > "/dev/stderr"
      exit 23
    }

    if (remove_target_m2_qacc < remove_target_m1_qacc - 0.10 ||
        remove_target_m5_qacc < remove_target_m1_qacc - 0.10 ||
        remove_target_m10_qacc < remove_target_m1_qacc - 0.10) {
      printf "expected target-only qacc not to regress catastrophically, m1=%f m2=%f m5=%f m10=%f\n",
        remove_target_m1_qacc, remove_target_m2_qacc, remove_target_m5_qacc, remove_target_m10_qacc > "/dev/stderr"
      exit 24
    }
    if (remove_projected_m2_qacc < remove_projected_m1_qacc - 0.10 ||
        remove_projected_m5_qacc < remove_projected_m1_qacc - 0.10 ||
        remove_projected_m10_qacc < remove_projected_m1_qacc - 0.10) {
      printf "expected projected qacc not to regress catastrophically, m1=%f m2=%f m5=%f m10=%f\n",
        remove_projected_m1_qacc, remove_projected_m2_qacc, remove_projected_m5_qacc, remove_projected_m10_qacc > "/dev/stderr"
      exit 25
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback strength smoke passed"
