#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61p_local_ssd_checkpoint_residency_preflight/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v61p_local_ssd_checkpoint_residency_preflight_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61p_local_ssd_checkpoint_residency_preflight_decision.csv"

V61P_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_relative_to(path, base):
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61p summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61p_local_ssd_checkpoint_residency_preflight_ready": "1",
    "v61o_checkpoint_shard_header_probe_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "checkpoint_shard_rows": "59",
    "checkpoint_download_plan_rows": "59",
    "local_shard_presence_rows": "59",
    "checkpoint_payload_bytes_downloaded_by_v61p": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61p {field}: expected {value}, got {summary.get(field)}")

if int(summary["total_checkpoint_bytes_required"]) <= 200_000_000_000:
    raise SystemExit("v61p should require a large 100B-class checkpoint byte budget")
if int(summary["required_with_reserve_bytes"]) <= int(summary["total_checkpoint_bytes_required"]):
    raise SystemExit("v61p required_with_reserve should exceed raw checkpoint bytes")
if int(summary["available_ssd_bytes"]) < 0:
    raise SystemExit("v61p available SSD bytes should be non-negative")

warehouse_path = Path(summary["ssd_warehouse_path"]).resolve()
if is_relative_to(warehouse_path, root):
    raise SystemExit("v61p default warehouse path should be outside the repository")
if summary["ssd_warehouse_outside_repo"] != "1":
    raise SystemExit("v61p should mark the default warehouse outside the repository")

resident_rows = int(summary["local_complete_shard_rows"])
if resident_rows < 0 or resident_rows > 59:
    raise SystemExit("v61p resident shard rows out of range")
ready_expected = int(
    summary["ssd_disk_budget_pass"] == "1"
    and summary["ssd_warehouse_outside_repo"] == "1"
    and resident_rows == 59
)
if int(summary["local_checkpoint_residency_ready"]) != ready_expected:
    raise SystemExit("v61p local residency readiness condition mismatch")
if int(summary["local_resident_checkpoint_bytes"]) < 0:
    raise SystemExit("v61p local resident checkpoint bytes should be non-negative")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61o-checkpoint-shard-header-probe-input",
    "ssd-warehouse-outside-repository",
    "checkpoint-download-plan",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61p gate should pass: {gate}")
for gate in [
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61p gate should remain blocked: {gate}")
if decisions.get("local-ssd-checkpoint-residency") not in {"pass", "blocked"}:
    raise SystemExit("v61p residency decision should be explicit")

required_files = [
    "ssd_warehouse_probe_rows.csv",
    "ssd_disk_budget_rows.csv",
    "checkpoint_residency_requirement_rows.csv",
    "checkpoint_download_plan_rows.csv",
    "local_shard_presence_rows.csv",
    "runtime_gap_rows.csv",
    "V61P_LOCAL_SSD_CHECKPOINT_RESIDENCY_PREFLIGHT_BOUNDARY.md",
    "v61p_local_ssd_checkpoint_residency_preflight_manifest.json",
    "sha256_manifest.csv",
    "source_v61o/checkpoint_shard_http_identity_rows.csv",
    "source_v61o/safetensors_header_probe_rows.csv",
    "source_v61o/v61o_checkpoint_shard_header_probe_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61p artifact: {rel}")

warehouse_rows = read_csv(run_dir / "ssd_warehouse_probe_rows.csv")
if len(warehouse_rows) != 1:
    raise SystemExit("v61p should emit one warehouse probe row")
warehouse = warehouse_rows[0]
if warehouse["checkpoint_payload_bytes_committed_to_repo"] != "0":
    raise SystemExit("v61p should not commit checkpoint payload bytes to the repo")
if warehouse["checkpoint_payload_bytes_downloaded_by_v61p"] != "0":
    raise SystemExit("v61p should not download checkpoint payload bytes")
if warehouse["warehouse_outside_repo"] != "1":
    raise SystemExit("v61p warehouse should be outside repo")

disk_rows = read_csv(run_dir / "ssd_disk_budget_rows.csv")
if len(disk_rows) != 1 or disk_rows[0]["df_probe_ready"] != "1":
    raise SystemExit("v61p disk probe should be ready")
if int(disk_rows[0]["available_bytes"]) != int(summary["available_ssd_bytes"]):
    raise SystemExit("v61p disk available bytes should match summary")

requirements = {row["requirement"]: row for row in read_csv(run_dir / "checkpoint_residency_requirement_rows.csv")}
if requirements["checkpoint_shards"]["required_bytes"] != summary["total_checkpoint_bytes_required"]:
    raise SystemExit("v61p requirement bytes mismatch")
if requirements["warehouse_outside_repository"]["status"] != "pass":
    raise SystemExit("v61p outside-repo requirement should pass")
if requirements["no_repo_weight_payload"]["status"] != "pass":
    raise SystemExit("v61p no-repo-weight requirement should pass")

download_plan = read_csv(run_dir / "checkpoint_download_plan_rows.csv")
presence = read_csv(run_dir / "local_shard_presence_rows.csv")
http_rows = read_csv(run_dir / "source_v61o/checkpoint_shard_http_identity_rows.csv")
if len(download_plan) != 59 or len(presence) != 59 or len(http_rows) != 59:
    raise SystemExit("v61p should bind all 59 checkpoint shards")
if any(row["downloaded_by_v61p"] != "0" for row in download_plan):
    raise SystemExit("v61p download plan should not execute downloads")
if any(row["model_id"] != "mistralai/Mixtral-8x22B-v0.1" for row in download_plan):
    raise SystemExit("v61p download plan model mismatch")
if any("huggingface-cli download" not in row["download_command"] for row in download_plan):
    raise SystemExit("v61p download plan should emit resumable Hugging Face commands")

http_by_shard = {row["shard_name"]: row for row in http_rows}
for row in download_plan:
    source = http_by_shard[row["shard_name"]]
    if row["source_url"] != source["source_url"] or row["expected_bytes"] != source["content_length"]:
        raise SystemExit("v61p download plan should mirror v61o shard identity")
for row in presence:
    source = http_by_shard[row["shard_name"]]
    if row["expected_bytes"] != source["content_length"]:
        raise SystemExit("v61p presence rows should mirror v61o shard size")
    expected_resident = int(row["local_file_exists"] == "1" and row["actual_bytes"] == row["expected_bytes"])
    if int(row["local_shard_resident"]) != expected_resident:
        raise SystemExit("v61p local_shard_resident condition mismatch")
    if row["hash_verified"] != "0":
        raise SystemExit("v61p should not claim full shard hash verification")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in [
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61p gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61p_local_ssd_checkpoint_residency_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61p_local_ssd_checkpoint_residency_preflight_ready") != 1:
    raise SystemExit("v61p manifest readiness mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61p") != 0:
    raise SystemExit("v61p manifest should keep download bytes at zero")
if manifest.get("real_checkpoint_weight_bytes_materialized") != 0:
    raise SystemExit("v61p manifest should not claim checkpoint materialization")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61p manifest should keep real generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61p sha256 mismatch: {rel}")

boundary = (run_dir / "V61P_LOCAL_SSD_CHECKPOINT_RESIDENCY_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Local SSD Checkpoint Residency Preflight",
    "checkpoint_shard_rows=59",
    "checkpoint_payload_bytes_downloaded_by_v61p=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "real_checkpoint_weight_bytes_materialized=0",
    "Blocked wording: completed checkpoint residency",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61p boundary missing {snippet}")
PY

echo "v61p local SSD checkpoint residency preflight smoke passed"
