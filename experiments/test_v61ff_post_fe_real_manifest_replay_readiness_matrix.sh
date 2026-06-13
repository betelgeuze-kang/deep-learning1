#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ff_post_fe_real_manifest_replay_readiness_matrix"
RUN_DIR="$RESULTS_DIR/$PREFIX/matrix_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
MATRIX_DIR="$RUN_DIR/real_manifest_replay_readiness_matrix"

V61FF_REUSE_EXISTING="${V61FF_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ff_post_fe_real_manifest_replay_readiness_matrix.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$MATRIX_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
matrix_dir = Path(sys.argv[4])


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
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": "1",
    "v61ch_real_model_page_manifest_release_index_ready": "1",
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": "1",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "v61fe_post_fd_real_return_replay_admission_guard_ready": "1",
    "matrix_rows": "16",
    "ready_matrix_rows": "7",
    "blocked_matrix_rows": "9",
    "blocker_rows": "9",
    "command_rows": "5",
    "ready_command_rows": "4",
    "blocked_command_rows": "1",
    "matrix_file_rows": "9",
    "metadata_only_matrix_file_rows": "9",
    "source_artifact_rows": "8",
    "release_index_file_rows": "10",
    "checkpoint_shard_rows": "59",
    "ready_checkpoint_materialization_shard_rows": "59",
    "promotion_identity_verified_bytes": "281241493344",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "full_safetensors_page_hash_binding_ready": "1",
    "post_full_shard_runtime_evidence_ready": "1",
    "runtime_execution_candidate_rows": "37",
    "runtime_execution_admitted_rows": "37",
    "real_manifest_runtime_execution_admission_ready": "1",
    "guard_rows": "10",
    "pass_guard_rows": "2",
    "blocked_guard_rows": "8",
    "open_delta_rows": "14",
    "dual_roots_supplied": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ff": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ff {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fe_real_manifest_replay_readiness_rows.csv",
    "post_fe_real_manifest_replay_blocker_rows.csv",
    "post_fe_real_manifest_replay_command_rows.csv",
    "V61FF_POST_FE_REAL_MANIFEST_REPLAY_READINESS_MATRIX_BOUNDARY.md",
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_manifest.json",
    "real_manifest_replay_readiness_matrix/REAL_MANIFEST_REPLAY_READINESS_ROWS.csv",
    "real_manifest_replay_readiness_matrix/REAL_MANIFEST_REPLAY_BLOCKER_ROWS.csv",
    "real_manifest_replay_readiness_matrix/REAL_MANIFEST_REPLAY_COMMAND_ROWS.csv",
    "real_manifest_replay_readiness_matrix/RUN_REAL_MANIFEST_REPLAY_IF_ADMITTED.sh",
    "real_manifest_replay_readiness_matrix/REAL_MANIFEST_REPLAY_SUMMARY.md",
    "real_manifest_replay_readiness_matrix/VERIFY_REAL_MANIFEST_REPLAY_MATRIX.sh",
    "real_manifest_replay_readiness_matrix/MATRIX_MANIFEST.json",
    "real_manifest_replay_readiness_matrix/MATRIX_FILE_LIST.txt",
    "real_manifest_replay_readiness_matrix/MATRIX_SHA256SUMS.txt",
    "source_v61ch/page_manifest_release_index_source_artifact_rows.csv",
    "source_v61ch/release_index/MANIFEST_INDEX.csv",
    "source_v61co/real_manifest_runtime_execution_admission_rows.csv",
    "source_v61dg/post_full_shard_runtime_evidence_rows.csv",
    "source_v61fe/post_fd_real_return_replay_admission_guard_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ff artifact: {rel}")

matrix_rows = {row["matrix_id"]: row for row in read_csv(run_dir / "post_fe_real_manifest_replay_readiness_rows.csv")}
for matrix_id in [
    "01-zero-payload-page-manifest-release-index",
    "02-full-checkpoint-materialization",
    "03-full-safetensors-page-hash-binding",
    "04-rocm-page-kernel-measurement",
    "05-kv-cache-residency-policy",
    "06-real-manifest-runtime-execution-admission",
    "07-v61fe-replay-admission-guard-ready",
]:
    if matrix_rows[matrix_id]["status"] != "ready":
        raise SystemExit(f"v61ff matrix row should be ready: {matrix_id}")
for matrix_id in [
    "08-dual-real-return-roots-supplied",
    "09-real-return-replay-admission",
    "10-row-acceptance-ready",
    "11-generation-execution-admission",
    "12-generation-result-artifact-acceptance",
    "13-actual-model-generation",
    "14-production-latency-claim",
    "15-near-frontier-quality-claim",
    "16-real-release-package",
]:
    if matrix_rows[matrix_id]["status"] != "blocked":
        raise SystemExit(f"v61ff matrix row should stay blocked: {matrix_id}")

blockers = read_csv(run_dir / "post_fe_real_manifest_replay_blocker_rows.csv")
if len(blockers) != 9:
    raise SystemExit("v61ff blocker row count mismatch")
commands = read_csv(run_dir / "post_fe_real_manifest_replay_command_rows.csv")
if len(commands) != 5:
    raise SystemExit("v61ff command row count mismatch")
if sum(row["ready_to_run_now"] == "1" for row in commands) != 4:
    raise SystemExit("v61ff ready command count mismatch")

manifest = json.loads((matrix_dir / "MATRIX_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("real_return_replay_admission_ready") != 0:
    raise SystemExit("v61ff manifest must keep replay admission blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ff manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ff manifest must keep checkpoint payload zero")

boundary = (run_dir / "V61FF_POST_FE_REAL_MANIFEST_REPLAY_READINESS_MATRIX_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "ready_matrix_rows=7",
    "blocked_matrix_rows=9",
    "checkpoint_shard_rows=59/59",
    "total_verified_page_hash_rows=134161/134161",
    "runtime_execution_admitted_rows=37/37",
    "real_return_replay_admission_ready=0",
    "row_acceptance_ready=0",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ff boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ff sha256 mismatch: {rel}")
PY

"$MATRIX_DIR/VERIFY_REAL_MANIFEST_REPLAY_MATRIX.sh" >/dev/null

if "$MATRIX_DIR/RUN_REAL_MANIFEST_REPLAY_IF_ADMITTED.sh" >/tmp/v61ff_should_not_run.out 2>/tmp/v61ff_should_not_run.err; then
  echo "v61ff guarded operator script unexpectedly ran without roots" >&2
  exit 1
fi

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ff produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ff post-fe real manifest replay readiness matrix smoke passed"
