#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v48_multi_domain_generator_evidence/run_001"
RETURN_DIR="$RUN_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v48_multi_domain_generator_evidence_summary.csv"
DECISION_CSV="$RESULTS_DIR/v48_multi_domain_generator_evidence_decision.csv"

"$ROOT_DIR/experiments/run_v48_multi_domain_generator_evidence.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

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
    raise SystemExit(f"expected one v48 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_values = {
    "v48_multi_domain_generator_evidence_ready": "1",
    "domain_count": "4",
    "generation_rows": "24",
    "abstain_rows": "4",
    "route_memory_evidence_rows": "24",
    "route_hint_used_rows": "24",
    "hint_value_transformed_rows": "20",
    "answer_equals_hint_value_rows": "0",
    "raw_span_text_copied_rows": "0",
    "grounded_answer_rows": "24",
    "citation_rows": "24",
    "audit_trail_rows": "24",
    "raw_context_in_hint_rows": "0",
    "raw_prompt_context_appended_rows": "0",
    "answer_grounded_rate": "1.000000",
    "span_citation_accuracy": "1.000000",
    "wrong_answer_rate": "0.000000",
    "v18_closed_corpus_poc_actual_ready": "1",
    "real_release_package_ready": "0",
}
for field, expected in expected_values.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v48 {field}: expected {expected}, got {summary.get(field)}")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v48-multi-domain-generator-evidence",
    "domain-coverage",
    "route-memory-evidence",
    "compact-routehint",
    "tiny-generator-no-prompt-stuffing",
    "routehint-transformation",
    "grounding-citation-abstain",
    "audit-trail",
    "v18-commercial-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v48 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v48 should leave release blocked")

required_files = [
    "V48_MULTI_DOMAIN_GENERATOR_BOUNDARY.md",
    "route_memory_evidence_rows.csv",
    "compact_route_hint_rows.csv",
    "tiny_generator_input_rows.csv",
    "grounded_generation_rows.csv",
    "v48_multi_domain_generator_manifest.json",
    "sha256_manifest.csv",
    "evidence/v18_multi_domain_generator_summary.csv",
    "evidence/v18_multi_domain_generator_decision.csv",
    "commercial_return/domain_manifest.json",
    "commercial_return/corpus_manifest.json",
    "commercial_return/query_set.csv",
    "commercial_return/poc_result_rows.csv",
    "commercial_return/audit_trail.csv",
    "commercial_return/resource_envelope.json",
    "commercial_return/privacy_review.json",
    "commercial_return/acceptance_review.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v48 missing artifact: {rel}")

