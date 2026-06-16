#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53ap_complete_source_abgh_same_query_measured/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v53ap_complete_source_abgh_same_query_measured_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53ap_complete_source_abgh_same_query_measured_decision.csv"

V53AP_REUSE_EXISTING="${V53AP_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v53ap_complete_source_abgh_same_query_measured.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
SYSTEMS = {"A", "B", "G", "H"}


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


summary = read_csv(summary_csv)[0]
expected = {
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "v53_ready": "0",
    "query_set_id": "v53i_complete_source_1000",
    "system_rows": "4",
    "systems": "A/B/G/H",
    "query_rows": "1000",
    "answer_rows": "4000",
    "citation_rows": "4000",
    "retrieval_rows": "4000",
    "adapter_trace_rows": "4000",
    "system_distinct_adapter_trace_ready": "1",
    "abstain_rows": "4000",
    "wrong_answer_guard_rows": "4000",
    "resource_rows": "4000",
    "routehint_rows": "2000",
    "negative_abstain_rows": "160",
    "missing_specific_abstain_rows": "30",
    "same_query_set_all_local_systems": "1",
    "same_source_manifest_all_local_systems": "1",
    "expected_answer_oracle_replay": "0",
    "expected_answer_oracle_replay_rows": "0",
    "deterministic_source_span_adapter_execution": "1",
    "deterministic_source_span_adapter_rows": "4000",
    "source_span_binding_match_rows": "4000",
    "actual_adapter_execution_ready": "1",
    "real_system_performance_claim_ready": "0",
    "external_network_used": "0",
    "external_model_used": "0",
    "internal_v1_0_pre_baseline_run": "1",
    "public_comparison_claim_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ap {field}: expected {value}, got {summary.get(field)}")

if summary["source_query_rows_sha256"] != sha256(run_dir / "source_v53i/complete_source_query_rows.csv"):
    raise SystemExit("v53ap query hash should bind source_v53i query rows")
if summary["source_span_rows_sha256"] != sha256(run_dir / "source_v53i/complete_source_span_rows.csv"):
    raise SystemExit("v53ap span hash should bind source_v53i span rows")

required_files = [
    "source_manifest_rows.csv",
    "abgh_system_rows.csv",
    "abgh_answer_rows.csv",
    "abgh_citation_rows.csv",
    "abgh_retrieval_rows.csv",
    "abgh_adapter_trace_rows.csv",
    "abgh_abstain_rows.csv",
    "abgh_wrong_answer_guard_rows.csv",
    "abgh_resource_rows.csv",
    "routehint_rows.csv",
    "abgh_system_metric_rows.csv",
    "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md",
    "v53ap_complete_source_abgh_same_query_measured_manifest.json",
    "sha256_manifest.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/complete_source_query_family_rows.csv",
    "source_v53i/complete_source_control_family_rows.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ap artifact: {rel}")

queries = read_csv(run_dir / "source_v53i/complete_source_query_rows.csv")
answers = read_csv(run_dir / "abgh_answer_rows.csv")
citations = read_csv(run_dir / "abgh_citation_rows.csv")
retrieval = read_csv(run_dir / "abgh_retrieval_rows.csv")
adapter_traces = read_csv(run_dir / "abgh_adapter_trace_rows.csv")
abstain = read_csv(run_dir / "abgh_abstain_rows.csv")
guards = read_csv(run_dir / "abgh_wrong_answer_guard_rows.csv")
resources = read_csv(run_dir / "abgh_resource_rows.csv")
hints = read_csv(run_dir / "routehint_rows.csv")
metrics = {row["system_id"]: row for row in read_csv(run_dir / "abgh_system_metric_rows.csv")}
query_ids = {row["query_id"] for row in queries}
if len(queries) != 1000:
    raise SystemExit("v53ap should bind 1000 source queries")
if {row["system_id"] for row in read_csv(run_dir / "abgh_system_rows.csv")} != SYSTEMS:
    raise SystemExit("v53ap should cover A/B/G/H systems")
system_rows = {row["system_id"]: row for row in read_csv(run_dir / "abgh_system_rows.csv")}
for system_id, row in system_rows.items():
    if row["execution_mode"] != "deterministic-source-span-adapter":
        raise SystemExit(f"v53ap should disclose deterministic source-span adapter execution mode for {system_id}")
    if (
        row["expected_answer_oracle_replay"] != "0"
        or row["deterministic_source_span_adapter_execution"] != "1"
        or row["actual_adapter_execution_ready"] != "1"
    ):
        raise SystemExit(f"v53ap system row boundary mismatch for {system_id}")
