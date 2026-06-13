#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dd_review_return_generation_refresh_bridge"
RUN_ID="${V61DD_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REVIEW_RETURN_DIR="${V61DD_REVIEW_RETURN_DIR:-}"

if [[ "${V61DD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dd_review_return_generation_refresh_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$REVIEW_RETURN_DIR" ]]; then
  V53Y_REVIEW_RETURN_DIR="$REVIEW_RETURN_DIR" V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
else
  V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
fi
V61DC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dc_complete_source_runtime_admission_local_return_materializer.sh" >/dev/null
V61CR_RUNTIME_ADMISSION_RETURN_DIR="$RESULTS_DIR/v61dc_complete_source_runtime_admission_local_return_materializer/materialize_001/runtime_admission_return_results" V61CR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null
V61CV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cv_complete_source_runtime_admission_operator_bundle.sh" >/dev/null
V61CW_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
V61CK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ck_real_generation_unblocker_operator_matrix.sh" >/dev/null
V61CS_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null
V61CT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null
V61CU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null
V61CX_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cx_post_full_shard_actual_generation_closure_queue.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$REVIEW_RETURN_DIR" <<'PY'
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
review_return_arg = sys.argv[5]
review_return_dir = Path(review_return_arg).expanduser().resolve() if review_return_arg else None
results = root / "results"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)
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


