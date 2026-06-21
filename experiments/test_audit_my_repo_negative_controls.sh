#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audit-my-repo-negative.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

repo="$TMP_DIR/repo"
out_a="$TMP_DIR/out_a"
out_b="$TMP_DIR/out_b"
mkdir -p "$repo" "$out_a" "$out_b"
printf 'keep' >"$out_a/sentinel.txt"

cat >"$repo/README.md" <<'EOF'
# Fixture Product

This repository is production ready and guaranteed to be state of the art.
EOF
cat >"$repo/pyproject.toml" <<'EOF'
[project]
name = "different-package-name"
requires-python = ">=3.10"
EOF
cat >"$repo/legacy.py" <<'EOF'
import distutils

def answer():
    return "ship it"
EOF
cat >"$repo/legacy.cpp" <<'EOF'
#include <memory>
std::auto_ptr<int> legacy_ptr();
EOF
cat >"$repo/legacy.js" <<'EOF'
var answer = eval("1 + 1");
document.write(answer);
EOF
cat >"$TMP_DIR/outside_link_target.md" <<'EOF'
# Outside Link Target

This file is outside the audited repository and must never enter source_manifest.csv.
EOF
ln -s "$TMP_DIR/outside_link_target.md" "$repo/OUTSIDE_LINK.md"

git -C "$repo" init -q
git -C "$repo" add README.md pyproject.toml legacy.py legacy.cpp legacy.js OUTSIDE_LINK.md
git -C "$repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init

if [[ "$("$ROOT_DIR/scripts/audit_my_repo.sh" --version)" != "audit_my_repo_alpha.v1" ]]; then
  echo "audit entrypoint must expose a stable tool version" >&2
  exit 8
fi
"$ROOT_DIR/scripts/audit_my_repo.sh" --list-plugins >"$TMP_DIR/plugins.json"
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_registry.schema.json" "$TMP_DIR/plugins.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo.sh" --list-plugin-rules >"$TMP_DIR/plugin_rules.json"
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_rules.schema.json" "$TMP_DIR/plugin_rules.json" >/dev/null
python3 - "$TMP_DIR/plugins.json" "$ROOT_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
root = Path(sys.argv[2]).resolve()


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


if payload["schema_version"] != "local_repo_audit.v1":
    raise SystemExit("plugin registry schema version mismatch")
if payload["tool_version"] != "audit_my_repo_alpha.v1":
    raise SystemExit("plugin registry tool version mismatch")
plugins = {row["plugin_id"]: row for row in payload["plugins"]}
expected = {
    "doc_code_identity": "auditor_plugin_doc_code_identity",
    "deprecated_api": "auditor_plugin_deprecated_api",
    "config_consistency": "auditor_plugin_config_consistency",
    "unsupported_claim": "auditor_plugin_unsupported_claim",
    "missing_evidence": "auditor_plugin_missing_evidence",
    "user_question": "auditor_plugin_user_question",
}
if set(plugins) != set(expected):
    raise SystemExit(f"plugin registry mismatch: {sorted(plugins)}")
for plugin_id, module in expected.items():
    if plugins[plugin_id].get("module") != module:
        raise SystemExit(f"plugin registry module mismatch for {plugin_id}")
    expected_source_path = f"scripts/{module}.py"
    if plugins[plugin_id].get("source_path") != expected_source_path:
        raise SystemExit(f"plugin registry source path mismatch for {plugin_id}")
    if plugins[plugin_id].get("source_sha256") != "sha256:" + sha256(root / expected_source_path):
        raise SystemExit(f"plugin registry source sha mismatch for {plugin_id}")
if plugins["deprecated_api"]["language"] != "multi":
    raise SystemExit("deprecated_api plugin must advertise multi-language coverage")
PY
python3 - "$TMP_DIR/plugin_rules.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload["schema_version"] != "local_repo_audit_plugin_rules.v1":
    raise SystemExit("plugin rules schema version mismatch")
if payload["tool_version"] != "audit_my_repo_alpha.v1":
    raise SystemExit("plugin rules tool version mismatch")
rules = payload["rules"]
plugin_ids = {row["plugin_id"] for row in rules}
expected_plugin_ids = {
    "doc_code_identity",
    "deprecated_api",
    "config_consistency",
    "unsupported_claim",
    "missing_evidence",
    "user_question",
}
if plugin_ids != expected_plugin_ids:
    raise SystemExit(f"plugin rules must cover every plugin: {sorted(plugin_ids)}")
rule_ids = [row["rule_id"] for row in rules]
if len(rule_ids) != len(set(rule_ids)):
    raise SystemExit("plugin rules must have unique rule_id values")
deprecated_languages = {row["language"] for row in rules if row["plugin_id"] == "deprecated_api"}
if not {"python", "cpp", "javascript"}.issubset(deprecated_languages):
    raise SystemExit("deprecated_api listed rules must expose python/cpp/javascript coverage")
if any(row["evidence_policy"] not in {"source-bound-span", "abstain-when-missing-source-bound-span"} for row in rules):
    raise SystemExit("plugin rules must expose supported evidence policies")
PY
expect_audit_exit() {
  local expected="$1"
  local label="$2"
  shift 2
  set +e
  "$ROOT_DIR/scripts/audit_my_repo.sh" "$@" >/dev/null 2>&1
  local rc="$?"
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    echo "$label expected exit $expected, got $rc" >&2
    exit 9
  fi
}

expect_audit_exit 2 "target repo must be required for audit execution" --out "$TMP_DIR/no_target"
expect_audit_exit 1 "verify-existing must reject missing output directories" --verify-existing "$TMP_DIR/missing_audit_output"
expect_audit_exit 2 "unsupported generator must fail with stable usage exit code" "$repo" --generator unsupported --out "$TMP_DIR/bad_generator"
expect_audit_exit 2 "non-positive max queries must fail with stable usage exit code" "$repo" --max-queries 0 --out "$TMP_DIR/bad_queries"
expect_audit_exit 2 "missing target repo must fail with stable usage exit code" "$TMP_DIR/missing" --out "$TMP_DIR/bad_target"
question_file="$TMP_DIR/question.txt"
printf 'Does this file-input question prove release readiness?\n' >"$question_file"
expect_audit_exit 2 "missing question file must fail with stable usage exit code" "$repo" --question-file "$TMP_DIR/missing_question.txt" --out "$TMP_DIR/bad_question_missing"
expect_audit_exit 2 "question and question-file must be mutually exclusive" "$repo" --question "Inline?" --question-file "$question_file" --out "$TMP_DIR/bad_question_both"
printf '\n' >"$TMP_DIR/empty_question.txt"
expect_audit_exit 2 "empty question file must fail with stable usage exit code" "$repo" --question-file "$TMP_DIR/empty_question.txt" --out "$TMP_DIR/bad_question_empty"
printf 'One?\nTwo?\n' >"$TMP_DIR/multi_question.txt"
expect_audit_exit 2 "multi-question file must fail with stable usage exit code" "$repo" --question-file "$TMP_DIR/multi_question.txt" --out "$TMP_DIR/bad_question_multi"
for bad_question_out in bad_question_missing bad_question_both bad_question_empty bad_question_multi; do
  if [[ -e "$TMP_DIR/$bad_question_out/audit_manifest.json" ]] || compgen -G "$TMP_DIR/.$bad_question_out.staging-*" >/dev/null; then
    echo "invalid question-file inputs must not publish audit artifacts: $bad_question_out" >&2
    exit 9
  fi
done
no_source_repo="$TMP_DIR/no_source_repo"
mkdir -p "$no_source_repo"
printf 'binary-ish payload\n' >"$no_source_repo/blob.bin"
git -C "$no_source_repo" init -q
git -C "$no_source_repo" add blob.bin
git -C "$no_source_repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
expect_audit_exit 2 "repo without auditable source files must fail with stable usage exit code" "$no_source_repo" --out "$TMP_DIR/no_source_out"
if [[ -e "$TMP_DIR/no_source_out/audit_manifest.json" ]] || compgen -G "$TMP_DIR/.no_source_out.staging-*" >/dev/null; then
  echo "repo without auditable source files must not publish audit artifacts" >&2
  exit 9
fi
expect_audit_exit 2 "output path inside audited repo must fail before publish" "$repo" --out "$repo/audit-output"
if [[ -e "$repo/audit-output" ]] || compgen -G "$repo/.audit-output.staging-*" >/dev/null; then
  echo "audit entrypoint must not create output or staging directories inside the audited repo" >&2
  exit 9
fi
expect_audit_exit 2 "real_benchmark namespace must require explicit confirmation" "$repo" --namespace real_benchmark --out "$TMP_DIR/bad_real_namespace"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$TMP_DIR/real_namespace_confirmed" \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --question "Does confirmed real_benchmark namespace prove release readiness?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_output.schema.json" "$TMP_DIR/real_namespace_confirmed/audit_manifest.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_summary.schema.json" "$TMP_DIR/real_namespace_confirmed/audit_summary.json" >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$TMP_DIR/real_namespace_confirmed" >/dev/null
python3 - "$TMP_DIR/real_namespace_confirmed" <<'PY'
import json
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
manifest = json.loads((out_dir / "audit_manifest.json").read_text(encoding="utf-8"))
summary = json.loads((out_dir / "audit_summary.json").read_text(encoding="utf-8"))
reproduce = (out_dir / "reproduce.sh").read_text(encoding="utf-8")
if manifest["namespace"] != "real_benchmark":
    raise SystemExit("confirmed namespace smoke must write real_benchmark namespace")
