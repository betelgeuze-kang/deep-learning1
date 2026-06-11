#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52n_30b_open_weight_llm_rag_measured_seed/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v52n_30b_open_weight_llm_rag_measured_seed_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52n_30b_open_weight_llm_rag_measured_seed_decision.csv"

V52N_REUSE_EXISTING="${V52N_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52n_30b_open_weight_llm_rag_measured_seed.sh" >/dev/null

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
    raise SystemExit(f"expected one v52n summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52n_30b_open_weight_llm_rag_measured_seed_ready": "1",
    "system_id": "D",
    "model_id": "qwen2.5:32b-instruct",
    "runner": "ollama",
    "query_set_id": "v50_public_repo_auditor_3repo_seed",
    "query_rows": "9",
    "answer_rows": "9",
    "citation_rows": "18",
    "citation_correct_rows": "18",
    "citation_accuracy": "1.000000",
    "resource_rows": "9",
    "raw_prompt_context_rows": "9",
    "external_network_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "model_identity_ready": "1",
    "model_size_class_ready": "1",
    "supplied_evidence_ready": "1",
    "v52d_absorb_ready": "1",
    "v52_ready": "0",
    "same_query_set_as_abgh_v52i": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52n {field}: expected {value}, got {summary.get(field)}")
if not (0 <= int(summary["correct_rows"]) <= 9):
    raise SystemExit("v52n correct row count should be bounded")
float(summary["accuracy"])

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "ollama-open-weight-model-present",
    "d-open-weight-generation",
    "d-evidence-directory",
    "v52d-supplied-evidence-validation",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52n gate should pass: {gate}")
for gate in ["v52-full-d-baseline-scale", "70b-real-row", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52n gate should remain blocked: {gate}")

required_files = [
    "d_llm_rag_evidence/model_identity.json",
    "d_llm_rag_evidence/llm_rag_answer_rows.csv",
    "d_llm_rag_evidence/llm_rag_citation_rows.csv",
    "d_llm_rag_evidence/llm_rag_resource_rows.csv",
    "ollama_generation_transcript_rows.csv",
    "source_v52d_validated/v52d_30b70b_llm_rag_evidence_intake_summary.csv",
    "source_v52d_validated/v52d_30b70b_llm_rag_evidence_intake_decision.csv",
    "source_v52d_validated/supplied_evidence/D/model_identity.json",
    "source_v52d_validated/supplied_evidence/D/llm_rag_answer_rows.csv",
    "source_v52d_validated/supplied_evidence/D/llm_rag_citation_rows.csv",
    "source_v52d_validated/supplied_evidence/D/llm_rag_resource_rows.csv",
    "source_v52d_validated/sha256_manifest.csv",
    "v52n_decision_rows.csv",
    "V52N_30B_OPEN_WEIGHT_LLM_RAG_MEASURED_SEED_BOUNDARY.md",
    "v52n_30b_open_weight_llm_rag_measured_seed_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52n artifact: {rel}")

identity = json.loads((run_dir / "d_llm_rag_evidence" / "model_identity.json").read_text(encoding="utf-8"))
if identity.get("system_id") != "D" or identity.get("model_id") != "qwen2.5:32b-instruct":
    raise SystemExit("v52n identity should bind system D to qwen2.5:32b-instruct")
if float(identity.get("parameter_count_b")) != 32.0 or identity.get("external_network_used") != 0:
    raise SystemExit("v52n identity should be local 32B/no-network")
if not str(identity.get("model_artifact_sha256", "")).startswith("sha256:"):
    raise SystemExit("v52n identity should bind model artifact sha")

answers = read_csv(run_dir / "d_llm_rag_evidence" / "llm_rag_answer_rows.csv")
if len(answers) != 9 or {row["system_id"] for row in answers} != {"D"}:
    raise SystemExit("v52n should write nine D answer rows")
if {row["route_memory_store_used"] for row in answers} != {"0"} or {row["compact_routehint_used"] for row in answers} != {"0"}:
    raise SystemExit("v52n D rows must not use RouteMemory/RouteHint")
if any(not row["output_sha256"].startswith("sha256:") for row in answers):
    raise SystemExit("v52n answer rows should hash outputs")

citations = read_csv(run_dir / "d_llm_rag_evidence" / "llm_rag_citation_rows.csv")
if len(citations) != 18 or {row["citation_correct"] for row in citations} != {"1"}:
    raise SystemExit("v52n should write 18 source-span-bound citation rows")

resources = read_csv(run_dir / "d_llm_rag_evidence" / "llm_rag_resource_rows.csv")
if len(resources) != 9 or {row["external_network_used"] for row in resources} != {"0"}:
    raise SystemExit("v52n resource rows should be local/no-network")

v52d_summary = read_csv(run_dir / "source_v52d_validated" / "v52d_30b70b_llm_rag_evidence_intake_summary.csv")[0]
if v52d_summary.get("d_30b_supplied_evidence_ready") != "1" or v52d_summary.get("v52_absorb_ready") != "1":
    raise SystemExit("v52n should carry validated v52d supplied evidence")

manifest = json.loads((run_dir / "v52n_30b_open_weight_llm_rag_measured_seed_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52n_30b_open_weight_llm_rag_measured_seed_ready") != 1:
    raise SystemExit("v52n manifest readiness mismatch")
if manifest.get("d_30b_supplied_evidence_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52n manifest should keep full v52 blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52n sha256 mismatch: {rel}")

boundary = (run_dir / "V52N_30B_OPEN_WEIGHT_LLM_RAG_MEASURED_SEED_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real local Ollama baseline-D measured seed",
    "not the completed v52 baseline war",
    "query_rows=9",
    "d_30b_supplied_evidence_ready=1",
    "E 70B real evidence directory",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52n boundary missing {snippet}")
PY

echo "v52n 30B open-weight LLM+RAG measured seed smoke passed"
