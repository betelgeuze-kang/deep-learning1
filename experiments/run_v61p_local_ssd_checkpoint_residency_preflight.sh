#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61p_local_ssd_checkpoint_residency_preflight"
RUN_ID="${V61P_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61P_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61p_local_ssd_checkpoint_residency_preflight_dir: $RUN_DIR"
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
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61o_dir = results / "v61o_checkpoint_shard_header_probe" / "probe_001"

model_id = "mistralai/Mixtral-8x22B-v0.1"
default_warehouse = Path.home() / ".cache" / "deep_learning_v61p_mixtral_8x22b_warehouse"
warehouse_path = Path(os.environ.get("V61P_SSD_WAREHOUSE_DIR", str(default_warehouse))).expanduser().resolve()
reserve_bytes = int(os.environ.get("V61P_SSD_RESERVE_BYTES", str(32 * 1024 * 1024 * 1024)))
create_warehouse_dir = os.environ.get("V61P_CREATE_WAREHOUSE_DIR", "0") == "1"
allow_repo_warehouse = os.environ.get("V61P_ALLOW_REPO_WAREHOUSE", "0") == "1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def is_relative_to(path, base):
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def nearest_existing_parent(path):
    current = path
    while not current.exists() and current != current.parent:
        current = current.parent
    return current


