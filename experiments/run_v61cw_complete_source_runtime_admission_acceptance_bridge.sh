#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cw_complete_source_runtime_admission_acceptance_bridge"
RUN_ID="${V61CW_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CW_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cw_complete_source_runtime_admission_acceptance_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cq_complete_source_runtime_admission_expansion_packet.sh" >/dev/null
V61CV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cv_complete_source_runtime_admission_operator_bundle.sh" >/dev/null
V61CR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null

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


def status(flag):
    return "pass" if flag else "blocked"


v61cq_dir = results / "v61cq_complete_source_runtime_admission_expansion_packet" / "packet_001"
v61cv_dir = results / "v61cv_complete_source_runtime_admission_operator_bundle" / "bundle_001"
v61cr_dir = results / "v61cr_complete_source_runtime_admission_return_intake" / "intake_001"

v61cq_summary_path = results / "v61cq_complete_source_runtime_admission_expansion_packet_summary.csv"
v61cv_summary_path = results / "v61cv_complete_source_runtime_admission_operator_bundle_summary.csv"
v61cr_summary_path = results / "v61cr_complete_source_runtime_admission_return_intake_summary.csv"
v61cq_decision_path = results / "v61cq_complete_source_runtime_admission_expansion_packet_decision.csv"
v61cv_decision_path = results / "v61cv_complete_source_runtime_admission_operator_bundle_decision.csv"
v61cr_decision_path = results / "v61cr_complete_source_runtime_admission_return_intake_decision.csv"

v61cq = read_csv(v61cq_summary_path)[0]
v61cv = read_csv(v61cv_summary_path)[0]
v61cr = read_csv(v61cr_summary_path)[0]
for key, row in [
    ("v61cq_complete_source_runtime_admission_expansion_packet_ready", v61cq),
    ("v61cv_complete_source_runtime_admission_operator_bundle_ready", v61cv),
    ("v61cr_complete_source_runtime_admission_return_intake_ready", v61cr),
]:
    if row.get(key) != "1":
        raise SystemExit(f"v61cw requires {key}=1")

for src, rel in [
    (v61cq_summary_path, "source_v61cq/v61cq_complete_source_runtime_admission_expansion_packet_summary.csv"),
    (v61cq_decision_path, "source_v61cq/v61cq_complete_source_runtime_admission_expansion_packet_decision.csv"),
    (v61cq_dir / "complete_source_runtime_admission_expansion_rows.csv", "source_v61cq/complete_source_runtime_admission_expansion_rows.csv"),
    (v61cq_dir / "complete_source_runtime_admission_return_manifest_rows.csv", "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv"),
    (v61cq_dir / "sha256_manifest.csv", "source_v61cq/sha256_manifest.csv"),
    (v61cv_summary_path, "source_v61cv/v61cv_complete_source_runtime_admission_operator_bundle_summary.csv"),
    (v61cv_decision_path, "source_v61cv/v61cv_complete_source_runtime_admission_operator_bundle_decision.csv"),
    (v61cv_dir / "complete_source_runtime_admission_operator_command_rows.csv", "source_v61cv/complete_source_runtime_admission_operator_command_rows.csv"),
    (v61cv_dir / "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv", "source_v61cv/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv"),
    (v61cv_dir / "sha256_manifest.csv", "source_v61cv/sha256_manifest.csv"),
    (v61cr_summary_path, "source_v61cr/v61cr_complete_source_runtime_admission_return_intake_summary.csv"),
    (v61cr_decision_path, "source_v61cr/v61cr_complete_source_runtime_admission_return_intake_decision.csv"),
    (v61cr_dir / "complete_source_runtime_admission_return_artifact_status_rows.csv", "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv"),
    (v61cr_dir / "complete_source_runtime_admission_return_requirement_rows.csv", "source_v61cr/complete_source_runtime_admission_return_requirement_rows.csv"),
    (v61cr_dir / "complete_source_runtime_admission_return_metric_rows.csv", "source_v61cr/complete_source_runtime_admission_return_metric_rows.csv"),
    (v61cr_dir / "sha256_manifest.csv", "source_v61cr/sha256_manifest.csv"),
]:
    copy(src, rel)

