#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-pipeline-contract-negative.XXXXXX")"

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

bad_pipeline_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/pipelines/v53.yaml" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "duplicate-stage":
    data["stages"][1]["stage_id"] = data["stages"][0]["stage_id"]
elif mutation == "future-requires":
    data["stages"][0]["requires"] = [data["stages"][1]["stage_id"]]
elif mutation == "literal-real-ready":
    data["stages"][0]["typed_readiness"]["real_model_execution_ready"] = "1"
elif mutation == "literal-release-ready":
    data["stages"][0]["typed_readiness"]["release_ready"] = "true"
elif mutation == "model-visible-source-span":
    for row in data["stages"]:
        if row["stage_id"] == "v53aq-sanitized-abgh-real-adapter":
            row["model_visible_inputs"].append("source_span_id")
            break
elif mutation == "unknown-model-visible":
    for row in data["stages"]:
        if row["stage_id"] == "v53aq-sanitized-abgh-real-adapter":
            row["model_visible_inputs"].append("expected_answer")
            break
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_v54_pipeline_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/pipelines/v54.yaml" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
if mutation == "model-visible-query-id":
    data["stages"][0]["model_visible_inputs"].append("query_id")
elif mutation == "literal-human-review-ready":
    data["stages"][0]["typed_readiness"]["human_review_ready"] = "ready"
else:
    raise SystemExit(f"unknown mutation: {mutation}")
Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

"$ROOT_DIR/tools/verify_artifact.py" pipeline \
  "$ROOT_DIR/pipelines/v52.yaml" \
  "$ROOT_DIR/pipelines/v53.yaml" \
  "$ROOT_DIR/pipelines/v54.yaml" \
  "$ROOT_DIR/pipelines/v58.yaml" \
  "$ROOT_DIR/pipelines/v61.yaml" >/dev/null

bad_path="$(bad_pipeline_json pipeline_duplicate_stage_bad duplicate-stage)"
expect_fail_with \
  "duplicate stage_id" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_pipeline_json pipeline_future_requires_bad future-requires)"
expect_fail_with \
  "requirement must appear before dependent stage" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_pipeline_json pipeline_literal_real_ready_bad literal-real-ready)"
expect_fail_with \
  "typed_readiness.real_model_execution_ready cannot be an untyped literal-ready claim" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_pipeline_json pipeline_literal_release_ready_bad literal-release-ready)"
expect_fail_with \
  "typed_readiness.release_ready cannot be an untyped literal-ready claim" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_pipeline_json pipeline_model_visible_source_span_bad model-visible-source-span)"
expect_fail_with \
  "model_visible_inputs contains forbidden evaluator-only field(s): source_span_id" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_pipeline_json pipeline_unknown_model_visible_bad unknown-model-visible)"
expect_fail_with \
  "model_visible_inputs contains forbidden evaluator-only field(s): expected_answer" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_v54_pipeline_json pipeline_v54_model_visible_query_bad model-visible-query-id)"
expect_fail_with \
  "model_visible_inputs contains forbidden evaluator-only field(s): query_id" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

bad_path="$(bad_v54_pipeline_json pipeline_v54_literal_human_review_bad literal-human-review-ready)"
expect_fail_with \
  "typed_readiness.human_review_ready cannot be an untyped literal-ready claim" \
  "$ROOT_DIR/tools/verify_artifact.py" pipeline "$bad_path"

echo "p0 pipeline contract negative controls passed"
