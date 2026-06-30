#!/usr/bin/env python3
"""Summarize AMR beta operator stage from existing local artifacts.

This is a read-only PM/operator status helper. It consumes optional AMR beta
artifact JSON files and reports the latest proven stage plus next blockers.

It does not create benchmark evidence, does not run benchmarks, does not read
raw feedback text, and does not promote release/model/public-comparison claims.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import sys
from pathlib import Path

SCHEMA = "amr_beta_operator_status.v1"
APPROVAL_SCOPE = "amr_beta_real_benchmark_runtime"
BLOCKED_FLAGS = {
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
GIT_OBJECT_RE = re.compile(r"^([0-9a-f]{40}|[0-9a-f]{64})$")
KNOWN_ARTIFACTS = {
    "repo_audit_plan": "amr_beta_repo_audit_plan.v1",
    "label_intake_plan": "amr_beta_label_intake_plan.v1",
    "maintainer_feedback_packet": "amr_beta_maintainer_feedback_packet.v1",
    "runtime_preflight": "amr_beta_runtime_preflight.v1",
    "runtime_approval_request": "amr_beta_runtime_approval_request.v1",
    "runtime_approval_status": "amr_beta_runtime_approval_status.v1",
    "readiness_backlog": "amr_beta_readiness_backlog.v1",
}
STAGE_ORDER = [
    "stage_0_claim_freeze",
    "stage_1_repo_intake_plan_ready",
    "stage_2_label_intake_plan_ready",
    "stage_3_maintainer_feedback_ready",
    "stage_4_runtime_preflight_ready",
    "stage_4_runtime_approval_verified",
    "stage_4_real_benchmark_verified",
    "stage_5_beta_candidate_or_hardening",
]
PREFLIGHT_SHA_BINDING_KEYS = [
    "repo_intake_sha256",
    "repo_snapshot_lock_sha256",
    "decisions_sha256",
    "feedback_sha256",
    "feedback_bundle_sha256",
    "label_template_bundle_sha256",
    "label_intake_bundle_sha256",
    "preflight_input_bundle_sha256",
]
PREFLIGHT_LIST_BINDING_KEYS = [
    "label_template_json_sha256s",
    "label_template_manifest_sha256s",
    "label_intake_manifest_sha256s",
]
PREFLIGHT_PATH_GUARD_KEYS = [
    "input_path_preflight_passed",
    "output_path_preflight_passed",
]
REPO_AUDIT_PLAN_READ_ONLY_FLAGS = [
    "runs_audit",
    "runs_label_template_generation",
    "writes_reviewer_packets",
    "creates_benchmark_evidence",
]
REPO_AUDIT_PLAN_COMMAND_FIELDS = [
    "audit_command",
    "audit_verify_command",
    "label_template_command",
    "label_template_verify_command",
    "reviewer_packet_command",
]
LABEL_INTAKE_PLAN_READ_ONLY_FLAGS = [
    "compiles_labels",
    "writes_label_intake_outputs",
    "creates_benchmark_evidence",
    "runs_real_benchmark",
]
LABEL_INTAKE_PLAN_COMMAND_FIELDS = [
    "compile_command",
    "verify_command",
]


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def command_line(parts: list[object]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def same_path(left: str, right: str) -> bool:
    if not left or not right:
        return False
    return str(Path(left).expanduser().resolve()) == str(Path(right).expanduser().resolve())


def read_json(path: Path, input_name: str) -> dict:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} path")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def artifact_schema(payload: dict) -> str:
    return str(payload.get("schema") or payload.get("schema_version") or "")


def truthy_int(payload: dict, key: str) -> int:
    try:
        return int(payload.get(key, 0))
    except (TypeError, ValueError):
        return 0


def strict_int_flag_errors(name: str, payload: dict, keys: list[str], allowed: set[int]) -> list[str]:
    errors: list[str] = []
    for key in keys:
        raw = payload.get(key, 0)
        try:
            value = int(raw)
        except (TypeError, ValueError):
            errors.append(f"{name}: {key} must be one of {sorted(allowed)}")
            continue
        if value not in allowed:
            errors.append(f"{name}: {key} must be one of {sorted(allowed)}")
    return errors


def artifact_claim_errors(name: str, payload: dict) -> list[str]:
    claim_keys = list(BLOCKED_FLAGS)
    errors = strict_int_flag_errors(name, payload, claim_keys, {0, 1})
    for key, expected in BLOCKED_FLAGS.items():
        if truthy_int(payload, key) != expected:
            errors.append(f"{name}: must keep {key}=0")
    if name != "benchmark_readiness" and truthy_int(payload, "design_partner_beta_candidate_ready") != 0:
        errors.append(f"{name}: must not promote design_partner_beta_candidate_ready")
    return errors


def load_optional(path_text: str, name: str) -> tuple[dict | None, dict | None, list[str]]:
    if not path_text:
        return None, None, []
    path = Path(path_text).expanduser().resolve()
    try:
        payload = read_json(path, name)
    except Exception as exc:
        return None, None, [f"{name}: {exc}"]
    meta = {
        "path": str(path),
        "sha256": sha256_file(path),
        "schema": artifact_schema(payload),
    }
    errors: list[str] = []
    expected_schema = KNOWN_ARTIFACTS.get(name)
    if expected_schema and meta["schema"] != expected_schema:
        errors.append(f"{name}: unexpected schema {meta['schema']!r}")
    errors.extend(artifact_claim_errors(name, payload))
    raw_errors = payload.get("errors", [])
    if raw_errors:
        errors.append(f"{name}: artifact contains errors")
    return payload, meta, errors


def benchmark_readiness_errors(payload: dict) -> list[str]:
    errors = artifact_claim_errors("benchmark_readiness", payload)
    errors.extend(
        strict_int_flag_errors("benchmark_readiness", payload, ["design_partner_beta_candidate_ready"], {0, 1})
    )
    if payload.get("schema_version") != "local_repo_audit_benchmark_readiness.v1":
        errors.append("benchmark_readiness: unexpected schema_version")
    real_label_basis = int(
        truthy_int(payload, "real_human_label_basis") == 1
        or truthy_int(payload, "product_readiness_calculated_from_real_labels") == 1
    )
    if real_label_basis != 1:
        errors.append(
            "benchmark_readiness: product_readiness_calculated_from_real_labels "
            "or real_human_label_basis must be 1 for real benchmark evidence"
        )
    return errors


def load_benchmark_readiness(path_text: str) -> tuple[dict | None, dict | None, list[str]]:
    if not path_text:
        return None, None, []
    path = Path(path_text).expanduser().resolve()
    try:
        payload = read_json(path, "benchmark_readiness")
    except Exception as exc:
        return None, None, [f"benchmark_readiness: {exc}"]
    meta = {
        "path": str(path),
        "sha256": sha256_file(path),
        "schema": artifact_schema(payload),
    }
    return payload, meta, benchmark_readiness_errors(payload)


def require_flag(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    key: str,
    expected: int,
) -> None:
    if key not in payload:
        errors.append(f"{name}: {key} must be present as an integer or boolean flag")
        return
    raw = payload.get(key)
    if isinstance(raw, bool):
        value = int(raw)
    elif isinstance(raw, int):
        value = raw
    else:
        errors.append(f"{name}: {key} must be an integer or boolean flag")
        return
    if value not in {0, 1}:
        errors.append(f"{name}: {key} must be one of [0, 1]")
        return
    if value != expected:
        errors.append(f"{name}: must set {key}={expected}")


def require_int_at_least(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    key: str,
    minimum: int,
) -> int:
    raw = payload.get(key)
    if isinstance(raw, bool) or not isinstance(raw, int):
        errors.append(f"{name}: {key} must be an integer >= {minimum}")
        return 0
    value = raw
    if value < minimum:
        errors.append(f"{name}: {key} must be >= {minimum}")
    return value


def require_exact_int(*, errors: list[str], name: str, payload: dict, key: str) -> int:
    raw = payload.get(key)
    if isinstance(raw, bool) or not isinstance(raw, int):
        errors.append(f"{name}: {key} must be an integer")
        return -1
    return raw


def require_bound_path(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected_path: str,
) -> None:
    value = str(payload.get(field) or "")
    if not same_path(value, expected_path):
        errors.append(f"{name}: {field} must match supplied artifact path")


def require_bound_sha(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected_sha: str,
) -> None:
    value = str(payload.get(field) or "")
    if value != expected_sha:
        errors.append(f"{name}: {field} must match supplied artifact sha256")


def require_sha_field(*, errors: list[str], name: str, payload: dict, field: str) -> None:
    value = str(payload.get(field) or "")
    if not SHA256_RE.fullmatch(value):
        errors.append(f"{name}: {field} must be a sha256 binding")


def require_sha_list_field(*, errors: list[str], name: str, payload: dict, field: str) -> None:
    values = payload.get(field)
    if not isinstance(values, list):
        errors.append(f"{name}: {field} must be a sha256 binding list")
        return
    for value in values:
        text = str(value or "")
        if not SHA256_RE.fullmatch(text):
            errors.append(f"{name}: {field} must contain only sha256 bindings")
            return


def require_matching_field(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected: object,
) -> None:
    if payload.get(field) != expected:
        errors.append(f"{name}: {field} must match runtime_preflight")


def require_matching_artifact_field(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected: object,
    expected_name: str,
) -> None:
    if payload.get(field) != expected:
        errors.append(f"{name}: {field} must match {expected_name}")


def require_repo_snapshot_lock_rows(
    *,
    errors: list[str],
    repo: dict,
    valid_repo_rows: int,
) -> dict[str, dict]:
    rows = repo.get("repo_snapshot_lock_rows")
    if not isinstance(rows, list):
        errors.append("repo_audit_plan: repo_snapshot_lock_rows must be a list")
        return {}

    row_count = require_exact_int(
        errors=errors,
        name="repo_audit_plan",
        payload=repo,
        key="repo_snapshot_lock_row_count",
    )
    if row_count >= 0 and row_count != len(rows):
        errors.append("repo_audit_plan: repo_snapshot_lock_row_count must match repo_snapshot_lock_rows length")
    if valid_repo_rows > 0 and len(rows) != valid_repo_rows:
        errors.append("repo_audit_plan: repo_snapshot_lock_rows length must match valid_repo_rows")
    if str(repo.get("repo_snapshot_lock_sha256") or "") != sha256_json(rows):
        errors.append("repo_audit_plan: repo_snapshot_lock_sha256 must match repo_snapshot_lock_rows")

    lock_by_case: dict[str, dict] = {}
    seen_paths: set[str] = set()
    for index, row in enumerate(rows, start=1):
        prefix = f"repo_audit_plan: repo_snapshot_lock_rows row {index}"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            return {}

        case_id = str(row.get("case_id") or "").strip()
        if not case_id:
            errors.append(f"{prefix}: case_id must be present")
            continue
        if case_id in lock_by_case:
            errors.append(f"{prefix}: duplicate case_id")
            continue

        repo_path = str(row.get("repo_path_resolved") or "").strip()
        if not repo_path:
            errors.append(f"{prefix}: repo_path_resolved must be present")
        else:
            canonical_repo_path = str(Path(repo_path).expanduser().resolve())
            if canonical_repo_path in seen_paths:
                errors.append(f"{prefix}: duplicate repo_path_resolved")
            seen_paths.add(canonical_repo_path)

        expected_head = str(row.get("expected_repo_git_head") or "").strip().lower()
        actual_head = str(row.get("actual_repo_git_head") or "").strip().lower()
        if not GIT_OBJECT_RE.fullmatch(expected_head):
            errors.append(f"{prefix}: expected_repo_git_head must be a full git object id")
        if not GIT_OBJECT_RE.fullmatch(actual_head):
            errors.append(f"{prefix}: actual_repo_git_head must be a full git object id")
        if expected_head and actual_head and expected_head != actual_head:
            errors.append(f"{prefix}: expected_repo_git_head must match actual_repo_git_head")

        for key in [
            "clean_worktree_declared",
            "clean_worktree_actual",
            "owner_or_maintainer_contact_present",
            "real_benchmark_namespace_confirmed",
            "valid",
        ]:
            value = row.get(key)
            if isinstance(value, bool) or not isinstance(value, int):
                errors.append(f"{prefix}: {key} must be an integer")
            elif value != 1:
                errors.append(f"{prefix}: {key} must be 1")

        audit_mode = str(row.get("audit_mode") or "").strip().lower()
        if audit_mode not in {"quick", "full"}:
            errors.append(f"{prefix}: audit_mode must be quick or full")
        if str(row.get("namespace") or "").strip() != "real_benchmark":
            errors.append(f"{prefix}: namespace must be real_benchmark")

        lock_by_case[case_id] = row
    return lock_by_case


def require_repo_operator_commands(
    *,
    errors: list[str],
    repo: dict,
    valid_repo_rows: int,
    snapshot_lock_rows: dict[str, dict],
) -> None:
    commands = repo.get("operator_commands")
    if not isinstance(commands, list) or not all(isinstance(command, str) and command for command in commands):
        errors.append("repo_audit_plan: operator_commands must be a non-empty string list")
        return

    command_count = require_exact_int(
        errors=errors,
        name="repo_audit_plan",
        payload=repo,
        key="operator_command_count",
    )
    if command_count >= 0 and command_count != len(commands):
        errors.append("repo_audit_plan: operator_command_count must match operator_commands length")
    if str(repo.get("operator_commands_sha256") or "") != sha256_json(commands):
        errors.append("repo_audit_plan: operator_commands_sha256 must match operator_commands")

    per_repo = repo.get("per_repo")
    if not isinstance(per_repo, list):
        errors.append("repo_audit_plan: per_repo must be a list")
        return
    if valid_repo_rows > 0 and len(per_repo) != valid_repo_rows:
        errors.append("repo_audit_plan: per_repo length must match valid_repo_rows")

    expected_commands: list[str] = []
    label_template_outs: list[str] = []
    seen_cases: set[str] = set()
    for row in per_repo:
        if not isinstance(row, dict):
            errors.append("repo_audit_plan: per_repo rows must be objects")
            return
        case_id = str(row.get("case_id") or "").strip()
        if not case_id:
            errors.append("repo_audit_plan: per_repo rows must include case_id")
            return
        if case_id in seen_cases:
            errors.append("repo_audit_plan: duplicate case_id in per_repo")
            return
        seen_cases.add(case_id)

        lock_row = snapshot_lock_rows.get(case_id)
        if snapshot_lock_rows and not lock_row:
            errors.append("repo_audit_plan: per_repo case_id set must match repo_snapshot_lock_rows")
            return
        if lock_row:
            if not same_path(str(row.get("repo_path") or ""), str(lock_row.get("repo_path_resolved") or "")):
                errors.append("repo_audit_plan: per_repo repo_path must match repo_snapshot_lock_rows")
                return
            for field in ["expected_repo_git_head", "actual_repo_git_head"]:
                if str(row.get(field) or "").strip().lower() != str(lock_row.get(field) or "").strip().lower():
                    errors.append(f"repo_audit_plan: per_repo {field} must match repo_snapshot_lock_rows")
                    return
            for field in ["owner_or_maintainer_contact_present", "real_benchmark_namespace_confirmed"]:
                if row.get(field) != lock_row.get(field):
                    errors.append(f"repo_audit_plan: per_repo {field} must match repo_snapshot_lock_rows")
                    return
            if str(row.get("audit_mode") or "").strip().lower() != str(lock_row.get("audit_mode") or "").strip().lower():
                errors.append("repo_audit_plan: per_repo audit_mode must match repo_snapshot_lock_rows")
                return

        repo_path = str(row.get("repo_path") or "").strip()
        audit_mode = str(row.get("audit_mode") or "").strip().lower()
        namespace = str(row.get("namespace") or "").strip()
        audit_out = str(row.get("audit_out") or "").strip()
        label_template_out = str(row.get("label_template_out") or "").strip()
        reviewer_packet_out = str(row.get("reviewer_packet_out") or "").strip()
        if namespace != "real_benchmark":
            errors.append("repo_audit_plan: per_repo namespace must be real_benchmark")
            return
        if audit_mode not in {"quick", "full"}:
            errors.append("repo_audit_plan: per_repo audit_mode must be quick or full")
            return
        for field, value in [
            ("repo_path", repo_path),
            ("audit_out", audit_out),
            ("label_template_out", label_template_out),
            ("reviewer_packet_out", reviewer_packet_out),
        ]:
            if not value:
                errors.append(f"repo_audit_plan: per_repo rows must include {field}")
                return
        expected_row_commands = {
            "audit_command": command_line(
                [
                    "./scripts/audit_my_repo.sh",
                    repo_path,
                    "--mode",
                    audit_mode,
                    "--namespace",
                    "real_benchmark",
                    "--confirm-real-benchmark-namespace",
                    "--out",
                    audit_out,
                ]
            ),
            "audit_verify_command": command_line(
                [
                    "./scripts/audit_my_repo.sh",
                    "--verify-existing",
                    audit_out,
                ]
            ),
            "label_template_command": command_line(
                [
                    "python3",
                    "scripts/audit_my_repo_label_template.py",
                    "--audit-output",
                    audit_out,
                    "--out",
                    label_template_out,
                    "--case-id",
                    case_id,
                ]
            ),
            "label_template_verify_command": command_line(
                [
                    "python3",
                    "scripts/audit_my_repo_label_template.py",
                    "--verify-existing",
                    label_template_out,
                ]
            ),
            "reviewer_packet_command": command_line(
                [
                    "python3",
                    "scripts/amr_beta_label_packet.py",
                    "--template-dir",
                    label_template_out,
                    "--out",
                    reviewer_packet_out,
                ]
            ),
        }
        for field in REPO_AUDIT_PLAN_COMMAND_FIELDS:
            command = row.get(field)
            if command != expected_row_commands[field]:
                errors.append(f"repo_audit_plan: per_repo {field} must match locked repo command")
                return
            expected_commands.append(expected_row_commands[field])
        label_template_outs.append(label_template_out)
    if snapshot_lock_rows and seen_cases != set(snapshot_lock_rows):
        errors.append("repo_audit_plan: per_repo case_id set must match repo_snapshot_lock_rows")

    artifact_root = str(repo.get("artifact_root") or "").strip()
    if not artifact_root:
        errors.append("repo_audit_plan: artifact_root must be present")
        return
    aggregate_parts: list[object] = ["python3", "scripts/amr_beta_label_packet.py"]
    for label_template_out in label_template_outs:
        aggregate_parts.extend(["--template-dir", label_template_out])
    aggregate_parts.extend(["--per-case-out-root", Path(artifact_root) / "reviewer_packets"])
    expected_aggregate_command = command_line(aggregate_parts)
    aggregate_command = repo.get("aggregate_reviewer_packet_command")
    if not isinstance(aggregate_command, str) or not aggregate_command:
        errors.append("repo_audit_plan: aggregate_reviewer_packet_command must be present")
    elif aggregate_command != expected_aggregate_command:
        errors.append("repo_audit_plan: aggregate_reviewer_packet_command must match locked repo commands")
    else:
        expected_commands.append(expected_aggregate_command)
    if commands != expected_commands:
        errors.append("repo_audit_plan: operator_commands must exactly match per_repo commands plus aggregate reviewer packet command")


def require_label_operator_commands(
    *,
    errors: list[str],
    label: dict,
    case_count: int,
) -> None:
    commands = label.get("operator_commands")
    if not isinstance(commands, list) or not all(isinstance(command, str) and command for command in commands):
        errors.append("label_intake_plan: operator_commands must be a non-empty string list")
        return

    command_count = require_exact_int(
        errors=errors,
        name="label_intake_plan",
        payload=label,
        key="operator_command_count",
    )
    if command_count >= 0 and command_count != len(commands):
        errors.append("label_intake_plan: operator_command_count must match operator_commands length")
    if str(label.get("operator_commands_sha256") or "") != sha256_json(commands):
        errors.append("label_intake_plan: operator_commands_sha256 must match operator_commands")

    per_case = label.get("per_case")
    if not isinstance(per_case, list):
        errors.append("label_intake_plan: per_case must be a list")
        return
    if case_count > 0 and len(per_case) != case_count:
        errors.append("label_intake_plan: per_case length must match case_count")

    expected_commands: list[str] = []
    for row in per_case:
        if not isinstance(row, dict):
            errors.append("label_intake_plan: per_case rows must be objects")
            return
        for field in LABEL_INTAKE_PLAN_COMMAND_FIELDS:
            command = row.get(field)
            if not isinstance(command, str) or not command:
                errors.append(f"label_intake_plan: per_case rows must include {field}")
                return
            expected_commands.append(command)
    if commands != expected_commands:
        errors.append("label_intake_plan: operator_commands must exactly match per_case compile/verify commands")


def require_label_template_fingerprints(*, errors: list[str], label: dict, case_count: int) -> None:
    template_dir_count = require_exact_int(
        errors=errors,
        name="label_intake_plan",
        payload=label,
        key="template_dir_count",
    )
    if template_dir_count >= 0 and template_dir_count != case_count:
        errors.append("label_intake_plan: template_dir_count must match case_count")

    fingerprints = label.get("label_template_fingerprints")
    if not isinstance(fingerprints, list):
        errors.append("label_intake_plan: label_template_fingerprints must be a list")
        return
    if case_count > 0 and len(fingerprints) != case_count:
        errors.append("label_intake_plan: label_template_fingerprints length must match case_count")

    json_sha256s: list[str] = []
    manifest_sha256s: list[str] = []
    for row in fingerprints:
        if not isinstance(row, dict):
            errors.append("label_intake_plan: label_template_fingerprints rows must be objects")
            return
        json_sha = str(row.get("label_template_json_sha256") or "")
        manifest_sha = str(row.get("label_template_manifest_sha256") or "")
        if not SHA256_RE.fullmatch(json_sha):
            errors.append("label_intake_plan: label_template_fingerprints JSON hashes must be sha256 bindings")
            return
        json_sha256s.append(json_sha)
        if manifest_sha:
            if not SHA256_RE.fullmatch(manifest_sha):
                errors.append("label_intake_plan: label_template_fingerprints manifest hashes must be sha256 bindings")
                return
            manifest_sha256s.append(manifest_sha)

    if label.get("label_template_json_sha256s") != json_sha256s:
        errors.append("label_intake_plan: label_template_json_sha256s must match label_template_fingerprints")
    if label.get("label_template_manifest_sha256s") != manifest_sha256s:
        errors.append("label_intake_plan: label_template_manifest_sha256s must match label_template_fingerprints")
    if str(label.get("label_template_bundle_sha256") or "") != sha256_json(fingerprints):
        errors.append("label_intake_plan: label_template_bundle_sha256 must match label_template_fingerprints")

    require_flag(
        errors=errors,
        name="label_intake_plan",
        payload=label,
        key="label_template_verify_existing_required",
        expected=1,
    )
    passed_dirs = require_exact_int(
        errors=errors,
        name="label_intake_plan",
        payload=label,
        key="label_template_verify_existing_passed_dirs",
    )
    failed_dirs = require_exact_int(
        errors=errors,
        name="label_intake_plan",
        payload=label,
        key="label_template_verify_existing_failed_dirs",
    )
    if passed_dirs >= 0 and passed_dirs != case_count:
        errors.append("label_intake_plan: label_template_verify_existing_passed_dirs must match case_count")
    if failed_dirs >= 0 and failed_dirs != 0:
        errors.append("label_intake_plan: label_template_verify_existing_failed_dirs must be 0")


def case_id_set(*, errors: list[str], name: str, payload: dict, row_field: str) -> set[str]:
    rows = payload.get(row_field)
    if not isinstance(rows, list):
        errors.append(f"{name}: {row_field} must be a list")
        return set()
    seen: set[str] = set()
    for row in rows:
        if not isinstance(row, dict):
            errors.append(f"{name}: {row_field} rows must be objects")
            return set()
        case_id = str(row.get("case_id") or "").strip()
        if not case_id:
            errors.append(f"{name}: {row_field} rows must include case_id")
            return set()
        if case_id in seen:
            errors.append(f"{name}: duplicate case_id in {row_field}")
            return set()
        seen.add(case_id)
    return seen


def preflight_count(preflight: dict, key: str, errors: list[str]) -> int:
    try:
        return int(preflight.get(key, -1))
    except (TypeError, ValueError):
        errors.append(f"runtime_preflight: {key} must be an integer")
        return -1


def runtime_fingerprint_bundle_errors(preflight: dict) -> list[str]:
    errors: list[str] = []
    template_fingerprints = preflight.get("label_template_fingerprints")
    if not isinstance(template_fingerprints, list):
        errors.append("runtime_preflight: label_template_fingerprints must be a list")
        template_fingerprints = []
    if len(template_fingerprints) != preflight_count(preflight, "template_dir_count", errors):
        errors.append("runtime_preflight: label_template_fingerprints length must equal template_dir_count")
    template_json_sha256s = [
        str(row.get("label_template_json_sha256") or "")
        for row in template_fingerprints
        if isinstance(row, dict)
    ]
    template_manifest_sha256s = [
        str(row.get("label_template_manifest_sha256") or "")
        for row in template_fingerprints
        if isinstance(row, dict) and str(row.get("label_template_manifest_sha256") or "")
    ]
    if preflight.get("label_template_json_sha256s") != template_json_sha256s:
        errors.append("runtime_preflight: label_template_json_sha256s must match label_template_fingerprints")
    if preflight.get("label_template_manifest_sha256s") != template_manifest_sha256s:
        errors.append("runtime_preflight: label_template_manifest_sha256s must match label_template_fingerprints")
    if str(preflight.get("label_template_bundle_sha256") or "") != sha256_json(template_fingerprints):
        errors.append("runtime_preflight: label_template_bundle_sha256 does not match label_template_fingerprints")

    label_intake_fingerprints = preflight.get("label_intake_fingerprints")
    if not isinstance(label_intake_fingerprints, list):
        errors.append("runtime_preflight: label_intake_fingerprints must be a list")
        label_intake_fingerprints = []
    if len(label_intake_fingerprints) != preflight_count(preflight, "label_intake_dir_count", errors):
        errors.append("runtime_preflight: label_intake_fingerprints length must equal label_intake_dir_count")
    label_intake_manifest_sha256s = [
        str(row.get("label_intake_manifest_sha256") or "")
        for row in label_intake_fingerprints
        if isinstance(row, dict)
    ]
    if preflight.get("label_intake_manifest_sha256s") != label_intake_manifest_sha256s:
        errors.append("runtime_preflight: label_intake_manifest_sha256s must match label_intake_fingerprints")
    if str(preflight.get("label_intake_bundle_sha256") or "") != sha256_json(label_intake_fingerprints):
        errors.append("runtime_preflight: label_intake_bundle_sha256 does not match label_intake_fingerprints")

    input_bundle = {
        "repo_intake_sha256": str(preflight.get("repo_intake_sha256") or ""),
        "repo_snapshot_lock_sha256": str(preflight.get("repo_snapshot_lock_sha256") or ""),
        "decisions_sha256": str(preflight.get("decisions_sha256") or ""),
        "feedback_sha256": str(preflight.get("feedback_sha256") or ""),
        "feedback_bundle_sha256": str(preflight.get("feedback_bundle_sha256") or ""),
        "label_template_bundle_sha256": str(preflight.get("label_template_bundle_sha256") or ""),
        "label_intake_bundle_sha256": str(preflight.get("label_intake_bundle_sha256") or ""),
    }
    if str(preflight.get("preflight_input_bundle_sha256") or "") != sha256_json(input_bundle):
        errors.append("runtime_preflight: preflight_input_bundle_sha256 does not match input fingerprints")
    return errors


def runtime_fingerprint_errors(artifacts: dict[str, dict | None]) -> list[str]:
    errors: list[str] = []
    preflight = artifacts.get("runtime_preflight")
    request = artifacts.get("runtime_approval_request")
    status = artifacts.get("runtime_approval_status")
    if not preflight:
        return errors

    for key in PREFLIGHT_SHA_BINDING_KEYS:
        require_sha_field(errors=errors, name="runtime_preflight", payload=preflight, field=key)
    for key in PREFLIGHT_LIST_BINDING_KEYS:
        require_sha_list_field(errors=errors, name="runtime_preflight", payload=preflight, field=key)
    errors.extend(runtime_fingerprint_bundle_errors(preflight))

    for name, payload in [
        ("runtime_approval_request", request),
        ("runtime_approval_status", status),
    ]:
        if not payload:
            continue
        for key in PREFLIGHT_SHA_BINDING_KEYS:
            require_matching_field(
                errors=errors,
                name=name,
                payload=payload,
                field=key,
                expected=preflight.get(key),
            )
        for key in PREFLIGHT_LIST_BINDING_KEYS:
            require_matching_field(
                errors=errors,
                name=name,
                payload=payload,
                field=key,
                expected=preflight.get(key),
            )
    return errors


def artifact_chain_errors(artifacts: dict[str, dict | None], metas: dict[str, dict]) -> list[str]:
    errors: list[str] = []
    repo = artifacts.get("repo_audit_plan")
    label = artifacts.get("label_intake_plan")
    feedback = artifacts.get("maintainer_feedback_packet")
    preflight = artifacts.get("runtime_preflight")
    request = artifacts.get("runtime_approval_request")
    status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")

    if repo:
        require_flag(
            errors=errors,
            name="repo_audit_plan",
            payload=repo,
            key="ready_for_real_benchmark_audit_plan",
            expected=1,
        )
        min_repos = require_int_at_least(
            errors=errors,
            name="repo_audit_plan",
            payload=repo,
            key="min_real_repos_required",
            minimum=10,
        )
        valid_repo_rows = require_int_at_least(
            errors=errors,
            name="repo_audit_plan",
            payload=repo,
            key="valid_repo_rows",
            minimum=max(10, min_repos),
        )
        require_sha_field(errors=errors, name="repo_audit_plan", payload=repo, field="repo_intake_sha256")
        require_sha_field(errors=errors, name="repo_audit_plan", payload=repo, field="repo_snapshot_lock_sha256")
        require_sha_field(errors=errors, name="repo_audit_plan", payload=repo, field="operator_commands_sha256")
        snapshot_lock_rows = require_repo_snapshot_lock_rows(
            errors=errors,
            repo=repo,
            valid_repo_rows=valid_repo_rows,
        )
        require_repo_operator_commands(
            errors=errors,
            repo=repo,
            valid_repo_rows=valid_repo_rows,
            snapshot_lock_rows=snapshot_lock_rows,
        )
        for key in REPO_AUDIT_PLAN_READ_ONLY_FLAGS:
            require_flag(errors=errors, name="repo_audit_plan", payload=repo, key=key, expected=0)
        require_flag(errors=errors, name="repo_audit_plan", payload=repo, key="input_path_guard_passed", expected=1)
        require_flag(errors=errors, name="repo_audit_plan", payload=repo, key="output_path_guard_passed", expected=1)

    if label:
        require_flag(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="ready_for_label_intake_plan",
            expected=1,
        )
        label_min_repos = require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="min_real_repos_required",
            minimum=10,
        )
        label_min_labels = require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="min_human_label_rows_required",
            minimum=300,
        )
        valid_human_label_rows = require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="valid_human_label_rows",
            minimum=max(300, label_min_labels),
        )
        non_synthetic_valid_human_label_rows = require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="non_synthetic_valid_human_label_rows",
            minimum=max(300, label_min_labels),
        )
        require_flag(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="human_label_requirement_met",
            expected=1,
        )
        human_labels_remaining = require_exact_int(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="human_labels_remaining_to_minimum",
        )
        if human_labels_remaining != 0:
            errors.append("label_intake_plan: human_labels_remaining_to_minimum must be 0")
        case_count = require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="case_count",
            minimum=max(10, label_min_repos),
        )
        require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="candidate_label_rows",
            minimum=valid_human_label_rows,
        )
        require_int_at_least(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="decision_rows",
            minimum=valid_human_label_rows,
        )
        candidate_label_rows = require_exact_int(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="candidate_label_rows",
        )
        synthetic_candidate_rows = require_exact_int(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="synthetic_candidate_rows",
        )
        non_synthetic_candidate_rows = require_exact_int(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="non_synthetic_candidate_rows",
        )
        if synthetic_candidate_rows != 0:
            errors.append("label_intake_plan: synthetic_candidate_rows must be 0")
        if (
            candidate_label_rows >= 0
            and synthetic_candidate_rows >= 0
            and non_synthetic_candidate_rows >= 0
            and candidate_label_rows != non_synthetic_candidate_rows + synthetic_candidate_rows
        ):
            errors.append(
                "label_intake_plan: candidate_label_rows must equal "
                "non_synthetic_candidate_rows + synthetic_candidate_rows"
            )
        decision_rows = require_exact_int(
            errors=errors,
            name="label_intake_plan",
            payload=label,
            key="decision_rows",
        )
        if (
            candidate_label_rows >= 0
            and decision_rows >= 0
            and not (
                candidate_label_rows
                == decision_rows
                == valid_human_label_rows
                == non_synthetic_valid_human_label_rows
            )
        ):
            errors.append(
                "label_intake_plan: candidate_label_rows, decision_rows, "
                "valid_human_label_rows, and non_synthetic_valid_human_label_rows must match"
            )
        for field in [
            "repo_intake_sha256",
            "repo_snapshot_lock_sha256",
            "decisions_sha256",
            "label_template_bundle_sha256",
            "operator_commands_sha256",
        ]:
            require_sha_field(errors=errors, name="label_intake_plan", payload=label, field=field)
        for field in ["label_template_json_sha256s", "label_template_manifest_sha256s"]:
            require_sha_list_field(errors=errors, name="label_intake_plan", payload=label, field=field)
        for key in LABEL_INTAKE_PLAN_READ_ONLY_FLAGS:
            require_flag(errors=errors, name="label_intake_plan", payload=label, key=key, expected=0)
        require_flag(errors=errors, name="label_intake_plan", payload=label, key="decision_input_guard_passed", expected=1)
        require_flag(errors=errors, name="label_intake_plan", payload=label, key="output_path_guard_passed", expected=1)
        require_label_template_fingerprints(errors=errors, label=label, case_count=case_count)
        require_label_operator_commands(errors=errors, label=label, case_count=case_count)

    if feedback:
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="ready_for_runtime_preflight_feedback",
            expected=1,
        )
        feedback_min_repos = require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="min_real_repos_required",
            minimum=10,
        )
        feedback_min_maintainers = require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="min_maintainer_feedback_required",
            minimum=3,
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="valid_repo_rows",
            minimum=max(10, feedback_min_repos),
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="request_case_rows",
            minimum=max(10, feedback_min_repos),
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="valid_feedback_rows",
            minimum=feedback_min_maintainers,
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="distinct_countable_maintainer_id_count",
            minimum=feedback_min_maintainers,
        )
        label_intake_dir_count = require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_dir_count",
            minimum=1,
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_label_rows",
            minimum=300,
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_case_count",
            minimum=max(10, feedback_min_repos),
        )
        require_int_at_least(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_countable_case_count",
            minimum=max(10, feedback_min_repos),
        )
        require_sha_field(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            field="repo_snapshot_lock_sha256",
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="maintainer_feedback_requirement_met",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="feedback_counts_for_beta_precheck",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_verify_existing_required",
            expected=1,
        )
        label_verify_passed = require_exact_int(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_verify_existing_passed_dirs",
        )
        label_verify_failed = require_exact_int(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_verify_existing_failed_dirs",
        )
        if label_verify_passed >= 0 and label_verify_passed != label_intake_dir_count:
            errors.append(
                "maintainer_feedback_packet: label_intake_verify_existing_passed_dirs must match label_intake_dir_count"
            )
        if label_verify_failed >= 0 and label_verify_failed != 0:
            errors.append("maintainer_feedback_packet: label_intake_verify_existing_failed_dirs must be 0")
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="label_intake_synthetic_case_count",
            expected=0,
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="raw_feedback_text_emitted",
            expected=0,
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="creates_benchmark_evidence",
            expected=0,
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="input_path_guard_passed",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            key="output_path_guard_passed",
            expected=1,
            )

    if repo and label:
        repo_case_ids = case_id_set(errors=errors, name="repo_audit_plan", payload=repo, row_field="per_repo")
        label_case_ids = case_id_set(errors=errors, name="label_intake_plan", payload=label, row_field="per_case")
        if repo_case_ids and label_case_ids and repo_case_ids != label_case_ids:
            errors.append("label_intake_plan: per_case case_id set must match repo_audit_plan")
        for key in ["repo_intake_sha256", "repo_snapshot_lock_sha256"]:
            require_matching_artifact_field(
                errors=errors,
                name="label_intake_plan",
                payload=label,
                field=key,
                expected=repo.get(key),
                expected_name="repo_audit_plan",
            )

    if label and preflight:
        for key in [
            "decisions_sha256",
            "label_template_bundle_sha256",
            "label_template_json_sha256s",
            "label_template_manifest_sha256s",
        ]:
            require_matching_artifact_field(
                errors=errors,
                name="runtime_preflight",
                payload=preflight,
                field=key,
                expected=label.get(key),
                expected_name="label_intake_plan",
            )

    if repo and feedback:
        require_matching_artifact_field(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            field="repo_snapshot_lock_sha256",
            expected=repo.get("repo_snapshot_lock_sha256"),
            expected_name="repo_audit_plan",
        )

    if label and feedback:
        require_matching_artifact_field(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            field="repo_snapshot_lock_sha256",
            expected=label.get("repo_snapshot_lock_sha256"),
            expected_name="label_intake_plan",
        )

    if repo and preflight:
        for key in ["repo_intake_sha256", "repo_snapshot_lock_sha256"]:
            require_matching_artifact_field(
                errors=errors,
                name="runtime_preflight",
                payload=preflight,
                field=key,
                expected=repo.get(key),
                expected_name="repo_audit_plan",
            )

    if request and not preflight:
        errors.append("runtime_approval_request: runtime_preflight is required")
    if status and not request:
        errors.append("runtime_approval_status: runtime_approval_request is required")
    if status and not preflight:
        errors.append("runtime_approval_status: runtime_preflight is required")
    if benchmark and not status:
        errors.append("benchmark_readiness: runtime_approval_status is required")

    if preflight:
        for key in PREFLIGHT_PATH_GUARD_KEYS:
            require_flag(errors=errors, name="runtime_preflight", payload=preflight, key=key, expected=1)

    if preflight and request:
        preflight_meta = metas["runtime_preflight"]
        require_bound_path(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            field="input_preflight",
            expected_path=str(preflight_meta["path"]),
        )
        require_bound_sha(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            field="input_preflight_sha256",
            expected_sha=str(preflight_meta["sha256"]),
        )
        require_flag(errors=errors, name="runtime_approval_request", payload=request, key="approved_by_human", expected=0)
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="approval_record_supplied",
            expected=0,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="requires_human_runtime_approval",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="benchmark_runtime_approval_required",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="creates_benchmark_evidence",
            expected=0,
        )
        require_flag(errors=errors, name="runtime_approval_request", payload=request, key="runs_benchmark", expected=0)
        for key in PREFLIGHT_PATH_GUARD_KEYS:
            require_matching_field(
                errors=errors,
                name="runtime_approval_request",
                payload=request,
                field=key,
                expected=preflight.get(key),
            )
            require_flag(errors=errors, name="runtime_approval_request", payload=request, key=key, expected=1)
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="output_path_guard_passed",
            expected=1,
        )

    if preflight and request and status:
        preflight_meta = metas["runtime_preflight"]
        request_meta = metas["runtime_approval_request"]
        require_bound_path(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="input_preflight",
            expected_path=str(preflight_meta["path"]),
        )
        require_bound_sha(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="input_preflight_sha256",
            expected_sha=str(preflight_meta["sha256"]),
        )
        require_bound_path(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="approval_request",
            expected_path=str(request_meta["path"]),
        )
        require_bound_sha(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="approval_request_sha256",
            expected_sha=str(request_meta["sha256"]),
        )
        require_flag(errors=errors, name="runtime_approval_status", payload=status, key="approved_by_human", expected=1)
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="approval_record_supplied",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="human_runtime_approval_record_verified",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="ready_for_human_operator_benchmark_run",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="benchmark_runtime_approval_required",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="creates_benchmark_evidence",
            expected=0,
        )
        require_flag(errors=errors, name="runtime_approval_status", payload=status, key="runs_benchmark", expected=0)
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="codex_runtime_permission_granted_by_this_packet",
            expected=0,
        )
        for key in PREFLIGHT_PATH_GUARD_KEYS:
            require_matching_field(
                errors=errors,
                name="runtime_approval_status",
                payload=status,
                field=key,
                expected=preflight.get(key),
            )
            require_flag(errors=errors, name="runtime_approval_status", payload=status, key=key, expected=1)
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="approval_request_output_path_guard_passed",
            expected=1,
        )
        if str(status.get("approval_scope") or "") != APPROVAL_SCOPE:
            errors.append(f"runtime_approval_status: approval_scope must be {APPROVAL_SCOPE}")
        if not str(status.get("approval_record") or "").strip():
            errors.append("runtime_approval_status: approval_record is required")
        require_sha_field(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="approval_record_sha256",
        )

    if benchmark and status:
        benchmark_meta = metas["benchmark_readiness"]
        benchmark_out = str(status.get("benchmark_out") or "")
        if not benchmark_out:
            errors.append("runtime_approval_status: benchmark_out is required")
        else:
            expected_readiness = str(Path(benchmark_out).expanduser().resolve() / "benchmark_readiness.json")
            if not same_path(str(benchmark_meta["path"]), expected_readiness):
                errors.append(
                    "benchmark_readiness: path must match "
                    "runtime_approval_status benchmark_out/benchmark_readiness.json"
                )

    errors.extend(runtime_fingerprint_errors(artifacts))
    return errors


def compute_stage(artifacts: dict[str, dict | None], errors: list[str]) -> tuple[str, list[str]]:
    if errors:
        return "stage_0_claim_freeze", ["Resolve artifact validation errors before advancing."]
    repo = artifacts.get("repo_audit_plan")
    label = artifacts.get("label_intake_plan")
    feedback = artifacts.get("maintainer_feedback_packet")
    preflight = artifacts.get("runtime_preflight")
    approval_request = artifacts.get("runtime_approval_request")
    approval_status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")

    if not repo or truthy_int(repo, "ready_for_real_benchmark_audit_plan") != 1:
        return "stage_0_claim_freeze", ["Generate a clean repo audit plan from >=10 validated real repos."]
    if not label or truthy_int(label, "ready_for_label_intake_plan") != 1:
        return "stage_1_repo_intake_plan_ready", [
            "Run/verify repo audits and label templates, then generate a label-intake plan from human decisions."
        ]
    if not feedback or truthy_int(feedback, "ready_for_runtime_preflight_feedback") != 1:
        return "stage_2_label_intake_plan_ready", [
            "Collect >=3 countable maintainer feedback rows bound to human-labeled non-synthetic cases."
        ]
    if not preflight or truthy_int(preflight, "ready_to_request_runtime_approval") != 1:
        return "stage_3_maintainer_feedback_ready", [
            "Compile/verify label intake outputs and run the final runtime preflight."
        ]
    if not approval_request or truthy_int(approval_request, "requires_human_runtime_approval") != 1:
        return "stage_4_runtime_preflight_ready", [
            "Generate a runtime approval request from the green preflight."
        ]
    if not approval_status or truthy_int(approval_status, "human_runtime_approval_record_verified") != 1:
        return "stage_4_runtime_preflight_ready", [
            "Get and validate a human runtime approval record before the long benchmark."
        ]
    if not benchmark:
        return "stage_4_runtime_approval_verified", [
            "Human/operator may run the approved real_benchmark command and verify benchmark_readiness.json."
        ]
    if truthy_int(benchmark, "design_partner_beta_candidate_ready") == 1:
        return "stage_5_beta_candidate_or_hardening", [
            "Package design-partner beta materials while keeping release/public/model claims blocked."
        ]
    return "stage_4_real_benchmark_verified", [
        "Generate remediation backlog and hardening analysis for blocked benchmark readiness gates."
    ]


def count_int(payload: dict | None, key: str, default: int = 0) -> int:
    if not payload:
        return default
    raw = payload.get(key, default)
    if isinstance(raw, bool):
        return int(raw)
    if isinstance(raw, int):
        return raw
    try:
        return int(raw)
    except (TypeError, ValueError):
        return default


def progress_summary(current: int, required: int) -> dict[str, int | float]:
    remaining = max(0, required - current)
    percent = 0.0 if required <= 0 else round(min(current, required) * 100.0 / required, 2)
    return {
        "current": current,
        "required": required,
        "remaining": remaining,
        "met": int(required > 0 and current >= required),
        "progress_percent": percent,
    }


def build_stage_progress(artifacts: dict[str, dict | None], *, benchmark_ready: int) -> dict[str, object]:
    repo = artifacts.get("repo_audit_plan")
    label = artifacts.get("label_intake_plan")
    feedback = artifacts.get("maintainer_feedback_packet")
    preflight = artifacts.get("runtime_preflight")
    request = artifacts.get("runtime_approval_request")
    status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")
    backlog = artifacts.get("readiness_backlog")

    repo_required = max(
        10,
        count_int(repo, "min_real_repos_required", 10),
        count_int(label, "min_real_repos_required", 10),
        count_int(feedback, "min_real_repos_required", 10),
    )
    repo_current = max(
        count_int(repo, "valid_repo_rows"),
        count_int(label, "case_count"),
        count_int(feedback, "valid_repo_rows"),
    )

    label_required = max(
        300,
        count_int(label, "min_human_label_rows_required", 300),
    )
    label_current = max(
        count_int(label, "valid_human_label_rows"),
        count_int(feedback, "label_intake_label_rows"),
    )

    maintainer_required = max(
        3,
        count_int(feedback, "min_maintainer_feedback_required", 3),
    )
    maintainer_current = max(
        count_int(feedback, "distinct_countable_maintainer_id_count"),
        count_int(feedback, "distinct_maintainer_id_count"),
    )

    blocked_gate_rows = count_int(benchmark, "blocked_gate_rows", count_int(backlog, "blocked_gate_rows"))
    passed_gate_rows = count_int(benchmark, "passed_gate_rows", 0)
    gate_rows = count_int(benchmark, "gate_rows", count_int(backlog, "gate_rows"))

    return {
        "repo_intake": progress_summary(repo_current, repo_required),
        "human_labels": progress_summary(label_current, label_required),
        "maintainer_feedback": progress_summary(maintainer_current, maintainer_required),
        "runtime_preflight": {
            "ready_to_request_runtime_approval": count_int(preflight, "ready_to_request_runtime_approval"),
            "input_path_preflight_passed": count_int(preflight, "input_path_preflight_passed"),
            "output_path_preflight_passed": count_int(preflight, "output_path_preflight_passed"),
        },
        "runtime_approval": {
            "approval_request_supplied": int(bool(request)),
            "approval_record_verified": count_int(status, "human_runtime_approval_record_verified"),
            "ready_for_human_operator_benchmark_run": count_int(
                status,
                "ready_for_human_operator_benchmark_run",
            ),
        },
        "benchmark": {
            "benchmark_readiness_supplied": int(bool(benchmark)),
            "gate_rows": gate_rows,
            "passed_gate_rows": passed_gate_rows,
            "blocked_gate_rows": blocked_gate_rows,
            "readiness_backlog_supplied": int(bool(backlog)),
            "readiness_backlog_items": count_int(backlog, "backlog_items"),
            "design_partner_beta_candidate_ready": benchmark_ready,
        },
    }


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like Markdown output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Operator Status",
        "",
        f"- current_stage: {payload['current_stage']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- runs_benchmark: {payload['runs_benchmark']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Stage Progress",
        "",
        "- repo_intake: {current}/{required} "
        "(remaining {remaining}, met {met}, {progress_percent}%)".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- human_labels: {current}/{required} "
        "(remaining {remaining}, met {met}, {progress_percent}%)".format(
            **payload["stage_progress"]["human_labels"],
        ),
        "- maintainer_feedback: {current}/{required} "
        "(remaining {remaining}, met {met}, {progress_percent}%)".format(
            **payload["stage_progress"]["maintainer_feedback"],
        ),
        "- runtime_preflight_ready: "
        f"{payload['stage_progress']['runtime_preflight']['ready_to_request_runtime_approval']}",
        "- runtime_approval_verified: "
        f"{payload['stage_progress']['runtime_approval']['approval_record_verified']}",
        "- benchmark_readiness_supplied: "
        f"{payload['stage_progress']['benchmark']['benchmark_readiness_supplied']}",
        "- benchmark_blocked_gate_rows: "
        f"{payload['stage_progress']['benchmark']['blocked_gate_rows']}",
        "",
        "## Next Blockers",
        "",
    ]
    lines.extend(f"- {blocker}" for blocker in payload["next_blockers"])
    lines.extend(["", "## Artifacts", ""])
    for name, meta in payload["artifacts"].items():
        lines.append(f"- {name}: {meta['path']} ({meta['schema']})")
    if payload.get("runtime_fingerprints"):
        lines.extend(["", "## Runtime Fingerprints", ""])
        for key, value in payload["runtime_fingerprints"].items():
            if isinstance(value, list):
                rendered = json.dumps(value, sort_keys=True)
            else:
                rendered = str(value)
            lines.append(f"- {key}: {rendered}")
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-audit-plan", default="")
    parser.add_argument("--label-intake-plan", default="")
    parser.add_argument("--maintainer-feedback-packet", default="")
    parser.add_argument("--runtime-preflight", default="")
    parser.add_argument("--runtime-approval-request", default="")
    parser.add_argument("--runtime-approval-status", default="")
    parser.add_argument("--benchmark-readiness", default="")
    parser.add_argument("--readiness-backlog", default="")
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-md", default="")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    artifact_args = {
        "repo_audit_plan": args.repo_audit_plan,
        "label_intake_plan": args.label_intake_plan,
        "maintainer_feedback_packet": args.maintainer_feedback_packet,
        "runtime_preflight": args.runtime_preflight,
        "runtime_approval_request": args.runtime_approval_request,
        "runtime_approval_status": args.runtime_approval_status,
        "readiness_backlog": args.readiness_backlog,
    }
    try:
        artifacts: dict[str, dict | None] = {}
        artifact_meta: dict[str, dict] = {}
        errors: list[str] = []
        for name, path_text in artifact_args.items():
            payload, meta, artifact_errors = load_optional(path_text, name)
            artifacts[name] = payload
            if meta:
                artifact_meta[name] = meta
            errors.extend(artifact_errors)
        benchmark, benchmark_meta, benchmark_errors = load_benchmark_readiness(args.benchmark_readiness)
        artifacts["benchmark_readiness"] = benchmark
        if benchmark_meta:
            artifact_meta["benchmark_readiness"] = benchmark_meta
        errors.extend(benchmark_errors)
        errors.extend(artifact_chain_errors(artifacts, artifact_meta))

        current_stage, next_blockers = compute_stage(artifacts, errors)
        benchmark_ready = int(
            current_stage == "stage_5_beta_candidate_or_hardening"
            and truthy_int(benchmark or {}, "design_partner_beta_candidate_ready") == 1
        )
        stage_progress = build_stage_progress(artifacts, benchmark_ready=benchmark_ready)
        preflight = artifacts.get("runtime_preflight") or {}
        runtime_fingerprints = {
            key: str(preflight.get(key) or "")
            for key in PREFLIGHT_SHA_BINDING_KEYS
            if preflight.get(key)
        }
        runtime_fingerprints.update(
            {
                key: list(preflight.get(key, []))
                for key in PREFLIGHT_LIST_BINDING_KEYS
                if preflight.get(key)
            }
        )
        runtime_fingerprints.update(
            {
                key: int(preflight.get(key, 0))
                for key in PREFLIGHT_PATH_GUARD_KEYS
                if key in preflight
            }
        )
        payload = {
            "schema": SCHEMA,
            "current_stage": current_stage,
            "stage_order": STAGE_ORDER,
            "stage_progress": stage_progress,
            "next_blockers": next_blockers,
            "artifacts": artifact_meta,
            "artifact_count": len(artifact_meta),
            "runtime_fingerprints": runtime_fingerprints,
            "creates_benchmark_evidence": 0,
            "runs_benchmark": 0,
            "design_partner_beta_candidate_ready": benchmark_ready,
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "errors": errors,
        }
        if errors:
            if args.json:
                print(json.dumps(payload, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        write_json(Path(args.out_json).expanduser().resolve(), payload, args.overwrite)
        if args.out_md:
            write_markdown(Path(args.out_md).expanduser().resolve(), payload, args.overwrite)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        else:
            print(f"operator_status: ok current_stage={current_stage}")
        return 0
    except Exception as exc:
        print(f"operator_status: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
