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

SCHEMA_ONLY_ROOT="$TMP_DIR/schema_only_root"
mkdir -p "$SCHEMA_ONLY_ROOT"
cp -a "$ROOT_DIR/schemas" "$SCHEMA_ONLY_ROOT/schemas"
python3 - "$SCHEMA_ONLY_ROOT/schemas/pipeline.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["properties"]["stages"]["items"]["required"] = "stage_id"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "invalid schema" \
  "$ROOT_DIR/tools/validate_json_schemas.py" --root "$SCHEMA_ONLY_ROOT" --skip-missing

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

pr_split_schema = json.loads((root / "schemas" / "pr_split.schema.json").read_text(encoding="utf-8"))
pr_split_contract = pr_split_schema["x-contract"]
pr_split_required_gates = set(
    pr_split_schema["properties"]["merge_gate_policy"]["properties"]["required_gates"]["items"]["enum"]
)
pr_split_tests_only_merge_conditions = set(
    pr_split_schema["properties"]["slices"]["items"]["properties"]["verification_commands"]["items"]["not"]["enum"]
)
pr_split_required_verification_terms = {
    slice_id: set(terms)
    for slice_id, terms in pr_split_contract["required_verification_terms_by_slice"].items()
}
if module.REQUIRED_PR_MERGE_GATES != pr_split_required_gates:
    raise SystemExit("REQUIRED_PR_MERGE_GATES must be derived from pr_split required_gates enum")
if module.TESTS_ONLY_MERGE_CONDITIONS != pr_split_tests_only_merge_conditions:
    raise SystemExit("TESTS_ONLY_MERGE_CONDITIONS must be derived from pr_split verification_commands.items.not.enum")
if module.REQUIRED_PR2_REWRITE_TERMS != set(pr_split_contract["required_rewrite_terms"]):
    raise SystemExit("REQUIRED_PR2_REWRITE_TERMS must be derived from pr_split x-contract.required_rewrite_terms")
if module.REQUIRED_PR2_SPLIT_PLAN_TERMS != set(pr_split_contract["required_split_plan_terms"]):
    raise SystemExit("REQUIRED_PR2_SPLIT_PLAN_TERMS must be derived from pr_split x-contract.required_split_plan_terms")
if module.REQUIRED_PR2_VERIFICATION_TERMS_BY_SLICE != pr_split_required_verification_terms:
    raise SystemExit(
        "REQUIRED_PR2_VERIFICATION_TERMS_BY_SLICE must be derived from "
        "pr_split x-contract.required_verification_terms_by_slice"
    )

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
leakage_stage_schema = leakage_schema["properties"]["stage_contracts"]["items"]
leakage_optional_stage_keys = set(leakage_stage_schema["properties"]) - set(leakage_stage_schema["required"])
expected_leakage_stages = {
    row["stage_id"]: row
    for row in leakage_schema["x-contract"]["expected_stage_contracts"]
}
if module.OPTIONAL_LEAKAGE_STAGE_KEYS != leakage_optional_stage_keys:
    raise SystemExit("OPTIONAL_LEAKAGE_STAGE_KEYS must be derived from schema stage_contracts.items.properties")
if module.EXPECTED_LEAKAGE_STAGE_CONTRACTS != expected_leakage_stages:
    raise SystemExit("EXPECTED_LEAKAGE_STAGE_CONTRACTS must be derived from schema x-contract.expected_stage_contracts")

baseline_schema = json.loads((root / "schemas" / "baseline_admission.schema.json").read_text(encoding="utf-8"))
baseline_contract = baseline_schema["x-contract"]
baseline_expected_artifact_columns = {
    row["artifact_id"]: set(row["required_columns"])
    for row in baseline_contract["expected_required_artifacts"]
}
baseline_expected_artifact_kinds = {
    row["artifact_id"]: row["artifact_kind"]
    for row in baseline_contract["expected_required_artifacts"]
}
baseline_expected_systems = {
    row["system_id"]: row
    for row in baseline_contract["expected_systems"]
}
baseline_expected_pm_ledgers_by_id = {
    row["ledger_id"]: row
    for row in baseline_contract["expected_pm_ledgers"]
}
if module.EXPECTED_DE_POLICY_STATIC != baseline_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_DE_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.REQUIRED_DE_REAL_EVIDENCE_FIELDS != set(baseline_contract["expected_required_real_evidence_fields"]):
    raise SystemExit("REQUIRED_DE_REAL_EVIDENCE_FIELDS must be derived from schema x-contract.expected_required_real_evidence_fields")
