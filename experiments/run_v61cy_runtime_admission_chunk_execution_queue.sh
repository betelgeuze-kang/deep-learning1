#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cy_runtime_admission_chunk_execution_queue"
RUN_ID="${V61CY_RUN_ID:-queue_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cy_runtime_admission_chunk_execution_queue_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cq_complete_source_runtime_admission_expansion_packet.sh" >/dev/null
V61CV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cv_complete_source_runtime_admission_operator_bundle.sh" >/dev/null
V61CW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
V61CX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cx_post_full_shard_actual_generation_closure_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "${V61CY_RUNTIME_ADMISSION_CHUNK_SIZE:-50}" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
chunk_size = int(sys.argv[5])
if chunk_size <= 0:
    raise SystemExit("V61CY_RUNTIME_ADMISSION_CHUNK_SIZE must be positive")

results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61cq": (
        results / "v61cq_complete_source_runtime_admission_expansion_packet_summary.csv",
        results / "v61cq_complete_source_runtime_admission_expansion_packet_decision.csv",
        results / "v61cq_complete_source_runtime_admission_expansion_packet" / "packet_001",
        "v61cq_complete_source_runtime_admission_expansion_packet_ready",
    ),
    "v61cv": (
        results / "v61cv_complete_source_runtime_admission_operator_bundle_summary.csv",
        results / "v61cv_complete_source_runtime_admission_operator_bundle_decision.csv",
        results / "v61cv_complete_source_runtime_admission_operator_bundle" / "bundle_001",
        "v61cv_complete_source_runtime_admission_operator_bundle_ready",
    ),
    "v61cw": (
        results / "v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv",
        results / "v61cw_complete_source_runtime_admission_acceptance_bridge_decision.csv",
        results / "v61cw_complete_source_runtime_admission_acceptance_bridge" / "bridge_001",
        "v61cw_complete_source_runtime_admission_acceptance_bridge_ready",
    ),
    "v61cx": (
        results / "v61cx_post_full_shard_actual_generation_closure_queue_summary.csv",
        results / "v61cx_post_full_shard_actual_generation_closure_queue_decision.csv",
        results / "v61cx_post_full_shard_actual_generation_closure_queue" / "queue_001",
        "v61cx_post_full_shard_actual_generation_closure_queue_ready",
    ),
}

summaries = {}
for key, (summary_path, decision_path, source_dir, ready_field) in sources.items():
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v61cy requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

copy(sources["v61cq"][2] / "complete_source_runtime_admission_expansion_rows.csv", "source_v61cq/complete_source_runtime_admission_expansion_rows.csv")
copy(sources["v61cq"][2] / "complete_source_runtime_admission_return_manifest_rows.csv", "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv")
copy(sources["v61cv"][2] / "complete_source_runtime_admission_operator_command_rows.csv", "source_v61cv/complete_source_runtime_admission_operator_command_rows.csv")
copy(sources["v61cv"][2] / "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv", "source_v61cv/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv")
copy(sources["v61cw"][2] / "complete_source_runtime_admission_acceptance_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv")
copy(sources["v61cx"][2] / "post_full_shard_generation_closure_queue_rows.csv", "source_v61cx/post_full_shard_generation_closure_queue_rows.csv")
copy(sources["v61cx"][2] / "post_full_shard_generation_next_action_rows.csv", "source_v61cx/post_full_shard_generation_next_action_rows.csv")

v61cq = summaries["v61cq"]
v61cv = summaries["v61cv"]
v61cw = summaries["v61cw"]
v61cx = summaries["v61cx"]

expansion_rows = read_csv(sources["v61cq"][2] / "complete_source_runtime_admission_expansion_rows.csv")
return_template_rows = read_csv(sources["v61cv"][2] / "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv")
if len(expansion_rows) != 1000:
    raise SystemExit("v61cy expects 1000 runtime admission expansion rows")
if len(return_template_rows) != 5:
    raise SystemExit("v61cy expects five runtime admission aggregate return artifacts")

full_shard_closed = as_int(v61cx, "full_shard_prerequisites_closed")
guard_ready = as_int(v61cv, "guarded_runtime_admission_command_ready")
runtime_acceptance_ready = as_int(v61cw, "complete_source_runtime_admission_execution_ready")
chunk_dispatch_ready = int(full_shard_closed and guard_ready)

