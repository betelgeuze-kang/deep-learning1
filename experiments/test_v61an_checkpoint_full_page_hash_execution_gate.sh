#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61an_checkpoint_full_page_hash_execution_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61an_checkpoint_full_page_hash_execution_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61an_checkpoint_full_page_hash_execution_gate_decision.csv"

V61AN_REUSE_EXISTING="${V61AN_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61an_checkpoint_full_page_hash_execution_gate.sh" >/dev/null

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
expected = {
    "v61an_checkpoint_full_page_hash_execution_gate_ready": "1",
    "v61am_checkpoint_post_activation_verification_gate_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "warehouse_root_override_supplied": "0",
    "checkpoint_shard_rows": "59",
    "required_page_hash_rows": "134161",
    "planned_page_hash_rows": "134161",
    "page_hash_execution_chunk_size_pages": "512",
    "execution_chunk_rows": "291",
    "executable_chunk_rows": "0",
    "hashed_chunk_rows": "0",
    "blocked_chunk_rows": "291",
    "blocked_activation_chunk_rows": "291",
    "blocked_identity_chunk_rows": "0",
    "blocked_execution_disabled_chunk_rows": "0",
    "activation_admitted_shard_rows": "0",
    "local_identity_verified_shard_rows": "0",
    "local_full_page_hash_verified_rows": "0",
    "local_full_page_hash_verified_bytes": "0",
    "full_page_hash_execution_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "post_activation_verification_gate_ready": "0",
    "download_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61an": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61an {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_full_page_hash_execution_chunk_rows.csv",
    "local_full_page_hash_verification_rows.csv",
    "checkpoint_full_page_hash_execution_requirement_rows.csv",
    "checkpoint_full_page_hash_execution_metric_rows.csv",
    "V61AN_CHECKPOINT_FULL_PAGE_HASH_EXECUTION_GATE_BOUNDARY.md",
    "v61an_checkpoint_full_page_hash_execution_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61am/checkpoint_post_activation_verification_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "source_v61r/shard_page_hash_sweep_status_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61an artifact: {rel}")

chunk_rows = read_csv(run_dir / "checkpoint_full_page_hash_execution_chunk_rows.csv")
verification_rows = read_csv(run_dir / "local_full_page_hash_verification_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "checkpoint_full_page_hash_execution_requirement_rows.csv")}
metric = read_csv(run_dir / "checkpoint_full_page_hash_execution_metric_rows.csv")[0]

if len(chunk_rows) != 291:
    raise SystemExit("v61an execution chunk row count mismatch")
if len(verification_rows) != 0:
    raise SystemExit("v61an should not emit local page hashes on the current host")
if sum(int(row["planned_page_hash_rows"]) for row in chunk_rows) != 134161:
    raise SystemExit("v61an planned page total mismatch")
if chunk_rows[0]["priority_rank"] != "1":
    raise SystemExit("v61an chunk ordering should follow post-activation priority")
if any(row["execution_chunk_status"] != "blocked-activation-not-admitted" for row in chunk_rows):
    raise SystemExit("v61an chunks should be blocked by activation on this host")
if any(row["activation_admitted"] != "0" for row in chunk_rows):
    raise SystemExit("v61an activation should not be admitted by default")
if any(row["local_identity_verified"] != "0" for row in chunk_rows):
    raise SystemExit("v61an local identity should not be verified by default")
if any(row["checkpoint_payload_bytes_downloaded_by_v61an"] != "0" for row in chunk_rows):
    raise SystemExit("v61an must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in chunk_rows):
    raise SystemExit("v61an must not commit checkpoint payload bytes")

for requirement_id in [
    "activation-admitted-all-shards",
    "local-identity-verified-all-shards",
    "full-page-hash-execution-chunks",
    "full-safetensors-page-hash-binding",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61an requirement should be blocked: {requirement_id}")
if requirements["manifest-only-no-repo-payload"]["status"] != "pass":
    raise SystemExit("v61an manifest-only requirement should pass")
if requirements["full-safetensors-page-hash-binding"]["required_rows"] != "134161":
    raise SystemExit("v61an full page hash required rows mismatch")
if requirements["full-safetensors-page-hash-binding"]["actual_rows"] != "0":
    raise SystemExit("v61an full page hash actual rows mismatch")

for field, value in expected.items():
    if field.startswith("v61an_") or field.startswith("v61am_") or field.startswith("v61t_") or field.startswith("v61r_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61an metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61am-post-activation-input",
    "v61t-materialization-input",
    "v61r-full-page-hash-plan-input",
    "full-page-hash-execution-schedule",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61an gate should pass: {gate}")
for gate in [
    "activation-admission",
    "local-identity-verification",
    "full-page-hash-execution",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61an gate should stay blocked: {gate}")

boundary = (run_dir / "V61AN_CHECKPOINT_FULL_PAGE_HASH_EXECUTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "required_page_hash_rows=134161",
    "planned_page_hash_rows=134161",
    "execution_chunk_rows=291",
    "blocked_activation_chunk_rows=291",
    "local_full_page_hash_verified_rows=0",
    "full_page_hash_execution_ready=0",
    "full_safetensors_page_hash_binding_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61an=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61an boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61an_checkpoint_full_page_hash_execution_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61an_checkpoint_full_page_hash_execution_gate_ready") != 1:
    raise SystemExit("v61an manifest readiness mismatch")
if manifest.get("execution_chunk_rows") != 291:
    raise SystemExit("v61an manifest chunk rows mismatch")
if manifest.get("local_full_page_hash_verified_rows") != 0:
    raise SystemExit("v61an manifest verified rows mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61an") != 0:
    raise SystemExit("v61an manifest must keep downloaded payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61an sha256 mismatch: {rel}")
PY

echo "v61an checkpoint full page hash execution gate smoke passed"
