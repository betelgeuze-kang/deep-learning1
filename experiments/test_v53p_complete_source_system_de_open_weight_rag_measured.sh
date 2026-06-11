#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53p_complete_source_system_de_open_weight_rag_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53p_complete_source_system_de_open_weight_rag_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53p_complete_source_system_de_open_weight_rag_measured_decision.csv"

V53P_REUSE_EXISTING="${V53P_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53p_complete_source_system_de_open_weight_rag_measured.sh" >/dev/null

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


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def provenance_hash(row):
    packet = {
        "answer_id": row["answer_id"],
        "system_id": row["system_id"],
        "query_id": row["query_id"],
        "answer_text_sha256": row["answer_text_sha256"],
        "resource_row_id": row["resource_row_id"],
    }
    return sha256_text(json.dumps(packet, sort_keys=True, separators=(",", ":")))


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53p_complete_source_system_de_open_weight_rag_ready": "1",
    "v53_ready": "0",
    "v53o_complete_source_system_h_routehint_scorer_policy_ready": "1",
    "v52p_30b_open_weight_llm_rag_v53e_1000_ready": "1",
    "v52q_70b_open_weight_llm_rag_v53e_1000_ready": "1",
    "complete_source_query_rows": "1000",
    "d_answer_rows": "1000",
    "d_citation_rows": "1000",
    "d_resource_rows": "1000",
    "d_retrieval_rows": "1000",
    "d_abstain_rows": "1000",
    "d_negative_abstain_query_rows": "160",
    "d_strict_expected_answer_match_rows": "1000",
    "d_wrong_answer_rows": "0",
    "d_transcript_rows": "1000",
    "e_answer_rows": "1000",
    "e_citation_rows": "1000",
    "e_resource_rows": "1000",
    "e_retrieval_rows": "1000",
    "e_abstain_rows": "1000",
    "e_negative_abstain_query_rows": "160",
    "e_strict_expected_answer_match_rows": "1000",
    "e_wrong_answer_rows": "0",
    "e_transcript_rows": "1000",
    "combined_core_answer_rows": "7000",
    "combined_core_citation_rows": "7000",
    "combined_core_resource_rows": "7000",
    "v53j_compatible_answer_rows": "7000",
    "v53j_compatible_citation_rows": "7000",
    "v53j_compatible_resource_rows": "7000",
    "valid_core_system_count": "7",
    "remaining_core_system_count": "0",
    "remaining_core_systems": "",
    "remaining_core_answer_rows": "0",
    "required_core_systems_ready": "1",
    "answer_citation_resource_rows_ready": "1",
    "external_bake_import_rows": "2000",
    "same_query_set_as_v53i": "1",
    "same_source_manifest_as_v53i": "1",
    "complete_source_de_quality_claim_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53p {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53o-system-abcgh-input",
    "v52p-system-d-identity-source",
    "v52q-system-e-identity-source",
    "system-d-answer-rows",
    "system-d-citation-rows",
    "system-d-resource-rows",
    "system-e-answer-rows",
    "system-e-citation-rows",
    "system-e-resource-rows",
    "v53j-compatible-combined-core-supplied-dir",
    "all-core-systems-ready",
    "answer-citation-resource-rows-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53p gate should pass: {gate}")
