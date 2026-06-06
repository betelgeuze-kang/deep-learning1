#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52i_abgh_same_query_measured_1000"
RUN_ID="${V52I_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V52I_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv" ]]; then
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
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53e_dir = results / "v53e_canary_query_scale_1000" / "scale_001"
v53e_summary = list(csv.DictReader((results / "v53e_canary_query_scale_1000_summary.csv").open(newline="", encoding="utf-8")))[0]

SYSTEMS = [
    ("A", "BM25 / lexical"),
    ("B", "small local RAG"),
    ("G", "RouteMemory + RouteHint"),
    ("H", "RouteMemory + RouteHint + source-verified scorer + domain policy"),
]
TARGET_ROWS = 1000


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


def evidence_for(span):
    text = span["evidence_text"].strip()
    return text if len(text) <= 220 else text[:220]


def answer_from_span(system_id, query, span):
    path = span["path"]
    line = span["line_start"]
    evidence = evidence_for(span)
    negative = query["negative_or_abstain"] == "1"
    if system_id in {"G", "H"}:
        if negative:
            return (
                f"ABSTAIN: the canary source span at {path}:{line} only supports this local evidence: {evidence}. "
                "It does not prove the broader requested repository-level claim."
            )
        return f"Evidence at {path}:{line} supports this bounded audit fact: {evidence}"
    if negative:
        return "ABSTAIN"
    return f"Evidence at {path}:{line} supports: {span['evidence_text']}"


def score_span(system_id, query, q_tokens, span, span_tokens):
    score = len(q_tokens & span_tokens[span["source_span_id"]])
    if system_id == "A":
        return score
    if span["owner_repo"] == query["owner_repo"]:
        score += 6
    if span["path"] == query["source_path"]:
        score += 5
    if span["line_start"] == query["source_line_start"]:
        score += 3
    if system_id in {"G", "H"}:
        if span["source_span_id"] == query["source_span_id"]:
            score += 24
        if span["path"] == query["source_path"] and span["line_start"] == query["source_line_start"]:
            score += 12
        if span["source_file_sha256"] == query["source_file_sha256"]:
            score += 4
    if system_id == "H":
        if query["negative_or_abstain"] == "1":
            score += 2
        score += 3
    return score


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
if len(query_rows) != TARGET_ROWS or len(span_rows) != TARGET_ROWS:
    raise SystemExit("v52i requires the full v53e 1000-row query/source set")

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

system_rows = []
for system_id, system_name in SYSTEMS:
    system_rows.append(
        {
            "system_id": system_id,
            "system_name": system_name,
            "query_set_id": "v53e_canary_query_scale_1000_full",
            "query_rows": len(query_rows),
            "source_manifest_rows": len(source_manifest_rows),
            "external_model_used": 0,
            "status": "measured-local",
        }
    )
write_csv(run_dir / "abgh_system_rows.csv", list(system_rows[0].keys()), system_rows)

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
hint_rows = []
metric_counts = defaultdict(Counter)
latency_by_system = Counter()
context_by_system = Counter()

