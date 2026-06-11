#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61x_hotset_runtime_replay_manifest"
RUN_ID="${V61X_RUN_ID:-hotset_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61X_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61x_hotset_runtime_replay_manifest_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61W_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null
V61S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61s_one_command_source_bound_qa_replay.sh" >/dev/null
V61M_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61m_kv_cache_residency_eviction_policy.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v61m_dir = results / "v61m_kv_cache_residency_eviction_policy" / "kv_001"
v61s_dir = results / "v61s_one_command_source_bound_qa_replay" / "replay_001"
v61u_dir = results / "v61u_remote_checkpoint_page_hash_sampler" / "sample_001"
v61v_dir = results / "v61v_remote_page_tensor_binding" / "binding_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"
page_bytes = 2 * 1024 * 1024
hotset_warehouse = Path(os.environ.get("V61X_HOTSET_WAREHOUSE", str(Path.home() / ".cache" / "deep_learning_v61x_mixtral_hotset_warehouse"))).expanduser()


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def inside_repo(path):
    try:
        Path(path).resolve().relative_to(root)
        return 1
    except ValueError:
        return 0


v61m_summary = read_csv(results / "v61m_kv_cache_residency_eviction_policy_summary.csv")[0]
v61s_summary = read_csv(results / "v61s_one_command_source_bound_qa_replay_summary.csv")[0]
v61u_summary = read_csv(results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv")[0]
v61v_summary = read_csv(results / "v61v_remote_page_tensor_binding_summary.csv")[0]
v61w_summary = read_csv(results / "v61w_materialization_admission_resume_plan_summary.csv")[0]

for name, summary, field in [
    ("v61m", v61m_summary, "v61m_kv_cache_residency_eviction_policy_ready"),
    ("v61s", v61s_summary, "v61s_one_command_source_bound_qa_replay_ready"),
    ("v61u", v61u_summary, "v61u_remote_checkpoint_page_hash_sampler_ready"),
    ("v61v", v61v_summary, "v61v_remote_page_tensor_binding_ready"),
    ("v61w", v61w_summary, "v61w_materialization_admission_resume_plan_ready"),
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v61x requires {name} {field}=1")

if v61w_summary.get("download_resume_plan_ready") != "1":
    raise SystemExit("v61x requires v61w download_resume_plan_ready=1")
if v61v_summary.get("remote_sample_tensor_binding_ready") != "1":
    raise SystemExit("v61x requires v61v remote_sample_tensor_binding_ready=1")
if v61s_summary.get("one_command_source_bound_qa_pass") != "1":
    raise SystemExit("v61x requires v61s one_command_source_bound_qa_pass=1")
if v61m_summary.get("kv_cache_policy_ready") != "1":
    raise SystemExit("v61x requires v61m kv_cache_policy_ready=1")

for src, rel in [
    (results / "v61m_kv_cache_residency_eviction_policy_summary.csv", "source_v61m/v61m_kv_cache_residency_eviction_policy_summary.csv"),
    (v61m_dir / "kv_residency_policy_rows.csv", "source_v61m/kv_residency_policy_rows.csv"),
    (v61m_dir / "kv_budget_profile_rows.csv", "source_v61m/kv_budget_profile_rows.csv"),
    (v61m_dir / "sha256_manifest.csv", "source_v61m/sha256_manifest.csv"),
    (results / "v61s_one_command_source_bound_qa_replay_summary.csv", "source_v61s/v61s_one_command_source_bound_qa_replay_summary.csv"),
    (v61s_dir / "source_bound_workload_pass_rows.csv", "source_v61s/source_bound_workload_pass_rows.csv"),
    (v61s_dir / "one_command_replay_rows.csv", "source_v61s/one_command_replay_rows.csv"),
    (v61s_dir / "sha256_manifest.csv", "source_v61s/sha256_manifest.csv"),
    (results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv", "source_v61u/v61u_remote_checkpoint_page_hash_sampler_summary.csv"),
    (v61u_dir / "remote_page_hash_sample_rows.csv", "source_v61u/remote_page_hash_sample_rows.csv"),
    (v61u_dir / "remote_page_hash_sample_metric_rows.csv", "source_v61u/remote_page_hash_sample_metric_rows.csv"),
    (v61u_dir / "sha256_manifest.csv", "source_v61u/sha256_manifest.csv"),
    (results / "v61v_remote_page_tensor_binding_summary.csv", "source_v61v/v61v_remote_page_tensor_binding_summary.csv"),
    (v61v_dir / "remote_sample_tensor_binding_rows.csv", "source_v61v/remote_sample_tensor_binding_rows.csv"),
    (v61v_dir / "remote_sample_runtime_node_rows.csv", "source_v61v/remote_sample_runtime_node_rows.csv"),
    (v61v_dir / "remote_sample_tensor_role_summary_rows.csv", "source_v61v/remote_sample_tensor_role_summary_rows.csv"),
    (v61v_dir / "sha256_manifest.csv", "source_v61v/sha256_manifest.csv"),
    (results / "v61w_materialization_admission_resume_plan_summary.csv", "source_v61w/v61w_materialization_admission_resume_plan_summary.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "checkpoint_download_resume_plan_rows.csv", "source_v61w/checkpoint_download_resume_plan_rows.csv"),
    (v61w_dir / "materialization_admission_metric_rows.csv", "source_v61w/materialization_admission_metric_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

kv_policy = read_csv(v61m_dir / "kv_residency_policy_rows.csv")[0]
qa_rows = read_csv(v61s_dir / "source_bound_workload_pass_rows.csv")
remote_sample_rows = {row["remote_sample_id"]: row for row in read_csv(v61u_dir / "remote_page_hash_sample_rows.csv")}
binding_rows = read_csv(v61v_dir / "remote_sample_tensor_binding_rows.csv")
runtime_nodes = {row["binding_id"]: row for row in read_csv(v61v_dir / "remote_sample_runtime_node_rows.csv")}
priority_rows = {row["shard_name"]: row for row in read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")}

if len(binding_rows) != 16 or len(runtime_nodes) != 16:
    raise SystemExit("v61x expects 16 remote sample runtime bindings")
if len(qa_rows) != 37:
    raise SystemExit("v61x expects 37 source-bound replay rows")

hotset_page_rows = []
slot_rows = []
for idx, binding in enumerate(binding_rows):
    runtime = runtime_nodes[binding["binding_id"]]
    sample = remote_sample_rows[binding["remote_sample_id"]]
    priority = priority_rows[binding["shard_name"]]
    slot_id = f"v61x_nvme_hotset_slot_{idx:04d}"
    planned_path = hotset_warehouse / binding["shard_name"] / f"page_{int(binding['shard_page_index']):08d}.bin"
    hotset_page_id = f"v61x_hotset_page_{idx:04d}"
    if binding["remote_page_sha256"] != sample["remote_page_sha256"]:
        raise SystemExit(f"v61x remote hash mismatch for {binding['remote_sample_id']}")
    if int(sample["remote_page_bytes_read"]) != page_bytes:
        raise SystemExit(f"v61x expected full 2 MiB remote page for {binding['remote_sample_id']}")
    hotset_page_rows.append(
        {
            "hotset_page_id": hotset_page_id,
            "slot_id": slot_id,
            "priority_rank": priority["priority_rank"],
            "binding_id": binding["binding_id"],
            "runtime_node_id": runtime["runtime_node_id"],
            "remote_sample_id": binding["remote_sample_id"],
            "model_id": binding["model_id"],
            "shard_name": binding["shard_name"],
            "shard_page_index": binding["shard_page_index"],
            "source_page_id": binding["source_page_id"],
            "remote_page_sha256": binding["remote_page_sha256"],
            "tensor_name": binding["tensor_name"],
            "tensor_role": binding["tensor_role"],
            "layer_index": binding["layer_index"],
            "expert_index": binding["expert_index"],
            "node_type": runtime["node_type"],
            "hotset_tier": "nvme-hotset-planned",
            "planned_local_page_path": str(planned_path),
            "planned_local_page_path_inside_repository": str(inside_repo(planned_path)),
            "expected_page_bytes": str(page_bytes),
            "remote_page_bytes_read": sample["remote_page_bytes_read"],
            "remote_page_hash_sample_ready": sample["remote_page_hash_sample_ready"],
            "remote_hash_bound": binding["remote_hash_bound"],
            "prefetch_candidate": runtime["prefetch_candidate"],
            "kv_policy_id": kv_policy["policy_id"],
            "host_ram_kv_spill_enabled": kv_policy["host_ram_kv_spill_enabled"],
            "page_hash_full_coverage_ready": runtime["page_hash_full_coverage_ready"],
            "local_page_payload_materialized": "0",
            "hotset_payload_materialization_ready": "0",
            "checkpoint_payload_bytes_downloaded_by_v61x": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
    slot_rows.append(
        {
            "slot_id": slot_id,
            "hotset_page_id": hotset_page_id,
            "runtime_node_id": runtime["runtime_node_id"],
            "node_type": runtime["node_type"],
            "model_id": binding["model_id"],
            "layer_index": binding["layer_index"],
            "expert_index": binding["expert_index"],
            "tensor_role": binding["tensor_role"],
            "storage_tier": "nvme-hotset-planned",
            "read_mode": "direct-io-or-mmap-planned",
            "quant_profile_id": runtime["quant_profile_id"],
            "prefetch_candidate": runtime["prefetch_candidate"],
            "kv_policy_id": kv_policy["policy_id"],
            "kv_policy_compatible": "1",
            "local_resident": "0",
            "remote_hash_bound": binding["remote_hash_bound"],
            "promotion_status": "planned-not-materialized",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )

moe_pages = sum(1 for row in hotset_page_rows if row["node_type"] == "moe_expert_page_node")
embedding_pages = sum(1 for row in hotset_page_rows if row["node_type"] == "embedding_page_node")
remote_hash_bound = sum(int(row["remote_hash_bound"]) for row in hotset_page_rows)
remote_ready = sum(int(row["remote_page_hash_sample_ready"]) for row in hotset_page_rows)

workload_rows = []
for idx, row in enumerate(qa_rows, start=1):
    workload_rows.append(
        {
            "workload_binding_id": f"v61x_workload_binding_{idx:04d}",
            "replay_id": row["replay_id"],
            "query_id": row["query_id"],
            "query_family": row["query_family"],
            "requires_abstain": row["requires_abstain"],
            "source_bound_query_pass": row["source_bound_query_pass"],
            "answer_supported_by_citation": row["answer_supported_by_citation"],
            "hotset_page_rows_bound": str(len(hotset_page_rows)),
            "moe_hotset_page_rows_bound": str(moe_pages),
            "embedding_hotset_page_rows_bound": str(embedding_pages),
            "remote_hash_bound_rows": str(remote_hash_bound),
            "hotset_manifest_ready": "1",
            "hotset_payload_materialization_ready": "0",
            "actual_model_generation_ready": "0",
            "complete_source_1000_query_ready": v61s_summary["complete_source_1000_query_ready"],
        }
    )

metric_rows = [
    {
        "metric_id": "v61x_hotset_runtime_replay_manifest_metrics",
        "hotset_page_rows": str(len(hotset_page_rows)),
        "hotset_runtime_slot_rows": str(len(slot_rows)),
        "hotset_workload_binding_rows": str(len(workload_rows)),
        "moe_hotset_page_rows": str(moe_pages),
        "embedding_hotset_page_rows": str(embedding_pages),
        "remote_hash_bound_rows": str(remote_hash_bound),
        "remote_page_hash_sample_ready_rows": str(remote_ready),
        "source_bound_query_rows": v61s_summary["source_bound_query_rows"],
        "source_bound_query_pass_rows": v61s_summary["source_bound_query_pass_rows"],
        "hotset_manifest_ready": "1",
        "source_bound_replay_binding_ready": "1",
        "hotset_payload_materialization_ready": "0",
        "hotset_runtime_execution_ready": "0",
        "materialization_admission_ready": v61w_summary["materialization_admission_ready"],
        "local_checkpoint_materialization_ready": v61w_summary["local_checkpoint_materialization_ready"],
        "full_safetensors_page_hash_binding_ready": v61w_summary["full_safetensors_page_hash_binding_ready"],
        "checkpoint_payload_bytes_downloaded_by_v61x": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "route_jump_rows": "0",
    }
]

runtime_gap_rows = [
    {"gap": "v61w-materialization-plan-input", "status": "ready", "evidence": "v61w summary ready and copied"},
    {"gap": "v61v-remote-tensor-binding-input", "status": "ready", "evidence": "16 remote-hashed tensor/runtime node rows copied"},
    {"gap": "v61m-kv-policy-input", "status": "ready", "evidence": "kv_cache_policy_ready=1 and host_ram_kv_spill_enabled=0"},
    {"gap": "v61s-source-bound-replay-input", "status": "ready", "evidence": "37/37 source-bound replay rows pass"},
    {"gap": "nvme-hotset-manifest", "status": "ready", "evidence": "16 planned outside-repository hotset slots emitted"},
    {"gap": "source-bound-replay-binding", "status": "ready", "evidence": "37 workload rows bound to the hotset manifest"},
    {"gap": "hotset-payload-materialization", "status": "blocked", "evidence": "local page payload bytes are not materialized"},
    {"gap": "ssd-disk-budget-admission", "status": "blocked", "evidence": "v61w materialization_admission_ready=0"},
    {"gap": "local-checkpoint-materialization", "status": "blocked", "evidence": "v61w local_checkpoint_materialization_ready=0"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "v61w full_safetensors_page_hash_binding_ready=0"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "near_frontier_claim_ready=0"},
    {"gap": "production-latency", "status": "blocked", "evidence": "production_latency_claim_ready=0"},
    {"gap": "release-package", "status": "blocked", "evidence": "real_release_package_ready=0"},
]

decision_rows = [
    {"gate": "v61w-materialization-plan-input", "status": "pass", "reason": "download resume plan and MoE-first priority rows are present"},
    {"gate": "v61v-remote-page-tensor-binding-input", "status": "pass", "reason": "16 remote-hashed pages are tensor/runtime-node bound"},
    {"gate": "v61m-kv-cache-policy-input", "status": "pass", "reason": "KV policy is ready and host RAM KV spill remains disabled"},
    {"gate": "v61s-source-bound-replay-input", "status": "pass", "reason": "one-command source-bound QA replay passes 37/37 rows"},
    {"gate": "nvme-hotset-manifest", "status": "pass", "reason": "planned hotset slots are outside the repository and hash-bound"},
    {"gate": "source-bound-replay-binding", "status": "pass", "reason": "source-bound workload rows are bound to the hotset manifest"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "no checkpoint payload bytes are written or committed by v61x"},
    {"gate": "hotset-payload-materialization", "status": "blocked", "reason": "local hotset page payloads are not materialized"},
    {"gate": "ssd-disk-budget-admission", "status": "blocked", "reason": "v61w keeps materialization admission blocked on current free space"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "local shard identity verification has zero verified shards"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full checkpoint page-hash coverage is not complete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real Mixtral generation is not executed"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "quality claims require real generation and external review"},
    {"gate": "production-latency", "status": "blocked", "reason": "production latency requires materialized checkpoint runtime"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires materialization, full hash coverage, generation, and review"},
]

write_csv(
    run_dir / "hotset_runtime_page_rows.csv",
    [
        "hotset_page_id",
        "slot_id",
        "priority_rank",
        "binding_id",
        "runtime_node_id",
        "remote_sample_id",
        "model_id",
        "shard_name",
        "shard_page_index",
        "source_page_id",
        "remote_page_sha256",
        "tensor_name",
        "tensor_role",
        "layer_index",
        "expert_index",
        "node_type",
        "hotset_tier",
        "planned_local_page_path",
        "planned_local_page_path_inside_repository",
        "expected_page_bytes",
        "remote_page_bytes_read",
        "remote_page_hash_sample_ready",
        "remote_hash_bound",
        "prefetch_candidate",
        "kv_policy_id",
        "host_ram_kv_spill_enabled",
        "page_hash_full_coverage_ready",
        "local_page_payload_materialized",
        "hotset_payload_materialization_ready",
        "checkpoint_payload_bytes_downloaded_by_v61x",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "route_jump_rows",
    ],
    hotset_page_rows,
)
write_csv(
    run_dir / "hotset_runtime_slot_rows.csv",
    [
        "slot_id",
        "hotset_page_id",
        "runtime_node_id",
        "node_type",
        "model_id",
        "layer_index",
        "expert_index",
        "tensor_role",
        "storage_tier",
        "read_mode",
        "quant_profile_id",
        "prefetch_candidate",
        "kv_policy_id",
        "kv_policy_compatible",
        "local_resident",
        "remote_hash_bound",
        "promotion_status",
        "checkpoint_payload_bytes_committed_to_repo",
        "route_jump_rows",
    ],
    slot_rows,
)
write_csv(
    run_dir / "hotset_source_bound_workload_binding_rows.csv",
    [
        "workload_binding_id",
        "replay_id",
        "query_id",
        "query_family",
        "requires_abstain",
        "source_bound_query_pass",
        "answer_supported_by_citation",
        "hotset_page_rows_bound",
        "moe_hotset_page_rows_bound",
        "embedding_hotset_page_rows_bound",
        "remote_hash_bound_rows",
        "hotset_manifest_ready",
        "hotset_payload_materialization_ready",
        "actual_model_generation_ready",
        "complete_source_1000_query_ready",
    ],
    workload_rows,
)
write_csv(
    run_dir / "hotset_runtime_replay_metric_rows.csv",
    [
        "metric_id",
        "hotset_page_rows",
        "hotset_runtime_slot_rows",
        "hotset_workload_binding_rows",
        "moe_hotset_page_rows",
        "embedding_hotset_page_rows",
        "remote_hash_bound_rows",
        "remote_page_hash_sample_ready_rows",
        "source_bound_query_rows",
        "source_bound_query_pass_rows",
        "hotset_manifest_ready",
        "source_bound_replay_binding_ready",
        "hotset_payload_materialization_ready",
        "hotset_runtime_execution_ready",
        "materialization_admission_ready",
        "local_checkpoint_materialization_ready",
        "full_safetensors_page_hash_binding_ready",
        "checkpoint_payload_bytes_downloaded_by_v61x",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "near_frontier_claim_ready",
        "production_latency_claim_ready",
        "real_release_package_ready",
        "route_jump_rows",
    ],
    metric_rows,
)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61x_hotset_runtime_replay_manifest_ready": "1",
    "v61w_materialization_admission_resume_plan_ready": v61w_summary["v61w_materialization_admission_resume_plan_ready"],
    "v61v_remote_page_tensor_binding_ready": v61v_summary["v61v_remote_page_tensor_binding_ready"],
    "v61s_one_command_source_bound_qa_replay_ready": v61s_summary["v61s_one_command_source_bound_qa_replay_ready"],
    "v61m_kv_cache_residency_eviction_policy_ready": v61m_summary["v61m_kv_cache_residency_eviction_policy_ready"],
    "model_id": model_id,
    "hotset_page_rows": str(len(hotset_page_rows)),
    "hotset_runtime_slot_rows": str(len(slot_rows)),
    "hotset_workload_binding_rows": str(len(workload_rows)),
    "moe_hotset_page_rows": str(moe_pages),
    "embedding_hotset_page_rows": str(embedding_pages),
    "remote_hash_bound_rows": str(remote_hash_bound),
    "remote_page_hash_sample_ready_rows": str(remote_ready),
    "source_bound_query_rows": v61s_summary["source_bound_query_rows"],
    "source_bound_query_pass_rows": v61s_summary["source_bound_query_pass_rows"],
    "hotset_manifest_ready": "1",
    "source_bound_replay_binding_ready": "1",
    "hotset_payload_materialization_ready": "0",
    "hotset_runtime_execution_ready": "0",
    "materialization_admission_ready": v61w_summary["materialization_admission_ready"],
    "local_checkpoint_materialization_ready": v61w_summary["local_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61w_summary["full_safetensors_page_hash_binding_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61x": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}

write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61x_hotset_runtime_replay_manifest",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "hotset_warehouse_planned_root": str(hotset_warehouse),
    "hotset_warehouse_inside_repository": inside_repo(hotset_warehouse),
    "v61x_hotset_runtime_replay_manifest_ready": 1,
    "hotset_page_rows": len(hotset_page_rows),
    "hotset_runtime_slot_rows": len(slot_rows),
    "hotset_workload_binding_rows": len(workload_rows),
    "moe_hotset_page_rows": moe_pages,
    "embedding_hotset_page_rows": embedding_pages,
    "remote_hash_bound_rows": remote_hash_bound,
    "remote_page_hash_sample_ready_rows": remote_ready,
    "source_bound_query_rows": int(v61s_summary["source_bound_query_rows"]),
    "source_bound_query_pass_rows": int(v61s_summary["source_bound_query_pass_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v61x": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "hotset_payload_materialization_ready": 0,
    "hotset_runtime_execution_ready": 0,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "hotset_payload_materialization",
        "local_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61x_hotset_runtime_replay_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61x Hotset Runtime Replay Manifest Boundary

This artifact binds the v61v remote-hashed Mixtral checkpoint pages to a
deterministic NVMe hotset/runtime replay manifest and to the v61s source-bound
QA replay rows.

Evidence emitted:

- hotset_page_rows={len(hotset_page_rows)}
- hotset_runtime_slot_rows={len(slot_rows)}
- hotset_workload_binding_rows={len(workload_rows)}
- moe_hotset_page_rows={moe_pages}
- embedding_hotset_page_rows={embedding_pages}
- remote_hash_bound_rows={remote_hash_bound}
- remote_page_hash_sample_ready_rows={remote_ready}
- source_bound_query_pass_rows={v61s_summary["source_bound_query_pass_rows"]}
- hotset_manifest_ready=1
- source_bound_replay_binding_ready=1
- checkpoint_payload_bytes_downloaded_by_v61x=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- hotset_payload_materialization_ready=0
- hotset_runtime_execution_ready=0
- materialization_admission_ready={v61w_summary["materialization_admission_ready"]}
- local_checkpoint_materialization_ready={v61w_summary["local_checkpoint_materialization_ready"]}
- full_safetensors_page_hash_binding_ready={v61w_summary["full_safetensors_page_hash_binding_ready"]}
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is not a real Mixtral generation result, not completed local checkpoint
materialization, not completed full safetensors page-hash coverage, and not a
near-frontier, production-latency, or release claim.
"""
(run_dir / "V61X_HOTSET_RUNTIME_REPLAY_MANIFEST_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61x_hotset_runtime_replay_manifest_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
