#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dg_post_full_shard_runtime_evidence_promotion_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DG_REUSE_EXISTING="${V61DG_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61dg summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cj_real_manifest_immediate_target_bridge_ready": "1",
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": "1",
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": "1",
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": "1",
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": "1",
    "v61cs_complete_source_generation_execution_admission_gate_ready": "1",
    "evidence_rows": "16",
    "ready_evidence_rows": "9",
    "blocked_evidence_rows": "7",
    "post_full_shard_runtime_evidence_ready": "1",
    "real_manifest_fixture_replacement_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "checkpoint_shard_rows": "59",
    "ready_checkpoint_materialization_shard_rows": "59",
    "promotion_identity_verified_bytes": "281241493344",
    "full_safetensors_page_hash_binding_ready": "1",
    "total_required_page_hash_rows": "134161",
    "total_verified_page_hash_rows": "134161",
    "gpu_page_dequant_matmul_measurement_ready": "1",
    "gpu_kernel_avg_ms": "0.513442",
    "gpu_page_dequant_gflops": "16.337990",
    "gpu_page_bandwidth_gbps": "4.124385",
    "kv_cache_policy_ready": "1",
    "kv_eviction_trace_ready": "1",
    "host_ram_kv_spill_enabled": "0",
    "host_ram_spill_bytes": "0",
    "max_evicted_nvme_bytes": "1639972864",
    "v61j_source_bound_qa_command_pass": "1",
    "source_bound_query_rows": "37",
    "source_bound_query_pass_rows": "37",
    "source_bound_citation_rows": "37",
    "source_bound_abstain_rows": "10",
    "source_bound_runtime_execution_admission_ready": "1",
    "complete_source_runtime_admission_execution_ready": "1",
    "runtime_admission_acceptance_rows": "1000",
    "runtime_admission_accepted_rows": "1000",
    "generation_operator_bundle_handoff_ready": "1",
    "generation_execution_packet_ready": "1",
    "complete_source_review_return_ready": "0",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dg {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_full_shard_runtime_evidence_rows.csv",
    "runtime_evidence_promotion_metric_rows.csv",
    "runtime_evidence_claim_boundary_rows.csv",
    "runtime_gap_rows.csv",
    "V61DG_POST_FULL_SHARD_RUNTIME_EVIDENCE_PROMOTION_GATE_BOUNDARY.md",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_manifest.json",
    "source_v61cj/v61cj_real_manifest_immediate_target_bridge_summary.csv",
    "source_v61cj/real_manifest_immediate_target_rows.csv",
    "source_v61l/gpu_page_dequant_matmul_rows.csv",
    "source_v61m/kv_residency_policy_rows.csv",
    "source_v61s/source_bound_workload_pass_rows.csv",
    "source_v61cm/full_checkpoint_materialization_promotion_rows.csv",
    "source_v61cb/full_page_hash_coverage_promotion_rows.csv",
    "source_v61cx/post_full_shard_generation_closure_queue_rows.csv",
    "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv",
    "source_v61cs/complete_source_generation_execution_admission_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dg artifact: {rel}")

evidence_rows = read_csv(run_dir / "post_full_shard_runtime_evidence_rows.csv")
if len(evidence_rows) != 16:
    raise SystemExit("v61dg expected 16 evidence rows")
ready_ids = {row["evidence_id"] for row in evidence_rows if row["status"] == "ready"}
blocked_ids = {row["evidence_id"] for row in evidence_rows if row["status"] == "blocked"}
for evidence_id in [
    "real-manifest-fixture-replacement",
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "gpu-rocm-page-dequant-matmul-measurement",
    "kv-cache-residency-eviction-policy",
    "v61j-source-bound-qa-command-pass",
    "source-bound-runtime-execution-admission",
    "complete-source-runtime-admission-acceptance",
    "generation-execution-packet-handoff",
]:
    if evidence_id not in ready_ids:
        raise SystemExit(f"v61dg evidence should be ready: {evidence_id}")
for evidence_id in [
    "complete-source-review-return",
    "complete-source-generation-execution-admission",
    "generation-result-artifact-acceptance",
    "actual-model-generation",
    "production-latency-claim",
    "near-frontier-quality-claim",
    "release-package",
]:
    if evidence_id not in blocked_ids:
        raise SystemExit(f"v61dg evidence should stay blocked: {evidence_id}")

claim_rows = {row["claim"]: row["status"] for row in read_csv(run_dir / "runtime_evidence_claim_boundary_rows.csv")}
if claim_rows.get("full-shard SSD-resident runtime evidence surface") != "allowed":
    raise SystemExit("v61dg should allow full-shard runtime evidence wording")
if claim_rows.get("ROCm page-kernel timing") != "allowed-with-boundary":
    raise SystemExit("v61dg should boundary ROCm timing wording")
if claim_rows.get("actual Mixtral generation ready") != "blocked":
    raise SystemExit("v61dg should block actual generation wording")
if claim_rows.get("production latency / near-frontier / release readiness") != "blocked":
    raise SystemExit("v61dg should block production/near-frontier/release wording")

metric = read_csv(run_dir / "runtime_evidence_promotion_metric_rows.csv")[0]
for field in [
    "ready_evidence_rows",
    "blocked_evidence_rows",
    "total_verified_page_hash_rows",
    "runtime_admission_accepted_rows",
    "generation_execution_admitted_rows",
    "actual_model_generation_ready",
]:
    if metric[field] != summary[field]:
        raise SystemExit(f"v61dg metric {field} should mirror summary")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in ready_ids:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61dg gap should be ready: {gap}")
for gap in blocked_ids:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61dg gap should be blocked: {gap}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ready_ids | {"post-full-shard-runtime-evidence-promotion"}:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dg decision should pass: {gate}")
for gate in blocked_ids:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dg decision should stay blocked: {gate}")

boundary = (run_dir / "V61DG_POST_FULL_SHARD_RUNTIME_EVIDENCE_PROMOTION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "post_full_shard_runtime_evidence_ready=1",
    "ready_checkpoint_materialization_shard_rows=59/59",
    "total_verified_page_hash_rows=134161/134161",
    "gpu_page_dequant_matmul_measurement_ready=1",
    "gpu_kernel_avg_ms=0.513442",
    "kv_cache_policy_ready=1",
    "host_ram_kv_spill_enabled=0",
    "v61j_source_bound_qa_command_pass=1",
    "source_bound_query_pass_rows=37/37",
    "runtime_admission_accepted_rows=1000/1000",
    "generation_execution_admitted_rows=0/1000",
    "answer_review_accepted_rows=0/7000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dg boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dg_post_full_shard_runtime_evidence_promotion_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dg_post_full_shard_runtime_evidence_promotion_gate_ready") != 1:
    raise SystemExit("v61dg manifest readiness mismatch")
if manifest.get("post_full_shard_runtime_evidence_ready") != 1:
    raise SystemExit("v61dg manifest should mark runtime evidence ready")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dg manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dg manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dg sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dg produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dg post-full-shard runtime evidence promotion gate smoke passed"
