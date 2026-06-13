#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ec_review_chunk_return_fixture_acceptance_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EC_REUSE_EXISTING="${V61EC_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ec_review_chunk_return_fixture_acceptance_gate.sh" >/dev/null

"$RUN_DIR/review_chunk_return_fixture_acceptance_bundle/VERIFY_V61EC_FIXTURE_ACCEPTANCE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/v53x_complete_source_review_chunk_return_intake_summary.csv" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
canonical_v53x_summary_csv = Path(sys.argv[4])


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
    raise SystemExit(f"expected one v61ec summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61ec_review_chunk_return_fixture_acceptance_gate_ready": "1",
    "v61eb_dispatch_receipt_fixture_acceptance_gate_ready": "1",
    "fixture_stage_rows": "8",
    "ready_fixture_stage_rows": "6",
    "blocked_fixture_stage_rows": "2",
    "fixture_chunk_return_artifact_rows": "50",
    "fixture_chunk_return_file_rows": "50",
    "fixture_aggregate_review_return_artifact_rows": "5",
    "fixture_aggregate_review_return_file_rows": "5",
    "fixture_file_rows": "55",
    "fixture_supplied_chunk_return_artifact_rows": "50",
    "fixture_accepted_chunk_return_artifact_rows": "50",
    "fixture_missing_chunk_return_artifact_rows": "0",
    "fixture_invalid_chunk_return_artifact_rows": "0",
    "fixture_ready_review_chunk_return_rows": "21",
    "fixture_expected_human_review_rows": "7000",
    "fixture_accepted_human_review_rows": "7000",
    "fixture_expected_adjudication_rows": "1000",
    "fixture_accepted_adjudication_rows": "1000",
    "fixture_expected_reviewer_identity_rows": "21",
    "fixture_accepted_reviewer_identity_rows": "21",
    "fixture_expected_conflict_disclosure_rows": "210",
    "fixture_accepted_conflict_disclosure_rows": "210",
    "fixture_supplied_aggregate_review_return_artifact_rows": "5",
    "fixture_accepted_aggregate_review_return_artifact_rows": "5",
    "fixture_missing_aggregate_review_return_artifact_rows": "0",
    "fixture_invalid_aggregate_review_return_artifact_rows": "0",
    "fixture_chunk_return_intake_ready": "1",
    "fixture_aggregate_review_return_ready": "1",
    "fixture_v53s_refresh_ready": "1",
    "canonical_default_supplied_chunk_return_artifact_rows": "0",
    "canonical_default_accepted_chunk_return_artifact_rows": "0",
    "canonical_default_missing_chunk_return_artifact_rows": "50",
    "canonical_default_accepted_aggregate_review_return_artifact_rows": "0",
    "canonical_default_missing_aggregate_review_return_artifact_rows": "5",
    "canonical_default_chunk_return_intake_ready": "0",
    "canonical_default_v53s_refresh_ready": "0",
    "real_external_review_chunk_return_rows": "0",
    "real_external_human_review_rows": "0",
    "real_external_adjudication_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": "11",
    "fixture_invariant_pass_rows": "11",
    "fixture_bundle_file_rows": "10",
    "metadata_only_fixture_bundle_file_rows": "10",
    "checkpoint_payload_bytes_downloaded_by_v61ec": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ec {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_chunk_return_fixture_artifact_rows.csv",
    "review_chunk_return_fixture_aggregate_rows.csv",
    "review_chunk_return_fixture_file_rows.csv",
    "review_chunk_return_fixture_acceptance_rows.csv",
    "review_chunk_return_fixture_aggregate_acceptance_rows.csv",
    "review_chunk_return_fixture_canonical_restore_rows.csv",
    "review_chunk_return_fixture_acceptance_stage_rows.csv",
    "review_chunk_return_fixture_invariant_rows.csv",
    "review_chunk_return_fixture_acceptance_bundle_file_rows.csv",
    "runtime_gap_rows.csv",
    "V61EC_REVIEW_CHUNK_RETURN_FIXTURE_ACCEPTANCE_GATE_BOUNDARY.md",
    "v61ec_review_chunk_return_fixture_acceptance_gate_manifest.json",
    "review_chunk_return_fixture_acceptance_bundle/README.md",
    "review_chunk_return_fixture_acceptance_bundle/VERIFY_V61EC_FIXTURE_ACCEPTANCE.sh",
    "review_chunk_return_fixture_acceptance_bundle/REVIEW_CHUNK_RETURN_FIXTURE_ARTIFACT_ROWS.csv",
    "review_chunk_return_fixture_acceptance_bundle/REVIEW_CHUNK_RETURN_FIXTURE_ACCEPTANCE_ROWS.csv",
    "review_chunk_return_fixture_acceptance_bundle/REVIEW_CHUNK_RETURN_FIXTURE_AGGREGATE_ROWS.csv",
    "review_chunk_return_fixture_acceptance_bundle/REVIEW_CHUNK_RETURN_FIXTURE_AGGREGATE_ACCEPTANCE_ROWS.csv",
    "review_chunk_return_fixture_acceptance_bundle/CANONICAL_RESTORE_ROWS.csv",
    "review_chunk_return_fixture_acceptance_bundle/FIXTURE_ACCEPTANCE_STAGES.csv",
    "review_chunk_return_fixture_acceptance_bundle/FIXTURE_ACCEPTANCE_INVARIANTS.csv",
    "review_chunk_return_fixture_acceptance_bundle/FIXTURE_ACCEPTANCE_MANIFEST.json",
    "source_v61eb/v61eb_dispatch_receipt_fixture_acceptance_gate_summary.csv",
    "source_v53w/review_return_chunk_artifact_rows.csv",
    "source_v53w/review_return_chunk_task_rows.csv",
    "source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "source_v53x_fixture/review_return_chunk_artifact_status_rows.csv",
    "source_v53x_fixture/review_return_aggregate_artifact_status_rows.csv",
    "source_v53x_default_before/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ec artifact: {rel}")

fixture_artifacts = read_csv(run_dir / "review_chunk_return_fixture_artifact_rows.csv")
fixture_aggregates = read_csv(run_dir / "review_chunk_return_fixture_aggregate_rows.csv")
fixture_files = read_csv(run_dir / "review_chunk_return_fixture_file_rows.csv")
acceptance_rows = read_csv(run_dir / "review_chunk_return_fixture_acceptance_rows.csv")
aggregate_acceptance_rows = read_csv(run_dir / "review_chunk_return_fixture_aggregate_acceptance_rows.csv")
restore_rows = read_csv(run_dir / "review_chunk_return_fixture_canonical_restore_rows.csv")
stages = read_csv(run_dir / "review_chunk_return_fixture_acceptance_stage_rows.csv")
invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "review_chunk_return_fixture_invariant_rows.csv")}
bundle_files = read_csv(run_dir / "review_chunk_return_fixture_acceptance_bundle_file_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(fixture_artifacts) != 50:
    raise SystemExit("v61ec expected 50 fixture artifact rows")
if any(row["fixture_only"] != "1" or row["real_external_review_return"] != "0" for row in fixture_artifacts):
    raise SystemExit("v61ec fixture artifacts must be synthetic only")
if len(fixture_aggregates) != 5:
    raise SystemExit("v61ec expected five fixture aggregate rows")
if any(row["fixture_only"] != "1" or row["real_external_review_return"] != "0" for row in fixture_aggregates):
    raise SystemExit("v61ec fixture aggregate artifacts must be synthetic only")
if len(acceptance_rows) != 50:
    raise SystemExit("v61ec expected 50 chunk acceptance rows")
if any(row["current_status"] != "accepted" for row in acceptance_rows):
    raise SystemExit("v61ec all fixture chunk artifacts should be accepted")
if any(row["fixture_only"] != "1" or row["real_external_review_return"] != "0" for row in acceptance_rows):
    raise SystemExit("v61ec accepted chunk rows must not become real evidence")
if len(aggregate_acceptance_rows) != 5:
    raise SystemExit("v61ec expected five aggregate acceptance rows")
if any(row["current_status"] != "accepted" for row in aggregate_acceptance_rows):
    raise SystemExit("v61ec all fixture aggregate artifacts should be accepted")
if len([row for row in fixture_files if row["fixture_relative_path"].startswith("chunks/")]) != 50:
    raise SystemExit("v61ec expected 50 chunk fixture files")
if len([row for row in fixture_files if row["fixture_relative_path"] in {"human_review_rows.csv", "adjudication_rows.csv", "reviewer_identity_rows.csv", "reviewer_conflict_rows.csv", "acceptance_summary.json"}]) != 5:
    raise SystemExit("v61ec expected five aggregate fixture files")
if any(row["payload_class"] != "synthetic-review-return-fixture" or row["real_external_review_return"] != "0" for row in fixture_files):
    raise SystemExit("v61ec fixture file class mismatch")

for row in fixture_files:
    path = run_dir / "fixture_review_chunk_returns" / row["fixture_relative_path"]
    if not path.is_file() or row["sha256"] != sha256(path):
        raise SystemExit(f"v61ec fixture file hash mismatch: {row['fixture_relative_path']}")

if restore_rows[0]["status"] != "pass":
    raise SystemExit("v61ec canonical restore row should pass")
canonical = read_csv(canonical_v53x_summary_csv)[0]
if canonical["accepted_chunk_return_artifact_rows"] != "0" or canonical["missing_chunk_return_artifact_rows"] != "50":
    raise SystemExit("v61ec did not leave canonical v53x summary restored")

if [row["stage_id"] for row in stages] != [
    "01-bind-v61eb-receipt-fixture-gate",
    "02-generate-50-chunk-return-fixtures",
    "03-generate-5-aggregate-return-fixtures",
    "04-run-v53x-fixture-intake",
    "05-prove-v53s-refresh-shape-ready",
    "06-restore-canonical-no-review-return",
    "07-real-review-return-received",
    "08-actual-generation-after-review",
]:
    raise SystemExit("v61ec stage order mismatch")
if sum(row["status"] == "ready" for row in stages) != 6:
    raise SystemExit("v61ec expected six ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61ec expected two blocked stages")

for invariant_id in [
    "v61eb-receipt-fixture-ready",
    "fixture-chunk-artifact-files-generated",
    "fixture-aggregate-artifact-files-generated",
    "fixture-v53x-accepts-all-chunk-artifacts",
    "fixture-v53x-accepts-all-aggregate-artifacts",
    "fixture-row-totals-match-v53w",
    "canonical-default-restored",
    "fixture-not-real-external-evidence",
    "real-review-return-still-blocked",
    "generation-still-blocked",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61ec invariant should pass: {invariant_id}")

if len(bundle_files) != 10:
    raise SystemExit("v61ec expected ten bundle files")
if any(row["payload_class"] != "metadata-only" for row in bundle_files):
    raise SystemExit("v61ec bundle files must be metadata-only")

for gate in [
    "v61eb-receipt-fixture-gate",
    "fixture-review-chunk-return-generation",
    "fixture-v53x-review-chunk-intake",
    "fixture-v53s-refresh-shape",
    "canonical-default-restore",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ec decision should pass: {gate}")
for gate in [
    "real-review-chunk-returns",
    "real-review-return-accepted",
    "generation-execution-admitted",
    "actual-model-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ec decision should stay blocked: {gate}")

for gap in ["fixture-review-chunk-return-intake", "fixture-v53s-refresh-shape"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ec gap should be ready: {gap}")
for gap in [
    "real-review-chunk-returns",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ec gap should stay blocked: {gap}")

boundary = (run_dir / "V61EC_REVIEW_CHUNK_RETURN_FIXTURE_ACCEPTANCE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "fixture_accepted_chunk_return_artifact_rows=50/50",
    "fixture_accepted_aggregate_review_return_artifact_rows=5/5",
    "fixture_v53s_refresh_ready=1",
    "canonical_default_accepted_chunk_return_artifact_rows=0",
    "real_external_review_chunk_return_rows=0",
    "accepted_human_review_rows=0/7000",
    "generation_execution_admitted_rows=0/1000",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ec boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ec_review_chunk_return_fixture_acceptance_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ec_review_chunk_return_fixture_acceptance_gate_ready") != 1:
    raise SystemExit("v61ec manifest readiness mismatch")
if manifest.get("fixture_accepted_chunk_return_artifact_rows") != 50:
    raise SystemExit("v61ec manifest fixture chunk accepted rows mismatch")
if manifest.get("fixture_accepted_aggregate_review_return_artifact_rows") != 5:
    raise SystemExit("v61ec manifest fixture aggregate accepted rows mismatch")
if manifest.get("real_external_review_chunk_return_rows") != 0:
    raise SystemExit("v61ec manifest must keep real external review returns at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ec manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ec manifest must keep repo payload zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ec sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ec produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ec review chunk return fixture acceptance gate smoke passed"
