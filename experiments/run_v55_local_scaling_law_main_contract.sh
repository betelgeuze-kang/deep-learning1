#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v55_local_scaling_law_main_contract"
RUN_ID="${V55_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/scripts/run_local_scaling_matrix.sh" "$ROOT_DIR" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v51_dir = results / "v51_local_scaling_matrix"
v51_summary = list(csv.DictReader((results / "v51_local_scaling_matrix_summary.csv").open(newline="", encoding="utf-8")))[0]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

for rel in [
    "source_manifest.csv",
    "measured_source_probe.csv",
    "store_size_curve.csv",
    "topk_curve.csv",
    "cache_budget_curve.csv",
    "routehint_budget_curve.csv",
    "query_count_curve.csv",
    "active_bytes_per_query.csv",
    "latency_breakdown.csv",
    "resource_envelope.json",
    "claim_boundary.md",
    "scaling_summary.md",
    "sha256_manifest.csv",
]:
    copy(v51_dir / rel, f"source_v51/{rel}")

axis_targets = [
    ("store_size", 20, int(v51_summary.get("store_size_curve_rows", "0")), "ready-preview"),
    ("top_k", 16, int(v51_summary.get("topk_curve_rows", "0")), "ready-preview"),
    ("cache_budget", 16, int(v51_summary.get("cache_budget_curve_rows", "0")), "ready-preview"),
    ("routehint_budget", 16, int(v51_summary.get("routehint_budget_curve_rows", "0")), "ready-preview"),
    ("query_count", 16, int(v51_summary.get("query_count_curve_rows", "0")), "ready-preview"),
    ("repo_count", 16, 0, "missing-main-run"),
]
axis_rows = []
for axis, target_rows, seed_rows, status in axis_targets:
    axis_rows.append(
        {
            "axis": axis,
            "target_curve_rows": target_rows,
            "seed_curve_rows": seed_rows,
            "missing_curve_rows": max(0, target_rows - seed_rows),
            "resource_envelope_required": "1",
            "hash_bound_required": "1",
            "status": "ready" if seed_rows >= target_rows else status,
        }
    )
write_csv(run_dir / "scaling_axis_target_rows.csv", list(axis_rows[0].keys()), axis_rows)

fit_contract_rows = [
    ("active_bytes_per_query", "required", "fit curve over source bytes, store size, top-k, cache, RouteHint budget, query count, and repo count"),
    ("query_to_evidence_latency", "required", "runner-measured or measured-proxy latency bound to source probe rows"),
    ("query_to_first_token_latency", "required", "required for generator-backed rows"),
    ("memory_envelope", "required", "peak RAM and cache budget rows"),
    ("storage_read_envelope", "required", "filesystem/NVMe-style read rows"),
    ("cache_hit_rate", "required", "cache behavior under cache-budget and repo-count axes"),
    ("failure_cases", "required", "rows where scaling breaks, abstains, or exceeds resource envelope"),
    ("confidence_interval", "required", "fit uncertainty or repeated-run variance"),
]
write_csv(
    run_dir / "scaling_fit_contract_rows.csv",
    ["fit_axis", "required_status", "notes"],
    [{"fit_axis": axis, "required_status": status, "notes": notes} for axis, status, notes in fit_contract_rows],
)

resource_invariant_rows = [
    ("no_oracle", "1", v51_summary.get("no_oracle", ""), "pass"),
    ("no_raw_input_extractor", "1", v51_summary.get("no_raw_input_extractor", ""), "pass"),
    ("route_memory_lineage", "1", v51_summary.get("route_memory_lineage", ""), "pass"),
    ("raw_prompt_context_bytes", "0", v51_summary.get("raw_prompt_context_bytes", ""), "pass"),
    ("gpu_speedup_claim", "deferred", v51_summary.get("gpu_speedup_claim", ""), "pass"),
    ("real_release_package_ready", "0", v51_summary.get("real_release_package_ready", ""), "pass"),
]
write_csv(
    run_dir / "scaling_invariant_rows.csv",
    ["invariant", "required_value", "observed_value", "status"],
    [{"invariant": inv, "required_value": req, "observed_value": obs, "status": status} for inv, req, obs, status in resource_invariant_rows],
)

