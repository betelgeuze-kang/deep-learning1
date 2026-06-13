#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eq_real_generation_intake_dispatch_seal"
RUN_DIR="$RESULTS_DIR/$PREFIX/seal_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61ep_real_generation_intake_inbox_archive.sh" >/dev/null

V61EQ_REUSE_EXISTING="${V61EQ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61eq_real_generation_intake_dispatch_seal.sh" >/dev/null

bash "$RUN_DIR/dispatch_bundle/VERIFY_DISPATCH_BUNDLE.sh" >/dev/null

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
    "v61eq_real_generation_intake_dispatch_seal_ready": "1",
    "v61ep_real_generation_intake_inbox_archive_ready": "1",
    "dispatch_bundle_ready": "1",
    "nested_archive_member_rows": "9",
    "nested_template_member_rows": "9",
    "nested_final_evidence_named_member_rows": "0",
    "bundle_payload_like_file_rows": "0",
    "nested_payload_like_member_rows": "0",
    "dispatch_receipt_template_rows": "1",
    "accepted_dispatch_receipt_rows": "0",
    "final_dispatch_receipt_rows": "0",
    "real_generation_result_artifacts": "0",
    "real_prerequisite_binding_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61eq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61eq {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dispatch_bundle/template_inbox_archive/v61eo_real_generation_intake_inbox_scaffold_001.tar.gz",
    "dispatch_bundle/template_inbox_archive/ARCHIVE_FILE_LIST.txt",
    "dispatch_bundle/template_inbox_archive/ARCHIVE_SHA256SUMS.txt",
    "dispatch_bundle/DISPATCH_MANIFEST.json",
    "dispatch_bundle/DISPATCH_RECEIPT.json.template",
    "dispatch_bundle/SEND_BUNDLE_README.md",
    "dispatch_bundle/VERIFY_DISPATCH_BUNDLE.sh",
    "dispatch_bundle/BUNDLE_FILE_LIST.txt",
    "dispatch_bundle/BUNDLE_SHA256SUMS.txt",
    "real_generation_intake_dispatch_bundle_file_rows.csv",
    "real_generation_intake_dispatch_nested_member_rows.csv",
    "real_generation_intake_dispatch_receipt_contract_rows.csv",
    "real_generation_intake_dispatch_requirement_rows.csv",
    "runtime_gap_rows.csv",
    "v61eq_real_generation_intake_dispatch_seal_manifest.json",
    "source_v61ep/v61ep_real_generation_intake_inbox_archive_summary.csv",
    "source_v61en/v61en_real_generation_intake_work_order_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61eq artifact: {rel}")

bundle_files = read_csv(run_dir / "real_generation_intake_dispatch_bundle_file_rows.csv")
if any(row["payload_like_file"] != "0" for row in bundle_files):
    raise SystemExit("v61eq bundle must not contain payload-like files")
if any(row["final_dispatch_receipt"] != "0" for row in bundle_files):
    raise SystemExit("v61eq must not contain final dispatch receipt")

archive_path = run_dir / "dispatch_bundle/template_inbox_archive/v61eo_real_generation_intake_inbox_scaffold_001.tar.gz"
with tarfile.open(archive_path, "r:gz") as tar:
    members = sorted(member.name for member in tar.getmembers() if member.isfile())
if len(members) != 9:
    raise SystemExit("v61eq nested archive member count mismatch")
if any(not member.endswith(".template") for member in members):
    raise SystemExit("v61eq nested archive must contain templates only")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "real_generation_intake_dispatch_requirement_rows.csv")}
for requirement in ["v61ep-template-archive-input", "dispatch-bundle-ready", "nested-template-only", "no-payload-like-files"]:
    if requirements[requirement] != "pass":
        raise SystemExit(f"v61eq requirement should pass: {requirement}")
for requirement in ["real-dispatch-receipt", "real-generation-intake", "actual-generation"]:
    if requirements[requirement] != "blocked":
        raise SystemExit(f"v61eq requirement should be blocked: {requirement}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61ep-template-archive-input", "dispatch-bundle-ready", "template-only-nested-archive", "repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61eq decision should pass: {gate}")
for gate in ["real-dispatch-receipt", "real-generation-intake", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61eq decision should be blocked: {gate}")

manifest = json.loads((run_dir / "v61eq_real_generation_intake_dispatch_seal_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61eq_real_generation_intake_dispatch_seal_ready") != 1:
    raise SystemExit("v61eq manifest readiness mismatch")
if manifest.get("accepted_dispatch_receipt_rows") != 0:
    raise SystemExit("v61eq manifest must keep dispatch receipt at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61eq manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61eq sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61eq produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61eq real generation intake dispatch seal smoke passed"
