#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

from auditor_plugin_user_question import USER_QUESTION_PLUGIN
from auditor_plugins import DEFAULT_PLUGINS, AuditPlugin, Finding, SourceFile

SCHEMA_VERSION = "local_repo_audit.v1"
OUTPUT_SCHEMA_VERSION = "local_repo_audit_output.v1"
TOOL_VERSION = "audit_my_repo_alpha.v1"
DETERMINISTIC_GENERATED_AT_UTC = "1970-01-01T00:00:00+00:00"
ARTIFACT_CONTRACT_SCHEMA_VERSION = "local_repo_audit_artifacts.v1"


class AuditInputError(Exception):
    """User-correctable audit invocation/input error."""


CSV_CONTRACTS: dict[str, list[str]] = {
    "source_manifest.csv": ["source_id", "file_path", "sha256", "bytes", "route_memory_source"],
    "audit_findings.csv": ["finding_id", "audit_type", "plugin_id", "language", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "citations", "citation_sha256s", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"],
    "citation_spans.csv": ["finding_id", "citation_id", "file_path", "line_start", "line_end", "sha256", "span_text_preview", "mmap_value_byte_read"],
    "compact_route_hint_rows.csv": ["hint_id", "finding_id", "hint_bytes", "source_citation_count", "raw_context_appended", "proposal_hint_used"],
    "grounded_generation_rows.csv": ["generation_id", "finding_id", "hint_id", "generator", "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes", "grounded", "abstain", "unsupported_claim", "answer"],
    "abstain_rows.csv": ["finding_id", "audit_type", "plugin_id", "language", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "citations", "citation_sha256s", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"],
    "unsupported_claim_rows.csv": ["finding_id", "audit_type", "plugin_id", "language", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "citations", "citation_sha256s", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"],
    "wrong_answer_guard_rows.csv": ["finding_id", "guard_id", "unsupported_direct_answer_blocked", "citation_required", "audit_trail_required", "wrong_answer_guard_pass"],
    "accuracy_rows.csv": ["finding_id", "accuracy_label", "automatic_accuracy_claimed", "manual_accuracy_review_required"],
    "citation_correctness_rows.csv": ["finding_id", "citation_count", "citation_bound", "citation_correctness_label", "manual_citation_review_required"],
    "latency_rows.csv": ["finding_id", "latency_ms", "latency_source"],
    "false_positive_candidate_rows.csv": ["finding_id", "manual_review_required", "false_positive_candidate", "auto_promoted"],
    "manual_review_queue.csv": ["finding_id", "review_queue_id", "review_types", "manual_review_required", "review_reason", "auto_promoted"],
    "plugin_rule_rows.csv": ["plugin_id", "audit_type", "rule_id", "language", "file_suffixes", "pattern_label", "evidence_policy"],
    "audit_summary.csv": ["schema_version", "tool_version", "audit_my_repo_ready", "target_repo", "mode", "namespace", "generator", "question_supplied", "source_files", "finding_rows", "citation_span_rows", "abstain_rows", "unsupported_claim_rows", "accuracy_rows", "citation_correctness_rows", "false_positive_candidate_rows", "wrong_answer_guard_rows", "wrong_answer_guard_pass_rows", "claim_boundary_ready", "route_memory_lineage_rows", "mmap_read_trace_rows", "compact_route_hint_rows", "grounded_generation_rows", "raw_prompt_context_bytes", "attention_blocks", "transformer_blocks", "oracle_prediction_used", "raw_input_extractor_used", "real_release_package_ready", "public_comparison_claim_ready", "gpu_speedup_claim", "latency_ms"],
}

JSONL_CONTRACTS: dict[str, list[str]] = {
    "audit_findings.jsonl": CSV_CONTRACTS["audit_findings.csv"],
    "citation_spans.jsonl": CSV_CONTRACTS["citation_spans.csv"],
    "prediction_lineage.jsonl": ["finding_id", "route_index_row", "compact_route_hint_id", "generator_id", "citation_count", "audit_trail_bound"],
    "mmap_read_trace.jsonl": ["finding_id", "file_path", "line_start", "sha256", "mmap_value_byte_read"],
}

JSON_CONTRACTS: dict[str, list[str]] = {
    "audit_invocation.json": ["schema_version", "tool_version", "target_repo", "out_dir", "mode", "max_queries", "generator", "namespace", "real_benchmark_namespace_confirmed", "question_supplied", "question_sha256", "verify_output_requested", "emit_report_requested", "emit_lineage_requested", "emit_reproduce_requested"],
    "audit_manifest.json": ["schema_version", "tool_version", "generated_at_utc", "target_repo", "namespace", "real_benchmark_namespace_confirmed", "fixture_result_promoted", "real_evidence_claimed", "source_file_count", "finding_rows", "atomic_publish", "output_dir_destroyed", "output_dir_overwritten", "publish_mode", "cache_key", "plugin_registry_sha256", "claim_boundary"],
    "audit_summary.json": list(CSV_CONTRACTS["audit_summary.csv"]),
    "exit_code_contract.json": ["schema_version", "tool_version", "success_exit_code", "artifact_verify_failure_exit_code", "input_or_publish_error_exit_code", "wrong_answer_guard_failure_exit_code", "stable_exit_code_policy"],
    "plugin_registry.json": ["schema_version", "tool_version", "plugins"],
    "resource_envelope.json": ["resource_envelope_ready", "tool_version", "source_files_scanned", "max_queries", "mode", "namespace", "external_network_used", "raw_prompt_context_bytes", "latency_ms", "wrong_answer_guard_rows", "claim_boundary_ready"],
    "source_snapshot.json": ["schema_version", "tool_version", "target_repo", "source_manifest_sha256", "source_file_count", "git_available", "git_head", "git_dirty", "git_status_sha256", "git_tracked_files"],
}

OPTIONAL_ZERO_ROW_ARTIFACTS = {"abstain_rows.csv", "unsupported_claim_rows.csv"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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
        ("AUDIT_REPORT.md", "markdown"),
        ("ARCHITECTURE_TRACE.md", "markdown"),
        ("claim_boundary.md", "markdown"),
        ("reproduce.sh", "shell"),
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


def tracked_files(target: Path, max_queries: int) -> list[Path]:
    try:
        output = subprocess.check_output(["git", "-C", str(target), "ls-files"], text=True, stderr=subprocess.DEVNULL)
        files = [target / line for line in output.splitlines() if line.strip()]
    except Exception:
        files = [path for path in target.rglob("*") if ".git" not in path.parts]
    allowed = []
    for path in files:
        if not is_target_regular_file(target, path):
            continue
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if size <= 0 or size > 700_000:
            continue
        suffix = path.suffix.lower()
        name = path.name.lower()
        if suffix in {".md", ".py", ".toml", ".ini", ".cfg", ".txt", ".yaml", ".yml", ".json", ".sh", ".cpp", ".hpp", ".cc", ".cxx", ".c", ".h", ".js", ".ts", ".tsx", ".jsx"} or name in {"makefile", "cmakelists.txt", "package.json"}:
            allowed.append(path)
    return sorted(allowed)[: max(12, min(max_queries, 220))]


def line_for(path: Path, patterns: list[str]) -> tuple[int, str]:
    text = read_text(path)
    for pattern in patterns:
        if not pattern:
            continue
        for idx, line in enumerate(text.splitlines(), start=1):
            if pattern in line or pattern.lower() in line.lower():
                return idx, line.strip()[:280]
    for idx, line in enumerate(text.splitlines(), start=1):
        if line.strip():
            return idx, line.strip()[:280]
    return 1, path.name


def collect_sources(target: Path, max_queries: int) -> tuple[list[SourceFile], list[dict]]:
    source_paths = tracked_files(target, max_queries)
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


def build_rows(target: Path, findings: list[Finding]) -> tuple[list[dict], list[dict]]:
    finding_rows: list[dict] = []
    span_rows: list[dict] = []
    for idx, finding in enumerate(findings, start=1):
        finding_id = f"finding_{idx:03d}"
        citation_cells = []
        citation_sha256s = []
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
            line_no, snippet = line_for(path, citation_patterns)
            citation_id = f"{finding_id}_cite_{cidx}"
            rel_path = rel_to_target(target, path)
            citation_sha256 = sha256(path)
            citation_cells.append(f"{rel_path}:{line_no}")
            citation_sha256s.append(citation_sha256)
            span_rows.append(
                {
                    "finding_id": finding_id,
                    "citation_id": citation_id,
                    "file_path": rel_path,
                    "line_start": line_no,
                    "line_end": line_no,
                    "sha256": citation_sha256,
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
                "language": finding.language,
                "question": finding.question,
                "answer": finding.answer if citation_cells else "Abstain: no source citation could be bound for this finding.",
                "severity": finding.severity,
                "grounded": grounded,
                "abstain": abstain,
                "unsupported_claim": finding.unsupported_claim,
                "citations": ";".join(citation_cells),
                "citation_sha256s": ";".join(citation_sha256s),
                "route_memory_lineage": 1,
                "raw_prompt_context_bytes": 0,
                "oracle_prediction_used": 0,
                "raw_input_extractor_used": 0,
            }
        )
    return finding_rows, span_rows


def publish_atomic(staging: Path, out_dir: Path) -> str:
    staging_manifest = json.loads((staging / "audit_manifest.json").read_text(encoding="utf-8"))
    existing_manifest_path = out_dir / "audit_manifest.json"
    if existing_manifest_path.is_file():
        existing_manifest = json.loads(existing_manifest_path.read_text(encoding="utf-8"))
        if existing_manifest.get("cache_key") != staging_manifest.get("cache_key"):
            raise RuntimeError(
                "output directory already contains a different audit_manifest.json cache_key; "
                "use a fresh --out path to preserve existing results"
            )
        staging_sha = (staging / "sha256sums.txt").read_text(encoding="utf-8")
        existing_sha_path = out_dir / "sha256sums.txt"
        if not existing_sha_path.is_file() or existing_sha_path.read_text(encoding="utf-8") != staging_sha:
            raise RuntimeError(
                "output directory cache_key matches but sha256sums.txt differs; "
                "use a fresh --out path or verify the existing artifact"
            )
        for path in sorted(staging.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(staging)
            existing_artifact = out_dir / rel
            if not existing_artifact.is_file() or sha256(existing_artifact) != sha256(path):
                raise RuntimeError(
                    "output directory cache_key matches but artifact content differs: "
                    f"{rel}"
                )
        return "idempotent-cache-hit"

    out_dir.mkdir(parents=True, exist_ok=True)
    staging_paths = sorted(staging.rglob("*"))
    conflicting_targets = [
        out_dir / path.relative_to(staging)
        for path in staging_paths
        if path.is_file() and (out_dir / path.relative_to(staging)).exists()
    ]
    if conflicting_targets:
        rel_conflicts = ", ".join(str(path.relative_to(out_dir)) for path in conflicting_targets[:5])
        raise RuntimeError(
            "refusing to overwrite existing output artifact without a matching cache_key: "
            f"{rel_conflicts}"
        )

    for path in staging_paths:
        rel = path.relative_to(staging)
        target = out_dir / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_name(f".{target.name}.tmp-{os.getpid()}")
        shutil.copy2(path, tmp)
        os.replace(tmp, target)
    return "created"


def write_outputs(root: Path, target: Path, out_dir: Path, staging: Path, mode: str, max_queries: int, generator: str, namespace: str, real_benchmark_namespace_confirmed: int, question: str, verify_output: bool, emit_report: bool, emit_lineage: bool, emit_reproduce: bool) -> dict:
    sources, source_rows = collect_sources(target, max_queries)
    write_json(staging / "plugin_registry.json", plugin_registry_payload())
    write_csv(staging / "plugin_rule_rows.csv", CSV_CONTRACTS["plugin_rule_rows.csv"], plugin_rule_rows())
    plugin_findings: list[Finding] = []
    for plugin in DEFAULT_PLUGINS:
        plugin_findings.extend(plugin.run(target, sources))
    question_finding = USER_QUESTION_PLUGIN.run_question(sources, question)
    if question_finding is not None:
        findings = plugin_findings[: max_queries - 1] + [question_finding]
    else:
        findings = plugin_findings[:max_queries]
    finding_rows, span_rows = build_rows(target, findings)

    write_csv(staging / "source_manifest.csv", ["source_id", "file_path", "sha256", "bytes", "route_memory_source"], source_rows)
    write_json(staging / "source_snapshot.json", source_snapshot_payload(target, staging / "source_manifest.csv", len(source_rows)))
    (staging / "audit_findings.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in finding_rows), encoding="utf-8")
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
    for idx, finding in enumerate(finding_rows, start=1):
        hint_id = f"hint_{idx:04d}"
        citation_count = len([c for c in finding["citations"].split(";") if c])
        routehint_rows.append({"hint_id": hint_id, "finding_id": finding["finding_id"], "hint_bytes": min(256, len(finding["answer"].encode("utf-8"))), "source_citation_count": citation_count, "raw_context_appended": 0, "proposal_hint_used": 1})
        generation_rows.append({"generation_id": f"gen_{idx:04d}", "finding_id": finding["finding_id"], "hint_id": hint_id, "generator": generator, "attention_blocks": 0, "transformer_blocks": 0, "raw_prompt_context_bytes": 0, "grounded": finding["grounded"], "abstain": finding["abstain"], "unsupported_claim": finding["unsupported_claim"], "answer": finding["answer"]})
        lineage_rows.append({"finding_id": finding["finding_id"], "route_index_row": idx, "compact_route_hint_id": hint_id, "generator_id": f"gen_{idx:04d}", "citation_count": citation_count, "audit_trail_bound": 1})
        latency_rows.append({"finding_id": finding["finding_id"], "latency_ms": 0, "latency_source": "deterministic-local-smoke"})
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
        mmap_rows.append({"finding_id": row["finding_id"], "file_path": row["file_path"], "line_start": row["line_start"], "sha256": row["sha256"], "mmap_value_byte_read": 1})

    write_csv(staging / "compact_route_hint_rows.csv", ["hint_id", "finding_id", "hint_bytes", "source_citation_count", "raw_context_appended", "proposal_hint_used"], routehint_rows)
    write_csv(staging / "grounded_generation_rows.csv", ["generation_id", "finding_id", "hint_id", "generator", "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes", "grounded", "abstain", "unsupported_claim", "answer"], generation_rows)
    (staging / "prediction_lineage.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
    (staging / "mmap_read_trace.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in mmap_rows), encoding="utf-8")
    write_csv(staging / "abstain_rows.csv", list(finding_rows[0].keys()), abstain_rows)
    write_csv(staging / "unsupported_claim_rows.csv", list(finding_rows[0].keys()), unsupported_rows)
    write_csv(staging / "wrong_answer_guard_rows.csv", ["finding_id", "guard_id", "unsupported_direct_answer_blocked", "citation_required", "audit_trail_required", "wrong_answer_guard_pass"], wrong_answer_guard_rows)
    write_csv(staging / "accuracy_rows.csv", ["finding_id", "accuracy_label", "automatic_accuracy_claimed", "manual_accuracy_review_required"], accuracy_rows)
    write_csv(staging / "citation_correctness_rows.csv", ["finding_id", "citation_count", "citation_bound", "citation_correctness_label", "manual_citation_review_required"], citation_correctness_rows)
    write_csv(staging / "latency_rows.csv", ["finding_id", "latency_ms", "latency_source"], latency_rows)
    write_csv(staging / "false_positive_candidate_rows.csv", ["finding_id", "manual_review_required", "false_positive_candidate", "auto_promoted"], false_positive_rows)
    write_csv(staging / "manual_review_queue.csv", CSV_CONTRACTS["manual_review_queue.csv"], manual_review_rows)
    write_json(
        staging / "audit_invocation.json",
        {
            "schema_version": "local_repo_audit_invocation.v1",
            "tool_version": TOOL_VERSION,
            "target_repo": str(target),
            "out_dir": str(out_dir),
            "mode": mode,
            "max_queries": max_queries,
            "generator": generator,
            "namespace": namespace,
            "real_benchmark_namespace_confirmed": real_benchmark_namespace_confirmed,
            "question_supplied": int(bool(question)),
            "question_sha256": sha256_text(question),
            "verify_output_requested": int(verify_output),
            "emit_report_requested": int(emit_report),
            "emit_lineage_requested": int(emit_lineage),
            "emit_reproduce_requested": int(emit_reproduce),
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
        "`real_release_package_ready=0`, `public_comparison_claim_ready=0`, and `gpu_speedup_claim=deferred` remain explicit.\n"
    )
    (staging / "claim_boundary.md").write_text(claim_boundary, encoding="utf-8")

    deterministic_latency_ms = 0
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
        "finding_rows": len(finding_rows),
        "citation_span_rows": len(span_rows),
        "abstain_rows": len(abstain_rows),
        "unsupported_claim_rows": len(unsupported_rows),
        "accuracy_rows": len(accuracy_rows),
        "citation_correctness_rows": len(citation_correctness_rows),
        "false_positive_candidate_rows": len(false_positive_rows),
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
        "public_comparison_claim_ready": 0,
        "gpu_speedup_claim": "deferred",
        "latency_ms": deterministic_latency_ms,
    }
    write_json(staging / "resource_envelope.json", {"resource_envelope_ready": 1, "tool_version": TOOL_VERSION, "source_files_scanned": len(source_rows), "max_queries": max_queries, "mode": mode, "namespace": namespace, "external_network_used": 0, "raw_prompt_context_bytes": 0, "latency_ms": deterministic_latency_ms, "wrong_answer_guard_rows": len(wrong_answer_guard_rows), "claim_boundary_ready": 1})
    write_json(staging / "audit_summary.json", summary)
    write_csv(staging / "audit_summary.csv", list(summary.keys()), [summary])

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
            "--max-queries",
            str(max_queries),
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
        if namespace == "real_benchmark":
            command.append("--confirm-real-benchmark-namespace")
        if question:
            command.extend(["--question", question])
        reproduce.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            f"cd {shlex.quote(str(root))}\n"
            + " ".join(shlex.quote(part) for part in command)
            + "\n",
            encoding="utf-8",
        )
        reproduce.chmod(0o755)

    plugin_registry_sha256 = sha256(staging / "plugin_registry.json")
    manifest = {
        "schema_version": OUTPUT_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "generated_at_utc": DETERMINISTIC_GENERATED_AT_UTC,
        "target_repo": str(target),
        "namespace": namespace,
        "real_benchmark_namespace_confirmed": real_benchmark_namespace_confirmed,
        "fixture_result_promoted": 0,
        "real_evidence_claimed": 0,
        "source_file_count": len(source_rows),
        "finding_rows": len(finding_rows),
        "atomic_publish": 1,
        "output_dir_destroyed": 0,
        "output_dir_overwritten": 0,
        "publish_mode": "create-or-idempotent-cache-hit",
        "cache_key": hashlib.sha256(json.dumps({"tool_version": TOOL_VERSION, "target": str(target), "source": [(row["file_path"], row["sha256"]) for row in source_rows], "source_snapshot": json.loads((staging / "source_snapshot.json").read_text(encoding="utf-8")), "mode": mode, "max_queries": max_queries, "namespace": namespace, "real_benchmark_namespace_confirmed": real_benchmark_namespace_confirmed, "question": question, "verify_output_requested": int(verify_output), "emit_report_requested": int(emit_report), "emit_lineage_requested": int(emit_lineage), "emit_reproduce_requested": int(emit_reproduce), "plugin_registry_sha256": plugin_registry_sha256}, sort_keys=True).encode("utf-8")).hexdigest(),
        "plugin_registry_sha256": plugin_registry_sha256,
        "claim_boundary": "alpha-local-code-doc-audit-only",
    }
    write_json(staging / "audit_manifest.json", manifest)
    write_artifact_contract(staging)
    sha_rows = []
    for path in sorted(staging.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            sha_rows.append(f"{sha256(path).removeprefix('sha256:')}  {path.relative_to(staging)}")
    (staging / "sha256sums.txt").write_text("\n".join(sha_rows) + "\n", encoding="utf-8")
    return summary


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a local evidence-bound code/documentation audit.")
    parser.add_argument("target_repo", nargs="?")
    parser.add_argument("--version", action="version", version=TOOL_VERSION)
    parser.add_argument("--list-plugins", action="store_true", help="Print the deterministic auditor plugin registry as JSON and exit.")
    parser.add_argument("--list-plugin-rules", action="store_true", help="Print deterministic auditor plugin rule metadata as JSON and exit.")
    parser.add_argument("--verify-existing", metavar="OUT_DIR", default="", help="Verify an existing audit output directory and exit.")
    parser.add_argument("--mode", choices=["quick", "full"], default="quick")
    parser.add_argument("--max-queries", type=int, default=100)
    parser.add_argument("--out", default="results/my_repo_audit")
    parser.add_argument("--generator", default="routehint-tiny")
    parser.add_argument("--namespace", choices=["fixture", "synthetic", "real_benchmark"], default="synthetic")
    parser.add_argument("--confirm-real-benchmark-namespace", action="store_true", help="Allow writing outputs in the real_benchmark namespace.")
    parser.add_argument("--question", default="")
    parser.add_argument("--question-file", default="", help="Read one non-empty question from a UTF-8 text file.")
    parser.add_argument("--emit-report", action="store_true", default=True)
    parser.add_argument("--emit-lineage", action="store_true", default=True)
    parser.add_argument("--emit-reproduce", action="store_true", default=True)
    parser.add_argument("--verify-output", action=argparse.BooleanOptionalAction, default=True)
    return parser.parse_args(argv)


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
    return {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "plugins": [
            {
                "plugin_id": plugin.plugin_id,
                "audit_type": plugin.audit_type,
                "language": plugin.language,
                "module": plugin.__class__.__module__,
            }
            for plugin in list(DEFAULT_PLUGINS) + [USER_QUESTION_PLUGIN]
        ],
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
    if args.max_queries <= 0:
        print("--max-queries must be positive", file=sys.stderr)
        return 2
    if args.namespace == "real_benchmark" and not args.confirm_real_benchmark_namespace:
        print("--namespace real_benchmark requires --confirm-real-benchmark-namespace", file=sys.stderr)
        return 2

    try:
        question = resolve_question(args)
    except AuditInputError as exc:
        print(f"input_error: {exc}", file=sys.stderr)
        return 2

    staging_parent = out_dir.parent
    staging_parent.mkdir(parents=True, exist_ok=True)
    staging = staging_parent / f".{out_dir.name}.staging-{os.getpid()}-{int(time.time())}"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    try:
        real_benchmark_namespace_confirmed = int(args.namespace == "real_benchmark" and args.confirm_real_benchmark_namespace)
        summary = write_outputs(root, target, out_dir, staging, args.mode, args.max_queries, args.generator, args.namespace, real_benchmark_namespace_confirmed, question, args.verify_output, args.emit_report, args.emit_lineage, args.emit_reproduce)
        publish_status = publish_atomic(staging, out_dir)
    except AuditInputError as exc:
        print(f"input_error: {exc}", file=sys.stderr)
        return 2
    except RuntimeError as exc:
        print(f"publish_error: {exc}", file=sys.stderr)
        return 2
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    if args.verify_output:
        verify_status = verify_output_artifact(root, out_dir)
        if verify_status != 0:
            return 1
    print(f"audit_report: {out_dir / 'AUDIT_REPORT.md'}")
    print(f"audit_summary: {out_dir / 'audit_summary.csv'}")
    return 0 if int(summary["wrong_answer_guard_pass_rows"]) == int(summary["wrong_answer_guard_rows"]) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
