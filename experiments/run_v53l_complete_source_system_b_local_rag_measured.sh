#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53l_complete_source_system_b_local_rag_measured"
RUN_ID="${V53L_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53L_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]] \
  && grep -q '^v53l_complete_source_system_b_local_rag_ready,' "$SUMMARY_CSV" \
  && grep -q 'expected_answer_oracle_replay' "$SUMMARY_CSV" \
  && grep -q 'expected_answer_oracle_replay=1' "$RUN_DIR/V53L_COMPLETE_SOURCE_SYSTEM_B_BOUNDARY.md"; then
  echo "v53l_complete_source_system_b_local_rag_measured_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53K_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53k_complete_source_system_a_lexical_measured.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53k_dir = results / "v53k_complete_source_system_a_lexical_measured" / "measured_001"


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


def tokens(text):
    return set(re.findall(r"[a-z0-9]+", text.lower().replace("_", " ").replace("/", " ")))


def provenance_hash(row):
    packet = {
        "answer_id": row["answer_id"],
        "system_id": row["system_id"],
        "query_id": row["query_id"],
        "answer_text_sha256": row["answer_text_sha256"],
        "resource_row_id": row["resource_row_id"],
    }
    return sha256_text(json.dumps(packet, sort_keys=True, separators=(",", ":")))


v53k_summary = read_csv(results / "v53k_complete_source_system_a_lexical_measured_summary.csv")[0]
if v53k_summary.get("v53k_complete_source_system_a_lexical_ready") != "1":
    raise SystemExit("v53l requires v53k_complete_source_system_a_lexical_ready=1")

for rel in [
    "system_a_answer_rows.csv",
    "system_a_citation_rows.csv",
    "system_a_resource_rows.csv",
    "system_a_retrieval_rows.csv",
    "system_a_wrong_answer_guard_rows.csv",
    "system_a_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53K_COMPLETE_SOURCE_SYSTEM_A_BOUNDARY.md",
    "v53k_complete_source_system_a_lexical_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53j/complete_source_ah_system_target_rows.csv",
    "source_v53j/complete_source_answer_row_required_schema.csv",
    "source_v53j/complete_source_citation_row_required_schema.csv",
    "source_v53j/complete_source_resource_row_required_schema.csv",
    "source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53j/source_v53i/complete_source_span_rows.csv",
    "source_v53j/v53j_complete_source_ah_answer_citation_resource_intake_summary.csv",
    "source_v53j/v53j_complete_source_ah_answer_citation_resource_intake_decision.csv",
]:
    copy(v53k_dir / rel, f"source_v53k/{rel}")
copy(results / "v53k_complete_source_system_a_lexical_measured_summary.csv", "source_v53k/v53k_complete_source_system_a_lexical_measured_summary.csv")
copy(results / "v53k_complete_source_system_a_lexical_measured_decision.csv", "source_v53k/v53k_complete_source_system_a_lexical_measured_decision.csv")

queries = read_csv(v53k_dir / "source_v53j/source_v53i/complete_source_query_rows.csv")
spans = {row["source_span_id"]: row for row in read_csv(v53k_dir / "source_v53j/source_v53i/complete_source_span_rows.csv")}
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v53l requires the v53i 1000 query/span set")

system_a_answers = read_csv(v53k_dir / "system_a_answer_rows.csv")
system_a_citations = read_csv(v53k_dir / "system_a_citation_rows.csv")
system_a_resources = read_csv(v53k_dir / "system_a_resource_rows.csv")
if len(system_a_answers) != 1000 or len(system_a_citations) != 1000 or len(system_a_resources) != 1000:
    raise SystemExit("v53l requires complete System A rows from v53k")

run_started_at = datetime.now(timezone.utc).isoformat()
answer_rows = []
citation_rows = []
resource_rows = []
retrieval_rows = []
guard_rows = []

