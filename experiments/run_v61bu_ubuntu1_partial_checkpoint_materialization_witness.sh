#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bu_ubuntu1_partial_checkpoint_materialization_witness"
RUN_ID="${V61BU_RUN_ID:-witness_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT="${V61BU_WAREHOUSE_ROOT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"

if [[ "${V61BU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bu_ubuntu1_partial_checkpoint_materialization_witness_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BQ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bq_ubuntu1_payload_execution_receipt_intake.sh" >/dev/null
V61T_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null

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


v61bq_dir = results / "v61bq_ubuntu1_payload_execution_receipt_intake" / "intake_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61bq_summary_path = results / "v61bq_ubuntu1_payload_execution_receipt_intake_summary.csv"
v61t_summary_path = results / "v61t_local_checkpoint_materialization_verifier_summary.csv"
v61bq_summary = read_csv(v61bq_summary_path)[0]
v61t_summary = read_csv(v61t_summary_path)[0]

if v61bq_summary.get("v61bq_ubuntu1_payload_execution_receipt_intake_ready") != "1":
    raise SystemExit("v61bu requires v61bq_ubuntu1_payload_execution_receipt_intake_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61bu requires v61t_local_checkpoint_materialization_verifier_ready=1")

for src, rel in [
    (v61bq_summary_path, "source_v61bq/v61bq_ubuntu1_payload_execution_receipt_intake_summary.csv"),
    (results / "v61bq_ubuntu1_payload_execution_receipt_intake_decision.csv", "source_v61bq/v61bq_ubuntu1_payload_execution_receipt_intake_decision.csv"),
    (v61bq_dir / "ubuntu1_payload_execution_live_presence_rows.csv", "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv"),
    (v61bq_dir / "ubuntu1_payload_execution_receipt_status_rows.csv", "source_v61bq/ubuntu1_payload_execution_receipt_status_rows.csv"),
    (v61bq_dir / "ubuntu1_payload_execution_receipt_metric_rows.csv", "source_v61bq/ubuntu1_payload_execution_receipt_metric_rows.csv"),
    (v61bq_dir / "sha256_manifest.csv", "source_v61bq/sha256_manifest.csv"),
    (v61t_summary_path, "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_decision.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv"),
    (v61t_dir / "local_checkpoint_materialization_rows.csv", "source_v61t/local_checkpoint_materialization_rows.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "sampled_local_page_hash_verification_rows.csv", "source_v61t/sampled_local_page_hash_verification_rows.csv"),
    (v61t_dir / "materialization_gap_rows.csv", "source_v61t/materialization_gap_rows.csv"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
]:
    copy(src, rel)

live_rows = read_csv(v61bq_dir / "ubuntu1_payload_execution_live_presence_rows.csv")
receipt_rows = read_csv(v61bq_dir / "ubuntu1_payload_execution_receipt_status_rows.csv")
materialization_rows = read_csv(v61t_dir / "local_checkpoint_materialization_rows.csv")
if len(live_rows) != 59 or len(receipt_rows) != 59 or len(materialization_rows) != 59:
    raise SystemExit("v61bu expects 59-row v61bq/v61t source surfaces")

live_by_shard = {row["shard_name"]: row for row in live_rows}
receipt_by_shard = {row["shard_name"]: row for row in receipt_rows}

witness_rows = []
for row in materialization_rows:
    live = live_by_shard[row["shard_name"]]
    receipt = receipt_by_shard[row["shard_name"]]
    if live["local_file_exists"] == "0" and row["local_file_exists"] == "0":
        continue
    witness_rows.append(
        {
            "partial_witness_row_id": f"v61bu-witness-{int(row['shard_index']):04d}",
            "model_id": model_id,
            "shard_index": row["shard_index"],
            "shard_name": row["shard_name"],
            "priority_rank": live["priority_rank"],
            "priority_class": receipt["priority_class"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "actual_bytes": row["actual_bytes"],
            "live_size_match": live["size_match"],
            "local_header_hash_match": row["local_header_hash_match"],
            "sampled_page_hash_match": row["sampled_page_hash_match"],
            "local_identity_verified": row["local_identity_verified"],
            "materialization_status": row["materialization_status"],
            "receipt_accepted": receipt["receipt_accepted"],
            "observed_external_checkpoint_payload_bytes": row["actual_bytes"] if row["local_identity_verified"] == "1" else "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

if not witness_rows:
    witness_rows.append(
        {
            "partial_witness_row_id": "v61bu-witness-none",
            "model_id": model_id,
            "shard_index": "0",
            "shard_name": "none",
            "priority_rank": "0",
            "priority_class": "none",
            "target_path": warehouse_root,
            "expected_bytes": "0",
            "actual_bytes": "0",
            "live_size_match": "0",
            "local_header_hash_match": "0",
            "sampled_page_hash_match": "0",
            "local_identity_verified": "0",
            "materialization_status": "no-live-full-shard",
            "receipt_accepted": "0",
            "observed_external_checkpoint_payload_bytes": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

write_csv(run_dir / "partial_checkpoint_materialization_witness_rows.csv", list(witness_rows[0].keys()), witness_rows)

expected_shards = int(v61t_summary["checkpoint_shard_rows"])
total_expected_bytes = int(v61t_summary["total_checkpoint_bytes_expected"])
live_existing = int(v61bq_summary["live_existing_shard_rows"])
live_size_match = int(v61bq_summary["live_size_match_shard_rows"])
accepted_receipts = int(v61bq_summary["accepted_payload_execution_receipt_rows"])
missing_receipts = int(v61bq_summary["missing_payload_execution_receipt_rows"])
local_existing = int(v61t_summary["local_existing_shard_rows"])
local_size_match = int(v61t_summary["local_size_match_shard_rows"])
local_header_match = int(v61t_summary["local_header_hash_match_shard_rows"])
local_identity = int(v61t_summary["local_identity_verified_shard_rows"])
local_identity_bytes = int(v61t_summary["local_identity_verified_bytes"])
remaining_shards = expected_shards - local_identity
remaining_bytes = total_expected_bytes - local_identity_bytes
partial_witness_ready = int(local_identity > 0)
full_checkpoint_materialization_ready = int(local_identity == expected_shards)

requirement_rows = [
    {
        "requirement_id": "v61bq-live-presence-input",
        "status": "pass",
        "required_value": "v61bq ready",
        "actual_value": v61bq_summary["v61bq_ubuntu1_payload_execution_receipt_intake_ready"],
        "reason": "live ubuntu-1 target file status is bound",
    },
    {
        "requirement_id": "v61t-identity-verifier-input",
        "status": "pass",
        "required_value": "v61t ready",
        "actual_value": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
        "reason": "safetensors header and identity checks are bound",
    },
    {
        "requirement_id": "partial-shard-materialization-witness",
        "status": "pass" if partial_witness_ready else "blocked",
        "required_value": ">=1 identity-verified shard",
        "actual_value": str(local_identity),
        "reason": "records actual local full-shard payload only when safetensors identity verification passes",
    },
    {
        "requirement_id": "receipt-backed-full-materialization",
        "status": "pass" if accepted_receipts == expected_shards and full_checkpoint_materialization_ready else "blocked",
        "required_value": "59 accepted receipts and 59 identity-verified shards",
        "actual_value": f"receipts={accepted_receipts}/59; identity={local_identity}/59",
        "reason": "full promotion waits for both returned receipts and identity verification",
    },
    {
        "requirement_id": "full-page-hash-coverage",
        "status": "pass" if v61t_summary["full_safetensors_page_hash_binding_ready"] == "1" else "blocked",
        "required_value": "134161 verified page hashes",
        "actual_value": v61t_summary["full_page_hash_verified_rows"],
        "reason": "partial shard identity is not full safetensors page-hash coverage",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": "blocked",
        "required_value": "materialization + page hashes + review return + generation rows",
        "actual_value": "0",
        "reason": "v61bu is a partial materialization witness, not a generation runner",
    },
]
write_csv(run_dir / "partial_checkpoint_materialization_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bu_partial_checkpoint_materialization_witness_metrics",
    "model_id": model_id,
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": v61bq_summary["v61bq_ubuntu1_payload_execution_receipt_intake_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "target_root_path": warehouse_root,
    "checkpoint_shard_rows": str(expected_shards),
    "total_checkpoint_bytes_expected": str(total_expected_bytes),
    "live_existing_shard_rows": str(live_existing),
    "live_size_match_shard_rows": str(live_size_match),
    "accepted_payload_execution_receipt_rows": str(accepted_receipts),
    "missing_payload_execution_receipt_rows": str(missing_receipts),
    "local_existing_shard_rows": str(local_existing),
    "local_size_match_shard_rows": str(local_size_match),
    "local_header_hash_match_shard_rows": str(local_header_match),
    "local_identity_verified_shard_rows": str(local_identity),
    "local_identity_verified_bytes": str(local_identity_bytes),
    "remaining_identity_unverified_shard_rows": str(remaining_shards),
    "remaining_identity_unverified_bytes": str(remaining_bytes),
    "partial_checkpoint_materialization_witness_ready": str(partial_witness_ready),
    "full_checkpoint_materialization_ready": str(full_checkpoint_materialization_ready),
    "full_safetensors_page_hash_binding_ready": v61t_summary["full_safetensors_page_hash_binding_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bu": "0",
    "observed_external_checkpoint_payload_bytes": str(local_identity_bytes),
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "partial_checkpoint_materialization_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("partial-shard-materialization-witness", "ready" if partial_witness_ready else "blocked", f"identity_verified={local_identity}/59"),
    ("receipt-backed-full-materialization", "ready" if accepted_receipts == expected_shards and full_checkpoint_materialization_ready else "blocked", f"receipts={accepted_receipts}/59; identity={local_identity}/59"),
    ("full-safetensors-page-hash-binding", "ready" if metric["full_safetensors_page_hash_binding_ready"] == "1" else "blocked", f"verified_page_hash_rows={v61t_summary['full_page_hash_verified_rows']}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bq-live-presence-input", "status": "pass", "reason": "v61bq live target evidence is bound"},
    {"gate": "v61t-identity-verifier-input", "status": "pass", "reason": "v61t local identity evidence is bound"},
    {"gate": "partial-shard-materialization-witness", "status": "pass" if partial_witness_ready else "blocked", "reason": f"local_identity_verified_shard_rows={local_identity}/59"},
    {"gate": "receipt-backed-full-materialization", "status": "pass" if accepted_receipts == expected_shards and full_checkpoint_materialization_ready else "blocked", "reason": f"accepted_receipts={accepted_receipts}/59; local_identity={local_identity}/59"},
    {"gate": "full-safetensors-page-hash-binding", "status": "pass" if metric["full_safetensors_page_hash_binding_ready"] == "1" else "blocked", "reason": f"full_page_hash_verified_rows={v61t_summary['full_page_hash_verified_rows']}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bu writes metadata only; checkpoint payload stays outside the repo"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bu Ubuntu-1 Partial Checkpoint Materialization Witness Boundary

This gate records current ubuntu-1 full-shard payload evidence after v61bp
operator execution. It accepts only live files that v61t verifies by size,
safetensors header hash, and any required sampled page hash. It does not
download checkpoint payload bytes and does not commit checkpoint payload bytes
to the repository.

Evidence emitted:

- live_existing_shard_rows={live_existing}
- live_size_match_shard_rows={live_size_match}
- accepted_payload_execution_receipt_rows={accepted_receipts}
- local_existing_shard_rows={local_existing}
- local_size_match_shard_rows={local_size_match}
- local_header_hash_match_shard_rows={local_header_match}
- local_identity_verified_shard_rows={local_identity}
- local_identity_verified_bytes={local_identity_bytes}
- remaining_identity_unverified_shard_rows={remaining_shards}
- partial_checkpoint_materialization_witness_ready={partial_witness_ready}
- full_checkpoint_materialization_ready={full_checkpoint_materialization_ready}
- full_safetensors_page_hash_binding_ready={metric['full_safetensors_page_hash_binding_ready']}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bu=0
- observed_external_checkpoint_payload_bytes={local_identity_bytes}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: partial ubuntu-1 checkpoint shard materialization witness.
Blocked wording: full checkpoint materialization, full page-hash coverage,
actual model generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61BU_UBUNTU1_PARTIAL_CHECKPOINT_MATERIALIZATION_WITNESS_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bu_ubuntu1_partial_checkpoint_materialization_witness",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": 1,
    "source_v61bq_summary_sha256": sha256(v61bq_summary_path),
    "source_v61t_summary_sha256": sha256(v61t_summary_path),
    "local_identity_verified_shard_rows": local_identity,
    "local_identity_verified_bytes": local_identity_bytes,
    "partial_checkpoint_materialization_witness_ready": partial_witness_ready,
    "full_checkpoint_materialization_ready": full_checkpoint_materialization_ready,
    "observed_external_checkpoint_payload_bytes": local_identity_bytes,
    "checkpoint_payload_bytes_downloaded_by_v61bu": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bu_ubuntu1_partial_checkpoint_materialization_witness_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bu_ubuntu1_partial_checkpoint_materialization_witness_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
