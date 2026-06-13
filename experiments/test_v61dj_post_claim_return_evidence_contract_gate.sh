#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dj_post_claim_return_evidence_contract_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/contract_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DJ_REUSE_EXISTING="${V61DJ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dj_post_claim_return_evidence_contract_gate.sh" >/dev/null

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
    "v61dj_post_claim_return_evidence_contract_gate_ready": "1",
    "v61di_post_claim_generation_unblock_audit_gate_ready": "1",
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "source_gate_rows": "3",
    "contract_surface_ready": "1",
    "return_contract_blocker_rows": "6",
    "unsatisfied_return_contract_blocker_rows": "6",
    "return_artifact_contract_rows": "10",
    "satisfied_return_artifact_contract_rows": "0",
    "unsatisfied_return_artifact_contract_rows": "10",
    "return_artifact_family_rows": "2",
    "return_contract_command_rows": "5",
    "ready_return_contract_command_rows": "2",
    "preflight_surface_ready": "1",
    "return_bundle_preflight_pass": "0",
    "preflight_rows": "81",
    "preflight_pass_rows": "0",
    "preflight_missing_rows": "81",
    "review_return_required_artifacts": "5",
    "generation_result_required_artifacts": "5",
    "review_return_expected_rows": "8232",
    "review_return_accepted_rows": "0",
    "review_return_missing_rows": "8232",
    "generation_result_expected_rows": "4001",
    "generation_result_accepted_contract_rows": "0",
    "generation_result_missing_rows": "4001",
    "accepted_human_review_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "actual_model_generation_ready": "0",
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dj {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_evidence_contract_blocker_rows.csv",
    "return_evidence_contract_artifact_rows.csv",
    "return_evidence_contract_family_rows.csv",
    "return_evidence_contract_command_rows.csv",
    "return_evidence_contract_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DJ_POST_CLAIM_RETURN_EVIDENCE_CONTRACT_GATE_BOUNDARY.md",
    "v61dj_post_claim_return_evidence_contract_gate_manifest.json",
    "source_v61di/v61di_post_claim_generation_unblock_audit_gate_summary.csv",
    "source_v61di/post_claim_generation_unblock_stage_rows.csv",
    "source_v61df/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv",
    "source_v61df/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
    "source_v53al/external_return_bundle_preflight_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dj artifact: {rel}")

blockers = read_csv(run_dir / "return_evidence_contract_blocker_rows.csv")
artifacts = read_csv(run_dir / "return_evidence_contract_artifact_rows.csv")
families = {row["external_return_family"]: row for row in read_csv(run_dir / "return_evidence_contract_family_rows.csv")}
commands = read_csv(run_dir / "return_evidence_contract_command_rows.csv")
metric = read_csv(run_dir / "return_evidence_contract_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(blockers) != 6 or any(row["contract_status"] != "unsatisfied" for row in blockers):
    raise SystemExit("v61dj blocker contract mismatch")
if len(artifacts) != 10 or any(row["contract_status"] != "unsatisfied" for row in artifacts):
    raise SystemExit("v61dj artifact contract mismatch")
if {row["return_artifact"] for row in artifacts} != {
    "human_review_rows.csv",
    "adjudication_rows.csv",
    "reviewer_identity_rows.csv",
    "reviewer_conflict_rows.csv",
    "acceptance_summary.json",
    "real_model_generation_answer_rows.csv",
    "real_model_generation_citation_rows.csv",
    "real_model_generation_abstain_fallback_rows.csv",
    "real_model_generation_latency_rows.csv",
    "real_model_generation_acceptance_summary.json",
}:
    raise SystemExit("v61dj required artifact set mismatch")
if families["aggregate-review-return"]["expected_rows"] != "8232":
    raise SystemExit("v61dj aggregate review expected row count mismatch")
if families["generation-result-return"]["expected_rows"] != "4001":
    raise SystemExit("v61dj generation result expected row count mismatch")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0", "0"]:
    raise SystemExit("v61dj command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v61dj_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61dj metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "contract-surface-ready",
    "source-v61di-ready",
    "source-v61df-ready",
    "source-v53al-ready",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dj gate should pass: {gate}")
for gate in [
    "return-bundle-preflight-pass",
    "aggregate-review-return-contract",
    "generation-result-return-contract",
    "actual-model-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dj gate should stay blocked: {gate}")

if gaps.get("contract-surface") != "ready":
    raise SystemExit("v61dj contract surface gap should be ready")
for gap in [
    "return-bundle-preflight-pass",
    "aggregate-review-return",
    "generation-result-return",
    "actual-model-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61dj gap should stay blocked: {gap}")

boundary = (run_dir / "V61DJ_POST_CLAIM_RETURN_EVIDENCE_CONTRACT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_contract_blocker_rows=6",
    "unsatisfied_return_contract_blocker_rows=6",
    "return_artifact_contract_rows=10",
    "satisfied_return_artifact_contract_rows=0",
    "unsatisfied_return_artifact_contract_rows=10",
    "ready_return_contract_command_rows=2",
    "return_bundle_preflight_pass=0",
    "preflight_pass_rows=0/81",
    "review_return_expected_rows=8232",
    "generation_result_expected_rows=4001",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61dj=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dj boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dj_post_claim_return_evidence_contract_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dj_post_claim_return_evidence_contract_gate_ready") != 1:
    raise SystemExit("v61dj manifest readiness mismatch")
if manifest.get("unsatisfied_return_artifact_contract_rows") != 10:
    raise SystemExit("v61dj manifest unsatisfied artifact count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dj manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dj manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dj sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dj produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dj post-claim return evidence contract gate smoke passed"
