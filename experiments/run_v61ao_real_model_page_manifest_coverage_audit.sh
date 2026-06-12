#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ao_real_model_page_manifest_coverage_audit"
RUN_ID="${V61AO_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ao_real_model_page_manifest_coverage_audit_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61Q_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61q_real_checkpoint_page_map.sh" >/dev/null
V61V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61v_remote_page_tensor_binding.sh" >/dev/null
V61AN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61an_checkpoint_full_page_hash_execution_gate.sh" >/dev/null

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

model_id = "mistralai/Mixtral-8x22B-v0.1"
expected_layers = 56
expected_experts = 8
expected_moe_tensor_roles = ["moe_w1", "moe_w2", "moe_w3"]

v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61v_dir = results / "v61v_remote_page_tensor_binding" / "binding_001"
v61an_dir = results / "v61an_checkpoint_full_page_hash_execution_gate" / "gate_001"


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
    if ".input_layernorm." in tensor_name or ".post_attention_layernorm." in tensor_name or tensor_name == "model.norm.weight":
        return "layernorm"
    if ".block_sparse_moe.gate.weight" in tensor_name:
        return "router_gate"
    return "other"


def layer_expert(tensor_name):
    layer_match = re.search(r"model\.layers\.(\d+)\.", tensor_name)
    expert_match = re.search(r"\.experts\.(\d+)\.", tensor_name)
    layer = layer_match.group(1) if layer_match else ""
    expert = expert_match.group(1) if expert_match else ""
    return layer, expert


v61q_summary = read_csv(results / "v61q_real_checkpoint_page_map_summary.csv")[0]
v61v_summary = read_csv(results / "v61v_remote_page_tensor_binding_summary.csv")[0]
v61an_summary = read_csv(results / "v61an_checkpoint_full_page_hash_execution_gate_summary.csv")[0]
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61ao requires v61q_real_checkpoint_page_map_ready=1")
if v61v_summary.get("v61v_remote_page_tensor_binding_ready") != "1":
    raise SystemExit("v61ao requires v61v_remote_page_tensor_binding_ready=1")
if v61an_summary.get("v61an_checkpoint_full_page_hash_execution_gate_ready") != "1":
    raise SystemExit("v61ao requires v61an_checkpoint_full_page_hash_execution_gate_ready=1")

