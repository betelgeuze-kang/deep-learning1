#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_closure_summary.csv"

MODE="quick"
if [[ "${1:-}" == "--extended" ]]; then
  MODE="extended"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--extended]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"
printf 'check,status\n' >"$SUMMARY_CSV"

run_check() {
  local label="$1"
  shift
  echo "h9 closure: ${label}" >&2
  "$@"
  printf '%s,pass\n' "$label" >>"$SUMMARY_CSV"
}

run_check shell-syntax bash -n "$ROOT_DIR"/experiments/*.sh
run_check cpu-build cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
run_check build-dmv02 cmake --build "$BUILD_DIR" --target dmv02 -j2
run_check h9-cpu-smoke "$ROOT_DIR/experiments/test_v09_gpu_backend_cpu_smoke.sh"
run_check h9-nohip-error "$ROOT_DIR/experiments/test_v09_gpu_backend_nohip_error.sh"
run_check h9-extended-boundary "$ROOT_DIR/experiments/test_v09_gpu_backend_extended_boundary.sh"
run_check h9-speed-evidence "$ROOT_DIR/experiments/test_v09_gpu_backend_speed_evidence.sh"
run_check h5-route-quality-closure "$ROOT_DIR/experiments/test_v05_route_quality_closure.sh"
run_check h7-goal-closure "$ROOT_DIR/experiments/test_v07_goal_route_memory_closure.sh"
run_check v08-external-benchmark-adapter \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_adapter.sh"
run_check v08-external-benchmark-evidence-ingestion \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_evidence_ingestion.sh"
run_check v08-external-benchmark-evidence-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_evidence_import.sh"
run_check v08-external-benchmark-readiness \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_readiness.sh"
run_check v08-external-benchmark-comparison-gate \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_comparison_gate.sh"
run_check v08-external-benchmark-comparison-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_comparison_import.sh"
run_check v08-external-benchmark-real-evidence \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_real_evidence_gate.sh"
run_check v08-external-benchmark-real-evidence-placeholder \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_real_evidence_placeholder.sh"
run_check v08-external-benchmark-real-evidence-format \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_real_evidence_format.sh"
run_check v08-external-benchmark-artifact-verifier \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_artifact_verifier.sh"
run_check v08-external-benchmark-artifact-verifier-local \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_artifact_verifier_local.sh"
run_check v08-external-benchmark-authenticity \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_authenticity_gate.sh"
run_check v08-external-benchmark-authenticity-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_authenticity_import.sh"
run_check v11-pc-routelm-prototype-readiness \
  "$ROOT_DIR/experiments/test_v11_pc_routelm_prototype_readiness.sh"
run_check v11-pc-routelm-prototype-import \
  "$ROOT_DIR/experiments/test_v11_pc_routelm_prototype_import.sh"

if [[ "$MODE" == "extended" ]]; then
  run_check h9-hip-candidate-weight-parity \
    "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
else
  echo "h9 closure: HIP parity optional; use --extended to run it" >&2
fi

echo "v09 GPU backend closure ${MODE} passed"
