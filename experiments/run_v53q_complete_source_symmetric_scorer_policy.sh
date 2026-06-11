#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53q_complete_source_symmetric_scorer_policy"
RUN_ID="${V53Q_RUN_ID:-score_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53Q_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53q_complete_source_symmetric_scorer_policy_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53P_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53p_complete_source_system_de_open_weight_rag_measured.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
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
v53p_dir = results / "v53p_complete_source_system_de_open_weight_rag_measured" / "measured_001"

CORE_SYSTEMS = ["A", "B", "C", "D", "E", "G", "H"]


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


def domain_policy_for(query):
    if query["negative_or_abstain"] == "1":
        return "abstain-first-unsupported-broad-claim"
    if query["source_category"] == "doc":
        return "doc-evidence-source-bound"
    if query["source_category"] == "config":
        return "config-evidence-source-bound"
    if query["source_category"] == "test":
        return "test-evidence-source-bound"
    return "code-evidence-source-bound"


v53p_summary = read_csv(results / "v53p_complete_source_system_de_open_weight_rag_measured_summary.csv")[0]
if v53p_summary.get("v53p_complete_source_system_de_open_weight_rag_ready") != "1":
    raise SystemExit("v53q requires v53p_complete_source_system_de_open_weight_rag_ready=1")
if v53p_summary.get("required_core_systems_ready") != "1":
    raise SystemExit("v53q requires all A/B/C/D/E/G/H core rows")

for rel in [
    "supplied_v53j/answer_rows.csv",
    "supplied_v53j/citation_rows.csv",
    "supplied_v53j/resource_rows.csv",
    "v53j_partial_supplied_validation_rows.csv",
    "system_de_model_identity_rows.csv",
    "V53P_COMPLETE_SOURCE_SYSTEM_DE_BOUNDARY.md",
    "v53p_complete_source_system_de_open_weight_rag_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
]:
    copy(v53p_dir / rel, f"source_v53p/{rel}")
copy(results / "v53p_complete_source_system_de_open_weight_rag_measured_summary.csv", "source_v53p/v53p_complete_source_system_de_open_weight_rag_measured_summary.csv")
copy(results / "v53p_complete_source_system_de_open_weight_rag_measured_decision.csv", "source_v53p/v53p_complete_source_system_de_open_weight_rag_measured_decision.csv")

queries = read_csv(v53p_dir / "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv")
span_rows = read_csv(v53p_dir / "source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv")
query_by_id = {row["query_id"]: row for row in queries}
span_by_id = {row["source_span_id"]: row for row in span_rows}
if len(queries) != 1000 or len(span_rows) != 1000:
    raise SystemExit("v53q requires the v53i 1000 query/span set")

answer_rows = read_csv(v53p_dir / "supplied_v53j/answer_rows.csv")
citation_rows = read_csv(v53p_dir / "supplied_v53j/citation_rows.csv")
resource_rows = read_csv(v53p_dir / "supplied_v53j/resource_rows.csv")
if len(answer_rows) != 7000 or len(citation_rows) != 7000 or len(resource_rows) != 7000:
    raise SystemExit("v53q requires 7000 A/B/C/D/E/G/H answer/citation/resource rows")

citations_by_answer = defaultdict(list)
for row in citation_rows:
    citations_by_answer[row["answer_id"]].append(row)
resource_by_id = {row["resource_row_id"]: row for row in resource_rows}

scorer_rows = []
policy_rows = []
system_counts = {system_id: Counter() for system_id in CORE_SYSTEMS}
query_counts = {query_id: Counter() for query_id in query_by_id}
policy_counts = Counter()

