#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-v53-v54-negative.XXXXXX")"
V53I_SUMMARY="$ROOT_DIR/results/v53i_complete_source_query_instantiation_summary.csv"
V53T_SUMMARY="$ROOT_DIR/results/v53t_complete_source_audit_readiness_gate_summary.csv"
V53AP_SUMMARY="$ROOT_DIR/results/v53ap_complete_source_abgh_same_query_measured_summary.csv"
V53AQ_SUMMARY="$ROOT_DIR/results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv"
V53_EXIT_LEDGER="$ROOT_DIR/results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv"
V54_SUMMARY="$ROOT_DIR/results/v54c_complete_source_grounded_generation_1000_summary.csv"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

expect_fail_with() {
  local expected="$1"
  shift
  local out="$TMP_DIR/expect_fail.out"
  if "$@" >"$out" 2>&1; then
    echo "negative control unexpectedly passed: $*" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$out" >/dev/null; then
    echo "negative control failed for the wrong reason: $*" >&2
    echo "expected diagnostic: $expected" >&2
    echo "actual output:" >&2
    cat "$out" >&2
    exit 1
  fi
}

verify_v53() {
  "$ROOT_DIR/tools/verify_artifact.py" v53-source-benchmark "$@" \
    --v53i-summary "$V53I_SUMMARY" \
    --v53t-summary "$V53T_SUMMARY" \
    --v53ap-summary "$V53AP_SUMMARY" \
    --v53aq-summary "$V53AQ_SUMMARY" \
    --v1-exit-ledger "$V53_EXIT_LEDGER"
}

bad_v53_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "human-review":
    data["policy"]["human_review_ready"] = True
elif mutation == "public-comparison":
    data["policy"]["public_comparison_claim_ready"] = True
elif mutation == "release":
    data["policy"]["release_ready"] = True
elif mutation == "requirement-order":
    rows = data["requirements"]
    rows[0], rows[1] = rows[1], rows[0]
elif mutation == "requirement-status":
    data["requirements"][0]["current_status"] = "blocked"
elif mutation == "summary-check-drop":
    data["requirements"][5]["summary_checks"] = data["requirements"][5]["summary_checks"][:-1]
elif mutation == "source-oracle":
    for check in data["requirements"][5]["summary_checks"]:
        if check["field"] == "source_span_oracle_selection_used":
            check["expected"] = "1"
            break
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_v54_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/v54/grounded_generation_contract.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "raw-context-policy":
    data["policy"]["raw_prompt_context_allowed"] = True
elif mutation == "real-generation":
    data["policy"]["real_model_generation_ready"] = True
elif mutation == "allowed-fields":
    data["policy"]["allowed_model_visible_fields"].append("source_span_id")
elif mutation == "artifact-order":
    artifacts = data["required_artifacts"]
    artifacts[0], artifacts[1] = artifacts[1], artifacts[0]
elif mutation == "input-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "generator-input-rows":
            row["required_columns"].remove("model_visible_source_span_id_used")
            break
elif mutation == "raw-flag":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "generator-input-rows":
            row["raw_prompt_context_forbidden"] = False
            break
elif mutation == "model-visible-flag":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "compact-routehint-rows":
            row["model_visible_leakage_forbidden"] = False
            break
elif mutation == "pm-output":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "answer-rows":
            row["pm_recommended_output"] = False
            break
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_v54_row_json() {
  local name="$1"
  local artifact_id="$2"
  local field="$3"
  local value="$4"
  local contract_path="$TMP_DIR/$name.json"
  local csv_path="$TMP_DIR/$name.csv"
  python3 - "$ROOT_DIR/v54/grounded_generation_contract.json" "$contract_path" "$csv_path" "$artifact_id" "$field" "$value" <<'PY'
import csv
import json
import sys
from pathlib import Path

source, target, csv_target, artifact_id, field, value = sys.argv[1:7]
data = json.loads(Path(source).read_text(encoding="utf-8"))
artifact = None
for row in data["required_artifacts"]:
    if row["artifact_id"] == artifact_id:
        artifact = row
        break
if artifact is None:
    raise SystemExit(f"unknown artifact_id: {artifact_id}")
source_csv = Path(artifact["path"])
with source_csv.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
if field not in fieldnames:
    raise SystemExit(f"{source_csv}: missing field {field}")
if not rows:
    raise SystemExit(f"{source_csv}: no rows to mutate")
rows[0][field] = value
with Path(csv_target).open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
artifact["path"] = csv_target
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$contract_path"
}

