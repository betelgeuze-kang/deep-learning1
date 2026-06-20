#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "usage: tools/check_tracked_results_policy.sh <allowlist-file> [tracked-results-file]" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

ALLOWLIST_FILE="$1"
TRACKED_RESULTS_FILE="${2:-}"

if [ ! -f "$ALLOWLIST_FILE" ]; then
  echo "tracked results allowlist not found: $ALLOWLIST_FILE" >&2
  exit 2
fi
if [ -n "$TRACKED_RESULTS_FILE" ] && [ ! -f "$TRACKED_RESULTS_FILE" ]; then
  echo "tracked results list not found: $TRACKED_RESULTS_FILE" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tracked-results-policy.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ALLOW_SORTED="$TMP_DIR/allowlist.sorted"
TRACKED_SORTED="$TMP_DIR/tracked.sorted"

if grep -nE '(^[[:space:]]*$|^[[:space:]]|[[:space:]]$)' "$ALLOWLIST_FILE" >/dev/null; then
  echo "tracked results allowlist must use one clean path per line with no blanks" >&2
  grep -nE '(^[[:space:]]*$|^[[:space:]]|[[:space:]]$)' "$ALLOWLIST_FILE" >&2
  exit 1
fi

while IFS= read -r path; do
  case "$path" in
    results/*) ;;
    *)
      echo "tracked results allowlist path must stay under results/: $path" >&2
      exit 1
      ;;
  esac
  case "$path" in
    *"/../"*|../*|*/..|*"/./"*|./*|*/.)
      echo "tracked results allowlist path must not contain traversal segments: $path" >&2
      exit 1
      ;;
  esac
done < "$ALLOWLIST_FILE"

LC_ALL=C sort -u "$ALLOWLIST_FILE" > "$ALLOW_SORTED"

if [ -n "$TRACKED_RESULTS_FILE" ]; then
  LC_ALL=C sort -u "$TRACKED_RESULTS_FILE" > "$TRACKED_SORTED"
else
  (
    cd "$ROOT_DIR"
    git ls-files 'results/**'
  ) | LC_ALL=C sort -u > "$TRACKED_SORTED"
fi

while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    *.bin|*.ckpt|*.gguf|*.npy|*.npz|*.onnx|*.pt|*.pth|*.safetensors|*.tar|*.tar.gz|*.tgz|*.zip)
      echo "tracked checkpoint/model payload path is forbidden under results/: $path" >&2
      exit 1
      ;;
  esac
done < "$TRACKED_SORTED"

EXTRA_TRACKED="$(comm -13 "$ALLOW_SORTED" "$TRACKED_SORTED" || true)"
if [ -n "$EXTRA_TRACKED" ]; then
  echo "tracked generated results are forbidden outside allowlist:" >&2
  echo "$EXTRA_TRACKED" >&2
  exit 1
fi

MISSING_TRACKED="$(comm -23 "$ALLOW_SORTED" "$TRACKED_SORTED" || true)"
if [ -n "$MISSING_TRACKED" ]; then
  echo "tracked results allowlist contains missing paths:" >&2
  echo "$MISSING_TRACKED" >&2
  exit 1
fi

echo "tracked results policy ok"
