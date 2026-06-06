#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v55_local_scaling_law_main_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v55_local_scaling_law_main_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v55_local_scaling_law_main_contract_decision.csv"

"$ROOT_DIR/experiments/run_v55_local_scaling_law_main_contract.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
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

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v55 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v55_local_scaling_law_contract_ready": "1",
    "v55_local_scaling_law_ready": "0",
    "target_scaling_axis_count": "6",
    "seed_scaling_axis_count": "5",
    "target_scaling_curve_rows": "100",
    "seed_scaling_curve_rows": "27",
    "missing_scaling_curve_rows": "73",
    "repo_count_axis_ready": "0",
    "store_size_axis_ready": "1",
    "query_count_axis_ready": "1",
    "resource_envelope_bound": "1",
    "claim_boundary_written": "1",
    "confidence_interval_ready": "0",
    "failure_case_rows_ready": "0",
    "real_release_package_ready": "0",
    "gpu_speedup_claim": "deferred",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v55 {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v55-local-scaling-law-contract", "v51-seed-scaling-matrix"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v55 gate should pass: {gate}")
for gate in ["scaling-axis-target", "scaling-curve-row-target", "repo-count-axis", "confidence-interval", "failure-case-rows", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v55 gate should remain blocked: {gate}")

required_files = [
    "scaling_axis_target_rows.csv",
    "scaling_fit_contract_rows.csv",
    "scaling_invariant_rows.csv",
    "V55_LOCAL_SCALING_LAW_BOUNDARY.md",
    "v55_local_scaling_law_manifest.json",
    "sha256_manifest.csv",
    "source_v51/source_manifest.csv",
    "source_v51/measured_source_probe.csv",
    "source_v51/store_size_curve.csv",
    "source_v51/topk_curve.csv",
    "source_v51/cache_budget_curve.csv",
    "source_v51/routehint_budget_curve.csv",
    "source_v51/query_count_curve.csv",
    "source_v51/active_bytes_per_query.csv",
    "source_v51/latency_breakdown.csv",
    "source_v51/resource_envelope.json",
    "source_v51/claim_boundary.md",
    "source_v51/scaling_summary.md",
    "source_v51/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v55 artifact: {rel}")

axis_rows = read_csv(run_dir / "scaling_axis_target_rows.csv")
if len(axis_rows) != 6:
    raise SystemExit("v55 axis contract should cover six axes")
by_axis = {row["axis"]: row for row in axis_rows}
for axis in ["store_size", "top_k", "cache_budget", "routehint_budget", "query_count", "repo_count"]:
    if axis not in by_axis:
        raise SystemExit(f"v55 axis contract missing {axis}")
if by_axis["repo_count"]["seed_curve_rows"] != "0" or by_axis["repo_count"]["status"] != "missing-main-run":
    raise SystemExit("v55 repo_count axis should remain missing")
if sum(int(row["target_curve_rows"]) for row in axis_rows) != 100:
    raise SystemExit("v55 axis target rows should sum to 100")
if sum(int(row["seed_curve_rows"]) for row in axis_rows) != 27:
    raise SystemExit("v55 seed curve rows should sum to 27")

fit_rows = read_csv(run_dir / "scaling_fit_contract_rows.csv")
fit_axes = {row["fit_axis"] for row in fit_rows}
for axis in ["active_bytes_per_query", "query_to_evidence_latency", "query_to_first_token_latency", "memory_envelope", "storage_read_envelope", "cache_hit_rate", "failure_cases", "confidence_interval"]:
    if axis not in fit_axes:
        raise SystemExit(f"v55 fit contract missing {axis}")

invariants = read_csv(run_dir / "scaling_invariant_rows.csv")
if len(invariants) != 6 or any(row["status"] != "pass" for row in invariants):
    raise SystemExit("v55 invariants should all pass on v51 seed")
by_inv = {row["invariant"]: row for row in invariants}
if by_inv["gpu_speedup_claim"]["observed_value"] != "deferred":
    raise SystemExit("v55 should keep GPU claim deferred")

manifest = json.loads((run_dir / "v55_local_scaling_law_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v55_local_scaling_law_contract_ready") != 1 or manifest.get("v55_local_scaling_law_ready") != 0:
    raise SystemExit("v55 manifest readiness boundary mismatch")
if manifest.get("missing_scaling_curve_rows") != 73 or manifest.get("repo_count_axis_ready") != 0:
    raise SystemExit("v55 manifest missing-count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v55 sha256 mismatch: {rel}")

boundary = (run_dir / "V55_LOCAL_SCALING_LAW_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed scaling law",
    "repo_count axis",
    "missing_scaling_curve_rows=73",
    "confidence intervals",
    "Do not publish v55 scaling-law claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v55 boundary missing {snippet}")
PY

echo "v55 local scaling law main contract smoke passed"
