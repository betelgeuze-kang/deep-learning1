#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53v_complete_source_review_return_acceptance_bridge"
RUN_ID="${V53V_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53V_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53v_complete_source_review_return_acceptance_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V53U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53u_complete_source_review_return_operator_bundle.sh" >/dev/null
V53S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

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


v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v53s_dir = results / "v53s_complete_source_review_return_intake" / "intake_001"
v53t_dir = results / "v53t_complete_source_audit_readiness_gate" / "gate_001"
v53u_dir = results / "v53u_complete_source_review_return_operator_bundle" / "bundle_001"

v53r_summary_path = results / "v53r_complete_source_review_packet_summary.csv"
v53s_summary_path = results / "v53s_complete_source_review_return_intake_summary.csv"
v53t_summary_path = results / "v53t_complete_source_audit_readiness_gate_summary.csv"
v53u_summary_path = results / "v53u_complete_source_review_return_operator_bundle_summary.csv"
v53r_decision_path = results / "v53r_complete_source_review_packet_decision.csv"
v53s_decision_path = results / "v53s_complete_source_review_return_intake_decision.csv"
v53t_decision_path = results / "v53t_complete_source_audit_readiness_gate_decision.csv"
v53u_decision_path = results / "v53u_complete_source_review_return_operator_bundle_decision.csv"

v53r = read_csv(v53r_summary_path)[0]
v53s = read_csv(v53s_summary_path)[0]
v53t = read_csv(v53t_summary_path)[0]
v53u = read_csv(v53u_summary_path)[0]

for key, row in [
    ("v53r_complete_source_review_packet_ready", v53r),
    ("v53s_complete_source_review_return_intake_ready", v53s),
    ("v53t_complete_source_audit_readiness_gate_ready", v53t),
    ("v53u_complete_source_review_return_operator_bundle_ready", v53u),
]:
    if row.get(key) != "1":
        raise SystemExit(f"v53v requires {key}=1")

