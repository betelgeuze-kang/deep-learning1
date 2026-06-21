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
python3 - "$TMP_DIR/plugins.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
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
}
if set(plugins) != set(expected):
    raise SystemExit(f"plugin registry mismatch: {sorted(plugins)}")
for plugin_id, module in expected.items():
    if plugins[plugin_id].get("module") != module:
        raise SystemExit(f"plugin registry module mismatch for {plugin_id}")
if plugins["deprecated_api"]["language"] != "multi":
    raise SystemExit("deprecated_api plugin must advertise multi-language coverage")
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
expect_audit_exit 2 "unsupported generator must fail with stable usage exit code" "$repo" --generator unsupported --out "$TMP_DIR/bad_generator"
expect_audit_exit 2 "non-positive max queries must fail with stable usage exit code" "$repo" --max-queries 0 --out "$TMP_DIR/bad_queries"
expect_audit_exit 2 "missing target repo must fail with stable usage exit code" "$TMP_DIR/missing" --out "$TMP_DIR/bad_target"
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
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_registry.schema.json" "$out_a/plugin_registry.json" >/dev/null
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
plugin_registry = json.loads((out_a / "plugin_registry.json").read_text(encoding="utf-8"))
if plugin_registry["tool_version"] != manifest["tool_version"]:
    raise SystemExit("plugin registry must be bound to the manifest tool version")
expected_plugin_modules = {
    "doc_code_identity": "auditor_plugin_doc_code_identity",
    "deprecated_api": "auditor_plugin_deprecated_api",
    "config_consistency": "auditor_plugin_config_consistency",
    "unsupported_claim": "auditor_plugin_unsupported_claim",
    "missing_evidence": "auditor_plugin_missing_evidence",
}
plugin_modules = {row["plugin_id"]: row.get("module") for row in plugin_registry["plugins"]}
if plugin_modules != expected_plugin_modules:
    raise SystemExit("fixture audit output must bind the deterministic plugin registry")
if manifest["plugin_registry_sha256"] != "sha256:" + sha256(out_a / "plugin_registry.json"):
    raise SystemExit("manifest must bind plugin registry sha256")
if manifest["namespace"] != "fixture":
    raise SystemExit("negative-control fixture must not be promoted out of fixture namespace")
if manifest["real_benchmark_namespace_confirmed"] != 0:
    raise SystemExit("fixture namespace must not carry real_benchmark confirmation")
if manifest["fixture_result_promoted"] != 0 or manifest["real_evidence_claimed"] != 0:
    raise SystemExit("fixture output must not be promoted or claimed as real evidence")
if manifest["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("claim boundary must remain alpha-only")
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
verify_cmd = [str(root / "tools/verify_local_audit.py"), str(out_a)]
if subprocess.run(verify_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit("local-audit verifier must require abstain_rows.csv in sha256sums.txt")
sha_manifest_path.write_text(original_sha_manifest_text, encoding="utf-8")

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
