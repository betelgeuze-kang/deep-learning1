#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bb_ubuntu1_write_sentinel_activation_probe/write_probe_001"
SUMMARY_CSV="$RESULTS_DIR/v61bb_ubuntu1_write_sentinel_activation_probe_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bb_ubuntu1_write_sentinel_activation_probe_decision.csv"

V61BB_REUSE_EXISTING="${V61BB_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bb_ubuntu1_write_sentinel_activation_probe.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"


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
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": "1",
    "v61ba_ubuntu1_activation_handoff_package_ready": "1",
    "selected_target_path": ubuntu1_target,
    "sentinel_exists": "1",
    "sentinel_json_valid": "1",
    "sentinel_artifact_match": "1",
    "sentinel_target_path_match": "1",
    "sentinel_no_payload_claim": "1",
    "sentinel_under_target": "1",
    "target_outside_repository": "1",
    "target_directory_exists": "1",
    "sentinel_parent_exists": "1",
    "ubuntu1_write_witness_ready": "1",
    "operator_write_step_resolved_by_witness": "1",
    "activation_target_write_witness_ready": "1",
    "activation_handoff_command_rows": "59",
    "target_bound_verify_command_rows": "59",
    "target_bound_full_page_hash_command_rows": "59",
    "target_bound_generation_recheck_command_rows": "59",
    "activation_payload_execution_ready": "0",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bb {field}: expected {value}, got {summary.get(field)}")

if not summary["sentinel_file"].startswith(ubuntu1_target + "/.v61_activation_sentinel/"):
    raise SystemExit("v61bb sentinel file should be under the ubuntu-1 activation sentinel dir")
if int(summary["sentinel_size_bytes"]) <= 0:
    raise SystemExit("v61bb sentinel should be non-empty")
if not summary["sentinel_sha256"].startswith("sha256:"):
    raise SystemExit("v61bb sentinel hash should be recorded")
if summary["write_probe_attempted"] not in {"0", "1"}:
    raise SystemExit("v61bb write probe attempted should be boolean")
if summary["write_probe_succeeded"] not in {"0", "1"}:
    raise SystemExit("v61bb write probe succeeded should be boolean")
if summary["write_probe_attempted"] == "1" and summary["write_probe_succeeded"] != "1":
    raise SystemExit("v61bb attempted write probe should succeed")

required_files = [
    "ubuntu1_write_sentinel_witness_rows.csv",
    "ubuntu1_write_sentinel_requirement_rows.csv",
    "ubuntu1_write_sentinel_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BB_UBUNTU1_WRITE_SENTINEL_ACTIVATION_PROBE_BOUNDARY.md",
    "v61bb_ubuntu1_write_sentinel_activation_probe_manifest.json",
    "sha256_manifest.csv",
    "source_v61ba/ubuntu1_activation_handoff_command_rows.csv",
    "source_v61ba/ubuntu1_activation_handoff_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bb artifact: {rel}")

witness = read_csv(run_dir / "ubuntu1_write_sentinel_witness_rows.csv")[0]
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_write_sentinel_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_write_sentinel_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

for field, value in expected.items():
    if field in witness and witness[field] != value:
        raise SystemExit(f"v61bb witness {field}: expected {value}, got {witness[field]}")
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bb metric {field}: expected {value}, got {metric[field]}")

if witness["sentinel_sha256"] != summary["sentinel_sha256"]:
    raise SystemExit("v61bb witness sentinel hash mismatch")
if witness["sentinel_file"] != summary["sentinel_file"]:
    raise SystemExit("v61bb witness sentinel path mismatch")

for requirement_id in [
    "v61ba-handoff-input",
    "target-bound-handoff-rows",
    "outside-repository-target",
    "sentinel-under-target",
    "sentinel-write-witness",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bb requirement should pass: {requirement_id}")
if requirements["explicit-download-execution"]["status"] != "blocked":
    raise SystemExit("v61bb explicit download execution should remain blocked")

for gate in [
    "v61ba-handoff-input",
    "target-bound-handoff-rows",
    "outside-repository-target",
    "sentinel-under-target",
    "sentinel-write-witness",
    "operator-write-step",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bb gate should pass: {gate}")
for gate in [
    "explicit-download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bb gate should remain blocked: {gate}")

for gap in [
    "v61ba-handoff-input",
    "target-bound-handoff-rows",
    "outside-repository-target",
    "sentinel-under-target",
    "sentinel-write-witness",
    "operator-write-step",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bb gap should be ready: {gap}")
for gap in [
    "explicit-download-execution",
    "local-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bb gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61bb_ubuntu1_write_sentinel_activation_probe_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bb_ubuntu1_write_sentinel_activation_probe_ready") != 1:
    raise SystemExit("v61bb manifest readiness mismatch")
if manifest.get("ubuntu1_write_witness_ready") != 1:
    raise SystemExit("v61bb manifest write witness mismatch")
if manifest.get("activation_target_write_witness_ready") != 1:
    raise SystemExit("v61bb manifest activation witness mismatch")
if manifest.get("activation_payload_execution_ready") != 0:
    raise SystemExit("v61bb manifest payload execution must remain blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bb") != 0:
    raise SystemExit("v61bb manifest must not download payload bytes")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61bb manifest must not commit payload bytes")

sentinel_path = Path(summary["sentinel_file"])
sentinel = json.loads(sentinel_path.read_text(encoding="utf-8"))
if sentinel.get("artifact") != "v61bb_ubuntu1_write_sentinel_activation_probe":
    raise SystemExit("v61bb sentinel artifact mismatch")
if sentinel.get("target_path") != ubuntu1_target:
    raise SystemExit("v61bb sentinel target mismatch")
if sentinel.get("checkpoint_payload_bytes_downloaded_by_v61bb") != 0:
    raise SystemExit("v61bb sentinel must not claim downloaded payload bytes")
if sentinel.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61bb sentinel must not claim committed payload bytes")
if sha256(sentinel_path) != summary["sentinel_sha256"]:
    raise SystemExit("v61bb sentinel hash should match summary")

boundary = (run_dir / "V61BB_UBUNTU1_WRITE_SENTINEL_ACTIVATION_PROBE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "ubuntu1_write_witness_ready=1",
    "operator_write_step_resolved_by_witness=1",
    "activation_target_write_witness_ready=1",
    "activation_payload_execution_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bb=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bb boundary missing snippet: {snippet}")

sha_rows = read_csv(run_dir / "sha256_manifest.csv")
if not sha_rows:
    raise SystemExit("v61bb sha manifest should not be empty")
for row in sha_rows:
    rel = row["path"]
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"v61bb sha manifest points to missing file: {rel}")
    if sha256(path) != row["sha256"]:
        raise SystemExit(f"v61bb sha mismatch: {rel}")

print("v61bb ubuntu-1 write sentinel activation probe smoke passed")
PY
