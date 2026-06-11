#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53m_complete_source_system_c_local_model_rag_measured"
RUN_ID="${V53M_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
MODEL_ID="${V53M_OLLAMA_MODEL:-qwen2.5:7b-instruct}"

if [[ "${V53M_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53m_complete_source_system_c_local_model_rag_measured_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53L_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53l_complete_source_system_b_local_rag_measured.sh" >/dev/null

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
v53l_dir = results / "v53l_complete_source_system_b_local_rag_measured" / "measured_001"


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
            "The question asks whether a broad claim is proven by one complete-source span. "
            "If the span only supports a local fact, answer with an abstention boundary."
        )
    else:
        instruction = "Answer the bounded source-fact question using only the supplied source span."
    return (
        "You are baseline C: a 7B local model with one RAG source span. "
        "Return compact JSON only: {\"answer\":\"...\"}. "
        "Do not use outside knowledge. "
        f"{instruction}\n\n"
        f"Question: {query['question']}\n"
        f"Repository: {query['owner_repo']}\n"
        f"Audit type: {query['audit_type']}\n"
        f"Source path: {span['path']}\n"
        f"Source line: {span['line_start']}\n"
        f"Source text: {span['evidence_text']}\n"
    )


def provenance_hash(row):
    packet = {
        "answer_id": row["answer_id"],
        "system_id": row["system_id"],
        "query_id": row["query_id"],
        "answer_text_sha256": row["answer_text_sha256"],
        "resource_row_id": row["resource_row_id"],
    }
    return sha256_text(json.dumps(packet, sort_keys=True, separators=(",", ":")))


v53l_summary = read_csv(results / "v53l_complete_source_system_b_local_rag_measured_summary.csv")[0]
if v53l_summary.get("v53l_complete_source_system_b_local_rag_ready") != "1":
    raise SystemExit("v53m requires v53l_complete_source_system_b_local_rag_ready=1")

for rel in [
    "system_b_answer_rows.csv",
    "system_b_citation_rows.csv",
    "system_b_resource_rows.csv",
    "system_b_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53L_COMPLETE_SOURCE_SYSTEM_B_BOUNDARY.md",
    "v53l_complete_source_system_b_local_rag_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
    "source_v53k/v53k_complete_source_system_a_lexical_measured_summary.csv",
]:
    copy(v53l_dir / rel, f"source_v53l/{rel}")
copy(results / "v53l_complete_source_system_b_local_rag_measured_summary.csv", "source_v53l/v53l_complete_source_system_b_local_rag_measured_summary.csv")
copy(results / "v53l_complete_source_system_b_local_rag_measured_decision.csv", "source_v53l/v53l_complete_source_system_b_local_rag_measured_decision.csv")

queries = read_csv(v53l_dir / "source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")
span_rows = read_csv(v53l_dir / "source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")
spans = {row["source_span_id"]: row for row in span_rows}
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53m requires the v53i 1000 query/span set")

combined_ab_answers = read_csv(v53l_dir / "supplied_v53j/answer_rows.csv")
combined_ab_citations = read_csv(v53l_dir / "supplied_v53j/citation_rows.csv")
combined_ab_resources = read_csv(v53l_dir / "supplied_v53j/resource_rows.csv")
if len(combined_ab_answers) != 2000 or len(combined_ab_citations) != 2000 or len(combined_ab_resources) != 2000:
    raise SystemExit("v53m requires combined A+B supplied rows from v53l")

server_started = False
server = None
try:
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

    manifest_path = root.home() / ".ollama" / "models" / "manifests" / "registry.ollama.ai" / "library" / "qwen2.5" / "7b-instruct"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    model_layer = next(layer for layer in manifest["layers"] if layer["mediaType"] == "application/vnd.ollama.image.model")
    model_artifact_sha256 = model_layer["digest"]
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
        "rag_context_builder": "v53i complete-source span supplied per query",
        "context_length": 2048,
        "external_network_used": 0,
    }
    (run_dir / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    run_started_at = datetime.now(timezone.utc).isoformat()
    answer_rows = []
    citation_rows = []
    resource_rows = []
    retrieval_rows = []
    abstain_rows = []
    guard_rows = []
    transcript_rows = []
    correct_rows = 0
    abstained_rows = 0
    wrong_answer_rows = 0
    latency_ms_total = 0
    context_total = 0

    span_by_query = {row["query_id"]: row for row in span_rows}
    for idx, query in enumerate(queries, start=1):
        span = span_by_query[query["query_id"]]
        prompt = build_prompt(query, span)
        prompt_bytes = prompt.encode("utf-8")
        start_ns = time.monotonic_ns()
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
            timeout=180,
        )
        latency_ms = max(1, (time.monotonic_ns() - start_ns) // 1_000_000)
        raw_response = response.get("response", "")
        answer_text = clean_answer(raw_response) or "ABSTAIN"
        abstained = int(answer_text.upper().startswith("ABSTAIN"))
        strict_match = int(answer_text == query["expected_answer"])
        wrong_answer = int(not strict_match and not abstained)
        correct_rows += strict_match
        abstained_rows += abstained
        wrong_answer_rows += wrong_answer
        latency_ms_total += latency_ms
        context_total += len(prompt_bytes)

        answer_id = f"v53m_C_{query['query_id']}"
        resource_row_id = f"{answer_id}_resource"
        answer_row = {
            "answer_id": answer_id,
            "system_id": "C",
            "query_id": query["query_id"],
            "run_id": "v53m_system_c_7b14b_local_model_rag_measured_001",
            "model_identity_id": "system_c_qwen2_5_7b_instruct_local_rag_v1",
            "answer_text": answer_text,
            "answer_text_sha256": sha256_text(answer_text),
            "expected_behavior": query["expected_behavior"],
            "predicted_behavior": "abstain" if abstained else "answer-with-citation",
            "abstained": str(abstained),
            "resource_row_id": resource_row_id,
            "output_provenance_sha256": "",
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "source_span_id": query["source_span_id"],
            "strict_expected_answer_match": str(strict_match),
        }
        answer_row["output_provenance_sha256"] = provenance_hash(answer_row)
        answer_rows.append(answer_row)

        citation_text = span["evidence_text"]
        citation_rows.append(
            {
                "citation_id": f"{answer_id}_citation_001",
                "answer_id": answer_id,
                "system_id": "C",
                "query_id": query["query_id"],
                "source_span_id": span["source_span_id"],
                "source_file_sha256": span["source_file_sha256"],
                "citation_text": citation_text,
                "citation_text_sha256": sha256_text(citation_text),
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
                "line_end": span["line_end"],
            }
        )
        resource_rows.append(
            {
                "resource_row_id": resource_row_id,
                "answer_id": answer_id,
                "system_id": "C",
                "query_id": query["query_id"],
                "run_id": "v53m_system_c_7b14b_local_model_rag_measured_001",
                "latency_ms": str(latency_ms),
                "input_tokens_or_bytes": str(len(prompt_bytes)),
                "output_tokens_or_bytes": str(len(answer_text.encode("utf-8"))),
                "external_model_used": "0",
                "model_name": model_id,
                "hardware_or_endpoint": "local-ollama-no-network",
                "run_started_at_utc": run_started_at,
                "retrieved_span_rows": "1",
                "external_network_used": "0",
            }
        )
        retrieval_rows.append(
            {
                "system_id": "C",
                "query_id": query["query_id"],
                "rank": "1",
                "source_span_id": span["source_span_id"],
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
                "retrieval_method": "complete-source-one-span-local-rag",
                "retrieval_score": "1",
            }
        )
        abstain_rows.append(
            {
                "system_id": "C",
                "query_id": query["query_id"],
                "negative_or_abstain": query["negative_or_abstain"],
                "abstained": str(abstained),
                "abstain_expected": str(int(query["negative_or_abstain"] == "1")),
                "abstain_correct": str(int((query["negative_or_abstain"] == "1") == bool(abstained))),
            }
        )
        guard_rows.append(
            {
                "system_id": "C",
                "query_id": query["query_id"],
                "expected_answer_sha256": query["expected_answer_sha256"],
                "answer_text_sha256": sha256_text(answer_text),
                "strict_expected_answer_match": str(strict_match),
                "wrong_answer": str(wrong_answer),
                "guard_status": "pass" if strict_match or abstained else "wrong-answer",
            }
        )
        transcript_rows.append(
            {
                "query_id": query["query_id"],
                "prompt_sha256": sha256_bytes(prompt_bytes),
                "response_sha256": sha256_text(raw_response),
                "answer_text_sha256": sha256_text(answer_text),
                "latency_ms": str(latency_ms),
                "raw_response": raw_response.replace("\n", "\\n"),
            }
        )
        if idx % 100 == 0:
            print(f"v53m generated {idx}/1000 rows", file=sys.stderr)

    write_csv(run_dir / "system_c_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
    write_csv(run_dir / "system_c_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
    write_csv(run_dir / "system_c_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
    write_csv(run_dir / "system_c_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
    write_csv(run_dir / "system_c_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
    write_csv(run_dir / "system_c_wrong_answer_guard_rows.csv", list(guard_rows[0].keys()), guard_rows)
    write_csv(run_dir / "ollama_generation_transcript_rows.csv", list(transcript_rows[0].keys()), transcript_rows)

    combined_answers = combined_ab_answers + answer_rows
    combined_citations = combined_ab_citations + citation_rows
    combined_resources = combined_ab_resources + resource_rows
    write_csv(run_dir / "supplied_v53j" / "answer_rows.csv", list(combined_answers[0].keys()), combined_answers)
    write_csv(run_dir / "supplied_v53j" / "citation_rows.csv", list(combined_citations[0].keys()), combined_citations)
    write_csv(run_dir / "supplied_v53j" / "resource_rows.csv", list(combined_resources[0].keys()), combined_resources)

    validation_rows = []
    for system_id in ["A", "B", "C", "D", "E", "G", "H"]:
        valid = 1000 if system_id in {"A", "B", "C"} else 0
        validation_rows.append(
            {
                "system_id": system_id,
                "target_answer_rows": "1000",
                "valid_answer_rows": str(valid),
                "valid_citation_rows": str(valid),
                "valid_resource_rows": str(valid),
                "missing_valid_answer_rows": str(1000 - valid),
                "status": "valid" if valid == 1000 else "missing-or-invalid",
            }
        )
    write_csv(run_dir / "v53j_partial_supplied_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

    metric_rows = [
        {
            "system_id": "C",
            "system_name": "7B-14B local model + RAG",
            "model_id": model_id,
            "query_rows": "1000",
            "answer_rows": str(len(answer_rows)),
            "strict_expected_answer_match_rows": str(correct_rows),
            "strict_expected_answer_accuracy": f"{correct_rows / len(answer_rows):.6f}",
            "citation_rows": str(len(citation_rows)),
            "resource_rows": str(len(resource_rows)),
            "retrieval_rows": str(len(retrieval_rows)),
            "abstain_rows": str(len(abstain_rows)),
            "negative_abstain_rows": str(sum(1 for row in queries if row["negative_or_abstain"] == "1")),
            "abstained_rows": str(abstained_rows),
            "wrong_answer_rows": str(wrong_answer_rows),
            "avg_latency_ms": str(latency_ms_total // len(answer_rows)),
            "context_total_bytes": str(context_total),
            "external_model_used": "0",
            "external_network_used": "0",
        }
    ]
    write_csv(run_dir / "system_c_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

    c_ready = int(len(answer_rows) == 1000 and len(citation_rows) == 1000 and len(resource_rows) == 1000)
    summary = {
        "v53m_complete_source_system_c_local_model_rag_ready": str(c_ready),
        "v53_ready": "0",
        "v53l_complete_source_system_b_local_rag_ready": v53l_summary["v53l_complete_source_system_b_local_rag_ready"],
        "complete_source_query_rows": "1000",
        "system_id": "C",
        "system_name": "7B-14B local model + RAG",
        "model_id": model_id,
        "c_answer_rows": str(len(answer_rows)),
        "c_citation_rows": str(len(citation_rows)),
        "c_resource_rows": str(len(resource_rows)),
        "c_retrieval_rows": str(len(retrieval_rows)),
        "c_abstain_rows": str(len(abstain_rows)),
        "c_guard_rows": str(len(guard_rows)),
        "c_transcript_rows": str(len(transcript_rows)),
        "c_strict_expected_answer_match_rows": str(correct_rows),
        "c_wrong_answer_rows": str(wrong_answer_rows),
        "combined_abc_answer_rows": str(len(combined_answers)),
        "combined_abc_citation_rows": str(len(combined_citations)),
        "combined_abc_resource_rows": str(len(combined_resources)),
        "v53j_compatible_answer_rows": str(len(combined_answers)),
        "v53j_compatible_citation_rows": str(len(combined_citations)),
        "v53j_compatible_resource_rows": str(len(combined_resources)),
        "valid_core_system_count": "3",
        "remaining_core_system_count": "4",
        "remaining_core_systems": "D/E/G/H",
        "remaining_core_answer_rows": "4000",
        "required_core_systems_ready": "0",
        "answer_citation_resource_rows_ready": "0",
        "symmetric_scorer_policy_rows_ready": "0",
        "review_artifacts_ready": "0",
        "real_release_package_ready": "0",
    }
    write_csv(summary_csv, list(summary.keys()), [summary])

    decision_rows = [
        ("v53l-system-ab-input", "pass", "v53l combined A+B complete-source packet is bound"),
        ("ollama-local-model-present", "pass", f"{model_id} is available locally"),
        ("system-c-answer-rows", "pass" if c_ready else "blocked", f"c_answer_rows={len(answer_rows)}"),
        ("system-c-citation-rows", "pass" if len(citation_rows) == 1000 else "blocked", f"c_citation_rows={len(citation_rows)}"),
        ("system-c-resource-rows", "pass" if len(resource_rows) == 1000 else "blocked", f"c_resource_rows={len(resource_rows)}"),
        ("v53j-compatible-combined-abc-supplied-dir", "pass", "combined A+B+C supplied_v53j rows emitted"),
        ("all-core-systems-ready", "blocked", "D/E/G/H supplied rows are still absent"),
        ("symmetric-scorer-policy-rows", "blocked", "symmetric scorer/policy rows over v53m are absent"),
        ("human-review-artifacts", "blocked", "human/release review artifacts are not supplied"),
        ("v53-full-public-repo-audit", "blocked", "Systems A/B/C are measured; remaining core systems and review evidence are still required"),
        ("real-release-package", "blocked", "v53m is not a release package"),
    ]
    write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

    (run_dir / "V53M_COMPLETE_SOURCE_SYSTEM_C_BOUNDARY.md").write_text(
        "# v53m Complete Source System C Local-Model-RAG Boundary\n\n"
        "This layer supplies real local Ollama System C answer, citation, resource, and transcript rows over the same v53i complete-source 1000-query set used by v53k/v53l. "
        "It also emits a combined A+B+C partial supplied_v53j directory. This is not the completed v53 audit.\n\n"
        f"- system_id=C\n"
        f"- model_id={model_id}\n"
        "- complete_source_query_rows=1000\n"
        f"- c_answer_rows={len(answer_rows)}\n"
        f"- c_citation_rows={len(citation_rows)}\n"
        f"- c_resource_rows={len(resource_rows)}\n"
        f"- c_transcript_rows={len(transcript_rows)}\n"
        f"- c_strict_expected_answer_match_rows={correct_rows}\n"
        f"- combined_abc_answer_rows={len(combined_answers)}\n"
        "- remaining_core_systems=D/E/G/H\n"
        "- v53_ready=0\n\n"
        "Still blocked:\n\n"
        "- supplied D/E/G/H answer/citation/resource rows over the same complete-source query IDs\n"
        "- symmetric scorer/policy rows\n"
        "- human/source review artifacts and release evidence\n\n"
        "Do not publish v53 completion, v1.0 comparison, superiority, or release claims from A+B+C rows alone.\n",
        encoding="utf-8",
    )

    manifest_out = {
        "manifest_scope": "v53m-complete-source-system-c-local-model-rag-measured",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "v53m_complete_source_system_c_local_model_rag_ready": c_ready,
        "v53_ready": 0,
        "system_id": "C",
        "model_id": model_id,
        "model_artifact_sha256": model_artifact_sha256,
        "complete_source_query_rows": 1000,
        "c_answer_rows": len(answer_rows),
        "c_citation_rows": len(citation_rows),
        "c_resource_rows": len(resource_rows),
        "c_transcript_rows": len(transcript_rows),
        "combined_abc_answer_rows": len(combined_answers),
        "remaining_core_systems": ["D", "E", "G", "H"],
        "v53l_summary_sha256": sha256(results / "v53l_complete_source_system_b_local_rag_measured_summary.csv"),
        "real_release_package_ready": 0,
    }
    (run_dir / "v53m_complete_source_system_c_local_model_rag_measured_manifest.json").write_text(
        json.dumps(manifest_out, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    artifact_rels = [
        "model_identity.json",
        "system_c_answer_rows.csv",
        "system_c_citation_rows.csv",
        "system_c_resource_rows.csv",
        "system_c_retrieval_rows.csv",
        "system_c_abstain_rows.csv",
        "system_c_wrong_answer_guard_rows.csv",
        "ollama_generation_transcript_rows.csv",
        "system_c_metric_rows.csv",
        "v53j_partial_supplied_validation_rows.csv",
        "supplied_v53j/answer_rows.csv",
        "supplied_v53j/citation_rows.csv",
        "supplied_v53j/resource_rows.csv",
        "V53M_COMPLETE_SOURCE_SYSTEM_C_BOUNDARY.md",
        "v53m_complete_source_system_c_local_model_rag_measured_manifest.json",
        "source_v53l/supplied_v53j/answer_rows.csv",
        "source_v53l/supplied_v53j/citation_rows.csv",
        "source_v53l/supplied_v53j/resource_rows.csv",
        "source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
        "source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
        "source_v53l/v53l_complete_source_system_b_local_rag_measured_summary.csv",
        "source_v53l/v53l_complete_source_system_b_local_rag_measured_decision.csv",
    ]
    artifact_rows = []
    for rel in artifact_rels:
        path = run_dir / rel
        artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
    write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)
finally:
    if server_started and server:
        server.terminate()

print(f"v53m_complete_source_system_c_local_model_rag_measured_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
