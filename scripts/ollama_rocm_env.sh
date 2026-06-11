#!/usr/bin/env bash
# Source before `ollama serve` on AMD ROCm hosts (e.g. RX 6800, gfx1030).
# Usage: source scripts/ollama_rocm_env.sh
export ROCM_PATH="${ROCM_PATH:-/opt/rocm-6.0.2}"
export HIP_PATH="${HIP_PATH:-$ROCM_PATH}"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure_rocm_device_libs.sh"
export HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}"
export HCC_AMDGPU_TARGET="${HCC_AMDGPU_TARGET:-gfx1030}"
export OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-1}"
export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-1}"
unset HIP_LAUNCH_BLOCKING
