#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61q_real_checkpoint_page_map"
RUN_ID="${V61Q_RUN_ID:-map_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61Q_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61q_real_checkpoint_page_map_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61O_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61o_checkpoint_shard_header_probe.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61o_dir = results / "v61o_checkpoint_shard_header_probe" / "probe_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"
page_size_bytes = 2 * 1024 * 1024


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


v61o_summary = read_csv(results / "v61o_checkpoint_shard_header_probe_summary.csv")[0]
if v61o_summary.get("v61o_checkpoint_shard_header_probe_ready") != "1":
    raise SystemExit("v61q requires v61o_checkpoint_shard_header_probe_ready=1")

for rel in [
    "checkpoint_index_rows.csv",
    "checkpoint_shard_http_identity_rows.csv",
    "safetensors_header_probe_rows.csv",
    "safetensors_header_tensor_rows.csv",
    "sampled_page_hash_probe_rows.csv",
    "runtime_gap_rows.csv",
    "V61O_CHECKPOINT_SHARD_HEADER_PROBE_BOUNDARY.md",
    "v61o_checkpoint_shard_header_probe_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61o_dir / rel, f"source_v61o/{rel}")
copy(results / "v61o_checkpoint_shard_header_probe_summary.csv", "source_v61o/v61o_checkpoint_shard_header_probe_summary.csv")
copy(results / "v61o_checkpoint_shard_header_probe_decision.csv", "source_v61o/v61o_checkpoint_shard_header_probe_decision.csv")

index_rows = read_csv(v61o_dir / "checkpoint_index_rows.csv")
http_rows = read_csv(v61o_dir / "checkpoint_shard_http_identity_rows.csv")
header_rows = read_csv(v61o_dir / "safetensors_header_probe_rows.csv")
tensor_rows = read_csv(v61o_dir / "safetensors_header_tensor_rows.csv")
sample_probe_rows = read_csv(v61o_dir / "sampled_page_hash_probe_rows.csv")

if len(index_rows) != 1 or len(http_rows) != 59 or len(header_rows) != 59:
    raise SystemExit("v61q expects one index row and 59 shard/header rows")
if int(v61o_summary["safetensors_header_tensor_rows"]) != len(tensor_rows):
    raise SystemExit("v61q tensor rows differ from v61o summary")

http_by_shard = {row["shard_name"]: row for row in http_rows}
header_by_shard = {row["shard_name"]: row for row in header_rows}
known_shards = set(http_by_shard)
if {row["shard_name"] for row in tensor_rows} - known_shards:
    raise SystemExit("v61q tensor rows reference unknown shards")

sample_probe_by_shard = {row["shard_name"]: row for row in sample_probe_rows}
page_segments_by_page = defaultdict(list)
page_payload_bytes = defaultdict(int)
page_sample_overlap = defaultdict(int)
payload_bytes_by_shard = defaultdict(int)
segment_rows_written = 0
mapped_tensor_payload_bytes = 0

span_fields = [
    "model_id",
    "shard_name",
    "tensor_name",
    "dtype",
    "shape",
    "tensor_payload_bytes",
    "absolute_data_offset_start",
    "absolute_data_offset_end",
    "first_shard_page_index",
    "last_shard_page_index",
    "page_span_count",
    "starts_on_page_boundary",
    "ends_on_page_boundary",
    "tensor_header_bound",
    "weight_bytes_included",
    "tensor_page_map_ready",
]
segment_fields = [
    "page_segment_id",
    "page_id",
    "model_id",
    "shard_name",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "tensor_name",
    "tensor_segment_index",
    "tensor_segment_start_byte",
    "tensor_segment_end_byte_exclusive",
    "tensor_segment_bytes",
    "tensor_offset_start_in_tensor",
    "tensor_offset_end_in_tensor",
    "page_offset_start",
    "page_offset_end",
    "dtype",
    "weight_bytes_included",
    "sampled_probe_overlap",
    "page_payload_hash_verified",
]
span_path = run_dir / "checkpoint_tensor_page_span_rows.csv"
segment_path = run_dir / "checkpoint_page_segment_rows.csv"
with span_path.open("w", newline="", encoding="utf-8") as span_handle, segment_path.open("w", newline="", encoding="utf-8") as segment_handle:
    span_writer = csv.DictWriter(span_handle, fieldnames=span_fields, lineterminator="\n")
    segment_writer = csv.DictWriter(segment_handle, fieldnames=segment_fields, lineterminator="\n")
    span_writer.writeheader()
    segment_writer.writeheader()

    for tensor_index, tensor in enumerate(tensor_rows):
        shard_name = tensor["shard_name"]
        start = int(tensor["absolute_data_offset_start"])
        end = int(tensor["absolute_data_offset_end"])
        payload_bytes = int(tensor["tensor_payload_bytes"])
        if end <= start or end - start != payload_bytes:
            raise SystemExit(f"v61q invalid tensor offset span: {tensor['tensor_name']}")
        if end > int(http_by_shard[shard_name]["content_length"]):
            raise SystemExit(f"v61q tensor extends past shard content length: {tensor['tensor_name']}")

        first_page = start // page_size_bytes
        last_page = (end - 1) // page_size_bytes
        page_span_count = last_page - first_page + 1
        mapped_tensor_payload_bytes += payload_bytes
        payload_bytes_by_shard[shard_name] += payload_bytes

        span_writer.writerow(
            {
                "model_id": model_id,
                "shard_name": shard_name,
                "tensor_name": tensor["tensor_name"],
                "dtype": tensor["dtype"],
                "shape": tensor["shape"],
                "tensor_payload_bytes": str(payload_bytes),
                "absolute_data_offset_start": str(start),
                "absolute_data_offset_end": str(end),
                "first_shard_page_index": str(first_page),
                "last_shard_page_index": str(last_page),
                "page_span_count": str(page_span_count),
                "starts_on_page_boundary": str(int(start % page_size_bytes == 0)),
                "ends_on_page_boundary": str(int(end % page_size_bytes == 0)),
                "tensor_header_bound": tensor["tensor_header_bound"],
                "weight_bytes_included": "0",
                "tensor_page_map_ready": "1",
            }
        )

        sample = sample_probe_by_shard.get(shard_name)
        sample_start = int(sample["page_start_byte"]) if sample else None
        sample_end = int(sample["page_end_byte"]) + 1 if sample else None
        for segment_index, page_index in enumerate(range(first_page, last_page + 1)):
            page_start = page_index * page_size_bytes
            page_end = min((page_index + 1) * page_size_bytes, int(http_by_shard[shard_name]["content_length"]))
            segment_start = max(start, page_start)
            segment_end = min(end, page_end)
            segment_bytes = segment_end - segment_start
            if segment_bytes <= 0:
                raise SystemExit("v61q produced an empty tensor/page segment")
            sampled_overlap = 0
            if sample_start is not None:
                sampled_overlap = int(max(segment_start, sample_start) < min(segment_end, sample_end))
            page_id = f"v61q:{shard_name}:page:{page_index:08d}"
            segment_id = f"v61q:{shard_name}:tensor:{tensor_index:05d}:segment:{segment_index:04d}"
            page_key = (shard_name, page_index)
            page_segments_by_page[page_key].append(segment_id)
            page_payload_bytes[page_key] += segment_bytes
            page_sample_overlap[page_key] = max(page_sample_overlap[page_key], sampled_overlap)
            segment_writer.writerow(
                {
                    "page_segment_id": segment_id,
                    "page_id": page_id,
                    "model_id": model_id,
                    "shard_name": shard_name,
                    "shard_page_index": str(page_index),
                    "page_start_byte": str(page_start),
                    "page_end_byte_exclusive": str(page_end),
                    "tensor_name": tensor["tensor_name"],
                    "tensor_segment_index": str(segment_index),
                    "tensor_segment_start_byte": str(segment_start),
                    "tensor_segment_end_byte_exclusive": str(segment_end),
                    "tensor_segment_bytes": str(segment_bytes),
                    "tensor_offset_start_in_tensor": str(segment_start - start),
                    "tensor_offset_end_in_tensor": str(segment_end - start),
                    "page_offset_start": str(segment_start - page_start),
                    "page_offset_end": str(segment_end - page_start),
                    "dtype": tensor["dtype"],
                    "weight_bytes_included": "0",
                    "sampled_probe_overlap": str(sampled_overlap),
                    "page_payload_hash_verified": "0",
                }
            )
            segment_rows_written += 1

page_fields = [
    "page_id",
    "model_id",
    "shard_name",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_size_bytes",
    "page_bytes_in_shard",
    "tensor_segment_count",
    "payload_bytes_mapped",
    "header_or_padding_bytes",
    "sampled_page_probe_overlap",
    "page_payload_hash_verified",
    "weight_bytes_included",
]
page_rows_written = 0
with (run_dir / "checkpoint_unique_page_rows.csv").open("w", newline="", encoding="utf-8") as page_handle:
    writer = csv.DictWriter(page_handle, fieldnames=page_fields, lineterminator="\n")
    writer.writeheader()
    for shard_name in sorted(known_shards):
        content_length = int(http_by_shard[shard_name]["content_length"])
        page_count = math.ceil(content_length / page_size_bytes)
        for page_index in range(page_count):
            page_start = page_index * page_size_bytes
            page_end = min((page_index + 1) * page_size_bytes, content_length)
            page_key = (shard_name, page_index)
            payload_bytes = page_payload_bytes.get(page_key, 0)
            page_bytes = page_end - page_start
            writer.writerow(
                {
                    "page_id": f"v61q:{shard_name}:page:{page_index:08d}",
                    "model_id": model_id,
                    "shard_name": shard_name,
                    "shard_page_index": str(page_index),
                    "page_start_byte": str(page_start),
                    "page_end_byte_exclusive": str(page_end),
                    "page_size_bytes": str(page_size_bytes),
                    "page_bytes_in_shard": str(page_bytes),
                    "tensor_segment_count": str(len(page_segments_by_page.get(page_key, []))),
                    "payload_bytes_mapped": str(payload_bytes),
                    "header_or_padding_bytes": str(page_bytes - payload_bytes),
                    "sampled_page_probe_overlap": str(page_sample_overlap.get(page_key, 0)),
                    "page_payload_hash_verified": "0",
                    "weight_bytes_included": "0",
                }
            )
            page_rows_written += 1

shard_summary_rows = []
for shard_name in sorted(known_shards):
    content_length = int(http_by_shard[shard_name]["content_length"])
    page_count = math.ceil(content_length / page_size_bytes)
    payload_bytes = payload_bytes_by_shard[shard_name]
    header_metadata_bytes = content_length - payload_bytes
    header_probe_bytes = int(header_by_shard[shard_name]["header_probe_bytes_read"])
    shard_summary_rows.append(
        {
            "model_id": model_id,
            "shard_name": shard_name,
            "content_length": str(content_length),
            "page_size_bytes": str(page_size_bytes),
            "checkpoint_page_rows": str(page_count),
            "tensor_rows": str(sum(1 for row in tensor_rows if row["shard_name"] == shard_name)),
            "mapped_tensor_payload_bytes": str(payload_bytes),
            "header_and_metadata_bytes": str(header_metadata_bytes),
            "header_probe_bytes_read": str(header_probe_bytes),
            "payload_coverage_ready": str(int(header_metadata_bytes == header_probe_bytes)),
            "weight_bytes_included": "0",
        }
    )
write_csv(run_dir / "checkpoint_shard_page_summary_rows.csv", list(shard_summary_rows[0].keys()), shard_summary_rows)

total_checkpoint_bytes_required = sum(int(row["content_length"]) for row in http_rows)
header_and_metadata_bytes = total_checkpoint_bytes_required - mapped_tensor_payload_bytes
metric_rows = [
    {
        "model_id": model_id,
        "checkpoint_shard_rows": str(len(http_rows)),
        "checkpoint_tensor_rows": str(len(tensor_rows)),
        "checkpoint_unique_page_rows": str(page_rows_written),
        "checkpoint_page_segment_rows": str(segment_rows_written),
        "page_size_bytes": str(page_size_bytes),
        "mapped_tensor_payload_bytes": str(mapped_tensor_payload_bytes),
        "total_checkpoint_bytes_required": str(total_checkpoint_bytes_required),
        "header_and_metadata_bytes": str(header_and_metadata_bytes),
        "sampled_page_hash_probe_rows": str(len(sample_probe_rows)),
        "weight_bytes_included": "0",
        "checkpoint_weight_bytes_persisted": "0",
        "checkpoint_page_map_ready": "1",
    }
]
write_csv(run_dir / "checkpoint_page_map_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

gap_rows = [
    ("real-checkpoint-page-map", "ready", "all v61o safetensors tensor offsets are mapped to 2 MiB SSD pages as metadata only"),
    ("full-checkpoint-materialization", "blocked", "v61q does not download or persist checkpoint payload bytes"),
    ("full-safetensors-page-hash-binding", "blocked", "v61q maps pages but does not hash every page payload"),
    ("local-ssd-checkpoint-residency", "blocked", "page map does not prove all shards are resident in the outside-repository SSD warehouse"),
    ("real-model-generation", "blocked", "v61q does not execute real Mixtral generation"),
    ("near-frontier-quality", "blocked", "checkpoint page mapping is not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

summary = {
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61o_checkpoint_shard_header_probe_ready": v61o_summary["v61o_checkpoint_shard_header_probe_ready"],
    "model_id": model_id,
    "source_model_license": v61o_summary["source_model_license"],
    "checkpoint_shard_rows": str(len(http_rows)),
    "checkpoint_tensor_rows": str(len(tensor_rows)),
    "checkpoint_unique_page_rows": str(page_rows_written),
    "checkpoint_page_segment_rows": str(segment_rows_written),
    "page_size_bytes": str(page_size_bytes),
    "mapped_tensor_payload_bytes": str(mapped_tensor_payload_bytes),
    "total_checkpoint_bytes_required": str(total_checkpoint_bytes_required),
    "header_and_metadata_bytes": str(header_and_metadata_bytes),
    "sampled_page_hash_probe_rows": str(len(sample_probe_rows)),
    "sampled_safetensors_page_hash_binding_ready": v61o_summary["sampled_safetensors_page_hash_binding_ready"],
    "checkpoint_page_map_weight_bytes_included": "0",
    "checkpoint_weight_bytes_persisted": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61o-checkpoint-shard-header-probe-input", "pass", "v61o index, shard HTTP identity, and safetensors tensor headers are bound"),
    ("real-safetensors-tensor-offset-map", "pass", f"tensor_rows={len(tensor_rows)}; mapped_tensor_payload_bytes={mapped_tensor_payload_bytes}"),
    ("checkpoint-page-enumeration", "pass", f"unique_page_rows={page_rows_written}; segment_rows={segment_rows_written}"),
    ("manifest-only-no-weight-bytes", "pass", "v61q writes page metadata only and includes zero checkpoint payload bytes"),
    ("sampled-page-hash-probe-binding", "pass", f"sampled_page_hash_probe_rows={len(sample_probe_rows)} from v61o remain bound"),
    ("full-checkpoint-materialization", "blocked", "full checkpoint shards are not downloaded or persisted"),
    ("full-safetensors-page-hash-binding", "blocked", "full page hash sweep remains future work"),
    ("local-ssd-checkpoint-residency", "blocked", "local checkpoint residency is not proven by the page map"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61Q_REAL_CHECKPOINT_PAGE_MAP_BOUNDARY.md").write_text(
    "# v61q Real Checkpoint Page Map Boundary\n\n"
    "This layer converts the v61o live safetensors header tensor offsets into a 2 MiB SSD page map for the real Mixtral 8x22B checkpoint. "
    "It records shard pages, tensor/page overlap segments, tensor page spans, per-shard coverage, and aggregate metrics as redistributable metadata only. "
    "It does not download, persist, redistribute, or hash the full checkpoint payload.\n\n"
    f"- checkpoint_shard_rows={len(http_rows)}\n"
    f"- checkpoint_tensor_rows={len(tensor_rows)}\n"
    f"- checkpoint_unique_page_rows={page_rows_written}\n"
    f"- checkpoint_page_segment_rows={segment_rows_written}\n"
    f"- page_size_bytes={page_size_bytes}\n"
    f"- mapped_tensor_payload_bytes={mapped_tensor_payload_bytes}\n"
    f"- total_checkpoint_bytes_required={total_checkpoint_bytes_required}\n"
    f"- header_and_metadata_bytes={header_and_metadata_bytes}\n"
    f"- sampled_page_hash_probe_rows={len(sample_probe_rows)}\n"
    "- checkpoint_page_map_weight_bytes_included=0\n"
    "- checkpoint_weight_bytes_persisted=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- real_100b_open_weight_materialized=0\n"
    "- full_safetensors_page_hash_binding_ready=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: real safetensors-header-derived checkpoint page map, manifest-only SSD page layout, and tensor/page offset binding. "
    "Blocked wording: full local checkpoint residency, full page-hash coverage, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61q-real-checkpoint-page-map",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61q_real_checkpoint_page_map_ready": 1,
    "v61o_summary_sha256": sha256(results / "v61o_checkpoint_shard_header_probe_summary.csv"),
    "checkpoint_shard_rows": len(http_rows),
    "checkpoint_tensor_rows": len(tensor_rows),
    "checkpoint_unique_page_rows": page_rows_written,
    "checkpoint_page_segment_rows": segment_rows_written,
    "page_size_bytes": page_size_bytes,
    "mapped_tensor_payload_bytes": mapped_tensor_payload_bytes,
    "total_checkpoint_bytes_required": total_checkpoint_bytes_required,
    "header_and_metadata_bytes": header_and_metadata_bytes,
    "sampled_page_hash_probe_rows": len(sample_probe_rows),
    "checkpoint_page_map_weight_bytes_included": 0,
    "checkpoint_weight_bytes_persisted": 0,
    "real_checkpoint_weight_bytes_materialized": 0,
    "real_100b_open_weight_materialized": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61q_real_checkpoint_page_map_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "checkpoint_tensor_page_span_rows.csv",
    "checkpoint_page_segment_rows.csv",
    "checkpoint_unique_page_rows.csv",
    "checkpoint_shard_page_summary_rows.csv",
    "checkpoint_page_map_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61Q_REAL_CHECKPOINT_PAGE_MAP_BOUNDARY.md",
    "v61q_real_checkpoint_page_map_manifest.json",
    "source_v61o/checkpoint_index_rows.csv",
    "source_v61o/checkpoint_shard_http_identity_rows.csv",
    "source_v61o/safetensors_header_probe_rows.csv",
    "source_v61o/safetensors_header_tensor_rows.csv",
    "source_v61o/sampled_page_hash_probe_rows.csv",
    "source_v61o/runtime_gap_rows.csv",
    "source_v61o/V61O_CHECKPOINT_SHARD_HEADER_PROBE_BOUNDARY.md",
    "source_v61o/v61o_checkpoint_shard_header_probe_manifest.json",
    "source_v61o/sha256_manifest.csv",
    "source_v61o/v61o_checkpoint_shard_header_probe_summary.csv",
    "source_v61o/v61o_checkpoint_shard_header_probe_decision.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61q_real_checkpoint_page_map_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
