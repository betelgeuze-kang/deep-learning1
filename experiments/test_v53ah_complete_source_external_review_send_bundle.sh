#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ah_complete_source_external_review_send_bundle"
RUN_DIR="$RESULTS_DIR/$PREFIX/bundle_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BUNDLE_DIR="$RUN_DIR/send_bundle"
DISPATCH_ARCHIVE="$BUNDLE_DIR/review_dispatch/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz"
RETURN_INBOX_ARCHIVE="$BUNDLE_DIR/return_inbox/v53af_external_return_inbox_scaffold_001.tar.gz"

V53AH_REUSE_EXISTING="${V53AH_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ah_complete_source_external_review_send_bundle.sh" >/dev/null

"$BUNDLE_DIR/VERIFY_SEND_BUNDLE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$DISPATCH_ARCHIVE" "$RETURN_INBOX_ARCHIVE" <<'PY'
import csv
import hashlib
import json
import sys
import tarfile
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
dispatch_archive = Path(sys.argv[4])
return_inbox_archive = Path(sys.argv[5])
bundle_dir = run_dir / "send_bundle"


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
    "v53ah_complete_source_external_review_send_bundle_ready": "1",
    "v53ac_complete_source_review_dispatch_archive_ready": "1",
    "v53ag_external_return_inbox_archive_ready": "1",
    "send_bundle_ready": "1",
    "send_bundle_archive_files": "2",
    "dispatch_archive_ready": "1",
    "return_inbox_archive_ready": "1",
    "bundle_file_list_ready": "1",
    "bundle_sha256_ready": "1",
    "send_readme_ready": "1",
    "verify_script_ready": "1",
    "bundle_file_rows": "10",
    "required_bundle_file_rows": "10",
    "required_bundle_files_present": "1",
    "dispatch_archive_member_files": "78",
    "return_inbox_archive_member_files": "84",
    "template_archive_member_rows": "82",
    "return_artifact_template_archive_member_rows": "81",
    "required_return_artifact_rows": "81",
    "payload_like_bundle_file_rows": "0",
    "nested_payload_like_archive_member_rows": "0",
    "return_inbox_final_evidence_named_archive_member_rows": "0",
    "dispatch_chunk_rows": "21",
    "dispatch_task_rows": "8000",
    "dispatch_return_artifact_rows": "50",
    "dispatch_receipt_template_rows": "21",
    "accepted_dispatch_receipt_rows": "0",
    "expected_human_review_rows": "7000",
    "answer_review_accepted_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ah": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ah {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "send_bundle/review_dispatch/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz",
    "send_bundle/review_dispatch/ARCHIVE_FILE_LIST.txt",
    "send_bundle/review_dispatch/ARCHIVE_SHA256SUMS.txt",
    "send_bundle/return_inbox/v53af_external_return_inbox_scaffold_001.tar.gz",
    "send_bundle/return_inbox/ARCHIVE_FILE_LIST.txt",
    "send_bundle/return_inbox/ARCHIVE_SHA256SUMS.txt",
    "send_bundle/BUNDLE_FILE_LIST.txt",
    "send_bundle/BUNDLE_SHA256SUMS.txt",
    "send_bundle/SEND_BUNDLE_README.md",
    "send_bundle/VERIFY_SEND_BUNDLE.sh",
    "complete_source_external_review_send_bundle_file_rows.csv",
    "complete_source_external_review_send_bundle_nested_member_rows.csv",
    "complete_source_external_review_send_bundle_artifact_rows.csv",
    "complete_source_external_review_send_bundle_requirement_rows.csv",
    "complete_source_external_review_send_bundle_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AH_COMPLETE_SOURCE_EXTERNAL_REVIEW_SEND_BUNDLE_BOUNDARY.md",
    "v53ah_complete_source_external_review_send_bundle_manifest.json",
    "source_v53ac/v53ac_complete_source_review_dispatch_archive_summary.csv",
    "source_v53ag/v53ag_external_return_inbox_archive_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ah artifact: {rel}")

