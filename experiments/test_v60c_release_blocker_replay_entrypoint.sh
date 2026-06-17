#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v60c_release_blocker_replay_entrypoint/entrypoint_001"
SUMMARY_CSV="$RESULTS_DIR/v60c_release_blocker_replay_entrypoint_summary.csv"
DECISION_CSV="$RESULTS_DIR/v60c_release_blocker_replay_entrypoint_decision.csv"
ENTRYPOINT_DIR="$RUN_DIR/release_blocker_replay_entrypoint"
FIXTURE_ROOT="$RUN_DIR/fixture_reject_roots"

"$ROOT_DIR/experiments/run_v60c_release_blocker_replay_entrypoint.sh" >/dev/null

"$ENTRYPOINT_DIR/VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh" >/dev/null
"$ENTRYPOINT_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if "$ENTRYPOINT_DIR/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh" >/tmp/v60c_no_env.out 2>/tmp/v60c_no_env.err; then
  echo "v60c entrypoint unexpectedly admitted without env" >&2
  exit 1
fi
grep -q "V60C_REAL_EVIDENCE_PROVENANCE" /tmp/v60c_no_env.err

mkdir -p "$FIXTURE_ROOT/d30" "$FIXTURE_ROOT/e70" "$FIXTURE_ROOT/v56" "$FIXTURE_ROOT/v58" "$FIXTURE_ROOT/public_source" "$FIXTURE_ROOT/review" "$FIXTURE_ROOT/release"
printf 'query_id,label_id\n' > "$FIXTURE_ROOT/h10_labels.csv"
if V60C_REAL_EVIDENCE_PROVENANCE="fixture-release-evidence" \
  V60C_30B_EVIDENCE_DIR="$FIXTURE_ROOT/d30" \
  V60C_70B_EVIDENCE_DIR="$FIXTURE_ROOT/e70" \
  V60C_H10_REAL_LABEL_EVIDENCE_CSV="$FIXTURE_ROOT/h10_labels.csv" \
  V60C_V56_REPLAY_ARTIFACT_DIR="$FIXTURE_ROOT/v56" \
  V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR="$FIXTURE_ROOT/v58" \
  V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR="$FIXTURE_ROOT/public_source" \
  V60C_HUMAN_RELEASE_REVIEW_DIR="$FIXTURE_ROOT/review" \
  V60C_RELEASE_PACKAGE_DIR="$FIXTURE_ROOT/release" \
  "$ENTRYPOINT_DIR/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh" >/tmp/v60c_fixture.out 2>/tmp/v60c_fixture.err; then
  echo "v60c entrypoint unexpectedly admitted fixture provenance" >&2
  exit 1
fi
grep -q "rejecting release blocker provenance" /tmp/v60c_fixture.err

if V60C_REAL_EVIDENCE_PROVENANCE="real-v60-release-blocker-evidence" \
  V60C_30B_EVIDENCE_DIR="$FIXTURE_ROOT/d30" \
  V60C_70B_EVIDENCE_DIR="$FIXTURE_ROOT/e70" \
  V60C_H10_REAL_LABEL_EVIDENCE_CSV="$FIXTURE_ROOT/h10_labels.csv" \
  V60C_V56_REPLAY_ARTIFACT_DIR="$FIXTURE_ROOT/v56" \
  V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR="$FIXTURE_ROOT/v58" \
  V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR="$FIXTURE_ROOT/public_source" \
  V60C_HUMAN_RELEASE_REVIEW_DIR="$FIXTURE_ROOT/review" \
  V60C_RELEASE_PACKAGE_DIR="$FIXTURE_ROOT/release" \
  "$ENTRYPOINT_DIR/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh" >/tmp/v60c_repo_internal.out 2>/tmp/v60c_repo_internal.err; then
  echo "v60c entrypoint unexpectedly admitted repo-internal evidence roots" >&2
  exit 1
