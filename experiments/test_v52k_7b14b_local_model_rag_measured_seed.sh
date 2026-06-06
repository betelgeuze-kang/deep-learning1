#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52k_7b14b_local_model_rag_measured_seed/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v52k_7b14b_local_model_rag_measured_seed_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52k_7b14b_local_model_rag_measured_seed_decision.csv"

"$ROOT_DIR/experiments/run_v52k_7b14b_local_model_rag_measured_seed.sh" >/dev/null

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
    raise SystemExit(f"expected one v52k summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52k_7b14b_local_model_rag_measured_seed_ready": "1",
    "system_id": "C",
    "model_id": "qwen2.5:7b-instruct",
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
    "v52c_absorb_ready": "1",
    "v52_ready": "0",
    "same_query_set_as_abgh_v52i": "0",
    "real_30b_70b_rows_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52k {field}: expected {value}, got {summary.get(field)}")
if not (0 <= int(summary["correct_rows"]) <= 9):
    raise SystemExit("v52k correct row count should be bounded")
float(summary["accuracy"])

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "ollama-local-model-present",
    "c-local-model-generation",
    "c-evidence-directory",
    "v52c-supplied-evidence-validation",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52k gate should pass: {gate}")
for gate in ["v52-full-c-baseline-scale", "30b-70b-real-rows", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52k gate should remain blocked: {gate}")

required_files = [
    "c_local_model_rag_evidence/model_identity.json",
    "c_local_model_rag_evidence/local_model_rag_answer_rows.csv",
    "c_local_model_rag_evidence/local_model_rag_citation_rows.csv",
    "c_local_model_rag_evidence/local_model_rag_resource_rows.csv",
    "ollama_generation_transcript_rows.csv",
    "source_v52c_validated/v52c_7b14b_local_model_rag_evidence_intake_summary.csv",
    "source_v52c_validated/v52c_7b14b_local_model_rag_evidence_intake_decision.csv",
    "source_v52c_validated/supplied_evidence/model_identity.json",
    "source_v52c_validated/supplied_evidence/local_model_rag_answer_rows.csv",
    "source_v52c_validated/supplied_evidence/local_model_rag_citation_rows.csv",
    "source_v52c_validated/supplied_evidence/local_model_rag_resource_rows.csv",
    "source_v52c_validated/sha256_manifest.csv",
    "v52k_decision_rows.csv",
    "V52K_7B14B_LOCAL_MODEL_RAG_MEASURED_SEED_BOUNDARY.md",
    "v52k_7b14b_local_model_rag_measured_seed_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52k artifact: {rel}")

identity = json.loads((run_dir / "c_local_model_rag_evidence" / "model_identity.json").read_text(encoding="utf-8"))
if identity.get("system_id") != "C" or identity.get("model_id") != "qwen2.5:7b-instruct":
    raise SystemExit("v52k identity should bind system C to qwen2.5:7b-instruct")
if float(identity.get("parameter_count_b")) != 7.0 or identity.get("external_network_used") != 0:
    raise SystemExit("v52k identity should be local 7B/no-network")
if not str(identity.get("model_artifact_sha256", "")).startswith("sha256:"):
    raise SystemExit("v52k identity should bind model artifact sha")

answers = read_csv(run_dir / "c_local_model_rag_evidence" / "local_model_rag_answer_rows.csv")
if len(answers) != 9 or {row["system_id"] for row in answers} != {"C"}:
    raise SystemExit("v52k should write nine C answer rows")
if {row["route_memory_store_used"] for row in answers} != {"0"} or {row["compact_routehint_used"] for row in answers} != {"0"}:
    raise SystemExit("v52k C rows must not use RouteMemory/RouteHint")
if any(not row["output_sha256"].startswith("sha256:") for row in answers):
    raise SystemExit("v52k answer rows should hash outputs")

citations = read_csv(run_dir / "c_local_model_rag_evidence" / "local_model_rag_citation_rows.csv")
if len(citations) != 18 or {row["citation_correct"] for row in citations} != {"1"}:
    raise SystemExit("v52k should write 18 source-span-bound citation rows")

resources = read_csv(run_dir / "c_local_model_rag_evidence" / "local_model_rag_resource_rows.csv")
if len(resources) != 9 or {row["external_network_used"] for row in resources} != {"0"}:
    raise SystemExit("v52k resource rows should be local/no-network")

v52c_summary = read_csv(run_dir / "source_v52c_validated" / "v52c_7b14b_local_model_rag_evidence_intake_summary.csv")[0]
if v52c_summary.get("supplied_evidence_ready") != "1" or v52c_summary.get("v52_absorb_ready") != "1":
    raise SystemExit("v52k should carry validated v52c supplied evidence")

manifest = json.loads((run_dir / "v52k_7b14b_local_model_rag_measured_seed_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52k_7b14b_local_model_rag_measured_seed_ready") != 1:
    raise SystemExit("v52k manifest readiness mismatch")
if manifest.get("v52c_supplied_evidence_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52k manifest should keep full v52 blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52k sha256 mismatch: {rel}")

boundary = (run_dir / "V52K_7B14B_LOCAL_MODEL_RAG_MEASURED_SEED_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real local Ollama baseline-C measured seed",
    "not the completed v52 baseline war",
    "query_rows=9",
    "v52c_supplied_evidence_ready=1",
    "D/E 30B/70B real evidence directories",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52k boundary missing {snippet}")
PY

echo "v52k 7B-14B local model RAG measured seed smoke passed"
