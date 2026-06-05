#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v37_human_review_intake"
INTAKE_ID="${V37_INTAKE_ID:-intake_001}"
INTAKE_DIR="${V37_INTAKE_DIR:-$RESULTS_DIR/${PREFIX}/$INTAKE_ID}"
DEFAULT_V36_PACKET_DIR="$RESULTS_DIR/v36_release_claim_audit_packet/packet_001"
V36_PACKET_DIR="${V37_V36_PACKET_DIR:-$DEFAULT_V36_PACKET_DIR}"
DEFAULT_REVIEW_ROWS="$V36_PACKET_DIR/human_review/human_review_rows.csv"
HUMAN_REVIEW_ROWS="${V37_HUMAN_REVIEW_ROWS:-$DEFAULT_REVIEW_ROWS}"
SUMMARY_CSV="${V37_SUMMARY_CSV:-$RESULTS_DIR/${PREFIX}_summary.csv}"
DECISION_CSV="${V37_DECISION_CSV:-$RESULTS_DIR/${PREFIX}_decision.csv}"

if [ ! -f "$V36_PACKET_DIR/v36_release_claim_audit_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v36_release_claim_audit_packet.sh" >/dev/null
fi

mkdir -p "$INTAKE_DIR"

python3 - "$ROOT_DIR" "$INTAKE_DIR" "$V36_PACKET_DIR" "$HUMAN_REVIEW_ROWS" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
intake_dir = Path(sys.argv[2])
v36_packet_dir = Path(sys.argv[3])
review_rows_path = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])

if intake_dir.exists():
    shutil.rmtree(intake_dir)
