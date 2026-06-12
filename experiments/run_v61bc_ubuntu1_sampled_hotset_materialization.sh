#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bc_ubuntu1_sampled_hotset_materialization"
RUN_ID="${V61BC_RUN_ID:-materialization_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
UBUNTU1_TARGET="${V61BC_UBUNTU1_TARGET:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"
UBUNTU1_HOTSET_ROOT="${V61BC_UBUNTU1_HOTSET_ROOT:-$UBUNTU1_TARGET/.v61_sampled_hotset_pages}"
ENABLE_MATERIALIZATION="${V61BC_ENABLE_MATERIALIZATION:-0}"

if [[ "${V61BC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bc_ubuntu1_sampled_hotset_materialization_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bb_ubuntu1_write_sentinel_activation_probe.sh" >/dev/null
V61Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61y_hotset_local_materialization_verifier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" "$UBUNTU1_HOTSET_ROOT" "$ENABLE_MATERIALIZATION" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
ubuntu1_target = Path(sys.argv[5]).expanduser().resolve()
ubuntu1_hotset_root = Path(sys.argv[6]).expanduser().resolve()
enable_materialization = sys.argv[7] == "1"
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


def target_page_path(row):
    shard = row["shard_name"]
    page_index = int(row["shard_page_index"])
    return ubuntu1_hotset_root / shard / f"page_{page_index:08d}.bin"


v61bb_dir = results / "v61bb_ubuntu1_write_sentinel_activation_probe" / "write_probe_001"
v61y_dir = results / "v61y_hotset_local_materialization_verifier" / "verify_001"
v61bb_summary_path = results / "v61bb_ubuntu1_write_sentinel_activation_probe_summary.csv"
v61y_summary_path = results / "v61y_hotset_local_materialization_verifier_summary.csv"
v61bb_summary = read_csv(v61bb_summary_path)[0]
v61y_summary = read_csv(v61y_summary_path)[0]
if v61bb_summary.get("v61bb_ubuntu1_write_sentinel_activation_probe_ready") != "1":
    raise SystemExit("v61bc requires v61bb_ubuntu1_write_sentinel_activation_probe_ready=1")
if v61bb_summary.get("ubuntu1_write_witness_ready") != "1":
    raise SystemExit("v61bc requires ubuntu1_write_witness_ready=1")
if v61y_summary.get("v61y_hotset_local_materialization_verifier_ready") != "1":
    raise SystemExit("v61bc requires v61y_hotset_local_materialization_verifier_ready=1")
if v61y_summary.get("hotset_payload_materialization_ready") != "1":
    raise SystemExit("v61bc requires v61y hotset_payload_materialization_ready=1")
if Path(v61bb_summary["selected_target_path"]).resolve() != ubuntu1_target:
    raise SystemExit("v61bc target must match v61bb selected target path")

for src, rel in [
    (v61bb_summary_path, "source_v61bb/v61bb_ubuntu1_write_sentinel_activation_probe_summary.csv"),
    (results / "v61bb_ubuntu1_write_sentinel_activation_probe_decision.csv", "source_v61bb/v61bb_ubuntu1_write_sentinel_activation_probe_decision.csv"),
    (v61bb_dir / "ubuntu1_write_sentinel_witness_rows.csv", "source_v61bb/ubuntu1_write_sentinel_witness_rows.csv"),
    (v61bb_dir / "sha256_manifest.csv", "source_v61bb/sha256_manifest.csv"),
    (v61y_summary_path, "source_v61y/v61y_hotset_local_materialization_verifier_summary.csv"),
    (results / "v61y_hotset_local_materialization_verifier_decision.csv", "source_v61y/v61y_hotset_local_materialization_verifier_decision.csv"),
    (v61y_dir / "hotset_local_materialization_rows.csv", "source_v61y/hotset_local_materialization_rows.csv"),
    (v61y_dir / "hotset_local_readback_rows.csv", "source_v61y/hotset_local_readback_rows.csv"),
    (v61y_dir / "sha256_manifest.csv", "source_v61y/sha256_manifest.csv"),
]:
    copy(src, rel)

source_rows = read_csv(v61y_dir / "hotset_local_materialization_rows.csv")
if len(source_rows) != 16:
    raise SystemExit("v61bc expects 16 v61y hotset materialization rows")

target_outside_repository = int(not is_relative_to(ubuntu1_target, root))
hotset_root_under_target = int(is_relative_to(ubuntu1_hotset_root, ubuntu1_target))
target_directory_exists = int(ubuntu1_target.exists() and ubuntu1_target.is_dir())
target_write_observed = int(os.access(ubuntu1_target, os.W_OK)) if target_directory_exists else 0

materialization_rows = []
readback_rows = []
present_rows = 0
hash_match_rows = 0
readback_hash_match_rows = 0
persisted_bytes = 0
copied_bytes = 0
source_hash_match_rows = 0
target_path_errors = 0

for idx, source in enumerate(source_rows):
    source_path = Path(source["planned_local_page_path"]).expanduser().resolve()
    target_path = target_page_path(source)
    expected_sha = source["remote_page_sha256"]
    expected_bytes = int(source["expected_page_bytes"])
    source_exists = source_path.is_file()
    source_bytes = source_path.stat().st_size if source_exists else 0
    source_sha = sha256(source_path) if source_exists and source_bytes == expected_bytes else ""
    source_hash_match = int(source_exists and source_bytes == expected_bytes and source_sha == expected_sha)
    source_hash_match_rows += source_hash_match
    target_under_ubuntu1 = int(is_relative_to(target_path, ubuntu1_target))
    target_inside_repo = int(is_relative_to(target_path, root))
    if not target_under_ubuntu1 or target_inside_repo:
        target_path_errors += 1

    copied_by_v61bc = 0
    materialization_error = ""
    before_exists = target_path.is_file()
    before_bytes = target_path.stat().st_size if before_exists else 0
    before_hash_match = before_exists and before_bytes == expected_bytes and sha256(target_path) == expected_sha
    if enable_materialization and source_hash_match and not before_hash_match:
        try:
            target_path.parent.mkdir(parents=True, exist_ok=True)
            tmp = target_path.with_name(target_path.name + ".tmp")
            shutil.copyfile(source_path, tmp)
            with tmp.open("rb") as handle:
                os.fsync(handle.fileno())
            os.replace(tmp, target_path)
            dir_fd = os.open(str(target_path.parent), os.O_RDONLY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
            copied_by_v61bc = 1
            copied_bytes += expected_bytes
        except OSError as exc:
            materialization_error = f"{exc.__class__.__name__}:{exc}"

    target_exists = target_path.is_file()
    target_bytes = target_path.stat().st_size if target_exists else 0
    target_sha = sha256(target_path) if target_exists and target_bytes == expected_bytes else ""
    target_hash_match = int(target_exists and target_bytes == expected_bytes and target_sha == expected_sha)
    if target_hash_match:
        present_rows += 1
        hash_match_rows += 1
        persisted_bytes += target_bytes

    readback_bytes = 0
    readback_sha = ""
    read_start = time.perf_counter()
    if target_hash_match:
        h = hashlib.sha256()
        with target_path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                readback_bytes += len(chunk)
                h.update(chunk)
        readback_sha = "sha256:" + h.hexdigest()
    read_ms = (time.perf_counter() - read_start) * 1000.0
    readback_hash_match = int(readback_sha == expected_sha and readback_bytes == expected_bytes)
    readback_hash_match_rows += readback_hash_match

    materialization_rows.append(
        {
            "ubuntu1_hotset_materialization_id": f"v61bc_ubuntu1_hotset_materialization_{idx:04d}",
            "source_hotset_materialization_id": source["hotset_materialization_id"],
            "hotset_page_id": source["hotset_page_id"],
            "remote_sample_id": source["remote_sample_id"],
            "model_id": model_id,
            "shard_name": source["shard_name"],
            "shard_page_index": source["shard_page_index"],
            "node_type": source["node_type"],
            "tensor_role": source["tensor_role"],
            "layer_index": source["layer_index"],
            "expert_index": source["expert_index"],
            "source_local_page_path": str(source_path),
            "source_local_page_exists": str(int(source_exists)),
            "source_local_page_sha256": source_sha,
            "source_local_hash_match": str(source_hash_match),
            "ubuntu1_page_path": str(target_path),
            "ubuntu1_page_under_target": str(target_under_ubuntu1),
            "ubuntu1_page_inside_repository": str(target_inside_repo),
            "remote_page_sha256": expected_sha,
            "ubuntu1_page_sha256": target_sha,
            "expected_page_bytes": str(expected_bytes),
            "ubuntu1_page_bytes": str(target_bytes),
            "ubuntu1_page_exists": str(int(target_exists)),
            "ubuntu1_hash_match": str(target_hash_match),
            "materialized_by_v61bc": str(copied_by_v61bc),
            "materialization_error": materialization_error,
            "checkpoint_payload_bytes_persisted_on_ubuntu1": str(target_bytes if target_hash_match else 0),
            "checkpoint_payload_bytes_copied_to_ubuntu1_by_v61bc": str(expected_bytes if copied_by_v61bc else 0),
            "checkpoint_payload_bytes_downloaded_by_v61bc": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "full_checkpoint_materialization_ready": "0",
            "full_safetensors_page_hash_binding_ready": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
    readback_rows.append(
        {
            "readback_id": f"v61bc_ubuntu1_hotset_readback_{idx:04d}",
            "hotset_page_id": source["hotset_page_id"],
            "remote_sample_id": source["remote_sample_id"],
            "read_mode": "ubuntu1-local-file-stream-readback",
            "ubuntu1_page_path": str(target_path),
            "readback_bytes": str(readback_bytes),
            "readback_sha256": readback_sha,
            "remote_page_sha256": expected_sha,
            "readback_hash_match": str(readback_hash_match),
            "readback_ms": f"{read_ms:.6f}",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

hotset_rows = len(materialization_rows)
ubuntu1_sampled_hotset_materialization_ready = int(
    hotset_rows == 16
    and source_hash_match_rows == 16
    and present_rows == 16
    and hash_match_rows == 16
    and readback_hash_match_rows == 16
    and target_path_errors == 0
    and target_outside_repository
    and hotset_root_under_target
)
expected_total_bytes = sum(int(row["expected_page_bytes"]) for row in materialization_rows)

metric = {
    "metric_id": "v61bc_ubuntu1_sampled_hotset_materialization_metrics",
    "model_id": model_id,
    "v61bc_ubuntu1_sampled_hotset_materialization_ready": "1",
    "v61bb_ubuntu1_write_sentinel_activation_probe_ready": v61bb_summary["v61bb_ubuntu1_write_sentinel_activation_probe_ready"],
    "v61y_hotset_local_materialization_verifier_ready": v61y_summary["v61y_hotset_local_materialization_verifier_ready"],
    "ubuntu1_write_witness_ready": v61bb_summary["ubuntu1_write_witness_ready"],
    "selected_target_path": str(ubuntu1_target),
    "ubuntu1_hotset_root": str(ubuntu1_hotset_root),
    "target_outside_repository": str(target_outside_repository),
    "hotset_root_under_target": str(hotset_root_under_target),
    "target_directory_exists": str(target_directory_exists),
    "target_write_observed": str(target_write_observed),
    "hotset_page_rows": str(hotset_rows),
    "source_local_hotset_hash_match_rows": str(source_hash_match_rows),
    "ubuntu1_hotset_page_present_rows": str(present_rows),
    "ubuntu1_hotset_hash_match_rows": str(hash_match_rows),
    "ubuntu1_hotset_readback_hash_match_rows": str(readback_hash_match_rows),
    "moe_hotset_page_rows": str(sum(1 for row in materialization_rows if row["node_type"] == "moe_expert_page_node")),
    "embedding_hotset_page_rows": str(sum(1 for row in materialization_rows if row["node_type"] == "embedding_page_node")),
    "sampled_hotset_checkpoint_payload_bytes_expected": str(expected_total_bytes),
    "sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1": str(persisted_bytes),
    "checkpoint_payload_bytes_copied_to_ubuntu1_by_v61bc": str(copied_bytes),
    "checkpoint_payload_bytes_downloaded_by_v61bc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "ubuntu1_sampled_hotset_materialization_ready": str(ubuntu1_sampled_hotset_materialization_ready),
    "ubuntu1_hotset_readback_verify_ready": str(int(readback_hash_match_rows == 16)),
    "activation_payload_execution_ready": "0",
    "download_execution_ready": "0",
    "full_checkpoint_materialization_ready": "0",
    "materialization_admission_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_100b_open_weight_materialized": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_sampled_hotset_materialization_rows.csv", list(materialization_rows[0].keys()), materialization_rows)
write_csv(run_dir / "ubuntu1_sampled_hotset_readback_rows.csv", list(readback_rows[0].keys()), readback_rows)
write_csv(run_dir / "ubuntu1_sampled_hotset_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, [key for key in metric if key != "metric_id"], [{key: value for key, value in metric.items() if key != "metric_id"}])

requirement_rows = [
    {"requirement_id": "v61bb-write-witness-input", "status": "pass", "actual": v61bb_summary["ubuntu1_write_witness_ready"], "required": "1", "reason": "ubuntu-1 write witness is ready"},
    {"requirement_id": "v61y-sampled-hotset-input", "status": "pass", "actual": v61y_summary["hotset_payload_materialization_ready"], "required": "1", "reason": "source sampled hotset pages are hash verified"},
    {"requirement_id": "outside-repository-target", "status": "pass" if target_outside_repository else "blocked", "actual": str(target_outside_repository), "required": "1", "reason": "ubuntu-1 target must stay outside repo"},
    {"requirement_id": "hotset-root-under-target", "status": "pass" if hotset_root_under_target else "blocked", "actual": str(hotset_root_under_target), "required": "1", "reason": "sampled pages must live under the ubuntu-1 target"},
    {"requirement_id": "ubuntu1-sampled-hotset-materialization", "status": "pass" if ubuntu1_sampled_hotset_materialization_ready else "blocked", "actual": f"{hash_match_rows}/16", "required": "16/16", "reason": "all sampled hotset pages must be present and hash matched on ubuntu-1"},
    {"requirement_id": "ubuntu1-sampled-hotset-readback", "status": "pass" if readback_hash_match_rows == 16 else "blocked", "actual": f"{readback_hash_match_rows}/16", "required": "16/16", "reason": "all ubuntu-1 sampled pages must read back with matching hashes"},
    {"requirement_id": "bounded-sampled-payload-only", "status": "pass" if persisted_bytes == expected_total_bytes == 33554432 else "blocked", "actual": str(persisted_bytes), "required": "33554432", "reason": "only 16 bounded 2 MiB sampled pages are materialized"},
    {"requirement_id": "no-network-download-by-v61bc", "status": "pass", "actual": "0", "required": "0", "reason": "v61bc copies from existing v61y verified pages and does not fetch remote payload"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "checkpoint payload bytes are outside the repo and not committed"},
    {"requirement_id": "full-checkpoint-materialization", "status": "blocked", "actual": "0", "required": "1", "reason": "only bounded sampled hotset pages are materialized"},
]
write_csv(run_dir / "ubuntu1_sampled_hotset_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    ("v61bb-write-witness-input", "ready", "ubuntu-1 write witness is ready"),
    ("v61y-sampled-hotset-input", "ready", "source sampled hotset pages are ready"),
    ("ubuntu1-sampled-hotset-materialization", "ready" if ubuntu1_sampled_hotset_materialization_ready else "blocked", f"{hash_match_rows}/16 ubuntu-1 sampled pages hash matched"),
    ("ubuntu1-sampled-hotset-readback", "ready" if readback_hash_match_rows == 16 else "blocked", f"{readback_hash_match_rows}/16 ubuntu-1 sampled pages read back"),
    ("bounded-sampled-payload-only", "ready" if persisted_bytes == 33554432 else "blocked", f"{persisted_bytes} bytes persisted on ubuntu-1"),
    ("explicit-download-execution", "blocked", "v61bc performs no network checkpoint download"),
    ("full-checkpoint-materialization", "blocked", "only 16 sampled hotset pages are materialized"),
    ("local-checkpoint-materialization", "blocked", "full shard identity verification remains blocked"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage is not complete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "sampled hotset copy/readback is not decode latency evidence"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in runtime_gap_rows])

decision_rows = [
    {"gate": "v61bb-write-witness-input", "status": "pass", "reason": "v61bb write witness is ready"},
    {"gate": "v61y-sampled-hotset-input", "status": "pass", "reason": "v61y sampled hotset pages are hash verified"},
    {"gate": "outside-repository-target", "status": "pass" if target_outside_repository else "blocked", "reason": str(ubuntu1_target)},
    {"gate": "hotset-root-under-target", "status": "pass" if hotset_root_under_target else "blocked", "reason": str(ubuntu1_hotset_root)},
    {"gate": "ubuntu1-sampled-hotset-materialization", "status": "pass" if ubuntu1_sampled_hotset_materialization_ready else "blocked", "reason": f"{hash_match_rows}/16 sampled pages hash matched"},
    {"gate": "ubuntu1-sampled-hotset-readback", "status": "pass" if readback_hash_match_rows == 16 else "blocked", "reason": f"{readback_hash_match_rows}/16 sampled pages read back"},
    {"gate": "bounded-sampled-payload-only", "status": "pass" if persisted_bytes == 33554432 else "blocked", "reason": f"persisted_bytes={persisted_bytes}"},
    {"gate": "no-network-download-by-v61bc", "status": "pass", "reason": "checkpoint_payload_bytes_downloaded_by_v61bc=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain zero"},
    {"gate": "explicit-download-execution", "status": "blocked", "reason": "full checkpoint payload download remains disabled"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": "only bounded sampled hotset pages are materialized"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 full shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61bc_ubuntu1_sampled_hotset_materialization",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bc_ubuntu1_sampled_hotset_materialization_ready": 1,
    "selected_target_path": str(ubuntu1_target),
    "ubuntu1_hotset_root": str(ubuntu1_hotset_root),
    "materialize_enabled": enable_materialization,
    "hotset_page_rows": hotset_rows,
    "ubuntu1_hotset_hash_match_rows": hash_match_rows,
    "ubuntu1_hotset_readback_hash_match_rows": readback_hash_match_rows,
    "sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1": persisted_bytes,
    "checkpoint_payload_bytes_copied_to_ubuntu1_by_v61bc": copied_bytes,
    "checkpoint_payload_bytes_downloaded_by_v61bc": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "ubuntu1_sampled_hotset_materialization_ready": ubuntu1_sampled_hotset_materialization_ready,
    "full_checkpoint_materialization_ready": 0,
    "actual_model_generation_ready": 0,
}
(run_dir / "v61bc_ubuntu1_sampled_hotset_materialization_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

boundary = f"""# v61bc ubuntu-1 Sampled Hotset Materialization Boundary

This artifact materializes only the bounded 16 sampled hotset pages under the
ubuntu-1 warehouse target. It does not fetch remote checkpoint payload and does
not materialize the full Mixtral checkpoint.

Evidence emitted:

- selected_target_path={ubuntu1_target}
- ubuntu1_hotset_root={ubuntu1_hotset_root}
- hotset_page_rows={hotset_rows}
- source_local_hotset_hash_match_rows={source_hash_match_rows}
- ubuntu1_hotset_page_present_rows={present_rows}
- ubuntu1_hotset_hash_match_rows={hash_match_rows}
- ubuntu1_hotset_readback_hash_match_rows={readback_hash_match_rows}
- sampled_hotset_checkpoint_payload_bytes_persisted_on_ubuntu1={persisted_bytes}
- checkpoint_payload_bytes_copied_to_ubuntu1_by_v61bc={copied_bytes}
- checkpoint_payload_bytes_downloaded_by_v61bc=0
- checkpoint_payload_bytes_committed_to_repo=0
- full_checkpoint_materialization_ready=0
- actual_model_generation_ready=0

Allowed wording: 16 bounded sampled hotset pages are materialized and hash
verified under the ubuntu-1 target.

Blocked wording: full checkpoint materialization, explicit full checkpoint
download execution, full safetensors page-hash coverage, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BC_UBUNTU1_SAMPLED_HOTSET_MATERIALIZATION_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bc_ubuntu1_sampled_hotset_materialization_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
