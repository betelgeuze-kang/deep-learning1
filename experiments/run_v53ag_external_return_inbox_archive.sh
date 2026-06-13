#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ag_external_return_inbox_archive"
RUN_ID="${V53AG_RUN_ID:-archive_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ag_external_return_inbox_archive_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53af_external_return_inbox_scaffold.sh" >/dev/null

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


v53af_summary_path = results / "v53af_external_return_inbox_scaffold_summary.csv"
v53af_decision_path = results / "v53af_external_return_inbox_scaffold_decision.csv"
v53af_dir = results / "v53af_external_return_inbox_scaffold" / "scaffold_001"
v53af = read_csv(v53af_summary_path)[0]
if v53af["v53af_external_return_inbox_scaffold_ready"] != "1":
    raise SystemExit("v53ag requires v53af return inbox scaffold readiness")

for src, rel in [
    (v53af_summary_path, "source_v53af/v53af_external_return_inbox_scaffold_summary.csv"),
    (v53af_decision_path, "source_v53af/v53af_external_return_inbox_scaffold_decision.csv"),
    (v53af_dir / "external_return_required_artifact_index_rows.csv", "source_v53af/external_return_required_artifact_index_rows.csv"),
    (v53af_dir / "external_return_inbox_file_rows.csv", "source_v53af/external_return_inbox_file_rows.csv"),
    (v53af_dir / "external_return_inbox_metric_rows.csv", "source_v53af/external_return_inbox_metric_rows.csv"),
    (v53af_dir / "runtime_gap_rows.csv", "source_v53af/runtime_gap_rows.csv"),
]:
    copy(src, rel)

inbox_src = v53af_dir / "return_inbox"
if not inbox_src.is_dir():
    raise SystemExit("v53ag requires v53af return_inbox directory")

archive_name = "v53af_external_return_inbox_scaffold_001.tar.gz"
archive_path = archive_dir / archive_name
archive_root = "v53af_external_return_inbox_scaffold_001"
with tarfile.open(archive_path, "w:gz") as tar:
    for path in sorted(inbox_src.rglob("*")):
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

send_readme = run_dir / "SEND_RETURN_INBOX_ARCHIVE.md"
send_readme.write_text(
    "\n".join(
        [
            "# v53ag External Return Inbox Archive",
            "",
            "Send the archive under `archive/` to the external review/generation operator.",
            "It contains templates only. Files ending in `.template` are not accepted evidence.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "cd archive",
            "sha256sum -c ARCHIVE_SHA256SUMS.txt",
            "tar -tzf v53af_external_return_inbox_scaffold_001.tar.gz",
            "```",
            "",
            "After extraction, copy real returned files into final return directories and run v53ae with the final directories.",
            "This archive does not complete review return, generation result acceptance, actual generation, latency, near-frontier, or release readiness.",
            "",
        ]
    ),
    encoding="utf-8",
)

required_member_suffixes = [
    "RETURN_INBOX_README.md",
    "VERIFY_RETURN_INBOX_SHAPE.sh",
    "RUN_V53AE_WITH_FINAL_RETURNS.sh.template",
    "aggregate_review_return_templates/human_review_rows.csv.template",
    "aggregate_review_return_templates/adjudication_rows.csv.template",
    "aggregate_review_return_templates/reviewer_identity_rows.csv.template",
    "aggregate_review_return_templates/reviewer_conflict_rows.csv.template",
    "aggregate_review_return_templates/acceptance_summary.json.template",
    "generation_result_return_templates/real_model_generation_answer_rows.csv.template",
    "generation_result_return_templates/real_model_generation_citation_rows.csv.template",
    "generation_result_return_templates/real_model_generation_abstain_fallback_rows.csv.template",
    "generation_result_return_templates/real_model_generation_latency_rows.csv.template",
    "generation_result_return_templates/real_model_generation_acceptance_summary.json.template",
]
required_members_present = int(all(any(member.endswith(suffix) for member in members) for suffix in required_member_suffixes))
payload_like_member_rows = sum(1 for member in members if member.endswith((".safetensors", ".bin", ".pt")))
template_member_rows = sum(1 for member in members if member.endswith(".template"))
return_artifact_template_member_rows = sum(1 for member in members if "_templates/" in member and member.endswith(".template"))
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

