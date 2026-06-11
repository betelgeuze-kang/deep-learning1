#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61al_checkpoint_warehouse_activation_gate"
RUN_ID="${V61AL_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61AL_WAREHOUSE_ROOT:-${V61AK_WAREHOUSE_ROOT:-}}"

if [[ "${V61AL_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61al_checkpoint_warehouse_activation_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61AK_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61AK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh" >/dev/null
else
  V61AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh" >/dev/null
fi
V61AH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
import csv
import hashlib
import json
import shlex
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


v61ak_dir = results / "v61ak_checkpoint_warehouse_target_preflight" / "preflight_001"
v61ah_dir = results / "v61ah_checkpoint_download_backend_fallback_plan" / "plan_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

v61ak_summary = read_csv(results / "v61ak_checkpoint_warehouse_target_preflight_summary.csv")[0]
v61ah_summary = read_csv(results / "v61ah_checkpoint_download_backend_fallback_plan_summary.csv")[0]
if v61ak_summary.get("v61ak_checkpoint_warehouse_target_preflight_ready") != "1":
    raise SystemExit("v61al requires v61ak_checkpoint_warehouse_target_preflight_ready=1")
if v61ah_summary.get("v61ah_checkpoint_download_backend_fallback_plan_ready") != "1":
    raise SystemExit("v61al requires v61ah_checkpoint_download_backend_fallback_plan_ready=1")

for src, rel in [
    (results / "v61ak_checkpoint_warehouse_target_preflight_summary.csv", "source_v61ak/v61ak_checkpoint_warehouse_target_preflight_summary.csv"),
    (results / "v61ak_checkpoint_warehouse_target_preflight_decision.csv", "source_v61ak/v61ak_checkpoint_warehouse_target_preflight_decision.csv"),
    (v61ak_dir / "checkpoint_warehouse_target_rows.csv", "source_v61ak/checkpoint_warehouse_target_rows.csv"),
    (v61ak_dir / "checkpoint_warehouse_target_requirement_rows.csv", "source_v61ak/checkpoint_warehouse_target_requirement_rows.csv"),
    (v61ak_dir / "checkpoint_warehouse_target_metric_rows.csv", "source_v61ak/checkpoint_warehouse_target_metric_rows.csv"),
    (v61ak_dir / "sha256_manifest.csv", "source_v61ak/sha256_manifest.csv"),
    (results / "v61ah_checkpoint_download_backend_fallback_plan_summary.csv", "source_v61ah/v61ah_checkpoint_download_backend_fallback_plan_summary.csv"),
    (v61ah_dir / "checkpoint_download_backend_plan_rows.csv", "source_v61ah/checkpoint_download_backend_plan_rows.csv"),
    (v61ah_dir / "checkpoint_download_backend_candidate_rows.csv", "source_v61ah/checkpoint_download_backend_candidate_rows.csv"),
    (v61ah_dir / "sha256_manifest.csv", "source_v61ah/sha256_manifest.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

target_rows = read_csv(v61ak_dir / "checkpoint_warehouse_target_rows.csv")
backend_plan_rows = read_csv(v61ah_dir / "checkpoint_download_backend_plan_rows.csv")
priority_rows = read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")
if len(backend_plan_rows) != 59:
    raise SystemExit("v61al expects 59 v61ah backend plan rows")
if len(priority_rows) != 59:
    raise SystemExit("v61al expects 59 v61w priority rows")

selected_target_id = v61ak_summary["selected_target_id"]
selected_target_path = v61ak_summary["selected_target_path"]
selected_backend_id = v61ah_summary["selected_backend_id"]
backend_ready = v61ah_summary["selected_backend_ready"]
admitted_target_rows = int(v61ak_summary["admitted_target_rows"])
target_selected = int(selected_target_id != "none" and bool(selected_target_path))
activation_package_ready = int(target_selected and backend_ready == "1" and admitted_target_rows > 0)
explicit_execute_required = 1

target_by_id = {row["target_id"]: row for row in target_rows}
current_target_path = target_by_id.get("current-v61p-warehouse", {}).get("target_path", "")
target_base_path = selected_target_path if target_selected else current_target_path
target_full_reserve_admitted = "1" if target_selected else "0"
target_blocked_reason = "none" if target_selected else "no-full-reserve-warehouse-target"

priority_by_shard = {row["shard_name"]: row for row in priority_rows}
activation_rows = []
for row in sorted(backend_plan_rows, key=lambda item: int(item["priority_rank"])):
    shard_name = row["shard_name"]
    priority = priority_by_shard[shard_name]
    target_path = str(Path(target_base_path) / shard_name) if target_base_path else ""
    source_url = row["source_url"]
    if target_selected:
        command_preview = (
            f"mkdir -p {shlex.quote(str(Path(target_base_path)))} && "
            f"curl -L --fail --retry 5 --continue-at - "
            f"--output {shlex.quote(target_path)} {shlex.quote(source_url)}"
        )
    else:
        command_preview = ""
    activation_admitted = int(activation_package_ready)
    blocked_reason = "none" if activation_admitted else target_blocked_reason
    activation_rows.append({
        "priority_rank": row["priority_rank"],
        "model_id": model_id,
        "shard_name": shard_name,
        "priority_class": priority["priority_class"],
        "source_url": source_url,
        "target_path": target_path,
        "expected_bytes": row["expected_bytes"],
        "selected_target_id": selected_target_id,
        "selected_target_path": selected_target_path,
        "selected_backend_id": selected_backend_id,
        "backend_ready": backend_ready,
        "target_full_reserve_admitted": target_full_reserve_admitted,
        "dry_run_default": "1",
        "explicit_execute_required": str(explicit_execute_required),
        "activation_admitted": str(activation_admitted),
        "activation_status": "ready-for-explicit-execution" if activation_admitted else "blocked",
        "blocked_reason": blocked_reason,
        "command_preview": command_preview,
        "post_download_verify_command": priority["post_download_verify_command"],
        "post_download_full_page_hash_command": priority["post_download_full_page_hash_command"],
        "checkpoint_payload_bytes_downloaded_by_v61al": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    })

activation_admitted_rows = sum(int(row["activation_admitted"]) for row in activation_rows)
activation_blocked_rows = len(activation_rows) - activation_admitted_rows
activation_gate_rows = [
    {
        "gate": "selected-full-reserve-warehouse-target",
        "status": "pass" if target_selected else "blocked",
        "reason": f"selected_target_id={selected_target_id}",
    },
    {
        "gate": "selected-download-backend",
        "status": "pass" if backend_ready == "1" else "blocked",
        "reason": f"selected_backend_id={selected_backend_id}",
    },
    {
        "gate": "activation-command-package",
        "status": "pass" if activation_package_ready else "blocked",
        "reason": f"activation_admitted_rows={activation_admitted_rows}",
    },
    {
        "gate": "explicit-payload-execution",
        "status": "blocked",
        "reason": "V61AL_EXECUTE_DOWNLOAD=1 was not supplied and this artifact is metadata-only",
    },
    {
        "gate": "manifest-only-no-repo-payload",
        "status": "pass",
        "reason": "v61al emits metadata only",
    },
]

metric = {
    "metric_id": "v61al_checkpoint_warehouse_activation_gate_metrics",
    "model_id": model_id,
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "activation_command_rows": str(len(activation_rows)),
    "activation_admitted_rows": str(activation_admitted_rows),
    "activation_blocked_rows": str(activation_blocked_rows),
    "activation_package_ready": str(activation_package_ready),
    "selected_target_id": selected_target_id,
    "selected_target_path": selected_target_path,
    "admitted_target_rows": str(admitted_target_rows),
    "selected_backend_id": selected_backend_id,
    "backend_ready": backend_ready,
    "explicit_execute_required": str(explicit_execute_required),
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61al": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}

write_csv(run_dir / "checkpoint_warehouse_activation_command_rows.csv", list(activation_rows[0].keys()), activation_rows)
write_csv(run_dir / "checkpoint_warehouse_activation_gate_rows.csv", list(activation_gate_rows[0].keys()), activation_gate_rows)
write_csv(run_dir / "checkpoint_warehouse_activation_metric_rows.csv", list(metric.keys()), [metric])

decision_rows = [
    {"gate": "v61ak-warehouse-target-input", "status": "pass", "reason": "v61ak target preflight is ready"},
    {"gate": "v61ah-backend-input", "status": "pass", "reason": "v61ah backend fallback plan is ready"},
    {"gate": "activation-command-package", "status": "pass" if activation_package_ready else "blocked", "reason": f"activation_admitted_rows={activation_admitted_rows}"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "payload execution requires explicit operator action outside this metadata artifact"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "activation gate is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "activation gate is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61al_checkpoint_warehouse_activation_gate_ready": "1",
    "v61ak_checkpoint_warehouse_target_preflight_ready": v61ak_summary["v61ak_checkpoint_warehouse_target_preflight_ready"],
    "v61ah_checkpoint_download_backend_fallback_plan_ready": v61ah_summary["v61ah_checkpoint_download_backend_fallback_plan_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61al Checkpoint Warehouse Activation Gate Boundary

This artifact binds the selected backend and warehouse target preflight into a
metadata-only activation command package. It does not execute downloads.

Evidence emitted:

- activation_command_rows={len(activation_rows)}
- activation_admitted_rows={activation_admitted_rows}
- activation_blocked_rows={activation_blocked_rows}
- activation_package_ready={activation_package_ready}
- selected_target_id={selected_target_id}
- selected_backend_id={selected_backend_id}
- backend_ready={backend_ready}
- explicit_execute_required={explicit_execute_required}
- download_execution_ready=0
- checkpoint_payload_bytes_downloaded_by_v61al=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- explicit_download_execution=blocked
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AL_CHECKPOINT_WAREHOUSE_ACTIVATION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61al_checkpoint_warehouse_activation_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61al_checkpoint_warehouse_activation_gate_ready": 1,
    "activation_command_rows": len(activation_rows),
    "activation_admitted_rows": activation_admitted_rows,
    "activation_package_ready": activation_package_ready,
    "selected_target_id": selected_target_id,
    "selected_backend_id": selected_backend_id,
    "checkpoint_payload_bytes_downloaded_by_v61al": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61al_checkpoint_warehouse_activation_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61al_checkpoint_warehouse_activation_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
