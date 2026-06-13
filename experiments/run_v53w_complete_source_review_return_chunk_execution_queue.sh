#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53w_complete_source_review_return_chunk_execution_queue"
RUN_ID="${V53W_RUN_ID:-queue_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53W_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53w_complete_source_review_return_chunk_execution_queue_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53u_complete_source_review_return_operator_bundle.sh" >/dev/null
V53V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
results = root / "results"
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


def status(flag):
    return "pass" if flag else "blocked"


v53u_dir = results / "v53u_complete_source_review_return_operator_bundle" / "bundle_001"
v53v_dir = results / "v53v_complete_source_review_return_acceptance_bridge" / "bridge_001"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v53s_dir = results / "v53s_complete_source_review_return_intake" / "intake_001"
v53u_summary_path = results / "v53u_complete_source_review_return_operator_bundle_summary.csv"
v53v_summary_path = results / "v53v_complete_source_review_return_acceptance_bridge_summary.csv"
v53u_decision_path = results / "v53u_complete_source_review_return_operator_bundle_decision.csv"
v53v_decision_path = results / "v53v_complete_source_review_return_acceptance_bridge_decision.csv"

v53u = read_csv(v53u_summary_path)[0]
v53v = read_csv(v53v_summary_path)[0]
if v53u.get("v53u_complete_source_review_return_operator_bundle_ready") != "1":
    raise SystemExit("v53w requires v53u_complete_source_review_return_operator_bundle_ready=1")
if v53v.get("v53v_complete_source_review_return_acceptance_bridge_ready") != "1":
    raise SystemExit("v53w requires v53v_complete_source_review_return_acceptance_bridge_ready=1")

