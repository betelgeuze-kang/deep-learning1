#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dg_post_full_shard_runtime_evidence_promotion_gate"
RUN_ID="${V61DG_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dg_post_full_shard_runtime_evidence_promotion_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V61DG_REFRESH_UPSTREAM:-0}" == "1" || ! -s "$RESULTS_DIR/v61cj_real_manifest_immediate_target_bridge_summary.csv" ]]; then
  V61CJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cj_real_manifest_immediate_target_bridge.sh" >/dev/null
fi
if [[ "${V61DG_REFRESH_UPSTREAM:-0}" == "1" || ! -s "$RESULTS_DIR/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv" ]]; then
  V61CM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh" >/dev/null
fi
if [[ "${V61DG_REFRESH_UPSTREAM:-0}" == "1" || ! -s "$RESULTS_DIR/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv" ]]; then
  V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
fi
if [[ "${V61DG_REFRESH_UPSTREAM:-0}" == "1" || ! -s "$RESULTS_DIR/v61cx_post_full_shard_actual_generation_closure_queue_summary.csv" ]]; then
  V61CX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cx_post_full_shard_actual_generation_closure_queue.sh" >/dev/null
fi
if [[ "${V61DG_REFRESH_UPSTREAM:-0}" == "1" || ! -s "$RESULTS_DIR/v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv" ]]; then
  V61CW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
fi
if [[ "${V61DG_REFRESH_UPSTREAM:-0}" == "1" || ! -s "$RESULTS_DIR/v61cs_complete_source_generation_execution_admission_gate_summary.csv" ]]; then
  V61CS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null
fi

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


def status(ready):
    return "ready" if ready else "blocked"


summary_sources = {
    "v61cj": results / "v61cj_real_manifest_immediate_target_bridge_summary.csv",
    "v61l": results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv",
    "v61m": results / "v61m_kv_cache_residency_eviction_policy_summary.csv",
    "v61s": results / "v61s_one_command_source_bound_qa_replay_summary.csv",
    "v61cm": results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv",
    "v61cb": results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv",
    "v61cx": results / "v61cx_post_full_shard_actual_generation_closure_queue_summary.csv",
    "v61cw": results / "v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv",
    "v61cs": results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
}
decision_sources = {
    "v61cj": results / "v61cj_real_manifest_immediate_target_bridge_decision.csv",
    "v61l": results / "v61l_gpu_page_dequant_matmul_measurement_decision.csv",
    "v61m": results / "v61m_kv_cache_residency_eviction_policy_decision.csv",
    "v61s": results / "v61s_one_command_source_bound_qa_replay_decision.csv",
    "v61cm": results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv",
    "v61cb": results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv",
    "v61cx": results / "v61cx_post_full_shard_actual_generation_closure_queue_decision.csv",
    "v61cw": results / "v61cw_complete_source_runtime_admission_acceptance_bridge_decision.csv",
    "v61cs": results / "v61cs_complete_source_generation_execution_admission_gate_decision.csv",
}

summaries = {}
for name, path in summary_sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dg source summary: {path}")
    summaries[name] = read_csv(path)[0]
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_sources.items():
    if path.is_file():
        copy(path, f"source_{name}/{path.name}")

