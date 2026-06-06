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

PREFIX="v13_routelm_mmap_reader"
BINDER_ARGS=()
BINDER_PREFIX="v13_real_run_binder_manifest"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_routelm_mmap_reader_smoke"
  BINDER_ARGS=(--smoke)
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_routelm_mmap_reader_full"
  BINDER_ARGS=(--full)
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_ROUTELM_MMAP_READER_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_ROUTELM_MMAP_READER_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

REQUIRED_STORE_FILES=(
  route_memory_store.bin
  route_index.bin
  chunk_pages.bin
  chunk_offsets.bin
  chunk_credit.bin
  page_table.bin
  manifest.json
)

verify_hash_manifest() {
  local dir="$1"
  local manifest="$dir/sha256sums.txt"

  if [[ ! -f "$manifest" ]]; then
    printf '0,0\n'
    return 0
  fi
  (
    cd "$dir"
    awk '
      NF >= 2 {
        entries++
        expected = $1
        file = $2
        command = "sha256sum \"" file "\" 2>/dev/null"
        command | getline line
        close(command)
        split(line, parts, " ")
        if (parts[1] == expected) verified++
      }
      END {
        printf "%d,%d\n", entries + 0, verified + 0
      }
    ' sha256sums.txt
  )
}

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  "$ROOT_DIR/experiments/run_v13_real_run_binder_manifest.sh" "${BINDER_ARGS[@]}" >/dev/null
fi

STORE_DIR="$RUN_DIR/store"
store_files_found=0
for file in "${REQUIRED_STORE_FILES[@]}"; do
  if [[ -f "$STORE_DIR/$file" ]]; then
    ((store_files_found += 1))
  fi
done

IFS=, read -r run_hash_entries run_hash_verified <<<"$(verify_hash_manifest "$RUN_DIR")"
run_hash_manifest_ready=0
if [[ "$run_hash_entries" -gt 0 && "$run_hash_entries" -eq "$run_hash_verified" ]]; then
  run_hash_manifest_ready=1
fi

IFS=, read -r store_hash_entries store_hash_verified <<<"$(verify_hash_manifest "$STORE_DIR")"
store_hash_manifest_ready=0
if [[ "$store_hash_entries" -gt 0 && "$store_hash_entries" -eq "$store_hash_verified" ]]; then
  store_hash_manifest_ready=1
fi

reader_metrics="$(
  python3 - "$RUN_DIR" <<'PY'
import csv
import json
import mmap
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
store = run_dir / "store"

metrics = {
    "manifest_page_size_bytes": 0,
    "page_table_rows": 0,
    "page_table_contiguous": 0,
    "route_index_rows": 0,
    "present_query_rows": 0,
    "missing_query_rows": 0,
    "route_memory_rows": 0,
    "chunk_offset_rows": 0,
    "mmap_opened": 0,
    "mmap_span_reads": 0,
    "mmap_page_reads": 0,
    "span_matches": 0,
    "span_mismatches": 0,
    "chunk_offset_matches": 0,
    "route_key_matches": 0,
    "missing_abstain_matches": 0,
    "byte_window_matches": 0,
    "mmap_reader_ready": 0,
}

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

