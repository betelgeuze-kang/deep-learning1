#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cx_post_full_shard_actual_generation_closure_queue"
RUN_ID="${V61CX_RUN_ID:-queue_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cx_post_full_shard_actual_generation_closure_queue_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh" >/dev/null
V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
V61CV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cv_complete_source_runtime_admission_operator_bundle.sh" >/dev/null
V61CW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
V53U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53u_complete_source_review_return_operator_bundle.sh" >/dev/null
V53V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh" >/dev/null
V61CT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null
V61CU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null

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


sources = {
    "v61cm": (
        results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv",
        results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv",
        results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate" / "gate_001",
        "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready",
    ),
    "v61cb": (
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv",
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv",
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate" / "gate_001",
        "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready",
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
    "v53u": (
        results / "v53u_complete_source_review_return_operator_bundle_summary.csv",
        results / "v53u_complete_source_review_return_operator_bundle_decision.csv",
        results / "v53u_complete_source_review_return_operator_bundle" / "bundle_001",
        "v53u_complete_source_review_return_operator_bundle_ready",
    ),
    "v53v": (
        results / "v53v_complete_source_review_return_acceptance_bridge_summary.csv",
        results / "v53v_complete_source_review_return_acceptance_bridge_decision.csv",
        results / "v53v_complete_source_review_return_acceptance_bridge" / "bridge_001",
        "v53v_complete_source_review_return_acceptance_bridge_ready",
    ),
    "v61ct": (
        results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
        results / "v61ct_complete_source_generation_execution_operator_bundle_decision.csv",
        results / "v61ct_complete_source_generation_execution_operator_bundle" / "bundle_001",
        "v61ct_complete_source_generation_execution_operator_bundle_ready",
    ),
    "v61cu": (
        results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
        results / "v61cu_complete_source_generation_result_acceptance_bridge_decision.csv",
        results / "v61cu_complete_source_generation_result_acceptance_bridge" / "bridge_001",
        "v61cu_complete_source_generation_result_acceptance_bridge_ready",
    ),
}

summaries = {}
for key, (summary_path, decision_path, source_dir, ready_field) in sources.items():
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v61cx requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

copy(sources["v61cv"][2] / "complete_source_runtime_admission_operator_command_rows.csv", "source_v61cv/complete_source_runtime_admission_operator_command_rows.csv")
copy(sources["v61cv"][2] / "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv", "source_v61cv/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv")
copy(sources["v61cw"][2] / "complete_source_runtime_admission_acceptance_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv")
copy(sources["v53u"][2] / "review_return_expected_artifact_rows.csv", "source_v53u/review_return_expected_artifact_rows.csv")
copy(sources["v53v"][2] / "complete_source_review_return_acceptance_rows.csv", "source_v53v/complete_source_review_return_acceptance_rows.csv")
copy(sources["v61ct"][2] / "complete_source_generation_execution_operator_command_rows.csv", "source_v61ct/complete_source_generation_execution_operator_command_rows.csv")
copy(sources["v61ct"][2] / "operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv", "source_v61ct/GENERATION_RESULT_RETURN_TEMPLATE.csv")
copy(sources["v61cu"][2] / "complete_source_generation_result_acceptance_rows.csv", "source_v61cu/complete_source_generation_result_acceptance_rows.csv")

v61cm = summaries["v61cm"]
v61cb = summaries["v61cb"]
v61cv = summaries["v61cv"]
v61cw = summaries["v61cw"]
v53u = summaries["v53u"]
v53v = summaries["v53v"]
v61ct = summaries["v61ct"]
v61cu = summaries["v61cu"]

full_checkpoint_ready = as_int(v61cm, "full_checkpoint_materialization_ready")
full_page_hash_ready = int(
    as_int(v61cb, "completed_full_safetensors_page_hash_coverage_ready")
    and as_int(v61cb, "full_safetensors_page_hash_binding_ready")
)
runtime_acceptance_ready = as_int(v61cw, "complete_source_runtime_admission_execution_ready")
review_return_ready = as_int(v53v, "review_return_ready")
generation_result_ready = as_int(v61cu, "actual_model_generation_ready")
full_shard_prerequisites_closed = int(full_checkpoint_ready and full_page_hash_ready)

queue_rows = [
    {
        "closure_step_id": "01-full-checkpoint-materialization",
        "source_gate": "v61cm",
        "required_rows": v61cm["total_required_checkpoint_shard_rows"],
        "accepted_rows": v61cm["total_identity_verified_checkpoint_shard_rows"],
        "missing_rows": v61cm["blocked_checkpoint_materialization_shard_rows"],
        "ready": str(full_checkpoint_ready),
        "operator_surface_ready": v61cm["full_checkpoint_materialization_promotion_ready"],
        "next_command": "closed",
        "blocking_reason": "full checkpoint materialization is closed",
    },
    {
        "closure_step_id": "02-full-safetensors-page-hash-coverage",
        "source_gate": "v61cb",
        "required_rows": v61cb["total_required_page_hash_rows"],
        "accepted_rows": v61cb["total_verified_page_hash_rows"],
        "missing_rows": v61cb["promotion_missing_page_hash_rows"],
        "ready": str(full_page_hash_ready),
        "operator_surface_ready": v61cb["full_page_hash_coverage_promotion_ready"],
        "next_command": "closed",
        "blocking_reason": "full safetensors page-hash coverage is closed",
    },
    {
        "closure_step_id": "03-complete-source-runtime-admission-acceptance",
        "source_gate": "v61cv/v61cw",
        "required_rows": v61cw["runtime_admission_acceptance_rows"],
        "accepted_rows": v61cw["runtime_admission_accepted_rows"],
        "missing_rows": str(as_int(v61cw, "runtime_admission_acceptance_rows") - as_int(v61cw, "runtime_admission_accepted_rows")),
        "ready": str(runtime_acceptance_ready),
        "operator_surface_ready": v61cv["guarded_runtime_admission_command_ready"],
        "next_command": "results/v61cv_complete_source_runtime_admission_operator_bundle/bundle_001/operator_bundle/RUN_RUNTIME_ADMISSION_GUARD.sh && V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return V61CR_REUSE_EXISTING=0 ./experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh && V61CW_REUSE_EXISTING=0 ./experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh",
        "blocking_reason": "1000 runtime admission acceptance rows are still missing",
    },
    {
        "closure_step_id": "04-complete-source-review-return-acceptance",
        "source_gate": "v53u/v53v",
        "required_rows": v53v["review_return_acceptance_rows"],
        "accepted_rows": v53v["answer_review_accepted_rows"],
        "missing_rows": str(as_int(v53v, "review_return_acceptance_rows") - as_int(v53v, "answer_review_accepted_rows")),
        "ready": str(review_return_ready),
        "operator_surface_ready": v53u["review_return_operator_bundle_handoff_ready"],
        "next_command": "V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return V53S_REUSE_EXISTING=0 ./experiments/run_v53s_complete_source_review_return_intake.sh && V53V_REUSE_EXISTING=0 ./experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh",
        "blocking_reason": "7000 complete-source answer review rows plus adjudication/identity/conflict/summary evidence are missing",
    },
    {
        "closure_step_id": "05-complete-source-generation-result-acceptance",
        "source_gate": "v61ct/v61cu",
        "required_rows": v61cu["generation_result_acceptance_rows"],
        "accepted_rows": v61cu["generation_result_accepted_rows"],
        "missing_rows": str(as_int(v61cu, "generation_result_acceptance_rows") - as_int(v61cu, "generation_result_accepted_rows")),
        "ready": str(generation_result_ready),
        "operator_surface_ready": v61ct["guarded_generation_command_ready"],
        "next_command": "results/v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/RUN_GENERATION_GUARD.sh && V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh && V61CU_REUSE_EXISTING=0 ./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh",
        "blocking_reason": "generation execution admission/operator/result artifacts are not accepted",
    },
]
write_csv(run_dir / "post_full_shard_generation_closure_queue_rows.csv", list(queue_rows[0].keys()), queue_rows)

next_action_rows = [
    {
        "action_id": "01-runtime-admission-return",
        "depends_on": "v61cv/v61cw",
        "ready_to_run_now": v61cv["guarded_runtime_admission_command_ready"],
        "expected_return": "runtime_admission_accepted_rows=1000",
        "blocks_generation_until_complete": "1",
        "command": queue_rows[2]["next_command"],
    },
    {
        "action_id": "02-review-return",
        "depends_on": "v53u/v53v",
        "ready_to_run_now": v53u["review_return_operator_bundle_handoff_ready"],
        "expected_return": "answer_review_accepted_rows=7000 plus adjudication/identity/conflict/summary",
        "blocks_generation_until_complete": "1",
        "command": queue_rows[3]["next_command"],
    },
    {
        "action_id": "03-generation-execution-return",
        "depends_on": "v61ct/v61cu",
        "ready_to_run_now": v61ct["guarded_generation_command_ready"],
        "expected_return": "generation_result_accepted_rows=1000",
        "blocks_generation_until_complete": "1",
        "command": queue_rows[4]["next_command"],
    },
]
write_csv(run_dir / "post_full_shard_generation_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

closed_closure_rows = sum(1 for row in queue_rows if row["ready"] == "1")
blocked_closure_rows = len(queue_rows) - closed_closure_rows
ready_next_action_rows = sum(1 for row in next_action_rows if row["ready_to_run_now"] == "1")

metric = {
    "metric_id": "v61cx_post_full_shard_actual_generation_closure_queue_metrics",
    "model_id": model_id,
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": v61cm["v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready"],
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": v61cb["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": v61cv["v61cv_complete_source_runtime_admission_operator_bundle_ready"],
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": v61cw["v61cw_complete_source_runtime_admission_acceptance_bridge_ready"],
    "v53u_complete_source_review_return_operator_bundle_ready": v53u["v53u_complete_source_review_return_operator_bundle_ready"],
    "v53v_complete_source_review_return_acceptance_bridge_ready": v53v["v53v_complete_source_review_return_acceptance_bridge_ready"],
    "v61ct_complete_source_generation_execution_operator_bundle_ready": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"],
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": v61cu["v61cu_complete_source_generation_result_acceptance_bridge_ready"],
    "target_root_path": v61cm["target_root_path"],
    "closure_queue_rows": str(len(queue_rows)),
    "closed_closure_rows": str(closed_closure_rows),
    "blocked_closure_rows": str(blocked_closure_rows),
    "next_action_rows": str(len(next_action_rows)),
    "ready_next_action_rows": str(ready_next_action_rows),
    "full_shard_prerequisites_closed": str(full_shard_prerequisites_closed),
    "full_checkpoint_materialization_ready": str(full_checkpoint_ready),
    "checkpoint_shard_rows": v61cm["checkpoint_shard_rows"],
    "total_identity_verified_checkpoint_shard_rows": v61cm["total_identity_verified_checkpoint_shard_rows"],
    "promotion_identity_verified_bytes": v61cm["promotion_identity_verified_bytes"],
    "completed_full_safetensors_page_hash_coverage_ready": v61cb["completed_full_safetensors_page_hash_coverage_ready"],
    "full_safetensors_page_hash_binding_ready": v61cb["full_safetensors_page_hash_binding_ready"],
    "total_required_page_hash_rows": v61cb["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61cb["total_verified_page_hash_rows"],
    "runtime_admission_acceptance_rows": v61cw["runtime_admission_acceptance_rows"],
    "runtime_admission_accepted_rows": v61cw["runtime_admission_accepted_rows"],
    "runtime_artifact_blocked_acceptance_rows": v61cw["runtime_artifact_blocked_acceptance_rows"],
    "runtime_result_blocked_acceptance_rows": v61cw["runtime_result_blocked_acceptance_rows"],
    "runtime_page_binding_blocked_acceptance_rows": v61cw["runtime_page_binding_blocked_acceptance_rows"],
    "runtime_budget_blocked_acceptance_rows": v61cw["runtime_budget_blocked_acceptance_rows"],
    "runtime_identity_blocked_acceptance_rows": v61cw["runtime_identity_blocked_acceptance_rows"],
    "runtime_safety_blocked_acceptance_rows": v61cw["runtime_safety_blocked_acceptance_rows"],
    "guarded_runtime_admission_command_ready": v61cv["guarded_runtime_admission_command_ready"],
    "complete_source_runtime_admission_execution_ready": v61cw["complete_source_runtime_admission_execution_ready"],
    "review_return_operator_bundle_handoff_ready": v53u["review_return_operator_bundle_handoff_ready"],
    "review_return_acceptance_rows": v53v["review_return_acceptance_rows"],
    "answer_review_accepted_rows": v53v["answer_review_accepted_rows"],
    "human_review_accepted_rows": v53v["human_review_accepted_rows"],
    "expected_human_review_rows": v53v["expected_human_review_rows"],
    "adjudication_accepted_rows": v53v["adjudication_accepted_rows"],
    "expected_adjudication_rows": v53v["expected_adjudication_rows"],
    "reviewer_identity_ready": v53v["reviewer_identity_ready"],
    "conflict_disclosure_ready": v53v["conflict_disclosure_ready"],
    "acceptance_summary_ready": v53v["acceptance_summary_ready"],
    "review_return_ready": v53v["review_return_ready"],
    "generation_execution_admission_rows": v61ct["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61ct["generation_execution_admitted_rows"],
    "guarded_generation_command_ready": v61ct["guarded_generation_command_ready"],
    "generation_operator_execution_ready": v61ct["generation_operator_execution_ready"],
    "generation_result_acceptance_rows": v61cu["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v61cu["generation_result_accepted_rows"],
    "actual_model_generation_ready_rows": v61cu["actual_model_generation_ready_rows"],
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_full_shard_generation_closure_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "full-checkpoint-materialization", "status": status(full_checkpoint_ready), "reason": f"checkpoint_shards={v61cm['total_identity_verified_checkpoint_shard_rows']}/{v61cm['total_required_checkpoint_shard_rows']}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": status(full_page_hash_ready), "reason": f"page_hash_rows={v61cb['total_verified_page_hash_rows']}/{v61cb['total_required_page_hash_rows']}"},
    {"gate": "complete-source-runtime-admission-acceptance", "status": status(runtime_acceptance_ready), "reason": f"runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}/{v61cw['runtime_admission_acceptance_rows']}"},
    {"gate": "complete-source-review-return", "status": status(review_return_ready), "reason": f"answer_review_accepted_rows={v53v['answer_review_accepted_rows']}/{v53v['review_return_acceptance_rows']}"},
    {"gate": "complete-source-generation-result-acceptance", "status": status(generation_result_ready), "reason": f"generation_result_accepted_rows={v61cu['generation_result_accepted_rows']}/{v61cu['generation_result_acceptance_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "review return and generation result acceptance remain blocked"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cx writes metadata and copied evidence only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cx Post-Full-Shard Actual Generation Closure Queue Boundary

This artifact starts after the ubuntu-1 full-shard and full-page-hash path is
closed. It orders the remaining actual-generation blockers without claiming
runtime execution, answer quality, production latency, or release readiness.

Evidence emitted:

- closure_queue_rows={len(queue_rows)}
- closed_closure_rows={closed_closure_rows}
- blocked_closure_rows={blocked_closure_rows}
- next_action_rows={len(next_action_rows)}
- ready_next_action_rows={ready_next_action_rows}
- full_shard_prerequisites_closed={full_shard_prerequisites_closed}
- full_checkpoint_materialization_ready={full_checkpoint_ready}
- checkpoint_shard_rows={v61cm['checkpoint_shard_rows']}
- total_identity_verified_checkpoint_shard_rows={v61cm['total_identity_verified_checkpoint_shard_rows']}
- promotion_identity_verified_bytes={v61cm['promotion_identity_verified_bytes']}
- completed_full_safetensors_page_hash_coverage_ready={v61cb['completed_full_safetensors_page_hash_coverage_ready']}
- full_safetensors_page_hash_binding_ready={v61cb['full_safetensors_page_hash_binding_ready']}
- total_required_page_hash_rows={v61cb['total_required_page_hash_rows']}
- total_verified_page_hash_rows={v61cb['total_verified_page_hash_rows']}
- runtime_admission_acceptance_rows={v61cw['runtime_admission_acceptance_rows']}
- runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}
- guarded_runtime_admission_command_ready={v61cv['guarded_runtime_admission_command_ready']}
- complete_source_runtime_admission_execution_ready={v61cw['complete_source_runtime_admission_execution_ready']}
- review_return_operator_bundle_handoff_ready={v53u['review_return_operator_bundle_handoff_ready']}
- review_return_acceptance_rows={v53v['review_return_acceptance_rows']}
- answer_review_accepted_rows={v53v['answer_review_accepted_rows']}
- review_return_ready={v53v['review_return_ready']}
- generation_execution_admission_rows={v61ct['generation_execution_admission_rows']}
- generation_execution_admitted_rows={v61ct['generation_execution_admitted_rows']}
- guarded_generation_command_ready={v61ct['guarded_generation_command_ready']}
- generation_result_acceptance_rows={v61cu['generation_result_acceptance_rows']}
- generation_result_accepted_rows={v61cu['generation_result_accepted_rows']}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cx=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: post-full-shard actual generation closure queue.
Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61CX_POST_FULL_SHARD_ACTUAL_GENERATION_CLOSURE_QUEUE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cx_post_full_shard_actual_generation_closure_queue",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": 1,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "closure_queue_rows": len(queue_rows),
    "closed_closure_rows": closed_closure_rows,
    "blocked_closure_rows": blocked_closure_rows,
    "next_action_rows": len(next_action_rows),
    "ready_next_action_rows": ready_next_action_rows,
    "actual_model_generation_ready": 0,
    "source_v61cm_summary_sha256": sha256(sources["v61cm"][0]),
    "source_v61cb_summary_sha256": sha256(sources["v61cb"][0]),
    "source_v61cw_summary_sha256": sha256(sources["v61cw"][0]),
    "source_v53v_summary_sha256": sha256(sources["v53v"][0]),
    "source_v61cu_summary_sha256": sha256(sources["v61cu"][0]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cx_post_full_shard_actual_generation_closure_queue_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cx_post_full_shard_actual_generation_closure_queue_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
