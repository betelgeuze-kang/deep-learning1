#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cc_ubuntu1_page_hash_generation_admission_bridge"
RUN_ID="${V61CC_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cc_ubuntu1_page_hash_generation_admission_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

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


v61cb_dir = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate" / "gate_001"
v53t_dir = results / "v53t_complete_source_audit_readiness_gate" / "gate_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"

v61cb_summary_path = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"
v53t_summary_path = results / "v53t_complete_source_audit_readiness_gate_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61cb_decision_path = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv"
v53t_decision_path = results / "v53t_complete_source_audit_readiness_gate_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"

v61cb_summary = read_csv(v61cb_summary_path)[0]
v53t_summary = read_csv(v53t_summary_path)[0]
v61bt_summary = read_csv(v61bt_summary_path)[0]
if v61cb_summary.get("v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready") != "1":
    raise SystemExit("v61cc requires v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready=1")
if v53t_summary.get("v53t_complete_source_audit_readiness_gate_ready") != "1":
    raise SystemExit("v61cc requires v53t_complete_source_audit_readiness_gate_ready=1")
if v61bt_summary.get("v61bt_ubuntu1_actual_generation_result_intake_ready") != "1":
    raise SystemExit("v61cc requires v61bt_ubuntu1_actual_generation_result_intake_ready=1")

