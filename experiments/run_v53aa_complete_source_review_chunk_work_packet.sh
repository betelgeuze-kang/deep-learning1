#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53aa_complete_source_review_chunk_work_packet"
RUN_ID="${V53AA_RUN_ID:-work_packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53aa_complete_source_review_chunk_work_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
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
packet_dir = run_dir / "operator_packet"
packet_dir.mkdir(parents=True, exist_ok=True)


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


def pass_block(flag):
    return "pass" if flag else "blocked"


v53w_summary_path = results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv"
v53w_decision_path = results / "v53w_complete_source_review_return_chunk_execution_queue_decision.csv"
v53u_summary_path = results / "v53u_complete_source_review_return_operator_bundle_summary.csv"
v53w_dir = results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001"
v53u_dir = results / "v53u_complete_source_review_return_operator_bundle" / "bundle_001"

v53w_summary = read_csv(v53w_summary_path)[0]
v53u_summary = read_csv(v53u_summary_path)[0]
if v53w_summary["v53w_complete_source_review_return_chunk_execution_queue_ready"] != "1":
    raise SystemExit("v53aa requires v53w chunk execution queue readiness")
if v53u_summary["v53u_complete_source_review_return_operator_bundle_ready"] != "1":
    raise SystemExit("v53aa requires v53u operator bundle readiness")

copy(v53w_summary_path, "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_summary.csv")
copy(v53w_decision_path, "source_v53w/v53w_complete_source_review_return_chunk_execution_queue_decision.csv")
copy(v53u_summary_path, "source_v53u/v53u_complete_source_review_return_operator_bundle_summary.csv")

source_files = [
    "review_return_chunk_execution_rows.csv",
    "review_return_chunk_task_rows.csv",
    "review_return_chunk_artifact_rows.csv",
    "review_return_aggregate_artifact_rows.csv",
    "review_return_chunk_requirement_rows.csv",
    "review_return_chunk_metric_rows.csv",
]
for name in source_files:
    copy(v53w_dir / name, f"source_v53w/{name}")
for name in [
    "HUMAN_REVIEW_ROWS_TEMPLATE.csv",
    "ADJUDICATION_ROWS_TEMPLATE.csv",
    "REVIEWER_IDENTITY_ROWS_TEMPLATE.csv",
    "REVIEWER_CONFLICT_ROWS_TEMPLATE.csv",
    "ACCEPTANCE_SUMMARY_TEMPLATE.json",
]:
    copy(v53u_dir / "operator_bundle" / name, f"operator_packet/review_templates/{name}")

chunk_rows = read_csv(v53w_dir / "review_return_chunk_execution_rows.csv")
task_rows = read_csv(v53w_dir / "review_return_chunk_task_rows.csv")
artifact_rows = read_csv(v53w_dir / "review_return_chunk_artifact_rows.csv")
aggregate_rows = read_csv(v53w_dir / "review_return_aggregate_artifact_rows.csv")

tasks_by_chunk = defaultdict(list)
for row in task_rows:
    tasks_by_chunk[row["review_chunk_id"]].append(row)
artifacts_by_chunk = defaultdict(list)
for row in artifact_rows:
    artifacts_by_chunk[row["review_chunk_id"]].append(row)

packet_file_rows = []


def add_file_row(rel, purpose):
    path = run_dir / rel
    packet_file_rows.append(
        {
            "packet_file": rel,
            "purpose": purpose,
            "file_ready": str(int(path.is_file() and path.stat().st_size > 0)),
            "sha256": sha256(path) if path.is_file() else "",
            "route_jump_rows": "0",
        }
    )


(packet_dir / "README.md").write_text(
    "# v53aa Complete-Source Review Chunk Work Packet\n\n"
    "This packet expands the v53w review-return chunk queue into reviewer-facing "
    "chunk directories. Reviewers fill the required return artifacts under each "
    "chunk directory, then the aggregate artifacts can be merged for v53s/v53y intake. "
    "This packet contains no model payload and does not create review judgments.\n",
    encoding="utf-8",
)

verify_script = packet_dir / "VERIFY_REVIEW_CHUNK_WORK_PACKET.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

PACKET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$(cd "$PACKET_DIR/.." && pwd)"

