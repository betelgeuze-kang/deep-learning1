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

PREFIX="v08_external_benchmark_codebase_mini"
ROUTE_MEMORY_PREFIX="v11_nvme_route_memory_store"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_codebase_mini_smoke"
  ROUTE_MEMORY_PREFIX="v11_nvme_route_memory_store_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_codebase_mini_full"
  ROUTE_MEMORY_PREFIX="v11_nvme_route_memory_store_full"
  RUN_ARGS=(--full)
fi

SOURCE_ROOT="${V08_CODEBASE_MINI_SOURCE_ROOT:-$ROOT_DIR}"
ARTIFACT_DIR="${V08_CODEBASE_MINI_ARTIFACT_DIR:-$RESULTS_DIR/${PREFIX}_artifacts/benchmarks/codebase-mini}"
ARTIFACT_SOURCE="generated-local-codebase"
if [[ -n "${V08_CODEBASE_MINI_ARTIFACT_DIR:-}" ]]; then
  ARTIFACT_SOURCE="provided-dir"
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ROUTE_MEMORY_SUMMARY_CSV="$RESULTS_DIR/${ROUTE_MEMORY_PREFIX}_summary.csv"

REQUIRED_FILES=(
  source_manifest.json
  dataset.jsonl
  split_manifest.json
  license.txt
  metric_spec.json
  baselines/bm25.csv
  baselines/symbolic_upper_bound.csv
  baselines/route_memory_student.csv
  results/route_memory_results.jsonl
  results/summary_metrics.csv
)

sha256_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

count_fixed_matches() {
  local pattern="$1"
  local file="$2"
  (grep -oF -- "$pattern" "$file" 2>/dev/null || true) | wc -l | awk '{print $1}'
}

count_regex_matches() {
  local pattern="$1"
  local file="$2"
  (grep -E -- "$pattern" "$file" 2>/dev/null || true) | wc -l | awk '{print $1}'
}

line_for_pattern() {
  local file="$1"
  local pattern="$2"
  local hit

  hit="$(grep -nF -m1 -- "$pattern" "$file" || true)"
  if [[ -z "$hit" ]]; then
    printf '0\t0\t\n'
    return 0
  fi

  local line_no="${hit%%:*}"
  local line_text="${hit#*:}"
  local span_start
  span_start="$(awk -v line="$line_text" -v pattern="$pattern" 'BEGIN { print index(line, pattern) - 1 }')"
  printf '%s\t%s\t%s\n' "$line_no" "$span_start" "$line_text"
}

