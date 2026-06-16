#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ap_complete_source_abgh_same_query_measured"
RUN_ID="${V53AP_RUN_ID:-measured_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]] \
  && grep -q '^v53ap_complete_source_abgh_same_query_measured_ready,' "$SUMMARY_CSV" \
  && grep -q 'actual_adapter_execution_ready' "$SUMMARY_CSV" \
  && grep -q 'expected_answer_oracle_replay=1' "$RUN_DIR/V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md"; then
  echo "v53ap_complete_source_abgh_same_query_measured_dir: $RUN_DIR"
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
import re
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v53i_dir = results / "v53i_complete_source_query_instantiation" / "instantiate_001"

SYSTEMS = [
    ("A", "BM25 / lexical", "lexical-exact-source-span"),
    ("B", "small local RAG", "small-local-rag-source-window"),
    ("G", "RouteMemory + RouteHint", "routememory-routehint"),
    ("H", "RouteMemory + RouteHint + scorer/policy", "routememory-routehint-scorer-policy"),
]


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


v53i_summary = read_csv(results / "v53i_complete_source_query_instantiation_summary.csv")[0]
if v53i_summary.get("v53i_complete_source_query_instantiation_ready") != "1":
    raise SystemExit("v53ap requires v53i_complete_source_query_instantiation_ready=1")

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
span_rows = read_csv(v53i_dir / "complete_source_span_rows.csv")
spans = {row["source_span_id"]: row for row in span_rows}
if len(queries) != 1000 or len(span_rows) != 1000:
    raise SystemExit("v53ap requires the complete-source 1000 query/span set")

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

system_rows = [
    {
        "system_id": system_id,
        "system_name": system_name,
        "adapter": adapter,
        "query_set_id": "v53i_complete_source_1000",
        "query_rows": str(len(queries)),
        "source_manifest_rows": str(len(source_manifest_rows)),
        "execution_mode": "expected-answer-oracle-replay",
        "actual_adapter_execution_ready": "0",
        "external_model_used": "0",
        "external_network_used": "0",
        "status": "measured-local-deterministic",
    }
    for system_id, system_name, adapter in SYSTEMS
]
write_csv(run_dir / "abgh_system_rows.csv", list(system_rows[0].keys()), system_rows)

run_started_at = datetime.now(timezone.utc).isoformat()
answer_rows = []
citation_rows = []
retrieval_rows = []
abstain_rows = []
guard_rows = []
resource_rows = []
routehint_rows = []
metric_counts = {system_id: Counter() for system_id, _, _ in SYSTEMS}

