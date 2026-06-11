#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate_decision.csv"

V53T_REUSE_EXISTING="${V53T_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "v52y_f_optional_final_policy_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "v53i_complete_source_query_instantiation_ready": "1",
    "v53q_complete_source_symmetric_scorer_policy_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v53s_complete_source_review_return_intake_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "complete_source_span_rows": "1000",
    "core_system_count": "7",
    "core_answer_rows": "7000",
    "symmetric_scorer_rows": "7000",
    "symmetric_policy_rows": "7000",
    "review_packet_ready": "1",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "machine_complete_source_surface_ready": "1",
    "review_return_ready": "0",
    "human_review_completed": "0",
    "adjudication_completed": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53t {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_audit_readiness_requirement_rows.csv",
    "complete_source_audit_claim_rows.csv",
    "complete_source_audit_readiness_metric_rows.csv",
    "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md",
    "v53t_complete_source_audit_readiness_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
    "source_v53q/v53q_complete_source_symmetric_scorer_policy_summary.csv",
    "source_v53r/v53r_complete_source_review_packet_summary.csv",
    "source_v53s/v53s_complete_source_review_return_intake_summary.csv",
    "source_v53s/review_return_metric_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53t artifact: {rel}")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_audit_readiness_requirement_rows.csv")}
for requirement_id in [
    "f-optional-final-disposition",
    "complete-source-content-and-query-surface",
    "core-a-b-c-d-e-g-h-answer-citation-resource",
    "symmetric-scorer-policy-surface",
    "review-packet-ready",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53t requirement should pass: {requirement_id}")
for requirement_id in [
    "human-review-return-accepted",
    "adjudication-return-accepted",
    "reviewer-identity-conflict-ready",
    "quality-comparison-claim-ready",
    "release-package-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53t requirement should stay blocked: {requirement_id}")
if len(requirements) != 10:
    raise SystemExit("v53t requirement row count mismatch")

claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "complete_source_audit_claim_rows.csv")}
if claims["complete-source-machine-surface"] != "allowed-limited":
    raise SystemExit("v53t should allow only limited machine-surface wording")
for claim_id in ["human-reviewed-complete-source-audit", "30b-150b-quality-comparison", "v53-ready", "release-ready"]:
    if claims[claim_id] != "blocked":
        raise SystemExit(f"v53t claim should be blocked: {claim_id}")

metric = read_csv(run_dir / "complete_source_audit_readiness_metric_rows.csv")[0]
for field, value in expected.items():
    if field.startswith("v53t_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53t metric {field}: expected {value}, got {metric[field]}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52y-f-final-policy-input",
    "v53i-complete-source-query-input",
    "v53q-core-scorer-policy-input",
    "v53r-review-packet-input",
    "machine-complete-source-surface",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53t gate should pass: {gate}")
for gate in [
    "v53s-review-return-input",
    "human-reviewed-audit",
    "quality-comparison-claim",
    "v53-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53t gate should stay blocked: {gate}")

boundary = (run_dir / "V53T_COMPLETE_SOURCE_AUDIT_READINESS_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "f_optional_final_disposition=deferred-with-reason-final",
    "complete_source_repo_count=10",
    "complete_source_query_rows=1000",
    "core_answer_rows=7000",
    "expected_human_review_rows=7000",
    "accepted_human_review_rows=0",
    "machine_complete_source_surface_ready=1",
    "review_return_ready=0",
    "quality_comparison_claim_ready=0",
    "v53_ready=0",
    "v1_0_comparison_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53t boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53t_complete_source_audit_readiness_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53t_complete_source_audit_readiness_gate_ready") != 1:
    raise SystemExit("v53t manifest readiness mismatch")
if manifest.get("machine_complete_source_surface_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53t manifest boundary mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53t sha256 mismatch: {rel}")
PY

echo "v53t complete-source audit readiness gate smoke passed"
