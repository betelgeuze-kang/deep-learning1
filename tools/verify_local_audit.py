#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import os
import shlex
import stat
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from audit_my_repo import CSV_CONTRACTS as EXPECTED_CSV_CONTRACTS
from audit_my_repo import JSON_CONTRACTS as EXPECTED_JSON_CONTRACTS
from audit_my_repo import JSONL_CONTRACTS as EXPECTED_JSONL_CONTRACTS


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
    "AUDIT_DASHBOARD.html",
    "AUDIT_REPORT.md",
    "abstain_rows.csv",
    "accuracy_rows.csv",
    "accuracy_rows.json",
    "artifact_contract_rows.csv",
    "audit_dashboard.json",
    "audit_findings.csv",
    "audit_findings.json",
    "audit_findings.jsonl",
    "audit_findings.sarif.json",
    "audit_invocation.json",
    "audit_manifest.json",
    "audit_semantic_summary.json",
    "audit_summary.csv",
    "audit_summary.json",
    "baseline_diff_rows.csv",
    "baseline_diff_summary.json",
    "BASELINE_DIFF.md",
    "citation_correctness_rows.csv",
    "citation_correctness_rows.json",
    "citation_spans.csv",
    "citation_spans.jsonl",
    "claim_boundary.md",
    "compact_route_hint_rows.csv",
    "diagnostics.json",
    "exit_code_contract.json",
    "false_positive_candidate_rows.csv",
    "grounded_generation_rows.csv",
    "latency_rows.csv",
    "manual_review_queue.csv",
    "manual_review_queue.json",
    "mmap_read_trace.jsonl",
    "phase_timing_rows.csv",
    "plugin_registry.json",
    "plugin_rule_rows.csv",
    "prediction_lineage.jsonl",
    "reproduce.sh",
    "resource_envelope.json",
    "sha256sums.txt",
    "source_manifest.csv",
    "source_snapshot.json",
    "suppressed_findings.csv",
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
    "source_scope",
    "changed_file_rows",
    "finding_rows",
    "suppression_rows",
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
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "gpu_speedup_claim",
    "max_files",
    "max_total_bytes",
    "max_file_bytes",
    "max_findings",
    "active_plugin_ids",
    "scan_latency_ms",
    "plugin_latency_ms",
    "serialize_latency_ms",
    "verify_latency_ms",
    "latency_ms",
]
EXPECTED_ARTIFACT_CONTRACT_FIELDS = [
    "schema_version",
    "artifact_path",
    "artifact_kind",
    "required_columns",
    "actual_columns",
    "required_keys",
    "actual_keys",
    "min_rows",
    "actual_rows",
    "sha256_manifest_required",
    "deterministic_required",
]
EXPECTED_TEXT_ARTIFACT_KINDS = {
    "AUDIT_DASHBOARD.html": "html",
    "AUDIT_REPORT.md": "markdown",
    "ARCHITECTURE_TRACE.md": "markdown",
    "BASELINE_DIFF.md": "markdown",
    "claim_boundary.md": "markdown",
    "reproduce.sh": "shell",
    "verify.sh": "shell",
}
EXPECTED_ARTIFACT_KINDS = {
    **{rel: "csv" for rel in EXPECTED_CSV_CONTRACTS},
    **{rel: "jsonl" for rel in EXPECTED_JSONL_CONTRACTS},
    **{rel: "json" for rel in EXPECTED_JSON_CONTRACTS},
    **EXPECTED_TEXT_ARTIFACT_KINDS,
}
SCHEMA_FILES = (
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
)
SCHEMA_INSTANCE_PAIRS = [
    ("schemas/local_repo_audit_output.schema.json", "audit_manifest.json"),
    ("schemas/local_repo_audit_diagnostics.schema.json", "diagnostics.json"),
    ("schemas/local_repo_audit_dashboard.schema.json", "audit_dashboard.json"),
    ("schemas/local_repo_audit_exit_code_contract.schema.json", "exit_code_contract.json"),
    ("schemas/local_repo_audit_accuracy_rows.schema.json", "accuracy_rows.json"),
    ("schemas/local_repo_audit_citation_correctness_rows.schema.json", "citation_correctness_rows.json"),
    ("schemas/local_repo_audit_findings.schema.json", "audit_findings.json"),
    ("schemas/local_repo_audit_invocation.schema.json", "audit_invocation.json"),
    ("schemas/local_repo_audit_manual_review_queue.schema.json", "manual_review_queue.json"),
    ("schemas/local_repo_audit_semantic_summary.schema.json", "audit_semantic_summary.json"),
    ("schemas/local_repo_audit_summary.schema.json", "audit_summary.json"),
    ("schemas/local_repo_audit_sarif.schema.json", "audit_findings.sarif.json"),
    ("schemas/local_repo_audit_baseline_diff.schema.json", "baseline_diff_summary.json"),
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


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def schema_sha256s(repo_root: Path) -> dict[str, str]:
    return {rel: sha256_prefixed(repo_root / rel) for rel in SCHEMA_FILES}


def sha256_baseline_output(path: Path) -> str:
    digest = hashlib.sha256()
    for rel in [
        "audit_manifest.json",
        "audit_findings.csv",
        "citation_spans.csv",
        "source_manifest.csv",
        "sha256sums.txt",
    ]:
        artifact = path / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256_prefixed(artifact).encode("utf-8"))
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def publish_root_for(out_dir: Path, manifest: dict | None = None) -> Path:
    run_id = str((manifest or {}).get("run_id", ""))
    if out_dir.parent.name == "runs" and (not run_id or out_dir.name == run_id):
        return out_dir.parent.parent
    if manifest and ".staging" in out_dir.parts:
        latest_pointer = str(manifest.get("latest_pointer", ""))
        if latest_pointer:
            return Path(latest_pointer).parent
    return out_dir


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def csv_fieldnames(path: Path) -> list[str]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or [])


def read_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def string_values(payload) -> list[str]:
    if isinstance(payload, str):
        return [payload]
    if isinstance(payload, list):
        values: list[str] = []
        for item in payload:
            values.extend(string_values(item))
        return values
    if isinstance(payload, dict):
        values: list[str] = []
        for item in payload.values():
            values.extend(string_values(item))
        return values
    return []


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


def verify_bundle_artifact_set(bundle_dir: Path, errors: list[str], context: str) -> None:
    seen: set[str] = set()
    for path in sorted(bundle_dir.rglob("*")):
        rel = path.relative_to(bundle_dir).as_posix()
        if rel not in REQUIRED_FILES:
            add(errors, f"{context} contains unmanifested artifact: {rel}")
            continue
        seen.add(rel)
        if path.is_symlink():
            add(errors, f"{context} artifact must not be a symlink: {rel}")
        elif not path.is_file():
            add(errors, f"{context} artifact must be a regular file: {rel}")
    for rel in REQUIRED_FILES:
        if rel not in seen:
            add(errors, f"{context} missing manifest-bound artifact: {rel}")


def verify_artifact_publish_layout(out_dir: Path, manifest: dict, errors: list[str]) -> None:
    is_bundle_dir = out_dir.parent.name == "runs" or ".staging" in out_dir.parts
    if is_bundle_dir:
        verify_bundle_artifact_set(out_dir, errors, "audit bundle")
        return

    run_id = str(manifest.get("run_id", ""))
    runs_dir = out_dir / "runs"
    latest_link = out_dir / "latest"
    if not runs_dir.is_dir():
        add(errors, "published audit output missing runs directory")
    if not latest_link.is_symlink():
        add(errors, "published audit output latest pointer must be a symlink")
    elif os.readlink(latest_link) != f"runs/{run_id}":
        add(errors, "published audit output latest pointer target mismatch")

    for child in sorted(out_dir.iterdir()):
        if child.name in REQUIRED_FILES or child.name in {"latest", "runs"}:
            continue
        if child.name == ".staging":
            add(errors, "published audit output must not expose .staging")
            continue
        if child.is_symlink():
            add(errors, f"published audit output exposes unmanifested audit symlink: {child.name}")

    for rel in REQUIRED_FILES:
        compat_path = out_dir / rel
        if not compat_path.is_symlink():
            add(errors, f"published compatibility artifact must be a latest symlink: {rel}")
            continue
        if os.readlink(compat_path) != f"latest/{rel}":
            add(errors, f"published compatibility artifact symlink target mismatch: {rel}")

    bundle_dir = runs_dir / run_id
    if bundle_dir.is_dir():
        verify_bundle_artifact_set(bundle_dir, errors, "latest audit bundle")
    else:
        add(errors, "published audit output latest bundle directory is missing")


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
        "release_ready",
        "public_comparison_claim_ready",
        "real_model_execution_ready",
    ]:
        if str(summary_json.get(key)) != "0":
            add(errors, f"blocked summary claim must remain zero: {key}")
    if summary_json.get("gpu_speedup_claim") != "deferred":
        add(errors, "gpu_speedup_claim must remain deferred")
    phase_sum = 0
    for key in ["scan_latency_ms", "plugin_latency_ms", "serialize_latency_ms", "verify_latency_ms"]:
        value = int(summary_json.get(key, 0))
        if value <= 0:
            add(errors, f"summary phase timing must be measured and positive: {key}")
        phase_sum += value
    if int(summary_json.get("latency_ms", 0)) != phase_sum:
        add(errors, "summary latency_ms must equal measured phase timing sum")
    return row


