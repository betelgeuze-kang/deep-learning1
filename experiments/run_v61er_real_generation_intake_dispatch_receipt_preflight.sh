#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61er_real_generation_intake_dispatch_receipt_preflight"
RUN_ID="${V61ER_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_DIR_ARG="${V61ER_DISPATCH_RECEIPT_DIR:-}"
RECEIPT_PROVENANCE="${V61ER_RECEIPT_PROVENANCE:-unspecified}"

if [[ "${V61ER_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61er_real_generation_intake_dispatch_receipt_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eq_real_generation_intake_dispatch_seal.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RECEIPT_DIR_ARG" "$RECEIPT_PROVENANCE" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
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
    return dst


def status(flag):
    return "pass" if flag else "blocked"


def ready(flag):
    return "ready" if flag else "blocked"


v61eq_summary_path = results / "v61eq_real_generation_intake_dispatch_seal_summary.csv"
v61eq_decision_path = results / "v61eq_real_generation_intake_dispatch_seal_decision.csv"
v61eq_dir = results / "v61eq_real_generation_intake_dispatch_seal" / "seal_001"
source_paths = [
    (v61eq_summary_path, "source_v61eq/v61eq_real_generation_intake_dispatch_seal_summary.csv"),
    (v61eq_decision_path, "source_v61eq/v61eq_real_generation_intake_dispatch_seal_decision.csv"),
    (v61eq_dir / "real_generation_intake_dispatch_bundle_file_rows.csv", "source_v61eq/real_generation_intake_dispatch_bundle_file_rows.csv"),
    (v61eq_dir / "real_generation_intake_dispatch_nested_member_rows.csv", "source_v61eq/real_generation_intake_dispatch_nested_member_rows.csv"),
    (v61eq_dir / "real_generation_intake_dispatch_receipt_contract_rows.csv", "source_v61eq/real_generation_intake_dispatch_receipt_contract_rows.csv"),
    (v61eq_dir / "real_generation_intake_dispatch_requirement_rows.csv", "source_v61eq/real_generation_intake_dispatch_requirement_rows.csv"),
    (v61eq_dir / "dispatch_bundle" / "DISPATCH_MANIFEST.json", "source_v61eq/DISPATCH_MANIFEST.json"),
    (v61eq_dir / "dispatch_bundle" / "BUNDLE_FILE_LIST.txt", "source_v61eq/BUNDLE_FILE_LIST.txt"),
    (v61eq_dir / "dispatch_bundle" / "BUNDLE_SHA256SUMS.txt", "source_v61eq/BUNDLE_SHA256SUMS.txt"),
]
for src, rel in source_paths:
    if not src.is_file():
        raise SystemExit(f"missing v61er source artifact: {src}")
    copy(src, rel)

v61eq = read_csv(v61eq_summary_path)[0]
if v61eq.get("v61eq_real_generation_intake_dispatch_seal_ready") != "1":
    raise SystemExit("v61er requires v61eq dispatch seal readiness")

required_fields = [
    "dispatch_bundle_sha256",
    "operator_identity",
    "sent_at_utc",
    "recipient",
    "receipt_status",
]
expected_bundle_sha = sha256(v61eq_dir / "dispatch_bundle" / "BUNDLE_SHA256SUMS.txt")

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
    selected_receipt_source_class = "fixture-v61er-dispatch-receipt"
else:
    selected_receipt_source_class = "operator-supplied"

present_fields = [field for field in required_fields if field in receipt_data and str(receipt_data.get(field, "")).strip()]
missing_fields = [field for field in required_fields if field not in present_fields]
dispatch_bundle_sha_match = int(str(receipt_data.get("dispatch_bundle_sha256", "")) == expected_bundle_sha)
receipt_status_sent = int(str(receipt_data.get("receipt_status", "")) == "sent")
operator_identity_present = int(bool(str(receipt_data.get("operator_identity", "")).strip()))
recipient_present = int(bool(str(receipt_data.get("recipient", "")).strip()))
sent_at_present = int(bool(str(receipt_data.get("sent_at_utc", "")).strip()))

candidate_preflight_ready = int(
    receipt_dir_supplied
    and receipt_dir_exists
    and receipt_file_present
    and receipt_json_readable
    and len(missing_fields) == 0
    and dispatch_bundle_sha_match
    and receipt_status_sent
    and operator_identity_present
    and recipient_present
    and sent_at_present
)
non_fixture_receipt = int(receipt_dir_supplied and not fixture_provenance)
real_dispatch_receipt_provenance_asserted = int(receipt_provenance == "real-external-dispatch")
real_dispatch_receipt_ready = int(
    candidate_preflight_ready
    and non_fixture_receipt
    and real_dispatch_receipt_provenance_asserted
)
accepted_dispatch_receipt_rows = real_dispatch_receipt_ready

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
write_csv(run_dir / "real_generation_intake_dispatch_receipt_file_rows.csv", list(file_rows[0].keys()), file_rows)

field_rows = []
for field in required_fields:
    actual = str(receipt_data.get(field, "")) if field in receipt_data else ""
    if field == "dispatch_bundle_sha256" and actual:
        valid = dispatch_bundle_sha_match
        reason = "must match v61eq dispatch bundle checksum ledger"
    elif field == "receipt_status" and actual:
        valid = receipt_status_sent
        reason = "must be sent"
    else:
        valid = bool(actual.strip())
        reason = "must be present"
    field_rows.append(
        {
            "required_field": field,
            "present": str(int(field in present_fields)),
            "valid": str(int(valid)),
            "actual_value": actual,
            "expected_value": expected_bundle_sha if field == "dispatch_bundle_sha256" else ("sent" if field == "receipt_status" else "non-empty"),
            "reason": reason,
        }
    )
write_csv(run_dir / "real_generation_intake_dispatch_receipt_field_check_rows.csv", list(field_rows[0].keys()), field_rows)

check_rows = [
    {"check_id": "receipt-dir-supplied", "status": status(receipt_dir_supplied), "required_value": "1", "actual_value": str(receipt_dir_supplied), "reason": "operator must supply V61ER_DISPATCH_RECEIPT_DIR"},
    {"check_id": "receipt-dir-exists", "status": status(receipt_dir_exists), "required_value": "1", "actual_value": str(receipt_dir_exists), "reason": "supplied receipt directory must exist"},
    {"check_id": "dispatch-receipt-file-present", "status": status(receipt_file_present), "required_value": "1", "actual_value": str(receipt_file_present), "reason": "DISPATCH_RECEIPT.json must be present"},
    {"check_id": "dispatch-receipt-json-readable", "status": status(receipt_json_readable), "required_value": "1", "actual_value": str(receipt_json_readable), "reason": "receipt must be JSON object"},
    {"check_id": "required-receipt-fields-present", "status": status(len(missing_fields) == 0), "required_value": str(len(required_fields)), "actual_value": str(len(present_fields)), "reason": "receipt must include all required fields"},
    {"check_id": "dispatch-bundle-sha-match", "status": status(dispatch_bundle_sha_match), "required_value": expected_bundle_sha, "actual_value": str(receipt_data.get("dispatch_bundle_sha256", "")), "reason": "receipt must bind the v61eq bundle checksum ledger"},
    {"check_id": "receipt-status-sent", "status": status(receipt_status_sent), "required_value": "sent", "actual_value": str(receipt_data.get("receipt_status", "")), "reason": "receipt must represent a sent bundle"},
    {"check_id": "operator-identity-present", "status": status(operator_identity_present), "required_value": "1", "actual_value": str(operator_identity_present), "reason": "operator identity must be supplied"},
    {"check_id": "recipient-present", "status": status(recipient_present), "required_value": "1", "actual_value": str(recipient_present), "reason": "recipient must be supplied"},
    {"check_id": "sent-at-present", "status": status(sent_at_present), "required_value": "1", "actual_value": str(sent_at_present), "reason": "sent timestamp must be supplied"},
    {"check_id": "dispatch-receipt-candidate-preflight-ready", "status": status(candidate_preflight_ready), "required_value": "1", "actual_value": str(candidate_preflight_ready), "reason": "mechanical receipt checks must pass"},
    {"check_id": "non-fixture-dispatch-receipt", "status": status(non_fixture_receipt), "required_value": "1", "actual_value": str(non_fixture_receipt), "reason": "fixture receipts are not real dispatch evidence"},
    {"check_id": "real-dispatch-receipt-provenance", "status": status(real_dispatch_receipt_provenance_asserted), "required_value": "real-external-dispatch", "actual_value": receipt_provenance, "reason": "real dispatch provenance must be explicit"},
    {"check_id": "real-dispatch-receipt-ready", "status": status(real_dispatch_receipt_ready), "required_value": "1", "actual_value": str(real_dispatch_receipt_ready), "reason": "candidate receipt plus non-fixture provenance required"},
    {"check_id": "real-generation-intake-handoff", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "receipt alone is not generation evidence"},
    {"check_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "real_generation_intake_dispatch_receipt_preflight_check_rows.csv", list(check_rows[0].keys()), check_rows)

metric = {
    "v61er_real_generation_intake_dispatch_receipt_preflight_ready": "1",
    "v61eq_real_generation_intake_dispatch_seal_ready": v61eq["v61eq_real_generation_intake_dispatch_seal_ready"],
    "receipt_dir_supplied": str(receipt_dir_supplied),
    "receipt_dir_exists": str(receipt_dir_exists),
    "selected_receipt_source_class": selected_receipt_source_class,
    "dispatch_receipt_file_present": str(receipt_file_present),
    "dispatch_receipt_json_readable": str(receipt_json_readable),
    "required_receipt_field_rows": str(len(required_fields)),
    "present_receipt_field_rows": str(len(present_fields)),
    "expected_dispatch_bundle_sha256": expected_bundle_sha,
    "supplied_dispatch_bundle_sha256": str(receipt_data.get("dispatch_bundle_sha256", "")),
    "dispatch_bundle_sha_match": str(dispatch_bundle_sha_match),
    "receipt_status_sent": str(receipt_status_sent),
    "dispatch_receipt_candidate_preflight_ready": str(candidate_preflight_ready),
    "non_fixture_dispatch_receipt": str(non_fixture_receipt),
    "real_dispatch_receipt_provenance_asserted": str(real_dispatch_receipt_provenance_asserted),
    "real_dispatch_receipt_ready": str(real_dispatch_receipt_ready),
    "accepted_dispatch_receipt_rows": str(accepted_dispatch_receipt_rows),
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61er": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "real_generation_intake_dispatch_receipt_preflight_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys()), [metric])

command_rows = [
    {
        "command_id": "verify-v61eq-dispatch-bundle",
        "command": "bash results/v61eq_real_generation_intake_dispatch_seal/seal_001/dispatch_bundle/VERIFY_DISPATCH_BUNDLE.sh",
        "ready_to_run_now": "1",
        "reason": "v61eq dispatch bundle exists",
    },
    {
        "command_id": "run-v61er-receipt-preflight",
        "command": "V61ER_DISPATCH_RECEIPT_DIR=<returned_receipt_dir> ./experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh",
        "ready_to_run_now": "1",
        "reason": "receiver preflight is available",
    },
    {
        "command_id": "promote-real-dispatch-receipt",
        "command": "V61ER_RECEIPT_PROVENANCE=real-external-dispatch V61ER_DISPATCH_RECEIPT_DIR=<returned_receipt_dir> ./experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh",
        "ready_to_run_now": str(real_dispatch_receipt_ready),
        "reason": "requires non-fixture receipt and explicit real provenance",
    },
    {
        "command_id": "run-real-generation-intake",
        "command": "./experiments/test_v61em_generation_intake_dual_preflight_rendezvous.sh",
        "ready_to_run_now": "0",
        "reason": "receipt alone does not supply generation-result artifacts or prerequisite binding",
    },
]
write_csv(run_dir / "real_generation_intake_dispatch_receipt_command_rows.csv", list(command_rows[0].keys()), command_rows)

runtime_gap_rows = [
    {"gap": "dispatch-bundle", "status": "ready", "reason": "v61eq dispatch bundle ready"},
    {"gap": "dispatch-receipt-candidate", "status": ready(candidate_preflight_ready), "reason": f"candidate_preflight_ready={candidate_preflight_ready}"},
    {"gap": "real-dispatch-receipt", "status": ready(real_dispatch_receipt_ready), "reason": "requires non-fixture receipt and real provenance"},
    {"gap": "real-generation-intake", "status": "blocked", "reason": "receipt is logistics evidence only"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61eq-dispatch-bundle-ready", "status": "pass", "reason": "v61eq dispatch seal is ready"},
    {"gate": "dispatch-receipt-candidate-preflight", "status": status(candidate_preflight_ready), "reason": f"candidate_preflight_ready={candidate_preflight_ready}"},
    {"gate": "non-fixture-dispatch-receipt", "status": status(non_fixture_receipt), "reason": f"selected_receipt_source_class={selected_receipt_source_class}"},
    {"gate": "real-dispatch-receipt-provenance", "status": status(real_dispatch_receipt_provenance_asserted), "reason": f"provenance={receipt_provenance}"},
    {"gate": "real-dispatch-receipt-ready", "status": status(real_dispatch_receipt_ready), "reason": f"real_dispatch_receipt_ready={real_dispatch_receipt_ready}"},
    {"gate": "real-generation-intake", "status": "blocked", "reason": "dispatch receipt is not generation evidence"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "receipt preflight copies metadata only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61ER_REAL_GENERATION_INTAKE_DISPATCH_RECEIPT_PREFLIGHT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61er Real Generation Intake Dispatch Receipt Preflight Boundary",
            "",
            f"- receipt_dir_supplied={receipt_dir_supplied}",
            f"- dispatch_receipt_candidate_preflight_ready={candidate_preflight_ready}",
            f"- real_dispatch_receipt_ready={real_dispatch_receipt_ready}",
            "- real_generation_intake_handoff_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- The v61eq dispatch bundle can be receipt-preflighted.",
            "- A fixture receipt can prove checksum and required-field mechanics.",
            "",
            "Blocked wording:",
            "- Do not claim real dispatch receipt acceptance unless provenance is non-fixture and explicit.",
            "- Do not claim real generation intake, actual generation, production latency, near-frontier quality, or release readiness from a receipt alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61er-real-generation-intake-dispatch-receipt-preflight",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61er_real_generation_intake_dispatch_receipt_preflight_ready": 1,
    "dispatch_receipt_candidate_preflight_ready": candidate_preflight_ready,
    "real_dispatch_receipt_ready": real_dispatch_receipt_ready,
    "accepted_dispatch_receipt_rows": accepted_dispatch_receipt_rows,
    "real_generation_intake_handoff_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61er_real_generation_intake_dispatch_receipt_preflight_manifest.json").write_text(
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

echo "v61er_real_generation_intake_dispatch_receipt_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
