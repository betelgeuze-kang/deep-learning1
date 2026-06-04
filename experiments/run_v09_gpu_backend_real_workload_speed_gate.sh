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

PREFIX="v09_gpu_backend_real_workload_speed_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v09_gpu_backend_real_workload_speed_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v09_gpu_backend_real_workload_speed_gate_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v09_gpu_backend_measured_speed_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" "${RUN_ARGS[@]}" >/dev/null

H9_SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_measured_speed_gate"
H11D_SUMMARY_CSV="$RESULTS_DIR/v11_pc_routelm_nlg_smoke"
if [[ "$MODE" == "smoke" ]]; then
  H9_SUMMARY_CSV="${H9_SUMMARY_CSV}_smoke"
  H11D_SUMMARY_CSV="${H11D_SUMMARY_CSV}_smoke"
elif [[ "$MODE" == "full" ]]; then
  H11D_SUMMARY_CSV="${H11D_SUMMARY_CSV}_full"
fi
H9_SUMMARY_CSV="${H9_SUMMARY_CSV}_summary.csv"
H11D_SUMMARY_CSV="${H11D_SUMMARY_CSV}_summary.csv"

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ARTIFACT_DIR="$RESULTS_DIR/${PREFIX}_artifacts/routelm/workload_speed"
WORKLOAD_CSV="${V09_GPU_BACKEND_WORKLOAD_SPEED_CSV:-$RESULTS_DIR/${PREFIX}_workload.csv}"
WORKLOAD_SOURCE="generated-fixture"

uri_to_local_path() {
  local uri="$1"
  if [[ "$uri" == file://* ]]; then
    printf '%s\n' "${uri#file://}"
    return 0
  fi
  return 1
}

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

hash_matches() {
  local path="$1"
  local expected="$2"
  local expected_hex
  local actual_hex

  if [[ ! -f "$path" ]] || ! is_sha256 "$expected"; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

if [[ -n "${V09_GPU_BACKEND_WORKLOAD_SPEED_CSV:-}" ]]; then
  WORKLOAD_SOURCE="provided-csv"
  if [[ ! -s "$WORKLOAD_CSV" ]]; then
    echo "V09_GPU_BACKEND_WORKLOAD_SPEED_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  rm -rf "$ARTIFACT_DIR"
  mkdir -p "$ARTIFACT_DIR"

  H11D_RESULT_JSON="$(
    awk -F, '
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        next
      }
      {
        print $idx["result_json"]
      }
    ' "$H11D_SUMMARY_CSV"
  )"

  cat >"$ARTIFACT_DIR/timing.json" <<'JSON'
{"cpu_median_ms":12.000000,"hip_median_ms":8.000000,"nvme_read_median_ms":0.180000,"claim":"diagnostic fixture only"}
JSON
  cat >"$ARTIFACT_DIR/environment.txt" <<'TXT'
diagnostic fixture environment; no real HIP or NVMe hardware attestation
TXT

  nlg_hash="$(sha256sum "$H11D_RESULT_JSON" | awk '{print $1}')"
  timing_hash="$(sha256sum "$ARTIFACT_DIR/timing.json" | awk '{print $1}')"
  environment_hash="$(sha256sum "$ARTIFACT_DIR/environment.txt" | awk '{print $1}')"

  cat >"$WORKLOAD_CSV" <<CSV
workload_id,workload_family,route_memory_residency,nlg_result_uri,nlg_result_hash,timing_artifact_uri,timing_artifact_hash,environment_uri,environment_hash,cpu_median_ms,hip_median_ms,nvme_read_median_ms,query_to_evidence_ms,query_to_first_token_ms,tokens_per_second_after_retrieval,ssd_bytes_per_query,ram_used_gb,vram_used_gb,warmup_runs,measured_runs,measurement_source,real_hip_measurement,real_nvme_measurement,non_fixture_workload,benchmark_or_product_trace_verified,workload_ready,routing_trigger_rate,active_jump_rate
diagnostic-pc-routelm-nlg,pc-routelm-nlg,nvme,file://$H11D_RESULT_JSON,sha256:$nlg_hash,file://$ARTIFACT_DIR/timing.json,sha256:$timing_hash,file://$ARTIFACT_DIR/environment.txt,sha256:$environment_hash,12.000000,8.000000,0.180000,0.420000,4.000000,48.666667,64.000000,0.031250,0.000000,2,5,fixture,0,0,0,0,1,0,0
CSV
fi

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("workload_id workload_family route_memory_residency nlg_result_uri nlg_result_hash timing_artifact_uri timing_artifact_hash environment_uri environment_hash cpu_median_ms hip_median_ms nvme_read_median_ms query_to_evidence_ms query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb warmup_runs measured_runs measurement_source real_hip_measurement real_nvme_measurement non_fixture_workload benchmark_or_product_trace_verified workload_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h9-h workload speed column: " required[i], 6)
    }
    next
  }
  {
    if (NF != header_fields) die("h9-h workload speed row has wrong column count", 7)
    rows++
  }
  END {
    if (NR == 0) die("empty h9-h workload speed CSV", 8)
  }
