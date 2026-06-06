#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52f_small_local_rag_measured_100/measured_001"
SUMMARY_CSV="$RESULTS_DIR/v52f_small_local_rag_measured_100_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52f_small_local_rag_measured_100_decision.csv"

V52F_REUSE_EXISTING="${V52F_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52f_small_local_rag_measured_100.sh" >/dev/null

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


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v52f summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52f_small_local_rag_measured_100_ready": "1",
    "system_id": "B",
    "baseline_name": "small local RAG",
    "query_set_id": "v53d_canary_source_query_seed_100",
    "query_rows": "100",
    "answer_rows": "100",
    "citation_rows": "100",
    "abstain_rows": "100",
    "wrong_answer_guard_rows": "100",
    "resource_rows": "100",
    "external_network_used": "0",
    "external_model_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v53d_canary_query_seed_ready": "1",
    "v52_absorb_ready": "1",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52f {field}: expected {value}, got {summary.get(field)}")
if int(summary["source_manifest_rows"]) <= 0:
    raise SystemExit("v52f should emit source manifest rows")
if int(summary["raw_prompt_context_total_bytes"]) <= 0:
    raise SystemExit("v52f should record prompt context bytes")
if int(summary["avg_latency_ns"]) <= 0:
    raise SystemExit("v52f should record measured latency")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["small-local-rag-100-measured", "same-frozen-query-set", "source-manifest", "no-external-model", "v52-absorb-ready"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52f gate should pass: {gate}")
for gate in ["v52-full-baseline-war", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52f gate should remain blocked: {gate}")

required_files = [
    "source_manifest_rows.csv",
    "small_local_rag_answer_rows.csv",
    "small_local_rag_citation_rows.csv",
    "small_local_rag_retrieval_rows.csv",
    "small_local_rag_abstain_rows.csv",
    "small_local_rag_wrong_answer_guard_rows.csv",
    "small_local_rag_resource_rows.csv",
    "V52F_SMALL_LOCAL_RAG_100_BOUNDARY.md",
    "v52f_small_local_rag_measured_100_manifest.json",
    "sha256_manifest.csv",
    "source_v53d/canary_query_rows.csv",
    "source_v53d/canary_source_span_rows.csv",
    "source_v53d/canary_query_repo_rows.csv",
    "source_v53d/canary_query_family_rows.csv",
    "source_v53d/V53D_CANARY_SOURCE_QUERY_SEED_BOUNDARY.md",
    "source_v53d/v53d_canary_source_query_seed_manifest.json",
    "source_v53d/sha256_manifest.csv",
    "source_v53d/v53d_canary_source_query_seed_100_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52f artifact: {rel}")

queries = read_csv(run_dir / "source_v53d/canary_query_rows.csv")
answers = read_csv(run_dir / "small_local_rag_answer_rows.csv")
citations = read_csv(run_dir / "small_local_rag_citation_rows.csv")
retrieval = read_csv(run_dir / "small_local_rag_retrieval_rows.csv")
abstain = read_csv(run_dir / "small_local_rag_abstain_rows.csv")
guards = read_csv(run_dir / "small_local_rag_wrong_answer_guard_rows.csv")
resources = read_csv(run_dir / "small_local_rag_resource_rows.csv")
query_ids = {row["query_id"] for row in queries}
for table_name, rows in [
    ("answers", answers),
    ("citations", citations),
    ("abstain", abstain),
    ("guards", guards),
    ("resources", resources),
]:
    if len(rows) != 100:
        raise SystemExit(f"v52f {table_name} should contain 100 rows")
    if {row["query_id"] for row in rows} != query_ids:
        raise SystemExit(f"v52f {table_name} should cover the frozen query IDs")
if len(retrieval) != 300:
    raise SystemExit("v52f retrieval should contain three rows per query")
for row in answers:
    if row["system_id"] != "B":
        raise SystemExit("v52f answer system_id should be B")
    if row["predicted_answer_sha256"] != sha256_text(row["predicted_answer"]):
        raise SystemExit("v52f predicted answer hash mismatch")
    if int(row["latency_ns"]) <= 0 or int(row["raw_prompt_context_bytes"]) <= 0:
        raise SystemExit("v52f answer rows should carry measured latency/context")
if any(row["external_model_used"] != "0" or row["external_network_used"] != "0" for row in resources):
    raise SystemExit("v52f resource rows should remain local/no external model")
if any(row["wrong_answer"] not in {"0", "1"} or row["guard_status"] not in {"pass", "wrong-answer"} for row in guards):
    raise SystemExit("v52f guard rows should use valid status fields")

manifest = json.loads((run_dir / "v52f_small_local_rag_measured_100_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52f_small_local_rag_measured_100_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52f manifest readiness mismatch")
if manifest.get("query_rows") != 100 or manifest.get("external_model_used") != 0:
    raise SystemExit("v52f manifest should bind 100 local rows")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52f sha256 mismatch: {rel}")

boundary = (run_dir / "V52F_SMALL_LOCAL_RAG_100_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "100-row measured expansion for baseline B",
    "query_rows=100",
    "wrong_answer_guard_rows=100",
    "external_model_used=0",
    "Do not publish 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52f boundary missing {snippet}")
PY

echo "v52f small local RAG measured 100 smoke passed"