def verify_manifest(manifest: dict, summary_json: dict, out_dir: Path, errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    publish_root = publish_root_for(out_dir, manifest)
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    for key, expected in {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "tool_source_sha256": sha256_prefixed(repo_root / "scripts" / "audit_my_repo.py"),
        "verifier_source_sha256": sha256_prefixed(repo_root / "tools" / "verify_local_audit.py"),
        "generated_at_utc": "1970-01-01T00:00:00+00:00",
        "atomic_publish": 1,
        "output_dir_destroyed": 0,
        "output_dir_overwritten": 0,
        "fixture_result_promoted": 0,
        "real_evidence_claimed": 0,
        "publish_mode": "versioned-run-dir-with-latest-pointer",
        "claim_boundary": CLAIM_BOUNDARY,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }.items():
        if manifest.get(key) != expected:
            add(errors, f"audit_manifest.{key} mismatch")
    if manifest.get("schema_sha256s") != schema_sha256s(repo_root):
        add(errors, "audit_manifest.schema_sha256s mismatch")
    run_id = str(manifest.get("run_id", ""))
    if not run_id.startswith("run-") or len(run_id) != 20:
        add(errors, "audit_manifest.run_id invalid")
    if manifest.get("bundle_run_dir") != str(publish_root / "runs" / run_id):
        add(errors, "audit_manifest.bundle_run_dir mismatch")
    if manifest.get("latest_pointer") != str(publish_root / "latest"):
        add(errors, "audit_manifest.latest_pointer mismatch")
    if manifest.get("namespace") not in {"fixture", "synthetic", "real_benchmark"}:
        add(errors, "audit_manifest.namespace invalid")
    if manifest.get("source_scope") not in {"tracked", "changed-files"}:
        add(errors, "audit_manifest.source_scope invalid")
    if str(manifest.get("source_scope")) != str(summary_json.get("source_scope")):
        add(errors, "audit_manifest source_scope does not match summary")
    if str(manifest.get("changed_file_rows")) != str(summary_json.get("changed_file_rows")):
        add(errors, "audit_manifest changed_file_rows does not match summary")
    if manifest.get("source_scope") == "tracked":
        if manifest.get("changed_files_from") != "" or manifest.get("changed_files_from_sha256") != sha256_text("") or manifest.get("changed_file_rows") != 0:
            add(errors, "tracked manifest must bind empty changed-files input")
    elif manifest.get("source_scope") == "changed-files":
        changed_files_from = str(manifest.get("changed_files_from", ""))
        changed_files_path = Path(changed_files_from)
        if not changed_files_from:
            add(errors, "changed-files manifest must bind changed_files_from")
        elif is_forbidden_env_path(changed_files_path):
            add(errors, "changed-files manifest input must not be .env-like")
        elif not changed_files_path.is_file():
            add(errors, "changed-files manifest input file is missing")
        elif manifest.get("changed_files_from_sha256") != sha256_prefixed(changed_files_path):
            add(errors, "changed-files manifest input sha mismatch")
        expected_changed_rows = changed_file_input_row_count(changed_files_from, target, errors, "manifest")
        if expected_changed_rows is not None and int(manifest.get("changed_file_rows", 0)) != expected_changed_rows:
            add(errors, "changed-files manifest row count mismatch")
        if int(manifest.get("changed_file_rows", 0)) <= 0:
            add(errors, "changed-files manifest must record at least one changed file row")
    expected_real_namespace_confirmed = 1 if manifest.get("namespace") == "real_benchmark" else 0
    if manifest.get("real_benchmark_namespace_confirmed") != expected_real_namespace_confirmed:
        add(errors, "audit_manifest.real_benchmark_namespace_confirmed mismatch")
    if manifest.get("plugin_registry_sha256") != sha256_prefixed(out_dir / "plugin_registry.json"):
        add(errors, "plugin registry hash mismatch")
    baseline_output = str(manifest.get("baseline_output", ""))
    if baseline_output:
        baseline_path = Path(baseline_output)
        if not baseline_path.is_dir():
            add(errors, "audit_manifest baseline_output is missing")
        elif manifest.get("baseline_output_sha256") != sha256_baseline_output(baseline_path):
            add(errors, "audit_manifest baseline_output_sha256 mismatch")
    elif manifest.get("baseline_output_sha256") != sha256_text(""):
        add(errors, "empty baseline_output must bind empty sha256")
    if str(manifest.get("source_file_count")) != str(summary_json.get("source_files")):
        add(errors, "manifest source count does not match summary")
    if str(manifest.get("finding_rows")) != str(summary_json.get("finding_rows")):
        add(errors, "manifest finding count does not match summary")
    if str(manifest.get("suppression_rows")) != str(summary_json.get("suppression_rows")):
        add(errors, "manifest suppression count does not match summary")
    if manifest.get("emit_diagnostics_requested") not in {0, 1}:
        add(errors, "audit_manifest.emit_diagnostics_requested must be binary")


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
        "source_scope": "source_scope",
        "changed_file_rows": "changed_file_rows",
        "wrong_answer_guard_rows": "wrong_answer_guard_rows",
        "suppression_rows": "suppression_rows",
        "latency_ms": "latency_ms",
        "max_files": "max_files",
        "max_total_bytes": "max_total_bytes",
        "max_file_bytes": "max_file_bytes",
        "max_findings": "max_findings",
        "active_plugin_ids": "active_plugin_ids",
        "scan_latency_ms": "scan_latency_ms",
        "plugin_latency_ms": "plugin_latency_ms",
        "serialize_latency_ms": "serialize_latency_ms",
        "verify_latency_ms": "verify_latency_ms",
        "mode": "mode",
        "namespace": "namespace",
    }.items():
        if str(resource.get(resource_key)) != str(summary.get(summary_key)):
            add(errors, f"resource envelope drift: {resource_key}")
    phase_total = sum(int(resource.get(key, 0)) for key in ["scan_latency_ms", "plugin_latency_ms", "serialize_latency_ms", "verify_latency_ms"])
    if int(resource.get("latency_ms", 0)) != phase_total:
        add(errors, "resource latency_ms must equal measured phase timing sum")


def changed_file_input_row_count(path_text: str, target: Path, errors: list[str], label: str) -> int | None:
    path = Path(path_text)
    if is_forbidden_env_path(path):
        add(errors, f"changed-files {label} input must not be .env-like")
        return None
    if not path.is_file():
        return None
    seen: set[str] = set()
    rows: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        raw = line.strip()
        if not raw:
            continue
        if "\0" in raw:
            add(errors, f"changed-files {label} input line {line_number} contains a NUL byte")
            continue
        rel_path = Path(raw)
        if raw.startswith("~") or rel_path.is_absolute() or ".." in rel_path.parts:
            add(errors, f"changed-files {label} input line {line_number} must be relative")
            continue
        normalized = rel_path.as_posix()
        if normalized in {"", "."}:
            continue
        try:
            (target / normalized).resolve().relative_to(target)
        except (OSError, ValueError):
            add(errors, f"changed-files {label} input line {line_number} escapes target repo")
            continue
        if normalized not in seen:
            rows.append(normalized)
            seen.add(normalized)
    if not rows:
        add(errors, f"changed-files {label} input must contain at least one relative path")
    return len(rows)


def verify_budget_envelope(out_dir: Path, resource: dict, errors: list[str]) -> None:
    def positive_int(key: str) -> int:
        try:
            value = int(resource.get(key, 0))
        except (TypeError, ValueError):
            add(errors, f"resource_envelope.{key} must be an integer budget")
            return 0
        if value <= 0:
            add(errors, f"resource_envelope.{key} must be positive")
        return value

    max_files = positive_int("max_files")
    max_total_bytes = positive_int("max_total_bytes")
    max_file_bytes = positive_int("max_file_bytes")
    max_findings = positive_int("max_findings")
    source_rows = read_csv(out_dir / "source_manifest.csv")
    finding_rows = read_csv(out_dir / "audit_findings.csv")
    source_bytes_total = 0
    if max_files and len(source_rows) > max_files:
        add(errors, "source files exceed max_files budget")
    if max_findings and len(finding_rows) > max_findings:
        add(errors, "finding rows exceed max_findings budget")
    for row in source_rows:
        rel = row.get("file_path", "")
        try:
            size = int(row.get("bytes", "0"))
        except ValueError:
            add(errors, f"source manifest bytes must be integer: {rel}")
            continue
        if size <= 0:
            add(errors, f"source manifest bytes must be positive: {rel}")
        if max_file_bytes and size > max_file_bytes:
            add(errors, f"source file exceeds max_file_bytes budget: {rel}")
        source_bytes_total += max(size, 0)
    if max_total_bytes and source_bytes_total > max_total_bytes:
        add(errors, "source files exceed max_total_bytes budget")


