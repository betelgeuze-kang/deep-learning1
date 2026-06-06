#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52_llm_rag_baseline_war"
RUN_ID="${V52_RUN_ID:-baseline_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v0_3_architecture_preview.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
results = root / "results"
preview_dir = results / "v0_3_architecture_preview"
preview_summary = list(csv.DictReader((results / "v0_3_architecture_preview_summary.csv").open(newline="", encoding="utf-8")))[0]
preview_baselines = list(csv.DictReader((preview_dir / "baseline_metrics.csv").open(newline="", encoding="utf-8")))
preview_by_id = {row["baseline_id"]: row for row in preview_baselines}

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

for rel in [
    "baseline_metrics.csv",
    "routehint_vs_rag.csv",
    "wrong_answer_guard_rows.csv",
    "prediction_lineage.jsonl",
    "compact_route_hint_rows.csv",
    "grounded_generation_rows.csv",
    "citation_spans.jsonl",
    "resource_envelope.json",
    "sha256sums.txt",
]:
    copy(preview_dir / rel, f"source_preview/{rel}")

required_systems = [
    {
        "system_id": "A",
        "system_name": "BM25 / lexical",
        "size_class": "lexical",
        "required_status": "required",
        "adapter_status": "ready-local-preview",
        "measured_baseline_ready": "1",
        "source_row": "v0.3:bm25_lexical",
        "needs_external_model": "0",
        "route_memory_store_used": preview_by_id["bm25_lexical"]["route_memory_store_used"],
        "compact_routehint_used": "0",
        "raw_prompt_context_boundary": "0",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "",
    },
    {
        "system_id": "B",
        "system_name": "small local RAG",
        "size_class": "small-local-rag",
        "required_status": "required",
        "adapter_status": "contract-ready-measurement-missing",
        "measured_baseline_ready": "0",
        "source_row": "v0.3:small_rag_boundary",
        "needs_external_model": "0",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "raw_prompt_context_boundary": "nonzero-or-unbounded",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "small-local-rag-run-missing",
    },
    {
        "system_id": "C",
        "system_name": "7B-14B local model + RAG",
        "size_class": "7b-14b",
        "required_status": "required",
        "adapter_status": "contract-ready-model-run-missing",
        "measured_baseline_ready": "0",
        "source_row": "",
        "needs_external_model": "1",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "raw_prompt_context_boundary": "rag-context",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "7b-14b-local-model-rag-run-missing",
    },
    {
        "system_id": "D",
        "system_name": "30B open-weight LLM + RAG",
        "size_class": "30b",
        "required_status": "required",
        "adapter_status": "contract-ready-model-run-missing",
        "measured_baseline_ready": "0",
        "source_row": "",
        "needs_external_model": "1",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "raw_prompt_context_boundary": "rag-context",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "30b-open-weight-rag-run-missing",
    },
    {
        "system_id": "E",
        "system_name": "70B open-weight LLM + RAG",
        "size_class": "70b",
        "required_status": "required",
        "adapter_status": "contract-ready-model-run-missing",
        "measured_baseline_ready": "0",
        "source_row": "",
        "needs_external_model": "1",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "raw_prompt_context_boundary": "rag-context",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "70b-open-weight-rag-run-missing",
    },
    {
        "system_id": "F",
        "system_name": "100B+ API or hosted model + RAG",
        "size_class": "100b-plus",
        "required_status": "optional-preferred",
        "adapter_status": "deferred-with-reason",
        "measured_baseline_ready": "0",
        "source_row": "",
        "needs_external_model": "1",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "raw_prompt_context_boundary": "rag-context",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "100b-plus-hosted-api-credentials-or-run-missing",
    },
    {
        "system_id": "G",
        "system_name": "RouteMemory + RouteHint",
        "size_class": "route-memory",
        "required_status": "required",
        "adapter_status": "ready-local-preview",
        "measured_baseline_ready": "1",
        "source_row": "v0.3:route_memory_compact_routehint",
        "needs_external_model": "0",
        "route_memory_store_used": "1",
        "compact_routehint_used": "1",
        "raw_prompt_context_boundary": "0",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "",
    },
    {
        "system_id": "H",
        "system_name": "RouteMemory + RouteHint + source-verified scorer + domain policy",
        "size_class": "route-memory-policy",
        "required_status": "required",
        "adapter_status": "ready-local-preview",
        "measured_baseline_ready": "1",
        "source_row": "v0.3:route_memory_scorer_offline_policy",
        "needs_external_model": "0",
        "route_memory_store_used": "1",
        "compact_routehint_used": "1",
        "raw_prompt_context_boundary": "0",
        "citation_verifier_required": "1",
        "abstain_verifier_required": "1",
        "blocking_reason": "",
    },
]
write_csv(run_dir / "baseline_registry.csv", list(required_systems[0].keys()), required_systems)

