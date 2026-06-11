#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ac_hotset_token_budget_replay/replay_001"
SUMMARY_CSV="$RESULTS_DIR/v61ac_hotset_token_budget_replay_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ac_hotset_token_budget_replay_decision.csv"

V61AC_REUSE_EXISTING="${V61AC_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ac_hotset_token_budget_replay.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
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


def as_float(value):
    parsed = float(value)
    if not math.isfinite(parsed):
        raise SystemExit(f"nonfinite numeric field: {value}")
    return parsed


summary = read_csv(summary_csv)[0]
expected = {
    "v61ac_hotset_token_budget_replay_ready": "1",
    "v61x_hotset_runtime_replay_manifest_ready": "1",
    "v61z_hotset_direct_io_replay_ready": "1",
    "v61ab_hotset_tensor_tile_quant_probe_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "source_bound_workload_binding_rows": "37",
    "token_budget_rows": "37",
    "token_page_schedule_rows": "148",
    "token_tile_binding_rows": "1184",
    "finite_token_budget_rows": "37",
    "finite_tile_binding_rows": "1184",
    "active_page_reads_per_token": "4",
    "active_tile_probe_rows_per_token": "32",
    "tile_bf16_values_per_token": "131072",
    "ssd_read_bytes_per_token": "8388608",
    "token_direct_io_latency_ms_p50": "2.323072",
    "token_direct_io_latency_ms_p95": "3.82676",
    "q8_abs_error_budget_mean_per_token": "0.0364191354",
    "q4_abs_error_budget_mean_per_token": "0.783213501",
    "hotset_token_budget_replay_ready": "1",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ac {field}: expected {value}, got {summary.get(field)}")

for field in [
    "token_direct_io_latency_ms_p50",
    "token_direct_io_latency_ms_p95",
    "q8_abs_error_budget_mean_per_token",
    "q4_abs_error_budget_mean_per_token",
]:
    if as_float(summary[field]) < 0:
        raise SystemExit(f"v61ac field should be non-negative: {field}")

required_files = [
    "hotset_token_budget_rows.csv",
    "hotset_token_budget_page_schedule_rows.csv",
    "hotset_token_budget_tile_binding_rows.csv",
    "hotset_token_budget_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AC_HOTSET_TOKEN_BUDGET_BOUNDARY.md",
    "v61ac_hotset_token_budget_replay_manifest.json",
    "sha256_manifest.csv",
    "source_v61x/hotset_source_bound_workload_binding_rows.csv",
    "source_v61z/hotset_direct_io_read_rows.csv",
    "source_v61ab/hotset_tensor_tile_probe_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ac artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61x-source-bound-replay-binding",
    "v61z-direct-io-latency-input",
    "v61ab-numeric-tile-input",
    "hotset-token-budget-replay",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ac gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ac gate should stay blocked: {gate}")

budget_rows = read_csv(run_dir / "hotset_token_budget_rows.csv")
schedule_rows = read_csv(run_dir / "hotset_token_budget_page_schedule_rows.csv")
tile_rows = read_csv(run_dir / "hotset_token_budget_tile_binding_rows.csv")
metric = read_csv(run_dir / "hotset_token_budget_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(budget_rows) != 37:
    raise SystemExit("v61ac token budget row count mismatch")
if len(schedule_rows) != 148:
    raise SystemExit("v61ac page schedule row count mismatch")
if len(tile_rows) != 1184:
    raise SystemExit("v61ac tile binding row count mismatch")
if any(row["hotset_token_budget_replay_ready"] != "1" for row in budget_rows):
    raise SystemExit("v61ac all token budget rows should be ready")
if any(row["active_page_reads_per_token"] != "4" for row in budget_rows):
    raise SystemExit("v61ac active page count mismatch")
if any(row["active_tile_probe_rows_per_token"] != "32" for row in budget_rows):
    raise SystemExit("v61ac active tile count mismatch")
if any(row["tile_bf16_values_per_token"] != "131072" for row in budget_rows):
    raise SystemExit("v61ac tile value count mismatch")
if any(row["ssd_read_bytes_per_token"] != "8388608" for row in budget_rows):
    raise SystemExit("v61ac SSD read byte budget mismatch")
if any(row["source_bound_query_pass"] != "1" for row in budget_rows):
    raise SystemExit("v61ac all source-bound query rows should pass")
if any(row["direct_read_hash_match"] != "1" for row in schedule_rows):
    raise SystemExit("v61ac all scheduled direct reads should hash-match")
if any(row["tile_hash_bound_to_remote_page"] != "1" for row in tile_rows):
    raise SystemExit("v61ac all tile bindings should be hash-bound")
if any(row["baseline_dot_finite"] != "1" or row["q8_dot_finite"] != "1" or row["q4_dot_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61ac all bound tile dot rows should be finite")
if any(row["q8_error_finite"] != "1" or row["q4_error_finite"] != "1" for row in tile_rows):
    raise SystemExit("v61ac all bound tile error rows should be finite")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in budget_rows + schedule_rows + tile_rows):
    raise SystemExit("v61ac must not commit checkpoint payload")
if any(row["actual_model_generation_ready"] != "0" for row in budget_rows + schedule_rows + tile_rows):
    raise SystemExit("v61ac must keep generation blocked")
if any(row["production_latency_claim_ready"] != "0" for row in budget_rows + schedule_rows):
    raise SystemExit("v61ac must keep production latency blocked")

for field, value in expected.items():
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ac metric {field}: expected {value}, got {metric[field]}")
for field in [
    "full_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "actual_model_generation_ready",
    "near_frontier_claim_ready",
    "production_latency_claim_ready",
    "real_release_package_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61ac metric should keep {field}=0")

for gap in [
    "v61x-source-bound-replay-binding",
    "v61z-direct-io-latency-input",
    "v61ab-numeric-tile-input",
    "hotset-token-budget-replay",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ac gap should be ready: {gap}")
for gap in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ac gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61ac_hotset_token_budget_replay_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ac_hotset_token_budget_replay_ready") != 1:
    raise SystemExit("v61ac manifest readiness mismatch")
if manifest.get("token_budget_rows") != 37 or manifest.get("token_tile_binding_rows") != 1184:
    raise SystemExit("v61ac manifest row count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ac manifest should keep generation blocked")

boundary = (run_dir / "V61AC_HOTSET_TOKEN_BUDGET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "token_budget_rows=37",
    "token_page_schedule_rows=148",
    "token_tile_binding_rows=1184",
    "ssd_read_bytes_per_token=8388608",
    "token_direct_io_latency_ms_p50=2.323072",
    "token_direct_io_latency_ms_p95=3.82676",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ac boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ac sha256 mismatch: {rel}")
PY

echo "v61ac hotset token budget replay smoke passed"
