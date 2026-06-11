#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61d_page_dequant_matmul/matmul_001"
SUMMARY_CSV="$RESULTS_DIR/v61d_page_dequant_matmul_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61d_page_dequant_matmul_decision.csv"

"$ROOT_DIR/experiments/run_v61d_page_dequant_matmul.sh" >/dev/null

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
    "v61d_page_dequant_matmul_ready": "1",
    "v61a_ssd_weight_page_store_ready": "1",
    "v61b_direct_io_page_reader_ready": "1",
    "v61c_vram_hot_cache_ready": "1",
    "ssd_resident_runtime_seed_ready": "1",
    "routehint_prefetch_plan_ready": "1",
    "tiny_moe_fixture_ready": "1",
    "no_ram_weight_residency_ready": "1",
    "route_jump_rows": "0",
    "gpu_speedup_claim": "blocked",
    "near_frontier_claim_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61d {field}: expected {value}, got {summary.get(field)}")

if int(summary["page_dequant_rows"]) < 1:
    raise SystemExit("v61d should emit page dequant rows")
if summary["numeric_check_pass_rows"] != summary["page_matmul_rows"]:
    raise SystemExit("v61d all matmul rows should pass numeric checks")
if int(summary["ssd_read_bytes_per_token"]) <= 0:
    raise SystemExit("v61d should carry a positive ssd_read_bytes_per_token")
if float(summary["tokens_per_second"]) <= 0.0:
    raise SystemExit("v61d should emit positive diagnostic tokens_per_second")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61a-page-store", "v61b-direct-io", "v61c-prefetch-cache", "v61d-page-dequant-matmul", "route-jump-invariant"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61d gate should pass: {gate}")
for gate in ["gpu-speedup-claim", "near-frontier-claim", "release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61d gate should remain blocked: {gate}")

required = [
    run_dir / "page_dequant_rows.csv",
    run_dir / "page_matmul_rows.csv",
    run_dir / "numeric_check_rows.csv",
    run_dir / "kernel_transcript_rows.csv",
    run_dir / "runtime_metric_rows.csv",
    run_dir / "V61D_PAGE_DEQUANT_MATMUL_BOUNDARY.md",
    run_dir / "sha256_manifest.csv",
    results / "v61a_ssd_weight_page_store_summary.csv",
    results / "v61b_direct_io_page_reader_summary.csv",
    results / "v61c_vram_hot_cache_summary.csv",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61d artifact: {path}")

runtime = read_csv(run_dir / "runtime_metric_rows.csv")[0]
for field in [
    "ssd_model_bytes_total",
    "ssd_pages_total",
    "ssd_pages_read",
    "ssd_read_bytes_total",
    "ssd_read_bytes_per_token",
    "nvme_read_latency_ms_p50",
    "nvme_read_latency_ms_p95",
    "prefetch_queue_depth",
    "prefetch_hit_rate",
    "prefetch_miss_ms_per_token",
    "vram_hot_cache_bytes",
    "vram_cache_hit_rate",
    "active_parameters_per_token",
    "dequant_ms_per_token",
    "matmul_ms_per_token",
    "tokens_per_second",
    "time_to_first_token_ms",
    "quality_score",
    "abstain_rate",
    "fallback_rate",
    "wrong_route_rate",
    "quant_profile_id",
    "route_jump_rows",
]:
    if field not in runtime:
        raise SystemExit(f"v61d runtime metrics missing {field}")
if runtime["route_jump_rows"] != "0":
    raise SystemExit("v61d route_jump_rows must stay zero")

numeric = read_csv(run_dir / "numeric_check_rows.csv")
if {row["numeric_check_pass"] for row in numeric} != {"1"}:
    raise SystemExit("v61d numeric checks must all pass")

manifest = json.loads((run_dir / "v61d_page_dequant_matmul_manifest.json").read_text(encoding="utf-8"))
if manifest.get("ssd_resident_runtime_seed_ready") != 1 or manifest.get("route_jump_rows") != 0:
    raise SystemExit("v61d manifest readiness mismatch")

boundary = (run_dir / "V61D_PAGE_DEQUANT_MATMUL_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in ["ssd_read_bytes_per_token", "no_ram_weight_residency_ready=1", "gpu_speedup_claim=blocked"]:
    if snippet not in boundary:
        raise SystemExit(f"v61d boundary missing {snippet}")
PY

echo "v61d page dequant matmul smoke passed"