summary_paths = {
    "v53y": results / "v53y_complete_source_review_return_refresh_gate_summary.csv",
    "v61dc": results / "v61dc_complete_source_runtime_admission_local_return_materializer_summary.csv",
    "v61ck": results / "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs": results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61ct": results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
    "v61cu": results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "v61cx": results / "v61cx_post_full_shard_actual_generation_closure_queue_summary.csv",
}
decision_paths = {
    "v53y": results / "v53y_complete_source_review_return_refresh_gate_decision.csv",
    "v61ck": results / "v61ck_real_generation_unblocker_operator_matrix_decision.csv",
    "v61cs": results / "v61cs_complete_source_generation_execution_admission_gate_decision.csv",
    "v61ct": results / "v61ct_complete_source_generation_execution_operator_bundle_decision.csv",
    "v61cu": results / "v61cu_complete_source_generation_result_acceptance_bridge_decision.csv",
    "v61cx": results / "v61cx_post_full_shard_actual_generation_closure_queue_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for name, ready_field in [
    ("v53y", "v53y_complete_source_review_return_refresh_gate_ready"),
    ("v61dc", "v61dc_complete_source_runtime_admission_local_return_materializer_ready"),
    ("v61ck", "v61ck_real_generation_unblocker_operator_matrix_ready"),
    ("v61cs", "v61cs_complete_source_generation_execution_admission_gate_ready"),
    ("v61ct", "v61ct_complete_source_generation_execution_operator_bundle_ready"),
    ("v61cu", "v61cu_complete_source_generation_result_acceptance_bridge_ready"),
    ("v61cx", "v61cx_post_full_shard_actual_generation_closure_queue_ready"),
]:
    if summaries[name].get(ready_field) != "1":
        raise SystemExit(f"v61dd requires {ready_field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

source_files = [
    ("v53y_complete_source_review_return_refresh_gate/refresh_001/complete_source_review_return_refresh_stage_rows.csv", "source_v53y/complete_source_review_return_refresh_stage_rows.csv"),
    ("v53y_complete_source_review_return_refresh_gate/refresh_001/runtime_gap_rows.csv", "source_v53y/runtime_gap_rows.csv"),
    ("v61ck_real_generation_unblocker_operator_matrix/matrix_001/real_generation_unblocker_matrix_rows.csv", "source_v61ck/real_generation_unblocker_matrix_rows.csv"),
    ("v61cs_complete_source_generation_execution_admission_gate/gate_001/complete_source_generation_execution_admission_metric_rows.csv", "source_v61cs/complete_source_generation_execution_admission_metric_rows.csv"),
    ("v61cs_complete_source_generation_execution_admission_gate/gate_001/runtime_gap_rows.csv", "source_v61cs/runtime_gap_rows.csv"),
    ("v61ct_complete_source_generation_execution_operator_bundle/bundle_001/complete_source_generation_execution_operator_command_rows.csv", "source_v61ct/complete_source_generation_execution_operator_command_rows.csv"),
    ("v61cu_complete_source_generation_result_acceptance_bridge/bridge_001/complete_source_generation_result_acceptance_metric_rows.csv", "source_v61cu/complete_source_generation_result_acceptance_metric_rows.csv"),
    ("v61cu_complete_source_generation_result_acceptance_bridge/bridge_001/runtime_gap_rows.csv", "source_v61cu/runtime_gap_rows.csv"),
    ("v61cx_post_full_shard_actual_generation_closure_queue/queue_001/post_full_shard_generation_closure_queue_rows.csv", "source_v61cx/post_full_shard_generation_closure_queue_rows.csv"),
]
for src_rel, dst_rel in source_files:
    copy(results / src_rel, dst_rel)

v53y = summaries["v53y"]
v61dc = summaries["v61dc"]
v61ck = summaries["v61ck"]
v61cs = summaries["v61cs"]
v61ct = summaries["v61ct"]
v61cu = summaries["v61cu"]
v61cx = summaries["v61cx"]

review_return_dir_supplied = int(review_return_dir is not None)
review_return_dir_exists = int(review_return_dir is not None and review_return_dir.is_dir())
full_shard_prerequisites_closed = as_int(v61cx, "full_shard_prerequisites_closed")
runtime_admission_ready = as_int(v61cs, "complete_source_runtime_admission_execution_ready")
review_return_ready = as_int(v53y, "review_return_ready")
review_unblock_ready = as_int(v53y, "v61_review_unblock_ready")
generation_execution_ready = as_int(v61cs, "generation_execution_admission_ready")
generation_result_ready = as_int(v61cu, "actual_model_generation_ready")
actual_generation_ready = int(generation_execution_ready and generation_result_ready)

stage_rows = [
    {
        "refresh_stage_id": "01-full-shard-and-page-hash-closed",
        "source_gate": "v61cx",
        "stage_status": "ready" if full_shard_prerequisites_closed else "blocked",
        "expected_return": "full_shard_prerequisites_closed=1",
        "actual_return": f"full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
        "blocking_reason": "ready" if full_shard_prerequisites_closed else "full shard/page-hash prerequisites incomplete",
    },
    {
        "refresh_stage_id": "02-runtime-admission-accepted",
        "source_gate": "v61dc/v61cs",
        "stage_status": "ready" if runtime_admission_ready else "blocked",
        "expected_return": "runtime_admission_accepted_rows=1000",
        "actual_return": f"runtime_admission_accepted_rows={v61cs['runtime_admission_accepted_rows']}/{v61cs['runtime_admission_acceptance_rows']}",
        "blocking_reason": "ready" if runtime_admission_ready else "runtime admission acceptance incomplete",
    },
    {
        "refresh_stage_id": "03-review-return-accepted",
        "source_gate": "v53y/v61ck",
        "stage_status": "ready" if review_unblock_ready else "blocked",
        "expected_return": "answer_review_accepted_rows=7000",
        "actual_return": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}",
        "blocking_reason": "ready" if review_unblock_ready else "complete-source review return not accepted",
    },
    {
        "refresh_stage_id": "04-generation-execution-admitted",
        "source_gate": "v61cs",
        "stage_status": "ready" if generation_execution_ready else "blocked",
        "expected_return": "generation_execution_admitted_rows=1000",
        "actual_return": f"generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}/{v61cs['generation_execution_admission_rows']}",
        "blocking_reason": "ready" if generation_execution_ready else "generation execution admission remains blocked",
    },
    {
        "refresh_stage_id": "05-generation-result-accepted",
        "source_gate": "v61cu",
        "stage_status": "ready" if generation_result_ready else "blocked",
        "expected_return": "actual_model_generation_ready_rows=1000",
        "actual_return": f"actual_model_generation_ready_rows={v61cu['actual_model_generation_ready_rows']}/{v61cu['generation_result_acceptance_rows']}",
        "blocking_reason": "ready" if generation_result_ready else "generation result artifacts/answer/citation/latency acceptance incomplete",
    },
    {
        "refresh_stage_id": "06-actual-model-generation-ready",
        "source_gate": "v61cs/v61cu",
        "stage_status": "ready" if actual_generation_ready else "blocked",
        "expected_return": "actual_model_generation_ready=1",
        "actual_return": f"actual_model_generation_ready={actual_generation_ready}",
        "blocking_reason": "ready" if actual_generation_ready else "actual generation is not proven",
    },
]
write_csv(run_dir / "review_return_generation_refresh_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

ready_stage_rows = sum(1 for row in stage_rows if row["stage_status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

command_rows = [
    {
        "command_id": "verify-v61dd-refresh-bridge",
        "command": "results/v61dd_review_return_generation_refresh_bridge/bridge_001/operator_bundle/VERIFY_REVIEW_GENERATION_REFRESH.sh",
        "ready_to_run_now": "1",
        "expected_return": "v61dd refresh bridge shape is valid",
    },
    {
        "command_id": "rerun-with-review-return-dir",
        "command": "V61DD_REVIEW_RETURN_DIR=/path/to/v53_review_return V61DD_REUSE_EXISTING=0 ./experiments/run_v61dd_review_return_generation_refresh_bridge.sh",
        "ready_to_run_now": str(int(review_return_dir_exists)),
        "expected_return": "v53y/v61ck/v61cs/v61ct/v61cu/v61cx refreshed after review return",
    },
    {
        "command_id": "run-generation-operator-after-review-unblock",
        "command": "results/v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/RUN_GENERATION_GUARD.sh",
        "ready_to_run_now": str(int(generation_execution_ready)),
        "expected_return": "generation execution admission guard opens only after review return and other blockers clear",
    },
]
write_csv(run_dir / "review_return_generation_refresh_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

requirement_rows = [
    {"requirement_id": "review-return-directory", "status": status(review_return_dir_exists), "required_value": "existing review return directory", "actual_value": str(review_return_dir) if review_return_dir else "", "reason": "real human/source review returns must be supplied externally"},
    {"requirement_id": "full-shard-page-hash-closed", "status": status(full_shard_prerequisites_closed), "required_value": "1", "actual_value": str(full_shard_prerequisites_closed), "reason": "v61 full checkpoint and full page-hash prerequisites must stay closed"},
    {"requirement_id": "runtime-admission-accepted", "status": status(runtime_admission_ready), "required_value": "1000", "actual_value": v61cs["runtime_admission_accepted_rows"], "reason": "v61dc/v61cw must keep runtime admission accepted"},
    {"requirement_id": "review-return-accepted", "status": status(review_unblock_ready), "required_value": v53y["expected_human_review_rows"], "actual_value": v53y["answer_review_accepted_rows"], "reason": "v53y must accept the review return before v61 review blocker can clear"},
    {"requirement_id": "generation-execution-admitted", "status": status(generation_execution_ready), "required_value": "1000", "actual_value": v61cs["generation_execution_admitted_rows"], "reason": "v61cs must admit all complete-source generation execution rows"},
    {"requirement_id": "generation-result-accepted", "status": status(generation_result_ready), "required_value": "1000", "actual_value": v61cu["actual_model_generation_ready_rows"], "reason": "v61cu must accept generation results, citations, and latency rows"},
    {"requirement_id": "actual-model-generation", "status": status(actual_generation_ready), "required_value": "1", "actual_value": str(actual_generation_ready), "reason": "actual generation requires review unblock plus accepted generation results"},
]
write_csv(run_dir / "review_return_generation_refresh_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "review-return-directory", "status": "ready" if review_return_dir_exists else "blocked", "reason": f"review_return_dir_supplied={review_return_dir_supplied}; review_return_dir_exists={review_return_dir_exists}"},
    {"gap": "full-shard-page-hash-closed", "status": "ready" if full_shard_prerequisites_closed else "blocked", "reason": f"full_shard_prerequisites_closed={full_shard_prerequisites_closed}"},
    {"gap": "runtime-admission-accepted", "status": "ready" if runtime_admission_ready else "blocked", "reason": f"runtime_admission_accepted_rows={v61cs['runtime_admission_accepted_rows']}/{v61cs['runtime_admission_acceptance_rows']}"},
    {"gap": "review-return-accepted", "status": "ready" if review_unblock_ready else "blocked", "reason": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}"},
    {"gap": "generation-execution-admitted", "status": "ready" if generation_execution_ready else "blocked", "reason": f"generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}/{v61cs['generation_execution_admission_rows']}"},
    {"gap": "generation-result-accepted", "status": "ready" if generation_result_ready else "blocked", "reason": f"actual_model_generation_ready_rows={v61cu['actual_model_generation_ready_rows']}/{v61cu['generation_result_acceptance_rows']}"},
    {"gap": "actual-model-generation", "status": "ready" if actual_generation_ready else "blocked", "reason": f"actual_model_generation_ready={actual_generation_ready}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61dd_review_return_generation_refresh_bridge_metrics",
    "model_id": model_id,
    "review_return_dir_supplied": str(review_return_dir_supplied),
    "review_return_dir_exists": str(review_return_dir_exists),
    "v53y_complete_source_review_return_refresh_gate_ready": v53y["v53y_complete_source_review_return_refresh_gate_ready"],
    "v61dc_complete_source_runtime_admission_local_return_materializer_ready": v61dc["v61dc_complete_source_runtime_admission_local_return_materializer_ready"],
    "v61ck_real_generation_unblocker_operator_matrix_ready": v61ck["v61ck_real_generation_unblocker_operator_matrix_ready"],
    "v61cs_complete_source_generation_execution_admission_gate_ready": v61cs["v61cs_complete_source_generation_execution_admission_gate_ready"],
    "v61ct_complete_source_generation_execution_operator_bundle_ready": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"],
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": v61cu["v61cu_complete_source_generation_result_acceptance_bridge_ready"],
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": v61cx["v61cx_post_full_shard_actual_generation_closure_queue_ready"],
    "refresh_stage_rows": str(len(stage_rows)),
    "ready_refresh_stage_rows": str(ready_stage_rows),
    "blocked_refresh_stage_rows": str(blocked_stage_rows),
    "refresh_command_rows": str(len(command_rows)),
    "ready_refresh_command_rows": str(ready_command_rows),
    "full_shard_prerequisites_closed": str(full_shard_prerequisites_closed),
    "full_checkpoint_materialization_ready": v61cx["full_checkpoint_materialization_ready"],
    "completed_full_safetensors_page_hash_coverage_ready": v61cx["completed_full_safetensors_page_hash_coverage_ready"],
    "full_safetensors_page_hash_binding_ready": v61cx["full_safetensors_page_hash_binding_ready"],
    "runtime_admission_acceptance_rows": v61cs["runtime_admission_acceptance_rows"],
    "runtime_admission_accepted_rows": v61cs["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61cs["complete_source_runtime_admission_execution_ready"],
    "machine_complete_source_surface_ready": v53y["machine_complete_source_surface_ready"],
    "accepted_chunk_return_artifact_rows": v53y["accepted_chunk_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53y["accepted_aggregate_review_return_artifact_rows"],
    "expected_human_review_rows": v53y["expected_human_review_rows"],
    "accepted_human_review_rows": v53y["accepted_human_review_rows"],
    "expected_adjudication_rows": v53y["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53y["accepted_adjudication_rows"],
    "answer_review_accepted_rows": v53y["answer_review_accepted_rows"],
    "review_return_ready": str(review_return_ready),
    "v61_review_unblock_ready": str(review_unblock_ready),
    "generation_execution_admission_rows": v61cs["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61cs["generation_execution_admitted_rows"],
    "review_return_blocked_generation_rows": v61cs["review_return_blocked_generation_rows"],
    "generation_result_artifact_blocked_rows": v61cs["generation_result_artifact_blocked_rows"],
    "guarded_generation_command_ready": v61ct["guarded_generation_command_ready"],
    "generation_operator_execution_ready": v61ct["generation_operator_execution_ready"],
    "generation_result_acceptance_rows": v61cu["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v61cu["generation_result_accepted_rows"],
    "actual_model_generation_ready_rows": v61cu["actual_model_generation_ready_rows"],
    "actual_model_generation_ready": str(actual_generation_ready),
    "closure_queue_rows": v61cx["closure_queue_rows"],
    "closed_closure_rows": v61cx["closed_closure_rows"],
    "blocked_closure_rows": v61cx["blocked_closure_rows"],
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "review_return_generation_refresh_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dd_review_return_generation_refresh_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "full-shard-page-hash-closed", "status": status(full_shard_prerequisites_closed), "reason": f"full_shard_prerequisites_closed={full_shard_prerequisites_closed}"},
    {"gate": "runtime-admission-accepted", "status": status(runtime_admission_ready), "reason": f"runtime_admission_accepted_rows={v61cs['runtime_admission_accepted_rows']}/{v61cs['runtime_admission_acceptance_rows']}"},
    {"gate": "review-return-directory", "status": status(review_return_dir_exists), "reason": f"review_return_dir_exists={review_return_dir_exists}"},
    {"gate": "review-return-accepted", "status": status(review_unblock_ready), "reason": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}"},
    {"gate": "generation-execution-admitted", "status": status(generation_execution_ready), "reason": f"generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}/{v61cs['generation_execution_admission_rows']}"},
    {"gate": "generation-result-accepted", "status": status(generation_result_ready), "reason": f"actual_model_generation_ready_rows={v61cu['actual_model_generation_ready_rows']}/{v61cu['generation_result_acceptance_rows']}"},
    {"gate": "actual-model-generation", "status": status(actual_generation_ready), "reason": f"actual_model_generation_ready={actual_generation_ready}"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

(operator_dir / "README.md").write_text(
    "# v61dd Review Return Generation Refresh Bridge\n\n"
    "Use `V61DD_REVIEW_RETURN_DIR=/path/to/v53_review_return` after external "
    "review artifacts are available. This bridge refreshes v53y, rebinds the "
    "v61 operator matrix, and then refreshes v61cs/v61ct/v61cu/v61cx so the "
    "review-return blocker can be observed in the actual generation path.\n",
    encoding="utf-8",
)
verify_script = operator_dir / "VERIFY_REVIEW_GENERATION_REFRESH.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/review_return_generation_refresh_stage_rows.csv"
  "$BUNDLE_DIR/review_return_generation_refresh_command_rows.csv"
  "$BUNDLE_DIR/review_return_generation_refresh_requirement_rows.csv"
  "$BUNDLE_DIR/review_return_generation_refresh_metric_rows.csv"
  "$BUNDLE_DIR/runtime_gap_rows.csv"
  "$BUNDLE_DIR/source_v53y/complete_source_review_return_refresh_stage_rows.csv"
  "$BUNDLE_DIR/source_v61cs/complete_source_generation_execution_admission_metric_rows.csv"
  "$BUNDLE_DIR/source_v61cu/complete_source_generation_result_acceptance_metric_rows.csv"
  "$BUNDLE_DIR/source_v61cx/post_full_shard_generation_closure_queue_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v61dd refresh bridge file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/review_return_generation_refresh_stage_rows.csv" | tr -d ' ')" == "7" ]] || { echo "expected six refresh stage rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_generation_refresh_command_rows.csv" | tr -d ' ')" == "4" ]] || { echo "expected three command rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v61dd bundle" >&2
  exit 1
fi

echo "v61dd review return generation refresh bridge shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

boundary = f"""# v61dd Review Return Generation Refresh Bridge Boundary

This artifact refreshes the v61 actual-generation blocker chain after v53y
review-return refresh. It does not fabricate review rows, run generation, or
claim production latency/near-frontier/release readiness.

Evidence emitted:

- review_return_dir_supplied={review_return_dir_supplied}
- review_return_dir_exists={review_return_dir_exists}
- refresh_stage_rows={len(stage_rows)}
- ready_refresh_stage_rows={ready_stage_rows}
- blocked_refresh_stage_rows={blocked_stage_rows}
- full_shard_prerequisites_closed={full_shard_prerequisites_closed}
- runtime_admission_accepted_rows={v61cs['runtime_admission_accepted_rows']}
- complete_source_runtime_admission_execution_ready={v61cs['complete_source_runtime_admission_execution_ready']}
- machine_complete_source_surface_ready={v53y['machine_complete_source_surface_ready']}
- accepted_chunk_return_artifact_rows={v53y['accepted_chunk_return_artifact_rows']}
- accepted_aggregate_review_return_artifact_rows={v53y['accepted_aggregate_review_return_artifact_rows']}
- expected_human_review_rows={v53y['expected_human_review_rows']}
- accepted_human_review_rows={v53y['accepted_human_review_rows']}
- answer_review_accepted_rows={v53y['answer_review_accepted_rows']}
- review_return_ready={review_return_ready}
- v61_review_unblock_ready={review_unblock_ready}
- generation_execution_admission_rows={v61cs['generation_execution_admission_rows']}
- generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}
- review_return_blocked_generation_rows={v61cs['review_return_blocked_generation_rows']}
- generation_result_artifact_blocked_rows={v61cs['generation_result_artifact_blocked_rows']}
- actual_model_generation_ready_rows={v61cu['actual_model_generation_ready_rows']}
- actual_model_generation_ready={actual_generation_ready}
- closed_closure_rows={v61cx['closed_closure_rows']}
- blocked_closure_rows={v61cx['blocked_closure_rows']}

Allowed wording: v61 review-return/generation refresh bridge is ready and
reports the exact remaining actual-generation blockers.

Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61DD_REVIEW_RETURN_GENERATION_REFRESH_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dd-review-return-generation-refresh-bridge",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dd_review_return_generation_refresh_bridge_ready": 1,
    "review_return_dir_supplied": review_return_dir_supplied,
    "review_return_dir_exists": review_return_dir_exists,
    "refresh_stage_rows": len(stage_rows),
    "ready_refresh_stage_rows": ready_stage_rows,
    "blocked_refresh_stage_rows": blocked_stage_rows,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "runtime_admission_accepted_rows": as_int(v61cs, "runtime_admission_accepted_rows"),
    "answer_review_accepted_rows": as_int(v53y, "answer_review_accepted_rows"),
    "v61_review_unblock_ready": review_unblock_ready,
    "generation_execution_admitted_rows": as_int(v61cs, "generation_execution_admitted_rows"),
    "actual_model_generation_ready_rows": as_int(v61cu, "actual_model_generation_ready_rows"),
    "actual_model_generation_ready": actual_generation_ready,
    "source_v53y_summary_sha256": sha256(summary_paths["v53y"]),
    "source_v61cs_summary_sha256": sha256(summary_paths["v61cs"]),
    "source_v61cu_summary_sha256": sha256(summary_paths["v61cu"]),
    "source_v61cx_summary_sha256": sha256(summary_paths["v61cx"]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dd_review_return_generation_refresh_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dd_review_return_generation_refresh_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
