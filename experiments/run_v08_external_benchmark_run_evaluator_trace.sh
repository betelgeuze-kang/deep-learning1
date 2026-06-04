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
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PREFIX="v08_external_benchmark_run_evaluator_trace"
AK_PREFIX="v08_external_benchmark_authority_promotion_evidence"
AB_PREFIX="v08_external_benchmark_codebase_mini"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_run_evaluator_trace_smoke"
  AK_PREFIX="v08_external_benchmark_authority_promotion_evidence_smoke"
  AB_PREFIX="v08_external_benchmark_codebase_mini_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_run_evaluator_trace_full"
  AK_PREFIX="v08_external_benchmark_authority_promotion_evidence_full"
  AB_PREFIX="v08_external_benchmark_codebase_mini_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_authority_promotion_evidence.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_codebase_mini.sh" "${RUN_ARGS[@]}" >/dev/null

AK_SUMMARY_CSV="$RESULTS_DIR/${AK_PREFIX}_summary.csv"
AB_SUMMARY_CSV="$RESULTS_DIR/${AB_PREFIX}_summary.csv"
TRACE_DIR="${V08_EXTERNAL_BENCHMARK_RUN_EVALUATOR_TRACE_DIR:-$RESULTS_DIR/${PREFIX}_artifacts/run-evaluator-trace}"
TRACE_SOURCE="generated-local-codebase-run"
if [[ -n "${V08_EXTERNAL_BENCHMARK_RUN_EVALUATOR_TRACE_DIR:-}" ]]; then
  TRACE_SOURCE="provided-dir"
fi
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_EXTERNAL_FAMILIES=4

REQUIRED_TRACE_FILES=(
  runner_manifest.json
  evaluator_manifest.json
  query_trace.csv
  evaluator_output.csv
  metrics_recomputed.csv
  command_receipt.txt
)

