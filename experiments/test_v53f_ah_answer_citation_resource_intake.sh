#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53f_ah_answer_citation_resource_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v53f_ah_answer_citation_resource_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53f_ah_answer_citation_resource_intake_decision.csv"

"$ROOT_DIR/experiments/run_v53f_ah_answer_citation_resource_intake.sh" >/dev/null

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
    raise SystemExit(f"expected one v53f summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v53e_canary_query_scale_ready") == "0":
    expected_blocked = {
        "v53f_ah_answer_citation_resource_intake_ready": "1",
        "v53_ready": "0",
        "frozen_query_rows": "0",
        "target_system_count": "8",
        "required_core_system_count": "7",
        "optional_system_count": "1",
        "target_answer_rows": "0",
        "target_resource_rows": "0",
        "minimum_target_citation_rows": "0",
        "supplied_evidence_dir_present": "0",
        "supplied_answer_rows": "0",
        "supplied_citation_rows": "0",
        "supplied_resource_rows": "0",
        "valid_answer_rows": "0",
        "valid_citation_rows": "0",
        "valid_resource_rows": "0",
        "required_core_systems_ready": "0",
        "optional_system_f_ready": "0",
        "answer_citation_resource_rows_ready": "0",
        "complete_source_snapshot_ready": "0",
        "review_artifacts_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v53f blocked {field}: expected {value}, got {summary.get(field)}")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    for gate in ["answer-citation-resource-intake-schema", "a-h-system-target-matrix"]:
        if decisions.get(gate) != "pass":
            raise SystemExit(f"v53f blocked path should keep schema gate pass: {gate}")
    for gate in [
        "frozen-v53e-query-input",
        "supplied-a-h-answer-rows",
        "source-citation-coverage",
        "resource-measurement-coverage",
        "full-source-snapshot-scale",
        "human-review-artifacts",
        "v53-full-public-repo-audit",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v53f blocked path should keep {gate} blocked")

    required_files = [
        "ah_system_target_rows.csv",
        "answer_row_required_schema.csv",
        "citation_row_required_schema.csv",
        "resource_row_required_schema.csv",
        "ah_answer_row_template.csv",
        "ah_resource_row_template.csv",
        "ah_supplied_validation_rows.csv",
        "ah_validation_error_rows.csv",
        "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md",
        "v53f_ah_answer_citation_resource_intake_manifest.json",
        "sha256_manifest.csv",
        "source_v53e/scaled_canary_query_rows.csv",
        "source_v53e/scaled_canary_source_span_rows.csv",
        "source_v53e/scaled_canary_query_family_rows.csv",
        "source_v53e/scaled_canary_query_repo_rows.csv",
        "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
        "source_v53e/v53e_canary_query_scale_1000_manifest.json",
        "source_v53e/sha256_manifest.csv",
        "source_v53e/v53e_canary_query_scale_1000_summary.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v53f blocked artifact: {rel}")
    system_rows = read_csv(run_dir / "ah_system_target_rows.csv")
    if len(system_rows) != 8 or {row["system_id"] for row in system_rows} != SYSTEM_IDS:
        raise SystemExit("v53f blocked path should still emit A-H target schema rows")
    if read_csv(run_dir / "ah_answer_row_template.csv") or read_csv(run_dir / "ah_resource_row_template.csv"):
        raise SystemExit("v53f blocked path should not fabricate answer/resource templates without frozen queries")
    validation_rows = read_csv(run_dir / "ah_supplied_validation_rows.csv")
    if len(validation_rows) != 8 or any(row["status"] != "missing-or-invalid" for row in validation_rows):
        raise SystemExit("v53f blocked path should keep validation rows missing")
    manifest = json.loads((run_dir / "v53f_ah_answer_citation_resource_intake_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v53f_ah_answer_citation_resource_intake_ready") != 1 or manifest.get("frozen_query_rows") != 0:
        raise SystemExit("v53f blocked manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v53f blocked sha256 mismatch: {rel}")
    boundary = (run_dir / "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
    for snippet in ["frozen_query_rows=0", "target_answer_rows=0", "valid_answer_rows=0", "answer_citation_resource_rows_ready=0"]:
        if snippet not in boundary:
            raise SystemExit(f"v53f blocked boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v53f_ah_answer_citation_resource_intake_ready": "1",
    "v53_ready": "0",
    "frozen_query_rows": "1000",
    "target_system_count": "8",
    "required_core_system_count": "7",
    "optional_system_count": "1",
    "target_answer_rows": "8000",
    "target_resource_rows": "8000",
    "minimum_target_citation_rows": "8000",
    "supplied_evidence_dir_present": "0",
    "supplied_answer_rows": "0",
    "supplied_citation_rows": "0",
    "supplied_resource_rows": "0",
    "valid_answer_rows": "0",
    "valid_citation_rows": "0",
    "valid_resource_rows": "0",
    "required_core_systems_ready": "0",
    "optional_system_f_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "v53e_canary_query_scale_ready": "1",
    "complete_source_snapshot_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53f {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "answer-citation-resource-intake-schema",
    "frozen-v53e-query-input",
    "a-h-system-target-matrix",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53f gate should pass: {gate}")
for gate in [
    "supplied-a-h-answer-rows",
    "source-citation-coverage",
    "resource-measurement-coverage",
    "full-source-snapshot-scale",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53f gate should remain blocked: {gate}")

required_files = [
    "ah_system_target_rows.csv",
    "answer_row_required_schema.csv",
    "citation_row_required_schema.csv",
    "resource_row_required_schema.csv",
    "ah_answer_row_template.csv",
    "ah_resource_row_template.csv",
    "ah_supplied_validation_rows.csv",
    "ah_validation_error_rows.csv",
    "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md",
    "v53f_ah_answer_citation_resource_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v53e/scaled_canary_query_rows.csv",
    "source_v53e/scaled_canary_source_span_rows.csv",
    "source_v53e/scaled_canary_query_family_rows.csv",
    "source_v53e/scaled_canary_query_repo_rows.csv",
    "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "source_v53e/v53e_canary_query_scale_1000_manifest.json",
    "source_v53e/sha256_manifest.csv",
    "source_v53e/v53e_canary_query_scale_1000_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53f artifact: {rel}")

system_rows = read_csv(run_dir / "ah_system_target_rows.csv")
if len(system_rows) != 8 or {row["system_id"] for row in system_rows} != SYSTEM_IDS:
    raise SystemExit("v53f should target all A-H systems")
for row in system_rows:
    if row["system_id"] in CORE_SYSTEM_IDS and row["requirement"] != "required-core":
        raise SystemExit(f"v53f core requirement mismatch: {row['system_id']}")
    if row["system_id"] == "F" and row["requirement"] != "optional-if-policy-allows":
        raise SystemExit("v53f F should remain optional")
    if row["target_answer_rows"] != "1000" or row["minimum_citation_rows"] != "1000":
        raise SystemExit("v53f each system should target 1000 rows")

answer_schema = {row["field"] for row in read_csv(run_dir / "answer_row_required_schema.csv")}
for field in ["answer_id", "system_id", "query_id", "answer_text", "answer_text_sha256", "resource_row_id"]:
    if field not in answer_schema:
        raise SystemExit(f"v53f answer schema missing {field}")
citation_schema = {row["field"] for row in read_csv(run_dir / "citation_row_required_schema.csv")}
for field in ["citation_id", "answer_id", "source_span_id", "source_file_sha256", "citation_text_sha256"]:
    if field not in citation_schema:
        raise SystemExit(f"v53f citation schema missing {field}")
resource_schema = {row["field"] for row in read_csv(run_dir / "resource_row_required_schema.csv")}
for field in ["resource_row_id", "latency_ms", "external_model_used", "model_name", "hardware_or_endpoint"]:
    if field not in resource_schema:
        raise SystemExit(f"v53f resource schema missing {field}")

queries = read_csv(run_dir / "source_v53e/scaled_canary_query_rows.csv")
query_ids = {row["query_id"] for row in queries}
if len(query_ids) != 1000:
    raise SystemExit("v53f should copy 1000 frozen v53e queries")
answers = read_csv(run_dir / "ah_answer_row_template.csv")
resources = read_csv(run_dir / "ah_resource_row_template.csv")
if len(answers) != 8000 or len(resources) != 8000:
    raise SystemExit("v53f should write 8000 answer/resource template rows")
if {row["system_id"] for row in answers} != SYSTEM_IDS:
    raise SystemExit("v53f answer template should cover A-H")
if {row["query_id"] for row in answers} != query_ids:
    raise SystemExit("v53f answer template should cover every frozen query")
if any(row["status"] != "missing-supplied-output" for row in answers):
    raise SystemExit("v53f default answer template rows should remain missing")
for row in answers:
    if row["system_id"] in CORE_SYSTEM_IDS and row["required_for_core_close"] != "1":
        raise SystemExit("v53f core answer target flag mismatch")
    if row["system_id"] == "F" and row["required_for_core_close"] != "0":
        raise SystemExit("v53f optional F answer target flag mismatch")

validation_rows = read_csv(run_dir / "ah_supplied_validation_rows.csv")
if len(validation_rows) != 8:
    raise SystemExit("v53f should write one validation row per system")
if any(row["valid_answer_rows"] != "0" or row["status"] != "missing-or-invalid" for row in validation_rows):
    raise SystemExit("v53f default validation should remain missing")

manifest = json.loads((run_dir / "v53f_ah_answer_citation_resource_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53f_ah_answer_citation_resource_intake_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53f manifest readiness boundary mismatch")
if manifest.get("target_answer_rows") != 8000 or manifest.get("valid_answer_rows") != 0:
    raise SystemExit("v53f manifest count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53f sha256 mismatch: {rel}")

boundary = (run_dir / "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "A-H systems over the frozen v53e 1000-query canary set",
    "target_answer_rows=8000",
    "valid_answer_rows=0",
    "not a completed A-H comparison",
    "Do not publish v53 safety/grounding superiority",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53f boundary missing {snippet}")
PY

echo "v53f A-H answer/citation/resource intake smoke passed"
