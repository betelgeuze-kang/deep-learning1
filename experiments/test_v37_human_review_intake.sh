#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
DEFAULT_INTAKE_DIR="$RESULTS_DIR/v37_human_review_intake/intake_001"
FIXTURE_INTAKE_DIR="$RESULTS_DIR/v37_human_review_intake/fixture_pass"
SUMMARY_CSV="$RESULTS_DIR/v37_human_review_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v37_human_review_intake_decision.csv"
FIXTURE_ROWS="$RESULTS_DIR/v37_human_review_intake/fixture_human_review_rows.csv"

"$ROOT_DIR/experiments/run_v37_human_review_intake.sh" >/dev/null

python3 - "$DEFAULT_INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

intake_dir = Path(sys.argv[1])
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
    raise SystemExit(f"expected one v37 default summary row, got {len(rows)}")
summary = rows[0]
for field in ["v37_human_review_intake_ready", "v36_release_claim_audit_packet_ready"]:
    if summary.get(field) != "1":
        raise SystemExit(f"v37 default {field}: expected 1, got {summary.get(field)}")
for field in [
    "human_review_return_supplied",
    "required_review_items_present",
    "reviewer_identity_ready",
    "review_timestamps_ready",
    "evidence_set_human_review_accepted",
    "human_review_completed",
    "real_release_package_ready",
]:
    if summary.get(field) != "0":
        raise SystemExit(f"v37 default {field}: expected 0, got {summary.get(field)}")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
if decisions.get("v37-human-review-intake", {}).get("status") != "pass":
    raise SystemExit("v37 verifier should be ready by default")
for gate in ["human-review-return", "required-review-items", "reviewer-identity", "review-timestamps", "evidence-set-human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v37 default gate should be blocked: {gate}")

required_files = [
    "human_review_intake_manifest.json",
    "normalized_human_review_rows.csv",
    "missing_review_rows.csv",
    "sha256_manifest.csv",
    "evidence/v36_release_claim_audit_manifest.json",
    "evidence/HUMAN_REVIEW_REQUEST.md",
    "evidence/human_review_template.csv",
    "evidence/v36_summary.csv",
]
for rel in required_files:
    path = intake_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v37 default missing artifact: {rel}")
manifest = json.loads((intake_dir / "human_review_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v37 default manifest should keep review/release blocked")
with (intake_dir / "missing_review_rows.csv").open(newline="", encoding="utf-8") as handle:
    missing_rows = list(csv.DictReader(handle))
if len(missing_rows) != 4:
    raise SystemExit("v37 default should list four missing review items")
with (intake_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v37 default sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(intake_dir / rel):
        raise SystemExit(f"v37 default sha mismatch for {rel}")
PY

mkdir -p "$(dirname "$FIXTURE_ROWS")"
cat > "$FIXTURE_ROWS" <<'CSV'
review_item,status,reason,reviewer,review_timestamp_utc
clean-runner-acceptability,pass,GitHub-hosted clean-runner evidence is acceptable for this stage.,external-reviewer-fixture,2026-06-05T18:30:00Z
bounded-claim-support,pass,v34 and v35 support the bounded claim.,external-reviewer-fixture,2026-06-05T18:30:00Z
blocked-claims-correctness,pass,The stronger claims are correctly blocked.,external-reviewer-fixture,2026-06-05T18:30:00Z
limited-public-reference,pass,Limited public reference is acceptable while release readiness stays blocked.,external-reviewer-fixture,2026-06-05T18:30:00Z
CSV

V37_INTAKE_ID=fixture_pass V37_HUMAN_REVIEW_ROWS="$FIXTURE_ROWS" "$ROOT_DIR/experiments/run_v37_human_review_intake.sh" >/dev/null

python3 - "$FIXTURE_INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

intake_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

with summary_csv.open(newline="", encoding="utf-8") as handle:
    summary = list(csv.DictReader(handle))[0]
for field in [
    "v37_human_review_intake_ready",
    "human_review_return_supplied",
    "required_review_items_present",
    "reviewer_identity_ready",
    "review_timestamps_ready",
    "clean_runner_accepted",
    "bounded_claim_supported",
    "blocked_claims_approved",
    "limited_public_reference_approved",
    "evidence_set_human_review_accepted",
    "human_review_completed",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v37 fixture {field}: expected 1, got {summary.get(field)}")
if summary.get("real_release_package_ready") != "0":
    raise SystemExit("v37 fixture must still keep release readiness blocked")
with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v37-human-review-intake",
    "human-review-return",
    "required-review-items",
    "reviewer-identity",
    "review-timestamps",
    "evidence-set-human-review",
    "non-github-rerun",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v37 fixture gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v37 fixture should keep real-release-package blocked")
manifest = json.loads((intake_dir / "human_review_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("human_review_completed") != 1:
    raise SystemExit("v37 fixture manifest should complete human review")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v37 fixture manifest should not open release readiness")
PY

"$ROOT_DIR/experiments/run_v37_human_review_intake.sh" >/dev/null

python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    summary = list(csv.DictReader(handle))[0]
if summary.get("human_review_completed") != "0" or summary.get("human_review_return_supplied") != "0":
    raise SystemExit("v37 test should leave the default no-return state in the public summary")
PY

echo "v37 human review intake smoke passed"
