#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v54b_routehint_generation_scale_1000/scale_001"
SUMMARY_CSV="$RESULTS_DIR/v54b_routehint_generation_scale_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v54b_routehint_generation_scale_1000_decision.csv"

"$ROOT_DIR/experiments/run_v54b_routehint_generation_scale_1000.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
root = run_dir.parents[2]

DOMAIN_TARGETS = {
    "codebase_qa": 200,
    "internal_docs_qa": 180,
    "product_manual_qa": 160,
    "incident_log_qa": 160,
    "ruler_niah": 150,
    "longbench": 150,
}


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
    raise SystemExit(f"expected one v54b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v54b_routehint_generation_scale_ready": "1",
    "v54_generation_1000_ready": "1",
    "target_generation_rows": "1000",
    "generation_rows": "1000",
    "missing_generation_rows": "0",
    "domain_count": "6",
    "answer_rows": "900",
    "abstain_rows": "100",
    "route_memory_evidence_rows": "1000",
    "route_hint_used_rows": "1000",
    "hint_value_transformed_rows": "900",
    "answer_equals_hint_value_rows": "0",
    "raw_span_text_copied_rows": "0",
    "grounded_answer_rows": "1000",
    "citation_rows": "1000",
    "resource_rows": "1000",
    "unsupported_claim_rows": "100",
    "raw_context_in_hint_rows": "0",
    "raw_prompt_context_appended_rows": "0",
    "attention_blocks": "0",
    "transformer_blocks": "0",
    "wrong_answer_rows": "0",
    "answer_grounded_rate": "1.000000",
    "span_citation_accuracy": "1.000000",
    "wrong_answer_rate": "0.000000",
    "v54_contract_ready": "1",
    "human_review_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v54b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v54b-routehint-generation-scale",
    "generation-row-target",
    "route-memory-evidence-binding",
    "compact-routehint-only",
    "non-attention-generator",
    "no-raw-prompt-context",
    "citation-grounding-target",
    "resource-measurement-rows",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v54b gate should pass: {gate}")
for gate in ["human-review-artifacts", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54b gate should remain blocked: {gate}")

required_files = [
    "query_rows.csv",
    "route_memory_evidence_rows.csv",
    "compact_route_hint_rows.csv",
    "generator_input_rows.csv",
    "grounded_generation_rows.csv",
    "citation_rows.csv",
    "abstain_rows.csv",
    "unsupported_claim_rows.csv",
    "resource_rows.csv",
    "domain_generation_rows.csv",
    "generation_metrics.json",
    "V54B_ROUTEHINT_GENERATION_SCALE_BOUNDARY.md",
    "v54b_routehint_generation_scale_manifest.json",
    "sha256_manifest.csv",
    "source_v54_contract/domain_generation_target_rows.csv",
    "source_v54_contract/generation_invariant_rows.csv",
    "source_v54_contract/artifact_contract_rows.csv",
    "source_v54_contract/V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md",
    "source_v54_contract/v54_routehint_generation_1000_manifest.json",
    "source_v54_contract/sha256_manifest.csv",
    "source_v54_contract/v54_routehint_generation_1000_contract_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v54b artifact: {rel}")

queries = read_csv(run_dir / "query_rows.csv")
evidence = read_csv(run_dir / "route_memory_evidence_rows.csv")
hints = read_csv(run_dir / "compact_route_hint_rows.csv")
inputs = read_csv(run_dir / "generator_input_rows.csv")
generations = read_csv(run_dir / "grounded_generation_rows.csv")
citations = read_csv(run_dir / "citation_rows.csv")
resources = read_csv(run_dir / "resource_rows.csv")
abstains = read_csv(run_dir / "abstain_rows.csv")
unsupported = read_csv(run_dir / "unsupported_claim_rows.csv")
domain_rows = read_csv(run_dir / "domain_generation_rows.csv")

for rows, name in [
    (queries, "query"),
    (evidence, "evidence"),
    (hints, "hint"),
    (inputs, "input"),
    (generations, "generation"),
    (citations, "citation"),
    (resources, "resource"),
]:
    if len(rows) != 1000:
        raise SystemExit(f"v54b should write 1000 {name} rows")
if len(abstains) != 100 or len(unsupported) != 100:
    raise SystemExit("v54b should write 100 abstain/unsupported rows")
if len({row["generation_id"] for row in generations}) != 1000:
    raise SystemExit("v54b generation ids should be unique")
if set(row["domain"] for row in generations) != set(DOMAIN_TARGETS):
    raise SystemExit("v54b should cover the six target domains")

domain_counts = Counter(row["domain"] for row in generations)
for domain, target in DOMAIN_TARGETS.items():
    if domain_counts[domain] != target:
        raise SystemExit(f"v54b domain count mismatch: {domain}")
domain_row_counts = {row["domain"]: int(row["generation_rows"]) for row in domain_rows}
if domain_row_counts != DOMAIN_TARGETS:
    raise SystemExit("v54b domain row table should match target distribution")

evidence_by_query = {row["query_id"]: row for row in evidence}
hint_by_query = {row["query_id"]: row for row in hints}
input_by_query = {row["query_id"]: row for row in inputs}
citation_by_query = {row["query_id"]: row for row in citations}
resource_by_query = {row["query_id"]: row for row in resources}
for row in generations:
    query_id = row["query_id"]
    ev = evidence_by_query[query_id]
    hint = hint_by_query[query_id]
    gen_input = input_by_query[query_id]
    citation = citation_by_query[query_id]
    resource = resource_by_query[query_id]
    evidence_path = root / ev["evidence_path"]
    if ev["evidence_sha256"] != sha256(evidence_path):
        raise SystemExit(f"v54b evidence hash mismatch: {query_id}")
    if hint["route_hint_used"] != "1" or hint["raw_context_in_hint"] != "0":
        raise SystemExit("v54b hints should be compact and used")
    if hint["source_evidence_sha256"] != ev["evidence_sha256"]:
        raise SystemExit(f"v54b hint/evidence mismatch: {query_id}")
    if gen_input["attention_layers"] != "0" or gen_input["transformer_blocks"] != "0":
        raise SystemExit("v54b generator should stay non-attention")
    if gen_input["raw_prompt_context_appended"] != "0" or gen_input["raw_prompt_context_bytes"] != "0" or gen_input["retrieved_text_in_prompt"] != "0":
        raise SystemExit("v54b generator should not stuff prompt context")
    if citation["sha256"] != ev["evidence_sha256"] or citation["span_citation_correct"] != "1":
        raise SystemExit(f"v54b citation mismatch: {query_id}")
    citation_text = (root / citation["file_path"]).read_text(encoding="utf-8").strip()
    if citation["citation_text_sha256"] != sha256_text(citation_text):
        raise SystemExit(f"v54b citation text hash mismatch: {query_id}")
    if resource["external_network_used"] != "0" or resource["external_model_used"] != "0":
        raise SystemExit("v54b resources should stay local")
    if resource["attention_layers"] != "0" or resource["transformer_blocks"] != "0" or resource["raw_prompt_context_bytes"] != "0":
        raise SystemExit("v54b resource rows should record no attention/raw context")
    if row["answer_grounded"] != "1" or row["span_citation_correct"] != "1" or row["abstain_correct"] != "1":
        raise SystemExit("v54b generations should be grounded, cited, and abstain-correct")
    if row["wrong_answer"] != "0" or row["audit_trail_bound"] != "1":
        raise SystemExit("v54b generations should have zero wrong answers and bound audit trails")
    if row["expected_behavior"] == "answer":
        if row["hint_value_transformed"] != "1" or row["answer_equals_hint_value"] != "0" or row["raw_span_text_copied"] != "0":
            raise SystemExit("v54b answer rows should transform hints without echoing values or spans")
        if row["route_key_phrase"] not in row["generated_answer"]:
            raise SystemExit("v54b generated answer should contain route key phrase")
    else:
        if row["generated_answer"] != "ABSTAIN":
            raise SystemExit("v54b abstain rows should output ABSTAIN")

metrics = json.loads((run_dir / "generation_metrics.json").read_text(encoding="utf-8"))
if metrics.get("generation_rows") != 1000 or metrics.get("wrong_answer_rows") != 0:
    raise SystemExit("v54b metrics count mismatch")
if metrics.get("attention_blocks") != 0 or metrics.get("transformer_blocks") != 0:
    raise SystemExit("v54b metrics should keep non-attention invariant")

manifest = json.loads((run_dir / "v54b_routehint_generation_scale_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v54b_routehint_generation_scale_ready") != 1 or manifest.get("v54_generation_1000_ready") != 1:
    raise SystemExit("v54b manifest readiness mismatch")
if manifest.get("generation_rows") != 1000 or manifest.get("domain_count") != 6:
    raise SystemExit("v54b manifest count mismatch")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v54b should keep release blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v54b sha256 mismatch: {rel}")
if len([path for path in sha_rows if path.startswith("route_memory_evidence_spans/")]) != 1000:
    raise SystemExit("v54b sha manifest should include 1000 evidence span files")

boundary = (run_dir / "V54B_ROUTEHINT_GENERATION_SCALE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "deterministic local 1000-row RouteHint generation scale run",
    "generation_rows=1000",
    "attention_blocks=0",
    "raw_prompt_context_appended_rows=0",
    "wrong_answer_rows=0",
    "Do not publish v1.0 release or 30B-150B equivalence claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v54b boundary missing {snippet}")
PY

echo "v54b RouteHint generation scale 1000 smoke passed"
