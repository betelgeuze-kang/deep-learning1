#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


MIN_REAL_REPOS_FOR_BETA = 10
MIN_HUMAN_LABELS_FOR_BETA = 300
MIN_MAINTAINER_FEEDBACK_FOR_BETA = 3
OVERALL_PRECISION_THRESHOLD = 0.80
P0_P1_PRECISION_THRESHOLD = 0.90
SAFE_CASE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
SAFE_FEEDBACK_ID = SAFE_CASE_ID
VALID_LABEL_PRIORITIES = {"", "P0", "P1", "P2", "P3"}
BENCHMARK_ARTIFACTS = (
    "benchmark_summary.json",
    "benchmark_summary.csv",
    "benchmark_evaluation.json",
    "benchmark_readiness.json",
    "benchmark_run_metrics.csv",
    "benchmark_case_metrics.csv",
    "benchmark_repo_snapshots.csv",
    "benchmark_labels.csv",
    "benchmark_labels.json",
    "benchmark_label_quality.csv",
    "benchmark_label_citation_expectations.csv",
    "benchmark_label_citation_expectations.json",
    "benchmark_findings.csv",
    "benchmark_findings.json",
    "benchmark_citation_validity.csv",
    "benchmark_confusion_rows.csv",
    "benchmark_abstain_correctness.csv",
    "benchmark_maintainer_feedback.csv",
    "benchmark_maintainer_feedback.json",
)
BENCHMARK_MANAGED_TOP_LEVEL = set(BENCHMARK_ARTIFACTS) | {"benchmark_manifest.json", "benchmark_sha256sums.txt", "case_runs"}
BENCHMARK_SCHEMA_INSTANCE_PAIRS = (
    ("schemas/local_repo_audit_benchmark_manifest.schema.json", "benchmark_manifest.json"),
    ("schemas/local_repo_audit_benchmark_summary.schema.json", "benchmark_summary.json"),
    ("schemas/local_repo_audit_benchmark_evaluation.schema.json", "benchmark_evaluation.json"),
    ("schemas/local_repo_audit_benchmark_readiness.schema.json", "benchmark_readiness.json"),
    ("schemas/local_repo_audit_benchmark_labels.schema.json", "benchmark_labels.json"),
    ("schemas/local_repo_audit_benchmark_label_citation_expectations.schema.json", "benchmark_label_citation_expectations.json"),
    ("schemas/local_repo_audit_benchmark_findings.schema.json", "benchmark_findings.json"),
    ("schemas/local_repo_audit_benchmark_maintainer_feedback.schema.json", "benchmark_maintainer_feedback.json"),
)
READINESS_GATES = (
    ("real_repo_requirement_met", "real_repo_count", "min_real_repos_required", "At least 10 real local repositories"),
    ("human_label_requirement_met", "human_label_rows", "min_human_label_rows_required", "At least 300 human label rows"),
    ("label_source_trace_requirement_met", "label_source_trace_rows", "human_label_rows", "Every human label preserves candidate and review-queue trace IDs"),
    ("repo_snapshot_requirement_met", "repo_snapshot_locked_rows", "repo_snapshot_rows", "Every case has clean expected repo snapshot"),
    ("maintainer_feedback_requirement_met", "maintainer_feedback_count", "min_maintainer_feedback_required", "At least 3 maintainer feedback sources"),
    ("overall_precision_requirement_met", "precision", "overall_precision_threshold", "Overall precision >= threshold"),
    ("p0_p1_precision_requirement_met", "p0_p1_precision", "p0_p1_precision_threshold", "P0/P1 precision >= threshold"),
    ("citation_validity_requirement_met", "citation_validity_pass_rows", "citation_validity_rows", "All citation validity rows pass"),
    ("label_citation_expectation_requirement_met", "label_citation_expectation_met_rows", "label_citation_expectation_rows", "All human citation expectations are matched"),
    ("standard_json_findings_requirement_met", "standard_json_findings_valid_rows", "standard_json_findings_checked_rows", "All standard JSON finding outputs validate"),
    ("install_success_requirement_met", "install_success_rows", "install_check_rows", "Install/preflight succeeds"),
    ("first_report_requirement_met", "first_report_success_rows", "case_rows", "First verified report succeeds for every case"),
    ("rerun_requirement_met", "rerun_success_rows", "rerun_checked_rows", "Rerun/cache/semantic repeatability succeeds when checked"),
    ("label_quality_requirement_met", "label_quality_specific_rows", "label_quality_total_rows", "Human labels are specific, citation-bound, non-duplicate, non-contradictory"),
)
LABEL_QUALITY_FIELDS = [
    "case_id",
    "label_id",
    "plugin_id",
    "rule_id",
    "file_path",
    "expected_line_start",
    "expected_line_end",
    "expected_span_sha256",
    "expected",
    "priority",
    "is_broad",
    "is_citation_unbound",
    "citation_expectation_supplied",
    "is_duplicate",
    "is_contradictory",
    "is_specific",
]
BENCHMARK_LABEL_FIELDS = [
    "case_id",
    "label_id",
    "source_candidate_label_id",
    "source_review_queue_id",
    "plugin_id",
    "rule_id",
    "file_path",
    "expected_line_start",
    "expected_line_end",
    "expected_span_sha256",
    "expected",
    "expected_abstain",
    "priority",
    "maintainer_id",
    "maintainer_feedback",
    "citation_expectation_supplied",
    "matched_citation_id",
    "citation_expectation_met",
    "outcome",
]
LABEL_CITATION_EXPECTATION_FIELDS = [
    "case_id",
    "label_id",
    "plugin_id",
    "rule_id",
    "file_path",
    "expected_line_start",
    "expected_line_end",
    "expected_span_sha256",
    "expected",
    "citation_expectation_supplied",
    "matched_finding_id",
    "matched_citation_id",
    "citation_expectation_met",
    "outcome",
]
ABSTAIN_CORRECTNESS_FIELDS = [
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
RUN_METRIC_FIELDS = [
    "case_id",
    "install_check_returncode",
    "install_success",
    "install_wall_ms",
    "audit_exit_code",
    "verify_exit_code",
    "first_report_success",
    "first_report_wall_ms",
    "cache_key",
    "semantic_result_sha256",
    "source_scope",
    "source_file_count",
    "changed_files_from",
    "changed_files_from_sha256",
    "changed_file_rows",
    "standard_json_findings_checked",
    "standard_json_findings_valid",
    "standard_json_finding_rows",
    "standard_json_findings_invalid_reasons",
    "rerun_checked",
    "rerun_exit_code",
    "rerun_verify_exit_code",
    "rerun_wall_ms",
    "rerun_cache_key_match",
    "rerun_semantic_result_match",
    "rerun_success",
]
CASE_METRIC_FIELDS = [
    "case_id",
    "tp",
    "fp",
    "fn",
    "p0_p1_tp",
    "p0_p1_fp",
    "p0_p1_fn",
    "abstain_checked",
    "abstain_correct",
    "citation_validity_rows",
    "citation_validity_pass_rows",
    "label_citation_expectation_rows",
    "label_citation_expectation_met_rows",
]
CITATION_VALIDITY_FIELDS = [
    "case_id",
    "finding_id",
    "citation_id",
    "file_path",
    "line_start",
    "line_end",
    "file_exists",
    "file_sha256_valid",
    "source_manifest_sha256_valid",
    "line_bounds_valid",
    "span_sha256_valid",
    "span_preview_valid",
    "citation_valid",
    "invalid_reasons",
]
CONFUSION_FIELDS = [
    "case_id",
    "row_type",
    "label_id",
    "plugin_id",
    "rule_id",
    "file_path",
    "expected_line_start",
    "expected_line_end",
    "expected_span_sha256",
    "expected",
    "priority",
    "matched_finding_id",
    "citation_expectation_supplied",
    "matched_citation_id",
    "citation_expectation_met",
    "outcome",
    "tp",
    "fp",
    "fn",
    "tn",
]
REPO_SNAPSHOT_FIELDS = [
    "case_id",
    "repo_path_sha256",
    "repo_git_available",
    "repo_git_head",
    "repo_git_dirty",
    "repo_git_status_sha256",
    "repo_git_tracked_file_count",
    "repo_git_tracked_files_sha256",
    "expected_repo_git_head",
    "expected_repo_git_head_match",
    "expected_repo_snapshot_sha256",
    "repo_snapshot_sha256",
    "expected_repo_snapshot_sha256_match",
    "repo_snapshot_missing_expectation",
    "repo_snapshot_mismatch",
    "repo_snapshot_locked",
    "repo_snapshot_problems",
]
BENCHMARK_FINDING_FIELDS = [
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
BINARY_BENCHMARK_FINDING_FIELDS = {
    "grounded",
    "abstain",
    "unsupported_claim",
    "suppressed",
    "route_memory_lineage",
    "oracle_prediction_used",
    "raw_input_extractor_used",
}
NONEMPTY_BENCHMARK_FINDING_FIELDS = {
    "case_id",
    "finding_id",
    "audit_type",
    "plugin_id",
    "plugin_rule_ids",
    "confidence",
    "language",
    "answer",
}
BENCHMARK_EVALUATION_SUMMARY_FIELDS = [
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
]


def truthy(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def read_json_or_jsonl(path: Path, input_name: str) -> list[dict]:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} file")
    text = path.read_text(encoding="utf-8")
    stripped = text.strip()
    if not stripped:
        raise ValueError(f"{input_name} file is empty")
    if stripped.startswith("["):
        payload = json.loads(stripped)
        if not isinstance(payload, list):
            raise ValueError(f"JSON {input_name} file must contain a list")
        return payload
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def csv_fieldnames(path: Path) -> list[str]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle).fieldnames or [])


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def sha256_hex(path: Path) -> str:
    return sha256_file(path).split(":", 1)[1]


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def is_sha256_digest(value: str) -> bool:
    return bool(re.fullmatch(r"sha256:[0-9a-f]{64}", value))


