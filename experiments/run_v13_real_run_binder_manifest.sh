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

PREFIX="v13_real_run_binder_manifest"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_run_binder_manifest_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_run_binder_manifest_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_REAL_RUN_BINDER_RUN_DIR:-$RESULTS_DIR/${PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_REAL_RUN_BINDER_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

summary_path() {
  local base="$1"
  if [[ "$MODE" == "smoke" ]]; then
    printf '%s/%s_smoke_summary.csv\n' "$RESULTS_DIR" "$base"
  elif [[ "$MODE" == "full" ]]; then
    printf '%s/%s_full_summary.csv\n' "$RESULTS_DIR" "$base"
  else
    printf '%s/%s_summary.csv\n' "$RESULTS_DIR" "$base"
  fi
}

csv_value() {
  local file="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(column in idx)) {
        print "missing v13 binder column: " column > "/dev/stderr"
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
        print "missing v13 binder summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

sha256_uri() {
  local path="$1"
  sha256sum "$path" | awk '{print "sha256:" $1}'
}

copy_dir_contents() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"
  if [[ -d "$src" ]]; then
    cp -a "$src"/. "$dst"/
  fi
}

write_hash_manifest() {
  local dir="$1"
  (
    cd "$dir"
    find . -type f ! -path './sha256sums.txt' -print | sort | while IFS= read -r file; do
      sha256sum "${file#./}"
    done
  ) >"$dir/sha256sums.txt"
}

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

"$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v09_gpu_backend_real_workload_speed_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_run_evaluator_trace.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v12_paper_release_claim_audit.sh" "${RUN_ARGS[@]}" >/dev/null

H11C_SUMMARY_CSV="$(summary_path "v11_nvme_route_memory_store")"
H11D_SUMMARY_CSV="$(summary_path "v11_pc_routelm_nlg_smoke")"
H9H_SUMMARY_CSV="$(summary_path "v09_gpu_backend_real_workload_speed_gate")"
V08_RUN_SUMMARY_CSV="$(summary_path "v08_external_benchmark_run_evaluator_trace")"
H10S_SUMMARY_CSV="$(summary_path "v10_source_verified_learned_chunk_scorer_eval_gate")"
V12_SUMMARY_CSV="$(summary_path "v12_paper_release_claim_audit")"

h11c_store_dir="$(csv_value "$H11C_SUMMARY_CSV" "store_dir")"
h11c_ready="$(csv_value "$H11C_SUMMARY_CSV" "route_memory_artifact_chain_verified")"
h11c_real_artifact="$(csv_value "$H11C_SUMMARY_CSV" "real_pc_routelm_artifact_verified")"
h11c_external="$(csv_value "$H11C_SUMMARY_CSV" "real_external_benchmark_verified")"
h11c_routing="$(csv_value "$H11C_SUMMARY_CSV" "routing_trigger_rate")"
h11c_jump="$(csv_value "$H11C_SUMMARY_CSV" "active_jump_rate")"

h11d_transcript="$(csv_value "$H11D_SUMMARY_CSV" "transcript_jsonl")"
h11d_result="$(csv_value "$H11D_SUMMARY_CSV" "result_json")"
h11d_ready="$(csv_value "$H11D_SUMMARY_CSV" "pc_routelm_nlg_smoke_ready")"
h11d_real_nlg="$(csv_value "$H11D_SUMMARY_CSV" "real_pc_routelm_nlg_verified")"
h11d_wrong_answer_rate="$(csv_value "$H11D_SUMMARY_CSV" "wrong_answer_rate")"
h11d_routing="$(csv_value "$H11D_SUMMARY_CSV" "routing_trigger_rate")"
h11d_jump="$(csv_value "$H11D_SUMMARY_CSV" "active_jump_rate")"

h9h_ready="$(csv_value "$H9H_SUMMARY_CSV" "diagnostic_workload_speed_ready")"
h9h_real_speed="$(csv_value "$H9H_SUMMARY_CSV" "real_workload_speed_evidence_ready")"
h9h_gpu_claim="$(csv_value "$H9H_SUMMARY_CSV" "gpu_speedup_claim")"
h9h_routing="$(csv_value "$H9H_SUMMARY_CSV" "routing_trigger_rate")"
h9h_jump="$(csv_value "$H9H_SUMMARY_CSV" "active_jump_rate")"

v08_trace_dir="$(csv_value "$V08_RUN_SUMMARY_CSV" "trace_dir")"
v08_trace_ready="$(csv_value "$V08_RUN_SUMMARY_CSV" "codebase_run_evaluator_trace_ready")"
v08_real_external="$(csv_value "$V08_RUN_SUMMARY_CSV" "real_external_benchmark_verified")"
v08_routing="$(csv_value "$V08_RUN_SUMMARY_CSV" "routing_trigger_rate")"
v08_jump="$(csv_value "$V08_RUN_SUMMARY_CSV" "active_jump_rate")"

h10s_student_eval_ready="$(csv_value "$H10S_SUMMARY_CSV" "student_only_eval_ready")"
h10s_source_verified_eval_ready="$(csv_value "$H10S_SUMMARY_CSV" "source_verified_learned_chunk_scorer_eval_ready")"
h10s_routing="$(csv_value "$H10S_SUMMARY_CSV" "routing_trigger_rate")"
h10s_jump="$(csv_value "$H10S_SUMMARY_CSV" "active_jump_rate")"

v12_diag_ready="$(csv_value "$V12_SUMMARY_CSV" "diagnostic_release_package_ready")"
v12_real_ready="$(csv_value "$V12_SUMMARY_CSV" "real_release_package_ready")"
v12_release_claim="$(csv_value "$V12_SUMMARY_CSV" "release_claim")"
v12_routing="$(csv_value "$V12_SUMMARY_CSV" "routing_trigger_rate")"
v12_jump="$(csv_value "$V12_SUMMARY_CSV" "active_jump_rate")"

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR"/{store,nlg,benchmark,speed,evidence}

  copy_dir_contents "$h11c_store_dir" "$RUN_DIR/store"
  cp "$h11d_transcript" "$RUN_DIR/nlg/transcript.jsonl"
  cp "$h11d_result" "$RUN_DIR/nlg/result_summary.json"
  copy_dir_contents "$v08_trace_dir" "$RUN_DIR/benchmark"

  h9_workload_csv="$RESULTS_DIR/${PREFIX/v13_real_run_binder_manifest/v09_gpu_backend_real_workload_speed_gate}_workload.csv"
  if [[ "$MODE" == "smoke" ]]; then
    h9_workload_csv="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_gate_smoke_workload.csv"
  elif [[ "$MODE" == "full" ]]; then
    h9_workload_csv="$RESULTS_DIR/v09_gpu_backend_real_workload_speed_gate_full_workload.csv"
  fi
  [[ -f "$h9_workload_csv" ]] && cp "$h9_workload_csv" "$RUN_DIR/speed/workload.csv"

  cp "$H11C_SUMMARY_CSV" "$RUN_DIR/evidence/h11c.csv"
  cp "$H11D_SUMMARY_CSV" "$RUN_DIR/evidence/h11d.csv"
  cp "$H9H_SUMMARY_CSV" "$RUN_DIR/evidence/h9h.csv"
  cp "$V08_RUN_SUMMARY_CSV" "$RUN_DIR/evidence/v08_run.csv"
  cp "$H10S_SUMMARY_CSV" "$RUN_DIR/evidence/h10s.csv"
  cp "$V12_SUMMARY_CSV" "$RUN_DIR/evidence/v12_input.csv"

  cat >"$RUN_DIR/run_manifest.json" <<JSON
{
  "artifact_scope": "v13-a-real-run-binder-manifest",
  "run_id": "$RUN_ID",
  "dataset_id": "public-codebase-routeqa-v1-seed-smoke",
  "store_id": "h11c-nvme-route-memory-store",
  "generator_id": "diagnostic-small-generator-v1",
  "evaluator_id": "v08al-codebase-run-evaluator-trace",
  "speed_profile_id": "h9h-resource-envelope",
  "claim_audit_id": "v12-paper-release-claim-audit",
  "source": "$RUN_SOURCE",
  "claim": "real-run binder manifest skeleton; generated diagnostic inputs, not real external benchmark or real PC RouteLM evidence"
}
JSON

  {
    echo "run_id,dataset_id,store_id,generator_id,evaluator_id,store_dir,nlg_transcript,nlg_result,benchmark_trace_dir,speed_workload_csv,h11c_csv,h11d_csv,h9h_csv,v08_run_csv,h10s_csv,v12_input_csv,source,fixture_or_generated_declared,routing_trigger_rate,active_jump_rate"
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,0.000000,0.000000\n" \
      "$RUN_ID" \
      "public-codebase-routeqa-v1-seed-smoke" \
      "h11c-nvme-route-memory-store" \
      "diagnostic-small-generator-v1" \
      "v08al-codebase-run-evaluator-trace" \
      "store" \
      "nlg/transcript.jsonl" \
      "nlg/result_summary.json" \
      "benchmark" \
      "speed/workload.csv" \
      "evidence/h11c.csv" \
      "evidence/h11d.csv" \
      "evidence/h9h.csv" \
      "evidence/v08_run.csv" \
      "evidence/h10s.csv" \
      "evidence/v12_input.csv" \
      "$RUN_SOURCE"
  } >"$RUN_DIR/evidence/v13_run_manifest.csv"

  write_hash_manifest "$RUN_DIR"
fi

required_sections_ready=0
store_files="$(find "$RUN_DIR/store" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
nlg_files="$(find "$RUN_DIR/nlg" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
benchmark_files="$(find "$RUN_DIR/benchmark" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
speed_files="$(find "$RUN_DIR/speed" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
evidence_files="$(find "$RUN_DIR/evidence" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$store_files" -ge 7 &&
      "$nlg_files" -ge 2 &&
      "$benchmark_files" -ge 6 &&
      "$speed_files" -ge 1 &&
      "$evidence_files" -ge 7 ]]; then
  required_sections_ready=1