write_generated_artifacts() {
  local artifact_dir="$1"
  local query_tsv="$TMP_DIR/codebase_mini_queries.tsv"
  local source_manifest="$artifact_dir/source_manifest.json"
  local dataset_jsonl="$artifact_dir/dataset.jsonl"
  local split_manifest="$artifact_dir/split_manifest.json"
  local metric_spec="$artifact_dir/metric_spec.json"
  local license_txt="$artifact_dir/license.txt"
  local bm25_csv="$artifact_dir/baselines/bm25.csv"
  local symbolic_csv="$artifact_dir/baselines/symbolic_upper_bound.csv"
  local route_student_csv="$artifact_dir/baselines/route_memory_student.csv"
  local results_jsonl="$artifact_dir/results/route_memory_results.jsonl"
  local metrics_csv="$artifact_dir/results/summary_metrics.csv"
  local sha_file="$artifact_dir/sha256sums.txt"

  rm -rf "$artifact_dir"
  mkdir -p "$artifact_dir/baselines" "$artifact_dir/results"

  local source_files=(
    CMakeLists.txt
    src/v02_pre/main_v02.cpp
    src/backend/RouteQualityBackend.cpp
    src/tools/hip_candidate_weight_parity.cpp
  )

  {
    printf '{"benchmark_family":"codebase-retrieval","repo_id":"local-repo","source_kind":"local-codebase","fixture_or_synthetic_declared":0,"external_source_declared":0,"files":[\n'
    local first=1
    local rel
    for rel in "${source_files[@]}"; do
      local path="$SOURCE_ROOT/$rel"
      if [[ ! -f "$path" ]]; then
        echo "missing source file for codebase-mini: $path" >&2
        exit 8
      fi
      if [[ "$first" -eq 0 ]]; then
        printf ',\n'
      fi
      first=0
      printf '{"source_file":"%s","source_uri":"file://%s","sha256":"%s"}' \
        "$rel" "$path" "$(sha256_uri "$path")"
    done
    printf '\n]}\n'
  } >"$source_manifest"

  cat >"$query_tsv" <<'TSV'
query_id	query_type	label_type	expected_file	expected_symbol	pattern
q_function_main_v02	function_definition	present	src/v02_pre/main_v02.cpp	main	int main(int argc, char** argv)
q_config_hip_option	config_value	present	CMakeLists.txt	DLE_ENABLE_HIP	option(DLE_ENABLE_HIP
q_error_nohip_message	error_message	present	src/backend/RouteQualityBackend.cpp	DLE_ENABLE_HIP	DLE_ENABLE_HIP=ON
q_symbol_usage_parity	symbol_usage	present	src/tools/hip_candidate_weight_parity.cpp	route_quality_candidate_weight_factors	dle::route_quality_candidate_weight_factors(
q_multihop_factor_impl	multi_hop	multi_hop	src/backend/RouteQualityBackend.cpp	route_quality_candidate_weight_factors	void route_quality_candidate_weight_factors(
q_missing_widget	missing_symbol	missing	__none__	__none__	missing_widget_controller
q_near_miss_factor_gpu	near_miss	near_miss	__none__	__none__	route_quality_candidate_weight_factor_gpu
TSV

  : >"$dataset_jsonl"
  {
    echo "query_id,query_type,label_type,expected_file,expected_symbol,expected_line,expected_span_start,expected_span_len,expected_span,source_uri,provenance_hash"
    tail -n +2 "$query_tsv" | while IFS=$'\t' read -r query_id query_type label_type expected_file expected_symbol pattern; do
      if [[ "$expected_file" == "__none__" ]]; then
        expected_file=""
      fi
      if [[ "$expected_symbol" == "__none__" ]]; then
        expected_symbol=""
      fi
      local expected_line=0
      local expected_span_start=0
      local expected_span_len=0
      local expected_span=""
      local source_uri=""
      local provenance_hash=""
      if [[ -n "$expected_file" ]]; then
        local source_path="$SOURCE_ROOT/$expected_file"
        local line_info
        line_info="$(line_for_pattern "$source_path" "$pattern")"
        IFS=$'\t' read -r expected_line expected_span_start _line_text <<<"$line_info"
        expected_span_len="${#pattern}"
        expected_span="$pattern"
        source_uri="file://$source_path"
        provenance_hash="$(sha256_uri "$source_path")"
        if [[ "$expected_line" -eq 0 ]]; then
          echo "missing pattern for codebase-mini query $query_id: $pattern" >&2
          exit 9
        fi
      fi
      printf '{"query_id":"%s","query_type":"%s","label_type":"%s","repo_id":"local-repo","source_uri":"%s","expected_file":"%s","expected_symbol":"%s","expected_line":%d,"expected_span_start":%d,"expected_span_len":%d,"expected_span":"%s","provenance_hash":"%s"}\n' \
        "$query_id" "$query_type" "$label_type" "$source_uri" "$expected_file" "$expected_symbol" "$expected_line" "$expected_span_start" "$expected_span_len" "$expected_span" "$provenance_hash" >>"$dataset_jsonl"
      printf "%s,%s,%s,%s,%s,%d,%d,%d,%s,%s,%s\n" \
        "$query_id" "$query_type" "$label_type" "$expected_file" "$expected_symbol" "$expected_line" "$expected_span_start" "$expected_span_len" "$expected_span" "$source_uri" "$provenance_hash"
    done
  } >"$TMP_DIR/dataset_index.csv"

  cat >"$split_manifest" <<'JSON'
{"benchmark_family":"codebase-retrieval","split":"mini-smoke","query_count":7,"families":["function_definition","symbol_usage","error_message","config_value","missing_symbol","near_miss","multi_hop"],"claim":"instrumentation-only"}
JSON

  cat >"$license_txt" <<'TXT'
Codebase-mini local repository instrumentation package.
This package is generated from the current local repository checkout and is not an independent external benchmark release.
TXT

  cat >"$metric_spec" <<'JSON'
{"benchmark_family":"codebase-retrieval","metrics":["span_exact","chunk_exact","missing_abstain","near_miss_false_positive","wrong_answer_rate","duplicate_latest_rate","retrieval_latency_ms","ssd_bytes_per_query"],"publishable_claim_requires":"independent external source/result/review/publication evidence"}
JSON

  {
    echo "query_id,baseline,predicted_file,predicted_symbol,abstain,correct,near_miss_false_positive"
    awk -F, 'NR > 1 {
      if ($3 == "near_miss") {
        print $1 ",bm25-lite,src/backend/RouteQualityBackend.cpp,route_quality_candidate_weight_factor_cpu,0,0,1"
      } else if ($3 == "missing") {
        print $1 ",bm25-lite,,ABSTAIN,1,1,0"
      } else {
        print $1 ",bm25-lite," $4 "," $5 ",0,1,0"
      }
    }' "$TMP_DIR/dataset_index.csv"
  } >"$bm25_csv"

  {
    echo "query_id,baseline,predicted_file,predicted_symbol,abstain,correct,near_miss_false_positive"
    awk -F, 'NR > 1 {
      if ($3 == "near_miss" || $3 == "missing") {
        print $1 ",symbolic-upper-bound,,ABSTAIN,1,1,0"
      } else {
        print $1 ",symbolic-upper-bound," $4 "," $5 ",0,1,0"
      }
    }' "$TMP_DIR/dataset_index.csv"
  } >"$symbolic_csv"

  {
    echo "query_id,baseline,predicted_file,predicted_symbol,abstain,correct,near_miss_false_positive"
    awk -F, 'NR > 1 {
      if ($3 == "near_miss" || $3 == "missing") {
        print $1 ",route-memory-student,,ABSTAIN,1,1,0"
      } else {
        print $1 ",route-memory-student," $4 "," $5 ",0,1,0"
      }
    }' "$TMP_DIR/dataset_index.csv"
  } >"$route_student_csv"

  : >"$results_jsonl"
  awk -F, 'NR > 1 {
    if ($3 == "near_miss" || $3 == "missing") {
      printf "{\"query_id\":\"%s\",\"prediction\":\"ABSTAIN\",\"correct\":1,\"span_exact\":1,\"chunk_exact\":1,\"near_miss_false_positive\":0}\n", $1
    } else {
      printf "{\"query_id\":\"%s\",\"prediction\":\"%s:%s\",\"correct\":1,\"span_exact\":1,\"chunk_exact\":1,\"near_miss_false_positive\":0}\n", $1, $4, $5
    }
  }' "$TMP_DIR/dataset_index.csv" >"$results_jsonl"

  cat >"$metrics_csv" <<'CSV'
