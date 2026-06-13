#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53v_complete_source_review_return_acceptance_bridge/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/v53v_complete_source_review_return_acceptance_bridge_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53v_complete_source_review_return_acceptance_bridge_decision.csv"

V53V_REUSE_EXISTING="${V53V_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53v_complete_source_review_return_acceptance_bridge_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v53s_complete_source_review_return_intake_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v53u_complete_source_review_return_operator_bundle_ready": "1",
    "machine_complete_source_surface_ready": "1",
    "review_return_acceptance_rows": "7000",
    "answer_review_accepted_rows": "0",
    "human_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "adjudication_required_rows": "1000",
    "adjudication_accepted_rows": "0",
    "expected_adjudication_rows": "1000",
    "adjudication_requirement_satisfied_rows": "6000",
    "reviewer_identity_ready": "0",
    "accepted_reviewer_identity_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "conflict_disclosure_ready": "0",
    "accepted_conflict_disclosure_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "acceptance_summary_ready": "0",
    "review_return_ready": "0",
    "human_review_blocked_acceptance_rows": "7000",
    "adjudication_blocked_acceptance_rows": "1000",
    "identity_blocked_acceptance_rows": "7000",
    "conflict_blocked_acceptance_rows": "7000",
    "acceptance_summary_blocked_acceptance_rows": "7000",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v53v summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "complete_source_review_return_acceptance_rows.csv",
    "complete_source_review_return_acceptance_requirement_rows.csv",
    "complete_source_review_return_acceptance_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53V_COMPLETE_SOURCE_REVIEW_RETURN_ACCEPTANCE_BRIDGE_BOUNDARY.md",
    "v53v_complete_source_review_return_acceptance_bridge_manifest.json",
    "source_v53r/review_answer_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "source_v53s/review_return_artifact_gate_rows.csv",
    "source_v53s/review_return_validation_rows.csv",
    "source_v53t/complete_source_audit_readiness_requirement_rows.csv",
    "source_v53u/reviewer_workload_chunk_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53v artifact: {rel}")

acceptance_rows = read_csv(run_dir / "complete_source_review_return_acceptance_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_review_return_acceptance_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_review_return_acceptance_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(acceptance_rows) != 7000:
    raise SystemExit("v53v acceptance row count mismatch")
if any(row["human_review_accepted"] != "0" for row in acceptance_rows):
    raise SystemExit("v53v default rows must accept no human review")
if any(row["answer_review_accepted"] != "0" for row in acceptance_rows):
    raise SystemExit("v53v default rows must keep answer review acceptance blocked")
if sum(row["adjudication_required"] == "1" for row in acceptance_rows) != 1000:
    raise SystemExit("v53v should require adjudication for 1000 p0 rows")
if sum(row["adjudication_requirement_satisfied"] == "1" for row in acceptance_rows) != 6000:
    raise SystemExit("v53v non-p0 adjudication satisfaction count mismatch")
if any("human-review-row-missing" not in row["blocking_reason"] for row in acceptance_rows):
    raise SystemExit("v53v default blocking reason should include missing human review")
if any(row["priority_class"] == "p0_answer_or_policy_mismatch" and "adjudication-row-missing" not in row["blocking_reason"] for row in acceptance_rows):
    raise SystemExit("v53v p0 blocking reason should include missing adjudication")

for requirement_id in [
    "v53r-review-packet-input",
    "v53s-review-return-intake-input",
    "v53t-readiness-gate-input",
    "v53u-operator-bundle-input",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53v requirement should pass: {requirement_id}")
for requirement_id in [
    "human-review-acceptance",
    "adjudication-acceptance",
    "reviewer-identity-conflict-acceptance",
    "acceptance-summary",
    "complete-source-review-return-accepted",
    "quality-comparison-claim",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53v requirement should stay blocked: {requirement_id}")

for key, value in expected.items():
    if key.startswith("v53v_"):
        continue
    if key in metric and metric[key] != value:
        raise SystemExit(f"v53v metric mismatch for {key}: {metric[key]!r} != {value!r}")

for gate in [
    "v53r-review-packet-input",
    "v53s-review-return-intake-input",
    "v53t-readiness-gate-input",
    "v53u-operator-bundle-input",
    "machine-complete-source-surface",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53v gate should pass: {gate}")
for gate in [
    "human-review-acceptance",
    "adjudication-acceptance",
    "reviewer-identity-conflict",
    "acceptance-summary",
    "complete-source-review-return-accepted",
    "quality-comparison-claim",
    "v53-ready",
    "v1.0-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53v gate should stay blocked: {gate}")

if gaps.get("machine-complete-source-surface") != "ready":
    raise SystemExit("v53v machine surface gap should be ready")
for gap in [
    "human-review-acceptance",
    "adjudication-acceptance",
    "reviewer-identity-conflict",
    "acceptance-summary",
    "complete-source-review-return-accepted",
    "quality-comparison-claim",
    "v53-ready",
    "v1.0-comparison-ready",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53v gap should stay blocked: {gap}")

boundary = (run_dir / "V53V_COMPLETE_SOURCE_REVIEW_RETURN_ACCEPTANCE_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_return_acceptance_rows=7000",
    "answer_review_accepted_rows=0",
    "human_review_accepted_rows=0",
    "adjudication_required_rows=1000",
    "adjudication_accepted_rows=0",
    "review_return_ready=0",
    "quality_comparison_claim_ready=0",
    "v53_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53v boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53v_complete_source_review_return_acceptance_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53v_complete_source_review_return_acceptance_bridge_ready") != 1:
    raise SystemExit("v53v manifest readiness mismatch")
if manifest.get("review_return_acceptance_rows") != 7000:
    raise SystemExit("v53v manifest row count mismatch")
if manifest.get("answer_review_accepted_rows") != 0:
    raise SystemExit("v53v manifest should keep accepted answer review rows at zero")
if manifest.get("v1_0_comparison_ready") != 0:
    raise SystemExit("v53v manifest must keep v1.0 comparison blocked")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53v produced checkpoint/model payload-like files" >&2
  exit 1
fi

echo "v53v complete-source review return acceptance bridge smoke passed"
