#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53n_complete_source_system_g_routehint_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53n_complete_source_system_g_routehint_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53n_complete_source_system_g_routehint_measured_decision.csv"

V53N_REUSE_EXISTING="${V53N_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53n_complete_source_system_g_routehint_measured.sh" >/dev/null

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


def rows_match_with_blank_schema_extension(actual_rows, expected_rows):
    if len(actual_rows) != len(expected_rows):
        return False
    for actual, expected in zip(actual_rows, expected_rows):
        for key, value in expected.items():
            if actual.get(key) != value:
                return False
        for key, value in actual.items():
            if key not in expected and value not in ("", None):
                return False
    return True


summary = read_csv(summary_csv)[0]
expected = {
    "v53n_complete_source_system_g_routehint_ready": "1",
    "v53_ready": "0",
    "v53m_complete_source_system_c_local_model_rag_ready": "1",
    "complete_source_query_rows": "1000",
    "system_id": "G",
    "system_name": "RouteMemory + RouteHint",
    "g_answer_rows": "1000",
    "g_citation_rows": "1000",
    "g_resource_rows": "1000",
    "g_retrieval_rows": "1000",
    "g_route_memory_evidence_rows": "1000",
    "g_compact_routehint_rows": "1000",
    "g_guard_rows": "1000",
    "g_strict_expected_answer_match_rows": "1000",
    "g_wrong_answer_rows": "0",
    "g_raw_prompt_context_bytes": "0",
    "combined_abcg_answer_rows": "4000",
    "combined_abcg_citation_rows": "4000",
    "combined_abcg_resource_rows": "4000",
    "v53j_compatible_answer_rows": "4000",
    "v53j_compatible_citation_rows": "4000",
    "v53j_compatible_resource_rows": "4000",
    "valid_core_system_count": "4",
    "remaining_core_system_count": "3",
    "remaining_core_systems": "D/E/H",
    "remaining_core_answer_rows": "3000",
    "required_core_systems_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
    "answer_source": "v53i_expected_answer_oracle_replay",
    "execution_mode": "expected-answer-oracle-replay",
    "expected_answer_oracle_replay": "1",
    "expected_answer_oracle_replay_rows": "1000",
    "actual_adapter_execution_ready": "0",
    "real_system_performance_claim_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53n {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53m-system-abc-input",
    "system-g-answer-rows",
    "system-g-citation-rows",
    "system-g-resource-rows",
    "system-g-route-memory-evidence",
    "system-g-compact-routehint",
    "v53j-compatible-combined-abcg-supplied-dir",
    "oracle-replay-disclosed",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53n gate should pass: {gate}")
for gate in [
    "all-core-systems-ready",
    "symmetric-scorer-policy-rows",
    "human-review-artifacts",
    "actual-adapter-execution",
    "real-system-performance-claim",
    "v53-full-public-repo-audit",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53n gate should remain blocked: {gate}")

required_files = [
    "system_g_answer_rows.csv",
    "system_g_citation_rows.csv",
    "system_g_resource_rows.csv",
    "system_g_retrieval_rows.csv",
    "system_g_wrong_answer_guard_rows.csv",
    "route_memory_evidence_rows.csv",
    "compact_routehint_rows.csv",
    "routehint_scorer_policy_preview_rows.csv",
    "system_g_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53N_COMPLETE_SOURCE_SYSTEM_G_BOUNDARY.md",
    "v53n_complete_source_system_g_routehint_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53m/supplied_v53j/answer_rows.csv",
    "source_v53m/supplied_v53j/citation_rows.csv",
    "source_v53m/supplied_v53j/resource_rows.csv",
    "source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53n artifact: {rel}")

queries = {row["query_id"]: row for row in read_csv(run_dir / "source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")}
spans = {row["source_span_id"]: row for row in read_csv(run_dir / "source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")}
answers = read_csv(run_dir / "system_g_answer_rows.csv")
citations = read_csv(run_dir / "system_g_citation_rows.csv")
resources = read_csv(run_dir / "system_g_resource_rows.csv")
retrieval = read_csv(run_dir / "system_g_retrieval_rows.csv")
guards = read_csv(run_dir / "system_g_wrong_answer_guard_rows.csv")
route_memory = read_csv(run_dir / "route_memory_evidence_rows.csv")
routehint = read_csv(run_dir / "compact_routehint_rows.csv")
for name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("resources", resources),
    ("retrieval", retrieval),
    ("guards", guards),
    ("route_memory", route_memory),
    ("routehint", routehint),
]:
    if len(rows) != 1000:
        raise SystemExit(f"v53n {name} should contain 1000 rows")

answer_by_id = {row["answer_id"]: row for row in answers}
resource_by_id = {row["resource_row_id"]: row for row in resources}
for answer in answers:
    if answer["system_id"] != "G" or answer["strict_expected_answer_match"] != "1":
        raise SystemExit("v53n answers should be exact System G rows")
    query = queries.get(answer["query_id"])
    if query is None:
        raise SystemExit("v53n answer query binding mismatch")
    if answer["answer_text"] != query["expected_answer"]:
        raise SystemExit("v53n answer should match expected answer")
    if answer["answer_text_sha256"] != query["expected_answer_sha256"]:
        raise SystemExit("v53n answer hash mismatch")
    if answer["answer_source"] != "v53i_expected_answer_oracle_replay":
        raise SystemExit("v53n answer rows must disclose expected-answer oracle replay")
    if answer["output_provenance_sha256"] != provenance_hash(answer):
        raise SystemExit("v53n output provenance hash mismatch")
    if answer["resource_row_id"] not in resource_by_id:
        raise SystemExit("v53n answer missing resource row")

for citation in citations:
    answer = answer_by_id.get(citation["answer_id"])
    if answer is None:
        raise SystemExit("v53n citation missing answer binding")
    query = queries[answer["query_id"]]
    span = spans[query["source_span_id"]]
    if citation["source_span_id"] != query["source_span_id"]:
        raise SystemExit("v53n citation should bind frozen source span")
    if citation["citation_text"] != span["evidence_text"]:
        raise SystemExit("v53n citation text should match source span")
    if citation["citation_text_sha256"] != sha256_text(citation["citation_text"]):
        raise SystemExit("v53n citation hash mismatch")

for row in resources:
    if row["external_model_used"] != "0" or row["external_network_used"] != "0":
        raise SystemExit("v53n resources should be local/no external model")
    if row["model_name"] != "deterministic-routememory-routehint-source-bound":
        raise SystemExit("v53n resource model name mismatch")
    if row["execution_mode"] != "expected-answer-oracle-replay":
        raise SystemExit("v53n resources must disclose expected-answer oracle replay execution mode")
    if row["actual_adapter_execution_ready"] != "0":
        raise SystemExit("v53n resources must not claim actual adapter execution")
    if row["answer_source"] != "v53i_expected_answer_oracle_replay":
        raise SystemExit("v53n resources must disclose expected-answer oracle replay source")
for row in retrieval:
    query = queries[row["query_id"]]
    if row["source_span_id"] != query["source_span_id"] or row["rank"] != "1":
        raise SystemExit("v53n retrieval should top-rank the frozen source span")
for row in route_memory:
    if row["route_memory_lookup_ready"] != "1" or row["route_jump_rows"] != "0":
        raise SystemExit("v53n route memory readiness mismatch")
for row in routehint:
    if row["raw_prompt_context_bytes"] != "0" or row["route_jump_rows"] != "0":
        raise SystemExit("v53n route hints should avoid raw prompt context and route jumps")
    if row["compact_route_hint_sha256"] != sha256_text(row["compact_route_hint"]):
        raise SystemExit("v53n route hint hash mismatch")
for row in guards:
    if row["strict_expected_answer_match"] != "1" or row["wrong_answer"] != "0" or row["guard_status"] != "pass":
        raise SystemExit("v53n guard rows should pass")

combined_abc_answers = read_csv(run_dir / "source_v53m/supplied_v53j/answer_rows.csv")
combined_abc_citations = read_csv(run_dir / "source_v53m/supplied_v53j/citation_rows.csv")
combined_abc_resources = read_csv(run_dir / "source_v53m/supplied_v53j/resource_rows.csv")
combined_answers = read_csv(run_dir / "supplied_v53j/answer_rows.csv")
combined_citations = read_csv(run_dir / "supplied_v53j/citation_rows.csv")
combined_resources = read_csv(run_dir / "supplied_v53j/resource_rows.csv")
if not rows_match_with_blank_schema_extension(combined_answers, combined_abc_answers + answers):
    raise SystemExit("v53n supplied_v53j answer rows should combine A+B+C+G")
if combined_citations != combined_abc_citations + citations:
    raise SystemExit("v53n supplied_v53j citation rows should combine A+B+C+G")
if not rows_match_with_blank_schema_extension(combined_resources, combined_abc_resources + resources):
    raise SystemExit("v53n supplied_v53j resource rows should combine A+B+C+G")

validation = {row["system_id"]: row for row in read_csv(run_dir / "v53j_partial_supplied_validation_rows.csv")}
for system_id in ["A", "B", "C", "G"]:
    if validation[system_id]["status"] != "valid" or validation[system_id]["valid_answer_rows"] != "1000":
        raise SystemExit(f"v53n should mark {system_id} valid")
for system_id in ["D", "E", "H"]:
    if validation[system_id]["status"] != "missing-or-invalid" or validation[system_id]["missing_valid_answer_rows"] != "1000":
        raise SystemExit(f"v53n should keep {system_id} missing")

metric = read_csv(run_dir / "system_g_metric_rows.csv")[0]
if metric["raw_prompt_context_bytes"] != "0" or metric["symmetric_scorer_policy_rows_ready"] != "0":
    raise SystemExit("v53n metric boundary mismatch")
if metric["expected_answer_oracle_replay"] != "1" or metric["expected_answer_oracle_replay_rows"] != "1000":
    raise SystemExit("v53n metric oracle replay disclosure mismatch")
if metric["actual_adapter_execution_ready"] != "0" or metric["real_system_performance_claim_ready"] != "0":
    raise SystemExit("v53n metric must not claim actual adapter execution or system performance")
if metric["answer_source"] != "v53i_expected_answer_oracle_replay" or metric["execution_mode"] != "expected-answer-oracle-replay":
    raise SystemExit("v53n metric must carry oracle replay source and execution mode")

manifest = json.loads((run_dir / "v53n_complete_source_system_g_routehint_measured_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53n_complete_source_system_g_routehint_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53n manifest readiness boundary mismatch")
if manifest.get("remaining_core_systems") != ["D", "E", "H"]:
    raise SystemExit("v53n manifest remaining core systems mismatch")
if manifest.get("expected_answer_oracle_replay") != 1 or manifest.get("expected_answer_oracle_replay_rows") != 1000:
    raise SystemExit("v53n manifest oracle replay boundary mismatch")
if manifest.get("actual_adapter_execution_ready") != 0 or manifest.get("real_system_performance_claim_ready") != 0:
    raise SystemExit("v53n manifest must not claim actual adapter execution or system performance")
if manifest.get("answer_source") != "v53i_expected_answer_oracle_replay" or manifest.get("execution_mode") != "expected-answer-oracle-replay":
    raise SystemExit("v53n manifest must carry oracle replay source and execution mode")

boundary = (run_dir / "V53N_COMPLETE_SOURCE_SYSTEM_G_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "System G RouteMemory + RouteHint",
    "g_answer_rows=1000",
    "g_raw_prompt_context_bytes=0",
    "combined_abcg_answer_rows=4000",
    "answer_source=v53i_expected_answer_oracle_replay",
    "execution_mode=expected-answer-oracle-replay",
    "expected_answer_oracle_replay=1",
    "actual_adapter_execution_ready=0",
    "real_system_performance_claim_ready=0",
    "remaining_core_systems=D/E/H",
    "Do not publish v53 completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53n boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53n sha256 mismatch: {rel}")
PY

echo "v53n complete-source System G RouteHint measured smoke passed"
