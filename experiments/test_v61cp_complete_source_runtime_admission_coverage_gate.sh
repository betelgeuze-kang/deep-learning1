#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cp_complete_source_runtime_admission_coverage_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61cp_complete_source_runtime_admission_coverage_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cp_complete_source_runtime_admission_coverage_gate_decision.csv"

V61CP_REUSE_EXISTING="${V61CP_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cp_complete_source_runtime_admission_coverage_gate.sh" >/dev/null

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


summary = read_csv(summary_csv)[0]
expected = {
    "v61cp_complete_source_runtime_admission_coverage_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": "1",
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": "1",
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": "1",
    "complete_source_query_rows": "1000",
    "source_bound_seed_runtime_candidate_rows": "37",
    "source_bound_seed_query_pass_rows": "37",
    "direct_query_overlap_rows": "0",
    "runtime_seed_covered_complete_source_rows": "0",
    "runtime_seed_uncovered_complete_source_rows": "1000",
    "runtime_seed_admitted_complete_source_rows": "0",
    "complete_source_runtime_execution_admitted_rows": "0",
    "complete_source_runtime_execution_blocked_rows": "1000",
    "complete_source_runtime_admission_coverage_ready": "0",
    "real_manifest_runtime_execution_admission_ready": "0",
    "generation_execution_admitted_rows": "0",
    "blocked_execution_rows": "1000",
    "page_hash_blocked_rows": "1000",
    "review_return_blocked_rows": "1000",
    "generation_result_artifact_blocked_rows": "1000",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cp {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_runtime_admission_coverage_rows.csv",
    "complete_source_runtime_admission_coverage_requirement_rows.csv",
    "complete_source_runtime_admission_coverage_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CP_COMPLETE_SOURCE_RUNTIME_ADMISSION_COVERAGE_GATE_BOUNDARY.md",
    "v61cp_complete_source_runtime_admission_coverage_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61co/real_manifest_runtime_execution_admission_rows.csv",
    "source_v61cf/source_bound_generation_execution_packet_rows.csv",
    "source_v61cf/source_bound_generation_return_manifest_rows.csv",
    "source_v61cc/page_hash_generation_admission_bridge_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cp artifact: {rel}")

coverage_rows = read_csv(run_dir / "complete_source_runtime_admission_coverage_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_runtime_admission_coverage_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_runtime_admission_coverage_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(coverage_rows) != 1000:
    raise SystemExit("v61cp coverage row count mismatch")
if any(row["has_direct_v61co_seed_runtime_row"] != "0" for row in coverage_rows):
    raise SystemExit("v61cp default complete-source rows should have no direct v61co seed coverage")
if any(row["complete_source_runtime_execution_admitted"] != "0" for row in coverage_rows):
    raise SystemExit("v61cp must not admit complete-source runtime execution rows")
if {row["runtime_admission_coverage_status"] for row in coverage_rows} != {"blocked-no-direct-v61co-seed-runtime-coverage"}:
    raise SystemExit("v61cp coverage status mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cp"] != "0" for row in coverage_rows):
    raise SystemExit("v61cp must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in coverage_rows):
    raise SystemExit("v61cp must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in coverage_rows):
    raise SystemExit("v61cp route jumps must stay zero")

for requirement_id in [
    "v61co-seed-runtime-admission-input",
    "v61cf-complete-source-generation-packet-input",
    "v61cc-complete-source-generation-admission-input",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cp requirement should pass: {requirement_id}")
for requirement_id in [
    "complete-source-runtime-seed-coverage",
    "complete-source-runtime-execution-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cp requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cp_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cp metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61co-seed-runtime-admission-input",
    "v61cf-complete-source-generation-packet-input",
    "v61cc-complete-source-generation-admission-input",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cp gate should pass: {gate}")
for gate in [
    "complete-source-runtime-seed-coverage",
    "complete-source-runtime-execution-admission",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cp gate should stay blocked: {gate}")

for gap in [
    "v61co-seed-runtime-admission-input",
    "v61cf-complete-source-generation-packet-input",
    "v61cc-complete-source-generation-admission-input",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cp gap should be ready: {gap}")
for gap in [
    "complete-source-runtime-seed-coverage",
    "complete-source-runtime-execution-admission",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cp gap should stay blocked: {gap}")

boundary = (run_dir / "V61CP_COMPLETE_SOURCE_RUNTIME_ADMISSION_COVERAGE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete_source_query_rows=1000",
    "source_bound_seed_runtime_candidate_rows=37",
    "source_bound_seed_query_pass_rows=37",
    "direct_query_overlap_rows=0",
    "runtime_seed_covered_complete_source_rows=0",
    "runtime_seed_uncovered_complete_source_rows=1000",
    "runtime_seed_admitted_complete_source_rows=0",
    "complete_source_runtime_execution_admitted_rows=0",
    "complete_source_runtime_execution_blocked_rows=1000",
    "complete_source_runtime_admission_coverage_ready=0",
    "real_manifest_runtime_execution_admission_ready=0",
    "page_hash_blocked_rows=1000",
    "review_return_blocked_rows=1000",
    "generation_result_artifact_blocked_rows=1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cp=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cp boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cp_complete_source_runtime_admission_coverage_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cp_complete_source_runtime_admission_coverage_gate_ready") != 1:
    raise SystemExit("v61cp manifest readiness mismatch")
if manifest.get("complete_source_query_rows") != 1000:
    raise SystemExit("v61cp manifest complete-source count mismatch")
if manifest.get("source_bound_seed_runtime_candidate_rows") != 37:
    raise SystemExit("v61cp manifest seed count mismatch")
if manifest.get("direct_query_overlap_rows") != 0:
    raise SystemExit("v61cp manifest overlap should be zero")
if manifest.get("complete_source_runtime_admission_coverage_ready") != 0:
    raise SystemExit("v61cp manifest should keep coverage blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cp manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cp sha256 mismatch: {rel}")
PY

echo "v61cp complete-source runtime admission coverage gate smoke passed"
