#!/usr/bin/env bash
set -euo pipefail

# Static command-string guard for wrapper launch commands.
# This is not a sandbox; it only blocks obvious forbidden wrapper commands.

cmd="${*:-}"
for pat in \
  "git push" \
  "git merge" \
  "npm publish" \
  "pnpm publish" \
  "yarn publish" \
  "docker push" \
  "kubectl apply" \
  "terraform apply" \
  "vercel deploy --prod" \
  "railway up" \
  "fly deploy" \
  "stripe refunds create" \
  "prisma migrate deploy" \
  "supabase db push"; do
  if printf '%s' "$cmd" | grep -qi "$pat"; then
    echo "Blocked dangerous command pattern in wrapper/config command: $pat" >&2
    exit 2
  fi
done