fi
grep -q "rejecting repo-internal evidence directory" /tmp/v60c_repo_internal.err

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ENTRYPOINT_DIR" <<'PY'
import csv
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
entrypoint_dir = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v60c_release_blocker_replay_entrypoint_ready": "1",
    "v60_release_contract_ready": "1",
    "entrypoint_admitted_by_default": "0",
    "required_env_rows": "9",
    "present_required_env_rows_by_default": "0",
    "stage_rows": "13",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "11",
    "command_rows": "3",
    "ready_command_rows": "2",
    "blocked_command_rows": "1",
    "release_requirement_rows": "14",
    "release_requirement_ready_rows": "6",
    "release_requirement_blocked_rows": "8",
    "blocked_release_requirement_rows": "8",
    "pm_acceptance_evidence_rows": "10",
    "pm_acceptance_evidence_ready_rows": "9",
    "pm_acceptance_evidence_tests_only_rows": "0",
    "pm_required_artifact_map_rows": "26",
    "pm_required_artifact_map_fixture_allowed_rows": "0",
    "pm_required_artifact_map_approval_rows": "26",
    "pm_required_artifact_map_template_bound_rows": "26",
    "pm_required_artifact_map_default_admitted_rows": "0",
    "metadata_only_entrypoint_file_rows": "11",
    "payload_like_entrypoint_file_rows": "0",
    "remote_mutation_approved": "0",
    "network_required_by_default": "0",
    "downloads_required_by_default": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_30b_70b_rows_ready": "0",
    "h10_real_label_promotion_ready": "0",
    "expanded_benchmark_ready": "0",
    "v58c_blind_response_intake_ready": "0",
    "v58c_intake_artifact_available": "0",
    "v58c_dependency_blocker_ready": "1",
    "blind_eval_ready": "0",
    "one_command_real_replay_ready": "0",
    "human_release_review_ready": "0",
    "v60_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v60c {field}: expected {value}, got {summary.get(field)}")
if int(summary["entrypoint_file_rows"]) < 7:
    raise SystemExit("v60c should emit at least seven entrypoint files")

required_files = [
    "release_blocker_replay_required_env_rows.csv",
    "release_blocker_replay_artifact_map_rows.csv",
    "release_blocker_replay_stage_rows.csv",
    "release_blocker_replay_command_rows.csv",
    "release_blocker_replay_entrypoint_file_rows.csv",
    "V60C_RELEASE_BLOCKER_REPLAY_ENTRYPOINT_BOUNDARY.md",
    "v60c_release_blocker_replay_entrypoint_manifest.json",
    "sha256_manifest.csv",
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh",
    "release_blocker_replay_entrypoint/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh",
    "release_blocker_replay_entrypoint/VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh",
    "release_blocker_replay_entrypoint/READY_NOW_COMMANDS.sh",
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_REQUIRED_ENV_ROWS.csv",
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_ARTIFACT_MAP_ROWS.csv",
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_STAGE_ROWS.csv",
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_COMMAND_ROWS.csv",
    "release_blocker_replay_entrypoint/V60C_PM_PR_ACCEPTANCE_EVIDENCE_ROWS.csv",
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_MANIFEST.json",
    "release_blocker_replay_entrypoint/README.md",
    "source_v60/v60_architecture_challenge_release_contract_summary.csv",
    "source_v60/release_requirement_rows.csv",
    "source_pm/pm_pr_acceptance_evidence_rows.csv",
    "source_pm/pm_blocker_required_artifact_rows.csv",
    "source_pm/pm_external_return_template_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v60c artifact: {rel}")

for rel in [
    "release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh",
    "release_blocker_replay_entrypoint/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh",
    "release_blocker_replay_entrypoint/VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh",
    "release_blocker_replay_entrypoint/READY_NOW_COMMANDS.sh",
]:
    if not os.access(run_dir / rel, os.X_OK):
        raise SystemExit(f"v60c executable bit missing: {rel}")

env_rows = read_csv(run_dir / "release_blocker_replay_required_env_rows.csv")
if [row["env_var"] for row in env_rows] != [
    "V60C_REAL_EVIDENCE_PROVENANCE",
    "V60C_30B_EVIDENCE_DIR",
    "V60C_70B_EVIDENCE_DIR",
    "V60C_H10_REAL_LABEL_EVIDENCE_CSV",
    "V60C_V56_REPLAY_ARTIFACT_DIR",
    "V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR",
    "V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR",
    "V60C_HUMAN_RELEASE_REVIEW_DIR",
    "V60C_RELEASE_PACKAGE_DIR",
]:
    raise SystemExit("v60c required env rows mismatch")

