#!/usr/bin/env python3
"""Validate human responses to AMR beta repo discovery requests.

This read-only helper consumes the request packet from
amr_beta_repo_discovery_request.py plus a human-edited Markdown/CSV response.
It verifies which discovered repos are ready to be passed to the existing
amr_beta_repo_intake_collect.py helper, without writing a filled intake sheet,
running audits, or counting any repo for beta evidence.

Raw owner/maintainer contacts are treated as local input only. The output
contains contact hashes and redacted collector command placeholders, not raw
contact values.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_repo_discovery_response.v1"
REQUEST_SCHEMA = "amr_beta_repo_discovery_request.v1"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
REQUEST_READ_ONLY_FLAGS = [
    "repo_intake_rows_counted",
    "ready_for_repo_intake",
    "writes_repo_intake_sheet",
    "runs_audit",
    "runs_label_template_generation",
    "writes_reviewer_packets",
    "creates_benchmark_evidence",
]
RESPONSE_ALIASES = {
    "case_id": "suggested_case_id",
    "candidate_id": "suggested_case_id",
    "include": "include_for_real_benchmark_intake",
    "selected": "include_for_real_benchmark_intake",
    "use_for_intake": "include_for_real_benchmark_intake",
    "include_for_intake": "include_for_real_benchmark_intake",
    "contact": "owner_or_maintainer_contact",
    "maintainer_contact": "owner_or_maintainer_contact",
    "owner_contact": "owner_or_maintainer_contact",
    "namespace_confirmed": "real_benchmark_namespace_confirmed",
    "real_benchmark_confirmed": "real_benchmark_namespace_confirmed",
    "confirm_real_benchmark_namespace": "real_benchmark_namespace_confirmed",
    "source_confirmed": "human_real_repo_source_confirmed",
    "real_repo_source_confirmed": "human_real_repo_source_confirmed",
    "human_source_confirmed": "human_real_repo_source_confirmed",
    "confirm_real_repo_source": "human_real_repo_source_confirmed",
}
TRUTHY = {"1", "true", "yes", "y"}
FALSEY = {"", "0", "false", "no", "n"}


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_text(value: str) -> str:
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def read_json(path: Path, name: str) -> dict:
    raw_path = path.expanduser()
    if is_forbidden_env_path(raw_path) or is_forbidden_env_path(raw_path.resolve()):
        raise ValueError(f"refusing .env-like {name} path")
    payload = json.loads(raw_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{name} must contain an object")
    return payload


def normalize_header(value: str) -> str:
    text = re.sub(r"\([^)]*\)", "", str(value).strip().lower())
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return RESPONSE_ALIASES.get(text, text)


def truthy(value: object) -> bool:
    return str(value or "").strip().lower() in TRUTHY


def falsey(value: object) -> bool:
    return str(value or "").strip().lower() in FALSEY


def int_flag(payload: dict, key: str, default: int = 0) -> int:
    raw = payload.get(key, default)
    if isinstance(raw, bool):
        return int(raw)
    if isinstance(raw, int):
        return raw
    return default


def optional_int_flag(payload: dict, key: str, *, errors: list[str], name: str) -> int:
    if key not in payload:
        return 0
    raw = payload.get(key)
    if isinstance(raw, bool) or not isinstance(raw, int) or raw not in {0, 1}:
        errors.append(f"{name}: {key} must be one of [0, 1]")
        return 0
    return raw


def optional_nonnegative_int(
    payload: dict,
    key: str,
    *,
    default: int,
    errors: list[str],
    name: str,
) -> int:
    if key not in payload:
        return default
    raw = payload.get(key)
    if isinstance(raw, bool) or not isinstance(raw, int) or raw < 0:
        errors.append(f"{name}: {key} must be an integer >= 0")
        return default
    return raw


def output_exists_errors(paths: dict[str, Path], overwrite: bool) -> list[str]:
    errors: list[str] = []
    seen: dict[Path, str] = {}
    for name, path in paths.items():
        raw_path = path.expanduser()
        if is_forbidden_env_path(raw_path):
            errors.append(f"{name} must not be .env-like")
        resolved = raw_path.resolve()
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen:
            errors.append(f"{name} must not reuse {seen[resolved]} path: {resolved}")
        seen[resolved] = name
        if resolved.exists() and not overwrite:
            errors.append(f"{name} already exists; use --overwrite: {resolved}")
        tmp_path = resolved.with_name(resolved.name + ".tmp")
        if tmp_path.exists():
            errors.append(f"{name} temporary output already exists: {tmp_path}")
    return errors


def validate_request(payload: dict) -> list[str]:
    errors: list[str] = []
    if str(payload.get("schema") or "") != REQUEST_SCHEMA:
        errors.append("repo_discovery_request: unexpected schema")
    if payload.get("errors"):
        errors.append("repo_discovery_request: artifact contains errors")
    for key in REQUEST_READ_ONLY_FLAGS:
        if int_flag(payload, key) != 0:
            errors.append(f"repo_discovery_request: must keep {key}=0")
    for key, expected in BLOCKED_FLAGS.items():
        if int_flag(payload, key) != expected:
            errors.append(f"repo_discovery_request: must keep {key}=0")
    request_rows = payload.get("request_rows")
    if not isinstance(request_rows, list):
        errors.append("repo_discovery_request: request_rows must be a list")
    return errors


def request_rows_by_case(payload: dict) -> dict[str, dict]:
    request_rows = payload.get("request_rows", [])
    if not isinstance(request_rows, list):
        return {}
    rows: dict[str, dict] = {}
    for row in request_rows:
        if not isinstance(row, dict):
            continue
        case_id = str(row.get("suggested_case_id") or "").strip()
        if case_id:
            rows[case_id] = row
    return rows


def request_repo_paths(payload: dict) -> list[str]:
    rows = payload.get("request_rows", [])
    if not isinstance(rows, list):
        return []
    return [str(row.get("repo_path") or "") for row in rows if isinstance(row, dict)]


def requires_source_confirmation(request_row: dict) -> bool:
    risk_flags = request_row.get("path_risk_flags", [])
    return int_flag(request_row, "human_real_repo_source_confirmation_required") == 1 or bool(risk_flags)


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return [
            {normalize_header(key or ""): str(value or "").strip() for key, value in row.items()}
            for row in reader
        ]


def read_markdown_rows(path: Path) -> list[dict[str, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    rows: list[dict[str, str]] = []
    header: list[str] | None = None
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            if header and rows:
                break
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if all(set(cell.replace(":", "").strip()) <= {"-"} for cell in cells):
            continue
        normalized = [normalize_header(cell) for cell in cells]
        if header is None:
            if "suggested_case_id" in normalized:
                header = normalized
            continue
        rows.append({column: cells[index] if index < len(cells) else "" for index, column in enumerate(header)})
    return rows


def read_response_rows(path: Path) -> list[dict[str, str]]:
    raw_path = path.expanduser()
    if is_forbidden_env_path(raw_path) or is_forbidden_env_path(raw_path.resolve()):
        raise ValueError("refusing to read .env-like response path")
    text = raw_path.read_text(encoding="utf-8")
    first_nonempty = next((line.strip() for line in text.splitlines() if line.strip()), "")
    if first_nonempty.startswith("|"):
        return read_markdown_rows(raw_path)
    return read_csv_rows(raw_path)


def git_text(repo: Path, args: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def current_repo_preflight(request_row: dict, repo_path: str, row_index: int) -> tuple[dict[str, object], list[str]]:
    errors: list[str] = []
    repo = Path(repo_path).expanduser().resolve()
    request_head = str(request_row.get("actual_repo_git_head") or "").strip().lower()
    status = {
        "current_repo_git_preflight_passed": 0,
        "current_repo_git_worktree_confirmed": 0,
        "current_repo_git_root": "",
        "current_repo_head_readable": 0,
        "current_repo_git_head": "",
        "current_repo_head_matches_request": 0,
        "current_repo_status_readable": 0,
        "current_repo_clean_worktree": 0,
    }
    if is_forbidden_env_path(repo):
        errors.append(f"response row {row_index}: current repo path must not be .env-like")
        return status, errors
    if not repo.is_dir():
        errors.append(f"response row {row_index}: current repo_path is not a directory: {repo}")
        return status, errors

    code, inside, _ = git_text(repo, ["rev-parse", "--is-inside-work-tree"])
    if code != 0 or inside.strip() != "true":
        errors.append(f"response row {row_index}: current repo_path is not a git worktree")
        return status, errors
    status["current_repo_git_worktree_confirmed"] = 1

    root_code, root, _ = git_text(repo, ["rev-parse", "--show-toplevel"])
    if root_code != 0 or not root.strip():
        errors.append(f"response row {row_index}: unable to read current git worktree root")
    else:
        git_root = str(Path(root.strip()).expanduser().resolve())
        status["current_repo_git_root"] = git_root
        if git_root != str(repo):
            errors.append(f"response row {row_index}: current repo_path must be git worktree root")

    head_code, head, _ = git_text(repo, ["rev-parse", "HEAD"])
    current_head = head.strip().lower()
    if head_code != 0 or not current_head:
        errors.append(f"response row {row_index}: unable to read current git HEAD")
    else:
        status["current_repo_head_readable"] = 1
        status["current_repo_git_head"] = current_head
        if current_head == request_head:
            status["current_repo_head_matches_request"] = 1
        else:
            errors.append(f"response row {row_index}: current git HEAD changed since request packet")

    status_code, porcelain, _ = git_text(repo, ["status", "--porcelain=v1", "--untracked-files=all"])
    if status_code != 0:
        errors.append(f"response row {row_index}: unable to read current git status")
    else:
        status["current_repo_status_readable"] = 1
        if porcelain.strip():
            errors.append(f"response row {row_index}: current git status must be clean")
        else:
            status["current_repo_clean_worktree"] = 1

    status["current_repo_git_preflight_passed"] = int(not errors)
    return status, errors


def validate_response_rows(
    *,
    request: dict,
    response_rows: list[dict[str, str]],
    min_repos: int,
) -> tuple[list[dict[str, object]], list[str], list[str]]:
    errors: list[str] = []
    blockers: list[str] = []
    by_case = request_rows_by_case(request)
    seen_cases: set[str] = set()
    selected: list[dict[str, object]] = []
    if not response_rows:
        errors.append("response: must contain at least one row")
        return selected, errors, blockers

    for index, row in enumerate(response_rows, start=1):
        case_id = str(row.get("suggested_case_id") or "").strip()
        include_raw = row.get("include_for_real_benchmark_intake", "")
        if not case_id:
            errors.append(f"response row {index}: suggested_case_id is required")
            continue
        if case_id in seen_cases:
            errors.append(f"response row {index}: duplicate suggested_case_id")
            continue
        seen_cases.add(case_id)
        request_row = by_case.get(case_id)
        if request_row is None:
            errors.append(f"response row {index}: suggested_case_id not found in request packet")
            continue
        if falsey(include_raw):
            continue
        if not truthy(include_raw):
            errors.append(f"response row {index}: include_for_real_benchmark_intake must be true/false")
            continue

        contact = str(row.get("owner_or_maintainer_contact") or "").strip()
        if not repo_intake.good_operator_value(contact) or not repo_intake.good_contact_value(contact):
            errors.append(f"response row {index}: owner_or_maintainer_contact must be human-supplied")
        if not truthy(row.get("real_benchmark_namespace_confirmed", "")):
            errors.append(f"response row {index}: real_benchmark_namespace_confirmed must be true")
        source_confirmed = truthy(row.get("human_real_repo_source_confirmed", ""))
        if requires_source_confirmation(request_row) and not source_confirmed:
            errors.append(f"response row {index}: human_real_repo_source_confirmed must be true")

        if int_flag(request_row, "recommended_for_contact_request") != 1:
            errors.append(f"response row {index}: selected candidate is not clean/head-ready in request packet")
        for key in ["repo_git_worktree_confirmed", "repo_head_readable", "repo_status_readable"]:
            if int_flag(request_row, key) != 1:
                errors.append(f"response row {index}: request packet {key} must be 1")
        if request_row.get("clean_worktree_actual") != 1:
            errors.append(f"response row {index}: request packet clean_worktree_actual must be 1")
        if int_flag(request_row, "counts_for_repo_intake") != 0:
            errors.append(f"response row {index}: request packet counts_for_repo_intake must be 0")
        if str(request_row.get("suggested_namespace") or "") != "real_benchmark":
            errors.append(f"response row {index}: request packet suggested_namespace must be real_benchmark")

        response_repo = str(row.get("repo_path") or "").strip()
        request_repo = str(request_row.get("repo_path") or "").strip()
        if response_repo and str(Path(response_repo).expanduser().resolve()) != str(Path(request_repo).expanduser().resolve()):
            errors.append(f"response row {index}: repo_path must match request packet")

        audit_mode = str(row.get("audit_mode") or request_row.get("suggested_audit_mode") or "quick").strip().lower()
        if audit_mode not in {"quick", "full"}:
            errors.append(f"response row {index}: audit_mode must be quick or full")

        current_status, current_errors = current_repo_preflight(request_row, request_repo, index)
        errors.extend(current_errors)

        selected.append(
            {
                "row_index": index,
                "suggested_case_id": case_id,
                "repo_path": request_repo,
                "actual_repo_git_head": request_row.get("actual_repo_git_head", ""),
                "audit_mode": audit_mode,
                "owner_or_maintainer_contact_sha256": sha256_text(contact),
                "real_benchmark_namespace_confirmed": 1,
                "human_real_repo_source_confirmed": int(source_confirmed),
                "counts_for_repo_intake": 0,
                **current_status,
            }
        )

    if len(selected) < min_repos:
        blockers.append(f"Need {min_repos - len(selected)} more selected clean repo response rows before collect.")
    return selected, errors, blockers


def current_preflight_completion(selected_rows: list[dict[str, object]]) -> dict[str, int]:
    failed_rows = [
        row
        for row in selected_rows
        if int_flag(row, "current_repo_git_preflight_passed") != 1
    ]
    return {
        "selected_current_repo_preflight_passed_rows": sum(
            1 for row in selected_rows if int_flag(row, "current_repo_git_preflight_passed") == 1
        ),
        "selected_current_repo_preflight_failed_rows": len(failed_rows),
        "selected_current_repo_head_mismatch_rows": sum(
            1 for row in failed_rows if int_flag(row, "current_repo_head_matches_request") != 1
        ),
        "selected_current_repo_dirty_rows": sum(
            1 for row in failed_rows if int_flag(row, "current_repo_clean_worktree") != 1
        ),
        "selected_current_repo_missing_or_not_git_rows": sum(
            1
            for row in failed_rows
            if int_flag(row, "current_repo_git_worktree_confirmed") != 1
            or int_flag(row, "current_repo_head_readable") != 1
            or int_flag(row, "current_repo_status_readable") != 1
        ),
        "selected_current_repo_root_mismatch_rows": sum(
            1
            for row in failed_rows
            if str(row.get("current_repo_git_root") or "").strip()
            and str(Path(str(row.get("current_repo_git_root"))).expanduser().resolve())
            != str(Path(str(row.get("repo_path") or "")).expanduser().resolve())
        ),
    }


def summarize_response_completion(
    *,
    request: dict,
    response_rows: list[dict[str, str]],
    min_repos: int,
) -> dict[str, int]:
    by_case = request_rows_by_case(request)
    recommended_cases = {
        case_id
        for case_id, request_row in by_case.items()
        if int_flag(request_row, "recommended_for_contact_request") == 1
    }
    seen_cases: set[str] = set()
    selected_truthy = 0
    unselected = 0
    blank_include = 0
    invalid_include = 0
    duplicate_case_id = 0
    selected_unknown_case_id = 0
    selected_not_recommended = 0
    selected_missing_contact = 0
    selected_missing_namespace = 0
    selected_missing_source_confirmation = 0
    selected_repo_path_mismatch = 0

    for row in response_rows:
        case_id = str(row.get("suggested_case_id") or "").strip()
        include_raw = row.get("include_for_real_benchmark_intake", "")
        include_text = str(include_raw or "").strip()
        if case_id in seen_cases:
            duplicate_case_id += 1
        elif case_id:
            seen_cases.add(case_id)

        if falsey(include_raw):
            unselected += 1
            if not include_text:
                blank_include += 1
            continue
        if not truthy(include_raw):
            invalid_include += 1
            continue

        selected_truthy += 1
        request_row = by_case.get(case_id)
        if request_row is None:
            selected_unknown_case_id += 1
        elif case_id not in recommended_cases:
            selected_not_recommended += 1

        contact = str(row.get("owner_or_maintainer_contact") or "").strip()
        if not repo_intake.good_operator_value(contact) or not repo_intake.good_contact_value(contact):
            selected_missing_contact += 1
        if not truthy(row.get("real_benchmark_namespace_confirmed", "")):
            selected_missing_namespace += 1
        if request_row and requires_source_confirmation(request_row) and not truthy(
            row.get("human_real_repo_source_confirmed", "")
        ):
            selected_missing_source_confirmation += 1

        response_repo = str(row.get("repo_path") or "").strip()
        if request_row and response_repo:
            request_repo = str(request_row.get("repo_path") or "").strip()
            if str(Path(response_repo).expanduser().resolve()) != str(Path(request_repo).expanduser().resolve()):
                selected_repo_path_mismatch += 1

    return {
        "request_row_count": len(by_case),
        "response_row_count": len(response_rows),
        "recommended_request_rows": len(recommended_cases),
        "selected_truthy_response_rows": selected_truthy,
        "unselected_response_rows": unselected,
        "blank_include_response_rows": blank_include,
        "invalid_include_response_rows": invalid_include,
        "duplicate_case_id_response_rows": duplicate_case_id,
        "selected_unknown_case_id_rows": selected_unknown_case_id,
        "selected_not_recommended_rows": selected_not_recommended,
        "selected_missing_or_invalid_contact_rows": selected_missing_contact,
        "selected_missing_namespace_confirmation_rows": selected_missing_namespace,
        "selected_missing_source_confirmation_rows": selected_missing_source_confirmation,
        "selected_repo_path_mismatch_rows": selected_repo_path_mismatch,
        "selected_response_rows_remaining_to_minimum": max(0, min_repos - selected_truthy),
        "human_required_cells_remaining": (
            blank_include
            + selected_missing_contact
            + selected_missing_namespace
            + selected_missing_source_confirmation
            + invalid_include
        ),
    }


def collector_command(selected_rows: list[dict[str, object]], collector_out: Path, collector_format: str) -> list[str]:
    command = ["python3", "scripts/amr_beta_repo_intake_collect.py"]
    for row in selected_rows:
        case_id = str(row["suggested_case_id"])
        command.extend(["--repo", str(row["repo_path"])])
        command.extend(["--contact", f"<contact-for-{case_id}>"])
        command.extend(["--case-id", case_id])
    command.extend(["--confirm-real-benchmark-namespace", "--out", str(collector_out)])
    if collector_format != "md":
        command.extend(["--format", collector_format])
    return command


def build_payload(
    *,
    request_path: Path,
    response_path: Path,
    collector_out: Path,
    collector_format: str,
    request: dict,
    response_rows: list[dict[str, str]],
    selected_rows: list[dict[str, object]],
    min_repos: int,
    errors: list[str],
    blockers: list[str],
) -> dict[str, object]:
    command = collector_command(selected_rows, collector_out, collector_format) if selected_rows else []
    response_completion = summarize_response_completion(
        request=request,
        response_rows=response_rows,
        min_repos=min_repos,
    )
    response_completion.update(current_preflight_completion(selected_rows))
    request_response_template_recommended_only = optional_int_flag(
        request,
        "response_template_recommended_only",
        errors=errors,
        name="repo_discovery_request",
    )
    request_response_template_row_count = optional_nonnegative_int(
        request,
        "response_template_row_count",
        default=0,
        errors=errors,
        name="repo_discovery_request",
    )
    selected_fingerprint = sha256_json(
        [
            {
                "suggested_case_id": row["suggested_case_id"],
                "repo_path": row["repo_path"],
                "owner_or_maintainer_contact_sha256": row["owner_or_maintainer_contact_sha256"],
            }
            for row in selected_rows
        ]
    )
    ready = int(not errors and len(selected_rows) >= min_repos)
    return {
        "schema": SCHEMA,
        "repo_discovery_request": str(request_path),
        "repo_discovery_request_sha256": sha256_file(request_path) if request_path.exists() else "",
        "human_response": str(response_path),
        "human_response_sha256": sha256_file(response_path) if response_path.exists() else "",
        "request_response_template_recommended_only": request_response_template_recommended_only,
        "request_response_template_row_count": request_response_template_row_count,
        "response_row_count": len(response_rows),
        "response_completion": response_completion,
        "human_required_cells_remaining": response_completion["human_required_cells_remaining"],
        "selected_response_rows": len(selected_rows),
        "valid_selected_response_rows": 0 if errors else len(selected_rows),
        "min_real_repos_required": min_repos,
        "ready_for_repo_intake_collect_command": ready,
        "selected_rows_cannot_count_until_collector_and_validator_pass": 1,
        "collector_out": str(collector_out),
        "collector_format": collector_format,
        "collector_command_redacted": " ".join(shlex.quote(part) for part in command),
        "collector_command_argv_redacted": command,
        "selected_case_ids": [row["suggested_case_id"] for row in selected_rows],
        "selected_response_fingerprint_sha256": selected_fingerprint,
        "selected_rows": selected_rows,
        "repo_intake_rows_counted": 0,
        "ready_for_repo_intake": 0,
        "writes_repo_intake_sheet": 0,
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        **BLOCKED_FLAGS,
        "next_blockers": blockers,
        "errors": errors,
    }


def markdown_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def write_json(path: Path, payload: dict[str, object], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    tmp_path = path.with_name(path.name + ".tmp")
    tmp_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp_path.replace(path)


def write_markdown(path: Path, payload: dict[str, object], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Repo Discovery Response Status",
        "",
        f"- ready_for_repo_intake_collect_command: {payload['ready_for_repo_intake_collect_command']}",
        f"- repo_intake_rows_counted: {payload['repo_intake_rows_counted']}",
        f"- request_response_template_recommended_only: {payload['request_response_template_recommended_only']}",
        f"- request_response_template_row_count: {payload['request_response_template_row_count']}",
        f"- selected_response_rows: {payload['selected_response_rows']}",
        f"- min_real_repos_required: {payload['min_real_repos_required']}",
        f"- human_required_cells_remaining: {payload['human_required_cells_remaining']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        "",
        "## Response Completion",
        "",
        "| metric | value |",
        "|---|---:|",
    ]
    completion = payload["response_completion"]
    for key in [
        "recommended_request_rows",
        "selected_truthy_response_rows",
        "unselected_response_rows",
        "blank_include_response_rows",
        "invalid_include_response_rows",
        "selected_missing_or_invalid_contact_rows",
        "selected_missing_namespace_confirmation_rows",
        "selected_missing_source_confirmation_rows",
        "selected_current_repo_preflight_passed_rows",
        "selected_current_repo_preflight_failed_rows",
        "selected_current_repo_head_mismatch_rows",
        "selected_current_repo_dirty_rows",
        "selected_current_repo_missing_or_not_git_rows",
        "selected_current_repo_root_mismatch_rows",
        "selected_response_rows_remaining_to_minimum",
        "human_required_cells_remaining",
    ]:
        lines.append(f"| {key} | {completion[key]} |")
    lines.extend(
        [
            "",
            "## Redacted Collector Command",
            "",
            "```bash",
            str(payload["collector_command_redacted"]),
            "```",
            "",
            "## Selected Rows",
            "",
            "| suggested_case_id | repo_path | audit_mode | contact_sha256 |",
            "|---|---|---|---|",
        ]
    )
    for row in payload["selected_rows"]:
        lines.append(
            "| {case_id} | {repo} | {audit_mode} | {contact_sha} |".format(
                case_id=markdown_cell(row.get("suggested_case_id", "")),
                repo=markdown_cell(row.get("repo_path", "")),
                audit_mode=markdown_cell(row.get("audit_mode", "")),
                contact_sha=markdown_cell(row.get("owner_or_maintainer_contact_sha256", "")),
            )
        )
    if payload["next_blockers"]:
        lines.extend(["", "## Next Blockers", ""])
        lines.extend(f"- {blocker}" for blocker in payload["next_blockers"])
    tmp_path = path.with_name(path.name + ".tmp")
    tmp_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    tmp_path.replace(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request-json", required=True, help="JSON from amr_beta_repo_discovery_request.py.")
    parser.add_argument("--response", required=True, help="Human-edited Markdown or CSV response.")
    parser.add_argument("--collector-out", default="/tmp/amr_beta_repo_intake.md")
    parser.add_argument("--collector-format", choices=["md", "csv"], default="md")
    parser.add_argument("--min-repos", type=int, default=0)
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-md", default="")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    raw_request_path = Path(args.request_json).expanduser()
    raw_response_path = Path(args.response).expanduser()
    raw_collector_out = Path(args.collector_out).expanduser()
    request_path = raw_request_path.resolve()
    response_path = raw_response_path.resolve()
    collector_out = raw_collector_out.resolve()
    raw_out_paths = {"out_json": Path(args.out_json).expanduser()}
    if args.out_md:
        raw_out_paths["out_md"] = Path(args.out_md).expanduser()
    out_paths = {name: path.resolve() for name, path in raw_out_paths.items()}

    request: dict[str, object] = {}
    response_rows: list[dict[str, str]] = []
    selected_rows: list[dict[str, object]] = []
    errors: list[str] = []
    blockers: list[str] = []
    try:
        request = read_json(raw_request_path, "repo discovery request")
    except Exception as exc:
        errors.append(str(exc))
    if request:
        errors.extend(validate_request(request))
        target_repo_paths = request_repo_paths(request)
        guarded_paths = {"response": raw_response_path, "collector_out": raw_collector_out, **raw_out_paths}
        errors.extend(repo_intake.validate_output_paths(guarded_paths, target_repo_paths))
    try:
        response_rows = read_response_rows(raw_response_path)
    except Exception as exc:
        errors.append(str(exc))

    min_repos = args.min_repos or int_flag(request, "min_real_repos_required", repo_intake.MIN_REAL_REPOS_FOR_BETA)
    if min_repos < 1:
        errors.append("--min-repos must be positive")
        min_repos = repo_intake.MIN_REAL_REPOS_FOR_BETA
    if request and response_rows:
        selected_rows, row_errors, blockers = validate_response_rows(
            request=request,
            response_rows=response_rows,
            min_repos=min_repos,
        )
        errors.extend(row_errors)
    errors.extend(output_exists_errors(raw_out_paths, args.overwrite))

    payload = build_payload(
        request_path=request_path,
        response_path=response_path,
        collector_out=collector_out,
        collector_format=args.collector_format,
        request=request,
        response_rows=response_rows,
        selected_rows=selected_rows,
        min_repos=min_repos,
        errors=errors,
        blockers=blockers,
    )
    if not errors:
        try:
            write_json(out_paths["out_json"], payload, args.overwrite)
            if args.out_md:
                write_markdown(out_paths["out_md"], payload, args.overwrite)
        except Exception as exc:
            errors.append(str(exc))
            payload["errors"] = errors
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    if not args.json:
        print(
            "repo_discovery_response: ok "
            f"selected_response_rows={payload['selected_response_rows']} "
            f"ready_for_repo_intake_collect_command={payload['ready_for_repo_intake_collect_command']} "
            f"repo_intake_rows_counted={payload['repo_intake_rows_counted']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
