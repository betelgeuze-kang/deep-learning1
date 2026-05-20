#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v09_gpu_backend_extended_boundary_summary.csv"

MODE="quick"
if [[ "${1:-}" == "--extended" ]]; then
  MODE="extended"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--extended]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"
printf 'check,status\n' >"$SUMMARY_CSV"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 hip_candidate_weight_parity -j2 >/dev/null
printf 'cpu-and-parity-tool-build,pass\n' >>"$SUMMARY_CSV"

rg -q 'proposal_max_abs_delta' "$ROOT_DIR/src/tools/hip_candidate_weight_parity.cpp"
rg -q 'cpu_best' "$ROOT_DIR/src/tools/hip_candidate_weight_parity.cpp"
rg -q 'hip_best' "$ROOT_DIR/src/tools/hip_candidate_weight_parity.cpp"
rg -q 'final_stats\.hip_kernel_calls < 2' "$ROOT_DIR/src/tools/hip_candidate_weight_parity.cpp"
printf 'proposal-score-parity-tool-boundary,pass\n' >>"$SUMMARY_CSV"

rg -q 'route_quality_candidate_weight_factor_mean' "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
rg -q 'fixture_query_byte_acc' "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
rg -q 'routing_trigger_rate' "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
rg -q 'active_jump_rate' "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
printf 'fixture-parity-boundary,pass\n' >>"$SUMMARY_CSV"

if [[ "$MODE" == "extended" ]]; then
  "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
  printf 'optional-hip-parity,pass-or-skip\n' >>"$SUMMARY_CSV"
else
  printf 'optional-hip-parity,skipped\n' >>"$SUMMARY_CSV"
fi

echo "v09 GPU backend extended boundary ${MODE} passed"
