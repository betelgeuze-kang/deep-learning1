#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52c_7b14b_local_model_rag_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v52c_7b14b_local_model_rag_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52c_7b14b_local_model_rag_evidence_intake_decision.csv"

"$ROOT_DIR/experiments/run_v52c_7b14b_local_model_rag_evidence_intake.sh" >/dev/null

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
    raise SystemExit(f"expected one v52c summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52c_7b14b_local_model_rag_intake_contract_ready": "1",
    "system_id": "C",
    "baseline_name": "7B-14B local model + RAG",
    "required_size_class": "7b-14b",
    "evidence_dir_supplied": "0",
    "supplied_evidence_ready": "0",
    "model_identity_ready": "0",
    "model_size_class_ready": "0",
    "answer_rows_ready": "0",
    "citation_rows_ready": "0",
    "resource_rows_ready": "0",
    "query_rows": "0",
    "answer_rows": "0",
    "correct_rows": "0",
    "accuracy": "0.000000",
    "citation_rows": "0",
    "citation_correct_rows": "0",
    "citation_accuracy": "0.000000",
    "raw_prompt_context_rows": "0",
    "external_network_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v50_seed_query_rows": "9",
    "v52_absorb_ready": "0",
    "v52_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "local-model-rag-evidence-dir-missing",
    "validation_error_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52c {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["intake-contract", "public-repo-seed"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52c gate should pass: {gate}")
for gate in [
    "7b-14b-local-model-rag-evidence",
    "v52-absorb-ready",
    "30b-llm-rag-real-row",
    "70b-llm-rag-real-row",
    "v52-full-baseline-war",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52c gate should remain blocked: {gate}")

required_files = [
    "local_model_rag_required_field_rows.csv",
    "local_model_rag_answer_template.csv",
    "model_identity_template.json",
    "local_model_rag_validation_rows.csv",
    "V52C_7B14B_LOCAL_MODEL_RAG_BOUNDARY.md",
    "v52c_7b14b_local_model_rag_manifest.json",
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
        raise SystemExit(f"missing v52c artifact: {rel}")

schema_rows = read_csv(run_dir / "local_model_rag_required_field_rows.csv")
if len(schema_rows) < 12:
    raise SystemExit("v52c should emit required field schema rows")
if not any(row["artifact"] == "model_identity.json" and row["field"] == "parameter_count_b" for row in schema_rows):
    raise SystemExit("v52c schema should require parameter_count_b")
if not any(row["artifact"] == "local_model_rag_citation_rows.csv" for row in schema_rows):
    raise SystemExit("v52c schema should require citation rows")

templates = read_csv(run_dir / "local_model_rag_answer_template.csv")
if len(templates) != 9:
    raise SystemExit("v52c should emit nine answer template rows from v50")
if any(row["system_id"] != "C" for row in templates):
    raise SystemExit("v52c answer template rows should all be system C")
if any(row["route_memory_store_used"] != "0" or row["compact_routehint_used"] != "0" for row in templates):
    raise SystemExit("v52c C template should not use RouteMemory/RouteHint")

identity_template = json.loads((run_dir / "model_identity_template.json").read_text(encoding="utf-8"))
if identity_template.get("system_id") != "C" or identity_template.get("size_class") != "7b-14b":
    raise SystemExit("v52c identity template should identify baseline C")
if identity_template.get("external_network_used") != 0:
    raise SystemExit("v52c identity template should default to local/no-network")

validation_rows = read_csv(run_dir / "local_model_rag_validation_rows.csv")
if validation_rows != [
    {
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52C_LOCAL_MODEL_RAG_EVIDENCE_DIR not supplied",
    }
]:
    raise SystemExit("v52c no-env validation row should block on missing evidence dir")

manifest = json.loads((run_dir / "v52c_7b14b_local_model_rag_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52c_7b14b_local_model_rag_intake_contract_ready") != 1:
    raise SystemExit("v52c manifest should mark intake contract ready")
if manifest.get("supplied_evidence_ready") != 0 or manifest.get("v52_absorb_ready") != 0:
    raise SystemExit("v52c manifest should keep no-env evidence blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52c sha256 mismatch: {rel}")

boundary = (run_dir / "V52C_7B14B_LOCAL_MODEL_RAG_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "baseline C",
    "model_identity.json",
    "7B-14B parameter count",
    "Default/no-env execution intentionally remains blocked",
    "Do not publish C, 30B-150B, or v1.0 comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52c boundary missing {snippet}")
PY

echo "v52c 7B-14B local model RAG evidence intake smoke passed"