intake_dir.mkdir(parents=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def rel(path):
    return str(path.relative_to(root))

def copy_file(src, dst):
    if not src.is_file():
        raise SystemExit(f"missing required source file: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

required_review_items = [
    "clean-runner-acceptability",
    "bounded-claim-support",
    "blocked-claims-correctness",
    "limited-public-reference",
]

v36_manifest_path = v36_packet_dir / "v36_release_claim_audit_manifest.json"
v36_review_request = v36_packet_dir / "human_review" / "HUMAN_REVIEW_REQUEST.md"
v36_review_template = v36_packet_dir / "human_review" / "human_review_template.csv"
v36_summary_path = root / "results" / "v36_release_claim_audit_packet_summary.csv"
for path in [v36_manifest_path, v36_review_request, v36_review_template, v36_summary_path]:
    if not path.is_file():
        raise SystemExit(f"v37 requires v36 artifact: {path}")

v36_manifest = read_json(v36_manifest_path)
v36_ready = int(v36_manifest.get("evidence_inputs_ready") == 1 and v36_manifest.get("maximum_allowed_claim_decided") == 1)
copy_file(v36_manifest_path, intake_dir / "evidence" / "v36_release_claim_audit_manifest.json")
copy_file(v36_review_request, intake_dir / "evidence" / "HUMAN_REVIEW_REQUEST.md")
copy_file(v36_review_template, intake_dir / "evidence" / "human_review_template.csv")
copy_file(v36_summary_path, intake_dir / "evidence" / "v36_summary.csv")

review_supplied = int(review_rows_path.is_file())
review_rows = read_csv(review_rows_path) if review_supplied else []
if review_supplied:
    copy_file(review_rows_path, intake_dir / "human_review_rows.csv")

by_item = {row.get("review_item", ""): row for row in review_rows}
missing_items = [item for item in required_review_items if item not in by_item]
reviewer_values = {row.get("reviewer", "").strip() for row in review_rows if row.get("reviewer", "").strip()}
timestamp_ready = all(row.get("review_timestamp_utc", "").strip() for row in review_rows) if review_rows else False
all_pass = bool(review_rows) and all(by_item.get(item, {}).get("status") == "pass" for item in required_review_items)
required_items_present = int(review_supplied and not missing_items)
reviewer_identity_ready = int(bool(reviewer_values))
review_timestamps_ready = int(timestamp_ready)
clean_runner_accepted = int(by_item.get("clean-runner-acceptability", {}).get("status") == "pass")
bounded_claim_supported = int(by_item.get("bounded-claim-support", {}).get("status") == "pass")
blocked_claims_approved = int(by_item.get("blocked-claims-correctness", {}).get("status") == "pass")
limited_public_reference_approved = int(by_item.get("limited-public-reference", {}).get("status") == "pass")
non_github_rerun_required = int(any(row.get("status") in {"requires-non-github-rerun", "rerun-required"} for row in review_rows))
evidence_set_human_review_accepted = int(
    v36_ready
    and review_supplied
    and required_items_present
    and reviewer_identity_ready
    and review_timestamps_ready
    and all_pass
)
human_review_completed = evidence_set_human_review_accepted
real_release_package_ready = 0
v37_ready = int(v36_ready and (v36_review_request.is_file() and v36_review_template.is_file()))

normalized_rows = []
for item in required_review_items:
    row = by_item.get(item, {})
    normalized_rows.append(
        {
            "review_item": item,
            "status": row.get("status", "missing"),
            "reason": row.get("reason", ""),
            "reviewer": row.get("reviewer", ""),
            "review_timestamp_utc": row.get("review_timestamp_utc", ""),
            "present": int(item in by_item),
            "pass": int(row.get("status") == "pass"),
        }
    )
write_csv(
    intake_dir / "normalized_human_review_rows.csv",
    ["review_item", "status", "reason", "reviewer", "review_timestamp_utc", "present", "pass"],
    normalized_rows,
)

missing_rows = [{"review_item": item, "reason": "required review item missing"} for item in missing_items]
write_csv(intake_dir / "missing_review_rows.csv", ["review_item", "reason"], missing_rows)

manifest = {
    "manifest_scope": "v37-human-review-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "intake_id": intake_dir.name,
    "v36_packet_dir": rel(v36_packet_dir),
    "v36_release_claim_audit_packet_ready": v36_ready,
    "review_rows_path": str(review_rows_path),
    "human_review_return_supplied": review_supplied,
    "required_review_items_present": required_items_present,
    "reviewer_identity_ready": reviewer_identity_ready,
    "review_timestamps_ready": review_timestamps_ready,
    "clean_runner_accepted": clean_runner_accepted,
    "bounded_claim_supported": bounded_claim_supported,
    "blocked_claims_approved": blocked_claims_approved,
    "limited_public_reference_approved": limited_public_reference_approved,
    "non_github_rerun_required": non_github_rerun_required,
    "evidence_set_human_review_accepted": evidence_set_human_review_accepted,
    "human_review_completed": human_review_completed,
    "real_release_package_ready": real_release_package_ready,
    "claim": "human review intake verifier; it can accept returned review rows but does not create release readiness by itself",
}
write_json(intake_dir / "human_review_intake_manifest.json", manifest)

sha_rows = []
for path in sorted(intake_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(intake_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(intake_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "intake_id": intake_dir.name,
        "v37_human_review_intake_ready": v37_ready,
        "v36_release_claim_audit_packet_ready": v36_ready,
        "human_review_return_supplied": review_supplied,
        "required_review_items_present": required_items_present,
        "reviewer_identity_ready": reviewer_identity_ready,
        "review_timestamps_ready": review_timestamps_ready,
        "clean_runner_accepted": clean_runner_accepted,
        "bounded_claim_supported": bounded_claim_supported,
        "blocked_claims_approved": blocked_claims_approved,
        "limited_public_reference_approved": limited_public_reference_approved,
        "non_github_rerun_required": non_github_rerun_required,
        "evidence_set_human_review_accepted": evidence_set_human_review_accepted,
        "human_review_completed": human_review_completed,
        "real_release_package_ready": real_release_package_ready,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v37-human-review-intake", "status": status(v37_ready), "reason": "v36 human review request and template are present" if v37_ready else "v36 human review request missing"},
    {"gate": "human-review-return", "status": status(review_supplied), "reason": "human_review_rows.csv supplied" if review_supplied else f"missing returned review rows at {review_rows_path}"},
    {"gate": "required-review-items", "status": status(required_items_present), "reason": "all required review items are present" if required_items_present else "missing: " + "|".join(missing_items)},
    {"gate": "reviewer-identity", "status": status(reviewer_identity_ready), "reason": "reviewer identity supplied" if reviewer_identity_ready else "reviewer identity missing"},
    {"gate": "review-timestamps", "status": status(review_timestamps_ready), "reason": "review timestamps supplied" if review_timestamps_ready else "review timestamps missing"},
    {"gate": "evidence-set-human-review", "status": status(evidence_set_human_review_accepted), "reason": "all review rows pass" if evidence_set_human_review_accepted else "review incomplete or did not pass all required rows"},
    {"gate": "non-github-rerun", "status": "blocked" if non_github_rerun_required else "pass", "reason": "review requires a non-GitHub independent rerun" if non_github_rerun_required else "no non-GitHub rerun requested by review rows"},
    {"gate": "real-release-package", "status": "blocked", "reason": "v37 verifies review intake only; release package remains a separate gate"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v37_human_review_intake_dir: $INTAKE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
