#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ag_external_return_inbox_archive"
RUN_DIR="$RESULTS_DIR/$PREFIX/archive_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ARCHIVE_PATH="$RUN_DIR/archive/v53af_external_return_inbox_scaffold_001.tar.gz"

V53AG_REUSE_EXISTING="${V53AG_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53ag_external_return_inbox_archive.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ARCHIVE_PATH" <<'PY'
import csv
import hashlib
import json
import sys
import tarfile
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
archive_path = Path(sys.argv[4])


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
    "v53ag_external_return_inbox_archive_ready": "1",
    "v53af_external_return_inbox_scaffold_ready": "1",
    "archive_ready": "1",
    "archive_sha256_ready": "1",
    "archive_file_list_ready": "1",
    "send_readme_ready": "1",
    "template_archive_member_rows": "82",
    "return_artifact_template_archive_member_rows": "81",
    "required_return_artifact_rows": "81",
    "required_archive_member_rows": "13",
    "required_members_present": "1",
    "payload_like_archive_member_rows": "0",
    "final_evidence_named_archive_member_rows": "0",
    "return_inbox_file_rows": "84",
    "dispatch_receipt_template_files": "21",
    "review_chunk_return_template_files": "50",
    "aggregate_review_return_template_files": "5",
    "generation_result_template_files": "5",
    "template_files_accepted_by_default": "0",
    "answer_review_accepted_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ag": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53ag {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("archive_member_files", "0")) < 84:
    raise SystemExit("v53ag archive should include all scaffold files")

required_files = [
    "archive/v53af_external_return_inbox_scaffold_001.tar.gz",
    "archive/ARCHIVE_FILE_LIST.txt",
    "archive/ARCHIVE_SHA256SUMS.txt",
    "SEND_RETURN_INBOX_ARCHIVE.md",
    "external_return_inbox_archive_member_rows.csv",
    "external_return_inbox_archive_artifact_rows.csv",
    "external_return_inbox_archive_requirement_rows.csv",
    "external_return_inbox_archive_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AG_EXTERNAL_RETURN_INBOX_ARCHIVE_BOUNDARY.md",
    "v53ag_external_return_inbox_archive_manifest.json",
    "source_v53af/v53af_external_return_inbox_scaffold_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53ag artifact: {rel}")

