#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ak_checkpoint_warehouse_target_preflight/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v61ak_checkpoint_warehouse_target_preflight_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ak_checkpoint_warehouse_target_preflight_decision.csv"

V61AK_REUSE_EXISTING="${V61AK_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ak_checkpoint_warehouse_target_preflight.sh" >/dev/null

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
    "v61ak_checkpoint_warehouse_target_preflight_ready": "1",
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "target_rows": "3",
    "env_warehouse_root_supplied": "0",
    "required_with_reserve_bytes": "315601231712",
    "total_checkpoint_bytes_required": "281241493344",
    "ssd_reserve_bytes": "34359738368",
    "minimum_additional_bytes_for_full_reserve_from_v61aj": "294263770976",
    "recommended_operator_free_bytes": "549755813888",
    "selected_backend_id": "curl-resume",
    "warehouse_target_preflight_ready": "1",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ak": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ak {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_warehouse_target_rows.csv",
    "checkpoint_warehouse_target_requirement_rows.csv",
    "checkpoint_warehouse_target_metric_rows.csv",
    "V61AK_CHECKPOINT_WAREHOUSE_TARGET_PREFLIGHT_BOUNDARY.md",
    "v61ak_checkpoint_warehouse_target_preflight_manifest.json",
    "sha256_manifest.csv",
    "source_v61aj/checkpoint_storage_profile_rows.csv",
    "source_v61p/ssd_disk_budget_rows.csv",
    "source_v61p/local_shard_presence_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ak artifact: {rel}")

targets = {row["target_id"]: row for row in read_csv(run_dir / "checkpoint_warehouse_target_rows.csv")}
if set(targets) != {"current-v61p-warehouse", "env-v61ak-warehouse-root", "repo-local-forbidden-control"}:
    raise SystemExit("v61ak target ids mismatch")

current = targets["current-v61p-warehouse"]
env_target = targets["env-v61ak-warehouse-root"]
repo_control = targets["repo-local-forbidden-control"]

if current["target_path_supplied"] != "1" or current["outside_repository"] != "1":
    raise SystemExit("v61ak current warehouse target should be supplied and outside repository")
if current["probe_ready"] != "1":
    raise SystemExit("v61ak current warehouse target should have a filesystem probe")
if int(current["filesystem_available_bytes"]) <= 0:
    raise SystemExit("v61ak current warehouse available bytes should be positive")
if summary["current_target_available_bytes_live"] != current["filesystem_available_bytes"]:
    raise SystemExit("v61ak current target available summary mismatch")
if summary["current_target_deficit_to_full_reserve_bytes_live"] != current["deficit_to_full_reserve_bytes"]:
    raise SystemExit("v61ak current target deficit summary mismatch")
if summary["current_target_full_reserve_admitted"] != current["full_reserve_target_admitted"]:
    raise SystemExit("v61ak current target admitted summary mismatch")
if env_target["target_path_supplied"] != "0" or env_target["blocked_reason"] != "target-path-not-supplied":
    raise SystemExit("v61ak env target should be absent by default")
if repo_control["inside_repository"] != "1" or repo_control["full_reserve_target_admitted"] != "0":
    raise SystemExit("v61ak repository-local target must be blocked")
if summary["repo_forbidden_control_blocked"] != "1":
    raise SystemExit("v61ak repo forbidden control summary mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ak"] != "0" for row in targets.values()):
    raise SystemExit("v61ak must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in targets.values()):
    raise SystemExit("v61ak must not commit checkpoint payload bytes")

admitted_rows = [row for row in targets.values() if row["full_reserve_target_admitted"] == "1"]
if summary["admitted_target_rows"] != str(len(admitted_rows)):
    raise SystemExit("v61ak admitted target count mismatch")
if admitted_rows:
    if summary["selected_target_id"] == "none":
        raise SystemExit("v61ak should select a target when admitted rows exist")
else:
    if summary["selected_target_id"] != "none":
        raise SystemExit("v61ak should not select a target when no admitted rows exist")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "checkpoint_warehouse_target_requirement_rows.csv")}
if requirements["full-reserve-free-bytes"]["bytes"] != "315601231712":
    raise SystemExit("v61ak full reserve requirement mismatch")
if requirements["operator-margin-free-bytes"]["bytes"] != "549755813888":
    raise SystemExit("v61ak operator margin requirement mismatch")
if requirements["outside-repository-warehouse"]["status"] != "required":
    raise SystemExit("v61ak outside repository requirement mismatch")

metric = read_csv(run_dir / "checkpoint_warehouse_target_metric_rows.csv")[0]
for field, value in summary.items():
    if field.startswith("v61ak_") or field.startswith("v61aj_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ak metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61aj-storage-profile-input",
    "warehouse-target-accounting",
    "repository-payload-target-block",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ak gate should pass: {gate}")
for gate in [
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ak gate should stay blocked: {gate}")
selected_gate = decisions.get("selected-full-reserve-warehouse-target")
if summary["admitted_target_rows"] == "0" and selected_gate != "blocked":
    raise SystemExit("v61ak selected target gate should block when no target is admitted")
if summary["admitted_target_rows"] != "0" and selected_gate != "pass":
    raise SystemExit("v61ak selected target gate should pass when a target is admitted")

boundary = (run_dir / "V61AK_CHECKPOINT_WAREHOUSE_TARGET_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "target_rows=3",
    "required_with_reserve_bytes=315601231712",
    "recommended_operator_free_bytes=549755813888",
    "warehouse_target_preflight_ready=1",
    "checkpoint_payload_bytes_downloaded_by_v61ak=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ak boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ak_checkpoint_warehouse_target_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ak_checkpoint_warehouse_target_preflight_ready") != 1:
    raise SystemExit("v61ak manifest readiness mismatch")
if manifest.get("target_rows") != 3:
    raise SystemExit("v61ak manifest target rows mismatch")
if manifest.get("required_with_reserve_bytes") != 315601231712:
    raise SystemExit("v61ak manifest required bytes mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ak") != 0:
    raise SystemExit("v61ak manifest must keep downloaded payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ak sha256 mismatch: {rel}")
PY

echo "v61ak checkpoint warehouse target preflight smoke passed"
