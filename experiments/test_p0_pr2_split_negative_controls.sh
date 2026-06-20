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
elif mutation == "roadmap-verifier-drop":
    row = slice_by_id("docs/v1-roadmap")
    row["verification_commands"] = [
        command.replace("tools/verify_artifact.py roadmap-doc", "tools/verify_artifact.py missing-roadmap-doc")
        for command in row["verification_commands"]
    ]
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
elif mutation == "v53-public-repo-ledger-drop":
    row = slice_by_id("v53-public-repo-source-manifest")
    row["verification_commands"] = [
        command.replace("--repo-ledger", "--missing-repo-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "v53-v1-exit-ledger-drop":
    row = slice_by_id("v53-query-instantiation-1000")
    row["verification_commands"] = [
        command.replace("--v1-exit-ledger", "--missing-v1-exit-ledger")
        for command in row["verification_commands"]
    ]
elif mutation == "v54-summary-drop":
    row = slice_by_id("v54-routehint-generation-contract")
    row["verification_commands"] = [
        command.replace("--summary", "--missing-summary")
        for command in row["verification_commands"]
    ]
elif mutation == "v59-gate-ledger-drop":
    row = slice_by_id("v59-one-command-demo")
    row["verification_commands"] = [
        command.replace("--gate-ledger", "--missing-gate-ledger")
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

write_v59_fixture() {
  local summary_path="$TMP_DIR/v59_summary.csv"
  local gate_path="$TMP_DIR/v59_gate_rows.csv"
  python3 - "$summary_path" "$gate_path" <<'PY'
import csv
import sys
from pathlib import Path

summary_path, gate_path = map(Path, sys.argv[1:3])
summary = {
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "v59_ready": "0",
    "one_command_entrypoint_ready": "1",
    "challenge_bundle_ready": "1",
    "one_command_replay_preflight_ready": "1",
    "pinned_public_sources_verified": "1",
    "source_snapshot_replay_used": "1",
    "public_source_download_executed": "0",
    "public_source_download_approval_required": "1",
    "full_public_source_download_ready": "0",
    "local_abgh_row_contract_replay_ready": "1",
    "v54c_real_model_generation_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "undocumented_local_state_required": "0",
    "private_fixture_required": "0",
    "manual_postprocessing_required": "0",
    "network_required": "0",
    "blocker_false_positive_closed": "1",
    "real_release_package_ready": "0",
}
with summary_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary), lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary)
gates = {
    "pinned-public-sources-verified": "pass",
    "public-source-replay-policy": "pass",
    "public-source-download-execution": "blocked",
    "local-abgh-row-contract-replay": "pass",
    "evaluator-check": "pass",
    "grounded-generation-outputs": "pass",
    "v58-blind-response-intake": "blocked",
    "v58-blind-review-intake": "blocked",
    "no-hidden-local-state": "pass",
    "blocker-false-positive-closed": "pass",
    "one-command-entrypoint": "pass",
    "challenge-bundle-written": "pass",
    "real-blind-eval": "blocked",
    "full-v59-public-demo": "blocked",
    "real-release-package": "blocked",
    "one-command-replay-preflight": "pass",
}
with gate_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["gate", "status", "reason"], lineterminator="\n")
    writer.writeheader()
    for gate, status in gates.items():
        writer.writerow({"gate": gate, "status": status, "reason": f"{gate} expected {status}"})
PY
  printf '%s %s\n' "$summary_path" "$gate_path"
}

bad_v59_summary() {
  local name="$1"
  local field="$2"
  local value="$3"
  local paths
  paths="$(write_v59_fixture)"
  local summary_path="${paths%% *}"
  local gate_path="${paths##* }"
  local bad_path="$TMP_DIR/$name.csv"
  python3 - "$summary_path" "$bad_path" "$field" "$value" <<'PY'
import csv
import sys
from pathlib import Path

source, target, field, value = sys.argv[1:5]
with Path(source).open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0][field] = value
with Path(target).open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
  printf '%s %s\n' "$bad_path" "$gate_path"
}