archive_ready = int(archive_path.is_file() and archive_path.stat().st_size > 0)
archive_sha256_ready = int(sha_path.is_file() and sha256(archive_path) in sha_path.read_text(encoding="utf-8"))
archive_file_list_ready = int(file_list_path.is_file() and required_members_present)
send_readme_ready = int(send_readme.is_file() and send_readme.stat().st_size > 0)
v53ag_ready = int(
    archive_ready
    and archive_sha256_ready
    and archive_file_list_ready
    and send_readme_ready
    and required_members_present
    and payload_like_member_rows == 0
    and return_artifact_template_member_rows == int(v53af["required_return_artifact_rows"])
)

member_rows = []
for member in members:
    member_rows.append(
        {
            "archive_member": member,
            "required_member": str(int(any(member.endswith(suffix) for suffix in required_member_suffixes))),
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
write_csv(run_dir / "external_return_inbox_archive_member_rows.csv", list(member_rows[0].keys()), member_rows)

artifact_rows = []
for artifact, purpose in [
    (archive_path, "return inbox tar.gz archive"),
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
write_csv(run_dir / "external_return_inbox_archive_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

requirement_rows = [
    {"requirement_id": "v53af-return-inbox-input", "status": "pass", "required_value": "1", "actual_value": v53af["v53af_external_return_inbox_scaffold_ready"], "reason": "v53af scaffold is ready"},
    {"requirement_id": "archive-file", "status": "pass" if archive_ready else "blocked", "required_value": "1", "actual_value": str(archive_ready), "reason": archive_name},
    {"requirement_id": "archive-sha256", "status": "pass" if archive_sha256_ready else "blocked", "required_value": "1", "actual_value": str(archive_sha256_ready), "reason": "archive checksum file binds archive"},
    {"requirement_id": "archive-required-members", "status": "pass" if required_members_present else "blocked", "required_value": str(len(required_member_suffixes)), "actual_value": str(sum(1 for suffix in required_member_suffixes if any(member.endswith(suffix) for member in members))), "reason": "required scaffold members present"},
    {"requirement_id": "template-member-count", "status": "pass" if return_artifact_template_member_rows == int(v53af["required_return_artifact_rows"]) else "blocked", "required_value": v53af["required_return_artifact_rows"], "actual_value": str(return_artifact_template_member_rows), "reason": "all return artifacts are represented as templates only"},
    {"requirement_id": "manifest-only-no-payload", "status": "pass" if payload_like_member_rows == 0 else "blocked", "required_value": "0", "actual_value": str(payload_like_member_rows), "reason": "archive must contain no model/checkpoint payload-like files"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": "7000", "actual_value": v53af["answer_review_accepted_rows"], "reason": "archive is templates only"},
    {"requirement_id": "generation-result-accepted", "status": "blocked", "required_value": "5", "actual_value": v53af["accepted_generation_result_artifacts"], "reason": "archive is templates only"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v53af["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "external_return_inbox_archive_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "return-inbox-archive", "status": "ready" if v53ag_ready else "blocked", "reason": f"archive_ready={archive_ready}; template_member_rows={template_member_rows}"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53af['answer_review_accepted_rows']}/7000"},
    {"gap": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53af['accepted_generation_result_artifacts']}/5"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53af['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ag_external_return_inbox_archive_metrics",
    "v53af_external_return_inbox_scaffold_ready": v53af["v53af_external_return_inbox_scaffold_ready"],
    "archive_ready": str(archive_ready),
    "archive_sha256_ready": str(archive_sha256_ready),
    "archive_file_list_ready": str(archive_file_list_ready),
    "send_readme_ready": str(send_readme_ready),
    "archive_member_files": str(len(members)),
    "template_archive_member_rows": str(template_member_rows),
    "return_artifact_template_archive_member_rows": str(return_artifact_template_member_rows),
    "required_return_artifact_rows": v53af["required_return_artifact_rows"],
    "required_archive_member_rows": str(len(required_member_suffixes)),
    "required_members_present": str(required_members_present),
    "payload_like_archive_member_rows": str(payload_like_member_rows),
    "final_evidence_named_archive_member_rows": str(final_evidence_named_member_rows),
    "return_inbox_file_rows": v53af["return_inbox_file_rows"],
    "dispatch_receipt_template_files": v53af["dispatch_receipt_template_files"],
    "review_chunk_return_template_files": v53af["review_chunk_return_template_files"],
    "aggregate_review_return_template_files": v53af["aggregate_review_return_template_files"],
    "generation_result_template_files": v53af["generation_result_template_files"],
    "template_files_accepted_by_default": v53af["template_files_accepted_by_default"],
    "answer_review_accepted_rows": v53af["answer_review_accepted_rows"],
    "generation_execution_admitted_rows": v53af["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53af["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v53af["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53af["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53af["runtime_admission_accepted_rows"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ag": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "external_return_inbox_archive_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ag_external_return_inbox_archive_ready": str(v53ag_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53af-return-inbox-input", "status": "pass", "reason": "v53af scaffold is ready"},
    {"gate": "return-inbox-archive", "status": "pass" if v53ag_ready else "blocked", "reason": f"archive_member_files={len(members)}"},
    {"gate": "archive-sha256", "status": "pass" if archive_sha256_ready else "blocked", "reason": "ARCHIVE_SHA256SUMS.txt binds archive"},
    {"gate": "template-only", "status": "pass" if return_artifact_template_member_rows == int(v53af["required_return_artifact_rows"]) else "blocked", "reason": f"return_artifact_template_member_rows={return_artifact_template_member_rows}/{v53af['required_return_artifact_rows']}"},
    {"gate": "no-payload", "status": "pass" if payload_like_member_rows == 0 else "blocked", "reason": f"payload_like_archive_member_rows={payload_like_member_rows}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53af['answer_review_accepted_rows']}/7000"},
    {"gate": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53af['accepted_generation_result_artifacts']}/5"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53af['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "return inbox archive is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ag External Return Inbox Archive Boundary

This artifact packages the v53af zero-evidence return inbox scaffold as a
transportable archive. It contains templates only. It does not create accepted
review returns, generation result evidence, actual generation, latency evidence,
near-frontier quality evidence, or release readiness.

Evidence emitted:

- archive_ready={archive_ready}
- archive_sha256_ready={archive_sha256_ready}
- archive_file_list_ready={archive_file_list_ready}
- send_readme_ready={send_readme_ready}
- archive_member_files={len(members)}
- template_archive_member_rows={template_member_rows}
- return_artifact_template_archive_member_rows={return_artifact_template_member_rows}
- required_return_artifact_rows={v53af['required_return_artifact_rows']}
- required_members_present={required_members_present}
- payload_like_archive_member_rows={payload_like_member_rows}
- final_evidence_named_archive_member_rows={final_evidence_named_member_rows}
- template_files_accepted_by_default={v53af['template_files_accepted_by_default']}
- answer_review_accepted_rows={v53af['answer_review_accepted_rows']}
- generation_execution_admitted_rows={v53af['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v53af['accepted_generation_result_artifacts']}
- actual_model_generation_ready={v53af['actual_model_generation_ready']}
- full_shard_prerequisites_closed={v53af['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53af['runtime_admission_accepted_rows']}
- checkpoint_payload_bytes_downloaded_by_v53ag=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: the external return inbox archive is ready to send.
Blocked wording: accepted review return, generation result acceptance, actual
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AG_EXTERNAL_RETURN_INBOX_ARCHIVE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ag-external-return-inbox-archive",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ag_external_return_inbox_archive_ready": v53ag_ready,
    "archive_name": archive_name,
    "archive_sha256": sha256(archive_path),
    "archive_member_files": len(members),
    "template_archive_member_rows": template_member_rows,
    "return_artifact_template_archive_member_rows": return_artifact_template_member_rows,
    "required_return_artifact_rows": int(v53af["required_return_artifact_rows"]),
    "payload_like_archive_member_rows": payload_like_member_rows,
    "final_evidence_named_archive_member_rows": final_evidence_named_member_rows,
    "answer_review_accepted_rows": int(v53af["answer_review_accepted_rows"]),
    "accepted_generation_result_artifacts": int(v53af["accepted_generation_result_artifacts"]),
    "actual_model_generation_ready": int(v53af["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53af["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53af["runtime_admission_accepted_rows"]),
    "source_v53af_summary_sha256": sha256(v53af_summary_path),
    "checkpoint_payload_bytes_downloaded_by_v53ag": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v53ag_external_return_inbox_archive_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ag_external_return_inbox_archive_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
