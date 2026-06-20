#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53j_complete_source_ah_answer_citation_resource_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v53j_complete_source_ah_answer_citation_resource_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53j_complete_source_ah_answer_citation_resource_intake_decision.csv"

V53J_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53j_complete_source_ah_answer_citation_resource_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

SYSTEM_IDS = set("ABCDEFGH")
CORE_SYSTEM_IDS = {"A", "B", "C", "D", "E", "G", "H"}


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
    raise SystemExit(f"expected one v53j summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53j_complete_source_ah_intake_ready": "1",
    "v53_ready": "0",
    "v53i_complete_source_query_instantiation_ready": "1",
    "complete_source_query_rows_ready": "1",
    "complete_source_query_rows": "1000",
    "complete_source_span_rows": "1000",
    "target_system_count": "8",
    "required_core_system_count": "7",
    "optional_system_count": "1",
    "core_target_answer_rows": "7000",
    "core_target_resource_rows": "7000",
    "core_minimum_target_citation_rows": "7000",
    "optional_f_target_answer_rows": "0",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "f_required_for_core_close": "0",
    "supplied_evidence_dir_present": "0",
    "supplied_answer_rows": "0",
    "supplied_citation_rows": "0",
    "supplied_resource_rows": "0",
    "valid_answer_rows": "0",
    "valid_citation_rows": "0",
    "valid_resource_rows": "0",
    "valid_core_answer_rows": "0",
    "valid_core_citation_rows": "0",
    "valid_core_resource_rows": "0",
    "required_core_systems_ready": "0",
    "required_core_citations_ready": "0",
    "required_core_resources_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53j {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "complete-source-v53i-query-input",
    "answer-citation-resource-intake-schema",
    "a-b-c-d-e-g-h-system-target-matrix",
    "f-optional-final-disposition",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53j gate should pass: {gate}")
for gate in [
    "supplied-core-answer-rows",
    "source-citation-coverage",
    "resource-measurement-coverage",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53j gate should remain blocked: {gate}")

required_files = [
    "complete_source_ah_system_target_rows.csv",
    "complete_source_answer_row_required_schema.csv",
    "complete_source_citation_row_required_schema.csv",
    "complete_source_resource_row_required_schema.csv",
    "complete_source_core_answer_row_template.csv",
    "complete_source_core_resource_row_template.csv",
    "complete_source_optional_f_final_rows.csv",
    "complete_source_ah_supplied_validation_rows.csv",
    "complete_source_ah_validation_error_rows.csv",
    "V53J_COMPLETE_SOURCE_AH_INTAKE_BOUNDARY.md",
    "v53j_complete_source_ah_answer_citation_resource_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
    "source_v52y/f_optional_final_rows.csv",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53j artifact: {rel}")

queries = read_csv(run_dir / "source_v53i/complete_source_query_rows.csv")
spans = read_csv(run_dir / "source_v53i/complete_source_span_rows.csv")
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53j should bind the v53i 1000 query/span set")
query_ids = {row["query_id"] for row in queries}

system_rows = read_csv(run_dir / "complete_source_ah_system_target_rows.csv")
if len(system_rows) != 8 or {row["system_id"] for row in system_rows} != SYSTEM_IDS:
    raise SystemExit("v53j should target A-H systems")
for row in system_rows:
    if row["system_id"] in CORE_SYSTEM_IDS:
        if row["requirement"] != "required-core" or row["target_answer_rows"] != "1000" or row["required_for_core_close"] != "1":
            raise SystemExit(f"v53j core target mismatch: {row['system_id']}")
    if row["system_id"] == "F":
        if row["requirement"] != "optional-final-policy" or row["target_answer_rows"] != "0" or row["required_for_core_close"] != "0":
            raise SystemExit("v53j F should be optional final policy, not core")
        if row["status"] != "deferred-with-reason-final":
            raise SystemExit("v53j F status should reflect v52y final deferral")

answer_schema = {row["field"] for row in read_csv(run_dir / "complete_source_answer_row_required_schema.csv")}
for field in ["answer_id", "system_id", "query_id", "answer_text", "answer_text_sha256", "resource_row_id"]:
    if field not in answer_schema:
        raise SystemExit(f"v53j answer schema missing {field}")
citation_schema = {row["field"] for row in read_csv(run_dir / "complete_source_citation_row_required_schema.csv")}
for field in ["citation_id", "answer_id", "source_span_id", "source_file_sha256", "citation_text_sha256"]:
    if field not in citation_schema:
        raise SystemExit(f"v53j citation schema missing {field}")
resource_schema = {row["field"] for row in read_csv(run_dir / "complete_source_resource_row_required_schema.csv")}
for field in ["resource_row_id", "latency_ms", "external_model_used", "model_name", "hardware_or_endpoint"]:
    if field not in resource_schema:
        raise SystemExit(f"v53j resource schema missing {field}")

answers = read_csv(run_dir / "complete_source_core_answer_row_template.csv")
resources = read_csv(run_dir / "complete_source_core_resource_row_template.csv")
if len(answers) != 7000 or len(resources) != 7000:
    raise SystemExit("v53j should write 7000 core answer/resource template rows")
if {row["system_id"] for row in answers} != CORE_SYSTEM_IDS:
    raise SystemExit("v53j core answer templates should cover A/B/C/D/E/G/H only")
if {row["query_id"] for row in answers} != query_ids:
    raise SystemExit("v53j core answer templates should cover every v53i query")
if any(row["status"] != "missing-supplied-output" for row in answers):
    raise SystemExit("v53j default answer templates should remain missing")
if any(row["required_for_core_close"] != "1" for row in answers):
    raise SystemExit("v53j core template rows should be required")

f_rows = read_csv(run_dir / "complete_source_optional_f_final_rows.csv")
if len(f_rows) != 1:
    raise SystemExit("v53j should emit one optional F final row")
f_row = f_rows[0]
if f_row["f_optional_final_disposition"] != "deferred-with-reason-final":
    raise SystemExit("v53j should bind F final disposition from v52y")
if f_row["required_for_core_close"] != "0" or f_row["target_answer_rows_required_for_v53j"] != "0":
    raise SystemExit("v53j F should not be required in default no-F path")
if f_row["counts_as_measured_100b_plus_result"] != "0":
    raise SystemExit("v53j default F row should not count as measured 100B+ result")

validation_rows = read_csv(run_dir / "complete_source_ah_supplied_validation_rows.csv")
if len(validation_rows) != 8:
    raise SystemExit("v53j should write one validation row per system")
for row in validation_rows:
    if row["system_id"] in CORE_SYSTEM_IDS:
        if row["target_answer_rows"] != "1000" or row["valid_answer_rows"] != "0" or row["status"] != "missing-or-invalid":
            raise SystemExit(f"v53j core validation mismatch: {row['system_id']}")
    if row["system_id"] == "F":
        if row["target_answer_rows"] != "0" or row["status"] != "final-deferred-not-required":
            raise SystemExit("v53j F validation should be final-deferred-not-required")

manifest = json.loads((run_dir / "v53j_complete_source_ah_answer_citation_resource_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53j_complete_source_ah_intake_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53j manifest readiness boundary mismatch")
if manifest.get("core_target_answer_rows") != 7000 or manifest.get("valid_core_answer_rows") != 0:
    raise SystemExit("v53j manifest count mismatch")
if manifest.get("required_core_systems") != sorted(CORE_SYSTEM_IDS):
    raise SystemExit("v53j manifest core systems mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53j sha256 mismatch: {rel}")

boundary = (run_dir / "V53J_COMPLETE_SOURCE_AH_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v53i complete-source 1000-query set",
    "required_core_systems=A/B/C/D/E/G/H",
    "core_target_answer_rows=7000",
    "f_optional_final_disposition=deferred-with-reason-final",
    "Do not publish v53 completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53j boundary missing {snippet}")
PY

echo "v53j complete-source A-H answer/citation/resource intake smoke passed"
