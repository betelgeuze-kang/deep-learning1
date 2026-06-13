#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ah_complete_source_external_review_send_bundle"
RUN_ID="${V53AH_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ah_complete_source_external_review_send_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AC_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ac_complete_source_review_dispatch_archive.sh" >/dev/null
V53AG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ag_external_return_inbox_archive.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
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
send_bundle_dir = run_dir / "send_bundle"
send_bundle_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    return sha256(path).split(":", 1)[1]


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


def copy_to_run(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def copy_to_bundle(src, rel):
    dst = send_bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def tar_file_members(path):
    with tarfile.open(path, "r:gz") as tar:
        return sorted(member.name for member in tar.getmembers() if member.isfile())


v53ac_summary_path = results / "v53ac_complete_source_review_dispatch_archive_summary.csv"
v53ac_decision_path = results / "v53ac_complete_source_review_dispatch_archive_decision.csv"
v53ac_dir = results / "v53ac_complete_source_review_dispatch_archive" / "archive_001"
v53ag_summary_path = results / "v53ag_external_return_inbox_archive_summary.csv"
v53ag_decision_path = results / "v53ag_external_return_inbox_archive_decision.csv"
v53ag_dir = results / "v53ag_external_return_inbox_archive" / "archive_001"

v53ac = read_csv(v53ac_summary_path)[0]
v53ag = read_csv(v53ag_summary_path)[0]
if v53ac["v53ac_complete_source_review_dispatch_archive_ready"] != "1":
    raise SystemExit("v53ah requires v53ac dispatch archive readiness")
if v53ag["v53ag_external_return_inbox_archive_ready"] != "1":
    raise SystemExit("v53ah requires v53ag return inbox archive readiness")

for src, rel in [
    (v53ac_summary_path, "source_v53ac/v53ac_complete_source_review_dispatch_archive_summary.csv"),
    (v53ac_decision_path, "source_v53ac/v53ac_complete_source_review_dispatch_archive_decision.csv"),
    (v53ac_dir / "complete_source_review_dispatch_archive_artifact_rows.csv", "source_v53ac/complete_source_review_dispatch_archive_artifact_rows.csv"),
    (v53ac_dir / "complete_source_review_dispatch_archive_member_rows.csv", "source_v53ac/complete_source_review_dispatch_archive_member_rows.csv"),
    (v53ac_dir / "complete_source_review_dispatch_archive_requirement_rows.csv", "source_v53ac/complete_source_review_dispatch_archive_requirement_rows.csv"),
    (v53ag_summary_path, "source_v53ag/v53ag_external_return_inbox_archive_summary.csv"),
    (v53ag_decision_path, "source_v53ag/v53ag_external_return_inbox_archive_decision.csv"),
    (v53ag_dir / "external_return_inbox_archive_artifact_rows.csv", "source_v53ag/external_return_inbox_archive_artifact_rows.csv"),
    (v53ag_dir / "external_return_inbox_archive_member_rows.csv", "source_v53ag/external_return_inbox_archive_member_rows.csv"),
    (v53ag_dir / "external_return_inbox_archive_requirement_rows.csv", "source_v53ag/external_return_inbox_archive_requirement_rows.csv"),
]:
    copy_to_run(src, rel)

dispatch_archive_name = "v53ab_complete_source_review_dispatch_packet_dispatch_001.tar.gz"
return_inbox_archive_name = "v53af_external_return_inbox_scaffold_001.tar.gz"
dispatch_archive_src = v53ac_dir / "archive" / dispatch_archive_name
return_inbox_archive_src = v53ag_dir / "archive" / return_inbox_archive_name

bundle_files = [
    copy_to_bundle(dispatch_archive_src, f"review_dispatch/{dispatch_archive_name}"),
    copy_to_bundle(v53ac_dir / "archive" / "ARCHIVE_FILE_LIST.txt", "review_dispatch/ARCHIVE_FILE_LIST.txt"),
    copy_to_bundle(v53ac_dir / "archive" / "ARCHIVE_SHA256SUMS.txt", "review_dispatch/ARCHIVE_SHA256SUMS.txt"),
    copy_to_bundle(return_inbox_archive_src, f"return_inbox/{return_inbox_archive_name}"),
    copy_to_bundle(v53ag_dir / "archive" / "ARCHIVE_FILE_LIST.txt", "return_inbox/ARCHIVE_FILE_LIST.txt"),
    copy_to_bundle(v53ag_dir / "archive" / "ARCHIVE_SHA256SUMS.txt", "return_inbox/ARCHIVE_SHA256SUMS.txt"),
]

send_readme = send_bundle_dir / "SEND_BUNDLE_README.md"
send_readme.write_text(
    "\n".join(
        [
            "# v53ah Complete-Source External Review Send Bundle",
            "",
            "This bundle ships two archive lanes together:",
            "",
            "- `review_dispatch/`: the complete-source review work packet archive.",
            "- `return_inbox/`: the template-only return inbox archive for dispatch receipts, review returns, and generation result returns.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "./VERIFY_SEND_BUNDLE.sh",
            "```",
            "",
            "The return inbox contains templates only. Files ending in `.template` are not accepted evidence.",
            "A valid bundle only makes external review/generation return logistics ready.",
            "It does not complete dispatch receipt acceptance, human review, adjudication, generation execution, actual model generation, production latency, near-frontier quality, or release readiness.",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = send_bundle_dir / "VERIFY_SEND_BUNDLE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import hashlib",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'BUNDLE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    if expected.startswith('sha256:'):",
            "        expected = expected.split(':', 1)[1]",
            "    rel = rel.strip()",
            "    h = hashlib.sha256()",
            "    with (root / rel).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    actual = h.hexdigest()",
            "    if actual != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel}: {actual} != {expected}')",
            "PY_VERIFY",
            f"tar -tzf review_dispatch/{dispatch_archive_name} >/dev/null",
            f"tar -tzf return_inbox/{return_inbox_archive_name} >/dev/null",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

file_list_path = send_bundle_dir / "BUNDLE_FILE_LIST.txt"
listed_files = sorted(
    str(path.relative_to(send_bundle_dir))
    for path in send_bundle_dir.rglob("*")
    if path.is_file() and path.name not in {"BUNDLE_FILE_LIST.txt", "BUNDLE_SHA256SUMS.txt"}
)
file_list_path.write_text("\n".join(listed_files) + "\n", encoding="utf-8")

sha_path = send_bundle_dir / "BUNDLE_SHA256SUMS.txt"
sha_targets = sorted(
    path
    for path in send_bundle_dir.rglob("*")
    if path.is_file() and path.name != "BUNDLE_SHA256SUMS.txt"
)
sha_path.write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(send_bundle_dir)}\n" for path in sha_targets),
    encoding="utf-8",
)

dispatch_members = tar_file_members(send_bundle_dir / "review_dispatch" / dispatch_archive_name)
return_members = tar_file_members(send_bundle_dir / "return_inbox" / return_inbox_archive_name)
bundle_file_rows = []
for path in sorted(send_bundle_dir.rglob("*")):
    if path.is_file():
        rel = str(path.relative_to(send_bundle_dir))
        bundle_file_rows.append(
            {
                "bundle_file": rel,
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "archive_file": str(int(path.suffixes[-2:] == [".tar", ".gz"] or path.name.endswith(".tar.gz"))),
                "payload_like_file": str(int(path.name.endswith((".safetensors", ".bin", ".pt")))),
            }
        )
write_csv(run_dir / "complete_source_external_review_send_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

nested_member_rows = []
for lane, members in [("review_dispatch", dispatch_members), ("return_inbox", return_members)]:
    for member in members:
        nested_member_rows.append(
            {
                "lane": lane,
                "archive_member": member,
                "template_member": str(int(member.endswith(".template"))),
                "payload_like_member": str(int(member.endswith((".safetensors", ".bin", ".pt")))),
                "return_inbox_final_evidence_named_member": str(
                    int(
                        lane == "return_inbox"
                        and (member.endswith(".csv") or member.endswith(".json") or member.endswith(".jsonl"))
                        and not member.endswith(".template")
                    )
                ),
            }
        )
write_csv(run_dir / "complete_source_external_review_send_bundle_nested_member_rows.csv", list(nested_member_rows[0].keys()), nested_member_rows)

required_bundle_files = [
    f"review_dispatch/{dispatch_archive_name}",
    "review_dispatch/ARCHIVE_FILE_LIST.txt",
    "review_dispatch/ARCHIVE_SHA256SUMS.txt",
    f"return_inbox/{return_inbox_archive_name}",
    "return_inbox/ARCHIVE_FILE_LIST.txt",
    "return_inbox/ARCHIVE_SHA256SUMS.txt",
    "SEND_BUNDLE_README.md",
    "VERIFY_SEND_BUNDLE.sh",
    "BUNDLE_FILE_LIST.txt",
    "BUNDLE_SHA256SUMS.txt",
]
required_bundle_files_present = int(all((send_bundle_dir / rel).is_file() for rel in required_bundle_files))
send_bundle_archive_files = sum(1 for row in bundle_file_rows if row["archive_file"] == "1")
payload_like_bundle_file_rows = sum(int(row["payload_like_file"]) for row in bundle_file_rows)
nested_payload_like_archive_member_rows = sum(int(row["payload_like_member"]) for row in nested_member_rows)
return_inbox_final_evidence_named_archive_member_rows = sum(
    int(row["return_inbox_final_evidence_named_member"]) for row in nested_member_rows
)
dispatch_archive_ready = int((send_bundle_dir / "review_dispatch" / dispatch_archive_name).is_file())
return_inbox_archive_ready = int((send_bundle_dir / "return_inbox" / return_inbox_archive_name).is_file())
bundle_file_list_ready = int(file_list_path.is_file() and all(rel in file_list_path.read_text(encoding="utf-8") for rel in listed_files))
bundle_sha256_ready = int(sha_path.is_file() and sha256_hex(send_bundle_dir / "review_dispatch" / dispatch_archive_name) in sha_path.read_text(encoding="utf-8"))
send_readme_ready = int(send_readme.is_file() and send_readme.stat().st_size > 0)
verify_script_ready = int(verify_script.is_file() and os.access(verify_script, os.X_OK))
send_bundle_ready = int(
    required_bundle_files_present
    and send_bundle_archive_files == 2
    and dispatch_archive_ready
    and return_inbox_archive_ready
    and bundle_file_list_ready
    and bundle_sha256_ready
    and send_readme_ready
    and verify_script_ready
    and payload_like_bundle_file_rows == 0
    and nested_payload_like_archive_member_rows == 0
    and return_inbox_final_evidence_named_archive_member_rows == 0
)

artifact_rows = []
for artifact in sorted(send_bundle_dir.rglob("*")):
    if artifact.is_file():
        rel = artifact.relative_to(run_dir)
        artifact_rows.append(
            {
                "artifact": artifact.name,
                "path": str(rel),
                "sha256": sha256(artifact),
                "bytes": str(artifact.stat().st_size),
                "artifact_ready": "1",
            }
        )
write_csv(run_dir / "complete_source_external_review_send_bundle_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

requirement_rows = [
    {"requirement_id": "v53ac-dispatch-archive-input", "status": "pass", "required_value": "1", "actual_value": v53ac["v53ac_complete_source_review_dispatch_archive_ready"], "reason": "review dispatch archive is ready"},
    {"requirement_id": "v53ag-return-inbox-archive-input", "status": "pass", "required_value": "1", "actual_value": v53ag["v53ag_external_return_inbox_archive_ready"], "reason": "return inbox archive is ready"},
    {"requirement_id": "send-bundle-shape", "status": "pass" if required_bundle_files_present else "blocked", "required_value": str(len(required_bundle_files)), "actual_value": str(sum(1 for rel in required_bundle_files if (send_bundle_dir / rel).is_file())), "reason": "all required bundle files are present"},
    {"requirement_id": "send-bundle-sha256", "status": "pass" if bundle_sha256_ready else "blocked", "required_value": "1", "actual_value": str(bundle_sha256_ready), "reason": "BUNDLE_SHA256SUMS.txt binds bundle files"},
    {"requirement_id": "nested-archives-no-payload", "status": "pass" if nested_payload_like_archive_member_rows == 0 else "blocked", "required_value": "0", "actual_value": str(nested_payload_like_archive_member_rows), "reason": "nested archives contain no model/checkpoint payload-like members"},
    {"requirement_id": "return-inbox-template-only", "status": "pass" if return_inbox_final_evidence_named_archive_member_rows == 0 else "blocked", "required_value": "0", "actual_value": str(return_inbox_final_evidence_named_archive_member_rows), "reason": "return inbox archive contains templates only, no final evidence-named csv/json"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": "7000", "actual_value": v53ag["answer_review_accepted_rows"], "reason": "bundle is a send surface, not returned review evidence"},
    {"requirement_id": "generation-execution-admitted", "status": "blocked", "required_value": "1000", "actual_value": v53ag["generation_execution_admitted_rows"], "reason": "generation cannot run until review return and final result returns are accepted"},
    {"requirement_id": "generation-result-accepted", "status": "blocked", "required_value": "5", "actual_value": v53ag["accepted_generation_result_artifacts"], "reason": "bundle contains templates only"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v53ag["actual_model_generation_ready"], "reason": "actual model generation remains unproven"},
]
write_csv(run_dir / "complete_source_external_review_send_bundle_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "external-send-bundle", "status": "ready" if send_bundle_ready else "blocked", "reason": f"send_bundle_archive_files={send_bundle_archive_files}; bundle_sha256_ready={bundle_sha256_ready}"},
    {"gap": "dispatch-receipts", "status": "blocked", "reason": f"accepted_dispatch_receipt_rows={v53ac['accepted_dispatch_receipt_rows']}/21"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ag['answer_review_accepted_rows']}/7000"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53ag['generation_execution_admitted_rows']}/1000"},
    {"gap": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53ag['accepted_generation_result_artifacts']}/5"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ag['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ah_complete_source_external_review_send_bundle_metrics",
    "v53ac_complete_source_review_dispatch_archive_ready": v53ac["v53ac_complete_source_review_dispatch_archive_ready"],
    "v53ag_external_return_inbox_archive_ready": v53ag["v53ag_external_return_inbox_archive_ready"],
    "send_bundle_ready": str(send_bundle_ready),
    "send_bundle_archive_files": str(send_bundle_archive_files),
    "dispatch_archive_ready": str(dispatch_archive_ready),
    "return_inbox_archive_ready": str(return_inbox_archive_ready),
    "bundle_file_list_ready": str(bundle_file_list_ready),
    "bundle_sha256_ready": str(bundle_sha256_ready),
    "send_readme_ready": str(send_readme_ready),
    "verify_script_ready": str(verify_script_ready),
    "bundle_file_rows": str(len(bundle_file_rows)),
    "required_bundle_file_rows": str(len(required_bundle_files)),
    "required_bundle_files_present": str(required_bundle_files_present),
    "dispatch_archive_member_files": v53ac["archive_member_files"],
    "return_inbox_archive_member_files": v53ag["archive_member_files"],
    "template_archive_member_rows": v53ag["template_archive_member_rows"],
    "return_artifact_template_archive_member_rows": v53ag["return_artifact_template_archive_member_rows"],
    "required_return_artifact_rows": v53ag["required_return_artifact_rows"],
    "payload_like_bundle_file_rows": str(payload_like_bundle_file_rows),
    "nested_payload_like_archive_member_rows": str(nested_payload_like_archive_member_rows),
    "return_inbox_final_evidence_named_archive_member_rows": str(return_inbox_final_evidence_named_archive_member_rows),
    "dispatch_chunk_rows": v53ac["dispatch_chunk_rows"],
    "dispatch_task_rows": v53ac["dispatch_task_rows"],
    "dispatch_return_artifact_rows": v53ac["dispatch_return_artifact_rows"],
    "dispatch_receipt_template_rows": v53ac["dispatch_receipt_template_rows"],
    "accepted_dispatch_receipt_rows": v53ac["accepted_dispatch_receipt_rows"],
    "expected_human_review_rows": v53ac["expected_human_review_rows"],
    "answer_review_accepted_rows": v53ag["answer_review_accepted_rows"],
    "generation_execution_admitted_rows": v53ag["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53ag["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v53ag["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53ag["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ag["runtime_admission_accepted_rows"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ah": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_external_review_send_bundle_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ah_complete_source_external_review_send_bundle_ready": str(send_bundle_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53ac-dispatch-archive-input", "status": "pass", "reason": "v53ac dispatch archive is ready"},
    {"gate": "v53ag-return-inbox-archive-input", "status": "pass", "reason": "v53ag return inbox archive is ready"},
    {"gate": "external-send-bundle", "status": "pass" if send_bundle_ready else "blocked", "reason": f"send_bundle_archive_files={send_bundle_archive_files}"},
    {"gate": "bundle-sha256", "status": "pass" if bundle_sha256_ready else "blocked", "reason": "BUNDLE_SHA256SUMS.txt binds files"},
    {"gate": "no-payload", "status": "pass" if nested_payload_like_archive_member_rows == 0 and payload_like_bundle_file_rows == 0 else "blocked", "reason": f"payload_like_bundle_file_rows={payload_like_bundle_file_rows}; nested_payload_like_archive_member_rows={nested_payload_like_archive_member_rows}"},
    {"gate": "return-inbox-template-only", "status": "pass" if return_inbox_final_evidence_named_archive_member_rows == 0 else "blocked", "reason": f"return_inbox_final_evidence_named_archive_member_rows={return_inbox_final_evidence_named_archive_member_rows}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ag['answer_review_accepted_rows']}/7000"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53ag['generation_execution_admitted_rows']}/1000"},
    {"gate": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53ag['accepted_generation_result_artifacts']}/5"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ag['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "send bundle is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ah Complete-Source External Review Send Bundle Boundary

This artifact bundles the v53ac complete-source review dispatch archive and the
v53ag template-only return inbox archive into one external send surface. It is a
logistics artifact only. It does not create dispatch receipts, human review
judgments, adjudication rows, generation execution, accepted generation result
artifacts, actual model generation, production latency evidence, near-frontier
quality evidence, or release readiness.

Evidence emitted:

- send_bundle_ready={send_bundle_ready}
- send_bundle_archive_files={send_bundle_archive_files}
- dispatch_archive_ready={dispatch_archive_ready}
- return_inbox_archive_ready={return_inbox_archive_ready}
- bundle_file_list_ready={bundle_file_list_ready}
- bundle_sha256_ready={bundle_sha256_ready}
- send_readme_ready={send_readme_ready}
- verify_script_ready={verify_script_ready}
- bundle_file_rows={len(bundle_file_rows)}
- required_bundle_files_present={required_bundle_files_present}
- dispatch_archive_member_files={v53ac['archive_member_files']}
- return_inbox_archive_member_files={v53ag['archive_member_files']}
- template_archive_member_rows={v53ag['template_archive_member_rows']}
- return_artifact_template_archive_member_rows={v53ag['return_artifact_template_archive_member_rows']}
- required_return_artifact_rows={v53ag['required_return_artifact_rows']}
- payload_like_bundle_file_rows={payload_like_bundle_file_rows}
- nested_payload_like_archive_member_rows={nested_payload_like_archive_member_rows}
- return_inbox_final_evidence_named_archive_member_rows={return_inbox_final_evidence_named_archive_member_rows}
- accepted_dispatch_receipt_rows={v53ac['accepted_dispatch_receipt_rows']}
- answer_review_accepted_rows={v53ag['answer_review_accepted_rows']}
- generation_execution_admitted_rows={v53ag['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v53ag['accepted_generation_result_artifacts']}
- actual_model_generation_ready={v53ag['actual_model_generation_ready']}
- full_shard_prerequisites_closed={v53ag['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53ag['runtime_admission_accepted_rows']}
- checkpoint_payload_bytes_downloaded_by_v53ah=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: the external review send bundle is ready to send.
Blocked wording: accepted review return, generation execution, generation
result acceptance, actual generation, production latency, near-frontier quality,
or release readiness.
"""
(run_dir / "V53AH_COMPLETE_SOURCE_EXTERNAL_REVIEW_SEND_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ah-complete-source-external-review-send-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ah_complete_source_external_review_send_bundle_ready": send_bundle_ready,
    "send_bundle_archive_files": send_bundle_archive_files,
    "dispatch_archive_sha256": sha256(send_bundle_dir / "review_dispatch" / dispatch_archive_name),
    "return_inbox_archive_sha256": sha256(send_bundle_dir / "return_inbox" / return_inbox_archive_name),
    "bundle_sha256_manifest_sha256": sha256(sha_path),
    "dispatch_archive_member_files": int(v53ac["archive_member_files"]),
    "return_inbox_archive_member_files": int(v53ag["archive_member_files"]),
    "return_artifact_template_archive_member_rows": int(v53ag["return_artifact_template_archive_member_rows"]),
    "nested_payload_like_archive_member_rows": nested_payload_like_archive_member_rows,
    "return_inbox_final_evidence_named_archive_member_rows": return_inbox_final_evidence_named_archive_member_rows,
    "accepted_dispatch_receipt_rows": int(v53ac["accepted_dispatch_receipt_rows"]),
    "answer_review_accepted_rows": int(v53ag["answer_review_accepted_rows"]),
    "generation_execution_admitted_rows": int(v53ag["generation_execution_admitted_rows"]),
    "accepted_generation_result_artifacts": int(v53ag["accepted_generation_result_artifacts"]),
    "actual_model_generation_ready": int(v53ag["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53ag["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53ag["runtime_admission_accepted_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v53ah": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53ah_complete_source_external_review_send_bundle_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ah_complete_source_external_review_send_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
