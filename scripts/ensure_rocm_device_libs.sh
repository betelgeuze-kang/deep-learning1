#!/usr/bin/env bash
# Resolve HIP device bitcode libs for hipcc when rocm-device-libs is not installed system-wide.
# Usage: source scripts/ensure_rocm_device_libs.sh
set -euo pipefail

_resolve_rocm_device_lib_path() {
  local candidate
  if [[ -n "${HIP_DEVICE_LIB_PATH:-}" && -f "${HIP_DEVICE_LIB_PATH}/ockl.bc" ]]; then
    printf '%s\n' "$HIP_DEVICE_LIB_PATH"
    return 0
  fi

  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local cache_dir="$root_dir/.cache/rocm-device-libs/amdgcn/bitcode"

  for candidate in \
    "$cache_dir" \
    "${ROCM_PATH:-/opt/rocm-6.0.2}/amdgcn/bitcode" \
    "/opt/rocm/amdgcn/bitcode" \
    "/opt/rocm-6.0.2/amdgcn/bitcode"; do
    if [[ -f "$candidate/ockl.bc" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg-deb >/dev/null 2>&1; then
    return 1
  fi

  local dl_dir extract_dir bitcode_dir
  dl_dir="$(mktemp -d)"
  trap 'rm -rf "$dl_dir"' RETURN
  (cd "$dl_dir" && apt-get download -qq rocm-device-libs)
  dpkg-deb -x "$dl_dir"/rocm-device-libs*.deb "$dl_dir/extract"
  bitcode_dir="$(find "$dl_dir/extract" -path '*/amdgcn/bitcode/ockl.bc' -print -quit)"
  if [[ -z "$bitcode_dir" ]]; then
    return 1
  fi
  bitcode_dir="$(dirname "$bitcode_dir")"
  mkdir -p "$cache_dir"
  cp -a "$bitcode_dir/." "$cache_dir/"
  printf '%s\n' "$cache_dir"
}

if HIP_DEVICE_LIB_PATH="$(_resolve_rocm_device_lib_path)"; then
  export HIP_DEVICE_LIB_PATH
else
  echo "ensure_rocm_device_libs: could not resolve HIP device bitcode path" >&2
  return 1 2>/dev/null || exit 1
fi
