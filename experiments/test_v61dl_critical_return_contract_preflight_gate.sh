#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dl_critical_return_contract_preflight_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DL_REUSE_EXISTING="${V61DL_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dl_critical_return_contract_preflight_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
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
    "v61dl_critical_return_contract_preflight_gate_ready": "1",
    "v61dk_return_contract_final_bundle_crosswalk_gate_ready": "1",
    "source_gate_rows": "1",
    "critical_preflight_surface_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "critical_artifact_rows": "10",
    "critical_preflight_pass_rows": "0",
    "critical_preflight_missing_rows": "10",
    "critical_preflight_non_empty_rows": "0",
    "critical_preflight_ready": "0",
    "critical_family_rows": "2",
    "critical_command_rows": "3",
    "ready_critical_command_rows": "2",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "0",
    "return_bundle_preflight_pass": "0",
    "operator_checklist_rows": "81",
    "review_return_expected_rows": "8232",
    "generation_result_expected_rows": "4001",
    "accepted_human_review_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
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
    "checkpoint_payload_bytes_downloaded_by_v61dl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dl {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "critical_return_contract_preflight_rows.csv",
    "critical_return_contract_preflight_family_rows.csv",
    "critical_return_contract_preflight_command_rows.csv",
    "critical_return_contract_preflight_metric_rows.csv",
    "runtime_gap_rows.csv",
    "VERIFY_CRITICAL_RETURN_CONTRACT.sh",
    "V61DL_CRITICAL_RETURN_CONTRACT_PREFLIGHT_GATE_BOUNDARY.md",
    "v61dl_critical_return_contract_preflight_gate_manifest.json",
    "source_v61dk/return_contract_final_bundle_crosswalk_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dl artifact: {rel}")
if not os.access(run_dir / "VERIFY_CRITICAL_RETURN_CONTRACT.sh", os.X_OK):
    raise SystemExit("v61dl verifier must be executable")

rows = read_csv(run_dir / "critical_return_contract_preflight_rows.csv")
families = {row["contract_family"]: row for row in read_csv(run_dir / "critical_return_contract_preflight_family_rows.csv")}
commands = read_csv(run_dir / "critical_return_contract_preflight_command_rows.csv")
metric = read_csv(run_dir / "critical_return_contract_preflight_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(rows) != 10 or any(row["critical_preflight_pass"] != "0" for row in rows):
    raise SystemExit("v61dl critical row readiness mismatch")
if {row["final_return_bundle_relative_path"] for row in rows} != {
    "aggregate_review_return/human_review_rows.csv",
    "aggregate_review_return/adjudication_rows.csv",
    "aggregate_review_return/reviewer_identity_rows.csv",
    "aggregate_review_return/reviewer_conflict_rows.csv",
    "aggregate_review_return/acceptance_summary.json",
    "generation_result_return/real_model_generation_answer_rows.csv",
    "generation_result_return/real_model_generation_citation_rows.csv",
    "generation_result_return/real_model_generation_abstain_fallback_rows.csv",
    "generation_result_return/real_model_generation_latency_rows.csv",
    "generation_result_return/real_model_generation_acceptance_summary.json",
}:
    raise SystemExit("v61dl critical path set mismatch")
if families["aggregate-review-return"]["critical_artifact_rows"] != "5":
    raise SystemExit("v61dl aggregate family mismatch")
if families["generation-result-return"]["critical_artifact_rows"] != "5":
    raise SystemExit("v61dl generation family mismatch")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0"]:
    raise SystemExit("v61dl command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v61dl_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61dl metric {field}: expected {value}, got {metric[field]}")

if decisions.get("critical-preflight-surface-ready") != "pass":
    raise SystemExit("v61dl surface gate should pass")
for gate in ["critical-return-contract-preflight", "full-return-bundle-preflight", "actual-model-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dl gate should stay blocked: {gate}")
if decisions.get("manifest-only-no-repo-payload") != "pass":
    raise SystemExit("v61dl no-payload gate should pass")
if gaps.get("critical-preflight-surface") != "ready":
    raise SystemExit("v61dl critical surface gap should be ready")
for gap in ["critical-return-contract-preflight", "full-return-bundle-preflight", "actual-model-generation"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61dl gap should stay blocked: {gap}")

boundary = (run_dir / "V61DL_CRITICAL_RETURN_CONTRACT_PREFLIGHT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "critical_artifact_rows=10",
    "critical_preflight_pass_rows=0",
    "critical_preflight_missing_rows=10",
    "critical_preflight_ready=0",
    "return_bundle_dir_supplied=0",
    "return_bundle_dir_exists=0",
    "full_preflight_rows=81",
    "return_bundle_preflight_pass=0",
    "review_return_expected_rows=8232",
    "generation_result_expected_rows=4001",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61dl=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dl boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dl_critical_return_contract_preflight_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dl_critical_return_contract_preflight_gate_ready") != 1:
    raise SystemExit("v61dl manifest readiness mismatch")
if manifest.get("critical_artifact_rows") != 10 or manifest.get("critical_preflight_pass_rows") != 0:
    raise SystemExit("v61dl manifest critical count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dl manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dl manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dl sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dl produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dl critical return contract preflight gate smoke passed"
