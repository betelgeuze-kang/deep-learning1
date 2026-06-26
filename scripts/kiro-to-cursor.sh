#!/usr/bin/env bash
# Auto-dispatch a Kiro Opus 4.8 prompt-architect prompt to Cursor CLI Composer 2.5.
#
# Governance (AGENTS.md):
# - Codex GPT-5.5 xhigh remains goal owner and final acceptance authority. This
#   wrapper only automates the Kiro-prompt -> Cursor Composer 2.5 handoff; it
#   does NOT replace Codex diff review. Codex must still review the resulting
#   git diff and run ./scripts/ai-verify.sh before accepting worker output.
# - The dispatch prompt is preserved under docs/ai/dispatch/ as the governance
#   trail before any live worker run.
# - Default model is composer-2.5 (override with CURSOR_AGENT_MODEL).
#
# Usage:
#   scripts/kiro-to-cursor.sh <prompt-file> [--plan]
#   scripts/kiro-to-cursor.sh --stdin <task-id> [--plan]   # read prompt from stdin
#
#   --plan   Plan-mode dispatch (no --force). NOTE: the installed cursor-agent
#            version does not guarantee read-only behavior under --plan; review
#            any resulting git diff as untrusted worker output.
set -euo pipefail

DISPATCH_DIR="docs/ai/dispatch"
MODEL="${CURSOR_AGENT_MODEL:-composer-2.5}"
PLAN_MODE=0
READ_STDIN=0

usage() {
  cat >&2 <<'EOF'
usage: kiro-to-cursor.sh <prompt-file> [--plan]
   or: kiro-to-cursor.sh --stdin <task-id> [--plan]

  --plan   Plan-mode dispatch (cursor-agent --plan; not guaranteed read-only).

Environment:
  CURSOR_AGENT_MODEL   Cursor model to use (default: composer-2.5)
EOF
  exit 2
}

positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) PLAN_MODE=1; shift ;;
    --stdin) READ_STDIN=1; shift ;;
    -h|--help) usage ;;
    --) shift; while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) positional+=("$1"); shift ;;
  esac
done

if [[ "$READ_STDIN" == "1" ]]; then
  task_id="${positional[0]:-}"
  [[ -n "$task_id" ]] || usage
  mkdir -p "$DISPATCH_DIR"
  prompt_file="${DISPATCH_DIR}/$(date -u +%Y-%m-%d)-${task_id}.md"
  cat > "$prompt_file"
  echo "kiro-to-cursor: wrote dispatch prompt -> $prompt_file" >&2
else
  prompt_file="${positional[0]:-}"
  [[ -n "$prompt_file" ]] || usage
fi

if [[ ! -f "$prompt_file" ]]; then
  echo "kiro-to-cursor: prompt file not found: $prompt_file" >&2
  exit 2
fi

# Preserve a dispatch record (governance trail) for prompts authored elsewhere.
case "$prompt_file" in
  "$DISPATCH_DIR"/*) : ;;
  *)
    mkdir -p "$DISPATCH_DIR"
    record="${DISPATCH_DIR}/$(date -u +%Y-%m-%d)-$(basename "${prompt_file%.md}").md"
    if [[ "$record" != "$prompt_file" ]]; then
      cp "$prompt_file" "$record"
      echo "kiro-to-cursor: copied dispatch record -> $record" >&2
      prompt_file="$record"
    fi
    ;;
esac

# If the prompt file holds the full Kiro deliverable (both markers present),
# forward only the "Cursor implementation prompt:" section to the worker and
# keep the "Kiro design notes:" block as the dispatch record only.
worker_prompt_file="$prompt_file"
cleanup_tmp=""
if grep -q '^Cursor implementation prompt:' "$prompt_file" \
   && grep -q '^Kiro design notes:' "$prompt_file"; then
  worker_prompt_file="$(mktemp "${TMPDIR:-/tmp}/kiro-cursor-prompt.XXXXXX")"
  cleanup_tmp="$worker_prompt_file"
  awk '
    /^Cursor implementation prompt:/ {capture=1}
    /^Kiro design notes:/ {capture=0}
    capture {print}
  ' "$prompt_file" > "$worker_prompt_file"
  echo "kiro-to-cursor: forwarding only the 'Cursor implementation prompt:' section" >&2
fi
cleanup() { [[ -n "$cleanup_tmp" && -f "$cleanup_tmp" ]] && rm -f "$cleanup_tmp"; }
trap cleanup EXIT

echo "kiro-to-cursor: model=${MODEL} plan_mode=${PLAN_MODE} prompt=${prompt_file}" >&2

if [[ "$PLAN_MODE" == "1" ]]; then
  # Plan-mode dispatch. NOTE: in the installed cursor-agent version, --plan does
  # NOT guarantee read-only behavior (it was observed creating files). Treat any
  # resulting changes as untrusted worker output and review the git diff.
  if [[ -x ./scripts/ai-dangerous-command-check.sh ]]; then
    ./scripts/ai-dangerous-command-check.sh "cursor-agent --print --plan --trust --model ${MODEL} < prompt-file"
  fi
  if ! command -v cursor-agent >/dev/null 2>&1 && [ -x "${HOME}/.local/bin/cursor-agent" ]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  exec cursor-agent --print --plan --trust --model "$MODEL" < "$worker_prompt_file"
fi

# Live implementation run: delegate to the guarded Cursor worker wrapper, which
# enforces the network check and dangerous-command check before editing code.
exec env CURSOR_AGENT_MODEL="$MODEL" ./scripts/ai-worker-cursor.sh "$worker_prompt_file"
