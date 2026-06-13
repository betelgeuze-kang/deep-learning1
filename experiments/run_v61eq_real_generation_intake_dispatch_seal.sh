#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eq_real_generation_intake_dispatch_seal"
RUN_ID="${V61EQ_RUN_ID:-seal_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61eq_real_generation_intake_dispatch_seal_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ep_real_generation_intake_inbox_archive.sh" >/dev/null
V61EN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null

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
bundle_dir = run_dir / "dispatch_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)


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
    dst = bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def tar_file_members(path):
    with tarfile.open(path, "r:gz") as tar:
        return sorted(member.name for member in tar.getmembers() if member.isfile())


v61ep_summary_path = results / "v61ep_real_generation_intake_inbox_archive_summary.csv"
v61ep_decision_path = results / "v61ep_real_generation_intake_inbox_archive_decision.csv"
v61ep_dir = results / "v61ep_real_generation_intake_inbox_archive" / "archive_001"
v61en_summary_path = results / "v61en_real_generation_intake_work_order_summary.csv"
v61en_decision_path = results / "v61en_real_generation_intake_work_order_decision.csv"
v61en_dir = results / "v61en_real_generation_intake_work_order" / "work_order_001"

v61ep = read_csv(v61ep_summary_path)[0]
v61en = read_csv(v61en_summary_path)[0]
if v61ep["v61ep_real_generation_intake_inbox_archive_ready"] != "1":
    raise SystemExit("v61eq requires v61ep inbox archive readiness")
if v61en["v61en_real_generation_intake_work_order_ready"] != "1":
    raise SystemExit("v61eq requires v61en work order readiness")

