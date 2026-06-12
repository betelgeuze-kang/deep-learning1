#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61aq_moe_remote_hash_execution_gate"
RUN_ID="${V61AQ_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61aq_moe_remote_hash_execution_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR/operator_bundle"

V61AP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ap_moe_coverage_remote_hash_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import shlex
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
import os

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

model_id = "mistralai/Mixtral-8x22B-v0.1"
chunk_rows_limit = int(os.environ.get("V61AQ_REMOTE_HASH_CHUNK_ROWS", "64"))
if chunk_rows_limit <= 0:
    raise SystemExit("V61AQ_REMOTE_HASH_CHUNK_ROWS must be positive")

v61ap_dir = results / "v61ap_moe_coverage_remote_hash_plan" / "plan_001"


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


v61ap_summary = read_csv(results / "v61ap_moe_coverage_remote_hash_plan_summary.csv")[0]
if v61ap_summary.get("v61ap_moe_coverage_remote_hash_plan_ready") != "1":
    raise SystemExit("v61aq requires v61ap_moe_coverage_remote_hash_plan_ready=1")

for src, rel in [
    (results / "v61ap_moe_coverage_remote_hash_plan_summary.csv", "source_v61ap/v61ap_moe_coverage_remote_hash_plan_summary.csv"),
    (results / "v61ap_moe_coverage_remote_hash_plan_decision.csv", "source_v61ap/v61ap_moe_coverage_remote_hash_plan_decision.csv"),
    (v61ap_dir / "moe_coverage_remote_hash_plan_rows.csv", "source_v61ap/moe_coverage_remote_hash_plan_rows.csv"),
    (v61ap_dir / "moe_coverage_existing_remote_hash_rows.csv", "source_v61ap/moe_coverage_existing_remote_hash_rows.csv"),
    (v61ap_dir / "moe_coverage_remote_hash_role_rows.csv", "source_v61ap/moe_coverage_remote_hash_role_rows.csv"),
    (v61ap_dir / "moe_coverage_remote_hash_shard_rows.csv", "source_v61ap/moe_coverage_remote_hash_shard_rows.csv"),
    (v61ap_dir / "moe_coverage_remote_hash_requirement_rows.csv", "source_v61ap/moe_coverage_remote_hash_requirement_rows.csv"),
    (v61ap_dir / "moe_coverage_remote_hash_metric_rows.csv", "source_v61ap/moe_coverage_remote_hash_metric_rows.csv"),
    (v61ap_dir / "v61ap_moe_coverage_remote_hash_plan_manifest.json", "source_v61ap/v61ap_moe_coverage_remote_hash_plan_manifest.json"),
    (v61ap_dir / "sha256_manifest.csv", "source_v61ap/sha256_manifest.csv"),
]:
    copy(src, rel)

plan_rows = read_csv(v61ap_dir / "moe_coverage_remote_hash_plan_rows.csv")
existing_rows = [row for row in plan_rows if row["plan_status"] == "already-remote-hash-bound"]
planned_rows = [row for row in plan_rows if row["plan_status"] == "planned-remote-range-hash"]
if len(plan_rows) != int(v61ap_summary["remote_hash_plan_rows"]):
    raise SystemExit("v61aq plan row count differs from v61ap summary")
if len(existing_rows) != int(v61ap_summary["already_remote_hash_bound_rows"]):
    raise SystemExit("v61aq existing row count differs from v61ap summary")
if len(planned_rows) != int(v61ap_summary["planned_remote_hash_rows"]):
    raise SystemExit("v61aq planned row count differs from v61ap summary")

