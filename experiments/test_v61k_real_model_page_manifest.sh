#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61k_real_model_page_manifest/manifest_001"
SUMMARY_CSV="$RESULTS_DIR/v61k_real_model_page_manifest_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61k_real_model_page_manifest_decision.csv"

"$ROOT_DIR/experiments/run_v61k_real_model_page_manifest.sh" >/dev/null

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
    "v61k_real_model_page_manifest_ready": "1",
    "real_model_page_manifest_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_model_license": "apache-2.0",
    "total_parameters_100b_plus": "1",
    "num_hidden_layers": "56",
    "num_local_experts": "8",
    "num_experts_per_tok": "2",
    "checkpoint_shard_manifest_rows": "59",
    "tensor_page_manifest_rows": "129024",
    "legally_redistributable_page_manifest_ready": "1",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "active_uncached_q4_budget_pass": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61k {field}: expected {value}, got {summary.get(field)}")

if int(summary["active_uncached_q4_bytes_per_token_estimate"]) <= int(summary["ssd_read_budget_bytes_per_token"]):
    raise SystemExit("v61k uncached q4 active path should remain over budget")

required = [
    run_dir / "real_model_identity_rows.csv",
    run_dir / "real_model_source_rows.csv",
    run_dir / "real_model_config_rows.csv",
    run_dir / "license_redistribution_rows.csv",
    run_dir / "checkpoint_shard_manifest_rows.csv",
    run_dir / "tensor_page_manifest_rows.csv",
    run_dir / "expert_page_budget_rows.csv",
    run_dir / "runtime_gap_rows.csv",
    run_dir / "V61K_REAL_MODEL_PAGE_MANIFEST_BOUNDARY.md",
    run_dir / "sha256_manifest.csv",
    results / "v61j_one_command_ssd_resident_demo_summary.csv",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61k artifact: {path}")

identity = read_csv(run_dir / "real_model_identity_rows.csv")[0]
if identity["real_open_weight_moe"] != "1" or identity["real_checkpoint_weight_bytes_materialized"] != "0":
    raise SystemExit("v61k identity should bind a real MoE model without materializing weights")

license_rows = read_csv(run_dir / "license_redistribution_rows.csv")
if license_rows[0]["page_manifest_redistributable"] != "1" or license_rows[0]["weights_redistributed"] != "0":
    raise SystemExit("v61k should redistribute page metadata only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["real-open-weight-moe-identity", "legally-redistributable-page-manifest", "tensor-page-enumeration", "100b-plus-direction"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61k gate should pass: {gate}")
for gate in ["real-checkpoint-weight-materialization", "uncached-runtime-budget", "gpu-kernel-measurement", "kv-cache-policy", "source-bound-qa", "near-frontier-quality", "release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61k gate should remain blocked: {gate}")

manifest = json.loads((run_dir / "v61k_real_model_page_manifest_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61k_real_model_page_manifest_ready") != 1 or manifest.get("real_checkpoint_weight_bytes_materialized") != 0:
    raise SystemExit("v61k manifest readiness mismatch")

with (run_dir / "tensor_page_manifest_rows.csv").open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 129024:
    raise SystemExit(f"v61k tensor page row count mismatch: {len(rows)}")
for field in ["page_id", "source_tensor_pattern", "weight_bytes_included", "page_hash_verified"]:
    if field not in rows[0]:
        raise SystemExit(f"v61k tensor page rows missing {field}")
if {rows[0]["weight_bytes_included"], rows[-1]["weight_bytes_included"]} != {"0"}:
    raise SystemExit("v61k tensor manifest must not include weights")
PY

echo "v61k real-model page manifest smoke passed"
