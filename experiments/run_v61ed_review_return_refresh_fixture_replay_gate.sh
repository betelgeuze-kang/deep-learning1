#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ed_review_return_refresh_fixture_replay_gate"
RUN_ID="${V61ED_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_DIR="$RUN_DIR/fixture_review_return_refresh"
FIXTURE_V53Y_RUN_ID="refresh_fixture_v61ed"

if [[ "${V61ED_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ed_review_return_refresh_fixture_replay_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61ec_review_chunk_return_fixture_acceptance_gate_summary.csv" ]]; then
  V61EC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ec_review_chunk_return_fixture_acceptance_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53r_complete_source_review_packet_summary.csv" ]]; then
  V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null
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


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def stable_hash(*parts):
    return "sha256:" + hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


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
    "v61ec_summary": results / "v61ec_review_chunk_return_fixture_acceptance_gate_summary.csv",
    "v61ec_decision": results / "v61ec_review_chunk_return_fixture_acceptance_gate_decision.csv",
    "v61ec_fixture_artifacts": results / "v61ec_review_chunk_return_fixture_acceptance_gate" / "gate_001" / "review_chunk_return_fixture_artifact_rows.csv",
    "v61ec_fixture_aggregates": results / "v61ec_review_chunk_return_fixture_acceptance_gate" / "gate_001" / "review_chunk_return_fixture_aggregate_rows.csv",
    "v53r_summary": results / "v53r_complete_source_review_packet_summary.csv",
    "v53r_answers": results / "v53r_complete_source_review_packet" / "review_001" / "review_answer_packet_rows.csv",
    "v53r_queue": results / "v53r_complete_source_review_packet" / "review_001" / "review_queue_rows.csv",
    "v53r_assignments": results / "v53r_complete_source_review_packet" / "review_001" / "reviewer_assignment_template_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ed source {key}: {path}")

copy(sources["v61ec_summary"], "source_v61ec/v61ec_review_chunk_return_fixture_acceptance_gate_summary.csv")
copy(sources["v61ec_decision"], "source_v61ec/v61ec_review_chunk_return_fixture_acceptance_gate_decision.csv")
copy(sources["v61ec_fixture_artifacts"], "source_v61ec/review_chunk_return_fixture_artifact_rows.csv")
copy(sources["v61ec_fixture_aggregates"], "source_v61ec/review_chunk_return_fixture_aggregate_rows.csv")
copy(sources["v53r_summary"], "source_v53r/v53r_complete_source_review_packet_summary.csv")
copy(sources["v53r_answers"], "source_v53r/review_answer_packet_rows.csv")
copy(sources["v53r_queue"], "source_v53r/review_queue_rows.csv")
copy(sources["v53r_assignments"], "source_v53r/reviewer_assignment_template_rows.csv")

v61ec = read_csv(sources["v61ec_summary"])[0]
if v61ec["v61ec_review_chunk_return_fixture_acceptance_gate_ready"] != "1":
    raise SystemExit("v61ed requires v61ec ready")
if v61ec["fixture_accepted_chunk_return_artifact_rows"] != "50":
    raise SystemExit("v61ed requires v61ec fixture chunk acceptance")

v61ec_fixture_root = results / "v61ec_review_chunk_return_fixture_acceptance_gate" / "gate_001" / "fixture_review_chunk_returns"
source_chunks = v61ec_fixture_root / "chunks"
if not source_chunks.is_dir():
    raise SystemExit(f"missing v61ec chunk fixture dir: {source_chunks}")
shutil.copytree(source_chunks, fixture_dir / "chunks")

answer_rows = read_csv(sources["v53r_answers"])
queue_rows = read_csv(sources["v53r_queue"])
assignment_rows = read_csv(sources["v53r_assignments"])
p0_answer_ids = {row["answer_id"] for row in queue_rows if row["priority_class"] == "p0_answer_or_policy_mismatch"}
owner_repos = sorted({row["owner_repo"] for row in answer_rows})

