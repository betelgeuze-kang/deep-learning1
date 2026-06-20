#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-schema-validation-negative.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

expect_fail_with() {
  local expected="$1"
  shift
  local out="$TMP_DIR/expect_fail.out"
  if "$@" >"$out" 2>&1; then
    echo "schema negative control unexpectedly passed: $*" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$out" >/dev/null; then
    echo "schema negative control failed for the wrong reason: $*" >&2
    echo "expected diagnostic: $expected" >&2
    echo "actual output:" >&2
    cat "$out" >&2
    exit 1
  fi
}

"$ROOT_DIR/tools/validate_json_schemas.py" >/dev/null

if ! grep -F "git ls-files '*.json' ':(exclude)results/**' ':(exclude)build/**'" "$ROOT_DIR/scripts/ai-verify.sh" >/dev/null; then
  echo "ai-verify.sh must parse all tracked source JSON dynamically" >&2
  exit 1
fi

python3 - "$ROOT_DIR" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("verify_artifact", root / "tools" / "verify_artifact.py")
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
schema = json.loads((root / "schemas" / "v61_one_token_path.schema.json").read_text(encoding="utf-8"))
expected_policy = set(schema["properties"]["policy"]["required"])
expected_milestone = set(schema["properties"]["milestones"]["items"]["required"])
expected_artifact = set(schema["properties"]["required_artifacts"]["items"]["required"])
if module.REQUIRED_V61_POLICY_KEYS != expected_policy:
    raise SystemExit("REQUIRED_V61_POLICY_KEYS must be derived from schema policy.required")
if module.REQUIRED_V61_MILESTONE_KEYS != expected_milestone:
    raise SystemExit("REQUIRED_V61_MILESTONE_KEYS must be derived from schema milestones.items.required")
if module.REQUIRED_V61_ARTIFACT_KEYS != expected_artifact:
    raise SystemExit("REQUIRED_V61_ARTIFACT_KEYS must be derived from schema required_artifacts.items.required")

checks = {
    "REQUIRED_STAGE_KEYS": ("pipeline.schema.json", ("properties", "stages", "items")),
    "REQUIRED_PR_SLICE_KEYS": ("pr_split.schema.json", ("properties", "slices", "items")),
    "REQUIRED_TYPED_READINESS_ROW_KEYS": ("typed_readiness.schema.json", ("properties", "rows", "items")),
    "REQUIRED_LEAKAGE_POLICY_KEYS": ("leakage_contract.schema.json", ("properties", "policy")),
    "REQUIRED_LEAKAGE_SURFACE_KEYS": ("leakage_contract.schema.json", ("properties", "forbidden_surfaces", "items")),
    "REQUIRED_LEAKAGE_STAGE_KEYS": ("leakage_contract.schema.json", ("properties", "stage_contracts", "items")),
    "REQUIRED_BASELINE_LEDGER_KEYS": ("baseline_admission.schema.json", ("properties", "required_pm_ledgers", "items")),
    "REQUIRED_BASELINE_SYSTEM_KEYS": ("baseline_admission.schema.json", ("properties", "systems", "items")),
    "REQUIRED_BASELINE_ARTIFACT_KEYS": ("baseline_admission.schema.json", ("properties", "required_artifacts", "items")),
    "REQUIRED_V52_ARTIFACT_KEYS": ("v52_adapter_guard.schema.json", ("properties", "required_artifacts", "items")),
    "REQUIRED_V52_REQUIREMENT_KEYS": ("v52_adapter_guard.schema.json", ("properties", "requirements", "items")),
    "REQUIRED_V50_POLICY_KEYS": ("v50_auditor_correctness.schema.json", ("properties", "policy")),
    "REQUIRED_V50_ARTIFACT_KEYS": ("v50_auditor_correctness.schema.json", ("properties", "required_artifacts", "items")),
    "REQUIRED_V50_REPLAY_COMMAND_KEYS": ("v50_auditor_correctness.schema.json", ("properties", "replay_commands")),
    "REQUIRED_V50_BOUNDARY_KEYS": ("v50_auditor_correctness.schema.json", ("properties", "claim_boundaries", "items")),
    "REQUIRED_V56_REPLAY_POLICY_KEYS": ("v56_replay.schema.json", ("properties", "policy")),
    "REQUIRED_V56_REPLAY_ARTIFACT_KEYS": ("v56_replay.schema.json", ("properties", "replay_artifacts", "items")),
    "REQUIRED_V56_SEED_DEPENDENCY_KEYS": ("v56_replay.schema.json", ("properties", "seed_dependency")),
    "REQUIRED_V54_ARTIFACT_KEYS": ("v54_grounded_generation.schema.json", ("properties", "required_artifacts", "items")),
    "REQUIRED_V53_REQUIREMENT_KEYS": ("v53_source_benchmark.schema.json", ("properties", "requirements", "items")),
    "REQUIRED_V58_REQUIREMENT_KEYS": ("v58_blind_eval.schema.json", ("properties", "requirements", "items")),
    "REQUIRED_V58_ARTIFACT_KEYS": ("v58_blind_eval.schema.json", ("properties", "required_artifacts", "items")),
    "REQUIRED_REVIEW_RETURN_REQUIREMENT_KEYS": ("review_return_workflow.schema.json", ("properties", "requirements", "items")),
}
for constant_name, (schema_name, path_parts) in checks.items():
    schema_node = json.loads((root / "schemas" / schema_name).read_text(encoding="utf-8"))
    for path_part in path_parts:
        schema_node = schema_node[path_part]
    expected = set(schema_node["required"])
    actual = getattr(module, constant_name)
    if actual != expected:
        raise SystemExit(f"{constant_name} must be derived from schema {'.'.join(path_parts)}.required")

