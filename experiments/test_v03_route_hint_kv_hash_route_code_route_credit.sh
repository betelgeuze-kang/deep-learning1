#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_route_credit_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_route_credit.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_credit_learning route_plasticity_ledger fixture_query_byte_acc route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_plasticity_ledger_size route_plasticity_ledger_mean_abs_credit", required, " ")
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
    learning = $idx["route_credit_learning"] + 0
    ledger = $idx["route_plasticity_ledger"] + 0
    correct_mean = $idx["route_credit_correct_mean"] + 0
    wrong_mean = $idx["route_credit_wrong_mean"] + 0
    gap = $idx["route_credit_gap"] + 0
    rewarded = $idx["route_credit_rewarded_rate"] + 0
    slashed = $idx["route_credit_slashed_rate"] + 0
    top1 = $idx["route_credit_top1_rate"] + 0
    qacc = $idx["route_credit_qacc"] + 0
    ledger_size = $idx["route_plasticity_ledger_size"] + 0
    ledger_mean_abs = $idx["route_plasticity_ledger_mean_abs_credit"] + 0

    if (scenario == "credit_off") {
      off_seen = 1
      if (learning != 0 || ledger != 0 || ledger_size != 0 || ledger_mean_abs != 0) {
        printf "expected credit_off disabled ledger, learning=%d ledger=%d size=%f mean_abs=%f\n",
          learning, ledger, ledger_size, ledger_mean_abs > "/dev/stderr"
        exit 3
      }
    } else if (scenario == "credit_on") {
      on_seen = 1
      if (learning != 1 || ledger != 1) {
        printf "expected credit_on learning=1 ledger=1, got learning=%d ledger=%d\n",
          learning, ledger > "/dev/stderr"
        exit 4
      }
      if (!(gap > 0.0 && correct_mean > wrong_mean)) {
        printf "expected positive route-credit separation, correct=%f wrong=%f gap=%f\n",
          correct_mean, wrong_mean, gap > "/dev/stderr"
        exit 5
      }
      if (rewarded <= 0.0 || slashed <= 0.0) {
        printf "expected both rewarded and slashed credit rates, rewarded=%f slashed=%f\n",
          rewarded, slashed > "/dev/stderr"
        exit 6
      }
      if (top1 < 0.0 || top1 > 1.0 || qacc <= 0.0) {
        printf "expected bounded credit top1 and populated qacc, top1=%f qacc=%f\n",
          top1, qacc > "/dev/stderr"
        exit 7
      }
      if (ledger_size <= 0.0 || ledger_mean_abs <= 0.0) {
        printf "expected populated route-plasticity ledger, size=%f mean_abs=%f\n",
          ledger_size, ledger_mean_abs > "/dev/stderr"
        exit 10
      }
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 8
    }
  }
  END {
    if (row_count != 2 || !off_seen || !on_seen) {
      printf "expected credit_off and credit_on rows, got %d\n", row_count > "/dev/stderr"
      exit 9
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code credit smoke passed"
