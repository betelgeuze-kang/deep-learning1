#!/usr/bin/env python3
"""Validate repository JSON contracts against their JSON Schemas."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError as exc:  # pragma: no cover - exercised only on missing env deps.
    raise SystemExit("jsonschema is required for schema validation") from exc


REPO_ROOT = Path(__file__).resolve().parents[1]

SCHEMA_INSTANCE_REGISTRY = {
    "schemas/pr_split.schema.json": ["pr_slices/pr2.json"],
    "schemas/typed_readiness.schema.json": ["readiness/typed_ready.json"],
    "schemas/leakage_contract.schema.json": ["leakage/retrieval_model_visible.json"],
    "schemas/baseline_admission.schema.json": ["baselines/de_30b70b_real.json"],
    "schemas/v52_adapter_guard.schema.json": ["baselines/v52_adapter_guard.json"],
    "schemas/v50_auditor_correctness.schema.json": ["audits/v50_public_repo_auditor_correctness.json"],
    "schemas/v53_source_benchmark.schema.json": ["benchmarks/v53_source_bound_freeze.json"],
    "schemas/v54_grounded_generation.schema.json": ["v54/grounded_generation_contract.json"],
    "schemas/v58_blind_eval.schema.json": ["v58/blind_eval_real.json"],
    "schemas/review_return_workflow.schema.json": ["operations/review_return_workflow.json"],
    "schemas/v61_one_token_path.schema.json": ["v61/one_token_path.json"],
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


def validate_instance(schema_path: Path, instance_path: Path) -> list[str]:
    errors: list[str] = []
    schema = load_json(schema_path)
    instance = load_json(instance_path)
    validator = jsonschema.Draft202012Validator(schema)
    for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
        location = ".".join(str(part) for part in error.path) or "<root>"
        errors.append(f"{instance_path}: schema {schema_path.name}: {location}: {error.message}")
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
