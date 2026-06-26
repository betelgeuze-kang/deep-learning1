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

echo "=== Codex + Kiro/Cursor research orchestration preflight ==="
echo

echo "[1] Project files"
test -f AGENTS.md && ok "AGENTS.md present" || bad "AGENTS.md missing"
test -f .codex/config.toml && ok ".codex/config.toml present" || note ".codex/config.toml missing"
test -f opencode.json && ok "opencode.json present" || bad "opencode.json missing"
test -f docs/ai/GOAL-LOOP-PLAYBOOK.md && ok "playbook present" || bad "playbook missing"
test -f docs/ai/profiles/deep-learning-research.md && ok "research profile present" || bad "research profile missing"
test -f docs/ai/prompts/deep_learning_research_goal_start.md && ok "research start prompt present" || bad "research start prompt missing"
test -f docs/ai/prompts/kiro_opus_prompt_architect.md && ok "Kiro Opus prompt architect template present" || bad "Kiro Opus prompt architect template missing"
test -f docs/ai/prompts/opencode_worker_slice.md && ok "OpenCode worker prompt present" || bad "OpenCode worker prompt missing"
test -f docs/ai/prompts/cursor_worker_slice.md && ok "Cursor worker prompt present" || bad "Cursor worker prompt missing"
test -f docs/ai/prompts/internal_subagent_worker_slice.md && ok "internal sub-agent worker prompt present" || bad "internal sub-agent worker prompt missing"
test -f docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md && ok "GitHub external mutation runbook present" || bad "GitHub external mutation runbook missing"
test -f docs/pm/EXTERNAL_MUTATION_APPROVAL_PACKET.md && ok "external mutation approval packet present" || bad "external mutation approval packet missing"
test -f tools/verify_repo_governance.py && ok "repo governance verifier present" || bad "repo governance verifier missing"
test -f tools/verify_github_external_state.py && ok "GitHub external state verifier present" || bad "GitHub external state verifier missing"
test -f tools/test_github_external_state_verifier.py && ok "GitHub external state verifier tests present" || bad "GitHub external state verifier tests missing"
test -f tools/verify_github_governance_commands.py && ok "GitHub command verifier present" || bad "GitHub command verifier missing"
test -f tools/verify_pr_cleanup_disposition_commands.py && ok "PR cleanup disposition command verifier present" || bad "PR cleanup disposition command verifier missing"
test -f scripts/refresh_github_external_snapshots.py && ok "GitHub read-only snapshot refresher present" || bad "GitHub read-only snapshot refresher missing"
test -f scripts/print_github_governance_commands.py && ok "GitHub governance command printer present" || bad "GitHub governance command printer missing"

if grep -q -- 'model = "gpt-5.5"' .codex/config.toml &&
   grep -q -- 'model_reasoning_effort = "xhigh"' .codex/config.toml; then
  ok "Codex verification default is gpt-5.5 xhigh"
else
  bad "Codex verification default is not gpt-5.5 xhigh"
fi

echo
echo "[2] Worker CLIs"
if command -v kiro >/dev/null 2>&1; then
  note "kiro found: $(command -v kiro); Kiro Opus prompt architecture is manual IDE-assisted, not a headless Codex worker"
else
  note "kiro CLI not found; Kiro Opus prompt architecture remains manual/external until available"
fi

if command -v cursor-agent >/dev/null 2>&1; then
  ok "cursor-agent found: $(command -v cursor-agent)"
elif command -v cursor >/dev/null 2>&1; then
  ok "cursor found: $(command -v cursor)"
else
  bad "Cursor CLI not found; Cursor composer-2.5 worker unavailable until installed"
fi

if command -v opencode >/dev/null 2>&1; then
  note "opencode found but former OpenCode worker assignment routes to Cursor composer-2.5"
else
  note "opencode not required; former OpenCode worker assignment routes to Cursor composer-2.5"
fi

echo
echo "[3] Wrapper syntax"
if bash -n scripts/ai-dangerous-command-check.sh scripts/ai-cursor-network-check.sh scripts/ai-worker-cursor.sh scripts/ai-worker-opencode.sh scripts/ai-preflight.sh scripts/ai-verify.sh scripts/audit_my_repo.sh scripts/audit_my_repo_pr.sh; then
  ok "ai wrapper shell syntax ok"
