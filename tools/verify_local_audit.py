#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shlex
import stat
import subprocess
import sys
from pathlib import Path


TOOL_VERSION = "audit_my_repo_alpha.v1"
MANIFEST_SCHEMA_VERSION = "local_repo_audit_output.v1"
SUMMARY_SCHEMA_VERSION = "local_repo_audit.v1"
CLAIM_BOUNDARY = "alpha-local-code-doc-audit-only"
EXPECTED_PLUGIN_IDS = [
    "doc_code_identity",
    "deprecated_api",
    "config_consistency",
    "unsupported_claim",
    "missing_evidence",
    "user_question",
]
EXPECTED_PLUGIN_MODULES = [
    "auditor_plugin_doc_code_identity",
    "auditor_plugin_deprecated_api",
    "auditor_plugin_config_consistency",
    "auditor_plugin_unsupported_claim",
    "auditor_plugin_missing_evidence",
    "auditor_plugin_user_question",
]
EXPECTED_PLUGIN_SOURCE_PATHS = [
    "scripts/auditor_plugin_doc_code_identity.py",
    "scripts/auditor_plugin_deprecated_api.py",
    "scripts/auditor_plugin_config_consistency.py",
    "scripts/auditor_plugin_unsupported_claim.py",
    "scripts/auditor_plugin_missing_evidence.py",
    "scripts/auditor_plugin_user_question.py",
]

REQUIRED_FILES = {
    "ARCHITECTURE_TRACE.md",
    "AUDIT_REPORT.md",
    "abstain_rows.csv",
    "accuracy_rows.csv",
    "artifact_contract_rows.csv",
    "audit_findings.csv",
    "audit_findings.jsonl",
    "audit_invocation.json",
    "audit_manifest.json",
    "audit_summary.csv",
    "audit_summary.json",
    "citation_correctness_rows.csv",
    "citation_spans.csv",
    "citation_spans.jsonl",
    "claim_boundary.md",
    "compact_route_hint_rows.csv",
    "exit_code_contract.json",
    "false_positive_candidate_rows.csv",
    "grounded_generation_rows.csv",
    "latency_rows.csv",
    "manual_review_queue.csv",
    "mmap_read_trace.jsonl",
    "plugin_registry.json",
    "plugin_rule_rows.csv",
    "prediction_lineage.jsonl",
    "reproduce.sh",
    "resource_envelope.json",
    "sha256sums.txt",
    "source_manifest.csv",
    "source_snapshot.json",
    "unsupported_claim_rows.csv",
    "verify.sh",
    "wrong_answer_guard_rows.csv",
}
EXPECTED_SUMMARY_KEYS = [
    "schema_version",
    "tool_version",
    "audit_my_repo_ready",
    "target_repo",
    "mode",
    "namespace",
    "generator",
    "question_supplied",
    "source_files",
    "finding_rows",
    "citation_span_rows",
    "abstain_rows",
    "unsupported_claim_rows",
    "accuracy_rows",
    "citation_correctness_rows",
    "false_positive_candidate_rows",
    "manual_review_queue_rows",
    "wrong_answer_guard_rows",
    "wrong_answer_guard_pass_rows",
    "claim_boundary_ready",
    "route_memory_lineage_rows",
    "mmap_read_trace_rows",
    "compact_route_hint_rows",
    "grounded_generation_rows",
    "raw_prompt_context_bytes",
    "attention_blocks",
    "transformer_blocks",
    "oracle_prediction_used",
    "raw_input_extractor_used",
    "real_release_package_ready",
    "public_comparison_claim_ready",
    "gpu_speedup_claim",
    "latency_ms",
]
SCHEMA_INSTANCE_PAIRS = [
    ("schemas/local_repo_audit_output.schema.json", "audit_manifest.json"),
    ("schemas/local_repo_audit_exit_code_contract.schema.json", "exit_code_contract.json"),
    ("schemas/local_repo_audit_invocation.schema.json", "audit_invocation.json"),
    ("schemas/local_repo_audit_summary.schema.json", "audit_summary.json"),
    ("schemas/local_repo_audit_plugin_registry.schema.json", "plugin_registry.json"),
    ("schemas/local_repo_audit_resource_envelope.schema.json", "resource_envelope.json"),
    ("schemas/local_repo_audit_source_snapshot.schema.json", "source_snapshot.json"),
]


