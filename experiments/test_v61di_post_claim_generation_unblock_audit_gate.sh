#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61di_post_claim_generation_unblock_audit_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DI_REUSE_EXISTING="${V61DI_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61di_post_claim_generation_unblock_audit_gate.sh" >/dev/null

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
    "v61di_post_claim_generation_unblock_audit_gate_ready": "1",
    "v61dh_post_full_shard_claim_audit_gate_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    "source_gate_rows": "3",
    "unblock_audit_ready": "1",
    "unblock_stage_rows": "12",
    "ready_unblock_stage_rows": "6",
    "blocked_unblock_stage_rows": "6",
    "unblock_command_rows": "9",
    "ready_unblock_command_rows": "2",
    "claim_audit_ready": "1",
    "allowed_claim_rows": "7",
    "blocked_claim_rows": "8",
    "v52_ready": "1",
    "comparison_30b_150b_wording_status": "allowed-with-disclosure",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "return_acceptance_replay_ready": "1",
    "return_acceptance_replay_closed": "0",
    "ready_replay_step_rows": "2",
    "blocked_replay_step_rows": "9",
    "return_bundle_preflight_pass": "0",
    "preflight_pass_rows": "0",
    "preflight_rows": "81",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
    "accepted_human_review_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "review_return_ready": "0",
    "v53_ready": "0",
    "v61_post_full_shard_runtime_evidence_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "operator_packet_ready": "1",
    "operator_packet_file_rows": "8",
    "ready_operator_packet_file_rows": "8",
    "ready_operator_stage_rows": "3",
    "blocked_operator_stage_rows": "4",
    "review_return_required_artifacts": "5",
    "generation_result_required_artifacts": "5",
    "generation_execution_admission_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "generation_result_acceptance_rows": "1000",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "generation_unblock_closure_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61di": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61di {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_claim_generation_unblock_stage_rows.csv",
    "post_claim_generation_unblock_command_rows.csv",
    "post_claim_generation_unblock_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DI_POST_CLAIM_GENERATION_UNBLOCK_AUDIT_GATE_BOUNDARY.md",
    "v61di_post_claim_generation_unblock_audit_gate_manifest.json",
    "source_v61dh/v61dh_post_full_shard_claim_audit_gate_summary.csv",
    "source_v61dh/post_full_shard_claim_audit_rows.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "source_v53am/return_acceptance_replay_step_rows.csv",
    "source_v61df/v61df_external_review_generation_return_operator_packet_summary.csv",
    "source_v61df/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv",
    "source_v61df/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61di artifact: {rel}")

stage_rows = read_csv(run_dir / "post_claim_generation_unblock_stage_rows.csv")
command_rows = read_csv(run_dir / "post_claim_generation_unblock_command_rows.csv")
metric = read_csv(run_dir / "post_claim_generation_unblock_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(stage_rows) != 12:
    raise SystemExit("v61di expected 12 unblock stage rows")
if [row["status"] for row in stage_rows] != ["ready"] * 6 + ["blocked"] * 6:
    raise SystemExit("v61di stage status sequence mismatch")
if len(command_rows) != 9:
    raise SystemExit("v61di expected nine command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "0", "0", "0", "0", "0", "0", "0"]:
    raise SystemExit("v61di command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v61di_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61di metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "source-claim-audit",
    "source-return-replay",
    "source-external-return-packet",
    "full-shard-runtime-evidence",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61di gate should pass: {gate}")
for gate in [
    "return-bundle-preflight-pass",
    "v53-ready",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
    "v1-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61di gate should stay blocked: {gate}")

for gap in [row["unblock_stage_id"] for row in stage_rows[:6]]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61di gap should be ready: {gap}")
for gap in [row["unblock_stage_id"] for row in stage_rows[6:]]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61di gap should be blocked: {gap}")

boundary = (run_dir / "V61DI_POST_CLAIM_GENERATION_UNBLOCK_AUDIT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "unblock_stage_rows=12",
    "ready_unblock_stage_rows=6",
    "blocked_unblock_stage_rows=6",
    "ready_unblock_command_rows=2",
    "claim_audit_ready=1",
    "return_acceptance_replay_ready=1",
    "return_acceptance_replay_closed=0",
    "operator_packet_file_rows=8/8",
    "return_bundle_preflight_pass=0",
    "preflight_pass_rows=0/81",
    "accepted_dispatch_receipt_rows=0/21",
    "accepted_chunk_return_artifact_rows=0/50",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "v1_0_comparison_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61di=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61di boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61di_post_claim_generation_unblock_audit_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61di_post_claim_generation_unblock_audit_gate_ready") != 1:
    raise SystemExit("v61di manifest readiness mismatch")
if manifest.get("ready_unblock_stage_rows") != 6 or manifest.get("blocked_unblock_stage_rows") != 6:
    raise SystemExit("v61di manifest stage counts mismatch")
if manifest.get("v53_ready") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61di manifest must keep v53/generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61di manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61di sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61di produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61di post-claim generation unblock audit gate smoke passed"