if manifest["real_benchmark_namespace_confirmed"] != 1:
    raise SystemExit("confirmed namespace smoke must record explicit confirmation")
if manifest["fixture_result_promoted"] != 0 or manifest["real_evidence_claimed"] != 0:
    raise SystemExit("confirmed namespace must not promote fixture output or claim real evidence")
if summary["real_release_package_ready"] != 0 or summary["public_comparison_claim_ready"] != 0:
    raise SystemExit("confirmed namespace must keep release/comparison claims blocked")
if "--confirm-real-benchmark-namespace" not in reproduce:
    raise SystemExit("reproduce.sh must preserve real_benchmark confirmation")
PY
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$TMP_DIR/default_namespace" \
  --question "What namespace is used by default?" \
  --generator routehint-tiny >/dev/null
python3 - "$TMP_DIR/default_namespace/audit_manifest.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if manifest["namespace"] != "synthetic":
    raise SystemExit("default namespace must be synthetic, not real_benchmark")
PY
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$TMP_DIR/question_file_out" \
  --question-file "$question_file" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$TMP_DIR/question_file_out" >/dev/null
python3 - "$TMP_DIR/question_file_out" <<'PY'
import csv
import json
import shlex
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
summary = json.loads((out_dir / "audit_summary.json").read_text(encoding="utf-8"))
if summary["question_supplied"] != 1:
    raise SystemExit("question-file input must set question_supplied=1")
with (out_dir / "audit_findings.csv").open(newline="", encoding="utf-8") as handle:
    question_rows = [row for row in csv.DictReader(handle) if row["plugin_id"] == "user_question"]
if len(question_rows) != 1:
    raise SystemExit("question-file input must produce exactly one user_question row")
expected_question = "Does this file-input question prove release readiness?"
if question_rows[0]["question"] != expected_question:
    raise SystemExit("question-file input question text drift")
if question_rows[0]["abstain"] != "1" or question_rows[0]["grounded"] != "0":
    raise SystemExit("question-file input must abstain without grounding")
reproduce_parts = shlex.split((out_dir / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if "--question-file" in reproduce_parts:
    raise SystemExit("reproduce.sh must freeze question-file input as --question text")
if "--question" not in reproduce_parts:
    raise SystemExit("reproduce.sh must preserve question-file input as --question")
if reproduce_parts[reproduce_parts.index("--question") + 1] != expected_question:
    raise SystemExit("reproduce.sh question-file value drift")
PY
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$TMP_DIR/no_question" \
  --namespace synthetic \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$TMP_DIR/no_question" >/dev/null

audit_log="$TMP_DIR/audit.log"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$out_a" \
  --namespace fixture \
  --question "Can I ship this as production ready?" \
  --generator routehint-tiny >"$audit_log"
if ! grep -q '^artifact_verify: ok$' "$audit_log"; then
  echo "audit entrypoint must verify its output artifact by default" >&2
  exit 14
fi

test "$(cat "$out_a/sentinel.txt")" = "keep"

"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_output.schema.json" "$out_a/audit_manifest.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_exit_code_contract.schema.json" "$out_a/exit_code_contract.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_invocation.schema.json" "$out_a/audit_invocation.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_summary.schema.json" "$out_a/audit_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_registry.schema.json" "$out_a/plugin_registry.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_source_snapshot.schema.json" "$out_a/source_snapshot.json" >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$out_a" >/dev/null

python3 - "$ROOT_DIR" "$repo" "$out_a" "$out_b" <<'PY'
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()
out_a = Path(sys.argv[3])
out_b = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

manifest = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out_a / "audit_invocation.json").read_text(encoding="utf-8"))
exit_contract = json.loads((out_a / "exit_code_contract.json").read_text(encoding="utf-8"))
plugin_registry = json.loads((out_a / "plugin_registry.json").read_text(encoding="utf-8"))
if invocation["target_repo"] != str(repo) or invocation["out_dir"] != str(out_a):
    raise SystemExit("audit invocation must bind target repo and output directory")
if invocation["mode"] != "quick" or invocation["max_queries"] != 12 or invocation["generator"] != "routehint-tiny":
    raise SystemExit("audit invocation must bind resolved execution options")
if invocation["namespace"] != "fixture" or invocation["real_benchmark_namespace_confirmed"] != 0:
    raise SystemExit("audit invocation must bind fixture namespace")
if invocation["question_supplied"] != 1 or invocation["verify_output_requested"] != 1:
    raise SystemExit("audit invocation must bind question and verification settings")
if exit_contract["success_exit_code"] != 0 or exit_contract["artifact_verify_failure_exit_code"] != 1:
    raise SystemExit("exit code contract must bind stable success/failure codes")
if exit_contract["input_or_publish_error_exit_code"] != 2:
    raise SystemExit("exit code contract must bind stable user-correctable error code")
if plugin_registry["tool_version"] != manifest["tool_version"]:
    raise SystemExit("plugin registry must be bound to the manifest tool version")
expected_plugin_modules = {
    "doc_code_identity": "auditor_plugin_doc_code_identity",
    "deprecated_api": "auditor_plugin_deprecated_api",
    "config_consistency": "auditor_plugin_config_consistency",
    "unsupported_claim": "auditor_plugin_unsupported_claim",
    "missing_evidence": "auditor_plugin_missing_evidence",
    "user_question": "auditor_plugin_user_question",
}
plugin_modules = {row["plugin_id"]: row.get("module") for row in plugin_registry["plugins"]}
if plugin_modules != expected_plugin_modules:
    raise SystemExit("fixture audit output must bind the deterministic plugin registry")
expected_plugin_source_paths = {
    plugin_id: f"scripts/{module}.py"
    for plugin_id, module in expected_plugin_modules.items()
}
if {row["plugin_id"]: row.get("source_path") for row in plugin_registry["plugins"]} != expected_plugin_source_paths:
    raise SystemExit("fixture audit output must bind deterministic plugin source paths")
for row in plugin_registry["plugins"]:
    source_path = root / row["source_path"]
    if row.get("source_sha256") != "sha256:" + sha256(source_path):
        raise SystemExit("fixture audit output must bind plugin source sha: " + row["plugin_id"])
if manifest["plugin_registry_sha256"] != "sha256:" + sha256(out_a / "plugin_registry.json"):
    raise SystemExit("manifest must bind plugin registry sha256")
with (out_a / "plugin_rule_rows.csv").open(newline="", encoding="utf-8") as handle:
    plugin_rule_rows = list(csv.DictReader(handle))
rule_plugin_ids = {row["plugin_id"] for row in plugin_rule_rows}
if rule_plugin_ids != set(expected_plugin_modules):
    raise SystemExit("plugin rule rows must cover every registered plugin")
deprecated_rule_languages = {
    row["language"]
    for row in plugin_rule_rows
    if row["plugin_id"] == "deprecated_api"
}
if not {"python", "cpp", "javascript"}.issubset(deprecated_rule_languages):
    raise SystemExit("deprecated API plugin rules must expose python/cpp/javascript coverage")
if any(row["evidence_policy"] not in {"source-bound-span", "abstain-when-missing-source-bound-span"} for row in plugin_rule_rows):
    raise SystemExit("plugin rule rows must bind a replayable evidence policy")
if manifest["namespace"] != "fixture":
    raise SystemExit("negative-control fixture must not be promoted out of fixture namespace")
if manifest["real_benchmark_namespace_confirmed"] != 0:
    raise SystemExit("fixture namespace must not carry real_benchmark confirmation")
if manifest["fixture_result_promoted"] != 0 or manifest["real_evidence_claimed"] != 0:
    raise SystemExit("fixture output must not be promoted or claimed as real evidence")
