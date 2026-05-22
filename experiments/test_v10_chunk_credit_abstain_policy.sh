#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_chunk_credit_abstain_policy.sh" --smoke

POLICY_CSV="$RESULTS_DIR/v10_chunk_credit_abstain_policy_smoke_policy.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("guardrail guardrail_action default_promotion diagnostic_only weak_hint_or_abstain chunk_credit_ready source_safe fallback_not_keyshape_only joint_chunk_source_ready distillation_ready combined_ready noisy_selection_clean joint_source_arm joint_noisy_used joint_fallback_retry_exercised joint_retry_raw_selected chunk_credit_chunk_exact chunk_credit_coherent_wrong keyshape_chunk_gap chunk_credit_top1 source_noisy_selected source_retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 abstain policy column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 abstain policy row has wrong column count", 11)
    if ($idx["guardrail_action"] != "weak-hint-with-abstain") {
      die("expected h10 chunk-credit policy to choose weak-hint with abstain", 3)
    }
    if (($idx["default_promotion"] + 0) != 0 ||
        ($idx["diagnostic_only"] + 0) != 1 ||
        ($idx["weak_hint_or_abstain"] + 0) != 1) {
      die("h10 chunk-credit policy should block default promotion", 4)
    }
    if (($idx["chunk_credit_ready"] + 0) != 1 ||
        ($idx["source_safe"] + 0) != 1 ||
        ($idx["noisy_selection_clean"] + 0) != 1) {
      die("h10 chunk-credit policy should see ready chunk credit and safe source", 5)
    }
    if (($idx["joint_chunk_source_ready"] + 0) != 0 ||
        ($idx["distillation_ready"] + 0) != 0 ||
        ($idx["combined_ready"] + 0) != 0) {
      die("h10 chunk-credit policy should require future fallback/retry and distillation before promotion", 6)
    }
    if ($idx["joint_source_arm"] !~ /^chunk-credit-/ ||
        ($idx["joint_noisy_used"] + 0) <= 0.0 ||
        ($idx["joint_fallback_retry_exercised"] + 0) != 0.0) {
      die("h10 chunk-credit policy should consume noisy-clean but fallback-unexercised joint evidence", 10)
    }
    if (($idx["chunk_credit_coherent_wrong"] + 0) != 0.0 ||
        ($idx["keyshape_chunk_gap"] + 0) > 0.000001 ||
        ($idx["chunk_credit_top1"] + 0) < 0.99) {
      die("h10 chunk-credit policy should preserve strong chunk signal", 7)
    }
    if (($idx["source_noisy_selected"] + 0) != 0.0 ||
        ($idx["source_retry_noisy_selected"] + 0) != 0.0) {
      die("h10 chunk-credit policy should keep noisy selection clean", 8)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 abstain policy", 9)
    }
  }
  END {
    if (rows != 1) die("expected one h10 abstain policy row", 10)
  }
' "$POLICY_CSV"

echo "v10 chunk-credit abstain policy smoke passed"
