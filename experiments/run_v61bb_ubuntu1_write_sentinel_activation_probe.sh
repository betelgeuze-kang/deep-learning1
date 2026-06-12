#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bb_ubuntu1_write_sentinel_activation_probe"
RUN_ID="${V61BB_RUN_ID:-write_probe_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
UBUNTU1_TARGET="${V61BB_UBUNTU1_TARGET:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"
SENTINEL_DIR="${V61BB_SENTINEL_DIR:-$UBUNTU1_TARGET/.v61_activation_sentinel}"
SENTINEL_FILE="${V61BB_SENTINEL_FILE:-$SENTINEL_DIR/v61bb_write_probe.json}"
ENABLE_WRITE_SENTINEL="${V61BB_ENABLE_WRITE_SENTINEL:-0}"

if [[ "${V61BB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bb_ubuntu1_write_sentinel_activation_probe_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ba_ubuntu1_activation_handoff_package.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" "$SENTINEL_FILE" "$ENABLE_WRITE_SENTINEL" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
target_dir = Path(sys.argv[5]).expanduser().resolve()
sentinel_file = Path(sys.argv[6]).expanduser().resolve()
enable_write_sentinel = sys.argv[7] == "1"
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


def is_relative_to(path, base):
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


v61ba_dir = results / "v61ba_ubuntu1_activation_handoff_package" / "handoff_001"
v61ba_summary_path = results / "v61ba_ubuntu1_activation_handoff_package_summary.csv"
v61ba_decision_path = results / "v61ba_ubuntu1_activation_handoff_package_decision.csv"
v61ba_summary = read_csv(v61ba_summary_path)[0]
if v61ba_summary.get("v61ba_ubuntu1_activation_handoff_package_ready") != "1":
    raise SystemExit("v61bb requires v61ba_ubuntu1_activation_handoff_package_ready=1")
if Path(v61ba_summary["selected_target_path"]).resolve() != target_dir:
    raise SystemExit("v61bb target must match v61ba selected target path")

for src, rel in [
    (v61ba_summary_path, "source_v61ba/v61ba_ubuntu1_activation_handoff_package_summary.csv"),
    (v61ba_decision_path, "source_v61ba/v61ba_ubuntu1_activation_handoff_package_decision.csv"),
    (v61ba_dir / "ubuntu1_activation_handoff_command_rows.csv", "source_v61ba/ubuntu1_activation_handoff_command_rows.csv"),
    (v61ba_dir / "ubuntu1_activation_handoff_requirement_rows.csv", "source_v61ba/ubuntu1_activation_handoff_requirement_rows.csv"),
    (v61ba_dir / "ubuntu1_activation_handoff_metric_rows.csv", "source_v61ba/ubuntu1_activation_handoff_metric_rows.csv"),
    (v61ba_dir / "runtime_gap_rows.csv", "source_v61ba/runtime_gap_rows.csv"),
    (v61ba_dir / "sha256_manifest.csv", "source_v61ba/sha256_manifest.csv"),
]:
    copy(src, rel)

write_probe_attempted = int(enable_write_sentinel)
write_probe_succeeded = 0
write_probe_error = ""
sentinel_payload = {
    "artifact": "v61bb_ubuntu1_write_sentinel_activation_probe",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "target_path": str(target_dir),
    "sentinel_file": str(sentinel_file),
    "source_v61ba_summary_sha256": sha256(v61ba_summary_path),
    "activation_handoff_command_rows": int(v61ba_summary["activation_handoff_command_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v61bb": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}

if enable_write_sentinel:
    try:
        sentinel_file.parent.mkdir(parents=True, exist_ok=True)
        tmp_file = sentinel_file.with_name(sentinel_file.name + ".tmp")
        with tmp_file.open("w", encoding="utf-8") as handle:
            json.dump(sentinel_payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_file, sentinel_file)
        dir_fd = os.open(str(sentinel_file.parent), os.O_RDONLY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
        write_probe_succeeded = 1
    except OSError as exc:
        write_probe_error = f"{exc.__class__.__name__}:{exc}"

sentinel_exists = int(sentinel_file.is_file())
sentinel_size_bytes = sentinel_file.stat().st_size if sentinel_exists else 0
sentinel_sha256 = sha256(sentinel_file) if sentinel_exists else ""
sentinel_json_valid = 0
sentinel_target_path_match = 0
sentinel_no_payload_claim = 0
sentinel_artifact_match = 0
if sentinel_exists:
    try:
        loaded = json.loads(sentinel_file.read_text(encoding="utf-8"))
        sentinel_json_valid = 1
        sentinel_artifact_match = int(loaded.get("artifact") == "v61bb_ubuntu1_write_sentinel_activation_probe")
        sentinel_target_path_match = int(Path(loaded.get("target_path", "")).resolve() == target_dir)
        sentinel_no_payload_claim = int(
            loaded.get("checkpoint_payload_bytes_downloaded_by_v61bb") == 0
            and loaded.get("checkpoint_payload_bytes_committed_to_repo") == 0
        )
    except (OSError, json.JSONDecodeError):
        sentinel_json_valid = 0

target_outside_repository = int(not is_relative_to(target_dir, root))
sentinel_under_target = int(is_relative_to(sentinel_file, target_dir))
target_directory_exists = int(target_dir.exists() and target_dir.is_dir())
sentinel_parent_exists = int(sentinel_file.parent.exists() and sentinel_file.parent.is_dir())
target_parent_write_access_observed = int(os.access(target_dir, os.W_OK)) if target_directory_exists else 0
ubuntu1_write_witness_ready = int(
    sentinel_exists
    and sentinel_size_bytes > 0
    and sentinel_json_valid
    and sentinel_artifact_match
    and sentinel_target_path_match
    and sentinel_no_payload_claim
    and target_outside_repository
    and sentinel_under_target
)
operator_write_step_resolved_by_witness = ubuntu1_write_witness_ready
activation_target_write_witness_ready = ubuntu1_write_witness_ready
activation_payload_execution_ready = 0
activation_handoff_command_rows = int(v61ba_summary["activation_handoff_command_rows"])

witness_rows = [
    {
        "witness_id": "ubuntu1-sentinel-write-witness",
        "model_id": model_id,
        "target_path": str(target_dir),
        "sentinel_file": str(sentinel_file),
        "write_probe_attempted": str(write_probe_attempted),
        "write_probe_succeeded": str(write_probe_succeeded),
        "write_probe_error": write_probe_error,
        "sentinel_exists": str(sentinel_exists),
        "sentinel_size_bytes": str(sentinel_size_bytes),
        "sentinel_sha256": sentinel_sha256,
        "sentinel_json_valid": str(sentinel_json_valid),
        "sentinel_artifact_match": str(sentinel_artifact_match),
        "sentinel_target_path_match": str(sentinel_target_path_match),
        "sentinel_no_payload_claim": str(sentinel_no_payload_claim),
        "sentinel_under_target": str(sentinel_under_target),
        "target_outside_repository": str(target_outside_repository),
        "target_directory_exists": str(target_directory_exists),
        "sentinel_parent_exists": str(sentinel_parent_exists),
        "target_parent_write_access_observed": str(target_parent_write_access_observed),
        "ubuntu1_write_witness_ready": str(ubuntu1_write_witness_ready),
        "operator_write_step_resolved_by_witness": str(operator_write_step_resolved_by_witness),
        "activation_target_write_witness_ready": str(activation_target_write_witness_ready),
        "activation_payload_execution_ready": str(activation_payload_execution_ready),
        "checkpoint_payload_bytes_downloaded_by_v61bb": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "ubuntu1_write_sentinel_witness_rows.csv", list(witness_rows[0].keys()), witness_rows)

requirement_rows = [
    {"requirement_id": "v61ba-handoff-input", "status": "pass", "actual": v61ba_summary["v61ba_ubuntu1_activation_handoff_package_ready"], "required": "1", "reason": "target-bound handoff package is available"},
    {"requirement_id": "target-bound-handoff-rows", "status": "pass" if activation_handoff_command_rows == 59 else "blocked", "actual": str(activation_handoff_command_rows), "required": "59", "reason": "all checkpoint shard handoff rows must be target-bound"},
    {"requirement_id": "outside-repository-target", "status": "pass" if target_outside_repository else "blocked", "actual": str(target_outside_repository), "required": "1", "reason": "sentinel must be under an outside-repository target"},
    {"requirement_id": "sentinel-under-target", "status": "pass" if sentinel_under_target else "blocked", "actual": str(sentinel_under_target), "required": "1", "reason": "write witness must live inside the ubuntu-1 target directory"},
    {"requirement_id": "sentinel-write-witness", "status": "pass" if ubuntu1_write_witness_ready else "blocked", "actual": str(ubuntu1_write_witness_ready), "required": "1", "reason": "small JSON sentinel proves operator/escalated write path without checkpoint payload"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61bb writes only a JSON sentinel and no checkpoint payload"},
    {"requirement_id": "explicit-download-execution", "status": "blocked", "actual": "0", "required": "1", "reason": "payload download execution remains disabled"},
]
write_csv(run_dir / "ubuntu1_write_sentinel_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bb_ubuntu1_write_sentinel_activation_probe_metrics",
    "model_id": model_id,
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": "1",
    "v61ba_ubuntu1_activation_handoff_package_ready": v61ba_summary["v61ba_ubuntu1_activation_handoff_package_ready"],
    "selected_target_path": str(target_dir),
    "sentinel_file": str(sentinel_file),
    "write_probe_attempted": str(write_probe_attempted),
    "write_probe_succeeded": str(write_probe_succeeded),
    "sentinel_exists": str(sentinel_exists),
    "sentinel_size_bytes": str(sentinel_size_bytes),
    "sentinel_sha256": sentinel_sha256,
    "sentinel_json_valid": str(sentinel_json_valid),
    "sentinel_artifact_match": str(sentinel_artifact_match),
    "sentinel_target_path_match": str(sentinel_target_path_match),
    "sentinel_no_payload_claim": str(sentinel_no_payload_claim),
    "sentinel_under_target": str(sentinel_under_target),
    "target_outside_repository": str(target_outside_repository),
    "target_directory_exists": str(target_directory_exists),
    "sentinel_parent_exists": str(sentinel_parent_exists),
    "target_parent_write_access_ready_from_v61az": v61ba_summary["target_parent_write_access_ready"],
    "target_parent_write_access_observed": str(target_parent_write_access_observed),
    "ubuntu1_write_witness_ready": str(ubuntu1_write_witness_ready),
    "operator_write_step_resolved_by_witness": str(operator_write_step_resolved_by_witness),
    "activation_target_write_witness_ready": str(activation_target_write_witness_ready),
    "activation_handoff_command_rows": str(activation_handoff_command_rows),
    "target_bound_verify_command_rows": v61ba_summary["target_bound_verify_command_rows"],
    "target_bound_full_page_hash_command_rows": v61ba_summary["target_bound_full_page_hash_command_rows"],
    "target_bound_generation_recheck_command_rows": v61ba_summary["target_bound_generation_recheck_command_rows"],
    "activation_payload_execution_ready": str(activation_payload_execution_ready),
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
write_csv(run_dir / "ubuntu1_write_sentinel_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, [key for key in metric if key != "metric_id"], [{key: value for key, value in metric.items() if key != "metric_id"}])

runtime_gap_rows = [
    ("v61ba-handoff-input", "ready", "target-bound handoff rows are available"),
    ("target-bound-handoff-rows", "ready" if activation_handoff_command_rows == 59 else "blocked", "59 shard handoff rows are required"),
    ("outside-repository-target", "ready" if target_outside_repository else "blocked", str(target_dir)),
    ("sentinel-under-target", "ready" if sentinel_under_target else "blocked", str(sentinel_file)),
    ("sentinel-write-witness", "ready" if ubuntu1_write_witness_ready else "blocked", write_probe_error or "sentinel witness not available"),
    ("operator-write-step", "ready" if operator_write_step_resolved_by_witness else "blocked", "resolved by sentinel witness" if operator_write_step_resolved_by_witness else "requires escalated/operator write"),
    ("explicit-download-execution", "blocked", "checkpoint payload execution remains disabled"),
    ("local-checkpoint-materialization", "blocked", "checkpoint shards are not materialized"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage is not complete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "sentinel write is not decode latency evidence"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in runtime_gap_rows])

decision_rows = [
    {"gate": "v61ba-handoff-input", "status": "pass", "reason": "v61ba handoff package is ready"},
    {"gate": "target-bound-handoff-rows", "status": "pass" if activation_handoff_command_rows == 59 else "blocked", "reason": f"activation_handoff_command_rows={activation_handoff_command_rows}"},
    {"gate": "outside-repository-target", "status": "pass" if target_outside_repository else "blocked", "reason": str(target_dir)},
    {"gate": "sentinel-under-target", "status": "pass" if sentinel_under_target else "blocked", "reason": str(sentinel_file)},
    {"gate": "sentinel-write-witness", "status": "pass" if ubuntu1_write_witness_ready else "blocked", "reason": write_probe_error or f"sentinel_exists={sentinel_exists} sentinel_json_valid={sentinel_json_valid}"},
    {"gate": "operator-write-step", "status": "pass" if operator_write_step_resolved_by_witness else "blocked", "reason": "small sentinel write witness resolves target write activation" if operator_write_step_resolved_by_witness else "no write witness"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain zero"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "payload download remains disabled"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bb ubuntu-1 Write Sentinel Activation Probe Boundary

This artifact records a tiny JSON sentinel write witness inside the ubuntu-1
warehouse target. It does not execute checkpoint downloads and does not write
checkpoint payload bytes.

Evidence emitted:

- selected_target_path={target_dir}
- sentinel_file={sentinel_file}
- write_probe_attempted={write_probe_attempted}
- write_probe_succeeded={write_probe_succeeded}
- sentinel_exists={sentinel_exists}
- sentinel_json_valid={sentinel_json_valid}
- sentinel_target_path_match={sentinel_target_path_match}
- sentinel_no_payload_claim={sentinel_no_payload_claim}
- ubuntu1_write_witness_ready={ubuntu1_write_witness_ready}
- operator_write_step_resolved_by_witness={operator_write_step_resolved_by_witness}
- activation_target_write_witness_ready={activation_target_write_witness_ready}
- activation_handoff_command_rows={activation_handoff_command_rows}
- activation_payload_execution_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bb=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 has an operator/escalated write witness for the
target-bound activation handoff path.

Blocked wording: checkpoint payload download execution, local checkpoint
materialization, full safetensors page-hash coverage, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BB_UBUNTU1_WRITE_SENTINEL_ACTIVATION_PROBE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bb_ubuntu1_write_sentinel_activation_probe",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": 1,
    "selected_target_path": str(target_dir),
    "sentinel_file": str(sentinel_file),
    "write_probe_attempted": write_probe_attempted,
    "write_probe_succeeded": write_probe_succeeded,
    "ubuntu1_write_witness_ready": ubuntu1_write_witness_ready,
    "activation_target_write_witness_ready": activation_target_write_witness_ready,
    "activation_payload_execution_ready": activation_payload_execution_ready,
    "checkpoint_payload_bytes_downloaded_by_v61bb": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bb_ubuntu1_write_sentinel_activation_probe_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bb_ubuntu1_write_sentinel_activation_probe_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
