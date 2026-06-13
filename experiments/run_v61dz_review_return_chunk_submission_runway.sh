#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dz_review_return_chunk_submission_runway"
RUN_ID="${V61DZ_RUN_ID:-runway_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dz_review_return_chunk_submission_runway_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61dy_active_goal_critical_path_runway_summary.csv" ]]; then
  V61DY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dy_active_goal_critical_path_runway.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53w_complete_source_review_return_chunk_execution_queue_summary.csv" ]]; then
  V53W_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
submission_dir = run_dir / "review_return_submission_runway"
submission_dir.mkdir(parents=True, exist_ok=True)


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def copy_submission(src, rel):
    dst = submission_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61dy_summary": results / "v61dy_active_goal_critical_path_runway_summary.csv",
    "v61dy_decision": results / "v61dy_active_goal_critical_path_runway_decision.csv",
    "v61dy_phase": results / "v61dy_active_goal_critical_path_runway/runway_001/critical_path_phase_rows.csv",
    "v61dy_family": results / "v61dy_active_goal_critical_path_runway/runway_001/critical_path_artifact_family_rows.csv",
    "v61dy_command": results / "v61dy_active_goal_critical_path_runway/runway_001/critical_path_command_dependency_rows.csv",
    "v61dy_next": results / "v61dy_active_goal_critical_path_runway/runway_001/critical_path_next_action_rows.csv",
    "v53w_summary": results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv",
    "v53w_decision": results / "v53w_complete_source_review_return_chunk_execution_queue_decision.csv",
    "v53w_execution": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_execution_rows.csv",
    "v53w_task": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_task_rows.csv",
    "v53w_artifact": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_artifact_rows.csv",
    "v53w_command": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_command_rows.csv",
    "v53w_requirement": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_requirement_rows.csv",
    "v53w_verify": results / "v53w_complete_source_review_return_chunk_execution_queue/queue_001/operator_bundle/VERIFY_CHUNK_QUEUE.sh",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dz source {key}: {path}")

copy(sources["v61dy_summary"], "source_v61dy/v61dy_active_goal_critical_path_runway_summary.csv")
copy(sources["v61dy_decision"], "source_v61dy/v61dy_active_goal_critical_path_runway_decision.csv")
copy(sources["v61dy_phase"], "source_v61dy/critical_path_phase_rows.csv")
copy(sources["v61dy_family"], "source_v61dy/critical_path_artifact_family_rows.csv")
copy(sources["v61dy_command"], "source_v61dy/critical_path_command_dependency_rows.csv")
copy(sources["v61dy_next"], "source_v61dy/critical_path_next_action_rows.csv")
copy(sources["v53w_summary"], "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_summary.csv")
copy(sources["v53w_decision"], "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_decision.csv")
copy(sources["v53w_execution"], "source_v53w/review_return_chunk_execution_rows.csv")
copy(sources["v53w_task"], "source_v53w/review_return_chunk_task_rows.csv")
copy(sources["v53w_artifact"], "source_v53w/review_return_chunk_artifact_rows.csv")
copy(sources["v53w_command"], "source_v53w/review_return_chunk_command_rows.csv")
copy(sources["v53w_requirement"], "source_v53w/review_return_chunk_requirement_rows.csv")
copy(sources["v53w_verify"], "source_v53w/VERIFY_CHUNK_QUEUE.sh")

v61dy = read_csv(sources["v61dy_summary"])[0]
v53w = read_csv(sources["v53w_summary"])[0]
execution_rows = read_csv(sources["v53w_execution"])
task_rows = read_csv(sources["v53w_task"])
artifact_rows = read_csv(sources["v53w_artifact"])
command_rows = read_csv(sources["v53w_command"])

if v61dy.get("v61dy_active_goal_critical_path_runway_ready") != "1":
    raise SystemExit("v61dz requires v61dy ready")
