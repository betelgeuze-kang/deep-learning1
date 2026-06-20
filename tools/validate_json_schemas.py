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
