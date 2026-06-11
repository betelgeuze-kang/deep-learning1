#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61k_real_model_page_manifest"
RUN_ID="${V61K_RUN_ID:-manifest_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61K_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61k_real_model_page_manifest_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61j_one_command_ssd_resident_demo_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61j_one_command_ssd_resident_demo.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

model_id = "mistralai/Mixtral-8x22B-v0.1"
model_url = "https://huggingface.co/mistralai/Mixtral-8x22B-v0.1"
config_url = model_url + "/raw/main/config.json"
readme_url = model_url + "/raw/main/README.md"

# Snapshot of the public config fields used for the page manifest. The runner
# optionally refreshes these small metadata files, but never downloads weights.
embedded_config = {
    "architectures": ["MixtralForCausalLM"],
    "hidden_size": 6144,
    "intermediate_size": 16384,
    "max_position_embeddings": 65536,
    "model_type": "mixtral",
    "num_attention_heads": 48,
    "num_experts_per_tok": 2,
    "num_hidden_layers": 56,
    "num_key_value_heads": 8,
    "num_local_experts": 8,
    "torch_dtype": "bfloat16",
    "vocab_size": 32000,
}
license_id = "apache-2.0"
published_total_parameter_label = "8x22B"
published_total_parameters_estimate = 176_000_000_000
checkpoint_shard_count = 59
page_size_bytes = int(os.environ.get("V61K_PAGE_SIZE_BYTES", str(2 * 1024 * 1024)))
ssd_read_budget = int(os.environ.get("V61K_SSD_READ_BUDGET_BYTES_PER_TOKEN", str(16 * 1024 * 1024)))
live_check_enabled = os.environ.get("V61K_LIVE_SOURCE_CHECK", "1") != "0"


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