' "$WORKLOAD_CSV"

H9_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("speed_schema_ready hip_tool_available measured_speed_evidence_ready speed_evidence_ready gpu_speedup_claim median_speedup routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h9-h measured speed column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%s,%.6f,%.6f,%.6f\n",
        $idx["speed_schema_ready"] + 0,
        $idx["hip_tool_available"] + 0,
        $idx["measured_speed_evidence_ready"] + 0,
        $idx["speed_evidence_ready"] + 0,
        $idx["gpu_speedup_claim"],
        $idx["median_speedup"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h9-h measured speed summary row", 3)
    }
  ' "$H9_SUMMARY_CSV"
)"

IFS=, read -r speed_schema_ready hip_tool_available h9_measured_speed_evidence_ready h9_speed_evidence_ready h9_gpu_speedup_claim h9_median_speedup h9_routing h9_jump <<<"$H9_VALUES"

H11D_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("diagnostic_artifact_ready pc_routelm_nlg_smoke_ready real_pc_routelm_nlg_verified query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h9-h NLG smoke column: " required[i], 4)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        $idx["diagnostic_artifact_ready"] + 0,
        $idx["pc_routelm_nlg_smoke_ready"] + 0,
        $idx["real_pc_routelm_nlg_verified"] + 0,
        $idx["query_to_first_token_ms"] + 0,
        $idx["tokens_per_second_after_retrieval"] + 0,
        $idx["ssd_bytes_per_query"] + 0,
        $idx["ram_used_gb"] + 0,
        $idx["vram_used_gb"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h9-h NLG smoke summary row", 5)
    }
  ' "$H11D_SUMMARY_CSV"
)"

IFS=, read -r diagnostic_artifact_ready pc_routelm_nlg_smoke_ready real_pc_routelm_nlg_verified h11d_query_to_first_token h11d_tokens_per_second h11d_ssd_bytes h11d_ram_used h11d_vram_used h11d_routing h11d_jump <<<"$H11D_VALUES"

workload_rows=0
workload_artifact_rows=0
nlg_result_hash_verified_rows=0
timing_artifact_hash_verified_rows=0
environment_hash_verified_rows=0
workload_ready_rows=0
real_hip_measurement_rows=0
real_nvme_measurement_rows=0
non_fixture_workload_rows=0
benchmark_or_product_trace_verified_rows=0
speedup_positive_rows=0
metrics_positive_rows=0
cpu_median_sum="0.000000"
hip_median_sum="0.000000"
median_speedup="0.000000"
nvme_read_sum="0.000000"
query_to_evidence_sum="0.000000"
query_to_first_token_sum="0.000000"
tokens_per_second_sum="0.000000"
ssd_bytes_sum="0.000000"
ram_used_sum="0.000000"
vram_used_sum="0.000000"
workload_routing="0.000000"
workload_jump="0.000000"

