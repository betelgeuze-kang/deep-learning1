#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKET_DIR="$RESULTS_DIR/v33_evidence_closure_packet/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v33_evidence_closure_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v33_evidence_closure_packet_decision.csv"

"$ROOT_DIR/experiments/run_v33_evidence_closure_packet.sh" >/dev/null

python3 - "$PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v33 summary row, got {len(rows)}")
summary = rows[0]
expected_ones = [
    "v33_evidence_closure_packet_ready",
    "third_party_return_copied",
    "official_candidate_return_copied",
    "commercial_poc_return_copied",
    "v18_summary_copied",
    "v18_decision_copied",
    "sha256_manifest_ready",
    "claim_boundary_ready",
    "human_review_request_ready",
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v33 {field}: expected 1, got {summary.get(field)}")
if summary.get("real_release_package_ready") != "0":
    raise SystemExit("v33 must keep real_release_package_ready=0")
if summary.get("human_review_completed") != "0":
    raise SystemExit("v33 should prepare human review, not mark it completed")
if int(summary.get("artifact_rows", "0")) < 25:
    raise SystemExit("v33 packet should hash a substantial evidence set")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v33-evidence-closure-packet",
    "v18-closure-flags",
    "third-party-return-copy",
    "official-candidate-return-copy",
    "commercial-poc-return-copy",
    "claim-boundary",
    "sha256-manifest",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v33 gate should pass: {gate}")
for gate in ["human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v33 should leave {gate} blocked")

required_files = [
    "CLAIM_BOUNDARY.md",
    "evidence_closure_manifest.json",
    "sha256_manifest.csv",
    "human_review/HUMAN_REVIEW_REQUEST.md",
    "human_review/human_review_template.csv",
    "evidence/v18_intake/v18_external_evidence_intake_summary.csv",
    "evidence/v18_intake/v18_external_evidence_intake_decision.csv",
    "evidence/third_party_return/reviewer_identity.json",
    "evidence/third_party_return/rerun_environment.json",
    "evidence/third_party_return/v15a_package_manifest.json",
    "evidence/official_candidate_return/official_source_snapshot.json",
    "evidence/official_candidate_return/candidate_result_rows.csv",
    "evidence/commercial_poc_return/privacy_review.json",
    "evidence/commercial_poc_return/acceptance_review.csv",
]
for rel in required_files:
    path = packet_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v33 missing packet artifact: {rel}")

claim = (packet_dir / "CLAIM_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Allowed claim:",
    "Blocked claims:",
    "General LLM replacement",
    "Release-ready product",
    "`real_release_package_ready` remains 0",
]:
    if snippet not in claim:
        raise SystemExit(f"v33 claim boundary missing: {snippet}")

manifest = json.loads((packet_dir / "evidence_closure_manifest.json").read_text(encoding="utf-8"))
if manifest.get("closure_flags_ready") != 1 or manifest.get("copies_ready") != 1:
    raise SystemExit("v33 manifest should mark closure flags and copies ready")
if manifest.get("human_review_completed") != 0:
    raise SystemExit("v33 manifest should not complete human review")
for blocked in ["general LLM replacement", "release-ready product"]:
    if blocked not in manifest.get("blocked_claims", []):
        raise SystemExit(f"v33 manifest missing blocked claim: {blocked}")

with (packet_dir / "evidence" / "v18_intake" / "v18_external_evidence_intake_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("real_external_benchmark_verified") != "1" or v18.get("real_release_package_ready") != "0":
    raise SystemExit("v33 copied v18 summary has wrong closure/release flags")

with (packet_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v33 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(packet_dir / rel):
        raise SystemExit(f"v33 sha mismatch for {rel}")
PY

echo "v33 evidence closure packet smoke passed"