command_rows = []
for index, row in enumerate(planned_rows):
    start = int(row["page_start_byte"])
    end = int(row["page_end_byte_exclusive"]) - 1
    url = row["source_url"]
    command = (
        "curl -L --fail --retry 3 --retry-delay 2 "
        f"-r {start}-{end} {shlex.quote(url)} | sha256sum"
    )
    command_rows.append(
        {
            "remote_hash_command_id": f"v61aq_remote_hash_command_{index:04d}",
            "remote_hash_plan_id": row["remote_hash_plan_id"],
            "model_id": model_id,
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "tensor_role": row["tensor_role"],
            "source_page_id": row["source_page_id"],
            "shard_name": row["shard_name"],
            "page_start_byte": row["page_start_byte"],
            "page_end_byte_exclusive": row["page_end_byte_exclusive"],
            "planned_range_bytes": row["planned_range_bytes"],
            "source_url": url,
            "curl_range_header": f"bytes={start}-{end}",
            "sha256_command": command,
            "execution_status": "blocked-execution-disabled",
            "remote_hash_execution_enabled": "0",
            "checkpoint_payload_bytes_downloaded_by_v61aq": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "moe_remote_hash_execution_command_rows.csv", list(command_rows[0].keys()), command_rows)

existing_hash_rows = []
for index, row in enumerate(existing_rows):
    existing_hash_rows.append(
        {
            "existing_hash_id": f"v61aq_existing_remote_hash_{index:04d}",
            "remote_hash_plan_id": row["remote_hash_plan_id"],
            "model_id": model_id,
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "tensor_role": row["tensor_role"],
            "source_page_id": row["source_page_id"],
            "shard_name": row["shard_name"],
            "remote_sample_id": row["remote_sample_id"],
            "remote_page_sha256": row["remote_page_sha256"],
            "existing_remote_hash_preserved": "1",
            "checkpoint_payload_bytes_downloaded_by_v61aq": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "moe_remote_hash_existing_hash_rows.csv", list(existing_hash_rows[0].keys()), existing_hash_rows)

chunk_rows = []
chunk_count = math.ceil(len(plan_rows) / chunk_rows_limit)
for chunk_index in range(chunk_count):
    start_index = chunk_index * chunk_rows_limit
    end_index = min(start_index + chunk_rows_limit, len(plan_rows))
    rows = plan_rows[start_index:end_index]
    existing_count = sum(1 for row in rows if row["plan_status"] == "already-remote-hash-bound")
    planned_count = len(rows) - existing_count
    chunk_status = "blocked-execution-disabled" if planned_count else "already-remote-hash-bound"
    chunk_rows.append(
        {
            "execution_chunk_id": f"v61aq_moe_remote_hash_chunk_{chunk_index:04d}",
            "chunk_index": str(chunk_index),
            "chunk_row_start_index": str(start_index),
            "chunk_row_end_index_exclusive": str(end_index),
            "planned_plan_rows": str(len(rows)),
            "already_remote_hash_bound_rows": str(existing_count),
            "planned_remote_hash_rows": str(planned_count),
            "planned_remote_hash_bytes": str(sum(int(row["planned_range_bytes"]) for row in rows if row["plan_status"] == "planned-remote-range-hash")),
            "first_remote_hash_plan_id": rows[0]["remote_hash_plan_id"],
            "last_remote_hash_plan_id": rows[-1]["remote_hash_plan_id"],
            "remote_hash_execution_enabled": "0",
            "execution_chunk_status": chunk_status,
            "remote_hash_verified_rows": str(existing_count),
            "checkpoint_payload_bytes_downloaded_by_v61aq": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "moe_remote_hash_execution_chunk_rows.csv", list(chunk_rows[0].keys()), chunk_rows)

role_counts = Counter(row["tensor_role"] for row in plan_rows)
role_existing = Counter(row["tensor_role"] for row in existing_rows)
role_planned = Counter(row["tensor_role"] for row in planned_rows)
role_execution_rows = []
for role in ["moe_w1", "moe_w2", "moe_w3"]:
    role_execution_rows.append(
        {
            "tensor_role": role,
            "remote_hash_plan_rows": str(role_counts[role]),
            "already_remote_hash_bound_rows": str(role_existing[role]),
            "planned_remote_hash_command_rows": str(role_planned[role]),
            "remote_hash_verified_rows": str(role_existing[role]),
            "full_role_remote_hash_ready": "0",
        }
    )
write_csv(run_dir / "moe_remote_hash_execution_role_rows.csv", list(role_execution_rows[0].keys()), role_execution_rows)

operator_script = run_dir / "operator_bundle" / "run_moe_remote_hash_commands.sh"
operator_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

if [[ "${V61AQ_EXECUTE_REMOTE_HASH:-0}" != "1" ]]; then
  echo "dry-run: set V61AQ_EXECUTE_REMOTE_HASH=1 to execute planned remote range hashes" >&2
  exit 0
fi

echo "v61aq remote hash execution is intentionally not implemented in this bundle." >&2
echo "Use moe_remote_hash_execution_command_rows.csv as the reviewed command plan." >&2
exit 2
""",
    encoding="utf-8",
)
operator_script.chmod(0o755)

total_rows = len(plan_rows)
already_rows = len(existing_rows)
command_row_count = len(command_rows)
execution_chunk_rows = len(chunk_rows)
blocked_chunk_rows = sum(1 for row in chunk_rows if row["execution_chunk_status"] == "blocked-execution-disabled")
already_complete_chunk_rows = execution_chunk_rows - blocked_chunk_rows
planned_remote_hash_bytes = sum(int(row["planned_range_bytes"]) for row in planned_rows)
full_moe_coverage_remote_hash_ready = int(already_rows == total_rows)
remote_hash_execution_ready = 0

requirement_rows = [
    {
        "requirement_id": "v61ap-remote-hash-plan-input",
        "status": "pass",
        "required_rows": v61ap_summary["remote_hash_plan_rows"],
        "actual_rows": str(total_rows),
        "reason": "v61ap representative MoE remote hash plan is bound",
    },
    {
        "requirement_id": "remote-hash-command-plan",
        "status": "pass",
        "required_rows": v61ap_summary["planned_remote_hash_rows"],
        "actual_rows": str(command_row_count),
        "reason": "each not-yet-hashed representative cell has one guarded curl-range command row",
    },
    {
        "requirement_id": "existing-remote-hash-preservation",
        "status": "pass",
        "required_rows": v61ap_summary["already_remote_hash_bound_rows"],
        "actual_rows": str(already_rows),
        "reason": "existing v61v MoE remote hashes are preserved as verified rows",
    },
    {
        "requirement_id": "remote-hash-execution",
        "status": "blocked",
        "required_rows": str(command_row_count),
        "actual_rows": "0",
        "reason": "v61aq does not execute network range hashes by default",
    },
    {
        "requirement_id": "full-moe-coverage-remote-hash",
        "status": "blocked",
        "required_rows": str(total_rows),
        "actual_rows": str(already_rows),
        "reason": "all representative MoE cells must have remote hashes before this passes",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_rows": "0",
        "actual_rows": "0",
        "reason": "v61aq emits command and hash metadata only",
    },
]
write_csv(run_dir / "moe_remote_hash_execution_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61aq_moe_remote_hash_execution_gate_metrics",
    "model_id": model_id,
    "v61ap_moe_coverage_remote_hash_plan_ready": v61ap_summary["v61ap_moe_coverage_remote_hash_plan_ready"],
    "remote_hash_plan_rows": str(total_rows),
    "already_remote_hash_bound_rows": str(already_rows),
    "planned_remote_hash_command_rows": str(command_row_count),
    "remote_hash_execution_chunk_size_rows": str(chunk_rows_limit),
    "remote_hash_execution_chunk_rows": str(execution_chunk_rows),
    "blocked_execution_chunk_rows": str(blocked_chunk_rows),
    "already_complete_chunk_rows": str(already_complete_chunk_rows),
    "remote_hash_verified_rows": str(already_rows),
    "planned_remote_hash_bytes": str(planned_remote_hash_bytes),
    "full_moe_coverage_remote_hash_ready": str(full_moe_coverage_remote_hash_ready),
    "remote_hash_execution_ready": str(remote_hash_execution_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61aq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "moe_remote_hash_execution_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61ap-plan-input", "ready", "1344-row MoE representative remote hash plan is bound"),
    ("remote-hash-command-plan", "ready", f"{command_row_count} guarded command rows are emitted"),
    ("existing-remote-hash-preservation", "ready", f"{already_rows} existing remote hashes are preserved"),
    ("remote-hash-execution", "blocked", "network range hashing is not executed by default"),
    ("full-moe-coverage-remote-hash", "blocked", f"{already_rows}/{total_rows} representative cells are remotely hash-bound"),
    ("full-safetensors-page-hash-binding", "blocked", "MoE representative coverage is not all 134161 checkpoint pages"),
    ("real-model-generation", "blocked", "real Mixtral generation waits for materialization and page-hash gates"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61aq_moe_remote_hash_execution_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ap-remote-hash-plan-input", "status": "pass", "reason": "v61ap hash plan is bound"},
    {"gate": "remote-hash-command-plan", "status": "pass", "reason": f"planned_remote_hash_command_rows={command_row_count}"},
    {"gate": "existing-remote-hash-preservation", "status": "pass", "reason": f"existing_hash_rows={already_rows}"},
    {"gate": "execution-chunk-schedule", "status": "pass", "reason": f"remote_hash_execution_chunk_rows={execution_chunk_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "command metadata only"},
    {"gate": "remote-hash-execution", "status": "blocked", "reason": "no network range hashing is executed by v61aq"},
    {"gate": "full-moe-coverage-remote-hash", "status": "blocked", "reason": f"remote_hash_verified_rows={already_rows}/{total_rows}"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "requires all checkpoint pages"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real generation is still gated"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61aq MoE Remote Hash Execution Gate Boundary

This artifact converts the v61ap MoE representative remote hash plan into
reviewable curl-range command rows and resumable execution chunks. It preserves
existing v61v hashes and does not execute new network range hashing by default.

Evidence emitted:

- remote_hash_plan_rows={total_rows}
- already_remote_hash_bound_rows={already_rows}
- planned_remote_hash_command_rows={command_row_count}
- remote_hash_execution_chunk_size_rows={chunk_rows_limit}
- remote_hash_execution_chunk_rows={execution_chunk_rows}
- blocked_execution_chunk_rows={blocked_chunk_rows}
- remote_hash_verified_rows={already_rows}
- planned_remote_hash_bytes={planned_remote_hash_bytes}
- full_moe_coverage_remote_hash_ready={full_moe_coverage_remote_hash_ready}
- remote_hash_execution_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61aq=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: guarded remote hash command plan and execution gate for
representative MoE coverage.
Blocked wording: executed remote hash expansion, full MoE remote hash coverage,
full safetensors page-hash coverage, local materialization, real Mixtral
generation, production latency, or release readiness.
"""
(run_dir / "V61AQ_MOE_REMOTE_HASH_EXECUTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61aq_moe_remote_hash_execution_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61aq_moe_remote_hash_execution_gate_ready": 1,
    "v61ap_summary_sha256": sha256(results / "v61ap_moe_coverage_remote_hash_plan_summary.csv"),
    "remote_hash_plan_rows": total_rows,
    "already_remote_hash_bound_rows": already_rows,
    "planned_remote_hash_command_rows": command_row_count,
    "remote_hash_execution_chunk_rows": execution_chunk_rows,
    "remote_hash_verified_rows": already_rows,
    "planned_remote_hash_bytes": planned_remote_hash_bytes,
    "full_moe_coverage_remote_hash_ready": full_moe_coverage_remote_hash_ready,
    "remote_hash_execution_ready": remote_hash_execution_ready,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61aq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61aq_moe_remote_hash_execution_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61aq_moe_remote_hash_execution_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