enum_checks = {
    "EXPECTED_PR2_SLICE_ORDER": ("pr_split.schema.json", ("properties", "slices", "items", "properties", "slice_id")),
    "EXPECTED_TYPED_READINESS_ORDER": ("typed_readiness.schema.json", ("properties", "rows", "items", "properties", "replacement_flag")),
    "EXPECTED_LEAKAGE_GUARD_IDS": ("leakage_contract.schema.json", ("properties", "forbidden_surfaces", "items", "properties", "guard_id")),
    "EXPECTED_LEAKAGE_STAGE_ORDER": ("leakage_contract.schema.json", ("properties", "stage_contracts", "items", "properties", "stage_id")),
}
for constant_name, (schema_name, path_parts) in enum_checks.items():
    schema_node = json.loads((root / "schemas" / schema_name).read_text(encoding="utf-8"))
    for path_part in path_parts:
        schema_node = schema_node[path_part]
    expected = [str(value) for value in schema_node["enum"]]
    actual = getattr(module, constant_name)
    if actual != expected:
        raise SystemExit(f"{constant_name} must be derived from schema {'.'.join(path_parts)}.enum")

enum_set_checks = {
    "TYPED_READINESS_KEYS": ("typed_readiness.schema.json", ("properties", "policy", "properties", "typed_fields", "items")),
    "AMBIGUOUS_READY_FLAGS": ("typed_readiness.schema.json", ("properties", "policy", "properties", "ambiguous_ready_flags", "items")),
    "FORBIDDEN_MODEL_VISIBLE_FIELDS": ("leakage_contract.schema.json", ("properties", "forbidden_surfaces", "items", "properties", "field_names", "items")),
    "ALLOWED_MODEL_VISIBLE_FIELDS": ("leakage_contract.schema.json", ("properties", "policy", "properties", "allowed_model_visible_fields", "items")),
}
for constant_name, (schema_name, path_parts) in enum_set_checks.items():
    schema_node = json.loads((root / "schemas" / schema_name).read_text(encoding="utf-8"))
    for path_part in path_parts:
        schema_node = schema_node[path_part]
    expected = {str(value) for value in schema_node["enum"]}
    actual = getattr(module, constant_name)
    if actual != expected:
        raise SystemExit(f"{constant_name} must be derived from schema {'.'.join(path_parts)}.enum")

typed_schema = json.loads((root / "schemas" / "typed_readiness.schema.json").read_text(encoding="utf-8"))
expected_contracts = {
    row["replacement_flag"]: row
    for row in typed_schema["x-contract"]["expected_rows"]
}
if module.EXPECTED_TYPED_READINESS_CONTRACTS != expected_contracts:
    raise SystemExit("EXPECTED_TYPED_READINESS_CONTRACTS must be derived from schema x-contract.expected_rows")

leakage_schema = json.loads((root / "schemas" / "leakage_contract.schema.json").read_text(encoding="utf-8"))
expected_leakage_stages = {
    row["stage_id"]: row
    for row in leakage_schema["x-contract"]["expected_stage_contracts"]
}
if module.EXPECTED_LEAKAGE_STAGE_CONTRACTS != expected_leakage_stages:
    raise SystemExit("EXPECTED_LEAKAGE_STAGE_CONTRACTS must be derived from schema x-contract.expected_stage_contracts")
PY

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_missing_policy.json"
python3 - "$TMP_DIR/typed_missing_policy.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data.pop("policy")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "'policy' is a required property" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/typed_readiness.schema.json" "$TMP_DIR/typed_missing_policy.json"

cp "$ROOT_DIR/schemas/typed_readiness.schema.json" "$TMP_DIR/typed_schema_contract_drift.schema.json"
python3 - "$TMP_DIR/typed_schema_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_rows"]:
    if row["replacement_flag"] == "pm_foundation_contract_fixture_ready":
        row["evidence_path"] = "results/drifted.csv"
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance readiness[1].evidence_path must match x-contract.expected_rows" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/typed_schema_contract_drift.schema.json" "$ROOT_DIR/readiness/typed_ready.json"