for table_name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("retrieval", retrieval),
    ("adapter_traces", adapter_traces),
    ("abstain", abstain),
    ("guards", guards),
    ("resources", resources),
]:
    if len(rows) != 4000:
        raise SystemExit(f"v53ap {table_name} row count mismatch")
    for system_id in SYSTEMS:
        if {row["query_id"] for row in rows if row["system_id"] == system_id} != query_ids:
            raise SystemExit(f"v53ap {table_name} should cover every query for {system_id}")

if len(hints) != 2000 or {row["system_id"] for row in hints} != {"G", "H"}:
    raise SystemExit("v53ap RouteHint rows should cover G/H only")
if any(row["raw_context_appended"] != "0" for row in hints):
    raise SystemExit("v53ap RouteHint rows must not append raw context")

trace_types = {
    "A": "lexical-source-span",
    "B": "small-local-rag-source-window",
    "G": "routememory-routehint",
    "H": "routememory-routehint-scorer-policy",
}
for system_id, trace_type in trace_types.items():
    rows = [row for row in adapter_traces if row["system_id"] == system_id]
    if len(rows) != 1000:
        raise SystemExit(f"v53ap adapter trace row count mismatch for {system_id}")
    if {row["adapter_trace_type"] for row in rows} != {trace_type}:
        raise SystemExit(f"v53ap adapter trace type mismatch for {system_id}")
    if any(row["query_binding_used"] != "1" or row["source_span_binding_match"] != "1" for row in rows):
        raise SystemExit(f"v53ap adapter traces should bind query/source span for {system_id}")
if any(row["raw_context_appended"] != "1" or row["compact_routehint_used"] != "0" for row in adapter_traces if row["system_id"] in {"A", "B"}):
    raise SystemExit("v53ap A/B adapter traces should disclose raw local context and no RouteHint")
if any(row["source_window_used"] != "1" or int(row["source_window_bytes"]) <= 0 for row in adapter_traces if row["system_id"] == "B"):
    raise SystemExit("v53ap B adapter traces should disclose local source-window use")
if any(row["raw_context_appended"] != "0" or row["compact_routehint_used"] != "1" for row in adapter_traces if row["system_id"] in {"G", "H"}):
    raise SystemExit("v53ap G/H adapter traces should use compact RouteHint without raw prompt context")
if any(row["source_verified_scorer_used"] != "1" or row["domain_policy_used"] != "1" for row in adapter_traces if row["system_id"] == "H"):
    raise SystemExit("v53ap H adapter traces should disclose scorer/policy use")
if any(row["expected_answer_oracle_replay"] != "0" or row["real_system_performance_claim_ready"] != "0" for row in adapter_traces):
    raise SystemExit("v53ap adapter traces must keep oracle and performance claim boundaries closed")

for row in answers:
    if row["answer_text_sha256"] != sha256_text(row["answer_text"]):
        raise SystemExit("v53ap answer hash mismatch")
    if row["answer_source"] != "deterministic_source_span_adapter":
        raise SystemExit("v53ap answer rows must come from deterministic source-span adapters")
    if row["source_span_selection_method"] != "query-owner-path-line-lexical-deterministic" or row["source_span_binding_match"] != "1":
        raise SystemExit("v53ap answer rows must bind deterministic source-span selection")
    if row["strict_expected_answer_match"] != "1":
        raise SystemExit("v53ap deterministic adapter answer should match the source-bound expected hash")
    if row["system_id"] in {"G", "H"} and row["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v53ap G/H should not use raw prompt context bytes")
for row in resources:
    if row["external_model_used"] != "0" or row["external_network_used"] != "0":
        raise SystemExit("v53ap resources should be local/no external model")
    if row["execution_mode"] != "deterministic-source-span-adapter":
        raise SystemExit("v53ap resources must disclose deterministic source-span adapter execution")
    if (
        row["answer_source"] != "deterministic_source_span_adapter"
        or row["expected_answer_oracle_replay"] != "0"
        or row["deterministic_source_span_adapter_execution"] != "1"
        or row["actual_adapter_execution_ready"] != "1"
    ):
        raise SystemExit("v53ap resources must disclose non-oracle deterministic adapter execution")
    if row["system_id"] in {"G", "H"} and (row["route_memory_store_used"] != "1" or row["compact_routehint_used"] != "1"):
        raise SystemExit("v53ap G/H should bind RouteMemory/RouteHint resource fields")
    if row["system_id"] == "H" and (row["source_verified_scorer_used"] != "1" or row["domain_policy_used"] != "1"):
        raise SystemExit("v53ap H should bind scorer/policy resource fields")