while IFS=$'\t' read -r workload_id workload_family route_memory_residency nlg_result_uri nlg_result_hash timing_artifact_uri timing_artifact_hash environment_uri environment_hash cpu_median_ms hip_median_ms nvme_read_median_ms query_to_evidence_ms query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb warmup_runs measured_runs row_measurement_source real_hip_measurement real_nvme_measurement non_fixture_workload benchmark_or_product_trace_verified workload_ready routing_trigger_rate active_jump_rate; do
  ((workload_rows += 1))

  nlg_hash_ok=0
  timing_hash_ok=0
  environment_hash_ok=0

  if nlg_path="$(uri_to_local_path "$nlg_result_uri")"; then
    if hash_matches "$nlg_path" "$nlg_result_hash"; then
      nlg_hash_ok=1
      ((nlg_result_hash_verified_rows += 1))
    fi
  fi
  if timing_path="$(uri_to_local_path "$timing_artifact_uri")"; then
    if hash_matches "$timing_path" "$timing_artifact_hash"; then
      timing_hash_ok=1
      ((timing_artifact_hash_verified_rows += 1))
    fi
  fi
  if environment_path="$(uri_to_local_path "$environment_uri")"; then
    if hash_matches "$environment_path" "$environment_hash"; then
      environment_hash_ok=1
      ((environment_hash_verified_rows += 1))
    fi
  fi
  if [[ "$nlg_hash_ok" == "1" && "$timing_hash_ok" == "1" && "$environment_hash_ok" == "1" ]]; then
    ((workload_artifact_rows += 1))
  fi

  row_speedup="$(awk -v cpu="$cpu_median_ms" -v hip="$hip_median_ms" 'BEGIN {
    if (cpu > 0 && hip > 0) printf "%.6f", cpu / hip; else printf "0.000000"
  }')"
  median_speedup="$(awk -v current="$median_speedup" -v row="$row_speedup" 'BEGIN {
    if (row > current) printf "%.6f", row; else printf "%.6f", current
  }')"

  if [[ "$workload_ready" == "1" &&
        "$route_memory_residency" == "nvme" &&
        "$workload_family" == "pc-routelm-nlg" &&
        "$warmup_runs" =~ ^[0-9]+$ &&
        "$measured_runs" =~ ^[0-9]+$ &&
        "$warmup_runs" -ge 1 &&
        "$measured_runs" -ge 3 ]]; then
    ((workload_ready_rows += 1))
  fi
  if [[ "$real_hip_measurement" == "1" && "$row_measurement_source" == "real-workload" ]]; then
    ((real_hip_measurement_rows += 1))
  fi
  if [[ "$real_nvme_measurement" == "1" && "$route_memory_residency" == "nvme" ]]; then
    ((real_nvme_measurement_rows += 1))
  fi
  if [[ "$non_fixture_workload" == "1" ]]; then
    ((non_fixture_workload_rows += 1))
  fi
  if [[ "$benchmark_or_product_trace_verified" == "1" ]]; then
    ((benchmark_or_product_trace_verified_rows += 1))
  fi
  if awk -v speedup="$row_speedup" 'BEGIN { exit !(speedup > 1.0) }'; then
    ((speedup_positive_rows += 1))
  fi
  if awk -v cpu="$cpu_median_ms" -v hip="$hip_median_ms" -v nvme="$nvme_read_median_ms" -v qe="$query_to_evidence_ms" -v qft="$query_to_first_token_ms" -v tps="$tokens_per_second_after_retrieval" -v ssd="$ssd_bytes_per_query" -v ram="$ram_used_gb" 'BEGIN {
    exit !(cpu > 0 && hip > 0 && nvme > 0 && qe > 0 && qft > 0 && tps > 0 && ssd > 0 && ram > 0)
  }'; then
    ((metrics_positive_rows += 1))
  fi

  cpu_median_sum="$(awk -v a="$cpu_median_sum" -v b="$cpu_median_ms" 'BEGIN { printf "%.6f", a + b }')"
  hip_median_sum="$(awk -v a="$hip_median_sum" -v b="$hip_median_ms" 'BEGIN { printf "%.6f", a + b }')"
  nvme_read_sum="$(awk -v a="$nvme_read_sum" -v b="$nvme_read_median_ms" 'BEGIN { printf "%.6f", a + b }')"
  query_to_evidence_sum="$(awk -v a="$query_to_evidence_sum" -v b="$query_to_evidence_ms" 'BEGIN { printf "%.6f", a + b }')"
  query_to_first_token_sum="$(awk -v a="$query_to_first_token_sum" -v b="$query_to_first_token_ms" 'BEGIN { printf "%.6f", a + b }')"
  tokens_per_second_sum="$(awk -v a="$tokens_per_second_sum" -v b="$tokens_per_second_after_retrieval" 'BEGIN { printf "%.6f", a + b }')"
  ssd_bytes_sum="$(awk -v a="$ssd_bytes_sum" -v b="$ssd_bytes_per_query" 'BEGIN { printf "%.6f", a + b }')"
  ram_used_sum="$(awk -v a="$ram_used_sum" -v b="$ram_used_gb" 'BEGIN { printf "%.6f", a + b }')"
  vram_used_sum="$(awk -v a="$vram_used_sum" -v b="$vram_used_gb" 'BEGIN { printf "%.6f", a + b }')"
  workload_routing="$(awk -v a="$workload_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  workload_jump="$(awk -v a="$workload_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("workload_id workload_family route_memory_residency nlg_result_uri nlg_result_hash timing_artifact_uri timing_artifact_hash environment_uri environment_hash cpu_median_ms hip_median_ms nvme_read_median_ms query_to_evidence_ms query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb warmup_runs measured_runs measurement_source real_hip_measurement real_nvme_measurement non_fixture_workload benchmark_or_product_trace_verified workload_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h9-h workload speed column: " required[i], 6)
      }
      next
    }
    {
      if (NF != header_fields) die("h9-h workload speed row has wrong column count", 7)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["workload_id"],
        $idx["workload_family"],
        $idx["route_memory_residency"],
        $idx["nlg_result_uri"],
        $idx["nlg_result_hash"],
        $idx["timing_artifact_uri"],
        $idx["timing_artifact_hash"],
        $idx["environment_uri"],
        $idx["environment_hash"],
        $idx["cpu_median_ms"] + 0,
        $idx["hip_median_ms"] + 0,
        $idx["nvme_read_median_ms"] + 0,
        $idx["query_to_evidence_ms"] + 0,
        $idx["query_to_first_token_ms"] + 0,
        $idx["tokens_per_second_after_retrieval"] + 0,
        $idx["ssd_bytes_per_query"] + 0,
        $idx["ram_used_gb"] + 0,
        $idx["vram_used_gb"] + 0,
        $idx["warmup_runs"] + 0,
        $idx["measured_runs"] + 0,
        $idx["measurement_source"],
        $idx["real_hip_measurement"] + 0,
        $idx["real_nvme_measurement"] + 0,
        $idx["non_fixture_workload"] + 0,
        $idx["benchmark_or_product_trace_verified"] + 0,
        $idx["workload_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$WORKLOAD_CSV"
)

avg_metric() {
  local sum="$1"
  local rows="$2"
  awk -v sum="$sum" -v rows="$rows" 'BEGIN {
    if (rows > 0) printf "%.6f", sum / rows; else printf "0.000000"
  }'
}

