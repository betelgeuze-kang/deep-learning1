#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61aj_checkpoint_storage_profile_admission_matrix/matrix_001"
SUMMARY_CSV="$RESULTS_DIR/v61aj_checkpoint_storage_profile_admission_matrix_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61aj_checkpoint_storage_profile_admission_matrix_decision.csv"

V61AJ_REUSE_EXISTING="${V61AJ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61aj_checkpoint_storage_profile_admission_matrix.sh" >/dev/null

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
    "v61aj_checkpoint_storage_profile_admission_matrix_ready": "1",
    "v61ai_checkpoint_storage_budget_remediation_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "profile_rows": "6",
    "full_reserve_profile_rows": "3",
    "full_without_reserve_profile_rows": "4",
    "first_full_reserve_profile_id": "full-checkpoint-exact-with-reserve",
    "current_available_bytes": "21337460736",
    "total_checkpoint_bytes_required": "281241493344",
    "ssd_reserve_bytes": "34359738368",
    "required_with_reserve_bytes": "315601231712",
    "minimum_additional_bytes_for_full_reserve": "294263770976",
    "raw_checkpoint_deficit_bytes": "259904032608",
    "recommended_operator_free_bytes": "549755813888",
    "current_reserve_admitted_shard_rows": "0",
    "current_no_reserve_admitted_shard_rows": "4",
    "current_no_reserve_admitted_shard_bytes": "19478756392",
    "exact_reserve_admitted_shard_rows": "59",
    "selected_backend_id": "curl-resume",
    "storage_profile_admission_matrix_ready": "1",
    "download_execution_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61aj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61aj {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "checkpoint_storage_profile_rows.csv",
    "checkpoint_storage_profile_requirement_rows.csv",
    "checkpoint_storage_profile_metric_rows.csv",
    "V61AJ_CHECKPOINT_STORAGE_PROFILE_ADMISSION_MATRIX_BOUNDARY.md",
    "v61aj_checkpoint_storage_profile_admission_matrix_manifest.json",
    "sha256_manifest.csv",
    "source_v61ai/checkpoint_storage_budget_remediation_rows.csv",
    "source_v61ai/checkpoint_materialization_batch_rows.csv",
    "source_v61w/checkpoint_shard_priority_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61aj artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61ai-storage-budget-input",
    "storage-profile-accounting",
    "minimum-safe-full-profile",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61aj gate should pass: {gate}")
for gate in [
    "current-host-full-materialization",
    "current-host-download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61aj gate should stay blocked: {gate}")

profiles = {row["profile_id"]: row for row in read_csv(run_dir / "checkpoint_storage_profile_rows.csv")}
if len(profiles) != 6:
    raise SystemExit("v61aj profile row count mismatch")
current = profiles["current-host-reserve-policy"]
diagnostic = profiles["current-host-no-reserve-diagnostic"]
raw_exact = profiles["raw-checkpoint-exact-no-reserve"]
safe_exact = profiles["full-checkpoint-exact-with-reserve"]
operator_512 = profiles["operator-512gib-free-profile"]
operator_1tib = profiles["operator-1tib-free-profile"]

if current["admitted_shard_rows_under_profile_policy"] != "0":
    raise SystemExit("v61aj current reserve profile should admit zero shards")
if current["admitted_shard_rows_without_reserve"] != "4":
    raise SystemExit("v61aj current no-reserve view should fit four shards")
if diagnostic["execution_admission_status"] != "diagnostic-only":
    raise SystemExit("v61aj current no-reserve profile should be diagnostic only")
if diagnostic["admitted_shard_rows_under_profile_policy"] != "4":
    raise SystemExit("v61aj diagnostic profile should admit four shards under no reserve")
if raw_exact["full_checkpoint_admitted_without_reserve"] != "1":
    raise SystemExit("v61aj raw exact profile should fit full checkpoint without reserve")
if raw_exact["configured_reserve_satisfied_after_full"] != "0":
    raise SystemExit("v61aj raw exact profile must not satisfy configured reserve")
if safe_exact["full_checkpoint_admitted_by_profile_policy"] != "1":
    raise SystemExit("v61aj exact reserve profile should admit full checkpoint")
if safe_exact["configured_reserve_satisfied_after_full"] != "1":
    raise SystemExit("v61aj exact reserve profile should satisfy configured reserve")
if safe_exact["additional_bytes_from_current"] != "294263770976":
    raise SystemExit("v61aj exact reserve additional bytes mismatch")
if operator_512["full_checkpoint_admitted_by_profile_policy"] != "1":
    raise SystemExit("v61aj 512GiB profile should admit full checkpoint")
if operator_1tib["full_checkpoint_admitted_by_profile_policy"] != "1":
    raise SystemExit("v61aj 1TiB profile should admit full checkpoint")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "checkpoint_storage_profile_requirement_rows.csv")}
if requirements["minimum-additional-bytes-for-full-reserve"]["bytes"] != "294263770976":
    raise SystemExit("v61aj minimum additional bytes requirement mismatch")
if requirements["operator-margin-free-bytes"]["bytes"] != "549755813888":
    raise SystemExit("v61aj operator margin bytes mismatch")

metric = read_csv(run_dir / "checkpoint_storage_profile_metric_rows.csv")[0]
for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61aj metric {field}: expected {value}, got {metric[field]}")

boundary = (run_dir / "V61AJ_CHECKPOINT_STORAGE_PROFILE_ADMISSION_MATRIX_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "profile_rows=6",
    "minimum_additional_bytes_for_full_reserve=294263770976",
    "current_reserve_admitted_shard_rows=0",
    "current_no_reserve_admitted_shard_rows=4",
    "exact_reserve_admitted_shard_rows=59",
    "first_full_reserve_profile_id=full-checkpoint-exact-with-reserve",
    "recommended_operator_free_bytes=549755813888",
    "checkpoint_payload_bytes_downloaded_by_v61aj=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61aj boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61aj_checkpoint_storage_profile_admission_matrix_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61aj_checkpoint_storage_profile_admission_matrix_ready") != 1:
    raise SystemExit("v61aj manifest readiness mismatch")
if manifest.get("profile_rows") != 6:
    raise SystemExit("v61aj manifest profile rows mismatch")
if manifest.get("minimum_additional_bytes_for_full_reserve") != 294263770976:
    raise SystemExit("v61aj manifest minimum bytes mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61aj") != 0:
    raise SystemExit("v61aj manifest must keep downloaded payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61aj sha256 mismatch: {rel}")
PY

echo "v61aj checkpoint storage profile admission matrix smoke passed"
