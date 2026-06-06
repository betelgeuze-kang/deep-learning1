#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKET_DIR="$RESULTS_DIR/v35_commercial_pilot_packet/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v35_commercial_pilot_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v35_commercial_pilot_packet_decision.csv"

"$ROOT_DIR/experiments/run_v35_commercial_pilot_packet.sh" >/dev/null

python3 - "$PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
commercial_dir = packet_dir / "commercial_pilot_return"

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v35 summary row, got {len(rows)}")
summary = rows[0]
expected_ones = [
    "v35_commercial_pilot_packet_ready",
    "commercial_pilot_return_ready",
    "closed_corpus_poc_actual_ready",
    "v18_with_v35_commercial_ready",
    "privacy_review_ready",
    "resource_envelope_ready",
    "real_external_benchmark_verified",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v35 {field}: expected 1, got {summary.get(field)}")
if summary.get("domain") != "internal_docs":
    raise SystemExit("v35 domain should be internal_docs")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v35 should keep human review and release blocked")
if int(summary.get("query_rows", "0")) < 5:
    raise SystemExit("v35 should include at least five internal-docs query rows")
if int(summary.get("abstain_rows", "0")) < 1:
    raise SystemExit("v35 should include an abstain row")
for field in ["wrong_answer_guard_pass_rows", "citation_accuracy_pass_rows", "abstain_behavior_pass_rows"]:
    if summary.get(field) != summary.get("query_rows"):
        raise SystemExit(f"v35 {field} should match query_rows")
if int(summary.get("artifact_rows", "0")) < 25:
    raise SystemExit("v35 packet should hash the pilot and evidence files")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v35-commercial-pilot-packet",
    "commercial-return-schema",
    "internal-docs-domain",
    "citation-accuracy",
    "wrong-answer-guard",
    "privacy-review",
    "v18-commercial-pilot-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v35 gate should pass: {gate}")
for gate in ["human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v35 should leave {gate} blocked")

required_files = [
    "COMMERCIAL_PILOT_BOUNDARY.md",
    "commercial_pilot_manifest.json",
    "sha256_manifest.csv",
    "artifact_manifest.csv",
    "source_manifests/internal_docs_corpus_source_rows.csv",
    "commercial_pilot_return/domain_manifest.json",
    "commercial_pilot_return/corpus_manifest.json",
    "commercial_pilot_return/query_set.csv",
    "commercial_pilot_return/poc_result_rows.csv",
    "commercial_pilot_return/audit_trail.csv",
    "commercial_pilot_return/resource_envelope.json",
    "commercial_pilot_return/privacy_review.json",
    "commercial_pilot_return/acceptance_review.csv",
    "evidence/v33_evidence_closure_manifest.json",
    "evidence/v34_benchmark_expansion_manifest.json",
    "evidence/v18_with_v35_commercial/v18_external_evidence_intake_summary.csv",
    "evidence/v18_with_v35_commercial/v18_external_evidence_intake_decision.csv",
]
for rel in required_files:
    path = packet_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v35 missing packet artifact: {rel}")

manifest = json.loads((packet_dir / "commercial_pilot_manifest.json").read_text(encoding="utf-8"))
if manifest.get("commercial_pilot_return_ready") != 1 or manifest.get("v18_with_v35_commercial_ready") != 1:
    raise SystemExit("v35 manifest should be ready")
if manifest.get("domain") != "internal_docs" or manifest.get("buyer_visible_workflow") != "internal documentation QA":
    raise SystemExit("v35 manifest should identify the internal-docs workflow")
if manifest.get("expanded_official_benchmark_consumed") != 1:
    raise SystemExit("v35 should consume v34 official expansion evidence")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v35 manifest should keep review/release blocked")

boundary = (packet_dir / "COMMERCIAL_PILOT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Allowed claim:",
    "Internal documentation QA",
    "Held constant:",
    "Blocked claims:",
    "Release-ready product",
]:
    if snippet not in boundary:
        raise SystemExit(f"v35 boundary missing: {snippet}")

domain = json.loads((commercial_dir / "domain_manifest.json").read_text(encoding="utf-8"))
corpus = json.loads((commercial_dir / "corpus_manifest.json").read_text(encoding="utf-8"))
privacy = json.loads((commercial_dir / "privacy_review.json").read_text(encoding="utf-8"))
resource = json.loads((commercial_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if domain.get("domain") != "internal_docs" or domain.get("not_fixture") != 1:
    raise SystemExit("v35 domain manifest should be non-fixture internal_docs")
if corpus.get("closed_corpus_ready") != 1:
    raise SystemExit("v35 corpus should be closed-corpus ready")
if privacy.get("privacy_review_ready") != 1 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v35 privacy/resource review should be ready")

source_rows = read_csv(packet_dir / "source_manifests" / "internal_docs_corpus_source_rows.csv")
if len(source_rows) < 2 or any(row.get("closed_corpus_member") != "1" for row in source_rows):
    raise SystemExit("v35 source manifest should list closed-corpus docs")

query_rows = read_csv(commercial_dir / "query_set.csv")
poc_rows = read_csv(commercial_dir / "poc_result_rows.csv")
audit_rows = read_csv(commercial_dir / "audit_trail.csv")
acceptance = read_csv(commercial_dir / "acceptance_review.csv")
if len(query_rows) != int(summary["query_rows"]):
    raise SystemExit("v35 query row count mismatch")
if len(poc_rows) != len(query_rows):
    raise SystemExit("v35 PoC rows should match query rows")
if len(audit_rows) < len(query_rows):
    raise SystemExit("v35 audit rows should cover every query")
if len(acceptance) != int(summary["acceptance_rows"]) or any(row["status"] != "pass" for row in acceptance):
    raise SystemExit("v35 acceptance review should pass")
if not any(row.get("expected_behavior") == "abstain" for row in query_rows):
    raise SystemExit("v35 query set should include an abstain case")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "buyer_visible"]:
    if any(row.get(field) != "1" for row in poc_rows):
        raise SystemExit(f"v35 result rows should pass {field}")
if not any(row.get("answer", "").startswith("ABSTAIN:") for row in poc_rows):
    raise SystemExit("v35 should include an explicit ABSTAIN answer")

with (packet_dir / "evidence" / "v18_with_v35_commercial" / "v18_external_evidence_intake_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
]:
    if v18.get(field) != "1":
        raise SystemExit(f"v35 copied v18 summary should keep {field}=1")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v35 copied v18 summary must keep release blocked")

with (packet_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v35 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(packet_dir / rel):
        raise SystemExit(f"v35 sha mismatch for {rel}")
PY

echo "v35 commercial pilot packet smoke passed"
