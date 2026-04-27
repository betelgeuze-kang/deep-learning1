#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_lowconf_diagnostics_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_lowconf_diagnostics.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_corrupt_preserve_correct route_corrupt_candidate_rate fixture_query_byte_acc route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1 route_lowconf_correct_value_vote_share route_highconf_correct_value_vote_share route_lowconf_unique_values route_highconf_unique_values route_lowconf_vote_entropy route_highconf_vote_entropy route_lowconf_route_margin route_highconf_route_margin route_lowconf_local_margin route_highconf_local_margin route_lowconf_hi_acc route_highconf_hi_acc route_lowconf_lo_acc route_highconf_lo_acc", required, " ")
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
    if (scenario == "preserve-correct" && preserve == 1) {
      preserve_seen = 1
      preserve_low_rate = $idx["route_lowconf_query_rate"] + 0
      preserve_high_rate = $idx["route_highconf_query_rate"] + 0
      preserve_low_qacc = $idx["route_lowconf_qacc"] + 0
      preserve_high_qacc = $idx["route_highconf_qacc"] + 0
      preserve_low_recall = $idx["route_lowconf_candidate_recall"] + 0
      preserve_high_recall = $idx["route_highconf_candidate_recall"] + 0
      preserve_low_entropy = $idx["route_lowconf_vote_entropy"] + 0
      preserve_high_entropy = $idx["route_highconf_vote_entropy"] + 0
      preserve_low_share = $idx["route_lowconf_correct_value_vote_share"] + 0
      preserve_high_share = $idx["route_highconf_correct_value_vote_share"] + 0
    } else if (scenario == "remove-correct" && preserve == 0) {
      remove_seen = 1
      remove_low_recall = $idx["route_lowconf_candidate_recall"] + 0
      remove_high_recall = $idx["route_highconf_candidate_recall"] + 0
      remove_low_qacc = $idx["route_lowconf_qacc"] + 0
      remove_high_qacc = $idx["route_highconf_qacc"] + 0
    }
  }
  END {
    if (row_count != 2 || !preserve_seen || !remove_seen) {
      printf "expected preserve-correct and remove-correct rows, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    if (preserve_low_rate <= 0.0 || preserve_high_rate <= 0.0) {
      printf "expected preserve-correct low/high split, low=%f high=%f\n",
        preserve_low_rate, preserve_high_rate > "/dev/stderr"
      exit 4
    }
    if (preserve_high_qacc <= preserve_low_qacc) {
      printf "expected high-confidence qacc to exceed low-confidence qacc, low=%f high=%f\n",
        preserve_low_qacc, preserve_high_qacc > "/dev/stderr"
      exit 5
    }
    if (preserve_low_recall < 0.99 || preserve_high_recall < 0.99) {
      printf "expected preserve-correct recall to stay high, low=%f high=%f\n",
        preserve_low_recall, preserve_high_recall > "/dev/stderr"
      exit 6
    }
    if (remove_low_recall >= preserve_low_recall || remove_high_recall >= preserve_high_recall) {
      printf "expected remove-correct recall below preserve-correct recall, preserve=(%f,%f) remove=(%f,%f)\n",
        preserve_low_recall, preserve_high_recall, remove_low_recall, remove_high_recall > "/dev/stderr"
      exit 7
    }
    if (preserve_low_entropy <= preserve_high_entropy &&
        preserve_low_share >= preserve_high_share &&
        preserve_low_qacc >= preserve_high_qacc) {
      printf "expected at least one low-confidence explanatory signal\n" > "/dev/stderr"
      exit 8
    }
    if (remove_low_qacc > preserve_low_qacc + 0.25 &&
        remove_high_qacc > preserve_high_qacc + 0.25) {
      printf "expected remove-correct not to outperform preserve-correct unexpectedly\n" > "/dev/stderr"
      exit 9
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code low-confidence diagnostics smoke passed"