source_artifacts = [
    ("v61cj_real_manifest_immediate_target_bridge/bridge_001/real_manifest_immediate_target_rows.csv", "source_v61cj/real_manifest_immediate_target_rows.csv"),
    ("v61cj_real_manifest_immediate_target_bridge/bridge_001/real_manifest_runtime_evidence_bridge_rows.csv", "source_v61cj/real_manifest_runtime_evidence_bridge_rows.csv"),
    ("v61l_gpu_page_dequant_matmul_measurement/gpu_001/gpu_page_dequant_matmul_rows.csv", "source_v61l/gpu_page_dequant_matmul_rows.csv"),
    ("v61l_gpu_page_dequant_matmul_measurement/gpu_001/rocm_runtime_env_rows.csv", "source_v61l/rocm_runtime_env_rows.csv"),
    ("v61m_kv_cache_residency_eviction_policy/kv_001/kv_cache_geometry_rows.csv", "source_v61m/kv_cache_geometry_rows.csv"),
    ("v61m_kv_cache_residency_eviction_policy/kv_001/kv_residency_policy_rows.csv", "source_v61m/kv_residency_policy_rows.csv"),
    ("v61m_kv_cache_residency_eviction_policy/kv_001/kv_budget_profile_rows.csv", "source_v61m/kv_budget_profile_rows.csv"),
    ("v61s_one_command_source_bound_qa_replay/replay_001/source_bound_workload_pass_rows.csv", "source_v61s/source_bound_workload_pass_rows.csv"),
    ("v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate/gate_001/full_checkpoint_materialization_promotion_rows.csv", "source_v61cm/full_checkpoint_materialization_promotion_rows.csv"),
    ("v61cb_ubuntu1_full_page_hash_coverage_promotion_gate/gate_001/full_page_hash_coverage_promotion_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_rows.csv"),
    ("v61cx_post_full_shard_actual_generation_closure_queue/queue_001/post_full_shard_generation_closure_queue_rows.csv", "source_v61cx/post_full_shard_generation_closure_queue_rows.csv"),
    ("v61cw_complete_source_runtime_admission_acceptance_bridge/bridge_001/complete_source_runtime_admission_acceptance_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv"),
    ("v61cs_complete_source_generation_execution_admission_gate/gate_001/complete_source_generation_execution_admission_rows.csv", "source_v61cs/complete_source_generation_execution_admission_rows.csv"),
]
for src_rel, dst_rel in source_artifacts:
    src = results / src_rel
    if not src.is_file():
        raise SystemExit(f"missing v61dg source artifact: {src}")
    copy(src, dst_rel)

v61cj = summaries["v61cj"]
v61l = summaries["v61l"]
v61m = summaries["v61m"]
v61s = summaries["v61s"]
v61cm = summaries["v61cm"]
v61cb = summaries["v61cb"]
v61cx = summaries["v61cx"]
v61cw = summaries["v61cw"]
v61cs = summaries["v61cs"]

model_id = v61cm.get("model_id") or v61cj.get("model_id") or "unknown"
real_manifest_ready = as_int(v61cj, "logical_fixture_replaced_by_real_manifest_ready")
full_checkpoint_ready = as_int(v61cm, "full_checkpoint_materialization_ready")
full_page_hash_ready = as_int(v61cb, "full_safetensors_page_hash_binding_ready")
gpu_measurement_ready = as_int(v61l, "gpu_measurement_ready")
kv_policy_ready = as_int(v61m, "kv_cache_policy_ready") and as_int(v61m, "kv_eviction_trace_ready")
source_bound_qa_ready = as_int(v61s, "one_command_source_bound_qa_pass")
source_bound_runtime_admitted = int(as_int(v61cj, "ready_runtime_bridge_rows") == as_int(v61cj, "runtime_bridge_rows") and as_int(v61cj, "source_bound_query_pass_rows") == as_int(v61cj, "source_bound_query_rows"))
complete_source_runtime_accepted = int(as_int(v61cw, "runtime_admission_accepted_rows") == as_int(v61cw, "runtime_admission_acceptance_rows") and as_int(v61cw, "complete_source_runtime_admission_execution_ready"))
generation_packet_handoff_ready = int(as_int(v61cs, "generation_operator_bundle_handoff_ready") and as_int(v61cs, "generation_execution_packet_ready"))
review_return_ready = as_int(v61cs, "complete_source_review_return_ready")
generation_execution_admitted = int(as_int(v61cs, "generation_execution_admitted_rows") == as_int(v61cs, "generation_execution_admission_rows"))
generation_result_acceptance_ready = int(as_int(v61cs, "accepted_generation_result_artifacts") == as_int(v61cs, "expected_generation_result_artifacts"))
actual_generation_ready = as_int(v61cs, "actual_model_generation_ready")

