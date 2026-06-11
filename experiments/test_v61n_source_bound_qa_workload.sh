#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61n_source_bound_qa_workload/qa_001"
SUMMARY_CSV="$RESULTS_DIR/v61n_source_bound_qa_workload_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61n_source_bound_qa_workload_decision.csv"

"$ROOT_DIR/experiments/run_v61n_source_bound_qa_workload.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61n summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61n_source_bound_qa_workload_ready": "1",
    "v61j_one_command_ssd_resident_demo_ready": "1",
    "v61m_kv_cache_residency_eviction_policy_ready": "1",
    "v53g_complete_source_manifest_ready": "1",
    "v53c_materialized_canary_source_ready": "1",
    "source_bound_qa_workload_ready": "1",
    "source_bound_qa_ready": "1",
    "bound_repo_count": "10",
    "runtime_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "complete_source_1000_query_ready": "0",
    "complete_source_content_snapshot_ready": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "safetensors_page_hash_binding_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61n {field}: expected {value}, got {summary.get(field)}")

materialized_rows = int(summary["materialized_source_file_rows"])
abstain_count = int(summary["source_bound_abstain_rows"])
query_count = int(summary["source_bound_query_rows"])
supported_count = int(summary["source_bound_supported_answer_rows"])
citation_count = int(summary["source_bound_citation_rows"])
resource_count = int(summary["source_bound_resource_rows"])
if materialized_rows < 20:
    raise SystemExit(f"v61n expected at least 20 materialized source rows, got {materialized_rows}")
if abstain_count != int(summary["bound_repo_count"]):
    raise SystemExit("v61n should emit one abstain row per bound repo")
if supported_count != materialized_rows:
    raise SystemExit("v61n supported answers should match materialized source rows")
if query_count != supported_count + abstain_count:
    raise SystemExit("v61n query count should equal supported plus abstain rows")
if citation_count != query_count or resource_count != query_count:
    raise SystemExit("v61n citation/resource rows should match query rows")
if int(summary["complete_source_manifest_binding_rows"]) != materialized_rows:
    raise SystemExit("v61n complete-source manifest bindings should match materialized source rows")
if int(summary["answer_citation_support_pass_rows"]) != query_count:
    raise SystemExit("v61n every answer should be citation-supported")
if int(summary["abstain_policy_verified_rows"]) != abstain_count:
    raise SystemExit("v61n every abstain should be policy verified")
if int(summary["source_category_doc_rows"]) <= 0 or int(summary["source_category_config_rows"]) <= 0:
    raise SystemExit("v61n should include doc and config source-bound rows")
if int(summary["source_category_source_rows"]) + int(summary["source_category_test_rows"]) <= 0:
    raise SystemExit("v61n should include code/test source-bound rows")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61j-one-command-input",
    "v61m-kv-policy-input",
    "v53g-complete-source-manifest-input",
    "materialized-canary-source-overlap",
    "source-bound-qa-workload-seed",
    "citation-support",
    "abstain-policy",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61n gate should pass: {gate}")
for gate in [
    "complete-source-1000-query-workload",
    "source-bound-model-generation",
    "safetensors-page-hash-binding",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61n gate should remain blocked: {gate}")

required_files = [
    "source_manifest_binding_rows.csv",
    "source_bound_query_rows.csv",
    "source_bound_answer_rows.csv",
    "source_bound_citation_rows.csv",
    "source_bound_abstain_rows.csv",
    "source_bound_resource_rows.csv",
    "runtime_binding_rows.csv",
    "runtime_gap_rows.csv",
    "V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md",
    "v61n_source_bound_qa_workload_manifest.json",
    "sha256_manifest.csv",
    "source_v61j/runtime_summary.csv",
    "source_v61m/kv_residency_policy_rows.csv",
    "source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53c/public_repo_canary_source_snapshot_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61n artifact: {rel}")

binding_rows = read_csv(run_dir / "source_manifest_binding_rows.csv")
if len(binding_rows) != materialized_rows:
    raise SystemExit("v61n materialized source file count mismatch")
if {row["v53g_manifest_canary_overlap"] for row in binding_rows} != {"1"}:
    raise SystemExit("v61n every source row should overlap v53g canary binding")
if {row["v53g_content_materialized"] for row in binding_rows} != {"0"}:
    raise SystemExit("v61n should keep v53g complete-source content materialization blocked")
if {row["v53c_content_materialized"] for row in binding_rows} != {"1"}:
    raise SystemExit("v61n should materialize only the v53c canary-overlap source subset")
for row in binding_rows:
    copied = run_dir / row["local_source_copy"]
    if not copied.is_file():
        raise SystemExit(f"missing copied source: {row['local_source_copy']}")
    if sha256(copied) != row["content_sha256"]:
        raise SystemExit(f"copied source hash mismatch: {row['local_source_copy']}")

query_rows = read_csv(run_dir / "source_bound_query_rows.csv")
answer_rows = read_csv(run_dir / "source_bound_answer_rows.csv")
citation_rows = read_csv(run_dir / "source_bound_citation_rows.csv")
resource_rows = read_csv(run_dir / "source_bound_resource_rows.csv")
abstain_rows = read_csv(run_dir / "source_bound_abstain_rows.csv")
if not (len(query_rows) == len(answer_rows) == len(citation_rows) == len(resource_rows) == query_count):
    raise SystemExit("v61n source-bound row count mismatch")
if len(abstain_rows) != abstain_count:
    raise SystemExit("v61n abstain row count mismatch")
if sum(1 for row in answer_rows if row["answer_status"] == "answered") != supported_count:
    raise SystemExit("v61n supported answer count mismatch")
if sum(1 for row in answer_rows if row["answer_status"] == "abstained") != abstain_count:
    raise SystemExit("v61n abstained answer count mismatch")
if any(row["answer_supported_by_citation"] != "1" for row in answer_rows):
    raise SystemExit("v61n every answer should be citation-supported")
if any(row["citation_supports_answer"] != "1" for row in citation_rows):
    raise SystemExit("v61n every citation should support its answer")
if any(row["real_checkpoint_weight_bytes_materialized"] != "0" for row in resource_rows):
    raise SystemExit("v61n resource rows should not materialize checkpoint weights")

runtime_binding = read_csv(run_dir / "runtime_binding_rows.csv")[0]
if runtime_binding["runtime_binding_ready"] != "1" or runtime_binding["actual_model_generation_ready"] != "0":
    raise SystemExit("v61n runtime binding boundary mismatch")

gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
for gap in [
    "complete-source-content-materialization",
    "complete-source-1000-query-workload",
    "source-bound-model-generation",
    "safetensors-page-hash-binding",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61n gap should remain blocked: {gap}")

manifest = json.loads((run_dir / "v61n_source_bound_qa_workload_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61n_source_bound_qa_workload_ready") != 1:
    raise SystemExit("v61n manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0 or manifest.get("complete_source_1000_query_ready") != 0:
    raise SystemExit("v61n manifest should keep generation and complete-source scale blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61n sha256 mismatch: {rel}")
for row in binding_rows:
    rel = row["local_source_copy"]
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61n source sha256 manifest mismatch: {rel}")

boundary = (run_dir / "V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "source-bound QA workload seed",
    "source_bound_qa_workload_ready=1",
    "actual_model_generation_ready=0",
    "complete_source_1000_query_ready=0",
    "Blocked wording: complete-source 1000+ audit completion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61n boundary missing {snippet}")
PY

echo "v61n source-bound QA workload smoke passed"
