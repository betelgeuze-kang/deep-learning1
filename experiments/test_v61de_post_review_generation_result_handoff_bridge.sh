#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61de_post_review_generation_result_handoff_bridge"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DE_REUSE_EXISTING="${V61DE_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_POST_REVIEW_GENERATION_HANDOFF.sh" >/dev/null

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
    "v61de_post_review_generation_result_handoff_bridge_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "generation_result_dir_supplied": "0",
    "generation_result_dir_exists": "0",
    "v53z_complete_source_review_return_v61_handoff_bridge_ready": "1",
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "v61bt_ubuntu1_actual_generation_result_intake_ready": "1",
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": "1",
    "v61dd_review_return_generation_refresh_bridge_ready": "1",
    "handoff_stage_rows": "8",
    "ready_handoff_stage_rows": "3",
    "blocked_handoff_stage_rows": "5",
    "handoff_command_rows": "6",
    "ready_handoff_command_rows": "2",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "complete_source_runtime_admission_execution_ready": "1",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "review_return_ready": "0",
    "v61_review_unblock_ready": "0",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_blocked_rows": "1000",
    "guarded_generation_command_ready": "0",
    "generation_operator_execution_ready": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "generation_result_supplied_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "answer_accepted_rows": "0",
    "citation_accepted_rows": "0",
    "latency_accepted_rows": "0",
    "actual_model_generation_ready_rows": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61de": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61de {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_review_generation_result_handoff_stage_rows.csv",
    "post_review_generation_result_handoff_command_rows.csv",
    "post_review_generation_result_handoff_requirement_rows.csv",
    "post_review_generation_result_handoff_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DE_POST_REVIEW_GENERATION_RESULT_HANDOFF_BRIDGE_BOUNDARY.md",
    "v61de_post_review_generation_result_handoff_bridge_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/VERIFY_POST_REVIEW_GENERATION_HANDOFF.sh",
    "source_v53z/review_return_v61_handoff_stage_rows.csv",
    "source_v61ct/complete_source_generation_execution_operator_command_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
    "source_v61cu/complete_source_generation_result_acceptance_rows.csv",
    "source_v61dd/review_return_generation_refresh_stage_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61de artifact: {rel}")

stage_rows = read_csv(run_dir / "post_review_generation_result_handoff_stage_rows.csv")
command_rows = read_csv(run_dir / "post_review_generation_result_handoff_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "post_review_generation_result_handoff_requirement_rows.csv")}
metric = read_csv(run_dir / "post_review_generation_result_handoff_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(stage_rows) != 8:
    raise SystemExit("v61de expected eight handoff stage rows")
if [row["stage_status"] for row in stage_rows] != ["ready", "ready", "ready", "blocked", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61de stage status sequence mismatch")
if len(command_rows) != 6:
    raise SystemExit("v61de expected six handoff command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "0", "1", "0", "0", "0"]:
    raise SystemExit("v61de command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v61de_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61de metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "review-return-v61-handoff-surface",
    "full-shard-runtime-prerequisites",
    "generation-operator-result-surfaces",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61de requirement should pass: {requirement_id}")
for requirement_id in [
    "review-return-directory",
    "review-return-accepted",
    "generation-execution-admitted",
    "guarded-generation-operator-ready",
    "generation-result-directory",
    "generation-result-artifacts-accepted",
    "generation-result-acceptance-ready",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61de requirement should stay blocked: {requirement_id}")

for gate in [
    "review-return-v61-handoff-surface",
    "full-shard-runtime-prerequisites",
    "generation-operator-result-surfaces",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61de decision should pass: {gate}")
for gate in [
    "review-return-directory",
    "review-return-accepted",
    "generation-execution-admitted",
    "guarded-generation-operator-ready",
    "generation-result-directory",
    "generation-result-artifacts-accepted",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61de decision should stay blocked: {gate}")

for gap in [
    "review-return-v61-handoff-surface",
    "full-shard-runtime-prerequisites",
    "generation-operator-result-surfaces",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61de gap should be ready: {gap}")
for gap in [
    "review-return-directory",
    "review-return-accepted",
    "generation-execution-admitted",
    "guarded-generation-operator-ready",
    "generation-result-directory",
    "generation-result-artifacts-accepted",
    "actual-model-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61de gap should stay blocked: {gap}")

boundary = (run_dir / "V61DE_POST_REVIEW_GENERATION_RESULT_HANDOFF_BRIDGE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_return_dir_supplied=0",
    "generation_result_dir_supplied=0",
    "handoff_stage_rows=8",
    "ready_handoff_stage_rows=3",
    "blocked_handoff_stage_rows=5",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "answer_review_accepted_rows=0/7000",
    "v61_review_unblock_ready=0",
    "generation_execution_admitted_rows=0/1000",
    "guarded_generation_command_ready=0",
    "accepted_generation_result_artifacts=0/5",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61de=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61de boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61de_post_review_generation_result_handoff_bridge_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61de_post_review_generation_result_handoff_bridge_ready") != 1:
    raise SystemExit("v61de manifest readiness mismatch")
if manifest.get("ready_handoff_stage_rows") != 3 or manifest.get("blocked_handoff_stage_rows") != 5:
    raise SystemExit("v61de manifest stage count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61de manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61de manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61de sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61de produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61de post-review generation result handoff bridge smoke passed"
