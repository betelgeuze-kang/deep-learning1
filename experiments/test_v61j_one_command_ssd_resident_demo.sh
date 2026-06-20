#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61j_one_command_ssd_resident_demo/demo_001"
SUMMARY_CSV="$RESULTS_DIR/v61j_one_command_ssd_resident_demo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61j_one_command_ssd_resident_demo_decision.csv"

"$ROOT_DIR/examples/v61_ssd_resident_moe_demo.sh" >/dev/null

python3 - "$RESULTS_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

results = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61a_ssd_weight_page_store_ready": "1",
    "v61b_direct_io_page_reader_ready": "1",
    "v61c_vram_hot_cache_ready": "1",
    "v61d_page_dequant_matmul_ready": "1",
    "v61e_expert_router_ready": "1",
    "v61f_predictive_prefetch_ready": "1",
    "v61g_mixed_quant_planner_ready": "1",
    "v61h_dense_stress_harness_ready": "1",
    "v61i_logical_100b_contract_fixture_ready": "1",
    "v61j_one_command_ssd_resident_demo_ready": "1",
    "one_command_entrypoint_ready": "1",
    "ssd_resident_active_sparse_path_proven": "1",
    "ram_resident_full_model_fallback_rows": "0",
    "logical_100b_moe_contract_ready": "1",
    "logical_100b_contract_fixture_ready": "1",
    "real_100b_inference_ready": "0",
    "contract_ready": "1",
    "fixture_execution_ready": "1",
    "real_model_execution_ready": "0",
    "heldout_metric_ready": "0",
    "human_review_ready": "0",
    "independent_reproduction_ready": "0",
    "release_ready": "0",
    "real_100b_open_weight_materialized": "0",
    "near_frontier_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61j {field}: expected {value}, got {summary.get(field)}")

required = [
    run_dir / "runtime_summary.csv",
    run_dir / "ssd_vram_budget_report.csv",
    run_dir / "routehint_schedule_trace.csv",
    run_dir / "quality_fallback_report.csv",
    run_dir / "source_v61i" / "moe_readiness_semantic_rows.csv",
    run_dir / "V61J_ONE_COMMAND_SSD_RESIDENT_DEMO_BOUNDARY.md",
    run_dir / "sha256_manifest.csv",
    results / "v61h_dense_stress_harness_summary.csv",
    results / "v61i_100b_moe_active_sparse_run_summary.csv",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61j artifact: {path}")

budget_rows = read_csv(run_dir / "ssd_vram_budget_report.csv")
if {row["budget_pass"] for row in budget_rows} != {"1"}:
    raise SystemExit("v61j all SSD/VRAM budget rows should pass")
if any(row["budget_name"] == "ram_resident_full_model_fallback_rows" and row["measured_value"] != "0" for row in budget_rows):
    raise SystemExit("v61j must not allow RAM full-model fallback")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["one-command-entrypoint", "ssd-resident-active-sparse-path", "no-ram-full-model-fallback"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61j gate should pass: {gate}")
for gate in ["real-100b-materialization", "near-frontier-quality", "release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61j gate should remain blocked: {gate}")

v61h = read_csv(results / "v61h_dense_stress_harness_summary.csv")[0]
if v61h.get("dense_hundreds_b_local_speed_claim") != "blocked":
    raise SystemExit("v61h dense hundreds-B speed claim must stay blocked")
v61i = read_csv(results / "v61i_100b_moe_active_sparse_run_summary.csv")[0]
if v61i.get("total_parameters_100b_plus") != "1" or v61i.get("real_100b_open_weight_materialized") != "0":
    raise SystemExit("v61i should close logical 100B+ contract while blocking real checkpoint materialization")
if v61i.get("v61i_100b_moe_active_sparse_run_ready") != "0" or v61i.get("v61i_logical_100b_contract_fixture_ready") != "1":
    raise SystemExit("v61i should keep the deprecated ambiguous ready flag closed and expose the typed fixture replacement")
if v61i.get("logical_100b_contract_fixture_ready") != "1" or v61i.get("real_100b_inference_ready") != "0":
    raise SystemExit("v61i should expose typed logical fixture readiness and block real 100B inference")
for field, value in {
    "contract_ready": "1",
    "fixture_execution_ready": "1",
    "real_model_execution_ready": "0",
    "heldout_metric_ready": "0",
    "human_review_ready": "0",
    "independent_reproduction_ready": "0",
    "release_ready": "0",
}.items():
    if v61i.get(field) != value:
        raise SystemExit(f"v61i typed readiness {field}: expected {value}, got {v61i.get(field)}")

readiness_rows = read_csv(run_dir / "source_v61i" / "moe_readiness_semantic_rows.csv")
if len(readiness_rows) != 1:
    raise SystemExit("v61j should copy one v61i readiness semantic row")
readiness = readiness_rows[0]
if readiness.get("deprecated_or_ambiguous_ready_flag") != "v61i_100b_moe_active_sparse_run_ready=0":
    raise SystemExit("v61i readiness row should keep the deprecated ambiguous ready flag closed")
if readiness.get("logical_100b_contract_fixture_ready") != "1" or readiness.get("real_100b_inference_ready") != "0":
    raise SystemExit("v61i readiness row should separate logical fixture from real inference")

manifest = json.loads((run_dir / "v61j_one_command_ssd_resident_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("ssd_resident_active_sparse_path_proven") != 1 or manifest.get("ram_resident_full_model_fallback_rows") != 0:
    raise SystemExit("v61j manifest readiness mismatch")
if manifest.get("logical_100b_contract_fixture_ready") != 1 or manifest.get("real_100b_inference_ready") != 0:
    raise SystemExit("v61j manifest should preserve typed 100B readiness")
if manifest.get("real_model_execution_ready") != 0 or manifest.get("release_ready") != 0:
    raise SystemExit("v61j manifest should block real model execution and release readiness")
PY

echo "v61j one-command SSD-resident demo smoke passed"
