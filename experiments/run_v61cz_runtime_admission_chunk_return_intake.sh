#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cz_runtime_admission_chunk_return_intake"
RUN_ID="${V61CZ_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cz_runtime_admission_chunk_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cy_runtime_admission_chunk_execution_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "${V61CZ_RUNTIME_ADMISSION_CHUNK_RETURN_DIR:-}" <<'PY'
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
return_dir_arg = sys.argv[5]
return_dir = Path(return_dir_arg).expanduser().resolve() if return_dir_arg else None
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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


def data_row_count(path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle)
        rows = list(reader)
    return max(0, len(rows) - 1)


v61cy_summary_path = results / "v61cy_runtime_admission_chunk_execution_queue_summary.csv"
v61cy_decision_path = results / "v61cy_runtime_admission_chunk_execution_queue_decision.csv"
v61cy_dir = results / "v61cy_runtime_admission_chunk_execution_queue" / "queue_001"
v61cy = read_csv(v61cy_summary_path)[0]
if v61cy.get("v61cy_runtime_admission_chunk_execution_queue_ready") != "1":
    raise SystemExit("v61cz requires v61cy_runtime_admission_chunk_execution_queue_ready=1")

for src, rel in [
    (v61cy_summary_path, "source_v61cy/v61cy_runtime_admission_chunk_execution_queue_summary.csv"),
    (v61cy_decision_path, "source_v61cy/v61cy_runtime_admission_chunk_execution_queue_decision.csv"),
    (v61cy_dir / "runtime_admission_execution_chunk_rows.csv", "source_v61cy/runtime_admission_execution_chunk_rows.csv"),
    (v61cy_dir / "runtime_admission_chunk_manifest_rows.csv", "source_v61cy/runtime_admission_chunk_manifest_rows.csv"),
    (v61cy_dir / "runtime_admission_chunk_return_artifact_rows.csv", "source_v61cy/runtime_admission_chunk_return_artifact_rows.csv"),
    (v61cy_dir / "runtime_admission_aggregate_return_artifact_rows.csv", "source_v61cy/runtime_admission_aggregate_return_artifact_rows.csv"),
    (v61cy_dir / "runtime_admission_chunk_operator_command_rows.csv", "source_v61cy/runtime_admission_chunk_operator_command_rows.csv"),
    (v61cy_dir / "operator_bundle/RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv", "source_v61cy/RUNTIME_ADMISSION_AGGREGATE_RETURN_TEMPLATE.csv"),
    (v61cy_dir / "sha256_manifest.csv", "source_v61cy/sha256_manifest.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v61cy_dir / "runtime_admission_execution_chunk_rows.csv")
chunk_artifact_rows = read_csv(v61cy_dir / "runtime_admission_chunk_return_artifact_rows.csv")
aggregate_template_rows = read_csv(v61cy_dir / "runtime_admission_aggregate_return_artifact_rows.csv")
if len(chunk_rows) != as_int(v61cy, "runtime_admission_chunk_rows"):
    raise SystemExit("v61cz chunk row count mismatch")
if len(chunk_artifact_rows) != as_int(v61cy, "runtime_admission_chunk_return_artifact_rows"):
    raise SystemExit("v61cz chunk artifact count mismatch")
if len(aggregate_template_rows) != as_int(v61cy, "runtime_admission_aggregate_return_artifact_rows"):
    raise SystemExit("v61cz aggregate artifact count mismatch")

return_dir_supplied = int(return_dir is not None)
return_dir_exists = int(return_dir is not None and return_dir.is_dir())

artifact_status_rows = []
accepted_artifacts = 0
missing_artifacts = 0
invalid_artifacts = 0
supplied_artifacts = 0
accepted_rows_total = 0

for row in chunk_artifact_rows:
    required_rows = int(row["required_rows"])
    supplied_path = return_dir / row["chunk_return_path"] if return_dir else None
    file_exists = int(supplied_path is not None and supplied_path.is_file())
    supplied_artifacts += file_exists
    observed_rows = 0
    artifact_hash = ""
    current_status = "missing"
    accepted_rows = 0
    if file_exists:
        observed_rows = data_row_count(supplied_path)
        artifact_hash = sha256(supplied_path)
        if observed_rows == required_rows:
            current_status = "accepted"
            accepted_rows = observed_rows
            accepted_artifacts += 1
        else:
            current_status = "invalid-row-count"
            invalid_artifacts += 1
    else:
        missing_artifacts += 1
    accepted_rows_total += accepted_rows
    artifact_status_rows.append(
        {
            "chunk_artifact_id": row["chunk_artifact_id"],
            "runtime_admission_chunk_id": row["runtime_admission_chunk_id"],
            "result_artifact": row["result_artifact"],
            "artifact_scope": row["artifact_scope"],
            "expected_path": row["chunk_return_path"],
            "required_rows": row["required_rows"],
            "supplied": str(file_exists),
            "observed_rows": str(observed_rows),
            "accepted_rows": str(accepted_rows),
            "current_status": current_status,
            "artifact_sha256": artifact_hash,
            "checkpoint_payload_bytes_downloaded_by_v61cz": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "runtime_admission_chunk_return_artifact_status_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)

accepted_artifacts_by_chunk = {}
required_artifacts_by_chunk = {}
for row in artifact_status_rows:
    chunk_id = row["runtime_admission_chunk_id"]
    if chunk_id == "global":
        continue
    required_artifacts_by_chunk[chunk_id] = required_artifacts_by_chunk.get(chunk_id, 0) + 1
    accepted_artifacts_by_chunk[chunk_id] = accepted_artifacts_by_chunk.get(chunk_id, 0) + int(row["current_status"] == "accepted")

global_identity_accepted = any(
    row["runtime_admission_chunk_id"] == "global" and row["current_status"] == "accepted"
    for row in artifact_status_rows
)

chunk_status_rows = []
accepted_chunk_rows = 0
missing_chunk_rows = 0
for chunk in chunk_rows:
    chunk_id = chunk["runtime_admission_chunk_id"]
    required = required_artifacts_by_chunk.get(chunk_id, 0)
    accepted = accepted_artifacts_by_chunk.get(chunk_id, 0)
    chunk_return_ready = int(required == 4 and accepted == required)
    accepted_chunk_rows += chunk_return_ready
    missing_chunk_rows += int(not chunk_return_ready)
    chunk_status_rows.append(
        {
            "runtime_admission_chunk_id": chunk_id,
            "chunk_index": chunk["chunk_index"],
            "query_rows": chunk["query_rows"],
            "required_chunk_artifacts": str(required),
            "accepted_chunk_artifacts": str(accepted),
            "chunk_return_ready": str(chunk_return_ready),
            "chunk_merge_ready": str(int(chunk_return_ready and global_identity_accepted)),
            "blocking_reason": "accepted" if chunk_return_ready else "chunk return artifacts missing or invalid",
            "checkpoint_payload_bytes_downloaded_by_v61cz": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "runtime_admission_chunk_return_status_rows.csv", list(chunk_status_rows[0].keys()), chunk_status_rows)

accepted_by_artifact = {}
required_by_artifact = {}
accepted_source_artifacts_by_result = {}
required_source_artifacts_by_result = {}
for row in artifact_status_rows:
    result = row["result_artifact"]
    accepted_by_artifact[result] = accepted_by_artifact.get(result, 0) + int(row["accepted_rows"])
    required_by_artifact[result] = required_by_artifact.get(result, 0) + int(row["required_rows"])
    accepted_source_artifacts_by_result[result] = accepted_source_artifacts_by_result.get(result, 0) + int(row["current_status"] == "accepted")
    required_source_artifacts_by_result[result] = required_source_artifacts_by_result.get(result, 0) + 1

aggregate_rows = []
aggregate_merge_ready_rows = 0
for row in aggregate_template_rows:
    result = row["result_artifact"]
    accepted_rows = accepted_by_artifact.get(result, 0)
    required_rows = int(row["required_rows"])
    accepted_sources = accepted_source_artifacts_by_result.get(result, 0)
    required_sources = int(row["source_chunk_artifacts_required"])
    merge_ready = int(accepted_rows == required_rows and accepted_sources == required_sources)
    aggregate_merge_ready_rows += merge_ready
    aggregate_rows.append(
        {
            "result_artifact": result,
            "aggregate_return_path": row["aggregate_return_path"],
            "required_rows": row["required_rows"],
            "accepted_rows_from_chunks": str(accepted_rows),
            "source_chunk_artifacts_required": row["source_chunk_artifacts_required"],
            "source_chunk_artifacts_accepted": str(accepted_sources),
            "merge_ready": str(merge_ready),
            "current_status": "accepted" if merge_ready else "missing",
            "artifact_sha256": "",
            "operator_note": "ready for v61cr aggregate intake" if merge_ready else "chunk returns incomplete",
        }
    )
write_csv(run_dir / "runtime_admission_aggregate_return_merge_rows.csv", list(aggregate_rows[0].keys()), aggregate_rows)

merge_ready = int(aggregate_merge_ready_rows == len(aggregate_rows))
runtime_acceptance_ready = int(merge_ready and as_int(v61cy, "complete_source_runtime_admission_execution_ready"))

requirement_rows = [
    {"requirement_id": "v61cy-runtime-admission-chunk-queue-input", "status": "pass", "required_value": "1", "actual_value": v61cy["v61cy_runtime_admission_chunk_execution_queue_ready"], "reason": "v61cy chunk queue is bound"},
    {"requirement_id": "chunk-return-directory-supplied", "status": "pass" if return_dir_supplied else "blocked", "required_value": "1", "actual_value": str(return_dir_supplied), "reason": "chunk return directory may be supplied with V61CZ_RUNTIME_ADMISSION_CHUNK_RETURN_DIR"},
    {"requirement_id": "chunk-return-directory-exists", "status": "pass" if return_dir_exists else "blocked", "required_value": "1", "actual_value": str(return_dir_exists), "reason": "chunk return directory must exist before accepting chunk artifacts"},
    {"requirement_id": "chunk-return-artifacts", "status": status(accepted_artifacts == len(chunk_artifact_rows)), "required_value": str(len(chunk_artifact_rows)), "actual_value": str(accepted_artifacts), "reason": "all chunk return artifacts must be accepted"},
    {"requirement_id": "runtime-admission-chunk-returns", "status": status(accepted_chunk_rows == len(chunk_rows)), "required_value": str(len(chunk_rows)), "actual_value": str(accepted_chunk_rows), "reason": "all per-query chunk returns must be accepted"},
    {"requirement_id": "global-runtime-identity-return", "status": status(global_identity_accepted), "required_value": "1", "actual_value": str(int(global_identity_accepted)), "reason": "global 59-row runtime identity artifact must be accepted"},
    {"requirement_id": "aggregate-runtime-return-merge", "status": status(merge_ready), "required_value": str(len(aggregate_rows)), "actual_value": str(aggregate_merge_ready_rows), "reason": "all aggregate runtime return artifacts must be merge-ready"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61cz writes metadata and copied evidence only"},
]
write_csv(run_dir / "runtime_admission_chunk_return_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "chunk-return-directory", "status": "ready" if return_dir_exists else "blocked", "reason": f"return_dir_supplied={return_dir_supplied}, return_dir_exists={return_dir_exists}"},
    {"gap": "chunk-return-artifacts", "status": "ready" if accepted_artifacts == len(chunk_artifact_rows) else "blocked", "reason": f"accepted_chunk_return_artifacts={accepted_artifacts}/{len(chunk_artifact_rows)}"},
    {"gap": "runtime-admission-chunk-returns", "status": "ready" if accepted_chunk_rows == len(chunk_rows) else "blocked", "reason": f"accepted_runtime_admission_chunk_rows={accepted_chunk_rows}/{len(chunk_rows)}"},
    {"gap": "aggregate-runtime-return-merge", "status": "ready" if merge_ready else "blocked", "reason": f"aggregate_runtime_return_merge_ready_rows={aggregate_merge_ready_rows}/{len(aggregate_rows)}"},
    {"gap": "complete-source-runtime-admission-acceptance", "status": "blocked", "reason": "v61cr/v61cw aggregate acceptance has not been refreshed from merged chunk returns"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gap": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gap": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61cz_runtime_admission_chunk_return_intake_metrics",
    "model_id": model_id,
    "v61cy_runtime_admission_chunk_execution_queue_ready": v61cy["v61cy_runtime_admission_chunk_execution_queue_ready"],
    "runtime_admission_chunk_rows": v61cy["runtime_admission_chunk_rows"],
    "runtime_admission_chunk_manifest_rows": v61cy["runtime_admission_chunk_manifest_rows"],
    "runtime_admission_chunk_return_artifact_rows": str(len(chunk_artifact_rows)),
    "runtime_admission_aggregate_return_artifact_rows": str(len(aggregate_rows)),
    "chunk_return_dir_supplied": str(return_dir_supplied),
    "chunk_return_dir_exists": str(return_dir_exists),
    "supplied_chunk_return_artifacts": str(supplied_artifacts),
    "accepted_chunk_return_artifacts": str(accepted_artifacts),
    "missing_chunk_return_artifacts": str(missing_artifacts),
    "invalid_chunk_return_artifacts": str(invalid_artifacts),
    "accepted_chunk_return_rows": str(accepted_rows_total),
    "accepted_runtime_admission_chunk_rows": str(accepted_chunk_rows),
    "missing_runtime_admission_chunk_rows": str(missing_chunk_rows),
    "global_runtime_identity_return_ready": str(int(global_identity_accepted)),
    "aggregate_runtime_return_merge_ready_rows": str(aggregate_merge_ready_rows),
    "aggregate_runtime_return_merge_ready": str(merge_ready),
    "runtime_admission_accepted_rows": "0",
    "complete_source_runtime_admission_execution_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "runtime_admission_chunk_return_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cz_runtime_admission_chunk_return_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "runtime-admission-chunk-queue-input", "status": "pass", "reason": "v61cy chunk queue is ready"},
    {"gate": "chunk-return-directory", "status": "pass" if return_dir_exists else "blocked", "reason": f"chunk_return_dir_exists={return_dir_exists}"},
    {"gate": "chunk-return-artifacts", "status": status(accepted_artifacts == len(chunk_artifact_rows)), "reason": f"accepted_chunk_return_artifacts={accepted_artifacts}/{len(chunk_artifact_rows)}"},
    {"gate": "runtime-admission-chunk-returns", "status": status(accepted_chunk_rows == len(chunk_rows)), "reason": f"accepted_runtime_admission_chunk_rows={accepted_chunk_rows}/{len(chunk_rows)}"},
    {"gate": "aggregate-runtime-return-merge", "status": status(merge_ready), "reason": f"aggregate_runtime_return_merge_ready_rows={aggregate_merge_ready_rows}/{len(aggregate_rows)}"},
    {"gate": "complete-source-runtime-admission-acceptance", "status": "blocked", "reason": "merged aggregate return has not been accepted by v61cr/v61cw"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cz writes metadata and copied evidence only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cz Runtime Admission Chunk Return Intake Boundary

This artifact intakes returned v61cy runtime admission chunk artifacts and
computes whether they can be merged into the five aggregate v61cr return files.
It does not fabricate missing chunk returns and does not claim complete-source
runtime admission acceptance.

Evidence emitted:

- runtime_admission_chunk_rows={v61cy['runtime_admission_chunk_rows']}
- runtime_admission_chunk_manifest_rows={v61cy['runtime_admission_chunk_manifest_rows']}
- runtime_admission_chunk_return_artifact_rows={len(chunk_artifact_rows)}
- runtime_admission_aggregate_return_artifact_rows={len(aggregate_rows)}
- chunk_return_dir_supplied={return_dir_supplied}
- chunk_return_dir_exists={return_dir_exists}
- supplied_chunk_return_artifacts={supplied_artifacts}
- accepted_chunk_return_artifacts={accepted_artifacts}
- missing_chunk_return_artifacts={missing_artifacts}
- invalid_chunk_return_artifacts={invalid_artifacts}
- accepted_runtime_admission_chunk_rows={accepted_chunk_rows}
- missing_runtime_admission_chunk_rows={missing_chunk_rows}
- global_runtime_identity_return_ready={int(global_identity_accepted)}
- aggregate_runtime_return_merge_ready_rows={aggregate_merge_ready_rows}
- aggregate_runtime_return_merge_ready={merge_ready}
- runtime_admission_accepted_rows=0
- complete_source_runtime_admission_execution_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cz=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: runtime admission chunk return intake and aggregate merge
readiness. Blocked wording: completed runtime admission, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CZ_RUNTIME_ADMISSION_CHUNK_RETURN_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cz_runtime_admission_chunk_return_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cz_runtime_admission_chunk_return_intake_ready": 1,
    "chunk_return_dir_supplied": return_dir_supplied,
    "chunk_return_dir_exists": return_dir_exists,
    "accepted_chunk_return_artifacts": accepted_artifacts,
    "accepted_runtime_admission_chunk_rows": accepted_chunk_rows,
    "aggregate_runtime_return_merge_ready": merge_ready,
    "complete_source_runtime_admission_execution_ready": 0,
    "actual_model_generation_ready": 0,
    "source_v61cy_summary_sha256": sha256(v61cy_summary_path),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cz_runtime_admission_chunk_return_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cz_runtime_admission_chunk_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
