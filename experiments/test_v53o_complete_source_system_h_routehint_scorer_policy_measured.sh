#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53o_complete_source_system_h_routehint_scorer_policy_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53o_complete_source_system_h_routehint_scorer_policy_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53o_complete_source_system_h_routehint_scorer_policy_measured_decision.csv"

V53O_REUSE_EXISTING="${V53O_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53o_complete_source_system_h_routehint_scorer_policy_measured.sh" >/dev/null

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
    "v53o_complete_source_system_h_routehint_scorer_policy_ready": "1",
    "v53_ready": "0",
    "v53n_complete_source_system_g_routehint_ready": "1",
    "complete_source_query_rows": "1000",
    "system_id": "H",
    "system_name": "RouteMemory + RouteHint + source-verified scorer + domain policy",
    "h_answer_rows": "1000",
    "h_citation_rows": "1000",
    "h_resource_rows": "1000",
    "h_retrieval_rows": "1000",
    "h_route_memory_evidence_rows": "1000",
    "h_compact_routehint_rows": "1000",
    "h_source_verified_scorer_rows": "1000",
    "h_domain_policy_rows": "1000",
    "h_guard_rows": "1000",
    "h_strict_expected_answer_match_rows": "1000",
    "h_wrong_answer_rows": "0",
    "h_raw_prompt_context_bytes": "0",
    "combined_abcgh_answer_rows": "5000",
    "combined_abcgh_citation_rows": "5000",
    "combined_abcgh_resource_rows": "5000",
    "v53j_compatible_answer_rows": "5000",
    "v53j_compatible_citation_rows": "5000",
    "v53j_compatible_resource_rows": "5000",
    "valid_core_system_count": "5",
    "remaining_core_system_count": "2",
    "remaining_core_systems": "D/E",
    "remaining_core_answer_rows": "2000",
    "required_core_systems_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53o {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53n-system-abcg-input",
    "system-h-answer-rows",
    "system-h-citation-rows",
    "system-h-resource-rows",
    "system-h-route-memory-evidence",
    "system-h-compact-routehint",
    "system-h-source-verified-scorer",
    "system-h-domain-policy",
    "v53j-compatible-combined-abcgh-supplied-dir",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53o gate should pass: {gate}")
for gate in [
    "all-core-systems-ready",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53o gate should remain blocked: {gate}")

required_files = [
    "system_h_answer_rows.csv",
    "system_h_citation_rows.csv",
    "system_h_resource_rows.csv",
    "system_h_retrieval_rows.csv",
    "system_h_wrong_answer_guard_rows.csv",
    "route_memory_evidence_rows.csv",
    "compact_routehint_rows.csv",
    "source_verified_scorer_rows.csv",
    "domain_policy_rows.csv",
    "domain_policy_summary_rows.csv",
    "system_h_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53O_COMPLETE_SOURCE_SYSTEM_H_BOUNDARY.md",
    "v53o_complete_source_system_h_routehint_scorer_policy_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53n/supplied_v53j/answer_rows.csv",
    "source_v53n/supplied_v53j/citation_rows.csv",
    "source_v53n/supplied_v53j/resource_rows.csv",
    "source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53o artifact: {rel}")

queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")}
spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")}
answers = read_csv(run_dir / "system_h_answer_rows.csv")
citations = read_csv(run_dir / "system_h_citation_rows.csv")
resources = read_csv(run_dir / "system_h_resource_rows.csv")
retrieval = read_csv(run_dir / "system_h_retrieval_rows.csv")
guards = read_csv(run_dir / "system_h_wrong_answer_guard_rows.csv")
route_memory = read_csv(run_dir / "route_memory_evidence_rows.csv")
routehint = read_csv(run_dir / "compact_routehint_rows.csv")
scorer = read_csv(run_dir / "source_verified_scorer_rows.csv")
policy = read_csv(run_dir / "domain_policy_rows.csv")
for name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("resources", resources),
    ("retrieval", retrieval),
    ("guards", guards),
    ("route_memory", route_memory),
    ("routehint", routehint),
    ("scorer", scorer),
    ("policy", policy),
]:
    if len(rows) != 1000:
        raise SystemExit(f"v53o {name} should contain 1000 rows")

answer_by_id = {row["answer_id"]: row for row in answers}
resource_by_id = {row["resource_row_id"]: row for row in resources}
for answer in answers:
    if answer["system_id"] != "H" or answer["strict_expected_answer_match"] != "1":
        raise SystemExit("v53o answers should be exact System H rows")
    query = queries.get(answer["query_id"])
    if query is None:
        raise SystemExit("v53o answer query binding mismatch")
    if answer["answer_text"] != query["expected_answer"]:
        raise SystemExit("v53o answer should match expected answer")
    if answer["answer_text_sha256"] != query["expected_answer_sha256"]:
        raise SystemExit("v53o answer hash mismatch")
    if answer["output_provenance_sha256"] != provenance_hash(answer):
        raise SystemExit("v53o output provenance hash mismatch")
    if answer["resource_row_id"] not in resource_by_id:
        raise SystemExit("v53o answer missing resource row")

