#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv"

V61CM_REUSE_EXISTING="${V61CM_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
source_queue_rows = read_csv(run_dir / "source_v61cl/remaining_checkpoint_materialization_return_queue_status_rows.csv")
source_preservation_rows = [row for row in read_csv(run_dir / "source_v61cl/existing_checkpoint_materialization_preservation_rows.csv") if row["shard_name"] != "none"]
expected_remaining_rows = len(source_queue_rows)
expected_remaining_bytes = sum(int(row["expected_bytes"]) for row in source_queue_rows)
expected_missing_rows = sum(int(row["missing_return_rows"]) for row in source_queue_rows)
expected_missing_bytes = sum(int(row["missing_bytes"]) for row in source_queue_rows)
expected_accepted_rows = sum(int(row["accepted_return_rows"]) for row in source_queue_rows)
expected_accepted_bytes = sum(int(row["accepted_bytes"]) for row in source_queue_rows)
existing_verified_rows = len(source_preservation_rows)
existing_verified_bytes = sum(int(row["identity_verified_bytes"]) for row in source_preservation_rows)
total_required_rows = expected_remaining_rows + existing_verified_rows
total_identity_verified_rows = existing_verified_rows + expected_accepted_rows
expected_full_ready = "1" if (
    total_required_rows == total_identity_verified_rows
    and expected_missing_rows == 0
    and expected_missing_bytes == 0
) else "0"
expected_full_status = "pass" if expected_full_ready == "1" else "blocked"
expected_full_gap = "ready" if expected_full_ready == "1" else "blocked"

