#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61o_checkpoint_shard_header_probe"
RUN_ID="${V61O_RUN_ID:-probe_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61O_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61o_checkpoint_shard_header_probe_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61k_real_model_page_manifest_summary.csv" \
  || ! -s "$RESULTS_DIR/v61k_real_model_page_manifest/manifest_001/checkpoint_shard_manifest_rows.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61k_real_model_page_manifest.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import struct
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61k_dir = results / "v61k_real_model_page_manifest" / "manifest_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"
model_url = "https://huggingface.co/mistralai/Mixtral-8x22B-v0.1"
resolve_base = model_url + "/resolve/main"
index_name = "model.safetensors.index.json"
index_url = f"{resolve_base}/{index_name}"
page_size_bytes = int(os.environ.get("V61O_PAGE_SIZE_BYTES", str(2 * 1024 * 1024)))
sample_page_probe_shards = int(os.environ.get("V61O_SAMPLE_PAGE_PROBE_SHARDS", "3"))


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


def request(url, method="GET", headers=None, timeout=60):
    base_headers = {"User-Agent": "v61o-checkpoint-shard-header-probe/1.0"}
    if headers:
        base_headers.update(headers)
    req = urllib.request.Request(url, method=method, headers=base_headers)
    return urllib.request.urlopen(req, timeout=timeout)


def fetch_bytes(url, byte_start=None, byte_end=None, timeout=60):
    headers = {}
    if byte_start is not None and byte_end is not None:
        headers["Range"] = f"bytes={byte_start}-{byte_end}"
    with request(url, headers=headers, timeout=timeout) as response:
        data = response.read()
        return data, response


def head(url, timeout=60):
    with request(url, method="HEAD", timeout=timeout) as response:
        return {
            "status": str(response.status),
            "final_url": response.geturl(),
            "content_length": response.headers.get("Content-Length", ""),
            "etag": (response.headers.get("ETag") or "").strip('"'),
            "accept_ranges": response.headers.get("Accept-Ranges", ""),
            "content_type": response.headers.get("Content-Type", ""),
        }


v61k_summary = read_csv(results / "v61k_real_model_page_manifest_summary.csv")[0]
if v61k_summary.get("v61k_real_model_page_manifest_ready") != "1":
    raise SystemExit("v61o requires v61k_real_model_page_manifest_ready=1")

for rel in [
    "real_model_identity_rows.csv",
    "real_model_config_rows.csv",
    "checkpoint_shard_manifest_rows.csv",
    "tensor_page_manifest_rows.csv",
    "V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    "v61k_real_model_page_manifest_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61k_dir / rel, f"source_v61k/{rel}")
copy(results / "v61k_real_model_page_manifest_summary.csv", "source_v61k/v61k_real_model_page_manifest_summary.csv")

index_bytes, index_response = fetch_bytes(index_url, timeout=60)
index_json = json.loads(index_bytes.decode("utf-8"))
(run_dir / index_name).write_bytes(index_bytes)
weight_map = index_json.get("weight_map", {})
metadata = index_json.get("metadata", {})
shard_names = sorted(set(weight_map.values()))
if len(shard_names) != int(v61k_summary["checkpoint_shard_manifest_rows"]):
    raise SystemExit(f"v61o shard count mismatch: {len(shard_names)}")

index_rows = [
    {
        "model_id": model_id,
        "index_name": index_name,
        "index_url": index_url,
        "index_status": str(index_response.status),
        "index_etag": (index_response.headers.get("ETag") or "").strip('"'),
        "index_content_length": str(len(index_bytes)),
        "index_sha256": sha256_bytes(index_bytes),
        "metadata_total_size": str(metadata.get("total_size", "")),
        "weight_map_tensor_rows": str(len(weight_map)),
        "checkpoint_shard_rows": str(len(shard_names)),
        "index_weight_bytes_included": "0",
        "index_ready": "1",
    }
]
write_csv(run_dir / "checkpoint_index_rows.csv", list(index_rows[0].keys()), index_rows)

shard_manifest_rows = read_csv(v61k_dir / "checkpoint_shard_manifest_rows.csv")
expected_shard_names = {row["shard_name"] for row in shard_manifest_rows}
if expected_shard_names != set(shard_names):
    raise SystemExit("v61o index shards differ from v61k shard manifest")

shard_http_rows = []
header_rows = []
tensor_rows = []
page_probe_rows = []
sampled_shards = set(shard_names[:sample_page_probe_shards])
sampled_payload_bytes_read = 0
header_total_bytes = 0