def df_probe(path):
    existing = nearest_existing_parent(path)
    usage = shutil.disk_usage(existing)
    row = {
        "probe_path": str(path),
        "existing_probe_path": str(existing),
        "filesystem": "",
        "fstype": "",
        "total_bytes": str(usage.total),
        "used_bytes": str(usage.used),
        "available_bytes": str(usage.free),
        "mount_point": "",
        "df_probe_ready": "1",
    }
    try:
        output = subprocess.check_output(
            ["df", "-B1", "-T", str(existing)],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip().splitlines()
        if len(output) >= 2:
            parts = output[-1].split(maxsplit=6)
            if len(parts) == 7:
                row.update(
                    {
                        "filesystem": parts[0],
                        "fstype": parts[1],
                        "total_bytes": parts[2],
                        "used_bytes": parts[3],
                        "available_bytes": parts[4],
                        "mount_point": parts[6],
                    }
                )
    except Exception:
        pass
    return row


v61o_summary = read_csv(results / "v61o_checkpoint_shard_header_probe_summary.csv")[0]
if v61o_summary.get("v61o_checkpoint_shard_header_probe_ready") != "1":
    raise SystemExit("v61p requires v61o_checkpoint_shard_header_probe_ready=1")

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

http_rows = read_csv(v61o_dir / "checkpoint_shard_http_identity_rows.csv")
if len(http_rows) != 59:
    raise SystemExit("v61p requires the v61o 59-shard identity table")

warehouse_inside_repo = int(is_relative_to(warehouse_path, root))
warehouse_outside_repo = int(warehouse_inside_repo == 0)
if warehouse_inside_repo and not allow_repo_warehouse:
    warehouse_allowed = 0
else:
    warehouse_allowed = 1

if create_warehouse_dir and warehouse_allowed:
    warehouse_path.mkdir(parents=True, exist_ok=True)

disk_row = df_probe(warehouse_path)
available_bytes = int(disk_row["available_bytes"])
total_checkpoint_bytes_required = sum(int(row["content_length"]) for row in http_rows)
required_with_reserve = total_checkpoint_bytes_required + reserve_bytes
disk_budget_pass = int(available_bytes >= required_with_reserve)

warehouse_rows = [
    {
        "model_id": model_id,
        "warehouse_path": str(warehouse_path),
        "warehouse_parent": str(nearest_existing_parent(warehouse_path)),
        "warehouse_dir_exists": str(int(warehouse_path.is_dir())),
        "warehouse_created_by_v61p": str(int(create_warehouse_dir and warehouse_allowed)),
        "warehouse_inside_repo": str(warehouse_inside_repo),
        "warehouse_outside_repo": str(warehouse_outside_repo),
        "warehouse_allowed": str(warehouse_allowed),
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "checkpoint_payload_bytes_downloaded_by_v61p": "0",
        "repo_root": str(root),
    }
]
write_csv(run_dir / "ssd_warehouse_probe_rows.csv", list(warehouse_rows[0].keys()), warehouse_rows)
write_csv(run_dir / "ssd_disk_budget_rows.csv", list(disk_row.keys()), [disk_row])

requirement_rows = [
    {
        "requirement": "checkpoint_shards",
        "required_rows": str(len(http_rows)),
        "required_bytes": str(total_checkpoint_bytes_required),
        "reserve_bytes": str(reserve_bytes),
        "required_with_reserve_bytes": str(required_with_reserve),
        "available_bytes": str(available_bytes),
        "status": "pass" if disk_budget_pass else "blocked",
        "reason": "available SSD bytes cover checkpoint plus reserve" if disk_budget_pass else "available SSD bytes do not cover checkpoint plus reserve",
    },
    {
        "requirement": "warehouse_outside_repository",
        "required_rows": "1",
        "required_bytes": "0",
        "reserve_bytes": "0",
        "required_with_reserve_bytes": "0",
        "available_bytes": str(available_bytes),
        "status": "pass" if warehouse_outside_repo else "blocked",
        "reason": "warehouse path is outside the git repository" if warehouse_outside_repo else "warehouse path is inside the git repository",
    },
    {
        "requirement": "no_repo_weight_payload",
        "required_rows": "1",
        "required_bytes": "0",
        "reserve_bytes": "0",
        "required_with_reserve_bytes": "0",
        "available_bytes": str(available_bytes),
        "status": "pass",
        "reason": "v61p writes only metadata and never commits checkpoint payload bytes",
    },
]
write_csv(run_dir / "checkpoint_residency_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

download_plan_rows = []
presence_rows = []
for idx, row in enumerate(http_rows, start=1):
    shard_name = row["shard_name"]
    expected_bytes = int(row["content_length"])
    local_path = warehouse_path / shard_name
    exists = local_path.is_file()
    actual_bytes = local_path.stat().st_size if exists else 0
    size_match = int(exists and actual_bytes == expected_bytes)
    download_plan_rows.append(
        {
            "model_id": model_id,
            "shard_index": str(idx),
            "shard_name": shard_name,
            "source_url": row["source_url"],
            "expected_bytes": str(expected_bytes),
            "expected_etag": row["etag"],
            "warehouse_path": str(warehouse_path),
            "target_path": str(local_path),
            "download_command": f"huggingface-cli download {model_id} {shard_name} --local-dir {warehouse_path}",
            "resume_supported": "1",
            "downloaded_by_v61p": "0",
        }
    )
    presence_rows.append(
        {
            "model_id": model_id,
            "shard_index": str(idx),
            "shard_name": shard_name,
            "target_path": str(local_path),
            "expected_bytes": str(expected_bytes),
            "actual_bytes": str(actual_bytes),
            "local_file_exists": str(int(exists)),
            "size_match": str(size_match),
            "etag": row["etag"],
            "local_shard_resident": str(size_match),
            "hash_verified": "0",
            "hash_verification_reason": "full shard hash not computed in preflight",
        }
    )

write_csv(run_dir / "checkpoint_download_plan_rows.csv", list(download_plan_rows[0].keys()), download_plan_rows)
write_csv(run_dir / "local_shard_presence_rows.csv", list(presence_rows[0].keys()), presence_rows)

resident_rows = sum(1 for row in presence_rows if row["local_shard_resident"] == "1")
resident_bytes = sum(int(row["actual_bytes"]) for row in presence_rows if row["local_shard_resident"] == "1")
local_checkpoint_residency_ready = int(
    resident_rows == len(http_rows)
    and disk_budget_pass
    and warehouse_outside_repo
    and warehouse_allowed
)

gap_rows = [
    ("local-ssd-checkpoint-residency", "ready" if local_checkpoint_residency_ready else "blocked", "all 59 shards must be present outside the repository with enough SSD budget"),
    ("full-safetensors-page-hash-binding", "blocked", "v61p does not hash every page of every local shard"),
    ("real-model-generation", "blocked", "v61p does not execute real Mixtral generation"),
    ("near-frontier-quality", "blocked", "checkpoint residency preflight is not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

summary = {
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "v61o_checkpoint_shard_header_probe_ready": v61o_summary["v61o_checkpoint_shard_header_probe_ready"],
    "model_id": model_id,
    "checkpoint_shard_rows": str(len(http_rows)),
    "total_checkpoint_bytes_required": str(total_checkpoint_bytes_required),
    "ssd_reserve_bytes": str(reserve_bytes),
    "required_with_reserve_bytes": str(required_with_reserve),
    "available_ssd_bytes": str(available_bytes),
    "ssd_disk_budget_pass": str(disk_budget_pass),
    "ssd_warehouse_path": str(warehouse_path),
    "ssd_warehouse_outside_repo": str(warehouse_outside_repo),
    "ssd_warehouse_dir_exists": str(int(warehouse_path.is_dir())),
    "checkpoint_download_plan_rows": str(len(download_plan_rows)),
    "local_shard_presence_rows": str(len(presence_rows)),
    "local_present_shard_rows": str(sum(int(row["local_file_exists"]) for row in presence_rows)),
    "local_complete_shard_rows": str(resident_rows),
    "local_resident_checkpoint_bytes": str(resident_bytes),
    "local_checkpoint_residency_ready": str(local_checkpoint_residency_ready),
    "checkpoint_payload_bytes_downloaded_by_v61p": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_safetensors_page_hash_binding_ready": "0",
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
    ("v61o-checkpoint-shard-header-probe-input", "pass", "v61o shard identity/header/sample-page evidence is bound"),
    ("ssd-warehouse-outside-repository", "pass" if warehouse_outside_repo else "blocked", f"warehouse_path={warehouse_path}"),
    ("checkpoint-download-plan", "pass", f"download_plan_rows={len(download_plan_rows)}"),
    ("ssd-disk-budget", "pass" if disk_budget_pass else "blocked", f"available={available_bytes}; required_with_reserve={required_with_reserve}"),
    ("local-shard-presence", "pass" if resident_rows == len(http_rows) else "blocked", f"resident_shards={resident_rows}/{len(http_rows)}"),
    ("local-ssd-checkpoint-residency", "pass" if local_checkpoint_residency_ready else "blocked", "requires outside-repo warehouse, disk budget, and all shards locally resident"),
    ("full-safetensors-page-hash-binding", "blocked", "page-hash sweep remains future work"),
    ("real-model-generation", "blocked", "no real Mixtral generation is executed"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61P_LOCAL_SSD_CHECKPOINT_RESIDENCY_PREFLIGHT_BOUNDARY.md").write_text(
    "# v61p Local SSD Checkpoint Residency Preflight Boundary\n\n"
    "This layer turns the v61o local-SSD residency blocker into a concrete outside-repository warehouse plan and disk/presence audit. "
    "It does not download checkpoint shards, does not write checkpoint payload bytes into the repository, and does not execute Mixtral generation.\n\n"
    f"- model_id={model_id}\n"
    f"- checkpoint_shard_rows={len(http_rows)}\n"
    f"- total_checkpoint_bytes_required={total_checkpoint_bytes_required}\n"
    f"- ssd_reserve_bytes={reserve_bytes}\n"
    f"- required_with_reserve_bytes={required_with_reserve}\n"
    f"- available_ssd_bytes={available_bytes}\n"
    f"- ssd_disk_budget_pass={disk_budget_pass}\n"
    f"- ssd_warehouse_path={warehouse_path}\n"
    f"- ssd_warehouse_outside_repo={warehouse_outside_repo}\n"
    f"- local_complete_shard_rows={resident_rows}\n"
    f"- local_checkpoint_residency_ready={local_checkpoint_residency_ready}\n"
    "- checkpoint_payload_bytes_downloaded_by_v61p=0\n"
    "- checkpoint_payload_bytes_committed_to_repo=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- real_100b_open_weight_materialized=0\n"
    "- full_safetensors_page_hash_binding_ready=0\n"
    "- actual_model_generation_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: local SSD checkpoint residency preflight, outside-repository warehouse plan, disk budget audit, and local shard presence audit. "
    "Blocked wording: completed checkpoint residency unless all shards are present and verified, full page-hash coverage, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61p-local-ssd-checkpoint-residency-preflight",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61p_local_ssd_checkpoint_residency_preflight_ready": 1,
    "v61o_summary_sha256": sha256(results / "v61o_checkpoint_shard_header_probe_summary.csv"),
    "warehouse_path_sha256": sha256_text(str(warehouse_path)),
    "checkpoint_shard_rows": len(http_rows),
    "total_checkpoint_bytes_required": total_checkpoint_bytes_required,
    "required_with_reserve_bytes": required_with_reserve,
    "available_ssd_bytes": available_bytes,
    "ssd_disk_budget_pass": disk_budget_pass,
    "ssd_warehouse_outside_repo": warehouse_outside_repo,
    "local_complete_shard_rows": resident_rows,
    "local_checkpoint_residency_ready": local_checkpoint_residency_ready,
    "checkpoint_payload_bytes_downloaded_by_v61p": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_checkpoint_weight_bytes_materialized": 0,
    "real_100b_open_weight_materialized": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61p_local_ssd_checkpoint_residency_preflight_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "ssd_warehouse_probe_rows.csv",
    "ssd_disk_budget_rows.csv",
    "checkpoint_residency_requirement_rows.csv",
    "checkpoint_download_plan_rows.csv",
    "local_shard_presence_rows.csv",
    "runtime_gap_rows.csv",
    "V61P_LOCAL_SSD_CHECKPOINT_RESIDENCY_PREFLIGHT_BOUNDARY.md",
    "v61p_local_ssd_checkpoint_residency_preflight_manifest.json",
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

print(f"v61p_local_ssd_checkpoint_residency_preflight_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