for row in answer_rows:
    answer_id = row["answer_id"]
    system_id = row["system_id"]
    query = query_by_id[row["query_id"]]
    span = span_by_id[query["source_span_id"]]
    citations = citations_by_answer.get(answer_id, [])
    primary_citation = citations[0] if citations else {}
    resource = resource_by_id.get(row["resource_row_id"], {})

    answer_hash_match = int(row.get("answer_text_sha256", "") == query["expected_answer_sha256"])
    predicted_behavior_match = int(row.get("predicted_behavior", "") == query["expected_behavior"])
    abstain_expected = int(query["expected_behavior"] == "abstain")
    abstained = int(row.get("abstained", "0") == "1")
    citation_row_bound = int(len(citations) > 0)
    citation_span_match = int(primary_citation.get("source_span_id", "") == query["source_span_id"])
    citation_text_hash_match = int(primary_citation.get("citation_text_sha256", "") == span["evidence_text_sha256"])
    source_file_hash_match = int(primary_citation.get("source_file_sha256", "") == span["source_file_sha256"])
    resource_row_bound = int(bool(resource) and resource.get("answer_id", "") == answer_id and resource.get("query_id", "") == row["query_id"])
    if abstain_expected:
        abstain_policy_pass = int(abstained == 1)
    else:
        abstain_policy_pass = int(abstained == 0)
    source_verified_score = (citation_row_bound + citation_span_match + citation_text_hash_match + source_file_hash_match + resource_row_bound) / 5.0
    answer_quality_score = 1.0 if answer_hash_match else 0.0
    behavior_policy_score = (predicted_behavior_match + abstain_policy_pass) / 2.0
    symmetric_total_score = (answer_quality_score + source_verified_score + behavior_policy_score) / 3.0
    policy_name = domain_policy_for(query)
    policy_counts[policy_name] += 1

    scorer_rows.append(
        {
            "symmetric_scorer_id": f"v53q_scorer_{answer_id}",
            "answer_id": answer_id,
            "system_id": system_id,
            "query_id": row["query_id"],
            "expected_answer_sha256": query["expected_answer_sha256"],
            "answer_text_sha256": row.get("answer_text_sha256", ""),
            "answer_hash_match": str(answer_hash_match),
            "expected_behavior": query["expected_behavior"],
            "predicted_behavior": row.get("predicted_behavior", ""),
            "predicted_behavior_match": str(predicted_behavior_match),
            "abstain_expected": str(abstain_expected),
            "abstained": str(abstained),
            "citation_rows_for_answer": str(len(citations)),
            "citation_row_bound": str(citation_row_bound),
            "citation_span_match": str(citation_span_match),
            "citation_text_hash_match": str(citation_text_hash_match),
            "source_file_hash_match": str(source_file_hash_match),
            "resource_row_bound": str(resource_row_bound),
            "source_verified_score": f"{source_verified_score:.6f}",
            "answer_quality_score": f"{answer_quality_score:.6f}",
            "behavior_policy_score": f"{behavior_policy_score:.6f}",
            "symmetric_total_score": f"{symmetric_total_score:.6f}",
            "symmetric_scorer_policy_row": "1",
            "quality_comparison_claim_ready": "0",
        }
    )
    policy_rows.append(
        {
            "symmetric_policy_id": f"v53q_policy_{answer_id}",
            "answer_id": answer_id,
            "system_id": system_id,
            "query_id": row["query_id"],
            "source_category": query["source_category"],
            "audit_type": query["audit_type"],
            "negative_or_abstain": query["negative_or_abstain"],
            "domain_policy": policy_name,
            "domain_policy_applied": "1",
            "abstain_policy_pass": str(abstain_policy_pass),
            "source_span_policy_pass": str(int(citation_span_match and source_file_hash_match)),
            "resource_policy_pass": str(resource_row_bound),
            "symmetric_scorer_policy_row": "1",
            "quality_comparison_claim_ready": "0",
        }
    )

    counter = system_counts[system_id]
    counter["answer_rows"] += 1
    counter["answer_hash_match_rows"] += answer_hash_match
    counter["answer_hash_mismatch_rows"] += int(not answer_hash_match)
    counter["predicted_behavior_match_rows"] += predicted_behavior_match
    counter["abstain_expected_rows"] += abstain_expected
    counter["abstained_rows"] += abstained
    counter["abstain_policy_pass_rows"] += abstain_policy_pass
    counter["citation_span_match_rows"] += citation_span_match
    counter["citation_text_hash_match_rows"] += citation_text_hash_match
    counter["resource_row_bound_rows"] += resource_row_bound
    counter["source_verified_score_milli_total"] += round(source_verified_score * 1000)
    counter["symmetric_total_score_milli_total"] += round(symmetric_total_score * 1000)
    counter["quality_comparison_claim_ready_rows"] += 0

    qcounter = query_counts[row["query_id"]]
    qcounter["answer_rows"] += 1
    qcounter["answer_hash_match_rows"] += answer_hash_match
    qcounter["citation_span_match_rows"] += citation_span_match
    qcounter["resource_row_bound_rows"] += resource_row_bound
    qcounter["abstain_policy_pass_rows"] += abstain_policy_pass

