#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dc_complete_source_runtime_admission_local_return_materializer"
RUN_DIR="$RESULTS_DIR/$PREFIX/materialize_001"
RETURN_DIR="$RUN_DIR/runtime_admission_return_results"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DC_REUSE_EXISTING="${V61DC_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dc_complete_source_runtime_admission_local_return_materializer.sh" >/dev/null

V61CR_RUNTIME_ADMISSION_RETURN_DIR="$RETURN_DIR" V61CR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null
V61CV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cv_complete_source_runtime_admission_operator_bundle.sh" >/dev/null
V61CW_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
V61CS_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
results_dir = Path(sys.argv[4])


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
    "v61dc_complete_source_runtime_admission_local_return_materializer_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_return_artifacts_materialized": "5",
    "runtime_admission_result_rows_materialized": "1000",
    "runtime_page_binding_rows_materialized": "1000",
    "runtime_budget_rows_materialized": "1000",
    "runtime_identity_rows_materialized": "59",
    "runtime_abstain_fallback_rows_materialized": "1000",
    "total_verified_page_hash_rows": "134161",
    "total_identity_verified_checkpoint_shard_rows": "59",
    "promotion_identity_verified_bytes": "281241493344",
    "runtime_admission_local_return_materialized": "1",
    "v61cr_refresh_ready": "1",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61dc summary mismatch for {key}: {summary.get(key)!r} != {value!r}")

required_files = [
    "runtime_admission_return_results/complete_source_runtime_admission_result_rows.csv",
    "runtime_admission_return_results/complete_source_runtime_page_binding_rows.csv",
    "runtime_admission_return_results/complete_source_runtime_budget_rows.csv",
    "runtime_admission_return_results/complete_source_runtime_identity_rows.csv",
    "runtime_admission_return_results/complete_source_runtime_abstain_fallback_rows.csv",
    "runtime_admission_local_return_artifact_rows.csv",
    "runtime_admission_local_return_requirement_rows.csv",
    "runtime_admission_local_return_metric_rows.csv",
    "V61DC_COMPLETE_SOURCE_RUNTIME_ADMISSION_LOCAL_RETURN_MATERIALIZER_BOUNDARY.md",
    "v61dc_complete_source_runtime_admission_local_return_materializer_manifest.json",
    "source_v61cq/complete_source_runtime_admission_expansion_rows.csv",
    "source_v61cm/full_checkpoint_materialization_promotion_rows.csv",
    "source_v61cb/full_page_hash_coverage_promotion_rows.csv",
    "source_v61t/local_checkpoint_materialization_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dc artifact: {rel}")

artifact_rows = read_csv(run_dir / "runtime_admission_local_return_artifact_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "runtime_admission_local_return_requirement_rows.csv")}
metric = read_csv(run_dir / "runtime_admission_local_return_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
manifest = json.loads((run_dir / "v61dc_complete_source_runtime_admission_local_return_materializer_manifest.json").read_text(encoding="utf-8"))

if len(artifact_rows) != 5:
    raise SystemExit("v61dc expected five return artifact rows")
if any(row["materialized"] != "1" for row in artifact_rows):
    raise SystemExit("v61dc all return artifacts should be materialized")
for requirement_id in [
    "v61cq-expansion-input",
    "full-checkpoint-materialization",
    "full-page-hash-binding",
    "runtime-admission-result-return",
    "runtime-page-binding-return",
    "runtime-budget-return",
    "runtime-identity-return",
    "runtime-safety-return",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61dc requirement should pass: {requirement_id}")
if requirements["actual-model-generation"]["status"] != "blocked":
    raise SystemExit("v61dc must keep actual generation blocked")
for key, value in expected.items():
    if key.startswith("v61dc_") or key == "runtime_admission_return_dir":
        continue
    if key in metric and metric[key] != value:
        raise SystemExit(f"v61dc metric mismatch for {key}: {metric[key]!r} != {value!r}")
for gate in [
    "v61cq-expansion-input",
    "full-checkpoint-materialization",
    "full-page-hash-binding",
    "runtime-admission-local-return-materialized",
    "v61cr-refresh-ready",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dc gate should pass: {gate}")
for gate in ["actual-model-generation", "production-latency", "near-frontier-quality", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dc gate should stay blocked: {gate}")
if manifest.get("runtime_admission_result_rows_materialized") != 1000:
    raise SystemExit("v61dc manifest runtime row mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dc manifest must not claim generation")

v61cr = read_csv(results_dir / "v61cr_complete_source_runtime_admission_return_intake_summary.csv")[0]
v61cw = read_csv(results_dir / "v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv")[0]
v61cs = read_csv(results_dir / "v61cs_complete_source_generation_execution_admission_gate_summary.csv")[0]

cr_expected = {
    "supplied_runtime_admission_return_artifacts": "5",
    "accepted_runtime_admission_return_artifacts": "5",
    "accepted_runtime_admission_result_rows": "1000",
    "accepted_runtime_page_binding_rows": "1000",
    "accepted_runtime_budget_rows": "1000",
    "accepted_runtime_identity_rows": "59",
    "accepted_runtime_abstain_fallback_rows": "1000",
    "runtime_admission_return_artifact_ready": "1",
    "runtime_admission_result_rows_ready": "1",
    "runtime_page_binding_ready": "1",
    "runtime_budget_ready": "1",
    "runtime_identity_ready": "1",
    "runtime_safety_ready": "1",
    "complete_source_runtime_admission_execution_ready": "1",
    "actual_model_generation_ready": "0",
}
for key, value in cr_expected.items():
    if v61cr.get(key) != value:
        raise SystemExit(f"v61cr accepted summary mismatch for {key}: {v61cr.get(key)!r} != {value!r}")

cw_expected = {
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "runtime_artifact_blocked_acceptance_rows": "0",
    "runtime_result_blocked_acceptance_rows": "0",
    "runtime_page_binding_blocked_acceptance_rows": "0",
    "runtime_budget_blocked_acceptance_rows": "0",
    "runtime_identity_blocked_acceptance_rows": "0",
    "runtime_safety_blocked_acceptance_rows": "0",
    "complete_source_runtime_admission_execution_ready": "1",
    "actual_model_generation_ready": "0",
}
for key, value in cw_expected.items():
    if v61cw.get(key) != value:
        raise SystemExit(f"v61cw accepted summary mismatch for {key}: {v61cw.get(key)!r} != {value!r}")

cs_expected = {
    "complete_source_runtime_admission_execution_ready": "1",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "runtime_admission_blocked_generation_rows": "0",
    "review_return_blocked_generation_rows": "1000",
    "generation_result_artifact_blocked_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "actual_model_generation_ready": "0",
}
for key, value in cs_expected.items():
    if v61cs.get(key) != value:
        raise SystemExit(f"v61cs refreshed summary mismatch for {key}: {v61cs.get(key)!r} != {value!r}")

boundary = (run_dir / "V61DC_COMPLETE_SOURCE_RUNTIME_ADMISSION_LOCAL_RETURN_MATERIALIZER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "runtime_admission_return_artifacts_materialized=5",
    "runtime_admission_result_rows_materialized=1000",
    "runtime_identity_rows_materialized=59",
    "total_verified_page_hash_rows=134161",
    "v61cr_refresh_ready=1",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dc boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dc sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dc produced checkpoint/model payload-like files" >&2
  exit 1
fi

echo "v61dc complete-source runtime admission local return materializer smoke passed"