fi

IFS=, read -r hash_manifest_entries hash_verified_files <<<"$(verify_hash_manifest "$RUN_DIR")"
hash_manifest_ready=0
if [[ "$hash_manifest_entries" -gt 0 && "$hash_manifest_entries" -eq "$hash_verified_files" ]]; then
  hash_manifest_ready=1
fi

routing_trigger_rate="$(awk -v a="$h11c_routing" -v b="$h11d_routing" -v c="$h9h_routing" -v d="$v08_routing" -v e="$h10s_routing" -v f="$v12_routing" 'BEGIN { printf "%.6f", a + b + c + d + e + f }')"
active_jump_rate="$(awk -v a="$h11c_jump" -v b="$h11d_jump" -v c="$h9h_jump" -v d="$v08_jump" -v e="$h10s_jump" -v f="$v12_jump" 'BEGIN { printf "%.6f", a + b + c + d + e + f }')"

real_run_binder_manifest_ready=0
if [[ "$required_sections_ready" == "1" &&
      "$hash_manifest_ready" == "1" &&
      "$h11c_ready" == "1" &&
      "$h11d_ready" == "1" &&
      "$h9h_ready" == "1" &&
      "$v08_trace_ready" == "1" &&
      "$v12_diag_ready" == "1" &&
      "$routing_trigger_rate" == "0.000000" &&
      "$active_jump_rate" == "0.000000" ]]; then
  real_run_binder_manifest_ready=1
