#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bc_ubuntu1_sampled_hotset_materialization/materialization_001"
SUMMARY_CSV="$RESULTS_DIR/v61bc_ubuntu1_sampled_hotset_materialization_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bc_ubuntu1_sampled_hotset_materialization_decision.csv"

V61BC_REUSE_EXISTING="${V61BC_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bc_ubuntu1_sampled_hotset_materialization.sh" >/dev/null

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
ubuntu1_hotset_root = ubuntu1_target + "/.v61_sampled_hotset_pages"


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
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bc_ubuntu1_sampled_hotset_materialization_ready": "1",
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": "1",
    "v61y_hotset_local_materialization_verifier_ready": "1",
    "ubuntu1_write_witness_ready": "1",
    "selected_target_path": ubuntu1_target,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "target_outside_repository": "1",
    "hotset_root_under_target": "1",
    "target_directory_exists": "1",
    "hotset_page_rows": "16",
    "source_local_hotset_hash_match_rows": "16",
    "ubuntu1_hotset_page_present_rows": "16",
    "ubuntu1_hotset_hash_match_rows": "16",
    "ubuntu1_hotset_readback_hash_match_rows": "16",
    "moe_hotset_page_rows": "15",
    "embedding_hotset_page_rows": "1",
    "sampled_hotset_checkpoint_payload_bytes_expected": "33554432",
    "sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1": "33554432",
    "checkpoint_payload_bytes_downloaded_by_v61bc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "ubuntu1_sampled_hotset_materialization_ready": "1",
    "ubuntu1_hotset_readback_verify_ready": "1",
    "activation_payload_execution_ready": "0",
    "download_execution_ready": "0",
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
        raise SystemExit(f"v61bc {field}: expected {value}, got {summary.get(field)}")

if summary["target_write_observed"] not in {"0", "1"}:
    raise SystemExit("v61bc target_write_observed should be boolean")
if int(summary["checkpoint_payload_bytes_copied_to_ubuntu1_by_v61bc"]) not in (0, 33554432):
    raise SystemExit("v61bc copied bytes should be 0 on reuse or 33554432 on first materialization")

required_files = [
    "ubuntu1_sampled_hotset_materialization_rows.csv",
    "ubuntu1_sampled_hotset_readback_rows.csv",
    "ubuntu1_sampled_hotset_metric_rows.csv",
    "ubuntu1_sampled_hotset_requirement_rows.csv",
    "runtime_gap_rows.csv",
    "V61BC_UBUNTU1_SAMPLED_HOTSET_MATERIALIZATION_BOUNDARY.md",
    "v61bc_ubuntu1_sampled_hotset_materialization_manifest.json",
    "sha256_manifest.csv",
    "source_v61bb/ubuntu1_write_sentinel_witness_rows.csv",
    "source_v61y/hotset_local_materialization_rows.csv",
    "source_v61y/hotset_local_readback_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bc artifact: {rel}")

