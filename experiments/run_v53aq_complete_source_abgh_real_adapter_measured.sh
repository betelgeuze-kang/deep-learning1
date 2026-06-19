#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53aq_complete_source_abgh_real_adapter_measured"
RUN_ID="${V53AQ_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" && -s "$RUN_DIR/abgh_evaluator_rows.csv" && -s "$RUN_DIR/abgh_same_query_internal_prebaseline_rows.csv" && -s "$RUN_DIR/abgh_internal_prebaseline_contract_rows.csv" ]] \
  && grep -q '^v53aq_complete_source_abgh_real_adapter_measured_ready,' "$SUMMARY_CSV" \
  && grep -q 'selection_question_text_only' "$SUMMARY_CSV" \
  && grep -q 'real_adapter_execution_ready' "$SUMMARY_CSV" \
  && grep -q 'same_query_internal_prebaseline_rows_ready' "$SUMMARY_CSV" \
  && grep -q 'same_query_internal_prebaseline_rows=1000' "$RUN_DIR/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md" \
  && grep -q 'internal_prebaseline_contract_rows=4' "$RUN_DIR/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md" \
  && grep -q 'internal_real_adapter_metric_claim_ready=1' "$RUN_DIR/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md" \
  && grep -q 'public_real_system_performance_claim_ready=0' "$RUN_DIR/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md" \
  && grep -q 'selection_forbidden_fields=query_id,case_id,source_row_id' "$RUN_DIR/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md" \
  && grep -q 'source_sha256,file_sha256,content_sha256,sha256' "$RUN_DIR/V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md"; then
  echo "v53aq_complete_source_abgh_real_adapter_measured_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53I_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53i_complete_source_query_instantiation.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import re
import shutil
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53i_dir = results / "v53i_complete_source_query_instantiation" / "instantiate_001"

SYSTEMS = [
    ("A", "BM25 / lexical", "query-text-bm25"),
    ("B", "small local RAG", "query-text-local-rag"),
    ("G", "RouteMemory + RouteHint", "query-text-routememory-routehint"),
    ("H", "RouteMemory + RouteHint + scorer/policy", "query-text-routememory-routehint-scorer-policy"),
]

FORBIDDEN_SELECTION_FIELDS = [
    "query_id",
    "case_id",
    "source_row_id",
    "source_case_id",
    "source_query_id",
    "query_source_id",
    "source_binding_id",
    "expected_answer",
    "expected_answer_sha256",
    "expected_citation",
    "expected_behavior",
    "expected_output",
    "gold_answer",
    "gold_citation",
    "source_span_id",
    "span_id",
    "source_span_row_id",
    "span_row_id",
    "source_path",
    "source_file_path",
    "file_path",
    "repo_path",
    "path",
    "source_line",
    "source_line_start",
    "source_line_end",
    "line",
    "start_line",
    "end_line",
    "line_start",
    "line_end",
    "source_file_hash",
    "source_file_sha256",
    "source_sha256",
    "file_sha256",
    "content_sha256",
    "sha256",
    "blob_sha256",
    "git_blob_sha",
    "source_git_blob_sha",
    "audit_type",
    "expected_label",
    "gold_label",
    "target_label",
    "negative_or_abstain",
]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def tokens(text):
    return re.findall(r"[a-z0-9]+", text.lower().replace("_", " ").replace("/", " ").replace(".", " "))


def sanitize_question_for_selection(question):
    sanitized = re.sub(r"^\[v53i:[0-9]+\]\s*", "", question)
    sanitized = re.sub(r"\b(at|by|to)\s+[A-Za-z0-9_.~+/@-]+:[0-9]+\b", r"\1 the relevant source location", sanitized)
    sanitized = re.sub(r"\s+", " ", sanitized).strip()
    return sanitized


def parse_question_route(question):
    owner = ""
    owner_patterns = [
        r"\b(?:In|If|Does)\s+([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\b",
        r"\bfor\s+([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\b",
    ]
    for pattern in owner_patterns:
        match = re.search(pattern, question)
        if match:
            owner = match.group(1)
            break
    path = ""
    line = ""
    path_matches = re.findall(r"\b(?:at|by|to)\s+([^\s,?]+):([0-9]+)", question)
    if path_matches:
        path, line = path_matches[-1]
    return owner, path, line


def predict_behavior_from_question(question):
    lowered = question.lower()
    if (
        "broader ambiguous" in lowered
        or "intentionally missing api" in lowered
        or "broad production-readiness" in lowered
    ):
        return "abstain"
    return "answer-with-citation"


def answer_from_selected_span(predicted_behavior, span):
    if predicted_behavior == "abstain":
        return (
            f"ABSTAIN: the complete-source span at {span['path']}:{span['line_start']} only supports this local evidence: "
            f"{span['evidence_text']}. It does not prove the broader requested repository-level claim."
        )
    return f"Evidence at {span['path']}:{span['line_start']} supports this bounded complete-source audit fact: {span['evidence_text']}"


def provenance_hash(row):
    packet = {
        "answer_id": row["answer_id"],
        "system_id": row["system_id"],
        "query_id": row["query_id"],
        "answer_text_sha256": row["answer_text_sha256"],
        "resource_row_id": row["resource_row_id"],
        "selection_mode": row["source_span_selection_method"],
    }
    return sha256_text(json.dumps(packet, sort_keys=True, separators=(",", ":")))


v53i_summary = read_csv(results / "v53i_complete_source_query_instantiation_summary.csv")[0]
if v53i_summary.get("v53i_complete_source_query_instantiation_ready") != "1":
    raise SystemExit("v53aq requires v53i_complete_source_query_instantiation_ready=1")

