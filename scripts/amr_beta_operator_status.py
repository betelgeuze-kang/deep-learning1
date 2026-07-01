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
    "pr_cleanup_export_plan": "amr_beta_pr_cleanup_export_plan.v1",
    "pr_cleanup_status": "amr_beta_pr_cleanup_status.v1",
    "repo_discovery_status": "amr_beta_repo_intake_discover.v1",
    "repo_discovery_response": "amr_beta_repo_discovery_response.v1",
    "repo_intake_status": "amr_beta_repo_intake_validate.v1",
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
PR_CLEANUP_EXPORT_PLAN_READ_ONLY_FLAGS = [
    "runs_github_query",
    "runs_github_mutation",
    "runs_git_push",
    "closes_pull_requests",
    "merges_pull_requests",
    "creates_benchmark_evidence",
]
PR_CLEANUP_EXPORT_PLAN_FORBIDDEN_SCRIPT_SNIPPETS = [
    "gh pr close",
    "gh pr merge",
    "gh pr create",
    "git push",
    "git merge",
    "git reset",
]
REPO_INTAKE_STATUS_READ_ONLY_FLAGS = [
    "runs_audit",
    "runs_label_template_generation",
    "writes_reviewer_packets",
    "creates_benchmark_evidence",
]
REPO_DISCOVERY_STATUS_READ_ONLY_FLAGS = [
    "runs_audit",
    "runs_label_template_generation",
    "writes_reviewer_packets",
    "creates_benchmark_evidence",
    "repo_intake_rows_counted",
    "ready_for_repo_intake",
]
REPO_DISCOVERY_RESPONSE_READ_ONLY_FLAGS = [
    "runs_audit",
    "runs_label_template_generation",
    "writes_reviewer_packets",
    "creates_benchmark_evidence",
    "repo_intake_rows_counted",
    "ready_for_repo_intake",
    "writes_repo_intake_sheet",
]
REPO_AUDIT_PLAN_COMMAND_FIELDS = [
    "audit_command",
    "audit_verify_command",
    "label_template_command",
    "label_template_verify_command",
    "reviewer_packet_command",
]
REPO_AUDIT_PLAN_COMMAND_SCRIPT_FIELDS = [
    "writes_operator_command_script",
    "operator_commands_script",
    "operator_commands_script_sha256",
    "operator_commands_script_command_count",
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
LABEL_INTAKE_PLAN_COMMAND_SCRIPT_FIELDS = [
    "writes_operator_command_script",
    "operator_commands_script",
    "operator_commands_script_sha256",
    "operator_commands_script_command_count",
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


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def same_path(left: str, right: str) -> bool:
    if not left or not right:
        return False
    return str(Path(left).expanduser().resolve()) == str(Path(right).expanduser().resolve())


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


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
    if raw_errors and name != "repo_intake_status":
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


def require_pr_cleanup_export_plan(*, errors: list[str], payload: dict) -> None:
    require_flag(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="ready_for_pr_cleanup_export_handoff",
        expected=1,
    )
    require_flag(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="writes_export_script",
        expected=1,
    )
    require_flag(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="generated_script_runs_github_query",
        expected=1,
    )
    require_flag(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="generated_script_runs_github_mutation",
        expected=0,
    )
    for key in PR_CLEANUP_EXPORT_PLAN_READ_ONLY_FLAGS:
        require_flag(errors=errors, name="pr_cleanup_export_plan", payload=payload, key=key, expected=0)

    checklist_pr = require_exact_int(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="checklist_pr",
    )
    if checklist_pr != 46:
        errors.append("pr_cleanup_export_plan: checklist_pr must be 46")
    stale_prs = payload.get("stale_prs")
    if not isinstance(stale_prs, list) or sorted(stale_prs) != [5, 10, 39, 40]:
        errors.append("pr_cleanup_export_plan: stale_prs must be [39, 40, 10, 5]")
    export_pr_count = require_exact_int(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="export_pr_count",
    )
    if export_pr_count >= 0 and isinstance(stale_prs, list) and export_pr_count != 1 + len(stale_prs):
        errors.append("pr_cleanup_export_plan: export_pr_count must match checklist plus stale PR count")

    claim_files = payload.get("claim_files")
    if not isinstance(claim_files, list) or not claim_files:
        errors.append("pr_cleanup_export_plan: claim_files must be a non-empty list")
        claim_files = []
    claim_file_count = require_exact_int(
        errors=errors,
        name="pr_cleanup_export_plan",
        payload=payload,
        key="claim_file_count",
    )
    if claim_file_count >= 0 and claim_file_count != len(claim_files):
        errors.append("pr_cleanup_export_plan: claim_file_count must match claim_files length")
    seen_claims: set[str] = set()
    for raw_path in claim_files:
        path_text = str(raw_path or "").strip()
        if not path_text:
            errors.append("pr_cleanup_export_plan: claim_files entries must be non-empty paths")
            continue
        path = Path(path_text).expanduser().resolve()
        if str(path) in seen_claims:
            errors.append("pr_cleanup_export_plan: duplicate claim_files path")
        seen_claims.add(str(path))
        if is_forbidden_env_path(path):
            errors.append("pr_cleanup_export_plan: claim_files must not include .env-like paths")
        if not path.is_file():
            errors.append(f"pr_cleanup_export_plan: claim_file is missing: {path}")

    for field in ["out_sh_sha256"]:
        require_sha_field(errors=errors, name="pr_cleanup_export_plan", payload=payload, field=field)
    out_sh = str(payload.get("out_sh") or "").strip()
    if not out_sh:
        errors.append("pr_cleanup_export_plan: out_sh must be present")
        return
    script_path = Path(out_sh).expanduser().resolve()
    if is_forbidden_env_path(script_path):
        errors.append("pr_cleanup_export_plan: out_sh must not be .env-like")
    if not script_path.is_file():
        errors.append("pr_cleanup_export_plan: out_sh file must exist")
        return
    if sha256_file(script_path) != str(payload.get("out_sh_sha256") or ""):
        errors.append("pr_cleanup_export_plan: out_sh_sha256 must match out_sh file")
    script_text = script_path.read_text(encoding="utf-8")
    if not script_text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n"):
        errors.append("pr_cleanup_export_plan: out_sh must start with bash strict-mode header")
    for snippet in PR_CLEANUP_EXPORT_PLAN_FORBIDDEN_SCRIPT_SNIPPETS:
        if snippet in script_text:
            errors.append(f"pr_cleanup_export_plan: out_sh must not contain mutation command {snippet!r}")
    if export_pr_count >= 0 and script_text.count("gh pr view ") != export_pr_count:
        errors.append("pr_cleanup_export_plan: out_sh gh pr view count must match export_pr_count")
    if "scripts/amr_beta_pr_cleanup_status.py" not in script_text:
        errors.append("pr_cleanup_export_plan: out_sh must run amr_beta_pr_cleanup_status.py")


def require_pr_cleanup_status(*, errors: list[str], payload: dict) -> None:
    require_flag(
        errors=errors,
        name="pr_cleanup_status",
        payload=payload,
        key="stage_0_claim_freeze_verified",
        expected=1,
    )
    require_flag(errors=errors, name="pr_cleanup_status", payload=payload, key="checklist_pr_merged", expected=1)
    require_flag(errors=errors, name="pr_cleanup_status", payload=payload, key="stale_prs_closed", expected=1)
    require_flag(
        errors=errors,
        name="pr_cleanup_status",
        payload=payload,
        key="claim_freeze_scan_passed",
        expected=1,
    )
    require_flag(
        errors=errors,
        name="pr_cleanup_status",
        payload=payload,
        key="output_path_guard_passed",
        expected=1,
    )
    for key in ["runs_github_query", "runs_github_mutation", "runs_git_push", "creates_benchmark_evidence"]:
        require_flag(errors=errors, name="pr_cleanup_status", payload=payload, key=key, expected=0)
    require_flag(errors=errors, name="pr_cleanup_status", payload=payload, key="reads_pr_state_export", expected=1)
    require_sha_field(errors=errors, name="pr_cleanup_status", payload=payload, field="input_pr_state_sha256")

    checklist_pr = require_exact_int(errors=errors, name="pr_cleanup_status", payload=payload, key="checklist_pr_number")
    if checklist_pr != 46:
        errors.append("pr_cleanup_status: checklist_pr_number must be 46")
    if str(payload.get("checklist_pr_state") or "").upper() != "MERGED":
        errors.append("pr_cleanup_status: checklist_pr_state must be MERGED")
    if not str(payload.get("checklist_pr_merged_at") or "").strip():
        errors.append("pr_cleanup_status: checklist_pr_merged_at must be present")

    expected_stale_numbers = {39, 40, 10, 5}
    stale_numbers = payload.get("stale_pr_numbers")
    if not isinstance(stale_numbers, list) or sorted(stale_numbers) != sorted(expected_stale_numbers):
        errors.append("pr_cleanup_status: stale_pr_numbers must be [39, 40, 10, 5]")
    stale_statuses = payload.get("stale_pr_statuses")
    if not isinstance(stale_statuses, list):
        errors.append("pr_cleanup_status: stale_pr_statuses must be a list")
        stale_statuses = []
    stale_closed_count = require_exact_int(
        errors=errors,
        name="pr_cleanup_status",
        payload=payload,
        key="stale_pr_closed_count",
    )
    if stale_closed_count >= 0 and stale_closed_count != 4:
        errors.append("pr_cleanup_status: stale_pr_closed_count must be 4")
    if len(stale_statuses) != 4:
        errors.append("pr_cleanup_status: stale_pr_statuses must include exactly 4 rows")
    stale_status_numbers: list[int] = []
    for row in stale_statuses:
        if not isinstance(row, dict):
            errors.append("pr_cleanup_status: stale_pr_statuses rows must be objects")
            continue
        raw_number = row.get("number")
        try:
            number = int(raw_number)
        except (TypeError, ValueError):
            number = -1
        if number not in expected_stale_numbers:
            errors.append("pr_cleanup_status: stale_pr_statuses number must be one of [39, 40, 10, 5]")
        else:
            stale_status_numbers.append(number)
        if str(row.get("state") or "").upper() != "CLOSED":
            errors.append(f"pr_cleanup_status: stale PR #{number} must be CLOSED")
        if int(row.get("closed_without_merge", 0)) != 1:
            errors.append(f"pr_cleanup_status: stale PR #{number} must be closed without merge")
        if str(row.get("merged_at") or ""):
            errors.append(f"pr_cleanup_status: stale PR #{number} must not have merged_at")
    if sorted(stale_status_numbers) != sorted(expected_stale_numbers):
        errors.append("pr_cleanup_status: stale_pr_statuses must include each stale PR exactly once")

    claim_count = require_int_at_least(
        errors=errors,
        name="pr_cleanup_status",
        payload=payload,
        key="claim_scan_file_count",
        minimum=1,
    )
    blocked_promotions = require_exact_int(
        errors=errors,
        name="pr_cleanup_status",
        payload=payload,
        key="claim_scan_blocked_promotions",
    )
    if blocked_promotions != 0:
        errors.append("pr_cleanup_status: claim_scan_blocked_promotions must be 0")
    claim_hits = payload.get("claim_scan_hits")
    if not isinstance(claim_hits, list):
        errors.append("pr_cleanup_status: claim_scan_hits must be a list")
        claim_hits = []
    if blocked_promotions >= 0 and blocked_promotions != len(claim_hits):
        errors.append("pr_cleanup_status: claim_scan_blocked_promotions must match claim_scan_hits length")
    if claim_hits:
        errors.append("pr_cleanup_status: claim_scan_hits must be empty")
    claim_files = payload.get("claim_scan_files")
    if not isinstance(claim_files, list):
        errors.append("pr_cleanup_status: claim_scan_files must be a list")
        claim_files = []
    if claim_count > 0 and len(claim_files) != claim_count:
        errors.append("pr_cleanup_status: claim_scan_file_count must match claim_scan_files length")
    seen_claim_paths: set[str] = set()
    for index, row in enumerate(claim_files, start=1):
        if not isinstance(row, dict):
            errors.append(f"pr_cleanup_status: claim_scan_files row {index} must be an object")
            continue
        claim_path = str(row.get("path") or "").strip()
        if not claim_path:
            errors.append(f"pr_cleanup_status: claim_scan_files row {index} path must be present")
        elif claim_path in seen_claim_paths:
            errors.append(f"pr_cleanup_status: duplicate claim_scan_files path: {claim_path}")
        seen_claim_paths.add(claim_path)
        if not SHA256_RE.fullmatch(str(row.get("sha256") or "")):
            errors.append(f"pr_cleanup_status: claim_scan_files row {index} sha256 must be a sha256 binding")


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
    name: str = "repo_audit_plan",
    require_git_read_flags: bool = False,
) -> dict[str, dict]:
    rows = repo.get("repo_snapshot_lock_rows")
    if not isinstance(rows, list):
        errors.append(f"{name}: repo_snapshot_lock_rows must be a list")
        return {}

    row_count = require_exact_int(
        errors=errors,
        name=name,
        payload=repo,
        key="repo_snapshot_lock_row_count",
    )
    if row_count >= 0 and row_count != len(rows):
        errors.append(f"{name}: repo_snapshot_lock_row_count must match repo_snapshot_lock_rows length")
    if valid_repo_rows > 0 and len(rows) != valid_repo_rows:
        errors.append(f"{name}: repo_snapshot_lock_rows length must match valid_repo_rows")
    if str(repo.get("repo_snapshot_lock_sha256") or "") != sha256_json(rows):
        errors.append(f"{name}: repo_snapshot_lock_sha256 must match repo_snapshot_lock_rows")

    lock_by_case: dict[str, dict] = {}
    seen_paths: set[str] = set()
    seen_git_roots: set[str] = set()
    for index, row in enumerate(rows, start=1):
        prefix = f"{name}: repo_snapshot_lock_rows row {index}"
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
        canonical_repo_path = ""
        if not repo_path:
            errors.append(f"{prefix}: repo_path_resolved must be present")
        else:
            canonical_repo_path = str(Path(repo_path).expanduser().resolve())
            if canonical_repo_path in seen_paths:
                errors.append(f"{prefix}: duplicate repo_path_resolved")
            seen_paths.add(canonical_repo_path)

        repo_git_root = str(row.get("repo_git_root") or "").strip()
        if not repo_git_root:
            errors.append(f"{prefix}: repo_git_root must be present")
        else:
            canonical_git_root = str(Path(repo_git_root).expanduser().resolve())
            if canonical_git_root in seen_git_roots:
                errors.append(f"{prefix}: duplicate repo_git_root")
            seen_git_roots.add(canonical_git_root)
            if canonical_repo_path and canonical_git_root != canonical_repo_path:
                errors.append(f"{prefix}: repo_git_root must match repo_path_resolved")

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
        if require_git_read_flags:
            for key in [
                "repo_git_worktree_confirmed",
                "repo_head_readable",
                "repo_status_readable",
                "repo_head_pinned",
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

    require_repo_operator_command_script(
        errors=errors,
        repo=repo,
        commands=commands,
        snapshot_lock_rows=snapshot_lock_rows,
    )


def repo_operator_command_script_text(repo: dict, commands: list[str]) -> str:
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        "# Generated by scripts/amr_beta_repo_audit_plan.py.",
        "# This script runs the operator commands from a validated repo audit plan.",
        "# It does not prove beta readiness by itself; verify outputs before use.",
        f"# repo_snapshot_lock_sha256: {repo.get('repo_snapshot_lock_sha256', '')}",
        f"# operator_commands_sha256: {repo.get('operator_commands_sha256', '')}",
        f"# operator_command_count: {len(commands)}",
        "",
    ]
    for index, command in enumerate(commands, start=1):
        lines.extend([f"# command {index}", command, ""])
    return "\n".join(lines).rstrip() + "\n"


def require_repo_operator_command_script(
    *,
    errors: list[str],
    repo: dict,
    commands: list[str],
    snapshot_lock_rows: dict[str, dict],
) -> None:
    if not any(field in repo for field in REPO_AUDIT_PLAN_COMMAND_SCRIPT_FIELDS):
        return

    errors.extend(
        strict_int_flag_errors(
            "repo_audit_plan",
            repo,
            ["writes_operator_command_script"],
            {0, 1},
        )
    )
    writes_script = truthy_int(repo, "writes_operator_command_script")
    script_path_text = str(repo.get("operator_commands_script") or "").strip()
    script_sha = str(repo.get("operator_commands_script_sha256") or "").strip()
    script_count = repo.get("operator_commands_script_command_count")

    if isinstance(script_count, bool) or not isinstance(script_count, int):
        errors.append("repo_audit_plan: operator_commands_script_command_count must be an integer")
        return

    if not writes_script:
        if script_path_text:
            errors.append("repo_audit_plan: operator_commands_script must be empty when writes_operator_command_script=0")
        if script_sha:
            errors.append("repo_audit_plan: operator_commands_script_sha256 must be empty when writes_operator_command_script=0")
        if script_count != 0:
            errors.append("repo_audit_plan: operator_commands_script_command_count must be 0 when writes_operator_command_script=0")
        return

    if not script_path_text:
        errors.append("repo_audit_plan: operator_commands_script is required when writes_operator_command_script=1")
        return
    script_path = Path(script_path_text).expanduser().resolve()
    if is_forbidden_env_path(script_path):
        errors.append("repo_audit_plan: operator_commands_script must not be .env-like")
    for lock_row in snapshot_lock_rows.values():
        repo_path = str(lock_row.get("repo_path_resolved") or "").strip()
        if repo_path and (script_path == Path(repo_path).expanduser().resolve() or is_relative_to(script_path, Path(repo_path))):
            errors.append("repo_audit_plan: operator_commands_script must not be inside a target repo")
            break
    if script_count != len(commands):
        errors.append("repo_audit_plan: operator_commands_script_command_count must match operator_commands length")

    expected_script_sha = sha256_text(repo_operator_command_script_text(repo, commands))
    if script_sha != expected_script_sha:
        errors.append("repo_audit_plan: operator_commands_script_sha256 must match operator command script content")
    if not script_path.is_file():
        errors.append("repo_audit_plan: operator_commands_script must exist")
        return
    if sha256_file(script_path) != script_sha:
        errors.append("repo_audit_plan: operator_commands_script_sha256 must match operator_commands_script file")


def label_operator_command_script_text(label: dict, commands: list[str]) -> str:
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        "# Generated by scripts/amr_beta_label_intake_plan.py.",
        "# This script runs the operator commands from a validated label-intake plan.",
        "# It does not prove beta readiness by itself; verify outputs before use.",
        f"# repo_snapshot_lock_sha256: {label.get('repo_snapshot_lock_sha256', '')}",
        f"# label_template_bundle_sha256: {label.get('label_template_bundle_sha256', '')}",
        f"# decisions_sha256: {label.get('decisions_sha256', '')}",
        f"# operator_commands_sha256: {label.get('operator_commands_sha256', '')}",
        f"# operator_command_count: {len(commands)}",
        "",
    ]
    for index, command in enumerate(commands, start=1):
        lines.extend([f"# command {index}", command, ""])
    return "\n".join(lines).rstrip() + "\n"