for shard_name in shard_names:
    shard_url = f"{resolve_base}/{shard_name}"
    head_info = head(shard_url)
    size = int(head_info["content_length"])
    final_host = urlparse(head_info["final_url"]).netloc
    shard_http_rows.append(
        {
            "model_id": model_id,
            "shard_name": shard_name,
            "source_url": shard_url,
            "head_status": head_info["status"],
            "content_length": str(size),
            "etag": head_info["etag"],
            "accept_ranges": head_info["accept_ranges"],
            "content_type": head_info["content_type"],
            "redirect_final_host": final_host,
            "http_identity_ready": "1",
            "weight_bytes_persisted": "0",
        }
    )

    header_len_bytes, header_len_response = fetch_bytes(shard_url, 0, 7)
    if len(header_len_bytes) != 8:
        raise SystemExit(f"v61o failed to read header length for {shard_name}")
    header_len = struct.unpack("<Q", header_len_bytes)[0]
    header_json_bytes, header_response = fetch_bytes(shard_url, 8, 8 + header_len - 1)
    if len(header_json_bytes) != header_len:
        raise SystemExit(f"v61o failed to read full safetensors header for {shard_name}")
    header_json = json.loads(header_json_bytes.decode("utf-8"))
    metadata_keys = sorted((header_json.get("__metadata__") or {}).keys())
    tensor_names = [name for name in header_json if name != "__metadata__"]
    data_base_offset = 8 + header_len
    header_total_bytes += 8 + header_len
    header_rows.append(
        {
            "model_id": model_id,
            "shard_name": shard_name,
            "header_len": str(header_len),
            "header_probe_bytes_read": str(8 + header_len),
            "header_len_status": str(header_len_response.status),
            "header_json_status": str(header_response.status),
            "header_sha256": sha256_bytes(header_len_bytes + header_json_bytes),
            "header_json_sha256": sha256_bytes(header_json_bytes),
            "tensor_count": str(len(tensor_names)),
            "metadata_keys": "|".join(metadata_keys),
            "data_base_offset": str(data_base_offset),
            "safetensors_header_probe_ready": "1",
            "weight_payload_bytes_persisted": "0",
        }
    )
    for tensor_name in tensor_names:
        tensor = header_json[tensor_name]
        offsets = tensor.get("data_offsets", [0, 0])
        tensor_rows.append(
            {
                "model_id": model_id,
                "shard_name": shard_name,
                "tensor_name": tensor_name,
                "dtype": tensor.get("dtype", ""),
                "shape": "x".join(str(x) for x in tensor.get("shape", [])),
                "data_offset_start": str(offsets[0]),
                "data_offset_end": str(offsets[1]),
                "absolute_data_offset_start": str(data_base_offset + int(offsets[0])),
                "absolute_data_offset_end": str(data_base_offset + int(offsets[1])),
                "tensor_payload_bytes": str(int(offsets[1]) - int(offsets[0])),
                "tensor_header_bound": "1",
            }
        )
    if shard_name in sampled_shards:
        page_start = data_base_offset
        page_end = min(size - 1, page_start + page_size_bytes - 1)
        page_bytes, page_response = fetch_bytes(shard_url, page_start, page_end, timeout=120)
        bytes_read = len(page_bytes)
        sampled_payload_bytes_read += bytes_read
        page_probe_rows.append(
            {
                "model_id": model_id,
                "shard_name": shard_name,
                "page_probe_index": "0",
                "page_start_byte": str(page_start),
                "page_end_byte": str(page_end),
                "page_probe_bytes_read": str(bytes_read),
                "page_probe_sha256": sha256_bytes(page_bytes),
                "page_probe_status": str(page_response.status),
                "page_probe_content_range": page_response.headers.get("Content-Range", ""),
                "page_size_bytes": str(page_size_bytes),
                "sampled_page_hash_binding_ready": str(int(bytes_read > 0)),
                "page_payload_bytes_persisted": "0",
            }
        )

write_csv(run_dir / "checkpoint_shard_http_identity_rows.csv", list(shard_http_rows[0].keys()), shard_http_rows)
write_csv(run_dir / "safetensors_header_probe_rows.csv", list(header_rows[0].keys()), header_rows)
write_csv(run_dir / "safetensors_header_tensor_rows.csv", list(tensor_rows[0].keys()), tensor_rows)
write_csv(run_dir / "sampled_page_hash_probe_rows.csv", list(page_probe_rows[0].keys()), page_probe_rows)