csv_value() {
  local file="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(column in idx)) {
        print "missing v08-al column: " column > "/dev/stderr"
        exit 11
      }
      next
    }
    NR == 2 {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) {
        print "missing v08-al summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

metric_value() {
  local file="$1"
  local metric="$2"
  awk -F, -v metric="$metric" '
    NR > 1 && $1 == metric {
      print $2
      found = 1
      exit
    }
    END {
      if (!found) {
        print "0.000000"
      }
    }
  ' "$file"
}

sha256_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

write_trace_artifacts() {
  local trace_dir="$1"
  local artifact_dir="$2"
  local dataset_jsonl="$artifact_dir/dataset.jsonl"
  local result_jsonl="$artifact_dir/results/route_memory_results.jsonl"
  local dataset_index="$TMP_DIR/v08al_dataset_index.csv"
  local result_index="$TMP_DIR/v08al_result_index.csv"

  if [[ ! -f "$dataset_jsonl" || ! -f "$result_jsonl" ]]; then
    return 0
  fi

  rm -rf "$trace_dir"
  mkdir -p "$trace_dir"

  sed -nE 's/.*"query_id":"([^"]+)".*"label_type":"([^"]+)".*/\1,\2/p' \
    "$dataset_jsonl" >"$dataset_index"
  sed -nE 's/.*"query_id":"([^"]+)","prediction":"([^"]+)","correct":([0-9]+),"span_exact":([0-9]+),"chunk_exact":([0-9]+),"near_miss_false_positive":([0-9]+).*/\1,\2,\3,\4,\5,\6/p' \
    "$result_jsonl" >"$result_index"

  {
    printf '{"benchmark_family":"codebase-retrieval","trace_kind":"runner-owned-local-recompute","mode":"%s","artifact_dir":"%s","dataset_uri":"file://%s","result_uri":"file://%s","dataset_hash":"%s","result_hash":"%s","independent_observer_declared":0,"fixture_or_synthetic_declared":0}\n' \
      "$MODE" \
      "$artifact_dir" \
      "$dataset_jsonl" \
      "$result_jsonl" \
      "$(sha256_uri "$dataset_jsonl")" \
      "$(sha256_uri "$result_jsonl")"
  } >"$trace_dir/runner_manifest.json"

  cat >"$trace_dir/evaluator_manifest.json" <<'JSON'
{"evaluator_id":"v08-al-codebase-mini-recompute","benchmark_family":"codebase-retrieval","metrics":["span_exact","chunk_exact","missing_abstain","near_miss_false_positive","wrong_answer_rate"],"claim":"runner-owned local evaluator trace only; not independent all-family external benchmark evidence"}
JSON

  {
    echo "query_id,label_type,dataset_bound,result_bound,runner_owned_evaluator,independent_evaluator"
    awk -F, '
      NR == FNR {
        label[$1] = $2
        next
      }
      {
        if ($1 in label) {
          print $1 "," label[$1] ",1,1,1,0"
        }
      }
    ' "$dataset_index" "$result_index"
  } >"$trace_dir/query_trace.csv"

  {
    echo "query_id,label_type,prediction,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer"
    awk -F, '
      NR == FNR {
        label[$1] = $2
        next
      }
      {
        current_label = label[$1]
        missing_abstain = 1
        if (current_label == "missing") {
          missing_abstain = ($2 == "ABSTAIN") ? 1 : 0
        }
        wrong_answer = (($3 + 0) == 1) ? 0 : 1
        print $1 "," current_label "," $2 "," ($4 + 0) "," ($5 + 0) "," missing_abstain "," ($6 + 0) "," wrong_answer
      }
    ' "$dataset_index" "$result_index"
  } >"$trace_dir/evaluator_output.csv"

  {
    echo "metric,value"
    awk -F, '
      NR > 1 {
        rows++
        span += $4
        chunk += $5
        if ($2 == "missing") {
          missing_rows++
          missing_ok += $6
        }
        if ($2 == "near_miss") {
          near_rows++
          near_fp += $7
        }
        wrong += $8
      }
      END {
        if (rows == 0) rows = 1
        if (missing_rows == 0) missing_rows = 1
        if (near_rows == 0) near_rows = 1
        printf "span_exact,%.6f\n", span / rows
        printf "chunk_exact,%.6f\n", chunk / rows
        printf "missing_abstain,%.6f\n", missing_ok / missing_rows
        printf "near_miss_false_positive,%.6f\n", near_fp / near_rows
        printf "wrong_answer_rate,%.6f\n", wrong / rows
      }
    ' "$trace_dir/evaluator_output.csv"
  } >"$trace_dir/metrics_recomputed.csv"

  {
    printf 'command=experiments/run_v08_external_benchmark_run_evaluator_trace.sh %s\n' "${RUN_ARGS[*]:-}"
    printf 'dataset=%s\n' "$dataset_jsonl"
    printf 'result=%s\n' "$result_jsonl"
    printf 'trace_source=%s\n' "$TRACE_SOURCE"
    printf 'routing_trigger_rate=0.000000\n'
    printf 'active_jump_rate=0.000000\n'
  } >"$trace_dir/command_receipt.txt"

  {
    local file
    for file in "${REQUIRED_TRACE_FILES[@]}"; do
      sha256sum "$trace_dir/$file" | awk -v f="$file" '{print $1 "  " f}'
    done
  } >"$trace_dir/sha256sums.txt"
}

authority_promotion_evidence_ready="$(csv_value "$AK_SUMMARY_CSV" "authority_promotion_evidence_ready")"
authority_real_external="$(csv_value "$AK_SUMMARY_CSV" "real_external_benchmark_verified")"
authority_action="$(csv_value "$AK_SUMMARY_CSV" "action")"
authority_routing="$(csv_value "$AK_SUMMARY_CSV" "routing_trigger_rate")"
authority_jump="$(csv_value "$AK_SUMMARY_CSV" "active_jump_rate")"

codebase_mini_source_ready="$(csv_value "$AB_SUMMARY_CSV" "codebase_mini_source_ready")"
benchmark_result_artifact_verified="$(csv_value "$AB_SUMMARY_CSV" "benchmark_result_artifact_verified")"
baseline_comparison_ready="$(csv_value "$AB_SUMMARY_CSV" "baseline_comparison_ready")"
codebase_real_external="$(csv_value "$AB_SUMMARY_CSV" "real_external_benchmark_verified")"
artifact_dir="$(csv_value "$AB_SUMMARY_CSV" "artifact_dir")"
ab_span_exact="$(csv_value "$AB_SUMMARY_CSV" "span_exact")"
ab_chunk_exact="$(csv_value "$AB_SUMMARY_CSV" "chunk_exact")"
ab_missing_abstain="$(csv_value "$AB_SUMMARY_CSV" "missing_abstain")"
ab_near_miss_false_positive="$(csv_value "$AB_SUMMARY_CSV" "near_miss_false_positive")"
ab_wrong_answer_rate="$(csv_value "$AB_SUMMARY_CSV" "wrong_answer_rate")"
codebase_routing="$(csv_value "$AB_SUMMARY_CSV" "routing_trigger_rate")"
codebase_jump="$(csv_value "$AB_SUMMARY_CSV" "active_jump_rate")"

if [[ "$TRACE_SOURCE" == "generated-local-codebase-run" ]]; then
  write_trace_artifacts "$TRACE_DIR" "$artifact_dir"
fi

trace_artifact_files=0
trace_hash_manifest_entries=0
trace_hash_verified_files=0
if [[ -f "$TRACE_DIR/sha256sums.txt" ]]; then
  trace_hash_manifest_entries="$(awk 'NF >= 2 { count++ } END { print count + 0 }' "$TRACE_DIR/sha256sums.txt")"
fi

for file in "${REQUIRED_TRACE_FILES[@]}"; do
  path="$TRACE_DIR/$file"
  if [[ ! -f "$path" ]]; then
    continue
  fi
  ((trace_artifact_files += 1))
  expected="$(awk -v f="$file" '$2 == f { print $1; found = 1 } END { if (!found) exit 1 }' "$TRACE_DIR/sha256sums.txt" 2>/dev/null || true)"
  if [[ -n "$expected" ]]; then
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" == "$expected" ]]; then
      ((trace_hash_verified_files += 1))
    fi
  fi
done

dataset_rows=0
if [[ -f "$artifact_dir/dataset.jsonl" ]]; then
  dataset_rows="$(wc -l <"$artifact_dir/dataset.jsonl" | awk '{print $1}')"
fi
result_rows=0
if [[ -f "$artifact_dir/results/route_memory_results.jsonl" ]]; then
  result_rows="$(wc -l <"$artifact_dir/results/route_memory_results.jsonl" | awk '{print $1}')"
fi
query_trace_rows=0
dataset_bound_rows=0
result_bound_rows=0
runner_owned_evaluator_rows=0
independent_evaluator_rows=0
if [[ -f "$TRACE_DIR/query_trace.csv" ]]; then
  eval "$(
    awk -F, '
      NR > 1 {
        rows++
        dataset_bound += $3
        result_bound += $4
        runner_owned += $5
        independent += $6
      }
      END {
        printf "query_trace_rows=%d\n", rows + 0
        printf "dataset_bound_rows=%d\n", dataset_bound + 0
        printf "result_bound_rows=%d\n", result_bound + 0
        printf "runner_owned_evaluator_rows=%d\n", runner_owned + 0
        printf "independent_evaluator_rows=%d\n", independent + 0
      }
    ' "$TRACE_DIR/query_trace.csv"
  )"