else
  bad "ai wrapper shell syntax failed"
fi

if grep -q -- 'OPENCODE_WORKER_CURSOR_MODEL="${OPENCODE_WORKER_CURSOR_MODEL:-composer-2.5}"' scripts/ai-worker-opencode.sh &&
   grep -q -- 'CURSOR_AGENT_MODEL="$OPENCODE_WORKER_CURSOR_MODEL" ./scripts/ai-worker-cursor.sh "$prompt_file"' scripts/ai-worker-opencode.sh; then
  ok "former OpenCode worker assignment routes to Cursor composer-2.5"
else
  bad "former OpenCode worker assignment is not routed to Cursor composer-2.5"
fi

if grep -q -- '--model "$CURSOR_AGENT_MODEL"' scripts/ai-worker-cursor.sh; then
  ok "cursor worker uses configured model"
else
  bad "cursor worker model wiring missing"
fi

if grep -q -- 'model=gpt-5.4-mini' docs/ai/prompts/internal_subagent_worker_slice.md &&
   grep -q -- 'reasoning_effort=xhigh' docs/ai/prompts/internal_subagent_worker_slice.md &&
   grep -q -- 'agent_type=worker' docs/ai/prompts/internal_subagent_worker_slice.md; then
  ok "internal sub-agent fallback is pinned to gpt-5.4-mini xhigh worker"
else
  bad "internal sub-agent fallback model pin missing"
fi

if grep -q -- 'Kiro Opus 4.8' docs/ai/prompts/kiro_opus_prompt_architect.md &&
   grep -q -- 'Cursor Composer 2.5' docs/ai/prompts/kiro_opus_prompt_architect.md &&
   grep -q -- 'Codex GPT-5.5 xhigh' docs/ai/prompts/kiro_opus_prompt_architect.md &&
   grep -q -- 'does not currently have a verified headless Kiro Opus 4.8 worker wrapper' docs/ai/prompts/kiro_opus_prompt_architect.md &&
   grep -q -- 'Do not edit code' docs/ai/prompts/kiro_opus_prompt_architect.md; then
  ok "manual Kiro -> Cursor -> Codex orchestration contract documented"
else
  bad "Kiro -> Cursor -> Codex orchestration contract incomplete"
fi

if ./scripts/ai-cursor-network-check.sh api2.cursor.sh >/dev/null 2>&1; then
  ok "cursor worker network/DNS reachable"
else
  bad "cursor worker network/DNS unavailable in this Codex environment"
fi

echo
echo "[4] GitHub governance contracts"
if python3 -m py_compile tools/verify_repo_governance.py tools/verify_github_external_state.py tools/test_github_external_state_verifier.py tools/verify_github_governance_commands.py tools/verify_pr_cleanup_disposition_commands.py scripts/refresh_github_external_snapshots.py scripts/print_github_governance_commands.py >/dev/null 2>&1; then
  ok "GitHub governance Python syntax ok"
else
  bad "GitHub governance Python syntax failed"
fi

if python3 tools/test_github_external_state_verifier.py >/dev/null 2>&1; then
  ok "GitHub external state verifier fixture tests passed"
else
  bad "GitHub external state verifier fixture tests failed"
fi

if python3 tools/verify_github_governance_commands.py >/dev/null 2>&1; then
  ok "GitHub governance command output is allowlisted"
else
  bad "GitHub governance command output verification failed"
fi

if python3 tools/verify_pr_cleanup_disposition_commands.py >/dev/null 2>&1; then
  ok "PR cleanup disposition commands are allowlisted"
else
  bad "PR cleanup disposition command verification failed"
fi

if python3 tools/verify_github_external_state.py --mode pending . >/dev/null 2>&1; then
  ok "GitHub external state pending snapshot verified"
else
  bad "GitHub external state pending snapshot failed"
fi

if python3 tools/verify_github_external_state.py --mode partial . >/dev/null 2>&1; then
  ok "GitHub external state partial snapshot verified"
else
  bad "GitHub external state partial snapshot failed"
fi

if python3 tools/verify_repo_governance.py . >/dev/null 2>&1; then
  ok "repo governance contract verified"
else
  bad "repo governance contract failed"
fi

echo
echo "[5] Local verify"
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
