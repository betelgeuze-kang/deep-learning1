#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ap_moe_coverage_remote_hash_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61ap_moe_coverage_remote_hash_plan_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ap_moe_coverage_remote_hash_plan_decision.csv"

V61AP_REUSE_EXISTING="${V61AP_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ap_moe_coverage_remote_hash_plan.sh" >/dev/null

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
expected = {
    "v61ap_moe_coverage_remote_hash_plan_ready": "1",
    "v61ao_real_model_page_manifest_coverage_audit_ready": "1",
    "real_model_page_manifest_coverage_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "moe_layer_expert_tensor_coverage_rows": "1344",
    "remote_hash_plan_rows": "1344",
    "already_remote_hash_bound_rows": "15",
    "planned_remote_hash_rows": "1329",
    "remote_hash_plan_shard_rows": "59",
    "planned_remote_hash_bytes": "2818572288",
    "already_remote_hash_bound_bytes": "31457280",
    "remaining_remote_hash_bytes": "2787115008",
    "full_moe_coverage_remote_hash_ready": "0",
    "remote_hash_expansion_execution_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ap": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ap {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "moe_coverage_remote_hash_plan_rows.csv",
    "moe_coverage_existing_remote_hash_rows.csv",
    "moe_coverage_remote_hash_role_rows.csv",
    "moe_coverage_remote_hash_shard_rows.csv",
    "moe_coverage_remote_hash_requirement_rows.csv",
    "moe_coverage_remote_hash_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AP_MOE_COVERAGE_REMOTE_HASH_PLAN_BOUNDARY.md",
    "v61ap_moe_coverage_remote_hash_plan_manifest.json",
    "sha256_manifest.csv",
    "source_v61ao/moe_layer_expert_tensor_coverage_rows.csv",
    "source_v61q/checkpoint_page_segment_rows.csv",
    "source_v61q/source_v61o/checkpoint_shard_http_identity_rows.csv",
    "source_v61v/remote_sample_tensor_binding_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ap artifact: {rel}")

plan_rows = read_csv(run_dir / "moe_coverage_remote_hash_plan_rows.csv")
existing_rows = read_csv(run_dir / "moe_coverage_existing_remote_hash_rows.csv")
role_rows = {row["tensor_role"]: row for row in read_csv(run_dir / "moe_coverage_remote_hash_role_rows.csv")}
shard_rows = read_csv(run_dir / "moe_coverage_remote_hash_shard_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "moe_coverage_remote_hash_requirement_rows.csv")}
metric = read_csv(run_dir / "moe_coverage_remote_hash_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(plan_rows) != 1344 or len(existing_rows) != 15 or len(shard_rows) != 59:
    raise SystemExit("v61ap row counts mismatch")
cells = {(row["layer_index"], row["expert_index"], row["tensor_role"]) for row in plan_rows}
if len(cells) != 1344:
    raise SystemExit("v61ap plan should contain one row per MoE layer/expert/tensor cell")
if {row["tensor_role"] for row in plan_rows} != {"moe_w1", "moe_w2", "moe_w3"}:
    raise SystemExit("v61ap plan should cover w1/w2/w3 only")
if len({row["layer_index"] for row in plan_rows}) != 56:
    raise SystemExit("v61ap layer coverage mismatch")
if len({row["expert_index"] for row in plan_rows}) != 8:
    raise SystemExit("v61ap expert coverage mismatch")
if any(int(row["planned_range_bytes"]) != 2097152 for row in plan_rows):
    raise SystemExit("v61ap all representative plans should target one 2 MiB page")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ap"] != "0" for row in plan_rows):
    raise SystemExit("v61ap must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in plan_rows):
    raise SystemExit("v61ap must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in plan_rows):
    raise SystemExit("v61ap must keep route_jump_rows at zero")

status_counts = Counter(row["plan_status"] for row in plan_rows)
if status_counts["already-remote-hash-bound"] != 15 or status_counts["planned-remote-range-hash"] != 1329:
    raise SystemExit(f"v61ap plan status counts mismatch: {status_counts}")
if any(row["remote_page_sha256"] == "" for row in existing_rows):
    raise SystemExit("v61ap existing rows should preserve remote hashes")
if any(row["plan_status"] != "already-remote-hash-bound" for row in existing_rows):
    raise SystemExit("v61ap existing rows should all be already-bound")
if any(not row["source_url"].startswith("https://huggingface.co/") for row in plan_rows):
    raise SystemExit("v61ap source URLs should bind to Hugging Face checkpoint shards")

expected_roles = {
    "moe_w1": ("448", "5", "443"),
    "moe_w2": ("448", "4", "444"),
    "moe_w3": ("448", "6", "442"),
}
for role, (total, existing, planned) in expected_roles.items():
    row = role_rows.get(role)
    if row is None:
        raise SystemExit(f"missing v61ap role row: {role}")
    if row["coverage_cell_rows"] != total or row["already_remote_hash_bound_rows"] != existing or row["planned_remote_hash_rows"] != planned:
        raise SystemExit(f"v61ap role row mismatch: {row}")
    if row["full_role_remote_hash_ready"] != "0":
        raise SystemExit("v61ap role remote hash coverage should remain blocked")

if sum(int(row["planned_cell_rows"]) for row in shard_rows) != 1344:
    raise SystemExit("v61ap shard planned cells should sum to 1344")
if sum(int(row["already_remote_hash_bound_rows"]) for row in shard_rows) != 15:
    raise SystemExit("v61ap shard existing hash rows should sum to 15")

for requirement_id in [
    "v61ao-real-model-page-manifest-coverage-input",
    "moe-cell-remote-hash-plan-complete",
    "existing-remote-hash-bindings-preserved",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61ap requirement should pass: {requirement_id}")
for requirement_id in [
    "full-moe-coverage-remote-hash",
    "remote-hash-expansion-execution",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ap requirement should remain blocked: {requirement_id}")

for gate in [
    "v61ao-real-model-page-manifest-coverage-input",
    "moe-cell-remote-hash-plan",
    "existing-remote-hash-bindings-preserved",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ap gate should pass: {gate}")
for gate in [
    "full-moe-coverage-remote-hash",
    "remote-hash-expansion-execution",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ap gate should stay blocked: {gate}")

for field, value in expected.items():
    if field.startswith("v61ap_") or field.startswith("v61ao_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ap metric {field}: expected {value}, got {metric[field]}")

manifest = json.loads((run_dir / "v61ap_moe_coverage_remote_hash_plan_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ap_moe_coverage_remote_hash_plan_ready") != 1:
    raise SystemExit("v61ap manifest readiness mismatch")
if manifest.get("remote_hash_plan_rows") != 1344 or manifest.get("already_remote_hash_bound_rows") != 15:
    raise SystemExit("v61ap manifest hash plan counts mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ap") != 0:
    raise SystemExit("v61ap manifest must keep downloaded payload bytes at zero")

boundary = (run_dir / "V61AP_MOE_COVERAGE_REMOTE_HASH_PLAN_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "remote_hash_plan_rows=1344",
    "already_remote_hash_bound_rows=15",
    "planned_remote_hash_rows=1329",
    "remaining_remote_hash_bytes=2787115008",
    "full_moe_coverage_remote_hash_ready=0",
    "remote_hash_expansion_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ap=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ap boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ap sha256 mismatch: {rel}")
PY

echo "v61ap MoE coverage remote hash plan smoke passed"
