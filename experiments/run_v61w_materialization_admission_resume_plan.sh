#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61w_materialization_admission_resume_plan"
RUN_ID="${V61W_RUN_ID:-plan_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61W_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61w_materialization_admission_resume_plan_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
V61V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61v_remote_page_tensor_binding.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v61p_dir = results / "v61p_local_ssd_checkpoint_residency_preflight" / "preflight_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61v_dir = results / "v61v_remote_page_tensor_binding" / "binding_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"


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


def shard_number(shard_name):
    match = re.search(r"model-(\d+)-of-\d+\.safetensors$", shard_name)
    if not match:
        return 9999
    return int(match.group(1))


def rel_command(path):
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


v61p_summary = read_csv(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
v61q_summary = read_csv(results / "v61q_real_checkpoint_page_map_summary.csv")[0]
v61t_summary = read_csv(results / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
v61v_summary = read_csv(results / "v61v_remote_page_tensor_binding_summary.csv")[0]

if v61p_summary.get("v61p_local_ssd_checkpoint_residency_preflight_ready") != "1":
    raise SystemExit("v61w requires v61p_local_ssd_checkpoint_residency_preflight_ready=1")
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61w requires v61q_real_checkpoint_page_map_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61w requires v61t_local_checkpoint_materialization_verifier_ready=1")
if v61v_summary.get("v61v_remote_page_tensor_binding_ready") != "1":
    raise SystemExit("v61w requires v61v_remote_page_tensor_binding_ready=1")

for src, rel in [
    (results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    (results / "v61p_local_ssd_checkpoint_residency_preflight_decision.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_decision.csv"),
    (v61p_dir / "ssd_warehouse_probe_rows.csv", "source_v61p/ssd_warehouse_probe_rows.csv"),
    (v61p_dir / "ssd_disk_budget_rows.csv", "source_v61p/ssd_disk_budget_rows.csv"),
    (v61p_dir / "checkpoint_residency_requirement_rows.csv", "source_v61p/checkpoint_residency_requirement_rows.csv"),
    (v61p_dir / "checkpoint_download_plan_rows.csv", "source_v61p/checkpoint_download_plan_rows.csv"),
    (v61p_dir / "local_shard_presence_rows.csv", "source_v61p/local_shard_presence_rows.csv"),
    (v61p_dir / "v61p_local_ssd_checkpoint_residency_preflight_manifest.json", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_manifest.json"),
    (v61p_dir / "sha256_manifest.csv", "source_v61p/sha256_manifest.csv"),
    (results / "v61q_real_checkpoint_page_map_summary.csv", "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (v61q_dir / "checkpoint_shard_page_summary_rows.csv", "source_v61q/checkpoint_shard_page_summary_rows.csv"),
    (v61q_dir / "checkpoint_page_map_metric_rows.csv", "source_v61q/checkpoint_page_map_metric_rows.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_summary.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_decision.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv"),
    (v61t_dir / "local_checkpoint_materialization_rows.csv", "source_v61t/local_checkpoint_materialization_rows.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "materialization_gap_rows.csv", "source_v61t/materialization_gap_rows.csv"),
    (v61t_dir / "v61t_local_checkpoint_materialization_verifier_manifest.json", "source_v61t/v61t_local_checkpoint_materialization_verifier_manifest.json"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
    (results / "v61v_remote_page_tensor_binding_summary.csv", "source_v61v/v61v_remote_page_tensor_binding_summary.csv"),
    (results / "v61v_remote_page_tensor_binding_decision.csv", "source_v61v/v61v_remote_page_tensor_binding_decision.csv"),
    (v61v_dir / "remote_sample_tensor_binding_rows.csv", "source_v61v/remote_sample_tensor_binding_rows.csv"),
    (v61v_dir / "remote_sample_runtime_node_rows.csv", "source_v61v/remote_sample_runtime_node_rows.csv"),
    (v61v_dir / "remote_sample_tensor_role_summary_rows.csv", "source_v61v/remote_sample_tensor_role_summary_rows.csv"),
    (v61v_dir / "remote_sample_tensor_coverage_rows.csv", "source_v61v/remote_sample_tensor_coverage_rows.csv"),
    (v61v_dir / "remote_sample_tensor_binding_metric_rows.csv", "source_v61v/remote_sample_tensor_binding_metric_rows.csv"),
    (v61v_dir / "v61v_remote_page_tensor_binding_manifest.json", "source_v61v/v61v_remote_page_tensor_binding_manifest.json"),
    (v61v_dir / "sha256_manifest.csv", "source_v61v/sha256_manifest.csv"),
]:
    copy(src, rel)

download_rows = read_csv(v61p_dir / "checkpoint_download_plan_rows.csv")
presence_rows = read_csv(v61p_dir / "local_shard_presence_rows.csv")
page_summary_rows = read_csv(v61q_dir / "checkpoint_shard_page_summary_rows.csv")
materialization_rows = read_csv(v61t_dir / "local_checkpoint_materialization_rows.csv")
binding_rows = read_csv(v61v_dir / "remote_sample_tensor_binding_rows.csv")
runtime_node_rows = read_csv(v61v_dir / "remote_sample_runtime_node_rows.csv")

if len(download_rows) != 59 or len(presence_rows) != 59 or len(materialization_rows) != 59:
    raise SystemExit("v61w expects 59 shard rows from v61p/v61t")
if len(binding_rows) != int(v61v_summary["remote_sample_tensor_binding_rows"]):
    raise SystemExit("v61w v61v binding count mismatch")

download_by_shard = {row["shard_name"]: row for row in download_rows}
presence_by_shard = {row["shard_name"]: row for row in presence_rows}
page_summary_by_shard = {row["shard_name"]: row for row in page_summary_rows}
materialization_by_shard = {row["shard_name"]: row for row in materialization_rows}

bindings_by_shard = defaultdict(list)
layers_by_shard = defaultdict(set)
experts_by_shard = defaultdict(set)
roles_by_shard = defaultdict(lambda: defaultdict(int))
for row in binding_rows:
    shard = row["shard_name"]
    bindings_by_shard[shard].append(row)
    roles_by_shard[shard][row["tensor_role"]] += 1
    if row["layer_index"]:
        layers_by_shard[shard].add(row["layer_index"])
    if row["expert_index"]:
        experts_by_shard[shard].add(row["expert_index"])

ssd_disk_budget_pass = int(v61p_summary["ssd_disk_budget_pass"])
ssd_warehouse_outside_repo = int(v61p_summary["ssd_warehouse_outside_repo"])
local_checkpoint_materialization_ready = int(v61t_summary["local_checkpoint_materialization_ready"])
full_safetensors_page_hash_binding_ready = int(v61t_summary["full_safetensors_page_hash_binding_ready"])
remote_sample_tensor_binding_ready = int(v61v_summary["remote_sample_tensor_binding_ready"])

def shard_admission_status(local_identity):
    if local_identity:
        return "already-identity-verified"
    if not ssd_warehouse_outside_repo:
        return "blocked-warehouse-inside-repository"
    if not ssd_disk_budget_pass:
        return "blocked-ssd-disk-budget"
    return "admitted-for-download"


def recommended_action(local_identity, actual_bytes):
    if local_identity:
        return "skip-verified-shard"
    if not ssd_warehouse_outside_repo or not ssd_disk_budget_pass:
        return "wait-for-admission-gates"
    if actual_bytes > 0:
        return "resume-download-then-verify"
    return "download-then-verify"


unranked_rows = []
for shard_name in sorted(download_by_shard, key=shard_number):
    download = download_by_shard[shard_name]
    presence = presence_by_shard[shard_name]
    page_summary = page_summary_by_shard[shard_name]
    materialization = materialization_by_shard[shard_name]
    shard_bindings = bindings_by_shard[shard_name]
    moe_bindings = sum(1 for row in shard_bindings if row["moe_expert_page"] == "1")
    embedding_bindings = sum(1 for row in shard_bindings if row["embedding_page"] == "1")
    local_identity = int(materialization["local_identity_verified"])
    expected_bytes = int(download["expected_bytes"])
    actual_bytes = int(presence["actual_bytes"])
    remaining_bytes = 0 if local_identity else max(expected_bytes - actual_bytes, 0)
    remote_binding_rows = len(shard_bindings)
    score = 0
    if moe_bindings:
        score += 1500
    elif embedding_bindings:
        score += 1200
    elif remote_binding_rows:
        score += 1000
    score += len(layers_by_shard[shard_name]) * 10
    score += len(experts_by_shard[shard_name]) * 3
    score += min(int(page_summary["checkpoint_page_rows"]), 2500) // 100
    if local_identity:
        score -= 5000
    if moe_bindings:
        priority_class = "p0_remote_moe_sampled"
        priority_reason = "remote-hashed sampled page is bound to a MoE expert tensor/runtime node"
    elif embedding_bindings:
        priority_class = "p0_embedding_sampled"
        priority_reason = "remote-hashed sampled page is bound to the embedding tensor/runtime node"
    elif remote_binding_rows:
        priority_class = "p1_remote_sampled"
        priority_reason = "remote-hashed sampled page is bound to a checkpoint tensor/runtime node"
    else:
        priority_class = "p2_checkpoint_backfill"
        priority_reason = "remaining shard needed for full checkpoint materialization and full page-hash sweep"
    admission_status = shard_admission_status(local_identity)
    action = recommended_action(local_identity, actual_bytes)
    blocked_reason = "" if admission_status in ["already-identity-verified", "admitted-for-download"] else admission_status
    verify_command = (
        "V61T_REUSE_EXISTING=0 "
        + rel_command(root / "experiments" / "run_v61t_local_checkpoint_materialization_verifier.sh")
    )
    full_hash_command = (
        "V61R_ENABLE_LOCAL_HASH_SWEEP=1 V61R_REUSE_EXISTING=0 "
        + rel_command(root / "experiments" / "run_v61r_full_page_hash_sweep_plan.sh")
    )
    unranked_rows.append(
        {
            "model_id": model_id,
            "shard_name": shard_name,
            "shard_number": str(shard_number(shard_name)),
            "target_path": download["target_path"],
            "source_url": download["source_url"],
            "expected_bytes": str(expected_bytes),
            "actual_bytes": str(actual_bytes),
            "remaining_bytes": str(remaining_bytes),
            "local_file_exists": presence["local_file_exists"],
            "local_identity_verified": str(local_identity),
            "checkpoint_page_rows": page_summary["checkpoint_page_rows"],
            "tensor_rows": page_summary["tensor_rows"],
            "mapped_tensor_payload_bytes": page_summary["mapped_tensor_payload_bytes"],
            "remote_sample_tensor_binding_rows": str(remote_binding_rows),
            "moe_expert_binding_rows": str(moe_bindings),
            "embedding_binding_rows": str(embedding_bindings),
            "unique_layers_bound": str(len(layers_by_shard[shard_name])),
            "unique_experts_bound": str(len(experts_by_shard[shard_name])),
            "priority_class": priority_class,
            "priority_score": str(score),
            "priority_reason": priority_reason,
            "resume_supported": download["resume_supported"],
            "download_command": download["download_command"],
            "resume_command": download["download_command"] + " --resume-download",
            "post_download_verify_command": verify_command,
            "post_download_full_page_hash_command": full_hash_command,
            "recommended_action": action,
            "admission_status": admission_status,
            "blocked_reason": blocked_reason,
            "checkpoint_payload_bytes_downloaded_by_v61w": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

priority_sorted = sorted(unranked_rows, key=lambda row: (-int(row["priority_score"]), int(row["shard_number"])))
priority_rows = []
resume_rows = []
for rank, row in enumerate(priority_sorted, start=1):
    ranked = dict(row)
    ranked["priority_rank"] = str(rank)
    ordered = {
        "priority_rank": ranked["priority_rank"],
        **{key: ranked[key] for key in row.keys()},
    }
    priority_rows.append(ordered)
    resume_rows.append(
        {
            "plan_id": f"v61w:resume:{rank:02d}:{row['shard_name']}",
            "priority_rank": str(rank),
            "model_id": model_id,
            "shard_name": row["shard_name"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "actual_bytes": row["actual_bytes"],
            "remaining_bytes": row["remaining_bytes"],
            "resume_supported": row["resume_supported"],
            "download_command": row["download_command"],
            "resume_command": row["resume_command"],
            "post_download_verify_command": row["post_download_verify_command"],
            "post_download_full_page_hash_command": row["post_download_full_page_hash_command"],
            "priority_class": row["priority_class"],
            "recommended_action": row["recommended_action"],
            "admission_status": row["admission_status"],
            "blocked_reason": row["blocked_reason"],
            "writes_inside_repository": "0",
            "checkpoint_payload_bytes_downloaded_by_v61w": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

write_csv(run_dir / "checkpoint_shard_priority_rows.csv", list(priority_rows[0].keys()), priority_rows)
write_csv(run_dir / "checkpoint_download_resume_plan_rows.csv", list(resume_rows[0].keys()), resume_rows)

sampled_priority_shard_rows = sum(1 for row in priority_rows if row["remote_sample_tensor_binding_rows"] != "0")
moe_priority_shard_rows = sum(1 for row in priority_rows if row["moe_expert_binding_rows"] != "0")
embedding_priority_shard_rows = sum(1 for row in priority_rows if row["embedding_binding_rows"] != "0")
planned_remaining_bytes = sum(int(row["remaining_bytes"]) for row in priority_rows)

admission_rows = [
    {
        "gate": "v61p-local-ssd-residency-preflight-input",
        "status": "pass",
        "evidence_rows": "1",
        "reason": "v61p summary and shard download plan are bound",
    },
    {
        "gate": "v61t-local-materialization-verifier-input",
        "status": "pass",
        "evidence_rows": "1",
        "reason": "v61t current local identity verification rows are bound",
    },
    {
        "gate": "v61v-remote-page-tensor-binding-input",
        "status": "pass",
        "evidence_rows": v61v_summary["remote_sample_tensor_binding_rows"],
        "reason": "remote hashed sampled pages are bound to tensor/runtime nodes",
    },
    {
        "gate": "outside-repository-warehouse",
        "status": "pass" if ssd_warehouse_outside_repo else "blocked",
        "evidence_rows": "1",
        "reason": f"warehouse_path={v61p_summary['ssd_warehouse_path']}",
    },
    {
        "gate": "ssd-disk-budget",
        "status": "pass" if ssd_disk_budget_pass else "blocked",
        "evidence_rows": "1",
        "reason": f"available={v61p_summary['available_ssd_bytes']}; required_with_reserve={v61p_summary['required_with_reserve_bytes']}",
    },
    {
        "gate": "download-resume-plan",
        "status": "pass",
        "evidence_rows": str(len(resume_rows)),
        "reason": "all checkpoint shards have deterministic priority, resume, and post-download verification rows",
    },
    {
        "gate": "moe-first-priority-plan",
        "status": "pass" if moe_priority_shard_rows > 0 else "blocked",
        "evidence_rows": str(moe_priority_shard_rows),
        "reason": "remote-hashed sampled MoE expert shards are promoted ahead of backfill shards",
    },
    {
        "gate": "local-checkpoint-materialization",
        "status": "pass" if local_checkpoint_materialization_ready else "blocked",
        "evidence_rows": v61t_summary["local_identity_verified_shard_rows"],
        "reason": "requires all 59 shards to pass size, header, and sampled page identity checks",
    },
    {
        "gate": "full-safetensors-page-hash-binding",
        "status": "pass" if full_safetensors_page_hash_binding_ready else "blocked",
        "evidence_rows": v61t_summary["full_page_hash_verified_rows"],
        "reason": "requires local hash coverage for every v61q checkpoint page",
    },
    {
        "gate": "manifest-only-no-repo-payload",
        "status": "pass",
        "evidence_rows": str(len(priority_rows)),
        "reason": "v61w emits metadata and commands only; no checkpoint payload bytes are written to repository artifacts",
    },
]
write_csv(run_dir / "materialization_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)

stage_rows = [
    ("01", "bind-v61p-v61t-v61v-inputs", "ready", "preflight, verifier, and remote tensor binding inputs are present"),
    ("02", "outside-repository-warehouse", "ready" if ssd_warehouse_outside_repo else "blocked", "checkpoint warehouse must remain outside the git repository"),
    ("03", "ssd-disk-budget-admission", "ready" if ssd_disk_budget_pass else "blocked", "available SSD bytes must cover checkpoint bytes plus reserve"),
    ("04", "download-resume-by-priority", "planned", "59 deterministic resume rows prioritize remote-hashed MoE/embedding shards first"),
    ("05", "post-download-size-header-sampled-page-verify", "blocked" if not local_checkpoint_materialization_ready else "ready", "v61t must verify all local shard identities after download"),
    ("06", "full-safetensors-page-hash-sweep", "blocked" if not full_safetensors_page_hash_binding_ready else "ready", "v61r full local page hash sweep must cover every v61q page"),
    ("07", "runtime-node-residency-promote", "blocked" if not local_checkpoint_materialization_ready else "planned", "v61v sampled runtime nodes can become local-resident only after materialization"),
    ("08", "real-model-source-bound-generation", "blocked", "real Mixtral generation over source-bound QA is not executed by v61w"),
    ("09", "production-and-release-claims", "blocked", "latency, quality, near-frontier, and release claims remain out of scope"),
]
write_csv(
    run_dir / "materialization_stage_rows.csv",
    ["stage_order", "stage", "status", "reason"],
    [{"stage_order": a, "stage": b, "status": c, "reason": d} for a, b, c, d in stage_rows],
)

gap_rows = [
    ("download-resume-plan", "ready", "all 59 shards have a deterministic resume plan"),
    ("moe-first-shard-priority", "ready" if moe_priority_shard_rows else "blocked", "remote-hashed MoE sample shards are scheduled before generic backfill shards"),
    ("ssd-disk-budget-admission", "ready" if ssd_disk_budget_pass else "blocked", "current host does not meet checkpoint plus reserve byte budget" if not ssd_disk_budget_pass else "SSD budget covers checkpoint plus reserve"),
    ("local-checkpoint-materialization", "ready" if local_checkpoint_materialization_ready else "blocked", "all shards must be local and identity verified"),
    ("full-safetensors-page-hash-binding", "ready" if full_safetensors_page_hash_binding_ready else "blocked", "full page-hash coverage is not verified"),
    ("actual-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality result"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "materialization_runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

download_resume_plan_ready = int(len(resume_rows) == 59 and all(row["resume_supported"] == "1" for row in resume_rows))
moe_first_priority_plan_ready = int(moe_priority_shard_rows > 0 and priority_rows[0]["priority_class"] == "p0_remote_moe_sampled")
materialization_admission_ready = int(
    ssd_warehouse_outside_repo
    and ssd_disk_budget_pass
    and download_resume_plan_ready
    and remote_sample_tensor_binding_ready
)
materialization_execution_ready = int(
    materialization_admission_ready
    and local_checkpoint_materialization_ready
    and full_safetensors_page_hash_binding_ready
)

metric_rows = [
    {
        "model_id": model_id,
        "checkpoint_shard_rows": str(len(priority_rows)),
        "download_resume_plan_rows": str(len(resume_rows)),
        "sampled_priority_shard_rows": str(sampled_priority_shard_rows),
        "moe_priority_shard_rows": str(moe_priority_shard_rows),
        "embedding_priority_shard_rows": str(embedding_priority_shard_rows),
        "remote_sample_tensor_binding_rows": v61v_summary["remote_sample_tensor_binding_rows"],
        "planned_remaining_bytes": str(planned_remaining_bytes),
        "total_checkpoint_bytes_required": v61p_summary["total_checkpoint_bytes_required"],
        "required_with_reserve_bytes": v61p_summary["required_with_reserve_bytes"],
        "available_ssd_bytes": v61p_summary["available_ssd_bytes"],
        "ssd_disk_budget_pass": str(ssd_disk_budget_pass),
        "ssd_warehouse_outside_repo": str(ssd_warehouse_outside_repo),
        "local_existing_shard_rows": v61t_summary["local_existing_shard_rows"],
        "local_identity_verified_shard_rows": v61t_summary["local_identity_verified_shard_rows"],
        "download_resume_plan_ready": str(download_resume_plan_ready),
        "moe_first_priority_plan_ready": str(moe_first_priority_plan_ready),
        "materialization_admission_ready": str(materialization_admission_ready),
        "materialization_execution_ready": str(materialization_execution_ready),
        "local_checkpoint_materialization_ready": str(local_checkpoint_materialization_ready),
        "full_safetensors_page_hash_binding_ready": str(full_safetensors_page_hash_binding_ready),
        "checkpoint_payload_bytes_downloaded_by_v61w": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "actual_model_generation_ready": "0",
    }
]
write_csv(run_dir / "materialization_admission_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

summary = {
    "v61w_materialization_admission_resume_plan_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": v61p_summary["v61p_local_ssd_checkpoint_residency_preflight_ready"],
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "v61v_remote_page_tensor_binding_ready": v61v_summary["v61v_remote_page_tensor_binding_ready"],
    "model_id": model_id,
    "checkpoint_shard_rows": str(len(priority_rows)),
    "download_resume_plan_rows": str(len(resume_rows)),
    "sampled_priority_shard_rows": str(sampled_priority_shard_rows),
    "moe_priority_shard_rows": str(moe_priority_shard_rows),
    "embedding_priority_shard_rows": str(embedding_priority_shard_rows),
    "remote_sample_tensor_binding_rows": v61v_summary["remote_sample_tensor_binding_rows"],
    "planned_remaining_bytes": str(planned_remaining_bytes),
    "total_checkpoint_bytes_required": v61p_summary["total_checkpoint_bytes_required"],
    "required_with_reserve_bytes": v61p_summary["required_with_reserve_bytes"],
    "available_ssd_bytes": v61p_summary["available_ssd_bytes"],
    "ssd_disk_budget_pass": str(ssd_disk_budget_pass),
    "ssd_warehouse_outside_repo": str(ssd_warehouse_outside_repo),
    "local_existing_shard_rows": v61t_summary["local_existing_shard_rows"],
    "local_identity_verified_shard_rows": v61t_summary["local_identity_verified_shard_rows"],
    "download_resume_plan_ready": str(download_resume_plan_ready),
    "moe_first_priority_plan_ready": str(moe_first_priority_plan_ready),
    "materialization_admission_ready": str(materialization_admission_ready),
    "materialization_execution_ready": str(materialization_execution_ready),
    "local_checkpoint_materialization_ready": str(local_checkpoint_materialization_ready),
    "full_safetensors_page_hash_binding_ready": str(full_safetensors_page_hash_binding_ready),
    "checkpoint_payload_bytes_downloaded_by_v61w": "0",
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

decision_rows = [
    ("v61p-local-ssd-residency-preflight-input", "pass", "v61p preflight and 59-shard download plan are bound"),
    ("v61q-real-checkpoint-page-map-input", "pass", "v61q page map summary is bound"),
    ("v61t-local-materialization-verifier-input", "pass", "v61t local materialization verifier status is bound"),
    ("v61v-remote-page-tensor-binding-input", "pass", "v61v remote page tensor/runtime node bindings are bound"),
    ("download-resume-plan", "pass" if download_resume_plan_ready else "blocked", f"download_resume_plan_rows={len(resume_rows)}"),
    ("moe-first-priority-plan", "pass" if moe_first_priority_plan_ready else "blocked", f"moe_priority_shard_rows={moe_priority_shard_rows}"),
    ("manifest-only-no-repo-payload", "pass", "v61w writes metadata, hashes, and commands only"),
    ("ssd-disk-budget-admission", "pass" if ssd_disk_budget_pass else "blocked", f"available={v61p_summary['available_ssd_bytes']}; required_with_reserve={v61p_summary['required_with_reserve_bytes']}"),
    ("materialization-admission", "pass" if materialization_admission_ready else "blocked", "requires outside-repo warehouse, SSD budget, resume plan, and remote tensor binding"),
    ("local-checkpoint-materialization", "pass" if local_checkpoint_materialization_ready else "blocked", "requires all local shards to pass identity verification"),
    ("full-safetensors-page-hash-binding", "pass" if full_safetensors_page_hash_binding_ready else "blocked", "requires full local page-hash sweep coverage"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61W_MATERIALIZATION_ADMISSION_RESUME_PLAN_BOUNDARY.md").write_text(
    "# v61w Materialization Admission Resume Plan Boundary\n\n"
    "This layer converts the v61p/v61t local checkpoint blockers and the v61v remote-hashed tensor bindings into an executable materialization admission and resume plan. "
    "It prioritizes remote-hashed MoE expert and embedding shards before generic backfill shards, records deterministic resume commands, and binds post-download identity and full-page-hash verification commands. "
    "It does not download checkpoint shards, does not persist checkpoint payload bytes, and does not execute real Mixtral generation.\n\n"
    f"- checkpoint_shard_rows={len(priority_rows)}\n"
    f"- download_resume_plan_rows={len(resume_rows)}\n"
    f"- sampled_priority_shard_rows={sampled_priority_shard_rows}\n"
    f"- moe_priority_shard_rows={moe_priority_shard_rows}\n"
    f"- embedding_priority_shard_rows={embedding_priority_shard_rows}\n"
    f"- planned_remaining_bytes={planned_remaining_bytes}\n"
    f"- total_checkpoint_bytes_required={v61p_summary['total_checkpoint_bytes_required']}\n"
    f"- required_with_reserve_bytes={v61p_summary['required_with_reserve_bytes']}\n"
    f"- available_ssd_bytes={v61p_summary['available_ssd_bytes']}\n"
    f"- ssd_disk_budget_pass={ssd_disk_budget_pass}\n"
    f"- download_resume_plan_ready={download_resume_plan_ready}\n"
    f"- moe_first_priority_plan_ready={moe_first_priority_plan_ready}\n"
    f"- materialization_admission_ready={materialization_admission_ready}\n"
    f"- materialization_execution_ready={materialization_execution_ready}\n"
    f"- local_checkpoint_materialization_ready={local_checkpoint_materialization_ready}\n"
    f"- full_safetensors_page_hash_binding_ready={full_safetensors_page_hash_binding_ready}\n"
    "- checkpoint_payload_bytes_downloaded_by_v61w=0\n"
    "- checkpoint_payload_bytes_committed_to_repo=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- real_100b_open_weight_materialized=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: materialization admission/resume plan, MoE-first shard priority, and post-download verification command binding for Mixtral checkpoint shards. "
    "Blocked wording: completed SSD-resident checkpoint materialization, full page-hash coverage, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61w-materialization-admission-resume-plan",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61w_materialization_admission_resume_plan_ready": 1,
    "v61p_summary_sha256": sha256(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    "v61q_summary_sha256": sha256(results / "v61q_real_checkpoint_page_map_summary.csv"),
    "v61t_summary_sha256": sha256(results / "v61t_local_checkpoint_materialization_verifier_summary.csv"),
    "v61v_summary_sha256": sha256(results / "v61v_remote_page_tensor_binding_summary.csv"),
    "checkpoint_shard_rows": len(priority_rows),
    "download_resume_plan_rows": len(resume_rows),
    "sampled_priority_shard_rows": sampled_priority_shard_rows,
    "moe_priority_shard_rows": moe_priority_shard_rows,
    "embedding_priority_shard_rows": embedding_priority_shard_rows,
    "planned_remaining_bytes": planned_remaining_bytes,
    "ssd_disk_budget_pass": ssd_disk_budget_pass,
    "ssd_warehouse_outside_repo": ssd_warehouse_outside_repo,
    "download_resume_plan_ready": download_resume_plan_ready,
    "moe_first_priority_plan_ready": moe_first_priority_plan_ready,
    "materialization_admission_ready": materialization_admission_ready,
    "materialization_execution_ready": materialization_execution_ready,
    "local_checkpoint_materialization_ready": local_checkpoint_materialization_ready,
    "full_safetensors_page_hash_binding_ready": full_safetensors_page_hash_binding_ready,
    "checkpoint_payload_bytes_downloaded_by_v61w": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61w_materialization_admission_resume_plan_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "checkpoint_shard_priority_rows.csv",
    "checkpoint_download_resume_plan_rows.csv",
    "materialization_admission_rows.csv",
    "materialization_stage_rows.csv",
    "materialization_runtime_gap_rows.csv",
    "materialization_admission_metric_rows.csv",
    "V61W_MATERIALIZATION_ADMISSION_RESUME_PLAN_BOUNDARY.md",
    "v61w_materialization_admission_resume_plan_manifest.json",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_decision.csv",
    "source_v61p/ssd_warehouse_probe_rows.csv",
    "source_v61p/ssd_disk_budget_rows.csv",
    "source_v61p/checkpoint_residency_requirement_rows.csv",
    "source_v61p/checkpoint_download_plan_rows.csv",
    "source_v61p/local_shard_presence_rows.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_manifest.json",
    "source_v61p/sha256_manifest.csv",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
    "source_v61q/checkpoint_page_map_metric_rows.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "source_v61t/local_checkpoint_materialization_metric_rows.csv",
    "source_v61t/materialization_gap_rows.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_manifest.json",
    "source_v61t/sha256_manifest.csv",
    "source_v61v/v61v_remote_page_tensor_binding_summary.csv",
    "source_v61v/v61v_remote_page_tensor_binding_decision.csv",
    "source_v61v/remote_sample_tensor_binding_rows.csv",
    "source_v61v/remote_sample_runtime_node_rows.csv",
    "source_v61v/remote_sample_tensor_role_summary_rows.csv",
    "source_v61v/remote_sample_tensor_coverage_rows.csv",
    "source_v61v/remote_sample_tensor_binding_metric_rows.csv",
    "source_v61v/v61v_remote_page_tensor_binding_manifest.json",
    "source_v61v/sha256_manifest.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61w_materialization_admission_resume_plan_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
