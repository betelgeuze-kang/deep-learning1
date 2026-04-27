#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_source_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_source.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_corrupt_preserve_correct route_corrupt_candidate_rate route_fallback_source fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_primary_recall route_primary_lowconf_rate route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_abstain_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1", required, " ")
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
    source = $idx["route_fallback_source"]
    qacc = $idx["fixture_query_byte_acc"] + 0
    primary_recall = $idx["route_primary_recall"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    low_rate = $idx["route_lowconf_query_rate"] + 0
    high_rate = $idx["route_highconf_query_rate"] + 0
    low_recall = $idx["route_lowconf_candidate_recall"] + 0
    high_recall = $idx["route_highconf_candidate_recall"] + 0
    low_top1 = $idx["route_lowconf_top1"] + 0
    high_top1 = $idx["route_highconf_top1"] + 0

    if (scenario == "preserve-off") {
      preserve_off_seen = 1
      preserve_off_qacc = qacc
      preserve_off_primary = primary_recall
      preserve_off_fallback = fallback_used
      preserve_off_low = low_rate
      preserve_off_high = high_rate
      preserve_off_low_recall = low_recall
      preserve_off_low_top1 = low_top1
    } else if (scenario == "preserve-key-shape") {
      preserve_shape_seen = 1
      preserve_shape_qacc = qacc
      preserve_shape_primary = primary_recall
      preserve_shape_fallback = fallback_used
    } else if (scenario == "remove-off") {
      remove_off_seen = 1
      remove_off_qacc = qacc
      remove_off_primary = primary_recall
      remove_off_fallback = fallback_used
      remove_off_high_recall = high_recall
      remove_off_high_top1 = high_top1
    } else if (scenario == "remove-key-shape") {
      remove_shape_seen = 1
      remove_shape_qacc = qacc
      remove_shape_primary = primary_recall
      remove_shape_fallback = fallback_used
      remove_shape_recall = fallback_recall
      remove_shape_fallback_qacc = fallback_qacc
      remove_shape_success = fallback_success
      remove_shape_high_recall = high_recall
      remove_shape_high_top1 = high_top1
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 3
    }

    if (source != "off" && source != "key-shape") {
      printf "unexpected fallback source in smoke: %s\n", source > "/dev/stderr"
      exit 4
    }
    if (preserve != 0 && preserve != 1) {
      printf "invalid preserve flag: %d\n", preserve > "/dev/stderr"
      exit 5
    }
  }
  END {
    if (row_count != 4 || !preserve_off_seen || !preserve_shape_seen || !remove_off_seen || !remove_shape_seen) {
      printf "expected four smoke rows, got %d\n", row_count > "/dev/stderr"
      exit 6
    }
    if (preserve_off_primary < 0.99 || preserve_shape_primary < 0.99) {
      printf "expected preserve primary recall to stay high, off=%f shape=%f\n", preserve_off_primary, preserve_shape_primary > "/dev/stderr"
      exit 7
    }
    if (preserve_off_fallback > 0.01 || preserve_shape_fallback > 0.01) {
      printf "expected preserve fallback to remain unused when primary recall is present, off=%f shape=%f\n", preserve_off_fallback, preserve_shape_fallback > "/dev/stderr"
      exit 8
    }
    if (preserve_shape_qacc < preserve_off_qacc - 0.05) {
      printf "expected preserve key-shape fallback not to regress materially, off=%f shape=%f\n", preserve_off_qacc, preserve_shape_qacc > "/dev/stderr"
      exit 9
    }
    if (preserve_off_low <= 0.0 || preserve_off_high <= 0.0 ||
        preserve_off_low_recall < 0.99 || preserve_off_low_top1 > 0.01) {
      printf "expected preserve-off to keep the h4-5m aggregation/ranking split, low=%f high=%f low_recall=%f low_top1=%f\n",
        preserve_off_low, preserve_off_high, preserve_off_low_recall, preserve_off_low_top1 > "/dev/stderr"
      exit 10
    }
    if (remove_off_primary >= preserve_off_primary) {
      printf "expected remove-off primary recall below preserve, remove=%f preserve=%f\n", remove_off_primary, preserve_off_primary > "/dev/stderr"
      exit 11
    }
    if (remove_shape_fallback <= 0.0 || remove_shape_recall < 0.99 ||
        remove_shape_success < 0.99) {
      printf "expected key-shape fallback to recover missing candidates, used=%f recall=%f success=%f fallback_qacc=%f\n",
        remove_shape_fallback, remove_shape_recall, remove_shape_success, remove_shape_fallback_qacc > "/dev/stderr"
      exit 12
    }
    if (remove_shape_qacc <= remove_off_qacc) {
      printf "expected remove key-shape fallback qacc to improve over no fallback, off=%f shape=%f\n", remove_off_qacc, remove_shape_qacc > "/dev/stderr"
      exit 13
    }
    if (remove_shape_high_recall <= remove_off_high_recall ||
        remove_shape_high_top1 <= remove_off_high_top1) {
      printf "expected remove key-shape fallback to improve high-confidence recall/top1, recall %f->%f top1 %f->%f\n",
        remove_off_high_recall, remove_shape_high_recall, remove_off_high_top1, remove_shape_high_top1 > "/dev/stderr"
      exit 14
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback source smoke passed"
