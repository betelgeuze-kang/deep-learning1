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

PREFIX="v06_route_memory_chunk_quality_diagnostics"
SOURCE_PREFIX="v06_route_memory_span_adaptive_guardrail_scale"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_chunk_quality_diagnostics_smoke"
  SOURCE_PREFIX="v06_route_memory_span_adaptive_guardrail_scale_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
SOURCE_DECISION_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_decisions.csv"
if [[ ! -s "$SOURCE_SUMMARY_CSV" || ! -s "$SOURCE_DECISION_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_span_adaptive_guardrail_scale.sh" "${RUN_ARGS[@]}" >/dev/null
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

awk -F, -v summary_csv="$SUMMARY_CSV" -v policy_csv="$POLICY_CSV" \
  -v agg_csv="$AGG_CSV" '
  function group_key(degradation, key_count, seed) {
    return degradation ":" key_count ":" seed
  }
  function metric_key(group, scenario) {
    return group SUBSEP scenario
  }
  function record_agg(degradation, policy, selected_qacc, chunk_exact,
      consistency, coherent_wrong, top1_recall_gap, qacc_delta, chunk_delta,
      accepted, sane, bad, keyshape_gap) {
    bucket = degradation SUBSEP policy
    agg_groups[bucket]++
    agg_qacc[bucket] += selected_qacc
    agg_chunk[bucket] += chunk_exact
    agg_consistency[bucket] += consistency
    agg_wrong[bucket] += coherent_wrong
    agg_gap[bucket] += top1_recall_gap
    agg_qacc_delta[bucket] += qacc_delta
    agg_chunk_delta[bucket] += chunk_delta
    agg_accept[bucket] += accepted
    agg_sane[bucket] += sane
    agg_bad[bucket] += bad
    agg_keyshape_gap[bucket] += keyshape_gap
  }
  NR == FNR {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) didx[$i] = i
      required_count = split("degradation key_count seed policy selected_scenario accepted_span_policy sane_accept bad_accept qacc_delta_vs_qacc_policy span_exact_delta_vs_qacc_policy", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in didx)) {
          printf "missing chunk-quality decision source column: %s\n", required[i] > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    policy = $didx["policy"]
    if (policy != "qacc-default" && policy != "utility-w0p75") next
    group = group_key($didx["degradation"], $didx["key_count"], $didx["seed"])
    decision_groups[group] = 1
    decision_policies[policy] = 1
    selected[group, policy] = $didx["selected_scenario"]
    accepted[group, policy] = $didx["accepted_span_policy"] + 0
    sane_accept[group, policy] = $didx["sane_accept"] + 0
    bad_accept[group, policy] = $didx["bad_accept"] + 0
    qacc_delta[group, policy] = $didx["qacc_delta_vs_qacc_policy"] + 0
    chunk_delta[group, policy] = $didx["span_exact_delta_vs_qacc_policy"] + 0
    next
  }
  FNR == 1 {
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("degradation key_count seed scenario qacc span_exact span_all_recall span_all_top1 top_key_consistency coherent_wrong_top_key routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) {
        printf "missing chunk-quality summary source column: %s\n", required[i] > "/dev/stderr"
        exit 3
      }
    }
    print "degradation,key_count,seed,scenario,qacc,chunk_exact,span_all_recall,span_all_top1,top1_recall_gap,per_offset_consistency,coherent_wrong_key,routing_trigger_rate,active_jump_rate" > summary_csv
    print "degradation,key_count,seed,policy,selected_scenario,accepted_span_policy,sane_accept,bad_accept,qacc,chunk_exact,per_offset_consistency,coherent_wrong_key,top1_recall_gap,qacc_delta_vs_qacc_policy,chunk_exact_delta_vs_qacc_policy,keyshape_chunk_exact,keyshape_gap,routing_trigger_rate,active_jump_rate" > policy_csv
    next
  }
  {
    group = group_key($sidx["degradation"], $sidx["key_count"], $sidx["seed"])
    scenario = $sidx["scenario"]
    key = metric_key(group, scenario)
    groups[group] = 1
    qacc[key] = $sidx["qacc"] + 0
    chunk_exact[key] = $sidx["span_exact"] + 0
    recall[key] = $sidx["span_all_recall"] + 0
    top1[key] = $sidx["span_all_top1"] + 0
    consistency[key] = $sidx["top_key_consistency"] + 0
    coherent_wrong[key] = $sidx["coherent_wrong_top_key"] + 0
    routing[group] += $sidx["routing_trigger_rate"] + 0
    jump[group] += $sidx["active_jump_rate"] + 0
    rows_by_group[group]++
    printf "%s,%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      $sidx["degradation"],
      $sidx["key_count"],
      $sidx["seed"],
      scenario,
      qacc[key],
      chunk_exact[key],
      recall[key],
      top1[key],
      recall[key] - top1[key],
      consistency[key],
      coherent_wrong[key],
      $sidx["routing_trigger_rate"] + 0,
      $sidx["active_jump_rate"] + 0 >> summary_csv
  }
  END {
    for (group in decision_groups) {
      split(group, parts, ":")
      degradation = parts[1]
      keyshape_key = metric_key(group, "keyshape")
      if (!(keyshape_key in chunk_exact)) {
        printf "missing keyshape chunk-quality upper-bound for group %s\n", group > "/dev/stderr"
        exit 4
      }
      routing_mean = rows_by_group[group] > 0 ? routing[group] / rows_by_group[group] : 0.0
      jump_mean = rows_by_group[group] > 0 ? jump[group] / rows_by_group[group] : 0.0
      for (policy in decision_policies) {
        scenario = selected[group, policy]
        selected_key = metric_key(group, scenario)
        if (!(selected_key in chunk_exact)) {
          printf "missing selected chunk-quality scenario %s for group %s\n", scenario, group > "/dev/stderr"
          exit 5
        }
        keyshape_gap = chunk_exact[keyshape_key] - chunk_exact[selected_key]
        printf "%s,%d,%d,%s,%s,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
          degradation,
          parts[2],
          parts[3],
          policy,
          scenario,
          accepted[group, policy],
          sane_accept[group, policy],
          bad_accept[group, policy],
          qacc[selected_key],
          chunk_exact[selected_key],
          consistency[selected_key],
          coherent_wrong[selected_key],
          recall[selected_key] - top1[selected_key],
          qacc_delta[group, policy],
          chunk_delta[group, policy],
          chunk_exact[keyshape_key],
          keyshape_gap,
          routing_mean,
          jump_mean >> policy_csv
        record_agg(degradation, policy, qacc[selected_key], chunk_exact[selected_key],
          consistency[selected_key], coherent_wrong[selected_key],
          recall[selected_key] - top1[selected_key], qacc_delta[group, policy],
          chunk_delta[group, policy], accepted[group, policy],
          sane_accept[group, policy], bad_accept[group, policy], keyshape_gap)
        record_agg("all", policy, qacc[selected_key], chunk_exact[selected_key],
          consistency[selected_key], coherent_wrong[selected_key],
          recall[selected_key] - top1[selected_key], qacc_delta[group, policy],
          chunk_delta[group, policy], accepted[group, policy],
          sane_accept[group, policy], bad_accept[group, policy], keyshape_gap)
        route_sum[degradation] += routing_mean
        jump_sum[degradation] += jump_mean
        route_groups[degradation]++
        route_sum["all"] += routing_mean
        jump_sum["all"] += jump_mean
        route_groups["all"]++
      }
    }

    print "degradation,policy,groups,span_policy_accept_rate,sane_accept_rate,bad_accept_rate,qacc_mean,chunk_exact_mean,per_offset_consistency_mean,coherent_wrong_key_mean,top1_recall_gap_mean,qacc_delta_vs_qacc_policy_mean,chunk_exact_delta_vs_qacc_policy_mean,keyshape_gap_mean,routing_trigger_rate_mean,active_jump_rate_mean" > agg_csv
    for (bucket in agg_groups) {
      split(bucket, parts, SUBSEP)
      degradation = parts[1]
      policy = parts[2]
      count = agg_groups[bucket]
      route_mean = route_groups[degradation] > 0 ? route_sum[degradation] / route_groups[degradation] : 0.0
      jump_mean = route_groups[degradation] > 0 ? jump_sum[degradation] / route_groups[degradation] : 0.0
      printf "%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        degradation,
        policy,
        count,
        agg_accept[bucket] / count,
        agg_sane[bucket] / count,
        agg_bad[bucket] / count,
        agg_qacc[bucket] / count,
        agg_chunk[bucket] / count,
        agg_consistency[bucket] / count,
        agg_wrong[bucket] / count,
        agg_gap[bucket] / count,
        agg_qacc_delta[bucket] / count,
        agg_chunk_delta[bucket] / count,
        agg_keyshape_gap[bucket] / count,
        route_mean,
        jump_mean >> agg_csv
    }
  }
' "$SOURCE_DECISION_CSV" "$SOURCE_SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "policy: $POLICY_CSV"
echo "aggregate: $AGG_CSV"
