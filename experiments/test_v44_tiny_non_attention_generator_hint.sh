#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
GEN_DIR="$RESULTS_DIR/v44_tiny_non_attention_generator_hint/generator_001"
RETURN_DIR="$GEN_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v44_tiny_non_attention_generator_hint_summary.csv"
DECISION_CSV="$RESULTS_DIR/v44_tiny_non_attention_generator_hint_decision.csv"

"$ROOT_DIR/experiments/run_v44_tiny_non_attention_generator_hint.sh" >/dev/null

python3 - "$ROOT_DIR" "$GEN_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
gen_dir = Path(sys.argv[2])
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
    raise SystemExit(f"expected one v44 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_ones = [
    "v44_tiny_non_attention_generator_hint_ready",
    "no_raw_prompt_stuffing_ready",
    "non_attention_generator_ready",
    "privacy_review_ready",
    "resource_envelope_ready",
    "v18_closed_corpus_poc_actual_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v44 {field}: expected 1, got {summary.get(field)}")
expected_counts = {
    "generator_rows": "10",
    "grounded_answer_rows": "10",
    "abstain_rows": "2",
    "route_hint_rows": "10",
    "route_hint_used_rows": "10",
    "raw_prompt_context_appended_rows": "0",
}
for field, expected in expected_counts.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v44 {field}: expected {expected}, got {summary.get(field)}")
for field in ["answer_grounded_rate", "span_citation_accuracy"]:
    if summary.get(field) != "1.000000":
        raise SystemExit(f"v44 {field}: expected 1.000000, got {summary.get(field)}")
if summary.get("wrong_answer_rate") != "0.000000":
    raise SystemExit("v44 wrong answer rate should be zero")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v44 should keep review/release blocked")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v44-tiny-non-attention-generator-hint",
    "routehint-used",
    "no-raw-prompt-stuffing",
    "non-attention-generator",
    "grounded-answer",
    "missing-abstain",
    "v18-commercial-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v44 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v44 should leave release blocked")

required_files = [
    "V44_TINY_GENERATOR_HINT_BOUNDARY.md",
    "route_hint_rows.csv",
    "generator_input_rows.csv",
    "generator_rows.csv",
    "transcript_rows.csv",
    "v44_tiny_generator_manifest.json",
    "sha256_manifest.csv",
    "evidence/v18_tiny_generator_summary.csv",
    "evidence/v18_tiny_generator_decision.csv",
    "evidence/v43_doc_code_conflict_summary.csv",
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
    path = gen_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v44 missing artifact: {rel}")

manifest = json.loads((gen_dir / "v44_tiny_generator_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v44_tiny_non_attention_generator_hint_ready") != 1:
    raise SystemExit("v44 manifest should be ready")
if manifest.get("generator_rows") != 10 or manifest.get("grounded_answer_rows") != 10:
    raise SystemExit("v44 manifest should record 10 grounded generator rows")
if manifest.get("abstain_rows") != 2:
    raise SystemExit("v44 manifest should record two abstain rows")
if manifest.get("raw_prompt_context_appended_rows") != 0:
    raise SystemExit("v44 manifest should forbid raw prompt stuffing")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v44 manifest should keep review/release blocked")

route_hint_rows = read_csv(gen_dir / "route_hint_rows.csv")
input_rows = read_csv(gen_dir / "generator_input_rows.csv")
generator_rows = read_csv(gen_dir / "generator_rows.csv")
transcript_rows = read_csv(gen_dir / "transcript_rows.csv")
if not (len(route_hint_rows) == len(input_rows) == len(generator_rows) == len(transcript_rows) == 10):
    raise SystemExit("v44 should write 10 route hint/input/generator/transcript rows")
if any(row["route_hint_used"] != "1" for row in route_hint_rows):
    raise SystemExit("v44 route hints should all be used")
if any(row["raw_context_in_hint"] != "0" for row in route_hint_rows):
    raise SystemExit("v44 route hints should not contain raw context")
if any(row["attention_layers"] != "0" or row["transformer_blocks"] != "0" for row in input_rows):
    raise SystemExit("v44 generator should be non-attention")
if any(row["raw_prompt_context_appended"] != "0" or row["raw_prompt_context_bytes"] != "0" or row["retrieved_text_in_prompt"] != "0" for row in input_rows):
    raise SystemExit("v44 generator input should not append retrieved text")
if any(row["answer_grounded"] != "1" or row["span_citation_correct"] != "1" or row["wrong_answer"] != "0" for row in generator_rows):
    raise SystemExit("v44 generator rows should all be grounded and correct")
if any(row["teacher_off_inference"] != "1" or row["route_hint_used"] != "1" or row["non_attention_generator"] != "1" for row in generator_rows):
    raise SystemExit("v44 generator rows should be teacher-off RouteHint non-attention rows")
if len([row for row in generator_rows if row["expected_behavior"] == "abstain" and row["generated_answer"] == "ABSTAIN"]) != 2:
    raise SystemExit("v44 should abstain on two missing rows")
for row in transcript_rows:
    citation_path = root / row["citation_path"]
    if row["citation_sha256"] != sha256(citation_path):
        raise SystemExit(f"v44 citation hash mismatch: {row['query_id']}")
    if row["raw_prompt_context_appended"] != "0":
        raise SystemExit("v44 transcript should not append raw prompt context")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 10:
    raise SystemExit("v44 domain should be codebase_qa with 10 queries")
if resource.get("attention_layers") != 0 or resource.get("transformer_blocks") != 0:
    raise SystemExit("v44 resource envelope should record zero attention/transformer blocks")
if resource.get("raw_prompt_context_appended") != 0 or resource.get("external_network_used") != 0:
    raise SystemExit("v44 should be offline with no raw prompt stuffing")
if privacy.get("privacy_review_ready") != 1:
    raise SystemExit("v44 privacy review should be ready")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 10 or len(poc_rows) != 10 or len(audit_rows) != 10:
    raise SystemExit("v44 query/result/audit rows should all be 10")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "audit_trail_bound", "route_hint_used", "non_attention_generator"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v44 result rows should pass {field}")
if any(row["raw_prompt_context_appended"] != "0" for row in poc_rows):
    raise SystemExit("v44 PoC rows should not append raw prompt context")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v44 audit trail rows should pass")
if len(acceptance_rows) < 7 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v44 acceptance rows should pass")

with (gen_dir / "evidence" / "v18_tiny_generator_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v44 copied v18 summary should verify commercial PoC")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v44 copied v18 summary should keep release blocked")

boundary = (gen_dir / "V44_TINY_GENERATOR_HINT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "A small non-attention generator actually uses RouteHint",
    "without appending retrieved text as raw prompt context",
    "finite-state/template generator smoke",
    "not a release-ready product claim",
]:
    if snippet not in boundary:
        raise SystemExit(f"v44 boundary missing: {snippet}")

with (gen_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v44 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(gen_dir / rel):
        raise SystemExit(f"v44 sha mismatch for {rel}")
PY

echo "v44 Tiny Non-Attention Generator Hint smoke passed"
