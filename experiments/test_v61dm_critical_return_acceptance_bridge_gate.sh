#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dm_critical_return_acceptance_bridge_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/bridge_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DM_REUSE_EXISTING="${V61DM_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null

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
    "v61dm_critical_return_acceptance_bridge_gate_ready": "1",
    "v61dl_critical_return_contract_preflight_gate_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "source_gate_rows": "2",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "bridge_step_rows": "11",
    "ready_bridge_step_rows": "2",
    "blocked_bridge_step_rows": "9",
    "bridge_command_rows": "4",
    "ready_bridge_command_rows": "3",
    "critical_artifact_rows": "10",
    "critical_preflight_pass_rows": "0",
    "critical_preflight_ready": "0",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "0",
    "return_bundle_preflight_pass": "0",
    "critical_only_gap_detected": "0",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
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
    "acceptance_bridge_closed": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dm {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "critical_return_acceptance_bridge_step_rows.csv",
    "critical_return_acceptance_bridge_command_rows.csv",
    "critical_return_acceptance_bridge_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DM_CRITICAL_RETURN_ACCEPTANCE_BRIDGE_GATE_BOUNDARY.md",
    "v61dm_critical_return_acceptance_bridge_gate_manifest.json",
    "source_v61dl/v61dl_critical_return_contract_preflight_gate_summary.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dm artifact: {rel}")

step_rows = read_csv(run_dir / "critical_return_acceptance_bridge_step_rows.csv")
command_rows = read_csv(run_dir / "critical_return_acceptance_bridge_command_rows.csv")
metric = read_csv(run_dir / "critical_return_acceptance_bridge_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

ready_ids = {row["bridge_step_id"] for row in step_rows if row["status"] == "ready"}
if ready_ids != {"01-critical-preflight-surface", "08-full-shard-runtime-context"}:
    raise SystemExit(f"v61dm default ready ids mismatch: {ready_ids}")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "1", "1", "0"]:
    raise SystemExit("v61dm default command readiness mismatch")
for field, value in expected.items():
    if field.startswith("v61dm_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61dm metric {field}: expected {value}, got {metric[field]}")

