#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61t_local_checkpoint_materialization_verifier"
RUN_ID="${V61T_RUN_ID:-verify_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61T_WAREHOUSE_ROOT:-${V61P_SSD_WAREHOUSE_DIR:-${V61_WAREHOUSE_ROOT:-}}}"

if [[ "${V61T_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61t_local_checkpoint_materialization_verifier_dir: $RUN_DIR"
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
  V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null
fi
V61R_ENABLE_LOCAL_HASH_SWEEP="${V61T_ENABLE_FULL_PAGE_HASH_SWEEP:-0}" \
  V61R_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root_override = sys.argv[5].strip()
results = root / "results"
v61o_dir = results / "v61o_checkpoint_shard_header_probe" / "probe_001"
v61p_dir = results / "v61p_local_ssd_checkpoint_residency_preflight" / "preflight_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61r_dir = results / "v61r_full_page_hash_sweep_plan" / "plan_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"


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


def read_exact(path, start, length):
    with path.open("rb") as handle:
        handle.seek(start)
        return handle.read(length)


v61p_summary = read_csv(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
v61q_summary = read_csv(results / "v61q_real_checkpoint_page_map_summary.csv")[0]
v61r_summary = read_csv(results / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
if v61p_summary.get("v61p_local_ssd_checkpoint_residency_preflight_ready") != "1":
    raise SystemExit("v61t requires v61p_local_ssd_checkpoint_residency_preflight_ready=1")
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61t requires v61q_real_checkpoint_page_map_ready=1")
if v61r_summary.get("v61r_full_page_hash_sweep_plan_ready") != "1":
    raise SystemExit("v61t requires v61r_full_page_hash_sweep_plan_ready=1")

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
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
    (results / "v61r_full_page_hash_sweep_plan_summary.csv", "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv"),
    (results / "v61r_full_page_hash_sweep_plan_decision.csv", "source_v61r/v61r_full_page_hash_sweep_plan_decision.csv"),
    (v61r_dir / "page_hash_sweep_metric_rows.csv", "source_v61r/page_hash_sweep_metric_rows.csv"),
    (v61r_dir / "shard_page_hash_sweep_status_rows.csv", "source_v61r/shard_page_hash_sweep_status_rows.csv"),
    (v61r_dir / "v61r_full_page_hash_sweep_plan_manifest.json", "source_v61r/v61r_full_page_hash_sweep_plan_manifest.json"),
    (v61r_dir / "sha256_manifest.csv", "source_v61r/sha256_manifest.csv"),
    (v61o_dir / "safetensors_header_probe_rows.csv", "source_v61o/safetensors_header_probe_rows.csv"),
    (v61o_dir / "sampled_page_hash_probe_rows.csv", "source_v61o/sampled_page_hash_probe_rows.csv"),
]:
    copy(src, rel)

presence_rows = read_csv(v61p_dir / "local_shard_presence_rows.csv")
download_plan_rows = read_csv(v61p_dir / "checkpoint_download_plan_rows.csv")
warehouse_rows = read_csv(v61p_dir / "ssd_warehouse_probe_rows.csv")
header_rows = read_csv(v61o_dir / "safetensors_header_probe_rows.csv")
sample_rows = read_csv(v61o_dir / "sampled_page_hash_probe_rows.csv")
shard_page_rows = read_csv(v61q_dir / "checkpoint_shard_page_summary_rows.csv")
shard_sweep_rows = read_csv(v61r_dir / "shard_page_hash_sweep_status_rows.csv")

if len(presence_rows) != 59 or len(download_plan_rows) != 59 or len(header_rows) != 59:
    raise SystemExit("v61t expects 59 shard presence/download/header rows")

presence_by_shard = {row["shard_name"]: row for row in presence_rows}
download_by_shard = {row["shard_name"]: row for row in download_plan_rows}
header_by_shard = {row["shard_name"]: row for row in header_rows}
sample_by_shard = {row["shard_name"]: row for row in sample_rows}
page_summary_by_shard = {row["shard_name"]: row for row in shard_page_rows}
sweep_by_shard = {row["shard_name"]: row for row in shard_sweep_rows}

materialization_rows = []
sample_verification_rows = []
existing_shards = 0
size_match_shards = 0
header_match_shards = 0
sample_attempt_rows = 0
sample_match_rows = 0
identity_verified_shards = 0
identity_verified_bytes = 0
full_page_hash_ready_shards = 0
full_page_hash_verified_rows = 0

for shard_index, shard_name in enumerate(sorted(presence_by_shard), start=1):
    presence = presence_by_shard[shard_name]
    download = download_by_shard[shard_name]
    header = header_by_shard[shard_name]
    page_summary = page_summary_by_shard[shard_name]
    sweep = sweep_by_shard[shard_name]
    local_path = Path(presence["target_path"])
    exists = local_path.is_file()
    expected_bytes = int(presence["expected_bytes"])
    actual_bytes = local_path.stat().st_size if exists else 0
    size_match = int(exists and actual_bytes == expected_bytes)
    header_required = int(header["header_probe_bytes_read"])
    header_bytes_read = 0
    local_header_sha256 = ""
    header_hash_match = 0
    header_read_status = "missing-local-shard"
    if exists:
        data = read_exact(local_path, 0, min(header_required, actual_bytes))
        header_bytes_read = len(data)
        local_header_sha256 = sha256_bytes(data) if data else ""
        header_hash_match = int(header_bytes_read == header_required and local_header_sha256 == header["header_sha256"])
        header_read_status = "match" if header_hash_match else "mismatch"
    sampled_required = int(shard_name in sample_by_shard)
    sampled_match = 1 if sampled_required == 0 else 0
    if sampled_required:
        sample = sample_by_shard[shard_name]
        start = int(sample["page_start_byte"])
        end_exclusive = int(sample["page_end_byte"]) + 1
        length = end_exclusive - start
        bytes_read = 0
        local_sample_sha256 = ""
        if exists and actual_bytes >= end_exclusive:
            sample_data = read_exact(local_path, start, length)
            bytes_read = len(sample_data)
            local_sample_sha256 = sha256_bytes(sample_data) if sample_data else ""
            sample_attempt_rows += 1
            sampled_match = int(bytes_read == length and local_sample_sha256 == sample["page_probe_sha256"])
            sample_match_rows += sampled_match
        sample_verification_rows.append(
            {
                "sample_verification_id": f"v61t:{shard_name}:sample:{sample['page_probe_index']}",
                "model_id": model_id,
                "shard_name": shard_name,
                "page_probe_index": sample["page_probe_index"],
                "page_start_byte": sample["page_start_byte"],
                "page_end_byte_exclusive": str(end_exclusive),
                "expected_probe_bytes": sample["page_probe_bytes_read"],
                "bytes_read": str(bytes_read),
                "expected_page_sha256": sample["page_probe_sha256"],
                "local_page_sha256": local_sample_sha256,
                "sampled_page_hash_match": str(sampled_match),
                "local_file_exists": str(int(exists)),
                "checkpoint_payload_bytes_committed_to_repo": "0",
            }
        )
    identity_verified = int(size_match and header_hash_match and sampled_match)
    status = "identity-verified" if identity_verified else "missing-local-shard"
    if exists and not size_match:
        status = "size-mismatch"
    elif size_match and not header_hash_match:
        status = "header-hash-mismatch"
    elif size_match and header_hash_match and sampled_required and not sampled_match:
        status = "sampled-page-hash-mismatch"

    existing_shards += int(exists)
    size_match_shards += size_match
    header_match_shards += header_hash_match
    identity_verified_shards += identity_verified
    identity_verified_bytes += expected_bytes if identity_verified else 0
    full_page_ready = int(sweep["shard_page_hash_coverage_ready"] == "1")
    full_page_hash_ready_shards += full_page_ready
    full_page_hash_verified_rows += int(sweep["verified_page_hash_rows"])

    materialization_rows.append(
        {
            "model_id": model_id,
            "shard_index": str(shard_index),
            "shard_name": shard_name,
            "target_path": str(local_path),
            "source_url": download["source_url"],
            "expected_bytes": str(expected_bytes),
            "actual_bytes": str(actual_bytes),
            "local_file_exists": str(int(exists)),
            "size_match": str(size_match),
            "header_probe_bytes_required": str(header_required),
            "header_bytes_read": str(header_bytes_read),
            "expected_header_sha256": header["header_sha256"],
            "local_header_sha256": local_header_sha256,
            "local_header_hash_match": str(header_hash_match),
            "header_read_status": header_read_status,
            "sampled_page_probe_required": str(sampled_required),
            "sampled_page_hash_match": str(sampled_match),
            "local_identity_verified": str(identity_verified),
            "checkpoint_page_rows": page_summary["checkpoint_page_rows"],
            "full_page_hash_rows_verified": sweep["verified_page_hash_rows"],
            "full_page_hash_coverage_ready": sweep["shard_page_hash_coverage_ready"],
            "materialization_status": status,
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

local_checkpoint_materialization_ready = int(identity_verified_shards == 59 and int(warehouse_rows[0]["warehouse_outside_repo"]) == 1)
full_safetensors_page_hash_binding_ready = int(v61r_summary["full_safetensors_page_hash_binding_ready"])
real_checkpoint_weight_bytes_materialized = identity_verified_bytes if local_checkpoint_materialization_ready else 0
real_100b_open_weight_materialized = local_checkpoint_materialization_ready

write_csv(run_dir / "local_checkpoint_materialization_rows.csv", list(materialization_rows[0].keys()), materialization_rows)
write_csv(run_dir / "sampled_local_page_hash_verification_rows.csv", list(sample_verification_rows[0].keys()), sample_verification_rows)

metric_rows = [
    {
        "model_id": model_id,
        "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
        "checkpoint_shard_rows": "59",
        "total_checkpoint_bytes_expected": v61p_summary["total_checkpoint_bytes_required"],
        "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
        "ssd_warehouse_outside_repo": v61p_summary["ssd_warehouse_outside_repo"],
        "local_existing_shard_rows": str(existing_shards),
        "local_size_match_shard_rows": str(size_match_shards),
        "local_header_hash_match_shard_rows": str(header_match_shards),
        "sampled_remote_page_hash_probe_rows": str(len(sample_rows)),
        "sampled_local_page_probe_rows": str(len(sample_verification_rows)),
        "sampled_local_page_probe_attempted_rows": str(sample_attempt_rows),
        "sampled_local_page_probe_match_rows": str(sample_match_rows),
        "local_identity_verified_shard_rows": str(identity_verified_shards),
        "local_identity_verified_bytes": str(identity_verified_bytes),
        "full_page_hash_coverage_ready_shard_rows": str(full_page_hash_ready_shards),
        "full_page_hash_verified_rows": str(full_page_hash_verified_rows),
        "local_checkpoint_materialization_ready": str(local_checkpoint_materialization_ready),
        "full_safetensors_page_hash_binding_ready": str(full_safetensors_page_hash_binding_ready),
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "real_checkpoint_weight_bytes_materialized": str(real_checkpoint_weight_bytes_materialized),
        "real_100b_open_weight_materialized": str(real_100b_open_weight_materialized),
        "actual_model_generation_ready": "0",
    }
]
write_csv(run_dir / "local_checkpoint_materialization_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

gap_rows = [
    ("warehouse-outside-repository", "ready" if v61p_summary["ssd_warehouse_outside_repo"] == "1" else "blocked", "checkpoint warehouse must remain outside the repository"),
    ("local-shard-size-identity", "ready" if size_match_shards == 59 else "blocked", "all 59 shards must exist with exact expected byte lengths"),
    ("local-header-hash-binding", "ready" if header_match_shards == 59 else "blocked", "each local shard header must match the remote safetensors header hash"),
    ("sampled-local-page-hash-binding", "ready" if sample_match_rows == len(sample_rows) else "blocked", "local sampled page hashes must match v61o remote sampled probes"),
    ("local-checkpoint-materialization", "ready" if local_checkpoint_materialization_ready else "blocked", "all shards must pass size, header, and sampled page identity checks"),
    ("full-safetensors-page-hash-binding", "ready" if full_safetensors_page_hash_binding_ready else "blocked", "full page hash binding requires v61r verification for every page"),
    ("real-model-generation", "blocked", "v61t does not execute real Mixtral generation"),
    ("near-frontier-quality", "blocked", "materialization identity is not a quality result"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "materialization_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61p_local_ssd_checkpoint_residency_preflight_ready": v61p_summary["v61p_local_ssd_checkpoint_residency_preflight_ready"],
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "v61r_full_page_hash_sweep_plan_ready": v61r_summary["v61r_full_page_hash_sweep_plan_ready"],
    "model_id": model_id,
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "checkpoint_shard_rows": "59",
    "total_checkpoint_bytes_expected": v61p_summary["total_checkpoint_bytes_required"],
    "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
    "ssd_warehouse_outside_repo": v61p_summary["ssd_warehouse_outside_repo"],
    "local_existing_shard_rows": str(existing_shards),
    "local_size_match_shard_rows": str(size_match_shards),
    "local_header_hash_match_shard_rows": str(header_match_shards),
    "sampled_remote_page_hash_probe_rows": str(len(sample_rows)),
    "sampled_local_page_probe_rows": str(len(sample_verification_rows)),
    "sampled_local_page_probe_attempted_rows": str(sample_attempt_rows),
    "sampled_local_page_probe_match_rows": str(sample_match_rows),
    "local_identity_verified_shard_rows": str(identity_verified_shards),
    "local_identity_verified_bytes": str(identity_verified_bytes),
    "full_page_hash_coverage_ready_shard_rows": str(full_page_hash_ready_shards),
    "full_page_hash_verified_rows": str(full_page_hash_verified_rows),
    "local_checkpoint_materialization_ready": str(local_checkpoint_materialization_ready),
    "full_safetensors_page_hash_binding_ready": str(full_safetensors_page_hash_binding_ready),
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": str(real_checkpoint_weight_bytes_materialized),
    "real_100b_open_weight_materialized": str(real_100b_open_weight_materialized),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61p-local-ssd-residency-preflight-input", "pass", "v61p local shard presence and warehouse plan are bound"),
    ("v61q-real-checkpoint-page-map-input", "pass", "v61q real checkpoint page map is bound"),
    ("v61r-full-page-hash-sweep-plan-input", "pass", "v61r full page-hash sweep plan is bound"),
    ("warehouse-outside-repository", "pass" if v61p_summary["ssd_warehouse_outside_repo"] == "1" else "blocked", "warehouse path must stay outside the git repository"),
    ("materialization-identity-verifier", "pass", "size, header-hash, and sampled-page-hash checks are emitted for every shard"),
    ("manifest-only-no-repo-payload", "pass", "v61t writes only metadata and hashes into the repository artifact path"),
    ("local-checkpoint-materialization", "pass" if local_checkpoint_materialization_ready else "blocked", "requires all shards to pass identity verification"),
    ("full-safetensors-page-hash-binding", "pass" if full_safetensors_page_hash_binding_ready else "blocked", "requires completed v61r page hash coverage"),
    ("real-model-generation", "blocked", "real Mixtral generation is not executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61T_LOCAL_CHECKPOINT_MATERIALIZATION_VERIFIER_BOUNDARY.md").write_text(
    "# v61t Local Checkpoint Materialization Verifier Boundary\n\n"
    "This layer promotes the v61p local SSD shard-presence preflight into an identity verifier for any outside-repository checkpoint shards already present on the host. "
    "It checks exact byte length, the safetensors header hash from v61o, and v61o sampled page hashes when a sampled probe exists. "
    "It never downloads checkpoint shards and never commits checkpoint payload bytes to the repository.\n\n"
    f"- checkpoint_shard_rows=59\n"
    f"- total_checkpoint_bytes_expected={v61p_summary['total_checkpoint_bytes_required']}\n"
    f"- local_existing_shard_rows={existing_shards}\n"
    f"- local_size_match_shard_rows={size_match_shards}\n"
    f"- local_header_hash_match_shard_rows={header_match_shards}\n"
    f"- sampled_local_page_probe_match_rows={sample_match_rows}\n"
    f"- local_identity_verified_shard_rows={identity_verified_shards}\n"
    f"- local_checkpoint_materialization_ready={local_checkpoint_materialization_ready}\n"
    f"- full_safetensors_page_hash_binding_ready={full_safetensors_page_hash_binding_ready}\n"
    "- checkpoint_payload_bytes_committed_to_repo=0\n"
    f"- real_checkpoint_weight_bytes_materialized={real_checkpoint_weight_bytes_materialized}\n"
    f"- real_100b_open_weight_materialized={real_100b_open_weight_materialized}\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: local checkpoint materialization identity verifier and current local shard identity status. "
    "Blocked wording: completed checkpoint materialization unless all 59 shards pass identity verification, full page-hash coverage unless every v61q page is hashed, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61t-local-checkpoint-materialization-verifier",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61t_local_checkpoint_materialization_verifier_ready": 1,
    "v61p_summary_sha256": sha256(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    "v61q_summary_sha256": sha256(results / "v61q_real_checkpoint_page_map_summary.csv"),
    "v61r_summary_sha256": sha256(results / "v61r_full_page_hash_sweep_plan_summary.csv"),
    "checkpoint_shard_rows": 59,
    "total_checkpoint_bytes_expected": int(v61p_summary["total_checkpoint_bytes_required"]),
    "local_existing_shard_rows": existing_shards,
    "local_size_match_shard_rows": size_match_shards,
    "local_header_hash_match_shard_rows": header_match_shards,
    "sampled_remote_page_hash_probe_rows": len(sample_rows),
    "sampled_local_page_probe_match_rows": sample_match_rows,
    "local_identity_verified_shard_rows": identity_verified_shards,
    "local_identity_verified_bytes": identity_verified_bytes,
    "local_checkpoint_materialization_ready": local_checkpoint_materialization_ready,
    "full_safetensors_page_hash_binding_ready": full_safetensors_page_hash_binding_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_checkpoint_weight_bytes_materialized": real_checkpoint_weight_bytes_materialized,
    "real_100b_open_weight_materialized": real_100b_open_weight_materialized,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61t_local_checkpoint_materialization_verifier_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "local_checkpoint_materialization_rows.csv",
    "sampled_local_page_hash_verification_rows.csv",
    "local_checkpoint_materialization_metric_rows.csv",
    "materialization_gap_rows.csv",
    "V61T_LOCAL_CHECKPOINT_MATERIALIZATION_VERIFIER_BOUNDARY.md",
    "v61t_local_checkpoint_materialization_verifier_manifest.json",
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
    "source_v61q/v61q_real_checkpoint_page_map_manifest.json",
    "source_v61q/sha256_manifest.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_decision.csv",
    "source_v61r/page_hash_sweep_metric_rows.csv",
    "source_v61r/shard_page_hash_sweep_status_rows.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_manifest.json",
    "source_v61r/sha256_manifest.csv",
    "source_v61o/safetensors_header_probe_rows.csv",
    "source_v61o/sampled_page_hash_probe_rows.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61t_local_checkpoint_materialization_verifier_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