try:
    with (store / "manifest.json").open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    metrics["manifest_page_size_bytes"] = int(manifest.get("page_size_bytes", 0))

    page_rows = read_csv(store / "page_table.bin")
    route_rows = read_csv(store / "route_index.bin")
    route_memory_rows = read_csv(store / "route_memory_store.bin")
    chunk_offset_rows = read_csv(store / "chunk_offsets.bin")

    metrics["page_table_rows"] = len(page_rows)
    metrics["route_index_rows"] = len(route_rows)
    metrics["route_memory_rows"] = len(route_memory_rows)
    metrics["chunk_offset_rows"] = len(chunk_offset_rows)

    pages = {}
    contiguous = True
    expected_start = 0
    for row in page_rows:
        page_id = int(row["page_id"])
        start = int(row["byte_start"])
        length = int(row["byte_len"])
        pages[page_id] = (start, length)
        if start != expected_start:
            contiguous = False
        expected_start = start + length
    metrics["page_table_contiguous"] = 1 if contiguous and bool(page_rows) else 0

    route_memory = {
        (row["route_key"], row["candidate_rank"]): row["candidate_chunk_id"]
        for row in route_memory_rows
    }
    chunk_offsets = {
        row["chunk_id"]: row
        for row in chunk_offset_rows
    }

    touched_pages = set()
    with (store / "chunk_pages.bin").open("rb") as handle:
        with mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            metrics["mmap_opened"] = 1
            for row in route_rows:
                metrics["route_index_rows"] += 0
                if int(row["abstain"]) == 1:
                    metrics["missing_query_rows"] += 1
                    if row["chunk_id"] == "ABSTAIN" and route_memory.get((row["route_key"], "1")) == "ABSTAIN":
                        metrics["missing_abstain_matches"] += 1
                    continue

                metrics["present_query_rows"] += 1
                page_id = int(row["page_id"])
                span_offset = int(row["span_offset"])
                span_len = int(row["span_len"])
                expected = row["expected_span"].encode("utf-8")
                touched_pages.add(page_id)

                page_start, page_len = pages.get(page_id, (-1, -1))
                if page_start <= span_offset and span_offset + span_len <= page_start + page_len:
                    metrics["byte_window_matches"] += 1

                metrics["mmap_span_reads"] += 1
                actual = mm[span_offset:span_offset + span_len]
                if actual == expected:
                    metrics["span_matches"] += 1
                else:
                    metrics["span_mismatches"] += 1

                offset_row = chunk_offsets.get(row["chunk_id"])
                if (
                    offset_row
                    and int(offset_row["page_id"]) == page_id
                    and int(offset_row["span_offset"]) == span_offset
                    and int(offset_row["span_len"]) == span_len
                    and offset_row["expected_span"] == row["expected_span"]
                ):
                    metrics["chunk_offset_matches"] += 1

                if route_memory.get((row["route_key"], "1")) == row["chunk_id"]:
                    metrics["route_key_matches"] += 1

    metrics["mmap_page_reads"] = len(touched_pages)

    if (
        metrics["mmap_opened"] == 1
        and metrics["page_table_contiguous"] == 1
        and metrics["present_query_rows"] > 0
        and metrics["span_matches"] == metrics["present_query_rows"]
        and metrics["chunk_offset_matches"] == metrics["present_query_rows"]
        and metrics["route_key_matches"] == metrics["present_query_rows"]
        and metrics["missing_abstain_matches"] == metrics["missing_query_rows"]
        and metrics["byte_window_matches"] == metrics["present_query_rows"]
    ):
        metrics["mmap_reader_ready"] = 1
except Exception as exc:
    metrics["reader_error"] = type(exc).__name__

fields = [
    "manifest_page_size_bytes",
    "page_table_rows",
    "page_table_contiguous",
    "route_index_rows",
    "present_query_rows",
    "missing_query_rows",
    "route_memory_rows",
    "chunk_offset_rows",
    "mmap_opened",
    "mmap_span_reads",
    "mmap_page_reads",
    "span_matches",
    "span_mismatches",
    "chunk_offset_matches",
    "route_key_matches",
    "missing_abstain_matches",
    "byte_window_matches",
    "mmap_reader_ready",
]
for field in fields:
    print(f"{field}={metrics[field]}")
PY
)"

eval "$reader_metrics"

routing_trigger_rate="0.000000"
active_jump_rate="0.000000"
actual_nonfixture_run_verified=0
real_pc_routelm_artifact_verified=0
real_external_benchmark_verified=0
real_release_package_ready=0

routelm_mmap_reader_ready=0
action="v13-routelm-store-files-missing"
if [[ "$store_files_found" -ne "${#REQUIRED_STORE_FILES[@]}" ]]; then
  action="v13-routelm-store-files-missing"
elif [[ "$run_hash_manifest_ready" != "1" ]]; then
  action="v13-routelm-run-hash-mismatch"
elif [[ "$store_hash_manifest_ready" != "1" ]]; then
  action="v13-routelm-store-hash-mismatch"
elif [[ "${mmap_opened:-0}" != "1" ]]; then
  action="v13-routelm-mmap-open-failed"
elif [[ "${page_table_contiguous:-0}" != "1" ]]; then
  action="v13-routelm-page-table-invalid"
elif [[ "${span_matches:-0}" -ne "${present_query_rows:-0}" ||
        "${byte_window_matches:-0}" -ne "${present_query_rows:-0}" ]]; then
  action="v13-routelm-mmap-span-mismatch"
elif [[ "${chunk_offset_matches:-0}" -ne "${present_query_rows:-0}" ]]; then
  action="v13-routelm-chunk-offset-mismatch"
elif [[ "${route_key_matches:-0}" -ne "${present_query_rows:-0}" ||
        "${missing_abstain_matches:-0}" -ne "${missing_query_rows:-0}" ]]; then
  action="v13-routelm-route-index-mismatch"
elif [[ "${mmap_reader_ready:-0}" == "1" ]]; then
  routelm_mmap_reader_ready=1
  action="v13-routelm-mmap-reader-ready-await-nonfixture-runner"
fi

