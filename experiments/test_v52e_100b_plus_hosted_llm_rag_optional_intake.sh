#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52e_100b_plus_hosted_llm_rag_optional_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52e_100b_plus_hosted_llm_rag_optional_intake_decision.csv"

"$ROOT_DIR/experiments/run_v52e_100b_plus_hosted_llm_rag_optional_intake.sh" >/dev/null

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
    raise SystemExit(f"expected one v52e summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52e_100b_plus_hosted_llm_rag_optional_intake_contract_ready": "1",
    "system_id": "F",
    "baseline_name": "100B+ API or hosted model + RAG",
    "required_status": "optional-preferred",
    "evidence_dir_supplied": "0",
    "supplied_evidence_ready": "0",
    "optional_100b_plus_baseline_ready": "0",
    "optional_100b_plus_baseline_status": "deferred-with-reason",
    "query_rows": "0",
    "answer_rows": "0",
    "correct_rows": "0",
    "accuracy": "0.000000",
    "citation_rows": "0",
    "citation_correct_rows": "0",
    "citation_accuracy": "0.000000",
    "raw_prompt_context_rows": "0",
    "external_api_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v50_seed_query_rows": "9",
    "v52_optional_absorb_ready": "0",
    "v52_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "100b-plus-hosted-api-evidence-dir-missing",
    "validation_error_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52e {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["optional-intake-contract", "public-repo-seed"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52e gate should pass: {gate}")
for gate in ["100b-plus-optional-row", "v52-optional-absorb-ready"]:
    if decisions.get(gate) != "deferred":
        raise SystemExit(f"v52e gate should be deferred: {gate}")
for gate in ["30b-llm-rag-real-row", "70b-llm-rag-real-row", "v52-full-baseline-war", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52e required gate should remain blocked: {gate}")

required_files = [
    "hosted_llm_rag_required_field_rows.csv",
    "hosted_llm_rag_answer_template.csv",
    "model_identity_template.json",
    "hosted_llm_rag_validation_rows.csv",
    "V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md",
    "v52e_100b_plus_hosted_llm_rag_manifest.json",
    "sha256_manifest.csv",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/query_set.csv",
    "source_v50/reference_poc_result_rows.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
    "source_v50/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52e artifact: {rel}")

schema_rows = read_csv(run_dir / "hosted_llm_rag_required_field_rows.csv")
if len(schema_rows) < 14:
    raise SystemExit("v52e should emit required field schema rows")
for field in ["provider", "credential_redacted", "policy_allows_public_reporting"]:
    if not any(row["artifact"] == "model_identity.json" and row["field"] == field for row in schema_rows):
        raise SystemExit(f"v52e schema should require {field}")
if not any(row["artifact"] == "hosted_llm_rag_resource_rows.csv" and row["field"] == "api_request_id_hash" for row in schema_rows):
    raise SystemExit("v52e schema should require redacted API request hash")

templates = read_csv(run_dir / "hosted_llm_rag_answer_template.csv")
if len(templates) != 9:
    raise SystemExit("v52e should emit nine answer template rows from v50")
if any(row["system_id"] != "F" or row["size_class"] != "100b-plus" for row in templates):
    raise SystemExit("v52e answer template rows should all be system F")
if any(row["external_api_used"] != "1" for row in templates):
    raise SystemExit("v52e hosted/API template should mark external_api_used=1")
if any(row["route_memory_store_used"] != "0" or row["compact_routehint_used"] != "0" for row in templates):
    raise SystemExit("v52e F template should not use RouteMemory/RouteHint")

identity_template = json.loads((run_dir / "model_identity_template.json").read_text(encoding="utf-8"))
if identity_template.get("system_id") != "F" or identity_template.get("size_class") != "100b-plus":
    raise SystemExit("v52e identity template should identify baseline F")
if identity_template.get("external_api_used") != 1 or identity_template.get("credential_redacted") != 1:
    raise SystemExit("v52e identity template should default to hosted/API with redacted credentials")
if identity_template.get("policy_allows_public_reporting") != 0:
    raise SystemExit("v52e identity template should keep public reporting disabled by default")

validation_rows = read_csv(run_dir / "hosted_llm_rag_validation_rows.csv")
if validation_rows != [
    {
        "check": "evidence-dir",
        "status": "deferred",
        "reason": "V52E_100B_PLUS_LLM_RAG_EVIDENCE_DIR not supplied",
    }
]:
    raise SystemExit("v52e no-env validation row should defer on missing F evidence dir")

manifest = json.loads((run_dir / "v52e_100b_plus_hosted_llm_rag_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52e_100b_plus_hosted_llm_rag_optional_intake_contract_ready") != 1:
    raise SystemExit("v52e manifest should mark optional intake contract ready")
if manifest.get("optional_100b_plus_baseline_status") != "deferred-with-reason":
    raise SystemExit("v52e manifest should keep F deferred by default")
if manifest.get("v52_optional_absorb_ready") != 0:
    raise SystemExit("v52e manifest should not absorb no-env F evidence")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52e sha256 mismatch: {rel}")

boundary = (run_dir / "V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "baseline F",
    "100B+ size class",
    "credential redaction",
    "Default/no-env execution intentionally remains deferred",
    "F is optional; it cannot replace required 30B and 70B D/E rows",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52e boundary missing {snippet}")
PY

echo "v52e 100B+ hosted/API LLM RAG optional intake smoke passed"
