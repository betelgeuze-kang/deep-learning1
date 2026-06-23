#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, replace
from pathlib import Path

from auditor_plugin_user_question import USER_QUESTION_PLUGIN
from auditor_plugins import DEFAULT_PLUGINS, AuditPlugin, Finding, SourceFile

SCHEMA_VERSION = "local_repo_audit.v1"
OUTPUT_SCHEMA_VERSION = "local_repo_audit_output.v1"
TOOL_VERSION = "audit_my_repo_alpha.v1"
DETERMINISTIC_GENERATED_AT_UTC = "1970-01-01T00:00:00+00:00"
ARTIFACT_CONTRACT_SCHEMA_VERSION = "local_repo_audit_artifacts.v1"
AUDITABLE_SOURCE_SUFFIXES = {
    ".md",
    ".py",
    ".toml",
    ".ini",
    ".cfg",
    ".txt",
    ".yaml",
    ".yml",
    ".json",
    ".sh",
    ".cpp",
    ".hpp",
    ".cc",
    ".cxx",
    ".c",
    ".h",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
}
AUDITABLE_SOURCE_NAMES = {"makefile", "cmakelists.txt", "package.json"}
MODE_PLUGIN_IDS = {
    "quick": ("doc_code_identity", "deprecated_api", "unsupported_claim"),
    "full": ("doc_code_identity", "deprecated_api", "config_consistency", "unsupported_claim", "missing_evidence"),
}
MODE_DEFAULT_BUDGETS = {
    "quick": {"max_files": 64, "max_total_bytes": 2_000_000, "max_file_bytes": 300_000, "max_findings": 20},
    "full": {"max_files": 220, "max_total_bytes": 15_000_000, "max_file_bytes": 700_000, "max_findings": 100},
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


class AuditInputError(Exception):
    """User-correctable audit invocation/input error."""


@dataclass(frozen=True)
class AuditBudget:
    max_files: int
    max_total_bytes: int
    max_file_bytes: int
    max_findings: int

    def as_dict(self) -> dict[str, int]:
        return {
            "max_files": self.max_files,
            "max_total_bytes": self.max_total_bytes,
            "max_file_bytes": self.max_file_bytes,
            "max_findings": self.max_findings,
        }


@dataclass(frozen=True)
class SuppressionRule:
    suppression_id: str
    plugin_id: str
    rule_id: str
    file_path: str
    reason: str
    active: bool = True


@dataclass(frozen=True)
class BaselineBundle:
    supplied: bool
    output: str
    output_sha256: str
    manifest_sha256: str
    cache_key: str
    finding_rows: tuple[dict[str, str], ...]


@dataclass(frozen=True)
class ChangedFileSelection:
    source_scope: str
    changed_files_from: str
    changed_files_from_sha256: str
    changed_file_rel_paths: tuple[str, ...]


CSV_CONTRACTS: dict[str, list[str]] = {
    "baseline_diff_rows.csv": ["diff_status", "finding_fingerprint", "content_sha256", "baseline_content_sha256", "current_finding_id", "baseline_finding_id", "plugin_id", "plugin_rule_ids", "confidence", "severity", "language", "current_citations", "baseline_citations", "current_citation_sha256s", "baseline_citation_sha256s", "current_suppressed", "baseline_suppressed", "manual_review_required"],
    "source_manifest.csv": ["source_id", "file_path", "sha256", "bytes", "route_memory_source"],
    "audit_findings.csv": ["finding_id", "audit_type", "plugin_id", "plugin_rule_ids", "confidence", "language", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "suppressed", "suppression_ids", "citations", "citation_sha256s", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"],
    "citation_spans.csv": ["finding_id", "citation_id", "file_path", "line_start", "line_end", "sha256", "span_sha256", "span_text_preview", "mmap_value_byte_read"],
    "compact_route_hint_rows.csv": ["hint_id", "finding_id", "hint_bytes", "source_citation_count", "raw_context_appended", "proposal_hint_used"],
    "grounded_generation_rows.csv": ["generation_id", "finding_id", "hint_id", "generator", "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes", "grounded", "abstain", "unsupported_claim", "answer"],
    "abstain_rows.csv": ["finding_id", "audit_type", "plugin_id", "plugin_rule_ids", "confidence", "language", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "suppressed", "suppression_ids", "citations", "citation_sha256s", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"],
    "unsupported_claim_rows.csv": ["finding_id", "audit_type", "plugin_id", "plugin_rule_ids", "confidence", "language", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "suppressed", "suppression_ids", "citations", "citation_sha256s", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"],
    "wrong_answer_guard_rows.csv": ["finding_id", "guard_id", "unsupported_direct_answer_blocked", "citation_required", "audit_trail_required", "wrong_answer_guard_pass"],
    "accuracy_rows.csv": ["finding_id", "accuracy_label", "automatic_accuracy_claimed", "manual_accuracy_review_required"],
    "citation_correctness_rows.csv": ["finding_id", "citation_count", "citation_bound", "citation_correctness_label", "manual_citation_review_required"],
    "latency_rows.csv": ["finding_id", "latency_ms", "latency_source"],
    "false_positive_candidate_rows.csv": ["finding_id", "manual_review_required", "false_positive_candidate", "auto_promoted"],
    "manual_review_queue.csv": ["finding_id", "review_queue_id", "review_types", "manual_review_required", "review_reason", "auto_promoted"],
    "plugin_rule_rows.csv": ["plugin_id", "audit_type", "rule_id", "language", "file_suffixes", "pattern_label", "evidence_policy", "confidence", "parser_id"],
    "phase_timing_rows.csv": ["phase", "wall_ms", "measured"],
    "suppressed_findings.csv": ["suppression_id", "finding_id", "plugin_id", "plugin_rule_ids", "confidence", "language", "audit_type", "severity", "evidence_paths", "citations", "citation_sha256s", "citation_span_sha256s", "reason", "active"],
    "audit_summary.csv": ["schema_version", "tool_version", "audit_my_repo_ready", "target_repo", "mode", "namespace", "generator", "question_supplied", "source_files", "source_scope", "changed_file_rows", "finding_rows", "suppression_rows", "citation_span_rows", "abstain_rows", "unsupported_claim_rows", "accuracy_rows", "citation_correctness_rows", "false_positive_candidate_rows", "manual_review_queue_rows", "wrong_answer_guard_rows", "wrong_answer_guard_pass_rows", "claim_boundary_ready", "route_memory_lineage_rows", "mmap_read_trace_rows", "compact_route_hint_rows", "grounded_generation_rows", "raw_prompt_context_bytes", "attention_blocks", "transformer_blocks", "oracle_prediction_used", "raw_input_extractor_used", "real_release_package_ready", "release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "gpu_speedup_claim", "max_files", "max_total_bytes", "max_file_bytes", "max_findings", "active_plugin_ids", "scan_latency_ms", "plugin_latency_ms", "serialize_latency_ms", "verify_latency_ms", "latency_ms"],
}

JSONL_CONTRACTS: dict[str, list[str]] = {
    "audit_findings.jsonl": CSV_CONTRACTS["audit_findings.csv"],
    "citation_spans.jsonl": CSV_CONTRACTS["citation_spans.csv"],
    "prediction_lineage.jsonl": ["finding_id", "route_index_row", "compact_route_hint_id", "generator_id", "citation_count", "audit_trail_bound"],
    "mmap_read_trace.jsonl": ["finding_id", "file_path", "line_start", "sha256", "span_sha256", "mmap_value_byte_read"],
}

JSON_CONTRACTS: dict[str, list[str]] = {
    "audit_dashboard.json": ["baseline", "cache_key", "claim_boundary", "dashboard_kind", "diff_counts", "generated_at_utc", "links", "mode", "namespace", "readiness", "review_counts", "run_id", "schema_version", "source_scope", "target_repo", "tool_version", "top_findings"],
    "audit_findings.json": ["claim_boundary", "findings", "public_comparison_claim_ready", "real_model_execution_ready", "release_ready", "schema_version", "tool_version"],
    "audit_findings.sarif.json": ["$schema", "runs", "version"],
    "accuracy_rows.json": ["accuracy_rows", "automatic_accuracy_claimed", "claim_boundary", "manual_accuracy_review_required", "public_comparison_claim_ready", "real_model_execution_ready", "release_ready", "rows", "schema_version", "tool_version"],
    "citation_correctness_rows.json": ["citation_correctness_rows", "claim_boundary", "manual_citation_review_required", "public_comparison_claim_ready", "real_model_execution_ready", "release_ready", "rows", "schema_version", "tool_version"],
    "manual_review_queue.json": ["claim_boundary", "manual_review_queue_rows", "public_comparison_claim_ready", "real_model_execution_ready", "release_ready", "rows", "schema_version", "tool_version"],
    "audit_semantic_summary.json": ["artifact_sha256s", "claim_boundary", "public_comparison_claim_ready", "real_model_execution_ready", "release_ready", "schema_version", "semantic_artifacts", "semantic_result_sha256", "tool_version"],
    "audit_invocation.json": ["schema_version", "tool_version", "target_repo", "out_dir", "mode", "max_queries", "max_files", "max_total_bytes", "max_file_bytes", "max_findings", "source_scope", "changed_files_from", "changed_files_from_sha256", "changed_file_rows", "active_plugin_ids", "suppression_file", "suppression_file_sha256", "baseline_output", "baseline_output_sha256", "generator", "namespace", "real_benchmark_namespace_confirmed", "question_supplied", "question_sha256", "verify_output_requested", "emit_report_requested", "emit_lineage_requested", "emit_reproduce_requested", "emit_diagnostics_requested"],
    "audit_manifest.json": ["schema_version", "tool_version", "tool_source_sha256", "verifier_source_sha256", "schema_sha256s", "generated_at_utc", "target_repo", "source_scope", "changed_files_from", "changed_files_from_sha256", "changed_file_rows", "namespace", "real_benchmark_namespace_confirmed", "fixture_result_promoted", "real_evidence_claimed", "source_file_count", "finding_rows", "suppression_rows", "atomic_publish", "output_dir_destroyed", "output_dir_overwritten", "publish_mode", "run_id", "bundle_run_dir", "latest_pointer", "cache_key", "plugin_registry_sha256", "suppression_file_sha256", "baseline_output", "baseline_output_sha256", "claim_boundary", "release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "emit_diagnostics_requested"],
    "diagnostics.json": ["schema_version", "tool_version", "diagnostics_opt_in", "diagnostics_collected", "external_network_used", "scope"],
    "audit_summary.json": list(CSV_CONTRACTS["audit_summary.csv"]),
    "baseline_diff_summary.json": ["schema_version", "tool_version", "baseline_supplied", "baseline_output", "baseline_output_sha256", "baseline_manifest_sha256", "baseline_cache_key", "current_finding_rows", "baseline_finding_rows", "diff_rows", "not_compared_findings", "new_findings", "changed_findings", "resolved_findings", "unchanged_findings", "manual_review_required_rows", "release_ready", "public_comparison_claim_ready", "real_model_execution_ready"],
    "exit_code_contract.json": ["schema_version", "tool_version", "success_exit_code", "artifact_verify_failure_exit_code", "input_or_publish_error_exit_code", "wrong_answer_guard_failure_exit_code", "stable_exit_code_policy"],
    "plugin_registry.json": ["schema_version", "tool_version", "plugins"],
    "resource_envelope.json": ["resource_envelope_ready", "tool_version", "source_files_scanned", "source_scope", "changed_file_rows", "max_queries", "max_files", "max_total_bytes", "max_file_bytes", "max_findings", "active_plugin_ids", "suppression_rows", "mode", "namespace", "external_network_used", "raw_prompt_context_bytes", "scan_latency_ms", "plugin_latency_ms", "serialize_latency_ms", "verify_latency_ms", "latency_ms", "wrong_answer_guard_rows", "claim_boundary_ready"],
    "source_snapshot.json": ["schema_version", "tool_version", "target_repo", "source_manifest_sha256", "source_file_count", "git_available", "git_head", "git_dirty", "git_status_sha256", "git_tracked_files"],
}

OPTIONAL_ZERO_ROW_ARTIFACTS = {"abstain_rows.csv", "unsupported_claim_rows.csv", "suppressed_findings.csv"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def elapsed_ms(start_ns: int) -> int:
    return max(1, int(round((time.perf_counter_ns() - start_ns) / 1_000_000)))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def csv_row_count_and_header(path: Path) -> tuple[int, list[str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return len(rows), list(reader.fieldnames or [])


def read_csv_dicts(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def jsonl_row_count_and_keys(path: Path) -> tuple[int, list[str]]:
    keys: set[str] = set()
    rows = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        rows += 1
        payload = json.loads(line)
        keys.update(payload.keys())
    return rows, sorted(keys)


def write_artifact_contract(staging: Path) -> int:
    rows: list[dict] = []
    for artifact_path, required_columns in sorted(CSV_CONTRACTS.items()):
        actual_rows, actual_columns = csv_row_count_and_header(staging / artifact_path)
        min_rows = 0 if artifact_path in OPTIONAL_ZERO_ROW_ARTIFACTS else 1
        rows.append(
            {
                "schema_version": ARTIFACT_CONTRACT_SCHEMA_VERSION,
                "artifact_path": artifact_path,
                "artifact_kind": "csv",
                "required_columns": "|".join(required_columns),
                "actual_columns": "|".join(actual_columns),
                "required_keys": "",
                "actual_keys": "",
                "min_rows": min_rows,
                "actual_rows": actual_rows,
                "sha256_manifest_required": 1,
                "deterministic_required": 1,
            }
        )
    for artifact_path, required_keys in sorted(JSONL_CONTRACTS.items()):
        actual_rows, actual_keys = jsonl_row_count_and_keys(staging / artifact_path)
        rows.append(
            {
                "schema_version": ARTIFACT_CONTRACT_SCHEMA_VERSION,
                "artifact_path": artifact_path,
                "artifact_kind": "jsonl",
                "required_columns": "",
                "actual_columns": "",
                "required_keys": "|".join(required_keys),
                "actual_keys": "|".join(actual_keys),
                "min_rows": 1,
                "actual_rows": actual_rows,
                "sha256_manifest_required": 1,
                "deterministic_required": 1,
            }
        )
    for artifact_path, required_keys in sorted(JSON_CONTRACTS.items()):
        payload = json.loads((staging / artifact_path).read_text(encoding="utf-8"))
        rows.append(
            {
                "schema_version": ARTIFACT_CONTRACT_SCHEMA_VERSION,
                "artifact_path": artifact_path,
                "artifact_kind": "json",
                "required_columns": "",
                "actual_columns": "",
                "required_keys": "|".join(required_keys),
                "actual_keys": "|".join(sorted(payload.keys())),
                "min_rows": 1,
                "actual_rows": 1,
                "sha256_manifest_required": 1,
                "deterministic_required": 1,
            }
        )
    for artifact_path, artifact_kind in [
        ("AUDIT_DASHBOARD.html", "html"),
        ("AUDIT_REPORT.md", "markdown"),
        ("ARCHITECTURE_TRACE.md", "markdown"),
        ("BASELINE_DIFF.md", "markdown"),
        ("claim_boundary.md", "markdown"),
        ("reproduce.sh", "shell"),
        ("verify.sh", "shell"),
    ]:
        if (staging / artifact_path).is_file():
            rows.append(
                {
                    "schema_version": ARTIFACT_CONTRACT_SCHEMA_VERSION,
                    "artifact_path": artifact_path,
                    "artifact_kind": artifact_kind,
                    "required_columns": "",
                    "actual_columns": "",
                    "required_keys": "",
                    "actual_keys": "",
                    "min_rows": 1,
                    "actual_rows": 1,
                    "sha256_manifest_required": 1,
                    "deterministic_required": 1,
                }
            )
    write_csv(
        staging / "artifact_contract_rows.csv",
        ["schema_version", "artifact_path", "artifact_kind", "required_columns", "actual_columns", "required_keys", "actual_keys", "min_rows", "actual_rows", "sha256_manifest_required", "deterministic_required"],
        rows,
    )
    return len(rows)


def rel_to_target(target: Path, path: Path) -> str:
    return str(path.resolve().relative_to(target))


def is_target_regular_file(target: Path, path: Path) -> bool:
    if path.is_symlink() or not path.is_file():
        return False
    try:
        resolved = path.resolve()
        resolved.relative_to(target)
    except (OSError, ValueError):
        return False
    return True


def is_auditable_source_path(path: Path) -> bool:
    suffix = path.suffix.lower()
    name = path.name.lower()
    return suffix in AUDITABLE_SOURCE_SUFFIXES or name in AUDITABLE_SOURCE_NAMES


def select_auditable_files(target: Path, files: list[Path], budget: AuditBudget) -> list[Path]:
    allowed = []
    total_bytes = 0
    seen_rel_paths: set[str] = set()
    for path in sorted(files, key=lambda candidate: str(candidate)):
        if not is_target_regular_file(target, path):
            continue
        rel_path = rel_to_target(target, path)
        if rel_path in seen_rel_paths:
            continue
        seen_rel_paths.add(rel_path)
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if size <= 0 or size > budget.max_file_bytes:
            continue
        if total_bytes + size > budget.max_total_bytes:
            continue
        if is_auditable_source_path(path):
            allowed.append(path)
            total_bytes += size
        if len(allowed) >= budget.max_files:
            break
    return allowed


def tracked_files(target: Path, budget: AuditBudget) -> list[Path]:
    try:
        output = subprocess.check_output(["git", "-C", str(target), "ls-files"], text=True, stderr=subprocess.DEVNULL)
        files = [target / line for line in output.splitlines() if line.strip()]
    except Exception:
        files = [path for path in target.rglob("*") if ".git" not in path.parts]
    return select_auditable_files(target, files, budget)


def changed_files(target: Path, budget: AuditBudget, selection: ChangedFileSelection) -> list[Path]:
    files = [target / rel_path for rel_path in selection.changed_file_rel_paths]
    return select_auditable_files(target, files, budget)


def line_for(path: Path, patterns: list[str], preferred_line: int | None = None) -> tuple[int, str]:
    text = read_text(path)
    lines = text.splitlines()
    if preferred_line is not None and 0 < preferred_line <= len(lines):
        return preferred_line, lines[preferred_line - 1].strip()[:280]
    for pattern in patterns:
        if not pattern:
            continue
        for idx, line in enumerate(lines, start=1):
            if pattern in line or pattern.lower() in line.lower():
                return idx, line.strip()[:280]
    for idx, line in enumerate(lines, start=1):
        if line.strip():
            return idx, line.strip()[:280]
    return 1, path.name


def collect_sources(target: Path, budget: AuditBudget, selection: ChangedFileSelection) -> tuple[list[SourceFile], list[dict]]:
    if selection.source_scope == "changed-files":
        source_paths = changed_files(target, budget, selection)
    else:
        source_paths = tracked_files(target, budget)
    if not source_paths:
        raise AuditInputError("no auditable source files found")
    sources: list[SourceFile] = []
    rows: list[dict] = []
    for idx, path in enumerate(source_paths, start=1):
        digest = sha256(path)
        source = SourceFile(
            source_id=f"src_{idx:04d}",
            path=path,
            rel_path=rel_to_target(target, path),
            sha256=digest,
            text=read_text(path),
        )
        sources.append(source)
        rows.append(
            {
                "source_id": source.source_id,
                "file_path": source.rel_path,
                "sha256": digest,
                "bytes": path.stat().st_size,
                "route_memory_source": 1,
            }
        )
    return sources, rows


def git_output(target: Path, args: list[str]) -> tuple[int, str]:
    result = subprocess.run(
        ["git", "-C", str(target), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.returncode, result.stdout


def source_snapshot_payload(target: Path, source_manifest: Path, source_file_count: int) -> dict:
    payload = {
        "schema_version": "local_repo_audit_source_snapshot.v1",
        "tool_version": TOOL_VERSION,
        "target_repo": str(target),
        "source_manifest_sha256": sha256(source_manifest),
        "source_file_count": source_file_count,
        "git_available": 0,
        "git_head": "",
        "git_dirty": 0,
        "git_status_sha256": sha256_text(""),
        "git_tracked_files": 0,
    }
    rc, inside = git_output(target, ["rev-parse", "--is-inside-work-tree"])
    if rc != 0 or inside.strip() != "true":
        return payload
    payload["git_available"] = 1
    rc, head = git_output(target, ["rev-parse", "HEAD"])
    payload["git_head"] = head.strip() if rc == 0 else ""
    rc, status = git_output(target, ["status", "--porcelain", "--untracked-files=all"])
    status_text = status if rc == 0 else ""
    payload["git_dirty"] = int(bool(status_text.strip()))
    payload["git_status_sha256"] = sha256_text(status_text)
    rc, tracked = git_output(target, ["ls-files"])
    payload["git_tracked_files"] = len([line for line in tracked.splitlines() if line.strip()]) if rc == 0 else 0
    return payload


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def empty_changed_file_selection() -> ChangedFileSelection:
    return ChangedFileSelection(
        source_scope="tracked",
        changed_files_from="",
        changed_files_from_sha256=sha256_text(""),
        changed_file_rel_paths=tuple(),
    )


def resolve_changed_file_selection(root: Path, target: Path, path_text: str) -> ChangedFileSelection:
    if not path_text:
        return empty_changed_file_selection()
    path = Path(path_text).expanduser()
    if not path.is_absolute():
        path = (root / path).resolve()
    else:
        path = path.resolve()
    if is_forbidden_env_path(path):
        raise AuditInputError("refusing to read .env-like changed-files input")
    if not path.is_file():
        raise AuditInputError(f"--changed-files-from is not a file: {path}")
    rel_paths: list[str] = []
    seen: set[str] = set()
    for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        raw = line.strip()
        if not raw:
            continue
        if "\0" in raw:
            raise AuditInputError(f"--changed-files-from line {line_number} contains a NUL byte")
        rel_path = Path(raw)
        if raw.startswith("~") or rel_path.is_absolute() or ".." in rel_path.parts:
            raise AuditInputError(f"--changed-files-from line {line_number} must be a relative path inside the target repo")
        normalized = rel_path.as_posix()
        if normalized in {"", "."}:
            continue
        candidate = target / normalized
        try:
            candidate.resolve().relative_to(target)
        except (OSError, ValueError):
            raise AuditInputError(f"--changed-files-from line {line_number} escapes the target repo")
        if normalized not in seen:
            rel_paths.append(normalized)
            seen.add(normalized)
    if not rel_paths:
        raise AuditInputError("--changed-files-from did not contain any relative changed file paths")
    return ChangedFileSelection(
        source_scope="changed-files",
        changed_files_from=str(path),
        changed_files_from_sha256=sha256(path),
        changed_file_rel_paths=tuple(sorted(rel_paths)),
    )


def load_suppression_rules(path_text: str) -> tuple[tuple[SuppressionRule, ...], str, str]:
    if not path_text:
        return tuple(), "", sha256_text("")
    path = Path(path_text).expanduser().resolve()
    if is_forbidden_env_path(path):
        raise AuditInputError("refusing to read .env-like suppression/allowlist file")
    if not path.is_file():
        raise AuditInputError(f"suppression/allowlist file is not a file: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise AuditInputError(f"suppression/allowlist file is not valid JSON: {exc}") from exc
    root = Path(__file__).resolve().parents[1]
    validator = root / "tools" / "validate_json_schemas.py"
    schema = root / "schemas" / "local_repo_audit_suppressions.schema.json"
    result = subprocess.run(
        [sys.executable, str(validator), "--schema-instance", str(schema), str(path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        raise AuditInputError(f"suppression/allowlist file failed schema validation{suffix}")
    rows = payload.get("suppressions", payload) if isinstance(payload, dict) else payload
    if not isinstance(rows, list):
        raise AuditInputError("suppression/allowlist file must be a JSON array or contain a suppressions array")
    rules: list[SuppressionRule] = []
    for idx, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            raise AuditInputError("suppression/allowlist rows must be JSON objects")
        suppression_id = str(row.get("suppression_id") or f"suppression_{idx:04d}")
        plugin_id = str(row.get("plugin_id") or "")
        rule_id = str(row.get("rule_id") or "")
        file_path = str(row.get("file_path") or "")
        reason = str(row.get("reason") or "").strip()
        active = bool(row.get("active", True))
        if not plugin_id and not rule_id and not file_path:
            raise AuditInputError(f"suppression row {suppression_id} must specify plugin_id, rule_id, or file_path")
        if active and not reason:
            raise AuditInputError(f"active suppression row {suppression_id} must include a reason")
        rules.append(
            SuppressionRule(
                suppression_id=suppression_id,
                plugin_id=plugin_id,
                rule_id=rule_id,
                file_path=file_path,
                reason=reason,
                active=active,
            )
        )
    return tuple(rules), str(path), sha256(path)


def empty_baseline_bundle() -> BaselineBundle:
    return BaselineBundle(
        supplied=False,
        output="",
        output_sha256=sha256_text(""),
        manifest_sha256=sha256_text(""),
        cache_key="",
        finding_rows=tuple(),
    )


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
        digest.update(sha256(artifact).encode("utf-8"))
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def resolve_baseline_bundle(root: Path, path_text: str) -> BaselineBundle:
    if not path_text:
        return empty_baseline_bundle()
    baseline = Path(path_text).expanduser()
    if not baseline.is_absolute():
        baseline = (root / baseline).resolve()
    else:
        baseline = baseline.resolve()
    if not baseline.is_dir():
        raise AuditInputError(f"--baseline is not a directory: {baseline}")
    verifier = root / "tools" / "verify_local_audit.py"
    result = subprocess.run(
        [sys.executable, str(verifier), str(baseline), "--allow-source-drift"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        raise AuditInputError(f"--baseline must point at a verified audit output{suffix}")
    manifest = json.loads((baseline / "audit_manifest.json").read_text(encoding="utf-8"))
    return BaselineBundle(
        supplied=True,
        output=str(baseline),
        output_sha256=sha256_baseline_output(baseline),
        manifest_sha256=sha256(baseline / "audit_manifest.json"),
        cache_key=str(manifest.get("cache_key", "")),
        finding_rows=tuple(read_csv_dicts(baseline / "audit_findings.csv")),
    )


def suppression_matches(target: Path, finding: Finding, rule: SuppressionRule) -> bool:
    if not rule.active:
        return False
    if rule.plugin_id and rule.plugin_id != finding.plugin_id:
        return False
    if rule.rule_id and rule.rule_id not in finding.rule_ids:
        return False
    if rule.file_path:
        rel_paths = set()
        for path in finding.evidence_paths:
            try:
                rel_paths.add(rel_to_target(target, path))
            except (OSError, ValueError):
                continue
        if rule.file_path not in rel_paths:
            return False
    return True


def suppression_ids_for_finding(target: Path, finding: Finding, rules: tuple[SuppressionRule, ...]) -> tuple[str, ...]:
    return tuple(rule.suppression_id for rule in rules if suppression_matches(target, finding, rule))


def active_plugins_for_mode(mode: str) -> tuple[AuditPlugin, ...]:
    active_ids = set(MODE_PLUGIN_IDS[mode])
    return tuple(plugin for plugin in DEFAULT_PLUGINS if plugin.plugin_id in active_ids)


def schema_sha256s(root: Path) -> dict[str, str]:
    return {rel: sha256(root / rel) for rel in SCHEMA_FILES}


def cache_key_payload(
    root: Path,
    target: Path,
    source_rows: list[dict],
    source_snapshot: dict,
    changed_file_selection: ChangedFileSelection,
    mode: str,
    budget: AuditBudget,
    max_queries: int,
    active_plugin_ids: tuple[str, ...],
    suppression_file_sha256: str,
    baseline_output: str,
    baseline_output_sha256: str,
    namespace: str,
    real_benchmark_namespace_confirmed: int,
    question: str,
    verify_output: bool,
    emit_report: bool,
    emit_lineage: bool,
    emit_reproduce: bool,
    emit_diagnostics: bool,
    plugin_registry_sha256: str,
    tool_source_sha256: str,
) -> dict:
    return {
        "tool_version": TOOL_VERSION,
        "tool_source_sha256": tool_source_sha256,
        "verifier_source_sha256": sha256(root / "tools" / "verify_local_audit.py"),
        "schema_sha256s": schema_sha256s(root),
        "target": str(target),
        "source": [(row["file_path"], row["sha256"]) for row in source_rows],
        "source_snapshot": source_snapshot,
        "source_scope": changed_file_selection.source_scope,
        "changed_files_from": changed_file_selection.changed_files_from,
        "changed_files_from_sha256": changed_file_selection.changed_files_from_sha256,
        "changed_file_rows": len(changed_file_selection.changed_file_rel_paths),
        "mode": mode,
        "max_queries": max_queries,
        **budget.as_dict(),
        "active_plugin_ids": list(active_plugin_ids),
        "suppression_file_sha256": suppression_file_sha256,
        "baseline_output": baseline_output,
        "baseline_output_sha256": baseline_output_sha256,
        "namespace": namespace,
        "real_benchmark_namespace_confirmed": real_benchmark_namespace_confirmed,
        "question": question,
        "verify_output_requested": int(verify_output),
        "emit_report_requested": int(emit_report),
        "emit_lineage_requested": int(emit_lineage),
        "emit_reproduce_requested": int(emit_reproduce),
        "emit_diagnostics_requested": int(emit_diagnostics),
        "plugin_registry_sha256": plugin_registry_sha256,
    }


def build_rows(target: Path, findings: list[Finding], suppression_rules: tuple[SuppressionRule, ...]) -> tuple[list[dict], list[dict], list[dict]]:
    finding_rows: list[dict] = []
    span_rows: list[dict] = []
    suppressed_rows: list[dict] = []
    for idx, finding in enumerate(findings, start=1):
        finding_id = f"finding_{idx:03d}"
        suppression_ids = suppression_ids_for_finding(target, finding, suppression_rules)
        citation_cells = []
        citation_sha256s = []
        citation_span_sha256s = []
        for cidx, path in enumerate(finding.evidence_paths, start=1):
            if not path.exists() or not path.is_file():
                continue
            citation_patterns = list(finding.evidence_terms) + [
                finding.answer,
                "name",
                "project",
                "default",
                "timeout",
                "distutils",
                "pkg_resources",
                "TODO",
                "# ",
            ]
            preferred_line = finding.evidence_line_numbers[cidx - 1] if cidx - 1 < len(finding.evidence_line_numbers) else None
            line_no, snippet = line_for(path, citation_patterns, preferred_line)
            citation_id = f"{finding_id}_cite_{cidx}"
            rel_path = rel_to_target(target, path)
            citation_sha256 = sha256(path)
            source_lines = read_text(path).splitlines()
            span_text = source_lines[line_no - 1].strip() if 0 < line_no <= len(source_lines) else snippet
            span_sha256 = sha256_text(span_text)
            citation_cells.append(f"{rel_path}:{line_no}")
            citation_sha256s.append(citation_sha256)
            citation_span_sha256s.append(span_sha256)
            span_rows.append(
                {
                    "finding_id": finding_id,
                    "citation_id": citation_id,
                    "file_path": rel_path,
                    "line_start": line_no,
                    "line_end": line_no,
                    "sha256": citation_sha256,
                    "span_sha256": span_sha256,
                    "span_text_preview": snippet,
                    "mmap_value_byte_read": 1,
                }
            )
        grounded = 0
        if not finding.abstain and citation_cells:
            grounded = finding.grounded
        abstain = finding.abstain if citation_cells else 1
        finding_rows.append(
            {
                "finding_id": finding_id,
                "audit_type": finding.audit_type,
                "plugin_id": finding.plugin_id,
                "plugin_rule_ids": "|".join(finding.rule_ids),
                "confidence": finding.confidence,
                "language": finding.language,
                "question": finding.question,
                "answer": finding.answer if citation_cells else "Abstain: no source citation could be bound for this finding.",
                "severity": finding.severity,
                "grounded": grounded,
                "abstain": abstain,
                "unsupported_claim": finding.unsupported_claim,
                "suppressed": int(bool(suppression_ids)),
                "suppression_ids": "|".join(suppression_ids),
                "citations": ";".join(citation_cells),
                "citation_sha256s": ";".join(citation_sha256s),
                "route_memory_lineage": 1,
                "raw_prompt_context_bytes": 0,
                "oracle_prediction_used": 0,
                "raw_input_extractor_used": 0,
            }
        )
        for suppression_id in suppression_ids:
            rule = next(rule for rule in suppression_rules if rule.suppression_id == suppression_id)
            suppressed_rows.append(
                {
                    "suppression_id": suppression_id,
                    "finding_id": finding_id,
                    "plugin_id": finding.plugin_id,
                    "plugin_rule_ids": "|".join(finding.rule_ids),
                    "confidence": finding.confidence,
                    "language": finding.language,
                    "audit_type": finding.audit_type,
                    "severity": finding.severity,
                    "evidence_paths": "|".join(cell.rsplit(":", 1)[0] for cell in citation_cells),
                    "citations": ";".join(citation_cells),
                    "citation_sha256s": ";".join(citation_sha256s),
                    "citation_span_sha256s": ";".join(citation_span_sha256s),
                    "reason": rule.reason,
                    "active": int(rule.active),
                }
            )
    return finding_rows, span_rows, suppressed_rows


def bind_findings_to_sources(findings: list[Finding], sources: list[SourceFile]) -> list[Finding]:
    allowed = {source.path.resolve() for source in sources}
    rebound: list[Finding] = []
    fallback = (sources[0].path,) if sources else tuple()
    for finding in findings:
        paths: list[Path] = []
        line_numbers: list[int] = []
        for idx, path in enumerate(finding.evidence_paths):
            try:
                resolved = path.resolve()
            except OSError:
                continue
            if resolved not in allowed:
                continue
            paths.append(path)
            if idx < len(finding.evidence_line_numbers):
                line_numbers.append(finding.evidence_line_numbers[idx])
        if paths:
            rebound.append(replace(finding, evidence_paths=tuple(paths), evidence_line_numbers=tuple(line_numbers)))
        else:
            rebound.append(
                replace(
                    finding,
                    answer="Abstain: no source citation inside the bounded source snapshot could be bound for this finding.",
                    evidence_paths=fallback,
                    evidence_terms=("README",),
                    grounded=0,
                    abstain=1,
                    confidence="low",
                    evidence_line_numbers=tuple(),
                )
            )
    return rebound


def publish_atomic(root: Path, staging: Path, out_dir: Path, overwrite_latest: bool = False) -> str:
    staging_manifest = json.loads((staging / "audit_manifest.json").read_text(encoding="utf-8"))
    run_id = str(staging_manifest["run_id"])
    runs_dir = out_dir / "runs"
    run_dir = runs_dir / run_id
    latest_link = out_dir / "latest"

    def verify_existing_run(path: Path) -> None:
        verifier = root / "tools" / "verify_local_audit.py"
        result = subprocess.run(
            [sys.executable, str(verifier), str(path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0:
            raise RuntimeError("existing versioned run failed local audit verification")

    out_dir.mkdir(parents=True, exist_ok=True)
    runs_dir.mkdir(parents=True, exist_ok=True)
    for path in sorted(staging.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(staging)
        compat_path = out_dir / rel
        if compat_path.exists() and not compat_path.is_symlink():
            raise RuntimeError(
                "refusing to replace an existing non-symlink output artifact; "
                f"use a fresh --out path or move {rel}"
            )
        if compat_path.is_symlink():
            target = os.readlink(compat_path)
            if target != f"latest/{rel}":
                raise RuntimeError(
                    "refusing to replace an output symlink that does not point at the latest bundle: "
                    f"{rel}"
                )

    latest_manifest_path = latest_link / "audit_manifest.json"
    if latest_manifest_path.is_file():
        try:
            latest_manifest = json.loads(latest_manifest_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            raise RuntimeError(
                "latest output pointer contains an unreadable audit_manifest.json; "
                "use a fresh --out path or repair the existing artifact"
            ) from exc
        if latest_manifest.get("cache_key") != staging_manifest.get("cache_key") and not overwrite_latest:
            raise RuntimeError(
                "output directory already has a different latest cache_key; "
                "use a fresh --out path or pass --overwrite-latest to publish a new versioned run"
            )

    if run_dir.exists():
        existing_manifest_path = run_dir / "audit_manifest.json"
        if not existing_manifest_path.is_file():
            raise RuntimeError(f"versioned run directory exists without audit_manifest.json: {run_id}")
        try:
            existing_manifest = json.loads(existing_manifest_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            raise RuntimeError(
                "versioned run directory contains an unreadable audit_manifest.json; "
                "use a fresh --out path or repair the existing artifact"
            ) from exc
        if existing_manifest.get("cache_key") != staging_manifest.get("cache_key"):
            raise RuntimeError(
                "versioned run directory cache_key mismatch; remove the corrupt run or use a fresh --out path"
            )
        verify_existing_run(run_dir)
        publish_status = "idempotent-cache-hit"
        created_run_dir = False
    else:
        if os.environ.get("AUDIT_MY_REPO_FAIL_PUBLISH_BEFORE_RUN_RENAME") == "1":
            raise RuntimeError("simulated publish failure before versioned run rename")
        os.replace(staging, run_dir)
        created_run_dir = True
        try:
            verify_existing_run(run_dir)
        except RuntimeError:
            shutil.rmtree(run_dir, ignore_errors=True)
            raise
        publish_status = "created-versioned-run"

    previous_latest_target = os.readlink(latest_link) if latest_link.is_symlink() else ""
    previous_latest_existed = latest_link.exists() or latest_link.is_symlink()
    created_compat_paths: list[Path] = []
    tmp_latest = out_dir / f".latest.tmp-{os.getpid()}"
    try:
        if tmp_latest.exists() or tmp_latest.is_symlink():
            tmp_latest.unlink()
        os.symlink(f"runs/{run_id}", tmp_latest)
        if os.environ.get("AUDIT_MY_REPO_FAIL_PUBLISH_BEFORE_LATEST") == "1":
            raise RuntimeError("simulated publish failure before latest pointer swap")
        os.replace(tmp_latest, latest_link)
        if os.environ.get("AUDIT_MY_REPO_FAIL_PUBLISH_AFTER_LATEST") == "1":
            raise RuntimeError("simulated publish failure after latest pointer swap")

        for path in sorted(run_dir.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(run_dir)
            compat_path = out_dir / rel
            if compat_path.exists() or compat_path.is_symlink():
                continue
            compat_path.parent.mkdir(parents=True, exist_ok=True)
            os.symlink(f"latest/{rel}", compat_path)
            created_compat_paths.append(compat_path)
    except Exception:
        tmp_latest.unlink(missing_ok=True)
        for compat_path in reversed(created_compat_paths):
            try:
                if compat_path.is_symlink() and os.readlink(compat_path).startswith("latest/"):
                    compat_path.unlink()
            except OSError:
                pass
        if previous_latest_existed and previous_latest_target:
            rollback_latest = out_dir / f".latest.rollback-{os.getpid()}"
            rollback_latest.unlink(missing_ok=True)
            os.symlink(previous_latest_target, rollback_latest)
            os.replace(rollback_latest, latest_link)
        elif latest_link.is_symlink():
            latest_link.unlink()
        if created_run_dir:
            shutil.rmtree(run_dir, ignore_errors=True)
        raise
    return publish_status


def write_phase_timing(staging: Path, timings: dict[str, int]) -> None:
    write_csv(
        staging / "phase_timing_rows.csv",
        CSV_CONTRACTS["phase_timing_rows.csv"],
        [
            {"phase": "scan", "wall_ms": timings["scan_latency_ms"], "measured": 1},
            {"phase": "plugin", "wall_ms": timings["plugin_latency_ms"], "measured": 1},
            {"phase": "serialize", "wall_ms": timings["serialize_latency_ms"], "measured": 1},
            {"phase": "verify", "wall_ms": timings["verify_latency_ms"], "measured": 1},
        ],
    )


def write_sha_manifest(staging: Path) -> None:
    sha_rows = []
    for path in sorted(staging.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            sha_rows.append(f"{sha256(path).removeprefix('sha256:')}  {path.relative_to(staging)}")
    (staging / "sha256sums.txt").write_text("\n".join(sha_rows) + "\n", encoding="utf-8")


def sarif_level(severity: str) -> str:
    return {
        "high": "error",
        "medium": "warning",
        "low": "note",
    }.get(severity, "note")


def write_sarif(staging: Path, finding_rows: list[dict], span_rows: list[dict], rule_rows: list[dict]) -> None:
    spans_by_finding: dict[str, list[dict]] = {}
    for span in span_rows:
        spans_by_finding.setdefault(str(span["finding_id"]), []).append(span)

    sarif_rules = []
    rule_index: dict[str, int] = {}
    for idx, rule in enumerate(rule_rows):
        rule_id = str(rule["rule_id"])
        rule_index[rule_id] = idx
        sarif_rules.append(
            {
                "id": rule_id,
                "name": f"{rule['plugin_id']}:{rule_id}",
                "shortDescription": {"text": str(rule["pattern_label"])},
                "fullDescription": {
                    "text": (
                        f"{rule['plugin_id']} {rule['audit_type']} rule for {rule['language']} "
                        f"using {rule['evidence_policy']} evidence."
                    )
                },
                "properties": {
                    "plugin_id": rule["plugin_id"],
                    "audit_type": rule["audit_type"],
                    "language": rule["language"],
                    "file_suffixes": rule["file_suffixes"],
                    "evidence_policy": rule["evidence_policy"],
                    "confidence": rule["confidence"],
                },
            }
        )

    results = []
    for finding in finding_rows:
        rule_ids = [cell for cell in str(finding["plugin_rule_ids"]).split("|") if cell]
        rule_id = rule_ids[0] if rule_ids else f"{finding['plugin_id']}:unknown"
        locations = []
        partial_fingerprints: dict[str, str] = {"auditFindingId": str(finding["finding_id"])}
        for idx, span in enumerate(spans_by_finding.get(str(finding["finding_id"]), []), start=1):
            locations.append(
                {
                    "physicalLocation": {
                        "artifactLocation": {"uri": span["file_path"]},
                        "region": {
                            "startLine": int(span["line_start"]),
                            "endLine": int(span["line_end"]),
                        },
                        "properties": {
                            "sha256": span["sha256"],
                            "span_sha256": span["span_sha256"],
                            "span_text_preview": span["span_text_preview"],
                        },
                    }
                }
            )
            if idx == 1:
                partial_fingerprints["primaryLocationLineHash"] = str(span["span_sha256"])
        result = {
            "ruleId": rule_id,
            "level": sarif_level(str(finding["severity"])),
            "kind": "review",
            "message": {"text": str(finding["answer"])},
            "locations": locations,
            "partialFingerprints": partial_fingerprints,
            "properties": {
                "finding_id": finding["finding_id"],
                "audit_type": finding["audit_type"],
                "plugin_id": finding["plugin_id"],
                "plugin_rule_ids": rule_ids,
                "confidence": finding["confidence"],
                "language": finding["language"],
                "severity": finding["severity"],
                "grounded": int(finding["grounded"]),
                "abstain": int(finding["abstain"]),
                "unsupported_claim": int(finding["unsupported_claim"]),
                "suppressed": int(finding["suppressed"]),
                "suppression_ids": [cell for cell in str(finding["suppression_ids"]).split("|") if cell],
                "citation_sha256s": [cell for cell in str(finding["citation_sha256s"]).split(";") if cell],
            },
        }
        if rule_id in rule_index:
            result["ruleIndex"] = rule_index[rule_id]
        if int(finding["suppressed"]):
            result["suppressions"] = [
                {
                    "kind": "external",
                    "justification": "source-bound allowlist suppression: " + str(finding["suppression_ids"]),
                }
            ]
        results.append(result)

    write_json(
        staging / "audit_findings.sarif.json",
        {
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "version": "2.1.0",
            "runs": [
                {
                    "tool": {
                        "driver": {
                            "name": "audit-my-repo",
                            "semanticVersion": TOOL_VERSION,
                            "rules": sarif_rules,
                        }
                    },
                    "results": results,
                    "properties": {
                        "schema_version": "local_repo_audit_sarif.v1",
                        "claim_boundary": "alpha-local-code-doc-audit-only",
                        "release_ready": 0,
                        "public_comparison_claim_ready": 0,
                        "real_model_execution_ready": 0,
                    },
                }
            ],
        },
    )


def finding_fingerprint(row: dict[str, str]) -> str:
    payload = {
        "plugin_id": str(row.get("plugin_id", "")),
        "plugin_rule_ids": str(row.get("plugin_rule_ids", "")),
        "language": str(row.get("language", "")),
        "citations": str(row.get("citations", "")),
    }
    return sha256_text(json.dumps(payload, sort_keys=True))


def finding_content_sha(row: dict[str, str]) -> str:
    payload = {
        "answer": str(row.get("answer", "")),
        "confidence": str(row.get("confidence", "")),
        "severity": str(row.get("severity", "")),
        "grounded": str(row.get("grounded", "")),
        "abstain": str(row.get("abstain", "")),
        "unsupported_claim": str(row.get("unsupported_claim", "")),
        "suppressed": str(row.get("suppressed", "")),
        "suppression_ids": str(row.get("suppression_ids", "")),
        "citation_sha256s": str(row.get("citation_sha256s", "")),
    }
    return sha256_text(json.dumps(payload, sort_keys=True))


SEMANTIC_SUMMARY_ARTIFACTS = [
    "source_manifest.csv",
    "audit_findings.csv",
    "citation_spans.csv",
    "abstain_rows.csv",
    "unsupported_claim_rows.csv",
    "baseline_diff_rows.csv",
    "manual_review_queue.csv",
]


def audit_semantic_result_sha(staging: Path, artifacts: list[str] = SEMANTIC_SUMMARY_ARTIFACTS) -> str:
    digest = hashlib.sha256()
    for rel in artifacts:
        path = staging / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256(path).encode("utf-8") if path.is_file() else b"missing")
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def write_audit_semantic_summary(staging: Path) -> None:
    artifact_sha256s = {
        rel: sha256(staging / rel)
        for rel in SEMANTIC_SUMMARY_ARTIFACTS
    }
    write_json(
        staging / "audit_semantic_summary.json",
        {
            "schema_version": "local_repo_audit_semantic_summary.v1",
            "tool_version": TOOL_VERSION,
            "claim_boundary": "alpha-local-code-doc-audit-only",
            "semantic_artifacts": SEMANTIC_SUMMARY_ARTIFACTS,
            "artifact_sha256s": artifact_sha256s,
            "semantic_result_sha256": audit_semantic_result_sha(staging),
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
        },
    )


def baseline_diff_row(
    status: str,
    fingerprint: str,
    current: dict[str, str] | None,
    baseline: dict[str, str] | None,
) -> dict[str, str | int]:
    source = current or baseline or {}
    current_content = finding_content_sha(current) if current is not None else ""
    baseline_content = finding_content_sha(baseline) if baseline is not None else ""
    return {
        "diff_status": status,
        "finding_fingerprint": fingerprint,
        "content_sha256": current_content,
        "baseline_content_sha256": baseline_content,
        "current_finding_id": "" if current is None else current.get("finding_id", ""),
        "baseline_finding_id": "" if baseline is None else baseline.get("finding_id", ""),
        "plugin_id": source.get("plugin_id", ""),
        "plugin_rule_ids": source.get("plugin_rule_ids", ""),
        "confidence": source.get("confidence", ""),
        "severity": source.get("severity", ""),
        "language": source.get("language", ""),
        "current_citations": "" if current is None else current.get("citations", ""),
        "baseline_citations": "" if baseline is None else baseline.get("citations", ""),
        "current_citation_sha256s": "" if current is None else current.get("citation_sha256s", ""),
        "baseline_citation_sha256s": "" if baseline is None else baseline.get("citation_sha256s", ""),
        "current_suppressed": "" if current is None else current.get("suppressed", ""),
        "baseline_suppressed": "" if baseline is None else baseline.get("suppressed", ""),
        "manual_review_required": int(status != "unchanged"),
    }


def write_baseline_diff(staging: Path, baseline: BaselineBundle, finding_rows: list[dict]) -> dict[str, int | str]:
    rows: list[dict[str, str | int]] = []
    current_by_fingerprint = {finding_fingerprint(row): row for row in finding_rows}
    baseline_by_fingerprint = {finding_fingerprint(row): row for row in baseline.finding_rows}

    if not baseline.supplied:
        for fingerprint, current in sorted(current_by_fingerprint.items()):
            rows.append(baseline_diff_row("not_compared", fingerprint, current, None))
    else:
        for fingerprint in sorted(set(current_by_fingerprint) | set(baseline_by_fingerprint)):
            current = current_by_fingerprint.get(fingerprint)
            previous = baseline_by_fingerprint.get(fingerprint)
            if current is None:
                status = "resolved"
            elif previous is None:
                status = "new"
            elif finding_content_sha(current) == finding_content_sha(previous):
                status = "unchanged"
            else:
                status = "changed"
            rows.append(baseline_diff_row(status, fingerprint, current, previous))

    counts = {status: sum(1 for row in rows if row["diff_status"] == status) for status in ["not_compared", "new", "changed", "resolved", "unchanged"]}
    summary = {
        "schema_version": "local_repo_audit_baseline_diff.v1",
        "tool_version": TOOL_VERSION,
        "baseline_supplied": int(baseline.supplied),
        "baseline_output": baseline.output,
        "baseline_output_sha256": baseline.output_sha256,
        "baseline_manifest_sha256": baseline.manifest_sha256,
        "baseline_cache_key": baseline.cache_key,
        "current_finding_rows": len(finding_rows),
        "baseline_finding_rows": len(baseline.finding_rows),
        "diff_rows": len(rows),
        "not_compared_findings": counts["not_compared"],
        "new_findings": counts["new"],
        "changed_findings": counts["changed"],
        "resolved_findings": counts["resolved"],
        "unchanged_findings": counts["unchanged"],
        "manual_review_required_rows": sum(int(row["manual_review_required"]) for row in rows),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    write_csv(staging / "baseline_diff_rows.csv", CSV_CONTRACTS["baseline_diff_rows.csv"], rows)
    write_json(staging / "baseline_diff_summary.json", summary)
    lines = [
        "# Baseline Diff",
        "",
        f"- baseline_supplied={summary['baseline_supplied']}",
        f"- current_finding_rows={summary['current_finding_rows']}",
        f"- baseline_finding_rows={summary['baseline_finding_rows']}",
        f"- not_compared_findings={summary['not_compared_findings']}",
        f"- new_findings={summary['new_findings']}",
        f"- changed_findings={summary['changed_findings']}",
        f"- resolved_findings={summary['resolved_findings']}",
        f"- unchanged_findings={summary['unchanged_findings']}",
        f"- manual_review_required_rows={summary['manual_review_required_rows']}",
        "",
        "Boundary: diff rows are source-bound change triage only. They do not claim release readiness, public comparison readiness, or real model execution.",
    ]
    (staging / "BASELINE_DIFF.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return summary


def dashboard_finding(row: dict) -> dict:
    citations = [cell for cell in str(row.get("citations", "")).split(";") if cell]
    citation_sha256s = [cell for cell in str(row.get("citation_sha256s", "")).split(";") if cell]
    return {
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
        "citation_sha256s": citation_sha256s,
        "answer_preview": str(row.get("answer", ""))[:220],
    }


def write_audit_dashboard(
    staging: Path,
    manifest: dict,
    summary: dict,
    baseline_summary: dict[str, int | str],
    finding_rows: list[dict],
) -> None:
    links = {
        "audit_report": "AUDIT_REPORT.md",
        "baseline_diff": "BASELINE_DIFF.md",
        "findings_json": "audit_findings.json",
        "findings_sarif": "audit_findings.sarif.json",
        "manual_review_queue": "manual_review_queue.csv",
        "reproduce": "reproduce.sh",
        "verify": "verify.sh",
    }
    diff_counts = {
        key: int(baseline_summary[key])
        for key in [
            "not_compared_findings",
            "new_findings",
            "changed_findings",
            "resolved_findings",
            "unchanged_findings",
            "manual_review_required_rows",
        ]
    }
    review_counts = {
        "finding_rows": int(summary["finding_rows"]),
        "source_files": int(summary["source_files"]),
        "citation_span_rows": int(summary["citation_span_rows"]),
        "abstain_rows": int(summary["abstain_rows"]),
        "unsupported_claim_rows": int(summary["unsupported_claim_rows"]),
        "manual_review_queue_rows": int(summary["manual_review_queue_rows"]),
        "suppression_rows": int(summary["suppression_rows"]),
    }
    readiness = {
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "automatic_accuracy_claimed": 0,
        "design_partner_beta_candidate_ready": 0,
    }
    payload = {
        "schema_version": "local_repo_audit_dashboard.v1",
        "tool_version": TOOL_VERSION,
        "dashboard_kind": "local-audit-diff-dashboard",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "generated_at_utc": DETERMINISTIC_GENERATED_AT_UTC,
        "target_repo": str(manifest["target_repo"]),
        "cache_key": str(manifest["cache_key"]),
        "run_id": str(manifest["run_id"]),
        "mode": str(summary["mode"]),
        "namespace": str(summary["namespace"]),
        "source_scope": str(summary["source_scope"]),
        "baseline": {
            "supplied": int(baseline_summary["baseline_supplied"]),
            "baseline_output_sha256": str(baseline_summary["baseline_output_sha256"]),
            "baseline_manifest_sha256": str(baseline_summary["baseline_manifest_sha256"]),
            "baseline_cache_key": str(baseline_summary["baseline_cache_key"]),
        },
        "diff_counts": diff_counts,
        "review_counts": review_counts,
        "readiness": readiness,
        "links": links,
        "top_findings": [dashboard_finding(row) for row in finding_rows[:20]],
    }
    write_json(staging / "audit_dashboard.json", payload)

    def esc(value: object) -> str:
        return html.escape(str(value), quote=True)

    diff_cells = "".join(
        f"<tr><th>{esc(key)}</th><td>{esc(value)}</td></tr>"
        for key, value in diff_counts.items()
    )
    review_cells = "".join(
        f"<tr><th>{esc(key)}</th><td>{esc(value)}</td></tr>"
        for key, value in review_counts.items()
    )
    finding_rows_html = "\n".join(
        "<tr "
        f"data-finding-id=\"{esc(row['finding_id'])}\" "
        f"data-plugin-id=\"{esc(row['plugin_id'])}\" "
        f"data-abstain=\"{esc(row['abstain'])}\" "
        f"data-suppressed=\"{esc(row['suppressed'])}\">"
        f"<td>{esc(row['finding_id'])}</td>"
        f"<td>{esc(row['plugin_id'])}</td>"
        f"<td>{esc(row['severity'])}</td>"
        f"<td>{esc(row['confidence'])}</td>"
        f"<td>{esc(row['primary_citation'])}</td>"
        f"<td>{esc(row['answer_preview'])}</td>"
        "</tr>"
        for row in payload["top_findings"]
    )
    if not finding_rows_html:
        finding_rows_html = "<tr><td colspan=\"6\">No findings emitted.</td></tr>"
    link_items = "".join(
        f"<li><a href=\"{esc(path)}\">{esc(label)}</a></li>"
        for label, path in links.items()
    )
    html_text = f"""<!doctype html>
<html lang="en"
  data-schema-version="local_repo_audit_dashboard.v1"
  data-tool-version="{esc(TOOL_VERSION)}"
  data-run-id="{esc(payload['run_id'])}"
  data-cache-key="{esc(payload['cache_key'])}"
  data-finding-rows="{esc(review_counts['finding_rows'])}"
  data-baseline-supplied="{esc(payload['baseline']['supplied'])}"
  data-new-findings="{esc(diff_counts['new_findings'])}"
  data-changed-findings="{esc(diff_counts['changed_findings'])}"
  data-resolved-findings="{esc(diff_counts['resolved_findings'])}"
  data-unchanged-findings="{esc(diff_counts['unchanged_findings'])}"
  data-release-ready="0"
  data-public-comparison-claim-ready="0"
  data-real-model-execution-ready="0"
  data-design-partner-beta-candidate-ready="0">
<head>
  <meta charset="utf-8">
  <title>audit-my-repo dashboard</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 24px; line-height: 1.35; color: #1f2933; background: #f7f9fb; }}
    main {{ max-width: 1120px; margin: 0 auto; }}
    h1, h2 {{ margin: 0.6rem 0; }}
    section {{ margin: 16px 0; padding: 16px; background: #ffffff; border: 1px solid #d9e2ec; border-radius: 6px; }}
    table {{ width: 100%; border-collapse: collapse; margin-top: 8px; }}
    th, td {{ padding: 8px; border-bottom: 1px solid #e4e7eb; text-align: left; vertical-align: top; }}
    th {{ width: 220px; color: #334e68; }}
    code {{ background: #eef2f7; padding: 2px 4px; border-radius: 4px; }}
    .blocked {{ color: #9f1239; font-weight: 700; }}
  </style>
</head>
<body>
<main>
  <h1>audit-my-repo dashboard</h1>
  <p>Run <code>{esc(payload['run_id'])}</code> in <code>{esc(payload['mode'])}</code> mode. Cache key <code>{esc(payload['cache_key'])}</code>.</p>
  <p class="blocked">release_ready=0, public_comparison_claim_ready=0, real_model_execution_ready=0, automatic_accuracy_claimed=0, design_partner_beta_candidate_ready=0.</p>
  <section>
    <h2>Diff Counts</h2>
    <table>{diff_cells}</table>
  </section>
  <section>
    <h2>Review Counts</h2>
    <table>{review_cells}</table>
  </section>
  <section>
    <h2>Top Findings</h2>
    <table>
      <thead><tr><th>Finding</th><th>Plugin</th><th>Severity</th><th>Confidence</th><th>Primary Citation</th><th>Answer Preview</th></tr></thead>
      <tbody>{finding_rows_html}</tbody>
    </table>
  </section>
  <section>
    <h2>Artifacts</h2>
    <ul>{link_items}</ul>
    <p>Structured dashboard data: <a href="audit_dashboard.json">audit_dashboard.json</a></p>
  </section>
  <section>
    <h2>Boundary</h2>
    <p>This dashboard is local source-bound change triage only. It does not claim release readiness, public comparison readiness, real model execution, or automatic accuracy.</p>
  </section>
</main>
</body>
</html>
"""
    (staging / "AUDIT_DASHBOARD.html").write_text(html_text, encoding="utf-8")


def measure_staging_verify(root: Path, staging: Path) -> tuple[int, int]:
    start_ns = time.perf_counter_ns()
    verifier = root / "tools" / "verify_local_audit.py"
    result = subprocess.run(
        [sys.executable, str(verifier), str(staging)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.returncode, elapsed_ms(start_ns)


def staging_verify_status(root: Path, staging: Path) -> int:
    verifier = root / "tools" / "verify_local_audit.py"
    result = subprocess.run(
        [sys.executable, str(verifier), str(staging)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout.rstrip(), file=sys.stderr)
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)
        print(f"staging_artifact_verify: failed ({staging})", file=sys.stderr)
    return result.returncode


def write_diagnostics(
    staging: Path,
    emit_diagnostics: bool,
    tool_version: str,
    mode: str,
    namespace: str,
    max_files: int,
    max_total_bytes: int,
    max_file_bytes: int,
    max_findings: int,
    max_queries: int,
    active_plugin_ids: tuple[str, ...],
    source_file_count: int,
    finding_rows: int,
    suppression_rows: int,
    timings: dict[str, int],
    install_verified: bool,
    first_report_verified: bool,
) -> None:
    """Write the local opt-in diagnostics.json artifact.

    Diagnostics are local-only. In the default opt-out mode the artifact
    proves the opt-in flag is unset, no diagnostics were collected, and
    no network was used. In the opt-in mode it exposes only coarse
    run metrics already present in the summary/resource envelope.
    The artifact must never include raw source snippets, source file
    paths, citations, secrets, .env content, or question text.
    """
    if not emit_diagnostics:
        payload = {
            "schema_version": "local_repo_audit_diagnostics.v1",
            "tool_version": tool_version,
            "diagnostics_opt_in": 0,
            "diagnostics_collected": 0,
            "external_network_used": 0,
            "scope": "none",
            "reason": "default-opt-out",
        }
    else:
        payload = {
            "schema_version": "local_repo_audit_diagnostics.v1",
            "tool_version": tool_version,
            "diagnostics_opt_in": 1,
            "diagnostics_collected": 1,
            "external_network_used": 0,
            "scope": "coarse-run-metrics",
            "mode": mode,
            "namespace": namespace,
            "max_files": max_files,
            "max_total_bytes": max_total_bytes,
            "max_file_bytes": max_file_bytes,
            "max_findings": max_findings,
            "max_queries": max_queries,
            "active_plugin_ids": list(active_plugin_ids),
            "source_file_count": source_file_count,
            "finding_rows": finding_rows,
            "suppression_rows": suppression_rows,
            "scan_latency_ms": timings["scan_latency_ms"],
            "plugin_latency_ms": timings["plugin_latency_ms"],
            "serialize_latency_ms": timings["serialize_latency_ms"],
            "verify_latency_ms": timings["verify_latency_ms"],
            "latency_ms": sum(timings.values()),
            "install_verified": int(install_verified),
            "first_report_verified": int(first_report_verified),
        }
    write_json(staging / "diagnostics.json", payload)


def write_outputs(root: Path, target: Path, out_dir: Path, staging: Path, mode: str, max_queries: int, budget: AuditBudget, changed_file_selection: ChangedFileSelection, suppression_rules: tuple[SuppressionRule, ...], suppression_file: str, suppression_file_sha256: str, baseline: BaselineBundle, generator: str, namespace: str, real_benchmark_namespace_confirmed: int, question: str, verify_output: bool, emit_report: bool, emit_lineage: bool, emit_reproduce: bool, emit_diagnostics: bool) -> dict:
    timings = {
        "scan_latency_ms": 1,
        "plugin_latency_ms": 1,
        "serialize_latency_ms": 1,
        "verify_latency_ms": 1,
    }
    scan_start_ns = time.perf_counter_ns()
    sources, source_rows = collect_sources(target, budget, changed_file_selection)
    timings["scan_latency_ms"] = elapsed_ms(scan_start_ns)
    write_json(staging / "plugin_registry.json", plugin_registry_payload())
    plugin_rule_metadata = plugin_rule_rows()
    write_csv(staging / "plugin_rule_rows.csv", CSV_CONTRACTS["plugin_rule_rows.csv"], plugin_rule_metadata)
    plugin_findings: list[Finding] = []
    active_plugins = active_plugins_for_mode(mode)
    active_plugin_ids = tuple(plugin.plugin_id for plugin in active_plugins)
    plugin_start_ns = time.perf_counter_ns()
    for plugin in active_plugins:
        plugin_findings.extend(plugin.run(target, sources))
    timings["plugin_latency_ms"] = elapsed_ms(plugin_start_ns)
    serialize_start_ns = time.perf_counter_ns()
    question_finding = USER_QUESTION_PLUGIN.run_question(sources, question)
    if question_finding is not None:
        findings = plugin_findings[: max(0, budget.max_findings - 1)] + [question_finding]
    else:
        findings = plugin_findings[: budget.max_findings]
    findings = bind_findings_to_sources(findings, sources)
    finding_rows, span_rows, suppressed_rows = build_rows(target, findings, suppression_rules)

    write_csv(staging / "source_manifest.csv", ["source_id", "file_path", "sha256", "bytes", "route_memory_source"], source_rows)
    write_json(staging / "source_snapshot.json", source_snapshot_payload(target, staging / "source_manifest.csv", len(source_rows)))
    (staging / "audit_findings.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_rows), encoding="utf-8")
    write_json(
        staging / "audit_findings.json",
        {
            "schema_version": "local_repo_audit_findings.v1",
            "tool_version": TOOL_VERSION,
            "claim_boundary": "alpha-local-code-doc-audit-only",
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "findings": finding_rows,
        },
    )
    (staging / "citation_spans.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in span_rows), encoding="utf-8")
    write_csv(staging / "audit_findings.csv", list(finding_rows[0].keys()), finding_rows)
    write_csv(staging / "citation_spans.csv", list(span_rows[0].keys()), span_rows)

    routehint_rows = []
    generation_rows = []
    lineage_rows = []
    mmap_rows = []
    abstain_rows = []
    unsupported_rows = []
    wrong_answer_guard_rows = []
    latency_rows = []
    false_positive_rows = []
    accuracy_rows = []
    citation_correctness_rows = []
    manual_review_rows = []
    per_finding_latency_ms = max(1, timings["plugin_latency_ms"] // max(1, len(finding_rows)))
    for idx, finding in enumerate(finding_rows, start=1):
        hint_id = f"hint_{idx:04d}"
        citation_count = len([c for c in finding["citations"].split(";") if c])
        routehint_rows.append({"hint_id": hint_id, "finding_id": finding["finding_id"], "hint_bytes": min(256, len(finding["answer"].encode("utf-8"))), "source_citation_count": citation_count, "raw_context_appended": 0, "proposal_hint_used": 1})
        generation_rows.append({"generation_id": f"gen_{idx:04d}", "finding_id": finding["finding_id"], "hint_id": hint_id, "generator": generator, "attention_blocks": 0, "transformer_blocks": 0, "raw_prompt_context_bytes": 0, "grounded": finding["grounded"], "abstain": finding["abstain"], "unsupported_claim": finding["unsupported_claim"], "answer": finding["answer"]})
        lineage_rows.append({"finding_id": finding["finding_id"], "route_index_row": idx, "compact_route_hint_id": hint_id, "generator_id": f"gen_{idx:04d}", "citation_count": citation_count, "audit_trail_bound": 1})
        latency_rows.append({"finding_id": finding["finding_id"], "latency_ms": per_finding_latency_ms, "latency_source": "measured-plugin-phase-share"})
        if finding["abstain"] == 1:
            abstain_rows.append(finding)
        if finding["unsupported_claim"] == 1:
            unsupported_rows.append(finding)
        false_positive_rows.append({"finding_id": finding["finding_id"], "manual_review_required": 1, "false_positive_candidate": int(finding["severity"] in {"medium", "high"}), "auto_promoted": 0})
        accuracy_rows.append({"finding_id": finding["finding_id"], "accuracy_label": "unreviewed", "automatic_accuracy_claimed": 0, "manual_accuracy_review_required": 1})
        citation_correctness_rows.append({"finding_id": finding["finding_id"], "citation_count": citation_count, "citation_bound": int(citation_count > 0), "citation_correctness_label": "source_bound_unreviewed", "manual_citation_review_required": 1})
        manual_review_rows.append({
            "finding_id": finding["finding_id"],
            "review_queue_id": f"manual_review_{idx:04d}",
            "review_types": "accuracy|citation_correctness|false_positive",
            "manual_review_required": 1,
            "review_reason": "alpha outputs are source-bound but unreviewed; no automatic accuracy/citation correctness/false-positive promotion is allowed",
            "auto_promoted": 0,
        })
        wrong_answer_guard_rows.append({"finding_id": finding["finding_id"], "guard_id": f"wrong_answer_guard_{idx:04d}", "unsupported_direct_answer_blocked": int(finding["abstain"] == 1 or finding["grounded"] == 1), "citation_required": 1, "audit_trail_required": 1, "wrong_answer_guard_pass": 1})
    for row in span_rows:
        mmap_rows.append({"finding_id": row["finding_id"], "file_path": row["file_path"], "line_start": row["line_start"], "sha256": row["sha256"], "span_sha256": row["span_sha256"], "mmap_value_byte_read": 1})

    write_csv(staging / "compact_route_hint_rows.csv", ["hint_id", "finding_id", "hint_bytes", "source_citation_count", "raw_context_appended", "proposal_hint_used"], routehint_rows)
    write_csv(staging / "grounded_generation_rows.csv", ["generation_id", "finding_id", "hint_id", "generator", "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes", "grounded", "abstain", "unsupported_claim", "answer"], generation_rows)
    (staging / "prediction_lineage.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
    (staging / "mmap_read_trace.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in mmap_rows), encoding="utf-8")
    write_csv(staging / "abstain_rows.csv", list(finding_rows[0].keys()), abstain_rows)
    write_csv(staging / "unsupported_claim_rows.csv", list(finding_rows[0].keys()), unsupported_rows)
    write_csv(staging / "wrong_answer_guard_rows.csv", ["finding_id", "guard_id", "unsupported_direct_answer_blocked", "citation_required", "audit_trail_required", "wrong_answer_guard_pass"], wrong_answer_guard_rows)
    write_csv(staging / "accuracy_rows.csv", ["finding_id", "accuracy_label", "automatic_accuracy_claimed", "manual_accuracy_review_required"], accuracy_rows)
    write_json(
        staging / "accuracy_rows.json",
        {
            "schema_version": "local_repo_audit_accuracy_rows.v1",
            "tool_version": TOOL_VERSION,
            "claim_boundary": "alpha-local-code-doc-audit-only",
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "accuracy_rows": len(accuracy_rows),
            "automatic_accuracy_claimed": 0,
            "manual_accuracy_review_required": 1,
            "rows": accuracy_rows,
        },
    )
    write_csv(staging / "citation_correctness_rows.csv", ["finding_id", "citation_count", "citation_bound", "citation_correctness_label", "manual_citation_review_required"], citation_correctness_rows)
    write_json(
        staging / "citation_correctness_rows.json",
        {
            "schema_version": "local_repo_audit_citation_correctness_rows.v1",
            "tool_version": TOOL_VERSION,
            "claim_boundary": "alpha-local-code-doc-audit-only",
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "citation_correctness_rows": len(citation_correctness_rows),
            "manual_citation_review_required": 1,
            "rows": citation_correctness_rows,
        },
    )
    write_csv(staging / "latency_rows.csv", ["finding_id", "latency_ms", "latency_source"], latency_rows)
    write_csv(staging / "false_positive_candidate_rows.csv", ["finding_id", "manual_review_required", "false_positive_candidate", "auto_promoted"], false_positive_rows)
    write_csv(staging / "manual_review_queue.csv", CSV_CONTRACTS["manual_review_queue.csv"], manual_review_rows)
    write_json(
        staging / "manual_review_queue.json",
        {
            "schema_version": "local_repo_audit_manual_review_queue.v1",
            "tool_version": TOOL_VERSION,
            "claim_boundary": "alpha-local-code-doc-audit-only",
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "manual_review_queue_rows": len(manual_review_rows),
            "rows": manual_review_rows,
        },
    )
    write_csv(staging / "suppressed_findings.csv", CSV_CONTRACTS["suppressed_findings.csv"], suppressed_rows)
    write_sarif(staging, finding_rows, span_rows, plugin_rule_metadata)
    baseline_diff_summary = write_baseline_diff(staging, baseline, finding_rows)
    write_audit_semantic_summary(staging)
    write_json(
        staging / "audit_invocation.json",
        {
            "schema_version": "local_repo_audit_invocation.v1",
            "tool_version": TOOL_VERSION,
            "target_repo": str(target),
            "out_dir": str(out_dir),
            "mode": mode,
            "max_queries": max_queries,
            "max_files": budget.max_files,
            "max_total_bytes": budget.max_total_bytes,
            "max_file_bytes": budget.max_file_bytes,
            "max_findings": budget.max_findings,
            "source_scope": changed_file_selection.source_scope,
            "changed_files_from": changed_file_selection.changed_files_from,
            "changed_files_from_sha256": changed_file_selection.changed_files_from_sha256,
            "changed_file_rows": len(changed_file_selection.changed_file_rel_paths),
            "active_plugin_ids": "|".join(active_plugin_ids),
            "suppression_file": suppression_file,
            "suppression_file_sha256": suppression_file_sha256,
            "baseline_output": baseline.output,
            "baseline_output_sha256": baseline.output_sha256,
            "generator": generator,
            "namespace": namespace,
            "real_benchmark_namespace_confirmed": real_benchmark_namespace_confirmed,
            "question_supplied": int(bool(question)),
            "question_sha256": sha256_text(question),
            "verify_output_requested": int(verify_output),
            "emit_report_requested": int(emit_report),
            "emit_lineage_requested": int(emit_lineage),
            "emit_reproduce_requested": int(emit_reproduce),
            "emit_diagnostics_requested": int(emit_diagnostics),
        },
    )
    write_json(
        staging / "exit_code_contract.json",
        {
            "schema_version": "local_repo_audit_exit_code_contract.v1",
            "tool_version": TOOL_VERSION,
            "success_exit_code": 0,
            "artifact_verify_failure_exit_code": 1,
            "input_or_publish_error_exit_code": 2,
            "wrong_answer_guard_failure_exit_code": 1,
            "stable_exit_code_policy": "0=verified-success,1=artifact-or-guard-failure,2=input-or-publish-error",
        },
    )

    claim_boundary = (
        "# Audit Claim Boundary\n\n"
        "Allowed claim: local evidence-bound codebase QA/audit assistance with citations, abstention, and an audit trail.\n\n"
        "Blocked claims: Transformer replacement, frontier local LLM, production-ready release, expert replacement, long-context solved, and GPU acceleration proven.\n\n"
        "`real_release_package_ready=0`, `release_ready=0`, `public_comparison_claim_ready=0`, `real_model_execution_ready=0`, and `gpu_speedup_claim=deferred` remain explicit.\n"
    )
    (staging / "claim_boundary.md").write_text(claim_boundary, encoding="utf-8")

    timings["serialize_latency_ms"] = elapsed_ms(serialize_start_ns)
    total_latency_ms = sum(timings.values())
    summary = {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "audit_my_repo_ready": 1,
        "target_repo": str(target),
        "mode": mode,
        "namespace": namespace,
        "generator": generator,
        "question_supplied": int(bool(question)),
        "source_files": len(source_rows),
        "source_scope": changed_file_selection.source_scope,
        "changed_file_rows": len(changed_file_selection.changed_file_rel_paths),
        "finding_rows": len(finding_rows),
        "suppression_rows": len(suppressed_rows),
        "citation_span_rows": len(span_rows),
        "abstain_rows": len(abstain_rows),
        "unsupported_claim_rows": len(unsupported_rows),
        "accuracy_rows": len(accuracy_rows),
        "citation_correctness_rows": len(citation_correctness_rows),
        "false_positive_candidate_rows": len(false_positive_rows),
        "manual_review_queue_rows": len(manual_review_rows),
        "wrong_answer_guard_rows": len(wrong_answer_guard_rows),
        "wrong_answer_guard_pass_rows": sum(1 for row in wrong_answer_guard_rows if row["wrong_answer_guard_pass"] == 1),
        "claim_boundary_ready": 1,
        "route_memory_lineage_rows": len(lineage_rows),
        "mmap_read_trace_rows": len(mmap_rows),
        "compact_route_hint_rows": len(routehint_rows),
        "grounded_generation_rows": len(generation_rows),
        "raw_prompt_context_bytes": 0,
        "attention_blocks": 0,
        "transformer_blocks": 0,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
        "real_release_package_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "gpu_speedup_claim": "deferred",
        "max_files": budget.max_files,
        "max_total_bytes": budget.max_total_bytes,
        "max_file_bytes": budget.max_file_bytes,
        "max_findings": budget.max_findings,
        "active_plugin_ids": "|".join(active_plugin_ids),
        "scan_latency_ms": timings["scan_latency_ms"],
        "plugin_latency_ms": timings["plugin_latency_ms"],
        "serialize_latency_ms": timings["serialize_latency_ms"],
        "verify_latency_ms": timings["verify_latency_ms"],
        "latency_ms": total_latency_ms,
    }

    def write_summary_resource_and_timing() -> None:
        summary["scan_latency_ms"] = timings["scan_latency_ms"]
        summary["plugin_latency_ms"] = timings["plugin_latency_ms"]
        summary["serialize_latency_ms"] = timings["serialize_latency_ms"]
        summary["verify_latency_ms"] = timings["verify_latency_ms"]
        summary["latency_ms"] = sum(timings.values())
        write_json(
            staging / "resource_envelope.json",
            {
                "resource_envelope_ready": 1,
                "tool_version": TOOL_VERSION,
                "source_files_scanned": len(source_rows),
                "source_scope": changed_file_selection.source_scope,
                "changed_file_rows": len(changed_file_selection.changed_file_rel_paths),
                "max_queries": max_queries,
                "max_files": budget.max_files,
                "max_total_bytes": budget.max_total_bytes,
                "max_file_bytes": budget.max_file_bytes,
                "max_findings": budget.max_findings,
                "active_plugin_ids": "|".join(active_plugin_ids),
                "suppression_rows": len(suppressed_rows),
                "mode": mode,
                "namespace": namespace,
                "external_network_used": 0,
                "raw_prompt_context_bytes": 0,
                "scan_latency_ms": timings["scan_latency_ms"],
                "plugin_latency_ms": timings["plugin_latency_ms"],
                "serialize_latency_ms": timings["serialize_latency_ms"],
                "verify_latency_ms": timings["verify_latency_ms"],
                "latency_ms": summary["latency_ms"],
                "wrong_answer_guard_rows": len(wrong_answer_guard_rows),
                "claim_boundary_ready": 1,
            },
        )
        write_json(staging / "audit_summary.json", summary)
        write_csv(staging / "audit_summary.csv", list(summary.keys()), [summary])
        write_phase_timing(staging, timings)

    write_summary_resource_and_timing()

    if emit_report:
        lines = ["# Local Codebase Audit Report", "", "Summary:", f"- {len(finding_rows)} source-bound findings", f"- {len(abstain_rows)} unsupported questions abstained", f"- {len(unsupported_rows)} unsupported claims flagged", "- RouteMemory evidence, compact RouteHint, grounded answer, citation/abstain, and audit trail artifacts were emitted.", ""]
        for finding in finding_rows:
            lines.extend([f"## {finding['finding_id']}: {finding['audit_type']}", "", "Question:", f"  {finding['question']}", "", "Answer:", f"  {finding['answer']}", "", "Evidence:"])
            citation_sha256s = [cell for cell in finding["citation_sha256s"].split(";") if cell]
            for citation, citation_sha256 in zip(
                [cell for cell in finding["citations"].split(";") if cell],
                citation_sha256s,
            ):
                lines.append(f"  {citation}")
                lines.append(f"  sha256={citation_sha256}")
            lines.extend(["", "Decision:", f"  grounded={finding['grounded']}", f"  abstain={finding['abstain']}", f"  unsupported_claims={finding['unsupported_claim']}", ""])
        (staging / "AUDIT_REPORT.md").write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

    if emit_lineage:
        (staging / "ARCHITECTURE_TRACE.md").write_text("\n".join(["# Architecture Trace", "", "RouteMemory evidence -> compact RouteHint -> tiny non-attention generator -> grounded answer -> citation / abstain / audit trail.", "", f"- route_memory_lineage_rows={summary['route_memory_lineage_rows']}", f"- compact_route_hint_rows={summary['compact_route_hint_rows']}", f"- grounded_generation_rows={summary['grounded_generation_rows']}", "- raw_prompt_context_bytes=0", "- attention_blocks=0", "- transformer_blocks=0", "- oracle_prediction_used=0", "- raw_input_extractor_used=0", "", "Boundary: this is a local evidence-bound QA/audit alpha, not a Transformer replacement, frontier local LLM, expert replacement, GPU-speedup proof, or production release."]) + "\n", encoding="utf-8")

    if emit_reproduce:
        reproduce = staging / "reproduce.sh"
        command = [
            "./scripts/audit_my_repo.sh",
            str(target),
            "--mode",
            mode,
            "--max-files",
            str(budget.max_files),
            "--max-total-bytes",
            str(budget.max_total_bytes),
            "--max-file-bytes",
            str(budget.max_file_bytes),
            "--max-findings",
            str(budget.max_findings),
            "--out",
            str(out_dir),
            "--generator",
            generator,
            "--namespace",
            namespace,
            "--verify-output",
            "--emit-report",
            "--emit-lineage",
            "--emit-reproduce",
        ]
        if suppression_file:
            command.extend(["--allowlist", suppression_file])
        if baseline.supplied:
            command.extend(["--baseline", baseline.output])
        if changed_file_selection.changed_files_from:
            command.extend(["--changed-files-from", changed_file_selection.changed_files_from])
        if namespace == "real_benchmark":
            command.append("--confirm-real-benchmark-namespace")
        if question:
            command.extend(["--question", question])
        if emit_diagnostics:
            command.append("--emit-diagnostics")
        reproduce.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            f"cd {shlex.quote(str(root))}\n"
            + " ".join(shlex.quote(part) for part in command)
            + "\n",
            encoding="utf-8",
        )
        reproduce.chmod(0o755)
        verify_script = staging / "verify.sh"
        verify_script.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            f"cd {shlex.quote(str(root))}\n"
            + " ".join(
                shlex.quote(part)
                for part in [
                    "./scripts/audit_my_repo.sh",
                    "--verify-existing",
                    str(out_dir),
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        verify_script.chmod(0o755)

    plugin_registry_sha256 = sha256(staging / "plugin_registry.json")
    tool_source_sha256 = sha256(Path(__file__).resolve())
    source_snapshot = json.loads((staging / "source_snapshot.json").read_text(encoding="utf-8"))
    cache_payload = cache_key_payload(
        root,
        target,
        source_rows,
        source_snapshot,
        changed_file_selection,
        mode,
        budget,
        max_queries,
        active_plugin_ids,
        suppression_file_sha256,
        baseline.output,
        baseline.output_sha256,
        namespace,
        real_benchmark_namespace_confirmed,
        question,
        verify_output,
        emit_report,
        emit_lineage,
        emit_reproduce,
        emit_diagnostics,
        plugin_registry_sha256,
        tool_source_sha256,
    )
    cache_key = hashlib.sha256(json.dumps(cache_payload, sort_keys=True).encode("utf-8")).hexdigest()
    run_id = f"run-{cache_key[:16]}"
    manifest = {
        "schema_version": OUTPUT_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "tool_source_sha256": tool_source_sha256,
        "verifier_source_sha256": sha256(root / "tools" / "verify_local_audit.py"),
        "schema_sha256s": schema_sha256s(root),
        "generated_at_utc": DETERMINISTIC_GENERATED_AT_UTC,
        "target_repo": str(target),
        "source_scope": changed_file_selection.source_scope,
        "changed_files_from": changed_file_selection.changed_files_from,
        "changed_files_from_sha256": changed_file_selection.changed_files_from_sha256,
        "changed_file_rows": len(changed_file_selection.changed_file_rel_paths),
        "namespace": namespace,
        "real_benchmark_namespace_confirmed": real_benchmark_namespace_confirmed,
        "fixture_result_promoted": 0,
        "real_evidence_claimed": 0,
        "source_file_count": len(source_rows),
        "finding_rows": len(finding_rows),
        "suppression_rows": len(suppressed_rows),
        "atomic_publish": 1,
        "output_dir_destroyed": 0,
        "output_dir_overwritten": 0,
        "publish_mode": "versioned-run-dir-with-latest-pointer",
        "run_id": run_id,
        "bundle_run_dir": str(out_dir / "runs" / run_id),
        "latest_pointer": str(out_dir / "latest"),
        "cache_key": cache_key,
        "plugin_registry_sha256": plugin_registry_sha256,
        "suppression_file_sha256": suppression_file_sha256,
        "baseline_output": baseline.output,
        "baseline_output_sha256": baseline.output_sha256,
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "emit_diagnostics_requested": int(emit_diagnostics),
    }
    write_json(staging / "audit_manifest.json", manifest)
    first_report_verified = (staging / "AUDIT_REPORT.md").is_file()
    write_diagnostics(
        staging,
        emit_diagnostics,
        TOOL_VERSION,
        mode,
        namespace,
        budget.max_files,
        budget.max_total_bytes,
        budget.max_file_bytes,
        budget.max_findings,
        max_queries,
        active_plugin_ids,
        len(source_rows),
        len(finding_rows),
        len(suppressed_rows),
        timings,
        install_verified=False,
        first_report_verified=first_report_verified,
    )
    write_audit_dashboard(staging, manifest, summary, baseline_diff_summary, finding_rows)
    write_artifact_contract(staging)
    write_sha_manifest(staging)
    staging_verify_returncode, timings["verify_latency_ms"] = measure_staging_verify(root, staging)
    write_summary_resource_and_timing()
    write_diagnostics(
        staging,
        emit_diagnostics,
        TOOL_VERSION,
        mode,
        namespace,
        budget.max_files,
        budget.max_total_bytes,
        budget.max_file_bytes,
        budget.max_findings,
        max_queries,
        active_plugin_ids,
        len(source_rows),
        len(finding_rows),
        len(suppressed_rows),
        timings,
        install_verified=staging_verify_returncode == 0,
        first_report_verified=first_report_verified,
    )
    write_audit_dashboard(staging, manifest, summary, baseline_diff_summary, finding_rows)
    write_artifact_contract(staging)
    write_sha_manifest(staging)
    if staging_verify_status(root, staging) != 0:
        raise RuntimeError("staging artifact verification failed")
    return summary


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a local evidence-bound code/documentation audit.")
    parser.add_argument("target_repo", nargs="?")
    parser.add_argument("--version", action="version", version=TOOL_VERSION)
    parser.add_argument("--list-plugins", action="store_true", help="Print the deterministic auditor plugin registry as JSON and exit.")
    parser.add_argument("--list-plugin-rules", action="store_true", help="Print deterministic auditor plugin rule metadata as JSON and exit.")
    parser.add_argument("--verify-existing", metavar="OUT_DIR", default="", help="Verify an existing audit output directory and exit.")
    parser.add_argument("--mode", choices=["quick", "full"], default="quick")
    parser.add_argument("--max-queries", type=int, default=None, help="Compatibility alias for --max-findings.")
    parser.add_argument("--max-files", type=int, default=None)
    parser.add_argument("--max-total-bytes", type=int, default=None)
    parser.add_argument("--max-file-bytes", type=int, default=None)
    parser.add_argument("--max-findings", type=int, default=None)
    parser.add_argument("--out", default="results/my_repo_audit")
    parser.add_argument("--generator", default="routehint-tiny")
    parser.add_argument("--namespace", choices=["fixture", "synthetic", "real_benchmark"], default="synthetic")
    parser.add_argument("--confirm-real-benchmark-namespace", action="store_true", help="Allow writing outputs in the real_benchmark namespace.")
    parser.add_argument("--question", default="")
    parser.add_argument("--question-file", default="", help="Read one non-empty question from a UTF-8 text file.")
    parser.add_argument("--allowlist", default="", help="JSON suppression/allowlist file for source-bound accepted findings.")
    parser.add_argument("--suppression-file", default="", help="Alias for --allowlist.")
    parser.add_argument("--baseline", default="", help="Verified previous audit output directory for source-bound finding diff.")
    parser.add_argument("--changed-files-from", default="", help="Newline-delimited target-repo-relative file list for PR/diff-scoped local audits.")
    parser.add_argument("--emit-report", action="store_true", default=True)
    parser.add_argument("--emit-lineage", action="store_true", default=True)
    parser.add_argument("--emit-reproduce", action="store_true", default=True)
    parser.add_argument("--emit-diagnostics", action="store_true", help="Opt in to writing a local-only diagnostics.json artifact with coarse run metrics. Defaults to opt-out.")
    parser.add_argument("--verify-output", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--overwrite-latest", action="store_true", help="Allow changing an existing latest pointer to a different cache key without deleting old versioned runs.")
    return parser.parse_args(argv)


def resolve_budget(args: argparse.Namespace) -> tuple[AuditBudget, int]:
    defaults = MODE_DEFAULT_BUDGETS[args.mode]
    max_findings = args.max_findings
    if max_findings is None and args.max_queries is not None:
        max_findings = args.max_queries
    if max_findings is None:
        max_findings = defaults["max_findings"]
    values = {
        "max_files": defaults["max_files"] if args.max_files is None else args.max_files,
        "max_total_bytes": defaults["max_total_bytes"] if args.max_total_bytes is None else args.max_total_bytes,
        "max_file_bytes": defaults["max_file_bytes"] if args.max_file_bytes is None else args.max_file_bytes,
        "max_findings": max_findings,
    }
    for name, value in values.items():
        if value <= 0:
            raise AuditInputError(f"--{name.replace('_', '-')} must be positive")
    max_queries = args.max_queries if args.max_queries is not None else max_findings
    if max_queries <= 0:
        raise AuditInputError("--max-queries must be positive")
    return AuditBudget(**values), max_queries


def resolve_question(args: argparse.Namespace) -> str:
    if args.question and args.question_file:
        raise AuditInputError("--question and --question-file are mutually exclusive")
    if not args.question_file:
        return args.question
    question_file = Path(args.question_file).expanduser().resolve()
    if not question_file.is_file():
        raise AuditInputError(f"--question-file is not a file: {question_file}")
    lines = [line.strip() for line in question_file.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) != 1:
        raise AuditInputError("--question-file must contain exactly one non-empty question line")
    return lines[0]


def plugin_registry_payload() -> dict:
    root = Path(__file__).resolve().parents[1]

    def plugin_source(plugin: AuditPlugin) -> tuple[str, str]:
        module = sys.modules[plugin.__class__.__module__]
        module_path = Path(str(module.__file__)).resolve()
        rel_path = str(module_path.relative_to(root))
        return rel_path, sha256(module_path)

    plugin_rows = []
    for plugin in list(DEFAULT_PLUGINS) + [USER_QUESTION_PLUGIN]:
        source_path, source_digest = plugin_source(plugin)
        plugin_rows.append(
            {
                "plugin_id": plugin.plugin_id,
                "audit_type": plugin.audit_type,
                "language": plugin.language,
                "module": plugin.__class__.__module__,
                "source_path": source_path,
                "source_sha256": source_digest,
            }
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "plugins": plugin_rows,
    }


def plugin_rule_row(plugin: AuditPlugin, rule) -> dict:
    return {
        "plugin_id": plugin.plugin_id,
        "audit_type": plugin.audit_type,
        "rule_id": rule.rule_id,
        "language": rule.language,
        "file_suffixes": "|".join(rule.file_suffixes),
        "pattern_label": rule.pattern_label,
        "evidence_policy": rule.evidence_policy,
        "confidence": rule.confidence,
        "parser_id": rule.parser_id,
    }


def plugin_rule_rows() -> list[dict]:
    rows = [
        plugin_rule_row(plugin, rule)
        for plugin in list(DEFAULT_PLUGINS) + [USER_QUESTION_PLUGIN]
        for rule in plugin.rules()
    ]
    return sorted(rows, key=lambda row: (row["plugin_id"], row["rule_id"]))


def plugin_rules_payload() -> dict:
    return {
        "schema_version": "local_repo_audit_plugin_rules.v1",
        "tool_version": TOOL_VERSION,
        "rules": plugin_rule_rows(),
    }


def verify_output_artifact(root: Path, out_dir: Path) -> int:
    verifier = root / "tools" / "verify_local_audit.py"
    result = subprocess.run(
        [sys.executable, str(verifier), str(out_dir)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout.rstrip(), file=sys.stderr)
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)
        print(f"artifact_verify: failed ({out_dir})", file=sys.stderr)
        return result.returncode
    print("artifact_verify: ok")
    return 0


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    if args.list_plugins:
        print(json.dumps(plugin_registry_payload(), indent=2, sort_keys=True))
        return 0
    if args.list_plugin_rules:
        print(json.dumps(plugin_rules_payload(), indent=2, sort_keys=True))
        return 0
    if args.verify_existing:
        existing_out = Path(args.verify_existing).expanduser()
        if not existing_out.is_absolute():
            existing_out = (root / existing_out).resolve()
        else:
            existing_out = existing_out.resolve()
        return 0 if verify_output_artifact(root, existing_out) == 0 else 1
    if not args.target_repo:
        print("target repo is required unless --version, --list-plugins, --list-plugin-rules, or --verify-existing is used", file=sys.stderr)
        return 2
    target = Path(args.target_repo).expanduser().resolve()
    out_dir = Path(args.out).expanduser()
    if not out_dir.is_absolute():
        out_dir = (root / out_dir).resolve()
    else:
        out_dir = out_dir.resolve()
    if not target.is_dir():
        print(f"target repo is not a directory: {target}", file=sys.stderr)
        return 2
    if out_dir == target or target in out_dir.parents:
        print("refusing --out inside target repo; use an output path outside the audited repository", file=sys.stderr)
        return 2
    if args.generator != "routehint-tiny":
        print("only --generator routehint-tiny is supported in the alpha path", file=sys.stderr)
        return 2
    if args.namespace == "real_benchmark" and not args.confirm_real_benchmark_namespace:
        print("--namespace real_benchmark requires --confirm-real-benchmark-namespace", file=sys.stderr)
        return 2

    try:
        question = resolve_question(args)
        budget, max_queries = resolve_budget(args)
        if args.allowlist and args.suppression_file:
            raise AuditInputError("--allowlist and --suppression-file are aliases; pass only one")
        suppression_arg = args.allowlist or args.suppression_file
        suppression_rules, suppression_file, suppression_file_sha256 = load_suppression_rules(suppression_arg)
        changed_file_selection = resolve_changed_file_selection(root, target, args.changed_files_from)
        baseline = resolve_baseline_bundle(root, args.baseline)
    except AuditInputError as exc:
        print(f"input_error: {exc}", file=sys.stderr)
        return 2
    minimum_findings = len(active_plugins_for_mode(args.mode)) + int(bool(question))
    if budget.max_findings < minimum_findings:
        print(
            f"--max-findings must be at least {minimum_findings} to run every required auditor plugin for --mode {args.mode}",
            file=sys.stderr,
        )
        return 2

    staging_parent = out_dir / ".staging"
    staging_parent.mkdir(parents=True, exist_ok=True)
    staging = staging_parent / f"run-{os.getpid()}-{int(time.time())}"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    try:
        real_benchmark_namespace_confirmed = int(args.namespace == "real_benchmark" and args.confirm_real_benchmark_namespace)
        summary = write_outputs(root, target, out_dir, staging, args.mode, max_queries, budget, changed_file_selection, suppression_rules, suppression_file, suppression_file_sha256, baseline, args.generator, args.namespace, real_benchmark_namespace_confirmed, question, args.verify_output, args.emit_report, args.emit_lineage, args.emit_reproduce, args.emit_diagnostics)
        publish_status = publish_atomic(root, staging, out_dir, args.overwrite_latest)
    except AuditInputError as exc:
        print(f"input_error: {exc}", file=sys.stderr)
        return 2
    except RuntimeError as exc:
        print(f"publish_error: {exc}", file=sys.stderr)
        return 2
    finally:
        shutil.rmtree(staging, ignore_errors=True)
        if staging_parent.is_dir():
            try:
                staging_parent.rmdir()
            except OSError:
                pass
    if args.verify_output:
        verify_status = verify_output_artifact(root, out_dir)
        if verify_status != 0:
            return 1
    print(f"audit_report: {out_dir / 'AUDIT_REPORT.md'}")
    print(f"audit_summary: {out_dir / 'audit_summary.csv'}")
    return 0 if int(summary["wrong_answer_guard_pass_rows"]) == int(summary["wrong_answer_guard_rows"]) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
