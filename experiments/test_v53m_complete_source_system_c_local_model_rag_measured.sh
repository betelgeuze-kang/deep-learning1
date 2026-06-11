#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53m_complete_source_system_c_local_model_rag_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53m_complete_source_system_c_local_model_rag_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53m_complete_source_system_c_local_model_rag_measured_decision.csv"

V53M_REUSE_EXISTING="${V53M_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53m_complete_source_system_c_local_model_rag_measured.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v53m summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53m_complete_source_system_c_local_model_rag_ready": "1",
    "v53_ready": "0",
    "v53l_complete_source_system_b_local_rag_ready": "1",
    "complete_source_query_rows": "1000",
    "system_id": "C",
    "system_name": "7B-14B local model + RAG",
    "model_id": "qwen2.5:7b-instruct",
    "c_answer_rows": "1000",
    "c_citation_rows": "1000",
    "c_resource_rows": "1000",
    "c_retrieval_rows": "1000",
    "c_abstain_rows": "1000",
    "c_guard_rows": "1000",
    "c_transcript_rows": "1000",
    "combined_abc_answer_rows": "3000",
    "combined_abc_citation_rows": "3000",
    "combined_abc_resource_rows": "3000",
    "v53j_compatible_answer_rows": "3000",
    "v53j_compatible_citation_rows": "3000",
    "v53j_compatible_resource_rows": "3000",
    "valid_core_system_count": "3",
    "remaining_core_system_count": "4",
    "remaining_core_systems": "D/E/G/H",
    "remaining_core_answer_rows": "4000",
    "required_core_systems_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53m {field}: expected {value}, got {summary.get(field)}")
if not (0 <= int(summary["c_strict_expected_answer_match_rows"]) <= 1000):
    raise SystemExit("v53m strict match rows should be bounded")
if not (0 <= int(summary["c_wrong_answer_rows"]) <= 1000):
    raise SystemExit("v53m wrong answer rows should be bounded")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53l-system-ab-input",
    "ollama-local-model-present",
    "system-c-answer-rows",
    "system-c-citation-rows",
    "system-c-resource-rows",
    "v53j-compatible-combined-abc-supplied-dir",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53m gate should pass: {gate}")
for gate in [
    "all-core-systems-ready",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53m gate should remain blocked: {gate}")

required_files = [
    "model_identity.json",
    "system_c_answer_rows.csv",
    "system_c_citation_rows.csv",
    "system_c_resource_rows.csv",
    "system_c_retrieval_rows.csv",
    "system_c_abstain_rows.csv",
    "system_c_wrong_answer_guard_rows.csv",
    "ollama_generation_transcript_rows.csv",
    "system_c_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53M_COMPLETE_SOURCE_SYSTEM_C_BOUNDARY.md",
    "v53m_complete_source_system_c_local_model_rag_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53l/supplied_v53j/answer_rows.csv",
    "source_v53l/supplied_v53j/citation_rows.csv",
    "source_v53l/supplied_v53j/resource_rows.csv",
    "source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53m artifact: {rel}")

identity = json.loads((run_dir / "model_identity.json").read_text(encoding="utf-8"))
if identity.get("system_id") != "C" or identity.get("model_id") != "qwen2.5:7b-instruct":
    raise SystemExit("v53m model identity mismatch")
if identity.get("external_network_used") != 0:
    raise SystemExit("v53m identity should remain local/no-network")

queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")}
spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")}
answers = read_csv(run_dir / "system_c_answer_rows.csv")
citations = read_csv(run_dir / "system_c_citation_rows.csv")
resources = read_csv(run_dir / "system_c_resource_rows.csv")
retrieval = read_csv(run_dir / "system_c_retrieval_rows.csv")
abstains = read_csv(run_dir / "system_c_abstain_rows.csv")
guards = read_csv(run_dir / "system_c_wrong_answer_guard_rows.csv")
transcripts = read_csv(run_dir / "ollama_generation_transcript_rows.csv")
for name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("resources", resources),
    ("retrieval", retrieval),
    ("abstains", abstains),
    ("guards", guards),
    ("transcripts", transcripts),
]:
    if len(rows) != 1000:
        raise SystemExit(f"v53m {name} should contain 1000 rows")