manifest = json.loads((run_dir / "v48_multi_domain_generator_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v48_multi_domain_generator_evidence_ready") != 1:
    raise SystemExit("v48 manifest should be ready")
if manifest.get("domain_count") != 4 or manifest.get("generation_rows") != 24:
    raise SystemExit("v48 manifest should record four domains and 24 rows")
if manifest.get("abstain_rows") != 4 or manifest.get("wrong_answer_rows") != 0:
    raise SystemExit("v48 manifest should record four abstains and zero wrong answers")
if manifest.get("hint_value_transformed_rows") != 20 or manifest.get("answer_equals_hint_value_rows") != 0 or manifest.get("raw_span_text_copied_rows") != 0:
    raise SystemExit("v48 manifest should record transformed, non-echo answer rows")
if manifest.get("raw_prompt_context_appended_rows") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v48 manifest should keep no prompt stuffing and no release readiness")

evidence_rows = read_csv(run_dir / "route_memory_evidence_rows.csv")
hint_rows = read_csv(run_dir / "compact_route_hint_rows.csv")
input_rows = read_csv(run_dir / "tiny_generator_input_rows.csv")
output_rows = read_csv(run_dir / "grounded_generation_rows.csv")
expected_domains = {"ruler_niah", "longbench_v2", "codebase_qa", "internal_docs_qa"}
for rows, name in [(evidence_rows, "evidence"), (hint_rows, "hint"), (input_rows, "input"), (output_rows, "output")]:
    if len(rows) != 24:
        raise SystemExit(f"v48 should write 24 {name} rows")
    if set(row["domain"] for row in rows) != expected_domains:
        raise SystemExit(f"v48 {name} rows should cover all domains")
for domain in expected_domains:
    if len([row for row in output_rows if row["domain"] == domain]) != 6:
        raise SystemExit(f"v48 should write six rows for {domain}")
    if len([row for row in output_rows if row["domain"] == domain and row["expected_behavior"] == "abstain"]) != 1:
        raise SystemExit(f"v48 should write one abstain for {domain}")
for row in evidence_rows:
    path = root / row["evidence_path"]
    if row["evidence_sha256"] != sha256(path):
        raise SystemExit(f"v48 evidence hash mismatch: {row['query_id']}")
    if row["route_memory_derived_evidence"] != "1":
        raise SystemExit("v48 evidence rows should be RouteMemory-derived")
for row in hint_rows:
    if row["route_hint_used"] != "1" or row["raw_context_in_hint"] != "0":
        raise SystemExit("v48 hints should be compact and used")
    match = next(e for e in evidence_rows if e["query_id"] == row["query_id"])
    if row["source_evidence_sha256"] != match["evidence_sha256"]:
        raise SystemExit(f"v48 hint/evidence mismatch: {row['query_id']}")
for row in input_rows:
    if row["attention_layers"] != "0" or row["transformer_blocks"] != "0":
        raise SystemExit("v48 generator should be non-attention")
    if row["raw_prompt_context_appended"] != "0" or row["raw_prompt_context_bytes"] != "0" or row["retrieved_text_in_prompt"] != "0":
        raise SystemExit("v48 generator input should not stuff retrieved text into prompt")
for row in output_rows:
    if row["answer_grounded"] != "1" or row["span_citation_correct"] != "1" or row["abstain_correct"] != "1":
        raise SystemExit("v48 generated answers should be grounded, cited, and abstain-correct")
    if row["wrong_answer"] != "0" or row["audit_trail_bound"] != "1":
        raise SystemExit("v48 generated answers should have zero wrong answers and bound audit trails")
    if row["expected_behavior"] == "answer":
        if row["hint_value_transformed"] != "1" or row["answer_equals_hint_value"] != "0" or row["raw_span_text_copied"] != "0":
            raise SystemExit("v48 answer rows should transform RouteHint values without echoing hint values or raw spans")
        if row["route_key_phrase"] not in row["generated_answer"]:
            raise SystemExit("v48 generated answers should include transformed route key phrase")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 24:
    raise SystemExit("v48 domain should be codebase_qa with 24 queries")
if resource.get("attention_layers") != 0 or resource.get("transformer_blocks") != 0:
    raise SystemExit("v48 resource envelope should record zero attention/transformer blocks")
if resource.get("raw_prompt_context_appended") != 0 or resource.get("external_network_used") != 0:
    raise SystemExit("v48 resource envelope should record no raw prompt stuffing or network")
if privacy.get("privacy_review_ready") != 1:
    raise SystemExit("v48 privacy review should be ready")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 24 or len(poc_rows) != 24 or len(audit_rows) != 24:
    raise SystemExit("v48 query/result/audit rows should all be 24")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "audit_trail_bound"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v48 result rows should pass {field}")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v48 audit rows should pass")
if len(acceptance_rows) < 7 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v48 acceptance rows should pass")

with (run_dir / "evidence" / "v18_multi_domain_generator_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v48 copied v18 summary should verify commercial PoC")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v48 copied v18 summary should keep release blocked")

boundary = (run_dir / "V48_MULTI_DOMAIN_GENERATOR_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Expand v44 from smoke to multi-domain answer generation evidence",
    "RULER NIAH",
    "LongBench v2",
    "Codebase QA",
    "Internal docs QA",
    "not an internal packaging layer",
]:
    if snippet not in boundary:
        raise SystemExit(f"v48 boundary missing: {snippet}")

with (run_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v48 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(run_dir / rel):
        raise SystemExit(f"v48 sha mismatch for {rel}")
PY

echo "v48 Multi-Domain RouteHint Generator evidence smoke passed"
