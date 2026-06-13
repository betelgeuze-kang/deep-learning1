#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dp_return_schema_acceptance_blocker_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/schema_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DP_REUSE_EXISTING="${V61DP_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dp_return_schema_acceptance_blocker_gate.sh" >/dev/null

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
    "v61dp_return_schema_acceptance_blocker_gate_ready": "1",
    "source_gate_rows": "2",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "schema_family_rows": "4",
    "ready_schema_family_rows": "0",
    "blocked_schema_family_rows": "4",
    "schema_stage_rows": "4",
    "ready_schema_stage_rows": "0",
    "blocked_schema_stage_rows": "4",
    "expected_schema_artifact_rows": "81",
    "supplied_schema_artifact_rows": "0",
    "accepted_schema_artifact_rows": "0",
    "missing_schema_artifact_rows": "81",
    "invalid_schema_artifact_rows": "0",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
    "full_preflight_rows": "81",
    "full_preflight_pass_rows": "0",
    "return_bundle_preflight_pass": "0",
    "preflight_only_gap_detected": "0",
    "accepted_dispatch_receipt_rows": "0",
    "dispatch_receipt_template_rows": "21",
    "accepted_chunk_return_artifact_rows": "0",
    "review_chunk_return_artifact_rows": "50",
    "answer_review_accepted_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "generation_result_accepted_rows": "0",
    "generation_result_acceptance_rows": "1000",
    "actual_model_generation_ready": "0",
    "schema_acceptance_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dp {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_schema_acceptance_blocker_family_rows.csv",
    "return_schema_acceptance_blocker_stage_rows.csv",
    "return_schema_acceptance_blocker_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DP_RETURN_SCHEMA_ACCEPTANCE_BLOCKER_GATE_BOUNDARY.md",
    "v61dp_return_schema_acceptance_blocker_gate_manifest.json",
    "source_v61do/v61do_full_return_preflight_acceptance_boundary_gate_summary.csv",
    "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dp artifact: {rel}")

families = {row["acceptance_family"]: row for row in read_csv(run_dir / "return_schema_acceptance_blocker_family_rows.csv")}
if set(families) != {"dispatch-receipt-json", "review-chunk-return-csv", "aggregate-review-return", "generation-result-return"}:
    raise SystemExit("v61dp family set mismatch")
for row in families.values():
    if row["acceptance_ready"] != "0":
        raise SystemExit("v61dp default families should be blocked")
stages = read_csv(run_dir / "return_schema_acceptance_blocker_stage_rows.csv")
if any(row["status"] != "blocked" for row in stages):
    raise SystemExit("v61dp default stages should all be blocked")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["preflight-is-not-schema-acceptance", "manifest-only-no-repo-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dp decision should pass: {gate}")
boundary = (run_dir / "V61DP_RETURN_SCHEMA_ACCEPTANCE_BLOCKER_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "schema_family_rows=4",
    "ready_schema_family_rows=0",
    "blocked_schema_family_rows=4",
    "full_preflight_pass_rows=0/81",
    "return_bundle_preflight_pass=0",
    "expected_schema_artifact_rows=81",
    "supplied_schema_artifact_rows=0",
    "accepted_schema_artifact_rows=0",
    "missing_schema_artifact_rows=81",
    "invalid_schema_artifact_rows=0",
    "expected_payload_rows=17483",
    "accepted_payload_rows=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dp boundary missing snippet: {snippet}")
