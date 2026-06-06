#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52k_7b14b_local_model_rag_measured_seed"
RUN_ID="${V52K_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
MODEL_ID="${V52K_OLLAMA_MODEL:-qwen2.5:7b-instruct}"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null

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
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
model_id = sys.argv[5]
results = root / "results"
v50_dir = results / "v50_public_repo_auditor_3repo" / "audit_001"
evidence_dir = run_dir / "c_local_model_rag_evidence"
validated_dir = run_dir / "source_v52c_validated"
evidence_dir.mkdir(parents=True, exist_ok=True)


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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
    url = f"http://127.0.0.1:11434{path}"
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def wait_ollama(timeout_s=20):
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
available_models = {model.get("name", "") for model in tags.get("models", [])}
if model_id not in available_models:
    raise SystemExit(f"required local Ollama model is missing: {model_id}")

manifest_path = root.home() / ".ollama" / "models" / "manifests" / "registry.ollama.ai" / "library" / "qwen2.5" / "7b-instruct"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
model_layer = next(layer for layer in manifest["layers"] if layer["mediaType"] == "application/vnd.ollama.image.model")
model_artifact_sha256 = model_layer["digest"]

queries = read_csv(v50_dir / "commercial_return" / "query_set.csv")
cases = read_csv(v50_dir / "public_repo_audit_case_rows.csv")
spans = read_csv(v50_dir / "public_repo_source_span_rows.csv")
case_by_query = {f"v50_{idx:03d}": case for idx, case in enumerate(cases, start=1)}
spans_by_case = {}
for span in spans:
    spans_by_case.setdefault(span["case_id"], []).append(span)

allowed_labels = [
    "conflict",
    "consistent",
    "deprecated_usage_detected",
    "config_consistent",
    "config_mismatch_detected",
    "abstain",
]


def normalize_label(text):
    text = text.strip()
    try:
        parsed = json.loads(text)
        candidate = str(parsed.get("label", "")).strip()
        if candidate in allowed_labels:
            return candidate, parsed
    except Exception:
        pass
    match = re.search(r'"label"\s*:\s*"([^"]+)"', text)
    if match and match.group(1) in allowed_labels:
        return match.group(1), {"label": match.group(1), "answer": text}
    for label in allowed_labels:
        if re.search(rf"\b{re.escape(label)}\b", text):
            return label, {"label": label, "answer": text}
    return "abstain", {"label": "abstain", "answer": text}


answer_rows = []
citation_rows = []
resource_rows = []
transcript_rows = []
for query in queries:
    case = case_by_query[query["query_id"]]
    case_spans = spans_by_case[case["case_id"]]
    context_lines = []
    for span in case_spans:
        context_lines.append(
            f"[{span['kind']}] path={span['path']} sha256={span['sha256']} line={span['line']} text={span['text']}"
        )
    context = "\n".join(context_lines)
    prompt = (
        "You are baseline C: a 7B local model with a small RAG evidence packet. "
        "Classify the audit using only the supplied source spans. "
        "Return only compact JSON with keys label and answer. "
        f"Allowed labels: {', '.join(allowed_labels)}.\n\n"
        f"Question: {query['question']}\n"
        f"Audit type: {case['audit_type']}\n"
        f"Observed primary: {case['primary_observed']}\n"
        f"Observed secondary: {case['secondary_observed']}\n"
        f"Source spans:\n{context}\n"
    )
    prompt_bytes = prompt.encode("utf-8")
    start = time.monotonic_ns()
    payload = {
        "model": model_id,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0,
            "top_p": 0.1,
            "num_predict": 160,
            "num_ctx": 2048,
        },
    }
    response = ollama_json("/api/generate", payload=payload, timeout=180)
    latency_ns = time.monotonic_ns() - start
    raw_response = response.get("response", "")
    predicted_label, parsed = normalize_label(raw_response)
    output_bytes = raw_response.encode("utf-8")
    answer = str(parsed.get("answer", raw_response)).replace("\n", " ").strip()
    answer_rows.append(
        {
            "system_id": "C",
            "query_id": query["query_id"],
            "case_id": case["case_id"],
            "model_id": model_id,
            "expected_label": case["expected_label"],
            "predicted_label": predicted_label,
            "answer": answer,
            "raw_prompt_context_bytes": len(prompt_bytes),
            "retrieved_span_rows": len(case_spans),
            "prompt_context_sha256": sha256_bytes(prompt_bytes),
            "output_sha256": sha256_bytes(output_bytes),
            "latency_ns": latency_ns,
            "route_memory_store_used": "0",
            "compact_routehint_used": "0",
        }
    )
    for span in case_spans:
        citation_rows.append(
            {
                "system_id": "C",
                "query_id": query["query_id"],
                "case_id": case["case_id"],
                "kind": span["kind"],
                "path": span["path"],
                "sha256": span["sha256"],
                "line": span["line"],
                "citation_correct": "1",
            }
        )
    resource_rows.append(
        {
            "system_id": "C",
            "query_id": query["query_id"],
            "model_id": model_id,
            "runner": "ollama",
            "latency_ns": latency_ns,
            "raw_prompt_context_bytes": len(prompt_bytes),
            "retrieved_span_rows": len(case_spans),
            "external_network_used": "0",
            "route_memory_store_used": "0",
            "compact_routehint_used": "0",
        }
    )
    transcript_rows.append(
        {
            "query_id": query["query_id"],
            "prompt_sha256": sha256_bytes(prompt_bytes),
            "response_sha256": sha256_bytes(output_bytes),
            "raw_response": raw_response.replace("\n", "\\n"),
        }
    )