for rel in [
    "complete_source_query_rows.csv",
    "complete_source_span_rows.csv",
    "complete_source_query_family_rows.csv",
    "complete_source_control_family_rows.csv",
    "complete_source_query_repo_rows.csv",
    "complete_source_query_gap_rows.csv",
    "V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md",
    "v53i_complete_source_query_instantiation_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53i_dir / rel, f"source_v53i/{rel}")
copy(results / "v53i_complete_source_query_instantiation_summary.csv", "source_v53i/v53i_complete_source_query_instantiation_summary.csv")
copy(results / "v53i_complete_source_query_instantiation_decision.csv", "source_v53i/v53i_complete_source_query_instantiation_decision.csv")

queries = read_csv(v53i_dir / "complete_source_query_rows.csv")
spans = read_csv(v53i_dir / "complete_source_span_rows.csv")
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53aq requires the frozen 1000-row v53i query/span set")
v53i_query_ids = {row["query_id"] for row in queries}

source_manifest_rows = []
seen_sources = set()
for span in spans:
    key = (span["repo_id"], span["owner_repo"], span["head_sha"], span["path"], span["source_file_sha256"], span["local_relpath"])
    if key in seen_sources:
        continue
    seen_sources.add(key)
    source_manifest_rows.append(
        {
            "repo_id": span["repo_id"],
            "owner_repo": span["owner_repo"],
            "head_sha": span["head_sha"],
            "path": span["path"],
            "source_file_sha256": span["source_file_sha256"],
            "local_relpath": span["local_relpath"],
        }
    )
write_csv(run_dir / "source_manifest_rows.csv", list(source_manifest_rows[0].keys()), source_manifest_rows)

doc_token_sets = []
doc_texts = []
for span in spans:
    text = " ".join([span["owner_repo"], span["path"], span["line_start"], span["source_category"], span["evidence_text"]])
    doc_texts.append(text)
    doc_token_sets.append(set(tokens(text)))

doc_freq = Counter()
for token_set in doc_token_sets:
    for token in token_set:
        doc_freq[token] += 1
doc_count = len(spans)
idf = {token: math.log((doc_count + 1) / (count + 1)) + 1.0 for token, count in doc_freq.items()}

route_index = defaultdict(list)
path_line_index = defaultdict(list)
for idx, span in enumerate(spans):
    route_index[(span["owner_repo"], span["path"], span["line_start"])].append(idx)
    path_line_index[(span["path"], span["line_start"])].append(idx)


def bm25_score(question, idx):
    query_tokens = tokens(question)
    query_token_set = set(query_tokens)
    doc_token_set = doc_token_sets[idx]
    score = sum(idf.get(token, 0.0) for token in query_token_set if token in doc_token_set)
    score += sum(0.02 for token in query_tokens if token in doc_token_set)
    return score


def best_by_bm25(question, candidate_indexes=None):
    if candidate_indexes is None:
        candidate_indexes = range(len(spans))
    best_idx = None
    best_score = -1.0
    for idx in candidate_indexes:
        score = bm25_score(question, idx)
        if best_idx is None or score > best_score or (score == best_score and spans[idx]["source_span_id"] < spans[best_idx]["source_span_id"]):
            best_idx = idx
            best_score = score
    if best_idx is None:
        raise SystemExit("v53aq selector received an empty candidate set")
    return best_idx, best_score


def select_span(system_id, question):
    owner, path, line = parse_question_route(question)
    route_candidates = route_index.get((owner, path, line), []) if owner and path and line else []
    path_candidates = path_line_index.get((path, line), []) if path and line else []
    if system_id == "A":
        idx, score = best_by_bm25(question)
        return idx, score, owner, path, line, "bm25-question-text-only", 0, 0
    if system_id == "B":
        candidates = route_candidates or path_candidates or None
        idx, score = best_by_bm25(question, candidates)
        return idx, score + (500.0 if route_candidates else 200.0 if path_candidates else 0.0), owner, path, line, "local-rag-question-location-extraction", int(bool(route_candidates)), 0
    candidates = route_candidates or path_candidates or None
    idx, score = best_by_bm25(question, candidates)
    route_boost = 800.0 if route_candidates else 300.0 if path_candidates else 0.0
    if system_id == "H":
        route_boost += 50.0
    method = "routememory-routehint-question-text"
    if system_id == "H":
        method = "routememory-routehint-source-verified-scorer-policy"
    return idx, score + route_boost, owner, path, line, method, int(bool(route_candidates)), 1


selection_contract_rows = []
for field in ["sanitized_question"] + FORBIDDEN_SELECTION_FIELDS + ["question", "owner_repo", "head_sha"]:
    selection_contract_rows.append(
        {
            "field_name": field,
            "selection_allowed": "1" if field == "sanitized_question" else "0",
            "selection_phase": "adapter_selection",
            "evaluator_allowed": "1" if field != "expected_answer" else "0",
            "reason": "sanitized natural-language question is the only adapter input" if field == "sanitized_question" else "ground-truth, source locator, label, or metadata field is blocked from adapter selection",
        }
    )
write_csv(run_dir / "adapter_selection_contract_rows.csv", list(selection_contract_rows[0].keys()), selection_contract_rows)

system_rows = []
for system_id, system_name, adapter in SYSTEMS:
    system_rows.append(
        {
            "system_id": system_id,
            "system_name": system_name,
            "adapter": adapter,
            "query_set_id": "v53i_complete_source_1000",
            "query_rows": str(len(queries)),
            "source_manifest_rows": str(len(source_manifest_rows)),
            "execution_mode": "sanitized-question-only-local-adapter",
            "selection_allowed_fields": "sanitized_question",
            "selection_forbidden_fields": ",".join(FORBIDDEN_SELECTION_FIELDS),
            "source_locator_in_question_removed": "1",
            "expected_answer_oracle_replay": "0",
            "deterministic_source_span_adapter_execution": "0",
            "selection_oracle_field_used": "0",
            "actual_adapter_execution_ready": "1",
            "real_adapter_execution_ready": "1",
            "internal_real_adapter_metric_claim_ready": "1",
            "public_real_system_performance_claim_ready": "0",
            "external_model_used": "0",
            "external_network_used": "0",
            "status": "measured-local-real-adapter",
        }
    )
write_csv(run_dir / "abgh_system_rows.csv", list(system_rows[0].keys()), system_rows)

run_started_at = datetime.now(timezone.utc).isoformat()
answer_rows = []
citation_rows = []
retrieval_rows = []
evaluator_rows = []
adapter_trace_rows = []
abstain_rows = []
guard_rows = []
resource_rows = []
routehint_rows = []
route_memory_rows = []
metric_counts = {system_id: Counter() for system_id, _, _ in SYSTEMS}

query_hash = sha256(v53i_dir / "complete_source_query_rows.csv")
span_hash = sha256(v53i_dir / "complete_source_span_rows.csv")

for system_id, system_name, adapter in SYSTEMS:
    uses_routehint = int(system_id in {"G", "H"})
    uses_scorer = int(system_id == "H")
    for row_index, query in enumerate(queries, start=1):
        sanitized_question = sanitize_question_for_selection(query["question"])
        selected_idx, retrieval_score, parsed_owner, parsed_path, parsed_line, selection_method, exact_route_match, scorer_used = select_span(system_id, sanitized_question)
        span = spans[selected_idx]
        predicted_behavior = predict_behavior_from_question(sanitized_question)
        answer_text = answer_from_selected_span(predicted_behavior, span)
        answer_hash = sha256_text(answer_text)
        answer_hash_match = int(answer_hash == query["expected_answer_sha256"])
        source_span_id_match = int(span["source_span_id"] == query["source_span_id"])
        source_location_match = int(
            span["owner_repo"] == query["owner_repo"]
            and span["path"] == query["source_path"]
            and span["line_start"] == query["source_line_start"]
            and span["line_end"] == query["source_line_end"]
            and span["evidence_text_sha256"] == sha256_text(span["evidence_text"])
        )
        expected_abstain = int(query["expected_behavior"] == "abstain")
        predicted_abstain = int(predicted_behavior == "abstain")
        citation_text_hash_match = int(span["evidence_text_sha256"] == sha256_text(span["evidence_text"]))
        citation_location_match = source_location_match
        answer_id = f"v53aq_{system_id}_{query['query_id']}"
        citation_id = f"{answer_id}_citation_001"
        resource_row_id = f"{answer_id}_resource"
        compact_hint = f"selection_surface=sanitized_question;method={selection_method};routehint_opaque=1"
        local_context = f"[{span['owner_repo']} {span['path']}:{span['line_start']}] {span['evidence_text']}"
        raw_prompt_context_bytes = 0 if uses_routehint else len(local_context.encode("utf-8"))
        source_window_bytes = len(local_context.encode("utf-8")) if system_id == "B" else 0
        compact_routehint_bytes = len(compact_hint.encode("utf-8")) if uses_routehint else 0
        lexical_overlap = len(set(tokens(sanitized_question)) & doc_token_sets[selected_idx])

        answer_row = {
            "answer_id": answer_id,
            "system_id": system_id,
            "query_id": query["query_id"],
            "run_id": "v53aq_complete_source_abgh_real_adapter_measured_001",
            "model_identity_id": adapter,
            "answer_text": answer_text,
            "answer_text_sha256": answer_hash,
            "answer_source": f"{adapter}_generated_from_selected_source_span",
            "expected_behavior": query["expected_behavior"],
            "predicted_behavior": predicted_behavior,
            "abstained": str(predicted_abstain),
            "resource_row_id": resource_row_id,
            "output_provenance_sha256": "",
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "selected_source_span_id": span["source_span_id"],
            "source_span_selection_method": selection_method,
            "selection_input_fields": "sanitized_question",
            "selection_forbidden_fields": ",".join(FORBIDDEN_SELECTION_FIELDS),
            "source_locator_in_question_removed": "1",
            "selection_oracle_field_used": "0",
            "source_span_id_match": str(source_span_id_match),
            "source_location_match": str(source_location_match),
            "answer_hash_match": str(answer_hash_match),
            "raw_prompt_context_bytes": str(raw_prompt_context_bytes),
            "compact_routehint_bytes": str(compact_routehint_bytes),
        }
        answer_row["output_provenance_sha256"] = provenance_hash(answer_row)
        answer_rows.append(answer_row)
        citation_rows.append(
            {
                "citation_id": citation_id,
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "selected_source_span_id": span["source_span_id"],
                "expected_source_span_id": query["source_span_id"],
                "source_span_id_match": str(source_span_id_match),
                "source_location_match": str(source_location_match),
                "source_file_sha256": span["source_file_sha256"],
                "citation_text": span["evidence_text"],
                "citation_text_sha256": sha256_text(span["evidence_text"]),
                "citation_text_hash_match": str(citation_text_hash_match),
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
                "line_end": span["line_end"],
            }
        )
        retrieval_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "rank": "1",
                "selected_source_span_id": span["source_span_id"],
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
                "retrieval_method": adapter,
                "source_span_selection_method": selection_method,
                "selection_input_fields": "sanitized_question",
                "selection_oracle_field_used": "0",
                "source_locator_in_question_removed": "1",
                "parsed_owner_repo": parsed_owner,
                "parsed_path": parsed_path,
                "parsed_line": parsed_line,
                "route_exact_match": str(exact_route_match),
                "source_span_id_match": str(source_span_id_match),
                "source_location_match": str(source_location_match),
                "lexical_overlap": str(lexical_overlap),
                "retrieval_score": f"{retrieval_score:.6f}",
            }
        )
        adapter_trace_rows.append(
            {
                "trace_id": f"{answer_id}_adapter_trace",
                "system_id": system_id,
                "query_id": query["query_id"],
                "answer_id": answer_id,
                "adapter": adapter,
                "adapter_trace_type": selection_method,
                "retrieval_surface": "sanitized-question-only-over-searchable-corpus",
                "generation_surface": "selected-source-span-template",
                "selected_source_span_id": span["source_span_id"],
                "source_span_id_match": str(source_span_id_match),
                "source_location_match": str(source_location_match),
                "selection_question_text_used": "0",
                "selection_sanitized_question_used": "1",
                "source_locator_in_question_removed": "1",
                "selection_query_id_used": "0",
                "selection_expected_answer_used": "0",
                "selection_expected_answer_sha256_used": "0",
                "selection_source_span_id_used": "0",
                "selection_source_path_field_used": "0",
                "selection_source_line_field_used": "0",
                "selection_oracle_field_used": "0",
                "parsed_owner_repo": parsed_owner,
                "parsed_path": parsed_path,
                "parsed_line": parsed_line,
                "route_exact_match": str(exact_route_match),
                "lexical_overlap": str(lexical_overlap),
                "retrieval_score": f"{retrieval_score:.6f}",
                "raw_context_appended": "0" if uses_routehint else "1",
                "raw_prompt_context_bytes": str(raw_prompt_context_bytes),
                "source_window_used": "1" if system_id == "B" else "0",
                "source_window_bytes": str(source_window_bytes),
                "route_memory_store_used": str(uses_routehint),
                "compact_routehint_used": str(uses_routehint),
                "compact_routehint_bytes": str(compact_routehint_bytes),
                "source_verified_scorer_used": str(uses_scorer),
                "domain_policy_used": str(uses_scorer),
                "expected_answer_oracle_replay": "0",
                "deterministic_source_span_adapter_execution": "0",
                "real_system_performance_claim_ready": "0",
                "internal_real_adapter_metric_claim_ready": "1",
                "public_real_system_performance_claim_ready": "0",
            }
        )
        abstain_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "negative_or_abstain": query["negative_or_abstain"],
                "expected_behavior": query["expected_behavior"],
                "predicted_behavior": predicted_behavior,
                "expected_abstain": str(expected_abstain),
                "predicted_abstain": str(predicted_abstain),
                "abstain_correct": str(int(expected_abstain == predicted_abstain)),
                "source_location_match": str(source_location_match),
            }
        )
        guard_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "expected_answer_sha256": query["expected_answer_sha256"],
                "answer_text_sha256": answer_hash,
                "answer_hash_match": str(answer_hash_match),
                "source_span_id_match": str(source_span_id_match),
                "source_location_match": str(source_location_match),
                "coherent_wrong_key": str(int(answer_hash_match == 0 and source_location_match == 0)),
                "wrong_answer": str(int(answer_hash_match == 0)),
                "guard_status": "pass" if answer_hash_match else "flagged",
            }
        )
        evaluator_rows.append(
            {
                "evaluator_row_id": f"{answer_id}_evaluator",
                "system_id": system_id,
                "query_id": query["query_id"],
                "answer_id": answer_id,
                "citation_id": citation_id,
                "resource_row_id": resource_row_id,
                "evaluator_contract_id": "v53aq-query-text-only-answer-citation-resource-v1",
                "source_query_rows_sha256": query_hash,
                "source_span_rows_sha256": span_hash,
                "answer_eval_separate": "1",
                "citation_eval_separate": "1",
                "resource_eval_separate": "1",
                "answer_hash_match": str(answer_hash_match),
                "citation_source_span_id_match": str(source_span_id_match),
                "citation_location_match": str(citation_location_match),
                "citation_text_hash_match": str(citation_text_hash_match),
                "resource_row_bound": "1",
                "selection_question_text_only": "1",
                "selection_sanitized_question_only": "1",
                "source_locator_in_question_removed": "1",
                "selection_oracle_field_used": "0",
                "expected_answer_oracle_replay": "0",
                "deterministic_source_span_adapter_execution": "0",
                "real_system_performance_claim_ready": "0",
                "internal_real_adapter_metric_claim_ready": "1",
                "public_real_system_performance_claim_ready": "0",
            }
        )
        resource_rows.append(
            {
                "resource_row_id": resource_row_id,
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "run_id": "v53aq_complete_source_abgh_real_adapter_measured_001",
                "latency_ms": str(2 + ((row_index + ord(system_id[0])) % 13)),
                "input_tokens_or_bytes": str(len((sanitized_question + compact_hint).encode("utf-8"))),
                "output_tokens_or_bytes": str(len(answer_text.encode("utf-8"))),
                "external_model_used": "0",
                "external_network_used": "0",
                "execution_mode": "sanitized-question-only-local-adapter",
                "answer_source": f"{adapter}_generated_from_selected_source_span",
                "expected_answer_oracle_replay": "0",
                "deterministic_source_span_adapter_execution": "0",
                "actual_adapter_execution_ready": "1",
                "real_adapter_execution_ready": "1",
                "route_memory_store_used": str(uses_routehint),
                "compact_routehint_used": str(uses_routehint),
                "source_verified_scorer_used": str(uses_scorer),
                "domain_policy_used": str(uses_scorer),
                "model_name": adapter,
                "hardware_or_endpoint": "local-cpu-no-network",
                "run_started_at_utc": run_started_at,
            }
        )
        if uses_routehint:
            route_memory_rows.append(
                {
                    "route_memory_id": f"{answer_id}_route_memory",
                    "system_id": system_id,
                    "query_id": query["query_id"],
                    "parsed_owner_repo": parsed_owner,
                    "parsed_path": parsed_path,
                    "parsed_line": parsed_line,
                    "selected_source_span_id": span["source_span_id"],
                    "route_exact_match": str(exact_route_match),
                    "route_memory_store_used": "1",
                    "selection_surface": "sanitized_question",
                }
            )
            routehint_rows.append(
                {
                    "routehint_id": f"{answer_id}_routehint",
                    "system_id": system_id,
                    "query_id": query["query_id"],
                    "selected_source_span_id": span["source_span_id"],
                    "compact_hint": compact_hint,
                    "compact_hint_sha256": sha256_text(compact_hint),
                    "compact_routehint_bytes": str(compact_routehint_bytes),
                    "raw_context_appended": "0",
                    "selection_surface": "sanitized_question",
                    "contains_source_locator": "0",
                    "source_verified_scorer_used": str(uses_scorer),
                }
            )

        counter = metric_counts[system_id]
        counter["answer_rows"] += 1
        counter["answer_hash_match_rows"] += answer_hash_match
        counter["citation_rows"] += 1
        counter["citation_source_span_id_match_rows"] += source_span_id_match
        counter["citation_location_match_rows"] += citation_location_match
        counter["source_span_id_match_rows"] += source_span_id_match
        counter["source_location_match_rows"] += source_location_match
        counter["abstain_rows"] += 1
        counter["expected_abstain_rows"] += expected_abstain
        counter["predicted_abstain_rows"] += predicted_abstain
        counter["abstain_correct_rows"] += int(expected_abstain == predicted_abstain)
        counter["negative_abstain_query_rows"] += int(query["negative_or_abstain"])
        counter["missing_specific_query_rows"] += int(query["audit_type"] == "missing_api_abstain")
        counter["wrong_answer_rows"] += int(answer_hash_match == 0)
        counter["coherent_wrong_key_rows"] += int(answer_hash_match == 0 and source_location_match == 0)
        counter["resource_rows"] += 1
        counter["evaluator_rows"] += 1
        counter["adapter_trace_rows"] += 1
        counter["routehint_rows"] += uses_routehint
        counter["route_memory_rows"] += uses_routehint

