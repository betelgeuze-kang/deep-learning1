#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bv_ubuntu1_remaining_checkpoint_materialization_queue"
RUN_ID="${V61BV_RUN_ID:-queue_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT="${V61BV_WAREHOUSE_ROOT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"

if [[ "${V61BV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bp_ubuntu1_payload_execution_launch_bundle.sh" >/dev/null
V61BU_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bu_ubuntu1_partial_checkpoint_materialization_witness.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT" <<'PY'
import csv
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root = Path(sys.argv[5])
results = root / "results"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)
model_id = "mistralai/Mixtral-8x22B-v0.1"
approval_phrase = "execute-ubuntu1-remaining-checkpoint-payload"


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


def write_executable(path, content):
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def stat_free_bytes(path):
    try:
        usage = shutil.disk_usage(path)
        return int(usage.free)
    except FileNotFoundError:
        return 0


v61bp_dir = results / "v61bp_ubuntu1_payload_execution_launch_bundle" / "bundle_001"
v61bu_dir = results / "v61bu_ubuntu1_partial_checkpoint_materialization_witness" / "witness_001"
v61bp_summary_path = results / "v61bp_ubuntu1_payload_execution_launch_bundle_summary.csv"
v61bu_summary_path = results / "v61bu_ubuntu1_partial_checkpoint_materialization_witness_summary.csv"
v61bp_decision_path = results / "v61bp_ubuntu1_payload_execution_launch_bundle_decision.csv"
v61bu_decision_path = results / "v61bu_ubuntu1_partial_checkpoint_materialization_witness_decision.csv"
v61bp_summary = read_csv(v61bp_summary_path)[0]
v61bu_summary = read_csv(v61bu_summary_path)[0]

if v61bp_summary.get("v61bp_ubuntu1_payload_execution_launch_bundle_ready") != "1":
    raise SystemExit("v61bv requires v61bp_ubuntu1_payload_execution_launch_bundle_ready=1")
if v61bu_summary.get("v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready") != "1":
    raise SystemExit("v61bv requires v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready=1")

for src, rel in [
    (v61bp_summary_path, "source_v61bp/v61bp_ubuntu1_payload_execution_launch_bundle_summary.csv"),
    (v61bp_decision_path, "source_v61bp/v61bp_ubuntu1_payload_execution_launch_bundle_decision.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_launch_command_rows.csv", "source_v61bp/ubuntu1_payload_execution_launch_command_rows.csv"),
    (v61bp_dir / "ubuntu1_payload_execution_chunk_launch_rows.csv", "source_v61bp/ubuntu1_payload_execution_chunk_launch_rows.csv"),
    (v61bp_dir / "operator_bundle/ubuntu1_payload_execution_readiness_rows.csv", "source_v61bp/ubuntu1_payload_execution_readiness_rows.csv"),
    (v61bp_dir / "sha256_manifest.csv", "source_v61bp/sha256_manifest.csv"),
    (v61bu_summary_path, "source_v61bu/v61bu_ubuntu1_partial_checkpoint_materialization_witness_summary.csv"),
    (v61bu_decision_path, "source_v61bu/v61bu_ubuntu1_partial_checkpoint_materialization_witness_decision.csv"),
    (v61bu_dir / "partial_checkpoint_materialization_witness_rows.csv", "source_v61bu/partial_checkpoint_materialization_witness_rows.csv"),
    (v61bu_dir / "partial_checkpoint_materialization_requirement_rows.csv", "source_v61bu/partial_checkpoint_materialization_requirement_rows.csv"),
    (v61bu_dir / "partial_checkpoint_materialization_metric_rows.csv", "source_v61bu/partial_checkpoint_materialization_metric_rows.csv"),
    (v61bu_dir / "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv", "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv"),
    (v61bu_dir / "source_v61t/local_checkpoint_materialization_rows.csv", "source_v61t/local_checkpoint_materialization_rows.csv"),
    (v61bu_dir / "sha256_manifest.csv", "source_v61bu/sha256_manifest.csv"),
]:
    copy(src, rel)

readiness_rows = read_csv(v61bp_dir / "operator_bundle/ubuntu1_payload_execution_readiness_rows.csv")
witness_rows = read_csv(v61bu_dir / "partial_checkpoint_materialization_witness_rows.csv")
live_rows = read_csv(v61bu_dir / "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv")
materialization_rows = read_csv(v61bu_dir / "source_v61t/local_checkpoint_materialization_rows.csv")
if len(readiness_rows) != 59 or len(live_rows) != 59 or len(materialization_rows) != 59:
    raise SystemExit("v61bv expects 59-row source surfaces")

live_by_shard = {row["shard_name"]: row for row in live_rows}
materialization_by_shard = {row["shard_name"]: row for row in materialization_rows}
verified_shards = {
    row["shard_name"]
    for row in materialization_rows
    if row["local_identity_verified"] == "1"
}

queue_rows = []
skipped_rows = []
for row in sorted(readiness_rows, key=lambda r: int(r["priority_rank"])):
    shard_name = row["shard_name"]
    live = live_by_shard[shard_name]
    materialized = materialization_by_shard[shard_name]
    actual_bytes = int(live["actual_bytes"])
    expected_bytes = int(row["expected_bytes"])
    remaining_bytes = max(expected_bytes - actual_bytes, 0)
    is_verified = shard_name in verified_shards
    common = {
        "model_id": model_id,
        "original_priority_rank": row["priority_rank"],
        "shard_name": shard_name,
        "priority_class": row["priority_class"],
        "target_path": row["target_path"],
        "expected_bytes": row["expected_bytes"],
        "actual_bytes_present": str(actual_bytes),
        "remaining_bytes": "0" if is_verified else str(remaining_bytes),
        "local_file_exists": live["local_file_exists"],
        "live_size_match": live["size_match"],
        "local_header_hash_match": materialized["local_header_hash_match"],
        "local_identity_verified": materialized["local_identity_verified"],
        "selected_backend_id": row["selected_backend_id"],
        "download_command_preview": row["download_command_preview"],
        "post_download_verify_command": row["post_download_verify_command"],
        "post_download_full_page_hash_command": row["post_download_full_page_hash_command"],
        "post_download_generation_admission_command": row["post_download_generation_admission_command"],
        "checkpoint_payload_bytes_downloaded_by_v61bv": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
    if is_verified:
        skipped_rows.append(
            {
                "skip_row_id": f"v61bv-skip-{int(row['priority_rank']):04d}",
                **common,
                "skip_reason": "already-identity-verified",
            }
        )
        continue
    action = "resume-download-then-verify" if actual_bytes > 0 else "download-then-verify"
    queue_rows.append(
        {
            "remaining_queue_row_id": f"v61bv-remaining-{len(queue_rows) + 1:04d}",
            "resumed_priority_rank": str(len(queue_rows) + 1),
            **common,
            "recommended_action": action,
            "payload_execution_preflight_ready": row["payload_execution_preflight_ready"],
            "dry_run_default": "1",
            "requires_execute_flag": "1",
            "requires_approval_phrase": "1",
            "approval_phrase_id": approval_phrase,
            "remaining_queue_ready": row["payload_execution_preflight_ready"],
        }
    )

if not queue_rows:
    queue_rows.append(
        {
            "remaining_queue_row_id": "v61bv-remaining-none",
            "resumed_priority_rank": "0",
            "model_id": model_id,
            "original_priority_rank": "0",
            "shard_name": "none",
            "priority_class": "none",
            "target_path": str(warehouse_root),
            "expected_bytes": "0",
            "actual_bytes_present": "0",
            "remaining_bytes": "0",
            "local_file_exists": "0",
            "live_size_match": "0",
            "local_header_hash_match": "0",
            "local_identity_verified": "0",
            "selected_backend_id": v61bp_summary["selected_backend_id"],
            "download_command_preview": "",
            "post_download_verify_command": "",
            "post_download_full_page_hash_command": "",
            "post_download_generation_admission_command": "",
            "checkpoint_payload_bytes_downloaded_by_v61bv": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "recommended_action": "none-full-materialization-already-complete",
            "payload_execution_preflight_ready": "0",
            "dry_run_default": "1",
            "requires_execute_flag": "1",
            "requires_approval_phrase": "1",
            "approval_phrase_id": approval_phrase,
            "remaining_queue_ready": "0",
        }
    )

write_csv(run_dir / "remaining_checkpoint_materialization_queue_rows.csv", list(queue_rows[0].keys()), queue_rows)
if skipped_rows:
    write_csv(run_dir / "verified_checkpoint_shard_skip_rows.csv", list(skipped_rows[0].keys()), skipped_rows)
else:
    write_csv(
        run_dir / "verified_checkpoint_shard_skip_rows.csv",
        ["skip_row_id", "model_id", "shard_name", "skip_reason", "checkpoint_payload_bytes_committed_to_repo"],
        [{"skip_row_id": "v61bv-skip-none", "model_id": model_id, "shard_name": "none", "skip_reason": "none", "checkpoint_payload_bytes_committed_to_repo": "0"}],
    )

remaining_real_rows = [row for row in queue_rows if row["shard_name"] != "none"]
priority_counts = Counter(row["priority_class"] for row in remaining_real_rows)
priority_bytes = Counter()
priority_first = defaultdict(lambda: 10**9)
priority_last = defaultdict(int)
priority_order = {}
for row in remaining_real_rows:
    priority_class = row["priority_class"]
    priority_order.setdefault(priority_class, int(row["resumed_priority_rank"]))
    priority_bytes[priority_class] += int(row["remaining_bytes"])
    priority_first[priority_class] = min(priority_first[priority_class], int(row["resumed_priority_rank"]))
    priority_last[priority_class] = max(priority_last[priority_class], int(row["resumed_priority_rank"]))

chunk_rows = []
for idx, priority_class in enumerate(sorted(priority_counts, key=lambda key: priority_order[key]), start=1):
    chunk_rows.append(
        {
            "remaining_chunk_id": f"v61bv-remaining-chunk-{idx:03d}",
            "priority_class": priority_class,
            "first_resumed_priority_rank": str(priority_first[priority_class]),
            "last_resumed_priority_rank": str(priority_last[priority_class]),
            "remaining_queue_rows": str(priority_counts[priority_class]),
            "remaining_bytes": str(priority_bytes[priority_class]),
            "dry_run_default": "1",
            "requires_execute_flag": "1",
            "requires_approval_phrase": "1",
            "checkpoint_payload_bytes_downloaded_by_v61bv": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
if not chunk_rows:
    chunk_rows = [
        {
            "remaining_chunk_id": "v61bv-remaining-chunk-none",
            "priority_class": "none",
            "first_resumed_priority_rank": "0",
            "last_resumed_priority_rank": "0",
            "remaining_queue_rows": "0",
            "remaining_bytes": "0",
            "dry_run_default": "1",
            "requires_execute_flag": "1",
            "requires_approval_phrase": "1",
            "checkpoint_payload_bytes_downloaded_by_v61bv": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    ]
write_csv(run_dir / "remaining_checkpoint_materialization_chunk_rows.csv", list(chunk_rows[0].keys()), chunk_rows)

operator_queue = operator_dir / "remaining_checkpoint_materialization_queue_rows.csv"
write_csv(operator_queue, list(queue_rows[0].keys()), queue_rows)

download_script = operator_dir / "download_remaining_checkpoint_shards.sh"
verify_script = operator_dir / "verify_remaining_checkpoint_materialization.sh"
env_template = operator_dir / "operator_env.template"
readme = operator_dir / "README.md"

download_content = f'''#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
QUEUE_CSV="${{V61BV_QUEUE_CSV:-$SCRIPT_DIR/remaining_checkpoint_materialization_queue_rows.csv}}"
MAX_ROWS="${{V61BV_MAX_ROWS:-0}}"
PRIORITY_CLASS="${{V61BV_PRIORITY_CLASS:-}}"
EXECUTE_PAYLOAD="${{V61BV_EXECUTE_PAYLOAD:-0}}"
APPROVAL_PHRASE="${{V61BV_APPROVAL_PHRASE:-}}"
EXPECTED_APPROVAL_PHRASE="{approval_phrase}"

python3 - "$QUEUE_CSV" "$MAX_ROWS" "$PRIORITY_CLASS" "$EXECUTE_PAYLOAD" "$APPROVAL_PHRASE" "$EXPECTED_APPROVAL_PHRASE" <<'PY_DOWNLOAD'
import csv
import subprocess
import sys
from pathlib import Path

queue_csv = Path(sys.argv[1])
max_rows = int(sys.argv[2])
priority_class = sys.argv[3]
execute_payload = sys.argv[4] == "1"
approval_phrase = sys.argv[5]
expected_approval_phrase = sys.argv[6]

if execute_payload and approval_phrase != expected_approval_phrase:
    raise SystemExit("blocked: V61BV_APPROVAL_PHRASE mismatch")

with queue_csv.open(newline="", encoding="utf-8") as handle:
    rows = [row for row in csv.DictReader(handle) if row["shard_name"] != "none"]

selected = []
for row in rows:
    if priority_class and row["priority_class"] != priority_class:
        continue
    selected.append(row)
    if max_rows and len(selected) >= max_rows:
        break

mode = "execute" if execute_payload else "dry-run"
print(f"v61bv mode={{mode}} selected_rows={{len(selected)}} priority_class={{priority_class or 'all'}}")
if not execute_payload:
    print("dry-run: set V61BV_EXECUTE_PAYLOAD=1 and V61BV_APPROVAL_PHRASE to execute-ubuntu1-remaining-checkpoint-payload to execute")

for row in selected:
    command = row["download_command_preview"]
    print(f"[{{mode}}] resumed_rank={{row['resumed_priority_rank']}} original_rank={{row['original_priority_rank']}} shard={{row['shard_name']}} action={{row['recommended_action']}} remaining_bytes={{row['remaining_bytes']}}")
    print(command)
    if execute_payload:
        subprocess.run(command, shell=True, executable="/bin/bash", check=True)

print(f"processed {{len(selected)}} remaining payload rows")
PY_DOWNLOAD
'''
verify_content = f'''#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${{V61BV_REPO_ROOT:-{root}}}"
WAREHOUSE_ROOT="${{V61BV_WAREHOUSE_ROOT:-{warehouse_root}}}"
cd "$REPO_ROOT"
V61T_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61T_REUSE_EXISTING=0 ./experiments/run_v61t_local_checkpoint_materialization_verifier.sh
V61BU_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BU_REUSE_EXISTING=0 ./experiments/run_v61bu_ubuntu1_partial_checkpoint_materialization_witness.sh
'''
env_content = f'''# v61bv ubuntu-1 remaining checkpoint materialization queue
export V61BV_REPO_ROOT={shlex.quote(str(root))}
export V61BV_WAREHOUSE_ROOT={shlex.quote(str(warehouse_root))}
export V61BV_QUEUE_CSV="$V61BV_REPO_ROOT/results/v61bv_ubuntu1_remaining_checkpoint_materialization_queue/queue_001/operator_bundle/remaining_checkpoint_materialization_queue_rows.csv"

# Dry-run by default. Set both variables below only for an intentional payload run.
export V61BV_EXECUTE_PAYLOAD=0
export V61BV_APPROVAL_PHRASE=
export V61BV_MAX_ROWS=0
export V61BV_PRIORITY_CLASS=

# Required phrase for payload execution:
# {approval_phrase}
'''
readme.write_text(
    "# v61bv Remaining Checkpoint Materialization Queue\n\n"
    "This operator bundle excludes already identity-verified shards and rewrites the remaining ubuntu-1 payload queue. "
    "It is dry-run first and requires an explicit execute flag plus approval phrase before any payload command runs.\n",
    encoding="utf-8",
)
write_executable(download_script, download_content)
write_executable(verify_script, verify_content)
env_template.write_text(env_content, encoding="utf-8")

script_probe_rows = []
for path in [download_script, verify_script]:
    proc = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True, check=False)
    script_probe_rows.append(
        {
            "script_path": path.relative_to(run_dir).as_posix(),
            "bash_syntax_pass": "1" if proc.returncode == 0 else "0",
            "executable_bit_set": "1" if os.access(path, os.X_OK) else "0",
            "stderr": proc.stderr.strip(),
        }
    )
write_csv(run_dir / "remaining_checkpoint_materialization_script_probe_rows.csv", list(script_probe_rows[0].keys()), script_probe_rows)

dry_proc = subprocess.run(
    ["bash", str(download_script)],
    env={**os.environ, "V61BV_EXECUTE_PAYLOAD": "0", "V61BV_MAX_ROWS": "1"},
    text=True,
    capture_output=True,
    check=False,
    timeout=60,
)
dry_run_rows = [
    {
        "dry_run_probe_id": "v61bv-dry-run-probe-001",
        "exit_code": str(dry_proc.returncode),
        "dry_run_guard_seen": "1" if "dry-run: set V61BV_EXECUTE_PAYLOAD=1" in dry_proc.stdout else "0",
        "planned_remaining_rows_processed": "1" if "processed 1 remaining payload rows" in dry_proc.stdout else "0",
        "payload_execution_blocked": "1",
        "stdout_sha256": "sha256:" + hashlib.sha256(dry_proc.stdout.encode("utf-8")).hexdigest(),
        "stderr": dry_proc.stderr.strip(),
    }
]
write_csv(run_dir / "remaining_checkpoint_materialization_dry_run_probe_rows.csv", list(dry_run_rows[0].keys()), dry_run_rows)

operator_files = []
for path in sorted(operator_dir.rglob("*")):
    if path.is_file():
        operator_files.append(
            {
                "operator_file": path.relative_to(run_dir).as_posix(),
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "checkpoint_payload_bytes_committed_to_repo": "0",
            }
        )
write_csv(run_dir / "remaining_checkpoint_materialization_operator_file_rows.csv", list(operator_files[0].keys()), operator_files)

verified_rows = len(verified_shards)
remaining_shards = len(remaining_real_rows)
skipped_verified_rows = len(skipped_rows)
remaining_bytes_total = sum(int(row["remaining_bytes"]) for row in remaining_real_rows)
identity_bytes = int(v61bu_summary["local_identity_verified_bytes"])
available_bytes = stat_free_bytes(warehouse_root)
capacity_ready = int(available_bytes >= remaining_bytes_total and remaining_shards > 0)
remaining_queue_ready = int(remaining_shards > 0 and all(row["remaining_queue_ready"] == "1" for row in remaining_real_rows))
dry_run_guard_ready = int(dry_run_rows[0]["exit_code"] == "0" and dry_run_rows[0]["dry_run_guard_seen"] == "1")
script_probe_ready = int(all(row["bash_syntax_pass"] == "1" and row["executable_bit_set"] == "1" for row in script_probe_rows))

requirement_rows = [
    {"requirement_id": "v61bp-launch-bundle-input", "status": "pass", "required_value": "1", "actual_value": v61bp_summary["v61bp_ubuntu1_payload_execution_launch_bundle_ready"], "reason": "dry-run-first launch command source is bound"},
    {"requirement_id": "v61bu-partial-witness-input", "status": "pass", "required_value": "1", "actual_value": v61bu_summary["v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready"], "reason": "current partial materialization witness is bound"},
    {"requirement_id": "skip-verified-shards", "status": "pass" if skipped_verified_rows == verified_rows else "blocked", "required_value": str(verified_rows), "actual_value": str(skipped_verified_rows), "reason": "already identity-verified shards are excluded from the remaining queue"},
    {"requirement_id": "remaining-materialization-queue", "status": "pass" if remaining_queue_ready else "blocked", "required_value": str(59 - verified_rows), "actual_value": str(remaining_shards), "reason": "remaining shard rows keep resumable curl and post-download verification commands"},
    {"requirement_id": "current-free-space-for-remaining-bytes", "status": "pass" if capacity_ready else "blocked", "required_value": str(remaining_bytes_total), "actual_value": str(available_bytes), "reason": "current ubuntu-1 free bytes are compared against remaining unverified bytes"},
    {"requirement_id": "operator-script-syntax", "status": "pass" if script_probe_ready else "blocked", "required_value": "2", "actual_value": str(sum(1 for row in script_probe_rows if row["bash_syntax_pass"] == "1")), "reason": "remaining queue operator scripts pass bash syntax and executable checks"},
    {"requirement_id": "download-dry-run-guard", "status": "pass" if dry_run_guard_ready else "blocked", "required_value": "1", "actual_value": str(dry_run_guard_ready), "reason": "download script defaults to dry-run and processes one planned row without payload execution"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61bv writes metadata/operator scripts only"},
    {"requirement_id": "explicit-payload-execution", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "payload execution still requires explicit operator approval"},
    {"requirement_id": "receipt-backed-full-materialization", "status": "blocked", "required_value": "59", "actual_value": str(verified_rows), "reason": "full materialization waits for all shards plus returned receipts"},
    {"requirement_id": "full-safetensors-page-hash-binding", "status": "blocked", "required_value": "134161", "actual_value": "0", "reason": "full page-hash execution is not performed by v61bv"},
    {"requirement_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "v61bv is a remaining materialization queue, not a generation runner"},
]
write_csv(run_dir / "remaining_checkpoint_materialization_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bv_remaining_checkpoint_materialization_queue_metrics",
    "model_id": model_id,
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": v61bp_summary["v61bp_ubuntu1_payload_execution_launch_bundle_ready"],
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": v61bu_summary["v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready"],
    "target_root_path": str(warehouse_root),
    "checkpoint_shard_rows": "59",
    "verified_identity_shard_rows": str(verified_rows),
    "skipped_verified_shard_rows": str(skipped_verified_rows),
    "remaining_queue_rows": str(remaining_shards),
    "remaining_chunk_rows": str(len([row for row in chunk_rows if row["priority_class"] != "none"])),
    "remaining_unverified_bytes": str(remaining_bytes_total),
    "local_identity_verified_bytes": str(identity_bytes),
    "ubuntu1_available_bytes_live": str(available_bytes),
    "remaining_bytes_fit_current_free_space": str(capacity_ready),
    "remaining_queue_ready": str(remaining_queue_ready),
    "script_probe_rows": str(len(script_probe_rows)),
    "script_bash_syntax_pass_rows": str(sum(1 for row in script_probe_rows if row["bash_syntax_pass"] == "1")),
    "operator_bundle_file_rows": str(len(operator_files)),
    "dry_run_guard_ready": str(dry_run_guard_ready),
    "payload_execution_launch_ready": "0",
    "download_execution_ready": "0",
    "full_checkpoint_materialization_ready": v61bu_summary["full_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61bu_summary["full_safetensors_page_hash_binding_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for priority_class in sorted(priority_counts):
    metric[f"{priority_class}_remaining_rows"] = str(priority_counts[priority_class])
    metric[f"{priority_class}_remaining_bytes"] = str(priority_bytes[priority_class])
write_csv(run_dir / "remaining_checkpoint_materialization_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("remaining-materialization-queue", "ready" if remaining_queue_ready else "blocked", f"remaining_queue_rows={remaining_shards}"),
    ("current-free-space-for-remaining-bytes", "ready" if capacity_ready else "blocked", f"available={available_bytes}; remaining={remaining_bytes_total}"),
    ("explicit-payload-execution", "blocked", "approval phrase and execute flag are not supplied"),
    ("receipt-backed-full-materialization", "blocked", f"verified_identity_shard_rows={verified_rows}/59"),
    ("full-safetensors-page-hash-binding", "blocked", "not executed by v61bv"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["requirement_id"], "status": row["status"], "reason": row["reason"]}
    for row in requirement_rows
]
for extra_gate in ["production-latency", "real-release-package"]:
    decision_rows.append({"gate": extra_gate, "status": "blocked", "reason": "not claimed by v61bv"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bv Ubuntu-1 Remaining Checkpoint Materialization Queue Boundary

This gate consumes the v61bp dry-run-first launch bundle and the v61bu partial
materialization witness, excludes already identity-verified shards, and emits a
remaining-only resumable queue for the ubuntu-1 checkpoint payload. It does not
download checkpoint payload bytes and does not commit checkpoint payload bytes
to the repository.

Evidence emitted:

- verified_identity_shard_rows={verified_rows}
- skipped_verified_shard_rows={skipped_verified_rows}
- remaining_queue_rows={remaining_shards}
- remaining_unverified_bytes={remaining_bytes_total}
- local_identity_verified_bytes={identity_bytes}
- ubuntu1_available_bytes_live={available_bytes}
- remaining_bytes_fit_current_free_space={capacity_ready}
- remaining_queue_ready={remaining_queue_ready}
- dry_run_guard_ready={dry_run_guard_ready}
- payload_execution_launch_ready=0
- download_execution_ready=0
- full_checkpoint_materialization_ready={metric['full_checkpoint_materialization_ready']}
- full_safetensors_page_hash_binding_ready={metric['full_safetensors_page_hash_binding_ready']}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bv=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: remaining ubuntu-1 checkpoint materialization queue after
partial shard witness.
Blocked wording: completed full checkpoint materialization, full page-hash
coverage, actual model generation, production latency, near-frontier quality,
or release readiness.
"""
(run_dir / "V61BV_UBUNTU1_REMAINING_CHECKPOINT_MATERIALIZATION_QUEUE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bv_ubuntu1_remaining_checkpoint_materialization_queue",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": 1,
    "source_v61bp_summary_sha256": sha256(v61bp_summary_path),
    "source_v61bu_summary_sha256": sha256(v61bu_summary_path),
    "verified_identity_shard_rows": verified_rows,
    "remaining_queue_rows": remaining_shards,
    "remaining_unverified_bytes": remaining_bytes_total,
    "remaining_bytes_fit_current_free_space": capacity_ready,
    "checkpoint_payload_bytes_downloaded_by_v61bv": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