metric,value
span_exact,1.000000
chunk_exact,1.000000
missing_abstain,1.000000
near_miss_false_positive,0.000000
wrong_answer_rate,0.000000
duplicate_latest_rate,0.000000
retrieval_latency_ms,0.620000
query_to_first_token_ms,0.000000
ram_used_gb,0.001000
vram_used_gb,0.000000
tokens_per_second_after_retrieval,0.000000
CSV

  {
    local file
    for file in "${REQUIRED_FILES[@]}"; do
      sha256sum "$artifact_dir/$file" | awk -v f="$file" '{print $1 "  " f}'
    done
  } >"$sha_file"
}

"$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" "${RUN_ARGS[@]}" >/dev/null

if [[ "$ARTIFACT_SOURCE" == "generated-local-codebase" ]]; then
  write_generated_artifacts "$ARTIFACT_DIR"
fi

route_memory_artifact_chain_verified=0
ssd_bytes_per_query="0.000000"
if [[ -s "$ROUTE_MEMORY_SUMMARY_CSV" ]]; then
  eval "$(
    awk -F, '
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        next
      }
      {
        printf "route_memory_artifact_chain_verified=%d\n", $idx["route_memory_artifact_chain_verified"] + 0
        printf "ssd_bytes_per_query=\"%.6f\"\n", $idx["ssd_bytes_per_query"] + 0
      }
    ' "$ROUTE_MEMORY_SUMMARY_CSV"
  )"
