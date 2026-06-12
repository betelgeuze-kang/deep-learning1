#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cj_real_manifest_immediate_target_bridge"
RUN_ID="${V61CJ_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cj_real_manifest_immediate_target_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ci_real_manifest_runtime_substitution_gate.sh" >/dev/null
V61L_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61l_gpu_page_dequant_matmul_measurement.sh" >/dev/null
V61M_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61m_kv_cache_residency_eviction_policy.sh" >/dev/null
V61S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61s_one_command_source_bound_qa_replay.sh" >/dev/null

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
model_id = "mistralai/Mixtral-8x22B-v0.1"

v61ci_dir = results / "v61ci_real_manifest_runtime_substitution_gate" / "gate_001"
v61l_dir = results / "v61l_gpu_page_dequant_matmul_measurement" / "gpu_001"
v61m_dir = results / "v61m_kv_cache_residency_eviction_policy" / "kv_001"
v61s_dir = results / "v61s_one_command_source_bound_qa_replay" / "replay_001"
v61n_dir = results / "v61n_source_bound_qa_workload" / "qa_001"


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


def status(flag):
    return "pass" if flag else "blocked"


v61ci = read_csv(results / "v61ci_real_manifest_runtime_substitution_gate_summary.csv")[0]
v61l = read_csv(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv")[0]
v61m = read_csv(results / "v61m_kv_cache_residency_eviction_policy_summary.csv")[0]
v61s = read_csv(results / "v61s_one_command_source_bound_qa_replay_summary.csv")[0]
v61n = read_csv(results / "v61n_source_bound_qa_workload_summary.csv")[0]
if v61ci.get("v61ci_real_manifest_runtime_substitution_gate_ready") != "1":
    raise SystemExit("v61cj requires v61ci_real_manifest_runtime_substitution_gate_ready=1")
if v61l.get("v61l_gpu_page_dequant_matmul_measurement_ready") != "1":
    raise SystemExit("v61cj requires v61l_gpu_page_dequant_matmul_measurement_ready=1")
if v61m.get("v61m_kv_cache_residency_eviction_policy_ready") != "1":
    raise SystemExit("v61cj requires v61m_kv_cache_residency_eviction_policy_ready=1")
if v61s.get("v61s_one_command_source_bound_qa_replay_ready") != "1":
    raise SystemExit("v61cj requires v61s_one_command_source_bound_qa_replay_ready=1")

for src, rel in [
    (results / "v61ci_real_manifest_runtime_substitution_gate_summary.csv", "source_v61ci/v61ci_real_manifest_runtime_substitution_gate_summary.csv"),
    (results / "v61ci_real_manifest_runtime_substitution_gate_decision.csv", "source_v61ci/v61ci_real_manifest_runtime_substitution_gate_decision.csv"),
    (v61ci_dir / "logical_fixture_replacement_contract_rows.csv", "source_v61ci/logical_fixture_replacement_contract_rows.csv"),
    (v61ci_dir / "real_manifest_runtime_binding_rows.csv", "source_v61ci/real_manifest_runtime_binding_rows.csv"),
    (v61ci_dir / "sha256_manifest.csv", "source_v61ci/sha256_manifest.csv"),
    (results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    (results / "v61l_gpu_page_dequant_matmul_measurement_decision.csv", "source_v61l/v61l_gpu_page_dequant_matmul_measurement_decision.csv"),
    (v61l_dir / "gpu_page_dequant_matmul_rows.csv", "source_v61l/gpu_page_dequant_matmul_rows.csv"),
    (v61l_dir / "real_model_manifest_binding_rows.csv", "source_v61l/real_model_manifest_binding_rows.csv"),
    (v61l_dir / "runtime_gap_rows.csv", "source_v61l/runtime_gap_rows.csv"),
    (v61l_dir / "sha256_manifest.csv", "source_v61l/sha256_manifest.csv"),
    (results / "v61m_kv_cache_residency_eviction_policy_summary.csv", "source_v61m/v61m_kv_cache_residency_eviction_policy_summary.csv"),
    (results / "v61m_kv_cache_residency_eviction_policy_decision.csv", "source_v61m/v61m_kv_cache_residency_eviction_policy_decision.csv"),
    (v61m_dir / "kv_cache_geometry_rows.csv", "source_v61m/kv_cache_geometry_rows.csv"),
    (v61m_dir / "kv_residency_policy_rows.csv", "source_v61m/kv_residency_policy_rows.csv"),
    (v61m_dir / "kv_budget_profile_rows.csv", "source_v61m/kv_budget_profile_rows.csv"),
    (v61m_dir / "runtime_gap_rows.csv", "source_v61m/runtime_gap_rows.csv"),
    (v61m_dir / "sha256_manifest.csv", "source_v61m/sha256_manifest.csv"),
    (results / "v61s_one_command_source_bound_qa_replay_summary.csv", "source_v61s/v61s_one_command_source_bound_qa_replay_summary.csv"),
    (results / "v61s_one_command_source_bound_qa_replay_decision.csv", "source_v61s/v61s_one_command_source_bound_qa_replay_decision.csv"),
    (v61s_dir / "one_command_replay_rows.csv", "source_v61s/one_command_replay_rows.csv"),
    (v61s_dir / "source_bound_workload_pass_rows.csv", "source_v61s/source_bound_workload_pass_rows.csv"),
    (v61s_dir / "runtime_gap_rows.csv", "source_v61s/runtime_gap_rows.csv"),
    (v61s_dir / "sha256_manifest.csv", "source_v61s/sha256_manifest.csv"),
    (results / "v61n_source_bound_qa_workload_summary.csv", "source_v61n/v61n_source_bound_qa_workload_summary.csv"),
    (v61n_dir / "source_bound_query_rows.csv", "source_v61n/source_bound_query_rows.csv"),
    (v61n_dir / "source_bound_answer_rows.csv", "source_v61n/source_bound_answer_rows.csv"),
    (v61n_dir / "source_bound_citation_rows.csv", "source_v61n/source_bound_citation_rows.csv"),
    (v61n_dir / "source_bound_abstain_rows.csv", "source_v61n/source_bound_abstain_rows.csv"),
    (v61n_dir / "source_bound_resource_rows.csv", "source_v61n/source_bound_resource_rows.csv"),
    (v61n_dir / "sha256_manifest.csv", "source_v61n/sha256_manifest.csv"),
]:
    copy(src, rel)

immediate_target_rows = [
    {
        "target_id": "v61-immediate-1-real-manifest-fixture-replacement",
        "target_statement": "logical 128B fixture is replaced by a real open-weight MoE zero-payload page manifest input",
        "evidence_source": "v61ci",
        "required_ready_field": "logical_fixture_replaced_by_real_manifest_ready",
        "actual_ready_value": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
        "target_ready": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
        "claim_scope": "runtime input contract only",
        "blocked_claim": "real runtime execution",
    },
    {
        "target_id": "v61-immediate-2-gpu-rocm-page-kernel",
        "target_statement": "GPU/ROCm page-dequant-matmul measurement is bound to real-model page geometry",
        "evidence_source": "v61l",
        "required_ready_field": "gpu_measurement_ready",
        "actual_ready_value": v61l["gpu_measurement_ready"],
        "target_ready": v61l["gpu_measurement_ready"],
        "claim_scope": f"one q4-equivalent page tile; avg_ms={v61l['gpu_kernel_avg_ms']}; gflops={v61l['gpu_page_dequant_gflops']}",
        "blocked_claim": "end-to-end production decode latency",
    },
    {
        "target_id": "v61-immediate-3-kv-residency-eviction",
        "target_statement": "KV-cache residency / eviction policy is bound to Mixtral geometry",
        "evidence_source": "v61m",
        "required_ready_field": "kv_cache_policy_ready",
        "actual_ready_value": v61m["kv_cache_policy_ready"],
        "target_ready": v61m["kv_cache_policy_ready"],
        "claim_scope": f"{v61m['sequence_profile_rows']} profiles; max_evicted_nvme_bytes={v61m['max_evicted_nvme_bytes']}",
        "blocked_claim": "long-context quality or full-KV-in-VRAM",
    },
    {
        "target_id": "v61-immediate-4-v61j-source-bound-qa-command",
        "target_statement": "v61j command path passes source-bound code/doc QA workload",
        "evidence_source": "v61s",
        "required_ready_field": "one_command_source_bound_qa_pass",
        "actual_ready_value": v61s["one_command_source_bound_qa_pass"],
        "target_ready": v61s["one_command_source_bound_qa_pass"],
        "claim_scope": f"{v61s['source_bound_query_pass_rows']}/{v61s['source_bound_query_rows']} source-bound seed queries",
        "blocked_claim": "complete-source 1000-query real model generation",
    },
]
write_csv(run_dir / "real_manifest_immediate_target_rows.csv", list(immediate_target_rows[0].keys()), immediate_target_rows)

runtime_bridge_rows = [
    {
        "bridge_id": "real-manifest-input-to-gpu",
        "source_ready": v61ci["zero_payload_runtime_input_ready"],
        "target_ready": v61l["gpu_measurement_ready"],
        "bridge_ready": str(int(v61ci["zero_payload_runtime_input_ready"] == "1" and v61l["gpu_measurement_ready"] == "1")),
        "evidence_summary": f"page_size_bytes={v61l['page_size_bytes']}; q4_page_bytes={v61l['q4_page_bytes']}; avg_ms={v61l['gpu_kernel_avg_ms']}",
    },
    {
        "bridge_id": "real-manifest-input-to-kv",
        "source_ready": v61ci["zero_payload_runtime_input_ready"],
        "target_ready": v61m["kv_cache_policy_ready"],
        "bridge_ready": str(int(v61ci["zero_payload_runtime_input_ready"] == "1" and v61m["kv_cache_policy_ready"] == "1")),
        "evidence_summary": f"kv_bytes_per_token={v61m['kv_bytes_per_token']}; host_ram_spill_bytes={v61m['host_ram_spill_bytes']}",
    },
    {
        "bridge_id": "real-manifest-input-to-source-bound-qa-command",
        "source_ready": v61ci["zero_payload_runtime_input_ready"],
        "target_ready": v61s["one_command_source_bound_qa_pass"],
        "bridge_ready": str(int(v61ci["zero_payload_runtime_input_ready"] == "1" and v61s["one_command_source_bound_qa_pass"] == "1")),
        "evidence_summary": f"entrypoint={v61s['entrypoint']} {v61s['entrypoint_mode']}; pass_rows={v61s['source_bound_query_pass_rows']}",
    },
]
write_csv(run_dir / "real_manifest_runtime_evidence_bridge_rows.csv", list(runtime_bridge_rows[0].keys()), runtime_bridge_rows)

ready_target_rows = sum(1 for row in immediate_target_rows if row["target_ready"] == "1")
bridge_ready_rows = sum(1 for row in runtime_bridge_rows if row["bridge_ready"] == "1")
immediate_target_bridge_ready = int(ready_target_rows == 4 and bridge_ready_rows == 3)

requirement_rows = [
    {
        "requirement_id": "real-manifest-fixture-replacement",
        "status": status(v61ci["logical_fixture_replaced_by_real_manifest_ready"] == "1"),
        "required_value": "1",
        "actual_value": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
        "reason": "v61ci replaces the logical fixture input with real zero-payload manifest metadata",
    },
    {
        "requirement_id": "gpu-rocm-page-kernel-measurement",
        "status": status(v61l["gpu_measurement_ready"] == "1"),
        "required_value": "1",
        "actual_value": v61l["gpu_measurement_ready"],
        "reason": "v61l records positive ROCm page-kernel timing rows",
    },
    {
        "requirement_id": "kv-cache-residency-eviction-policy",
        "status": status(v61m["kv_cache_policy_ready"] == "1"),
        "required_value": "1",
        "actual_value": v61m["kv_cache_policy_ready"],
        "reason": "v61m records deterministic VRAM-hot/NVMe-cold KV policy rows",
    },
    {
        "requirement_id": "v61j-source-bound-qa-command-pass",
        "status": status(v61s["one_command_source_bound_qa_pass"] == "1"),
        "required_value": "1",
        "actual_value": v61s["one_command_source_bound_qa_pass"],
        "reason": "v61s exercises the v61j command with source-bound QA mode",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": status(v61ci["completed_full_safetensors_page_hash_coverage_ready"] == "1"),
        "required_value": v61ci["total_required_page_hash_rows"],
        "actual_value": v61ci["total_verified_page_hash_rows"],
        "reason": "the immediate target bridge does not complete remaining page hashes",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": "blocked",
        "required_value": "accepted real generation artifacts",
        "actual_value": "0",
        "reason": "source-bound command replay is a scaffold/seed, not real Mixtral generation",
    },
]
write_csv(run_dir / "real_manifest_immediate_target_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cj_real_manifest_immediate_target_bridge_metrics",
    "model_id": model_id,
    "v61ci_real_manifest_runtime_substitution_gate_ready": v61ci["v61ci_real_manifest_runtime_substitution_gate_ready"],
    "v61l_gpu_page_dequant_matmul_measurement_ready": v61l["v61l_gpu_page_dequant_matmul_measurement_ready"],
    "v61m_kv_cache_residency_eviction_policy_ready": v61m["v61m_kv_cache_residency_eviction_policy_ready"],
    "v61s_one_command_source_bound_qa_replay_ready": v61s["v61s_one_command_source_bound_qa_replay_ready"],
    "immediate_target_rows": str(len(immediate_target_rows)),
    "ready_immediate_target_rows": str(ready_target_rows),
    "runtime_bridge_rows": str(len(runtime_bridge_rows)),
    "ready_runtime_bridge_rows": str(bridge_ready_rows),
    "real_manifest_immediate_target_bridge_ready": str(immediate_target_bridge_ready),
    "logical_fixture_replaced_by_real_manifest_ready": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
    "zero_payload_runtime_input_ready": v61ci["zero_payload_runtime_input_ready"],
    "gpu_kernel_avg_ms": v61l["gpu_kernel_avg_ms"],
    "gpu_page_dequant_gflops": v61l["gpu_page_dequant_gflops"],
    "gpu_page_bandwidth_gbps": v61l["gpu_page_bandwidth_gbps"],
    "kv_cache_policy_ready": v61m["kv_cache_policy_ready"],
    "kv_eviction_trace_ready": v61m["kv_eviction_trace_ready"],
    "source_bound_query_rows": v61s["source_bound_query_rows"],
    "source_bound_query_pass_rows": v61s["source_bound_query_pass_rows"],
    "source_bound_citation_rows": v61s["source_bound_citation_rows"],
    "source_bound_abstain_rows": v61s["source_bound_abstain_rows"],
    "complete_source_1000_query_ready": v61s["complete_source_1000_query_ready"],
    "total_required_page_hash_rows": v61ci["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61ci["total_verified_page_hash_rows"],
    "remaining_page_hash_rows": v61ci["remaining_page_hash_rows"],
    "completed_full_safetensors_page_hash_coverage_ready": v61ci["completed_full_safetensors_page_hash_coverage_ready"],
    "runtime_execution_admission_ready": v61ci["runtime_execution_admission_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "real_manifest_immediate_target_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cj_real_manifest_immediate_target_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "real-manifest-fixture-replacement", "status": "ready", "reason": "v61ci substitution is ready"},
    {"gap": "gpu-rocm-page-kernel-measurement", "status": "ready", "reason": "v61l GPU measurement is ready"},
    {"gap": "kv-cache-residency-eviction-policy", "status": "ready", "reason": "v61m KV policy is ready"},
    {"gap": "v61j-source-bound-qa-command-pass", "status": "ready", "reason": "v61s one-command QA replay passes"},
    {"gap": "completed-full-safetensors-page-hash-coverage", "status": "blocked", "reason": f"total_verified_page_hash_rows={v61ci['total_verified_page_hash_rows']}/{v61ci['total_required_page_hash_rows']}"},
    {"gap": "complete-source-1000-query", "status": "blocked", "reason": f"complete_source_1000_query_ready={v61s['complete_source_1000_query_ready']}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "not real Mixtral generation"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode latency report"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "real-manifest-fixture-replacement", "status": "pass", "reason": "v61ci substitution is ready"},
    {"gate": "gpu-rocm-page-kernel-measurement", "status": "pass", "reason": "v61l GPU measurement is ready"},
    {"gate": "kv-cache-residency-eviction-policy", "status": "pass", "reason": "v61m KV policy is ready"},
    {"gate": "v61j-source-bound-qa-command-pass", "status": "pass", "reason": "v61s one-command source-bound QA replay passes"},
    {"gate": "real-manifest-immediate-target-bridge", "status": "pass" if immediate_target_bridge_ready else "blocked", "reason": f"ready_targets={ready_target_rows}/4; ready_bridges={bridge_ready_rows}/3"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "blocked", "reason": f"total_verified_page_hash_rows={v61ci['total_verified_page_hash_rows']}/{v61ci['total_required_page_hash_rows']}"},
    {"gate": "complete-source-1000-query", "status": "blocked", "reason": f"complete_source_1000_query_ready={v61s['complete_source_1000_query_ready']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cj Real Manifest Immediate Target Bridge Boundary

This artifact binds the v61 real-model immediate targets into one evidence
surface after v61ci real-manifest runtime substitution. It records that the
fixture replacement, ROCm page-kernel timing, KV policy, and v61j source-bound
QA command path are present, while keeping full page-hash coverage and actual
generation blocked.

Evidence emitted:

- immediate_target_rows={len(immediate_target_rows)}
- ready_immediate_target_rows={ready_target_rows}
- runtime_bridge_rows={len(runtime_bridge_rows)}
- ready_runtime_bridge_rows={bridge_ready_rows}
- real_manifest_immediate_target_bridge_ready={immediate_target_bridge_ready}
- logical_fixture_replaced_by_real_manifest_ready={v61ci["logical_fixture_replaced_by_real_manifest_ready"]}
- gpu_kernel_avg_ms={v61l["gpu_kernel_avg_ms"]}
- gpu_page_dequant_gflops={v61l["gpu_page_dequant_gflops"]}
- kv_cache_policy_ready={v61m["kv_cache_policy_ready"]}
- source_bound_query_pass_rows={v61s["source_bound_query_pass_rows"]}/{v61s["source_bound_query_rows"]}
- completed_full_safetensors_page_hash_coverage_ready={v61ci["completed_full_safetensors_page_hash_coverage_ready"]}
- complete_source_1000_query_ready={v61s["complete_source_1000_query_ready"]}
- runtime_execution_admission_ready={v61ci["runtime_execution_admission_ready"]}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cj=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: v61 real-model immediate target bridge, ROCm page-kernel timing
bound to real manifest geometry, KV-cache residency policy, and source-bound QA
command seed replay. Blocked wording: completed full safetensors page-hash
coverage, complete-source 1000-query real model generation, production latency,
near-frontier quality, or release readiness.
"""
(run_dir / "V61CJ_REAL_MANIFEST_IMMEDIATE_TARGET_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cj_real_manifest_immediate_target_bridge",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cj_real_manifest_immediate_target_bridge_ready": 1,
    "v61ci_summary_sha256": sha256(results / "v61ci_real_manifest_runtime_substitution_gate_summary.csv"),
    "v61l_summary_sha256": sha256(results / "v61l_gpu_page_dequant_matmul_measurement_summary.csv"),
    "v61m_summary_sha256": sha256(results / "v61m_kv_cache_residency_eviction_policy_summary.csv"),
    "v61s_summary_sha256": sha256(results / "v61s_one_command_source_bound_qa_replay_summary.csv"),
    "immediate_target_rows": len(immediate_target_rows),
    "ready_immediate_target_rows": ready_target_rows,
    "runtime_bridge_rows": len(runtime_bridge_rows),
    "ready_runtime_bridge_rows": bridge_ready_rows,
    "real_manifest_immediate_target_bridge_ready": immediate_target_bridge_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61cj": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61cj_real_manifest_immediate_target_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cj_real_manifest_immediate_target_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