for src, rel in [
    (v61cb_summary_path, "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"),
    (v61cb_decision_path, "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_rows.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_requirement_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_requirement_rows.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_metric_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_metric_rows.csv"),
    (v61cb_dir / "runtime_gap_rows.csv", "source_v61cb/runtime_gap_rows.csv"),
    (v61cb_dir / "sha256_manifest.csv", "source_v61cb/sha256_manifest.csv"),
    (v53t_summary_path, "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv"),
    (v53t_decision_path, "source_v53t/v53t_complete_source_audit_readiness_gate_decision.csv"),
    (v53t_dir / "complete_source_audit_readiness_requirement_rows.csv", "source_v53t/complete_source_audit_readiness_requirement_rows.csv"),
    (v53t_dir / "complete_source_audit_claim_rows.csv", "source_v53t/complete_source_audit_claim_rows.csv"),
    (v53t_dir / "complete_source_audit_readiness_metric_rows.csv", "source_v53t/complete_source_audit_readiness_metric_rows.csv"),
    (v53t_dir / "sha256_manifest.csv", "source_v53t/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_query_result_rows.csv", "source_v61bt/actual_generation_query_result_rows.csv"),
    (v61bt_dir / "actual_generation_result_required_field_rows.csv", "source_v61bt/actual_generation_result_required_field_rows.csv"),
    (v61bt_dir / "actual_generation_result_template_rows.csv", "source_v61bt/actual_generation_result_template_rows.csv"),
    (v61bt_dir / "actual_generation_result_status_rows.csv", "source_v61bt/actual_generation_result_status_rows.csv"),
    (v61bt_dir / "actual_generation_result_metric_rows.csv", "source_v61bt/actual_generation_result_metric_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
]:
    copy(src, rel)

query_rows = read_csv(v61bt_dir / "actual_generation_query_result_rows.csv")
if len(query_rows) != 1000:
    raise SystemExit("v61cc expects 1000 v61bt query result rows")

target_root = v61cb_summary["target_root_path"]
if v61bt_summary["target_root_path"] != target_root:
    raise SystemExit("v61cc requires v61cb/v61bt target root match")

machine_complete_source_surface_ready = int(v53t_summary["machine_complete_source_surface_ready"])
review_return_ready = int(v53t_summary["review_return_ready"])
full_page_hash_binding_ready = int(v61cb_summary["full_safetensors_page_hash_binding_ready"])
completed_full_page_hash_coverage_ready = int(v61cb_summary["completed_full_safetensors_page_hash_coverage_ready"])
generation_result_schema_ready = int(v61bt_summary["v61bt_ubuntu1_actual_generation_result_intake_ready"])
generation_packet_artifacts_ready = int(v61bt_summary["generation_packet_artifacts_ready"])
generation_execution_admission_ready = int(
    machine_complete_source_surface_ready
    and review_return_ready
    and full_page_hash_binding_ready
    and completed_full_page_hash_coverage_ready
    and generation_result_schema_ready
)
actual_model_generation_ready = int(generation_execution_admission_ready and generation_packet_artifacts_ready)

bridge_rows = []
generation_execution_admitted_rows = 0
page_hash_blocked_rows = 0
review_return_blocked_rows = 0
generation_result_artifact_blocked_rows = 0
for index, query in enumerate(query_rows):
    page_hash_blocked = int(not full_page_hash_binding_ready or not completed_full_page_hash_coverage_ready)
    review_blocked = int(not review_return_ready)
    artifact_blocked = int(not generation_packet_artifacts_ready)
    admitted = int(machine_complete_source_surface_ready and not page_hash_blocked and not review_blocked and generation_result_schema_ready)
    generation_ready = int(admitted and not artifact_blocked)
    generation_execution_admitted_rows += admitted
    page_hash_blocked_rows += page_hash_blocked
    review_return_blocked_rows += review_blocked
    generation_result_artifact_blocked_rows += artifact_blocked
    bridge_rows.append(
        {
            "generation_admission_bridge_id": f"v61cc-generation-admission-{index:04d}",
            "review_query_packet_id": query["review_query_packet_id"],
            "query_id": query["query_id"],
            "owner_repo": query["owner_repo"],
            "source_span_id": query["source_span_id"],
            "source_file_sha256": query["source_file_sha256"],
            "machine_complete_source_surface_ready": str(machine_complete_source_surface_ready),
            "complete_source_review_return_ready": str(review_return_ready),
            "full_safetensors_page_hash_binding_ready": str(full_page_hash_binding_ready),
            "completed_full_safetensors_page_hash_coverage_ready": str(completed_full_page_hash_coverage_ready),
            "actual_generation_result_schema_ready": str(generation_result_schema_ready),
            "generation_packet_artifacts_ready": str(generation_packet_artifacts_ready),
            "page_hash_blocked": str(page_hash_blocked),
            "review_return_blocked": str(review_blocked),
            "generation_result_artifact_blocked": str(artifact_blocked),
            "generation_execution_admitted": str(admitted),
            "actual_model_generation_ready": str(generation_ready),
            "checkpoint_payload_bytes_downloaded_by_v61cc": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "page_hash_generation_admission_bridge_rows.csv", list(bridge_rows[0].keys()), bridge_rows)

requirement_rows = [
    {
        "requirement_id": "v61cb-page-hash-promotion-input",
        "status": "pass",
        "required_value": "v61cb ready",
        "actual_value": v61cb_summary["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
        "reason": "page-hash promotion gate is bound",
    },
    {
        "requirement_id": "v53t-complete-source-audit-input",
        "status": "pass",
        "required_value": "v53t ready",
        "actual_value": v53t_summary["v53t_complete_source_audit_readiness_gate_ready"],
        "reason": "complete-source audit readiness gate is bound",
    },
    {
        "requirement_id": "v61bt-generation-result-schema-input",
        "status": "pass",
        "required_value": "v61bt schema ready",
        "actual_value": v61bt_summary["v61bt_ubuntu1_actual_generation_result_intake_ready"],
        "reason": "actual generation result intake schema is bound",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "pass" if full_page_hash_binding_ready and completed_full_page_hash_coverage_ready else "blocked",
        "required_value": v61cb_summary["total_required_page_hash_rows"],
        "actual_value": v61cb_summary["total_verified_page_hash_rows"],
        "reason": "every checkpoint page must be hash-verified before generation admission",
    },
    {
        "requirement_id": "complete-source-review-return",
        "status": "pass" if review_return_ready else "blocked",
        "required_value": f"{v53t_summary['expected_human_review_rows']} review / {v53t_summary['expected_adjudication_rows']} adjudication",
        "actual_value": f"{v53t_summary['accepted_human_review_rows']} review / {v53t_summary['accepted_adjudication_rows']} adjudication",
        "reason": "human/source review and adjudication returns must be accepted",
    },
    {
        "requirement_id": "generation-execution-admission",
        "status": "pass" if generation_execution_admission_ready else "blocked",
        "required_value": v61bt_summary["complete_source_query_rows"],
        "actual_value": str(generation_execution_admitted_rows),
        "reason": "execution admission requires page hash binding and complete-source review return",
    },
    {
        "requirement_id": "actual-generation-result-artifacts",
        "status": "pass" if generation_packet_artifacts_ready else "blocked",
        "required_value": v61bt_summary["expected_generation_result_artifacts"],
        "actual_value": v61bt_summary["accepted_generation_result_artifacts"],
        "reason": "actual answer/citation/abstain/latency artifacts are still missing",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": "pass" if actual_model_generation_ready else "blocked",
        "required_value": v61bt_summary["complete_source_query_rows"],
        "actual_value": str(sum(int(row["actual_model_generation_ready"]) for row in bridge_rows)),
        "reason": "actual generation requires admitted execution plus accepted generation result artifacts",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 payload bytes",
        "actual_value": "0",
        "reason": "v61cc writes metadata and hashes only",
    },
]
write_csv(run_dir / "page_hash_generation_admission_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cc_ubuntu1_page_hash_generation_admission_bridge_metrics",
    "model_id": model_id,
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": v61cb_summary["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
    "v53t_complete_source_audit_readiness_gate_ready": v53t_summary["v53t_complete_source_audit_readiness_gate_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt_summary["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "target_root_path": target_root,
    "complete_source_query_rows": v61bt_summary["complete_source_query_rows"],
    "generation_admission_bridge_rows": str(len(bridge_rows)),
    "machine_complete_source_surface_ready": str(machine_complete_source_surface_ready),
    "complete_source_review_return_ready": str(review_return_ready),
    "full_page_hash_coverage_promotion_ready": v61cb_summary["full_page_hash_coverage_promotion_ready"],
    "completed_full_safetensors_page_hash_coverage_ready": str(completed_full_page_hash_coverage_ready),
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_binding_ready),
    "checkpoint_shard_rows": v61cb_summary["checkpoint_shard_rows"],
    "ready_full_page_hash_shard_rows": v61cb_summary["ready_full_page_hash_shard_rows"],
    "blocked_full_page_hash_shard_rows": v61cb_summary["blocked_full_page_hash_shard_rows"],
    "total_required_page_hash_rows": v61cb_summary["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61cb_summary["total_verified_page_hash_rows"],
    "missing_remaining_page_hash_result_rows": v61cb_summary["missing_remaining_page_hash_result_rows"],
    "expected_human_review_rows": v53t_summary["expected_human_review_rows"],
    "accepted_human_review_rows": v53t_summary["accepted_human_review_rows"],
    "expected_adjudication_rows": v53t_summary["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53t_summary["accepted_adjudication_rows"],
    "generation_result_schema_ready": str(generation_result_schema_ready),
    "expected_generation_result_artifacts": v61bt_summary["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61bt_summary["accepted_generation_result_artifacts"],
    "generation_packet_artifacts_ready": str(generation_packet_artifacts_ready),
    "generation_execution_admission_ready": str(generation_execution_admission_ready),
    "generation_execution_admitted_rows": str(generation_execution_admitted_rows),
    "page_hash_blocked_rows": str(page_hash_blocked_rows),
    "review_return_blocked_rows": str(review_return_blocked_rows),
    "generation_result_artifact_blocked_rows": str(generation_result_artifact_blocked_rows),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "source_bound_qa_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "page_hash_generation_admission_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61cb-page-hash-promotion-input", "ready", "v61cb promotion rows are bound"),
    ("v53t-complete-source-audit-input", "ready", "v53t complete-source audit readiness is bound"),
    ("v61bt-generation-result-schema-input", "ready", "v61bt generation result intake schema is bound"),
    ("completed-full-safetensors-page-hash-coverage", "ready" if full_page_hash_binding_ready and completed_full_page_hash_coverage_ready else "blocked", f"verified={v61cb_summary['total_verified_page_hash_rows']}/{v61cb_summary['total_required_page_hash_rows']}"),
    ("complete-source-review-return", "ready" if review_return_ready else "blocked", f"accepted_review={v53t_summary['accepted_human_review_rows']}/{v53t_summary['expected_human_review_rows']}"),
    ("generation-execution-admission", "ready" if generation_execution_admission_ready else "blocked", f"admitted={generation_execution_admitted_rows}/{len(bridge_rows)}"),
    ("actual-generation-result-artifacts", "ready" if generation_packet_artifacts_ready else "blocked", f"accepted={v61bt_summary['accepted_generation_result_artifacts']}/{v61bt_summary['expected_generation_result_artifacts']}"),
    ("actual-model-generation", "ready" if actual_model_generation_ready else "blocked", f"ready_rows={sum(int(row['actual_model_generation_ready']) for row in bridge_rows)}"),
    ("production-latency", "blocked", "not a production latency run"),
    ("near-frontier-quality", "blocked", "requires external review and comparison evidence"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61cb-page-hash-promotion-input", "status": "pass", "reason": "v61cb promotion rows are bound"},
    {"gate": "v53t-complete-source-audit-input", "status": "pass", "reason": "v53t audit readiness is bound"},
    {"gate": "v61bt-generation-result-schema-input", "status": "pass", "reason": "v61bt result schema is bound"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if full_page_hash_binding_ready and completed_full_page_hash_coverage_ready else "blocked", "reason": f"verified={v61cb_summary['total_verified_page_hash_rows']}/{v61cb_summary['total_required_page_hash_rows']}"},
    {"gate": "complete-source-review-return", "status": "pass" if review_return_ready else "blocked", "reason": f"accepted_review={v53t_summary['accepted_human_review_rows']}/{v53t_summary['expected_human_review_rows']}"},
    {"gate": "generation-execution-admission", "status": "pass" if generation_execution_admission_ready else "blocked", "reason": f"admitted={generation_execution_admitted_rows}/{len(bridge_rows)}"},
    {"gate": "actual-generation-result-artifacts", "status": "pass" if generation_packet_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={v61bt_summary['accepted_generation_result_artifacts']}/{v61bt_summary['expected_generation_result_artifacts']}"},
    {"gate": "actual-model-generation", "status": "pass" if actual_model_generation_ready else "blocked", "reason": f"ready_rows={sum(int(row['actual_model_generation_ready']) for row in bridge_rows)}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cc writes metadata only"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a production benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cc Ubuntu-1 Page-Hash Generation Admission Bridge Boundary

This gate bridges the current v61cb page-hash promotion state into the
complete-source generation admission surface. It does not execute generation,
does not execute page hashing, does not download checkpoint payload bytes, and
does not commit checkpoint payload bytes to the repository.

Evidence emitted:

- complete_source_query_rows={v61bt_summary['complete_source_query_rows']}
- generation_admission_bridge_rows={len(bridge_rows)}
- machine_complete_source_surface_ready={machine_complete_source_surface_ready}
- complete_source_review_return_ready={review_return_ready}
- full_page_hash_coverage_promotion_ready={v61cb_summary['full_page_hash_coverage_promotion_ready']}
- completed_full_safetensors_page_hash_coverage_ready={completed_full_page_hash_coverage_ready}
- full_safetensors_page_hash_binding_ready={full_page_hash_binding_ready}
- total_verified_page_hash_rows={v61cb_summary['total_verified_page_hash_rows']}
- total_required_page_hash_rows={v61cb_summary['total_required_page_hash_rows']}
- generation_execution_admission_ready={generation_execution_admission_ready}
- generation_execution_admitted_rows={generation_execution_admitted_rows}
- page_hash_blocked_rows={page_hash_blocked_rows}
- review_return_blocked_rows={review_return_blocked_rows}
- generation_result_artifact_blocked_rows={generation_result_artifact_blocked_rows}
- actual_model_generation_ready={actual_model_generation_ready}
- checkpoint_payload_bytes_downloaded_by_v61cc=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: current v61 has a page-hash-to-generation admission bridge
for the 1000 complete-source queries. Blocked wording: completed full
safetensors page-hash coverage, complete-source human review return, actual
model generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61CC_UBUNTU1_PAGE_HASH_GENERATION_ADMISSION_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cc_ubuntu1_page_hash_generation_admission_bridge",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": 1,
    "source_v61cb_summary_sha256": sha256(v61cb_summary_path),
    "source_v53t_summary_sha256": sha256(v53t_summary_path),
    "source_v61bt_summary_sha256": sha256(v61bt_summary_path),
    "complete_source_query_rows": int(v61bt_summary["complete_source_query_rows"]),
    "generation_admission_bridge_rows": len(bridge_rows),
    "generation_execution_admitted_rows": generation_execution_admitted_rows,
    "page_hash_blocked_rows": page_hash_blocked_rows,
    "review_return_blocked_rows": review_return_blocked_rows,
    "generation_result_artifact_blocked_rows": generation_result_artifact_blocked_rows,
    "total_required_page_hash_rows": int(v61cb_summary["total_required_page_hash_rows"]),
    "total_verified_page_hash_rows": int(v61cb_summary["total_verified_page_hash_rows"]),
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_downloaded_by_v61cc": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cc_ubuntu1_page_hash_generation_admission_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cc_ubuntu1_page_hash_generation_admission_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
