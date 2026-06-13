#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eb_dispatch_receipt_fixture_acceptance_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EB_REUSE_EXISTING="${V61EB_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61eb_dispatch_receipt_fixture_acceptance_gate.sh" >/dev/null

"$RUN_DIR/dispatch_receipt_fixture_acceptance_bundle/VERIFY_V61EB_FIXTURE_ACCEPTANCE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
canonical_v53ad_summary_csv = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61eb summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61eb_dispatch_receipt_fixture_acceptance_gate_ready": "1",
    "v61ea_external_review_dispatch_seal_gate_ready": "1",
    "fixture_stage_rows": "7",
    "ready_fixture_stage_rows": "5",
    "blocked_fixture_stage_rows": "2",
    "fixture_receipt_rows": "21",
    "fixture_receipt_file_rows": "21",
    "fixture_supplied_dispatch_receipt_rows": "21",
    "fixture_accepted_dispatch_receipt_rows": "21",
    "fixture_missing_dispatch_receipt_rows": "0",
    "fixture_invalid_dispatch_receipt_rows": "0",
    "fixture_dispatch_receipt_intake_ready": "1",
    "canonical_default_supplied_dispatch_receipt_rows": "0",
    "canonical_default_accepted_dispatch_receipt_rows": "0",
    "canonical_default_missing_dispatch_receipt_rows": "21",
    "canonical_default_invalid_dispatch_receipt_rows": "0",
    "canonical_default_dispatch_receipt_intake_ready": "0",
    "real_external_dispatch_receipt_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": "8",
    "fixture_invariant_pass_rows": "8",
    "fixture_bundle_file_rows": "8",
    "metadata_only_fixture_bundle_file_rows": "8",
    "checkpoint_payload_bytes_downloaded_by_v61eb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61eb {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dispatch_receipt_fixture_rows.csv",
    "dispatch_receipt_fixture_acceptance_rows.csv",
    "dispatch_receipt_fixture_file_rows.csv",
    "dispatch_receipt_fixture_canonical_restore_rows.csv",
    "dispatch_receipt_fixture_acceptance_stage_rows.csv",
    "dispatch_receipt_fixture_invariant_rows.csv",
    "dispatch_receipt_fixture_acceptance_bundle_file_rows.csv",
    "runtime_gap_rows.csv",
    "V61EB_DISPATCH_RECEIPT_FIXTURE_ACCEPTANCE_GATE_BOUNDARY.md",
    "v61eb_dispatch_receipt_fixture_acceptance_gate_manifest.json",
    "dispatch_receipt_fixture_acceptance_bundle/README.md",
    "dispatch_receipt_fixture_acceptance_bundle/VERIFY_V61EB_FIXTURE_ACCEPTANCE.sh",
    "dispatch_receipt_fixture_acceptance_bundle/DISPATCH_RECEIPT_FIXTURE_ROWS.csv",
    "dispatch_receipt_fixture_acceptance_bundle/DISPATCH_RECEIPT_FIXTURE_ACCEPTANCE_ROWS.csv",
    "dispatch_receipt_fixture_acceptance_bundle/CANONICAL_RESTORE_ROWS.csv",
    "dispatch_receipt_fixture_acceptance_bundle/FIXTURE_ACCEPTANCE_STAGES.csv",
    "dispatch_receipt_fixture_acceptance_bundle/FIXTURE_ACCEPTANCE_INVARIANTS.csv",
    "dispatch_receipt_fixture_acceptance_bundle/FIXTURE_ACCEPTANCE_MANIFEST.json",
    "source_v61ea/v61ea_external_review_dispatch_seal_gate_summary.csv",
    "source_v53ad_fixture/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "source_v53ad_fixture/complete_source_review_dispatch_receipt_status_rows.csv",
    "source_v53ad_default_before/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "source_v53ab/complete_source_review_dispatch_receipt_template_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61eb artifact: {rel}")