def require_label_operator_command_script(
    *,
    errors: list[str],
    label: dict,
    commands: list[str],
    repo_paths: list[str],
) -> None:
    if not any(field in label for field in LABEL_INTAKE_PLAN_COMMAND_SCRIPT_FIELDS):
        return

    errors.extend(
        strict_int_flag_errors(
            "label_intake_plan",
            label,
            ["writes_operator_command_script"],
            {0, 1},
        )
    )
    writes_script = truthy_int(label, "writes_operator_command_script")
    script_path_text = str(label.get("operator_commands_script") or "").strip()
    script_sha = str(label.get("operator_commands_script_sha256") or "").strip()
    script_count = label.get("operator_commands_script_command_count")

    if isinstance(script_count, bool) or not isinstance(script_count, int):
        errors.append("label_intake_plan: operator_commands_script_command_count must be an integer")
        return

    if not writes_script:
        if script_path_text:
            errors.append("label_intake_plan: operator_commands_script must be empty when writes_operator_command_script=0")
        if script_sha:
            errors.append("label_intake_plan: operator_commands_script_sha256 must be empty when writes_operator_command_script=0")
        if script_count != 0:
            errors.append("label_intake_plan: operator_commands_script_command_count must be 0 when writes_operator_command_script=0")
        return

    if not script_path_text:
        errors.append("label_intake_plan: operator_commands_script is required when writes_operator_command_script=1")
        return
    script_path = Path(script_path_text).expanduser().resolve()
    if is_forbidden_env_path(script_path):
        errors.append("label_intake_plan: operator_commands_script must not be .env-like")
    for repo_path_text in repo_paths:
        repo_path = Path(repo_path_text).expanduser().resolve()
        if script_path == repo_path or is_relative_to(script_path, repo_path):
            errors.append("label_intake_plan: operator_commands_script must not be inside a target repo")
            break
    if script_count != len(commands):
        errors.append("label_intake_plan: operator_commands_script_command_count must match operator_commands length")

    expected_script_sha = sha256_text(label_operator_command_script_text(label, commands))
    if script_sha != expected_script_sha:
        errors.append("label_intake_plan: operator_commands_script_sha256 must match operator command script content")
    if not script_path.is_file():
        errors.append("label_intake_plan: operator_commands_script must exist")
        return
    if sha256_file(script_path) != script_sha:
        errors.append("label_intake_plan: operator_commands_script_sha256 must match operator_commands_script file")


