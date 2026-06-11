#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ae_real_generation_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61ae_real_generation_admission_gate_summary.csv"
TARGET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61ae-warehouse-override.XXXXXX")"

cleanup() {
  rm -rf "$TARGET_DIR"
  V61P_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61p_local_ssd_checkpoint_residency_preflight.sh" >/dev/null || true
  V61R_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null || true
  V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null || true
  V61W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null || true
  V61AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ae_real_generation_admission_gate.sh" >/dev/null || true
}
trap cleanup EXIT

V61AE_REUSE_EXISTING=1 V61AE_WAREHOUSE_ROOT="$TARGET_DIR" "$ROOT_DIR/experiments/run_v61ae_real_generation_admission_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$TARGET_DIR" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
target_dir = Path(sys.argv[3]).resolve()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
source_v61r_summary = read_csv(run_dir / "source_v61r" / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
source_v61t_summary = read_csv(run_dir / "source_v61t" / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
source_v61w_summary = read_csv(run_dir / "source_v61w" / "v61w_materialization_admission_resume_plan_summary.csv")[0]
candidate_rows = read_csv(run_dir / "real_generation_candidate_rows.csv")
metric = read_csv(run_dir / "real_generation_admission_metric_rows.csv")[0]

expected = {
    "v61ae_real_generation_admission_gate_ready": "1",
    "warehouse_root_override_supplied": "1",
    "generation_candidate_rows": "1000",
    "generation_admitted_rows": "0",
    "materialization_admission_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ae override {field}: expected {value}, got {summary.get(field)}")

for name, source_summary in [
    ("v61r", source_v61r_summary),
    ("v61t", source_v61t_summary),
    ("v61w", source_v61w_summary),
]:
    if source_summary["warehouse_root_override_supplied"] != "1":
        raise SystemExit(f"v61ae override did not force fresh {name} planning")
    if Path(source_summary["ssd_warehouse_path"]) != target_dir:
        raise SystemExit(f"v61ae override {name} warehouse path mismatch")

if metric["warehouse_root_override_supplied"] != "1":
    raise SystemExit("v61ae override metric should record warehouse override")
if len(candidate_rows) != 1000:
    raise SystemExit("v61ae override candidate row count mismatch")
if any(row["generation_admitted"] != "0" for row in candidate_rows):
    raise SystemExit("v61ae override must not admit generation rows")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in candidate_rows):
    raise SystemExit("v61ae override must not commit checkpoint payload bytes")
PY

echo "v61ae real generation admission gate target override smoke passed"
