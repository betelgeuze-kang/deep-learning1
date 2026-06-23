#!/usr/bin/env bash
set -euo pipefail
prompt_file="${1:?usage: ai-worker-cursor.sh <prompt-file>}"

if [[ ! -f "$prompt_file" ]]; then
  echo "Prompt file not found: $prompt_file" >&2
  exit 2
fi

CURSOR_AGENT_MODEL="${CURSOR_AGENT_MODEL:-auto}"
CURSOR_AGENT_SANDBOX="${CURSOR_AGENT_SANDBOX:-enabled}"
CURSOR_AGENT_REQUIRE_NETWORK="${CURSOR_AGENT_REQUIRE_NETWORK:-enabled}"

if [[ "$CURSOR_AGENT_REQUIRE_NETWORK" != "0" &&
      "$CURSOR_AGENT_REQUIRE_NETWORK" != "false" &&
      "$CURSOR_AGENT_REQUIRE_NETWORK" != "False" &&
      "$CURSOR_AGENT_REQUIRE_NETWORK" != "FALSE" &&
      "$CURSOR_AGENT_REQUIRE_NETWORK" != "disabled" &&
      "$CURSOR_AGENT_REQUIRE_NETWORK" != "Disabled" &&
      "$CURSOR_AGENT_REQUIRE_NETWORK" != "DISABLED" ]]; then
  if ! ./scripts/ai-cursor-network-check.sh api2.cursor.sh; then
    cat >&2 <<'EOF'
Cursor worker cannot run from the current Codex sandbox because outbound
network/DNS is unavailable here. This is not a prompt, model, or wrapper
routing problem: Cursor Agent needs network access to api2.cursor.sh.

Run this worker from a network-enabled terminal/Codex session, or disable this
guard only for diagnostics with CURSOR_AGENT_REQUIRE_NETWORK=disabled.
EOF
    exit 75
  fi
fi

if ! command -v cursor-agent >/dev/null 2>&1 && [ -x "${HOME}/.local/bin/cursor-agent" ]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

if command -v cursor-agent >/dev/null 2>&1; then
  CURSOR_AGENT_CMD=(cursor-agent)
elif command -v cursor >/dev/null 2>&1; then
  CURSOR_AGENT_CMD=(cursor agent)
elif [ -x "${HOME}/.local/bin/cursor" ]; then
  CURSOR_AGENT_CMD=("${HOME}/.local/bin/cursor" agent)
else
  echo "Neither cursor-agent nor cursor was found on PATH." >&2
  exit 2
fi

./scripts/ai-dangerous-command-check.sh "${CURSOR_AGENT_CMD[*]} --model ${CURSOR_AGENT_MODEL} < prompt-file"

"${CURSOR_AGENT_CMD[@]}" \
  --print \
  --force \
  --trust \
  --sandbox "$CURSOR_AGENT_SANDBOX" \
  --model "$CURSOR_AGENT_MODEL" < "$prompt_file"