if module.EXPECTED_DE_PM_LEDGERS != baseline_contract["expected_pm_ledgers"]:
    raise SystemExit("EXPECTED_DE_PM_LEDGERS must be derived from schema x-contract.expected_pm_ledgers")
if module.EXPECTED_DE_PM_LEDGERS_BY_ID != baseline_expected_pm_ledgers_by_id:
    raise SystemExit("EXPECTED_DE_PM_LEDGERS_BY_ID must be derived from schema x-contract.expected_pm_ledgers")
if module.EXPECTED_DE_SYSTEMS != baseline_expected_systems:
    raise SystemExit("EXPECTED_DE_SYSTEMS must be derived from schema x-contract.expected_systems")
if module.EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS != baseline_expected_artifact_columns:
    raise SystemExit("EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_DE_REQUIRED_ARTIFACT_KINDS != baseline_expected_artifact_kinds:
    raise SystemExit("EXPECTED_DE_REQUIRED_ARTIFACT_KINDS must be derived from schema x-contract.expected_required_artifacts")
if module.DEFAULT_DE_MEASURED_REGISTRY_LEDGER != Path(baseline_expected_pm_ledgers_by_id["de-measured-registry-exclusion"]["path"]):
    raise SystemExit("DEFAULT_DE_MEASURED_REGISTRY_LEDGER must be derived from schema x-contract.expected_pm_ledgers")
if module.DEFAULT_DE_ACCEPTANCE_LEDGER != Path(baseline_expected_pm_ledgers_by_id["de-acceptance-evidence-blockers"]["path"]):
    raise SystemExit("DEFAULT_DE_ACCEPTANCE_LEDGER must be derived from schema x-contract.expected_pm_ledgers")

v52_schema = json.loads((root / "schemas" / "v52_adapter_guard.schema.json").read_text(encoding="utf-8"))
v52_contract = v52_schema["x-contract"]
v52_expected_artifacts_by_id = {
    row["artifact_id"]: row
    for row in v52_contract["expected_required_artifacts"]
}
v52_expected_summary_checks = {
    requirement_id: [
        (check["summary_id"], check["field"], check["expected"])
        for check in checks
    ]
    for requirement_id, checks in v52_contract["expected_summary_checks"].items()
}
if module.EXPECTED_V52_POLICY_STATIC != v52_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_V52_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.EXPECTED_V52_ARTIFACTS != v52_contract["expected_required_artifacts"]:
    raise SystemExit("EXPECTED_V52_ARTIFACTS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_ARTIFACTS_BY_ID != v52_expected_artifacts_by_id:
    raise SystemExit("EXPECTED_V52_ARTIFACTS_BY_ID must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_C_ARTIFACT_IDS != [row["artifact_id"] for row in v52_contract["expected_required_artifacts"]]:
    raise SystemExit("EXPECTED_V52_C_ARTIFACT_IDS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_C_ARTIFACT_COLUMNS != {row["artifact_id"]: row["required_columns"] for row in v52_contract["expected_required_artifacts"]}:
    raise SystemExit("EXPECTED_V52_C_ARTIFACT_COLUMNS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_C_MIN_ROWS != {row["artifact_id"]: row["min_rows"] for row in v52_contract["expected_required_artifacts"]}:
    raise SystemExit("EXPECTED_V52_C_MIN_ROWS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_ARTIFACT_KINDS != {row["artifact_id"]: row["artifact_kind"] for row in v52_contract["expected_required_artifacts"]}:
    raise SystemExit("EXPECTED_V52_ARTIFACT_KINDS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_REQUIRED_FOR_C_PACKET != {row["artifact_id"]: row["required_for_c_packet"] for row in v52_contract["expected_required_artifacts"]}:
    raise SystemExit("EXPECTED_V52_REQUIRED_FOR_C_PACKET must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V52_REQUIREMENT_IDS != v52_contract["expected_requirement_ids"]:
    raise SystemExit("EXPECTED_V52_REQUIREMENT_IDS must be derived from schema x-contract.expected_requirement_ids")
if module.EXPECTED_V52_SUMMARY_CHECKS != v52_expected_summary_checks:
    raise SystemExit("EXPECTED_V52_SUMMARY_CHECKS must be derived from schema x-contract.expected_summary_checks")

v50_schema = json.loads((root / "schemas" / "v50_auditor_correctness.schema.json").read_text(encoding="utf-8"))
v50_contract = v50_schema["x-contract"]
if module.EXPECTED_V50_POLICY_STATIC != v50_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_V50_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.EXPECTED_V50_ARTIFACTS != v50_contract["expected_required_artifacts"]:
    raise SystemExit("EXPECTED_V50_ARTIFACTS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V50_SUMMARY != v50_contract["expected_summary_when_supplied"]:
    raise SystemExit("EXPECTED_V50_SUMMARY must be derived from schema x-contract.expected_summary_when_supplied")
if module.EXPECTED_V50_DECISION_GATES != v50_contract["expected_decision_gates_when_supplied"]:
    raise SystemExit("EXPECTED_V50_DECISION_GATES must be derived from schema x-contract.expected_decision_gates_when_supplied")

v53_schema = json.loads((root / "schemas" / "v53_source_benchmark.schema.json").read_text(encoding="utf-8"))
v53_contract = v53_schema["x-contract"]
v53_expected_summary_checks = {
    requirement_id: [
        (check["summary_id"], check["field"], check["expected"])
        for check in checks
    ]
    for requirement_id, checks in v53_contract["expected_summary_checks"].items()
}
v53_default_summary_paths = {
    summary_id: Path(summary_path)
    for summary_id, summary_path in v53_contract["default_summary_paths"].items()
}
if module.EXPECTED_V53_POLICY_STATIC != v53_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_V53_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.EXPECTED_V53_REQUIREMENT_IDS != v53_contract["expected_requirement_ids"]:
    raise SystemExit("EXPECTED_V53_REQUIREMENT_IDS must be derived from schema x-contract.expected_requirement_ids")
if module.EXPECTED_V53_SUMMARY_CHECKS != v53_expected_summary_checks:
    raise SystemExit("EXPECTED_V53_SUMMARY_CHECKS must be derived from schema x-contract.expected_summary_checks")
if module.DEFAULT_V53_SUMMARY_PATHS != v53_default_summary_paths:
    raise SystemExit("DEFAULT_V53_SUMMARY_PATHS must be derived from schema x-contract.default_summary_paths")
if module.EXPECTED_V53_V1_EXIT_CRITERION_IDS != v53_contract["expected_v1_exit_criterion_ids"]:
    raise SystemExit("EXPECTED_V53_V1_EXIT_CRITERION_IDS must be derived from schema x-contract.expected_v1_exit_criterion_ids")
if module.EXPECTED_V53_PUBLIC_SOURCE_MANIFEST_SUMMARY != v53_contract["expected_public_source_manifest_summary"]:
    raise SystemExit("EXPECTED_V53_PUBLIC_SOURCE_MANIFEST_SUMMARY must be derived from schema x-contract.expected_public_source_manifest_summary")
if module.EXPECTED_V53_PUBLIC_REPOS != v53_contract["expected_public_repos"]:
    raise SystemExit("EXPECTED_V53_PUBLIC_REPOS must be derived from schema x-contract.expected_public_repos")

v54_schema = json.loads((root / "schemas" / "v54_grounded_generation.schema.json").read_text(encoding="utf-8"))
v54_contract = v54_schema["x-contract"]
if module.EXPECTED_V54_POLICY_STATIC != v54_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_V54_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.EXPECTED_V54_ARTIFACTS != v54_contract["expected_required_artifacts"]:
    raise SystemExit("EXPECTED_V54_ARTIFACTS must be derived from schema x-contract.expected_required_artifacts")
if module.EXPECTED_V54_SUMMARY != v54_contract["expected_summary_when_supplied"]:
    raise SystemExit("EXPECTED_V54_SUMMARY must be derived from schema x-contract.expected_summary_when_supplied")

v58_schema = json.loads((root / "schemas" / "v58_blind_eval.schema.json").read_text(encoding="utf-8"))
v58_contract = v58_schema["x-contract"]
v58_artifact_schema = v58_schema["properties"]["required_artifacts"]["items"]
v58_optional_artifact_keys = set(v58_artifact_schema["properties"]) - set(v58_artifact_schema["required"])
if module.EXPECTED_V58_POLICY_STATIC != v58_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_V58_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.EXPECTED_V58_REQUIRED_SYSTEMS != v58_contract["expected_required_systems"]:
    raise SystemExit("EXPECTED_V58_REQUIRED_SYSTEMS must be derived from schema x-contract.expected_required_systems")
if module.EXPECTED_V58_REQUIREMENT_IDS != v58_contract["expected_requirement_ids"]:
    raise SystemExit("EXPECTED_V58_REQUIREMENT_IDS must be derived from schema x-contract.expected_requirement_ids")
if module.EXPECTED_V58_ARTIFACTS != v58_contract["expected_required_artifacts"]:
    raise SystemExit("EXPECTED_V58_ARTIFACTS must be derived from schema x-contract.expected_required_artifacts")
if module.OPTIONAL_V58_ARTIFACT_KEYS != v58_optional_artifact_keys:
    raise SystemExit("OPTIONAL_V58_ARTIFACT_KEYS must be derived from schema required_artifacts.items.properties")
if module.V58_REVIEW_FORBIDDEN_RESOURCE_COLUMNS != set(v58_contract["review_forbidden_resource_columns"]):
    raise SystemExit("V58_REVIEW_FORBIDDEN_RESOURCE_COLUMNS must be derived from schema x-contract.review_forbidden_resource_columns")
if module.V58_REVIEW_FORBIDDEN_IDENTITY_COLUMNS != set(v58_contract["review_forbidden_identity_columns"]):
    raise SystemExit("V58_REVIEW_FORBIDDEN_IDENTITY_COLUMNS must be derived from schema x-contract.review_forbidden_identity_columns")

review_return_schema = json.loads((root / "schemas" / "review_return_workflow.schema.json").read_text(encoding="utf-8"))
review_return_contract = review_return_schema["x-contract"]
review_return_expected_summary_checks = {
    requirement_id: [
        (check["summary_id"], check["field"], check["expected"])
        for check in checks
    ]
    for requirement_id, checks in review_return_contract["expected_summary_checks"].items()
}
if module.EXPECTED_REVIEW_RETURN_POLICY_STATIC != review_return_contract["expected_policy_static"]:
    raise SystemExit("EXPECTED_REVIEW_RETURN_POLICY_STATIC must be derived from schema x-contract.expected_policy_static")
if module.EXPECTED_REVIEW_RETURN_REQUIREMENT_IDS != review_return_contract["expected_requirement_ids"]:
    raise SystemExit("EXPECTED_REVIEW_RETURN_REQUIREMENT_IDS must be derived from schema x-contract.expected_requirement_ids")
if module.EXPECTED_REVIEW_RETURN_SUMMARY_CHECKS != review_return_expected_summary_checks:
    raise SystemExit("EXPECTED_REVIEW_RETURN_SUMMARY_CHECKS must be derived from schema x-contract.expected_summary_checks")

v56_schema = json.loads((root / "schemas" / "v56_replay.schema.json").read_text(encoding="utf-8"))
v56_contract = v56_schema["x-contract"]
if module.EXPECTED_V56_POLICY != v56_contract["expected_policy"]:
    raise SystemExit("EXPECTED_V56_POLICY must be derived from schema x-contract.expected_policy")
if module.EXPECTED_V56_REPLAY_ARTIFACTS != v56_contract["expected_replay_artifacts"]:
    raise SystemExit("EXPECTED_V56_REPLAY_ARTIFACTS must be derived from schema x-contract.expected_replay_artifacts")
if module.EXPECTED_V56_SEED_DEPENDENCY != v56_contract["expected_seed_dependency"]:
    raise SystemExit("EXPECTED_V56_SEED_DEPENDENCY must be derived from schema x-contract.expected_seed_dependency")
PY

cp "$ROOT_DIR/schemas/pr_split.schema.json" "$TMP_DIR/pr_split_schema_missing_slice_contract.schema.json"
python3 - "$TMP_DIR/pr_split_schema_missing_slice_contract.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["required_verification_terms_by_slice"].pop("v59-one-command-demo")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.required_verification_terms_by_slice keys must match slice_id enum" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/pr_split_schema_missing_slice_contract.schema.json" "$ROOT_DIR/pr_slices/pr2.json"

cp "$ROOT_DIR/schemas/pr_split.schema.json" "$TMP_DIR/pr_split_schema_verification_term_drift.schema.json"
python3 - "$TMP_DIR/pr_split_schema_verification_term_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["required_verification_terms_by_slice"]["v59-one-command-demo"].append(
    "missing-v59-verification-term"
)
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance slice v59-one-command-demo.verification_commands must contain x-contract.required_verification_terms_by_slice" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/pr_split_schema_verification_term_drift.schema.json" "$ROOT_DIR/pr_slices/pr2.json"

cp "$ROOT_DIR/schemas/pr_split.schema.json" "$TMP_DIR/pr_split_schema_rewrite_term_drift.schema.json"
python3 - "$TMP_DIR/pr_split_schema_rewrite_term_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["required_rewrite_terms"].append("missing-pr2-rewrite-term")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance recommended_body must contain x-contract.required_rewrite_terms" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/pr_split_schema_rewrite_term_drift.schema.json" "$ROOT_DIR/pr_slices/pr2.json"

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

cp "$ROOT_DIR/schemas/baseline_admission.schema.json" "$TMP_DIR/baseline_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/baseline_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["fixture_rows_in_measured_registry"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/baseline_schema_policy_contract_drift.schema.json" "$ROOT_DIR/baselines/de_30b70b_real.json"

cp "$ROOT_DIR/schemas/baseline_admission.schema.json" "$TMP_DIR/baseline_schema_artifact_contract_drift.schema.json"
python3 - "$TMP_DIR/baseline_schema_artifact_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_required_artifacts"]:
    if row["artifact_id"] == "answer-citation-raw-output":
        row["required_columns"].remove("prompt_template_sha256")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifacts must match x-contract.expected_required_artifacts" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/baseline_schema_artifact_contract_drift.schema.json" "$ROOT_DIR/baselines/de_30b70b_real.json"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/baseline_instance_system_drift.json"
python3 - "$TMP_DIR/baseline_instance_system_drift.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["systems"][0]["parameter_count_b_min"] = 24
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance systems must match x-contract.expected_systems" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/baseline_admission.schema.json" "$TMP_DIR/baseline_instance_system_drift.json"

cp "$ROOT_DIR/schemas/v52_adapter_guard.schema.json" "$TMP_DIR/v52_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/v52_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["release_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v52_schema_policy_contract_drift.schema.json" "$ROOT_DIR/baselines/v52_adapter_guard.json"

cp "$ROOT_DIR/schemas/v52_adapter_guard.schema.json" "$TMP_DIR/v52_schema_artifact_contract_drift.schema.json"
python3 - "$TMP_DIR/v52_schema_artifact_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_required_artifacts"]:
    if row["artifact_id"] == "c-answer-rows":
        row["required_columns"].remove("latency_ns")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifacts must match x-contract.expected_required_artifacts" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v52_schema_artifact_contract_drift.schema.json" "$ROOT_DIR/baselines/v52_adapter_guard.json"

cp "$ROOT_DIR/schemas/v52_adapter_guard.schema.json" "$TMP_DIR/v52_schema_requirement_contract_drift.schema.json"
python3 - "$TMP_DIR/v52_schema_requirement_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_requirement_ids"] = data["x-contract"]["expected_requirement_ids"][:-1]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirements must follow x-contract.expected_requirement_ids" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v52_schema_requirement_contract_drift.schema.json" "$ROOT_DIR/baselines/v52_adapter_guard.json"

cp "$ROOT_DIR/schemas/v52_adapter_guard.schema.json" "$TMP_DIR/v52_schema_summary_contract_drift.schema.json"
python3 - "$TMP_DIR/v52_schema_summary_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
checks = data["x-contract"]["expected_summary_checks"]["c-7b14b-quality-boundary"]
for check in checks:
    if check["field"] == "accuracy":
        check["expected"] = "1.000000"
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirement c-7b14b-quality-boundary.summary_checks must match x-contract.expected_summary_checks" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v52_schema_summary_contract_drift.schema.json" "$ROOT_DIR/baselines/v52_adapter_guard.json"

cp "$ROOT_DIR/schemas/v50_auditor_correctness.schema.json" "$TMP_DIR/v50_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/v50_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["artifact_replay_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy.artifact_replay_ready must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v50_schema_policy_contract_drift.schema.json" "$ROOT_DIR/audits/v50_public_repo_auditor_correctness.json"

cp "$ROOT_DIR/schemas/v50_auditor_correctness.schema.json" "$TMP_DIR/v50_schema_artifact_contract_drift.schema.json"
python3 - "$TMP_DIR/v50_schema_artifact_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_required_artifacts"]:
    if row["artifact_id"] == "source-snapshot-rows":
        row["required_columns"].remove("head_sha")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifacts must match x-contract.expected_required_artifacts" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v50_schema_artifact_contract_drift.schema.json" "$ROOT_DIR/audits/v50_public_repo_auditor_correctness.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/v53_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["human_review_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy.human_review_ready must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_policy_contract_drift.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_requirement_contract_drift.schema.json"
python3 - "$TMP_DIR/v53_schema_requirement_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_requirement_ids"] = data["x-contract"]["expected_requirement_ids"][:-1]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirements must follow x-contract.expected_requirement_ids" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_requirement_contract_drift.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_summary_contract_drift.schema.json"
python3 - "$TMP_DIR/v53_schema_summary_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
checks = data["x-contract"]["expected_summary_checks"]["sanitized-question-only-adapter-selection"]
checks[-1]["expected"] = "1"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirement sanitized-question-only-adapter-selection.summary_checks must match x-contract.expected_summary_checks" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_summary_contract_drift.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_default_summary_paths_drift.schema.json"
python3 - "$TMP_DIR/v53_schema_default_summary_paths_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["default_summary_paths"].pop("v53aq")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.default_summary_paths keys must match summary_id enum" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_default_summary_paths_drift.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_v1_exit_contract_duplicate.schema.json"
python3 - "$TMP_DIR/v53_schema_v1_exit_contract_duplicate.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
criteria = data["x-contract"]["expected_v1_exit_criterion_ids"]
criteria[-1] = criteria[0]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.expected_v1_exit_criterion_ids values must be unique" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_v1_exit_contract_duplicate.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_public_repo_duplicate.schema.json"
python3 - "$TMP_DIR/v53_schema_public_repo_duplicate.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
repos = data["x-contract"]["expected_public_repos"]
repos[-1] = repos[0]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.expected_public_repos must be a non-empty unique owner/repo list" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_public_repo_duplicate.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v53_source_benchmark.schema.json" "$TMP_DIR/v53_schema_public_repo_count_drift.schema.json"
python3 - "$TMP_DIR/v53_schema_public_repo_count_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_public_source_manifest_summary"]["complete_source_repo_count"] = "9"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.expected_public_source_manifest_summary repo count must match expected_public_repos" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v53_schema_public_repo_count_drift.schema.json" "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json"

cp "$ROOT_DIR/schemas/v54_grounded_generation.schema.json" "$TMP_DIR/v54_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/v54_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["real_model_generation_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy.real_model_generation_ready must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v54_schema_policy_contract_drift.schema.json" "$ROOT_DIR/v54/grounded_generation_contract.json"

cp "$ROOT_DIR/schemas/v54_grounded_generation.schema.json" "$TMP_DIR/v54_schema_artifact_contract_drift.schema.json"
python3 - "$TMP_DIR/v54_schema_artifact_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_required_artifacts"]:
    if row["artifact_id"] == "answer-rows":
        row["required_columns"].remove("answer_correct")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifacts must match x-contract.expected_required_artifacts" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v54_schema_artifact_contract_drift.schema.json" "$ROOT_DIR/v54/grounded_generation_contract.json"

cp "$ROOT_DIR/schemas/v58_blind_eval.schema.json" "$TMP_DIR/v58_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/v58_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["real_execution_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy.real_execution_ready must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v58_schema_policy_contract_drift.schema.json" "$ROOT_DIR/v58/blind_eval_real.json"

cp "$ROOT_DIR/schemas/v58_blind_eval.schema.json" "$TMP_DIR/v58_schema_requirement_contract_drift.schema.json"
python3 - "$TMP_DIR/v58_schema_requirement_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_requirement_ids"] = data["x-contract"]["expected_requirement_ids"][:-1]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirements must follow x-contract.expected_requirement_ids" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v58_schema_requirement_contract_drift.schema.json" "$ROOT_DIR/v58/blind_eval_real.json"

