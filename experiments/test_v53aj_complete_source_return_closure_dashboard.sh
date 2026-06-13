#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53aj_complete_source_return_closure_dashboard"
RUN_DIR="$RESULTS_DIR/$PREFIX/dashboard_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AJ_REUSE_EXISTING="${V53AJ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53aj_complete_source_return_closure_dashboard.sh" >/dev/null

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
    "v53aj_complete_source_return_closure_dashboard_ready": "1",
    "v53ai_complete_source_external_return_bundle_intake_ready": "1",
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": "1",
    "v53v_complete_source_review_return_acceptance_bridge_ready": "1",
    "v61de_post_review_generation_result_handoff_bridge_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "closure_dashboard_ready": "1",
    "closure_item_rows": "12",
    "ready_closure_item_rows": "3",
    "blocked_closure_item_rows": "9",
    "next_action_rows": "5",
    "ready_next_action_rows": "1",
    "send_bundle_ready": "1",
    "return_bundle_mapping_ready": "1",
    "required_return_artifact_rows": "81",
    "supplied_return_artifact_rows": "0",
    "missing_return_artifact_rows": "81",
    "all_return_artifacts_present": "0",
    "accepted_by_v53ai_rows": "0",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "aggregate_review_return_artifact_rows": "5",
    "expected_human_review_rows": "7000",
    "answer_review_accepted_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
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
    "return_loop_closed": "0",
    "v53_review_closed": "0",
    "v61_generation_closed": "0",
    "checkpoint_payload_bytes_downloaded_by_v53aj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53aj {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_return_closure_dashboard_rows.csv",
    "complete_source_return_closure_next_action_rows.csv",
    "complete_source_return_closure_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AJ_COMPLETE_SOURCE_RETURN_CLOSURE_DASHBOARD_BOUNDARY.md",
    "v53aj_complete_source_return_closure_dashboard_manifest.json",
    "source_v53ai/v53ai_complete_source_external_return_bundle_intake_summary.csv",
    "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv",
    "source_v53v/v53v_complete_source_review_return_acceptance_bridge_summary.csv",
    "source_v61de/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53aj artifact: {rel}")

closure_rows = read_csv(run_dir / "complete_source_return_closure_dashboard_rows.csv")
action_rows = read_csv(run_dir / "complete_source_return_closure_next_action_rows.csv")
metric = read_csv(run_dir / "complete_source_return_closure_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(closure_rows) != 12:
    raise SystemExit("v53aj expected 12 closure rows")
if sum(1 for row in closure_rows if row["status"] == "ready") != 3:
    raise SystemExit("v53aj expected 3 ready closure rows")
if sum(1 for row in closure_rows if row["status"] == "blocked") != 9:
    raise SystemExit("v53aj expected 9 blocked closure rows")
ready_ids = {row["closure_item_id"] for row in closure_rows if row["status"] == "ready"}
if ready_ids != {
    "01-external-send-bundle-ready",
    "02-return-bundle-mapping-surface",
    "08-full-shard-runtime-closed",
}:
    raise SystemExit(f"v53aj ready closure ids mismatch: {ready_ids}")
if len(action_rows) != 5:
    raise SystemExit("v53aj expected 5 next action rows")
if [row["action_status"] for row in action_rows] != ["ready", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v53aj next action status mismatch")

for field, value in expected.items():
    if field.startswith("v53aj_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53aj metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "01-external-send-bundle-ready",
    "02-return-bundle-mapping-surface",
    "08-full-shard-runtime-closed",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53aj decision should pass: {gate}")
for gate in [
    "03-return-bundle-artifacts-present",
    "04-dispatch-receipts-accepted",
    "05-review-chunk-returns-accepted",
    "06-aggregate-review-return-accepted",
    "07-complete-source-review-ready",
    "09-generation-execution-admitted",
    "10-generation-result-accepted",
    "11-actual-model-generation-ready",
    "12-release-claim-ready",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53aj decision should stay blocked: {gate}")

for gap in [
    "01-external-send-bundle-ready",
    "02-return-bundle-mapping-surface",
    "08-full-shard-runtime-closed",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v53aj gap should be ready: {gap}")
for gap in [
    "03-return-bundle-artifacts-present",
    "04-dispatch-receipts-accepted",
    "05-review-chunk-returns-accepted",
    "06-aggregate-review-return-accepted",
    "07-complete-source-review-ready",
    "09-generation-execution-admitted",
    "10-generation-result-accepted",
    "11-actual-model-generation-ready",
    "12-release-claim-ready",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53aj gap should stay blocked: {gap}")

boundary = (run_dir / "V53AJ_COMPLETE_SOURCE_RETURN_CLOSURE_DASHBOARD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "closure_item_rows=12",
    "ready_closure_item_rows=3",
    "blocked_closure_item_rows=9",
    "next_action_rows=5",
    "ready_next_action_rows=1",
    "send_bundle_ready=1",
    "return_bundle_mapping_ready=1",
    "required_return_artifact_rows=81",
    "supplied_return_artifact_rows=0",
    "missing_return_artifact_rows=81",
    "accepted_by_v53ai_rows=0",
    "answer_review_accepted_rows=0",
    "accepted_adjudication_rows=0",
    "v53_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v53aj=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53aj boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53aj_complete_source_return_closure_dashboard_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53aj_complete_source_return_closure_dashboard_ready") != 1:
    raise SystemExit("v53aj manifest readiness mismatch")
if manifest.get("ready_closure_item_rows") != 3:
    raise SystemExit("v53aj manifest ready row count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53aj manifest must keep actual generation blocked")
if manifest.get("full_shard_prerequisites_closed") != 1:
    raise SystemExit("v53aj manifest should inherit full-shard closure")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53aj sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53aj produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53aj complete-source return closure dashboard smoke passed"