for src, rel in [
    (v61ep_summary_path, "source_v61ep/v61ep_real_generation_intake_inbox_archive_summary.csv"),
    (v61ep_decision_path, "source_v61ep/v61ep_real_generation_intake_inbox_archive_decision.csv"),
    (v61ep_dir / "real_generation_intake_inbox_archive_member_rows.csv", "source_v61ep/real_generation_intake_inbox_archive_member_rows.csv"),
    (v61ep_dir / "real_generation_intake_inbox_archive_artifact_rows.csv", "source_v61ep/real_generation_intake_inbox_archive_artifact_rows.csv"),
    (v61ep_dir / "real_generation_intake_inbox_archive_requirement_rows.csv", "source_v61ep/real_generation_intake_inbox_archive_requirement_rows.csv"),
    (v61en_summary_path, "source_v61en/v61en_real_generation_intake_work_order_summary.csv"),
    (v61en_decision_path, "source_v61en/v61en_real_generation_intake_work_order_decision.csv"),
    (v61en_dir / "real_generation_intake_work_order_rows.csv", "source_v61en/real_generation_intake_work_order_rows.csv"),
    (v61en_dir / "real_generation_intake_command_rows.csv", "source_v61en/real_generation_intake_command_rows.csv"),
    (v61en_dir / "real_generation_intake_blocker_rows.csv", "source_v61en/real_generation_intake_blocker_rows.csv"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61eq source artifact: {src}")
    copy_to_run(src, rel)

archive_name = "v61eo_real_generation_intake_inbox_scaffold_001.tar.gz"
archive_src = v61ep_dir / "archive" / archive_name
archive_file_list_src = v61ep_dir / "archive" / "ARCHIVE_FILE_LIST.txt"
archive_sha_src = v61ep_dir / "archive" / "ARCHIVE_SHA256SUMS.txt"
for src in [archive_src, archive_file_list_src, archive_sha_src]:
    if not src.is_file():
        raise SystemExit(f"missing v61eq archive source: {src}")

copy_to_bundle(archive_src, f"template_inbox_archive/{archive_name}")
copy_to_bundle(archive_file_list_src, "template_inbox_archive/ARCHIVE_FILE_LIST.txt")
copy_to_bundle(archive_sha_src, "template_inbox_archive/ARCHIVE_SHA256SUMS.txt")

dispatch_manifest = {
    "bundle_scope": "v61eq-real-generation-intake-dispatch-seal",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "template_archive": f"template_inbox_archive/{archive_name}",
    "template_archive_sha256": sha256(archive_src),
    "template_archive_member_files": int(v61ep["archive_member_files"]),
    "template_archive_member_rows": int(v61ep["template_archive_member_rows"]),
    "final_evidence_named_archive_member_rows": int(v61ep["final_evidence_named_archive_member_rows"]),
    "payload_like_archive_member_rows": int(v61ep["payload_like_archive_member_rows"]),
    "dispatch_receipt_status": "template-only",
    "real_generation_intake_handoff_ready": 0,
    "actual_model_generation_ready": 0,
}
write_json(bundle_dir / "DISPATCH_MANIFEST.json", dispatch_manifest)

receipt_template = {
    "dispatch_bundle_sha256": "fill-after-real-send",
    "operator_identity": "fill-with-real-operator-identity",
    "sent_at_utc": "fill-with-real-timestamp",
    "recipient": "fill-with-real-recipient",
    "receipt_status": "template-not-evidence",
    "template_warning": "copy to DISPATCH_RECEIPT.json only after real dispatch",
}
write_json(bundle_dir / "DISPATCH_RECEIPT.json.template", receipt_template)

send_readme = bundle_dir / "SEND_BUNDLE_README.md"
send_readme.write_text(
    "\n".join(
        [
            "# v61eq Real Generation Intake Dispatch Seal",
            "",
            "This bundle ships the v61ep template-only real generation intake inbox archive.",
            "It is dispatch-ready logistics, not accepted evidence.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "./VERIFY_DISPATCH_BUNDLE.sh",
            "```",
            "",
            "The dispatch receipt is a `.template` file. Copy it to `DISPATCH_RECEIPT.json` only after real dispatch.",
            "The nested intake archive contains templates only and no final evidence filenames.",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = bundle_dir / "VERIFY_DISPATCH_BUNDLE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import hashlib",
            "from pathlib import Path",
            "root = Path('.')",
            "for line in (root / 'BUNDLE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "PY_VERIFY",
            f"tar -tzf template_inbox_archive/{archive_name} >/dev/null",
            "test -f DISPATCH_RECEIPT.json.template",
            "test ! -f DISPATCH_RECEIPT.json",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

file_list_path = bundle_dir / "BUNDLE_FILE_LIST.txt"
listed_files = sorted(
    str(path.relative_to(bundle_dir))
    for path in bundle_dir.rglob("*")
    if path.is_file() and path.name not in {"BUNDLE_FILE_LIST.txt", "BUNDLE_SHA256SUMS.txt"}
)
file_list_path.write_text("\n".join(listed_files) + "\n", encoding="utf-8")

sha_path = bundle_dir / "BUNDLE_SHA256SUMS.txt"
sha_targets = sorted(path for path in bundle_dir.rglob("*") if path.is_file() and path.name != "BUNDLE_SHA256SUMS.txt")
sha_path.write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(bundle_dir)}\n" for path in sha_targets),
    encoding="utf-8",
)

nested_members = tar_file_members(bundle_dir / "template_inbox_archive" / archive_name)
bundle_file_rows = []
for path in sorted(bundle_dir.rglob("*")):
    if path.is_file():
        rel = str(path.relative_to(bundle_dir))
        bundle_file_rows.append(
            {
                "bundle_file": rel,
                "bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "archive_file": str(int(path.name.endswith(".tar.gz"))),
                "template_file": str(int(path.name.endswith(".template"))),
                "payload_like_file": str(int(path.name.endswith((".safetensors", ".bin", ".pt")))),
                "final_dispatch_receipt": str(int(path.name == "DISPATCH_RECEIPT.json")),
            }
        )
write_csv(run_dir / "real_generation_intake_dispatch_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

nested_rows = []
for member in nested_members:
    nested_rows.append(
        {
            "archive_member": member,
            "template_member": str(int(member.endswith(".template"))),
            "payload_like_member": str(int(member.endswith((".safetensors", ".bin", ".pt")))),
            "final_evidence_named_member": str(
                int(
                    (member.endswith(".csv") or member.endswith(".json") or member.endswith(".jsonl"))
                    and not member.endswith(".template")
                )
            ),
        }
    )
write_csv(run_dir / "real_generation_intake_dispatch_nested_member_rows.csv", list(nested_rows[0].keys()), nested_rows)

receipt_contract_rows = [
    {
        "receipt_artifact": "DISPATCH_RECEIPT.json",
        "template_artifact": "DISPATCH_RECEIPT.json.template",
        "required_field": field,
        "accepted_now": "0",
    }
    for field in ["dispatch_bundle_sha256", "operator_identity", "sent_at_utc", "recipient", "receipt_status"]
]
write_csv(run_dir / "real_generation_intake_dispatch_receipt_contract_rows.csv", list(receipt_contract_rows[0].keys()), receipt_contract_rows)

bundle_file_count = len(bundle_file_rows)
bundle_payload_like_files = sum(row["payload_like_file"] == "1" for row in bundle_file_rows)
final_dispatch_receipt_rows = sum(row["final_dispatch_receipt"] == "1" for row in bundle_file_rows)
nested_template_rows = sum(row["template_member"] == "1" for row in nested_rows)
nested_final_evidence_rows = sum(row["final_evidence_named_member"] == "1" for row in nested_rows)
nested_payload_rows = sum(row["payload_like_member"] == "1" for row in nested_rows)
bundle_ready = int(
    (bundle_dir / "template_inbox_archive" / archive_name).is_file()
    and (bundle_dir / "BUNDLE_SHA256SUMS.txt").is_file()
    and (bundle_dir / "BUNDLE_FILE_LIST.txt").is_file()
    and (bundle_dir / "DISPATCH_RECEIPT.json.template").is_file()
    and final_dispatch_receipt_rows == 0
    and bundle_payload_like_files == 0
    and nested_template_rows == int(v61ep["archive_member_files"])
    and nested_final_evidence_rows == 0
    and nested_payload_rows == 0
)

requirement_rows = [
    {"requirement_id": "v61ep-template-archive-input", "status": "pass", "required_value": "1", "actual_value": v61ep["v61ep_real_generation_intake_inbox_archive_ready"], "reason": "v61ep archive is ready"},
    {"requirement_id": "dispatch-bundle-ready", "status": "pass" if bundle_ready else "blocked", "required_value": "1", "actual_value": str(bundle_ready), "reason": "bundle files and checksums present"},
    {"requirement_id": "nested-template-only", "status": "pass" if nested_final_evidence_rows == 0 else "blocked", "required_value": "0", "actual_value": str(nested_final_evidence_rows), "reason": "nested archive must not contain final evidence filenames"},
    {"requirement_id": "no-payload-like-files", "status": "pass" if bundle_payload_like_files == 0 and nested_payload_rows == 0 else "blocked", "required_value": "0", "actual_value": str(bundle_payload_like_files + nested_payload_rows), "reason": "bundle must not contain checkpoint payload files"},
    {"requirement_id": "real-dispatch-receipt", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "receipt is template-only"},
    {"requirement_id": "real-generation-intake", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "dispatch seal does not accept evidence"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "real_generation_intake_dispatch_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "dispatch-bundle", "status": "ready" if bundle_ready else "blocked", "reason": f"bundle_file_rows={bundle_file_count}"},
    {"gap": "real-dispatch-receipt", "status": "blocked", "reason": "DISPATCH_RECEIPT.json.template only"},
    {"gap": "real-generation-intake", "status": "blocked", "reason": "dispatch bundle is not intake evidence"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

summary = {
    "v61eq_real_generation_intake_dispatch_seal_ready": str(bundle_ready),
    "v61ep_real_generation_intake_inbox_archive_ready": v61ep["v61ep_real_generation_intake_inbox_archive_ready"],
    "dispatch_bundle_ready": str(bundle_ready),
    "bundle_file_rows": str(bundle_file_count),
    "nested_archive_member_rows": str(len(nested_rows)),
    "nested_template_member_rows": str(nested_template_rows),
    "nested_final_evidence_named_member_rows": str(nested_final_evidence_rows),
    "bundle_payload_like_file_rows": str(bundle_payload_like_files),
    "nested_payload_like_member_rows": str(nested_payload_rows),
    "dispatch_receipt_template_rows": "1",
    "accepted_dispatch_receipt_rows": "0",
    "final_dispatch_receipt_rows": str(final_dispatch_receipt_rows),
    "real_generation_result_artifacts": "0",
    "real_prerequisite_binding_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61eq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ep-template-archive-input", "status": "pass", "reason": "v61ep archive ready"},
    {"gate": "dispatch-bundle-ready", "status": "pass" if bundle_ready else "blocked", "reason": f"bundle_ready={bundle_ready}"},
    {"gate": "template-only-nested-archive", "status": "pass" if nested_final_evidence_rows == 0 else "blocked", "reason": f"nested_final_evidence_named_member_rows={nested_final_evidence_rows}"},
    {"gate": "real-dispatch-receipt", "status": "blocked", "reason": "receipt is template-only"},
    {"gate": "real-generation-intake", "status": "blocked", "reason": "dispatch seal is not accepted evidence"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted real generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata/template dispatch bundle only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

manifest = {
    "manifest_scope": "v61eq-real-generation-intake-dispatch-seal",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61eq_real_generation_intake_dispatch_seal_ready": bundle_ready,
    "dispatch_bundle_ready": bundle_ready,
    "nested_archive_member_rows": len(nested_rows),
    "nested_final_evidence_named_member_rows": nested_final_evidence_rows,
    "accepted_dispatch_receipt_rows": 0,
    "real_generation_intake_handoff_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61eq_real_generation_intake_dispatch_seal_manifest.json").write_text(
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

echo "v61eq_real_generation_intake_dispatch_seal_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