cp "$ROOT_DIR/schemas/v58_blind_eval.schema.json" "$TMP_DIR/v58_schema_artifact_contract_drift.schema.json"
python3 - "$TMP_DIR/v58_schema_artifact_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_required_artifacts"]:
    if row["artifact_id"] == "v58-blind-response-rows":
        row["required_columns"].remove("context_budget")
        row["per_system_min_rows"]["D"] = 499
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance required_artifacts must match x-contract.expected_required_artifacts" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v58_schema_artifact_contract_drift.schema.json" "$ROOT_DIR/v58/blind_eval_real.json"

cp "$ROOT_DIR/schemas/v58_blind_eval.schema.json" "$TMP_DIR/v58_schema_review_forbidden_duplicate.schema.json"
python3 - "$TMP_DIR/v58_schema_review_forbidden_duplicate.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
columns = data["x-contract"]["review_forbidden_resource_columns"]
columns.append(columns[0])
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.review_forbidden_resource_columns must be a non-empty unique string list" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v58_schema_review_forbidden_duplicate.schema.json" "$ROOT_DIR/v58/blind_eval_real.json"

cp "$ROOT_DIR/schemas/v58_blind_eval.schema.json" "$TMP_DIR/v58_schema_review_forbidden_artifact_leak.schema.json"
python3 - "$TMP_DIR/v58_schema_review_forbidden_artifact_leak.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["x-contract"]["expected_required_artifacts"]:
    if row["artifact_id"] == "v58-human-review-rows":
        row["required_columns"].append("latency_ns")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "x-contract.expected_required_artifacts.v58-human-review-rows must not contain v58 review forbidden columns" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v58_schema_review_forbidden_artifact_leak.schema.json" "$ROOT_DIR/v58/blind_eval_real.json"

