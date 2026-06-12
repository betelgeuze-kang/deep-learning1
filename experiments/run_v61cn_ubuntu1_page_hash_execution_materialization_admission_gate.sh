#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cn_ubuntu1_page_hash_execution_materialization_admission_gate"
RUN_ID="${V61CN_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bz_ubuntu1_remaining_page_hash_operator_bundle.sh" >/dev/null
V61CM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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


v61bz_dir = results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle" / "bundle_001"
v61cm_dir = results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate" / "gate_001"
v61bz_summary_path = results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_summary.csv"
v61bz_decision_path = results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_decision.csv"
v61cm_summary_path = results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv"
v61cm_decision_path = results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv"
v61bz_summary = read_csv(v61bz_summary_path)[0]
v61cm_summary = read_csv(v61cm_summary_path)[0]
if v61bz_summary.get("v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready") != "1":
    raise SystemExit("v61cn requires v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready=1")
if v61cm_summary.get("v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready") != "1":
    raise SystemExit("v61cn requires v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready=1")

for src, rel in [
    (v61bz_summary_path, "source_v61bz/v61bz_ubuntu1_remaining_page_hash_operator_bundle_summary.csv"),
    (v61bz_decision_path, "source_v61bz/v61bz_ubuntu1_remaining_page_hash_operator_bundle_decision.csv"),
    (v61bz_dir / "operator_bundle/remaining_page_hash_execution_chunk_rows.csv", "source_v61bz/remaining_page_hash_execution_chunk_rows.csv"),
    (v61bz_dir / "operator_bundle/verified_page_hash_skip_rows.csv", "source_v61bz/verified_page_hash_skip_rows.csv"),
    (v61bz_dir / "remaining_page_hash_operator_metric_rows.csv", "source_v61bz/remaining_page_hash_operator_metric_rows.csv"),
    (v61bz_dir / "sha256_manifest.csv", "source_v61bz/sha256_manifest.csv"),
    (v61cm_summary_path, "source_v61cm/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv"),
    (v61cm_decision_path, "source_v61cm/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv"),
    (v61cm_dir / "full_checkpoint_materialization_promotion_rows.csv", "source_v61cm/full_checkpoint_materialization_promotion_rows.csv"),
    (v61cm_dir / "full_checkpoint_materialization_promotion_metric_rows.csv", "source_v61cm/full_checkpoint_materialization_promotion_metric_rows.csv"),
    (v61cm_dir / "sha256_manifest.csv", "source_v61cm/sha256_manifest.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v61bz_dir / "operator_bundle/remaining_page_hash_execution_chunk_rows.csv")
promotion_rows = read_csv(v61cm_dir / "full_checkpoint_materialization_promotion_rows.csv")
materialization_by_shard = {row["shard_name"]: row for row in promotion_rows}
PAGE_SIZE = 2 * 1024 * 1024
if not chunk_rows:
    raise SystemExit("v61cn requires remaining page-hash chunk rows")
if not materialization_by_shard:
    raise SystemExit("v61cn requires materialization promotion rows")

admission_rows = []
admitted_chunks = 0
blocked_chunks = 0
admitted_page_hash_rows = 0
blocked_page_hash_rows = 0
admitted_page_hash_bytes = 0
blocked_page_hash_bytes = 0
missing_materialization_shard_rows = 0
seen_missing_shards = set()

for index, chunk in enumerate(chunk_rows):
    shard = chunk["shard_name"]
    mat = materialization_by_shard.get(shard)
    full_shard_materialization_ready = mat["full_shard_materialization_ready"] if mat else "0"
    planned_rows = int(chunk["planned_page_hash_rows"])
    chunk_start = int(chunk["chunk_page_start_index"]) * PAGE_SIZE
    chunk_end = int(chunk["chunk_page_end_index_exclusive"]) * PAGE_SIZE
    shard_bytes = int(chunk["shard_remaining_page_hash_bytes"])
    planned_bytes = max(0, min(chunk_end, shard_bytes) - min(chunk_start, shard_bytes))
    admitted = int(full_shard_materialization_ready == "1")
    if admitted:
        admitted_chunks += 1
        admitted_page_hash_rows += planned_rows
        admitted_page_hash_bytes += planned_bytes
        status = "admitted-materialization-ready"
        reason = "shard has full materialization promotion readiness"
    else:
        blocked_chunks += 1
        blocked_page_hash_rows += planned_rows
        blocked_page_hash_bytes += planned_bytes
        status = "blocked-materialization-not-ready"
        reason = "shard lacks accepted materialization return rows"
        if shard not in seen_missing_shards:
            seen_missing_shards.add(shard)
            missing_materialization_shard_rows += 1
    admission_rows.append(
        {
            "admission_row_id": f"v61cn-page-hash-admission-{index:04d}",
            "remaining_page_hash_chunk_id": chunk["remaining_page_hash_chunk_id"],
            "model_id": model_id,
            "shard_name": shard,
            "target_path": chunk["target_path"],
            "planned_page_hash_rows": chunk["planned_page_hash_rows"],
            "planned_page_hash_bytes": str(planned_bytes),
            "materialization_promotion_status": mat["promotion_status"] if mat else "missing-materialization-promotion-row",
            "full_shard_materialization_ready": full_shard_materialization_ready,
            "page_hash_execution_admitted": str(admitted),
            "page_hash_execution_admission_status": status,
            "admission_reason": reason,
            "checkpoint_payload_bytes_downloaded_by_v61cn": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "page_hash_execution_materialization_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)

full_materialization_ready = int(v61cm_summary["full_checkpoint_materialization_ready"])
operator_bundle_ready = int(v61bz_summary["remaining_page_hash_operator_bundle_ready"])
page_hash_execution_admission_ready = int(operator_bundle_ready and full_materialization_ready and admitted_chunks == len(chunk_rows))

requirement_rows = [
    {
        "requirement_id": "v61bz-page-hash-operator-bundle-input",
        "status": "pass",
        "required_value": "v61bz ready",
        "actual_value": v61bz_summary["v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready"],
        "reason": "remaining page-hash operator bundle is bound",
    },
    {
        "requirement_id": "v61cm-full-materialization-promotion-input",
        "status": "pass",
        "required_value": "v61cm ready",
        "actual_value": v61cm_summary["v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready"],
        "reason": "full checkpoint materialization promotion gate is bound",
    },
    {
        "requirement_id": "full-checkpoint-materialization-ready-before-page-hash",
        "status": "pass" if full_materialization_ready else "blocked",
        "required_value": "1",
        "actual_value": str(full_materialization_ready),
        "reason": "page-hash execution requires all checkpoint shards to be materialized",
    },
    {
        "requirement_id": "all-remaining-page-hash-chunks-admitted",
        "status": "pass" if admitted_chunks == len(chunk_rows) else "blocked",
        "required_value": str(len(chunk_rows)),
        "actual_value": str(admitted_chunks),
        "reason": "all remaining page-hash chunks must have materialized shard inputs",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "admission gate stores metadata only",
    },
]
write_csv(run_dir / "page_hash_execution_materialization_admission_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_metrics",
    "model_id": model_id,
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": v61bz_summary["v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready"],
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": v61cm_summary["v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready"],
    "target_root_path": v61bz_summary["target_root_path"],
    "remaining_page_hash_execution_chunk_rows": str(len(chunk_rows)),
    "admitted_page_hash_execution_chunk_rows": str(admitted_chunks),
    "materialization_blocked_page_hash_execution_chunk_rows": str(blocked_chunks),
    "admitted_page_hash_rows": str(admitted_page_hash_rows),
    "blocked_page_hash_rows": str(blocked_page_hash_rows),
    "admitted_page_hash_bytes": str(admitted_page_hash_bytes),
    "blocked_page_hash_bytes": str(blocked_page_hash_bytes),
    "materialization_blocked_shard_rows": str(missing_materialization_shard_rows),
    "ready_checkpoint_materialization_shard_rows": v61cm_summary["ready_checkpoint_materialization_shard_rows"],
    "blocked_checkpoint_materialization_shard_rows": v61cm_summary["blocked_checkpoint_materialization_shard_rows"],
    "full_checkpoint_materialization_ready": v61cm_summary["full_checkpoint_materialization_ready"],
    "remaining_page_hash_operator_bundle_ready": v61bz_summary["remaining_page_hash_operator_bundle_ready"],
    "page_hash_execution_admission_ready": str(page_hash_execution_admission_ready),
    "page_hash_execution_ready": "0",
    "completed_full_safetensors_page_hash_coverage_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "page_hash_execution_materialization_admission_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61bz-page-hash-operator-bundle-input", "ready", "v61bz operator bundle is bound"),
    ("v61cm-full-materialization-promotion-input", "ready", "v61cm materialization promotion is bound"),
    ("full-checkpoint-materialization-ready-before-page-hash", "ready" if full_materialization_ready else "blocked", f"full_checkpoint_materialization_ready={full_materialization_ready}"),
    ("all-remaining-page-hash-chunks-admitted", "ready" if admitted_chunks == len(chunk_rows) else "blocked", f"admitted_page_hash_execution_chunk_rows={admitted_chunks}"),
    ("page-hash-execution", "blocked", "this gate does not run page hashing"),
    ("completed-full-safetensors-page-hash-coverage", "blocked", "requires executed and accepted page-hash result rows"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bz-page-hash-operator-bundle-input", "status": "pass", "reason": "v61bz operator bundle is bound"},
    {"gate": "v61cm-full-materialization-promotion-input", "status": "pass", "reason": "v61cm materialization promotion is bound"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cn writes metadata only"},
    {"gate": "full-checkpoint-materialization-ready-before-page-hash", "status": "pass" if full_materialization_ready else "blocked", "reason": f"full_checkpoint_materialization_ready={full_materialization_ready}"},
    {"gate": "all-remaining-page-hash-chunks-admitted", "status": "pass" if admitted_chunks == len(chunk_rows) else "blocked", "reason": f"admitted_page_hash_execution_chunk_rows={admitted_chunks}"},
    {"gate": "page-hash-execution", "status": "blocked", "reason": "not executed by v61cn"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "blocked", "reason": "requires accepted page-hash result rows"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cn Ubuntu-1 Page-Hash Execution Materialization Admission Gate Boundary

This gate binds the v61bz remaining page-hash operator chunks to v61cm full
checkpoint materialization promotion rows. It does not execute page hashing,
does not download checkpoint payload bytes, and does not commit checkpoint
payload bytes to the repository.

Evidence emitted:

- remaining_page_hash_execution_chunk_rows={len(chunk_rows)}
- admitted_page_hash_execution_chunk_rows={admitted_chunks}
- materialization_blocked_page_hash_execution_chunk_rows={blocked_chunks}
- admitted_page_hash_rows={admitted_page_hash_rows}
- blocked_page_hash_rows={blocked_page_hash_rows}
- admitted_page_hash_bytes={admitted_page_hash_bytes}
- blocked_page_hash_bytes={blocked_page_hash_bytes}
- materialization_blocked_shard_rows={missing_materialization_shard_rows}
- full_checkpoint_materialization_ready={full_materialization_ready}
- remaining_page_hash_operator_bundle_ready={operator_bundle_ready}
- page_hash_execution_admission_ready={page_hash_execution_admission_ready}
- page_hash_execution_ready=0
- completed_full_safetensors_page_hash_coverage_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cn=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: page-hash execution materialization admission gate with
default materialization block. Blocked wording: executed page hashing,
completed full safetensors page-hash coverage, actual model generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CN_UBUNTU1_PAGE_HASH_EXECUTION_MATERIALIZATION_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready": 1,
    "source_v61bz_summary_sha256": sha256(v61bz_summary_path),
    "source_v61cm_summary_sha256": sha256(v61cm_summary_path),
    "remaining_page_hash_execution_chunk_rows": len(chunk_rows),
    "admitted_page_hash_execution_chunk_rows": admitted_chunks,
    "materialization_blocked_page_hash_execution_chunk_rows": blocked_chunks,
    "page_hash_execution_admission_ready": page_hash_execution_admission_ready,
    "checkpoint_payload_bytes_downloaded_by_v61cn": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