if v53w.get("v53w_complete_source_review_return_chunk_execution_queue_ready") != "1":
    raise SystemExit("v61dz requires v53w ready")

chunk_manifest_rows = []
for row in execution_rows:
    expected_payload_rows = (
        int(row["expected_human_review_rows"])
        + int(row["expected_adjudication_rows"])
        + int(row["expected_reviewer_identity_rows"])
        + int(row["expected_conflict_disclosure_rows"])
    )
    chunk_manifest_rows.append(
        {
            "review_chunk_id": row["review_chunk_id"],
            "assignment_id": row["assignment_id"],
            "reviewer_slot_id": row["reviewer_slot_id"],
            "system_id": row["system_id"],
            "review_scope": row["review_scope"],
            "expected_payload_rows": str(expected_payload_rows),
            "expected_human_review_rows": row["expected_human_review_rows"],
            "expected_adjudication_rows": row["expected_adjudication_rows"],
            "expected_reviewer_identity_rows": row["expected_reviewer_identity_rows"],
            "expected_conflict_disclosure_rows": row["expected_conflict_disclosure_rows"],
            "expected_chunk_return_artifacts": row["expected_chunk_return_artifacts"],
            "chunk_dispatch_ready": row["chunk_dispatch_ready"],
            "chunk_return_completed": row["chunk_return_completed"],
            "chunk_return_accepted": row["chunk_return_accepted"],
            "submission_status": "ready-to-dispatch" if row["chunk_dispatch_ready"] == "1" else "blocked",
            "blocking_reason": row["blocking_reason"],
        }
    )
write_csv(run_dir / "review_return_submission_chunk_manifest_rows.csv", list(chunk_manifest_rows[0].keys()), chunk_manifest_rows)
copy_submission(run_dir / "review_return_submission_chunk_manifest_rows.csv", "REVIEW_RETURN_CHUNK_MANIFEST.csv")

artifact_family_counts = defaultdict(lambda: {"artifacts": 0, "expected_rows": 0, "accepted_rows": 0})
for row in artifact_rows:
    bucket = artifact_family_counts[row["artifact_family"]]
    bucket["artifacts"] += 1
    bucket["expected_rows"] += int(row["expected_rows"])
    bucket["accepted_rows"] += int(row["accepted_rows"])

artifact_family_rows = []
for family, counts in sorted(artifact_family_counts.items()):
    artifact_family_rows.append(
        {
            "artifact_family": family,
            "chunk_artifact_rows": str(counts["artifacts"]),
            "expected_rows": str(counts["expected_rows"]),
            "accepted_rows": str(counts["accepted_rows"]),
            "family_ready": "0",
            "submission_status": "ready-to-dispatch" if family in {"human_review_rows.csv", "adjudication_rows.csv", "reviewer_identity_rows.csv", "reviewer_conflict_rows.csv"} else "blocked",
        }
    )
write_csv(run_dir / "review_return_submission_artifact_family_rows.csv", list(artifact_family_rows[0].keys()), artifact_family_rows)
copy_submission(run_dir / "review_return_submission_artifact_family_rows.csv", "REVIEW_RETURN_ARTIFACT_FAMILIES.csv")

task_family_counts = defaultdict(int)
for row in task_rows:
    task_family_counts[row["task_type"]] += 1
task_family_rows = [
    {
        "task_type": task_type,
        "task_rows": str(count),
        "accepted_rows": "0",
        "submission_status": "ready-to-dispatch",
    }
    for task_type, count in sorted(task_family_counts.items())
]
write_csv(run_dir / "review_return_submission_task_family_rows.csv", list(task_family_rows[0].keys()), task_family_rows)
copy_submission(run_dir / "review_return_submission_task_family_rows.csv", "REVIEW_RETURN_TASK_FAMILIES.csv")

