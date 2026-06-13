#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dt_return_bundle_closure_replay_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/closure_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DT_REUSE_EXISTING="${V61DT_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dt_return_bundle_closure_replay_gate.sh" >/dev/null

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
    "v61dt_return_bundle_closure_replay_gate_ready": "1",
    "v61dr_return_bundle_schema_preflight_gate_ready": "1",
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    "v61ds_schema_preflight_acceptance_handoff_gate_ready": "1",
    "source_gate_rows": "3",
    "closure_stage_rows": "15",
    "ready_closure_stage_rows": "4",
    "blocked_closure_stage_rows": "11",
    "closure_command_rows": "9",
    "ready_closure_command_rows": "4",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "schema_preflight_artifact_rows": "81",
    "schema_preflight_pass_rows": "0",
    "schema_preflight_pass": "0",
    "schema_handoff_stage_rows": "12",
    "ready_schema_handoff_stage_rows": "2",
    "return_bundle_preflight_pass": "0",
    "preflight_pass_rows": "0",
    "preflight_rows": "81",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
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
    "schema_acceptance_ready": "0",
    "return_acceptance_replay_closed": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dt": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dt {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_bundle_closure_replay_stage_rows.csv",
    "return_bundle_closure_replay_command_rows.csv",
    "return_bundle_closure_replay_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DT_RETURN_BUNDLE_CLOSURE_REPLAY_GATE_BOUNDARY.md",
    "v61dt_return_bundle_closure_replay_gate_manifest.json",
    "source_v61dr/v61dr_return_bundle_schema_preflight_gate_summary.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "source_v61ds/v61ds_schema_preflight_acceptance_handoff_gate_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dt artifact: {rel}")

stage_rows = read_csv(run_dir / "return_bundle_closure_replay_stage_rows.csv")
command_rows = read_csv(run_dir / "return_bundle_closure_replay_command_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(stage_rows) != 15:
    raise SystemExit("v61dt expected 15 closure stages")
ready_stage_ids = [row["closure_stage_id"] for row in stage_rows if row["status"] == "ready"]
if ready_stage_ids != [
    "02-schema-preflight-surface",
    "04-schema-acceptance-handoff-audited",
    "05-acceptance-replay-surface",
    "11-full-shard-runtime-closed",
]:
    raise SystemExit(f"v61dt ready stages mismatch: {ready_stage_ids}")
if [row["ready_to_run_now"] for row in command_rows[:5]] != ["1", "1", "1", "1", "0"]:
    raise SystemExit("v61dt command readiness prefix mismatch")
for gate in [
    "02-schema-preflight-surface",
    "04-schema-acceptance-handoff-audited",
    "05-acceptance-replay-surface",
    "11-full-shard-runtime-closed",
    "one-command-return-bundle-replay",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dt decision should pass: {gate}")
for gate in [
    "01-return-bundle-supplied",
    "03-schema-preflight-pass",
    "06-full-return-preflight-pass",
    "09-aggregate-review-accepted",
    "15-actual-generation-ready",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dt decision should stay blocked: {gate}")
if gaps.get("15-actual-generation-ready") != "blocked":
    raise SystemExit("v61dt actual-generation gap must stay blocked")

boundary = (run_dir / "V61DT_RETURN_BUNDLE_CLOSURE_REPLAY_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "closure_stage_rows=15",
    "ready_closure_stage_rows=4",
    "blocked_closure_stage_rows=11",
    "schema_preflight_pass_rows=0/81",
    "preflight_pass_rows=0/81",
    "accepted_payload_rows=0/17483",
    "answer_review_accepted_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "generation_result_accepted_rows=0/1000",
    "return_acceptance_replay_closed=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dt boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dt_return_bundle_closure_replay_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("ready_closure_stage_rows") != 4:
    raise SystemExit("v61dt manifest ready stage mismatch")
if manifest.get("accepted_payload_rows") != 0:
    raise SystemExit("v61dt manifest must not accept payload rows")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dt manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dt sha256 mismatch: {rel}")
PY

CRITICAL_ONLY_BUNDLE_DIR="$(mktemp -d /tmp/v61dt_critical_only_bundle.XXXXXX)"
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

CRITICAL_RUN_ID="closure_critical_only_smoke"
CRITICAL_RUN_DIR="$RESULTS_DIR/$PREFIX/$CRITICAL_RUN_ID"
V61DT_RUN_ID="$CRITICAL_RUN_ID" \
V61DT_RETURN_BUNDLE_DIR="$CRITICAL_ONLY_BUNDLE_DIR" \
V61DT_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61dt_return_bundle_closure_replay_gate.sh" >/dev/null

python3 - "$CRITICAL_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
    "closure_stage_rows": "15",
    "ready_closure_stage_rows": "5",
    "blocked_closure_stage_rows": "10",
    "schema_preflight_pass": "0",
    "return_bundle_preflight_pass": "0",
    "preflight_pass_rows": "10",
    "accepted_payload_rows": "0",
    "answer_review_accepted_rows": "0",
    "accepted_adjudication_rows": "0",
    "return_acceptance_replay_closed": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dt": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dt critical-only {field}: expected {value}, got {summary.get(field)}")
if int(summary["schema_preflight_pass_rows"]) >= 81:
    raise SystemExit("v61dt critical-only must not pass full schema preflight")

stage_rows = read_csv(run_dir / "return_bundle_closure_replay_stage_rows.csv")
ready_stage_ids = [row["closure_stage_id"] for row in stage_rows if row["status"] == "ready"]
if ready_stage_ids != [
    "01-return-bundle-supplied",
    "02-schema-preflight-surface",
    "04-schema-acceptance-handoff-audited",
    "05-acceptance-replay-surface",
    "11-full-shard-runtime-closed",
]:
    raise SystemExit(f"v61dt critical-only ready stages mismatch: {ready_stage_ids}")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["03-schema-preflight-pass", "06-full-return-preflight-pass", "15-actual-generation-ready", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dt critical-only decision should stay blocked: {gate}")
boundary = (run_dir / "V61DT_RETURN_BUNDLE_CLOSURE_REPLAY_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_bundle_dir_supplied=1",
    "preflight_pass_rows=10/81",
    "accepted_payload_rows=0/17483",
    "actual_model_generation_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dt critical-only boundary missing snippet: {snippet}")
manifest = json.loads((run_dir / "v61dt_return_bundle_closure_replay_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("ready_closure_stage_rows") != 5:
    raise SystemExit("v61dt critical-only manifest ready stage mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dt critical-only manifest must keep generation blocked")
PY

V61DT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dt_return_bundle_closure_replay_gate.sh" >/dev/null

python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    summary = list(csv.DictReader(handle))[0]
if summary.get("return_bundle_dir_supplied") != "0":
    raise SystemExit("v61dt canonical summary was not restored to no-return")
if summary.get("ready_closure_stage_rows") != "4":
    raise SystemExit("v61dt canonical ready stage rows should return to 4")
if summary.get("actual_model_generation_ready") != "0":
    raise SystemExit("v61dt canonical actual generation must remain blocked")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dt produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dt return bundle closure replay gate smoke passed"