evidence_rows = [
    ("real-manifest-fixture-replacement", "v61cj", real_manifest_ready, "logical fixture replaced by real Mixtral page manifest"),
    ("full-checkpoint-materialization", "v61cm", full_checkpoint_ready, "59/59 identity-verified checkpoint shards are materialized outside the repo"),
    ("full-safetensors-page-hash-binding", "v61cb", full_page_hash_ready, "134161/134161 safetensors pages are verified"),
    ("gpu-rocm-page-dequant-matmul-measurement", "v61l", gpu_measurement_ready, "ROCm/HIP page-dequant matmul timing is measured"),
    ("kv-cache-residency-eviction-policy", "v61m", kv_policy_ready, "KV hot VRAM plus NVMe cold eviction policy is ready with host RAM spill disabled"),
    ("v61j-source-bound-qa-command-pass", "v61s", source_bound_qa_ready, "one-command source-bound QA replay passes 37/37 rows"),
    ("source-bound-runtime-execution-admission", "v61cj", source_bound_runtime_admitted, "source-bound runtime bridge rows are ready"),
    ("complete-source-runtime-admission-acceptance", "v61cw", complete_source_runtime_accepted, "1000/1000 complete-source runtime admission rows are accepted"),
    ("generation-execution-packet-handoff", "v61cs", generation_packet_handoff_ready, "generation packet/operator handoff surface is ready"),
    ("complete-source-review-return", "v61cs", review_return_ready, "7000 human review and 1000 adjudication rows must be accepted"),
    ("complete-source-generation-execution-admission", "v61cs", generation_execution_admitted, "generation execution admission remains review/result gated"),
    ("generation-result-artifact-acceptance", "v61cs", generation_result_acceptance_ready, "five generation result artifacts and 1000 query acceptance rows must return"),
    ("actual-model-generation", "v61cs", actual_generation_ready, "actual Mixtral generation cannot be claimed without admitted execution and result acceptance"),
    ("production-latency-claim", "v61cs", as_int(v61cs, "production_latency_claim_ready"), "production latency claim requires real returned latency evidence"),
    ("near-frontier-quality-claim", "v61cs", as_int(v61cs, "near_frontier_claim_ready"), "near-frontier claim requires external review and accepted generation evidence"),
    ("release-package", "v61cs", as_int(v61cs, "real_release_package_ready"), "release package remains blocked"),
]
evidence_dicts = [
    {
        "evidence_id": evidence_id,
        "source_gate": source_gate,
        "status": status(ready),
        "ready": str(int(bool(ready))),
        "reason": reason,
    }
    for evidence_id, source_gate, ready, reason in evidence_rows
]
write_csv(
    run_dir / "post_full_shard_runtime_evidence_rows.csv",
    ["evidence_id", "source_gate", "status", "ready", "reason"],
    evidence_dicts,
)

claim_rows = [
    {
        "claim": "full-shard SSD-resident runtime evidence surface",
        "status": "allowed",
        "required_disclosure": "full checkpoint/page-hash/runtime admission are ready but generation is not accepted",
    },
    {
        "claim": "ROCm page-kernel timing",
        "status": "allowed-with-boundary",
        "required_disclosure": "v61l measures synthetic q4 page geometry, not full model generation latency",
    },
    {
        "claim": "KV residency/eviction policy",
        "status": "allowed-with-boundary",
        "required_disclosure": "policy rows show VRAM hot plus NVMe cold with host RAM spill disabled",
    },
    {
        "claim": "source-bound QA command pass",
        "status": "allowed-with-boundary",
        "required_disclosure": "37-row source-bound replay is not the complete-source 1000-query generation run",
    },
    {
        "claim": "actual Mixtral generation ready",
        "status": "blocked",
        "required_disclosure": "requires review return, execution admission, generation artifacts, and query-level acceptance",
    },
    {
        "claim": "production latency / near-frontier / release readiness",
        "status": "blocked",
        "required_disclosure": "requires external review, accepted generation result rows, latency evidence, and release audit",
    },
]
write_csv(
    run_dir / "runtime_evidence_claim_boundary_rows.csv",
    ["claim", "status", "required_disclosure"],
    claim_rows,
)

