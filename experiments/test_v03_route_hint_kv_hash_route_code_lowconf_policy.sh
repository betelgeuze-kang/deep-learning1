#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_lowconf_policy_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_lowconf_policy.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_corrupt_preserve_correct route_corrupt_candidate_rate route_lowconf_policy route_lowconf_weak_scale fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_candidate_corrupt_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1 route_lowconf_policy_none_rate route_lowconf_policy_weak_vote_rate route_lowconf_policy_aggregate_rate route_lowconf_effective_strength_mean route_highconf_effective_strength_mean route_lowconf_wrong_strength_mean route_highconf_wrong_strength_mean route_strength_mean", required, " ")
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
    policy = $idx["route_lowconf_policy"]
    weak_scale = $idx["route_lowconf_weak_scale"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    damage = $idx["damage_vs_clean"] + 0
    low_rate = $idx["route_lowconf_query_rate"] + 0
    high_rate = $idx["route_highconf_query_rate"] + 0
    low_qacc = $idx["route_lowconf_qacc"] + 0
    high_qacc = $idx["route_highconf_qacc"] + 0
    low_recall = $idx["route_lowconf_candidate_recall"] + 0
    high_recall = $idx["route_highconf_candidate_recall"] + 0
    low_top1 = $idx["route_lowconf_top1"] + 0
    high_top1 = $idx["route_highconf_top1"] + 0
    none_rate = $idx["route_lowconf_policy_none_rate"] + 0
    weak_rate = $idx["route_lowconf_policy_weak_vote_rate"] + 0
    agg_rate = $idx["route_lowconf_policy_aggregate_rate"] + 0
    low_eff = $idx["route_lowconf_effective_strength_mean"] + 0
    high_eff = $idx["route_highconf_effective_strength_mean"] + 0

    if (corrupt_rate < 0.24 || corrupt_rate > 0.26) {
      printf "expected smoke corruption 0.25, got %f for %s\n", corrupt_rate, scenario > "/dev/stderr"
      exit 3
    }
    if (weak_scale < 0.49 || weak_scale > 0.51) {
      printf "expected weak scale 0.5, got %f for %s\n", weak_scale, scenario > "/dev/stderr"
      exit 4
    }

    if (scenario == "preserve-aggregate") {
      preserve_aggregate_seen = 1
      if (preserve != 1 || policy != "aggregate") {
        printf "expected preserve-aggregate policy row, got preserve=%d policy=%s\n", preserve, policy > "/dev/stderr"
        exit 5
      }
      preserve_aggregate_low_rate = low_rate
      preserve_aggregate_high_rate = high_rate
      preserve_aggregate_low_qacc = low_qacc
      preserve_aggregate_high_qacc = high_qacc
      preserve_aggregate_low_recall = low_recall
      preserve_aggregate_high_recall = high_recall
      preserve_aggregate_low_top1 = low_top1
      preserve_aggregate_high_top1 = high_top1
      preserve_aggregate_agg_rate = agg_rate
      preserve_aggregate_none_rate = none_rate
      preserve_aggregate_weak_rate = weak_rate
      preserve_aggregate_low_eff = low_eff
      preserve_aggregate_high_eff = high_eff
      preserve_aggregate_damage = damage
    } else if (scenario == "preserve-none") {
      preserve_none_seen = 1
      if (preserve != 1 || policy != "none") {
        printf "expected preserve-none policy row, got preserve=%d policy=%s\n", preserve, policy > "/dev/stderr"
        exit 6
      }
      preserve_none_damage = damage
      preserve_none_low_eff = low_eff
      preserve_none_high_eff = high_eff
      preserve_none_none_rate = none_rate
      preserve_none_agg_rate = agg_rate
      preserve_none_weak_rate = weak_rate
    } else if (scenario == "preserve-weak-vote") {
      preserve_weak_seen = 1
      if (preserve != 1 || policy != "weak-vote") {
        printf "expected preserve-weak-vote policy row, got preserve=%d policy=%s\n", preserve, policy > "/dev/stderr"
        exit 7
      }
      preserve_weak_damage = damage
      preserve_weak_low_eff = low_eff
      preserve_weak_high_eff = high_eff
      preserve_weak_none_rate = none_rate
      preserve_weak_agg_rate = agg_rate
      preserve_weak_weak_rate = weak_rate
    } else if (scenario == "remove-aggregate") {
      remove_aggregate_seen = 1
      if (preserve != 0 || policy != "aggregate") {
        printf "expected remove-aggregate policy row, got preserve=%d policy=%s\n", preserve, policy > "/dev/stderr"
        exit 8
      }
      remove_aggregate_low_rate = low_rate
      remove_aggregate_high_rate = high_rate
      remove_aggregate_low_qacc = low_qacc
      remove_aggregate_high_qacc = high_qacc
      remove_aggregate_low_recall = low_recall
      remove_aggregate_high_recall = high_recall
      remove_aggregate_low_top1 = low_top1
      remove_aggregate_high_top1 = high_top1
      remove_aggregate_agg_rate = agg_rate
      remove_aggregate_none_rate = none_rate
      remove_aggregate_weak_rate = weak_rate
      remove_aggregate_low_eff = low_eff
      remove_aggregate_high_eff = high_eff
      remove_aggregate_damage = damage
    } else if (scenario == "remove-none") {
      remove_none_seen = 1
      if (preserve != 0 || policy != "none") {
        printf "expected remove-none policy row, got preserve=%d policy=%s\n", preserve, policy > "/dev/stderr"
        exit 9
      }
      remove_none_damage = damage
      remove_none_low_eff = low_eff
      remove_none_high_eff = high_eff
      remove_none_none_rate = none_rate
      remove_none_agg_rate = agg_rate
      remove_none_weak_rate = weak_rate
    } else if (scenario == "remove-weak-vote") {
      remove_weak_seen = 1
      if (preserve != 0 || policy != "weak-vote") {
        printf "expected remove-weak-vote policy row, got preserve=%d policy=%s\n", preserve, policy > "/dev/stderr"
        exit 10
      }
      remove_weak_damage = damage
      remove_weak_low_eff = low_eff
      remove_weak_high_eff = high_eff
      remove_weak_none_rate = none_rate
      remove_weak_agg_rate = agg_rate
      remove_weak_weak_rate = weak_rate
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 11
    }
  }
  END {
    if (row_count != 6 || !preserve_aggregate_seen || !preserve_none_seen || !preserve_weak_seen || !remove_aggregate_seen || !remove_none_seen || !remove_weak_seen) {
      printf "expected preserve/remove aggregate/none/weak-vote rows, got %d\n", row_count > "/dev/stderr"
      exit 12
    }

    if (preserve_aggregate_agg_rate < preserve_aggregate_low_rate - 0.01 ||
        preserve_aggregate_none_rate > 0.01 ||
        preserve_aggregate_weak_rate > 0.01) {
      printf "expected preserve-aggregate to select aggregate policy, got agg=%f none=%f weak=%f low=%f\n",
        preserve_aggregate_agg_rate, preserve_aggregate_none_rate, preserve_aggregate_weak_rate, preserve_aggregate_low_rate > "/dev/stderr"
      exit 13
    }
    if (preserve_none_none_rate < preserve_aggregate_low_rate - 0.01 ||
        preserve_none_agg_rate > 0.01 ||
        preserve_none_weak_rate > 0.01) {
      printf "expected preserve-none to select none policy, got agg=%f none=%f weak=%f low=%f\n",
        preserve_none_agg_rate, preserve_none_none_rate, preserve_none_weak_rate, preserve_aggregate_low_rate > "/dev/stderr"
      exit 14
    }
    if (preserve_weak_weak_rate < preserve_aggregate_low_rate - 0.01 ||
        preserve_weak_agg_rate > 0.01 ||
        preserve_weak_none_rate > 0.01) {
      printf "expected preserve-weak-vote to select weak-vote policy, got agg=%f none=%f weak=%f low=%f\n",
        preserve_weak_agg_rate, preserve_weak_none_rate, preserve_weak_weak_rate, preserve_aggregate_low_rate > "/dev/stderr"
      exit 15
    }
    if (remove_aggregate_agg_rate < remove_aggregate_low_rate - 0.01 ||
        remove_aggregate_none_rate > 0.01 ||
        remove_aggregate_weak_rate > 0.01) {
      printf "expected remove-aggregate to select aggregate policy, got agg=%f none=%f weak=%f low=%f\n",
        remove_aggregate_agg_rate, remove_aggregate_none_rate, remove_aggregate_weak_rate, remove_aggregate_low_rate > "/dev/stderr"
      exit 16
    }
    if (remove_none_none_rate < remove_aggregate_low_rate - 0.01 ||
        remove_none_agg_rate > 0.01 ||
        remove_none_weak_rate > 0.01) {
      printf "expected remove-none to select none policy, got agg=%f none=%f weak=%f low=%f\n",
        remove_none_agg_rate, remove_none_none_rate, remove_none_weak_rate, remove_aggregate_low_rate > "/dev/stderr"
      exit 17
    }
    if (remove_weak_weak_rate < remove_aggregate_low_rate - 0.01 ||
        remove_weak_agg_rate > 0.01 ||
        remove_weak_none_rate > 0.01) {
      printf "expected remove-weak-vote to select weak-vote policy, got agg=%f none=%f weak=%f low=%f\n",
        remove_weak_agg_rate, remove_weak_none_rate, remove_weak_weak_rate, remove_aggregate_low_rate > "/dev/stderr"
      exit 18
    }

    if (preserve_aggregate_low_rate <= 0.0 || preserve_aggregate_high_rate <= 0.0 ||
        preserve_aggregate_low_rate >= preserve_aggregate_high_rate) {
      printf "expected preserve-aggregate low/high split, low=%f high=%f\n",
        preserve_aggregate_low_rate, preserve_aggregate_high_rate > "/dev/stderr"
      exit 19
    }
    if (preserve_aggregate_low_qacc >= preserve_aggregate_high_qacc) {
      printf "expected preserve-aggregate low/high qacc split, low=%f high=%f\n",
        preserve_aggregate_low_qacc, preserve_aggregate_high_qacc > "/dev/stderr"
      exit 20
    }
    if (preserve_aggregate_low_top1 >= preserve_aggregate_high_top1) {
      printf "expected preserve-aggregate low/high top1 split, low=%f high=%f\n",
        preserve_aggregate_low_top1, preserve_aggregate_high_top1 > "/dev/stderr"
      exit 21
    }
    if (preserve_aggregate_high_eff <= preserve_aggregate_low_eff) {
      printf "expected high-confidence effective strength to exceed low-confidence strength, low=%f high=%f\n",
        preserve_aggregate_low_eff, preserve_aggregate_high_eff > "/dev/stderr"
      exit 22
    }
    if (preserve_aggregate_low_recall < 0.99 || preserve_aggregate_high_recall < 0.99) {
      printf "expected preserve-aggregate candidate recall to stay high, low=%f high=%f\n",
        preserve_aggregate_low_recall, preserve_aggregate_high_recall > "/dev/stderr"
      exit 23
    }
    if (remove_aggregate_low_recall >= preserve_aggregate_low_recall) {
      printf "expected remove-aggregate low-confidence recall below preserve-aggregate, preserve=%f remove=%f\n",
        preserve_aggregate_low_recall, remove_aggregate_low_recall > "/dev/stderr"
      exit 24
    }
    if (remove_aggregate_high_recall >= preserve_aggregate_high_recall) {
      printf "expected remove-aggregate high-confidence recall below preserve-aggregate, preserve=%f remove=%f\n",
        preserve_aggregate_high_recall, remove_aggregate_high_recall > "/dev/stderr"
      exit 25
    }

    if (!(preserve_aggregate_low_eff > preserve_weak_low_eff && preserve_weak_low_eff > preserve_none_low_eff)) {
      printf "expected preserve policy effective strengths to order aggregate > weak-vote > none, agg=%f weak=%f none=%f\n",
        preserve_aggregate_low_eff, preserve_weak_low_eff, preserve_none_low_eff > "/dev/stderr"
      exit 26
    }
    if (remove_aggregate_low_rate > 0.01) {
      if (!(remove_aggregate_low_eff > remove_weak_low_eff && remove_weak_low_eff > remove_none_low_eff)) {
        printf "expected remove policy effective strengths to order aggregate > weak-vote > none when low-confidence exists, agg=%f weak=%f none=%f\n",
          remove_aggregate_low_eff, remove_weak_low_eff, remove_none_low_eff > "/dev/stderr"
        exit 27
      }
    } else if (remove_aggregate_low_eff > 0.01 || remove_none_low_eff > 0.01 || remove_weak_low_eff > 0.01) {
      printf "expected remove low-confidence strengths to stay zero when no low-confidence queries exist, agg=%f weak=%f none=%f\n",
        remove_aggregate_low_eff, remove_weak_low_eff, remove_none_low_eff > "/dev/stderr"
      exit 27
    }

    if (preserve_none_damage > preserve_aggregate_damage + 0.15 ||
        preserve_weak_damage > preserve_aggregate_damage + 0.15 ||
        remove_none_damage > remove_aggregate_damage + 0.15 ||
        remove_weak_damage > remove_aggregate_damage + 0.15) {
      printf "expected none/weak-vote not to be catastrophically worse than aggregate, preserve=(%f,%f,%f) remove=(%f,%f,%f)\n",
        preserve_aggregate_damage, preserve_none_damage, preserve_weak_damage,
        remove_aggregate_damage, remove_none_damage, remove_weak_damage > "/dev/stderr"
      exit 28
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code low-confidence policy smoke passed"