pm_acceptance_rows = read_csv(run_dir / "source_pm/pm_pr_acceptance_evidence_rows.csv")
entrypoint_acceptance_rows = read_csv(run_dir / "release_blocker_replay_entrypoint/V60C_PM_PR_ACCEPTANCE_EVIDENCE_ROWS.csv")
if len(pm_acceptance_rows) != 10 or pm_acceptance_rows != entrypoint_acceptance_rows:
    raise SystemExit("v60c should carry the PM PR acceptance evidence rows into source_pm and the entrypoint package")
pm_acceptance_by_id = {row["slice_id"]: row for row in pm_acceptance_rows}
if sum(row["acceptance_ready"] == "1" for row in pm_acceptance_rows) != 9:
    raise SystemExit("v60c PM acceptance evidence should preserve nine review-ready slices")
if any(row["tests_only_merge_condition"] != "0" for row in pm_acceptance_rows):
    raise SystemExit("v60c PM acceptance evidence should preserve tests-only merge condition closure")
if pm_acceptance_by_id["v56-ruler-longbench-expanded"]["acceptance_ready"] != "0":
    raise SystemExit("v60c PM acceptance evidence should keep v56 held until replay artifact evidence closes")
if pm_acceptance_by_id["v53-system-a-b-g-h-measured"]["replay_artifact_path"] != "source_v59e/local_abgh_row_contract_replay_rows.csv":
    raise SystemExit("v60c PM acceptance evidence should bind A/B/G/H to the local row-contract replay ledger")

artifact_map_rows = read_csv(run_dir / "release_blocker_replay_artifact_map_rows.csv")
if len(artifact_map_rows) != 26:
    raise SystemExit("v60c should map all 26 PM required artifacts into replay targets")
if any(row["source_fixture_allowed"] != "0" for row in artifact_map_rows):
    raise SystemExit("v60c PM artifact map must preserve fixture-forbidden boundaries")
if any(row["source_approval_required"] != "1" for row in artifact_map_rows):
    raise SystemExit("v60c PM artifact map must preserve approval-required boundaries")
if any(row["return_template_ready"] != "1" for row in artifact_map_rows):
    raise SystemExit("v60c PM artifact map must bind every artifact to a ready return template")
if any(row["default_replay_admitted"] != "0" or row["status"] != "fail-closed" for row in artifact_map_rows):
    raise SystemExit("v60c PM artifact map must fail closed by default")
artifact_map_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in artifact_map_rows}
expected_artifact_targets = {
    ("de-30b70b-baselines-missing", "d-model-identity"): ("V60C_30B_EVIDENCE_DIR", "04-d-e-30b70b-baselines"),
    ("de-30b70b-baselines-missing", "e-model-identity"): ("V60C_70B_EVIDENCE_DIR", "04-d-e-30b70b-baselines"),
    ("external-human-label-evidence-missing", "h10-label-evidence-csv"): ("V60C_H10_REAL_LABEL_EVIDENCE_CSV", "05-h10-real-labels"),
    ("v56-replay-artifact-missing", "v56b-scale-artifacts"): ("V60C_V56_REPLAY_ARTIFACT_DIR", "06-v56-replay-artifact"),
    ("v58c-intake-artifact-missing", "v58c-intake-summary"): ("V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR", "07-v58c-blind-response-intake"),
    ("v58-real-blind-eval-missing", "v58-human-review-rows"): ("V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR", "08-v58-real-blind-eval"),
    ("v60-release-evidence-missing", "v59-public-source-download-refresh"): ("V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR", "09-public-source-download-refresh"),
    ("v60-release-evidence-missing", "v59e-local-abgh-row-contract-replay"): ("none-local-v60-source-copy", "02-pm-foundation-pass-surfaces"),
    ("v60-release-evidence-missing", "v60-human-release-review"): ("V60C_HUMAN_RELEASE_REVIEW_DIR", "11-human-release-review"),
    ("v60-release-evidence-missing", "v60-release-sha256-manifest"): ("V60C_RELEASE_PACKAGE_DIR", "12-release-package"),
}
for key, (env_var, stage_id) in expected_artifact_targets.items():
    row = artifact_map_by_key.get(key)
    if row is None:
        raise SystemExit(f"v60c PM artifact map missing {key}")
    if row["replay_env_var"] != env_var or row["replay_stage_id"] != stage_id:
        raise SystemExit(f"v60c PM artifact map target mismatch for {key}")

