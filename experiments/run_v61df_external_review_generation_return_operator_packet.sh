#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61df_external_review_generation_return_operator_packet"
RUN_ID="${V61DF_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61df_external_review_generation_return_operator_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

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
packet_dir = run_dir / "operator_packet"
packet_dir.mkdir(parents=True, exist_ok=True)


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


summary_paths = {
    "v53u": results / "v53u_complete_source_review_return_operator_bundle_summary.csv",
    "v53w": results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv",
    "v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_summary.csv",
    "v61ct": results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
    "v61de": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
}
decision_paths = {
    "v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_decision.csv",
    "v61de": results / "v61de_post_review_generation_result_handoff_bridge_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for name, ready_field in [
    ("v53u", "v53u_complete_source_review_return_operator_bundle_ready"),
    ("v53w", "v53w_complete_source_review_return_chunk_execution_queue_ready"),
    ("v53z", "v53z_complete_source_review_return_v61_handoff_bridge_ready"),
    ("v61ct", "v61ct_complete_source_generation_execution_operator_bundle_ready"),
    ("v61de", "v61de_post_review_generation_result_handoff_bridge_ready"),
]:
    if summaries[name].get(ready_field) != "1":
        raise SystemExit(f"v61df requires {ready_field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

v53u_dir = results / "v53u_complete_source_review_return_operator_bundle" / "bundle_001"
v53w_dir = results / "v53w_complete_source_review_return_chunk_execution_queue" / "queue_001"
v53z_dir = results / "v53z_complete_source_review_return_v61_handoff_bridge" / "bridge_001"
v61ct_dir = results / "v61ct_complete_source_generation_execution_operator_bundle" / "bundle_001"
v61de_dir = results / "v61de_post_review_generation_result_handoff_bridge" / "bridge_001"

source_files = [
    (v53u_dir / "operator_bundle/HUMAN_REVIEW_ROWS_TEMPLATE.csv", "operator_packet/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv"),
    (v53u_dir / "operator_bundle/ADJUDICATION_ROWS_TEMPLATE.csv", "operator_packet/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv"),
    (v53u_dir / "operator_bundle/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv", "operator_packet/review_templates/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv"),
    (v53u_dir / "operator_bundle/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv", "operator_packet/review_templates/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv"),
    (v53u_dir / "operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json", "operator_packet/review_templates/ACCEPTANCE_SUMMARY_TEMPLATE.json"),
    (v53u_dir / "review_return_expected_artifact_rows.csv", "source_v53u/review_return_expected_artifact_rows.csv"),
    (v53w_dir / "review_return_chunk_execution_rows.csv", "source_v53w/review_return_chunk_execution_rows.csv"),
    (v53w_dir / "review_return_chunk_task_rows.csv", "source_v53w/review_return_chunk_task_rows.csv"),
    (v53w_dir / "review_return_chunk_artifact_rows.csv", "source_v53w/review_return_chunk_artifact_rows.csv"),
    (v53w_dir / "review_return_aggregate_artifact_rows.csv", "source_v53w/review_return_aggregate_artifact_rows.csv"),
    (v53z_dir / "review_return_v61_handoff_stage_rows.csv", "source_v53z/review_return_v61_handoff_stage_rows.csv"),
    (v61ct_dir / "operator_bundle/GENERATION_EXECUTION_ENV.template", "operator_packet/generation_templates/GENERATION_EXECUTION_ENV.template"),
    (v61ct_dir / "operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv", "operator_packet/generation_templates/GENERATION_RESULT_RETURN_TEMPLATE.csv"),
    (v61ct_dir / "complete_source_generation_execution_operator_command_rows.csv", "source_v61ct/complete_source_generation_execution_operator_command_rows.csv"),
    (v61de_dir / "post_review_generation_result_handoff_stage_rows.csv", "source_v61de/post_review_generation_result_handoff_stage_rows.csv"),
    (v61de_dir / "post_review_generation_result_handoff_command_rows.csv", "source_v61de/post_review_generation_result_handoff_command_rows.csv"),
]
for src, dst in source_files:
    copy(src, dst)

v53u = summaries["v53u"]
v53w = summaries["v53w"]
v53z = summaries["v53z"]
v61ct = summaries["v61ct"]
v61de = summaries["v61de"]

review_expected_rows = [
    {
        "external_return_family": "aggregate-review-return",
        "return_artifact": "human_review_rows.csv",
        "expected_rows": v53z["expected_human_review_rows"],
        "accepted_rows": v53z["accepted_human_review_rows"],
        "target_env_var": "V53Z_REVIEW_RETURN_DIR",
        "current_status": "blocked",
    },
    {
        "external_return_family": "aggregate-review-return",
        "return_artifact": "adjudication_rows.csv",
        "expected_rows": v53z["expected_adjudication_rows"],
        "accepted_rows": v53z["accepted_adjudication_rows"],
        "target_env_var": "V53Z_REVIEW_RETURN_DIR",
        "current_status": "blocked",
    },
    {
        "external_return_family": "aggregate-review-return",
        "return_artifact": "reviewer_identity_rows.csv",
        "expected_rows": v53u["expected_reviewer_identity_rows"],
        "accepted_rows": v53u["accepted_reviewer_identity_rows"],
        "target_env_var": "V53Z_REVIEW_RETURN_DIR",
        "current_status": "blocked",
    },
    {
        "external_return_family": "aggregate-review-return",
        "return_artifact": "reviewer_conflict_rows.csv",
        "expected_rows": v53u["expected_conflict_disclosure_rows"],
        "accepted_rows": v53u["accepted_conflict_disclosure_rows"],
        "target_env_var": "V53Z_REVIEW_RETURN_DIR",
        "current_status": "blocked",
    },
    {
        "external_return_family": "aggregate-review-return",
        "return_artifact": "acceptance_summary.json",
        "expected_rows": "1",
        "accepted_rows": "0",
        "target_env_var": "V53Z_REVIEW_RETURN_DIR",
        "current_status": "blocked",
    },
]
write_csv(packet_dir / "REVIEW_RETURN_REQUIRED_ARTIFACTS.csv", list(review_expected_rows[0].keys()), review_expected_rows)

generation_expected_rows = []
for row in read_csv(v61ct_dir / "operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv"):
    generation_expected_rows.append(
        {
            "external_return_family": "generation-result-return",
            "return_artifact": row["result_artifact"],
            "expected_rows": "1000" if row["result_artifact"].endswith(".csv") else "1",
            "accepted_rows": "0",
            "target_env_var": "V61DE_GENERATION_RESULT_DIR",
            "current_status": row["current_status"],
        }
    )
write_csv(packet_dir / "GENERATION_RESULT_REQUIRED_ARTIFACTS.csv", list(generation_expected_rows[0].keys()), generation_expected_rows)

stage_rows = [
    {
        "operator_stage_id": "01-review-return-operator-templates",
        "source_gate": "v53u/v53w",
        "stage_status": "ready",
        "expected_return": "review templates and 21 chunks",
        "actual_return": f"review_chunk_rows={v53w['review_chunk_rows']}; review_chunk_return_artifact_rows={v53w['review_chunk_return_artifact_rows']}",
        "blocking_reason": "ready",
    },
    {
        "operator_stage_id": "02-v53-to-v61-handoff",
        "source_gate": "v53z",
        "stage_status": "ready",
        "expected_return": "v53z handoff ready",
        "actual_return": f"ready_handoff_stage_rows={v53z['ready_handoff_stage_rows']}/{v53z['handoff_stage_rows']}",
        "blocking_reason": "ready",
    },
    {
        "operator_stage_id": "03-generation-result-operator-templates",
        "source_gate": "v61ct/v61de",
        "stage_status": "ready",
        "expected_return": "generation result templates and post-review chain",
        "actual_return": f"expected_generation_result_artifacts={v61de['expected_generation_result_artifacts']}",
        "blocking_reason": "ready",
    },
    {
        "operator_stage_id": "04-review-return-accepted",
        "source_gate": "v53z/v61de",
        "stage_status": "blocked",
        "expected_return": "answer_review_accepted_rows=7000",
        "actual_return": f"answer_review_accepted_rows={v61de['answer_review_accepted_rows']}/{v61de['expected_human_review_rows']}",
        "blocking_reason": "external review return absent",
    },
    {
        "operator_stage_id": "05-generation-execution-admitted",
        "source_gate": "v61de",
        "stage_status": "blocked",
        "expected_return": "generation_execution_admitted_rows=1000",
        "actual_return": f"generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}",
        "blocking_reason": "generation execution admission remains closed",
    },
    {
        "operator_stage_id": "06-generation-result-accepted",
        "source_gate": "v61de",
        "stage_status": "blocked",
        "expected_return": "accepted_generation_result_artifacts=5",
        "actual_return": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}",
        "blocking_reason": "external generation result return absent",
    },
    {
        "operator_stage_id": "07-actual-generation-ready",
        "source_gate": "v61de",
        "stage_status": "blocked",
        "expected_return": "actual_model_generation_ready=1",
        "actual_return": f"actual_model_generation_ready={v61de['actual_model_generation_ready']}",
        "blocking_reason": "actual generation remains unproven",
    },
]
write_csv(run_dir / "external_return_operator_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(1 for row in stage_rows if row["stage_status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

command_rows = [
    {
        "command_id": "verify-external-return-packet",
        "command": "results/v61df_external_review_generation_return_operator_packet/packet_001/operator_packet/VERIFY_EXTERNAL_RETURN_PACKET.sh",
        "ready_to_run_now": "1",
        "expected_return": "packet shape and zero-payload boundary verified",
    },
    {
        "command_id": "dispatch-review-work",
        "command": "use REVIEW_RETURN_REQUIRED_ARTIFACTS.csv plus review_templates/",
        "ready_to_run_now": "1",
        "expected_return": "external reviewers produce v53 aggregate review return artifacts",
    },
    {
        "command_id": "refresh-review-return-chain",
        "command": "V53Z_REVIEW_RETURN_DIR=/path/to/v53_review_return V53Z_REUSE_EXISTING=0 ./experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh",
        "ready_to_run_now": "0",
        "expected_return": "answer_review_accepted_rows=7000",
    },
    {
        "command_id": "refresh-post-review-generation-chain",
        "command": "V61DE_REVIEW_RETURN_DIR=/path/to/v53_review_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": "0",
        "expected_return": "generation execution admission can be rechecked after review unblock",
    },
    {
        "command_id": "run-generation-guard",
        "command": "results/v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/RUN_GENERATION_GUARD.sh",
        "ready_to_run_now": "1",
        "expected_return": "guard refuses until generation admission opens",
    },
    {
        "command_id": "intake-generation-results",
        "command": "V61DE_GENERATION_RESULT_DIR=/path/to/generation_result_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": "0",
        "expected_return": "generation result artifacts accepted and final acceptance refreshed",
    },
]
write_csv(run_dir / "external_return_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

packet_files = [
    ("operator_packet/README.md", "operator instructions"),
    ("operator_packet/VERIFY_EXTERNAL_RETURN_PACKET.sh", "shape verifier"),
    ("operator_packet/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv", "review return artifact list"),
    ("operator_packet/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv", "generation result artifact list"),
    ("operator_packet/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv", "human review template"),
    ("operator_packet/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv", "adjudication template"),
    ("operator_packet/generation_templates/GENERATION_RESULT_RETURN_TEMPLATE.csv", "generation result return template"),
    ("operator_packet/generation_templates/GENERATION_EXECUTION_ENV.template", "generation execution env template"),
]

(packet_dir / "README.md").write_text(
    "# v61df External Review and Generation Return Operator Packet\n\n"
    "This packet is the single external-return handoff for the current v53/v61 path. "
    "Fill review artifacts first, refresh v53z/v61de, then only if the generation guard opens, "
    "return generation result artifacts and refresh v61de again. This packet contains no model payload.\n",
    encoding="utf-8",
)
verify_script = packet_dir / "VERIFY_EXTERNAL_RETURN_PACKET.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

PACKET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required_files=(
  "$PACKET_DIR/README.md"
  "$PACKET_DIR/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv"
  "$PACKET_DIR/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv"
  "$PACKET_DIR/review_templates/HUMAN_REVIEW_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/ADJUDICATION_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv"
  "$PACKET_DIR/review_templates/ACCEPTANCE_SUMMARY_TEMPLATE.json"
  "$PACKET_DIR/generation_templates/GENERATION_RESULT_RETURN_TEMPLATE.csv"
  "$PACKET_DIR/generation_templates/GENERATION_EXECUTION_ENV.template"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v61df operator packet file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$PACKET_DIR/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv" | tr -d ' ')" == "6" ]] || { echo "expected five review return artifacts" >&2; exit 1; }
[[ "$(wc -l < "$PACKET_DIR/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv" | tr -d ' ')" == "6" ]] || { echo "expected five generation result artifacts" >&2; exit 1; }

if find "$PACKET_DIR/.." -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v61df packet" >&2
  exit 1
fi

echo "v61df external return operator packet shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

packet_file_rows = []
for rel, purpose in packet_files:
    path = run_dir / rel
    packet_file_rows.append(
        {
            "packet_file": rel,
            "purpose": purpose,
            "file_ready": str(int(path.is_file() and path.stat().st_size > 0)),
            "sha256": sha256(path) if path.is_file() else "",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "external_return_operator_packet_file_rows.csv", list(packet_file_rows[0].keys()), packet_file_rows)

requirement_rows = [
    {"requirement_id": "v53-review-return-operator-surface", "status": "pass", "required_value": "1", "actual_value": v53u["v53u_complete_source_review_return_operator_bundle_ready"], "reason": "review return templates are present"},
    {"requirement_id": "v53-to-v61-handoff-surface", "status": "pass", "required_value": "1", "actual_value": v53z["v53z_complete_source_review_return_v61_handoff_bridge_ready"], "reason": "v53z handoff bridge is present"},
    {"requirement_id": "v61-post-review-generation-surface", "status": "pass", "required_value": "1", "actual_value": v61de["v61de_post_review_generation_result_handoff_bridge_ready"], "reason": "v61de handoff bridge is present"},
    {"requirement_id": "operator-packet-files", "status": status(all(row["file_ready"] == "1" for row in packet_file_rows)), "required_value": str(len(packet_file_rows)), "actual_value": str(sum(row["file_ready"] == "1" for row in packet_file_rows)), "reason": "all external-return packet files must exist"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": v53z["expected_human_review_rows"], "actual_value": v53z["answer_review_accepted_rows"], "reason": "external review return has not been supplied"},
    {"requirement_id": "generation-result-accepted", "status": "blocked", "required_value": v61de["expected_generation_result_artifacts"], "actual_value": v61de["accepted_generation_result_artifacts"], "reason": "external generation result return has not been supplied"},
    {"requirement_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": v61de["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "external_return_operator_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "operator-packet-files", "status": "ready", "reason": f"operator_packet_file_rows={len(packet_file_rows)}"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}"},
    {"gap": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61de['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61df_external_review_generation_return_operator_packet_metrics",
    "model_id": v61de["model_id"],
    "v53u_complete_source_review_return_operator_bundle_ready": v53u["v53u_complete_source_review_return_operator_bundle_ready"],
    "v53w_complete_source_review_return_chunk_execution_queue_ready": v53w["v53w_complete_source_review_return_chunk_execution_queue_ready"],
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": v53z["v53z_complete_source_review_return_v61_handoff_bridge_ready"],
    "v61ct_complete_source_generation_execution_operator_bundle_ready": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"],
    "v61de_post_review_generation_result_handoff_bridge_ready": v61de["v61de_post_review_generation_result_handoff_bridge_ready"],
    "operator_stage_rows": str(len(stage_rows)),
    "ready_operator_stage_rows": str(ready_stage_rows),
    "blocked_operator_stage_rows": str(blocked_stage_rows),
    "operator_command_rows": str(len(command_rows)),
    "ready_operator_command_rows": str(ready_command_rows),
    "operator_packet_file_rows": str(len(packet_file_rows)),
    "ready_operator_packet_file_rows": str(sum(row["file_ready"] == "1" for row in packet_file_rows)),
    "review_return_required_artifacts": str(len(review_expected_rows)),
    "generation_result_required_artifacts": str(len(generation_expected_rows)),
    "review_chunk_rows": v53w["review_chunk_rows"],
    "review_chunk_task_rows": v53w["review_chunk_task_rows"],
    "expected_human_review_rows": v53z["expected_human_review_rows"],
    "answer_review_accepted_rows": v53z["answer_review_accepted_rows"],
    "runtime_admission_accepted_rows": v61de["runtime_admission_accepted_rows"],
    "generation_execution_admission_rows": v61de["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61de["generation_execution_admitted_rows"],
    "expected_generation_result_artifacts": v61de["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61de["accepted_generation_result_artifacts"],
    "generation_result_acceptance_rows": v61de["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v61de["generation_result_accepted_rows"],
    "actual_model_generation_ready": v61de["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61df": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "external_return_operator_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "operator-packet-files", "status": "pass", "reason": f"ready_operator_packet_file_rows={metric['ready_operator_packet_file_rows']}/{metric['operator_packet_file_rows']}"},
    {"gate": "review-return-operator-surface", "status": "pass", "reason": "v53 review return templates are present"},
    {"gate": "generation-result-operator-surface", "status": "pass", "reason": "v61 generation result templates are present"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53z['answer_review_accepted_rows']}/{v53z['expected_human_review_rows']}"},
    {"gate": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61de['actual_model_generation_ready']}"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61df External Review and Generation Return Operator Packet Boundary

This artifact packages the external-return materials needed by the current
v53/v61 path. It contains review return templates, generation result return
templates, command ordering, and copied source evidence. It does not create
review judgments, run generation, create generation results, or claim latency,
near-frontier quality, or release readiness.

Evidence emitted:

- operator_stage_rows={len(stage_rows)}
- ready_operator_stage_rows={ready_stage_rows}
- blocked_operator_stage_rows={blocked_stage_rows}
- operator_command_rows={len(command_rows)}
- ready_operator_command_rows={ready_command_rows}
- operator_packet_file_rows={len(packet_file_rows)}
- ready_operator_packet_file_rows={metric['ready_operator_packet_file_rows']}
- review_return_required_artifacts={len(review_expected_rows)}
- generation_result_required_artifacts={len(generation_expected_rows)}
- review_chunk_rows={v53w['review_chunk_rows']}
- review_chunk_task_rows={v53w['review_chunk_task_rows']}
- expected_human_review_rows={v53z['expected_human_review_rows']}
- answer_review_accepted_rows={v53z['answer_review_accepted_rows']}
- runtime_admission_accepted_rows={v61de['runtime_admission_accepted_rows']}
- generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}
- generation_result_accepted_rows={v61de['generation_result_accepted_rows']}
- actual_model_generation_ready={v61de['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61df=0

Allowed wording: external review/generation return operator packet is ready.
Blocked wording: accepted review return, real generation result acceptance,
actual generation, latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DF_EXTERNAL_REVIEW_GENERATION_RETURN_OPERATOR_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61df-external-review-generation-return-operator-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61df_external_review_generation_return_operator_packet_ready": 1,
    "operator_stage_rows": len(stage_rows),
    "ready_operator_stage_rows": ready_stage_rows,
    "blocked_operator_stage_rows": blocked_stage_rows,
    "operator_packet_file_rows": len(packet_file_rows),
    "ready_operator_packet_file_rows": int(metric["ready_operator_packet_file_rows"]),
    "review_return_required_artifacts": len(review_expected_rows),
    "generation_result_required_artifacts": len(generation_expected_rows),
    "answer_review_accepted_rows": int(v53z["answer_review_accepted_rows"]),
    "accepted_generation_result_artifacts": int(v61de["accepted_generation_result_artifacts"]),
    "actual_model_generation_ready": int(v61de["actual_model_generation_ready"]),
    "source_v53z_summary_sha256": sha256(summary_paths["v53z"]),
    "source_v61de_summary_sha256": sha256(summary_paths["v61de"]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61df_external_review_generation_return_operator_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61df_external_review_generation_return_operator_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
