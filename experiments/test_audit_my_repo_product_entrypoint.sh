#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audit-my-repo-product.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_repo() {
  local repo="$1"
  local title="$2"
  local package="$3"
  mkdir -p "$repo"
  cat >"$repo/README.md" <<EOF
# $title

This repository is a local audit target. It is not production ready without evidence.
EOF
  cat >"$repo/pyproject.toml" <<EOF
[project]
name = "$package"
requires-python = ">=3.10"
EOF
  cat >"$repo/module.py" <<'EOF'
def answer():
    return "ok"
EOF
  git -C "$repo" init -q
  git -C "$repo" add README.md pyproject.toml module.py
  git -C "$repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
}

for idx in 1 2 3; do
  make_repo "$TMP_DIR/repo_$idx" "Audit Target $idx" "audit-target-$idx"
done

for idx in 1 2 3; do
  out="$TMP_DIR/out_$idx"
  mkdir -p "$out"
  printf 'keep' >"$out/sentinel.txt"
  "$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_$idx" \
    --mode quick \
    --max-queries 12 \
    --out "$out" \
    --namespace synthetic \
    --question "Does this repo prove production readiness?" \
    --generator routehint-tiny \
    --emit-report \
    --emit-lineage \
    --emit-reproduce >/dev/null

  test "$(cat "$out/sentinel.txt")" = "keep"
  for file in \
    AUDIT_REPORT.md \
    audit_findings.jsonl \
    audit_manifest.json \
    audit_summary.json \
    citation_spans.jsonl \
    prediction_lineage.jsonl \
    resource_envelope.json \
    reproduce.sh \
    sha256sums.txt \
    source_manifest.csv \
    false_positive_candidate_rows.csv \
    latency_rows.csv
  do
    if [[ ! -s "$out/$file" ]]; then
      echo "missing audit product artifact for repo_$idx: $file" >&2
      exit 10
    fi
  done
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_output.schema.json" "$out/audit_manifest.json" >/dev/null
done

python3 - "$TMP_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


for idx in range(1, 4):
    out = root / f"out_{idx}"
    manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
    if manifest["namespace"] != "synthetic":
        raise SystemExit("generated fixture repos must stay in the synthetic namespace")
    if manifest["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("audit manifest must expose the tool version")
    if manifest["atomic_publish"] != 1 or manifest["output_dir_destroyed"] != 0:
        raise SystemExit("audit manifest must prove atomic non-destructive publish")
    summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
    if summary["real_release_package_ready"] != 0 or summary["public_comparison_claim_ready"] != 0:
        raise SystemExit("audit product smoke must keep release/comparison claims blocked")
    if summary["question_supplied"] != 1:
        raise SystemExit("audit product smoke should record user question support")
    findings = [json.loads(line) for line in (out / "audit_findings.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    citations = [json.loads(line) for line in (out / "citation_spans.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    lineage = [json.loads(line) for line in (out / "prediction_lineage.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    if not findings or not citations or not lineage:
        raise SystemExit("findings, citations, and lineage must be non-empty")
    if not any(row["audit_type"] == "user_question" and row["abstain"] == 1 for row in findings):
        raise SystemExit("unsupported user question must abstain")
    if any(row["grounded"] == 1 and not row["citations"] for row in findings):
        raise SystemExit("grounded findings must have citations")
    with (out / "wrong_answer_guard_rows.csv").open(newline="", encoding="utf-8") as handle:
        guards = list(csv.DictReader(handle))
    if not guards or any(row["wrong_answer_guard_pass"] != "1" for row in guards):
        raise SystemExit("wrong-answer guard rows must pass")
    manifest_rows = {}
    for line in (out / "sha256sums.txt").read_text(encoding="utf-8").splitlines():
        digest, rel = line.split(None, 1)
        manifest_rows[rel] = digest
    for rel in ["audit_manifest.json", "audit_summary.json", "audit_findings.jsonl", "citation_spans.jsonl"]:
        if manifest_rows.get(rel) != sha256(out / rel):
            raise SystemExit(f"sha256 mismatch: {rel}")
PY

echo "audit_my_repo product entrypoint smoke passed"
