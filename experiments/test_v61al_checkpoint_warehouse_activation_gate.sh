#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61al_checkpoint_warehouse_activation_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61al_checkpoint_warehouse_activation_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61al_checkpoint_warehouse_activation_gate_decision.csv"

V61AL_REUSE_EXISTING="${V61AL_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61al_checkpoint_warehouse_activation_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61al_checkpoint_warehouse_activation_gate_ready": "1",
    "v61ak_checkpoint_warehouse_target_preflight_ready": "1",
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "warehouse_root_override_supplied": "0",
    "activation_command_rows": "59",
    "activation_admitted_rows": "0",
    "activation_blocked_rows": "59",
    "activation_package_ready": "0",
    "selected_target_id": "none",
    "selected_target_path": "",
    "admitted_target_rows": "0",
    "selected_backend_id": "curl-resume",
    "backend_ready": "1",
    "explicit_execute_required": "1",
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
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61al {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_warehouse_activation_command_rows.csv",
    "checkpoint_warehouse_activation_gate_rows.csv",
    "checkpoint_warehouse_activation_metric_rows.csv",
    "V61AL_CHECKPOINT_WAREHOUSE_ACTIVATION_GATE_BOUNDARY.md",
    "v61al_checkpoint_warehouse_activation_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61ak/checkpoint_warehouse_target_rows.csv",
    "source_v61ah/checkpoint_download_backend_plan_rows.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61al artifact: {rel}")

activation_rows = read_csv(run_dir / "checkpoint_warehouse_activation_command_rows.csv")
if len(activation_rows) != 59:
    raise SystemExit("v61al activation command row count mismatch")
if [row["priority_rank"] for row in activation_rows[:4]] != ["1", "2", "3", "4"]:
    raise SystemExit("v61al activation priority ordering mismatch")
if any(row["selected_backend_id"] != "curl-resume" for row in activation_rows):
    raise SystemExit("v61al selected backend mismatch")
if any(row["backend_ready"] != "1" for row in activation_rows):
    raise SystemExit("v61al backend should be ready")
if any(row["selected_target_id"] != "none" for row in activation_rows):
    raise SystemExit("v61al default target should be none")
if any(row["activation_admitted"] != "0" for row in activation_rows):
    raise SystemExit("v61al default activation rows should be blocked")
if any(row["activation_status"] != "blocked" for row in activation_rows):
    raise SystemExit("v61al default activation status should be blocked")
if any(row["blocked_reason"] != "no-full-reserve-warehouse-target" for row in activation_rows):
    raise SystemExit("v61al default blocked reason mismatch")
if any(row["dry_run_default"] != "1" for row in activation_rows):
    raise SystemExit("v61al activation rows should default to dry-run")
if any(row["explicit_execute_required"] != "1" for row in activation_rows):
    raise SystemExit("v61al activation rows should require explicit execution")
if any(row["command_preview"] for row in activation_rows):
    raise SystemExit("v61al should not emit executable command previews without selected target")
if any(row["checkpoint_payload_bytes_downloaded_by_v61al"] != "0" for row in activation_rows):
    raise SystemExit("v61al must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in activation_rows):
    raise SystemExit("v61al must not commit checkpoint payload bytes")

gate_rows = {row["gate"]: row for row in read_csv(run_dir / "checkpoint_warehouse_activation_gate_rows.csv")}
if gate_rows["selected-full-reserve-warehouse-target"]["status"] != "blocked":
    raise SystemExit("v61al selected target gate should be blocked by default")
if gate_rows["selected-download-backend"]["status"] != "pass":
    raise SystemExit("v61al selected backend gate should pass")
if gate_rows["activation-command-package"]["status"] != "blocked":
    raise SystemExit("v61al activation package should be blocked by default")
if gate_rows["explicit-payload-execution"]["status"] != "blocked":
    raise SystemExit("v61al explicit execution gate should stay blocked")
if gate_rows["manifest-only-no-repo-payload"]["status"] != "pass":
    raise SystemExit("v61al manifest-only gate should pass")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61ak-warehouse-target-input", "v61ah-backend-input"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61al gate should pass: {gate}")
for gate in [
    "activation-command-package",
    "explicit-download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61al gate should stay blocked: {gate}")

metric = read_csv(run_dir / "checkpoint_warehouse_activation_metric_rows.csv")[0]
for field, value in expected.items():
    if field.startswith("v61al_") or field.startswith("v61ak_") or field.startswith("v61ah_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61al metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61AL_CHECKPOINT_WAREHOUSE_ACTIVATION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "activation_command_rows=59",
    "activation_admitted_rows=0",
    "activation_blocked_rows=59",
    "activation_package_ready=0",
    "selected_target_id=none",
    "selected_backend_id=curl-resume",
    "explicit_execute_required=1",
    "checkpoint_payload_bytes_downloaded_by_v61al=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61al boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61al_checkpoint_warehouse_activation_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61al_checkpoint_warehouse_activation_gate_ready") != 1:
    raise SystemExit("v61al manifest readiness mismatch")
if manifest.get("activation_command_rows") != 59:
    raise SystemExit("v61al manifest command rows mismatch")
if manifest.get("activation_admitted_rows") != 0:
    raise SystemExit("v61al manifest admitted rows mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61al") != 0:
    raise SystemExit("v61al manifest must keep downloaded payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61al sha256 mismatch: {rel}")
PY

echo "v61al checkpoint warehouse activation gate smoke passed"
