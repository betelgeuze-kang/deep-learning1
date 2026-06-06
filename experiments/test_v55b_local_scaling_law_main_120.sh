#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v55b_local_scaling_law_main_120/main_001"
SUMMARY_CSV="$RESULTS_DIR/v55b_local_scaling_law_main_120_summary.csv"
DECISION_CSV="$RESULTS_DIR/v55b_local_scaling_law_main_120_decision.csv"

"$ROOT_DIR/experiments/run_v55b_local_scaling_law_main_120.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

AXES = {"store_size", "top_k", "cache_budget", "routehint_budget", "query_count", "repo_count"}


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
    raise SystemExit(f"expected one v55b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v55b_local_scaling_law_main_ready": "1",
    "v55_local_scaling_law_ready": "1",
    "scaling_axis_count": "6",
    "scaling_curve_rows": "360",
    "target_scaling_curve_rows": "100",
    "missing_scaling_curve_rows": "0",
    "repo_count_axis_ready": "1",
    "repo_count_curve_rows": "60",
    "confidence_interval_ready": "1",
    "confidence_interval_rows": "120",
    "failure_case_rows_ready": "1",
    "resource_rows": "360",
    "fit_rows": "6",
    "external_network_used": "0",
    "gpu_used": "0",
    "raw_prompt_context_bytes": "0",
    "no_oracle": "1",
    "no_raw_input_extractor": "1",
    "route_memory_lineage": "1",
    "v55_contract_ready": "1",
    "gpu_speedup_claim": "deferred",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v55b {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("failure_case_rows", "0")) <= 0:
    raise SystemExit("v55b should include failure case rows")
if int(summary.get("source_files", "0")) < 12 or int(summary.get("probe_bytes", "0")) <= 0:
    raise SystemExit("v55b should bind to local source/probe evidence")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v55b-local-scaling-law-main",
    "scaling-axis-target",
    "scaling-curve-row-target",
    "repo-count-axis",
    "confidence-interval",
    "failure-case-rows",
    "resource-envelope",
    "no-oracle-no-extractor",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v55b gate should pass: {gate}")
for gate in ["gpu-speedup-claim", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v55b gate should remain blocked: {gate}")

required_files = [
    "source_manifest.csv",
    "scaling_curve_rows.csv",
    "scaling_axis_rows.csv",
    "confidence_interval_rows.csv",
    "failure_case_rows.csv",
    "resource_rows.csv",
    "scaling_fit_rows.csv",
    "resource_envelope.json",
    "V55B_LOCAL_SCALING_LAW_MAIN_BOUNDARY.md",
    "v55b_local_scaling_law_main_manifest.json",
    "sha256_manifest.csv",
    "source_v55_contract/scaling_axis_target_rows.csv",
    "source_v55_contract/scaling_fit_contract_rows.csv",
    "source_v55_contract/scaling_invariant_rows.csv",
    "source_v55_contract/V55_LOCAL_SCALING_LAW_BOUNDARY.md",
    "source_v55_contract/v55_local_scaling_law_manifest.json",
    "source_v55_contract/sha256_manifest.csv",
    "source_v55_contract/v55_local_scaling_law_main_contract_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v55b artifact: {rel}")

curve_rows = read_csv(run_dir / "scaling_curve_rows.csv")
axis_rows = read_csv(run_dir / "scaling_axis_rows.csv")
confidence_rows = read_csv(run_dir / "confidence_interval_rows.csv")
failure_rows = read_csv(run_dir / "failure_case_rows.csv")
resource_rows = read_csv(run_dir / "resource_rows.csv")
fit_rows = read_csv(run_dir / "scaling_fit_rows.csv")
if len(curve_rows) != 360 or len(resource_rows) != 360:
    raise SystemExit("v55b should write 360 curve/resource rows")
if len(confidence_rows) != 120 or len(fit_rows) != 6:
    raise SystemExit("v55b should write confidence and fit rows")
if len(failure_rows) <= 0:
    raise SystemExit("v55b should write failure rows")
axis_counts = Counter(row["axis"] for row in curve_rows)
if set(axis_counts) != AXES:
    raise SystemExit("v55b should cover all six axes")
if any(count != 60 for count in axis_counts.values()):
    raise SystemExit("v55b should write 60 rows per axis")
axis_table = {row["axis"]: row for row in axis_rows}
for axis in AXES:
    if axis_table[axis]["curve_rows"] != "60" or axis_table[axis]["unique_values"] != "20":
        raise SystemExit(f"v55b axis row mismatch: {axis}")
    if axis_table[axis]["status"] != "ready":
        raise SystemExit(f"v55b axis should be ready: {axis}")

for row in curve_rows:
    if row["no_oracle"] != "1" or row["no_raw_input_extractor"] != "1" or row["route_memory_lineage"] != "1":
        raise SystemExit("v55b curve rows should preserve invariants")
    if row["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v55b curve rows should not use raw prompt context")
    if int(row["active_bytes_per_query"]) <= 0 or float(row["query_to_evidence_latency_ms"]) <= 0:
        raise SystemExit("v55b curve rows should record positive active bytes and latency")
for row in resource_rows:
    if row["external_network_used"] != "0" or row["gpu_used"] != "0" or row["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v55b resource rows should stay local CPU/no raw prompt context")

repo_rows = sorted([row for row in curve_rows if row["axis"] == "repo_count" and row["repeat_id"] == "1"], key=lambda row: int(row["value"]))
if len(repo_rows) != 20:
    raise SystemExit("v55b repo_count axis should have 20 values")
if int(repo_rows[-1]["active_bytes_per_query"]) <= int(repo_rows[0]["active_bytes_per_query"]):
    raise SystemExit("v55b repo_count active bytes should increase")

resource = json.loads((run_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if resource.get("resource_envelope_ready") != 1 or resource.get("curve_rows") != 360 or resource.get("axis_count") != 6:
    raise SystemExit("v55b resource envelope count mismatch")
if resource.get("external_network_used") != 0 or resource.get("gpu_used") != 0 or resource.get("raw_prompt_context_bytes") != 0:
    raise SystemExit("v55b resource envelope should keep local/no-gpu/no-raw-context boundary")
if resource.get("gpu_speedup_claim") != "deferred" or resource.get("real_release_package_ready") != 0:
    raise SystemExit("v55b resource envelope claim boundary mismatch")

manifest = json.loads((run_dir / "v55b_local_scaling_law_main_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v55b_local_scaling_law_main_ready") != 1 or manifest.get("v55_local_scaling_law_ready") != 1:
    raise SystemExit("v55b manifest readiness mismatch")
if manifest.get("scaling_curve_rows") != 360 or manifest.get("repo_count_axis_ready") != 1:
    raise SystemExit("v55b manifest count mismatch")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v55b manifest should keep release blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v55b sha256 mismatch: {rel}")

boundary = (run_dir / "V55B_LOCAL_SCALING_LAW_MAIN_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "deterministic local scaling-law main run",
    "scaling_axis_count=6",
    "scaling_curve_rows=360",
    "repo_count_curve_rows=60",
    "gpu_speedup_claim=deferred",
    "Do not publish 30B-150B equivalence or release claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v55b boundary missing {snippet}")
PY

echo "v55b local scaling law main 120 smoke passed"
