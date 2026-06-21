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

git -C "$repo" init -q
git -C "$repo" add README.md pyproject.toml legacy.py legacy.cpp legacy.js
git -C "$repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init

if [[ "$("$ROOT_DIR/scripts/audit_my_repo.sh" --version)" != "audit_my_repo_alpha.v1" ]]; then
  echo "audit entrypoint must expose a stable tool version" >&2
  exit 8
fi
"$ROOT_DIR/scripts/audit_my_repo.sh" --list-plugins >"$TMP_DIR/plugins.json"
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
    "doc_code_identity",
    "deprecated_api",
    "config_consistency",
    "unsupported_claim",
    "missing_evidence",
}
if set(plugins) != expected:
    raise SystemExit(f"plugin registry mismatch: {sorted(plugins)}")
if plugins["deprecated_api"]["language"] != "multi":
    raise SystemExit("deprecated_api plugin must advertise multi-language coverage")
PY
if "$ROOT_DIR/scripts/audit_my_repo.sh" --out "$TMP_DIR/no_target" >/dev/null 2>&1; then
  echo "target repo must be required for audit execution" >&2
  exit 9
fi
if "$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" --generator unsupported --out "$TMP_DIR/bad_generator" >/dev/null 2>&1; then
  echo "unsupported generator must fail" >&2
  exit 10
fi
if "$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" --max-queries 0 --out "$TMP_DIR/bad_queries" >/dev/null 2>&1; then
  echo "non-positive max queries must fail" >&2
  exit 11
fi
if "$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/missing" --out "$TMP_DIR/bad_target" >/dev/null 2>&1; then
  echo "missing target repo must fail" >&2
  exit 12
fi
if "$ROOT_DIR/scripts/audit_my_repo.sh" "$repo" --namespace real_benchmark --out "$TMP_DIR/bad_real_namespace" >/dev/null 2>&1; then
  echo "real_benchmark namespace must require explicit confirmation" >&2
  exit 13
fi
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
if {row["plugin_id"] for row in plugin_registry["plugins"]} != {
    "doc_code_identity",
    "deprecated_api",
    "config_consistency",
    "unsupported_claim",
    "missing_evidence",
}:
    raise SystemExit("fixture audit output must bind the deterministic plugin registry")
if manifest["plugin_registry_sha256"] != "sha256:" + sha256(out_a / "plugin_registry.json"):
    raise SystemExit("manifest must bind plugin registry sha256")
if manifest["namespace"] != "fixture":
    raise SystemExit("negative-control fixture must not be promoted out of fixture namespace")
if manifest["claim_boundary"] != "alpha-local-code-doc-audit-only":
    raise SystemExit("claim boundary must remain alpha-only")
if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
    raise SystemExit("manifest timestamp must be deterministic")

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
if not any(row["plugin_id"] == "user_question" and row["abstain"] == 1 and row["grounded"] == 1 for row in findings):
    raise SystemExit("free-form production question must abstain with bound source citation")
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

tampered_citations = out_a / "citation_spans.jsonl"
sha_manifest_path = out_a / "sha256sums.txt"
original_citations = tampered_citations.read_text(encoding="utf-8")
original_sha_manifest_text = sha_manifest_path.read_text(encoding="utf-8")
tampered_citations.write_text(original_citations.replace("sha256:", "sha256:0000", 1), encoding="utf-8")
verify_cmd = [str(root / "tools/verify_local_audit.py"), str(out_a)]
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

findings_csv_path = out_a / "audit_findings.csv"
original_findings_csv_text = findings_csv_path.read_text(encoding="utf-8")
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
