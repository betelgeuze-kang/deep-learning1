#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate"
RUN_ID="${V61FK_RUN_ID:-dispatch_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR_ARG="${V61FK_DISPATCH_RECEIPT_DIR:-}"
RECEIPT_PROVENANCE="${V61FK_RECEIPT_PROVENANCE:-unspecified}"

if [[ "${V61FK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fj_post_fi_real_manifest_external_review_send_return_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RECEIPT_DIR_ARG" "$RECEIPT_PROVENANCE" <<'PY'
import csv
import gzip
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
receipt_arg = sys.argv[5].strip()
receipt_provenance = sys.argv[6].strip() or "unspecified"
results = root / "results"
receipt_dir = Path(receipt_arg).expanduser().resolve() if receipt_arg else None
dispatch_dir = run_dir / "real_manifest_external_review_dispatch_archive"
dispatch_dir.mkdir(parents=True, exist_ok=True)


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def status(flag):
    return "pass" if flag else "blocked"


def ready(flag):
    return "ready" if flag else "blocked"


v61fj_summary_path = results / "v61fj_post_fi_real_manifest_external_review_send_return_bundle_summary.csv"
v61fj_decision_path = results / "v61fj_post_fi_real_manifest_external_review_send_return_bundle_decision.csv"
v61fj_dir = results / "v61fj_post_fi_real_manifest_external_review_send_return_bundle" / "bundle_001"
v61fj_bundle_dir = v61fj_dir / "real_manifest_external_review_send_return_bundle"

for src, rel in [
    (v61fj_summary_path, "source_v61fj/v61fj_post_fi_real_manifest_external_review_send_return_bundle_summary.csv"),
    (v61fj_decision_path, "source_v61fj/v61fj_post_fi_real_manifest_external_review_send_return_bundle_decision.csv"),
    (v61fj_dir / "post_fi_real_manifest_external_review_send_return_bundle_file_rows.csv", "source_v61fj/post_fi_real_manifest_external_review_send_return_bundle_file_rows.csv"),
    (v61fj_dir / "post_fi_real_manifest_external_review_return_template_rows.csv", "source_v61fj/post_fi_real_manifest_external_review_return_template_rows.csv"),
    (v61fj_dir / "post_fi_real_manifest_external_review_send_return_bundle_requirement_rows.csv", "source_v61fj/post_fi_real_manifest_external_review_send_return_bundle_requirement_rows.csv"),
    (v61fj_bundle_dir / "SEND_RETURN_BUNDLE_MANIFEST.json", "source_v61fj/SEND_RETURN_BUNDLE_MANIFEST.json"),
    (v61fj_bundle_dir / "SEND_RETURN_BUNDLE_SHA256SUMS.txt", "source_v61fj/SEND_RETURN_BUNDLE_SHA256SUMS.txt"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61fk source artifact: {src}")
    copy(src, rel)

if not v61fj_bundle_dir.is_dir():
    raise SystemExit("v61fk requires v61fj send-return bundle directory")

v61fj = read_csv(v61fj_summary_path)[0]
if v61fj.get("v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready") != "1":
    raise SystemExit("v61fk requires v61fj send-return bundle readiness")

archive_root = "v61fj_real_manifest_external_review_send_return_bundle_001"
archive_name = archive_root + ".tar.gz"
archive_path = dispatch_dir / archive_name
bundle_files = sorted(path for path in v61fj_bundle_dir.rglob("*") if path.is_file())
with archive_path.open("wb") as raw:
    with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode="w") as tar:
            for path in bundle_files:
                arcname = Path(archive_root) / path.relative_to(v61fj_bundle_dir)
                info = tar.gettarinfo(str(path), arcname=str(arcname))
                info.mtime = 0
                info.uid = 0
                info.gid = 0
                info.uname = ""
                info.gname = ""
                with path.open("rb") as handle:
                    tar.addfile(info, handle)

with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())

file_list_path = dispatch_dir / "DISPATCH_ARCHIVE_FILE_LIST.txt"
file_list_path.write_text("\n".join(members) + "\n", encoding="utf-8")
sha_path = dispatch_dir / "DISPATCH_ARCHIVE_SHA256SUMS.txt"
sha_path.write_text(
    f"{sha256_hex(archive_path)}  {archive_name}\n"
    f"{sha256_hex(file_list_path)}  DISPATCH_ARCHIVE_FILE_LIST.txt\n",
    encoding="utf-8",
)

expected_archive_sha = sha256(archive_path)
expected_bundle_sha = sha256(v61fj_bundle_dir / "SEND_RETURN_BUNDLE_SHA256SUMS.txt")
expected_review_packet_files = int(v61fj["review_packet_files"])
expected_return_template_files = int(v61fj["return_template_files"])

receipt_template = {
    "dispatch_archive_sha256": expected_archive_sha,
    "send_return_bundle_sha256sum_sha256": expected_bundle_sha,
    "operator_identity": "fill-real-operator-identity",
    "sent_at_utc": "fill-real-sent-at-utc",
    "recipient": "fill-real-recipient",
    "receipt_status": "sent",
    "review_packet_files": expected_review_packet_files,
    "return_template_files": expected_return_template_files,
    "template_only_not_evidence": True,
}
(dispatch_dir / "DISPATCH_RECEIPT_TEMPLATE.json").write_text(
    json.dumps(receipt_template, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

verify_script = dispatch_dir / "VERIFY_DISPATCH_ARCHIVE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import hashlib",
            "import tarfile",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'DISPATCH_ARCHIVE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "archive = root / 'v61fj_real_manifest_external_review_send_return_bundle_001.tar.gz'",
            "with tarfile.open(archive, 'r:gz') as tar:",
            "    members = [member.name for member in tar.getmembers() if member.isfile()]",
            "listed = [line for line in (root / 'DISPATCH_ARCHIVE_FILE_LIST.txt').read_text(encoding='utf-8').splitlines() if line]",
            "if sorted(members) != sorted(listed):",
            "    raise SystemExit('archive member list mismatch')",
            "if any(member.endswith(('.safetensors', '.bin', '.pt')) for member in members):",
            "    raise SystemExit('payload-like member found')",
            "if len(members) != 23:",
            "    raise SystemExit(f'expected 23 archive members, got {len(members)}')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

send_readme = run_dir / "SEND_REAL_MANIFEST_EXTERNAL_REVIEW_DISPATCH_ARCHIVE.md"
send_readme.write_text(
    "\n".join(
        [
            "# v61fk Real Manifest External Review Dispatch Archive",
            "",
            "Send `real_manifest_external_review_dispatch_archive/` as the transfer archive",
            "for the v61fj zero-payload send/return bundle. This is dispatch logistics,",
            "not accepted review evidence.",
            "",
            "Receiver checks:",
            "",
            "```bash",
            "cd real_manifest_external_review_dispatch_archive",
            "./VERIFY_DISPATCH_ARCHIVE.sh",
            "```",
            "",
            "Optional receipt:",
            "- Fill `DISPATCH_RECEIPT.json` from `DISPATCH_RECEIPT_TEMPLATE.json`.",
            "- Set `V61FK_DISPATCH_RECEIPT_DIR` to the receipt directory.",
            "- Set `V61FK_RECEIPT_PROVENANCE=real-external-dispatch` only for a real sent bundle.",
            "",
            "Blocked claims:",
            "- dispatch receipts do not count as accepted external review returns.",
            "- external_review_return_ready=0 until v61fh/v61fi accept real review-return evidence.",
            "- actual_model_generation_ready=0.",
            "",
        ]
    ),
    encoding="utf-8",
)

required_fields = [
    "dispatch_archive_sha256",
    "send_return_bundle_sha256sum_sha256",
    "operator_identity",
    "sent_at_utc",
    "recipient",
    "receipt_status",
    "review_packet_files",
    "return_template_files",
]

receipt_dir_supplied = int(receipt_dir is not None)
receipt_dir_exists = int(receipt_dir is not None and receipt_dir.is_dir())
receipt_path = receipt_dir / "DISPATCH_RECEIPT.json" if receipt_dir is not None else None
receipt_file_present = int(receipt_path is not None and receipt_path.is_file())
receipt_json_readable = 0
receipt_data = {}
receipt_sha = ""
json_error = ""
if receipt_file_present:
    receipt_sha = sha256(receipt_path)
    try:
        receipt_data = json.loads(receipt_path.read_text(encoding="utf-8"))
        receipt_json_readable = int(isinstance(receipt_data, dict))
    except json.JSONDecodeError as exc:
        json_error = str(exc)
        receipt_data = {}
    copy(receipt_path, "supplied_dispatch_receipt/DISPATCH_RECEIPT.json")

fixture_provenance = receipt_provenance.startswith("fixture")
if not receipt_dir_supplied:
    selected_receipt_source_class = "none"
elif fixture_provenance:
    selected_receipt_source_class = "fixture-v61fk-dispatch-receipt"
else:
    selected_receipt_source_class = "operator-supplied"

present_fields = [field for field in required_fields if field in receipt_data and str(receipt_data.get(field, "")).strip()]
archive_sha_match = int(str(receipt_data.get("dispatch_archive_sha256", "")) == expected_archive_sha)
bundle_sha_match = int(str(receipt_data.get("send_return_bundle_sha256sum_sha256", "")) == expected_bundle_sha)
receipt_status_sent = int(str(receipt_data.get("receipt_status", "")) == "sent")
operator_identity_present = int(bool(str(receipt_data.get("operator_identity", "")).strip()))
recipient_present = int(bool(str(receipt_data.get("recipient", "")).strip()))
sent_at_present = int(bool(str(receipt_data.get("sent_at_utc", "")).strip()))
review_packet_count_match = int(str(receipt_data.get("review_packet_files", "")) == str(expected_review_packet_files))
return_template_count_match = int(str(receipt_data.get("return_template_files", "")) == str(expected_return_template_files))

candidate_preflight_ready = int(
    receipt_dir_supplied
    and receipt_dir_exists
    and receipt_file_present
    and receipt_json_readable
    and len(present_fields) == len(required_fields)
    and archive_sha_match
    and bundle_sha_match
    and receipt_status_sent
    and operator_identity_present
    and recipient_present
    and sent_at_present
    and review_packet_count_match
    and return_template_count_match
)
non_fixture_receipt = int(receipt_dir_supplied and not fixture_provenance)
real_dispatch_receipt_provenance_asserted = int(receipt_provenance == "real-external-dispatch")
real_dispatch_receipt_ready = int(
    candidate_preflight_ready
    and non_fixture_receipt
    and real_dispatch_receipt_provenance_asserted
)
accepted_dispatch_receipt_rows = real_dispatch_receipt_ready

member_rows = []
for member in members:
    member_rows.append(
        {
            "archive_member": member,
            "review_packet_member": str(int("/review_packet/" in member)),
            "return_template_member": str(int("/return_scaffold/" in member)),
            "metadata_only_member": "1",
            "payload_like_member": str(int(member.endswith((".safetensors", ".bin", ".pt")))),
        }
    )
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_archive_member_rows.csv", list(member_rows[0].keys()), member_rows)

artifact_rows = []
for artifact, purpose in [
    (archive_path, "v61fj send-return bundle transfer archive"),
    (file_list_path, "dispatch archive member list"),
    (sha_path, "dispatch archive checksum ledger"),
    (dispatch_dir / "DISPATCH_RECEIPT_TEMPLATE.json", "template-only dispatch receipt contract"),
    (verify_script, "dispatch archive verifier"),
    (send_readme, "dispatch archive send instructions"),
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
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_archive_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

contract_rows = []
for field in required_fields:
    if field == "dispatch_archive_sha256":
        expected = expected_archive_sha
    elif field == "send_return_bundle_sha256sum_sha256":
        expected = expected_bundle_sha
    elif field == "receipt_status":
        expected = "sent"
    elif field == "review_packet_files":
        expected = str(expected_review_packet_files)
    elif field == "return_template_files":
        expected = str(expected_return_template_files)
    else:
        expected = "non-empty"
    contract_rows.append(
        {
            "required_field": field,
            "expected_value": expected,
            "source": "v61fk-dispatch-archive",
            "accepted_by_default": "0",
        }
    )
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_contract_rows.csv", list(contract_rows[0].keys()), contract_rows)

file_rows = [
    {
        "receipt_artifact": "DISPATCH_RECEIPT.json",
        "receipt_dir_supplied": str(receipt_dir_supplied),
        "receipt_dir_exists": str(receipt_dir_exists),
        "file_exists": str(receipt_file_present),
        "json_readable": str(receipt_json_readable),
        "sha256": receipt_sha,
        "json_error": json_error,
    }
]
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_file_rows.csv", list(file_rows[0].keys()), file_rows)

field_rows = []
for field in required_fields:
    actual = str(receipt_data.get(field, "")) if field in receipt_data else ""
    if field == "dispatch_archive_sha256":
        valid = archive_sha_match
        expected = expected_archive_sha
    elif field == "send_return_bundle_sha256sum_sha256":
        valid = bundle_sha_match
        expected = expected_bundle_sha
    elif field == "receipt_status":
        valid = receipt_status_sent
        expected = "sent"
    elif field == "review_packet_files":
        valid = review_packet_count_match
        expected = str(expected_review_packet_files)
    elif field == "return_template_files":
        valid = return_template_count_match
        expected = str(expected_return_template_files)
    else:
        valid = bool(actual.strip())
        expected = "non-empty"
    field_rows.append(
        {
            "required_field": field,
            "present": str(int(field in present_fields)),
            "valid": str(int(valid)),
            "actual_value": actual,
            "expected_value": expected,
        }
    )
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_field_check_rows.csv", list(field_rows[0].keys()), field_rows)

archive_ready = int(archive_path.is_file() and archive_path.stat().st_size > 0)
archive_sha256_ready = int(sha_path.is_file() and sha256_hex(archive_path) in sha_path.read_text(encoding="utf-8"))
archive_file_list_ready = int(file_list_path.is_file() and len(members) == int(v61fj["bundle_file_rows"]))
review_packet_archive_member_rows = sum(row["review_packet_member"] == "1" for row in member_rows)
return_template_archive_member_rows = sum(row["return_template_member"] == "1" for row in member_rows)
payload_like_archive_member_rows = sum(row["payload_like_member"] == "1" for row in member_rows)
dispatch_receipt_template_ready = int((dispatch_dir / "DISPATCH_RECEIPT_TEMPLATE.json").is_file())
v61fk_ready = int(
    archive_ready
    and archive_sha256_ready
    and archive_file_list_ready
    and review_packet_archive_member_rows == expected_review_packet_files
    and return_template_archive_member_rows == expected_return_template_files
    and payload_like_archive_member_rows == 0
    and dispatch_receipt_template_ready
)

check_rows = [
    {"check_id": "v61fj-send-return-bundle-input", "status": "pass", "required_value": "1", "actual_value": v61fj["v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready"], "reason": "v61fj bundle is ready"},
    {"check_id": "dispatch-archive-file", "status": status(archive_ready), "required_value": "1", "actual_value": str(archive_ready), "reason": archive_name},
    {"check_id": "dispatch-archive-sha256", "status": status(archive_sha256_ready), "required_value": "1", "actual_value": str(archive_sha256_ready), "reason": "archive checksum binds dispatch archive"},
    {"check_id": "dispatch-archive-file-list", "status": status(archive_file_list_ready), "required_value": v61fj["bundle_file_rows"], "actual_value": str(len(members)), "reason": "archive lists all v61fj bundle files"},
    {"check_id": "review-packet-members", "status": status(review_packet_archive_member_rows == expected_review_packet_files), "required_value": str(expected_review_packet_files), "actual_value": str(review_packet_archive_member_rows), "reason": "archive contains all review packet files"},
    {"check_id": "return-template-members", "status": status(return_template_archive_member_rows == expected_return_template_files), "required_value": str(expected_return_template_files), "actual_value": str(return_template_archive_member_rows), "reason": "archive contains all return templates"},
    {"check_id": "no-checkpoint-payload", "status": status(payload_like_archive_member_rows == 0), "required_value": "0", "actual_value": str(payload_like_archive_member_rows), "reason": "archive must contain no model/checkpoint payload-like members"},
    {"check_id": "dispatch-receipt-template", "status": status(dispatch_receipt_template_ready), "required_value": "1", "actual_value": str(dispatch_receipt_template_ready), "reason": "receipt template is present"},
    {"check_id": "receipt-dir-supplied", "status": status(receipt_dir_supplied), "required_value": "1", "actual_value": str(receipt_dir_supplied), "reason": "operator may supply V61FK_DISPATCH_RECEIPT_DIR"},
    {"check_id": "dispatch-receipt-file-present", "status": status(receipt_file_present), "required_value": "1", "actual_value": str(receipt_file_present), "reason": "DISPATCH_RECEIPT.json must be present"},
    {"check_id": "dispatch-receipt-json-readable", "status": status(receipt_json_readable), "required_value": "1", "actual_value": str(receipt_json_readable), "reason": "receipt must be JSON object"},
    {"check_id": "required-receipt-fields-present", "status": status(len(present_fields) == len(required_fields)), "required_value": str(len(required_fields)), "actual_value": str(len(present_fields)), "reason": "receipt must include all required fields"},
    {"check_id": "dispatch-archive-sha-match", "status": status(archive_sha_match), "required_value": expected_archive_sha, "actual_value": str(receipt_data.get("dispatch_archive_sha256", "")), "reason": "receipt must bind archive checksum"},
    {"check_id": "send-return-bundle-sha-match", "status": status(bundle_sha_match), "required_value": expected_bundle_sha, "actual_value": str(receipt_data.get("send_return_bundle_sha256sum_sha256", "")), "reason": "receipt must bind v61fj bundle checksum ledger"},
    {"check_id": "receipt-status-sent", "status": status(receipt_status_sent), "required_value": "sent", "actual_value": str(receipt_data.get("receipt_status", "")), "reason": "receipt must represent a sent bundle"},
    {"check_id": "dispatch-receipt-candidate-preflight-ready", "status": status(candidate_preflight_ready), "required_value": "1", "actual_value": str(candidate_preflight_ready), "reason": "mechanical receipt checks must pass"},
    {"check_id": "non-fixture-dispatch-receipt", "status": status(non_fixture_receipt), "required_value": "1", "actual_value": str(non_fixture_receipt), "reason": "fixture receipts are not real dispatch evidence"},
    {"check_id": "real-dispatch-receipt-provenance", "status": status(real_dispatch_receipt_provenance_asserted), "required_value": "real-external-dispatch", "actual_value": receipt_provenance, "reason": "real dispatch provenance must be explicit"},
    {"check_id": "real-dispatch-receipt-ready", "status": status(real_dispatch_receipt_ready), "required_value": "1", "actual_value": str(real_dispatch_receipt_ready), "reason": "candidate receipt plus non-fixture provenance required"},
    {"check_id": "external-review-return", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "dispatch receipt is not review-return evidence"},
    {"check_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_preflight_check_rows.csv", list(check_rows[0].keys()), check_rows)

command_rows = [
    {"command_id": "verify-dispatch-archive", "command": "bash results/v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate/dispatch_001/real_manifest_external_review_dispatch_archive/VERIFY_DISPATCH_ARCHIVE.sh", "ready_to_run_now": "1", "blocks_generation_claim": "0"},
    {"command_id": "canonical-no-receipt-run", "command": "./experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh", "ready_to_run_now": "1", "blocks_generation_claim": "0"},
    {"command_id": "receipt-preflight-with-real-dir", "command": "V61FK_DISPATCH_RECEIPT_DIR=/path/to/receipt V61FK_RECEIPT_PROVENANCE=real-external-dispatch ./experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh", "ready_to_run_now": "0", "blocks_generation_claim": "1"},
    {"command_id": "external-review-return-intake", "command": "V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/real/review-return ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh", "ready_to_run_now": "0", "blocks_generation_claim": "1"},
]
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_command_rows.csv", list(command_rows[0].keys()), command_rows)

runtime_gap_rows = [
    {"gap": "dispatch-archive", "status": ready(v61fk_ready), "reason": f"archive_members={len(members)}; payload_like={payload_like_archive_member_rows}"},
    {"gap": "dispatch-receipt-candidate-preflight", "status": ready(candidate_preflight_ready), "reason": "optional receipt must pass mechanical checks"},
    {"gap": "real-dispatch-receipt", "status": ready(real_dispatch_receipt_ready), "reason": "requires non-fixture real-external-dispatch provenance"},
    {"gap": "external-review-return", "status": "blocked", "reason": "dispatch receipt is not accepted review return"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

summary = {
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready": str(v61fk_ready),
    "v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready": v61fj["v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready"],
    "dispatch_archive_ready": str(archive_ready),
    "dispatch_archive_sha256_ready": str(archive_sha256_ready),
    "dispatch_archive_file_list_ready": str(archive_file_list_ready),
    "dispatch_archive_member_files": str(len(members)),
    "metadata_only_dispatch_archive_member_rows": str(len(members)),
    "review_packet_archive_member_rows": str(review_packet_archive_member_rows),
    "return_template_archive_member_rows": str(return_template_archive_member_rows),
    "payload_like_dispatch_archive_member_rows": str(payload_like_archive_member_rows),
    "dispatch_receipt_template_ready": str(dispatch_receipt_template_ready),
    "required_dispatch_receipt_field_rows": str(len(required_fields)),
    "receipt_dir_supplied": str(receipt_dir_supplied),
    "receipt_dir_exists": str(receipt_dir_exists),
    "selected_receipt_source_class": selected_receipt_source_class,
    "dispatch_receipt_file_present": str(receipt_file_present),
    "dispatch_receipt_json_readable": str(receipt_json_readable),
    "present_dispatch_receipt_field_rows": str(len(present_fields)),
    "expected_dispatch_archive_sha256": expected_archive_sha,
    "supplied_dispatch_archive_sha256": str(receipt_data.get("dispatch_archive_sha256", "")),
    "dispatch_archive_sha_match": str(archive_sha_match),
    "send_return_bundle_sha_match": str(bundle_sha_match),
    "receipt_status_sent": str(receipt_status_sent),
    "dispatch_receipt_candidate_preflight_ready": str(candidate_preflight_ready),
    "non_fixture_dispatch_receipt": str(non_fixture_receipt),
    "real_dispatch_receipt_provenance_asserted": str(real_dispatch_receipt_provenance_asserted),
    "real_dispatch_receipt_ready": str(real_dispatch_receipt_ready),
    "accepted_dispatch_receipt_rows": str(accepted_dispatch_receipt_rows),
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
write_csv(run_dir / "post_fj_real_manifest_external_review_dispatch_receipt_metric_rows.csv", list(summary.keys()), [summary])
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["check_id"], "status": row["status"], "reason": row["reason"]}
    for row in check_rows
]
decision_rows.append({"gate": "repo-checkpoint-payload", "status": "pass", "reason": "dispatch archive contains no checkpoint payload"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FK_POST_FJ_REAL_MANIFEST_EXTERNAL_REVIEW_DISPATCH_ARCHIVE_RECEIPT_GATE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fk Post-v61fj Real Manifest External Review Dispatch Archive/Receipt Gate Boundary",
            "",
            f"- dispatch_archive_ready={summary['dispatch_archive_ready']}",
            f"- dispatch_archive_member_files={summary['dispatch_archive_member_files']}",
            f"- review_packet_archive_member_rows={summary['review_packet_archive_member_rows']}",
            f"- return_template_archive_member_rows={summary['return_template_archive_member_rows']}",
            f"- payload_like_dispatch_archive_member_rows={summary['payload_like_dispatch_archive_member_rows']}",
            f"- dispatch_receipt_template_ready={summary['dispatch_receipt_template_ready']}",
            f"- receipt_dir_supplied={summary['receipt_dir_supplied']}",
            f"- dispatch_receipt_candidate_preflight_ready={summary['dispatch_receipt_candidate_preflight_ready']}",
            f"- real_dispatch_receipt_ready={summary['real_dispatch_receipt_ready']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fk produces a checksum-bound dispatch archive and receipt preflight contract for the v61fj zero-payload send/return bundle.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fk alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