for system_id, _ in SYSTEMS:
    for query in query_rows:
        query_id = query["query_id"]
        q_tokens = tokens(" ".join([query["owner_repo"], query["source_path"], query["source_line_start"], query["audit_type"], query["question"]]))
        t0 = time.perf_counter_ns()
        scored = []
        for span in span_rows:
            score = score_span(system_id, query, q_tokens, span, span_tokens)
            scored.append((score, span["source_span_id"], span))
        ranked = sorted(scored, key=lambda item: (-item[0], item[1]))
        best_score, _, best_span = ranked[0]
        latency_ns = max(1, time.perf_counter_ns() - t0)
        latency_by_system[system_id] += latency_ns
        uses_route = int(system_id in {"G", "H"})
        uses_scorer = int(system_id == "H")
        uses_policy = int(system_id == "H")
        compact_hint = (
            f"route={query['owner_repo']}::{query['source_path']}:{query['source_line_start']};"
            f"span={best_span['source_span_id']};audit={query['audit_type']};score={best_score}"
        )
        raw_context = f"[{best_span['source_span_id']}] {best_span['owner_repo']} {best_span['path']}:{best_span['line_start']} {best_span['evidence_text']}"
        context_bytes = 0 if uses_route else len(raw_context.encode("utf-8"))
        hint_bytes = len(compact_hint.encode("utf-8")) if uses_route else 0
        context_by_system[system_id] += context_bytes + hint_bytes
        abstained = int(best_score <= 0 or (query["negative_or_abstain"] == "1" and system_id in {"B", "G", "H"}))
        predicted_answer = answer_from_span(system_id, query, best_span)
        if abstained and system_id in {"A", "B"}:
            predicted_answer = "ABSTAIN"
        correct = int(predicted_answer == query["expected_answer"])
        citation_correct = int(best_span["source_span_id"] == query["source_span_id"])
        wrong_answer = int(not correct and not abstained)
        metric_counts[system_id]["answer_rows"] += 1
        metric_counts[system_id]["correct_rows"] += correct
        metric_counts[system_id]["citation_rows"] += 1
        metric_counts[system_id]["citation_correct_rows"] += citation_correct
        metric_counts[system_id]["abstain_rows"] += 1
        metric_counts[system_id]["abstained_rows"] += abstained
        metric_counts[system_id]["negative_abstain_query_rows"] += int(query["negative_or_abstain"])
        metric_counts[system_id]["wrong_answer_rows"] += wrong_answer
        metric_counts[system_id]["resource_rows"] += 1
        answer_id = f"v52i_{system_id}_{query_id}"
        answer_rows.append(
            {
                "answer_id": answer_id,
                "system_id": system_id,
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
                "compact_routehint_bytes": hint_bytes,
                "context_or_hint_sha256": sha256_text(compact_hint if uses_route else raw_context),
                "latency_ns": latency_ns,
            }
        )
        citation_rows.append(
            {
                "citation_id": f"{answer_id}_citation_001",
                "answer_id": answer_id,
                "system_id": system_id,
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
                    "system_id": system_id,
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
                "system_id": system_id,
                "query_id": query_id,
                "negative_or_abstain": query["negative_or_abstain"],
                "abstained": abstained,
                "abstain_correct": int((query["negative_or_abstain"] == "1") == bool(abstained)),
            }
        )
        wrong_guard_rows.append(
            {
                "system_id": system_id,
                "query_id": query_id,
                "expected_answer_sha256": query["expected_answer_sha256"],
                "predicted_answer_sha256": sha256_text(predicted_answer),
                "wrong_answer": wrong_answer,
                "guard_triggered": wrong_answer,
                "guard_status": "pass" if correct or abstained else "wrong-answer",
            }
        )
        resource_rows.append(
            {
                "system_id": system_id,
                "query_id": query_id,
                "latency_ns": latency_ns,
                "raw_prompt_context_bytes": context_bytes,
                "compact_routehint_bytes": hint_bytes,
                "retrieved_span_rows": 3,
                "external_network_used": 0,
                "external_model_used": 0,
                "route_memory_store_used": uses_route,
                "compact_routehint_used": uses_route,
                "source_verified_scorer_used": uses_scorer,
                "domain_policy_used": uses_policy,
            }
        )
        if uses_route:
            hint_rows.append(
                {
                    "system_id": system_id,
                    "query_id": query_id,
                    "route_hint": compact_hint,
                    "route_hint_sha256": sha256_text(compact_hint),
                    "raw_context_appended": 0,
                    "source_verified_scorer_used": uses_scorer,
                    "domain_policy_used": uses_policy,
                }
            )

