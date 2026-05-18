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

PREFIX="v06_route_memory_span_local_energy_policy"
COMPOSITION_PREFIX="v06_route_memory_span_local_energy_composition"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_local_energy_policy_smoke"
  COMPOSITION_PREFIX="v06_route_memory_span_local_energy_composition_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_composition.sh" "${RUN_ARGS[@]}"

SUMMARY_CSV="$RESULTS_DIR/${COMPOSITION_PREFIX}_summary.csv"
POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

awk -F, -v policy_csv="$POLICY_CSV" -v agg_csv="$AGG_CSV" '
  function abs(value) {
    return value < 0 ? -value : value
  }
  function is_candidate(scenario) {
    if (scenario == "local-energy") {
      return 1
    }
    if (scenario == "local-energy-base") {
      return 1
    }
    if (scenario == "local-energy-hybrid") {
      return 1
    }
    return 0
  }
  function better_qacc(scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (qacc[scenario] > qacc[best_scenario] + eps) {
      return 1
    }
    if (abs(qacc[scenario] - qacc[best_scenario]) <= eps && span_exact[scenario] > span_exact[best_scenario] + eps) {
      return 1
    }
    if (abs(qacc[scenario] - qacc[best_scenario]) <= eps && abs(span_exact[scenario] - span_exact[best_scenario]) <= eps && factor_max[scenario] < factor_max[best_scenario] - eps) {
      return 1
    }
    return 0
  }
  function better_span(scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (span_exact[scenario] > span_exact[best_scenario] + eps) {
      return 1
    }
    if (abs(span_exact[scenario] - span_exact[best_scenario]) <= eps && qacc[scenario] > qacc[best_scenario] + eps) {
      return 1
    }
    if (abs(span_exact[scenario] - span_exact[best_scenario]) <= eps && abs(qacc[scenario] - qacc[best_scenario]) <= eps && factor_max[scenario] < factor_max[best_scenario] - eps) {
      return 1
    }
    return 0
  }
  function balanced_score(scenario) {
    return (qacc[scenario] - qacc["weak"]) + (span_exact[scenario] - span_exact["weak"])
  }
  function better_balanced(scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (balanced_score(scenario) > balanced_score(best_scenario) + eps) {
      return 1
    }
    if (abs(balanced_score(scenario) - balanced_score(best_scenario)) <= eps && span_exact[scenario] > span_exact[best_scenario] + eps) {
      return 1
    }
    if (abs(balanced_score(scenario) - balanced_score(best_scenario)) <= eps && abs(span_exact[scenario] - span_exact[best_scenario]) <= eps && qacc[scenario] > qacc[best_scenario] + eps) {
      return 1
    }
    return 0
  }
  function emit_policy(objective, scenario) {
    printf "%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      objective,
      scenario,
      qacc[scenario],
      span_exact[scenario],
      all_top1[scenario],
      correct_share[scenario],
      entropy[scenario],
      coherent_wrong[scenario],
      qacc[scenario] - qacc["weak"],
      span_exact[scenario] - span_exact["weak"],
      qacc[scenario] - qacc["local-energy"],
      span_exact[scenario] - span_exact["local-energy"] >> policy_csv
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scenario qacc span_exact span_all_recall span_all_top1 correct_key_share key_entropy coherent_wrong_top_key factor_max routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy policy input column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    scenario = $idx["scenario"]
    scenarios[scenario] = 1
    rows++
    qacc[scenario] = $idx["qacc"] + 0
    span_exact[scenario] = $idx["span_exact"] + 0
    all_recall[scenario] = $idx["span_all_recall"] + 0
    all_top1[scenario] = $idx["span_all_top1"] + 0
    correct_share[scenario] = $idx["correct_key_share"] + 0
    entropy[scenario] = $idx["key_entropy"] + 0
    coherent_wrong[scenario] = $idx["coherent_wrong_top_key"] + 0
    factor_max[scenario] = $idx["factor_max"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    eps = 0.0000005
    missing_required = 0
    if (!("weak" in scenarios)) {
      missing_required = 1
    }
    if (!("local-energy" in scenarios)) {
      missing_required = 1
    }
    if (!("local-energy-base" in scenarios)) {
      missing_required = 1
    }
    if (!("local-energy-hybrid" in scenarios)) {
      missing_required = 1
    }
    if (!("keyshape" in scenarios)) {
      missing_required = 1
    }
    if (missing_required != 0) {
      printf "policy calibration requires weak/local/base/hybrid/keyshape rows\n" > "/dev/stderr"
      exit 3
    }
    for (scenario in scenarios) {
      if (is_candidate(scenario)) {
        if (better_qacc(scenario, qacc_policy, eps)) {
          qacc_policy = scenario
        }
        if (better_span(scenario, span_policy, eps)) {
          span_policy = scenario
        }
        if (better_balanced(scenario, balanced_policy, eps)) {
          balanced_policy = scenario
        }
      }
    }

    print "objective,selected_scenario,qacc,span_exact,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,qacc_delta_vs_weak,span_exact_delta_vs_weak,qacc_delta_vs_local_energy,span_exact_delta_vs_local_energy" > policy_csv
    emit_policy("byte-qacc", qacc_policy)
    emit_policy("span-exact", span_policy)
    emit_policy("balanced", balanced_policy)

    print "candidate_rows,qacc_objective_scenario,span_objective_scenario,balanced_objective_scenario,objectives_differ,qacc_objective_qacc,qacc_objective_span_exact,span_objective_qacc,span_objective_span_exact,span_objective_qacc_delta_vs_qacc_objective,span_objective_span_exact_delta_vs_qacc_objective,balanced_objective_qacc,balanced_objective_span_exact,routing_trigger_rate_sum,active_jump_rate_sum" > agg_csv
    printf "%d,%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      qacc_policy,
      span_policy,
      balanced_policy,
      qacc_policy == span_policy ? 0 : 1,
      qacc[qacc_policy],
      span_exact[qacc_policy],
      qacc[span_policy],
      span_exact[span_policy],
      qacc[span_policy] - qacc[qacc_policy],
      span_exact[span_policy] - span_exact[qacc_policy],
      qacc[balanced_policy],
      span_exact[balanced_policy],
      routing,
      jump >> agg_csv
  }
' "$SUMMARY_CSV"

echo "policy: $POLICY_CSV"
echo "aggregate: $AGG_CSV"
