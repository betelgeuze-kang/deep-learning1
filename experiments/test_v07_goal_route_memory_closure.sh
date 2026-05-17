#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

MODE="quick"
if [[ "${1:-}" == "--extended" ]]; then
  MODE="extended"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--extended]" >&2
  exit 2
fi

echo "goal: shell-syntax"
bash -n "$ROOT_DIR"/experiments/*.sh

echo "goal: build-dmv02"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2

echo "goal: h5-route-quality-closure"
if [[ "$MODE" == "extended" ]]; then
  bash "$ROOT_DIR/experiments/test_v05_route_quality_closure.sh" --extended
else
  bash "$ROOT_DIR/experiments/test_v05_route_quality_closure.sh"
fi

echo "goal: h6-span-boundary"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_boundary.sh"

echo "goal: h6-exact-span"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_exact.sh"

echo "goal: h6-exact-span-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_exact_scale.sh"

echo "goal: h6-hash-span"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_hash.sh"

echo "goal: h6-hash-span-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_hash_scale.sh"

if [[ "$MODE" == "extended" ]]; then
  echo "goal: h6-exact-span-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_exact_scale.sh" >/dev/null

  echo "goal: h6-hash-span-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_hash_scale.sh" >/dev/null
fi

echo "v07 goal route-memory closure passed"