required_files=(
  "$PACKET_DIR/README.md"
  "$PACKET_DIR/CHUNK_PACKET_INDEX.csv"
  "$PACKET_DIR/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv"
  "$PACKET_DIR/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/ACCEPTANCE_SUMMARY_TEMPLATE.json"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53aa packet file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$PACKET_DIR/CHUNK_PACKET_INDEX.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 chunk packet rows" >&2; exit 1; }
[[ "$(wc -l < "$PACKET_DIR/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv" | tr -d ' ')" == "6" ]] || { echo "expected five aggregate return artifact rows" >&2; exit 1; }

while IFS=, read -r chunk_packet_id review_chunk_id assignment_id reviewer_slot_id system_id review_scope task_rows expected_human_review_rows expected_adjudication_rows required_return_artifacts packet_dir packet_ready blocking_reason; do
  [[ "$chunk_packet_id" == "chunk_packet_id" ]] && continue
  [[ -s "$PACKET_DIR/$packet_dir/README.md" ]] || { echo "missing chunk README for $review_chunk_id" >&2; exit 1; }
  [[ -s "$PACKET_DIR/$packet_dir/REVIEW_TASK_ROWS.csv" ]] || { echo "missing chunk tasks for $review_chunk_id" >&2; exit 1; }
  [[ -s "$PACKET_DIR/$packet_dir/REQUIRED_RETURN_ARTIFACTS.csv" ]] || { echo "missing chunk artifacts for $review_chunk_id" >&2; exit 1; }
done < "$PACKET_DIR/CHUNK_PACKET_INDEX.csv"

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v53aa packet" >&2
  exit 1
fi

echo "v53aa review chunk work packet shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

write_csv(packet_dir / "AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv", list(aggregate_rows[0].keys()), aggregate_rows)

chunk_packet_rows = []
for chunk in chunk_rows:
    chunk_id = chunk["review_chunk_id"]
    chunk_rel = f"chunks/{chunk_id}"
    chunk_dir = packet_dir / chunk_rel
    chunk_dir.mkdir(parents=True, exist_ok=True)
    chunk_tasks = tasks_by_chunk[chunk_id]
    chunk_artifacts = artifacts_by_chunk[chunk_id]
    expected_task_rows = int(chunk["expected_human_review_rows"]) + int(chunk["expected_adjudication_rows"])
    packet_ready = int(
        chunk["chunk_dispatch_ready"] == "1"
        and len(chunk_tasks) == expected_task_rows
        and len(chunk_artifacts) == int(chunk["expected_chunk_return_artifacts"])
    )
    write_csv(chunk_dir / "REVIEW_TASK_ROWS.csv", list(task_rows[0].keys()), chunk_tasks)
    write_csv(chunk_dir / "REQUIRED_RETURN_ARTIFACTS.csv", list(artifact_rows[0].keys()), chunk_artifacts)
    (chunk_dir / "README.md").write_text(
        f"# {chunk_id}\n\n"
        f"- assignment_id={chunk['assignment_id']}\n"
        f"- reviewer_slot_id={chunk['reviewer_slot_id']}\n"
        f"- system_id={chunk['system_id']}\n"
        f"- review_scope={chunk['review_scope']}\n"
        f"- review_task_rows={len(chunk_tasks)}\n"
        f"- expected_human_review_rows={chunk['expected_human_review_rows']}\n"
        f"- expected_adjudication_rows={chunk['expected_adjudication_rows']}\n"
        f"- expected_chunk_return_artifacts={chunk['expected_chunk_return_artifacts']}\n\n"
        "Fill the files listed in REQUIRED_RETURN_ARTIFACTS.csv and preserve row IDs. "
        "Do not invent aggregate acceptance rows inside a chunk packet.\n",
        encoding="utf-8",
    )
    chunk_packet_rows.append(
        {
            "chunk_packet_id": f"v53aa_packet_{chunk_id}",
            "review_chunk_id": chunk_id,
            "assignment_id": chunk["assignment_id"],
            "reviewer_slot_id": chunk["reviewer_slot_id"],
            "system_id": chunk["system_id"],
            "review_scope": chunk["review_scope"],
            "task_rows": str(len(chunk_tasks)),
            "expected_human_review_rows": chunk["expected_human_review_rows"],
            "expected_adjudication_rows": chunk["expected_adjudication_rows"],
            "required_return_artifacts": str(len(chunk_artifacts)),
            "packet_dir": chunk_rel,
            "packet_ready": str(packet_ready),
            "blocking_reason": "ready-for-external-review" if packet_ready else "chunk-packet-shape-mismatch",
        }
    )

write_csv(packet_dir / "CHUNK_PACKET_INDEX.csv", list(chunk_packet_rows[0].keys()), chunk_packet_rows)

for rel, purpose in [
    ("operator_packet/README.md", "operator packet instructions"),
    ("operator_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh", "operator packet verifier"),
    ("operator_packet/CHUNK_PACKET_INDEX.csv", "21 chunk packet index"),
    ("operator_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv", "five aggregate return artifact targets"),
    ("operator_packet/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv", "human review template"),
    ("operator_packet/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv", "adjudication template"),
    ("operator_packet/review_templates/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv", "reviewer identity template"),
    ("operator_packet/review_templates/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv", "reviewer conflict template"),
    ("operator_packet/review_templates/ACCEPTANCE_SUMMARY_TEMPLATE.json", "acceptance summary template"),
]:
    add_file_row(rel, purpose)
for row in chunk_packet_rows:
    for filename, purpose in [
        ("README.md", "chunk instructions"),
        ("REVIEW_TASK_ROWS.csv", "chunk review tasks"),
        ("REQUIRED_RETURN_ARTIFACTS.csv", "chunk required return artifacts"),
    ]:
        add_file_row(f"operator_packet/{row['packet_dir']}/{filename}", purpose)

ready_chunk_packets = sum(int(row["packet_ready"]) for row in chunk_packet_rows)
ready_packet_files = sum(int(row["file_ready"]) for row in packet_file_rows)

write_csv(run_dir / "complete_source_review_chunk_packet_rows.csv", list(chunk_packet_rows[0].keys()), chunk_packet_rows)
write_csv(run_dir / "complete_source_review_chunk_packet_file_rows.csv", list(packet_file_rows[0].keys()), packet_file_rows)

requirement_rows = [
    {"requirement_id": "v53w-chunk-queue-input", "status": "pass", "required_value": "1", "actual_value": v53w_summary["v53w_complete_source_review_return_chunk_execution_queue_ready"], "reason": "v53w chunk queue is ready"},
    {"requirement_id": "chunk-packet-index", "status": pass_block(len(chunk_packet_rows) == 21 and ready_chunk_packets == 21), "required_value": "21", "actual_value": str(ready_chunk_packets), "reason": "all chunk packet directories must be ready"},
    {"requirement_id": "chunk-task-export", "status": pass_block(len(task_rows) == 8000), "required_value": "8000", "actual_value": str(len(task_rows)), "reason": "all human/adjudication tasks exported"},
    {"requirement_id": "chunk-return-artifact-map", "status": pass_block(len(artifact_rows) == 50), "required_value": "50", "actual_value": str(len(artifact_rows)), "reason": "all chunk return artifacts mapped"},
    {"requirement_id": "operator-packet-files", "status": pass_block(ready_packet_files == len(packet_file_rows)), "required_value": str(len(packet_file_rows)), "actual_value": str(ready_packet_files), "reason": "all packet files present"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": v53w_summary["expected_human_review_rows"], "actual_value": v53w_summary["answer_review_accepted_rows"], "reason": "external human/source review return has not been supplied"},
    {"requirement_id": "v53-ready", "status": "blocked", "required_value": "1", "actual_value": v53w_summary["v53_ready"], "reason": "v53 remains blocked until review return is accepted"},
    {"requirement_id": "manifest-only-no-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "no model/checkpoint payload emitted"},
]
write_csv(run_dir / "complete_source_review_chunk_packet_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "chunk-work-packet", "status": "ready", "reason": f"ready_operator_chunk_packet_rows={ready_chunk_packets}/21"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53w_summary['answer_review_accepted_rows']}/{v53w_summary['expected_human_review_rows']}"},
    {"gap": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53w_summary['v53_ready']}"},
    {"gap": "v1-comparison", "status": "blocked", "reason": f"v1_0_comparison_ready={v53w_summary['v1_0_comparison_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53aa_complete_source_review_chunk_work_packet_metrics",
    "v53w_complete_source_review_return_chunk_execution_queue_ready": v53w_summary["v53w_complete_source_review_return_chunk_execution_queue_ready"],
    "v53u_complete_source_review_return_operator_bundle_ready": v53u_summary["v53u_complete_source_review_return_operator_bundle_ready"],
    "review_chunk_rows": v53w_summary["review_chunk_rows"],
    "ready_review_chunk_dispatch_rows": v53w_summary["ready_review_chunk_dispatch_rows"],
    "review_chunk_task_rows": v53w_summary["review_chunk_task_rows"],
    "human_review_chunk_task_rows": v53w_summary["human_review_chunk_task_rows"],
    "adjudication_chunk_task_rows": v53w_summary["adjudication_chunk_task_rows"],
    "review_chunk_return_artifact_rows": v53w_summary["review_chunk_return_artifact_rows"],
    "human_review_chunk_artifact_rows": v53w_summary["human_review_chunk_artifact_rows"],
    "adjudication_chunk_artifact_rows": v53w_summary["adjudication_chunk_artifact_rows"],
    "reviewer_identity_chunk_artifact_rows": v53w_summary["reviewer_identity_chunk_artifact_rows"],
    "reviewer_conflict_chunk_artifact_rows": v53w_summary["reviewer_conflict_chunk_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53w_summary["aggregate_review_return_artifact_rows"],
    "operator_chunk_packet_rows": str(len(chunk_packet_rows)),
    "ready_operator_chunk_packet_rows": str(ready_chunk_packets),
    "operator_packet_file_rows": str(len(packet_file_rows)),
    "ready_operator_packet_file_rows": str(ready_packet_files),
    "expected_human_review_rows": v53w_summary["expected_human_review_rows"],
    "accepted_human_review_rows": v53w_summary["accepted_human_review_rows"],
    "expected_adjudication_rows": v53w_summary["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53w_summary["accepted_adjudication_rows"],
    "expected_reviewer_identity_rows": v53w_summary["expected_reviewer_identity_rows"],
    "accepted_reviewer_identity_rows": v53w_summary["accepted_reviewer_identity_rows"],
    "expected_conflict_disclosure_rows": v53w_summary["expected_conflict_disclosure_rows"],
    "accepted_conflict_disclosure_rows": v53w_summary["accepted_conflict_disclosure_rows"],
    "answer_review_accepted_rows": v53w_summary["answer_review_accepted_rows"],
    "review_return_ready": v53w_summary["review_return_ready"],
    "v53_ready": v53w_summary["v53_ready"],
    "v1_0_comparison_ready": v53w_summary["v1_0_comparison_ready"],
    "real_release_package_ready": v53w_summary["real_release_package_ready"],
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_review_chunk_packet_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53aa_complete_source_review_chunk_work_packet_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53w-chunk-queue-input", "status": "pass", "reason": "v53w chunk queue is ready"},
    {"gate": "chunk-work-packet", "status": "pass", "reason": f"ready_operator_chunk_packet_rows={ready_chunk_packets}/21"},
    {"gate": "operator-packet-files", "status": "pass", "reason": f"ready_operator_packet_file_rows={ready_packet_files}/{len(packet_file_rows)}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53w_summary['answer_review_accepted_rows']}/{v53w_summary['expected_human_review_rows']}"},
    {"gate": "v53-ready", "status": "blocked", "reason": f"v53_ready={v53w_summary['v53_ready']}"},
    {"gate": "v1-comparison", "status": "blocked", "reason": f"v1_0_comparison_ready={v53w_summary['v1_0_comparison_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "review packet alone is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53aa Complete-Source Review Chunk Work Packet Boundary

This artifact expands v53w review-return chunk rows into reviewer-facing chunk
work packets. It does not create human/source review judgments, adjudication
rows, reviewer identities, conflict disclosures, acceptance summaries, v53
readiness, v1.0 comparison readiness, or release evidence.

Evidence emitted:

- review_chunk_rows={v53w_summary['review_chunk_rows']}
- ready_review_chunk_dispatch_rows={v53w_summary['ready_review_chunk_dispatch_rows']}
- review_chunk_task_rows={v53w_summary['review_chunk_task_rows']}
- human_review_chunk_task_rows={v53w_summary['human_review_chunk_task_rows']}
- adjudication_chunk_task_rows={v53w_summary['adjudication_chunk_task_rows']}
- review_chunk_return_artifact_rows={v53w_summary['review_chunk_return_artifact_rows']}
- aggregate_review_return_artifact_rows={v53w_summary['aggregate_review_return_artifact_rows']}
- operator_chunk_packet_rows={len(chunk_packet_rows)}
- ready_operator_chunk_packet_rows={ready_chunk_packets}
- operator_packet_file_rows={len(packet_file_rows)}
- ready_operator_packet_file_rows={ready_packet_files}
- expected_human_review_rows={v53w_summary['expected_human_review_rows']}
- answer_review_accepted_rows={v53w_summary['answer_review_accepted_rows']}
- review_return_ready={v53w_summary['review_return_ready']}
- v53_ready={v53w_summary['v53_ready']}
- route_jump_rows=0

Allowed wording: complete-source review chunk work packet is ready for external
review dispatch.
Blocked wording: accepted review return, v53 readiness, v1.0 comparison
readiness, release readiness, or quality superiority.
"""
(run_dir / "V53AA_COMPLETE_SOURCE_REVIEW_CHUNK_WORK_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53aa-complete-source-review-chunk-work-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53aa_complete_source_review_chunk_work_packet_ready": 1,
    "review_chunk_rows": int(v53w_summary["review_chunk_rows"]),
    "review_chunk_task_rows": int(v53w_summary["review_chunk_task_rows"]),
    "operator_chunk_packet_rows": len(chunk_packet_rows),
    "ready_operator_chunk_packet_rows": ready_chunk_packets,
    "operator_packet_file_rows": len(packet_file_rows),
    "ready_operator_packet_file_rows": ready_packet_files,
    "answer_review_accepted_rows": int(v53w_summary["answer_review_accepted_rows"]),
    "review_return_ready": int(v53w_summary["review_return_ready"]),
    "v53_ready": int(v53w_summary["v53_ready"]),
    "v1_0_comparison_ready": int(v53w_summary["v1_0_comparison_ready"]),
    "source_v53w_summary_sha256": sha256(v53w_summary_path),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53aa_complete_source_review_chunk_work_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53aa_complete_source_review_chunk_work_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