chunk_rows = []
manifest_rows = []
for chunk_index, start in enumerate(range(0, len(expansion_rows), chunk_size)):
    chunk = expansion_rows[start : start + chunk_size]
    end = start + len(chunk)
    chunk_id = f"v61cy-runtime-admission-chunk-{chunk_index:03d}"
    chunk_ready = chunk_dispatch_ready
    chunk_rows.append(
        {
            "runtime_admission_chunk_id": chunk_id,
            "chunk_index": str(chunk_index),
            "row_start_index": str(start),
            "row_end_index_exclusive": str(end),
            "query_rows": str(len(chunk)),
            "first_expansion_row_id": chunk[0]["expansion_row_id"],
            "last_expansion_row_id": chunk[-1]["expansion_row_id"],
            "first_query_id": chunk[0]["query_id"],
            "last_query_id": chunk[-1]["query_id"],
            "model_id": model_id,
            "checkpoint_root": chunk[0]["checkpoint_root"],
            "chunk_dispatch_ready": str(chunk_ready),
            "chunk_execution_completed": "0",
            "chunk_return_accepted": "0",
            "blocking_reason": "chunk return artifacts missing",
            "checkpoint_payload_bytes_downloaded_by_v61cy": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
    for row_offset, row in enumerate(chunk):
        manifest_rows.append(
            {
                "runtime_admission_chunk_id": chunk_id,
                "chunk_index": str(chunk_index),
                "chunk_row_index": str(row_offset),
                "global_row_index": str(start + row_offset),
                "expansion_row_id": row["expansion_row_id"],
                "query_id": row["query_id"],
                "review_query_packet_id": row["review_query_packet_id"],
                "generation_execution_packet_id": row["generation_execution_packet_id"],
                "owner_repo": row["owner_repo"],
                "audit_type": row["audit_type"],
                "expected_behavior": row["expected_behavior"],
                "source_span_id": row["source_span_id"],
                "source_path": row["source_path"],
                "model_id": row["model_id"],
                "checkpoint_root": row["checkpoint_root"],
            }
        )

write_csv(run_dir / "runtime_admission_execution_chunk_rows.csv", list(chunk_rows[0].keys()), chunk_rows)
write_csv(run_dir / "runtime_admission_chunk_manifest_rows.csv", list(manifest_rows[0].keys()), manifest_rows)

query_artifacts = [
    ("complete-source-runtime-admission-result-rows", "complete_source_runtime_admission_result_rows.csv"),
    ("complete-source-runtime-page-binding-rows", "complete_source_runtime_page_binding_rows.csv"),
    ("complete-source-runtime-budget-rows", "complete_source_runtime_budget_rows.csv"),
    ("complete-source-runtime-abstain-fallback-rows", "complete_source_runtime_abstain_fallback_rows.csv"),
]
chunk_artifact_rows = []
for chunk in chunk_rows:
    for artifact_id, filename in query_artifacts:
        chunk_artifact_rows.append(
            {
                "chunk_artifact_id": f"{chunk['runtime_admission_chunk_id']}::{artifact_id}",
                "runtime_admission_chunk_id": chunk["runtime_admission_chunk_id"],
                "result_artifact": artifact_id,
                "chunk_return_path": f"chunks/{chunk['runtime_admission_chunk_id']}/{filename}",
                "required_rows": chunk["query_rows"],
                "current_status": "missing",
                "accepted_rows": "0",
                "artifact_scope": "per-query-chunk",
            }
        )

chunk_artifact_rows.append(
    {
        "chunk_artifact_id": "v61cy-runtime-admission-global-identity::complete-source-runtime-identity-rows",
        "runtime_admission_chunk_id": "global",
        "result_artifact": "complete-source-runtime-identity-rows",
        "chunk_return_path": "chunks/global/complete_source_runtime_identity_rows.csv",
        "required_rows": "59",
        "current_status": "missing",
        "accepted_rows": "0",
        "artifact_scope": "global-once",
    }
)
write_csv(run_dir / "runtime_admission_chunk_return_artifact_rows.csv", list(chunk_artifact_rows[0].keys()), chunk_artifact_rows)

aggregate_rows = []
for row in return_template_rows:
    aggregate_rows.append(
        {
            "result_artifact": row["result_artifact"],
            "aggregate_return_path": row["path"],
            "required_rows": row["required_rows"],
            "current_status": "missing",
            "accepted_rows": "0",
            "source_chunk_artifacts_required": "1" if row["result_artifact"] == "complete-source-runtime-identity-rows" else str(len(chunk_rows)),
            "merge_ready": "0",
            "operator_note": "merge chunk returns before v61cr intake",
        }
    )
write_csv(run_dir / "runtime_admission_aggregate_return_artifact_rows.csv", list(aggregate_rows[0].keys()), aggregate_rows)
write_csv(operator_dir / "RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv", list(aggregate_rows[0].keys()), aggregate_rows)

command_rows = [
    {
        "command_id": "verify-runtime-admission-prerequisites",
        "command": "results/v61cv_complete_source_runtime_admission_operator_bundle/bundle_001/operator_bundle/RUN_RUNTIME_ADMISSION_GUARD.sh",
        "purpose": "verify full-shard/page-hash/runtime seed prerequisites",
        "ready_to_run_now": str(chunk_dispatch_ready),
    },
    {
        "command_id": "dispatch-runtime-admission-chunks",
        "command": "DRY_RUN=0 V61CY_CHUNK_QUEUE=results/v61cy_runtime_admission_chunk_execution_queue/queue_001/runtime_admission_execution_chunk_rows.csv ./operator/run_runtime_admission_chunks.sh",
        "purpose": "execute complete-source runtime admission in 20 chunks",
        "ready_to_run_now": str(chunk_dispatch_ready),
    },
    {
        "command_id": "merge-runtime-admission-chunk-returns",
        "command": "results/v61cy_runtime_admission_chunk_execution_queue/queue_001/operator_bundle/MERGE_RUNTIME_ADMISSION_CHUNKS.sh /path/to/runtime_admission_chunk_returns /path/to/runtime_admission_return",
        "purpose": "merge chunk returns into the five v61cr aggregate artifacts",
        "ready_to_run_now": "0",
    },
    {
        "command_id": "intake-runtime-admission-aggregate-return",
        "command": "V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return V61CR_REUSE_EXISTING=0 ./experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh && V61CW_REUSE_EXISTING=0 ./experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh",
        "purpose": "validate aggregate return and refresh per-query runtime acceptance",
        "ready_to_run_now": "0",
    },
]
write_csv(run_dir / "runtime_admission_chunk_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

(operator_dir / "README.md").write_text(
    "# v61cy Runtime Admission Chunk Execution Queue\n\n"
    "This queue splits the 1000-row complete-source runtime admission expansion "
    "packet into bounded execution chunks. It does not execute the model, merge "
    "returns, or claim runtime admission acceptance.\n",
    encoding="utf-8",
)
(operator_dir / "RUNTIME_ADMISSION_CHUNK_ENV.template").write_text(
    "V61CY_CHUNK_QUEUE=results/v61cy_runtime_admission_chunk_execution_queue/queue_001/runtime_admission_execution_chunk_rows.csv\n"
    "V61CY_CHUNK_MANIFEST=results/v61cy_runtime_admission_chunk_execution_queue/queue_001/runtime_admission_chunk_manifest_rows.csv\n"
    "V61CY_CHUNK_RETURN_DIR=/path/to/runtime_admission_chunk_returns\n"
    "V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return\n"
    "DRY_RUN=1\n",
    encoding="utf-8",
)
verify_script = operator_dir / "VERIFY_RUNTIME_ADMISSION_CHUNK_QUEUE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

QUEUE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  "$QUEUE_DIR/runtime_admission_execution_chunk_rows.csv"
  "$QUEUE_DIR/runtime_admission_chunk_manifest_rows.csv"
  "$QUEUE_DIR/runtime_admission_chunk_return_artifact_rows.csv"
  "$QUEUE_DIR/runtime_admission_aggregate_return_artifact_rows.csv"
  "$QUEUE_DIR/operator_bundle/RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v61cy chunk queue file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$QUEUE_DIR/runtime_admission_execution_chunk_rows.csv" | tr -d ' ')" == "21" ]] || { echo "expected 20 runtime chunks" >&2; exit 1; }
[[ "$(wc -l < "$QUEUE_DIR/runtime_admission_chunk_manifest_rows.csv" | tr -d ' ')" == "1001" ]] || { echo "expected 1000 chunk manifest rows" >&2; exit 1; }
[[ "$(wc -l < "$QUEUE_DIR/runtime_admission_chunk_return_artifact_rows.csv" | tr -d ' ')" == "82" ]] || { echo "expected 81 chunk artifact rows" >&2; exit 1; }
[[ "$(wc -l < "$QUEUE_DIR/runtime_admission_aggregate_return_artifact_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected 5 aggregate return rows" >&2; exit 1; }

if find "$QUEUE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "checkpoint payload-like file found inside v61cy queue" >&2
  exit 1
fi

echo "v61cy runtime admission chunk queue shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

merge_script = operator_dir / "MERGE_RUNTIME_ADMISSION_CHUNKS.sh"
merge_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <chunk_return_dir> <aggregate_return_dir>" >&2
  exit 2
fi

CHUNK_RETURN_DIR="$1"
AGGREGATE_RETURN_DIR="$2"
QUEUE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "$CHUNK_RETURN_DIR" ]]; then
  echo "chunk return directory does not exist: $CHUNK_RETURN_DIR" >&2
  exit 1
fi

mkdir -p "$AGGREGATE_RETURN_DIR"
echo "merge template only: validate chunk artifacts from $CHUNK_RETURN_DIR before writing aggregate files into $AGGREGATE_RETURN_DIR"
echo "required aggregate template: $QUEUE_DIR/operator_bundle/RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv"
exit 1
""",
    encoding="utf-8",
)
merge_script.chmod(0o755)

ready_chunk_dispatch_rows = sum(1 for row in chunk_rows if row["chunk_dispatch_ready"] == "1")
completed_chunk_rows = sum(1 for row in chunk_rows if row["chunk_execution_completed"] == "1")
accepted_chunk_return_rows = sum(1 for row in chunk_rows if row["chunk_return_accepted"] == "1")
ready_operator_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

metric = {
    "metric_id": "v61cy_runtime_admission_chunk_execution_queue_metrics",
    "model_id": model_id,
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": v61cq["v61cq_complete_source_runtime_admission_expansion_packet_ready"],
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": v61cv["v61cv_complete_source_runtime_admission_operator_bundle_ready"],
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": v61cw["v61cw_complete_source_runtime_admission_acceptance_bridge_ready"],
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": v61cx["v61cx_post_full_shard_actual_generation_closure_queue_ready"],
    "runtime_admission_expansion_rows": str(len(expansion_rows)),
    "runtime_admission_chunk_size": str(chunk_size),
    "runtime_admission_chunk_rows": str(len(chunk_rows)),
    "runtime_admission_chunk_manifest_rows": str(len(manifest_rows)),
    "runtime_admission_chunk_return_artifact_rows": str(len(chunk_artifact_rows)),
    "runtime_admission_aggregate_return_artifact_rows": str(len(aggregate_rows)),
    "runtime_admission_chunk_operator_command_rows": str(len(command_rows)),
    "ready_runtime_admission_chunk_dispatch_rows": str(ready_chunk_dispatch_rows),
    "completed_runtime_admission_chunk_rows": str(completed_chunk_rows),
    "accepted_runtime_admission_chunk_return_rows": str(accepted_chunk_return_rows),
    "ready_operator_command_rows": str(ready_operator_command_rows),
    "full_shard_prerequisites_closed": v61cx["full_shard_prerequisites_closed"],
    "guarded_runtime_admission_command_ready": v61cv["guarded_runtime_admission_command_ready"],
    "runtime_admission_acceptance_rows": v61cw["runtime_admission_acceptance_rows"],
    "runtime_admission_accepted_rows": v61cw["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61cw["complete_source_runtime_admission_execution_ready"],
    "chunk_dispatch_ready": str(chunk_dispatch_ready),
    "chunk_merge_ready": "0",
    "aggregate_runtime_return_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cy": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "runtime_admission_chunk_execution_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cy_runtime_admission_chunk_execution_queue_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "runtime-admission-expansion-input", "status": "pass", "reason": f"runtime_admission_expansion_rows={len(expansion_rows)}"},
    {"gate": "runtime-admission-operator-input", "status": "pass", "reason": "v61cv operator bundle is ready"},
    {"gate": "post-full-shard-closure-input", "status": "pass", "reason": f"full_shard_prerequisites_closed={v61cx['full_shard_prerequisites_closed']}"},
    {"gate": "runtime-admission-chunk-dispatch", "status": status(chunk_dispatch_ready), "reason": f"ready_runtime_admission_chunk_dispatch_rows={ready_chunk_dispatch_rows}/{len(chunk_rows)}"},
    {"gate": "runtime-admission-chunk-return", "status": "blocked", "reason": f"accepted_runtime_admission_chunk_return_rows={accepted_chunk_return_rows}/{len(chunk_rows)}"},
    {"gate": "runtime-admission-aggregate-return", "status": "blocked", "reason": "aggregate runtime admission return artifacts are missing"},
    {"gate": "complete-source-runtime-admission-acceptance", "status": status(runtime_acceptance_ready), "reason": f"runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}/{v61cw['runtime_admission_acceptance_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cy writes metadata and copied evidence only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cy Runtime Admission Chunk Execution Queue Boundary

This artifact splits the 1000-row complete-source runtime admission expansion
packet into bounded chunks so the post-full-shard runtime admission return can
be executed and merged without re-opening checkpoint/page-hash closure.

Evidence emitted:

- runtime_admission_expansion_rows={len(expansion_rows)}
- runtime_admission_chunk_size={chunk_size}
- runtime_admission_chunk_rows={len(chunk_rows)}
- runtime_admission_chunk_manifest_rows={len(manifest_rows)}
- runtime_admission_chunk_return_artifact_rows={len(chunk_artifact_rows)}
- runtime_admission_aggregate_return_artifact_rows={len(aggregate_rows)}
- ready_runtime_admission_chunk_dispatch_rows={ready_chunk_dispatch_rows}
- completed_runtime_admission_chunk_rows={completed_chunk_rows}
- accepted_runtime_admission_chunk_return_rows={accepted_chunk_return_rows}
- full_shard_prerequisites_closed={v61cx['full_shard_prerequisites_closed']}
- guarded_runtime_admission_command_ready={v61cv['guarded_runtime_admission_command_ready']}
- runtime_admission_acceptance_rows={v61cw['runtime_admission_acceptance_rows']}
- runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}
- complete_source_runtime_admission_execution_ready={v61cw['complete_source_runtime_admission_execution_ready']}
- chunk_dispatch_ready={chunk_dispatch_ready}
- chunk_merge_ready=0
- aggregate_runtime_return_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cy=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: runtime admission chunk execution queue after full-shard
closure. Blocked wording: completed runtime admission, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CY_RUNTIME_ADMISSION_CHUNK_EXECUTION_QUEUE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cy_runtime_admission_chunk_execution_queue",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cy_runtime_admission_chunk_execution_queue_ready": 1,
    "runtime_admission_expansion_rows": len(expansion_rows),
    "runtime_admission_chunk_rows": len(chunk_rows),
    "runtime_admission_chunk_manifest_rows": len(manifest_rows),
    "runtime_admission_chunk_return_artifact_rows": len(chunk_artifact_rows),
    "runtime_admission_aggregate_return_artifact_rows": len(aggregate_rows),
    "chunk_dispatch_ready": chunk_dispatch_ready,
    "complete_source_runtime_admission_execution_ready": runtime_acceptance_ready,
    "actual_model_generation_ready": 0,
    "source_v61cq_summary_sha256": sha256(sources["v61cq"][0]),
    "source_v61cv_summary_sha256": sha256(sources["v61cv"][0]),
    "source_v61cw_summary_sha256": sha256(sources["v61cw"][0]),
    "source_v61cx_summary_sha256": sha256(sources["v61cx"][0]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cy_runtime_admission_chunk_execution_queue_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cy_runtime_admission_chunk_execution_queue_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