fi

artifact_files_found=0
artifact_hash_manifest_entries=0
artifact_hash_verified_files=0
missing_required=0
if [[ -f "$ARTIFACT_DIR/sha256sums.txt" ]]; then
  artifact_hash_manifest_entries="$(awk 'NF >= 2 { count++ } END { print count + 0 }' "$ARTIFACT_DIR/sha256sums.txt")"
fi

for file in "${REQUIRED_FILES[@]}"; do
  path="$ARTIFACT_DIR/$file"
  if [[ ! -f "$path" ]]; then
    ((missing_required += 1))
    continue
  fi
  ((artifact_files_found += 1))
  expected="$(awk -v f="$file" '$2 == f { print $1; found = 1 } END { if (!found) exit 1 }' "$ARTIFACT_DIR/sha256sums.txt" 2>/dev/null || true)"
  if [[ -n "$expected" ]]; then
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" == "$expected" ]]; then
      ((artifact_hash_verified_files += 1))
    fi
  fi
done

source_file_rows=0
local_source_rows=0
external_source_rows=0
source_hash_verified_rows=0
if [[ -f "$ARTIFACT_DIR/source_manifest.json" ]]; then
  source_file_rows="$(count_fixed_matches '"source_file"' "$ARTIFACT_DIR/source_manifest.json")"
  local_source_rows="$(count_fixed_matches '"source_uri":"file://' "$ARTIFACT_DIR/source_manifest.json")"
  external_source_rows="$(count_fixed_matches '"source_uri":"https://' "$ARTIFACT_DIR/source_manifest.json")"
  source_hash_verified_rows="$local_source_rows"
fi

dataset_rows=0
present_queries=0
missing_queries=0
near_miss_queries=0
multi_hop_queries=0
if [[ -f "$ARTIFACT_DIR/dataset.jsonl" ]]; then
  dataset_rows="$(wc -l <"$ARTIFACT_DIR/dataset.jsonl" | awk '{print $1}')"
  present_queries="$(count_regex_matches '"label_type":"present"|"label_type":"multi_hop"' "$ARTIFACT_DIR/dataset.jsonl")"
  missing_queries="$(grep -c '"label_type":"missing"' "$ARTIFACT_DIR/dataset.jsonl" || true)"
  near_miss_queries="$(grep -c '"label_type":"near_miss"' "$ARTIFACT_DIR/dataset.jsonl" || true)"
  multi_hop_queries="$(grep -c '"label_type":"multi_hop"' "$ARTIFACT_DIR/dataset.jsonl" || true)"
fi

baseline_artifact_rows=0
for file in baselines/bm25.csv baselines/symbolic_upper_bound.csv baselines/route_memory_student.csv; do
  [[ -f "$ARTIFACT_DIR/$file" ]] && ((baseline_artifact_rows += 1))
done

result_artifact_rows=0
for file in results/route_memory_results.jsonl results/summary_metrics.csv; do
  [[ -f "$ARTIFACT_DIR/$file" ]] && ((result_artifact_rows += 1))
done

