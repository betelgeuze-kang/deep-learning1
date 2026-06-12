#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ci_real_manifest_runtime_substitution_gate"
RUN_ID="${V61CI_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ci_real_manifest_runtime_substitution_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61J_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61j_one_command_ssd_resident_demo.sh" >/dev/null
V61K_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61k_real_model_page_manifest.sh" >/dev/null
V61CH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ch_real_model_page_manifest_release_index.sh" >/dev/null

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

v61j_dir = results / "v61j_one_command_ssd_resident_demo" / "demo_001"
v61k_dir = results / "v61k_real_model_page_manifest" / "manifest_001"
v61ch_dir = results / "v61ch_real_model_page_manifest_release_index" / "index_001"


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


v61j = read_csv(results / "v61j_one_command_ssd_resident_demo_summary.csv")[0]
v61k = read_csv(results / "v61k_real_model_page_manifest_summary.csv")[0]
v61ch = read_csv(results / "v61ch_real_model_page_manifest_release_index_summary.csv")[0]
if v61j.get("v61j_one_command_ssd_resident_demo_ready") != "1":
    raise SystemExit("v61ci requires v61j_one_command_ssd_resident_demo_ready=1")
if v61k.get("v61k_real_model_page_manifest_ready") != "1":
    raise SystemExit("v61ci requires v61k_real_model_page_manifest_ready=1")
if v61ch.get("v61ch_real_model_page_manifest_release_index_ready") != "1":
    raise SystemExit("v61ci requires v61ch_real_model_page_manifest_release_index_ready=1")

for src, rel in [
    (results / "v61j_one_command_ssd_resident_demo_summary.csv", "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv"),
    (results / "v61j_one_command_ssd_resident_demo_decision.csv", "source_v61j/v61j_one_command_ssd_resident_demo_decision.csv"),
    (v61j_dir / "runtime_summary.csv", "source_v61j/runtime_summary.csv"),
    (v61j_dir / "ssd_vram_budget_report.csv", "source_v61j/ssd_vram_budget_report.csv"),
    (v61j_dir / "routehint_schedule_trace.csv", "source_v61j/routehint_schedule_trace.csv"),
    (v61j_dir / "sha256_manifest.csv", "source_v61j/sha256_manifest.csv"),
    (results / "v61k_real_model_page_manifest_summary.csv", "source_v61k/v61k_real_model_page_manifest_summary.csv"),
    (results / "v61k_real_model_page_manifest_decision.csv", "source_v61k/v61k_real_model_page_manifest_decision.csv"),
    (v61k_dir / "real_model_identity_rows.csv", "source_v61k/real_model_identity_rows.csv"),
    (v61k_dir / "license_redistribution_rows.csv", "source_v61k/license_redistribution_rows.csv"),
    (v61k_dir / "expert_page_budget_rows.csv", "source_v61k/expert_page_budget_rows.csv"),
    (v61k_dir / "sha256_manifest.csv", "source_v61k/sha256_manifest.csv"),
    (results / "v61ch_real_model_page_manifest_release_index_summary.csv", "source_v61ch/v61ch_real_model_page_manifest_release_index_summary.csv"),
    (results / "v61ch_real_model_page_manifest_release_index_decision.csv", "source_v61ch/v61ch_real_model_page_manifest_release_index_decision.csv"),
    (v61ch_dir / "release_index/MANIFEST_INDEX.csv", "source_v61ch/release_index/MANIFEST_INDEX.csv"),
    (v61ch_dir / "release_index/page_hash_coverage_status_rows.csv", "source_v61ch/release_index/page_hash_coverage_status_rows.csv"),
    (v61ch_dir / "release_index/generation_handoff_status_rows.csv", "source_v61ch/release_index/generation_handoff_status_rows.csv"),
    (v61ch_dir / "sha256_manifest.csv", "source_v61ch/sha256_manifest.csv"),
]:
    copy(src, rel)

runtime_summary = read_csv(v61j_dir / "runtime_summary.csv")[0]
budget_rows = read_csv(v61j_dir / "ssd_vram_budget_report.csv")
route_rows = read_csv(v61j_dir / "routehint_schedule_trace.csv")
manifest_index_rows = read_csv(v61ch_dir / "release_index/MANIFEST_INDEX.csv")
page_hash_status = read_csv(v61ch_dir / "release_index/page_hash_coverage_status_rows.csv")[0]
generation_handoff = read_csv(v61ch_dir / "release_index/generation_handoff_status_rows.csv")[0]
expert_budget_rows = {row["budget_scope"]: row for row in read_csv(v61k_dir / "expert_page_budget_rows.csv")}

