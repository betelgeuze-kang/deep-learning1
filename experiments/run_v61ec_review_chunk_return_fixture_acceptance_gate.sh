#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ec_review_chunk_return_fixture_acceptance_gate"
RUN_ID="${V61EC_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_DIR="$RUN_DIR/fixture_review_chunk_returns"
FIXTURE_V53X_RUN_ID="chunk_return_fixture_v61ec"

if [[ "${V61EC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ec_review_chunk_return_fixture_acceptance_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61eb_dispatch_receipt_fixture_acceptance_gate_summary.csv" ]]; then
  V61EB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eb_dispatch_receipt_fixture_acceptance_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61ea_external_review_dispatch_seal_gate_summary.csv" ]]; then
  V61EA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ea_external_review_dispatch_seal_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53w_complete_source_review_return_chunk_execution_queue_summary.csv" ]]; then
  V53W_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_summary.csv" ]]; then
  V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
fixture_dir = Path(sys.argv[3])
results = root / "results"
fixture_dir.mkdir(parents=True, exist_ok=True)

HUMAN_FIELDS = [
    "review_answer_packet_id",
    "answer_id",
    "system_id",
    "query_id",
    "reviewer_id",
    "review_decision",
    "source_support_verified",
    "citation_verified",
    "policy_verified",
    "review_comment_sha256",
]
ADJUDICATION_FIELDS = [
    "adjudication_id",
    "review_answer_packet_id",
    "answer_id",
    "adjudicator_id",
    "adjudication_decision",
    "adjudication_reason_sha256",
]
IDENTITY_FIELDS = [
    "assignment_id",
    "reviewer_id",
    "reviewer_slot_id",
    "system_id",
    "review_scope",
    "independence_declared",
    "credential_statement_sha256",
]
CONFLICT_FIELDS = [
    "assignment_id",
    "reviewer_id",
    "owner_repo",
    "conflict_declared",
    "conflict_statement_sha256",
]
DEFAULT_REPOS = [
    "django/django",
    "fastapi/fastapi",
    "pallets/click",
    "pallets/flask",
    "psf/requests",
    "pypa/pip",
    "pypa/sampleproject",
    "pytest-dev/pytest",
    "python/cpython",
    "tiangolo/typer",
]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


sources = {
    "v61eb_summary": results / "v61eb_dispatch_receipt_fixture_acceptance_gate_summary.csv",
    "v61eb_decision": results / "v61eb_dispatch_receipt_fixture_acceptance_gate_decision.csv",
    "v61ea_summary": results / "v61ea_external_review_dispatch_seal_gate_summary.csv",
    "v53w_summary": results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv",
    "v53w_decision": results / "v53w_complete_source_review_return_chunk_execution_queue_decision.csv",
    "v53x_default_before": results / "v53x_complete_source_review_chunk_return_intake_summary.csv",
}
v53w_dir = results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001"
source_files = {
    "chunk_rows": v53w_dir / "review_return_chunk_execution_rows.csv",
    "chunk_artifacts": v53w_dir / "review_return_chunk_artifact_rows.csv",
    "chunk_tasks": v53w_dir / "review_return_chunk_task_rows.csv",
    "aggregate_artifacts": v53w_dir / "review_return_aggregate_artifact_rows.csv",
    "required_fields": v53w_dir / "source_v53s" / "review_return_required_field_rows.csv",
}
for key, path in {**sources, **source_files}.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ec source {key}: {path}")

copy(sources["v61eb_summary"], "source_v61eb/v61eb_dispatch_receipt_fixture_acceptance_gate_summary.csv")
copy(sources["v61eb_decision"], "source_v61eb/v61eb_dispatch_receipt_fixture_acceptance_gate_decision.csv")
copy(sources["v61ea_summary"], "source_v61ea/v61ea_external_review_dispatch_seal_gate_summary.csv")
copy(sources["v53w_summary"], "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_summary.csv")
copy(sources["v53w_decision"], "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_decision.csv")
copy(sources["v53x_default_before"], "source_v53x_default_before/v53x_complete_source_review_chunk_return_intake_summary.csv")
copy(source_files["chunk_rows"], "source_v53w/review_return_chunk_execution_rows.csv")
copy(source_files["chunk_artifacts"], "source_v53w/review_return_chunk_artifact_rows.csv")
copy(source_files["chunk_tasks"], "source_v53w/review_return_chunk_task_rows.csv")
copy(source_files["aggregate_artifacts"], "source_v53w/review_return_aggregate_artifact_rows.csv")
copy(source_files["required_fields"], "source_v53w/review_return_required_field_rows.csv")

v61eb = read_csv(sources["v61eb_summary"])[0]
v61ea = read_csv(sources["v61ea_summary"])[0]
v53w = read_csv(sources["v53w_summary"])[0]
chunk_rows = read_csv(source_files["chunk_rows"])
artifact_rows = read_csv(source_files["chunk_artifacts"])
task_rows = read_csv(source_files["chunk_tasks"])
aggregate_artifacts = read_csv(source_files["aggregate_artifacts"])

if v61eb["v61eb_dispatch_receipt_fixture_acceptance_gate_ready"] != "1":
    raise SystemExit("v61ec requires v61eb ready")
if v61ea["v61ea_external_review_dispatch_seal_gate_ready"] != "1":
    raise SystemExit("v61ec requires v61ea ready")
if v53w["v53w_complete_source_review_return_chunk_execution_queue_ready"] != "1":
    raise SystemExit("v61ec requires v53w ready")
