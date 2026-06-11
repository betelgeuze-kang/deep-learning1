#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--source-bound-qa" ]]; then
  shift
  exec "$ROOT_DIR/experiments/run_v61n_source_bound_qa_workload.sh" "$@"
fi

exec "$ROOT_DIR/experiments/run_v61j_one_command_ssd_resident_demo.sh" "$@"
