#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cn_ubuntu1_page_hash_execution_materialization_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_decision.csv"

V61CN_REUSE_EXISTING="${V61CN_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cn_ubuntu1_page_hash_execution_materialization_admission_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
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
source_chunks = read_csv(run_dir / "source_v61bz/remaining_page_hash_execution_chunk_rows.csv")
expected_chunk_rows = len(source_chunks)
expected_page_hash_rows = sum(int(row["planned_page_hash_rows"]) for row in source_chunks)
page_size = 2 * 1024 * 1024
expected_page_hash_bytes = 0
for row in source_chunks:
    chunk_start = int(row["chunk_page_start_index"]) * page_size
    chunk_end = int(row["chunk_page_end_index_exclusive"]) * page_size
    shard_bytes = int(row["shard_remaining_page_hash_bytes"])
    expected_page_hash_bytes += max(0, min(chunk_end, shard_bytes) - min(chunk_start, shard_bytes))
expected_blocked_shards = len({row["shard_name"] for row in source_chunks})

expected = {
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": "1",
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    "remaining_page_hash_execution_chunk_rows": str(expected_chunk_rows),
    "admitted_page_hash_execution_chunk_rows": "0",
    "materialization_blocked_page_hash_execution_chunk_rows": "0",
    "admitted_page_hash_rows": "0",
    "blocked_page_hash_rows": "0",
    "admitted_page_hash_bytes": "0",
    "blocked_page_hash_bytes": "0",
    "materialization_blocked_shard_rows": "0",
    "ready_checkpoint_materialization_shard_rows": "59",
    "blocked_checkpoint_materialization_shard_rows": "0",
    "full_checkpoint_materialization_ready": "1",
    "remaining_page_hash_operator_bundle_ready": "1",
    "page_hash_execution_admission_ready": "1",
    "page_hash_execution_ready": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cn {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "page_hash_execution_materialization_admission_rows.csv",
    "page_hash_execution_materialization_admission_requirement_rows.csv",
    "page_hash_execution_materialization_admission_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CN_UBUNTU1_PAGE_HASH_EXECUTION_MATERIALIZATION_ADMISSION_GATE_BOUNDARY.md",
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61bz/remaining_page_hash_execution_chunk_rows.csv",
    "source_v61bz/verified_page_hash_skip_rows.csv",
    "source_v61cm/full_checkpoint_materialization_promotion_rows.csv",
    "source_v61cm/full_checkpoint_materialization_promotion_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cn artifact: {rel}")

admission_rows = read_csv(run_dir / "page_hash_execution_materialization_admission_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "page_hash_execution_materialization_admission_requirement_rows.csv")}
metric = read_csv(run_dir / "page_hash_execution_materialization_admission_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(admission_rows) != expected_chunk_rows:
    raise SystemExit("v61cn admission row count mismatch")
if any(row["page_hash_execution_admitted"] != "0" for row in admission_rows):
    raise SystemExit("v61cn should admit no page-hash chunks by default")
if any(row["page_hash_execution_admission_status"] != "blocked-materialization-not-ready" for row in admission_rows):
    raise SystemExit("v61cn default rows should be materialization-blocked")
if sum(int(row["planned_page_hash_rows"]) for row in admission_rows) != expected_page_hash_rows:
    raise SystemExit("v61cn planned page-hash row sum mismatch")
if sum(int(row["planned_page_hash_bytes"]) for row in admission_rows) != expected_page_hash_bytes:
    raise SystemExit("v61cn planned page-hash byte sum mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cn"] != "0" for row in admission_rows):
    raise SystemExit("v61cn must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in admission_rows):
    raise SystemExit("v61cn must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in admission_rows):
    raise SystemExit("v61cn must keep route jumps at zero")

for requirement_id in [
    "v61bz-page-hash-operator-bundle-input",
    "v61cm-full-materialization-promotion-input",
    "full-checkpoint-materialization-ready-before-page-hash",
    "all-remaining-page-hash-chunks-admitted",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cn requirement should pass: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cn_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cn metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61bz-page-hash-operator-bundle-input",
    "v61cm-full-materialization-promotion-input",
    "full-checkpoint-materialization-ready-before-page-hash",
    "all-remaining-page-hash-chunks-admitted",
    "completed-full-safetensors-page-hash-coverage",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cn gate should pass: {gate}")
if decisions.get("page-hash-execution") != "not-applicable":
    raise SystemExit("v61cn page-hash execution should be not-applicable with zero chunks")
for gate in [
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cn gate should stay blocked: {gate}")

for gap in [
    "v61bz-page-hash-operator-bundle-input",
    "v61cm-full-materialization-promotion-input",
    "full-checkpoint-materialization-ready-before-page-hash",
    "all-remaining-page-hash-chunks-admitted",
    "completed-full-safetensors-page-hash-coverage",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cn gap should be ready: {gap}")
if gaps.get("page-hash-execution") != "not-applicable":
    raise SystemExit("v61cn page-hash-execution gap should be not-applicable")
for gap in [
    "actual-model-generation",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cn gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready") != 1:
    raise SystemExit("v61cn manifest readiness mismatch")
if manifest.get("admitted_page_hash_execution_chunk_rows") != 0:
    raise SystemExit("v61cn manifest admitted chunk count mismatch")
if manifest.get("page_hash_execution_admission_ready") != 1:
    raise SystemExit("v61cn manifest should mark admission ready")

boundary = (run_dir / "V61CN_UBUNTU1_PAGE_HASH_EXECUTION_MATERIALIZATION_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"remaining_page_hash_execution_chunk_rows={expected_chunk_rows}",
    "admitted_page_hash_execution_chunk_rows=0",
    "materialization_blocked_page_hash_execution_chunk_rows=0",
    "blocked_page_hash_rows=0",
    "blocked_page_hash_bytes=0",
    "materialization_blocked_shard_rows=0",
    "full_checkpoint_materialization_ready=1",
    "remaining_page_hash_operator_bundle_ready=1",
    "page_hash_execution_admission_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61cn=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cn boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cn sha256 mismatch: {rel}")
PY

echo "v61cn ubuntu-1 page-hash execution materialization admission gate smoke passed"
