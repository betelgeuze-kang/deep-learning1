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

Innovation note: this repository is production ready and guaranteed to be state of the art.
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
repo_head="$(git -C "$repo" rev-parse HEAD)"

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
deprecated_parser_ids = {row["parser_id"] for row in rules if row["plugin_id"] == "deprecated_api"}
if not {
    "python_ast",
    "cpp_lexical_code_candidate_parser",
    "javascript_typescript_lexical_code_candidate_parser",
}.issubset(deprecated_parser_ids):
    raise SystemExit("deprecated_api listed rules must expose parser provenance for python/js-ts/cpp")
unsupported_parser_ids = {row["parser_id"] for row in rules if row["plugin_id"] == "unsupported_claim"}
if "claim_boundary_negation_code_literal_filter" not in unsupported_parser_ids:
    raise SystemExit("unsupported_claim listed rule must expose claim-boundary/code-literal parser provenance")
if any(row["evidence_policy"] not in {"source-bound-span", "abstain-when-missing-source-bound-span"} for row in rules):
    raise SystemExit("plugin rules must expose supported evidence policies")
if any(not row.get("parser_id") for row in rules):
    raise SystemExit("plugin rules must expose parser provenance")
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
expect_audit_exit 2 "too-small max findings must not skip required full-mode auditor plugins" "$repo" --mode full --max-findings 4 --out "$TMP_DIR/bad_too_few_plugin_queries"
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

negative_syntax_repo="$TMP_DIR/negative_syntax_repo"
mkdir -p "$negative_syntax_repo"
cat >"$negative_syntax_repo/README.md" <<'EOF'
# Negation Boundary

This project is not production ready.
Blocked claims: release ready, frontier, state of the art.
We must not call this release ready.
Do not claim this is frontier.
Inline example wording must stay an example: `production ready` and `guaranteed`.

```text
Example wording that must stay an example: this project is production ready and guaranteed.
```
EOF
cat >"$negative_syntax_repo/demo.py" <<'EOF'
# import distutils must not count inside a comment
# This module is production ready and guaranteed must not count inside a comment
text = "pkg_resources must not count inside a string"
claim_text = "release ready and state of the art must not count inside a string"
triple_text = """frontier must not count inside a Python multiline string"""
import json
EOF
cat >"$negative_syntax_repo/demo.js" <<'EOF'
// eval("1+1") must not count inside a comment
// This package is production ready and guaranteed must not count inside a comment
const text = "document.write must not count inside a string";
const claimText = "release ready and state of the art must not count inside a string";
const claimRegex = /production ready|frontier/;
export function ok() { return 1; }
EOF
cat >"$negative_syntax_repo/demo.ts" <<'EOF'
// Template literal text must not count as executable eval usage.
// This module is human-level and frontier must not count inside a comment.
const templateText = `eval(input) and document.write stay literal text`;
const claimTemplate = `production ready and guaranteed must not count inside template literal text`;
const claimRegex: RegExp = /release ready|human-level/;
export const ok: number = 1;
EOF
cat >"$negative_syntax_repo/demo.cpp" <<'EOF'
// std::auto_ptr<int> must not count inside a comment
// This library is production ready and guaranteed must not count inside a comment
const char* text = "gets( must not count inside a string";
const char* claim_text = "release ready and state of the art must not count inside a string";
const char* raw_claim_text = R"(human-level frontier must not count inside a raw string)";
int main() { return 0; }
EOF
git -C "$negative_syntax_repo" init -q
git -C "$negative_syntax_repo" add .
git -C "$negative_syntax_repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
"$ROOT_DIR/scripts/audit_my_repo.sh" "$negative_syntax_repo" \
  --mode full \
  --max-findings 5 \
  --out "$TMP_DIR/negative_syntax_out" \
  --namespace synthetic \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$TMP_DIR/negative_syntax_out" >/dev/null
python3 - "$TMP_DIR/negative_syntax_out" <<'PY'
import csv
import sys
from pathlib import Path

rows = list(csv.DictReader((Path(sys.argv[1]) / "audit_findings.csv").open(newline="", encoding="utf-8")))
deprecated = [row for row in rows if row["plugin_id"] == "deprecated_api"][0]
unsupported = [row for row in rows if row["plugin_id"] == "unsupported_claim"][0]
if deprecated["severity"] != "info" or "No deprecated/legacy API candidate" not in deprecated["answer"]:
    raise SystemExit("comment/string deprecated API negative control must not produce a finding")
if unsupported["unsupported_claim"] != "0" or unsupported["severity"] != "info" or unsupported["abstain"] != "1":
    raise SystemExit("negated claim-boundary wording must not be promoted as unsupported claim finding")
PY

parser_positive_repo="$TMP_DIR/parser_positive_repo"
mkdir -p "$parser_positive_repo"
cat >"$parser_positive_repo/README.md" <<'EOF'
# Parser Positive Control

This repository exercises lexical parser boundaries without release claims.
EOF
cat >"$parser_positive_repo/app.js" <<'EOF'
export function run(input) {
  const regexOnly = /eval\(/;
  const textOnly = "document.write should stay inside a string";
  if (regexOnly.test(input)) return "safe";
  return eval(input);
}
EOF
cat >"$parser_positive_repo/app.ts" <<'EOF'
export function render(input: string) {
  const textOnly = `eval(input) should stay literal text`;
  return `${/}/.test(input) ? eval(input) : input}`;
}
EOF
cat >"$parser_positive_repo/main.cpp" <<'EOF'
#include <cstdio>
const char* raw_text = R"(gets( must stay inside a raw string)";
int main() {
  char buffer[8];
  return gets(buffer) == nullptr;
}
EOF
git -C "$parser_positive_repo" init -q
git -C "$parser_positive_repo" add .
git -C "$parser_positive_repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
"$ROOT_DIR/scripts/audit_my_repo.sh" "$parser_positive_repo" \
  --mode full \
  --max-findings 5 \
  --out "$TMP_DIR/parser_positive_out" \
  --namespace synthetic \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$TMP_DIR/parser_positive_out" >/dev/null
python3 - "$TMP_DIR/parser_positive_out" <<'PY'
import csv
import sys
from pathlib import Path

out = Path(sys.argv[1])
findings = list(csv.DictReader((out / "audit_findings.csv").open(newline="", encoding="utf-8")))
spans = list(csv.DictReader((out / "citation_spans.csv").open(newline="", encoding="utf-8")))
deprecated = [row for row in findings if row["plugin_id"] == "deprecated_api"][0]
if deprecated["severity"] != "medium":
    raise SystemExit("parser positive control must detect real executable deprecated API usage")
for expected_rule in ["deprecated-api-06", "deprecated-api-08"]:
    if expected_rule not in deprecated["plugin_rule_ids"].split("|"):
        raise SystemExit(f"parser positive control missing expected rule id: {expected_rule}")
deprecated_spans = [row for row in spans if row["finding_id"] == deprecated["finding_id"]]
span_by_file = {row["file_path"]: row for row in deprecated_spans}
if span_by_file.get("app.js", {}).get("line_start") != "5":
    raise SystemExit("javascript parser must ignore regex/string decoys and cite the executable eval line")
if span_by_file.get("app.ts", {}).get("line_start") != "3":
    raise SystemExit("typescript parser must ignore template literal text and cite executable template expression eval")
if span_by_file.get("main.cpp", {}).get("line_start") != "5":
    raise SystemExit("cpp parser must ignore raw-string decoys and cite the executable gets line")
if "app.js:2" in deprecated["citations"] or "app.js:3" in deprecated["citations"] or "app.ts:2" in deprecated["citations"] or "main.cpp:2" in deprecated["citations"]:
    raise SystemExit("deprecated API citations must not bind to regex/string/template-literal/raw-string decoys")
PY

full_budget_out="$TMP_DIR/full_budget_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode full \
  --max-files 2 \
  --max-total-bytes 100000 \
  --max-file-bytes 1000 \
  --max-findings 6 \
  --out "$full_budget_out" \
  --namespace fixture \
  --question "Does full mode include every required plugin?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$full_budget_out" >/dev/null
python3 - "$TMP_DIR/no_question" "$full_budget_out" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

quick_summary = json.loads((Path(sys.argv[1]) / "audit_summary.json").read_text(encoding="utf-8")) if (Path(sys.argv[1]) / "audit_summary.json").exists() else None
full = Path(sys.argv[2])
summary = json.loads((full / "audit_summary.json").read_text(encoding="utf-8"))
resource = json.loads((full / "resource_envelope.json").read_text(encoding="utf-8"))
if summary["active_plugin_ids"] != "doc_code_identity|deprecated_api|config_consistency|unsupported_claim|missing_evidence":
    raise SystemExit("full mode must bind the full active plugin set")
if resource["max_files"] != 2 or resource["max_total_bytes"] != 100000 or resource["max_file_bytes"] != 1000 or resource["max_findings"] != 6:
    raise SystemExit("resource envelope must bind split file/byte/finding budgets")
if summary["source_files"] > 2:
    raise SystemExit("max-files budget must limit scanned source files")
if quick_summary is not None and quick_summary["active_plugin_ids"] == summary["active_plugin_ids"]:
    raise SystemExit("quick and full modes must use different active plugin sets")
findings = list(csv.DictReader((full / "audit_findings.csv").open(newline="", encoding="utf-8")))
if {row["plugin_id"] for row in findings} != {"doc_code_identity", "deprecated_api", "config_consistency", "unsupported_claim", "missing_evidence", "user_question"}:
    raise SystemExit("full mode findings must include every full plugin plus user question")
PY

changed_files_list="$TMP_DIR/changed-files.txt"
printf 'legacy.js\n' >"$changed_files_list"
changed_files_out="$TMP_DIR/changed_files_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode full \
  --max-files 5 \
  --max-total-bytes 100000 \
  --max-file-bytes 1000 \
  --max-findings 5 \
  --changed-files-from "$changed_files_list" \
  --out "$changed_files_out" \
  --namespace fixture \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$changed_files_out" >/dev/null
python3 - "$changed_files_out" "$changed_files_list" "$full_budget_out" "$ROOT_DIR" <<'PY'
import csv
import hashlib
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1])
changed_files = Path(sys.argv[2]).resolve()
full = Path(sys.argv[3])
root = Path(sys.argv[4]).resolve()
manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
resource = json.loads((out / "resource_envelope.json").read_text(encoding="utf-8"))
summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
source_rows = list(csv.DictReader((out / "source_manifest.csv").open(newline="", encoding="utf-8")))
source_snapshot = json.loads((out / "source_snapshot.json").read_text(encoding="utf-8"))


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


if manifest["source_scope"] != "changed-files" or invocation["source_scope"] != "changed-files" or resource["source_scope"] != "changed-files" or summary["source_scope"] != "changed-files":
    raise SystemExit("changed-files run must bind changed-files source scope everywhere")
if manifest["changed_file_rows"] != 1 or invocation["changed_file_rows"] != 1 or resource["changed_file_rows"] != 1 or summary["changed_file_rows"] != 1:
    raise SystemExit("changed-files run must record the normalized changed file row count")
expected_sha = "sha256:" + hashlib.sha256(changed_files.read_bytes()).hexdigest()
if manifest["changed_files_from"] != str(changed_files) or invocation["changed_files_from"] != str(changed_files):
    raise SystemExit("changed-files run must bind the changed-files input path")
if manifest["changed_files_from_sha256"] != expected_sha or invocation["changed_files_from_sha256"] != expected_sha:
    raise SystemExit("changed-files run must bind the changed-files input sha")
if [row["file_path"] for row in source_rows] != ["legacy.js"]:
    raise SystemExit("changed-files run must scan only the listed auditable current file")
if summary["source_files"] != 1 or manifest["source_file_count"] != 1 or resource["source_files_scanned"] != 1:
    raise SystemExit("changed-files run source counts must match the scoped source manifest")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if "--changed-files-from" not in reproduce_parts or str(changed_files) not in reproduce_parts:
    raise SystemExit("reproduce.sh must preserve --changed-files-from")
full_manifest = json.loads((full / "audit_manifest.json").read_text(encoding="utf-8"))
if full_manifest["cache_key"] == manifest["cache_key"]:
    raise SystemExit("changed-files source scope must change the cache key")
expected_cache_key = hashlib.sha256(json.dumps({
    "tool_version": "audit_my_repo_alpha.v1",
    "tool_source_sha256": "sha256:" + sha256(root / "scripts/audit_my_repo.py"),
    "verifier_source_sha256": "sha256:" + sha256(root / "tools/verify_local_audit.py"),
    "schema_sha256s": {
        rel: "sha256:" + sha256(root / rel)
        for rel in [
            "schemas/local_repo_audit_output.schema.json",
            "schemas/local_repo_audit_diagnostics.schema.json",
            "schemas/local_repo_audit_dashboard.schema.json",
            "schemas/local_repo_audit_exit_code_contract.schema.json",
            "schemas/local_repo_audit_accuracy_rows.schema.json",
            "schemas/local_repo_audit_citation_correctness_rows.schema.json",
            "schemas/local_repo_audit_findings.schema.json",
            "schemas/local_repo_audit_invocation.schema.json",
            "schemas/local_repo_audit_manual_review_queue.schema.json",
            "schemas/local_repo_audit_semantic_summary.schema.json",
            "schemas/local_repo_audit_summary.schema.json",
            "schemas/local_repo_audit_sarif.schema.json",
            "schemas/local_repo_audit_baseline_diff.schema.json",
            "schemas/local_repo_audit_plugin_registry.schema.json",
            "schemas/local_repo_audit_plugin_rules.schema.json",
            "schemas/local_repo_audit_resource_envelope.schema.json",
            "schemas/local_repo_audit_source_snapshot.schema.json",
            "schemas/local_repo_audit_suppressions.schema.json",
        ]
    },
    "target": manifest["target_repo"],
    "source": [(row["file_path"], row["sha256"]) for row in source_rows],
    "source_snapshot": source_snapshot,
    "source_scope": "changed-files",
    "changed_files_from": str(changed_files),
    "changed_files_from_sha256": expected_sha,
    "changed_file_rows": 1,
    "mode": "full",
    "max_queries": 5,
    "max_files": 5,
    "max_total_bytes": 100000,
    "max_file_bytes": 1000,
    "max_findings": 5,
    "active_plugin_ids": ["doc_code_identity", "deprecated_api", "config_consistency", "unsupported_claim", "missing_evidence"],
    "suppression_file_sha256": "sha256:" + sha256_text(""),
    "baseline_output": "",
    "baseline_output_sha256": "sha256:" + sha256_text(""),
    "namespace": "fixture",
    "real_benchmark_namespace_confirmed": 0,
    "question": "",
    "verify_output_requested": 1,
    "emit_report_requested": 1,
    "emit_lineage_requested": 1,
    "emit_reproduce_requested": 1,
    "emit_diagnostics_requested": 0,
    "plugin_registry_sha256": manifest["plugin_registry_sha256"],
}, sort_keys=True).encode("utf-8")).hexdigest()
if manifest["cache_key"] != expected_cache_key:
    raise SystemExit("changed-files cache key must bind source scope/input sha/source snapshot/plugin inputs")
PY

printf '%s\n' "$repo/legacy.js" >"$TMP_DIR/changed-files-absolute.txt"
expect_audit_exit 2 "absolute changed-files rows must fail" "$repo" \
  --mode quick --changed-files-from "$TMP_DIR/changed-files-absolute.txt" \
  --out "$TMP_DIR/bad_changed_files_absolute_out" --generator routehint-tiny
printf '../legacy.js\n' >"$TMP_DIR/changed-files-traversal.txt"
expect_audit_exit 2 "path traversal changed-files rows must fail" "$repo" \
  --mode quick --changed-files-from "$TMP_DIR/changed-files-traversal.txt" \
  --out "$TMP_DIR/bad_changed_files_traversal_out" --generator routehint-tiny
printf 'legacy.js\n' >"$TMP_DIR/.env.changed-files"
expect_audit_exit 2 ".env-like changed-files input path must not be read" "$repo" \
  --mode quick --changed-files-from "$TMP_DIR/.env.changed-files" \
  --out "$TMP_DIR/bad_changed_files_env_out" --generator routehint-tiny

cat >"$TMP_DIR/allowlist.json" <<'EOF'
{
  "schema_version": "local_repo_audit_suppressions.v1",
  "suppressions": [
    {
      "suppression_id": "accepted-distutils-fixture",
      "plugin_id": "deprecated_api",
      "rule_id": "deprecated-api-01",
      "file_path": "legacy.py",
      "reason": "fixture intentionally keeps distutils for allowlist coverage"
    }
  ]
}
EOF
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_suppressions.schema.json" "$TMP_DIR/allowlist.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode full \
  --max-findings 6 \
  --out "$TMP_DIR/allowlist_out" \
  --allowlist "$TMP_DIR/allowlist.json" \
  --namespace fixture \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$TMP_DIR/allowlist_out" >/dev/null
python3 - "$TMP_DIR/allowlist_out" "$TMP_DIR/allowlist.json" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
allowlist = Path(sys.argv[2]).resolve()
summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
findings = list(csv.DictReader((out / "audit_findings.csv").open(newline="", encoding="utf-8")))
suppressed = list(csv.DictReader((out / "suppressed_findings.csv").open(newline="", encoding="utf-8")))
if summary["suppression_rows"] != 1 or len(suppressed) != 1:
    raise SystemExit("allowlist run must record exactly one suppressed finding")
deprecated = [row for row in findings if row["plugin_id"] == "deprecated_api"][0]
if deprecated["suppressed"] != "1" or deprecated["suppression_ids"] != "accepted-distutils-fixture":
    raise SystemExit("deprecated finding must bind the applied suppression id")
if suppressed[0]["reason"] != "fixture intentionally keeps distutils for allowlist coverage":
    raise SystemExit("suppressed finding must preserve allowlist reason")
digest = "sha256:" + hashlib.sha256(allowlist.read_bytes()).hexdigest()
if invocation["suppression_file"] != str(allowlist) or invocation["suppression_file_sha256"] != digest:
    raise SystemExit("audit invocation must bind suppression file path and sha256")
PY
cat >"$TMP_DIR/bad_allowlist.json" <<'EOF'
{
  "schema_version": "local_repo_audit_suppressions.v1",
  "suppressions": [
    {
      "suppression_id": "blank-reason",
      "plugin_id": "deprecated_api",
      "rule_id": "deprecated-api-01",
      "file_path": "legacy.py",
      "reason": "   "
    }
  ]
}
EOF
expect_audit_exit 2 "active allowlist row without reason must fail" "$repo" --allowlist "$TMP_DIR/bad_allowlist.json" --out "$TMP_DIR/bad_allowlist_out"
cat >"$TMP_DIR/bad_allowlist_schema.json" <<'EOF'
{
  "schema_version": "local_repo_audit_suppressions.v1",
  "suppressions": [
    {
      "suppression_id": "schema-extra",
      "plugin_id": "deprecated_api",
      "rule_id": "deprecated-api-01",
      "file_path": "legacy.py",
      "reason": "schema should reject unexpected fields",
      "unexpected": "not allowed"
    }
  ]
}
EOF
expect_audit_exit 2 "schema-invalid allowlist rows must fail before suppression is applied" "$repo" --allowlist "$TMP_DIR/bad_allowlist_schema.json" --out "$TMP_DIR/bad_allowlist_schema_out"
printf '{"suppressions":[]}\n' >"$TMP_DIR/.env.allowlist"
expect_audit_exit 2 ".env-like allowlist path must not be read" "$repo" --allowlist "$TMP_DIR/.env.allowlist" --out "$TMP_DIR/env_allowlist_out"

baseline_seed_out="$TMP_DIR/baseline_seed_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$baseline_seed_out" \
  --namespace fixture \
  --question "Baseline seed for source-bound change triage?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_seed_out" >/dev/null

baseline_out="$TMP_DIR/baseline_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$baseline_out" \
  --baseline "$baseline_seed_out" \
  --namespace fixture \
  --question "Baseline seed for source-bound change triage?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_out" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_baseline_diff.schema.json" "$baseline_out/baseline_diff_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_dashboard.schema.json" "$baseline_out/audit_dashboard.json" >/dev/null

for file in \
  AUDIT_DASHBOARD.html \
  audit_dashboard.json \
  baseline_diff_rows.csv \
  baseline_diff_summary.json \
  BASELINE_DIFF.md
do
  if [[ ! -s "$baseline_out/$file" ]]; then
    echo "missing baseline diff artifact: $file" >&2
    exit 19
  fi
done

python3 - "$baseline_out" "$baseline_seed_out" <<'PY'
import csv
import hashlib
import json
import shlex
import sys
from pathlib import Path

baseline = Path(sys.argv[1])
seed = Path(sys.argv[2]).resolve()
seed_manifest = json.loads((seed / "audit_manifest.json").read_text(encoding="utf-8"))
manifest = json.loads((baseline / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((baseline / "audit_invocation.json").read_text(encoding="utf-8"))
diff_summary = json.loads((baseline / "baseline_diff_summary.json").read_text(encoding="utf-8"))
reproduce_lines = (baseline / "reproduce.sh").read_text(encoding="utf-8").splitlines()
reproduce_parts = []
for line in reproduce_lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("cd ") or stripped.startswith("#!"):
        continue
    reproduce_parts.extend(shlex.split(line))
expected_baseline_path = str(seed)
if manifest["baseline_output"] != expected_baseline_path:
    raise SystemExit("manifest must bind baseline_output to supplied path")
if invocation["baseline_output"] != expected_baseline_path:
    raise SystemExit("invocation must bind baseline_output to supplied path")
if manifest["baseline_output_sha256"] != invocation["baseline_output_sha256"]:
    raise SystemExit("manifest and invocation baseline_output_sha256 mismatch")
if not manifest["baseline_output_sha256"]:
    raise SystemExit("manifest baseline_output_sha256 must be non-empty when baseline is supplied")
if diff_summary["baseline_supplied"] != 1:
    raise SystemExit("baseline_diff_summary must record baseline_supplied=1")
if diff_summary["baseline_output"] != expected_baseline_path:
    raise SystemExit("baseline_diff_summary must bind baseline_output")
expected_manifest_sha = "sha256:" + hashlib.sha256((seed / "audit_manifest.json").read_bytes()).hexdigest()
if diff_summary["baseline_manifest_sha256"] != expected_manifest_sha:
    raise SystemExit("baseline_diff_summary baseline_manifest_sha256 mismatch")
if diff_summary["baseline_cache_key"] != seed_manifest["cache_key"]:
    raise SystemExit("baseline_diff_summary baseline_cache_key mismatch")
if diff_summary["current_finding_rows"] != diff_summary["diff_rows"]:
    raise SystemExit("baseline diff rows must cover every current finding")
expected_statuses = {"new", "changed", "resolved", "unchanged"}
for count_key in ["new_findings", "changed_findings", "resolved_findings", "unchanged_findings", "manual_review_required_rows", "baseline_finding_rows"]:
    if int(diff_summary[count_key]) < 0:
        raise SystemExit(f"baseline diff summary count must be non-negative: {count_key}")
if int(diff_summary["new_findings"]) + int(diff_summary["changed_findings"]) + int(diff_summary["resolved_findings"]) + int(diff_summary["unchanged_findings"]) != int(diff_summary["diff_rows"]):
    raise SystemExit("baseline diff summary status counts must sum to diff_rows")
if manifest["cache_key"] == seed_manifest["cache_key"]:
    raise SystemExit("cache key must change when --baseline changes")
if "--baseline" not in reproduce_parts or expected_baseline_path not in reproduce_parts:
    raise SystemExit("reproduce.sh must include --baseline flag with supplied path")
for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready"]:
    if diff_summary[key] != 0:
        raise SystemExit(f"baseline diff summary must keep {key}=0")
dashboard = (baseline / "BASELINE_DIFF.md").read_text(encoding="utf-8")
for snippet in ["release readiness", "public comparison readiness", "real model execution"]:
    if snippet not in dashboard:
        raise SystemExit(f"BASELINE_DIFF.md must preserve readiness boundary: {snippet}")
audit_dashboard = (baseline / "AUDIT_DASHBOARD.html").read_text(encoding="utf-8")
audit_dashboard_json = json.loads((baseline / "audit_dashboard.json").read_text(encoding="utf-8"))
for snippet in [
    'data-schema-version="local_repo_audit_dashboard.v1"',
    f'data-run-id="{manifest["run_id"]}"',
    f'data-cache-key="{manifest["cache_key"]}"',
    'data-release-ready="0"',
    'data-public-comparison-claim-ready="0"',
    'data-real-model-execution-ready="0"',
    'data-design-partner-beta-candidate-ready="0"',
    "release_ready=0",
    "public_comparison_claim_ready=0",
    "real_model_execution_ready=0",
    "design_partner_beta_candidate_ready=0",
]:
    if snippet not in audit_dashboard:
        raise SystemExit(f"AUDIT_DASHBOARD.html must preserve verified run/diff boundary: {snippet}")
if audit_dashboard_json["cache_key"] != manifest["cache_key"] or audit_dashboard_json["run_id"] != manifest["run_id"]:
    raise SystemExit("audit_dashboard.json must bind manifest run/cache identity")
if audit_dashboard_json["baseline"]["supplied"] != 1 or audit_dashboard_json["baseline"]["baseline_cache_key"] != seed_manifest["cache_key"]:
    raise SystemExit("audit_dashboard.json must bind supplied baseline identity")
for key in ["new_findings", "changed_findings", "resolved_findings", "unchanged_findings", "manual_review_required_rows"]:
    if audit_dashboard_json["diff_counts"][key] != diff_summary[key]:
        raise SystemExit(f"audit_dashboard.json must bind baseline metric: {key}")
    if f"<th>{key}</th><td>{diff_summary[key]}</td>" not in audit_dashboard:
        raise SystemExit(f"AUDIT_DASHBOARD.html must bind baseline metric: {key}")
with (baseline / "baseline_diff_rows.csv").open(newline="", encoding="utf-8") as handle:
    diff_rows = list(csv.DictReader(handle))
for row in diff_rows:
    if row["diff_status"] not in expected_statuses:
        raise SystemExit(f"baseline diff row uses unsupported status: {row['diff_status']}")
if int(diff_summary["unchanged_findings"]) <= 0:
    raise SystemExit("identical baseline comparison must produce unchanged rows")
if int(diff_summary["new_findings"]) or int(diff_summary["changed_findings"]) or int(diff_summary["resolved_findings"]):
    raise SystemExit("identical baseline comparison must not produce new/changed/resolved rows")
PY

baseline_semantic_repo="$TMP_DIR/baseline_semantic_repo"
mkdir -p "$baseline_semantic_repo"
cat >"$baseline_semantic_repo/README.md" <<'EOF'
# Fixture Product

This repository is production ready and guaranteed to be state of the art.
EOF
cat >"$baseline_semantic_repo/pyproject.toml" <<'EOF'
[project]
name = "different-package-name"
requires-python = ">=3.10"
EOF
cat >"$baseline_semantic_repo/legacy.py" <<'EOF'
import distutils

def answer():
    return "ship it"
EOF
cat >"$baseline_semantic_repo/legacy.js" <<'EOF'
var answer = eval("1 + 1");
document.write(answer);
EOF
git -C "$baseline_semantic_repo" init -q
git -C "$baseline_semantic_repo" add .
git -C "$baseline_semantic_repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
baseline_semantic_seed_out="$TMP_DIR/baseline_semantic_seed_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$baseline_semantic_repo" \
  --mode quick \
  --max-queries 12 \
  --out "$baseline_semantic_seed_out" \
  --namespace fixture \
  --question "Baseline semantic change triage?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_semantic_seed_out" >/dev/null

cat >"$baseline_semantic_repo/README.md" <<'EOF'
# Fixture Product

This repository is production ready and guaranteed to be best in class.
EOF
cat >"$baseline_semantic_repo/legacy.py" <<'EOF'
import json

def answer():
    return "ship it"
EOF
cat >"$baseline_semantic_repo/new_legacy.cpp" <<'EOF'
#include <memory>
std::auto_ptr<int> another_legacy_ptr();
EOF
git -C "$baseline_semantic_repo" add .
git -C "$baseline_semantic_repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m mutate
if "$ROOT_DIR/tools/verify_local_audit.py" "$baseline_semantic_seed_out" >/dev/null 2>&1; then
  echo "strict verifier must reject a historical baseline after target source changes" >&2
  exit 19
fi
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_semantic_seed_out" --allow-source-drift >/dev/null

baseline_semantic_out="$TMP_DIR/baseline_semantic_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$baseline_semantic_repo" \
  --mode quick \
  --max-queries 12 \
  --out "$baseline_semantic_out" \
  --baseline "$baseline_semantic_seed_out" \
  --namespace fixture \
  --question "Baseline semantic change triage?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_semantic_out" >/dev/null
python3 - "$baseline_semantic_out" "$baseline_semantic_seed_out" <<'PY'
import csv
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1])
seed = Path(sys.argv[2]).resolve()
summary = json.loads((out / "baseline_diff_summary.json").read_text(encoding="utf-8"))
dashboard = json.loads((out / "audit_dashboard.json").read_text(encoding="utf-8"))
rows = list(csv.DictReader((out / "baseline_diff_rows.csv").open(newline="", encoding="utf-8")))
statuses = {row["diff_status"] for row in rows}
for expected in ["new", "changed", "resolved"]:
    if expected not in statuses or int(summary[f"{expected}_findings"]) <= 0:
        raise SystemExit(f"mutated baseline comparison must produce {expected} rows")
