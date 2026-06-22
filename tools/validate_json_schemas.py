#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def validate_value(schema: dict, value, path: str, errors: list[str]) -> None:
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: expected const {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: value not in enum")
    expected_type = schema.get("type")
    if expected_type == "object":
        if not isinstance(value, dict):
            errors.append(f"{path}: expected object")
            return
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}.{key}: missing required property")
        if schema.get("additionalProperties") is False:
            allowed = set(schema.get("properties", {}))
            for key in value:
                if key not in allowed:
                    errors.append(f"{path}.{key}: unexpected property")
        elif isinstance(schema.get("additionalProperties"), dict):
            allowed = set(schema.get("properties", {}))
            additional_schema = schema["additionalProperties"]
            for key, child_value in value.items():
                if key not in allowed:
                    validate_value(additional_schema, child_value, f"{path}.{key}", errors)
        if "minProperties" in schema and len(value) < int(schema["minProperties"]):
            errors.append(f"{path}: object has fewer properties than minProperties")
        if "maxProperties" in schema and len(value) > int(schema["maxProperties"]):
            errors.append(f"{path}: object has more properties than maxProperties")
        for key, child in schema.get("properties", {}).items():
            if key in value:
                validate_value(child, value[key], f"{path}.{key}", errors)
    elif expected_type == "string":
        if not isinstance(value, str):
            errors.append(f"{path}: expected string")
            return
        if len(value) < int(schema.get("minLength", 0)):
            errors.append(f"{path}: string shorter than minLength")
        if "pattern" in schema and not re.match(schema["pattern"], value):
            errors.append(f"{path}: string does not match pattern")
    elif expected_type == "integer":
        if not isinstance(value, int) or isinstance(value, bool):
            errors.append(f"{path}: expected integer")
            return
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: integer below minimum")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: integer above maximum")
    elif expected_type == "array":
        if not isinstance(value, list):
            errors.append(f"{path}: expected array")
            return
        if "minItems" in schema and len(value) < int(schema["minItems"]):
            errors.append(f"{path}: array shorter than minItems")
        if "maxItems" in schema and len(value) > int(schema["maxItems"]):
            errors.append(f"{path}: array longer than maxItems")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                validate_value(item_schema, item, f"{path}[{index}]", errors)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Small JSON schema checker for repository smoke tests.")
    parser.add_argument("--schema-instance", nargs=2, metavar=("SCHEMA", "INSTANCE"))
    args = parser.parse_args(argv)
    if args.schema_instance:
        schema_path = Path(args.schema_instance[0])
        instance_path = Path(args.schema_instance[1])
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        instance = json.loads(instance_path.read_text(encoding="utf-8"))
        errors: list[str] = []
        validate_value(schema, instance, "$", errors)
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        print("schema instance ok")
        return 0
    for schema_path in sorted(Path("schemas").glob("*.schema.json")):
        json.loads(schema_path.read_text(encoding="utf-8"))
    print("json schema files ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
