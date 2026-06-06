#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

PREFIX="v06_route_memory_span_local_energy_policy_scale"
KEY_COUNTS=(32 64)
SEEDS=(1 2)
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_local_energy_policy_scale_smoke"
  KEY_COUNTS=(32)
  SEEDS=(1)
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(32 64 128)
  SEEDS=(1 2 3)
  VALUE_LEN=8
  EPOCHS=8
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

value_for_index() {
  local index="$1"
  local len="$2"
  local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
  local out=""
  local alphabet_len="${#alphabet}"
  for ((j = 0; j < len; j++)); do
    local pos=$(((index * 13 + j * 7 + j * index) % alphabet_len))
    out+="${alphabet:pos:1}"
  done
  printf "%s" "$out"
}

make_fixture() {
  local path="$1"
  local key_count="$2"
  local value_len="$3"

  : >"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((73000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((73000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_correct_key_share_mean route_span_candidate_key_entropy_mean route_span_candidate_coherent_wrong_top_key_rate route_quality_candidate_weight_factor_max routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span local-energy policy-scale metric column: %s\n", required[i] > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    { last = $0 }
    END {
      if (last == "") {
        printf "no data rows in %s\n", FILENAME > "/dev/stderr"
        exit 3
      }
      split(last, row, FS)
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_span_exact_match_rate"]] + 0,
        row[idx["route_span_candidate_all_recall_rate"]] + 0,
        row[idx["route_span_candidate_all_top1_rate"]] + 0,
        row[idx["route_span_candidate_correct_key_share_mean"]] + 0,
        row[idx["route_span_candidate_key_entropy_mean"]] + 0,
        row[idx["route_span_candidate_coherent_wrong_top_key_rate"]] + 0,
        row[idx["route_quality_candidate_weight_factor_max"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local scenario="$1"
  local fixture="$2"
  local n_bytes="$3"
  local key_count="$4"
  local seed="$5"
  local score="$6"
  local preset="$7"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}_k${key_count}_s${seed}.csv"

  local preset_args=()
  if [[ "$preset" != "none" ]]; then
    preset_args=(--route-quality-candidate-weight-preset "$preset")
  fi

  echo "v06-span-local-energy-policy-scale: ${scenario} k=${key_count} seed=${seed}" >&2
  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n_bytes" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$CYCLES_PER_EPOCH" \
    --seed "$seed" \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count "$PROPOSAL_COUNT" \
    --route-mode hint-kv-hash \
    --route-span-hints 1 \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --route-code-key-region-keep-prob 0.25 \
    --route-code-aux-noise-rate 0.75 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --route-hash-bits 16 \
    --K-route 16 \
    --route-hint-agg weighted-vote \
    --route-candidate-score "$score" \
    --lambda-route 5.0 \
    "${preset_args[@]}" \
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v scenario="$scenario" -v key_count="$key_count" \
    -v seed="$seed" -v value_len="$VALUE_LEN" -v score="$score" \
    -v preset="$preset" -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        scenario, key_count, seed, value_len, score, preset,
        m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10]
    }
  ' >>"$SUMMARY_CSV"
}

printf 'scenario,key_count,seed,value_len,score,preset,qacc,span_exact,span_all_recall,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,factor_max,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  fixture="$TMP_DIR/span_local_energy_policy_scale_k${key_count}.txt"
  make_fixture "$fixture" "$key_count" "$VALUE_LEN"
  n_bytes="$(wc -c <"$fixture")"
  for seed in "${SEEDS[@]}"; do
    run_case weak "$fixture" "$n_bytes" "$key_count" "$seed" insertion none
    run_case local-energy "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy none
    run_case local-energy-base "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy base-default
    run_case local-energy-hybrid "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy hybrid-safe
    run_case keyshape "$fixture" "$n_bytes" "$key_count" "$seed" key-shape none
  done
