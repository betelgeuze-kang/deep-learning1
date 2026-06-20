#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="${HOME}/.local/bin:${PATH}"
if command -v npm >/dev/null 2>&1; then
  npm_prefix="$(npm prefix -g 2>/dev/null || true)"
  if [ -n "$npm_prefix" ]; then
    export PATH="${npm_prefix}/bin:${PATH}"
  fi
fi

pass=0
warn=0
fail=0

ok() { echo "  OK   $*"; pass=$((pass + 1)); }
note() { echo "  WARN $*"; warn=$((warn + 1)); }
bad() { echo "  FAIL $*"; fail=$((fail + 1)); }

echo "=== Codex + OpenCode/Cursor research orchestration preflight ==="
echo

echo "[1] Project files"
test -f AGENTS.md && ok "AGENTS.md present" || bad "AGENTS.md missing"
test -f .codex/config.toml && ok ".codex/config.toml present" || note ".codex/config.toml missing"
test -f opencode.json && ok "opencode.json present" || bad "opencode.json missing"
test -f docs/ai/GOAL-LOOP-PLAYBOOK.md && ok "playbook present" || bad "playbook missing"
test -f docs/ai/profiles/deep-learning-research.md && ok "research profile present" || bad "research profile missing"
test -f docs/ai/prompts/deep_learning_research_goal_start.md && ok "research start prompt present" || bad "research start prompt missing"
test -f docs/ai/prompts/opencode_worker_slice.md && ok "OpenCode worker prompt present" || bad "OpenCode worker prompt missing"
test -f docs/ai/prompts/cursor_worker_slice.md && ok "Cursor worker prompt present" || bad "Cursor worker prompt missing"

echo
echo "[2] Worker CLIs"
if command -v cursor-agent >/dev/null 2>&1; then
  ok "cursor-agent found: $(command -v cursor-agent)"
elif command -v cursor >/dev/null 2>&1; then
  ok "cursor found: $(command -v cursor)"
else
  note "Cursor CLI not found; Cursor worker unavailable until installed"
fi

if command -v opencode >/dev/null 2>&1; then
  ok "opencode found: $(command -v opencode)"
  ok "opencode version: $(opencode --version)"
else
  bad "opencode not found. Install with: npm install -g opencode-ai"
fi

echo
echo "[3] Wrapper syntax"
if bash -n scripts/ai-dangerous-command-check.sh scripts/ai-worker-cursor.sh scripts/ai-worker-opencode.sh scripts/ai-preflight.sh scripts/ai-verify.sh; then
  ok "ai wrapper shell syntax ok"
else
  bad "ai wrapper shell syntax failed"
fi

if grep -q -- '--file "$prompt_file"' scripts/ai-worker-opencode.sh; then
  ok "opencode worker passes prompt by file"
else
  bad "opencode worker prompt-file wiring missing"
fi

if grep -q -- '--model "$CURSOR_AGENT_MODEL"' scripts/ai-worker-cursor.sh; then
  ok "cursor worker uses configured model"
else
  bad "cursor worker model wiring missing"
fi

echo
echo "[4] Local verify"
if ./scripts/ai-verify.sh >/dev/null 2>&1; then
  ok "ai-verify.sh passed"
else
  bad "ai-verify.sh failed"
fi

echo
echo "=== Summary: ${pass} ok, ${warn} warn, ${fail} fail ==="
if [ "$fail" -gt 0 ]; then
  exit 1
fi