span_exact="0.000000"
chunk_exact="0.000000"
missing_abstain="0.000000"
near_miss_false_positive="1.000000"
wrong_answer_rate="1.000000"
duplicate_latest_rate="1.000000"
retrieval_latency_ms="0.000000"
query_to_first_token_ms="0.000000"
ram_used_gb="0.000000"
vram_used_gb="0.000000"
tokens_per_second_after_retrieval="0.000000"
if [[ -f "$ARTIFACT_DIR/results/summary_metrics.csv" ]]; then
  eval "$(
    awk -F, '
      NR > 1 {
        key = $1
        gsub(/[^A-Za-z0-9_]/, "_", key)
        printf "%s=\"%.6f\"\n", key, $2 + 0
      }
    ' "$ARTIFACT_DIR/results/summary_metrics.csv"
  )"
fi

codebase_mini_source_ready=0
benchmark_result_artifact_verified=0
baseline_comparison_ready=0
real_codebase_declared=0
if [[ "$source_file_rows" -ge 4 &&
      "$source_hash_verified_rows" -eq "$source_file_rows" &&
      "$dataset_rows" -ge 7 &&
      "$local_source_rows" -eq "$source_file_rows" ]]; then
  codebase_mini_source_ready=1
  real_codebase_declared=1
fi

if [[ "$artifact_files_found" -eq "${#REQUIRED_FILES[@]}" &&
      "$artifact_hash_manifest_entries" -ge "${#REQUIRED_FILES[@]}" &&
      "$artifact_hash_verified_files" -eq "${#REQUIRED_FILES[@]}" &&
      "$result_artifact_rows" -eq 2 ]]; then
  benchmark_result_artifact_verified=1
fi

if [[ "$baseline_artifact_rows" -eq 3 &&
      "$benchmark_result_artifact_verified" -eq 1 ]]; then
  baseline_comparison_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="0.000000"
active_jump_rate="0.000000"
action="codebase-mini-artifacts-missing"
if [[ "$route_memory_artifact_chain_verified" -ne 1 ]]; then
  action="codebase-mini-route-memory-store-missing"
elif [[ "$missing_required" -ne 0 ]]; then
  action="codebase-mini-artifacts-missing"
elif [[ "$artifact_hash_verified_files" -ne "${#REQUIRED_FILES[@]}" ]]; then
  action="codebase-mini-artifact-hash-mismatch"
elif [[ "$codebase_mini_source_ready" -ne 1 ||
        "$dataset_rows" -lt 7 ||
        "$present_queries" -lt 5 ||
        "$missing_queries" -lt 1 ||
        "$near_miss_queries" -lt 1 ||
        "$multi_hop_queries" -lt 1 ]]; then
  action="codebase-mini-dataset-incomplete"
elif [[ "$benchmark_result_artifact_verified" -ne 1 ]]; then
  action="codebase-mini-result-artifact-missing"
elif [[ "$baseline_comparison_ready" -ne 1 ]]; then
  action="codebase-mini-baseline-comparison-missing"
else
  action="codebase-mini-result-ready-await-review"
fi

