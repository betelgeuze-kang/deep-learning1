#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate"
RUN_ID="${V61CM_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake.sh" >/dev/null

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
v61cl_dir = results / "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake" / "intake_001"
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


v61cl_summary_path = results / "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_summary.csv"
v61cl_decision_path = results / "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_decision.csv"
v61cl_summary = read_csv(v61cl_summary_path)[0]
if v61cl_summary.get("v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready") != "1":
    raise SystemExit("v61cm requires v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready=1")

for src, rel in [
    (v61cl_summary_path, "source_v61cl/v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_summary.csv"),
    (v61cl_decision_path, "source_v61cl/v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_decision.csv"),
    (v61cl_dir / "remaining_checkpoint_materialization_return_queue_status_rows.csv", "source_v61cl/remaining_checkpoint_materialization_return_queue_status_rows.csv"),
    (v61cl_dir / "remaining_checkpoint_materialization_return_chunk_status_rows.csv", "source_v61cl/remaining_checkpoint_materialization_return_chunk_status_rows.csv"),
    (v61cl_dir / "existing_checkpoint_materialization_preservation_rows.csv", "source_v61cl/existing_checkpoint_materialization_preservation_rows.csv"),
    (v61cl_dir / "remaining_checkpoint_materialization_return_validation_rows.csv", "source_v61cl/remaining_checkpoint_materialization_return_validation_rows.csv"),
    (v61cl_dir / "remaining_checkpoint_materialization_return_metric_rows.csv", "source_v61cl/remaining_checkpoint_materialization_return_metric_rows.csv"),
    (v61cl_dir / "runtime_gap_rows.csv", "source_v61cl/runtime_gap_rows.csv"),
    (v61cl_dir / "sha256_manifest.csv", "source_v61cl/sha256_manifest.csv"),
]:
    copy(src, rel)

queue_status_rows = read_csv(v61cl_dir / "remaining_checkpoint_materialization_return_queue_status_rows.csv")
preservation_rows = [row for row in read_csv(v61cl_dir / "existing_checkpoint_materialization_preservation_rows.csv") if row["shard_name"] != "none"]
if not queue_status_rows and not preservation_rows:
    raise SystemExit("v61cm requires v61cl queue status rows or preservation rows")

remaining_by_shard = {row["shard_name"]: row for row in queue_status_rows}
existing_by_shard = {row["shard_name"]: row for row in preservation_rows}
all_shards = sorted(set(existing_by_shard).union(remaining_by_shard))

promotion_rows = []
ready_shard_rows = 0
blocked_shard_rows = 0
existing_identity_verified_shard_rows = 0
remaining_materialization_shard_rows = 0
promotion_identity_verified_bytes = 0
promotion_missing_materialization_bytes = 0
promotion_invalid_return_rows = 0

