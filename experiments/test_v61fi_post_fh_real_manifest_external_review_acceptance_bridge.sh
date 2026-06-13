#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fi_post_fh_real_manifest_external_review_acceptance_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BRIDGE_DIR="$RUN_DIR/real_manifest_external_review_acceptance_bridge"

V61FI_REUSE_EXISTING="${V61FI_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$BRIDGE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
bridge_dir = Path(sys.argv[4])


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
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": "1",
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fg_post_ff_real_manifest_external_review_packet_ready": "1",
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": "1",
    "bridge_rows": "12",
    "ready_bridge_rows": "4",
    "blocked_bridge_rows": "8",
    "blocker_rows": "8",
    "next_action_rows": "6",
    "ready_next_action_rows": "3",
    "claim_boundary_rows": "4",
    "blocked_claim_boundary_rows": "3",
    "bridge_file_rows": "9",
    "metadata_only_bridge_file_rows": "9",
    "required_review_return_artifacts": "6",
    "accepted_review_return_artifacts": "0",
    "missing_review_return_artifacts": "6",
    "review_checklist_rows": "13",
    "accepted_review_checklist_rows": "0",
    "claim_boundary_review_rows": "5",
    "accepted_claim_boundary_rows": "0",
    "candidate_external_review_return_ready": "0",
    "external_review_return_ready": "0",
    "real_manifest_runtime_evidence_review_ready": "1",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fi": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fi {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fh_real_manifest_external_review_acceptance_bridge_rows.csv",
    "post_fh_real_manifest_external_review_acceptance_blocker_rows.csv",
    "post_fh_real_manifest_external_review_next_action_rows.csv",
    "post_fh_real_manifest_external_review_claim_boundary_rows.csv",
    "V61FI_POST_FH_REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_BOUNDARY.md",
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_manifest.json",
    "real_manifest_external_review_acceptance_bridge/EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_ROWS.csv",
    "real_manifest_external_review_acceptance_bridge/EXTERNAL_REVIEW_ACCEPTANCE_BLOCKER_ROWS.csv",
    "real_manifest_external_review_acceptance_bridge/EXTERNAL_REVIEW_NEXT_ACTION_ROWS.csv",
    "real_manifest_external_review_acceptance_bridge/EXTERNAL_REVIEW_CLAIM_BOUNDARY_ROWS.csv",
    "real_manifest_external_review_acceptance_bridge/EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_SUMMARY.md",
    "real_manifest_external_review_acceptance_bridge/VERIFY_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE.sh",
    "real_manifest_external_review_acceptance_bridge/BRIDGE_MANIFEST.json",
    "real_manifest_external_review_acceptance_bridge/BRIDGE_FILE_LIST.txt",
    "real_manifest_external_review_acceptance_bridge/BRIDGE_SHA256SUMS.txt",
    "source_v61fh/real_manifest_external_review_return_artifact_status_rows.csv",
    "source_v61fh/real_manifest_external_review_return_acceptance_rows.csv",
    "source_v61fg/post_ff_real_manifest_external_review_checklist_rows.csv",
    "source_v61ff/post_fe_real_manifest_replay_readiness_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fi artifact: {rel}")

bridge_rows = {row["bridge_id"]: row for row in read_csv(run_dir / "post_fh_real_manifest_external_review_acceptance_bridge_rows.csv")}
for bridge_id in [
    "01-v61fh-return-intake-ready",
    "02-v61fg-review-packet-ready",
    "03-review-return-contract-ready",
    "04-real-manifest-runtime-evidence-review-ready",
]:
    if bridge_rows[bridge_id]["status"] != "ready":
        raise SystemExit(f"v61fi bridge row should be ready: {bridge_id}")
for bridge_id in [
    "05-candidate-external-review-return",
    "06-real-external-review-return",
    "07-review-checklist-acceptance",
    "08-claim-boundary-acceptance",
    "09-real-return-replay-admission",
    "10-row-acceptance",
    "11-actual-model-generation",
    "12-release-claims",
]:
    if bridge_rows[bridge_id]["status"] != "blocked":
        raise SystemExit(f"v61fi bridge row should stay blocked: {bridge_id}")

blockers = read_csv(run_dir / "post_fh_real_manifest_external_review_acceptance_blocker_rows.csv")
if len(blockers) != 8:
    raise SystemExit("v61fi blocker row count mismatch")
next_actions = read_csv(run_dir / "post_fh_real_manifest_external_review_next_action_rows.csv")
if len(next_actions) != 6 or sum(row["status"] == "ready" for row in next_actions) != 3:
    raise SystemExit("v61fi next action shape mismatch")
claim_rows = {row["claim"]: row["status"] for row in read_csv(run_dir / "post_fh_real_manifest_external_review_claim_boundary_rows.csv")}
if claim_rows.get("reviewer-ready real page-manifest evidence packet") != "allowed-with-boundary":
    raise SystemExit("v61fi should allow reviewer-ready packet wording with boundary")
if claim_rows.get("actual model generation / near-frontier / latency / release") != "blocked":
    raise SystemExit("v61fi should block generation/release wording")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "01-v61fh-return-intake-ready",
    "02-v61fg-review-packet-ready",
    "03-review-return-contract-ready",
    "04-real-manifest-runtime-evidence-review-ready",
    "bridge-shape",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fi decision should pass: {gate}")
for gate in [
    "05-candidate-external-review-return",
    "06-real-external-review-return",
    "07-review-checklist-acceptance",
    "08-claim-boundary-acceptance",
    "09-real-return-replay-admission",
    "10-row-acceptance",
    "11-actual-model-generation",
    "12-release-claims",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fi decision should stay blocked: {gate}")

manifest = json.loads((bridge_dir / "BRIDGE_MANIFEST.json").read_text(encoding="utf-8"))
for key in ["candidate_external_review_return_ready", "external_review_return_ready", "actual_model_generation_ready", "checkpoint_payload_bytes_committed_to_repo"]:
    if manifest.get(key) != 0:
        raise SystemExit(f"v61fi manifest must keep {key}=0")

if not os.access(bridge_dir / "VERIFY_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE.sh", os.X_OK):
    raise SystemExit("v61fi verifier must be executable")

boundary = (run_dir / "V61FI_POST_FH_REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "bridge_rows=12",
    "ready_bridge_rows=4",
    "blocked_bridge_rows=8",
    "accepted_review_return_artifacts=0/6",
    "accepted_review_checklist_rows=0/13",
    "accepted_claim_boundary_rows=0/5",
    "candidate_external_review_return_ready=0",
    "external_review_return_ready=0",
    "real_return_replay_admission_ready=0",
    "row_acceptance_ready=0",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fi boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fi sha256 mismatch: {rel}")
PY

"$BRIDGE_DIR/VERIFY_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fi produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fi post-fh real manifest external review acceptance bridge smoke passed"
