#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ep_real_generation_intake_inbox_archive"
RUN_ID="${V61EP_RUN_ID:-archive_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ep_real_generation_intake_inbox_archive_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eo_real_generation_intake_evidence_inbox_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
import tarfile
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
archive_dir = run_dir / "archive"
archive_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v61eo_summary_path = results / "v61eo_real_generation_intake_evidence_inbox_scaffold_summary.csv"
v61eo_decision_path = results / "v61eo_real_generation_intake_evidence_inbox_scaffold_decision.csv"
v61eo_dir = results / "v61eo_real_generation_intake_evidence_inbox_scaffold" / "scaffold_001"
v61eo = read_csv(v61eo_summary_path)[0]
if v61eo["v61eo_real_generation_intake_evidence_inbox_scaffold_ready"] != "1":
    raise SystemExit("v61ep requires v61eo inbox scaffold readiness")

for src, rel in [
    (v61eo_summary_path, "source_v61eo/v61eo_real_generation_intake_evidence_inbox_scaffold_summary.csv"),
    (v61eo_decision_path, "source_v61eo/v61eo_real_generation_intake_evidence_inbox_scaffold_decision.csv"),
    (v61eo_dir / "real_generation_intake_inbox_template_rows.csv", "source_v61eo/real_generation_intake_inbox_template_rows.csv"),
    (v61eo_dir / "real_generation_intake_path_contract_rows.csv", "source_v61eo/real_generation_intake_path_contract_rows.csv"),
    (v61eo_dir / "real_generation_intake_inbox_command_rows.csv", "source_v61eo/real_generation_intake_inbox_command_rows.csv"),
    (v61eo_dir / "RETURN_ENV.template", "source_v61eo/RETURN_ENV.template"),
    (v61eo_dir / "VERIFY_REAL_GENERATION_INTAKE_INBOX.sh", "source_v61eo/VERIFY_REAL_GENERATION_INTAKE_INBOX.sh"),
    (v61eo_dir / "README.md", "source_v61eo/README.md"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61ep source artifact: {src}")
    copy(src, rel)

inbox_src = v61eo_dir / "real_generation_intake_inbox"
if not inbox_src.is_dir():
    raise SystemExit("v61ep requires v61eo real_generation_intake_inbox directory")

archive_name = "v61eo_real_generation_intake_inbox_scaffold_001.tar.gz"
archive_root = "v61eo_real_generation_intake_inbox_scaffold_001"
archive_path = archive_dir / archive_name
with tarfile.open(archive_path, "w:gz") as tar:
    for path in sorted(inbox_src.rglob("*")):
        if path.is_file():
            arcname = Path(archive_root) / path.relative_to(inbox_src)
            tar.add(path, arcname=str(arcname), recursive=False)

with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())

file_list_path = archive_dir / "ARCHIVE_FILE_LIST.txt"
file_list_path.write_text("\n".join(members) + "\n", encoding="utf-8")
sha_path = archive_dir / "ARCHIVE_SHA256SUMS.txt"
sha_path.write_text(
    f"{sha256(archive_path)}  {archive_name}\n"
    f"{sha256(file_list_path)}  ARCHIVE_FILE_LIST.txt\n",
    encoding="utf-8",
)

send_readme = run_dir / "SEND_REAL_GENERATION_INTAKE_INBOX_ARCHIVE.md"
send_readme.write_text(
    "\n".join(
        [
            "# v61ep Real Generation Intake Inbox Archive",
            "",
            "Send the archive under `archive/` only as a template-only intake shape.",
            "Every archive member is a `.template` file. It is not accepted evidence.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "cd archive",
            "sha256sum -c ARCHIVE_SHA256SUMS.txt",
            "tar -tzf v61eo_real_generation_intake_inbox_scaffold_001.tar.gz",
            "```",
            "",
            "After filling real non-template files outside this archive, run v61ej, v61el, v61em, v61en, then v61bt/v61de.",
            "This archive does not complete real generation intake, actual generation, latency, near-frontier, or release readiness.",
            "",
        ]
    ),
    encoding="utf-8",
)

template_rows = read_csv(v61eo_dir / "real_generation_intake_inbox_template_rows.csv")
expected_template_artifacts = {row["template_artifact"] for row in template_rows}
expected_suffixes = [str(Path(artifact).relative_to("real_generation_intake_inbox")) for artifact in expected_template_artifacts]
required_members_present = int(all(any(member.endswith(suffix) for member in members) for suffix in expected_suffixes))
template_member_rows = sum(1 for member in members if member.endswith(".template"))
payload_like_member_rows = sum(1 for member in members if member.endswith((".safetensors", ".bin", ".pt")))
final_evidence_named_member_rows = sum(
    1
    for member in members
    if (
        member.endswith(".csv")
        or member.endswith(".json")
        or member.endswith(".jsonl")
    )
    and not member.endswith(".template")
)
all_members_template = int(len(members) == template_member_rows)
archive_ready = int(archive_path.is_file() and archive_path.stat().st_size > 0)
archive_sha256_ready = int(sha_path.is_file() and sha256(archive_path) in sha_path.read_text(encoding="utf-8"))
archive_file_list_ready = int(file_list_path.is_file() and len(members) == int(v61eo["inbox_template_rows"]))
send_readme_ready = int(send_readme.is_file() and send_readme.stat().st_size > 0)
v61ep_ready = int(
    archive_ready
    and archive_sha256_ready
    and archive_file_list_ready
    and send_readme_ready
    and required_members_present
    and all_members_template
    and template_member_rows == int(v61eo["inbox_template_rows"])
    and payload_like_member_rows == 0
    and final_evidence_named_member_rows == 0
)

member_rows = []
for member in members:
    member_rows.append(
        {
            "archive_member": member,
            "required_member": str(int(any(member.endswith(suffix) for suffix in expected_suffixes))),
            "template_member": str(int(member.endswith(".template"))),
            "payload_like_member": str(int(member.endswith((".safetensors", ".bin", ".pt")))),
            "final_evidence_named_member": str(
                int(
                    (
                        member.endswith(".csv")
                        or member.endswith(".json")
                        or member.endswith(".jsonl")
                    )
                    and not member.endswith(".template")
                )
            ),
        }
    )
write_csv(run_dir / "real_generation_intake_inbox_archive_member_rows.csv", list(member_rows[0].keys()), member_rows)

artifact_rows = []
for artifact, purpose in [
    (archive_path, "template-only real generation intake inbox archive"),
    (file_list_path, "archive member list"),
    (sha_path, "archive checksums"),
    (send_readme, "send instructions"),
]:
    artifact_rows.append(
        {
            "artifact": artifact.name,
            "purpose": purpose,
            "path": str(artifact.relative_to(run_dir)),
            "sha256": sha256(artifact),
            "bytes": str(artifact.stat().st_size),
            "artifact_ready": "1",
        }
    )
write_csv(run_dir / "real_generation_intake_inbox_archive_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

requirement_rows = [
    {"requirement_id": "v61eo-inbox-input", "status": "pass", "required_value": "1", "actual_value": v61eo["v61eo_real_generation_intake_evidence_inbox_scaffold_ready"], "reason": "v61eo scaffold is ready"},
    {"requirement_id": "archive-file", "status": "pass" if archive_ready else "blocked", "required_value": "1", "actual_value": str(archive_ready), "reason": archive_name},
    {"requirement_id": "archive-sha256", "status": "pass" if archive_sha256_ready else "blocked", "required_value": "1", "actual_value": str(archive_sha256_ready), "reason": "archive checksum binds archive"},
    {"requirement_id": "all-template-members-present", "status": "pass" if required_members_present else "blocked", "required_value": v61eo["inbox_template_rows"], "actual_value": str(sum(1 for suffix in expected_suffixes if any(member.endswith(suffix) for member in members))), "reason": "all v61eo templates are archived"},
    {"requirement_id": "all-members-template-only", "status": "pass" if all_members_template else "blocked", "required_value": "1", "actual_value": str(all_members_template), "reason": "archive members must all end with .template"},
    {"requirement_id": "no-final-evidence-filenames", "status": "pass" if final_evidence_named_member_rows == 0 else "blocked", "required_value": "0", "actual_value": str(final_evidence_named_member_rows), "reason": "archive must not contain final evidence filenames"},
    {"requirement_id": "no-checkpoint-payload", "status": "pass" if payload_like_member_rows == 0 else "blocked", "required_value": "0", "actual_value": str(payload_like_member_rows), "reason": "archive must contain no model/checkpoint payload-like files"},
    {"requirement_id": "real-generation-intake", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "archive contains templates only"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "real_generation_intake_inbox_archive_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "template-inbox-archive", "status": "ready" if v61ep_ready else "blocked", "reason": f"archive_ready={archive_ready}; template_members={template_member_rows}"},
    {"gap": "real-generation-intake", "status": "blocked", "reason": "archive is template-only"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

summary = {
    "v61ep_real_generation_intake_inbox_archive_ready": str(v61ep_ready),
    "v61eo_real_generation_intake_evidence_inbox_scaffold_ready": v61eo["v61eo_real_generation_intake_evidence_inbox_scaffold_ready"],
    "archive_ready": str(archive_ready),
    "archive_sha256_ready": str(archive_sha256_ready),
    "archive_file_list_ready": str(archive_file_list_ready),
    "send_readme_ready": str(send_readme_ready),
    "archive_member_files": str(len(members)),
    "template_archive_member_rows": str(template_member_rows),
    "expected_template_member_rows": v61eo["inbox_template_rows"],
    "required_members_present": str(required_members_present),
    "all_members_template_only": str(all_members_template),
    "payload_like_archive_member_rows": str(payload_like_member_rows),
    "final_evidence_named_archive_member_rows": str(final_evidence_named_member_rows),
    "accepted_by_default_rows": "0",
    "real_generation_result_artifacts": "0",
    "real_prerequisite_binding_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ep": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61eo-template-inbox-input", "status": "pass", "reason": "v61eo scaffold is ready"},
    {"gate": "archive-ready", "status": "pass" if archive_ready else "blocked", "reason": f"archive_ready={archive_ready}"},
    {"gate": "template-only-members", "status": "pass" if all_members_template else "blocked", "reason": f"template_member_rows={template_member_rows}/{len(members)}"},
    {"gate": "no-final-evidence-filenames", "status": "pass" if final_evidence_named_member_rows == 0 else "blocked", "reason": f"final_evidence_named_archive_member_rows={final_evidence_named_member_rows}"},
    {"gate": "no-checkpoint-payload", "status": "pass" if payload_like_member_rows == 0 else "blocked", "reason": f"payload_like_archive_member_rows={payload_like_member_rows}"},
    {"gate": "real-generation-intake", "status": "blocked", "reason": "archive contains templates only"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata/template archive only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

manifest = {
    "manifest_scope": "v61ep-real-generation-intake-inbox-archive",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61ep_real_generation_intake_inbox_archive_ready": v61ep_ready,
    "archive_member_files": len(members),
    "template_archive_member_rows": template_member_rows,
    "final_evidence_named_archive_member_rows": final_evidence_named_member_rows,
    "real_generation_intake_handoff_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ep_real_generation_intake_inbox_archive_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ep_real_generation_intake_inbox_archive_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
