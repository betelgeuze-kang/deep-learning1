#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKAGE_DIR="$RESULTS_DIR/v17_post_v16_externalization_handoff/package_001"
SUMMARY_CSV="$RESULTS_DIR/v17_post_v16_externalization_handoff_summary.csv"
DECISION_CSV="$RESULTS_DIR/v17_post_v16_externalization_handoff_decision.csv"

"$ROOT_DIR/experiments/run_v17_post_v16_externalization_handoff.sh" >/dev/null

python3 - "$PACKAGE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

package_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v17 summary row, got {len(rows)}")
summary = rows[0]
expected = {
    "handoff_ready": "1",
    "third_party_rerun_handoff_ready": "1",
    "independent_rerun_actual_ready": "0",
    "official_benchmark_reconciliation_intake_ready": "1",
    "candidate_external_benchmark_result_ready": "0",
    "commercial_local_poc_intake_ready": "1",
    "closed_corpus_poc_actual_ready": "0",
    "real_external_benchmark_verified": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v17 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("artifact_rows", "0")) < 18:
    raise SystemExit("v17 artifact count too small")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in ["third-party-rerun-handoff", "official-benchmark-reconciliation-intake", "commercial-local-poc-intake"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v17 decision did not pass: {gate}")
for gate in ["independent-rerun-actual", "candidate-external-benchmark-result", "closed-corpus-poc-actual", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v17 decision should remain blocked: {gate}")

required = [
    "handoff_manifest.json",
    "artifact_manifest.csv",
    "docs/POST_V16_EXTERNALIZATION.md",
    "third_party_rerun/EXTERNAL_REPRODUCE.sh",
    "third_party_rerun/README.md",
    "third_party_rerun/required_external_rerun_artifacts.csv",
    "third_party_rerun/rerun_manifest_template.csv",
    "official_benchmark_reconciliation/README.md",
    "official_benchmark_reconciliation/official_reconciliation_requirements.csv",
    "official_benchmark_reconciliation/candidate_result_template.csv",
    "commercial_local_poc/README.md",
    "commercial_local_poc/poc_acceptance_criteria.csv",
    "commercial_local_poc/domain_intake_template.csv",
    "baseline_inputs/v15a_package_manifest.json",
    "baseline_inputs/v15a_REPRODUCE.sh",
    "baseline_inputs/v15b_review_manifest.json",
    "baseline_inputs/v16_manifest.json",
]
for rel in required:
    path = package_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v17 artifact: {rel}")

manifest = json.loads((package_dir / "handoff_manifest.json").read_text(encoding="utf-8"))
if manifest.get("handoff_ready") != 1:
    raise SystemExit("v17 handoff manifest not ready")
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v17 manifest overstated actual readiness: {field}")

with (package_dir / "artifact_manifest.csv").open(newline="", encoding="utf-8") as handle:
    artifact_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in artifact_rows}
for rel in required:
    if rel in {"artifact_manifest.csv", "handoff_manifest.json"}:
        continue
    if rel not in by_path:
        raise SystemExit(f"v17 artifact manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(package_dir / rel):
        raise SystemExit(f"v17 artifact hash mismatch: {rel}")

third_party_doc = (package_dir / "third_party_rerun" / "README.md").read_text(encoding="utf-8")
for phrase in ["independent_rerun_actual_ready=1", "reviewer identity", "metric delta"]:
    if phrase not in third_party_doc:
        raise SystemExit(f"v17 third-party doc missing phrase: {phrase}")
official_doc = (package_dir / "official_benchmark_reconciliation" / "README.md").read_text(encoding="utf-8")
for phrase in ["official source snapshot", "no oracle", "RouteMemory-derived prediction lineage"]:
    if phrase not in official_doc:
        raise SystemExit(f"v17 official benchmark doc missing phrase: {phrase}")
commercial_doc = (package_dir / "commercial_local_poc" / "README.md").read_text(encoding="utf-8")
for phrase in ["local evidence-bound QA/audit system", "wrong-answer guard", "citation accuracy", "abstain behavior"]:
    if phrase not in commercial_doc:
        raise SystemExit(f"v17 commercial PoC doc missing phrase: {phrase}")
PY

echo "v17 post-v16 externalization handoff smoke passed"