def sha256_hex(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_prefixed(path: Path) -> str:
    return "sha256:" + sha256_hex(path)


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def add(errors: list[str], message: str) -> None:
    errors.append(message)


def verify_schema_instances(out_dir: Path, errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    validator = repo_root / "tools" / "validate_json_schemas.py"
    for schema_rel, instance_rel in SCHEMA_INSTANCE_PAIRS:
        result = subprocess.run(
            [
                sys.executable,
                str(validator),
                "--schema-instance",
                str(repo_root / schema_rel),
                str(out_dir / instance_rel),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip().splitlines()
            suffix = f": {detail[0]}" if detail else ""
            add(errors, f"schema instance validation failed: {instance_rel}{suffix}")


def verify_sha_manifest(out_dir: Path, errors: list[str]) -> dict[str, str]:
    entries: dict[str, str] = {}
    allowed_entries = set(REQUIRED_FILES)
    for line in (out_dir / "sha256sums.txt").read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            digest, rel = line.split("  ", 1)
        except ValueError:
            add(errors, f"invalid sha256 line: {line!r}")
            continue
        if rel in entries:
            add(errors, f"duplicate sha manifest entry: {rel}")
        if Path(rel).is_absolute() or ".." in Path(rel).parts:
            add(errors, f"sha manifest path escapes output directory: {rel}")
            continue
        if rel not in allowed_entries:
            add(errors, f"sha manifest references unexpected artifact: {rel}")
        entries[rel] = digest
        artifact = out_dir / rel
        if not artifact.is_file():
            add(errors, f"sha manifest references missing artifact: {rel}")
        elif sha256_hex(artifact) != digest:
            add(errors, f"sha mismatch: {rel}")
    for rel in REQUIRED_FILES - {"sha256sums.txt"}:
        if rel not in entries:
            add(errors, f"sha manifest missing required artifact: {rel}")
    return entries


def verify_summary(summary_json: dict, summary_csv_rows: list[dict[str, str]], errors: list[str]) -> dict[str, str]:
    if len(summary_csv_rows) != 1:
        add(errors, "audit_summary.csv must have exactly one row")
        return {}
    row = summary_csv_rows[0]
    if set(summary_json.keys()) != set(EXPECTED_SUMMARY_KEYS):
        add(errors, "audit_summary.json keys drifted")
    if list(row.keys()) != EXPECTED_SUMMARY_KEYS:
        add(errors, "audit_summary.csv columns drifted")
    if summary_json.get("schema_version") != SUMMARY_SCHEMA_VERSION:
        add(errors, "audit_summary schema_version mismatch")
    if summary_json.get("tool_version") != TOOL_VERSION:
        add(errors, "audit_summary tool_version mismatch")
    for key, value in summary_json.items():
        if row.get(key) != str(value):
            add(errors, f"audit summary CSV/JSON drift: {key}")
    for key in [
        "raw_prompt_context_bytes",
        "attention_blocks",
        "transformer_blocks",
        "oracle_prediction_used",
        "raw_input_extractor_used",
        "real_release_package_ready",
        "public_comparison_claim_ready",
    ]:
        if str(summary_json.get(key)) != "0":
            add(errors, f"blocked summary claim must remain zero: {key}")
    if summary_json.get("gpu_speedup_claim") != "deferred":
        add(errors, "gpu_speedup_claim must remain deferred")
    return row


def verify_manifest(manifest: dict, summary_json: dict, out_dir: Path, errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    for key, expected in {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "tool_source_sha256": sha256_prefixed(repo_root / "scripts" / "audit_my_repo.py"),
        "generated_at_utc": "1970-01-01T00:00:00+00:00",
        "atomic_publish": 1,
        "output_dir_destroyed": 0,
        "output_dir_overwritten": 0,
        "fixture_result_promoted": 0,
        "real_evidence_claimed": 0,
        "publish_mode": "create-or-idempotent-cache-hit",
        "claim_boundary": CLAIM_BOUNDARY,
    }.items():
        if manifest.get(key) != expected:
            add(errors, f"audit_manifest.{key} mismatch")
    if manifest.get("namespace") not in {"fixture", "synthetic", "real_benchmark"}:
        add(errors, "audit_manifest.namespace invalid")
    expected_real_namespace_confirmed = 1 if manifest.get("namespace") == "real_benchmark" else 0
    if manifest.get("real_benchmark_namespace_confirmed") != expected_real_namespace_confirmed:
        add(errors, "audit_manifest.real_benchmark_namespace_confirmed mismatch")
    if manifest.get("plugin_registry_sha256") != sha256_prefixed(out_dir / "plugin_registry.json"):
        add(errors, "plugin registry hash mismatch")
    if str(manifest.get("source_file_count")) != str(summary_json.get("source_files")):
        add(errors, "manifest source count does not match summary")
    if str(manifest.get("finding_rows")) != str(summary_json.get("finding_rows")):
        add(errors, "manifest finding count does not match summary")


def verify_resource(resource: dict, summary: dict[str, str], errors: list[str]) -> None:
    for key, expected in {
        "resource_envelope_ready": "1",
        "tool_version": TOOL_VERSION,
        "external_network_used": "0",
        "raw_prompt_context_bytes": "0",
        "claim_boundary_ready": "1",
    }.items():
        if str(resource.get(key)) != expected:
            add(errors, f"resource_envelope.{key} mismatch")
    for resource_key, summary_key in {
        "source_files_scanned": "source_files",
        "wrong_answer_guard_rows": "wrong_answer_guard_rows",
        "latency_ms": "latency_ms",
        "mode": "mode",
        "namespace": "namespace",
    }.items():
        if str(resource.get(resource_key)) != str(summary.get(summary_key)):
            add(errors, f"resource envelope drift: {resource_key}")


def verify_invocation(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    invocation = read_json(out_dir / "audit_invocation.json")
    expected_keys = {
        "schema_version",
        "tool_version",
        "target_repo",
        "out_dir",
        "mode",
        "max_queries",
        "generator",
        "namespace",
        "real_benchmark_namespace_confirmed",
        "question_supplied",
        "question_sha256",
        "verify_output_requested",
        "emit_report_requested",
        "emit_lineage_requested",
        "emit_reproduce_requested",
    }
    if set(invocation) != expected_keys:
        add(errors, "audit_invocation.json keys drifted")
    for key, expected in {
        "schema_version": "local_repo_audit_invocation.v1",
        "tool_version": TOOL_VERSION,
        "target_repo": str(manifest.get("target_repo")),
        "out_dir": str(out_dir),
        "mode": str(summary.get("mode")),
        "generator": str(summary.get("generator")),
        "namespace": str(manifest.get("namespace")),
        "real_benchmark_namespace_confirmed": int(manifest.get("real_benchmark_namespace_confirmed", -1)),
        "question_supplied": int(summary.get("question_supplied", -1)),
        "emit_report_requested": 1,
        "emit_lineage_requested": 1,
        "emit_reproduce_requested": 1,
    }.items():
        if invocation.get(key) != expected:
            add(errors, f"audit_invocation.{key} mismatch")
    resource = read_json(out_dir / "resource_envelope.json")
    if str(invocation.get("max_queries")) != str(resource.get("max_queries")):
        add(errors, "audit_invocation max_queries mismatch")
    if invocation.get("verify_output_requested") not in {0, 1}:
        add(errors, "audit_invocation verify_output_requested must be binary")
    questions = [row.get("question", "") for row in read_csv(out_dir / "audit_findings.csv") if row.get("audit_type") == "user_question"]
    question = questions[0] if len(questions) == 1 else ""
    if invocation.get("question_sha256") != sha256_text(question):
        add(errors, "audit_invocation question_sha256 mismatch")


def verify_exit_code_contract(out_dir: Path, errors: list[str]) -> None:
    contract = read_json(out_dir / "exit_code_contract.json")
    expected = {
        "schema_version": "local_repo_audit_exit_code_contract.v1",
        "tool_version": TOOL_VERSION,
        "success_exit_code": 0,
        "artifact_verify_failure_exit_code": 1,
        "input_or_publish_error_exit_code": 2,
        "wrong_answer_guard_failure_exit_code": 1,
        "stable_exit_code_policy": "0=verified-success,1=artifact-or-guard-failure,2=input-or-publish-error",
    }
    if set(contract) != set(expected):
        add(errors, "exit_code_contract.json keys drifted")
    for key, value in expected.items():
        if contract.get(key) != value:
            add(errors, f"exit_code_contract.{key} mismatch")


def verify_claim_boundary_docs(out_dir: Path, errors: list[str]) -> None:
    claim_boundary = (out_dir / "claim_boundary.md").read_text(encoding="utf-8")
    for snippet in [
        "Allowed claim: local evidence-bound codebase QA/audit assistance with citations, abstention, and an audit trail.",
        "Blocked claims: Transformer replacement, frontier local LLM, production-ready release, expert replacement, long-context solved, and GPU acceleration proven.",
        "`real_release_package_ready=0`, `public_comparison_claim_ready=0`, and `gpu_speedup_claim=deferred` remain explicit.",
    ]:
        if snippet not in claim_boundary:
            add(errors, "claim_boundary.md must preserve alpha product claim boundary")

    architecture_trace = (out_dir / "ARCHITECTURE_TRACE.md").read_text(encoding="utf-8")
    for snippet in [
        "- raw_prompt_context_bytes=0",
        "- attention_blocks=0",
        "- transformer_blocks=0",
        "- oracle_prediction_used=0",
        "- raw_input_extractor_used=0",
        "not a Transformer replacement",
        "GPU-speedup proof",
        "production release",
    ]:
        if snippet not in architecture_trace:
            add(errors, "ARCHITECTURE_TRACE.md must preserve non-LLM/non-release boundary")


def verify_audit_report(out_dir: Path, summary: dict[str, str], errors: list[str]) -> None:
    report = (out_dir / "AUDIT_REPORT.md").read_text(encoding="utf-8")
    findings = read_csv(out_dir / "audit_findings.csv")
    expected_summary_lines = [
        "# Local Codebase Audit Report",
        f"- {summary.get('finding_rows')} source-bound findings",
        f"- {summary.get('abstain_rows')} unsupported questions abstained",
        f"- {summary.get('unsupported_claim_rows')} unsupported claims flagged",
        "- RouteMemory evidence, compact RouteHint, grounded answer, citation/abstain, and audit trail artifacts were emitted.",
    ]
    for line in expected_summary_lines:
        if line not in report:
            add(errors, "AUDIT_REPORT.md summary must match audit_summary rows")
    for row in findings:
        finding_id = row.get("finding_id", "")
        section_header = f"## {finding_id}: {row.get('audit_type', '')}"
        section_start = report.find(section_header)
        if section_start < 0:
            add(errors, f"AUDIT_REPORT.md drift for finding: {finding_id}")
            continue
        next_section_start = report.find("\n## ", section_start + 1)
        section = report[section_start:] if next_section_start < 0 else report[section_start:next_section_start]
        expected_lines = [
            section_header,
            f"  {row.get('question', '')}",
            f"  {row.get('answer', '')}",
            f"  grounded={row.get('grounded', '')}",
            f"  abstain={row.get('abstain', '')}",
            f"  unsupported_claims={row.get('unsupported_claim', '')}",
        ]
        citation_sha256s = [cell for cell in row.get("citation_sha256s", "").split(";") if cell]
        expected_evidence_lines: list[str] = []
        for citation, citation_sha256 in zip(
            [cell for cell in row.get("citations", "").split(";") if cell],
            citation_sha256s,
        ):
            expected_evidence_lines.extend([f"  {citation}", f"  sha256={citation_sha256}"])
        expected_lines.extend(expected_evidence_lines)
        for line in expected_lines:
            if line not in section:
                add(errors, f"AUDIT_REPORT.md drift for finding: {finding_id}")
        section_lines = section.splitlines()
        try:
            evidence_start = section_lines.index("Evidence:") + 1
            evidence_end = section_lines.index("Decision:")
            actual_evidence_lines = [line for line in section_lines[evidence_start:evidence_end] if line.strip()]
            if actual_evidence_lines != expected_evidence_lines:
                add(errors, f"AUDIT_REPORT.md evidence block drift: {finding_id}")
        except ValueError:
            add(errors, f"AUDIT_REPORT.md missing evidence or decision block: {finding_id}")
        for prefix, expected in {
            "  grounded=": f"  grounded={row.get('grounded', '')}",
            "  abstain=": f"  abstain={row.get('abstain', '')}",
            "  unsupported_claims=": f"  unsupported_claims={row.get('unsupported_claim', '')}",
        }.items():
            decision_lines = [line for line in section.splitlines() if line.startswith(prefix)]
            if decision_lines != [expected]:
                add(errors, f"AUDIT_REPORT.md duplicate or conflicting decision line: {finding_id}")


def verify_registry(registry: dict, errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    if registry.get("schema_version") != "local_repo_audit.v1":
        add(errors, "plugin registry schema_version mismatch")
    if registry.get("tool_version") != TOOL_VERSION:
        add(errors, "plugin registry tool_version mismatch")
    plugin_ids = [plugin.get("plugin_id") for plugin in registry.get("plugins", [])]
    if plugin_ids != EXPECTED_PLUGIN_IDS:
        add(errors, "plugin registry ids drifted")
    plugin_modules = [plugin.get("module") for plugin in registry.get("plugins", [])]
    if plugin_modules != EXPECTED_PLUGIN_MODULES:
        add(errors, "plugin registry modules drifted")
    plugin_source_paths = [plugin.get("source_path") for plugin in registry.get("plugins", [])]
    if plugin_source_paths != EXPECTED_PLUGIN_SOURCE_PATHS:
        add(errors, "plugin registry source paths drifted")
    for plugin in registry.get("plugins", []):
        source_path = str(plugin.get("source_path", ""))
        rel = Path(source_path)
        if not source_path or rel.is_absolute() or ".." in rel.parts:
            add(errors, f"plugin registry source path escapes repo: {source_path}")
            continue
        source = repo_root / rel
        if not source.is_file():
            add(errors, f"plugin registry source file missing: {source_path}")
            continue
        if plugin.get("source_sha256") != sha256_prefixed(source):
            add(errors, f"plugin registry source sha mismatch: {source_path}")


def verify_finding_registry_binding(out_dir: Path, registry: dict, errors: list[str]) -> None:
    registry_by_plugin = {
        str(plugin.get("plugin_id", "")): plugin
        for plugin in registry.get("plugins", [])
    }
    findings = read_csv(out_dir / "audit_findings.csv")
    expected_plugin_ids = set(EXPECTED_PLUGIN_IDS)
    summary = read_json(out_dir / "audit_summary.json")
    if str(summary.get("question_supplied")) != "1":
        expected_plugin_ids.remove("user_question")
    finding_plugin_ids = [row.get("plugin_id", "") for row in findings]
    if set(finding_plugin_ids) != expected_plugin_ids:
        add(errors, "audit findings must contain exactly the expected required plugin rows")
    duplicate_plugins = sorted(
        plugin_id
        for plugin_id in set(finding_plugin_ids)
        if finding_plugin_ids.count(plugin_id) > 1
    )
    if duplicate_plugins:
        add(errors, f"audit findings contain duplicate plugin rows: {','.join(duplicate_plugins)}")
    for row in findings:
        finding_id = row.get("finding_id", "")
        plugin_id = row.get("plugin_id", "")
        plugin = registry_by_plugin.get(plugin_id)
        if plugin is None:
            add(errors, f"audit finding references unregistered plugin: {finding_id} {plugin_id}")
            continue
        if row.get("audit_type") != str(plugin.get("audit_type", "")):
            add(errors, f"audit finding audit_type does not match plugin registry: {finding_id}")
        plugin_language = str(plugin.get("language", ""))
        if plugin_language != "multi" and row.get("language") != plugin_language:
            add(errors, f"audit finding language does not match plugin registry: {finding_id}")


def expected_plugin_rule_rows(errors: list[str]) -> list[dict[str, str]]:
    scripts_dir = Path(__file__).resolve().parents[1] / "scripts"
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))
    try:
        from auditor_plugin_user_question import USER_QUESTION_PLUGIN
        from auditor_plugins import DEFAULT_PLUGINS
    except Exception as exc:
        add(errors, f"could not import auditor plugins for rule verification: {exc}")
        return []
    rows = []
    for plugin in list(DEFAULT_PLUGINS) + [USER_QUESTION_PLUGIN]:
        for rule in plugin.rules():
            rows.append(
                {
                    "plugin_id": str(plugin.plugin_id),
                    "audit_type": str(plugin.audit_type),
                    "rule_id": str(rule.rule_id),
                    "language": str(rule.language),
                    "file_suffixes": "|".join(rule.file_suffixes),
                    "pattern_label": str(rule.pattern_label),
                    "evidence_policy": str(rule.evidence_policy),
                }
            )
    return sorted(rows, key=lambda row: (row["plugin_id"], row["rule_id"]))


def verify_plugin_rules(out_dir: Path, registry: dict, errors: list[str]) -> None:
    registry_by_plugin = {
        str(plugin.get("plugin_id", "")): plugin
        for plugin in registry.get("plugins", [])
    }
    rows = read_csv(out_dir / "plugin_rule_rows.csv")
    expected_rows = expected_plugin_rule_rows(errors)
    if expected_rows and rows != expected_rows:
        add(errors, "plugin_rule_rows.csv does not match plugin-owned rule metadata")
    expected_columns = ["plugin_id", "audit_type", "rule_id", "language", "file_suffixes", "pattern_label", "evidence_policy"]
    with (out_dir / "plugin_rule_rows.csv").open(newline="", encoding="utf-8") as handle:
        columns = list(csv.DictReader(handle).fieldnames or [])
    if columns != expected_columns:
        add(errors, "plugin_rule_rows.csv columns drifted")
    rule_ids: set[str] = set()
    deprecated_languages: set[str] = set()
    plugin_ids_with_rules: set[str] = set()
    for row in rows:
        plugin_id = row.get("plugin_id", "")
        rule_id = row.get("rule_id", "")
        plugin = registry_by_plugin.get(plugin_id)
        if not rule_id:
            add(errors, "plugin rule row missing rule_id")
        if rule_id in rule_ids:
            add(errors, f"duplicate plugin rule_id: {rule_id}")
        rule_ids.add(rule_id)
        if plugin is None:
            add(errors, f"plugin rule references unregistered plugin: {plugin_id}")
            continue
        plugin_ids_with_rules.add(plugin_id)
        if row.get("audit_type") != str(plugin.get("audit_type", "")):
            add(errors, f"plugin rule audit_type does not match registry: {rule_id}")
        if row.get("language") not in {"generic", "python", "cpp", "javascript"}:
            add(errors, f"plugin rule language is unsupported: {rule_id}")
        if row.get("evidence_policy") not in {"source-bound-span", "abstain-when-missing-source-bound-span"}:
            add(errors, f"plugin rule evidence policy is unsupported: {rule_id}")
        if not row.get("file_suffixes") or not row.get("pattern_label"):
            add(errors, f"plugin rule missing replay metadata: {rule_id}")
        if plugin_id == "deprecated_api":
            deprecated_languages.add(row.get("language", ""))
            if row.get("evidence_policy") != "source-bound-span":
                add(errors, f"deprecated_api rule must be source-bound: {rule_id}")
    missing_rule_plugins = set(registry_by_plugin) - plugin_ids_with_rules
    if missing_rule_plugins:
        add(errors, f"plugin rule rows missing registered plugins: {','.join(sorted(missing_rule_plugins))}")
    if not {"python", "cpp", "javascript"}.issubset(deprecated_languages):
        add(errors, "deprecated_api plugin rules must cover python, cpp, and javascript")


def verify_contract(out_dir: Path, sha_entries: dict[str, str], errors: list[str]) -> None:
    rows = read_csv(out_dir / "artifact_contract_rows.csv")
    expected_contract_paths = REQUIRED_FILES - {"sha256sums.txt", "artifact_contract_rows.csv"}
    seen_contract_paths: set[str] = set()
    for row in rows:
        rel = row.get("artifact_path", "")
        artifact = out_dir / rel
        if rel in seen_contract_paths:
            add(errors, f"duplicate artifact contract row: {rel}")
        seen_contract_paths.add(rel)
        if row.get("schema_version") != "local_repo_audit_artifacts.v1":
            add(errors, f"artifact contract schema drift: {rel}")
        if row.get("sha256_manifest_required") == "1" and rel not in sha_entries:
            add(errors, f"contract artifact missing from sha manifest: {rel}")
        if not artifact.is_file():
            add(errors, f"contract artifact missing: {rel}")
            continue
        kind = row.get("artifact_kind")
        min_rows = int(row.get("min_rows") or 0)
        if kind == "csv":
            with artifact.open(newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                rows = list(reader)
                columns = list(reader.fieldnames or [])
            expected_columns = row.get("required_columns", "").split("|") if row.get("required_columns") else []
            if columns != expected_columns or row.get("actual_columns", "").split("|") != expected_columns:
                add(errors, f"csv contract columns mismatch: {rel}")
            if len(rows) != int(row.get("actual_rows") or -1) or len(rows) < min_rows:
                add(errors, f"csv contract row count mismatch: {rel}")
        elif kind == "jsonl":
            rows = read_jsonl(artifact)
            keys = sorted({key for payload in rows for key in payload})
            required_keys = sorted(row.get("required_keys", "").split("|")) if row.get("required_keys") else []
            if not set(required_keys).issubset(keys) or len(rows) < min_rows:
                add(errors, f"jsonl contract mismatch: {rel}")
        elif kind == "json":
            payload = read_json(artifact)
            required_keys = sorted(row.get("required_keys", "").split("|")) if row.get("required_keys") else []
            if sorted(payload.keys()) != sorted(row.get("actual_keys", "").split("|")):
                add(errors, f"json contract actual keys drift: {rel}")
            if not set(required_keys).issubset(payload):
                add(errors, f"json contract required keys missing: {rel}")
    missing_contracts = expected_contract_paths - seen_contract_paths
    extra_contracts = seen_contract_paths - expected_contract_paths
    if missing_contracts:
        add(errors, f"artifact contract missing required rows: {','.join(sorted(missing_contracts))}")
    if extra_contracts:
        add(errors, f"artifact contract has unexpected rows: {','.join(sorted(extra_contracts))}")


def verify_csv_jsonl(out_dir: Path, errors: list[str]) -> None:
    for csv_rel, jsonl_rel in [("audit_findings.csv", "audit_findings.jsonl"), ("citation_spans.csv", "citation_spans.jsonl")]:
        csv_rows = read_csv(out_dir / csv_rel)
        jsonl_rows = [{key: str(value) for key, value in row.items()} for row in read_jsonl(out_dir / jsonl_rel)]
        if csv_rows != jsonl_rows:
            add(errors, f"CSV/JSONL drift: {csv_rel} vs {jsonl_rel}")


def relative_source_path(rel: str, errors: list[str], label: str) -> Path | None:
    path = Path(rel)
    if not rel or path.is_absolute() or ".." in path.parts:
        add(errors, f"{label} path escapes target repo: {rel}")
        return None
    return path


def verify_sources(out_dir: Path, manifest: dict, errors: list[str]) -> dict[str, dict[str, str]]:
    rows = read_csv(out_dir / "source_manifest.csv")
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    by_path: dict[str, dict[str, str]] = {}
    source_ids: set[str] = set()
    if not target.is_dir():
        add(errors, "target_repo directory is missing")
    for row in rows:
        source_id = row.get("source_id", "")
        rel = row.get("file_path", "")
        rel_path = relative_source_path(rel, errors, "source_manifest")
        if source_id in source_ids:
            add(errors, f"duplicate source_id in source_manifest.csv: {source_id}")
        source_ids.add(source_id)
        if rel in by_path:
            add(errors, f"duplicate file_path in source_manifest.csv: {rel}")
        by_path[rel] = row
        if rel_path is None:
            continue
        source = target / rel_path
        if row.get("route_memory_source") != "1":
            add(errors, f"source_manifest route_memory_source must be 1: {rel}")
        try:
            source.resolve().relative_to(target)
        except (OSError, ValueError):
            add(errors, f"source manifest resolved path escapes target repo: {rel}")
            continue
        if source.is_symlink():
            add(errors, f"source manifest must not include symlinks: {rel}")
            continue
        if not source.is_file():
            add(errors, f"source manifest file missing in target repo: {rel}")
            continue
        if row.get("sha256") != sha256_prefixed(source):
            add(errors, f"source manifest sha mismatch: {rel}")
        if row.get("bytes") != str(source.stat().st_size):
            add(errors, f"source manifest byte count mismatch: {rel}")
    if str(len(rows)) != str(manifest.get("source_file_count")):
        add(errors, "source manifest row count does not match manifest")
    return by_path


def git_output(target: Path, args: list[str]) -> tuple[int, str]:
    result = subprocess.run(
        ["git", "-C", str(target), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.returncode, result.stdout


def verify_source_snapshot(out_dir: Path, manifest: dict, source_by_path: dict[str, dict[str, str]], errors: list[str]) -> None:
    snapshot = read_json(out_dir / "source_snapshot.json")
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    expected_keys = {
        "schema_version",
        "tool_version",
        "target_repo",
        "source_manifest_sha256",
        "source_file_count",
        "git_available",
        "git_head",
        "git_dirty",
        "git_status_sha256",
        "git_tracked_files",
    }
    if set(snapshot) != expected_keys:
        add(errors, "source_snapshot.json keys drifted")
    if snapshot.get("schema_version") != "local_repo_audit_source_snapshot.v1":
        add(errors, "source_snapshot schema_version mismatch")
    if snapshot.get("tool_version") != TOOL_VERSION:
        add(errors, "source_snapshot tool_version mismatch")
    if snapshot.get("target_repo") != str(target):
        add(errors, "source_snapshot target_repo mismatch")
    if snapshot.get("source_manifest_sha256") != sha256_prefixed(out_dir / "source_manifest.csv"):
        add(errors, "source_snapshot source_manifest hash mismatch")
    if str(snapshot.get("source_file_count")) != str(len(source_by_path)):
        add(errors, "source_snapshot source_file_count mismatch")
    rc, inside = git_output(target, ["rev-parse", "--is-inside-work-tree"])
    current_git_available = int(rc == 0 and inside.strip() == "true")
    if int(snapshot.get("git_available", -1)) != current_git_available:
        add(errors, "source_snapshot git_available mismatch")
        return
    if not current_git_available:
        return
    rc, head = git_output(target, ["rev-parse", "HEAD"])
    if rc != 0 or snapshot.get("git_head") != head.strip():
        add(errors, "source_snapshot git_head mismatch")
    rc, status = git_output(target, ["status", "--porcelain", "--untracked-files=all"])
    status_text = status if rc == 0 else ""
    if int(snapshot.get("git_dirty", -1)) != int(bool(status_text.strip())):
        add(errors, "source_snapshot git_dirty mismatch")
    if snapshot.get("git_status_sha256") != sha256_text(status_text):
        add(errors, "source_snapshot git_status hash mismatch")
    rc, tracked = git_output(target, ["ls-files"])
    tracked_count = len([line for line in tracked.splitlines() if line.strip()]) if rc == 0 else 0
    if int(snapshot.get("git_tracked_files", -1)) != tracked_count:
        add(errors, "source_snapshot git_tracked_files mismatch")


def verify_citations(out_dir: Path, manifest: dict, source_by_path: dict[str, dict[str, str]], errors: list[str]) -> None:
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    findings = {row["finding_id"]: row for row in read_csv(out_dir / "audit_findings.csv")}
    citation_cells: dict[tuple[str, str], dict[str, str]] = {}
    citation_ids: set[str] = set()
    for row in read_csv(out_dir / "citation_spans.csv"):
        rel = row.get("file_path", "")
        rel_path = relative_source_path(rel, errors, "citation")
        finding_id = row.get("finding_id", "")
        citation_id = row.get("citation_id", "")
        line_start = int(row.get("line_start") or 0)
        line_end = int(row.get("line_end") or 0)
        if citation_id in citation_ids:
            add(errors, f"duplicate citation_id in citation_spans.csv: {citation_id}")
        citation_ids.add(citation_id)
        if rel not in source_by_path:
            add(errors, f"citation outside source_manifest.csv: {rel}")
            continue
        if rel_path is None:
            continue
        source = target / rel_path
        if row.get("sha256") != source_by_path[rel].get("sha256") or row.get("sha256") != sha256_prefixed(source):
            add(errors, f"citation sha mismatch: {rel}")
        lines = source.read_text(encoding="utf-8", errors="replace").splitlines()
        if line_start < 1 or line_end < line_start or line_end > len(lines):
            add(errors, f"citation line bounds invalid: {rel}:{line_start}")
            continue
        span_text = "\n".join(line.strip() for line in lines[line_start - 1:line_end])
        if row.get("span_sha256") != sha256_text(span_text):
            add(errors, f"citation span sha mismatch: {rel}:{line_start}")
        if row.get("span_text_preview") != lines[line_start - 1].strip()[:280]:
            add(errors, f"citation preview mismatch: {rel}:{line_start}")
        cell_key = (finding_id, f"{rel}:{line_start}")
        if cell_key in citation_cells:
            add(errors, f"duplicate citation cell in citation_spans.csv: {finding_id} {rel}:{line_start}")
        citation_cells[cell_key] = row
    for finding_id, finding in findings.items():
        cells = [cell for cell in finding.get("citations", "").split(";") if cell]
        if not cells:
            add(errors, f"finding has no citation: {finding_id}")
        sha_cells = [cell for cell in finding.get("citation_sha256s", "").split(";") if cell]
        if len(cells) != len(sha_cells):
            add(errors, f"finding citation/citation_sha256 count drift: {finding_id}")
        for idx, cell in enumerate(cells):
            span = citation_cells.get((finding_id, cell))
            if span is None:
                add(errors, f"finding citation has no matching span row: {finding_id} {cell}")
                continue
            if idx >= len(sha_cells):
                continue
            if sha_cells[idx] != span.get("sha256"):
                add(errors, f"finding citation sha256 drift: {finding_id} {cell}")


def verify_cache_key(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    source_rows = read_csv(out_dir / "source_manifest.csv")
    source_snapshot = read_json(out_dir / "source_snapshot.json")
    invocation = read_json(out_dir / "audit_invocation.json")
    questions = {row.get("question", "") for row in read_csv(out_dir / "audit_findings.csv") if row.get("audit_type") == "user_question"}
    question = sorted(questions)[0] if summary.get("question_supplied") == "1" and questions else ""
    payload = {
        "tool_version": TOOL_VERSION,
        "tool_source_sha256": manifest.get("tool_source_sha256"),
        "target": manifest.get("target_repo"),
        "source": [(row["file_path"], row["sha256"]) for row in source_rows],
        "source_snapshot": source_snapshot,
        "mode": summary.get("mode"),
        "max_queries": int(read_json(out_dir / "resource_envelope.json").get("max_queries")),
        "namespace": manifest.get("namespace"),
        "real_benchmark_namespace_confirmed": manifest.get("real_benchmark_namespace_confirmed"),
        "question": question,
        "verify_output_requested": int(invocation.get("verify_output_requested", -1)),
        "emit_report_requested": int(invocation.get("emit_report_requested", -1)),
        "emit_lineage_requested": int(invocation.get("emit_lineage_requested", -1)),
        "emit_reproduce_requested": int(invocation.get("emit_reproduce_requested", -1)),
        "plugin_registry_sha256": manifest.get("plugin_registry_sha256"),
    }
    expected = hashlib.sha256(json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()
    if manifest.get("cache_key") != expected:
        add(errors, "cache key mismatch")


def verify_reproduce(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    path = out_dir / "reproduce.sh"
    resource = read_json(out_dir / "resource_envelope.json")
    if not (path.stat().st_mode & stat.S_IXUSR):
        add(errors, "reproduce.sh must be executable")
    text = path.read_text(encoding="utf-8")
    if not text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n"):
        add(errors, "reproduce.sh must use bash strict mode")
    lines = text.splitlines()
    if len(lines) < 4:
        add(errors, "reproduce.sh must include repo-root cd and command lines")
        return
    try:
        cd_parts = shlex.split(lines[2])
    except ValueError as exc:
        add(errors, f"reproduce.sh cd line is not parseable: {exc}")
        return
    if cd_parts != ["cd", str(repo_root)]:
        add(errors, "reproduce.sh repo-root cd drift")
    try:
        parts = shlex.split(lines[-1])
    except ValueError as exc:
        add(errors, f"reproduce.sh command is not parseable: {exc}")
        return
    for item in [
        "./scripts/audit_my_repo.sh",
        str(manifest.get("target_repo")),
        "--mode",
        str(summary.get("mode")),
        "--max-queries",
        str(resource.get("max_queries")),
        "--generator",
        str(summary.get("generator")),
        "--namespace",
        str(manifest.get("namespace")),
        "--verify-output",
        "--emit-report",
        "--emit-lineage",
        "--emit-reproduce",
    ]:
        if item not in parts:
            add(errors, f"reproduce.sh missing required token: {item}")
    flag_values = {
        flag: parts[idx + 1] if idx + 1 < len(parts) else ""
        for idx, flag in enumerate(parts)
        if flag.startswith("--")
    }
    expected_flag_values = {
        "--mode": str(summary.get("mode")),
        "--max-queries": str(resource.get("max_queries")),
        "--out": str(out_dir),
        "--generator": str(summary.get("generator")),
        "--namespace": str(manifest.get("namespace")),
    }
    for flag, expected in expected_flag_values.items():
        if flag_values.get(flag) != expected:
            add(errors, f"reproduce.sh {flag} value drift")
    if manifest.get("namespace") == "real_benchmark" and "--confirm-real-benchmark-namespace" not in parts:
        add(errors, "real_benchmark reproduce command must include confirmation flag")
    if summary.get("question_supplied") == "1":
        questions = [row.get("question", "") for row in read_csv(out_dir / "audit_findings.csv") if row.get("audit_type") == "user_question"]
        expected_question = questions[0] if len(questions) == 1 else ""
        if flag_values.get("--question") != expected_question:
            add(errors, "reproduce.sh question value drift")

    verify_path = out_dir / "verify.sh"
    if not (verify_path.stat().st_mode & stat.S_IXUSR):
        add(errors, "verify.sh must be executable")
    verify_text = verify_path.read_text(encoding="utf-8")
    if not verify_text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n"):
        add(errors, "verify.sh must use bash strict mode")
    verify_lines = verify_text.splitlines()
    if len(verify_lines) < 4:
        add(errors, "verify.sh must include repo-root cd and command lines")
        return
    try:
        verify_cd_parts = shlex.split(verify_lines[2])
    except ValueError as exc:
        add(errors, f"verify.sh cd line is not parseable: {exc}")
        return
    if verify_cd_parts != ["cd", str(repo_root)]:
        add(errors, "verify.sh repo-root cd drift")
    try:
        verify_parts = shlex.split(verify_lines[-1])
    except ValueError as exc:
        add(errors, f"verify.sh command is not parseable: {exc}")
        return
    expected_verify_parts = [
        "./scripts/audit_my_repo.sh",
        "--verify-existing",
        str(out_dir),
    ]
    if verify_parts != expected_verify_parts:
        add(errors, "verify.sh command drift")


def verify_manual_rows(out_dir: Path, summary: dict[str, str], errors: list[str]) -> None:
    findings = read_csv(out_dir / "audit_findings.csv")
    finding_ids = {row.get("finding_id", "") for row in findings}
    if len(finding_ids) != len(findings):
        add(errors, "audit_findings.csv must not contain duplicate finding_id values")
    if str(len(findings)) != summary.get("finding_rows"):
        add(errors, "finding row count drift")
    for row in findings:
        finding_id = row.get("finding_id", "")
        grounded = row.get("grounded")
        abstain = row.get("abstain")
        if grounded not in {"0", "1"} or abstain not in {"0", "1"}:
            add(errors, f"finding grounded/abstain flags must be binary: {finding_id}")
        elif grounded == "1" and abstain == "1":
            add(errors, f"finding cannot be both grounded and abstain: {finding_id}")
        elif grounded == "0" and abstain == "0":
            add(errors, f"ungrounded finding must abstain: {finding_id}")
        if row.get("abstain") == "1":
            if row.get("grounded") != "0":
                add(errors, f"abstain finding must not be grounded: {finding_id}")
            if not row.get("answer", "").startswith("Abstain:"):
                add(errors, f"abstain finding must keep explicit abstain answer boundary: {finding_id}")
    abstain_ids = {row.get("finding_id", "") for row in findings if row.get("abstain") == "1"}
    unsupported_ids = {row.get("finding_id", "") for row in findings if row.get("unsupported_claim") == "1"}
    abstain_rows = read_csv(out_dir / "abstain_rows.csv")
    unsupported_rows = read_csv(out_dir / "unsupported_claim_rows.csv")
    if {row.get("finding_id", "") for row in abstain_rows} != abstain_ids:
        add(errors, "abstain_rows.csv must exactly match abstaining findings")
    if {row.get("finding_id", "") for row in unsupported_rows} != unsupported_ids:
        add(errors, "unsupported_claim_rows.csv must exactly match unsupported-claim findings")
    if str(len(abstain_rows)) != summary.get("abstain_rows"):
        add(errors, "abstain row count drift")
    if str(len(unsupported_rows)) != summary.get("unsupported_claim_rows"):
        add(errors, "unsupported claim row count drift")

    guard_rows = read_csv(out_dir / "wrong_answer_guard_rows.csv")
    guard_by_finding = {row.get("finding_id", ""): row for row in guard_rows}
    if len(guard_by_finding) != len(guard_rows) or set(guard_by_finding) != finding_ids:
        add(errors, "wrong_answer_guard_rows.csv must contain exactly one row per finding")
    if len([row for row in guard_rows if row.get("wrong_answer_guard_pass") == "1"]) != len(guard_rows):
        add(errors, "wrong answer guard rows are not all passing")
    if str(len(guard_rows)) != summary.get("wrong_answer_guard_rows"):
        add(errors, "wrong answer guard row count drift")
    guard_pass_rows = [row for row in guard_rows if row.get("wrong_answer_guard_pass") == "1"]
    if str(len(guard_pass_rows)) != summary.get("wrong_answer_guard_pass_rows"):
        add(errors, "wrong answer guard pass row count drift")
    for finding_id, row in guard_by_finding.items():
        finding = next((item for item in findings if item.get("finding_id") == finding_id), {})
        expected_blocked = "1" if finding.get("abstain") == "1" or finding.get("grounded") == "1" else "0"
        if row.get("unsupported_direct_answer_blocked") != expected_blocked:
            add(errors, f"wrong answer guard blocked flag drift: {finding_id}")
        if row.get("citation_required") != "1" or row.get("audit_trail_required") != "1":
            add(errors, f"wrong answer guard must require citation and audit trail: {finding_id}")
    latency_rows = read_csv(out_dir / "latency_rows.csv")
    latency_ids = {row.get("finding_id", "") for row in latency_rows}
    if len(latency_ids) != len(latency_rows) or latency_ids != finding_ids:
        add(errors, "latency_rows.csv must contain exactly one row per finding")
    for row in latency_rows:
        if row.get("latency_ms") != "0" or row.get("latency_source") != "deterministic-local-smoke":
            add(errors, "latency rows must stay deterministic-local-smoke")
    accuracy_rows = read_csv(out_dir / "accuracy_rows.csv")
    accuracy_ids = {row.get("finding_id", "") for row in accuracy_rows}
    if len(accuracy_ids) != len(accuracy_rows) or accuracy_ids != finding_ids:
        add(errors, "accuracy_rows.csv must contain exactly one row per finding")
    if str(len(accuracy_rows)) != summary.get("accuracy_rows"):
        add(errors, "accuracy row count drift")
    for row in accuracy_rows:
        if row.get("automatic_accuracy_claimed") != "0" or row.get("manual_accuracy_review_required") != "1":
            add(errors, "accuracy rows must remain manual/unreviewed")
    citation_rows = read_csv(out_dir / "citation_correctness_rows.csv")
    citation_ids = {row.get("finding_id", "") for row in citation_rows}
    if len(citation_ids) != len(citation_rows) or citation_ids != finding_ids:
        add(errors, "citation_correctness_rows.csv must contain exactly one row per finding")
    if str(len(citation_rows)) != summary.get("citation_correctness_rows"):
        add(errors, "citation correctness row count drift")
    for row in citation_rows:
        if row.get("citation_correctness_label") != "source_bound_unreviewed" or row.get("manual_citation_review_required") != "1":
            add(errors, "citation correctness rows must remain source-bound unreviewed")
    fp_rows = read_csv(out_dir / "false_positive_candidate_rows.csv")
    fp_ids = {row.get("finding_id", "") for row in fp_rows}
    if len(fp_ids) != len(fp_rows) or fp_ids != finding_ids:
        add(errors, "false_positive_candidate_rows.csv must contain exactly one row per finding")
    if str(len(fp_rows)) != summary.get("false_positive_candidate_rows"):
        add(errors, "false-positive candidate row count drift")
    for row in fp_rows:
        if row.get("auto_promoted") != "0":
            add(errors, "false-positive candidates must not be auto-promoted")
    manual_review_rows = read_csv(out_dir / "manual_review_queue.csv")
    manual_review_ids = {row.get("finding_id", "") for row in manual_review_rows}
    if len(manual_review_ids) != len(manual_review_rows) or manual_review_ids != finding_ids:
        add(errors, "manual_review_queue.csv must contain exactly one row per finding")
    if str(len(manual_review_rows)) != summary.get("manual_review_queue_rows"):
        add(errors, "manual_review_queue_rows summary mismatch")
    review_queue_ids = {row.get("review_queue_id", "") for row in manual_review_rows}
    if len(review_queue_ids) != len(manual_review_rows) or "" in review_queue_ids:
        add(errors, "manual_review_queue.csv review_queue_id values must be unique and non-empty")
    for row in manual_review_rows:
        if row.get("review_types") != "accuracy|citation_correctness|false_positive":
            add(errors, "manual_review_queue.csv review_types drifted")
        if row.get("manual_review_required") != "1" or row.get("auto_promoted") != "0":
            add(errors, "manual review queue rows must require manual review and forbid auto-promotion")
        if "unreviewed" not in row.get("review_reason", ""):
            add(errors, "manual review queue rows must preserve unreviewed reason")


def verify_route_generation_rows(out_dir: Path, summary: dict[str, str], errors: list[str]) -> None:
    findings = read_csv(out_dir / "audit_findings.csv")
    finding_by_id = {row.get("finding_id", ""): row for row in findings}
    finding_ids = set(finding_by_id)
    citation_counts = {
        finding_id: len([cell for cell in row.get("citations", "").split(";") if cell])
        for finding_id, row in finding_by_id.items()
    }

    hint_rows = read_csv(out_dir / "compact_route_hint_rows.csv")
    hint_by_finding = {row.get("finding_id", ""): row for row in hint_rows}
    if len(hint_by_finding) != len(hint_rows) or set(hint_by_finding) != finding_ids:
        add(errors, "compact_route_hint_rows.csv must contain exactly one row per finding")
    if str(len(hint_rows)) != summary.get("compact_route_hint_rows"):
        add(errors, "compact route hint row count drift")
    hint_ids = set()
    for finding_id, row in hint_by_finding.items():
        hint_id = row.get("hint_id", "")
        if not hint_id:
            add(errors, f"route hint id missing: {finding_id}")
        if hint_id in hint_ids:
            add(errors, f"duplicate route hint id: {hint_id}")
        hint_ids.add(hint_id)
        if row.get("source_citation_count") != str(citation_counts.get(finding_id, -1)):
            add(errors, f"route hint citation count drift: {finding_id}")
        if row.get("raw_context_appended") != "0" or row.get("proposal_hint_used") != "1":
            add(errors, "route hints must use compact proposal hints without raw context")

    generation_rows = read_csv(out_dir / "grounded_generation_rows.csv")
    generation_by_finding = {row.get("finding_id", ""): row for row in generation_rows}
    if len(generation_by_finding) != len(generation_rows) or set(generation_by_finding) != finding_ids:
        add(errors, "grounded_generation_rows.csv must contain exactly one row per finding")
    if str(len(generation_rows)) != summary.get("grounded_generation_rows"):
        add(errors, "grounded generation row count drift")
    generation_ids = set()
    for finding_id, row in generation_by_finding.items():
        finding = finding_by_id.get(finding_id, {})
        generation_id = row.get("generation_id", "")
        if not generation_id:
            add(errors, f"generation id missing: {finding_id}")
        if generation_id in generation_ids:
            add(errors, f"duplicate generation id: {generation_id}")
        generation_ids.add(generation_id)
        if row.get("hint_id") != hint_by_finding.get(finding_id, {}).get("hint_id"):
            add(errors, f"generation hint binding drift: {finding_id}")
        for key in ["grounded", "abstain", "unsupported_claim", "answer"]:
            if row.get(key) != finding.get(key):
                add(errors, f"generation/finding drift: {finding_id} {key}")
        if row.get("raw_prompt_context_bytes") != "0" or row.get("attention_blocks") != "0" or row.get("transformer_blocks") != "0":
            add(errors, "generation rows must not claim raw prompt stuffing or attention/transformer blocks")

    lineage_rows = read_jsonl(out_dir / "prediction_lineage.jsonl")
    lineage_by_finding = {str(row.get("finding_id", "")): row for row in lineage_rows}
    if len(lineage_by_finding) != len(lineage_rows) or set(lineage_by_finding) != finding_ids:
        add(errors, "prediction_lineage.jsonl must contain exactly one row per finding")
    if str(len(lineage_rows)) != summary.get("route_memory_lineage_rows"):
        add(errors, "prediction lineage row count drift")
    for finding_id, row in lineage_by_finding.items():
        if str(row.get("compact_route_hint_id")) != hint_by_finding.get(finding_id, {}).get("hint_id"):
            add(errors, f"lineage hint id not bound: {finding_id}")
        if str(row.get("generator_id")) != generation_by_finding.get(finding_id, {}).get("generation_id"):
            add(errors, f"lineage generator id not bound: {finding_id}")
        if str(row.get("citation_count")) != str(citation_counts.get(finding_id, -1)):
            add(errors, f"lineage citation count drift: {finding_id}")
        if str(row.get("audit_trail_bound")) != "1":
            add(errors, f"lineage audit trail must be bound: {finding_id}")

    citation_rows = read_csv(out_dir / "citation_spans.csv")
    expected_mmap_keys = {
        (
            row.get("finding_id", ""),
            row.get("file_path", ""),
            str(row.get("line_start", "")),
            row.get("sha256", ""),
        )
        for row in citation_rows
    }
    mmap_rows = read_jsonl(out_dir / "mmap_read_trace.jsonl")
    mmap_keys = {
        (
            str(row.get("finding_id", "")),
            str(row.get("file_path", "")),
            str(row.get("line_start", "")),
            str(row.get("sha256", "")),
        )
        for row in mmap_rows
    }
    if mmap_keys != expected_mmap_keys or len(mmap_keys) != len(mmap_rows):
        add(errors, "mmap read trace must exactly match citation spans")
    if str(len(mmap_rows)) != summary.get("mmap_read_trace_rows"):
        add(errors, "mmap read trace row count drift")
    for row in mmap_rows:
        if str(row.get("finding_id", "")) not in finding_ids:
            add(errors, "mmap read trace references unknown finding")
        if str(row.get("mmap_value_byte_read")) != "1":
            add(errors, "mmap read trace must prove value byte read")


def verify_local_audit(out_dir: Path) -> list[str]:
    errors: list[str] = []
    for rel in REQUIRED_FILES:
        if not (out_dir / rel).is_file():
            add(errors, f"missing required artifact: {rel}")
    if errors:
        return errors
    sha_entries = verify_sha_manifest(out_dir, errors)
    verify_schema_instances(out_dir, errors)
    manifest = read_json(out_dir / "audit_manifest.json")
    summary_json = read_json(out_dir / "audit_summary.json")
    summary = verify_summary(summary_json, read_csv(out_dir / "audit_summary.csv"), errors)
    verify_manifest(manifest, summary_json, out_dir, errors)
    verify_resource(read_json(out_dir / "resource_envelope.json"), summary, errors)
    verify_invocation(out_dir, manifest, summary, errors)
    verify_exit_code_contract(out_dir, errors)
    verify_claim_boundary_docs(out_dir, errors)
    verify_audit_report(out_dir, summary, errors)
    registry = read_json(out_dir / "plugin_registry.json")
    verify_registry(registry, errors)
    verify_finding_registry_binding(out_dir, registry, errors)
    verify_plugin_rules(out_dir, registry, errors)
    verify_contract(out_dir, sha_entries, errors)
    verify_csv_jsonl(out_dir, errors)
    source_by_path = verify_sources(out_dir, manifest, errors)
    verify_source_snapshot(out_dir, manifest, source_by_path, errors)
    verify_citations(out_dir, manifest, source_by_path, errors)
    verify_cache_key(out_dir, manifest, summary, errors)
    verify_reproduce(out_dir, manifest, summary, errors)
    verify_manual_rows(out_dir, summary, errors)
    verify_route_generation_rows(out_dir, summary, errors)
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Verify local audit product artifacts.")
    parser.add_argument("out_dir")
    args = parser.parse_args(argv)
    try:
        errors = verify_local_audit(Path(args.out_dir).resolve())
    except (
        OSError,
        UnicodeDecodeError,
        json.JSONDecodeError,
        csv.Error,
        KeyError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as exc:
        print(f"local_audit_verify_error: {exc}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("local_audit_verify: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