if summary["not_compared_findings"] != 0:
    raise SystemExit("mutated baseline comparison with supplied baseline must not produce not_compared rows")
if summary["manual_review_required_rows"] != sum(1 for row in rows if row["diff_status"] != "unchanged"):
    raise SystemExit("baseline diff manual_review_required count must track non-unchanged rows")
if any(row["manual_review_required"] != ("0" if row["diff_status"] == "unchanged" else "1") for row in rows):
    raise SystemExit("baseline diff manual_review_required must be 0 only for unchanged rows")
if not any(row["diff_status"] == "resolved" and row["plugin_id"] == "deprecated_api" and "legacy.py:1" in row["baseline_citations"] and not row["current_citations"] for row in rows):
    raise SystemExit("baseline diff must mark removed deprecated Python finding as resolved")
if not any(row["diff_status"] == "new" and row["plugin_id"] == "deprecated_api" and "new_legacy.cpp:2" in row["current_citations"] and not row["baseline_citations"] for row in rows):
    raise SystemExit("baseline diff must mark newly introduced C++ deprecated finding as new")
if not any(row["diff_status"] == "changed" and row["plugin_id"] == "unsupported_claim" and row["current_citations"] == "README.md:3" and row["baseline_citations"] == "README.md:3" for row in rows):
    raise SystemExit("baseline diff must mark same-citation unsupported-claim content changes as changed")
for key in ["new_findings", "changed_findings", "resolved_findings", "unchanged_findings", "manual_review_required_rows"]:
    if dashboard["diff_counts"][key] != summary[key]:
        raise SystemExit(f"audit_dashboard.json must bind semantic baseline metric: {key}")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if "--baseline" not in reproduce_parts or reproduce_parts[reproduce_parts.index("--baseline") + 1] != str(seed):
    raise SystemExit("semantic baseline reproduce.sh must preserve the historical baseline path")
PY

no_baseline_out="$TMP_DIR/no_baseline_out"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$no_baseline_out" \
  --namespace fixture \
  --question "Baseline seed for source-bound change triage?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$no_baseline_out" >/dev/null
python3 - "$no_baseline_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

no_baseline = Path(sys.argv[1])
manifest = json.loads((no_baseline / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((no_baseline / "audit_invocation.json").read_text(encoding="utf-8"))
diff_summary = json.loads((no_baseline / "baseline_diff_summary.json").read_text(encoding="utf-8"))
if manifest["baseline_output"] != "":
    raise SystemExit("manifest baseline_output must be empty without --baseline")
if manifest["baseline_output_sha256"] != "sha256:" + hashlib.sha256(b"").hexdigest():
    raise SystemExit("manifest baseline_output_sha256 must be empty sha without --baseline")
if invocation["baseline_output"] != "":
    raise SystemExit("invocation baseline_output must be empty without --baseline")
if diff_summary["baseline_supplied"] != 0:
    raise SystemExit("baseline_diff_summary must record baseline_supplied=0 without --baseline")
if diff_summary["baseline_manifest_sha256"] != "sha256:" + hashlib.sha256(b"").hexdigest():
    raise SystemExit("baseline_diff_summary baseline_manifest_sha256 must be empty sha without --baseline")
if diff_summary["baseline_cache_key"] != "":
    raise SystemExit("baseline_diff_summary baseline_cache_key must be empty without --baseline")
if diff_summary["current_finding_rows"] != diff_summary["diff_rows"]:
    raise SystemExit("baseline diff rows must cover every current finding without --baseline")
if diff_summary["not_compared_findings"] != diff_summary["current_finding_rows"]:
    raise SystemExit("not_compared_findings must equal current_finding_rows without --baseline")
if diff_summary["new_findings"] or diff_summary["changed_findings"] or diff_summary["resolved_findings"] or diff_summary["unchanged_findings"]:
    raise SystemExit("no-baseline diff summary must not report new/changed/resolved/unchanged findings")
reproduce_text = (no_baseline / "reproduce.sh").read_text(encoding="utf-8")
if "--baseline" in reproduce_text:
    raise SystemExit("reproduce.sh must not include --baseline flag when baseline was not supplied")
PY

expect_audit_exit 2 "missing --baseline directory must fail with stable usage exit code" "$repo" \
  --mode quick --max-queries 12 \
  --baseline "$TMP_DIR/missing_baseline_dir" \
  --out "$TMP_DIR/bad_baseline_missing_out" --generator routehint-tiny
if [[ -e "$TMP_DIR/bad_baseline_missing_out/audit_manifest.json" ]] || compgen -G "$TMP_DIR/bad_baseline_missing_out/.staging/*" >/dev/null; then
  echo "missing --baseline directory must not publish audit artifacts" >&2
  exit 20
fi

unverified_baseline_dir="$TMP_DIR/unverified_baseline"
mkdir -p "$unverified_baseline_dir"
printf 'unverified baseline directory must fail verifier preflight\n' >"$unverified_baseline_dir/placeholder.txt"
expect_audit_exit 2 "unverified --baseline directory must fail with stable usage exit code" "$repo" \
  --mode quick --max-queries 12 \
  --baseline "$unverified_baseline_dir" \
  --out "$TMP_DIR/bad_baseline_unverified_out" --generator routehint-tiny
if [[ -e "$TMP_DIR/bad_baseline_unverified_out/audit_manifest.json" ]] || compgen -G "$TMP_DIR/bad_baseline_unverified_out/.staging/*" >/dev/null; then
  echo "unverified --baseline directory must not publish audit artifacts" >&2
  exit 21
fi

tampered_diff_rows_path="$baseline_out/baseline_diff_rows.csv"
tampered_diff_summary_path="$baseline_out/baseline_diff_summary.json"
tampered_diff_sha_manifest_path="$baseline_out/sha256sums.txt"
cp "$tampered_diff_rows_path" "$TMP_DIR/baseline_diff_rows.original"
cp "$tampered_diff_summary_path" "$TMP_DIR/baseline_diff_summary.original"
cp "$tampered_diff_sha_manifest_path" "$TMP_DIR/baseline_diff_sha_manifest.original"
python3 - "$tampered_diff_rows_path" <<'PY'
import csv
import sys
from pathlib import Path
path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
for row in rows:
    if row["diff_status"] == "unchanged":
        row["diff_status"] = "changed"
        row["manual_review_required"] = "1"
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
python3 - "$tampered_diff_sha_manifest_path" "$tampered_diff_rows_path" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = sha_path.read_text(encoding="utf-8").splitlines()
for idx, line in enumerate(lines):
    if line.endswith("  baseline_diff_rows.csv"):
        lines[idx] = f"{new_sha}  baseline_diff_rows.csv"
        break
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/tools/verify_local_audit.py" "$baseline_out" >/dev/null 2>&1; then
  echo "verifier must reject tampered baseline_diff_rows.csv" >&2
  exit 22
fi
cp "$TMP_DIR/baseline_diff_rows.original" "$tampered_diff_rows_path"
cp "$TMP_DIR/baseline_diff_sha_manifest.original" "$tampered_diff_sha_manifest_path"
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_out" >/dev/null

python3 - "$tampered_diff_summary_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["unchanged_findings"] = 0
payload["changed_findings"] = payload["diff_rows"]
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$tampered_diff_sha_manifest_path" "$tampered_diff_summary_path" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = sha_path.read_text(encoding="utf-8").splitlines()
for idx, line in enumerate(lines):
    if line.endswith("  baseline_diff_summary.json"):
        lines[idx] = f"{new_sha}  baseline_diff_summary.json"
        break
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/tools/verify_local_audit.py" "$baseline_out" >/dev/null 2>&1; then
  echo "verifier must reject tampered baseline_diff_summary.json counts" >&2
  exit 22
fi
cp "$TMP_DIR/baseline_diff_summary.original" "$tampered_diff_summary_path"
cp "$TMP_DIR/baseline_diff_sha_manifest.original" "$tampered_diff_sha_manifest_path"
"$ROOT_DIR/tools/verify_local_audit.py" "$baseline_out" >/dev/null

# Diagnostics negative controls: opt-out default, opt-in binding, and
# tamper rejection. Diagnostics must never leak raw source paths,
# citations, or question text.
default_diag_out="$TMP_DIR/diagnostics_default"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$default_diag_out" \
  --namespace fixture \
  --question "Diagnostics opt-out default smoke question?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$default_diag_out" >/dev/null
python3 - "$default_diag_out" "$repo" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()
manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
diagnostics = json.loads((out / "diagnostics.json").read_text(encoding="utf-8"))
if manifest.get("emit_diagnostics_requested") != 0:
    raise SystemExit("default opt-out run must keep emit_diagnostics_requested=0 in manifest")
if invocation.get("emit_diagnostics_requested") != 0:
    raise SystemExit("default opt-out run must keep emit_diagnostics_requested=0 in invocation")
if diagnostics.get("diagnostics_opt_in") != 0:
    raise SystemExit("default opt-out diagnostics must have diagnostics_opt_in=0")
if diagnostics.get("diagnostics_collected") != 0:
    raise SystemExit("default opt-out diagnostics must have diagnostics_collected=0")
if diagnostics.get("external_network_used") != 0:
    raise SystemExit("default opt-out diagnostics must keep external_network_used=0")
if diagnostics.get("scope") != "none":
    raise SystemExit("default opt-out diagnostics must keep scope=none")
text = json.dumps(diagnostics, sort_keys=True)
for forbidden in [str(repo), "legacy.py", "Diagnostics opt-out default smoke question?"]:
    if forbidden in text:
        raise SystemExit(f"default opt-out diagnostics must not contain {forbidden!r}")
PY

opt_in_diag_out="$TMP_DIR/diagnostics_optin"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$opt_in_diag_out" \
  --namespace fixture \
  --question "Diagnostics opt-in smoke question?" \
  --generator routehint-tiny \
  --emit-diagnostics >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_diagnostics.schema.json" "$opt_in_diag_out/diagnostics.json" >/dev/null
python3 - "$opt_in_diag_out" "$repo" <<'PY'
import csv
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()
manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
diagnostics = json.loads((out / "diagnostics.json").read_text(encoding="utf-8"))
summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
if manifest.get("emit_diagnostics_requested") != 1:
    raise SystemExit("opt-in run must bind emit_diagnostics_requested=1 in manifest")
if invocation.get("emit_diagnostics_requested") != 1:
    raise SystemExit("opt-in run must bind emit_diagnostics_requested=1 in invocation")
if diagnostics.get("diagnostics_opt_in") != 1:
    raise SystemExit("opt-in diagnostics must have diagnostics_opt_in=1")
if diagnostics.get("diagnostics_collected") != 1:
    raise SystemExit("opt-in diagnostics must have diagnostics_collected=1")
if diagnostics.get("external_network_used") != 0:
    raise SystemExit("opt-in diagnostics must keep external_network_used=0")
if diagnostics.get("scope") != "coarse-run-metrics":
    raise SystemExit("opt-in diagnostics must keep scope=coarse-run-metrics")
for key in ["mode", "namespace", "max_files", "max_total_bytes", "max_file_bytes", "max_findings", "finding_rows", "suppression_rows"]:
    if str(diagnostics.get(key)) != str(summary.get(key)):
        raise SystemExit(f"opt-in diagnostics {key} must mirror summary")
if str(diagnostics.get("source_file_count")) != str(summary.get("source_files")):
    raise SystemExit("opt-in diagnostics source_file_count must mirror summary source_files")
if diagnostics.get("max_queries") != 12:
    raise SystemExit("opt-in diagnostics max_queries must bind the run budget")
if diagnostics.get("active_plugin_ids") != summary.get("active_plugin_ids", "").split("|"):
    raise SystemExit("opt-in diagnostics active_plugin_ids must match summary")
text = json.dumps(diagnostics, sort_keys=True)
for forbidden in [str(repo), "legacy.py", "Diagnostics opt-in smoke question?"]:
    if forbidden in text:
        raise SystemExit(f"opt-in diagnostics must not contain {forbidden!r}")
for blocked in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "real_release_package_ready", "gpu_speedup_claim"]:
    if blocked in diagnostics:
        raise SystemExit(f"opt-in diagnostics must not contain readiness claim {blocked}")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if "--emit-diagnostics" not in reproduce_parts:
    raise SystemExit("reproduce.sh must include --emit-diagnostics in opt-in mode")
PY

# Cache key must change when --emit-diagnostics changes the opt-in flag.
python3 - "$default_diag_out" "$opt_in_diag_out" <<'PY'
import json
import sys
from pathlib import Path
default_key = json.loads((Path(sys.argv[1]) / "audit_manifest.json").read_text(encoding="utf-8"))["cache_key"]
opt_in_key = json.loads((Path(sys.argv[2]) / "audit_manifest.json").read_text(encoding="utf-8"))["cache_key"]
if default_key == opt_in_key:
    raise SystemExit("cache key must change when --emit-diagnostics flips the opt-in flag")
PY

# Tamper with diagnostics.json: verifier must reject and reject readiness claim leakage.
diagnostics_path="$opt_in_diag_out/diagnostics.json"
sha_manifest_path="$opt_in_diag_out/sha256sums.txt"
original_diagnostics_path="$TMP_DIR/diagnostics.original.json"
original_diag_sha_manifest_path="$TMP_DIR/diagnostics.original.sha256sums.txt"
cp "$diagnostics_path" "$original_diagnostics_path"
cp "$sha_manifest_path" "$original_diag_sha_manifest_path"
python3 - "$diagnostics_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["diagnostics_opt_in"] = 0
payload["diagnostics_collected"] = 0
payload["scope"] = "none"
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$sha_manifest_path" "$diagnostics_path" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = sha_path.read_text(encoding="utf-8").splitlines()
for idx, line in enumerate(lines):
    if line.endswith("  diagnostics.json"):
        lines[idx] = f"{new_sha}  diagnostics.json"
        break
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null 2>&1; then
  echo "verifier must reject diagnostics.json opt-in/opt-out drift" >&2
  exit 23
fi
cp "$original_diagnostics_path" "$diagnostics_path"
cp "$original_diag_sha_manifest_path" "$sha_manifest_path"
"$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null

# Diagnostics must never include raw source path, citation, or question text.
python3 - "$diagnostics_path" "$repo" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()
payload = {
    "schema_version": "local_repo_audit_diagnostics.v1",
    "tool_version": "audit_my_repo_alpha.v1",
    "diagnostics_opt_in": 1,
    "diagnostics_collected": 1,
    "external_network_used": 0,
    "scope": "coarse-run-metrics",
    "leak": str(repo),
}
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$sha_manifest_path" "$diagnostics_path" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = sha_path.read_text(encoding="utf-8").splitlines()
for idx, line in enumerate(lines):
    if line.endswith("  diagnostics.json"):
        lines[idx] = f"{new_sha}  diagnostics.json"
        break
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null 2>&1; then
  echo "verifier must reject diagnostics.json with raw target path leak" >&2
  exit 24
fi
cp "$original_diagnostics_path" "$diagnostics_path"
cp "$original_diag_sha_manifest_path" "$sha_manifest_path"
"$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null

# Tampered diagnostics readiness claim must also be rejected.
python3 - "$diagnostics_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["release_ready"] = 1
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$sha_manifest_path" "$diagnostics_path" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = sha_path.read_text(encoding="utf-8").splitlines()
for idx, line in enumerate(lines):
    if line.endswith("  diagnostics.json"):
        lines[idx] = f"{new_sha}  diagnostics.json"
        break
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null 2>&1; then
  echo "verifier must reject diagnostics.json readiness claim drift" >&2
  exit 25
fi
cp "$original_diagnostics_path" "$diagnostics_path"
cp "$original_diag_sha_manifest_path" "$sha_manifest_path"
"$ROOT_DIR/tools/verify_local_audit.py" "$opt_in_diag_out" >/dev/null

legacy_py_line1_span_sha="$(python3 - "$repo/legacy.py" <<'PY'
import hashlib
import sys
from pathlib import Path

line = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()[0].strip()
print("sha256:" + hashlib.sha256(line.encode("utf-8")).hexdigest())
PY
)"
readme_line3_span_sha="$(python3 - "$repo/README.md" <<'PY'
import hashlib
import sys
from pathlib import Path

line = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()[2].strip()
print("sha256:" + hashlib.sha256(line.encode("utf-8")).hexdigest())
PY
)"

cat >"$TMP_DIR/benchmark_labels.jsonl" <<EOF
{"case_id":"fixture_case","repo_path":"$repo","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","source_candidate_label_id":"direct-candidate-001","source_review_queue_id":"direct-review-001","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_line_end":1,"expected_span_sha256":"$legacy_py_line1_span_sha","expected":"present","expected_abstain":false}
{"case_id":"fixture_case","repo_path":"$repo","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P2","plugin_id":"unsupported_claim","rule_id":"unsupported-claim-readiness-capability-wording","file_path":"README.md","expected_line_start":3,"expected_line_end":3,"expected_span_sha256":"$readme_line3_span_sha","expected":"present"}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$TMP_DIR/benchmark_out" \
  --mode full \
  --namespace synthetic >/dev/null
benchmark_manifest_before_no_overwrite="$(cat "$TMP_DIR/benchmark_out/benchmark_manifest.json")"
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$TMP_DIR/benchmark_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
benchmark_no_overwrite_rc="$?"
set -e
if [[ "$benchmark_no_overwrite_rc" -ne 2 ]]; then
  echo "benchmark runner must refuse to replace existing benchmark output without --overwrite" >&2
  exit 26
fi
if [[ "$(cat "$TMP_DIR/benchmark_out/benchmark_manifest.json")" != "$benchmark_manifest_before_no_overwrite" ]]; then
  echo "benchmark no-overwrite refusal must preserve existing benchmark manifest" >&2
  exit 26
fi
benchmark_unrelated_out="$TMP_DIR/benchmark_unrelated_out"
mkdir "$benchmark_unrelated_out"
printf 'keep unrelated benchmark note\n' >"$benchmark_unrelated_out/sentinel.txt"
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$benchmark_unrelated_out" \
  --mode full \
  --namespace synthetic \
  --overwrite >/dev/null 2>&1
benchmark_unrelated_overwrite_rc="$?"
set -e
if [[ "$benchmark_unrelated_overwrite_rc" -ne 2 ]]; then
  echo "benchmark overwrite must refuse to delete unrelated output-root files" >&2
  exit 26
fi
if [[ "$(cat "$benchmark_unrelated_out/sentinel.txt")" != "keep unrelated benchmark note" ]]; then
  echo "benchmark overwrite refusal must preserve unrelated output-root files" >&2
  exit 26
fi
if [[ -e "$benchmark_unrelated_out/benchmark_manifest.json" ]] || [[ -e "$benchmark_unrelated_out/case_runs" ]]; then
  echo "benchmark overwrite refusal must not partially publish into unrelated output root" >&2
  exit 26
fi
benchmark_failure_out="$TMP_DIR/benchmark_failure_out"
set +e
AUDIT_MY_REPO_BENCHMARK_FAIL_AFTER_CASES=1 "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$benchmark_failure_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
benchmark_failure_rc="$?"
set -e
if [[ "$benchmark_failure_rc" -ne 2 ]]; then
  echo "benchmark runner must fail with input/run error on simulated post-case failure" >&2
  exit 26
fi
if [[ -e "$benchmark_failure_out/benchmark_manifest.json" ]] || [[ -e "$benchmark_failure_out/benchmark_summary.json" ]] || [[ -e "$benchmark_failure_out/case_runs" ]]; then
  echo "benchmark runner must not expose partial managed artifacts after post-case failure" >&2
  exit 26
fi
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$benchmark_failure_out").benchmark_backup.*" | grep -q .; then
  echo "benchmark runner must clean sibling backup directories after fresh failure" >&2
  exit 26
fi
cp "$TMP_DIR/benchmark_out/benchmark_manifest.json" "$TMP_DIR/benchmark_manifest.before_failure.json"
cp "$TMP_DIR/benchmark_out/benchmark_sha256sums.txt" "$TMP_DIR/benchmark_sha256sums.before_failure.txt"
set +e
AUDIT_MY_REPO_BENCHMARK_FAIL_AFTER_CASES=1 "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$TMP_DIR/benchmark_out" \
  --mode full \
  --namespace synthetic \
  --overwrite >/dev/null 2>&1
benchmark_overwrite_failure_rc="$?"
set -e
if [[ "$benchmark_overwrite_failure_rc" -ne 2 ]]; then
  echo "benchmark overwrite must fail with input/run error on simulated post-case failure" >&2
  exit 26
fi
cmp "$TMP_DIR/benchmark_manifest.before_failure.json" "$TMP_DIR/benchmark_out/benchmark_manifest.json" >/dev/null
cmp "$TMP_DIR/benchmark_sha256sums.before_failure.txt" "$TMP_DIR/benchmark_out/benchmark_sha256sums.txt" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$TMP_DIR/benchmark_out").benchmark_backup.*" | grep -q .; then
  echo "benchmark overwrite rollback must not leak sibling backup directories" >&2
  exit 26
fi
benchmark_write_failure_out="$TMP_DIR/benchmark_write_failure_out"
set +e
AUDIT_MY_REPO_BENCHMARK_FAIL_DURING_WRITE=1 "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$benchmark_write_failure_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
benchmark_write_failure_rc="$?"
set -e
if [[ "$benchmark_write_failure_rc" -ne 2 ]]; then
  echo "benchmark runner must fail with input/run error on simulated artifact write failure" >&2
  exit 26
fi
if [[ -e "$benchmark_write_failure_out/benchmark_run_metrics.csv" ]] || [[ -e "$benchmark_write_failure_out/benchmark_manifest.json" ]] || [[ -e "$benchmark_write_failure_out/case_runs" ]]; then
  echo "benchmark runner must not expose partial managed artifacts after artifact write failure" >&2
  exit 26
fi
set +e
AUDIT_MY_REPO_BENCHMARK_FAIL_DURING_WRITE=1 "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$TMP_DIR/benchmark_out" \
  --mode full \
  --namespace synthetic \
  --overwrite >/dev/null 2>&1
benchmark_overwrite_write_failure_rc="$?"
set -e
if [[ "$benchmark_overwrite_write_failure_rc" -ne 2 ]]; then
  echo "benchmark overwrite must fail with input/run error on simulated artifact write failure" >&2
  exit 26
fi
cmp "$TMP_DIR/benchmark_manifest.before_failure.json" "$TMP_DIR/benchmark_out/benchmark_manifest.json" >/dev/null
cmp "$TMP_DIR/benchmark_sha256sums.before_failure.txt" "$TMP_DIR/benchmark_out/benchmark_sha256sums.txt" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$TMP_DIR/benchmark_out").benchmark_backup.*" | grep -q .; then
  echo "benchmark overwrite write-failure rollback must not leak sibling backup directories" >&2
  exit 26
fi
benchmark_verify_failure_out="$TMP_DIR/benchmark_verify_failure_out"
set +e
AUDIT_MY_REPO_BENCHMARK_TAMPER_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$benchmark_verify_failure_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
benchmark_verify_failure_rc="$?"
set -e
if [[ "$benchmark_verify_failure_rc" -ne 1 ]]; then
  echo "benchmark runner must fail with verifier error on simulated manifest drift" >&2
  exit 26
fi
if [[ -e "$benchmark_verify_failure_out/benchmark_manifest.json" ]] || [[ -e "$benchmark_verify_failure_out/benchmark_summary.json" ]] || [[ -e "$benchmark_verify_failure_out/case_runs" ]]; then
  echo "benchmark runner must roll back fresh artifacts after verifier failure" >&2
  exit 26
fi
set +e
AUDIT_MY_REPO_BENCHMARK_TAMPER_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$TMP_DIR/benchmark_out" \
  --mode full \
  --namespace synthetic \
  --overwrite >/dev/null 2>&1
benchmark_overwrite_verify_failure_rc="$?"
set -e
if [[ "$benchmark_overwrite_verify_failure_rc" -ne 1 ]]; then
  echo "benchmark overwrite must fail with verifier error on simulated manifest drift" >&2
  exit 26
fi
cmp "$TMP_DIR/benchmark_manifest.before_failure.json" "$TMP_DIR/benchmark_out/benchmark_manifest.json" >/dev/null
cmp "$TMP_DIR/benchmark_sha256sums.before_failure.txt" "$TMP_DIR/benchmark_out/benchmark_sha256sums.txt" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$TMP_DIR/benchmark_out").benchmark_backup.*" | grep -q .; then
  echo "benchmark overwrite verifier-failure rollback must not leak sibling backup directories" >&2
  exit 26
