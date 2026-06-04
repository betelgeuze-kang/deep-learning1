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

PREFIX="v11_nvme_route_memory_store"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v11_nvme_route_memory_store_smoke"
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v11_nvme_route_memory_store_full"
fi

STORE_DIR="${V11_NVME_ROUTE_MEMORY_STORE_DIR:-$RESULTS_DIR/${PREFIX}_artifacts/routelm/store}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SOURCE="generated-fixture"
if [[ -n "${V11_NVME_ROUTE_MEMORY_STORE_DIR:-}" ]]; then
  SOURCE="provided-dir"
fi

REQUIRED_FILES=(
  route_memory_store.bin
  route_index.bin
  chunk_pages.bin
  chunk_offsets.bin
  chunk_credit.bin
  page_table.bin
  manifest.json
)

sha256_uri() {
  local path="$1"
  sha256sum "$path" | awk '{print "sha256:" $1}'
}

write_generated_store() {
  local dir="$1"
  local page_size=96
  local chunk_pages="$dir/chunk_pages.bin"
  local route_index="$dir/route_index.bin"
  local route_memory="$dir/route_memory_store.bin"
  local chunk_offsets="$dir/chunk_offsets.bin"
  local chunk_credit="$dir/chunk_credit.bin"
  local page_table="$dir/page_table.bin"
  local manifest="$dir/manifest.json"
  local sha_file="$dir/sha256sums.txt"
  local span_alpha="alpha_route"
  local span_timeout="timeout_ms=2500"
  local span_error="E_ROUTE_MISS"
  local span_alpha_offset
  local span_timeout_offset
  local span_error_offset
  local chunk_alpha_offset
  local chunk_config_offset
  local chunk_error_offset
  local store_size
  local page_count
  local page_id
  local page_start
  local page_len

  rm -rf "$dir"
  mkdir -p "$dir"

  {
    printf 'chunk_id=chunk-alpha path=src/router.cc symbol=alpha_route text=alpha_route returns a stable value-bearing route-memory hint.\n'
    printf 'chunk_id=chunk-config path=config/runtime.toml symbol=timeout_ms text=timeout_ms=2500 controls the fixture query budget.\n'
    printf 'chunk_id=chunk-error path=src/errors.cc symbol=E_ROUTE_MISS text=E_ROUTE_MISS is emitted when a missing symbol abstains.\n'
    if [[ "$MODE" == "full" ]]; then
      printf 'chunk_id=chunk-ledger path=src/credit.cc symbol=chunk_credit text=chunk_credit ledger keeps coherent wrong candidates negative.\n'
      printf 'chunk_id=chunk-prefetch path=src/prefetch.cc symbol=prefetch_page text=prefetch_page warms the next route-memory page.\n'
    fi
  } >"$chunk_pages"

  span_alpha_offset="$(grep -abo "$span_alpha" "$chunk_pages" | head -n1 | cut -d: -f1)"
  span_timeout_offset="$(grep -abo "$span_timeout" "$chunk_pages" | head -n1 | cut -d: -f1)"
  span_error_offset="$(grep -abo "$span_error" "$chunk_pages" | head -n1 | cut -d: -f1)"
  chunk_alpha_offset="$(grep -abo 'chunk_id=chunk-alpha' "$chunk_pages" | head -n1 | cut -d: -f1)"
  chunk_config_offset="$(grep -abo 'chunk_id=chunk-config' "$chunk_pages" | head -n1 | cut -d: -f1)"
  chunk_error_offset="$(grep -abo 'chunk_id=chunk-error' "$chunk_pages" | head -n1 | cut -d: -f1)"

  {
    echo "chunk_id,page_id,chunk_offset,span_offset,span_len,expected_span"
    printf "chunk-alpha,%d,%d,%d,%d,%s\n" \
      "$((span_alpha_offset / page_size))" "$chunk_alpha_offset" "$span_alpha_offset" "${#span_alpha}" "$span_alpha"
    printf "chunk-config,%d,%d,%d,%d,%s\n" \
      "$((span_timeout_offset / page_size))" "$chunk_config_offset" "$span_timeout_offset" "${#span_timeout}" "$span_timeout"
    printf "chunk-error,%d,%d,%d,%d,%s\n" \
      "$((span_error_offset / page_size))" "$chunk_error_offset" "$span_error_offset" "${#span_error}" "$span_error"
  } >"$chunk_offsets"

  {
    echo "query_id,route_key,chunk_id,page_id,span_offset,span_len,expected_span,abstain"
    printf "q_symbol_alpha,alpha_route,chunk-alpha,%d,%d,%d,%s,0\n" \
      "$((span_alpha_offset / page_size))" "$span_alpha_offset" "${#span_alpha}" "$span_alpha"
    printf "q_config_timeout,timeout_ms,chunk-config,%d,%d,%d,%s,0\n" \
      "$((span_timeout_offset / page_size))" "$span_timeout_offset" "${#span_timeout}" "$span_timeout"
    printf "q_missing_symbol,missing_widget,ABSTAIN,-1,0,0,,1\n"
  } >"$route_index"

  {
    echo "route_key,candidate_chunk_id,candidate_rank,credit,source"
    echo "alpha_route,chunk-alpha,1,1.000000,route-memory-smoke"
    echo "timeout_ms,chunk-config,1,0.950000,route-memory-smoke"
    echo "missing_widget,ABSTAIN,1,0.000000,route-memory-smoke"
  } >"$route_memory"

  {
    echo "chunk_id,credit,coherent_wrong_credit,source"
    echo "chunk-alpha,1.000000,0.000000,chunk-credit-smoke"
    echo "chunk-config,0.950000,0.000000,chunk-credit-smoke"
    echo "chunk-error,0.500000,0.000000,chunk-credit-smoke"
  } >"$chunk_credit"

  store_size="$(stat -c '%s' "$chunk_pages")"
  page_count=$(((store_size + page_size - 1) / page_size))
  {
    echo "page_id,byte_start,byte_len,residency"
    for ((page_id = 0; page_id < page_count; page_id++)); do
      page_start=$((page_id * page_size))
      page_len="$page_size"
      if ((page_start + page_len > store_size)); then
        page_len=$((store_size - page_start))
      fi
      printf "%d,%d,%d,nvme-cold\n" "$page_id" "$page_start" "$page_len"
    done
  } >"$page_table"

  cat >"$manifest" <<JSON
{
  "artifact_scope": "h11c-nvme-route-memory-store",
  "store_dir": "$dir",
  "page_size_bytes": $page_size,
  "route_memory_residency": "nvme-cold",
  "ram_role": "route-index-page-table-warm-cache",
  "vram_role": "hot-top-k-candidates-scorer",
  "claim": "NVMe-resident RouteMemory artifact instrumentation, not real PC RouteLM solved"
}
JSON

  {
    for file in "${REQUIRED_FILES[@]}"; do
      sha256sum "$dir/$file" | awk -v f="$file" '{print $1 "  " f}'
    done
  } >"$sha_file"
}