fi

evaluator_output_rows=0
if [[ -f "$TRACE_DIR/evaluator_output.csv" ]]; then
  evaluator_output_rows="$(awk 'NR > 1 { rows++ } END { print rows + 0 }' "$TRACE_DIR/evaluator_output.csv")"
fi
matched_query_rows=0
if [[ "$query_trace_rows" -eq "$dataset_rows" &&
      "$evaluator_output_rows" -eq "$dataset_rows" &&
      "$result_rows" -eq "$dataset_rows" ]]; then
  matched_query_rows="$dataset_rows"
fi

metric_rows=0
if [[ -f "$TRACE_DIR/metrics_recomputed.csv" ]]; then
  metric_rows="$(awk 'NR > 1 { rows++ } END { print rows + 0 }' "$TRACE_DIR/metrics_recomputed.csv")"
fi
span_exact="$(metric_value "$TRACE_DIR/metrics_recomputed.csv" "span_exact")"
chunk_exact="$(metric_value "$TRACE_DIR/metrics_recomputed.csv" "chunk_exact")"
missing_abstain="$(metric_value "$TRACE_DIR/metrics_recomputed.csv" "missing_abstain")"
near_miss_false_positive="$(metric_value "$TRACE_DIR/metrics_recomputed.csv" "near_miss_false_positive")"
wrong_answer_rate="$(metric_value "$TRACE_DIR/metrics_recomputed.csv" "wrong_answer_rate")"