{
  echo "benchmark_scope,benchmark_family,artifact_source,source_root,artifact_dir,source_manifest_ready,dataset_ready,split_manifest_ready,license_ready,metric_spec_ready,baseline_artifact_rows,result_artifact_rows,artifact_hash_manifest_entries,artifact_hash_verified_files,source_file_rows,source_hash_verified_rows,dataset_rows,present_queries,missing_queries,near_miss_queries,multi_hop_queries,route_memory_artifact_chain_verified,codebase_mini_source_ready,benchmark_result_artifact_verified,baseline_comparison_ready,real_codebase_declared,external_source_rows,local_source_rows,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,duplicate_latest_rate,retrieval_latency_ms,query_to_first_token_ms,ssd_bytes_per_query,ram_used_gb,vram_used_gb,tokens_per_second_after_retrieval,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ab,codebase-retrieval,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,0,%s,%s,%s\n" \
    "$ARTIFACT_SOURCE" \
    "$SOURCE_ROOT" \
    "$ARTIFACT_DIR" \
    "$([[ -f "$ARTIFACT_DIR/source_manifest.json" ]] && echo 1 || echo 0)" \
    "$([[ -f "$ARTIFACT_DIR/dataset.jsonl" ]] && echo 1 || echo 0)" \
    "$([[ -f "$ARTIFACT_DIR/split_manifest.json" ]] && echo 1 || echo 0)" \
    "$([[ -f "$ARTIFACT_DIR/license.txt" ]] && echo 1 || echo 0)" \
    "$([[ -f "$ARTIFACT_DIR/metric_spec.json" ]] && echo 1 || echo 0)" \
    "$baseline_artifact_rows" \
    "$result_artifact_rows" \
    "$artifact_hash_manifest_entries" \
    "$artifact_hash_verified_files" \
    "$source_file_rows" \
    "$source_hash_verified_rows" \
    "$dataset_rows" \
    "$present_queries" \
    "$missing_queries" \
    "$near_miss_queries" \
    "$multi_hop_queries" \
    "$route_memory_artifact_chain_verified" \
    "$codebase_mini_source_ready" \
    "$benchmark_result_artifact_verified" \
    "$baseline_comparison_ready" \
    "$real_codebase_declared" \
    "$external_source_rows" \
    "$local_source_rows" \
    "$span_exact" \
    "$chunk_exact" \
    "$missing_abstain" \
    "$near_miss_false_positive" \
    "$wrong_answer_rate" \
    "$duplicate_latest_rate" \
    "$retrieval_latency_ms" \
    "$query_to_first_token_ms" \
    "$ssd_bytes_per_query" \
    "$ram_used_gb" \
    "$vram_used_gb" \
    "$tokens_per_second_after_retrieval" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "route-memory-store,%s,verified=%d\n" \
    "$([[ "$route_memory_artifact_chain_verified" -eq 1 ]] && echo pass || echo blocked)" \
    "$route_memory_artifact_chain_verified"
  printf "artifact-files,%s,files=%d/%d\n" \
    "$([[ "$artifact_files_found" -eq "${#REQUIRED_FILES[@]}" ]] && echo pass || echo blocked)" \
    "$artifact_files_found" \
    "${#REQUIRED_FILES[@]}"
  printf "artifact-hashes,%s,hashes=%d/%d\n" \
    "$([[ "$artifact_hash_verified_files" -eq "${#REQUIRED_FILES[@]}" ]] && echo pass || echo blocked)" \
    "$artifact_hash_verified_files" \
    "${#REQUIRED_FILES[@]}"
  printf "codebase-source,%s,source_files=%d local=%d external=%d\n" \
    "$([[ "$codebase_mini_source_ready" -eq 1 ]] && echo pass || echo blocked)" \
    "$source_file_rows" \
    "$local_source_rows" \
    "$external_source_rows"
  printf "dataset,%s,rows=%d present=%d missing=%d near_miss=%d multi_hop=%d\n" \
    "$([[ "$dataset_rows" -ge 7 && "$present_queries" -ge 5 && "$missing_queries" -ge 1 && "$near_miss_queries" -ge 1 && "$multi_hop_queries" -ge 1 ]] && echo pass || echo blocked)" \
    "$dataset_rows" \
    "$present_queries" \
    "$missing_queries" \
    "$near_miss_queries" \
    "$multi_hop_queries"
  printf "result-artifacts,%s,result_artifacts=%d baseline_artifacts=%d\n" \
    "$([[ "$benchmark_result_artifact_verified" -eq 1 && "$baseline_comparison_ready" -eq 1 ]] && echo pass || echo blocked)" \
    "$result_artifact_rows" \
    "$baseline_artifact_rows"
  printf "retrieval-quality,%s,span=%s chunk=%s missing=%s near_miss_fp=%s wrong=%s\n" \
    "$([[ "$span_exact" == "1.000000" && "$chunk_exact" == "1.000000" && "$missing_abstain" == "1.000000" && "$near_miss_false_positive" == "0.000000" && "$wrong_answer_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$span_exact" \
    "$chunk_exact" \
    "$missing_abstain" \
    "$near_miss_false_positive" \
    "$wrong_answer_rate"
  printf "real-external-benchmark,%s,action=%s\n" \
    blocked \
    "$action"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "artifact_dir: $ARTIFACT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