expansion_rows = read_csv(v61cq_dir / "complete_source_runtime_admission_expansion_rows.csv")
artifact_rows = read_csv(v61cr_dir / "complete_source_runtime_admission_return_artifact_status_rows.csv")
if len(expansion_rows) != 1000:
    raise SystemExit("v61cw expects 1000 expansion rows")
if len(artifact_rows) != 5:
    raise SystemExit("v61cw expects five v61cr artifact status rows")

runtime_artifact_ready = int(v61cr["runtime_admission_return_artifact_ready"] == "1")
runtime_result_ready = int(v61cr["runtime_admission_result_rows_ready"] == "1")
runtime_page_binding_ready = int(v61cr["runtime_page_binding_ready"] == "1")
runtime_budget_ready = int(v61cr["runtime_budget_ready"] == "1")
runtime_identity_ready = int(v61cr["runtime_identity_ready"] == "1")
runtime_safety_ready = int(v61cr["runtime_safety_ready"] == "1")
operator_guard_ready = int(v61cv["guarded_runtime_admission_command_ready"] == "1")
runtime_execution_ready = int(v61cr["complete_source_runtime_admission_execution_ready"] == "1")

acceptance_rows = []
accepted_rows = 0
operator_guard_blocked_rows = 0
artifact_blocked_rows = 0
result_blocked_rows = 0
page_binding_blocked_rows = 0
budget_blocked_rows = 0
identity_blocked_rows = 0
safety_blocked_rows = 0