def require_repo_intake_status(*, errors: list[str], payload: dict) -> None:
    ready = require_exact_int(
        errors=errors,
        name="repo_intake_status",
        payload=payload,
        key="ready_for_real_benchmark_audit",
    )
    if ready not in {0, 1}:
        errors.append("repo_intake_status: ready_for_real_benchmark_audit must be one of [0, 1]")
    min_repos = require_int_at_least(
        errors=errors,
        name="repo_intake_status",
        payload=payload,
        key="min_real_repos_required",
        minimum=10,
    )
    valid_repo_rows = require_int_at_least(
        errors=errors,
        name="repo_intake_status",
        payload=payload,
        key="valid_repo_rows",
        minimum=0,
    )
    total_rows = require_int_at_least(
        errors=errors,
        name="repo_intake_status",
        payload=payload,
        key="total_rows",
        minimum=valid_repo_rows,
    )
    if ready == 1 and valid_repo_rows < max(10, min_repos):
        errors.append("repo_intake_status: valid_repo_rows must be >= min_real_repos_required when ready")
    if ready == 1 and valid_repo_rows >= 0 and total_rows >= 0 and total_rows != valid_repo_rows:
        errors.append("repo_intake_status: total_rows must match valid_repo_rows")
    require_sha_field(errors=errors, name="repo_intake_status", payload=payload, field="input_intake_sha256")
    require_sha_field(errors=errors, name="repo_intake_status", payload=payload, field="repo_snapshot_lock_sha256")
    rows = payload.get("repo_snapshot_lock_rows")
    if not isinstance(rows, list):
        errors.append("repo_intake_status: repo_snapshot_lock_rows must be a list")
        rows = []
    row_count = require_exact_int(
        errors=errors,
        name="repo_intake_status",
        payload=payload,
        key="repo_snapshot_lock_row_count",
    )
    if row_count >= 0 and row_count != len(rows):
        errors.append("repo_intake_status: repo_snapshot_lock_row_count must match repo_snapshot_lock_rows length")
    if total_rows >= 0 and len(rows) != total_rows:
        errors.append("repo_intake_status: repo_snapshot_lock_rows length must match total_rows")
    if str(payload.get("repo_snapshot_lock_sha256") or "") != sha256_json(rows):
        errors.append("repo_intake_status: repo_snapshot_lock_sha256 must match repo_snapshot_lock_rows")

    seen_cases: set[str] = set()
    strict_valid_rows = 0
    for index, row in enumerate(rows, start=1):
        prefix = f"repo_intake_status: repo_snapshot_lock_rows row {index}"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        case_id = str(row.get("case_id") or "").strip()
        if not case_id:
            errors.append(f"{prefix}: case_id must be present")
        elif case_id in seen_cases:
            errors.append(f"{prefix}: duplicate case_id")
        seen_cases.add(case_id)

        valid = row.get("valid")
        if isinstance(valid, bool) or not isinstance(valid, int) or valid not in {0, 1}:
            errors.append(f"{prefix}: valid must be one of [0, 1]")
            valid = 0
        if valid == 1:
            strict_valid_rows += 1
            repo_path = str(row.get("repo_path_resolved") or "").strip()
            repo_git_root = str(row.get("repo_git_root") or "").strip()
            if not repo_path:
                errors.append(f"{prefix}: repo_path_resolved must be present")
            if not repo_git_root:
                errors.append(f"{prefix}: repo_git_root must be present")
            if repo_path and repo_git_root and not same_path(repo_path, repo_git_root):
                errors.append(f"{prefix}: repo_git_root must match repo_path_resolved")

            expected_head = str(row.get("expected_repo_git_head") or "").strip().lower()
            actual_head = str(row.get("actual_repo_git_head") or "").strip().lower()
            if not GIT_OBJECT_RE.fullmatch(expected_head):
                errors.append(f"{prefix}: expected_repo_git_head must be a full git object id")
            if not GIT_OBJECT_RE.fullmatch(actual_head):
                errors.append(f"{prefix}: actual_repo_git_head must be a full git object id")
            if expected_head and actual_head and expected_head != actual_head:
                errors.append(f"{prefix}: expected_repo_git_head must match actual_repo_git_head")

            for key in [
                "repo_git_worktree_confirmed",
                "repo_head_readable",
                "repo_status_readable",
                "repo_head_pinned",
                "clean_worktree_declared",
                "clean_worktree_actual",
                "owner_or_maintainer_contact_present",
                "real_benchmark_namespace_confirmed",
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
    if valid_repo_rows >= 0 and strict_valid_rows != valid_repo_rows:
        errors.append("repo_intake_status: valid_repo_rows must match valid repo_snapshot_lock_rows")
    for key in REPO_INTAKE_STATUS_READ_ONLY_FLAGS:
        require_flag(errors=errors, name="repo_intake_status", payload=payload, key=key, expected=0)
    for key in ["input_path_guard_passed", "output_path_guard_passed"]:
        value = require_exact_int(errors=errors, name="repo_intake_status", payload=payload, key=key)
        if value not in {0, 1}:
            errors.append(f"repo_intake_status: {key} must be one of [0, 1]")
        if ready == 1 and value != 1:
            errors.append(f"repo_intake_status: {key} must be 1 when ready")


def require_discovery_row_flag(
    *,
    errors: list[str],
    prefix: str,
    row: dict,
    key: str,
) -> int:
    value = row.get(key)
    if isinstance(value, bool) or not isinstance(value, int):
        errors.append(f"{prefix}: {key} must be an integer")
        return -1
    if value not in {0, 1}:
        errors.append(f"{prefix}: {key} must be one of [0, 1]")
    return value


def require_repo_discovery_status(*, errors: list[str], payload: dict) -> None:
    for key in REPO_DISCOVERY_STATUS_READ_ONLY_FLAGS:
        require_flag(errors=errors, name="repo_discovery_status", payload=payload, key=key, expected=0)
    require_flag(
        errors=errors,
        name="repo_discovery_status",
        payload=payload,
        key="candidate_rows_cannot_count_without_human_contact",
        expected=1,
    )

    candidate_count = require_int_at_least(
        errors=errors,
        name="repo_discovery_status",
        payload=payload,
        key="candidate_repo_count",
        minimum=0,
    )
    clean_head_count = require_int_at_least(
        errors=errors,
        name="repo_discovery_status",
        payload=payload,
        key="candidate_repos_with_clean_head",
        minimum=0,
    )
    require_int_at_least(
        errors=errors,
        name="repo_discovery_status",
        payload=payload,
        key="min_real_repos_required",
        minimum=10,
    )
    if clean_head_count > candidate_count:
        errors.append("repo_discovery_status: candidate_repos_with_clean_head must be <= candidate_repo_count")

    candidates = payload.get("candidates")
    if not isinstance(candidates, list):
        errors.append("repo_discovery_status: candidates must be a list")
        candidates = []
    if candidate_count >= 0 and len(candidates) != candidate_count:
        errors.append("repo_discovery_status: candidate_repo_count must match candidates length")

    ready_rows = 0
    seen_paths: set[str] = set()
    for index, row in enumerate(candidates, start=1):
        prefix = f"repo_discovery_status: candidates row {index}"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue

        repo_path = str(row.get("repo_path") or "").strip()
        repo_git_root = str(row.get("repo_git_root") or "").strip()
        if not repo_path:
            errors.append(f"{prefix}: repo_path must be present")
        if not repo_git_root:
            errors.append(f"{prefix}: repo_git_root must be present")
        if repo_path and repo_git_root and not same_path(repo_path, repo_git_root):
            errors.append(f"{prefix}: repo_git_root must match repo_path")
        if repo_path in seen_paths:
            errors.append(f"{prefix}: duplicate repo_path")
        seen_paths.add(repo_path)

        worktree = require_discovery_row_flag(errors=errors, prefix=prefix, row=row, key="repo_git_worktree_confirmed")
        head = require_discovery_row_flag(errors=errors, prefix=prefix, row=row, key="repo_head_readable")
        status = require_discovery_row_flag(errors=errors, prefix=prefix, row=row, key="repo_status_readable")
        contact_present = require_discovery_row_flag(
            errors=errors,
            prefix=prefix,
            row=row,
            key="owner_or_maintainer_contact_present",
        )
        contact_required = require_discovery_row_flag(
            errors=errors,
            prefix=prefix,
            row=row,
            key="owner_or_maintainer_contact_required",
        )
        namespace_required = require_discovery_row_flag(
            errors=errors,
            prefix=prefix,
            row=row,
            key="real_benchmark_namespace_confirmation_required",
        )
        ready = require_discovery_row_flag(
            errors=errors,
            prefix=prefix,
            row=row,
            key="ready_for_intake_after_human_contact",
        )
        counts = require_discovery_row_flag(errors=errors, prefix=prefix, row=row, key="counts_for_repo_intake")

        if contact_present != 0:
            errors.append(f"{prefix}: owner_or_maintainer_contact_present must be 0")
        if contact_required != 1:
            errors.append(f"{prefix}: owner_or_maintainer_contact_required must be 1")
        if namespace_required != 1:
            errors.append(f"{prefix}: real_benchmark_namespace_confirmation_required must be 1")
        if counts != 0:
            errors.append(f"{prefix}: counts_for_repo_intake must be 0")

        clean = row.get("clean_worktree_actual")
        if clean is not None and (isinstance(clean, bool) or not isinstance(clean, int) or clean not in {0, 1}):
            errors.append(f"{prefix}: clean_worktree_actual must be null or one of [0, 1]")
        if ready == 1:
            ready_rows += 1
            if worktree != 1 or head != 1 or status != 1 or clean != 1:
                errors.append(f"{prefix}: ready_for_intake_after_human_contact requires clean readable git state")

        actual_head = str(row.get("actual_repo_git_head") or "").strip().lower()
        if head == 1 and not GIT_OBJECT_RE.fullmatch(actual_head):
            errors.append(f"{prefix}: actual_repo_git_head must be a full git object id when head is readable")
        if str(row.get("suggested_namespace") or "").strip() != "real_benchmark":
            errors.append(f"{prefix}: suggested_namespace must be real_benchmark")

        blockers = row.get("blockers_before_counting")
        if not isinstance(blockers, list):
            errors.append(f"{prefix}: blockers_before_counting must be a list")
            blockers = []
        required_blockers = {
            "human_owner_or_maintainer_contact_required",
            "filled_intake_namespace_confirmation_required",
        }
        if not required_blockers.issubset({str(blocker) for blocker in blockers}):
            errors.append(f"{prefix}: blockers_before_counting must include human contact and namespace blockers")

    if clean_head_count >= 0 and ready_rows != clean_head_count:
        errors.append("repo_discovery_status: candidate_repos_with_clean_head must match ready candidate rows")


def require_repo_discovery_response(*, errors: list[str], payload: dict) -> None:
    for key in REPO_DISCOVERY_RESPONSE_READ_ONLY_FLAGS:
        require_flag(errors=errors, name="repo_discovery_response", payload=payload, key=key, expected=0)
    require_flag(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        key="selected_rows_cannot_count_until_collector_and_validator_pass",
        expected=1,
    )
    ready = require_exact_int(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        key="ready_for_repo_intake_collect_command",
    )
    if ready not in {0, 1}:
        errors.append("repo_discovery_response: ready_for_repo_intake_collect_command must be one of [0, 1]")
    min_repos = require_int_at_least(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        key="min_real_repos_required",
        minimum=10,
    )
    response_rows = require_int_at_least(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        key="response_row_count",
        minimum=0,
    )
    selected_rows_count = require_int_at_least(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        key="selected_response_rows",
        minimum=0,
    )
    valid_selected_rows = require_int_at_least(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        key="valid_selected_response_rows",
        minimum=0,
    )
    if selected_rows_count > response_rows:
        errors.append("repo_discovery_response: selected_response_rows must be <= response_row_count")
    if valid_selected_rows > selected_rows_count:
        errors.append("repo_discovery_response: valid_selected_response_rows must be <= selected_response_rows")
    if ready == 1 and valid_selected_rows < max(10, min_repos):
        errors.append("repo_discovery_response: ready command requires >= min_real_repos_required valid selected rows")
    if ready == 0 and valid_selected_rows >= max(10, min_repos):
        errors.append("repo_discovery_response: ready_for_repo_intake_collect_command must be 1 when threshold is met")

    completion = payload.get("response_completion")
    if completion is not None:
        if not isinstance(completion, dict):
            errors.append("repo_discovery_response: response_completion must be an object")
        else:
            completion_name = "repo_discovery_response.response_completion"
            completion_ints = {
                key: require_int_at_least(
                    errors=errors,
                    name=completion_name,
                    payload=completion,
                    key=key,
                    minimum=0,
                )
                for key in [
                    "request_row_count",
                    "response_row_count",
                    "recommended_request_rows",
                    "selected_truthy_response_rows",
                    "unselected_response_rows",
                    "blank_include_response_rows",
                    "invalid_include_response_rows",
                    "duplicate_case_id_response_rows",
                    "selected_unknown_case_id_rows",
                    "selected_not_recommended_rows",
                    "selected_missing_or_invalid_contact_rows",
                    "selected_missing_namespace_confirmation_rows",
                    "selected_repo_path_mismatch_rows",
                    "selected_response_rows_remaining_to_minimum",
                    "human_required_cells_remaining",
                ]
            }
            if completion_ints["response_row_count"] != response_rows:
                errors.append("repo_discovery_response: response_completion response_row_count must match response_row_count")
            if completion_ints["selected_truthy_response_rows"] < selected_rows_count:
                errors.append(
                    "repo_discovery_response: response_completion selected_truthy_response_rows "
                    "must be >= selected_response_rows"
                )
            if "human_required_cells_remaining" in payload:
                top_level_remaining = require_int_at_least(
                    errors=errors,
                    name="repo_discovery_response",
                    payload=payload,
                    key="human_required_cells_remaining",
                    minimum=0,
                )
                if top_level_remaining != completion_ints["human_required_cells_remaining"]:
                    errors.append(
                        "repo_discovery_response: human_required_cells_remaining must match response_completion"
                    )
            if "request_response_template_row_count" in payload:
                template_rows = require_int_at_least(
                    errors=errors,
                    name="repo_discovery_response",
                    payload=payload,
                    key="request_response_template_row_count",
                    minimum=0,
                )
                if template_rows > completion_ints["request_row_count"]:
                    errors.append(
                        "repo_discovery_response: request_response_template_row_count "
                        "must be <= response_completion request_row_count"
                    )
            if "request_response_template_recommended_only" in payload:
                recommended_only = require_exact_int(
                    errors=errors,
                    name="repo_discovery_response",
                    payload=payload,
                    key="request_response_template_recommended_only",
                )
                if recommended_only not in {0, 1}:
                    errors.append(
                        "repo_discovery_response: request_response_template_recommended_only must be one of [0, 1]"
                    )
                elif recommended_only == 1 and "request_response_template_row_count" in payload:
                    template_rows = require_int_at_least(
                        errors=errors,
                        name="repo_discovery_response",
                        payload=payload,
                        key="request_response_template_row_count",
                        minimum=0,
                    )
                    if template_rows > completion_ints["recommended_request_rows"]:
                        errors.append(
                            "repo_discovery_response: recommended-only template row count "
                            "must be <= response_completion recommended_request_rows"
                        )

    require_sha_field(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        field="repo_discovery_request_sha256",
    )
    require_sha_field(errors=errors, name="repo_discovery_response", payload=payload, field="human_response_sha256")
    require_sha_field(
        errors=errors,
        name="repo_discovery_response",
        payload=payload,
        field="selected_response_fingerprint_sha256",
    )

    selected_rows = payload.get("selected_rows")
    if not isinstance(selected_rows, list):
        errors.append("repo_discovery_response: selected_rows must be a list")
        selected_rows = []
    if selected_rows_count >= 0 and len(selected_rows) != selected_rows_count:
        errors.append("repo_discovery_response: selected_response_rows must match selected_rows length")

    selected_case_ids = payload.get("selected_case_ids")
    if not isinstance(selected_case_ids, list):
        errors.append("repo_discovery_response: selected_case_ids must be a list")
        selected_case_ids = []
    if len(selected_case_ids) != len(selected_rows):
        errors.append("repo_discovery_response: selected_case_ids length must match selected_rows")

    seen_cases: set[str] = set()
    for index, row in enumerate(selected_rows, start=1):
        prefix = f"repo_discovery_response: selected_rows row {index}"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        case_id = str(row.get("suggested_case_id") or "").strip()
        if not case_id:
            errors.append(f"{prefix}: suggested_case_id must be present")
        elif case_id in seen_cases:
            errors.append(f"{prefix}: duplicate suggested_case_id")
        seen_cases.add(case_id)
        if case_id and selected_case_ids and selected_case_ids[index - 1] != case_id:
            errors.append(f"{prefix}: selected_case_ids must match selected_rows order")
        if not str(row.get("repo_path") or "").strip():
            errors.append(f"{prefix}: repo_path must be present")
        head = str(row.get("actual_repo_git_head") or "").strip().lower()
        if not GIT_OBJECT_RE.fullmatch(head):
            errors.append(f"{prefix}: actual_repo_git_head must be a full git object id")
        if row.get("owner_or_maintainer_contact") is not None:
            errors.append(f"{prefix}: must not expose raw owner_or_maintainer_contact")
        contact_sha = str(row.get("owner_or_maintainer_contact_sha256") or "")
        if not SHA256_RE.fullmatch(contact_sha):
            errors.append(f"{prefix}: owner_or_maintainer_contact_sha256 must be a sha256 binding")
        require_discovery_row_flag(errors=errors, prefix=prefix, row=row, key="real_benchmark_namespace_confirmed")
        counts = require_discovery_row_flag(errors=errors, prefix=prefix, row=row, key="counts_for_repo_intake")
        if counts != 0:
            errors.append(f"{prefix}: counts_for_repo_intake must be 0")

    command = str(payload.get("collector_command_redacted") or "")
    command_argv = payload.get("collector_command_argv_redacted")
    if selected_rows:
        if "<contact-for-" not in command:
            errors.append("repo_discovery_response: collector_command_redacted must contain contact placeholders")
        if not isinstance(command_argv, list) or not command_argv:
            errors.append("repo_discovery_response: collector_command_argv_redacted must be a non-empty list")
    next_blockers = payload.get("next_blockers", [])
    if not isinstance(next_blockers, list):
        errors.append("repo_discovery_response: next_blockers must be a list")


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
    repo_paths: list[str] = []
    for row in per_case:
        if not isinstance(row, dict):
            errors.append("label_intake_plan: per_case rows must be objects")
            return
        repo_path = str(row.get("repo_path") or "").strip()
        if repo_path:
            repo_paths.append(repo_path)
        for field in LABEL_INTAKE_PLAN_COMMAND_FIELDS:
            command = row.get(field)
            if not isinstance(command, str) or not command:
                errors.append(f"label_intake_plan: per_case rows must include {field}")
                return
            expected_commands.append(command)
    if commands != expected_commands:
        errors.append("label_intake_plan: operator_commands must exactly match per_case compile/verify commands")
    require_label_operator_command_script(
        errors=errors,
        label=label,
        commands=commands,
        repo_paths=repo_paths,
    )


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


def require_label_packet_summary_binding(*, errors: list[str], label: dict) -> None:
    require_flag(
        errors=errors,
        name="label_intake_plan",
        payload=label,
        key="label_packet_summary_bound",
        expected=1,
    )
    for field in [
        "label_packet_summary_sha256",
        "label_packet_decisions_bundle_sha256",
        "label_packet_template_bundle_sha256",
    ]:
        require_sha_field(errors=errors, name="label_intake_plan", payload=label, field=field)
    if not str(label.get("label_packet_summary") or ""):
        errors.append("label_intake_plan: label_packet_summary must be supplied")

    decision_fingerprints = label.get("label_packet_decisions_fingerprints")
    if not isinstance(decision_fingerprints, list):
        errors.append("label_intake_plan: label_packet_decisions_fingerprints must be a list")
        return
    for row in decision_fingerprints:
        if not isinstance(row, dict):
            errors.append("label_intake_plan: label_packet_decisions_fingerprints rows must be objects")
            return
        if not str(row.get("decisions") or ""):
            errors.append("label_intake_plan: label_packet_decisions_fingerprints rows must bind decisions")
            return
        if not SHA256_RE.fullmatch(str(row.get("decisions_sha256") or "")):
            errors.append("label_intake_plan: label_packet_decisions_fingerprints rows must bind decisions_sha256")
            return

    expected_fingerprints = [
        {
            "decisions": str(label.get("decisions") or ""),
            "decisions_sha256": str(label.get("decisions_sha256") or ""),
        }
    ]
    if decision_fingerprints != expected_fingerprints:
        errors.append("label_intake_plan: label_packet_decisions_fingerprints must match decisions input")
    if str(label.get("label_packet_decisions_bundle_sha256") or "") != sha256_json(decision_fingerprints):
        errors.append("label_intake_plan: label_packet_decisions_bundle_sha256 must match decisions fingerprints")
    if label.get("label_packet_template_bundle_sha256") != label.get("label_template_bundle_sha256"):
        errors.append("label_intake_plan: label_packet_template_bundle_sha256 must match label_template_bundle_sha256")


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
    pr_export = artifacts.get("pr_cleanup_export_plan")
    pr_cleanup = artifacts.get("pr_cleanup_status")
    discovery = artifacts.get("repo_discovery_status")
    discovery_response = artifacts.get("repo_discovery_response")
    intake = artifacts.get("repo_intake_status")
    repo = artifacts.get("repo_audit_plan")
    label = artifacts.get("label_intake_plan")
    feedback = artifacts.get("maintainer_feedback_packet")
    preflight = artifacts.get("runtime_preflight")
    request = artifacts.get("runtime_approval_request")
    status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")

    if pr_export:
        require_pr_cleanup_export_plan(errors=errors, payload=pr_export)

    if pr_cleanup:
        require_pr_cleanup_status(errors=errors, payload=pr_cleanup)

    if discovery:
        require_repo_discovery_status(errors=errors, payload=discovery)

    if discovery_response:
        require_repo_discovery_response(errors=errors, payload=discovery_response)

    if intake:
        require_repo_intake_status(errors=errors, payload=intake)

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
        require_label_packet_summary_binding(errors=errors, label=label)
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
        require_sha_field(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            field="feedback_sha256",
        )
        require_sha_field(
            errors=errors,
            name="maintainer_feedback_packet",
            payload=feedback,
            field="feedback_bundle_sha256",
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

    if intake and repo:
        require_matching_artifact_field(
            errors=errors,
            name="repo_audit_plan",
            payload=repo,
            field="repo_intake_sha256",
            expected=intake.get("input_intake_sha256"),
            expected_name="repo_intake_status",
        )
        require_matching_artifact_field(
            errors=errors,
            name="repo_audit_plan",
            payload=repo,
            field="repo_snapshot_lock_sha256",
            expected=intake.get("repo_snapshot_lock_sha256"),
            expected_name="repo_intake_status",
        )
        if repo.get("repo_snapshot_lock_rows") != intake.get("repo_snapshot_lock_rows"):
            errors.append("repo_audit_plan: repo_snapshot_lock_rows must match repo_intake_status")

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

    if feedback and preflight:
        for key in ["feedback_sha256", "feedback_bundle_sha256"]:
            require_matching_artifact_field(
                errors=errors,
                name="runtime_preflight",
                payload=preflight,
                field=key,
                expected=feedback.get(key),
                expected_name="maintainer_feedback_packet",
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

    if pr_export and pr_cleanup:
        require_matching_artifact_field(
            errors=errors,
            name="pr_cleanup_status",
            payload=pr_cleanup,
            field="input_pr_state",
            expected=pr_export.get("pr_state_out"),
            expected_name="pr_cleanup_export_plan",
        )
        export_claim_paths = sorted(str(path) for path in pr_export.get("claim_files", []))
        cleanup_claim_paths = sorted(str(row.get("path") or "") for row in pr_cleanup.get("claim_scan_files", []))
        if export_claim_paths and cleanup_claim_paths and export_claim_paths != cleanup_claim_paths:
            errors.append("pr_cleanup_status: claim_scan_files must match pr_cleanup_export_plan claim_files")

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
    pr_export = artifacts.get("pr_cleanup_export_plan")
    pr_cleanup = artifacts.get("pr_cleanup_status")
    intake = artifacts.get("repo_intake_status")
    repo = artifacts.get("repo_audit_plan")
    label = artifacts.get("label_intake_plan")
    feedback = artifacts.get("maintainer_feedback_packet")
    preflight = artifacts.get("runtime_preflight")
    approval_request = artifacts.get("runtime_approval_request")
    approval_status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")

    if not pr_cleanup or truthy_int(pr_cleanup, "stage_0_claim_freeze_verified") != 1:
        if pr_export and truthy_int(pr_export, "ready_for_pr_cleanup_export_handoff") == 1:
            return "stage_0_claim_freeze", [
                "Run the PR cleanup export handoff script with authenticated gh, then validate stage-0 status."
            ]
        return "stage_0_claim_freeze", [
            "Validate stage-0 PR cleanup and claim freeze from exported GitHub PR state."
        ]
    if not repo or truthy_int(repo, "ready_for_real_benchmark_audit_plan") != 1:
        if intake and truthy_int(intake, "ready_for_real_benchmark_audit") == 1:
            return "stage_0_claim_freeze", [
                "Generate a clean repo audit plan from the validated >=10 real repo intake status."
            ]
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


def nested_count_int(payload: dict | None, parent: str, key: str, default: int = 0) -> int:
    if not payload:
        return default
    nested = payload.get(parent)
    if not isinstance(nested, dict):
        return default
    return count_int(nested, key, default)


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
    pr_export = artifacts.get("pr_cleanup_export_plan")
    pr_cleanup = artifacts.get("pr_cleanup_status")
    discovery = artifacts.get("repo_discovery_status")
    discovery_response = artifacts.get("repo_discovery_response")
    intake = artifacts.get("repo_intake_status")
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
        count_int(discovery, "min_real_repos_required", 10),
        count_int(intake, "min_real_repos_required", 10),
        count_int(repo, "min_real_repos_required", 10),
        count_int(label, "min_real_repos_required", 10),
        count_int(feedback, "min_real_repos_required", 10),
    )
    repo_current = max(
        count_int(intake, "valid_repo_rows"),
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
    human_label_progress = progress_summary(label_current, label_required)
    human_label_progress.update(
        {
            "label_intake_plan_supplied": int(bool(label)),
            "ready_for_label_intake_plan": count_int(label, "ready_for_label_intake_plan"),
            "label_intake_plan_operator_command_count": count_int(label, "operator_command_count"),
            "label_intake_plan_command_script_written": count_int(label, "writes_operator_command_script"),
            "label_intake_plan_command_script_command_count": count_int(
                label,
                "operator_commands_script_command_count",
            ),
        }
    )

    return {
        "claim_freeze": {
            "pr_cleanup_export_plan_supplied": int(bool(pr_export)),
            "ready_for_pr_cleanup_export_handoff": count_int(
                pr_export,
                "ready_for_pr_cleanup_export_handoff",
            ),
            "pr_cleanup_export_pr_count": count_int(pr_export, "export_pr_count"),
            "pr_cleanup_export_script_written": count_int(pr_export, "writes_export_script"),
            "pr_cleanup_status_supplied": int(bool(pr_cleanup)),
            "stage_0_claim_freeze_verified": count_int(pr_cleanup, "stage_0_claim_freeze_verified"),
            "checklist_pr_merged": count_int(pr_cleanup, "checklist_pr_merged"),
            "stale_prs_closed": count_int(pr_cleanup, "stale_prs_closed"),
            "claim_freeze_scan_passed": count_int(pr_cleanup, "claim_freeze_scan_passed"),
            "claim_scan_file_count": count_int(pr_cleanup, "claim_scan_file_count"),
            "claim_scan_blocked_promotions": count_int(pr_cleanup, "claim_scan_blocked_promotions"),
        },
        "repo_intake": {
            **progress_summary(repo_current, repo_required),
            "repo_discovery_status_supplied": int(bool(discovery)),
            "candidate_repo_count": count_int(discovery, "candidate_repo_count"),
            "candidate_repos_with_clean_head": count_int(discovery, "candidate_repos_with_clean_head"),
            "candidate_rows_cannot_count_without_human_contact": count_int(
                discovery,
                "candidate_rows_cannot_count_without_human_contact",
            ),
            "repo_discovery_rows_counted": count_int(discovery, "repo_intake_rows_counted"),
            "repo_discovery_response_supplied": int(bool(discovery_response)),
            "selected_response_rows": count_int(discovery_response, "selected_response_rows"),
            "valid_selected_response_rows": count_int(discovery_response, "valid_selected_response_rows"),
            "ready_for_repo_intake_collect_command": count_int(
                discovery_response,
                "ready_for_repo_intake_collect_command",
            ),
            "repo_discovery_response_rows_counted": count_int(discovery_response, "repo_intake_rows_counted"),
            "repo_discovery_response_template_recommended_only": count_int(
                discovery_response,
                "request_response_template_recommended_only",
            ),
            "repo_discovery_response_template_row_count": count_int(
                discovery_response,
                "request_response_template_row_count",
            ),
            "repo_discovery_response_recommended_request_rows": nested_count_int(
                discovery_response,
                "response_completion",
                "recommended_request_rows",
            ),
            "repo_discovery_response_human_required_cells_remaining": count_int(
                discovery_response,
                "human_required_cells_remaining",
                nested_count_int(discovery_response, "response_completion", "human_required_cells_remaining"),
            ),
            "repo_discovery_response_blank_include_rows": nested_count_int(
                discovery_response,
                "response_completion",
                "blank_include_response_rows",
            ),
            "repo_discovery_response_missing_contact_rows": nested_count_int(
                discovery_response,
                "response_completion",
                "selected_missing_or_invalid_contact_rows",
            ),
            "repo_discovery_response_missing_namespace_rows": nested_count_int(
                discovery_response,
                "response_completion",
                "selected_missing_namespace_confirmation_rows",
            ),
            "repo_discovery_response_selected_rows_remaining_to_minimum": nested_count_int(
                discovery_response,
                "response_completion",
                "selected_response_rows_remaining_to_minimum",
            ),
            "repo_intake_status_supplied": int(bool(intake)),
            "ready_for_real_benchmark_audit": count_int(intake, "ready_for_real_benchmark_audit"),
            "repo_snapshot_lock_row_count": count_int(intake, "repo_snapshot_lock_row_count"),
            "repo_audit_plan_supplied": int(bool(repo)),
            "ready_for_real_benchmark_audit_plan": count_int(repo, "ready_for_real_benchmark_audit_plan"),
            "repo_audit_plan_operator_command_count": count_int(repo, "operator_command_count"),
            "repo_audit_plan_command_script_written": count_int(repo, "writes_operator_command_script"),
            "repo_audit_plan_command_script_command_count": count_int(
                repo,
                "operator_commands_script_command_count",
            ),
        },
        "human_labels": human_label_progress,
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
        "- claim_freeze_verified: "
        f"{payload['stage_progress']['claim_freeze']['stage_0_claim_freeze_verified']}",
        "- pr_cleanup_export_plan_supplied: "
        f"{payload['stage_progress']['claim_freeze']['pr_cleanup_export_plan_supplied']}",
        "- pr_cleanup_export_handoff_ready: "
        f"{payload['stage_progress']['claim_freeze']['ready_for_pr_cleanup_export_handoff']}",
        "- pr_cleanup_export_pr_count: "
        f"{payload['stage_progress']['claim_freeze']['pr_cleanup_export_pr_count']}",
        "- pr_cleanup_status_supplied: "
        f"{payload['stage_progress']['claim_freeze']['pr_cleanup_status_supplied']}",
        "- repo_intake: {current}/{required} "
        "(remaining {remaining}, met {met}, {progress_percent}%)".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- repo_discovery_candidates: {candidate_repo_count} "
        "(clean_head {candidate_repos_with_clean_head}, supplied {repo_discovery_status_supplied}, "
        "rows_counted {repo_discovery_rows_counted})".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- repo_discovery_response: {valid_selected_response_rows}/{required} "
        "(selected {selected_response_rows}, ready_command {ready_for_repo_intake_collect_command}, "
        "supplied {repo_discovery_response_supplied}, rows_counted {repo_discovery_response_rows_counted})".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- repo_discovery_response_template: rows {repo_discovery_response_template_row_count} "
        "(recommended_only {repo_discovery_response_template_recommended_only}, "
        "recommended_request_rows {repo_discovery_response_recommended_request_rows})".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- repo_discovery_response_completion: human_required_cells "
        "{repo_discovery_response_human_required_cells_remaining} "
        "(blank_include {repo_discovery_response_blank_include_rows}, "
        "missing_contact {repo_discovery_response_missing_contact_rows}, "
        "missing_namespace {repo_discovery_response_missing_namespace_rows}, "
        "selected_remaining {repo_discovery_response_selected_rows_remaining_to_minimum})".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- repo_audit_plan_commands: {repo_audit_plan_operator_command_count} "
        "(script_written {repo_audit_plan_command_script_written}, "
        "script_commands {repo_audit_plan_command_script_command_count})".format(
            **payload["stage_progress"]["repo_intake"],
        ),
        "- human_labels: {current}/{required} "
        "(remaining {remaining}, met {met}, {progress_percent}%)".format(
            **payload["stage_progress"]["human_labels"],
        ),
        "- label_intake_plan_commands: {label_intake_plan_operator_command_count} "
        "(script_written {label_intake_plan_command_script_written}, "
        "script_commands {label_intake_plan_command_script_command_count})".format(
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
    parser.add_argument("--pr-cleanup-export-plan", default="")
    parser.add_argument("--pr-cleanup-status", default="")
    parser.add_argument("--repo-discovery-status", default="")
    parser.add_argument("--repo-discovery-response", default="")
    parser.add_argument("--repo-intake-status", default="")
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
        "pr_cleanup_export_plan": args.pr_cleanup_export_plan,
        "pr_cleanup_status": args.pr_cleanup_status,
        "repo_discovery_status": args.repo_discovery_status,
        "repo_discovery_response": args.repo_discovery_response,
        "repo_intake_status": args.repo_intake_status,
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
