#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dk_return_contract_final_bundle_crosswalk_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/crosswalk_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DK_REUSE_EXISTING="${V61DK_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dk_return_contract_final_bundle_crosswalk_gate.sh" >/dev/null

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
    "v61dk_return_contract_final_bundle_crosswalk_gate_ready": "1",
    "v61dj_post_claim_return_evidence_contract_gate_ready": "1",
    "v53ak_complete_source_external_return_operator_checklist_ready": "1",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "source_gate_rows": "3",
    "crosswalk_surface_ready": "1",
    "contract_artifact_rows": "10",
    "crosswalk_rows": "10",
    "mapped_crosswalk_rows": "10",
    "unmapped_crosswalk_rows": "0",
    "family_crosswalk_rows": "2",
    "contract_preflight_pass_rows": "0",
    "contract_preflight_missing_rows": "10",
    "contract_preflight_ready": "0",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "0",
    "full_preflight_missing_rows": "81",
    "return_bundle_preflight_pass": "0",
    "operator_checklist_rows": "81",
    "aggregate_review_crosswalk_rows": "5",
    "generation_result_crosswalk_rows": "5",
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
    "checkpoint_payload_bytes_downloaded_by_v61dk": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dk {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_contract_final_bundle_crosswalk_rows.csv",
    "return_contract_final_bundle_family_crosswalk_rows.csv",
    "return_contract_final_bundle_preflight_scope_rows.csv",
    "return_contract_final_bundle_crosswalk_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DK_RETURN_CONTRACT_FINAL_BUNDLE_CROSSWALK_GATE_BOUNDARY.md",
    "v61dk_return_contract_final_bundle_crosswalk_gate_manifest.json",
    "source_v61dj/return_evidence_contract_artifact_rows.csv",
    "source_v53ak/external_return_operator_checklist_rows.csv",
    "source_v53al/external_return_bundle_preflight_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dk artifact: {rel}")

crosswalk = read_csv(run_dir / "return_contract_final_bundle_crosswalk_rows.csv")
families = {row["contract_family"]: row for row in read_csv(run_dir / "return_contract_final_bundle_family_crosswalk_rows.csv")}
scopes = {row["scope_id"]: row for row in read_csv(run_dir / "return_contract_final_bundle_preflight_scope_rows.csv")}
metric = read_csv(run_dir / "return_contract_final_bundle_crosswalk_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(crosswalk) != 10 or any(row["mapping_status"] != "mapped" for row in crosswalk):
    raise SystemExit("v61dk crosswalk mapping mismatch")
if any(row["preflight_pass"] != "0" for row in crosswalk):
    raise SystemExit("v61dk contract preflight should remain unpassed")
if {row["final_return_bundle_relative_path"] for row in crosswalk} != {
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
    raise SystemExit("v61dk final bundle path set mismatch")
if families["aggregate-review-return"]["mapped_crosswalk_rows"] != "5":
    raise SystemExit("v61dk aggregate family mapping mismatch")
if families["generation-result-return"]["mapped_crosswalk_rows"] != "5":
    raise SystemExit("v61dk generation family mapping mismatch")
if scopes["full-final-return-bundle"]["scope_rows"] != "81":
    raise SystemExit("v61dk full scope row count mismatch")
if scopes["contract-critical-artifacts"]["scope_rows"] != "10":
    raise SystemExit("v61dk contract scope row count mismatch")

for field, value in expected.items():
    if field.startswith("v61dk_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61dk metric {field}: expected {value}, got {metric[field]}")

for gate in ["crosswalk-surface-ready", "contract-artifact-mapping", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dk gate should pass: {gate}")
for gate in ["full-return-bundle-preflight", "contract-critical-preflight", "actual-model-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dk gate should stay blocked: {gate}")
if gaps.get("crosswalk-surface") != "ready":
    raise SystemExit("v61dk crosswalk surface gap should be ready")
for gap in ["full-final-return-bundle", "contract-critical-artifacts", "actual-model-generation"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61dk gap should stay blocked: {gap}")

boundary = (run_dir / "V61DK_RETURN_CONTRACT_FINAL_BUNDLE_CROSSWALK_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "contract_artifact_rows=10",
    "crosswalk_rows=10",
    "mapped_crosswalk_rows=10",
    "unmapped_crosswalk_rows=0",
    "contract_preflight_pass_rows=0",
    "contract_preflight_missing_rows=10",
    "full_preflight_rows=81",
    "return_bundle_preflight_pass=0",
    "operator_checklist_rows=81",
    "aggregate_review_crosswalk_rows=5",
    "generation_result_crosswalk_rows=5",
    "review_return_expected_rows=8232",
    "generation_result_expected_rows=4001",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61dk=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dk boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dk_return_contract_final_bundle_crosswalk_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dk_return_contract_final_bundle_crosswalk_gate_ready") != 1:
    raise SystemExit("v61dk manifest readiness mismatch")
if manifest.get("mapped_crosswalk_rows") != 10 or manifest.get("unmapped_crosswalk_rows") != 0:
    raise SystemExit("v61dk manifest mapping mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dk manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dk manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dk sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dk produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dk return contract final bundle crosswalk gate smoke passed"
