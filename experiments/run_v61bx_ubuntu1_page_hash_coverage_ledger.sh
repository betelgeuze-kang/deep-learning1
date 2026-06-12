#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bx_ubuntu1_page_hash_coverage_ledger"
RUN_ID="${V61BX_RUN_ID:-ledger_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT="${V61BX_WAREHOUSE_ROOT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"

if [[ "${V61BX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bx_ubuntu1_page_hash_coverage_ledger_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BW_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bw_ubuntu1_partial_page_hash_witness.sh" >/dev/null
V61BV_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bv_ubuntu1_remaining_checkpoint_materialization_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT" <<'PY'
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
warehouse_root = sys.argv[5]
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


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


v61bw_dir = results / "v61bw_ubuntu1_partial_page_hash_witness" / "hash_001"
v61bv_dir = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue" / "queue_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61bw_summary_path = results / "v61bw_ubuntu1_partial_page_hash_witness_summary.csv"
v61bv_summary_path = results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"
v61q_summary_path = results / "v61q_real_checkpoint_page_map_summary.csv"
v61bw_summary = read_csv(v61bw_summary_path)[0]
v61bv_summary = read_csv(v61bv_summary_path)[0]
v61q_summary = read_csv(v61q_summary_path)[0]

if v61bw_summary.get("v61bw_ubuntu1_partial_page_hash_witness_ready") != "1":
    raise SystemExit("v61bx requires v61bw_ubuntu1_partial_page_hash_witness_ready=1")
if v61bv_summary.get("v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready") != "1":
    raise SystemExit("v61bx requires v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready=1")
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61bx requires v61q_real_checkpoint_page_map_ready=1")

for src, rel in [
    (v61bw_summary_path, "source_v61bw/v61bw_ubuntu1_partial_page_hash_witness_summary.csv"),
    (results / "v61bw_ubuntu1_partial_page_hash_witness_decision.csv", "source_v61bw/v61bw_ubuntu1_partial_page_hash_witness_decision.csv"),
    (v61bw_dir / "partial_page_hash_witness_rows.csv", "source_v61bw/partial_page_hash_witness_rows.csv"),
    (v61bw_dir / "partial_page_hash_shard_status_rows.csv", "source_v61bw/partial_page_hash_shard_status_rows.csv"),
    (v61bw_dir / "partial_page_hash_metric_rows.csv", "source_v61bw/partial_page_hash_metric_rows.csv"),
    (v61bw_dir / "sha256_manifest.csv", "source_v61bw/sha256_manifest.csv"),
    (v61bv_summary_path, "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv"),
    (results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv", "source_v61bv/v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_queue_rows.csv", "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv"),
    (v61bv_dir / "verified_checkpoint_shard_skip_rows.csv", "source_v61bv/verified_checkpoint_shard_skip_rows.csv"),
    (v61bv_dir / "remaining_checkpoint_materialization_chunk_rows.csv", "source_v61bv/remaining_checkpoint_materialization_chunk_rows.csv"),
    (v61bv_dir / "sha256_manifest.csv", "source_v61bv/sha256_manifest.csv"),
    (v61q_summary_path, "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (results / "v61q_real_checkpoint_page_map_decision.csv", "source_v61q/v61q_real_checkpoint_page_map_decision.csv"),
    (v61q_dir / "checkpoint_shard_page_summary_rows.csv", "source_v61q/checkpoint_shard_page_summary_rows.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
]:
    copy(src, rel)

shard_page_rows = read_csv(v61q_dir / "checkpoint_shard_page_summary_rows.csv")
partial_shard_status_rows = read_csv(v61bw_dir / "partial_page_hash_shard_status_rows.csv")
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
chunk_rows = [
    row
    for row in read_csv(v61bv_dir / "remaining_checkpoint_materialization_chunk_rows.csv")
    if row["priority_class"] != "none"
]
if len(shard_page_rows) != 59:
    raise SystemExit("v61bx expects 59 checkpoint shard page summary rows")

verified_by_shard = {
    row["shard_name"]: row
    for row in partial_shard_status_rows
    if row["shard_name"] != "none" and row["partial_full_shard_page_hash_ready"] == "1"
}
queue_by_shard = {row["shard_name"]: row for row in remaining_queue_rows}
skip_by_shard = {row["shard_name"]: row for row in skip_rows}

ledger_rows = []
verified_page_rows = 0
verified_page_bytes = 0
verified_shards = 0
remaining_page_rows = 0
remaining_page_bytes = 0
queued_remaining_shards = 0
skipped_verified_shards = 0

for row in sorted(shard_page_rows, key=lambda item: item["shard_name"]):
    shard_name = row["shard_name"]
    planned_pages = int(row["checkpoint_page_rows"])
    planned_bytes = int(row["content_length"])
    verified = verified_by_shard.get(shard_name)
    queue = queue_by_shard.get(shard_name)
    skip = skip_by_shard.get(shard_name)
    hashed_pages = int(verified["hashed_page_rows"]) if verified else 0
    hashed_bytes = int(verified["hashed_page_bytes"]) if verified else 0
    shard_ready = int(hashed_pages == planned_pages and hashed_bytes == planned_bytes and planned_pages > 0)
    remaining_rows = max(planned_pages - hashed_pages, 0)
    remaining_bytes = max(planned_bytes - hashed_bytes, 0)
    verified_page_rows += hashed_pages
    verified_page_bytes += hashed_bytes
    verified_shards += shard_ready
    remaining_page_rows += remaining_rows
    remaining_page_bytes += remaining_bytes
    queued_remaining_shards += int(queue is not None)
    skipped_verified_shards += int(skip is not None)
    if shard_ready:
        coverage_status = "partial-witness-shard-complete"
    elif queue:
        coverage_status = "blocked-pending-materialization"
    else:
        coverage_status = "blocked-no-current-queue-row"
    ledger_rows.append(
        {
            "coverage_ledger_row_id": f"v61bx:{shard_name}",
            "model_id": model_id,
            "shard_name": shard_name,
            "planned_page_hash_rows": str(planned_pages),
            "planned_page_hash_bytes": str(planned_bytes),
            "verified_page_hash_rows": str(hashed_pages),
            "verified_page_hash_bytes": str(hashed_bytes),
            "remaining_page_hash_rows": str(remaining_rows),
            "remaining_page_hash_bytes": str(remaining_bytes),
            "full_shard_page_hash_coverage_ready": str(shard_ready),
            "remaining_materialization_queued": str(int(queue is not None)),
            "verified_shard_skipped_by_materialization_queue": str(int(skip is not None)),
            "coverage_status": coverage_status,
            "checkpoint_payload_bytes_downloaded_by_v61bx": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

write_csv(run_dir / "page_hash_coverage_ledger_rows.csv", list(ledger_rows[0].keys()), ledger_rows)

total_checkpoint_pages = int(v61q_summary["checkpoint_unique_page_rows"])
total_checkpoint_bytes = int(v61q_summary["total_checkpoint_bytes_required"])
remaining_shard_rows = len(ledger_rows) - verified_shards
partial_ledger_ready = int(verified_page_rows > 0 and verified_page_rows == int(v61bw_summary["page_hash_witness_rows"]))
full_page_hash_ready = int(verified_page_rows == total_checkpoint_pages and verified_shards == len(ledger_rows))

requirement_rows = [
    {
        "requirement_id": "v61bw-partial-page-hash-input",
        "status": "pass",
        "required_value": "v61bw ready",
        "actual_value": v61bw_summary["v61bw_ubuntu1_partial_page_hash_witness_ready"],
        "reason": "partial page-hash witness rows are bound",
    },
    {
        "requirement_id": "v61q-page-map-input",
        "status": "pass",
        "required_value": "v61q ready",
        "actual_value": v61q_summary["v61q_real_checkpoint_page_map_ready"],
        "reason": "complete checkpoint page map metadata is bound",
    },
    {
        "requirement_id": "v61bv-remaining-materialization-queue-input",
        "status": "pass",
        "required_value": "v61bv ready",
        "actual_value": v61bv_summary["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
        "reason": "remaining materialization queue is bound to the same target",
    },
    {
        "requirement_id": "partial-page-hash-coverage-ledger",
        "status": "pass" if partial_ledger_ready else "blocked",
        "required_value": "verified rows from v61bw promoted into ledger",
        "actual_value": str(verified_page_rows),
        "reason": "ledger records verified and remaining page-hash rows per checkpoint shard",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "pass" if full_page_hash_ready else "blocked",
        "required_value": str(total_checkpoint_pages),
        "actual_value": str(verified_page_rows),
        "reason": "full coverage requires every checkpoint shard page hash to be verified",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "v61bx writes coverage metadata only",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": "blocked",
        "required_value": "full page-hash coverage plus generation rows",
        "actual_value": "0",
        "reason": "v61bx is a coverage ledger, not a generation runner",
    },
]
write_csv(run_dir / "page_hash_coverage_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bx_ubuntu1_page_hash_coverage_ledger_metrics",
    "model_id": model_id,
    "v61bw_ubuntu1_partial_page_hash_witness_ready": v61bw_summary["v61bw_ubuntu1_partial_page_hash_witness_ready"],
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": v61bv_summary["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "target_root_path": warehouse_root,
    "checkpoint_shard_rows": str(len(ledger_rows)),
    "total_checkpoint_unique_page_rows": str(total_checkpoint_pages),
    "total_checkpoint_bytes_expected": str(total_checkpoint_bytes),
    "verified_page_hash_shard_rows": str(verified_shards),
    "verified_page_hash_rows": str(verified_page_rows),
    "verified_page_hash_bytes": str(verified_page_bytes),
    "remaining_page_hash_shard_rows": str(remaining_shard_rows),
    "remaining_page_hash_rows": str(remaining_page_rows),
    "remaining_page_hash_bytes": str(remaining_page_bytes),
    "remaining_materialization_queue_rows": str(len(remaining_queue_rows)),
    "remaining_materialization_chunk_rows": str(len(chunk_rows)),
    "queued_remaining_shard_rows": str(queued_remaining_shards),
    "skipped_verified_shard_rows": str(skipped_verified_shards),
    "partial_page_hash_coverage_ledger_ready": str(partial_ledger_ready),
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "page_hash_coverage_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("partial-page-hash-coverage-ledger", "ready" if partial_ledger_ready else "blocked", f"verified_page_hash_rows={verified_page_rows}/{total_checkpoint_pages}"),
    ("completed-full-safetensors-page-hash-coverage", "ready" if full_page_hash_ready else "blocked", f"remaining_page_hash_rows={remaining_page_rows}"),
    ("remaining-materialization-queue", "ready" if remaining_queue_rows else "blocked", f"remaining_queue_rows={len(remaining_queue_rows)}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "coverage ledger is not latency evidence"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61bx_ubuntu1_page_hash_coverage_ledger_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bw-partial-page-hash-input", "status": "pass", "reason": "v61bw partial page-hash witness is bound"},
    {"gate": "v61q-page-map-input", "status": "pass", "reason": "v61q complete page map metadata is bound"},
    {"gate": "v61bv-remaining-materialization-queue-input", "status": "pass", "reason": "v61bv remaining materialization queue is bound"},
    {"gate": "partial-page-hash-coverage-ledger", "status": "pass" if partial_ledger_ready else "blocked", "reason": f"verified_page_hash_rows={verified_page_rows}/{total_checkpoint_pages}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if full_page_hash_ready else "blocked", "reason": f"remaining_page_hash_rows={remaining_page_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bx writes metadata only; checkpoint payload stays outside repo"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bx Ubuntu-1 Page-Hash Coverage Ledger Boundary

This gate promotes the v61bw partial page-hash witness into a checkpoint-wide
coverage ledger. It records verified and remaining page-hash rows per shard,
but it does not download checkpoint payload bytes and does not commit
checkpoint payload bytes to the repository.

Evidence emitted:

- checkpoint_shard_rows={len(ledger_rows)}
- total_checkpoint_unique_page_rows={total_checkpoint_pages}
- verified_page_hash_shard_rows={verified_shards}
- verified_page_hash_rows={verified_page_rows}
- verified_page_hash_bytes={verified_page_bytes}
- remaining_page_hash_shard_rows={remaining_shard_rows}
- remaining_page_hash_rows={remaining_page_rows}
- remaining_page_hash_bytes={remaining_page_bytes}
- remaining_materialization_queue_rows={len(remaining_queue_rows)}
- partial_page_hash_coverage_ledger_ready={partial_ledger_ready}
- full_safetensors_page_hash_binding_ready={full_page_hash_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bx=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: partial page-hash coverage ledger over the current ubuntu-1
identity-verified shard. Blocked wording: completed full safetensors page-hash
coverage, actual model generation, production latency, near-frontier quality,
or release readiness.
"""
(run_dir / "V61BX_UBUNTU1_PAGE_HASH_COVERAGE_LEDGER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bx_ubuntu1_page_hash_coverage_ledger",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bx_ubuntu1_page_hash_coverage_ledger_ready": 1,
    "source_v61bw_summary_sha256": sha256(v61bw_summary_path),
    "source_v61bv_summary_sha256": sha256(v61bv_summary_path),
    "source_v61q_summary_sha256": sha256(v61q_summary_path),
    "checkpoint_shard_rows": len(ledger_rows),
    "total_checkpoint_unique_page_rows": total_checkpoint_pages,
    "verified_page_hash_rows": verified_page_rows,
    "verified_page_hash_bytes": verified_page_bytes,
    "remaining_page_hash_rows": remaining_page_rows,
    "partial_page_hash_coverage_ledger_ready": partial_ledger_ready,
    "full_safetensors_page_hash_binding_ready": full_page_hash_ready,
    "checkpoint_payload_bytes_downloaded_by_v61bx": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bx_ubuntu1_page_hash_coverage_ledger_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bx_ubuntu1_page_hash_coverage_ledger_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
