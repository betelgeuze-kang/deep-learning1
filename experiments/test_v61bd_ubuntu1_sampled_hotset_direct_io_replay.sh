#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bd_ubuntu1_sampled_hotset_direct_io_replay/replay_001"
SUMMARY_CSV="$RESULTS_DIR/v61bd_ubuntu1_sampled_hotset_direct_io_replay_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bd_ubuntu1_sampled_hotset_direct_io_replay_decision.csv"

V61BD_REUSE_EXISTING="${V61BD_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bd_ubuntu1_sampled_hotset_direct_io_replay.sh" >/dev/null

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
    "v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready": "1",
    "v61bc_ubuntu1_sampled_hotset_materialization_ready": "1",
    "v61x_hotset_runtime_replay_manifest_ready": "1",
    "selected_target_path": ubuntu1_target,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "hotset_page_rows": "16",
    "direct_io_read_rows": "16",
    "direct_io_hash_match_rows": "16",
    "direct_io_error_rows": "0",
    "moe_direct_read_rows": "15",
    "embedding_direct_read_rows": "1",
    "direct_io_bytes_read_total": "33554432",
    "ssd_read_bytes_per_token": "8388608",
    "source_bound_workload_binding_rows": "37",
    "ubuntu1_direct_io_replay_ready": "1",
    "checkpoint_payload_bytes_downloaded_by_v61bd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
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
        raise SystemExit(f"v61bd {field}: expected {value}, got {summary.get(field)}")
for field in ["direct_io_read_latency_ms_p50", "direct_io_read_latency_ms_p95", "direct_io_read_throughput_mib_s"]:
    if float(summary[field]) <= 0:
        raise SystemExit(f"v61bd expected positive {field}")

required_files = [
    "ubuntu1_hotset_direct_io_read_rows.csv",
    "ubuntu1_hotset_direct_io_prefetch_order_rows.csv",
    "ubuntu1_hotset_direct_io_latency_rows.csv",
    "ubuntu1_hotset_direct_io_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BD_UBUNTU1_SAMPLED_HOTSET_DIRECT_IO_REPLAY_BOUNDARY.md",
    "v61bd_ubuntu1_sampled_hotset_direct_io_replay_manifest.json",
    "sha256_manifest.csv",
    "source_v61bc/ubuntu1_sampled_hotset_materialization_rows.csv",
    "source_v61bc/ubuntu1_sampled_hotset_readback_rows.csv",
    "source_v61x/hotset_runtime_slot_rows.csv",
    "source_v61x/hotset_source_bound_workload_binding_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bd artifact: {rel}")

direct_rows = read_csv(run_dir / "ubuntu1_hotset_direct_io_read_rows.csv")
prefetch_rows = read_csv(run_dir / "ubuntu1_hotset_direct_io_prefetch_order_rows.csv")
metric = read_csv(run_dir / "ubuntu1_hotset_direct_io_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(direct_rows) != 16 or len(prefetch_rows) != 16:
    raise SystemExit("v61bd row counts mismatch")
if sum(1 for row in direct_rows if row["node_type"] == "moe_expert_page_node") != 15:
    raise SystemExit("v61bd MoE direct read count mismatch")
if sum(1 for row in direct_rows if row["node_type"] == "embedding_page_node") != 1:
    raise SystemExit("v61bd embedding direct read count mismatch")
for row in direct_rows:
    page_path = Path(row["ubuntu1_page_path"])
    if not str(page_path).startswith(ubuntu1_hotset_root + "/"):
        raise SystemExit("v61bd direct read path should live under ubuntu-1 hotset root")
    if row["direct_io_requested"] != "1" or row["direct_io_used"] != "1":
        raise SystemExit("v61bd direct I/O should be requested and used for every row")
    if row["direct_read_hash_match"] != "1":
        raise SystemExit("v61bd direct reads should match remote hashes")
    if row["bytes_read"] != "2097152":
        raise SystemExit("v61bd direct reads should read full 2 MiB pages")
    if row["local_page_sha256"] != row["remote_page_sha256"]:
        raise SystemExit("v61bd local sha should match remote sha")
    if sha256(page_path) != row["remote_page_sha256"]:
        raise SystemExit("v61bd filesystem hash should match remote sha")
    if row["checkpoint_payload_bytes_downloaded_by_v61bd"] != "0":
        raise SystemExit("v61bd must not download checkpoint payload")
    if row["checkpoint_payload_bytes_committed_to_repo"] != "0":
        raise SystemExit("v61bd must not commit checkpoint payload")
    if row["full_checkpoint_materialization_ready"] != "0":
        raise SystemExit("v61bd must not claim full materialization")
    if row["actual_model_generation_ready"] != "0":
        raise SystemExit("v61bd must keep generation blocked")

if [row["node_type"] for row in prefetch_rows[:15]].count("moe_expert_page_node") != 15:
    raise SystemExit("v61bd prefetch order should put MoE pages first")
if prefetch_rows[-1]["node_type"] != "embedding_page_node":
    raise SystemExit("v61bd embedding page should follow MoE hotset pages")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bd metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61bc-ubuntu1-sampled-hotset-input",
    "ubuntu1-direct-io-hotset-read",
    "moe-first-prefetch-order",
    "no-network-download-by-v61bd",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bd gate should pass: {gate}")
for gate in [
    "explicit-download-execution",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bd gate should stay blocked: {gate}")

for gap in [
    "v61bc-ubuntu1-sampled-hotset-input",
    "ubuntu1-direct-io-hotset-read",
    "moe-first-prefetch-order",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bd gap should be ready: {gap}")
for gap in [
    "explicit-download-execution",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bd gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bd_ubuntu1_sampled_hotset_direct_io_replay_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bd_ubuntu1_sampled_hotset_direct_io_replay_ready") != 1:
    raise SystemExit("v61bd manifest readiness mismatch")
if manifest.get("direct_io_read_rows") != 16 or manifest.get("direct_io_hash_match_rows") != 16:
    raise SystemExit("v61bd manifest direct read counts mismatch")
if manifest.get("direct_io_bytes_read_total") != 33554432:
    raise SystemExit("v61bd manifest byte count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bd") != 0:
    raise SystemExit("v61bd manifest must not download payload")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61bd manifest must not commit payload")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61bd manifest should keep generation blocked")

boundary = (run_dir / "V61BD_UBUNTU1_SAMPLED_HOTSET_DIRECT_IO_REPLAY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "direct_io_read_rows=16",
    "direct_io_hash_match_rows=16",
    "direct_io_error_rows=0",
    "direct_io_bytes_read_total=33554432",
    "ssd_read_bytes_per_token=8388608",
    "ubuntu1_direct_io_replay_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61bd=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bd boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bd sha256 mismatch: {rel}")

print("v61bd ubuntu-1 sampled hotset direct I/O replay smoke passed")
PY