if len(artifact_rows) != 50:
    raise SystemExit("v61ec expects 50 v53w chunk return artifacts")
if len(aggregate_artifacts) != 5:
    raise SystemExit("v61ec expects five v53w aggregate artifacts")

chunk_by_id = {row["review_chunk_id"]: row for row in chunk_rows}
tasks_by_artifact = {}
repos_by_chunk = {}
for row in task_rows:
    tasks_by_artifact.setdefault(row["expected_return_artifact"], []).append(row)
    repos_by_chunk.setdefault(row["review_chunk_id"], [])
    if row["owner_repo"] not in repos_by_chunk[row["review_chunk_id"]]:
        repos_by_chunk[row["review_chunk_id"]].append(row["owner_repo"])

aggregate_rows = {
    "human_review_rows.csv": [],
    "adjudication_rows.csv": [],
    "reviewer_identity_rows.csv": [],
    "reviewer_conflict_rows.csv": [],
}
fixture_artifact_rows = []
generated_at = datetime.now(timezone.utc).isoformat()

for artifact in artifact_rows:
    chunk_id = artifact["review_chunk_id"]
    rel = artifact["return_artifact"]
    family = artifact["artifact_family"]
    expected_rows = int(artifact["expected_rows"])
    path = fixture_dir / rel
    chunk = chunk_by_id[chunk_id]
    reviewer_id = f"fixture_{chunk['assignment_id']}_{chunk['reviewer_slot_id']}"

    if family == "human_review_rows.csv":
        rows = [
            {
                "review_answer_packet_id": task["review_answer_packet_id"],
                "answer_id": task["answer_id"],
                "system_id": task["system_id"],
                "query_id": task["query_id"],
                "reviewer_id": reviewer_id,
                "review_decision": "fixture-shape-only-not-real-review",
                "source_support_verified": "0",
                "citation_verified": "0",
                "policy_verified": "0",
                "review_comment_sha256": sha256_text(f"v61ec:{task['review_chunk_task_id']}:human:{generated_at}"),
            }
            for task in tasks_by_artifact.get(rel, [])
            if task["task_type"] == "human-review"
        ]
        fieldnames = HUMAN_FIELDS
    elif family == "adjudication_rows.csv":
        rows = [
            {
                "adjudication_id": f"v61ec_fixture_adj_{index:04d}_{task['answer_id']}",
                "review_answer_packet_id": task["review_answer_packet_id"],
                "answer_id": task["answer_id"],
                "adjudicator_id": reviewer_id,
                "adjudication_decision": "fixture-shape-only-not-real-adjudication",
                "adjudication_reason_sha256": sha256_text(f"v61ec:{task['review_chunk_task_id']}:adjudication:{generated_at}"),
            }
            for index, task in enumerate(tasks_by_artifact.get(rel, []), start=1)
            if task["task_type"] == "adjudication"
        ]
        fieldnames = ADJUDICATION_FIELDS
    elif family == "reviewer_identity_rows.csv":
        rows = [
            {
                "assignment_id": chunk["assignment_id"],
                "reviewer_id": reviewer_id,
                "reviewer_slot_id": chunk["reviewer_slot_id"],
                "system_id": chunk["system_id"],
                "review_scope": chunk["review_scope"],
                "independence_declared": "fixture-only",
                "credential_statement_sha256": sha256_text(f"v61ec:{chunk_id}:identity:{generated_at}"),
            }
        ]
        fieldnames = IDENTITY_FIELDS
    elif family == "reviewer_conflict_rows.csv":
        repos = (repos_by_chunk.get(chunk_id) or DEFAULT_REPOS)[:10]
        while len(repos) < 10:
            repos.append(DEFAULT_REPOS[len(repos) % len(DEFAULT_REPOS)])
        rows = [
            {
                "assignment_id": chunk["assignment_id"],
                "reviewer_id": reviewer_id,
                "owner_repo": repo,
                "conflict_declared": "fixture-only",
                "conflict_statement_sha256": sha256_text(f"v61ec:{chunk_id}:{repo}:conflict:{generated_at}"),
            }
            for repo in repos[:10]
        ]
        fieldnames = CONFLICT_FIELDS
    else:
        raise SystemExit(f"unknown v61ec artifact family: {family}")

    if len(rows) != expected_rows:
        raise SystemExit(f"v61ec fixture row count mismatch for {rel}: expected {expected_rows}, got {len(rows)}")
    write_csv(path, fieldnames, rows)
    aggregate_rows[family].extend(rows)
    fixture_artifact_rows.append(
        {
            "review_chunk_id": chunk_id,
            "return_artifact": rel,
            "artifact_family": family,
            "expected_rows": str(expected_rows),
            "fixture_rows": str(len(rows)),
            "fixture_sha256": sha256(path),
            "fixture_only": "1",
            "real_external_review_return": "0",
        }
    )

