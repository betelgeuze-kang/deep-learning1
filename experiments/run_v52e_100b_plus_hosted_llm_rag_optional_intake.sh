#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52e_100b_plus_hosted_llm_rag_optional_intake"
RUN_ID="${V52E_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EVIDENCE_DIR="${V52E_100B_PLUS_LLM_RAG_EVIDENCE_DIR:-}"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$EVIDENCE_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
evidence_dir_arg = sys.argv[5]
results = root / "results"
v50_dir = results / "v50_public_repo_auditor_3repo" / "audit_001"
v50_summary = list(csv.DictReader((results / "v50_public_repo_auditor_3repo_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_sha256(value):
    return isinstance(value, str) and value.startswith("sha256:") and len(value) == 71


def int_value(row, field, errors, minimum=None):
    try:
        value = int(row.get(field, ""))
    except (TypeError, ValueError):
        errors.append(f"{field}-not-integer")
        return 0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-{minimum}")
    return value


def float_value(row, field, errors, minimum=None):
    raw = row.get(field, "")
    if raw in ("", None):
        return None
    try:
        value = float(raw)
    except (TypeError, ValueError):
        errors.append(f"{field}-not-float")
        return None
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-{minimum}")
    return value


for src, rel in [
    (v50_dir / "public_repo_audit_case_rows.csv", "source_v50/public_repo_audit_case_rows.csv"),
    (v50_dir / "public_repo_source_span_rows.csv", "source_v50/public_repo_source_span_rows.csv"),
    (v50_dir / "commercial_return" / "query_set.csv", "source_v50/query_set.csv"),
    (v50_dir / "commercial_return" / "poc_result_rows.csv", "source_v50/reference_poc_result_rows.csv"),
    (results / "v50_public_repo_auditor_3repo_summary.csv", "source_v50/v50_public_repo_auditor_3repo_summary.csv"),
    (v50_dir / "sha256_manifest.csv", "source_v50/sha256_manifest.csv"),
]:
    copy(src, rel)

cases = read_csv(v50_dir / "public_repo_audit_case_rows.csv")
queries = read_csv(v50_dir / "commercial_return" / "query_set.csv")
spans = read_csv(v50_dir / "public_repo_source_span_rows.csv")
case_by_query = {f"v50_{idx:03d}": case for idx, case in enumerate(cases, start=1)}
span_keys = {(row["case_id"], row["kind"], row["path"], row["sha256"], row["line"]) for row in spans}
expected_query_ids = [row["query_id"] for row in queries]

schema_rows = [
    {"artifact": "model_identity.json", "field": "system_id", "required": 1, "rule": "must equal F"},
    {"artifact": "model_identity.json", "field": "model_id", "required": 1, "rule": "stable hosted/API model identifier"},
    {"artifact": "model_identity.json", "field": "provider", "required": 1, "rule": "hosted/API provider name"},
    {"artifact": "model_identity.json", "field": "size_class", "required": 1, "rule": "must equal 100b-plus"},
    {"artifact": "model_identity.json", "field": "parameter_count_b", "required": 0, "rule": "if disclosed, must be >=100"},
    {"artifact": "model_identity.json", "field": "model_artifact_sha256", "required": 0, "rule": "sha256 if a local artifact/cache is available"},
    {"artifact": "model_identity.json", "field": "credential_redacted", "required": 1, "rule": "must be 1"},
    {"artifact": "model_identity.json", "field": "policy_allows_public_reporting", "required": 1, "rule": "must be 1 to count as ready"},
    {"artifact": "hosted_llm_rag_answer_rows.csv", "field": "query_id", "required": 1, "rule": "must cover every v50 query id exactly once"},
    {"artifact": "hosted_llm_rag_answer_rows.csv", "field": "predicted_label", "required": 1, "rule": "scored against v50 expected_label"},
    {"artifact": "hosted_llm_rag_answer_rows.csv", "field": "raw_prompt_context_bytes", "required": 1, "rule": "positive integer"},
    {"artifact": "hosted_llm_rag_citation_rows.csv", "field": "case_id/kind/path/sha256/line", "required": 1, "rule": "must bind to v50 source spans"},
    {"artifact": "hosted_llm_rag_resource_rows.csv", "field": "latency_ns", "required": 1, "rule": "positive measured runtime"},
    {"artifact": "hosted_llm_rag_resource_rows.csv", "field": "api_request_id_hash", "required": 1, "rule": "sha256:<64 hex> or redacted request hash"},
]
write_csv(run_dir / "hosted_llm_rag_required_field_rows.csv", list(schema_rows[0].keys()), schema_rows)

template_rows = []
for query in queries:
    case = case_by_query[query["query_id"]]
    template_rows.append(
        {
            "system_id": "F",
            "query_id": query["query_id"],
            "case_id": case["case_id"],
            "size_class": "100b-plus",
            "model_id": "replace-with-100b-plus-hosted-model-id",
            "expected_label": case["expected_label"],
            "predicted_label": "",
            "answer": "",
            "raw_prompt_context_bytes": "",
            "retrieved_span_rows": "",
            "prompt_context_sha256": "",
            "output_sha256": "",
            "latency_ns": "",
            "external_api_used": "1",
            "route_memory_store_used": "0",
            "compact_routehint_used": "0",
        }
    )
write_csv(run_dir / "hosted_llm_rag_answer_template.csv", list(template_rows[0].keys()), template_rows)

identity_template = {
    "system_id": "F",
    "model_id": "replace-with-100b-plus-hosted-model-id",
    "provider": "replace-with-provider",
    "parameter_count_b": None,
    "size_class": "100b-plus",
    "model_artifact_sha256": "",
    "hosted_endpoint_policy_uri": "required",
    "rag_context_builder": "describe retrieval and prompt assembly",
    "context_length": None,
    "external_api_used": 1,
    "credential_redacted": 1,
    "policy_allows_public_reporting": 0,
}
(run_dir / "model_identity_template.json").write_text(json.dumps(identity_template, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary = {
    "v52e_100b_plus_hosted_llm_rag_optional_intake_contract_ready": 1,
    "system_id": "F",
    "baseline_name": "100B+ API or hosted model + RAG",
    "required_status": "optional-preferred",
    "evidence_dir_supplied": int(bool(evidence_dir_arg)),
    "supplied_evidence_ready": 0,
    "optional_100b_plus_baseline_ready": 0,
    "optional_100b_plus_baseline_status": "deferred-with-reason",
    "query_rows": 0,
    "answer_rows": 0,
    "correct_rows": 0,
    "accuracy": "0.000000",
    "citation_rows": 0,
    "citation_correct_rows": 0,
    "citation_accuracy": "0.000000",
    "raw_prompt_context_rows": 0,
    "external_api_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v50_seed_query_rows": int(v50_summary.get("audit_case_rows", "0")),
    "v52_optional_absorb_ready": 0,
    "v52_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": "100b-plus-hosted-api-evidence-dir-missing",
    "validation_error_rows": 0,
}
decision_rows = [
    ("optional-intake-contract", "pass", "F evidence schema and templates are emitted"),
    ("public-repo-seed", "pass", "uses v50 3-repo / 9-query seed"),
]
validation_rows = []
evidence_dir = Path(evidence_dir_arg) if evidence_dir_arg else None

if not evidence_dir or not evidence_dir.is_dir():
    validation_rows.append({"check": "evidence-dir", "status": "deferred", "reason": "V52E_100B_PLUS_LLM_RAG_EVIDENCE_DIR not supplied"})
else:
    required = {
        "identity": evidence_dir / "model_identity.json",
        "answers": evidence_dir / "hosted_llm_rag_answer_rows.csv",
        "citations": evidence_dir / "hosted_llm_rag_citation_rows.csv",
        "resources": evidence_dir / "hosted_llm_rag_resource_rows.csv",
    }
    for name, path in required.items():
        if path.is_file() and path.stat().st_size > 0:
            copy(path, f"supplied_evidence/{path.name}")
            validation_rows.append({"check": f"{name}-file", "status": "pass", "reason": "present"})
        else:
            validation_rows.append({"check": f"{name}-file", "status": "fail", "reason": "missing-or-empty"})
    if all(path.is_file() and path.stat().st_size > 0 for path in required.values()):
        errors = []
        identity = json.loads(required["identity"].read_text(encoding="utf-8"))
        if identity.get("system_id") != "F":
            errors.append("identity-system-id-not-F")
        if identity.get("size_class") != "100b-plus":
            errors.append("identity-size-class-not-100b-plus")
        if not identity.get("model_id"):
            errors.append("identity-model-id-missing")
        if not identity.get("provider"):
            errors.append("identity-provider-missing")
        float_value(identity, "parameter_count_b", errors, minimum=100.0)
        artifact_hash = identity.get("model_artifact_sha256", "")
        if artifact_hash and not is_sha256(artifact_hash):
            errors.append("identity-model-artifact-sha256-invalid")
        if int(identity.get("credential_redacted", 0)) != 1:
            errors.append("identity-credential-redacted-not-one")
        if int(identity.get("policy_allows_public_reporting", 0)) != 1:
            errors.append("identity-public-reporting-policy-not-ready")
        model_id = identity.get("model_id", "")

        answers = read_csv(required["answers"])
        citations = read_csv(required["citations"])
        resources = read_csv(required["resources"])
        answer_query_ids = [row.get("query_id", "") for row in answers]
        if sorted(answer_query_ids) != sorted(expected_query_ids) or len(answer_query_ids) != len(set(answer_query_ids)):
            errors.append("answer-query-coverage-mismatch")
        correct_rows = 0
        raw_context_rows = 0
        for row in answers:
            query_id = row.get("query_id", "")
            case = case_by_query.get(query_id)
            row_errors = []
            if row.get("system_id") != "F":
                row_errors.append("answer-system-id-not-F")
            if row.get("model_id") != model_id:
                row_errors.append("answer-model-id-mismatch")
            if not case or row.get("case_id") != case["case_id"]:
                row_errors.append("answer-case-id-mismatch")
            if not row.get("predicted_label"):
                row_errors.append("answer-predicted-label-missing")
            if row.get("predicted_label") == (case or {}).get("expected_label"):
                correct_rows += 1
            if int_value(row, "raw_prompt_context_bytes", row_errors, minimum=1) > 0:
                raw_context_rows += 1
            int_value(row, "retrieved_span_rows", row_errors, minimum=1)
            int_value(row, "latency_ns", row_errors, minimum=1)
            if not is_sha256(row.get("prompt_context_sha256", "")):
                row_errors.append("answer-prompt-context-sha256-invalid")
            if not is_sha256(row.get("output_sha256", "")):
                row_errors.append("answer-output-sha256-invalid")
            if row.get("external_api_used") != "1":
                row_errors.append("answer-external-api-used-not-one")
            if row.get("route_memory_store_used") != "0" or row.get("compact_routehint_used") != "0":
                row_errors.append("answer-route-memory-or-routehint-not-zero")
            errors.extend(f"{query_id}:{err}" for err in row_errors)

        citation_query_ids = {row.get("query_id", "") for row in citations}
        if citation_query_ids != set(expected_query_ids):
            errors.append("citation-query-coverage-mismatch")
        citation_correct_rows = 0
        for row in citations:
            row_errors = []
            key = (row.get("case_id", ""), row.get("kind", ""), row.get("path", ""), row.get("sha256", ""), row.get("line", ""))
            if key not in span_keys:
                row_errors.append("citation-source-span-mismatch")
            if row.get("query_id", "") not in case_by_query:
                row_errors.append("citation-query-id-unknown")
            if row.get("citation_correct") == "1":
                citation_correct_rows += 1
            elif row.get("citation_correct") != "0":
                row_errors.append("citation-correct-not-0-or-1")
            errors.extend(f"{row.get('query_id', '')}:citation:{err}" for err in row_errors)

        resource_query_ids = [row.get("query_id", "") for row in resources]
        if sorted(resource_query_ids) != sorted(expected_query_ids) or len(resource_query_ids) != len(set(resource_query_ids)):
            errors.append("resource-query-coverage-mismatch")
        for row in resources:
            row_errors = []
            if row.get("model_id") != model_id:
                row_errors.append("resource-model-id-mismatch")
            int_value(row, "latency_ns", row_errors, minimum=1)
            int_value(row, "raw_prompt_context_bytes", row_errors, minimum=1)
            int_value(row, "retrieved_span_rows", row_errors, minimum=1)
            if row.get("external_api_used") != "1":
                row_errors.append("resource-external-api-used-not-one")
            if not is_sha256(row.get("api_request_id_hash", "")):
                row_errors.append("resource-api-request-id-hash-invalid")
            errors.extend(f"{row.get('query_id', '')}:resource:{err}" for err in row_errors)

        if errors:
            for err in errors:
                validation_rows.append({"check": "supplied-evidence", "status": "fail", "reason": err})
            summary["blocking_reason"] = "supplied-100b-plus-hosted-evidence-invalid"
        else:
            query_rows = len(expected_query_ids)
            summary.update(
                {
                    "supplied_evidence_ready": 1,
                    "optional_100b_plus_baseline_ready": 1,
                    "optional_100b_plus_baseline_status": "ready",
                    "query_rows": query_rows,
                    "answer_rows": len(answers),
                    "correct_rows": correct_rows,
                    "accuracy": f"{correct_rows / query_rows:.6f}",
                    "citation_rows": len(citations),
                    "citation_correct_rows": citation_correct_rows,
                    "citation_accuracy": f"{citation_correct_rows / len(citations):.6f}" if citations else "0.000000",
                    "raw_prompt_context_rows": raw_context_rows,
                    "external_api_used": 1,
                    "v52_optional_absorb_ready": 1,
                    "blocking_reason": "",
                }
            )
            validation_rows.append({"check": "supplied-evidence", "status": "pass", "reason": "100b-plus hosted/API evidence validates"})

summary["validation_error_rows"] = sum(1 for row in validation_rows if row["status"] == "fail")
if summary["optional_100b_plus_baseline_ready"]:
    decision_rows.append(("100b-plus-optional-row", "pass", "F supplied evidence validates"))
    decision_rows.append(("v52-optional-absorb-ready", "pass", "F row can be consumed by a later v52 registry update"))
else:
    decision_rows.append(("100b-plus-optional-row", "deferred", summary["blocking_reason"]))
    decision_rows.append(("v52-optional-absorb-ready", "deferred", "F is optional and does not unblock required D/E rows"))
decision_rows.extend(
    [
        ("30b-llm-rag-real-row", "blocked", "D row is still required separately"),
        ("70b-llm-rag-real-row", "blocked", "E row is still required separately"),
        ("v52-full-baseline-war", "blocked", "v52 still needs required D/E rows and release-scale evidence"),
        ("real-release-package", "blocked", "this optional intake is not a release package"),
    ]
)
write_csv(run_dir / "hosted_llm_rag_validation_rows.csv", ["check", "status", "reason"], validation_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md").write_text(
    "# v52e 100B+ Hosted/API LLM+RAG Optional Intake Boundary\n\n"
    "This is the optional evidence intake gate for baseline F, not a completed v52 baseline war.\n\n"
    "A valid supplied evidence directory must contain:\n\n"
    "- `model_identity.json` with `system_id=F`, hosted/API provider, 100B+ size class, credential redaction, and public-reporting policy readiness.\n"
    "- `hosted_llm_rag_answer_rows.csv` with one answer row for every v50 query ID.\n"
    "- `hosted_llm_rag_citation_rows.csv` with source-span-bound citations against the v50 source span registry.\n"
    "- `hosted_llm_rag_resource_rows.csv` with measured runtime/resource rows and redacted request hashes.\n\n"
    "Default/no-env execution intentionally remains deferred. F is optional; it cannot replace required 30B and 70B D/E rows, and it does not support 30B-150B or v1.0 comparison claims by itself.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52e-100b-plus-hosted-llm-rag-optional-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "system_id": "F",
    "v52e_100b_plus_hosted_llm_rag_optional_intake_contract_ready": 1,
    "optional_100b_plus_baseline_status": summary["optional_100b_plus_baseline_status"],
    "optional_100b_plus_baseline_ready": summary["optional_100b_plus_baseline_ready"],
    "v52_optional_absorb_ready": summary["v52_optional_absorb_ready"],
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": summary["blocking_reason"],
    "v50_summary_sha256": sha256(results / "v50_public_repo_auditor_3repo_summary.csv"),
}
(run_dir / "v52e_100b_plus_hosted_llm_rag_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "hosted_llm_rag_required_field_rows.csv",
    "hosted_llm_rag_answer_template.csv",
    "model_identity_template.json",
    "hosted_llm_rag_validation_rows.csv",
    "V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md",
    "v52e_100b_plus_hosted_llm_rag_manifest.json",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/query_set.csv",
    "source_v50/reference_poc_result_rows.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
    "source_v50/sha256_manifest.csv",
]
if evidence_dir and evidence_dir.is_dir():
    for name in [
        "model_identity.json",
        "hosted_llm_rag_answer_rows.csv",
        "hosted_llm_rag_citation_rows.csv",
        "hosted_llm_rag_resource_rows.csv",
    ]:
        rel = f"supplied_evidence/{name}"
        if (run_dir / rel).is_file():
            artifact_rels.append(rel)

artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52e_100b_plus_hosted_llm_rag_optional_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
