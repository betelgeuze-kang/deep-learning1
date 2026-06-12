#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ck_real_generation_unblocker_operator_matrix"
RUN_ID="${V61CK_RUN_ID:-matrix_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ck_real_generation_unblocker_operator_matrix_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cj_real_manifest_immediate_target_bridge.sh" >/dev/null
V61BV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bv_ubuntu1_remaining_checkpoint_materialization_queue.sh" >/dev/null
V61BZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bz_ubuntu1_remaining_page_hash_operator_bundle.sh" >/dev/null
V61CA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ca_ubuntu1_remaining_page_hash_result_intake.sh" >/dev/null
V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
V53U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53u_complete_source_review_return_operator_bundle.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61CG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cg_ubuntu1_source_bound_generation_operator_bundle.sh" >/dev/null

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
operator_dir = run_dir / "operator_matrix"
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


sources = {
    "v61cj": (
        results / "v61cj_real_manifest_immediate_target_bridge_summary.csv",
        results / "v61cj_real_manifest_immediate_target_bridge_decision.csv",
        results / "v61cj_real_manifest_immediate_target_bridge" / "bridge_001",
        "v61cj_real_manifest_immediate_target_bridge_ready",
    ),
    "v61bv": (
        results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_summary.csv",
        results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_decision.csv",
        results / "v61bv_ubuntu1_remaining_checkpoint_materialization_queue" / "queue_001",
        "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready",
    ),
    "v61bz": (
        results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_summary.csv",
        results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_decision.csv",
        results / "v61bz_ubuntu1_remaining_page_hash_operator_bundle" / "bundle_001",
        "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready",
    ),
    "v61ca": (
        results / "v61ca_ubuntu1_remaining_page_hash_result_intake_summary.csv",
        results / "v61ca_ubuntu1_remaining_page_hash_result_intake_decision.csv",
        results / "v61ca_ubuntu1_remaining_page_hash_result_intake" / "intake_001",
        "v61ca_ubuntu1_remaining_page_hash_result_intake_ready",
    ),
    "v61cb": (
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv",
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv",
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate" / "gate_001",
        "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready",
    ),
    "v53u": (
        results / "v53u_complete_source_review_return_operator_bundle_summary.csv",
        results / "v53u_complete_source_review_return_operator_bundle_decision.csv",
        results / "v53u_complete_source_review_return_operator_bundle" / "bundle_001",
        "v53u_complete_source_review_return_operator_bundle_ready",
    ),
    "v61bt": (
        results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
        results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv",
        results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001",
        "v61bt_ubuntu1_actual_generation_result_intake_ready",
    ),
    "v61cg": (
        results / "v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv",
        results / "v61cg_ubuntu1_source_bound_generation_operator_bundle_decision.csv",
        results / "v61cg_ubuntu1_source_bound_generation_operator_bundle" / "bundle_001",
        "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready",
    ),
}

summaries = {}
for key, (summary_path, decision_path, source_dir, ready_field) in sources.items():
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v61ck requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

copy(sources["v61bv"][2] / "remaining_checkpoint_materialization_queue_rows.csv", "source_v61bv/remaining_checkpoint_materialization_queue_rows.csv")
copy(sources["v61bv"][2] / "remaining_checkpoint_materialization_chunk_rows.csv", "source_v61bv/remaining_checkpoint_materialization_chunk_rows.csv")
copy(sources["v61bz"][2] / "remaining_page_hash_operator_file_rows.csv", "source_v61bz/remaining_page_hash_operator_file_rows.csv")
copy(sources["v61ca"][2] / "remaining_page_hash_result_requirement_rows.csv", "source_v61ca/remaining_page_hash_result_requirement_rows.csv")
copy(sources["v61cb"][2] / "full_page_hash_coverage_promotion_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_rows.csv")
copy(sources["v53u"][2] / "reviewer_workload_chunk_rows.csv", "source_v53u/reviewer_workload_chunk_rows.csv")
copy(sources["v53u"][2] / "review_return_expected_artifact_rows.csv", "source_v53u/review_return_expected_artifact_rows.csv")
copy(sources["v61bt"][2] / "actual_generation_result_requirement_rows.csv", "source_v61bt/actual_generation_result_requirement_rows.csv")
copy(sources["v61cg"][2] / "source_bound_generation_operator_bundle_file_rows.csv", "source_v61cg/source_bound_generation_operator_bundle_file_rows.csv")

