#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52c_7b14b_local_model_rag_evidence_intake"
RUN_ID="${V52C_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EVIDENCE_DIR="${V52C_LOCAL_MODEL_RAG_EVIDENCE_DIR:-}"

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
    except ValueError:
        errors.append(f"{field}-not-integer")
        return 0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-{minimum}")
    return value


def float_value(row, field, errors, minimum=None, maximum=None):
    try:
        value = float(row.get(field, ""))
    except ValueError:
        errors.append(f"{field}-not-float")
        return 0.0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-{minimum}")
    if maximum is not None and value > maximum:
        errors.append(f"{field}-above-{maximum}")
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
case_by_id = {case["case_id"]: case for case in cases}
span_keys = {(row["case_id"], row["kind"], row["path"], row["sha256"], row["line"]) for row in spans}

schema_rows = [
    {"artifact": "model_identity.json", "field": "system_id", "required": 1, "rule": "must equal C"},
    {"artifact": "model_identity.json", "field": "model_id", "required": 1, "rule": "stable local model identifier"},
    {"artifact": "model_identity.json", "field": "parameter_count_b", "required": 1, "rule": "float in [7, 14]"},
    {"artifact": "model_identity.json", "field": "model_artifact_sha256", "required": 1, "rule": "sha256:<64 hex>"},
    {"artifact": "local_model_rag_answer_rows.csv", "field": "query_id", "required": 1, "rule": "must cover every v50 query id exactly once"},
    {"artifact": "local_model_rag_answer_rows.csv", "field": "system_id", "required": 1, "rule": "must equal C"},
    {"artifact": "local_model_rag_answer_rows.csv", "field": "predicted_label", "required": 1, "rule": "scored against v50 expected_label"},
    {"artifact": "local_model_rag_answer_rows.csv", "field": "raw_prompt_context_bytes", "required": 1, "rule": "positive integer"},
    {"artifact": "local_model_rag_answer_rows.csv", "field": "output_sha256", "required": 1, "rule": "sha256:<64 hex>"},
    {"artifact": "local_model_rag_citation_rows.csv", "field": "query_id", "required": 1, "rule": "must reference covered answer rows"},
    {"artifact": "local_model_rag_citation_rows.csv", "field": "case_id/kind/path/sha256/line", "required": 1, "rule": "must bind to v50 source spans"},
    {"artifact": "local_model_rag_resource_rows.csv", "field": "external_network_used", "required": 1, "rule": "must be 0 for local-model baseline C"},
]
write_csv(run_dir / "local_model_rag_required_field_rows.csv", list(schema_rows[0].keys()), schema_rows)

template_answer_rows = []
for query in queries:
    case = case_by_query[query["query_id"]]
    template_answer_rows.append(
        {
            "system_id": "C",
            "query_id": query["query_id"],
            "case_id": case["case_id"],
            "model_id": "replace-with-7b-14b-local-model-id",
            "expected_label": case["expected_label"],
            "predicted_label": "",
            "answer": "",
            "raw_prompt_context_bytes": "",
            "retrieved_span_rows": "",
            "prompt_context_sha256": "",
            "output_sha256": "",
            "latency_ns": "",
            "route_memory_store_used": "0",
            "compact_routehint_used": "0",
        }
    )
write_csv(run_dir / "local_model_rag_answer_template.csv", list(template_answer_rows[0].keys()), template_answer_rows)

identity_template = {
    "system_id": "C",
    "model_id": "replace-with-7b-14b-local-model-id",
    "parameter_count_b": None,
    "size_class": "7b-14b",
    "runner": "llama.cpp|ollama|vllm|transformers|other",
    "quantization": "record exact quantization or none",
    "model_artifact_uri": "local path or HTTPS model artifact identifier",
    "model_artifact_sha256": "sha256:<64 hex>",
    "rag_context_builder": "describe retrieval and prompt assembly",
    "context_length": None,
    "external_network_used": 0,
}
(run_dir / "model_identity_template.json").write_text(json.dumps(identity_template, indent=2, sort_keys=True) + "\n", encoding="utf-8")

validation_rows = []
decision_rows = [
    ("intake-contract", "pass", "C baseline evidence schema and templates are emitted"),
    ("public-repo-seed", "pass", "uses v50 3-repo / 9-query seed"),
]

