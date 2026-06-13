#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53x_complete_source_review_chunk_return_intake"
RUN_ID="${V53X_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_DIR="${V53X_REVIEW_CHUNK_RETURN_DIR:-}"

if [[ "${V53X_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53x_complete_source_review_chunk_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53W_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_DIR" <<'PY'
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

ACCEPTANCE_REQUIRED_FIELDS = [
    "review_protocol_version",
    "acceptance_decision",
    "expected_human_review_rows",
    "accepted_human_review_rows",
    "human_review_rows_sha256",
    "expected_adjudication_rows",
    "accepted_adjudication_rows",
    "adjudication_rows_sha256",
    "expected_reviewer_identity_rows",
    "accepted_reviewer_identity_rows",
    "reviewer_identity_rows_sha256",
    "expected_conflict_disclosure_rows",
    "accepted_conflict_disclosure_rows",
    "reviewer_conflict_rows_sha256",
]


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


def read_csv_with_fields(path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return rows, reader.fieldnames or []


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


v53w_summary_path = results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv"
v53w_decision_path = results / "v53w_complete_source_review_return_chunk_execution_queue_decision.csv"
v53w_dir = results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001"
v53w = read_csv(v53w_summary_path)[0]
if v53w.get("v53w_complete_source_review_return_chunk_execution_queue_ready") != "1":
    raise SystemExit("v53x requires v53w_complete_source_review_return_chunk_execution_queue_ready=1")

for src, rel in [
    (v53w_summary_path, "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_summary.csv"),
    (v53w_decision_path, "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_decision.csv"),
    (v53w_dir / "review_return_chunk_execution_rows.csv", "source_v53w/review_return_chunk_execution_rows.csv"),
    (v53w_dir / "review_return_chunk_task_rows.csv", "source_v53w/review_return_chunk_task_rows.csv"),
    (v53w_dir / "review_return_chunk_artifact_rows.csv", "source_v53w/review_return_chunk_artifact_rows.csv"),
    (v53w_dir / "review_return_aggregate_artifact_rows.csv", "source_v53w/review_return_aggregate_artifact_rows.csv"),
    (v53w_dir / "review_return_chunk_command_rows.csv", "source_v53w/review_return_chunk_command_rows.csv"),
    (v53w_dir / "source_v53s/review_return_required_field_rows.csv", "source_v53w/review_return_required_field_rows.csv"),
    (v53w_dir / "sha256_manifest.csv", "source_v53w/sha256_manifest.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v53w_dir / "review_return_chunk_execution_rows.csv")
chunk_artifact_rows = read_csv(v53w_dir / "review_return_chunk_artifact_rows.csv")
aggregate_template_rows = read_csv(v53w_dir / "review_return_aggregate_artifact_rows.csv")
required_field_rows = read_csv(v53w_dir / "source_v53s/review_return_required_field_rows.csv")

if len(chunk_rows) != as_int(v53w, "review_chunk_rows"):
    raise SystemExit("v53x chunk row count mismatch")
if len(chunk_artifact_rows) != as_int(v53w, "review_chunk_return_artifact_rows"):
    raise SystemExit("v53x chunk artifact count mismatch")
if len(aggregate_template_rows) != as_int(v53w, "aggregate_review_return_artifact_rows"):
    raise SystemExit("v53x aggregate artifact count mismatch")

required_fields_by_artifact = {}
for row in required_field_rows:
    if row["field_name"] == "json_document":
        continue
    required_fields_by_artifact.setdefault(row["return_artifact"], set()).add(row["field_name"])

return_dir_supplied = int(return_dir is not None)
return_dir_exists = int(return_dir is not None and return_dir.is_dir())

artifact_status_rows = []
accepted_chunk_artifacts = 0
missing_chunk_artifacts = 0
invalid_chunk_artifacts = 0
supplied_chunk_artifacts = 0
accepted_rows_by_family = {}

for row in chunk_artifact_rows:
    required_rows = int(row["expected_rows"])
    artifact_family = row["artifact_family"]
    expected_rel = row["return_artifact"]
    supplied_path = return_dir / expected_rel if return_dir else None
    file_exists = int(supplied_path is not None and supplied_path.is_file())
    supplied_chunk_artifacts += file_exists
    observed_rows = 0
    accepted_rows = 0
    missing_fields = []
    artifact_hash = ""
    current_status = "missing"
    if file_exists:
        rows, fields = read_csv_with_fields(supplied_path)
        observed_rows = len(rows)
        artifact_hash = sha256(supplied_path)
        missing_fields = sorted(required_fields_by_artifact.get(artifact_family, set()) - set(fields))
        if missing_fields:
            current_status = "invalid-field-set"
            invalid_chunk_artifacts += 1
        elif observed_rows != required_rows:
            current_status = "invalid-row-count"
            invalid_chunk_artifacts += 1
        else:
            current_status = "accepted"
            accepted_rows = observed_rows
            accepted_chunk_artifacts += 1
    else:
        missing_chunk_artifacts += 1
    accepted_rows_by_family[artifact_family] = accepted_rows_by_family.get(artifact_family, 0) + accepted_rows
    artifact_status_rows.append(
        {
            "review_chunk_id": row["review_chunk_id"],
            "return_artifact": expected_rel,
            "artifact_family": artifact_family,
            "expected_rows": row["expected_rows"],
            "supplied": str(file_exists),
            "observed_rows": str(observed_rows),
            "accepted_rows": str(accepted_rows),
            "current_status": current_status,
            "missing_required_fields": ";".join(missing_fields),
            "artifact_sha256": artifact_hash,
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "review_return_chunk_artifact_status_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)

required_artifacts_by_chunk = {}
accepted_artifacts_by_chunk = {}
for row in artifact_status_rows:
    chunk_id = row["review_chunk_id"]
    required_artifacts_by_chunk[chunk_id] = required_artifacts_by_chunk.get(chunk_id, 0) + 1
    accepted_artifacts_by_chunk[chunk_id] = accepted_artifacts_by_chunk.get(chunk_id, 0) + int(row["current_status"] == "accepted")

chunk_status_rows = []
ready_chunk_returns = 0
for row in chunk_rows:
    chunk_id = row["review_chunk_id"]
    required = required_artifacts_by_chunk.get(chunk_id, 0)
    accepted = accepted_artifacts_by_chunk.get(chunk_id, 0)
    chunk_return_ready = int(required > 0 and required == accepted)
    ready_chunk_returns += chunk_return_ready
    chunk_status_rows.append(
        {
            "review_chunk_id": chunk_id,
            "assignment_id": row["assignment_id"],
            "system_id": row["system_id"],
            "review_scope": row["review_scope"],
            "required_chunk_artifacts": str(required),
            "accepted_chunk_artifacts": str(accepted),
            "chunk_return_ready": str(chunk_return_ready),
            "blocking_reason": "accepted" if chunk_return_ready else "chunk return artifacts missing or invalid",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "review_return_chunk_status_rows.csv", list(chunk_status_rows[0].keys()), chunk_status_rows)

aggregate_status_rows = []
accepted_aggregate_artifacts = 0
missing_aggregate_artifacts = 0
invalid_aggregate_artifacts = 0
supplied_aggregate_artifacts = 0
accepted_aggregate_rows_by_artifact = {}

for row in aggregate_template_rows:
    artifact = row["aggregate_artifact"]
    expected_rows = int(row["expected_rows"])
    supplied_path = return_dir / artifact if return_dir else None
    file_exists = int(supplied_path is not None and supplied_path.is_file())
    supplied_aggregate_artifacts += file_exists
    observed_rows = 0
    accepted_rows = 0
    missing_fields = []
    artifact_hash = ""
    current_status = "missing"
    if file_exists and artifact.endswith(".csv"):
        rows, fields = read_csv_with_fields(supplied_path)
        observed_rows = len(rows)
        artifact_hash = sha256(supplied_path)
        missing_fields = sorted(required_fields_by_artifact.get(artifact, set()) - set(fields))
        if missing_fields:
            current_status = "invalid-field-set"
            invalid_aggregate_artifacts += 1
        elif observed_rows != expected_rows:
            current_status = "invalid-row-count"
            invalid_aggregate_artifacts += 1
        else:
            current_status = "accepted"
            accepted_rows = observed_rows
            accepted_aggregate_artifacts += 1
    elif file_exists and artifact == "acceptance_summary.json":
        artifact_hash = sha256(supplied_path)
        try:
            payload = json.loads(supplied_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            payload = {}
            current_status = "invalid-json"
            invalid_aggregate_artifacts += 1
        if payload:
            missing_fields = sorted(set(ACCEPTANCE_REQUIRED_FIELDS) - set(payload.keys()))
            if missing_fields:
                current_status = "invalid-field-set"
                invalid_aggregate_artifacts += 1
            else:
                observed_rows = 1
                accepted_rows = 1
                current_status = "accepted"
                accepted_aggregate_artifacts += 1
    elif file_exists:
        artifact_hash = sha256(supplied_path)
        current_status = "invalid-artifact-kind"
        invalid_aggregate_artifacts += 1
    else:
        missing_aggregate_artifacts += 1
    accepted_aggregate_rows_by_artifact[artifact] = accepted_rows
    aggregate_status_rows.append(
        {
            "aggregate_artifact": artifact,
            "source_chunk_artifact_family": row["source_chunk_artifact_family"],
            "expected_rows": row["expected_rows"],
            "supplied": str(file_exists),
            "observed_rows": str(observed_rows),
            "accepted_rows": str(accepted_rows),
            "current_status": current_status,
            "missing_required_fields": ";".join(missing_fields),
            "artifact_sha256": artifact_hash,
            "target_intake": row["target_intake"],
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "review_return_aggregate_artifact_status_rows.csv", list(aggregate_status_rows[0].keys()), aggregate_status_rows)

expected_human = as_int(v53w, "expected_human_review_rows")
expected_adjudication = as_int(v53w, "expected_adjudication_rows")
expected_identity = as_int(v53w, "expected_reviewer_identity_rows")
expected_conflict = as_int(v53w, "expected_conflict_disclosure_rows")
accepted_human = accepted_rows_by_family.get("human_review_rows.csv", 0)
accepted_adjudication = accepted_rows_by_family.get("adjudication_rows.csv", 0)
accepted_identity = accepted_rows_by_family.get("reviewer_identity_rows.csv", 0)
accepted_conflict = accepted_rows_by_family.get("reviewer_conflict_rows.csv", 0)
chunk_return_intake_ready = int(
    accepted_chunk_artifacts == len(chunk_artifact_rows)
    and ready_chunk_returns == len(chunk_rows)
    and accepted_human == expected_human
    and accepted_adjudication == expected_adjudication
    and accepted_identity == expected_identity
    and accepted_conflict == expected_conflict
)
aggregate_review_return_ready = int(accepted_aggregate_artifacts == len(aggregate_template_rows))
v53s_refresh_ready = int(chunk_return_intake_ready and aggregate_review_return_ready)

operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)

(operator_dir / "README.md").write_text(
    "# v53x Review Chunk Return Intake\n\n"
    "Supply a review chunk return directory with `chunks/<review_chunk_id>/...` "
    "files plus the five aggregate v53s artifacts at the directory root. This "
    "intake verifies shape, row counts, and required CSV fields. It does not "
    "promote v53 readiness; run v53s/v53v on the aggregate return after this "
    "gate reports `v53s_refresh_ready=1`.\n",
    encoding="utf-8",
)

verify_script = operator_dir / "VERIFY_CHUNK_RETURN_INTAKE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/review_return_chunk_artifact_status_rows.csv"
  "$BUNDLE_DIR/review_return_chunk_status_rows.csv"
  "$BUNDLE_DIR/review_return_aggregate_artifact_status_rows.csv"
  "$BUNDLE_DIR/source_v53w/review_return_chunk_artifact_rows.csv"
  "$BUNDLE_DIR/source_v53w/review_return_aggregate_artifact_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53x chunk return intake file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/review_return_chunk_artifact_status_rows.csv" | tr -d ' ')" == "51" ]] || { echo "expected 50 chunk artifact status rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_chunk_status_rows.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 chunk status rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_aggregate_artifact_status_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected 5 aggregate artifact status rows" >&2; exit 1; }

echo "v53x review chunk return intake shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

command_rows = [
    {
        "command_id": "verify-chunk-return-intake-shape",
        "command": "results/v53x_complete_source_review_chunk_return_intake/intake_001/operator_bundle/VERIFY_CHUNK_RETURN_INTAKE.sh",
        "ready_to_run_now": "1",
        "expected_return": "chunk return intake files and counts are shape-valid",
    },
    {
        "command_id": "refresh-v53s-from-aggregate-return",
        "command": "V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return V53S_REUSE_EXISTING=0 ./experiments/run_v53s_complete_source_review_return_intake.sh",
        "ready_to_run_now": str(v53s_refresh_ready),
        "expected_return": "review_return_ready=1 after real aggregate review return",
    },
    {
        "command_id": "refresh-v53v-acceptance",
        "command": "V53V_REUSE_EXISTING=0 ./experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh",
        "ready_to_run_now": str(v53s_refresh_ready),
        "expected_return": "answer_review_accepted_rows=7000",
    },
]
write_csv(run_dir / "review_return_chunk_intake_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {"requirement_id": "v53w-chunk-queue-input", "status": "pass", "required_value": "1", "actual_value": v53w["v53w_complete_source_review_return_chunk_execution_queue_ready"], "reason": "v53w chunk queue is bound"},
    {"requirement_id": "return-directory-supplied", "status": status(return_dir_exists), "required_value": "existing return directory", "actual_value": str(return_dir) if return_dir else "", "reason": "review chunks must be supplied outside the repo"},
    {"requirement_id": "chunk-return-artifact-intake", "status": status(chunk_return_intake_ready), "required_value": "50 accepted chunk artifacts", "actual_value": f"{accepted_chunk_artifacts}/{len(chunk_artifact_rows)}", "reason": "all chunk CSV files must match expected rows and required fields"},
    {"requirement_id": "aggregate-review-return-artifact-intake", "status": status(aggregate_review_return_ready), "required_value": "5 accepted aggregate artifacts", "actual_value": f"{accepted_aggregate_artifacts}/{len(aggregate_template_rows)}", "reason": "aggregate files must be ready for v53s"},
    {"requirement_id": "v53s-refresh-ready", "status": status(v53s_refresh_ready), "required_value": "1", "actual_value": str(v53s_refresh_ready), "reason": "v53s refresh is allowed only after chunk and aggregate evidence pass"},
    {"requirement_id": "v53-ready", "status": "blocked", "required_value": "review_return_ready=1 and answer_review_accepted_rows=7000", "actual_value": "0", "reason": "v53x intake does not replace v53s/v53v acceptance"},
]
write_csv(run_dir / "review_return_chunk_intake_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "return-directory", "status": "ready" if return_dir_exists else "blocked", "reason": f"return_dir_supplied={return_dir_supplied}, return_dir_exists={return_dir_exists}"},
    {"gap": "chunk-return-artifacts", "status": "ready" if chunk_return_intake_ready else "blocked", "reason": f"accepted_chunk_return_artifacts={accepted_chunk_artifacts}/{len(chunk_artifact_rows)}"},
    {"gap": "aggregate-review-return-artifacts", "status": "ready" if aggregate_review_return_ready else "blocked", "reason": f"accepted_aggregate_return_artifacts={accepted_aggregate_artifacts}/{len(aggregate_template_rows)}"},
    {"gap": "v53s-refresh", "status": "ready" if v53s_refresh_ready else "blocked", "reason": f"v53s_refresh_ready={v53s_refresh_ready}"},
    {"gap": "review-return-ready", "status": "blocked", "reason": "run v53s/v53v after real aggregate review return is supplied"},
    {"gap": "v53-ready", "status": "blocked", "reason": "human/source review acceptance is not promoted by v53x"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53x_complete_source_review_chunk_return_intake_metrics",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": v53w["v53w_complete_source_review_return_chunk_execution_queue_ready"],
    "return_dir_supplied": str(return_dir_supplied),
    "return_dir_exists": str(return_dir_exists),
    "review_chunk_rows": str(len(chunk_rows)),
    "review_chunk_return_artifact_rows": str(len(chunk_artifact_rows)),
    "supplied_chunk_return_artifact_rows": str(supplied_chunk_artifacts),
    "accepted_chunk_return_artifact_rows": str(accepted_chunk_artifacts),
    "missing_chunk_return_artifact_rows": str(missing_chunk_artifacts),
    "invalid_chunk_return_artifact_rows": str(invalid_chunk_artifacts),
    "ready_review_chunk_return_rows": str(ready_chunk_returns),
    "expected_human_review_rows": str(expected_human),
    "accepted_human_review_rows": str(accepted_human),
    "expected_adjudication_rows": str(expected_adjudication),
    "accepted_adjudication_rows": str(accepted_adjudication),
    "expected_reviewer_identity_rows": str(expected_identity),
    "accepted_reviewer_identity_rows": str(accepted_identity),
    "expected_conflict_disclosure_rows": str(expected_conflict),
    "accepted_conflict_disclosure_rows": str(accepted_conflict),
    "aggregate_review_return_artifact_rows": str(len(aggregate_template_rows)),
    "supplied_aggregate_review_return_artifact_rows": str(supplied_aggregate_artifacts),
    "accepted_aggregate_review_return_artifact_rows": str(accepted_aggregate_artifacts),
    "missing_aggregate_review_return_artifact_rows": str(missing_aggregate_artifacts),
    "invalid_aggregate_review_return_artifact_rows": str(invalid_aggregate_artifacts),
    "chunk_return_intake_ready": str(chunk_return_intake_ready),
    "aggregate_review_return_ready": str(aggregate_review_return_ready),
    "v53s_refresh_ready": str(v53s_refresh_ready),
    "review_return_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "review_return_chunk_intake_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53x_complete_source_review_chunk_return_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53w-chunk-queue-input", "status": "pass", "reason": "v53w chunk queue is bound"},
    {"gate": "return-directory-supplied", "status": status(return_dir_exists), "reason": f"return_dir_exists={return_dir_exists}"},
    {"gate": "chunk-return-artifacts", "status": status(chunk_return_intake_ready), "reason": f"accepted_chunk_return_artifacts={accepted_chunk_artifacts}/{len(chunk_artifact_rows)}"},
    {"gate": "aggregate-review-return-artifacts", "status": status(aggregate_review_return_ready), "reason": f"accepted_aggregate_return_artifacts={accepted_aggregate_artifacts}/{len(aggregate_template_rows)}"},
    {"gate": "v53s-refresh-ready", "status": status(v53s_refresh_ready), "reason": f"v53s_refresh_ready={v53s_refresh_ready}"},
    {"gate": "review-return-ready", "status": "blocked", "reason": "v53s/v53v have not accepted returned review evidence"},
    {"gate": "v53-ready", "status": "blocked", "reason": "actual review return acceptance is still required"},
    {"gate": "v1.0-comparison-ready", "status": "blocked", "reason": "complete-source human/source review is incomplete"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53x Complete Source Review Chunk Return Intake Boundary

This artifact consumes the v53w review chunk-return surface and validates
returned chunk/aggregate artifact shape. It does not fabricate human review
judgments and does not promote v53 readiness without v53s/v53v acceptance.

Evidence emitted:

- return_dir_supplied={return_dir_supplied}
- return_dir_exists={return_dir_exists}
- review_chunk_rows={len(chunk_rows)}
- review_chunk_return_artifact_rows={len(chunk_artifact_rows)}
- supplied_chunk_return_artifact_rows={supplied_chunk_artifacts}
- accepted_chunk_return_artifact_rows={accepted_chunk_artifacts}
- missing_chunk_return_artifact_rows={missing_chunk_artifacts}
- invalid_chunk_return_artifact_rows={invalid_chunk_artifacts}
- ready_review_chunk_return_rows={ready_chunk_returns}
- expected_human_review_rows={expected_human}
- accepted_human_review_rows={accepted_human}
- expected_adjudication_rows={expected_adjudication}
- accepted_adjudication_rows={accepted_adjudication}
- expected_reviewer_identity_rows={expected_identity}
- accepted_reviewer_identity_rows={accepted_identity}
- expected_conflict_disclosure_rows={expected_conflict}
- accepted_conflict_disclosure_rows={accepted_conflict}
- aggregate_review_return_artifact_rows={len(aggregate_template_rows)}
- accepted_aggregate_review_return_artifact_rows={accepted_aggregate_artifacts}
- chunk_return_intake_ready={chunk_return_intake_ready}
- aggregate_review_return_ready={aggregate_review_return_ready}
- v53s_refresh_ready={v53s_refresh_ready}
- review_return_ready=0
- v53_ready=0
- v1_0_comparison_ready=0

Allowed wording: review chunk-return intake surface is ready and reports exact
missing/accepted chunk artifacts.

Blocked wording: accepted human/source review return, v53 readiness, v1.0
comparison readiness, quality comparison claim, or release readiness.
"""
(run_dir / "V53X_COMPLETE_SOURCE_REVIEW_CHUNK_RETURN_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53x-complete-source-review-chunk-return-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53x_complete_source_review_chunk_return_intake_ready": 1,
    "source_v53w_summary_sha256": sha256(v53w_summary_path),
    "return_dir_supplied": return_dir_supplied,
    "return_dir_exists": return_dir_exists,
    "review_chunk_rows": len(chunk_rows),
    "review_chunk_return_artifact_rows": len(chunk_artifact_rows),
    "accepted_chunk_return_artifact_rows": accepted_chunk_artifacts,
    "aggregate_review_return_artifact_rows": len(aggregate_template_rows),
    "accepted_aggregate_review_return_artifact_rows": accepted_aggregate_artifacts,
    "chunk_return_intake_ready": chunk_return_intake_ready,
    "aggregate_review_return_ready": aggregate_review_return_ready,
    "v53s_refresh_ready": v53s_refresh_ready,
    "review_return_ready": 0,
    "v53_ready": 0,
    "v1_0_comparison_ready": 0,
}
(run_dir / "v53x_complete_source_review_chunk_return_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53x_complete_source_review_chunk_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
