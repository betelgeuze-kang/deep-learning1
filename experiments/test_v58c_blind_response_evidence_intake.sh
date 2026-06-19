#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v58c_blind_response_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v58c_blind_response_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v58c_blind_response_evidence_intake_decision.csv"

set +e
output="$(V58C_REUSE_EXISTING="${V58C_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v58c_blind_response_evidence_intake.sh" 2>&1 >/dev/null)"
status=$?
set -e
if [ "$status" -ne 0 ]; then
  if ! grep -q "Refusing implicit v57 regeneration" <<<"$output"; then
    printf '%s\n' "$output" >&2
    exit "$status"
  fi
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
    "v58c_blind_response_evidence_intake_ready": "0",
    "v58_ready": "0",
    "v58c_dependency_blocker_ready": "1",
    "missing_dependency_artifact_rows": "7",
    "missing_v57_dependency_artifact_rows": "7",
    "implicit_dependency_rebuild_allowed": "0",
    "dependency_rebuild_approval_required": "1",
    "network_or_download_approval_required": "1",
    "pm_actual_required_system_rows": "7",
    "pm_actual_required_blind_response_rows": "3500",
    "pm_actual_required_blind_response_ready": "0",
    "pm_actual_missing_system_rows": "7",
    "pm_actual_template_gap_rows": "7",
    "required_blind_response_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v58c dependency {field}: expected {value}, got {summary.get(field)}")

rows = read_csv(run_dir / "v58c_dependency_blocker_rows.csv")
if len(rows) != 7:
    raise SystemExit("v58c dependency blocker should carry seven missing v57 artifact rows")
if any(row["implicit_rebuild_allowed"] != "0" or row["approval_required"] != "1" for row in rows):
    raise SystemExit("v58c dependency blocker rows should require approval and forbid implicit rebuild")