aggregate_fieldnames = {
    "human_review_rows.csv": HUMAN_FIELDS,
    "adjudication_rows.csv": ADJUDICATION_FIELDS,
    "reviewer_identity_rows.csv": IDENTITY_FIELDS,
    "reviewer_conflict_rows.csv": CONFLICT_FIELDS,
}
aggregate_fixture_rows = []
for aggregate in aggregate_artifacts:
    artifact_name = aggregate["aggregate_artifact"]
    expected_rows = int(aggregate["expected_rows"])
    path = fixture_dir / artifact_name
    if artifact_name.endswith(".csv"):
        rows = aggregate_rows[artifact_name]
        if len(rows) != expected_rows:
            raise SystemExit(f"v61ec aggregate row count mismatch for {artifact_name}: expected {expected_rows}, got {len(rows)}")
        write_csv(path, aggregate_fieldnames[artifact_name], rows)
        observed_rows = len(rows)
    elif artifact_name == "acceptance_summary.json":
        payload = {
            "review_protocol_version": "v61ec-fixture-shape-only",
            "acceptance_decision": "fixture-only-not-real-human-review",
            "expected_human_review_rows": "7000",
            "accepted_human_review_rows": "7000",
            "human_review_rows_sha256": sha256(fixture_dir / "human_review_rows.csv"),
            "expected_adjudication_rows": "1000",
            "accepted_adjudication_rows": "1000",
            "adjudication_rows_sha256": sha256(fixture_dir / "adjudication_rows.csv"),
            "expected_reviewer_identity_rows": "21",
            "accepted_reviewer_identity_rows": "21",
            "reviewer_identity_rows_sha256": sha256(fixture_dir / "reviewer_identity_rows.csv"),
            "expected_conflict_disclosure_rows": "210",
            "accepted_conflict_disclosure_rows": "210",
            "reviewer_conflict_rows_sha256": sha256(fixture_dir / "reviewer_conflict_rows.csv"),
            "fixture_only": True,
            "real_external_review_return": False,
            "generated_at_utc": generated_at,
        }
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        observed_rows = 1
    else:
        raise SystemExit(f"unknown v61ec aggregate artifact: {artifact_name}")
    aggregate_fixture_rows.append(
        {
            "aggregate_artifact": artifact_name,
            "source_chunk_artifact_family": aggregate["source_chunk_artifact_family"],
            "expected_rows": str(expected_rows),
            "fixture_rows": str(observed_rows),
            "fixture_sha256": sha256(path),
            "fixture_only": "1",
            "real_external_review_return": "0",
        }
    )

write_csv(run_dir / "review_chunk_return_fixture_artifact_rows.csv", list(fixture_artifact_rows[0].keys()), fixture_artifact_rows)
write_csv(run_dir / "review_chunk_return_fixture_aggregate_rows.csv", list(aggregate_fixture_rows[0].keys()), aggregate_fixture_rows)
write_csv(fixture_dir / "REVIEW_CHUNK_RETURN_FIXTURE_ARTIFACT_ROWS.csv", list(fixture_artifact_rows[0].keys()), fixture_artifact_rows)
write_csv(fixture_dir / "REVIEW_CHUNK_RETURN_FIXTURE_AGGREGATE_ROWS.csv", list(aggregate_fixture_rows[0].keys()), aggregate_fixture_rows)

fixture_files = sorted(path for path in fixture_dir.rglob("*") if path.is_file())
fixture_file_rows = [
    {
        "fixture_relative_path": str(path.relative_to(fixture_dir)),
        "size_bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "payload_class": "synthetic-review-return-fixture",
        "fixture_only": "1",
        "real_external_review_return": "0",
    }
    for path in fixture_files
]
write_csv(run_dir / "review_chunk_return_fixture_file_rows.csv", list(fixture_file_rows[0].keys()), fixture_file_rows)

(fixture_dir / "README.md").write_text(
    "# v61ec Review Chunk Return Fixture\n\n"
    "These files are synthetic fixture returns. They prove the v53x review "
    "chunk-return intake can accept the expected 50 chunk artifacts plus the "
    "five aggregate v53s artifacts. They are not real human/source review "
    "judgments, not real adjudication, and not release evidence.\n",
    encoding="utf-8",
)
PY

V53X_REVIEW_CHUNK_RETURN_DIR="$FIXTURE_DIR" \
V53X_RUN_ID="$FIXTURE_V53X_RUN_ID" \
V53X_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null

mkdir -p "$RUN_DIR/source_v53x_fixture"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_summary.csv" "$RUN_DIR/source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_summary.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_decision.csv" "$RUN_DIR/source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_decision.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/$FIXTURE_V53X_RUN_ID/review_return_chunk_artifact_status_rows.csv" "$RUN_DIR/source_v53x_fixture/review_return_chunk_artifact_status_rows.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/$FIXTURE_V53X_RUN_ID/review_return_chunk_status_rows.csv" "$RUN_DIR/source_v53x_fixture/review_return_chunk_status_rows.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/$FIXTURE_V53X_RUN_ID/review_return_aggregate_artifact_status_rows.csv" "$RUN_DIR/source_v53x_fixture/review_return_aggregate_artifact_status_rows.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/$FIXTURE_V53X_RUN_ID/runtime_gap_rows.csv" "$RUN_DIR/source_v53x_fixture/runtime_gap_rows.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/$FIXTURE_V53X_RUN_ID/sha256_manifest.csv" "$RUN_DIR/source_v53x_fixture/sha256_manifest.csv"