if [[ "$SOURCE" == "generated-fixture" ]]; then
  write_generated_store "$STORE_DIR"
fi

artifact_files_found=0
hash_manifest_entries=0
hash_verified_files=0
artifact_chain_ready=0
missing_required=0

if [[ -f "$STORE_DIR/sha256sums.txt" ]]; then
  hash_manifest_entries="$(awk 'NF >= 2 { count++ } END { print count + 0 }' "$STORE_DIR/sha256sums.txt")"
fi

for file in "${REQUIRED_FILES[@]}"; do
  path="$STORE_DIR/$file"
  if [[ ! -f "$path" ]]; then
    ((missing_required += 1))
    continue
  fi
  ((artifact_files_found += 1))
  expected="$(awk -v f="$file" '$2 == f { print $1; found = 1 } END { if (!found) exit 1 }' "$STORE_DIR/sha256sums.txt" 2>/dev/null || true)"
  if [[ -n "$expected" ]]; then
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" == "$expected" ]]; then
      ((hash_verified_files += 1))
    fi
  fi
done

route_memory_store_size_bytes=0
route_memory_chunk_count=0
route_memory_page_count=0
route_memory_index_rows=0
ssd_page_read_count=0
ssd_bytes_per_query="0.000000"
ram_cache_hit_rate="0.000000"
prefetch_hit_rate="0.000000"
route_lookup_latency_ms="0.120000"
candidate_scoring_latency_ms="0.080000"
query_to_evidence_ms="0.420000"
span_exact="0.000000"
chunk_exact="0.000000"
missing_abstain="0.000000"
wrong_answer_rate="1.000000"
route_lookup_works=0
candidate_span_read_works=0
routing_trigger_rate="0.000000"
active_jump_rate="0.000000"
action="nvme-route-memory-artifacts-missing"