fi

actual_nonfixture_run_verified=0
real_pc_routelm_nlg_verified=0
real_external_benchmark_verified=0
real_workload_speed_evidence_ready=0
real_release_package_ready=0

action="real-run-binder-sections-missing"
if [[ "$required_sections_ready" != "1" ]]; then
  action="real-run-binder-sections-missing"
elif [[ "$hash_manifest_ready" != "1" ]]; then
  action="real-run-binder-hash-manifest-mismatch"
elif [[ "$h11c_ready" != "1" || "$h11d_ready" != "1" || "$h9h_ready" != "1" || "$v08_trace_ready" != "1" || "$v12_diag_ready" != "1" ]]; then
  action="real-run-binder-upstream-diagnostic-input-missing"
elif [[ "$routing_trigger_rate" != "0.000000" || "$active_jump_rate" != "0.000000" ]]; then
  action="real-run-binder-jump-guardrail-violated"
elif [[ "$real_run_binder_manifest_ready" == "1" ]]; then
  action="real-run-binder-manifest-ready-await-nonfixture-runner"
fi

{
  echo "binder_scope,run_source,run_id,run_dir,store_files,nlg_files,benchmark_files,speed_files,evidence_files,required_sections_ready,hash_manifest_entries,hash_verified_files,hash_manifest_ready,h11c_ready,h11d_ready,h9h_ready,v08_trace_ready,h10s_student_eval_ready,h10s_source_verified_eval_ready,v12_diagnostic_release_ready,v12_real_release_ready,v12_release_claim,real_run_binder_manifest_ready,actual_nonfixture_run_verified,real_pc_routelm_artifact_verified,real_pc_routelm_nlg_verified,real_external_benchmark_verified,real_workload_speed_evidence_ready,real_release_package_ready,gpu_speedup_claim,action,routing_trigger_rate,active_jump_rate"
  printf "v13-a-real-run-binder-manifest,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s\n" \
    "$RUN_SOURCE" \
    "$RUN_ID" \
    "$RUN_DIR" \
    "$store_files" \
    "$nlg_files" \
    "$benchmark_files" \
    "$speed_files" \
    "$evidence_files" \
    "$required_sections_ready" \
    "$hash_manifest_entries" \
    "$hash_verified_files" \
    "$hash_manifest_ready" \
    "$h11c_ready" \
    "$h11d_ready" \
    "$h9h_ready" \
    "$v08_trace_ready" \
    "$h10s_student_eval_ready" \
    "$h10s_source_verified_eval_ready" \
    "$v12_diag_ready" \
    "$v12_real_ready" \
    "$v12_release_claim" \
    "$real_run_binder_manifest_ready" \
    "$actual_nonfixture_run_verified" \
    "$h11c_real_artifact" \
    "$real_pc_routelm_nlg_verified" \
    "$real_external_benchmark_verified" \
    "$real_workload_speed_evidence_ready" \
    "$real_release_package_ready" \
    "$h9h_gpu_claim" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

section_status=blocked
[[ "$required_sections_ready" == "1" ]] && section_status=pass
hash_status=blocked
[[ "$hash_manifest_ready" == "1" ]] && hash_status=pass
upstream_status=blocked
[[ "$h11c_ready" == "1" && "$h11d_ready" == "1" && "$h9h_ready" == "1" && "$v08_trace_ready" == "1" && "$v12_diag_ready" == "1" ]] && upstream_status=pass
ready_status=blocked
[[ "$real_run_binder_manifest_ready" == "1" ]] && ready_status=pass
jump_status=blocked
[[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && jump_status=pass

{
  echo "gate,status,reason"
  printf "run-directory-sections,%s,store=%d nlg=%d benchmark=%d speed=%d evidence=%d\n" \
    "$section_status" "$store_files" "$nlg_files" "$benchmark_files" "$speed_files" "$evidence_files"
  printf "run-directory-hash-manifest,%s,verified=%d/%d\n" \
    "$hash_status" "$hash_verified_files" "$hash_manifest_entries"
  printf "upstream-diagnostic-inputs,%s,h11c=%d h11d=%d h9h=%d v08_run=%d v12=%d\n" \
    "$upstream_status" "$h11c_ready" "$h11d_ready" "$h9h_ready" "$v08_trace_ready" "$v12_diag_ready"
  printf "real-run-binder-manifest,%s,ready=%d action=%s\n" \
    "$ready_status" "$real_run_binder_manifest_ready" "$action"
  printf "real-run-claims,blocked,actual_nonfixture=%d real_nlg=%d real_external=%d real_speed=%d real_release=%d\n" \
    "$actual_nonfixture_run_verified" "$real_pc_routelm_nlg_verified" "$real_external_benchmark_verified" "$real_workload_speed_evidence_ready" "$real_release_package_ready"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$jump_status" "$routing_trigger_rate" "$active_jump_rate"
} >"$DECISION_CSV"