V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$FIXTURE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
fixture_dir = Path(sys.argv[5])
results = root / "results"
bundle_dir = run_dir / "review_chunk_return_fixture_acceptance_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy_bundle(src, rel):
    dst = bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(src.read_bytes())


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61eb_summary": results / "v61eb_dispatch_receipt_fixture_acceptance_gate_summary.csv",
    "v61ea_summary": results / "v61ea_external_review_dispatch_seal_gate_summary.csv",
    "fixture_artifacts": run_dir / "review_chunk_return_fixture_artifact_rows.csv",
    "fixture_aggregates": run_dir / "review_chunk_return_fixture_aggregate_rows.csv",
    "fixture_files": run_dir / "review_chunk_return_fixture_file_rows.csv",
    "fixture_summary": run_dir / "source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "fixture_decision": run_dir / "source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_decision.csv",
    "fixture_chunk_status": run_dir / "source_v53x_fixture/review_return_chunk_artifact_status_rows.csv",
    "fixture_chunk_ready": run_dir / "source_v53x_fixture/review_return_chunk_status_rows.csv",
    "fixture_aggregate_status": run_dir / "source_v53x_fixture/review_return_aggregate_artifact_status_rows.csv",
    "default_summary": results / "v53x_complete_source_review_chunk_return_intake_summary.csv",
    "default_chunk_status": results / "v53x_complete_source_review_chunk_return_intake/intake_001/review_return_chunk_artifact_status_rows.csv",
    "default_aggregate_status": results / "v53x_complete_source_review_chunk_return_intake/intake_001/review_return_aggregate_artifact_status_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ec aggregate source {key}: {path}")

v61eb = read_csv(sources["v61eb_summary"])[0]
v61ea = read_csv(sources["v61ea_summary"])[0]
fixture_artifacts = read_csv(sources["fixture_artifacts"])
fixture_aggregates = read_csv(sources["fixture_aggregates"])
fixture_file_rows = read_csv(sources["fixture_files"])
fixture_summary = read_csv(sources["fixture_summary"])[0]
fixture_chunk_status = read_csv(sources["fixture_chunk_status"])
fixture_chunk_ready = read_csv(sources["fixture_chunk_ready"])
fixture_aggregate_status = read_csv(sources["fixture_aggregate_status"])
default_summary = read_csv(sources["default_summary"])[0]
default_chunk_status = read_csv(sources["default_chunk_status"])
default_aggregate_status = read_csv(sources["default_aggregate_status"])

if fixture_summary["accepted_chunk_return_artifact_rows"] != "50":
    raise SystemExit("v61ec fixture v53x run did not accept all chunk artifacts")
if fixture_summary["accepted_aggregate_review_return_artifact_rows"] != "5":
    raise SystemExit("v61ec fixture v53x run did not accept all aggregate artifacts")
if fixture_summary["v53s_refresh_ready"] != "1":
    raise SystemExit("v61ec fixture v53x run did not reach v53s_refresh_ready=1")
if default_summary["accepted_chunk_return_artifact_rows"] != "0":
    raise SystemExit("v61ec canonical v53x default was not restored")

fixture_acceptance_rows = []
for row in fixture_chunk_status:
    fixture_acceptance_rows.append(
        {
            "review_chunk_id": row["review_chunk_id"],
            "return_artifact": row["return_artifact"],
            "artifact_family": row["artifact_family"],
            "expected_rows": row["expected_rows"],
            "observed_rows": row["observed_rows"],
            "accepted_rows": row["accepted_rows"],
            "current_status": row["current_status"],
            "fixture_only": "1",
            "real_external_review_return": "0",
            "missing_required_fields": row["missing_required_fields"],
        }
    )
write_csv(run_dir / "review_chunk_return_fixture_acceptance_rows.csv", list(fixture_acceptance_rows[0].keys()), fixture_acceptance_rows)

fixture_aggregate_acceptance_rows = []
for row in fixture_aggregate_status:
    fixture_aggregate_acceptance_rows.append(
        {
            "aggregate_artifact": row["aggregate_artifact"],
            "source_chunk_artifact_family": row["source_chunk_artifact_family"],
            "expected_rows": row["expected_rows"],
            "observed_rows": row["observed_rows"],
            "accepted_rows": row["accepted_rows"],
            "current_status": row["current_status"],
            "fixture_only": "1",
            "real_external_review_return": "0",
            "missing_required_fields": row["missing_required_fields"],
        }
    )
write_csv(run_dir / "review_chunk_return_fixture_aggregate_acceptance_rows.csv", list(fixture_aggregate_acceptance_rows[0].keys()), fixture_aggregate_acceptance_rows)

canonical_restore_rows = [
    {
        "restore_id": "v61ec-restore-v53x-canonical-no-review-return",
        "status": "pass" if default_summary["accepted_chunk_return_artifact_rows"] == "0" and default_summary["missing_chunk_return_artifact_rows"] == "50" else "fail",
        "canonical_supplied_chunk_return_artifact_rows": default_summary["supplied_chunk_return_artifact_rows"],
        "canonical_accepted_chunk_return_artifact_rows": default_summary["accepted_chunk_return_artifact_rows"],
        "canonical_missing_chunk_return_artifact_rows": default_summary["missing_chunk_return_artifact_rows"],
        "canonical_accepted_aggregate_review_return_artifact_rows": default_summary["accepted_aggregate_review_return_artifact_rows"],
        "canonical_missing_aggregate_review_return_artifact_rows": default_summary["missing_aggregate_review_return_artifact_rows"],
        "canonical_chunk_return_intake_ready": default_summary["chunk_return_intake_ready"],
        "canonical_v53s_refresh_ready": default_summary["v53s_refresh_ready"],
    }
]
write_csv(run_dir / "review_chunk_return_fixture_canonical_restore_rows.csv", list(canonical_restore_rows[0].keys()), canonical_restore_rows)