cpu_median_ms="$(avg_metric "$cpu_median_sum" "$workload_rows")"
hip_median_ms="$(avg_metric "$hip_median_sum" "$workload_rows")"
nvme_read_median_ms="$(avg_metric "$nvme_read_sum" "$workload_rows")"
query_to_evidence_ms="$(avg_metric "$query_to_evidence_sum" "$workload_rows")"
query_to_first_token_ms="$(avg_metric "$query_to_first_token_sum" "$workload_rows")"
tokens_per_second_after_retrieval="$(avg_metric "$tokens_per_second_sum" "$workload_rows")"
ssd_bytes_per_query="$(avg_metric "$ssd_bytes_sum" "$workload_rows")"
ram_used_gb="$(avg_metric "$ram_used_sum" "$workload_rows")"
vram_used_gb="$(avg_metric "$vram_used_sum" "$workload_rows")"

total_routing="$(awk -v a="$h9_routing" -v b="$h11d_routing" -v c="$workload_routing" 'BEGIN { printf "%.6f", a + b + c }')"
total_jump="$(awk -v a="$h9_jump" -v b="$h11d_jump" -v c="$workload_jump" 'BEGIN { printf "%.6f", a + b + c }')"

diagnostic_workload_speed_ready=0
if [[ "$speed_schema_ready" == "1" &&
      "$diagnostic_artifact_ready" == "1" &&
      "$pc_routelm_nlg_smoke_ready" == "1" &&
      "$workload_rows" -gt 0 &&
      "$workload_artifact_rows" -eq "$workload_rows" &&
      "$nlg_result_hash_verified_rows" -eq "$workload_rows" &&
      "$timing_artifact_hash_verified_rows" -eq "$workload_rows" &&
      "$environment_hash_verified_rows" -eq "$workload_rows" &&
      "$workload_ready_rows" -eq "$workload_rows" &&
      "$metrics_positive_rows" -eq "$workload_rows" &&
      "$speedup_positive_rows" -eq "$workload_rows" &&
      "$total_routing" == "0.000000" &&
      "$total_jump" == "0.000000" ]]; then
  diagnostic_workload_speed_ready=1