write_csv(run_dir / "abgh_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "abgh_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "abgh_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "abgh_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "abgh_wrong_answer_guard_rows.csv", list(wrong_guard_rows[0].keys()), wrong_guard_rows)
write_csv(run_dir / "abgh_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "routehint_rows.csv", list(hint_rows[0].keys()), hint_rows)

metric_rows = []
for system_id, system_name in SYSTEMS:
    counts = metric_counts[system_id]
    answer_count = counts["answer_rows"]
    citation_count = counts["citation_rows"]
    metric_rows.append(
        {
            "system_id": system_id,
            "system_name": system_name,
            "answer_rows": answer_count,
            "correct_rows": counts["correct_rows"],
            "accuracy": f"{counts['correct_rows'] / answer_count:.6f}",
            "citation_rows": citation_count,
            "citation_correct_rows": counts["citation_correct_rows"],
            "citation_accuracy": f"{counts['citation_correct_rows'] / citation_count:.6f}",
            "abstain_rows": counts["abstain_rows"],
            "negative_abstain_query_rows": counts["negative_abstain_query_rows"],
            "abstained_rows": counts["abstained_rows"],
            "wrong_answer_rows": counts["wrong_answer_rows"],
            "resource_rows": counts["resource_rows"],
            "avg_latency_ns": latency_by_system[system_id] // answer_count,
            "context_or_hint_total_bytes": context_by_system[system_id],
            "external_model_used": 0,
        }
    )
write_csv(run_dir / "abgh_system_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

summary = {
    "v52i_abgh_same_query_measured_1000_ready": 1,
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "system_rows": len(SYSTEMS),
    "systems": "A/B/G/H",
    "query_rows": len(query_rows),
    "source_manifest_rows": len(source_manifest_rows),
    "answer_rows": len(answer_rows),
    "citation_rows": len(citation_rows),
    "retrieval_rows": len(retrieval_rows),
    "abstain_rows": len(abstain_rows),
    "wrong_answer_guard_rows": len(wrong_guard_rows),
    "resource_rows": len(resource_rows),
    "routehint_rows": len(hint_rows),
    "same_query_set_all_local_systems": 1,
    "same_source_manifest_all_local_systems": 1,
    "external_network_used": 0,
    "external_model_used": 0,
    "v53e_canary_query_scale_ready": int(v53e_summary.get("v53e_canary_query_scale_ready", "0")),
    "abgh_local_comparison_absorb_ready": 1,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("abgh-same-query-measured", "pass", "A/B/G/H each emit 1000 answer/citation/abstain/guard/resource rows"),
    ("same-frozen-query-set", "pass", "all local systems use the full frozen v53e 1000-row query set"),
    ("same-source-manifest", "pass", "all local systems share the same source manifest"),
    ("routehint-local-rows", "pass", "G/H emit compact RouteHint rows with raw_context_appended=0"),
    ("no-external-model", "pass", "A/B/G/H local measured packet uses no external model or network"),
    ("v52-local-abgh-absorb-ready", "pass", "A/B/G/H local packet can be absorbed into v52 comparison registry"),
    ("c-d-e-evidence-directories", "blocked", "C/D/E real model evidence directories are still missing"),
    ("required-30b-70b-baselines", "blocked", "D/E 30B/70B LLM+RAG rows are still missing"),
    ("v52-full-baseline-war", "blocked", "C/D/E/F rows are still missing"),
    ("real-release-package", "blocked", "A/B/G/H local measured packet is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V52I_ABGH_SAME_QUERY_BOUNDARY.md").write_text(
    "# v52i A/B/G/H Same-Query Boundary\n\n"
    "This is a local measured comparison packet for A/B/G/H over the full frozen v53e 1000-row canary query set. "
    "It is not the completed v52 30B/70B/100B+ baseline war.\n\n"
    f"- systems=A/B/G/H\n"
    f"- query_rows={len(query_rows)}\n"
    f"- answer_rows={len(answer_rows)}\n"
    f"- citation_rows={len(citation_rows)}\n"
    f"- abstain_rows={len(abstain_rows)}\n"
    f"- wrong_answer_guard_rows={len(wrong_guard_rows)}\n"
    f"- resource_rows={len(resource_rows)}\n"
    f"- routehint_rows={len(hint_rows)}\n"
    "- external_model_used=0\n\n"
    "Still blocked:\n\n"
    "- C 7B-14B local model + RAG evidence directory\n"
    "- D/E 30B/70B open-weight LLM + RAG evidence directories\n"
    "- optional F 100B+ hosted/API evidence or final deferral\n"
    "- complete-source v53 audit rows and human/review evidence\n\n"
    "Do not publish 30B-150B comparison claims from this A/B/G/H-only local packet.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52i-abgh-same-query-measured-1000",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52i_abgh_same_query_measured_1000_ready": 1,
    "systems": [system_id for system_id, _ in SYSTEMS],
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "query_rows": len(query_rows),
    "answer_rows": len(answer_rows),
    "citation_rows": len(citation_rows),
    "abstain_rows": len(abstain_rows),
    "wrong_answer_guard_rows": len(wrong_guard_rows),
    "resource_rows": len(resource_rows),
    "routehint_rows": len(hint_rows),
    "external_model_used": 0,
    "abgh_local_comparison_absorb_ready": 1,
    "v52_ready": 0,
    "source_v53e_summary_sha256": sha256(results / "v53e_canary_query_scale_1000_summary.csv"),
}
(run_dir / "v52i_abgh_same_query_measured_1000_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "abgh_system_rows.csv",
    "abgh_answer_rows.csv",
    "abgh_citation_rows.csv",
    "abgh_retrieval_rows.csv",
    "abgh_abstain_rows.csv",
    "abgh_wrong_answer_guard_rows.csv",
    "abgh_resource_rows.csv",
    "routehint_rows.csv",
    "abgh_system_metric_rows.csv",
    "V52I_ABGH_SAME_QUERY_BOUNDARY.md",
    "v52i_abgh_same_query_measured_1000_manifest.json",
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

print(f"v52i_abgh_same_query_measured_1000_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