stage_rows = [
    {"stage_id": "01-bind-v61eb-receipt-fixture-gate", "status": "ready", "ready": "1", "evidence": "v61eb fixture dispatch receipt gate is ready"},
    {"stage_id": "02-generate-50-chunk-return-fixtures", "status": "ready", "ready": "1", "evidence": "50 synthetic chunk return CSV files generated"},
    {"stage_id": "03-generate-5-aggregate-return-fixtures", "status": "ready", "ready": "1", "evidence": "five aggregate v53s fixture artifacts generated"},
    {"stage_id": "04-run-v53x-fixture-intake", "status": "ready", "ready": "1", "evidence": "fixture v53x intake accepts 50/50 chunk artifacts"},
    {"stage_id": "05-prove-v53s-refresh-shape-ready", "status": "ready", "ready": "1", "evidence": "fixture v53x reports v53s_refresh_ready=1"},
    {"stage_id": "06-restore-canonical-no-review-return", "status": "ready", "ready": "1", "evidence": "canonical v53x default summary restored to zero accepted artifacts"},
    {"stage_id": "07-real-review-return-received", "status": "blocked", "ready": "0", "evidence": "real_external_review_chunk_return_rows=0"},
    {"stage_id": "08-actual-generation-after-review", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "review_chunk_return_fixture_acceptance_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

fixture_chunk_file_count = sum(1 for row in fixture_file_rows if row["fixture_relative_path"].startswith("chunks/"))
fixture_aggregate_file_count = sum(
    1
    for row in fixture_file_rows
    if row["fixture_relative_path"] in {
        "human_review_rows.csv",
        "adjudication_rows.csv",
        "reviewer_identity_rows.csv",
        "reviewer_conflict_rows.csv",
        "acceptance_summary.json",
    }
)

invariant_rows = [
    {"invariant_id": "v61eb-receipt-fixture-ready", "status": "pass" if v61eb["v61eb_dispatch_receipt_fixture_acceptance_gate_ready"] == "1" else "fail", "expected": "v61eb ready", "actual": v61eb["v61eb_dispatch_receipt_fixture_acceptance_gate_ready"]},
    {"invariant_id": "fixture-chunk-artifact-files-generated", "status": "pass" if fixture_chunk_file_count == 50 else "fail", "expected": "50 chunk fixture files", "actual": str(fixture_chunk_file_count)},
    {"invariant_id": "fixture-aggregate-artifact-files-generated", "status": "pass" if fixture_aggregate_file_count == 5 else "fail", "expected": "5 aggregate fixture files", "actual": str(fixture_aggregate_file_count)},
    {"invariant_id": "fixture-v53x-accepts-all-chunk-artifacts", "status": "pass" if fixture_summary["accepted_chunk_return_artifact_rows"] == "50" and fixture_summary["ready_review_chunk_return_rows"] == "21" else "fail", "expected": "50 accepted artifacts and 21 ready chunks", "actual": f"{fixture_summary['accepted_chunk_return_artifact_rows']}/{fixture_summary['review_chunk_return_artifact_rows']};chunks={fixture_summary['ready_review_chunk_return_rows']}"},
    {"invariant_id": "fixture-v53x-accepts-all-aggregate-artifacts", "status": "pass" if fixture_summary["accepted_aggregate_review_return_artifact_rows"] == "5" and fixture_summary["v53s_refresh_ready"] == "1" else "fail", "expected": "5 accepted aggregate artifacts and v53s_refresh_ready=1", "actual": f"{fixture_summary['accepted_aggregate_review_return_artifact_rows']}/{fixture_summary['aggregate_review_return_artifact_rows']};v53s={fixture_summary['v53s_refresh_ready']}"},
    {"invariant_id": "fixture-row-totals-match-v53w", "status": "pass" if fixture_summary["accepted_human_review_rows"] == "7000" and fixture_summary["accepted_adjudication_rows"] == "1000" and fixture_summary["accepted_reviewer_identity_rows"] == "21" and fixture_summary["accepted_conflict_disclosure_rows"] == "210" else "fail", "expected": "7000/1000/21/210 fixture rows", "actual": f"human={fixture_summary['accepted_human_review_rows']};adj={fixture_summary['accepted_adjudication_rows']};identity={fixture_summary['accepted_reviewer_identity_rows']};conflict={fixture_summary['accepted_conflict_disclosure_rows']}"},
    {"invariant_id": "canonical-default-restored", "status": canonical_restore_rows[0]["status"], "expected": "0 accepted canonical chunk artifacts", "actual": f"{default_summary['accepted_chunk_return_artifact_rows']}/{default_summary['review_chunk_return_artifact_rows']}"},
    {"invariant_id": "fixture-not-real-external-evidence", "status": "pass" if all(row["real_external_review_return"] == "0" for row in fixture_artifacts + fixture_aggregates) else "fail", "expected": "all fixture rows real_external_review_return=0", "actual": str(sum(row["real_external_review_return"] == "0" for row in fixture_artifacts + fixture_aggregates))},
    {"invariant_id": "real-review-return-still-blocked", "status": "pass" if v61ea["accepted_human_review_rows"] == "0" and v61ea["accepted_adjudication_rows"] == "0" else "fail", "expected": "real accepted review rows remain zero", "actual": f"human={v61ea['accepted_human_review_rows']};adjudication={v61ea['accepted_adjudication_rows']}"},
    {"invariant_id": "generation-still-blocked", "status": "pass" if v61ea["generation_execution_admitted_rows"] == "0" and v61ea["actual_model_generation_ready"] == "0" else "fail", "expected": "generation remains blocked", "actual": f"generation={v61ea['generation_execution_admitted_rows']};actual={v61ea['actual_model_generation_ready']}"},
    {"invariant_id": "repo-checkpoint-payload-zero", "status": "pass" if v61ea["checkpoint_payload_bytes_committed_to_repo"] == "0" else "fail", "expected": "repo checkpoint payload is zero", "actual": v61ea["checkpoint_payload_bytes_committed_to_repo"]},
]
write_csv(run_dir / "review_chunk_return_fixture_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

runtime_gap_rows = [
    {"gap": "fixture-review-chunk-return-intake", "status": "ready", "reason": "fixture v53x intake accepted 50/50 chunk artifacts"},
    {"gap": "fixture-v53s-refresh-shape", "status": "ready", "reason": "fixture v53x reports v53s_refresh_ready=1"},
    {"gap": "real-review-chunk-returns", "status": "blocked", "reason": "real_external_review_chunk_return_rows=0"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"accepted_human_review_rows={v61ea['accepted_human_review_rows']}/{v61ea['expected_human_review_rows']}"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61ea['generation_execution_admitted_rows']}/{v61ea['generation_execution_admission_rows']}"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61ea['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

bundle_readme = bundle_dir / "README.md"
bundle_readme.write_text(
    "# v61ec Review Chunk Return Fixture Acceptance Gate\n\n"
    "This bundle proves that the v53x review chunk-return intake can accept a "
    "complete synthetic fixture: 50 chunk artifacts plus five aggregate v53s "
    "artifacts. It is shape and routing evidence only. It does not count as "
    "real external human review, real adjudication, v53 readiness, actual "
    "generation evidence, or release evidence.\n",
    encoding="utf-8",
)
copy_bundle(run_dir / "review_chunk_return_fixture_artifact_rows.csv", "REVIEW_CHUNK_RETURN_FIXTURE_ARTIFACT_ROWS.csv")
copy_bundle(run_dir / "review_chunk_return_fixture_acceptance_rows.csv", "REVIEW_CHUNK_RETURN_FIXTURE_ACCEPTANCE_ROWS.csv")
copy_bundle(run_dir / "review_chunk_return_fixture_aggregate_rows.csv", "REVIEW_CHUNK_RETURN_FIXTURE_AGGREGATE_ROWS.csv")
copy_bundle(run_dir / "review_chunk_return_fixture_aggregate_acceptance_rows.csv", "REVIEW_CHUNK_RETURN_FIXTURE_AGGREGATE_ACCEPTANCE_ROWS.csv")
copy_bundle(run_dir / "review_chunk_return_fixture_canonical_restore_rows.csv", "CANONICAL_RESTORE_ROWS.csv")
copy_bundle(run_dir / "review_chunk_return_fixture_acceptance_stage_rows.csv", "FIXTURE_ACCEPTANCE_STAGES.csv")
copy_bundle(run_dir / "review_chunk_return_fixture_invariant_rows.csv", "FIXTURE_ACCEPTANCE_INVARIANTS.csv")

verify_script = bundle_dir / "VERIFY_V61EC_FIXTURE_ACCEPTANCE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
            'RUN_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"',
            "export RUN_DIR",
            'test -s "$BUNDLE_DIR/REVIEW_CHUNK_RETURN_FIXTURE_ARTIFACT_ROWS.csv"',
            'test -s "$BUNDLE_DIR/REVIEW_CHUNK_RETURN_FIXTURE_ACCEPTANCE_ROWS.csv"',
            'test -s "$BUNDLE_DIR/REVIEW_CHUNK_RETURN_FIXTURE_AGGREGATE_ROWS.csv"',
            'test -s "$BUNDLE_DIR/CANONICAL_RESTORE_ROWS.csv"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import os",
            "from pathlib import Path",
            "run_dir = Path(os.environ['RUN_DIR'])",
            "def read_csv(path):",
            "    with path.open(newline='', encoding='utf-8') as handle:",
            "        return list(csv.DictReader(handle))",
            "summary = read_csv(run_dir.parent.parent / 'v61ec_review_chunk_return_fixture_acceptance_gate_summary.csv')[0]",
            "if summary['fixture_accepted_chunk_return_artifact_rows'] != '50':",
            "    raise SystemExit('fixture chunk returns were not accepted')",
            "if summary['fixture_accepted_aggregate_review_return_artifact_rows'] != '5':",
            "    raise SystemExit('fixture aggregate returns were not accepted')",
            "if summary['canonical_default_accepted_chunk_return_artifact_rows'] != '0':",
            "    raise SystemExit('canonical default v53x state was not restored')",
            "if summary['real_external_review_chunk_return_rows'] != '0':",
            "    raise SystemExit('fixture must not count as real external review return')",
            "if summary['actual_model_generation_ready'] != '0':",
            "    raise SystemExit('actual generation must remain blocked')",
            "PY_VERIFY",
            'if find "$RUN_DIR" -type f \\( -name "*.safetensors" -o -name "*.bin" -o -name "*.pt" \\) | grep -q .; then',
            '  echo "model/checkpoint payload-like file found inside v61ec fixture gate" >&2',
            "  exit 1",
            "fi",
            "echo 'v61ec fixture acceptance verified'",
        ]
    )
    + "\n",
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_manifest = {
    "manifest_scope": "v61ec-review-chunk-return-fixture-acceptance-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "fixture_chunk_return_artifact_rows": len(fixture_artifacts),
    "fixture_accepted_chunk_return_artifact_rows": as_int(fixture_summary, "accepted_chunk_return_artifact_rows"),
    "fixture_accepted_aggregate_review_return_artifact_rows": as_int(fixture_summary, "accepted_aggregate_review_return_artifact_rows"),
    "fixture_v53s_refresh_ready": as_int(fixture_summary, "v53s_refresh_ready"),
    "canonical_default_accepted_chunk_return_artifact_rows": as_int(default_summary, "accepted_chunk_return_artifact_rows"),
    "real_external_review_chunk_return_rows": 0,
    "actual_model_generation_ready": as_int(v61ea, "actual_model_generation_ready"),
}
(bundle_dir / "FIXTURE_ACCEPTANCE_MANIFEST.json").write_text(
    json.dumps(bundle_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

bundle_files = sorted(path for path in bundle_dir.rglob("*") if path.is_file())
bundle_file_rows = [
    {
        "bundle_relative_path": str(path.relative_to(bundle_dir)),
        "size_bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "payload_class": "metadata-only",
    }
    for path in bundle_files
]
write_csv(run_dir / "review_chunk_return_fixture_acceptance_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

ready_stage_rows = sum(1 for row in stage_rows if row["status"] == "ready")
blocked_stage_rows = sum(1 for row in stage_rows if row["status"] == "blocked")
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

summary_row = {
    "v61ec_review_chunk_return_fixture_acceptance_gate_ready": "1",
    "v61eb_dispatch_receipt_fixture_acceptance_gate_ready": v61eb["v61eb_dispatch_receipt_fixture_acceptance_gate_ready"],
    "fixture_stage_rows": str(len(stage_rows)),
    "ready_fixture_stage_rows": str(ready_stage_rows),
    "blocked_fixture_stage_rows": str(blocked_stage_rows),
    "fixture_chunk_return_artifact_rows": str(len(fixture_artifacts)),
    "fixture_chunk_return_file_rows": str(fixture_chunk_file_count),
    "fixture_aggregate_review_return_artifact_rows": str(len(fixture_aggregates)),
    "fixture_aggregate_review_return_file_rows": str(fixture_aggregate_file_count),
    "fixture_file_rows": str(fixture_chunk_file_count + fixture_aggregate_file_count),
    "fixture_supplied_chunk_return_artifact_rows": fixture_summary["supplied_chunk_return_artifact_rows"],
    "fixture_accepted_chunk_return_artifact_rows": fixture_summary["accepted_chunk_return_artifact_rows"],
    "fixture_missing_chunk_return_artifact_rows": fixture_summary["missing_chunk_return_artifact_rows"],
    "fixture_invalid_chunk_return_artifact_rows": fixture_summary["invalid_chunk_return_artifact_rows"],
    "fixture_ready_review_chunk_return_rows": fixture_summary["ready_review_chunk_return_rows"],
    "fixture_expected_human_review_rows": fixture_summary["expected_human_review_rows"],
    "fixture_accepted_human_review_rows": fixture_summary["accepted_human_review_rows"],
    "fixture_expected_adjudication_rows": fixture_summary["expected_adjudication_rows"],
    "fixture_accepted_adjudication_rows": fixture_summary["accepted_adjudication_rows"],
    "fixture_expected_reviewer_identity_rows": fixture_summary["expected_reviewer_identity_rows"],
    "fixture_accepted_reviewer_identity_rows": fixture_summary["accepted_reviewer_identity_rows"],
    "fixture_expected_conflict_disclosure_rows": fixture_summary["expected_conflict_disclosure_rows"],
    "fixture_accepted_conflict_disclosure_rows": fixture_summary["accepted_conflict_disclosure_rows"],
    "fixture_supplied_aggregate_review_return_artifact_rows": fixture_summary["supplied_aggregate_review_return_artifact_rows"],
    "fixture_accepted_aggregate_review_return_artifact_rows": fixture_summary["accepted_aggregate_review_return_artifact_rows"],
    "fixture_missing_aggregate_review_return_artifact_rows": fixture_summary["missing_aggregate_review_return_artifact_rows"],
    "fixture_invalid_aggregate_review_return_artifact_rows": fixture_summary["invalid_aggregate_review_return_artifact_rows"],
    "fixture_chunk_return_intake_ready": fixture_summary["chunk_return_intake_ready"],
    "fixture_aggregate_review_return_ready": fixture_summary["aggregate_review_return_ready"],
    "fixture_v53s_refresh_ready": fixture_summary["v53s_refresh_ready"],
    "canonical_default_supplied_chunk_return_artifact_rows": default_summary["supplied_chunk_return_artifact_rows"],
    "canonical_default_accepted_chunk_return_artifact_rows": default_summary["accepted_chunk_return_artifact_rows"],
    "canonical_default_missing_chunk_return_artifact_rows": default_summary["missing_chunk_return_artifact_rows"],
    "canonical_default_accepted_aggregate_review_return_artifact_rows": default_summary["accepted_aggregate_review_return_artifact_rows"],
    "canonical_default_missing_aggregate_review_return_artifact_rows": default_summary["missing_aggregate_review_return_artifact_rows"],
    "canonical_default_chunk_return_intake_ready": default_summary["chunk_return_intake_ready"],
    "canonical_default_v53s_refresh_ready": default_summary["v53s_refresh_ready"],
    "real_external_review_chunk_return_rows": "0",
    "real_external_human_review_rows": "0",
    "real_external_adjudication_rows": "0",
    "expected_human_review_rows": v61ea["expected_human_review_rows"],
    "accepted_human_review_rows": v61ea["accepted_human_review_rows"],
    "expected_adjudication_rows": v61ea["expected_adjudication_rows"],
    "accepted_adjudication_rows": v61ea["accepted_adjudication_rows"],
    "generation_execution_admitted_rows": v61ea["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61ea["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61ea["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v61ea["actual_model_generation_ready"],
    "fixture_invariant_rows": str(len(invariant_rows)),
    "fixture_invariant_pass_rows": str(invariant_pass_rows),
    "fixture_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_fixture_bundle_file_rows": str(sum(1 for row in bundle_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61ec": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "v61eb-receipt-fixture-gate", "status": "pass", "reason": "v61eb fixture dispatch receipt gate is ready"},
    {"gate": "fixture-review-chunk-return-generation", "status": "pass", "reason": "50 chunk artifacts and five aggregate artifacts generated"},
    {"gate": "fixture-v53x-review-chunk-intake", "status": "pass", "reason": "v53x fixture intake accepted 50/50 chunk artifacts"},
    {"gate": "fixture-v53s-refresh-shape", "status": "pass", "reason": "fixture v53x reports v53s_refresh_ready=1"},
    {"gate": "canonical-default-restore", "status": canonical_restore_rows[0]["status"], "reason": "canonical v53x default no-return state restored"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "no checkpoint/model payload committed"},
    {"gate": "real-review-chunk-returns", "status": "blocked", "reason": "real_external_review_chunk_return_rows=0"},
    {"gate": "real-review-return-accepted", "status": "blocked", "reason": "fixture rows are not real v53s/v53v review acceptance"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": "generation execution remains blocked"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual model generation remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ec Review Chunk Return Fixture Acceptance Gate Boundary

This gate proves the review chunk-return intake mechanics, not real review
completion. It generates a synthetic fixture with the exact v53w return shape,
runs v53x against that fixture, copies the fixture acceptance evidence, and
then restores the canonical v53x default no-return state.

Evidence emitted:

- fixture_chunk_return_artifact_rows={len(fixture_artifacts)}
- fixture_accepted_chunk_return_artifact_rows={fixture_summary['accepted_chunk_return_artifact_rows']}/50
- fixture_ready_review_chunk_return_rows={fixture_summary['ready_review_chunk_return_rows']}/21
- fixture_accepted_human_review_rows={fixture_summary['accepted_human_review_rows']}/7000
- fixture_accepted_adjudication_rows={fixture_summary['accepted_adjudication_rows']}/1000
- fixture_accepted_reviewer_identity_rows={fixture_summary['accepted_reviewer_identity_rows']}/21
- fixture_accepted_conflict_disclosure_rows={fixture_summary['accepted_conflict_disclosure_rows']}/210
- fixture_accepted_aggregate_review_return_artifact_rows={fixture_summary['accepted_aggregate_review_return_artifact_rows']}/5
- fixture_v53s_refresh_ready={fixture_summary['v53s_refresh_ready']}
- canonical_default_accepted_chunk_return_artifact_rows={default_summary['accepted_chunk_return_artifact_rows']}
- canonical_default_missing_chunk_return_artifact_rows={default_summary['missing_chunk_return_artifact_rows']}
- real_external_review_chunk_return_rows=0
- accepted_human_review_rows={v61ea['accepted_human_review_rows']}/{v61ea['expected_human_review_rows']}
- accepted_adjudication_rows={v61ea['accepted_adjudication_rows']}/{v61ea['expected_adjudication_rows']}
- generation_execution_admitted_rows={v61ea['generation_execution_admitted_rows']}/{v61ea['generation_execution_admission_rows']}
- actual_model_generation_ready={v61ea['actual_model_generation_ready']}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: v53x review chunk-return intake mechanics accept a complete
synthetic 50+5 artifact fixture and the canonical no-return state is restored.

Blocked wording: real external review return received, accepted human/source
review, accepted adjudication, v53 readiness, v1.0 comparison readiness,
actual generation, production latency, or release readiness.
"""
(run_dir / "V61EC_REVIEW_CHUNK_RETURN_FIXTURE_ACCEPTANCE_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61ec-review-chunk-return-fixture-acceptance-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ec_review_chunk_return_fixture_acceptance_gate_ready": 1,
    "fixture_chunk_return_artifact_rows": len(fixture_artifacts),
    "fixture_accepted_chunk_return_artifact_rows": as_int(fixture_summary, "accepted_chunk_return_artifact_rows"),
    "fixture_accepted_aggregate_review_return_artifact_rows": as_int(fixture_summary, "accepted_aggregate_review_return_artifact_rows"),
    "fixture_v53s_refresh_ready": as_int(fixture_summary, "v53s_refresh_ready"),
    "canonical_default_accepted_chunk_return_artifact_rows": as_int(default_summary, "accepted_chunk_return_artifact_rows"),
    "real_external_review_chunk_return_rows": 0,
    "accepted_human_review_rows": as_int(v61ea, "accepted_human_review_rows"),
    "accepted_adjudication_rows": as_int(v61ea, "accepted_adjudication_rows"),
    "actual_model_generation_ready": as_int(v61ea, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ec_review_chunk_return_fixture_acceptance_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ec_review_chunk_return_fixture_acceptance_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