for citation in citations:
    answer = answer_by_id.get(citation["answer_id"])
    if answer is None:
        raise SystemExit("v53o citation missing answer binding")
    query = queries[answer["query_id"]]
    span = spans[query["source_span_id"]]
    if citation["source_span_id"] != query["source_span_id"]:
        raise SystemExit("v53o citation should bind frozen source span")
    if citation["citation_text"] != span["evidence_text"]:
        raise SystemExit("v53o citation text should match source span")
    if citation["citation_text_sha256"] != sha256_text(citation["citation_text"]):
        raise SystemExit("v53o citation hash mismatch")

for row in resources:
    if row["external_model_used"] != "0" or row["external_network_used"] != "0":
        raise SystemExit("v53o resources should be local/no external model")
    if row["model_name"] != "deterministic-routememory-routehint-source-verified-scorer-domain-policy":
        raise SystemExit("v53o resource model name mismatch")
for row in retrieval:
    query = queries[row["query_id"]]
    if row["source_span_id"] != query["source_span_id"] or row["rank"] != "1":
        raise SystemExit("v53o retrieval should top-rank the frozen source span")
for row in route_memory:
    if row["route_memory_lookup_ready"] != "1" or row["route_jump_rows"] != "0":
        raise SystemExit("v53o route memory readiness mismatch")
for row in routehint:
    if row["raw_prompt_context_bytes"] != "0" or row["route_jump_rows"] != "0":
        raise SystemExit("v53o route hints should avoid raw prompt context and route jumps")
    if row["compact_route_hint_sha256"] != sha256_text(row["compact_route_hint"]):
        raise SystemExit("v53o route hint hash mismatch")
for row in scorer:
    if row["source_verified_scorer_applied"] != "1" or row["source_verified_score"] != "1.000000":
        raise SystemExit("v53o scorer rows should be applied")
    if row["symmetric_scorer_policy_row"] != "0":
        raise SystemExit("v53o should not claim symmetric scorer rows")
for row in policy:
    if row["domain_policy_applied"] != "1" or row["domain_policy_score"] != "1.000000":
        raise SystemExit("v53o domain policy rows should be applied")
    if row["symmetric_scorer_policy_row"] != "0":
        raise SystemExit("v53o should not claim symmetric policy rows")
for row in guards:
    if row["strict_expected_answer_match"] != "1" or row["wrong_answer"] != "0" or row["guard_status"] != "pass":
        raise SystemExit("v53o guard rows should pass")

combined_abcg_answers = read_csv(run_dir / "source_v53n/supplied_v53j/answer_rows.csv")
combined_abcg_citations = read_csv(run_dir / "source_v53n/supplied_v53j/citation_rows.csv")
combined_abcg_resources = read_csv(run_dir / "source_v53n/supplied_v53j/resource_rows.csv")
combined_answers = read_csv(run_dir / "supplied_v53j/answer_rows.csv")
combined_citations = read_csv(run_dir / "supplied_v53j/citation_rows.csv")
combined_resources = read_csv(run_dir / "supplied_v53j/resource_rows.csv")
if combined_answers != combined_abcg_answers + answers:
    raise SystemExit("v53o supplied_v53j answer rows should combine A+B+C+G+H")
if combined_citations != combined_abcg_citations + citations:
    raise SystemExit("v53o supplied_v53j citation rows should combine A+B+C+G+H")
if combined_resources != combined_abcg_resources + resources:
    raise SystemExit("v53o supplied_v53j resource rows should combine A+B+C+G+H")

validation = {row["system_id"]: row for row in read_csv(run_dir / "v53j_partial_supplied_validation_rows.csv")}
for system_id in ["A", "B", "C", "G", "H"]:
    if validation[system_id]["status"] != "valid" or validation[system_id]["valid_answer_rows"] != "1000":
        raise SystemExit(f"v53o should mark {system_id} valid")
for system_id in ["D", "E"]:
    if validation[system_id]["status"] != "missing-or-invalid" or validation[system_id]["missing_valid_answer_rows"] != "1000":
        raise SystemExit(f"v53o should keep {system_id} missing")

metric = read_csv(run_dir / "system_h_metric_rows.csv")[0]
if metric["raw_prompt_context_bytes"] != "0" or metric["symmetric_scorer_policy_rows_ready"] != "0":
    raise SystemExit("v53o metric boundary mismatch")

manifest = json.loads((run_dir / "v53o_complete_source_system_h_routehint_scorer_policy_measured_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53o_complete_source_system_h_routehint_scorer_policy_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53o manifest readiness boundary mismatch")
if manifest.get("remaining_core_systems") != ["D", "E"]:
    raise SystemExit("v53o manifest remaining core systems mismatch")

boundary = (run_dir / "V53O_COMPLETE_SOURCE_SYSTEM_H_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "System H RouteMemory + RouteHint + source-verified scorer + domain policy",
    "h_answer_rows=1000",
    "h_source_verified_scorer_rows=1000",
    "h_domain_policy_rows=1000",
    "combined_abcgh_answer_rows=5000",
    "remaining_core_systems=D/E",
    "symmetric_scorer_policy_rows_ready=0",
    "Do not publish v53 completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53o boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53o sha256 mismatch: {rel}")
PY

echo "v53o complete-source System H RouteHint scorer/policy measured smoke passed"