for src, rel in [
    (v53u_summary_path, "source_v53u/v53u_complete_source_review_return_operator_bundle_summary.csv"),
    (v53u_decision_path, "source_v53u/v53u_complete_source_review_return_operator_bundle_decision.csv"),
    (v53u_dir / "reviewer_workload_chunk_rows.csv", "source_v53u/reviewer_workload_chunk_rows.csv"),
    (v53u_dir / "review_return_expected_artifact_rows.csv", "source_v53u/review_return_expected_artifact_rows.csv"),
    (v53u_dir / "review_return_operator_command_rows.csv", "source_v53u/review_return_operator_command_rows.csv"),
    (v53u_dir / "review_return_operator_metric_rows.csv", "source_v53u/review_return_operator_metric_rows.csv"),
    (v53u_dir / "sha256_manifest.csv", "source_v53u/sha256_manifest.csv"),
    (v53v_summary_path, "source_v53v/v53v_complete_source_review_return_acceptance_bridge_summary.csv"),
    (v53v_decision_path, "source_v53v/v53v_complete_source_review_return_acceptance_bridge_decision.csv"),
    (v53v_dir / "complete_source_review_return_acceptance_rows.csv", "source_v53v/complete_source_review_return_acceptance_rows.csv"),
    (v53v_dir / "complete_source_review_return_acceptance_metric_rows.csv", "source_v53v/complete_source_review_return_acceptance_metric_rows.csv"),
    (v53v_dir / "sha256_manifest.csv", "source_v53v/sha256_manifest.csv"),
    (v53r_dir / "review_answer_packet_rows.csv", "source_v53r/review_answer_packet_rows.csv"),
    (v53r_dir / "review_queue_rows.csv", "source_v53r/review_queue_rows.csv"),
    (v53r_dir / "reviewer_assignment_template_rows.csv", "source_v53r/reviewer_assignment_template_rows.csv"),
    (v53s_dir / "review_return_required_field_rows.csv", "source_v53s/review_return_required_field_rows.csv"),
    (v53s_dir / "review_return_row_template.csv", "source_v53s/review_return_row_template.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v53u_dir / "reviewer_workload_chunk_rows.csv")
answer_rows = read_csv(v53r_dir / "review_answer_packet_rows.csv")
queue_rows = read_csv(v53r_dir / "review_queue_rows.csv")
if len(chunk_rows) != 21:
    raise SystemExit("v53w expects 21 v53u reviewer workload chunks")
if len(answer_rows) != 7000 or len(queue_rows) != 7000:
    raise SystemExit("v53w expects 7000 v53r answer and queue rows")

primary_chunk_by_system = {
    row["system_id"]: row["review_chunk_id"]
    for row in chunk_rows
    if row["review_scope"] == "primary-source-review"
}
secondary_chunk_by_system = {
    row["system_id"]: row["review_chunk_id"]
    for row in chunk_rows
    if row["review_scope"] == "secondary-adjudication-review"
}
queue_by_answer_id = {row["answer_id"]: row for row in queue_rows}

execution_rows = []
for row in chunk_rows:
    human_rows = int(row["expected_human_review_rows"])
    adjudication_rows = int(row["expected_adjudication_rows"])
    identity_rows = int(row["expected_reviewer_identity_rows"])
    conflict_rows = int(row["expected_conflict_disclosure_rows"])
    execution_rows.append(
        {
            "review_chunk_id": row["review_chunk_id"],
            "assignment_id": row["assignment_id"],
            "reviewer_slot_id": row["reviewer_slot_id"],
            "system_id": row["system_id"],
            "review_scope": row["review_scope"],
            "expected_human_review_rows": str(human_rows),
            "expected_adjudication_rows": str(adjudication_rows),
            "expected_reviewer_identity_rows": str(identity_rows),
            "expected_conflict_disclosure_rows": str(conflict_rows),
            "expected_chunk_return_artifacts": str(int(human_rows > 0) + int(adjudication_rows > 0) + 2),
            "chunk_dispatch_ready": row["chunk_ready"],
            "chunk_return_completed": "0",
            "chunk_return_accepted": "0",
            "blocking_reason": "chunk-return-not-supplied",
        }
    )
write_csv(run_dir / "review_return_chunk_execution_rows.csv", list(execution_rows[0].keys()), execution_rows)

task_rows = []
for answer in answer_rows:
    human_chunk_id = primary_chunk_by_system[answer["system_id"]]
    task_rows.append(
        {
            "review_chunk_task_id": f"v53w-human-{answer['answer_id']}",
            "task_type": "human-review",
            "review_chunk_id": human_chunk_id,
            "review_answer_packet_id": answer["review_answer_packet_id"],
            "answer_id": answer["answer_id"],
            "system_id": answer["system_id"],
            "query_id": answer["query_id"],
            "owner_repo": answer["owner_repo"],
            "priority_class": answer["priority_class"],
            "expected_return_artifact": f"chunks/{human_chunk_id}/human_review_rows.csv",
            "task_return_ready": "0",
        }
    )
    queue = queue_by_answer_id[answer["answer_id"]]
    if queue["priority_class"] == "p0_answer_or_policy_mismatch":
        adjudication_chunk_id = secondary_chunk_by_system[answer["system_id"]]
        task_rows.append(
            {
                "review_chunk_task_id": f"v53w-adjudication-{answer['answer_id']}",
                "task_type": "adjudication",
                "review_chunk_id": adjudication_chunk_id,
                "review_answer_packet_id": answer["review_answer_packet_id"],
                "answer_id": answer["answer_id"],
                "system_id": answer["system_id"],
                "query_id": answer["query_id"],
                "owner_repo": answer["owner_repo"],
                "priority_class": answer["priority_class"],
                "expected_return_artifact": f"chunks/{adjudication_chunk_id}/adjudication_rows.csv",
                "task_return_ready": "0",
            }
        )
write_csv(run_dir / "review_return_chunk_task_rows.csv", list(task_rows[0].keys()), task_rows)

chunk_artifact_rows = []
for row in execution_rows:
    chunk_id = row["review_chunk_id"]
    if int(row["expected_human_review_rows"]):
        chunk_artifact_rows.append(
            {
                "review_chunk_id": chunk_id,
                "return_artifact": f"chunks/{chunk_id}/human_review_rows.csv",
                "artifact_family": "human_review_rows.csv",
                "expected_rows": row["expected_human_review_rows"],
                "accepted_rows": "0",
                "artifact_ready": "0",
            }
        )
    if int(row["expected_adjudication_rows"]):
        chunk_artifact_rows.append(
            {
                "review_chunk_id": chunk_id,
                "return_artifact": f"chunks/{chunk_id}/adjudication_rows.csv",
                "artifact_family": "adjudication_rows.csv",
                "expected_rows": row["expected_adjudication_rows"],
                "accepted_rows": "0",
                "artifact_ready": "0",
            }
        )
    chunk_artifact_rows.append(
        {
            "review_chunk_id": chunk_id,
            "return_artifact": f"chunks/{chunk_id}/reviewer_identity_rows.csv",
            "artifact_family": "reviewer_identity_rows.csv",
            "expected_rows": row["expected_reviewer_identity_rows"],
            "accepted_rows": "0",
            "artifact_ready": "0",
        }
    )
    chunk_artifact_rows.append(
        {
            "review_chunk_id": chunk_id,
            "return_artifact": f"chunks/{chunk_id}/reviewer_conflict_rows.csv",
            "artifact_family": "reviewer_conflict_rows.csv",
            "expected_rows": row["expected_conflict_disclosure_rows"],
            "accepted_rows": "0",
            "artifact_ready": "0",
        }
    )
write_csv(run_dir / "review_return_chunk_artifact_rows.csv", list(chunk_artifact_rows[0].keys()), chunk_artifact_rows)

aggregate_artifact_rows = [
    {
        "aggregate_artifact": "human_review_rows.csv",
        "source_chunk_artifact_family": "human_review_rows.csv",
        "expected_rows": v53u["expected_human_review_rows"],
        "accepted_rows": "0",
        "aggregate_ready": "0",
        "target_intake": "v53s",
    },
    {
        "aggregate_artifact": "adjudication_rows.csv",
        "source_chunk_artifact_family": "adjudication_rows.csv",
        "expected_rows": v53u["expected_adjudication_rows"],
        "accepted_rows": "0",
        "aggregate_ready": "0",
        "target_intake": "v53s",
    },
    {
        "aggregate_artifact": "reviewer_identity_rows.csv",
        "source_chunk_artifact_family": "reviewer_identity_rows.csv",
        "expected_rows": v53u["expected_reviewer_identity_rows"],
        "accepted_rows": "0",
        "aggregate_ready": "0",
        "target_intake": "v53s",
    },
    {
        "aggregate_artifact": "reviewer_conflict_rows.csv",
        "source_chunk_artifact_family": "reviewer_conflict_rows.csv",
        "expected_rows": v53u["expected_conflict_disclosure_rows"],
        "accepted_rows": "0",
        "aggregate_ready": "0",
        "target_intake": "v53s",
    },
    {
        "aggregate_artifact": "acceptance_summary.json",
        "source_chunk_artifact_family": "aggregate_hash_summary",
        "expected_rows": "1",
        "accepted_rows": "0",
        "aggregate_ready": "0",
        "target_intake": "v53s",
    },
]
write_csv(run_dir / "review_return_aggregate_artifact_rows.csv", list(aggregate_artifact_rows[0].keys()), aggregate_artifact_rows)

operator_readme = """# v53w Review Return Chunk Execution Queue

This bundle turns the v53u reviewer workload chunks into concrete chunk-return
paths. It does not contain review judgments. Populate chunk files under an
external return directory, merge them into the five aggregate v53s artifacts,
then run v53s/v53v again.

Expected aggregate return artifacts:

- human_review_rows.csv: 7000 rows
- adjudication_rows.csv: 1000 rows
- reviewer_identity_rows.csv: 21 rows
- reviewer_conflict_rows.csv: 210 rows
- acceptance_summary.json: hashes and accepted row counts
"""
(operator_dir / "README.md").write_text(operator_readme, encoding="utf-8")

verify_script = operator_dir / "VERIFY_CHUNK_QUEUE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/review_return_chunk_execution_rows.csv"
  "$BUNDLE_DIR/review_return_chunk_task_rows.csv"
  "$BUNDLE_DIR/review_return_chunk_artifact_rows.csv"
  "$BUNDLE_DIR/review_return_aggregate_artifact_rows.csv"
  "$BUNDLE_DIR/source_v53u/reviewer_workload_chunk_rows.csv"
  "$BUNDLE_DIR/source_v53v/complete_source_review_return_acceptance_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53w chunk queue file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/review_return_chunk_execution_rows.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 chunk execution rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_chunk_task_rows.csv" | tr -d ' ')" == "8001" ]] || { echo "expected 8000 chunk task rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_chunk_artifact_rows.csv" | tr -d ' ')" == "51" ]] || { echo "expected 50 chunk artifact rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_aggregate_artifact_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected 5 aggregate artifact rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v53w bundle" >&2
  exit 1
fi

echo "v53w review return chunk queue shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

command_rows = [
    {
        "command_id": "verify-chunk-queue-shape",
        "command": "results/v53w_complete_source_review_return_chunk_execution_queue/queue_001/operator_bundle/VERIFY_CHUNK_QUEUE.sh",
        "ready_to_run_now": "1",
        "expected_return": "chunk queue files and counts are shape-valid",
    },
    {
        "command_id": "dispatch-review-chunks",
        "command": "external-review-team-populates /path/to/v53_review_chunk_return/chunks/<review_chunk_id>/",
        "ready_to_run_now": "1",
        "expected_return": "50 chunk artifacts across 21 reviewer chunks",
    },
    {
        "command_id": "merge-chunks-into-v53s-aggregate",
        "command": "merge chunk artifacts into /path/to/v53_review_return/{human_review_rows.csv,adjudication_rows.csv,reviewer_identity_rows.csv,reviewer_conflict_rows.csv,acceptance_summary.json}",
        "ready_to_run_now": "0",
        "expected_return": "five aggregate artifacts accepted by v53s",
    },
    {
        "command_id": "refresh-v53s-v53v",
        "command": "V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return V53S_REUSE_EXISTING=0 ./experiments/run_v53s_complete_source_review_return_intake.sh && V53V_REUSE_EXISTING=0 ./experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh",
        "ready_to_run_now": "0",
        "expected_return": "answer_review_accepted_rows=7000",
    },
]
write_csv(run_dir / "review_return_chunk_command_rows.csv", list(command_rows[0].keys()), command_rows)

human_task_rows = sum(1 for row in task_rows if row["task_type"] == "human-review")
adjudication_task_rows = sum(1 for row in task_rows if row["task_type"] == "adjudication")
ready_dispatch_rows = sum(1 for row in execution_rows if row["chunk_dispatch_ready"] == "1")
human_artifact_rows = sum(1 for row in chunk_artifact_rows if row["artifact_family"] == "human_review_rows.csv")
adjudication_artifact_rows = sum(1 for row in chunk_artifact_rows if row["artifact_family"] == "adjudication_rows.csv")
identity_artifact_rows = sum(1 for row in chunk_artifact_rows if row["artifact_family"] == "reviewer_identity_rows.csv")
conflict_artifact_rows = sum(1 for row in chunk_artifact_rows if row["artifact_family"] == "reviewer_conflict_rows.csv")
chunk_dispatch_ready = int(ready_dispatch_rows == len(execution_rows))

requirement_rows = [
    {"requirement_id": "v53u-operator-bundle-input", "status": "pass", "required_value": "1", "actual_value": v53u["v53u_complete_source_review_return_operator_bundle_ready"], "reason": "v53u review-return operator bundle is bound"},
    {"requirement_id": "v53v-acceptance-bridge-input", "status": "pass", "required_value": "1", "actual_value": v53v["v53v_complete_source_review_return_acceptance_bridge_ready"], "reason": "v53v acceptance bridge is bound"},
    {"requirement_id": "review-chunk-dispatch-coverage", "status": status(chunk_dispatch_ready), "required_value": "21 chunks / 8000 tasks", "actual_value": f"{ready_dispatch_rows} chunks / {len(task_rows)} tasks", "reason": "all human/adjudication tasks are assigned to reviewer chunks"},
    {"requirement_id": "chunk-return-artifact-surface", "status": status(len(chunk_artifact_rows) == 50), "required_value": "50 chunk artifacts", "actual_value": str(len(chunk_artifact_rows)), "reason": "chunk artifact family rows cover human/adjudication/identity/conflict returns"},
    {"requirement_id": "aggregate-v53s-artifact-surface", "status": status(len(aggregate_artifact_rows) == 5), "required_value": "5 aggregate artifacts", "actual_value": str(len(aggregate_artifact_rows)), "reason": "aggregate surface matches v53s required artifacts"},
    {"requirement_id": "actual-review-return", "status": "blocked", "required_value": "7000 accepted answer reviews", "actual_value": v53v["answer_review_accepted_rows"], "reason": "v53w queues return execution but does not fabricate review rows"},
]
write_csv(run_dir / "review_return_chunk_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "review-chunk-dispatch-coverage", "status": "ready" if chunk_dispatch_ready else "blocked", "reason": f"ready_review_chunk_dispatch_rows={ready_dispatch_rows}/{len(execution_rows)}"},
    {"gap": "chunk-return-artifacts", "status": "blocked", "reason": "accepted_chunk_return_artifacts=0/50"},
    {"gap": "aggregate-review-return-artifacts", "status": "blocked", "reason": "accepted_aggregate_return_artifacts=0/5"},
    {"gap": "v53s-review-return-ready", "status": "blocked", "reason": "review_return_ready=0"},
    {"gap": "v53v-answer-review-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53v['answer_review_accepted_rows']}/7000"},
    {"gap": "v53-ready", "status": "blocked", "reason": "actual review return is still absent"},
    {"gap": "v1.0-comparison-ready", "status": "blocked", "reason": "human-reviewed complete-source audit is incomplete"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53w_complete_source_review_return_chunk_execution_queue_metrics",
    "v53u_complete_source_review_return_operator_bundle_ready": v53u["v53u_complete_source_review_return_operator_bundle_ready"],
    "v53v_complete_source_review_return_acceptance_bridge_ready": v53v["v53v_complete_source_review_return_acceptance_bridge_ready"],
    "review_chunk_rows": str(len(execution_rows)),
    "ready_review_chunk_dispatch_rows": str(ready_dispatch_rows),
    "review_chunk_task_rows": str(len(task_rows)),
    "human_review_chunk_task_rows": str(human_task_rows),
    "adjudication_chunk_task_rows": str(adjudication_task_rows),
    "review_chunk_return_artifact_rows": str(len(chunk_artifact_rows)),
    "human_review_chunk_artifact_rows": str(human_artifact_rows),
    "adjudication_chunk_artifact_rows": str(adjudication_artifact_rows),
    "reviewer_identity_chunk_artifact_rows": str(identity_artifact_rows),
    "reviewer_conflict_chunk_artifact_rows": str(conflict_artifact_rows),
    "aggregate_review_return_artifact_rows": str(len(aggregate_artifact_rows)),
    "expected_human_review_rows": v53u["expected_human_review_rows"],
    "accepted_human_review_rows": v53u["accepted_human_review_rows"],
    "expected_adjudication_rows": v53u["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53u["accepted_adjudication_rows"],
    "expected_reviewer_identity_rows": v53u["expected_reviewer_identity_rows"],
    "accepted_reviewer_identity_rows": v53u["accepted_reviewer_identity_rows"],
    "expected_conflict_disclosure_rows": v53u["expected_conflict_disclosure_rows"],
    "accepted_conflict_disclosure_rows": v53u["accepted_conflict_disclosure_rows"],
    "answer_review_accepted_rows": v53v["answer_review_accepted_rows"],
    "chunk_dispatch_ready": str(chunk_dispatch_ready),
    "chunk_return_intake_ready": "0",
    "aggregate_review_return_ready": "0",
    "review_return_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "review_return_chunk_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53w_complete_source_review_return_chunk_execution_queue_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53u-operator-bundle-input", "status": "pass", "reason": "v53u bundle is bound"},
    {"gate": "v53v-acceptance-bridge-input", "status": "pass", "reason": "v53v acceptance bridge is bound"},
    {"gate": "review-chunk-dispatch-coverage", "status": "pass" if chunk_dispatch_ready else "blocked", "reason": f"ready_review_chunk_dispatch_rows={ready_dispatch_rows}/{len(execution_rows)}"},
    {"gate": "chunk-return-artifacts", "status": "blocked", "reason": f"accepted_chunk_return_artifacts=0/{len(chunk_artifact_rows)}"},
    {"gate": "aggregate-review-return-artifacts", "status": "blocked", "reason": f"accepted_aggregate_return_artifacts=0/{len(aggregate_artifact_rows)}"},
    {"gate": "answer-review-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53v['answer_review_accepted_rows']}/7000"},
    {"gate": "v53-ready", "status": "blocked", "reason": "actual human/source review return is absent"},
    {"gate": "v1.0-comparison-ready", "status": "blocked", "reason": "human-reviewed complete-source audit is incomplete"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53w Complete Source Review Return Chunk Execution Queue Boundary

This artifact turns the v53u reviewer workload chunks into a concrete
chunk-return execution queue. It does not create human review judgments and does
not make v53 or v1.0 comparison ready.

Evidence emitted:

- review_chunk_rows={len(execution_rows)}
- ready_review_chunk_dispatch_rows={ready_dispatch_rows}
- review_chunk_task_rows={len(task_rows)}
- human_review_chunk_task_rows={human_task_rows}
- adjudication_chunk_task_rows={adjudication_task_rows}
- review_chunk_return_artifact_rows={len(chunk_artifact_rows)}
- aggregate_review_return_artifact_rows={len(aggregate_artifact_rows)}
- expected_human_review_rows={v53u['expected_human_review_rows']}
- accepted_human_review_rows={v53u['accepted_human_review_rows']}
- expected_adjudication_rows={v53u['expected_adjudication_rows']}
- accepted_adjudication_rows={v53u['accepted_adjudication_rows']}
- answer_review_accepted_rows={v53v['answer_review_accepted_rows']}
- chunk_dispatch_ready={chunk_dispatch_ready}
- chunk_return_intake_ready=0
- aggregate_review_return_ready=0
- review_return_ready=0
- v53_ready=0
- v1_0_comparison_ready=0

Allowed wording: complete-source review-return chunk execution queue is
dispatch-ready.

Blocked wording: accepted human/source review return, v53 readiness, v1.0
comparison readiness, quality comparison claim, or release readiness.
"""
(run_dir / "V53W_COMPLETE_SOURCE_REVIEW_RETURN_CHUNK_EXECUTION_QUEUE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53w-complete-source-review-return-chunk-execution-queue",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53w_complete_source_review_return_chunk_execution_queue_ready": 1,
    "source_v53u_summary_sha256": sha256(v53u_summary_path),
    "source_v53v_summary_sha256": sha256(v53v_summary_path),
    "review_chunk_rows": len(execution_rows),
    "ready_review_chunk_dispatch_rows": ready_dispatch_rows,
    "review_chunk_task_rows": len(task_rows),
    "review_chunk_return_artifact_rows": len(chunk_artifact_rows),
    "aggregate_review_return_artifact_rows": len(aggregate_artifact_rows),
    "chunk_dispatch_ready": chunk_dispatch_ready,
    "chunk_return_intake_ready": 0,
    "aggregate_review_return_ready": 0,
    "review_return_ready": 0,
    "v53_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53w_complete_source_review_return_chunk_execution_queue_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53w_complete_source_review_return_chunk_execution_queue_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
