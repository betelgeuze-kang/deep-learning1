#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fg_post_ff_real_manifest_external_review_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKET_DIR="$RUN_DIR/real_manifest_external_review_packet"

V61FG_REUSE_EXISTING="${V61FG_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fg_post_ff_real_manifest_external_review_packet.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKET_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
packet_dir = Path(sys.argv[4])


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
    "v61fg_post_ff_real_manifest_external_review_packet_ready": "1",
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": "1",
    "v61ch_real_model_page_manifest_release_index_ready": "1",
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": "1",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "review_packet_rows": "13",
    "ready_review_packet_rows": "8",
    "blocked_review_packet_rows": "5",
    "claim_boundary_rows": "5",
    "blocked_claim_boundary_rows": "1",
    "review_command_rows": "6",
    "ready_review_command_rows": "5",
    "blocked_review_command_rows": "1",
    "packet_file_rows": "11",
    "metadata_only_packet_file_rows": "11",
    "source_pointer_rows": "4",
    "page_manifest_external_review_packet_ready": "1",
    "real_manifest_runtime_evidence_review_ready": "1",
    "checkpoint_shard_rows": "59",
    "ready_checkpoint_materialization_shard_rows": "59",
    "promotion_identity_verified_bytes": "281241493344",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "runtime_execution_candidate_rows": "37",
    "runtime_execution_admitted_rows": "37",
    "real_manifest_runtime_execution_admission_ready": "1",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "open_delta_rows": "14",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "external_review_return_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fg {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_ff_real_manifest_external_review_checklist_rows.csv",
    "post_ff_real_manifest_external_review_blocker_rows.csv",
    "post_ff_real_manifest_external_review_claim_rows.csv",
    "post_ff_real_manifest_external_review_command_rows.csv",
    "V61FG_POST_FF_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET_BOUNDARY.md",
    "v61fg_post_ff_real_manifest_external_review_packet_manifest.json",
    "real_manifest_external_review_packet/REVIEW_PACKET_MANIFEST.json",
    "real_manifest_external_review_packet/REVIEW_PACKET_SUMMARY.md",
    "real_manifest_external_review_packet/REVIEW_CHECKLIST.csv",
    "real_manifest_external_review_packet/REVIEW_CLAIM_BOUNDARY_ROWS.csv",
    "real_manifest_external_review_packet/REVIEW_BLOCKER_ROWS.csv",
    "real_manifest_external_review_packet/REVIEW_REPRODUCE_COMMAND_ROWS.csv",
    "real_manifest_external_review_packet/REVIEW_SOURCE_POINTERS.csv",
    "real_manifest_external_review_packet/REPRODUCE_REVIEW_PACKET.sh",
    "real_manifest_external_review_packet/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh",
    "real_manifest_external_review_packet/REVIEW_PACKET_FILE_LIST.txt",
    "real_manifest_external_review_packet/REVIEW_PACKET_SHA256SUMS.txt",
    "source_v61ch/release_index/MANIFEST_INDEX.csv",
    "source_v61co/real_manifest_runtime_execution_admission_rows.csv",
    "source_v61dg/post_full_shard_runtime_evidence_rows.csv",
    "source_v61ff/post_fe_real_manifest_replay_readiness_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fg artifact: {rel}")

checklist = {row["review_item_id"]: row for row in read_csv(run_dir / "post_ff_real_manifest_external_review_checklist_rows.csv")}
for item_id in [
    "01-zero-payload-release-index",
    "02-checkpoint-shard-identity",
    "03-full-page-hash-binding",
    "04-rocm-page-kernel-measurement",
    "05-kv-cache-residency-policy",
    "06-runtime-seed-admission",
    "07-v61ff-readiness-matrix",
    "08-review-packet-verifier",
]:
    if checklist[item_id]["status"] != "ready":
        raise SystemExit(f"v61fg review item should be ready: {item_id}")
for item_id in [
    "09-real-return-roots",
    "10-row-acceptance",
    "11-generation-execution-admission",
    "12-generation-result-acceptance",
    "13-actual-generation-release",
]:
    if checklist[item_id]["status"] != "blocked":
        raise SystemExit(f"v61fg review item should stay blocked: {item_id}")

blockers = read_csv(run_dir / "post_ff_real_manifest_external_review_blocker_rows.csv")
if len(blockers) != 5:
    raise SystemExit("v61fg blocker row count mismatch")
claims = {row["claim"]: row["status"] for row in read_csv(run_dir / "post_ff_real_manifest_external_review_claim_rows.csv")}
if claims.get("zero-payload real page-manifest release index") != "allowed":
    raise SystemExit("v61fg should allow zero-payload page-manifest wording")
if claims.get("actual Mixtral generation, near-frontier quality, production latency, or release readiness") != "blocked":
    raise SystemExit("v61fg should block generation/release wording")

commands = read_csv(run_dir / "post_ff_real_manifest_external_review_command_rows.csv")
if len(commands) != 6:
    raise SystemExit("v61fg command row count mismatch")
if sum(row["ready_to_run_now"] == "1" for row in commands) != 5:
    raise SystemExit("v61fg ready command row count mismatch")

manifest = json.loads((packet_dir / "REVIEW_PACKET_MANIFEST.json").read_text(encoding="utf-8"))
for key in ["real_return_replay_admission_ready", "row_acceptance_ready", "actual_model_generation_ready", "checkpoint_payload_bytes_committed_to_repo"]:
    if manifest.get(key) != 0:
        raise SystemExit(f"v61fg manifest must keep {key}=0")

for script_name in ["REPRODUCE_REVIEW_PACKET.sh", "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh"]:
    if not os.access(packet_dir / script_name, os.X_OK):
        raise SystemExit(f"v61fg script must be executable: {script_name}")

boundary = (run_dir / "V61FG_POST_FF_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "ready_review_packet_rows=8",
    "blocked_review_packet_rows=5",
    "page_manifest_external_review_packet_ready=1",
    "checkpoint_shard_rows=59/59",
    "total_verified_page_hash_rows=134161/134161",
    "runtime_execution_admitted_rows=37/37",
    "real_return_replay_admission_ready=0",
    "row_acceptance_ready=0",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "external_review_return_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fg boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fg sha256 mismatch: {rel}")
PY

"$PACKET_DIR/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh" >/dev/null
"$PACKET_DIR/REPRODUCE_REVIEW_PACKET.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fg produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fg post-ff real manifest external review packet smoke passed"