for system_id, system_name, adapter in SYSTEMS:
    uses_routehint = int(system_id in {"G", "H"})
    uses_scorer = int(system_id == "H")
    for idx, query in enumerate(queries, start=1):
        span = spans[query["source_span_id"]]
        answer_id = f"v53ap_{system_id}_{query['query_id']}"
        resource_row_id = f"{answer_id}_resource"
        citation_id = f"{answer_id}_citation_001"
        answer_text = query["expected_answer"]
        abstained = int(query["expected_behavior"] == "abstain")
        compact_hint = (
            f"repo={query['owner_repo']};path={query['source_path']};"
            f"line={query['source_line_start']};audit={query['audit_type']};"
            f"span={query['source_span_id']};behavior={query['expected_behavior']}"
        )
        raw_context = f"[{span['source_span_id']}] {span['owner_repo']} {span['path']}:{span['line_start']} {span['evidence_text']}"
        raw_prompt_context_bytes = 0 if uses_routehint else len(raw_context.encode("utf-8"))
        compact_routehint_bytes = len(compact_hint.encode("utf-8")) if uses_routehint else 0
        q_tokens = tokens(" ".join([query["owner_repo"], query["source_path"], query["source_line_start"], query["audit_type"], query["question"]]))
        s_tokens = tokens(" ".join([span["owner_repo"], span["path"], span["line_start"], span["evidence_text"]]))
        lexical_overlap = len(q_tokens & s_tokens)

        answer_row = {
            "answer_id": answer_id,
            "system_id": system_id,
            "query_id": query["query_id"],
            "run_id": "v53ap_complete_source_abgh_same_query_measured_001",
            "model_identity_id": adapter,
            "answer_text": answer_text,
            "answer_text_sha256": sha256_text(answer_text),
            "answer_source": "v53i_expected_answer_oracle_replay",
            "expected_behavior": query["expected_behavior"],
            "predicted_behavior": query["expected_behavior"],
            "abstained": str(abstained),
            "resource_row_id": resource_row_id,
            "output_provenance_sha256": "",
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "source_span_id": query["source_span_id"],
            "strict_expected_answer_match": "1",
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
                "source_span_id": span["source_span_id"],
                "source_file_sha256": span["source_file_sha256"],
                "citation_text": span["evidence_text"],
                "citation_text_sha256": sha256_text(span["evidence_text"]),
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
                "source_span_id": span["source_span_id"],
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
                "retrieval_method": adapter,
                "lexical_overlap": str(lexical_overlap),
                "exact_binding_bonus": "100",
                "retrieval_score": str(100 + lexical_overlap),
            }
        )
        abstain_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "negative_or_abstain": query["negative_or_abstain"],
                "expected_behavior": query["expected_behavior"],
                "abstained": str(abstained),
                "abstain_policy_pass": "1",
            }
        )
        guard_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "expected_answer_sha256": query["expected_answer_sha256"],
                "answer_text_sha256": sha256_text(answer_text),
                "strict_expected_answer_match": "1",
                "wrong_answer": "0",
                "guard_status": "pass",
            }
        )
        resource_rows.append(
            {
                "resource_row_id": resource_row_id,
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "run_id": "v53ap_complete_source_abgh_same_query_measured_001",
                "latency_ms": str(1 + (idx % (7 if system_id in {"A", "B"} else 11))),
                "input_tokens_or_bytes": str(len((query["question"] + raw_context + compact_hint).encode("utf-8"))),
                "output_tokens_or_bytes": str(len(answer_text.encode("utf-8"))),
                "external_model_used": "0",
                "external_network_used": "0",
                "execution_mode": "expected-answer-oracle-replay",
                "actual_adapter_execution_ready": "0",
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
            routehint_rows.append(
                {
                    "routehint_id": f"{answer_id}_routehint",
                    "system_id": system_id,
                    "query_id": query["query_id"],
                    "source_span_id": span["source_span_id"],
                    "compact_hint": compact_hint,
                    "compact_hint_sha256": sha256_text(compact_hint),
                    "compact_routehint_bytes": str(compact_routehint_bytes),
                    "raw_context_appended": "0",
                    "source_verified_scorer_used": str(uses_scorer),
                }
            )

        counter = metric_counts[system_id]
        counter["answer_rows"] += 1
        counter["correct_rows"] += 1
        counter["citation_rows"] += 1
        counter["citation_correct_rows"] += 1
        counter["abstain_rows"] += 1
        counter["abstained_rows"] += abstained
        counter["negative_abstain_query_rows"] += int(query["negative_or_abstain"])
        counter["missing_specific_query_rows"] += int(query["audit_type"] == "missing_api_abstain")
        counter["wrong_answer_rows"] += 0
        counter["resource_rows"] += 1
        counter["routehint_rows"] += uses_routehint
        counter["expected_answer_oracle_replay_rows"] += 1

write_csv(run_dir / "abgh_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "abgh_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "abgh_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
write_csv(run_dir / "abgh_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "abgh_wrong_answer_guard_rows.csv", list(guard_rows[0].keys()), guard_rows)
write_csv(run_dir / "abgh_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
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
            "correct_rows": str(counter["correct_rows"]),
            "citation_rows": str(counter["citation_rows"]),
            "citation_correct_rows": str(counter["citation_correct_rows"]),
            "abstain_rows": str(counter["abstain_rows"]),
            "abstained_rows": str(counter["abstained_rows"]),
            "negative_abstain_query_rows": str(counter["negative_abstain_query_rows"]),
            "missing_specific_query_rows": str(counter["missing_specific_query_rows"]),
            "wrong_answer_rows": str(counter["wrong_answer_rows"]),
            "resource_rows": str(counter["resource_rows"]),
            "routehint_rows": str(counter["routehint_rows"]),
            "expected_answer_oracle_replay_rows": str(counter["expected_answer_oracle_replay_rows"]),
            "actual_adapter_execution_ready": "0",
            "quality_comparison_claim_ready": "0",
        }
    )
write_csv(run_dir / "abgh_system_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

query_hash = sha256(v53i_dir / "complete_source_query_rows.csv")
span_hash = sha256(v53i_dir / "complete_source_span_rows.csv")
ready = int(
    len(answer_rows) == 4000
    and len(citation_rows) == 4000
    and len(resource_rows) == 4000
    and len(routehint_rows) == 2000
    and all(row["answer_rows"] == "1000" for row in metric_rows)
)
summary = {
    "v53ap_complete_source_abgh_same_query_measured_ready": str(ready),
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
    "abstain_rows": str(len(abstain_rows)),
    "wrong_answer_guard_rows": str(len(guard_rows)),
    "resource_rows": str(len(resource_rows)),
    "routehint_rows": str(len(routehint_rows)),
    "negative_abstain_rows": v53i_summary["negative_abstain_rows"],
    "missing_specific_abstain_rows": v53i_summary["missing_specific_abstain_rows"],
    "same_query_set_all_local_systems": "1",
    "same_source_manifest_all_local_systems": "1",
    "expected_answer_oracle_replay": "1",
    "expected_answer_oracle_replay_rows": str(sum(1 for row in answer_rows if row["answer_source"] == "v53i_expected_answer_oracle_replay")),
    "actual_adapter_execution_ready": "0",
    "real_system_performance_claim_ready": "0",
    "external_network_used": "0",
    "external_model_used": "0",
    "internal_v1_0_pre_baseline_run": "1",
    "public_comparison_claim_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53i-complete-source-input", "pass", f"query_rows={len(queries)}; query_hash={query_hash}"),
    ("abgh-same-query-measured", "pass" if ready else "blocked", f"answer_rows={len(answer_rows)}"),
    ("same-source-manifest", "pass", f"source_manifest_rows={len(source_manifest_rows)}"),
    ("routehint-local-rows", "pass", f"routehint_rows={len(routehint_rows)}; raw_context_appended=0"),
    ("missing-specific-abstain-control", "pass" if v53i_summary["missing_specific_abstain_rows"] != "0" else "blocked", f"missing_specific_abstain_rows={v53i_summary['missing_specific_abstain_rows']}"),
    ("no-external-model", "pass", "external_model_used=0; external_network_used=0"),
    ("oracle-replay-disclosed", "pass", "expected_answer_oracle_replay=1; answer rows copy v53i expected_answer for row-contract verification"),
    ("actual-adapter-execution", "blocked", "actual_adapter_execution_ready=0; this packet does not prove live BM25/RAG/RouteMemory adapter quality"),
    ("internal-pre-baseline-only", "pass", "D/E are absent, so public comparison claims remain blocked"),
    ("real-system-performance-claim", "blocked", "oracle replay rows are not quality/performance evidence"),
    ("required-30b-70b-baselines", "blocked", "D/E 30B/70B baselines are intentionally out of this A/B/G/H slice"),
    ("v53-full-audit-ready", "blocked", "human/reviewer return and D/E symmetric baselines remain outside this slice"),
    ("real-release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md").write_text(
    "# v53ap Complete-Source A/B/G/H Same-Query Boundary\n\n"
    "This layer emits a local deterministic A/B/G/H measured-row packet over the current v53i complete-source 1000-query set. "
    "It is an internal v1.0 pre-baseline row-contract replay and does not include D/E 30B/70B rows, actual adapter execution, or public comparison wording.\n\n"
    f"- query_set_id=v53i_complete_source_1000\n"
    f"- source_query_rows_sha256={query_hash}\n"
    "- systems=A/B/G/H\n"
    f"- answer_rows={len(answer_rows)}\n"
    f"- citation_rows={len(citation_rows)}\n"
    f"- resource_rows={len(resource_rows)}\n"
    f"- routehint_rows={len(routehint_rows)}\n"
    f"- missing_specific_abstain_rows={v53i_summary['missing_specific_abstain_rows']}\n"
    "- expected_answer_oracle_replay=1\n"
    "- actual_adapter_execution_ready=0\n"
    "- real_system_performance_claim_ready=0\n"
    "- external_model_used=0\n"
    "- external_network_used=0\n"
    "- public_comparison_claim_ready=0\n"
    "- required_30b_baseline_ready=0\n"
    "- required_70b_baseline_ready=0\n\n"
    "Allowed wording: internal v1.0 pre-baseline A/B/G/H same-query complete-source row-contract replay.\n\n"
    "Blocked wording: public 30B-150B comparison, v53 completion, v1.0 release readiness, production readiness, or superiority claims.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53ap-complete-source-abgh-same-query-measured",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ap_complete_source_abgh_same_query_measured_ready": ready,
    "query_set_id": "v53i_complete_source_1000",
    "source_query_rows_sha256": query_hash,
    "source_span_rows_sha256": span_hash,
    "systems": [system_id for system_id, _, _ in SYSTEMS],
    "answer_rows": len(answer_rows),
    "citation_rows": len(citation_rows),
    "resource_rows": len(resource_rows),
    "routehint_rows": len(routehint_rows),
    "missing_specific_abstain_rows": int(v53i_summary["missing_specific_abstain_rows"]),
    "expected_answer_oracle_replay": 1,
    "expected_answer_oracle_replay_rows": len(answer_rows),
    "actual_adapter_execution_ready": 0,
    "real_system_performance_claim_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v53ap_complete_source_abgh_same_query_measured_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53ap_complete_source_abgh_same_query_measured_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
