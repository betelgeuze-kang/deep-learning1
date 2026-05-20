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

PREFIX="v06_route_memory_span_first_guardrail"
SOURCE_PREFIX="v06_route_memory_span_local_energy_policy_scale"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_first_guardrail_smoke"
  SOURCE_PREFIX="v06_route_memory_span_local_energy_policy_scale_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_policy_scale.sh" "${RUN_ARGS[@]}" >/dev/null

SOURCE_POLICY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_policy.csv"
SOURCE_AGG_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_aggregate.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decisions.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

awk -F, -v decision_csv="$DECISION_CSV" -v agg_csv="$AGG_CSV" '
  function abs(value) {
    return value < 0 ? -value : value
  }
  function group_key(key_count, seed) {
    return key_count ":" seed
  }
  function add_guardrail(label, min_gain, max_loss) {
    guardrail_count++
    guardrail_label[guardrail_count] = label
    guardrail_min_gain[guardrail_count] = min_gain
    guardrail_max_loss[guardrail_count] = max_loss
  }
  function emit_decision(group, label, min_gain, max_loss, selected, accepted) {
    split(group, parts, ":")
    selected_qacc = selected == span_policy[group] ? span_qacc[group] : qacc_qacc[group]
    selected_span = selected == span_policy[group] ? span_span[group] : qacc_span[group]
    printf "%d,%d,%s,%.6f,%.6f,%s,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      parts[1],
      parts[2],
      label,
      min_gain,
      max_loss,
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
      selected_span - qacc_span[group] >> decision_csv
  }
  function emit_aggregate(label, min_gain, max_loss, groups_seen, accept_count,
      selected_hybrid_count, qacc_sum, span_sum, qacc_delta_sum, span_delta_sum,
      split_count, qacc_policy_qacc_sum, qacc_policy_span_sum,
      span_policy_qacc_sum, span_policy_span_sum) {
    printf "%s,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      label,
      min_gain,
      max_loss,
      groups_seen,
      accept_count / groups_seen,
      selected_hybrid_count / groups_seen,
      qacc_sum / groups_seen,
      span_sum / groups_seen,
      qacc_delta_sum / groups_seen,
      span_delta_sum / groups_seen,
      split_count / groups_seen,
      qacc_policy_qacc_sum / groups_seen,
      qacc_policy_span_sum / groups_seen,
      span_policy_qacc_sum / groups_seen,
      span_policy_span_sum / groups_seen,
      source_objectives_differ_rate,
      source_routing_trigger_rate,
      source_active_jump_rate >> agg_csv
  }
  NR == FNR {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("key_count seed objective selected_scenario qacc span_exact", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span-first guardrail policy column: %s\n", required[i] > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    group = group_key($idx["key_count"], $idx["seed"])
    groups[group] = 1
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
    next
  }
  FNR == 1 {
    for (i = 1; i <= NF; i++) agg_idx[$i] = i
    next
  }
  {
    if ("objectives_differ_rate" in agg_idx) {
      source_objectives_differ_rate = $agg_idx["objectives_differ_rate"] + 0
    }
    if ("routing_trigger_rate_mean" in agg_idx) {
      source_routing_trigger_rate = $agg_idx["routing_trigger_rate_mean"] + 0
    }
    if ("active_jump_rate_mean" in agg_idx) {
      source_active_jump_rate = $agg_idx["active_jump_rate_mean"] + 0
    }
  }
  END {
    eps = 0.0000005
    add_guardrail("qacc-default", 999.0, 0.0)
    add_guardrail("strict-g0p050-cap0p050", 0.050, 0.050)
    add_guardrail("balanced-g0p025-cap0p050", 0.025, 0.050)
    add_guardrail("span-first-g0p025-cap0p075", 0.025, 0.075)

    print "key_count,seed,guardrail,min_span_gain,max_qacc_loss,selected_scenario,accepted_span_policy,qacc_policy_scenario,span_policy_scenario,qacc,span_exact,qacc_policy_qacc,qacc_policy_span_exact,span_policy_qacc,span_policy_span_exact,qacc_delta_vs_qacc_policy,span_exact_delta_vs_qacc_policy" > decision_csv
    print "guardrail,min_span_gain,max_qacc_loss,groups,span_accept_rate,selected_hybrid_rate,qacc_mean,span_exact_mean,qacc_delta_vs_qacc_policy_mean,span_exact_delta_vs_qacc_policy_mean,objective_split_rate,qacc_policy_qacc_mean,qacc_policy_span_exact_mean,span_policy_qacc_mean,span_policy_span_exact_mean,source_objectives_differ_rate,routing_trigger_rate_mean,active_jump_rate_mean" > agg_csv

    for (g = 1; g <= guardrail_count; g++) {
      groups_seen = 0
      accept_count = 0
      selected_hybrid_count = 0
      qacc_sum = 0.0
      span_sum = 0.0
      qacc_delta_sum = 0.0
      span_delta_sum = 0.0
      split_count = 0
      qacc_policy_qacc_sum = 0.0
      qacc_policy_span_sum = 0.0
      span_policy_qacc_sum = 0.0
      span_policy_span_sum = 0.0

      for (group in groups) {
        if (!seen_qacc[group] || !seen_span[group]) {
          printf "missing qacc/span policy rows for group %s\n", group > "/dev/stderr"
          exit 3
        }
        groups_seen++
        span_gain = span_span[group] - qacc_span[group]
        qacc_loss = qacc_qacc[group] - span_qacc[group]
        accept = 0
        selected = qacc_policy[group]
        if (span_policy[group] != qacc_policy[group] &&
            span_gain + eps >= guardrail_min_gain[g] &&
            qacc_loss <= guardrail_max_loss[g] + eps) {
          accept = 1
          selected = span_policy[group]
        }

        selected_qacc = selected == span_policy[group] ? span_qacc[group] : qacc_qacc[group]
        selected_span = selected == span_policy[group] ? span_span[group] : qacc_span[group]
        emit_decision(group, guardrail_label[g], guardrail_min_gain[g], guardrail_max_loss[g], selected, accept)

        accept_count += accept
        if (selected == "local-energy-hybrid") {
          selected_hybrid_count++
        }
        if (span_policy[group] != qacc_policy[group]) {
          split_count++
        }
        qacc_sum += selected_qacc
        span_sum += selected_span
        qacc_delta_sum += selected_qacc - qacc_qacc[group]
        span_delta_sum += selected_span - qacc_span[group]
        qacc_policy_qacc_sum += qacc_qacc[group]
        qacc_policy_span_sum += qacc_span[group]
        span_policy_qacc_sum += span_qacc[group]
        span_policy_span_sum += span_span[group]
      }
      if (groups_seen <= 0) {
        printf "invalid span-first guardrail group count\n" > "/dev/stderr"
        exit 4
      }
      emit_aggregate(guardrail_label[g], guardrail_min_gain[g], guardrail_max_loss[g],
        groups_seen, accept_count, selected_hybrid_count, qacc_sum, span_sum,
        qacc_delta_sum, span_delta_sum, split_count, qacc_policy_qacc_sum,
        qacc_policy_span_sum, span_policy_qacc_sum, span_policy_span_sum)
    }
  }
' "$SOURCE_POLICY_CSV" "$SOURCE_AGG_CSV"

echo "decisions: $DECISION_CSV"
echo "aggregate: $AGG_CSV"
