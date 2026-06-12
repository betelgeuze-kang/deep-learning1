#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61co_real_manifest_runtime_execution_admission_bridge"
RUN_ID="${V61CO_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61co_real_manifest_runtime_execution_admission_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cj_real_manifest_immediate_target_bridge.sh" >/dev/null
V61CI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ci_real_manifest_runtime_substitution_gate.sh" >/dev/null
V61CM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh" >/dev/null
V61CN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cn_ubuntu1_page_hash_execution_materialization_admission_gate.sh" >/dev/null
V61N_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61n_source_bound_qa_workload.sh" >/dev/null
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

v61cj_dir = results / "v61cj_real_manifest_immediate_target_bridge" / "bridge_001"
v61ci_dir = results / "v61ci_real_manifest_runtime_substitution_gate" / "gate_001"
v61cm_dir = results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate" / "gate_001"
v61cn_dir = results / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate" / "gate_001"
v61n_dir = results / "v61n_source_bound_qa_workload" / "qa_001"
v61s_dir = results / "v61s_one_command_source_bound_qa_replay" / "replay_001"


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


def pass_block(flag):
    return "pass" if flag else "blocked"


v61cj = read_csv(results / "v61cj_real_manifest_immediate_target_bridge_summary.csv")[0]
v61ci = read_csv(results / "v61ci_real_manifest_runtime_substitution_gate_summary.csv")[0]
v61cm = read_csv(results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv")[0]
v61cn = read_csv(results / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_summary.csv")[0]
v61n = read_csv(results / "v61n_source_bound_qa_workload_summary.csv")[0]
v61s = read_csv(results / "v61s_one_command_source_bound_qa_replay_summary.csv")[0]

required_ready = [
    ("v61cj", "v61cj_real_manifest_immediate_target_bridge_ready", v61cj),
    ("v61ci", "v61ci_real_manifest_runtime_substitution_gate_ready", v61ci),
    ("v61cm", "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready", v61cm),
    ("v61cn", "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready", v61cn),
    ("v61n", "v61n_source_bound_qa_workload_ready", v61n),
    ("v61s", "v61s_one_command_source_bound_qa_replay_ready", v61s),
]
for label, field, row in required_ready:
    if row.get(field) != "1":
        raise SystemExit(f"v61co requires {label} {field}=1")

for src, rel in [
    (results / "v61cj_real_manifest_immediate_target_bridge_summary.csv", "source_v61cj/v61cj_real_manifest_immediate_target_bridge_summary.csv"),
    (results / "v61cj_real_manifest_immediate_target_bridge_decision.csv", "source_v61cj/v61cj_real_manifest_immediate_target_bridge_decision.csv"),
    (v61cj_dir / "real_manifest_immediate_target_rows.csv", "source_v61cj/real_manifest_immediate_target_rows.csv"),
    (v61cj_dir / "real_manifest_runtime_evidence_bridge_rows.csv", "source_v61cj/real_manifest_runtime_evidence_bridge_rows.csv"),
    (v61cj_dir / "sha256_manifest.csv", "source_v61cj/sha256_manifest.csv"),
    (results / "v61ci_real_manifest_runtime_substitution_gate_summary.csv", "source_v61ci/v61ci_real_manifest_runtime_substitution_gate_summary.csv"),
    (results / "v61ci_real_manifest_runtime_substitution_gate_decision.csv", "source_v61ci/v61ci_real_manifest_runtime_substitution_gate_decision.csv"),
    (v61ci_dir / "logical_fixture_replacement_contract_rows.csv", "source_v61ci/logical_fixture_replacement_contract_rows.csv"),
    (v61ci_dir / "real_manifest_runtime_binding_rows.csv", "source_v61ci/real_manifest_runtime_binding_rows.csv"),
    (v61ci_dir / "sha256_manifest.csv", "source_v61ci/sha256_manifest.csv"),
    (results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv", "source_v61cm/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv"),
    (results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv", "source_v61cm/v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv"),
    (v61cm_dir / "full_checkpoint_materialization_promotion_rows.csv", "source_v61cm/full_checkpoint_materialization_promotion_rows.csv"),
    (v61cm_dir / "sha256_manifest.csv", "source_v61cm/sha256_manifest.csv"),
    (results / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_summary.csv", "source_v61cn/v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_summary.csv"),
    (results / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_decision.csv", "source_v61cn/v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_decision.csv"),
    (v61cn_dir / "page_hash_execution_materialization_admission_rows.csv", "source_v61cn/page_hash_execution_materialization_admission_rows.csv"),
    (v61cn_dir / "sha256_manifest.csv", "source_v61cn/sha256_manifest.csv"),
    (results / "v61n_source_bound_qa_workload_summary.csv", "source_v61n/v61n_source_bound_qa_workload_summary.csv"),
    (v61n_dir / "source_bound_query_rows.csv", "source_v61n/source_bound_query_rows.csv"),
    (v61n_dir / "source_bound_answer_rows.csv", "source_v61n/source_bound_answer_rows.csv"),
    (v61n_dir / "source_bound_citation_rows.csv", "source_v61n/source_bound_citation_rows.csv"),
    (v61n_dir / "source_bound_resource_rows.csv", "source_v61n/source_bound_resource_rows.csv"),
    (v61n_dir / "sha256_manifest.csv", "source_v61n/sha256_manifest.csv"),
    (results / "v61s_one_command_source_bound_qa_replay_summary.csv", "source_v61s/v61s_one_command_source_bound_qa_replay_summary.csv"),
    (v61s_dir / "source_bound_workload_pass_rows.csv", "source_v61s/source_bound_workload_pass_rows.csv"),
    (v61s_dir / "sha256_manifest.csv", "source_v61s/sha256_manifest.csv"),
]:
    copy(src, rel)

query_rows = read_csv(v61n_dir / "source_bound_query_rows.csv")
pass_rows = {row["query_id"]: row for row in read_csv(v61s_dir / "source_bound_workload_pass_rows.csv")}

immediate_ready = v61cj["real_manifest_immediate_target_bridge_ready"] == "1"
substitution_ready = v61ci["logical_fixture_replaced_by_real_manifest_ready"] == "1"
full_materialization_ready = v61cm["full_checkpoint_materialization_ready"] == "1"
page_hash_admission_ready = v61cn["page_hash_execution_admission_ready"] == "1"
full_page_hash_ready = v61cn["completed_full_safetensors_page_hash_coverage_ready"] == "1"

admission_rows = []
for index, query in enumerate(query_rows):
    replay = pass_rows.get(query["query_id"], {})
    source_bound_query_pass = replay.get("source_bound_query_pass", "0")
    admitted = (
        immediate_ready
        and substitution_ready
        and full_materialization_ready
        and page_hash_admission_ready
        and full_page_hash_ready
        and source_bound_query_pass == "1"
    )
    if admitted:
        status = "admitted"
        blocking_gate = "none"
        reason = "all runtime execution admission gates are ready"
    elif not full_materialization_ready:
        status = "blocked-full-checkpoint-materialization"
        blocking_gate = "v61cm-full-checkpoint-materialization"
        reason = (
            f"blocked_checkpoint_materialization_shard_rows={v61cm['blocked_checkpoint_materialization_shard_rows']}; "
            f"missing_remaining_materialization_return_rows={v61cm['missing_remaining_materialization_return_rows']}"
        )
    elif not page_hash_admission_ready:
        status = "blocked-page-hash-execution-admission"
        blocking_gate = "v61cn-page-hash-execution-admission"
        reason = (
            f"admitted_page_hash_execution_chunk_rows={v61cn['admitted_page_hash_execution_chunk_rows']}/"
            f"{v61cn['remaining_page_hash_execution_chunk_rows']}"
        )
    elif not full_page_hash_ready:
        status = "blocked-full-safetensors-page-hash-coverage"
        blocking_gate = "v61cn-full-safetensors-page-hash-coverage"
        reason = f"blocked_page_hash_rows={v61cn['blocked_page_hash_rows']}"
    else:
        status = "blocked-source-bound-query-pass"
        blocking_gate = "v61s-source-bound-query-pass"
        reason = f"source_bound_query_pass={source_bound_query_pass}"
    admission_rows.append(
        {
            "admission_row_id": f"v61co-runtime-admission-{index:04d}",
            "query_id": query["query_id"],
            "workload_id": query["workload_id"],
            "owner_repo": query["owner_repo"],
            "path": query["path"],
            "query_family": query["query_family"],
            "source_bound_query_pass": source_bound_query_pass,
            "real_manifest_immediate_target_bridge_ready": v61cj["real_manifest_immediate_target_bridge_ready"],
            "logical_fixture_replaced_by_real_manifest_ready": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
            "full_checkpoint_materialization_ready": v61cm["full_checkpoint_materialization_ready"],
            "page_hash_execution_admission_ready": v61cn["page_hash_execution_admission_ready"],
            "completed_full_safetensors_page_hash_coverage_ready": v61cn["completed_full_safetensors_page_hash_coverage_ready"],
            "runtime_execution_admitted": "1" if admitted else "0",
            "runtime_execution_admission_status": status,
            "blocking_gate": blocking_gate,
            "blocking_reason": reason,
            "checkpoint_payload_bytes_downloaded_by_v61co": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "real_manifest_runtime_execution_admission_rows.csv", list(admission_rows[0].keys()), admission_rows)

runtime_candidate_rows = len(admission_rows)
runtime_admitted_rows = sum(1 for row in admission_rows if row["runtime_execution_admitted"] == "1")
runtime_blocked_rows = runtime_candidate_rows - runtime_admitted_rows
materialization_blocked_runtime_rows = sum(
    1 for row in admission_rows if row["runtime_execution_admission_status"] == "blocked-full-checkpoint-materialization"
)
page_hash_admission_blocked_runtime_rows = 0 if page_hash_admission_ready else runtime_candidate_rows
source_bound_query_pass_rows = sum(1 for row in admission_rows if row["source_bound_query_pass"] == "1")
runtime_execution_admission_ready = int(runtime_candidate_rows > 0 and runtime_admitted_rows == runtime_candidate_rows)

requirement_rows = [
    {
        "requirement_id": "v61cj-real-manifest-immediate-target-bridge-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61cj["real_manifest_immediate_target_bridge_ready"],
        "reason": "fixture replacement, ROCm page-kernel timing, KV policy, and v61j source-bound QA seed are bound",
    },
    {
        "requirement_id": "v61ci-real-manifest-runtime-substitution-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
        "reason": "logical runtime scaffold is mapped to zero-payload real manifest metadata",
    },
    {
        "requirement_id": "v61cm-full-checkpoint-materialization",
        "status": pass_block(full_materialization_ready),
        "required_value": "59 ready checkpoint shards",
        "actual_value": f"{v61cm['ready_checkpoint_materialization_shard_rows']}/{v61cm['checkpoint_shard_rows']}",
        "reason": "runtime execution cannot admit source-bound queries until all real checkpoint shards are materialized",
    },
    {
        "requirement_id": "v61cn-page-hash-execution-admission",
        "status": pass_block(page_hash_admission_ready),
        "required_value": v61cn["remaining_page_hash_execution_chunk_rows"],
        "actual_value": v61cn["admitted_page_hash_execution_chunk_rows"],
        "reason": "remaining page-hash execution chunks are not admitted while materialization is incomplete",
    },
    {
        "requirement_id": "v61cn-completed-full-safetensors-page-hash-coverage",
        "status": pass_block(full_page_hash_ready),
        "required_value": "0 blocked page hash rows",
        "actual_value": v61cn["blocked_page_hash_rows"],
        "reason": "full page-hash coverage is still incomplete",
    },
    {
        "requirement_id": "v61n-v61s-source-bound-qa-seed",
        "status": pass_block(source_bound_query_pass_rows == runtime_candidate_rows),
        "required_value": str(runtime_candidate_rows),
        "actual_value": str(source_bound_query_pass_rows),
        "reason": "source-bound QA seed rows pass before real runtime admission",
    },
    {
        "requirement_id": "runtime-execution-admission-over-source-bound-qa",
        "status": pass_block(runtime_execution_admission_ready == 1),
        "required_value": str(runtime_candidate_rows),
        "actual_value": str(runtime_admitted_rows),
        "reason": "all source-bound QA candidates remain blocked by materialization/page-hash prerequisites",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0",
        "actual_value": "0",
        "reason": "v61co writes metadata and admission rows only",
    },
]
write_csv(run_dir / "real_manifest_runtime_execution_admission_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61co_real_manifest_runtime_execution_admission_metrics",
    "model_id": model_id,
    "v61cj_real_manifest_immediate_target_bridge_ready": v61cj["v61cj_real_manifest_immediate_target_bridge_ready"],
    "v61ci_real_manifest_runtime_substitution_gate_ready": v61ci["v61ci_real_manifest_runtime_substitution_gate_ready"],
    "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready": v61cm["v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready"],
    "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready": v61cn["v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_ready"],
    "v61n_source_bound_qa_workload_ready": v61n["v61n_source_bound_qa_workload_ready"],
    "v61s_one_command_source_bound_qa_replay_ready": v61s["v61s_one_command_source_bound_qa_replay_ready"],
    "immediate_target_rows": v61cj["immediate_target_rows"],
    "ready_immediate_target_rows": v61cj["ready_immediate_target_rows"],
    "runtime_bridge_rows": v61cj["runtime_bridge_rows"],
    "ready_runtime_bridge_rows": v61cj["ready_runtime_bridge_rows"],
    "real_manifest_immediate_target_bridge_ready": v61cj["real_manifest_immediate_target_bridge_ready"],
    "logical_fixture_replaced_by_real_manifest_ready": v61ci["logical_fixture_replaced_by_real_manifest_ready"],
    "zero_payload_runtime_input_ready": v61ci["zero_payload_runtime_input_ready"],
    "runtime_execution_candidate_rows": str(runtime_candidate_rows),
    "runtime_execution_admitted_rows": str(runtime_admitted_rows),
    "runtime_execution_blocked_rows": str(runtime_blocked_rows),
    "materialization_blocked_runtime_rows": str(materialization_blocked_runtime_rows),
    "page_hash_admission_blocked_runtime_rows": str(page_hash_admission_blocked_runtime_rows),
    "source_bound_query_rows": str(runtime_candidate_rows),
    "source_bound_query_pass_rows": str(source_bound_query_pass_rows),
    "checkpoint_shard_rows": v61cm["checkpoint_shard_rows"],
    "ready_checkpoint_materialization_shard_rows": v61cm["ready_checkpoint_materialization_shard_rows"],
    "blocked_checkpoint_materialization_shard_rows": v61cm["blocked_checkpoint_materialization_shard_rows"],
    "missing_remaining_materialization_return_rows": v61cm["missing_remaining_materialization_return_rows"],
    "promotion_missing_materialization_bytes": v61cm["promotion_missing_materialization_bytes"],
    "full_checkpoint_materialization_ready": v61cm["full_checkpoint_materialization_ready"],
    "remaining_page_hash_execution_chunk_rows": v61cn["remaining_page_hash_execution_chunk_rows"],
    "admitted_page_hash_execution_chunk_rows": v61cn["admitted_page_hash_execution_chunk_rows"],
    "materialization_blocked_page_hash_execution_chunk_rows": v61cn["materialization_blocked_page_hash_execution_chunk_rows"],
    "blocked_page_hash_rows": v61cn["blocked_page_hash_rows"],
    "blocked_page_hash_bytes": v61cn["blocked_page_hash_bytes"],
    "page_hash_execution_admission_ready": v61cn["page_hash_execution_admission_ready"],
    "completed_full_safetensors_page_hash_coverage_ready": v61cn["completed_full_safetensors_page_hash_coverage_ready"],
    "real_manifest_runtime_execution_admission_ready": str(runtime_execution_admission_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61co": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "real_manifest_runtime_execution_admission_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61cj-real-manifest-immediate-target-bridge-input", "status": "ready", "reason": "immediate targets are ready"},
    {"gap": "v61ci-real-manifest-runtime-substitution-input", "status": "ready", "reason": "zero-payload real manifest substitution is ready"},
    {"gap": "v61n-v61s-source-bound-qa-seed", "status": "ready", "reason": f"source_bound_query_pass_rows={source_bound_query_pass_rows}/{runtime_candidate_rows}"},
    {"gap": "v61cm-full-checkpoint-materialization", "status": "ready" if full_materialization_ready else "blocked", "reason": f"ready_checkpoint_materialization_shard_rows={v61cm['ready_checkpoint_materialization_shard_rows']}/{v61cm['checkpoint_shard_rows']}"},
    {"gap": "v61cn-page-hash-execution-admission", "status": "ready" if page_hash_admission_ready else "blocked", "reason": f"admitted_page_hash_execution_chunk_rows={v61cn['admitted_page_hash_execution_chunk_rows']}/{v61cn['remaining_page_hash_execution_chunk_rows']}"},
    {"gap": "completed-full-safetensors-page-hash-coverage", "status": "ready" if full_page_hash_ready else "blocked", "reason": f"blocked_page_hash_rows={v61cn['blocked_page_hash_rows']}"},
    {"gap": "real-manifest-runtime-execution-admission", "status": "ready" if runtime_execution_admission_ready else "blocked", "reason": f"runtime_execution_admitted_rows={runtime_admitted_rows}/{runtime_candidate_rows}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "runtime execution admission rows are not admitted"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61cj-real-manifest-immediate-target-bridge-input", "status": "pass", "reason": "v61cj immediate target bridge is ready"},
    {"gate": "v61ci-real-manifest-runtime-substitution-input", "status": "pass", "reason": "v61ci runtime substitution is ready"},
    {"gate": "v61n-v61s-source-bound-qa-seed", "status": "pass", "reason": f"source_bound_query_pass_rows={source_bound_query_pass_rows}/{runtime_candidate_rows}"},
    {"gate": "v61cm-full-checkpoint-materialization", "status": "pass" if full_materialization_ready else "blocked", "reason": f"blocked_checkpoint_materialization_shard_rows={v61cm['blocked_checkpoint_materialization_shard_rows']}"},
    {"gate": "v61cn-page-hash-execution-admission", "status": "pass" if page_hash_admission_ready else "blocked", "reason": f"materialization_blocked_page_hash_execution_chunk_rows={v61cn['materialization_blocked_page_hash_execution_chunk_rows']}"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if full_page_hash_ready else "blocked", "reason": f"blocked_page_hash_rows={v61cn['blocked_page_hash_rows']}"},
    {"gate": "real-manifest-runtime-execution-admission", "status": "pass" if runtime_execution_admission_ready else "blocked", "reason": f"runtime_execution_admitted_rows={runtime_admitted_rows}/{runtime_candidate_rows}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not external release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61co writes metadata and admission rows only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61co Real Manifest Runtime Execution Admission Bridge Boundary

This artifact binds the ready v61 real-manifest immediate targets to the
materialization and page-hash execution prerequisites required before a
source-bound QA row can become a real runtime execution row.

Evidence emitted:

- immediate_target_rows={v61cj["immediate_target_rows"]}
- ready_immediate_target_rows={v61cj["ready_immediate_target_rows"]}
- real_manifest_immediate_target_bridge_ready={v61cj["real_manifest_immediate_target_bridge_ready"]}
- logical_fixture_replaced_by_real_manifest_ready={v61ci["logical_fixture_replaced_by_real_manifest_ready"]}
- runtime_execution_candidate_rows={runtime_candidate_rows}
- runtime_execution_admitted_rows={runtime_admitted_rows}
- runtime_execution_blocked_rows={runtime_blocked_rows}
- materialization_blocked_runtime_rows={materialization_blocked_runtime_rows}
- page_hash_admission_blocked_runtime_rows={page_hash_admission_blocked_runtime_rows}
- source_bound_query_pass_rows={source_bound_query_pass_rows}/{runtime_candidate_rows}
- checkpoint_shard_rows={v61cm["checkpoint_shard_rows"]}
- ready_checkpoint_materialization_shard_rows={v61cm["ready_checkpoint_materialization_shard_rows"]}
- blocked_checkpoint_materialization_shard_rows={v61cm["blocked_checkpoint_materialization_shard_rows"]}
- promotion_missing_materialization_bytes={v61cm["promotion_missing_materialization_bytes"]}
- remaining_page_hash_execution_chunk_rows={v61cn["remaining_page_hash_execution_chunk_rows"]}
- admitted_page_hash_execution_chunk_rows={v61cn["admitted_page_hash_execution_chunk_rows"]}
- materialization_blocked_page_hash_execution_chunk_rows={v61cn["materialization_blocked_page_hash_execution_chunk_rows"]}
- blocked_page_hash_rows={v61cn["blocked_page_hash_rows"]}
- blocked_page_hash_bytes={v61cn["blocked_page_hash_bytes"]}
- real_manifest_runtime_execution_admission_ready={runtime_execution_admission_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61co=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: source-bound runtime execution admission bridge over real
zero-payload manifest evidence. Blocked wording: real Mixtral runtime execution,
actual model generation, completed full page-hash coverage, near-frontier
quality, production latency, or release readiness.
"""
(run_dir / "V61CO_REAL_MANIFEST_RUNTIME_EXECUTION_ADMISSION_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61co_real_manifest_runtime_execution_admission_bridge",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": 1,
    "v61cj_summary_sha256": sha256(results / "v61cj_real_manifest_immediate_target_bridge_summary.csv"),
    "v61ci_summary_sha256": sha256(results / "v61ci_real_manifest_runtime_substitution_gate_summary.csv"),
    "v61cm_summary_sha256": sha256(results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv"),
    "v61cn_summary_sha256": sha256(results / "v61cn_ubuntu1_page_hash_execution_materialization_admission_gate_summary.csv"),
    "v61n_summary_sha256": sha256(results / "v61n_source_bound_qa_workload_summary.csv"),
    "v61s_summary_sha256": sha256(results / "v61s_one_command_source_bound_qa_replay_summary.csv"),
    "runtime_execution_candidate_rows": runtime_candidate_rows,
    "runtime_execution_admitted_rows": runtime_admitted_rows,
    "runtime_execution_blocked_rows": runtime_blocked_rows,
    "real_manifest_runtime_execution_admission_ready": runtime_execution_admission_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61co": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61co_real_manifest_runtime_execution_admission_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61co_real_manifest_runtime_execution_admission_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
