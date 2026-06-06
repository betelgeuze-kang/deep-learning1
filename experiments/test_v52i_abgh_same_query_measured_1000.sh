#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52i_abgh_same_query_measured_1000/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v52i_abgh_same_query_measured_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52i_abgh_same_query_measured_1000_decision.csv"

V52I_REUSE_EXISTING="${V52I_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52i_abgh_same_query_measured_1000.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v52i summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52i_abgh_same_query_measured_1000_ready": "1",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "system_rows": "4",
    "systems": "A/B/G/H",
    "query_rows": "1000",
    "answer_rows": "4000",
    "citation_rows": "4000",
    "retrieval_rows": "12000",
    "abstain_rows": "4000",
    "wrong_answer_guard_rows": "4000",
    "resource_rows": "4000",
    "routehint_rows": "2000",
    "same_query_set_all_local_systems": "1",
    "same_source_manifest_all_local_systems": "1",
    "external_network_used": "0",
    "external_model_used": "0",
    "v53e_canary_query_scale_ready": "1",
    "abgh_local_comparison_absorb_ready": "1",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52i {field}: expected {value}, got {summary.get(field)}")
if int(summary["source_manifest_rows"]) <= 0:
    raise SystemExit("v52i should emit source manifest rows")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "abgh-same-query-measured",
    "same-frozen-query-set",
    "same-source-manifest",
    "routehint-local-rows",
    "no-external-model",
    "v52-local-abgh-absorb-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52i gate should pass: {gate}")
for gate in [
    "c-d-e-evidence-directories",
    "required-30b-70b-baselines",
    "v52-full-baseline-war",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52i gate should remain blocked: {gate}")

required_files = [
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
    "sha256_manifest.csv",
    "source_v53e/scaled_canary_query_rows.csv",
    "source_v53e/scaled_canary_source_span_rows.csv",
    "source_v53e/scaled_canary_query_repo_rows.csv",
    "source_v53e/scaled_canary_query_family_rows.csv",
    "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "source_v53e/v53e_canary_query_scale_1000_manifest.json",
    "source_v53e/sha256_manifest.csv",
    "source_v53e/v53e_canary_query_scale_1000_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52i artifact: {rel}")

queries = read_csv(run_dir / "frozen_query_rows.csv")
spans = read_csv(run_dir / "frozen_source_span_rows.csv")
systems = read_csv(run_dir / "abgh_system_rows.csv")
answers = read_csv(run_dir / "abgh_answer_rows.csv")
citations = read_csv(run_dir / "abgh_citation_rows.csv")
retrieval = read_csv(run_dir / "abgh_retrieval_rows.csv")
abstain = read_csv(run_dir / "abgh_abstain_rows.csv")
guards = read_csv(run_dir / "abgh_wrong_answer_guard_rows.csv")
resources = read_csv(run_dir / "abgh_resource_rows.csv")
hints = read_csv(run_dir / "routehint_rows.csv")
metrics = read_csv(run_dir / "abgh_system_metric_rows.csv")
query_ids = {row["query_id"] for row in queries}
if len(queries) != 1000 or len(spans) != 1000:
    raise SystemExit("v52i should contain 1000 frozen query/source rows")
if {row["system_id"] for row in systems} != SYSTEMS:
    raise SystemExit("v52i should cover A/B/G/H systems")
if any(row["query_rows"] != "1000" or row["external_model_used"] != "0" for row in systems):
    raise SystemExit("v52i system rows should bind 1000 local rows")
for table_name, rows, expected_count in [
    ("answers", answers, 4000),
    ("citations", citations, 4000),
    ("abstain", abstain, 4000),
    ("guards", guards, 4000),
    ("resources", resources, 4000),
]:
    if len(rows) != expected_count:
        raise SystemExit(f"v52i {table_name} should contain {expected_count} rows")
    for system_id in SYSTEMS:
        system_query_ids = {row["query_id"] for row in rows if row["system_id"] == system_id}
        if system_query_ids != query_ids:
            raise SystemExit(f"v52i {table_name} should cover every query for {system_id}")
if len(retrieval) != 12000:
    raise SystemExit("v52i retrieval should contain three rows per query per system")
if len(hints) != 2000 or {row["system_id"] for row in hints} != {"G", "H"}:
    raise SystemExit("v52i RouteHint rows should cover G/H only")
if any(row["raw_context_appended"] != "0" for row in hints):
    raise SystemExit("v52i RouteHint rows should avoid raw context appending")
for row in answers:
    if row["system_id"] not in SYSTEMS:
        raise SystemExit("v52i answer system mismatch")
    if row["predicted_answer_sha256"] != sha256_text(row["predicted_answer"]):
        raise SystemExit("v52i predicted answer hash mismatch")
    if int(row["latency_ns"]) <= 0:
        raise SystemExit("v52i answer rows should carry latency")
for row in resources:
    if row["external_model_used"] != "0" or row["external_network_used"] != "0":
        raise SystemExit("v52i resources should remain local/no external model")
    if row["system_id"] in {"G", "H"} and (row["route_memory_store_used"] != "1" or row["compact_routehint_used"] != "1"):
        raise SystemExit("v52i G/H resources should use RouteMemory and RouteHint")
    if row["system_id"] == "H" and (row["source_verified_scorer_used"] != "1" or row["domain_policy_used"] != "1"):
        raise SystemExit("v52i H resources should use scorer and domain policy")
    if row["system_id"] in {"A", "B"} and (row["route_memory_store_used"] != "0" or row["compact_routehint_used"] != "0"):
        raise SystemExit("v52i A/B resources should not use RouteMemory/RouteHint")
if any(row["wrong_answer"] not in {"0", "1"} or row["guard_status"] not in {"pass", "wrong-answer"} for row in guards):
    raise SystemExit("v52i guard rows should use valid status fields")
metric_by_id = {row["system_id"]: row for row in metrics}
if set(metric_by_id) != SYSTEMS:
    raise SystemExit("v52i metrics should cover A/B/G/H")
for system_id, row in metric_by_id.items():
    if row["answer_rows"] != "1000" or row["citation_rows"] != "1000" or row["resource_rows"] != "1000":
        raise SystemExit(f"v52i metric counts mismatch for {system_id}")
if metric_by_id["G"]["correct_rows"] != "1000" or metric_by_id["H"]["correct_rows"] != "1000":
    raise SystemExit("v52i G/H should close deterministic local routehint answer rows")
if metric_by_id["G"]["citation_correct_rows"] != "1000" or metric_by_id["H"]["citation_correct_rows"] != "1000":
    raise SystemExit("v52i G/H should cite the frozen source spans")

manifest = json.loads((run_dir / "v52i_abgh_same_query_measured_1000_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52i_abgh_same_query_measured_1000_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52i manifest readiness mismatch")
if manifest.get("systems") != ["A", "B", "G", "H"] or manifest.get("answer_rows") != 4000:
    raise SystemExit("v52i manifest should bind A/B/G/H answer rows")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52i sha256 mismatch: {rel}")

boundary = (run_dir / "V52I_ABGH_SAME_QUERY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "A/B/G/H over the full frozen v53e 1000-row canary query set",
    "systems=A/B/G/H",
    "answer_rows=4000",
    "routehint_rows=2000",
    "external_model_used=0",
    "Do not publish 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52i boundary missing {snippet}")
PY

echo "v52i A/B/G/H same-query measured 1000 smoke passed"
