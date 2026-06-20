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