bad_v59_gate() {
  local name="$1"
  local gate="$2"
  local status="$3"
  local paths
  paths="$(write_v59_fixture)"
  local summary_path="${paths%% *}"
  local gate_path="${paths##* }"
  local bad_path="$TMP_DIR/$name.csv"
  python3 - "$gate_path" "$bad_path" "$gate" "$status" <<'PY'
import csv
import sys
from pathlib import Path

source, target, gate, status = sys.argv[1:5]
with Path(source).open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["gate"] == gate:
        row["status"] = status
        break
else:
    raise SystemExit(f"missing gate: {gate}")
with Path(target).open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
  printf '%s %s\n' "$summary_path" "$bad_path"
}

bad_roadmap_doc() {
  local path="$TMP_DIR/bad_roadmap.md"
  python3 - "$ROOT_DIR/docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md" "$path" <<'PY'
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:3])
text = source.read_text(encoding="utf-8")
text = text.replace("Transformer replacement", "architecture replacement")
text = text.replace("false-positive blocker closure rather than by tests alone", "tests pass")
Path(target).write_text(text, encoding="utf-8")
PY
  printf '%s\n' "$path"
}

write_v53_public_fixture() {
  local summary_path="$TMP_DIR/v53_public_summary.csv"
  local repo_path="$TMP_DIR/v53_public_repo_rows.csv"
  python3 - "$summary_path" "$repo_path" <<'PY'
import csv
import sys
from pathlib import Path

summary_path, repo_path = map(Path, sys.argv[1:3])
summary = {
    "pm_v53_freeze_ready": "1",
    "complete_source_repo_count": "10",
    "foundation_direct_pinned_manifest_ready": "1",
    "foundation_direct_repo_manifest_ready": "1",
    "foundation_direct_content_snapshot_ready": "1",
    "foundation_direct_repo_manifest_rows": "10",
    "foundation_direct_file_manifest_rows": "11266",
    "foundation_direct_content_repo_rows": "10",
    "foundation_direct_content_snapshot_rows": "11266",
    "foundation_direct_query_rows": "1000",
    "foundation_direct_span_rows": "1000",
    "machine_complete_source_surface_ready": "1",
    "review_return_ready": "0",
    "human_review_completed": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
with summary_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary), lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary)
repos = [
    "pypa/sampleproject",
    "psf/requests",
    "pallets/click",
    "pallets/flask",
    "fastapi/fastapi",
    "django/django",
    "pytest-dev/pytest",
    "pypa/pip",
    "python/cpython",
    "tiangolo/typer",
]
fieldnames = [
    "repo_slot",
    "repo_id",
    "owner_repo",
    "head_sha",
    "tree_blob_rows",
    "included_file_rows",
    "query_eligible_file_rows",
    "tree_truncated",
    "complete_source_tree_manifest_ready",
]
with repo_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    for index, owner_repo in enumerate(repos, start=1):
        writer.writerow(
            {
                "repo_slot": str(index),
                "repo_id": owner_repo.replace("/", "_").replace("-", "_"),
                "owner_repo": owner_repo,
                "head_sha": f"{index:040x}",
                "tree_blob_rows": "10",
                "included_file_rows": "8",
                "query_eligible_file_rows": "8",
                "tree_truncated": "0",
                "complete_source_tree_manifest_ready": "1",
            }
        )
PY
  printf '%s %s\n' "$summary_path" "$repo_path"
}

bad_v53_public_summary() {
  local name="$1"
  local field="$2"
  local value="$3"
  local paths
  paths="$(write_v53_public_fixture)"
  local summary_path="${paths%% *}"
  local repo_path="${paths##* }"
  local bad_path="$TMP_DIR/$name.csv"
  python3 - "$summary_path" "$bad_path" "$field" "$value" <<'PY'
import csv
import sys
from pathlib import Path

source, target, field, value = sys.argv[1:5]
with Path(source).open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0][field] = value
with Path(target).open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
  printf '%s %s\n' "$bad_path" "$repo_path"
}

