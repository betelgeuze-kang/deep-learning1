#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CB_REUSE_EXISTING="${V61CB_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
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
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": "1",
    "target_root_path": ubuntu1_target,
    "checkpoint_shard_rows": "59",
    "ready_full_page_hash_shard_rows": "59",
    "blocked_full_page_hash_shard_rows": "0",
    "existing_verified_page_hash_shard_rows": "59",
    "remaining_page_hash_shard_rows": "0",
    "expected_remaining_page_hash_result_rows": "0",
    "accepted_remaining_page_hash_result_rows": "0",
    "missing_remaining_page_hash_result_rows": "0",
    "invalid_remaining_page_hash_result_rows": "0",
    "existing_verified_page_hash_rows": "134161",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "promotion_total_verified_page_hash_rows": "134161",
    "promotion_missing_page_hash_rows": "0",
    "promotion_invalid_page_hash_rows": "0",
    "full_page_hash_coverage_promotion_ready": "1",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cb {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "full_page_hash_coverage_promotion_rows.csv",
    "full_page_hash_coverage_promotion_requirement_rows.csv",
    "full_page_hash_coverage_promotion_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CB_UBUNTU1_FULL_PAGE_HASH_COVERAGE_PROMOTION_GATE_BOUNDARY.md",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61ca/remaining_page_hash_result_chunk_status_rows.csv",
    "source_v61ca/existing_page_hash_preservation_rows.csv",
    "source_v61ca/remaining_page_hash_result_validation_rows.csv",
    "source_v61ca/remaining_page_hash_result_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cb artifact: {rel}")

promotion_rows = read_csv(run_dir / "full_page_hash_coverage_promotion_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "full_page_hash_coverage_promotion_requirement_rows.csv")}
metric = read_csv(run_dir / "full_page_hash_coverage_promotion_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(promotion_rows) != 59:
    raise SystemExit("v61cb promotion row count mismatch")
status_counts = Counter(row["promotion_status"] for row in promotion_rows)
if status_counts["ready-existing-page-hash-witness"] != 59:
    raise SystemExit(f"v61cb existing ready shard mismatch: {status_counts}")
if status_counts["blocked-missing-remaining-page-hash-results"] != 0:
    raise SystemExit(f"v61cb blocked shard mismatch: {status_counts}")
if sum(int(row["existing_verified_page_hash_rows"]) for row in promotion_rows) != 134161:
    raise SystemExit("v61cb existing verified page hash sum mismatch")
if sum(int(row["planned_remaining_page_hash_rows"]) for row in promotion_rows) != 0:
    raise SystemExit("v61cb planned remaining page hash sum mismatch")
if sum(int(row["accepted_remaining_page_hash_rows"]) for row in promotion_rows) != 0:
    raise SystemExit("v61cb should accept no remaining rows by default")
if sum(int(row["missing_remaining_page_hash_rows"]) for row in promotion_rows) != 0:
    raise SystemExit("v61cb missing remaining page hash sum mismatch")
if sum(int(row["total_verified_page_hash_rows"]) for row in promotion_rows) != 134161:
    raise SystemExit("v61cb total verified page hash sum mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cb"] != "0" for row in promotion_rows):
    raise SystemExit("v61cb must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in promotion_rows):
    raise SystemExit("v61cb must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in promotion_rows):
    raise SystemExit("v61cb must keep route jumps at zero")

for requirement_id in [
    "v61ca-result-intake-input",
    "remaining-page-hash-result-intake-ready",
    "all-shard-page-hash-coverage-ready",
    "completed-full-safetensors-page-hash-coverage",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cb requirement should pass: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cb_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cb metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61ca-result-intake-input",
    "existing-page-hash-preservation",
    "remaining-page-hash-result-intake-ready",
    "all-shard-page-hash-coverage-ready",
    "completed-full-safetensors-page-hash-coverage",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cb gate should pass: {gate}")
for gate in [
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cb gate should stay blocked: {gate}")

if gaps["v61ca-result-intake-input"] != "ready":
    raise SystemExit("v61cb v61ca input gap should be ready")
for gap in [
    "remaining-page-hash-result-intake-ready",
    "all-shard-page-hash-coverage-ready",
    "completed-full-safetensors-page-hash-coverage",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cb gap should be ready: {gap}")
for gap in [
    "actual-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cb gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready") != 1:
    raise SystemExit("v61cb manifest readiness mismatch")
if manifest.get("checkpoint_shard_rows") != 59:
    raise SystemExit("v61cb manifest shard row mismatch")
if manifest.get("total_verified_page_hash_rows") != 134161:
    raise SystemExit("v61cb manifest verified row mismatch")
if manifest.get("full_safetensors_page_hash_binding_ready") != 1:
    raise SystemExit("v61cb manifest should mark full coverage ready")

boundary = (run_dir / "V61CB_UBUNTU1_FULL_PAGE_HASH_COVERAGE_PROMOTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "checkpoint_shard_rows=59",
    "ready_full_page_hash_shard_rows=59",
    "blocked_full_page_hash_shard_rows=0",
    "expected_remaining_page_hash_result_rows=0",
    "accepted_remaining_page_hash_result_rows=0",
    "missing_remaining_page_hash_result_rows=0",
    "existing_verified_page_hash_rows=134161",
    "total_required_page_hash_rows=134161",
    "total_verified_page_hash_rows=134161",
    "full_page_hash_coverage_promotion_ready=1",
    "full_safetensors_page_hash_binding_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61cb=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cb boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cb sha256 mismatch: {rel}")
PY

echo "v61cb ubuntu-1 full page-hash coverage promotion gate smoke passed"