def copy_if_exists(src, rel):
    if src.is_file():
        dst = run_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def fetch_text(url, timeout=8):
    request = urllib.request.Request(url, headers={"User-Agent": "v61k-page-manifest/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


live_source_verified = 0
live_source_error = ""
config = dict(embedded_config)
readme_license_seen = 0
if live_check_enabled:
    try:
        live_config = json.loads(fetch_text(config_url))
        expected_keys = [
            "hidden_size",
            "intermediate_size",
            "num_experts_per_tok",
            "num_hidden_layers",
            "num_local_experts",
            "torch_dtype",
            "vocab_size",
        ]
        for key in expected_keys:
            if live_config.get(key) != embedded_config[key]:
                raise RuntimeError(f"config mismatch for {key}: {live_config.get(key)} != {embedded_config[key]}")
        config = live_config
        (run_dir / "source_config_snapshot.json").write_text(json.dumps(live_config, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        readme_text = fetch_text(readme_url)
        readme_license_seen = int("license: apache-2.0" in readme_text.lower())
        (run_dir / "source_readme_license_probe.txt").write_text(
            "source_url=" + readme_url + "\nlicense_seen=" + str(readme_license_seen) + "\n",
            encoding="utf-8",
        )
        live_source_verified = int(readme_license_seen == 1)
    except Exception as exc:  # Keep offline testability; record the weaker evidence.
        live_source_error = str(exc)
        (run_dir / "source_config_snapshot.json").write_text(json.dumps(embedded_config, indent=2, sort_keys=True) + "\n", encoding="utf-8")
else:
    (run_dir / "source_config_snapshot.json").write_text(json.dumps(embedded_config, indent=2, sort_keys=True) + "\n", encoding="utf-8")

copy_if_exists(results / "v61j_one_command_ssd_resident_demo_summary.csv", "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv")

num_layers = int(config["num_hidden_layers"])
num_experts = int(config["num_local_experts"])
top_k = int(config["num_experts_per_tok"])
hidden_size = int(config["hidden_size"])
intermediate_size = int(config["intermediate_size"])
bytes_per_param_bf16 = 2
tensor_names = ["w1", "w2", "w3"]
params_per_tensor = hidden_size * intermediate_size
bf16_bytes_per_tensor = params_per_tensor * bytes_per_param_bf16
if bf16_bytes_per_tensor % page_size_bytes != 0:
    raise SystemExit("v61k expects exact 2 MiB page division for the Mixtral expert tensors")
pages_per_tensor = bf16_bytes_per_tensor // page_size_bytes
params_per_page = page_size_bytes // bytes_per_param_bf16
total_expert_pages = num_layers * num_experts * len(tensor_names) * pages_per_tensor
total_expert_bf16_bytes = total_expert_pages * page_size_bytes
active_uncached_bf16_pages_per_token = num_layers * top_k * len(tensor_names) * pages_per_tensor
active_uncached_bf16_bytes_per_token = active_uncached_bf16_pages_per_token * page_size_bytes
active_uncached_q4_bytes_per_token = active_uncached_bf16_bytes_per_token // 4

model_rows = [
    {
        "model_id": model_id,
        "model_family": "mixtral",
        "architecture": "MixtralForCausalLM",
        "published_total_parameter_label": published_total_parameter_label,
        "published_total_parameters_estimate": str(published_total_parameters_estimate),
        "total_parameters_100b_plus": "1",
        "license": license_id,
        "source_url": model_url,
        "config_url": config_url,
        "real_open_weight_moe": "1",
        "real_checkpoint_weight_bytes_materialized": "0",
    }
]
source_rows = [
    {
        "source_name": "huggingface_model_repository",
        "source_url": model_url,
        "source_kind": "model-card-and-file-list",
        "live_source_verified": str(live_source_verified),
        "live_source_error": live_source_error,
    },
    {
        "source_name": "huggingface_config_json",
        "source_url": config_url,
        "source_kind": "config-json",
        "live_source_verified": str(live_source_verified),
        "live_source_error": live_source_error,
    },
    {
        "source_name": "huggingface_readme_license",
        "source_url": readme_url,
        "source_kind": "license-probe",
        "live_source_verified": str(readme_license_seen),
        "live_source_error": live_source_error,
    },
]
config_rows = [
    {
        "model_id": model_id,
        "hidden_size": str(hidden_size),
        "intermediate_size": str(intermediate_size),
        "num_hidden_layers": str(num_layers),
        "num_local_experts": str(num_experts),
        "num_experts_per_tok": str(top_k),
        "num_attention_heads": str(config["num_attention_heads"]),
        "num_key_value_heads": str(config["num_key_value_heads"]),
        "max_position_embeddings": str(config["max_position_embeddings"]),
        "torch_dtype": str(config["torch_dtype"]),
        "vocab_size": str(config["vocab_size"]),
    }
]
license_rows = [
    {
        "model_id": model_id,
        "license": license_id,
        "page_manifest_redistributable": "1",
        "weights_redistributed": "0",
        "redistribution_boundary": "manifest-only-no-weight-bytes",
        "license_source_url": readme_url,
    }
]
shard_rows = [
    {
        "model_id": model_id,
        "shard_index": str(index),
        "shard_name": f"model-{index:05d}-of-{checkpoint_shard_count:05d}.safetensors",
        "source_repo": model_url,
        "expected_format": "safetensors",
        "weight_bytes_materialized": "0",
        "shard_hash_verified": "0",
        "redistributable_manifest_only": "1",
    }
    for index in range(1, checkpoint_shard_count + 1)
]

write_csv(run_dir / "real_model_identity_rows.csv", list(model_rows[0].keys()), model_rows)
write_csv(run_dir / "real_model_source_rows.csv", list(source_rows[0].keys()), source_rows)
write_csv(run_dir / "real_model_config_rows.csv", list(config_rows[0].keys()), config_rows)
write_csv(run_dir / "license_redistribution_rows.csv", list(license_rows[0].keys()), license_rows)
write_csv(run_dir / "checkpoint_shard_manifest_rows.csv", list(shard_rows[0].keys()), shard_rows)

page_fieldnames = [
    "page_id",
    "model_id",
    "layer_id",
    "expert_id",
    "tensor_name",
    "page_index_in_tensor",
    "page_size_bytes",
    "parameter_offset",
    "parameter_count",
    "bf16_bytes",
    "quant_profile_hint",
    "source_tensor_pattern",
    "weight_bytes_included",
    "page_hash_verified",
]
with (run_dir / "tensor_page_manifest_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=page_fieldnames, lineterminator="\n")
    writer.writeheader()
    for layer in range(num_layers):
        for expert in range(num_experts):
            for tensor_name in tensor_names:
                for page_index in range(pages_per_tensor):
                    writer.writerow(
                        {
                            "page_id": f"mixtral8x22b_l{layer:02d}_e{expert:02d}_{tensor_name}_p{page_index:03d}",
                            "model_id": model_id,
                            "layer_id": str(layer),
                            "expert_id": str(expert),
                            "tensor_name": tensor_name,
                            "page_index_in_tensor": str(page_index),
                            "page_size_bytes": str(page_size_bytes),
                            "parameter_offset": str(page_index * params_per_page),
                            "parameter_count": str(params_per_page),
                            "bf16_bytes": str(page_size_bytes),
                            "quant_profile_hint": "q4-or-q5-after-real-quality-gate",
                            "source_tensor_pattern": f"model.layers.{layer}.block_sparse_moe.experts.{expert}.{tensor_name}.weight",
                            "weight_bytes_included": "0",
                            "page_hash_verified": "0",
                        }
                    )

budget_rows = [
    {
        "budget_scope": "full_expert_manifest_bf16",
        "pages": str(total_expert_pages),
        "bytes": str(total_expert_bf16_bytes),
        "budget_bytes": "",
        "budget_pass": "",
        "implication": "manifest maps real MoE expert tensor pages without redistributing weights",
    },
    {
        "budget_scope": "uncached_top2_active_bf16_per_token",
        "pages": str(active_uncached_bf16_pages_per_token),
        "bytes": str(active_uncached_bf16_bytes_per_token),
        "budget_bytes": str(ssd_read_budget),
        "budget_pass": "0",
        "implication": "uncached active expert streaming is too large for the current SSD bytes/token budget",
    },
    {
        "budget_scope": "uncached_top2_active_q4_per_token",
        "pages": str(active_uncached_bf16_pages_per_token // 4),
        "bytes": str(active_uncached_q4_bytes_per_token),
        "budget_bytes": str(ssd_read_budget),
        "budget_pass": "0",
        "implication": "quantization alone is insufficient without persistent hot cache and reuse",
    },
]
runtime_gap_rows = [
    ("real-weight-materialization", "blocked", "weights are not downloaded or redistributed by v61k"),
    ("safetensors-header-validation", "blocked", "checkpoint shard headers are not locally inspected yet"),
    ("page-hash-binding", "blocked", "page hashes require local checkpoint shards"),
    ("active-uncached-ssd-budget", "blocked", "uncached top-2 active path exceeds current SSD bytes/token budget"),
    ("gpu-page-dequant-matmul", "blocked", "ROCm/GPU page kernel measurement remains v61 next work"),
    ("kv-cache-residency-policy", "blocked", "long-context KV residency and eviction policy is not implemented here"),
    ("source-bound-qa-workload", "blocked", "v61j has not yet answered complete-source QA through this real model manifest"),
    ("near-frontier-quality", "blocked", "no near-frontier quality claim is opened"),
    ("release-package", "blocked", "not a release package"),
]
runtime_rows = [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in runtime_gap_rows]
write_csv(run_dir / "expert_page_budget_rows.csv", list(budget_rows[0].keys()), budget_rows)
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_rows[0].keys()), runtime_rows)

summary = {
    "v61k_real_model_page_manifest_ready": "1",
    "real_model_page_manifest_ready": "1",
    "model_id": model_id,
    "source_model_license": license_id,
    "published_total_parameter_label": published_total_parameter_label,
    "published_total_parameters_estimate": str(published_total_parameters_estimate),
    "total_parameters_100b_plus": "1",
    "num_hidden_layers": str(num_layers),
    "num_local_experts": str(num_experts),
    "num_experts_per_tok": str(top_k),
    "checkpoint_shard_manifest_rows": str(len(shard_rows)),
    "tensor_page_manifest_rows": str(total_expert_pages),
    "page_size_bytes": str(page_size_bytes),
    "manifest_bf16_expert_bytes_total": str(total_expert_bf16_bytes),
    "active_uncached_q4_bytes_per_token_estimate": str(active_uncached_q4_bytes_per_token),
    "ssd_read_budget_bytes_per_token": str(ssd_read_budget),
    "active_uncached_q4_budget_pass": "0",
    "legally_redistributable_page_manifest_ready": "1",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "live_source_verified": str(live_source_verified),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v61k-real-model-page-manifest",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "license": license_id,
    "v61k_real_model_page_manifest_ready": 1,
    "tensor_page_manifest_rows": total_expert_pages,
    "legally_redistributable_page_manifest_ready": 1,
    "real_checkpoint_weight_bytes_materialized": 0,
    "active_uncached_q4_budget_pass": 0,
    "near_frontier_claim_ready": 0,
    "route_jump_rows": 0,
}
(run_dir / "v61k_real_model_page_manifest_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / "V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md").write_text(
    "# v61k Real-Model Page Manifest Boundary\n\n"
    "This artifact moves v61 beyond the logical 128B fixture by binding the page manifest to a real public MoE model identity and config. It redistributes only metadata/page rows, not checkpoint weight bytes.\n\n"
    f"- model_id={model_id}\n"
    f"- license={license_id}\n"
    f"- published_total_parameter_label={published_total_parameter_label}\n"
    f"- tensor_page_manifest_rows={total_expert_pages}\n"
    f"- active_uncached_q4_bytes_per_token_estimate={active_uncached_q4_bytes_per_token}\n"
    f"- ssd_read_budget_bytes_per_token={ssd_read_budget}\n"
    "- active_uncached_q4_budget_pass=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n",
    encoding="utf-8",
)

decision_rows = [
    ("real-open-weight-moe-identity", "pass", "model id, license, config, and source URLs are recorded"),
    ("legally-redistributable-page-manifest", "pass", "page manifest contains metadata only and no checkpoint weights"),
    ("tensor-page-enumeration", "pass", f"expert tensor page rows={total_expert_pages}"),
    ("100b-plus-direction", "pass", "Mixtral 8x22B label-derived estimate exceeds 100B total parameters"),
    ("real-checkpoint-weight-materialization", "blocked", "v61k does not download or redistribute checkpoint shards"),
    ("uncached-runtime-budget", "blocked", "uncached active expert stream exceeds SSD bytes/token budget"),
    ("gpu-kernel-measurement", "blocked", "ROCm page-dequant-matmul measurement remains next work"),
    ("kv-cache-policy", "blocked", "KV residency/eviction policy remains next work"),
    ("source-bound-qa", "blocked", "v61j has not yet run complete-source QA through this real model manifest"),
    ("near-frontier-quality", "blocked", "no quality claim is opened"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "real_model_identity_rows.csv",
    "real_model_source_rows.csv",
    "real_model_config_rows.csv",
    "license_redistribution_rows.csv",
    "checkpoint_shard_manifest_rows.csv",
    "tensor_page_manifest_rows.csv",
    "expert_page_budget_rows.csv",
    "runtime_gap_rows.csv",
    "source_config_snapshot.json",
    "v61k_real_model_page_manifest_manifest.json",
    "V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
]
if (run_dir / "source_readme_license_probe.txt").is_file():
    artifact_rels.append("source_readme_license_probe.txt")
sha_rows = [{"path": rel, "sha256": sha256(run_dir / rel), "bytes": (run_dir / rel).stat().st_size} for rel in artifact_rels]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v61k_real_model_page_manifest_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
