#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/audit_my_repo_pr.sh <repo> --base-ref <rev> [--head-ref <rev>] [audit-my-repo args...]

Runs audit-my-repo on files changed between two local git commits/refs.
The wrapper never fetches from the network. It writes a stable changed-files
input next to the requested --out directory, then passes that file to
audit_my_repo.sh --changed-files-from so the run remains reproducible.

Examples:
  ./scripts/audit_my_repo_pr.sh /path/to/repo --base-ref main --head-ref HEAD --mode quick --out results/my_repo_audit_pr

Environment defaults:
  AUDIT_MY_REPO_PR_BASE_REF, AUDIT_MY_REPO_PR_HEAD_REF
EOF
}

input_error() {
  echo "input_error: $*" >&2
  exit 2
}

need_value() {
  local flag="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    input_error "$flag requires a value"
  fi
}

resolve_out_dir() {
  python3 - "$ROOT_DIR" "$1" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).expanduser()
if not out.is_absolute():
    out = root / out
print(out.resolve())
PY
}

rev_parse_commit() {
  local repo="$1"
  local ref="$2"
  if ! git -C "$repo" rev-parse --verify --quiet "${ref}^{commit}"; then
    return 1
  fi
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi
if [ "$#" -lt 1 ]; then
  usage >&2
  exit 2
fi

repo_arg="$1"
shift

if ! repo_abs="$(cd "$repo_arg" 2>/dev/null && pwd -P)"; then
  input_error "target repo is not a directory: $repo_arg"
fi
if [ "$(git -C "$repo_abs" rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]; then
  input_error "target repo must be a git work tree: $repo_abs"
fi

base_ref="${AUDIT_MY_REPO_PR_BASE_REF:-}"
head_ref="${AUDIT_MY_REPO_PR_HEAD_REF:-HEAD}"
out_dir=""
out_supplied=0
audit_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base-ref|--base)
      need_value "$1" "${2:-}"
      base_ref="$2"
      shift 2
      ;;
    --base-ref=*|--base=*)
      base_ref="${1#*=}"
      need_value "--base-ref" "$base_ref"
      shift
      ;;
    --head-ref|--head)
      need_value "$1" "${2:-}"
      head_ref="$2"
      shift 2
      ;;
    --head-ref=*|--head=*)
      head_ref="${1#*=}"
      need_value "--head-ref" "$head_ref"
      shift
      ;;
    --changed-files-from|--changed-files-from=*)
      input_error "audit_my_repo_pr.sh generates --changed-files-from; do not pass it explicitly"
      ;;
    --out)
      need_value "$1" "${2:-}"
      out_dir="$2"
      out_supplied=1
      audit_args+=("$1" "$2")
      shift 2
      ;;
    --out=*)
      out_dir="${1#--out=}"
      need_value "--out" "$out_dir"
      out_supplied=1
      audit_args+=("$1")
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      audit_args+=("$@")
      break
      ;;
    *)
      audit_args+=("$1")
      shift
      ;;
  esac
done

for arg in "${audit_args[@]}"; do
  case "$arg" in
    --changed-files-from|--changed-files-from=*)
      input_error "audit_my_repo_pr.sh generates --changed-files-from; do not pass it explicitly"
      ;;
  esac
done

need_value "--base-ref" "$base_ref"
need_value "--head-ref" "$head_ref"

if [ "$out_supplied" -eq 0 ]; then
  out_dir="results/my_repo_audit_pr"
  audit_args+=("--out" "$out_dir")
fi

out_abs="$(resolve_out_dir "$out_dir")"
if [[ "$out_abs" == "$repo_abs" || "$out_abs" == "$repo_abs"/* ]]; then
  input_error "refusing --out inside target repo; use an output path outside the audited repository"
fi

if ! base_sha="$(rev_parse_commit "$repo_abs" "$base_ref")"; then
  input_error "--base-ref does not resolve to a local commit: $base_ref"
fi
if ! head_sha="$(rev_parse_commit "$repo_abs" "$head_ref")"; then
  input_error "--head-ref does not resolve to a local commit: $head_ref"
fi
if ! git -C "$repo_abs" merge-base "$base_sha" "$head_sha" >/dev/null 2>&1; then
  input_error "--base-ref and --head-ref do not have a local merge base"
fi

mkdir -p "$out_abs"
changed_file="$out_abs/pr_changed_files_${base_sha:0:12}_${head_sha:0:12}.txt"
tmp_changed="$(mktemp "$out_abs/.pr_changed_files_tmp.XXXXXX")"
cleanup_tmp() {
  rm -f "$tmp_changed"
}
trap cleanup_tmp EXIT

set +e
python3 - "$repo_abs" "$base_sha" "$head_sha" "$tmp_changed" <<'PY'
import subprocess
import sys

repo, base, head, out_path = sys.argv[1:]
proc = subprocess.run(
    ["git", "-C", repo, "diff", "--name-only", "-z", "--diff-filter=ACMRT", f"{base}...{head}"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if proc.returncode != 0:
    sys.exit(10)

rows = []
for raw in proc.stdout.split(b"\0"):
    if not raw:
        continue
    try:
        path = raw.decode("utf-8")
    except UnicodeDecodeError:
        sys.exit(11)
    if "\n" in path or "\r" in path or path.strip() != path:
        sys.exit(12)
    rows.append(path)

if not rows:
    sys.exit(13)

with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
    for path in sorted(dict.fromkeys(rows)):
        handle.write(path + "\n")
PY
diff_rc=$?
set -e

case "$diff_rc" in
  0)
    ;;
  10)
    input_error "git diff failed for local range: $base_ref...$head_ref"
    ;;
  11)
    input_error "changed file path is not UTF-8; write a checked file list and use audit_my_repo.sh --changed-files-from"
    ;;
  12)
    input_error "changed file path contains newline, carriage return, or trim-sensitive whitespace"
    ;;
  13)
    input_error "no changed files found for local range: $base_ref...$head_ref"
    ;;
  *)
    input_error "failed to build changed-files input for local range: $base_ref...$head_ref"
    ;;
esac

if [ -e "$changed_file" ]; then
  if ! cmp -s "$tmp_changed" "$changed_file"; then
    input_error "existing PR changed-files input differs at $changed_file"
  fi
  rm -f "$tmp_changed"
  created_changed_file=0
else
  mv "$tmp_changed" "$changed_file"
  created_changed_file=1
fi
trap - EXIT

set +e
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo_abs" --changed-files-from "$changed_file" "${audit_args[@]}"
audit_rc=$?
set -e

if [ "$audit_rc" -eq 2 ] && [ "$created_changed_file" -eq 1 ]; then
  rm -f "$changed_file"
fi

exit "$audit_rc"
