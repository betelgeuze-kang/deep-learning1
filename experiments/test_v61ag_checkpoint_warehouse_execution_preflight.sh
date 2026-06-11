#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ag_checkpoint_warehouse_execution_preflight/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v61ag_checkpoint_warehouse_execution_preflight_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ag_checkpoint_warehouse_execution_preflight_decision.csv"

V61AG_REUSE_EXISTING="${V61AG_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh" >/dev/null

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
    "v61ag_checkpoint_warehouse_execution_preflight_ready": "1",
    "v61af_checkpoint_warehouse_operator_bundle_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "operator_command_rows": "62",
    "download_command_rows": "59",
    "script_probe_rows": "4",
    "script_bash_syntax_pass_rows": "4",
    "script_executable_rows": "4",
    "dry_run_probe_rows": "1",
    "download_dry_run_exit_code": "0",
    "download_dry_run_guard_ready": "1",
    "warehouse_outside_repo": "1",
    "operator_bundle_ignored_by_git": "1",
    "ssd_disk_budget_pass": "0",
    "required_with_reserve_bytes": "315601231712",
    "warehouse_root_override_supplied": "0",
    "download_execution_ready": "0",
    "operator_execution_preflight_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "generation_admitted_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ag": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ag {field}: expected {value}, got {summary.get(field)}")
if summary.get("huggingface_cli_available") not in {"0", "1"}:
    raise SystemExit("v61ag huggingface_cli_available should be boolean")

required_files = [
    "checkpoint_warehouse_environment_rows.csv",
    "checkpoint_warehouse_operator_script_probe_rows.csv",
    "checkpoint_warehouse_dry_run_probe_rows.csv",
    "checkpoint_warehouse_execution_gate_rows.csv",
    "checkpoint_warehouse_execution_preflight_metric_rows.csv",
    "V61AG_CHECKPOINT_WAREHOUSE_EXECUTION_PREFLIGHT_BOUNDARY.md",
    "v61ag_checkpoint_warehouse_execution_preflight_manifest.json",
    "sha256_manifest.csv",
    "source_v61af/v61af_checkpoint_warehouse_operator_bundle_summary.csv",
    "source_v61af/checkpoint_warehouse_operator_command_rows.csv",
    "source_v61af/checkpoint_warehouse_operator_stage_rows.csv",
    "source_v61af/checkpoint_warehouse_operator_metric_rows.csv",
    "operator_bundle/README.md",
    "operator_bundle/operator_env.template",
    "operator_bundle/download_priority_queue.sh",
    "operator_bundle/verify_materialization.sh",
    "operator_bundle/run_full_page_hash_sweep.sh",
    "operator_bundle/recheck_real_generation_admission.sh",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ag artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61af-operator-bundle-input",
    "operator-script-syntax",
    "operator-script-executable",
    "download-dry-run-guard",
    "warehouse-outside-repository",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ag gate should pass: {gate}")
for gate in [
    "ssd-disk-budget-admission",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ag gate should stay blocked: {gate}")
if summary["huggingface_cli_available"] == "0" and decisions.get("huggingface-cli-available") != "blocked":
    raise SystemExit("v61ag huggingface CLI gate should be blocked when CLI is unavailable")

environment_rows = {row["check"]: row for row in read_csv(run_dir / "checkpoint_warehouse_environment_rows.csv")}
script_rows = read_csv(run_dir / "checkpoint_warehouse_operator_script_probe_rows.csv")
dry_rows = read_csv(run_dir / "checkpoint_warehouse_dry_run_probe_rows.csv")
gate_rows = {row["gate"]: row for row in read_csv(run_dir / "checkpoint_warehouse_execution_gate_rows.csv")}
metric = read_csv(run_dir / "checkpoint_warehouse_execution_preflight_metric_rows.csv")[0]
source_v61af_summary = read_csv(run_dir / "source_v61af/v61af_checkpoint_warehouse_operator_bundle_summary.csv")[0]

if summary["available_ssd_bytes"] != source_v61af_summary["available_ssd_bytes"]:
    raise SystemExit("v61ag available_ssd_bytes should match copied v61af summary")
if metric["available_ssd_bytes"] != summary["available_ssd_bytes"]:
    raise SystemExit("v61ag metric available_ssd_bytes should match summary")
if summary["ssd_warehouse_path"] != source_v61af_summary["ssd_warehouse_path"]:
    raise SystemExit("v61ag warehouse path should match copied v61af summary")

if len(environment_rows) != 5 or len(script_rows) != 4 or len(dry_rows) != 1:
    raise SystemExit("v61ag artifact row count mismatch")
if environment_rows["operator-dry-run-guard"]["status"] != "ready":
    raise SystemExit("v61ag dry-run guard environment row should be ready")
if environment_rows["ssd-disk-budget"]["status"] != "blocked":
    raise SystemExit("v61ag SSD budget environment row should stay blocked")
if any(row["bash_syntax_pass"] != "1" or row["executable_bit_set"] != "1" for row in script_rows):
    raise SystemExit("v61ag scripts should pass syntax and executable checks")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ag"] != "0" for row in script_rows + dry_rows):
    raise SystemExit("v61ag must not download payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in script_rows + dry_rows):
    raise SystemExit("v61ag must not commit payload bytes")
if dry_rows[0]["payload_execution_blocked"] != "1" or dry_rows[0]["dry_run_guard_seen"] != "1":
    raise SystemExit("v61ag dry-run probe should block payload execution")
if gate_rows["download-execution"]["status"] != "blocked":
    raise SystemExit("v61ag download execution gate should stay blocked")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ag metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61AG_CHECKPOINT_WAREHOUSE_EXECUTION_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "operator_command_rows=62",
    "download_dry_run_guard_ready=1",
    "warehouse_root_override_supplied=0",
    "download_execution_ready=0",
    "operator_execution_preflight_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ag=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ag boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ag_checkpoint_warehouse_execution_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ag_checkpoint_warehouse_execution_preflight_ready") != 1:
    raise SystemExit("v61ag manifest readiness mismatch")
if manifest.get("download_dry_run_guard_ready") != 1:
    raise SystemExit("v61ag manifest dry-run guard mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ag") != 0:
    raise SystemExit("v61ag manifest must keep downloaded payload bytes at zero")
if manifest.get("warehouse_root_override_supplied") != 0:
    raise SystemExit("v61ag manifest should record no default warehouse override")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ag sha256 mismatch: {rel}")
PY

echo "v61ag checkpoint warehouse execution preflight smoke passed"
