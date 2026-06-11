#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53q_complete_source_symmetric_scorer_policy/score_001"
SUMMARY_CSV="$RESULTS_DIR/v53q_complete_source_symmetric_scorer_policy_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53q_complete_source_symmetric_scorer_policy_decision.csv"

V53Q_REUSE_EXISTING="${V53Q_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53q_complete_source_symmetric_scorer_policy.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53q_complete_source_symmetric_scorer_policy_ready": "1",
    "v53_ready": "0",
    "v53p_complete_source_system_de_open_weight_rag_ready": "1",
    "complete_source_query_rows": "1000",
    "core_system_count": "7",
    "core_answer_rows": "7000",
    "symmetric_scorer_rows": "7000",
    "symmetric_policy_rows": "7000",
    "symmetric_system_metric_rows": "7",
    "symmetric_query_metric_rows": "1000",
    "answer_hash_match_rows": "6000",
    "answer_hash_mismatch_rows": "1000",
    "citation_span_match_rows": "7000",
    "resource_row_bound_rows": "7000",
    "abstain_policy_pass_rows": "6877",
    "required_core_systems_ready": "1",
    "answer_citation_resource_rows_ready": "1",
    "symmetric_scorer_policy_rows_ready": "1",
    "quality_comparison_claim_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53q {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53p-core-answer-input",
    "symmetric-scorer-row-coverage",
    "symmetric-policy-row-coverage",
    "all-core-systems-scored",
    "source-citation-binding",
    "resource-binding",
    "answer-quality-scored-not-claimed",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53q gate should pass: {gate}")