fi

real_workload_speed_evidence_ready=0
if [[ "$diagnostic_workload_speed_ready" == "1" &&
      "$hip_tool_available" == "1" &&
      "$h9_measured_speed_evidence_ready" == "1" &&
      "$h9_speed_evidence_ready" == "1" &&
      "$real_pc_routelm_nlg_verified" == "1" &&
      "$real_hip_measurement_rows" -eq "$workload_rows" &&
      "$real_nvme_measurement_rows" -eq "$workload_rows" &&
      "$non_fixture_workload_rows" -eq "$workload_rows" &&
      "$benchmark_or_product_trace_verified_rows" -eq "$workload_rows" ]]; then
  real_workload_speed_evidence_ready=1
fi

gpu_speedup_claim="deferred"
action="real-workload-speed-evidence-missing"
if [[ "$pc_routelm_nlg_smoke_ready" != "1" ]]; then
  action="pc-routelm-nlg-smoke-missing"
elif [[ "$workload_rows" -le 0 ]]; then
  action="workload-speed-rows-missing"
elif [[ "$workload_artifact_rows" -ne "$workload_rows" ]]; then
  action="workload-speed-artifact-hash-mismatch"
elif [[ "$workload_ready_rows" -ne "$workload_rows" ||
        "$metrics_positive_rows" -ne "$workload_rows" ]]; then
  action="workload-speed-contract-incomplete"
elif [[ "$speedup_positive_rows" -ne "$workload_rows" ]]; then
  action="workload-speedup-not-demonstrated"
elif [[ "$total_routing" != "0.000000" || "$total_jump" != "0.000000" ]]; then
  action="jump-guardrail-active"
elif [[ "$h9_measured_speed_evidence_ready" != "1" ||
        "$h9_speed_evidence_ready" != "1" ]]; then
  action="real-workload-speed-evidence-missing"
elif [[ "$real_pc_routelm_nlg_verified" != "1" ]]; then
  action="real-pc-routelm-nlg-missing"
elif [[ "$real_hip_measurement_rows" -ne "$workload_rows" ||
        "$real_nvme_measurement_rows" -ne "$workload_rows" ||
        "$non_fixture_workload_rows" -ne "$workload_rows" ||
        "$benchmark_or_product_trace_verified_rows" -ne "$workload_rows" ]]; then
  action="non-fixture-workload-evidence-missing"
elif [[ "$real_workload_speed_evidence_ready" == "1" ]]; then
  gpu_speedup_claim="measured-pc-routelm-workload-candidate"
  action="real-workload-speed-evidence-ready"
fi

