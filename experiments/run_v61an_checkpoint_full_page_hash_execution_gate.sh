#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61an_checkpoint_full_page_hash_execution_gate"
RUN_ID="${V61AN_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61AN_WAREHOUSE_ROOT:-${V61AM_WAREHOUSE_ROOT:-${V61AL_WAREHOUSE_ROOT:-${V61AK_WAREHOUSE_ROOT:-}}}}"

if [[ "${V61AN_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61an_checkpoint_full_page_hash_execution_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61AM_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61am_checkpoint_post_activation_verification_gate.sh" >/dev/null
else
  V61AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61am_checkpoint_post_activation_verification_gate.sh" >/dev/null
fi
V61T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
V61R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
import csv
import hashlib
import json
import math
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

model_id = "mistralai/Mixtral-8x22B-v0.1"
chunk_pages = int(os.environ.get("V61AN_PAGE_HASH_CHUNK_PAGES", "512"))
enable_local_hash_execution = os.environ.get("V61AN_ENABLE_LOCAL_HASH_EXECUTION", "0") == "1"
if chunk_pages <= 0:
    raise SystemExit("V61AN_PAGE_HASH_CHUNK_PAGES must be positive")


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


v61am_dir = results / "v61am_checkpoint_post_activation_verification_gate" / "gate_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61r_dir = results / "v61r_full_page_hash_sweep_plan" / "plan_001"

v61am_summary = read_csv(results / "v61am_checkpoint_post_activation_verification_gate_summary.csv")[0]
v61t_summary = read_csv(results / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
v61r_summary = read_csv(results / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
if v61am_summary.get("v61am_checkpoint_post_activation_verification_gate_ready") != "1":
    raise SystemExit("v61an requires v61am_checkpoint_post_activation_verification_gate_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61an requires v61t_local_checkpoint_materialization_verifier_ready=1")
if v61r_summary.get("v61r_full_page_hash_sweep_plan_ready") != "1":
    raise SystemExit("v61an requires v61r_full_page_hash_sweep_plan_ready=1")

for src, rel in [
    (results / "v61am_checkpoint_post_activation_verification_gate_summary.csv", "source_v61am/v61am_checkpoint_post_activation_verification_gate_summary.csv"),
    (results / "v61am_checkpoint_post_activation_verification_gate_decision.csv", "source_v61am/v61am_checkpoint_post_activation_verification_gate_decision.csv"),
    (v61am_dir / "checkpoint_post_activation_verification_rows.csv", "source_v61am/checkpoint_post_activation_verification_rows.csv"),
    (v61am_dir / "checkpoint_post_activation_metric_rows.csv", "source_v61am/checkpoint_post_activation_metric_rows.csv"),
    (v61am_dir / "sha256_manifest.csv", "source_v61am/sha256_manifest.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_summary.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (v61t_dir / "local_checkpoint_materialization_rows.csv", "source_v61t/local_checkpoint_materialization_rows.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
    (results / "v61r_full_page_hash_sweep_plan_summary.csv", "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv"),
    (results / "v61r_full_page_hash_sweep_plan_decision.csv", "source_v61r/v61r_full_page_hash_sweep_plan_decision.csv"),
    (v61r_dir / "page_hash_sweep_metric_rows.csv", "source_v61r/page_hash_sweep_metric_rows.csv"),
    (v61r_dir / "shard_page_hash_sweep_status_rows.csv", "source_v61r/shard_page_hash_sweep_status_rows.csv"),
    (v61r_dir / "local_page_hash_verification_rows.csv", "source_v61r/local_page_hash_verification_rows.csv"),
    (v61r_dir / "sha256_manifest.csv", "source_v61r/sha256_manifest.csv"),
]:
    copy(src, rel)

post_rows = read_csv(v61am_dir / "checkpoint_post_activation_verification_rows.csv")
materialization_rows = read_csv(v61t_dir / "local_checkpoint_materialization_rows.csv")
shard_status_rows = read_csv(v61r_dir / "shard_page_hash_sweep_status_rows.csv")
plan_rows = read_csv(v61r_dir / "page_hash_sweep_plan_rows.csv")
if len(post_rows) != 59 or len(materialization_rows) != 59 or len(shard_status_rows) != 59:
    raise SystemExit("v61an expects 59 shard-level input rows")
if len(plan_rows) != int(v61r_summary["page_hash_sweep_plan_rows"]):
    raise SystemExit("v61an page plan row count mismatch")

post_by_shard = {row["shard_name"]: row for row in post_rows}
mat_by_shard = {row["shard_name"]: row for row in materialization_rows}
status_by_shard = {row["shard_name"]: row for row in shard_status_rows}
plan_by_shard = defaultdict(list)
for row in plan_rows:
    plan_by_shard[row["shard_name"]].append(row)
for rows in plan_by_shard.values():
    rows.sort(key=lambda item: int(item["shard_page_index"]))

ordered_shards = [
    row["shard_name"]
    for row in sorted(post_rows, key=lambda item: int(item["priority_rank"]))
]

chunk_rows = []
verification_fields = [
    "page_hash_task_id",
    "execution_chunk_id",
    "model_id",
    "shard_name",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_bytes_hashed",
    "page_sha256",
    "local_hash_verified",
    "checkpoint_payload_bytes_committed_to_repo",
]
verification_rows = []
hashed_chunk_rows = 0
executable_chunk_rows = 0
blocked_chunk_rows = 0
blocked_activation_chunk_rows = 0
blocked_identity_chunk_rows = 0
blocked_execution_disabled_chunk_rows = 0
verified_page_hash_rows = 0
verified_page_hash_bytes = 0

for shard_name in ordered_shards:
    post = post_by_shard[shard_name]
    mat = mat_by_shard[shard_name]
    status = status_by_shard[shard_name]
    rows = plan_by_shard[shard_name]
    if not rows:
        raise SystemExit(f"v61an missing plan rows for {shard_name}")
    activation_admitted = post["activation_admitted"]
    local_identity_verified = mat["local_identity_verified"]
    local_path = Path(mat["target_path"])
    local_file_exists = "1" if local_path.is_file() else "0"
    page_count = len(rows)
    chunk_count = math.ceil(page_count / chunk_pages)
    for chunk_index in range(chunk_count):
        start_index = chunk_index * chunk_pages
        end_index = min(start_index + chunk_pages, page_count)
        chunk_plan_rows = rows[start_index:end_index]
        if activation_admitted != "1":
            chunk_status = "blocked-activation-not-admitted"
            blocked_activation_chunk_rows += 1
        elif local_identity_verified != "1":
            chunk_status = "blocked-local-identity-not-verified"
            blocked_identity_chunk_rows += 1
        elif not enable_local_hash_execution:
            chunk_status = "ready-to-hash-disabled"
            blocked_execution_disabled_chunk_rows += 1
        else:
            chunk_status = "hashed"
            hashed_chunk_rows += 1
        if chunk_status.startswith("blocked") or chunk_status == "ready-to-hash-disabled":
            blocked_chunk_rows += 1
        if chunk_status == "ready-to-hash-disabled":
            executable_chunk_rows += 1

        chunk_id = f"v61an:{shard_name}:chunk:{chunk_index:04d}"
        if chunk_status == "hashed":
            if not local_path.is_file():
                raise SystemExit(f"v61an expected local shard for hashing: {local_path}")
            with local_path.open("rb") as handle:
                for page in chunk_plan_rows:
                    start_byte = int(page["page_start_byte"])
                    end_byte = int(page["page_end_byte_exclusive"])
                    handle.seek(start_byte)
                    data = handle.read(end_byte - start_byte)
                    if len(data) != end_byte - start_byte:
                        raise SystemExit(f"v61an short read for {page['page_hash_task_id']}")
                    verification_rows.append(
                        {
                            "page_hash_task_id": page["page_hash_task_id"],
                            "execution_chunk_id": chunk_id,
                            "model_id": model_id,
                            "shard_name": shard_name,
                            "shard_page_index": page["shard_page_index"],
                            "page_start_byte": page["page_start_byte"],
                            "page_end_byte_exclusive": page["page_end_byte_exclusive"],
                            "page_bytes_hashed": str(len(data)),
                            "page_sha256": sha256_bytes(data),
                            "local_hash_verified": "1",
                            "checkpoint_payload_bytes_committed_to_repo": "0",
                        }
                    )
                    verified_page_hash_rows += 1
                    verified_page_hash_bytes += len(data)

        chunk_rows.append(
            {
                "execution_chunk_id": chunk_id,
                "priority_rank": post["priority_rank"],
                "model_id": model_id,
                "shard_name": shard_name,
                "chunk_index": str(chunk_index),
                "chunk_page_start_index": str(start_index),
                "chunk_page_end_index_exclusive": str(end_index),
                "planned_page_hash_rows": str(len(chunk_plan_rows)),
                "chunk_first_page_start_byte": chunk_plan_rows[0]["page_start_byte"],
                "chunk_last_page_end_byte_exclusive": chunk_plan_rows[-1]["page_end_byte_exclusive"],
                "target_path": mat["target_path"],
                "activation_admitted": activation_admitted,
                "local_identity_verified": local_identity_verified,
                "local_file_exists": local_file_exists,
                "shard_page_hash_coverage_ready": status["shard_page_hash_coverage_ready"],
                "local_hash_execution_enabled": str(int(enable_local_hash_execution)),
                "execution_chunk_status": chunk_status,
                "verified_page_hash_rows": str(len(chunk_plan_rows) if chunk_status == "hashed" else 0),
                "checkpoint_payload_bytes_downloaded_by_v61an": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
            }
        )

execution_chunk_rows = len(chunk_rows)
planned_page_hash_rows = sum(int(row["planned_page_hash_rows"]) for row in chunk_rows)
required_page_hash_rows = int(v61r_summary["checkpoint_unique_page_rows"])
full_hash_execution_ready = int(verified_page_hash_rows == required_page_hash_rows and required_page_hash_rows > 0)
full_safetensors_page_hash_binding_ready = full_hash_execution_ready

write_csv(run_dir / "checkpoint_full_page_hash_execution_chunk_rows.csv", list(chunk_rows[0].keys()), chunk_rows)
write_csv(run_dir / "local_full_page_hash_verification_rows.csv", verification_fields, verification_rows)

requirement_rows = [
    {
        "requirement_id": "activation-admitted-all-shards",
        "status": "pass" if int(v61am_summary["activation_admitted_rows"]) == 59 else "blocked",
        "required_rows": "59",
        "actual_rows": v61am_summary["activation_admitted_rows"],
        "reason": "all shard activation rows must be admitted before full-page hash execution",
    },
    {
        "requirement_id": "local-identity-verified-all-shards",
        "status": "pass" if int(v61t_summary["local_identity_verified_shard_rows"]) == 59 else "blocked",
        "required_rows": "59",
        "actual_rows": v61t_summary["local_identity_verified_shard_rows"],
        "reason": "all local shards must pass size/header/sample identity checks",
    },
    {
        "requirement_id": "full-page-hash-execution-chunks",
        "status": "pass" if full_hash_execution_ready else "blocked",
        "required_rows": str(execution_chunk_rows),
        "actual_rows": str(hashed_chunk_rows),
        "reason": "all page-hash execution chunks must hash successfully",
    },
    {
        "requirement_id": "full-safetensors-page-hash-binding",
        "status": "pass" if full_safetensors_page_hash_binding_ready else "blocked",
        "required_rows": str(required_page_hash_rows),
        "actual_rows": str(verified_page_hash_rows),
        "reason": "all safetensors pages must have local sha256 verification rows",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_rows": "0",
        "actual_rows": "0",
        "reason": "v61an never downloads or commits checkpoint payload bytes",
    },
]
write_csv(run_dir / "checkpoint_full_page_hash_execution_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61an_checkpoint_full_page_hash_execution_gate_metrics",
    "model_id": model_id,
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "checkpoint_shard_rows": "59",
    "required_page_hash_rows": str(required_page_hash_rows),
    "planned_page_hash_rows": str(planned_page_hash_rows),
    "page_hash_execution_chunk_size_pages": str(chunk_pages),
    "execution_chunk_rows": str(execution_chunk_rows),
    "executable_chunk_rows": str(executable_chunk_rows),
    "hashed_chunk_rows": str(hashed_chunk_rows),
    "blocked_chunk_rows": str(blocked_chunk_rows),
    "blocked_activation_chunk_rows": str(blocked_activation_chunk_rows),
    "blocked_identity_chunk_rows": str(blocked_identity_chunk_rows),
    "blocked_execution_disabled_chunk_rows": str(blocked_execution_disabled_chunk_rows),
    "activation_admitted_shard_rows": v61am_summary["activation_admitted_rows"],
    "local_identity_verified_shard_rows": v61t_summary["local_identity_verified_shard_rows"],
    "local_full_page_hash_verified_rows": str(verified_page_hash_rows),
    "local_full_page_hash_verified_bytes": str(verified_page_hash_bytes),
    "full_page_hash_execution_ready": str(full_hash_execution_ready),
    "full_safetensors_page_hash_binding_ready": str(full_safetensors_page_hash_binding_ready),
    "post_activation_verification_gate_ready": v61am_summary["post_activation_verification_gate_ready"],
    "download_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61an": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "checkpoint_full_page_hash_execution_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61an_checkpoint_full_page_hash_execution_gate_ready": "1",
    "v61am_checkpoint_post_activation_verification_gate_ready": v61am_summary["v61am_checkpoint_post_activation_verification_gate_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "v61r_full_page_hash_sweep_plan_ready": v61r_summary["v61r_full_page_hash_sweep_plan_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61am-post-activation-input", "status": "pass", "reason": "v61am post-activation verification gate is ready"},
    {"gate": "v61t-materialization-input", "status": "pass", "reason": "v61t local materialization verifier is ready"},
    {"gate": "v61r-full-page-hash-plan-input", "status": "pass", "reason": "v61r full page-hash sweep plan is ready"},
    {"gate": "full-page-hash-execution-schedule", "status": "pass", "reason": f"execution_chunk_rows={execution_chunk_rows}; chunk_pages={chunk_pages}"},
    {"gate": "activation-admission", "status": "pass" if v61am_summary["activation_admitted_rows"] == "59" else "blocked", "reason": f"activation_admitted_shard_rows={v61am_summary['activation_admitted_rows']}"},
    {"gate": "local-identity-verification", "status": "pass" if v61t_summary["local_identity_verified_shard_rows"] == "59" else "blocked", "reason": f"local_identity_verified_shard_rows={v61t_summary['local_identity_verified_shard_rows']}"},
    {"gate": "full-page-hash-execution", "status": "pass" if full_hash_execution_ready else "blocked", "reason": f"local_full_page_hash_verified_rows={verified_page_hash_rows}/{required_page_hash_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61an writes hashes and metadata only"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real Mixtral generation waits for full local page-hash binding"},
    {"gate": "production-latency", "status": "blocked", "reason": "not an end-to-end decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61an Checkpoint Full Page Hash Execution Gate Boundary

This artifact turns the v61r full page-hash plan into resumable execution chunks
and records local page-hash verification rows only when activation, local shard
identity, and explicit local hash execution are all available.

Evidence emitted:

- checkpoint_shard_rows=59
- required_page_hash_rows={required_page_hash_rows}
- planned_page_hash_rows={planned_page_hash_rows}
- page_hash_execution_chunk_size_pages={chunk_pages}
- execution_chunk_rows={execution_chunk_rows}
- executable_chunk_rows={executable_chunk_rows}
- hashed_chunk_rows={hashed_chunk_rows}
- blocked_chunk_rows={blocked_chunk_rows}
- blocked_activation_chunk_rows={blocked_activation_chunk_rows}
- local_full_page_hash_verified_rows={verified_page_hash_rows}
- full_page_hash_execution_ready={full_hash_execution_ready}
- full_safetensors_page_hash_binding_ready={full_safetensors_page_hash_binding_ready}
- checkpoint_payload_bytes_downloaded_by_v61an=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- activation_admission=blocked unless all 59 shards are activation-admitted
- local_identity_verification=blocked unless all 59 shards are locally identity-verified
- full_page_hash_execution=blocked unless all {required_page_hash_rows} pages have local hash rows
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AN_CHECKPOINT_FULL_PAGE_HASH_EXECUTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61an_checkpoint_full_page_hash_execution_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61an_checkpoint_full_page_hash_execution_gate_ready": 1,
    "required_page_hash_rows": required_page_hash_rows,
    "planned_page_hash_rows": planned_page_hash_rows,
    "page_hash_execution_chunk_size_pages": chunk_pages,
    "execution_chunk_rows": execution_chunk_rows,
    "hashed_chunk_rows": hashed_chunk_rows,
    "local_full_page_hash_verified_rows": verified_page_hash_rows,
    "full_page_hash_execution_ready": full_hash_execution_ready,
    "full_safetensors_page_hash_binding_ready": full_safetensors_page_hash_binding_ready,
    "checkpoint_payload_bytes_downloaded_by_v61an": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61an_checkpoint_full_page_hash_execution_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61an_checkpoint_full_page_hash_execution_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