fi
cat >"$TMP_DIR/benchmark_allowlist.json" <<'EOF'
{
  "schema_version": "local_repo_audit_suppressions.v1",
  "suppressions": [
    {
      "suppression_id": "benchmark-accepted-distutils",
      "plugin_id": "deprecated_api",
      "reason": "benchmark fixture accepts deprecated API debt"
    },
    {
      "suppression_id": "benchmark-accepted-readiness-wording",
      "plugin_id": "unsupported_claim",
      "reason": "benchmark fixture accepts claim wording for suppression coverage"
    },
    {
      "suppression_id": "benchmark-accepted-doc-code-identity",
      "plugin_id": "doc_code_identity",
      "reason": "benchmark fixture accepts doc-code identity mismatch for zero-row finding coverage"
    },
    {
      "suppression_id": "benchmark-accepted-config-consistency",
      "plugin_id": "config_consistency",
      "reason": "benchmark fixture accepts config consistency finding for zero-row finding coverage"
    },
    {
      "suppression_id": "benchmark-accepted-missing-evidence",
      "plugin_id": "missing_evidence",
      "reason": "benchmark fixture accepts missing-evidence finding for zero-row finding coverage"
    }
  ]
}
EOF
cat >"$TMP_DIR/benchmark_allowlist_labels.jsonl" <<EOF
{"case_id":"suppressed_case","repo_path":"$repo","allowlist":"$TMP_DIR/benchmark_allowlist.json","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"absent"}
EOF
cat >"$TMP_DIR/benchmark_other_allowlist.json" <<'EOF'
{
  "schema_version": "local_repo_audit_suppressions.v1",
  "suppressions": []
}
EOF
cat >"$TMP_DIR/benchmark_conflicting_allowlist_labels.jsonl" <<EOF
{"case_id":"conflicting_suppression_case","repo_path":"$repo","allowlist":"$TMP_DIR/benchmark_allowlist.json","suppression_file":"$TMP_DIR/benchmark_other_allowlist.json","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"absent"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_conflicting_allowlist_labels.jsonl" \
  --out "$TMP_DIR/benchmark_conflicting_allowlist_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
benchmark_conflicting_allowlist_rc="$?"
set -e
if [[ "$benchmark_conflicting_allowlist_rc" -ne 2 ]]; then
  echo "benchmark labels must reject conflicting allowlist and suppression_file values in the same row" >&2
  exit 26
fi
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_allowlist_labels.jsonl" \
  --out "$TMP_DIR/benchmark_allowlist_out" \
  --mode full \
  --namespace synthetic >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_allowlist_out" >/dev/null
python3 - "$TMP_DIR/benchmark_allowlist_out" "$TMP_DIR/benchmark_allowlist.json" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
allowlist = Path(sys.argv[2]).resolve()
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
case_manifest = json.loads((out / "case_runs" / "suppressed_case" / "audit_manifest.json").read_text(encoding="utf-8"))
case_invocation = json.loads((out / "case_runs" / "suppressed_case" / "audit_invocation.json").read_text(encoding="utf-8"))
with (out / "benchmark_confusion_rows.csv").open(newline="", encoding="utf-8") as handle:
    confusion_rows = list(csv.DictReader(handle))
with (out / "benchmark_labels.csv").open(newline="", encoding="utf-8") as handle:
    label_rows = list(csv.DictReader(handle))
with (out / "benchmark_findings.csv").open(newline="", encoding="utf-8") as handle:
    benchmark_reader = csv.DictReader(handle)
    benchmark_finding_fieldnames = list(benchmark_reader.fieldnames or [])
    benchmark_findings = list(benchmark_reader)
with (out / "benchmark_abstain_correctness.csv").open(newline="", encoding="utf-8") as handle:
    abstain_reader = csv.DictReader(handle)
    abstain_fieldnames = list(abstain_reader.fieldnames or [])
    abstain_rows = list(abstain_reader)
with (out / "case_runs" / "suppressed_case" / "audit_findings.csv").open(newline="", encoding="utf-8") as handle:
    case_findings = list(csv.DictReader(handle))
with (out / "case_runs" / "suppressed_case" / "suppressed_findings.csv").open(newline="", encoding="utf-8") as handle:
    suppressed_rows = list(csv.DictReader(handle))

allowlist_sha = "sha256:" + hashlib.sha256(allowlist.read_bytes()).hexdigest()
if case_manifest["suppression_file_sha256"] != allowlist_sha or case_invocation["suppression_file"] != str(allowlist):
    raise SystemExit("benchmark case audit must bind allowlist path and sha")
if summary["tp"] != 0 or summary["fp"] != 0 or summary["fn"] != 0:
    raise SystemExit("suppressed benchmark finding must not score as active TP/FP/FN")
if label_rows[0]["outcome"] != "TN" or confusion_rows[0]["outcome"] != "TN":
    raise SystemExit("absent label for suppressed finding must score as TN")
if any(row["row_type"] == "unmatched_finding" and row["plugin_id"] == "deprecated_api" for row in confusion_rows):
    raise SystemExit("suppressed deprecated finding must not appear as unmatched FP")
if not any(row["plugin_id"] == "deprecated_api" and row["suppressed"] == "1" and row["suppression_ids"] == "benchmark-accepted-distutils" for row in case_findings):
    raise SystemExit("case audit must still emit suppressed deprecated finding with suppression id")
if not suppressed_rows:
    raise SystemExit("case audit must emit suppressed_findings.csv row")
if any(row["plugin_id"] == "deprecated_api" and row["suppressed"] == "1" for row in benchmark_findings):
    raise SystemExit("benchmark_findings.csv must include only active unsuppressed findings")
expected_benchmark_finding_fields = [
    "case_id",
    "finding_id",
    "audit_type",
    "plugin_id",
    "plugin_rule_ids",
    "confidence",
    "language",
    "question",
    "answer",
    "severity",
    "grounded",
    "abstain",
    "unsupported_claim",
    "suppressed",
    "suppression_ids",
    "citations",
    "citation_sha256s",
    "route_memory_lineage",
    "raw_prompt_context_bytes",
    "oracle_prediction_used",
    "raw_input_extractor_used",
]
if benchmark_findings or benchmark_finding_fieldnames != expected_benchmark_finding_fields:
    raise SystemExit("zero-row benchmark_findings.csv must keep the full stable finding header")
expected_abstain_fields = [
    "case_id",
    "label_id",
    "plugin_id",
    "rule_id",
    "file_path",
    "expected",
    "expected_abstain",
    "matched_finding_id",
    "actual_abstain",
    "outcome",
    "abstain_correct",
]
if abstain_rows or abstain_fieldnames != expected_abstain_fields:
    raise SystemExit("zero-row benchmark_abstain_correctness.csv must keep the full stable abstain header")
if summary["precision"] != "0.000000" or summary["recall"] != "0.000000":
    raise SystemExit("suppressed-only benchmark should keep zero precision/recall without claiming positives")
PY

python3 - "$TMP_DIR/benchmark_allowlist_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
manifest_path = out / "benchmark_manifest.json"
sha_path = out / "benchmark_sha256sums.txt"
tampered_csvs = {
    "benchmark_run_metrics.csv": out / "benchmark_run_metrics.csv",
    "benchmark_case_metrics.csv": out / "benchmark_case_metrics.csv",
    "benchmark_citation_validity.csv": out / "benchmark_citation_validity.csv",
    "benchmark_confusion_rows.csv": out / "benchmark_confusion_rows.csv",
    "benchmark_findings.csv": out / "benchmark_findings.csv",
    "benchmark_abstain_correctness.csv": out / "benchmark_abstain_correctness.csv",
    "benchmark_label_quality.csv": out / "benchmark_label_quality.csv",
}
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
csv_shas = {}
for rel, path in tampered_csvs.items():
    path.write_text("case_id\n", encoding="utf-8")
    csv_shas[rel] = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    manifest["artifact_sha256s"][rel] = csv_shas[rel]
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    if rel in csv_shas:
        digest = csv_shas[rel].split(":", 1)[1]
    elif rel == "benchmark_manifest.json":
        digest = manifest_sha
    lines.append(f"{digest}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
allowlist_header_stderr="$TMP_DIR/benchmark_allowlist_header_verify.stderr"
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_allowlist_out" >/dev/null 2>"$allowlist_header_stderr"; then
  echo "benchmark verifier must reject benchmark CSV header drift" >&2
  exit 30
fi
for expected_header_error in \
  "benchmark_run_metrics.csv header drift" \
  "benchmark_case_metrics.csv header drift" \
  "benchmark_citation_validity.csv header drift" \
  "benchmark_confusion_rows.csv header drift" \
  "benchmark_findings.csv header drift" \
  "benchmark_abstain_correctness.csv header drift" \
  "benchmark_label_quality.csv header drift"; do
  if ! grep -F "$expected_header_error" "$allowlist_header_stderr" >/dev/null; then
    echo "benchmark verifier must explain CSV header drift: $expected_header_error" >&2
    cat "$allowlist_header_stderr" >&2
    exit 30
  fi
done

"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --out "$TMP_DIR/benchmark_out" \
  --mode full \
  --namespace synthetic \
  --overwrite >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_manifest.schema.json" "$TMP_DIR/benchmark_out/benchmark_manifest.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_summary.schema.json" "$TMP_DIR/benchmark_out/benchmark_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_maintainer_feedback.schema.json" "$TMP_DIR/benchmark_out/benchmark_maintainer_feedback.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_findings.schema.json" "$TMP_DIR/benchmark_out/benchmark_findings.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_evaluation.schema.json" "$TMP_DIR/benchmark_out/benchmark_evaluation.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_readiness.schema.json" "$TMP_DIR/benchmark_out/benchmark_readiness.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_labels.schema.json" "$TMP_DIR/benchmark_out/benchmark_labels.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json" "$TMP_DIR/benchmark_out/benchmark_label_citation_expectations.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null
python3 - "$TMP_DIR/benchmark_out/benchmark_summary.json" "$TMP_DIR/benchmark_out/benchmark_run_metrics.csv" "$TMP_DIR/benchmark_out/benchmark_citation_validity.csv" "$TMP_DIR/benchmark_out/benchmark_confusion_rows.csv" "$TMP_DIR/benchmark_out/benchmark_abstain_correctness.csv" "$TMP_DIR/benchmark_out/benchmark_maintainer_feedback.csv" "$TMP_DIR/benchmark_out/benchmark_manifest.json" "$TMP_DIR/benchmark_out/benchmark_sha256sums.txt" "$TMP_DIR/benchmark_labels.jsonl" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
with Path(sys.argv[2]).open(newline="", encoding="utf-8") as handle:
    run_metrics = list(csv.DictReader(handle))
with Path(sys.argv[3]).open(newline="", encoding="utf-8") as handle:
    citation_validity = list(csv.DictReader(handle))
with Path(sys.argv[4]).open(newline="", encoding="utf-8") as handle:
    confusion_rows = list(csv.DictReader(handle))
with Path(sys.argv[5]).open(newline="", encoding="utf-8") as handle:
    abstain_rows = list(csv.DictReader(handle))
with Path(sys.argv[6]).open(newline="", encoding="utf-8") as handle:
    feedback_rows = list(csv.DictReader(handle))
with (Path(sys.argv[1]).parent / "benchmark_label_quality.csv").open(newline="", encoding="utf-8") as handle:
    label_quality_rows = list(csv.DictReader(handle))
with (Path(sys.argv[1]).parent / "benchmark_labels.csv").open(newline="", encoding="utf-8") as handle:
    benchmark_label_rows = list(csv.DictReader(handle))
benchmark_labels = json.loads((Path(sys.argv[1]).parent / "benchmark_labels.json").read_text(encoding="utf-8"))
with (Path(sys.argv[1]).parent / "benchmark_label_citation_expectations.csv").open(newline="", encoding="utf-8") as handle:
    label_citation_rows = list(csv.DictReader(handle))
label_citation_payload = json.loads((Path(sys.argv[1]).parent / "benchmark_label_citation_expectations.json").read_text(encoding="utf-8"))
with (Path(sys.argv[1]).parent / "benchmark_repo_snapshots.csv").open(newline="", encoding="utf-8") as handle:
    repo_snapshot_rows = list(csv.DictReader(handle))
with (Path(sys.argv[1]).parent / "benchmark_findings.csv").open(newline="", encoding="utf-8") as handle:
    benchmark_finding_rows = list(csv.DictReader(handle))
benchmark_findings = json.loads((Path(sys.argv[1]).parent / "benchmark_findings.json").read_text(encoding="utf-8"))
benchmark_evaluation = json.loads((Path(sys.argv[1]).parent / "benchmark_evaluation.json").read_text(encoding="utf-8"))
benchmark_readiness = json.loads((Path(sys.argv[1]).parent / "benchmark_readiness.json").read_text(encoding="utf-8"))
manifest = json.loads(Path(sys.argv[7]).read_text(encoding="utf-8"))
sha_rows = {
    rel: digest
    for digest, rel in (
        line.split(None, 1)
        for line in Path(sys.argv[8]).read_text(encoding="utf-8").splitlines()
        if line.strip()
    )
}
labels_path = Path(sys.argv[9]).resolve()
if summary["tp"] != 2 or summary["fn"] != 0:
    raise SystemExit("benchmark harness must separate TP/FN label outcomes")
if manifest["schema_version"] != "local_repo_audit_benchmark_manifest.v1":
    raise SystemExit("benchmark manifest schema_version mismatch")
if manifest["labels_input"] != str(labels_path) or manifest["labels_input_sha256"] != "sha256:" + hashlib.sha256(labels_path.read_bytes()).hexdigest():
    raise SystemExit("benchmark manifest must bind label input path and sha")
if manifest["label_source_kind"] != "direct_labels":
    raise SystemExit("direct-label benchmark must bind label_source_kind=direct_labels")
if manifest["label_intake_output"] != "":
    raise SystemExit("direct-label benchmark must not bind a label intake output")
if manifest["label_intake_manifest_sha256"] != "sha256:" + hashlib.sha256(b"").hexdigest():
    raise SystemExit("direct-label benchmark must bind empty label intake manifest sha")
if manifest["label_intake_sha256sums_sha256"] != "sha256:" + hashlib.sha256(b"").hexdigest():
    raise SystemExit("direct-label benchmark must bind empty label intake sha manifest sha")
if manifest["feedback_input"] != "" or manifest["feedback_input_sha256"] != "sha256:" + hashlib.sha256(b"").hexdigest():
    raise SystemExit("benchmark manifest must bind empty feedback input by default")
if manifest["release_ready"] != 0 or manifest["public_comparison_claim_ready"] != 0 or manifest["real_model_execution_ready"] != 0:
    raise SystemExit("benchmark manifest readiness flags must remain false")
if manifest["synthetic_smoke_promoted_to_real_benchmark"] != 0:
    raise SystemExit("benchmark manifest must not promote synthetic smoke")
if manifest["real_benchmark_namespace_confirmed"] != 0:
    raise SystemExit("synthetic benchmark manifest must not carry real_benchmark confirmation")
if manifest["case_ids"] != ["fixture_case"]:
    raise SystemExit("benchmark manifest must bind sorted case ids")
for rel, digest in manifest["artifact_sha256s"].items():
    if sha_rows.get(rel) != digest.split(":", 1)[1]:
        raise SystemExit(f"benchmark sha manifest must bind artifact digest: {rel}")
if "benchmark_manifest.json" not in sha_rows or "case_runs/fixture_case/audit_manifest.json" not in sha_rows:
    raise SystemExit("benchmark sha manifest must include benchmark and case manifests")
if manifest["case_run_manifest_sha256s"]["fixture_case"].split(":", 1)[1] != sha_rows["case_runs/fixture_case/audit_manifest.json"]:
    raise SystemExit("benchmark manifest must bind case audit manifest sha")
if summary["product_readiness_calculated_from_real_labels"] != 0:
    raise SystemExit("synthetic namespace benchmark must not calculate product readiness")
if summary["design_partner_beta_candidate_ready"] != 0:
    raise SystemExit("synthetic namespace benchmark must never mark beta candidate readiness")
if summary["maintainer_feedback_rows"] != 0 or summary["maintainer_feedback_count"] != 0 or summary["maintainer_feedback_input_supplied"] != 0:
    raise SystemExit("synthetic benchmark without feedback input must not record maintainer feedback evidence")
if summary["maintainer_feedback_input_sha256"] != "sha256:" + hashlib.sha256(b"").hexdigest():
    raise SystemExit("synthetic benchmark without feedback input must bind empty feedback sha")
if feedback_rows:
    raise SystemExit("benchmark_maintainer_feedback.csv must be empty without feedback input")
if benchmark_labels["schema_version"] != "local_repo_audit_benchmark_labels.v1":
    raise SystemExit("benchmark labels JSON schema_version mismatch")
if benchmark_labels["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("benchmark labels JSON must bind alpha claim boundary")
if benchmark_labels["human_label_rows"] != len(benchmark_label_rows) or benchmark_labels["rows"] != benchmark_label_rows:
    raise SystemExit("benchmark labels JSON must match benchmark_labels.csv")
if len(benchmark_label_rows) != 2:
    raise SystemExit("benchmark_labels.csv must include one row per human label")
if summary["label_source_trace_rows"] != 1 or summary["label_source_trace_missing_rows"] != 1 or summary["label_source_trace_requirement_met"] != 0:
    raise SystemExit("benchmark summary must count present and missing label source traces")
if label_citation_payload["schema_version"] != "local_repo_audit_benchmark_label_citation_expectations.v1":
    raise SystemExit("benchmark label citation expectation JSON schema_version mismatch")
if label_citation_payload["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("benchmark label citation expectation JSON must bind alpha claim boundary")
if label_citation_payload["release_ready"] != 0 or label_citation_payload["public_comparison_claim_ready"] != 0 or label_citation_payload["real_model_execution_ready"] != 0:
    raise SystemExit("benchmark label citation expectation JSON must keep readiness blocked")
if label_citation_payload["label_rows"] != len(label_citation_rows) or label_citation_payload["rows"] != label_citation_rows:
    raise SystemExit("benchmark label citation expectation JSON must match CSV")
if label_citation_payload["citation_expectation_rows"] != 2 or label_citation_payload["citation_expectation_met_rows"] != 2:
    raise SystemExit("benchmark label citation expectation JSON must bind supplied/met counts")
if len(label_citation_rows) != len(benchmark_label_rows):
    raise SystemExit("benchmark label citation expectation rows must mirror label row count")
for label in benchmark_labels["rows"]:
    if label["case_id"] != "fixture_case" or label["outcome"] != "TP":
        raise SystemExit("benchmark labels JSON must bind case and outcome")
    if not label["plugin_id"] or label["expected"] != "present" or label["maintainer_feedback"] != "0":
        raise SystemExit("benchmark labels JSON must preserve label fields")
    if label["citation_expectation_supplied"] != "1" or label["citation_expectation_met"] != "1" or not label["matched_citation_id"]:
        raise SystemExit("benchmark labels JSON must bind matched human citation expectations")
    if not label["expected_line_start"] or not label["expected_line_end"] or not label["expected_span_sha256"].startswith("sha256:"):
        raise SystemExit("benchmark labels JSON must preserve expected citation span fields")
deprecated_label = [row for row in benchmark_labels["rows"] if row["plugin_id"] == "deprecated_api"][0]
unsupported_label = [row for row in benchmark_labels["rows"] if row["plugin_id"] == "unsupported_claim"][0]
if deprecated_label["source_candidate_label_id"] != "direct-candidate-001" or deprecated_label["source_review_queue_id"] != "direct-review-001":
    raise SystemExit("benchmark labels JSON must preserve direct-label source trace ids")
if unsupported_label["source_candidate_label_id"] != "" or unsupported_label["source_review_queue_id"] != "":
    raise SystemExit("benchmark labels JSON must keep absent direct-label source trace ids as empty strings")
if deprecated_label["expected_abstain"] != "0" or unsupported_label["expected_abstain"] != "":
    raise SystemExit("benchmark labels JSON must normalize expected_abstain to 0/1/empty")
if deprecated_label["expected_line_start"] != "1" or unsupported_label["expected_line_start"] != "3":
    raise SystemExit("benchmark labels JSON must preserve per-label expected citation lines")
if {row["label_id"] for row in label_citation_rows} != {row["label_id"] for row in benchmark_label_rows}:
    raise SystemExit("benchmark label citation expectation rows must bind every label id")
if any(row["citation_expectation_supplied"] != "1" or row["citation_expectation_met"] != "1" or not row["matched_citation_id"] for row in label_citation_rows):
    raise SystemExit("benchmark label citation expectation rows must bind exact matched citations")
if benchmark_findings["schema_version"] != "local_repo_audit_benchmark_findings.v1":
    raise SystemExit("benchmark findings JSON schema_version mismatch")
if benchmark_findings["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("benchmark findings JSON must bind alpha claim boundary")
if benchmark_findings["finding_rows"] != len(benchmark_finding_rows):
    raise SystemExit("benchmark findings JSON must bind finding row count")
if benchmark_findings["rows"] != benchmark_finding_rows:
    raise SystemExit("benchmark findings JSON must match benchmark_findings.csv")
if not benchmark_finding_rows:
    raise SystemExit("benchmark_findings.csv must include fixture findings")
for finding in benchmark_findings["rows"]:
    if finding["case_id"] != "fixture_case":
        raise SystemExit("benchmark findings JSON must bind case_id for each finding")
    if not finding["plugin_id"] or not finding["plugin_rule_ids"] or not finding["confidence"]:
        raise SystemExit("benchmark findings JSON rows must preserve plugin/rule/confidence")
    for flag in ["grounded", "abstain", "unsupported_claim", "suppressed", "route_memory_lineage", "oracle_prediction_used", "raw_input_extractor_used"]:
        if finding[flag] not in {"0", "1"}:
            raise SystemExit(f"benchmark findings JSON must preserve binary flag strings: {flag}")
if len(label_quality_rows) != 2:
    raise SystemExit("benchmark_label_quality.csv must include one row per human label")
if summary["label_quality_total_rows"] != 2 or summary["label_quality_specific_rows"] != 2:
    raise SystemExit("benchmark summary must record specific label quality rows")
for key in ["label_quality_broad_rows", "label_quality_citation_unbound_rows", "label_quality_duplicate_rows", "label_quality_contradictory_rows"]:
    if summary[key] != 0:
        raise SystemExit(f"specific benchmark labels must not record label quality defect: {key}")
if summary["label_quality_requirement_met"] != 1:
    raise SystemExit("specific benchmark labels must satisfy label quality requirement")
if sum(int(row["is_specific"]) for row in label_quality_rows) != 2:
    raise SystemExit("benchmark_label_quality.csv must bind specific label rows")
if sum(int(row["citation_expectation_supplied"]) for row in label_quality_rows) != 2:
    raise SystemExit("benchmark_label_quality.csv must bind citation expectation coverage")
if summary["standard_json_findings_checked_rows"] != 1 or summary["standard_json_findings_valid_rows"] != 1:
    raise SystemExit("benchmark summary must record valid standard JSON findings output per case")
if benchmark_evaluation["schema_version"] != "local_repo_audit_benchmark_evaluation.v1":
    raise SystemExit("benchmark evaluation JSON schema_version mismatch")
if benchmark_evaluation["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("benchmark evaluation JSON must bind alpha claim boundary")
if benchmark_evaluation["release_ready"] != 0 or benchmark_evaluation["public_comparison_claim_ready"] != 0 or benchmark_evaluation["real_model_execution_ready"] != 0:
    raise SystemExit("benchmark evaluation JSON must keep readiness claims blocked")
for key in [
    "human_label_rows",
    "tp",
    "fp",
    "fn",
    "p0_p1_label_rows",
    "p0_p1_tp",
    "p0_p1_fp",
    "p0_p1_fn",
    "precision",
    "recall",
    "p0_p1_precision",
    "abstain_checked",
    "abstain_correct",
    "citation_validity_rows",
    "citation_validity_pass_rows",
    "label_citation_expectation_rows",
    "label_citation_expectation_met_rows",
    "overall_precision_requirement_met",
    "p0_p1_precision_requirement_met",
    "citation_validity_requirement_met",
    "label_citation_expectation_requirement_met",
]:
    if str(benchmark_evaluation["metrics"][key]) != str(summary[key]):
        raise SystemExit(f"benchmark evaluation JSON must bind summary metric: {key}")
if benchmark_evaluation["confusion_rows"] != len(confusion_rows) or benchmark_evaluation["confusion"] != confusion_rows:
    raise SystemExit("benchmark evaluation JSON must bind confusion rows")
if benchmark_evaluation["abstain_correctness_rows"] != len(abstain_rows) or benchmark_evaluation["abstain_correctness"] != abstain_rows:
    raise SystemExit("benchmark evaluation JSON must bind abstain correctness rows")
if benchmark_evaluation["citation_validity_detail_rows"] != len(citation_validity) or benchmark_evaluation["citation_validity"] != citation_validity:
    raise SystemExit("benchmark evaluation JSON must bind citation validity rows")
if benchmark_readiness["schema_version"] != "local_repo_audit_benchmark_readiness.v1":
    raise SystemExit("benchmark readiness JSON schema_version mismatch")
if benchmark_readiness["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("benchmark readiness JSON must bind alpha claim boundary")
if benchmark_readiness["release_ready"] != 0 or benchmark_readiness["public_comparison_claim_ready"] != 0 or benchmark_readiness["real_model_execution_ready"] != 0:
    raise SystemExit("benchmark readiness JSON must keep readiness claims blocked")
if benchmark_readiness["product_readiness_calculated_from_real_labels"] != summary["product_readiness_calculated_from_real_labels"]:
    raise SystemExit("benchmark readiness JSON must bind real-label readiness basis")
if benchmark_readiness["design_partner_beta_candidate_ready"] != summary["design_partner_beta_candidate_ready"]:
    raise SystemExit("benchmark readiness JSON must bind beta candidate readiness")
if benchmark_readiness["gate_rows"] != len(benchmark_readiness["rows"]):
    raise SystemExit("benchmark readiness JSON must bind gate row count")
if benchmark_readiness["passed_gate_rows"] != sum(1 for row in benchmark_readiness["rows"] if row["passed"] == 1):
    raise SystemExit("benchmark readiness JSON must bind passed gate count")
if benchmark_readiness["blocked_gate_rows"] != sum(1 for row in benchmark_readiness["rows"] if row["passed"] == 0):
    raise SystemExit("benchmark readiness JSON must bind blocked gate count")
if benchmark_readiness["blocked_gate_rows"] == 0:
    raise SystemExit("synthetic benchmark readiness JSON must record blocked gates")
gate_ids = {row["gate_id"] for row in benchmark_readiness["rows"]}
for gate_id in ["real_repo_requirement_met", "human_label_requirement_met", "label_source_trace_requirement_met", "maintainer_feedback_requirement_met"]:
    if gate_id not in gate_ids:
        raise SystemExit(f"benchmark readiness JSON must include gate: {gate_id}")
for row in benchmark_readiness["rows"]:
    if row["passed"] == 0 and not row["blocked_reason"]:
        raise SystemExit("blocked benchmark readiness gate must include a blocker reason")
    if row["passed"] == 1 and row["blocked_reason"]:
        raise SystemExit("passed benchmark readiness gate must not include a blocker reason")
if len(repo_snapshot_rows) != 1:
    raise SystemExit("benchmark_repo_snapshots.csv must include one row per case")
snapshot = repo_snapshot_rows[0]
if snapshot["case_id"] != "fixture_case" or snapshot["repo_git_available"] != "1" or snapshot["repo_git_dirty"] != "0":
    raise SystemExit("benchmark repo snapshot must bind a clean git worktree")
if snapshot["expected_repo_git_head_match"] != "1" or snapshot["repo_snapshot_locked"] != "1":
    raise SystemExit("benchmark repo snapshot must lock expected git HEAD")
if snapshot["repo_snapshot_missing_expectation"] != "0" or snapshot["repo_snapshot_mismatch"] != "0":
    raise SystemExit("benchmark repo snapshot must not report missing expectation or mismatch for locked fixture")
if not snapshot["repo_snapshot_sha256"].startswith("sha256:") or not snapshot["repo_git_tracked_files_sha256"].startswith("sha256:"):
    raise SystemExit("benchmark repo snapshot must bind deterministic sha values")
if summary["repo_snapshot_rows"] != 1 or summary["repo_snapshot_locked_rows"] != 1 or summary["repo_snapshot_dirty_rows"] != 0 or summary["repo_snapshot_mismatch_rows"] != 0 or summary["repo_snapshot_missing_expectation_rows"] != 0:
    raise SystemExit("benchmark summary must record repo snapshot counts")
for key in [
    "real_repo_requirement_met",
    "human_label_requirement_met",
    "repo_snapshot_requirement_met",
    "maintainer_feedback_requirement_met",
    "overall_precision_requirement_met",
    "p0_p1_precision_requirement_met",
    "citation_validity_requirement_met",
    "label_citation_expectation_requirement_met",
    "standard_json_findings_requirement_met",
    "install_success_requirement_met",
    "first_report_requirement_met",
    "rerun_requirement_met",
]:
    if summary[key] != 0:
        raise SystemExit(f"synthetic benchmark must not satisfy beta gate requirement: {key}")
if summary["p0_p1_label_rows"] != 1 or summary["p0_p1_tp"] != 1 or summary["p0_p1_precision"] != "1.000000":
    raise SystemExit("benchmark harness must calculate P0/P1 label precision separately")
if summary["release_ready"] != 0 or summary["public_comparison_claim_ready"] != 0 or summary["real_model_execution_ready"] != 0:
    raise SystemExit("benchmark harness must keep readiness claims blocked")
if summary["citation_validity_rows"] != summary["citation_validity_pass_rows"]:
    raise SystemExit("benchmark harness must record citation validity separately")
if summary["label_citation_expectation_rows"] != 2 or summary["label_citation_expectation_met_rows"] != 2:
    raise SystemExit("benchmark harness must record human-label citation expectation matches separately")
if summary["abstain_checked"] != 1 or summary["abstain_correct"] != 1:
    raise SystemExit("benchmark harness must record abstain correctness separately")
if not confusion_rows:
    raise SystemExit("benchmark harness must emit benchmark_confusion_rows.csv")
if sum(int(row["tp"]) for row in confusion_rows) != 2 or sum(int(row["fn"]) for row in confusion_rows) != 0:
    raise SystemExit("benchmark confusion rows must separate TP/FN outcomes")
if any(row["row_type"] not in {"human_label", "unmatched_finding"} for row in confusion_rows):
    raise SystemExit("benchmark confusion rows must record row_type provenance")
if len(abstain_rows) != 1:
    raise SystemExit("benchmark_abstain_correctness.csv must include exactly one checked row")
if abstain_rows[0]["expected_abstain"] != "0" or abstain_rows[0]["actual_abstain"] != "0" or abstain_rows[0]["abstain_correct"] != "1":
    raise SystemExit("benchmark abstain correctness row must bind expected and actual abstain values")
if not citation_validity:
    raise SystemExit("benchmark harness must emit benchmark_citation_validity.csv rows")
for row in citation_validity:
    if row["citation_valid"] != "1":
        raise SystemExit("benchmark citation validity rows must pass for verified fixture output")
    for key in ["file_exists", "file_sha256_valid", "source_manifest_sha256_valid", "line_bounds_valid", "span_sha256_valid", "span_preview_valid"]:
        if row[key] != "1":
            raise SystemExit(f"benchmark citation validity must record {key}=1")
    if row["invalid_reasons"]:
        raise SystemExit("valid benchmark citations must not include invalid reasons")
if summary["install_success_rows"] != 1 or summary["install_success_rate"] != "1.000000":
    raise SystemExit("benchmark harness must record local install/preflight success")
if summary["first_report_success_rows"] != 1 or summary["first_report_success_rate"] != "1.000000":
    raise SystemExit("benchmark harness must record first verified report success rate")
if int(summary["first_report_wall_ms_max"]) <= 0:
    raise SystemExit("benchmark harness must record positive first report wall time")
if summary["rerun_checked_rows"] != 1 or summary["rerun_success_rows"] != 1 or summary["rerun_success_rate"] != "1.000000":
    raise SystemExit("benchmark harness must record successful rerun rate")
if summary["rerun_cache_key_match_rows"] != 1 or summary["rerun_semantic_result_match_rows"] != 1:
    raise SystemExit("benchmark harness must record rerun cache/semantic consistency")
if summary["changed_file_scope_case_rows"] != 0 or summary["tracked_scope_case_rows"] != 1:
    raise SystemExit("benchmark harness must record tracked vs changed-file scope case counts")
if len(run_metrics) != 1:
    raise SystemExit("benchmark_run_metrics.csv must have one row for the fixture case")
row = run_metrics[0]
for key in ["install_success", "first_report_success", "standard_json_findings_checked", "standard_json_findings_valid", "rerun_checked", "rerun_success", "rerun_cache_key_match", "rerun_semantic_result_match"]:
    if row[key] != "1":
        raise SystemExit(f"benchmark_run_metrics.csv must record {key}=1")
if row["standard_json_findings_invalid_reasons"]:
    raise SystemExit("valid benchmark standard JSON findings must not include invalid reasons")
if row["source_scope"] != "tracked" or row["source_file_count"] == "0" or row["changed_file_rows"] != "0" or row["changed_files_from"]:
    raise SystemExit("benchmark_run_metrics.csv must bind default tracked source scope")
if not row["cache_key"] or not row["semantic_result_sha256"].startswith("sha256:"):
    raise SystemExit("benchmark_run_metrics.csv must record cache key and semantic result sha")
PY
benchmark_manifest_path="$TMP_DIR/benchmark_out/benchmark_manifest.json"
benchmark_summary_path="$TMP_DIR/benchmark_out/benchmark_summary.json"
benchmark_run_metrics_path="$TMP_DIR/benchmark_out/benchmark_run_metrics.csv"
benchmark_repo_snapshot_path="$TMP_DIR/benchmark_out/benchmark_repo_snapshots.csv"
benchmark_labels_csv_path="$TMP_DIR/benchmark_out/benchmark_labels.csv"
benchmark_labels_json_path="$TMP_DIR/benchmark_out/benchmark_labels.json"
benchmark_label_citation_csv_path="$TMP_DIR/benchmark_out/benchmark_label_citation_expectations.csv"
benchmark_label_citation_json_path="$TMP_DIR/benchmark_out/benchmark_label_citation_expectations.json"
benchmark_findings_csv_path="$TMP_DIR/benchmark_out/benchmark_findings.csv"
benchmark_findings_json_path="$TMP_DIR/benchmark_out/benchmark_findings.json"
benchmark_evaluation_path="$TMP_DIR/benchmark_out/benchmark_evaluation.json"
benchmark_readiness_path="$TMP_DIR/benchmark_out/benchmark_readiness.json"
benchmark_confusion_path="$TMP_DIR/benchmark_out/benchmark_confusion_rows.csv"
benchmark_sha_path="$TMP_DIR/benchmark_out/benchmark_sha256sums.txt"
cp "$benchmark_manifest_path" "$TMP_DIR/benchmark_manifest.original.json"
cp "$benchmark_summary_path" "$TMP_DIR/benchmark_summary.original.json"
cp "$benchmark_run_metrics_path" "$TMP_DIR/benchmark_run_metrics.original.csv"
cp "$benchmark_repo_snapshot_path" "$TMP_DIR/benchmark_repo_snapshots.original.csv"
cp "$benchmark_labels_csv_path" "$TMP_DIR/benchmark_labels.original.csv"
cp "$benchmark_labels_json_path" "$TMP_DIR/benchmark_labels.original.json"
cp "$benchmark_label_citation_csv_path" "$TMP_DIR/benchmark_label_citation_expectations.original.csv"
cp "$benchmark_label_citation_json_path" "$TMP_DIR/benchmark_label_citation_expectations.original.json"
cp "$benchmark_findings_csv_path" "$TMP_DIR/benchmark_findings.original.csv"
cp "$benchmark_findings_json_path" "$TMP_DIR/benchmark_findings.original.json"
cp "$benchmark_evaluation_path" "$TMP_DIR/benchmark_evaluation.original.json"
cp "$benchmark_readiness_path" "$TMP_DIR/benchmark_readiness.original.json"
cp "$benchmark_confusion_path" "$TMP_DIR/benchmark_confusion_rows.original.csv"
cp "$benchmark_sha_path" "$TMP_DIR/benchmark_sha256sums.original.txt"

expect_benchmark_verify_failure() {
  local label="$1"
  local needle="$2"
  local stderr_path="$TMP_DIR/benchmark_verify_failure.stderr"
  if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>"$stderr_path"; then
    echo "$label" >&2
    exit 26
  fi
  if ! grep -F "$needle" "$stderr_path" >/dev/null; then
    echo "$label; missing verifier evidence: $needle" >&2
    cat "$stderr_path" >&2
    exit 26
  fi
}

printf '{"case_id":"fixture_case","repo_path":"%s","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","expected":"present"}\n' "$repo" >"$TMP_DIR/.env.labels"
benchmark_env_manifest_out="$TMP_DIR/benchmark_env_manifest_out"
cp -a "$TMP_DIR/benchmark_out" "$benchmark_env_manifest_out"
python3 - "$benchmark_env_manifest_out/benchmark_manifest.json" "$benchmark_env_manifest_out/benchmark_sha256sums.txt" "$TMP_DIR/.env.labels" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
env_labels = Path(sys.argv[3]).resolve()
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["labels_input"] = str(env_labels)
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{manifest_sha if rel == 'benchmark_manifest.json' else digest}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
env_manifest_stderr="$TMP_DIR/benchmark_env_manifest_verify.stderr"
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$benchmark_env_manifest_out" >/dev/null 2>"$env_manifest_stderr"; then
  echo "benchmark verifier must reject .env-like labels_input without reading it" >&2
  exit 30
fi
if ! grep -F "benchmark labels input must not be .env-like" "$env_manifest_stderr" >/dev/null; then
  echo "benchmark verifier must identify .env-like labels_input" >&2
  cat "$env_manifest_stderr" >&2
  exit 30
fi

printf 'stale benchmark artifact\n' >"$TMP_DIR/benchmark_out/stale_benchmark_artifact.txt"
expect_benchmark_verify_failure \
  "benchmark verifier must reject manifest-outside benchmark root artifacts" \
  "benchmark output contains unmanifested top-level artifact"
rm "$TMP_DIR/benchmark_out/stale_benchmark_artifact.txt"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

mkdir "$TMP_DIR/benchmark_out/case_runs/stale_case"
expect_benchmark_verify_failure \
  "benchmark verifier must reject manifest-outside case run directories" \
  "benchmark output contains unmanifested case run"
rmdir "$TMP_DIR/benchmark_out/case_runs/stale_case"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

printf 'stale case artifact\n' >"$TMP_DIR/benchmark_out/case_runs/fixture_case/latest/stale_case_artifact.txt"
expect_benchmark_verify_failure \
  "benchmark verifier must reject manifest-outside artifacts inside case audit bundles" \
  "case audit output failed verifier"
rm "$TMP_DIR/benchmark_out/case_runs/fixture_case/latest/stale_case_artifact.txt"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

printf 'preserved case note\n' >"$TMP_DIR/benchmark_out/case_runs/fixture_case/sentinel.txt"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null
rm "$TMP_DIR/benchmark_out/case_runs/fixture_case/sentinel.txt"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["release_ready"] = 1
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$benchmark_sha_path" "$benchmark_manifest_path" "benchmark_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered benchmark_manifest readiness" >&2
  exit 27
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["real_benchmark_namespace_confirmed"] = 1
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$benchmark_sha_path" "$benchmark_manifest_path" "benchmark_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
expect_benchmark_verify_failure \
  "benchmark verifier must reject synthetic namespace with real_benchmark confirmation" \
  "non-real benchmark manifest must not carry real_benchmark namespace confirmation"
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["case_runs_manifest_sha256"] = "sha256:" + ("0" * 64)
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$benchmark_sha_path" "$benchmark_manifest_path" "benchmark_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered aggregate case_runs_manifest_sha256" >&2
  exit 28
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_summary_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["release_ready"] = 1
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$benchmark_sha_path" "$benchmark_summary_path" "benchmark_summary.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered benchmark_summary readiness" >&2
  exit 29
fi
cp "$TMP_DIR/benchmark_summary.original.json" "$benchmark_summary_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_evaluation_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
evaluation_path = Path(sys.argv[3])
payload = json.loads(evaluation_path.read_text(encoding="utf-8"))
payload["schema_only_tamper"] = "unexpected"
evaluation_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
evaluation_sha = "sha256:" + hashlib.sha256(evaluation_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_evaluation.json"] = evaluation_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_evaluation.json": evaluation_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject schema-invalid benchmark evaluation JSON" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_evaluation.original.json" "$benchmark_evaluation_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_readiness_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
readiness_path = Path(sys.argv[3])
payload = json.loads(readiness_path.read_text(encoding="utf-8"))
payload["design_partner_beta_candidate_ready"] = 1
readiness_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
readiness_sha = "sha256:" + hashlib.sha256(readiness_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_readiness.json"] = readiness_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_readiness.json": readiness_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
expect_benchmark_verify_failure \
  "benchmark verifier must reject tampered benchmark_readiness beta gate" \
  "benchmark_readiness summary drift: design_partner_beta_candidate_ready"
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_readiness.original.json" "$benchmark_readiness_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_run_metrics_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
run_metrics_path = Path(sys.argv[3])
with run_metrics_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["standard_json_findings_valid"] = "0"
with run_metrics_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
run_metrics_sha = "sha256:" + hashlib.sha256(run_metrics_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_run_metrics.csv"] = run_metrics_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_run_metrics.csv": run_metrics_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered standard JSON findings run metrics" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_run_metrics.original.csv" "$benchmark_run_metrics_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_repo_snapshot_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
snapshot_path = Path(sys.argv[3])
with snapshot_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["repo_snapshot_locked"] = "0"
with snapshot_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
snapshot_sha = "sha256:" + hashlib.sha256(snapshot_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_repo_snapshots.csv"] = snapshot_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_repo_snapshots.csv": snapshot_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered repo snapshot rows" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_repo_snapshots.original.csv" "$benchmark_repo_snapshot_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_labels_json_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
labels_path = Path(sys.argv[3])
payload = json.loads(labels_path.read_text(encoding="utf-8"))
payload["rows"][0]["outcome"] = "FN"
labels_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
labels_sha = "sha256:" + hashlib.sha256(labels_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_labels.json"] = labels_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_labels.json": labels_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered benchmark labels JSON" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_labels.original.json" "$benchmark_labels_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_labels_csv_path" "$benchmark_labels_json_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
csv_path = Path(sys.argv[3])
json_path = Path(sys.argv[4])
with csv_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["outcome"] = "FN"
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(json_path.read_text(encoding="utf-8"))
payload["rows"] = rows
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
csv_sha = "sha256:" + hashlib.sha256(csv_path.read_bytes()).hexdigest()
json_sha = "sha256:" + hashlib.sha256(json_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_labels.csv"] = csv_sha
manifest["artifact_sha256s"]["benchmark_labels.json"] = json_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_labels.csv": csv_sha.split(":", 1)[1],
    "benchmark_labels.json": json_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject coordinated benchmark labels CSV/JSON drift" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_labels.original.csv" "$benchmark_labels_csv_path"
cp "$TMP_DIR/benchmark_labels.original.json" "$benchmark_labels_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_labels_csv_path" "$benchmark_labels_json_path" "$benchmark_summary_path" "$benchmark_readiness_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
csv_path = Path(sys.argv[3])
json_path = Path(sys.argv[4])
summary_path = Path(sys.argv[5])
readiness_path = Path(sys.argv[6])
with csv_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["source_candidate_label_id"] = ""
rows[0]["source_review_queue_id"] = ""
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(json_path.read_text(encoding="utf-8"))
payload["rows"] = rows
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
summary = json.loads(summary_path.read_text(encoding="utf-8"))
summary["label_source_trace_rows"] = 0
summary["label_source_trace_missing_rows"] = len(rows)
summary["label_source_trace_requirement_met"] = 0
summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
readiness = json.loads(readiness_path.read_text(encoding="utf-8"))
for row in readiness["rows"]:
    if row["gate_id"] == "label_source_trace_requirement_met":
        row["observed"] = "0"
readiness_path.write_text(json.dumps(readiness, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
updates = {
    "benchmark_labels.csv": hashlib.sha256(csv_path.read_bytes()).hexdigest(),
    "benchmark_labels.json": hashlib.sha256(json_path.read_bytes()).hexdigest(),
    "benchmark_summary.json": hashlib.sha256(summary_path.read_bytes()).hexdigest(),
    "benchmark_readiness.json": hashlib.sha256(readiness_path.read_bytes()).hexdigest(),
}
for rel, digest in updates.items():
    manifest["artifact_sha256s"][rel] = "sha256:" + digest
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates["benchmark_manifest.json"] = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
expect_benchmark_verify_failure \
  "benchmark verifier must reject coordinated label source trace drift" \
  "benchmark label rows drift from case audit outputs"
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_summary.original.json" "$benchmark_summary_path"
cp "$TMP_DIR/benchmark_readiness.original.json" "$benchmark_readiness_path"
cp "$TMP_DIR/benchmark_labels.original.csv" "$benchmark_labels_csv_path"
cp "$TMP_DIR/benchmark_labels.original.json" "$benchmark_labels_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_label_citation_json_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
payload_path = Path(sys.argv[3])
payload = json.loads(payload_path.read_text(encoding="utf-8"))
payload["rows"][0]["citation_expectation_met"] = "0"
payload_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
payload_sha = "sha256:" + hashlib.sha256(payload_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_label_citation_expectations.json"] = payload_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_label_citation_expectations.json": payload_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered label citation expectations JSON" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_label_citation_expectations.original.json" "$benchmark_label_citation_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_label_citation_csv_path" "$benchmark_label_citation_json_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
csv_path = Path(sys.argv[3])
json_path = Path(sys.argv[4])
with csv_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["citation_expectation_met"] = "0"
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(json_path.read_text(encoding="utf-8"))
payload["rows"] = rows
payload["citation_expectation_met_rows"] = sum(1 for row in rows if row["citation_expectation_met"] == "1")
payload["label_citation_expectation_requirement_met"] = 0
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
csv_sha = "sha256:" + hashlib.sha256(csv_path.read_bytes()).hexdigest()
json_sha = "sha256:" + hashlib.sha256(json_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_label_citation_expectations.csv"] = csv_sha
manifest["artifact_sha256s"]["benchmark_label_citation_expectations.json"] = json_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_label_citation_expectations.csv": csv_sha.split(":", 1)[1],
    "benchmark_label_citation_expectations.json": json_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject coordinated label citation expectations CSV/JSON drift" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_label_citation_expectations.original.csv" "$benchmark_label_citation_csv_path"
cp "$TMP_DIR/benchmark_label_citation_expectations.original.json" "$benchmark_label_citation_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_findings_json_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
findings_path = Path(sys.argv[3])
payload = json.loads(findings_path.read_text(encoding="utf-8"))
payload["rows"][0]["plugin_id"] = "tampered_plugin"
findings_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
findings_sha = "sha256:" + hashlib.sha256(findings_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_findings.json"] = findings_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_findings.json": findings_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered benchmark findings JSON" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_findings.original.json" "$benchmark_findings_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_findings_csv_path" "$benchmark_findings_json_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
csv_path = Path(sys.argv[3])
json_path = Path(sys.argv[4])
with csv_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["severity"] = "critical"
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(json_path.read_text(encoding="utf-8"))
payload["rows"][0]["severity"] = "critical"
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
csv_sha = "sha256:" + hashlib.sha256(csv_path.read_bytes()).hexdigest()
json_sha = "sha256:" + hashlib.sha256(json_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_findings.csv"] = csv_sha
manifest["artifact_sha256s"]["benchmark_findings.json"] = json_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_findings.csv": csv_sha.split(":", 1)[1],
    "benchmark_findings.json": json_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject coordinated invalid benchmark finding rows" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_findings.original.csv" "$benchmark_findings_csv_path"
cp "$TMP_DIR/benchmark_findings.original.json" "$benchmark_findings_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_findings_csv_path" "$benchmark_findings_json_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
csv_path = Path(sys.argv[3])
json_path = Path(sys.argv[4])
with csv_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["plugin_id"] = "schema_valid_tamper"
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(json_path.read_text(encoding="utf-8"))
payload["rows"][0]["plugin_id"] = "schema_valid_tamper"
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
csv_sha = "sha256:" + hashlib.sha256(csv_path.read_bytes()).hexdigest()
json_sha = "sha256:" + hashlib.sha256(json_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_findings.csv"] = csv_sha
manifest["artifact_sha256s"]["benchmark_findings.json"] = json_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_findings.csv": csv_sha.split(":", 1)[1],
    "benchmark_findings.json": json_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject schema-valid benchmark finding drift from case runs" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_findings.original.csv" "$benchmark_findings_csv_path"
cp "$TMP_DIR/benchmark_findings.original.json" "$benchmark_findings_json_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_evaluation_path" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
evaluation_path = Path(sys.argv[3])
payload = json.loads(evaluation_path.read_text(encoding="utf-8"))
payload["confusion"][0]["outcome"] = "FN"
evaluation_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
evaluation_sha = "sha256:" + hashlib.sha256(evaluation_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_evaluation.json"] = evaluation_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_evaluation.json": evaluation_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject tampered benchmark evaluation JSON" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_evaluation.original.json" "$benchmark_evaluation_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

python3 - "$benchmark_manifest_path" "$benchmark_sha_path" "$benchmark_confusion_path" "$benchmark_evaluation_path" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sha_path = Path(sys.argv[2])
confusion_path = Path(sys.argv[3])
evaluation_path = Path(sys.argv[4])
with confusion_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["outcome"] = "FN"
rows[0]["tp"] = "0"
rows[0]["fn"] = "1"
with confusion_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(evaluation_path.read_text(encoding="utf-8"))
payload["confusion"] = rows
evaluation_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
confusion_sha = "sha256:" + hashlib.sha256(confusion_path.read_bytes()).hexdigest()
evaluation_sha = "sha256:" + hashlib.sha256(evaluation_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_confusion_rows.csv"] = confusion_sha
manifest["artifact_sha256s"]["benchmark_evaluation.json"] = evaluation_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_confusion_rows.csv": confusion_sha.split(":", 1)[1],
    "benchmark_evaluation.json": evaluation_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject coordinated benchmark evaluation/CSV drift" >&2
  exit 30
fi
cp "$TMP_DIR/benchmark_manifest.original.json" "$benchmark_manifest_path"
cp "$TMP_DIR/benchmark_confusion_rows.original.csv" "$benchmark_confusion_path"
cp "$TMP_DIR/benchmark_evaluation.original.json" "$benchmark_evaluation_path"
cp "$TMP_DIR/benchmark_sha256sums.original.txt" "$benchmark_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_out" >/dev/null

cat >"$TMP_DIR/benchmark_bad_case_id_labels.jsonl" <<EOF
{"case_id":"../escape","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_bad_case_id_labels.jsonl" \
  --out "$TMP_DIR/benchmark_bad_case_id_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
bad_case_id_rc="$?"
set -e
if [[ "$bad_case_id_rc" -ne 2 ]]; then
  echo "benchmark harness must reject path-like case_id values" >&2
  exit 30
fi
cat >"$TMP_DIR/benchmark_partial_citation_labels.jsonl" <<EOF
{"case_id":"partial_citation_case","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_partial_citation_labels.jsonl" \
  --out "$TMP_DIR/benchmark_partial_citation_out" \
  --mode quick \
  --namespace synthetic >/dev/null 2>&1
partial_citation_rc="$?"
set -e
if [[ "$partial_citation_rc" -ne 2 ]]; then
  echo "benchmark harness must reject partial expected citation inputs" >&2
  exit 30
fi
if [[ -e "$TMP_DIR/benchmark_partial_citation_out/benchmark_manifest.json" ]] || [[ -e "$TMP_DIR/benchmark_partial_citation_out/benchmark_summary.json" ]]; then
  echo "partial citation input rejection must not expose benchmark artifacts" >&2
  exit 30
fi
cat >"$TMP_DIR/benchmark_bad_citation_digest_labels.jsonl" <<EOF
{"case_id":"bad_citation_digest_case","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_span_sha256":"not-a-sha","expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_bad_citation_digest_labels.jsonl" \
  --out "$TMP_DIR/benchmark_bad_citation_digest_out" \
  --mode quick \
  --namespace synthetic >/dev/null 2>&1
bad_citation_digest_rc="$?"
set -e
if [[ "$bad_citation_digest_rc" -ne 2 ]]; then
  echo "benchmark harness must reject malformed expected citation digests" >&2
  exit 30
fi
cat >"$TMP_DIR/benchmark_bad_priority_labels.jsonl" <<EOF
{"case_id":"bad_priority_case","repo_path":"$repo","human_labeled":true,"synthetic":false,"priority":"urgent","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_bad_priority_labels.jsonl" \
  --out "$TMP_DIR/benchmark_bad_priority_out" \
  --mode quick \
  --namespace synthetic >/dev/null 2>&1
bad_priority_rc="$?"
set -e
if [[ "$bad_priority_rc" -ne 2 ]]; then
  echo "benchmark harness must reject malformed human-label priority values" >&2
  exit 30
fi
if [[ -e "$TMP_DIR/benchmark_bad_priority_out/benchmark_manifest.json" ]] || [[ -e "$TMP_DIR/benchmark_bad_priority_out/benchmark_summary.json" ]]; then
  echo "bad priority input rejection must not expose benchmark artifacts" >&2
  exit 30
fi
cat >"$TMP_DIR/benchmark_bad_label_quality.jsonl" <<EOF
{"case_id":"quality_bad","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","expected":"present"}
{"case_id":"quality_bad","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
{"case_id":"quality_bad","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
{"case_id":"quality_bad","repo_path":"$repo","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"absent"}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_bad_label_quality.jsonl" \
  --out "$TMP_DIR/benchmark_bad_label_quality_out" \
  --mode full \
  --namespace synthetic >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_summary.schema.json" "$TMP_DIR/benchmark_bad_label_quality_out/benchmark_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json" "$TMP_DIR/benchmark_bad_label_quality_out/benchmark_label_citation_expectations.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_bad_label_quality_out" >/dev/null
python3 - "$TMP_DIR/benchmark_bad_label_quality_out" <<'PY'
import csv
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
label_citation_payload = json.loads((out / "benchmark_label_citation_expectations.json").read_text(encoding="utf-8"))
with (out / "benchmark_label_quality.csv").open(newline="", encoding="utf-8") as handle:
    quality_rows = list(csv.DictReader(handle))
with (out / "benchmark_label_citation_expectations.csv").open(newline="", encoding="utf-8") as handle:
    label_citation_rows = list(csv.DictReader(handle))
with (out / "benchmark_repo_snapshots.csv").open(newline="", encoding="utf-8") as handle:
    snapshot_rows = list(csv.DictReader(handle))
if summary["label_quality_total_rows"] != 4 or len(quality_rows) != 4:
    raise SystemExit("bad label quality benchmark must record all label rows")
if summary["label_quality_broad_rows"] != 1 or summary["label_quality_citation_unbound_rows"] != 3:
    raise SystemExit("bad label quality benchmark must record broad and citation-unbound labels")
if summary["label_quality_duplicate_rows"] != 1:
    raise SystemExit("bad label quality benchmark must record duplicate label rows")
if summary["label_quality_contradictory_rows"] < 2:
    raise SystemExit("bad label quality benchmark must record contradictory label rows")
if summary["label_quality_specific_rows"] != 3:
    raise SystemExit("bad label quality benchmark must still count specific label rows separately")
if summary["label_quality_requirement_met"] != 0:
    raise SystemExit("bad label quality benchmark must fail label quality requirement")
if summary["label_citation_expectation_rows"] != 0 or summary["label_citation_expectation_met_rows"] != 0 or summary["label_citation_expectation_requirement_met"] != 0:
    raise SystemExit("bad label quality benchmark must keep citation expectation requirement unmet without supplied spans")
if len(label_citation_rows) != 4:
    raise SystemExit("benchmark_label_citation_expectations.csv must include one row per bad label")
if label_citation_payload["rows"] != label_citation_rows or label_citation_payload["label_rows"] != 4:
    raise SystemExit("bad label quality citation JSON must match citation CSV rows")
if label_citation_payload["citation_expectation_rows"] != 0 or label_citation_payload["citation_expectation_met_rows"] != 0:
    raise SystemExit("bad label quality citation JSON must record zero supplied expectations")
if any(row["citation_expectation_supplied"] != "0" or row["citation_expectation_met"] for row in label_citation_rows):
    raise SystemExit("bad label quality citation rows must record unbound labels without false failures")
if len(snapshot_rows) != 1 or snapshot_rows[0]["repo_snapshot_missing_expectation"] != "1" or snapshot_rows[0]["repo_snapshot_locked"] != "0":
    raise SystemExit("benchmark repo snapshot must record missing expected HEAD as unlocked")
if summary["repo_snapshot_missing_expectation_rows"] != 1 or summary["repo_snapshot_locked_rows"] != 0 or summary["repo_snapshot_requirement_met"] != 0:
    raise SystemExit("benchmark summary must block snapshot requirement without expected HEAD")
if summary["design_partner_beta_candidate_ready"] != 0 or summary["release_ready"] != 0 or summary["public_comparison_claim_ready"] != 0 or summary["real_model_execution_ready"] != 0:
    raise SystemExit("bad label quality benchmark must not set readiness flags")
if sum(int(row["is_broad"]) for row in quality_rows) != summary["label_quality_broad_rows"]:
    raise SystemExit("benchmark_label_quality.csv broad row count must match summary")
if sum(int(row["is_duplicate"]) for row in quality_rows) != summary["label_quality_duplicate_rows"]:
    raise SystemExit("benchmark_label_quality.csv duplicate row count must match summary")
if sum(int(row["is_contradictory"]) for row in quality_rows) != summary["label_quality_contradictory_rows"]:
    raise SystemExit("benchmark_label_quality.csv contradictory row count must match summary")
PY
printf 'legacy.py\n' >"$TMP_DIR/benchmark_changed_files.txt"
cat >"$TMP_DIR/benchmark_changed_scope_labels.jsonl" <<EOF
{"case_id":"changed_scope_case","repo_path":"$repo","changed_files_from":"$TMP_DIR/benchmark_changed_files.txt","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_line_end":1,"expected_span_sha256":"$legacy_py_line1_span_sha","expected":"present","expected_abstain":false}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_changed_scope_labels.jsonl" \
  --out "$TMP_DIR/benchmark_changed_scope_out" \
  --mode full \
  --namespace synthetic >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_manifest.schema.json" "$TMP_DIR/benchmark_changed_scope_out/benchmark_manifest.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_summary.schema.json" "$TMP_DIR/benchmark_changed_scope_out/benchmark_summary.json" >/dev/null
python3 - "$TMP_DIR/benchmark_changed_scope_out" "$TMP_DIR/benchmark_changed_files.txt" <<'PY'
import csv
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
changed_files = str(Path(sys.argv[2]).resolve())
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
with (out / "benchmark_run_metrics.csv").open(newline="", encoding="utf-8") as handle:
    run_metrics = list(csv.DictReader(handle))
with (out / "case_runs" / "changed_scope_case" / "source_manifest.csv").open(newline="", encoding="utf-8") as handle:
    source_rows = list(csv.DictReader(handle))
if summary["tp"] != 1 or summary["fn"] != 0:
    raise SystemExit("changed-scope benchmark must score the scoped human label")
if summary["changed_file_scope_case_rows"] != 1 or summary["tracked_scope_case_rows"] != 0:
    raise SystemExit("changed-scope benchmark must count changed-file cases separately")
if summary["repo_snapshot_rows"] != 1 or summary["repo_snapshot_locked_rows"] != 1:
    raise SystemExit("changed-scope benchmark must preserve repo snapshot locking")
if len(run_metrics) != 1:
    raise SystemExit("changed-scope benchmark must emit one run metric row")
row = run_metrics[0]
if row["source_scope"] != "changed-files":
    raise SystemExit("changed-scope benchmark run metrics must bind source_scope=changed-files")
if row["changed_files_from"] != changed_files:
    raise SystemExit("changed-scope benchmark must bind changed_files_from")
if not row["changed_files_from_sha256"].startswith("sha256:") or row["changed_file_rows"] != "1":
    raise SystemExit("changed-scope benchmark must bind changed file input sha and row count")
if row["source_file_count"] != "1" or [source["file_path"] for source in source_rows] != ["legacy.py"]:
    raise SystemExit("changed-scope benchmark must only scan the requested changed source")
for key in ["rerun_checked", "rerun_success", "rerun_cache_key_match", "rerun_semantic_result_match"]:
    if row[key] != "1":
        raise SystemExit(f"changed-scope benchmark must keep rerun metric {key}=1")
PY
printf 'README.md\n' >"$TMP_DIR/benchmark_changed_files_other.txt"
cat >"$TMP_DIR/benchmark_conflicting_changed_scope_labels.jsonl" <<EOF
{"case_id":"conflicting_changed_scope","repo_path":"$repo","changed_files_from":"$TMP_DIR/benchmark_changed_files.txt","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
{"case_id":"conflicting_changed_scope","repo_path":"$repo","changed_files_from":"$TMP_DIR/benchmark_changed_files_other.txt","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"plugin_id":"unsupported_claim","rule_id":"unsupported-claim-readiness-capability-wording","file_path":"README.md","expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_conflicting_changed_scope_labels.jsonl" \
  --out "$TMP_DIR/benchmark_conflicting_changed_scope_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
conflicting_changed_scope_rc="$?"
set -e
if [[ "$conflicting_changed_scope_rc" -ne 2 ]]; then
  echo "benchmark harness must reject conflicting changed_files_from values within one case" >&2
  exit 26
fi
python3 - "$TMP_DIR/benchmark_out/case_runs/fixture_case" "$repo" <<'PY'
import csv
import shutil
import sys
from pathlib import Path

root = Path.cwd()
sys.path.insert(0, str(root / "scripts"))
from audit_my_repo_benchmark import citation_validity_rows

source = Path(sys.argv[1])
repo = Path(sys.argv[2])
tampered = source.parent / "fixture_case_tampered_citation"
if tampered.exists():
    shutil.rmtree(tampered)
shutil.copytree(source, tampered, symlinks=True)
path = tampered / "citation_spans.csv"
with path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
rows[0]["span_sha256"] = "sha256:" + ("0" * 64)
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
validity = citation_validity_rows({"case_id": "fixture_case", "repo_path": str(repo)}, tampered)
if all(row["citation_valid"] == 1 for row in validity):
    raise SystemExit("benchmark citation validity must reject tampered span sha")
if not any("span_sha256_mismatch" in row["invalid_reasons"] for row in validity):
    raise SystemExit("benchmark citation validity must report span_sha256_mismatch")
PY
cat >"$TMP_DIR/synthetic_benchmark_labels.jsonl" <<EOF
{"case_id":"synthetic_case","repo_path":"$repo","human_labeled":true,"synthetic":true,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/synthetic_benchmark_labels.jsonl" \
  --out "$TMP_DIR/synthetic_benchmark_out" \
  --mode full \
  --namespace real_benchmark >/dev/null 2>&1
synthetic_benchmark_unconfirmed_rc="$?"
set -e
if [[ "$synthetic_benchmark_unconfirmed_rc" -ne 2 ]]; then
  echo "benchmark harness must require explicit confirmation for real_benchmark namespace" >&2
  exit 16
fi
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/synthetic_benchmark_labels.jsonl" \
  --out "$TMP_DIR/synthetic_benchmark_out" \
  --mode full \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace >/dev/null 2>&1
synthetic_benchmark_rc="$?"
set -e
if [[ "$synthetic_benchmark_rc" -ne 2 ]]; then
  echo "benchmark harness must reject synthetic cases in confirmed real_benchmark namespace" >&2
  exit 16
fi
printf '{"case_id":"fixture_case","repo_path":"%s","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","expected":"present"}\n' "$repo" >"$TMP_DIR/.env.labels"
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/.env.labels" \
  --out "$TMP_DIR/env_labels_benchmark_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
env_labels_rc="$?"
set -e
if [[ "$env_labels_rc" -ne 2 ]]; then
  echo "benchmark harness must reject .env-like label input before reading it" >&2
  exit 16
fi
if [[ -e "$TMP_DIR/env_labels_benchmark_out/benchmark_manifest.json" ]] || [[ -e "$TMP_DIR/env_labels_benchmark_out/benchmark_summary.json" ]]; then
  echo ".env-like label input rejection must not expose benchmark artifacts" >&2
  exit 16
fi
printf '{"case_id":"fixture_case","maintainer_id":"maintainer-one","human_feedback":true,"feedback_text":"fixture feedback"}\n' >"$TMP_DIR/.env.feedback"
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_labels.jsonl" \
  --feedback "$TMP_DIR/.env.feedback" \
  --out "$TMP_DIR/env_feedback_benchmark_out" \
  --mode full \
  --namespace synthetic >/dev/null 2>&1
env_feedback_rc="$?"
set -e
if [[ "$env_feedback_rc" -ne 2 ]]; then
  echo "benchmark harness must reject .env-like feedback input" >&2
  exit 16
fi

cat >"$TMP_DIR/benchmark_bad_repo_head_labels.jsonl" <<EOF
{"case_id":"bad_repo_head","repo_path":"$repo","expected_repo_git_head":"not-a-sha","human_labeled":true,"synthetic":false,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected":"present"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_bad_repo_head_labels.jsonl" \
  --out "$TMP_DIR/benchmark_bad_repo_head_out" \
  --mode quick \
  --namespace synthetic >/dev/null 2>&1
bad_repo_head_rc="$?"
set -e
if [[ "$bad_repo_head_rc" -ne 2 ]]; then
  echo "benchmark harness must reject malformed expected_repo_git_head values" >&2
  exit 16
fi

cat >"$TMP_DIR/benchmark_mismatched_repo_head_labels.jsonl" <<EOF
{"case_id":"mismatched_repo_head","repo_path":"$repo","expected_repo_git_head":"0000000000000000000000000000000000000000","human_labeled":true,"synthetic":false,"priority":"P1","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_line_end":1,"expected_span_sha256":"$legacy_py_line1_span_sha","expected":"present","expected_abstain":false}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_mismatched_repo_head_labels.jsonl" \
  --out "$TMP_DIR/benchmark_mismatched_repo_head_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_mismatched_repo_head_out" >/dev/null
python3 - "$TMP_DIR/benchmark_mismatched_repo_head_out" <<'PY'
import csv
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
with (out / "benchmark_repo_snapshots.csv").open(newline="", encoding="utf-8") as handle:
    snapshots = list(csv.DictReader(handle))
if len(snapshots) != 1:
    raise SystemExit("mismatched repo head benchmark must emit one snapshot row")
snapshot = snapshots[0]
if snapshot["expected_repo_git_head_match"] != "0" or snapshot["repo_snapshot_mismatch"] != "1" or snapshot["repo_snapshot_locked"] != "0":
    raise SystemExit("mismatched repo head benchmark must record an unlocked snapshot mismatch")
if summary["product_readiness_calculated_from_real_labels"] != 1:
    raise SystemExit("mismatched repo head benchmark must still identify real human-label basis")
if summary["repo_snapshot_rows"] != 1 or summary["repo_snapshot_locked_rows"] != 0 or summary["repo_snapshot_mismatch_rows"] != 1 or summary["repo_snapshot_requirement_met"] != 0:
    raise SystemExit("mismatched repo head benchmark must block repo snapshot requirement")
if summary["design_partner_beta_candidate_ready"] != 0:
    raise SystemExit("mismatched repo head benchmark must not become beta candidate ready")
PY
printf 'dirty snapshot sentinel\n' >"$repo/DIRTY_SNAPSHOT_ONLY.txt"
cat >"$TMP_DIR/benchmark_dirty_repo_labels.jsonl" <<EOF
{"case_id":"dirty_repo_head","repo_path":"$repo","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_line_end":1,"expected_span_sha256":"$legacy_py_line1_span_sha","expected":"present","expected_abstain":false}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/benchmark_dirty_repo_labels.jsonl" \
  --out "$TMP_DIR/benchmark_dirty_repo_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/benchmark_dirty_repo_out" >/dev/null
python3 - "$TMP_DIR/benchmark_dirty_repo_out" <<'PY'
import csv
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
snapshot_text = (out / "benchmark_repo_snapshots.csv").read_text(encoding="utf-8")
with (out / "benchmark_repo_snapshots.csv").open(newline="", encoding="utf-8") as handle:
    snapshots = list(csv.DictReader(handle))
if "DIRTY_SNAPSHOT_ONLY" in snapshot_text:
    raise SystemExit("benchmark repo snapshot must not emit raw dirty status path names")
if len(snapshots) != 1:
    raise SystemExit("dirty repo benchmark must emit one snapshot row")
snapshot = snapshots[0]
if snapshot["repo_git_dirty"] != "1" or snapshot["repo_snapshot_locked"] != "0":
    raise SystemExit("dirty repo benchmark must record dirty worktree as unlocked")
if snapshot["expected_repo_git_head_match"] != "1" or snapshot["repo_snapshot_mismatch"] != "0":
    raise SystemExit("dirty repo benchmark must distinguish dirty state from expected HEAD mismatch")
if "repo_dirty" not in snapshot["repo_snapshot_problems"]:
    raise SystemExit("dirty repo benchmark must record repo_dirty problem")
if summary["repo_snapshot_dirty_rows"] != 1 or summary["repo_snapshot_locked_rows"] != 0 or summary["repo_snapshot_requirement_met"] != 0:
    raise SystemExit("dirty repo benchmark must block repo snapshot requirement")
if summary["design_partner_beta_candidate_ready"] != 0:
    raise SystemExit("dirty repo benchmark must not become beta candidate ready")
PY
rm "$repo/DIRTY_SNAPSHOT_ONLY.txt"

legacy_py_line_sha="$(python3 - "$repo/legacy.py" <<'PY'
import hashlib
import sys
from pathlib import Path

line = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()[0].strip()
print("sha256:" + hashlib.sha256(line.encode("utf-8")).hexdigest())
PY
)"
readme_claim_line_sha="$(python3 - "$repo/README.md" <<'PY'
import hashlib
import sys
from pathlib import Path

line = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()[2].strip()
print("sha256:" + hashlib.sha256(line.encode("utf-8")).hexdigest())
PY
)"
cat >"$TMP_DIR/real_benchmark_small_labels.jsonl" <<EOF
{"case_id":"real_small_case","repo_path":"$repo","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","maintainer_id":"maintainer-one","maintainer_feedback":true,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_line_end":1,"expected_span_sha256":"$legacy_py_line_sha","expected":"present","expected_abstain":false}
{"case_id":"real_small_case","repo_path":"$repo","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P2","maintainer_id":"maintainer-one","maintainer_feedback":true,"plugin_id":"unsupported_claim","rule_id":"unsupported-claim-readiness-capability-wording","file_path":"README.md","expected_line_start":3,"expected_line_end":3,"expected_span_sha256":"$readme_claim_line_sha","expected":"present"}
EOF
cat >"$TMP_DIR/real_benchmark_small_feedback.jsonl" <<EOF
{"feedback_id":"fb-one","case_id":"real_small_case","maintainer_id":"maintainer-one","human_feedback":true,"synthetic":false,"feedback_text":"Fixture maintainer reviewed the source-bound finding set and requested clearer triage notes."}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/real_benchmark_small_labels.jsonl" \
  --feedback "$TMP_DIR/real_benchmark_small_feedback.jsonl" \
  --out "$TMP_DIR/real_benchmark_small_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_manifest.schema.json" "$TMP_DIR/real_benchmark_small_out/benchmark_manifest.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_summary.schema.json" "$TMP_DIR/real_benchmark_small_out/benchmark_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_readiness.schema.json" "$TMP_DIR/real_benchmark_small_out/benchmark_readiness.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json" "$TMP_DIR/real_benchmark_small_out/benchmark_label_citation_expectations.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_maintainer_feedback.schema.json" "$TMP_DIR/real_benchmark_small_out/benchmark_maintainer_feedback.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/real_benchmark_small_out" >/dev/null
python3 - "$TMP_DIR/real_benchmark_small_out/benchmark_summary.json" "$TMP_DIR/real_benchmark_small_out/benchmark_maintainer_feedback.csv" "$TMP_DIR/real_benchmark_small_feedback.jsonl" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
label_citation_payload = json.loads((Path(sys.argv[1]).parent / "benchmark_label_citation_expectations.json").read_text(encoding="utf-8"))
readiness_payload = json.loads((Path(sys.argv[1]).parent / "benchmark_readiness.json").read_text(encoding="utf-8"))
manifest = json.loads((Path(sys.argv[1]).parent / "benchmark_manifest.json").read_text(encoding="utf-8"))
with Path(sys.argv[2]).open(newline="", encoding="utf-8") as handle:
    feedback_rows = list(csv.DictReader(handle))
with (Path(sys.argv[1]).parent / "benchmark_repo_snapshots.csv").open(newline="", encoding="utf-8") as handle:
    repo_snapshot_rows = list(csv.DictReader(handle))
feedback_input = Path(sys.argv[3])
if manifest["namespace"] != "real_benchmark" or manifest["real_benchmark_namespace_confirmed"] != 1:
    raise SystemExit("real benchmark manifest must bind explicit namespace confirmation")
if summary["product_readiness_calculated_from_real_labels"] != 1:
    raise SystemExit("real_benchmark human labels must enable readiness calculation basis")
if summary["label_quality_total_rows"] != 2 or summary["label_quality_specific_rows"] != 2:
    raise SystemExit("real_benchmark summary must record specific label quality rows")
if summary["label_quality_broad_rows"] != 0 or summary["label_quality_duplicate_rows"] != 0 or summary["label_quality_contradictory_rows"] != 0:
    raise SystemExit("real_benchmark specific labels must not record label quality defects")
if summary["label_quality_requirement_met"] != 1:
    raise SystemExit("real_benchmark specific labels must satisfy label quality requirement")
if summary["label_source_trace_rows"] != 0 or summary["label_source_trace_missing_rows"] != 2 or summary["label_source_trace_requirement_met"] != 0:
    raise SystemExit("real_benchmark direct labels without review queue trace must fail source trace sub-gate")
if summary["label_citation_expectation_rows"] != 2 or summary["label_citation_expectation_met_rows"] != 2 or summary["label_citation_expectation_requirement_met"] != 1:
    raise SystemExit("real_benchmark with exact human citation spans must satisfy citation expectation sub-gate")
if label_citation_payload["citation_expectation_rows"] != 2 or label_citation_payload["citation_expectation_met_rows"] != 2:
    raise SystemExit("real_benchmark citation expectation JSON must bind exact matched spans")
if summary["design_partner_beta_candidate_ready"] != 0:
    raise SystemExit("undersized real_benchmark must not be beta candidate ready")
if readiness_payload["product_readiness_calculated_from_real_labels"] != 1 or readiness_payload["design_partner_beta_candidate_ready"] != 0:
    raise SystemExit("real_benchmark readiness JSON must bind real-label basis and blocked beta candidate state")
if readiness_payload["release_ready"] != 0 or readiness_payload["public_comparison_claim_ready"] != 0 or readiness_payload["real_model_execution_ready"] != 0:
    raise SystemExit("real_benchmark readiness JSON must keep release/model claims blocked")
readiness_by_gate = {row["gate_id"]: row for row in readiness_payload["rows"]}
for gate_id in ["real_repo_requirement_met", "human_label_requirement_met", "label_source_trace_requirement_met", "maintainer_feedback_requirement_met"]:
    if readiness_by_gate[gate_id]["passed"] != 0 or not readiness_by_gate[gate_id]["blocked_reason"]:
        raise SystemExit(f"undersized real_benchmark readiness JSON must block gate: {gate_id}")
for gate_id in ["repo_snapshot_requirement_met", "label_quality_requirement_met", "label_citation_expectation_requirement_met"]:
    if readiness_by_gate[gate_id]["passed"] != 1 or readiness_by_gate[gate_id]["blocked_reason"]:
        raise SystemExit(f"real_benchmark readiness JSON must pass satisfied sub-gate: {gate_id}")
if summary["real_repo_count"] != 1 or summary["real_repo_requirement_met"] != 0:
    raise SystemExit("beta gate must require at least 10 real repositories")
if summary["human_label_rows"] != 2 or summary["human_label_requirement_met"] != 0:
    raise SystemExit("beta gate must require at least 300 human labels")
if len(repo_snapshot_rows) != 1 or repo_snapshot_rows[0]["repo_snapshot_locked"] != "1":
    raise SystemExit("real benchmark must record a locked repo snapshot row")
if summary["repo_snapshot_rows"] != 1 or summary["repo_snapshot_locked_rows"] != 1 or summary["repo_snapshot_requirement_met"] != 1:
    raise SystemExit("real benchmark with expected clean HEAD must satisfy repo snapshot sub-gate")
if summary["maintainer_feedback_count"] != 1 or summary["maintainer_feedback_rows"] != 1 or summary["maintainer_feedback_case_rows"] != 1 or summary["maintainer_feedback_requirement_met"] != 0:
    raise SystemExit("beta gate must require at least three maintainer feedback sources")
if summary["maintainer_feedback_input_supplied"] != 1:
    raise SystemExit("real benchmark summary must record supplied maintainer feedback input")
if summary["maintainer_feedback_input_sha256"] != "sha256:" + hashlib.sha256(feedback_input.read_bytes()).hexdigest():
    raise SystemExit("real benchmark summary must bind maintainer feedback input sha")
if len(feedback_rows) != 1:
    raise SystemExit("benchmark_maintainer_feedback.csv must emit one feedback evidence row")
feedback_row = feedback_rows[0]
if feedback_row["counts_for_beta"] != "1" or feedback_row["human_feedback"] != "1" or feedback_row["synthetic"] != "0":
    raise SystemExit("maintainer feedback row must count only real human feedback")
if "Fixture maintainer" in json.dumps(feedback_row, sort_keys=True):
    raise SystemExit("maintainer feedback output must not emit raw feedback text")
if not feedback_row["feedback_text_sha256"].startswith("sha256:") or int(feedback_row["feedback_text_bytes"]) <= 0:
    raise SystemExit("maintainer feedback output must bind feedback text by sha and byte count")
if summary["overall_precision_requirement_met"] != 1 or summary["p0_p1_precision_requirement_met"] != 1:
    raise SystemExit("undersized real benchmark should still report satisfied precision sub-gates")
if summary["citation_validity_requirement_met"] != 1 or summary["install_success_requirement_met"] != 1 or summary["first_report_requirement_met"] != 1:
    raise SystemExit("undersized real benchmark should report satisfied local execution/citation sub-gates")
if summary["standard_json_findings_checked_rows"] != 1 or summary["standard_json_findings_valid_rows"] != 1 or summary["standard_json_findings_requirement_met"] != 1:
    raise SystemExit("undersized real benchmark should report satisfied standard JSON findings sub-gate")
if summary["rerun_requirement_met"] != 0:
    raise SystemExit("--no-rerun-check must keep rerun beta gate unmet")
if summary["release_ready"] != 0 or summary["public_comparison_claim_ready"] != 0 or summary["real_model_execution_ready"] != 0:
    raise SystemExit("real benchmark summary must keep release/comparison/model flags false")
PY

cat >"$TMP_DIR/duplicate_feedback_id.jsonl" <<EOF
{"feedback_id":"fb-duplicate","case_id":"real_small_case","maintainer_id":"maintainer-one","human_feedback":true,"synthetic":false,"feedback_text":"First duplicate feedback row."}
{"feedback_id":"fb-duplicate","case_id":"real_small_case","maintainer_id":"maintainer-two","human_feedback":true,"synthetic":false,"feedback_text":"Second duplicate feedback row."}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/real_benchmark_small_labels.jsonl" \
  --feedback "$TMP_DIR/duplicate_feedback_id.jsonl" \
  --out "$TMP_DIR/duplicate_feedback_id_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null 2>&1
duplicate_feedback_id_rc="$?"
set -e
if [[ "$duplicate_feedback_id_rc" -ne 2 ]]; then
  echo "benchmark harness must reject duplicate maintainer feedback ids" >&2
  exit 16
fi
cat >"$TMP_DIR/unsafe_feedback_id.jsonl" <<EOF
{"feedback_id":"bad/id","case_id":"real_small_case","maintainer_id":"maintainer-one","human_feedback":true,"synthetic":false,"feedback_text":"Unsafe feedback id must be rejected."}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/real_benchmark_small_labels.jsonl" \
  --feedback "$TMP_DIR/unsafe_feedback_id.jsonl" \
  --out "$TMP_DIR/unsafe_feedback_id_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null 2>&1
unsafe_feedback_id_rc="$?"
set -e
if [[ "$unsafe_feedback_id_rc" -ne 2 ]]; then
  echo "benchmark harness must reject unsafe maintainer feedback ids" >&2
  exit 16
fi

cat >"$TMP_DIR/real_benchmark_wrong_citation_labels.jsonl" <<EOF
{"case_id":"real_wrong_citation_case","repo_path":"$repo","expected_repo_git_head":"$repo_head","human_labeled":true,"synthetic":false,"priority":"P1","maintainer_id":"maintainer-one","maintainer_feedback":true,"plugin_id":"deprecated_api","rule_id":"deprecated-api-01","file_path":"legacy.py","expected_line_start":1,"expected_line_end":1,"expected_span_sha256":"sha256:0000000000000000000000000000000000000000000000000000000000000000","expected":"present","expected_abstain":false}
EOF
cat >"$TMP_DIR/real_benchmark_wrong_citation_feedback.jsonl" <<EOF
{"feedback_id":"fb-wrong-citation","case_id":"real_wrong_citation_case","maintainer_id":"maintainer-one","human_feedback":true,"synthetic":false,"feedback_text":"Fixture maintainer reviewed the wrong citation expectation case."}
EOF
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/real_benchmark_wrong_citation_labels.jsonl" \
  --feedback "$TMP_DIR/real_benchmark_wrong_citation_feedback.jsonl" \
  --out "$TMP_DIR/real_benchmark_wrong_citation_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json" "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_label_citation_expectations.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/real_benchmark_wrong_citation_out" >/dev/null
python3 - "$TMP_DIR/real_benchmark_wrong_citation_out" <<'PY'
import csv
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
label_citation_payload = json.loads((out / "benchmark_label_citation_expectations.json").read_text(encoding="utf-8"))
with (out / "benchmark_label_citation_expectations.csv").open(newline="", encoding="utf-8") as handle:
    label_citation_rows = list(csv.DictReader(handle))
if summary["product_readiness_calculated_from_real_labels"] != 1:
    raise SystemExit("wrong-citation real benchmark must still use real human-label basis")
if summary["tp"] != 1 or summary["fn"] != 0:
    raise SystemExit("wrong-citation benchmark must keep finding match separate from citation expectation match")
if summary["label_quality_requirement_met"] != 1 or summary["repo_snapshot_requirement_met"] != 1:
    raise SystemExit("wrong-citation benchmark must isolate the failing citation expectation sub-gate")
if summary["label_citation_expectation_rows"] != 1 or summary["label_citation_expectation_met_rows"] != 0 or summary["label_citation_expectation_requirement_met"] != 0:
    raise SystemExit("wrong-citation benchmark must block label citation expectation requirement")
if label_citation_payload["citation_expectation_rows"] != 1 or label_citation_payload["citation_expectation_met_rows"] != 0:
    raise SystemExit("wrong-citation JSON must bind supplied-but-unmet citation expectation counts")
if label_citation_payload["release_ready"] != 0 or label_citation_payload["public_comparison_claim_ready"] != 0 or label_citation_payload["real_model_execution_ready"] != 0:
    raise SystemExit("wrong-citation JSON must keep release/comparison/model flags false")
if len(label_citation_rows) != 1 or label_citation_rows[0]["citation_expectation_supplied"] != "1" or label_citation_rows[0]["citation_expectation_met"] != "0":
    raise SystemExit("wrong-citation CSV must record supplied-but-unmet citation expectation")
if label_citation_rows[0]["matched_finding_id"] == "" or label_citation_rows[0]["matched_citation_id"] != "":
    raise SystemExit("wrong-citation CSV must keep the matched finding but not invent a matching citation")
if summary["design_partner_beta_candidate_ready"] != 0:
    raise SystemExit("wrong-citation benchmark must not become beta candidate ready")
if summary["release_ready"] != 0 or summary["public_comparison_claim_ready"] != 0 or summary["real_model_execution_ready"] != 0:
    raise SystemExit("wrong-citation benchmark must keep release/comparison/model flags false")
PY
cp "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_summary.json" "$TMP_DIR/real_benchmark_wrong_citation_summary.original.json"
cp "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_manifest.json" "$TMP_DIR/real_benchmark_wrong_citation_manifest.original.json"
cp "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_sha256sums.txt" "$TMP_DIR/real_benchmark_wrong_citation_sha256sums.original.txt"
python3 - "$TMP_DIR/real_benchmark_wrong_citation_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary_path = out / "benchmark_summary.json"
manifest_path = out / "benchmark_manifest.json"
sha_path = out / "benchmark_sha256sums.txt"
summary = json.loads(summary_path.read_text(encoding="utf-8"))
summary["label_citation_expectation_requirement_met"] = 1
summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
summary_sha = "sha256:" + hashlib.sha256(summary_path.read_bytes()).hexdigest()
manifest["artifact_sha256s"]["benchmark_summary.json"] = summary_sha
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "benchmark_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "benchmark_summary.json": summary_sha.split(":", 1)[1],
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/real_benchmark_wrong_citation_out" >/dev/null 2>&1; then
  echo "benchmark verifier must reject promoted label citation expectation summary tamper" >&2
  exit 16
fi
cp "$TMP_DIR/real_benchmark_wrong_citation_summary.original.json" "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_summary.json"
cp "$TMP_DIR/real_benchmark_wrong_citation_manifest.original.json" "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_manifest.json"
cp "$TMP_DIR/real_benchmark_wrong_citation_sha256sums.original.txt" "$TMP_DIR/real_benchmark_wrong_citation_out/benchmark_sha256sums.txt"
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$TMP_DIR/real_benchmark_wrong_citation_out" >/dev/null

cat >"$TMP_DIR/synthetic_feedback.jsonl" <<EOF
{"feedback_id":"fb-synthetic","case_id":"real_small_case","maintainer_id":"maintainer-one","human_feedback":true,"synthetic":true,"feedback_text":"synthetic feedback must not enter real benchmark"}
EOF
set +e
"$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
  --labels "$TMP_DIR/real_benchmark_small_labels.jsonl" \
  --feedback "$TMP_DIR/synthetic_feedback.jsonl" \
  --out "$TMP_DIR/synthetic_feedback_real_benchmark_out" \
  --mode quick \
  --namespace real_benchmark \
  --confirm-real-benchmark-namespace \
  --no-rerun-check >/dev/null 2>&1
synthetic_feedback_rc="$?"
set -e
if [[ "$synthetic_feedback_rc" -ne 2 ]]; then
  echo "benchmark harness must reject synthetic feedback rows in real_benchmark namespace" >&2
  exit 16
fi
set +e
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --max-wall-ms 0 --out "$TMP_DIR/bad_first_report_smoke" >/dev/null 2>&1
first_report_bad_budget_rc="$?"
set -e
if [[ "$first_report_bad_budget_rc" -ne 2 ]]; then
  echo "first-report smoke must reject non-positive wall budget" >&2
  exit 16
fi
set +e
AUDIT_MY_REPO_FIRST_REPORT_TAMPER_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" \
  --out "$TMP_DIR/first_report_self_verify_tamper" \
  --max-wall-ms 600000 >/dev/null 2>&1
first_report_self_verify_tamper_rc="$?"
set -e
if [[ "$first_report_self_verify_tamper_rc" -ne 1 ]]; then
  echo "first-report smoke must fail when self-verification detects receipt drift" >&2
  exit 16
fi
if [[ -e "$TMP_DIR/first_report_self_verify_tamper/first_report_smoke.json" ]] || [[ -e "$TMP_DIR/first_report_self_verify_tamper/audit_out" ]] || [[ -e "$TMP_DIR/first_report_self_verify_tamper/fixture_repo" ]]; then
  echo "first-report smoke self-verification failure must not expose managed smoke artifacts" >&2
  exit 16
fi
first_report_time_budget_out="$TMP_DIR/first_report_time_budget_out"
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --out "$first_report_time_budget_out" --max-wall-ms 600000 >/dev/null
python3 - "$first_report_time_budget_out/first_report_smoke.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
receipt = json.loads(path.read_text(encoding="utf-8"))
receipt["max_wall_ms"] = 1
receipt["within_time_budget"] = 0
path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$first_report_time_budget_out" >/dev/null 2>&1; then
  echo "first-report smoke verifier must reject receipts outside the time budget" >&2
  exit 16
fi

if [[ "$("$ROOT_DIR/scripts/audit_my_repo_package.py" --version)" != "audit_my_repo_alpha.v1" ]]; then
  echo "package entrypoint must expose a stable tool version" >&2
  exit 31
fi
package_out="$TMP_DIR/package_out"
mkdir -p "$package_out"
printf 'keep' >"$package_out/sentinel.txt"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_out" >/dev/null
test "$(cat "$package_out/sentinel.txt")" = "keep"
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_package_manifest.schema.json" "$package_out/package_manifest.json" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null
python3 - "$package_out" "$ROOT_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

package_out = Path(sys.argv[1])
root = Path(sys.argv[2]).resolve()
manifest = json.loads((package_out / "package_manifest.json").read_text(encoding="utf-8"))
sha_rows = {
    rel: digest
    for digest, rel in (
        line.split(None, 1)
        for line in (package_out / "package_sha256s.txt").read_text(encoding="utf-8").splitlines()
        if line.strip()
    )
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


if manifest["schema_version"] != "local_repo_audit_package_manifest.v1":
    raise SystemExit("package manifest schema_version mismatch")
if manifest["tool_version"] != "audit_my_repo_alpha.v1" or manifest["package_version"] != "audit_my_repo_alpha.v1":
    raise SystemExit("package manifest must pin the alpha version")
if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
    raise SystemExit("package manifest timestamp must be deterministic")
for key in [
    "version_pinned",
]:
    if manifest[key] != 1:
        raise SystemExit(f"package manifest must set {key}=1")
for key in [
    "network_download_used",
    "package_upload_performed",
    "real_release_package_ready",
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "design_partner_beta_candidate_ready",
]:
    if manifest[key] != 0:
        raise SystemExit(f"package manifest must keep {key}=0")
if manifest["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("package manifest must keep the alpha claim boundary")
required_sources = {
    "scripts/audit_my_repo.py",
    "scripts/audit_my_repo.sh",
    "scripts/audit_my_repo_pr.sh",
    "scripts/audit_my_repo_benchmark.py",
    "scripts/audit_my_repo_first_report_smoke.py",
    "scripts/audit_my_repo_package.py",
    "tools/verify_local_audit.py",
    "tools/validate_json_schemas.py",
    "experiments/test_audit_my_repo_negative_controls.sh",
    "experiments/test_audit_my_repo_product_entrypoint.sh",
}
if not required_sources.issubset(manifest["source_sha256s"]):
    raise SystemExit("package manifest missing required source bindings")
if manifest["source_sha256s"]["scripts/audit_my_repo_package.py"] != "sha256:" + sha256(root / "scripts/audit_my_repo_package.py"):
    raise SystemExit("package manifest source sha mismatch for package entrypoint")
if manifest["schema_sha256s"]["schemas/local_repo_audit_package_manifest.schema.json"] != "sha256:" + sha256(root / "schemas/local_repo_audit_package_manifest.schema.json"):
    raise SystemExit("package manifest must bind its schema sha")
if manifest["source_file_count"] != len(manifest["source_sha256s"]) or manifest["schema_file_count"] != len(manifest["schema_sha256s"]):
    raise SystemExit("package manifest source/schema counts must match their maps")
if manifest["changelog_path"] != "CHANGELOG.audit-my-repo.md":
    raise SystemExit("package manifest must bind changelog path")
if manifest["changelog_sha256"] != "sha256:" + sha256(package_out / "CHANGELOG.audit-my-repo.md"):
    raise SystemExit("package manifest changelog sha mismatch")
if set(sha_rows) != {"package_manifest.json", "CHANGELOG.audit-my-repo.md"}:
    raise SystemExit("package sha manifest must bind exactly the package manifest and changelog")
for rel, digest in sha_rows.items():
    if digest != sha256(package_out / rel):
        raise SystemExit(f"package sha manifest mismatch: {rel}")
commands = [row["command"] for row in manifest["entrypoints"]]
if "./scripts/audit_my_repo.sh --version" not in commands:
    raise SystemExit("package manifest must advertise the version entrypoint")
if not any(row["command"].startswith("./scripts/audit_my_repo_pr.sh ") for row in manifest["entrypoints"]):
    raise SystemExit("package manifest must advertise the PR/diff scoped entrypoint")
if not any("--verify-existing" in row["command"] for row in manifest["verification_commands"]):
    raise SystemExit("package manifest must advertise package verification")
if not any(row["command"] == "./scripts/ai-verify.sh" for row in manifest["verification_commands"]):
    raise SystemExit("package manifest must preserve ai-verify as the final verification command")
PY
set +e
"$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_out" >/dev/null 2>&1
package_no_overwrite_rc="$?"
set -e
if [[ "$package_no_overwrite_rc" -ne 2 ]]; then
  echo "package writer must refuse to replace package artifacts without --overwrite" >&2
  exit 31
fi
test "$(cat "$package_out/sentinel.txt")" = "keep"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_out" --overwrite >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

printf 'stale' >"$package_out/package_manifest.json.old"
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject stale package-managed artifacts outside the sha manifest" >&2
  exit 31
fi
rm "$package_out/package_manifest.json.old"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

package_stale_write_out="$TMP_DIR/package_stale_write_out"
mkdir -p "$package_stale_write_out"
printf 'stale' >"$package_stale_write_out/package_sha256s.txt.old"
set +e
"$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_stale_write_out" >/dev/null 2>&1
package_stale_write_rc="$?"
set -e
if [[ "$package_stale_write_rc" -ne 2 ]]; then
  echo "package writer must refuse stale package-managed artifacts before publish" >&2
  exit 31
fi
if [ -e "$package_stale_write_out/package_manifest.json" ] || [ -e "$package_stale_write_out/CHANGELOG.audit-my-repo.md" ] || [ -e "$package_stale_write_out/package_sha256s.txt" ]; then
  echo "package writer must not publish package artifacts after stale-layout refusal" >&2
  exit 31
fi

package_self_verify_tamper_out="$TMP_DIR/package_self_verify_tamper_out"
set +e
AUDIT_MY_REPO_PACKAGE_TAMPER_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_self_verify_tamper_out" >/dev/null 2>&1
package_self_verify_tamper_rc="$?"
set -e
if [[ "$package_self_verify_tamper_rc" -ne 1 ]]; then
  echo "package writer must fail when self-verification detects manifest drift" >&2
  exit 31
fi
if [ -e "$package_self_verify_tamper_out/package_manifest.json" ] || [ -e "$package_self_verify_tamper_out/CHANGELOG.audit-my-repo.md" ] || [ -e "$package_self_verify_tamper_out/package_sha256s.txt" ]; then
  echo "package writer must not publish artifacts after self-verification failure" >&2
  exit 31
fi
if [ -d "$package_self_verify_tamper_out" ] && find "$package_self_verify_tamper_out" -maxdepth 1 -name '.package_staging.*' | grep -q .; then
  echo "package writer must clean staging directories after self-verification failure" >&2
  exit 31
fi

package_manifest_path="$package_out/package_manifest.json"
package_changelog_path="$package_out/CHANGELOG.audit-my-repo.md"
package_sha_path="$package_out/package_sha256s.txt"
cp "$package_manifest_path" "$TMP_DIR/package_manifest.original.json"
cp "$package_changelog_path" "$TMP_DIR/package_changelog.original.md"
cp "$package_sha_path" "$TMP_DIR/package_sha256s.original.txt"

package_publish_failure_out="$TMP_DIR/package_publish_failure_out"
set +e
AUDIT_MY_REPO_PACKAGE_FAIL_AFTER_PUBLISH_COUNT=1 "$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_publish_failure_out" >/dev/null 2>&1
package_publish_failure_rc="$?"
set -e
if [[ "$package_publish_failure_rc" -ne 2 ]]; then
  echo "package writer must fail with input/publish error on simulated publish failure" >&2
  exit 31
fi
if [ -e "$package_publish_failure_out/package_manifest.json" ] || [ -e "$package_publish_failure_out/CHANGELOG.audit-my-repo.md" ] || [ -e "$package_publish_failure_out/package_sha256s.txt" ]; then
  echo "package writer must not expose partial managed artifacts after publish failure" >&2
  exit 31
fi
if [ -d "$package_publish_failure_out" ] && find "$package_publish_failure_out" -maxdepth 1 \( -name '.package_staging.*' -o -name '.package_backup.*' \) | grep -q .; then
  echo "package writer must clean staging and backup directories after publish failure" >&2
  exit 31
fi
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$package_publish_failure_out").package_backup.*" | grep -q .; then
  echo "package writer must clean sibling backup directories after publish failure" >&2
  exit 31
fi

set +e
AUDIT_MY_REPO_PACKAGE_FAIL_AFTER_PUBLISH_COUNT=1 "$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_out" --overwrite >/dev/null 2>&1
package_overwrite_publish_failure_rc="$?"
set -e
if [[ "$package_overwrite_publish_failure_rc" -ne 2 ]]; then
  echo "package overwrite must fail with input/publish error on simulated publish failure" >&2
  exit 31
fi
cmp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path" >/dev/null
cmp "$TMP_DIR/package_changelog.original.md" "$package_changelog_path" >/dev/null
cmp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null
if find "$package_out" -maxdepth 1 \( -name '.package_staging.*' -o -name '.package_backup.*' \) | grep -q .; then
  echo "package overwrite rollback must not leak staging or backup directories" >&2
  exit 31
fi
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$package_out").package_backup.*" | grep -q .; then
  echo "package overwrite rollback must not leak sibling backup directories" >&2
  exit 31
fi

package_final_verify_tamper_out="$TMP_DIR/package_final_verify_tamper_out"
set +e
AUDIT_MY_REPO_PACKAGE_TAMPER_AFTER_PUBLISH_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_final_verify_tamper_out" >/dev/null 2>&1
package_final_verify_tamper_rc="$?"
set -e
if [[ "$package_final_verify_tamper_rc" -ne 1 ]]; then
  echo "package writer must fail when final self-verification detects post-publish drift" >&2
  exit 31
fi
if [ -e "$package_final_verify_tamper_out/package_manifest.json" ] || [ -e "$package_final_verify_tamper_out/CHANGELOG.audit-my-repo.md" ] || [ -e "$package_final_verify_tamper_out/package_sha256s.txt" ]; then
  echo "package writer must roll back fresh artifacts after final self-verification failure" >&2
  exit 31
fi
if [ -d "$package_final_verify_tamper_out" ] && find "$package_final_verify_tamper_out" -maxdepth 1 -name '.package_staging.*' | grep -q .; then
  echo "package writer must clean staging directories after final self-verification failure" >&2
  exit 31
fi
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$package_final_verify_tamper_out").package_backup.*" | grep -q .; then
  echo "package writer must clean sibling backup directories after final self-verification failure" >&2
  exit 31
fi

set +e
AUDIT_MY_REPO_PACKAGE_TAMPER_AFTER_PUBLISH_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_package.py" --out "$package_out" --overwrite >/dev/null 2>&1
package_overwrite_final_verify_tamper_rc="$?"
set -e
if [[ "$package_overwrite_final_verify_tamper_rc" -ne 1 ]]; then
  echo "package overwrite must fail when final self-verification detects post-publish drift" >&2
  exit 31
fi
cmp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path" >/dev/null
cmp "$TMP_DIR/package_changelog.original.md" "$package_changelog_path" >/dev/null
cmp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path" >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null
if find "$TMP_DIR" -maxdepth 1 -name ".$(basename "$package_out").package_backup.*" | grep -q .; then
  echo "package overwrite final-verification rollback must not leak sibling backup directories" >&2
  exit 31
fi

printf '\nTampered release claim.\n' >>"$package_changelog_path"
python3 - "$package_sha_path" "$package_changelog_path" "CHANGELOG.audit-my-repo.md" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject tampered changelog even when package_sha256s is updated" >&2
  exit 31
fi
cp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path"
cp "$TMP_DIR/package_changelog.original.md" "$package_changelog_path"
cp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

python3 - "$package_sha_path" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = []
for line in path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  CHANGELOG.audit-my-repo.md"):
        lines.append(("0" * 64) + "  CHANGELOG.audit-my-repo.md")
    else:
        lines.append(line)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject package_sha256s-only digest drift" >&2
  exit 31
fi
cp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

python3 - "$package_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["design_partner_beta_candidate_ready"] = 1
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$package_sha_path" "$package_manifest_path" "package_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject tampered design-partner beta readiness" >&2
  exit 31
fi
cp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path"
cp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

python3 - "$package_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["release_ready"] = 1
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$package_sha_path" "$package_manifest_path" "package_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject tampered readiness flags" >&2
  exit 31
fi
cp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path"
cp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

python3 - "$package_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["source_sha256s"]["scripts/audit_my_repo.py"] = "sha256:" + ("0" * 64)
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$package_sha_path" "$package_manifest_path" "package_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject stale source sha bindings" >&2
  exit 31
fi
cp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path"
cp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

python3 - "$package_manifest_path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["schema_only_tamper"] = "unexpected"
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
python3 - "$package_sha_path" "$package_manifest_path" "package_manifest.json" <<'PY'
import hashlib
import sys
from pathlib import Path
sha_path = Path(sys.argv[1])
target = Path(sys.argv[2])
rel = sys.argv[3]
new_sha = hashlib.sha256(target.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    if line.endswith("  " + rel):
        lines.append(f"{new_sha}  {rel}")
    else:
        lines.append(line)
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null 2>&1; then
  echo "package verifier must reject schema-invalid package manifest" >&2
  exit 31
fi
cp "$TMP_DIR/package_manifest.original.json" "$package_manifest_path"
cp "$TMP_DIR/package_sha256s.original.txt" "$package_sha_path"
"$ROOT_DIR/scripts/audit_my_repo_package.py" --verify-existing "$package_out" >/dev/null

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
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_diagnostics.schema.json" "$out_a/diagnostics.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_dashboard.schema.json" "$out_a/audit_dashboard.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_exit_code_contract.schema.json" "$out_a/exit_code_contract.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_accuracy_rows.schema.json" "$out_a/accuracy_rows.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_citation_correctness_rows.schema.json" "$out_a/citation_correctness_rows.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_findings.schema.json" "$out_a/audit_findings.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_invocation.schema.json" "$out_a/audit_invocation.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_semantic_summary.schema.json" "$out_a/audit_semantic_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_summary.schema.json" "$out_a/audit_summary.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_registry.schema.json" "$out_a/plugin_registry.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_resource_envelope.schema.json" "$out_a/resource_envelope.json" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_source_snapshot.schema.json" "$out_a/source_snapshot.json" >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$out_a" >/dev/null

before_publish_failure_manifest="$(cat "$out_a/audit_manifest.json")"
before_publish_failure_sha="$(cat "$out_a/sha256sums.txt")"
before_publish_failure_latest="$(readlink "$out_a/latest")"
before_publish_failure_runs="$(find "$out_a/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)"
set +e
AUDIT_MY_REPO_FAIL_PUBLISH_BEFORE_LATEST=1 "$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$out_a" \
  --namespace fixture \
  --question "A publish failure must not replace latest." \
  --generator routehint-tiny \
  --overwrite-latest >/dev/null 2>&1
publish_failure_rc="$?"
set -e
if [[ "$publish_failure_rc" -ne 2 ]]; then
  echo "simulated publish failure before latest must return exit 2, got $publish_failure_rc" >&2
  exit 15
fi
if [[ "$(cat "$out_a/audit_manifest.json")" != "$before_publish_failure_manifest" ]]; then
  echo "simulated publish failure must not change the public audit_manifest.json" >&2
  exit 15
fi
if [[ "$(cat "$out_a/sha256sums.txt")" != "$before_publish_failure_sha" ]]; then
  echo "simulated publish failure must not change the public sha256sums.txt" >&2
  exit 15
fi
if [[ "$(readlink "$out_a/latest")" != "$before_publish_failure_latest" ]]; then
  echo "simulated publish failure before latest must not change the latest pointer" >&2
  exit 15
fi
if [[ "$(find "$out_a/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)" != "$before_publish_failure_runs" ]]; then
  echo "simulated publish failure before latest must not leave a failed versioned run directory" >&2
  exit 15
fi
"$ROOT_DIR/tools/verify_local_audit.py" "$out_a" >/dev/null

before_after_latest_failure_manifest="$(cat "$out_a/audit_manifest.json")"
before_after_latest_failure_sha="$(cat "$out_a/sha256sums.txt")"
before_after_latest_failure_latest="$(readlink "$out_a/latest")"
before_after_latest_failure_runs="$(find "$out_a/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)"
set +e
AUDIT_MY_REPO_FAIL_PUBLISH_AFTER_LATEST=1 "$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" \
  --mode quick \
  --max-queries 12 \
  --out "$out_a" \
  --namespace fixture \
  --question "A publish failure after latest must roll back the public pointer." \
  --generator routehint-tiny \
  --overwrite-latest >/dev/null 2>&1
after_latest_failure_rc="$?"
set -e
if [[ "$after_latest_failure_rc" -ne 2 ]]; then
  echo "simulated publish failure after latest must return exit 2, got $after_latest_failure_rc" >&2
  exit 15
fi
if [[ "$(cat "$out_a/audit_manifest.json")" != "$before_after_latest_failure_manifest" ]]; then
  echo "simulated publish failure after latest must roll back the public audit_manifest.json" >&2
  exit 15
fi
if [[ "$(cat "$out_a/sha256sums.txt")" != "$before_after_latest_failure_sha" ]]; then
  echo "simulated publish failure after latest must roll back the public sha256sums.txt" >&2
  exit 15
fi
if [[ "$(readlink "$out_a/latest")" != "$before_after_latest_failure_latest" ]]; then
  echo "simulated publish failure after latest must restore the previous latest pointer" >&2
  exit 15
fi
if [[ "$(find "$out_a/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)" != "$before_after_latest_failure_runs" ]]; then
  echo "simulated publish failure after latest must remove the failed versioned run directory" >&2
  exit 15
fi
"$ROOT_DIR/tools/verify_local_audit.py" "$out_a" >/dev/null

python3 - "$ROOT_DIR" "$repo" "$out_a" "$out_b" <<'PY'
import csv
import hashlib
import html
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()
out_a = Path(sys.argv[3])
out_b = Path(sys.argv[4])
question_cache_out = out_b.parent / "question_cache_out"


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
deprecated_parser_ids = {
    row["parser_id"]
    for row in plugin_rule_rows
    if row["plugin_id"] == "deprecated_api"
}
if not {
    "python_ast",
    "cpp_lexical_code_candidate_parser",
    "javascript_typescript_lexical_code_candidate_parser",
}.issubset(deprecated_parser_ids):
    raise SystemExit("deprecated API plugin rules must bind parser provenance for python/js-ts/cpp")
if any(row["evidence_policy"] not in {"source-bound-span", "abstain-when-missing-source-bound-span"} for row in plugin_rule_rows):
    raise SystemExit("plugin rule rows must bind a replayable evidence policy")
if any(not row.get("parser_id") for row in plugin_rule_rows):
    raise SystemExit("plugin rule rows must bind parser provenance")
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
if manifest["verifier_source_sha256"] != "sha256:" + sha256(root / "tools/verify_local_audit.py"):
    raise SystemExit("manifest must bind local verifier source sha")
if manifest["schema_sha256s"].get("schemas/local_repo_audit_suppressions.schema.json") != "sha256:" + sha256(root / "schemas/local_repo_audit_suppressions.schema.json"):
    raise SystemExit("manifest must bind suppression/allowlist schema sha")
if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
    raise SystemExit("manifest timestamp must be deterministic")
if manifest["output_dir_overwritten"] != 0:
    raise SystemExit("manifest must prove output artifacts were not overwritten")
if manifest["publish_mode"] != "versioned-run-dir-with-latest-pointer":
    raise SystemExit("manifest must expose bundle-level latest pointer publish mode")
if manifest["bundle_run_dir"] != str(out_a / "runs" / manifest["run_id"]):
    raise SystemExit("manifest must bind versioned run directory")
if manifest["latest_pointer"] != str(out_a / "latest"):
    raise SystemExit("manifest must bind latest pointer")

summary = json.loads((out_a / "audit_summary.json").read_text(encoding="utf-8"))
audit_dashboard_json = json.loads((out_a / "audit_dashboard.json").read_text(encoding="utf-8"))
for field in [
    "real_release_package_ready",
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "raw_prompt_context_bytes",
    "attention_blocks",
    "transformer_blocks",
    "oracle_prediction_used",
    "raw_input_extractor_used",
]:
    if summary[field] != 0:
        raise SystemExit(f"{field} must stay zero in product negative controls")
phase_sum = summary["scan_latency_ms"] + summary["plugin_latency_ms"] + summary["serialize_latency_ms"] + summary["verify_latency_ms"]
if summary["latency_ms"] != phase_sum or phase_sum <= 0:
    raise SystemExit("summary latency must equal positive measured phase timings")
if summary["active_plugin_ids"] != "doc_code_identity|deprecated_api|unsupported_claim":
    raise SystemExit("quick mode must bind its reduced active plugin set")
if summary["namespace"] != "fixture":
    raise SystemExit("summary namespace must match fixture")
if summary["unsupported_claim_rows"] < 1 or summary["abstain_rows"] < 1:
    raise SystemExit("unsupported and abstain rows must be present")
if audit_dashboard_json["cache_key"] != manifest["cache_key"] or audit_dashboard_json["run_id"] != manifest["run_id"]:
    raise SystemExit("audit_dashboard.json must bind manifest run/cache identity")
if audit_dashboard_json["review_counts"]["finding_rows"] != summary["finding_rows"]:
    raise SystemExit("audit_dashboard.json must bind summary finding count")
if (
    audit_dashboard_json["readiness"]["release_ready"] != 0
    or audit_dashboard_json["readiness"]["public_comparison_claim_ready"] != 0
    or audit_dashboard_json["readiness"]["real_model_execution_ready"] != 0
    or audit_dashboard_json["readiness"]["design_partner_beta_candidate_ready"] != 0
):
    raise SystemExit("audit_dashboard.json must keep readiness claims blocked")

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
findings_json = json.loads((out_a / "audit_findings.json").read_text(encoding="utf-8"))
if findings_json.get("schema_version") != "local_repo_audit_findings.v1":
    raise SystemExit("standard JSON findings schema version mismatch")
if findings_json.get("tool_version") != "audit_my_repo_alpha.v1":
    raise SystemExit("standard JSON findings must bind tool version")
if findings_json.get("claim_boundary") != "alpha-local-code-doc-audit-only":
    raise SystemExit("standard JSON findings must bind the alpha claim boundary")
if findings_json.get("release_ready") != 0 or findings_json.get("public_comparison_claim_ready") != 0 or findings_json.get("real_model_execution_ready") != 0:
    raise SystemExit("standard JSON findings must keep readiness flags false")
if findings_json.get("findings") != findings:
    raise SystemExit("standard JSON findings must match audit_findings.jsonl")
plugin_ids = {row["plugin_id"] for row in findings}
expected_plugins = {
    "doc_code_identity",
    "deprecated_api",
    "unsupported_claim",
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
accuracy_payload = json.loads((out_a / "accuracy_rows.json").read_text(encoding="utf-8"))
if accuracy_payload["accuracy_rows"] != len(accuracy_rows):
    raise SystemExit("accuracy rows JSON count must match CSV")
if accuracy_payload["automatic_accuracy_claimed"] != 0 or accuracy_payload["manual_accuracy_review_required"] != 1:
    raise SystemExit("accuracy rows JSON must preserve manual unreviewed boundary")
if [{key: str(value) for key, value in row.items()} for row in accuracy_payload["rows"]] != accuracy_rows:
    raise SystemExit("accuracy rows JSON must mirror accuracy_rows.csv")

with (out_a / "citation_correctness_rows.csv").open(newline="", encoding="utf-8") as handle:
    citation_rows = list(csv.DictReader(handle))
if not citation_rows or any(row["citation_correctness_label"] != "source_bound_unreviewed" for row in citation_rows):
    raise SystemExit("citation correctness must stay source-bound unreviewed")
citation_payload = json.loads((out_a / "citation_correctness_rows.json").read_text(encoding="utf-8"))
if citation_payload["citation_correctness_rows"] != len(citation_rows):
    raise SystemExit("citation correctness JSON count must match CSV")
if citation_payload["manual_citation_review_required"] != 1:
    raise SystemExit("citation correctness JSON must preserve manual review boundary")
if [{key: str(value) for key, value in row.items()} for row in citation_payload["rows"]] != citation_rows:
    raise SystemExit("citation correctness JSON must mirror citation_correctness_rows.csv")

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
citation_spans_csv_path = out_a / "citation_spans.csv"
sha_manifest_path = out_a / "sha256sums.txt"
original_citations = tampered_citations.read_text(encoding="utf-8")
original_citation_spans_csv_text = citation_spans_csv_path.read_text(encoding="utf-8")
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
direct_verify_cmd = [str(root / "tools/verify_local_audit.py")]
manifest_path = out_a / "audit_manifest.json"


def expect_verify_failure(cmd, label, needle):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode == 0:
        raise SystemExit(label)
    combined = result.stdout + result.stderr
    if needle not in combined:
        raise SystemExit(f"{label}; missing verifier evidence: {needle}")


if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must require abstain_rows.csv in sha256sums.txt")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

unexpected_bundle_artifact_path = out_a / "latest" / "stale_bundle_artifact.txt"
unexpected_bundle_artifact_path.write_text("stale bundle artifact must not be exposed through latest\n", encoding="utf-8")
expect_verify_failure(
    verify_cmd,
    "local-audit verifier must reject manifest-outside artifacts inside the latest bundle",
    "latest audit bundle contains unmanifested artifact",
)
unexpected_bundle_artifact_path.unlink()

unexpected_audit_symlink_path = out_a / "stale_audit_link.txt"
unexpected_audit_symlink_path.symlink_to("latest/audit_summary.csv")
expect_verify_failure(
    verify_cmd,
    "local-audit verifier must reject manifest-outside top-level audit symlinks",
    "published audit output exposes unmanifested audit symlink",
)
unexpected_audit_symlink_path.unlink()

absolute_audit_symlink_path = out_a / "absolute_stale_audit_link.txt"
absolute_audit_symlink_path.symlink_to((out_a / "latest" / "audit_summary.csv").resolve())
expect_verify_failure(
    verify_cmd,
    "local-audit verifier must reject manifest-outside absolute audit symlinks",
    "published audit output exposes unmanifested audit symlink",
)
absolute_audit_symlink_path.unlink()

manifest_for_bundle_path = json.loads(manifest_path.read_text(encoding="utf-8"))
run_dir = Path(manifest_for_bundle_path["bundle_run_dir"])
direct_bundle_stale_path = run_dir / "direct_bundle_stale.txt"
direct_bundle_stale_path.write_text("direct bundle verification must reject this stale file\n", encoding="utf-8")
expect_verify_failure(
    direct_verify_cmd + [str(run_dir)],
    "direct versioned-run verification must reject manifest-outside artifacts",
    "audit bundle contains unmanifested artifact",
)
direct_bundle_stale_path.unlink()

report_path = out_a / "AUDIT_REPORT.md"
report_target = os.readlink(report_path)
report_text = report_path.read_text(encoding="utf-8")
report_path.unlink()
report_path.write_text(report_text, encoding="utf-8")
expect_verify_failure(
    verify_cmd,
    "local-audit verifier must reject stale regular files in compatibility artifact slots",
    "published compatibility artifact must be a latest symlink",
)
report_path.unlink()
os.symlink(report_target, report_path)

plugin_registry_path = out_a / "plugin_registry.json"
original_plugin_registry_text = plugin_registry_path.read_text(encoding="utf-8")
original_manifest_text = manifest_path.read_text(encoding="utf-8")
contract_path_for_manifest_schema = out_a / "artifact_contract_rows.csv"
original_contract_text_for_manifest_schema = contract_path_for_manifest_schema.read_text(encoding="utf-8")
tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["schema_only_extra_key"] = 1
manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
with contract_path_for_manifest_schema.open(newline="", encoding="utf-8") as handle:
    contract_rows = list(csv.DictReader(handle))
for row in contract_rows:
    if row["artifact_path"] == "audit_manifest.json":
        row["actual_keys"] = row["actual_keys"] + "|schema_only_extra_key"
with contract_path_for_manifest_schema.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(contract_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(contract_rows)
new_manifest_sha = sha256(manifest_path)
new_contract_sha = sha256(contract_path_for_manifest_schema)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_manifest.json"):
        sha_lines.append(f"{new_manifest_sha}  audit_manifest.json")
    elif line.endswith("  artifact_contract_rows.csv"):
        sha_lines.append(f"{new_contract_sha}  artifact_contract_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must schema-check audit_manifest.json instances")
manifest_path.write_text(original_manifest_text, encoding="utf-8")
contract_path_for_manifest_schema.write_text(original_contract_text_for_manifest_schema, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

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

manual_review_json_path = out_a / "manual_review_queue.json"
original_manual_review_json_text = manual_review_json_path.read_text(encoding="utf-8")
manual_review_json = json.loads(original_manual_review_json_text)
manual_review_json["rows"][0]["auto_promoted"] = 1
manual_review_json_path.write_text(json.dumps(manual_review_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_manual_review_json_sha = sha256(manual_review_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  manual_review_queue.json"):
        sha_lines.append(f"{new_manual_review_json_sha}  manual_review_queue.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject manual review JSON auto-promotion")
manual_review_json_path.write_text(original_manual_review_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

manual_review_path.write_text(original_manual_review_text, encoding="utf-8")
manual_review_json_path.write_text(original_manual_review_json_text, encoding="utf-8")
audit_semantic_summary_path = out_a / "audit_semantic_summary.json"
original_audit_semantic_summary_text = audit_semantic_summary_path.read_text(encoding="utf-8")
with manual_review_path.open(newline="", encoding="utf-8") as handle:
    manual_review_rows = list(csv.DictReader(handle))
manual_review_json = json.loads(original_manual_review_json_text)
if len(manual_review_rows) >= 2 and len(manual_review_json.get("rows", [])) >= 2:
    manual_review_rows[0]["review_queue_id"], manual_review_rows[1]["review_queue_id"] = (
        manual_review_rows[1]["review_queue_id"],
        manual_review_rows[0]["review_queue_id"],
    )
    manual_review_json["rows"][0]["review_queue_id"], manual_review_json["rows"][1]["review_queue_id"] = (
        manual_review_json["rows"][1]["review_queue_id"],
        manual_review_json["rows"][0]["review_queue_id"],
    )
    with manual_review_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(manual_review_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(manual_review_rows)
    manual_review_json_path.write_text(json.dumps(manual_review_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    semantic_payload = json.loads(original_audit_semantic_summary_text)
    semantic_payload["artifact_sha256s"]["manual_review_queue.csv"] = "sha256:" + sha256(manual_review_path)
    digest = hashlib.sha256()
    for rel in semantic_payload["semantic_artifacts"]:
        artifact = out_a / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(("sha256:" + sha256(artifact)).encode("utf-8") if artifact.is_file() else b"missing")
        digest.update(b"\n")
    semantic_payload["semantic_result_sha256"] = "sha256:" + digest.hexdigest()
    audit_semantic_summary_path.write_text(json.dumps(semantic_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    new_manual_review_sha = sha256(manual_review_path)
    new_manual_review_json_sha = sha256(manual_review_json_path)
    new_audit_semantic_summary_sha = sha256(audit_semantic_summary_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  manual_review_queue.csv"):
            sha_lines.append(f"{new_manual_review_sha}  manual_review_queue.csv")
        elif line.endswith("  manual_review_queue.json"):
            sha_lines.append(f"{new_manual_review_json_sha}  manual_review_queue.json")
        elif line.endswith("  audit_semantic_summary.json"):
            sha_lines.append(f"{new_audit_semantic_summary_sha}  audit_semantic_summary.json")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    manual_review_swap_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if manual_review_swap_result.returncode == 0:
        raise SystemExit("local-audit verifier must reject swapped manual review queue ids")
    if "manual_review_queue.csv review_queue_id must bind finding_id" not in manual_review_swap_result.stderr:
        raise SystemExit("local-audit verifier must explain manual review queue id binding drift")
    manual_review_path.write_text(original_manual_review_text, encoding="utf-8")
    manual_review_json_path.write_text(original_manual_review_json_text, encoding="utf-8")
    audit_semantic_summary_path.write_text(original_audit_semantic_summary_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

accuracy_json_path = out_a / "accuracy_rows.json"
original_accuracy_json_text = accuracy_json_path.read_text(encoding="utf-8")
accuracy_json = json.loads(original_accuracy_json_text)
accuracy_json["automatic_accuracy_claimed"] = 1
accuracy_json_path.write_text(json.dumps(accuracy_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_accuracy_json_sha = sha256(accuracy_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  accuracy_rows.json"):
        sha_lines.append(f"{new_accuracy_json_sha}  accuracy_rows.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject accuracy JSON automatic accuracy claims")
accuracy_json_path.write_text(original_accuracy_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

citation_json_path = out_a / "citation_correctness_rows.json"
original_citation_json_text = citation_json_path.read_text(encoding="utf-8")
citation_json = json.loads(original_citation_json_text)
citation_json["rows"][0]["manual_citation_review_required"] = 0
citation_json_path.write_text(json.dumps(citation_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_citation_json_sha = sha256(citation_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  citation_correctness_rows.json"):
        sha_lines.append(f"{new_citation_json_sha}  citation_correctness_rows.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject citation correctness JSON manual-review drift")
citation_json_path.write_text(original_citation_json_text, encoding="utf-8")
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

with plugin_rule_path.open(newline="", encoding="utf-8") as handle:
    plugin_rule_rows = list(csv.DictReader(handle))
for row in plugin_rule_rows:
    if row["plugin_id"] == "deprecated_api" and row["parser_id"] == "javascript_typescript_lexical_code_candidate_parser":
        row["parser_id"] = "text_pattern"
        break
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
    raise SystemExit("local-audit verifier must reject deprecated_api parser provenance drift")
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

suppressed_findings_path = out_a / "suppressed_findings.csv"
original_suppressed_findings_text = suppressed_findings_path.read_text(encoding="utf-8")
suppressed_findings_path.write_text("suppression_id\n", encoding="utf-8")
with contract_path.open(newline="", encoding="utf-8") as handle:
    contract_rows = list(csv.DictReader(handle))
for row in contract_rows:
    if row["artifact_path"] == "suppressed_findings.csv":
        row["artifact_kind"] = "text"
        row["required_columns"] = "suppression_id"
        row["actual_columns"] = "suppression_id"
        row["actual_rows"] = "0"
with contract_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(contract_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(contract_rows)
new_suppressed_findings_sha = sha256(suppressed_findings_path)
new_contract_sha = sha256(contract_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  suppressed_findings.csv"):
        sha_lines.append(f"{new_suppressed_findings_sha}  suppressed_findings.csv")
    elif line.endswith("  artifact_contract_rows.csv"):
        sha_lines.append(f"{new_contract_sha}  artifact_contract_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
contract_kind_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if contract_kind_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject coordinated CSV contract kind/header drift")
if "artifact contract kind drift: suppressed_findings.csv" not in contract_kind_result.stderr:
    raise SystemExit("local-audit verifier must explain artifact contract kind drift")
suppressed_findings_path.write_text(original_suppressed_findings_text, encoding="utf-8")
contract_path.write_text(original_contract_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

tampered_citations.write_text(original_citations.replace("sha256:", "sha256:0000", 1), encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject tampered citation hashes")
tampered_citations.write_text(original_citations, encoding="utf-8")

with citation_spans_csv_path.open(newline="", encoding="utf-8") as handle:
    citation_csv_rows = list(csv.DictReader(handle))
citation_json_rows = [json.loads(line) for line in original_citations.splitlines() if line.strip()]
citation_csv_rows[0]["span_sha256"] = "sha256:" + ("0" * 64)
citation_json_rows[0]["span_sha256"] = "sha256:" + ("0" * 64)
with citation_spans_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(citation_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(citation_csv_rows)
tampered_citations.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in citation_json_rows), encoding="utf-8")
new_citation_csv_sha = sha256(citation_spans_csv_path)
new_citation_jsonl_sha = sha256(tampered_citations)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  citation_spans.csv"):
        sha_lines.append(f"{new_citation_csv_sha}  citation_spans.csv")
    elif line.endswith("  citation_spans.jsonl"):
        sha_lines.append(f"{new_citation_jsonl_sha}  citation_spans.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject citation span sha drift")
citation_spans_csv_path.write_text(original_citation_spans_csv_text, encoding="utf-8")
tampered_citations.write_text(original_citations, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with citation_spans_csv_path.open(newline="", encoding="utf-8") as handle:
    citation_csv_rows = list(csv.DictReader(handle))
citation_json_rows = [json.loads(line) for line in original_citations.splitlines() if line.strip()]
if citation_csv_rows and citation_json_rows:
    orphan_csv_row = dict(citation_csv_rows[0])
    orphan_json_row = dict(citation_json_rows[0])
    orphan_csv_row["finding_id"] = "finding_999"
    orphan_csv_row["citation_id"] = "finding_999_cite_1"
    orphan_json_row["finding_id"] = "finding_999"
    orphan_json_row["citation_id"] = "finding_999_cite_1"
    citation_csv_rows.append(orphan_csv_row)
    citation_json_rows.append(orphan_json_row)
    with citation_spans_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(citation_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(citation_csv_rows)
    tampered_citations.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in citation_json_rows), encoding="utf-8")
    new_citation_csv_sha = sha256(citation_spans_csv_path)
    new_citation_jsonl_sha = sha256(tampered_citations)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  citation_spans.csv"):
            sha_lines.append(f"{new_citation_csv_sha}  citation_spans.csv")
        elif line.endswith("  citation_spans.jsonl"):
            sha_lines.append(f"{new_citation_jsonl_sha}  citation_spans.jsonl")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    result = subprocess.run(verify_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode == 0:
        raise SystemExit("local-audit verifier must reject orphan citation span rows")
    if "citation span references unknown finding" not in result.stderr or "citation span is not referenced by audit_findings.csv" not in result.stderr:
        raise SystemExit("local-audit verifier must name orphan citation span provenance errors")
    citation_spans_csv_path.write_text(original_citation_spans_csv_text, encoding="utf-8")
    tampered_citations.write_text(original_citations, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with citation_spans_csv_path.open(newline="", encoding="utf-8") as handle:
    citation_csv_rows = list(csv.DictReader(handle))
citation_json_rows = [json.loads(line) for line in original_citations.splitlines() if line.strip()]
sarif_path = out_a / "audit_findings.sarif.json"
mmap_path = out_a / "mmap_read_trace.jsonl"
original_sarif_text = sarif_path.read_text(encoding="utf-8")
original_mmap_text_for_citation_span = mmap_path.read_text(encoding="utf-8")
target_idx = None
target_lines = []
for idx, row in enumerate(citation_csv_rows):
    source_path = repo / row["file_path"]
    lines = source_path.read_text(encoding="utf-8", errors="replace").splitlines()
    if int(row["line_start"]) < len(lines):
        target_idx = idx
        target_lines = lines
        break
if target_idx is None:
    raise SystemExit("local-audit multi-line span negative control needs a citation before EOF")
target_csv_row = citation_csv_rows[target_idx]
target_json_row = citation_json_rows[target_idx]
original_target_span_sha = target_csv_row["span_sha256"]
line_start = int(target_csv_row["line_start"])
line_end = line_start + 1
span_text = "\n".join(line.strip() for line in target_lines[line_start - 1:line_end])
new_span_sha = "sha256:" + hashlib.sha256(span_text.encode("utf-8")).hexdigest()
for row in (target_csv_row, target_json_row):
    row["line_end"] = str(line_end)
    row["span_sha256"] = new_span_sha
with citation_spans_csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(citation_csv_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(citation_csv_rows)
tampered_citations.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in citation_json_rows), encoding="utf-8")
sarif_payload = json.loads(original_sarif_text)
for result in sarif_payload["runs"][0]["results"]:
    if result.get("properties", {}).get("finding_id") != target_csv_row["finding_id"]:
        continue
    if result.get("partialFingerprints", {}).get("primaryLocationLineHash") == original_target_span_sha:
        result["partialFingerprints"]["primaryLocationLineHash"] = new_span_sha
    for location in result.get("locations", []):
        physical = location.get("physicalLocation", {})
        artifact = physical.get("artifactLocation", {})
        region = physical.get("region", {})
        if artifact.get("uri") == target_csv_row["file_path"] and str(region.get("startLine")) == str(line_start):
            region["endLine"] = line_end
            physical.setdefault("properties", {})["span_sha256"] = new_span_sha
sarif_path.write_text(json.dumps(sarif_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
mmap_rows = [json.loads(line) for line in original_mmap_text_for_citation_span.splitlines() if line.strip()]
for row in mmap_rows:
    if (
        row.get("finding_id") == target_csv_row["finding_id"]
        and row.get("file_path") == target_csv_row["file_path"]
        and str(row.get("line_start")) == str(line_start)
        and row.get("sha256") == target_csv_row["sha256"]
    ):
        row["span_sha256"] = new_span_sha
mmap_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in mmap_rows), encoding="utf-8")
semantic_payload = json.loads(original_audit_semantic_summary_text)
semantic_payload["artifact_sha256s"]["citation_spans.csv"] = "sha256:" + sha256(citation_spans_csv_path)
digest = hashlib.sha256()
for rel in semantic_payload["semantic_artifacts"]:
    artifact = out_a / rel
    digest.update(rel.encode("utf-8"))
    digest.update(b"\0")
    digest.update(("sha256:" + sha256(artifact)).encode("utf-8") if artifact.is_file() else b"missing")
    digest.update(b"\n")
semantic_payload["semantic_result_sha256"] = "sha256:" + digest.hexdigest()
audit_semantic_summary_path.write_text(json.dumps(semantic_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_citation_csv_sha = sha256(citation_spans_csv_path)
new_citation_jsonl_sha = sha256(tampered_citations)
new_sarif_sha = sha256(sarif_path)
new_mmap_sha = sha256(mmap_path)
new_semantic_summary_sha = sha256(audit_semantic_summary_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  citation_spans.csv"):
        sha_lines.append(f"{new_citation_csv_sha}  citation_spans.csv")
    elif line.endswith("  citation_spans.jsonl"):
        sha_lines.append(f"{new_citation_jsonl_sha}  citation_spans.jsonl")
    elif line.endswith("  audit_findings.sarif.json"):
        sha_lines.append(f"{new_sarif_sha}  audit_findings.sarif.json")
    elif line.endswith("  mmap_read_trace.jsonl"):
        sha_lines.append(f"{new_mmap_sha}  mmap_read_trace.jsonl")
    elif line.endswith("  audit_semantic_summary.json"):
        sha_lines.append(f"{new_semantic_summary_sha}  audit_semantic_summary.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
single_line_span_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if single_line_span_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject widened citation spans")
if "citation span must remain single-line" not in single_line_span_result.stderr:
    raise SystemExit("local-audit verifier must explain widened citation span drift")
citation_spans_csv_path.write_text(original_citation_spans_csv_text, encoding="utf-8")
tampered_citations.write_text(original_citations, encoding="utf-8")
sarif_path.write_text(original_sarif_text, encoding="utf-8")
mmap_path.write_text(original_mmap_text_for_citation_span, encoding="utf-8")
audit_semantic_summary_path.write_text(original_audit_semantic_summary_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with citation_spans_csv_path.open(newline="", encoding="utf-8") as handle:
    citation_csv_rows = list(csv.DictReader(handle))
citation_json_rows = [json.loads(line) for line in original_citations.splitlines() if line.strip()]
if citation_csv_rows and citation_json_rows:
    citation_csv_rows[0]["citation_id"] = citation_csv_rows[0]["citation_id"] + "_tampered"
    citation_json_rows[0]["citation_id"] = citation_json_rows[0]["citation_id"] + "_tampered"
    with citation_spans_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(citation_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(citation_csv_rows)
    tampered_citations.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in citation_json_rows), encoding="utf-8")
    new_citation_csv_sha = sha256(citation_spans_csv_path)
    new_citation_jsonl_sha = sha256(tampered_citations)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  citation_spans.csv"):
            sha_lines.append(f"{new_citation_csv_sha}  citation_spans.csv")
        elif line.endswith("  citation_spans.jsonl"):
            sha_lines.append(f"{new_citation_jsonl_sha}  citation_spans.jsonl")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if result.returncode == 0:
        raise SystemExit("local-audit verifier must reject citation id/order drift")
    if "citation id must bind finding citation order" not in result.stderr:
        raise SystemExit("local-audit verifier must explain citation id/order drift")
    citation_spans_csv_path.write_text(original_citation_spans_csv_text, encoding="utf-8")
    tampered_citations.write_text(original_citations, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

findings_csv_path = out_a / "audit_findings.csv"
audit_findings_json_path = out_a / "audit_findings.json"
audit_findings_path = out_a / "audit_findings.jsonl"
original_findings_csv_text = findings_csv_path.read_text(encoding="utf-8")
original_findings_json_text = audit_findings_json_path.read_text(encoding="utf-8")
original_findings_text = audit_findings_path.read_text(encoding="utf-8")
with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]

standard_json_payload = json.loads(original_findings_json_text)
standard_json_payload["release_ready"] = 1
audit_findings_json_path.write_text(json.dumps(standard_json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_findings_standard_json_sha = sha256(audit_findings_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_findings.json"):
        sha_lines.append(f"{new_findings_standard_json_sha}  audit_findings.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject standard JSON findings readiness drift")
audit_findings_json_path.write_text(original_findings_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

standard_json_payload = json.loads(original_findings_json_text)
if standard_json_payload.get("findings"):
    standard_json_payload["findings"][0]["answer"] = standard_json_payload["findings"][0]["answer"] + " tampered"
    audit_findings_json_path.write_text(json.dumps(standard_json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    new_findings_standard_json_sha = sha256(audit_findings_json_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  audit_findings.json"):
            sha_lines.append(f"{new_findings_standard_json_sha}  audit_findings.json")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject standard JSON findings row drift")
    audit_findings_json_path.write_text(original_findings_json_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

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
tampered_deprecated_language_id = ""
for row in findings_csv_rows:
    if row.get("plugin_id") == "deprecated_api":
        tampered_deprecated_language_id = row["finding_id"]
        row["language"] = "generic"
        break
if tampered_deprecated_language_id:
    for row in finding_json_rows:
        if row["finding_id"] == tampered_deprecated_language_id:
            row["language"] = "generic"
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
    result = subprocess.run(verify_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode == 0:
        raise SystemExit("local-audit verifier must reject multi-plugin finding language drift")
    if "audit finding language does not match referenced plugin rules" not in result.stderr:
        raise SystemExit("local-audit verifier must name multi-plugin rule language drift")
    findings_csv_path.write_text(original_findings_csv_text, encoding="utf-8")
    audit_findings_path.write_text(original_findings_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with findings_csv_path.open(newline="", encoding="utf-8") as handle:
    findings_csv_rows = list(csv.DictReader(handle))
finding_json_rows = [json.loads(line) for line in original_findings_text.splitlines() if line.strip()]
tampered_rule_binding_id = findings_csv_rows[0]["finding_id"] if findings_csv_rows else ""
if tampered_rule_binding_id:
    findings_csv_rows[0]["plugin_rule_ids"] = "missing-rule-id"
    for row in finding_json_rows:
        if row["finding_id"] == tampered_rule_binding_id:
            row["plugin_rule_ids"] = "missing-rule-id"
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
        raise SystemExit("local-audit verifier must reject finding plugin rule provenance drift")
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
missing_plugin_rows = [row for row in findings_csv_rows if row.get("plugin_id") != "missing_evidence"]
missing_plugin_json_rows = [row for row in finding_json_rows if row.get("plugin_id") != "missing_evidence"]
if len(missing_plugin_rows) != len(findings_csv_rows):
    with findings_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(findings_csv_rows[0].keys()), lineterminator="\n")
        writer.writeheader()
        writer.writerows(missing_plugin_rows)
    audit_findings_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in missing_plugin_json_rows), encoding="utf-8")
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
        raise SystemExit("local-audit verifier must reject missing required plugin findings")
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
source_manifest_rows[0]["source_id"] = "src_tampered"
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
source_id_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if source_id_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject source manifest source_id drift")
if "source_manifest source_id must bind row order" not in source_id_result.stderr:
    raise SystemExit("local-audit verifier must explain source manifest source_id drift")
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

audit_dashboard_path = out_a / "AUDIT_DASHBOARD.html"
original_audit_dashboard_text = audit_dashboard_path.read_text(encoding="utf-8")
audit_dashboard_path.write_text(
    original_audit_dashboard_text.replace('data-release-ready="0"', 'data-release-ready="1"', 1),
    encoding="utf-8",
)
new_audit_dashboard_sha = sha256(audit_dashboard_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  AUDIT_DASHBOARD.html"):
        sha_lines.append(f"{new_audit_dashboard_sha}  AUDIT_DASHBOARD.html")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit dashboard readiness drift")
audit_dashboard_path.write_text(original_audit_dashboard_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

audit_dashboard_json_path = out_a / "audit_dashboard.json"
original_audit_dashboard_json_text = audit_dashboard_json_path.read_text(encoding="utf-8")
audit_dashboard_json_payload = json.loads(original_audit_dashboard_json_text)

if audit_dashboard_json_payload["top_findings"]:
    original_preview = audit_dashboard_json_payload["top_findings"][0]["answer_preview"]
    escaped_preview = html.escape(original_preview, quote=True)
    if escaped_preview not in original_audit_dashboard_text:
        raise SystemExit("audit dashboard HTML test fixture must include the top finding answer preview")
    audit_dashboard_path.write_text(
        original_audit_dashboard_text.replace(escaped_preview, "tampered dashboard answer preview", 1),
        encoding="utf-8",
    )
    new_audit_dashboard_sha = sha256(audit_dashboard_path)
    sha_lines = []
    for line in original_sha_manifest_text.splitlines():
        if line.endswith("  AUDIT_DASHBOARD.html"):
            sha_lines.append(f"{new_audit_dashboard_sha}  AUDIT_DASHBOARD.html")
        else:
            sha_lines.append(line)
    sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
    if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        raise SystemExit("local-audit verifier must reject audit dashboard HTML answer-preview drift")
    audit_dashboard_path.write_text(original_audit_dashboard_text, encoding="utf-8")
    sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

audit_dashboard_json_payload["diff_counts"]["manual_review_required_rows"] += 1
audit_dashboard_json_path.write_text(json.dumps(audit_dashboard_json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_audit_dashboard_json_sha = sha256(audit_dashboard_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_dashboard.json"):
        sha_lines.append(f"{new_audit_dashboard_json_sha}  audit_dashboard.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit dashboard JSON diff-count drift")
audit_dashboard_json_path.write_text(original_audit_dashboard_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

audit_dashboard_json_payload = json.loads(original_audit_dashboard_json_text)
audit_dashboard_json_payload["readiness"]["release_ready"] = 1
audit_dashboard_json_path.write_text(json.dumps(audit_dashboard_json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_audit_dashboard_json_sha = sha256(audit_dashboard_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_dashboard.json"):
        sha_lines.append(f"{new_audit_dashboard_json_sha}  audit_dashboard.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit dashboard JSON readiness drift")
audit_dashboard_json_path.write_text(original_audit_dashboard_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

audit_dashboard_json_payload = json.loads(original_audit_dashboard_json_text)
audit_dashboard_json_payload["readiness"]["design_partner_beta_candidate_ready"] = 1
audit_dashboard_json_path.write_text(json.dumps(audit_dashboard_json_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_audit_dashboard_json_sha = sha256(audit_dashboard_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_dashboard.json"):
        sha_lines.append(f"{new_audit_dashboard_json_sha}  audit_dashboard.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject audit dashboard design-partner readiness drift")
audit_dashboard_json_path.write_text(original_audit_dashboard_json_text, encoding="utf-8")
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
bad_resource_schema_path = out_a / "tampered_resource_envelope.json"
bad_resource_schema = json.loads(original_resource_text)
bad_resource_schema["external_network_used"] = 1
bad_resource_schema_path.write_text(json.dumps(bad_resource_schema, indent=2, sort_keys=True) + "\n", encoding="utf-8")
resource_schema_cmd = [
    str(root / "tools/validate_json_schemas.py"),
    "--schema-instance",
    str(root / "schemas/local_repo_audit_resource_envelope.schema.json"),
    str(bad_resource_schema_path),
]
if subprocess.run(resource_schema_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("resource envelope schema must reject external network usage")
bad_resource_schema_path.unlink()

import importlib.util

spec = importlib.util.spec_from_file_location("verify_local_audit", root / "tools" / "verify_local_audit.py")
verify_local_audit = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(verify_local_audit)
source_rows = list(csv.DictReader((out_a / "source_manifest.csv").open(newline="", encoding="utf-8")))
finding_rows = list(csv.DictReader((out_a / "audit_findings.csv").open(newline="", encoding="utf-8")))
resource_payload = json.loads(original_resource_text)
source_byte_values = [int(row["bytes"]) for row in source_rows]
budget_checks = []
if len(source_rows) > 1:
    budget_checks.append(("source files exceed max_files budget", {"max_files": len(source_rows) - 1}))
if sum(source_byte_values) > 1:
    budget_checks.append(("source files exceed max_total_bytes budget", {"max_total_bytes": sum(source_byte_values) - 1}))
if max(source_byte_values) > 1:
    budget_checks.append(("source file exceeds max_file_bytes budget", {"max_file_bytes": max(source_byte_values) - 1}))
if len(finding_rows) > 1:
    budget_checks.append(("finding rows exceed max_findings budget", {"max_findings": len(finding_rows) - 1}))
if len(budget_checks) < 4:
    raise SystemExit("budget verifier fixture must contain enough rows and bytes to exercise split budget checks")
for expected_error, updates in budget_checks:
    candidate = dict(resource_payload)
    candidate.update(updates)
    errors = []
    verify_local_audit.verify_budget_envelope(out_a, candidate, errors)
    if not any(expected_error in error for error in errors):
        raise SystemExit(f"budget verifier must reject {expected_error}")

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
latency_rows[0]["latency_ms"] = "0"
latency_rows[0]["latency_source"] = "deterministic-local-smoke"
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
    raise SystemExit("local-audit verifier must reject unmeasured latency rows")
latency_path.write_text(original_latency_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

with latency_path.open(newline="", encoding="utf-8") as handle:
    latency_rows = list(csv.DictReader(handle))
latency_rows[0]["latency_ms"] = str(int(latency_rows[0]["latency_ms"]) + 7)
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
latency_share_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if latency_share_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject latency phase-share drift")
if "latency rows must bind measured plugin phase share" not in latency_share_result.stderr:
    raise SystemExit("local-audit verifier must explain latency phase-share drift")
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

with accuracy_path.open(newline="", encoding="utf-8") as handle:
    accuracy_rows = list(csv.DictReader(handle))
accuracy_rows[0]["accuracy_label"] = "reviewed_true_positive"
with accuracy_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(accuracy_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(accuracy_rows)
accuracy_json = json.loads(original_accuracy_json_text)
accuracy_json["rows"] = accuracy_rows
accuracy_json_path.write_text(json.dumps(accuracy_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_accuracy_sha = sha256(accuracy_path)
new_accuracy_json_sha = sha256(accuracy_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  accuracy_rows.csv"):
        sha_lines.append(f"{new_accuracy_sha}  accuracy_rows.csv")
    elif line.endswith("  accuracy_rows.json"):
        sha_lines.append(f"{new_accuracy_json_sha}  accuracy_rows.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
accuracy_label_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if accuracy_label_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject reviewed accuracy labels")
if "accuracy rows must not claim reviewed labels" not in accuracy_label_result.stderr:
    raise SystemExit("local-audit verifier must explain reviewed accuracy label drift")
accuracy_path.write_text(original_accuracy_text, encoding="utf-8")
accuracy_json_path.write_text(original_accuracy_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

citation_path = out_a / "citation_correctness_rows.csv"
original_citation_text = citation_path.read_text(encoding="utf-8")
with citation_path.open(newline="", encoding="utf-8") as handle:
    citation_rows = list(csv.DictReader(handle))
tampered_citation_row = citation_rows[0]
if tampered_citation_row["citation_count"] == "0":
    tampered_citation_row["citation_count"] = "1"
    tampered_citation_row["citation_bound"] = "1"
else:
    tampered_citation_row["citation_count"] = "0"
    tampered_citation_row["citation_bound"] = "0"
with citation_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(citation_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(citation_rows)
citation_json = json.loads(original_citation_json_text)
citation_json["rows"] = citation_rows
citation_json_path.write_text(json.dumps(citation_json, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_citation_sha = sha256(citation_path)
new_citation_json_sha = sha256(citation_json_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  citation_correctness_rows.csv"):
        sha_lines.append(f"{new_citation_sha}  citation_correctness_rows.csv")
    elif line.endswith("  citation_correctness_rows.json"):
        sha_lines.append(f"{new_citation_json_sha}  citation_correctness_rows.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
citation_binding_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if citation_binding_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject citation correctness count/bound drift")
if "citation correctness rows must bind finding citations" not in citation_binding_result.stderr:
    raise SystemExit("local-audit verifier must explain citation correctness binding drift")
citation_path.write_text(original_citation_text, encoding="utf-8")
citation_json_path.write_text(original_citation_json_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

fp_path = out_a / "false_positive_candidate_rows.csv"
original_fp_text = fp_path.read_text(encoding="utf-8")
with (out_a / "audit_findings.csv").open(newline="", encoding="utf-8") as handle:
    finding_rows_for_fp = list(csv.DictReader(handle))
severity_by_finding = {row["finding_id"]: row["severity"] for row in finding_rows_for_fp}
with fp_path.open(newline="", encoding="utf-8") as handle:
    fp_rows = list(csv.DictReader(handle))
tampered_fp_row = None
for row in fp_rows:
    expected_candidate = "1" if severity_by_finding[row["finding_id"]] in {"medium", "high"} else "0"
    row["manual_review_required"] = "1"
    if row["false_positive_candidate"] == expected_candidate:
        row["false_positive_candidate"] = "0" if expected_candidate == "1" else "1"
        tampered_fp_row = row
        break
if tampered_fp_row is None:
    raise SystemExit("local-audit false-positive binding negative control needs a tamperable row")
with fp_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(fp_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(fp_rows)
new_fp_sha = sha256(fp_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  false_positive_candidate_rows.csv"):
        sha_lines.append(f"{new_fp_sha}  false_positive_candidate_rows.csv")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
fp_binding_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if fp_binding_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject false-positive candidate severity drift")
if "false-positive candidate rows must bind finding severity" not in fp_binding_result.stderr:
    raise SystemExit("local-audit verifier must explain false-positive severity binding drift")
fp_path.write_text(original_fp_text, encoding="utf-8")
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

with hint_path.open(newline="", encoding="utf-8") as handle:
    hint_rows = list(csv.DictReader(handle))
with generation_path.open(newline="", encoding="utf-8") as handle:
    generation_rows = list(csv.DictReader(handle))
lineage_rows = [json.loads(line) for line in original_lineage_text.splitlines() if line.strip()]
if len(hint_rows) < 2 or len(generation_rows) < 2 or len(lineage_rows) < 2:
    raise SystemExit("local-audit route/generation ID swap negative control needs at least two findings")
hint_rows[0]["hint_id"], hint_rows[1]["hint_id"] = hint_rows[1]["hint_id"], hint_rows[0]["hint_id"]
generation_rows[0]["generation_id"], generation_rows[1]["generation_id"] = (
    generation_rows[1]["generation_id"],
    generation_rows[0]["generation_id"],
)
hint_id_by_finding = {row["finding_id"]: row["hint_id"] for row in hint_rows}
generation_id_by_finding = {row["finding_id"]: row["generation_id"] for row in generation_rows}
for row in generation_rows:
    row["hint_id"] = hint_id_by_finding[row["finding_id"]]
for row in lineage_rows:
    row["compact_route_hint_id"] = hint_id_by_finding[row["finding_id"]]
    row["generator_id"] = generation_id_by_finding[row["finding_id"]]
with hint_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(hint_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(hint_rows)
with generation_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(generation_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(generation_rows)
lineage_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
new_hint_sha = sha256(hint_path)
new_generation_sha = sha256(generation_path)
new_lineage_sha = sha256(lineage_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  compact_route_hint_rows.csv"):
        sha_lines.append(f"{new_hint_sha}  compact_route_hint_rows.csv")
    elif line.endswith("  grounded_generation_rows.csv"):
        sha_lines.append(f"{new_generation_sha}  grounded_generation_rows.csv")
    elif line.endswith("  prediction_lineage.jsonl"):
        sha_lines.append(f"{new_lineage_sha}  prediction_lineage.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
route_generation_swap_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if route_generation_swap_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject coordinated route/generation ID swaps")
if "route hint id/finding binding drift" not in route_generation_swap_result.stderr:
    raise SystemExit("local-audit verifier must explain route hint/finding binding drift")
hint_path.write_text(original_hint_text, encoding="utf-8")
generation_path.write_text(original_generation_text, encoding="utf-8")
lineage_path.write_text(original_lineage_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

lineage_rows = [json.loads(line) for line in original_lineage_text.splitlines() if line.strip()]
if len(lineage_rows) < 2:
    raise SystemExit("local-audit lineage route-index negative control needs at least two findings")
lineage_rows[0]["route_index_row"] = lineage_rows[1]["route_index_row"]
lineage_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
new_lineage_sha = sha256(lineage_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  prediction_lineage.jsonl"):
        sha_lines.append(f"{new_lineage_sha}  prediction_lineage.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
route_index_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if route_index_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject lineage route index/finding drift")
if "lineage route index/finding binding drift" not in route_index_result.stderr:
    raise SystemExit("local-audit verifier must explain lineage route index/finding drift")
lineage_path.write_text(original_lineage_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

lineage_rows = [json.loads(line) for line in original_lineage_text.splitlines() if line.strip()]
lineage_rows[0]["schema_drift_probe"] = "extra"
lineage_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
new_lineage_sha = sha256(lineage_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  prediction_lineage.jsonl"):
        sha_lines.append(f"{new_lineage_sha}  prediction_lineage.jsonl")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
lineage_schema_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
if lineage_schema_result.returncode == 0:
    raise SystemExit("local-audit verifier must reject prediction lineage JSONL key drift")
if "jsonl contract actual keys drift: prediction_lineage.jsonl" not in lineage_schema_result.stderr:
    raise SystemExit("local-audit verifier must explain prediction lineage JSONL key drift")
lineage_path.write_text(original_lineage_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

mmap_path = out_a / "mmap_read_trace.jsonl"
original_mmap_text = mmap_path.read_text(encoding="utf-8")
mmap_rows = [json.loads(line) for line in original_mmap_text.splitlines() if line.strip()]
mmap_rows[0]["span_sha256"] = "sha256:" + ("0" * 64)
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
    raise SystemExit("local-audit verifier must reject mmap trace span sha drift")
mmap_path.write_text(original_mmap_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

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

with guard_path.open(newline="", encoding="utf-8") as handle:
    guard_rows = list(csv.DictReader(handle))
if len(guard_rows) >= 2:
    guard_rows[0]["guard_id"], guard_rows[1]["guard_id"] = guard_rows[1]["guard_id"], guard_rows[0]["guard_id"]
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
    guard_swap_result = subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if guard_swap_result.returncode == 0:
        raise SystemExit("local-audit verifier must reject swapped wrong-answer guard ids")
    if "wrong_answer_guard_rows.csv guard_id must bind finding_id" not in guard_swap_result.stderr:
        raise SystemExit("local-audit verifier must explain wrong-answer guard id binding drift")
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

semantic_summary_path = out_a / "audit_semantic_summary.json"
original_semantic_summary_text = semantic_summary_path.read_text(encoding="utf-8")
semantic_summary = json.loads(original_semantic_summary_text)
semantic_summary["semantic_result_sha256"] = "sha256:" + ("0" * 64)
semantic_summary_path.write_text(json.dumps(semantic_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
new_semantic_summary_sha = sha256(semantic_summary_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  audit_semantic_summary.json"):
        sha_lines.append(f"{new_semantic_summary_sha}  audit_semantic_summary.json")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject semantic summary hash drift")
semantic_summary_path.write_text(original_semantic_summary_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

tampered_manifest = json.loads(original_manifest_text)
tampered_manifest["schema_sha256s"].pop("schemas/local_repo_audit_suppressions.schema.json", None)
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
    raise SystemExit("local-audit verifier must reject missing suppression schema sha binding")
manifest_path.write_text(original_manifest_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

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

label_template_out = out_a.parent / "label_template_negative"
subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_template.py"),
        "--audit-output",
        str(out_a),
        "--out",
        str(label_template_out),
        "--case-id",
        "negative_case",
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
subprocess.run(
    [str(root / "scripts/audit_my_repo_label_template.py"), "--verify-existing", str(label_template_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)
label_template_json_path = label_template_out / "label_template.json"
original_label_template_json_text = label_template_json_path.read_text(encoding="utf-8")
label_template_payload = json.loads(original_label_template_json_text)
if not label_template_payload["rows"]:
    raise SystemExit("negative label template fixture must contain candidate rows")
if any(row["synthetic"] != "1" for row in label_template_payload["rows"]):
    raise SystemExit("fixture namespace label templates must stay synthetic/non-real evidence")
label_template_manifest_payload = json.loads((label_template_out / "label_template_manifest.json").read_text(encoding="utf-8"))
if label_template_manifest_payload["input_audit_namespace"] != "fixture":
    raise SystemExit("negative label template fixture must bind fixture namespace")
if label_template_manifest_payload["input_audit_real_benchmark_namespace_confirmed"] != 0:
    raise SystemExit("fixture label template must not carry real benchmark namespace confirmation")
label_template_payload["rows"][0]["human_labeled"] = "1"
label_template_json_path.write_text(json.dumps(label_template_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
if subprocess.run(
    [str(root / "scripts/audit_my_repo_label_template.py"), "--verify-existing", str(label_template_out)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode == 0:
    raise SystemExit("label-template verifier must reject rows that claim human_labeled=1")
label_template_json_path.write_text(original_label_template_json_text, encoding="utf-8")
subprocess.run(
    [str(root / "scripts/audit_my_repo_label_template.py"), "--verify-existing", str(label_template_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)

label_template_sha_path = label_template_out / "label_template_sha256sums.txt"
original_label_template_sha_text = label_template_sha_path.read_text(encoding="utf-8")
sha_lines = []
for line in original_label_template_sha_text.splitlines():
    if line.endswith("  label_template.json"):
        sha_lines.append(("0" * 64) + "  label_template.json")
    else:
        sha_lines.append(line)
label_template_sha_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(
    [str(root / "scripts/audit_my_repo_label_template.py"), "--verify-existing", str(label_template_out)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode == 0:
    raise SystemExit("label-template verifier must reject sha manifest drift")
label_template_sha_path.write_text(original_label_template_sha_text, encoding="utf-8")
subprocess.run(
    [str(root / "scripts/audit_my_repo_label_template.py"), "--verify-existing", str(label_template_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)

label_template_nonempty = out_a.parent / "label_template_nonempty"
label_template_nonempty.mkdir()
(label_template_nonempty / "sentinel.txt").write_text("keep", encoding="utf-8")
nonempty_result = subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_template.py"),
        "--audit-output",
        str(out_a),
        "--out",
        str(label_template_nonempty),
        "--case-id",
        "negative_case",
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
if nonempty_result.returncode != 2:
    raise SystemExit("label-template writer must refuse non-empty output without --overwrite")
if (label_template_nonempty / "sentinel.txt").read_text(encoding="utf-8") != "keep":
    raise SystemExit("label-template non-overwrite refusal must preserve unrelated files")
if (label_template_nonempty / "label_template.json").exists():
    raise SystemExit("label-template non-overwrite refusal must not expose managed artifacts")

label_template_fail_out = out_a.parent / "label_template_fail_before_verify"
env = os.environ.copy()
env["AUDIT_MY_REPO_LABEL_TEMPLATE_TAMPER_BEFORE_VERIFY"] = "1"
tamper_result = subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_template.py"),
        "--audit-output",
        str(out_a),
        "--out",
        str(label_template_fail_out),
        "--case-id",
        "negative_case",
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    env=env,
)
if tamper_result.returncode != 1:
    raise SystemExit("label-template writer must fail when self-verification detects tampering")
if label_template_fail_out.exists():
    raise SystemExit("label-template self-verification failure must not publish managed output")

label_intake_decisions = out_a.parent / "label_intake_decisions.jsonl"
template_rows = json.loads(original_label_template_json_text)["rows"]
selected_template_row = None
for row in template_rows:
    if row["expected_line_start"] and row["expected_span_sha256"] and row["suggested_expected_abstain"] == "0":
        selected_template_row = row
        break
if selected_template_row is None:
    raise SystemExit("negative label intake fixture must contain a cited non-abstain candidate")
valid_decision = {
    "candidate_label_id": selected_template_row["candidate_label_id"],
    "human_labeled": True,
    "expected": "present",
    "expected_abstain": selected_template_row["suggested_expected_abstain"],
    "priority": "P1",
    "reviewer_id": "negative-reviewer-one",
}
label_intake_decisions.write_text(json.dumps(valid_decision, sort_keys=True) + "\n", encoding="utf-8")
label_intake_out = out_a.parent / "label_intake_negative"
subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(label_intake_decisions),
        "--out",
        str(label_intake_out),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
subprocess.run(
    [str(root / "scripts/audit_my_repo_label_intake.py"), "--verify-existing", str(label_intake_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)
intake_rows = [json.loads(line) for line in (label_intake_out / "benchmark_labels.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
intake_manifest_payload = json.loads((label_intake_out / "label_intake_manifest.json").read_text(encoding="utf-8"))
if len(intake_rows) != 1 or intake_rows[0]["synthetic"] is not True:
    raise SystemExit("fixture-derived label intake rows must stay synthetic/non-real evidence")
if intake_manifest_payload["synthetic_label_rows"] != 1:
    raise SystemExit("fixture-derived label intake manifest must count synthetic labels")

label_intake_benchmark_out = out_a.parent / "label_intake_benchmark_negative"
subprocess.run(
    [
        str(root / "scripts/audit_my_repo_benchmark.py"),
        "--label-intake",
        str(label_intake_out),
        "--out",
        str(label_intake_benchmark_out),
        "--mode",
        "quick",
        "--namespace",
        "synthetic",
        "--max-files",
        "20",
        "--max-total-bytes",
        "200000",
        "--max-file-bytes",
        "50000",
        "--max-findings",
        "40",
        "--no-rerun-check",
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
subprocess.run(
    [str(root / "scripts/audit_my_repo_benchmark.py"), "--verify-existing", str(label_intake_benchmark_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)
label_intake_benchmark_manifest_path = label_intake_benchmark_out / "benchmark_manifest.json"
label_intake_benchmark_sha_path = label_intake_benchmark_out / "benchmark_sha256sums.txt"
label_intake_benchmark_manifest_text = label_intake_benchmark_manifest_path.read_text(encoding="utf-8")
label_intake_benchmark_sha_text = label_intake_benchmark_sha_path.read_text(encoding="utf-8")
label_intake_benchmark_manifest = json.loads(label_intake_benchmark_manifest_text)
if label_intake_benchmark_manifest["label_source_kind"] != "label_intake":
    raise SystemExit("label-intake benchmark must bind label_source_kind=label_intake")
if label_intake_benchmark_manifest["label_intake_output"] != str(label_intake_out):
    raise SystemExit("label-intake benchmark must bind the intake output path")
if label_intake_benchmark_manifest["labels_input"] != str(label_intake_out / "benchmark_labels.jsonl"):
    raise SystemExit("label-intake benchmark must use benchmark_labels.jsonl from the intake bundle")
if label_intake_benchmark_manifest["label_intake_manifest_sha256"] != "sha256:" + sha256(label_intake_out / "label_intake_manifest.json"):
    raise SystemExit("label-intake benchmark must bind the intake manifest sha")
if label_intake_benchmark_manifest["label_intake_sha256sums_sha256"] != "sha256:" + sha256(label_intake_out / "label_intake_sha256sums.txt"):
    raise SystemExit("label-intake benchmark must bind the intake sha manifest sha")
tampered_label_intake_benchmark_manifest = dict(label_intake_benchmark_manifest)
tampered_label_intake_benchmark_manifest["label_intake_manifest_sha256"] = "sha256:" + ("0" * 64)
label_intake_benchmark_manifest_path.write_text(
    json.dumps(tampered_label_intake_benchmark_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
updated_manifest_sha = sha256(label_intake_benchmark_manifest_path)
label_intake_benchmark_sha_lines = []
for line in label_intake_benchmark_sha_text.splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    label_intake_benchmark_sha_lines.append(f"{updated_manifest_sha if rel == 'benchmark_manifest.json' else digest}  {rel}")
label_intake_benchmark_sha_path.write_text("\n".join(label_intake_benchmark_sha_lines) + "\n", encoding="utf-8")
if subprocess.run(
    [str(root / "scripts/audit_my_repo_benchmark.py"), "--verify-existing", str(label_intake_benchmark_out)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode == 0:
    raise SystemExit("benchmark verifier must reject label intake manifest sha drift")
label_intake_benchmark_manifest_path.write_text(label_intake_benchmark_manifest_text, encoding="utf-8")
label_intake_benchmark_sha_path.write_text(label_intake_benchmark_sha_text, encoding="utf-8")
subprocess.run(
    [str(root / "scripts/audit_my_repo_benchmark.py"), "--verify-existing", str(label_intake_benchmark_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)

bad_decisions = out_a.parent / "label_intake_bad_decisions.jsonl"
bad_payload = dict(valid_decision)
bad_payload["human_labeled"] = False
bad_decisions.write_text(json.dumps(bad_payload, sort_keys=True) + "\n", encoding="utf-8")
if subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(bad_decisions),
        "--out",
        str(out_a.parent / "label_intake_bad_decisions_out"),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode != 2:
    raise SystemExit("label-intake writer must reject decisions without human_labeled=true")

unknown_decisions = out_a.parent / "label_intake_unknown_decisions.jsonl"
unknown_payload = dict(valid_decision)
unknown_payload["candidate_label_id"] = "missing_candidate"
unknown_decisions.write_text(json.dumps(unknown_payload, sort_keys=True) + "\n", encoding="utf-8")
if subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(unknown_decisions),
        "--out",
        str(out_a.parent / "label_intake_unknown_out"),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode != 2:
    raise SystemExit("label-intake writer must reject unknown candidate_label_id decisions")

duplicate_decisions = out_a.parent / "label_intake_duplicate_decisions.jsonl"
duplicate_decisions.write_text(
    json.dumps(valid_decision, sort_keys=True) + "\n" + json.dumps(valid_decision, sort_keys=True) + "\n",
    encoding="utf-8",
)
if subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(duplicate_decisions),
        "--out",
        str(out_a.parent / "label_intake_duplicate_out"),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode != 2:
    raise SystemExit("label-intake writer must reject duplicate candidate decisions")

bad_priority_decisions = out_a.parent / "label_intake_bad_priority_decisions.jsonl"
bad_priority_payload = dict(valid_decision)
bad_priority_payload["priority"] = "urgent"
bad_priority_decisions.write_text(json.dumps(bad_priority_payload, sort_keys=True) + "\n", encoding="utf-8")
if subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(bad_priority_decisions),
        "--out",
        str(out_a.parent / "label_intake_bad_priority_out"),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode != 2:
    raise SystemExit("label-intake writer must reject malformed priority values")

intake_labels_path = label_intake_out / "benchmark_labels.jsonl"
if subprocess.run(
    [
        str(root / "scripts/audit_my_repo_benchmark.py"),
        "--labels",
        str(intake_labels_path),
        "--label-intake",
        str(label_intake_out),
        "--out",
        str(out_a.parent / "label_intake_benchmark_conflict"),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode != 2:
    raise SystemExit("benchmark writer must reject simultaneous --labels and --label-intake")
intake_manifest_path = label_intake_out / "label_intake_manifest.json"
intake_sha_path = label_intake_out / "label_intake_sha256sums.txt"
original_intake_labels_text = intake_labels_path.read_text(encoding="utf-8")
original_intake_manifest_text = intake_manifest_path.read_text(encoding="utf-8")
original_intake_sha_text = intake_sha_path.read_text(encoding="utf-8")
tampered_labels = [json.loads(line) for line in original_intake_labels_text.splitlines() if line.strip()]
tampered_labels[0]["expected"] = "absent"
intake_labels_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in tampered_labels), encoding="utf-8")
tampered_manifest = json.loads(original_intake_manifest_text)
tampered_manifest["artifact_sha256s"]["benchmark_labels.jsonl"] = "sha256:" + sha256(intake_labels_path)
intake_manifest_path.write_text(json.dumps(tampered_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
intake_updates = {
    "benchmark_labels.jsonl": sha256(intake_labels_path),
    "label_intake_manifest.json": sha256(intake_manifest_path),
}
intake_sha_lines = []
for line in original_intake_sha_text.splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    intake_sha_lines.append(f"{intake_updates.get(rel, digest)}  {rel}")
intake_sha_path.write_text("\n".join(intake_sha_lines) + "\n", encoding="utf-8")
if subprocess.run(
    [str(root / "scripts/audit_my_repo_label_intake.py"), "--verify-existing", str(label_intake_out)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode == 0:
    raise SystemExit("label-intake verifier must reject coordinated benchmark label drift")
intake_labels_path.write_text(original_intake_labels_text, encoding="utf-8")
intake_manifest_path.write_text(original_intake_manifest_text, encoding="utf-8")
intake_sha_path.write_text(original_intake_sha_text, encoding="utf-8")
subprocess.run(
    [str(root / "scripts/audit_my_repo_label_intake.py"), "--verify-existing", str(label_intake_out)],
    check=True,
    stdout=subprocess.DEVNULL,
)

label_intake_nonempty = out_a.parent / "label_intake_nonempty"
label_intake_nonempty.mkdir()
(label_intake_nonempty / "sentinel.txt").write_text("keep", encoding="utf-8")
nonempty_intake_result = subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(label_intake_decisions),
        "--out",
        str(label_intake_nonempty),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
if nonempty_intake_result.returncode != 2:
    raise SystemExit("label-intake writer must refuse non-empty output without --overwrite")
if (label_intake_nonempty / "sentinel.txt").read_text(encoding="utf-8") != "keep":
    raise SystemExit("label-intake non-overwrite refusal must preserve unrelated files")

label_intake_fail_out = out_a.parent / "label_intake_fail_before_verify"
env = os.environ.copy()
env["AUDIT_MY_REPO_LABEL_INTAKE_TAMPER_BEFORE_VERIFY"] = "1"
tamper_intake_result = subprocess.run(
    [
        str(root / "scripts/audit_my_repo_label_intake.py"),
        "--template",
        str(label_template_out),
        "--decisions",
        str(label_intake_decisions),
        "--out",
        str(label_intake_fail_out),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    env=env,
)
if tamper_intake_result.returncode != 1:
    raise SystemExit("label-intake writer must fail when self-verification detects tampering")
if label_intake_fail_out.exists():
    raise SystemExit("label-intake self-verification failure must not publish managed output")

reproduce_path = out_a / "reproduce.sh"
original_reproduce_text = reproduce_path.read_text(encoding="utf-8")
reproduce_lines = original_reproduce_text.splitlines()
reproduce_lines[2] = "cd /tmp"
reproduce_path.write_text("\n".join(reproduce_lines) + "\n", encoding="utf-8")
new_reproduce_sha = sha256(reproduce_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  reproduce.sh"):
        sha_lines.append(f"{new_reproduce_sha}  reproduce.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject reproduce.sh repo-root cd drift")
reproduce_path.write_text(original_reproduce_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

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

reproduce_path.write_text(original_reproduce_text.replace(" --max-findings 12", " --max-findings 11"), encoding="utf-8")
new_reproduce_sha = sha256(reproduce_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  reproduce.sh"):
        sha_lines.append(f"{new_reproduce_sha}  reproduce.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject reproduce.sh max-findings drift")
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

verify_script_path = out_a / "verify.sh"
original_verify_script_text = verify_script_path.read_text(encoding="utf-8")
verify_script_lines = original_verify_script_text.splitlines()
verify_script_lines[2] = "cd /tmp"
verify_script_path.write_text("\n".join(verify_script_lines) + "\n", encoding="utf-8")
new_verify_script_sha = sha256(verify_script_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  verify.sh"):
        sha_lines.append(f"{new_verify_script_sha}  verify.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject verify.sh repo-root cd drift")
verify_script_path.write_text(original_verify_script_text, encoding="utf-8")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

verify_script_path.write_text(original_verify_script_text.replace(" --verify-existing ", " --version "), encoding="utf-8")
new_verify_script_sha = sha256(verify_script_path)
sha_lines = []
for line in original_sha_manifest_text.splitlines():
    if line.endswith("  verify.sh"):
        sha_lines.append(f"{new_verify_script_sha}  verify.sh")
    else:
        sha_lines.append(line)
sha_manifest_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must reject verify.sh command drift")
verify_script_path.write_text(original_verify_script_text, encoding="utf-8")
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
        str(question_cache_out),
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
manifest_b = json.loads((question_cache_out / "audit_manifest.json").read_text(encoding="utf-8"))
if manifest_b["cache_key"] == manifest["cache_key"]:
    raise SystemExit("cache key must change when the user question changes")

same_input_rerun_out = out_a.parent / "same_input_rerun_out"
subprocess.run(
    [
        str(root / "scripts/audit_my_repo.sh"),
        str(repo),
        "--mode",
        "quick",
        "--max-queries",
        "12",
        "--out",
        str(same_input_rerun_out),
        "--namespace",
        "fixture",
        "--question",
        "Can I ship this as production ready?",
        "--generator",
        "routehint-tiny",
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
manifest_same = json.loads((same_input_rerun_out / "audit_manifest.json").read_text(encoding="utf-8"))
semantic_same = json.loads((same_input_rerun_out / "audit_semantic_summary.json").read_text(encoding="utf-8"))
semantic_original = json.loads(original_semantic_summary_text)
if manifest_same["cache_key"] != manifest["cache_key"]:
    raise SystemExit("same input rerun must produce the same cache key")
if semantic_same["semantic_result_sha256"] != semantic_original["semantic_result_sha256"]:
    raise SystemExit("same input rerun must produce the same semantic result sha")
if json.loads((question_cache_out / "audit_semantic_summary.json").read_text(encoding="utf-8"))["semantic_result_sha256"] == semantic_original["semantic_result_sha256"]:
    raise SystemExit("different question must change the semantic result sha")
PY

echo "audit_my_repo negative controls passed"
