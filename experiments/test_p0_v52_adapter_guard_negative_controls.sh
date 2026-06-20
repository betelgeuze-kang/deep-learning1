#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-v52-adapter-negative.XXXXXX")"
V52C_SUMMARY="$ROOT_DIR/results/v52c_7b14b_local_model_rag_evidence_intake_summary.csv"
V52D_SUMMARY="$ROOT_DIR/results/v52d_30b70b_llm_rag_evidence_intake_summary.csv"
V52L_SUMMARY="$ROOT_DIR/results/v52l_7b14b_local_model_rag_v53e_1000_summary.csv"
V52R_SUMMARY="$ROOT_DIR/results/v52r_measured_registry_de_absorb_summary.csv"
V52Y_SUMMARY="$ROOT_DIR/results/v52y_f_optional_final_policy_summary.csv"

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

verify_v52() {
  "$ROOT_DIR/tools/verify_artifact.py" v52-adapter-guard "$@" \
    --v52c-summary "$V52C_SUMMARY" \
    --v52d-summary "$V52D_SUMMARY" \
    --v52l-summary "$V52L_SUMMARY" \
    --v52r-summary "$V52R_SUMMARY" \
    --v52y-summary "$V52Y_SUMMARY"
}

bad_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/baselines/v52_adapter_guard.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "c-quality":
    data["policy"]["c_quality_claim_ready"] = True
elif mutation == "de-admission":
    data["policy"]["de_measured_registry_admission_ready"] = True
elif mutation == "public-comparison":
    data["policy"]["public_comparison_claim_ready"] = True
elif mutation == "release":
    data["policy"]["release_ready"] = True
elif mutation == "artifact-order":
    artifacts = data["required_artifacts"]
    artifacts[0], artifacts[1] = artifacts[1], artifacts[0]
elif mutation == "answer-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "c-answer-rows":
            row["required_columns"].remove("latency_ns")
            break
elif mutation == "min-rows":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "c-answer-rows":
            row["min_rows"] = 1
            break
elif mutation == "not-required":
    data["required_artifacts"][0]["required_for_c_packet"] = False
elif mutation == "requirement-status":
    data["requirements"][1]["current_status"] = "blocked"
elif mutation == "summary-check":
    for check in data["requirements"][1]["summary_checks"]:
        if check["field"] == "accuracy":
            check["expected"] = "1.000000"
            break
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_path="$(bad_json c_quality_bad c-quality)"
expect_fail_with \
  "c_quality_claim_ready must be false" \
  verify_v52 "$bad_path"

bad_path="$(bad_json de_admission_bad de-admission)"
expect_fail_with \
  "de_measured_registry_admission_ready must be false" \
  verify_v52 "$bad_path"

bad_path="$(bad_json public_comparison_bad public-comparison)"
expect_fail_with \
  "public_comparison_claim_ready must be false" \
  verify_v52 "$bad_path"

bad_path="$(bad_json release_bad release)"
expect_fail_with \
  "release_ready must be false" \
  verify_v52 "$bad_path"

bad_path="$(bad_json artifact_order_bad artifact-order)"
expect_fail_with \
  "required_artifacts order must match the v52 C packet contract" \
  verify_v52 "$bad_path"

bad_path="$(bad_json answer_column_drop_bad answer-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v52 C packet header" \
  verify_v52 "$bad_path"

bad_path="$(bad_json min_rows_bad min-rows)"
expect_fail_with \
  "min_rows expected 1000, got 1" \
  verify_v52 "$bad_path"

bad_path="$(bad_json not_required_bad not-required)"
expect_fail_with \
  "required_for_c_packet must be true" \
  verify_v52 "$bad_path"

bad_path="$(bad_json requirement_status_bad requirement-status)"
expect_fail_with \
  "current_status must be pass" \
  verify_v52 "$bad_path"

bad_path="$(bad_json summary_check_bad summary-check)"
expect_fail_with \
  "v52l.accuracy expected 1.000000, got 0.000000" \
  verify_v52 "$bad_path"

echo "p0 v52 adapter guard negative controls passed"