stages = read_csv(run_dir / "release_blocker_replay_stage_rows.csv")
if len(stages) != 13:
    raise SystemExit("v60c expected thirteen stage rows")
if sum(row["status"] == "ready" for row in stages) != 2:
    raise SystemExit("v60c expected two ready stages by default")
if sum(row["status"] == "blocked" for row in stages) != 11:
    raise SystemExit("v60c expected eleven blocked stages by default")

commands = read_csv(run_dir / "release_blocker_replay_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0"]:
    raise SystemExit("v60c command readiness mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v60-release-contract-input", "entrypoint-files", "zero-remote-mutation-default", "zero-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v60c expected pass decision: {gate}")
for gate in ["default-admission", "real-evidence-provenance", "release-ready"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v60c expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v60c_release_blocker_replay_entrypoint_manifest.json").read_text(encoding="utf-8"))
if manifest.get("entrypoint_admitted_by_default") != 0:
    raise SystemExit("v60c manifest must fail closed by default")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v60c manifest must keep release blocked")
if (
    manifest.get("pm_acceptance_evidence_rows") != 10
    or manifest.get("pm_acceptance_evidence_ready_rows") != 9
    or manifest.get("pm_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v60c manifest PM acceptance evidence mismatch")

entry_manifest = json.loads((entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_MANIFEST.json").read_text(encoding="utf-8"))
if entry_manifest.get("required_env_rows") != 9:
    raise SystemExit("v60c entrypoint manifest required env mismatch")
if (
    entry_manifest.get("pm_acceptance_evidence_rows") != 10
    or entry_manifest.get("pm_acceptance_evidence_ready_rows") != 9
    or entry_manifest.get("pm_acceptance_evidence_tests_only_rows") != 0
):
    raise SystemExit("v60c entrypoint manifest PM acceptance evidence mismatch")
if entry_manifest.get("pm_required_artifact_map_rows") != 26:
    raise SystemExit("v60c entrypoint manifest PM artifact map mismatch")
if entry_manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v60c entrypoint manifest must keep repo payload zero")

run_script = (entrypoint_dir / "RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh").read_text(encoding="utf-8")
expected_root = str(run_dir.parents[2])
if expected_root not in run_script:
    raise SystemExit("v60c replay script must pin the real repository root")
for snippet in [
    "V52D_30B_LLM_RAG_EVIDENCE_DIR",
    "V10_H10_REAL_LABEL_EVIDENCE_CSV",
    "V58C_BLIND_RESPONSE_EVIDENCE_DIR",
    "V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR",
    "rejecting repo-internal evidence",
]:
    if snippet not in run_script:
        raise SystemExit(f"v60c replay script missing: {snippet}")

ready_output = subprocess.check_output([str(entrypoint_dir / "READY_NOW_COMMANDS.sh")], text=True)
for snippet in [
    "metadata verification only",
    "VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh",
    "V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh",
    "RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh",
]:
    if snippet not in ready_output:
        raise SystemExit(f"v60c ready output missing: {snippet}")

boundary = (run_dir / "V60C_RELEASE_BLOCKER_REPLAY_ENTRYPOINT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v60c_release_blocker_replay_entrypoint_ready=1",
    "entrypoint_admitted_by_default=0",
    "required_env_rows=9",
    "blocked_release_requirement_rows=8",
    "pm_acceptance_evidence_rows=10",
    "pm_acceptance_evidence_ready_rows=9",
    "pm_acceptance_evidence_tests_only_rows=0",
    "pm_required_artifact_map_rows=26",
    "pm_required_artifact_map_fixture_allowed_rows=0",
    "pm_required_artifact_map_approval_rows=26",
    "pm_required_artifact_map_template_bound_rows=26",
    "real_30b_70b_rows_ready=0",
    "h10_real_label_promotion_ready=0",
    "v58c_blind_response_intake_ready=0",
    "v58c_intake_artifact_available=0",
    "v58c_dependency_blocker_ready=1",
    "blind_eval_ready=0",
    "v60_ready=0",
    "real_release_package_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v60c boundary missing: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v60c sha256 mismatch: {rel}")
PY

echo "v60c release blocker replay entrypoint smoke passed"
