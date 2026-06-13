#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53al_complete_source_external_return_bundle_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AL_REUSE_EXISTING="${V53AL_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
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
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "v53ak_complete_source_external_return_operator_checklist_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "preflight_surface_ready": "1",
    "return_bundle_preflight_pass": "0",
    "preflight_rows": "81",
    "preflight_pass_rows": "0",
    "preflight_file_exists_rows": "0",
    "preflight_missing_rows": "81",
    "preflight_non_empty_rows": "0",
    "preflight_template_named_rows": "0",
    "accepted_by_v53al_rows": "0",
    "family_preflight_rows": "4",
    "verifier_script_ready": "1",
    "operator_checklist_ready": "1",
    "checklist_rows": "81",
    "supplied_checklist_rows": "0",
    "missing_checklist_rows": "81",
    "accepted_by_v53ak_rows": "0",
    "send_bundle_ready": "1",
    "return_bundle_mapping_ready": "1",
    "ready_closure_item_rows": "3",
    "blocked_closure_item_rows": "9",
    "answer_review_accepted_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53al": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53al {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_return_bundle_preflight_rows.csv",
    "external_return_bundle_preflight_family_rows.csv",
    "external_return_bundle_preflight_requirement_rows.csv",
    "external_return_bundle_preflight_metric_rows.csv",
    "runtime_gap_rows.csv",
    "VERIFY_EXTERNAL_RETURN_BUNDLE_PREFLIGHT.sh",
    "EXTERNAL_RETURN_BUNDLE_PREFLIGHT.md",
    "V53AL_COMPLETE_SOURCE_EXTERNAL_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md",
    "v53al_complete_source_external_return_bundle_preflight_manifest.json",
    "source_v53ak/v53ak_complete_source_external_return_operator_checklist_summary.csv",
    "source_v53ak/external_return_operator_checklist_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53al artifact: {rel}")
if not os.access(run_dir / "VERIFY_EXTERNAL_RETURN_BUNDLE_PREFLIGHT.sh", os.X_OK):
    raise SystemExit("v53al verifier script must be executable")

preflight_rows = read_csv(run_dir / "external_return_bundle_preflight_rows.csv")
family_rows = read_csv(run_dir / "external_return_bundle_preflight_family_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "external_return_bundle_preflight_requirement_rows.csv")}
metric = read_csv(run_dir / "external_return_bundle_preflight_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(preflight_rows) != 81:
    raise SystemExit("v53al expected 81 preflight rows")
if sum(int(row["preflight_pass"]) for row in preflight_rows) != 0:
    raise SystemExit("v53al default should have zero preflight pass rows")
if sum(int(row["preflight_file_exists"]) for row in preflight_rows) != 0:
    raise SystemExit("v53al default should have zero existing files")
if sum(int(row["accepted_by_v53al"]) for row in preflight_rows) != 0:
    raise SystemExit("v53al must not accept evidence")
if len(family_rows) != 4:
    raise SystemExit("v53al expected four family rows")
for row in family_rows:
    if row["family_preflight_pass"] != "0":
        raise SystemExit(f"v53al default family should not pass: {row['return_family']}")

for field, value in expected.items():
    if field.startswith("v53al_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53al metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53ak-checklist-input",
    "preflight-row-coverage",
    "preflight-verifier",
    "no-template-named-artifacts",
    "v53al-does-not-accept-evidence",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53al requirement should pass: {requirement_id}")
for requirement_id in [
    "return-bundle-directory",
    "all-final-artifacts-present",
    "non-empty-artifacts",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53al requirement should stay blocked: {requirement_id}")

for gate in [
    "v53ak-checklist-input",
    "preflight-surface",
    "preflight-verifier",
    "no-template-named-artifacts",
    "v53al-does-not-accept-evidence",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53al decision should pass: {gate}")
for gate in [
    "return-bundle-directory",
    "all-final-artifacts-present",
    "return-bundle-preflight-pass",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53al decision should stay blocked: {gate}")

if gaps.get("preflight-surface") != "ready":
    raise SystemExit("v53al preflight surface gap should be ready")
for gap in [
    "return-bundle-directory",
    "all-final-artifacts-present",
    "return-bundle-preflight-pass",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53al gap should stay blocked: {gap}")

readme = (run_dir / "EXTERNAL_RETURN_BUNDLE_PREFLIGHT.md").read_text(encoding="utf-8")
for snippet in [
    "presence, non-empty files, and template-name rejection",
    "VERIFY_EXTERNAL_RETURN_BUNDLE_PREFLIGHT.sh /path/to/final_return_bundle",
    "Downstream gates remain authoritative",
]:
    if snippet not in readme:
        raise SystemExit(f"v53al readme missing: {snippet}")

boundary = (run_dir / "V53AL_COMPLETE_SOURCE_EXTERNAL_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "preflight_surface_ready=1",
    "return_bundle_preflight_pass=0",
    "preflight_rows=81",
    "preflight_pass_rows=0",
    "preflight_file_exists_rows=0",
    "preflight_missing_rows=81",
    "accepted_by_v53al_rows=0",
    "verifier_script_ready=1",
    "operator_checklist_ready=1",
    "checklist_rows=81",
    "answer_review_accepted_rows=0",
    "generation_execution_admitted_rows=0",
    "actual_model_generation_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "checkpoint_payload_bytes_downloaded_by_v53al=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53al boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53al_complete_source_external_return_bundle_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53al_complete_source_external_return_bundle_preflight_ready") != 1:
    raise SystemExit("v53al manifest readiness mismatch")
if manifest.get("return_bundle_preflight_pass") != 0:
    raise SystemExit("v53al manifest preflight should not pass by default")
if manifest.get("accepted_by_v53al_rows") != 0:
    raise SystemExit("v53al manifest must not accept evidence")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53al manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53al sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53al produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53al complete-source external return bundle preflight smoke passed"