metrics_match_rows=0
[[ "$span_exact" == "$ab_span_exact" ]] && ((metrics_match_rows += 1))
[[ "$chunk_exact" == "$ab_chunk_exact" ]] && ((metrics_match_rows += 1))
[[ "$missing_abstain" == "$ab_missing_abstain" ]] && ((metrics_match_rows += 1))
[[ "$near_miss_false_positive" == "$ab_near_miss_false_positive" ]] && ((metrics_match_rows += 1))
[[ "$wrong_answer_rate" == "$ab_wrong_answer_rate" ]] && ((metrics_match_rows += 1))

codebase_run_evaluator_trace_ready=0
if [[ "$codebase_mini_source_ready" == "1" &&
      "$benchmark_result_artifact_verified" == "1" &&
      "$baseline_comparison_ready" == "1" &&
      "$trace_artifact_files" -eq "${#REQUIRED_TRACE_FILES[@]}" &&
      "$trace_hash_manifest_entries" -ge "${#REQUIRED_TRACE_FILES[@]}" &&
      "$trace_hash_verified_files" -eq "${#REQUIRED_TRACE_FILES[@]}" &&
      "$dataset_rows" -ge 7 &&
      "$matched_query_rows" -eq "$dataset_rows" &&
      "$dataset_bound_rows" -eq "$dataset_rows" &&
      "$result_bound_rows" -eq "$dataset_rows" &&
      "$runner_owned_evaluator_rows" -eq "$dataset_rows" &&
      "$metric_rows" -eq 5 &&
      "$metrics_match_rows" -eq 5 ]]; then
  codebase_run_evaluator_trace_ready=1
fi

external_family_coverage=0
if [[ "$codebase_run_evaluator_trace_ready" == "1" ]]; then
  external_family_coverage=1
fi
external_benchmark_run_evaluator_trace_ready=0
real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$authority_routing" -v b="$codebase_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$authority_jump" -v b="$codebase_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-codebase-mini-not-ready"
if [[ "$codebase_mini_source_ready" != "1" ||
      "$benchmark_result_artifact_verified" != "1" ||
      "$baseline_comparison_ready" != "1" ]]; then
  action="external-benchmark-codebase-mini-not-ready"
elif [[ "$trace_artifact_files" -ne "${#REQUIRED_TRACE_FILES[@]}" ]]; then
  action="external-benchmark-run-evaluator-trace-artifacts-missing"
elif [[ "$trace_hash_verified_files" -ne "${#REQUIRED_TRACE_FILES[@]}" ]]; then
  action="external-benchmark-run-evaluator-trace-hash-mismatch"
elif [[ "$matched_query_rows" -ne "$dataset_rows" ||
        "$dataset_bound_rows" -ne "$dataset_rows" ||
        "$result_bound_rows" -ne "$dataset_rows" ||
        "$runner_owned_evaluator_rows" -ne "$dataset_rows" ]]; then
  action="external-benchmark-run-evaluator-trace-query-binding-mismatch"
elif [[ "$metrics_match_rows" -ne 5 ]]; then
  action="external-benchmark-run-evaluator-trace-metric-mismatch"
elif [[ "$authority_promotion_evidence_ready" != "1" ]]; then
  action="external-benchmark-authority-promotion-evidence-not-ready"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-run-evaluator-trace-jump-guardrail-violated"
elif [[ "$codebase_run_evaluator_trace_ready" == "1" ]]; then
  action="codebase-run-evaluator-trace-ready-await-independent-all-family-run-evidence"
fi