expected = {
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready": "1",
    "checkpoint_shard_rows": str(total_required_rows),
    "ready_checkpoint_materialization_shard_rows": str(existing_verified_rows + expected_accepted_rows),
    "blocked_checkpoint_materialization_shard_rows": str(expected_missing_rows),
    "existing_identity_verified_checkpoint_shard_rows": str(existing_verified_rows),
    "remaining_materialization_shard_rows": str(expected_remaining_rows),
    "expected_remaining_materialization_return_rows": str(expected_remaining_rows),
    "accepted_remaining_materialization_return_rows": str(expected_accepted_rows),
    "missing_remaining_materialization_return_rows": str(expected_missing_rows),
    "invalid_remaining_materialization_return_rows": "0",
    "expected_remaining_materialization_bytes": str(expected_remaining_bytes),
    "accepted_remaining_materialization_bytes": str(expected_accepted_bytes),
    "missing_remaining_materialization_bytes": str(expected_missing_bytes),
    "existing_verified_checkpoint_shard_rows": str(existing_verified_rows),
    "existing_verified_checkpoint_shard_bytes": str(existing_verified_bytes),
    "total_required_checkpoint_shard_rows": str(total_required_rows),
    "total_identity_verified_checkpoint_shard_rows": str(total_identity_verified_rows),
    "promotion_identity_verified_bytes": str(existing_verified_bytes + expected_accepted_bytes),
    "promotion_missing_materialization_bytes": str(expected_missing_bytes),
    "promotion_invalid_materialization_return_rows": "0",
    "full_checkpoint_materialization_promotion_ready": expected_full_ready,
    "full_checkpoint_materialization_ready": expected_full_ready,
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cm {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "full_checkpoint_materialization_promotion_rows.csv",
    "full_checkpoint_materialization_promotion_requirement_rows.csv",
    "full_checkpoint_materialization_promotion_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CM_UBUNTU1_FULL_CHECKPOINT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md",
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61cl/remaining_checkpoint_materialization_return_queue_status_rows.csv",
    "source_v61cl/remaining_checkpoint_materialization_return_chunk_status_rows.csv",
    "source_v61cl/existing_checkpoint_materialization_preservation_rows.csv",
    "source_v61cl/remaining_checkpoint_materialization_return_validation_rows.csv",
    "source_v61cl/remaining_checkpoint_materialization_return_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cm artifact: {rel}")

promotion_rows = read_csv(run_dir / "full_checkpoint_materialization_promotion_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "full_checkpoint_materialization_promotion_requirement_rows.csv")}
metric = read_csv(run_dir / "full_checkpoint_materialization_promotion_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(promotion_rows) != total_required_rows:
    raise SystemExit("v61cm promotion row count mismatch")
status_counts = Counter(row["promotion_status"] for row in promotion_rows)
if status_counts["ready-existing-identity-verified-shard"] != existing_verified_rows:
    raise SystemExit(f"v61cm existing ready shard mismatch: {status_counts}")
if status_counts["blocked-missing-materialization-return"] != expected_missing_rows:
    raise SystemExit(f"v61cm blocked shard mismatch: {status_counts}")
if sum(int(row["existing_identity_verified_bytes"]) for row in promotion_rows) != existing_verified_bytes:
    raise SystemExit("v61cm existing identity verified byte sum mismatch")
if sum(int(row["expected_remaining_materialization_bytes"]) for row in promotion_rows) != expected_remaining_bytes:
    raise SystemExit("v61cm expected remaining byte sum mismatch")
if sum(int(row["accepted_remaining_materialization_return_rows"]) for row in promotion_rows) != expected_accepted_rows:
    raise SystemExit("v61cm accepted return row sum mismatch")
if sum(int(row["missing_remaining_materialization_return_rows"]) for row in promotion_rows) != expected_missing_rows:
    raise SystemExit("v61cm missing return row sum mismatch")
if sum(int(row["identity_verified_bytes"]) for row in promotion_rows) != existing_verified_bytes + expected_accepted_bytes:
    raise SystemExit("v61cm identity verified byte sum mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cm"] != "0" for row in promotion_rows):
    raise SystemExit("v61cm must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in promotion_rows):
    raise SystemExit("v61cm must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in promotion_rows):
    raise SystemExit("v61cm must keep route jumps at zero")

for requirement_id in ["v61cl-return-intake-input", "manifest-only-no-repo-payload"]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cm requirement should pass: {requirement_id}")
for requirement_id in [
    "remaining-materialization-return-intake-ready",
    "all-shard-checkpoint-materialization-ready",
    "completed-full-checkpoint-materialization",
]:
    if requirements[requirement_id]["status"] != expected_full_status:
        raise SystemExit(f"v61cm requirement status mismatch: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cm_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cm metric {field}: expected {value}, got {metric[field]}")

for gate in ["v61cl-return-intake-input", "existing-checkpoint-materialization-preservation", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cm gate should pass: {gate}")
for gate in [
    "remaining-materialization-return-intake-ready",
    "all-shard-checkpoint-materialization-ready",
    "completed-full-checkpoint-materialization",
]:
    if decisions.get(gate) != expected_full_status:
        raise SystemExit(f"v61cm gate status mismatch: {gate}")
for gate in ["full-safetensors-page-hash-binding", "actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cm gate should stay blocked: {gate}")

if gaps["v61cl-return-intake-input"] != "ready":
    raise SystemExit("v61cm v61cl input gap should be ready")
for gap in [
    "remaining-materialization-return-intake-ready",
    "all-shard-checkpoint-materialization-ready",
    "completed-full-checkpoint-materialization",
]:
    if gaps.get(gap) != expected_full_gap:
        raise SystemExit(f"v61cm gap status mismatch: {gap}")
for gap in ["full-safetensors-page-hash-binding", "actual-model-generation", "production-latency", "release-package"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cm gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready") != 1:
    raise SystemExit("v61cm manifest readiness mismatch")
if manifest.get("checkpoint_shard_rows") != total_required_rows:
    raise SystemExit("v61cm manifest shard row mismatch")
if manifest.get("total_identity_verified_checkpoint_shard_rows") != total_identity_verified_rows:
    raise SystemExit("v61cm manifest verified shard mismatch")
if manifest.get("full_checkpoint_materialization_ready") != int(expected_full_ready):
    raise SystemExit("v61cm manifest full materialization readiness mismatch")

boundary = (run_dir / "V61CM_UBUNTU1_FULL_CHECKPOINT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"checkpoint_shard_rows={total_required_rows}",
    f"ready_checkpoint_materialization_shard_rows={existing_verified_rows}",
    f"blocked_checkpoint_materialization_shard_rows={expected_missing_rows}",
    f"expected_remaining_materialization_return_rows={expected_remaining_rows}",
    f"accepted_remaining_materialization_return_rows={expected_accepted_rows}",
    f"missing_remaining_materialization_return_rows={expected_missing_rows}",
    f"expected_remaining_materialization_bytes={expected_remaining_bytes}",
    f"missing_remaining_materialization_bytes={expected_missing_bytes}",
    f"existing_verified_checkpoint_shard_rows={existing_verified_rows}",
    f"total_required_checkpoint_shard_rows={total_required_rows}",
    f"total_identity_verified_checkpoint_shard_rows={total_identity_verified_rows}",
    f"full_checkpoint_materialization_promotion_ready={expected_full_ready}",
    f"full_checkpoint_materialization_ready={expected_full_ready}",
    "checkpoint_payload_bytes_downloaded_by_v61cm=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cm boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cm sha256 mismatch: {rel}")
PY

echo "v61cm ubuntu-1 full checkpoint materialization promotion gate smoke passed"