logical_fixture_contract_rows = [
    {
        "contract_id": "v61j-logical-total-parameters",
        "logical_value": runtime_summary["logical_total_parameters"],
        "real_manifest_value": v61k["published_total_parameters_estimate"],
        "replacement_status": "replaced-by-real-manifest-metadata",
        "ready": "1",
    },
    {
        "contract_id": "v61j-logical-page-store",
        "logical_value": "fixture-page-store",
        "real_manifest_value": f"{v61ch['checkpoint_unique_page_rows']} safetensors-header-derived pages",
        "replacement_status": "replaced-by-zero-payload-page-index",
        "ready": "1",
    },
    {
        "contract_id": "v61j-routehint-page-ids",
        "logical_value": f"{len(route_rows)} routehint trace rows",
        "real_manifest_value": f"{v61ch['moe_layer_expert_tensor_coverage_ready_rows']} ready MoE coverage cells",
        "replacement_status": "routehint-input-space-bound-to-real-manifest",
        "ready": "1",
    },
    {
        "contract_id": "v61j-budget-contract",
        "logical_value": runtime_summary["ssd_read_bytes_per_token_max"],
        "real_manifest_value": expert_budget_rows["uncached_top2_active_q4_per_token"]["bytes"],
        "replacement_status": "substitution-ready-but-runtime-admission-blocked",
        "ready": "1",
    },
]
write_csv(run_dir / "logical_fixture_replacement_contract_rows.csv", list(logical_fixture_contract_rows[0].keys()), logical_fixture_contract_rows)

runtime_binding_rows = [
    {
        "binding_id": "ssd-page-store-input",
        "v61j_runtime_surface": "SSD page store",
        "real_manifest_surface": "v61ch release_index/checkpoint_manifest_shard_audit_rows.csv",
        "source_artifact_rows": v61ch["source_artifact_rows"],
        "runtime_substitution_ready": "1",
        "runtime_execution_ready": "0",
        "reason": "page-store input can be addressed by real shard/page metadata, but payload execution remains blocked",
    },
    {
        "binding_id": "expert-router-input",
        "v61j_runtime_surface": "logical top-k MoE router",
        "real_manifest_surface": "v61k Mixtral top-2 / 56-layer / 8-expert metadata",
        "source_artifact_rows": v61k["tensor_page_manifest_rows"],
        "runtime_substitution_ready": "1",
        "runtime_execution_ready": "0",
        "reason": "router shape is bound to real model metadata, but real weights are not executed",
    },
    {
        "binding_id": "routehint-prefetch-input",
        "v61j_runtime_surface": "RouteHint prefetch trace",
        "real_manifest_surface": "v61ch MoE coverage matrix and page-hash status",
        "source_artifact_rows": v61ch["moe_layer_expert_tensor_coverage_rows"],
        "runtime_substitution_ready": "1",
        "runtime_execution_ready": "0",
        "reason": "prefetch address space can target real manifest rows after page-hash/materialization completion",
    },
    {
        "binding_id": "page-dequant-matmul-input",
        "v61j_runtime_surface": "page dequant matmul seed",
        "real_manifest_surface": "v61k q4-or-q5 manifest hints plus v61ch zero-payload index",
        "source_artifact_rows": v61k["checkpoint_shard_manifest_rows"],
        "runtime_substitution_ready": "1",
        "runtime_execution_ready": "0",
        "reason": "numeric kernel inputs are named, but full page hashes and payload materialization remain blocked",
    },
    {
        "binding_id": "source-bound-generation-handoff",
        "v61j_runtime_surface": "one-command source-bound QA scaffold",
        "real_manifest_surface": "v61ch generation handoff status over v61cg",
        "source_artifact_rows": generation_handoff["execution_packet_rows"],
        "runtime_substitution_ready": "1",
        "runtime_execution_ready": generation_handoff["generation_operator_execution_ready"],
        "reason": "operator handoff exists, but admitted generation rows remain zero",
    },
]
write_csv(run_dir / "real_manifest_runtime_binding_rows.csv", list(runtime_binding_rows[0].keys()), runtime_binding_rows)

substitution_ready = int(
    v61j["logical_100b_moe_contract_ready"] == "1"
    and v61k["legally_redistributable_page_manifest_ready"] == "1"
    and v61ch["redistributable_manifest_index_ready"] == "1"
    and all(row["ready"] == "1" for row in logical_fixture_contract_rows)
    and all(row["runtime_substitution_ready"] == "1" for row in runtime_binding_rows)
)

