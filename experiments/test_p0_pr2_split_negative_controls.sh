#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-pr2-split-negative.XXXXXX")"

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

bad_pr2_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/pr_slices/pr2.json" "$path" "$@" <<'PY'
import json
import sys
from pathlib import Path

source, target, mutation = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))

def slice_by_id(slice_id):
    for row in data["slices"]:
        if row["slice_id"] == slice_id:
            return row
    raise SystemExit(f"missing slice: {slice_id}")

if mutation == "split-not-required":
    data["split_required"] = False
elif mutation == "title-not-split":
    data["recommended_title"] = "Merge PR #2"
elif mutation == "body-v61-term-drop":
    data["recommended_body"] = [
        row.replace("one-token logits parity", "logits parity")
        for row in data["recommended_body"]
    ]
elif mutation == "tests-only-allowed":
    data["merge_gate_policy"]["forbid_tests_only"] = False
elif mutation == "gate-tests-only":
    data["slices"][0]["merge_gates"] = ["tests"]
elif mutation == "slice-order":
    rows = data["slices"]
    rows[0], rows[1] = rows[1], rows[0]
elif mutation == "v61-summary-command-drop":
    row = slice_by_id("v61-ssd-moe-runtime-roadmap")
    row["verification_commands"] = [
        command.replace("--v61ab-summary", "--missing-v61ab-summary")
        for command in row["verification_commands"]
    ]
elif mutation == "docs-typed-ledger-drop":
    row = slice_by_id("docs-readme-pr2-cleanup")
    row["verification_commands"] = [
        command.replace("--pm-ledger", "--missing-pm-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "leakage-ledger-drop":
    row = slice_by_id("v53-system-a-b-g-h-measured")
    row["verification_commands"] = [
        command.replace("--pm-ledger", "--missing-pm-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "v58-template-ledger-drop":
    row = slice_by_id("v58-blind-eval-contract")
    row["verification_commands"] = [
        command.replace("--template-ledger", "--missing-template-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "de-acceptance-ledger-drop":
    row = slice_by_id("v52-baseline-registry-contract")
    row["verification_commands"] = [
        command.replace("--acceptance-ledger", "--missing-acceptance-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "v56-blocker-ledger-drop":
    row = slice_by_id("v56-ruler-longbench-expanded")
    row["verification_commands"] = [
        command.replace("--blocker-ledger", "--missing-blocker-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "v50-decision-drop":
    row = slice_by_id("v50-auditor-correctness")
    row["verification_commands"] = [
        command.replace("--decision", "--missing-decision")
        for command in row["verification_commands"]
    ]
elif mutation == "review-return-v61hv-summary-drop":
    row = slice_by_id("operator-review-return-workflow")
    row["verification_commands"] = [
        command.replace("--v61hv-summary", "--missing-v61hv-summary")
        for command in row["verification_commands"]
    ]
else:
    raise SystemExit(f"unknown mutation: {mutation}")

Path(target).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  printf '%s\n' "$path"
}

bad_path="$(bad_pr2_json pr2_split_not_required_bad split-not-required)"
expect_fail_with \
  "split_required must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_title_not_split_bad title-not-split)"
expect_fail_with \
  "recommended_title must describe the split" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_body_v61_term_drop_bad body-v61-term-drop)"
expect_fail_with \
  "recommended_body missing PR #2 rewrite terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_tests_only_allowed_bad tests-only-allowed)"
expect_fail_with \
  "merge_gate_policy.forbid_tests_only must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_gate_tests_only_bad gate-tests-only)"
expect_fail_with \
  "merge_gates must be exactly blocker-false-positive, claim-boundary, replay-artifact" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_slice_order_bad slice-order)"
expect_fail_with \
  "PR #2 slice order must match the PM contract" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v61_summary_command_drop_bad v61-summary-command-drop)"
expect_fail_with \
  "v61 verification commands missing replay summary terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_docs_typed_ledger_drop_bad docs-typed-ledger-drop)"
expect_fail_with \
  "docs cleanup verification commands must compare typed readiness to the PM ledger" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_leakage_ledger_drop_bad leakage-ledger-drop)"
expect_fail_with \
  "leakage verification commands must compare the retrieval/model-visible contract to the PM ledger" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v58_template_ledger_drop_bad v58-template-ledger-drop)"
expect_fail_with \
  "v58 verification commands must compare blind-eval blockers to readiness, artifact, and template ledgers" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_de_acceptance_ledger_drop_bad de-acceptance-ledger-drop)"
expect_fail_with \
  "D/E baseline verification commands must compare measured-registry exclusion and acceptance blocker ledgers" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v56_blocker_ledger_drop_bad v56-blocker-ledger-drop)"
expect_fail_with \
  "v56 verification commands must compare replay contract to summary, seed blocker, and acceptance ledgers" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v50_decision_drop_bad v50-decision-drop)"
expect_fail_with \
  "v50 verification commands must compare auditor contract to summary and decision artifacts" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_review_return_v61hv_summary_drop_bad review-return-v61hv-summary-drop)"
expect_fail_with \
  "review-return verification commands must compare workflow contract to v53, v58, v61af, and v61hv blocker summaries" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

echo "p0 PR #2 split negative controls passed"