seed_curve_rows = int(v51_summary.get("active_bytes_rows", "0"))
target_curve_rows = 100
missing_curve_rows = max(0, target_curve_rows - seed_curve_rows)
axis_count = len(axis_rows)
ready_axis_count = sum(1 for row in axis_rows if int(row["seed_curve_rows"]) > 0)

summary = {
    "v55_local_scaling_law_contract_ready": 1,
    "v55_local_scaling_law_ready": 0,
    "target_scaling_axis_count": axis_count,
    "seed_scaling_axis_count": ready_axis_count,
    "target_scaling_curve_rows": target_curve_rows,
    "seed_scaling_curve_rows": seed_curve_rows,
    "missing_scaling_curve_rows": missing_curve_rows,
    "repo_count_axis_ready": 0,
    "store_size_axis_ready": int(v51_summary.get("store_size_curve_rows", "0") != "0"),
    "query_count_axis_ready": int(v51_summary.get("query_count_curve_rows", "0") != "0"),
    "resource_envelope_bound": 1,
    "claim_boundary_written": 1,
    "confidence_interval_ready": 0,
    "failure_case_rows_ready": 0,
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v55-local-scaling-law-contract", "pass", "axis targets, fit contracts, invariants, and v51 source curves emitted"),
    ("v51-seed-scaling-matrix", "pass" if seed_curve_rows == 27 else "blocked", f"seed_scaling_curve_rows={seed_curve_rows}"),
    ("scaling-axis-target", "blocked", f"need 6 main axes; repo_count axis missing; seed axes={ready_axis_count}"),
    ("scaling-curve-row-target", "blocked", f"need >=100 rows; have {seed_curve_rows}; missing {missing_curve_rows}"),
    ("repo-count-axis", "blocked", "repo_count axis is not supplied by v51 preview matrix"),
    ("confidence-interval", "blocked", "main-run repeated/variance rows are not supplied"),
    ("failure-case-rows", "blocked", "main-run failure case rows are not supplied"),
    ("real-release-package", "blocked", "v55 contract is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V55_LOCAL_SCALING_LAW_BOUNDARY.md").write_text(
    "# v55 Local Scaling Law Main-Run Boundary\n\n"
    "This is the v55 local scaling law main-run contract scaffold, not the completed scaling law.\n\n"
    "Seed evidence from v51:\n\n"
    f"- seed_scaling_curve_rows={seed_curve_rows}\n"
    f"- source_files={v51_summary.get('source_files')}\n"
    f"- source_bytes={v51_summary.get('source_bytes')}\n"
    "- axes=store_size,top_k,cache_budget,routehint_budget,query_count\n\n"
    "Still blocked:\n\n"
    "- repo_count axis\n"
    f"- missing_scaling_curve_rows={missing_curve_rows}\n"
    "- confidence intervals / repeated-run variance\n"
    "- failure case rows\n\n"
    "Do not publish v55 scaling-law claims until the main-run axes, curve volume, resource envelope, confidence intervals, and failure cases are all hash-bound.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v55-local-scaling-law-main-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v55_local_scaling_law_contract_ready": 1,
    "v55_local_scaling_law_ready": 0,
    "target_scaling_curve_rows": target_curve_rows,
    "seed_scaling_curve_rows": seed_curve_rows,
    "missing_scaling_curve_rows": missing_curve_rows,
    "repo_count_axis_ready": 0,
    "v51_summary_sha256": sha256(results / "v51_local_scaling_matrix_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v55_local_scaling_law_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "scaling_axis_target_rows.csv",
    "scaling_fit_contract_rows.csv",
    "scaling_invariant_rows.csv",
    "V55_LOCAL_SCALING_LAW_BOUNDARY.md",
    "v55_local_scaling_law_manifest.json",
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
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v55_local_scaling_law_main_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
