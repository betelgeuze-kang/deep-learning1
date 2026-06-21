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
  local variant="$4"
  mkdir -p "$repo"
  cat >"$repo/README.md" <<EOF
# $title

This repository is a local audit target. It is not production ready without evidence.
EOF
  case "$variant" in
    python)
      cat >"$repo/pyproject.toml" <<EOF
[project]
name = "$package"
requires-python = ">=3.10"
EOF
      cat >"$repo/module.py" <<'EOF'
def answer():
    return "ok"
EOF
      ;;
    javascript)
      cat >"$repo/package.json" <<EOF
{"name":"$package","version":"0.0.0","type":"module"}
EOF
      mkdir -p "$repo/src"
      cat >"$repo/src/index.js" <<'EOF'
export function answer() {
  return "ok";
}
EOF
      ;;
    cpp)
      cat >"$repo/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(${package//-/_} LANGUAGES CXX)
add_executable(${package//-/_} src/main.cpp)
EOF
      mkdir -p "$repo/src"
      cat >"$repo/src/main.cpp" <<'EOF'
#include <iostream>

int main() {
  std::cout << "ok\n";
  return 0;
}
EOF
      ;;
    *)
      echo "unknown test repo variant: $variant" >&2
      exit 2
      ;;
  esac
  git -C "$repo" init -q
  git -C "$repo" add .
  git -C "$repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
}

make_repo "$TMP_DIR/repo_1" "Audit Target Python" "audit-target-python" python
make_repo "$TMP_DIR/repo_2" "Audit Target JavaScript" "audit-target-js" javascript
make_repo "$TMP_DIR/repo_3" "Audit Target Cpp" "audit-target-cpp" cpp

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
    --generator routehint-tiny >/dev/null

  test "$(cat "$out/sentinel.txt")" = "keep"
  for file in \
    AUDIT_REPORT.md \
    ARCHITECTURE_TRACE.md \
    accuracy_rows.csv \
    artifact_contract_rows.csv \
    audit_findings.jsonl \
    audit_manifest.json \
    audit_summary.json \
    citation_spans.jsonl \
    citation_correctness_rows.csv \
    prediction_lineage.jsonl \
    plugin_registry.json \
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
  "$ROOT_DIR/tools/verify_artifact.py" local-audit "$out" >/dev/null

  cp "$out/sha256sums.txt" "$out/sha256sums.first"
  "$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_$idx" \
    --mode quick \
    --max-queries 12 \
    --out "$out" \
    --namespace synthetic \
    --question "Does this repo prove production readiness?" \
    --generator routehint-tiny >/dev/null
  cmp "$out/sha256sums.first" "$out/sha256sums.txt" >/dev/null
  "$out/reproduce.sh" >/dev/null
  cmp "$out/sha256sums.first" "$out/sha256sums.txt" >/dev/null
  "$ROOT_DIR/tools/verify_artifact.py" local-audit "$out" >/dev/null
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


