#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ae_real_generation_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61ae_real_generation_admission_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ae_real_generation_admission_gate_decision.csv"

V61AE_REUSE_EXISTING="${V61AE_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ae_real_generation_admission_gate.sh" >/dev/null

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
source_v61r_summary = read_csv(run_dir / "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv")[0]
source_v61t_summary = read_csv(run_dir / "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
source_v61w_summary = read_csv(run_dir / "source_v61w/v61w_materialization_admission_resume_plan_summary.csv")[0]
local_checkpoint_ready = source_v61t_summary["local_checkpoint_materialization_ready"]
materialization_admission_ready = source_v61w_summary["materialization_admission_ready"]
page_hash_ready = source_v61r_summary["full_safetensors_page_hash_binding_ready"]
materialization_blocked = str(int(not (int(local_checkpoint_ready) and int(materialization_admission_ready))))
page_hash_blocked = str(int(not int(page_hash_ready)))
expected = {
    "v61ae_real_generation_admission_gate_ready": "1",
    "v61ad_kv_weight_token_budget_replay_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v61r_full_page_hash_sweep_plan_ready": "1",
    "v61t_local_checkpoint_materialization_verifier_ready": "1",
    "v61w_materialization_admission_resume_plan_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "review_packet_ready": "1",
    "review_artifacts_ready": "0",
    "warehouse_root_override_supplied": "0",
    "pending_review_queue_rows": "7000",
    "generation_candidate_rows": "1000",
    "generation_admitted_rows": "0",
    "runtime_budget_ready_rows": "1000",
    "source_review_blocked_rows": "1000",
    "materialization_blocked_rows": str(1000 * int(materialization_blocked)),
    "page_hash_blocked_rows": str(1000 * int(page_hash_blocked)),
    "local_identity_verified_shard_rows": source_v61t_summary["local_identity_verified_shard_rows"],
    "checkpoint_shard_rows": source_v61t_summary["checkpoint_shard_rows"],
    "full_page_hash_verified_rows": source_v61r_summary["verified_page_hash_rows"],
    "page_hash_sweep_plan_rows": source_v61r_summary["page_hash_sweep_plan_rows"],
    "materialization_admission_ready": materialization_admission_ready,
    "local_checkpoint_materialization_ready": local_checkpoint_ready,
    "full_safetensors_page_hash_binding_ready": page_hash_ready,
    "real_generation_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ae {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_candidate_rows.csv",
    "real_generation_admission_requirement_rows.csv",
    "real_generation_admission_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AE_REAL_GENERATION_ADMISSION_BOUNDARY.md",
    "v61ae_real_generation_admission_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61ad/kv_weight_token_budget_rows.csv",
    "source_v53r/review_query_packet_rows.csv",
    "source_v53r/review_queue_rows.csv",
    "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv",
    "source_v61r/page_hash_sweep_metric_rows.csv",
    "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv",
    "source_v61t/local_checkpoint_materialization_metric_rows.csv",
    "source_v61w/v61w_materialization_admission_resume_plan_summary.csv",
    "source_v61w/materialization_admission_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ae artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61ad-runtime-budget-input",
    "v53r-complete-source-review-packet-input",
    "generation-candidate-surface",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ae gate should pass: {gate}")
if local_checkpoint_ready == "1":
    if decisions.get("local-checkpoint-materialization") != "pass":
        raise SystemExit("v61ae local-checkpoint-materialization gate should pass")
else:
    if decisions.get("local-checkpoint-materialization") != "blocked":
        raise SystemExit("v61ae local-checkpoint-materialization gate should stay blocked")
if page_hash_ready == "1":
    if decisions.get("full-safetensors-page-hash-binding") != "pass":
        raise SystemExit("v61ae full-safetensors-page-hash-binding gate should pass")
else:
    if decisions.get("full-safetensors-page-hash-binding") != "blocked":
        raise SystemExit("v61ae full-safetensors-page-hash-binding gate should stay blocked")
for gate in [
    "human-source-review-artifacts",
    "materialization-admission",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ae gate should stay blocked: {gate}")

candidate_rows = read_csv(run_dir / "real_generation_candidate_rows.csv")
requirement_rows = read_csv(run_dir / "real_generation_admission_requirement_rows.csv")
metric = read_csv(run_dir / "real_generation_admission_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
requirements = {row["requirement"]: row["status"] for row in requirement_rows}

if len(candidate_rows) != 1000:
    raise SystemExit("v61ae generation candidate row count mismatch")
if len(requirement_rows) != 7:
    raise SystemExit("v61ae requirement row count mismatch")
if metric.get("metric_id") != "v61ae_real_generation_admission_metrics":
    raise SystemExit("v61ae metric id mismatch")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ae metric {field}: expected {value}, got {metric[field]}")

for row in candidate_rows:
    checks = {
        "runtime_budget_ready": "1",
        "source_review_artifacts_ready": "0",
        "local_checkpoint_materialization_ready": local_checkpoint_ready,
        "materialization_admission_ready": materialization_admission_ready,
        "full_safetensors_page_hash_binding_ready": page_hash_ready,
        "generation_admitted": "0",
        "source_review_blocked": "1",
        "materialization_blocked": materialization_blocked,
        "page_hash_blocked": page_hash_blocked,
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "actual_model_generation_ready": "0",
        "production_latency_claim_ready": "0",
    }
    for field, value in checks.items():
        if row[field] != value:
            raise SystemExit(f"v61ae candidate {field}: expected {value}, got {row[field]}")

for requirement in [
    "runtime-budget-shape",
    "complete-source-generation-candidate-surface",
]:
    if requirements.get(requirement) != "ready":
        raise SystemExit(f"v61ae requirement should be ready: {requirement}")
if local_checkpoint_ready == "1":
    if requirements.get("local-checkpoint-materialization") != "ready":
        raise SystemExit("v61ae local-checkpoint-materialization requirement should be ready")
else:
    if requirements.get("local-checkpoint-materialization") != "blocked":
        raise SystemExit("v61ae local-checkpoint-materialization requirement should stay blocked")
if page_hash_ready == "1":
    if requirements.get("full-safetensors-page-hash-binding") != "ready":
        raise SystemExit("v61ae full-safetensors-page-hash-binding requirement should be ready")
else:
    if requirements.get("full-safetensors-page-hash-binding") != "blocked":
        raise SystemExit("v61ae full-safetensors-page-hash-binding requirement should stay blocked")
for requirement in [
    "human-source-review-artifacts",
    "materialization-admission",
    "real-model-generation",
]:
    if requirements.get(requirement) != "blocked":
        raise SystemExit(f"v61ae requirement should stay blocked: {requirement}")

for gap in [
    "v61ad-runtime-budget-input",
    "v53r-complete-source-review-packet-input",
    "generation-candidate-surface",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ae gap should be ready: {gap}")
if local_checkpoint_ready == "1":
    if gaps.get("local-checkpoint-materialization") != "ready":
        raise SystemExit("v61ae local-checkpoint-materialization gap should be ready")
else:
    if gaps.get("local-checkpoint-materialization") != "blocked":
        raise SystemExit("v61ae local-checkpoint-materialization gap should stay blocked")
if page_hash_ready == "1":
    if gaps.get("full-safetensors-page-hash-binding") != "ready":
        raise SystemExit("v61ae full-safetensors-page-hash-binding gap should be ready")
else:
    if gaps.get("full-safetensors-page-hash-binding") != "blocked":
        raise SystemExit("v61ae full-safetensors-page-hash-binding gap should stay blocked")
for gap in [
    "human-source-review-artifacts",
    "materialization-admission",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ae gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ae_real_generation_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ae_real_generation_admission_gate_ready") != 1:
    raise SystemExit("v61ae manifest readiness mismatch")
if manifest.get("generation_candidate_rows") != 1000:
    raise SystemExit("v61ae manifest candidate row count mismatch")
if manifest.get("generation_admitted_rows") != 0:
    raise SystemExit("v61ae manifest should admit zero generation rows")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ae manifest should keep generation blocked")
if manifest.get("warehouse_root_override_supplied") != 0:
    raise SystemExit("v61ae manifest should record no default warehouse override")

boundary = (run_dir / "V61AE_REAL_GENERATION_ADMISSION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete_source_query_rows=1000",
    "generation_candidate_rows=1000",
    "generation_admitted_rows=0",
    "runtime_budget_ready_rows=1000",
    "source_review_blocked_rows=1000",
    "materialization_blocked_rows=1000",
    "page_hash_blocked_rows=1000",
    "warehouse_root_override_supplied=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ae boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ae sha256 mismatch: {rel}")
PY

echo "v61ae real generation admission gate smoke passed"