{
  echo "reader_scope,run_source,run_id,run_dir,store_files_found,run_hash_entries,run_hash_verified,run_hash_manifest_ready,store_hash_entries,store_hash_verified,store_hash_manifest_ready,manifest_page_size_bytes,page_table_rows,page_table_contiguous,route_index_rows,present_query_rows,missing_query_rows,route_memory_rows,chunk_offset_rows,mmap_opened,mmap_span_reads,mmap_page_reads,span_matches,span_mismatches,chunk_offset_matches,route_key_matches,missing_abstain_matches,byte_window_matches,mmap_reader_ready,routelm_mmap_reader_ready,actual_nonfixture_run_verified,real_pc_routelm_artifact_verified,real_external_benchmark_verified,real_release_package_ready,action,routing_trigger_rate,active_jump_rate"
  printf "v13-b-routelm-mmap-reader,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s\n" \
    "$RUN_SOURCE" \
    "$RUN_ID" \
    "$RUN_DIR" \
    "$store_files_found" \
    "$run_hash_entries" \
    "$run_hash_verified" \
    "$run_hash_manifest_ready" \
    "$store_hash_entries" \
    "$store_hash_verified" \
    "$store_hash_manifest_ready" \
    "${manifest_page_size_bytes:-0}" \
    "${page_table_rows:-0}" \
    "${page_table_contiguous:-0}" \
    "${route_index_rows:-0}" \
    "${present_query_rows:-0}" \
    "${missing_query_rows:-0}" \
    "${route_memory_rows:-0}" \
    "${chunk_offset_rows:-0}" \
    "${mmap_opened:-0}" \
    "${mmap_span_reads:-0}" \
    "${mmap_page_reads:-0}" \
    "${span_matches:-0}" \
    "${span_mismatches:-0}" \
    "${chunk_offset_matches:-0}" \
    "${route_key_matches:-0}" \
    "${missing_abstain_matches:-0}" \
    "${byte_window_matches:-0}" \
    "${mmap_reader_ready:-0}" \
    "$routelm_mmap_reader_ready" \
    "$actual_nonfixture_run_verified" \
    "$real_pc_routelm_artifact_verified" \
    "$real_external_benchmark_verified" \
    "$real_release_package_ready" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

files_status=blocked
[[ "$store_files_found" -eq "${#REQUIRED_STORE_FILES[@]}" ]] && files_status=pass
run_hash_status=blocked
[[ "$run_hash_manifest_ready" == "1" ]] && run_hash_status=pass
store_hash_status=blocked
[[ "$store_hash_manifest_ready" == "1" ]] && store_hash_status=pass
mmap_status=blocked
[[ "${mmap_opened:-0}" == "1" ]] && mmap_status=pass
span_status=blocked
[[ "${span_matches:-0}" -eq "${present_query_rows:-0}" && "${byte_window_matches:-0}" -eq "${present_query_rows:-0}" && "${present_query_rows:-0}" -gt 0 ]] && span_status=pass
route_status=blocked
[[ "${route_key_matches:-0}" -eq "${present_query_rows:-0}" && "${missing_abstain_matches:-0}" -eq "${missing_query_rows:-0}" ]] && route_status=pass
ready_status=blocked
[[ "$routelm_mmap_reader_ready" == "1" ]] && ready_status=pass

{
  echo "gate,status,reason"
  printf "store-files,%s,files=%d/%d\n" \
    "$files_status" "$store_files_found" "${#REQUIRED_STORE_FILES[@]}"
  printf "run-hash-manifest,%s,verified=%d/%d\n" \
    "$run_hash_status" "$run_hash_verified" "$run_hash_entries"
  printf "store-hash-manifest,%s,verified=%d/%d\n" \
    "$store_hash_status" "$store_hash_verified" "$store_hash_entries"
  printf "mmap-open,%s,opened=%d page_size=%d\n" \
    "$mmap_status" "${mmap_opened:-0}" "${manifest_page_size_bytes:-0}"
  printf "mmap-span-read,%s,span=%d/%d window=%d/%d mismatches=%d pages=%d\n" \
    "$span_status" "${span_matches:-0}" "${present_query_rows:-0}" "${byte_window_matches:-0}" "${present_query_rows:-0}" "${span_mismatches:-0}" "${mmap_page_reads:-0}"
  printf "route-index,%s,route_key=%d/%d missing=%d/%d\n" \
    "$route_status" "${route_key_matches:-0}" "${present_query_rows:-0}" "${missing_abstain_matches:-0}" "${missing_query_rows:-0}"
  printf "routelm-mmap-reader,%s,ready=%d action=%s\n" \
    "$ready_status" "$routelm_mmap_reader_ready" "$action"
  printf "real-run-claims,blocked,actual_nonfixture=%d real_artifact=%d real_external=%d real_release=%d\n" \
    "$actual_nonfixture_run_verified" "$real_pc_routelm_artifact_verified" "$real_external_benchmark_verified" "$real_release_package_ready"
} >"$DECISION_CSV"

echo "run_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
