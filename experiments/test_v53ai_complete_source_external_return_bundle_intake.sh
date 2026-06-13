#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ai_complete_source_external_return_bundle_intake"
RUN_DIR="$RESULTS_DIR/$PREFIX/intake_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AI_REUSE_EXISTING="${V53AI_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ai_complete_source_external_return_bundle_intake.sh" >/dev/null

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
    "v53ai_complete_source_external_return_bundle_intake_ready": "1",
    "v53ah_complete_source_external_review_send_bundle_ready": "1",
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "dispatch_receipt_dir_supplied": "0",
    "dispatch_receipt_dir_exists": "0",
    "review_chunk_return_dir_supplied": "0",
    "review_chunk_return_dir_exists": "0",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "generation_result_dir_supplied": "0",
    "generation_result_dir_exists": "0",
    "standard_return_family_rows": "4",
    "required_return_artifact_rows": "81",
    "supplied_return_artifact_rows": "0",
    "missing_return_artifact_rows": "81",
    "template_named_supplied_rows": "0",
    "accepted_by_v53ai_rows": "0",
    "return_bundle_mapping_ready": "1",
    "all_return_artifacts_present": "0",
    "send_bundle_ready": "1",
    "send_bundle_archive_files": "2",
    "nested_payload_like_archive_member_rows": "0",
    "return_inbox_final_evidence_named_archive_member_rows": "0",
    "rendezvous_stage_rows": "9",
    "ready_rendezvous_stage_rows": "3",
    "blocked_rendezvous_stage_rows": "6",
    "accepted_dispatch_receipt_rows": "0",
    "accepted_chunk_return_artifact_rows": "0",
    "answer_review_accepted_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ai": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ai {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_return_bundle_artifact_mapping_rows.csv",
    "external_return_bundle_family_rows.csv",
    "external_return_bundle_intake_requirement_rows.csv",
    "external_return_bundle_intake_metric_rows.csv",
    "runtime_gap_rows.csv",
    "RECEIVE_EXTERNAL_RETURN_BUNDLE.md",
    "V53AI_COMPLETE_SOURCE_EXTERNAL_RETURN_BUNDLE_INTAKE_BOUNDARY.md",
    "v53ai_complete_source_external_return_bundle_intake_manifest.json",
    "source_v53ah/v53ah_complete_source_external_review_send_bundle_summary.csv",
    "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv",
    "source_v53af/external_return_required_artifact_index_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ai artifact: {rel}")

artifact_rows = read_csv(run_dir / "external_return_bundle_artifact_mapping_rows.csv")
family_rows = read_csv(run_dir / "external_return_bundle_family_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "external_return_bundle_intake_requirement_rows.csv")}
metric = read_csv(run_dir / "external_return_bundle_intake_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(artifact_rows) != 81:
    raise SystemExit("v53ai expected 81 return artifact mapping rows")
if sum(int(row["return_artifact_supplied"]) for row in artifact_rows) != 0:
    raise SystemExit("v53ai default smoke should supply zero return artifacts")
if sum(int(row["accepted_by_v53ai"]) for row in artifact_rows) != 0:
    raise SystemExit("v53ai must not accept artifacts itself")
if sum(int(row["template_named_supplied"]) for row in artifact_rows) != 0:
    raise SystemExit("v53ai default should have zero supplied template-named files")
family_expected = {
    "dispatch-receipt": "21",
    "review-chunk-return": "50",
    "aggregate-review-return": "5",
    "generation-result-return": "5",
}
if len(family_rows) != 4:
    raise SystemExit("v53ai expected four return family rows")
for row in family_rows:
    if row["expected_artifact_rows"] != family_expected[row["return_family"]]:
        raise SystemExit(f"v53ai family count mismatch for {row['return_family']}")
    if row["supplied_artifact_rows"] != "0" or row["family_complete_by_presence"] != "0":
        raise SystemExit(f"v53ai family should be missing by default: {row['return_family']}")

for field, value in expected.items():
    if field.startswith("v53ai_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ai metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53ah-send-bundle-input",
    "v53af-required-artifact-index",
    "template-files-not-accepted",
    "v53ae-rendezvous-refresh",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ai requirement should pass: {requirement_id}")
for requirement_id in [
    "return-bundle-directory",
    "all-return-artifacts-present",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ai requirement should stay blocked: {requirement_id}")

for gate in [
    "v53ah-send-bundle-input",
    "required-artifact-index",
    "template-files-not-accepted",
    "v53ae-rendezvous-refresh",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ai decision should pass: {gate}")
for gate in [
    "return-bundle-directory",
    "all-return-artifacts-present",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ai decision should stay blocked: {gate}")

if gaps.get("return-bundle-intake-surface") != "ready":
    raise SystemExit("v53ai intake surface gap should be ready")
for gap in [
    "return-bundle-directory",
    "all-return-artifacts-present",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ai gap should stay blocked: {gap}")

readme = (run_dir / "RECEIVE_EXTERNAL_RETURN_BUNDLE.md").read_text(encoding="utf-8")
for snippet in [
    "dispatch_receipts/",
    "review_chunk_returns/chunks/...",
    "aggregate_review_return/",
    "generation_result_return/",
    "V53AI_RETURN_BUNDLE_DIR=/path/to/final_return_bundle",
]:
    if snippet not in readme:
        raise SystemExit(f"v53ai receive readme missing: {snippet}")

boundary = (run_dir / "V53AI_COMPLETE_SOURCE_EXTERNAL_RETURN_BUNDLE_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "required_return_artifact_rows=81",
    "supplied_return_artifact_rows=0",
    "missing_return_artifact_rows=81",
    "template_named_supplied_rows=0",
    "accepted_by_v53ai_rows=0",
    "return_bundle_mapping_ready=1",
    "all_return_artifacts_present=0",
    "send_bundle_ready=1",
    "rendezvous_stage_rows=9",
    "ready_rendezvous_stage_rows=3",
    "blocked_rendezvous_stage_rows=6",
    "answer_review_accepted_rows=0",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "checkpoint_payload_bytes_downloaded_by_v53ai=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ai boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ai_complete_source_external_return_bundle_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ai_complete_source_external_return_bundle_intake_ready") != 1:
    raise SystemExit("v53ai manifest readiness mismatch")
if manifest.get("required_return_artifact_rows") != 81:
    raise SystemExit("v53ai manifest required count mismatch")
if manifest.get("supplied_return_artifact_rows") != 0:
    raise SystemExit("v53ai manifest supplied count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ai manifest must keep actual generation blocked")
if manifest.get("full_shard_prerequisites_closed") != 1:
    raise SystemExit("v53ai manifest should inherit full-shard closure")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ai sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ai produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ai complete-source external return bundle intake smoke passed"
