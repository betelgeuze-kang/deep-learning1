#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61y_hotset_local_materialization_verifier"
RUN_ID="${V61Y_RUN_ID:-verify_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61Y_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61y_hotset_local_materialization_verifier_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61X_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61x_hotset_runtime_replay_manifest.sh" >/dev/null
V61U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61u_remote_checkpoint_page_hash_sampler.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v61u_dir = results / "v61u_remote_checkpoint_page_hash_sampler" / "sample_001"
v61x_dir = results / "v61x_hotset_runtime_replay_manifest" / "hotset_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
materialize_enabled = os.environ.get("V61Y_ENABLE_REMOTE_HOTSET_MATERIALIZATION", "1") == "1"


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


def inside_repo(path):
    try:
        Path(path).resolve().relative_to(root)
        return 1
    except ValueError:
        return 0


def request_range(url, start, end_inclusive, timeout=120):
    req = urllib.request.Request(
        url,
        headers={
            "Range": f"bytes={start}-{end_inclusive}",
            "User-Agent": "v61y-hotset-local-materialization-verifier/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read(), response


v61u_summary = read_csv(results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv")[0]
v61x_summary = read_csv(results / "v61x_hotset_runtime_replay_manifest_summary.csv")[0]

if v61u_summary.get("v61u_remote_checkpoint_page_hash_sampler_ready") != "1":
    raise SystemExit("v61y requires v61u_remote_checkpoint_page_hash_sampler_ready=1")
if v61x_summary.get("v61x_hotset_runtime_replay_manifest_ready") != "1":
    raise SystemExit("v61y requires v61x_hotset_runtime_replay_manifest_ready=1")
if v61x_summary.get("hotset_manifest_ready") != "1":
    raise SystemExit("v61y requires v61x hotset_manifest_ready=1")

for src, rel in [
    (results / "v61u_remote_checkpoint_page_hash_sampler_summary.csv", "source_v61u/v61u_remote_checkpoint_page_hash_sampler_summary.csv"),
    (v61u_dir / "remote_page_hash_sample_plan_rows.csv", "source_v61u/remote_page_hash_sample_plan_rows.csv"),
    (v61u_dir / "remote_page_hash_sample_rows.csv", "source_v61u/remote_page_hash_sample_rows.csv"),
    (v61u_dir / "remote_page_hash_sample_metric_rows.csv", "source_v61u/remote_page_hash_sample_metric_rows.csv"),
    (v61u_dir / "sha256_manifest.csv", "source_v61u/sha256_manifest.csv"),
    (results / "v61x_hotset_runtime_replay_manifest_summary.csv", "source_v61x/v61x_hotset_runtime_replay_manifest_summary.csv"),
    (results / "v61x_hotset_runtime_replay_manifest_decision.csv", "source_v61x/v61x_hotset_runtime_replay_manifest_decision.csv"),
    (v61x_dir / "hotset_runtime_page_rows.csv", "source_v61x/hotset_runtime_page_rows.csv"),
    (v61x_dir / "hotset_runtime_slot_rows.csv", "source_v61x/hotset_runtime_slot_rows.csv"),
    (v61x_dir / "hotset_source_bound_workload_binding_rows.csv", "source_v61x/hotset_source_bound_workload_binding_rows.csv"),
    (v61x_dir / "sha256_manifest.csv", "source_v61x/sha256_manifest.csv"),
]:
    copy(src, rel)

hotset_rows = read_csv(v61x_dir / "hotset_runtime_page_rows.csv")
remote_plan_rows = {row["remote_sample_id"]: row for row in read_csv(v61u_dir / "remote_page_hash_sample_plan_rows.csv")}
remote_sample_rows = {row["remote_sample_id"]: row for row in read_csv(v61u_dir / "remote_page_hash_sample_rows.csv")}

if len(hotset_rows) != 16:
    raise SystemExit("v61y expects 16 hotset rows from v61x")

materialization_rows = []
readback_rows = []
persisted_bytes = 0
verified_bytes = 0
local_present_rows = 0
hash_match_rows = 0
downloaded_by_v61y = 0
repo_path_errors = 0

for idx, hotset in enumerate(hotset_rows):
    sample_id = hotset["remote_sample_id"]
    plan = remote_plan_rows[sample_id]
    remote = remote_sample_rows[sample_id]
    target = Path(hotset["planned_local_page_path"]).expanduser()
    target_inside_repo = inside_repo(target)
    if target_inside_repo:
        repo_path_errors += 1
    expected_bytes = int(hotset["expected_page_bytes"])
    expected_sha = hotset["remote_page_sha256"]
    before_exists = target.is_file()
    before_bytes = target.stat().st_size if before_exists else 0
    materialized_by_v61y = 0
    materialization_status = "missing-local-page"
    http_status = ""
    content_range = ""

    if materialize_enabled and (not before_exists or before_bytes != expected_bytes or sha256(target) != expected_sha):
        start = int(plan["page_start_byte"])
        end = int(plan["page_end_byte_exclusive"]) - 1
        data, response = request_range(plan["source_url"], start, end)
        http_status = str(response.status)
        content_range = response.headers.get("Content-Range", "")
        if len(data) != expected_bytes:
            raise SystemExit(f"v61y materialized byte count mismatch for {sample_id}")
        if sha256_bytes(data) != expected_sha:
            raise SystemExit(f"v61y materialized sha256 mismatch for {sample_id}")
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_suffix(target.suffix + ".tmp")
        tmp.write_bytes(data)
        tmp.replace(target)
        materialized_by_v61y = 1
        downloaded_by_v61y += len(data)

    exists = target.is_file()
    actual_bytes = target.stat().st_size if exists else 0
    local_sha = sha256(target) if exists and actual_bytes == expected_bytes else ""
    hash_match = int(exists and actual_bytes == expected_bytes and local_sha == expected_sha)
    if hash_match:
        materialization_status = "verified-local-hotset-page"
        local_present_rows += 1
        hash_match_rows += 1
        persisted_bytes += actual_bytes

    read_start = time.perf_counter()
    readback_sha = ""
    readback_bytes = 0
    if hash_match:
        h = hashlib.sha256()
        with target.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                readback_bytes += len(chunk)
                h.update(chunk)
        readback_sha = "sha256:" + h.hexdigest()
    read_ms = (time.perf_counter() - read_start) * 1000.0
    readback_hash_match = int(readback_sha == expected_sha and readback_bytes == expected_bytes)
    if readback_hash_match:
        verified_bytes += readback_bytes

    materialization_rows.append(
        {
            "hotset_materialization_id": f"v61y_hotset_materialization_{idx:04d}",
            "hotset_page_id": hotset["hotset_page_id"],
            "slot_id": hotset["slot_id"],
            "remote_sample_id": sample_id,
            "model_id": model_id,
            "shard_name": hotset["shard_name"],
            "shard_page_index": hotset["shard_page_index"],
            "node_type": hotset["node_type"],
            "tensor_role": hotset["tensor_role"],
            "layer_index": hotset["layer_index"],
            "expert_index": hotset["expert_index"],
            "planned_local_page_path": str(target),
            "planned_local_page_path_inside_repository": str(target_inside_repo),
            "remote_page_sha256": expected_sha,
            "local_page_sha256": local_sha,
            "expected_page_bytes": str(expected_bytes),
            "local_page_bytes": str(actual_bytes),
            "local_page_exists": str(int(exists)),
            "local_hash_match": str(hash_match),
            "materialized_by_v61y": str(materialized_by_v61y),
            "materialization_status": materialization_status,
            "remote_source_url": plan["source_url"],
            "remote_page_http_status": http_status,
            "remote_page_content_range": content_range,
            "checkpoint_payload_bytes_persisted_outside_repo": str(actual_bytes if hash_match else 0),
            "checkpoint_payload_bytes_downloaded_by_v61y": str(expected_bytes if materialized_by_v61y else 0),
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "full_checkpoint_materialization_ready": "0",
            "full_safetensors_page_hash_binding_ready": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
    readback_rows.append(
        {
            "readback_id": f"v61y_hotset_readback_{idx:04d}",
            "hotset_page_id": hotset["hotset_page_id"],
            "slot_id": hotset["slot_id"],
            "read_mode": "local-file-stream-readback",
            "readback_bytes": str(readback_bytes),
            "readback_sha256": readback_sha,
            "remote_page_sha256": expected_sha,
            "readback_hash_match": str(readback_hash_match),
            "readback_ms": f"{read_ms:.6f}",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

hotset_payload_materialization_ready = int(local_present_rows == len(hotset_rows) and hash_match_rows == len(hotset_rows) and repo_path_errors == 0)
readback_ready = int(verified_bytes == persisted_bytes and persisted_bytes > 0)

metric_rows = [
    {
        "metric_id": "v61y_hotset_local_materialization_metrics",
        "hotset_page_rows": str(len(hotset_rows)),
        "local_hotset_page_present_rows": str(local_present_rows),
        "local_hotset_hash_match_rows": str(hash_match_rows),
        "local_hotset_readback_hash_match_rows": str(sum(int(row["readback_hash_match"]) for row in readback_rows)),
        "moe_hotset_page_rows": str(sum(1 for row in materialization_rows if row["node_type"] == "moe_expert_page_node")),
        "embedding_hotset_page_rows": str(sum(1 for row in materialization_rows if row["node_type"] == "embedding_page_node")),
        "sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo": str(persisted_bytes),
        "checkpoint_payload_bytes_downloaded_by_v61y": str(downloaded_by_v61y),
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "hotset_payload_materialization_ready": str(hotset_payload_materialization_ready),
        "hotset_readback_verify_ready": str(readback_ready),
        "full_checkpoint_materialization_ready": "0",
        "materialization_admission_ready": "0",
        "local_checkpoint_materialization_ready": "0",
        "full_safetensors_page_hash_binding_ready": "0",
        "real_100b_open_weight_materialized": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "route_jump_rows": "0",
    }
]

runtime_gap_rows = [
    {"gap": "v61x-hotset-manifest-input", "status": "ready", "evidence": "v61x hotset manifest ready and copied"},
    {"gap": "v61u-remote-page-hash-input", "status": "ready", "evidence": "v61u remote range hash samples ready and copied"},
    {"gap": "local-sampled-hotset-pages", "status": "ready" if hotset_payload_materialization_ready else "blocked", "evidence": f"{local_present_rows}/{len(hotset_rows)} sampled pages are local hash matches"},
    {"gap": "local-hotset-readback", "status": "ready" if readback_ready else "blocked", "evidence": f"{verified_bytes} bytes read back with matching hashes"},
    {"gap": "full-checkpoint-materialization", "status": "blocked", "evidence": "only 16 sampled pages are materialized"},
    {"gap": "ssd-disk-budget-admission", "status": "blocked", "evidence": "full v61w materialization admission remains 0"},
    {"gap": "local-checkpoint-materialization", "status": "blocked", "evidence": "full shard identity verification remains 0"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page hash sweep remains incomplete"},
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "sampled pages cannot run full Mixtral generation"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and external review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "production latency requires full materialized runtime"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61x-hotset-manifest-input", "status": "pass", "reason": "16 planned hotset pages are bound to runtime/source-bound replay rows"},
    {"gate": "v61u-remote-page-hash-input", "status": "pass", "reason": "16 remote page hashes and byte ranges are available"},
    {"gate": "outside-repository-hotset-paths", "status": "pass" if repo_path_errors == 0 else "blocked", "reason": "planned local page paths must resolve outside the repository"},
    {"gate": "sampled-hotset-local-materialization", "status": "pass" if hotset_payload_materialization_ready else "blocked", "reason": f"{local_present_rows}/{len(hotset_rows)} pages are local hash matches"},
    {"gate": "local-hotset-readback", "status": "pass" if readback_ready else "blocked", "reason": f"{verified_bytes} local page bytes read back with matching hashes"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes are stored outside the repository and not committed"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "ssd-disk-budget-admission", "status": "blocked", "reason": "full checkpoint materialization admission remains blocked"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "full shard identity verification remains blocked"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "full model generation is not possible from sampled hotset pages only"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "production latency requires full materialized runtime"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(
    run_dir / "hotset_local_materialization_rows.csv",
    [
        "hotset_materialization_id",
        "hotset_page_id",
        "slot_id",
        "remote_sample_id",
        "model_id",
        "shard_name",
        "shard_page_index",
        "node_type",
        "tensor_role",
        "layer_index",
        "expert_index",
        "planned_local_page_path",
        "planned_local_page_path_inside_repository",
        "remote_page_sha256",
        "local_page_sha256",
        "expected_page_bytes",
        "local_page_bytes",
        "local_page_exists",
        "local_hash_match",
        "materialized_by_v61y",
        "materialization_status",
        "remote_source_url",
        "remote_page_http_status",
        "remote_page_content_range",
        "checkpoint_payload_bytes_persisted_outside_repo",
        "checkpoint_payload_bytes_downloaded_by_v61y",
        "checkpoint_payload_bytes_committed_to_repo",
        "full_checkpoint_materialization_ready",
        "full_safetensors_page_hash_binding_ready",
        "actual_model_generation_ready",
        "route_jump_rows",
    ],
    materialization_rows,
)
write_csv(
    run_dir / "hotset_local_readback_rows.csv",
    [
        "readback_id",
        "hotset_page_id",
        "slot_id",
        "read_mode",
        "readback_bytes",
        "readback_sha256",
        "remote_page_sha256",
        "readback_hash_match",
        "readback_ms",
        "checkpoint_payload_bytes_committed_to_repo",
    ],
    readback_rows,
)
write_csv(
    run_dir / "hotset_local_materialization_metric_rows.csv",
    [
        "metric_id",
        "hotset_page_rows",
        "local_hotset_page_present_rows",
        "local_hotset_hash_match_rows",
        "local_hotset_readback_hash_match_rows",
        "moe_hotset_page_rows",
        "embedding_hotset_page_rows",
        "sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo",
        "checkpoint_payload_bytes_downloaded_by_v61y",
        "checkpoint_payload_bytes_committed_to_repo",
        "hotset_payload_materialization_ready",
        "hotset_readback_verify_ready",
        "full_checkpoint_materialization_ready",
        "materialization_admission_ready",
        "local_checkpoint_materialization_ready",
        "full_safetensors_page_hash_binding_ready",
        "real_100b_open_weight_materialized",
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
    "v61y_hotset_local_materialization_verifier_ready": "1",
    "v61x_hotset_runtime_replay_manifest_ready": v61x_summary["v61x_hotset_runtime_replay_manifest_ready"],
    "v61u_remote_checkpoint_page_hash_sampler_ready": v61u_summary["v61u_remote_checkpoint_page_hash_sampler_ready"],
    "model_id": model_id,
    "hotset_page_rows": str(len(hotset_rows)),
    "local_hotset_page_present_rows": str(local_present_rows),
    "local_hotset_hash_match_rows": str(hash_match_rows),
    "local_hotset_readback_hash_match_rows": str(sum(int(row["readback_hash_match"]) for row in readback_rows)),
    "moe_hotset_page_rows": metric_rows[0]["moe_hotset_page_rows"],
    "embedding_hotset_page_rows": metric_rows[0]["embedding_hotset_page_rows"],
    "sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo": str(persisted_bytes),
    "checkpoint_payload_bytes_downloaded_by_v61y": str(downloaded_by_v61y),
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "hotset_payload_materialization_ready": str(hotset_payload_materialization_ready),
    "hotset_readback_verify_ready": str(readback_ready),
    "full_checkpoint_materialization_ready": "0",
    "materialization_admission_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
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
    "artifact": "v61y_hotset_local_materialization_verifier",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61y_hotset_local_materialization_verifier_ready": 1,
    "materialize_enabled": materialize_enabled,
    "hotset_page_rows": len(hotset_rows),
    "local_hotset_page_present_rows": local_present_rows,
    "local_hotset_hash_match_rows": hash_match_rows,
    "sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo": persisted_bytes,
    "checkpoint_payload_bytes_downloaded_by_v61y": downloaded_by_v61y,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "hotset_payload_materialization_ready": hotset_payload_materialization_ready,
    "hotset_readback_verify_ready": readback_ready,
    "full_checkpoint_materialization_ready": 0,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "full_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61y_hotset_local_materialization_verifier_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61y Hotset Local Materialization Verifier Boundary

This artifact materializes only the bounded v61x/v61u sampled hotset pages
outside the repository and verifies their local readback hashes.

Evidence emitted:

- hotset_page_rows={len(hotset_rows)}
- local_hotset_page_present_rows={local_present_rows}
- local_hotset_hash_match_rows={hash_match_rows}
- local_hotset_readback_hash_match_rows={sum(int(row["readback_hash_match"]) for row in readback_rows)}
- moe_hotset_page_rows={metric_rows[0]["moe_hotset_page_rows"]}
- embedding_hotset_page_rows={metric_rows[0]["embedding_hotset_page_rows"]}
- sampled_hotset_checkpoint_payload_bytes_persisted_outside_repo={persisted_bytes}
- checkpoint_payload_bytes_downloaded_by_v61y={downloaded_by_v61y}
- checkpoint_payload_bytes_committed_to_repo=0
- hotset_payload_materialization_ready={hotset_payload_materialization_ready}
- hotset_readback_verify_ready={readback_ready}

Blocked wording:

- full_checkpoint_materialization_ready=0
- materialization_admission_ready=0
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- real_100b_open_weight_materialized=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is not full Mixtral checkpoint materialization, not full safetensors
page-hash coverage, not real Mixtral generation, and not a near-frontier,
production-latency, or release claim.
"""
(run_dir / "V61Y_HOTSET_LOCAL_MATERIALIZATION_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61y_hotset_local_materialization_verifier_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
