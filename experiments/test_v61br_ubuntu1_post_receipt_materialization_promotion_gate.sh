#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61br_ubuntu1_post_receipt_materialization_promotion_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61br_ubuntu1_post_receipt_materialization_promotion_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61br_ubuntu1_post_receipt_materialization_promotion_gate_decision.csv"

V61BR_REUSE_EXISTING="${V61BR_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61br_ubuntu1_post_receipt_materialization_promotion_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"


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
    "v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": "1",
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "target_root_count": "1",
    "target_root_path": ubuntu1_target,
    "target_root_outside_repo": "1",
    "tmp_target_rows": "0",
    "repo_local_target_rows": "0",
    "checkpoint_shard_rows": "59",
    "expected_payload_execution_receipt_rows": "59",
    "accepted_payload_execution_receipt_rows": "0",
    "missing_payload_execution_receipt_rows": "59",
    "live_existing_shard_rows": "0",
    "live_size_match_shard_rows": "0",
    "receipt_backed_materialization_input_ready": "0",
    "identity_verification_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "required_page_hash_rows": "134161",
    "verified_page_hash_rows": "0",
    "full_page_hash_execution_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "accepted_human_review_rows": "0",
    "complete_source_review_return_ready": "0",
    "post_receipt_materialization_promotion_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61br": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61br {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_post_receipt_materialization_requirement_rows.csv",
    "ubuntu1_post_receipt_verification_command_rows.csv",
    "ubuntu1_post_receipt_materialization_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BR_UBUNTU1_POST_RECEIPT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md",
    "v61br_ubuntu1_post_receipt_materialization_promotion_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv",
    "source_v61bq/ubuntu1_payload_execution_receipt_status_rows.csv",
    "source_v61r/page_hash_sweep_metric_rows.csv",
    "source_v53t/complete_source_audit_readiness_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61br artifact: {rel}")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_post_receipt_materialization_requirement_rows.csv")}
if len(requirements) != 10:
    raise SystemExit("v61br requirement row count mismatch")
for requirement_id in [
    "v61bq-receipt-intake-input",
    "single-ubuntu1-target-root",
    "target-root-outside-repository",
    "no-stale-tmp-targets",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61br requirement should pass: {requirement_id}")
for requirement_id in [
    "accepted-execution-receipts",
    "live-size-match-shards",
    "identity-verification-execution-admission",
    "full-page-hash-execution-admission",
    "complete-source-review-return",
    "actual-model-generation-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61br requirement should stay blocked: {requirement_id}")

commands = read_csv(run_dir / "ubuntu1_post_receipt_verification_command_rows.csv")
if len(commands) != 3:
    raise SystemExit("v61br command row count mismatch")
command_by_id = {row["command_id"]: row for row in commands}
if command_by_id["v61br-identity-verification-ubuntu1"]["admission_ready"] != "0":
    raise SystemExit("v61br identity command should remain gated")
if "V61T_WAREHOUSE_ROOT=" + ubuntu1_target not in command_by_id["v61br-identity-verification-ubuntu1"]["command"]:
    raise SystemExit("v61br identity command must target ubuntu-1")
if "V61AN_ENABLE_LOCAL_HASH_EXECUTION=1" not in command_by_id["v61br-full-page-hash-ubuntu1"]["command"]:
    raise SystemExit("v61br full page hash command must enable local hash execution explicitly")
if any("/tmp/" in row["command"] for row in commands):
    raise SystemExit("v61br commands must not use stale /tmp target paths")
if any(row["checkpoint_payload_bytes_downloaded_by_v61br"] != "0" for row in commands):
    raise SystemExit("v61br must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in commands):
    raise SystemExit("v61br must not commit checkpoint payload bytes")

metric = read_csv(run_dir / "ubuntu1_post_receipt_materialization_metric_rows.csv")[0]
for field, value in expected.items():
    if field.startswith("v61br_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61br metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61bq-receipt-intake-input", "ubuntu1-target-contract", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61br gate should pass: {gate}")
for gate in [
    "receipt-backed-materialization-input",
    "live-size-match-shards",
    "identity-verification-execution",
    "full-page-hash-execution",
    "complete-source-review-return",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61br gate should stay blocked: {gate}")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in ["v61bq-receipt-intake", "ubuntu1-target-contract"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61br gap should be ready: {gap}")
for gap in [
    "accepted-payload-execution-receipts",
    "live-size-match-shards",
    "identity-verification-rerun",
    "full-page-hash-execution",
    "complete-source-review-return",
    "actual-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61br gap should stay blocked: {gap}")

boundary = (run_dir / "V61BR_UBUNTU1_POST_RECEIPT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"target_root_path={ubuntu1_target}",
    "tmp_target_rows=0",
    "accepted_payload_execution_receipt_rows=0",
    "live_size_match_shard_rows=0",
    "identity_verification_execution_ready=0",
    "required_page_hash_rows=134161",
    "verified_page_hash_rows=0",
    "complete_source_review_return_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61br=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61br boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61br_ubuntu1_post_receipt_materialization_promotion_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready") != 1:
    raise SystemExit("v61br manifest readiness mismatch")
if manifest.get("target_root_path") != ubuntu1_target:
    raise SystemExit("v61br manifest target root mismatch")
if manifest.get("accepted_payload_execution_receipt_rows") != 0:
    raise SystemExit("v61br manifest accepted receipt mismatch")
if manifest.get("identity_verification_execution_ready") != 0:
    raise SystemExit("v61br manifest identity admission should be blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61br") != 0:
    raise SystemExit("v61br manifest must keep downloaded bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61br sha256 mismatch: {rel}")
PY

echo "v61br ubuntu-1 post-receipt materialization promotion gate smoke passed"
