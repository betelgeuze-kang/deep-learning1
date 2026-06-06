#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52b_small_local_rag_measured_row/row_001"
SUMMARY_CSV="$RESULTS_DIR/v52b_small_local_rag_measured_row_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52b_small_local_rag_measured_row_decision.csv"

"$ROOT_DIR/experiments/run_v52b_small_local_rag_measured_row.sh" >/dev/null

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
    raise SystemExit(f"expected one v52b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52b_small_local_rag_measured_row_ready": "1",
    "system_id": "B",
    "baseline_name": "small local RAG",
    "query_rows": "9",
    "answer_rows": "9",
    "correct_rows": "9",
    "accuracy": "1.000000",
    "citation_rows": "18",
    "citation_correct_rows": "18",
    "citation_accuracy": "1.000000",
    "raw_prompt_context_rows": "9",
    "retrieved_span_rows": "18",
    "external_network_used": "0",
    "external_model_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v50_seed_query_rows": "9",
    "v52_absorb_ready": "1",
    "v52_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52b {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("raw_prompt_context_total_bytes", "0")) <= 0:
    raise SystemExit("v52b should record nonzero raw prompt context bytes")
if int(summary.get("avg_latency_ns", "0")) <= 0:
    raise SystemExit("v52b should record positive measured latency")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "small-local-rag-measured-row",
    "public-repo-seed",
    "raw-prompt-context-boundary",
    "external-model-boundary",
    "v52-absorb-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52b gate should pass: {gate}")
for gate in ["30b-llm-rag-real-row", "70b-llm-rag-real-row", "v52-full-baseline-war", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52b gate should remain blocked: {gate}")

required_files = [
    "small_local_rag_answer_rows.csv",
    "small_local_rag_citation_rows.csv",
    "small_local_rag_retrieval_rows.csv",
    "small_local_rag_resource_rows.csv",
    "V52B_SMALL_LOCAL_RAG_BOUNDARY.md",
    "v52b_small_local_rag_manifest.json",
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
        raise SystemExit(f"missing v52b artifact: {rel}")

answers = read_csv(run_dir / "small_local_rag_answer_rows.csv")
if len(answers) != 9:
    raise SystemExit("v52b should write nine answer rows")
if any(row["system_id"] != "B" for row in answers):
    raise SystemExit("v52b answer rows should all be system B")
if any(row["correct"] != "1" for row in answers):
    raise SystemExit("v52b seed answers should match the v50 expected labels")
if any(int(row["raw_prompt_context_bytes"]) <= 0 for row in answers):
    raise SystemExit("v52b every answer should carry retrieved prompt context bytes")

citations = read_csv(run_dir / "small_local_rag_citation_rows.csv")
if len(citations) != 18 or any(row["citation_correct"] != "1" for row in citations):
    raise SystemExit("v52b citations should bind two correct spans per query")

resources = read_csv(run_dir / "small_local_rag_resource_rows.csv")
if len(resources) != 9:
    raise SystemExit("v52b should write nine resource rows")
for row in resources:
    if row["external_network_used"] != "0" or row["external_model_used"] != "0":
        raise SystemExit("v52b should stay local and model-free")
    if int(row["latency_ns"]) <= 0 or int(row["raw_prompt_context_bytes"]) <= 0:
        raise SystemExit("v52b resource rows should record positive latency/context")

manifest = json.loads((run_dir / "v52b_small_local_rag_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52b_small_local_rag_measured_row_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52b manifest readiness boundary mismatch")
if manifest.get("system_id") != "B" or manifest.get("external_model_used") != 0:
    raise SystemExit("v52b manifest should identify local system B")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52b sha256 mismatch: {rel}")

boundary = (run_dir / "V52B_SMALL_LOCAL_RAG_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "measured seed row for baseline B",
    "external_model_used=0",
    "route_memory_store_used=0",
    "C 7B-14B local model + RAG row",
    "Do not publish 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52b boundary missing {snippet}")
PY

echo "v52b small local RAG measured row smoke passed"
