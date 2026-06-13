#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61cf_ubuntu1_source_bound_generation_execution_packet/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"
UBUNTU1_TARGET="/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"

V61CF_REUSE_EXISTING="${V61CF_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61cf_ubuntu1_source_bound_generation_execution_packet.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$UBUNTU1_TARGET" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = sys.argv[4]


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
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v53r_complete_source_review_packet_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "v61ce_ubuntu1_generation_closure_return_intake_ready": "1",
    "target_root_path": ubuntu1_target,
    "execution_packet_rows": "1000",
    "prompt_manifest_rows": "4",
    "return_manifest_rows": "5",
    "operator_command_rows": "6",
    "complete_source_query_rows": "1000",
    "expected_generation_result_artifacts": "5",
    "generation_closure_return_intake_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_execution_ready": "0",
    "generation_execution_admitted_rows": "0",
    "blocked_execution_rows": "1000",
    "page_hash_closure_ready": "1",
    "review_return_closure_ready": "0",
    "generation_result_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cf": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61cf {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "source_bound_generation_execution_packet_rows.csv",
    "source_bound_generation_prompt_manifest_rows.csv",
    "source_bound_generation_return_manifest_rows.csv",
    "source_bound_generation_operator_command_rows.csv",
    "source_bound_generation_execution_requirement_rows.csv",
    "source_bound_generation_execution_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61CF_UBUNTU1_SOURCE_BOUND_GENERATION_EXECUTION_PACKET_BOUNDARY.md",
    "v61cf_ubuntu1_source_bound_generation_execution_packet_manifest.json",
    "sha256_manifest.csv",
    "source_v53r/review_query_packet_rows.csv",
    "source_v61bt/actual_generation_result_required_field_rows.csv",
    "source_v61ce/generation_closure_return_admission_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61cf artifact: {rel}")

packet_rows = read_csv(run_dir / "source_bound_generation_execution_packet_rows.csv")
prompt_rows = read_csv(run_dir / "source_bound_generation_prompt_manifest_rows.csv")
return_rows = read_csv(run_dir / "source_bound_generation_return_manifest_rows.csv")
command_rows = read_csv(run_dir / "source_bound_generation_operator_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "source_bound_generation_execution_requirement_rows.csv")}
metric = read_csv(run_dir / "source_bound_generation_execution_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(packet_rows) != 1000:
    raise SystemExit("v61cf packet row count mismatch")
if len(prompt_rows) != 4:
    raise SystemExit("v61cf prompt row count mismatch")
if len(return_rows) != 5:
    raise SystemExit("v61cf return row count mismatch")
if len(command_rows) != 6:
    raise SystemExit("v61cf command row count mismatch")
if any(row["generation_execution_ready"] != "0" for row in packet_rows):
    raise SystemExit("v61cf default packet rows should not be execution ready")
if any(row["execution_admitted"] != "0" for row in packet_rows):
    raise SystemExit("v61cf default packet rows should not be admitted")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in packet_rows):
    raise SystemExit("v61cf must not commit checkpoint payload bytes")
if {row["blocked_reason"] for row in packet_rows} != {"complete-source-review-return;actual-generation-result-return"}:
    raise SystemExit("v61cf blocked reason mismatch")
if {row["return_artifact"] for row in return_rows} != {
    "real_model_generation_answer_rows.csv",
    "real_model_generation_citation_rows.csv",
    "real_model_generation_abstain_fallback_rows.csv",
    "real_model_generation_latency_rows.csv",
    "real_model_generation_acceptance_summary.json",
}:
    raise SystemExit("v61cf return artifact set mismatch")
if any(row["execution_ready"] != "0" for row in command_rows):
    raise SystemExit("v61cf operator commands should remain blocked by default")

for requirement_id in [
    "v61ce-closure-return-intake-input",
    "complete-source-query-packet",
    "full-page-hash-closure",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61cf requirement should pass: {requirement_id}")
for requirement_id in [
    "generation-closure-return-intake-ready",
    "complete-source-review-return",
    "actual-generation-result-return",
    "generation-execution-admission-ready",
    "source-bound-generation-execution-ready",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61cf requirement should stay blocked: {requirement_id}")

for field, value in expected.items():
    if field.startswith("v61cf_") or field.startswith("v53r_") or field.startswith("v61bt_") or field.startswith("v61ce_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61cf metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61ce-closure-return-intake-input",
    "complete-source-query-packet",
    "full-page-hash-closure",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61cf gate should pass: {gate}")
for gate in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "source-bound-generation-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61cf gate should stay blocked: {gate}")

for gap in ["v61ce-closure-return-intake-input", "complete-source-query-packet", "full-page-hash-closure"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61cf gap should be ready: {gap}")
for gap in [
    "complete-source-review-return",
    "actual-generation-result-return",
    "source-bound-generation-execution",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61cf gap should stay blocked: {gap}")

boundary = (run_dir / "V61CF_UBUNTU1_SOURCE_BOUND_GENERATION_EXECUTION_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "execution_packet_rows=1000",
    "prompt_manifest_rows=4",
    "return_manifest_rows=5",
    "operator_command_rows=6",
    "complete_source_query_rows=1000",
    "generation_execution_ready=0",
    "generation_execution_admitted_rows=0",
    "blocked_execution_rows=1000",
    "page_hash_closure_ready=1",
    "review_return_closure_ready=0",
    "generation_result_closure_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61cf=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61cf boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61cf_ubuntu1_source_bound_generation_execution_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61cf_ubuntu1_source_bound_generation_execution_packet_ready") != 1:
    raise SystemExit("v61cf manifest readiness mismatch")
if manifest.get("execution_packet_rows") != 1000:
    raise SystemExit("v61cf manifest packet count mismatch")
if manifest.get("prompt_manifest_rows") != 4:
    raise SystemExit("v61cf manifest prompt count mismatch")
if manifest.get("return_manifest_rows") != 5:
    raise SystemExit("v61cf manifest return count mismatch")
if manifest.get("operator_command_rows") != 6:
    raise SystemExit("v61cf manifest command count mismatch")
if manifest.get("generation_execution_ready") != 0:
    raise SystemExit("v61cf manifest execution should remain blocked")
if manifest.get("page_hash_closure_ready") != 1:
    raise SystemExit("v61cf manifest page-hash closure mismatch")
if manifest.get("review_return_closure_ready") != 0:
    raise SystemExit("v61cf manifest review closure should remain blocked")
if manifest.get("generation_result_closure_ready") != 0:
    raise SystemExit("v61cf manifest generation result closure should remain blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61cf manifest should keep generation blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61cf") != 0:
    raise SystemExit("v61cf manifest must keep downloaded bytes at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61cf manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61cf sha256 mismatch: {rel}")
PY

echo "v61cf ubuntu-1 source-bound generation execution packet smoke passed"
