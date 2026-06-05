#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKET_DIR="$RESULTS_DIR/v36_release_claim_audit_packet/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v36_release_claim_audit_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v36_release_claim_audit_packet_decision.csv"

"$ROOT_DIR/experiments/run_v36_release_claim_audit_packet.sh" >/dev/null

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

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v36 summary row, got {len(rows)}")
summary = rows[0]
expected_ones = [
    "v36_release_claim_audit_packet_ready",
    "evidence_inputs_ready",
    "maximum_allowed_claim_decided",
    "v33_evidence_closure_packet_ready",
    "v34_official_benchmark_expansion_packet_ready",
    "v35_commercial_pilot_packet_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v36 {field}: expected 1, got {summary.get(field)}")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v36 must keep human review and release package blocked")
if int(summary.get("allowed_claim_rows", "0")) < 1:
    raise SystemExit("v36 should allow at least one bounded claim")
if int(summary.get("blocked_claim_rows", "0")) < 5:
    raise SystemExit("v36 should block stronger claims")
if int(summary.get("artifact_rows", "0")) < 18:
    raise SystemExit("v36 packet should hash audit and evidence files")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v36-release-claim-audit-packet",
    "evidence-inputs",
    "maximum-allowed-public-claim",
    "overclaim-guard",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v36 gate should pass: {gate}")
for gate in ["human-review", "real-release-package", "release-ready-product"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v36 should leave {gate} blocked")

required_files = [
    "RELEASE_CLAIM_AUDIT.md",
    "claim_matrix.csv",
    "evidence_input_rows.csv",
    "release_decision_rows.csv",
    "v36_release_claim_audit_manifest.json",
    "sha256_manifest.csv",
    "evidence/v33/evidence_closure_manifest.json",
    "evidence/v33/summary.csv",
    "evidence/v33/decision.csv",
    "evidence/v34/benchmark_expansion_manifest.json",
    "evidence/v34/summary.csv",
    "evidence/v34/decision.csv",
    "evidence/v35/commercial_pilot_manifest.json",
    "evidence/v35/summary.csv",
    "evidence/v35/decision.csv",
]
for rel in required_files:
    path = packet_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v36 missing packet artifact: {rel}")

manifest = json.loads((packet_dir / "v36_release_claim_audit_manifest.json").read_text(encoding="utf-8"))
if manifest.get("evidence_inputs_ready") != 1:
    raise SystemExit("v36 manifest should mark evidence inputs ready")
if manifest.get("maximum_allowed_claim_decided") != 1:
    raise SystemExit("v36 manifest should decide a maximum allowed claim")
if "local evidence-bound QA/audit architecture" not in manifest.get("maximum_allowed_claim", ""):
    raise SystemExit("v36 maximum allowed claim should remain bounded")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v36 manifest must not open review/release")
if manifest.get("release_recommendation") != "do-not-release-product":
    raise SystemExit("v36 release recommendation should block product release")

claim_rows = read_csv(packet_dir / "claim_matrix.csv")
if not any(row["status"] == "allowed_limited" and "local evidence-bound QA/audit architecture" in row["public_wording"] for row in claim_rows):
    raise SystemExit("v36 should allow only a bounded QA/audit claim")
for claim_id in [
    "release-ready-product",
    "general-llm-replacement",
    "transformer-replacement",
    "frontier-long-context-solved",
    "gpu-acceleration",
]:
    matches = [row for row in claim_rows if row["claim_id"] == claim_id]
    if len(matches) != 1 or matches[0]["status"] != "blocked":
        raise SystemExit(f"v36 should block claim: {claim_id}")

evidence_rows = read_csv(packet_dir / "evidence_input_rows.csv")
if {row["input_id"] for row in evidence_rows} != {"v33", "v34", "v35"}:
    raise SystemExit("v36 evidence input set should be v33/v34/v35")
if any(row["ready"] != "1" for row in evidence_rows):
    raise SystemExit("v36 evidence inputs should be ready")
if any(row["release_ready"] != "0" for row in evidence_rows):
    raise SystemExit("v36 evidence inputs should not be release-ready")

audit = (packet_dir / "RELEASE_CLAIM_AUDIT.md").read_text(encoding="utf-8")
for snippet in [
    "Maximum allowed public claim:",
    "Blocked:",
    "Release-ready product",
    "`real_release_package_ready` remains 0",
]:
    if snippet not in audit:
        raise SystemExit(f"v36 audit missing: {snippet}")

with (packet_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v36 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(packet_dir / rel):
        raise SystemExit(f"v36 sha mismatch for {rel}")
PY

echo "v36 release claim audit packet smoke passed"
