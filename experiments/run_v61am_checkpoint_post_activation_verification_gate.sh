#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61am_checkpoint_post_activation_verification_gate"
RUN_ID="${V61AM_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61am_checkpoint_post_activation_verification_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61al_checkpoint_warehouse_activation_gate.sh" >/dev/null
V61T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
V61R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null

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


v61al_dir = results / "v61al_checkpoint_warehouse_activation_gate" / "gate_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61r_dir = results / "v61r_full_page_hash_sweep_plan" / "plan_001"

v61al_summary = read_csv(results / "v61al_checkpoint_warehouse_activation_gate_summary.csv")[0]
v61t_summary = read_csv(results / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
v61r_summary = read_csv(results / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
if v61al_summary.get("v61al_checkpoint_warehouse_activation_gate_ready") != "1":
    raise SystemExit("v61am requires v61al_checkpoint_warehouse_activation_gate_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61am requires v61t_local_checkpoint_materialization_verifier_ready=1")
if v61r_summary.get("v61r_full_page_hash_sweep_plan_ready") != "1":
    raise SystemExit("v61am requires v61r_full_page_hash_sweep_plan_ready=1")

for src, rel in [
    (results / "v61al_checkpoint_warehouse_activation_gate_summary.csv", "source_v61al/v61al_checkpoint_warehouse_activation_gate_summary.csv"),
    (results / "v61al_checkpoint_warehouse_activation_gate_decision.csv", "source_v61al/v61al_checkpoint_warehouse_activation_gate_decision.csv"),
    (v61al_dir / "checkpoint_warehouse_activation_command_rows.csv", "source_v61al/checkpoint_warehouse_activation_command_rows.csv"),
    (v61al_dir / "checkpoint_warehouse_activation_gate_rows.csv", "source_v61al/checkpoint_warehouse_activation_gate_rows.csv"),
    (v61al_dir / "checkpoint_warehouse_activation_metric_rows.csv", "source_v61al/checkpoint_warehouse_activation_metric_rows.csv"),
    (v61al_dir / "sha256_manifest.csv", "source_v61al/sha256_manifest.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_summary.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (v61t_dir / "local_checkpoint_materialization_rows.csv", "source_v61t/local_checkpoint_materialization_rows.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
    (results / "v61r_full_page_hash_sweep_plan_summary.csv", "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv"),
    (v61r_dir / "shard_page_hash_sweep_status_rows.csv", "source_v61r/shard_page_hash_sweep_status_rows.csv"),
    (v61r_dir / "page_hash_sweep_metric_rows.csv", "source_v61r/page_hash_sweep_metric_rows.csv"),
    (v61r_dir / "sha256_manifest.csv", "source_v61r/sha256_manifest.csv"),
]:
    copy(src, rel)

activation_rows = read_csv(v61al_dir / "checkpoint_warehouse_activation_command_rows.csv")
materialization_rows = {row["shard_name"]: row for row in read_csv(v61t_dir / "local_checkpoint_materialization_rows.csv")}
hash_status_rows = {row["shard_name"]: row for row in read_csv(v61r_dir / "shard_page_hash_sweep_status_rows.csv")}
if len(activation_rows) != 59 or len(materialization_rows) != 59 or len(hash_status_rows) != 59:
    raise SystemExit("v61am expects 59 activation/materialization/hash status rows")

verification_rows = []
for row in sorted(activation_rows, key=lambda item: int(item["priority_rank"])):
    shard_name = row["shard_name"]
    mat = materialization_rows[shard_name]
    page = hash_status_rows[shard_name]
    activation_admitted = row["activation_admitted"]
    local_identity_verified = mat["local_identity_verified"]
    shard_page_hash_coverage_ready = page["shard_page_hash_coverage_ready"]
    ready = int(activation_admitted == "1" and local_identity_verified == "1" and shard_page_hash_coverage_ready == "1")
    if activation_admitted != "1":
        blocked_reason = "activation-not-admitted"
    elif local_identity_verified != "1":
        blocked_reason = "local-identity-not-verified"
    elif shard_page_hash_coverage_ready != "1":
        blocked_reason = "full-page-hash-not-verified"
    else:
        blocked_reason = "none"
    verification_rows.append({
        "priority_rank": row["priority_rank"],
        "model_id": model_id,
        "shard_name": shard_name,
        "priority_class": row["priority_class"],
        "target_path": row["target_path"],
        "expected_bytes": row["expected_bytes"],
        "activation_admitted": activation_admitted,
        "local_file_exists": mat["local_file_exists"],
        "size_match": mat["size_match"],
        "local_header_hash_match": mat["local_header_hash_match"],
        "sampled_page_hash_match": mat["sampled_page_hash_match"],
        "local_identity_verified": local_identity_verified,
        "planned_page_hash_rows": page["planned_page_hash_rows"],
        "verified_page_hash_rows": page["verified_page_hash_rows"],
        "shard_page_hash_coverage_ready": shard_page_hash_coverage_ready,
        "post_activation_verification_ready": str(ready),
        "blocked_reason": blocked_reason,
        "post_download_verify_command": row["post_download_verify_command"],
        "post_download_full_page_hash_command": row["post_download_full_page_hash_command"],
        "checkpoint_payload_bytes_downloaded_by_v61am": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    })

post_activation_verification_ready_rows = sum(int(row["post_activation_verification_ready"]) for row in verification_rows)
post_activation_verification_blocked_rows = len(verification_rows) - post_activation_verification_ready_rows
activation_admitted_rows = int(v61al_summary["activation_admitted_rows"])
activation_blocked_rows = int(v61al_summary["activation_blocked_rows"])
local_identity_verified_shard_rows = int(v61t_summary["local_identity_verified_shard_rows"])
full_page_hash_coverage_ready_shard_rows = int(v61t_summary["full_page_hash_coverage_ready_shard_rows"])
verified_page_hash_rows = int(v61r_summary["verified_page_hash_rows"])
required_page_hash_rows = int(v61r_summary["checkpoint_unique_page_rows"])

requirement_rows = [
    {
        "requirement_id": "activation-admitted-all-shards",
        "status": "pass" if activation_admitted_rows == 59 else "blocked",
        "required_rows": "59",
        "actual_rows": str(activation_admitted_rows),
        "reason": "all shard activation rows must be admitted before post-download verification",
    },
    {
        "requirement_id": "local-identity-verified-all-shards",
        "status": "pass" if local_identity_verified_shard_rows == 59 else "blocked",
        "required_rows": "59",
        "actual_rows": str(local_identity_verified_shard_rows),
        "reason": "all shards must pass local size/header/sample identity verification",
    },
    {
        "requirement_id": "full-page-hash-coverage-all-pages",
        "status": "pass" if verified_page_hash_rows == required_page_hash_rows else "blocked",
        "required_rows": str(required_page_hash_rows),
        "actual_rows": str(verified_page_hash_rows),
        "reason": "all safetensors checkpoint pages must be locally verified",
    },
    {
        "requirement_id": "generation-gate-after-verification",
        "status": "pass" if post_activation_verification_ready_rows == 59 else "blocked",
        "required_rows": "59",
        "actual_rows": str(post_activation_verification_ready_rows),
        "reason": "real generation remains blocked until activation, identity, and full page hashes pass",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_rows": "0",
        "actual_rows": "0",
        "reason": "v61am emits metadata only",
    },
]

metric = {
    "metric_id": "v61am_checkpoint_post_activation_verification_gate_metrics",
    "model_id": model_id,
    "post_activation_verification_rows": str(len(verification_rows)),
    "post_activation_verification_ready_rows": str(post_activation_verification_ready_rows),
    "post_activation_verification_blocked_rows": str(post_activation_verification_blocked_rows),
    "activation_command_rows": v61al_summary["activation_command_rows"],
    "activation_admitted_rows": str(activation_admitted_rows),
    "activation_blocked_rows": str(activation_blocked_rows),
    "local_identity_verified_shard_rows": str(local_identity_verified_shard_rows),
    "full_page_hash_coverage_ready_shard_rows": str(full_page_hash_coverage_ready_shard_rows),
    "verified_page_hash_rows": str(verified_page_hash_rows),
    "required_page_hash_rows": str(required_page_hash_rows),
    "post_activation_verification_gate_ready": "0",
    "generation_gate_ready_after_post_activation": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61am": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}

write_csv(run_dir / "checkpoint_post_activation_verification_rows.csv", list(verification_rows[0].keys()), verification_rows)
write_csv(run_dir / "checkpoint_post_activation_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)
write_csv(run_dir / "checkpoint_post_activation_metric_rows.csv", list(metric.keys()), [metric])

decision_rows = [
    {"gate": "v61al-activation-input", "status": "pass", "reason": "v61al activation gate is ready"},
    {"gate": "v61t-materialization-input", "status": "pass", "reason": "v61t materialization verifier is ready"},
    {"gate": "v61r-full-page-hash-input", "status": "pass", "reason": "v61r full page-hash sweep plan is ready"},
    {"gate": "activation-admission", "status": "blocked", "reason": f"activation_admitted_rows={activation_admitted_rows}"},
    {"gate": "local-identity-verification", "status": "blocked", "reason": f"local_identity_verified_shard_rows={local_identity_verified_shard_rows}"},
    {"gate": "full-page-hash-verification", "status": "blocked", "reason": f"verified_page_hash_rows={verified_page_hash_rows}/{required_page_hash_rows}"},
    {"gate": "post-activation-generation-gate", "status": "blocked", "reason": f"post_activation_verification_ready_rows={post_activation_verification_ready_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61am emits metadata only"},
    {"gate": "production-latency", "status": "blocked", "reason": "post-activation verification gate is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "post-activation verification gate is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61am_checkpoint_post_activation_verification_gate_ready": "1",
    "v61al_checkpoint_warehouse_activation_gate_ready": v61al_summary["v61al_checkpoint_warehouse_activation_gate_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "v61r_full_page_hash_sweep_plan_ready": v61r_summary["v61r_full_page_hash_sweep_plan_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61am Checkpoint Post-Activation Verification Gate Boundary

This artifact binds activation, local identity verification, and full page-hash
coverage into the required post-download gate before real generation.

Evidence emitted:

- post_activation_verification_rows={len(verification_rows)}
- post_activation_verification_ready_rows={post_activation_verification_ready_rows}
- post_activation_verification_blocked_rows={post_activation_verification_blocked_rows}
- activation_admitted_rows={activation_admitted_rows}
- activation_blocked_rows={activation_blocked_rows}
- local_identity_verified_shard_rows={local_identity_verified_shard_rows}
- full_page_hash_coverage_ready_shard_rows={full_page_hash_coverage_ready_shard_rows}
- verified_page_hash_rows={verified_page_hash_rows}
- required_page_hash_rows={required_page_hash_rows}
- post_activation_verification_gate_ready=0
- generation_gate_ready_after_post_activation=0
- checkpoint_payload_bytes_downloaded_by_v61am=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- activation_admission=blocked
- local_identity_verification=blocked
- full_page_hash_verification=blocked
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AM_CHECKPOINT_POST_ACTIVATION_VERIFICATION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61am_checkpoint_post_activation_verification_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61am_checkpoint_post_activation_verification_gate_ready": 1,
    "post_activation_verification_rows": len(verification_rows),
    "post_activation_verification_ready_rows": post_activation_verification_ready_rows,
    "verified_page_hash_rows": verified_page_hash_rows,
    "required_page_hash_rows": required_page_hash_rows,
    "checkpoint_payload_bytes_downloaded_by_v61am": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61am_checkpoint_post_activation_verification_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61am_checkpoint_post_activation_verification_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