for index, shard in enumerate(all_shards):
    existing = existing_by_shard.get(shard)
    remaining = remaining_by_shard.get(shard)
    existing_bytes = int(existing["identity_verified_bytes"]) if existing else 0
    planned_remaining_rows = 1 if remaining else 0
    accepted_remaining_rows = int(remaining["accepted_return_rows"]) if remaining else 0
    invalid_remaining_rows = int(remaining["invalid_return_rows"]) if remaining else 0
    missing_remaining_rows = int(remaining["missing_return_rows"]) if remaining else 0
    expected_remaining_bytes = int(remaining["expected_bytes"]) if remaining else 0
    accepted_remaining_bytes = int(remaining["accepted_bytes"]) if remaining else 0
    missing_remaining_bytes = int(remaining["missing_bytes"]) if remaining else 0
    target_path = (existing or {}).get("target_path") or (remaining or {}).get("target_path", "")
    identity_verified_bytes = existing_bytes + accepted_remaining_bytes
    full_shard_ready = int(
        existing_bytes > 0
        or (
            planned_remaining_rows > 0
            and accepted_remaining_rows == planned_remaining_rows
            and missing_remaining_rows == 0
            and invalid_remaining_rows == 0
            and accepted_remaining_bytes == expected_remaining_bytes
        )
    )
    if full_shard_ready:
        ready_shard_rows += 1
        status = "ready-existing-identity-verified-shard" if existing_bytes > 0 else "ready-accepted-materialization-return"
    else:
        blocked_shard_rows += 1
        status = "blocked-missing-materialization-return"
    if existing_bytes > 0:
        existing_identity_verified_shard_rows += 1
    if planned_remaining_rows > 0:
        remaining_materialization_shard_rows += 1
    promotion_identity_verified_bytes += identity_verified_bytes
    promotion_missing_materialization_bytes += missing_remaining_bytes
    promotion_invalid_return_rows += invalid_remaining_rows
    promotion_rows.append(
        {
            "promotion_row_id": f"v61cm-checkpoint-materialization-promotion-{index:04d}",
            "model_id": model_id,
            "shard_name": shard,
            "target_path": target_path,
            "existing_identity_verified_bytes": str(existing_bytes),
            "planned_remaining_materialization_return_rows": str(planned_remaining_rows),
            "accepted_remaining_materialization_return_rows": str(accepted_remaining_rows),
            "invalid_remaining_materialization_return_rows": str(invalid_remaining_rows),
            "missing_remaining_materialization_return_rows": str(missing_remaining_rows),
            "expected_remaining_materialization_bytes": str(expected_remaining_bytes),
            "accepted_remaining_materialization_bytes": str(accepted_remaining_bytes),
            "missing_remaining_materialization_bytes": str(missing_remaining_bytes),
            "identity_verified_bytes": str(identity_verified_bytes),
            "full_shard_materialization_ready": str(full_shard_ready),
            "promotion_status": status,
            "checkpoint_payload_bytes_downloaded_by_v61cm": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "full_checkpoint_materialization_promotion_rows.csv", list(promotion_rows[0].keys()), promotion_rows)

total_required_checkpoint_shard_rows = int(v61cl_summary["total_required_checkpoint_shard_rows"])
expected_remaining_return_rows = int(v61cl_summary["expected_remaining_materialization_return_rows"])
accepted_remaining_return_rows = int(v61cl_summary["accepted_remaining_materialization_return_rows"])
missing_remaining_return_rows = int(v61cl_summary["missing_remaining_materialization_return_rows"])
expected_remaining_bytes = int(v61cl_summary["expected_remaining_materialization_bytes"])
accepted_remaining_bytes = int(v61cl_summary["accepted_remaining_materialization_bytes"])
missing_remaining_bytes = int(v61cl_summary["missing_remaining_materialization_bytes"])
existing_verified_checkpoint_shard_rows = int(v61cl_summary["existing_verified_checkpoint_shard_rows"])
existing_verified_checkpoint_shard_bytes = int(v61cl_summary["existing_verified_checkpoint_shard_bytes"])
total_identity_verified_checkpoint_shard_rows = int(v61cl_summary["total_identity_verified_checkpoint_shard_rows"])
full_materialization_ready = int(
    total_identity_verified_checkpoint_shard_rows == total_required_checkpoint_shard_rows
    and missing_remaining_return_rows == 0
    and missing_remaining_bytes == 0
    and blocked_shard_rows == 0
)
promotion_gate_ready = int(full_materialization_ready)

requirement_rows = [
    {
        "requirement_id": "v61cl-return-intake-input",
        "status": "pass",
        "required_value": "v61cl ready",
        "actual_value": v61cl_summary["v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready"],
        "reason": "remaining materialization return intake is bound",
    },
    {
        "requirement_id": "remaining-materialization-return-intake-ready",
        "status": "pass" if v61cl_summary["remaining_materialization_return_intake_ready"] == "1" else "blocked",
        "required_value": str(expected_remaining_return_rows),
        "actual_value": str(accepted_remaining_return_rows),
        "reason": "all remaining materialization returns must be accepted",
    },
    {
        "requirement_id": "all-shard-checkpoint-materialization-ready",
        "status": "pass" if blocked_shard_rows == 0 else "blocked",
        "required_value": str(len(promotion_rows)),
        "actual_value": str(ready_shard_rows),
        "reason": "each checkpoint shard must be identity-verified or have an accepted materialization return",
    },
    {
        "requirement_id": "completed-full-checkpoint-materialization",
        "status": "pass" if full_materialization_ready else "blocked",
        "required_value": str(total_required_checkpoint_shard_rows),
        "actual_value": str(total_identity_verified_checkpoint_shard_rows),
        "reason": "identity-verified shards must cover every checkpoint shard",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "promotion gate stores metadata and receipt evidence only",
    },
]
write_csv(run_dir / "full_checkpoint_materialization_promotion_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_metrics",
    "model_id": model_id,
    "v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready": v61cl_summary["v61cl_ubuntu1_remaining_checkpoint_materialization_return_intake_ready"],
    "target_root_path": v61cl_summary["target_root_path"],
    "checkpoint_shard_rows": str(len(promotion_rows)),
    "ready_checkpoint_materialization_shard_rows": str(ready_shard_rows),
    "blocked_checkpoint_materialization_shard_rows": str(blocked_shard_rows),
    "existing_identity_verified_checkpoint_shard_rows": str(existing_identity_verified_shard_rows),
    "remaining_materialization_shard_rows": str(remaining_materialization_shard_rows),
    "expected_remaining_materialization_return_rows": str(expected_remaining_return_rows),
    "accepted_remaining_materialization_return_rows": str(accepted_remaining_return_rows),
    "missing_remaining_materialization_return_rows": str(missing_remaining_return_rows),
    "invalid_remaining_materialization_return_rows": v61cl_summary["invalid_remaining_materialization_return_rows"],
    "expected_remaining_materialization_bytes": str(expected_remaining_bytes),
    "accepted_remaining_materialization_bytes": str(accepted_remaining_bytes),
    "missing_remaining_materialization_bytes": str(missing_remaining_bytes),
    "existing_verified_checkpoint_shard_rows": str(existing_verified_checkpoint_shard_rows),
    "existing_verified_checkpoint_shard_bytes": str(existing_verified_checkpoint_shard_bytes),
    "total_required_checkpoint_shard_rows": str(total_required_checkpoint_shard_rows),
    "total_identity_verified_checkpoint_shard_rows": str(total_identity_verified_checkpoint_shard_rows),
    "promotion_identity_verified_bytes": str(promotion_identity_verified_bytes),
    "promotion_missing_materialization_bytes": str(promotion_missing_materialization_bytes),
    "promotion_invalid_materialization_return_rows": str(promotion_invalid_return_rows),
    "full_checkpoint_materialization_promotion_ready": str(promotion_gate_ready),
    "full_checkpoint_materialization_ready": str(full_materialization_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "full_checkpoint_materialization_promotion_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61cl-return-intake-input", "ready", "v61cl return intake is bound"),
    ("remaining-materialization-return-intake-ready", "ready" if v61cl_summary["remaining_materialization_return_intake_ready"] == "1" else "blocked", f"accepted_remaining_materialization_return_rows={accepted_remaining_return_rows}"),
    ("all-shard-checkpoint-materialization-ready", "ready" if blocked_shard_rows == 0 else "blocked", f"ready_checkpoint_materialization_shard_rows={ready_shard_rows}"),
    ("completed-full-checkpoint-materialization", "ready" if full_materialization_ready else "blocked", f"total_identity_verified_checkpoint_shard_rows={total_identity_verified_checkpoint_shard_rows}"),
    ("full-safetensors-page-hash-binding", "blocked", "not a page-hash runner"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "no production latency run"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61cl-return-intake-input", "status": "pass", "reason": "v61cl return intake is bound"},
    {"gate": "existing-checkpoint-materialization-preservation", "status": "pass", "reason": f"existing_verified_checkpoint_shard_rows={existing_verified_checkpoint_shard_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cm writes metadata and receipt evidence only"},
    {"gate": "remaining-materialization-return-intake-ready", "status": "pass" if v61cl_summary["remaining_materialization_return_intake_ready"] == "1" else "blocked", "reason": f"accepted_remaining_materialization_return_rows={accepted_remaining_return_rows}"},
    {"gate": "all-shard-checkpoint-materialization-ready", "status": "pass" if blocked_shard_rows == 0 else "blocked", "reason": f"blocked_checkpoint_materialization_shard_rows={blocked_shard_rows}"},
    {"gate": "completed-full-checkpoint-materialization", "status": "pass" if full_materialization_ready else "blocked", "reason": f"total_identity_verified_checkpoint_shard_rows={total_identity_verified_checkpoint_shard_rows}"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "not a page-hash runner"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cm Ubuntu-1 Full Checkpoint Materialization Promotion Gate Boundary

This gate promotes v61cl accepted materialization return rows into a
full-checkpoint materialization decision. It does not download checkpoint
payload bytes and does not commit checkpoint payload bytes to the repository.

Evidence emitted:

- checkpoint_shard_rows={len(promotion_rows)}
- ready_checkpoint_materialization_shard_rows={ready_shard_rows}
- blocked_checkpoint_materialization_shard_rows={blocked_shard_rows}
- existing_identity_verified_checkpoint_shard_rows={existing_identity_verified_shard_rows}
- remaining_materialization_shard_rows={remaining_materialization_shard_rows}
- expected_remaining_materialization_return_rows={expected_remaining_return_rows}
- accepted_remaining_materialization_return_rows={accepted_remaining_return_rows}
- missing_remaining_materialization_return_rows={missing_remaining_return_rows}
- expected_remaining_materialization_bytes={expected_remaining_bytes}
- accepted_remaining_materialization_bytes={accepted_remaining_bytes}
- missing_remaining_materialization_bytes={missing_remaining_bytes}
- existing_verified_checkpoint_shard_rows={existing_verified_checkpoint_shard_rows}
- total_required_checkpoint_shard_rows={total_required_checkpoint_shard_rows}
- total_identity_verified_checkpoint_shard_rows={total_identity_verified_checkpoint_shard_rows}
- full_checkpoint_materialization_promotion_ready={promotion_gate_ready}
- full_checkpoint_materialization_ready={full_materialization_ready}
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cm=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: full checkpoint materialization promotion gate, including
completed full checkpoint materialization when every shard is identity-verified
or has an accepted materialization return. Blocked wording: full safetensors
page-hash binding, actual model generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61CM_UBUNTU1_FULL_CHECKPOINT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": 1,
    "source_v61cl_summary_sha256": sha256(v61cl_summary_path),
    "checkpoint_shard_rows": len(promotion_rows),
    "ready_checkpoint_materialization_shard_rows": ready_shard_rows,
    "blocked_checkpoint_materialization_shard_rows": blocked_shard_rows,
    "total_required_checkpoint_shard_rows": total_required_checkpoint_shard_rows,
    "total_identity_verified_checkpoint_shard_rows": total_identity_verified_checkpoint_shard_rows,
    "full_checkpoint_materialization_ready": full_materialization_ready,
    "checkpoint_payload_bytes_downloaded_by_v61cm": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