ready_rows = sum(row["ready"] == "1" for row in evidence_dicts)
blocked_rows = len(evidence_dicts) - ready_rows
metric = {
    "metric_id": "v61dg",
    "evidence_rows": str(len(evidence_dicts)),
    "ready_evidence_rows": str(ready_rows),
    "blocked_evidence_rows": str(blocked_rows),
    "checkpoint_shard_rows": v61cm.get("checkpoint_shard_rows", "0"),
    "ready_checkpoint_materialization_shard_rows": v61cm.get("ready_checkpoint_materialization_shard_rows", "0"),
    "promotion_identity_verified_bytes": v61cm.get("promotion_identity_verified_bytes", "0"),
    "total_required_page_hash_rows": v61cb.get("total_required_page_hash_rows", "0"),
    "total_verified_page_hash_rows": v61cb.get("total_verified_page_hash_rows", "0"),
    "gpu_kernel_avg_ms": v61l.get("gpu_kernel_avg_ms", "0"),
    "gpu_page_dequant_gflops": v61l.get("gpu_page_dequant_gflops", "0"),
    "gpu_page_bandwidth_gbps": v61l.get("gpu_page_bandwidth_gbps", "0"),
    "kv_bytes_per_token": v61m.get("kv_bytes_per_token", "0"),
    "max_evicted_nvme_bytes": v61m.get("max_evicted_nvme_bytes", "0"),
    "source_bound_query_rows": v61s.get("source_bound_query_rows", "0"),
    "source_bound_query_pass_rows": v61s.get("source_bound_query_pass_rows", "0"),
    "runtime_admission_accepted_rows": v61cw.get("runtime_admission_accepted_rows", "0"),
    "generation_execution_admitted_rows": v61cs.get("generation_execution_admitted_rows", "0"),
    "generation_execution_admission_rows": v61cs.get("generation_execution_admission_rows", "0"),
    "answer_review_accepted_rows": v61cs.get("answer_review_accepted_rows", "0"),
    "expected_human_review_rows": "7000",
    "accepted_generation_result_artifacts": v61cs.get("accepted_generation_result_artifacts", "0"),
    "expected_generation_result_artifacts": v61cs.get("expected_generation_result_artifacts", "0"),
    "actual_model_generation_ready": v61cs.get("actual_model_generation_ready", "0"),
}
write_csv(run_dir / "runtime_evidence_promotion_metric_rows.csv", list(metric.keys()), [metric])

runtime_gap_rows = [
    {
        "gap": row["evidence_id"],
        "status": "ready" if row["ready"] == "1" else "blocked",
        "reason": row["reason"],
    }
    for row in evidence_dicts
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], runtime_gap_rows)

post_full_shard_runtime_evidence_ready = int(
    real_manifest_ready
    and full_checkpoint_ready
    and full_page_hash_ready
    and gpu_measurement_ready
    and kv_policy_ready
    and source_bound_qa_ready
    and source_bound_runtime_admitted
    and complete_source_runtime_accepted
    and generation_packet_handoff_ready
)