def is_git_object_id(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", value))


def semantic_result_sha(out_dir: Path) -> str:
    semantic_summary = out_dir / "audit_semantic_summary.json"
    if semantic_summary.is_file():
        payload = json.loads(semantic_summary.read_text(encoding="utf-8"))
        value = str(payload.get("semantic_result_sha256", ""))
        if is_sha256_digest(value):
            return value
    digest = hashlib.sha256()
    for rel in [
        "source_manifest.csv",
        "audit_findings.csv",
        "citation_spans.csv",
        "abstain_rows.csv",
        "unsupported_claim_rows.csv",
        "baseline_diff_rows.csv",
        "manual_review_queue.csv",
    ]:
        path = out_dir / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256_file(path).encode("utf-8") if path.is_file() else b"missing")
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def standard_json_findings_metrics(out_dir: Path) -> dict:
    reasons: list[str] = []
    rows = read_csv(out_dir / "audit_findings.csv")
    citation_rows = read_csv(out_dir / "citation_spans.csv")
    try:
        payload = json.loads((out_dir / "audit_findings.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "standard_json_findings_checked": 1,
            "standard_json_findings_valid": 0,
            "standard_json_finding_rows": 0,
            "standard_json_findings_invalid_reasons": str(exc),
        }

    expected_metadata = {
        "schema_version": "local_repo_audit_findings.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    for key, expected in expected_metadata.items():
        if payload.get(key) != expected:
            reasons.append(f"{key}_mismatch")
    findings = payload.get("findings")
    if not isinstance(findings, list):
        reasons.append("findings_not_list")
        findings = []
    json_rows = [{key: "" if value is None else str(value) for key, value in row.items()} for row in findings if isinstance(row, dict)]
    if len(json_rows) != len(findings):
        reasons.append("findings_non_object_row")
    if json_rows != rows:
        reasons.append("findings_csv_drift")
    citation_spans = payload.get("citation_spans")
    if not isinstance(citation_spans, list):
        reasons.append("citation_spans_not_list")
        citation_spans = []
    json_citation_rows = [
        {key: "" if value is None else str(value) for key, value in row.items()}
        for row in citation_spans
        if isinstance(row, dict)
    ]
    if len(json_citation_rows) != len(citation_spans):
        reasons.append("citation_spans_non_object_row")
    if json_citation_rows != citation_rows:
        reasons.append("citation_spans_csv_drift")
    return {
        "standard_json_findings_checked": 1,
        "standard_json_findings_valid": int(not reasons),
        "standard_json_finding_rows": len(json_rows),
        "standard_json_findings_invalid_reasons": "|".join(reasons),
    }


def install_check(root: Path) -> tuple[int, int]:
    start_ns = time.perf_counter_ns()
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "py_compile",
            str(root / "scripts" / "audit_my_repo.py"),
            str(root / "tools" / "verify_local_audit.py"),
            str(root / "scripts" / "audit_my_repo_benchmark.py"),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    wall_ms = max(1, int(round((time.perf_counter_ns() - start_ns) / 1_000_000)))
    return result.returncode, wall_ms


def normalize_case_path(path_text: str, labels_dir: Path, *, label: str) -> str:
    if not path_text:
        return ""
    path = Path(path_text).expanduser()
    if not path.is_absolute():
        path = labels_dir / path
    resolved = path.resolve()
    if is_forbidden_env_path(resolved):
        raise ValueError(f"refusing to read .env-like {label} file")
    return str(resolved)


def normalize_case_id(raw_case_id: object, idx: int) -> str:
    case_id = str(raw_case_id or f"case_{idx:04d}").strip()
    if not SAFE_CASE_ID.fullmatch(case_id):
        raise ValueError(f"case_id must be a safe identifier with letters, numbers, '.', '_' or '-': {case_id}")
    return case_id


def normalize_label_citation_expectation(row: dict, case_id: str, label_id: str) -> tuple[str, str, str]:
    expected_line_start = str(row.get("expected_line_start") or "").strip()
    expected_line_end = str(row.get("expected_line_end") or "").strip()
    expected_span_sha256 = str(row.get("expected_span_sha256") or "").strip()
    if not (expected_line_start or expected_line_end or expected_span_sha256):
        return "", "", ""
    if not expected_line_start or not expected_span_sha256:
        raise ValueError(f"label {label_id} in case {case_id} must provide expected_line_start and expected_span_sha256 together")
    if not expected_line_end:
        expected_line_end = expected_line_start
    if not expected_line_start.isdigit() or not expected_line_end.isdigit():
        raise ValueError(f"label {label_id} in case {case_id} expected citation lines must be positive integers")
    if int(expected_line_start) <= 0 or int(expected_line_end) < int(expected_line_start):
        raise ValueError(f"label {label_id} in case {case_id} expected citation line bounds are invalid")
    if not is_sha256_digest(expected_span_sha256):
        raise ValueError(f"label {label_id} in case {case_id} expected_span_sha256 must be sha256:<64 hex>")
    return expected_line_start, expected_line_end, expected_span_sha256


def normalize_label_priority(value: object, case_id: str, label_id: str) -> str:
    priority = str(value or "").strip().upper()
    if priority not in VALID_LABEL_PRIORITIES:
        raise ValueError(f"label {label_id} in case {case_id} priority must be P0, P1, P2, P3, or empty")
    return priority


def normalize_cases(raw_rows: list[dict], labels_dir: Path) -> list[dict]:
    cases: dict[str, dict] = {}
    for idx, row in enumerate(raw_rows, start=1):
        case_id = normalize_case_id(row.get("case_id"), idx)
        repo_path = str(row.get("repo_path") or "")
        if not repo_path:
            raise ValueError(f"case {case_id} missing repo_path")
        changed_files_from = normalize_case_path(str(row.get("changed_files_from") or "").strip(), labels_dir, label="changed_files_from")
        allowlist = normalize_case_path(str(row.get("allowlist") or "").strip(), labels_dir, label="allowlist")
        suppression_file = normalize_case_path(
            str(row.get("suppression_file") or "").strip(), labels_dir, label="suppression_file"
        )
        if allowlist and suppression_file and allowlist != suppression_file:
            raise ValueError(f"case {case_id} has conflicting allowlist and suppression_file values")
        allowlist = allowlist or suppression_file
        expected_repo_git_head = str(row.get("expected_repo_git_head") or row.get("repo_git_head") or "").strip().lower()
        expected_repo_snapshot_sha256 = str(row.get("expected_repo_snapshot_sha256") or row.get("repo_snapshot_sha256") or "").strip()
        if expected_repo_git_head and not is_git_object_id(expected_repo_git_head):
            raise ValueError(f"case {case_id} expected_repo_git_head must be a git object id")
        if expected_repo_snapshot_sha256 and not is_sha256_digest(expected_repo_snapshot_sha256):
            raise ValueError(f"case {case_id} expected_repo_snapshot_sha256 must be sha256:<64 hex>")
        case = cases.setdefault(
            case_id,
            {
                "case_id": case_id,
                "repo_path": repo_path,
                "changed_files_from": changed_files_from,
                "allowlist": allowlist,
                "expected_repo_git_head": expected_repo_git_head,
                "expected_repo_snapshot_sha256": expected_repo_snapshot_sha256,
                "human_labeled": truthy(row.get("human_labeled", False)),
                "synthetic": truthy(row.get("synthetic", False)),
                "maintainer_feedback_ids": set(),
                "labels": [],
            },
        )
        if repo_path and case["repo_path"] and repo_path != case["repo_path"]:
            raise ValueError(f"case {case_id} has conflicting repo_path values")
        if changed_files_from and case["changed_files_from"] and changed_files_from != case["changed_files_from"]:
            raise ValueError(f"case {case_id} has conflicting changed_files_from values")
        if changed_files_from:
            case["changed_files_from"] = changed_files_from
        if allowlist and case["allowlist"] and allowlist != case["allowlist"]:
            raise ValueError(f"case {case_id} has conflicting allowlist values")
        if allowlist:
            case["allowlist"] = allowlist
        if (
            expected_repo_git_head
            and case["expected_repo_git_head"]
            and expected_repo_git_head != case["expected_repo_git_head"]
        ):
            raise ValueError(f"case {case_id} has conflicting expected_repo_git_head values")
        if expected_repo_git_head:
            case["expected_repo_git_head"] = expected_repo_git_head
        if (
            expected_repo_snapshot_sha256
            and case["expected_repo_snapshot_sha256"]
            and expected_repo_snapshot_sha256 != case["expected_repo_snapshot_sha256"]
        ):
            raise ValueError(f"case {case_id} has conflicting expected_repo_snapshot_sha256 values")
        if expected_repo_snapshot_sha256:
            case["expected_repo_snapshot_sha256"] = expected_repo_snapshot_sha256
        case["human_labeled"] = case["human_labeled"] or truthy(row.get("human_labeled", False))
        case["synthetic"] = case["synthetic"] or truthy(row.get("synthetic", False))
        maintainer_id = str(row.get("maintainer_id") or "").strip()
        if maintainer_id and truthy(row.get("maintainer_feedback", False)):
            case["maintainer_feedback_ids"].add(maintainer_id)
        label_id = str(row.get("label_id") or f"{case_id}_label_{len(case['labels']) + 1:03d}")
        expected_line_start, expected_line_end, expected_span_sha256 = normalize_label_citation_expectation(row, case_id, label_id)
        label = {
            "label_id": label_id,
            "source_candidate_label_id": str(
                row.get("source_candidate_label_id") or row.get("candidate_label_id") or ""
            ).strip(),
            "source_review_queue_id": str(row.get("source_review_queue_id") or "").strip(),
            "plugin_id": str(row.get("plugin_id") or ""),
            "rule_id": str(row.get("rule_id") or ""),
            "file_path": str(row.get("file_path") or ""),
            "expected_line_start": expected_line_start,
            "expected_line_end": expected_line_end,
            "expected_span_sha256": expected_span_sha256,
            "expected": str(row.get("expected") or "present"),
            "expected_abstain": row.get("expected_abstain", ""),
            "priority": normalize_label_priority(row.get("priority", ""), case_id, label_id),
            "maintainer_id": maintainer_id,
            "maintainer_feedback": int(bool(maintainer_id and truthy(row.get("maintainer_feedback", False)))),
        }
        if label["expected"] not in {"present", "absent"}:
            raise ValueError(f"label {label['label_id']} expected must be present or absent")
        if label["plugin_id"]:
            case["labels"].append(label)
    return list(cases.values())


def git_text(repo: Path, args: list[str]) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return None
    return result.stdout


def repo_snapshot_payload(row: dict) -> dict:
    return {
        "repo_git_available": int(row["repo_git_available"]),
        "repo_git_head": row["repo_git_head"],
        "repo_git_dirty": int(row["repo_git_dirty"]),
        "repo_git_status_sha256": row["repo_git_status_sha256"],
        "repo_git_tracked_file_count": int(row["repo_git_tracked_file_count"]),
        "repo_git_tracked_files_sha256": row["repo_git_tracked_files_sha256"],
    }


def case_repo_snapshot(case: dict) -> dict:
    repo = Path(case["repo_path"]).expanduser().resolve()
    if not repo.is_dir():
        raise ValueError(f"case {case['case_id']} repo_path is not a directory: {repo}")
    problems: list[str] = []
    expected_head = str(case.get("expected_repo_git_head", "")).strip().lower()
    expected_snapshot = str(case.get("expected_repo_snapshot_sha256", "")).strip()
    inside_worktree = git_text(repo, ["rev-parse", "--is-inside-work-tree"])
    repo_git_available = int(inside_worktree is not None and inside_worktree.strip() == "true")
    repo_git_head = ""
    repo_git_dirty = 0
    repo_git_status_sha256 = sha256_text("")
    repo_git_tracked_file_count = 0
    repo_git_tracked_files_sha256 = sha256_text("")
    if repo_git_available:
        repo_git_head = (git_text(repo, ["rev-parse", "HEAD"]) or "").strip().lower()
        status_text = git_text(repo, ["status", "--porcelain=v1", "--untracked-files=all"]) or ""
        tracked_files_text = git_text(repo, ["ls-files"]) or ""
        repo_git_dirty = int(bool(status_text.strip()))
        repo_git_status_sha256 = sha256_text(status_text)
        tracked_files = [line for line in tracked_files_text.splitlines() if line]
        repo_git_tracked_file_count = len(tracked_files)
        repo_git_tracked_files_sha256 = sha256_text("\n".join(tracked_files) + ("\n" if tracked_files else ""))
        if not repo_git_head:
            problems.append("git_head_missing")
        if repo_git_dirty:
            problems.append("repo_dirty")
    else:
        problems.append("git_worktree_unavailable")
    snapshot_seed = repo_snapshot_payload(
        {
            "repo_git_available": repo_git_available,
            "repo_git_head": repo_git_head,
            "repo_git_dirty": repo_git_dirty,
            "repo_git_status_sha256": repo_git_status_sha256,
            "repo_git_tracked_file_count": repo_git_tracked_file_count,
            "repo_git_tracked_files_sha256": repo_git_tracked_files_sha256,
        }
    )
    repo_snapshot_sha256 = sha256_text(json.dumps(snapshot_seed, sort_keys=True, separators=(",", ":")))
    expected_head_match = int(bool(expected_head) and expected_head == repo_git_head)
    expected_snapshot_match = int(bool(expected_snapshot) and expected_snapshot == repo_snapshot_sha256)
    missing_expectation = int(not bool(expected_head))
    mismatch = int(
        (bool(expected_head) and not bool(expected_head_match))
        or (bool(expected_snapshot) and not bool(expected_snapshot_match))
    )
    if missing_expectation:
        problems.append("expected_repo_git_head_missing")
    if expected_head and not expected_head_match:
        problems.append("expected_repo_git_head_mismatch")
    if expected_snapshot and not expected_snapshot_match:
        problems.append("expected_repo_snapshot_sha256_mismatch")
    locked = int(repo_git_available == 1 and repo_git_dirty == 0 and missing_expectation == 0 and mismatch == 0)
    return {
        "case_id": case["case_id"],
        "repo_path_sha256": sha256_text(str(repo)),
        "repo_git_available": repo_git_available,
        "repo_git_head": repo_git_head,
        "repo_git_dirty": repo_git_dirty,
        "repo_git_status_sha256": repo_git_status_sha256,
        "repo_git_tracked_file_count": repo_git_tracked_file_count,
        "repo_git_tracked_files_sha256": repo_git_tracked_files_sha256,
        "expected_repo_git_head": expected_head,
        "expected_repo_git_head_match": expected_head_match,
        "expected_repo_snapshot_sha256": expected_snapshot,
        "repo_snapshot_sha256": repo_snapshot_sha256,
        "expected_repo_snapshot_sha256_match": expected_snapshot_match,
        "repo_snapshot_missing_expectation": missing_expectation,
        "repo_snapshot_mismatch": mismatch,
        "repo_snapshot_locked": locked,
        "repo_snapshot_problems": "|".join(problems),
    }


def stringify_row(row: dict) -> dict[str, str]:
    return {key: "" if value is None else str(value) for key, value in row.items()}


def assess_label_quality(cases: list[dict]) -> tuple[dict[str, int], list[dict]]:
    label_entries: list[tuple[dict, dict]] = []
    for case in cases:
        for label in case["labels"]:
            label_entries.append((case, label))

    expectation_sets: dict[tuple[str, str, str, str], set[str]] = {}
    for case, label in label_entries:
        exact_key = (
            str(case["case_id"]),
            str(label["plugin_id"]),
            str(label["rule_id"]),
            str(label["file_path"]),
            str(label["expected"]),
        )
        broad_key = exact_key[:4]
        expectation_sets.setdefault(broad_key, set()).add(str(label["expected"]))

    seen_exact: dict[tuple[str, str, str, str, str], int] = {}
    seen_label_ids: dict[tuple[str, str], int] = {}
    rows: list[dict] = []
    for case, label in label_entries:
        exact_key = (
            str(case["case_id"]),
            str(label["plugin_id"]),
            str(label["rule_id"]),
            str(label["file_path"]),
            str(label["expected"]),
        )
        broad_key = exact_key[:4]
        label_id_key = (str(case["case_id"]), str(label["label_id"]))
        seen_exact[exact_key] = seen_exact.get(exact_key, 0) + 1
        seen_label_ids[label_id_key] = seen_label_ids.get(label_id_key, 0) + 1
        is_duplicate = int(seen_exact[exact_key] > 1 or seen_label_ids[label_id_key] > 1)
        citation_expectation_supplied = int(bool(label["expected_line_start"] and label["expected_line_end"] and label["expected_span_sha256"]))
        is_broad = int(not label["rule_id"] or not label["file_path"])
        is_citation_unbound = int(label["expected"] == "present" and not citation_expectation_supplied)
        is_contradictory = int(len(expectation_sets.get(broad_key, set())) > 1)
        is_specific = int(bool(label["plugin_id"] and label["rule_id"] and label["file_path"]))
        rows.append(
            {
                "case_id": case["case_id"],
                "label_id": label["label_id"],
                "plugin_id": label["plugin_id"],
                "rule_id": label["rule_id"],
                "file_path": label["file_path"],
                "expected_line_start": label["expected_line_start"],
                "expected_line_end": label["expected_line_end"],
                "expected_span_sha256": label["expected_span_sha256"],
                "expected": label["expected"],
                "priority": label.get("priority", ""),
                "is_broad": is_broad,
                "is_citation_unbound": is_citation_unbound,
                "citation_expectation_supplied": citation_expectation_supplied,
                "is_duplicate": is_duplicate,
                "is_contradictory": is_contradictory,
                "is_specific": is_specific,
            }
        )

    total_rows = len(rows)
    broad_rows = sum(int(row["is_broad"]) for row in rows)
    citation_unbound_rows = sum(int(row["is_citation_unbound"]) for row in rows)
    duplicate_rows = sum(int(row["is_duplicate"]) for row in rows)
    contradictory_rows = sum(int(row["is_contradictory"]) for row in rows)
    specific_rows = sum(int(row["is_specific"]) for row in rows)
    metrics = {
        "label_quality_total_rows": total_rows,
        "label_quality_specific_rows": specific_rows,
        "label_quality_broad_rows": broad_rows,
        "label_quality_citation_unbound_rows": citation_unbound_rows,
        "label_quality_duplicate_rows": duplicate_rows,
        "label_quality_contradictory_rows": contradictory_rows,
        "label_quality_requirement_met": int(
            total_rows > 0
            and broad_rows == 0
            and citation_unbound_rows == 0
            and duplicate_rows == 0
            and contradictory_rows == 0
        ),
    }
    return metrics, rows


def normalize_maintainer_feedback(raw_rows: list[dict], cases: list[dict]) -> list[dict]:
    cases_by_id = {case["case_id"]: case for case in cases}
    rows: list[dict] = []
    seen_feedback_ids: set[str] = set()
    for idx, row in enumerate(raw_rows, start=1):
        case_id = str(row.get("case_id") or "").strip()
        if not case_id:
            raise ValueError(f"feedback row {idx} missing case_id")
        if case_id not in cases_by_id:
            raise ValueError(f"feedback row {idx} references unknown case_id: {case_id}")
        feedback_id = str(row.get("feedback_id") or f"feedback_{idx:04d}").strip()
        if not SAFE_FEEDBACK_ID.fullmatch(feedback_id):
            raise ValueError(f"feedback row {idx} has unsafe feedback_id: {feedback_id}")
        if feedback_id in seen_feedback_ids:
            raise ValueError(f"feedback row {idx} duplicates feedback_id: {feedback_id}")
        seen_feedback_ids.add(feedback_id)
        maintainer_id = str(row.get("maintainer_id") or "").strip()
        if not maintainer_id:
            raise ValueError(f"feedback row {idx} missing maintainer_id")
        feedback_text = str(row.get("feedback_text") or "")
        provided_sha = str(row.get("feedback_text_sha256") or row.get("feedback_sha256") or "").strip()
        if feedback_text:
            feedback_sha = sha256_text(feedback_text)
            feedback_text_bytes = len(feedback_text.encode("utf-8"))
        else:
            feedback_sha = provided_sha
            feedback_text_bytes = 0
        if not is_sha256_digest(feedback_sha):
            raise ValueError(f"feedback row {idx} must include feedback_text or a sha256 feedback_text_sha256")
        human_feedback = truthy(row.get("human_feedback", row.get("maintainer_feedback", False)))
        synthetic = truthy(row.get("synthetic", False)) or bool(cases_by_id[case_id]["synthetic"])
        counts_for_beta = int(
            human_feedback
            and not synthetic
            and bool(cases_by_id[case_id]["human_labeled"])
            and not bool(cases_by_id[case_id]["synthetic"])
        )
        rows.append(
            {
                "feedback_id": feedback_id,
                "case_id": case_id,
                "feedback_source": "feedback_file",
                "maintainer_id_sha256": sha256_text(maintainer_id),
                "human_feedback": int(human_feedback),
                "synthetic": int(synthetic),
                "counts_for_beta": counts_for_beta,
                "feedback_text_sha256": feedback_sha,
                "feedback_text_bytes": feedback_text_bytes,
            }
        )
    return rows


def normalize_expected_abstain(value) -> str:
    if value == "":
        return ""
    return "1" if str(value).lower() in {"1", "true", "yes"} else "0"


def finding_matches(label: dict, finding: dict[str, str], citation_files: set[str]) -> bool:
    if label["plugin_id"] and finding.get("plugin_id") != label["plugin_id"]:
        return False
    if label["rule_id"]:
        rule_ids = set(str(finding.get("plugin_rule_ids", "")).split("|"))
        if label["rule_id"] not in rule_ids:
            return False
    if label["file_path"] and label["file_path"] not in citation_files:
        return False
    expected_abstain = normalize_expected_abstain(label.get("expected_abstain", ""))
    if expected_abstain != "":
        if finding.get("abstain") != expected_abstain:
            return False
    return True


def label_citation_match(label: dict, matched: dict, citations_by_finding: dict[str, list[dict[str, str]]]) -> tuple[str, str]:
    if not (label["expected_line_start"] and label["expected_line_end"] and label["expected_span_sha256"]):
        return "", ""
    finding_id = str(matched.get("finding_id", ""))
    if not finding_id:
        return "", "0"
    for citation in citations_by_finding.get(finding_id, []):
        if (
            citation.get("file_path", "") == label["file_path"]
            and citation.get("line_start", "") == label["expected_line_start"]
            and citation.get("line_end", "") == label["expected_line_end"]
            and citation.get("span_sha256", "") == label["expected_span_sha256"]
        ):
            return citation.get("citation_id", ""), "1"
    return "", "0"


def verify_audit_output(root: Path, out_dir: Path) -> int:
    result = subprocess.run(
        [sys.executable, str(root / "tools" / "verify_local_audit.py"), str(out_dir)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.returncode


def audit_manifest(out_dir: Path) -> dict:
    return json.loads((out_dir / "audit_manifest.json").read_text(encoding="utf-8"))


def run_audit(root: Path, case: dict, out_dir: Path, args: argparse.Namespace) -> dict:
    repo = Path(case["repo_path"]).expanduser().resolve()
    if not repo.is_dir():
        raise ValueError(f"case {case['case_id']} repo_path is not a directory: {repo}")
    cmd = [
        str(root / "scripts" / "audit_my_repo.sh"),
        str(repo),
        "--mode",
        args.mode,
        "--max-files",
        str(args.max_files),
        "--max-total-bytes",
        str(args.max_total_bytes),
        "--max-file-bytes",
        str(args.max_file_bytes),
        "--max-findings",
        str(args.max_findings),
        "--out",
        str(out_dir),
        "--namespace",
        args.namespace,
        "--generator",
        "routehint-tiny",
    ]
    if args.namespace == "real_benchmark":
        cmd.append("--confirm-real-benchmark-namespace")
    if case.get("changed_files_from"):
        cmd.extend(["--changed-files-from", str(case["changed_files_from"])])
    if case.get("allowlist"):
        cmd.extend(["--allowlist", str(case["allowlist"])])
    start_ns = time.perf_counter_ns()
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    wall_ms = max(1, int(round((time.perf_counter_ns() - start_ns) / 1_000_000)))
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        raise RuntimeError(f"audit failed for case {case['case_id']}{suffix}")
    verify_rc = verify_audit_output(root, out_dir)
    if verify_rc != 0:
        raise RuntimeError(f"audit verifier failed for case {case['case_id']}")
    manifest = audit_manifest(out_dir)
    return {
        "case_id": case["case_id"],
        "audit_exit_code": result.returncode,
        "verify_exit_code": verify_rc,
        "first_report_success": int((out_dir / "AUDIT_REPORT.md").is_file()),
        "first_report_wall_ms": wall_ms,
        "cache_key": str(manifest.get("cache_key", "")),
        "semantic_result_sha256": semantic_result_sha(out_dir),
        "source_scope": str(manifest.get("source_scope", "")),
        "source_file_count": int(manifest.get("source_file_count", 0)),
        "changed_files_from": str(manifest.get("changed_files_from", "")),
        "changed_files_from_sha256": str(manifest.get("changed_files_from_sha256", "")),
        "changed_file_rows": int(manifest.get("changed_file_rows", 0)),
        **standard_json_findings_metrics(out_dir),
    }


def rerun_audit(root: Path, case: dict, out_dir: Path, args: argparse.Namespace, first_run: dict) -> dict:
    second = run_audit(root, case, out_dir, args)
    return {
        "rerun_checked": 1,
        "rerun_exit_code": second["audit_exit_code"],
        "rerun_verify_exit_code": second["verify_exit_code"],
        "rerun_wall_ms": second["first_report_wall_ms"],
        "rerun_cache_key_match": int(second["cache_key"] == first_run["cache_key"]),
        "rerun_semantic_result_match": int(second["semantic_result_sha256"] == first_run["semantic_result_sha256"]),
        "rerun_success": int(
            second["audit_exit_code"] == 0
            and second["verify_exit_code"] == 0
            and second["cache_key"] == first_run["cache_key"]
            and second["semantic_result_sha256"] == first_run["semantic_result_sha256"]
        ),
    }


def citation_validity_rows(case: dict, out_dir: Path) -> list[dict]:
    repo = Path(case["repo_path"]).expanduser().resolve()
    source_manifest = {
        row.get("file_path", ""): row.get("sha256", "")
        for row in read_csv(out_dir / "source_manifest.csv")
    }
    rows: list[dict] = []
    for citation in read_csv(out_dir / "citation_spans.csv"):
        rel = citation.get("file_path", "")
        source_path = repo / rel
        checks = {
            "file_exists": 0,
            "file_sha256_valid": 0,
            "source_manifest_sha256_valid": 0,
            "line_bounds_valid": 0,
            "span_sha256_valid": 0,
            "span_preview_valid": 0,
        }
        reasons: list[str] = []
        lines: list[str] = []
        if source_path.is_file():
            checks["file_exists"] = 1
            actual_sha = sha256_file(source_path)
            if actual_sha == citation.get("sha256", ""):
                checks["file_sha256_valid"] = 1
            else:
                reasons.append("file_sha256_mismatch")
            if source_manifest.get(rel) == citation.get("sha256", ""):
                checks["source_manifest_sha256_valid"] = 1
            else:
                reasons.append("source_manifest_sha256_mismatch")
            lines = source_path.read_text(encoding="utf-8", errors="replace").splitlines()
        else:
            reasons.append("source_file_missing")
        try:
            line_start = int(citation.get("line_start", "0"))
            line_end = int(citation.get("line_end", "0"))
        except ValueError:
            line_start = 0
            line_end = 0
            reasons.append("line_bounds_not_integer")
        if lines and 1 <= line_start <= line_end <= len(lines):
            checks["line_bounds_valid"] = 1
            span_text = "\n".join(line.strip() for line in lines[line_start - 1:line_end])
            if sha256_text(span_text) == citation.get("span_sha256", ""):
                checks["span_sha256_valid"] = 1
            else:
                reasons.append("span_sha256_mismatch")
            if lines[line_start - 1].strip()[:280] == citation.get("span_text_preview", ""):
                checks["span_preview_valid"] = 1
            else:
                reasons.append("span_preview_mismatch")
        elif "line_bounds_not_integer" not in reasons:
            reasons.append("line_bounds_invalid")
        citation_valid = int(all(checks.values()))
        rows.append(
            {
                "case_id": case["case_id"],
                "finding_id": citation.get("finding_id", ""),
                "citation_id": citation.get("citation_id", ""),
                "file_path": rel,
                "line_start": citation.get("line_start", ""),
                "line_end": citation.get("line_end", ""),
                **checks,
                "citation_valid": citation_valid,
                "invalid_reasons": "|".join(reasons),
            }
        )
    return rows


def evaluate_case(case: dict, out_dir: Path) -> tuple[list[dict], list[dict], list[dict], list[dict], list[dict], list[dict], dict]:
    findings = [row for row in read_csv(out_dir / "audit_findings.csv") if row.get("suppressed", "0") != "1"]
    citations = read_csv(out_dir / "citation_spans.csv")
    citation_validity = citation_validity_rows(case, out_dir)
    citation_files_by_finding: dict[str, set[str]] = {}
    citations_by_finding: dict[str, list[dict[str, str]]] = {}
    for row in citations:
        citation_files_by_finding.setdefault(row["finding_id"], set()).add(row["file_path"])
        citations_by_finding.setdefault(row["finding_id"], []).append(row)

    label_rows: list[dict] = []
    label_citation_rows: list[dict] = []
    confusion_rows: list[dict] = []
    abstain_correctness_rows: list[dict] = []
    matched_finding_ids: set[str] = set()
    tp = fp = fn = abstain_checked = abstain_correct = 0
    label_citation_expectation_rows = label_citation_expectation_met_rows = 0
    p0_p1_tp = p0_p1_fp = p0_p1_fn = 0
    for label in case["labels"]:
        matches = [
            finding
            for finding in findings
            if finding_matches(label, finding, citation_files_by_finding.get(finding["finding_id"], set()))
        ]
        is_p0_p1 = str(label.get("priority", "")).upper() in {"P0", "P1"}
        if label["expected"] == "present":
            if matches:
                matched_finding_ids.add(matches[0]["finding_id"])
                tp += 1
                if is_p0_p1:
                    p0_p1_tp += 1
                outcome = "TP"
            else:
                fn += 1
                if is_p0_p1:
                    p0_p1_fn += 1
                outcome = "FN"
        else:
            if matches:
                matched_finding_ids.add(matches[0]["finding_id"])
                fp += 1
                if is_p0_p1:
                    p0_p1_fp += 1
                outcome = "FP"
            else:
                outcome = "TN"
        matched = matches[0] if matches else {}
        citation_expectation_supplied = int(bool(label["expected_line_start"] and label["expected_line_end"] and label["expected_span_sha256"]))
        matched_citation_id, citation_expectation_met = label_citation_match(label, matched, citations_by_finding)
        if citation_expectation_supplied:
            label_citation_expectation_rows += 1
            label_citation_expectation_met_rows += int(citation_expectation_met == "1")
        expected_abstain = normalize_expected_abstain(label.get("expected_abstain", ""))
        if label.get("expected_abstain", "") != "":
            abstain_checked += 1
            if outcome in {"TP", "TN"}:
                abstain_correct += 1
            abstain_correctness_rows.append(
                {
                    "case_id": case["case_id"],
                    "label_id": label["label_id"],
                    "plugin_id": label["plugin_id"],
                    "rule_id": label["rule_id"],
                    "file_path": label["file_path"],
                    "expected": label["expected"],
                    "expected_abstain": expected_abstain,
                    "matched_finding_id": matched.get("finding_id", ""),
                    "actual_abstain": matched.get("abstain", ""),
                    "outcome": outcome,
                    "abstain_correct": int(outcome in {"TP", "TN"}),
                }
            )
        confusion_rows.append(
            {
                "case_id": case["case_id"],
                "row_type": "human_label",
                "label_id": label["label_id"],
                "plugin_id": label["plugin_id"],
                "rule_id": label["rule_id"],
                "file_path": label["file_path"],
                "expected_line_start": label["expected_line_start"],
                "expected_line_end": label["expected_line_end"],
                "expected_span_sha256": label["expected_span_sha256"],
                "expected": label["expected"],
                "priority": label.get("priority", ""),
                "matched_finding_id": matched.get("finding_id", ""),
                "citation_expectation_supplied": citation_expectation_supplied,
                "matched_citation_id": matched_citation_id,
                "citation_expectation_met": citation_expectation_met,
                "outcome": outcome,
                "tp": int(outcome == "TP"),
                "fp": int(outcome == "FP"),
                "fn": int(outcome == "FN"),
                "tn": int(outcome == "TN"),
            }
        )
        label_citation_rows.append(
            {
                "case_id": case["case_id"],
                "label_id": label["label_id"],
                "plugin_id": label["plugin_id"],
                "rule_id": label["rule_id"],
                "file_path": label["file_path"],
                "expected_line_start": label["expected_line_start"],
                "expected_line_end": label["expected_line_end"],
                "expected_span_sha256": label["expected_span_sha256"],
                "expected": label["expected"],
                "citation_expectation_supplied": citation_expectation_supplied,
                "matched_finding_id": matched.get("finding_id", ""),
                "matched_citation_id": matched_citation_id,
                "citation_expectation_met": citation_expectation_met,
                "outcome": "citation_unbound" if label["expected"] == "present" and not citation_expectation_supplied else outcome,
            }
        )
        label_rows.append(
            {
                "case_id": case["case_id"],
                **label,
                "expected_abstain": expected_abstain,
                "citation_expectation_supplied": citation_expectation_supplied,
                "matched_citation_id": matched_citation_id,
                "citation_expectation_met": citation_expectation_met,
                "outcome": outcome,
            }
        )

    positive_label_plugins = {label["plugin_id"] for label in case["labels"] if label["expected"] == "present"}
    for finding in findings:
        if finding["finding_id"] in matched_finding_ids:
            continue
        if finding["plugin_id"] in positive_label_plugins and finding.get("abstain") != "1":
            fp += 1
            confusion_rows.append(
                {
                    "case_id": case["case_id"],
                    "row_type": "unmatched_finding",
                    "label_id": "",
                    "plugin_id": finding.get("plugin_id", ""),
                    "rule_id": finding.get("plugin_rule_ids", ""),
                    "file_path": "",
                    "expected_line_start": "",
                    "expected_line_end": "",
                    "expected_span_sha256": "",
                    "expected": "absent",
                    "priority": "",
                    "matched_finding_id": finding.get("finding_id", ""),
                    "citation_expectation_supplied": 0,
                    "matched_citation_id": "",
                    "citation_expectation_met": "",
                    "outcome": "FP",
                    "tp": 0,
                    "fp": 1,
                    "fn": 0,
                    "tn": 0,
                }
            )

    citation_validity_count = len(citation_validity)
    citation_validity_pass_rows = sum(int(row["citation_valid"]) for row in citation_validity)
    metrics = {
        "case_id": case["case_id"],
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "p0_p1_tp": p0_p1_tp,
        "p0_p1_fp": p0_p1_fp,
        "p0_p1_fn": p0_p1_fn,
        "abstain_checked": abstain_checked,
        "abstain_correct": abstain_correct,
        "citation_validity_rows": citation_validity_count,
        "citation_validity_pass_rows": citation_validity_pass_rows,
        "label_citation_expectation_rows": label_citation_expectation_rows,
        "label_citation_expectation_met_rows": label_citation_expectation_met_rows,
    }
    finding_rows = [{"case_id": case["case_id"], **finding} for finding in findings]
    return label_rows, finding_rows, citation_validity, confusion_rows, abstain_correctness_rows, label_citation_rows, metrics


def case_runs_manifest_sha256(out_dir: Path, case_ids: list[str]) -> str:
    digest = hashlib.sha256()
    for case_id in sorted(case_ids):
        rel = f"case_runs/{case_id}/audit_manifest.json"
        path = out_dir / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256_file(path).encode("utf-8"))
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def benchmark_artifact_sha256s(out_dir: Path) -> dict[str, str]:
    return {rel: sha256_file(out_dir / rel) for rel in BENCHMARK_ARTIFACTS}


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def prepare_benchmark_output_dir(out_dir: Path, overwrite: bool) -> Path | None:
    if not out_dir.exists():
        out_dir.mkdir(parents=True)
        return None
    if not out_dir.is_dir():
        raise ValueError(f"benchmark output path is not a directory: {out_dir}")
    children = list(out_dir.iterdir())
    if not children:
        return None
    if not overwrite:
        raise ValueError("benchmark output directory already contains artifacts; use a fresh --out or pass --overwrite")
    for child in children:
        if child.name not in BENCHMARK_MANAGED_TOP_LEVEL:
            raise ValueError(f"refusing to delete unrelated benchmark output entry: {child.name}; use a fresh --out")
    backup_dir = Path(tempfile.mkdtemp(prefix=f".{out_dir.name}.benchmark_backup.", dir=out_dir.parent))
    for child in children:
        os.replace(child, backup_dir / child.name)
    return backup_dir


def rollback_benchmark_output_dir(out_dir: Path, backup_dir: Path | None) -> None:
    if out_dir.exists():
        for child in list(out_dir.iterdir()):
            if child.name in BENCHMARK_MANAGED_TOP_LEVEL:
                remove_path(child)
    else:
        out_dir.mkdir(parents=True, exist_ok=True)
    if backup_dir is not None and backup_dir.exists():
        for child in list(backup_dir.iterdir()):
            os.replace(child, out_dir / child.name)
        shutil.rmtree(backup_dir, ignore_errors=True)


def commit_benchmark_output_dir(backup_dir: Path | None) -> None:
    if backup_dir is not None:
        shutil.rmtree(backup_dir, ignore_errors=True)


def benchmark_fail_after_cases_requested() -> bool:
    return os.environ.get("AUDIT_MY_REPO_BENCHMARK_FAIL_AFTER_CASES") == "1"


def write_benchmark_findings_json(path: Path, rows: list[dict]) -> None:
    payload = {
        "schema_version": "local_repo_audit_benchmark_findings.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "finding_rows": len(rows),
        "rows": [stringify_row(row) for row in rows],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_benchmark_labels_json(path: Path, rows: list[dict]) -> None:
    payload = {
        "schema_version": "local_repo_audit_benchmark_labels.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "human_label_rows": len(rows),
        "rows": [stringify_row(row) for row in rows],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_benchmark_label_citation_expectations_json(path: Path, rows: list[dict]) -> None:
    payload = {
        "schema_version": "local_repo_audit_benchmark_label_citation_expectations.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "label_rows": len(rows),
        "citation_expectation_rows": sum(int(row.get("citation_expectation_supplied", 0)) for row in rows),
        "citation_expectation_met_rows": sum(1 for row in rows if str(row.get("citation_expectation_met", "")) == "1"),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "rows": [stringify_row(row) for row in rows],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_benchmark_evaluation_json(
    path: Path,
    summary: dict,
    confusion_rows: list[dict],
    abstain_rows: list[dict],
    citation_rows: list[dict],
) -> None:
    payload = {
        "schema_version": "local_repo_audit_benchmark_evaluation.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "metrics": {key: summary[key] for key in BENCHMARK_EVALUATION_SUMMARY_FIELDS},
        "confusion_rows": len(confusion_rows),
        "abstain_correctness_rows": len(abstain_rows),
        "citation_validity_detail_rows": len(citation_rows),
        "confusion": [stringify_row(row) for row in confusion_rows],
        "abstain_correctness": [stringify_row(row) for row in abstain_rows],
        "citation_validity": [stringify_row(row) for row in citation_rows],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def readiness_gate_rows(summary: dict) -> list[dict[str, str | int]]:
    rows: list[dict[str, str | int]] = []
    for gate_id, observed_key, required_key, description in READINESS_GATES:
        passed = int(str(summary.get(gate_id, "0")) == "1")
        rows.append(
            {
                "gate_id": gate_id,
                "passed": passed,
                "observed": str(summary.get(observed_key, "")),
                "required": str(summary.get(required_key, "")),
                "blocked_reason": "" if passed else description,
            }
        )
    return rows


def write_benchmark_readiness_json(path: Path, summary: dict) -> None:
    rows = readiness_gate_rows(summary)
    blocked_rows = sum(1 for row in rows if int(row["passed"]) == 0)
    payload = {
        "schema_version": "local_repo_audit_benchmark_readiness.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "product_readiness_calculated_from_real_labels": int(summary["product_readiness_calculated_from_real_labels"]),
        "design_partner_beta_candidate_ready": int(summary["design_partner_beta_candidate_ready"]),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "gate_rows": len(rows),
        "passed_gate_rows": len(rows) - blocked_rows,
        "blocked_gate_rows": blocked_rows,
        "rows": rows,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sort_rows_for_compare(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return sorted(rows, key=lambda row: json.dumps(row, sort_keys=True, separators=(",", ":")))


def write_benchmark_sha_manifest(out_dir: Path, rel_paths: list[str]) -> None:
    lines: list[str] = []
    seen: set[str] = set()
    for rel in rel_paths:
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts or rel in seen:
            raise ValueError(f"invalid benchmark sha manifest path: {rel}")
        seen.add(rel)
        lines.append(f"{sha256_hex(out_dir / rel)}  {rel}")
    (out_dir / "benchmark_sha256sums.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_benchmark_manifest(
    root: Path,
    out_dir: Path,
    args: argparse.Namespace,
    labels_path: Path,
    labels_input_sha256: str,
    label_source_kind: str,
    label_intake_output: Path | None,
    label_intake_manifest_sha256: str,
    label_intake_sha256sums_sha256: str,
    feedback_path: Path | None,
    feedback_input_sha256: str,
    case_ids: list[str],
    summary: dict,
) -> None:
    manifest = {
        "schema_version": "local_repo_audit_benchmark_manifest.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "benchmark_runner_source_sha256": sha256_file(root / "scripts" / "audit_my_repo_benchmark.py"),
        "audit_entrypoint_source_sha256": sha256_file(root / "scripts" / "audit_my_repo.py"),
        "local_audit_verifier_source_sha256": sha256_file(root / "tools" / "verify_local_audit.py"),
        "labels_input": str(labels_path),
        "labels_input_sha256": labels_input_sha256,
        "label_source_kind": label_source_kind,
        "label_intake_output": "" if label_intake_output is None else str(label_intake_output),
        "label_intake_manifest_sha256": label_intake_manifest_sha256,
        "label_intake_sha256sums_sha256": label_intake_sha256sums_sha256,
        "feedback_input": "" if feedback_path is None else str(feedback_path),
        "feedback_input_sha256": feedback_input_sha256,
        "mode": args.mode,
        "namespace": args.namespace,
        "real_benchmark_namespace_confirmed": int(args.namespace == "real_benchmark" and bool(args.confirm_real_benchmark_namespace)),
        "rerun_check_requested": int(bool(args.rerun_check)),
        "max_files": args.max_files,
        "max_total_bytes": args.max_total_bytes,
        "max_file_bytes": args.max_file_bytes,
        "max_findings": args.max_findings,
        "case_rows": int(summary["case_rows"]),
        "human_label_rows": int(summary["human_label_rows"]),
        "maintainer_feedback_rows": int(summary["maintainer_feedback_rows"]),
        "repo_snapshot_rows": int(summary["repo_snapshot_rows"]),
        "repo_snapshot_locked_rows": int(summary["repo_snapshot_locked_rows"]),
        "repo_snapshot_requirement_met": int(summary["repo_snapshot_requirement_met"]),
        "case_ids": sorted(case_ids),
        "case_run_manifest_sha256s": {
            case_id: sha256_file(out_dir / "case_runs" / case_id / "audit_manifest.json")
            for case_id in sorted(case_ids)
        },
        "case_runs_manifest_sha256": case_runs_manifest_sha256(out_dir, case_ids),
        "artifact_sha256s": benchmark_artifact_sha256s(out_dir),
        "overall_precision_threshold": f"{OVERALL_PRECISION_THRESHOLD:.6f}",
        "p0_p1_precision_threshold": f"{P0_P1_PRECISION_THRESHOLD:.6f}",
        "product_readiness_calculated_from_real_labels": int(summary["product_readiness_calculated_from_real_labels"]),
        "design_partner_beta_candidate_ready": int(summary["design_partner_beta_candidate_ready"]),
        "synthetic_smoke_promoted_to_real_benchmark": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    (out_dir / "benchmark_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_benchmark_sha_manifest(
        out_dir,
        [
            "benchmark_manifest.json",
            *BENCHMARK_ARTIFACTS,
            *[f"case_runs/{case_id}/audit_manifest.json" for case_id in sorted(case_ids)],
        ],
    )


def read_benchmark_sha_manifest(path: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            raise ValueError("benchmark_sha256sums.txt has an invalid row")
        digest, rel = parts
        rel = rel.strip()
        rel_path = Path(rel)
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError(f"benchmark sha row has invalid digest: {rel}")
        if rel in rows or rel_path.is_absolute() or ".." in rel_path.parts:
            raise ValueError(f"benchmark sha row has invalid path: {rel}")
        rows[rel] = digest
    return rows


def verify_benchmark_artifact_layout(out_dir: Path, manifest: dict, add) -> None:
    case_ids = {str(case_id) for case_id in manifest.get("case_ids", [])}
    allowed_top_level = set(BENCHMARK_ARTIFACTS) | {"benchmark_manifest.json", "benchmark_sha256sums.txt", "case_runs"}
    for child in sorted(out_dir.iterdir()):
        if child.name not in allowed_top_level:
            add(f"benchmark output contains unmanifested top-level artifact: {child.name}")
            continue
        if child.name != "case_runs":
            if child.is_symlink() or not child.is_file():
                add(f"benchmark output artifact must be a regular file: {child.name}")
            continue
        if child.is_symlink() or not child.is_dir():
            add("benchmark output case_runs must be a directory")

    case_runs_dir = out_dir / "case_runs"
    if not case_ids:
        if case_runs_dir.exists():
            add("benchmark output case_runs exists without manifest case_ids")
        return
    if not case_runs_dir.is_dir() or case_runs_dir.is_symlink():
        add("benchmark output missing case_runs directory")
        return
    for child in sorted(case_runs_dir.iterdir()):
        if child.name not in case_ids:
            add(f"benchmark output contains unmanifested case run: case_runs/{child.name}")
            continue
        if child.is_symlink() or not child.is_dir():
            add(f"benchmark case run must be a directory: case_runs/{child.name}")
    for case_id in sorted(case_ids):
        if not (case_runs_dir / case_id).is_dir():
            add(f"benchmark output missing manifest case run: case_runs/{case_id}")


def verify_benchmark_schema_instances(root: Path, out_dir: Path, errors: list[str]) -> None:
    validator = root / "tools" / "validate_json_schemas.py"
    for schema_rel, instance_rel in BENCHMARK_SCHEMA_INSTANCE_PAIRS:
        result = subprocess.run(
            [
                sys.executable,
                str(validator),
                "--schema-instance",
                str(root / schema_rel),
                str(out_dir / instance_rel),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip().splitlines()
            suffix = f": {detail[0]}" if detail else ""
            errors.append(f"benchmark schema validation failed: {instance_rel}{suffix}")


def verify_label_intake_bundle(root: Path, label_intake_dir: Path) -> list[str]:
    errors: list[str] = []
    if is_forbidden_env_path(label_intake_dir):
        return ["label intake output must not be .env-like"]
    if not label_intake_dir.is_dir():
        return [f"label intake output is not a directory: {label_intake_dir}"]
    result = subprocess.run(
        [
            sys.executable,
            str(root / "scripts" / "audit_my_repo_label_intake.py"),
            "--verify-existing",
            str(label_intake_dir),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        errors.append(f"label intake verification failed{suffix}")
    return errors


def verify_benchmark_output(root: Path, out_dir: Path) -> list[str]:
    errors: list[str] = []

    def add(message: str) -> None:
        errors.append(message)

    manifest_path = out_dir / "benchmark_manifest.json"
    sha_manifest_path = out_dir / "benchmark_sha256sums.txt"
    if not manifest_path.is_file():
        return ["missing benchmark_manifest.json"]
    if not sha_manifest_path.is_file():
        return ["missing benchmark_sha256sums.txt"]
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        summary = json.loads((out_dir / "benchmark_summary.json").read_text(encoding="utf-8"))
        sha_rows = read_benchmark_sha_manifest(sha_manifest_path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return [str(exc)]

    for key, expected in {
        "schema_version": "local_repo_audit_benchmark_manifest.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "benchmark_runner_source_sha256": sha256_file(root / "scripts" / "audit_my_repo_benchmark.py"),
        "audit_entrypoint_source_sha256": sha256_file(root / "scripts" / "audit_my_repo.py"),
        "local_audit_verifier_source_sha256": sha256_file(root / "tools" / "verify_local_audit.py"),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "synthetic_smoke_promoted_to_real_benchmark": 0,
    }.items():
        if manifest.get(key) != expected:
            add(f"benchmark_manifest.{key} mismatch")
    if manifest.get("namespace") not in {"fixture", "synthetic", "real_benchmark"}:
        add("benchmark_manifest.namespace invalid")
    if manifest.get("real_benchmark_namespace_confirmed") not in {0, 1}:
        add("benchmark_manifest.real_benchmark_namespace_confirmed invalid")
    elif manifest.get("namespace") == "real_benchmark" and manifest.get("real_benchmark_namespace_confirmed") != 1:
        add("real_benchmark benchmark manifest must carry explicit namespace confirmation")
    elif manifest.get("namespace") != "real_benchmark" and manifest.get("real_benchmark_namespace_confirmed") != 0:
        add("non-real benchmark manifest must not carry real_benchmark namespace confirmation")
    if manifest.get("mode") not in {"quick", "full"}:
        add("benchmark_manifest.mode invalid")
    if str(manifest.get("case_rows")) != str(summary.get("case_rows")):
        add("benchmark manifest case_rows drift")
    if str(manifest.get("human_label_rows")) != str(summary.get("human_label_rows")):
        add("benchmark manifest human_label_rows drift")
    if str(manifest.get("maintainer_feedback_rows")) != str(summary.get("maintainer_feedback_rows")):
        add("benchmark manifest maintainer_feedback_rows drift")
    if str(manifest.get("repo_snapshot_rows")) != str(summary.get("repo_snapshot_rows")):
        add("benchmark manifest repo_snapshot_rows drift")
    if str(manifest.get("repo_snapshot_locked_rows")) != str(summary.get("repo_snapshot_locked_rows")):
        add("benchmark manifest repo_snapshot_locked_rows drift")
    for key in [
        "product_readiness_calculated_from_real_labels",
        "design_partner_beta_candidate_ready",
        "repo_snapshot_requirement_met",
        "release_ready",
        "public_comparison_claim_ready",
        "real_model_execution_ready",
    ]:
        if str(manifest.get(key)) != str(summary.get(key)):
            add(f"benchmark manifest/summary readiness drift: {key}")
    if manifest.get("overall_precision_threshold") != f"{OVERALL_PRECISION_THRESHOLD:.6f}":
        add("benchmark manifest overall precision threshold drift")
    if manifest.get("p0_p1_precision_threshold") != f"{P0_P1_PRECISION_THRESHOLD:.6f}":
        add("benchmark manifest P0/P1 precision threshold drift")
    verify_benchmark_artifact_layout(out_dir, manifest, add)

    labels_input = Path(str(manifest.get("labels_input", "")))
    if is_forbidden_env_path(labels_input):
        add("benchmark labels input must not be .env-like")
    elif not labels_input.is_file():
        add("benchmark labels input missing")
    elif manifest.get("labels_input_sha256") != sha256_file(labels_input):
        add("benchmark labels input sha mismatch")
    label_source_kind = str(manifest.get("label_source_kind", ""))
    if label_source_kind not in {"direct_labels", "label_intake"}:
        add("benchmark_manifest.label_source_kind invalid")
    elif label_source_kind == "direct_labels":
        if manifest.get("label_intake_output") != "":
            add("direct-label benchmark must not bind a label intake output")
        if manifest.get("label_intake_manifest_sha256") != sha256_text(""):
            add("direct-label benchmark must bind empty label intake manifest sha")
        if manifest.get("label_intake_sha256sums_sha256") != sha256_text(""):
            add("direct-label benchmark must bind empty label intake sha manifest sha")
    else:
        label_intake_output = Path(str(manifest.get("label_intake_output", "")))
        if not str(manifest.get("label_intake_output", "")):
            add("label-intake benchmark must bind label_intake_output")
        elif not label_intake_output.is_absolute():
            add("label-intake output path must be absolute")
        elif is_forbidden_env_path(label_intake_output):
            add("benchmark label intake output must not be .env-like")
        else:
            for error in verify_label_intake_bundle(root, label_intake_output):
                add(f"benchmark {error}")
            expected_labels = label_intake_output / "benchmark_labels.jsonl"
            if labels_input != expected_labels:
                add("label-intake benchmark labels_input must be the intake benchmark_labels.jsonl")
            label_intake_manifest_path = label_intake_output / "label_intake_manifest.json"
            label_intake_sha_path = label_intake_output / "label_intake_sha256sums.txt"
            if not label_intake_manifest_path.is_file():
                add("benchmark label intake manifest missing")
            elif manifest.get("label_intake_manifest_sha256") != sha256_file(label_intake_manifest_path):
                add("benchmark label intake manifest sha mismatch")
            if not label_intake_sha_path.is_file():
                add("benchmark label intake sha manifest missing")
            elif manifest.get("label_intake_sha256sums_sha256") != sha256_file(label_intake_sha_path):
                add("benchmark label intake sha manifest sha mismatch")
    feedback_input = str(manifest.get("feedback_input", ""))
    if feedback_input:
        feedback_path = Path(feedback_input)
        if is_forbidden_env_path(feedback_path):
            add("benchmark feedback input must not be .env-like")
        elif not feedback_path.is_file():
            add("benchmark feedback input missing")
        elif manifest.get("feedback_input_sha256") != sha256_file(feedback_path):
            add("benchmark feedback input sha mismatch")
    elif manifest.get("feedback_input_sha256") != sha256_text(""):
        add("empty benchmark feedback input must bind empty sha")

    artifact_sha256s = manifest.get("artifact_sha256s", {})
    if set(artifact_sha256s) != set(BENCHMARK_ARTIFACTS):
        add("benchmark manifest artifact set drift")
    for rel in BENCHMARK_ARTIFACTS:
        path = out_dir / rel
        if not path.is_file():
            add(f"missing benchmark artifact: {rel}")
            continue
        if artifact_sha256s.get(rel) != sha256_file(path):
            add(f"benchmark artifact sha mismatch: {rel}")
    verify_benchmark_schema_instances(root, out_dir, errors)
    try:
        label_quality_rows = read_csv(out_dir / "benchmark_label_quality.csv")
    except OSError as exc:
        add(f"benchmark label quality read failed: {exc}")
        label_quality_rows = []

    def csv_int(row: dict[str, str], key: str) -> int:
        try:
            return int(row.get(key, "0"))
        except ValueError:
            add(f"benchmark CSV row has non-integer {key}")
            return 0

    label_quality_count_checks = {
        "label_quality_total_rows": len(label_quality_rows),
        "label_quality_specific_rows": sum(csv_int(row, "is_specific") for row in label_quality_rows),
        "label_quality_broad_rows": sum(csv_int(row, "is_broad") for row in label_quality_rows),
        "label_quality_citation_unbound_rows": sum(csv_int(row, "is_citation_unbound") for row in label_quality_rows),
        "label_quality_duplicate_rows": sum(csv_int(row, "is_duplicate") for row in label_quality_rows),
        "label_quality_contradictory_rows": sum(csv_int(row, "is_contradictory") for row in label_quality_rows),
    }
    expected_quality_met = int(
        label_quality_count_checks["label_quality_total_rows"] > 0
        and label_quality_count_checks["label_quality_broad_rows"] == 0
        and label_quality_count_checks["label_quality_citation_unbound_rows"] == 0
        and label_quality_count_checks["label_quality_duplicate_rows"] == 0
        and label_quality_count_checks["label_quality_contradictory_rows"] == 0
    )
    label_quality_count_checks["label_quality_requirement_met"] = expected_quality_met
    for key, expected in label_quality_count_checks.items():
        if str(summary.get(key)) != str(expected):
            add(f"benchmark label quality summary drift: {key}")
    try:
        summary_real_label_basis = int(summary.get("product_readiness_calculated_from_real_labels", 0))
        summary_label_citation_rows = int(summary.get("label_citation_expectation_rows", 0))
        summary_label_citation_met_rows = int(summary.get("label_citation_expectation_met_rows", -1))
    except (TypeError, ValueError):
        add("benchmark summary has invalid label citation expectation counters")
        summary_real_label_basis = 0
        summary_label_citation_rows = 0
        summary_label_citation_met_rows = -1
    expected_label_citation_requirement = int(
        summary_real_label_basis == 1
        and summary_label_citation_rows > 0
        and summary_label_citation_rows == summary_label_citation_met_rows
        and label_quality_count_checks["label_quality_citation_unbound_rows"] == 0
    )
    if str(summary.get("label_citation_expectation_requirement_met")) != str(expected_label_citation_requirement):
        add("benchmark label citation expectation requirement drift")

    labels_cases: list[dict] = []
    if labels_input.is_file():
        try:
            labels_cases = normalize_cases(read_json_or_jsonl(labels_input, "label"), labels_input.parent)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            add(f"benchmark label input normalization failed: {exc}")
    try:
        repo_snapshot_rows = read_csv(out_dir / "benchmark_repo_snapshots.csv")
    except OSError as exc:
        add(f"benchmark repo snapshot read failed: {exc}")
        repo_snapshot_rows = []
    try:
        expected_repo_snapshot_rows = [stringify_row(case_repo_snapshot(case)) for case in labels_cases]
    except (OSError, ValueError) as exc:
        add(f"benchmark repo snapshot recompute failed: {exc}")
        expected_repo_snapshot_rows = []
    if expected_repo_snapshot_rows and repo_snapshot_rows != expected_repo_snapshot_rows:
        add("benchmark repo snapshot rows drift")
    repo_snapshot_count_checks = {
        "repo_snapshot_rows": len(repo_snapshot_rows),
        "repo_snapshot_locked_rows": sum(csv_int(row, "repo_snapshot_locked") for row in repo_snapshot_rows),
        "repo_snapshot_dirty_rows": sum(csv_int(row, "repo_git_dirty") for row in repo_snapshot_rows),
        "repo_snapshot_mismatch_rows": sum(csv_int(row, "repo_snapshot_mismatch") for row in repo_snapshot_rows),
        "repo_snapshot_missing_expectation_rows": sum(
            csv_int(row, "repo_snapshot_missing_expectation") for row in repo_snapshot_rows
        ),
    }
    expected_repo_snapshot_requirement = int(
        int(summary.get("product_readiness_calculated_from_real_labels", 0)) == 1
        and repo_snapshot_count_checks["repo_snapshot_rows"] > 0
        and repo_snapshot_count_checks["repo_snapshot_locked_rows"] == repo_snapshot_count_checks["repo_snapshot_rows"]
    )
    repo_snapshot_count_checks["repo_snapshot_requirement_met"] = expected_repo_snapshot_requirement
    for key, expected in repo_snapshot_count_checks.items():
        if str(summary.get(key)) != str(expected):
            add(f"benchmark repo snapshot summary drift: {key}")

    case_ids = list(manifest.get("case_ids", []))
    if sorted(case_ids) != case_ids or any(not SAFE_CASE_ID.fullmatch(str(case_id)) for case_id in case_ids):
        add("benchmark manifest case_ids invalid")
    case_run_manifest_sha256s = manifest.get("case_run_manifest_sha256s", {})
    if set(case_run_manifest_sha256s) != set(case_ids):
        add("benchmark case manifest sha set drift")
    for case_id in case_ids:
        case_out = out_dir / "case_runs" / str(case_id)
        case_manifest = case_out / "audit_manifest.json"
        if not case_manifest.is_file():
            add(f"missing case audit manifest: {case_id}")
            continue
        if case_run_manifest_sha256s.get(case_id) != sha256_file(case_manifest):
            add(f"case audit manifest sha mismatch: {case_id}")
        if verify_audit_output(root, case_out) != 0:
            add(f"case audit output failed verifier: {case_id}")
    if case_ids and manifest.get("case_runs_manifest_sha256") != case_runs_manifest_sha256(out_dir, [str(case_id) for case_id in case_ids]):
        add("case_runs_manifest_sha256 mismatch")

    expected_label_rows: list[dict] = []
    expected_label_citation_rows: list[dict] = []
    expected_finding_rows: list[dict] = []
    expected_citation_validity_rows: list[dict] = []
    expected_confusion_rows: list[dict] = []
    expected_abstain_rows: list[dict] = []
    expected_metric_rows: list[dict] = []
    if labels_cases:
        for case in labels_cases:
            case_out = out_dir / "case_runs" / str(case["case_id"])
            if not case_out.is_dir():
                add(f"cannot recompute benchmark rows for missing case output: {case['case_id']}")
                continue
            try:
                label_rows, finding_rows, citation_rows, confusion_rows, abstain_rows, label_citation_rows, metrics = evaluate_case(case, case_out)
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                add(f"benchmark case row recompute failed for {case['case_id']}: {exc}")
                continue
            expected_label_rows.extend(label_rows)
            expected_label_citation_rows.extend(label_citation_rows)
            expected_finding_rows.extend(finding_rows)
            expected_citation_validity_rows.extend(citation_rows)
            expected_confusion_rows.extend(confusion_rows)
            expected_abstain_rows.extend(abstain_rows)
            expected_metric_rows.append(metrics)

    def compare_expected_csv(rel: str, expected_rows: list[dict], label: str) -> list[dict[str, str]]:
        try:
            actual_rows = read_csv(out_dir / rel)
        except OSError as exc:
            add(f"benchmark {label} read failed: {exc}")
            return []
        expected_string_rows = [stringify_row(row) for row in expected_rows]
        if actual_rows != expected_string_rows:
            add(f"benchmark {label} rows drift from case audit outputs")
        return actual_rows

    if labels_cases:
        compare_expected_csv("benchmark_labels.csv", expected_label_rows, "label")
        compare_expected_csv("benchmark_label_citation_expectations.csv", expected_label_citation_rows, "label citation expectation")
        compare_expected_csv("benchmark_case_metrics.csv", expected_metric_rows, "case metrics")
        compare_expected_csv("benchmark_findings.csv", expected_finding_rows, "finding")
        compare_expected_csv("benchmark_citation_validity.csv", expected_citation_validity_rows, "citation validity")
        compare_expected_csv("benchmark_confusion_rows.csv", expected_confusion_rows, "confusion")
        compare_expected_csv("benchmark_abstain_correctness.csv", expected_abstain_rows, "abstain correctness")

        expected_total_tp = sum(int(row["tp"]) for row in expected_metric_rows)
        expected_total_fp = sum(int(row["fp"]) for row in expected_metric_rows)
        expected_total_fn = sum(int(row["fn"]) for row in expected_metric_rows)
        expected_p0_p1_tp = sum(int(row["p0_p1_tp"]) for row in expected_metric_rows)
        expected_p0_p1_fp = sum(int(row["p0_p1_fp"]) for row in expected_metric_rows)
        expected_p0_p1_fn = sum(int(row["p0_p1_fn"]) for row in expected_metric_rows)
        expected_precision = expected_total_tp / (expected_total_tp + expected_total_fp) if expected_total_tp + expected_total_fp else 0.0
        expected_recall = expected_total_tp / (expected_total_tp + expected_total_fn) if expected_total_tp + expected_total_fn else 0.0
        expected_p0_p1_label_rows = expected_p0_p1_tp + expected_p0_p1_fp + expected_p0_p1_fn
        expected_p0_p1_precision = (
            expected_p0_p1_tp / (expected_p0_p1_tp + expected_p0_p1_fp)
            if expected_p0_p1_tp + expected_p0_p1_fp
            else 0.0
        )
        expected_summary_from_cases = {
            "human_label_rows": len(expected_label_rows),
            "label_source_trace_rows": sum(
                1
                for row in expected_label_rows
                if str(row.get("source_candidate_label_id", "")).strip()
                and str(row.get("source_review_queue_id", "")).strip()
            ),
            "tp": expected_total_tp,
            "fp": expected_total_fp,
            "fn": expected_total_fn,
            "p0_p1_label_rows": expected_p0_p1_label_rows,
            "p0_p1_tp": expected_p0_p1_tp,
            "p0_p1_fp": expected_p0_p1_fp,
            "p0_p1_fn": expected_p0_p1_fn,
            "precision": f"{expected_precision:.6f}",
            "recall": f"{expected_recall:.6f}",
            "p0_p1_precision": f"{expected_p0_p1_precision:.6f}",
            "abstain_checked": sum(int(row["abstain_checked"]) for row in expected_metric_rows),
            "abstain_correct": sum(int(row["abstain_correct"]) for row in expected_metric_rows),
            "citation_validity_rows": sum(int(row["citation_validity_rows"]) for row in expected_metric_rows),
            "citation_validity_pass_rows": sum(int(row["citation_validity_pass_rows"]) for row in expected_metric_rows),
            "label_citation_expectation_rows": sum(int(row["label_citation_expectation_rows"]) for row in expected_metric_rows),
            "label_citation_expectation_met_rows": sum(int(row["label_citation_expectation_met_rows"]) for row in expected_metric_rows),
        }
        expected_summary_from_cases["label_source_trace_missing_rows"] = (
            expected_summary_from_cases["human_label_rows"] - expected_summary_from_cases["label_source_trace_rows"]
        )
        for key, expected in expected_summary_from_cases.items():
            if str(summary.get(key, "")) != str(expected):
                add(f"benchmark summary drift from case audit outputs: {key}")

    try:
        benchmark_label_rows = read_csv(out_dir / "benchmark_labels.csv")
        benchmark_labels_payload = json.loads((out_dir / "benchmark_labels.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add(f"benchmark labels JSON read failed: {exc}")
        benchmark_label_rows = []
        benchmark_labels_payload = {}
    for key, expected in {
        "schema_version": "local_repo_audit_benchmark_labels.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
    }.items():
        if benchmark_labels_payload.get(key) != expected:
            add(f"benchmark_labels.{key} mismatch")
    rows_payload = benchmark_labels_payload.get("rows", [])
    if not isinstance(rows_payload, list):
        add("benchmark_labels.rows must be a list")
        rows_payload = []
    normalized_label_json_rows = [
        {key: "" if value is None else str(value) for key, value in row.items()}
        for row in rows_payload
        if isinstance(row, dict)
    ]
    if len(normalized_label_json_rows) != len(rows_payload):
        add("benchmark_labels.rows contains non-object row")
    if benchmark_labels_payload.get("human_label_rows") != len(benchmark_label_rows):
        add("benchmark_labels human_label_rows drift")
    if normalized_label_json_rows != benchmark_label_rows:
        add("benchmark_labels JSON/CSV drift")
    for idx, row in enumerate(normalized_label_json_rows, start=1):
        if set(row) != set(BENCHMARK_LABEL_FIELDS):
            add(f"benchmark_labels row {idx} field set mismatch")
            continue
        for key in ["case_id", "label_id", "plugin_id", "expected", "outcome"]:
            if not row.get(key, ""):
                add(f"benchmark_labels row {idx} missing required value: {key}")
        if row.get("expected", "") not in {"present", "absent"}:
            add(f"benchmark_labels row {idx} invalid expected")
        if row.get("expected_abstain", "") not in {"", "0", "1"}:
            add(f"benchmark_labels row {idx} invalid expected_abstain")
        if row.get("outcome", "") not in {"TP", "FP", "FN", "TN"}:
            add(f"benchmark_labels row {idx} invalid outcome")
        if row.get("maintainer_feedback", "") not in {"0", "1"}:
            add(f"benchmark_labels row {idx} invalid maintainer_feedback")
    label_trace_rows = sum(
        1
        for row in benchmark_label_rows
        if str(row.get("source_candidate_label_id", "")).strip()
        and str(row.get("source_review_queue_id", "")).strip()
    )
    label_trace_missing_rows = len(benchmark_label_rows) - label_trace_rows
    expected_label_trace_requirement = int(
        int(summary.get("product_readiness_calculated_from_real_labels", 0)) == 1
        and len(benchmark_label_rows) > 0
        and label_trace_rows == len(benchmark_label_rows)
    )
    for key, expected in {
        "label_source_trace_rows": label_trace_rows,
        "label_source_trace_missing_rows": label_trace_missing_rows,
        "label_source_trace_requirement_met": expected_label_trace_requirement,
    }.items():
        if str(summary.get(key, "")) != str(expected):
            add(f"benchmark label source trace summary drift: {key}")

    try:
        label_citation_rows = read_csv(out_dir / "benchmark_label_citation_expectations.csv")
        label_citation_payload = json.loads((out_dir / "benchmark_label_citation_expectations.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add(f"benchmark label citation expectations JSON read failed: {exc}")
        label_citation_rows = []
        label_citation_payload = {}
    for key, expected in {
        "schema_version": "local_repo_audit_benchmark_label_citation_expectations.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }.items():
        if label_citation_payload.get(key) != expected:
            add(f"benchmark_label_citation_expectations.{key} mismatch")
    label_citation_payload_rows = label_citation_payload.get("rows", [])
    if not isinstance(label_citation_payload_rows, list):
        add("benchmark_label_citation_expectations.rows must be a list")
        label_citation_payload_rows = []
    normalized_label_citation_json_rows = [
        {key: "" if value is None else str(value) for key, value in row.items()}
        for row in label_citation_payload_rows
        if isinstance(row, dict)
    ]
    if len(normalized_label_citation_json_rows) != len(label_citation_payload_rows):
        add("benchmark_label_citation_expectations.rows contains non-object row")
    if label_citation_payload.get("label_rows") != len(label_citation_rows):
        add("benchmark_label_citation_expectations label_rows drift")
    if label_citation_payload.get("citation_expectation_rows") != sum(csv_int(row, "citation_expectation_supplied") for row in label_citation_rows):
        add("benchmark_label_citation_expectations supplied row count drift")
    if label_citation_payload.get("citation_expectation_met_rows") != sum(1 for row in label_citation_rows if row.get("citation_expectation_met", "") == "1"):
        add("benchmark_label_citation_expectations met row count drift")
    if normalized_label_citation_json_rows != label_citation_rows:
        add("benchmark_label_citation_expectations JSON/CSV drift")
    for idx, row in enumerate(normalized_label_citation_json_rows, start=1):
        if set(row) != set(LABEL_CITATION_EXPECTATION_FIELDS):
            add(f"benchmark_label_citation_expectations row {idx} field set mismatch")
            continue
        if row.get("citation_expectation_supplied", "") not in {"0", "1"}:
            add(f"benchmark_label_citation_expectations row {idx} invalid supplied flag")
        if row.get("citation_expectation_met", "") not in {"", "0", "1"}:
            add(f"benchmark_label_citation_expectations row {idx} invalid met flag")
        if row.get("outcome", "") not in {"TP", "FP", "FN", "TN", "citation_unbound"}:
            add(f"benchmark_label_citation_expectations row {idx} invalid outcome")
        if row.get("outcome", "") == "citation_unbound" and (
            row.get("expected", "") != "present" or row.get("citation_expectation_supplied", "") != "0"
        ):
            add(f"benchmark_label_citation_expectations row {idx} invalid citation_unbound outcome")
        if row.get("expected_span_sha256", "") and not is_sha256_digest(row.get("expected_span_sha256", "")):
            add(f"benchmark_label_citation_expectations row {idx} invalid expected span sha")

    try:
        run_metric_rows = read_csv(out_dir / "benchmark_run_metrics.csv")
    except OSError as exc:
        add(f"benchmark run metrics read failed: {exc}")
        run_metric_rows = []
    for rel, expected_fields in {
        "benchmark_run_metrics.csv": RUN_METRIC_FIELDS,
        "benchmark_case_metrics.csv": CASE_METRIC_FIELDS,
        "benchmark_citation_validity.csv": CITATION_VALIDITY_FIELDS,
        "benchmark_confusion_rows.csv": CONFUSION_FIELDS,
        "benchmark_abstain_correctness.csv": ABSTAIN_CORRECTNESS_FIELDS,
        "benchmark_label_quality.csv": LABEL_QUALITY_FIELDS,
    }.items():
        try:
            if csv_fieldnames(out_dir / rel) != expected_fields:
                add(f"{rel} header drift")
        except OSError as exc:
            add(f"{rel} header read failed: {exc}")
    standard_json_checked_rows = sum(1 for row in run_metric_rows if row.get("standard_json_findings_checked") == "1")
    standard_json_valid_rows = sum(1 for row in run_metric_rows if row.get("standard_json_findings_valid") == "1")
    if str(summary.get("standard_json_findings_checked_rows")) != str(standard_json_checked_rows):
        add("benchmark standard JSON findings checked row summary drift")
    if str(summary.get("standard_json_findings_valid_rows")) != str(standard_json_valid_rows):
        add("benchmark standard JSON findings valid row summary drift")
    expected_standard_json_requirement = int(
        int(summary.get("product_readiness_calculated_from_real_labels", 0)) == 1
        and standard_json_checked_rows > 0
        and standard_json_checked_rows == standard_json_valid_rows
    )
    if str(summary.get("standard_json_findings_requirement_met")) != str(expected_standard_json_requirement):
        add("benchmark standard JSON findings requirement drift")
    for row in run_metric_rows:
        case_id = row.get("case_id", "")
        if not case_id:
            add("benchmark run metrics row missing case_id")
            continue
        case_out = out_dir / "case_runs" / case_id
        if not case_out.is_dir():
            add(f"benchmark run metrics references missing case output: {case_id}")
            continue
        expected = standard_json_findings_metrics(case_out)
        for key, expected_value in expected.items():
            if str(row.get(key, "")) != str(expected_value):
                add(f"benchmark standard JSON findings metric drift for {case_id}: {key}")

    try:
        benchmark_finding_rows = read_csv(out_dir / "benchmark_findings.csv")
        benchmark_findings_payload = json.loads((out_dir / "benchmark_findings.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add(f"benchmark findings JSON read failed: {exc}")
        benchmark_finding_rows = []
        benchmark_findings_payload = {}
    for key, expected in {
        "schema_version": "local_repo_audit_benchmark_findings.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
    }.items():
        if benchmark_findings_payload.get(key) != expected:
            add(f"benchmark_findings.{key} mismatch")
    try:
        if csv_fieldnames(out_dir / "benchmark_findings.csv") != BENCHMARK_FINDING_FIELDS:
            add("benchmark_findings.csv header drift")
    except OSError as exc:
        add(f"benchmark_findings.csv header read failed: {exc}")
    rows_payload = benchmark_findings_payload.get("rows", [])
    if not isinstance(rows_payload, list):
        add("benchmark_findings.rows must be a list")
        rows_payload = []
    normalized_json_rows = [
        {key: "" if value is None else str(value) for key, value in row.items()}
        for row in rows_payload
        if isinstance(row, dict)
    ]
    if len(normalized_json_rows) != len(rows_payload):
        add("benchmark_findings.rows contains non-object row")
    if benchmark_findings_payload.get("finding_rows") != len(benchmark_finding_rows):
        add("benchmark_findings finding_rows drift")
    if normalized_json_rows != benchmark_finding_rows:
        add("benchmark_findings JSON/CSV drift")
    expected_benchmark_finding_rows: list[dict[str, str]] = []
    for case_id in case_ids:
        case_out = out_dir / "case_runs" / str(case_id)
        try:
            case_finding_rows = read_csv(case_out / "audit_findings.csv")
        except OSError as exc:
            add(f"benchmark_findings source case read failed for {case_id}: {exc}")
            continue
        expected_benchmark_finding_rows.extend(
            stringify_row({"case_id": str(case_id), **row})
            for row in case_finding_rows
            if row.get("suppressed", "0") != "1"
        )
    if sort_rows_for_compare(benchmark_finding_rows) != sort_rows_for_compare(expected_benchmark_finding_rows):
        add("benchmark_findings do not match case audit_findings.csv")
    for idx, row in enumerate(normalized_json_rows, start=1):
        if set(row) != set(BENCHMARK_FINDING_FIELDS):
            add(f"benchmark_findings row {idx} field set mismatch")
            continue
        for key in NONEMPTY_BENCHMARK_FINDING_FIELDS:
            if not row.get(key, ""):
                add(f"benchmark_findings row {idx} missing required value: {key}")
        for key in BINARY_BENCHMARK_FINDING_FIELDS:
            if row.get(key, "") not in {"0", "1"}:
                add(f"benchmark_findings row {idx} invalid binary flag: {key}")
        if row.get("severity", "") not in {"info", "low", "medium", "high"}:
            add(f"benchmark_findings row {idx} invalid severity")
        if not re.fullmatch(r"[0-9]+", row.get("raw_prompt_context_bytes", "")):
            add(f"benchmark_findings row {idx} invalid raw_prompt_context_bytes")

    try:
        confusion_rows = read_csv(out_dir / "benchmark_confusion_rows.csv")
        abstain_rows = read_csv(out_dir / "benchmark_abstain_correctness.csv")
        citation_validity_rows = read_csv(out_dir / "benchmark_citation_validity.csv")
        evaluation_payload = json.loads((out_dir / "benchmark_evaluation.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add(f"benchmark evaluation JSON read failed: {exc}")
        confusion_rows = []
        abstain_rows = []
        citation_validity_rows = []
        evaluation_payload = {}
    for key, expected in {
        "schema_version": "local_repo_audit_benchmark_evaluation.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }.items():
        if evaluation_payload.get(key) != expected:
            add(f"benchmark_evaluation.{key} mismatch")
    metrics = evaluation_payload.get("metrics", {})
    if not isinstance(metrics, dict):
        add("benchmark_evaluation.metrics must be an object")
        metrics = {}
    for key in BENCHMARK_EVALUATION_SUMMARY_FIELDS:
        if str(metrics.get(key, "")) != str(summary.get(key, "")):
            add(f"benchmark_evaluation metric drift: {key}")
    if evaluation_payload.get("confusion_rows") != len(confusion_rows):
        add("benchmark_evaluation confusion row count drift")
    if evaluation_payload.get("abstain_correctness_rows") != len(abstain_rows):
        add("benchmark_evaluation abstain row count drift")
    if evaluation_payload.get("citation_validity_detail_rows") != len(citation_validity_rows):
        add("benchmark_evaluation citation row count drift")
    for key, expected_rows in {
        "confusion": confusion_rows,
        "abstain_correctness": abstain_rows,
        "citation_validity": citation_validity_rows,
    }.items():
        rows_payload = evaluation_payload.get(key, [])
        if not isinstance(rows_payload, list):
            add(f"benchmark_evaluation.{key} must be a list")
            continue
        normalized_rows = [
            {cell_key: "" if cell_value is None else str(cell_value) for cell_key, cell_value in row.items()}
            for row in rows_payload
            if isinstance(row, dict)
        ]
        if len(normalized_rows) != len(rows_payload):
            add(f"benchmark_evaluation.{key} contains non-object row")
        if normalized_rows != expected_rows:
            add(f"benchmark_evaluation.{key} CSV drift")

    try:
        readiness_payload = json.loads((out_dir / "benchmark_readiness.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add(f"benchmark readiness JSON read failed: {exc}")
        readiness_payload = {}
    for key, expected in {
        "schema_version": "local_repo_audit_benchmark_readiness.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "claim_boundary": "alpha-local-code-doc-audit-only",
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }.items():
        if readiness_payload.get(key) != expected:
            add(f"benchmark_readiness.{key} mismatch")
    for key in ["product_readiness_calculated_from_real_labels", "design_partner_beta_candidate_ready"]:
        if str(readiness_payload.get(key, "")) != str(summary.get(key, "")):
            add(f"benchmark_readiness summary drift: {key}")
    expected_readiness_rows = readiness_gate_rows(summary)
    readiness_rows = readiness_payload.get("rows", [])
    if not isinstance(readiness_rows, list):
        add("benchmark_readiness.rows must be a list")
        readiness_rows = []
    if readiness_rows != expected_readiness_rows:
        add("benchmark_readiness rows drift")
    passed_gate_rows = sum(1 for row in expected_readiness_rows if int(row["passed"]) == 1)
    blocked_gate_rows = len(expected_readiness_rows) - passed_gate_rows
    for key, expected in {
        "gate_rows": len(expected_readiness_rows),
        "passed_gate_rows": passed_gate_rows,
        "blocked_gate_rows": blocked_gate_rows,
    }.items():
        if readiness_payload.get(key) != expected:
            add(f"benchmark_readiness.{key} drift")
    if int(summary.get("design_partner_beta_candidate_ready", 0)) == 1 and blocked_gate_rows != 0:
        add("benchmark_readiness beta-ready summary has blocked gates")
    if int(summary.get("design_partner_beta_candidate_ready", 0)) == 0 and expected_readiness_rows and blocked_gate_rows == 0:
        add("benchmark_readiness blocked gate count missing for non-ready summary")

    expected_sha_paths = {"benchmark_manifest.json", *BENCHMARK_ARTIFACTS}
    expected_sha_paths.update(f"case_runs/{case_id}/audit_manifest.json" for case_id in case_ids)
    if set(sha_rows) != expected_sha_paths:
        add("benchmark_sha256sums.txt artifact set drift")
    for rel, digest in sha_rows.items():
        path = out_dir / rel
        if not path.is_file():
            add(f"benchmark sha manifest references missing artifact: {rel}")
        elif digest != sha256_hex(path):
            add(f"benchmark sha manifest digest mismatch: {rel}")
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Evaluate audit_my_repo against user-provided local repositories and human labels.")
    parser.add_argument("--labels", default="", help="JSON or JSONL labels. Repositories must already exist locally.")
    parser.add_argument("--label-intake", default="", help="Verified label-intake output directory containing benchmark_labels.jsonl.")
    parser.add_argument("--feedback", default="", help="Optional JSON/JSONL design-partner maintainer feedback rows. Raw feedback text is hashed, not emitted.")
    parser.add_argument("--verify-existing", default="", help="Verify an existing benchmark output directory and exit.")
    parser.add_argument("--out", default="")
    parser.add_argument("--mode", choices=["quick", "full"], default="full")
    parser.add_argument("--namespace", choices=["fixture", "synthetic", "real_benchmark"], default="synthetic")
    parser.add_argument("--confirm-real-benchmark-namespace", action="store_true", help="Explicitly confirm that real_benchmark inputs are real local repositories with human labels.")
    parser.add_argument("--max-files", type=int, default=220)
    parser.add_argument("--max-total-bytes", type=int, default=15_000_000)
    parser.add_argument("--max-file-bytes", type=int, default=700_000)
    parser.add_argument("--max-findings", type=int, default=100)
    parser.add_argument("--rerun-check", action=argparse.BooleanOptionalAction, default=True, help="Run each case twice and record cache/semantic repeatability metrics.")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing benchmark-managed artifacts. Unrelated files are never deleted.")
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parents[1]
    if args.verify_existing:
        verify_dir = Path(args.verify_existing).expanduser().resolve()
        errors = verify_benchmark_output(root, verify_dir)
        if errors:
            for error in errors:
                print(f"benchmark_verify_error: {error}", file=sys.stderr)
            return 1
        print("benchmark_verify: ok")
        return 0
    if bool(args.labels) == bool(args.label_intake):
        print("exactly one of --labels or --label-intake is required unless --verify-existing is used", file=sys.stderr)
        return 2
    if args.namespace == "real_benchmark" and not args.confirm_real_benchmark_namespace:
        print("--namespace real_benchmark requires --confirm-real-benchmark-namespace", file=sys.stderr)
        return 2
    if args.namespace != "real_benchmark" and args.confirm_real_benchmark_namespace:
        print("--confirm-real-benchmark-namespace is only valid with --namespace real_benchmark", file=sys.stderr)
        return 2
    if not args.out:
        print("--out is required unless --verify-existing is used", file=sys.stderr)
        return 2
    out = Path(args.out).expanduser().resolve()
    benchmark_backup_dir: Path | None = None
    try:
        benchmark_backup_dir = prepare_benchmark_output_dir(out, args.overwrite)
    except ValueError as exc:
        print(f"benchmark_error: {exc}", file=sys.stderr)
        return 2
    install_returncode, install_wall_ms = install_check(root)
    try:
        label_source_kind = "direct_labels"
        label_intake_output: Path | None = None
        label_intake_manifest_sha256 = sha256_text("")
        label_intake_sha256sums_sha256 = sha256_text("")
        if args.label_intake:
            label_source_kind = "label_intake"
            label_intake_output = Path(args.label_intake).expanduser().resolve()
            intake_errors = verify_label_intake_bundle(root, label_intake_output)
            if intake_errors:
                raise ValueError("; ".join(intake_errors))
            labels_path = label_intake_output / "benchmark_labels.jsonl"
            label_intake_manifest_sha256 = sha256_file(label_intake_output / "label_intake_manifest.json")
            label_intake_sha256sums_sha256 = sha256_file(label_intake_output / "label_intake_sha256sums.txt")
        else:
            labels_path = Path(args.labels).expanduser().resolve()
            if is_forbidden_env_path(labels_path):
                raise ValueError("refusing to read .env-like label file")
        labels_input_sha256 = sha256_file(labels_path)
        cases = normalize_cases(read_json_or_jsonl(labels_path, "label"), labels_path.parent)
        label_quality_metrics, label_quality_rows = assess_label_quality(cases)
        feedback_input_supplied = int(bool(args.feedback))
        feedback_input_sha256 = sha256_text("")
        feedback_path: Path | None = None
        maintainer_feedback_rows: list[dict] = []
        if args.feedback:
            feedback_path = Path(args.feedback).expanduser().resolve()
            if is_forbidden_env_path(feedback_path):
                raise ValueError("refusing to read .env-like feedback file")
            if not feedback_path.is_file():
                raise ValueError(f"feedback file is not a file: {feedback_path}")
            feedback_input_sha256 = sha256_file(feedback_path)
            maintainer_feedback_rows = normalize_maintainer_feedback(read_json_or_jsonl(feedback_path, "feedback"), cases)
        if args.namespace == "real_benchmark" and any(case["synthetic"] for case in cases):
            raise ValueError("synthetic cases cannot be evaluated in the real_benchmark namespace")
        if args.namespace == "real_benchmark" and any(int(row["synthetic"]) == 1 for row in maintainer_feedback_rows):
            raise ValueError("synthetic maintainer feedback cannot be evaluated in the real_benchmark namespace")
        all_label_rows: list[dict] = []
        all_finding_rows: list[dict] = []
        all_citation_validity_rows: list[dict] = []
        all_confusion_rows: list[dict] = []
        all_abstain_correctness_rows: list[dict] = []
        all_label_citation_rows: list[dict] = []
        repo_snapshot_rows: list[dict] = []
        metric_rows: list[dict] = []
        run_metric_rows: list[dict] = []
        for case in cases:
            case_out = out / "case_runs" / case["case_id"]
            repo_snapshot_rows.append(case_repo_snapshot(case))
            first_run = run_audit(root, case, case_out, args)
            if args.rerun_check:
                rerun = rerun_audit(root, case, case_out, args, first_run)
            else:
                rerun = {
                    "rerun_checked": 0,
                    "rerun_exit_code": -1,
                    "rerun_verify_exit_code": -1,
                    "rerun_wall_ms": 0,
                    "rerun_cache_key_match": 0,
                    "rerun_semantic_result_match": 0,
                    "rerun_success": 0,
                }
            run_metric_rows.append(
                {
                    "case_id": case["case_id"],
                    "install_check_returncode": install_returncode,
                    "install_success": int(install_returncode == 0),
                    "install_wall_ms": install_wall_ms,
                    "audit_exit_code": first_run["audit_exit_code"],
                    "verify_exit_code": first_run["verify_exit_code"],
                    "first_report_success": first_run["first_report_success"],
                    "first_report_wall_ms": first_run["first_report_wall_ms"],
                    "cache_key": first_run["cache_key"],
                    "semantic_result_sha256": first_run["semantic_result_sha256"],
                    "source_scope": first_run["source_scope"],
                    "source_file_count": first_run["source_file_count"],
                    "changed_files_from": first_run["changed_files_from"],
                    "changed_files_from_sha256": first_run["changed_files_from_sha256"],
                    "changed_file_rows": first_run["changed_file_rows"],
                    "standard_json_findings_checked": first_run["standard_json_findings_checked"],
                    "standard_json_findings_valid": first_run["standard_json_findings_valid"],
                    "standard_json_finding_rows": first_run["standard_json_finding_rows"],
                    "standard_json_findings_invalid_reasons": first_run["standard_json_findings_invalid_reasons"],
                    **rerun,
                }
            )
            label_rows, finding_rows, citation_rows, confusion_rows, abstain_rows, label_citation_rows, metrics = evaluate_case(case, case_out)
            all_label_rows.extend(label_rows)
            all_finding_rows.extend(finding_rows)
            all_citation_validity_rows.extend(citation_rows)
            all_confusion_rows.extend(confusion_rows)
            all_abstain_correctness_rows.extend(abstain_rows)
            all_label_citation_rows.extend(label_citation_rows)
            metric_rows.append(metrics)
        if benchmark_fail_after_cases_requested():
            raise RuntimeError("simulated benchmark failure after case runs")
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        rollback_benchmark_output_dir(out, benchmark_backup_dir)
        print(f"benchmark_error: {exc}", file=sys.stderr)
        return 2

    total_tp = sum(int(row["tp"]) for row in metric_rows)
    total_fp = sum(int(row["fp"]) for row in metric_rows)
    total_fn = sum(int(row["fn"]) for row in metric_rows)
    p0_p1_tp = sum(int(row["p0_p1_tp"]) for row in metric_rows)
    p0_p1_fp = sum(int(row["p0_p1_fp"]) for row in metric_rows)
    p0_p1_fn = sum(int(row["p0_p1_fn"]) for row in metric_rows)
    precision = total_tp / (total_tp + total_fp) if total_tp + total_fp else 0.0
    recall = total_tp / (total_tp + total_fn) if total_tp + total_fn else 0.0
    p0_p1_precision = p0_p1_tp / (p0_p1_tp + p0_p1_fp) if p0_p1_tp + p0_p1_fp else 0.0
    abstain_checked = sum(int(row["abstain_checked"]) for row in metric_rows)
    abstain_correct = sum(int(row["abstain_correct"]) for row in metric_rows)
    citation_rows = sum(int(row["citation_validity_rows"]) for row in metric_rows)
    citation_pass = sum(int(row["citation_validity_pass_rows"]) for row in metric_rows)
    label_citation_expectation_rows = sum(int(row["label_citation_expectation_rows"]) for row in metric_rows)
    label_citation_expectation_met_rows = sum(int(row["label_citation_expectation_met_rows"]) for row in metric_rows)
    first_report_success_rows = sum(int(row["first_report_success"]) for row in run_metric_rows)
    first_report_wall_values = [int(row["first_report_wall_ms"]) for row in run_metric_rows if int(row["first_report_success"]) == 1]
    rerun_checked_rows = sum(int(row["rerun_checked"]) for row in run_metric_rows)
    rerun_success_rows = sum(int(row["rerun_success"]) for row in run_metric_rows)
    rerun_cache_key_match_rows = sum(int(row["rerun_cache_key_match"]) for row in run_metric_rows)
    rerun_semantic_match_rows = sum(int(row["rerun_semantic_result_match"]) for row in run_metric_rows)
    changed_file_scope_case_rows = sum(1 for row in run_metric_rows if row.get("source_scope") == "changed-files")
    tracked_scope_case_rows = sum(1 for row in run_metric_rows if row.get("source_scope") == "tracked")
    standard_json_findings_checked_rows = sum(int(row["standard_json_findings_checked"]) for row in run_metric_rows)
    standard_json_findings_valid_rows = sum(int(row["standard_json_findings_valid"]) for row in run_metric_rows)
    real_repo_count = len({str(Path(case["repo_path"]).expanduser().resolve()) for case in cases})
    maintainer_feedback_case_rows = len({row["case_id"] for row in maintainer_feedback_rows if int(row["counts_for_beta"]) == 1})
    maintainer_feedback_count = len({row["maintainer_id_sha256"] for row in maintainer_feedback_rows if int(row["counts_for_beta"]) == 1})
    real_human_label_basis = int(
        args.namespace == "real_benchmark"
        and bool(args.confirm_real_benchmark_namespace)
        and bool(cases)
        and all(case["human_labeled"] and not case["synthetic"] for case in cases)
    )
    p0_p1_label_rows = p0_p1_tp + p0_p1_fp + p0_p1_fn
    repo_snapshot_count = len(repo_snapshot_rows)
    repo_snapshot_locked_rows = sum(int(row["repo_snapshot_locked"]) for row in repo_snapshot_rows)
    repo_snapshot_dirty_rows = sum(int(row["repo_git_dirty"]) for row in repo_snapshot_rows)
    repo_snapshot_mismatch_rows = sum(int(row["repo_snapshot_mismatch"]) for row in repo_snapshot_rows)
    repo_snapshot_missing_expectation_rows = sum(int(row["repo_snapshot_missing_expectation"]) for row in repo_snapshot_rows)
    label_source_trace_rows = sum(
        1
        for row in all_label_rows
        if str(row.get("source_candidate_label_id", "")).strip()
        and str(row.get("source_review_queue_id", "")).strip()
    )
    label_source_trace_missing_rows = len(all_label_rows) - label_source_trace_rows
    real_repo_requirement_met = int(real_human_label_basis == 1 and real_repo_count >= MIN_REAL_REPOS_FOR_BETA)
    human_label_requirement_met = int(real_human_label_basis == 1 and len(all_label_rows) >= MIN_HUMAN_LABELS_FOR_BETA)
    label_source_trace_requirement_met = int(
        real_human_label_basis == 1
        and len(all_label_rows) > 0
        and label_source_trace_rows == len(all_label_rows)
    )
    repo_snapshot_requirement_met = int(
        real_human_label_basis == 1
        and repo_snapshot_count > 0
        and repo_snapshot_locked_rows == repo_snapshot_count
    )
    maintainer_feedback_requirement_met = int(real_human_label_basis == 1 and maintainer_feedback_count >= MIN_MAINTAINER_FEEDBACK_FOR_BETA)
    overall_precision_requirement_met = int(real_human_label_basis == 1 and precision >= OVERALL_PRECISION_THRESHOLD and total_tp + total_fp > 0)
    p0_p1_precision_requirement_met = int(real_human_label_basis == 1 and p0_p1_label_rows > 0 and p0_p1_precision >= P0_P1_PRECISION_THRESHOLD)
    citation_validity_requirement_met = int(real_human_label_basis == 1 and citation_rows > 0 and citation_rows == citation_pass)
    label_citation_expectation_requirement_met = int(
        real_human_label_basis == 1
        and label_citation_expectation_rows > 0
        and label_citation_expectation_rows == label_citation_expectation_met_rows
        and int(label_quality_metrics["label_quality_citation_unbound_rows"]) == 0
    )
    standard_json_findings_requirement_met = int(
        real_human_label_basis == 1
        and standard_json_findings_checked_rows > 0
        and standard_json_findings_checked_rows == standard_json_findings_valid_rows
    )
    install_success_requirement_met = int(real_human_label_basis == 1 and install_returncode == 0)
    first_report_requirement_met = int(real_human_label_basis == 1 and bool(run_metric_rows) and first_report_success_rows == len(run_metric_rows))
    rerun_requirement_met = int(real_human_label_basis == 1 and rerun_checked_rows > 0 and rerun_success_rows == rerun_checked_rows)
    design_partner_beta_candidate_ready = int(
        real_repo_requirement_met
        and human_label_requirement_met
        and label_source_trace_requirement_met
        and repo_snapshot_requirement_met
        and maintainer_feedback_requirement_met
        and overall_precision_requirement_met
        and p0_p1_precision_requirement_met
        and citation_validity_requirement_met
        and label_citation_expectation_requirement_met
        and standard_json_findings_requirement_met
        and install_success_requirement_met
        and first_report_requirement_met
        and rerun_requirement_met
        and int(label_quality_metrics["label_quality_requirement_met"]) == 1
    )
    summary = {
        "schema_version": "local_repo_audit_benchmark.v1",
        "tool_version": "audit_my_repo_alpha.v1",
        "case_rows": len(cases),
        "human_label_rows": len(all_label_rows),
        "tp": total_tp,
        "fp": total_fp,
        "fn": total_fn,
        "p0_p1_label_rows": p0_p1_label_rows,
        "p0_p1_tp": p0_p1_tp,
        "p0_p1_fp": p0_p1_fp,
        "p0_p1_fn": p0_p1_fn,
        "precision": f"{precision:.6f}",
        "recall": f"{recall:.6f}",
        "p0_p1_precision": f"{p0_p1_precision:.6f}",
        "abstain_checked": abstain_checked,
        "abstain_correct": abstain_correct,
        "citation_validity_rows": citation_rows,
        "citation_validity_pass_rows": citation_pass,
        "label_citation_expectation_rows": label_citation_expectation_rows,
        "label_citation_expectation_met_rows": label_citation_expectation_met_rows,
        "install_check_rows": 1,
        "install_success_rows": int(install_returncode == 0),
        "install_success_rate": f"{float(install_returncode == 0):.6f}",
        "install_wall_ms": install_wall_ms,
        "first_report_success_rows": first_report_success_rows,
        "first_report_success_rate": f"{(first_report_success_rows / len(run_metric_rows)) if run_metric_rows else 0.0:.6f}",
        "first_report_wall_ms_avg": f"{(sum(first_report_wall_values) / len(first_report_wall_values)) if first_report_wall_values else 0.0:.6f}",
        "first_report_wall_ms_max": max(first_report_wall_values) if first_report_wall_values else 0,
        "rerun_checked_rows": rerun_checked_rows,
        "rerun_success_rows": rerun_success_rows,
        "rerun_success_rate": f"{(rerun_success_rows / rerun_checked_rows) if rerun_checked_rows else 0.0:.6f}",
        "rerun_cache_key_match_rows": rerun_cache_key_match_rows,
        "rerun_semantic_result_match_rows": rerun_semantic_match_rows,
        "changed_file_scope_case_rows": changed_file_scope_case_rows,
        "tracked_scope_case_rows": tracked_scope_case_rows,
        "standard_json_findings_checked_rows": standard_json_findings_checked_rows,
        "standard_json_findings_valid_rows": standard_json_findings_valid_rows,
        "repo_snapshot_rows": repo_snapshot_count,
        "repo_snapshot_locked_rows": repo_snapshot_locked_rows,
        "repo_snapshot_dirty_rows": repo_snapshot_dirty_rows,
        "repo_snapshot_mismatch_rows": repo_snapshot_mismatch_rows,
        "repo_snapshot_missing_expectation_rows": repo_snapshot_missing_expectation_rows,
        "repo_snapshot_requirement_met": repo_snapshot_requirement_met,
        **label_quality_metrics,
        "product_readiness_calculated_from_real_labels": real_human_label_basis,
        "design_partner_beta_candidate_ready": design_partner_beta_candidate_ready,
        "real_repo_count": real_repo_count,
        "min_real_repos_required": MIN_REAL_REPOS_FOR_BETA,
        "real_repo_requirement_met": real_repo_requirement_met,
        "min_human_label_rows_required": MIN_HUMAN_LABELS_FOR_BETA,
        "human_label_requirement_met": human_label_requirement_met,
        "label_source_trace_rows": label_source_trace_rows,
        "label_source_trace_missing_rows": label_source_trace_missing_rows,
        "label_source_trace_requirement_met": label_source_trace_requirement_met,
        "maintainer_feedback_count": maintainer_feedback_count,
        "maintainer_feedback_rows": len(maintainer_feedback_rows),
        "maintainer_feedback_case_rows": maintainer_feedback_case_rows,
        "maintainer_feedback_input_supplied": feedback_input_supplied,
        "maintainer_feedback_input_sha256": feedback_input_sha256,
        "min_maintainer_feedback_required": MIN_MAINTAINER_FEEDBACK_FOR_BETA,
        "maintainer_feedback_requirement_met": maintainer_feedback_requirement_met,
        "overall_precision_threshold": f"{OVERALL_PRECISION_THRESHOLD:.6f}",
        "overall_precision_requirement_met": overall_precision_requirement_met,
        "p0_p1_precision_threshold": f"{P0_P1_PRECISION_THRESHOLD:.6f}",
        "p0_p1_precision_requirement_met": p0_p1_precision_requirement_met,
        "citation_validity_requirement_met": citation_validity_requirement_met,
        "label_citation_expectation_requirement_met": label_citation_expectation_requirement_met,
        "standard_json_findings_requirement_met": standard_json_findings_requirement_met,
        "install_success_requirement_met": install_success_requirement_met,
        "first_report_requirement_met": first_report_requirement_met,
        "rerun_requirement_met": rerun_requirement_met,
        "synthetic_smoke_promoted_to_real_benchmark": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    try:
        write_csv(out / "benchmark_run_metrics.csv", RUN_METRIC_FIELDS, run_metric_rows)
        if os.environ.get("AUDIT_MY_REPO_BENCHMARK_FAIL_DURING_WRITE") == "1":
            raise OSError("simulated benchmark artifact write failure")
        write_csv(out / "benchmark_case_metrics.csv", CASE_METRIC_FIELDS, metric_rows)
        write_csv(out / "benchmark_repo_snapshots.csv", REPO_SNAPSHOT_FIELDS, repo_snapshot_rows)
        write_csv(out / "benchmark_labels.csv", BENCHMARK_LABEL_FIELDS, all_label_rows)
        write_benchmark_labels_json(out / "benchmark_labels.json", all_label_rows)
        write_csv(out / "benchmark_label_quality.csv", LABEL_QUALITY_FIELDS, label_quality_rows)
        write_csv(out / "benchmark_label_citation_expectations.csv", LABEL_CITATION_EXPECTATION_FIELDS, all_label_citation_rows)
        write_benchmark_label_citation_expectations_json(out / "benchmark_label_citation_expectations.json", all_label_citation_rows)
        write_csv(out / "benchmark_findings.csv", BENCHMARK_FINDING_FIELDS, all_finding_rows)
        write_benchmark_findings_json(out / "benchmark_findings.json", all_finding_rows)
        write_csv(out / "benchmark_citation_validity.csv", CITATION_VALIDITY_FIELDS, all_citation_validity_rows)
        write_csv(out / "benchmark_confusion_rows.csv", CONFUSION_FIELDS, all_confusion_rows)
        write_csv(out / "benchmark_abstain_correctness.csv", ABSTAIN_CORRECTNESS_FIELDS, all_abstain_correctness_rows)
        feedback_fields = ["feedback_id", "case_id", "feedback_source", "maintainer_id_sha256", "human_feedback", "synthetic", "counts_for_beta", "feedback_text_sha256", "feedback_text_bytes"]
        write_csv(out / "benchmark_maintainer_feedback.csv", feedback_fields, maintainer_feedback_rows)
        feedback_payload = {
            "schema_version": "local_repo_audit_benchmark_maintainer_feedback.v1",
            "tool_version": "audit_my_repo_alpha.v1",
            "feedback_rows": len(maintainer_feedback_rows),
            "rows": maintainer_feedback_rows,
        }
        (out / "benchmark_maintainer_feedback.json").write_text(json.dumps(feedback_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        write_csv(out / "benchmark_summary.csv", list(summary.keys()), [summary])
        (out / "benchmark_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        write_benchmark_evaluation_json(
            out / "benchmark_evaluation.json",
            summary,
            all_confusion_rows,
            all_abstain_correctness_rows,
            all_citation_validity_rows,
        )
        write_benchmark_readiness_json(out / "benchmark_readiness.json", summary)
        write_benchmark_manifest(
            root,
            out,
            args,
            labels_path,
            labels_input_sha256,
            label_source_kind,
            label_intake_output,
            label_intake_manifest_sha256,
            label_intake_sha256sums_sha256,
            feedback_path,
            feedback_input_sha256,
            [case["case_id"] for case in cases],
            summary,
        )
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        rollback_benchmark_output_dir(out, benchmark_backup_dir)
        print(f"benchmark_error: {exc}", file=sys.stderr)
        return 2
    if os.environ.get("AUDIT_MY_REPO_BENCHMARK_TAMPER_BEFORE_VERIFY") == "1":
        manifest_path = out / "benchmark_manifest.json"
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        payload["release_ready"] = 1
        manifest_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify_errors = verify_benchmark_output(root, out)
    if verify_errors:
        rollback_benchmark_output_dir(out, benchmark_backup_dir)
        for error in verify_errors:
            print(f"benchmark_verify_error: {error}", file=sys.stderr)
        return 1
    commit_benchmark_output_dir(benchmark_backup_dir)
    print(f"benchmark_summary: {out / 'benchmark_summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
