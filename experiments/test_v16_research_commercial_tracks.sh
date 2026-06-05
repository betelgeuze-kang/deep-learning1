#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKET_DIR="$RESULTS_DIR/v16_research_commercial_tracks/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v16_research_commercial_tracks_summary.csv"
DECISION_CSV="$RESULTS_DIR/v16_research_commercial_tracks_decision.csv"

"$ROOT_DIR/experiments/run_v16_research_commercial_tracks.sh" >/dev/null

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
    raise SystemExit(f"expected one v16 summary row, got {len(rows)}")
summary = rows[0]
expected = {
    "research_publication_track_ready": "1",
    "commercial_local_qa_audit_prototype_ready": "1",
    "claim_boundaries_ready": "1",
    "v16_ready": "1",
    "candidate_external_benchmark_result_ready": "0",
    "real_external_benchmark_verified": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v16 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("evidence_matrix_rows", "0")) < 6:
    raise SystemExit("v16 evidence matrix too small")
if int(summary.get("commercial_acceptance_rows", "0")) < 7:
    raise SystemExit("v16 commercial acceptance matrix too small")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["v16-research-publication-track", "v16-commercial-local-qa-audit-prototype", "v16-claim-boundaries"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v16 decision did not pass: {gate}")
for gate in ["candidate-external-benchmark-result", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v16 decision should remain blocked: {gate}")

required = [
    "research_publication_packet.md",
    "research_evidence_matrix.csv",
    "claim_boundary_matrix.csv",
    "commercial_local_qa_audit_contract.md",
    "commercial_acceptance_rows.csv",
    "artifact_manifest.csv",
    "v16_manifest.json",
    "inputs/v14-b-lite_summary.csv",
    "inputs/v14-c_summary.csv",
    "inputs/v14-d_summary.csv",
    "inputs/v14-e_summary.csv",
    "inputs/v15-a_summary.csv",
    "inputs/v15-b_summary.csv",
    "inputs/v15-b_decision.csv",
]
for rel in required:
    path = packet_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v16 artifact: {rel}")

research_doc = (packet_dir / "research_publication_packet.md").read_text(encoding="utf-8")
for phrase in ["Hypothesis", "Method", "Limitations", "not independent RULER benchmark verification"]:
    if phrase not in research_doc:
        raise SystemExit(f"v16 research packet missing phrase: {phrase}")
commercial_doc = (packet_dir / "commercial_local_qa_audit_contract.md").read_text(encoding="utf-8")
for phrase in ["evidence-bound", "abstain", "local", "Blocked Product Claims"]:
    if phrase not in commercial_doc:
        raise SystemExit(f"v16 commercial contract missing phrase: {phrase}")

with (packet_dir / "claim_boundary_matrix.csv").open(newline="", encoding="utf-8") as handle:
    claim_rows = list(csv.DictReader(handle))
if not any(row["status"] == "allowed" for row in claim_rows):
    raise SystemExit("v16 claim matrix has no allowed claims")
if not any(row["status"] == "blocked" and "Release-ready" in row["claim"] for row in claim_rows):
    raise SystemExit("v16 claim matrix did not block release claim")

manifest = json.loads((packet_dir / "v16_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v16_ready") != 1 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v16 manifest readiness mismatch")

with (packet_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required:
    if rel in {"artifact_manifest.csv", "v16_manifest.json"}:
        continue
    if rel not in by_path:
        raise SystemExit(f"v16 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(packet_dir / rel):
        raise SystemExit(f"v16 artifact manifest hash mismatch: {rel}")

with (packet_dir / "commercial_acceptance_rows.csv").open(newline="", encoding="utf-8") as handle:
    acceptance_rows = list(csv.DictReader(handle))
if any(row["ready"] != "1" for row in acceptance_rows):
    raise SystemExit("v16 commercial acceptance row not ready")
PY

echo "v16 research/commercial tracks smoke passed"
