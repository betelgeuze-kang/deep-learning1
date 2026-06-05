#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
ARTIFACT_DIR="$RESULTS_DIR/v40_machine_verified_research_artifact/artifact_001"
SUMMARY_CSV="$RESULTS_DIR/v40_machine_verified_research_artifact_summary.csv"
DECISION_CSV="$RESULTS_DIR/v40_machine_verified_research_artifact_decision.csv"

"$ROOT_DIR/experiments/run_v40_machine_verified_research_artifact.sh" >/dev/null

python3 - "$ARTIFACT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

artifact_dir = Path(sys.argv[1])
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

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v40 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
for field in [
    "v40_machine_verified_research_artifact_ready",
    "automated_research_artifact_ready",
    "machine_verified_prototype_ready",
    "v36_release_claim_audit_packet_ready",
    "v37_human_review_intake_ready",
    "v38_human_review_dispatch_bundle_ready",
    "v39_human_review_dispatch_archive_ready",
    "human_review_required_for_public_release",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v40 {field}: expected 1, got {summary.get(field)}")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v40 must not open human review or release readiness")
if int(summary.get("allowed_claim_rows", "0")) < 2:
    raise SystemExit("v40 should include bounded allowed claims")
if int(summary.get("blocked_claim_rows", "0")) < 8:
    raise SystemExit("v40 should block stronger claims")
if int(summary.get("artifact_rows", "0")) < 25:
    raise SystemExit("v40 should hash its copied evidence and boundary files")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v40-machine-verified-research-artifact",
    "v36-release-claim-audit",
    "v37-human-review-intake",
    "v38-dispatch-bundle",
    "v39-dispatch-archive",
    "automated-research-artifact",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v40 gate should pass: {gate}")
for gate in ["human-reviewed-release", "real-release-package", "production-readiness"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v40 should leave {gate} blocked")

required_files = [
    "MACHINE_VERIFIED_RESEARCH_ARTIFACT.md",
    "release_mode_rows.csv",
    "allowed_claim_rows.csv",
    "blocked_claim_rows.csv",
    "evidence_index.csv",
    "artifact_manifest.csv",
    "v40_machine_verified_research_artifact_manifest.json",
    "sha256_manifest.csv",
    "evidence/v36/RELEASE_CLAIM_AUDIT.md",
    "evidence/v36/claim_matrix.csv",
    "evidence/v36/summary.csv",
    "evidence/v37/human_review_intake_manifest.json",
    "evidence/v37/missing_review_rows.csv",
    "evidence/v37/summary.csv",
    "evidence/v38/HUMAN_REVIEW_DISPATCH_README.md",
    "evidence/v38/human_review_dispatch_manifest.json",
    "evidence/v38/summary.csv",
    "evidence/v39/SEND_ARCHIVE_README.md",
    "evidence/v39/human_review_dispatch_archive_manifest.json",
    "evidence/v39/artifact_manifest.csv",
    "evidence/v39/summary.csv",
]
for rel in required_files:
    path = artifact_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v40 missing artifact: {rel}")

manifest = json.loads((artifact_dir / "v40_machine_verified_research_artifact_manifest.json").read_text(encoding="utf-8"))
if manifest.get("automated_research_artifact_ready") != 1:
    raise SystemExit("v40 manifest should mark automated research artifact ready")
if manifest.get("machine_verified_prototype_ready") != 1:
    raise SystemExit("v40 manifest should mark machine verified prototype ready")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v40 manifest must keep human review/release blocked")
if manifest.get("human_review_required_for_public_release") != 1:
    raise SystemExit("v40 manifest should require human review for public release")
if "not a human-reviewed release package" not in manifest.get("notice", ""):
    raise SystemExit("v40 manifest should carry the not-human-reviewed notice")
if "local evidence-bound QA/audit architecture" not in manifest.get("allowed_claim", ""):
    raise SystemExit("v40 allowed claim should remain bounded")

release_mode_rows = read_csv(artifact_dir / "release_mode_rows.csv")
if len(release_mode_rows) != 1:
    raise SystemExit("v40 release mode should contain one row")
release_mode = release_mode_rows[0]
if release_mode.get("release_mode") != "machine_verified_research_artifact":
    raise SystemExit("v40 release mode name should be machine_verified_research_artifact")
for field in ["automated_research_artifact_ready", "machine_verified_prototype_ready", "human_review_required_for_public_release"]:
    if release_mode.get(field) != "1":
        raise SystemExit(f"v40 release mode {field} should be 1")
for field in ["human_review_completed", "real_release_package_ready"]:
    if release_mode.get(field) != "0":
        raise SystemExit(f"v40 release mode {field} should be 0")

blocked = {row["claim_id"]: row for row in read_csv(artifact_dir / "blocked_claim_rows.csv")}
for claim_id in [
    "human-reviewed-release",
    "production-ready-product",
    "release-ready-product",
    "general-llm-replacement",
    "transformer-replacement",
    "frontier-local-llm",
    "frontier-long-context-solved",
    "gpu-acceleration-proven",
    "full-commercial-deployment-ready",
]:
    row = blocked.get(claim_id)
    if row is None or row.get("allowed") != "0" or row.get("status") != "blocked":
        raise SystemExit(f"v40 should block claim: {claim_id}")

allowed = {row["claim_id"]: row for row in read_csv(artifact_dir / "allowed_claim_rows.csv")}
if allowed.get("machine-verified-research-artifact", {}).get("allowed") != "1":
    raise SystemExit("v40 should allow the machine-verified research artifact claim")
if "local evidence-bound QA/audit architecture" not in allowed.get("bounded-local-qa-audit-architecture", {}).get("public_wording", ""):
    raise SystemExit("v40 should inherit bounded v36 public wording")

evidence = {row["evidence_id"]: row for row in read_csv(artifact_dir / "evidence_index.csv")}
if set(evidence) != {
    "v36-release-claim-audit",
    "v37-human-review-intake",
    "v38-human-review-dispatch-bundle",
    "v39-human-review-dispatch-archive",
}:
    raise SystemExit("v40 evidence index should bind v36-v39")
if any(row["ready"] != "1" for row in evidence.values()):
    raise SystemExit("v40 evidence index rows should be ready")

readme = (artifact_dir / "MACHINE_VERIFIED_RESEARCH_ARTIFACT.md").read_text(encoding="utf-8")
for snippet in [
    "not a human-reviewed release package",
    "`automated_research_artifact_ready=1` is allowed",
    "`human_review_completed=0` remains explicit",
    "`real_release_package_ready=0` remains explicit",
    "Human-reviewed release",
    "experiments/test_v40_machine_verified_research_artifact.sh",
]:
    if snippet not in readme:
        raise SystemExit(f"v40 artifact readme missing: {snippet}")

with (artifact_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v40 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(artifact_dir / rel):
        raise SystemExit(f"v40 sha mismatch for {rel}")
PY

echo "v40 machine verified research artifact smoke passed"