write_csv(run_dir / "symmetric_scorer_rows.csv", list(scorer_rows[0].keys()), scorer_rows)
write_csv(run_dir / "symmetric_domain_policy_rows.csv", list(policy_rows[0].keys()), policy_rows)

system_metric_rows = []
for system_id in CORE_SYSTEMS:
    counter = system_counts[system_id]
    rows = counter["answer_rows"]
    system_metric_rows.append(
        {
            "system_id": system_id,
            "answer_rows": str(rows),
            "symmetric_scorer_rows": str(rows),
            "symmetric_policy_rows": str(rows),
            "answer_hash_match_rows": str(counter["answer_hash_match_rows"]),
            "answer_hash_mismatch_rows": str(counter["answer_hash_mismatch_rows"]),
            "predicted_behavior_match_rows": str(counter["predicted_behavior_match_rows"]),
            "abstain_expected_rows": str(counter["abstain_expected_rows"]),
            "abstained_rows": str(counter["abstained_rows"]),
            "abstain_policy_pass_rows": str(counter["abstain_policy_pass_rows"]),
            "citation_span_match_rows": str(counter["citation_span_match_rows"]),
            "citation_text_hash_match_rows": str(counter["citation_text_hash_match_rows"]),
            "resource_row_bound_rows": str(counter["resource_row_bound_rows"]),
            "avg_source_verified_score": f"{(counter['source_verified_score_milli_total'] / rows / 1000):.6f}",
            "avg_symmetric_total_score": f"{(counter['symmetric_total_score_milli_total'] / rows / 1000):.6f}",
            "quality_comparison_claim_ready": "0",
        }
    )
write_csv(run_dir / "symmetric_system_metric_rows.csv", list(system_metric_rows[0].keys()), system_metric_rows)

query_metric_rows = []
for query in queries:
    counter = query_counts[query["query_id"]]
    query_metric_rows.append(
        {
            "query_id": query["query_id"],
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "expected_behavior": query["expected_behavior"],
            "negative_or_abstain": query["negative_or_abstain"],
            "answer_rows": str(counter["answer_rows"]),
            "answer_hash_match_rows": str(counter["answer_hash_match_rows"]),
            "citation_span_match_rows": str(counter["citation_span_match_rows"]),
            "resource_row_bound_rows": str(counter["resource_row_bound_rows"]),
            "abstain_policy_pass_rows": str(counter["abstain_policy_pass_rows"]),
            "all_core_systems_scored": str(int(counter["answer_rows"] == len(CORE_SYSTEMS))),
        }
    )
write_csv(run_dir / "symmetric_query_metric_rows.csv", list(query_metric_rows[0].keys()), query_metric_rows)

policy_summary_rows = [
    {
        "domain_policy": policy,
        "policy_rows": str(count),
        "symmetric_scorer_policy_row": "1",
        "quality_comparison_claim_ready": "0",
    }
    for policy, count in sorted(policy_counts.items())
]
write_csv(run_dir / "symmetric_policy_summary_rows.csv", list(policy_summary_rows[0].keys()), policy_summary_rows)

