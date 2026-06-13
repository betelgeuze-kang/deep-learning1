#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ac_complete_source_review_dispatch_archive"
RUN_ID="${V53AC_RUN_ID:-archive_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ac_complete_source_review_dispatch_archive_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ab_complete_source_review_dispatch_receipt_packet.sh" >/dev/null

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


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v53ab_summary_path = results / "v53ab_complete_source_review_dispatch_receipt_packet_summary.csv"
v53ab_decision_path = results / "v53ab_complete_source_review_dispatch_receipt_packet_decision.csv"
v53ab_dir = results / "v53ab_complete_source_review_dispatch_receipt_packet" / "dispatch_001"
v53ab = read_csv(v53ab_summary_path)[0]
if v53ab["v53ab_complete_source_review_dispatch_receipt_packet_ready"] != "1":
    raise SystemExit("v53ac requires v53ab dispatch receipt packet readiness")

for src, rel in [
    (v53ab_summary_path, "source_v53ab/v53ab_complete_source_review_dispatch_receipt_packet_summary.csv"),
    (v53ab_decision_path, "source_v53ab/v53ab_complete_source_review_dispatch_receipt_packet_decision.csv"),
    (v53ab_dir / "complete_source_review_dispatch_chunk_rows.csv", "source_v53ab/complete_source_review_dispatch_chunk_rows.csv"),
    (v53ab_dir / "complete_source_review_dispatch_receipt_template_rows.csv", "source_v53ab/complete_source_review_dispatch_receipt_template_rows.csv"),
    (v53ab_dir / "complete_source_review_return_handoff_artifact_rows.csv", "source_v53ab/complete_source_review_return_handoff_artifact_rows.csv"),
    (v53ab_dir / "complete_source_review_dispatch_command_rows.csv", "source_v53ab/complete_source_review_dispatch_command_rows.csv"),
]:
    copy(src, rel)

dispatch_src = v53ab_dir / "operator_dispatch"
if not dispatch_src.is_dir():
    raise SystemExit("v53ac requires v53ab operator_dispatch directory")

archive_name = "v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz"
archive_path = archive_dir / archive_name
archive_root = "v53ab_complete_source_review_dispatch_packet_dispatch_001"
with tarfile.open(archive_path, "w:gz") as tar:
    for path in sorted(dispatch_src.rglob("*")):
        arcname = Path(archive_root) / path.relative_to(dispatch_src)
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

send_readme = run_dir / "SEND_REVIEW_DISPATCH_ARCHIVE.md"
send_readme.write_text(
    "\n".join(
        [
            "# v53ac Complete-Source Review Dispatch Archive",
            "",
            "Send the archive under `archive/` to the external review coordinator.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "cd archive",
            "sha256sum -c ARCHIVE_SHA256SUMS.txt",
            "tar -tzf v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz",
            "```",
            "",
            "After extraction, use `operator_dispatch/review_work_packet/` as the reviewer packet.",
            "Return completed review artifacts through `V53Y_REVIEW_RETURN_DIR` and rerun v53y/v53z/v61df.",
            "",
            "This archive does not complete review return, v53 readiness, or actual generation by itself.",
            "",
        ]
    ),
    encoding="utf-8",
)

required_member_suffixes = [
    "README.md",
    "VERIFY_REVIEW_DISPATCH_PACKET.sh",
    "DISPATCH_CHUNK_ROWS.csv",
    "DISPATCH_RECEIPT_TEMPLATE_ROWS.csv",
    "REVIEW_RETURN_HANDOFF_ARTIFACT_ROWS.csv",
    "REVIEW_RETURN_REFRESH_COMMAND_ROWS.csv",
    "review_work_packet/CHUNK_PACKET_INDEX.csv",
    "review_work_packet/AGGREGATE_RETURN_REQUIRED_ARTIFACTS.csv",
    "review_work_packet/VERIFY_REVIEW_CHUNK_WORK_PACKET.sh",
]
required_members_present = int(all(any(member.endswith(suffix) for member in members) for suffix in required_member_suffixes))
payload_like_member_rows = sum(1 for member in members if member.endswith((".safetensors", ".bin", ".pt")))
archive_ready = int(archive_path.is_file() and archive_path.stat().st_size > 0)
archive_sha256_ready = int(sha_path.is_file() and sha256(archive_path) in sha_path.read_text(encoding="utf-8"))
archive_file_list_ready = int(file_list_path.is_file() and required_members_present)
send_readme_ready = int(send_readme.is_file() and send_readme.stat().st_size > 0)
v53ac_ready = int(
    archive_ready
    and archive_sha256_ready
    and archive_file_list_ready
    and send_readme_ready
    and required_members_present
    and payload_like_member_rows == 0
)