for row in guards:
    if row["strict_expected_answer_match"] != "1" or row["wrong_answer"] != "0" or row["guard_status"] != "pass":
        raise SystemExit("v53ap wrong-answer guards should pass")

if set(metrics) != SYSTEMS:
    raise SystemExit("v53ap metric system coverage mismatch")
for system_id, row in metrics.items():
    if row["answer_rows"] != "1000" or row["citation_correct_rows"] != "1000" or row["resource_rows"] != "1000":
        raise SystemExit(f"v53ap metric counts mismatch for {system_id}")
    if row["adapter_trace_rows"] != "1000":
        raise SystemExit(f"v53ap adapter trace metric mismatch for {system_id}")
    if row["missing_specific_query_rows"] != "30":
        raise SystemExit(f"v53ap missing-specific count mismatch for {system_id}")
    if (
        row["expected_answer_oracle_replay_rows"] != "0"
        or row["deterministic_source_span_adapter_rows"] != "1000"
        or row["source_span_binding_match_rows"] != "1000"
        or row["actual_adapter_execution_ready"] != "1"
    ):
        raise SystemExit(f"v53ap deterministic adapter metric boundary mismatch for {system_id}")
    if row["quality_comparison_claim_ready"] != "0":
        raise SystemExit("v53ap must not mark quality comparison ready")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53i-complete-source-input",
    "abgh-same-query-measured",
    "system-distinct-adapter-trace",
    "same-source-manifest",
    "routehint-local-rows",
    "missing-specific-abstain-control",
    "no-external-model",
    "expected-answer-oracle-replay-absent",
    "deterministic-source-span-adapter-execution",
    "internal-pre-baseline-only",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ap gate should pass: {gate}")
for gate in ["real-system-performance-claim", "required-30b-70b-baselines", "v53-full-audit-ready", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ap gate should remain blocked: {gate}")

manifest = json.loads((run_dir / "v53ap_complete_source_abgh_same_query_measured_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ap_complete_source_abgh_same_query_measured_ready") != 1:
    raise SystemExit("v53ap manifest readiness mismatch")
if manifest.get("systems") != ["A", "B", "G", "H"] or manifest.get("missing_specific_abstain_rows") != 30:
    raise SystemExit("v53ap manifest system/control mismatch")
if (
    manifest.get("expected_answer_oracle_replay") != 0
    or manifest.get("expected_answer_oracle_replay_rows") != 0
    or manifest.get("deterministic_source_span_adapter_execution") != 1
    or manifest.get("deterministic_source_span_adapter_rows") != 4000
    or manifest.get("adapter_trace_rows") != 4000
    or manifest.get("system_distinct_adapter_trace_ready") != 1
    or manifest.get("source_span_binding_match_rows") != 4000
    or manifest.get("actual_adapter_execution_ready") != 1
):
    raise SystemExit("v53ap manifest deterministic adapter boundary mismatch")
if manifest.get("public_comparison_claim_ready") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v53ap manifest claim boundary mismatch")

boundary = (run_dir / "V53AP_COMPLETE_SOURCE_ABGH_SAME_QUERY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "internal v1.0 pre-baseline",
    "systems=A/B/G/H",
    "answer_rows=4000",
    "adapter_trace_rows=4000",
    "system_distinct_adapter_trace_ready=1",
    "routehint_rows=2000",
    "missing_specific_abstain_rows=30",
    "expected_answer_oracle_replay=0",
    "deterministic_source_span_adapter_execution=1",
    "deterministic_source_span_adapter_rows=4000",
    "actual_adapter_execution_ready=1",
    "real_system_performance_claim_ready=0",
    "public_comparison_claim_ready=0",
    "required_30b_baseline_ready=0",
    "required_70b_baseline_ready=0",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ap boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ap sha256 mismatch: {rel}")
PY

echo "v53ap complete-source A/B/G/H same-query smoke passed"