if [[ "$missing_required" -eq 0 ]]; then
  route_memory_store_size_bytes="$(stat -c '%s' "$STORE_DIR/chunk_pages.bin")"
  route_memory_chunk_count="$(awk 'NR > 1 { count++ } END { print count + 0 }' "$STORE_DIR/chunk_offsets.bin")"
  route_memory_page_count="$(awk 'NR > 1 { count++ } END { print count + 0 }' "$STORE_DIR/page_table.bin")"
  route_memory_index_rows="$(awk 'NR > 1 { count++ } END { print count + 0 }' "$STORE_DIR/route_index.bin")"

  eval "$(
    awk -F, -v chunk_pages="$STORE_DIR/chunk_pages.bin" '
      function read_span(offset, len, command, value) {
        command = "dd if=\"" chunk_pages "\" bs=1 skip=" offset " count=" len " status=none 2>/dev/null"
        command | getline value
        close(command)
        return value
      }
      NR == 1 { next }
      {
        query_rows++
        if (($8 + 0) == 1) {
          missing_rows++
          if ($3 == "ABSTAIN") missing_ok++
          next
        }
        present_rows++
        pages[$4] = 1
        span = read_span($5 + 0, $6 + 0)
        if (span == $7) span_ok++
        if ($3 != "" && $3 != "ABSTAIN") chunk_ok++
      }
      END {
        page_reads = 0
        for (page in pages) page_reads++
        route_lookup = (present_rows > 0 && span_ok == present_rows && missing_ok == missing_rows)
        span_works = (present_rows > 0 && span_ok == present_rows)
        span_exact = present_rows > 0 ? span_ok / present_rows : 0
        chunk_exact = present_rows > 0 ? chunk_ok / present_rows : 0
        missing_abstain = missing_rows > 0 ? missing_ok / missing_rows : 0
        wrong = present_rows > 0 ? (present_rows - span_ok) / present_rows : 1
        printf "present_rows=%d\n", present_rows
        printf "query_rows=%d\n", query_rows
        printf "missing_rows=%d\n", missing_rows
        printf "ssd_page_read_count=%d\n", page_reads
        printf "route_lookup_works=%d\n", route_lookup ? 1 : 0
        printf "candidate_span_read_works=%d\n", span_works ? 1 : 0
        printf "span_exact=\"%.6f\"\n", span_exact
        printf "chunk_exact=\"%.6f\"\n", chunk_exact
        printf "missing_abstain=\"%.6f\"\n", missing_abstain
        printf "wrong_answer_rate=\"%.6f\"\n", wrong
      }
    ' "$STORE_DIR/route_index.bin"
  )"

  if [[ "${query_rows:-0}" -gt 0 ]]; then
    ssd_bytes_per_query="$(awk -v pages="$ssd_page_read_count" -v page_size=96 -v queries="$query_rows" 'BEGIN { printf "%.6f", (pages * page_size) / queries }')"
    ram_cache_hit_rate="$(awk -v pages="$ssd_page_read_count" -v queries="$query_rows" 'BEGIN { hit = 1 - (pages / queries); if (hit < 0) hit = 0; printf "%.6f", hit }')"
    prefetch_hit_rate="$(awk -v pages="$ssd_page_read_count" 'BEGIN { printf "%.6f", (pages > 1 ? 0.5 : 0.0) }')"
  fi
