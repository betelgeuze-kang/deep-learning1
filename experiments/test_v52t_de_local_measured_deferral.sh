#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52t_de_local_measured_deferral/deferral_001"
SUMMARY_CSV="$RESULTS_DIR/v52t_de_local_measured_deferral_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52t_de_local_measured_deferral_decision.csv"

"$ROOT_DIR/experiments/run_v52t_de_local_measured_deferral.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v52t_de_local_measured_deferral_ready": "1",
    "local_de_measured_status": "deferred-with-reason",
    "deferred_systems": "D/E",
    "aborted_local_run_rows": "1",
    "v52s_weight_tier_contract_ready": "1",
    "weight_tier_mmap_reader_ready": "1",
    "rocm_kernel_bind_ready": "1",
    "weight_tier_runtime_ready": "0",
    "d_30b_supplied_evidence_ready": "0",
    "e_70b_supplied_evidence_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52t {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "de-local-measured-deferral",
    "v52s-weight-tier-contract-linked",
    "v52u-mmap-reader-linked",
    "v52v-rocm-bind-linked",
    "v52d-intake-still-valid",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52t gate should pass: {gate}")
for gate in ["30b-llm-rag-real-row", "70b-llm-rag-real-row", "v52-de-absorb-ready", "v52-full-baseline-war"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52t gate should remain blocked: {gate}")

deferrals = read_csv(run_dir / "de_local_measured_deferral_rows.csv")
if len(deferrals) != 2 or {row["system_id"] for row in deferrals} != {"D", "E"}:
    raise SystemExit("v52t should defer D and E")
if {row["local_measured_status"] for row in deferrals} != {"deferred-with-reason"}:
    raise SystemExit("v52t deferral status mismatch")

aborted = read_csv(run_dir / "aborted_local_run_rows.csv")[0]
if aborted.get("experiment") != "v52n_30b_open_weight_llm_rag_measured_seed":
    raise SystemExit("v52t should record v52n abort")

manifest = json.loads((run_dir / "v52t_de_local_measured_deferral_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52t_de_local_measured_deferral_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52t manifest readiness mismatch")

boundary = (run_dir / "V52T_DE_LOCAL_MEASURED_DEFERRAL_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "deferred-with-reason",
    "v52s_weight_tier_contract_ready=1",
    "weight_tier_mmap_reader_ready=1",
    "rocm_kernel_bind_ready=1",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52t boundary missing {snippet}")
PY

echo "v52t D/E local measured deferral smoke passed"