answer_by_id = {row["answer_id"]: row for row in answers}
resource_by_id = {row["resource_row_id"]: row for row in resources}
for answer in answers:
    if answer["system_id"] != "C":
        raise SystemExit("v53m answers should be System C only")
    query = queries.get(answer["query_id"])
    if query is None:
        raise SystemExit("v53m answer query binding mismatch")
    if answer["answer_text_sha256"] != sha256_text(answer["answer_text"]):
        raise SystemExit("v53m answer hash mismatch")
    if answer["expected_behavior"] != query["expected_behavior"]:
        raise SystemExit("v53m expected behavior mismatch")
    if answer["predicted_behavior"] not in {"answer-with-citation", "abstain"}:
        raise SystemExit("v53m predicted behavior should be answer-with-citation or abstain")
    if answer["output_provenance_sha256"] != provenance_hash(answer):
        raise SystemExit("v53m output provenance hash mismatch")
    if answer["resource_row_id"] not in resource_by_id:
        raise SystemExit("v53m answer missing resource row")

for citation in citations:
    answer = answer_by_id.get(citation["answer_id"])
    if answer is None:
        raise SystemExit("v53m citation missing answer binding")
    query = queries[answer["query_id"]]
    span = spans[query["source_span_id"]]
    if citation["source_span_id"] != query["source_span_id"]:
        raise SystemExit("v53m citation should bind frozen source span")
    if citation["source_file_sha256"] != span["source_file_sha256"]:
        raise SystemExit("v53m citation source hash mismatch")
    if citation["citation_text"] != span["evidence_text"]:
        raise SystemExit("v53m citation text should match source span")
    if citation["citation_text_sha256"] != sha256_text(citation["citation_text"]):
        raise SystemExit("v53m citation text hash mismatch")

for resource in resources:
    if resource["external_model_used"] != "0" or resource["external_network_used"] != "0":
        raise SystemExit("v53m resources should be local/no external model")
    if resource["model_name"] != "qwen2.5:7b-instruct":
        raise SystemExit("v53m resource model name mismatch")
    if int(resource["latency_ms"]) <= 0:
        raise SystemExit("v53m resource latency should be positive")

for row in retrieval:
    query = queries[row["query_id"]]
    if row["source_span_id"] != query["source_span_id"] or row["rank"] != "1":
        raise SystemExit("v53m retrieval should top-rank the frozen source span")

combined_ab_answers = read_csv(run_dir / "source_v53l/supplied_v53j/answer_rows.csv")
combined_ab_citations = read_csv(run_dir / "source_v53l/supplied_v53j/citation_rows.csv")
combined_ab_resources = read_csv(run_dir / "source_v53l/supplied_v53j/resource_rows.csv")
combined_answers = read_csv(run_dir / "supplied_v53j/answer_rows.csv")
combined_citations = read_csv(run_dir / "supplied_v53j/citation_rows.csv")
combined_resources = read_csv(run_dir / "supplied_v53j/resource_rows.csv")
if combined_answers != combined_ab_answers + answers:
    raise SystemExit("v53m supplied_v53j answer rows should combine A+B+C")
if combined_citations != combined_ab_citations + citations:
    raise SystemExit("v53m supplied_v53j citation rows should combine A+B+C")
if combined_resources != combined_ab_resources + resources:
    raise SystemExit("v53m supplied_v53j resource rows should combine A+B+C")

validation = {row["system_id"]: row for row in read_csv(run_dir / "v53j_partial_supplied_validation_rows.csv")}
for system_id in ["A", "B", "C"]:
    if validation[system_id]["status"] != "valid" or validation[system_id]["valid_answer_rows"] != "1000":
        raise SystemExit(f"v53m should mark {system_id} valid")
for system_id in ["D", "E", "G", "H"]:
    if validation[system_id]["status"] != "missing-or-invalid" or validation[system_id]["missing_valid_answer_rows"] != "1000":
        raise SystemExit(f"v53m should keep {system_id} missing")

metric = read_csv(run_dir / "system_c_metric_rows.csv")[0]
if metric["answer_rows"] != "1000" or metric["citation_rows"] != "1000":
    raise SystemExit("v53m metric rows mismatch")

manifest = json.loads((run_dir / "v53m_complete_source_system_c_local_model_rag_measured_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53m_complete_source_system_c_local_model_rag_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53m manifest readiness boundary mismatch")
if manifest.get("remaining_core_systems") != ["D", "E", "G", "H"]:
    raise SystemExit("v53m manifest remaining core systems mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53m sha256 mismatch: {rel}")

boundary = (run_dir / "V53M_COMPLETE_SOURCE_SYSTEM_C_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real local Ollama System C",
    "c_answer_rows=1000",
    "combined_abc_answer_rows=3000",
    "remaining_core_systems=D/E/G/H",
    "Do not publish v53 completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53m boundary missing {snippet}")
PY

echo "v53m complete-source System C local-model-RAG measured smoke passed"
