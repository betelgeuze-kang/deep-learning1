#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ea_external_review_dispatch_seal_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EA_REUSE_EXISTING="${V61EA_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ea_external_review_dispatch_seal_gate.sh" >/dev/null

"$RUN_DIR/external_review_dispatch_seal/VERIFY_V61EA_DISPATCH_SEAL.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61ea summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61ea_external_review_dispatch_seal_gate_ready": "1",
    "v61dz_review_return_chunk_submission_runway_ready": "1",
    "v53ah_complete_source_external_review_send_bundle_ready": "1",
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": "1",
    "seal_stage_rows": "7",
    "ready_seal_stage_rows": "4",
    "blocked_seal_stage_rows": "3",
    "seal_pointer_rows": "10",
    "send_bundle_ready": "1",
    "send_bundle_archive_files": "2",
    "bundle_file_rows": "10",
    "dispatch_archive_member_files": "78",
    "return_inbox_archive_member_files": "84",
    "return_artifact_template_archive_member_rows": "81",
    "payload_like_bundle_file_rows": "0",
    "nested_payload_like_archive_member_rows": "0",
    "return_inbox_final_evidence_named_archive_member_rows": "0",
    "review_chunk_rows": "21",
    "ready_review_chunk_dispatch_rows": "21",
    "review_chunk_task_rows": "8000",
    "human_review_chunk_task_rows": "7000",
    "adjudication_chunk_task_rows": "1000",
    "review_chunk_return_artifact_rows": "50",
    "dispatch_receipt_template_rows": "21",
    "supplied_dispatch_receipt_rows": "0",
    "accepted_dispatch_receipt_rows": "0",
    "missing_dispatch_receipt_rows": "21",
    "dispatch_receipt_intake_ready": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "seal_invariant_rows": "8",
    "seal_invariant_pass_rows": "8",
    "next_action_rows": "5",
    "ready_next_action_rows": "1",
    "blocked_next_action_rows": "4",
    "seal_file_rows": "9",
    "metadata_only_seal_file_rows": "9",
    "checkpoint_payload_bytes_downloaded_by_v61ea": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ea {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_review_dispatch_seal_stage_rows.csv",
    "external_review_dispatch_seal_pointer_rows.csv",
    "external_review_dispatch_receipt_status_rows.csv",
    "external_review_dispatch_blocker_rows.csv",
    "external_review_dispatch_next_action_rows.csv",
    "external_review_dispatch_seal_invariant_rows.csv",
    "external_review_dispatch_seal_file_rows.csv",
    "external_review_dispatch_seal/EXTERNAL_REVIEW_DISPATCH_SEAL.md",
    "external_review_dispatch_seal/EXTERNAL_REVIEW_DISPATCH_SEAL_STAGES.csv",
    "external_review_dispatch_seal/SEALED_SEND_BUNDLE_POINTERS.csv",
    "external_review_dispatch_seal/DISPATCH_RECEIPT_INTAKE_STATUS.csv",
    "external_review_dispatch_seal/REVIEW_RETURN_BLOCKER_LEDGER.csv",
    "external_review_dispatch_seal/NEXT_ACTIONS.csv",
    "external_review_dispatch_seal/SEAL_INVARIANTS.csv",
    "external_review_dispatch_seal/VERIFY_V61EA_DISPATCH_SEAL.sh",
    "external_review_dispatch_seal/SEAL_MANIFEST.json",
    "v61ea_external_review_dispatch_seal_gate_manifest.json",
    "source_v61dz/v61dz_review_return_chunk_submission_runway_summary.csv",
    "source_v61dz/review_return_submission_chunk_manifest_rows.csv",
    "source_v53ah/v53ah_complete_source_external_review_send_bundle_summary.csv",
    "source_v53ah/complete_source_external_review_send_bundle_file_rows.csv",
    "source_v53ah/complete_source_external_review_send_bundle_nested_member_rows.csv",
    "source_v53ah/BUNDLE_SHA256SUMS.txt",
    "source_v53ad/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "source_v53ad/complete_source_review_dispatch_receipt_status_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ea artifact: {rel}")

stages = read_csv(run_dir / "external_review_dispatch_seal_stage_rows.csv")
if [row["stage_id"] for row in stages] != [
    "01-active-goal-review-runway-bound",
    "02-external-send-bundle-bound",
    "03-send-bundle-integrity-sealed",
    "04-dispatch-receipt-intake-defined",
    "05-dispatch-receipts-returned",
    "06-human-review-return-accepted",
    "07-generation-unblock",
]:
    raise SystemExit("v61ea stage order mismatch")
if sum(row["status"] == "ready" for row in stages) != 4:
    raise SystemExit("v61ea expected four ready stages")
if sum(row["status"] == "blocked" for row in stages) != 3:
    raise SystemExit("v61ea expected three blocked stages")

pointers = read_csv(run_dir / "external_review_dispatch_seal_pointer_rows.csv")
if len(pointers) != 10:
    raise SystemExit("v61ea expected ten sealed send bundle pointers")
if sum(int(row["archive_file"]) for row in pointers) != 2:
    raise SystemExit("v61ea expected two archive pointers")
if any(row["payload_like_file"] != "0" for row in pointers):
    raise SystemExit("v61ea pointers must not include payload-like files")
if any(row["seal_status"] != "sealed" for row in pointers):
    raise SystemExit("v61ea pointer seal status mismatch")

receipts = read_csv(run_dir / "external_review_dispatch_receipt_status_rows.csv")
if len(receipts) != 21:
    raise SystemExit("v61ea expected 21 receipt status rows")
if any(row["receipt_status"] != "missing" for row in receipts):
    raise SystemExit("v61ea default receipts should remain missing")
if sum(int(row["receipt_accepted"]) for row in receipts) != 0:
    raise SystemExit("v61ea must accept zero dispatch receipts by default")

blockers = {row["blocker_id"]: row for row in read_csv(run_dir / "external_review_dispatch_blocker_rows.csv")}
expected_blockers = {
    "dispatch-receipts": ("21", "0"),
    "review-chunk-return-artifacts": ("50", "0"),
    "human-review-rows": ("7000", "0"),
    "adjudication-rows": ("1000", "0"),
    "generation-execution": ("1000", "0"),
    "generation-result-artifacts": ("5", "0"),
}
for blocker_id, (required_rows, accepted_rows) in expected_blockers.items():
    row = blockers.get(blocker_id)
    if not row:
        raise SystemExit(f"missing v61ea blocker: {blocker_id}")
    if row["required_rows"] != required_rows or row["accepted_rows"] != accepted_rows or row["status"] != "blocked":
        raise SystemExit(f"v61ea blocker mismatch: {row}")

actions = read_csv(run_dir / "external_review_dispatch_next_action_rows.csv")
if len(actions) != 5:
    raise SystemExit("v61ea expected five next actions")
if actions[0]["status"] != "ready" or actions[0]["ready_to_run_now"] != "1":
    raise SystemExit("v61ea first action should be send-ready")
if sum(row["status"] == "blocked" for row in actions) != 4:
    raise SystemExit("v61ea expected four blocked next actions")

invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "external_review_dispatch_seal_invariant_rows.csv")}
for invariant_id in [
    "v61dz-active-review-runway-ready",
    "v53ah-send-bundle-ready",
    "send-bundle-no-payload",
    "return-inbox-template-only",
    "receipt-intake-defined-but-empty",
    "review-return-blocks-generation",
    "full-shard-runtime-still-bound",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61ea invariant should pass: {invariant_id}")

seal_files = read_csv(run_dir / "external_review_dispatch_seal_file_rows.csv")
if len(seal_files) != 9:
    raise SystemExit("v61ea expected nine seal files")
if any(row["payload_class"] != "metadata-only" for row in seal_files):
    raise SystemExit("v61ea seal files must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "active-goal-review-runway",
    "external-send-bundle",
    "send-bundle-integrity",
    "dispatch-receipt-intake-surface",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ea decision should pass: {gate}")
for gate in [
    "dispatch-receipts-accepted",
    "review-return-accepted",
    "generation-execution-admitted",
    "actual-model-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ea decision should stay blocked: {gate}")

readme = (run_dir / "external_review_dispatch_seal/EXTERNAL_REVIEW_DISPATCH_SEAL.md").read_text(encoding="utf-8")
for snippet in [
    "metadata-only",
    "send_bundle_ready=1",
    "review_chunk_rows=21",
    "review_chunk_task_rows=8000",
    "review_chunk_return_artifact_rows=50",
    "dispatch_receipt_template_rows=21",
    "accepted_dispatch_receipt_rows=0/21",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "actual_model_generation_ready=0",
]:
    if snippet not in readme:
        raise SystemExit(f"v61ea readme missing snippet: {snippet}")

seal_manifest = json.loads((run_dir / "external_review_dispatch_seal/SEAL_MANIFEST.json").read_text(encoding="utf-8"))
if seal_manifest.get("send_bundle_ready") != 1:
    raise SystemExit("v61ea seal manifest send readiness mismatch")
if seal_manifest.get("accepted_dispatch_receipt_rows") != 0:
    raise SystemExit("v61ea seal manifest must keep dispatch receipts at zero")
if seal_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ea seal manifest must keep actual generation blocked")

manifest = json.loads((run_dir / "v61ea_external_review_dispatch_seal_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ea_external_review_dispatch_seal_gate_ready") != 1:
    raise SystemExit("v61ea manifest readiness mismatch")
if manifest.get("accepted_dispatch_receipt_rows") != 0:
    raise SystemExit("v61ea manifest must keep dispatch receipts at zero")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ea manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ea sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ea produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ea external review dispatch seal gate smoke passed"