rows = read_csv(run_dir / "ubuntu1_sampled_hotset_materialization_rows.csv")
readback_rows = read_csv(run_dir / "ubuntu1_sampled_hotset_readback_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_sampled_hotset_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_sampled_hotset_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(rows) != 16:
    raise SystemExit("v61bc should emit 16 materialization rows")
if len(readback_rows) != 16:
    raise SystemExit("v61bc should emit 16 readback rows")
if sum(1 for row in rows if row["node_type"] == "moe_expert_page_node") != 15:
    raise SystemExit("v61bc MoE hotset row count mismatch")
if sum(1 for row in rows if row["node_type"] == "embedding_page_node") != 1:
    raise SystemExit("v61bc embedding hotset row count mismatch")

for row in rows:
    ubuntu1_path = Path(row["ubuntu1_page_path"])
    if not str(ubuntu1_path).startswith(ubuntu1_hotset_root + "/"):
        raise SystemExit("v61bc page path should live under the ubuntu-1 hotset root")
    if row["ubuntu1_page_under_target"] != "1":
        raise SystemExit("v61bc page should be under ubuntu-1 target")
    if row["ubuntu1_page_inside_repository"] != "0":
        raise SystemExit("v61bc page must not be inside the repository")
    if row["source_local_hash_match"] != "1":
        raise SystemExit("v61bc source local page should be hash matched")
    if row["ubuntu1_page_exists"] != "1":
        raise SystemExit(f"v61bc ubuntu-1 page missing: {ubuntu1_path}")
    if row["ubuntu1_hash_match"] != "1":
        raise SystemExit("v61bc ubuntu-1 page hash should match")
    if row["expected_page_bytes"] != "2097152" or row["ubuntu1_page_bytes"] != "2097152":
        raise SystemExit("v61bc pages should be full 2 MiB pages")
    if row["ubuntu1_page_sha256"] != row["remote_page_sha256"]:
        raise SystemExit("v61bc ubuntu-1 sha should match remote sha")
    if sha256(ubuntu1_path) != row["remote_page_sha256"]:
        raise SystemExit("v61bc filesystem hash should match row hash")
    if row["checkpoint_payload_bytes_downloaded_by_v61bc"] != "0":
        raise SystemExit("v61bc must not download checkpoint payload bytes")
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61bc must not commit checkpoint payload bytes")
    if row["full_checkpoint_materialization_ready"] != "0":
        raise SystemExit("v61bc must not claim full checkpoint materialization")
    if row["actual_model_generation_ready"] != "0":
        raise SystemExit("v61bc must not claim generation readiness")

readbacks = {row["remote_sample_id"]: row for row in readback_rows}
for row in rows:
    readback = readbacks[row["remote_sample_id"]]
    if readback["readback_bytes"] != "2097152":
        raise SystemExit("v61bc readback should cover one full page")
    if readback["readback_hash_match"] != "1":
        raise SystemExit("v61bc readback hash should match")
    if readback["readback_sha256"] != row["remote_page_sha256"]:
        raise SystemExit("v61bc readback sha should match remote sha")
    if readback["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61bc readback must not commit checkpoint payload")

for requirement_id in [
    "v61bb-write-witness-input",
    "v61y-sampled-hotset-input",
    "outside-repository-target",
    "hotset-root-under-target",
    "ubuntu1-sampled-hotset-materialization",
    "ubuntu1-sampled-hotset-readback",
    "bounded-sampled-payload-only",
    "no-network-download-by-v61bc",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bc requirement should pass: {requirement_id}")
if requirements["full-checkpoint-materialization"]["status"] != "blocked":
    raise SystemExit("v61bc full checkpoint materialization should remain blocked")

for gate in [
    "v61bb-write-witness-input",
    "v61y-sampled-hotset-input",
    "outside-repository-target",
    "hotset-root-under-target",
    "ubuntu1-sampled-hotset-materialization",
    "ubuntu1-sampled-hotset-readback",
    "bounded-sampled-payload-only",
    "no-network-download-by-v61bc",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bc gate should pass: {gate}")
for gate in [
    "explicit-download-execution",
    "full-checkpoint-materialization",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bc gate should remain blocked: {gate}")

for gap in [
    "v61bb-write-witness-input",
    "v61y-sampled-hotset-input",
    "ubuntu1-sampled-hotset-materialization",
    "ubuntu1-sampled-hotset-readback",
    "bounded-sampled-payload-only",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bc gap should be ready: {gap}")
for gap in [
    "explicit-download-execution",
    "full-checkpoint-materialization",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bc gap should remain blocked: {gap}")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bc metric {field}: expected {value}, got {metric[field]}")

manifest = json.loads((run_dir / "v61bc_ubuntu1_sampled_hotset_materialization_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bc_ubuntu1_sampled_hotset_materialization_ready") != 1:
    raise SystemExit("v61bc manifest readiness mismatch")
if manifest.get("ubuntu1_hotset_hash_match_rows") != 16:
    raise SystemExit("v61bc manifest hash row mismatch")
if manifest.get("sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1") != 33554432:
    raise SystemExit("v61bc manifest persisted byte mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bc") != 0:
    raise SystemExit("v61bc manifest must not download payload bytes")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61bc manifest must not commit payload bytes")
if manifest.get("full_checkpoint_materialization_ready") != 0:
    raise SystemExit("v61bc manifest must keep full checkpoint materialization blocked")

boundary = (run_dir / "V61BC_UBUNTU1_SAMPLED_HOTSET_MATERIALIZATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "hotset_page_rows=16",
    "ubuntu1_hotset_hash_match_rows=16",
    "ubuntu1_hotset_readback_hash_match_rows=16",
    "sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1=33554432",
    "checkpoint_payload_bytes_downloaded_by_v61bc=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "full_checkpoint_materialization_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bc boundary missing snippet: {snippet}")

sha_rows = read_csv(run_dir / "sha256_manifest.csv")
if not sha_rows:
    raise SystemExit("v61bc sha manifest should not be empty")
for row in sha_rows:
    rel = row["path"]
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"v61bc sha manifest points to missing file: {rel}")
    if sha256(path) != row["sha256"]:
        raise SystemExit(f"v61bc sha mismatch: {rel}")

print("v61bc ubuntu-1 sampled hotset materialization smoke passed")
PY