manifest = json.loads((run_dir / "v61dp_return_schema_acceptance_blocker_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dp manifest must keep generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dp sha256 mismatch: {rel}")
PY

FULL_PREFLIGHT_BUNDLE_DIR="$(mktemp -d /tmp/v61dp_full_preflight_bundle.XXXXXX)"
trap 'rm -rf "$FULL_PREFLIGHT_BUNDLE_DIR"' EXIT
python3 - "$ROOT_DIR" "$FULL_PREFLIGHT_BUNDLE_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
bundle = Path(sys.argv[2])
checklist = root / "results/v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_checklist_rows.csv"
with checklist.open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        path = bundle / row["final_return_bundle_relative_path"]
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix == ".json":
            path.write_text(json.dumps({"synthetic_full_preflight_only": True}) + "\n", encoding="utf-8")
        else:
            path.write_text("synthetic_full_preflight_only\n", encoding="utf-8")
PY

SUPPLIED_RUN_ID="schema_full_preflight_only_smoke"
SUPPLIED_RUN_DIR="$RESULTS_DIR/$PREFIX/$SUPPLIED_RUN_ID"
V61DP_RUN_ID="$SUPPLIED_RUN_ID" \
V61DP_RETURN_BUNDLE_DIR="$FULL_PREFLIGHT_BUNDLE_DIR" \
V61DP_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61dp_return_schema_acceptance_blocker_gate.sh" >/dev/null

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
    "schema_family_rows": "4",
    "ready_schema_family_rows": "0",
    "blocked_schema_family_rows": "4",
    "ready_schema_stage_rows": "1",
    "blocked_schema_stage_rows": "3",
    "expected_schema_artifact_rows": "81",
    "supplied_schema_artifact_rows": "31",
    "accepted_schema_artifact_rows": "0",
    "missing_schema_artifact_rows": "50",
    "invalid_schema_artifact_rows": "31",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
    "full_preflight_pass_rows": "81",
    "return_bundle_preflight_pass": "1",
    "preflight_only_gap_detected": "1",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dp full-preflight {field}: expected {value}, got {summary.get(field)}")

families = {row["acceptance_family"]: row for row in read_csv(run_dir / "return_schema_acceptance_blocker_family_rows.csv")}
checks = {
    "dispatch-receipt-json": ("21", "21", "0", "0", "21"),
    "review-chunk-return-csv": ("50", "0", "0", "50", "0"),
    "aggregate-review-return": ("5", "5", "0", "0", "5"),
    "generation-result-return": ("5", "5", "0", "0", "5"),
}
for family, (expected_rows, supplied, accepted, missing, invalid) in checks.items():
    row = families[family]
    observed = (
        row["expected_artifact_rows"],
        row["supplied_artifact_rows"],
        row["accepted_artifact_rows"],
        row["missing_artifact_rows"],
        row["invalid_artifact_rows"],
    )
    if observed != (expected_rows, supplied, accepted, missing, invalid):
        raise SystemExit(f"v61dp full-preflight family mismatch {family}: {observed}")

stages = {row["stage_id"]: row for row in read_csv(run_dir / "return_schema_acceptance_blocker_stage_rows.csv")}
if stages["01-full-file-preflight"]["status"] != "ready":
    raise SystemExit("v61dp full-preflight should mark full file preflight ready")
for stage_id in ["02-schema-family-acceptance", "03-payload-row-acceptance", "04-actual-generation-ready"]:
    if stages[stage_id]["status"] != "blocked":
        raise SystemExit(f"v61dp full-preflight stage should stay blocked: {stage_id}")

boundary = (run_dir / "V61DP_RETURN_SCHEMA_ACCEPTANCE_BLOCKER_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "full_preflight_pass_rows=81/81",
    "return_bundle_preflight_pass=1",
    "preflight_only_gap_detected=1",
    "supplied_schema_artifact_rows=31",
    "accepted_schema_artifact_rows=0",
    "missing_schema_artifact_rows=50",
    "invalid_schema_artifact_rows=31",
    "accepted_payload_rows=0",
    "actual_model_generation_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dp full-preflight boundary missing snippet: {snippet}")
PY

# Restore canonical no-return summaries for upstream and this gate.
V61DL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dl_critical_return_contract_preflight_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V61DM_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null
V61DN_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null
V61DO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61do_full_return_preflight_acceptance_boundary_gate.sh" >/dev/null
V61DP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dp_return_schema_acceptance_blocker_gate.sh" >/dev/null

if find "$RUN_DIR" "$SUPPLIED_RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dp produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dp return schema acceptance blocker gate smoke passed"
