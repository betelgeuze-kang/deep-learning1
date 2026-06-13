#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61et_real_generation_intake_return_bundle_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
FIXTURE_BUNDLE_DIR="$RESULTS_DIR/$PREFIX/fixture_return_bundle_input"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_return_bundle_preflight_v61et"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61ER_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null
V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null
V61ES_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null

V61ET_REUSE_EXISTING="${V61ET_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

rm -rf "$FIXTURE_BUNDLE_DIR"
mkdir -p \
  "$FIXTURE_BUNDLE_DIR/dispatch_receipt" \
  "$FIXTURE_BUNDLE_DIR/generation_result_return" \
  "$FIXTURE_BUNDLE_DIR/prerequisite_binding" \
  "$FIXTURE_BUNDLE_DIR/review_return_provenance"

python3 - "$ROOT_DIR" "$FIXTURE_BUNDLE_DIR" <<'PY'
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
bundle = Path(sys.argv[2])
receipt_src = root / "results/v61er_real_generation_intake_dispatch_receipt_preflight/fixture_dispatch_receipt_preflight_v61er/supplied_dispatch_receipt/DISPATCH_RECEIPT.json"
gen_src = root / "results/v61ej_real_generation_return_receiver_preflight/fixture_preflight_v61ej/supplied_generation_result_return"
binding_src = root / "results/v61el_real_prerequisite_binding_receiver_preflight/fixture_binding_preflight_v61el/selected_prerequisite_binding"
shutil.copy2(receipt_src, bundle / "dispatch_receipt/DISPATCH_RECEIPT.json")
for path in gen_src.iterdir():
    if path.is_file():
        shutil.copy2(path, bundle / "generation_result_return" / path.name)
for path in binding_src.iterdir():
    if path.is_file():
        shutil.copy2(path, bundle / "prerequisite_binding" / path.name)
(bundle / "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json").write_text(
    json.dumps(
        {
            "provenance_class": "fixture-v61et-return-bundle",
            "review_return_source": "fixture-v61ed",
            "accepted_as_real": 0,
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY

V61ET_RUN_ID="fixture_return_bundle_preflight_v61et" \
V61ET_RETURN_BUNDLE_DIR="$FIXTURE_BUNDLE_DIR" \
V61ET_RETURN_BUNDLE_PROVENANCE="fixture-v61et-return-bundle" \
V61ET_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

V61ET_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

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
    "v61et_real_generation_intake_return_bundle_preflight_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "selected_bundle_source_class": "none",
    "required_return_bundle_files": "10",
    "present_return_bundle_files": "0",
    "return_bundle_family_rows": "4",
    "ready_return_bundle_family_rows": "0",
    "template_named_return_bundle_files": "0",
    "payload_like_return_bundle_files": "0",
    "return_bundle_candidate_preflight_ready": "0",
    "non_fixture_return_bundle": "0",
    "real_return_bundle_provenance_asserted": "0",
    "real_return_bundle_preflight_ready": "0",
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61et": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61et {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_intake_return_bundle_file_rows.csv",
    "real_generation_intake_return_bundle_family_rows.csv",
    "real_generation_intake_return_bundle_requirement_rows.csv",
    "real_generation_intake_return_bundle_command_rows.csv",
    "runtime_gap_rows.csv",
    "V61ET_REAL_GENERATION_INTAKE_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md",
    "v61et_real_generation_intake_return_bundle_preflight_manifest.json",
    "source_summaries/v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv",
    "source_contracts/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv",
    "source_contracts/PREREQUISITE_BINDING_CONTRACT.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61et artifact: {rel}")

files = read_csv(run_dir / "real_generation_intake_return_bundle_file_rows.csv")
if len(files) != 10 or any(row["file_exists"] != "0" for row in files):
    raise SystemExit("v61et canonical file rows should show 0/10 present")

fixture_summary = read_csv(fixture_run_dir / "real_generation_intake_return_bundle_requirement_rows.csv")
fixture_requirements = {row["requirement_id"]: row["status"] for row in fixture_summary}
for req in [
    "return-bundle-dir-supplied",
    "return-bundle-dir-exists",
    "required-files-present",
    "family-preflight-ready",
    "no-template-names",
    "no-payload-like-files",
    "return-bundle-candidate-preflight",
]:
    if fixture_requirements[req] != "pass":
        raise SystemExit(f"v61et fixture requirement should pass: {req}")
for req in [
    "non-fixture-return-bundle",
    "real-return-bundle-provenance",
    "real-return-bundle-preflight",
    "downstream-row-acceptance",
    "actual-generation",
]:
    if fixture_requirements[req] != "blocked":
        raise SystemExit(f"v61et fixture requirement should stay blocked: {req}")

fixture_metric = read_csv(fixture_run_dir / "sha256_manifest.csv")
if not fixture_metric:
    raise SystemExit("v61et fixture did not produce hash rows")
fixture_selected = fixture_run_dir / "selected_return_bundle"
for rel in [
    "dispatch_receipt/DISPATCH_RECEIPT.json",
    "generation_result_return/real_model_generation_answer_rows.csv",
    "prerequisite_binding/v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json",
]:
    if not (fixture_selected / rel).is_file():
        raise SystemExit(f"v61et fixture did not copy selected bundle file: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61et repo payload decision should pass")
for gate in [
    "return-bundle-candidate-preflight",
    "non-fixture-return-bundle",
    "real-return-bundle-provenance",
    "real-return-bundle-preflight",
    "downstream-row-acceptance",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61et canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61ET_REAL_GENERATION_INTAKE_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_bundle_dir_supplied=0",
    "present_return_bundle_files=0/10",
    "return_bundle_candidate_preflight_ready=0",
    "real_return_bundle_preflight_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61et boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61et_real_generation_intake_return_bundle_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61et_real_generation_intake_return_bundle_preflight_ready") != 1:
    raise SystemExit("v61et manifest readiness mismatch")
if manifest.get("real_return_bundle_preflight_ready") != 0:
    raise SystemExit("v61et canonical manifest must keep real bundle blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61et manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61et sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61et produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61et real generation intake return bundle preflight smoke passed"
