#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
AUDIT_DIR="$RESULTS_DIR/v0_3_completion_audit"
SUMMARY_CSV="$RESULTS_DIR/v0_3_completion_audit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v0_3_completion_audit_decision.csv"

"$ROOT_DIR/experiments/run_v0_3_completion_audit.sh" >/dev/null

awk -F, '
  function die(text, code) { print text > "/dev/stderr"; exit code }
  NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
  {
    if ($idx["v0_3_completion_audit_ready"] != "1") die("completion audit not ready", 2)
    if ($idx["blocked_rows"] != "0") die("completion audit has blocked rows", 3)
    if ($idx["baseline_rows"] != "8") die("completion audit baseline_rows mismatch", 4)
    if ($idx["scaling_curve_rows"] != "27") die("completion audit scaling_curve_rows mismatch", 5)
    if ($idx["real_release_package_ready"] != "0") die("completion audit release boundary mismatch", 6)
    if ($idx["gpu_speedup_claim"] != "deferred") die("completion audit gpu boundary mismatch", 7)
    rows++
  }
  END { if (rows != 1) die("expected one completion audit summary row", 8) }
' "$SUMMARY_CSV"

awk -F, '
  function die(text, code) { print text > "/dev/stderr"; exit code }
  NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
  $idx["gate"] == "v0.3-completion-audit" { found_completion = 1; if ($idx["status"] != "pass") die("completion gate should pass", 10) }
  $idx["gate"] == "remote-push-pr" { found_remote = 1; if ($idx["status"] != "blocked") die("remote gate should stay blocked without approval", 11) }
  $idx["gate"] == "real-release-package" { found_release = 1; if ($idx["status"] != "blocked") die("release gate should stay blocked", 12) }
  END {
    if (!found_completion) die("missing completion gate", 13)
    if (!found_remote) die("missing remote gate", 14)
    if (!found_release) die("missing release gate", 15)
  }
' "$DECISION_CSV"

for file in \
  COMPLETION_AUDIT.md \
  PR_BODY.md \
  completion_requirements.csv \
  sha256_manifest.csv
do
  if [[ ! -s "$AUDIT_DIR/$file" ]]; then
    echo "missing completion audit artifact: $file" >&2
    exit 20
  fi
done

python3 - "$AUDIT_DIR" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

audit_dir = Path(sys.argv[1])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with (audit_dir / "completion_requirements.csv").open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) < 25:
    raise SystemExit("completion audit should cover the public checklist")
if any(row["status"] != "pass" for row in rows):
    raise SystemExit("completion audit has non-pass requirement rows")

required = {
    "v51-local-scaling-command",
    "v52-eight-baseline-war",
    "v53-audit-command",
    "v54-mainline-artifacts",
    "v55-showcase-bundle",
    "claim-release-blocked",
    "readme-quickstart",
}
seen = {row["requirement"] for row in rows}
missing = required - seen
if missing:
    raise SystemExit(f"completion audit missing requirements: {sorted(missing)}")

sha_rows = {}
with (audit_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        sha_rows[row["path"]] = row["sha256"]
for rel in ["COMPLETION_AUDIT.md", "PR_BODY.md", "completion_requirements.csv"]:
    if sha_rows.get(rel) != sha256(audit_dir / rel):
        raise SystemExit(f"sha256 manifest mismatch: {rel}")

pr_body = (audit_dir / "PR_BODY.md").read_text(encoding="utf-8")
for snippet in ["v0.3 Architecture Preview", "test_v0_3_architecture_preview.sh", "real_release_package_ready=0", "gpu_speedup_claim=deferred"]:
    if snippet not in pr_body:
        raise SystemExit(f"PR body missing {snippet}")
PY

echo "v0.3 completion audit smoke passed"