contract_rows = [
    {
        "artifact": "source_manifest",
        "required_for_all_systems": "1",
        "same_across_required_systems": "1",
        "status": "contract-ready",
        "notes": "all systems must bind to the same source corpus manifest",
    },
    {
        "artifact": "query_set",
        "required_for_all_systems": "1",
        "same_across_required_systems": "1",
        "status": "contract-ready",
        "notes": "all systems must answer the same query IDs before comparison",
    },
    {
        "artifact": "answer_rows",
        "required_for_all_systems": "1",
        "same_across_required_systems": "0",
        "status": "contract-ready",
        "notes": "per-system answers are scored by the shared evaluator",
    },
    {
        "artifact": "citation_rows",
        "required_for_all_systems": "1",
        "same_across_required_systems": "0",
        "status": "contract-ready",
        "notes": "citation verification must be symmetric for LLM+RAG and RouteMemory systems",
    },
    {
        "artifact": "abstain_rows",
        "required_for_all_systems": "1",
        "same_across_required_systems": "0",
        "status": "contract-ready",
        "notes": "unsupported claims must be explicit abstain rows, not hidden failures",
    },
    {
        "artifact": "wrong_answer_guard_rows",
        "required_for_all_systems": "1",
        "same_across_required_systems": "0",
        "status": "contract-ready",
        "notes": "wrong-answer guard is a first-class score axis",
    },
    {
        "artifact": "resource_rows",
        "required_for_all_systems": "1",
        "same_across_required_systems": "0",
        "status": "contract-ready",
        "notes": "latency, memory, storage, cost, and locality are compared separately from answer rate",
    },
]
write_csv(run_dir / "evaluation_contract_rows.csv", list(contract_rows[0].keys()), contract_rows)

adapter_rows = []
for row in required_systems:
    adapter_rows.append(
        {
            "system_id": row["system_id"],
            "adapter_required": "1" if row["required_status"] == "required" else "0",
            "adapter_status": row["adapter_status"],
            "prompt_template_bound": "1" if row["system_id"] in {"A", "G", "H"} else "0",
            "retrieval_backend_bound": "1" if row["system_id"] in {"A", "G", "H"} else "0",
            "model_identity_bound": "1" if row["system_id"] in {"A", "G", "H"} else "0",
            "resource_envelope_bound": "1" if row["system_id"] in {"A", "G", "H"} else "0",
            "deferred_reason": row["blocking_reason"],
        }
    )
write_csv(run_dir / "adapter_contract_rows.csv", list(adapter_rows[0].keys()), adapter_rows)

score_axis_rows = [
    ("answer_correctness", "required", "raw answer match or task-specific evaluator output"),
    ("citation_correctness", "required", "answer support must cite admissible source spans"),
    ("unsupported_claim_abstention", "required", "missing or unsupported facts should abstain"),
    ("wrong_answer_guard", "required", "known false/negative cases must be blocked"),
    ("source_lineage", "required", "source/query/answer/provenance rows hash-bound"),
    ("replayability", "required", "one command or run manifest should reproduce the public subset"),
    ("resource_envelope", "required", "latency/memory/storage/cost/locality reported"),
    ("privacy_locality_boundary", "required", "local versus hosted/API boundary explicit"),
]
write_csv(
    run_dir / "score_axis_rows.csv",
    ["score_axis", "required_status", "notes"],
    [{"score_axis": axis, "required_status": status, "notes": notes} for axis, status, notes in score_axis_rows],
)