{
  echo "scope,workload_source,workload_rows,diagnostic_artifact_ready,pc_routelm_nlg_smoke_ready,real_pc_routelm_nlg_verified,h9_measured_speed_evidence_ready,h9_speed_evidence_ready,workload_artifact_rows,nlg_result_hash_verified_rows,timing_artifact_hash_verified_rows,environment_hash_verified_rows,workload_ready_rows,metrics_positive_rows,real_hip_measurement_rows,real_nvme_measurement_rows,non_fixture_workload_rows,benchmark_or_product_trace_verified_rows,speedup_positive_rows,cpu_median_ms,hip_median_ms,median_speedup,nvme_read_median_ms,query_to_evidence_ms,query_to_first_token_ms,tokens_per_second_after_retrieval,ssd_bytes_per_query,ram_used_gb,vram_used_gb,diagnostic_workload_speed_ready,real_workload_speed_evidence_ready,gpu_speedup_claim,action,routing_trigger_rate,active_jump_rate"
  printf "h9h-real-workload-speed,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%s,%s,%.6f,%.6f\n" \
    "$WORKLOAD_SOURCE" \
    "$workload_rows" \
    "$diagnostic_artifact_ready" \
    "$pc_routelm_nlg_smoke_ready" \
    "$real_pc_routelm_nlg_verified" \
    "$h9_measured_speed_evidence_ready" \
    "$h9_speed_evidence_ready" \
    "$workload_artifact_rows" \
    "$nlg_result_hash_verified_rows" \
    "$timing_artifact_hash_verified_rows" \
    "$environment_hash_verified_rows" \
    "$workload_ready_rows" \
    "$metrics_positive_rows" \
    "$real_hip_measurement_rows" \
    "$real_nvme_measurement_rows" \
    "$non_fixture_workload_rows" \
    "$benchmark_or_product_trace_verified_rows" \
    "$speedup_positive_rows" \
    "$cpu_median_ms" \
    "$hip_median_ms" \
    "$median_speedup" \
    "$nvme_read_median_ms" \
    "$query_to_evidence_ms" \
    "$query_to_first_token_ms" \
    "$tokens_per_second_after_retrieval" \
    "$ssd_bytes_per_query" \
    "$ram_used_gb" \
    "$vram_used_gb" \
    "$diagnostic_workload_speed_ready" \
    "$real_workload_speed_evidence_ready" \
    "$gpu_speedup_claim" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "pc-routelm-nlg-smoke,%s,ready=%d real=%d\n" \
    "$([[ "$pc_routelm_nlg_smoke_ready" == "1" ]] && echo pass || echo blocked)" \
    "$pc_routelm_nlg_smoke_ready" \
    "$real_pc_routelm_nlg_verified"
  printf "workload-artifacts,%s,artifact_rows=%d rows=%d\n" \
    "$([[ "$workload_artifact_rows" -eq "$workload_rows" && "$workload_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$workload_artifact_rows" \
    "$workload_rows"
  printf "workload-hashes,%s,nlg=%d timing=%d environment=%d rows=%d\n" \
    "$([[ "$nlg_result_hash_verified_rows" -eq "$workload_rows" && "$timing_artifact_hash_verified_rows" -eq "$workload_rows" && "$environment_hash_verified_rows" -eq "$workload_rows" && "$workload_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$nlg_result_hash_verified_rows" \
    "$timing_artifact_hash_verified_rows" \
    "$environment_hash_verified_rows" \
    "$workload_rows"
  printf "workload-contract,%s,ready=%d metrics_positive=%d rows=%d\n" \
    "$([[ "$workload_ready_rows" -eq "$workload_rows" && "$metrics_positive_rows" -eq "$workload_rows" && "$workload_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$workload_ready_rows" \
    "$metrics_positive_rows" \
    "$workload_rows"
  printf "speedup-positive,%s,speedup_rows=%d median_speedup=%.6f\n" \
    "$([[ "$speedup_positive_rows" -eq "$workload_rows" && "$workload_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$speedup_positive_rows" \
    "$median_speedup"
  printf "h9-real-speed,%s,measured=%d speed_ready=%d h9_claim=%s\n" \
    "$([[ "$h9_measured_speed_evidence_ready" == "1" && "$h9_speed_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$h9_measured_speed_evidence_ready" \
    "$h9_speed_evidence_ready" \
    "$h9_gpu_speedup_claim"
  printf "real-workload-source,%s,hip=%d nvme=%d non_fixture=%d trace=%d rows=%d\n" \
    "$([[ "$real_hip_measurement_rows" -eq "$workload_rows" && "$real_nvme_measurement_rows" -eq "$workload_rows" && "$non_fixture_workload_rows" -eq "$workload_rows" && "$benchmark_or_product_trace_verified_rows" -eq "$workload_rows" && "$workload_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$real_hip_measurement_rows" \
    "$real_nvme_measurement_rows" \
    "$non_fixture_workload_rows" \
    "$benchmark_or_product_trace_verified_rows" \
    "$workload_rows"
  printf "real-workload-speed,%s,real_ready=%d action=%s\n" \
    "$([[ "$real_workload_speed_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$real_workload_speed_evidence_ready" \
    "$action"
  printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n" \
    "$([[ "$total_routing" == "0.000000" && "$total_jump" == "0.000000" ]] && echo pass || echo blocked)" \
    "$total_routing" \
    "$total_jump"
} >"$DECISION_CSV"

echo "workload: $WORKLOAD_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
