#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fj_post_fi_real_manifest_external_review_send_return_bundle"
RUN_DIR="$RESULTS_DIR/$PREFIX/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BUNDLE_DIR="$RUN_DIR/real_manifest_external_review_send_return_bundle"

V61FJ_REUSE_EXISTING="${V61FJ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fj_post_fi_real_manifest_external_review_send_return_bundle.sh" >/dev/null

"$BUNDLE_DIR/VERIFY_SEND_RETURN_BUNDLE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$BUNDLE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
bundle_dir = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready": "1",
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": "1",
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fg_post_ff_real_manifest_external_review_packet_ready": "1",
    "send_return_bundle_ready": "1",
    "review_packet_files": "11",
    "return_template_files": "6",
    "bundle_file_rows": "23",
    "metadata_only_bundle_file_rows": "23",
    "payload_like_bundle_file_rows": "0",
    "required_review_return_artifacts": "6",
    "accepted_review_return_artifacts": "0",
    "missing_review_return_artifacts": "6",
    "candidate_external_review_return_ready": "0",
    "external_review_return_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fj {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fi_real_manifest_external_review_return_template_rows.csv",
    "post_fi_real_manifest_external_review_send_return_bundle_file_rows.csv",
    "post_fi_real_manifest_external_review_send_return_bundle_requirement_rows.csv",
    "V61FJ_POST_FI_REAL_MANIFEST_EXTERNAL_REVIEW_SEND_RETURN_BUNDLE_BOUNDARY.md",
    "v61fj_post_fi_real_manifest_external_review_send_return_bundle_manifest.json",
    "real_manifest_external_review_send_return_bundle/SEND_RETURN_BUNDLE_README.md",
    "real_manifest_external_review_send_return_bundle/SEND_RETURN_BUNDLE_MANIFEST.json",
    "real_manifest_external_review_send_return_bundle/VERIFY_SEND_RETURN_BUNDLE.sh",
    "real_manifest_external_review_send_return_bundle/SEND_RETURN_BUNDLE_FILE_LIST.txt",
    "real_manifest_external_review_send_return_bundle/SEND_RETURN_BUNDLE_SHA256SUMS.txt",
    "real_manifest_external_review_send_return_bundle/RETURN_TEMPLATE_ROWS.csv",
    "source_v61fi/post_fh_real_manifest_external_review_acceptance_bridge_rows.csv",
    "source_v61fh/real_manifest_external_review_required_artifact_rows.csv",
    "source_v61fg/post_ff_real_manifest_external_review_checklist_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fj artifact: {rel}")

template_rows = read_csv(run_dir / "post_fi_real_manifest_external_review_return_template_rows.csv")
if len(template_rows) != 6:
    raise SystemExit("v61fj expected six template rows")
if any(row["template_file_ready"] != "1" or row["accepted_by_default"] != "0" for row in template_rows):
    raise SystemExit("v61fj templates must be ready but not accepted by default")

bundle_files = read_csv(run_dir / "post_fi_real_manifest_external_review_send_return_bundle_file_rows.csv")
if len(bundle_files) != 23:
    raise SystemExit(f"v61fj bundle file count mismatch: {len(bundle_files)}")
if sum(row["review_packet_file"] == "1" for row in bundle_files) != 11:
    raise SystemExit("v61fj review packet file count mismatch")
if sum(row["return_template_file"] == "1" for row in bundle_files) != 6:
    raise SystemExit("v61fj return template file count mismatch")
if any(row["payload_like_file"] != "0" for row in bundle_files):
    raise SystemExit("v61fj bundle must not include payload-like files")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "post_fi_real_manifest_external_review_send_return_bundle_requirement_rows.csv")}
for requirement_id in [
    "v61fi-acceptance-bridge-input",
    "review-packet-files-copied",
    "return-template-files-created",
    "templates-not-accepted-evidence",
]:
    if requirements[requirement_id] != "pass":
        raise SystemExit(f"v61fj requirement should pass: {requirement_id}")
for requirement_id in ["external-review-return", "actual-generation"]:
    if requirements[requirement_id] != "blocked":
        raise SystemExit(f"v61fj requirement should stay blocked: {requirement_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("repo-checkpoint-payload") != "pass":
    raise SystemExit("v61fj repo checkpoint payload gate should pass")
for gate in ["external-review-return", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fj decision should stay blocked: {gate}")

manifest = json.loads((bundle_dir / "SEND_RETURN_BUNDLE_MANIFEST.json").read_text(encoding="utf-8"))
for key in ["external_review_return_ready", "actual_model_generation_ready", "checkpoint_payload_bytes_committed_to_repo"]:
    if manifest.get(key) != 0:
        raise SystemExit(f"v61fj manifest must keep {key}=0")

if not os.access(bundle_dir / "VERIFY_SEND_RETURN_BUNDLE.sh", os.X_OK):
    raise SystemExit("v61fj verifier must be executable")

readme = (bundle_dir / "SEND_RETURN_BUNDLE_README.md").read_text(encoding="utf-8")
for snippet in ["template-only", "not accepted review", "actual_model_generation_ready=0"]:
    if snippet not in readme:
        raise SystemExit(f"v61fj readme missing snippet: {snippet}")

boundary = (run_dir / "V61FJ_POST_FI_REAL_MANIFEST_EXTERNAL_REVIEW_SEND_RETURN_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "send_return_bundle_ready=1",
    "review_packet_files=11",
    "return_template_files=6",
    "bundle_file_rows=23",
    "accepted_review_return_artifacts=0/6",
    "external_review_return_ready=0",
    "real_return_replay_admission_ready=0",
    "row_acceptance_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fj boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fj sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fj produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fj post-fi real manifest external review send-return bundle smoke passed"
