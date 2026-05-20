#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v06_route_memory_span_adaptive_guardrail"
SOURCE_PREFIX="v06_route_memory_span_first_guardrail_degradation"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_adaptive_guardrail_smoke"
  SOURCE_PREFIX="v06_route_memory_span_first_guardrail_degradation_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

SOURCE_POLICY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_policy.csv"
SOURCE_AGG_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_aggregate.csv"

if [[ ! -s "$SOURCE_POLICY_CSV" || ! -s "$SOURCE_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_span_first_guardrail_degradation.sh" "${RUN_ARGS[@]}" >/dev/null
fi

DECISION_CSV="$RESULTS_DIR/${PREFIX}_decisions.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

awk -F, -v decision_csv="$DECISION_CSV" -v agg_csv="$AGG_CSV" '
  function group_key(degradation, key_count, seed) {
    return degradation ":" key_count ":" seed
  }
  function add_policy(label, weight) {
    policy_count++
    policy_label[policy_count] = label
    policy_weight[policy_count] = weight
  }
  function emit_decision(group, label, weight, selected, accepted, utility, span_gain, qacc_loss) {
    split(group, parts, ":")
    if (selected == span_policy[group]) {
      selected_qacc = span_qacc[group]
      selected_span = span_span[group]
    } else {
      selected_qacc = qacc_qacc[group]
      selected_span = qacc_span[group]
    }
    printf "%s,%d,%d,%s,%.6f,%s,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      parts[1],
      parts[2],
      parts[3],
      label,
      weight,
      selected,
      accepted,
      qacc_policy[group],
      span_policy[group],
      selected_qacc,
      selected_span,
      qacc_qacc[group],
      qacc_span[group],
      span_qacc[group],
      span_span[group],
      selected_qacc - qacc_qacc[group],
      selected_span - qacc_span[group],
      utility >> decision_csv
  }
  function record_agg(degradation, label, selected, selected_qacc, selected_span,
      qacc_delta, span_delta, accepted, split_flag, utility) {
    bucket = degradation SUBSEP label
    agg_groups[bucket]++
    agg_qacc[bucket] += selected_qacc
    agg_span[bucket] += selected_span
    agg_qacc_delta[bucket] += qacc_delta
    agg_span_delta[bucket] += span_delta
    agg_accept[bucket] += accepted
    agg_split[bucket] += split_flag
    agg_utility[bucket] += utility
    if (selected == "local-energy-hybrid") {
      agg_hybrid[bucket]++
    }
  }
  NR == FNR {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) agg_idx[$i] = i
      next
    }
    degradation = $agg_idx["degradation"]
    if (degradation != "") {
      source_routing[degradation] = $agg_idx["routing_trigger_rate_mean"] + 0
      source_jump[degradation] = $agg_idx["active_jump_rate_mean"] + 0
    }
    next
  }
  FNR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation key_count seed objective selected_scenario qacc span_exact", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing adaptive guardrail policy column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    group = group_key($idx["degradation"], $idx["key_count"], $idx["seed"])
    groups[group] = 1
    degradations[$idx["degradation"]] = 1
    objective = $idx["objective"]
    if (objective == "byte-qacc") {
      qacc_policy[group] = $idx["selected_scenario"]
      qacc_qacc[group] = $idx["qacc"] + 0
      qacc_span[group] = $idx["span_exact"] + 0
      seen_qacc[group] = 1
    } else if (objective == "span-exact") {
      span_policy[group] = $idx["selected_scenario"]
      span_qacc[group] = $idx["qacc"] + 0
      span_span[group] = $idx["span_exact"] + 0
      seen_span[group] = 1
    }
  }
  END {
    add_policy("qacc-default", 999.0)
    add_policy("utility-w0p50", 0.50)
    add_policy("utility-w0p75", 0.75)
    add_policy("utility-w1p00", 1.00)

    print "degradation,key_count,seed,policy,loss_weight,selected_scenario,accepted_span_policy,qacc_policy_scenario,span_policy_scenario,qacc,span_exact,qacc_policy_qacc,qacc_policy_span_exact,span_policy_qacc,span_policy_span_exact,qacc_delta_vs_qacc_policy,span_exact_delta_vs_qacc_policy,utility" > decision_csv
    print "degradation,policy,loss_weight,groups,objective_split_rate,span_accept_rate,selected_hybrid_rate,qacc_mean,span_exact_mean,qacc_delta_vs_qacc_policy_mean,span_exact_delta_vs_qacc_policy_mean,utility_mean,routing_trigger_rate_mean,active_jump_rate_mean" > agg_csv

    for (group in groups) {
      if (!seen_qacc[group] || !seen_span[group]) {
        printf "missing qacc/span adaptive policy rows for group %s\n", group > "/dev/stderr"
        exit 3
      }
      split(group, parts, ":")
      degradation = parts[1]
      split_policy = qacc_policy[group] != span_policy[group] ? 1 : 0
      span_gain = span_span[group] - qacc_span[group]
      qacc_loss = qacc_qacc[group] - span_qacc[group]

      for (p = 1; p <= policy_count; p++) {
        accepted = 0
        selected = qacc_policy[group]
        utility = span_gain - policy_weight[p] * qacc_loss
        if (policy_label[p] == "qacc-default") {
          utility = 0.0
        }
        if (policy_label[p] != "qacc-default" && split_policy && utility > 0.0) {
          accepted = 1
          selected = span_policy[group]
        }
        if (selected == span_policy[group]) {
          selected_qacc = span_qacc[group]
          selected_span = span_span[group]
        } else {
          selected_qacc = qacc_qacc[group]
          selected_span = qacc_span[group]
        }
        emit_decision(group, policy_label[p], policy_weight[p], selected, accepted,
          utility, span_gain, qacc_loss)
        record_agg(degradation, policy_label[p], selected, selected_qacc, selected_span,
          selected_qacc - qacc_qacc[group],
          selected_span - qacc_span[group],
          accepted, split_policy, utility)
      }
    }

    for (bucket in agg_groups) {
      split(bucket, parts, SUBSEP)
      degradation = parts[1]
      label = parts[2]
      groups_seen = agg_groups[bucket]
      weight = 0.0
      for (p = 1; p <= policy_count; p++) {
        if (policy_label[p] == label) {
          weight = policy_weight[p]
        }
      }
      printf "%s,%s,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        degradation,
        label,
        weight,
        groups_seen,
        agg_split[bucket] / groups_seen,
        agg_accept[bucket] / groups_seen,
        agg_hybrid[bucket] / groups_seen,
        agg_qacc[bucket] / groups_seen,
        agg_span[bucket] / groups_seen,
        agg_qacc_delta[bucket] / groups_seen,
        agg_span_delta[bucket] / groups_seen,
        agg_utility[bucket] / groups_seen,
        source_routing[degradation] + 0,
        source_jump[degradation] + 0 >> agg_csv
    }
  }
' "$SOURCE_AGG_CSV" "$SOURCE_POLICY_CSV"

echo "decisions: $DECISION_CSV"
echo "aggregate: $AGG_CSV"