v61cj = summaries["v61cj"]
v61bv = summaries["v61bv"]
v61bz = summaries["v61bz"]
v61ca = summaries["v61ca"]
v61cb = summaries["v61cb"]
v53u = summaries["v53u"]
v61bt = summaries["v61bt"]
v61cg = summaries["v61cg"]
target_root = v61bv["target_root_path"]

matrix_rows = [
    {
        "unblocker_id": "01-full-checkpoint-materialization",
        "source_gate": "v61bv",
        "operator_surface_ready": v61bv["remaining_queue_ready"],
        "required_rows": v61bv["remaining_queue_rows"],
        "accepted_rows": "0",
        "missing_rows": v61bv["remaining_queue_rows"],
        "required_bytes": v61bv["remaining_unverified_bytes"],
        "current_ready": v61bv["full_checkpoint_materialization_ready"],
        "blocking_reason": "remaining checkpoint shards have not been payload-executed/materialized",
    },
    {
        "unblocker_id": "02-full-safetensors-page-hash-coverage",
        "source_gate": "v61bz/v61ca/v61cb",
        "operator_surface_ready": v61bz["remaining_page_hash_operator_bundle_ready"],
        "required_rows": v61ca["expected_remaining_page_hash_result_rows"],
        "accepted_rows": v61ca["accepted_remaining_page_hash_result_rows"],
        "missing_rows": v61ca["missing_remaining_page_hash_result_rows"],
        "required_bytes": v61bz["remaining_page_hash_bytes"],
        "current_ready": v61cb["completed_full_safetensors_page_hash_coverage_ready"],
        "blocking_reason": "remaining page-hash result rows are absent",
    },
    {
        "unblocker_id": "03-complete-source-human-review-return",
        "source_gate": "v53u",
        "operator_surface_ready": v53u["review_return_operator_bundle_handoff_ready"],
        "required_rows": v53u["expected_human_review_rows"],
        "accepted_rows": v53u["accepted_human_review_rows"],
        "missing_rows": str(int(v53u["expected_human_review_rows"]) - int(v53u["accepted_human_review_rows"])),
        "required_bytes": "0",
        "current_ready": v53u["review_return_ready"],
        "blocking_reason": "external human/source review return has not been accepted",
    },
    {
        "unblocker_id": "04-complete-source-adjudication-return",
        "source_gate": "v53u",
        "operator_surface_ready": v53u["review_return_operator_bundle_handoff_ready"],
        "required_rows": v53u["expected_adjudication_rows"],
        "accepted_rows": v53u["accepted_adjudication_rows"],
        "missing_rows": str(int(v53u["expected_adjudication_rows"]) - int(v53u["accepted_adjudication_rows"])),
        "required_bytes": "0",
        "current_ready": v53u["review_return_ready"],
        "blocking_reason": "external p0 adjudication return has not been accepted",
    },
    {
        "unblocker_id": "05-actual-generation-result-return",
        "source_gate": "v61cg/v61bt",
        "operator_surface_ready": v61cg["operator_bundle_handoff_ready"],
        "required_rows": v61bt["expected_generation_result_artifacts"],
        "accepted_rows": v61bt["accepted_generation_result_artifacts"],
        "missing_rows": v61bt["missing_generation_result_artifacts"],
        "required_bytes": "0",
        "current_ready": v61bt["actual_model_generation_ready"],
        "blocking_reason": "actual Mixtral generation result artifacts are absent",
    },
]
write_csv(run_dir / "real_generation_unblocker_matrix_rows.csv", list(matrix_rows[0].keys()), matrix_rows)