if manifest["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("claim boundary must remain alpha-only")
if manifest["tool_source_sha256"] != "sha256:" + sha256(root / "scripts/audit_my_repo.py"):
    raise SystemExit("manifest must bind audit entrypoint source sha")
if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
    raise SystemExit("manifest timestamp must be deterministic")
if manifest["output_dir_overwritten"] != 0:
    raise SystemExit("manifest must prove output artifacts were not overwritten")
if manifest["publish_mode"] != "create-or-idempotent-cache-hit":
    raise SystemExit("manifest must expose the no-overwrite publish mode")

summary = json.loads((out_a / "audit_summary.json").read_text(encoding="utf-8"))
for field in [
    "real_release_package_ready",
    "public_comparison_claim_ready",
    "raw_prompt_context_bytes",
    "attention_blocks",
    "transformer_blocks",
    "oracle_prediction_used",
    "raw_input_extractor_used",
    "latency_ms",
]:
    if summary[field] != 0:
        raise SystemExit(f"{field} must stay zero in product negative controls")
if summary["namespace"] != "fixture":
    raise SystemExit("summary namespace must match fixture")
if summary["unsupported_claim_rows"] < 1 or summary["abstain_rows"] < 1:
    raise SystemExit("unsupported and abstain rows must be present")

with (out_a / "source_manifest.csv").open(newline="", encoding="utf-8") as handle:
    source_manifest_rows = list(csv.DictReader(handle))
source_manifest_paths = {row["file_path"] for row in source_manifest_rows}
if "OUTSIDE_LINK.md" in source_manifest_paths:
    raise SystemExit("source manifest must not include tracked symlinks")
source_snapshot = json.loads((out_a / "source_snapshot.json").read_text(encoding="utf-8"))
if source_snapshot["schema_version"] != "local_repo_audit_source_snapshot.v1":
    raise SystemExit("source snapshot schema_version mismatch")
if source_snapshot["target_repo"] != str(repo):
    raise SystemExit("source snapshot must bind the target repo")
if source_snapshot["source_manifest_sha256"] != "sha256:" + sha256(out_a / "source_manifest.csv"):
    raise SystemExit("source snapshot must bind source_manifest.csv sha256")
if source_snapshot["source_file_count"] != len(source_manifest_rows):
    raise SystemExit("source snapshot source_file_count mismatch")
if source_snapshot["git_available"] != 1 or source_snapshot["git_dirty"] != 0:
    raise SystemExit("fixture source snapshot must bind a clean git repo")

findings = [json.loads(line) for line in (out_a / "audit_findings.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
plugin_ids = {row["plugin_id"] for row in findings}
expected_plugins = {
    "doc_code_identity",
    "deprecated_api",
    "config_consistency",
    "unsupported_claim",
    "missing_evidence",
    "user_question",
}
if not expected_plugins.issubset(plugin_ids):
    raise SystemExit(f"missing plugin rows: {sorted(expected_plugins - plugin_ids)}")
if not any(row["plugin_id"] == "unsupported_claim" and row["unsupported_claim"] == 1 and row["severity"] == "high" for row in findings):
    raise SystemExit("unsupported readiness wording must be flagged as high severity")
if not any(row["plugin_id"] == "user_question" and row["abstain"] == 1 and row["grounded"] == 0 and row["citations"] for row in findings):
    raise SystemExit("free-form production question must abstain without a grounded answer while keeping source context")
if any(row["plugin_id"] == "user_question" and "ship" in row["answer"].lower() and row["abstain"] != 1 for row in findings):
    raise SystemExit("user question must not be answered as a shippability claim")
deprecated = [row for row in findings if row["plugin_id"] == "deprecated_api"]
if not deprecated or deprecated[0]["language"] != "multi":
    raise SystemExit("deprecated API plugin must report multi-language coverage")

citations = [json.loads(line) for line in (out_a / "citation_spans.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
if not citations:
    raise SystemExit("citation spans must be present")
deprecated_ids = {row["finding_id"] for row in deprecated}
deprecated_previews = [
    row["span_text_preview"]
    for row in citations
    if row["finding_id"] in deprecated_ids
]
for expected in ["distutils", "std::auto_ptr", "document.write"]:
    if not any(expected in preview for preview in deprecated_previews):
        raise SystemExit(f"deprecated citation must bind exact evidence line for {expected}")
unsupported_ids = {row["finding_id"] for row in findings if row["plugin_id"] == "unsupported_claim"}
unsupported_previews = [
    row["span_text_preview"].lower()
    for row in citations
    if row["finding_id"] in unsupported_ids
]
if not any("production ready" in preview or "state of the art" in preview for preview in unsupported_previews):
    raise SystemExit("unsupported claim citation must bind exact readiness wording")
for row in citations:
    if row["file_path"] == "OUTSIDE_LINK.md":
        raise SystemExit("citation spans must not include tracked symlinks")
    path = repo / row["file_path"]
    if not path.is_file():
        raise SystemExit(f"citation path missing: {row['file_path']}")
    if int(row["line_start"]) <= 0 or int(row["line_end"]) < int(row["line_start"]):
        raise SystemExit("citation line bounds must be valid")
    if not row["sha256"].startswith("sha256:"):
        raise SystemExit("citation sha256 must be explicit")

with (out_a / "accuracy_rows.csv").open(newline="", encoding="utf-8") as handle:
    accuracy_rows = list(csv.DictReader(handle))
if not accuracy_rows or any(row["automatic_accuracy_claimed"] != "0" or row["manual_accuracy_review_required"] != "1" for row in accuracy_rows):
    raise SystemExit("accuracy rows must stay unreviewed/manual")

with (out_a / "citation_correctness_rows.csv").open(newline="", encoding="utf-8") as handle:
    citation_rows = list(csv.DictReader(handle))
if not citation_rows or any(row["citation_correctness_label"] != "source_bound_unreviewed" for row in citation_rows):
    raise SystemExit("citation correctness must stay source-bound unreviewed")

with (out_a / "false_positive_candidate_rows.csv").open(newline="", encoding="utf-8") as handle:
    fp_rows = list(csv.DictReader(handle))
if not fp_rows or not any(row["false_positive_candidate"] == "1" and row["auto_promoted"] == "0" for row in fp_rows):
    raise SystemExit("high/medium findings must be manual false-positive candidates, not auto-promoted")
with (out_a / "manual_review_queue.csv").open(newline="", encoding="utf-8") as handle:
    manual_review_rows = list(csv.DictReader(handle))
if {row["finding_id"] for row in manual_review_rows} != {row["finding_id"] for row in findings}:
    raise SystemExit("manual review queue must cover every finding")
if any(row["manual_review_required"] != "1" or row["auto_promoted"] != "0" for row in manual_review_rows):
    raise SystemExit("manual review queue must require review and forbid auto-promotion")

before_manifest = (out_a / "audit_manifest.json").read_text(encoding="utf-8")
before_sha = (out_a / "sha256sums.txt").read_text(encoding="utf-8")

tampered = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
tampered["output_dir_destroyed"] = 1
bad_manifest = out_a / "tampered_manifest.json"
bad_manifest.write_text(json.dumps(tampered, sort_keys=True), encoding="utf-8")
schema_cmd = [
    str(root / "tools/validate_json_schemas.py"),
    "--schema-instance",
    str(root / "schemas/local_repo_audit_output.schema.json"),
    str(bad_manifest),
]
if subprocess.run(schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("schema must reject output_dir_destroyed=1")

tampered = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
tampered["output_dir_overwritten"] = 1
bad_manifest.write_text(json.dumps(tampered, sort_keys=True), encoding="utf-8")
if subprocess.run(schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("schema must reject output_dir_overwritten=1")

tampered = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
tampered["fixture_result_promoted"] = 1
bad_manifest.write_text(json.dumps(tampered, sort_keys=True), encoding="utf-8")
if subprocess.run(schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("schema must reject fixture_result_promoted=1")

tampered = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
tampered["real_evidence_claimed"] = 1
bad_manifest.write_text(json.dumps(tampered, sort_keys=True), encoding="utf-8")
if subprocess.run(schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("schema must reject real_evidence_claimed=1")

tampered = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
tampered["real_benchmark_namespace_confirmed"] = 2
bad_manifest.write_text(json.dumps(tampered, sort_keys=True), encoding="utf-8")
if subprocess.run(schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("schema must reject invalid real_benchmark_namespace_confirmed values")

bad_summary = out_a / "tampered_summary.json"
summary_schema_cmd = [
    str(root / "tools/validate_json_schemas.py"),
    "--schema-instance",
    str(root / "schemas/local_repo_audit_summary.schema.json"),
    str(bad_summary),
]
tampered_summary = json.loads((out_a / "audit_summary.json").read_text(encoding="utf-8"))
tampered_summary["real_release_package_ready"] = 1
bad_summary.write_text(json.dumps(tampered_summary, sort_keys=True), encoding="utf-8")
if subprocess.run(summary_schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("summary schema must reject real_release_package_ready=1")

tampered_summary = json.loads((out_a / "audit_summary.json").read_text(encoding="utf-8"))
tampered_summary["public_comparison_claim_ready"] = 1
bad_summary.write_text(json.dumps(tampered_summary, sort_keys=True), encoding="utf-8")
if subprocess.run(summary_schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("summary schema must reject public_comparison_claim_ready=1")

tampered_summary = json.loads((out_a / "audit_summary.json").read_text(encoding="utf-8"))
tampered_summary["raw_prompt_context_bytes"] = 128
bad_summary.write_text(json.dumps(tampered_summary, sort_keys=True), encoding="utf-8")
if subprocess.run(summary_schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("summary schema must reject raw_prompt_context_bytes drift")

tampered = json.loads((out_a / "audit_manifest.json").read_text(encoding="utf-8"))
tampered["real_benchmark_namespace_confirmed"] = 1
(out_a / "audit_manifest.json").write_text(json.dumps(tampered, sort_keys=True), encoding="utf-8")
verify_bad_namespace = subprocess.run(
    [str(root / "tools/verify_local_audit.py"), str(out_a)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
if verify_bad_namespace.returncode == 0:
    raise SystemExit("verify_local_audit must reject fixture namespace with real_benchmark confirmation")
(out_a / "audit_manifest.json").write_text(before_manifest, encoding="utf-8")

bad_registry = json.loads((out_a / "plugin_registry.json").read_text(encoding="utf-8"))
bad_registry["plugins"][0]["module"] = "auditor_plugin_fake"
bad_registry_path = out_a / "tampered_plugin_registry.json"
bad_registry_path.write_text(json.dumps(bad_registry, sort_keys=True), encoding="utf-8")
registry_schema_cmd = [
    str(root / "tools/validate_json_schemas.py"),
    "--schema-instance",
    str(root / "schemas/local_repo_audit_plugin_registry.schema.json"),
    str(bad_registry_path),
]
if subprocess.run(registry_schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("plugin registry schema must reject unknown plugin modules")

overwrite_cmd = [
    str(root / "scripts/audit_my_repo.sh"),
    str(repo),
    "--mode",
    "quick",
    "--max-queries",
    "12",
    "--out",
    str(out_a),
    "--namespace",
    "fixture",
    "--question",
    "A different unsupported release question?",
    "--generator",
    "routehint-tiny",
]
overwrite_result = subprocess.run(overwrite_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if overwrite_result.returncode != 2:
    raise SystemExit(f"same output directory with a different cache key must return exit 2, got {overwrite_result.returncode}")
if (out_a / "audit_manifest.json").read_text(encoding="utf-8") != before_manifest:
    raise SystemExit("failed overwrite attempt must not change audit_manifest.json")
if (out_a / "sha256sums.txt").read_text(encoding="utf-8") != before_sha:
    raise SystemExit("failed overwrite attempt must not change sha256sums.txt")

original_report_text_for_cache_hit = (out_a / "AUDIT_REPORT.md").read_text(encoding="utf-8")
(out_a / "AUDIT_REPORT.md").write_text(original_report_text_for_cache_hit + "\ncache-hit tamper\n", encoding="utf-8")
cache_hit_tamper_cmd = [
    str(root / "scripts/audit_my_repo.sh"),
    str(repo),
    "--mode",
    "quick",
    "--max-queries",
    "12",
    "--out",
    str(out_a),
    "--namespace",
    "fixture",
    "--question",
    "Can I ship this as production ready?",
    "--generator",
    "routehint-tiny",
    "--no-verify-output",
]
cache_hit_tamper_result = subprocess.run(cache_hit_tamper_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if cache_hit_tamper_result.returncode != 2:
    raise SystemExit(f"tampered cache-hit output must fail before verify-output, got {cache_hit_tamper_result.returncode}")
if (out_a / "AUDIT_REPORT.md").read_text(encoding="utf-8") != original_report_text_for_cache_hit + "\ncache-hit tamper\n":
    raise SystemExit("tampered cache-hit failure must not overwrite existing report")
(out_a / "AUDIT_REPORT.md").write_text(original_report_text_for_cache_hit, encoding="utf-8")
if subprocess.run(cache_hit_tamper_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 2:
    raise SystemExit("cache-hit with changed verify-output setting must fail to preserve invocation artifacts")

conflict_out = out_a.parent / "out_conflict"
conflict_out.mkdir(parents=True, exist_ok=True)
(conflict_out / "AUDIT_REPORT.md").write_text("existing report must survive\n", encoding="utf-8")
conflict_cmd = [
    str(root / "scripts/audit_my_repo.sh"),
    str(repo),
    "--mode",
    "quick",
    "--max-queries",
    "12",
    "--out",
    str(conflict_out),
    "--namespace",
    "fixture",
    "--question",
    "Can this conflicting out dir be reused?",
    "--generator",
    "routehint-tiny",
]
conflict_result = subprocess.run(conflict_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if conflict_result.returncode != 2:
    raise SystemExit(f"output directory with an existing artifact and no manifest must return exit 2, got {conflict_result.returncode}")
if (conflict_out / "AUDIT_REPORT.md").read_text(encoding="utf-8") != "existing report must survive\n":
    raise SystemExit("conflicting output artifact must not be overwritten")
if (conflict_out / "ARCHITECTURE_TRACE.md").exists() or (conflict_out / "audit_manifest.json").exists():
    raise SystemExit("conflict preflight must not partially publish new output artifacts")

corrupt_manifest_out = out_a.parent / "out_corrupt_manifest"
corrupt_manifest_out.mkdir(parents=True, exist_ok=True)
(corrupt_manifest_out / "audit_manifest.json").write_text("{not json\n", encoding="utf-8")
(corrupt_manifest_out / "sentinel.txt").write_text("keep\n", encoding="utf-8")
corrupt_manifest_cmd = [
    str(root / "scripts/audit_my_repo.sh"),
    str(repo),
    "--mode",
    "quick",
    "--max-queries",
    "12",
    "--out",
    str(corrupt_manifest_out),
    "--namespace",
    "fixture",
    "--question",
    "Can this corrupt output manifest be reused?",
    "--generator",
    "routehint-tiny",
]
corrupt_manifest_result = subprocess.run(corrupt_manifest_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if corrupt_manifest_result.returncode != 2:
    raise SystemExit(f"corrupt existing audit_manifest.json must return exit 2, got {corrupt_manifest_result.returncode}")
if (corrupt_manifest_out / "audit_manifest.json").read_text(encoding="utf-8") != "{not json\n":
    raise SystemExit("corrupt existing audit_manifest.json must not be overwritten")
if (corrupt_manifest_out / "sentinel.txt").read_text(encoding="utf-8") != "keep\n":
    raise SystemExit("corrupt manifest publish failure must preserve unrelated files")
if (corrupt_manifest_out / "AUDIT_REPORT.md").exists() or (corrupt_manifest_out / "sha256sums.txt").exists():
    raise SystemExit("corrupt manifest publish failure must not partially publish artifacts")

tampered_citations = out_a / "citation_spans.jsonl"
sha_manifest_path = out_a / "sha256sums.txt"
original_citations = tampered_citations.read_text(encoding="utf-8")
original_sha_manifest_text = sha_manifest_path.read_text(encoding="utf-8")
sha_manifest_path.write_text(
    "\n".join(
        line
        for line in original_sha_manifest_text.splitlines()
        if not line.endswith("  abstain_rows.csv")
    )
    + "\n",
    encoding="utf-8",
)
verify_cmd = [str(root / "scripts/audit_my_repo.sh"), "--verify-existing", str(out_a)]
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must require abstain_rows.csv in sha256sums.txt")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

plugin_registry_path = out_a / "plugin_registry.json"
manifest_path = out_a / "audit_manifest.json"
original_plugin_registry_text = plugin_registry_path.read_text(encoding="utf-8")
original_manifest_text = manifest_path.read_text(encoding="utf-8")
tampered_registry = json.loads(original_plugin_registry_text)
tampered_registry["plugins"][0]["source_sha256"] = "sha256:" + ("0" * 64)
plugin_registry_path.write_text(json.dumps(tampered_registry, indent=2, sort_keys=True) + "\n", encoding="utf-8")
tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["plugin_registry_sha256"] = "sha256:" + sha256(plugin_registry_path)
manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_plugin_registry_sha = sha256(plugin_registry_path)
new_manifest_sha = sha256(manifest_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  plugin_registry.json"):
        sha_lines.append(f"{new_plugin_registry_sha}  plugin_registry.json")
    elif line.endswith("  audit_manifest.json"):
        sha_lines.append(f"{new_manifest_sha}  audit_manifest.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject plugin source sha drift")
plugin_registry_path.write_text(original_plugin_registry_text, encoding="utf-8")
manifest_path.write_text(original_manifest_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

summary_json_path = out_a / "audit_summary.json"
original_summary_json_text = summary_json_path.read_text(encoding="utf-8")
summary_json_path.write_text("{not json\n", encoding="utf-8")
corrupt_result = subprocess.run(verify_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
if corrupt_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject corrupt JSON artifacts")
if "Traceback" in corrupt_result.stderr:
    raise SystemExit("local-audit verifier must not expose Python traceback for corrupt JSON artifacts")
if "local_audit_verify_error:" not in corrupt_result.stderr or "artifact_verify: failed" not in corrupt_result.stderr:
    raise SystemExit("corrupt JSON verifier failure must include stable error and artifact failure lines")
summary_json_path.write_text(original_summary_json_text, encoding="utf-8")

first_sha_line = original_sha_manifest_text.splitlines()[0]
sha_manifest_path.write_text(original_sha_manifest_text + first_sha_line + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject duplicate sha256 manifest entries")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

sha_manifest_path.write_text(original_sha_manifest_text + "0" * 64 + "  ../escape.txt\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject sha256 manifest path traversal")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

unexpected_artifact_path = out_a / "unexpected_extra_artifact.txt"
unexpected_artifact_path.write_text("unexpected artifact must not be hash-admitted\n", encoding="utf-8")
sha_manifest_path.write_text(
    original_sha_manifest_text + f"{sha256(unexpected_artifact_path)}  unexpected_extra_artifact.txt\n",
    encoding="utf-8",
)
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject unexpected sha256 manifest artifacts")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")
unexpected_artifact_path.unlink()

source_snapshot_path = out_a / "source_snapshot.json"
original_source_snapshot_text = source_snapshot_path.read_text(encoding="utf-8")
tampered_source_snapshot = json.loads(original_source_snapshot_text)
tampered_source_snapshot["source_file_count"] = tampered_source_snapshot["source_file_count"] + 1
source_snapshot_path.write_text(json.dumps(tampered_source_snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_source_snapshot_sha = sha256(source_snapshot_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  source_snapshot.json"):
        sha_lines.append(f"{new_source_snapshot_sha}  source_snapshot.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject source snapshot/source manifest drift")
source_snapshot_path.write_text(original_source_snapshot_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

invocation_path = out_a / "audit_invocation.json"
original_invocation_text = invocation_path.read_text(encoding="utf-8")
tampered_invocation = json.loads(original_invocation_text)
tampered_invocation["max_queries"] = tampered_invocation["max_queries"] + 1
invocation_path.write_text(json.dumps(tampered_invocation, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_invocation_sha = sha256(invocation_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_invocation.json"):
        sha_lines.append(f"{new_invocation_sha}  audit_invocation.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit invocation option drift")
invocation_path.write_text(original_invocation_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

exit_contract_path = out_a / "exit_code_contract.json"
original_exit_contract_text = exit_contract_path.read_text(encoding="utf-8")
tampered_exit_contract = json.loads(original_exit_contract_text)
tampered_exit_contract["input_or_publish_error_exit_code"] = 3
exit_contract_path.write_text(json.dumps(tampered_exit_contract, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_exit_contract_sha = sha256(exit_contract_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  exit_code_contract.json"):
        sha_lines.append(f"{new_exit_contract_sha}  exit_code_contract.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject exit code contract drift")
exit_contract_path.write_text(original_exit_contract_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

manual_review_path = out_a / "manual_review_queue.csv"
original_manual_review_text = manual_review_path.read_text(encoding="utf-8")
with manual_review_path.open(newline="", encoding="utf-8") as handle:
    manual_review_rows = list(csv.DictReader(handle))
manual_review_rows[0]["auto_promoted"] = "1"
with manual_review_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(manual_review_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(manual_review_rows)
new_manual_review_sha = sha256(manual_review_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  manual_review_queue.csv"):
        sha_lines.append(f"{new_manual_review_sha}  manual_review_queue.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject manual review auto-promotion")
manual_review_path.write_text(original_manual_review_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

plugin_rule_path = out_a / "plugin_rule_rows.csv"
original_plugin_rule_text = plugin_rule_path.read_text(encoding="utf-8")
with plugin_rule_path.open(newline="", encoding="utf-8") as handle:
    plugin_rule_rows = list(csv.DictReader(handle))
plugin_rule_rows[0]["plugin_id"] = "unregistered_plugin"
with plugin_rule_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(plugin_rule_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(plugin_rule_rows)
new_plugin_rule_sha = sha256(plugin_rule_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  plugin_rule_rows.csv"):
        sha_lines.append(f"{new_plugin_rule_sha}  plugin_rule_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject plugin rules from unregistered plugins")
plugin_rule_path.write_text(original_plugin_rule_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with plugin_rule_path.open(newline="", encoding="utf-8") as handle:
    plugin_rule_rows = list(csv.DictReader(handle))
plugin_rule_rows = [
    row
    for row in plugin_rule_rows
    if not (row["plugin_id"] == "deprecated_api" and row["language"] == "javascript")
]
with plugin_rule_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(plugin_rule_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(plugin_rule_rows)
new_plugin_rule_sha = sha256(plugin_rule_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  plugin_rule_rows.csv"):
        sha_lines.append(f"{new_plugin_rule_sha}  plugin_rule_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject missing deprecated_api javascript rule coverage")
plugin_rule_path.write_text(original_plugin_rule_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

contract_path = out_a / "artifact_contract_rows.csv"
original_contract_text = contract_path.read_text(encoding="utf-8")
with contract_path.open(newline="", encoding="utf-8") as handle:
    contract_rows = list(csv.DictReader(handle))
contract_rows = [row for row in contract_rows if row["artifact_path"] != "grounded_generation_rows.csv"]
with contract_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(contract_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(contract_rows)
new_contract_sha = sha256(contract_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  artifact_contract_rows.csv"):
        sha_lines.append(f"{new_contract_sha}  artifact_contract_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject missing artifact contract rows")
contract_path.write_text(original_contract_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

tampered_citations.write_text(original_citations.replace("sha256:", "sha256:0000", 1), encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject tampered citation hashes")
tampered_citations.write_text(original_citations, encoding="utf-8")

findings_csv_path = out_a / "audit_findings.csv"
audit_findings_path = out_a / "audit_findings.jsonl"
original_findings_csv_text = findings_csv_path.read_text(encoding="utf-8")
original_findings_text = audit_findings_path.read_text(encoding="utf-8")
with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]

tampered_registry_binding_id = ""
for row in findings_csv_rows:
    if row.get("plugin_id") != "deprecated_api":
        tampered_registry_binding_id = row["finding_id"]
        row["language"] = "multi"
        break
if tampered_registry_binding_id:
    for row in finding_json_rows:
        if row["finding_id"] == tampered_registry_binding_id:
            row["language"] = "multi"
            break
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(findings_csv_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_json_rows), encoding="utf-8")
    new_findings_csv_sha = sha256(findings_csv_path)
    new_findings_jsonl_sha = sha256(audit_findings_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.csv"):
            sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
        elif line.endswith("  audit_findings.jsonl"):
            sha_lines.append(f"{new_findings_jsonl_sha}  audit_findings.jsonl")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject finding language drift from plugin registry")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
tampered_registry_binding_id = findings_csv_rows[0]["finding_id"] if findings_csv_rows else ""
if tampered_registry_binding_id:
    findings_csv_rows[0]["plugin_id"] = "unregistered_plugin"
    for row in finding_json_rows:
        if row["finding_id"] == tampered_registry_binding_id:
            row["plugin_id"] = "unregistered_plugin"
            break
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(findings_csv_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_json_rows), encoding="utf-8")
    new_findings_csv_sha = sha256(findings_csv_path)
    new_findings_jsonl_sha = sha256(audit_findings_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.csv"):
            sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
        elif line.endswith("  audit_findings.jsonl"):
            sha_lines.append(f"{new_findings_jsonl_sha}  audit_findings.jsonl")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject findings from unregistered plugins")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
tampered_binding_id = ""
for row in findings_csv_rows:
    sha_cells = [cell for cell in row.get("citation_sha256s", "").split(";") if cell]
    if sha_cells:
        tampered_binding_id = row["finding_id"]
        sha_cells[0] = "sha256:" + ("0" * 64)
        row["citation_sha256s"] = ";".join(sha_cells)
        break
if tampered_binding_id:
    for row in finding_json_rows:
        if row["finding_id"] == tampered_binding_id:
            sha_cells = [cell for cell in str(row.get("citation_sha256s", "")).split(";") if cell]
            sha_cells[0] = "sha256:" + ("0" * 64)
            row["citation_sha256s"] = ";".join(sha_cells)
            break
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(findings_csv_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_json_rows), encoding="utf-8")
    new_findings_csv_sha = sha256(findings_csv_path)
    new_findings_jsonl_sha = sha256(audit_findings_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.csv"):
            sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
        elif line.endswith("  audit_findings.jsonl"):
            sha_lines.append(f"{new_findings_jsonl_sha}  audit_findings.jsonl")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject finding citation sha binding drift")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

tampered_rows = [json.loads(line) for line in original_citations.splitlines() if line.strip()]
tampered_rows[0]["span_text_preview"] = "tampered preview that does not match the source line"
tampered_citations.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in tampered_rows), encoding="utf-8")
new_citation_sha = sha256(tampered_citations)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  citation_spans.jsonl"):
        sha_lines.append(f"{new_citation_sha}  citation_spans.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject citation preview mismatches")
tampered_citations.write_text(original_citations, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

source_snapshot_path = out_a / "source_snapshot.json"
original_source_snapshot_text = source_snapshot_path.read_text(encoding="utf-8")
tampered_source_snapshot = json.loads(original_source_snapshot_text)
tampered_source_snapshot["source_manifest_sha256"] = "sha256:" + ("0" * 64)
source_snapshot_path.write_text(json.dumps(tampered_source_snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_source_snapshot_sha = sha256(source_snapshot_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  source_snapshot.json"):
        sha_lines.append(f"{new_source_snapshot_sha}  source_snapshot.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject source snapshot manifest hash drift")
source_snapshot_path.write_text(original_source_snapshot_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

source_manifest_path = out_a / "source_manifest.csv"
original_source_manifest_text = source_manifest_path.read_text(encoding="utf-8")
with source_manifest_path.open(newline="", encoding="utf-8") as handle:
    source_manifest_rows = list(csv.DictReader(handle))
source_manifest_rows[0]["route_memory_source"] = "0"
with source_manifest_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(source_manifest_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(source_manifest_rows)
new_source_manifest_sha = sha256(source_manifest_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  source_manifest.csv"):
        sha_lines.append(f"{new_source_manifest_sha}  source_manifest.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject invalid source manifest rows")
source_manifest_path.write_text(original_source_manifest_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with source_manifest_path.open(newline="", encoding="utf-8") as handle:
    source_manifest_rows = list(csv.DictReader(handle))
outside_target = repo.parent / "outside_link_target.md"
source_manifest_rows[0]["file_path"] = "../outside_link_target.md"
source_manifest_rows[0]["sha256"] = "sha256:" + sha256(outside_target)
source_manifest_rows[0]["bytes"] = str(outside_target.stat().st_size)
with source_manifest_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(source_manifest_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(source_manifest_rows)
new_source_manifest_sha = sha256(source_manifest_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  source_manifest.csv"):
        sha_lines.append(f"{new_source_manifest_sha}  source_manifest.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject source manifest path traversal")
source_manifest_path.write_text(original_source_manifest_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with source_manifest_path.open(newline="", encoding="utf-8") as handle:
    source_manifest_rows = list(csv.DictReader(handle))
if len(source_manifest_rows) >= 2:
    source_manifest_rows[1]["file_path"] = source_manifest_rows[0]["file_path"]
    source_manifest_rows[1]["sha256"] = source_manifest_rows[0]["sha256"]
    source_manifest_rows[1]["bytes"] = source_manifest_rows[0]["bytes"]
    with source_manifest_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(source_manifest_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(source_manifest_rows)
    new_source_manifest_sha = sha256(source_manifest_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  source_manifest.csv"):
            sha_lines.append(f"{new_source_manifest_sha}  source_manifest.csv")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject duplicate source manifest file paths")
    source_manifest_path.write_text(original_source_manifest_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

outside_source = repo / "UNTRACKED_EXTRA.md"
outside_source.write_text("# Untracked Extra\n\nThis file was not part of the audit source manifest.\n", encoding="utf-8")
audit_findings_path = out_a / "audit_findings.jsonl"
original_findings_text = audit_findings_path.read_text(encoding="utf-8")
tampered_citation_rows = [json.loads(line) for line in original_citations.splitlines() if line.strip()]
tampered_finding_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
outside_rel = "UNTRACKED_EXTRA.md"
outside_cell = f"{outside_rel}:1"
outside_sha = "sha256:" + sha256(outside_source)
tampered_citation_rows[0]["file_path"] = outside_rel
tampered_citation_rows[0]["line_start"] = 1
tampered_citation_rows[0]["line_end"] = 1
tampered_citation_rows[0]["sha256"] = outside_sha
tampered_citation_rows[0]["span_text_preview"] = "# Untracked Extra"
for row in tampered_finding_rows:
    if row["finding_id"] == tampered_citation_rows[0]["finding_id"]:
        row["citations"] = outside_cell
        break
tampered_citations.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in tampered_citation_rows), encoding="utf-8")
audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in tampered_finding_rows), encoding="utf-8")
new_citation_sha = sha256(tampered_citations)
new_findings_sha = sha256(audit_findings_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  citation_spans.jsonl"):
        sha_lines.append(f"{new_citation_sha}  citation_spans.jsonl")
    elif line.endswith("  audit_findings.jsonl"):
        sha_lines.append(f"{new_findings_sha}  audit_findings.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject citations outside source_manifest.csv")
tampered_citations.write_text(original_citations, encoding="utf-8")
audit_findings_path.write_text(original_findings_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")
outside_source.unlink()

summary_csv_path = out_a / "audit_summary.csv"
original_summary_csv_text = summary_csv_path.read_text(encoding="utf-8")
with summary_csv_path.open(newline="", encoding="utf-8") as handle:
    summary_csv_rows = list(csv.DictReader(handle))
summary_csv_rows[0]["public_comparison_claim_ready"] = "1"
with summary_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_csv_rows)
new_summary_csv_sha = sha256(summary_csv_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_summary.csv"):
        sha_lines.append(f"{new_summary_csv_sha}  audit_summary.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit summary CSV/JSON drift")
summary_csv_path.write_text(original_summary_csv_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

summary_json_path = out_a / "audit_summary.json"
original_summary_json_text = summary_json_path.read_text(encoding="utf-8")
with summary_csv_path.open(newline="", encoding="utf-8") as handle:
    summary_csv_rows = list(csv.DictReader(handle))
tampered_summary_json = json.loads(original_summary_json_text)
summary_csv_rows[0]["false_positive_candidate_rows"] = "0"
tampered_summary_json["false_positive_candidate_rows"] = 0
with summary_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_csv_rows)
summary_json_path.write_text(json.dumps(tampered_summary_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_summary_csv_sha = sha256(summary_csv_path)
new_summary_json_sha = sha256(summary_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_summary.csv"):
        sha_lines.append(f"{new_summary_csv_sha}  audit_summary.csv")
    elif line.endswith("  audit_summary.json"):
        sha_lines.append(f"{new_summary_json_sha}  audit_summary.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject false-positive candidate summary row-count drift")
summary_csv_path.write_text(original_summary_csv_text, encoding="utf-8")
summary_json_path.write_text(original_summary_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with summary_csv_path.open(newline="", encoding="utf-8") as handle:
    summary_csv_rows = list(csv.DictReader(handle))
tampered_summary_json = json.loads(original_summary_json_text)
summary_csv_rows[0]["manual_review_queue_rows"] = "0"
tampered_summary_json["manual_review_queue_rows"] = 0
with summary_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_csv_rows)
summary_json_path.write_text(json.dumps(tampered_summary_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_summary_csv_sha = sha256(summary_csv_path)
new_summary_json_sha = sha256(summary_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_summary.csv"):
        sha_lines.append(f"{new_summary_csv_sha}  audit_summary.csv")
    elif line.endswith("  audit_summary.json"):
        sha_lines.append(f"{new_summary_json_sha}  audit_summary.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject manual review queue summary row-count drift")
summary_csv_path.write_text(original_summary_csv_text, encoding="utf-8")
summary_json_path.write_text(original_summary_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with summary_csv_path.open(newline="", encoding="utf-8") as handle:
    summary_csv_rows = list(csv.DictReader(handle))
tampered_summary_json = json.loads(original_summary_json_text)
summary_csv_rows[0]["wrong_answer_guard_pass_rows"] = "0"
tampered_summary_json["wrong_answer_guard_pass_rows"] = 0
with summary_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_csv_rows)
summary_json_path.write_text(json.dumps(tampered_summary_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_summary_csv_sha = sha256(summary_csv_path)
new_summary_json_sha = sha256(summary_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_summary.csv"):
        sha_lines.append(f"{new_summary_csv_sha}  audit_summary.csv")
    elif line.endswith("  audit_summary.json"):
        sha_lines.append(f"{new_summary_json_sha}  audit_summary.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject wrong-answer guard pass summary row-count drift")
summary_csv_path.write_text(original_summary_csv_text, encoding="utf-8")
summary_json_path.write_text(original_summary_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with summary_csv_path.open(newline="", encoding="utf-8") as handle:
    summary_csv_rows = list(csv.DictReader(handle))
tampered_summary_json = json.loads(original_summary_json_text)
summary_csv_rows[0]["unexpected_ready_claim"] = "1"
tampered_summary_json["unexpected_ready_claim"] = 1
with summary_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_csv_rows)
summary_json_path.write_text(json.dumps(tampered_summary_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
with contract_path.open(newline="", encoding="utf-8") as handle:
    contract_rows = list(csv.DictReader(handle))
for row in contract_rows:
    if row["artifact_path"] == "audit_summary.csv":
        row["required_columns"] = row["required_columns"] + "|unexpected_ready_claim"
        row["actual_columns"] = row["actual_columns"] + "|unexpected_ready_claim"
    if row["artifact_path"] == "audit_summary.json":
        row["required_keys"] = row["required_keys"] + "|unexpected_ready_claim"
        row["actual_keys"] = row["actual_keys"] + "|unexpected_ready_claim"
with contract_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(contract_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(contract_rows)
new_summary_csv_sha = sha256(summary_csv_path)
new_summary_json_sha = sha256(summary_json_path)
new_contract_sha = sha256(contract_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_summary.csv"):
        sha_lines.append(f"{new_summary_csv_sha}  audit_summary.csv")
    elif line.endswith("  audit_summary.json"):
        sha_lines.append(f"{new_summary_json_sha}  audit_summary.json")
    elif line.endswith("  artifact_contract_rows.csv"):
        sha_lines.append(f"{new_contract_sha}  artifact_contract_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject unexpected audit summary keys")
summary_csv_path.write_text(original_summary_csv_text, encoding="utf-8")
summary_json_path.write_text(original_summary_json_text, encoding="utf-8")
contract_path.write_text(original_contract_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

claim_boundary_path = out_a / "claim_boundary.md"
original_claim_boundary_text = claim_boundary_path.read_text(encoding="utf-8")
claim_boundary_path.write_text(
    original_claim_boundary_text.replace("real_release_package_ready=0", "real_release_package_ready=1"),
    encoding="utf-8",
)
new_claim_boundary_sha = sha256(claim_boundary_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  claim_boundary.md"):
        sha_lines.append(f"{new_claim_boundary_sha}  claim_boundary.md")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject claim boundary release drift")
claim_boundary_path.write_text(original_claim_boundary_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

architecture_trace_path = out_a / "ARCHITECTURE_TRACE.md"
original_architecture_trace_text = architecture_trace_path.read_text(encoding="utf-8")
architecture_trace_path.write_text(
    original_architecture_trace_text.replace("- raw_prompt_context_bytes=0", "- raw_prompt_context_bytes=128"),
    encoding="utf-8",
)
new_architecture_trace_sha = sha256(architecture_trace_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  ARCHITECTURE_TRACE.md"):
        sha_lines.append(f"{new_architecture_trace_sha}  ARCHITECTURE_TRACE.md")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject architecture trace raw-context drift")
architecture_trace_path.write_text(original_architecture_trace_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

audit_report_path = out_a / "AUDIT_REPORT.md"
original_audit_report_text = audit_report_path.read_text(encoding="utf-8")
audit_report_path.write_text(
    original_audit_report_text.replace("  abstain=1", "  abstain=0", 1),
    encoding="utf-8",
)
new_audit_report_sha = sha256(audit_report_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  AUDIT_REPORT.md"):
        sha_lines.append(f"{new_audit_report_sha}  AUDIT_REPORT.md")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit report decision drift")
audit_report_path.write_text(original_audit_report_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

audit_report_path.write_text(
    original_audit_report_text.replace("  abstain=1\n", "  abstain=1\n  abstain=0\n", 1),
    encoding="utf-8",
)
new_audit_report_sha = sha256(audit_report_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  AUDIT_REPORT.md"):
        sha_lines.append(f"{new_audit_report_sha}  AUDIT_REPORT.md")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject duplicate audit report decision lines")
audit_report_path.write_text(original_audit_report_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

first_report_sha_line = next(
    (line for line in original_audit_report_text.splitlines() if line.startswith("  sha256=sha256:")),
    "",
)
if first_report_sha_line:
    audit_report_path.write_text(
        original_audit_report_text.replace(first_report_sha_line, first_report_sha_line + "\n" + first_report_sha_line, 1),
        encoding="utf-8",
    )
    new_audit_report_sha = sha256(audit_report_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  AUDIT_REPORT.md"):
            sha_lines.append(f"{new_audit_report_sha}  AUDIT_REPORT.md")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject duplicate audit report evidence sha lines")
    audit_report_path.write_text(original_audit_report_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

findings_csv_path = out_a / "audit_findings.csv"
audit_findings_path = out_a / "audit_findings.jsonl"
original_findings_csv_text = findings_csv_path.read_text(encoding="utf-8")
original_findings_text = audit_findings_path.read_text(encoding="utf-8")
with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
tampered_citation_sha = "sha256:" + ("0" * 64)
original_citation_sha = ""
for row in findings_csv_rows:
    sha_cells = [cell for cell in row.get("citation_sha256s", "").split(";") if cell]
    if sha_cells:
        original_citation_sha = sha_cells[0]
        sha_cells[0] = tampered_citation_sha
        row["citation_sha256s"] = ";".join(sha_cells)
        tampered_finding_id = row["finding_id"]
        break
else:
    tampered_finding_id = ""
if tampered_finding_id:
    for row in finding_json_rows:
        if row["finding_id"] == tampered_finding_id:
            sha_cells = [cell for cell in row.get("citation_sha256s", "").split(";") if cell]
            sha_cells[0] = tampered_citation_sha
            row["citation_sha256s"] = ";".join(sha_cells)
            break
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(findings_csv_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_json_rows), encoding="utf-8")
    audit_report_path.write_text(
        original_audit_report_text.replace(f"  sha256={original_citation_sha}", f"  sha256={tampered_citation_sha}", 1),
        encoding="utf-8",
    )
    new_findings_csv_sha = sha256(findings_csv_path)
    new_findings_jsonl_sha = sha256(audit_findings_path)
    new_audit_report_sha = sha256(audit_report_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.csv"):
            sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
        elif line.endswith("  audit_findings.jsonl"):
            sha_lines.append(f"{new_findings_jsonl_sha}  audit_findings.jsonl")
        elif line.endswith("  AUDIT_REPORT.md"):
            sha_lines.append(f"{new_audit_report_sha}  AUDIT_REPORT.md")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject finding-level citation sha256 drift")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    audit_report_path.write_text(original_audit_report_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

resource_path = out_a / "resource_envelope.json"
original_resource_text = resource_path.read_text(encoding="utf-8")
tampered_resource = json.loads(original_resource_text)
tampered_resource["source_files_scanned"] = 999
resource_path.write_text(json.dumps(tampered_resource, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_resource_sha = sha256(resource_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  resource_envelope.json"):
        sha_lines.append(f"{new_resource_sha}  resource_envelope.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject resource envelope drift")
resource_path.write_text(original_resource_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

latency_path = out_a / "latency_rows.csv"
original_latency_text = latency_path.read_text(encoding="utf-8")
with latency_path.open(newline="", encoding="utf-8") as handle:
    latency_rows = list(csv.DictReader(handle))
latency_rows[0]["latency_ms"] = "7"
with latency_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(latency_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(latency_rows)
new_latency_sha = sha256(latency_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  latency_rows.csv"):
        sha_lines.append(f"{new_latency_sha}  latency_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject non-deterministic latency rows")
latency_path.write_text(original_latency_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

accuracy_path = out_a / "accuracy_rows.csv"
original_accuracy_text = accuracy_path.read_text(encoding="utf-8")
with accuracy_path.open(newline="", encoding="utf-8") as handle:
    accuracy_rows = list(csv.DictReader(handle))
with accuracy_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(accuracy_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(accuracy_rows[1:])
new_accuracy_sha = sha256(accuracy_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  accuracy_rows.csv"):
        sha_lines.append(f"{new_accuracy_sha}  accuracy_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject missing per-finding accuracy rows")
accuracy_path.write_text(original_accuracy_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with accuracy_path.open(newline="", encoding="utf-8") as handle:
    accuracy_rows = list(csv.DictReader(handle))
accuracy_rows.append(dict(accuracy_rows[0]))
with accuracy_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(accuracy_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(accuracy_rows)
with summary_csv_path.open(newline="", encoding="utf-8") as handle:
    summary_csv_rows = list(csv.DictReader(handle))
tampered_summary_json = json.loads(original_summary_json_text)
summary_csv_rows[0]["accuracy_rows"] = str(len(accuracy_rows))
tampered_summary_json["accuracy_rows"] = len(accuracy_rows)
with summary_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_csv_rows)
summary_json_path.write_text(json.dumps(tampered_summary_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
with contract_path.open(newline="", encoding="utf-8") as handle:
    contract_rows = list(csv.DictReader(handle))
for row in contract_rows:
    if row["artifact_path"] == "accuracy_rows.csv":
        row["actual_rows"] = str(len(accuracy_rows))
with contract_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(contract_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(contract_rows)
new_accuracy_sha = sha256(accuracy_path)
new_summary_csv_sha = sha256(summary_csv_path)
new_summary_json_sha = sha256(summary_json_path)
new_contract_sha = sha256(contract_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  accuracy_rows.csv"):
        sha_lines.append(f"{new_accuracy_sha}  accuracy_rows.csv")
    elif line.endswith("  audit_summary.csv"):
        sha_lines.append(f"{new_summary_csv_sha}  audit_summary.csv")
    elif line.endswith("  audit_summary.json"):
        sha_lines.append(f"{new_summary_json_sha}  audit_summary.json")
    elif line.endswith("  artifact_contract_rows.csv"):
        sha_lines.append(f"{new_contract_sha}  artifact_contract_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject duplicate per-finding accuracy rows")
accuracy_path.write_text(original_accuracy_text, encoding="utf-8")
summary_csv_path.write_text(original_summary_csv_text, encoding="utf-8")
summary_json_path.write_text(original_summary_json_text, encoding="utf-8")
contract_path.write_text(original_contract_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

generation_path = out_a / "grounded_generation_rows.csv"
original_generation_text = generation_path.read_text(encoding="utf-8")
with generation_path.open(newline="", encoding="utf-8") as handle:
    generation_rows = list(csv.DictReader(handle))
generation_rows[0]["raw_prompt_context_bytes"] = "128"
with generation_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(generation_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(generation_rows)
new_generation_sha = sha256(generation_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  grounded_generation_rows.csv"):
        sha_lines.append(f"{new_generation_sha}  grounded_generation_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject raw prompt stuffing in generation rows")
generation_path.write_text(original_generation_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

hint_path = out_a / "compact_route_hint_rows.csv"
original_hint_text = hint_path.read_text(encoding="utf-8")
with hint_path.open(newline="", encoding="utf-8") as handle:
    hint_rows = list(csv.DictReader(handle))
hint_rows[0]["raw_context_appended"] = "1"
with hint_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(hint_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(hint_rows)
new_hint_sha = sha256(hint_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  compact_route_hint_rows.csv"):
        sha_lines.append(f"{new_hint_sha}  compact_route_hint_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject raw context in route hint rows")
hint_path.write_text(original_hint_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with generation_path.open(newline="", encoding="utf-8") as handle:
    generation_rows = list(csv.DictReader(handle))
generation_rows[0]["hint_id"] = "missing_hint"
with generation_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(generation_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(generation_rows)
new_generation_sha = sha256(generation_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  grounded_generation_rows.csv"):
        sha_lines.append(f"{new_generation_sha}  grounded_generation_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject generation hint binding drift")
generation_path.write_text(original_generation_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

lineage_path = out_a / "prediction_lineage.jsonl"
original_lineage_text = lineage_path.read_text(encoding="utf-8")
lineage_rows = [json.loads(line) for line in original_lineage_text.splitlines() if line.strip()]
lineage_rows[0]["generator_id"] = "missing_gen"
lineage_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
new_lineage_sha = sha256(lineage_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  prediction_lineage.jsonl"):
        sha_lines.append(f"{new_lineage_sha}  prediction_lineage.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject prediction lineage generator drift")
lineage_path.write_text(original_lineage_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

mmap_path = out_a / "mmap_read_trace.jsonl"
original_mmap_text = mmap_path.read_text(encoding="utf-8")
mmap_rows = [json.loads(line) for line in original_mmap_text.splitlines() if line.strip()]
mmap_rows[0]["mmap_value_byte_read"] = 0
mmap_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in mmap_rows), encoding="utf-8")
new_mmap_sha = sha256(mmap_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  mmap_read_trace.jsonl"):
        sha_lines.append(f"{new_mmap_sha}  mmap_read_trace.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject mmap trace byte-read drift")
mmap_path.write_text(original_mmap_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

guard_path = out_a / "wrong_answer_guard_rows.csv"
original_guard_text = guard_path.read_text(encoding="utf-8")
with guard_path.open(newline="", encoding="utf-8") as handle:
    guard_rows = list(csv.DictReader(handle))
guard_rows[0]["citation_required"] = "0"
with guard_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(guard_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(guard_rows)
new_guard_sha = sha256(guard_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  wrong_answer_guard_rows.csv"):
        sha_lines.append(f"{new_guard_sha}  wrong_answer_guard_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject wrong-answer guard citation bypass")
guard_path.write_text(original_guard_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

findings_csv_path = out_a / "audit_findings.csv"
original_findings_csv_text = findings_csv_path.read_text(encoding="utf-8")
with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
generation_rows = []
with generation_path.open(newline="", encoding="utf-8") as handle:
    generation_rows = list(csv.DictReader(handle))
tampered_abstain_id = ""
for row in findings_csv_rows:
    if row["abstain"] == "1":
        tampered_abstain_id = row["finding_id"]
        row["grounded"] = "0"
        row["answer"] = "Yes, this repository is production ready."
        break
if tampered_abstain_id:
    for row in finding_json_rows:
        if row["finding_id"] == tampered_abstain_id:
            row["grounded"] = 0
            row["answer"] = "Yes, this repository is production ready."
            break
    for row in generation_rows:
        if row["finding_id"] == tampered_abstain_id:
            row["answer"] = "Yes, this repository is production ready."
            row["grounded"] = "0"
            row["abstain"] = "1"
            break
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(findings_csv_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_json_rows), encoding="utf-8")
    with generation_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(generation_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(generation_rows)
    new_findings_csv_sha = sha256(findings_csv_path)
    new_findings_jsonl_sha = sha256(audit_findings_path)
    new_generation_sha = sha256(generation_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.csv"):
            sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
        elif line.endswith("  audit_findings.jsonl"):
            sha_lines.append(f"{new_findings_jsonl_sha}  audit_findings.jsonl")
        elif line.endswith("  grounded_generation_rows.csv"):
            sha_lines.append(f"{new_generation_sha}  grounded_generation_rows.csv")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject direct answers in abstain findings")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    generation_path.write_text(original_generation_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
with generation_path.open(newline="", encoding="utf-8") as handle:
    generation_rows = list(csv.DictReader(handle))
tampered_ungrounded_id = ""
for row in findings_csv_rows:
    if row["grounded"] == "1":
        tampered_ungrounded_id = row["finding_id"]
        row["grounded"] = "0"
        row["abstain"] = "0"
        break
if tampered_ungrounded_id:
    for row in finding_json_rows:
        if row["finding_id"] == tampered_ungrounded_id:
            row["grounded"] = 0
            row["abstain"] = 0
            break
    for row in generation_rows:
        if row["finding_id"] == tampered_ungrounded_id:
            row["grounded"] = "0"
            row["abstain"] = "0"
            break
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(findings_csv_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_json_rows), encoding="utf-8")
    with generation_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(generation_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(generation_rows)
    new_findings_csv_sha = sha256(findings_csv_path)
    new_findings_jsonl_sha = sha256(audit_findings_path)
    new_generation_sha = sha256(generation_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.csv"):
            sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
        elif line.endswith("  audit_findings.jsonl"):
            sha_lines.append(f"{new_findings_jsonl_sha}  audit_findings.jsonl")
        elif line.endswith("  grounded_generation_rows.csv"):
            sha_lines.append(f"{new_generation_sha}  grounded_generation_rows.csv")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject ungrounded non-abstain findings")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    generation_path.write_text(original_generation_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
findings_csv_rows[0]["grounded"] = "0" if findings_csv_rows[0]["grounded"] != "0" else "1"
with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(findings_csv_rows)
new_findings_csv_sha = sha256(findings_csv_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_findings.csv"):
        sha_lines.append(f"{new_findings_csv_sha}  audit_findings.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit findings CSV/JSONL drift")
findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

manifest_path = out_a / "audit_manifest.json"
original_manifest_text = manifest_path.read_text(encoding="utf-8")
tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["plugin_registry_sha256"] = "sha256:" + ("0" * 64)
manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject plugin registry hash mismatch")
manifest_path.write_text(original_manifest_text, encoding="utf-8")

tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["cache_key"] = "0" * 64
manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject cache key mismatches")
manifest_path.write_text(original_manifest_text, encoding="utf-8")

tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["tool_source_sha256"] = "sha256:" + ("0" * 64)
manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_manifest_sha = sha256(manifest_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_manifest.json"):
        sha_lines.append(f"{new_manifest_sha}  audit_manifest.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit entrypoint source sha drift")
manifest_path.write_text(original_manifest_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["real_benchmark_namespace_confirmed"] = 1
manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_manifest_sha = sha256(manifest_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_manifest.json"):
        sha_lines.append(f"{new_manifest_sha}  audit_manifest.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject fixture namespace real_benchmark confirmation")
manifest_path.write_text(original_manifest_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

reproduce_path = out_a / "reproduce.sh"
original_reproduce_text = reproduce_path.read_text(encoding="utf-8")
reproduce_path.write_text(original_reproduce_text.replace(" --verify-output", ""), encoding="utf-8")
new_reproduce_sha = sha256(reproduce_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  reproduce.sh"):
        sha_lines.append(f"{new_reproduce_sha}  reproduce.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject reproduce.sh without --verify-output")
reproduce_path.write_text(original_reproduce_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

reproduce_path.write_text(original_reproduce_text.replace(" --max-queries 12", " --max-queries 11"), encoding="utf-8")
new_reproduce_sha = sha256(reproduce_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  reproduce.sh"):
        sha_lines.append(f"{new_reproduce_sha}  reproduce.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject reproduce.sh max-queries drift")
reproduce_path.write_text(original_reproduce_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

reproduce_path.write_text(original_reproduce_text.replace(" --generator routehint-tiny", " --generator routehint-other"), encoding="utf-8")
new_reproduce_sha = sha256(reproduce_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  reproduce.sh"):
        sha_lines.append(f"{new_reproduce_sha}  reproduce.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject reproduce.sh generator drift")
reproduce_path.write_text(original_reproduce_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

reproduce_path.write_text(
    original_reproduce_text.replace("Can I ship this as production ready?", "Can I claim this is release ready?"),
    encoding="utf-8",
)
new_reproduce_sha = sha256(reproduce_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  reproduce.sh"):
        sha_lines.append(f"{new_reproduce_sha}  reproduce.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject reproduce.sh question drift")
reproduce_path.write_text(original_reproduce_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

subprocess.run(
    [
        str(root / "scripts/audit_my_repo.sh"),
        str(repo),
        "--mode",
        "quick",
        "--max-queries",
        "12",
        "--out",
        str(out_b),
        "--namespace",
        "fixture",
        "--question",
        "A different unsupported release question?",
        "--generator",
        "routehint-tiny",
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
manifest_b = json.loads((out_b / "audit_manifest.json").read_text(encoding="utf-8"))
if manifest_b["cache_key"] == manifest["cache_key"]:
    raise SystemExit("cache key must change when the user question changes")
PY

echo "audit_my_repo negative controls passed"