validation_rows = []
for system_id in CORE_SYSTEMS:
    counter = system_counts[system_id]
    ready = int(counter["answer_rows"] == 1000 and counter["citation_span_match_rows"] == 1000 and counter["resource_row_bound_rows"] == 1000)
    validation_rows.append(
        {
            "system_id": system_id,
            "target_scorer_rows": "1000",
            "target_policy_rows": "1000",
            "valid_scorer_rows": str(counter["answer_rows"]),
            "valid_policy_rows": str(counter["answer_rows"]),
            "source_bound_rows": str(counter["citation_span_match_rows"]),
            "resource_bound_rows": str(counter["resource_row_bound_rows"]),
            "status": "valid" if ready else "missing-or-invalid",
        }
    )
write_csv(run_dir / "symmetric_scorer_policy_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

all_systems_scored = int(all(row["status"] == "valid" for row in validation_rows))
scorer_policy_ready = int(len(scorer_rows) == 7000 and len(policy_rows) == 7000 and all_systems_scored)
total_hash_match_rows = sum(system_counts[system_id]["answer_hash_match_rows"] for system_id in CORE_SYSTEMS)
total_citation_span_match_rows = sum(system_counts[system_id]["citation_span_match_rows"] for system_id in CORE_SYSTEMS)
total_resource_bound_rows = sum(system_counts[system_id]["resource_row_bound_rows"] for system_id in CORE_SYSTEMS)
total_abstain_policy_pass_rows = sum(system_counts[system_id]["abstain_policy_pass_rows"] for system_id in CORE_SYSTEMS)
summary = {
    "v53q_complete_source_symmetric_scorer_policy_ready": str(scorer_policy_ready),
    "v53_ready": "0",
    "v53p_complete_source_system_de_open_weight_rag_ready": v53p_summary["v53p_complete_source_system_de_open_weight_rag_ready"],
    "complete_source_query_rows": "1000",
    "core_system_count": str(len(CORE_SYSTEMS)),
    "core_answer_rows": str(len(answer_rows)),
    "symmetric_scorer_rows": str(len(scorer_rows)),
    "symmetric_policy_rows": str(len(policy_rows)),
    "symmetric_system_metric_rows": str(len(system_metric_rows)),
    "symmetric_query_metric_rows": str(len(query_metric_rows)),
    "answer_hash_match_rows": str(total_hash_match_rows),
    "answer_hash_mismatch_rows": str(len(answer_rows) - total_hash_match_rows),
    "citation_span_match_rows": str(total_citation_span_match_rows),
    "resource_row_bound_rows": str(total_resource_bound_rows),
    "abstain_policy_pass_rows": str(total_abstain_policy_pass_rows),
    "required_core_systems_ready": v53p_summary["required_core_systems_ready"],
    "answer_citation_resource_rows_ready": v53p_summary["answer_citation_resource_rows_ready"],
    "symmetric_scorer_policy_rows_ready": str(scorer_policy_ready),
    "quality_comparison_claim_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v53p-core-answer-input", "pass", "v53p A/B/C/D/E/G/H answer/citation/resource rows are bound"),
    ("symmetric-scorer-row-coverage", "pass" if len(scorer_rows) == 7000 else "blocked", f"symmetric_scorer_rows={len(scorer_rows)}"),
    ("symmetric-policy-row-coverage", "pass" if len(policy_rows) == 7000 else "blocked", f"symmetric_policy_rows={len(policy_rows)}"),
    ("all-core-systems-scored", "pass" if all_systems_scored else "blocked", "seven core systems have 1000 scorer/policy rows each"),
    ("source-citation-binding", "pass" if total_citation_span_match_rows == 7000 else "blocked", f"citation_span_match_rows={total_citation_span_match_rows}"),
    ("resource-binding", "pass" if total_resource_bound_rows == 7000 else "blocked", f"resource_row_bound_rows={total_resource_bound_rows}"),
    ("answer-quality-scored-not-claimed", "pass", f"answer_hash_match_rows={total_hash_match_rows}; quality_comparison_claim_ready=0"),
    ("human-review-artifacts", "blocked", "human/source review artifacts are not supplied"),
    ("v53-full-public-repo-audit", "blocked", "core rows and symmetric scoring exist, but review evidence is still required"),
    ("real-release-package", "blocked", "v53q is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md").write_text(
    "# v53q Complete Source Symmetric Scorer/Policy Boundary\n\n"
    "This layer applies the same source-verification scorer and domain/abstain policy checks to every A/B/C/D/E/G/H answer row over the frozen v53i complete-source 1000-query set. "
    "It closes scorer/policy row coverage, but it does not convert scores into a quality comparison or release claim.\n\n"
    "- complete_source_query_rows=1000\n"
    "- core_systems=A/B/C/D/E/G/H\n"
    f"- core_answer_rows={len(answer_rows)}\n"
    f"- symmetric_scorer_rows={len(scorer_rows)}\n"
    f"- symmetric_policy_rows={len(policy_rows)}\n"
    f"- answer_hash_match_rows={total_hash_match_rows}\n"
    f"- answer_hash_mismatch_rows={len(answer_rows) - total_hash_match_rows}\n"
    f"- citation_span_match_rows={total_citation_span_match_rows}\n"
    f"- resource_row_bound_rows={total_resource_bound_rows}\n"
    f"- symmetric_scorer_policy_rows_ready={scorer_policy_ready}\n"
    "- quality_comparison_claim_ready=0\n"
    "- review_artifacts_ready=0\n"
    "- v53_ready=0\n\n"
    "Still blocked:\n\n"
    "- human/source review artifacts and release evidence\n"
    "- v53 completion, v1.0 comparison, superiority, production, or release claims\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53q-complete-source-symmetric-scorer-policy",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53q_complete_source_symmetric_scorer_policy_ready": scorer_policy_ready,
    "v53_ready": 0,
    "complete_source_query_rows": 1000,
    "core_systems": CORE_SYSTEMS,
    "core_answer_rows": len(answer_rows),
    "symmetric_scorer_rows": len(scorer_rows),
    "symmetric_policy_rows": len(policy_rows),
    "answer_hash_match_rows": total_hash_match_rows,
    "citation_span_match_rows": total_citation_span_match_rows,
    "resource_row_bound_rows": total_resource_bound_rows,
    "symmetric_scorer_policy_rows_ready": scorer_policy_ready,
    "quality_comparison_claim_ready": 0,
    "review_artifacts_ready": 0,
    "real_release_package_ready": 0,
    "v53p_summary_sha256": sha256(results / "v53p_complete_source_system_de_open_weight_rag_measured_summary.csv"),
}
(run_dir / "v53q_complete_source_symmetric_scorer_policy_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "symmetric_scorer_rows.csv",
    "symmetric_domain_policy_rows.csv",
    "symmetric_system_metric_rows.csv",
    "symmetric_query_metric_rows.csv",
    "symmetric_policy_summary_rows.csv",
    "symmetric_scorer_policy_validation_rows.csv",
    "V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md",
    "v53q_complete_source_symmetric_scorer_policy_manifest.json",
    "source_v53p/supplied_v53j/answer_rows.csv",
    "source_v53p/supplied_v53j/citation_rows.csv",
    "source_v53p/supplied_v53j/resource_rows.csv",
    "source_v53p/v53j_partial_supplied_validation_rows.csv",
    "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
    "source_v53p/v53p_complete_source_system_de_open_weight_rag_measured_summary.csv",
    "source_v53p/v53p_complete_source_system_de_open_weight_rag_measured_decision.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53q_complete_source_symmetric_scorer_policy_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
