#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cq_complete_source_runtime_admission_expansion_packet/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v61cq_complete_source_runtime_admission_expansion_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cq_complete_source_runtime_admission_expansion_packet_decision.csv"

V61CQ_REUSE_EXISTING="${V61CQ_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cq_complete_source_runtime_admission_expansion_packet.sh" >/dev/null

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
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61cp_complete_source_runtime_admission_coverage_gate_ready": "1",
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": "1",
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": "1",
    "complete_source_query_rows": "1000",
    "source_bound_seed_runtime_candidate_rows": "37",
    "source_bound_seed_query_pass_rows": "37",
    "direct_query_overlap_rows": "0",
    "runtime_seed_covered_complete_source_rows": "0",
    "runtime_seed_uncovered_complete_source_rows": "1000",
    "complete_source_runtime_execution_admitted_rows": "0",
    "complete_source_runtime_execution_blocked_rows": "1000",
    "complete_source_runtime_admission_coverage_ready": "0",
    "runtime_admission_expansion_packet_rows": "1000",
    "runtime_admission_expansion_required_rows": "1000",
    "new_runtime_admission_rows_required": "1000",
    "runtime_admission_operator_command_rows": "5",
    "runtime_admission_return_artifact_rows": "5",
    "runtime_admission_expansion_packet_ready": "1",
    "runtime_admission_expansion_execution_ready": "0",
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
    "checkpoint_payload_bytes_downloaded_by_v61cq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cq {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_runtime_admission_expansion_rows.csv",
    "complete_source_runtime_admission_operator_command_rows.csv",
    "complete_source_runtime_admission_return_manifest_rows.csv",
    "complete_source_runtime_admission_expansion_requirement_rows.csv",
    "complete_source_runtime_admission_expansion_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CQ_COMPLETE_SOURCE_RUNTIME_ADMISSION_EXPANSION_PACKET_BOUNDARY.md",
    "v61cq_complete_source_runtime_admission_expansion_packet_manifest.json",
    "sha256_manifest.csv",
    "source_v61cp/complete_source_runtime_admission_coverage_rows.csv",
    "source_v61cf/source_bound_generation_execution_packet_rows.csv",
    "source_v61cf/source_bound_generation_return_manifest_rows.csv",
    "source_v61cf/source_bound_generation_operator_command_rows.csv",
    "source_v61cc/page_hash_generation_admission_bridge_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cq artifact: {rel}")

expansion_rows = read_csv(run_dir / "complete_source_runtime_admission_expansion_rows.csv")
operator_rows = read_csv(run_dir / "complete_source_runtime_admission_operator_command_rows.csv")
return_rows = read_csv(run_dir / "complete_source_runtime_admission_return_manifest_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_runtime_admission_expansion_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_runtime_admission_expansion_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(expansion_rows) != 1000:
    raise SystemExit("v61cq expansion row count mismatch")
if len(operator_rows) != 5:
    raise SystemExit("v61cq operator command row count mismatch")
if len(return_rows) != 5:
    raise SystemExit("v61cq return manifest row count mismatch")
if any(row["requires_new_runtime_admission_row"] != "1" for row in expansion_rows):
    raise SystemExit("v61cq every row should require new runtime admission")
if {row["runtime_admission_expansion_status"] for row in expansion_rows} != {"planned-new-runtime-admission-required"}:
    raise SystemExit("v61cq expansion status mismatch")
if any(row["checkpoint_payload_bytes_downloaded_by_v61cq"] != "0" for row in expansion_rows):
    raise SystemExit("v61cq must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in expansion_rows):
    raise SystemExit("v61cq must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in expansion_rows):
    raise SystemExit("v61cq route jumps must stay zero")
if any(row["accepted_rows"] != "0" or row["status"] != "missing" for row in return_rows):
    raise SystemExit("v61cq return manifest should remain missing by default")

for requirement_id in [
    "v61cp-complete-source-runtime-coverage-input",
    "v61cf-complete-source-generation-packet-input",
    "v61cc-generation-admission-input",
    "complete-source-runtime-admission-expansion-packet",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cq requirement should pass: {requirement_id}")
if requirements["complete-source-runtime-admission-execution"]["status"] != "blocked":
    raise SystemExit("v61cq execution requirement should stay blocked")

for field, value in expected.items():
    if field.startswith("v61cq_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cq metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61cp-complete-source-runtime-coverage-input",
    "v61cf-complete-source-generation-packet-input",
    "v61cc-generation-admission-input",
    "complete-source-runtime-admission-expansion-packet",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cq gate should pass: {gate}")
for gate in [
    "complete-source-runtime-admission-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cq gate should stay blocked: {gate}")

for gap in [
    "v61cp-complete-source-runtime-coverage-input",
    "v61cf-complete-source-generation-packet-input",
    "v61cc-generation-admission-input",
    "complete-source-runtime-admission-expansion-packet",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cq gap should be ready: {gap}")
for gap in [
    "complete-source-runtime-admission-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cq gap should stay blocked: {gap}")

boundary = (run_dir / "V61CQ_COMPLETE_SOURCE_RUNTIME_ADMISSION_EXPANSION_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "complete_source_query_rows=1000",
    "source_bound_seed_runtime_candidate_rows=37",
    "source_bound_seed_query_pass_rows=37",
    "direct_query_overlap_rows=0",
    "runtime_seed_covered_complete_source_rows=0",
    "runtime_seed_uncovered_complete_source_rows=1000",
    "runtime_admission_expansion_packet_rows=1000",
    "runtime_admission_expansion_required_rows=1000",
    "new_runtime_admission_rows_required=1000",
    "runtime_admission_operator_command_rows=5",
    "runtime_admission_return_artifact_rows=5",
    "runtime_admission_expansion_packet_ready=1",
    "runtime_admission_expansion_execution_ready=0",
    "complete_source_runtime_admission_coverage_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cq=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cq boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cq_complete_source_runtime_admission_expansion_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cq_complete_source_runtime_admission_expansion_packet_ready") != 1:
    raise SystemExit("v61cq manifest readiness mismatch")
if manifest.get("complete_source_query_rows") != 1000:
    raise SystemExit("v61cq manifest query count mismatch")
if manifest.get("runtime_admission_expansion_required_rows") != 1000:
    raise SystemExit("v61cq manifest expansion count mismatch")
if manifest.get("runtime_admission_expansion_execution_ready") != 0:
    raise SystemExit("v61cq manifest should keep execution blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cq manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cq sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61cq must not write checkpoint payload files" >&2
  exit 1
fi

echo "v61cq complete-source runtime admission expansion packet smoke passed"