summary = {
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "model_id": model_id,
    "v61cj_real_manifest_immediate_target_bridge_ready": v61cj.get("v61cj_real_manifest_immediate_target_bridge_ready", "0"),
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": v61cm.get("v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready", "0"),
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": v61cb.get("v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready", "0"),
    "v61cx_post_full_shard_actual_generation_closure_queue_ready": v61cx.get("v61cx_post_full_shard_actual_generation_closure_queue_ready", "0"),
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": v61cw.get("v61cw_complete_source_runtime_admission_acceptance_bridge_ready", "0"),
    "v61cs_complete_source_generation_execution_admission_gate_ready": v61cs.get("v61cs_complete_source_generation_execution_admission_gate_ready", "0"),
    "evidence_rows": str(len(evidence_dicts)),
    "ready_evidence_rows": str(ready_rows),
    "blocked_evidence_rows": str(blocked_rows),
    "post_full_shard_runtime_evidence_ready": str(post_full_shard_runtime_evidence_ready),
    "real_manifest_fixture_replacement_ready": str(real_manifest_ready),
    "full_checkpoint_materialization_ready": str(full_checkpoint_ready),
    "checkpoint_shard_rows": v61cm.get("checkpoint_shard_rows", "0"),
    "ready_checkpoint_materialization_shard_rows": v61cm.get("ready_checkpoint_materialization_shard_rows", "0"),
    "promotion_identity_verified_bytes": v61cm.get("promotion_identity_verified_bytes", "0"),
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_ready),
    "total_required_page_hash_rows": v61cb.get("total_required_page_hash_rows", "0"),
    "total_verified_page_hash_rows": v61cb.get("total_verified_page_hash_rows", "0"),
    "gpu_page_dequant_matmul_measurement_ready": str(gpu_measurement_ready),
    "gpu_kernel_avg_ms": v61l.get("gpu_kernel_avg_ms", "0"),
    "gpu_page_dequant_gflops": v61l.get("gpu_page_dequant_gflops", "0"),
    "gpu_page_bandwidth_gbps": v61l.get("gpu_page_bandwidth_gbps", "0"),
    "kv_cache_policy_ready": str(int(bool(kv_policy_ready))),
    "kv_eviction_trace_ready": v61m.get("kv_eviction_trace_ready", "0"),
    "host_ram_kv_spill_enabled": v61m.get("host_ram_kv_spill_enabled", "0"),
    "host_ram_spill_bytes": v61m.get("host_ram_spill_bytes", "0"),
    "max_evicted_nvme_bytes": v61m.get("max_evicted_nvme_bytes", "0"),
    "v61j_source_bound_qa_command_pass": str(source_bound_qa_ready),
    "source_bound_query_rows": v61s.get("source_bound_query_rows", "0"),
    "source_bound_query_pass_rows": v61s.get("source_bound_query_pass_rows", "0"),
    "source_bound_citation_rows": v61s.get("source_bound_citation_rows", "0"),
    "source_bound_abstain_rows": v61s.get("source_bound_abstain_rows", "0"),
    "source_bound_runtime_execution_admission_ready": str(source_bound_runtime_admitted),
    "complete_source_runtime_admission_execution_ready": v61cw.get("complete_source_runtime_admission_execution_ready", "0"),
    "runtime_admission_acceptance_rows": v61cw.get("runtime_admission_acceptance_rows", "0"),
    "runtime_admission_accepted_rows": v61cw.get("runtime_admission_accepted_rows", "0"),
    "generation_operator_bundle_handoff_ready": v61cs.get("generation_operator_bundle_handoff_ready", "0"),
    "generation_execution_packet_ready": v61cs.get("generation_execution_packet_ready", "0"),
    "complete_source_review_return_ready": v61cs.get("complete_source_review_return_ready", "0"),
    "answer_review_accepted_rows": v61cs.get("answer_review_accepted_rows", "0"),
    "expected_human_review_rows": "7000",
    "generation_execution_admission_rows": v61cs.get("generation_execution_admission_rows", "0"),
    "generation_execution_admitted_rows": v61cs.get("generation_execution_admitted_rows", "0"),
    "expected_generation_result_artifacts": v61cs.get("expected_generation_result_artifacts", "0"),
    "accepted_generation_result_artifacts": v61cs.get("accepted_generation_result_artifacts", "0"),
    "actual_model_generation_ready": v61cs.get("actual_model_generation_ready", "0"),
    "source_bound_qa_generation_ready": v61cs.get("source_bound_qa_generation_ready", "0"),
    "near_frontier_claim_ready": v61cs.get("near_frontier_claim_ready", "0"),
    "production_latency_claim_ready": v61cs.get("production_latency_claim_ready", "0"),
    "real_release_package_ready": v61cs.get("real_release_package_ready", "0"),
    "checkpoint_payload_bytes_downloaded_by_v61dg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": v61cj.get("real_checkpoint_weight_bytes_materialized", "0"),
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = []
for row in evidence_dicts:
    gate = row["evidence_id"]
    decision_rows.append(
        {
            "gate": gate,
            "status": "pass" if row["ready"] == "1" else "blocked",
            "reason": row["reason"],
        }
    )
