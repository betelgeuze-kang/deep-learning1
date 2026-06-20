#!/usr/bin/env python3
"""Validate repository JSON contracts against their JSON Schemas."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError as exc:  # pragma: no cover - exercised only on missing env deps.
    raise SystemExit("jsonschema is required for schema validation") from exc


REPO_ROOT = Path(__file__).resolve().parents[1]

SCHEMA_INSTANCE_REGISTRY = {
    "schemas/ai_verify_toolchain_lock.schema.json": ["ci/ai_verify_toolchain.lock.json"],
    "schemas/pr_split.schema.json": ["pr_slices/pr2.json"],
    "schemas/typed_readiness.schema.json": ["readiness/typed_ready.json"],
    "schemas/leakage_contract.schema.json": ["leakage/retrieval_model_visible.json"],
    "schemas/baseline_admission.schema.json": ["baselines/de_30b70b_real.json"],
    "schemas/v52_adapter_guard.schema.json": ["baselines/v52_adapter_guard.json"],
    "schemas/v50_auditor_correctness.schema.json": ["audits/v50_public_repo_auditor_correctness.json"],
    "schemas/v56_replay.schema.json": ["v56/replay_contract.json"],
    "schemas/v53_source_benchmark.schema.json": ["benchmarks/v53_source_bound_freeze.json"],
    "schemas/v54_grounded_generation.schema.json": ["v54/grounded_generation_contract.json"],
    "schemas/v58_blind_eval.schema.json": ["v58/blind_eval_real.json"],
    "schemas/review_return_workflow.schema.json": ["operations/review_return_workflow.json"],
    "schemas/v61_one_token_path.schema.json": ["v61/one_token_path.json"],
}

NON_CONTRACT_JSON_ALLOWLIST = {
    "opencode.json",
    "experiments/fixtures/v52x_external_de_bake/D/external_bake_manifest.json",
    "experiments/fixtures/v52x_external_de_bake/D/model_identity.json",
    "experiments/fixtures/v52x_external_de_bake/E/external_bake_manifest.json",
    "experiments/fixtures/v52x_external_de_bake/E/model_identity.json",
}


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_schema(schema_path: Path) -> list[str]:
    errors: list[str] = []
    try:
        schema = load_json(schema_path)
        jsonschema.Draft202012Validator.check_schema(schema)
    except Exception as exc:
        errors.append(f"{schema_path}: invalid schema: {exc}")
    return errors


def validate_contract_metadata(schema_path: Path, schema: object, instance: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    contract = schema.get("x-contract")
    if contract is None:
        return errors
    if not isinstance(contract, dict):
        return [f"{schema_path}: x-contract must be an object"]

    required_contract_keys = {
        "artifact_contracts",
        "artifact_value_checks",
        "blocked_runtime_forbidden_ready_fields",
        "current_status_by_milestone",
        "milestone_order",
        "real_model_execution_pass_milestones",
        "required_before_runtime_claim",
    }
    if not any(key in contract for key in required_contract_keys):
        return errors
    missing_contract_keys = required_contract_keys - set(contract)
    if missing_contract_keys:
        errors.append(f"{schema_path}: x-contract missing {', '.join(sorted(missing_contract_keys))}")

    milestone_order = contract.get("milestone_order", [])
    status_by_milestone = contract.get("current_status_by_milestone", {})
    required_before_runtime = contract.get("required_before_runtime_claim", [])
    artifact_contracts = contract.get("artifact_contracts", [])
    real_model_execution_pass_milestones = contract.get("real_model_execution_pass_milestones", [])
    blocked_runtime_forbidden_ready_fields = contract.get("blocked_runtime_forbidden_ready_fields", [])
    artifact_value_checks = contract.get("artifact_value_checks", {})
    if not isinstance(milestone_order, list) or not milestone_order or len(set(milestone_order)) != len(milestone_order):
        errors.append(f"{schema_path}: x-contract.milestone_order must be a non-empty unique list")
    if not isinstance(status_by_milestone, dict) or set(status_by_milestone) != set(milestone_order):
        errors.append(f"{schema_path}: x-contract.current_status_by_milestone keys must match milestone_order")
    elif any(value not in {"pass", "blocked"} for value in status_by_milestone.values()):
        errors.append(f"{schema_path}: x-contract.current_status_by_milestone values must be pass or blocked")
    if not isinstance(required_before_runtime, list) or not set(required_before_runtime).issubset(set(milestone_order)):
        errors.append(f"{schema_path}: x-contract.required_before_runtime_claim must be a milestone subset")
    if not isinstance(artifact_contracts, list) or not artifact_contracts:
        errors.append(f"{schema_path}: x-contract.artifact_contracts must be a non-empty list")
        artifact_contracts = []
    artifact_ids = [row.get("artifact_id") for row in artifact_contracts if isinstance(row, dict)]
    if len(set(artifact_ids)) != len(artifact_ids):
        errors.append(f"{schema_path}: x-contract.artifact_contracts artifact_id values must be unique")
    artifact_by_id = {}
    for index, row in enumerate(artifact_contracts, start=1):
        if not isinstance(row, dict):
            errors.append(f"{schema_path}: x-contract.artifact_contracts[{index}] must be an object")
            continue
        missing = {"artifact_id", "path", "linked_milestone_id", "pass_field", "min_rows", "required_columns"} - set(row)
        if missing:
            errors.append(f"{schema_path}: x-contract.artifact_contracts[{index}] missing {', '.join(sorted(missing))}")
        if row.get("linked_milestone_id") not in milestone_order:
            errors.append(f"{schema_path}: x-contract.artifact_contracts[{index}] linked_milestone_id must reference milestone_order")
        if not isinstance(row.get("min_rows"), int) or row.get("min_rows", 0) < 1:
            errors.append(f"{schema_path}: x-contract.artifact_contracts[{index}] min_rows must be a positive integer")
        required_columns = row.get("required_columns", [])
        if not isinstance(required_columns, list) or not required_columns or any(not isinstance(column, str) for column in required_columns):
            errors.append(f"{schema_path}: x-contract.artifact_contracts[{index}] required_columns must be a non-empty string list")
        elif len(set(required_columns)) != len(required_columns):
            errors.append(f"{schema_path}: x-contract.artifact_contracts[{index}] required_columns values must be unique")
        artifact_by_id[row.get("artifact_id", "")] = row

    if real_model_execution_pass_milestones:
        if not isinstance(real_model_execution_pass_milestones, list) or len(set(real_model_execution_pass_milestones)) != len(real_model_execution_pass_milestones):
            errors.append(f"{schema_path}: x-contract.real_model_execution_pass_milestones must be a unique list")
        elif not set(real_model_execution_pass_milestones).issubset(set(milestone_order)):
            errors.append(f"{schema_path}: x-contract.real_model_execution_pass_milestones must reference milestone_order")
    if blocked_runtime_forbidden_ready_fields:
        if (
            not isinstance(blocked_runtime_forbidden_ready_fields, list)
            or not blocked_runtime_forbidden_ready_fields
            or any(not isinstance(field, str) or not field for field in blocked_runtime_forbidden_ready_fields)
            or len(set(blocked_runtime_forbidden_ready_fields)) != len(blocked_runtime_forbidden_ready_fields)
        ):
            errors.append(f"{schema_path}: x-contract.blocked_runtime_forbidden_ready_fields must be a non-empty unique string list")
    if artifact_value_checks:
        if not isinstance(artifact_value_checks, dict):
            errors.append(f"{schema_path}: x-contract.artifact_value_checks must be an object")
        else:
            for artifact_id, checks in artifact_value_checks.items():
                contract_row = artifact_by_id.get(artifact_id)
                if contract_row is None:
                    errors.append(f"{schema_path}: x-contract.artifact_value_checks.{artifact_id} must reference artifact_contracts")
                    continue
                if not isinstance(checks, dict) or not checks:
                    errors.append(f"{schema_path}: x-contract.artifact_value_checks.{artifact_id} must be a non-empty object")
                    continue
                required_columns = set(contract_row.get("required_columns", []))
                for field, expected in checks.items():
                    if field not in required_columns:
                        errors.append(f"{schema_path}: x-contract.artifact_value_checks.{artifact_id}.{field} must reference required_columns")
                    if not isinstance(expected, str):
                        errors.append(f"{schema_path}: x-contract.artifact_value_checks.{artifact_id}.{field} expected value must be a string")

    milestones = instance.get("milestones", [])
    milestone_ids = [row.get("milestone_id", "") for row in milestones if isinstance(row, dict)]
    if milestone_order and milestone_ids != milestone_order:
        errors.append(f"{schema_path}: instance milestones must follow x-contract.milestone_order")
    for row in milestones:
        if isinstance(row, dict) and status_by_milestone.get(row.get("milestone_id", "")) != row.get("current_status"):
            errors.append(f"{schema_path}: instance milestone {row.get('milestone_id')} status must match x-contract")

    policy = instance.get("policy", {})
    if isinstance(policy, dict) and policy.get("required_before_ssd_resident_runtime_claim") != required_before_runtime:
        errors.append(f"{schema_path}: instance policy.required_before_ssd_resident_runtime_claim must match x-contract")

    required_artifacts = instance.get("required_artifacts", [])
    required_artifact_ids = [row.get("artifact_id", "") for row in required_artifacts if isinstance(row, dict)]
    if artifact_ids and required_artifact_ids != artifact_ids:
        errors.append(f"{schema_path}: instance required_artifacts must follow x-contract.artifact_contracts")
    for row in required_artifacts:
        if not isinstance(row, dict):
            continue
        artifact_id = row.get("artifact_id", "")
        contract_row = artifact_by_id.get(artifact_id)
        if not contract_row:
            continue
        for field in ["path", "linked_milestone_id", "pass_field", "min_rows", "required_columns"]:
            if row.get(field) != contract_row.get(field):
                errors.append(f"{schema_path}: instance required_artifact {artifact_id}.{field} must match x-contract")
    return errors


def validate_typed_readiness_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "typed_readiness.v1":
        return errors

    row_schema = (
        schema.get("properties", {})
        .get("rows", {})
        .get("items", {})
    )
    if not isinstance(row_schema, dict):
        errors.append(f"{schema_path}: typed readiness rows schema must be an object")
        return errors
    required_row_keys = row_schema.get("required", [])
    if not isinstance(required_row_keys, list) or not required_row_keys:
        errors.append(f"{schema_path}: typed readiness row schema must declare required keys")
        return errors
    required_row_key_set = {str(key) for key in required_row_keys}

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for typed_readiness.v1")
        return errors
    expected_rows = contract.get("expected_rows")
    if not isinstance(expected_rows, list) or not expected_rows:
        errors.append(f"{schema_path}: x-contract.expected_rows must be a non-empty list")
        return errors

    replacement_schema = (
        row_schema.get("properties", {})
        .get("replacement_flag", {})
    )
    expected_order = replacement_schema.get("enum", [])
    if not isinstance(expected_order, list) or not expected_order:
        errors.append(f"{schema_path}: typed readiness replacement_flag enum must be non-empty")
        expected_order = []

    expected_replacements = [
        row.get("replacement_flag", "")
        for row in expected_rows
        if isinstance(row, dict)
    ]
    if expected_order and expected_replacements != [str(value) for value in expected_order]:
        errors.append(f"{schema_path}: x-contract.expected_rows must follow replacement_flag enum order")
    if len(expected_replacements) != len(set(expected_replacements)):
        errors.append(f"{schema_path}: x-contract.expected_rows replacement_flag values must be unique")

    expected_by_replacement: dict[str, dict[str, object]] = {}
    for index, row in enumerate(expected_rows, start=1):
        if not isinstance(row, dict):
            errors.append(f"{schema_path}: x-contract.expected_rows[{index}] must be an object")
            continue
        missing = required_row_key_set - set(row)
        if missing:
            errors.append(
                f"{schema_path}: x-contract.expected_rows[{index}] missing {', '.join(sorted(missing))}"
            )
        extra = set(row) - required_row_key_set
        if extra:
            errors.append(
                f"{schema_path}: x-contract.expected_rows[{index}] has unexpected keys {', '.join(sorted(extra))}"
            )
        replacement = row.get("replacement_flag", "")
        if isinstance(replacement, str) and replacement:
            expected_by_replacement[replacement] = row

    rows = instance.get("rows", [])
    if not isinstance(rows, list):
        return errors
    instance_replacements = [
        row.get("replacement_flag", "")
        for row in rows
        if isinstance(row, dict)
    ]
    if expected_replacements and instance_replacements != expected_replacements:
        errors.append(f"{schema_path}: instance rows must follow x-contract.expected_rows")
    for index, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            continue
        replacement = row.get("replacement_flag", "")
        expected = expected_by_replacement.get(replacement)
        if expected is None:
            errors.append(
                f"{schema_path}: instance readiness[{index}] replacement_flag={replacement} missing from x-contract.expected_rows"
            )
            continue
        for field, expected_value in expected.items():
            if row.get(field) != expected_value:
                errors.append(
                    f"{schema_path}: instance readiness[{index}].{field} must match x-contract.expected_rows"
                )
    return errors


def validate_leakage_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "leakage_contract.v1":
        return errors

    stage_schema = (
        schema.get("properties", {})
        .get("stage_contracts", {})
        .get("items", {})
    )
    if not isinstance(stage_schema, dict):
        errors.append(f"{schema_path}: leakage stage_contracts schema must be an object")
        return errors
    required_stage_keys = stage_schema.get("required", [])
    if not isinstance(required_stage_keys, list) or not required_stage_keys:
        errors.append(f"{schema_path}: leakage stage_contracts schema must declare required keys")
        return errors
    optional_stage_keys = set(stage_schema.get("properties", {})) - set(required_stage_keys)
    allowed_stage_keys = {str(key) for key in required_stage_keys} | {
        str(key) for key in optional_stage_keys
    }

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for leakage_contract.v1")
        return errors
    expected_stages = contract.get("expected_stage_contracts")
    if not isinstance(expected_stages, list) or not expected_stages:
        errors.append(f"{schema_path}: x-contract.expected_stage_contracts must be a non-empty list")
        return errors

    stage_id_schema = (
        stage_schema.get("properties", {})
        .get("stage_id", {})
    )
    expected_order = stage_id_schema.get("enum", [])
    if not isinstance(expected_order, list) or not expected_order:
        errors.append(f"{schema_path}: leakage stage_id enum must be non-empty")
        expected_order = []

    expected_stage_ids = [
        row.get("stage_id", "")
        for row in expected_stages
        if isinstance(row, dict)
    ]
    if expected_order and expected_stage_ids != [str(value) for value in expected_order]:
        errors.append(f"{schema_path}: x-contract.expected_stage_contracts must follow stage_id enum order")
    if len(expected_stage_ids) != len(set(expected_stage_ids)):
        errors.append(f"{schema_path}: x-contract.expected_stage_contracts stage_id values must be unique")

    expected_by_stage: dict[str, dict[str, object]] = {}
    for index, row in enumerate(expected_stages, start=1):
        if not isinstance(row, dict):
            errors.append(f"{schema_path}: x-contract.expected_stage_contracts[{index}] must be an object")
            continue
        missing = set(required_stage_keys) - set(row)
        if missing:
            errors.append(
                f"{schema_path}: x-contract.expected_stage_contracts[{index}] missing {', '.join(sorted(missing))}"
            )
        extra = set(row) - allowed_stage_keys
        if extra:
            errors.append(
                f"{schema_path}: x-contract.expected_stage_contracts[{index}] has unexpected keys {', '.join(sorted(extra))}"
            )
        stage_id = row.get("stage_id", "")
        if isinstance(stage_id, str) and stage_id:
            expected_by_stage[stage_id] = row

    stages = instance.get("stage_contracts", [])
    if not isinstance(stages, list):
        return errors
    instance_stage_ids = [
        row.get("stage_id", "")
        for row in stages
        if isinstance(row, dict)
    ]
    if expected_stage_ids and instance_stage_ids != expected_stage_ids:
        errors.append(f"{schema_path}: instance stage_contracts must follow x-contract.expected_stage_contracts")
    for index, row in enumerate(stages, start=1):
        if not isinstance(row, dict):
            continue
        stage_id = row.get("stage_id", "")
        expected = expected_by_stage.get(stage_id)
        if expected is None:
            errors.append(
                f"{schema_path}: instance stage_contract[{index}] stage_id={stage_id} missing from x-contract.expected_stage_contracts"
            )
            continue
        if row != expected:
            errors.append(
                f"{schema_path}: instance stage_contract[{index}] must match x-contract.expected_stage_contracts"
            )
    return errors


def _v50_static_artifact_projection(row: dict[str, object]) -> dict[str, object]:
    return {
        "artifact_id": row.get("artifact_id"),
        "artifact_kind": row.get("artifact_kind"),
        "required_columns": row.get("required_columns"),
        "min_rows": row.get("min_rows"),
        "sha256_manifest_required": row.get("sha256_manifest_required"),
        "required_for_merge": row.get("required_for_merge"),
    }


def validate_v50_auditor_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "v50_auditor_correctness.v1":
        return errors

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for v50_auditor_correctness.v1")
        return errors

    expected_policy = contract.get("expected_policy_static")
    expected_artifacts = contract.get("expected_required_artifacts")
    expected_summary = contract.get("expected_summary_when_supplied")
    expected_decisions = contract.get("expected_decision_gates_when_supplied")
    if not isinstance(expected_policy, dict) or not expected_policy:
        errors.append(f"{schema_path}: x-contract.expected_policy_static must be a non-empty object")
    if not isinstance(expected_artifacts, list) or not expected_artifacts:
        errors.append(f"{schema_path}: x-contract.expected_required_artifacts must be a non-empty list")
    if not isinstance(expected_summary, dict) or not expected_summary:
        errors.append(f"{schema_path}: x-contract.expected_summary_when_supplied must be a non-empty object")
    if not isinstance(expected_decisions, dict) or not expected_decisions:
        errors.append(f"{schema_path}: x-contract.expected_decision_gates_when_supplied must be a non-empty object")
    if errors:
        return errors

    policy = instance.get("policy", {})
    if not isinstance(policy, dict):
        return errors
    for field, expected_value in expected_policy.items():
        if policy.get(field) != expected_value:
            errors.append(f"{schema_path}: instance policy.{field} must match x-contract.expected_policy_static")

    artifact_ids = [
        row.get("artifact_id", "")
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{schema_path}: x-contract.expected_required_artifacts artifact_id values must be unique")

    required_artifacts = instance.get("required_artifacts", [])
    if not isinstance(required_artifacts, list):
        return errors
    observed_static = [
        _v50_static_artifact_projection(row)
        for row in required_artifacts
        if isinstance(row, dict)
    ]
    expected_static = [
        _v50_static_artifact_projection(row)
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if observed_static != expected_static:
        errors.append(f"{schema_path}: instance required_artifacts must match x-contract.expected_required_artifacts")

    pass_gates = expected_decisions.get("pass", [])
    blocked_gates = expected_decisions.get("blocked", {})
    if not isinstance(pass_gates, list) or len(pass_gates) != len(set(pass_gates)):
        errors.append(f"{schema_path}: x-contract.expected_decision_gates_when_supplied.pass must be a unique list")
    if not isinstance(blocked_gates, dict) or not blocked_gates:
        errors.append(f"{schema_path}: x-contract.expected_decision_gates_when_supplied.blocked must be a non-empty object")
    return errors


def _v54_static_artifact_projection(row: dict[str, object]) -> dict[str, object]:
    return {
        "artifact_id": row.get("artifact_id"),
        "artifact_kind": row.get("artifact_kind"),
        "required_columns": row.get("required_columns"),
        "min_rows": row.get("min_rows"),
        "pm_recommended_output": row.get("pm_recommended_output"),
        "raw_prompt_context_forbidden": row.get("raw_prompt_context_forbidden"),
        "model_visible_leakage_forbidden": row.get("model_visible_leakage_forbidden"),
    }


def validate_v54_grounded_generation_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "v54_grounded_generation.v1":
        return errors

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for v54_grounded_generation.v1")
        return errors

    expected_policy = contract.get("expected_policy_static")
    expected_artifacts = contract.get("expected_required_artifacts")
    expected_summary = contract.get("expected_summary_when_supplied")
    if not isinstance(expected_policy, dict) or not expected_policy:
        errors.append(f"{schema_path}: x-contract.expected_policy_static must be a non-empty object")
    if not isinstance(expected_artifacts, list) or not expected_artifacts:
        errors.append(f"{schema_path}: x-contract.expected_required_artifacts must be a non-empty list")
    if not isinstance(expected_summary, dict) or not expected_summary:
        errors.append(f"{schema_path}: x-contract.expected_summary_when_supplied must be a non-empty object")
    if errors:
        return errors

    policy = instance.get("policy", {})
    if not isinstance(policy, dict):
        return errors
    for field, expected_value in expected_policy.items():
        if policy.get(field) != expected_value:
            errors.append(f"{schema_path}: instance policy.{field} must match x-contract.expected_policy_static")

    artifact_ids = [
        row.get("artifact_id", "")
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{schema_path}: x-contract.expected_required_artifacts artifact_id values must be unique")

    required_artifacts = instance.get("required_artifacts", [])
    if not isinstance(required_artifacts, list):
        return errors
    observed_static = [
        _v54_static_artifact_projection(row)
        for row in required_artifacts
        if isinstance(row, dict)
    ]
    expected_static = [
        _v54_static_artifact_projection(row)
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if observed_static != expected_static:
        errors.append(f"{schema_path}: instance required_artifacts must match x-contract.expected_required_artifacts")
    return errors


def validate_v53_source_benchmark_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "v53_source_benchmark.v1":
        return errors

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for v53_source_benchmark.v1")
        return errors

    expected_policy = contract.get("expected_policy_static")
    expected_requirements = contract.get("expected_requirement_ids")
    expected_summary_checks = contract.get("expected_summary_checks")
    default_summary_paths = contract.get("default_summary_paths")
    expected_v1_exit = contract.get("expected_v1_exit_criterion_ids")
    if not isinstance(expected_policy, dict) or not expected_policy:
        errors.append(f"{schema_path}: x-contract.expected_policy_static must be a non-empty object")
    if not isinstance(expected_requirements, list) or not expected_requirements:
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids must be a non-empty list")
    if not isinstance(expected_summary_checks, dict) or not expected_summary_checks:
        errors.append(f"{schema_path}: x-contract.expected_summary_checks must be a non-empty object")
    if not isinstance(default_summary_paths, dict) or not default_summary_paths:
        errors.append(f"{schema_path}: x-contract.default_summary_paths must be a non-empty object")
    if not isinstance(expected_v1_exit, list) or not expected_v1_exit:
        errors.append(f"{schema_path}: x-contract.expected_v1_exit_criterion_ids must be a non-empty list")
    if errors:
        return errors

    summary_id_enum = (
        schema.get("properties", {})
        .get("requirements", {})
        .get("items", {})
        .get("properties", {})
        .get("summary_checks", {})
        .get("items", {})
        .get("properties", {})
        .get("summary_id", {})
        .get("enum", [])
    )
    if not isinstance(summary_id_enum, list) or any(not isinstance(summary_id, str) for summary_id in summary_id_enum):
        errors.append(f"{schema_path}: schema summary_id enum must be a string list")

    policy = instance.get("policy", {})
    if isinstance(policy, dict):
        for field, expected_value in expected_policy.items():
            if policy.get(field) != expected_value:
                errors.append(f"{schema_path}: instance policy.{field} must match x-contract.expected_policy_static")

    requirements = instance.get("requirements", [])
    if not isinstance(requirements, list):
        return errors
    requirement_ids = [
        row.get("requirement_id", "")
        for row in requirements
        if isinstance(row, dict)
    ]
    if requirement_ids != expected_requirements:
        errors.append(f"{schema_path}: instance requirements must follow x-contract.expected_requirement_ids")
    if any(not isinstance(requirement_id, str) for requirement_id in expected_requirements):
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids values must be strings")
    if len(expected_requirements) != len(set(expected_requirements)):
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids values must be unique")
    if set(expected_summary_checks) != set(expected_requirements):
        errors.append(f"{schema_path}: x-contract.expected_summary_checks keys must match expected_requirement_ids")
    if set(default_summary_paths) != set(summary_id_enum):
        errors.append(f"{schema_path}: x-contract.default_summary_paths keys must match summary_id enum")
    if any(not isinstance(summary_path, str) or not summary_path for summary_path in default_summary_paths.values()):
        errors.append(f"{schema_path}: x-contract.default_summary_paths values must be non-empty strings")
    if any(not isinstance(criterion_id, str) or not criterion_id for criterion_id in expected_v1_exit):
        errors.append(f"{schema_path}: x-contract.expected_v1_exit_criterion_ids values must be non-empty strings")
    if len(expected_v1_exit) != len(set(expected_v1_exit)):
        errors.append(f"{schema_path}: x-contract.expected_v1_exit_criterion_ids values must be unique")

    for row in requirements:
        if not isinstance(row, dict):
            continue
        requirement_id = row.get("requirement_id", "")
        expected_checks = expected_summary_checks.get(requirement_id)
        if not isinstance(expected_checks, list):
            errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} must be a list")
            continue
        for check in expected_checks:
            if not isinstance(check, dict):
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} values must be objects")
                continue
            if set(check) != {"summary_id", "field", "expected"}:
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} entries must have summary_id, field, expected")
            if check.get("summary_id") not in default_summary_paths:
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} summary_id must have a default_summary_paths entry")
            if any(not isinstance(check.get(key), str) or not check.get(key) for key in ("summary_id", "field", "expected")):
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} entries must use non-empty string values")
        if expected_checks is None:
            errors.append(f"{schema_path}: x-contract.expected_summary_checks missing {requirement_id}")
            continue
        if row.get("summary_checks") != expected_checks:
            errors.append(f"{schema_path}: instance requirement {requirement_id}.summary_checks must match x-contract.expected_summary_checks")
    return errors


def validate_review_return_workflow_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "review_return_workflow.v1":
        return errors

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for review_return_workflow.v1")
        return errors

    expected_policy = contract.get("expected_policy_static")
    expected_requirements = contract.get("expected_requirement_ids")
    expected_summary_checks = contract.get("expected_summary_checks")
    if not isinstance(expected_policy, dict) or not expected_policy:
        errors.append(f"{schema_path}: x-contract.expected_policy_static must be a non-empty object")
    if not isinstance(expected_requirements, list) or not expected_requirements:
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids must be a non-empty list")
    if not isinstance(expected_summary_checks, dict) or not expected_summary_checks:
        errors.append(f"{schema_path}: x-contract.expected_summary_checks must be a non-empty object")
    if errors:
        return errors

    summary_id_enum = (
        schema.get("properties", {})
        .get("requirements", {})
        .get("items", {})
        .get("properties", {})
        .get("summary_checks", {})
        .get("items", {})
        .get("properties", {})
        .get("summary_id", {})
        .get("enum", [])
    )
    if not isinstance(summary_id_enum, list) or any(not isinstance(summary_id, str) for summary_id in summary_id_enum):
        errors.append(f"{schema_path}: schema summary_id enum must be a string list")

    policy = instance.get("policy", {})
    if isinstance(policy, dict):
        for field, expected_value in expected_policy.items():
            if policy.get(field) != expected_value:
                errors.append(f"{schema_path}: instance policy.{field} must match x-contract.expected_policy_static")

    requirements = instance.get("requirements", [])
    if not isinstance(requirements, list):
        return errors
    requirement_ids = [
        row.get("requirement_id", "")
        for row in requirements
        if isinstance(row, dict)
    ]
    if requirement_ids != expected_requirements:
        errors.append(f"{schema_path}: instance requirements must follow x-contract.expected_requirement_ids")
    if any(not isinstance(requirement_id, str) for requirement_id in expected_requirements):
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids values must be strings")
    if len(expected_requirements) != len(set(expected_requirements)):
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids values must be unique")
    if set(expected_summary_checks) != set(expected_requirements):
        errors.append(f"{schema_path}: x-contract.expected_summary_checks keys must match expected_requirement_ids")

    for row in requirements:
        if not isinstance(row, dict):
            continue
        requirement_id = row.get("requirement_id", "")
        expected_checks = expected_summary_checks.get(requirement_id)
        if not isinstance(expected_checks, list):
            errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} must be a list")
            continue
        for check in expected_checks:
            if not isinstance(check, dict):
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} values must be objects")
                continue
            if set(check) != {"summary_id", "field", "expected"}:
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} entries must have summary_id, field, expected")
            if check.get("summary_id") not in summary_id_enum:
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} summary_id must be in summary_id enum")
            if any(not isinstance(check.get(key), str) or not check.get(key) for key in ("summary_id", "field", "expected")):
                errors.append(f"{schema_path}: x-contract.expected_summary_checks.{requirement_id} entries must use non-empty string values")
        if expected_checks is None:
            errors.append(f"{schema_path}: x-contract.expected_summary_checks missing {requirement_id}")
            continue
        if row.get("summary_checks") != expected_checks:
            errors.append(f"{schema_path}: instance requirement {requirement_id}.summary_checks must match x-contract.expected_summary_checks")
    return errors


def _v58_static_artifact_projection(row: dict[str, object]) -> dict[str, object]:
    projected = {
        "artifact_id": row.get("artifact_id"),
        "artifact_kind": row.get("artifact_kind"),
        "validation_command": row.get("validation_command"),
        "required_columns": row.get("required_columns"),
        "min_rows": row.get("min_rows"),
    }
    if "per_system_min_rows" in row:
        projected["per_system_min_rows"] = row.get("per_system_min_rows")
    return projected


def validate_v58_blind_eval_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "v58_blind_eval.v1":
        return errors

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for v58_blind_eval.v1")
        return errors

    expected_policy = contract.get("expected_policy_static")
    expected_systems = contract.get("expected_required_systems")
    expected_requirements = contract.get("expected_requirement_ids")
    expected_artifacts = contract.get("expected_required_artifacts")
    if not isinstance(expected_policy, dict) or not expected_policy:
        errors.append(f"{schema_path}: x-contract.expected_policy_static must be a non-empty object")
    if not isinstance(expected_systems, list) or not expected_systems:
        errors.append(f"{schema_path}: x-contract.expected_required_systems must be a non-empty list")
    if not isinstance(expected_requirements, list) or not expected_requirements:
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids must be a non-empty list")
    if not isinstance(expected_artifacts, list) or not expected_artifacts:
        errors.append(f"{schema_path}: x-contract.expected_required_artifacts must be a non-empty list")
    if errors:
        return errors

    policy = instance.get("policy", {})
    if isinstance(policy, dict):
        for field, expected_value in expected_policy.items():
            if policy.get(field) != expected_value:
                errors.append(f"{schema_path}: instance policy.{field} must match x-contract.expected_policy_static")

    if instance.get("required_systems") != expected_systems:
        errors.append(f"{schema_path}: instance required_systems must match x-contract.expected_required_systems")

    requirement_ids = [
        row.get("requirement_id", "")
        for row in instance.get("requirements", [])
        if isinstance(row, dict)
    ]
    if requirement_ids != expected_requirements:
        errors.append(f"{schema_path}: instance requirements must follow x-contract.expected_requirement_ids")
    if len(expected_requirements) != len(set(expected_requirements)):
        errors.append(f"{schema_path}: x-contract.expected_requirement_ids values must be unique")

    artifact_ids = [
        row.get("artifact_id", "")
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{schema_path}: x-contract.expected_required_artifacts artifact_id values must be unique")

    required_artifacts = instance.get("required_artifacts", [])
    if not isinstance(required_artifacts, list):
        return errors
    observed_static = [
        _v58_static_artifact_projection(row)
        for row in required_artifacts
        if isinstance(row, dict)
    ]
    expected_static = [
        _v58_static_artifact_projection(row)
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if observed_static != expected_static:
        errors.append(f"{schema_path}: instance required_artifacts must match x-contract.expected_required_artifacts")
    return errors


def validate_v56_replay_contract_metadata(
    schema_path: Path,
    schema: object,
    instance: object,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(schema, dict) or not isinstance(instance, dict):
        return errors
    if instance.get("schema_version") != "v56_replay_contract.v1":
        return errors

    contract = schema.get("x-contract")
    if not isinstance(contract, dict):
        errors.append(f"{schema_path}: x-contract must be an object for v56_replay_contract.v1")
        return errors
    expected_policy = contract.get("expected_policy")
    expected_artifacts = contract.get("expected_replay_artifacts")
    expected_seed = contract.get("expected_seed_dependency")
    if not isinstance(expected_policy, dict) or not expected_policy:
        errors.append(f"{schema_path}: x-contract.expected_policy must be a non-empty object")
    if not isinstance(expected_artifacts, list) or not expected_artifacts:
        errors.append(f"{schema_path}: x-contract.expected_replay_artifacts must be a non-empty list")
    if not isinstance(expected_seed, dict) or not expected_seed:
        errors.append(f"{schema_path}: x-contract.expected_seed_dependency must be a non-empty object")
    if errors:
        return errors

    if instance.get("policy") != expected_policy:
        errors.append(f"{schema_path}: instance policy must match x-contract.expected_policy")
    if instance.get("replay_artifacts") != expected_artifacts:
        errors.append(f"{schema_path}: instance replay_artifacts must match x-contract.expected_replay_artifacts")
    if instance.get("seed_dependency") != expected_seed:
        errors.append(f"{schema_path}: instance seed_dependency must match x-contract.expected_seed_dependency")

    artifact_ids = [
        row.get("artifact_id", "")
        for row in expected_artifacts
        if isinstance(row, dict)
    ]
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{schema_path}: x-contract.expected_replay_artifacts artifact_id values must be unique")
    seed_paths = expected_seed.get("missing_seed_artifact_paths", [])
    if not isinstance(seed_paths, list) or len(seed_paths) != len(set(seed_paths)):
        errors.append(f"{schema_path}: x-contract.expected_seed_dependency.missing_seed_artifact_paths must be a unique list")
    return errors


def tracked_source_json(root: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "*.json", ":(exclude)results/**", ":(exclude)build/**"],
            cwd=root,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except (OSError, subprocess.CalledProcessError):
        return []
    return sorted(line for line in result.stdout.splitlines() if line)


def validate_registry_coverage(root: Path, registry: dict[str, list[str]]) -> list[str]:
    registered_instances = {
        instance
        for instances in registry.values()
        for instance in instances
    }
    errors: list[str] = []
    for rel_path in tracked_source_json(root):
        if rel_path.startswith("schemas/"):
            continue
        if rel_path in NON_CONTRACT_JSON_ALLOWLIST:
            continue
        if rel_path not in registered_instances:
            errors.append(f"{rel_path}: tracked contract JSON is not registered for schema validation")
    return errors


def validate_instance(schema_path: Path, instance_path: Path) -> list[str]:
    errors: list[str] = []
    schema = load_json(schema_path)
    instance = load_json(instance_path)
    validator = jsonschema.Draft202012Validator(schema)
    for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
        location = ".".join(str(part) for part in error.path) or "<root>"
        errors.append(f"{instance_path}: schema {schema_path.name}: {location}: {error.message}")
    errors.extend(validate_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_typed_readiness_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_leakage_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_v50_auditor_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_v53_source_benchmark_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_review_return_workflow_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_v54_grounded_generation_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_v58_blind_eval_contract_metadata(schema_path, schema, instance))
    errors.extend(validate_v56_replay_contract_metadata(schema_path, schema, instance))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="repository root; defaults to the parent of tools/",
    )
    parser.add_argument(
        "--skip-missing",
        action="store_true",
        help="skip missing registered instances instead of failing",
    )
    parser.add_argument(
        "--schema-instance",
        nargs=2,
        action="append",
        metavar=("SCHEMA", "INSTANCE"),
        help="validate one explicit schema/instance pair instead of the default registry",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    errors: list[str] = []
    registry = (
        {schema: [instance] for schema, instance in args.schema_instance}
        if args.schema_instance
        else SCHEMA_INSTANCE_REGISTRY
    )
    if not args.schema_instance:
        errors.extend(validate_registry_coverage(root, registry))
    for schema_rel, instance_rels in registry.items():
        schema_path = root / schema_rel
        if not schema_path.is_file():
            errors.append(f"{schema_path}: registered schema is missing")
            continue
        errors.extend(validate_schema(schema_path))
        for instance_rel in instance_rels:
            instance_path = root / instance_rel
            if not instance_path.is_file():
                if not args.skip_missing:
                    errors.append(f"{instance_path}: registered JSON instance is missing")
                continue
            errors.extend(validate_instance(schema_path, instance_path))

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("json schema validation ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