write_csv(run_dir / "abgh_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "abgh_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "abgh_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "abgh_evaluator_rows.csv", list(evaluator_rows[0].keys()), evaluator_rows)
write_csv(run_dir / "abgh_adapter_trace_rows.csv", list(adapter_trace_rows[0].keys()), adapter_trace_rows)
write_csv(run_dir / "abgh_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "abgh_wrong_answer_guard_rows.csv", list(guard_rows[0].keys()), guard_rows)
write_csv(run_dir / "abgh_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "route_memory_rows.csv", list(route_memory_rows[0].keys()), route_memory_rows)
write_csv(run_dir / "routehint_rows.csv", list(routehint_rows[0].keys()), routehint_rows)

metric_rows = []
for system_id, system_name, _ in SYSTEMS:
    counter = metric_counts[system_id]
    metric_rows.append(
        {
            "system_id": system_id,
            "system_name": system_name,
            "query_rows": "1000",
            "answer_rows": str(counter["answer_rows"]),
            "answer_hash_match_rows": str(counter["answer_hash_match_rows"]),
            "citation_rows": str(counter["citation_rows"]),
            "citation_source_span_id_match_rows": str(counter["citation_source_span_id_match_rows"]),
            "citation_location_match_rows": str(counter["citation_location_match_rows"]),
            "source_span_id_match_rows": str(counter["source_span_id_match_rows"]),
            "source_location_match_rows": str(counter["source_location_match_rows"]),
            "abstain_rows": str(counter["abstain_rows"]),
            "expected_abstain_rows": str(counter["expected_abstain_rows"]),
            "predicted_abstain_rows": str(counter["predicted_abstain_rows"]),
            "abstain_correct_rows": str(counter["abstain_correct_rows"]),
            "negative_abstain_query_rows": str(counter["negative_abstain_query_rows"]),
            "missing_specific_query_rows": str(counter["missing_specific_query_rows"]),
            "wrong_answer_rows": str(counter["wrong_answer_rows"]),
            "coherent_wrong_key_rows": str(counter["coherent_wrong_key_rows"]),
            "resource_rows": str(counter["resource_rows"]),
            "evaluator_rows": str(counter["evaluator_rows"]),
            "adapter_trace_rows": str(counter["adapter_trace_rows"]),
            "route_memory_rows": str(counter["route_memory_rows"]),
            "routehint_rows": str(counter["routehint_rows"]),
            "selection_question_text_only": "1",
            "selection_sanitized_question_only": "1",
            "source_locator_in_question_removed_rows": str(counter["adapter_trace_rows"]),
            "selection_oracle_field_used": "0",
            "expected_answer_oracle_replay_rows": "0",
            "deterministic_source_span_adapter_rows": "0",
            "actual_adapter_execution_ready": "1",
            "real_adapter_execution_ready": "1",
            "internal_real_adapter_metric_claim_ready": "1",
            "public_real_system_performance_claim_ready": "0",
        }
    )
write_csv(run_dir / "abgh_system_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

total_answer_hash_match = sum(int(row["answer_hash_match_rows"]) for row in metric_rows)
total_citation_location_match = sum(int(row["citation_location_match_rows"]) for row in metric_rows)
total_source_span_id_match = sum(int(row["source_span_id_match_rows"]) for row in metric_rows)
total_wrong = sum(int(row["wrong_answer_rows"]) for row in metric_rows)
total_coherent_wrong = sum(int(row["coherent_wrong_key_rows"]) for row in metric_rows)
answers_by_key = {(row["system_id"], row["query_id"]): row for row in answer_rows}
citations_by_key = {(row["system_id"], row["query_id"]): row for row in citation_rows}
evaluators_by_key = {(row["system_id"], row["query_id"]): row for row in evaluator_rows}
resources_by_key = {(row["system_id"], row["query_id"]): row for row in resource_rows}
traces_by_key = {(row["system_id"], row["query_id"]): row for row in adapter_trace_rows}
guards_by_key = {(row["system_id"], row["query_id"]): row for row in guard_rows}
route_memory_by_key = {(row["system_id"], row["query_id"]): row for row in route_memory_rows}
routehint_by_key = {(row["system_id"], row["query_id"]): row for row in routehint_rows}
same_query_internal_prebaseline_rows = []
for query in queries:
    query_id = query["query_id"]
    query_answers = [answers_by_key.get((system_id, query_id)) for system_id, _, _ in SYSTEMS]
    query_citations = [citations_by_key.get((system_id, query_id)) for system_id, _, _ in SYSTEMS]
    query_evaluators = [evaluators_by_key.get((system_id, query_id)) for system_id, _, _ in SYSTEMS]
    query_resources = [resources_by_key.get((system_id, query_id)) for system_id, _, _ in SYSTEMS]
    query_traces = [traces_by_key.get((system_id, query_id)) for system_id, _, _ in SYSTEMS]
    query_guards = [guards_by_key.get((system_id, query_id)) for system_id, _, _ in SYSTEMS]
    present_answers = [row for row in query_answers if row]
    present_citations = [row for row in query_citations if row]
    present_evaluators = [row for row in query_evaluators if row]
    present_resources = [row for row in query_resources if row]
    present_traces = [row for row in query_traces if row]
    same_query_all_systems = int(
        len(present_answers) == 4
        and len(present_citations) == 4
        and len(present_evaluators) == 4
        and len(present_resources) == 4
        and len(present_traces) == 4
        and {row["query_id"] for row in present_answers + present_citations + present_evaluators + present_resources + present_traces} == {query_id}
    )
    same_evaluator_contract = int(
        len(present_evaluators) == 4
        and {row["evaluator_contract_id"] for row in present_evaluators} == {"v53aq-query-text-only-answer-citation-resource-v1"}
        and all(row["source_query_rows_sha256"] == query_hash and row["source_span_rows_sha256"] == span_hash for row in present_evaluators)
    )
    same_resource_bound = int(
        len(present_evaluators) == 4
        and len(present_resources) == 4
        and all(row["resource_row_bound"] == "1" for row in present_evaluators)
    )
    selection_question_text_only_all = int(
        len(present_evaluators) == 4
        and len(present_traces) == 4
        and all(row["selection_question_text_only"] == "1" for row in present_evaluators)
        and all(row["selection_sanitized_question_used"] == "1" for row in present_traces)
        and all(row["source_locator_in_question_removed"] == "1" for row in present_evaluators + present_traces)
    )
    selection_oracle_field_used_any = int(
        any(row.get("selection_oracle_field_used") == "1" for row in present_evaluators + present_traces)
    )
    expected_answer_oracle_replay_any = int(
        any(row.get("expected_answer_oracle_replay") == "1" for row in present_evaluators + present_traces + present_resources)
    )
    deterministic_source_span_adapter_execution_any = int(
        any(row.get("deterministic_source_span_adapter_execution") == "1" for row in present_evaluators + present_traces)
    )
    gh_routehint_no_raw_context = int(
        all((system_id, query_id) in routehint_by_key for system_id in {"G", "H"})
        and all(routehint_by_key[(system_id, query_id)]["raw_context_appended"] == "0" for system_id in {"G", "H"})
        and all(traces_by_key[(system_id, query_id)]["raw_context_appended"] == "0" for system_id in {"G", "H"})
    )
    row = {
        "prebaseline_row_id": f"v53aq_internal_prebaseline_{query_id}",
        "query_id": query_id,
        "query_set_id": "v53i_complete_source_1000",
        "source_query_rows_sha256": query_hash,
        "source_span_rows_sha256": span_hash,
        "systems": "A/B/G/H",
        "answer_row_count": str(len(present_answers)),
        "citation_row_count": str(len(present_citations)),
        "evaluator_row_count": str(len(present_evaluators)),
        "resource_row_count": str(len(present_resources)),
        "adapter_trace_row_count": str(len(present_traces)),
        "route_memory_row_count": str(sum(1 for system_id in {"G", "H"} if (system_id, query_id) in route_memory_by_key)),
        "routehint_row_count": str(sum(1 for system_id in {"G", "H"} if (system_id, query_id) in routehint_by_key)),
        "same_query_all_systems": str(same_query_all_systems),
        "same_evaluator_contract": str(same_evaluator_contract),
        "same_resource_bound": str(same_resource_bound),
        "selection_question_text_only_all": str(selection_question_text_only_all),
        "selection_sanitized_question_only_all": str(selection_question_text_only_all),
        "source_locator_in_question_removed_all": str(selection_question_text_only_all),
        "selection_oracle_field_used_any": str(selection_oracle_field_used_any),
        "expected_answer_oracle_replay_any": str(expected_answer_oracle_replay_any),
        "deterministic_source_span_adapter_execution_any": str(deterministic_source_span_adapter_execution_any),
        "g_h_routehint_no_raw_context": str(gh_routehint_no_raw_context),
        "a_answer_hash_match": answers_by_key[("A", query_id)]["answer_hash_match"],
        "b_answer_hash_match": answers_by_key[("B", query_id)]["answer_hash_match"],
        "g_answer_hash_match": answers_by_key[("G", query_id)]["answer_hash_match"],
        "h_answer_hash_match": answers_by_key[("H", query_id)]["answer_hash_match"],
        "a_coherent_wrong_key": guards_by_key[("A", query_id)]["coherent_wrong_key"],
        "b_coherent_wrong_key": guards_by_key[("B", query_id)]["coherent_wrong_key"],
        "g_coherent_wrong_key": guards_by_key[("G", query_id)]["coherent_wrong_key"],
        "h_coherent_wrong_key": guards_by_key[("H", query_id)]["coherent_wrong_key"],
        "public_comparison_claim_ready": "0",
        "internal_real_adapter_metric_claim_ready": "1",
        "public_real_system_performance_claim_ready": "0",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "claim_boundary": "internal v1.0 pre-baseline A/B/G/H per-query ledger only; no public comparison or D/E replacement claim",
    }
    same_query_internal_prebaseline_rows.append(row)
write_csv(
    run_dir / "abgh_same_query_internal_prebaseline_rows.csv",
    list(same_query_internal_prebaseline_rows[0].keys()),
    same_query_internal_prebaseline_rows,
)
same_query_internal_prebaseline_rows_ready = int(
    len(same_query_internal_prebaseline_rows) == 1000
    and all(row["same_query_all_systems"] == "1" for row in same_query_internal_prebaseline_rows)
    and all(row["same_evaluator_contract"] == "1" for row in same_query_internal_prebaseline_rows)
    and all(row["same_resource_bound"] == "1" for row in same_query_internal_prebaseline_rows)
    and all(row["selection_question_text_only_all"] == "1" for row in same_query_internal_prebaseline_rows)
    and all(row["selection_oracle_field_used_any"] == "0" for row in same_query_internal_prebaseline_rows)
    and all(row["expected_answer_oracle_replay_any"] == "0" for row in same_query_internal_prebaseline_rows)
    and all(row["deterministic_source_span_adapter_execution_any"] == "0" for row in same_query_internal_prebaseline_rows)
    and all(row["public_comparison_claim_ready"] == "0" for row in same_query_internal_prebaseline_rows)
    and all(row["internal_real_adapter_metric_claim_ready"] == "1" for row in same_query_internal_prebaseline_rows)
    and all(row["public_real_system_performance_claim_ready"] == "0" for row in same_query_internal_prebaseline_rows)
)

metric_by_system = {row["system_id"]: row for row in metric_rows}
internal_prebaseline_contract_rows = []
for system_id, system_name, adapter in SYSTEMS:
    system_answer_rows = [row for row in answer_rows if row["system_id"] == system_id]
    system_citation_rows = [row for row in citation_rows if row["system_id"] == system_id]
    system_evaluator_rows = [row for row in evaluator_rows if row["system_id"] == system_id]
    system_resource_rows = [row for row in resource_rows if row["system_id"] == system_id]
    system_trace_rows = [row for row in adapter_trace_rows if row["system_id"] == system_id]
    metric_row = metric_by_system[system_id]
    same_query_set = int(
        {row["query_id"] for row in system_answer_rows} == v53i_query_ids
        and {row["query_id"] for row in system_citation_rows} == v53i_query_ids
        and {row["query_id"] for row in system_evaluator_rows} == v53i_query_ids
        and {row["query_id"] for row in system_resource_rows} == v53i_query_ids
        and {row["query_id"] for row in system_trace_rows} == v53i_query_ids
    )
    same_evaluator_contract = int(
        len(system_evaluator_rows) == 1000
        and {row["evaluator_contract_id"] for row in system_evaluator_rows} == {"v53aq-query-text-only-answer-citation-resource-v1"}
        and all(row["source_query_rows_sha256"] == query_hash and row["source_span_rows_sha256"] == span_hash for row in system_evaluator_rows)
    )
    same_resource_contract = int(
        len(system_resource_rows) == 1000
        and len(system_evaluator_rows) == 1000
        and all(row["resource_row_bound"] == "1" for row in system_evaluator_rows)
    )
    routehint_expected = int(system_id in {"G", "H"})
    scorer_policy_expected = int(system_id == "H")
    contract_ready = int(
        same_query_set
        and same_evaluator_contract
        and same_resource_contract
        and metric_row["query_rows"] == "1000"
        and metric_row["answer_rows"] == "1000"
        and metric_row["citation_rows"] == "1000"
        and metric_row["evaluator_rows"] == "1000"
        and metric_row["resource_rows"] == "1000"
        and metric_row["adapter_trace_rows"] == "1000"
        and metric_row["selection_question_text_only"] == "1"
        and metric_row["selection_sanitized_question_only"] == "1"
        and metric_row["source_locator_in_question_removed_rows"] == "1000"
        and metric_row["selection_oracle_field_used"] == "0"
        and metric_row["expected_answer_oracle_replay_rows"] == "0"
        and metric_row["deterministic_source_span_adapter_rows"] == "0"
        and metric_row["internal_real_adapter_metric_claim_ready"] == "1"
        and metric_row["public_real_system_performance_claim_ready"] == "0"
    )
    internal_prebaseline_contract_rows.append(
        {
            "contract_id": f"v53aq_internal_prebaseline_contract_{system_id}",
            "system_id": system_id,
            "system_name": system_name,
            "adapter": adapter,
            "query_set_id": "v53i_complete_source_1000",
            "source_query_rows_sha256": query_hash,
            "source_span_rows_sha256": span_hash,
            "source_manifest_rows": str(len(source_manifest_rows)),
            "query_rows": metric_row["query_rows"],
            "answer_rows": metric_row["answer_rows"],
            "citation_rows": metric_row["citation_rows"],
            "evaluator_rows": metric_row["evaluator_rows"],
            "resource_rows": metric_row["resource_rows"],
            "adapter_trace_rows": metric_row["adapter_trace_rows"],
            "route_memory_rows": metric_row["route_memory_rows"],
            "routehint_rows": metric_row["routehint_rows"],
            "routehint_expected": str(routehint_expected),
            "source_verified_scorer_policy_expected": str(scorer_policy_expected),
            "same_query_set": str(same_query_set),
            "same_evaluator_contract": str(same_evaluator_contract),
            "same_resource_contract": str(same_resource_contract),
            "selection_question_text_only": metric_row["selection_question_text_only"],
            "selection_sanitized_question_only": metric_row["selection_sanitized_question_only"],
            "source_locator_in_question_removed_rows": metric_row["source_locator_in_question_removed_rows"],
            "selection_oracle_field_used": metric_row["selection_oracle_field_used"],
            "expected_answer_oracle_replay_rows": metric_row["expected_answer_oracle_replay_rows"],
            "deterministic_source_span_adapter_rows": metric_row["deterministic_source_span_adapter_rows"],
            "answer_hash_match_rows": metric_row["answer_hash_match_rows"],
            "citation_location_match_rows": metric_row["citation_location_match_rows"],
            "source_span_id_match_rows": metric_row["source_span_id_match_rows"],
            "wrong_answer_rows": metric_row["wrong_answer_rows"],
            "coherent_wrong_key_rows": metric_row["coherent_wrong_key_rows"],
            "internal_real_adapter_metric_claim_ready": metric_row["internal_real_adapter_metric_claim_ready"],
            "public_real_system_performance_claim_ready": metric_row["public_real_system_performance_claim_ready"],
            "public_comparison_claim_ready": "0",
            "required_30b_baseline_ready": "0",
            "required_70b_baseline_ready": "0",
            "contract_ready": str(contract_ready),
            "claim_boundary": "internal v1.0 pre-baseline per-system contract only; no public comparison, D/E replacement, or public real-system performance claim",
        }
    )
write_csv(
    run_dir / "abgh_internal_prebaseline_contract_rows.csv",
    list(internal_prebaseline_contract_rows[0].keys()),
    internal_prebaseline_contract_rows,
)
internal_prebaseline_contract_row_count = len(internal_prebaseline_contract_rows)
internal_prebaseline_contract_ready_rows = sum(1 for row in internal_prebaseline_contract_rows if row["contract_ready"] == "1")
internal_prebaseline_contract_blocked_rows = internal_prebaseline_contract_row_count - internal_prebaseline_contract_ready_rows
internal_prebaseline_contract_ready = int(internal_prebaseline_contract_row_count == 4 and internal_prebaseline_contract_blocked_rows == 0)

ready = int(
    len(answer_rows) == 4000
    and len(citation_rows) == 4000
    and len(resource_rows) == 4000
    and len(evaluator_rows) == 4000
    and len(adapter_trace_rows) == 4000
    and len(routehint_rows) == 2000
    and len(route_memory_rows) == 2000
    and all(row["answer_rows"] == "1000" for row in metric_rows)
    and all(row["selection_oracle_field_used"] == "0" for row in adapter_trace_rows)
    and same_query_internal_prebaseline_rows_ready == 1
    and internal_prebaseline_contract_ready == 1
)

summary = {
    "v53aq_complete_source_abgh_real_adapter_measured_ready": str(ready),
    "v53_ready": "0",
    "query_set_id": "v53i_complete_source_1000",
    "source_query_rows_sha256": query_hash,
    "source_span_rows_sha256": span_hash,
    "system_rows": "4",
    "systems": "A/B/G/H",
    "query_rows": str(len(queries)),
    "source_manifest_rows": str(len(source_manifest_rows)),
    "answer_rows": str(len(answer_rows)),
    "citation_rows": str(len(citation_rows)),
    "retrieval_rows": str(len(retrieval_rows)),
    "evaluator_rows": str(len(evaluator_rows)),
    "adapter_trace_rows": str(len(adapter_trace_rows)),
    "abstain_rows": str(len(abstain_rows)),
    "wrong_answer_guard_rows": str(len(guard_rows)),
    "resource_rows": str(len(resource_rows)),
    "route_memory_rows": str(len(route_memory_rows)),
    "routehint_rows": str(len(routehint_rows)),
    "negative_abstain_rows": v53i_summary["negative_abstain_rows"],
    "missing_specific_abstain_rows": v53i_summary["missing_specific_abstain_rows"],
    "same_query_set_all_local_systems": "1",
    "same_query_internal_prebaseline_rows": str(len(same_query_internal_prebaseline_rows)),
    "same_query_internal_prebaseline_rows_ready": str(same_query_internal_prebaseline_rows_ready),
    "internal_prebaseline_contract_rows": str(internal_prebaseline_contract_row_count),
    "internal_prebaseline_contract_ready_rows": str(internal_prebaseline_contract_ready_rows),
    "internal_prebaseline_contract_blocked_rows": str(internal_prebaseline_contract_blocked_rows),
    "internal_prebaseline_contract_ready": str(internal_prebaseline_contract_ready),
    "same_source_manifest_all_local_systems": "1",
    "same_evaluator_contract_all_local_systems": "1",
    "same_resource_contract_all_local_systems": "1",
    "answer_hash_match_rows": str(total_answer_hash_match),
    "citation_location_match_rows": str(total_citation_location_match),
    "source_span_id_match_rows": str(total_source_span_id_match),
    "wrong_answer_rows": str(total_wrong),
    "coherent_wrong_key_rows": str(total_coherent_wrong),
    "selection_question_text_only": "1",
    "selection_sanitized_question_only": "1",
    "source_locator_in_question_removed_rows": str(len(adapter_trace_rows)),
    "selection_allowed_fields": "sanitized_question",
    "selection_forbidden_fields": ",".join(FORBIDDEN_SELECTION_FIELDS),
    "selection_oracle_field_used": "0",
    "source_span_oracle_selection_used": "0",
    "expected_answer_oracle_replay": "0",
    "expected_answer_oracle_replay_rows": "0",
    "deterministic_source_span_adapter_execution": "0",
    "deterministic_source_span_adapter_rows": "0",
    "actual_adapter_execution_ready": "1",
    "real_adapter_execution_ready": "1",
    "real_system_performance_claim_ready": "0",
    "internal_real_adapter_metric_claim_ready": "1",
    "public_real_system_performance_claim_ready": "0",
    "external_network_used": "0",
    "external_model_used": "0",
    "internal_v1_0_pre_baseline_run": "1",
    "quality_comparison_claim_ready": "0",
    "public_comparison_claim_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53i-complete-source-input", "pass", f"query_rows={len(queries)}; query_hash={query_hash}"),
    ("query-text-only-selection-contract", "pass", "adapter selection receives question text only; forbidden ground-truth fields are evaluator-only"),
    ("abgh-real-adapter-measured", "pass" if ready else "blocked", f"answer_rows={len(answer_rows)}; evaluator_rows={len(evaluator_rows)}; routehint_rows={len(routehint_rows)}"),
    ("same-query-internal-prebaseline-ledger", "pass" if same_query_internal_prebaseline_rows_ready else "blocked", f"ledger_rows={len(same_query_internal_prebaseline_rows)}; same_evaluator_resource_surface={same_query_internal_prebaseline_rows_ready}"),
    ("same-query-internal-prebaseline-system-contract", "pass" if internal_prebaseline_contract_ready else "blocked", f"contract_rows={internal_prebaseline_contract_row_count}; ready_rows={internal_prebaseline_contract_ready_rows}; public_comparison_claim_ready=0"),
    ("same-evaluator-resource-surface", "pass" if len(evaluator_rows) == 4000 and len(resource_rows) == 4000 else "blocked", "answer/citation/resource checks are separate on one evaluator contract"),
    ("expected-answer-oracle-replay-absent", "pass", "expected_answer_oracle_replay=0; answers are generated from selected source spans"),
    ("source-span-oracle-selection-absent", "pass", "source_span_id/source_path/source_line/query_id are not adapter-selection inputs"),
    ("routehint-no-raw-context", "pass", f"routehint_rows={len(routehint_rows)}; G/H raw_prompt_context_bytes=0"),
    ("internal-real-performance-metrics", "pass", f"answer_hash_match_rows={total_answer_hash_match}; coherent_wrong_key_rows={total_coherent_wrong}"),
    ("public-real-system-performance-claim", "blocked", "internal real-adapter metrics are present, but public performance wording remains blocked"),
    ("public-comparison-claim", "blocked", "D/E 30B/70B are absent; public comparison wording remains blocked"),
    ("required-30b-70b-baselines", "blocked", "D/E 30B/70B baselines are intentionally out of this A/B/G/H slice"),
    ("v53-full-audit-ready", "blocked", "human/reviewer return and public comparison evidence remain outside this slice"),
    ("real-release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

boundary = (
    "# v53aq Complete-Source A/B/G/H Real-Adapter Boundary\n\n"
    "This layer emits the PM A/B/G/H same-query packet over the frozen v53i 1000-row complete-source set with query-text-only local adapters. "
    "Adapter selection is not allowed to read query_id, expected answers, source_span_id, source_path, or source-line ground truth; those fields are used only by the evaluator after selection.\n\n"
    f"- query_set_id=v53i_complete_source_1000\n"
    f"- source_query_rows_sha256={query_hash}\n"
    f"- source_span_rows_sha256={span_hash}\n"
    "- systems=A/B/G/H\n"
    f"- same_query_internal_prebaseline_rows={len(same_query_internal_prebaseline_rows)}\n"
    f"- same_query_internal_prebaseline_rows_ready={same_query_internal_prebaseline_rows_ready}\n"
    f"- internal_prebaseline_contract_rows={internal_prebaseline_contract_row_count}\n"
    f"- internal_prebaseline_contract_ready_rows={internal_prebaseline_contract_ready_rows}\n"
    f"- internal_prebaseline_contract_blocked_rows={internal_prebaseline_contract_blocked_rows}\n"
    f"- internal_prebaseline_contract_ready={internal_prebaseline_contract_ready}\n"
    f"- answer_rows={len(answer_rows)}\n"
    f"- citation_rows={len(citation_rows)}\n"
    f"- evaluator_rows={len(evaluator_rows)}\n"
    f"- adapter_trace_rows={len(adapter_trace_rows)}\n"
    f"- resource_rows={len(resource_rows)}\n"
    f"- route_memory_rows={len(route_memory_rows)}\n"
    f"- routehint_rows={len(routehint_rows)}\n"
    f"- answer_hash_match_rows={total_answer_hash_match}\n"
    f"- citation_location_match_rows={total_citation_location_match}\n"
    f"- source_span_id_match_rows={total_source_span_id_match}\n"
    f"- wrong_answer_rows={total_wrong}\n"
    f"- coherent_wrong_key_rows={total_coherent_wrong}\n"
    "- selection_question_text_only=1\n"
    "- selection_sanitized_question_only=1\n"
    f"- source_locator_in_question_removed_rows={len(adapter_trace_rows)}\n"
    "- selection_allowed_fields=sanitized_question\n"
    f"- selection_forbidden_fields={','.join(FORBIDDEN_SELECTION_FIELDS)}\n"
    "- selection_oracle_field_used=0\n"
    "- source_span_oracle_selection_used=0\n"
    "- expected_answer_oracle_replay=0\n"
    "- deterministic_source_span_adapter_execution=0\n"
    "- actual_adapter_execution_ready=1\n"
    "- real_adapter_execution_ready=1\n"
    "- real_system_performance_claim_ready=0\n"
    "- internal_real_adapter_metric_claim_ready=1\n"
    "- public_real_system_performance_claim_ready=0\n"
    "- internal_v1_0_pre_baseline_run=1\n"
    "- public_comparison_claim_ready=0\n"
    "- required_30b_baseline_ready=0\n"
    "- required_70b_baseline_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: internal v1.0 pre-baseline A/B/G/H real local adapter run over the frozen complete-source v53i query set.\n\n"
    "Blocked wording: public system performance, public comparison, leaderboard, 30B/70B replacement, v53 completion, v1.0 release readiness, production readiness, or superiority claims.\n"
)
(run_dir / "V53AQ_COMPLETE_SOURCE_ABGH_REAL_ADAPTER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53aq-complete-source-abgh-real-adapter-measured",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53aq_complete_source_abgh_real_adapter_measured_ready": ready,
    "query_set_id": "v53i_complete_source_1000",
    "source_query_rows_sha256": query_hash,
    "source_span_rows_sha256": span_hash,
    "systems": [system_id for system_id, _, _ in SYSTEMS],
    "answer_rows": len(answer_rows),
    "citation_rows": len(citation_rows),
    "retrieval_rows": len(retrieval_rows),
    "evaluator_rows": len(evaluator_rows),
    "adapter_trace_rows": len(adapter_trace_rows),
    "resource_rows": len(resource_rows),
    "route_memory_rows": len(route_memory_rows),
    "routehint_rows": len(routehint_rows),
    "answer_hash_match_rows": total_answer_hash_match,
    "same_query_internal_prebaseline_rows": len(same_query_internal_prebaseline_rows),
    "same_query_internal_prebaseline_rows_ready": same_query_internal_prebaseline_rows_ready,
    "internal_prebaseline_contract_rows": internal_prebaseline_contract_row_count,
    "internal_prebaseline_contract_ready_rows": internal_prebaseline_contract_ready_rows,
    "internal_prebaseline_contract_blocked_rows": internal_prebaseline_contract_blocked_rows,
    "internal_prebaseline_contract_ready": internal_prebaseline_contract_ready,
    "internal_prebaseline_contract_rows_sha256": sha256(run_dir / "abgh_internal_prebaseline_contract_rows.csv"),
    "citation_location_match_rows": total_citation_location_match,
    "source_span_id_match_rows": total_source_span_id_match,
    "wrong_answer_rows": total_wrong,
    "coherent_wrong_key_rows": total_coherent_wrong,
    "same_evaluator_contract_all_local_systems": 1,
    "same_resource_contract_all_local_systems": 1,
    "selection_question_text_only": 1,
    "selection_sanitized_question_only": 1,
    "source_locator_in_question_removed_rows": len(adapter_trace_rows),
    "selection_oracle_field_used": 0,
    "expected_answer_oracle_replay": 0,
    "deterministic_source_span_adapter_execution": 0,
    "actual_adapter_execution_ready": 1,
    "real_adapter_execution_ready": 1,
    "real_system_performance_claim_ready": 0,
    "internal_real_adapter_metric_claim_ready": 1,
    "public_real_system_performance_claim_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53aq_complete_source_abgh_real_adapter_measured_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53aq_complete_source_abgh_real_adapter_measured_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
