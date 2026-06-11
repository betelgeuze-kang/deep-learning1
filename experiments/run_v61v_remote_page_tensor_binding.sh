#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61v_remote_page_tensor_binding"
RUN_ID="${V61V_RUN_ID:-binding_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61V_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61v_remote_page_tensor_binding_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61u_remote_checkpoint_page_hash_sampler.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61u_dir = results / "v61u_remote_checkpoint_page_hash_sampler" / "sample_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"

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


def tensor_role(tensor_name):
    if tensor_name == "model.embed_tokens.weight":
        return "embedding"
    if tensor_name == "lm_head.weight":
        return "lm_head"
    match = re.search(r"\.experts\.\d+\.(w[123])\.weight$", tensor_name)
    if match:
        return f"moe_{match.group(1)}"
    if ".self_attn." in tensor_name:
        return "attention"
    if ".input_layernorm." in tensor_name or ".post_attention_layernorm." in tensor_name:
        return "layernorm"
    return "other"


def layer_expert(tensor_name):
    layer = ""
    expert = ""
    layer_match = re.search(r"model\.layers\.(\d+)\.", tensor_name)
    expert_match = re.search(r"\.experts\.(\d+)\.", tensor_name)
    if layer_match:
        layer = layer_match.group(1)
    if expert_match:
        expert = expert_match.group(1)
    return layer, expert


