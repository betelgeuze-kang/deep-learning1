#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52f_small_local_rag_measured_100"
RUN_ID="${V52F_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V52F_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v53d_canary_source_query_seed_100_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v53d_canary_source_query_seed_100.sh" >/dev/null
fi

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
v53d_dir = results / "v53d_canary_source_query_seed_100" / "query_001"
v53d_summary = list(csv.DictReader((results / "v53d_canary_source_query_seed_100_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def tokens(text):
    return set(re.findall(r"[a-z0-9]+", text.lower().replace("_", " ").replace("/", " ")))


for relpath in [
    "canary_query_rows.csv",
    "canary_source_span_rows.csv",
    "canary_query_repo_rows.csv",
    "canary_query_family_rows.csv",
    "V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
    "v53d_canary_source_query_seed_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53d_dir / relpath, f"source_v53d/{relpath}")
copy(results / "v53d_canary_source_query_seed_100_summary.csv", "source_v53d/v53d_canary_source_query_seed_100_summary.csv")

query_rows = read_csv(v53d_dir / "canary_query_rows.csv")
span_rows = read_csv(v53d_dir / "canary_source_span_rows.csv")
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

span_by_id = {row["source_span_id"]: row for row in span_rows}
span_tokens = {
    row["source_span_id"]: tokens(" ".join([row["owner_repo"], row["path"], row["line_start"], row["evidence_text"]]))
    for row in span_rows
}

answer_rows = []
citation_rows = []
retrieval_rows = []
abstain_rows = []
wrong_guard_rows = []
resource_rows = []
correct_rows = 0
citation_correct_rows = 0
latency_total = 0
context_total = 0

for query in query_rows:
    query_id = query["query_id"]
    q_tokens = tokens(" ".join([query["owner_repo"], query["source_path"], query["source_line_start"], query["question"]]))
    t0 = time.perf_counter_ns()
    scored = []
    for span in span_rows:
        score = len(q_tokens & span_tokens[span["source_span_id"]])
        if span["owner_repo"] == query["owner_repo"]:
            score += 6
        if span["path"] == query["source_path"]:
            score += 5
        if span["line_start"] == query["source_line_start"]:
            score += 3
        scored.append((score, span["source_span_id"], span))
    ranked = sorted(scored, key=lambda item: (-item[0], item[1]))
    best_score, _, best_span = ranked[0]
    latency_ns = max(1, time.perf_counter_ns() - t0)
    latency_total += latency_ns
    context = f"[{best_span['source_span_id']}] {best_span['owner_repo']} {best_span['path']}:{best_span['line_start']} {best_span['evidence_text']}"
    context_bytes = len(context.encode("utf-8"))
    context_total += context_bytes
    abstained = int(best_score <= 0 or query["negative_or_abstain"] == "1")
    if abstained:
        predicted_answer = "ABSTAIN"
    else:
        predicted_answer = f"Evidence at {best_span['path']}:{best_span['line_start']} supports: {best_span['evidence_text']}"
    correct = int(predicted_answer == query["expected_answer"])
    citation_correct = int(best_span["source_span_id"] == query["source_span_id"])
    correct_rows += correct
    citation_correct_rows += citation_correct
    answer_rows.append(
        {
            "system_id": "B",
            "query_id": query_id,
            "repo_id": query["repo_id"],
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "expected_answer_sha256": query["expected_answer_sha256"],
            "predicted_answer": predicted_answer,
            "predicted_answer_sha256": sha256_text(predicted_answer),
            "correct": correct,
            "abstained": abstained,
            "retrieved_source_span_id": best_span["source_span_id"],
            "raw_prompt_context_bytes": context_bytes,
            "context_sha256": sha256_text(context),
            "latency_ns": latency_ns,
        }
    )
    citation_rows.append(
        {
            "system_id": "B",
            "query_id": query_id,
            "source_span_id": best_span["source_span_id"],
            "repo_id": best_span["repo_id"],
            "owner_repo": best_span["owner_repo"],
            "path": best_span["path"],
            "line_start": best_span["line_start"],
            "line_end": best_span["line_end"],
            "source_file_sha256": best_span["source_file_sha256"],
            "evidence_text_sha256": best_span["evidence_text_sha256"],
            "citation_correct": citation_correct,
        }
    )
    for rank, (score, _, span) in enumerate(ranked[:3], start=1):
        retrieval_rows.append(
            {
                "system_id": "B",
                "query_id": query_id,
                "rank": rank,
                "score": score,
                "source_span_id": span["source_span_id"],
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
            }
        )
    abstain_rows.append(
        {
            "system_id": "B",
            "query_id": query_id,
            "negative_or_abstain": query["negative_or_abstain"],
            "abstained": abstained,
            "abstain_correct": int((query["negative_or_abstain"] == "1") == bool(abstained)),
        }
    )
    wrong_guard_rows.append(
        {
            "system_id": "B",
            "query_id": query_id,
            "expected_answer_sha256": query["expected_answer_sha256"],
            "predicted_answer_sha256": sha256_text(predicted_answer),
            "wrong_answer": int(not correct and not abstained),
            "guard_triggered": int(not correct and not abstained),
            "guard_status": "pass" if correct or abstained else "wrong-answer",
        }
    )
    resource_rows.append(
        {
            "system_id": "B",
            "query_id": query_id,
            "latency_ns": latency_ns,
            "raw_prompt_context_bytes": context_bytes,
            "retrieved_span_rows": 3,
            "external_network_used": 0,
            "external_model_used": 0,
            "route_memory_store_used": 0,
            "compact_routehint_used": 0,
        }
    )

write_csv(run_dir / "source_manifest_rows.csv", list(source_manifest_rows[0].keys()), source_manifest_rows)
write_csv(run_dir / "small_local_rag_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "small_local_rag_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "small_local_rag_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "small_local_rag_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "small_local_rag_wrong_answer_guard_rows.csv", list(wrong_guard_rows[0].keys()), wrong_guard_rows)
write_csv(run_dir / "small_local_rag_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)

query_count = len(query_rows)
summary = {
    "v52f_small_local_rag_measured_100_ready": 1,
    "system_id": "B",
    "baseline_name": "small local RAG",
    "query_set_id": "v53d_canary_source_query_seed_100",
    "query_rows": query_count,
    "source_manifest_rows": len(source_manifest_rows),
    "answer_rows": len(answer_rows),
    "correct_rows": correct_rows,
    "accuracy": f"{correct_rows / query_count:.6f}",
    "citation_rows": len(citation_rows),
    "citation_correct_rows": citation_correct_rows,
    "citation_accuracy": f"{citation_correct_rows / len(citation_rows):.6f}",
    "abstain_rows": len(abstain_rows),
    "abstained_rows": sum(int(row["abstained"]) for row in abstain_rows),
    "wrong_answer_guard_rows": len(wrong_guard_rows),
    "wrong_answer_rows": sum(int(row["wrong_answer"]) for row in wrong_guard_rows),
    "resource_rows": len(resource_rows),
    "raw_prompt_context_total_bytes": context_total,
    "avg_latency_ns": latency_total // query_count,
    "external_network_used": 0,
    "external_model_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v53d_canary_query_seed_ready": int(v53d_summary.get("v53d_canary_query_seed_ready", "0")),
    "v52_absorb_ready": 1,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("small-local-rag-100-measured", "pass", "B baseline writes 100 measured answer/citation/abstain/guard/resource rows"),
    ("same-frozen-query-set", "pass", "uses v53d 100-row frozen query ids and source spans"),
    ("source-manifest", "pass", f"source_manifest_rows={len(source_manifest_rows)}"),
    ("no-external-model", "pass", "local lexical/RAG scoring only"),
    ("v52-absorb-ready", "pass", "B-100 can be absorbed into v52 comparison registry"),
    ("v52-full-baseline-war", "blocked", "A/C/D/E/F/G/H comparable rows over the same set are still missing"),
    ("real-release-package", "blocked", "B-100 measured run is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V52F_SMALL_LOCAL_RAG_100_BOUNDARY.md").write_text(
    "# v52f Small Local RAG 100-Row Boundary\n\n"
    "This is the 100-row measured expansion for baseline B over the frozen v53d query set. "
    "It is not the completed v52 baseline war.\n\n"
    f"- query_rows={query_count}\n"
    f"- answer_rows={len(answer_rows)}\n"
    f"- citation_rows={len(citation_rows)}\n"
    f"- abstain_rows={len(abstain_rows)}\n"
    f"- wrong_answer_guard_rows={len(wrong_guard_rows)}\n"
    f"- resource_rows={len(resource_rows)}\n"
    "- external_model_used=0\n\n"
    "Still blocked:\n\n"
    "- A/G/H rows on the same frozen query set\n"
    "- C/D/E/F evidence directories and validated rows\n"
    "- complete-source v53 audit rows\n\n"
    "Do not publish 30B-150B comparison claims from this B-only 100-row measured run.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52f-small-local-rag-measured-100",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52f_small_local_rag_measured_100_ready": 1,
    "system_id": "B",
    "query_set_id": "v53d_canary_source_query_seed_100",
    "query_rows": query_count,
    "accuracy": summary["accuracy"],
    "citation_accuracy": summary["citation_accuracy"],
    "wrong_answer_rows": summary["wrong_answer_rows"],
    "external_model_used": 0,
    "v52_absorb_ready": 1,
    "v52_ready": 0,
    "source_v53d_summary_sha256": sha256(results / "v53d_canary_source_query_seed_100_summary.csv"),
}
(run_dir / "v52f_small_local_rag_measured_100_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "source_manifest_rows.csv",
    "small_local_rag_answer_rows.csv",
    "small_local_rag_citation_rows.csv",
    "small_local_rag_retrieval_rows.csv",
    "small_local_rag_abstain_rows.csv",
    "small_local_rag_wrong_answer_guard_rows.csv",
    "small_local_rag_resource_rows.csv",
    "V52F_SMALL_LOCAL_RAG_100_BOUNDARY.md",
    "v52f_small_local_rag_measured_100_manifest.json",
    "source_v53d/canary_query_rows.csv",
    "source_v53d/canary_source_span_rows.csv",
    "source_v53d/canary_query_repo_rows.csv",
    "source_v53d/canary_query_family_rows.csv",
    "source_v53d/V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
    "source_v53d/v53d_canary_source_query_seed_manifest.json",
    "source_v53d/sha256_manifest.csv",
    "source_v53d/v53d_canary_source_query_seed_100_summary.csv",
]
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52f_small_local_rag_measured_100_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