if any(row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0" for row in rows):
    raise SystemExit("v58c dependency blocker rows should forbid fixtures and tests-only merge")
if any(row["network_or_download_risk"] != "1" for row in rows):
    raise SystemExit("v58c dependency blocker rows should preserve network/download risk")

actual_matrix_rows = read_csv(run_dir / "blind_response_actual_execution_matrix_rows.csv")
if len(actual_matrix_rows) != 7:
    raise SystemExit("v58c dependency blocker should emit seven PM actual execution matrix rows")
matrix_by_system = {row["source_system_id"]: row for row in actual_matrix_rows}
if set(matrix_by_system) != {"A", "B", "C", "D", "E", "G", "H"}:
    raise SystemExit("v58c dependency PM matrix should cover A/B/C/D/E/G/H")
for system_id, row in matrix_by_system.items():
    if row["required_for_pm_v58_real_execution"] != "1":
        raise SystemExit(f"v58c dependency PM matrix should require {system_id}")
    if row["same_corpus_required"] != "1" or row["same_context_budget_required"] != "1":
        raise SystemExit(f"v58c dependency PM matrix should require same corpus/context for {system_id}")
    if row["blind_identity_required"] != "1" or row["latency_memory_separate_required"] != "1":
        raise SystemExit(f"v58c dependency PM matrix should require blind identity and separate latency/memory for {system_id}")
    if row["expected_blind_response_rows"] != "500":
        raise SystemExit(f"v58c dependency PM matrix should require 500 rows for {system_id}")
    if row["v58b_template_rows"] != "0" or row["supplied_blind_response_rows"] != "0":
        raise SystemExit(f"v58c dependency PM matrix should expose no template/supplied rows for {system_id}")
    if row["actual_response_ready"] != "0" or row["status"] != "blocked":
        raise SystemExit(f"v58c dependency PM matrix should keep {system_id} blocked")
    if row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v58c dependency PM matrix should forbid fixtures/tests-only for {system_id}")
    if row["blocker"] != "v58b-candidate-dependency-missing":
        raise SystemExit(f"v58c dependency PM matrix should expose dependency blocker for {system_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("v58c-dependency-blocker") != "pass":
    raise SystemExit("v58c dependency blocker gate should pass")
for gate in ["implicit-v58b-v57-rebuild", "v58c-intake-contract", "v58-full-blind-eval", "pm-required-all-a-b-c-d-e-g-h-response-rows"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v58c dependency blocker should keep blocked: {gate}")

manifest = json.loads((run_dir / "v58c_dependency_blocker_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v58c_dependency_blocker_ready") != 1:
    raise SystemExit("v58c dependency blocker manifest should be ready")
if manifest.get("pm_actual_required_system_rows") != 7 or manifest.get("pm_actual_required_blind_response_rows") != 3500:
    raise SystemExit("v58c dependency manifest should record PM A/B/C/D/E/G/H actual response requirement")
if manifest.get("pm_actual_required_blind_response_ready") != 0 or manifest.get("pm_actual_template_gap_rows") != 7:
    raise SystemExit("v58c dependency manifest should keep PM readiness blocked with seven template gaps")
boundary = (run_dir / "V58C_BLIND_RESPONSE_INTAKE_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
for snippet in [
    "refuses implicit regeneration",
    "dependency_rebuild_approval_required=1",
    "pm_actual_required_system_rows=7",
    "pm_actual_required_blind_response_rows=3500",
    "pm_actual_required_blind_response_ready=0",
    "pm_actual_template_gap_rows=7",
    "v58_full_blind_eval_ready=0",
    "Blocked wording: v58c intake artifact ready",
]:
    if snippet not in boundary:
        raise SystemExit(f"v58c dependency blocker boundary missing {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in [
    "v58c_dependency_blocker_rows.csv",
    "blind_response_actual_execution_matrix_rows.csv",
    "V58C_BLIND_RESPONSE_INTAKE_DEPENDENCY_BLOCKER.md",
    "v58c_dependency_blocker_manifest.json",
]:
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v58c dependency blocker sha mismatch: {rel}")
PY
  echo "v58c blind response evidence intake dependency guard smoke passed"
  exit 0
fi

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v58c summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v58c_dependency_blocker_ready") == "1":
    expected = {
        "v58c_blind_response_evidence_intake_ready": "0",
        "v58_ready": "0",
        "v58c_dependency_blocker_ready": "1",
        "missing_dependency_artifact_rows": "7",
        "missing_v57_dependency_artifact_rows": "7",
        "implicit_dependency_rebuild_allowed": "0",
        "dependency_rebuild_approval_required": "1",
        "network_or_download_approval_required": "1",
        "pm_actual_required_system_rows": "7",
        "pm_actual_required_blind_response_rows": "3500",
        "pm_actual_required_blind_response_ready": "0",
        "pm_actual_missing_system_rows": "7",
        "pm_actual_template_gap_rows": "7",
        "required_blind_response_ready": "0",
        "v58_full_blind_eval_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected.items():
        if summary.get(field) != value:
            raise SystemExit(f"v58c dependency {field}: expected {value}, got {summary.get(field)}")
    rows = read_csv(run_dir / "v58c_dependency_blocker_rows.csv")
    if len(rows) != 7:
        raise SystemExit("v58c dependency blocker should carry seven missing v57 artifact rows")
    if any(row["implicit_rebuild_allowed"] != "0" or row["approval_required"] != "1" for row in rows):
        raise SystemExit("v58c dependency blocker rows should require approval and forbid implicit rebuild")
    actual_matrix_rows = read_csv(run_dir / "blind_response_actual_execution_matrix_rows.csv")
    if len(actual_matrix_rows) != 7:
        raise SystemExit("v58c dependency blocker should emit seven PM actual execution matrix rows")
    matrix_by_system = {row["source_system_id"]: row for row in actual_matrix_rows}
    if set(matrix_by_system) != {"A", "B", "C", "D", "E", "G", "H"}:
        raise SystemExit("v58c dependency PM matrix should cover A/B/C/D/E/G/H")
    for system_id, row in matrix_by_system.items():
        if row["required_for_pm_v58_real_execution"] != "1":
            raise SystemExit(f"v58c dependency PM matrix should require {system_id}")
        if row["same_corpus_required"] != "1" or row["same_context_budget_required"] != "1":
            raise SystemExit(f"v58c dependency PM matrix should require same corpus/context for {system_id}")
        if row["blind_identity_required"] != "1" or row["latency_memory_separate_required"] != "1":
            raise SystemExit(f"v58c dependency PM matrix should require blind identity and separate latency/memory for {system_id}")
        if row["expected_blind_response_rows"] != "500":
            raise SystemExit(f"v58c dependency PM matrix should require 500 rows for {system_id}")
        if row["v58b_template_rows"] != "0" or row["supplied_blind_response_rows"] != "0":
            raise SystemExit(f"v58c dependency PM matrix should expose no template/supplied rows for {system_id}")
        if row["actual_response_ready"] != "0" or row["status"] != "blocked":
            raise SystemExit(f"v58c dependency PM matrix should keep {system_id} blocked")
        if row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
            raise SystemExit(f"v58c dependency PM matrix should forbid fixtures/tests-only for {system_id}")
        if row["blocker"] != "v58b-candidate-dependency-missing":
            raise SystemExit(f"v58c dependency PM matrix should expose dependency blocker for {system_id}")
    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    if decisions.get("v58c-dependency-blocker") != "pass":
        raise SystemExit("v58c dependency blocker gate should pass")
    for gate in ["implicit-v58b-v57-rebuild", "v58c-intake-contract", "v58-full-blind-eval", "pm-required-all-a-b-c-d-e-g-h-response-rows"]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v58c dependency blocker should keep blocked: {gate}")
    manifest = json.loads((run_dir / "v58c_dependency_blocker_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v58c_dependency_blocker_ready") != 1:
        raise SystemExit("v58c dependency blocker manifest should be ready")
    if manifest.get("pm_actual_required_system_rows") != 7 or manifest.get("pm_actual_required_blind_response_rows") != 3500:
        raise SystemExit("v58c dependency manifest should record PM A/B/C/D/E/G/H actual response requirement")
    if manifest.get("pm_actual_required_blind_response_ready") != 0 or manifest.get("pm_actual_template_gap_rows") != 7:
        raise SystemExit("v58c dependency manifest should keep PM readiness blocked with seven template gaps")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in [
        "v58c_dependency_blocker_rows.csv",
        "blind_response_actual_execution_matrix_rows.csv",
        "V58C_BLIND_RESPONSE_INTAKE_DEPENDENCY_BLOCKER.md",
        "v58c_dependency_blocker_manifest.json",
    ]:
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v58c dependency blocker sha mismatch: {rel}")
    boundary = (run_dir / "V58C_BLIND_RESPONSE_INTAKE_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
    for snippet in [
        "refuses implicit regeneration",
        "dependency_rebuild_approval_required=1",
        "pm_actual_required_system_rows=7",
        "pm_actual_required_blind_response_rows=3500",
        "pm_actual_required_blind_response_ready=0",
        "pm_actual_template_gap_rows=7",
        "v58_full_blind_eval_ready=0",
        "Blocked wording: v58c intake artifact ready",
    ]:
        if snippet not in boundary:
            raise SystemExit(f"v58c dependency blocker boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v58c_blind_response_evidence_intake_ready": "1",
    "v58_ready": "0",
    "evidence_dir_supplied": "0",
    "expected_blind_response_rows": "2500",
    "supplied_blind_response_rows": "0",
    "required_blind_response_rows": "3500",
    "pm_actual_required_system_rows": "7",
    "pm_actual_required_blind_response_rows": "3500",
    "pm_actual_required_blind_response_ready": "0",
    "pm_actual_missing_system_rows": "7",
    "pm_actual_template_gap_rows": "3",
    "required_blind_response_ready": "0",
    "d_30b_blind_response_ready": "0",
    "e_70b_blind_response_ready": "0",
    "g_routehint_blind_response_ready": "0",
    "h_policy_blind_response_ready": "0",
    "optional_100b_plus_blind_response_ready": "0",
    "optional_100b_plus_blind_response_status": "deferred-with-reason",
    "validation_error_rows": "0",
    "v58b_blind_eval_candidate_ready": "1",
    "blind_response_absorb_ready": "0",
    "human_blind_review_ready": "0",
    "inter_rater_rows_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v58c {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["intake-contract", "v58b-candidate-input"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v58c gate should pass: {gate}")
for gate in [
    "30b-blind-response-row",
    "70b-blind-response-row",
    "routehint-blind-response-row",
    "policy-blind-response-row",
    "pm-required-a-blind-response-row",
    "pm-required-b-blind-response-row",
    "pm-required-c-blind-response-row",
    "pm-required-all-a-b-c-d-e-g-h-response-rows",
    "100b-plus-blind-response-row",
    "blind-response-absorb-ready",
    "human-blind-review",
    "v58-full-blind-eval",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v58c gate should remain blocked: {gate}")

required_files = [
    "blind_response_required_field_rows.csv",
    "blind_response_row_template.csv",
    "run_identity_template_rows.csv",
    "blind_response_actual_execution_matrix_rows.csv",
    "blind_response_validation_rows.csv",
    "blind_response_intake_gate_rows.csv",
    "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md",
    "v58c_blind_response_evidence_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v58b/blind_query_freeze_rows.csv",
    "source_v58b/sealed_answer_key_rows.csv",
    "source_v58b/blind_response_template_rows.csv",
    "source_v58b/blind_reviewer_packet_template_rows.csv",
    "source_v58b/blind_evidence_budget_rows.csv",
    "source_v58b/sealed_identity_key_rows.csv",
    "source_v58b/V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md",
    "source_v58b/v58b_blind_eval_candidate_manifest.json",
    "source_v58b/sha256_manifest.csv",
    "source_v58b/v58b_blind_eval_candidate_500_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v58c artifact: {rel}")

schema_rows = read_csv(run_dir / "blind_response_required_field_rows.csv")
if len(schema_rows) < 17:
    raise SystemExit("v58c should emit blind response and run identity schema rows")
for field in ["blind_response_id", "response_text", "citation_source_span_id", "output_sha256", "latency_ns", "model_run_id"]:
    if not any(row["field"] == field for row in schema_rows):
        raise SystemExit(f"v58c schema missing {field}")

templates = read_csv(run_dir / "blind_response_row_template.csv")
if len(templates) != 2500:
    raise SystemExit("v58c should emit 2500 blind response template rows")
if {row["source_system_id"] for row in templates} != {"D", "E", "F", "G", "H"}:
    raise SystemExit("v58c templates should cover D/E/F/G/H")
if any(row["response_text"] or row["output_sha256"] for row in templates):
    raise SystemExit("v58c templates should not include fake responses")

identity_templates = read_csv(run_dir / "run_identity_template_rows.csv")
if len(identity_templates) != 5:
    raise SystemExit("v58c should emit five run identity template rows")
if {row["source_system_id"] for row in identity_templates} != {"D", "E", "F", "G", "H"}:
    raise SystemExit("v58c run identity templates should cover D/E/F/G/H")

actual_matrix_rows = read_csv(run_dir / "blind_response_actual_execution_matrix_rows.csv")
if len(actual_matrix_rows) != 7:
    raise SystemExit("v58c should emit seven PM actual execution matrix rows")
matrix_by_system = {row["source_system_id"]: row for row in actual_matrix_rows}
if set(matrix_by_system) != {"A", "B", "C", "D", "E", "G", "H"}:
    raise SystemExit("v58c PM actual execution matrix should cover A/B/C/D/E/G/H")
for system_id, row in matrix_by_system.items():
    if row["required_for_pm_v58_real_execution"] != "1":
        raise SystemExit(f"v58c PM matrix should require {system_id}")
    if row["same_corpus_required"] != "1" or row["same_context_budget_required"] != "1":
        raise SystemExit(f"v58c PM matrix should require same corpus/context for {system_id}")
    if row["blind_identity_required"] != "1" or row["latency_memory_separate_required"] != "1":
        raise SystemExit(f"v58c PM matrix should require blind identity and separate latency/memory for {system_id}")
    if row["expected_blind_response_rows"] != "500":
        raise SystemExit(f"v58c PM matrix should require 500 rows for {system_id}")
    if row["actual_response_ready"] != "0" or row["status"] != "blocked":
        raise SystemExit(f"v58c PM matrix should keep {system_id} blocked by default")
    if row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
        raise SystemExit(f"v58c PM matrix should forbid fixtures/tests-only for {system_id}")
for system_id in ["A", "B", "C"]:
    if matrix_by_system[system_id]["v58b_template_rows"] != "0":
        raise SystemExit(f"v58c PM matrix should expose missing template rows for {system_id}")
    if matrix_by_system[system_id]["blocker"] != "missing-v58b-blind-template-for-pm-required-system":
        raise SystemExit(f"v58c PM matrix should expose A/B/C template blocker for {system_id}")
for system_id in ["D", "E", "G", "H"]:
    if matrix_by_system[system_id]["v58b_template_rows"] != "500":
        raise SystemExit(f"v58c PM matrix should carry 500 template rows for {system_id}")

validation = read_csv(run_dir / "blind_response_validation_rows.csv")
if validation != [{"check": "evidence-dir", "status": "blocked", "reason": "V58C_BLIND_RESPONSE_EVIDENCE_DIR not supplied"}]:
    raise SystemExit("v58c no-env validation should block on missing evidence dir")

manifest = json.loads((run_dir / "v58c_blind_response_evidence_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v58c_blind_response_evidence_intake_ready") != 1 or manifest.get("v58_ready") != 0:
    raise SystemExit("v58c manifest readiness mismatch")
if manifest.get("required_blind_response_ready") != 0 or manifest.get("human_blind_review_ready") != 0:
    raise SystemExit("v58c manifest should keep response/review blocked by default")
if manifest.get("pm_actual_required_system_rows") != 7 or manifest.get("pm_actual_required_blind_response_rows") != 3500:
    raise SystemExit("v58c manifest should record PM A/B/C/D/E/G/H actual response requirement")
if manifest.get("pm_actual_required_blind_response_ready") != 0 or manifest.get("pm_actual_template_gap_rows") != 3:
    raise SystemExit("v58c manifest should keep PM actual response readiness blocked with A/B/C template gaps")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v58c sha256 mismatch: {rel}")

boundary = (run_dir / "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "response evidence intake for the v58 blind evaluation",
    "It is not a completed blind evaluation",
    "expected_blind_response_rows=2500",
    "pm_actual_required_system_rows=7",
    "pm_actual_required_blind_response_rows=3500",
    "pm_actual_required_blind_response_ready=0",
    "pm_actual_template_gap_rows=3",
    "human_blind_review_ready=0",
    "Do not publish blind-eval wins",
]:
    if snippet not in boundary:
        raise SystemExit(f"v58c boundary missing {snippet}")
PY

echo "v58c blind response evidence intake smoke passed"
