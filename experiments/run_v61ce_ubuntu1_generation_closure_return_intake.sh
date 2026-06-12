#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ce_ubuntu1_generation_closure_return_intake"
RUN_ID="${V61CE_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ce_ubuntu1_generation_closure_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61CC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh" >/dev/null
V61CD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cd_ubuntu1_generation_unblocker_closure_bundle.sh" >/dev/null

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


def as_int(value):
    return int(str(value).strip() or "0")


def status(flag):
    return "pass" if flag else "blocked"


v61cb_dir = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate" / "gate_001"
v53t_dir = results / "v53t_complete_source_audit_readiness_gate" / "gate_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"
v61cc_dir = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge" / "bridge_001"
v61cd_dir = results / "v61cd_ubuntu1_generation_unblocker_closure_bundle" / "bundle_001"

v61cb_summary_path = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"
v53t_summary_path = results / "v53t_complete_source_audit_readiness_gate_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61cc_summary_path = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"
v61cd_summary_path = results / "v61cd_ubuntu1_generation_unblocker_closure_bundle_summary.csv"
v61cb_decision_path = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv"
v53t_decision_path = results / "v53t_complete_source_audit_readiness_gate_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"
v61cc_decision_path = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"
v61cd_decision_path = results / "v61cd_ubuntu1_generation_unblocker_closure_bundle_decision.csv"