for index, row in enumerate(expansion_rows):
    operator_guard_blocked = int(not operator_guard_ready)
    artifact_blocked = int(not runtime_artifact_ready)
    result_blocked = int(not runtime_result_ready)
    page_binding_blocked = int(not runtime_page_binding_ready)
    budget_blocked = int(not runtime_budget_ready)
    identity_blocked = int(not runtime_identity_ready)
    safety_blocked = int(not runtime_safety_ready)
    accepted = int(
        runtime_execution_ready
        and not operator_guard_blocked
        and not artifact_blocked
        and not result_blocked
        and not page_binding_blocked
        and not budget_blocked
        and not identity_blocked
        and not safety_blocked
    )
    accepted_rows += accepted
    operator_guard_blocked_rows += operator_guard_blocked
    artifact_blocked_rows += artifact_blocked
    result_blocked_rows += result_blocked
    page_binding_blocked_rows += page_binding_blocked
    budget_blocked_rows += budget_blocked
    identity_blocked_rows += identity_blocked
    safety_blocked_rows += safety_blocked
    reasons = []
    if operator_guard_blocked:
        reasons.append("runtime-admission-operator-guard-blocked")
    if artifact_blocked:
        reasons.append("runtime-admission-return-artifacts-missing")
    if result_blocked:
        reasons.append("runtime-admission-result-rows-missing")
    if page_binding_blocked:
        reasons.append("runtime-page-binding-rows-missing")
    if budget_blocked:
        reasons.append("runtime-budget-rows-missing")
    if identity_blocked:
        reasons.append("runtime-identity-rows-missing")
    if safety_blocked:
        reasons.append("runtime-safety-rows-missing")
    acceptance_rows.append(
        {
            "runtime_admission_acceptance_id": f"v61cw-runtime-admission-acceptance-{index:04d}",
            "expansion_row_id": row["expansion_row_id"],
            "query_id": row["query_id"],
            "review_query_packet_id": row["review_query_packet_id"],
            "generation_execution_packet_id": row["generation_execution_packet_id"],
            "owner_repo": row["owner_repo"],
            "audit_type": row["audit_type"],
            "expected_behavior": row["expected_behavior"],
            "source_span_id": row["source_span_id"],
            "model_id": row["model_id"],
            "checkpoint_root": row["checkpoint_root"],
            "operator_guard_ready": str(operator_guard_ready),
            "runtime_admission_return_artifact_ready": str(runtime_artifact_ready),
            "runtime_admission_result_rows_ready": str(runtime_result_ready),
            "runtime_page_binding_ready": str(runtime_page_binding_ready),
            "runtime_budget_ready": str(runtime_budget_ready),
            "runtime_identity_ready": str(runtime_identity_ready),
            "runtime_safety_ready": str(runtime_safety_ready),
            "complete_source_runtime_admission_execution_ready": str(runtime_execution_ready),
            "runtime_admission_accepted": str(accepted),
            "blocking_reason": ";".join(reasons) if reasons else "accepted",
            "checkpoint_payload_bytes_downloaded_by_v61cw": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "complete_source_runtime_admission_acceptance_rows.csv", list(acceptance_rows[0].keys()), acceptance_rows)

requirement_rows = [
    {"requirement_id": "v61cq-runtime-admission-expansion-input", "status": "pass", "required_value": "1", "actual_value": v61cq["v61cq_complete_source_runtime_admission_expansion_packet_ready"], "reason": "v61cq expansion packet is bound"},
    {"requirement_id": "v61cv-runtime-admission-operator-input", "status": "pass", "required_value": "1", "actual_value": v61cv["v61cv_complete_source_runtime_admission_operator_bundle_ready"], "reason": "v61cv operator bundle is bound"},
    {"requirement_id": "v61cr-runtime-admission-return-input", "status": "pass", "required_value": "1", "actual_value": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"], "reason": "v61cr return intake is bound"},
    {"requirement_id": "runtime-admission-return-artifacts", "status": status(runtime_artifact_ready), "required_value": v61cr["expected_runtime_admission_return_artifacts"], "actual_value": v61cr["accepted_runtime_admission_return_artifacts"], "reason": "all runtime return artifacts must be accepted"},
    {"requirement_id": "runtime-admission-result-rows", "status": status(runtime_result_ready), "required_value": v61cr["expected_runtime_admission_result_rows"], "actual_value": v61cr["accepted_runtime_admission_result_rows"], "reason": "all runtime result rows must be admitted"},
    {"requirement_id": "runtime-page-binding-rows", "status": status(runtime_page_binding_ready), "required_value": v61cr["complete_source_query_rows"], "actual_value": v61cr["accepted_runtime_page_binding_rows"], "reason": "all runtime page bindings must be verified"},
    {"requirement_id": "runtime-budget-rows", "status": status(runtime_budget_ready), "required_value": v61cr["complete_source_query_rows"], "actual_value": v61cr["accepted_runtime_budget_rows"], "reason": "all runtime budgets must be verified"},
    {"requirement_id": "runtime-identity-rows", "status": status(runtime_identity_ready), "required_value": "59", "actual_value": v61cr["accepted_runtime_identity_rows"], "reason": "all checkpoint identity rows must be accepted"},
    {"requirement_id": "runtime-safety-rows", "status": status(runtime_safety_ready), "required_value": v61cr["complete_source_query_rows"], "actual_value": v61cr["accepted_runtime_abstain_fallback_rows"], "reason": "citation/abstain/fallback safety rows must be accepted"},
    {"requirement_id": "complete-source-runtime-admission-acceptance", "status": status(accepted_rows == len(expansion_rows)), "required_value": str(len(expansion_rows)), "actual_value": str(accepted_rows), "reason": "all complete-source runtime admission rows must be accepted"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61cw writes metadata and copied evidence only"},
]
write_csv(run_dir / "complete_source_runtime_admission_acceptance_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cw_complete_source_runtime_admission_acceptance_bridge_metrics",
    "model_id": model_id,
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": v61cq["v61cq_complete_source_runtime_admission_expansion_packet_ready"],
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": v61cv["v61cv_complete_source_runtime_admission_operator_bundle_ready"],
    "v61cr_complete_source_runtime_admission_return_intake_ready": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"],
    "runtime_admission_acceptance_rows": str(len(acceptance_rows)),
    "runtime_admission_accepted_rows": str(accepted_rows),
    "operator_guard_blocked_acceptance_rows": str(operator_guard_blocked_rows),
    "runtime_artifact_blocked_acceptance_rows": str(artifact_blocked_rows),
    "runtime_result_blocked_acceptance_rows": str(result_blocked_rows),
    "runtime_page_binding_blocked_acceptance_rows": str(page_binding_blocked_rows),
    "runtime_budget_blocked_acceptance_rows": str(budget_blocked_rows),
    "runtime_identity_blocked_acceptance_rows": str(identity_blocked_rows),
    "runtime_safety_blocked_acceptance_rows": str(safety_blocked_rows),
    "guarded_runtime_admission_command_ready": str(operator_guard_ready),
    "runtime_admission_return_artifact_ready": str(runtime_artifact_ready),
    "runtime_admission_result_rows_ready": str(runtime_result_ready),
    "runtime_page_binding_ready": str(runtime_page_binding_ready),
    "runtime_budget_ready": str(runtime_budget_ready),
    "runtime_identity_ready": str(runtime_identity_ready),
    "runtime_safety_ready": str(runtime_safety_ready),
    "complete_source_runtime_admission_execution_ready": str(runtime_execution_ready),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_runtime_admission_acceptance_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "runtime-admission-expansion-input", "status": "ready", "reason": "v61cq expansion packet is bound"},
    {"gap": "runtime-admission-operator-input", "status": "ready", "reason": "v61cv operator bundle is bound"},
    {"gap": "runtime-admission-return-intake", "status": "ready", "reason": "v61cr return intake is bound"},
    {"gap": "runtime-admission-acceptance", "status": "ready" if accepted_rows == len(acceptance_rows) else "blocked", "reason": f"runtime_admission_accepted_rows={accepted_rows}/{len(acceptance_rows)}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "complete-source runtime admission acceptance is not ready"},
    {"gap": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gap": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "runtime-admission-expansion-input", "status": "pass", "reason": "v61cq is ready"},
    {"gate": "runtime-admission-operator-input", "status": "pass", "reason": "v61cv is ready"},
    {"gate": "runtime-admission-return-intake", "status": "pass", "reason": "v61cr is ready"},
    {"gate": "runtime-admission-acceptance", "status": "pass" if accepted_rows == len(acceptance_rows) else "blocked", "reason": f"runtime_admission_accepted_rows={accepted_rows}/{len(acceptance_rows)}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cw writes metadata only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cw Complete-Source Runtime Admission Acceptance Bridge Boundary

This artifact converts v61cr aggregate runtime-admission return intake into a
1000-row per-query acceptance ledger over the v61cq expansion packet. It does
not fabricate runtime rows and does not claim complete-source runtime admission
until every runtime result, page binding, budget, identity, and safety family is
accepted.

Evidence emitted:

- runtime_admission_acceptance_rows={len(acceptance_rows)}
- runtime_admission_accepted_rows={accepted_rows}
- operator_guard_blocked_acceptance_rows={operator_guard_blocked_rows}
- runtime_artifact_blocked_acceptance_rows={artifact_blocked_rows}
- runtime_result_blocked_acceptance_rows={result_blocked_rows}
- runtime_page_binding_blocked_acceptance_rows={page_binding_blocked_rows}
- runtime_budget_blocked_acceptance_rows={budget_blocked_rows}
- runtime_identity_blocked_acceptance_rows={identity_blocked_rows}
- runtime_safety_blocked_acceptance_rows={safety_blocked_rows}
- guarded_runtime_admission_command_ready={operator_guard_ready}
- runtime_admission_return_artifact_ready={runtime_artifact_ready}
- runtime_admission_result_rows_ready={runtime_result_ready}
- runtime_page_binding_ready={runtime_page_binding_ready}
- runtime_budget_ready={runtime_budget_ready}
- runtime_identity_ready={runtime_identity_ready}
- runtime_safety_ready={runtime_safety_ready}
- complete_source_runtime_admission_execution_ready={runtime_execution_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cw=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: per-query complete-source runtime admission acceptance bridge.
Blocked wording: completed runtime admission, actual Mixtral generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CW_COMPLETE_SOURCE_RUNTIME_ADMISSION_ACCEPTANCE_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cw_complete_source_runtime_admission_acceptance_bridge",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": 1,
    "source_v61cq_summary_sha256": sha256(v61cq_summary_path),
    "source_v61cv_summary_sha256": sha256(v61cv_summary_path),
    "source_v61cr_summary_sha256": sha256(v61cr_summary_path),
    "runtime_admission_acceptance_rows": len(acceptance_rows),
    "runtime_admission_accepted_rows": accepted_rows,
    "complete_source_runtime_admission_execution_ready": runtime_execution_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cw_complete_source_runtime_admission_acceptance_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cw_complete_source_runtime_admission_acceptance_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
