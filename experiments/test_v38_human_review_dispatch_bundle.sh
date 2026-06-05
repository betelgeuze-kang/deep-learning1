#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
BUNDLE_DIR="$RESULTS_DIR/v38_human_review_dispatch_bundle/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/v38_human_review_dispatch_bundle_summary.csv"
DECISION_CSV="$RESULTS_DIR/v38_human_review_dispatch_bundle_decision.csv"

"$ROOT_DIR/experiments/run_v38_human_review_dispatch_bundle.sh" >/dev/null

python3 - "$BUNDLE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

bundle_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v38 summary row, got {len(rows)}")
summary = rows[0]
for field in [
    "v38_human_review_dispatch_bundle_ready",
    "return_template_ready",
    "verify_script_ready",
    "v37_human_review_intake_ready",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v38 {field}: expected 1, got {summary.get(field)}")
if int(summary.get("review_packet_files", "0")) < 9:
    raise SystemExit("v38 should copy the complete review packet")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v38 should not complete review or release readiness")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v38-human-review-dispatch-bundle",
    "review-packet",
    "return-template",
    "verify-return-script",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v38 gate should pass: {gate}")
for gate in ["human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v38 should leave {gate} blocked")

required_files = [
    "HUMAN_REVIEW_DISPATCH_README.md",
    "dispatch_rows.csv",
    "human_review_dispatch_manifest.json",
    "sha256_manifest.csv",
    "review_packet/HUMAN_REVIEW_REQUEST.md",
    "review_packet/human_review_template.csv",
    "review_packet/RELEASE_CLAIM_AUDIT.md",
    "review_packet/claim_matrix.csv",
    "review_packet/release_decision_rows.csv",
    "review_packet/evidence_input_rows.csv",
    "review_packet/v36_release_claim_audit_manifest.json",
    "review_packet/v37_human_review_intake_manifest.json",
    "review_packet/v37_missing_review_rows.csv",
    "return/human_review_rows.csv",
    "verify/VERIFY_RETURN.sh",
]
for rel in required_files:
    path = bundle_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v38 missing bundle artifact: {rel}")

manifest = json.loads((bundle_dir / "human_review_dispatch_manifest.json").read_text(encoding="utf-8"))
if manifest.get("human_review_dispatch_bundle_ready") != 1:
    raise SystemExit("v38 manifest should be ready")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v38 manifest should keep review/release blocked")

readme = (bundle_dir / "HUMAN_REVIEW_DISPATCH_README.md").read_text(encoding="utf-8")
for snippet in [
    "Send `review_packet/` to the reviewer.",
    "Reviewer return:",
    "VERIFY_RETURN.sh",
    "does not set `human_review_completed=1`",
]:
    if snippet not in readme:
        raise SystemExit(f"v38 dispatch readme missing: {snippet}")

verify_text = (bundle_dir / "verify" / "VERIFY_RETURN.sh").read_text(encoding="utf-8")
if "V37_HUMAN_REVIEW_ROWS" not in verify_text or "run_v37_human_review_intake.sh" not in verify_text:
    raise SystemExit("v38 verify script should invoke v37 with returned rows")

with (bundle_dir / "review_packet" / "human_review_template.csv").open(newline="", encoding="utf-8") as handle:
    template_rows = list(csv.DictReader(handle))
if {row["review_item"] for row in template_rows} != {
    "clean-runner-acceptability",
    "bounded-claim-support",
    "blocked-claims-correctness",
    "limited-public-reference",
}:
    raise SystemExit("v38 review template should contain the four required review items")

with (bundle_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v38 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(bundle_dir / rel):
        raise SystemExit(f"v38 sha mismatch for {rel}")
PY

echo "v38 human review dispatch bundle smoke passed"