{
  echo "benchmark_scope,trace_source,authority_promotion_evidence_ready,authority_real_external,authority_action,codebase_mini_source_ready,benchmark_result_artifact_verified,baseline_comparison_ready,codebase_real_external,artifact_dir,trace_dir,trace_artifact_files,trace_hash_manifest_entries,trace_hash_verified_files,dataset_rows,result_rows,query_trace_rows,evaluator_output_rows,matched_query_rows,dataset_bound_rows,result_bound_rows,runner_owned_evaluator_rows,independent_evaluator_rows,metric_rows,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,metrics_match_rows,codebase_run_evaluator_trace_ready,external_family_coverage,expected_external_families,external_benchmark_run_evaluator_trace_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08al,%s,%d,%d,%s,%d,%d,%d,%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%s,%s,%s\n" \
    "$TRACE_SOURCE" \
    "$authority_promotion_evidence_ready" \
    "$authority_real_external" \
    "$authority_action" \
    "$codebase_mini_source_ready" \
    "$benchmark_result_artifact_verified" \
    "$baseline_comparison_ready" \
    "$codebase_real_external" \
    "$artifact_dir" \
    "$TRACE_DIR" \
    "$trace_artifact_files" \
    "$trace_hash_manifest_entries" \
    "$trace_hash_verified_files" \
    "$dataset_rows" \
    "$result_rows" \
    "$query_trace_rows" \
    "$evaluator_output_rows" \
    "$matched_query_rows" \
    "$dataset_bound_rows" \
    "$result_bound_rows" \
    "$runner_owned_evaluator_rows" \
    "$independent_evaluator_rows" \
    "$metric_rows" \
    "$span_exact" \
    "$chunk_exact" \
    "$missing_abstain" \
    "$near_miss_false_positive" \
    "$wrong_answer_rate" \
    "$metrics_match_rows" \
    "$codebase_run_evaluator_trace_ready" \
    "$external_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$external_benchmark_run_evaluator_trace_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "authority-promotion-evidence,%s,ready=%d real=%d action=%s\n" \
    "$([[ "$authority_promotion_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$authority_promotion_evidence_ready" \
    "$authority_real_external" \
    "$authority_action"
  printf "codebase-mini-result,%s,source=%d result=%d baseline=%d\n" \
    "$([[ "$codebase_mini_source_ready" == "1" && "$benchmark_result_artifact_verified" == "1" && "$baseline_comparison_ready" == "1" ]] && echo pass || echo blocked)" \
    "$codebase_mini_source_ready" \
    "$benchmark_result_artifact_verified" \
    "$baseline_comparison_ready"
  printf "run-evaluator-trace-artifacts,%s,files=%d/%d hashes=%d/%d\n" \
    "$([[ "$trace_artifact_files" -eq "${#REQUIRED_TRACE_FILES[@]}" && "$trace_hash_verified_files" -eq "${#REQUIRED_TRACE_FILES[@]}" ]] && echo pass || echo blocked)" \
    "$trace_artifact_files" \
    "${#REQUIRED_TRACE_FILES[@]}" \
    "$trace_hash_verified_files" \
    "${#REQUIRED_TRACE_FILES[@]}"
  printf "run-evaluator-query-binding,%s,matched=%d dataset=%d result=%d trace=%d output=%d\n" \
    "$([[ "$matched_query_rows" -eq "$dataset_rows" && "$dataset_bound_rows" -eq "$dataset_rows" && "$result_bound_rows" -eq "$dataset_rows" && "$runner_owned_evaluator_rows" -eq "$dataset_rows" ]] && echo pass || echo blocked)" \
    "$matched_query_rows" \
    "$dataset_rows" \
    "$result_rows" \
    "$query_trace_rows" \
    "$evaluator_output_rows"
  printf "run-evaluator-metrics,%s,span=%s chunk=%s missing=%s near_miss_fp=%s wrong=%s matches=%d/5\n" \
    "$([[ "$metrics_match_rows" -eq 5 ]] && echo pass || echo blocked)" \
    "$span_exact" \
    "$chunk_exact" \
    "$missing_abstain" \
    "$near_miss_false_positive" \
    "$wrong_answer_rate" \
    "$metrics_match_rows"
  printf "codebase-run-evaluator-trace,%s,ready=%d runner_owned=%d independent=%d\n" \
    "$([[ "$codebase_run_evaluator_trace_ready" -eq 1 ]] && echo pass || echo blocked)" \
    "$codebase_run_evaluator_trace_ready" \
    "$runner_owned_evaluator_rows" \
    "$independent_evaluator_rows"
  printf "external-family-run-evaluator-coverage,%s,coverage=%d/%d\n" \
    blocked \
    "$external_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d action=%s\n" \
    blocked \
    "$real_external_benchmark_verified" \
    "$action"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "trace_dir: $TRACE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
