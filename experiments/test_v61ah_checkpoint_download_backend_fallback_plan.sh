#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ah_checkpoint_download_backend_fallback_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61ah_checkpoint_download_backend_fallback_plan_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ah_checkpoint_download_backend_fallback_plan_decision.csv"

V61AH_REUSE_EXISTING="${V61AH_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ah_checkpoint_download_backend_fallback_plan.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import subprocess
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
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "v61ag_checkpoint_warehouse_execution_preflight_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "backend_candidate_rows": "5",
    "ready_backend_rows": "3",
    "selected_backend_id": "curl-resume",
    "selected_backend_ready": "1",
    "download_backend_plan_rows": "59",
    "download_backend_dry_run_exit_code": "0",
    "download_backend_dry_run_guard_ready": "1",
    "huggingface_cli_available": "0",
    "python_huggingface_hub_available": "1",
    "curl_available": "1",
    "wget_available": "1",
    "aria2c_available": "0",
    "ssd_disk_budget_pass": "0",
    "warehouse_outside_repo": "1",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "generation_admitted_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ah": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ah {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_download_backend_candidate_rows.csv",
    "checkpoint_download_backend_plan_rows.csv",
    "checkpoint_download_backend_dry_run_rows.csv",
    "checkpoint_download_backend_metric_rows.csv",
    "operator_bundle/download_priority_queue_backend.sh",
    "V61AH_CHECKPOINT_DOWNLOAD_BACKEND_FALLBACK_BOUNDARY.md",
    "v61ah_checkpoint_download_backend_fallback_plan_manifest.json",
    "sha256_manifest.csv",
    "source_v61ag/checkpoint_warehouse_environment_rows.csv",
    "source_v61af/checkpoint_warehouse_operator_command_rows.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ah artifact: {rel}")

subprocess.run(["bash", "-n", str(run_dir / "operator_bundle/download_priority_queue_backend.sh")], check=True)

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61ag-execution-preflight-input",
    "download-backend-probe",
    "selected-download-backend",
    "backend-dry-run-guard",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ah gate should pass: {gate}")
for gate in [
    "huggingface-cli-primary",
    "ssd-disk-budget-admission",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ah gate should stay blocked: {gate}")

candidate_rows = {row["backend_id"]: row for row in read_csv(run_dir / "checkpoint_download_backend_candidate_rows.csv")}
plan_rows = read_csv(run_dir / "checkpoint_download_backend_plan_rows.csv")
dry_rows = read_csv(run_dir / "checkpoint_download_backend_dry_run_rows.csv")
metric = read_csv(run_dir / "checkpoint_download_backend_metric_rows.csv")[0]

if set(candidate_rows) != {"curl-resume", "python-huggingface-hub", "wget-continue", "huggingface-cli", "aria2c-continue"}:
    raise SystemExit("v61ah backend candidate set mismatch")
if candidate_rows["curl-resume"]["available"] != "1" or candidate_rows["curl-resume"]["selected_backend"] != "1":
    raise SystemExit("v61ah should select available curl-resume backend")
if candidate_rows["huggingface-cli"]["available"] != "0" or candidate_rows["huggingface-cli"]["selected_backend"] != "0":
    raise SystemExit("v61ah should keep huggingface-cli unavailable and unselected")
if len(plan_rows) != 59 or len(dry_rows) != 1:
    raise SystemExit("v61ah row count mismatch")
if any(row["selected_backend_id"] != "curl-resume" for row in plan_rows):
    raise SystemExit("v61ah all plan rows should use curl-resume")
if any("curl -L --fail --retry 5 --continue-at -" not in row["download_command"] for row in plan_rows[:5]):
    raise SystemExit("v61ah plan rows should emit curl resume commands")
if any(row["requires_explicit_execute"] != "1" or row["dry_run_default"] != "1" for row in plan_rows):
    raise SystemExit("v61ah plan rows should be dry-run and explicit-execute guarded")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ah"] != "0" for row in plan_rows + dry_rows):
    raise SystemExit("v61ah must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in plan_rows + dry_rows):
    raise SystemExit("v61ah must not commit checkpoint payload bytes")
if dry_rows[0]["payload_execution_blocked"] != "1" or dry_rows[0]["dry_run_guard_seen"] != "1":
    raise SystemExit("v61ah dry-run probe should block payload execution")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ah metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61AH_CHECKPOINT_DOWNLOAD_BACKEND_FALLBACK_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "selected_backend_id=curl-resume",
    "download_backend_dry_run_guard_ready=1",
    "huggingface_cli_available=0",
    "curl_available=1",
    "download_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ah=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ah boundary missing snippet: {snippet}")

script = (run_dir / "operator_bundle/download_priority_queue_backend.sh").read_text(encoding="utf-8")
for snippet in ["V61AH_EXECUTE_DOWNLOAD", "dry-run", "curl -L --fail --retry 5 --continue-at -"]:
    if snippet not in script:
        raise SystemExit(f"v61ah backend script missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ah_checkpoint_download_backend_fallback_plan_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ah_checkpoint_download_backend_fallback_plan_ready") != 1:
    raise SystemExit("v61ah manifest readiness mismatch")
if manifest.get("selected_backend_id") != "curl-resume":
    raise SystemExit("v61ah manifest selected backend mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ah") != 0:
    raise SystemExit("v61ah manifest must keep downloaded payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ah sha256 mismatch: {rel}")
PY

echo "v61ah checkpoint download backend fallback plan smoke passed"