cp "$ROOT_DIR/schemas/review_return_workflow.schema.json" "$TMP_DIR/review_return_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/review_return_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["release_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy.release_ready must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/review_return_schema_policy_contract_drift.schema.json" "$ROOT_DIR/operations/review_return_workflow.json"

cp "$ROOT_DIR/schemas/review_return_workflow.schema.json" "$TMP_DIR/review_return_schema_counter_contract_drift.schema.json"
python3 - "$TMP_DIR/review_return_schema_counter_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy_static"]["accepted_human_review_rows"] = 1
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy.accepted_human_review_rows must match x-contract.expected_policy_static" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/review_return_schema_counter_contract_drift.schema.json" "$ROOT_DIR/operations/review_return_workflow.json"

cp "$ROOT_DIR/schemas/review_return_workflow.schema.json" "$TMP_DIR/review_return_schema_requirement_contract_drift.schema.json"
python3 - "$TMP_DIR/review_return_schema_requirement_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_requirement_ids"] = list(reversed(data["x-contract"]["expected_requirement_ids"]))
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirements must follow x-contract.expected_requirement_ids" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/review_return_schema_requirement_contract_drift.schema.json" "$ROOT_DIR/operations/review_return_workflow.json"

cp "$ROOT_DIR/schemas/review_return_workflow.schema.json" "$TMP_DIR/review_return_schema_summary_contract_drift.schema.json"
python3 - "$TMP_DIR/review_return_schema_summary_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
checks = data["x-contract"]["expected_summary_checks"]["v61-operator-bundle-logistics-only"]
for check in checks:
    if check["field"] == "operator_command_rows":
        check["expected"] = "61"
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance requirement v61-operator-bundle-logistics-only.summary_checks must match x-contract.expected_summary_checks" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/review_return_schema_summary_contract_drift.schema.json" "$ROOT_DIR/operations/review_return_workflow.json"

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

cp "$ROOT_DIR/schemas/v56_replay.schema.json" "$TMP_DIR/v56_schema_policy_contract_drift.schema.json"
python3 - "$TMP_DIR/v56_schema_policy_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_policy"]["ready_replay_artifact_count"] = 1
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance policy must match x-contract.expected_policy" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v56_schema_policy_contract_drift.schema.json" "$ROOT_DIR/v56/replay_contract.json"

cp "$ROOT_DIR/schemas/v56_replay.schema.json" "$TMP_DIR/v56_schema_seed_contract_drift.schema.json"
python3 - "$TMP_DIR/v56_schema_seed_contract_drift.schema.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["x-contract"]["expected_seed_dependency"]["missing_seed_artifact_paths"] = data["x-contract"]["expected_seed_dependency"]["missing_seed_artifact_paths"][:-1]
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "instance seed_dependency must match x-contract.expected_seed_dependency" \
  "$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$TMP_DIR/v56_schema_seed_contract_drift.schema.json" "$ROOT_DIR/v56/replay_contract.json"

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
