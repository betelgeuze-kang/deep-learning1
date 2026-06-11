#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61am_checkpoint_post_activation_verification_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61am_checkpoint_post_activation_verification_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61am_checkpoint_post_activation_verification_gate_decision.csv"

V61AM_REUSE_EXISTING="${V61AM_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61am_checkpoint_post_activation_verification_gate.sh" >/dev/null

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
    "v61am_checkpoint_post_activation_verification_gate_ready": "1",
    "v61al_checkpoint_warehouse_activation_gate_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "warehouse_root_override_supplied": "0",
    "post_activation_verification_rows": "59",
    "post_activation_verification_ready_rows": "0",
    "post_activation_verification_blocked_rows": "59",
    "activation_command_rows": "59",
    "activation_admitted_rows": "0",
    "activation_blocked_rows": "59",
    "local_identity_verified_shard_rows": "0",
    "full_page_hash_coverage_ready_shard_rows": "0",
    "verified_page_hash_rows": "0",
    "required_page_hash_rows": "134161",
    "post_activation_verification_gate_ready": "0",
    "generation_gate_ready_after_post_activation": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61am": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61am {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_post_activation_verification_rows.csv",
    "checkpoint_post_activation_requirement_rows.csv",
    "checkpoint_post_activation_metric_rows.csv",
    "V61AM_CHECKPOINT_POST_ACTIVATION_VERIFICATION_GATE_BOUNDARY.md",
    "v61am_checkpoint_post_activation_verification_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61al/checkpoint_warehouse_activation_command_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "source_v61r/shard_page_hash_sweep_status_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61am artifact: {rel}")

verification_rows = read_csv(run_dir / "checkpoint_post_activation_verification_rows.csv")
if len(verification_rows) != 59:
    raise SystemExit("v61am verification row count mismatch")
if [row["priority_rank"] for row in verification_rows[:4]] != ["1", "2", "3", "4"]:
    raise SystemExit("v61am priority ordering mismatch")
if any(row["activation_admitted"] != "0" for row in verification_rows):
    raise SystemExit("v61am activation should not be admitted by default")
if any(row["local_identity_verified"] != "0" for row in verification_rows):
    raise SystemExit("v61am local identity should not be verified by default")
if any(row["shard_page_hash_coverage_ready"] != "0" for row in verification_rows):
    raise SystemExit("v61am full page-hash coverage should not be ready by default")
if any(row["post_activation_verification_ready"] != "0" for row in verification_rows):
    raise SystemExit("v61am post activation verification rows should be blocked")
if any(row["blocked_reason"] != "activation-not-admitted" for row in verification_rows):
    raise SystemExit("v61am default blocked reason mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61am"] != "0" for row in verification_rows):
    raise SystemExit("v61am must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in verification_rows):
    raise SystemExit("v61am must not commit checkpoint payload bytes")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "checkpoint_post_activation_requirement_rows.csv")}
for requirement_id in [
    "activation-admitted-all-shards",
    "local-identity-verified-all-shards",
    "full-page-hash-coverage-all-pages",
    "generation-gate-after-verification",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61am requirement should be blocked: {requirement_id}")
if requirements["manifest-only-no-repo-payload"]["status"] != "pass":
    raise SystemExit("v61am manifest-only requirement should pass")
if requirements["full-page-hash-coverage-all-pages"]["required_rows"] != "134161":
    raise SystemExit("v61am full page hash required rows mismatch")
if requirements["full-page-hash-coverage-all-pages"]["actual_rows"] != "0":
    raise SystemExit("v61am full page hash actual rows mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61al-activation-input", "v61t-materialization-input", "v61r-full-page-hash-input", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61am gate should pass: {gate}")
for gate in [
    "activation-admission",
    "local-identity-verification",
    "full-page-hash-verification",
    "post-activation-generation-gate",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61am gate should stay blocked: {gate}")

metric = read_csv(run_dir / "checkpoint_post_activation_metric_rows.csv")[0]
for field, value in expected.items():
    if field.startswith("v61am_") or field.startswith("v61al_") or field.startswith("v61t_") or field.startswith("v61r_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61am metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61AM_CHECKPOINT_POST_ACTIVATION_VERIFICATION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "post_activation_verification_rows=59",
    "post_activation_verification_ready_rows=0",
    "post_activation_verification_blocked_rows=59",
    "activation_admitted_rows=0",
    "local_identity_verified_shard_rows=0",
    "verified_page_hash_rows=0",
    "required_page_hash_rows=134161",
    "post_activation_verification_gate_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61am=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61am boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61am_checkpoint_post_activation_verification_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61am_checkpoint_post_activation_verification_gate_ready") != 1:
    raise SystemExit("v61am manifest readiness mismatch")
if manifest.get("post_activation_verification_rows") != 59:
    raise SystemExit("v61am manifest verification rows mismatch")
if manifest.get("post_activation_verification_ready_rows") != 0:
    raise SystemExit("v61am manifest ready rows mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61am") != 0:
    raise SystemExit("v61am manifest must keep downloaded payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61am sha256 mismatch: {rel}")
PY

echo "v61am checkpoint post-activation verification gate smoke passed"
