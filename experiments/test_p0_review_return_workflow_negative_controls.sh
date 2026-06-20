#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-review-return-negative.XXXXXX")"
V53S_SUMMARY="$ROOT_DIR/results/v53s_complete_source_review_return_intake_summary.csv"
V58D_SUMMARY="$ROOT_DIR/results/v58d_blind_review_return_intake_summary.csv"
V61AF_SUMMARY="$ROOT_DIR/results/v61af_checkpoint_warehouse_operator_bundle_summary.csv"
V61HV_SUMMARY="$ROOT_DIR/results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv"

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

verify_workflow() {
  "$ROOT_DIR/tools/verify_artifact.py" review-return-workflow "$@" \
    --v53s-summary "$V53S_SUMMARY" \
    --v58d-summary "$V58D_SUMMARY" \
    --v61af-summary "$V61AF_SUMMARY" \
    --v61hv-summary "$V61HV_SUMMARY"
}

bad_workflow_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/operations/review_return_workflow.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "human-review-ready":
    data["policy"]["human_review_ready"] = True
elif mutation == "adjudication-ready":
    data["policy"]["adjudication_ready"] = True
elif mutation == "operator-input-ready":
    data["policy"]["operator_input_files_ready"] = True
elif mutation == "actual-generation-ready":
    data["policy"]["actual_generation_ready"] = True
elif mutation == "release-ready":
    data["policy"]["release_ready"] = True
elif mutation == "fixture-closes-return":
    data["policy"]["fixture_can_close_real_return"] = True
elif mutation == "accepted-human-rows":
    data["policy"]["accepted_human_review_rows"] = 1
elif mutation == "accepted-operator-rows":
    data["policy"]["accepted_operator_return_rows"] = 1
elif mutation == "requirement-order":
    rows = data["requirements"]
    rows[0], rows[1] = rows[1], rows[0]
elif mutation == "requirement-status":
    data["requirements"][0]["current_status"] = "blocked"
elif mutation == "summary-check-drop":
    data["requirements"][0]["summary_checks"] = data["requirements"][0]["summary_checks"][:-1]
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_summary_csv() {
  local source="$1"
  local name="$2"
  local field="$3"
  local value="$4"
  local path="$TMP_DIR/$name.csv"
  cp "$source" "$path"
  python3 - "$path" "$field" "$value" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
value = sys.argv[3]
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
if field not in fieldnames:
    raise SystemExit(f"field not found: {field}")
rows[0][field] = value
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
  printf '%s\n' "$path"
}

bad_path="$(bad_workflow_json review_human_ready_bad human-review-ready)"
expect_fail_with \
  "human_review_ready must be false" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_adjudication_ready_bad adjudication-ready)"
expect_fail_with \
  "adjudication_ready must be false" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_operator_input_ready_bad operator-input-ready)"
expect_fail_with \
  "operator_input_files_ready must be false" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_actual_generation_ready_bad actual-generation-ready)"
expect_fail_with \
  "actual_generation_ready must be false" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_release_ready_bad release-ready)"
expect_fail_with \
  "release_ready must be false" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_fixture_closes_return_bad fixture-closes-return)"
expect_fail_with \
  "fixture_can_close_real_return must be false" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_accepted_human_rows_bad accepted-human-rows)"
expect_fail_with \
  "accepted_human_review_rows must be 0" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_accepted_operator_rows_bad accepted-operator-rows)"
expect_fail_with \
  "accepted_operator_return_rows must be 0" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_requirement_order_bad requirement-order)"
expect_fail_with \
  "requirement order must match the review-return workflow contract" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_requirement_status_bad requirement-status)"
expect_fail_with \
  "current_status must be pass" \
  verify_workflow "$bad_path"

bad_path="$(bad_workflow_json review_summary_check_drop_bad summary-check-drop)"
expect_fail_with \
  "summary_checks must exactly match the review-return blocker contract" \
  verify_workflow "$bad_path"

bad_v53s="$(bad_summary_csv "$V53S_SUMMARY" v53s_review_summary_bad accepted_human_review_rows 1)"
expect_fail_with \
  "v53s.accepted_human_review_rows expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" review-return-workflow "$ROOT_DIR/operations/review_return_workflow.json" \
  --v53s-summary "$bad_v53s" \
  --v58d-summary "$V58D_SUMMARY" \
  --v61af-summary "$V61AF_SUMMARY" \
  --v61hv-summary "$V61HV_SUMMARY"

bad_v58d="$(bad_summary_csv "$V58D_SUMMARY" v58d_review_summary_bad human_blind_review_ready 1)"
expect_fail_with \
  "v58d.human_blind_review_ready expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" review-return-workflow "$ROOT_DIR/operations/review_return_workflow.json" \
  --v53s-summary "$V53S_SUMMARY" \
  --v58d-summary "$bad_v58d" \
  --v61af-summary "$V61AF_SUMMARY" \
  --v61hv-summary "$V61HV_SUMMARY"

bad_v61af="$(bad_summary_csv "$V61AF_SUMMARY" v61af_review_summary_bad actual_model_generation_ready 1)"
expect_fail_with \
  "v61af.actual_model_generation_ready expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" review-return-workflow "$ROOT_DIR/operations/review_return_workflow.json" \
  --v53s-summary "$V53S_SUMMARY" \
  --v58d-summary "$V58D_SUMMARY" \
  --v61af-summary "$bad_v61af" \
  --v61hv-summary "$V61HV_SUMMARY"

bad_v61hv="$(bad_summary_csv "$V61HV_SUMMARY" v61hv_review_summary_bad operator_input_files_ready 1)"
expect_fail_with \
  "v61hv.operator_input_files_ready expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" review-return-workflow "$ROOT_DIR/operations/review_return_workflow.json" \
  --v53s-summary "$V53S_SUMMARY" \
  --v58d-summary "$V58D_SUMMARY" \
  --v61af-summary "$V61AF_SUMMARY" \
  --v61hv-summary "$bad_v61hv"

echo "p0 review-return workflow negative controls passed"