for gate in [
    "complete-source-de-quality-claim",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53p gate should remain blocked: {gate}")

required_files = [
    "system_d_answer_rows.csv",
    "system_d_citation_rows.csv",
    "system_d_resource_rows.csv",
    "system_d_retrieval_rows.csv",
    "system_d_abstain_rows.csv",
    "system_d_wrong_answer_guard_rows.csv",
    "system_d_transcript_rows.csv",
    "system_d_metric_rows.csv",
    "system_e_answer_rows.csv",
    "system_e_citation_rows.csv",
    "system_e_resource_rows.csv",
    "system_e_retrieval_rows.csv",
    "system_e_abstain_rows.csv",
    "system_e_wrong_answer_guard_rows.csv",
    "system_e_transcript_rows.csv",
    "system_e_metric_rows.csv",
    "system_de_model_identity_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53P_COMPLETE_SOURCE_SYSTEM_DE_BOUNDARY.md",
    "v53p_complete_source_system_de_open_weight_rag_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53o/supplied_v53j/answer_rows.csv",
    "source_v53o/supplied_v53j/citation_rows.csv",
    "source_v53o/supplied_v53j/resource_rows.csv",
    "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
    "source_v52p/model_identity.json",
    "source_v52q/model_identity.json",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53p artifact: {rel}")

queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")}
spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")}
abcgh_answers = read_csv(run_dir / "source_v53o/supplied_v53j/answer_rows.csv")
abcgh_citations = read_csv(run_dir / "source_v53o/supplied_v53j/citation_rows.csv")
abcgh_resources = read_csv(run_dir / "source_v53o/supplied_v53j/resource_rows.csv")
if len(abcgh_answers) != 5000 or len(abcgh_citations) != 5000 or len(abcgh_resources) != 5000:
    raise SystemExit("v53p should bind v53o A+B+C+G+H rows")

for system_id in ["d", "e"]:
    upper = system_id.upper()
    answers = read_csv(run_dir / f"system_{system_id}_answer_rows.csv")
    citations = read_csv(run_dir / f"system_{system_id}_citation_rows.csv")
    resources = read_csv(run_dir / f"system_{system_id}_resource_rows.csv")
    retrieval = read_csv(run_dir / f"system_{system_id}_retrieval_rows.csv")
    abstain = read_csv(run_dir / f"system_{system_id}_abstain_rows.csv")
    guards = read_csv(run_dir / f"system_{system_id}_wrong_answer_guard_rows.csv")
    transcripts = read_csv(run_dir / f"system_{system_id}_transcript_rows.csv")
    metric = read_csv(run_dir / f"system_{system_id}_metric_rows.csv")[0]
    for name, rows in [
        ("answers", answers),
        ("citations", citations),
        ("resources", resources),
        ("retrieval", retrieval),
        ("abstain", abstain),
        ("guards", guards),
        ("transcripts", transcripts),
    ]:
        if len(rows) != 1000:
            raise SystemExit(f"v53p {upper} {name} should contain 1000 rows")
    answer_by_id = {row["answer_id"]: row for row in answers}
    resource_by_id = {row["resource_row_id"]: row for row in resources}
    for answer in answers:
        if answer["system_id"] != upper or answer["external_bake_import"] != "1" or answer["quality_claim_ready"] != "0":
            raise SystemExit(f"v53p {upper} answer boundary mismatch")
        query = queries[answer["query_id"]]
        if answer["answer_text"] != query["expected_answer"]:
            raise SystemExit(f"v53p {upper} answer should match frozen expected answer")
        if answer["answer_text_sha256"] != query["expected_answer_sha256"]:
            raise SystemExit(f"v53p {upper} answer hash mismatch")
        if answer["output_provenance_sha256"] != provenance_hash(answer):
            raise SystemExit(f"v53p {upper} provenance hash mismatch")
        if answer["resource_row_id"] not in resource_by_id:
            raise SystemExit(f"v53p {upper} answer missing resource")
    for citation in citations:
        answer = answer_by_id[citation["answer_id"]]
        query = queries[answer["query_id"]]
        span = spans[query["source_span_id"]]
        if citation["source_span_id"] != span["source_span_id"]:
            raise SystemExit(f"v53p {upper} citation span mismatch")
        if citation["citation_text"] != span["evidence_text"]:
            raise SystemExit(f"v53p {upper} citation text mismatch")
        if citation["citation_text_sha256"] != sha256_text(citation["citation_text"]):
            raise SystemExit(f"v53p {upper} citation hash mismatch")
    for row in resources:
        if row["external_model_used"] != "1" or row["external_network_used"] != "0":
            raise SystemExit(f"v53p {upper} resource model/network boundary mismatch")
        if row["external_bake_import"] != "1" or row["same_query_set_as_v53i"] != "1" or row["quality_claim_ready"] != "0":
            raise SystemExit(f"v53p {upper} resource readiness boundary mismatch")
    for row in retrieval:
        query = queries[row["query_id"]]
        if row["rank"] != "1" or row["source_span_id"] != query["source_span_id"]:
            raise SystemExit(f"v53p {upper} retrieval should top-rank frozen span")
    for row in abstain:
        query = queries[row["query_id"]]
        if row["abstained"] != ("1" if query["expected_behavior"] == "abstain" else "0"):
            raise SystemExit(f"v53p {upper} abstain row mismatch")
        if row["abstain_policy_pass"] != "1":
            raise SystemExit(f"v53p {upper} abstain policy should pass")
    for row in guards:
        if row["strict_expected_answer_match"] != "1" or row["wrong_answer"] != "0" or row["guard_status"] != "pass":
            raise SystemExit(f"v53p {upper} guard should pass")
    for row in transcripts:
        if row["external_bake_import"] != "1" or row["quality_claim_ready"] != "0":
            raise SystemExit(f"v53p {upper} transcript boundary mismatch")
    if metric["external_bake_import"] != "1" or metric["quality_claim_ready"] != "0":
        raise SystemExit(f"v53p {upper} metric boundary mismatch")
    if metric["negative_abstain_query_rows"] != "160" or metric["wrong_answer_rows"] != "0":
        raise SystemExit(f"v53p {upper} metric counts mismatch")

combined_answers = read_csv(run_dir / "supplied_v53j/answer_rows.csv")
combined_citations = read_csv(run_dir / "supplied_v53j/citation_rows.csv")
combined_resources = read_csv(run_dir / "supplied_v53j/resource_rows.csv")
if len(combined_answers) != 7000 or len(combined_citations) != 7000 or len(combined_resources) != 7000:
    raise SystemExit("v53p supplied_v53j should contain 7000 core rows")
for idx, source_row in enumerate(abcgh_answers):
    combined_row = combined_answers[idx]
    for field in ["answer_id", "system_id", "query_id", "answer_text_sha256", "resource_row_id"]:
        if combined_row.get(field) != source_row.get(field):
            raise SystemExit("v53p supplied answers should preserve v53o rows first")
if {row["system_id"] for row in combined_answers} != {"A", "B", "C", "D", "E", "G", "H"}:
    raise SystemExit("v53p supplied answers should cover all core systems")

validation = {row["system_id"]: row for row in read_csv(run_dir / "v53j_partial_supplied_validation_rows.csv")}
for system_id in ["A", "B", "C", "D", "E", "G", "H"]:
    row = validation.get(system_id)
    if not row or row["status"] != "valid" or row["valid_answer_rows"] != "1000":
        raise SystemExit(f"v53p should mark {system_id} valid")

identities = {row["system_id"]: row for row in read_csv(run_dir / "system_de_model_identity_rows.csv")}
if identities["D"]["size_class"] != "30b" or identities["E"]["size_class"] != "70b":
    raise SystemExit("v53p D/E identity size class mismatch")
if identities["D"]["quality_claim_ready"] != "0" or identities["E"]["quality_claim_ready"] != "0":
    raise SystemExit("v53p identities should not claim quality readiness")

manifest = json.loads((run_dir / "v53p_complete_source_system_de_open_weight_rag_measured_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53p_complete_source_system_de_open_weight_rag_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53p manifest readiness boundary mismatch")
if manifest.get("combined_core_answer_rows") != 7000 or manifest.get("complete_source_de_quality_claim_ready") != 0:
    raise SystemExit("v53p manifest row/quality boundary mismatch")

boundary = (run_dir / "V53P_COMPLETE_SOURCE_SYSTEM_DE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "systems=D/E",
    "d_answer_rows=1000",
    "e_answer_rows=1000",
    "combined_core_answer_rows=7000",
    "answer_citation_resource_rows_ready=1",
    "complete_source_de_quality_claim_ready=0",
    "symmetric_scorer_policy_rows_ready=0",
    "v53_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53p boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in sha_rows:
        raise SystemExit(f"v53p sha manifest missing: {rel}")
    if sha_rows[rel] != sha256(run_dir / rel):
        raise SystemExit(f"v53p sha256 mismatch: {rel}")
PY

echo "v53p complete-source System D/E open-weight RAG smoke passed"
