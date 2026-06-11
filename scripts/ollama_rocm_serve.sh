#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/ollama_rocm_env.sh"
export PATH="/opt/rocm/bin:${PATH:-}"

exec ollama serve "$@"