artifact_rows = read_csv(run_dir / "external_return_inbox_archive_artifact_rows.csv")
member_rows = read_csv(run_dir / "external_return_inbox_archive_member_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "external_return_inbox_archive_requirement_rows.csv")}
metric = read_csv(run_dir / "external_return_inbox_archive_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(artifact_rows) != 4 or any(row["artifact_ready"] != "1" for row in artifact_rows):
    raise SystemExit("v53ag archive artifact rows mismatch")
if not member_rows:
    raise SystemExit("v53ag archive member rows missing")
if sum(int(row["template_member"]) for row in member_rows) != 82:
    raise SystemExit("v53ag template member count mismatch")
if sum(1 for row in member_rows if "_templates/" in row["archive_member"] and row["template_member"] == "1") != 81:
    raise SystemExit("v53ag return artifact template member count mismatch")
if sum(int(row["payload_like_member"]) for row in member_rows) != 0:
    raise SystemExit("v53ag archive must not contain payload-like members")
if sum(int(row["final_evidence_named_member"]) for row in member_rows) != 0:
    raise SystemExit("v53ag archive must not contain final evidence-named csv/json members")
if sum(int(row["required_member"]) for row in member_rows) < 13:
    raise SystemExit("v53ag archive required members missing")

with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())
for suffix in [
    "RETURN_INBOX_README.md",
    "VERIFY_RETURN_INBOX_SHAPE.sh",
    "RUN_V53AE_WITH_FINAL_RETURNS.sh.template",
    "aggregate_review_return_templates/human_review_rows.csv.template",
    "aggregate_review_return_templates/adjudication_rows.csv.template",
    "generation_result_return_templates/real_model_generation_answer_rows.csv.template",
    "generation_result_return_templates/real_model_generation_latency_rows.csv.template",
]:
    if not any(member.endswith(suffix) for member in members):
        raise SystemExit(f"v53ag archive missing member suffix: {suffix}")
if any(member.endswith((".safetensors", ".bin", ".pt")) for member in members):
    raise SystemExit("v53ag archive includes model/checkpoint payload-like member")
if any((member.endswith(".csv") or member.endswith(".json")) and not member.endswith(".template") for member in members):
    raise SystemExit("v53ag archive includes final evidence-named csv/json member")

sha_text = (run_dir / "archive" / "ARCHIVE_SHA256SUMS.txt").read_text(encoding="utf-8")
if sha256(archive_path) not in sha_text:
    raise SystemExit("v53ag checksum file should include archive sha")
file_list = (run_dir / "archive" / "ARCHIVE_FILE_LIST.txt").read_text(encoding="utf-8")
if "RETURN_INBOX_README.md" not in file_list or "real_model_generation_answer_rows.csv.template" not in file_list:
    raise SystemExit("v53ag archive file list missing expected members")

readme = (run_dir / "SEND_RETURN_INBOX_ARCHIVE.md").read_text(encoding="utf-8")
for snippet in [
    "templates only",
    "sha256sum -c ARCHIVE_SHA256SUMS.txt",
    "tar -tzf v53af_external_return_inbox_scaffold_001.tar.gz",
    "does not complete review return",
]:
    if snippet not in readme:
        raise SystemExit(f"v53ag send readme missing: {snippet}")

for field, value in expected.items():
    if field.startswith("v53ag_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53ag metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53af-return-inbox-input",
    "archive-file",
    "archive-sha256",
    "archive-required-members",
    "template-member-count",
    "manifest-only-no-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53ag requirement should pass: {requirement_id}")
for requirement_id in ["review-return-accepted", "generation-result-accepted", "actual-generation"]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53ag requirement should stay blocked: {requirement_id}")

for gate in ["v53af-return-inbox-input", "return-inbox-archive", "archive-sha256", "template-only", "no-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53ag decision should pass: {gate}")
for gate in ["review-return-accepted", "generation-result-accepted", "actual-model-generation", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53ag decision should stay blocked: {gate}")

if gaps.get("return-inbox-archive") != "ready":
    raise SystemExit("v53ag return-inbox-archive gap should be ready")
for gap in ["review-return-accepted", "generation-result-accepted", "actual-generation"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53ag gap should stay blocked: {gap}")

boundary = (run_dir / "V53AG_EXTERNAL_RETURN_INBOX_ARCHIVE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "archive_ready=1",
    "archive_sha256_ready=1",
    "archive_file_list_ready=1",
    "send_readme_ready=1",
    "template_archive_member_rows=82",
    "return_artifact_template_archive_member_rows=81",
    "required_return_artifact_rows=81",
    "required_members_present=1",
    "payload_like_archive_member_rows=0",
    "final_evidence_named_archive_member_rows=0",
    "template_files_accepted_by_default=0",
    "answer_review_accepted_rows=0",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "checkpoint_payload_bytes_downloaded_by_v53ag=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53ag boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53ag_external_return_inbox_archive_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53ag_external_return_inbox_archive_ready") != 1:
    raise SystemExit("v53ag manifest readiness mismatch")
if manifest.get("archive_sha256") != sha256(archive_path):
    raise SystemExit("v53ag manifest archive sha mismatch")
if manifest.get("template_archive_member_rows") != 82:
    raise SystemExit("v53ag manifest template count mismatch")
if manifest.get("return_artifact_template_archive_member_rows") != 81:
    raise SystemExit("v53ag manifest return artifact template count mismatch")
if manifest.get("payload_like_archive_member_rows") != 0:
    raise SystemExit("v53ag manifest payload-like count mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53ag manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53ag sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53ag produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53ag external return inbox archive smoke passed"
