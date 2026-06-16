#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> ai wrapper shell syntax"
bash -n scripts/ai-dangerous-command-check.sh scripts/ai-worker-cursor.sh scripts/ai-worker-opencode.sh scripts/ai-preflight.sh scripts/ai-verify.sh

echo "==> json"
python3 -m json.tool opencode.json >/dev/null

echo "==> python syntax"
python_files="$(find . \
  -path './.git' -prune -o \
  -path './build' -prune -o \
  -path './results' -prune -o \
  -path './.cache' -prune -o \
  -path './.venv' -prune -o \
  -path './venv' -prune -o \
  -path './env' -prune -o \
  -path './node_modules' -prune -o \
  -path './.mypy_cache' -prune -o \
  -path './.pytest_cache' -prune -o \
  -path './__pycache__' -prune -o \
  -type f -name '*.py' -print)"
if [ -n "$python_files" ]; then
  while IFS= read -r py_file; do
    [ -n "$py_file" ] || continue
    python3 -m py_compile "$py_file"
  done <<EOF
$python_files
EOF
else
  echo "no python files detected outside ignored generated dirs"
fi

echo "==> cmake configure/build smoke"
if [ -f CMakeLists.txt ]; then
  DLE_VERIFY_ENABLE_HIP="${DLE_VERIFY_ENABLE_HIP:-OFF}"
  AI_VERIFY_JOBS="${AI_VERIFY_JOBS:-2}"
  cmake -S . -B build -DDLE_ENABLE_HIP="$DLE_VERIFY_ENABLE_HIP" >/dev/null
  cmake --build build -j "$AI_VERIFY_JOBS" >/dev/null

  mkdir -p results
  if [ -x build/dmv01 ]; then
    build/dmv01 --N 32 --cycles 5 --seed 1 --csv results/ai_verify_v01_smoke.csv >/dev/null
    test -s results/ai_verify_v01_smoke.csv
  fi
  if [ -x build/dmv02 ]; then
    build/dmv02 --dataset counter --N 32 --epochs 1 --cycles-per-epoch 2 --seed 1 --csv results/ai_verify_v02_smoke.csv >/dev/null
    test -s results/ai_verify_v02_smoke.csv
  fi
fi

echo "==> required orchestration files"
test -f AGENTS.md
test -f .codex/config.toml
test -f opencode.json
test -f docs/ai/GOAL-LOOP-PLAYBOOK.md
test -f docs/ai/profiles/deep-learning-research.md
test -f docs/ai/prompts/deep_learning_research_goal_start.md
test -f docs/ai/prompts/opencode_worker_slice.md
test -f docs/ai/prompts/cursor_worker_slice.md
test -x scripts/ai-worker-cursor.sh
test -x scripts/ai-worker-opencode.sh

echo "verify ok"