for src, rel in [
    (v53r_summary_path, "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (v53r_decision_path, "source_v53r/v53r_complete_source_review_packet_decision.csv"),
    (v53r_dir / "review_answer_packet_rows.csv", "source_v53r/review_answer_packet_rows.csv"),
    (v53r_dir / "review_queue_rows.csv", "source_v53r/review_queue_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53r_dir / "sha256_manifest.csv", "source_v53r/sha256_manifest.csv"),
    (v53s_summary_path, "source_v53s/v53s_complete_source_review_return_intake_summary.csv"),
    (v53s_decision_path, "source_v53s/v53s_complete_source_review_return_intake_decision.csv"),
    (v53s_dir / "review_return_artifact_gate_rows.csv", "source_v53s/review_return_artifact_gate_rows.csv"),
    (v53s_dir / "review_return_validation_rows.csv", "source_v53s/review_return_validation_rows.csv"),
    (v53s_dir / "review_return_metric_rows.csv", "source_v53s/review_return_metric_rows.csv"),
    (v53s_dir / "sha256_manifest.csv", "source_v53s/sha256_manifest.csv"),
    (v53t_summary_path, "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv"),
    (v53t_decision_path, "source_v53t/v53t_complete_source_audit_readiness_gate_decision.csv"),
    (v53t_dir / "complete_source_audit_readiness_requirement_rows.csv", "source_v53t/complete_source_audit_readiness_requirement_rows.csv"),
    (v53t_dir / "complete_source_audit_claim_rows.csv", "source_v53t/complete_source_audit_claim_rows.csv"),
    (v53t_dir / "sha256_manifest.csv", "source_v53t/sha256_manifest.csv"),
    (v53u_summary_path, "source_v53u/v53u_complete_source_review_return_operator_bundle_summary.csv"),
    (v53u_decision_path, "source_v53u/v53u_complete_source_review_return_operator_bundle_decision.csv"),
    (v53u_dir / "reviewer_workload_chunk_rows.csv", "source_v53u/reviewer_workload_chunk_rows.csv"),
    (v53u_dir / "review_return_expected_artifact_rows.csv", "source_v53u/review_return_expected_artifact_rows.csv"),
    (v53u_dir / "review_return_operator_metric_rows.csv", "source_v53u/review_return_operator_metric_rows.csv"),
    (v53u_dir / "sha256_manifest.csv", "source_v53u/sha256_manifest.csv"),
]:
    copy(src, rel)

answer_rows = read_csv(v53r_dir / "review_answer_packet_rows.csv")
queue_rows = read_csv(v53r_dir / "review_queue_rows.csv")
validation_rows = read_csv(v53s_dir / "review_return_validation_rows.csv")
artifact_gate_rows = read_csv(v53s_dir / "review_return_artifact_gate_rows.csv")

if len(answer_rows) != 7000 or len(queue_rows) != 7000:
    raise SystemExit("v53v expects 7000 review answer and queue rows")
if len(artifact_gate_rows) != 5:
    raise SystemExit("v53v expects five v53s return artifact gate rows")

human_review_pass_answer_ids = {
    row["row_key"]
    for row in validation_rows
    if row.get("return_artifact") == "human_review_rows.csv" and row.get("status") == "pass"
}
adjudication_pass_answer_ids = {
    row["row_key"]
    for row in validation_rows
    if row.get("return_artifact") == "adjudication_rows.csv" and row.get("status") == "pass"
}
queue_by_answer_id = {row["answer_id"]: row for row in queue_rows}

reviewer_identity_ready = as_int(v53s, "reviewer_identity_ready")
conflict_disclosure_ready = as_int(v53s, "conflict_disclosure_ready")
acceptance_summary_ready = as_int(v53s, "acceptance_summary_ready")
review_return_ready = as_int(v53s, "review_return_ready")
quality_comparison_claim_ready = as_int(v53s, "quality_comparison_claim_ready")

acceptance_rows = []
human_review_accepted_rows = 0
adjudication_required_rows = 0
adjudication_accepted_rows = 0
adjudication_requirement_satisfied_rows = 0
answer_review_accepted_rows = 0
human_review_blocked_rows = 0
adjudication_blocked_rows = 0
identity_blocked_rows = 0
conflict_blocked_rows = 0
acceptance_summary_blocked_rows = 0

for index, answer in enumerate(answer_rows):
    queue = queue_by_answer_id[answer["answer_id"]]
    adjudication_required = int(answer["priority_class"] == "p0_answer_or_policy_mismatch")
    human_review_accepted = int(answer["answer_id"] in human_review_pass_answer_ids)
    adjudication_accepted = int(answer["answer_id"] in adjudication_pass_answer_ids)
    adjudication_satisfied = int((not adjudication_required) or adjudication_accepted)
    final_accepted = int(
        human_review_accepted
        and adjudication_satisfied
        and reviewer_identity_ready
        and conflict_disclosure_ready
        and acceptance_summary_ready
        and review_return_ready
    )

    human_review_accepted_rows += human_review_accepted
    adjudication_required_rows += adjudication_required
    adjudication_accepted_rows += adjudication_accepted
    adjudication_requirement_satisfied_rows += adjudication_satisfied
    answer_review_accepted_rows += final_accepted
    human_review_blocked_rows += int(not human_review_accepted)
    adjudication_blocked_rows += int(adjudication_required and not adjudication_accepted)
    identity_blocked_rows += int(not reviewer_identity_ready)
    conflict_blocked_rows += int(not conflict_disclosure_ready)
    acceptance_summary_blocked_rows += int(not acceptance_summary_ready)

    blocking_reasons = []
    if not human_review_accepted:
        blocking_reasons.append("human-review-row-missing")
    if adjudication_required and not adjudication_accepted:
        blocking_reasons.append("adjudication-row-missing")
    if not reviewer_identity_ready:
        blocking_reasons.append("reviewer-identity-missing")
    if not conflict_disclosure_ready:
        blocking_reasons.append("conflict-disclosure-missing")
    if not acceptance_summary_ready:
        blocking_reasons.append("acceptance-summary-missing")
    if not review_return_ready:
        blocking_reasons.append("review-return-not-ready")

    acceptance_rows.append(
        {
            "review_return_acceptance_id": f"v53v-review-return-acceptance-{index:04d}",
            "review_answer_packet_id": answer["review_answer_packet_id"],
            "review_queue_id": queue["review_queue_id"],
            "answer_id": answer["answer_id"],
            "system_id": answer["system_id"],
            "query_id": answer["query_id"],
            "owner_repo": answer["owner_repo"],
            "audit_type": answer["audit_type"],
            "source_span_id": answer["source_span_id"],
            "priority_class": answer["priority_class"],
            "required_reviewer_count": queue["required_reviewer_count"],
            "human_review_accepted": str(human_review_accepted),
            "adjudication_required": str(adjudication_required),
            "adjudication_accepted": str(adjudication_accepted),
            "adjudication_requirement_satisfied": str(adjudication_satisfied),
            "reviewer_identity_ready": str(reviewer_identity_ready),
            "conflict_disclosure_ready": str(conflict_disclosure_ready),
            "acceptance_summary_ready": str(acceptance_summary_ready),
            "review_return_ready": str(review_return_ready),
            "answer_review_accepted": str(final_accepted),
            "quality_comparison_claim_ready": str(quality_comparison_claim_ready),
            "blocking_reason": ";".join(blocking_reasons) if blocking_reasons else "accepted",
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "complete_source_review_return_acceptance_rows.csv", list(acceptance_rows[0].keys()), acceptance_rows)

requirement_rows = [
    {"requirement_id": "v53r-review-packet-input", "status": "pass", "required_value": "1", "actual_value": v53r["review_packet_ready"], "reason": "v53r review packet is bound"},
    {"requirement_id": "v53s-review-return-intake-input", "status": "pass", "required_value": "1", "actual_value": v53s["v53s_complete_source_review_return_intake_ready"], "reason": "v53s return intake is bound"},
    {"requirement_id": "v53t-readiness-gate-input", "status": "pass", "required_value": "1", "actual_value": v53t["v53t_complete_source_audit_readiness_gate_ready"], "reason": "v53t audit readiness gate is bound"},
    {"requirement_id": "v53u-operator-bundle-input", "status": "pass", "required_value": "1", "actual_value": v53u["v53u_complete_source_review_return_operator_bundle_ready"], "reason": "v53u operator bundle is bound"},
    {"requirement_id": "human-review-acceptance", "status": status(human_review_accepted_rows == len(answer_rows)), "required_value": str(len(answer_rows)), "actual_value": str(human_review_accepted_rows), "reason": "all answer packets need accepted human/source review rows"},
    {"requirement_id": "adjudication-acceptance", "status": status(adjudication_accepted_rows == adjudication_required_rows), "required_value": str(adjudication_required_rows), "actual_value": str(adjudication_accepted_rows), "reason": "all p0 rows need accepted adjudication rows"},
    {"requirement_id": "reviewer-identity-conflict-acceptance", "status": status(reviewer_identity_ready and conflict_disclosure_ready), "required_value": "1/1", "actual_value": f"{reviewer_identity_ready}/{conflict_disclosure_ready}", "reason": "reviewer identity and conflict disclosures must be accepted"},
    {"requirement_id": "acceptance-summary", "status": status(acceptance_summary_ready), "required_value": "1", "actual_value": str(acceptance_summary_ready), "reason": "hash-bound acceptance summary must be accepted"},
    {"requirement_id": "complete-source-review-return-accepted", "status": status(answer_review_accepted_rows == len(answer_rows)), "required_value": str(len(answer_rows)), "actual_value": str(answer_review_accepted_rows), "reason": "per-answer acceptance requires all review-return families"},
    {"requirement_id": "quality-comparison-claim", "status": status(quality_comparison_claim_ready), "required_value": "1", "actual_value": str(quality_comparison_claim_ready), "reason": "quality comparison claim waits for accepted review return"},
]
write_csv(run_dir / "complete_source_review_return_acceptance_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v53v_complete_source_review_return_acceptance_bridge_metrics",
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v53s_complete_source_review_return_intake_ready": v53s["v53s_complete_source_review_return_intake_ready"],
    "v53t_complete_source_audit_readiness_gate_ready": v53t["v53t_complete_source_audit_readiness_gate_ready"],
    "v53u_complete_source_review_return_operator_bundle_ready": v53u["v53u_complete_source_review_return_operator_bundle_ready"],
    "machine_complete_source_surface_ready": v53t["machine_complete_source_surface_ready"],
    "review_return_acceptance_rows": str(len(acceptance_rows)),
    "answer_review_accepted_rows": str(answer_review_accepted_rows),
    "human_review_accepted_rows": str(human_review_accepted_rows),
    "expected_human_review_rows": v53s["expected_human_review_rows"],
    "adjudication_required_rows": str(adjudication_required_rows),
    "adjudication_accepted_rows": str(adjudication_accepted_rows),
    "expected_adjudication_rows": v53s["expected_adjudication_rows"],
    "adjudication_requirement_satisfied_rows": str(adjudication_requirement_satisfied_rows),
    "reviewer_identity_ready": str(reviewer_identity_ready),
    "accepted_reviewer_identity_rows": v53s["accepted_reviewer_identity_rows"],
    "expected_reviewer_identity_rows": v53s["expected_reviewer_identity_rows"],
    "conflict_disclosure_ready": str(conflict_disclosure_ready),
    "accepted_conflict_disclosure_rows": v53s["accepted_conflict_disclosure_rows"],
    "expected_conflict_disclosure_rows": v53s["expected_conflict_disclosure_rows"],
    "acceptance_summary_ready": str(acceptance_summary_ready),
    "review_return_ready": str(review_return_ready),
    "human_review_blocked_acceptance_rows": str(human_review_blocked_rows),
    "adjudication_blocked_acceptance_rows": str(adjudication_blocked_rows),
    "identity_blocked_acceptance_rows": str(identity_blocked_rows),
    "conflict_blocked_acceptance_rows": str(conflict_blocked_rows),
    "acceptance_summary_blocked_acceptance_rows": str(acceptance_summary_blocked_rows),
    "quality_comparison_claim_ready": str(quality_comparison_claim_ready),
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_review_return_acceptance_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53v_complete_source_review_return_acceptance_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "machine-complete-source-surface", "status": "ready" if v53t["machine_complete_source_surface_ready"] == "1" else "blocked", "reason": f"machine_complete_source_surface_ready={v53t['machine_complete_source_surface_ready']}"},
    {"gap": "human-review-acceptance", "status": "ready" if human_review_accepted_rows == len(answer_rows) else "blocked", "reason": f"human_review_accepted_rows={human_review_accepted_rows}/{len(answer_rows)}"},
    {"gap": "adjudication-acceptance", "status": "ready" if adjudication_accepted_rows == adjudication_required_rows else "blocked", "reason": f"adjudication_accepted_rows={adjudication_accepted_rows}/{adjudication_required_rows}"},
    {"gap": "reviewer-identity-conflict", "status": "ready" if reviewer_identity_ready and conflict_disclosure_ready else "blocked", "reason": f"identity={reviewer_identity_ready}; conflict={conflict_disclosure_ready}"},
    {"gap": "acceptance-summary", "status": "ready" if acceptance_summary_ready else "blocked", "reason": f"acceptance_summary_ready={acceptance_summary_ready}"},
    {"gap": "complete-source-review-return-accepted", "status": "ready" if answer_review_accepted_rows == len(answer_rows) else "blocked", "reason": f"answer_review_accepted_rows={answer_review_accepted_rows}/{len(answer_rows)}"},
    {"gap": "quality-comparison-claim", "status": "ready" if quality_comparison_claim_ready else "blocked", "reason": f"quality_comparison_claim_ready={quality_comparison_claim_ready}"},
    {"gap": "v53-ready", "status": "blocked", "reason": "review return acceptance is incomplete"},
    {"gap": "v1.0-comparison-ready", "status": "blocked", "reason": "human-reviewed complete-source audit is incomplete"},
    {"gap": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v53r-review-packet-input", "status": "pass", "reason": "v53r is ready"},
    {"gate": "v53s-review-return-intake-input", "status": "pass", "reason": "v53s is ready"},
    {"gate": "v53t-readiness-gate-input", "status": "pass", "reason": "v53t is ready"},
    {"gate": "v53u-operator-bundle-input", "status": "pass", "reason": "v53u is ready"},
    {"gate": "machine-complete-source-surface", "status": "pass" if v53t["machine_complete_source_surface_ready"] == "1" else "blocked", "reason": f"machine_complete_source_surface_ready={v53t['machine_complete_source_surface_ready']}"},
    {"gate": "human-review-acceptance", "status": "pass" if human_review_accepted_rows == len(answer_rows) else "blocked", "reason": f"human_review_accepted_rows={human_review_accepted_rows}/{len(answer_rows)}"},
    {"gate": "adjudication-acceptance", "status": "pass" if adjudication_accepted_rows == adjudication_required_rows else "blocked", "reason": f"adjudication_accepted_rows={adjudication_accepted_rows}/{adjudication_required_rows}"},
    {"gate": "reviewer-identity-conflict", "status": "pass" if reviewer_identity_ready and conflict_disclosure_ready else "blocked", "reason": f"identity={reviewer_identity_ready}; conflict={conflict_disclosure_ready}"},
    {"gate": "acceptance-summary", "status": "pass" if acceptance_summary_ready else "blocked", "reason": f"acceptance_summary_ready={acceptance_summary_ready}"},
    {"gate": "complete-source-review-return-accepted", "status": "pass" if answer_review_accepted_rows == len(answer_rows) else "blocked", "reason": f"answer_review_accepted_rows={answer_review_accepted_rows}/{len(answer_rows)}"},
    {"gate": "quality-comparison-claim", "status": "pass" if quality_comparison_claim_ready else "blocked", "reason": f"quality_comparison_claim_ready={quality_comparison_claim_ready}"},
    {"gate": "v53-ready", "status": "blocked", "reason": "review return acceptance is incomplete"},
    {"gate": "v1.0-comparison-ready", "status": "blocked", "reason": "human-reviewed complete-source audit is incomplete"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53v Complete Source Review Return Acceptance Bridge Boundary

This artifact joins the frozen v53r review packet, v53s review-return intake,
v53t audit readiness gate, and v53u operator bundle into a 7000-row per-answer
review-return acceptance ledger. It does not create human review judgments.

Evidence emitted:

- review_return_acceptance_rows={len(acceptance_rows)}
- machine_complete_source_surface_ready={v53t['machine_complete_source_surface_ready']}
- answer_review_accepted_rows={answer_review_accepted_rows}
- human_review_accepted_rows={human_review_accepted_rows}
- expected_human_review_rows={v53s['expected_human_review_rows']}
- adjudication_required_rows={adjudication_required_rows}
- adjudication_accepted_rows={adjudication_accepted_rows}
- expected_adjudication_rows={v53s['expected_adjudication_rows']}
- reviewer_identity_ready={reviewer_identity_ready}
- conflict_disclosure_ready={conflict_disclosure_ready}
- acceptance_summary_ready={acceptance_summary_ready}
- review_return_ready={review_return_ready}
- human_review_blocked_acceptance_rows={human_review_blocked_rows}
- adjudication_blocked_acceptance_rows={adjudication_blocked_rows}
- identity_blocked_acceptance_rows={identity_blocked_rows}
- conflict_blocked_acceptance_rows={conflict_blocked_rows}
- acceptance_summary_blocked_acceptance_rows={acceptance_summary_blocked_rows}
- quality_comparison_claim_ready={quality_comparison_claim_ready}
- v53_ready=0
- v1_0_comparison_ready=0

Allowed wording: machine-prepared complete-source review-return acceptance
ledger. Blocked wording: accepted human-reviewed complete-source audit, v53
readiness, v1.0 comparison readiness, quality comparison claim, or release
readiness.
"""
(run_dir / "V53V_COMPLETE_SOURCE_REVIEW_RETURN_ACCEPTANCE_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53v-complete-source-review-return-acceptance-bridge",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53v_complete_source_review_return_acceptance_bridge_ready": 1,
    "review_return_acceptance_rows": len(acceptance_rows),
    "answer_review_accepted_rows": answer_review_accepted_rows,
    "human_review_accepted_rows": human_review_accepted_rows,
    "adjudication_required_rows": adjudication_required_rows,
    "adjudication_accepted_rows": adjudication_accepted_rows,
    "review_return_ready": review_return_ready,
    "quality_comparison_claim_ready": quality_comparison_claim_ready,
    "v53_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "source_v53r_summary_sha256": sha256(v53r_summary_path),
    "source_v53s_summary_sha256": sha256(v53s_summary_path),
    "source_v53t_summary_sha256": sha256(v53t_summary_path),
    "source_v53u_summary_sha256": sha256(v53u_summary_path),
}
(run_dir / "v53v_complete_source_review_return_acceptance_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53v_complete_source_review_return_acceptance_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