done

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
  function group_key(key_count, seed) {
    return key_count ":" seed
  }
  function better_qacc(group, scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (qacc[group, scenario] > qacc[group, best_scenario] + eps) {
      return 1
    }
    if (abs(qacc[group, scenario] - qacc[group, best_scenario]) <= eps && span_exact[group, scenario] > span_exact[group, best_scenario] + eps) {
      return 1
    }
    if (abs(qacc[group, scenario] - qacc[group, best_scenario]) <= eps && abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps && factor_max[group, scenario] < factor_max[group, best_scenario] - eps) {
      return 1
    }
    return 0
  }
  function better_span(group, scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (span_exact[group, scenario] > span_exact[group, best_scenario] + eps) {
      return 1
    }
    if (abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps && qacc[group, scenario] > qacc[group, best_scenario] + eps) {
      return 1
    }
    if (abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps && abs(qacc[group, scenario] - qacc[group, best_scenario]) <= eps && factor_max[group, scenario] < factor_max[group, best_scenario] - eps) {
      return 1
    }
    return 0
  }
  function balanced_score(group, scenario) {
    return (qacc[group, scenario] - qacc[group, "weak"]) + (span_exact[group, scenario] - span_exact[group, "weak"])
  }
  function better_balanced(group, scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (balanced_score(group, scenario) > balanced_score(group, best_scenario) + eps) {
      return 1
    }
    if (abs(balanced_score(group, scenario) - balanced_score(group, best_scenario)) <= eps && span_exact[group, scenario] > span_exact[group, best_scenario] + eps) {
      return 1
    }
    if (abs(balanced_score(group, scenario) - balanced_score(group, best_scenario)) <= eps && abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps && qacc[group, scenario] > qacc[group, best_scenario] + eps) {
      return 1
    }
    return 0
  }
  function scenario_count_increment(bucket, scenario) {
    bucket SUBSEP scenario
  }
  function emit_policy(group, objective, scenario) {
    split(group, parts, ":")
    printf "%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      parts[1],
      parts[2],
      objective,
      scenario,
      qacc[group, scenario],
      span_exact[group, scenario],
      all_top1[group, scenario],
      correct_share[group, scenario],
      entropy[group, scenario],
      coherent_wrong[group, scenario],
      qacc[group, scenario] - qacc[group, "weak"],
      span_exact[group, scenario] - span_exact[group, "weak"],
      qacc[group, scenario] - qacc[group, "local-energy"],
      span_exact[group, scenario] - span_exact[group, "local-energy"] >> policy_csv
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "key_count,seed,objective,selected_scenario,qacc,span_exact,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,qacc_delta_vs_weak,span_exact_delta_vs_weak,qacc_delta_vs_local_energy,span_exact_delta_vs_local_energy" > policy_csv
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    group = group_key($idx["key_count"], $idx["seed"])
    groups[group] = 1
    seen[group, scenario] = 1
    qacc[group, scenario] = $idx["qacc"] + 0
    span_exact[group, scenario] = $idx["span_exact"] + 0
    all_recall[group, scenario] = $idx["span_all_recall"] + 0
    all_top1[group, scenario] = $idx["span_all_top1"] + 0
    correct_share[group, scenario] = $idx["correct_key_share"] + 0
    entropy[group, scenario] = $idx["key_entropy"] + 0
    coherent_wrong[group, scenario] = $idx["coherent_wrong_top_key"] + 0
    factor_max[group, scenario] = $idx["factor_max"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    eps = 0.0000005
    for (group in groups) {
      missing_group = 0
      if (!seen[group, "weak"]) {
        missing_group = 1
      }
      if (!seen[group, "local-energy"]) {
        missing_group = 1
      }
      if (!seen[group, "local-energy-base"]) {
        missing_group = 1
      }
      if (!seen[group, "local-energy-hybrid"]) {
        missing_group = 1
      }
      if (!seen[group, "keyshape"]) {
        missing_group = 1
      }
      if (missing_group != 0) {
        printf "missing policy-scale scenario in group %s\n", group > "/dev/stderr"
        exit 4
      }
      qacc_policy = ""
      span_policy = ""
      balanced_policy = ""
      for (scenario in seen) {
        split(scenario, scenario_parts, SUBSEP)
        if (scenario_parts[1] != group || !is_candidate(scenario_parts[2])) {
          continue
        }
        candidate = scenario_parts[2]
        if (better_qacc(group, candidate, qacc_policy, eps)) {
          qacc_policy = candidate
        }
        if (better_span(group, candidate, span_policy, eps)) {
          span_policy = candidate
        }
        if (better_balanced(group, candidate, balanced_policy, eps)) {
          balanced_policy = candidate
        }
      }
      group_count++
      emit_policy(group, "byte-qacc", qacc_policy)
      emit_policy(group, "span-exact", span_policy)
      emit_policy(group, "balanced", balanced_policy)
      if (qacc_policy != span_policy) {
        objectives_differ++
      }
      if (qacc_policy == "local-energy") {
        qacc_local_energy_count++
      }
      if (span_policy == "local-energy-hybrid") {
        span_hybrid_count++
      }
      if (balanced_policy == "local-energy-hybrid") {
        balanced_hybrid_count++
      }
      qacc_policy_qacc_sum += qacc[group, qacc_policy]
      qacc_policy_span_sum += span_exact[group, qacc_policy]
      span_policy_qacc_sum += qacc[group, span_policy]
      span_policy_span_sum += span_exact[group, span_policy]
      span_policy_qacc_delta_sum += qacc[group, span_policy] - qacc[group, qacc_policy]
      span_policy_span_delta_sum += span_exact[group, span_policy] - span_exact[group, qacc_policy]
    }
    if (group_count <= 0) {
      printf "invalid policy-scale group count\n" > "/dev/stderr"
      exit 5
    }
    print "rows,groups,objectives_differ_rate,qacc_policy_local_energy_rate,span_policy_hybrid_rate,balanced_policy_hybrid_rate,qacc_policy_qacc_mean,qacc_policy_span_exact_mean,span_policy_qacc_mean,span_policy_span_exact_mean,span_policy_qacc_delta_vs_qacc_policy_mean,span_policy_span_exact_delta_vs_qacc_policy_mean,routing_trigger_rate_mean,active_jump_rate_mean" > agg_csv
    printf "%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      group_count,
      objectives_differ / group_count,
      qacc_local_energy_count / group_count,
      span_hybrid_count / group_count,
      balanced_hybrid_count / group_count,
      qacc_policy_qacc_sum / group_count,
      qacc_policy_span_sum / group_count,
      span_policy_qacc_sum / group_count,
      span_policy_span_sum / group_count,
      span_policy_qacc_delta_sum / group_count,
      span_policy_span_delta_sum / group_count,
      routing / rows,
      jump / rows >> agg_csv
  }
' "$SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "policy: $POLICY_CSV"
echo "aggregate: $AGG_CSV"
