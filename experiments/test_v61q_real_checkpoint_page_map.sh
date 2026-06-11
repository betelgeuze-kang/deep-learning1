#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61q_real_checkpoint_page_map/map_001"
SUMMARY_CSV="$RESULTS_DIR/v61q_real_checkpoint_page_map_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61q_real_checkpoint_page_map_decision.csv"

V61Q_REUSE_EXISTING="${V61Q_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61q_real_checkpoint_page_map.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
    "v61q_real_checkpoint_page_map_ready": "1",
    "v61o_checkpoint_shard_header_probe_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_model_license": "apache-2.0",
    "checkpoint_shard_rows": "59",
    "checkpoint_tensor_rows": "1739",
    "checkpoint_unique_page_rows": "134161",
    "checkpoint_page_segment_rows": "135841",
    "page_size_bytes": "2097152",
    "mapped_tensor_payload_bytes": "281241268224",
    "total_checkpoint_bytes_required": "281241493344",
    "header_and_metadata_bytes": "225120",
    "sampled_page_hash_probe_rows": "3",
    "sampled_safetensors_page_hash_binding_ready": "1",
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
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61q {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_tensor_page_span_rows.csv",
    "checkpoint_page_segment_rows.csv",
    "checkpoint_unique_page_rows.csv",
    "checkpoint_shard_page_summary_rows.csv",
    "checkpoint_page_map_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61Q_REAL_CHECKPOINT_PAGE_MAP_BOUNDARY.md",
    "v61q_real_checkpoint_page_map_manifest.json",
    "sha256_manifest.csv",
    "source_v61o/checkpoint_index_rows.csv",
    "source_v61o/checkpoint_shard_http_identity_rows.csv",
    "source_v61o/safetensors_header_probe_rows.csv",
    "source_v61o/safetensors_header_tensor_rows.csv",
    "source_v61o/sampled_page_hash_probe_rows.csv",
    "source_v61o/v61o_checkpoint_shard_header_probe_summary.csv",
    "source_v61o/v61o_checkpoint_shard_header_probe_decision.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61q artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61o-checkpoint-shard-header-probe-input",
    "real-safetensors-tensor-offset-map",
    "checkpoint-page-enumeration",
    "manifest-only-no-weight-bytes",
    "sampled-page-hash-probe-binding",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61q gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "local-ssd-checkpoint-residency",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61q gate should remain blocked: {gate}")

span_rows = read_csv(run_dir / "checkpoint_tensor_page_span_rows.csv")
segment_rows = read_csv(run_dir / "checkpoint_page_segment_rows.csv")
page_rows = read_csv(run_dir / "checkpoint_unique_page_rows.csv")
shard_rows = read_csv(run_dir / "checkpoint_shard_page_summary_rows.csv")
metric = read_csv(run_dir / "checkpoint_page_map_metric_rows.csv")[0]
if len(span_rows) != 1739 or len(segment_rows) != 135841 or len(page_rows) != 134161 or len(shard_rows) != 59:
    raise SystemExit("v61q page-map row counts mismatch")
if metric["checkpoint_page_map_ready"] != "1" or metric["weight_bytes_included"] != "0":
    raise SystemExit("v61q metric readiness mismatch")

payload_from_segments = sum(int(row["tensor_segment_bytes"]) for row in segment_rows)
if payload_from_segments != int(summary["mapped_tensor_payload_bytes"]):
    raise SystemExit("v61q segment payload total mismatch")
page_bytes_total = sum(int(row["page_bytes_in_shard"]) for row in page_rows)
if page_bytes_total != int(summary["total_checkpoint_bytes_required"]):
    raise SystemExit("v61q unique page byte total mismatch")
page_payload_total = sum(int(row["payload_bytes_mapped"]) for row in page_rows)
if page_payload_total != int(summary["mapped_tensor_payload_bytes"]):
    raise SystemExit("v61q unique page payload total mismatch")

for row in span_rows[:10]:
    if row["weight_bytes_included"] != "0" or row["tensor_page_map_ready"] != "1":
        raise SystemExit("v61q tensor spans should be metadata-only and ready")
for row in segment_rows[:10]:
    if row["weight_bytes_included"] != "0" or int(row["tensor_segment_bytes"]) <= 0:
        raise SystemExit("v61q page segments should be metadata-only and non-empty")
for row in page_rows[:10]:
    if row["weight_bytes_included"] != "0" or row["page_payload_hash_verified"] != "0":
        raise SystemExit("v61q unique pages should not include or verify payload bytes")

sampled_overlaps = sum(int(row["sampled_page_probe_overlap"]) for row in page_rows)
if sampled_overlaps < 3:
    raise SystemExit("v61q should bind sampled v61o page probes to page overlaps")

manifest = json.loads((run_dir / "v61q_real_checkpoint_page_map_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61q_real_checkpoint_page_map_ready") != 1:
    raise SystemExit("v61q manifest readiness mismatch")
if manifest.get("checkpoint_unique_page_rows") != 134161 or manifest.get("checkpoint_page_segment_rows") != 135841:
    raise SystemExit("v61q manifest page counts mismatch")
if manifest.get("real_checkpoint_weight_bytes_materialized") != 0:
    raise SystemExit("v61q manifest should not materialize checkpoint weights")

boundary = (run_dir / "V61Q_REAL_CHECKPOINT_PAGE_MAP_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real safetensors-header-derived checkpoint page map",
    "checkpoint_unique_page_rows=134161",
    "checkpoint_page_segment_rows=135841",
    "checkpoint_page_map_weight_bytes_included=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61q boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61q sha256 mismatch: {rel}")
PY

echo "v61q real checkpoint page map smoke passed"