gap_rows = [
    ("full-checkpoint-materialization", "blocked", "v61o probes index, HTTP identity, safetensors headers, and sampled page bytes; it does not persist or materialize full checkpoint weights"),
    ("full-safetensors-page-hash-binding", "blocked", "only sampled first-page probes are hashed; full shard page coverage is still missing"),
    ("local-ssd-checkpoint-residency", "blocked", "checkpoint shards are not downloaded into a local SSD warehouse"),
    ("real-model-generation", "blocked", "no real Mixtral checkpoint generation is executed"),
    ("near-frontier-quality", "blocked", "checkpoint metadata/header/page probes are not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end decode latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

summary = {
    "v61o_checkpoint_shard_header_probe_ready": "1",
    "v61k_real_model_page_manifest_ready": v61k_summary["v61k_real_model_page_manifest_ready"],
    "model_id": model_id,
    "source_model_license": v61k_summary["source_model_license"],
    "checkpoint_index_ready": "1",
    "checkpoint_index_weight_map_tensor_rows": str(len(weight_map)),
    "checkpoint_shard_http_identity_rows": str(len(shard_http_rows)),
    "safetensors_header_probe_rows": str(len(header_rows)),
    "safetensors_header_probe_ready_rows": str(sum(1 for row in header_rows if row["safetensors_header_probe_ready"] == "1")),
    "safetensors_header_tensor_rows": str(len(tensor_rows)),
    "sampled_page_hash_probe_rows": str(len(page_probe_rows)),
    "sampled_page_payload_bytes_read": str(sampled_payload_bytes_read),
    "sampled_safetensors_page_hash_binding_ready": str(int(len(page_probe_rows) == len(sampled_shards) and all(int(row["page_probe_bytes_read"]) > 0 for row in page_probe_rows))),
    "full_safetensors_page_hash_binding_ready": "0",
    "safetensors_header_probe_bytes_read": str(header_total_bytes),
    "checkpoint_weight_bytes_persisted": "0",
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
    ("v61k-real-model-page-manifest-input", "pass", "v61k Mixtral page manifest is bound"),
    ("checkpoint-index-intake", "pass", f"weight_map_tensor_rows={len(weight_map)}; shard_rows={len(shard_names)}"),
    ("checkpoint-shard-http-identity", "pass", f"head_rows={len(shard_http_rows)}"),
    ("safetensors-header-probe", "pass", f"header_rows={len(header_rows)}; tensor_rows={len(tensor_rows)}"),
    ("sampled-page-hash-probe", "pass", f"sampled_page_hash_probe_rows={len(page_probe_rows)}"),
    ("full-checkpoint-materialization", "blocked", "full checkpoint shards are not downloaded or persisted"),
    ("full-safetensors-page-hash-binding", "blocked", "sampled page probes are not full page coverage"),
    ("local-ssd-checkpoint-residency", "blocked", "checkpoint shards are not resident in a local SSD warehouse"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61O_CHECKPOINT_SHARD_HEADER_PROBE_BOUNDARY.md").write_text(
    "# v61o Checkpoint Shard Header Probe Boundary\n\n"
    "This layer strengthens the v61 real-model binding by fetching the Hugging Face safetensors index, HEAD metadata for every checkpoint shard, safetensors headers for every shard, and sampled first-page payload hashes. "
    "It does not persist checkpoint payload bytes or download the full model.\n\n"
    f"- checkpoint_shard_http_identity_rows={len(shard_http_rows)}\n"
    f"- safetensors_header_probe_rows={len(header_rows)}\n"
    f"- safetensors_header_tensor_rows={len(tensor_rows)}\n"
    f"- sampled_page_hash_probe_rows={len(page_probe_rows)}\n"
    f"- sampled_page_payload_bytes_read={sampled_payload_bytes_read}\n"
    "- checkpoint_weight_bytes_persisted=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- real_100b_open_weight_materialized=0\n"
    "- full_safetensors_page_hash_binding_ready=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: checkpoint index, shard HTTP identity, safetensors header, and sampled page-hash probe evidence. "
    "Blocked wording: full local checkpoint residency, full page-hash coverage, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61o-checkpoint-shard-header-probe",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61o_checkpoint_shard_header_probe_ready": 1,
    "v61k_summary_sha256": sha256(results / "v61k_real_model_page_manifest_summary.csv"),
    "checkpoint_index_sha256": sha256(run_dir / index_name),
    "checkpoint_shard_http_identity_rows": len(shard_http_rows),
    "safetensors_header_probe_rows": len(header_rows),
    "safetensors_header_tensor_rows": len(tensor_rows),
    "sampled_page_hash_probe_rows": len(page_probe_rows),
    "sampled_page_payload_bytes_read": sampled_payload_bytes_read,
    "checkpoint_weight_bytes_persisted": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61o_checkpoint_shard_header_probe_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    index_name,
    "checkpoint_index_rows.csv",
    "checkpoint_shard_http_identity_rows.csv",
    "safetensors_header_probe_rows.csv",
    "safetensors_header_tensor_rows.csv",
    "sampled_page_hash_probe_rows.csv",
    "runtime_gap_rows.csv",
    "V61O_CHECKPOINT_SHARD_HEADER_PROBE_BOUNDARY.md",
    "v61o_checkpoint_shard_header_probe_manifest.json",
    "source_v61k/real_model_identity_rows.csv",
    "source_v61k/real_model_config_rows.csv",
    "source_v61k/checkpoint_shard_manifest_rows.csv",
    "source_v61k/tensor_page_manifest_rows.csv",
    "source_v61k/V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    "source_v61k/v61k_real_model_page_manifest_manifest.json",
    "source_v61k/sha256_manifest.csv",
    "source_v61k/v61k_real_model_page_manifest_summary.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61o_checkpoint_shard_header_probe_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