for gate in ["01-critical-preflight-surface", "08-full-shard-runtime-context", "critical-only-is-not-acceptance", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dm decision should pass: {gate}")
for gate in [
    "02-critical-preflight-pass",
    "03-full-return-bundle-preflight",
    "04-dispatch-receipts",
    "05-review-chunk-returns",
    "06-aggregate-review-acceptance",
    "07-v53-ready",
    "09-generation-execution-admitted",
    "10-generation-result-acceptance",
    "11-actual-generation-ready",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dm decision should stay blocked: {gate}")
if gaps.get("08-full-shard-runtime-context") != "ready":
    raise SystemExit("v61dm full-shard/runtime gap should be ready")

boundary = (run_dir / "V61DM_CRITICAL_RETURN_ACCEPTANCE_BRIDGE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "bridge_step_rows=11",
    "ready_bridge_step_rows=2",
    "blocked_bridge_step_rows=9",
    "critical_preflight_pass_rows=0",
    "full_preflight_pass_rows=0/81",
    "critical_only_gap_detected=0",
    "accepted_dispatch_receipt_rows=0/21",
    "accepted_chunk_return_artifact_rows=0/50",
    "answer_review_accepted_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "acceptance_bridge_closed=0",
    "checkpoint_payload_bytes_downloaded_by_v61dm=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dm boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dm_critical_return_acceptance_bridge_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dm_critical_return_acceptance_bridge_gate_ready") != 1:
    raise SystemExit("v61dm manifest readiness mismatch")
if manifest.get("ready_bridge_step_rows") != 2 or manifest.get("blocked_bridge_step_rows") != 9:
    raise SystemExit("v61dm manifest step count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dm manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dm sha256 mismatch: {rel}")
PY

CRITICAL_ONLY_BUNDLE_DIR="$(mktemp -d /tmp/v61dm_critical_only_bundle.XXXXXX)"
trap 'rm -rf "$CRITICAL_ONLY_BUNDLE_DIR"' EXIT
python3 - "$CRITICAL_ONLY_BUNDLE_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
payloads = {
    "aggregate_review_return/human_review_rows.csv": "review_id,accepted\nsynthetic-critical-only,1\n",
    "aggregate_review_return/adjudication_rows.csv": "query_id,accepted\nsynthetic-critical-only,1\n",
    "aggregate_review_return/reviewer_identity_rows.csv": "reviewer_id,assigned\nsynthetic-critical-only,1\n",
    "aggregate_review_return/reviewer_conflict_rows.csv": "reviewer_id,repo_id,conflict\nsynthetic-critical-only,repo,0\n",
    "aggregate_review_return/acceptance_summary.json": json.dumps({"synthetic_critical_only": True}) + "\n",
    "generation_result_return/real_model_generation_answer_rows.csv": "query_id,answer\nsynthetic-critical-only,answer\n",
    "generation_result_return/real_model_generation_citation_rows.csv": "query_id,citation\nsynthetic-critical-only,citation\n",
    "generation_result_return/real_model_generation_abstain_fallback_rows.csv": "query_id,abstain,fallback\nsynthetic-critical-only,0,0\n",
    "generation_result_return/real_model_generation_latency_rows.csv": "query_id,latency_ms\nsynthetic-critical-only,1\n",
    "generation_result_return/real_model_generation_acceptance_summary.json": json.dumps({"synthetic_critical_only": True}) + "\n",
}
for rel, text in payloads.items():
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
PY

SUPPLIED_RUN_ID="bridge_critical_only_smoke"
SUPPLIED_RUN_DIR="$RESULTS_DIR/$PREFIX/$SUPPLIED_RUN_ID"
V61DM_RUN_ID="$SUPPLIED_RUN_ID" \
V61DM_RETURN_BUNDLE_DIR="$CRITICAL_ONLY_BUNDLE_DIR" \
V61DM_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null

python3 - "$SUPPLIED_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "return_bundle_dir_supplied": "1",
    "return_bundle_dir_exists": "1",
    "bridge_step_rows": "11",
    "ready_bridge_step_rows": "3",
    "blocked_bridge_step_rows": "8",
    "critical_artifact_rows": "10",
    "critical_preflight_pass_rows": "10",
    "critical_preflight_ready": "1",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "10",
    "return_bundle_preflight_pass": "0",
    "critical_only_gap_detected": "1",
    "accepted_dispatch_receipt_rows": "0",
    "accepted_chunk_return_artifact_rows": "0",
    "answer_review_accepted_rows": "0",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "acceptance_bridge_closed": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dm critical-only {field}: expected {value}, got {summary.get(field)}")

step_rows = read_csv(run_dir / "critical_return_acceptance_bridge_step_rows.csv")
ready_ids = {row["bridge_step_id"] for row in step_rows if row["status"] == "ready"}
if ready_ids != {"01-critical-preflight-surface", "02-critical-preflight-pass", "08-full-shard-runtime-context"}:
    raise SystemExit(f"v61dm critical-only ready ids mismatch: {ready_ids}")
preflight_step = {row["bridge_step_id"]: row for row in step_rows}["03-full-return-bundle-preflight"]
if "preflight_pass_rows=10/81" not in preflight_step["actual_value"]:
    raise SystemExit("v61dm critical-only should expose 10/81 full preflight progress")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["01-critical-preflight-surface", "02-critical-preflight-pass", "08-full-shard-runtime-context", "critical-only-is-not-acceptance", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dm critical-only decision should pass: {gate}")
for gate in [
    "03-full-return-bundle-preflight",
    "04-dispatch-receipts",
    "05-review-chunk-returns",
    "06-aggregate-review-acceptance",
    "07-v53-ready",
    "09-generation-execution-admitted",
    "10-generation-result-acceptance",
    "11-actual-generation-ready",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dm critical-only decision should stay blocked: {gate}")

boundary = (run_dir / "V61DM_CRITICAL_RETURN_ACCEPTANCE_BRIDGE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "ready_bridge_step_rows=3",
    "blocked_bridge_step_rows=8",
    "critical_preflight_pass_rows=10",
    "full_preflight_pass_rows=10/81",
    "critical_only_gap_detected=1",
    "answer_review_accepted_rows=0/7000",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dm critical-only boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dm_critical_return_acceptance_bridge_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("critical_only_gap_detected") != 1:
    raise SystemExit("v61dm critical-only manifest gap mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dm critical-only manifest must keep actual generation blocked")
PY

# Restore canonical no-return summaries for the upstream gates and this bridge.
V61DL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dl_critical_return_contract_preflight_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V61DM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null

if find "$RUN_DIR" "$SUPPLIED_RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dm produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dm critical return acceptance bridge gate smoke passed"
