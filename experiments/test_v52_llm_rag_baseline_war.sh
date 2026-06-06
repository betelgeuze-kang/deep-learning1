#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52_llm_rag_baseline_war/baseline_001"
SUMMARY_CSV="$RESULTS_DIR/v52_llm_rag_baseline_war_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52_llm_rag_baseline_war_decision.csv"

"$ROOT_DIR/experiments/run_v52_llm_rag_baseline_war.sh" >/dev/null

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
    raise SystemExit(f"expected one v52 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52_baseline_war_contract_ready": "1",
    "v52_ready": "0",
    "baseline_system_rows": "8",
    "required_system_rows": "7",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "optional_100b_plus_baseline_status": "deferred-with-reason",
    "same_query_set_all_required_systems": "1",
    "same_source_manifest_all_required_systems": "1",
    "symmetric_citation_contract_ready": "1",
    "routehint_no_raw_prompt_stuffing": "1",
    "score_axis_rows": "8",
    "release_ready_claim": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("required_missing_rows", "0")) < 4:
    raise SystemExit("v52 should keep missing required LLM+RAG rows explicit")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52-baseline-war-contract",
    "same-query-source-contract",
    "symmetric-citation-contract",
    "routehint-no-raw-prompt-stuffing",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52 gate should pass: {gate}")
for gate in [
    "30b-llm-rag-real-row",
    "70b-llm-rag-real-row",
    "100b-plus-llm-rag-real-row",
    "v52-full-baseline-war",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52 gate should remain blocked: {gate}")

required_files = [
    "baseline_registry.csv",
    "evaluation_contract_rows.csv",
    "adapter_contract_rows.csv",
    "score_axis_rows.csv",
    "V52_BASELINE_WAR_BOUNDARY.md",
    "v52_llm_rag_baseline_war_manifest.json",
    "sha256_manifest.csv",
    "source_preview/baseline_metrics.csv",
    "source_preview/routehint_vs_rag.csv",
    "source_preview/wrong_answer_guard_rows.csv",
    "source_preview/prediction_lineage.jsonl",
    "source_preview/compact_route_hint_rows.csv",
    "source_preview/grounded_generation_rows.csv",
    "source_preview/citation_spans.jsonl",
    "source_preview/resource_envelope.json",
    "source_preview/sha256sums.txt",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52 artifact: {rel}")

registry = read_csv(run_dir / "baseline_registry.csv")
if {row["system_id"] for row in registry} != set("ABCDEFGH"):
    raise SystemExit("v52 registry must cover A-H")
by_id = {row["system_id"]: row for row in registry}
for system_id in ["D", "E"]:
    row = by_id[system_id]
    if row["measured_baseline_ready"] != "0" or "missing" not in row["blocking_reason"]:
        raise SystemExit(f"v52 {system_id} should stay blocked until a real LLM+RAG row exists")
if by_id["F"]["adapter_status"] != "deferred-with-reason":
    raise SystemExit("v52 100B+ row should be explicitly deferred with reason")
for system_id in ["G", "H"]:
    row = by_id[system_id]
    if row["route_memory_store_used"] != "1" or row["compact_routehint_used"] != "1" or row["raw_prompt_context_boundary"] != "0":
        raise SystemExit(f"v52 RouteMemory system missing RouteHint/no-raw-context controls: {system_id}")
if by_id["B"]["raw_prompt_context_boundary"] != "nonzero-or-unbounded":
    raise SystemExit("v52 small RAG boundary should remain explicit")

contracts = read_csv(run_dir / "evaluation_contract_rows.csv")
contract_artifacts = {row["artifact"] for row in contracts}
for artifact in ["source_manifest", "query_set", "answer_rows", "citation_rows", "abstain_rows", "wrong_answer_guard_rows", "resource_rows"]:
    if artifact not in contract_artifacts:
        raise SystemExit(f"v52 evaluation contract missing {artifact}")
if any(row["status"] != "contract-ready" for row in contracts):
    raise SystemExit("v52 evaluation contract rows should be contract-ready")

score_axes = {row["score_axis"] for row in read_csv(run_dir / "score_axis_rows.csv")}
for axis in ["answer_correctness", "citation_correctness", "unsupported_claim_abstention", "wrong_answer_guard", "source_lineage", "replayability", "resource_envelope", "privacy_locality_boundary"]:
    if axis not in score_axes:
        raise SystemExit(f"v52 score axis missing {axis}")

manifest = json.loads((run_dir / "v52_llm_rag_baseline_war_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52_baseline_war_contract_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52 manifest readiness boundary mismatch")
if manifest.get("required_30b_baseline_ready") != 0 or manifest.get("required_70b_baseline_ready") != 0:
    raise SystemExit("v52 manifest should not pretend 30B/70B rows exist")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52 sha256 mismatch: {rel}")

boundary = (run_dir / "V52_BASELINE_WAR_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed 30B/70B/100B+ comparison",
    "30B open-weight LLM + RAG row",
    "70B open-weight LLM + RAG row",
    "Do not publish v52 performance claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52 boundary missing {snippet}")
PY

echo "v52 LLM+RAG baseline war contract smoke passed"
