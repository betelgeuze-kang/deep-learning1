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

PREFIX="v06_route_memory_span_first_guardrail_degradation"
KEY_COUNTS=(32 64)
SEEDS=(1)
DEGRADATIONS=("weak:0.25:0.75" "harsher:0.125:0.875")
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_first_guardrail_degradation_smoke"
  KEY_COUNTS=(32)
  SEEDS=(1)
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(32 64 128)
  SEEDS=(1 2)
  DEGRADATIONS=("weak:0.25:0.75" "harsher:0.125:0.875" "extreme:0.0625:0.9375")
  VALUE_LEN=8
  EPOCHS=8
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decisions.csv"
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
    local key=$((74000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((74000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_correct_key_share_mean route_span_candidate_key_entropy_mean route_span_candidate_coherent_wrong_top_key_rate route_quality_candidate_weight_factor_max key_region_route_decode_acc route_signature_collision_rate routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span guardrail degradation metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_span_exact_match_rate"]] + 0,
        row[idx["route_span_candidate_all_recall_rate"]] + 0,
        row[idx["route_span_candidate_all_top1_rate"]] + 0,
        row[idx["route_span_candidate_correct_key_share_mean"]] + 0,
        row[idx["route_span_candidate_key_entropy_mean"]] + 0,
        row[idx["route_span_candidate_coherent_wrong_top_key_rate"]] + 0,
        row[idx["route_quality_candidate_weight_factor_max"]] + 0,
        row[idx["key_region_route_decode_acc"]] + 0,
        row[idx["route_signature_collision_rate"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local degradation="$1"
  local keep_prob="$2"
  local aux_noise="$3"
  local scenario="$4"
  local fixture="$5"
  local n_bytes="$6"
  local key_count="$7"
  local seed="$8"
  local score="$9"
  local preset="${10}"
  local csv_path="$RESULTS_DIR/${PREFIX}_${degradation}_${scenario}_k${key_count}_s${seed}.csv"

  local preset_args=()
  if [[ "$preset" != "none" ]]; then
    preset_args=(--route-quality-candidate-weight-preset "$preset")
  fi

  echo "v06-span-guardrail-degradation: ${degradation} ${scenario} k=${key_count} seed=${seed}" >&2
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
    --route-code-key-region-keep-prob "$keep_prob" \
    --route-code-aux-noise-rate "$aux_noise" \
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
  awk -F, -v degradation="$degradation" -v keep_prob="$keep_prob" \
    -v aux_noise="$aux_noise" -v scenario="$scenario" \
    -v key_count="$key_count" -v seed="$seed" -v value_len="$VALUE_LEN" \
    -v score="$score" -v preset="$preset" -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%s,%s,%s,%d,%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        degradation, keep_prob, aux_noise, scenario, key_count, seed, value_len,
        score, preset, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9],
        m[10], m[11], m[12]
    }
  ' >>"$SUMMARY_CSV"
}

printf 'degradation,keep_prob,aux_noise,scenario,key_count,seed,value_len,score,preset,qacc,span_exact,span_all_recall,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,factor_max,route_decode,route_collision,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for degradation_spec in "${DEGRADATIONS[@]}"; do
  IFS=: read -r degradation keep_prob aux_noise <<<"$degradation_spec"
  for key_count in "${KEY_COUNTS[@]}"; do
    fixture="$TMP_DIR/span_guardrail_degradation_${degradation}_k${key_count}.txt"
    make_fixture "$fixture" "$key_count" "$VALUE_LEN"
    n_bytes="$(wc -c <"$fixture")"
    for seed in "${SEEDS[@]}"; do
      run_case "$degradation" "$keep_prob" "$aux_noise" weak "$fixture" "$n_bytes" "$key_count" "$seed" insertion none
      run_case "$degradation" "$keep_prob" "$aux_noise" local-energy "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy none
      run_case "$degradation" "$keep_prob" "$aux_noise" local-energy-base "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy base-default
      run_case "$degradation" "$keep_prob" "$aux_noise" local-energy-hybrid "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy hybrid-safe
      run_case "$degradation" "$keep_prob" "$aux_noise" keyshape "$fixture" "$n_bytes" "$key_count" "$seed" key-shape none
    done
  done
done

awk -F, -v policy_csv="$POLICY_CSV" -v decision_csv="$DECISION_CSV" \
  -v agg_csv="$AGG_CSV" '
  function abs(value) {
    return value < 0 ? -value : value
  }
  function is_candidate(scenario) {
    return scenario == "local-energy" ||
      scenario == "local-energy-base" ||
      scenario == "local-energy-hybrid"
  }
  function group_key(degradation, key_count, seed) {
    return degradation ":" key_count ":" seed
  }
  function better_qacc(group, scenario, best_scenario, eps) {
    if (best_scenario == "") {
      return 1
    }
    if (qacc[group, scenario] > qacc[group, best_scenario] + eps) {
      return 1
    }
    if (abs(qacc[group, scenario] - qacc[group, best_scenario]) <= eps &&
        span_exact[group, scenario] > span_exact[group, best_scenario] + eps) {
      return 1
    }
    if (abs(qacc[group, scenario] - qacc[group, best_scenario]) <= eps &&
        abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps &&
        factor_max[group, scenario] < factor_max[group, best_scenario] - eps) {
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
    if (abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps &&
        qacc[group, scenario] > qacc[group, best_scenario] + eps) {
      return 1
    }
    if (abs(span_exact[group, scenario] - span_exact[group, best_scenario]) <= eps &&
        abs(qacc[group, scenario] - qacc[group, best_scenario]) <= eps &&
        factor_max[group, scenario] < factor_max[group, best_scenario] - eps) {
      return 1
    }
    return 0
  }
  function add_guardrail(label, min_gain, max_loss) {
    guardrail_count++
    guardrail_label[guardrail_count] = label
    guardrail_min_gain[guardrail_count] = min_gain
    guardrail_max_loss[guardrail_count] = max_loss
  }
  function emit_policy(group, objective, scenario) {
    split(group, parts, ":")
    printf "%s,%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      parts[1],
      parts[2],
      parts[3],
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
  function record_agg(degradation, guardrail, selected, qacc_value, span_value,
      qacc_delta, span_delta, accepted, qacc_policy_scenario, span_policy_scenario) {
    bucket = degradation SUBSEP guardrail
    agg_groups[bucket]++
    agg_qacc[bucket] += qacc_value
    agg_span[bucket] += span_value
    agg_qacc_delta[bucket] += qacc_delta
    agg_span_delta[bucket] += span_delta
    agg_accept[bucket] += accepted
    agg_split[bucket] += qacc_policy_scenario != span_policy_scenario ? 1 : 0
    if (selected == "local-energy-hybrid") {
      agg_hybrid[bucket]++
    }
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "degradation,key_count,seed,objective,selected_scenario,qacc,span_exact,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,qacc_delta_vs_weak,span_exact_delta_vs_weak,qacc_delta_vs_local_energy,span_exact_delta_vs_local_energy" > policy_csv
    print "degradation,key_count,seed,guardrail,min_span_gain,max_qacc_loss,selected_scenario,accepted_span_policy,qacc_policy_scenario,span_policy_scenario,qacc,span_exact,qacc_policy_qacc,qacc_policy_span_exact,span_policy_qacc,span_policy_span_exact,qacc_delta_vs_qacc_policy,span_exact_delta_vs_qacc_policy" > decision_csv
    next
  }
  {
    rows++
    degradation = $idx["degradation"]
    scenario = $idx["scenario"]
    group = group_key(degradation, $idx["key_count"], $idx["seed"])
    groups[group] = 1
    degradations[degradation] = 1
    seen[group, scenario] = 1
    qacc[group, scenario] = $idx["qacc"] + 0
    span_exact[group, scenario] = $idx["span_exact"] + 0
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
    add_guardrail("qacc-default", 999.0, 0.0)
    add_guardrail("strict-g0p050-cap0p050", 0.050, 0.050)
    add_guardrail("balanced-g0p025-cap0p050", 0.025, 0.050)
    add_guardrail("span-first-g0p025-cap0p075", 0.025, 0.075)

    for (group in groups) {
      missing_group = 0
      if (!seen[group, "weak"] || !seen[group, "local-energy"] ||
          !seen[group, "local-energy-base"] ||
          !seen[group, "local-energy-hybrid"] ||
          !seen[group, "keyshape"]) {
        missing_group = 1
      }
      if (missing_group != 0) {
        printf "missing guardrail degradation scenario in group %s\n", group > "/dev/stderr"
        exit 4
      }

      qacc_policy = ""
      span_policy = ""
      for (scenario_key in seen) {
        split(scenario_key, scenario_parts, SUBSEP)
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
      }
      emit_policy(group, "byte-qacc", qacc_policy)
      emit_policy(group, "span-exact", span_policy)

      split(group, parts, ":")
      degradation = parts[1]
      for (g = 1; g <= guardrail_count; g++) {
        span_gain = span_exact[group, span_policy] - span_exact[group, qacc_policy]
        qacc_loss = qacc[group, qacc_policy] - qacc[group, span_policy]
        accept = 0
        selected = qacc_policy
        if (span_policy != qacc_policy &&
            span_gain + eps >= guardrail_min_gain[g] &&
            qacc_loss <= guardrail_max_loss[g] + eps) {
          accept = 1
          selected = span_policy
        }
        selected_qacc = selected == span_policy ? qacc[group, span_policy] : qacc[group, qacc_policy]
        selected_span = selected == span_policy ? span_exact[group, span_policy] : span_exact[group, qacc_policy]
        printf "%s,%d,%d,%s,%.6f,%.6f,%s,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
          degradation,
          parts[2],
          parts[3],
          guardrail_label[g],
          guardrail_min_gain[g],
          guardrail_max_loss[g],
          selected,
          accept,
          qacc_policy,
          span_policy,
          selected_qacc,
          selected_span,
          qacc[group, qacc_policy],
          span_exact[group, qacc_policy],
          qacc[group, span_policy],
          span_exact[group, span_policy],
          selected_qacc - qacc[group, qacc_policy],
          selected_span - span_exact[group, qacc_policy] >> decision_csv
        record_agg(degradation, guardrail_label[g], selected, selected_qacc, selected_span,
          selected_qacc - qacc[group, qacc_policy],
          selected_span - span_exact[group, qacc_policy],
          accept, qacc_policy, span_policy)
      }
    }

    print "degradation,guardrail,groups,span_accept_rate,selected_hybrid_rate,qacc_mean,span_exact_mean,qacc_delta_vs_qacc_policy_mean,span_exact_delta_vs_qacc_policy_mean,objective_split_rate,routing_trigger_rate_mean,active_jump_rate_mean" > agg_csv
    for (bucket in agg_groups) {
      split(bucket, parts, SUBSEP)
      groups_seen = agg_groups[bucket]
      printf "%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        parts[1],
        parts[2],
        groups_seen,
        agg_accept[bucket] / groups_seen,
        agg_hybrid[bucket] / groups_seen,
        agg_qacc[bucket] / groups_seen,
        agg_span[bucket] / groups_seen,
        agg_qacc_delta[bucket] / groups_seen,
        agg_span_delta[bucket] / groups_seen,
        agg_split[bucket] / groups_seen,
        routing / rows,
        jump / rows >> agg_csv
    }
  }
' "$SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "policy: $POLICY_CSV"
echo "decisions: $DECISION_CSV"
echo "aggregate: $AGG_CSV"
