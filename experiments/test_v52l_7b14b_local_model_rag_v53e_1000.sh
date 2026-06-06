#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52l_7b14b_local_model_rag_v53e_1000/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v52l_7b14b_local_model_rag_v53e_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52l_7b14b_local_model_rag_v53e_1000_decision.csv"

V52L_REUSE_EXISTING="${V52L_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52l_7b14b_local_model_rag_v53e_1000.sh" >/dev/null

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


summary = read_csv(summary_csv)[0]
expected = {
    "v52l_7b14b_local_model_rag_v53e_1000_ready": "1",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "system_id": "C",
    "model_id": "qwen2.5:7b-instruct",
    "query_rows": "1000",
    "answer_rows": "1000",
    "citation_rows": "1000",
    "citation_correct_rows": "1000",
    "citation_accuracy": "1.000000",
    "retrieval_rows": "1000",
    "abstain_rows": "1000",
    "negative_abstain_query_rows": "160",
    "wrong_answer_guard_rows": "1000",
    "resource_rows": "1000",
    "transcript_rows": "1000",
    "same_query_set_as_v52i_abgh": "1",
    "same_source_manifest_as_v52i_abgh": "1",
    "external_network_used": "0",
    "external_model_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "c_v53e_absorb_ready": "1",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52l {field}: expected {value}, got {summary.get(field)}")
if not (0 <= int(summary["correct_rows"]) <= 1000):
    raise SystemExit("v52l correct_rows should be bounded")
float(summary["accuracy"])

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "c-v53e-1000-local-model-rag",
    "same-frozen-query-set-as-abgh",
    "same-source-manifest-as-abgh",
    "ollama-local-model-generation",
    "no-external-network",
    "v52-c-absorb-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52l gate should pass: {gate}")
for gate in ["required-30b-70b-baselines", "v52-full-baseline-war", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52l gate should remain blocked: {gate}")

required_files = [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "model_identity.json",
    "c_answer_rows.csv",
    "c_citation_rows.csv",
    "c_retrieval_rows.csv",
    "c_abstain_rows.csv",
    "c_wrong_answer_guard_rows.csv",
    "c_resource_rows.csv",
    "ollama_generation_transcript_rows.csv",
    "c_system_metric_rows.csv",
    "V52L_7B14B_LOCAL_MODEL_RAG_V53E_BOUNDARY.md",
    "v52l_7b14b_local_model_rag_v53e_1000_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52l artifact: {rel}")

for rel, expected_rows in [
    ("c_answer_rows.csv", 1000),
    ("c_citation_rows.csv", 1000),
    ("c_retrieval_rows.csv", 1000),
    ("c_abstain_rows.csv", 1000),
    ("c_wrong_answer_guard_rows.csv", 1000),
    ("c_resource_rows.csv", 1000),
    ("ollama_generation_transcript_rows.csv", 1000),
]:
    rows = read_csv(run_dir / rel)
    if len(rows) != expected_rows:
        raise SystemExit(f"v52l {rel}: expected {expected_rows} rows, got {len(rows)}")

identity = json.loads((run_dir / "model_identity.json").read_text(encoding="utf-8"))
if identity.get("system_id") != "C" or identity.get("model_id") != "qwen2.5:7b-instruct":
    raise SystemExit("v52l identity should bind system C to qwen2.5:7b-instruct")
if float(identity.get("parameter_count_b")) != 7.0 or identity.get("external_network_used") != 0:
    raise SystemExit("v52l identity should be local 7B/no-network")

answers = read_csv(run_dir / "c_answer_rows.csv")
if {row["system_id"] for row in answers} != {"C"}:
    raise SystemExit("v52l answer rows should all be system C")
if any(not row["predicted_answer_sha256"].startswith("sha256:") for row in answers):
    raise SystemExit("v52l answer rows should hash predictions")

resources = read_csv(run_dir / "c_resource_rows.csv")
if {row["external_network_used"] for row in resources} != {"0"}:
    raise SystemExit("v52l resource rows should be local/no-network")

manifest = json.loads((run_dir / "v52l_7b14b_local_model_rag_v53e_1000_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52l_7b14b_local_model_rag_v53e_1000_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52l manifest readiness mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52l sha256 mismatch: {rel}")

boundary = (run_dir / "V52L_7B14B_LOCAL_MODEL_RAG_V53E_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real local Ollama baseline-C measured packet",
    "full frozen v53e 1000-query canary set",
    "same_query_set_as_v52i_abgh=1",
    "D/E 30B/70B real evidence directories",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52l boundary missing {snippet}")
PY

echo "v52l 7B-14B local model RAG v53e 1000 smoke passed"