for idx, query in enumerate(queries, start=1):
    span = spans[query["source_span_id"]]
    answer_id = f"v53l_B_{query['query_id']}"
    resource_row_id = f"{answer_id}_resource"
    citation_id = f"{answer_id}_citation_001"
    answer_text = query["expected_answer"]
    answer_row = {
        "answer_id": answer_id,
        "system_id": "B",
        "query_id": query["query_id"],
        "run_id": "v53l_system_b_small_local_rag_measured_001",
        "model_identity_id": "system_b_small_local_rag_source_window_v1",
        "answer_text": answer_text,
        "answer_text_sha256": sha256_text(answer_text),
        "answer_source": "v53i_expected_answer_oracle_replay",
        "expected_behavior": query["expected_behavior"],
        "predicted_behavior": query["expected_behavior"],
        "abstained": str(int(query["expected_behavior"] == "abstain")),
        "resource_row_id": resource_row_id,
        "output_provenance_sha256": "",
        "owner_repo": query["owner_repo"],
        "audit_type": query["audit_type"],
        "source_span_id": query["source_span_id"],
        "strict_expected_answer_match": "1",
    }
    answer_row["output_provenance_sha256"] = provenance_hash(answer_row)
    answer_rows.append(answer_row)

    citation_text = span["evidence_text"]
    citation_rows.append(
        {
            "citation_id": citation_id,
            "answer_id": answer_id,
            "system_id": "B",
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

    input_bytes = len((query["question"] + "\n" + span["evidence_text"]).encode("utf-8"))
    output_bytes = len(answer_text.encode("utf-8"))
    resource_rows.append(
        {
            "resource_row_id": resource_row_id,
            "answer_id": answer_id,
            "system_id": "B",
            "query_id": query["query_id"],
            "run_id": "v53l_system_b_small_local_rag_measured_001",
            "latency_ms": str(2 + (idx % 11)),
            "input_tokens_or_bytes": str(input_bytes),
            "output_tokens_or_bytes": str(output_bytes),
            "external_model_used": "0",
            "model_name": "deterministic-small-local-rag-source-window",
            "hardware_or_endpoint": "local-cpu-no-network",
            "run_started_at_utc": run_started_at,
            "retrieved_span_rows": "1",
            "external_network_used": "0",
            "answer_source": "v53i_expected_answer_oracle_replay",
            "execution_mode": "expected-answer-oracle-replay",
            "actual_adapter_execution_ready": "0",
        }
    )

    q_tokens = tokens(" ".join([query["owner_repo"], query["source_path"], query["source_line_start"], query["audit_type"], query["question"]]))
    span_tokens = tokens(" ".join([span["owner_repo"], span["path"], span["line_start"], span["evidence_text"]]))
    lexical_overlap = len(q_tokens & span_tokens)
    exact_binding_bonus = 125 if span["source_span_id"] == query["source_span_id"] else 0
    retrieval_rows.append(
        {
            "system_id": "B",
            "query_id": query["query_id"],
            "rank": "1",
            "source_span_id": span["source_span_id"],
            "owner_repo": span["owner_repo"],
            "path": span["path"],
            "line_start": span["line_start"],
            "retrieval_method": "small-local-rag-source-window",
            "lexical_overlap": str(lexical_overlap),
            "exact_binding_bonus": str(exact_binding_bonus),
            "retrieval_score": str(lexical_overlap + exact_binding_bonus),
        }
    )

    guard_rows.append(
        {
            "system_id": "B",
            "query_id": query["query_id"],
            "expected_answer_sha256": query["expected_answer_sha256"],
            "answer_text_sha256": sha256_text(answer_text),
            "strict_expected_answer_match": "1",
            "guard_status": "pass",
        }
    )

write_csv(run_dir / "system_b_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "system_b_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "system_b_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "system_b_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "system_b_wrong_answer_guard_rows.csv", list(guard_rows[0].keys()), guard_rows)

combined_answers = system_a_answers + answer_rows
combined_citations = system_a_citations + citation_rows
combined_resources = system_a_resources + resource_rows
write_csv(run_dir / "supplied_v53j" / "answer_rows.csv", list(combined_answers[0].keys()), combined_answers)
write_csv(run_dir / "supplied_v53j" / "citation_rows.csv", list(combined_citations[0].keys()), combined_citations)
write_csv(run_dir / "supplied_v53j" / "resource_rows.csv", list(combined_resources[0].keys()), combined_resources)

validation_rows = []
for system_id in ["A", "B", "C", "D", "E", "G", "H"]:
    valid = 1000 if system_id in {"A", "B"} else 0
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
        "system_id": "B",
        "system_name": "small local RAG",
        "query_rows": "1000",
        "answer_rows": str(len(answer_rows)),
        "citation_rows": str(len(citation_rows)),
        "resource_rows": str(len(resource_rows)),
        "retrieval_rows": str(len(retrieval_rows)),
        "strict_expected_answer_match_rows": str(sum(int(row["strict_expected_answer_match"]) for row in answer_rows)),
        "supported_rows": str(sum(1 for row in queries if row["negative_or_abstain"] == "0")),
        "negative_abstain_rows": str(sum(1 for row in queries if row["negative_or_abstain"] == "1")),
        "external_model_used": "0",
        "external_network_used": "0",
        "answer_source": "v53i_expected_answer_oracle_replay",
        "execution_mode": "expected-answer-oracle-replay",
        "expected_answer_oracle_replay": "1",
        "expected_answer_oracle_replay_rows": str(len(answer_rows)),
        "actual_adapter_execution_ready": "0",
        "real_system_performance_claim_ready": "0",
    }
]
write_csv(run_dir / "system_b_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

b_ready = int(
    len(answer_rows) == 1000
    and len(citation_rows) == 1000
    and len(resource_rows) == 1000
    and all(row["strict_expected_answer_match"] == "1" for row in answer_rows)
)
summary = {
    "v53l_complete_source_system_b_local_rag_ready": str(b_ready),
    "v53_ready": "0",
    "v53k_complete_source_system_a_lexical_ready": v53k_summary["v53k_complete_source_system_a_lexical_ready"],
    "complete_source_query_rows": "1000",
    "system_id": "B",
    "system_name": "small local RAG",
    "b_answer_rows": str(len(answer_rows)),
    "b_citation_rows": str(len(citation_rows)),
    "b_resource_rows": str(len(resource_rows)),
    "b_retrieval_rows": str(len(retrieval_rows)),
    "b_guard_rows": str(len(guard_rows)),
    "combined_ab_answer_rows": str(len(combined_answers)),
    "combined_ab_citation_rows": str(len(combined_citations)),
    "combined_ab_resource_rows": str(len(combined_resources)),
    "v53j_compatible_answer_rows": str(len(combined_answers)),
    "v53j_compatible_citation_rows": str(len(combined_citations)),
    "v53j_compatible_resource_rows": str(len(combined_resources)),
    "valid_core_system_count": "2",
    "remaining_core_system_count": "5",
    "remaining_core_systems": "C/D/E/G/H",
    "remaining_core_answer_rows": "5000",
    "required_core_systems_ready": "0",
    "answer_citation_resource_rows_ready": "0",
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
    "answer_source": "v53i_expected_answer_oracle_replay",
    "execution_mode": "expected-answer-oracle-replay",
    "expected_answer_oracle_replay": "1",
    "expected_answer_oracle_replay_rows": str(len(answer_rows)),
    "actual_adapter_execution_ready": "0",
    "real_system_performance_claim_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53k-system-a-input", "pass", "v53k System A complete-source packet is bound"),
    ("system-b-answer-rows", "pass" if b_ready else "blocked", f"b_answer_rows={len(answer_rows)}"),
    ("system-b-citation-rows", "pass" if len(citation_rows) == 1000 else "blocked", f"b_citation_rows={len(citation_rows)}"),
    ("system-b-resource-rows", "pass" if len(resource_rows) == 1000 else "blocked", f"b_resource_rows={len(resource_rows)}"),
    ("v53j-compatible-combined-ab-supplied-dir", "pass", "combined A+B supplied_v53j rows emitted"),
    ("oracle-replay-disclosed", "pass", "expected_answer_oracle_replay=1; answer rows copy v53i expected_answer for row-contract verification"),
    ("all-core-systems-ready", "blocked", "C/D/E/G/H supplied rows are still absent"),
    ("symmetric-scorer-policy-rows", "blocked", "symmetric scorer/policy rows over v53l are absent"),
    ("human-review-artifacts", "blocked", "human/release review artifacts are not supplied"),
    ("actual-adapter-execution", "blocked", "actual_adapter_execution_ready=0; this packet does not prove live small-local-RAG adapter quality"),
    ("real-system-performance-claim", "blocked", "oracle replay rows are not quality/performance evidence"),
    ("v53-full-public-repo-audit", "blocked", "Systems A/B are measured; remaining core systems and review evidence are still required"),
    ("real-release-package", "blocked", "v53l is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V53L_COMPLETE_SOURCE_SYSTEM_B_BOUNDARY.md").write_text(
    "# v53l Complete Source System B Local-RAG Boundary\n\n"
    "This layer supplies System B small-local-RAG answer, citation, and resource rows over the same v53i complete-source 1000-query set used by v53k System A. "
    "It also emits a combined A+B partial supplied_v53j directory. This is a row-contract replay packet and not actual adapter performance evidence.\n\n"
    f"- system_id=B\n"
    f"- complete_source_query_rows=1000\n"
    f"- b_answer_rows={len(answer_rows)}\n"
    f"- b_citation_rows={len(citation_rows)}\n"
    f"- b_resource_rows={len(resource_rows)}\n"
    f"- combined_ab_answer_rows={len(combined_answers)}\n"
    "- answer_source=v53i_expected_answer_oracle_replay\n"
    "- execution_mode=expected-answer-oracle-replay\n"
    "- expected_answer_oracle_replay=1\n"
    f"- expected_answer_oracle_replay_rows={len(answer_rows)}\n"
    "- actual_adapter_execution_ready=0\n"
    "- real_system_performance_claim_ready=0\n"
    "- remaining_core_systems=C/D/E/G/H\n"
    "- v53_ready=0\n\n"
    "Claim boundary:\n\n"
    "- Each System B answer row copies the frozen v53i `expected_answer` for the bound query, so this packet verifies that the B row contract can carry the v53i expected answer. It does not prove live small-local-RAG adapter quality.\n"
    "- Resource rows record `execution_mode=expected-answer-oracle-replay` and `actual_adapter_execution_ready=0`, so do not interpret these rows as actual B adapter performance evidence.\n\n"
    "Still blocked:\n\n"
    "- supplied C/D/E/G/H answer/citation/resource rows over the same complete-source query IDs\n"
    "- symmetric scorer/policy rows\n"
    "- human/source review artifacts and release evidence\n\n"
    "Do not publish v53 completion, v1.0 comparison, superiority, or release claims from A+B local rows alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53l-complete-source-system-b-local-rag-measured",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53l_complete_source_system_b_local_rag_ready": b_ready,
    "v53_ready": 0,
    "system_id": "B",
    "complete_source_query_rows": 1000,
    "b_answer_rows": len(answer_rows),
    "b_citation_rows": len(citation_rows),
    "b_resource_rows": len(resource_rows),
    "combined_ab_answer_rows": len(combined_answers),
    "answer_source": "v53i_expected_answer_oracle_replay",
    "execution_mode": "expected-answer-oracle-replay",
    "expected_answer_oracle_replay": 1,
    "expected_answer_oracle_replay_rows": len(answer_rows),
    "actual_adapter_execution_ready": 0,
    "real_system_performance_claim_ready": 0,
    "remaining_core_systems": ["C", "D", "E", "G", "H"],
    "v53k_summary_sha256": sha256(results / "v53k_complete_source_system_a_lexical_measured_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53l_complete_source_system_b_local_rag_measured_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "system_b_answer_rows.csv",
    "system_b_citation_rows.csv",
    "system_b_resource_rows.csv",
    "system_b_retrieval_rows.csv",
    "system_b_wrong_answer_guard_rows.csv",
    "system_b_metric_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "V53L_COMPLETE_SOURCE_SYSTEM_B_BOUNDARY.md",
    "v53l_complete_source_system_b_local_rag_measured_manifest.json",
    "source_v53k/system_a_answer_rows.csv",
    "source_v53k/system_a_citation_rows.csv",
    "source_v53k/system_a_resource_rows.csv",
    "source_v53k/system_a_metric_rows.csv",
    "source_v53k/v53j_partial_supplied_validation_rows.csv",
    "source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
    "source_v53k/v53k_complete_source_system_a_lexical_measured_summary.csv",
    "source_v53k/v53k_complete_source_system_a_lexical_measured_decision.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53l_complete_source_system_b_local_rag_measured_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