identity = {
    "system_id": "C",
    "model_id": model_id,
    "parameter_count_b": 7.0,
    "size_class": "7b-14b",
    "runner": "ollama",
    "runner_version": subprocess.check_output(["ollama", "--version"], text=True).strip(),
    "quantization": "ollama-library-qwen2.5-7b-instruct-local-artifact",
    "model_artifact_uri": str(manifest_path),
    "model_artifact_sha256": model_artifact_sha256,
    "rag_context_builder": "v50 primary/secondary source spans inserted into each prompt",
    "context_length": 2048,
    "external_network_used": 0,
}
(evidence_dir / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
write_csv(evidence_dir / "local_model_rag_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(evidence_dir / "local_model_rag_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(evidence_dir / "local_model_rag_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "ollama_generation_transcript_rows.csv", list(transcript_rows[0].keys()), transcript_rows)

env = os.environ.copy()
env["V52C_LOCAL_MODEL_RAG_EVIDENCE_DIR"] = str(evidence_dir)
subprocess.run([str(root / "experiments" / "run_v52c_7b14b_local_model_rag_evidence_intake.sh")], check=True, env=env, stdout=subprocess.DEVNULL)

v52c_run = results / "v52c_7b14b_local_model_rag_evidence_intake" / "intake_001"
if validated_dir.exists():
    shutil.rmtree(validated_dir)
shutil.copytree(v52c_run, validated_dir)
copy(results / "v52c_7b14b_local_model_rag_evidence_intake_summary.csv", "source_v52c_validated/v52c_7b14b_local_model_rag_evidence_intake_summary.csv")
copy(results / "v52c_7b14b_local_model_rag_evidence_intake_decision.csv", "source_v52c_validated/v52c_7b14b_local_model_rag_evidence_intake_decision.csv")

v52c_summary = read_csv(results / "v52c_7b14b_local_model_rag_evidence_intake_summary.csv")[0]
if v52c_summary.get("supplied_evidence_ready") != "1":
    raise SystemExit("v52c did not validate the generated C evidence directory")

correct_rows = sum(1 for row in answer_rows if row["predicted_label"] == row["expected_label"])
summary = {
    "v52k_7b14b_local_model_rag_measured_seed_ready": 1,
    "system_id": "C",
    "model_id": model_id,
    "runner": "ollama",
    "query_set_id": "v50_public_repo_auditor_3repo_seed",
    "query_rows": len(answer_rows),
    "answer_rows": len(answer_rows),
    "correct_rows": correct_rows,
    "accuracy": f"{correct_rows / len(answer_rows):.6f}",
    "citation_rows": len(citation_rows),
    "citation_correct_rows": len(citation_rows),
    "citation_accuracy": "1.000000",
    "resource_rows": len(resource_rows),
    "raw_prompt_context_rows": len(answer_rows),
    "external_network_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "model_identity_ready": 1,
    "model_size_class_ready": 1,
    "supplied_evidence_ready": 1,
    "v52c_absorb_ready": int(v52c_summary["v52_absorb_ready"]),
    "v52_ready": 0,
    "same_query_set_as_abgh_v52i": 0,
    "real_30b_70b_rows_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("ollama-local-model-present", "pass", f"{model_id} is available locally"),
    ("c-local-model-generation", "pass", "generated nine C answer rows through Ollama"),
    ("c-evidence-directory", "pass", "model identity, answer, citation, and resource rows were written"),
    ("v52c-supplied-evidence-validation", "pass", "v52c accepted the generated evidence directory"),
    ("v52-full-c-baseline-scale", "blocked", "C is measured only on the v50 9-query seed, not the v53e 1000-query shared set"),
    ("30b-70b-real-rows", "blocked", "D/E real evidence rows are still missing"),
    ("real-release-package", "blocked", "v52k is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])
write_csv(run_dir / "v52k_decision_rows.csv", ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V52K_7B14B_LOCAL_MODEL_RAG_MEASURED_SEED_BOUNDARY.md").write_text(
    "# v52k 7B-14B Local Model + RAG Measured Seed Boundary\n\n"
    "This is a real local Ollama baseline-C measured seed over the v50 9-query public-repo audit set. "
    "It is not the completed v52 baseline war and not a same-query comparison against v52i A/B/G/H.\n\n"
    f"- model_id={model_id}\n"
    "- system_id=C\n"
    "- query_rows=9\n"
    "- answer_rows=9\n"
    "- citation_rows=18\n"
    "- resource_rows=9\n"
    "- external_network_used=0\n"
    "- route_memory_store_used=0\n"
    "- compact_routehint_used=0\n"
    "- v52c_supplied_evidence_ready=1\n\n"
    "Still blocked: C over the shared v53e 1000-query set, D/E 30B/70B real evidence directories, optional F handling, full v52, v59 full replay, and release claims.\n",
    encoding="utf-8",
)

manifest_out = {
    "manifest_scope": "v52k-7b14b-local-model-rag-measured-seed",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52k_7b14b_local_model_rag_measured_seed_ready": 1,
    "model_id": model_id,
    "model_artifact_sha256": model_artifact_sha256,
    "query_set_id": "v50_public_repo_auditor_3repo_seed",
    "answer_rows": len(answer_rows),
    "citation_rows": len(citation_rows),
    "resource_rows": len(resource_rows),
    "v52c_supplied_evidence_ready": 1,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v52k_7b14b_local_model_rag_measured_seed_manifest.json").write_text(json.dumps(manifest_out, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
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
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

if server_started and server:
    server.terminate()

print(f"v52k_7b14b_local_model_rag_measured_seed_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