execution_rows = [
    {
        "execution_step": "01-verify-review-return-bundle",
        "depends_on": "v53u",
        "command": "results/v53u_complete_source_review_return_operator_bundle/bundle_001/operator_bundle/VERIFY_REVIEW_RETURN_BUNDLE.sh",
        "ready_to_run_now": "1",
        "expected_return": "bundle shape verified",
    },
    {
        "execution_step": "02-execute-remaining-checkpoint-materialization",
        "depends_on": "v61bv",
        "command": "use v61bv remaining checkpoint materialization queue outside the repository",
        "ready_to_run_now": v61bv["remaining_queue_ready"],
        "expected_return": "58 remaining shards materialized and identity-verifiable",
    },
    {
        "execution_step": "03-execute-remaining-page-hash",
        "depends_on": "v61bz",
        "command": "run v61bz remaining page-hash operator chunks after materialization",
        "ready_to_run_now": v61bz["remaining_page_hash_operator_bundle_ready"],
        "expected_return": "131808 remaining page-hash result rows",
    },
    {
        "execution_step": "04-intake-page-hash-results",
        "depends_on": "v61ca/v61cb",
        "command": "V61CA_REUSE_EXISTING=0 V61CA_PAGE_HASH_RESULT_DIR=/path/to/page_hash_return ./experiments/run_v61ca_ubuntu1_remaining_page_hash_result_intake.sh && V61CB_REUSE_EXISTING=0 ./experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh",
        "ready_to_run_now": "0",
        "expected_return": "completed_full_safetensors_page_hash_coverage_ready=1",
    },
    {
        "execution_step": "05-intake-human-review-return",
        "depends_on": "v53u/v53s/v53t",
        "command": "V53S_REUSE_EXISTING=0 V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return ./experiments/run_v53s_complete_source_review_return_intake.sh && V53T_REUSE_EXISTING=0 ./experiments/run_v53t_complete_source_audit_readiness_gate.sh",
        "ready_to_run_now": "0",
        "expected_return": "review_return_ready=1",
    },
    {
        "execution_step": "06-run-source-bound-generation",
        "depends_on": "v61cg",
        "command": "run v61cg operator bundle only after full page-hash and review return pass",
        "ready_to_run_now": "0",
        "expected_return": "five v61bt generation result artifacts",
    },
    {
        "execution_step": "07-intake-generation-results",
        "depends_on": "v61bt/v61ce",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=/path/to/generation_return ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh && V61CE_REUSE_EXISTING=0 ./experiments/run_v61ce_ubuntu1_generation_closure_return_intake.sh",
        "ready_to_run_now": "0",
        "expected_return": "actual_model_generation_ready=1 if all prior gates passed and artifacts validate",
    },
]
write_csv(run_dir / "real_generation_operator_execution_order_rows.csv", list(execution_rows[0].keys()), execution_rows)

claim_rows = [
    {
        "claim_id": "real-manifest-immediate-targets",
        "status": "ready",
        "evidence": f"v61cj ready targets={v61cj['ready_immediate_target_rows']}/{v61cj['immediate_target_rows']}",
    },
    {
        "claim_id": "operator-unblocker-matrix",
        "status": "ready",
        "evidence": "materialization/page-hash/review/generation result blockers are row-bound",
    },
    {
        "claim_id": "actual-model-generation",
        "status": "blocked",
        "evidence": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}",
    },
    {
        "claim_id": "production-latency",
        "status": "blocked",
        "evidence": "requires accepted actual generation and production-ish latency report",
    },
    {
        "claim_id": "near-frontier-quality",
        "status": "blocked",
        "evidence": "requires accepted review/generation evidence and external evaluation",
    },
]
write_csv(run_dir / "real_generation_claim_boundary_rows.csv", list(claim_rows[0].keys()), claim_rows)

(operator_dir / "README.md").write_text(
    "# v61ck Real Generation Unblocker Operator Matrix\n\n"
    "This matrix links the current real Mixtral manifest/runtime evidence to the "
    "remaining external actions required before actual generation can be claimed. "
    "It does not download checkpoint payloads, fabricate review rows, or accept "
    "generation artifacts.\n\n"
    "Execution order is captured in `real_generation_operator_execution_order_rows.csv`.\n",
    encoding="utf-8",
)
(operator_dir / "RETURN_DIRECTORY_LAYOUT.md").write_text(
    "# Return Directory Layout\n\n"
    "- Page hash return: 131808 remaining hash rows for v61ca.\n"
    "- Review return: v53s human review/adjudication/identity/conflict artifacts.\n"
    "- Generation return: five v61bt artifacts after page-hash and review gates pass.\n",
    encoding="utf-8",
)
verify_script = operator_dir / "VERIFY_UNBLOCKER_MATRIX.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

MATRIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$MATRIX_DIR/real_generation_unblocker_matrix_rows.csv"
  "$MATRIX_DIR/real_generation_operator_execution_order_rows.csv"
  "$MATRIX_DIR/real_generation_claim_boundary_rows.csv"
  "$MATRIX_DIR/source_v61bv/remaining_checkpoint_materialization_queue_rows.csv"
  "$MATRIX_DIR/source_v61ca/remaining_page_hash_result_requirement_rows.csv"
  "$MATRIX_DIR/source_v53u/reviewer_workload_chunk_rows.csv"
  "$MATRIX_DIR/source_v61bt/actual_generation_result_requirement_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v61ck matrix file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$MATRIX_DIR/real_generation_unblocker_matrix_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected five unblocker rows" >&2; exit 1; }
[[ "$(wc -l < "$MATRIX_DIR/real_generation_operator_execution_order_rows.csv" | tr -d ' ')" == "8" ]] || { echo "expected seven execution order rows" >&2; exit 1; }
[[ "$(wc -l < "$MATRIX_DIR/source_v53u/reviewer_workload_chunk_rows.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 v53u reviewer chunks" >&2; exit 1; }

if find "$MATRIX_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "checkpoint/model payload-like file found inside v61ck matrix" >&2
  exit 1
fi

echo "v61ck real generation unblocker matrix shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

file_rows = [
    {"matrix_file": "operator_matrix/README.md", "purpose": "operator matrix overview", "file_ready": "1"},
    {"matrix_file": "operator_matrix/RETURN_DIRECTORY_LAYOUT.md", "purpose": "return directory layout", "file_ready": "1"},
    {"matrix_file": "operator_matrix/VERIFY_UNBLOCKER_MATRIX.sh", "purpose": "matrix shape verifier", "file_ready": "1"},
]
write_csv(run_dir / "real_generation_operator_matrix_file_rows.csv", list(file_rows[0].keys()), file_rows)

ready_unblocker_surfaces = sum(1 for row in matrix_rows if row["operator_surface_ready"] == "1")
blocked_unblocker_rows = sum(1 for row in matrix_rows if row["current_ready"] != "1")
matrix_ready = int(
    ready_unblocker_surfaces == 5
    and len(execution_rows) == 7
    and int(v61cg["operator_bundle_handoff_ready"]) == 1
    and int(v53u["review_return_operator_bundle_handoff_ready"]) == 1
)

metric = {
    "metric_id": "v61ck_real_generation_unblocker_operator_matrix_metrics",
    "model_id": model_id,
    "v61cj_real_manifest_immediate_target_bridge_ready": v61cj["v61cj_real_manifest_immediate_target_bridge_ready"],
    "v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready": v61bv["v61bv_ubuntu1_remaining_checkpoint_materialization_queue_ready"],
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": v61bz["v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready"],
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": v61ca["v61ca_ubuntu1_remaining_page_hash_result_intake_ready"],
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": v61cb["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
    "v53u_complete_source_review_return_operator_bundle_ready": v53u["v53u_complete_source_review_return_operator_bundle_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": v61cg["v61cg_ubuntu1_source_bound_generation_operator_bundle_ready"],
    "target_root_path": target_root,
    "unblocker_matrix_rows": str(len(matrix_rows)),
    "ready_unblocker_operator_surfaces": str(ready_unblocker_surfaces),
    "blocked_unblocker_rows": str(blocked_unblocker_rows),
    "operator_execution_order_rows": str(len(execution_rows)),
    "operator_matrix_file_rows": str(len(file_rows)),
    "remaining_materialization_queue_rows": v61bv["remaining_queue_rows"],
    "remaining_unverified_bytes": v61bv["remaining_unverified_bytes"],
    "remaining_page_hash_rows": v61ca["expected_remaining_page_hash_result_rows"],
    "accepted_remaining_page_hash_result_rows": v61ca["accepted_remaining_page_hash_result_rows"],
    "missing_remaining_page_hash_result_rows": v61ca["missing_remaining_page_hash_result_rows"],
    "expected_human_review_rows": v53u["expected_human_review_rows"],
    "accepted_human_review_rows": v53u["accepted_human_review_rows"],
    "expected_adjudication_rows": v53u["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53u["accepted_adjudication_rows"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "real_manifest_immediate_target_bridge_ready": v61cj["real_manifest_immediate_target_bridge_ready"],
    "review_return_operator_bundle_handoff_ready": v53u["review_return_operator_bundle_handoff_ready"],
    "generation_operator_bundle_handoff_ready": v61cg["operator_bundle_handoff_ready"],
    "generation_unblocker_operator_matrix_ready": str(matrix_ready),
    "full_checkpoint_materialization_ready": v61bv["full_checkpoint_materialization_ready"],
    "completed_full_safetensors_page_hash_coverage_ready": v61cb["completed_full_safetensors_page_hash_coverage_ready"],
    "full_safetensors_page_hash_binding_ready": v61cb["full_safetensors_page_hash_binding_ready"],
    "review_return_ready": v53u["review_return_ready"],
    "generation_result_admission_ready": v61bt["generation_admission_result_ready"],
    "generation_execution_ready": v61cg["generation_execution_ready"],
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ck": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "real_generation_unblocker_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ck_real_generation_unblocker_operator_matrix_ready": str(matrix_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "real-manifest-immediate-target-bridge", "status": "pass", "reason": "v61cj immediate target bridge is ready"},
    {"gate": "operator-unblocker-matrix", "status": "pass" if matrix_ready else "blocked", "reason": f"ready_surfaces={ready_unblocker_surfaces}/5"},
    {"gate": "full-checkpoint-materialization", "status": "blocked", "reason": f"remaining_queue_rows={v61bv['remaining_queue_rows']}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "blocked", "reason": f"accepted_remaining_page_hash_result_rows={v61ca['accepted_remaining_page_hash_result_rows']}/{v61ca['expected_remaining_page_hash_result_rows']}"},
    {"gate": "complete-source-review-return", "status": "blocked", "reason": f"accepted_human_review_rows={v53u['accepted_human_review_rows']}/{v53u['expected_human_review_rows']}"},
    {"gate": "actual-generation-result-return", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "full materialization, full page-hash, review return, and generation artifacts are incomplete"},
    {"gate": "production-latency", "status": "blocked", "reason": "requires actual generation and latency report"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "requires external quality review"},
    {"gate": "real-release-package", "status": "blocked", "reason": "v61ck is not a release package"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ck Real Generation Unblocker Operator Matrix Boundary

This layer binds the real Mixtral manifest/runtime evidence to the remaining
operator return surfaces required before actual model generation can be claimed.
It is a matrix and handoff layer only.

Evidence emitted:

- unblocker_matrix_rows={len(matrix_rows)}
- ready_unblocker_operator_surfaces={ready_unblocker_surfaces}/5
- remaining_materialization_queue_rows={v61bv['remaining_queue_rows']}
- remaining_unverified_bytes={v61bv['remaining_unverified_bytes']}
- remaining_page_hash_rows={v61ca['expected_remaining_page_hash_result_rows']}
- accepted_remaining_page_hash_result_rows={v61ca['accepted_remaining_page_hash_result_rows']}
- expected_human_review_rows={v53u['expected_human_review_rows']}
- accepted_human_review_rows={v53u['accepted_human_review_rows']}
- expected_adjudication_rows={v53u['expected_adjudication_rows']}
- accepted_adjudication_rows={v53u['accepted_adjudication_rows']}
- expected_generation_result_artifacts={v61bt['expected_generation_result_artifacts']}
- accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}
- generation_unblocker_operator_matrix_ready={matrix_ready}
- full_checkpoint_materialization_ready={v61bv['full_checkpoint_materialization_ready']}
- completed_full_safetensors_page_hash_coverage_ready={v61cb['completed_full_safetensors_page_hash_coverage_ready']}
- review_return_ready={v53u['review_return_ready']}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ck=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: real-generation unblocker operator matrix over the current
Mixtral manifest/runtime evidence.

Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61CK_REAL_GENERATION_UNBLOCKER_OPERATOR_MATRIX_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61ck-real-generation-unblocker-operator-matrix",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ck_real_generation_unblocker_operator_matrix_ready": matrix_ready,
    "generation_unblocker_operator_matrix_ready": matrix_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "source_v61cj_summary_sha256": sha256(sources["v61cj"][0]),
    "source_v61cb_summary_sha256": sha256(sources["v61cb"][0]),
    "source_v53u_summary_sha256": sha256(sources["v53u"][0]),
    "source_v61bt_summary_sha256": sha256(sources["v61bt"][0]),
}
(run_dir / "v61ck_real_generation_unblocker_operator_matrix_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ck_real_generation_unblocker_operator_matrix_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
