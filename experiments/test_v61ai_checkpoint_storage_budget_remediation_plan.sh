#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ai_checkpoint_storage_budget_remediation_plan/plan_001"
SUMMARY_CSV="$RESULTS_DIR/v61ai_checkpoint_storage_budget_remediation_plan_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ai_checkpoint_storage_budget_remediation_plan_decision.csv"

V61AI_REUSE_EXISTING="${V61AI_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ai_checkpoint_storage_budget_remediation_plan.sh" >/dev/null

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
    "v61ai_checkpoint_storage_budget_remediation_plan_ready": "1",
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "total_checkpoint_bytes_required": "281241493344",
    "ssd_reserve_bytes": "34359738368",
    "required_with_reserve_bytes": "315601231712",
    "safe_materialization_batch_rows": "0",
    "safe_materialization_batch_bytes": "0",
    "selected_backend_id": "curl-resume",
    "download_backend_ready": "1",
    "warehouse_root_override_supplied": "0",
    "download_execution_ready": "0",
    "storage_budget_remediation_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "generation_admitted_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ai": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ai {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_storage_budget_remediation_rows.csv",
    "checkpoint_materialization_batch_rows.csv",
    "checkpoint_no_reserve_candidate_shard_rows.csv",
    "checkpoint_storage_budget_metric_rows.csv",
    "V61AI_CHECKPOINT_STORAGE_BUDGET_REMEDIATION_BOUNDARY.md",
    "v61ai_checkpoint_storage_budget_remediation_plan_manifest.json",
    "sha256_manifest.csv",
    "source_v61ah/checkpoint_download_backend_plan_rows.csv",
    "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv",
    "source_v61p/checkpoint_residency_requirement_rows.csv",
    "source_v61w/v61w_materialization_admission_resume_plan_summary.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ai artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61ah-download-backend-input",
    "storage-budget-accounting",
    "diagnostic-no-reserve-candidate-batch",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ai gate should pass: {gate}")
for gate in [
    "full-checkpoint-storage-budget",
    "safe-partial-download-batch",
    "download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ai gate should stay blocked: {gate}")

remediation_rows = {row["remediation_id"]: row for row in read_csv(run_dir / "checkpoint_storage_budget_remediation_rows.csv")}
batch_rows = {row["batch_id"]: row for row in read_csv(run_dir / "checkpoint_materialization_batch_rows.csv")}
candidate_rows = read_csv(run_dir / "checkpoint_no_reserve_candidate_shard_rows.csv")
metric = read_csv(run_dir / "checkpoint_storage_budget_metric_rows.csv")[0]
source_v61p_summary = read_csv(run_dir / "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
source_v61w_summary = read_csv(run_dir / "source_v61w/v61w_materialization_admission_resume_plan_summary.csv")[0]

total_checkpoint_bytes = int(summary["total_checkpoint_bytes_required"])
reserve_bytes = int(summary["ssd_reserve_bytes"])
required_with_reserve = int(summary["required_with_reserve_bytes"])
available_bytes = int(summary["available_ssd_bytes"])
available_after_reserve = max(available_bytes - reserve_bytes, 0)
full_budget_deficit = max(required_with_reserve - available_bytes, 0)
raw_checkpoint_deficit = max(total_checkpoint_bytes - available_bytes, 0)
no_reserve_candidate_rows = int(summary["no_reserve_candidate_shard_rows"])
no_reserve_candidate_bytes = int(summary["no_reserve_candidate_bytes"])

if summary["available_ssd_bytes"] != source_v61p_summary["available_ssd_bytes"]:
    raise SystemExit("v61ai available_ssd_bytes should match copied v61p summary")
if summary["ssd_warehouse_path"] != source_v61p_summary["ssd_warehouse_path"]:
    raise SystemExit("v61ai warehouse path should match copied v61p summary")
if source_v61w_summary["ssd_warehouse_path"] != summary["ssd_warehouse_path"]:
    raise SystemExit("v61ai source v61w warehouse path should match summary")
if int(summary["available_after_reserve_bytes"]) != available_after_reserve:
    raise SystemExit("v61ai available_after_reserve_bytes formula mismatch")
if int(summary["full_budget_deficit_bytes"]) != full_budget_deficit:
    raise SystemExit("v61ai full_budget_deficit_bytes formula mismatch")
if int(summary["raw_checkpoint_deficit_bytes"]) != raw_checkpoint_deficit:
    raise SystemExit("v61ai raw_checkpoint_deficit_bytes formula mismatch")

if len(remediation_rows) != 5 or len(batch_rows) != 3 or len(candidate_rows) != no_reserve_candidate_rows:
    raise SystemExit("v61ai row count mismatch")
if remediation_rows["full-checkpoint-with-reserve"]["deficit_bytes"] != str(full_budget_deficit):
    raise SystemExit("v61ai full reserve deficit mismatch")
if remediation_rows["diagnostic-no-reserve-top-priority-batch"]["status"] != "diagnostic-only":
    raise SystemExit("v61ai no-reserve batch should be diagnostic only")
if batch_rows["current-safe-reserve-batch"]["shard_rows"] != "0":
    raise SystemExit("v61ai safe reserve batch should admit zero shards")
if batch_rows["diagnostic-no-reserve-top-priority-batch"]["batch_checkpoint_bytes"] != str(no_reserve_candidate_bytes):
    raise SystemExit("v61ai no-reserve batch bytes mismatch")
if [row["priority_rank"] for row in candidate_rows] != [str(index) for index in range(1, no_reserve_candidate_rows + 1)]:
    raise SystemExit("v61ai no-reserve candidate priorities mismatch")
if any(row["admitted_under_reserve_policy"] != "0" for row in candidate_rows):
    raise SystemExit("v61ai no-reserve candidates must not be admitted under reserve policy")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ai"] != "0" for row in candidate_rows):
    raise SystemExit("v61ai must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in candidate_rows):
    raise SystemExit("v61ai must not commit checkpoint payload bytes")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ai metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61AI_CHECKPOINT_STORAGE_BUDGET_REMEDIATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    f"full_budget_deficit_bytes={full_budget_deficit}",
    f"raw_checkpoint_deficit_bytes={raw_checkpoint_deficit}",
    "safe_materialization_batch_rows=0",
    f"no_reserve_candidate_shard_rows={no_reserve_candidate_rows}",
    f"no_reserve_candidate_bytes={no_reserve_candidate_bytes}",
    "warehouse_root_override_supplied=0",
    "storage_budget_remediation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ai=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ai boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ai_checkpoint_storage_budget_remediation_plan_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ai_checkpoint_storage_budget_remediation_plan_ready") != 1:
    raise SystemExit("v61ai manifest readiness mismatch")
if manifest.get("full_budget_deficit_bytes") != full_budget_deficit:
    raise SystemExit("v61ai manifest deficit mismatch")
if manifest.get("safe_materialization_batch_rows") != 0:
    raise SystemExit("v61ai manifest safe batch should stay zero")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ai") != 0:
    raise SystemExit("v61ai manifest must keep downloaded payload bytes at zero")
if manifest.get("warehouse_root_override_supplied") != 0:
    raise SystemExit("v61ai manifest should record no default warehouse override")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ai sha256 mismatch: {rel}")
PY

echo "v61ai checkpoint storage budget remediation plan smoke passed"