decision_rows.append(
    {
        "gate": "post-full-shard-runtime-evidence-promotion",
        "status": "pass" if post_full_shard_runtime_evidence_ready else "blocked",
        "reason": "real manifest, full shard, page hash, ROCm, KV, source-bound QA, and runtime admission are bound",
    }
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

(run_dir / "V61DG_POST_FULL_SHARD_RUNTIME_EVIDENCE_PROMOTION_GATE_BOUNDARY.md").write_text(
    "# v61dg Post-Full-Shard Runtime Evidence Promotion Gate\n\n"
    "This gate promotes the already measured real-model runtime evidence after full-shard closure. "
    "It does not execute or accept actual model generation.\n\n"
    f"- evidence_rows={summary['evidence_rows']}\n"
    f"- ready_evidence_rows={summary['ready_evidence_rows']}\n"
    f"- blocked_evidence_rows={summary['blocked_evidence_rows']}\n"
    f"- post_full_shard_runtime_evidence_ready={summary['post_full_shard_runtime_evidence_ready']}\n"
    f"- full_checkpoint_materialization_ready={summary['full_checkpoint_materialization_ready']}\n"
    f"- ready_checkpoint_materialization_shard_rows={summary['ready_checkpoint_materialization_shard_rows']}/{summary['checkpoint_shard_rows']}\n"
    f"- full_safetensors_page_hash_binding_ready={summary['full_safetensors_page_hash_binding_ready']}\n"
    f"- total_verified_page_hash_rows={summary['total_verified_page_hash_rows']}/{summary['total_required_page_hash_rows']}\n"
    f"- gpu_page_dequant_matmul_measurement_ready={summary['gpu_page_dequant_matmul_measurement_ready']}\n"
    f"- gpu_kernel_avg_ms={summary['gpu_kernel_avg_ms']}\n"
    f"- kv_cache_policy_ready={summary['kv_cache_policy_ready']}\n"
    f"- host_ram_kv_spill_enabled={summary['host_ram_kv_spill_enabled']}\n"
    f"- v61j_source_bound_qa_command_pass={summary['v61j_source_bound_qa_command_pass']}\n"
    f"- source_bound_query_pass_rows={summary['source_bound_query_pass_rows']}/{summary['source_bound_query_rows']}\n"
    f"- runtime_admission_accepted_rows={summary['runtime_admission_accepted_rows']}/{summary['runtime_admission_acceptance_rows']}\n"
    f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}\n"
    f"- answer_review_accepted_rows={summary['answer_review_accepted_rows']}/{summary['expected_human_review_rows']}\n"
    f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}\n"
    f"- actual_model_generation_ready={summary['actual_model_generation_ready']}\n"
    f"- checkpoint_payload_bytes_downloaded_by_v61dg={summary['checkpoint_payload_bytes_downloaded_by_v61dg']}\n\n"
    "Allowed wording: full-shard runtime evidence promotion, ROCm page-kernel timing, KV residency policy, source-bound QA command pass, and complete-source runtime admission acceptance. "
    "Blocked wording: actual Mixtral generation, production latency, near-frontier quality, and release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61dg-post-full-shard-runtime-evidence-promotion-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": 1,
    "model_id": model_id,
    "post_full_shard_runtime_evidence_ready": post_full_shard_runtime_evidence_ready,
    "ready_evidence_rows": ready_rows,
    "blocked_evidence_rows": blocked_rows,
    "full_checkpoint_materialization_ready": full_checkpoint_ready,
    "full_safetensors_page_hash_binding_ready": full_page_hash_ready,
    "gpu_page_dequant_matmul_measurement_ready": gpu_measurement_ready,
    "kv_cache_policy_ready": int(bool(kv_policy_ready)),
    "v61j_source_bound_qa_command_pass": source_bound_qa_ready,
    "runtime_admission_accepted_rows": as_int(v61cw, "runtime_admission_accepted_rows"),
    "generation_execution_admitted_rows": as_int(v61cs, "generation_execution_admitted_rows"),
    "actual_model_generation_ready": actual_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dg_post_full_shard_runtime_evidence_promotion_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "post_full_shard_runtime_evidence_rows.csv",
    "runtime_evidence_promotion_metric_rows.csv",
    "runtime_evidence_claim_boundary_rows.csv",
    "runtime_gap_rows.csv",
    "V61DG_POST_FULL_SHARD_RUNTIME_EVIDENCE_PROMOTION_GATE_BOUNDARY.md",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_manifest.json",
]
for rel in sorted(p.relative_to(run_dir).as_posix() for p in run_dir.rglob("*") if p.is_file()):
    if rel not in artifact_rels:
        artifact_rels.append(rel)
sha_rows = []
for rel in artifact_rels:
    if rel == "sha256_manifest.csv":
        continue
    path = run_dir / rel
    if path.is_file():
        sha_rows.append({"path": rel, "sha256": sha256(path), "size_bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "size_bytes"], sha_rows)

print(f"v61dg_post_full_shard_runtime_evidence_promotion_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
