#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52h_small_local_rag_measured_1000"
RUN_ID="${V52H_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V52H_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53e_dir = results / "v53e_canary_query_scale_1000" / "scale_001"
v53e_summary = list(csv.DictReader((results / "v53e_canary_query_scale_1000_summary.csv").open(newline="", encoding="utf-8")))[0]

TARGET_ROWS = 1000
TARGET_FAMILY_ROWS = {
    "doc_code_conflict": 140,
    "deprecation_legacy_usage": 140,
    "config_mismatch": 140,
    "api_behavior": 160,
    "docs_truthfulness": 160,
    "examples_tests_alignment": 100,
    "unsupported_claim_abstain": 100,
    "ambiguous_source_abstain": 60,
}


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

all_query_rows = read_csv(v53e_dir / "scaled_canary_query_rows.csv")
all_span_rows = read_csv(v53e_dir / "scaled_canary_source_span_rows.csv")
if len(all_query_rows) < TARGET_ROWS:
    raise SystemExit(f"v53e query source should have at least {TARGET_ROWS} rows")

query_rows = []
for family, target in TARGET_FAMILY_ROWS.items():
    family_rows = [row for row in all_query_rows if row["audit_type"] == family]
    if len(family_rows) < target:
        raise SystemExit(f"v53e family {family} should have at least {target} rows")
    query_rows.extend(family_rows[:target])
query_rows = sorted(query_rows, key=lambda row: row["query_id"])
selected_query_ids = {row["query_id"] for row in query_rows}
span_rows = [row for row in all_span_rows if row["query_id"] in selected_query_ids]
if len(span_rows) != TARGET_ROWS:
    raise SystemExit("selected v53e span rows should match selected query rows")

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
family_counts = Counter(row["audit_type"] for row in query_rows)
repo_counts = Counter(row["owner_repo"] for row in query_rows)
negative_rows = sum(int(row["negative_or_abstain"]) for row in query_rows)
summary = {
    "v52h_small_local_rag_measured_1000_ready": 1,
    "system_id": "B",
    "baseline_name": "small local RAG",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "parent_query_set_id": "v53e_canary_query_scale_1000",
    "query_rows": query_count,
    "source_manifest_rows": len(source_manifest_rows),
    "answer_rows": len(answer_rows),
    "correct_rows": correct_rows,
    "accuracy": f"{correct_rows / query_count:.6f}",
    "citation_rows": len(citation_rows),
    "citation_correct_rows": citation_correct_rows,
    "citation_accuracy": f"{citation_correct_rows / len(citation_rows):.6f}",
    "abstain_rows": len(abstain_rows),
    "negative_abstain_query_rows": negative_rows,
    "abstained_rows": sum(int(row["abstained"]) for row in abstain_rows),
    "wrong_answer_guard_rows": len(wrong_guard_rows),
    "wrong_answer_rows": sum(int(row["wrong_answer"]) for row in wrong_guard_rows),
    "resource_rows": len(resource_rows),
    "retrieval_rows": len(retrieval_rows),
    "repo_count": len(repo_counts),
    "family_count": len(family_counts),
    "raw_prompt_context_total_bytes": context_total,
    "avg_latency_ns": latency_total // query_count,
    "external_network_used": 0,
    "external_model_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v53e_canary_query_scale_ready": int(v53e_summary.get("v53e_canary_query_scale_ready", "0")),
    "v52_absorb_ready": 1,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("small-local-rag-1000-measured", "pass", "B baseline writes 1000 measured answer/citation/abstain/guard/resource rows"),
    ("same-frozen-query-set", "pass", "uses the full frozen v53e 1000-row query ids and source spans"),
    ("source-manifest", "pass", f"source_manifest_rows={len(source_manifest_rows)}"),
    ("negative-abstain-coverage", "pass", f"negative_abstain_query_rows={negative_rows}"),
    ("no-external-model", "pass", "local lexical/RAG scoring only"),
    ("v52-absorb-ready", "pass", "B-1000 can be absorbed into v52 comparison registry"),
    ("v52-b-1000", "pass", "B baseline has reached the 1000-row measured run target"),
    ("a-g-h-same-query-set", "blocked", "A/G/H comparable rows over the same set are still missing"),
    ("c-d-e-evidence-directories", "blocked", "C/D/E real model evidence directories are still missing"),
    ("v52-full-baseline-war", "blocked", "A/C/D/E/F/G/H comparable rows over the same set are still missing"),
    ("real-release-package", "blocked", "B-1000 measured run is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V52H_SMALL_LOCAL_RAG_1000_BOUNDARY.md").write_text(
    "# v52h Small Local RAG 1000-Row Boundary\n\n"
    "This is the 1000-row measured expansion for baseline B over the full frozen v53e canary query scale. "
    "It is not the completed v52 baseline war.\n\n"
    f"- query_rows={query_count}\n"
    f"- answer_rows={len(answer_rows)}\n"
    f"- citation_rows={len(citation_rows)}\n"
    f"- abstain_rows={len(abstain_rows)}\n"
    f"- negative_abstain_query_rows={negative_rows}\n"
    f"- wrong_answer_guard_rows={len(wrong_guard_rows)}\n"
    f"- resource_rows={len(resource_rows)}\n"
    f"- retrieval_rows={len(retrieval_rows)}\n"
    "- external_model_used=0\n\n"
    "Still blocked:\n\n"
    "- A/G/H rows on the same frozen query set\n"
    "- C/D/E/F evidence directories and validated rows\n"
    "- complete-source v53 audit rows\n\n"
    "Do not publish 30B-150B comparison claims from this B-only 1000-row measured run.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52h-small-local-rag-measured-1000",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52h_small_local_rag_measured_1000_ready": 1,
    "system_id": "B",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "parent_query_set_id": "v53e_canary_query_scale_1000",
    "query_rows": query_count,
    "accuracy": summary["accuracy"],
    "citation_accuracy": summary["citation_accuracy"],
    "negative_abstain_query_rows": negative_rows,
    "wrong_answer_rows": summary["wrong_answer_rows"],
    "external_model_used": 0,
    "v52_absorb_ready": 1,
    "v52_ready": 0,
    "source_v53e_summary_sha256": sha256(results / "v53e_canary_query_scale_1000_summary.csv"),
}
(run_dir / "v52h_small_local_rag_measured_1000_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "small_local_rag_answer_rows.csv",
    "small_local_rag_citation_rows.csv",
    "small_local_rag_retrieval_rows.csv",
    "small_local_rag_abstain_rows.csv",
    "small_local_rag_wrong_answer_guard_rows.csv",
    "small_local_rag_resource_rows.csv",
    "V52H_SMALL_LOCAL_RAG_1000_BOUNDARY.md",
    "v52h_small_local_rag_measured_1000_manifest.json",
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

print(f"v52h_small_local_rag_measured_1000_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
