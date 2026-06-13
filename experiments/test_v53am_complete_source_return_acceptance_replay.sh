#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53am_complete_source_return_acceptance_replay"
RUN_DIR="$RESULTS_DIR/$PREFIX/replay_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AM_REUSE_EXISTING="${V53AM_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null

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
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": "1",
    "v61de_post_review_generation_result_handoff_bridge_ready": "1",
    "return_acceptance_replay_ready": "1",
    "replay_step_rows": "11",
    "ready_replay_step_rows": "2",
    "blocked_replay_step_rows": "9",
    "replay_command_rows": "7",
    "ready_replay_command_rows": "1",
    "return_bundle_preflight_pass": "0",
    "preflight_pass_rows": "0",
    "preflight_rows": "81",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "aggregate_review_return_artifact_rows": "5",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "review_return_ready": "0",
    "v53_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "return_acceptance_replay_closed": "0",
    "accepted_by_v53am_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v53am": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53am {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_acceptance_replay_step_rows.csv",
    "return_acceptance_replay_command_rows.csv",
    "return_acceptance_replay_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AM_COMPLETE_SOURCE_RETURN_ACCEPTANCE_REPLAY_BOUNDARY.md",
    "v53am_complete_source_return_acceptance_replay_manifest.json",
    "source_v53al/v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "source_v53ad/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "source_v53x/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "source_v53y/v53y_complete_source_review_return_refresh_gate_summary.csv",
    "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv",
    "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "source_v61de/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53am artifact: {rel}")

step_rows = read_csv(run_dir / "return_acceptance_replay_step_rows.csv")
command_rows = read_csv(run_dir / "return_acceptance_replay_command_rows.csv")
metric = read_csv(run_dir / "return_acceptance_replay_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(step_rows) != 11:
    raise SystemExit("v53am expected 11 replay step rows")
ready_ids = {row["replay_step_id"] for row in step_rows if row["status"] == "ready"}
if ready_ids != {"01-return-bundle-preflight-surface", "07-full-shard-runtime-closed"}:
    raise SystemExit(f"v53am ready replay ids mismatch: {ready_ids}")
if len(command_rows) != 7:
    raise SystemExit("v53am expected seven command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "0", "0", "0", "0", "0", "0"]:
    raise SystemExit("v53am command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v53am_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53am metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "01-return-bundle-preflight-surface",
    "07-full-shard-runtime-closed",
    "v53am-does-not-accept-evidence",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53am decision should pass: {gate}")
for gate in [
    "02-return-bundle-preflight-pass",
    "03-dispatch-receipt-intake",
    "04-review-chunk-return-intake",
    "05-aggregate-review-refresh",
    "06-v53-review-acceptance",
    "08-generation-execution-admitted",
    "09-generation-result-intake",
    "10-generation-result-acceptance",
    "11-actual-model-generation-ready",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53am decision should stay blocked: {gate}")

for gap in ["01-return-bundle-preflight-surface", "07-full-shard-runtime-closed"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v53am gap should be ready: {gap}")
for gap in [
    "02-return-bundle-preflight-pass",
    "03-dispatch-receipt-intake",
    "04-review-chunk-return-intake",
    "05-aggregate-review-refresh",
    "06-v53-review-acceptance",
    "08-generation-execution-admitted",
    "09-generation-result-intake",
    "10-generation-result-acceptance",
    "11-actual-model-generation-ready",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53am gap should stay blocked: {gap}")

boundary = (run_dir / "V53AM_COMPLETE_SOURCE_RETURN_ACCEPTANCE_REPLAY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_acceptance_replay_ready=1",
    "replay_step_rows=11",
    "ready_replay_step_rows=2",
    "blocked_replay_step_rows=9",
    "ready_replay_command_rows=1",
    "return_bundle_preflight_pass=0",
    "preflight_pass_rows=0/81",
    "accepted_dispatch_receipt_rows=0/21",
    "accepted_chunk_return_artifact_rows=0/50",
    "answer_review_accepted_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "accepted_by_v53am_rows=0",
    "checkpoint_payload_bytes_downloaded_by_v53am=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53am boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53am_complete_source_return_acceptance_replay_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53am_complete_source_return_acceptance_replay_ready") != 1:
    raise SystemExit("v53am manifest readiness mismatch")
if manifest.get("ready_replay_step_rows") != 2:
    raise SystemExit("v53am manifest ready step count mismatch")
if manifest.get("accepted_by_v53am_rows") != 0:
    raise SystemExit("v53am manifest must not accept evidence")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53am manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53am sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53am produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53am complete-source return acceptance replay smoke passed"