bad_v53_public_repo() {
  local name="$1"
  local field="$2"
  local value="$3"
  local paths
  paths="$(write_v53_public_fixture)"
  local summary_path="${paths%% *}"
  local repo_path="${paths##* }"
  local bad_path="$TMP_DIR/$name.csv"
  python3 - "$repo_path" "$bad_path" "$field" "$value" <<'PY'
import csv
import sys
from pathlib import Path

source, target, field, value = sys.argv[1:5]
with Path(source).open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0][field] = value
with Path(target).open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
  printf '%s %s\n' "$summary_path" "$bad_path"
}

bad_v53_public_repo_order() {
  local paths
  paths="$(write_v53_public_fixture)"
  local summary_path="${paths%% *}"
  local repo_path="${paths##* }"
  local bad_path="$TMP_DIR/v53_public_repo_order_bad.csv"
  python3 - "$repo_path" "$bad_path" <<'PY'
import csv
import sys
from pathlib import Path

source, target = sys.argv[1:3]
with Path(source).open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["owner_repo"], rows[1]["owner_repo"] = rows[1]["owner_repo"], rows[0]["owner_repo"]
with Path(target).open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
  printf '%s %s\n' "$summary_path" "$bad_path"
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

bad_path="$(bad_pr2_json pr2_roadmap_verifier_drop_bad roadmap-verifier-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_roadmap_doc)"
expect_fail_with \
  "roadmap missing required claim-boundary terms" \
  "$ROOT_DIR/tools/verify_artifact.py" roadmap-doc "$bad_path"

bad_path="$(bad_pr2_json pr2_v61_summary_command_drop_bad v61-summary-command-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_docs_typed_ledger_drop_bad docs-typed-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_leakage_ledger_drop_bad leakage-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v53_public_repo_ledger_drop_bad v53-public-repo-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

paths="$(bad_v53_public_summary v53_public_ready_bad v53_ready 1)"
summary_path="${paths%% *}"
repo_path="${paths##* }"
expect_fail_with \
  "v53_ready expected 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v53-public-source-manifest "$summary_path" --repo-ledger "$repo_path"

paths="$(bad_v53_public_repo v53_public_tree_truncated_bad tree_truncated 1)"
summary_path="${paths%% *}"
repo_path="${paths##* }"
expect_fail_with \
  "tree_truncated must be 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v53-public-source-manifest "$summary_path" --repo-ledger "$repo_path"

paths="$(bad_v53_public_repo_order)"
summary_path="${paths%% *}"
repo_path="${paths##* }"
expect_fail_with \
  "owner_repo order must match the pinned v53 public source manifest" \
  "$ROOT_DIR/tools/verify_artifact.py" v53-public-source-manifest "$summary_path" --repo-ledger "$repo_path"

bad_path="$(bad_pr2_json pr2_v53_v1_exit_ledger_drop_bad v53-v1-exit-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v54_summary_drop_bad v54-summary-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v59_gate_ledger_drop_bad v59-gate-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

paths="$(bad_v59_summary v59_ready_bad v59_ready 1)"
summary_path="${paths%% *}"
gate_path="${paths##* }"
expect_fail_with \
  "v59_ready expected 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v59-pm-foundation-demo "$summary_path" --gate-ledger "$gate_path"

paths="$(bad_v59_gate v59_release_gate_bad real-release-package pass)"
summary_path="${paths%% *}"
gate_path="${paths##* }"
expect_fail_with \
  "real-release-package.status expected blocked" \
  "$ROOT_DIR/tools/verify_artifact.py" v59-pm-foundation-demo "$summary_path" --gate-ledger "$gate_path"

bad_path="$(bad_pr2_json pr2_v58_template_ledger_drop_bad v58-template-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_de_acceptance_ledger_drop_bad de-acceptance-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v56_blocker_ledger_drop_bad v56-blocker-ledger-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_v50_decision_drop_bad v50-decision-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

bad_path="$(bad_pr2_json pr2_review_return_v61hv_summary_drop_bad review-return-v61hv-summary-drop)"
expect_fail_with \
  "verification_commands missing schema x-contract terms" \
  "$ROOT_DIR/tools/verify_artifact.py" pr-split "$bad_path"

echo "p0 PR #2 split negative controls passed"
