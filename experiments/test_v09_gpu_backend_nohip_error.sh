#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

ERR="$TMP_DIR/nohip.err"
set +e
"$BUILD_DIR/dmv02" \
  --backend hip \
  --dataset counter \
  --N 16 \
  --epochs 1 \
  --cycles-per-epoch 1 >"$TMP_DIR/nohip.out" 2>"$ERR"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "--backend hip unexpectedly succeeded in the CPU-only build" >&2
  exit 1
fi
if ! grep -q "DLE_ENABLE_HIP=ON" "$ERR"; then
  echo "missing clear DLE_ENABLE_HIP error message" >&2
  cat "$ERR" >&2
  exit 1
fi

echo "h9 no-HIP runtime error smoke passed"