bundle_files = read_csv(run_dir / "complete_source_external_review_send_bundle_file_rows.csv")
nested_members = read_csv(run_dir / "complete_source_external_review_send_bundle_nested_member_rows.csv")
artifact_rows = read_csv(run_dir / "complete_source_external_review_send_bundle_artifact_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_external_review_send_bundle_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_external_review_send_bundle_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(bundle_files) != 10:
    raise SystemExit("v53ah expected ten bundle files")
if sum(int(row["archive_file"]) for row in bundle_files) != 2:
    raise SystemExit("v53ah expected two tar.gz archive files")
if sum(int(row["payload_like_file"]) for row in bundle_files) != 0:
    raise SystemExit("v53ah bundle must not include top-level payload-like files")
if len(artifact_rows) != 10 or any(row["artifact_ready"] != "1" for row in artifact_rows):
    raise SystemExit("v53ah artifact rows mismatch")
if sum(int(row["payload_like_member"]) for row in nested_members) != 0:
    raise SystemExit("v53ah nested archives must not include payload-like members")
if sum(int(row["return_inbox_final_evidence_named_member"]) for row in nested_members) != 0:
    raise SystemExit("v53ah return inbox archive must not include final evidence-named members")
if sum(1 for row in nested_members if row["lane"] == "review_dispatch") != 78:
    raise SystemExit("v53ah dispatch archive member count mismatch")
if sum(1 for row in nested_members if row["lane"] == "return_inbox") != 84:
    raise SystemExit("v53ah return inbox archive member count mismatch")
if sum(1 for row in nested_members if row["lane"] == "return_inbox" and row["template_member"] == "1") != 82:
    raise SystemExit("v53ah return inbox template member count mismatch")

for path in [dispatch_archive, return_inbox_archive]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing nested archive: {path}")
    with tarfile.open(path, "r:gz") as tar:
        members = sorted(member.name for member in tar.getmembers() if member.isfile())
    if any(member.endswith((".safetensors", ".bin", ".pt")) for member in members):
        raise SystemExit(f"payload-like member found in {path.name}")

with tarfile.open(return_inbox_archive, "r:gz") as tar:
    return_members = sorted(member.name for member in tar.getmembers() if member.isfile())
if any((member.endswith(".csv") or member.endswith(".json") or member.endswith(".jsonl")) and not member.endswith(".template") for member in return_members):
    raise SystemExit("return inbox archive includes final evidence-named csv/json/jsonl")
for suffix in [
    "aggregate_review_return_templates/human_review_rows.csv.template",
    "aggregate_review_return_templates/adjudication_rows.csv.template",
    "generation_result_return_templates/real_model_generation_answer_rows.csv.template",
    "generation_result_return_templates/real_model_generation_latency_rows.csv.template",
]:
    if not any(member.endswith(suffix) for member in return_members):
        raise SystemExit(f"return inbox archive missing template suffix: {suffix}")

bundle_sha = (bundle_dir / "BUNDLE_SHA256SUMS.txt").read_text(encoding="utf-8")
for rel in [
    "review_dispatch/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz",
    "return_inbox/v53af_external_return_inbox_scaffold_001.tar.gz",
    "BUNDLE_FILE_LIST.txt",
]:
    if sha256(bundle_dir / rel).split(":", 1)[1] not in bundle_sha:
        raise SystemExit(f"bundle sha file missing hash for {rel}")

file_list = (bundle_dir / "BUNDLE_FILE_LIST.txt").read_text(encoding="utf-8")
for rel in [
    "review_dispatch/v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz",
    "return_inbox/v53af_external_return_inbox_scaffold_001.tar.gz",
    "SEND_BUNDLE_README.md",
    "VERIFY_SEND_BUNDLE.sh",
]:
    if rel not in file_list:
        raise SystemExit(f"bundle file list missing {rel}")

readme = (bundle_dir / "SEND_BUNDLE_README.md").read_text(encoding="utf-8")
for snippet in [
    "review_dispatch/",
    "return_inbox/",
    "templates only",
    "does not complete dispatch receipt acceptance",
]:
    if snippet not in readme:
        raise SystemExit(f"v53ah readme missing: {snippet}")

for field, value in expected.items():
    if field.startswith("v53ah_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ah metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53ac-dispatch-archive-input",
    "v53ag-return-inbox-archive-input",
    "send-bundle-shape",
    "send-bundle-sha256",
    "nested-archives-no-payload",
    "return-inbox-template-only",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ah requirement should pass: {requirement_id}")
for requirement_id in [
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ah requirement should stay blocked: {requirement_id}")

for gate in [
    "v53ac-dispatch-archive-input",
    "v53ag-return-inbox-archive-input",
    "external-send-bundle",
    "bundle-sha256",
    "no-payload",
    "return-inbox-template-only",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ah decision should pass: {gate}")
for gate in [
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ah decision should stay blocked: {gate}")

if gaps.get("external-send-bundle") != "ready":
    raise SystemExit("v53ah send bundle gap should be ready")
for gap in [
    "dispatch-receipts",
    "review-return-accepted",
    "generation-execution-admitted",
    "generation-result-accepted",
    "actual-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ah gap should stay blocked: {gap}")

boundary = (run_dir / "V53AH_COMPLETE_SOURCE_EXTERNAL_REVIEW_SEND_BUNDLE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "send_bundle_ready=1",
    "send_bundle_archive_files=2",
    "bundle_sha256_ready=1",
    "dispatch_archive_member_files=78",
    "return_inbox_archive_member_files=84",
    "return_artifact_template_archive_member_rows=81",
    "nested_payload_like_archive_member_rows=0",
    "return_inbox_final_evidence_named_archive_member_rows=0",
    "accepted_dispatch_receipt_rows=0",
    "answer_review_accepted_rows=0",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "checkpoint_payload_bytes_downloaded_by_v53ah=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ah boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ah_complete_source_external_review_send_bundle_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ah_complete_source_external_review_send_bundle_ready") != 1:
    raise SystemExit("v53ah manifest readiness mismatch")
if manifest.get("send_bundle_archive_files") != 2:
    raise SystemExit("v53ah manifest archive count mismatch")
if manifest.get("nested_payload_like_archive_member_rows") != 0:
    raise SystemExit("v53ah manifest payload-like count mismatch")
if manifest.get("return_inbox_final_evidence_named_archive_member_rows") != 0:
    raise SystemExit("v53ah manifest final evidence count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ah manifest must keep actual generation blocked")
if manifest.get("full_shard_prerequisites_closed") != 1:
    raise SystemExit("v53ah manifest should inherit full-shard closure")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ah sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ah produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ah complete-source external review send bundle smoke passed"