for src, rel in [
    (results / "v61q_real_checkpoint_page_map_summary.csv", "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (results / "v61q_real_checkpoint_page_map_decision.csv", "source_v61q/v61q_real_checkpoint_page_map_decision.csv"),
    (v61q_dir / "checkpoint_tensor_page_span_rows.csv", "source_v61q/checkpoint_tensor_page_span_rows.csv"),
    (v61q_dir / "checkpoint_page_segment_rows.csv", "source_v61q/checkpoint_page_segment_rows.csv"),
    (v61q_dir / "checkpoint_unique_page_rows.csv", "source_v61q/checkpoint_unique_page_rows.csv"),
    (v61q_dir / "checkpoint_shard_page_summary_rows.csv", "source_v61q/checkpoint_shard_page_summary_rows.csv"),
    (v61q_dir / "checkpoint_page_map_metric_rows.csv", "source_v61q/checkpoint_page_map_metric_rows.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
    (results / "v61v_remote_page_tensor_binding_summary.csv", "source_v61v/v61v_remote_page_tensor_binding_summary.csv"),
    (results / "v61v_remote_page_tensor_binding_decision.csv", "source_v61v/v61v_remote_page_tensor_binding_decision.csv"),
    (v61v_dir / "remote_sample_tensor_binding_rows.csv", "source_v61v/remote_sample_tensor_binding_rows.csv"),
    (v61v_dir / "remote_sample_runtime_node_rows.csv", "source_v61v/remote_sample_runtime_node_rows.csv"),
    (v61v_dir / "remote_sample_tensor_coverage_rows.csv", "source_v61v/remote_sample_tensor_coverage_rows.csv"),
    (v61v_dir / "remote_sample_tensor_binding_metric_rows.csv", "source_v61v/remote_sample_tensor_binding_metric_rows.csv"),
    (v61v_dir / "source_v61u/remote_page_hash_sample_rows.csv", "source_v61v/source_v61u/remote_page_hash_sample_rows.csv"),
    (v61v_dir / "v61v_remote_page_tensor_binding_manifest.json", "source_v61v/v61v_remote_page_tensor_binding_manifest.json"),
    (v61v_dir / "sha256_manifest.csv", "source_v61v/sha256_manifest.csv"),
    (results / "v61an_checkpoint_full_page_hash_execution_gate_summary.csv", "source_v61an/v61an_checkpoint_full_page_hash_execution_gate_summary.csv"),
    (results / "v61an_checkpoint_full_page_hash_execution_gate_decision.csv", "source_v61an/v61an_checkpoint_full_page_hash_execution_gate_decision.csv"),
    (v61an_dir / "checkpoint_full_page_hash_execution_requirement_rows.csv", "source_v61an/checkpoint_full_page_hash_execution_requirement_rows.csv"),
    (v61an_dir / "checkpoint_full_page_hash_execution_metric_rows.csv", "source_v61an/checkpoint_full_page_hash_execution_metric_rows.csv"),
    (v61an_dir / "v61an_checkpoint_full_page_hash_execution_gate_manifest.json", "source_v61an/v61an_checkpoint_full_page_hash_execution_gate_manifest.json"),
    (v61an_dir / "sha256_manifest.csv", "source_v61an/sha256_manifest.csv"),
]:
    copy(src, rel)

span_rows = read_csv(v61q_dir / "checkpoint_tensor_page_span_rows.csv")
segment_rows = read_csv(v61q_dir / "checkpoint_page_segment_rows.csv")
page_rows = read_csv(v61q_dir / "checkpoint_unique_page_rows.csv")
shard_rows = read_csv(v61q_dir / "checkpoint_shard_page_summary_rows.csv")
remote_binding_rows = read_csv(v61v_dir / "remote_sample_tensor_binding_rows.csv")
remote_sample_rows = read_csv(v61v_dir / "source_v61u/remote_page_hash_sample_rows.csv")

if len(span_rows) != int(v61q_summary["checkpoint_tensor_rows"]):
    raise SystemExit("v61ao tensor span rows differ from v61q summary")
if len(segment_rows) != int(v61q_summary["checkpoint_page_segment_rows"]):
    raise SystemExit("v61ao segment rows differ from v61q summary")
if len(page_rows) != int(v61q_summary["checkpoint_unique_page_rows"]):
    raise SystemExit("v61ao page rows differ from v61q summary")
if len(shard_rows) != int(v61q_summary["checkpoint_shard_rows"]):
    raise SystemExit("v61ao shard rows differ from v61q summary")

role_span_count = Counter()
role_segment_count = Counter()
role_payload_bytes = Counter()
role_pages = defaultdict(set)
role_layers = defaultdict(set)
role_experts = defaultdict(set)
matrix = defaultdict(lambda: {"segment_rows": 0, "unique_pages": set(), "payload_bytes": 0})
all_layers = set()
all_experts = set()
moe_matrix_keys = set()

for row in span_rows:
    role = tensor_role(row["tensor_name"])
    role_span_count[role] += 1

for row in segment_rows:
    role = tensor_role(row["tensor_name"])
    layer, expert = layer_expert(row["tensor_name"])
    payload = int(row["tensor_segment_bytes"])
    role_segment_count[role] += 1
    role_payload_bytes[role] += payload
    role_pages[role].add(row["page_id"])
    if layer:
        role_layers[role].add(layer)
        all_layers.add(layer)
    if expert:
        role_experts[role].add(expert)
        all_experts.add(expert)
    if role in expected_moe_tensor_roles:
        key = (layer, expert, role)
        matrix[key]["segment_rows"] += 1
        matrix[key]["unique_pages"].add(row["page_id"])
        matrix[key]["payload_bytes"] += payload
        moe_matrix_keys.add(key)

remote_role_count = Counter(row["tensor_role"] for row in remote_binding_rows)
remote_hash_bound_count = Counter(row["tensor_role"] for row in remote_binding_rows if row["remote_hash_bound"] == "1")
role_names = sorted(set(role_span_count) | set(role_segment_count) | set(remote_role_count))
role_rows = []
for role in role_names:
    role_rows.append(
        {
            "tensor_role": role,
            "checkpoint_tensor_rows": str(role_span_count[role]),
            "checkpoint_page_segment_rows": str(role_segment_count[role]),
            "checkpoint_unique_pages_touched": str(len(role_pages[role])),
            "tensor_payload_bytes": str(role_payload_bytes[role]),
            "unique_layer_indices": str(len(role_layers[role])),
            "unique_expert_indices": str(len(role_experts[role])),
            "remote_hashed_binding_rows": str(remote_role_count[role]),
            "remote_hash_bound_rows": str(remote_hash_bound_count[role]),
            "role_manifest_coverage_ready": str(int(role_segment_count[role] > 0 or role_span_count[role] > 0)),
            "weight_bytes_included": "0",
        }
    )
write_csv(run_dir / "checkpoint_tensor_role_coverage_rows.csv", list(role_rows[0].keys()), role_rows)

matrix_rows = []
for layer in range(expected_layers):
    for expert in range(expected_experts):
        for role in expected_moe_tensor_roles:
            key = (str(layer), str(expert), role)
            entry = matrix[key]
            matrix_rows.append(
                {
                    "layer_index": str(layer),
                    "expert_index": str(expert),
                    "tensor_role": role,
                    "checkpoint_page_segment_rows": str(entry["segment_rows"]),
                    "checkpoint_unique_pages_touched": str(len(entry["unique_pages"])),
                    "tensor_payload_bytes": str(entry["payload_bytes"]),
                    "moe_matrix_cell_ready": str(int(entry["segment_rows"] > 0 and len(entry["unique_pages"]) > 0)),
                    "weight_bytes_included": "0",
                }
            )
write_csv(run_dir / "moe_layer_expert_tensor_coverage_rows.csv", list(matrix_rows[0].keys()), matrix_rows)

remote_samples_by_shard = Counter(row["shard_name"] for row in remote_sample_rows)
remote_bindings_by_shard = Counter(row["shard_name"] for row in remote_binding_rows)
shard_audit_rows = []
for row in shard_rows:
    shard_audit_rows.append(
        {
            "model_id": model_id,
            "shard_name": row["shard_name"],
            "content_length": row["content_length"],
            "checkpoint_page_rows": row["checkpoint_page_rows"],
            "tensor_rows": row["tensor_rows"],
            "mapped_tensor_payload_bytes": row["mapped_tensor_payload_bytes"],
            "header_and_metadata_bytes": row["header_and_metadata_bytes"],
            "payload_coverage_ready": row["payload_coverage_ready"],
            "remote_hash_sample_rows": str(remote_samples_by_shard[row["shard_name"]]),
            "remote_tensor_binding_rows": str(remote_bindings_by_shard[row["shard_name"]]),
            "weight_bytes_included": row["weight_bytes_included"],
        }
    )
write_csv(run_dir / "checkpoint_manifest_shard_audit_rows.csv", list(shard_audit_rows[0].keys()), shard_audit_rows)

page_payload_bytes = sum(int(row["payload_bytes_mapped"]) for row in page_rows)
page_total_bytes = sum(int(row["page_bytes_in_shard"]) for row in page_rows)
header_padding_bytes = sum(int(row["header_or_padding_bytes"]) for row in page_rows)
payload_pages = sum(1 for row in page_rows if int(row["payload_bytes_mapped"]) > 0)
partial_payload_pages = sum(1 for row in page_rows if 0 < int(row["payload_bytes_mapped"]) < int(row["page_bytes_in_shard"]))
full_payload_pages = sum(1 for row in page_rows if int(row["payload_bytes_mapped"]) == int(row["page_bytes_in_shard"]))
moe_matrix_ready_rows = sum(1 for row in matrix_rows if row["moe_matrix_cell_ready"] == "1")
expected_moe_matrix_rows = expected_layers * expected_experts * len(expected_moe_tensor_roles)
remote_hash_bound_rows = sum(1 for row in remote_binding_rows if row["remote_hash_bound"] == "1")
remote_hash_bound_moe_rows = sum(1 for row in remote_binding_rows if row["remote_hash_bound"] == "1" and row["tensor_role"].startswith("moe_"))

coverage_ready = int(
    len(shard_rows) == 59
    and len(span_rows) == 1739
    and len(page_rows) == int(v61q_summary["checkpoint_unique_page_rows"])
    and len(segment_rows) == int(v61q_summary["checkpoint_page_segment_rows"])
    and page_payload_bytes == int(v61q_summary["mapped_tensor_payload_bytes"])
    and page_total_bytes == int(v61q_summary["total_checkpoint_bytes_required"])
    and header_padding_bytes == int(v61q_summary["header_and_metadata_bytes"])
    and len(all_layers) == expected_layers
    and len(all_experts) == expected_experts
    and moe_matrix_ready_rows == expected_moe_matrix_rows
)

requirement_rows = [
    {
        "requirement_id": "real-checkpoint-page-map-input",
        "status": "pass",
        "required_rows": v61q_summary["checkpoint_unique_page_rows"],
        "actual_rows": str(len(page_rows)),
        "reason": "v61q safetensors-header-derived page map is bound",
    },
    {
        "requirement_id": "complete-moe-layer-expert-tensor-coverage",
        "status": "pass" if moe_matrix_ready_rows == expected_moe_matrix_rows else "blocked",
        "required_rows": str(expected_moe_matrix_rows),
        "actual_rows": str(moe_matrix_ready_rows),
        "reason": "every layer/expert/w1-w2-w3 MoE tensor cell must have checkpoint page segments",
    },
    {
        "requirement_id": "remote-hashed-sample-binding",
        "status": "pass" if remote_hash_bound_rows == len(remote_binding_rows) and len(remote_binding_rows) > 0 else "blocked",
        "required_rows": str(len(remote_binding_rows)),
        "actual_rows": str(remote_hash_bound_rows),
        "reason": "v61v remote-hashed sample pages must stay tensor-bound",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_rows": "0",
        "actual_rows": "0",
        "reason": "v61ao copies metadata and hashes only and never writes checkpoint payload bytes",
    },
    {
        "requirement_id": "full-safetensors-page-hash-binding",
        "status": "pass" if v61an_summary["full_safetensors_page_hash_binding_ready"] == "1" else "blocked",
        "required_rows": v61an_summary["required_page_hash_rows"],
        "actual_rows": v61an_summary["local_full_page_hash_verified_rows"],
        "reason": "full local page-hash coverage remains gated by v61an",
    },
    {
        "requirement_id": "real-model-generation",
        "status": "blocked",
        "required_rows": "1",
        "actual_rows": "0",
        "reason": "coverage audit is not real Mixtral generation",
    },
]
write_csv(run_dir / "real_model_page_manifest_coverage_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ao_real_model_page_manifest_coverage_audit_metrics",
    "model_id": model_id,
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "v61v_remote_page_tensor_binding_ready": v61v_summary["v61v_remote_page_tensor_binding_ready"],
    "v61an_checkpoint_full_page_hash_execution_gate_ready": v61an_summary["v61an_checkpoint_full_page_hash_execution_gate_ready"],
    "checkpoint_shard_rows": str(len(shard_rows)),
    "checkpoint_tensor_rows": str(len(span_rows)),
    "checkpoint_unique_page_rows": str(len(page_rows)),
    "checkpoint_page_segment_rows": str(len(segment_rows)),
    "checkpoint_payload_pages": str(payload_pages),
    "checkpoint_full_payload_pages": str(full_payload_pages),
    "checkpoint_partial_payload_pages": str(partial_payload_pages),
    "mapped_tensor_payload_bytes": str(page_payload_bytes),
    "total_checkpoint_bytes_required": str(page_total_bytes),
    "header_and_metadata_bytes": str(header_padding_bytes),
    "tensor_role_coverage_rows": str(len(role_rows)),
    "moe_layer_expert_tensor_coverage_rows": str(len(matrix_rows)),
    "moe_layer_expert_tensor_coverage_ready_rows": str(moe_matrix_ready_rows),
    "covered_moe_layer_indices": str(len(all_layers)),
    "covered_moe_expert_indices": str(len(all_experts)),
    "covered_moe_tensor_roles": str(len(expected_moe_tensor_roles)),
    "remote_page_hash_sample_rows": str(len(remote_sample_rows)),
    "remote_hash_bound_tensor_rows": str(remote_hash_bound_rows),
    "remote_hash_bound_moe_rows": str(remote_hash_bound_moe_rows),
    "real_model_page_manifest_coverage_ready": str(coverage_ready),
    "required_page_hash_rows": v61an_summary["required_page_hash_rows"],
    "local_full_page_hash_verified_rows": v61an_summary["local_full_page_hash_verified_rows"],
    "full_safetensors_page_hash_binding_ready": v61an_summary["full_safetensors_page_hash_binding_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61ao": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "real_model_page_manifest_coverage_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ao_real_model_page_manifest_coverage_audit_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61q-real-checkpoint-page-map-input", "status": "pass", "reason": "v61q checkpoint page map is bound"},
    {"gate": "v61v-remote-page-tensor-binding-input", "status": "pass", "reason": "v61v remote hashed tensor bindings are bound"},
    {"gate": "v61an-full-page-hash-execution-gate-input", "status": "pass", "reason": "v61an full page-hash execution gate is bound"},
    {"gate": "real-model-page-manifest-coverage", "status": "pass" if coverage_ready else "blocked", "reason": f"moe_matrix_ready_rows={moe_matrix_ready_rows}/{expected_moe_matrix_rows}; page_rows={len(page_rows)}"},
    {"gate": "remote-hashed-sample-binding", "status": "pass" if remote_hash_bound_rows == len(remote_binding_rows) else "blocked", "reason": f"remote_hash_bound_tensor_rows={remote_hash_bound_rows}/{len(remote_binding_rows)}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "metadata/hash audit only; zero checkpoint payload bytes"},
    {"gate": "full-safetensors-page-hash-binding", "status": "pass" if v61an_summary["full_safetensors_page_hash_binding_ready"] == "1" else "blocked", "reason": f"local_full_page_hash_verified_rows={v61an_summary['local_full_page_hash_verified_rows']}/{v61an_summary['required_page_hash_rows']}"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real Mixtral generation waits for local materialization and full page-hash coverage"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "manifest coverage audit is not a quality benchmark"},
    {"gate": "production-latency", "status": "blocked", "reason": "not an end-to-end decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ao Real Model Page Manifest Coverage Audit Boundary

This artifact audits the real Mixtral checkpoint page manifest as a complete
metadata coverage object. It binds v61q safetensors-header page rows, v61v
remote-hashed tensor/runtime samples, and v61an full page-hash execution gating.
It does not download or persist checkpoint payload bytes.

Evidence emitted:

- checkpoint_shard_rows={len(shard_rows)}
- checkpoint_tensor_rows={len(span_rows)}
- checkpoint_unique_page_rows={len(page_rows)}
- checkpoint_page_segment_rows={len(segment_rows)}
- mapped_tensor_payload_bytes={page_payload_bytes}
- total_checkpoint_bytes_required={page_total_bytes}
- tensor_role_coverage_rows={len(role_rows)}
- moe_layer_expert_tensor_coverage_rows={len(matrix_rows)}
- moe_layer_expert_tensor_coverage_ready_rows={moe_matrix_ready_rows}
- covered_moe_layer_indices={len(all_layers)}
- covered_moe_expert_indices={len(all_experts)}
- remote_page_hash_sample_rows={len(remote_sample_rows)}
- remote_hash_bound_tensor_rows={remote_hash_bound_rows}
- remote_hash_bound_moe_rows={remote_hash_bound_moe_rows}
- real_model_page_manifest_coverage_ready={coverage_ready}
- required_page_hash_rows={v61an_summary["required_page_hash_rows"]}
- local_full_page_hash_verified_rows={v61an_summary["local_full_page_hash_verified_rows"]}
- full_safetensors_page_hash_binding_ready={v61an_summary["full_safetensors_page_hash_binding_ready"]}
- checkpoint_payload_bytes_downloaded_by_v61ao=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: real checkpoint page manifest coverage, complete MoE
layer/expert/tensor metadata coverage, and remote-hashed sampled tensor binding.
Blocked wording: completed full safetensors page-hash coverage, local
checkpoint materialization, real Mixtral generation, near-frontier quality,
production latency, or release readiness.
"""
(run_dir / "V61AO_REAL_MODEL_PAGE_MANIFEST_COVERAGE_AUDIT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ao_real_model_page_manifest_coverage_audit",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ao_real_model_page_manifest_coverage_audit_ready": 1,
    "v61q_summary_sha256": sha256(results / "v61q_real_checkpoint_page_map_summary.csv"),
    "v61v_summary_sha256": sha256(results / "v61v_remote_page_tensor_binding_summary.csv"),
    "v61an_summary_sha256": sha256(results / "v61an_checkpoint_full_page_hash_execution_gate_summary.csv"),
    "checkpoint_shard_rows": len(shard_rows),
    "checkpoint_tensor_rows": len(span_rows),
    "checkpoint_unique_page_rows": len(page_rows),
    "checkpoint_page_segment_rows": len(segment_rows),
    "moe_layer_expert_tensor_coverage_rows": len(matrix_rows),
    "moe_layer_expert_tensor_coverage_ready_rows": moe_matrix_ready_rows,
    "remote_hash_bound_tensor_rows": remote_hash_bound_rows,
    "real_model_page_manifest_coverage_ready": coverage_ready,
    "full_safetensors_page_hash_binding_ready": int(v61an_summary["full_safetensors_page_hash_binding_ready"]),
    "checkpoint_payload_bytes_downloaded_by_v61ao": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61ao_real_model_page_manifest_coverage_audit_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ao_real_model_page_manifest_coverage_audit_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