v61cb = read_csv(v61cb_summary_path)[0]
v53t = read_csv(v53t_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]
v61cc = read_csv(v61cc_summary_path)[0]
v61cd = read_csv(v61cd_summary_path)[0]
for field, summary in [
    ("v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready", v61cb),
    ("v53t_complete_source_audit_readiness_gate_ready", v53t),
    ("v61bt_ubuntu1_actual_generation_result_intake_ready", v61bt),
    ("v61cc_ubuntu1_page_hash_generation_admission_bridge_ready", v61cc),
    ("v61cd_ubuntu1_generation_unblocker_closure_bundle_ready", v61cd),
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v61ce requires {field}=1")

target_root = v61cc["target_root_path"]
for source_name, summary in [
    ("v61cb", v61cb),
    ("v61bt", v61bt),
    ("v61cd", v61cd),
]:
    if summary.get("target_root_path") != target_root:
        raise SystemExit(f"v61ce requires target root match for {source_name}")

for src, rel in [
    (v61cb_summary_path, "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"),
    (v61cb_decision_path, "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_rows.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_metric_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_metric_rows.csv"),
    (v61cb_dir / "runtime_gap_rows.csv", "source_v61cb/runtime_gap_rows.csv"),
    (v61cb_dir / "sha256_manifest.csv", "source_v61cb/sha256_manifest.csv"),
    (v53t_summary_path, "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv"),
    (v53t_decision_path, "source_v53t/v53t_complete_source_audit_readiness_gate_decision.csv"),
    (v53t_dir / "complete_source_audit_readiness_metric_rows.csv", "source_v53t/complete_source_audit_readiness_metric_rows.csv"),
    (v53t_dir / "complete_source_audit_readiness_requirement_rows.csv", "source_v53t/complete_source_audit_readiness_requirement_rows.csv"),
    (v53t_dir / "sha256_manifest.csv", "source_v53t/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_result_status_rows.csv", "source_v61bt/actual_generation_result_status_rows.csv"),
    (v61bt_dir / "actual_generation_query_result_rows.csv", "source_v61bt/actual_generation_query_result_rows.csv"),
    (v61bt_dir / "actual_generation_result_metric_rows.csv", "source_v61bt/actual_generation_result_metric_rows.csv"),
    (v61bt_dir / "runtime_gap_rows.csv", "source_v61bt/runtime_gap_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
    (v61cc_summary_path, "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"),
    (v61cc_decision_path, "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"),
    (v61cc_dir / "page_hash_generation_admission_bridge_rows.csv", "source_v61cc/page_hash_generation_admission_bridge_rows.csv"),
    (v61cc_dir / "page_hash_generation_admission_requirement_rows.csv", "source_v61cc/page_hash_generation_admission_requirement_rows.csv"),
    (v61cc_dir / "runtime_gap_rows.csv", "source_v61cc/runtime_gap_rows.csv"),
    (v61cc_dir / "sha256_manifest.csv", "source_v61cc/sha256_manifest.csv"),
    (v61cd_summary_path, "source_v61cd/v61cd_ubuntu1_generation_unblocker_closure_bundle_summary.csv"),
    (v61cd_decision_path, "source_v61cd/v61cd_ubuntu1_generation_unblocker_closure_bundle_decision.csv"),
    (v61cd_dir / "generation_unblocker_phase_rows.csv", "source_v61cd/generation_unblocker_phase_rows.csv"),
    (v61cd_dir / "generation_unblocker_return_artifact_rows.csv", "source_v61cd/generation_unblocker_return_artifact_rows.csv"),
    (v61cd_dir / "generation_unblocker_metric_rows.csv", "source_v61cd/generation_unblocker_metric_rows.csv"),
    (v61cd_dir / "runtime_gap_rows.csv", "source_v61cd/runtime_gap_rows.csv"),
    (v61cd_dir / "sha256_manifest.csv", "source_v61cd/sha256_manifest.csv"),
]:
    copy(src, rel)

bridge_rows = read_csv(v61cc_dir / "page_hash_generation_admission_bridge_rows.csv")
if len(bridge_rows) != 1000:
    raise SystemExit("v61ce expects 1000 v61cc bridge rows")

page_hash_closure_ready = int(
    v61cb["full_page_hash_coverage_promotion_ready"] == "1"
    and v61cb["completed_full_safetensors_page_hash_coverage_ready"] == "1"
    and v61cb["full_safetensors_page_hash_binding_ready"] == "1"
)
review_return_closure_ready = int(
    v53t["review_return_ready"] == "1"
    and v53t["human_review_completed"] == "1"
    and v53t["adjudication_completed"] == "1"
)
generation_result_closure_ready = int(
    v61bt["actual_model_generation_ready"] == "1"
    and v61bt["source_bound_qa_generation_ready"] == "1"
    and v61bt["generation_packet_artifacts_ready"] == "1"
)
generation_closure_return_intake_ready = int(
    page_hash_closure_ready and review_return_closure_ready and generation_result_closure_ready
)
generation_execution_admission_ready = int(
    generation_closure_return_intake_ready
    and v61cc["machine_complete_source_surface_ready"] == "1"
    and v61cc["generation_result_schema_ready"] == "1"
)
generation_execution_admitted_rows = len(bridge_rows) if generation_execution_admission_ready else 0

review_required_rows = (
    as_int(v53t["expected_human_review_rows"])
    + as_int(v53t["expected_adjudication_rows"])
)
review_accepted_rows = (
    as_int(v53t["accepted_human_review_rows"])
    + as_int(v53t["accepted_adjudication_rows"])
)
page_hash_blocked_rows = 0 if page_hash_closure_ready else len(bridge_rows)
review_return_blocked_rows = 0 if review_return_closure_ready else len(bridge_rows)
generation_result_artifact_blocked_rows = 0 if generation_result_closure_ready else len(bridge_rows)

gate_rows = [
    {
        "closure_gate_id": "page-hash-coverage-return",
        "source_gate": "v61cb",
        "required_rows": v61cb["total_required_page_hash_rows"],
        "accepted_rows": v61cb["total_verified_page_hash_rows"],
        "missing_rows": v61cb["promotion_missing_page_hash_rows"],
        "invalid_rows": v61cb["promotion_invalid_page_hash_rows"],
        "required_artifacts": "1",
        "accepted_artifacts": str(page_hash_closure_ready),
        "closure_ready": str(page_hash_closure_ready),
        "blocks_generation_rows": str(page_hash_blocked_rows),
        "reason": "full page-hash coverage must cover every safetensors page",
    },
    {
        "closure_gate_id": "complete-source-review-return",
        "source_gate": "v53t",
        "required_rows": str(review_required_rows),
        "accepted_rows": str(review_accepted_rows),
        "missing_rows": str(review_required_rows - review_accepted_rows),
        "invalid_rows": "0",
        "required_artifacts": "5",
        "accepted_artifacts": "0" if not review_return_closure_ready else "5",
        "closure_ready": str(review_return_closure_ready),
        "blocks_generation_rows": str(review_return_blocked_rows),
        "reason": "complete-source human review and adjudication must be accepted",
    },
    {
        "closure_gate_id": "actual-generation-result-return",
        "source_gate": "v61bt",
        "required_rows": v61bt["complete_source_query_rows"],
        "accepted_rows": v61bt["accepted_generation_rows"],
        "missing_rows": str(as_int(v61bt["complete_source_query_rows"]) - as_int(v61bt["accepted_generation_rows"])),
        "invalid_rows": v61bt["invalid_generation_result_artifacts"],
        "required_artifacts": v61bt["expected_generation_result_artifacts"],
        "accepted_artifacts": v61bt["accepted_generation_result_artifacts"],
        "closure_ready": str(generation_result_closure_ready),
        "blocks_generation_rows": str(generation_result_artifact_blocked_rows),
        "reason": "actual source-bound generation answer, citation, abstain/fallback, latency, and acceptance artifacts must be accepted",
    },
]
write_csv(run_dir / "generation_closure_return_gate_rows.csv", list(gate_rows[0].keys()), gate_rows)

blocked_reasons = []
if not page_hash_closure_ready:
    blocked_reasons.append("page-hash-coverage-return")
if not review_return_closure_ready:
    blocked_reasons.append("complete-source-review-return")
if not generation_result_closure_ready:
    blocked_reasons.append("actual-generation-result-return")
blocked_reason = "none" if not blocked_reasons else ";".join(blocked_reasons)
admission_rows = []
for index, row in enumerate(bridge_rows):
    admission_rows.append(
        {
            "generation_closure_admission_id": f"v61ce-generation-closure-admission-{index:04d}",
            "generation_admission_bridge_id": row["generation_admission_bridge_id"],
            "review_query_packet_id": row["review_query_packet_id"],
            "query_id": row["query_id"],
            "owner_repo": row["owner_repo"],
            "source_span_id": row["source_span_id"],
            "page_hash_closure_ready": str(page_hash_closure_ready),
            "review_return_closure_ready": str(review_return_closure_ready),
            "generation_result_closure_ready": str(generation_result_closure_ready),
            "generation_closure_return_intake_ready": str(generation_closure_return_intake_ready),
            "generation_execution_admitted": str(generation_execution_admission_ready),
            "blocked_reason": blocked_reason,
            "checkpoint_payload_bytes_downloaded_by_v61ce": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "generation_closure_return_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)

requirement_rows = [
    {
        "requirement_id": "v61cd-closure-bundle-input",
        "required_value": "v61cd ready",
        "actual_value": v61cd["v61cd_ubuntu1_generation_unblocker_closure_bundle_ready"],
        "status": "pass",
        "reason": "operator closure bundle evidence is bound",
    },
    {
        "requirement_id": "full-page-hash-coverage-return",
        "required_value": v61cb["total_required_page_hash_rows"],
        "actual_value": v61cb["total_verified_page_hash_rows"],
        "status": status(page_hash_closure_ready),
        "reason": f"verified={v61cb['total_verified_page_hash_rows']}/{v61cb['total_required_page_hash_rows']}",
    },
    {
        "requirement_id": "complete-source-review-return",
        "required_value": str(review_required_rows),
        "actual_value": str(review_accepted_rows),
        "status": status(review_return_closure_ready),
        "reason": f"review_return_ready={v53t['review_return_ready']}",
    },
    {
        "requirement_id": "actual-generation-result-return",
        "required_value": v61bt["expected_generation_result_artifacts"],
        "actual_value": v61bt["accepted_generation_result_artifacts"],
        "status": status(generation_result_closure_ready),
        "reason": f"actual_model_generation_ready={v61bt['actual_model_generation_ready']}",
    },
    {
        "requirement_id": "generation-closure-return-intake",
        "required_value": "all three closure gates ready",
        "actual_value": str(generation_closure_return_intake_ready),
        "status": status(generation_closure_return_intake_ready),
        "reason": f"page_hash={page_hash_closure_ready}; review={review_return_closure_ready}; generation={generation_result_closure_ready}",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "required_value": "0",
        "actual_value": "0",
        "status": "pass",
        "reason": "v61ce copies metadata, summary rows, and hashes only",
    },
]
write_csv(run_dir / "generation_closure_return_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ce_ubuntu1_generation_closure_return_intake_metrics",
    "model_id": model_id,
    "target_root_path": target_root,
    "closure_gate_rows": str(len(gate_rows)),
    "generation_closure_admission_rows": str(len(admission_rows)),
    "complete_source_query_rows": v61cc["complete_source_query_rows"],
    "generation_admission_bridge_rows": v61cc["generation_admission_bridge_rows"],
    "page_hash_return_required_rows": v61cd["page_hash_return_required_rows"],
    "page_hash_return_accepted_rows": v61cd["page_hash_return_accepted_rows"],
    "total_required_page_hash_rows": v61cb["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61cb["total_verified_page_hash_rows"],
    "human_review_required_rows": v53t["expected_human_review_rows"],
    "human_review_accepted_rows": v53t["accepted_human_review_rows"],
    "adjudication_required_rows": v53t["expected_adjudication_rows"],
    "adjudication_accepted_rows": v53t["accepted_adjudication_rows"],
    "generation_result_required_artifacts": v61bt["expected_generation_result_artifacts"],
    "generation_result_accepted_artifacts": v61bt["accepted_generation_result_artifacts"],
    "accepted_generation_rows": v61bt["accepted_generation_rows"],
    "page_hash_closure_ready": str(page_hash_closure_ready),
    "review_return_closure_ready": str(review_return_closure_ready),
    "generation_result_closure_ready": str(generation_result_closure_ready),
    "generation_closure_return_intake_ready": str(generation_closure_return_intake_ready),
    "generation_execution_admission_ready": str(generation_execution_admission_ready),
    "generation_execution_admitted_rows": str(generation_execution_admitted_rows),
    "page_hash_blocked_rows": str(page_hash_blocked_rows),
    "review_return_blocked_rows": str(review_return_blocked_rows),
    "generation_result_artifact_blocked_rows": str(generation_result_artifact_blocked_rows),
    "actual_model_generation_ready": str(generation_result_closure_ready),
    "source_bound_qa_generation_ready": v61bt["source_bound_qa_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ce": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "generation_closure_return_metric_rows.csv", list(metric.keys()), [metric])

runtime_gap_rows = [
    ("v61cd-closure-bundle-input", "ready", "closure bundle evidence is present"),
    ("full-page-hash-coverage-return", status(page_hash_closure_ready), f"verified={v61cb['total_verified_page_hash_rows']}/{v61cb['total_required_page_hash_rows']}"),
    ("complete-source-review-return", status(review_return_closure_ready), f"accepted_review={review_accepted_rows}/{review_required_rows}"),
    ("actual-generation-result-return", status(generation_result_closure_ready), f"accepted_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"),
    ("generation-closure-return-intake", status(generation_closure_return_intake_ready), "requires page-hash, review, and generation returns"),
    ("actual-model-generation", status(generation_result_closure_ready), "requires accepted source-bound generation artifacts"),
    ("production-latency", "blocked", "not a production latency run"),
    ("near-frontier-quality", "blocked", "not an external near-frontier quality review"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": state, "reason": reason} for gap, state, reason in runtime_gap_rows],
)

boundary = f"""# v61ce Ubuntu-1 Generation Closure Return Intake Boundary

This gate consumes v61cd plus the current page-hash, complete-source review, and
actual-generation result intake summaries. It decides whether the generation
unblocker returns are closed as a combined admission surface.

Current state:

- closure_gate_rows={len(gate_rows)}
- generation_closure_admission_rows={len(admission_rows)}
- complete_source_query_rows={v61cc['complete_source_query_rows']}
- total_verified_page_hash_rows={v61cb['total_verified_page_hash_rows']}
- total_required_page_hash_rows={v61cb['total_required_page_hash_rows']}
- page_hash_return_required_rows={v61cd['page_hash_return_required_rows']}
- page_hash_return_accepted_rows={v61cd['page_hash_return_accepted_rows']}
- human_review_required_rows={v53t['expected_human_review_rows']}
- human_review_accepted_rows={v53t['accepted_human_review_rows']}
- adjudication_required_rows={v53t['expected_adjudication_rows']}
- adjudication_accepted_rows={v53t['accepted_adjudication_rows']}
- generation_result_required_artifacts={v61bt['expected_generation_result_artifacts']}
- generation_result_accepted_artifacts={v61bt['accepted_generation_result_artifacts']}
- accepted_generation_rows={v61bt['accepted_generation_rows']}
- page_hash_closure_ready={page_hash_closure_ready}
- review_return_closure_ready={review_return_closure_ready}
- generation_result_closure_ready={generation_result_closure_ready}
- generation_closure_return_intake_ready={generation_closure_return_intake_ready}
- generation_execution_admitted_rows={generation_execution_admitted_rows}
- page_hash_blocked_rows={page_hash_blocked_rows}
- review_return_blocked_rows={review_return_blocked_rows}
- generation_result_artifact_blocked_rows={generation_result_artifact_blocked_rows}
- actual_model_generation_ready={generation_result_closure_ready}
- checkpoint_payload_bytes_downloaded_by_v61ce=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

v61ce does not claim actual Mixtral generation, completed full safetensors
page-hash coverage, production latency, near-frontier quality, or a release
package. It is a return-intake and admission gate over metadata rows only.
"""
(run_dir / "V61CE_UBUNTU1_GENERATION_CLOSURE_RETURN_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

summary = {
    "v61ce_ubuntu1_generation_closure_return_intake_ready": "1",
    "model_id": model_id,
    "v61cd_ubuntu1_generation_unblocker_closure_bundle_ready": v61cd["v61cd_ubuntu1_generation_unblocker_closure_bundle_ready"],
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": v61cb["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
    "v53t_complete_source_audit_readiness_gate_ready": v53t["v53t_complete_source_audit_readiness_gate_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": v61cc["v61cc_ubuntu1_page_hash_generation_admission_bridge_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decisions = [
    {"gate": "v61cd-closure-bundle-input", "status": "pass", "reason": "v61cd closure bundle is bound"},
    {"gate": "full-page-hash-coverage-return", "status": status(page_hash_closure_ready), "reason": f"verified={v61cb['total_verified_page_hash_rows']}/{v61cb['total_required_page_hash_rows']}"},
    {"gate": "complete-source-review-return", "status": status(review_return_closure_ready), "reason": f"review_return_ready={v53t['review_return_ready']}"},
    {"gate": "actual-generation-result-return", "status": status(generation_result_closure_ready), "reason": f"accepted_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gate": "generation-closure-return-intake", "status": status(generation_closure_return_intake_ready), "reason": "requires all three closure gates"},
    {"gate": "actual-model-generation", "status": status(generation_result_closure_ready), "reason": "actual generation artifacts are not accepted"},
    {"gate": "production-latency", "status": "blocked", "reason": "no production latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "no external near-frontier quality review"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not a release package"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "no checkpoint payload bytes are copied into the repository"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decisions)

manifest = {
    "artifact": "v61ce_ubuntu1_generation_closure_return_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "target_root_path": target_root,
    "v61ce_ubuntu1_generation_closure_return_intake_ready": 1,
    "source_v61cd_summary_sha256": sha256(v61cd_summary_path),
    "source_v61cc_summary_sha256": sha256(v61cc_summary_path),
    "closure_gate_rows": len(gate_rows),
    "generation_closure_admission_rows": len(admission_rows),
    "complete_source_query_rows": as_int(v61cc["complete_source_query_rows"]),
    "total_required_page_hash_rows": as_int(v61cb["total_required_page_hash_rows"]),
    "total_verified_page_hash_rows": as_int(v61cb["total_verified_page_hash_rows"]),
    "page_hash_closure_ready": page_hash_closure_ready,
    "review_return_closure_ready": review_return_closure_ready,
    "generation_result_closure_ready": generation_result_closure_ready,
    "generation_closure_return_intake_ready": generation_closure_return_intake_ready,
    "generation_execution_admitted_rows": generation_execution_admitted_rows,
    "actual_model_generation_ready": generation_result_closure_ready,
    "checkpoint_payload_bytes_downloaded_by_v61ce": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ce_ubuntu1_generation_closure_return_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61ce_ubuntu1_generation_closure_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