v61u_summary = read_csv(results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv")[0]
if v61u_summary.get("v61u_remote_checkpoint_page_hash_sampler_ready") != "1":
    raise SystemExit("v61v requires v61u_remote_checkpoint_page_hash_sampler_ready=1")

for src, rel in [
    (results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv", "source_v61u/v61u_remote_checkpoint_page_hash_sampler_summary.csv"),
    (results / "v61u_remote_checkpoint_page_hash_sampler_decision.csv", "source_v61u/v61u_remote_checkpoint_page_hash_sampler_decision.csv"),
    (v61u_dir / "remote_page_hash_sample_rows.csv", "source_v61u/remote_page_hash_sample_rows.csv"),
    (v61u_dir / "remote_page_hash_page_map_overlap_rows.csv", "source_v61u/remote_page_hash_page_map_overlap_rows.csv"),
    (v61u_dir / "remote_page_hash_sample_metric_rows.csv", "source_v61u/remote_page_hash_sample_metric_rows.csv"),
    (v61u_dir / "v61u_remote_checkpoint_page_hash_sampler_manifest.json", "source_v61u/v61u_remote_checkpoint_page_hash_sampler_manifest.json"),
    (v61u_dir / "sha256_manifest.csv", "source_v61u/sha256_manifest.csv"),
    (results / "v61q_real_checkpoint_page_map_summary.csv", "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (v61q_dir / "checkpoint_page_map_metric_rows.csv", "source_v61q/checkpoint_page_map_metric_rows.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
]:
    copy(src, rel)

sample_rows = read_csv(v61u_dir / "remote_page_hash_sample_rows.csv")
if len(sample_rows) != int(v61u_summary["remote_page_hash_sample_rows"]):
    raise SystemExit("v61v sample rows differ from v61u summary")
sample_by_page = {row["source_page_id"]: row for row in sample_rows}
sample_pages = set(sample_by_page)

selected_segment_rows = []
with (v61q_dir / "checkpoint_page_segment_rows.csv").open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        if row["page_id"] in sample_pages:
            selected_segment_rows.append(row)
if not selected_segment_rows:
    raise SystemExit("v61v did not find v61q tensor segments for v61u sample pages")
write_csv(run_dir / "selected_v61q_page_segment_rows.csv", list(selected_segment_rows[0].keys()), selected_segment_rows)

binding_rows = []
runtime_node_rows = []
role_counts = Counter()
role_bytes = Counter()
layer_set = set()
expert_set = set()
moe_expert_binding_rows = 0
embedding_binding_rows = 0
remote_hash_bound_rows = 0
route_jump_rows = 0

for segment in selected_segment_rows:
    sample = sample_by_page[segment["page_id"]]
    role = tensor_role(segment["tensor_name"])
    layer, expert = layer_expert(segment["tensor_name"])
    is_moe = int(role.startswith("moe_") and layer != "" and expert != "")
    is_embedding = int(role == "embedding")
    if layer:
        layer_set.add(layer)
    if expert:
        expert_set.add(expert)
    moe_expert_binding_rows += is_moe
    embedding_binding_rows += is_embedding
    remote_hash_bound_rows += int(sample["remote_page_hash_sample_ready"] == "1")
    role_counts[role] += 1
    role_bytes[role] += int(segment["tensor_segment_bytes"])
    scheduler_node_type = "moe_expert_page_node" if is_moe else ("embedding_page_node" if is_embedding else "tensor_page_node")
    binding_id = f"v61v:{sample['remote_sample_id']}:{segment['page_segment_id'].split(':')[-1]}"
    binding_rows.append(
        {
            "binding_id": binding_id,
            "remote_sample_id": sample["remote_sample_id"],
            "source_page_id": segment["page_id"],
            "remote_page_sha256": sample["remote_page_sha256"],
            "model_id": model_id,
            "shard_name": segment["shard_name"],
            "shard_page_index": segment["shard_page_index"],
            "tensor_name": segment["tensor_name"],
            "tensor_role": role,
            "layer_index": layer,
            "expert_index": expert,
            "dtype": segment["dtype"],
            "tensor_segment_bytes": segment["tensor_segment_bytes"],
            "page_offset_start": segment["page_offset_start"],
            "page_offset_end": segment["page_offset_end"],
            "tensor_offset_start_in_tensor": segment["tensor_offset_start_in_tensor"],
            "tensor_offset_end_in_tensor": segment["tensor_offset_end_in_tensor"],
            "moe_expert_page": str(is_moe),
            "embedding_page": str(is_embedding),
            "remote_hash_bound": sample["remote_page_hash_sample_ready"],
            "checkpoint_payload_bytes_persisted": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
    runtime_node_rows.append(
        {
            "runtime_node_id": f"v61v_node_{sample['remote_sample_id']}",
            "binding_id": binding_id,
            "node_type": scheduler_node_type,
            "model_id": model_id,
            "layer_index": layer,
            "expert_index": expert,
            "tensor_role": role,
            "source_page_id": segment["page_id"],
            "remote_page_sha256": sample["remote_page_sha256"],
            "storage_tier": "remote-hash-sample-not-local-resident",
            "dtype": segment["dtype"],
            "quant_profile_id": "bf16-source-checkpoint",
            "prefetch_candidate": str(int(is_moe or is_embedding)),
            "local_resident": "0",
            "remote_hash_bound": sample["remote_page_hash_sample_ready"],
            "page_hash_full_coverage_ready": "0",
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "remote_sample_tensor_binding_rows.csv", list(binding_rows[0].keys()), binding_rows)
write_csv(run_dir / "remote_sample_runtime_node_rows.csv", list(runtime_node_rows[0].keys()), runtime_node_rows)

role_summary_rows = [
    {
        "tensor_role": role,
        "binding_rows": str(role_counts[role]),
        "tensor_segment_bytes": str(role_bytes[role]),
        "remote_hash_bound_rows": str(sum(1 for row in binding_rows if row["tensor_role"] == role and row["remote_hash_bound"] == "1")),
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
    for role in sorted(role_counts)
]
write_csv(run_dir / "remote_sample_tensor_role_summary_rows.csv", list(role_summary_rows[0].keys()), role_summary_rows)

coverage_rows = [
    {
        "coverage_axis": "remote_samples",
        "covered_rows": str(len(sample_rows)),
        "expected_rows": v61u_summary["remote_page_hash_sample_rows"],
        "coverage_ready": str(int(len(sample_rows) == int(v61u_summary["remote_page_hash_sample_rows"]))),
    },
    {
        "coverage_axis": "tensor_bindings",
        "covered_rows": str(len(binding_rows)),
        "expected_rows": str(len(sample_rows)),
        "coverage_ready": str(int(len(binding_rows) >= len(sample_rows))),
    },
    {
        "coverage_axis": "moe_expert_bindings",
        "covered_rows": str(moe_expert_binding_rows),
        "expected_rows": "1",
        "coverage_ready": str(int(moe_expert_binding_rows > 0)),
    },
    {
        "coverage_axis": "layer_indices",
        "covered_rows": str(len(layer_set)),
        "expected_rows": "1",
        "coverage_ready": str(int(len(layer_set) > 0)),
    },
    {
        "coverage_axis": "expert_indices",
        "covered_rows": str(len(expert_set)),
        "expected_rows": "1",
        "coverage_ready": str(int(len(expert_set) > 0)),
    },
]
write_csv(run_dir / "remote_sample_tensor_coverage_rows.csv", list(coverage_rows[0].keys()), coverage_rows)

remote_sample_tensor_binding_ready = int(len(binding_rows) >= len(sample_rows) and remote_hash_bound_rows == len(binding_rows))
metric_rows = [
    {
        "model_id": model_id,
        "remote_page_hash_sample_rows": str(len(sample_rows)),
        "remote_sample_tensor_binding_rows": str(len(binding_rows)),
        "remote_sample_runtime_node_rows": str(len(runtime_node_rows)),
        "remote_sample_tensor_role_rows": str(len(role_summary_rows)),
        "remote_hash_bound_rows": str(remote_hash_bound_rows),
        "moe_expert_binding_rows": str(moe_expert_binding_rows),
        "embedding_binding_rows": str(embedding_binding_rows),
        "unique_layer_indices": str(len(layer_set)),
        "unique_expert_indices": str(len(expert_set)),
        "remote_sample_tensor_binding_ready": str(remote_sample_tensor_binding_ready),
        "full_safetensors_page_hash_binding_ready": "0",
        "local_checkpoint_materialization_ready": v61u_summary["local_checkpoint_materialization_ready"],
        "checkpoint_payload_bytes_persisted": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "actual_model_generation_ready": "0",
        "route_jump_rows": str(route_jump_rows),
    }
]
write_csv(run_dir / "remote_sample_tensor_binding_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

gap_rows = [
    ("remote-sample-tensor-binding", "ready" if remote_sample_tensor_binding_ready else "blocked", "v61u remote page hashes are bound to v61q tensor segments"),
    ("moe-expert-runtime-node-binding", "ready" if moe_expert_binding_rows > 0 else "blocked", "at least one remote-hashed page is bound to a MoE expert tensor"),
    ("local-checkpoint-materialization", "ready" if v61u_summary["local_checkpoint_materialization_ready"] == "1" else "blocked", "local shards are not identity-verified on the current host"),
    ("full-safetensors-page-hash-binding", "blocked", "v61v binds sampled pages only, not all v61q checkpoint pages"),
    ("real-model-generation", "blocked", "v61v does not execute real Mixtral generation"),
    ("near-frontier-quality", "blocked", "tensor binding is not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61v_remote_page_tensor_binding_ready": "1",
    "v61u_remote_checkpoint_page_hash_sampler_ready": v61u_summary["v61u_remote_checkpoint_page_hash_sampler_ready"],
    "model_id": model_id,
    "remote_page_hash_sample_rows": str(len(sample_rows)),
    "remote_sample_tensor_binding_rows": str(len(binding_rows)),
    "remote_sample_runtime_node_rows": str(len(runtime_node_rows)),
    "remote_sample_tensor_role_rows": str(len(role_summary_rows)),
    "remote_hash_bound_rows": str(remote_hash_bound_rows),
    "moe_expert_binding_rows": str(moe_expert_binding_rows),
    "embedding_binding_rows": str(embedding_binding_rows),
    "unique_layer_indices": str(len(layer_set)),
    "unique_expert_indices": str(len(expert_set)),
    "remote_sample_tensor_binding_ready": str(remote_sample_tensor_binding_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "local_checkpoint_materialization_ready": v61u_summary["local_checkpoint_materialization_ready"],
    "checkpoint_payload_bytes_persisted": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": str(route_jump_rows),
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61u-remote-page-hash-sampler-input", "pass", "v61u remote page-hash samples are bound"),
    ("remote-sample-tensor-binding", "pass" if remote_sample_tensor_binding_ready else "blocked", f"binding_rows={len(binding_rows)}"),
    ("moe-expert-runtime-node-binding", "pass" if moe_expert_binding_rows > 0 else "blocked", f"moe_expert_binding_rows={moe_expert_binding_rows}"),
    ("manifest-only-no-repo-payload", "pass", "v61v writes tensor bindings and hashes only"),
    ("local-checkpoint-materialization", "pass" if v61u_summary["local_checkpoint_materialization_ready"] == "1" else "blocked", "requires identity-verified local shards"),
    ("full-safetensors-page-hash-binding", "blocked", "sampled tensor bindings are not full page-hash coverage"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61V_REMOTE_PAGE_TENSOR_BINDING_BOUNDARY.md").write_text(
    "# v61v Remote Page Tensor Binding Boundary\n\n"
    "This layer binds v61u remote checkpoint page-hash samples to v61q tensor/page segments and emits runtime scheduling nodes for the sampled real-model pages. "
    "It stores hashes and metadata only. It does not provide full page-hash coverage, local checkpoint materialization, or real Mixtral generation.\n\n"
    f"- remote_page_hash_sample_rows={len(sample_rows)}\n"
    f"- remote_sample_tensor_binding_rows={len(binding_rows)}\n"
    f"- moe_expert_binding_rows={moe_expert_binding_rows}\n"
    f"- embedding_binding_rows={embedding_binding_rows}\n"
    f"- unique_layer_indices={len(layer_set)}\n"
    f"- unique_expert_indices={len(expert_set)}\n"
    f"- remote_sample_tensor_binding_ready={remote_sample_tensor_binding_ready}\n"
    "- full_safetensors_page_hash_binding_ready=0\n"
    f"- local_checkpoint_materialization_ready={v61u_summary['local_checkpoint_materialization_ready']}\n"
    "- checkpoint_payload_bytes_persisted=0\n"
    "- checkpoint_payload_bytes_committed_to_repo=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: remote-hashed sampled checkpoint pages are bound to tensor, layer, expert, and runtime-node metadata. "
    "Blocked wording: full safetensors page-hash coverage, completed local checkpoint materialization, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61v-remote-page-tensor-binding",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61v_remote_page_tensor_binding_ready": 1,
    "v61u_summary_sha256": sha256(results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv"),
    "v61q_segment_source_sha256": sha256(v61q_dir / "checkpoint_page_segment_rows.csv"),
    "remote_page_hash_sample_rows": len(sample_rows),
    "remote_sample_tensor_binding_rows": len(binding_rows),
    "remote_sample_runtime_node_rows": len(runtime_node_rows),
    "moe_expert_binding_rows": moe_expert_binding_rows,
    "embedding_binding_rows": embedding_binding_rows,
    "unique_layer_indices": len(layer_set),
    "unique_expert_indices": len(expert_set),
    "remote_sample_tensor_binding_ready": remote_sample_tensor_binding_ready,
    "full_safetensors_page_hash_binding_ready": 0,
    "local_checkpoint_materialization_ready": int(v61u_summary["local_checkpoint_materialization_ready"]),
    "checkpoint_payload_bytes_persisted": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61v_remote_page_tensor_binding_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "selected_v61q_page_segment_rows.csv",
    "remote_sample_tensor_binding_rows.csv",
    "remote_sample_runtime_node_rows.csv",
    "remote_sample_tensor_role_summary_rows.csv",
    "remote_sample_tensor_coverage_rows.csv",
    "remote_sample_tensor_binding_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61V_REMOTE_PAGE_TENSOR_BINDING_BOUNDARY.md",
    "v61v_remote_page_tensor_binding_manifest.json",
    "source_v61u/v61u_remote_checkpoint_page_hash_sampler_summary.csv",
    "source_v61u/v61u_remote_checkpoint_page_hash_sampler_decision.csv",
    "source_v61u/remote_page_hash_sample_rows.csv",
    "source_v61u/remote_page_hash_page_map_overlap_rows.csv",
    "source_v61u/remote_page_hash_sample_metric_rows.csv",
    "source_v61u/v61u_remote_checkpoint_page_hash_sampler_manifest.json",
    "source_v61u/sha256_manifest.csv",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/checkpoint_page_map_metric_rows.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61v_remote_page_tensor_binding_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
