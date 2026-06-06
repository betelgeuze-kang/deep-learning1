#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_decision.csv"

"$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null

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
    raise SystemExit(f"expected one v52d summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52d_30b70b_llm_rag_intake_contract_ready": "1",
    "required_systems": "D,E",
    "baseline_name": "30B/70B open-weight LLM + RAG",
    "d_30b_evidence_dir_supplied": "0",
    "e_70b_evidence_dir_supplied": "0",
    "d_30b_supplied_evidence_ready": "0",
    "e_70b_supplied_evidence_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "d_30b_query_rows": "0",
    "e_70b_query_rows": "0",
    "d_30b_accuracy": "0.000000",
    "e_70b_accuracy": "0.000000",
    "d_30b_citation_accuracy": "0.000000",
    "e_70b_citation_accuracy": "0.000000",
    "d_30b_validation_error_rows": "0",
    "e_70b_validation_error_rows": "0",
    "external_api_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v50_seed_query_rows": "9",
    "v52_absorb_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "30b:evidence-dir-missing;70b:evidence-dir-missing",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52d {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["intake-contract", "public-repo-seed"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52d gate should pass: {gate}")
for gate in [
    "30b-llm-rag-real-row",
    "70b-llm-rag-real-row",
    "v52-d-e-absorb-ready",
    "v52-full-baseline-war",
    "100b-plus-optional-row",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52d gate should remain blocked: {gate}")

required_files = [
    "llm_rag_required_field_rows.csv",
    "llm_rag_answer_template.csv",
    "model_identity_templates.json",
    "llm_rag_validation_rows.csv",
    "V52D_30B70B_LLM_RAG_BOUNDARY.md",
    "v52d_30b70b_llm_rag_manifest.json",
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
        raise SystemExit(f"missing v52d artifact: {rel}")

schema_rows = read_csv(run_dir / "llm_rag_required_field_rows.csv")
if len(schema_rows) < 22:
    raise SystemExit("v52d should emit required field schema rows for D and E")
for system_id, size_rule in [("D", "float in [25.0, 40.0]"), ("E", "float in [65.0, 80.0]")]:
    if not any(row["system_id"] == system_id and row["field"] == "parameter_count_b" and row["rule"] == size_rule for row in schema_rows):
        raise SystemExit(f"v52d schema should require parameter range for {system_id}")
    if not any(row["system_id"] == system_id and row["field"] == "external_api_used" for row in schema_rows):
        raise SystemExit(f"v52d schema should require external_api_used=0 for {system_id}")

templates = read_csv(run_dir / "llm_rag_answer_template.csv")
if len(templates) != 18:
    raise SystemExit("v52d should emit eighteen answer template rows from v50 for D/E")
if sum(1 for row in templates if row["system_id"] == "D") != 9:
    raise SystemExit("v52d D template row count mismatch")
if sum(1 for row in templates if row["system_id"] == "E") != 9:
    raise SystemExit("v52d E template row count mismatch")
if any(row["external_api_used"] != "0" for row in templates):
    raise SystemExit("v52d D/E templates should forbid external API use")
if any(row["route_memory_store_used"] != "0" or row["compact_routehint_used"] != "0" for row in templates):
    raise SystemExit("v52d D/E templates should not use RouteMemory/RouteHint")

identity_templates = json.loads((run_dir / "model_identity_templates.json").read_text(encoding="utf-8"))
if sorted(identity_templates.keys()) != ["D", "E"]:
    raise SystemExit("v52d identity templates should cover D and E")
if identity_templates["D"].get("size_class") != "30b" or identity_templates["E"].get("size_class") != "70b":
    raise SystemExit("v52d identity templates should identify 30B and 70B classes")
if identity_templates["D"].get("external_api_used") != 0 or identity_templates["E"].get("external_api_used") != 0:
    raise SystemExit("v52d identity templates should default to open-weight/no external API")

validation_rows = read_csv(run_dir / "llm_rag_validation_rows.csv")
expected_validation = [
    {
        "system_id": "D",
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52D_30B_LLM_RAG_EVIDENCE_DIR not supplied",
    },
    {
        "system_id": "E",
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52D_70B_LLM_RAG_EVIDENCE_DIR not supplied",
    },
]
if validation_rows != expected_validation:
    raise SystemExit("v52d no-env validation rows should block on missing D/E evidence dirs")

manifest = json.loads((run_dir / "v52d_30b70b_llm_rag_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52d_30b70b_llm_rag_intake_contract_ready") != 1:
    raise SystemExit("v52d manifest should mark intake contract ready")
if manifest.get("required_30b_baseline_ready") != 0 or manifest.get("required_70b_baseline_ready") != 0:
    raise SystemExit("v52d manifest should keep D/E baselines blocked by default")
if manifest.get("v52_absorb_ready") != 0:
    raise SystemExit("v52d manifest should not absorb no-env D/E evidence")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52d sha256 mismatch: {rel}")

boundary = (run_dir / "V52D_30B70B_LLM_RAG_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "baselines D and E",
    "open-weight license URI",
    "llm_rag_answer_rows.csv",
    "Default/no-env execution intentionally remains blocked",
    "Do not publish D/E, 30B-150B, or v1.0 comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52d boundary missing {snippet}")
PY

echo "v52d 30B/70B LLM RAG evidence intake smoke passed"