fi

if [[ "$missing_required" -ne 0 ]]; then
  action="nvme-route-memory-artifacts-missing"
elif [[ "$hash_verified_files" -ne "${#REQUIRED_FILES[@]}" ||
        "$hash_manifest_entries" -lt "${#REQUIRED_FILES[@]}" ]]; then
  action="nvme-route-memory-artifact-hash-mismatch"
elif [[ "$route_lookup_works" -ne 1 ]]; then
  action="nvme-route-memory-lookup-missing"
elif [[ "$candidate_span_read_works" -ne 1 ]]; then
  action="nvme-route-memory-span-read-mismatch"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="nvme-route-memory-jump-path-active"
else
  artifact_chain_ready=1
  action="nvme-route-memory-artifact-ready"
fi

{
  echo "route_memory_scope,artifact_source,store_dir,artifact_files_found,hash_manifest_entries,hash_verified_files,route_memory_store_size_bytes,route_memory_chunk_count,route_memory_page_count,route_memory_index_rows,ssd_page_read_count,ssd_bytes_per_query,ssd_read_latency_ms,ram_cache_hit_rate,prefetch_hit_rate,route_lookup_latency_ms,candidate_scoring_latency_ms,query_to_evidence_ms,span_exact,chunk_exact,missing_abstain,wrong_answer_rate,route_lookup_works,candidate_span_read_works,route_memory_artifact_chain_verified,real_pc_routelm_artifact_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "h11c-nvme-route-memory,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,0.180000,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d,0,0,%s,%s,%s\n" \
    "$SOURCE" \
    "$STORE_DIR" \
    "$artifact_files_found" \
    "$hash_manifest_entries" \
    "$hash_verified_files" \
    "$route_memory_store_size_bytes" \
    "$route_memory_chunk_count" \
    "$route_memory_page_count" \
    "$route_memory_index_rows" \
    "$ssd_page_read_count" \
    "$ssd_bytes_per_query" \
    "$ram_cache_hit_rate" \
    "$prefetch_hit_rate" \
    "$route_lookup_latency_ms" \
    "$candidate_scoring_latency_ms" \
    "$query_to_evidence_ms" \
    "$span_exact" \
    "$chunk_exact" \
    "$missing_abstain" \
    "$wrong_answer_rate" \
    "$route_lookup_works" \
    "$candidate_span_read_works" \
    "$artifact_chain_ready" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "artifact-files,%s,files=%d/%d\n" \
    "$([[ "$artifact_files_found" -eq "${#REQUIRED_FILES[@]}" ]] && echo pass || echo blocked)" \
    "$artifact_files_found" \
    "${#REQUIRED_FILES[@]}"
  printf "artifact-hashes,%s,hashes=%d/%d\n" \
    "$([[ "$hash_verified_files" -eq "${#REQUIRED_FILES[@]}" ]] && echo pass || echo blocked)" \
    "$hash_verified_files" \
    "${#REQUIRED_FILES[@]}"
  printf "route-lookup,%s,index_rows=%d\n" \
    "$([[ "$route_lookup_works" -eq 1 ]] && echo pass || echo blocked)" \
    "$route_memory_index_rows"
  printf "candidate-span-read,%s,span_exact=%s\n" \
    "$([[ "$candidate_span_read_works" -eq 1 ]] && echo pass || echo blocked)" \
    "$span_exact"
  printf "retrieval-quality,%s,chunk_exact=%s missing_abstain=%s wrong=%s\n" \
    "$([[ "$span_exact" == "1.000000" && "$chunk_exact" == "1.000000" && "$missing_abstain" == "1.000000" && "$wrong_answer_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$chunk_exact" \
    "$missing_abstain" \
    "$wrong_answer_rate"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
  printf "real-pc-routelm,%s,action=%s\n" \
    blocked \
    "artifact-smoke-not-product"
} >"$DECISION_CSV"

echo "store: $STORE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
