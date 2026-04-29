#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_projected_delta_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_projected_delta.sh" --smoke

awk -F, '
  function abs(x) {
    return (x < 0 ? -x : x)
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_corrupt_preserve_correct route_corrupt_candidate_rate route_delta_mode route_pull_scale route_push_scale route_fallback_source fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_route_margin_mean route_fallback_effective_strength_mean route_lowconf_query_rate route_highconf_query_rate", required, " ")
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
    mode = $idx["route_delta_mode"]
    pull = $idx["route_pull_scale"] + 0
    push = $idx["route_push_scale"] + 0
    source = $idx["route_fallback_source"]
    qacc = $idx["fixture_query_byte_acc"] + 0
    clean_ref = $idx["clean_reference_qacc"] + 0
    damage = $idx["damage_vs_clean"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    fallback_hi = $idx["route_fallback_hi_acc"] + 0
    fallback_lo = $idx["route_fallback_lo_acc"] + 0
    fallback_margin = $idx["route_fallback_route_margin_mean"] + 0
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0
    low_rate = $idx["route_lowconf_query_rate"] + 0
    high_rate = $idx["route_highconf_query_rate"] + 0

    if (corrupt_rate < 0.24 || corrupt_rate > 0.26) {
      printf "expected smoke corruption 0.25, got %f for %s\n", corrupt_rate, scenario > "/dev/stderr"
      exit 3
    }

    if (scenario == "preserve-off-target-only") {
      preserve_target_seen = 1
      preserve_target_qacc = qacc
      preserve_target_clean = clean_ref
      preserve_target_damage = damage
      preserve_target_fallback = fallback_used
      preserve_target_low = low_rate
      preserve_target_high = high_rate
      if (preserve != 1 || mode != "target-only" || source != "off") {
        printf "unexpected preserve-target-only row preserve=%d mode=%s source=%s\n", preserve, mode, source > "/dev/stderr"
        exit 4
      }
    } else if (scenario == "preserve-off-projected") {
      preserve_projected_seen = 1
      preserve_projected_qacc = qacc
      preserve_projected_clean = clean_ref
      preserve_projected_damage = damage
      preserve_projected_fallback = fallback_used
      preserve_projected_low = low_rate
      preserve_projected_high = high_rate
      if (preserve != 1 || mode != "projected" || source != "off" || pull < 0.99 || pull > 1.01 || push < 0.99 || push > 1.01) {
        printf "unexpected preserve-projected row preserve=%d mode=%s source=%s pull=%f push=%f\n", preserve, mode, source, pull, push > "/dev/stderr"
        exit 5
      }
    } else if (scenario == "preserve-off-projected-pull2") {
      preserve_projected_seen = 1
      preserve_projected_p2_seen = 1
      preserve_projected_p2_qacc = qacc
      preserve_projected_p2_clean = clean_ref
      preserve_projected_p2_damage = damage
      preserve_projected_p2_fallback = fallback_used
      preserve_projected_p2_low = low_rate
      preserve_projected_p2_high = high_rate
      if (preserve != 1 || mode != "projected" || source != "off" || pull < 1.99 || push < 0.99 || push > 1.01) {
        printf "unexpected preserve-projected row preserve=%d mode=%s source=%s pull=%f push=%f\n", preserve, mode, source, pull, push > "/dev/stderr"
        exit 5
      }
    } else if (scenario == "remove-key-shape-target-only") {
      remove_target_seen = 1
      remove_target_qacc = qacc
      remove_target_clean = clean_ref
      remove_target_damage = damage
      remove_target_low = low_rate
      remove_target_high = high_rate
      remove_target_fallback = fallback_used
      remove_target_recall = fallback_recall
      remove_target_fallback_qacc = fallback_qacc
      remove_target_success = fallback_success
      remove_target_hi = fallback_hi
      remove_target_lo = fallback_lo
      remove_target_margin = fallback_margin
      remove_target_strength = fallback_strength
      if (preserve != 0 || mode != "target-only" || source != "key-shape") {
        printf "unexpected remove-target-only row preserve=%d mode=%s source=%s\n", preserve, mode, source > "/dev/stderr"
        exit 6
      }
    } else if (scenario == "remove-key-shape-projected") {
      remove_projected_seen = 1
      remove_projected_qacc = qacc
      remove_projected_clean = clean_ref
      remove_projected_damage = damage
      remove_projected_low = low_rate
      remove_projected_high = high_rate
      remove_projected_fallback = fallback_used
      remove_projected_recall = fallback_recall
      remove_projected_fallback_qacc = fallback_qacc
      remove_projected_success = fallback_success
      remove_projected_hi = fallback_hi
      remove_projected_lo = fallback_lo
      remove_projected_margin = fallback_margin
      remove_projected_strength = fallback_strength
      if (preserve != 0 || mode != "projected" || source != "key-shape" || pull < 0.99 || pull > 1.01 || push < 0.99 || push > 1.01) {
        printf "unexpected remove-projected row preserve=%d mode=%s source=%s pull=%f push=%f\n", preserve, mode, source, pull, push > "/dev/stderr"
        exit 7
      }
    } else if (scenario == "remove-key-shape-projected-pull2") {
      remove_projected_p2_seen = 1
      remove_projected_p2_qacc = qacc
      remove_projected_p2_clean = clean_ref
      remove_projected_p2_damage = damage
      remove_projected_p2_low = low_rate
      remove_projected_p2_high = high_rate
      remove_projected_p2_fallback = fallback_used
      remove_projected_p2_recall = fallback_recall
      remove_projected_p2_fallback_qacc = fallback_qacc
      remove_projected_p2_success = fallback_success
      remove_projected_p2_hi = fallback_hi
      remove_projected_p2_lo = fallback_lo
      remove_projected_p2_margin = fallback_margin
      remove_projected_p2_strength = fallback_strength
      if (preserve != 0 || mode != "projected" || source != "key-shape" || pull < 1.99 || push < 0.99 || push > 1.01) {
        printf "unexpected remove-projected row preserve=%d mode=%s source=%s pull=%f push=%f\n", preserve, mode, source, pull, push > "/dev/stderr"
        exit 7
      }
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 8
    }
  }
  END {
    if (row_count != 6 ||
        !preserve_target_seen || !preserve_projected_seen || !preserve_projected_p2_seen ||
        !remove_target_seen || !remove_projected_seen || !remove_projected_p2_seen) {
      printf "expected six projected delta smoke rows, got %d\n", row_count > "/dev/stderr"
      exit 9
    }
    if (preserve_target_fallback > 0.01 || preserve_projected_fallback > 0.01 || preserve_projected_p2_fallback > 0.01) {
      printf "expected preserve fallback to remain unused, target=%f projected=%f projected_p2=%f\n", preserve_target_fallback, preserve_projected_fallback, preserve_projected_p2_fallback > "/dev/stderr"
      exit 10
    }
    if (preserve_projected_qacc < preserve_target_qacc - 0.10 ||
        preserve_projected_p2_qacc < preserve_target_qacc - 0.10 ||
        abs(preserve_projected_qacc - preserve_target_qacc) > 0.10 ||
        abs(preserve_projected_p2_qacc - preserve_target_qacc) > 0.10) {
      printf "expected projected preserve qacc to stay near target-only, target=%f projected=%f projected_p2=%f\n",
        preserve_target_qacc, preserve_projected_qacc, preserve_projected_p2_qacc > "/dev/stderr"
      exit 11
    }
    if (preserve_target_clean <= 0.0 || preserve_projected_clean <= 0.0 || preserve_projected_p2_clean <= 0.0 ||
        preserve_target_damage < 0.0 || preserve_projected_damage < 0.0 || preserve_projected_p2_damage < 0.0) {
      printf "expected preserve clean-reference and damage values to be populated\n" > "/dev/stderr"
      exit 12
    }
    if (preserve_target_low <= 0.0 || preserve_target_high <= 0.0 ||
        preserve_projected_low <= 0.0 || preserve_projected_high <= 0.0 ||
        preserve_projected_p2_low <= 0.0 || preserve_projected_p2_high <= 0.0) {
      printf "expected preserve low/high confidence split in all modes\n" > "/dev/stderr"
      exit 13
    }
    if (remove_target_low <= 0.0 || remove_target_high <= 0.0 ||
        remove_projected_low <= 0.0 || remove_projected_high <= 0.0 ||
        remove_projected_p2_low <= 0.0 || remove_projected_p2_high <= 0.0) {
      printf "expected remove low/high confidence split in all modes\n" > "/dev/stderr"
      exit 14
    }
    if (remove_target_fallback <= 0.0 || remove_projected_fallback <= 0.0 || remove_projected_p2_fallback <= 0.0 ||
        remove_target_recall < 0.99 || remove_projected_recall < 0.99 || remove_projected_p2_recall < 0.99 ||
        remove_target_success < 0.99 || remove_projected_success < 0.99 || remove_projected_p2_success < 0.99) {
      printf "expected fallback recovery in all remove rows, target used=%f recall=%f success=%f projected used=%f recall=%f success=%f projected_p2 used=%f recall=%f success=%f\n",
        remove_target_fallback, remove_target_recall, remove_target_success,
        remove_projected_fallback, remove_projected_recall, remove_projected_success,
        remove_projected_p2_fallback, remove_projected_p2_recall, remove_projected_p2_success > "/dev/stderr"
      exit 15
    }
    if (remove_projected_qacc < remove_target_qacc - 0.10 ||
        remove_projected_p2_qacc < remove_target_qacc - 0.10) {
      printf "expected projected remove qacc not to regress catastrophically, target=%f projected=%f projected_p2=%f\n",
        remove_target_qacc, remove_projected_qacc, remove_projected_p2_qacc > "/dev/stderr"
      exit 16
    }
    if (remove_target_fallback_qacc <= 0.0 || remove_projected_fallback_qacc <= 0.0 || remove_projected_p2_fallback_qacc <= 0.0 ||
        remove_target_hi <= 0.0 || remove_projected_hi <= 0.0 || remove_projected_p2_hi <= 0.0 ||
        remove_target_lo <= 0.0 || remove_projected_lo <= 0.0 || remove_projected_p2_lo <= 0.0 ||
        remove_target_margin <= 0.0 || remove_projected_margin <= 0.0 || remove_projected_p2_margin <= 0.0 ||
        remove_target_strength <= 0.0 || remove_projected_strength <= 0.0 || remove_projected_p2_strength <= 0.0) {
      printf "expected populated fallback subset metrics, target qacc=%f hi=%f lo=%f margin=%f strength=%f projected qacc=%f hi=%f lo=%f margin=%f strength=%f projected_p2 qacc=%f hi=%f lo=%f margin=%f strength=%f\n",
        remove_target_fallback_qacc, remove_target_hi, remove_target_lo, remove_target_margin, remove_target_strength,
        remove_projected_fallback_qacc, remove_projected_hi, remove_projected_lo, remove_projected_margin, remove_projected_strength,
        remove_projected_p2_fallback_qacc, remove_projected_p2_hi, remove_projected_p2_lo, remove_projected_p2_margin, remove_projected_p2_strength > "/dev/stderr"
      exit 17
    }
    printf "projected preserve baseline qacc: target=%f projected=%f projected_p2=%f\n",
      preserve_target_qacc, preserve_projected_qacc, preserve_projected_p2_qacc
    printf "projected remove baseline qacc: target=%f projected=%f projected_p2=%f\n",
      remove_target_qacc, remove_projected_qacc, remove_projected_p2_qacc
    printf "projected remove fallback subset: target=(%f,%f,%f,%f) projected=(%f,%f,%f,%f) projected_p2=(%f,%f,%f,%f)\n",
      remove_target_fallback_qacc, remove_target_hi, remove_target_lo, remove_target_strength,
      remove_projected_fallback_qacc, remove_projected_hi, remove_projected_lo, remove_projected_strength,
      remove_projected_p2_fallback_qacc, remove_projected_p2_hi, remove_projected_p2_lo, remove_projected_p2_strength
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code projected delta smoke passed"