def verify_invocation(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    invocation = read_json(out_dir / "audit_invocation.json")
    publish_root = publish_root_for(out_dir, manifest)
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    expected_keys = {
        "schema_version",
        "tool_version",
        "target_repo",
        "out_dir",
        "mode",
        "max_queries",
        "max_files",
        "max_total_bytes",
        "max_file_bytes",
        "max_findings",
        "source_scope",
        "changed_files_from",
        "changed_files_from_sha256",
        "changed_file_rows",
        "active_plugin_ids",
        "suppression_file",
        "suppression_file_sha256",
        "baseline_output",
        "baseline_output_sha256",
        "generator",
        "namespace",
        "real_benchmark_namespace_confirmed",
        "question_supplied",
        "question_sha256",
        "verify_output_requested",
        "emit_report_requested",
        "emit_lineage_requested",
        "emit_reproduce_requested",
        "emit_diagnostics_requested",
    }
    if set(invocation) != expected_keys:
        add(errors, "audit_invocation.json keys drifted")
    for key, expected in {
        "schema_version": "local_repo_audit_invocation.v1",
        "tool_version": TOOL_VERSION,
        "target_repo": str(manifest.get("target_repo")),
        "out_dir": str(publish_root),
        "mode": str(summary.get("mode")),
        "source_scope": str(summary.get("source_scope")),
        "changed_file_rows": int(summary.get("changed_file_rows", -1)),
        "generator": str(summary.get("generator")),
        "namespace": str(manifest.get("namespace")),
        "real_benchmark_namespace_confirmed": int(manifest.get("real_benchmark_namespace_confirmed", -1)),
        "question_supplied": int(summary.get("question_supplied", -1)),
        "emit_report_requested": 1,
        "emit_lineage_requested": 1,
        "emit_reproduce_requested": 1,
        "emit_diagnostics_requested": int(manifest.get("emit_diagnostics_requested", -1)),
    }.items():
        if invocation.get(key) != expected:
            add(errors, f"audit_invocation.{key} mismatch")
    resource = read_json(out_dir / "resource_envelope.json")
    if str(invocation.get("max_queries")) != str(resource.get("max_queries")):
        add(errors, "audit_invocation max_queries mismatch")
    for key in ["max_files", "max_total_bytes", "max_file_bytes", "max_findings", "source_scope", "changed_file_rows", "active_plugin_ids"]:
        if str(invocation.get(key)) != str(resource.get(key)):
            add(errors, f"audit_invocation {key} mismatch")
    if invocation.get("source_scope") != manifest.get("source_scope"):
        add(errors, "audit_invocation source_scope must match manifest")
    if invocation.get("changed_files_from") != manifest.get("changed_files_from"):
        add(errors, "audit_invocation changed_files_from must match manifest")
    if invocation.get("changed_files_from_sha256") != manifest.get("changed_files_from_sha256"):
        add(errors, "audit_invocation changed_files_from_sha256 must match manifest")
    if invocation.get("changed_file_rows") != manifest.get("changed_file_rows"):
        add(errors, "audit_invocation changed_file_rows must match manifest")
    changed_files_from = str(invocation.get("changed_files_from", ""))
    if invocation.get("source_scope") == "tracked":
        if changed_files_from or invocation.get("changed_files_from_sha256") != sha256_text("") or invocation.get("changed_file_rows") != 0:
            add(errors, "tracked invocation must bind empty changed-files input")
    elif invocation.get("source_scope") == "changed-files":
        if not changed_files_from:
            add(errors, "changed-files invocation must bind changed_files_from")
        else:
            changed_files_path = Path(changed_files_from)
            if is_forbidden_env_path(changed_files_path):
                add(errors, "changed-files invocation input must not be .env-like")
            elif not changed_files_path.is_file():
                add(errors, "changed-files invocation input file is missing")
            elif invocation.get("changed_files_from_sha256") != sha256_prefixed(changed_files_path):
                add(errors, "changed-files invocation input sha mismatch")
        expected_changed_rows = changed_file_input_row_count(changed_files_from, target, errors, "invocation")
        if expected_changed_rows is not None and int(invocation.get("changed_file_rows", 0)) != expected_changed_rows:
            add(errors, "changed-files invocation row count mismatch")
        if int(invocation.get("changed_file_rows", 0)) <= 0:
            add(errors, "changed-files invocation must record at least one changed file row")
    suppression_file = str(invocation.get("suppression_file", ""))
    if suppression_file:
        suppression_path = Path(suppression_file)
        if not suppression_path.is_file():
            add(errors, "audit_invocation suppression_file is missing")
        elif invocation.get("suppression_file_sha256") != sha256_prefixed(suppression_path):
            add(errors, "audit_invocation suppression_file_sha256 mismatch")
    elif invocation.get("suppression_file_sha256") != sha256_text(""):
        add(errors, "empty suppression_file must bind empty sha256")
    if invocation.get("suppression_file_sha256") != manifest.get("suppression_file_sha256"):
        add(errors, "audit_invocation suppression hash must match manifest")
    baseline_output = str(invocation.get("baseline_output", ""))
    if baseline_output:
        baseline_path = Path(baseline_output)
        if not baseline_path.is_dir():
            add(errors, "audit_invocation baseline_output is missing")
        elif invocation.get("baseline_output_sha256") != sha256_baseline_output(baseline_path):
            add(errors, "audit_invocation baseline_output_sha256 mismatch")
    elif invocation.get("baseline_output_sha256") != sha256_text(""):
        add(errors, "empty baseline_output must bind empty sha256")
    if invocation.get("baseline_output") != manifest.get("baseline_output"):
        add(errors, "audit_invocation baseline path must match manifest")
    if invocation.get("baseline_output_sha256") != manifest.get("baseline_output_sha256"):
        add(errors, "audit_invocation baseline hash must match manifest")
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
        "`real_release_package_ready=0`, `release_ready=0`, `public_comparison_claim_ready=0`, `real_model_execution_ready=0`, and `gpu_speedup_claim=deferred` remain explicit.",
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


def verify_audit_dashboard(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    payload = read_json(out_dir / "audit_dashboard.json")
    dashboard = (out_dir / "AUDIT_DASHBOARD.html").read_text(encoding="utf-8")
    baseline_summary = read_json(out_dir / "baseline_diff_summary.json")
    findings = read_csv(out_dir / "audit_findings.csv")

    def esc(value: object) -> str:
        return html.escape(str(value), quote=True)

    expected_diff_counts = {
        key: int(baseline_summary.get(key, 0))
        for key in [
            "not_compared_findings",
            "new_findings",
            "changed_findings",
            "resolved_findings",
            "unchanged_findings",
            "manual_review_required_rows",
        ]
    }
    expected_review_counts = {
        "finding_rows": int(summary.get("finding_rows", 0)),
        "source_files": int(summary.get("source_files", 0)),
        "citation_span_rows": int(summary.get("citation_span_rows", 0)),
        "abstain_rows": int(summary.get("abstain_rows", 0)),
        "unsupported_claim_rows": int(summary.get("unsupported_claim_rows", 0)),
        "manual_review_queue_rows": int(summary.get("manual_review_queue_rows", 0)),
        "suppression_rows": int(summary.get("suppression_rows", 0)),
    }
    expected_readiness = {
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "automatic_accuracy_claimed": 0,
        "design_partner_beta_candidate_ready": 0,
    }
    expected_links = {
        "audit_report": "AUDIT_REPORT.md",
        "baseline_diff": "BASELINE_DIFF.md",
        "findings_json": "audit_findings.json",
        "findings_sarif": "audit_findings.sarif.json",
        "manual_review_queue": "manual_review_queue.csv",
        "reproduce": "reproduce.sh",
        "verify": "verify.sh",
    }
    for key, expected in {
        "schema_version": "local_repo_audit_dashboard.v1",
        "tool_version": TOOL_VERSION,
        "dashboard_kind": "local-audit-diff-dashboard",
        "claim_boundary": CLAIM_BOUNDARY,
        "generated_at_utc": "1970-01-01T00:00:00+00:00",
        "target_repo": manifest.get("target_repo", ""),
        "cache_key": manifest.get("cache_key", ""),
        "run_id": manifest.get("run_id", ""),
        "mode": summary.get("mode", ""),
        "namespace": summary.get("namespace", ""),
        "source_scope": summary.get("source_scope", ""),
    }.items():
        if payload.get(key) != expected:
            add(errors, f"audit_dashboard.json metadata drift: {key}")
    expected_baseline = {
        "supplied": int(baseline_summary.get("baseline_supplied", 0)),
        "baseline_output_sha256": baseline_summary.get("baseline_output_sha256", ""),
        "baseline_manifest_sha256": baseline_summary.get("baseline_manifest_sha256", ""),
        "baseline_cache_key": baseline_summary.get("baseline_cache_key", ""),
    }
    if payload.get("baseline") != expected_baseline:
        add(errors, "audit_dashboard.json baseline drift")
    if payload.get("diff_counts") != expected_diff_counts:
        add(errors, "audit_dashboard.json diff_counts drift")
    if payload.get("review_counts") != expected_review_counts:
        add(errors, "audit_dashboard.json review_counts drift")
    if payload.get("readiness") != expected_readiness:
        add(errors, "audit_dashboard.json readiness drift")
    if payload.get("links") != expected_links:
        add(errors, "audit_dashboard.json links drift")
    expected_top_findings = []
    for row in findings[:20]:
        citations = [cell for cell in str(row.get("citations", "")).split(";") if cell]
        expected_top_findings.append(
            {
                "finding_id": str(row.get("finding_id", "")),
                "plugin_id": str(row.get("plugin_id", "")),
                "rule_ids": [cell for cell in str(row.get("plugin_rule_ids", "")).split("|") if cell],
                "severity": str(row.get("severity", "")),
                "confidence": str(row.get("confidence", "")),
                "language": str(row.get("language", "")),
                "grounded": int(row.get("grounded", 0)),
                "abstain": int(row.get("abstain", 0)),
                "unsupported_claim": int(row.get("unsupported_claim", 0)),
                "suppressed": int(row.get("suppressed", 0)),
                "citation_count": len(citations),
                "primary_citation": citations[0] if citations else "",
                "citation_sha256s": [cell for cell in str(row.get("citation_sha256s", "")).split(";") if cell],
                "answer_preview": str(row.get("answer", ""))[:220],
            }
        )
    if payload.get("top_findings") != expected_top_findings:
        add(errors, "audit_dashboard.json top_findings drift")

    expected_tokens = [
        '<html lang="en"',
        'data-schema-version="local_repo_audit_dashboard.v1"',
        f'data-tool-version="{TOOL_VERSION}"',
        f'data-run-id="{esc(manifest.get("run_id", ""))}"',
        f'data-cache-key="{esc(manifest.get("cache_key", ""))}"',
        f'data-finding-rows="{esc(summary.get("finding_rows", ""))}"',
        f'data-baseline-supplied="{esc(baseline_summary.get("baseline_supplied", ""))}"',
        f'data-new-findings="{esc(baseline_summary.get("new_findings", ""))}"',
        f'data-changed-findings="{esc(baseline_summary.get("changed_findings", ""))}"',
        f'data-resolved-findings="{esc(baseline_summary.get("resolved_findings", ""))}"',
        f'data-unchanged-findings="{esc(baseline_summary.get("unchanged_findings", ""))}"',
        'data-release-ready="0"',
        'data-public-comparison-claim-ready="0"',
        'data-real-model-execution-ready="0"',
        'data-design-partner-beta-candidate-ready="0"',
        f"<code>{esc(manifest.get('run_id', ''))}</code>",
        f"<code>{esc(manifest.get('cache_key', ''))}</code>",
        "release_ready=0",
        "public_comparison_claim_ready=0",
        "real_model_execution_ready=0",
        "automatic_accuracy_claimed=0",
        "design_partner_beta_candidate_ready=0",
    ]
    for token in expected_tokens:
        if token not in dashboard:
            add(errors, "AUDIT_DASHBOARD.html run/boundary metadata drift")
            break
    for key, value in {**expected_diff_counts, **expected_review_counts}.items():
        if f"<th>{esc(key)}</th><td>{esc(value)}</td>" not in dashboard:
            add(errors, f"AUDIT_DASHBOARD.html metric drift: {key}")
    for row in expected_top_findings:
        finding_id = row.get("finding_id", "")
        expected_cells = [
            f'data-finding-id="{esc(finding_id)}"',
            f'data-plugin-id="{esc(row.get("plugin_id", ""))}"',
            f'data-abstain="{esc(row.get("abstain", ""))}"',
            f'data-suppressed="{esc(row.get("suppressed", ""))}"',
            f"<td>{esc(finding_id)}</td>",
            f"<td>{esc(row.get('plugin_id', ''))}</td>",
            f"<td>{esc(row.get('severity', ''))}</td>",
            f"<td>{esc(row.get('confidence', ''))}</td>",
            f"<td>{esc(row.get('primary_citation', ''))}</td>",
            f"<td>{esc(row.get('answer_preview', ''))}</td>",
        ]
        if not all(cell in dashboard for cell in expected_cells):
            add(errors, f"AUDIT_DASHBOARD.html finding row drift: {finding_id}")


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
    plugin_rules_by_plugin: dict[str, dict[str, dict[str, str]]] = {}
    for rule in read_csv(out_dir / "plugin_rule_rows.csv"):
        plugin_rules_by_plugin.setdefault(rule.get("plugin_id", ""), {})[rule.get("rule_id", "")] = rule
    findings = read_csv(out_dir / "audit_findings.csv")
    resource = read_json(out_dir / "resource_envelope.json")
    expected_plugin_ids = set(str(resource.get("active_plugin_ids", "")).split("|"))
    summary = read_json(out_dir / "audit_summary.json")
    if str(summary.get("question_supplied")) != "1":
        expected_plugin_ids.discard("user_question")
    else:
        expected_plugin_ids.add("user_question")
    expected_plugin_ids.discard("")
    finding_plugin_ids = [row.get("plugin_id", "") for row in findings]
    if set(finding_plugin_ids) != expected_plugin_ids:
        add(errors, "audit findings must contain exactly the expected required plugin rows")
    finding_signatures = [
        (
            row.get("plugin_id", ""),
            row.get("plugin_rule_ids", ""),
            row.get("citations", ""),
        )
        for row in findings
    ]
    if len(finding_signatures) != len(set(finding_signatures)):
        add(errors, "audit findings must not contain duplicate plugin/rule/citation rows")
    for row in findings:
        finding_id = row.get("finding_id", "")
        plugin_id = row.get("plugin_id", "")
        plugin = registry_by_plugin.get(plugin_id)
        if plugin is None:
            add(errors, f"audit finding references unregistered plugin: {finding_id} {plugin_id}")
            continue
        rule_ids = [cell for cell in row.get("plugin_rule_ids", "").split("|") if cell]
        if not rule_ids:
            add(errors, f"audit finding missing plugin rule provenance: {finding_id}")
        if len(rule_ids) != len(set(rule_ids)):
            add(errors, f"audit finding has duplicate plugin rule provenance: {finding_id}")
        if row.get("confidence") not in {"low", "medium", "high"}:
            add(errors, f"audit finding confidence is unsupported: {finding_id}")
        if row.get("suppressed") not in {"0", "1"}:
            add(errors, f"audit finding suppressed flag must be binary: {finding_id}")
        if row.get("suppressed") == "1" and not row.get("suppression_ids"):
            add(errors, f"suppressed finding must bind suppression ids: {finding_id}")
        if row.get("suppressed") == "0" and row.get("suppression_ids"):
            add(errors, f"unsuppressed finding must not bind suppression ids: {finding_id}")
        plugin_rule_rows = plugin_rules_by_plugin.get(plugin_id, {})
        unknown_rule_ids = sorted(set(rule_ids) - set(plugin_rule_rows))
        if unknown_rule_ids:
            add(errors, f"audit finding references unknown plugin rules: {finding_id} {','.join(unknown_rule_ids)}")
        if row.get("audit_type") != str(plugin.get("audit_type", "")):
            add(errors, f"audit finding audit_type does not match plugin registry: {finding_id}")
        plugin_language = str(plugin.get("language", ""))
        finding_language = row.get("language", "")
        if plugin_language == "multi":
            rule_languages = {
                str(plugin_rule_rows[rule_id].get("language", ""))
                for rule_id in rule_ids
                if rule_id in plugin_rule_rows
            }
            if finding_language != "multi" and finding_language not in rule_languages:
                add(errors, f"audit finding language does not match referenced plugin rules: {finding_id}")
        elif finding_language != plugin_language:
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
                    "confidence": str(rule.confidence),
                    "parser_id": str(rule.parser_id),
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
    expected_columns = ["plugin_id", "audit_type", "rule_id", "language", "file_suffixes", "pattern_label", "evidence_policy", "confidence", "parser_id"]
    with (out_dir / "plugin_rule_rows.csv").open(newline="", encoding="utf-8") as handle:
        columns = list(csv.DictReader(handle).fieldnames or [])
    if columns != expected_columns:
        add(errors, "plugin_rule_rows.csv columns drifted")
    rule_ids: set[str] = set()
    deprecated_languages: set[str] = set()
    deprecated_parser_ids: set[str] = set()
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
        if row.get("confidence") not in {"low", "medium", "high"}:
            add(errors, f"plugin rule confidence is unsupported: {rule_id}")
        if not row.get("file_suffixes") or not row.get("pattern_label") or not row.get("parser_id"):
            add(errors, f"plugin rule missing replay metadata: {rule_id}")
        if plugin_id == "deprecated_api":
            deprecated_languages.add(row.get("language", ""))
            deprecated_parser_ids.add(row.get("parser_id", ""))
            if row.get("evidence_policy") != "source-bound-span":
                add(errors, f"deprecated_api rule must be source-bound: {rule_id}")
    missing_rule_plugins = set(registry_by_plugin) - plugin_ids_with_rules
    if missing_rule_plugins:
        add(errors, f"plugin rule rows missing registered plugins: {','.join(sorted(missing_rule_plugins))}")
    if not {"python", "cpp", "javascript"}.issubset(deprecated_languages):
        add(errors, "deprecated_api plugin rules must cover python, cpp, and javascript")
    required_deprecated_parsers = {
        "python_ast",
        "cpp_lexical_code_candidate_parser",
        "javascript_typescript_lexical_code_candidate_parser",
    }
    if not required_deprecated_parsers.issubset(deprecated_parser_ids):
        add(errors, "deprecated_api plugin rules must bind python/js-ts/cpp parser provenance")


def verify_contract(out_dir: Path, sha_entries: dict[str, str], errors: list[str]) -> None:
    if csv_fieldnames(out_dir / "artifact_contract_rows.csv") != EXPECTED_ARTIFACT_CONTRACT_FIELDS:
        add(errors, "artifact_contract_rows.csv header drift")
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
        expected_kind = EXPECTED_ARTIFACT_KINDS.get(rel)
        kind = row.get("artifact_kind")
        if expected_kind is None:
            add(errors, f"artifact contract missing verifier kind expectation: {rel}")
        elif kind != expected_kind:
            add(errors, f"artifact contract kind drift: {rel}")
            kind = expected_kind
        min_rows = int(row.get("min_rows") or 0)
        if kind == "csv":
            with artifact.open(newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                rows = list(reader)
                columns = list(reader.fieldnames or [])
            expected_columns = row.get("required_columns", "").split("|") if row.get("required_columns") else []
            verifier_columns = EXPECTED_CSV_CONTRACTS.get(rel)
            if verifier_columns is None:
                add(errors, f"csv contract missing verifier expectation: {rel}")
                verifier_columns = expected_columns
            if expected_columns != verifier_columns:
                add(errors, f"csv contract required columns drift: {rel}")
            if columns != verifier_columns or row.get("actual_columns", "").split("|") != verifier_columns:
                add(errors, f"csv contract columns mismatch: {rel}")
            if len(rows) != int(row.get("actual_rows") or -1) or len(rows) < min_rows:
                add(errors, f"csv contract row count mismatch: {rel}")
        elif kind == "jsonl":
            rows = read_jsonl(artifact)
            keys = sorted({key for payload in rows for key in payload})
            required_keys = sorted(row.get("required_keys", "").split("|")) if row.get("required_keys") else []
            actual_keys = sorted(row.get("actual_keys", "").split("|")) if row.get("actual_keys") else []
            verifier_keys = sorted(EXPECTED_JSONL_CONTRACTS.get(rel, []))
            if verifier_keys and required_keys != verifier_keys:
                add(errors, f"jsonl contract required keys drift: {rel}")
            if keys != actual_keys:
                add(errors, f"jsonl contract actual keys drift: {rel}")
            if verifier_keys and keys != verifier_keys:
                add(errors, f"jsonl contract keys mismatch: {rel}")
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
    standard_json = read_json(out_dir / "audit_findings.json")
    for key, expected in {
        "schema_version": "local_repo_audit_findings.v1",
        "tool_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }.items():
        if standard_json.get(key) != expected:
            add(errors, f"audit_findings.json metadata drift: {key}")
    finding_rows = standard_json.get("findings")
    if not isinstance(finding_rows, list):
        add(errors, "audit_findings.json findings must be an array")
        return
    json_rows = [{key: str(value) for key, value in row.items()} for row in finding_rows if isinstance(row, dict)]
    if len(json_rows) != len(finding_rows):
        add(errors, "audit_findings.json findings must contain only objects")
    if read_csv(out_dir / "audit_findings.csv") != json_rows:
        add(errors, "CSV/standard JSON drift: audit_findings.csv vs audit_findings.json")


def verify_sarif(out_dir: Path, errors: list[str]) -> None:
    sarif = read_json(out_dir / "audit_findings.sarif.json")
    if sarif.get("$schema") != "https://json.schemastore.org/sarif-2.1.0.json":
        add(errors, "SARIF schema URI drift")
    if sarif.get("version") != "2.1.0":
        add(errors, "SARIF version drift")
    runs = sarif.get("runs")
    if not isinstance(runs, list) or len(runs) != 1:
        add(errors, "SARIF must contain exactly one run")
        return
    run = runs[0]
    if not isinstance(run, dict):
        add(errors, "SARIF run must be an object")
        return
    properties = run.get("properties", {})
    expected_properties = {
        "schema_version": "local_repo_audit_sarif.v1",
        "claim_boundary": CLAIM_BOUNDARY,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    for key, expected in expected_properties.items():
        if properties.get(key) != expected:
            add(errors, f"SARIF run property drift: {key}")

    driver = run.get("tool", {}).get("driver", {})
    if driver.get("name") != "audit-my-repo":
        add(errors, "SARIF tool driver name drift")
    if driver.get("semanticVersion") != TOOL_VERSION:
        add(errors, "SARIF tool driver version drift")

    plugin_rules = read_csv(out_dir / "plugin_rule_rows.csv")
    expected_rule_ids = [row.get("rule_id", "") for row in plugin_rules]
    sarif_rules = driver.get("rules", [])
    if not isinstance(sarif_rules, list):
        add(errors, "SARIF rules must be a list")
        sarif_rules = []
    if [str(rule.get("id", "")) for rule in sarif_rules] != expected_rule_ids:
        add(errors, "SARIF rule ids must match plugin_rule_rows.csv")
    plugin_rules_by_id = {row.get("rule_id", ""): row for row in plugin_rules}
    for rule in sarif_rules:
        rule_id = str(rule.get("id", ""))
        plugin_rule = plugin_rules_by_id.get(rule_id)
        if plugin_rule is None:
            continue
        props = rule.get("properties", {})
        for key in ["plugin_id", "audit_type", "language", "file_suffixes", "evidence_policy", "confidence"]:
            if str(props.get(key, "")) != str(plugin_rule.get(key, "")):
                add(errors, f"SARIF rule property drift: {rule_id} {key}")

    findings = read_csv(out_dir / "audit_findings.csv")
    spans = read_csv(out_dir / "citation_spans.csv")
    spans_by_finding: dict[str, list[dict[str, str]]] = {}
    for span in spans:
        spans_by_finding.setdefault(span.get("finding_id", ""), []).append(span)
    results = run.get("results", [])
    if not isinstance(results, list):
        add(errors, "SARIF results must be a list")
        results = []
    result_by_finding = {
        str(result.get("properties", {}).get("finding_id", "")): result
        for result in results
        if isinstance(result, dict)
    }
    finding_ids = [row.get("finding_id", "") for row in findings]
    if list(result_by_finding) != finding_ids or len(result_by_finding) != len(results):
        add(errors, "SARIF results must contain exactly one result per audit finding in order")
    expected_levels = {"high": "error", "medium": "warning", "low": "note"}
    for idx, finding in enumerate(findings):
        finding_id = finding.get("finding_id", "")
        result = result_by_finding.get(finding_id)
        if not isinstance(result, dict):
            continue
        rule_ids = [cell for cell in finding.get("plugin_rule_ids", "").split("|") if cell]
        expected_rule_id = rule_ids[0] if rule_ids else f"{finding.get('plugin_id', '')}:unknown"
        if result.get("ruleId") != expected_rule_id:
            add(errors, f"SARIF ruleId drift: {finding_id}")
        if expected_rule_id in expected_rule_ids:
            expected_rule_index = expected_rule_ids.index(expected_rule_id)
        else:
            expected_rule_index = -1
            add(errors, f"SARIF finding references unknown rule id: {finding_id}")
        if "ruleIndex" in result and result.get("ruleIndex") != expected_rule_index:
            add(errors, f"SARIF ruleIndex drift: {finding_id}")
        if result.get("kind") != "review":
            add(errors, f"SARIF result kind drift: {finding_id}")
        if result.get("level") != expected_levels.get(finding.get("severity", ""), "note"):
            add(errors, f"SARIF level drift: {finding_id}")
        if result.get("message", {}).get("text") != finding.get("answer", ""):
            add(errors, f"SARIF message drift: {finding_id}")
        fingerprints = result.get("partialFingerprints", {})
        if fingerprints.get("auditFindingId") != finding_id:
            add(errors, f"SARIF fingerprint finding id drift: {finding_id}")
        props = result.get("properties", {})
        for key in ["audit_type", "plugin_id", "confidence", "language", "severity"]:
            if str(props.get(key, "")) != str(finding.get(key, "")):
                add(errors, f"SARIF finding property drift: {finding_id} {key}")
        for key in ["grounded", "abstain", "unsupported_claim", "suppressed"]:
            if str(props.get(key, "")) != str(finding.get(key, "")):
                add(errors, f"SARIF finding binary property drift: {finding_id} {key}")
        if props.get("plugin_rule_ids") != rule_ids:
            add(errors, f"SARIF finding rule id list drift: {finding_id}")
        expected_suppression_ids = [cell for cell in finding.get("suppression_ids", "").split("|") if cell]
        if props.get("suppression_ids") != expected_suppression_ids:
            add(errors, f"SARIF suppression id drift: {finding_id}")
        expected_sha_cells = [cell for cell in finding.get("citation_sha256s", "").split(";") if cell]
        if props.get("citation_sha256s") != expected_sha_cells:
            add(errors, f"SARIF citation sha list drift: {finding_id}")
        suppressions = result.get("suppressions", [])
        if finding.get("suppressed") == "1":
            if not suppressions:
                add(errors, f"SARIF suppressed finding missing suppressions: {finding_id}")
        elif suppressions:
            add(errors, f"SARIF unsuppressed finding has suppressions: {finding_id}")

        expected_spans = spans_by_finding.get(finding_id, [])
        locations = result.get("locations", [])
        if len(locations) != len(expected_spans):
            add(errors, f"SARIF location count drift: {finding_id}")
            continue
        if expected_spans and fingerprints.get("primaryLocationLineHash") != expected_spans[0].get("span_sha256"):
            add(errors, f"SARIF primary location fingerprint drift: {finding_id}")
        for location, span in zip(locations, expected_spans):
            physical = location.get("physicalLocation", {})
            artifact = physical.get("artifactLocation", {})
            region = physical.get("region", {})
            loc_props = physical.get("properties", {})
            if artifact.get("uri") != span.get("file_path"):
                add(errors, f"SARIF location URI drift: {finding_id}")
            if str(region.get("startLine")) != span.get("line_start") or str(region.get("endLine")) != span.get("line_end"):
                add(errors, f"SARIF location region drift: {finding_id}")
            for key in ["sha256", "span_sha256", "span_text_preview"]:
                if str(loc_props.get(key, "")) != str(span.get(key, "")):
                    add(errors, f"SARIF location property drift: {finding_id} {key}")


def finding_fingerprint(row: dict[str, str]) -> str:
    payload = {
        "plugin_id": row.get("plugin_id", ""),
        "plugin_rule_ids": row.get("plugin_rule_ids", ""),
        "language": row.get("language", ""),
        "citations": row.get("citations", ""),
    }
    return sha256_text(json.dumps(payload, sort_keys=True))


def finding_content_sha(row: dict[str, str]) -> str:
    payload = {
        "answer": row.get("answer", ""),
        "confidence": row.get("confidence", ""),
        "severity": row.get("severity", ""),
        "grounded": row.get("grounded", ""),
        "abstain": row.get("abstain", ""),
        "unsupported_claim": row.get("unsupported_claim", ""),
        "suppressed": row.get("suppressed", ""),
        "suppression_ids": row.get("suppression_ids", ""),
        "citation_sha256s": row.get("citation_sha256s", ""),
    }
    return sha256_text(json.dumps(payload, sort_keys=True))


def verify_baseline_diff(out_dir: Path, manifest: dict, errors: list[str]) -> None:
    rows = read_csv(out_dir / "baseline_diff_rows.csv")
    summary = read_json(out_dir / "baseline_diff_summary.json")
    expected_keys = {
        "schema_version",
        "tool_version",
        "baseline_supplied",
        "baseline_output",
        "baseline_output_sha256",
        "baseline_manifest_sha256",
        "baseline_cache_key",
        "current_finding_rows",
        "baseline_finding_rows",
        "diff_rows",
        "not_compared_findings",
        "new_findings",
        "changed_findings",
        "resolved_findings",
        "unchanged_findings",
        "manual_review_required_rows",
        "release_ready",
        "public_comparison_claim_ready",
        "real_model_execution_ready",
    }
    if set(summary) != expected_keys:
        add(errors, "baseline_diff_summary.json keys drifted")
    for key, expected in {
        "schema_version": "local_repo_audit_baseline_diff.v1",
        "tool_version": TOOL_VERSION,
        "baseline_output": str(manifest.get("baseline_output", "")),
        "baseline_output_sha256": str(manifest.get("baseline_output_sha256", "")),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }.items():
        if summary.get(key) != expected:
            add(errors, f"baseline_diff_summary.{key} mismatch")

    current_findings = read_csv(out_dir / "audit_findings.csv")
    current_by_fingerprint = {finding_fingerprint(row): row for row in current_findings}
    if len(current_by_fingerprint) != len(current_findings):
        add(errors, "baseline diff current finding fingerprints must be unique")
    baseline_output = str(manifest.get("baseline_output", ""))
    baseline_findings: list[dict[str, str]] = []
    baseline_manifest: dict = {}
    if baseline_output:
        baseline_path = Path(baseline_output)
        if baseline_path.is_dir():
            baseline_findings = read_csv(baseline_path / "audit_findings.csv")
            baseline_manifest = read_json(baseline_path / "audit_manifest.json")
            if summary.get("baseline_manifest_sha256") != sha256_prefixed(baseline_path / "audit_manifest.json"):
                add(errors, "baseline_diff_summary baseline_manifest_sha256 mismatch")
            if summary.get("baseline_cache_key") != str(baseline_manifest.get("cache_key", "")):
                add(errors, "baseline_diff_summary baseline_cache_key mismatch")
        if summary.get("baseline_supplied") != 1:
            add(errors, "baseline diff summary must record supplied baseline")
    else:
        if summary.get("baseline_supplied") != 0:
            add(errors, "baseline diff summary must record missing baseline")
        if summary.get("baseline_manifest_sha256") != sha256_text("") or summary.get("baseline_cache_key") != "":
            add(errors, "missing baseline must bind empty manifest/cache fields")

    baseline_by_fingerprint = {finding_fingerprint(row): row for row in baseline_findings}
    if len(baseline_by_fingerprint) != len(baseline_findings):
        add(errors, "baseline diff baseline finding fingerprints must be unique")
    expected_rows: list[dict[str, str]] = []
    if not baseline_output:
        for fingerprint, current in sorted(current_by_fingerprint.items()):
            expected_rows.append(
                {
                    "diff_status": "not_compared",
                    "finding_fingerprint": fingerprint,
                    "content_sha256": finding_content_sha(current),
                    "baseline_content_sha256": "",
                    "current_finding_id": current.get("finding_id", ""),
                    "baseline_finding_id": "",
                    "plugin_id": current.get("plugin_id", ""),
                    "plugin_rule_ids": current.get("plugin_rule_ids", ""),
                    "confidence": current.get("confidence", ""),
                    "severity": current.get("severity", ""),
                    "language": current.get("language", ""),
                    "current_citations": current.get("citations", ""),
                    "baseline_citations": "",
                    "current_citation_sha256s": current.get("citation_sha256s", ""),
                    "baseline_citation_sha256s": "",
                    "current_suppressed": current.get("suppressed", ""),
                    "baseline_suppressed": "",
                    "manual_review_required": "1",
                }
            )
    else:
        for fingerprint in sorted(set(current_by_fingerprint) | set(baseline_by_fingerprint)):
            current = current_by_fingerprint.get(fingerprint)
            previous = baseline_by_fingerprint.get(fingerprint)
            if current is None:
                source = previous or {}
                status = "resolved"
            elif previous is None:
                source = current
                status = "new"
            elif finding_content_sha(current) == finding_content_sha(previous):
                source = current
                status = "unchanged"
            else:
                source = current
                status = "changed"
            expected_rows.append(
                {
                    "diff_status": status,
                    "finding_fingerprint": fingerprint,
                    "content_sha256": "" if current is None else finding_content_sha(current),
                    "baseline_content_sha256": "" if previous is None else finding_content_sha(previous),
                    "current_finding_id": "" if current is None else current.get("finding_id", ""),
                    "baseline_finding_id": "" if previous is None else previous.get("finding_id", ""),
                    "plugin_id": source.get("plugin_id", ""),
                    "plugin_rule_ids": source.get("plugin_rule_ids", ""),
                    "confidence": source.get("confidence", ""),
                    "severity": source.get("severity", ""),
                    "language": source.get("language", ""),
                    "current_citations": "" if current is None else current.get("citations", ""),
                    "baseline_citations": "" if previous is None else previous.get("citations", ""),
                    "current_citation_sha256s": "" if current is None else current.get("citation_sha256s", ""),
                    "baseline_citation_sha256s": "" if previous is None else previous.get("citation_sha256s", ""),
                    "current_suppressed": "" if current is None else current.get("suppressed", ""),
                    "baseline_suppressed": "" if previous is None else previous.get("suppressed", ""),
                    "manual_review_required": "0" if status == "unchanged" else "1",
                }
            )
    if rows != expected_rows:
        add(errors, "baseline_diff_rows.csv does not match current/baseline finding fingerprints")
    counts = {status: sum(1 for row in rows if row.get("diff_status") == status) for status in ["not_compared", "new", "changed", "resolved", "unchanged"]}
    expected_summary_counts = {
        "current_finding_rows": len(current_findings),
        "baseline_finding_rows": len(baseline_findings),
        "diff_rows": len(rows),
        "not_compared_findings": counts["not_compared"],
        "new_findings": counts["new"],
        "changed_findings": counts["changed"],
        "resolved_findings": counts["resolved"],
        "unchanged_findings": counts["unchanged"],
        "manual_review_required_rows": sum(1 for row in rows if row.get("manual_review_required") == "1"),
    }
    for key, expected in expected_summary_counts.items():
        if str(summary.get(key)) != str(expected):
            add(errors, f"baseline diff summary count drift: {key}")
    dashboard = (out_dir / "BASELINE_DIFF.md").read_text(encoding="utf-8")
    for key in [
        "baseline_supplied",
        "current_finding_rows",
        "baseline_finding_rows",
        "not_compared_findings",
        "new_findings",
        "changed_findings",
        "resolved_findings",
        "unchanged_findings",
        "manual_review_required_rows",
    ]:
        if f"- {key}={summary.get(key)}" not in dashboard:
            add(errors, f"BASELINE_DIFF.md summary drift: {key}")
    for snippet in ["release readiness", "public comparison readiness", "real model execution"]:
        if snippet not in dashboard:
            add(errors, "BASELINE_DIFF.md must preserve readiness boundary")


SEMANTIC_SUMMARY_ARTIFACTS = [
    "source_manifest.csv",
    "audit_findings.csv",
    "citation_spans.csv",
    "abstain_rows.csv",
    "unsupported_claim_rows.csv",
    "baseline_diff_rows.csv",
    "manual_review_queue.csv",
]


def audit_semantic_result_sha(out_dir: Path, artifacts: list[str]) -> str:
    digest = hashlib.sha256()
    for rel in artifacts:
        path = out_dir / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256_prefixed(path).encode("utf-8") if path.is_file() else b"missing")
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def verify_audit_semantic_summary(out_dir: Path, errors: list[str]) -> None:
    payload = read_json(out_dir / "audit_semantic_summary.json")
    if payload.get("schema_version") != "local_repo_audit_semantic_summary.v1":
        add(errors, "audit_semantic_summary.json schema_version drifted")
    if payload.get("tool_version") != TOOL_VERSION:
        add(errors, "audit_semantic_summary.json tool_version drifted")
    if payload.get("claim_boundary") != CLAIM_BOUNDARY:
        add(errors, "audit_semantic_summary.json claim boundary drifted")
    for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready"]:
        if payload.get(key) != 0:
            add(errors, f"audit_semantic_summary.json must keep {key}=0")
    artifacts = payload.get("semantic_artifacts", [])
    if artifacts != SEMANTIC_SUMMARY_ARTIFACTS:
        add(errors, "audit_semantic_summary.json semantic_artifacts drifted")
        artifacts = SEMANTIC_SUMMARY_ARTIFACTS
    artifact_sha256s = payload.get("artifact_sha256s", {})
    if not isinstance(artifact_sha256s, dict):
        add(errors, "audit_semantic_summary.json artifact_sha256s must be an object")
        artifact_sha256s = {}
    expected_sha256s = {rel: sha256_prefixed(out_dir / rel) for rel in artifacts}
    if artifact_sha256s != expected_sha256s:
        add(errors, "audit_semantic_summary.json artifact sha256 drift")
    if payload.get("semantic_result_sha256") != audit_semantic_result_sha(out_dir, artifacts):
        add(errors, "audit_semantic_summary.json semantic_result_sha256 drift")


def relative_source_path(rel: str, errors: list[str], label: str) -> Path | None:
    path = Path(rel)
    if not rel or path.is_absolute() or ".." in path.parts:
        add(errors, f"{label} path escapes target repo: {rel}")
        return None
    return path


def verify_sources(out_dir: Path, manifest: dict, errors: list[str], *, live_source_check: bool = True) -> dict[str, dict[str, str]]:
    rows = read_csv(out_dir / "source_manifest.csv")
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    by_path: dict[str, dict[str, str]] = {}
    source_ids: set[str] = set()
    if live_source_check and not target.is_dir():
        add(errors, "target_repo directory is missing")
    for idx, row in enumerate(rows, start=1):
        source_id = row.get("source_id", "")
        rel = row.get("file_path", "")
        rel_path = relative_source_path(rel, errors, "source_manifest")
        expected_source_id = f"src_{idx:04d}"
        if source_id != expected_source_id:
            add(errors, f"source_manifest source_id must bind row order: {rel}")
        if source_id in source_ids:
            add(errors, f"duplicate source_id in source_manifest.csv: {source_id}")
        source_ids.add(source_id)
        if rel in by_path:
            add(errors, f"duplicate file_path in source_manifest.csv: {rel}")
        by_path[rel] = row
        if rel_path is None:
            continue
        if row.get("route_memory_source") != "1":
            add(errors, f"source_manifest route_memory_source must be 1: {rel}")
        if not live_source_check:
            continue
        source = target / rel_path
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


def verify_source_snapshot(
    out_dir: Path,
    manifest: dict,
    source_by_path: dict[str, dict[str, str]],
    errors: list[str],
    *,
    live_source_check: bool = True,
) -> None:
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
    if not live_source_check:
        return
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


def verify_citations(
    out_dir: Path,
    manifest: dict,
    summary: dict[str, str],
    source_by_path: dict[str, dict[str, str]],
    errors: list[str],
    *,
    live_source_check: bool = True,
) -> None:
    target = Path(str(manifest.get("target_repo", ""))).resolve()
    findings = {row["finding_id"]: row for row in read_csv(out_dir / "audit_findings.csv")}
    citation_cells: dict[tuple[str, str], dict[str, str]] = {}
    citation_ids: set[str] = set()
    referenced_span_cells: set[tuple[str, str]] = set()
    citation_rows = read_csv(out_dir / "citation_spans.csv")
    if str(len(citation_rows)) != str(summary.get("citation_span_rows")):
        add(errors, "citation span row count drift")
    for row in citation_rows:
        rel = row.get("file_path", "")
        rel_path = relative_source_path(rel, errors, "citation")
        finding_id = row.get("finding_id", "")
        citation_id = row.get("citation_id", "")
        line_start = int(row.get("line_start") or 0)
        line_end = int(row.get("line_end") or 0)
        if citation_id in citation_ids:
            add(errors, f"duplicate citation_id in citation_spans.csv: {citation_id}")
        citation_ids.add(citation_id)
        if finding_id not in findings:
            add(errors, f"citation span references unknown finding: {finding_id}")
        if rel not in source_by_path:
            add(errors, f"citation outside source_manifest.csv: {rel}")
            continue
        if rel_path is None:
            continue
        if row.get("sha256") != source_by_path[rel].get("sha256"):
            add(errors, f"citation sha mismatch: {rel}")
        if line_start < 1 or line_end < line_start:
            add(errors, f"citation line bounds invalid: {rel}:{line_start}")
            continue
        if line_end != line_start:
            add(errors, f"citation span must remain single-line: {rel}:{line_start}-{line_end}")
        if not live_source_check:
            cell_key = (finding_id, f"{rel}:{line_start}")
            if cell_key in citation_cells:
                add(errors, f"duplicate citation cell in citation_spans.csv: {finding_id} {rel}:{line_start}")
            citation_cells[cell_key] = row
            continue
        source = target / rel_path
        if row.get("sha256") != sha256_prefixed(source):
            add(errors, f"citation sha mismatch: {rel}")
            continue
        lines = source.read_text(encoding="utf-8", errors="replace").splitlines()
        if line_end > len(lines):
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
            referenced_span_cells.add((finding_id, cell))
            span = citation_cells.get((finding_id, cell))
            if span is None:
                add(errors, f"finding citation has no matching span row: {finding_id} {cell}")
                continue
            expected_citation_id = f"{finding_id}_cite_{idx + 1}"
            if span.get("citation_id") != expected_citation_id:
                add(errors, f"citation id must bind finding citation order: {finding_id} {cell}")
            if idx >= len(sha_cells):
                continue
            if sha_cells[idx] != span.get("sha256"):
                add(errors, f"finding citation sha256 drift: {finding_id} {cell}")
    orphan_span_cells = sorted(set(citation_cells) - referenced_span_cells)
    if orphan_span_cells:
        finding_id, cell = orphan_span_cells[0]
        add(errors, f"citation span is not referenced by audit_findings.csv: {finding_id} {cell}")


def verify_cache_key(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    source_rows = read_csv(out_dir / "source_manifest.csv")
    source_snapshot = read_json(out_dir / "source_snapshot.json")
    invocation = read_json(out_dir / "audit_invocation.json")
    resource = read_json(out_dir / "resource_envelope.json")
    questions = {row.get("question", "") for row in read_csv(out_dir / "audit_findings.csv") if row.get("audit_type") == "user_question"}
    question = sorted(questions)[0] if summary.get("question_supplied") == "1" and questions else ""
    payload = {
        "tool_version": TOOL_VERSION,
        "tool_source_sha256": manifest.get("tool_source_sha256"),
        "verifier_source_sha256": sha256_prefixed(repo_root / "tools" / "verify_local_audit.py"),
        "schema_sha256s": schema_sha256s(repo_root),
        "target": manifest.get("target_repo"),
        "source": [(row["file_path"], row["sha256"]) for row in source_rows],
        "source_snapshot": source_snapshot,
        "source_scope": manifest.get("source_scope"),
        "changed_files_from": manifest.get("changed_files_from"),
        "changed_files_from_sha256": manifest.get("changed_files_from_sha256"),
        "changed_file_rows": manifest.get("changed_file_rows"),
        "mode": summary.get("mode"),
        "max_queries": int(resource.get("max_queries")),
        "max_files": int(resource.get("max_files")),
        "max_total_bytes": int(resource.get("max_total_bytes")),
        "max_file_bytes": int(resource.get("max_file_bytes")),
        "max_findings": int(resource.get("max_findings")),
        "active_plugin_ids": str(resource.get("active_plugin_ids")).split("|"),
        "suppression_file_sha256": manifest.get("suppression_file_sha256"),
        "baseline_output": manifest.get("baseline_output"),
        "baseline_output_sha256": manifest.get("baseline_output_sha256"),
        "namespace": manifest.get("namespace"),
        "real_benchmark_namespace_confirmed": manifest.get("real_benchmark_namespace_confirmed"),
        "question": question,
        "verify_output_requested": int(invocation.get("verify_output_requested", -1)),
        "emit_report_requested": int(invocation.get("emit_report_requested", -1)),
        "emit_lineage_requested": int(invocation.get("emit_lineage_requested", -1)),
        "emit_reproduce_requested": int(invocation.get("emit_reproduce_requested", -1)),
        "emit_diagnostics_requested": int(invocation.get("emit_diagnostics_requested", -1)),
        "plugin_registry_sha256": manifest.get("plugin_registry_sha256"),
    }
    expected = hashlib.sha256(json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()
    if manifest.get("cache_key") != expected:
        add(errors, "cache key mismatch")


def verify_reproduce(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    repo_root = Path(__file__).resolve().parents[1]
    publish_root = publish_root_for(out_dir, manifest)
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
        "--max-files",
        str(resource.get("max_files")),
        "--max-total-bytes",
        str(resource.get("max_total_bytes")),
        "--max-file-bytes",
        str(resource.get("max_file_bytes")),
        "--max-findings",
        str(resource.get("max_findings")),
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
        "--max-files": str(resource.get("max_files")),
        "--max-total-bytes": str(resource.get("max_total_bytes")),
        "--max-file-bytes": str(resource.get("max_file_bytes")),
        "--max-findings": str(resource.get("max_findings")),
        "--out": str(publish_root),
        "--generator": str(summary.get("generator")),
        "--namespace": str(manifest.get("namespace")),
    }
    for flag, expected in expected_flag_values.items():
        if flag_values.get(flag) != expected:
            add(errors, f"reproduce.sh {flag} value drift")
    invocation = read_json(out_dir / "audit_invocation.json")
    suppression_file = str(invocation.get("suppression_file", ""))
    if suppression_file:
        if flag_values.get("--allowlist") != suppression_file:
            add(errors, "reproduce.sh allowlist value drift")
    elif "--allowlist" in parts or "--suppression-file" in parts:
        add(errors, "reproduce.sh must not include empty allowlist flags")
    baseline_output = str(invocation.get("baseline_output", ""))
    if baseline_output:
        if flag_values.get("--baseline") != baseline_output:
            add(errors, "reproduce.sh baseline value drift")
    elif "--baseline" in parts:
        add(errors, "reproduce.sh must not include empty baseline flags")
    changed_files_from = str(invocation.get("changed_files_from", ""))
    if changed_files_from:
        if flag_values.get("--changed-files-from") != changed_files_from:
            add(errors, "reproduce.sh changed-files value drift")
    elif "--changed-files-from" in parts:
        add(errors, "reproduce.sh must not include empty changed-files flags")
    if manifest.get("namespace") == "real_benchmark" and "--confirm-real-benchmark-namespace" not in parts:
        add(errors, "real_benchmark reproduce command must include confirmation flag")
    if summary.get("question_supplied") == "1":
        questions = [row.get("question", "") for row in read_csv(out_dir / "audit_findings.csv") if row.get("audit_type") == "user_question"]
        expected_question = questions[0] if len(questions) == 1 else ""
        if flag_values.get("--question") != expected_question:
            add(errors, "reproduce.sh question value drift")
    diagnostics_requested = int(invocation.get("emit_diagnostics_requested", 0))
    if diagnostics_requested == 1:
        if "--emit-diagnostics" not in parts:
            add(errors, "reproduce.sh must include --emit-diagnostics when diagnostics were requested")
    else:
        if "--emit-diagnostics" in parts:
            add(errors, "reproduce.sh must not include --emit-diagnostics in default opt-out mode")

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
        str(publish_root),
    ]
    if verify_parts != expected_verify_parts:
        add(errors, "verify.sh command drift")


def load_suppression_rules_for_verifier(out_dir: Path, errors: list[str]) -> dict[str, dict[str, str]]:
    invocation = read_json(out_dir / "audit_invocation.json")
    suppression_file = str(invocation.get("suppression_file", ""))
    if not suppression_file:
        return {}
    path = Path(suppression_file)
    if is_forbidden_env_path(path):
        add(errors, "audit_invocation suppression_file must not be .env-like")
        return {}
    if not path.is_file():
        add(errors, "audit_invocation suppression_file is missing")
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        add(errors, "audit_invocation suppression_file must be readable JSON")
        return {}
    rows = payload.get("suppressions", payload) if isinstance(payload, dict) else payload
    if not isinstance(rows, list):
        add(errors, "audit_invocation suppression_file must contain suppression rows")
        return {}
    rules: dict[str, dict[str, str]] = {}
    for idx, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            add(errors, "audit_invocation suppression_file rows must be objects")
            continue
        suppression_id = str(row.get("suppression_id") or f"suppression_{idx:04d}")
        if suppression_id in rules:
            add(errors, f"audit_invocation suppression_file duplicate suppression_id: {suppression_id}")
            continue
        rules[suppression_id] = {
            "plugin_id": str(row.get("plugin_id") or ""),
            "rule_id": str(row.get("rule_id") or ""),
            "file_path": str(row.get("file_path") or ""),
            "reason": str(row.get("reason") or "").strip(),
            "active": "1" if bool(row.get("active", True)) else "0",
        }
    return rules


def verify_manual_rows(out_dir: Path, summary: dict[str, str], errors: list[str]) -> None:
    findings = read_csv(out_dir / "audit_findings.csv")
    finding_by_id = {row.get("finding_id", ""): row for row in findings}
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
    suppressed_rows = read_csv(out_dir / "suppressed_findings.csv")
    suppression_rules = load_suppression_rules_for_verifier(out_dir, errors)
    if suppressed_rows and not suppression_rules:
        add(errors, "suppressed_findings.csv rows require a bound suppression file")
    spans_by_finding: dict[str, list[dict[str, str]]] = {}
    for span in read_csv(out_dir / "citation_spans.csv"):
        spans_by_finding.setdefault(span.get("finding_id", ""), []).append(span)
    suppressed_finding_by_pair: dict[tuple[str, str], dict[str, str]] = {}
    for finding in findings:
        finding_id = finding.get("finding_id", "")
        if finding.get("suppressed") != "1":
            continue
        for suppression_id in finding.get("suppression_ids", "").split("|"):
            if not suppression_id:
                continue
            pair = (suppression_id, finding_id)
            if pair in suppressed_finding_by_pair:
                add(errors, f"suppression id/finding pair must be unique: {suppression_id} {finding_id}")
            else:
                suppressed_finding_by_pair[pair] = finding
    suppressed_pairs_from_findings = {
        (suppression_id, row.get("finding_id", ""))
        for row in findings
        if row.get("suppressed") == "1"
        for suppression_id in row.get("suppression_ids", "").split("|")
        if suppression_id
    }
    suppressed_pairs_from_rows = {(row.get("suppression_id", ""), row.get("finding_id", "")) for row in suppressed_rows}
    if len(suppressed_pairs_from_rows) != len(suppressed_rows) or ("", "") in suppressed_pairs_from_rows:
        add(errors, "suppressed_findings.csv must contain unique suppression id/finding pairs")
    if suppressed_pairs_from_rows != suppressed_pairs_from_findings:
        add(errors, "suppressed_findings.csv must exactly match suppressed finding applications")
    if str(len(suppressed_rows)) != summary.get("suppression_rows"):
        add(errors, "suppression row count drift")
    for row in suppressed_rows:
        if row.get("active") != "1":
            add(errors, "suppressed_findings.csv rows must represent active suppressions")
        if not row.get("reason"):
            add(errors, "suppressed_findings.csv rows must include a reason")
        if row.get("plugin_id") not in EXPECTED_PLUGIN_IDS:
            add(errors, "suppressed_findings.csv plugin_id must be registered")
        finding_id = row.get("finding_id", "")
        finding = suppressed_finding_by_pair.get((row.get("suppression_id", ""), finding_id))
        if finding is None:
            continue
        suppression_id = row.get("suppression_id", "")
        rule = suppression_rules.get(suppression_id)
        if rule is None:
            add(errors, f"suppressed_findings.csv suppression_id must exist in suppression file: {suppression_id}")
        else:
            if rule.get("active") != "1":
                add(errors, f"suppressed_findings.csv suppression_id must bind active suppression rule: {suppression_id}")
            if row.get("reason", "") != rule.get("reason", ""):
                add(errors, f"suppressed_findings.csv reason must bind suppression file: {suppression_id}")
            if rule.get("plugin_id") and rule.get("plugin_id") != finding.get("plugin_id", ""):
                add(errors, f"suppressed_findings.csv plugin_id must satisfy suppression file: {suppression_id}")
            finding_rule_ids = [cell for cell in finding.get("plugin_rule_ids", "").split("|") if cell]
            if rule.get("rule_id") and rule.get("rule_id") not in finding_rule_ids:
                add(errors, f"suppressed_findings.csv rule_id must satisfy suppression file: {suppression_id}")
            finding_citation_paths = {
                cell.rsplit(":", 1)[0]
                for cell in finding.get("citations", "").split(";")
                if ":" in cell
            }
            if rule.get("file_path") and rule.get("file_path") not in finding_citation_paths:
                add(errors, f"suppressed_findings.csv file_path must satisfy suppression file: {suppression_id}")
        for key in ["plugin_id", "plugin_rule_ids", "confidence", "language", "audit_type", "severity"]:
            if row.get(key, "") != finding.get(key, ""):
                add(errors, f"suppressed_findings.csv {key} must bind suppressed finding: {suppression_id}")
        if row.get("citations", "") != finding.get("citations", ""):
            add(errors, f"suppressed_findings.csv citations must bind suppressed finding: {suppression_id}")
        if row.get("citation_sha256s", "") != finding.get("citation_sha256s", ""):
            add(errors, f"suppressed_findings.csv citation_sha256s must bind suppressed finding: {suppression_id}")
        expected_span_sha256s = ";".join(span.get("span_sha256", "") for span in spans_by_finding.get(finding_id, []))
        if row.get("citation_span_sha256s", "") != expected_span_sha256s:
            add(errors, f"suppressed_findings.csv citation_span_sha256s must bind suppressed finding spans: {suppression_id}")
        expected_evidence_paths = sorted(
            cell.rsplit(":", 1)[0]
            for cell in finding.get("citations", "").split(";")
            if ":" in cell
        )
        actual_evidence_paths = sorted(
            cell for cell in row.get("evidence_paths", "").split("|") if cell
        )
        if actual_evidence_paths != expected_evidence_paths:
            add(errors, f"suppressed_findings.csv evidence_paths must bind suppressed finding citations: {suppression_id}")

    guard_rows = read_csv(out_dir / "wrong_answer_guard_rows.csv")
    guard_by_finding = {row.get("finding_id", ""): row for row in guard_rows}
    if len(guard_by_finding) != len(guard_rows) or set(guard_by_finding) != finding_ids:
        add(errors, "wrong_answer_guard_rows.csv must contain exactly one row per finding")
    guard_ids = {row.get("guard_id", "") for row in guard_rows}
    if len(guard_ids) != len(guard_rows) or "" in guard_ids:
        add(errors, "wrong_answer_guard_rows.csv guard_id values must be unique and non-empty")
    if len([row for row in guard_rows if row.get("wrong_answer_guard_pass") == "1"]) != len(guard_rows):
        add(errors, "wrong answer guard rows are not all passing")
    if str(len(guard_rows)) != summary.get("wrong_answer_guard_rows"):
        add(errors, "wrong answer guard row count drift")
    guard_pass_rows = [row for row in guard_rows if row.get("wrong_answer_guard_pass") == "1"]
    if str(len(guard_pass_rows)) != summary.get("wrong_answer_guard_pass_rows"):
        add(errors, "wrong answer guard pass row count drift")
    for finding_id, row in guard_by_finding.items():
        finding = finding_by_id.get(finding_id, {})
        suffix = finding_id.removeprefix("finding_")
        if not suffix.isdigit():
            add(errors, f"wrong_answer_guard_rows.csv finding_id format drift: {finding_id}")
        else:
            expected_guard_id = f"wrong_answer_guard_{int(suffix):04d}"
            if row.get("guard_id") != expected_guard_id:
                add(errors, f"wrong_answer_guard_rows.csv guard_id must bind finding_id: {finding_id}")
        expected_blocked = "1" if finding.get("abstain") == "1" or finding.get("grounded") == "1" else "0"
        if row.get("unsupported_direct_answer_blocked") != expected_blocked:
            add(errors, f"wrong answer guard blocked flag drift: {finding_id}")
        if row.get("citation_required") != "1" or row.get("audit_trail_required") != "1":
            add(errors, f"wrong answer guard must require citation and audit trail: {finding_id}")
    latency_rows = read_csv(out_dir / "latency_rows.csv")
    latency_ids = {row.get("finding_id", "") for row in latency_rows}
    if len(latency_ids) != len(latency_rows) or latency_ids != finding_ids:
        add(errors, "latency_rows.csv must contain exactly one row per finding")
    expected_latency_ms = max(1, int(summary.get("plugin_latency_ms", "0")) // max(1, len(findings)))
    for row in latency_rows:
        if int(row.get("latency_ms", "0")) <= 0 or row.get("latency_source") != "measured-plugin-phase-share":
            add(errors, "latency rows must use positive measured plugin phase shares")
        if row.get("latency_ms") != str(expected_latency_ms):
            add(errors, f"latency rows must bind measured plugin phase share: {row.get('finding_id', '')}")
    accuracy_rows = read_csv(out_dir / "accuracy_rows.csv")
    accuracy_ids = {row.get("finding_id", "") for row in accuracy_rows}
    if len(accuracy_ids) != len(accuracy_rows) or accuracy_ids != finding_ids:
        add(errors, "accuracy_rows.csv must contain exactly one row per finding")
    if str(len(accuracy_rows)) != summary.get("accuracy_rows"):
        add(errors, "accuracy row count drift")
    for row in accuracy_rows:
        if row.get("accuracy_label") != "unreviewed":
            add(errors, "accuracy rows must not claim reviewed labels")
        if row.get("automatic_accuracy_claimed") != "0" or row.get("manual_accuracy_review_required") != "1":
            add(errors, "accuracy rows must remain manual/unreviewed")
    accuracy_payload = read_json(out_dir / "accuracy_rows.json")
    if accuracy_payload.get("schema_version") != "local_repo_audit_accuracy_rows.v1":
        add(errors, "accuracy_rows.json schema_version drifted")
    if accuracy_payload.get("tool_version") != TOOL_VERSION:
        add(errors, "accuracy_rows.json tool_version drifted")
    if accuracy_payload.get("claim_boundary") != CLAIM_BOUNDARY:
        add(errors, "accuracy_rows.json claim boundary drifted")
    for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready"]:
        if accuracy_payload.get(key) != 0:
            add(errors, f"accuracy_rows.json must keep {key}=0")
    if accuracy_payload.get("automatic_accuracy_claimed") != 0 or accuracy_payload.get("manual_accuracy_review_required") != 1:
        add(errors, "accuracy_rows.json must keep automatic accuracy blocked and manual review required")
    accuracy_json_rows = accuracy_payload.get("rows", [])
    if not isinstance(accuracy_json_rows, list):
        add(errors, "accuracy_rows.json rows must be a list")
        accuracy_json_rows = []
    normalized_accuracy_json_rows = [{key: str(value) for key, value in row.items()} for row in accuracy_json_rows if isinstance(row, dict)]
    if len(normalized_accuracy_json_rows) != len(accuracy_json_rows):
        add(errors, "accuracy_rows.json rows must all be objects")
    if accuracy_payload.get("accuracy_rows") != len(accuracy_rows):
        add(errors, "accuracy_rows.json row count drift")
    if normalized_accuracy_json_rows != accuracy_rows:
        add(errors, "accuracy_rows.json must match accuracy_rows.csv")
    citation_rows = read_csv(out_dir / "citation_correctness_rows.csv")
    citation_ids = {row.get("finding_id", "") for row in citation_rows}
    if len(citation_ids) != len(citation_rows) or citation_ids != finding_ids:
        add(errors, "citation_correctness_rows.csv must contain exactly one row per finding")
    if str(len(citation_rows)) != summary.get("citation_correctness_rows"):
        add(errors, "citation correctness row count drift")
    for row in citation_rows:
        finding_id = row.get("finding_id", "")
        finding = finding_by_id.get(finding_id, {})
        citation_count = len([cell for cell in finding.get("citations", "").split(";") if cell])
        expected_bound = "1" if citation_count > 0 else "0"
        if row.get("citation_count") != str(citation_count) or row.get("citation_bound") != expected_bound:
            add(errors, f"citation correctness rows must bind finding citations: {finding_id}")
        if row.get("citation_correctness_label") != "source_bound_unreviewed" or row.get("manual_citation_review_required") != "1":
            add(errors, "citation correctness rows must remain source-bound unreviewed")
    citation_payload = read_json(out_dir / "citation_correctness_rows.json")
    if citation_payload.get("schema_version") != "local_repo_audit_citation_correctness_rows.v1":
        add(errors, "citation_correctness_rows.json schema_version drifted")
    if citation_payload.get("tool_version") != TOOL_VERSION:
        add(errors, "citation_correctness_rows.json tool_version drifted")
    if citation_payload.get("claim_boundary") != CLAIM_BOUNDARY:
        add(errors, "citation_correctness_rows.json claim boundary drifted")
    for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready"]:
        if citation_payload.get(key) != 0:
            add(errors, f"citation_correctness_rows.json must keep {key}=0")
    if citation_payload.get("manual_citation_review_required") != 1:
        add(errors, "citation_correctness_rows.json must require manual citation review")
    citation_json_rows = citation_payload.get("rows", [])
    if not isinstance(citation_json_rows, list):
        add(errors, "citation_correctness_rows.json rows must be a list")
        citation_json_rows = []
    normalized_citation_json_rows = [{key: str(value) for key, value in row.items()} for row in citation_json_rows if isinstance(row, dict)]
    if len(normalized_citation_json_rows) != len(citation_json_rows):
        add(errors, "citation_correctness_rows.json rows must all be objects")
    if citation_payload.get("citation_correctness_rows") != len(citation_rows):
        add(errors, "citation_correctness_rows.json row count drift")
    if normalized_citation_json_rows != citation_rows:
        add(errors, "citation_correctness_rows.json must match citation_correctness_rows.csv")
    fp_rows = read_csv(out_dir / "false_positive_candidate_rows.csv")
    fp_ids = {row.get("finding_id", "") for row in fp_rows}
    if len(fp_ids) != len(fp_rows) or fp_ids != finding_ids:
        add(errors, "false_positive_candidate_rows.csv must contain exactly one row per finding")
    if str(len(fp_rows)) != summary.get("false_positive_candidate_rows"):
        add(errors, "false-positive candidate row count drift")
    for row in fp_rows:
        finding_id = row.get("finding_id", "")
        finding = finding_by_id.get(finding_id, {})
        expected_candidate = "1" if finding.get("severity") in {"medium", "high"} else "0"
        if row.get("manual_review_required") != "1" or row.get("false_positive_candidate") != expected_candidate:
            add(errors, f"false-positive candidate rows must bind finding severity: {finding_id}")
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
    manual_by_finding = {row.get("finding_id", ""): row for row in manual_review_rows}
    for finding_id in sorted(finding_ids):
        suffix = finding_id.removeprefix("finding_")
        if not suffix.isdigit():
            add(errors, f"manual_review_queue.csv finding_id format drift: {finding_id}")
            continue
        expected_review_queue_id = f"manual_review_{int(suffix):04d}"
        actual_review_queue_id = manual_by_finding.get(finding_id, {}).get("review_queue_id")
        if actual_review_queue_id != expected_review_queue_id:
            add(errors, f"manual_review_queue.csv review_queue_id must bind finding_id: {finding_id}")
    for row in manual_review_rows:
        if row.get("review_types") != "accuracy|citation_correctness|false_positive":
            add(errors, "manual_review_queue.csv review_types drifted")
        if row.get("manual_review_required") != "1" or row.get("auto_promoted") != "0":
            add(errors, "manual review queue rows must require manual review and forbid auto-promotion")
        if "unreviewed" not in row.get("review_reason", ""):
            add(errors, "manual review queue rows must preserve unreviewed reason")
    manual_review_payload = read_json(out_dir / "manual_review_queue.json")
    if manual_review_payload.get("schema_version") != "local_repo_audit_manual_review_queue.v1":
        add(errors, "manual_review_queue.json schema_version drifted")
    if manual_review_payload.get("tool_version") != TOOL_VERSION:
        add(errors, "manual_review_queue.json tool_version drifted")
    if manual_review_payload.get("claim_boundary") != CLAIM_BOUNDARY:
        add(errors, "manual_review_queue.json claim boundary drifted")
    for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready"]:
        if manual_review_payload.get(key) != 0:
            add(errors, f"manual_review_queue.json must keep {key}=0")
    rows_payload = manual_review_payload.get("rows", [])
    if not isinstance(rows_payload, list):
        add(errors, "manual_review_queue.json rows must be a list")
        rows_payload = []
    normalized_json_rows = [{key: str(value) for key, value in row.items()} for row in rows_payload if isinstance(row, dict)]
    if len(normalized_json_rows) != len(rows_payload):
        add(errors, "manual_review_queue.json rows must all be objects")
    if manual_review_payload.get("manual_review_queue_rows") != len(manual_review_rows):
        add(errors, "manual_review_queue.json row count drift")
    if normalized_json_rows != manual_review_rows:
        add(errors, "manual_review_queue.json must match manual_review_queue.csv")


def verify_phase_timing(out_dir: Path, summary: dict[str, str], errors: list[str]) -> None:
    rows = read_csv(out_dir / "phase_timing_rows.csv")
    expected = {
        "scan": "scan_latency_ms",
        "plugin": "plugin_latency_ms",
        "serialize": "serialize_latency_ms",
        "verify": "verify_latency_ms",
    }
    if [row.get("phase") for row in rows] != list(expected):
        add(errors, "phase_timing_rows.csv must contain scan/plugin/serialize/verify in order")
        return
    for row in rows:
        phase = row.get("phase", "")
        if row.get("measured") != "1":
            add(errors, f"phase timing must be marked measured: {phase}")
        wall_ms = int(row.get("wall_ms", "0"))
        if wall_ms <= 0:
            add(errors, f"phase timing must be positive: {phase}")
        if str(wall_ms) != str(summary.get(expected[phase])):
            add(errors, f"phase timing summary drift: {phase}")


def verify_route_generation_rows(out_dir: Path, summary: dict[str, str], errors: list[str]) -> None:
    findings = read_csv(out_dir / "audit_findings.csv")
    finding_by_id = {row.get("finding_id", ""): row for row in findings}
    finding_ids = set(finding_by_id)
    citation_counts = {
        finding_id: len([cell for cell in row.get("citations", "").split(";") if cell])
        for finding_id, row in finding_by_id.items()
    }
    sequence_by_finding: dict[str, int] = {}
    for finding_id in finding_ids:
        prefix = "finding_"
        suffix = finding_id[len(prefix):] if finding_id.startswith(prefix) else ""
        if not suffix.isdigit():
            add(errors, f"finding id must use deterministic sequence form: {finding_id}")
            continue
        sequence_by_finding[finding_id] = int(suffix)

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
        sequence = sequence_by_finding.get(finding_id)
        if sequence is not None and hint_id != f"hint_{sequence:04d}":
            add(errors, f"route hint id/finding binding drift: {finding_id}")
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
        sequence = sequence_by_finding.get(finding_id)
        if sequence is not None and generation_id != f"gen_{sequence:04d}":
            add(errors, f"generation id/finding binding drift: {finding_id}")
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
        sequence = sequence_by_finding.get(finding_id)
        if sequence is not None:
            if str(row.get("route_index_row")) != str(sequence):
                add(errors, f"lineage route index/finding binding drift: {finding_id}")
            if str(row.get("compact_route_hint_id")) != f"hint_{sequence:04d}":
                add(errors, f"lineage hint sequence drift: {finding_id}")
            if str(row.get("generator_id")) != f"gen_{sequence:04d}":
                add(errors, f"lineage generator sequence drift: {finding_id}")
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
            row.get("span_sha256", ""),
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
            str(row.get("span_sha256", "")),
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


def verify_diagnostics(out_dir: Path, manifest: dict, summary: dict[str, str], errors: list[str]) -> None:
    diagnostics = read_json(out_dir / "diagnostics.json")
    expected_keys = {
        "schema_version",
        "tool_version",
        "diagnostics_opt_in",
        "diagnostics_collected",
        "external_network_used",
        "scope",
    }
    opt_in_keys = {
        "mode",
        "namespace",
        "max_files",
        "max_total_bytes",
        "max_file_bytes",
        "max_findings",
        "max_queries",
        "active_plugin_ids",
        "source_file_count",
        "finding_rows",
        "suppression_rows",
        "scan_latency_ms",
        "plugin_latency_ms",
        "serialize_latency_ms",
        "verify_latency_ms",
        "latency_ms",
        "install_verified",
        "first_report_verified",
    }
    opt_out_keys = {"reason"}
    diagnostics_scope = diagnostics.get("scope")
    if diagnostics_scope == "coarse-run-metrics":
        allowed_extra = opt_in_keys
    elif diagnostics_scope == "none":
        allowed_extra = opt_out_keys
    else:
        add(errors, "diagnostics.json scope must be 'none' or 'coarse-run-metrics'")
        allowed_extra = opt_out_keys | opt_in_keys
    actual = set(diagnostics)
    if diagnostics_scope == "coarse-run-metrics":
        if actual != expected_keys | opt_in_keys:
            add(errors, "diagnostics.json opt-in keys drifted")
    elif diagnostics_scope == "none":
        if actual != expected_keys | opt_out_keys:
            add(errors, "diagnostics.json opt-out keys drifted")
    elif actual - (expected_keys | allowed_extra):
        add(errors, "diagnostics.json keys drifted")
    if diagnostics.get("schema_version") != "local_repo_audit_diagnostics.v1":
        add(errors, "diagnostics.json schema_version mismatch")
    if diagnostics.get("tool_version") != TOOL_VERSION:
        add(errors, "diagnostics.json tool_version mismatch")
    if diagnostics.get("external_network_used") != 0:
        add(errors, "diagnostics.json external_network_used must be 0")
    if int(diagnostics.get("diagnostics_opt_in", -1)) not in {0, 1}:
        add(errors, "diagnostics.json diagnostics_opt_in must be binary")
    if int(diagnostics.get("diagnostics_collected", -1)) not in {0, 1}:
        add(errors, "diagnostics.json diagnostics_collected must be binary")
    opt_in_flag = int(manifest.get("emit_diagnostics_requested", -1))
    if diagnostics.get("diagnostics_opt_in") != opt_in_flag:
        add(errors, "diagnostics.json diagnostics_opt_in must match manifest.emit_diagnostics_requested")
    if diagnostics.get("diagnostics_collected") != opt_in_flag:
        add(errors, "diagnostics.json diagnostics_collected must match manifest.emit_diagnostics_requested")
    invocation = read_json(out_dir / "audit_invocation.json")
    if int(invocation.get("emit_diagnostics_requested", -1)) != opt_in_flag:
        add(errors, "diagnostics.json opt-in flag must match invocation.emit_diagnostics_requested")
    if opt_in_flag == 0:
        if diagnostics.get("scope") != "none":
            add(errors, "diagnostics.json scope must be 'none' in default opt-out mode")
        if diagnostics.get("diagnostics_collected") != 0:
            add(errors, "diagnostics.json diagnostics_collected must be 0 in opt-out mode")
        if diagnostics.get("reason") != "default-opt-out":
            add(errors, "diagnostics.json reason must be 'default-opt-out' in opt-out mode")
    else:
        if diagnostics.get("scope") != "coarse-run-metrics":
            add(errors, "diagnostics.json scope must be 'coarse-run-metrics' when opted in")
        if "reason" in diagnostics:
            add(errors, "diagnostics.json must not include opt-out reason in opt-in mode")
        resource = read_json(out_dir / "resource_envelope.json")
        # Bind the diagnostic counters to the actual run summary.
        for key, summary_key in {
            "finding_rows": "finding_rows",
            "suppression_rows": "suppression_rows",
            "scan_latency_ms": "scan_latency_ms",
            "plugin_latency_ms": "plugin_latency_ms",
            "serialize_latency_ms": "serialize_latency_ms",
            "verify_latency_ms": "verify_latency_ms",
            "max_files": "max_files",
            "max_total_bytes": "max_total_bytes",
            "max_file_bytes": "max_file_bytes",
            "max_findings": "max_findings",
            "mode": "mode",
            "namespace": "namespace",
        }.items():
            if str(diagnostics.get(key)) != str(summary.get(summary_key)):
                add(errors, f"diagnostics.json {key} drift from summary")
        if str(diagnostics.get("source_file_count")) != str(summary.get("source_files")):
            add(errors, "diagnostics.json source_file_count drift from summary")
        if str(diagnostics.get("max_queries")) != str(resource.get("max_queries")):
            add(errors, "diagnostics.json max_queries drift from resource envelope")
        expected_active_plugins = str(summary.get("active_plugin_ids", "")).split("|") if summary.get("active_plugin_ids") else []
        if diagnostics.get("active_plugin_ids") != expected_active_plugins:
            add(errors, "diagnostics.json active_plugin_ids must match summary")
        if int(diagnostics.get("latency_ms", 0)) != sum(
            int(diagnostics.get(key, 0))
            for key in ["scan_latency_ms", "plugin_latency_ms", "serialize_latency_ms", "verify_latency_ms"]
        ):
            add(errors, "diagnostics.json latency_ms must equal measured phase timing sum")
        for key in ["install_verified", "first_report_verified"]:
            if diagnostics.get(key) not in {0, 1}:
                add(errors, f"diagnostics.json {key} must be binary")
        if diagnostics.get("first_report_verified") != int((out_dir / "AUDIT_REPORT.md").is_file()):
            add(errors, "diagnostics.json first_report_verified drift")
    # Diagnostics must never carry readiness claims regardless of opt-in state.
    for blocked_key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "real_release_package_ready", "gpu_speedup_claim"]:
        if blocked_key in diagnostics:
            add(errors, f"diagnostics.json must not contain readiness claim: {blocked_key}")
    # Diagnostics must never include raw target paths, source file paths, citations, secrets, .env content, or question text.
    forbidden_strings: list[str] = []
    forbidden_strings.append(str(manifest.get("target_repo", "")))
    for row in read_csv(out_dir / "source_manifest.csv"):
        rel = row.get("file_path", "")
        if rel:
            forbidden_strings.append(rel)
    for row in read_csv(out_dir / "citation_spans.csv"):
        rel = row.get("file_path", "")
        if rel:
            forbidden_strings.append(rel)
    for row in read_csv(out_dir / "audit_findings.csv"):
        citation = row.get("citations", "")
        if citation:
            forbidden_strings.extend(cell for cell in citation.split(";") if cell)
        question = row.get("question", "")
        if question:
            forbidden_strings.append(question)
    diagnostics_values = string_values(diagnostics)
    for forbidden in forbidden_strings:
        if forbidden and forbidden in diagnostics_values:
            add(errors, "diagnostics.json must not include raw target/source paths, citations, or question text")
    for value in diagnostics_values:
        lowered = value.lower()
        if ".env" in lowered or "secret" in lowered or "question_text" in lowered:
            add(errors, "diagnostics.json must not include secrets, .env content, or question text markers")


def verify_local_audit(out_dir: Path, *, live_source_check: bool = True) -> list[str]:
    errors: list[str] = []
    for rel in REQUIRED_FILES:
        if not (out_dir / rel).is_file():
            add(errors, f"missing required artifact: {rel}")
    if errors:
        return errors
    sha_entries = verify_sha_manifest(out_dir, errors)
    verify_schema_instances(out_dir, errors)
    manifest = read_json(out_dir / "audit_manifest.json")
    verify_artifact_publish_layout(out_dir, manifest, errors)
    summary_json = read_json(out_dir / "audit_summary.json")
    summary = verify_summary(summary_json, read_csv(out_dir / "audit_summary.csv"), errors)
    verify_manifest(manifest, summary_json, out_dir, errors)
    resource = read_json(out_dir / "resource_envelope.json")
    verify_resource(resource, summary, errors)
    verify_budget_envelope(out_dir, resource, errors)
    verify_invocation(out_dir, manifest, summary, errors)
    verify_diagnostics(out_dir, manifest, summary, errors)
    verify_exit_code_contract(out_dir, errors)
    verify_claim_boundary_docs(out_dir, errors)
    verify_audit_report(out_dir, summary, errors)
    verify_audit_dashboard(out_dir, manifest, summary, errors)
    registry = read_json(out_dir / "plugin_registry.json")
    verify_registry(registry, errors)
    verify_finding_registry_binding(out_dir, registry, errors)
    verify_plugin_rules(out_dir, registry, errors)
    verify_contract(out_dir, sha_entries, errors)
    verify_csv_jsonl(out_dir, errors)
    verify_sarif(out_dir, errors)
    verify_baseline_diff(out_dir, manifest, errors)
    verify_audit_semantic_summary(out_dir, errors)
    source_by_path = verify_sources(out_dir, manifest, errors, live_source_check=live_source_check)
    verify_source_snapshot(out_dir, manifest, source_by_path, errors, live_source_check=live_source_check)
    verify_citations(out_dir, manifest, summary, source_by_path, errors, live_source_check=live_source_check)
    verify_cache_key(out_dir, manifest, summary, errors)
    verify_reproduce(out_dir, manifest, summary, errors)
    verify_manual_rows(out_dir, summary, errors)
    verify_phase_timing(out_dir, summary, errors)
    verify_route_generation_rows(out_dir, summary, errors)
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Verify local audit product artifacts.")
    parser.add_argument("out_dir")
    parser.add_argument(
        "--allow-source-drift",
        action="store_true",
        help="Verify a historical audit bundle without comparing source spans to the current target worktree.",
    )
    args = parser.parse_args(argv)
    try:
        errors = verify_local_audit(Path(args.out_dir).resolve(), live_source_check=not args.allow_source_drift)
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
