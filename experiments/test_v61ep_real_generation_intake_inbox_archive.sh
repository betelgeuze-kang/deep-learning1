#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ep_real_generation_intake_inbox_archive"
RUN_DIR="$RESULTS_DIR/$PREFIX/archive_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61eo_real_generation_intake_evidence_inbox_scaffold.sh" >/dev/null

V61EP_REUSE_EXISTING="${V61EP_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ep_real_generation_intake_inbox_archive.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
import tarfile
from pathlib import Path

run_dir = Path(sys.argv[1])
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


summary = read_csv(summary_csv)[0]
expected = {
    "v61ep_real_generation_intake_inbox_archive_ready": "1",
    "v61eo_real_generation_intake_evidence_inbox_scaffold_ready": "1",
    "archive_ready": "1",
    "archive_sha256_ready": "1",
    "archive_file_list_ready": "1",
    "send_readme_ready": "1",
    "archive_member_files": "9",
    "template_archive_member_rows": "9",
    "expected_template_member_rows": "9",
    "required_members_present": "1",
    "all_members_template_only": "1",
    "payload_like_archive_member_rows": "0",
    "final_evidence_named_archive_member_rows": "0",
    "accepted_by_default_rows": "0",
    "real_generation_result_artifacts": "0",
    "real_prerequisite_binding_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ep": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ep {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "archive/v61eo_real_generation_intake_inbox_scaffold_001.tar.gz",
    "archive/ARCHIVE_FILE_LIST.txt",
    "archive/ARCHIVE_SHA256SUMS.txt",
    "SEND_REAL_GENERATION_INTAKE_INBOX_ARCHIVE.md",
    "real_generation_intake_inbox_archive_member_rows.csv",
    "real_generation_intake_inbox_archive_artifact_rows.csv",
    "real_generation_intake_inbox_archive_requirement_rows.csv",
    "runtime_gap_rows.csv",
    "v61ep_real_generation_intake_inbox_archive_manifest.json",
    "source_v61eo/v61eo_real_generation_intake_evidence_inbox_scaffold_summary.csv",
    "source_v61eo/real_generation_intake_inbox_template_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ep artifact: {rel}")

archive_path = run_dir / "archive/v61eo_real_generation_intake_inbox_scaffold_001.tar.gz"
with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())
if len(members) != 9:
    raise SystemExit(f"v61ep expected 9 archive members, got {len(members)}")
if any(not member.endswith(".template") for member in members):
    raise SystemExit("v61ep archive must contain template members only")
if any(member.endswith((".safetensors", ".bin", ".pt")) for member in members):
    raise SystemExit("v61ep archive contains payload-like member")
if any(member.endswith((".csv", ".json", ".jsonl")) and not member.endswith(".template") for member in members):
    raise SystemExit("v61ep archive contains final evidence-named member")

member_rows = read_csv(run_dir / "real_generation_intake_inbox_archive_member_rows.csv")
if len(member_rows) != 9:
    raise SystemExit("v61ep member rows mismatch")
if any(row["template_member"] != "1" for row in member_rows):
    raise SystemExit("v61ep member row should be template")
if any(row["final_evidence_named_member"] != "0" for row in member_rows):
    raise SystemExit("v61ep member row should not be final evidence")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "real_generation_intake_inbox_archive_requirement_rows.csv")}
for requirement in [
    "v61eo-inbox-input",
    "archive-file",
    "archive-sha256",
    "all-template-members-present",
    "all-members-template-only",
    "no-final-evidence-filenames",
    "no-checkpoint-payload",
]:
    if requirements[requirement] != "pass":
        raise SystemExit(f"v61ep requirement should pass: {requirement}")
for requirement in ["real-generation-intake", "actual-generation"]:
    if requirements[requirement] != "blocked":
        raise SystemExit(f"v61ep requirement should be blocked: {requirement}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61eo-template-inbox-input",
    "archive-ready",
    "template-only-members",
    "no-final-evidence-filenames",
    "no-checkpoint-payload",
    "repo-checkpoint-payload",
]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61ep decision should pass: {gate}")
for gate in ["real-generation-intake", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ep decision should be blocked: {gate}")

manifest = json.loads((run_dir / "v61ep_real_generation_intake_inbox_archive_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ep_real_generation_intake_inbox_archive_ready") != 1:
    raise SystemExit("v61ep manifest readiness mismatch")
if manifest.get("final_evidence_named_archive_member_rows") != 0:
    raise SystemExit("v61ep manifest must keep final evidence rows at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ep manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ep sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ep produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ep real generation intake inbox archive smoke passed"
