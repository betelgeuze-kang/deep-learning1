#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eu_real_generation_intake_return_bundle_fanout_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/fanout_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_bundle_fanout_v61eu"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_BUNDLE_DIR="$RESULTS_DIR/v61et_real_generation_intake_return_bundle_preflight/fixture_return_bundle_input"

V61ET_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

V61EU_REUSE_EXISTING="${V61EU_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh" >/dev/null

V61EU_RUN_ID="fixture_bundle_fanout_v61eu" \
V61EU_RETURN_BUNDLE_DIR="$FIXTURE_BUNDLE_DIR" \
V61EU_RETURN_BUNDLE_PROVENANCE="fixture-v61et-return-bundle" \
V61EU_RECEIPT_PROVENANCE="fixture-v61er-dispatch-receipt" \
V61EU_BINDING_PROVENANCE="fixture-v61et-review-return" \
V61EU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh" >/dev/null

V61EU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


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
    "v61eu_real_generation_intake_return_bundle_fanout_gate_ready": "1",
    "return_bundle_dir_supplied": "0",
    "selected_return_bundle_candidate_preflight_ready": "0",
    "selected_real_return_bundle_preflight_ready": "0",
    "selected_dispatch_receipt_candidate_preflight_ready": "0",
    "selected_real_dispatch_receipt_ready": "0",
    "selected_generation_result_receiver_preflight_ready": "0",
    "selected_real_generation_result_artifacts": "0",
    "selected_binding_candidate_preflight_ready": "0",
    "selected_real_prerequisite_binding_ready": "0",
    "fanout_candidate_preflight_ready": "0",
    "fanout_real_preflight_ready": "0",
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61eu": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61eu {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "return_bundle_fanout_stage_rows.csv",
    "return_bundle_fanout_requirement_rows.csv",
    "return_bundle_fanout_command_rows.csv",
    "V61EU_REAL_GENERATION_INTAKE_RETURN_BUNDLE_FANOUT_BOUNDARY.md",
    "v61eu_real_generation_intake_return_bundle_fanout_gate_manifest.json",
    "selected_v61et/real_generation_intake_return_bundle_requirement_rows.csv",
    "selected_v61er/real_generation_intake_dispatch_receipt_preflight_metric_rows.csv",
    "selected_v61ej/receiver_preflight_metric_rows.csv",
    "selected_v61el/prerequisite_binding_preflight_metric_rows.csv",
    "source_summaries/v61et_real_generation_intake_return_bundle_preflight_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61eu artifact: {rel}")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "return_bundle_fanout_requirement_rows.csv")}
for req in [
    "return-bundle-candidate-preflight",
    "dispatch-receipt-candidate-preflight",
    "generation-result-candidate-preflight",
    "prerequisite-binding-candidate-preflight",
    "fanout-candidate-preflight",
    "fanout-real-preflight",
    "downstream-row-acceptance",
    "actual-generation",
]:
    if requirements[req] != "blocked":
        raise SystemExit(f"v61eu canonical requirement should be blocked: {req}")

fixture_summary = read_csv(fixture_run_dir / "return_bundle_fanout_stage_rows.csv")
fixture_stages = {row["stage_id"]: row["ready"] for row in fixture_summary}
for stage in [
    "01-return-bundle-candidate",
    "02-dispatch-receipt-preflight",
    "03-generation-result-preflight",
    "04-prerequisite-binding-preflight",
    "05-fanout-candidate-preflight",
]:
    if fixture_stages[stage] != "1":
        raise SystemExit(f"v61eu fixture stage should pass: {stage}")
for stage in [
    "06-fanout-real-preflight",
    "07-downstream-row-acceptance",
    "08-actual-generation",
]:
    if fixture_stages[stage] != "0":
        raise SystemExit(f"v61eu fixture stage should stay blocked: {stage}")

fixture_manifest = json.loads((fixture_run_dir / "v61eu_real_generation_intake_return_bundle_fanout_gate_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("fanout_candidate_preflight_ready") != 1:
    raise SystemExit("v61eu fixture candidate fanout should be ready")
if fixture_manifest.get("fanout_real_preflight_ready") != 0:
    raise SystemExit("v61eu fixture real fanout must stay blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61eu repo payload decision should pass")
for gate in ["return-bundle-candidate-preflight", "downstream-candidate-fanout", "real-evidence-fanout", "downstream-row-acceptance", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61eu canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61EU_REAL_GENERATION_INTAKE_RETURN_BUNDLE_FANOUT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_bundle_dir_supplied=0",
    "fanout_candidate_preflight_ready=0",
    "fanout_real_preflight_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61eu boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61eu_real_generation_intake_return_bundle_fanout_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61eu_real_generation_intake_return_bundle_fanout_gate_ready") != 1:
    raise SystemExit("v61eu manifest readiness mismatch")
if manifest.get("fanout_real_preflight_ready") != 0:
    raise SystemExit("v61eu canonical manifest must keep real fanout blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61eu manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61eu sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61eu produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61eu real generation intake return bundle fanout gate smoke passed"