cp "$ROOT_DIR/schemas/typed_readiness.schema.json" "$TMP_DIR/typed_schema_missing_contract.schema.json"
python3 - "$TMP_DIR/typed_schema_missing_contract.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data.pop("x-contract")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract must be an object for typed_readiness.v1" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/typed_schema_missing_contract.schema.json" "$ROOT_DIR/readiness/typed_ready.json"

cp "$ROOT_DIR/schemas/leakage_contract.schema.json" "$TMP_DIR/leakage_schema_stage_contract_drift.schema.json"
python3 - "$TMP_DIR/leakage_schema_stage_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_stage_contracts"]:
    if row["stage_id"] == "v54c-grounded-generation-guard":
        row["must_equal"]["raw_prompt_context_appended_rows"] = "1"
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance stage_contract[2] must match x-contract.expected_stage_contracts" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/leakage_schema_stage_contract_drift.schema.json" "$ROOT_DIR/leakage/retrieval_model_visible.json"

cp "$ROOT_DIR/schemas/leakage_contract.schema.json" "$TMP_DIR/leakage_schema_missing_contract.schema.json"
python3 - "$TMP_DIR/leakage_schema_missing_contract.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data.pop("x-contract")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract must be an object for leakage_contract.v1" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/leakage_schema_missing_contract.schema.json" "$ROOT_DIR/leakage/retrieval_model_visible.json"

cp "$ROOT_DIR/v61/one_token_path.json" "$TMP_DIR/v61_bad_policy_type.json"
python3 - "$TMP_DIR/v61_bad_policy_type.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["required_artifact_count"] = "10"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "'10' is not of type 'integer'" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/v61_one_token_path.schema.json" "$TMP_DIR/v61_bad_policy_type.json"

cp "$ROOT_DIR/schemas/v61_one_token_path.schema.json" "$TMP_DIR/v61_schema_contract_drift.schema.json"
python3 - "$TMP_DIR/v61_schema_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["artifact_contracts"]:
    if row["artifact_id"] == "one-token-logits-parity-rows":
        row["min_rows"] = 2
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifact one-token-logits-parity-rows.min_rows must match x-contract" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v61_schema_contract_drift.schema.json" "$ROOT_DIR/v61/one_token_path.json"

cp "$ROOT_DIR/schemas/v61_one_token_path.schema.json" "$TMP_DIR/v61_schema_column_contract_drift.schema.json"
python3 - "$TMP_DIR/v61_schema_column_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["artifact_contracts"]:
    if row["artifact_id"] == "one-token-logits-parity-rows":
        row["required_columns"] = [
            column
            for column in row["required_columns"]
            if column != "mean_abs_delta"
        ]
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifact one-token-logits-parity-rows.required_columns must match x-contract" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v61_schema_column_contract_drift.schema.json" "$ROOT_DIR/v61/one_token_path.json"

cp "$ROOT_DIR/schemas/v61_one_token_path.schema.json" "$TMP_DIR/v61_schema_value_check_bad_field.schema.json"
python3 - "$TMP_DIR/v61_schema_value_check_bad_field.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["artifact_value_checks"]["one-token-logits-parity-rows"] = {
    "missing_contract_column": "1"
}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.artifact_value_checks.one-token-logits-parity-rows.missing_contract_column must reference required_columns" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v61_schema_value_check_bad_field.schema.json" "$ROOT_DIR/v61/one_token_path.json"

cp "$ROOT_DIR/schemas/v61_one_token_path.schema.json" "$TMP_DIR/v61_schema_missing_value_checks.schema.json"
python3 - "$TMP_DIR/v61_schema_missing_value_checks.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"].pop("artifact_value_checks")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract missing artifact_value_checks" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v61_schema_missing_value_checks.schema.json" "$ROOT_DIR/v61/one_token_path.json"

cp "$ROOT_DIR/tools/validate_json_schemas.py" "$TMP_DIR/validate_json_schemas_missing_v56.py"
python3 - "$TMP_DIR/validate_json_schemas_missing_v56.py" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
line = '    "schemas/v56_replay.schema.json": ["v56/replay_contract.json"],\n'
if line not in text:
    raise SystemExit("v56 registry line not found")
path.write_text(text.replace(line, ""), encoding="utf-8")
PY
expect_fail_with \
  "v56/replay_contract.json: tracked contract JSON is not registered for schema validation" \
  python3 "$TMP_DIR/validate_json_schemas_missing_v56.py" --root "$ROOT_DIR"

cp "$ROOT_DIR/audits/v50_public_repo_auditor_correctness.json" "$TMP_DIR/v50_extra_policy.json"
python3 - "$TMP_DIR/v50_extra_policy.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["runner_declared_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "Additional properties are not allowed" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/v50_auditor_correctness.schema.json" "$TMP_DIR/v50_extra_policy.json"

echo "p0 schema validation negative controls passed"
