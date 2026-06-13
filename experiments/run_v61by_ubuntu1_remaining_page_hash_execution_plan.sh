#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61by_ubuntu1_remaining_page_hash_execution_plan"
RUN_ID="${V61BY_RUN_ID:-plan_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT="${V61BY_WAREHOUSE_ROOT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"
CHUNK_PAGES="${V61BY_PAGE_HASH_CHUNK_PAGES:-512}"

if [[ "${V61BY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61by_ubuntu1_remaining_page_hash_execution_plan_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BX_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bx_ubuntu1_page_hash_coverage_ledger.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT" "$CHUNK_PAGES" <<'PY'
import csv
import hashlib
import json
import math
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root = sys.argv[5]
chunk_pages = int(sys.argv[6])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"
if chunk_pages <= 0:
    raise SystemExit("V61BY_PAGE_HASH_CHUNK_PAGES must be positive")


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


v61bx_dir = results / "v61bx_ubuntu1_page_hash_coverage_ledger" / "ledger_001"
v61bv_dir = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue" / "queue_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61bx_summary_path = results / "v61bx_ubuntu1_page_hash_coverage_ledger_summary.csv"
v61bv_summary_path = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"
v61q_summary_path = results / "v61q_real_checkpoint_page_map_summary.csv"
v61bx_summary = read_csv(v61bx_summary_path)[0]
v61bv_summary = read_csv(v61bv_summary_path)[0]
v61q_summary = read_csv(v61q_summary_path)[0]

if v61bx_summary.get("v61bx_ubuntu1_page_hash_coverage_ledger_ready") != "1":
    raise SystemExit("v61by requires v61bx_ubuntu1_page_hash_coverage_ledger_ready=1")
if v61bv_summary.get("v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready") != "1":
    raise SystemExit("v61by requires v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready=1")
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61by requires v61q_real_checkpoint_page_map_ready=1")

for src, rel in [
    (v61bx_summary_path, "source_v61bx/v61bx_ubuntu1_page_hash_coverage_ledger_summary.csv"),
    (results / "v61bx_ubuntu1_page_hash_coverage_ledger_decision.csv", "source_v61bx/v61bx_ubuntu1_page_hash_coverage_ledger_decision.csv"),
    (v61bx_dir / "page_hash_coverage_ledger_rows.csv", "source_v61bx/page_hash_coverage_ledger_rows.csv"),
    (v61bx_dir / "page_hash_coverage_metric_rows.csv", "source_v61bx/page_hash_coverage_metric_rows.csv"),
    (v61bx_dir / "sha256_manifest.csv", "source_v61bx/sha256_manifest.csv"),
    (v61bv_summary_path, "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"),
    (results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv", "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_queue_rows.csv", "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv"),
    (v61bv_dir / "verified_checkpoint_shard_skip_rows.csv", "source_v61bv/verified_checkpoint_shard_skip_rows.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_chunk_rows.csv", "source_v61bv/remaining_checkpoint_materialization_chunk_rows.csv"),
    (v61bv_dir / "sha256_manifest.csv", "source_v61bv/sha256_manifest.csv"),
    (v61q_summary_path, "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (v61q_dir / "checkpoint_shard_page_summary_rows.csv", "source_v61q/checkpoint_shard_page_summary_rows.csv"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
]:
    copy(src, rel)

ledger_rows = read_csv(v61bx_dir / "page_hash_coverage_ledger_rows.csv")
remaining_queue_rows = [
    row
    for row in read_csv(v61bv_dir / "remaining_checkpoint_materialization_queue_rows.csv")
    if row["shard_name"] != "none"
]
skip_rows = [
    row
    for row in read_csv(v61bv_dir / "verified_checkpoint_shard_skip_rows.csv")
    if row["shard_name"] != "none"
]
if len(ledger_rows) != 59:
    raise SystemExit("v61by expects 59 ledger rows")

ledger_by_shard = {row["shard_name"]: row for row in ledger_rows}
queue_by_shard = {row["shard_name"]: row for row in remaining_queue_rows}
skip_by_shard = {row["shard_name"]: row for row in skip_rows}

chunk_rows = []
skip_page_hash_rows = []
planned_page_rows = 0
planned_page_bytes = 0
skipped_verified_page_rows = 0
skipped_verified_page_bytes = 0

for row in sorted(remaining_queue_rows, key=lambda item: int(item["resumed_priority_rank"])):
    shard_name = row["shard_name"]
    ledger = ledger_by_shard[shard_name]
    remaining_pages = int(ledger["remaining_page_hash_rows"])
    remaining_bytes = int(ledger["remaining_page_hash_bytes"])
    if remaining_pages <= 0:
        raise SystemExit(f"v61by queue shard has no remaining pages: {shard_name}")
    chunk_count = math.ceil(remaining_pages / chunk_pages)
    planned_page_rows += remaining_pages
    planned_page_bytes += remaining_bytes
    for chunk_index in range(chunk_count):
        start_page = chunk_index * chunk_pages
        end_page = min(start_page + chunk_pages, remaining_pages)
        chunk_page_rows = end_page - start_page
        chunk_rows.append(
            {
                "remaining_page_hash_chunk_id": f"v61by:{shard_name}:chunk:{chunk_index:04d}",
                "resumed_priority_rank": row["resumed_priority_rank"],
                "original_priority_rank": row["original_priority_rank"],
                "model_id": model_id,
                "shard_name": shard_name,
                "priority_class": row["priority_class"],
                "target_path": row["target_path"],
                "chunk_index": str(chunk_index),
                "chunk_page_start_index": str(start_page),
                "chunk_page_end_index_exclusive": str(end_page),
                "planned_page_hash_rows": str(chunk_page_rows),
                "shard_remaining_page_hash_rows": str(remaining_pages),
                "shard_remaining_page_hash_bytes": str(remaining_bytes),
                "remaining_materialization_queued": ledger["remaining_materialization_queued"],
                "full_shard_page_hash_coverage_ready": ledger["full_shard_page_hash_coverage_ready"],
                "dry_run_default": "1",
                "requires_identity_verification_before_hash": "1",
                "requires_execute_flag": "1",
                "requires_approval_phrase": "1",
                "page_hash_execution_status": "blocked-pending-materialization",
                "checkpoint_payload_bytes_downloaded_by_v61by": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
            }
        )

for shard_name, skip in sorted(skip_by_shard.items()):
    ledger = ledger_by_shard[shard_name]
    verified_rows = int(ledger["verified_page_hash_rows"])
    verified_bytes = int(ledger["verified_page_hash_bytes"])
    skipped_verified_page_rows += verified_rows
    skipped_verified_page_bytes += verified_bytes
    skip_page_hash_rows.append(
        {
            "skip_page_hash_row_id": f"v61by-skip:{shard_name}",
            "model_id": model_id,
            "shard_name": shard_name,
            "target_path": skip["target_path"],
            "verified_page_hash_rows": str(verified_rows),
            "verified_page_hash_bytes": str(verified_bytes),
            "full_shard_page_hash_coverage_ready": ledger["full_shard_page_hash_coverage_ready"],
            "skip_reason": "already-page-hash-witnessed",
            "checkpoint_payload_bytes_downloaded_by_v61by": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

if not skip_page_hash_rows:
    skip_page_hash_rows.append(
        {
            "skip_page_hash_row_id": "v61by-skip:none",
            "model_id": model_id,
            "shard_name": "none",
            "target_path": warehouse_root,
            "verified_page_hash_rows": "0",
            "verified_page_hash_bytes": "0",
            "full_shard_page_hash_coverage_ready": "0",
            "skip_reason": "no-page-hash-witnessed-shard",
            "checkpoint_payload_bytes_downloaded_by_v61by": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

chunk_fields = [
    "remaining_page_hash_chunk_id",
    "resumed_priority_rank",
    "original_priority_rank",
    "model_id",
    "shard_name",
    "priority_class",
    "target_path",
    "chunk_index",
    "chunk_page_start_index",
    "chunk_page_end_index_exclusive",
    "planned_page_hash_rows",
    "shard_remaining_page_hash_rows",
    "shard_remaining_page_hash_bytes",
    "remaining_materialization_queued",
    "full_shard_page_hash_coverage_ready",
    "dry_run_default",
    "requires_identity_verification_before_hash",
    "requires_execute_flag",
    "requires_approval_phrase",
    "page_hash_execution_status",
    "checkpoint_payload_bytes_downloaded_by_v61by",
    "checkpoint_payload_bytes_committed_to_repo",
]
write_csv(run_dir / "remaining_page_hash_execution_chunk_rows.csv", chunk_fields, chunk_rows)
write_csv(run_dir / "verified_page_hash_skip_rows.csv", list(skip_page_hash_rows[0].keys()), skip_page_hash_rows)

total_page_rows = int(v61bx_summary["total_checkpoint_unique_page_rows"])
total_bytes = int(v61bx_summary["total_checkpoint_bytes_expected"])
verified_page_rows = int(v61bx_summary["verified_page_hash_rows"])
verified_page_bytes = int(v61bx_summary["verified_page_hash_bytes"])
remaining_page_rows = int(v61bx_summary["remaining_page_hash_rows"])
remaining_page_bytes = int(v61bx_summary["remaining_page_hash_bytes"])
full_page_hash_ready = int(v61bx_summary["full_safetensors_page_hash_binding_ready"])
remaining_plan_ready = int(
    (remaining_page_rows == 0 and remaining_page_bytes == 0 and full_page_hash_ready)
    or (planned_page_rows == remaining_page_rows and planned_page_bytes == remaining_page_bytes and len(chunk_rows) > 0)
)

requirement_rows = [
    {
        "requirement_id": "v61bx-coverage-ledger-input",
        "status": "pass",
        "required_value": "v61bx ready",
        "actual_value": v61bx_summary["v61bx_ubuntu1_page_hash_coverage_ledger_ready"],
        "reason": "partial coverage ledger is bound",
    },
    {
        "requirement_id": "v61bv-remaining-materialization-input",
        "status": "pass",
        "required_value": "v61bv ready",
        "actual_value": v61bv_summary["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
        "reason": "remaining shard queue is bound",
    },
    {
        "requirement_id": "remaining-page-hash-execution-plan",
        "status": "pass" if remaining_plan_ready else "blocked",
        "required_value": str(remaining_page_rows),
        "actual_value": str(planned_page_rows),
        "reason": "only unverified shard pages are scheduled for future hashing; no chunks are needed when full coverage is already complete",
    },
    {
        "requirement_id": "skip-already-verified-page-hash-shards",
        "status": "pass" if skipped_verified_page_rows == verified_page_rows else "blocked",
        "required_value": str(verified_page_rows),
        "actual_value": str(skipped_verified_page_rows),
        "reason": "already page-hashed shard(s) are excluded from remaining execution chunks",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "pass" if full_page_hash_ready else "blocked",
        "required_value": str(total_page_rows),
        "actual_value": str(verified_page_rows),
        "reason": "full coverage waits for remaining page-hash chunks to execute after materialization",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "v61by emits execution metadata only",
    },
]
write_csv(run_dir / "remaining_page_hash_execution_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61by_ubuntu1_remaining_page_hash_execution_plan_metrics",
    "model_id": model_id,
    "v61bx_ubuntu1_page_hash_coverage_ledger_ready": v61bx_summary["v61bx_ubuntu1_page_hash_coverage_ledger_ready"],
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": v61bv_summary["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
    "target_root_path": warehouse_root,
    "checkpoint_shard_rows": "59",
    "total_checkpoint_unique_page_rows": str(total_page_rows),
    "total_checkpoint_bytes_expected": str(total_bytes),
    "verified_page_hash_rows": str(verified_page_rows),
    "verified_page_hash_bytes": str(verified_page_bytes),
    "skipped_verified_page_hash_rows": str(skipped_verified_page_rows),
    "skipped_verified_page_hash_bytes": str(skipped_verified_page_bytes),
    "remaining_page_hash_rows": str(remaining_page_rows),
    "remaining_page_hash_bytes": str(remaining_page_bytes),
    "remaining_page_hash_execution_chunk_size_pages": str(chunk_pages),
    "remaining_page_hash_execution_chunk_rows": str(len(chunk_rows)),
    "remaining_page_hash_execution_plan_ready": str(remaining_plan_ready),
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61by": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "remaining_page_hash_execution_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("remaining-page-hash-execution-plan", "ready" if remaining_plan_ready else "blocked", f"planned_page_hash_rows={planned_page_rows}/{remaining_page_rows}"),
    ("completed-full-safetensors-page-hash-coverage", "ready" if full_page_hash_ready else "blocked", f"remaining_page_hash_rows={remaining_page_rows}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "remaining page-hash execution plan is not latency evidence"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61by_ubuntu1_remaining_page_hash_execution_plan_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bx-coverage-ledger-input", "status": "pass", "reason": "v61bx partial coverage ledger is bound"},
    {"gate": "v61bv-remaining-materialization-input", "status": "pass", "reason": "v61bv remaining materialization queue is bound"},
    {"gate": "remaining-page-hash-execution-plan", "status": "pass" if remaining_plan_ready else "blocked", "reason": f"planned_page_hash_rows={planned_page_rows}/{remaining_page_rows}"},
    {"gate": "skip-already-verified-page-hash-shards", "status": "pass" if skipped_verified_page_rows == verified_page_rows else "blocked", "reason": f"skipped_verified_page_hash_rows={skipped_verified_page_rows}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if full_page_hash_ready else "blocked", "reason": f"remaining_page_hash_rows={remaining_page_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61by writes metadata only; checkpoint payload stays outside repo"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61by Ubuntu-1 Remaining Page-Hash Execution Plan Boundary

This gate consumes the v61bx page-hash coverage ledger and emits a remaining
execution plan for only the unverified checkpoint pages. Already verified
page-hash shards are skipped. It does not download checkpoint payload bytes and
does not commit checkpoint payload bytes to the repository.

Evidence emitted:

- verified_page_hash_rows={verified_page_rows}
- skipped_verified_page_hash_rows={skipped_verified_page_rows}
- remaining_page_hash_rows={remaining_page_rows}
- remaining_page_hash_bytes={remaining_page_bytes}
- remaining_page_hash_execution_chunk_size_pages={chunk_pages}
- remaining_page_hash_execution_chunk_rows={len(chunk_rows)}
- remaining_page_hash_execution_plan_ready={remaining_plan_ready}
- full_safetensors_page_hash_binding_ready={full_page_hash_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61by=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: remaining page-hash execution plan after partial ubuntu-1
coverage. Blocked wording: completed full safetensors page-hash coverage,
actual model generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61BY_UBUNTU1_REMAINING_PAGE_HASH_EXECUTION_PLAN_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61by_ubuntu1_remaining_page_hash_execution_plan",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61by_ubuntu1_remaining_page_hash_execution_plan_ready": 1,
    "source_v61bx_summary_sha256": sha256(v61bx_summary_path),
    "source_v61bv_summary_sha256": sha256(v61bv_summary_path),
    "verified_page_hash_rows": verified_page_rows,
    "remaining_page_hash_rows": remaining_page_rows,
    "remaining_page_hash_execution_chunk_rows": len(chunk_rows),
    "remaining_page_hash_execution_plan_ready": remaining_plan_ready,
    "full_safetensors_page_hash_binding_ready": full_page_hash_ready,
    "checkpoint_payload_bytes_downloaded_by_v61by": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61by_ubuntu1_remaining_page_hash_execution_plan_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61by_ubuntu1_remaining_page_hash_execution_plan_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
