#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v05_route_quality_closure_summary.csv"

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
  echo "closure: ${label}" >&2
  "$@"
  printf '%s,pass\n' "$label" >>"$SUMMARY_CSV"
}

run_check shell-syntax bash -n "$ROOT_DIR"/experiments/*.sh
run_check build-dmv02 cmake --build "$ROOT_DIR/build" --target dmv02 -j2

run_check route-hint-oracle "$ROOT_DIR/experiments/test_v03_route_hint_oracle.sh"
run_check candidate-preset "$ROOT_DIR/experiments/test_v05_route_quality_candidate_preset.sh"
run_check candidate-preset-policy "$ROOT_DIR/experiments/test_v05_route_quality_candidate_preset_policy.sh"
run_check candidate-preset-policy-scale env RUN_SOURCE=0 \
  "$ROOT_DIR/experiments/test_v05_route_quality_candidate_preset_policy_scale.sh"

if [[ "$MODE" == "extended" ]]; then
  run_check route-code-adaptive "$ROOT_DIR/experiments/test_v03_route_hint_kv_hash_route_code_adaptive.sh"
  run_check candidate-preset-regression "$ROOT_DIR/experiments/test_v05_route_quality_candidate_preset_regression.sh"
  run_check candidate-basis-guardrail-scale env RUN_SOURCE=0 \
    "$ROOT_DIR/experiments/test_v05_route_quality_candidate_basis_guardrail.sh" --scale
fi

echo "route quality closure ${MODE} passed"
