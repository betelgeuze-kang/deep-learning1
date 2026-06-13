#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dn_residual_return_completion_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/residual_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DN_REUSE_EXISTING="${V61DN_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null

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
    "v61dn_residual_return_completion_gate_ready": "1",
    "v61dm_critical_return_acceptance_bridge_gate_ready": "1",
    "v53ak_complete_source_external_return_operator_checklist_ready": "1",
    "source_gate_rows": "2",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "completion_stage_rows": "7",
    "ready_completion_stage_rows": "2",
    "blocked_completion_stage_rows": "5",
    "completion_command_rows": "4",
    "ready_completion_command_rows": "4",
    "full_return_artifact_rows": "81",
    "critical_artifact_rows": "10",
    "residual_artifact_rows": "71",
    "dispatch_receipt_residual_rows": "21",
    "review_chunk_residual_rows": "50",
    "residual_preflight_pass_rows": "0",
    "residual_missing_rows": "71",
    "residual_completion_ready": "0",
    "critical_preflight_pass_rows": "0",
    "critical_preflight_ready": "0",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "0",
    "return_bundle_preflight_pass": "0",
    "critical_only_gap_detected": "0",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "acceptance_bridge_closed": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dn {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "residual_return_completion_rows.csv",
    "residual_return_completion_family_rows.csv",
    "residual_return_completion_stage_rows.csv",
    "residual_return_completion_command_rows.csv",
    "residual_return_completion_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DN_RESIDUAL_RETURN_COMPLETION_GATE_BOUNDARY.md",
    "v61dn_residual_return_completion_gate_manifest.json",
    "source_v61dm/v61dm_critical_return_acceptance_bridge_gate_summary.csv",
    "source_v53ak/external_return_operator_checklist_rows.csv",
    "source_v61dk/return_contract_final_bundle_crosswalk_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dn artifact: {rel}")

rows = read_csv(run_dir / "residual_return_completion_rows.csv")
families = {row["return_family"]: row for row in read_csv(run_dir / "residual_return_completion_family_rows.csv")}
stages = {row["stage_id"]: row for row in read_csv(run_dir / "residual_return_completion_stage_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
metric = read_csv(run_dir / "residual_return_completion_metric_rows.csv")[0]

if len(rows) != 71:
    raise SystemExit("v61dn residual row count mismatch")
if any(row["return_family"] not in {"dispatch-receipt", "review-chunk-return"} for row in rows):
    raise SystemExit("v61dn residual rows must be dispatch/review chunk only")
if any(row["residual_preflight_pass"] != "0" for row in rows):
    raise SystemExit("v61dn default residual rows should not pass")
if families["dispatch-receipt"]["residual_artifact_rows"] != "21":
    raise SystemExit("v61dn dispatch residual count mismatch")
if families["review-chunk-return"]["residual_artifact_rows"] != "50":
    raise SystemExit("v61dn review chunk residual count mismatch")
ready_stage_ids = {stage_id for stage_id, row in stages.items() if row["status"] == "ready"}
if ready_stage_ids != {"01-critical-surface", "03-residual-surface"}:
    raise SystemExit(f"v61dn default ready stages mismatch: {ready_stage_ids}")
for field, value in expected.items():
    if field.startswith("v61dn_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61dn metric {field}: expected {value}, got {metric[field]}")
for gate in ["01-critical-surface", "03-residual-surface", "residual-scope-is-71", "critical-only-is-still-incomplete", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dn decision should pass: {gate}")
for gate in ["02-critical-preflight-pass", "04-residual-completion", "05-full-return-preflight", "06-row-level-acceptance", "07-actual-generation-ready"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dn decision should stay blocked: {gate}")

boundary = (run_dir / "V61DN_RESIDUAL_RETURN_COMPLETION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "residual_artifact_rows=71",
    "dispatch_receipt_residual_rows=21",
    "review_chunk_residual_rows=50",
    "residual_preflight_pass_rows=0/71",
    "critical_preflight_pass_rows=0/10",
    "full_preflight_pass_rows=0/81",
    "answer_review_accepted_rows=0/7000",
    "generation_result_accepted_rows=0/1000",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61dn=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dn boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dn_residual_return_completion_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("residual_artifact_rows") != 71 or manifest.get("residual_preflight_pass_rows") != 0:
    raise SystemExit("v61dn manifest residual count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dn manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dn sha256 mismatch: {rel}")
PY

CRITICAL_ONLY_BUNDLE_DIR="$(mktemp -d /tmp/v61dn_critical_only_bundle.XXXXXX)"
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

SUPPLIED_RUN_ID="residual_critical_only_smoke"
SUPPLIED_RUN_DIR="$RESULTS_DIR/$PREFIX/$SUPPLIED_RUN_ID"
V61DN_RUN_ID="$SUPPLIED_RUN_ID" \
V61DN_RETURN_BUNDLE_DIR="$CRITICAL_ONLY_BUNDLE_DIR" \
V61DN_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null

python3 - "$SUPPLIED_RUN_DIR" "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "return_bundle_dir_supplied": "1",
    "return_bundle_dir_exists": "1",
    "ready_completion_stage_rows": "3",
    "blocked_completion_stage_rows": "4",
    "critical_preflight_pass_rows": "10",
    "critical_preflight_ready": "1",
    "residual_artifact_rows": "71",
    "residual_preflight_pass_rows": "0",
    "residual_missing_rows": "71",
    "residual_completion_ready": "0",
    "full_preflight_pass_rows": "10",
    "return_bundle_preflight_pass": "0",
    "critical_only_gap_detected": "1",
    "answer_review_accepted_rows": "0",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dn critical-only {field}: expected {value}, got {summary.get(field)}")

stages = {row["stage_id"]: row for row in read_csv(run_dir / "residual_return_completion_stage_rows.csv")}
ready_stage_ids = {stage_id for stage_id, row in stages.items() if row["status"] == "ready"}
if ready_stage_ids != {"01-critical-surface", "02-critical-preflight-pass", "03-residual-surface"}:
    raise SystemExit(f"v61dn critical-only ready stages mismatch: {ready_stage_ids}")
rows = read_csv(run_dir / "residual_return_completion_rows.csv")
if any(row["residual_preflight_pass"] != "0" for row in rows):
    raise SystemExit("v61dn critical-only residual rows should still be missing")
boundary = (run_dir / "V61DN_RESIDUAL_RETURN_COMPLETION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "residual_preflight_pass_rows=0/71",
    "critical_preflight_pass_rows=10/10",
    "full_preflight_pass_rows=10/81",
    "critical_only_gap_detected=1",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dn critical-only boundary missing snippet: {snippet}")
PY

# Restore canonical no-return summaries for upstream and this gate.
V61DL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dl_critical_return_contract_preflight_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V61DM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null
V61DN_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null

if find "$RUN_DIR" "$SUPPLIED_RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dn produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dn residual return completion gate smoke passed"
