#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

cmake -S . -B build -DDLE_ENABLE_HIP=OFF >/dev/null
cmake --build build --target v02_credit_core_contract -j "${AI_VERIFY_JOBS:-2}" >/dev/null
build/v02_credit_core_contract

echo "p1 v02 credit core contract passed"
