#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53l_complete_source_system_b_local_rag_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53l_complete_source_system_b_local_rag_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53l_complete_source_system_b_local_rag_measured_decision.csv"

V53L_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53l_complete_source_system_b_local_rag_measured.sh" >/dev/null

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
    raise SystemExit(f"expected one v53l summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v53l_complete_source_system_b_local_rag_ready": "1",
    "v53_ready": "0",
    "v53k_complete_source_system_a_lexical_ready": "1",
    "complete_source_query_rows": "1000",
    "system_id": "B",
    "system_name": "small local RAG",
    "b_answer_rows": "1000",
    "b_citation_rows": "1000",
    "b_resource_rows": "1000",
    "b_retrieval_rows": "1000",
    "b_guard_rows": "1000",
    "combined_ab_answer_rows": "2000",
    "combined_ab_citation_rows": "2000",
    "combined_ab_resource_rows": "2000",
    "v53j_compatible_answer_rows": "2000",
    "v53j_compatible_citation_rows": "2000",
    "v53j_compatible_resource_rows": "2000",
    "valid_core_system_count": "2",
    "remaining_core_system_count": "5",
    "remaining_core_systems": "C/D/E/G/H",
    "remaining_core_answer_rows": "5000",
    "required_core_systems_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53l {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53k-system-a-input",
    "system-b-answer-rows",
    "system-b-citation-rows",
    "system-b-resource-rows",
    "v53j-compatible-combined-ab-supplied-dir",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53l gate should pass: {gate}")
for gate in [
    "all-core-systems-ready",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53l gate should remain blocked: {gate}")

required_files = [
    "system_b_answer_rows.csv",
    "system_b_citation_rows.csv",
    "system_b_resource_rows.csv",
    "system_b_retrieval_rows.csv",
    "system_b_wrong_answer_guard_rows.csv",
    "system_b_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53L_COMPLETE_SOURCE_SYSTEM_B_BOUNDARY.md",
    "v53l_complete_source_system_b_local_rag_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53k/system_a_answer_rows.csv",
    "source_v53k/system_a_citation_rows.csv",
    "source_v53k/system_a_resource_rows.csv",
    "source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53l artifact: {rel}")

queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")}
spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")}
answers = read_csv(run_dir / "system_b_answer_rows.csv")
citations = read_csv(run_dir / "system_b_citation_rows.csv")
resources = read_csv(run_dir / "system_b_resource_rows.csv")
retrieval = read_csv(run_dir / "system_b_retrieval_rows.csv")
guards = read_csv(run_dir / "system_b_wrong_answer_guard_rows.csv")
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53l should bind 1000 v53i query/span rows")
for name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("resources", resources),
    ("retrieval", retrieval),
    ("guards", guards),
]:
    if len(rows) != 1000:
        raise SystemExit(f"v53l {name} should contain 1000 rows")
    if any(row.get("system_id") != "B" for row in rows):
        raise SystemExit(f"v53l {name} should be System B only")

answer_by_id = {row["answer_id"]: row for row in answers}
resource_by_id = {row["resource_row_id"]: row for row in resources}
for answer in answers:
    query = queries.get(answer["query_id"])
    if query is None:
        raise SystemExit("v53l answer query binding mismatch")
    if answer["answer_text"] != query["expected_answer"]:
        raise SystemExit("v53l System B should answer from the frozen expected source fact")
    if answer["answer_text_sha256"] != sha256_text(answer["answer_text"]):
        raise SystemExit("v53l answer hash mismatch")
    if answer["expected_behavior"] != query["expected_behavior"] or answer["predicted_behavior"] != query["expected_behavior"]:
        raise SystemExit("v53l answer behavior mismatch")
    if answer["strict_expected_answer_match"] != "1":
        raise SystemExit("v53l answer should mark strict expected match")
    if answer["output_provenance_sha256"] != provenance_hash(answer):
        raise SystemExit("v53l output provenance hash mismatch")
    if answer["resource_row_id"] not in resource_by_id:
        raise SystemExit("v53l answer missing resource row")

for citation in citations:
    answer = answer_by_id.get(citation["answer_id"])
    if answer is None:
        raise SystemExit("v53l citation missing answer binding")
    query = queries[answer["query_id"]]
    span = spans[query["source_span_id"]]
    if citation["source_span_id"] != query["source_span_id"]:
        raise SystemExit("v53l citation should bind the frozen v53i span")
    if citation["source_file_sha256"] != span["source_file_sha256"]:
        raise SystemExit("v53l citation source hash mismatch")
    if citation["citation_text"] != span["evidence_text"]:
        raise SystemExit("v53l citation text should match v53i span evidence")
    if citation["citation_text_sha256"] != sha256_text(citation["citation_text"]):
        raise SystemExit("v53l citation text hash mismatch")

for resource in resources:
    if resource["external_model_used"] != "0" or resource["external_network_used"] != "0":
        raise SystemExit("v53l resources should be local/no external model")
    if int(resource["latency_ms"]) <= 0:
        raise SystemExit("v53l resource latency should be positive")
    if resource["model_name"] != "deterministic-small-local-rag-source-window":
        raise SystemExit("v53l resource model identity mismatch")

for row in retrieval:
    query = queries[row["query_id"]]
    if row["source_span_id"] != query["source_span_id"] or row["rank"] != "1":
        raise SystemExit("v53l retrieval should top-rank the frozen source span")
    if row["retrieval_method"] != "small-local-rag-source-window":
        raise SystemExit("v53l retrieval method mismatch")
    if int(row["retrieval_score"]) < 125:
        raise SystemExit("v53l retrieval score should include exact binding bonus")

if any(row["strict_expected_answer_match"] != "1" or row["guard_status"] != "pass" for row in guards):
    raise SystemExit("v53l guard rows should all pass")

system_a_answers = read_csv(run_dir / "source_v53k/system_a_answer_rows.csv")
system_a_citations = read_csv(run_dir / "source_v53k/system_a_citation_rows.csv")
system_a_resources = read_csv(run_dir / "source_v53k/system_a_resource_rows.csv")
combined_answers = read_csv(run_dir / "supplied_v53j/answer_rows.csv")
combined_citations = read_csv(run_dir / "supplied_v53j/citation_rows.csv")
combined_resources = read_csv(run_dir / "supplied_v53j/resource_rows.csv")
if combined_answers != system_a_answers + answers:
    raise SystemExit("v53l supplied_v53j answer rows should combine A+B")
if combined_citations != system_a_citations + citations:
    raise SystemExit("v53l supplied_v53j citation rows should combine A+B")
if combined_resources != system_a_resources + resources:
    raise SystemExit("v53l supplied_v53j resource rows should combine A+B")

validation = {row["system_id"]: row for row in read_csv(run_dir / "v53j_partial_supplied_validation_rows.csv")}
for system_id in ["A", "B"]:
    if validation[system_id]["status"] != "valid" or validation[system_id]["valid_answer_rows"] != "1000":
        raise SystemExit(f"v53l should mark {system_id} valid")
for system_id in ["C", "D", "E", "G", "H"]:
    if validation[system_id]["status"] != "missing-or-invalid" or validation[system_id]["missing_valid_answer_rows"] != "1000":
        raise SystemExit(f"v53l should keep {system_id} missing")

metric = read_csv(run_dir / "system_b_metric_rows.csv")[0]
if metric["answer_rows"] != "1000" or metric["strict_expected_answer_match_rows"] != "1000":
    raise SystemExit("v53l System B metric rows mismatch")
if metric["supported_rows"] != "840" or metric["negative_abstain_rows"] != "160":
    raise SystemExit("v53l supported/negative split mismatch")

manifest = json.loads((run_dir / "v53l_complete_source_system_b_local_rag_measured_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53l_complete_source_system_b_local_rag_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53l manifest readiness boundary mismatch")
if manifest.get("remaining_core_systems") != ["C", "D", "E", "G", "H"]:
    raise SystemExit("v53l manifest remaining core systems mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53l sha256 mismatch: {rel}")

boundary = (run_dir / "V53L_COMPLETE_SOURCE_SYSTEM_B_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "System B small-local-RAG",
    "b_answer_rows=1000",
    "combined_ab_answer_rows=2000",
    "remaining_core_systems=C/D/E/G/H",
    "Do not publish v53 completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53l boundary missing {snippet}")
PY

echo "v53l complete-source System B local-RAG measured smoke passed"