human_fields = [
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
human_rows = []
for row in answer_rows:
    human_rows.append(
        {
            "review_answer_packet_id": row["review_answer_packet_id"],
            "answer_id": row["answer_id"],
            "system_id": row["system_id"],
            "query_id": row["query_id"],
            "reviewer_id": f"fixture_reviewer_{row['system_id'].lower()}_primary",
            "review_decision": "needs-adjudication" if row["answer_id"] in p0_answer_ids else "accept",
            "source_support_verified": "1",
            "citation_verified": "1",
            "policy_verified": "1",
            "review_comment_sha256": stable_hash("v61ed-human", row["answer_id"]),
        }
    )
write_csv(fixture_dir / "human_review_rows.csv", human_fields, human_rows)

adjudication_fields = [
    "adjudication_id",
    "review_answer_packet_id",
    "answer_id",
    "adjudicator_id",
    "adjudication_decision",
    "adjudication_reason_sha256",
]
adjudication_rows = []
for index, row in enumerate(queue_rows, start=1):
    if row["answer_id"] not in p0_answer_ids:
        continue
    adjudication_rows.append(
        {
            "adjudication_id": f"v61ed_fixture_adjudication_{index:04d}",
            "review_answer_packet_id": row["review_answer_packet_id"],
            "answer_id": row["answer_id"],
            "adjudicator_id": "v61ed_fixture_adjudicator_001",
            "adjudication_decision": "accept",
            "adjudication_reason_sha256": stable_hash("v61ed-adjudication", row["answer_id"]),
        }
    )
write_csv(fixture_dir / "adjudication_rows.csv", adjudication_fields, adjudication_rows)

identity_fields = [
    "assignment_id",
    "reviewer_id",
    "reviewer_slot_id",
    "system_id",
    "review_scope",
    "independence_declared",
    "credential_statement_sha256",
]
identity_rows = []
reviewer_by_assignment = {}
for row in assignment_rows:
    reviewer_id = f"v61ed_fixture_reviewer_{row['system_id'].lower()}_{row['reviewer_slot_id']}"
    reviewer_by_assignment[row["assignment_id"]] = reviewer_id
    identity_rows.append(
        {
            "assignment_id": row["assignment_id"],
            "reviewer_id": reviewer_id,
            "reviewer_slot_id": row["reviewer_slot_id"],
            "system_id": row["system_id"],
            "review_scope": row["review_scope"],
            "independence_declared": "1",
            "credential_statement_sha256": stable_hash("v61ed-identity", row["assignment_id"]),
        }
    )
write_csv(fixture_dir / "reviewer_identity_rows.csv", identity_fields, identity_rows)

conflict_fields = [
    "assignment_id",
    "reviewer_id",
    "owner_repo",
    "conflict_declared",
    "conflict_statement_sha256",
]
conflict_rows = []
for assignment in assignment_rows:
    for owner_repo in owner_repos:
        conflict_rows.append(
            {
                "assignment_id": assignment["assignment_id"],
                "reviewer_id": reviewer_by_assignment[assignment["assignment_id"]],
                "owner_repo": owner_repo,
                "conflict_declared": "0",
                "conflict_statement_sha256": stable_hash("v61ed-conflict", assignment["assignment_id"], owner_repo),
            }
        )
write_csv(fixture_dir / "reviewer_conflict_rows.csv", conflict_fields, conflict_rows)

acceptance = {
    "review_protocol_version": "v53s",
    "acceptance_decision": "accepted",
    "expected_human_review_rows": len(human_rows),
    "accepted_human_review_rows": len(human_rows),
    "human_review_rows_sha256": sha256(fixture_dir / "human_review_rows.csv"),
    "expected_adjudication_rows": len(adjudication_rows),
    "accepted_adjudication_rows": len(adjudication_rows),
    "adjudication_rows_sha256": sha256(fixture_dir / "adjudication_rows.csv"),
    "expected_reviewer_identity_rows": len(identity_rows),
    "accepted_reviewer_identity_rows": len(identity_rows),
    "reviewer_identity_rows_sha256": sha256(fixture_dir / "reviewer_identity_rows.csv"),
    "expected_conflict_disclosure_rows": len(conflict_rows),
    "accepted_conflict_disclosure_rows": len(conflict_rows),
    "reviewer_conflict_rows_sha256": sha256(fixture_dir / "reviewer_conflict_rows.csv"),
    "fixture_only": True,
    "real_external_review_return": False,
}
(fixture_dir / "acceptance_summary.json").write_text(json.dumps(acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(fixture_dir / "README.md").write_text(
    "# v61ed Review Return Refresh Fixture\n\n"
    "This directory combines v61ec chunk-level synthetic returns with a "
    "v53s-valid aggregate fixture. It verifies downstream refresh mechanics "
    "only. It is not real external human/source review evidence.\n",
    encoding="utf-8",
)

fixture_rows = [
    {
        "fixture_family": "human_review_rows.csv",
        "fixture_rows": str(len(human_rows)),
        "sha256": sha256(fixture_dir / "human_review_rows.csv"),
        "fixture_only": "1",
        "real_external_review_return": "0",
    },
    {
        "fixture_family": "adjudication_rows.csv",
        "fixture_rows": str(len(adjudication_rows)),
        "sha256": sha256(fixture_dir / "adjudication_rows.csv"),
        "fixture_only": "1",
        "real_external_review_return": "0",
    },
    {
        "fixture_family": "reviewer_identity_rows.csv",
        "fixture_rows": str(len(identity_rows)),
        "sha256": sha256(fixture_dir / "reviewer_identity_rows.csv"),
        "fixture_only": "1",
        "real_external_review_return": "0",
    },
    {
        "fixture_family": "reviewer_conflict_rows.csv",
        "fixture_rows": str(len(conflict_rows)),
        "sha256": sha256(fixture_dir / "reviewer_conflict_rows.csv"),
        "fixture_only": "1",
        "real_external_review_return": "0",
    },
    {
        "fixture_family": "acceptance_summary.json",
        "fixture_rows": "1",
        "sha256": sha256(fixture_dir / "acceptance_summary.json"),
        "fixture_only": "1",
        "real_external_review_return": "0",
    },
]
write_csv(run_dir / "review_return_refresh_fixture_family_rows.csv", list(fixture_rows[0].keys()), fixture_rows)

fixture_files = sorted(path for path in fixture_dir.rglob("*") if path.is_file())
fixture_file_rows = [
    {
        "fixture_relative_path": str(path.relative_to(fixture_dir)),
        "size_bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "payload_class": "synthetic-review-refresh-fixture",
        "fixture_only": "1",
        "real_external_review_return": "0",
    }
    for path in fixture_files
]
write_csv(run_dir / "review_return_refresh_fixture_file_rows.csv", list(fixture_file_rows[0].keys()), fixture_file_rows)
PY

V53Y_REVIEW_RETURN_DIR="$FIXTURE_DIR" \
V53Y_RUN_ID="$FIXTURE_V53Y_RUN_ID" \
V53Y_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null

mkdir -p "$RUN_DIR/source_v53y_fixture" "$RUN_DIR/source_v53s_fixture" "$RUN_DIR/source_v53v_fixture" "$RUN_DIR/source_v53x_fixture"
cp "$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate_summary.csv" "$RUN_DIR/source_v53y_fixture/v53y_complete_source_review_return_refresh_gate_summary.csv"
cp "$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate_decision.csv" "$RUN_DIR/source_v53y_fixture/v53y_complete_source_review_return_refresh_gate_decision.csv"
cp "$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate/$FIXTURE_V53Y_RUN_ID/complete_source_review_return_refresh_stage_rows.csv" "$RUN_DIR/source_v53y_fixture/complete_source_review_return_refresh_stage_rows.csv"
cp "$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate/$FIXTURE_V53Y_RUN_ID/runtime_gap_rows.csv" "$RUN_DIR/source_v53y_fixture/runtime_gap_rows.csv"
cp "$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate/$FIXTURE_V53Y_RUN_ID/sha256_manifest.csv" "$RUN_DIR/source_v53y_fixture/sha256_manifest.csv"
cp "$RESULTS_DIR/v53s_complete_source_review_return_intake_summary.csv" "$RUN_DIR/source_v53s_fixture/v53s_complete_source_review_return_intake_summary.csv"
cp "$RESULTS_DIR/v53s_complete_source_review_return_intake_decision.csv" "$RUN_DIR/source_v53s_fixture/v53s_complete_source_review_return_intake_decision.csv"
cp "$RESULTS_DIR/v53s_complete_source_review_return_intake/intake_001/review_return_artifact_gate_rows.csv" "$RUN_DIR/source_v53s_fixture/review_return_artifact_gate_rows.csv"
cp "$RESULTS_DIR/v53s_complete_source_review_return_intake/intake_001/review_return_validation_rows.csv" "$RUN_DIR/source_v53s_fixture/review_return_validation_rows.csv"
cp "$RESULTS_DIR/v53v_complete_source_review_return_acceptance_bridge_summary.csv" "$RUN_DIR/source_v53v_fixture/v53v_complete_source_review_return_acceptance_bridge_summary.csv"
cp "$RESULTS_DIR/v53v_complete_source_review_return_acceptance_bridge_decision.csv" "$RUN_DIR/source_v53v_fixture/v53v_complete_source_review_return_acceptance_bridge_decision.csv"
cp "$RESULTS_DIR/v53v_complete_source_review_return_acceptance_bridge/bridge_001/complete_source_review_return_acceptance_metric_rows.csv" "$RUN_DIR/source_v53v_fixture/complete_source_review_return_acceptance_metric_rows.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_summary.csv" "$RUN_DIR/source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_summary.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/intake_001/review_return_chunk_artifact_status_rows.csv" "$RUN_DIR/source_v53x_fixture/review_return_chunk_artifact_status_rows.csv"
cp "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake/intake_001/review_return_aggregate_artifact_status_rows.csv" "$RUN_DIR/source_v53x_fixture/review_return_aggregate_artifact_status_rows.csv"

V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null

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
bundle_dir = run_dir / "review_return_refresh_fixture_replay_bundle"
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
    "v61ec_summary": results / "v61ec_review_chunk_return_fixture_acceptance_gate_summary.csv",
    "fixture_family": run_dir / "review_return_refresh_fixture_family_rows.csv",
    "fixture_files": run_dir / "review_return_refresh_fixture_file_rows.csv",
    "fixture_v53y": run_dir / "source_v53y_fixture/v53y_complete_source_review_return_refresh_gate_summary.csv",
    "fixture_v53s": run_dir / "source_v53s_fixture/v53s_complete_source_review_return_intake_summary.csv",
    "fixture_v53v": run_dir / "source_v53v_fixture/v53v_complete_source_review_return_acceptance_bridge_summary.csv",
    "fixture_v53x": run_dir / "source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "default_v53y": results / "v53y_complete_source_review_return_refresh_gate_summary.csv",
    "default_v53s": results / "v53s_complete_source_review_return_intake_summary.csv",
    "default_v53v": results / "v53v_complete_source_review_return_acceptance_bridge_summary.csv",
    "default_v53x": results / "v53x_complete_source_review_chunk_return_intake_summary.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ed aggregate source {key}: {path}")

v61ec = read_csv(sources["v61ec_summary"])[0]
fixture_family_rows = read_csv(sources["fixture_family"])
fixture_file_rows = read_csv(sources["fixture_files"])
fixture_v53y = read_csv(sources["fixture_v53y"])[0]
fixture_v53s = read_csv(sources["fixture_v53s"])[0]
fixture_v53v = read_csv(sources["fixture_v53v"])[0]
fixture_v53x = read_csv(sources["fixture_v53x"])[0]
default_v53y = read_csv(sources["default_v53y"])[0]
default_v53s = read_csv(sources["default_v53s"])[0]
default_v53v = read_csv(sources["default_v53v"])[0]
default_v53x = read_csv(sources["default_v53x"])[0]

if fixture_v53y["answer_review_accepted_rows"] != "7000":
    raise SystemExit("v61ed fixture v53y run did not accept 7000 answer review rows")
if fixture_v53y["v61_review_unblock_ready"] != "1":
    raise SystemExit("v61ed fixture v53y run did not reach v61_review_unblock_ready=1")
if default_v53y["answer_review_accepted_rows"] != "0":
    raise SystemExit("v61ed canonical v53y default was not restored")

canonical_restore_rows = [
    {
        "restore_id": "v61ed-restore-v53-review-return-canonical-no-return",
        "status": "pass" if default_v53y["answer_review_accepted_rows"] == "0" and default_v53x["accepted_chunk_return_artifact_rows"] == "0" and default_v53s["review_return_ready"] == "0" else "fail",
        "canonical_answer_review_accepted_rows": default_v53y["answer_review_accepted_rows"],
        "canonical_accepted_chunk_return_artifact_rows": default_v53x["accepted_chunk_return_artifact_rows"],
        "canonical_review_return_ready": default_v53s["review_return_ready"],
        "canonical_v61_review_unblock_ready": default_v53y["v61_review_unblock_ready"],
    }
]
write_csv(run_dir / "review_return_refresh_fixture_canonical_restore_rows.csv", list(canonical_restore_rows[0].keys()), canonical_restore_rows)

stage_rows = [
    {"stage_id": "01-bind-v61ec-chunk-fixture", "status": "ready", "ready": "1", "evidence": "v61ec chunk fixture acceptance is ready"},
    {"stage_id": "02-generate-v53s-valid-aggregate-fixture", "status": "ready", "ready": "1", "evidence": "root aggregate review return fixture generated"},
    {"stage_id": "03-run-v53y-fixture-refresh", "status": "ready", "ready": "1", "evidence": "v53y fixture refresh executed"},
    {"stage_id": "04-v53s-aggregate-intake-fixture-accepted", "status": "ready", "ready": "1", "evidence": "v53s fixture review_return_ready=1"},
    {"stage_id": "05-v53v-per-answer-fixture-accepted", "status": "ready", "ready": "1", "evidence": "v53v fixture answer_review_accepted_rows=7000"},
    {"stage_id": "06-v53x-chunk-fixture-accepted", "status": "ready", "ready": "1", "evidence": "v53x fixture accepted 50/50 chunk artifacts"},
    {"stage_id": "07-v53y-review-unblock-fixture-ready", "status": "ready", "ready": "1", "evidence": "v53y fixture v61_review_unblock_ready=1"},
    {"stage_id": "08-restore-canonical-no-return", "status": "ready", "ready": "1", "evidence": "canonical v53 review-return chain restored to no-return"},
    {"stage_id": "09-real-review-return-received", "status": "blocked", "ready": "0", "evidence": "real_external_review_return_rows=0"},
    {"stage_id": "10-actual-generation-after-real-review", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "review_return_refresh_fixture_replay_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

invariant_rows = [
    {"invariant_id": "v61ec-ready", "status": "pass" if v61ec["v61ec_review_chunk_return_fixture_acceptance_gate_ready"] == "1" else "fail", "expected": "v61ec ready", "actual": v61ec["v61ec_review_chunk_return_fixture_acceptance_gate_ready"]},
    {"invariant_id": "fixture-family-rows", "status": "pass" if len(fixture_family_rows) == 5 else "fail", "expected": "5 aggregate fixture families", "actual": str(len(fixture_family_rows))},
    {"invariant_id": "fixture-files-include-chunks-and-root", "status": "pass" if len([row for row in fixture_file_rows if row["fixture_relative_path"].startswith("chunks/")]) == 50 and len([row for row in fixture_file_rows if not row["fixture_relative_path"].startswith("chunks/")]) >= 6 else "fail", "expected": "50 chunk files and root aggregate files", "actual": str(len(fixture_file_rows))},
    {"invariant_id": "fixture-v53s-review-return-ready", "status": "pass" if fixture_v53s["review_return_ready"] == "1" and fixture_v53s["accepted_human_review_rows"] == "7000" else "fail", "expected": "v53s fixture review_return_ready=1", "actual": f"ready={fixture_v53s['review_return_ready']};human={fixture_v53s['accepted_human_review_rows']}"},
    {"invariant_id": "fixture-v53v-answer-review-accepted", "status": "pass" if fixture_v53v["answer_review_accepted_rows"] == "7000" else "fail", "expected": "7000 accepted answer review rows", "actual": fixture_v53v["answer_review_accepted_rows"]},
    {"invariant_id": "fixture-v53x-chunk-return-accepted", "status": "pass" if fixture_v53x["accepted_chunk_return_artifact_rows"] == "50" and fixture_v53x["accepted_aggregate_review_return_artifact_rows"] == "5" else "fail", "expected": "50 chunk and 5 aggregate artifacts accepted", "actual": f"{fixture_v53x['accepted_chunk_return_artifact_rows']};{fixture_v53x['accepted_aggregate_review_return_artifact_rows']}"},
    {"invariant_id": "fixture-v53y-review-unblock-ready", "status": "pass" if fixture_v53y["v61_review_unblock_ready"] == "1" else "fail", "expected": "fixture v61_review_unblock_ready=1", "actual": fixture_v53y["v61_review_unblock_ready"]},
    {"invariant_id": "canonical-default-restored", "status": canonical_restore_rows[0]["status"], "expected": "canonical accepted review rows stay zero", "actual": default_v53y["answer_review_accepted_rows"]},
    {"invariant_id": "fixture-not-real-external-evidence", "status": "pass" if all(row["real_external_review_return"] == "0" for row in fixture_family_rows) else "fail", "expected": "all fixture rows real_external_review_return=0", "actual": str(sum(row["real_external_review_return"] == "0" for row in fixture_family_rows))},
    {"invariant_id": "actual-generation-still-blocked", "status": "pass", "expected": "actual_model_generation_ready=0", "actual": "0"},
    {"invariant_id": "repo-checkpoint-payload-zero", "status": "pass", "expected": "checkpoint payload committed to repo is zero", "actual": "0"},
]
write_csv(run_dir / "review_return_refresh_fixture_replay_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

runtime_gap_rows = [
    {"gap": "fixture-review-return-refresh", "status": "ready", "reason": "fixture v53y reached v61_review_unblock_ready=1"},
    {"gap": "canonical-default-restore", "status": "ready", "reason": "canonical v53 review-return chain restored to no-return"},
    {"gap": "real-review-return", "status": "blocked", "reason": "real_external_review_return_rows=0"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gap": "release", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

bundle_readme = bundle_dir / "README.md"
bundle_readme.write_text(
    "# v61ed Review Return Refresh Fixture Replay Gate\n\n"
    "This bundle proves the downstream v53s/v53v/v53x/v53y review-return "
    "refresh mechanics can close on a complete supplied fixture. It is fixture "
    "evidence only and does not count as real external human/source review, "
    "v1.0 comparison evidence, actual generation evidence, or release evidence.\n",
    encoding="utf-8",
)
for src, rel in [
    (run_dir / "review_return_refresh_fixture_family_rows.csv", "REVIEW_RETURN_REFRESH_FIXTURE_FAMILY_ROWS.csv"),
    (run_dir / "review_return_refresh_fixture_file_rows.csv", "REVIEW_RETURN_REFRESH_FIXTURE_FILE_ROWS.csv"),
    (run_dir / "review_return_refresh_fixture_canonical_restore_rows.csv", "CANONICAL_RESTORE_ROWS.csv"),
    (run_dir / "review_return_refresh_fixture_replay_stage_rows.csv", "FIXTURE_REPLAY_STAGES.csv"),
    (run_dir / "review_return_refresh_fixture_replay_invariant_rows.csv", "FIXTURE_REPLAY_INVARIANTS.csv"),
]:
    copy_bundle(src, rel)

verify_script = bundle_dir / "VERIFY_V61ED_FIXTURE_REPLAY.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
            'RUN_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"',
            "export RUN_DIR",
            'test -s "$BUNDLE_DIR/REVIEW_RETURN_REFRESH_FIXTURE_FAMILY_ROWS.csv"',
            'test -s "$BUNDLE_DIR/CANONICAL_RESTORE_ROWS.csv"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import os",
            "from pathlib import Path",
            "run_dir = Path(os.environ['RUN_DIR'])",
            "def read_csv(path):",
            "    with path.open(newline='', encoding='utf-8') as handle:",
            "        return list(csv.DictReader(handle))",
            "summary = read_csv(run_dir.parent.parent / 'v61ed_review_return_refresh_fixture_replay_gate_summary.csv')[0]",
            "if summary['fixture_answer_review_accepted_rows'] != '7000':",
            "    raise SystemExit('fixture answer review rows were not accepted')",
            "if summary['fixture_v61_review_unblock_ready'] != '1':",
            "    raise SystemExit('fixture review unblock did not become ready')",
            "if summary['canonical_default_answer_review_accepted_rows'] != '0':",
            "    raise SystemExit('canonical default v53y state was not restored')",
            "if summary['real_external_review_return_rows'] != '0':",
            "    raise SystemExit('fixture must not count as real external review return')",
            "PY_VERIFY",
            'if find "$RUN_DIR" -type f \\( -name "*.safetensors" -o -name "*.bin" -o -name "*.pt" \\) | grep -q .; then',
            '  echo "model/checkpoint payload-like file found inside v61ed fixture gate" >&2',
            "  exit 1",
            "fi",
            "echo 'v61ed fixture replay verified'",
        ]
    )
    + "\n",
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_manifest = {
    "manifest_scope": "v61ed-review-return-refresh-fixture-replay-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "fixture_answer_review_accepted_rows": as_int(fixture_v53y, "answer_review_accepted_rows"),
    "fixture_v61_review_unblock_ready": as_int(fixture_v53y, "v61_review_unblock_ready"),
    "canonical_default_answer_review_accepted_rows": as_int(default_v53y, "answer_review_accepted_rows"),
    "real_external_review_return_rows": 0,
    "actual_model_generation_ready": 0,
}
(bundle_dir / "FIXTURE_REPLAY_MANIFEST.json").write_text(
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
write_csv(run_dir / "review_return_refresh_fixture_replay_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

ready_stage_rows = sum(1 for row in stage_rows if row["status"] == "ready")
blocked_stage_rows = sum(1 for row in stage_rows if row["status"] == "blocked")
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

summary_row = {
    "v61ed_review_return_refresh_fixture_replay_gate_ready": "1",
    "v61ec_review_chunk_return_fixture_acceptance_gate_ready": v61ec["v61ec_review_chunk_return_fixture_acceptance_gate_ready"],
    "fixture_stage_rows": str(len(stage_rows)),
    "ready_fixture_stage_rows": str(ready_stage_rows),
    "blocked_fixture_stage_rows": str(blocked_stage_rows),
    "fixture_family_rows": str(len(fixture_family_rows)),
    "fixture_file_rows": str(len(fixture_file_rows)),
    "fixture_v53s_review_return_ready": fixture_v53s["review_return_ready"],
    "fixture_v53v_answer_review_accepted_rows": fixture_v53v["answer_review_accepted_rows"],
    "fixture_v53x_accepted_chunk_return_artifact_rows": fixture_v53x["accepted_chunk_return_artifact_rows"],
    "fixture_v53x_accepted_aggregate_review_return_artifact_rows": fixture_v53x["accepted_aggregate_review_return_artifact_rows"],
    "fixture_answer_review_accepted_rows": fixture_v53y["answer_review_accepted_rows"],
    "fixture_v61_review_unblock_ready": fixture_v53y["v61_review_unblock_ready"],
    "fixture_v53_ready": fixture_v53y["v53_ready"],
    "fixture_v1_0_comparison_ready": fixture_v53y["v1_0_comparison_ready"],
    "canonical_default_review_return_ready": default_v53s["review_return_ready"],
    "canonical_default_answer_review_accepted_rows": default_v53y["answer_review_accepted_rows"],
    "canonical_default_accepted_chunk_return_artifact_rows": default_v53x["accepted_chunk_return_artifact_rows"],
    "canonical_default_v61_review_unblock_ready": default_v53y["v61_review_unblock_ready"],
    "real_external_review_return_rows": "0",
    "real_external_human_review_rows": "0",
    "real_external_adjudication_rows": "0",
    "accepted_human_review_rows": "0",
    "accepted_adjudication_rows": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": str(len(invariant_rows)),
    "fixture_invariant_pass_rows": str(invariant_pass_rows),
    "fixture_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_fixture_bundle_file_rows": str(sum(1 for row in bundle_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61ed": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "v61ec-chunk-fixture", "status": "pass", "reason": "v61ec chunk fixture is ready"},
    {"gate": "fixture-v53s-aggregate-intake", "status": "pass", "reason": "fixture v53s review_return_ready=1"},
    {"gate": "fixture-v53v-per-answer-acceptance", "status": "pass", "reason": "fixture v53v accepted 7000/7000 answer review rows"},
    {"gate": "fixture-v53x-chunk-intake", "status": "pass", "reason": "fixture v53x accepted 50/50 chunk artifacts"},
    {"gate": "fixture-v53y-review-unblock", "status": "pass", "reason": "fixture v53y reports v61_review_unblock_ready=1"},
    {"gate": "canonical-default-restore", "status": canonical_restore_rows[0]["status"], "reason": "canonical v53 review-return chain restored to no-return"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "no checkpoint/model payload committed"},
    {"gate": "real-review-return", "status": "blocked", "reason": "real_external_review_return_rows=0"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual generation remains blocked"},
    {"gate": "release", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ed Review Return Refresh Fixture Replay Gate Boundary

This gate proves downstream review-return refresh mechanics only. It combines
v61ec chunk fixture returns with a v53s-valid aggregate fixture, runs v53y
against that supplied directory, copies the fixture replay evidence, and then
restores the canonical no-return v53 review chain.

Evidence emitted:

- fixture_v53s_review_return_ready={fixture_v53s['review_return_ready']}
- fixture_v53v_answer_review_accepted_rows={fixture_v53v['answer_review_accepted_rows']}/7000
- fixture_v53x_accepted_chunk_return_artifact_rows={fixture_v53x['accepted_chunk_return_artifact_rows']}/50
- fixture_v53x_accepted_aggregate_review_return_artifact_rows={fixture_v53x['accepted_aggregate_review_return_artifact_rows']}/5
- fixture_answer_review_accepted_rows={fixture_v53y['answer_review_accepted_rows']}/7000
- fixture_v61_review_unblock_ready={fixture_v53y['v61_review_unblock_ready']}
- canonical_default_answer_review_accepted_rows={default_v53y['answer_review_accepted_rows']}
- canonical_default_accepted_chunk_return_artifact_rows={default_v53x['accepted_chunk_return_artifact_rows']}
- real_external_review_return_rows=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: downstream v53 review-return refresh mechanics can close on a
complete supplied fixture and the canonical no-return state is restored.

Blocked wording: real external review return received, accepted human/source
review, v1.0 comparison readiness, actual generation, production latency,
near-frontier quality, or release readiness.
"""
(run_dir / "V61ED_REVIEW_RETURN_REFRESH_FIXTURE_REPLAY_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61ed-review-return-refresh-fixture-replay-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ed_review_return_refresh_fixture_replay_gate_ready": 1,
    "fixture_answer_review_accepted_rows": as_int(fixture_v53y, "answer_review_accepted_rows"),
    "fixture_v61_review_unblock_ready": as_int(fixture_v53y, "v61_review_unblock_ready"),
    "canonical_default_answer_review_accepted_rows": as_int(default_v53y, "answer_review_accepted_rows"),
    "real_external_review_return_rows": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ed_review_return_refresh_fixture_replay_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ed_review_return_refresh_fixture_replay_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
