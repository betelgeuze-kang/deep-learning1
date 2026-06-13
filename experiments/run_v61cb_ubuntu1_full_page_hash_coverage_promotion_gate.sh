#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cb_ubuntu1_full_page_hash_coverage_promotion_gate"
RUN_ID="${V61CB_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ca_ubuntu1_remaining_page_hash_result_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v61ca_dir = results / "v61ca_ubuntu1_remaining_page_hash_result_intake" / "intake_001"
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


v61ca_summary_path = results / "v61ca_ubuntu1_remaining_page_hash_result_intake_summary.csv"
v61ca_decision_path = results / "v61ca_ubuntu1_remaining_page_hash_result_intake_decision.csv"
v61ca_summary = read_csv(v61ca_summary_path)[0]
if v61ca_summary.get("v61ca_ubuntu1_remaining_page_hash_result_intake_ready") != "1":
    raise SystemExit("v61cb requires v61ca_ubuntu1_remaining_page_hash_result_intake_ready=1")

for src, rel in [
    (v61ca_summary_path, "source_v61ca/v61ca_ubuntu1_remaining_page_hash_result_intake_summary.csv"),
    (v61ca_decision_path, "source_v61ca/v61ca_ubuntu1_remaining_page_hash_result_intake_decision.csv"),
    (v61ca_dir / "remaining_page_hash_result_chunk_status_rows.csv", "source_v61ca/remaining_page_hash_result_chunk_status_rows.csv"),
    (v61ca_dir / "existing_page_hash_preservation_rows.csv", "source_v61ca/existing_page_hash_preservation_rows.csv"),
    (v61ca_dir / "remaining_page_hash_result_validation_rows.csv", "source_v61ca/remaining_page_hash_result_validation_rows.csv"),
    (v61ca_dir / "remaining_page_hash_result_metric_rows.csv", "source_v61ca/remaining_page_hash_result_metric_rows.csv"),
    (v61ca_dir / "runtime_gap_rows.csv", "source_v61ca/runtime_gap_rows.csv"),
    (v61ca_dir / "sha256_manifest.csv", "source_v61ca/sha256_manifest.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v61ca_dir / "remaining_page_hash_result_chunk_status_rows.csv")
preservation_rows = read_csv(v61ca_dir / "existing_page_hash_preservation_rows.csv")
if not preservation_rows:
    raise SystemExit("v61cb requires v61ca existing preservation rows")

remaining_by_shard = defaultdict(
    lambda: {
        "model_id": model_id,
        "target_path": "",
        "planned_page_hash_rows": 0,
        "accepted_page_hash_rows": 0,
        "invalid_page_hash_rows": 0,
        "missing_page_hash_rows": 0,
        "chunk_rows": 0,
    }
)
for row in chunk_rows:
    shard = row["shard_name"]
    agg = remaining_by_shard[shard]
    agg["target_path"] = row["target_path"]
    agg["planned_page_hash_rows"] += int(row["planned_page_hash_rows"])
    agg["accepted_page_hash_rows"] += int(row["accepted_page_hash_rows"])
    agg["invalid_page_hash_rows"] += int(row["invalid_page_hash_rows"])
    agg["missing_page_hash_rows"] += int(row["missing_page_hash_rows"])
    agg["chunk_rows"] += 1

existing_by_shard = {}
for row in preservation_rows:
    if row["shard_name"] == "none":
        continue
    existing_by_shard[row["shard_name"]] = row

all_shards = sorted(set(existing_by_shard).union(remaining_by_shard))
promotion_rows = []
ready_shard_rows = 0
blocked_shard_rows = 0
existing_verified_page_hash_shard_rows = 0
remaining_page_hash_shard_rows = 0
promotion_ready_page_hash_rows = 0
promotion_missing_page_hash_rows = 0
promotion_invalid_page_hash_rows = 0

for index, shard in enumerate(all_shards):
    existing = existing_by_shard.get(shard)
    remaining = remaining_by_shard.get(shard)
    existing_verified_rows = int(existing["verified_page_hash_rows"]) if existing else 0
    existing_verified_bytes = int(existing["verified_page_hash_bytes"]) if existing else 0
    accepted_remaining_rows = remaining["accepted_page_hash_rows"] if remaining else 0
    missing_remaining_rows = remaining["missing_page_hash_rows"] if remaining else 0
    invalid_remaining_rows = remaining["invalid_page_hash_rows"] if remaining else 0
    planned_remaining_rows = remaining["planned_page_hash_rows"] if remaining else 0
    chunk_count = remaining["chunk_rows"] if remaining else 0
    target_path = (existing or {}).get("target_path") or (remaining or {}).get("target_path", "")
    total_verified_rows = existing_verified_rows + accepted_remaining_rows
    full_shard_ready = int((planned_remaining_rows == 0 or (accepted_remaining_rows == planned_remaining_rows and missing_remaining_rows == 0 and invalid_remaining_rows == 0)) and existing_verified_rows + planned_remaining_rows > 0)
    if full_shard_ready:
        ready_shard_rows += 1
        status = "ready-existing-page-hash-witness" if planned_remaining_rows == 0 else "ready-accepted-remaining-page-hash-results"
    else:
        blocked_shard_rows += 1
        status = "blocked-missing-remaining-page-hash-results"
    if existing_verified_rows > 0:
        existing_verified_page_hash_shard_rows += 1
    if planned_remaining_rows > 0:
        remaining_page_hash_shard_rows += 1
    promotion_ready_page_hash_rows += total_verified_rows
    promotion_missing_page_hash_rows += missing_remaining_rows
    promotion_invalid_page_hash_rows += invalid_remaining_rows
    promotion_rows.append(
        {
            "promotion_row_id": f"v61cb-page-hash-promotion-{index:04d}",
            "model_id": model_id,
            "shard_name": shard,
            "target_path": target_path,
            "existing_verified_page_hash_rows": str(existing_verified_rows),
            "existing_verified_page_hash_bytes": str(existing_verified_bytes),
            "planned_remaining_page_hash_rows": str(planned_remaining_rows),
            "accepted_remaining_page_hash_rows": str(accepted_remaining_rows),
            "invalid_remaining_page_hash_rows": str(invalid_remaining_rows),
            "missing_remaining_page_hash_rows": str(missing_remaining_rows),
            "remaining_page_hash_chunk_rows": str(chunk_count),
            "total_verified_page_hash_rows": str(total_verified_rows),
            "full_shard_page_hash_coverage_ready": str(full_shard_ready),
            "promotion_status": status,
            "checkpoint_payload_bytes_downloaded_by_v61cb": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "full_page_hash_coverage_promotion_rows.csv", list(promotion_rows[0].keys()), promotion_rows)

total_required_page_hash_rows = int(v61ca_summary["total_required_page_hash_rows"])
expected_remaining_page_hash_rows = int(v61ca_summary["expected_remaining_page_hash_result_rows"])
accepted_remaining_page_hash_rows = int(v61ca_summary["accepted_remaining_page_hash_result_rows"])
missing_remaining_page_hash_rows = int(v61ca_summary["missing_remaining_page_hash_result_rows"])
existing_verified_page_hash_rows = int(v61ca_summary["existing_verified_page_hash_rows"])
total_verified_page_hash_rows = int(v61ca_summary["total_verified_page_hash_rows"])
promotion_total_verified_rows = sum(int(row["total_verified_page_hash_rows"]) for row in promotion_rows)
promotion_total_missing_rows = sum(int(row["missing_remaining_page_hash_rows"]) for row in promotion_rows)
full_coverage_ready = int(
    total_verified_page_hash_rows == total_required_page_hash_rows
    and missing_remaining_page_hash_rows == 0
    and promotion_total_verified_rows == total_required_page_hash_rows
    and blocked_shard_rows == 0
)
promotion_gate_ready = int(full_coverage_ready)

requirement_rows = [
    {
        "requirement_id": "v61ca-result-intake-input",
        "status": "pass",
        "required_value": "v61ca ready",
        "actual_value": v61ca_summary["v61ca_ubuntu1_remaining_page_hash_result_intake_ready"],
        "reason": "remaining page-hash result intake is bound",
    },
    {
        "requirement_id": "remaining-page-hash-result-intake-ready",
        "status": "pass" if v61ca_summary["remaining_page_hash_result_intake_ready"] == "1" else "blocked",
        "required_value": str(expected_remaining_page_hash_rows),
        "actual_value": str(accepted_remaining_page_hash_rows),
        "reason": "all remaining page-hash results must be accepted",
    },
    {
        "requirement_id": "all-shard-page-hash-coverage-ready",
        "status": "pass" if blocked_shard_rows == 0 else "blocked",
        "required_value": str(len(promotion_rows)),
        "actual_value": str(ready_shard_rows),
        "reason": "each checkpoint shard must have complete page-hash coverage",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "pass" if full_coverage_ready else "blocked",
        "required_value": str(total_required_page_hash_rows),
        "actual_value": str(total_verified_page_hash_rows),
        "reason": "verified page hashes must cover every checkpoint page",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "promotion gate stores metadata and hash evidence only",
    },
]
write_csv(run_dir / "full_page_hash_coverage_promotion_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_metrics",
    "model_id": model_id,
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": v61ca_summary["v61ca_ubuntu1_remaining_page_hash_result_intake_ready"],
    "target_root_path": v61ca_summary["target_root_path"],
    "checkpoint_shard_rows": str(len(promotion_rows)),
    "ready_full_page_hash_shard_rows": str(ready_shard_rows),
    "blocked_full_page_hash_shard_rows": str(blocked_shard_rows),
    "existing_verified_page_hash_shard_rows": str(existing_verified_page_hash_shard_rows),
    "remaining_page_hash_shard_rows": str(remaining_page_hash_shard_rows),
    "expected_remaining_page_hash_result_rows": str(expected_remaining_page_hash_rows),
    "accepted_remaining_page_hash_result_rows": str(accepted_remaining_page_hash_rows),
    "missing_remaining_page_hash_result_rows": str(missing_remaining_page_hash_rows),
    "invalid_remaining_page_hash_result_rows": v61ca_summary["invalid_remaining_page_hash_result_rows"],
    "existing_verified_page_hash_rows": str(existing_verified_page_hash_rows),
    "total_required_page_hash_rows": str(total_required_page_hash_rows),
    "total_verified_page_hash_rows": str(total_verified_page_hash_rows),
    "promotion_total_verified_page_hash_rows": str(promotion_total_verified_rows),
    "promotion_missing_page_hash_rows": str(promotion_total_missing_rows),
    "promotion_invalid_page_hash_rows": str(promotion_invalid_page_hash_rows),
    "full_page_hash_coverage_promotion_ready": str(promotion_gate_ready),
    "completed_full_safetensors_page_hash_coverage_ready": str(full_coverage_ready),
    "full_safetensors_page_hash_binding_ready": str(full_coverage_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "full_page_hash_coverage_promotion_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61ca-result-intake-input", "ready", "v61ca result intake is bound"),
    ("remaining-page-hash-result-intake-ready", "ready" if v61ca_summary["remaining_page_hash_result_intake_ready"] == "1" else "blocked", f"accepted_remaining_page_hash_result_rows={accepted_remaining_page_hash_rows}"),
    ("all-shard-page-hash-coverage-ready", "ready" if blocked_shard_rows == 0 else "blocked", f"ready_full_page_hash_shard_rows={ready_shard_rows}"),
    ("completed-full-safetensors-page-hash-coverage", "ready" if full_coverage_ready else "blocked", f"total_verified_page_hash_rows={total_verified_page_hash_rows}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "no production latency run"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ca-result-intake-input", "status": "pass", "reason": "v61ca result intake is bound"},
    {"gate": "existing-page-hash-preservation", "status": "pass", "reason": f"existing_verified_page_hash_rows={existing_verified_page_hash_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cb writes metadata and hash evidence only"},
    {"gate": "remaining-page-hash-result-intake-ready", "status": "pass" if v61ca_summary["remaining_page_hash_result_intake_ready"] == "1" else "blocked", "reason": f"accepted_remaining_page_hash_result_rows={accepted_remaining_page_hash_rows}"},
    {"gate": "all-shard-page-hash-coverage-ready", "status": "pass" if blocked_shard_rows == 0 else "blocked", "reason": f"blocked_full_page_hash_shard_rows={blocked_shard_rows}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if full_coverage_ready else "blocked", "reason": f"total_verified_page_hash_rows={total_verified_page_hash_rows}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cb Ubuntu-1 Full Page-Hash Coverage Promotion Gate Boundary

This gate promotes v61ca accepted page-hash result rows into a full-checkpoint
coverage decision. It does not execute page hashing, does not download
checkpoint payload bytes, and does not commit checkpoint payload bytes to the
repository.

Evidence emitted:

- checkpoint_shard_rows={len(promotion_rows)}
- ready_full_page_hash_shard_rows={ready_shard_rows}
- blocked_full_page_hash_shard_rows={blocked_shard_rows}
- existing_verified_page_hash_shard_rows={existing_verified_page_hash_shard_rows}
- remaining_page_hash_shard_rows={remaining_page_hash_shard_rows}
- expected_remaining_page_hash_result_rows={expected_remaining_page_hash_rows}
- accepted_remaining_page_hash_result_rows={accepted_remaining_page_hash_rows}
- missing_remaining_page_hash_result_rows={missing_remaining_page_hash_rows}
- existing_verified_page_hash_rows={existing_verified_page_hash_rows}
- total_required_page_hash_rows={total_required_page_hash_rows}
- total_verified_page_hash_rows={total_verified_page_hash_rows}
- full_page_hash_coverage_promotion_ready={promotion_gate_ready}
- completed_full_safetensors_page_hash_coverage_ready={full_coverage_ready}
- full_safetensors_page_hash_binding_ready={full_coverage_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cb=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: full page-hash coverage promotion gate with default blocked
coverage. Blocked wording: completed full safetensors page-hash coverage,
actual model generation, production latency, near-frontier quality, or release
readiness until all remaining page-hash result rows are accepted.
"""
(run_dir / "V61CB_UBUNTU1_FULL_PAGE_HASH_COVERAGE_PROMOTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": 1,
    "source_v61ca_summary_sha256": sha256(v61ca_summary_path),
    "checkpoint_shard_rows": len(promotion_rows),
    "ready_full_page_hash_shard_rows": ready_shard_rows,
    "blocked_full_page_hash_shard_rows": blocked_shard_rows,
    "total_required_page_hash_rows": total_required_page_hash_rows,
    "total_verified_page_hash_rows": total_verified_page_hash_rows,
    "full_safetensors_page_hash_binding_ready": full_coverage_ready,
    "checkpoint_payload_bytes_downloaded_by_v61cb": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
