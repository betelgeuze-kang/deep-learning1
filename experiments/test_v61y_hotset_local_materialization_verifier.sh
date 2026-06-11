#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61y_hotset_local_materialization_verifier/verify_001"
SUMMARY_CSV="$RESULTS_DIR/v61y_hotset_local_materialization_verifier_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61y_hotset_local_materialization_verifier_decision.csv"

V61Y_REUSE_EXISTING="${V61Y_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61y_hotset_local_materialization_verifier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def inside_repo(path):
    try:
        Path(path).resolve().relative_to(root)
        return 1
    except ValueError:
        return 0


summary = read_csv(summary_csv)[0]
expected = {
    "v61y_hotset_local_materialization_verifier_ready": "1",
    "v61x_hotset_runtime_replay_manifest_ready": "1",
    "v61u_remote_checkpoint_page_hash_sampler_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "hotset_page_rows": "16",
    "local_hotset_page_present_rows": "16",
    "local_hotset_hash_match_rows": "16",
    "local_hotset_readback_hash_match_rows": "16",
    "moe_hotset_page_rows": "15",
    "embedding_hotset_page_rows": "1",
    "sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo": "33554432",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "hotset_payload_materialization_ready": "1",
    "hotset_readback_verify_ready": "1",
    "full_checkpoint_materialization_ready": "0",
    "materialization_admission_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61y {field}: expected {value}, got {summary.get(field)}")
if int(summary["checkpoint_payload_bytes_downloaded_by_v61y"]) not in (0, 33554432):
    raise SystemExit("v61y downloaded byte count should be 0 on reuse or 33554432 on first materialization")

required_files = [
    "hotset_local_materialization_rows.csv",
    "hotset_local_readback_rows.csv",
    "hotset_local_materialization_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61Y_HOTSET_LOCAL_MATERIALIZATION_BOUNDARY.md",
    "v61y_hotset_local_materialization_verifier_manifest.json",
    "sha256_manifest.csv",
    "source_v61u/remote_page_hash_sample_plan_rows.csv",
    "source_v61u/remote_page_hash_sample_rows.csv",
    "source_v61x/hotset_runtime_page_rows.csv",
    "source_v61x/hotset_runtime_slot_rows.csv",
    "source_v61x/hotset_source_bound_workload_binding_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61y artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61x-hotset-manifest-input",
    "v61u-remote-page-hash-input",
    "outside-repository-hotset-paths",
    "sampled-hotset-local-materialization",
    "local-hotset-readback",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61y gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "ssd-disk-budget-admission",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61y gate should remain blocked: {gate}")

materialization_rows = read_csv(run_dir / "hotset_local_materialization_rows.csv")
readback_rows = read_csv(run_dir / "hotset_local_readback_rows.csv")
metric = read_csv(run_dir / "hotset_local_materialization_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(materialization_rows) != 16 or len(readback_rows) != 16:
    raise SystemExit("v61y row counts mismatch")
if sum(1 for row in materialization_rows if row["node_type"] == "moe_expert_page_node") != 15:
    raise SystemExit("v61y MoE hotset count mismatch")
if sum(1 for row in materialization_rows if row["node_type"] == "embedding_page_node") != 1:
    raise SystemExit("v61y embedding hotset count mismatch")
for row in materialization_rows:
    local_path = Path(row["planned_local_page_path"])
    if row["planned_local_page_path_inside_repository"] != "0" or inside_repo(local_path):
        raise SystemExit("v61y local hotset paths must stay outside the repository")
    if not local_path.is_file():
        raise SystemExit(f"v61y local hotset page missing: {local_path}")
    if row["local_page_exists"] != "1" or row["local_hash_match"] != "1":
        raise SystemExit("v61y local page verification should pass")
    if row["local_page_bytes"] != "2097152" or local_path.stat().st_size != 2097152:
        raise SystemExit("v61y local pages must be full 2 MiB pages")
    if row["local_page_sha256"] != row["remote_page_sha256"] or sha256(local_path) != row["remote_page_sha256"]:
        raise SystemExit("v61y local page hash should match remote page hash")
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61y must not commit checkpoint payload")
    if row["full_checkpoint_materialization_ready"] != "0" or row["actual_model_generation_ready"] != "0":
        raise SystemExit("v61y must keep full materialization and generation blocked")

readback_by_slot = {row["slot_id"]: row for row in readback_rows}
for row in materialization_rows:
    readback = readback_by_slot[row["slot_id"]]
    if readback["readback_bytes"] != "2097152":
        raise SystemExit("v61y readback should cover one full page")
    if readback["readback_hash_match"] != "1":
        raise SystemExit("v61y readback hashes should match")
    if readback["readback_sha256"] != row["remote_page_sha256"]:
        raise SystemExit("v61y readback sha should match remote hash")

if metric["hotset_payload_materialization_ready"] != "1" or metric["hotset_readback_verify_ready"] != "1":
    raise SystemExit("v61y metric readiness mismatch")
for field in [
    "full_checkpoint_materialization_ready",
    "materialization_admission_ready",
    "local_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "real_100b_open_weight_materialized",
    "actual_model_generation_ready",
    "near_frontier_claim_ready",
    "production_latency_claim_ready",
    "real_release_package_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61y metric should keep {field}=0")

for gap in ["v61x-hotset-manifest-input", "v61u-remote-page-hash-input", "local-sampled-hotset-pages", "local-hotset-readback"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61y gap should be ready: {gap}")
for gap in [
    "full-checkpoint-materialization",
    "ssd-disk-budget-admission",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61y gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61y_hotset_local_materialization_verifier_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61y_hotset_local_materialization_verifier_ready") != 1:
    raise SystemExit("v61y manifest readiness mismatch")
if manifest.get("hotset_page_rows") != 16 or manifest.get("local_hotset_hash_match_rows") != 16:
    raise SystemExit("v61y manifest row counts mismatch")
if manifest.get("sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo") != 33554432:
    raise SystemExit("v61y manifest persisted byte count mismatch")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61y manifest should record zero repo payload bytes")
if manifest.get("full_checkpoint_materialization_ready") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61y manifest should keep full checkpoint and generation blocked")

boundary = (run_dir / "V61Y_HOTSET_LOCAL_MATERIALIZATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "hotset_page_rows=16",
    "local_hotset_hash_match_rows=16",
    "sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo=33554432",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "hotset_payload_materialization_ready=1",
    "full_checkpoint_materialization_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61y boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61y sha256 mismatch: {rel}")
PY

echo "v61y hotset local materialization verifier smoke passed"
