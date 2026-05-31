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
run_check h9-measured-speed-gate "$ROOT_DIR/experiments/test_v09_gpu_backend_measured_speed_gate.sh"
run_check h9-measured-speed-import "$ROOT_DIR/experiments/test_v09_gpu_backend_measured_speed_import.sh"
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
run_check v08-external-benchmark-execution \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_execution_gate.sh"
run_check v08-external-benchmark-execution-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_execution_import.sh"
run_check v08-external-benchmark-attestation \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_attestation_gate.sh"
run_check v08-external-benchmark-attestation-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_attestation_import.sh"
run_check v08-external-benchmark-attestor-identity \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_attestor_identity_gate.sh"
run_check v08-external-benchmark-attestor-identity-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_attestor_identity_import.sh"
run_check v08-external-benchmark-lower-chain-remote-artifacts \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh"
run_check v08-external-benchmark-source-import-gate \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_gate.sh"
run_check v08-external-benchmark-source-import-remote-contract \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_remote_contract.sh"
run_check v08-external-benchmark-source-import-verifier \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_verifier_gate.sh"
run_check v08-external-benchmark-source-import-live-verifier \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_verifier_gate.sh"
run_check v08-external-benchmark-source-import-live-review \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_review_gate.sh"
run_check v08-external-benchmark-source-import-authoritative-review \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_authoritative_review_gate.sh"
run_check v08-external-benchmark-source-import-public-registry \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_public_registry_gate.sh"
run_check v08-external-benchmark-source-import-live-registry-query \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_query_gate.sh"
run_check v08-external-benchmark-source-import-live-registry-fetcher \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_fetcher.sh"
run_check v08-external-benchmark-source-import-live-registry-network-proof \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_network_proof.sh"
run_check v08-external-benchmark-source-import-real-verification \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_real_verification_gate.sh"
run_check v08-external-benchmark-source-import-official-authority \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_official_authority_gate.sh"
run_check v08-external-benchmark-final-review \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_gate.sh"
run_check v08-external-benchmark-final-review-import \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_import.sh"
run_check v08-external-benchmark-final-review-real-source-guard \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_real_source_guard.sh"
run_check v08-external-benchmark-final-review-remote-review-guard \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_remote_review_guard.sh"
run_check v08-external-benchmark-final-review-remote-full-guard \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_remote_full_guard.sh"
run_check v08-external-benchmark-result-authority \
  "$ROOT_DIR/experiments/test_v08_external_benchmark_result_authority_gate.sh"
run_check v11-pc-routelm-prototype-readiness \
  "$ROOT_DIR/experiments/test_v11_pc_routelm_prototype_readiness.sh"
run_check v11-pc-routelm-prototype-import \
  "$ROOT_DIR/experiments/test_v11_pc_routelm_prototype_import.sh"
run_check v11-pc-routelm-prototype-artifact-verifier \
  "$ROOT_DIR/experiments/test_v11_pc_routelm_prototype_artifact_verifier.sh"
run_check v11-pc-routelm-prototype-artifact-import \
  "$ROOT_DIR/experiments/test_v11_pc_routelm_prototype_artifact_import.sh"

if [[ "$MODE" == "extended" ]]; then
  run_check h9-hip-candidate-weight-parity \
    "$ROOT_DIR/experiments/test_v09_gpu_backend_candidate_weight_parity.sh"
else
  echo "h9 closure: HIP parity optional; use --extended to run it" >&2
fi

echo "v09 GPU backend closure ${MODE} passed"