bad_path="$(bad_v53_json v53_human_review_bad human-review)"
expect_fail_with \
  "human_review_ready must remain false" \
  verify_v53 "$bad_path"

bad_path="$(bad_v53_json v53_public_comparison_bad public-comparison)"
expect_fail_with \
  "public_comparison_claim_ready must remain false" \
  verify_v53 "$bad_path"

bad_path="$(bad_v53_json v53_release_bad release)"
expect_fail_with \
  "release_ready must remain false" \
  verify_v53 "$bad_path"

bad_path="$(bad_v53_json v53_requirement_order_bad requirement-order)"
expect_fail_with \
  "requirement order must match the v53 source-bound freeze contract" \
  verify_v53 "$bad_path"

bad_path="$(bad_v53_json v53_requirement_status_bad requirement-status)"
expect_fail_with \
  "current_status must be pass for the machine foundation freeze" \
  verify_v53 "$bad_path"

bad_path="$(bad_v53_json v53_summary_check_drop_bad summary-check-drop)"
expect_fail_with \
  "summary_checks must exactly match the v53 source benchmark contract" \
  verify_v53 "$bad_path"

bad_path="$(bad_v53_json v53_source_oracle_bad source-oracle)"
expect_fail_with \
  "summary_checks must exactly match the v53 source benchmark contract" \
  verify_v53 "$bad_path"

cp "$V53_EXIT_LEDGER" "$TMP_DIR/v53_exit_ledger_bad.csv"
python3 - "$TMP_DIR/v53_exit_ledger_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["tests_only_merge_condition"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "tests_only_merge_condition must be 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v53-source-benchmark "$ROOT_DIR/benchmarks/v53_source_bound_freeze.json" \
  --v53i-summary "$V53I_SUMMARY" \
  --v53t-summary "$V53T_SUMMARY" \
  --v53ap-summary "$V53AP_SUMMARY" \
  --v53aq-summary "$V53AQ_SUMMARY" \
  --v1-exit-ledger "$TMP_DIR/v53_exit_ledger_bad.csv"

bad_path="$(bad_v54_json v54_raw_context_policy_bad raw-context-policy)"
expect_fail_with \
  "raw_prompt_context_allowed must be false" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_real_generation_bad real-generation)"
expect_fail_with \
  "real_model_generation_ready must be false" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_allowed_fields_bad allowed-fields)"
expect_fail_with \
  "allowed_model_visible_fields must be sanitized_question, opaque_routehint" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_artifact_order_bad artifact-order)"
expect_fail_with \
  "required_artifacts order must match the v54 grounded generation contract" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_input_column_drop_bad input-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v54 artifact header" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_raw_flag_bad raw-flag)"
expect_fail_with \
  "raw_prompt_context_forbidden must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_model_visible_flag_bad model-visible-flag)"
expect_fail_with \
  "model_visible_leakage_forbidden must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_json v54_pm_output_bad pm-output)"
expect_fail_with \
  "PM recommended v54 outputs must set pm_recommended_output=true" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_row_json v54_generator_source_span_visible_bad generator-input-rows model_visible_source_span_id_used 1)"
expect_fail_with \
  "generator-input-rows.model_visible_source_span_id_used expected 0 for all rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_row_json v54_generator_raw_context_bad generator-input-rows raw_prompt_context_appended 1)"
expect_fail_with \
  "generator-input-rows.raw_prompt_context_appended expected 0 for all rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_row_json v54_generator_real_generation_bad generator-input-rows real_model_generation_ready 1)"
expect_fail_with \
  "generator-input-rows.real_model_generation_ready expected 0 for all rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_row_json v54_routehint_alias_bad compact-routehint-rows compact_routehint_forbidden_alias_used 1)"
expect_fail_with \
  "compact-routehint-rows.compact_routehint_forbidden_alias_used expected 0 for all rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_row_json v54_answer_wrong_bad answer-rows wrong_answer 1)"
expect_fail_with \
  "answer-rows.wrong_answer expected 0 for all rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

bad_path="$(bad_v54_row_json v54_wrong_guard_status_bad wrong-answer-guard-rows guard_status blocked)"
expect_fail_with \
  "wrong-answer-guard-rows.guard_status expected pass for all rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v54-grounded-generation "$bad_path" --summary "$V54_SUMMARY"

echo "p0 v53/v54 pipeline negative controls passed"