evidence_dir = Path(evidence_dir_arg) if evidence_dir_arg else None
summary = {
    "v52c_7b14b_local_model_rag_intake_contract_ready": 1,
    "system_id": "C",
    "baseline_name": "7B-14B local model + RAG",
    "required_size_class": "7b-14b",
    "evidence_dir_supplied": int(bool(evidence_dir_arg)),
    "supplied_evidence_ready": 0,
    "model_identity_ready": 0,
    "model_size_class_ready": 0,
    "answer_rows_ready": 0,
    "citation_rows_ready": 0,
    "resource_rows_ready": 0,
    "query_rows": 0,
    "answer_rows": 0,
    "correct_rows": 0,
    "accuracy": "0.000000",
    "citation_rows": 0,
    "citation_correct_rows": 0,
    "citation_accuracy": "0.000000",
    "raw_prompt_context_rows": 0,
    "avg_latency_ns": 0,
    "external_network_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v50_seed_query_rows": int(v50_summary.get("audit_case_rows", "0")),
    "v52_absorb_ready": 0,
    "v52_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": "local-model-rag-evidence-dir-missing",
    "validation_error_rows": 0,
}

if evidence_dir and evidence_dir.is_dir():
    required = {
        "identity": evidence_dir / "model_identity.json",
        "answers": evidence_dir / "local_model_rag_answer_rows.csv",
        "citations": evidence_dir / "local_model_rag_citation_rows.csv",
        "resources": evidence_dir / "local_model_rag_resource_rows.csv",
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
        if identity.get("system_id") != "C":
            errors.append("identity-system-id-not-C")
        parameter_count_b = float_value(identity, "parameter_count_b", errors, minimum=7.0, maximum=14.0)
        if not identity.get("model_id"):
            errors.append("identity-model-id-missing")
        if not is_sha256(identity.get("model_artifact_sha256", "")):
            errors.append("identity-model-artifact-sha256-invalid")
        if int(identity.get("external_network_used", 0)) != 0:
            errors.append("identity-external-network-used-not-zero")
        model_id = identity.get("model_id", "")

        answers = read_csv(required["answers"])
        citations = read_csv(required["citations"])
        resources = read_csv(required["resources"])
        answer_query_ids = [row.get("query_id", "") for row in answers]
        expected_query_ids = [row["query_id"] for row in queries]
        if sorted(answer_query_ids) != sorted(expected_query_ids) or len(answer_query_ids) != len(set(answer_query_ids)):
            errors.append("answer-query-coverage-mismatch")
        correct_rows = 0
        latency_ns_total = 0
        raw_context_rows = 0
        for row in answers:
            query_id = row.get("query_id", "")
            case = case_by_query.get(query_id)
            row_errors = []
            if row.get("system_id") != "C":
                row_errors.append("answer-system-id-not-C")
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
            latency_ns_total += int_value(row, "latency_ns", row_errors, minimum=1)
            if not is_sha256(row.get("prompt_context_sha256", "")):
                row_errors.append("answer-prompt-context-sha256-invalid")
            if not is_sha256(row.get("output_sha256", "")):
                row_errors.append("answer-output-sha256-invalid")
            if row.get("route_memory_store_used") != "0" or row.get("compact_routehint_used") != "0":
                row_errors.append("answer-route-memory-or-routehint-not-zero")
            errors.extend(f"{query_id}:{err}" for err in row_errors)

        citation_correct_rows = 0
        citation_query_ids = {row.get("query_id", "") for row in citations}
        if citation_query_ids != set(expected_query_ids):
            errors.append("citation-query-coverage-mismatch")
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
            if row.get("external_network_used") != "0":
                row_errors.append("resource-external-network-used-not-zero")
            errors.extend(f"{row.get('query_id', '')}:resource:{err}" for err in row_errors)

        if not errors:
            query_rows = len(expected_query_ids)
            summary.update(
                {
                    "supplied_evidence_ready": 1,
                    "model_identity_ready": 1,
                    "model_size_class_ready": int(7.0 <= parameter_count_b <= 14.0),
                    "answer_rows_ready": 1,
                    "citation_rows_ready": 1,
                    "resource_rows_ready": 1,
                    "query_rows": query_rows,
                    "answer_rows": len(answers),
                    "correct_rows": correct_rows,
                    "accuracy": f"{correct_rows / query_rows:.6f}",
                    "citation_rows": len(citations),
                    "citation_correct_rows": citation_correct_rows,
                    "citation_accuracy": f"{citation_correct_rows / len(citations):.6f}" if citations else "0.000000",
                    "raw_prompt_context_rows": raw_context_rows,
                    "avg_latency_ns": latency_ns_total // query_rows,
                    "v52_absorb_ready": 1,
                    "blocking_reason": "",
                }
            )
            decision_rows.append(("7b-14b-local-model-rag-evidence", "pass", "supplied C evidence directory validates"))
            decision_rows.append(("v52-absorb-ready", "pass", "C row can be consumed by a later v52 registry update"))
        else:
            for err in errors:
                validation_rows.append({"check": "supplied-evidence", "status": "fail", "reason": err})
            summary["blocking_reason"] = "supplied-local-model-rag-evidence-invalid"
else:
    validation_rows.append({"check": "evidence-dir", "status": "blocked", "reason": "V52C_LOCAL_MODEL_RAG_EVIDENCE_DIR not supplied"})

if not summary["supplied_evidence_ready"]:
    decision_rows.append(("7b-14b-local-model-rag-evidence", "blocked", summary["blocking_reason"]))
    decision_rows.append(("v52-absorb-ready", "blocked", "C row cannot be absorbed until supplied evidence validates"))

decision_rows.extend(
    [
        ("30b-llm-rag-real-row", "blocked", "D row is still missing"),
        ("70b-llm-rag-real-row", "blocked", "E row is still missing"),
        ("v52-full-baseline-war", "blocked", "v52 still needs D/E and release-scale evidence even if C is supplied"),
        ("real-release-package", "blocked", "this intake is not a release package"),
    ]
)

summary["validation_error_rows"] = sum(1 for row in validation_rows if row["status"] == "fail")
write_csv(run_dir / "local_model_rag_validation_rows.csv", ["check", "status", "reason"], validation_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V52C_7B14B_LOCAL_MODEL_RAG_BOUNDARY.md").write_text(
    "# v52c 7B-14B Local Model + RAG Evidence Intake Boundary\n\n"
    "This is the evidence intake gate for baseline C, not a completed v52 baseline war.\n\n"
    "A valid supplied evidence directory must contain:\n\n"
    "- `model_identity.json` with `system_id=C`, a stable model ID, a 7B-14B parameter count, and sha256-bound model artifact identity.\n"
    "- `local_model_rag_answer_rows.csv` with one answer row for every v50 query ID.\n"
    "- `local_model_rag_citation_rows.csv` with source-span-bound citations against the v50 source span registry.\n"
    "- `local_model_rag_resource_rows.csv` with local runtime/resource rows and `external_network_used=0`.\n\n"
    "Default/no-env execution intentionally remains blocked. Do not publish C, 30B-150B, or v1.0 comparison claims from this contract alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52c-7b14b-local-model-rag-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "system_id": "C",
    "required_size_class": "7b-14b",
    "v52c_7b14b_local_model_rag_intake_contract_ready": 1,
    "supplied_evidence_ready": summary["supplied_evidence_ready"],
    "v52_absorb_ready": summary["v52_absorb_ready"],
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": summary["blocking_reason"],
    "v50_summary_sha256": sha256(results / "v50_public_repo_auditor_3repo_summary.csv"),
}
(run_dir / "v52c_7b14b_local_model_rag_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "local_model_rag_required_field_rows.csv",
    "local_model_rag_answer_template.csv",
    "model_identity_template.json",
    "local_model_rag_validation_rows.csv",
    "V52C_7B14B_LOCAL_MODEL_RAG_BOUNDARY.md",
    "v52c_7b14b_local_model_rag_manifest.json",
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
        "local_model_rag_answer_rows.csv",
        "local_model_rag_citation_rows.csv",
        "local_model_rag_resource_rows.csv",
    ]:
        rel = f"supplied_evidence/{name}"
        if (run_dir / rel).is_file():
            artifact_rels.append(rel)

artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52c_7b14b_local_model_rag_evidence_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