required_ready = [row for row in required_systems if row["required_status"] == "required" and row["measured_baseline_ready"] == "1"]
required_missing = [row for row in required_systems if row["required_status"] == "required" and row["measured_baseline_ready"] != "1"]
real_30b_ready = int(any(row["system_id"] == "D" and row["measured_baseline_ready"] == "1" for row in required_systems))
real_70b_ready = int(any(row["system_id"] == "E" and row["measured_baseline_ready"] == "1" for row in required_systems))
optional_100b_status = next(row["adapter_status"] for row in required_systems if row["system_id"] == "F")
routehint_no_raw_prompt_stuffing = int(preview_summary.get("raw_prompt_context_bytes") == "0")

summary = {
    "v52_baseline_war_contract_ready": 1,
    "v52_ready": 0,
    "baseline_system_rows": len(required_systems),
    "required_system_rows": sum(1 for row in required_systems if row["required_status"] == "required"),
    "required_measured_ready_rows": len(required_ready),
    "required_missing_rows": len(required_missing),
    "required_30b_baseline_ready": real_30b_ready,
    "required_70b_baseline_ready": real_70b_ready,
    "optional_100b_plus_baseline_status": optional_100b_status,
    "same_query_set_all_required_systems": 1,
    "same_source_manifest_all_required_systems": 1,
    "symmetric_citation_contract_ready": 1,
    "routehint_no_raw_prompt_stuffing": routehint_no_raw_prompt_stuffing,
    "score_axis_rows": len(score_axis_rows),
    "release_ready_claim": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v52-baseline-war-contract", "pass", "A-H registry, adapter contracts, score axes, and comparison artifacts are emitted"),
    ("same-query-source-contract", "pass", "same query/source manifest requirement is explicit for all required systems"),
    ("symmetric-citation-contract", "pass", "citation/abstain/wrong-answer/resource axes apply to all systems"),
    ("routehint-no-raw-prompt-stuffing", "pass" if routehint_no_raw_prompt_stuffing else "blocked", "v0.3 preview raw_prompt_context_bytes=0"),
    ("30b-llm-rag-real-row", "blocked", "30B open-weight LLM+RAG run is not supplied"),
    ("70b-llm-rag-real-row", "blocked", "70B open-weight LLM+RAG run is not supplied"),
    ("100b-plus-llm-rag-real-row", "blocked", "100B+ hosted/API row is deferred with reason"),
    ("v52-full-baseline-war", "blocked", "full v52 requires real C/D/E rows and preferably F"),
    ("real-release-package", "blocked", "v52 contract is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

claim_boundary = run_dir / "V52_BASELINE_WAR_BOUNDARY.md"
claim_boundary.write_text(
    "# v52 Baseline War Boundary\n\n"
    "This is a v1.0 Architecture Challenge baseline-war contract scaffold, not the completed 30B/70B/100B+ comparison.\n\n"
    "Ready now:\n\n"
    "- A-H baseline registry\n"
    "- shared source/query/evaluator artifact contract\n"
    "- symmetric citation, abstain, wrong-answer guard, resource, and privacy/locality axes\n"
    "- local preview evidence for A, G, and H\n\n"
    "Still blocked:\n\n"
    "- B measured small-local-RAG row\n"
    "- C measured 7B-14B local model + RAG row\n"
    "- D measured 30B open-weight LLM + RAG row\n"
    "- E measured 70B open-weight LLM + RAG row\n"
    "- F measured 100B+ hosted/API + RAG row, if available\n\n"
    "Do not publish v52 performance claims until D and E are real rows and citation verification is symmetric.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52-llm-rag-baseline-war-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52_baseline_war_contract_ready": 1,
    "v52_ready": 0,
    "baseline_system_rows": len(required_systems),
    "required_30b_baseline_ready": real_30b_ready,
    "required_70b_baseline_ready": real_70b_ready,
    "optional_100b_plus_baseline_status": optional_100b_status,
    "source_preview_sha256": sha256(run_dir / "source_preview" / "baseline_metrics.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v52_llm_rag_baseline_war_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "baseline_registry.csv",
    "evaluation_contract_rows.csv",
    "adapter_contract_rows.csv",
    "score_axis_rows.csv",
    "V52_BASELINE_WAR_BOUNDARY.md",
    "v52_llm_rag_baseline_war_manifest.json",
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
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52_llm_rag_baseline_war_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
