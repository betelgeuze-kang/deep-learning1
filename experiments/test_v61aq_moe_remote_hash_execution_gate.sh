#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61aq_moe_remote_hash_execution_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61aq_moe_remote_hash_execution_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61aq_moe_remote_hash_execution_gate_decision.csv"

V61AQ_REUSE_EXISTING="${V61AQ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61aq_moe_remote_hash_execution_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
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
    "v61aq_moe_remote_hash_execution_gate_ready": "1",
    "v61ap_moe_coverage_remote_hash_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "remote_hash_plan_rows": "1344",
    "already_remote_hash_bound_rows": "15",
    "planned_remote_hash_command_rows": "1329",
    "remote_hash_execution_chunk_size_rows": "64",
    "remote_hash_execution_chunk_rows": "21",
    "blocked_execution_chunk_rows": "21",
    "already_complete_chunk_rows": "0",
    "remote_hash_verified_rows": "15",
    "planned_remote_hash_bytes": "2787115008",
    "full_moe_coverage_remote_hash_ready": "0",
    "remote_hash_execution_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61aq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61aq {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "moe_remote_hash_execution_command_rows.csv",
    "moe_remote_hash_existing_hash_rows.csv",
    "moe_remote_hash_execution_chunk_rows.csv",
    "moe_remote_hash_execution_role_rows.csv",
    "moe_remote_hash_execution_requirement_rows.csv",
    "moe_remote_hash_execution_metric_rows.csv",
    "runtime_gap_rows.csv",
    "operator_bundle/run_moe_remote_hash_commands.sh",
    "V61AQ_MOE_REMOTE_HASH_EXECUTION_GATE_BOUNDARY.md",
    "v61aq_moe_remote_hash_execution_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61ap/moe_coverage_remote_hash_plan_rows.csv",
    "source_v61ap/moe_coverage_existing_remote_hash_rows.csv",
    "source_v61ap/moe_coverage_remote_hash_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61aq artifact: {rel}")

command_rows = read_csv(run_dir / "moe_remote_hash_execution_command_rows.csv")
existing_rows = read_csv(run_dir / "moe_remote_hash_existing_hash_rows.csv")
chunk_rows = read_csv(run_dir / "moe_remote_hash_execution_chunk_rows.csv")
role_rows = {row["tensor_role"]: row for row in read_csv(run_dir / "moe_remote_hash_execution_role_rows.csv")}
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "moe_remote_hash_execution_requirement_rows.csv")}
metric = read_csv(run_dir / "moe_remote_hash_execution_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(command_rows) != 1329 or len(existing_rows) != 15 or len(chunk_rows) != 21:
    raise SystemExit("v61aq row counts mismatch")
if any(row["execution_status"] != "blocked-execution-disabled" for row in command_rows):
    raise SystemExit("v61aq command rows should be blocked by default")
if any(row["remote_hash_execution_enabled"] != "0" for row in command_rows):
    raise SystemExit("v61aq command rows should keep execution disabled")
if any(row["checkpoint_payload_bytes_downloaded_by_v61aq"] != "0" for row in command_rows + existing_rows + chunk_rows):
    raise SystemExit("v61aq must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in command_rows + existing_rows + chunk_rows):
    raise SystemExit("v61aq must not commit checkpoint payload bytes")
if any(row.get("route_jump_rows", "0") != "0" for row in command_rows + existing_rows):
    raise SystemExit("v61aq must keep route jumps at zero")
if any(not row["sha256_command"].startswith("curl -L --fail --retry 3") for row in command_rows):
    raise SystemExit("v61aq command rows should emit guarded curl commands")
if any("sha256sum" not in row["sha256_command"] for row in command_rows):
    raise SystemExit("v61aq command rows should pipe to sha256sum")
if any(int(row["planned_range_bytes"]) != 2097152 for row in command_rows):
    raise SystemExit("v61aq commands should target 2 MiB ranges")

status_counts = Counter(row["execution_chunk_status"] for row in chunk_rows)
if status_counts["blocked-execution-disabled"] != 21:
    raise SystemExit(f"v61aq chunk status mismatch: {status_counts}")
if sum(int(row["planned_plan_rows"]) for row in chunk_rows) != 1344:
    raise SystemExit("v61aq chunks should cover 1344 plan rows")
if sum(int(row["already_remote_hash_bound_rows"]) for row in chunk_rows) != 15:
    raise SystemExit("v61aq chunks should preserve 15 existing hash rows")
if sum(int(row["planned_remote_hash_rows"]) for row in chunk_rows) != 1329:
    raise SystemExit("v61aq chunks should contain 1329 planned hash rows")

expected_roles = {
    "moe_w1": ("448", "5", "443"),
    "moe_w2": ("448", "4", "444"),
    "moe_w3": ("448", "6", "442"),
}
for role, (total, existing, commands) in expected_roles.items():
    row = role_rows.get(role)
    if row is None:
        raise SystemExit(f"missing v61aq role row: {role}")
    if row["remote_hash_plan_rows"] != total or row["already_remote_hash_bound_rows"] != existing or row["planned_remote_hash_command_rows"] != commands:
        raise SystemExit(f"v61aq role row mismatch: {row}")
    if row["full_role_remote_hash_ready"] != "0":
        raise SystemExit("v61aq role readiness should remain blocked")

for requirement_id in [
    "v61ap-remote-hash-plan-input",
    "remote-hash-command-plan",
    "existing-remote-hash-preservation",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61aq requirement should pass: {requirement_id}")
for requirement_id in [
    "remote-hash-execution",
    "full-moe-coverage-remote-hash",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61aq requirement should remain blocked: {requirement_id}")

for gate in [
    "v61ap-remote-hash-plan-input",
    "remote-hash-command-plan",
    "existing-remote-hash-preservation",
    "execution-chunk-schedule",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61aq gate should pass: {gate}")
for gate in [
    "remote-hash-execution",
    "full-moe-coverage-remote-hash",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61aq gate should stay blocked: {gate}")

for field, value in expected.items():
    if field.startswith("v61aq_") or field.startswith("v61ap_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61aq metric {field}: expected {value}, got {metric[field]}")

operator_script = run_dir / "operator_bundle/run_moe_remote_hash_commands.sh"
script_text = operator_script.read_text(encoding="utf-8")
if "V61AQ_EXECUTE_REMOTE_HASH" not in script_text or "dry-run" not in script_text:
    raise SystemExit("v61aq operator script should default to dry-run guard")
if not (operator_script.stat().st_mode & 0o111):
    raise SystemExit("v61aq operator script should be executable")

manifest = json.loads((run_dir / "v61aq_moe_remote_hash_execution_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61aq_moe_remote_hash_execution_gate_ready") != 1:
    raise SystemExit("v61aq manifest readiness mismatch")
if manifest.get("planned_remote_hash_command_rows") != 1329:
    raise SystemExit("v61aq manifest command count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61aq") != 0:
    raise SystemExit("v61aq manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61AQ_MOE_REMOTE_HASH_EXECUTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "remote_hash_plan_rows=1344",
    "already_remote_hash_bound_rows=15",
    "planned_remote_hash_command_rows=1329",
    "remote_hash_execution_chunk_rows=21",
    "blocked_execution_chunk_rows=21",
    "remote_hash_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61aq=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61aq boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61aq sha256 mismatch: {rel}")
PY

echo "v61aq MoE remote hash execution gate smoke passed"