fixture_rows = read_csv(run_dir / "dispatch_receipt_fixture_rows.csv")
acceptance_rows = read_csv(run_dir / "dispatch_receipt_fixture_acceptance_rows.csv")
fixture_files = read_csv(run_dir / "dispatch_receipt_fixture_file_rows.csv")
restore_rows = read_csv(run_dir / "dispatch_receipt_fixture_canonical_restore_rows.csv")
stages = read_csv(run_dir / "dispatch_receipt_fixture_acceptance_stage_rows.csv")
invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "dispatch_receipt_fixture_invariant_rows.csv")}
bundle_files = read_csv(run_dir / "dispatch_receipt_fixture_acceptance_bundle_file_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(fixture_rows) != 21:
    raise SystemExit("v61eb expected 21 fixture rows")
if any(row["fixture_only"] != "1" or row["real_external_receipt"] != "0" for row in fixture_rows):
    raise SystemExit("v61eb fixture rows must be synthetic only")
if len(acceptance_rows) != 21:
    raise SystemExit("v61eb expected 21 fixture acceptance rows")
if any(row["receipt_status"] != "accepted" or row["receipt_accepted"] != "1" for row in acceptance_rows):
    raise SystemExit("v61eb fixture acceptance rows must all be accepted")
if any(row["fixture_only"] != "1" or row["real_external_receipt"] != "0" for row in acceptance_rows):
    raise SystemExit("v61eb accepted fixture rows must not become real receipts")
if len(fixture_files) != 21:
    raise SystemExit("v61eb expected 21 fixture receipt files")
if any(row["payload_class"] != "synthetic-fixture-receipt" or row["real_external_receipt"] != "0" for row in fixture_files):
    raise SystemExit("v61eb fixture receipt file class mismatch")
for row in fixture_files:
    path = run_dir / "fixture_dispatch_receipts" / row["fixture_receipt_artifact"]
    if not path.is_file() or row["sha256"] != sha256(path):
        raise SystemExit(f"v61eb fixture receipt hash mismatch: {row['fixture_receipt_artifact']}")

if restore_rows[0]["status"] != "pass":
    raise SystemExit("v61eb canonical restore row should pass")
canonical = read_csv(canonical_v53ad_summary_csv)[0]
if canonical["accepted_dispatch_receipt_rows"] != "0" or canonical["missing_dispatch_receipt_rows"] != "21":
    raise SystemExit("v61eb did not leave canonical v53ad summary restored")

if [row["stage_id"] for row in stages] != [
    "01-bind-v61ea-dispatch-seal",
    "02-generate-21-fixture-receipts",
    "03-run-v53ad-fixture-intake",
    "04-restore-canonical-no-receipt",
    "05-keep-fixture-non-real",
    "06-real-dispatch-receipts-returned",
    "07-review-generation-return",
]:
    raise SystemExit("v61eb stage order mismatch")
if sum(row["status"] == "ready" for row in stages) != 5:
    raise SystemExit("v61eb expected five ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61eb expected two blocked stages")

for invariant_id in [
    "v61ea-dispatch-seal-ready",
    "fixture-receipt-files-generated",
    "fixture-v53ad-accepts-all-receipts",
    "canonical-default-restored",
    "fixture-not-real-external-evidence",
    "review-return-still-blocked",
    "generation-still-blocked",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61eb invariant should pass: {invariant_id}")

if len(bundle_files) != 8:
    raise SystemExit("v61eb expected eight bundle files")
if any(row["payload_class"] != "metadata-only" for row in bundle_files):
    raise SystemExit("v61eb bundle files must be metadata-only")

for gate in [
    "v61ea-dispatch-seal",
    "fixture-receipt-generation",
    "fixture-v53ad-dispatch-receipt-intake",
    "canonical-default-restore",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61eb decision should pass: {gate}")
for gate in [
    "real-dispatch-receipts",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-model-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61eb decision should stay blocked: {gate}")

if gaps["fixture-dispatch-receipt-intake"] != "ready":
    raise SystemExit("v61eb fixture intake gap should be ready")
for gap in [
    "real-dispatch-receipts",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61eb gap should stay blocked: {gap}")

boundary = (run_dir / "V61EB_DISPATCH_RECEIPT_FIXTURE_ACCEPTANCE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "fixture_accepted_dispatch_receipt_rows=21",
    "canonical_default_accepted_dispatch_receipt_rows=0",
    "real_external_dispatch_receipt_rows=0",
    "accepted_human_review_rows=0/7000",
    "generation_execution_admitted_rows=0/1000",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61eb boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61eb_dispatch_receipt_fixture_acceptance_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61eb_dispatch_receipt_fixture_acceptance_gate_ready") != 1:
    raise SystemExit("v61eb manifest readiness mismatch")
if manifest.get("fixture_accepted_dispatch_receipt_rows") != 21:
    raise SystemExit("v61eb manifest fixture accepted rows mismatch")
if manifest.get("real_external_dispatch_receipt_rows") != 0:
    raise SystemExit("v61eb manifest must keep real external receipts at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61eb manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61eb manifest must keep repo payload zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61eb sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61eb produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61eb dispatch receipt fixture acceptance gate smoke passed"
