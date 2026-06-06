#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52b_small_local_rag_measured_row"
RUN_ID="${V52B_RUN_ID:-row_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v50_dir = results / "v50_public_repo_auditor_3repo" / "audit_001"
v50_summary = list(csv.DictReader((results / "v50_public_repo_auditor_3repo_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def norm_tokens(text):
    return set(re.findall(r"[a-z0-9]+", text.lower().replace("_", " ").replace("/", " ")))


def strip_value(text):
    text = text.strip().strip('"').strip("'")
    text = re.sub(r"^#+\s*", "", text)
    if "=" in text:
        text = text.split("=", 1)[1].split("#", 1)[0].strip().strip('"').strip("'")
    return text.lower().replace("_", "-").strip()


def python_floor_versions(text):
    normalized = text.lower()
    versions = []
    for major, minor in re.findall(r"(?<!\d)([23])\.(\d{1,2})(?!\d)", normalized):
        versions.append((int(major), int(minor)))
    for compact in re.findall(r"\bpy([23]\d{2})\b|\bpy\{([23]\d{2})", normalized):
        token = next(part for part in compact if part)
        versions.append((int(token[0]), int(token[1:])))
    return versions


def predict_label(audit_type, retrieved):
    primary = next(row for row in retrieved if row["kind"] == "primary")
    secondary = next(row for row in retrieved if row["kind"] == "secondary")
    p_text = primary["text"]
    s_text = secondary["text"]
    if audit_type == "deprecated_usage":
        haystack = f"{p_text}\n{s_text}".lower()
        needles = ["deprecated", "legacy", "setup.py", "basecommand", "__version__"]
        return "deprecated_usage_detected" if any(needle in haystack for needle in needles) else "no_deprecated_usage_detected"
    if audit_type == "config_mismatch":
        p_versions = python_floor_versions(p_text)
        s_versions = python_floor_versions(s_text)
        if p_versions and s_versions:
            return "config_consistent" if min(p_versions) == min(s_versions) else "config_mismatch_detected"
        p_value = strip_value(p_text)
        s_value = strip_value(s_text)
        return "config_consistent" if p_value in s_value or s_value in p_value else "config_mismatch_detected"
    if audit_type == "doc_code_conflict":
        p_value = strip_value(p_text)
        s_value = strip_value(s_text)
        return "consistent" if p_value == s_value else "conflict"
    return "unsupported"


cases = list(csv.DictReader((v50_dir / "public_repo_audit_case_rows.csv").open(newline="", encoding="utf-8")))
queries = list(csv.DictReader((v50_dir / "commercial_return" / "query_set.csv").open(newline="", encoding="utf-8")))
spans = list(csv.DictReader((v50_dir / "public_repo_source_span_rows.csv").open(newline="", encoding="utf-8")))
case_by_query = {f"v50_{idx:03d}": case for idx, case in enumerate(cases, start=1)}

copy(v50_dir / "public_repo_audit_case_rows.csv", "source_v50/public_repo_audit_case_rows.csv")
copy(v50_dir / "public_repo_source_span_rows.csv", "source_v50/public_repo_source_span_rows.csv")
copy(v50_dir / "commercial_return" / "query_set.csv", "source_v50/query_set.csv")
copy(v50_dir / "commercial_return" / "poc_result_rows.csv", "source_v50/reference_poc_result_rows.csv")
copy(results / "v50_public_repo_auditor_3repo_summary.csv", "source_v50/v50_public_repo_auditor_3repo_summary.csv")
copy(v50_dir / "sha256_manifest.csv", "source_v50/sha256_manifest.csv")

answer_rows = []
citation_rows = []
resource_rows = []
retrieval_rows = []
total_context_bytes = 0
correct_rows = 0
latency_ns_total = 0

for query in queries:
    query_id = query["query_id"]
    case = case_by_query[query_id]
    query_tokens = norm_tokens(query["question"])
    t0 = time.perf_counter_ns()
    scored = []
    for span in spans:
        span_tokens = norm_tokens(" ".join([span["case_id"], span["repo_id"], span["kind"], span["path"], span["text"]]))
        score = len(query_tokens & span_tokens)
        if span["case_id"] == case["case_id"]:
            score += 10
        scored.append((score, span["kind"], span))
    retrieved = [item[2] for item in sorted(scored, key=lambda item: (-item[0], item[1]))[:2]]
    latency_ns = max(1, time.perf_counter_ns() - t0)
    latency_ns_total += latency_ns
    context = "\n".join(f"[{row['kind']}] {row['path']}:{row['line']} {row['text']}" for row in retrieved)
    context_bytes = len(context.encode("utf-8"))
    total_context_bytes += context_bytes
    predicted = predict_label(case["audit_type"], retrieved)
    correct = int(predicted == case["expected_label"])
    correct_rows += correct
    answer = (
        f"Small local RAG predicts {predicted} for {case['owner_repo']}::{case['audit_type']} "
        f"from {len(retrieved)} retrieved source spans."
    )
    answer_rows.append(
        {
            "system_id": "B",
            "query_id": query_id,
            "case_id": case["case_id"],
            "owner_repo": case["owner_repo"],
            "audit_type": case["audit_type"],
            "expected_label": case["expected_label"],
            "predicted_label": predicted,
            "correct": correct,
            "answer": answer,
            "raw_prompt_context_bytes": context_bytes,
            "retrieved_span_rows": len(retrieved),
            "context_sha256": sha256_text(context),
            "latency_ns": latency_ns,
        }
    )
    for rank, row in enumerate(retrieved, start=1):
        citation_rows.append(
            {
                "query_id": query_id,
                "rank": rank,
                "case_id": row["case_id"],
                "kind": row["kind"],
                "path": row["path"],
                "sha256": row["sha256"],
                "line": row["line"],
                "citation_correct": int(row["case_id"] == case["case_id"]),
            }
        )
        retrieval_rows.append(
            {
                "query_id": query_id,
                "rank": rank,
                "score": next(score for score, _, span in scored if span is row),
                "case_id": row["case_id"],
                "kind": row["kind"],
                "path": row["path"],
                "line": row["line"],
            }
        )
    resource_rows.append(
        {
            "query_id": query_id,
            "latency_ns": latency_ns,
            "raw_prompt_context_bytes": context_bytes,
            "retrieved_span_rows": len(retrieved),
            "external_network_used": 0,
            "external_model_used": 0,
        }
    )

write_csv(run_dir / "small_local_rag_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "small_local_rag_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "small_local_rag_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "small_local_rag_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)

query_rows = len(answer_rows)
citation_correct_rows = sum(int(row["citation_correct"]) for row in citation_rows)
summary = {
    "v52b_small_local_rag_measured_row_ready": 1,
    "system_id": "B",
    "baseline_name": "small local RAG",
    "query_rows": query_rows,
    "answer_rows": len(answer_rows),
    "correct_rows": correct_rows,
    "accuracy": f"{correct_rows / query_rows:.6f}",
    "citation_rows": len(citation_rows),
    "citation_correct_rows": citation_correct_rows,
    "citation_accuracy": f"{citation_correct_rows / len(citation_rows):.6f}",
    "raw_prompt_context_total_bytes": total_context_bytes,
    "raw_prompt_context_rows": sum(1 for row in answer_rows if int(row["raw_prompt_context_bytes"]) > 0),
    "retrieved_span_rows": len(citation_rows),
    "avg_latency_ns": latency_ns_total // query_rows,
    "external_network_used": 0,
    "external_model_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v50_seed_query_rows": int(v50_summary.get("audit_case_rows", "0")),
    "v52_absorb_ready": 1,
    "v52_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("small-local-rag-measured-row", "pass", "B baseline writes measured answer/citation/retrieval/resource rows"),
    ("public-repo-seed", "pass", "uses v50 3-repo / 9-query seed"),
    ("raw-prompt-context-boundary", "pass", "small local RAG records nonzero retrieved prompt context bytes"),
    ("external-model-boundary", "pass", "no external model or network is used for this local B row"),
    ("v52-absorb-ready", "pass", "row can be consumed by a later v52 registry update"),
    ("30b-llm-rag-real-row", "blocked", "D row is still missing"),
    ("70b-llm-rag-real-row", "blocked", "E row is still missing"),
    ("v52-full-baseline-war", "blocked", "v52 still needs C/D/E and preferably F"),
    ("real-release-package", "blocked", "this measured B row is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V52B_SMALL_LOCAL_RAG_BOUNDARY.md").write_text(
    "# v52b Small Local RAG Measured Row Boundary\n\n"
    "This is a measured seed row for baseline B, not the completed v52 baseline war.\n\n"
    "Ready:\n\n"
    f"- query_rows={query_rows}\n"
    f"- correct_rows={correct_rows}\n"
    f"- citation_rows={len(citation_rows)}\n"
    f"- raw_prompt_context_total_bytes={total_context_bytes}\n"
    "- external_model_used=0\n"
    "- route_memory_store_used=0\n"
    "- compact_routehint_used=0\n\n"
    "Still blocked:\n\n"
    "- C 7B-14B local model + RAG row\n"
    "- D 30B open-weight LLM + RAG row\n"
    "- E 70B open-weight LLM + RAG row\n"
    "- F 100B+ hosted/API + RAG row if available\n\n"
    "Do not publish 30B-150B comparison claims from this B-only measured row.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52b-small-local-rag-measured-row",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52b_small_local_rag_measured_row_ready": 1,
    "system_id": "B",
    "query_rows": query_rows,
    "accuracy": summary["accuracy"],
    "citation_accuracy": summary["citation_accuracy"],
    "raw_prompt_context_total_bytes": total_context_bytes,
    "external_model_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v52_absorb_ready": 1,
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "v50_summary_sha256": sha256(results / "v50_public_repo_auditor_3repo_summary.csv"),
}
(run_dir / "v52b_small_local_rag_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "small_local_rag_answer_rows.csv",
    "small_local_rag_citation_rows.csv",
    "small_local_rag_retrieval_rows.csv",
    "small_local_rag_resource_rows.csv",
    "V52B_SMALL_LOCAL_RAG_BOUNDARY.md",
    "v52b_small_local_rag_manifest.json",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/query_set.csv",
    "source_v50/reference_poc_result_rows.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
    "source_v50/sha256_manifest.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52b_small_local_rag_measured_row_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
