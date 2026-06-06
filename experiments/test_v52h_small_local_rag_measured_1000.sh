#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52h_small_local_rag_measured_1000/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v52h_small_local_rag_measured_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52h_small_local_rag_measured_1000_decision.csv"

V52H_REUSE_EXISTING="${V52H_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52h_small_local_rag_measured_1000.sh" >/dev/null

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


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v52h summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52h_small_local_rag_measured_1000_ready": "1",
    "system_id": "B",
    "baseline_name": "small local RAG",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "parent_query_set_id": "v53e_canary_query_scale_1000",
    "query_rows": "1000",
    "answer_rows": "1000",
    "citation_rows": "1000",
    "abstain_rows": "1000",
    "wrong_answer_guard_rows": "1000",
    "resource_rows": "1000",
    "retrieval_rows": "3000",
    "external_network_used": "0",
    "external_model_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v53e_canary_query_scale_ready": "1",
    "v52_absorb_ready": "1",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52h {field}: expected {value}, got {summary.get(field)}")
if int(summary["source_manifest_rows"]) <= 0:
    raise SystemExit("v52h should emit source manifest rows")
if int(summary["negative_abstain_query_rows"]) <= 0:
    raise SystemExit("v52h should include negative/abstain rows from v53e")
if int(summary["raw_prompt_context_total_bytes"]) <= 0:
    raise SystemExit("v52h should record prompt context bytes")
if int(summary["avg_latency_ns"]) <= 0:
    raise SystemExit("v52h should record measured latency")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "small-local-rag-1000-measured",
    "same-frozen-query-set",
    "source-manifest",
    "negative-abstain-coverage",
    "no-external-model",
    "v52-absorb-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52h gate should pass: {gate}")
for gate in [
    "v52-b-1000",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52h gate should pass: {gate}")
for gate in [
    "a-g-h-same-query-set",
    "c-d-e-evidence-directories",
    "v52-full-baseline-war",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52h gate should remain blocked: {gate}")

required_files = [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "small_local_rag_answer_rows.csv",
    "small_local_rag_citation_rows.csv",
    "small_local_rag_retrieval_rows.csv",
    "small_local_rag_abstain_rows.csv",
    "small_local_rag_wrong_answer_guard_rows.csv",
    "small_local_rag_resource_rows.csv",
    "V52H_SMALL_LOCAL_RAG_1000_BOUNDARY.md",
    "v52h_small_local_rag_measured_1000_manifest.json",
    "sha256_manifest.csv",
    "source_v53e/scaled_canary_query_rows.csv",
    "source_v53e/scaled_canary_source_span_rows.csv",
    "source_v53e/scaled_canary_query_repo_rows.csv",
    "source_v53e/scaled_canary_query_family_rows.csv",
    "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "source_v53e/v53e_canary_query_scale_1000_manifest.json",
    "source_v53e/sha256_manifest.csv",
    "source_v53e/v53e_canary_query_scale_1000_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52h artifact: {rel}")

queries = read_csv(run_dir / "frozen_query_rows.csv")
spans = read_csv(run_dir / "frozen_source_span_rows.csv")
answers = read_csv(run_dir / "small_local_rag_answer_rows.csv")
citations = read_csv(run_dir / "small_local_rag_citation_rows.csv")
retrieval = read_csv(run_dir / "small_local_rag_retrieval_rows.csv")
abstain = read_csv(run_dir / "small_local_rag_abstain_rows.csv")
guards = read_csv(run_dir / "small_local_rag_wrong_answer_guard_rows.csv")
resources = read_csv(run_dir / "small_local_rag_resource_rows.csv")
query_ids = {row["query_id"] for row in queries}
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v52h should contain 1000 frozen query/source span rows")
if {row["query_id"] for row in spans} != query_ids:
    raise SystemExit("v52h frozen spans should cover the frozen query IDs")
family_counts = {}
for row in queries:
    family_counts[row["audit_type"]] = family_counts.get(row["audit_type"], 0) + 1
expected_family_counts = {
    "doc_code_conflict": 140,
    "deprecation_legacy_usage": 140,
    "config_mismatch": 140,
    "api_behavior": 160,
    "docs_truthfulness": 160,
    "examples_tests_alignment": 100,
    "unsupported_claim_abstain": 100,
    "ambiguous_source_abstain": 60,
}
if family_counts != expected_family_counts:
    raise SystemExit(f"v52h should freeze the full v53e 1000-row set, got {family_counts}")
if sum(int(row["negative_or_abstain"]) for row in queries) != 160:
    raise SystemExit("v52h should preserve negative/abstain query rows")
for table_name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("abstain", abstain),
    ("guards", guards),
    ("resources", resources),
]:
    if len(rows) != 1000:
        raise SystemExit(f"v52h {table_name} should contain 1000 rows")
    if {row["query_id"] for row in rows} != query_ids:
        raise SystemExit(f"v52h {table_name} should cover the frozen query IDs")
if len(retrieval) != 3000:
    raise SystemExit("v52h retrieval should contain three rows per query")
for row in answers:
    if row["system_id"] != "B":
        raise SystemExit("v52h answer system_id should be B")
    if row["predicted_answer_sha256"] != sha256_text(row["predicted_answer"]):
        raise SystemExit("v52h predicted answer hash mismatch")
    if int(row["latency_ns"]) <= 0 or int(row["raw_prompt_context_bytes"]) <= 0:
        raise SystemExit("v52h answer rows should carry measured latency/context")
if any(row["external_model_used"] != "0" or row["external_network_used"] != "0" for row in resources):
    raise SystemExit("v52h resource rows should remain local/no external model")
if any(row["wrong_answer"] not in {"0", "1"} or row["guard_status"] not in {"pass", "wrong-answer"} for row in guards):
    raise SystemExit("v52h guard rows should use valid status fields")

manifest = json.loads((run_dir / "v52h_small_local_rag_measured_1000_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52h_small_local_rag_measured_1000_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52h manifest readiness mismatch")
if manifest.get("query_rows") != 1000 or manifest.get("external_model_used") != 0:
    raise SystemExit("v52h manifest should bind 1000 local rows")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52h sha256 mismatch: {rel}")

boundary = (run_dir / "V52H_SMALL_LOCAL_RAG_1000_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "1000-row measured expansion for baseline B",
    "query_rows=1000",
    "negative_abstain_query_rows=",
    "wrong_answer_guard_rows=1000",
    "external_model_used=0",
    "Do not publish 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52h boundary missing {snippet}")
PY

echo "v52h small local RAG measured 1000 smoke passed"
