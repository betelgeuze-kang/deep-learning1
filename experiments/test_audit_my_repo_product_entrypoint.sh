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
      mkdir -p "$repo/docs"
      cat >"$repo/docs/evidence.md" <<'EOF'
# Evidence Notes

This local evidence note is a citation target, not release proof.
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
    abstain_rows.csv \
    accuracy_rows.csv \
    artifact_contract_rows.csv \
    audit_findings.csv \
    audit_findings.jsonl \
    audit_invocation.json \
    audit_manifest.json \
    audit_summary.csv \
    audit_summary.json \
    citation_spans.csv \
    citation_spans.jsonl \
    citation_correctness_rows.csv \
    claim_boundary.md \
    compact_route_hint_rows.csv \
    exit_code_contract.json \
    grounded_generation_rows.csv \
    mmap_read_trace.jsonl \
    prediction_lineage.jsonl \
    plugin_registry.json \
    plugin_rule_rows.csv \
    resource_envelope.json \
    reproduce.sh \
    sha256sums.txt \
    source_manifest.csv \
    source_snapshot.json \
    unsupported_claim_rows.csv \
    false_positive_candidate_rows.csv \
    latency_rows.csv \
    wrong_answer_guard_rows.csv
  do
    if [[ ! -s "$out/$file" ]]; then
      echo "missing audit product artifact for repo_$idx: $file" >&2
      exit 10
    fi
  done
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_output.schema.json" "$out/audit_manifest.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_exit_code_contract.schema.json" "$out/exit_code_contract.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_invocation.schema.json" "$out/audit_invocation.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_summary.schema.json" "$out/audit_summary.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_registry.schema.json" "$out/plugin_registry.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_source_snapshot.schema.json" "$out/source_snapshot.json" >/dev/null
  "$ROOT_DIR/tools/verify_local_audit.py" "$out" >/dev/null

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
  "$ROOT_DIR/tools/verify_local_audit.py" "$out" >/dev/null
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
        "plugin_rule_rows.csv",
        "source_snapshot.json",
        "audit_invocation.json",
        "exit_code_contract.json",
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
    invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
    exit_contract = json.loads((out / "exit_code_contract.json").read_text(encoding="utf-8"))
    if manifest["namespace"] != "synthetic":
        raise SystemExit("generated fixture repos must stay in the synthetic namespace")
    if manifest["real_benchmark_namespace_confirmed"] != 0:
        raise SystemExit("synthetic product smoke must not confirm the real_benchmark namespace")
    if manifest["fixture_result_promoted"] != 0 or manifest["real_evidence_claimed"] != 0:
        raise SystemExit("synthetic product smoke must not promote fixture results or claim real evidence")
    if manifest["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("audit manifest must expose the tool version")
    if invocation["tool_version"] != manifest["tool_version"]:
        raise SystemExit("audit invocation must expose the tool version")
    if invocation["target_repo"] != str(repo.resolve()) or invocation["out_dir"] != str(out.resolve()):
        raise SystemExit("audit invocation must bind target repo and output directory")
    if invocation["mode"] != "quick" or invocation["max_queries"] != 12 or invocation["generator"] != "routehint-tiny":
        raise SystemExit("audit invocation must bind resolved execution options")
    if invocation["namespace"] != "synthetic" or invocation["real_benchmark_namespace_confirmed"] != 0:
        raise SystemExit("audit invocation must bind namespace confirmation")
    if invocation["verify_output_requested"] != 1:
        raise SystemExit("audit invocation must record default verify-output")
    if exit_contract["success_exit_code"] != 0 or exit_contract["artifact_verify_failure_exit_code"] != 1:
        raise SystemExit("exit code contract must bind success and verify failure codes")
    if exit_contract["input_or_publish_error_exit_code"] != 2:
        raise SystemExit("exit code contract must bind input/publish error code")
    if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
        raise SystemExit("audit manifest timestamp must be deterministic")
    if manifest["atomic_publish"] != 1 or manifest["output_dir_destroyed"] != 0:
        raise SystemExit("audit manifest must prove atomic non-destructive publish")
    if manifest["output_dir_overwritten"] != 0:
        raise SystemExit("audit manifest must prove output artifacts were not overwritten")
    if manifest["publish_mode"] != "create-or-idempotent-cache-hit":
        raise SystemExit("audit manifest publish mode must be no-overwrite/idempotent")
    summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
    with (out / "audit_summary.csv").open(newline="", encoding="utf-8") as handle:
        summary_rows = list(csv.DictReader(handle))
    if len(summary_rows) != 1:
        raise SystemExit("audit summary CSV must contain exactly one row")
    if set(summary_rows[0]) != set(summary):
        raise SystemExit("audit summary CSV columns must match audit_summary.json keys")
    for key, value in summary.items():
        if summary_rows[0][key] != str(value):
            raise SystemExit(f"audit summary CSV/JSON mismatch: {key}")
    resource = json.loads((out / "resource_envelope.json").read_text(encoding="utf-8"))
    expected_resource = {
        "tool_version": manifest["tool_version"],
        "source_files_scanned": manifest["source_file_count"],
        "mode": summary["mode"],
        "namespace": manifest["namespace"],
        "external_network_used": 0,
        "raw_prompt_context_bytes": summary["raw_prompt_context_bytes"],
        "latency_ms": summary["latency_ms"],
        "wrong_answer_guard_rows": summary["wrong_answer_guard_rows"],
        "claim_boundary_ready": summary["claim_boundary_ready"],
    }
    for key, value in expected_resource.items():
        if resource[key] != value:
            raise SystemExit(f"resource envelope mismatch: {key}")
    plugin_registry = json.loads((out / "plugin_registry.json").read_text(encoding="utf-8"))
    plugin_ids = {row["plugin_id"] for row in plugin_registry["plugins"]}
    if plugin_registry["schema_version"] != "local_repo_audit.v1":
        raise SystemExit("plugin registry schema version mismatch")
    if plugin_registry["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("plugin registry tool version mismatch")
    if plugin_ids != {"doc_code_identity", "deprecated_api", "config_consistency", "unsupported_claim", "missing_evidence", "user_question"}:
        raise SystemExit("plugin registry must bind the deterministic plugin set")
    expected_plugin_modules = {
        "doc_code_identity": "auditor_plugin_doc_code_identity",
        "deprecated_api": "auditor_plugin_deprecated_api",
        "config_consistency": "auditor_plugin_config_consistency",
        "unsupported_claim": "auditor_plugin_unsupported_claim",
        "missing_evidence": "auditor_plugin_missing_evidence",
        "user_question": "auditor_plugin_user_question",
    }
    if {row["plugin_id"]: row.get("module") for row in plugin_registry["plugins"]} != expected_plugin_modules:
        raise SystemExit("plugin registry must bind each deterministic plugin to its module")
    plugin_registry_sha256 = "sha256:" + sha256(out / "plugin_registry.json")
    if manifest["plugin_registry_sha256"] != plugin_registry_sha256:
        raise SystemExit("audit manifest must bind plugin_registry.json sha256")
    with (out / "plugin_rule_rows.csv").open(newline="", encoding="utf-8") as handle:
        plugin_rule_rows = list(csv.DictReader(handle))
    if not plugin_rule_rows:
        raise SystemExit("plugin rule rows must be emitted")
    rule_plugin_ids = {row["plugin_id"] for row in plugin_rule_rows}
    if rule_plugin_ids != plugin_ids:
        raise SystemExit("plugin rule rows must cover every registered plugin")
    deprecated_rule_languages = {
        row["language"]
        for row in plugin_rule_rows
        if row["plugin_id"] == "deprecated_api"
    }
    if not {"python", "cpp", "javascript"}.issubset(deprecated_rule_languages):
        raise SystemExit("deprecated_api rules must expose python/cpp/javascript coverage")
    if any(row["evidence_policy"] not in {"source-bound-span", "abstain-when-missing-source-bound-span"} for row in plugin_rule_rows):
        raise SystemExit("plugin rule rows must bind a replayable evidence policy")
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
    for csv_name, jsonl_rows in [
        ("audit_findings.csv", findings),
        ("citation_spans.csv", citations),
    ]:
        with (out / csv_name).open(newline="", encoding="utf-8") as handle:
            csv_rows = list(csv.DictReader(handle))
        if len(csv_rows) != len(jsonl_rows):
            raise SystemExit(f"{csv_name} row count must match jsonl")
        for csv_row, jsonl_row in zip(csv_rows, jsonl_rows):
            if set(csv_row) != set(jsonl_row):
                raise SystemExit(f"{csv_name} columns must match jsonl keys")
            for key, value in jsonl_row.items():
                if csv_row[key] != str(value):
                    raise SystemExit(f"{csv_name} drift: {key}")
    with (out / "source_manifest.csv").open(newline="", encoding="utf-8") as handle:
        source_rows = list(csv.DictReader(handle))
    source_snapshot = json.loads((out / "source_snapshot.json").read_text(encoding="utf-8"))
    source_files = {row["file_path"] for row in source_rows}
    if not findings or not citations or not lineage:
        raise SystemExit("findings, citations, and lineage must be non-empty")
    if not any(row["audit_type"] == "user_question" and row["abstain"] == 1 and row["grounded"] == 0 and row["citations"] for row in findings):
        raise SystemExit("unsupported user question must abstain without a grounded answer while keeping source context")
    if any(row["grounded"] == 1 and not row["citations"] for row in findings):
        raise SystemExit("grounded findings must have citations")
    if any(int(row["line_start"]) <= 0 or not row["sha256"].startswith("sha256:") for row in citations):
        raise SystemExit("citation rows must bind line numbers and sha256")
    citation_by_finding_cell = {
        (row["finding_id"], f"{row['file_path']}:{row['line_start']}"): row
        for row in citations
    }
    for row in findings:
        finding_cells = [cell for cell in str(row.get("citations", "")).split(";") if cell]
        finding_sha256s = [cell for cell in str(row.get("citation_sha256s", "")).split(";") if cell]
        if len(finding_cells) != len(finding_sha256s):
            raise SystemExit(f"finding citation sha count drift: {row['finding_id']}")
        for cell, digest in zip(finding_cells, finding_sha256s):
            citation = citation_by_finding_cell.get((row["finding_id"], cell))
            if citation is None:
                raise SystemExit(f"finding citation has no span row: {row['finding_id']} {cell}")
            if digest != citation["sha256"]:
                raise SystemExit(f"finding citation sha drift: {row['finding_id']} {cell}")
    for row in citations:
        cited = repo / row["file_path"]
        if row["file_path"] not in source_files:
            raise SystemExit(f"citation is not listed in source manifest: {row['file_path']}")
        if not cited.is_file():
            raise SystemExit(f"citation target missing: {row['file_path']}")
        if row["sha256"] != "sha256:" + sha256(cited):
            raise SystemExit(f"citation sha does not match file content: {row['file_path']}")
        source_lines = cited.read_text(encoding="utf-8", errors="replace").splitlines()
        line_start = int(row["line_start"])
        if line_start > len(source_lines):
            raise SystemExit(f"citation line is out of range: {row['file_path']}:{line_start}")
        if row["span_text_preview"] != source_lines[line_start - 1].strip()[:280]:
            raise SystemExit(f"citation preview does not match source line: {row['file_path']}:{line_start}")
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
    source_sets.append(tuple(sorted(source_files)))
    if expected_sources[idx] not in source_files:
        raise SystemExit(f"repo_{idx} source manifest missing expected source: {expected_sources[idx]}")
    if len(source_files) != len(source_rows):
        raise SystemExit("source manifest file paths must be unique")
    for row in source_rows:
        source_path = repo / row["file_path"]
        if not source_path.is_file():
            raise SystemExit(f"source manifest target missing: {row['file_path']}")
        if row["sha256"] != "sha256:" + sha256(source_path):
            raise SystemExit(f"source manifest sha mismatch: {row['file_path']}")
        if int(row["bytes"]) != source_path.stat().st_size:
            raise SystemExit(f"source manifest byte count mismatch: {row['file_path']}")
        if row["route_memory_source"] != "1":
            raise SystemExit(f"source manifest route_memory_source mismatch: {row['file_path']}")
    if source_snapshot["schema_version"] != "local_repo_audit_source_snapshot.v1":
        raise SystemExit("source snapshot schema_version mismatch")
    if source_snapshot["tool_version"] != manifest["tool_version"]:
        raise SystemExit("source snapshot tool_version mismatch")
    if source_snapshot["target_repo"] != str(repo.resolve()):
        raise SystemExit("source snapshot target repo mismatch")
    if source_snapshot["source_manifest_sha256"] != "sha256:" + sha256(out / "source_manifest.csv"):
        raise SystemExit("source snapshot must bind source_manifest.csv sha256")
    if source_snapshot["source_file_count"] != len(source_rows):
        raise SystemExit("source snapshot source_file_count mismatch")
    if source_snapshot["git_available"] != 1:
        raise SystemExit("source snapshot must record git availability for product smoke repos")
    if source_snapshot["git_dirty"] != 0:
        raise SystemExit("source snapshot must record clean product smoke repos")
    if len(source_snapshot["git_head"]) != 40:
        raise SystemExit("source snapshot must record the git HEAD sha")
    expected_cache_key = hashlib.sha256(json.dumps({
        "tool_version": "audit_my_repo_alpha.v1",
        "target": str((root / f"repo_{idx}").resolve()),
        "source": [(row["file_path"], row["sha256"]) for row in source_rows],
        "source_snapshot": source_snapshot,
        "mode": "quick",
        "max_queries": 12,
        "namespace": "synthetic",
        "real_benchmark_namespace_confirmed": 0,
        "question": "Does this repo prove production readiness?",
        "verify_output_requested": 1,
        "emit_report_requested": 1,
        "emit_lineage_requested": 1,
        "emit_reproduce_requested": 1,
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
        "audit_invocation.json",
        "audit_manifest.json",
        "audit_summary.json",
        "audit_findings.jsonl",
        "citation_spans.jsonl",
        "citation_correctness_rows.csv",
        "exit_code_contract.json",
        "prediction_lineage.jsonl",
        "plugin_registry.json",
        "plugin_rule_rows.csv",
        "source_snapshot.json",
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