requirement_rows = [
    {
        "requirement_id": "v61j-logical-runtime-scaffold-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61j["v61j_one_command_ssd_resident_demo_ready"],
        "reason": "one-command SSD-resident runtime scaffold is bound",
    },
    {
        "requirement_id": "v61k-real-100b-manifest-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61k["legally_redistributable_page_manifest_ready"],
        "reason": "real Mixtral 8x22B metadata-only manifest is bound",
    },
    {
        "requirement_id": "v61ch-zero-payload-release-index-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61ch["redistributable_manifest_index_ready"],
        "reason": "zero-payload real-model release index is bound",
    },
    {
        "requirement_id": "logical-fixture-replacement-contract",
        "status": pass_block(substitution_ready),
        "required_value": "4 contract rows and 5 binding rows ready",
        "actual_value": f"{len(logical_fixture_contract_rows)} contract rows and {len(runtime_binding_rows)} binding rows ready",
        "reason": "runtime input surfaces are mapped from logical fixture to real manifest metadata",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": pass_block(page_hash_status["completed_full_safetensors_page_hash_coverage_ready"] == "1"),
        "required_value": page_hash_status["total_required_page_hash_rows"],
        "actual_value": page_hash_status["total_verified_page_hash_rows"],
        "reason": "runtime substitution does not complete the remaining page-hash return",
    },
    {
        "requirement_id": "real-manifest-runtime-execution",
        "status": pass_block(False),
        "required_value": "admitted materialized/hash-bound runtime execution",
        "actual_value": "0",
        "reason": "this gate binds inputs only and does not execute real model weights",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": pass_block(False),
        "required_value": "accepted generation return artifacts",
        "actual_value": generation_handoff["actual_model_generation_ready"],
        "reason": "actual generation remains blocked by page-hash/review/return gates",
    },
]
write_csv(run_dir / "real_manifest_runtime_substitution_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ci_real_manifest_runtime_substitution_metrics",
    "model_id": model_id,
    "v61j_one_command_ssd_resident_demo_ready": v61j["v61j_one_command_ssd_resident_demo_ready"],
    "v61k_real_model_page_manifest_ready": v61k["v61k_real_model_page_manifest_ready"],
    "v61ch_real_model_page_manifest_release_index_ready": v61ch["v61ch_real_model_page_manifest_release_index_ready"],
    "logical_total_parameters": runtime_summary["logical_total_parameters"],
    "real_manifest_total_parameters_estimate": v61k["published_total_parameters_estimate"],
    "real_manifest_100b_plus_ready": v61k["total_parameters_100b_plus"],
    "logical_fixture_replacement_contract_rows": str(len(logical_fixture_contract_rows)),
    "runtime_substitution_binding_rows": str(len(runtime_binding_rows)),
    "logical_fixture_replaced_by_real_manifest_ready": str(substitution_ready),
    "zero_payload_runtime_input_ready": str(substitution_ready),
    "source_artifact_rows": v61ch["source_artifact_rows"],
    "release_index_file_rows": v61ch["release_index_file_rows"],
    "checkpoint_unique_page_rows": v61ch["checkpoint_unique_page_rows"],
    "checkpoint_page_segment_rows": v61ch["checkpoint_page_segment_rows"],
    "moe_layer_expert_tensor_coverage_rows": v61ch["moe_layer_expert_tensor_coverage_rows"],
    "moe_layer_expert_tensor_coverage_ready_rows": v61ch["moe_layer_expert_tensor_coverage_ready_rows"],
    "total_required_page_hash_rows": page_hash_status["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": page_hash_status["total_verified_page_hash_rows"],
    "remaining_page_hash_rows": page_hash_status["promotion_missing_page_hash_rows"],
    "completed_full_safetensors_page_hash_coverage_ready": page_hash_status["completed_full_safetensors_page_hash_coverage_ready"],
    "real_manifest_uncached_q4_bytes_per_token_estimate": expert_budget_rows["uncached_top2_active_q4_per_token"]["bytes"],
    "v61j_ssd_read_bytes_per_token_max": runtime_summary["ssd_read_bytes_per_token_max"],
    "v61j_ssd_read_budget_pass": next(row["budget_pass"] for row in budget_rows if row["budget_name"] == "ssd_read_bytes_per_token"),
    "runtime_execution_admission_ready": "0",
    "generation_operator_execution_ready": generation_handoff["generation_operator_execution_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "redistributed_checkpoint_payload_bytes": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ci": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "real_manifest_runtime_substitution_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ci_real_manifest_runtime_substitution_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61j-logical-runtime-scaffold-input", "status": "ready", "reason": "v61j one-command scaffold is bound"},
    {"gap": "v61k-real-100b-manifest-input", "status": "ready", "reason": "real Mixtral manifest is bound"},
    {"gap": "v61ch-zero-payload-release-index-input", "status": "ready", "reason": "zero-payload release index is bound"},
    {"gap": "logical-fixture-replacement-contract", "status": "ready" if substitution_ready else "blocked", "reason": "logical runtime surfaces map to real manifest metadata"},
    {"gap": "completed-full-safetensors-page-hash-coverage", "status": "ready" if page_hash_status["completed_full_safetensors_page_hash_coverage_ready"] == "1" else "blocked", "reason": f"total_verified_page_hash_rows={page_hash_status['total_verified_page_hash_rows']}/{page_hash_status['total_required_page_hash_rows']}"},
    {"gap": "real-manifest-runtime-execution", "status": "blocked", "reason": "input substitution gate is not payload execution"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "generation result artifacts are not accepted"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61j-logical-runtime-scaffold-input", "status": "pass", "reason": "v61j scaffold is bound"},
    {"gate": "v61k-real-100b-manifest-input", "status": "pass", "reason": "v61k manifest is bound"},
    {"gate": "v61ch-zero-payload-release-index-input", "status": "pass", "reason": "v61ch release index is bound"},
    {"gate": "logical-fixture-replacement-contract", "status": "pass" if substitution_ready else "blocked", "reason": "logical fixture surfaces are mapped to real manifest metadata"},
    {"gate": "zero-payload-runtime-input", "status": "pass" if substitution_ready else "blocked", "reason": "substitution uses metadata/hash/offset rows only"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if page_hash_status["completed_full_safetensors_page_hash_coverage_ready"] == "1" else "blocked", "reason": f"total_verified_page_hash_rows={page_hash_status['total_verified_page_hash_rows']}/{page_hash_status['total_required_page_hash_rows']}"},
    {"gate": "real-manifest-runtime-execution", "status": "blocked", "reason": "no materialized hash-bound full-runtime execution"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ci Real Manifest Runtime Substitution Gate Boundary

This artifact binds the v61j logical runtime scaffold to the v61k/v61ch real
Mixtral zero-payload page manifest. It replaces the logical fixture as a runtime
input contract, but it does not execute checkpoint payload bytes.

Evidence emitted:

- logical_total_parameters={runtime_summary["logical_total_parameters"]}
- real_manifest_total_parameters_estimate={v61k["published_total_parameters_estimate"]}
- logical_fixture_replacement_contract_rows={len(logical_fixture_contract_rows)}
- runtime_substitution_binding_rows={len(runtime_binding_rows)}
- logical_fixture_replaced_by_real_manifest_ready={substitution_ready}
- zero_payload_runtime_input_ready={substitution_ready}
- checkpoint_unique_page_rows={v61ch["checkpoint_unique_page_rows"]}
- checkpoint_page_segment_rows={v61ch["checkpoint_page_segment_rows"]}
- moe_layer_expert_tensor_coverage_ready_rows={v61ch["moe_layer_expert_tensor_coverage_ready_rows"]}
- total_verified_page_hash_rows={page_hash_status["total_verified_page_hash_rows"]}
- remaining_page_hash_rows={page_hash_status["promotion_missing_page_hash_rows"]}
- completed_full_safetensors_page_hash_coverage_ready={page_hash_status["completed_full_safetensors_page_hash_coverage_ready"]}
- runtime_execution_admission_ready=0
- actual_model_generation_ready=0
- redistributed_checkpoint_payload_bytes=0
- checkpoint_payload_bytes_downloaded_by_v61ci=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: logical fixture replaced by real zero-payload manifest input,
runtime substitution contract, and metadata/hash/offset runtime binding.
Blocked wording: completed full safetensors page-hash coverage, real Mixtral
runtime execution, actual model generation, near-frontier quality, production
latency, or real release package.
"""
(run_dir / "V61CI_REAL_MANIFEST_RUNTIME_SUBSTITUTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ci_real_manifest_runtime_substitution_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ci_real_manifest_runtime_substitution_gate_ready": 1,
    "v61j_summary_sha256": sha256(results / "v61j_one_command_ssd_resident_demo_summary.csv"),
    "v61k_summary_sha256": sha256(results / "v61k_real_model_page_manifest_summary.csv"),
    "v61ch_summary_sha256": sha256(results / "v61ch_real_model_page_manifest_release_index_summary.csv"),
    "logical_fixture_replacement_contract_rows": len(logical_fixture_contract_rows),
    "runtime_substitution_binding_rows": len(runtime_binding_rows),
    "logical_fixture_replaced_by_real_manifest_ready": substitution_ready,
    "zero_payload_runtime_input_ready": substitution_ready,
    "checkpoint_unique_page_rows": int(v61ch["checkpoint_unique_page_rows"]),
    "checkpoint_page_segment_rows": int(v61ch["checkpoint_page_segment_rows"]),
    "total_verified_page_hash_rows": int(page_hash_status["total_verified_page_hash_rows"]),
    "remaining_page_hash_rows": int(page_hash_status["promotion_missing_page_hash_rows"]),
    "runtime_execution_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "redistributed_checkpoint_payload_bytes": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ci": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61ci_real_manifest_runtime_substitution_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ci_real_manifest_runtime_substitution_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