archive_member_rows = []
for member in members:
    archive_member_rows.append(
        {
            "archive_member": member,
            "required_member": str(int(any(member.endswith(suffix) for suffix in required_member_suffixes))),
            "payload_like_member": str(int(member.endswith((".safetensors", ".bin", ".pt")))),
        }
    )
write_csv(run_dir / "complete_source_review_dispatch_archive_member_rows.csv", ["archive_member", "required_member", "payload_like_member"], archive_member_rows)

artifact_rows = []
for artifact, purpose in [
    (archive_path, "dispatch tar.gz archive"),
    (file_list_path, "archive file list"),
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
write_csv(run_dir / "complete_source_review_dispatch_archive_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

requirement_rows = [
    {"requirement_id": "v53ab-dispatch-packet-input", "status": "pass", "required_value": "1", "actual_value": v53ab["v53ab_complete_source_review_dispatch_receipt_packet_ready"], "reason": "v53ab dispatch packet is ready"},
    {"requirement_id": "archive-file", "status": "pass" if archive_ready else "blocked", "required_value": "1", "actual_value": str(archive_ready), "reason": archive_name},
    {"requirement_id": "archive-sha256", "status": "pass" if archive_sha256_ready else "blocked", "required_value": "1", "actual_value": str(archive_sha256_ready), "reason": "archive checksum file binds archive"},
    {"requirement_id": "archive-required-members", "status": "pass" if required_members_present else "blocked", "required_value": str(len(required_member_suffixes)), "actual_value": str(sum(1 for suffix in required_member_suffixes if any(member.endswith(suffix) for member in members))), "reason": "required dispatch packet members present"},
    {"requirement_id": "manifest-only-no-payload", "status": "pass" if payload_like_member_rows == 0 else "blocked", "required_value": "0", "actual_value": str(payload_like_member_rows), "reason": "archive must contain no model/checkpoint payload-like files"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": v53ab["expected_human_review_rows"], "actual_value": v53ab["answer_review_accepted_rows"], "reason": "archive is ready to send, but no review return is accepted"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v53ab["actual_model_generation_ready"], "reason": "actual generation remains gated behind review/generation returns"},
]
write_csv(run_dir / "complete_source_review_dispatch_archive_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "dispatch-archive", "status": "ready" if v53ac_ready else "blocked", "reason": f"archive_ready={archive_ready}; required_members_present={required_members_present}"},
    {"gap": "dispatch-receipts", "status": "blocked", "reason": f"accepted_dispatch_receipt_rows={v53ab['accepted_dispatch_receipt_rows']}/21"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ab['answer_review_accepted_rows']}/{v53ab['expected_human_review_rows']}"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ab['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ac_complete_source_review_dispatch_archive_metrics",
    "v53ab_complete_source_review_dispatch_receipt_packet_ready": v53ab["v53ab_complete_source_review_dispatch_receipt_packet_ready"],
    "archive_ready": str(archive_ready),
    "archive_sha256_ready": str(archive_sha256_ready),
    "archive_file_list_ready": str(archive_file_list_ready),
    "send_readme_ready": str(send_readme_ready),
    "archive_member_files": str(len(members)),
    "required_archive_member_rows": str(len(required_member_suffixes)),
    "required_members_present": str(required_members_present),
    "payload_like_archive_member_rows": str(payload_like_member_rows),
    "dispatch_chunk_rows": v53ab["dispatch_chunk_rows"],
    "dispatch_task_rows": v53ab["dispatch_task_rows"],
    "dispatch_return_artifact_rows": v53ab["dispatch_return_artifact_rows"],
    "dispatch_receipt_template_rows": v53ab["dispatch_receipt_template_rows"],
    "accepted_dispatch_receipt_rows": v53ab["accepted_dispatch_receipt_rows"],
    "expected_human_review_rows": v53ab["expected_human_review_rows"],
    "answer_review_accepted_rows": v53ab["answer_review_accepted_rows"],
    "review_return_ready": v53ab["review_return_ready"],
    "v53_ready": v53ab["v53_ready"],
    "actual_model_generation_ready": v53ab["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_review_dispatch_archive_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ac_complete_source_review_dispatch_archive_ready": str(v53ac_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53ab-dispatch-packet-input", "status": "pass", "reason": "v53ab dispatch packet is ready"},
    {"gate": "dispatch-archive", "status": "pass" if v53ac_ready else "blocked", "reason": f"archive_member_files={len(members)}"},
    {"gate": "archive-sha256", "status": "pass" if archive_sha256_ready else "blocked", "reason": "ARCHIVE_SHA256SUMS.txt binds archive"},
    {"gate": "no-payload", "status": "pass" if payload_like_member_rows == 0 else "blocked", "reason": f"payload_like_archive_member_rows={payload_like_member_rows}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ab['answer_review_accepted_rows']}/{v53ab['expected_human_review_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ab['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "archive is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ac Complete-Source Review Dispatch Archive Boundary

This artifact archives the v53ab external review dispatch packet for transport.
It creates a tar.gz archive, checksum file, file list, and send instructions.
It does not create dispatch receipts, review judgments, accepted review rows,
v53 readiness, v61 actual generation, latency evidence, near-frontier quality,
or release readiness.

Evidence emitted:

- archive_ready={archive_ready}
- archive_sha256_ready={archive_sha256_ready}
- archive_file_list_ready={archive_file_list_ready}
- send_readme_ready={send_readme_ready}
- archive_member_files={len(members)}
- required_archive_member_rows={len(required_member_suffixes)}
- required_members_present={required_members_present}
- payload_like_archive_member_rows={payload_like_member_rows}
- dispatch_chunk_rows={v53ab['dispatch_chunk_rows']}
- dispatch_task_rows={v53ab['dispatch_task_rows']}
- dispatch_return_artifact_rows={v53ab['dispatch_return_artifact_rows']}
- dispatch_receipt_template_rows={v53ab['dispatch_receipt_template_rows']}
- accepted_dispatch_receipt_rows={v53ab['accepted_dispatch_receipt_rows']}
- expected_human_review_rows={v53ab['expected_human_review_rows']}
- answer_review_accepted_rows={v53ab['answer_review_accepted_rows']}
- review_return_ready={v53ab['review_return_ready']}
- v53_ready={v53ab['v53_ready']}
- actual_model_generation_ready={v53ab['actual_model_generation_ready']}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source review dispatch archive is ready to send.
Blocked wording: accepted review return, v53 readiness, v61 actual generation,
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AC_COMPLETE_SOURCE_REVIEW_DISPATCH_ARCHIVE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ac-complete-source-review-dispatch-archive",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ac_complete_source_review_dispatch_archive_ready": v53ac_ready,
    "archive_path": str(archive_path.relative_to(run_dir)),
    "archive_sha256": sha256(archive_path),
    "archive_member_files": len(members),
    "required_members_present": required_members_present,
    "payload_like_archive_member_rows": payload_like_member_rows,
    "answer_review_accepted_rows": int(v53ab["answer_review_accepted_rows"]),
    "actual_model_generation_ready": int(v53ab["actual_model_generation_ready"]),
    "source_v53ab_summary_sha256": sha256(v53ab_summary_path),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53ac_complete_source_review_dispatch_archive_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ac_complete_source_review_dispatch_archive_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
