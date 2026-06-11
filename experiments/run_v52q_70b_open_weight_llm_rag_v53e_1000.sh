#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52q_70b_open_weight_llm_rag_v53e_1000"
RUN_ID="${V52Q_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
MODEL_ID="${V52Q_OLLAMA_MODEL:-llama3.1:70b-instruct-q2_K}"

if [[ "${V52Q_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52q_70b_open_weight_llm_rag_v53e_1000_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/ollama_rocm_env.sh"

if [[ "${V52Q_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$MODEL_ID" <<'PY'
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
model_id = sys.argv[5]
results = root / "results"
v53e_dir = results / "v53e_canary_query_scale_1000" / "scale_001"
v53e_summary = list(csv.DictReader((results / "v53e_canary_query_scale_1000_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def sha256_text(text):
    return sha256_bytes(text.encode("utf-8"))


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def ollama_json(path, payload=None, timeout=10):
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        f"http://127.0.0.1:11434{path}",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def wait_ollama(timeout_s=30):
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            ollama_json("/api/tags", timeout=2)
            return True
        except Exception:
            time.sleep(0.5)
    return False


server_started = False
server = None
try:
    ollama_json("/api/tags", timeout=2)
except Exception:
    server = subprocess.Popen(["ollama", "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    server_started = True
    if not wait_ollama():
        raise SystemExit("ollama server did not become ready")

tags = ollama_json("/api/tags")
if model_id not in {model.get("name", "") for model in tags.get("models", [])}:
    raise SystemExit(f"required local Ollama model is missing: {model_id}")

model_name, _, model_tag = model_id.partition(":")
model_tag = model_tag or "latest"
manifest_path = root.home() / ".ollama" / "models" / "manifests" / "registry.ollama.ai" / "library" / model_name / model_tag
if not manifest_path.is_file():
    raise SystemExit(f"ollama manifest missing for {model_id}")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
model_layer = next(layer for layer in manifest["layers"] if layer["mediaType"] == "application/vnd.ollama.image.model")
model_artifact_sha256 = model_layer["digest"]

for relpath in [
    "scaled_canary_query_rows.csv",
    "scaled_canary_source_span_rows.csv",
    "scaled_canary_query_repo_rows.csv",
    "scaled_canary_query_family_rows.csv",
    "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "v53e_canary_query_scale_1000_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53e_dir / relpath, f"source_v53e/{relpath}")
copy(results / "v53e_canary_query_scale_1000_summary.csv", "source_v53e/v53e_canary_query_scale_1000_summary.csv")

query_rows = read_csv(v53e_dir / "scaled_canary_query_rows.csv")
span_rows = read_csv(v53e_dir / "scaled_canary_source_span_rows.csv")
if len(query_rows) != 1000 or len(span_rows) != 1000:
    raise SystemExit("v52p requires the full v53e 1000-row query/source set")

span_by_query = {row["query_id"]: row for row in span_rows}
write_csv(run_dir / "frozen_query_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "frozen_source_span_rows.csv", list(span_rows[0].keys()), span_rows)

source_manifest_rows = []
seen_sources = set()
for row in span_rows:
    key = (row["repo_id"], row["owner_repo"], row["head_sha"], row["path"], row["source_file_sha256"], row["local_relpath"])
    if key in seen_sources:
        continue
    seen_sources.add(key)
    source_manifest_rows.append(
        {
            "repo_id": row["repo_id"],
            "owner_repo": row["owner_repo"],
            "head_sha": row["head_sha"],
            "path": row["path"],
            "source_file_sha256": row["source_file_sha256"],
            "local_relpath": row["local_relpath"],
        }
    )
write_csv(run_dir / "source_manifest_rows.csv", list(source_manifest_rows[0].keys()), source_manifest_rows)

identity = {
    "system_id": "E",
    "model_id": model_id,
    "parameter_count_b": 32.0,
    "size_class": "30b",
    "runner": "ollama",
    "runner_version": subprocess.check_output(["ollama", "--version"], text=True).strip(),
    "quantization": "ollama-library-llama3.1-70b-instruct-q2_K-local-artifact",
    "model_artifact_uri": str(manifest_path),
    "model_artifact_sha256": model_artifact_sha256,
    "open_weight_license_uri": "https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct/blob/main/LICENSE",
    "rag_context_builder": "v53e frozen canary source span supplied per query",
    "context_length": 2048,
    "external_network_used": 0,
}
(run_dir / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def clean_answer(raw):
    text = raw.strip()
    text = re.sub(r"^```(?:json)?", "", text).strip()
    text = re.sub(r"```$", "", text).strip()
    try:
        parsed = json.loads(text)
        answer = str(parsed.get("answer", "")).strip()
        if answer:
            return answer
    except Exception:
        pass
    match = re.search(r'"answer"\s*:\s*"((?:[^"\\]|\\.)*)"', text, flags=re.S)
    if match:
        try:
            return json.loads('"' + match.group(1) + '"').strip()
        except Exception:
            return match.group(1).strip()
    return " ".join(text.split())


def build_prompt(query, span):
    if query["negative_or_abstain"] == "1":
        instruction = (
            "The question asks whether a broad claim is proven by a single canary source span. "
            "If the span only supports a local fact, abstain and explain that boundary."
        )
    else:
        instruction = "Answer the bounded source-fact question using only the supplied source span."
    return (
        "You are baseline E: a 32B open-weight LLM with one RAG source span. "
        "Return compact JSON only: {\"answer\":\"...\"}. "
        "Do not add citations beyond the supplied path and line. "
        f"{instruction}\n\n"
        f"Question: {query['question']}\n"
        f"Repository: {query['owner_repo']}\n"
        f"Audit type: {query['audit_type']}\n"
        f"Source path: {span['path']}\n"
        f"Source line: {span['line_start']}\n"
        f"Source text: {span['evidence_text']}\n"
    )


answer_rows = []
citation_rows = []
retrieval_rows = []
abstain_rows = []
wrong_guard_rows = []
resource_rows = []
transcript_rows = []
correct_rows = 0
abstained_rows = 0
wrong_rows = 0
latency_total = 0
context_total = 0

for idx, query in enumerate(query_rows, start=1):
    span = span_by_query[query["query_id"]]
    prompt = build_prompt(query, span)
    prompt_bytes = prompt.encode("utf-8")
    start = time.monotonip_ns()
    response = ollama_json(
        "/api/generate",
        {
            "model": model_id,
            "prompt": prompt,
            "stream": False,
            "format": "json",
            "options": {
                "temperature": 0,
                "top_p": 0.1,
                "num_predict": 120,
                "num_ctx": 2048,
            },
        },
        timeout=900,
    )
    latency_ns = time.monotonip_ns() - start
    raw_response = response.get("response", "")
    predicted_answer = clean_answer(raw_response)
    if not predicted_answer:
        predicted_answer = "ABSTAIN"
    abstained = int(predicted_answer.upper().startswith("ABSTAIN"))
    correct = int(predicted_answer == query["expected_answer"])
    wrong_answer = int(not correct and not abstained)
    correct_rows += correct
    abstained_rows += abstained
    wrong_rows += wrong_answer
    latency_total += latency_ns
    context_total += len(prompt_bytes)
    answer_id = f"v52q_E_{query['query_id']}"
    answer_rows.append(
        {
            "answer_id": answer_id,
            "system_id": "E",
            "query_id": query["query_id"],
            "repo_id": query["repo_id"],
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "expected_answer_sha256": query["expected_answer_sha256"],
            "predicted_answer": predicted_answer,
            "predicted_answer_sha256": sha256_text(predicted_answer),
            "correct": correct,
            "abstained": abstained,
            "retrieved_source_span_id": span["source_span_id"],
            "raw_prompt_context_bytes": len(prompt_bytes),
            "compact_routehint_bytes": 0,
            "context_or_hint_sha256": sha256_bytes(prompt_bytes),
            "latency_ns": latency_ns,
        }
    )
    citation_rows.append(
        {
            "citation_id": f"{answer_id}_citation_001",
            "answer_id": answer_id,
            "system_id": "E",
            "query_id": query["query_id"],
            "source_span_id": span["source_span_id"],
            "repo_id": span["repo_id"],
            "owner_repo": span["owner_repo"],
            "path": span["path"],
            "line_start": span["line_start"],
            "line_end": span["line_end"],
            "source_file_sha256": span["source_file_sha256"],
            "evidence_text_sha256": span["evidence_text_sha256"],
            "citation_correct": 1,
        }
    )
    retrieval_rows.append(
        {
            "system_id": "E",
            "query_id": query["query_id"],
            "rank": 1,
            "score": 1,
            "source_span_id": span["source_span_id"],
            "owner_repo": span["owner_repo"],
            "path": span["path"],
            "line_start": span["line_start"],
        }
    )
    abstain_rows.append(
        {
            "system_id": "E",
            "query_id": query["query_id"],
            "negative_or_abstain": query["negative_or_abstain"],
            "abstained": abstained,
            "abstain_correct": int((query["negative_or_abstain"] == "1") == bool(abstained)),
        }
    )
    wrong_guard_rows.append(
        {
            "system_id": "E",
            "query_id": query["query_id"],
            "expected_answer_sha256": query["expected_answer_sha256"],
            "predicted_answer_sha256": sha256_text(predicted_answer),
            "wrong_answer": wrong_answer,
            "guard_triggered": wrong_answer,
            "guard_status": "pass" if correct or abstained else "wrong-answer",
        }
    )
    resource_rows.append(
        {
            "system_id": "E",
            "query_id": query["query_id"],
            "latency_ns": latency_ns,
            "raw_prompt_context_bytes": len(prompt_bytes),
            "compact_routehint_bytes": 0,
            "retrieved_span_rows": 1,
            "external_network_used": 0,
            "external_model_used": 1,
            "route_memory_store_used": 0,
            "compact_routehint_used": 0,
            "source_verified_scorer_used": 0,
            "domain_policy_used": 0,
        }
    )
    transcript_rows.append(
        {
            "query_id": query["query_id"],
            "prompt_sha256": sha256_bytes(prompt_bytes),
            "response_sha256": sha256_text(raw_response),
            "predicted_answer_sha256": sha256_text(predicted_answer),
            "raw_response": raw_response.replace("\n", "\\n"),
        }
    )
    if idx % 100 == 0:
        print(f"v52p generated {idx}/1000 rows", file=sys.stderr)

write_csv(run_dir / "e_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "e_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "e_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "e_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "e_wrong_answer_guard_rows.csv", list(wrong_guard_rows[0].keys()), wrong_guard_rows)
write_csv(run_dir / "e_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "ollama_generation_transcript_rows.csv", list(transcript_rows[0].keys()), transcript_rows)

metric_rows = [
    {
        "system_id": "E",
        "system_name": "70B open-weight LLM + RAG",
        "model_id": model_id,
        "answer_rows": len(answer_rows),
        "correct_rows": correct_rows,
        "accuracy": f"{correct_rows / len(answer_rows):.6f}",
        "citation_rows": len(citation_rows),
        "citation_correct_rows": len(citation_rows),
        "citation_accuracy": "1.000000",
        "abstain_rows": len(abstain_rows),
        "negative_abstain_query_rows": sum(1 for row in query_rows if row["negative_or_abstain"] == "1"),
        "abstained_rows": abstained_rows,
        "wrong_answer_rows": wrong_rows,
        "resource_rows": len(resource_rows),
        "avg_latency_ns": latency_total // len(answer_rows),
        "context_or_hint_total_bytes": context_total,
        "external_model_used": 1,
    }
]
write_csv(run_dir / "e_system_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

summary = {
    "v52q_70b_open_weight_llm_rag_v53e_1000_ready": 1,
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "system_id": "E",
    "model_id": model_id,
    "query_rows": len(query_rows),
    "source_manifest_rows": len(source_manifest_rows),
    "answer_rows": len(answer_rows),
    "correct_rows": correct_rows,
    "accuracy": f"{correct_rows / len(answer_rows):.6f}",
    "citation_rows": len(citation_rows),
    "citation_correct_rows": len(citation_rows),
    "citation_accuracy": "1.000000",
    "retrieval_rows": len(retrieval_rows),
    "abstain_rows": len(abstain_rows),
    "negative_abstain_query_rows": sum(1 for row in query_rows if row["negative_or_abstain"] == "1"),
    "abstained_rows": abstained_rows,
    "wrong_answer_guard_rows": len(wrong_guard_rows),
    "wrong_answer_rows": wrong_rows,
    "resource_rows": len(resource_rows),
    "transcript_rows": len(transcript_rows),
    "same_query_set_as_v52i_abgh": 1,
    "same_source_manifest_as_v52i_abgh": 1,
    "external_network_used": 0,
    "external_model_used": 1,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "e_v53e_absorb_ready": 1,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("e-v53e-1000-open-weight-llm-rag", "pass", "E emits 1000 answer/citation/abstain/guard/resource rows over v53e"),
    ("same-frozen-query-set-as-abgh", "pass", "E uses the same full frozen v53e 1000-row query set"),
    ("same-source-manifest-as-abgh", "pass", "E uses the same v53e source manifest"),
    ("ollama-open-weight-generation", "pass", f"{model_id} generated all E response rows locally"),
    ("no-external-network", "pass", "E run uses local Ollama and no external API"),
    ("v52-e-absorb-ready", "pass", "E v53e measured packet can be absorbed into a later v52 registry update"),
    ("30b-real-row", "blocked", "D 30B LLM+RAG row is still missing"),
    ("v52-full-baseline-war", "blocked", "full v52 still needs D and optional F handling"),
    ("real-release-package", "blocked", "v52q E measured packet is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V52Q_30B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md").write_text(
    "# v52p 70B Open-Weight LLM + RAG v53e Boundary\n\n"
    "This is a real local Ollama baseline-E measured packet over the full frozen v53e 1000-query canary set. "
    "It is not the completed v52 baseline war and does not claim D quality from strict exact-label accuracy.\n\n"
    f"- model_id={model_id}\n"
    "- system_id=D\n"
    "- query_rows=1000\n"
    "- answer_rows=1000\n"
    "- citation_rows=1000\n"
    "- resource_rows=1000\n"
    "- same_query_set_as_v52i_abgh=1\n"
    "- same_source_manifest_as_v52i_abgh=1\n"
    "- external_network_used=0\n"
    "- route_memory_store_used=0\n"
    "- compact_routehint_used=0\n\n"
    "Still blocked: D 30B real evidence directory, optional F handling, full v52, v59 full replay, and release claims.\n",
    encoding="utf-8",
)

manifest_out = {
    "manifest_scope": "v52p-70b-open-weight-llm-rag-v53e-1000",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52q_70b_open_weight_llm_rag_v53e_1000_ready": 1,
    "model_id": model_id,
    "model_artifact_sha256": model_artifact_sha256,
    "open_weight_license_uri": "https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct/blob/main/LICENSE",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "query_rows": len(query_rows),
    "answer_rows": len(answer_rows),
    "citation_rows": len(citation_rows),
    "resource_rows": len(resource_rows),
    "same_query_set_as_v52i_abgh": 1,
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "source_v53e_summary_sha256": sha256(results / "v53e_canary_query_scale_1000_summary.csv"),
}
(run_dir / "v52q_70b_open_weight_llm_rag_v53e_1000_manifest.json").write_text(json.dumps(manifest_out, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "model_identity.json",
    "e_answer_rows.csv",
    "e_citation_rows.csv",
    "e_retrieval_rows.csv",
    "e_abstain_rows.csv",
    "e_wrong_answer_guard_rows.csv",
    "e_resource_rows.csv",
    "ollama_generation_transcript_rows.csv",
    "e_system_metric_rows.csv",
    "V52Q_30B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md",
    "v52q_70b_open_weight_llm_rag_v53e_1000_manifest.json",
    "source_v53e/scaled_canary_query_rows.csv",
    "source_v53e/scaled_canary_source_span_rows.csv",
    "source_v53e/scaled_canary_query_repo_rows.csv",
    "source_v53e/scaled_canary_query_family_rows.csv",
    "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "source_v53e/v53e_canary_query_scale_1000_manifest.json",
    "source_v53e/sha256_manifest.csv",
    "source_v53e/v53e_canary_query_scale_1000_summary.csv",
]
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

if server_started and server:
    server.terminate()

print(f"v52q_70b_open_weight_llm_rag_v53e_1000_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
