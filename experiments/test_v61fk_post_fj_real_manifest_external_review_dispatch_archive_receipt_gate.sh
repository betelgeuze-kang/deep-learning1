#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/dispatch_001"
FIXTURE_RECEIPT_DIR="$RESULTS_DIR/$PREFIX/fixture_dispatch_receipt_input"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_dispatch_receipt_preflight_v61fk"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61FJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fj_post_fi_real_manifest_external_review_send_return_bundle.sh" >/dev/null

V61FK_REUSE_EXISTING="${V61FK_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh" >/dev/null

"$RUN_DIR/real_manifest_external_review_dispatch_archive/VERIFY_DISPATCH_ARCHIVE.sh" >/dev/null

rm -rf "$FIXTURE_RECEIPT_DIR"
mkdir -p "$FIXTURE_RECEIPT_DIR"

python3 - "$RUN_DIR" "$FIXTURE_RECEIPT_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
receipt_dir = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


contract_rows = read_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_contract_rows.csv")
payload = {
    "dispatch_archive_sha256": contract_rows[0]["expected_value"],
    "send_return_bundle_sha256sum_sha256": contract_rows[1]["expected_value"],
    "operator_identity": "fixture-v61fk-operator",
    "sent_at_utc": "2026-06-14T00:00:00+00:00",
    "recipient": "fixture-v61fk-reviewer",
    "receipt_status": "sent",
    "review_packet_files": 11,
    "return_template_files": 6,
}
(receipt_dir / "DISPATCH_RECEIPT.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61FK_RUN_ID="fixture_dispatch_receipt_preflight_v61fk" \
V61FK_DISPATCH_RECEIPT_DIR="$FIXTURE_RECEIPT_DIR" \
V61FK_RECEIPT_PROVENANCE="fixture-v61fk-dispatch-receipt" \
V61FK_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh" >/dev/null

V61FK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import sys
import tarfile
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
dispatch_dir = run_dir / "real_manifest_external_review_dispatch_archive"


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
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready": "1",
    "v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready": "1",
    "dispatch_archive_ready": "1",
    "dispatch_archive_sha256_ready": "1",
    "dispatch_archive_file_list_ready": "1",
    "dispatch_archive_member_files": "23",
    "metadata_only_dispatch_archive_member_rows": "23",
    "review_packet_archive_member_rows": "11",
    "return_template_archive_member_rows": "6",
    "payload_like_dispatch_archive_member_rows": "0",
    "dispatch_receipt_template_ready": "1",
    "required_dispatch_receipt_field_rows": "8",
    "receipt_dir_supplied": "0",
    "receipt_dir_exists": "0",
    "selected_receipt_source_class": "none",
    "dispatch_receipt_file_present": "0",
    "dispatch_receipt_json_readable": "0",
    "present_dispatch_receipt_field_rows": "0",
    "dispatch_archive_sha_match": "0",
    "send_return_bundle_sha_match": "0",
    "receipt_status_sent": "0",
    "dispatch_receipt_candidate_preflight_ready": "0",
    "non_fixture_dispatch_receipt": "0",
    "real_dispatch_receipt_provenance_asserted": "0",
    "real_dispatch_receipt_ready": "0",
    "accepted_dispatch_receipt_rows": "0",
    "external_review_return_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fk": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fk {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_manifest_external_review_dispatch_archive/v61fj_real_manifest_external_review_send_return_bundle_001.tar.gz",
    "real_manifest_external_review_dispatch_archive/DISPATCH_ARCHIVE_FILE_LIST.txt",
    "real_manifest_external_review_dispatch_archive/DISPATCH_ARCHIVE_SHA256SUMS.txt",
    "real_manifest_external_review_dispatch_archive/DISPATCH_RECEIPT_TEMPLATE.json",
    "real_manifest_external_review_dispatch_archive/VERIFY_DISPATCH_ARCHIVE.sh",
    "SEND_REAL_MANIFEST_EXTERNAL_REVIEW_DISPATCH_ARCHIVE.md",
    "post_fj_real_manifest_external_review_dispatch_archive_member_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_archive_artifact_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_receipt_contract_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_receipt_file_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_receipt_field_check_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_receipt_preflight_check_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_command_rows.csv",
    "post_fj_real_manifest_external_review_dispatch_receipt_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61FK_POST_FJ_REAL_MANIFEST_EXTERNAL_REVIEW_DISPATCH_ARCHIVE_RECEIPT_GATE_BOUNDARY.md",
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_manifest.json",
    "source_v61fj/v61fj_post_fi_real_manifest_external_review_send_return_bundle_summary.csv",
    "source_v61fj/post_fi_real_manifest_external_review_send_return_bundle_file_rows.csv",
    "source_v61fj/SEND_RETURN_BUNDLE_SHA256SUMS.txt",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fk artifact: {rel}")

if not os.access(dispatch_dir / "VERIFY_DISPATCH_ARCHIVE.sh", os.X_OK):
    raise SystemExit("v61fk verifier must be executable")

archive_path = dispatch_dir / "v61fj_real_manifest_external_review_send_return_bundle_001.tar.gz"
with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())
if len(members) != 23:
    raise SystemExit(f"v61fk expected 23 archive members, got {len(members)}")
if sum("/review_packet/" in member for member in members) != 11:
    raise SystemExit("v61fk review packet archive member count mismatch")
if sum("/return_scaffold/" in member for member in members) != 6:
    raise SystemExit("v61fk return template archive member count mismatch")
if any(member.endswith((".safetensors", ".bin", ".pt")) for member in members):
    raise SystemExit("v61fk archive contains payload-like member")

member_rows = read_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_archive_member_rows.csv")
if len(member_rows) != 23:
    raise SystemExit("v61fk member rows mismatch")
if any(row["metadata_only_member"] != "1" for row in member_rows):
    raise SystemExit("v61fk archive members should all be metadata-only")
if any(row["payload_like_member"] != "0" for row in member_rows):
    raise SystemExit("v61fk member rows include payload-like member")

contract_rows = read_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_contract_rows.csv")
if len(contract_rows) != 8:
    raise SystemExit("v61fk expected eight receipt fields")
if any(row["accepted_by_default"] != "0" for row in contract_rows):
    raise SystemExit("v61fk receipt contract must not be accepted by default")

checks = {row["check_id"]: row["status"] for row in read_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_preflight_check_rows.csv")}
for check in [
    "v61fj-send-return-bundle-input",
    "dispatch-archive-file",
    "dispatch-archive-sha256",
    "dispatch-archive-file-list",
    "review-packet-members",
    "return-template-members",
    "no-checkpoint-payload",
    "dispatch-receipt-template",
]:
    if checks[check] != "pass":
        raise SystemExit(f"v61fk canonical check should pass: {check}")
for check in [
    "receipt-dir-supplied",
    "dispatch-receipt-file-present",
    "dispatch-receipt-candidate-preflight-ready",
    "non-fixture-dispatch-receipt",
    "real-dispatch-receipt-provenance",
    "real-dispatch-receipt-ready",
    "external-review-return",
    "actual-model-generation",
]:
    if checks[check] != "blocked":
        raise SystemExit(f"v61fk canonical check should be blocked: {check}")

commands = read_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_command_rows.csv")
if [row["ready_to_run_now"] for row in commands] != ["1", "1", "0", "0"]:
    raise SystemExit("v61fk canonical command readiness mismatch")

fixture_metric = read_csv(fixture_run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_metric_rows.csv")[0]
fixture_expected = {
    "receipt_dir_supplied": "1",
    "receipt_dir_exists": "1",
    "selected_receipt_source_class": "fixture-v61fk-dispatch-receipt",
    "dispatch_receipt_file_present": "1",
    "dispatch_receipt_json_readable": "1",
    "required_dispatch_receipt_field_rows": "8",
    "present_dispatch_receipt_field_rows": "8",
    "dispatch_archive_sha_match": "1",
    "send_return_bundle_sha_match": "1",
    "receipt_status_sent": "1",
    "dispatch_receipt_candidate_preflight_ready": "1",
    "non_fixture_dispatch_receipt": "0",
    "real_dispatch_receipt_provenance_asserted": "0",
    "real_dispatch_receipt_ready": "0",
    "accepted_dispatch_receipt_rows": "0",
    "external_review_return_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61fk fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_checks = {row["check_id"]: row["status"] for row in read_csv(fixture_run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_preflight_check_rows.csv")}
for check in [
    "receipt-dir-supplied",
    "dispatch-receipt-file-present",
    "dispatch-receipt-json-readable",
    "required-receipt-fields-present",
    "dispatch-archive-sha-match",
    "send-return-bundle-sha-match",
    "receipt-status-sent",
    "dispatch-receipt-candidate-preflight-ready",
]:
    if fixture_checks[check] != "pass":
        raise SystemExit(f"v61fk fixture check should pass: {check}")
for check in [
    "non-fixture-dispatch-receipt",
    "real-dispatch-receipt-provenance",
    "real-dispatch-receipt-ready",
    "external-review-return",
    "actual-model-generation",
]:
    if fixture_checks[check] != "blocked":
        raise SystemExit(f"v61fk fixture check should stay blocked: {check}")

if not (fixture_run_dir / "supplied_dispatch_receipt/DISPATCH_RECEIPT.json").is_file():
    raise SystemExit("v61fk fixture receipt was not copied")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61fj-send-return-bundle-input",
    "dispatch-archive-file",
    "dispatch-archive-sha256",
    "dispatch-archive-file-list",
    "review-packet-members",
    "return-template-members",
    "no-checkpoint-payload",
    "dispatch-receipt-template",
    "repo-checkpoint-payload",
]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61fk decision should pass: {gate}")
for gate in [
    "dispatch-receipt-candidate-preflight-ready",
    "non-fixture-dispatch-receipt",
    "real-dispatch-receipt-provenance",
    "real-dispatch-receipt-ready",
    "external-review-return",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fk decision should be blocked: {gate}")

boundary = (run_dir / "V61FK_POST_FJ_REAL_MANIFEST_EXTERNAL_REVIEW_DISPATCH_ARCHIVE_RECEIPT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "dispatch_archive_ready=1",
    "dispatch_archive_member_files=23",
    "review_packet_archive_member_rows=11",
    "return_template_archive_member_rows=6",
    "payload_like_dispatch_archive_member_rows=0",
    "dispatch_receipt_candidate_preflight_ready=0",
    "real_dispatch_receipt_ready=0",
    "external_review_return_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fk boundary missing snippet: {snippet}")

readme = (run_dir / "SEND_REAL_MANIFEST_EXTERNAL_REVIEW_DISPATCH_ARCHIVE.md").read_text(encoding="utf-8")
for snippet in ["transfer archive", "not accepted review evidence", "actual_model_generation_ready=0"]:
    if snippet not in readme:
        raise SystemExit(f"v61fk readme missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready") != 1:
    raise SystemExit("v61fk manifest readiness mismatch")
if manifest.get("real_dispatch_receipt_ready") != 0:
    raise SystemExit("v61fk canonical manifest must keep real receipt blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fk manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fk manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fk sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fk produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fk post-fj real manifest external review dispatch archive receipt gate smoke passed"
