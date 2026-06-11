#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61r_full_page_hash_sweep_plan"
RUN_ID="${V61R_RUN_ID:-plan_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61R_WAREHOUSE_ROOT:-${V61T_WAREHOUSE_ROOT:-${V61P_SSD_WAREHOUSE_DIR:-${V61_WAREHOUSE_ROOT:-}}}}"

if [[ "${V61R_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61r_full_page_hash_sweep_plan_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61Q_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61q_real_checkpoint_page_map.sh" >/dev/null
if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61P_SSD_WAREHOUSE_DIR="$WAREHOUSE_ROOT_OVERRIDE" V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null
else
  V61P_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root_override = sys.argv[5].strip()
results = root / "results"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61p_dir = results / "v61p_local_ssd_checkpoint_residency_preflight" / "preflight_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"
enable_local_hash_sweep = os.environ.get("V61R_ENABLE_LOCAL_HASH_SWEEP", "0") == "1"


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


v61q_summary = read_csv(results / "v61q_real_checkpoint_page_map_summary.csv")[0]
v61p_summary = read_csv(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61r requires v61q_real_checkpoint_page_map_ready=1")
if v61p_summary.get("v61p_local_ssd_checkpoint_residency_preflight_ready") != "1":
    raise SystemExit("v61r requires v61p_local_ssd_checkpoint_residency_preflight_ready=1")

for src, rel in [
    (results / "v61q_real_checkpoint_page_map_summary.csv", "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (results / "v61q_real_checkpoint_page_map_decision.csv", "source_v61q/v61q_real_checkpoint_page_map_decision.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
    (results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    (results / "v61p_local_ssd_checkpoint_residency_preflight_decision.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_decision.csv"),
    (v61p_dir / "ssd_warehouse_probe_rows.csv", "source_v61p/ssd_warehouse_probe_rows.csv"),
    (v61p_dir / "checkpoint_download_plan_rows.csv", "source_v61p/checkpoint_download_plan_rows.csv"),
    (v61p_dir / "local_shard_presence_rows.csv", "source_v61p/local_shard_presence_rows.csv"),
    (v61p_dir / "v61p_local_ssd_checkpoint_residency_preflight_manifest.json", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_manifest.json"),
    (v61p_dir / "sha256_manifest.csv", "source_v61p/sha256_manifest.csv"),
]:
    copy(src, rel)

page_rows = read_csv(v61q_dir / "checkpoint_unique_page_rows.csv")
shard_page_rows = read_csv(v61q_dir / "checkpoint_shard_page_summary_rows.csv")
presence_rows = read_csv(v61p_dir / "local_shard_presence_rows.csv")
download_plan_rows = read_csv(v61p_dir / "checkpoint_download_plan_rows.csv")
sampled_probe_rows = read_csv(v61q_dir / "source_v61o/sampled_page_hash_probe_rows.csv")

if len(page_rows) != int(v61q_summary["checkpoint_unique_page_rows"]):
    raise SystemExit("v61r page row count differs from v61q summary")
if len(presence_rows) != 59 or len(download_plan_rows) != 59:
    raise SystemExit("v61r expects 59 v61p shard presence/download rows")

presence_by_shard = {row["shard_name"]: row for row in presence_rows}
download_by_shard = {row["shard_name"]: row for row in download_plan_rows}
page_count_by_shard = {row["shard_name"]: int(row["checkpoint_page_rows"]) for row in shard_page_rows}

plan_fields = [
    "page_hash_task_id",
    "source_page_id",
    "model_id",
    "shard_name",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_bytes_in_shard",
    "local_shard_path",
    "expected_shard_bytes",
    "local_shard_exists",
    "local_shard_size_match",
    "local_shard_resident",
    "expected_etag",
    "task_status",
    "hash_algorithm",
    "local_hash_sweep_enabled",
    "page_hash_verified",
    "checkpoint_payload_bytes_committed_to_repo",
]
verification_fields = [
    "page_hash_task_id",
    "source_page_id",
    "model_id",
    "shard_name",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_bytes_hashed",
    "page_sha256",
    "hash_algorithm",
    "local_hash_verified",
    "checkpoint_payload_bytes_committed_to_repo",
]

plan_rows_written = 0
ready_to_hash_rows = 0
blocked_missing_local_rows = 0
verified_page_hash_rows = 0
verified_page_hash_bytes = 0
local_resident_page_rows = 0

open_files = {}
try:
    with (run_dir / "page_hash_sweep_plan_rows.csv").open("w", newline="", encoding="utf-8") as plan_handle, (
        run_dir / "local_page_hash_verification_rows.csv"
    ).open("w", newline="", encoding="utf-8") as verify_handle:
        plan_writer = csv.DictWriter(plan_handle, fieldnames=plan_fields, lineterminator="\n")
        verify_writer = csv.DictWriter(verify_handle, fieldnames=verification_fields, lineterminator="\n")
        plan_writer.writeheader()
        verify_writer.writeheader()

        for page in page_rows:
            shard_name = page["shard_name"]
            presence = presence_by_shard[shard_name]
            download = download_by_shard[shard_name]
            local_resident = presence["local_shard_resident"] == "1"
            if local_resident:
                local_resident_page_rows += 1
            if local_resident and enable_local_hash_sweep:
                task_status = "hashed"
            elif local_resident:
                task_status = "ready-to-hash"
            else:
                task_status = "blocked-missing-local-shard"
            if task_status == "ready-to-hash":
                ready_to_hash_rows += 1
            if task_status == "blocked-missing-local-shard":
                blocked_missing_local_rows += 1

            page_hash_task_id = f"v61r:{shard_name}:page:{int(page['shard_page_index']):08d}"
            plan_writer.writerow(
                {
                    "page_hash_task_id": page_hash_task_id,
                    "source_page_id": page["page_id"],
                    "model_id": model_id,
                    "shard_name": shard_name,
                    "shard_page_index": page["shard_page_index"],
                    "page_start_byte": page["page_start_byte"],
                    "page_end_byte_exclusive": page["page_end_byte_exclusive"],
                    "page_bytes_in_shard": page["page_bytes_in_shard"],
                    "local_shard_path": presence["target_path"],
                    "expected_shard_bytes": presence["expected_bytes"],
                    "local_shard_exists": presence["local_file_exists"],
                    "local_shard_size_match": presence["size_match"],
                    "local_shard_resident": presence["local_shard_resident"],
                    "expected_etag": download["expected_etag"],
                    "task_status": task_status,
                    "hash_algorithm": "sha256",
                    "local_hash_sweep_enabled": str(int(enable_local_hash_sweep)),
                    "page_hash_verified": "1" if task_status == "hashed" else "0",
                    "checkpoint_payload_bytes_committed_to_repo": "0",
                }
            )
            plan_rows_written += 1

            if task_status == "hashed":
                local_path = Path(presence["target_path"])
                handle = open_files.get(shard_name)
                if handle is None:
                    handle = local_path.open("rb")
                    open_files[shard_name] = handle
                start = int(page["page_start_byte"])
                end = int(page["page_end_byte_exclusive"])
                handle.seek(start)
                data = handle.read(end - start)
                if len(data) != end - start:
                    raise SystemExit(f"v61r failed to read full page for {page_hash_task_id}")
                verify_writer.writerow(
                    {
                        "page_hash_task_id": page_hash_task_id,
                        "source_page_id": page["page_id"],
                        "model_id": model_id,
                        "shard_name": shard_name,
                        "shard_page_index": page["shard_page_index"],
                        "page_start_byte": page["page_start_byte"],
                        "page_end_byte_exclusive": page["page_end_byte_exclusive"],
                        "page_bytes_hashed": str(len(data)),
                        "page_sha256": sha256_bytes(data),
                        "hash_algorithm": "sha256",
                        "local_hash_verified": "1",
                        "checkpoint_payload_bytes_committed_to_repo": "0",
                    }
                )
                verified_page_hash_rows += 1
                verified_page_hash_bytes += len(data)
finally:
    for handle in open_files.values():
        handle.close()

sample_binding_fields = [
    "sample_binding_id",
    "model_id",
    "shard_name",
    "remote_probe_start_byte",
    "remote_probe_end_byte_exclusive",
    "remote_probe_bytes_read",
    "remote_probe_sha256",
    "overlap_page_id",
    "overlap_shard_page_index",
    "overlap_start_byte",
    "overlap_end_byte_exclusive",
    "overlap_bytes",
    "remote_sample_hash_binding_ready",
    "full_page_hash_verified",
]
sample_binding_rows = []
page_rows_by_shard = defaultdict(list)
for page in page_rows:
    page_rows_by_shard[page["shard_name"]].append(page)
for sample_index, sample in enumerate(sampled_probe_rows):
    shard_name = sample["shard_name"]
    sample_start = int(sample["page_start_byte"])
    sample_end = int(sample["page_end_byte"]) + 1
    for page in page_rows_by_shard[shard_name]:
        page_start = int(page["page_start_byte"])
        page_end = int(page["page_end_byte_exclusive"])
        overlap_start = max(sample_start, page_start)
        overlap_end = min(sample_end, page_end)
        if overlap_start < overlap_end:
            sample_binding_rows.append(
                {
                    "sample_binding_id": f"v61r:sample:{sample_index:03d}:page:{page['shard_page_index']}",
                    "model_id": model_id,
                    "shard_name": shard_name,
                    "remote_probe_start_byte": str(sample_start),
                    "remote_probe_end_byte_exclusive": str(sample_end),
                    "remote_probe_bytes_read": sample["page_probe_bytes_read"],
                    "remote_probe_sha256": sample["page_probe_sha256"],
                    "overlap_page_id": page["page_id"],
                    "overlap_shard_page_index": page["shard_page_index"],
                    "overlap_start_byte": str(overlap_start),
                    "overlap_end_byte_exclusive": str(overlap_end),
                    "overlap_bytes": str(overlap_end - overlap_start),
                    "remote_sample_hash_binding_ready": sample["sampled_page_hash_binding_ready"],
                    "full_page_hash_verified": "0",
                }
            )
write_csv(run_dir / "sampled_remote_page_hash_binding_rows.csv", sample_binding_fields, sample_binding_rows)

shard_status_rows = []
for shard_name in sorted(presence_by_shard):
    presence = presence_by_shard[shard_name]
    page_rows_for_shard = page_count_by_shard[shard_name]
    resident = presence["local_shard_resident"] == "1"
    verified_for_shard = page_rows_for_shard if (resident and enable_local_hash_sweep) else 0
    shard_status_rows.append(
        {
            "model_id": model_id,
            "shard_name": shard_name,
            "target_path": presence["target_path"],
            "expected_bytes": presence["expected_bytes"],
            "actual_bytes": presence["actual_bytes"],
            "local_shard_exists": presence["local_file_exists"],
            "local_shard_resident": presence["local_shard_resident"],
            "checkpoint_page_rows": str(page_rows_for_shard),
            "planned_page_hash_rows": str(page_rows_for_shard),
            "verified_page_hash_rows": str(verified_for_shard),
            "shard_page_hash_coverage_ready": str(int(verified_for_shard == page_rows_for_shard and page_rows_for_shard > 0)),
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "shard_page_hash_sweep_status_rows.csv", list(shard_status_rows[0].keys()), shard_status_rows)

full_page_hash_ready = int(plan_rows_written > 0 and verified_page_hash_rows == plan_rows_written)
metric_rows = [
    {
        "model_id": model_id,
        "checkpoint_unique_page_rows": str(plan_rows_written),
        "page_hash_sweep_plan_rows": str(plan_rows_written),
        "local_resident_page_rows": str(local_resident_page_rows),
        "ready_to_hash_page_rows": str(ready_to_hash_rows),
        "blocked_missing_local_shard_page_rows": str(blocked_missing_local_rows),
        "verified_page_hash_rows": str(verified_page_hash_rows),
        "verified_page_hash_bytes": str(verified_page_hash_bytes),
        "sampled_remote_page_hash_probe_rows": str(len(sampled_probe_rows)),
        "sampled_remote_page_hash_page_overlap_rows": str(len(sample_binding_rows)),
        "local_hash_sweep_enabled": str(int(enable_local_hash_sweep)),
        "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
        "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
        "full_safetensors_page_hash_binding_ready": str(full_page_hash_ready),
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "page_hash_sweep_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

gap_rows = [
    ("full-page-hash-sweep-plan", "ready", "all v61q checkpoint pages have page-hash task rows"),
    ("sampled-remote-page-hash-binding", "ready", "v61o sampled remote page probes are bound to overlapping v61q page rows"),
    ("local-ssd-checkpoint-residency", "ready" if v61p_summary["local_checkpoint_residency_ready"] == "1" else "blocked", "all shards must be locally resident before the full local hash sweep can run"),
    ("full-safetensors-page-hash-binding", "ready" if full_page_hash_ready else "blocked", "full coverage requires hashing every local checkpoint page"),
    ("real-model-generation", "blocked", "v61r does not execute real Mixtral generation"),
    ("near-frontier-quality", "blocked", "page hash coverage is not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

summary = {
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "v61p_local_ssd_checkpoint_residency_preflight_ready": v61p_summary["v61p_local_ssd_checkpoint_residency_preflight_ready"],
    "model_id": model_id,
    "checkpoint_shard_rows": v61q_summary["checkpoint_shard_rows"],
    "checkpoint_unique_page_rows": str(plan_rows_written),
    "page_hash_sweep_plan_rows": str(plan_rows_written),
    "local_resident_page_rows": str(local_resident_page_rows),
    "ready_to_hash_page_rows": str(ready_to_hash_rows),
    "blocked_missing_local_shard_page_rows": str(blocked_missing_local_rows),
    "verified_page_hash_rows": str(verified_page_hash_rows),
    "verified_page_hash_bytes": str(verified_page_hash_bytes),
    "sampled_remote_page_hash_probe_rows": str(len(sampled_probe_rows)),
    "sampled_remote_page_hash_page_overlap_rows": str(len(sample_binding_rows)),
    "local_hash_sweep_enabled": str(int(enable_local_hash_sweep)),
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
    "local_checkpoint_residency_ready": v61p_summary["local_checkpoint_residency_ready"],
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_ready),
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
    ("v61q-real-checkpoint-page-map-input", "pass", "v61q checkpoint page map is bound"),
    ("v61p-local-ssd-residency-preflight-input", "pass", "v61p local shard presence and warehouse plan are bound"),
    ("full-page-hash-sweep-plan", "pass", f"page_hash_sweep_plan_rows={plan_rows_written}"),
    ("sampled-remote-page-hash-binding", "pass", f"sampled_probe_rows={len(sampled_probe_rows)}; overlap_rows={len(sample_binding_rows)}"),
    ("manifest-only-no-repo-payload", "pass", "v61r writes only hashes/plans/metadata into the repository artifact path"),
    ("local-ssd-checkpoint-residency", "pass" if v61p_summary["local_checkpoint_residency_ready"] == "1" else "blocked", "requires all checkpoint shards in the outside-repository warehouse"),
    ("full-safetensors-page-hash-binding", "pass" if full_page_hash_ready else "blocked", "requires a completed local hash row for every checkpoint page"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61R_FULL_PAGE_HASH_SWEEP_PLAN_BOUNDARY.md").write_text(
    "# v61r Full Page Hash Sweep Plan Boundary\n\n"
    "This layer converts the v61q real checkpoint page map into a full safetensors page-hash sweep plan and binds the v61p local SSD shard-presence audit. "
    "If `V61R_ENABLE_LOCAL_HASH_SWEEP=1` and local shards are resident outside the repository, it hashes resident checkpoint pages. "
    "On the current host no shards are locally resident, so full page-hash coverage remains blocked. The runner never downloads checkpoint shards and never commits checkpoint payload bytes to the repository.\n\n"
    f"- checkpoint_shard_rows={v61q_summary['checkpoint_shard_rows']}\n"
    f"- checkpoint_unique_page_rows={plan_rows_written}\n"
    f"- page_hash_sweep_plan_rows={plan_rows_written}\n"
    f"- local_resident_page_rows={local_resident_page_rows}\n"
    f"- blocked_missing_local_shard_page_rows={blocked_missing_local_rows}\n"
    f"- verified_page_hash_rows={verified_page_hash_rows}\n"
    f"- sampled_remote_page_hash_probe_rows={len(sampled_probe_rows)}\n"
    f"- sampled_remote_page_hash_page_overlap_rows={len(sample_binding_rows)}\n"
    f"- local_checkpoint_residency_ready={v61p_summary['local_checkpoint_residency_ready']}\n"
    f"- warehouse_root_override_supplied={int(bool(warehouse_root_override))}\n"
    f"- ssd_warehouse_path={v61p_summary['ssd_warehouse_path']}\n"
    f"- full_safetensors_page_hash_binding_ready={full_page_hash_ready}\n"
    "- checkpoint_payload_bytes_committed_to_repo=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- real_100b_open_weight_materialized=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: full page-hash sweep plan and sampled remote page-hash binding. "
    "Blocked wording: completed full page-hash coverage unless every local checkpoint page is hashed, completed local checkpoint residency, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61r-full-page-hash-sweep-plan",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61r_full_page_hash_sweep_plan_ready": 1,
    "v61q_summary_sha256": sha256(results / "v61q_real_checkpoint_page_map_summary.csv"),
    "v61p_summary_sha256": sha256(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    "checkpoint_shard_rows": int(v61q_summary["checkpoint_shard_rows"]),
    "checkpoint_unique_page_rows": plan_rows_written,
    "page_hash_sweep_plan_rows": plan_rows_written,
    "local_resident_page_rows": local_resident_page_rows,
    "ready_to_hash_page_rows": ready_to_hash_rows,
    "blocked_missing_local_shard_page_rows": blocked_missing_local_rows,
    "verified_page_hash_rows": verified_page_hash_rows,
    "verified_page_hash_bytes": verified_page_hash_bytes,
    "sampled_remote_page_hash_probe_rows": len(sampled_probe_rows),
    "sampled_remote_page_hash_page_overlap_rows": len(sample_binding_rows),
    "local_hash_sweep_enabled": int(enable_local_hash_sweep),
    "warehouse_root_override_supplied": int(bool(warehouse_root_override)),
    "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
    "local_checkpoint_residency_ready": int(v61p_summary["local_checkpoint_residency_ready"]),
    "full_safetensors_page_hash_binding_ready": full_page_hash_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_checkpoint_weight_bytes_materialized": 0,
    "real_100b_open_weight_materialized": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61r_full_page_hash_sweep_plan_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "page_hash_sweep_plan_rows.csv",
    "local_page_hash_verification_rows.csv",
    "sampled_remote_page_hash_binding_rows.csv",
    "shard_page_hash_sweep_status_rows.csv",
    "page_hash_sweep_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61R_FULL_PAGE_HASH_SWEEP_PLAN_BOUNDARY.md",
    "v61r_full_page_hash_sweep_plan_manifest.json",
    "source_v61q/v61q_real_checkpoint_page_map_summary.csv",
    "source_v61q/v61q_real_checkpoint_page_map_decision.csv",
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_decision.csv",
    "source_v61p/ssd_warehouse_probe_rows.csv",
    "source_v61p/checkpoint_download_plan_rows.csv",
    "source_v61p/local_shard_presence_rows.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_manifest.json",
    "source_v61p/sha256_manifest.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61r_full_page_hash_sweep_plan_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
