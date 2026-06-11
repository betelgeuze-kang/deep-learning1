#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61u_remote_checkpoint_page_hash_sampler"
RUN_ID="${V61U_RUN_ID:-sample_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61U_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61u_remote_checkpoint_page_hash_sampler_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61Q_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61q_real_checkpoint_page_map.sh" >/dev/null
V61T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null

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

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61o_dir = results / "v61o_checkpoint_shard_header_probe" / "probe_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"
target_sample_rows = int(os.environ.get("V61U_REMOTE_PAGE_SAMPLE_ROWS", "16"))
if target_sample_rows <= 0:
    raise SystemExit("V61U_REMOTE_PAGE_SAMPLE_ROWS must be positive")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


def request_range(url, start, end_inclusive, timeout=120):
    req = urllib.request.Request(
        url,
        headers={
            "Range": f"bytes={start}-{end_inclusive}",
            "User-Agent": "v61u-remote-checkpoint-page-hash-sampler/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        data = response.read()
        return data, response


v61q_summary = read_csv(results / "v61q_real_checkpoint_page_map_summary.csv")[0]
v61t_summary = read_csv(results / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61u requires v61q_real_checkpoint_page_map_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61u requires v61t_local_checkpoint_materialization_verifier_ready=1")

for src, rel in [
    (results / "v61q_real_checkpoint_page_map_summary.csv", "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (v61q_dir / "checkpoint_shard_page_summary_rows.csv", "source_v61q/checkpoint_shard_page_summary_rows.csv"),
    (v61q_dir / "checkpoint_page_map_metric_rows.csv", "source_v61q/checkpoint_page_map_metric_rows.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_summary.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_decision.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "v61t_local_checkpoint_materialization_verifier_manifest.json", "source_v61t/v61t_local_checkpoint_materialization_verifier_manifest.json"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
    (v61o_dir / "checkpoint_shard_http_identity_rows.csv", "source_v61o/checkpoint_shard_http_identity_rows.csv"),
    (v61o_dir / "sampled_page_hash_probe_rows.csv", "source_v61o/sampled_page_hash_probe_rows.csv"),
]:
    copy(src, rel)

page_rows = read_csv(v61q_dir / "checkpoint_unique_page_rows.csv")
http_rows = read_csv(v61o_dir / "checkpoint_shard_http_identity_rows.csv")
prior_sample_rows = read_csv(v61o_dir / "sampled_page_hash_probe_rows.csv")
if len(page_rows) != int(v61q_summary["checkpoint_unique_page_rows"]):
    raise SystemExit("v61u page row count differs from v61q summary")
if len(http_rows) != 59:
    raise SystemExit("v61u expects 59 v61o HTTP identity rows")

http_by_shard = {row["shard_name"]: row for row in http_rows}
eligible_pages = [row for row in page_rows if int(row["page_bytes_in_shard"]) == int(row["page_size_bytes"])]
if len(eligible_pages) < target_sample_rows:
    raise SystemExit("v61u does not have enough full-size pages to sample")

if target_sample_rows == 1:
    selected_indices = [0]
else:
    selected_indices = sorted({round(i * (len(eligible_pages) - 1) / (target_sample_rows - 1)) for i in range(target_sample_rows)})
    cursor = 0
    while len(selected_indices) < target_sample_rows:
        if cursor not in selected_indices:
            selected_indices.append(cursor)
        cursor += 1
    selected_indices = sorted(selected_indices[:target_sample_rows])
selected_pages = [eligible_pages[i] for i in selected_indices]

plan_rows = []
sample_rows = []
overlap_rows = []
bytes_read_total = 0
ready_rows = 0
unique_shards = set()

for sample_index, page in enumerate(selected_pages):
    shard_name = page["shard_name"]
    http = http_by_shard[shard_name]
    start = int(page["page_start_byte"])
    end_exclusive = int(page["page_end_byte_exclusive"])
    end_inclusive = end_exclusive - 1
    expected_bytes = int(page["page_bytes_in_shard"])
    sample_id = f"v61u_remote_sample_{sample_index:04d}"
    unique_shards.add(shard_name)
    plan_rows.append(
        {
            "remote_sample_id": sample_id,
            "model_id": model_id,
            "source_page_id": page["page_id"],
            "shard_name": shard_name,
            "shard_page_index": page["shard_page_index"],
            "page_start_byte": str(start),
            "page_end_byte_exclusive": str(end_exclusive),
            "expected_page_bytes": str(expected_bytes),
            "source_url": http["source_url"],
            "expected_shard_bytes": http["content_length"],
            "expected_etag": http["etag"],
            "sample_selection_method": "evenly-spaced-full-size-v61q-pages",
            "checkpoint_payload_bytes_persisted": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
    data, response = request_range(http["source_url"], start, end_inclusive)
    page_sha = sha256_bytes(data)
    bytes_read = len(data)
    ready = int(bytes_read == expected_bytes and bytes_read > 0)
    ready_rows += ready
    bytes_read_total += bytes_read
    sample_rows.append(
        {
            "remote_sample_id": sample_id,
            "model_id": model_id,
            "source_page_id": page["page_id"],
            "shard_name": shard_name,
            "shard_page_index": page["shard_page_index"],
            "page_start_byte": str(start),
            "page_end_byte_exclusive": str(end_exclusive),
            "expected_page_bytes": str(expected_bytes),
            "remote_page_bytes_read": str(bytes_read),
            "remote_page_sha256": page_sha,
            "http_status": str(response.status),
            "content_range": response.headers.get("Content-Range", ""),
            "remote_page_hash_sample_ready": str(ready),
            "checkpoint_payload_bytes_persisted": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
    overlap_rows.append(
        {
            "remote_sample_id": sample_id,
            "source_page_id": page["page_id"],
            "v61q_shard_name": page["shard_name"],
            "v61q_shard_page_index": page["shard_page_index"],
            "v61q_page_start_byte": page["page_start_byte"],
            "v61q_page_end_byte_exclusive": page["page_end_byte_exclusive"],
            "remote_page_start_byte": str(start),
            "remote_page_end_byte_exclusive": str(end_exclusive),
            "overlap_bytes": str(expected_bytes if ready else 0),
            "v61q_page_map_overlap_ready": str(ready),
            "full_safetensors_page_hash_binding_ready": "0",
        }
    )

write_csv(run_dir / "remote_page_hash_sample_plan_rows.csv", list(plan_rows[0].keys()), plan_rows)
write_csv(run_dir / "remote_page_hash_sample_rows.csv", list(sample_rows[0].keys()), sample_rows)
write_csv(run_dir / "remote_page_hash_page_map_overlap_rows.csv", list(overlap_rows[0].keys()), overlap_rows)

full_hash_ready = 0
metric_rows = [
    {
        "model_id": model_id,
        "v61q_checkpoint_unique_page_rows": v61q_summary["checkpoint_unique_page_rows"],
        "remote_page_hash_sample_plan_rows": str(len(plan_rows)),
        "remote_page_hash_sample_rows": str(len(sample_rows)),
        "remote_page_hash_sample_ready_rows": str(ready_rows),
        "remote_page_hash_sample_unique_shards": str(len(unique_shards)),
        "remote_page_payload_bytes_read": str(bytes_read_total),
        "prior_v61o_sampled_page_hash_probe_rows": str(len(prior_sample_rows)),
        "full_safetensors_page_hash_binding_ready": str(full_hash_ready),
        "local_checkpoint_materialization_ready": v61t_summary["local_checkpoint_materialization_ready"],
        "checkpoint_payload_bytes_persisted": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "real_checkpoint_weight_bytes_materialized": "0",
        "actual_model_generation_ready": "0",
    }
]
write_csv(run_dir / "remote_page_hash_sample_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

gap_rows = [
    ("remote-page-hash-sample", "ready" if ready_rows == len(sample_rows) else "blocked", "bounded remote page hashes are sampled directly from the checkpoint source"),
    ("local-checkpoint-materialization", "ready" if v61t_summary["local_checkpoint_materialization_ready"] == "1" else "blocked", "all shards must be identity-verified locally before materialization is ready"),
    ("full-safetensors-page-hash-binding", "blocked", "bounded remote samples are not full page-hash coverage"),
    ("real-model-generation", "blocked", "v61u does not execute real Mixtral generation"),
    ("near-frontier-quality", "blocked", "remote page hashes are not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61u_remote_checkpoint_page_hash_sampler_ready": "1",
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "model_id": model_id,
    "checkpoint_unique_page_rows": v61q_summary["checkpoint_unique_page_rows"],
    "remote_page_hash_sample_plan_rows": str(len(plan_rows)),
    "remote_page_hash_sample_rows": str(len(sample_rows)),
    "remote_page_hash_sample_ready_rows": str(ready_rows),
    "remote_page_hash_sample_unique_shards": str(len(unique_shards)),
    "remote_page_payload_bytes_read": str(bytes_read_total),
    "prior_v61o_sampled_page_hash_probe_rows": str(len(prior_sample_rows)),
    "full_safetensors_page_hash_binding_ready": str(full_hash_ready),
    "local_checkpoint_materialization_ready": v61t_summary["local_checkpoint_materialization_ready"],
    "checkpoint_payload_bytes_persisted": "0",
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
    ("v61q-real-checkpoint-page-map-input", "pass", "v61q checkpoint page rows are bound"),
    ("v61t-local-materialization-verifier-input", "pass", "v61t local materialization identity boundary is bound"),
    ("remote-page-hash-sample-plan", "pass", f"remote_page_hash_sample_plan_rows={len(plan_rows)}"),
    ("remote-page-hash-sample", "pass" if ready_rows == len(sample_rows) else "blocked", f"ready_rows={ready_rows}; sample_rows={len(sample_rows)}"),
    ("manifest-only-no-repo-payload", "pass", "v61u writes hashes/metadata only and does not persist checkpoint payload bytes"),
    ("local-checkpoint-materialization", "pass" if v61t_summary["local_checkpoint_materialization_ready"] == "1" else "blocked", "requires identity-verified local shards"),
    ("full-safetensors-page-hash-binding", "blocked", "bounded remote samples are not full page-hash coverage"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61U_REMOTE_CHECKPOINT_PAGE_HASH_SAMPLER_BOUNDARY.md").write_text(
    "# v61u Remote Checkpoint Page Hash Sampler Boundary\n\n"
    "This layer expands real checkpoint page-hash evidence by performing bounded HTTP range reads over deterministic v61q full-size checkpoint pages and storing only page hashes and metadata. "
    "It does not download full checkpoint shards, does not persist checkpoint payload bytes, and does not make a full page-hash coverage claim.\n\n"
    f"- checkpoint_unique_page_rows={v61q_summary['checkpoint_unique_page_rows']}\n"
    f"- remote_page_hash_sample_rows={len(sample_rows)}\n"
    f"- remote_page_hash_sample_ready_rows={ready_rows}\n"
    f"- remote_page_hash_sample_unique_shards={len(unique_shards)}\n"
    f"- remote_page_payload_bytes_read={bytes_read_total}\n"
    f"- prior_v61o_sampled_page_hash_probe_rows={len(prior_sample_rows)}\n"
    "- full_safetensors_page_hash_binding_ready=0\n"
    f"- local_checkpoint_materialization_ready={v61t_summary['local_checkpoint_materialization_ready']}\n"
    "- checkpoint_payload_bytes_persisted=0\n"
    "- checkpoint_payload_bytes_committed_to_repo=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: bounded remote checkpoint page-hash samples over the v61q page map. "
    "Blocked wording: full safetensors page-hash coverage, completed local checkpoint materialization, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61u-remote-checkpoint-page-hash-sampler",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61u_remote_checkpoint_page_hash_sampler_ready": 1,
    "v61q_summary_sha256": sha256(results / "v61q_real_checkpoint_page_map_summary.csv"),
    "v61t_summary_sha256": sha256(results / "v61t_local_checkpoint_materialization_verifier_summary.csv"),
    "checkpoint_unique_page_rows": int(v61q_summary["checkpoint_unique_page_rows"]),
    "remote_page_hash_sample_rows": len(sample_rows),
    "remote_page_hash_sample_ready_rows": ready_rows,
    "remote_page_hash_sample_unique_shards": len(unique_shards),
    "remote_page_payload_bytes_read": bytes_read_total,
    "prior_v61o_sampled_page_hash_probe_rows": len(prior_sample_rows),
    "full_safetensors_page_hash_binding_ready": 0,
    "local_checkpoint_materialization_ready": int(v61t_summary["local_checkpoint_materialization_ready"]),
    "checkpoint_payload_bytes_persisted": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_checkpoint_weight_bytes_materialized": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61u_remote_checkpoint_page_hash_sampler_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "remote_page_hash_sample_plan_rows.csv",
    "remote_page_hash_sample_rows.csv",
    "remote_page_hash_page_map_overlap_rows.csv",
    "remote_page_hash_sample_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61U_REMOTE_CHECKPOINT_PAGE_HASH_SAMPLER_BOUNDARY.md",
    "v61u_remote_checkpoint_page_hash_sampler_manifest.json",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/checkpoint_shard_page_summary_rows.csv",
    "source_v61q/checkpoint_page_map_metric_rows.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv",
    "source_v61t/local_checkpoint_materialization_metric_rows.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_manifest.json",
    "source_v61t/sha256_manifest.csv",
    "source_v61o/checkpoint_shard_http_identity_rows.csv",
    "source_v61o/sampled_page_hash_probe_rows.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61u_remote_checkpoint_page_hash_sampler_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