for gate in ["human-review-artifacts", "v53-full-public-repo-audit", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53q gate should remain blocked: {gate}")

required_files = [
    "symmetric_scorer_rows.csv",
    "symmetric_domain_policy_rows.csv",
    "symmetric_system_metric_rows.csv",
    "symmetric_query_metric_rows.csv",
    "symmetric_policy_summary_rows.csv",
    "symmetric_scorer_policy_validation_rows.csv",
    "V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md",
    "v53q_complete_source_symmetric_scorer_policy_manifest.json",
    "sha256_manifest.csv",
    "source_v53p/supplied_v53j/answer_rows.csv",
    "source_v53p/supplied_v53j/citation_rows.csv",
    "source_v53p/supplied_v53j/resource_rows.csv",
    "source_v53p/v53j_partial_supplied_validation_rows.csv",
    "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_query_rows.csv",
    "source_v53p/source_v53o/source_v53n/source_v53m/source_v53l/source_v53k/source_v53j/source_v53i/complete_source_span_rows.csv",
    "source_v53p/v53p_complete_source_system_de_open_weight_rag_measured_summary.csv",
    "source_v53p/v53p_complete_source_system_de_open_weight_rag_measured_decision.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53q artifact: {rel}")

scorer = read_csv(run_dir / "symmetric_scorer_rows.csv")
policy = read_csv(run_dir / "symmetric_domain_policy_rows.csv")
system_metrics = {row["system_id"]: row for row in read_csv(run_dir / "symmetric_system_metric_rows.csv")}
query_metrics = read_csv(run_dir / "symmetric_query_metric_rows.csv")
validation = {row["system_id"]: row for row in read_csv(run_dir / "symmetric_scorer_policy_validation_rows.csv")}
if len(scorer) != 7000 or len(policy) != 7000:
    raise SystemExit("v53q scorer/policy row count mismatch")
if len(system_metrics) != 7 or len(query_metrics) != 1000:
    raise SystemExit("v53q metric row count mismatch")

expected_systems = {"A", "B", "C", "D", "E", "G", "H"}
if set(system_metrics) != expected_systems or set(validation) != expected_systems:
    raise SystemExit("v53q core system coverage mismatch")
for system_id, row in system_metrics.items():
    if row["answer_rows"] != "1000" or row["symmetric_scorer_rows"] != "1000" or row["symmetric_policy_rows"] != "1000":
        raise SystemExit(f"v53q {system_id} row coverage mismatch")
    if row["citation_span_match_rows"] != "1000" or row["resource_row_bound_rows"] != "1000":
        raise SystemExit(f"v53q {system_id} source/resource binding mismatch")
    if row["quality_comparison_claim_ready"] != "0":
        raise SystemExit(f"v53q {system_id} should not claim quality readiness")
    if validation[system_id]["status"] != "valid":
        raise SystemExit(f"v53q validation should mark {system_id} valid")

for system_id in ["A", "B", "D", "E", "G", "H"]:
    if system_metrics[system_id]["answer_hash_match_rows"] != "1000":
        raise SystemExit(f"v53q {system_id} should have 1000 hash matches")
    if system_metrics[system_id]["abstain_policy_pass_rows"] != "1000":
        raise SystemExit(f"v53q {system_id} should pass abstain policy")
if system_metrics["C"]["answer_hash_match_rows"] != "0" or system_metrics["C"]["answer_hash_mismatch_rows"] != "1000":
    raise SystemExit("v53q should preserve System C mismatch evidence")
if system_metrics["C"]["abstain_policy_pass_rows"] != "877":
    raise SystemExit("v53q should preserve System C abstain-policy misses")

for row in scorer:
    if row["symmetric_scorer_policy_row"] != "1" or row["quality_comparison_claim_ready"] != "0":
        raise SystemExit("v53q scorer rows should be symmetric but not claim quality readiness")
    for field in ["citation_row_bound", "citation_span_match", "citation_text_hash_match", "source_file_hash_match", "resource_row_bound"]:
        if row[field] != "1":
            raise SystemExit(f"v53q scorer source binding field should pass: {field}")
for row in policy:
    if row["symmetric_scorer_policy_row"] != "1" or row["quality_comparison_claim_ready"] != "0":
        raise SystemExit("v53q policy rows should be symmetric but not claim quality readiness")
    if row["domain_policy_applied"] != "1" or row["source_span_policy_pass"] != "1" or row["resource_policy_pass"] != "1":
        raise SystemExit("v53q policy source/resource rows should pass")
for row in query_metrics:
    if row["answer_rows"] != "7" or row["all_core_systems_scored"] != "1":
        raise SystemExit("v53q each query should have seven scored core answers")
    if row["citation_span_match_rows"] != "7" or row["resource_row_bound_rows"] != "7":
        raise SystemExit("v53q query metric source/resource binding mismatch")

manifest = json.loads((run_dir / "v53q_complete_source_symmetric_scorer_policy_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53q_complete_source_symmetric_scorer_policy_ready") != 1 or manifest.get("v53_ready") != 0:
    raise SystemExit("v53q manifest readiness boundary mismatch")
if manifest.get("symmetric_scorer_rows") != 7000 or manifest.get("quality_comparison_claim_ready") != 0:
    raise SystemExit("v53q manifest scorer/claim boundary mismatch")

boundary = (run_dir / "V53Q_COMPLETE_SOURCE_SYMMETRIC_SCORER_POLICY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "core_systems=A/B/C/D/E/G/H",
    "core_answer_rows=7000",
    "symmetric_scorer_rows=7000",
    "symmetric_policy_rows=7000",
    "answer_hash_match_rows=6000",
    "answer_hash_mismatch_rows=1000",
    "symmetric_scorer_policy_rows_ready=1",
    "quality_comparison_claim_ready=0",
    "review_artifacts_ready=0",
    "v53_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53q boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in sha_rows:
        raise SystemExit(f"v53q sha manifest missing: {rel}")
    if sha_rows[rel] != sha256(run_dir / rel):
        raise SystemExit(f"v53q sha256 mismatch: {rel}")
PY

echo "v53q complete-source symmetric scorer/policy smoke passed"