submission_phase_rows = [
    {
        "phase_id": "01-bind-review-first-runway",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61dy",
        "evidence": "review-first critical path runway is ready",
    },
    {
        "phase_id": "02-bind-review-chunk-queue",
        "status": "ready",
        "ready": "1",
        "source_gate": "v53w",
        "evidence": "21/21 review chunks are dispatch-ready",
    },
    {
        "phase_id": "03-dispatch-review-chunks",
        "status": "ready",
        "ready": "1",
        "source_gate": "v53w",
        "evidence": "external review team can populate chunk return directories",
    },
    {
        "phase_id": "04-collect-50-chunk-artifacts",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v53w/v53x",
        "evidence": "50 chunk artifacts have not been returned",
    },
    {
        "phase_id": "05-merge-aggregate-v53s-return",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v53s",
        "evidence": "aggregate review return artifacts are not accepted",
    },
    {
        "phase_id": "06-refresh-generation-unblock-chain",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61dy/v61de",
        "evidence": "generation remains blocked until v53 review return is accepted",
    },
]
write_csv(run_dir / "review_return_submission_phase_rows.csv", list(submission_phase_rows[0].keys()), submission_phase_rows)
copy_submission(run_dir / "review_return_submission_phase_rows.csv", "REVIEW_RETURN_SUBMISSION_PHASES.csv")

ready_command_rows = []
for row in command_rows:
    ready_command_rows.append(
        {
            "command_id": row["command_id"],
            "ready_to_run_now": row["ready_to_run_now"],
            "status": "ready" if row["ready_to_run_now"] == "1" else "blocked",
            "command": row["command"],
            "expected_return": row["expected_return"],
        }
    )
write_csv(run_dir / "review_return_submission_command_rows.csv", list(ready_command_rows[0].keys()), ready_command_rows)
copy_submission(run_dir / "review_return_submission_command_rows.csv", "REVIEW_RETURN_COMMANDS.csv")

invariant_rows = [
    {
        "invariant_id": "v61dy-review-first-runway-ready",
        "status": "pass" if v61dy["v61dy_active_goal_critical_path_runway_ready"] == "1" else "fail",
        "expected": "v61dy ready",
        "actual": v61dy["v61dy_active_goal_critical_path_runway_ready"],
    },
    {
        "invariant_id": "v53w-review-chunk-dispatch-ready",
        "status": "pass" if v53w["review_chunk_rows"] == "21" and v53w["ready_review_chunk_dispatch_rows"] == "21" else "fail",
        "expected": "21/21 review chunks dispatch-ready",
        "actual": f"{v53w['ready_review_chunk_dispatch_rows']}/{v53w['review_chunk_rows']}",
    },
    {
        "invariant_id": "review-task-counts-preserved",
        "status": "pass" if len(task_rows) == 8000 and task_family_counts["human-review"] == 7000 and task_family_counts["adjudication"] == 1000 else "fail",
        "expected": "7000 human review and 1000 adjudication task rows",
        "actual": f"tasks={len(task_rows)};human={task_family_counts['human-review']};adjudication={task_family_counts['adjudication']}",
    },
    {
        "invariant_id": "chunk-artifact-counts-preserved",
        "status": "pass" if len(artifact_rows) == 50 and as_int(v53w, "review_chunk_return_artifact_rows") == 50 else "fail",
        "expected": "50 chunk return artifacts",
        "actual": f"artifact_rows={len(artifact_rows)};summary={v53w['review_chunk_return_artifact_rows']}",
    },
    {
        "invariant_id": "review-return-blocks-generation",
        "status": "pass" if v61dy["generation_execution_admitted_rows"] == "0" and v61dy["actual_model_generation_ready"] == "0" else "fail",
        "expected": "generation stays blocked while review return is absent",
        "actual": f"generation={v61dy['generation_execution_admitted_rows']};actual={v61dy['actual_model_generation_ready']}",
    },
    {
        "invariant_id": "repo-checkpoint-payload-zero",
        "status": "pass" if v61dy["checkpoint_payload_bytes_committed_to_repo"] == "0" else "fail",
        "expected": "repo checkpoint payload is zero",
        "actual": v61dy["checkpoint_payload_bytes_committed_to_repo"],
    },
]
write_csv(run_dir / "review_return_submission_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)
copy_submission(run_dir / "review_return_submission_invariant_rows.csv", "REVIEW_RETURN_INVARIANTS.csv")

readme = submission_dir / "REVIEW_RETURN_SUBMISSION_README.md"
readme.write_text(
    "\n".join(
        [
            "# v61dz Review Return Chunk Submission Runway",
            "",
            "This package is metadata-only. It prepares the external review team",
            "submission shape for v53s without creating human review decisions,",
            "adjudication rows, generation results, latency evidence, or release",
            "evidence.",
            "",
            "Dispatch-ready:",
            "",
            f"- review_chunk_rows={v53w['review_chunk_rows']}",
            f"- ready_review_chunk_dispatch_rows={v53w['ready_review_chunk_dispatch_rows']}",
            f"- review_chunk_task_rows={v53w['review_chunk_task_rows']}",
            f"- human_review_chunk_task_rows={v53w['human_review_chunk_task_rows']}",
            f"- adjudication_chunk_task_rows={v53w['adjudication_chunk_task_rows']}",
            f"- review_chunk_return_artifact_rows={v53w['review_chunk_return_artifact_rows']}",
            "",
            "Still blocked:",
            "",
            f"- accepted_human_review_rows={v53w['accepted_human_review_rows']}/{v53w['expected_human_review_rows']}",
            f"- accepted_adjudication_rows={v53w['accepted_adjudication_rows']}/{v53w['expected_adjudication_rows']}",
            f"- review_return_ready={v53w['review_return_ready']}",
            f"- actual_model_generation_ready={v61dy['actual_model_generation_ready']}",
            "",
        ]
    ),
    encoding="utf-8",
)

ready_script = submission_dir / "READY_REVIEW_CHUNK_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61dz review chunk commands are informational and require real reviewer output directories.'",
]
for row in ready_command_rows:
    if row["ready_to_run_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['command'])}")
