#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cd_ubuntu1_generation_unblocker_closure_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v61cd_ubuntu1_generation_unblocker_closure_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cd_ubuntu1_generation_unblocker_closure_bundle_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CD_REUSE_EXISTING="${V61CD_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cd_ubuntu1_generation_unblocker_closure_bundle.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = sys.argv[4]


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
    "v61cd_ubuntu1_generation_unblocker_closure_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": "1",
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": "1",
    "v53s_complete_source_review_return_intake_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "target_root_path": ubuntu1_target,
    "closure_phase_rows": "3",
    "return_artifact_rows": "11",
    "operator_command_rows": "7",
    "complete_source_query_rows": "1000",
    "generation_admission_bridge_rows": "1000",
    "page_hash_return_required_rows": "0",
    "page_hash_return_accepted_rows": "0",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "human_review_required_rows": "7000",
    "human_review_accepted_rows": "0",
    "adjudication_required_rows": "1000",
    "adjudication_accepted_rows": "0",
    "reviewer_identity_required_rows": "21",
    "reviewer_identity_accepted_rows": "0",
    "conflict_disclosure_required_rows": "210",
    "conflict_disclosure_accepted_rows": "0",
    "generation_result_required_artifacts": "5",
    "generation_result_accepted_artifacts": "0",
    "generation_execution_admitted_rows": "0",
    "page_hash_blocked_rows": "0",
    "review_return_blocked_rows": "1000",
    "generation_result_artifact_blocked_rows": "1000",
    "page_hash_closure_ready": "1",
    "review_return_closure_ready": "0",
    "generation_result_closure_ready": "0",
    "generation_unblocker_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cd {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "generation_unblocker_phase_rows.csv",
    "generation_unblocker_return_artifact_rows.csv",
    "generation_unblocker_operator_command_rows.csv",
    "generation_unblocker_metric_rows.csv",
    "generation_unblocker_requirement_rows.csv",
    "runtime_gap_rows.csv",
    "V61CD_UBUNTU1_GENERATION_UNBLOCKER_CLOSURE_BUNDLE_BOUNDARY.md",
    "v61cd_ubuntu1_generation_unblocker_closure_bundle_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/return_manifest_template.csv",
    "operator_bundle/VERIFY_RETURN_BUNDLE.sh",
    "sha256_manifest.csv",
    "source_v61cc/page_hash_generation_admission_bridge_rows.csv",
    "source_v61ca/remaining_page_hash_result_required_field_rows.csv",
    "source_v53s/review_return_required_field_rows.csv",
    "source_v61bt/actual_generation_result_required_field_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cd artifact: {rel}")
if not os.access(run_dir / "operator_bundle/VERIFY_RETURN_BUNDLE.sh", os.X_OK):
    raise SystemExit("v61cd verify script must be executable")

phase_rows = read_csv(run_dir / "generation_unblocker_phase_rows.csv")
artifact_rows = read_csv(run_dir / "generation_unblocker_return_artifact_rows.csv")
command_rows = read_csv(run_dir / "generation_unblocker_operator_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "generation_unblocker_requirement_rows.csv")}
metric = read_csv(run_dir / "generation_unblocker_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if [row["phase_id"] for row in phase_rows] != [
    "phase-01-remaining-page-hash-return",
    "phase-02-complete-source-review-return",
    "phase-03-actual-generation-result-return",
]:
    raise SystemExit("v61cd phase order mismatch")
if phase_rows[0]["closure_ready"] != "1":
    raise SystemExit("v61cd page-hash phase should be closed")
if any(row["closure_ready"] != "0" for row in phase_rows[1:]):
    raise SystemExit("v61cd review/generation phases should remain blocked")
if len(artifact_rows) != 11:
    raise SystemExit("v61cd artifact row count mismatch")
if len(command_rows) != 7:
    raise SystemExit("v61cd command row count mismatch")
if any(row["execution_ready"] != "0" for row in command_rows):
    raise SystemExit("v61cd commands should be handoff-only by default")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in artifact_rows):
    raise SystemExit("v61cd must not commit checkpoint payload bytes")
required_artifacts = {
    "remaining_page_hash_result_rows.csv",
    "human_review_rows.csv",
    "adjudication_rows.csv",
    "reviewer_identity_rows.csv",
    "reviewer_conflict_rows.csv",
    "acceptance_summary.json",
    "real_model_generation_answer_rows.csv",
    "real_model_generation_citation_rows.csv",
    "real_model_generation_abstain_fallback_rows.csv",
    "real_model_generation_latency_rows.csv",
    "real_model_generation_acceptance_summary.json",
}
if {row["artifact_name"] for row in artifact_rows} != required_artifacts:
    raise SystemExit("v61cd required artifact set mismatch")

for requirement_id in ["v61cc-admission-bridge-input", "remaining-page-hash-return", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cd requirement should pass: {requirement_id}")
for requirement_id in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "generation-unblocker-closure",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cd requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cd_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cd metric {field}: expected {value}, got {metric[field]}")

for gate in ["v61cc-admission-bridge-input", "operator-closure-bundle", "remaining-page-hash-return", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cd gate should pass: {gate}")
for gate in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "actual-model-generation",
    "production-latency",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cd gate should stay blocked: {gate}")

if gaps["v61cc-admission-bridge-input"] != "ready":
    raise SystemExit("v61cd v61cc input gap should be ready")
if gaps.get("remaining-page-hash-return") != "ready":
    raise SystemExit("v61cd page-hash return gap should be ready")
for gap in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cd gap should stay blocked: {gap}")

boundary = (run_dir / "V61CD_UBUNTU1_GENERATION_UNBLOCKER_CLOSURE_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "closure_phase_rows=3",
    "return_artifact_rows=11",
    "operator_command_rows=7",
    "page_hash_return_required_rows=0",
    "human_review_required_rows=7000",
    "adjudication_required_rows=1000",
    "generation_result_required_artifacts=5",
    "generation_execution_admitted_rows=0",
    "page_hash_blocked_rows=0",
    "review_return_blocked_rows=1000",
    "generation_result_artifact_blocked_rows=1000",
    "generation_unblocker_closure_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cd=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cd boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cd_ubuntu1_generation_unblocker_closure_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cd_ubuntu1_generation_unblocker_closure_bundle_ready") != 1:
    raise SystemExit("v61cd manifest readiness mismatch")
if manifest.get("closure_phase_rows") != 3:
    raise SystemExit("v61cd manifest phase count mismatch")
if manifest.get("return_artifact_rows") != 11:
    raise SystemExit("v61cd manifest artifact count mismatch")
if manifest.get("operator_command_rows") != 7:
    raise SystemExit("v61cd manifest command count mismatch")
if manifest.get("page_hash_return_required_rows") != 0:
    raise SystemExit("v61cd manifest page-hash required mismatch")
if manifest.get("human_review_required_rows") != 7000:
    raise SystemExit("v61cd manifest review required mismatch")
if manifest.get("generation_unblocker_closure_ready") != 0:
    raise SystemExit("v61cd manifest closure should remain blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cd manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61cd") != 0:
    raise SystemExit("v61cd manifest must keep downloaded bytes at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cd manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cd sha256 mismatch: {rel}")
PY

echo "v61cd ubuntu-1 generation unblocker closure bundle smoke passed"