def read_contract(out):
    with (out / "artifact_contract_rows.csv").open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise SystemExit("artifact contract rows must be non-empty")
    for row in rows:
        if row["schema_version"] != "local_repo_audit_artifacts.v1":
            raise SystemExit("artifact contract schema version mismatch")
        artifact = out / row["artifact_path"]
        if not artifact.is_file():
            raise SystemExit(f"contract artifact missing: {row['artifact_path']}")
        if row["artifact_kind"] == "csv":
            with artifact.open(newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                actual_columns = list(reader.fieldnames or [])
                actual_rows = list(reader)
            expected_columns = row["required_columns"].split("|") if row["required_columns"] else []
            if actual_columns != expected_columns or row["actual_columns"].split("|") != expected_columns:
                raise SystemExit(f"csv contract columns mismatch: {row['artifact_path']}")
            if int(row["actual_rows"]) != len(actual_rows):
                raise SystemExit(f"csv contract row count mismatch: {row['artifact_path']}")
        elif row["artifact_kind"] == "jsonl":
            actual_rows = [json.loads(line) for line in artifact.read_text(encoding="utf-8").splitlines() if line.strip()]
            actual_keys = sorted({key for payload in actual_rows for key in payload})
            required_keys = sorted(row["required_keys"].split("|")) if row["required_keys"] else []
            if not set(required_keys).issubset(actual_keys):
                raise SystemExit(f"jsonl contract keys mismatch: {row['artifact_path']}")
            if int(row["actual_rows"]) != len(actual_rows):
                raise SystemExit(f"jsonl contract row count mismatch: {row['artifact_path']}")
        elif row["artifact_kind"] == "json":
            payload = json.loads(artifact.read_text(encoding="utf-8"))
            required_keys = row["required_keys"].split("|") if row["required_keys"] else []
            if not set(required_keys).issubset(payload):
                raise SystemExit(f"json contract keys mismatch: {row['artifact_path']}")
        if row["sha256_manifest_required"] != "1" or row["deterministic_required"] != "1":
            raise SystemExit("artifact contract must require sha manifest and deterministic output")
    required_artifacts = {
        "audit_findings.csv",
        "audit_findings.jsonl",
        "citation_spans.csv",
        "citation_spans.jsonl",
        "prediction_lineage.jsonl",
        "plugin_registry.json",
        "audit_manifest.json",
        "audit_summary.json",
        "AUDIT_REPORT.md",
        "reproduce.sh",
    }
    seen = {row["artifact_path"] for row in rows}
    if not required_artifacts.issubset(seen):
        raise SystemExit(f"artifact contract missing required artifacts: {sorted(required_artifacts - seen)}")
    return rows


expected_sources = {
    1: "module.py",
    2: "src/index.js",
    3: "src/main.cpp",
}
source_sets = []

for idx in range(1, 4):
    out = root / f"out_{idx}"
    repo = root / f"repo_{idx}"
    manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
    if manifest["namespace"] != "synthetic":
        raise SystemExit("generated fixture repos must stay in the synthetic namespace")
    if manifest["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("audit manifest must expose the tool version")
    if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
        raise SystemExit("audit manifest timestamp must be deterministic")
    if manifest["atomic_publish"] != 1 or manifest["output_dir_destroyed"] != 0:
        raise SystemExit("audit manifest must prove atomic non-destructive publish")
    summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
    plugin_registry = json.loads((out / "plugin_registry.json").read_text(encoding="utf-8"))
    plugin_ids = {row["plugin_id"] for row in plugin_registry["plugins"]}
    if plugin_registry["schema_version"] != "local_repo_audit.v1":
        raise SystemExit("plugin registry schema version mismatch")
    if plugin_registry["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("plugin registry tool version mismatch")
    if plugin_ids != {"doc_code_identity", "deprecated_api", "config_consistency", "unsupported_claim", "missing_evidence"}:
        raise SystemExit("plugin registry must bind the deterministic plugin set")
    plugin_registry_sha256 = "sha256:" + sha256(out / "plugin_registry.json")
    if manifest["plugin_registry_sha256"] != plugin_registry_sha256:
        raise SystemExit("audit manifest must bind plugin_registry.json sha256")
    if summary["real_release_package_ready"] != 0 or summary["public_comparison_claim_ready"] != 0:
        raise SystemExit("audit product smoke must keep release/comparison claims blocked")
    if summary["latency_ms"] != 0:
        raise SystemExit("summary latency must stay deterministic; latency rows carry measurement slots")
    if summary["question_supplied"] != 1:
        raise SystemExit("audit product smoke should record user question support")
    if summary["accuracy_rows"] <= 0 or summary["citation_correctness_rows"] <= 0:
        raise SystemExit("accuracy and citation correctness rows must be recorded separately")
    findings = [json.loads(line) for line in (out / "audit_findings.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    citations = [json.loads(line) for line in (out / "citation_spans.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    lineage = [json.loads(line) for line in (out / "prediction_lineage.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    if not findings or not citations or not lineage:
        raise SystemExit("findings, citations, and lineage must be non-empty")
    if not any(row["audit_type"] == "user_question" and row["abstain"] == 1 for row in findings):
        raise SystemExit("unsupported user question must abstain")
    if any(row["grounded"] == 1 and not row["citations"] for row in findings):
        raise SystemExit("grounded findings must have citations")
    if any(int(row["line_start"]) <= 0 or not row["sha256"].startswith("sha256:") for row in citations):
        raise SystemExit("citation rows must bind line numbers and sha256")
    for row in citations:
        cited = repo / row["file_path"]
        if not cited.is_file():
            raise SystemExit(f"citation target missing: {row['file_path']}")
        if row["sha256"] != "sha256:" + sha256(cited):
            raise SystemExit(f"citation sha does not match file content: {row['file_path']}")
    with (out / "wrong_answer_guard_rows.csv").open(newline="", encoding="utf-8") as handle:
        guards = list(csv.DictReader(handle))
    if not guards or any(row["wrong_answer_guard_pass"] != "1" for row in guards):
        raise SystemExit("wrong-answer guard rows must pass")
    with (out / "accuracy_rows.csv").open(newline="", encoding="utf-8") as handle:
        accuracy_rows = list(csv.DictReader(handle))
    if not accuracy_rows or any(row["automatic_accuracy_claimed"] != "0" for row in accuracy_rows):
        raise SystemExit("automatic accuracy must not be claimed by the alpha smoke")
    with (out / "citation_correctness_rows.csv").open(newline="", encoding="utf-8") as handle:
        citation_rows = list(csv.DictReader(handle))
    if not citation_rows or any(row["manual_citation_review_required"] != "1" for row in citation_rows):
        raise SystemExit("citation correctness rows must require manual review")
    with (out / "source_manifest.csv").open(newline="", encoding="utf-8") as handle:
        source_rows = list(csv.DictReader(handle))
    source_files = {row["file_path"] for row in source_rows}
    source_sets.append(tuple(sorted(source_files)))
    if expected_sources[idx] not in source_files:
        raise SystemExit(f"repo_{idx} source manifest missing expected source: {expected_sources[idx]}")
    expected_cache_key = hashlib.sha256(json.dumps({
        "tool_version": "audit_my_repo_alpha.v1",
        "target": str((root / f"repo_{idx}").resolve()),
        "source": [(row["file_path"], row["sha256"]) for row in source_rows],
        "mode": "quick",
        "max_queries": 12,
        "namespace": "synthetic",
        "question": "Does this repo prove production readiness?",
        "plugin_registry_sha256": plugin_registry_sha256,
    }, sort_keys=True).encode("utf-8")).hexdigest()
    if manifest["cache_key"] != expected_cache_key:
        raise SystemExit("audit manifest cache key does not match source/query/plugin inputs")
    contract_rows = read_contract(out)
    manifest_rows = {}
    for line in (out / "sha256sums.txt").read_text(encoding="utf-8").splitlines():
        digest, rel = line.split(None, 1)
        manifest_rows[rel] = digest
    for rel in [
        "AUDIT_REPORT.md",
        "ARCHITECTURE_TRACE.md",
        "accuracy_rows.csv",
        "artifact_contract_rows.csv",
        "audit_manifest.json",
        "audit_summary.json",
        "audit_findings.jsonl",
        "citation_spans.jsonl",
        "citation_correctness_rows.csv",
        "prediction_lineage.jsonl",
        "plugin_registry.json",
        "reproduce.sh",
    ]:
        if manifest_rows.get(rel) != sha256(out / rel):
            raise SystemExit(f"sha256 mismatch: {rel}")
    for row in contract_rows:
        if row["sha256_manifest_required"] == "1" and row["artifact_path"] not in manifest_rows:
            raise SystemExit(f"contract artifact missing from sha256 manifest: {row['artifact_path']}")
    reproduce_text = (out / "reproduce.sh").read_text(encoding="utf-8")
    if "--question 'Does this repo prove production readiness?'" not in reproduce_text:
        raise SystemExit("reproduce.sh must preserve the user question")
if len(set(source_sets)) != 3:
    raise SystemExit("product smoke must exercise three distinct unseen local repository shapes")
PY

echo "audit_my_repo product entrypoint smoke passed"