ready_script.write_text("\n".join(ready_lines) + "\n", encoding="utf-8")
os.chmod(ready_script, 0o755)

submission_manifest = {
    "manifest_scope": "v61dz-review-return-chunk-submission-runway",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "review_chunk_rows": as_int(v53w, "review_chunk_rows"),
    "ready_review_chunk_dispatch_rows": as_int(v53w, "ready_review_chunk_dispatch_rows"),
    "review_chunk_task_rows": as_int(v53w, "review_chunk_task_rows"),
    "review_chunk_return_artifact_rows": as_int(v53w, "review_chunk_return_artifact_rows"),
    "actual_model_generation_ready": as_int(v61dy, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(submission_dir / "SUBMISSION_MANIFEST.json").write_text(
    json.dumps(submission_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

submission_files = sorted(path for path in submission_dir.rglob("*") if path.is_file())
write_csv(
    run_dir / "review_return_submission_file_rows.csv",
    ["submission_relative_path", "size_bytes", "sha256", "payload_class"],
    [
        {
            "submission_relative_path": str(path.relative_to(submission_dir)),
            "size_bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "payload_class": "metadata-only",
        }
        for path in submission_files
    ],
)

ready_phase_rows = sum(1 for row in submission_phase_rows if row["status"] == "ready")
blocked_phase_rows = sum(1 for row in submission_phase_rows if row["status"] == "blocked")
ready_command_count = sum(1 for row in ready_command_rows if row["status"] == "ready")
blocked_command_count = sum(1 for row in ready_command_rows if row["status"] == "blocked")
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")
submission_file_rows = read_csv(run_dir / "review_return_submission_file_rows.csv")

summary_row = {
    "v61dz_review_return_chunk_submission_runway_ready": "1",
    "v61dy_active_goal_critical_path_runway_ready": v61dy["v61dy_active_goal_critical_path_runway_ready"],
    "v53w_complete_source_review_return_chunk_execution_queue_ready": v53w["v53w_complete_source_review_return_chunk_execution_queue_ready"],
    "submission_phase_rows": str(len(submission_phase_rows)),
    "ready_submission_phase_rows": str(ready_phase_rows),
    "blocked_submission_phase_rows": str(blocked_phase_rows),
    "review_chunk_rows": v53w["review_chunk_rows"],
    "ready_review_chunk_dispatch_rows": v53w["ready_review_chunk_dispatch_rows"],
    "review_chunk_task_rows": v53w["review_chunk_task_rows"],
    "human_review_chunk_task_rows": v53w["human_review_chunk_task_rows"],
    "adjudication_chunk_task_rows": v53w["adjudication_chunk_task_rows"],
    "review_chunk_return_artifact_rows": v53w["review_chunk_return_artifact_rows"],
    "human_review_chunk_artifact_rows": v53w["human_review_chunk_artifact_rows"],
    "adjudication_chunk_artifact_rows": v53w["adjudication_chunk_artifact_rows"],
    "reviewer_identity_chunk_artifact_rows": v53w["reviewer_identity_chunk_artifact_rows"],
    "reviewer_conflict_chunk_artifact_rows": v53w["reviewer_conflict_chunk_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53w["aggregate_review_return_artifact_rows"],
    "submission_artifact_family_rows": str(len(artifact_family_rows)),
    "submission_task_family_rows": str(len(task_family_rows)),
    "submission_command_rows": str(len(ready_command_rows)),
    "ready_submission_command_rows": str(ready_command_count),
    "blocked_submission_command_rows": str(blocked_command_count),
    "submission_invariant_rows": str(len(invariant_rows)),
    "submission_invariant_pass_rows": str(invariant_pass_rows),
    "submission_file_rows": str(len(submission_file_rows)),
    "metadata_only_submission_file_rows": str(sum(1 for row in submission_file_rows if row["payload_class"] == "metadata-only")),
    "expected_human_review_rows": v53w["expected_human_review_rows"],
    "accepted_human_review_rows": v53w["accepted_human_review_rows"],
    "expected_adjudication_rows": v53w["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53w["accepted_adjudication_rows"],
    "review_return_ready": v53w["review_return_ready"],
    "v53_ready": v53w["v53_ready"],
    "generation_execution_admitted_rows": v61dy["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61dy["generation_execution_admission_rows"],
    "actual_model_generation_ready": v61dy["actual_model_generation_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61dz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "review-return-chunk-submission-runway", "status": "pass", "reason": "chunk manifest, artifact families, task families, commands, and invariants emitted", "evidence_source": "v61dy/v53w"},
    {"gate": "review-chunk-dispatch-ready", "status": "pass", "reason": f"{v53w['ready_review_chunk_dispatch_rows']}/{v53w['review_chunk_rows']} review chunks are dispatch-ready", "evidence_source": "v53w"},
    {"gate": "review-chunk-return-accepted", "status": "blocked", "reason": "chunk return artifacts are not supplied", "evidence_source": "v53w"},
    {"gate": "aggregate-v53s-review-return", "status": "blocked", "reason": f"accepted review/adjudication rows {v53w['accepted_human_review_rows']}/{v53w['expected_human_review_rows']} and {v53w['accepted_adjudication_rows']}/{v53w['expected_adjudication_rows']}", "evidence_source": "v53w"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61dy['generation_execution_admitted_rows']}/{v61dy['generation_execution_admission_rows']}", "evidence_source": "v61dy"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "review return is not accepted", "evidence_source": "v61dy/v53w"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "checkpoint payload committed to repo remains zero", "evidence_source": "v61dy"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

manifest = {
    "manifest_scope": "v61dz-review-return-chunk-submission-runway",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary_row.items()},
}
(run_dir / "v61dz_review_return_chunk_submission_runway_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file()):
    if path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY
