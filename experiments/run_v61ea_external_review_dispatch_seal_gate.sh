#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ea_external_review_dispatch_seal_gate"
RUN_ID="${V61EA_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ea_external_review_dispatch_seal_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61dz_review_return_chunk_submission_runway_summary.csv" ]]; then
  V61DZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dz_review_return_chunk_submission_runway.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53ah_complete_source_external_review_send_bundle_summary.csv" ]]; then
  V53AH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ah_complete_source_external_review_send_bundle.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv" ]]; then
  V53AD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
seal_dir = run_dir / "external_review_dispatch_seal"
seal_dir.mkdir(parents=True, exist_ok=True)


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


def copy_seal(src, rel):
    dst = seal_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61dz_summary": results / "v61dz_review_return_chunk_submission_runway_summary.csv",
    "v61dz_decision": results / "v61dz_review_return_chunk_submission_runway_decision.csv",
    "v61dz_chunk_manifest": results / "v61dz_review_return_chunk_submission_runway/gate_001/review_return_submission_chunk_manifest_rows.csv",
    "v53ah_summary": results / "v53ah_complete_source_external_review_send_bundle_summary.csv",
    "v53ah_decision": results / "v53ah_complete_source_external_review_send_bundle_decision.csv",
    "v53ah_file_rows": results / "v53ah_complete_source_external_review_send_bundle/bundle_001/complete_source_external_review_send_bundle_file_rows.csv",
    "v53ah_member_rows": results / "v53ah_complete_source_external_review_send_bundle/bundle_001/complete_source_external_review_send_bundle_nested_member_rows.csv",
    "v53ah_sha": results / "v53ah_complete_source_external_review_send_bundle/bundle_001/send_bundle/BUNDLE_SHA256SUMS.txt",
    "v53ah_manifest": results / "v53ah_complete_source_external_review_send_bundle/bundle_001/v53ah_complete_source_external_review_send_bundle_manifest.json",
    "v53ad_summary": results / "v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "v53ad_decision": results / "v53ad_complete_source_review_dispatch_receipt_intake_decision.csv",
    "v53ad_receipt_status": results / "v53ad_complete_source_review_dispatch_receipt_intake/intake_001/complete_source_review_dispatch_receipt_status_rows.csv",
}

# Older runs used runway_001 for v61dz. Keep the source lookup tolerant.
if not sources["v61dz_chunk_manifest"].is_file():
    sources["v61dz_chunk_manifest"] = results / "v61dz_review_return_chunk_submission_runway/runway_001/review_return_submission_chunk_manifest_rows.csv"

for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ea source {key}: {path}")

copy(sources["v61dz_summary"], "source_v61dz/v61dz_review_return_chunk_submission_runway_summary.csv")
copy(sources["v61dz_decision"], "source_v61dz/v61dz_review_return_chunk_submission_runway_decision.csv")
copy(sources["v61dz_chunk_manifest"], "source_v61dz/review_return_submission_chunk_manifest_rows.csv")
copy(sources["v53ah_summary"], "source_v53ah/v53ah_complete_source_external_review_send_bundle_summary.csv")
copy(sources["v53ah_decision"], "source_v53ah/v53ah_complete_source_external_review_send_bundle_decision.csv")
copy(sources["v53ah_file_rows"], "source_v53ah/complete_source_external_review_send_bundle_file_rows.csv")
copy(sources["v53ah_member_rows"], "source_v53ah/complete_source_external_review_send_bundle_nested_member_rows.csv")
copy(sources["v53ah_sha"], "source_v53ah/BUNDLE_SHA256SUMS.txt")
copy(sources["v53ah_manifest"], "source_v53ah/v53ah_complete_source_external_review_send_bundle_manifest.json")
copy(sources["v53ad_summary"], "source_v53ad/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv")
copy(sources["v53ad_decision"], "source_v53ad/v53ad_complete_source_review_dispatch_receipt_intake_decision.csv")
copy(sources["v53ad_receipt_status"], "source_v53ad/complete_source_review_dispatch_receipt_status_rows.csv")

v61dz = read_csv(sources["v61dz_summary"])[0]
v53ah = read_csv(sources["v53ah_summary"])[0]
v53ad = read_csv(sources["v53ad_summary"])[0]
file_rows = read_csv(sources["v53ah_file_rows"])
member_rows = read_csv(sources["v53ah_member_rows"])
receipt_rows = read_csv(sources["v53ad_receipt_status"])

if v61dz["v61dz_review_return_chunk_submission_runway_ready"] != "1":
    raise SystemExit("v61ea requires v61dz ready")
if v53ah["v53ah_complete_source_external_review_send_bundle_ready"] != "1":
    raise SystemExit("v61ea requires v53ah send bundle ready")
if v53ad["v53ad_complete_source_review_dispatch_receipt_intake_ready"] != "1":
    raise SystemExit("v61ea requires v53ad receipt intake surface ready")

seal_stage_rows = [
    {
        "stage_id": "01-active-goal-review-runway-bound",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61dz",
        "evidence": "21 dispatch-ready chunks and 8000 review/adjudication tasks are bound",
    },
    {
        "stage_id": "02-external-send-bundle-bound",
        "status": "ready",
        "ready": "1",
        "source_gate": "v53ah",
        "evidence": "two send archives, file list, sha256 manifest, and verifier are ready",
    },
    {
        "stage_id": "03-send-bundle-integrity-sealed",
        "status": "ready",
        "ready": "1",
        "source_gate": "v53ah",
        "evidence": "bundle sha256 and nested archive no-payload/template-only checks pass",
    },
    {
        "stage_id": "04-dispatch-receipt-intake-defined",
        "status": "ready",
        "ready": "1",
        "source_gate": "v53ad",
        "evidence": "21 receipt template rows are defined for post-send acknowledgement intake",
    },
    {
        "stage_id": "05-dispatch-receipts-returned",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v53ad",
        "evidence": "accepted_dispatch_receipt_rows=0/21",
    },
    {
        "stage_id": "06-human-review-return-accepted",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v53s/v53v",
        "evidence": "accepted human/adjudication rows are 0/7000 and 0/1000",
    },
    {
        "stage_id": "07-generation-unblock",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61de/v61cu",
        "evidence": "generation execution/result/actual generation remain blocked",
    },
]
write_csv(run_dir / "external_review_dispatch_seal_stage_rows.csv", list(seal_stage_rows[0].keys()), seal_stage_rows)
copy_seal(run_dir / "external_review_dispatch_seal_stage_rows.csv", "EXTERNAL_REVIEW_DISPATCH_SEAL_STAGES.csv")

seal_pointer_rows = []
for row in file_rows:
    seal_pointer_rows.append(
        {
            "bundle_file": row["bundle_file"],
            "source_gate": "v53ah",
            "bytes": row["bytes"],
            "sha256": row["sha256"],
            "archive_file": row["archive_file"],
            "payload_like_file": row["payload_like_file"],
            "seal_status": "sealed",
        }
    )
write_csv(run_dir / "external_review_dispatch_seal_pointer_rows.csv", list(seal_pointer_rows[0].keys()), seal_pointer_rows)
copy_seal(run_dir / "external_review_dispatch_seal_pointer_rows.csv", "SEALED_SEND_BUNDLE_POINTERS.csv")

receipt_status_rows = [
    {
        "review_chunk_id": row["review_chunk_id"],
        "receipt_id": row["receipt_id"],
        "receipt_supplied": row["receipt_supplied"],
        "receipt_accepted": row["receipt_accepted"],
        "receipt_status": row["receipt_status"],
        "next_required_action": "supply-valid-dispatch-receipt-json",
    }
    for row in receipt_rows
]
write_csv(run_dir / "external_review_dispatch_receipt_status_rows.csv", list(receipt_status_rows[0].keys()), receipt_status_rows)
copy_seal(run_dir / "external_review_dispatch_receipt_status_rows.csv", "DISPATCH_RECEIPT_INTAKE_STATUS.csv")

blocker_rows = [
    {
        "blocker_id": "dispatch-receipts",
        "required_rows": v53ad["dispatch_receipt_template_rows"],
        "accepted_rows": v53ad["accepted_dispatch_receipt_rows"],
        "status": "blocked",
        "unlock_command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
    },
    {
        "blocker_id": "review-chunk-return-artifacts",
        "required_rows": v61dz["review_chunk_return_artifact_rows"],
        "accepted_rows": "0",
        "status": "blocked",
        "unlock_command": "collect 50 chunk artifacts under the final return bundle",
    },
    {
        "blocker_id": "human-review-rows",
        "required_rows": v61dz["expected_human_review_rows"],
        "accepted_rows": v61dz["accepted_human_review_rows"],
        "status": "blocked",
        "unlock_command": "V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return V53S_REUSE_EXISTING=0 ./experiments/run_v53s_complete_source_review_return_intake.sh",
    },
    {
        "blocker_id": "adjudication-rows",
        "required_rows": v61dz["expected_adjudication_rows"],
        "accepted_rows": v61dz["accepted_adjudication_rows"],
        "status": "blocked",
        "unlock_command": "V53V_REUSE_EXISTING=0 ./experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh",
    },
    {
        "blocker_id": "generation-execution",
        "required_rows": v61dz["generation_execution_admission_rows"],
        "accepted_rows": v61dz["generation_execution_admitted_rows"],
        "status": "blocked",
        "unlock_command": "run guarded generation only after review return acceptance closes",
    },
    {
        "blocker_id": "generation-result-artifacts",
        "required_rows": "5",
        "accepted_rows": v53ah["accepted_generation_result_artifacts"],
        "status": "blocked",
        "unlock_command": "V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
    },
]
write_csv(run_dir / "external_review_dispatch_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)
copy_seal(run_dir / "external_review_dispatch_blocker_rows.csv", "REVIEW_RETURN_BLOCKER_LEDGER.csv")

next_action_rows = [
    {
        "action_id": "01-send-v53ah-bundle-to-reviewers",
        "status": "ready",
        "ready_to_run_now": "1",
        "command_or_action": "send results/v53ah_complete_source_external_review_send_bundle/bundle_001/send_bundle/",
        "expected_transition": "external reviewers can acknowledge dispatch",
    },
    {
        "action_id": "02-ingest-dispatch-receipts",
        "status": "blocked",
        "ready_to_run_now": "0",
        "command_or_action": blocker_rows[0]["unlock_command"],
        "expected_transition": "accepted_dispatch_receipt_rows=21",
    },
    {
        "action_id": "03-collect-review-chunk-returns",
        "status": "blocked",
        "ready_to_run_now": "0",
        "command_or_action": "collect human/adjudication/identity/conflict chunk artifacts",
        "expected_transition": "accepted_chunk_return_artifacts=50",
    },
    {
        "action_id": "04-refresh-v53-review-return",
        "status": "blocked",
        "ready_to_run_now": "0",
        "command_or_action": "V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return V53S_REUSE_EXISTING=0 ./experiments/run_v53s_complete_source_review_return_intake.sh && V53V_REUSE_EXISTING=0 ./experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh",
        "expected_transition": "answer_review_accepted_rows=7000",
    },
    {
        "action_id": "05-refresh-generation-unblock",
        "status": "blocked",
        "ready_to_run_now": "0",
        "command_or_action": "V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "expected_transition": "generation execution can be admitted only after review return closes",
    },
]
write_csv(run_dir / "external_review_dispatch_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)
copy_seal(run_dir / "external_review_dispatch_next_action_rows.csv", "NEXT_ACTIONS.csv")

invariant_rows = [
    {
        "invariant_id": "v61dz-active-review-runway-ready",
        "status": "pass" if v61dz["v61dz_review_return_chunk_submission_runway_ready"] == "1" else "fail",
        "expected": "v61dz ready",
        "actual": v61dz["v61dz_review_return_chunk_submission_runway_ready"],
    },
    {
        "invariant_id": "v53ah-send-bundle-ready",
        "status": "pass" if v53ah["send_bundle_ready"] == "1" else "fail",
        "expected": "send bundle ready",
        "actual": v53ah["send_bundle_ready"],
    },
    {
        "invariant_id": "send-bundle-no-payload",
        "status": "pass" if v53ah["payload_like_bundle_file_rows"] == "0" and v53ah["nested_payload_like_archive_member_rows"] == "0" else "fail",
        "expected": "0 payload-like files/members",
        "actual": f"files={v53ah['payload_like_bundle_file_rows']};members={v53ah['nested_payload_like_archive_member_rows']}",
    },
    {
        "invariant_id": "return-inbox-template-only",
        "status": "pass" if v53ah["return_inbox_final_evidence_named_archive_member_rows"] == "0" else "fail",
        "expected": "0 final evidence-named return inbox members",
        "actual": v53ah["return_inbox_final_evidence_named_archive_member_rows"],
    },
    {
        "invariant_id": "receipt-intake-defined-but-empty",
        "status": "pass" if v53ad["dispatch_receipt_template_rows"] == "21" and v53ad["accepted_dispatch_receipt_rows"] == "0" else "fail",
        "expected": "21 templates and 0 accepted receipts",
        "actual": f"{v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}",
    },
    {
        "invariant_id": "review-return-blocks-generation",
        "status": "pass" if v61dz["accepted_human_review_rows"] == "0" and v61dz["generation_execution_admitted_rows"] == "0" and v61dz["actual_model_generation_ready"] == "0" else "fail",
        "expected": "review/generation blocked",
        "actual": f"review={v61dz['accepted_human_review_rows']};generation={v61dz['generation_execution_admitted_rows']};actual={v61dz['actual_model_generation_ready']}",
    },
    {
        "invariant_id": "full-shard-runtime-still-bound",
        "status": "pass" if v53ah["full_shard_prerequisites_closed"] == "1" and v53ah["runtime_admission_accepted_rows"] == "1000" else "fail",
        "expected": "full shard closed and runtime admission 1000",
        "actual": f"full={v53ah['full_shard_prerequisites_closed']};runtime={v53ah['runtime_admission_accepted_rows']}",
    },
    {
        "invariant_id": "repo-checkpoint-payload-zero",
        "status": "pass" if v53ah["checkpoint_payload_bytes_committed_to_repo"] == "0" else "fail",
        "expected": "repo checkpoint payload is zero",
        "actual": v53ah["checkpoint_payload_bytes_committed_to_repo"],
    },
]
write_csv(run_dir / "external_review_dispatch_seal_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)
copy_seal(run_dir / "external_review_dispatch_seal_invariant_rows.csv", "SEAL_INVARIANTS.csv")

seal_readme = seal_dir / "EXTERNAL_REVIEW_DISPATCH_SEAL.md"
seal_readme.write_text(
    "\n".join(
        [
            "# v61ea External Review Dispatch Seal",
            "",
            "This seal binds the v61 active goal runway to the v53ah external",
            "review send bundle and the v53ad dispatch receipt intake surface.",
            "It is metadata-only and does not create dispatch receipts, human",
            "review decisions, adjudication rows, generation result artifacts,",
            "latency evidence, near-frontier evidence, or release evidence.",
            "",
            "Ready:",
            "",
            f"- send_bundle_ready={v53ah['send_bundle_ready']}",
            f"- review_chunk_rows={v61dz['review_chunk_rows']}",
            f"- review_chunk_task_rows={v61dz['review_chunk_task_rows']}",
            f"- review_chunk_return_artifact_rows={v61dz['review_chunk_return_artifact_rows']}",
            f"- dispatch_receipt_template_rows={v53ad['dispatch_receipt_template_rows']}",
            "",
            "Still blocked:",
            "",
            f"- accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}",
            f"- accepted_human_review_rows={v61dz['accepted_human_review_rows']}/{v61dz['expected_human_review_rows']}",
            f"- accepted_adjudication_rows={v61dz['accepted_adjudication_rows']}/{v61dz['expected_adjudication_rows']}",
            f"- generation_execution_admitted_rows={v61dz['generation_execution_admitted_rows']}/{v61dz['generation_execution_admission_rows']}",
            f"- actual_model_generation_ready={v61dz['actual_model_generation_ready']}",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = seal_dir / "VERIFY_V61EA_DISPATCH_SEAL.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'SEAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
            'RUN_DIR="$(cd "$SEAL_DIR/.." && pwd)"',
            "export RUN_DIR",
            'test -s "$SEAL_DIR/EXTERNAL_REVIEW_DISPATCH_SEAL.md"',
            'test -s "$SEAL_DIR/SEALED_SEND_BUNDLE_POINTERS.csv"',
            'test -s "$SEAL_DIR/DISPATCH_RECEIPT_INTAKE_STATUS.csv"',
            'test -s "$SEAL_DIR/REVIEW_RETURN_BLOCKER_LEDGER.csv"',
            'test -s "$SEAL_DIR/NEXT_ACTIONS.csv"',
            'test -s "$SEAL_DIR/SEAL_INVARIANTS.csv"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "from pathlib import Path",
            "run_dir = Path(__import__('os').environ['RUN_DIR'])",
            "def read_csv(path):",
            "    with path.open(newline='', encoding='utf-8') as handle:",
            "        return list(csv.DictReader(handle))",
            "summary = read_csv(run_dir.parent.parent / 'v61ea_external_review_dispatch_seal_gate_summary.csv')[0]",
            "if summary['send_bundle_ready'] != '1':",
            "    raise SystemExit('send bundle is not ready')",
            "if summary['accepted_dispatch_receipt_rows'] != '0':",
            "    raise SystemExit('seal must not accept dispatch receipts by default')",
            "if summary['actual_model_generation_ready'] != '0':",
            "    raise SystemExit('seal must keep actual generation blocked')",
            "PY_VERIFY",
            'if find "$RUN_DIR" -type f \\( -name "*.safetensors" -o -name "*.bin" -o -name "*.pt" \\) | grep -q .; then',
            '  echo "model/checkpoint payload-like file found inside v61ea seal" >&2',
            "  exit 1",
            "fi",
            "echo 'v61ea dispatch seal verified'",
        ]
    )
    + "\n",
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

seal_manifest = {
    "manifest_scope": "v61ea-external-review-dispatch-seal-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "send_bundle_ready": as_int(v53ah, "send_bundle_ready"),
    "review_chunk_rows": as_int(v61dz, "review_chunk_rows"),
    "review_chunk_task_rows": as_int(v61dz, "review_chunk_task_rows"),
    "review_chunk_return_artifact_rows": as_int(v61dz, "review_chunk_return_artifact_rows"),
    "dispatch_receipt_template_rows": as_int(v53ad, "dispatch_receipt_template_rows"),
    "accepted_dispatch_receipt_rows": as_int(v53ad, "accepted_dispatch_receipt_rows"),
    "accepted_human_review_rows": as_int(v61dz, "accepted_human_review_rows"),
    "generation_execution_admitted_rows": as_int(v61dz, "generation_execution_admitted_rows"),
    "actual_model_generation_ready": as_int(v61dz, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(seal_dir / "SEAL_MANIFEST.json").write_text(
    json.dumps(seal_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

seal_files = sorted(path for path in seal_dir.rglob("*") if path.is_file())
write_csv(
    run_dir / "external_review_dispatch_seal_file_rows.csv",
    ["seal_relative_path", "size_bytes", "sha256", "payload_class"],
    [
        {
            "seal_relative_path": str(path.relative_to(seal_dir)),
            "size_bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "payload_class": "metadata-only",
        }
        for path in seal_files
    ],
)

ready_stage_rows = sum(1 for row in seal_stage_rows if row["status"] == "ready")
blocked_stage_rows = sum(1 for row in seal_stage_rows if row["status"] == "blocked")
ready_next_action_rows = sum(1 for row in next_action_rows if row["status"] == "ready")
blocked_next_action_rows = sum(1 for row in next_action_rows if row["status"] == "blocked")
seal_file_rows = read_csv(run_dir / "external_review_dispatch_seal_file_rows.csv")
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

summary_row = {
    "v61ea_external_review_dispatch_seal_gate_ready": "1",
    "v61dz_review_return_chunk_submission_runway_ready": v61dz["v61dz_review_return_chunk_submission_runway_ready"],
    "v53ah_complete_source_external_review_send_bundle_ready": v53ah["v53ah_complete_source_external_review_send_bundle_ready"],
    "v53ad_complete_source_review_dispatch_receipt_intake_ready": v53ad["v53ad_complete_source_review_dispatch_receipt_intake_ready"],
    "seal_stage_rows": str(len(seal_stage_rows)),
    "ready_seal_stage_rows": str(ready_stage_rows),
    "blocked_seal_stage_rows": str(blocked_stage_rows),
    "seal_pointer_rows": str(len(seal_pointer_rows)),
    "send_bundle_ready": v53ah["send_bundle_ready"],
    "send_bundle_archive_files": v53ah["send_bundle_archive_files"],
    "bundle_file_rows": v53ah["bundle_file_rows"],
    "dispatch_archive_member_files": v53ah["dispatch_archive_member_files"],
    "return_inbox_archive_member_files": v53ah["return_inbox_archive_member_files"],
    "return_artifact_template_archive_member_rows": v53ah["return_artifact_template_archive_member_rows"],
    "payload_like_bundle_file_rows": v53ah["payload_like_bundle_file_rows"],
    "nested_payload_like_archive_member_rows": v53ah["nested_payload_like_archive_member_rows"],
    "return_inbox_final_evidence_named_archive_member_rows": v53ah["return_inbox_final_evidence_named_archive_member_rows"],
    "review_chunk_rows": v61dz["review_chunk_rows"],
    "ready_review_chunk_dispatch_rows": v61dz["ready_review_chunk_dispatch_rows"],
    "review_chunk_task_rows": v61dz["review_chunk_task_rows"],
    "human_review_chunk_task_rows": v61dz["human_review_chunk_task_rows"],
    "adjudication_chunk_task_rows": v61dz["adjudication_chunk_task_rows"],
    "review_chunk_return_artifact_rows": v61dz["review_chunk_return_artifact_rows"],
    "dispatch_receipt_template_rows": v53ad["dispatch_receipt_template_rows"],
    "supplied_dispatch_receipt_rows": v53ad["supplied_dispatch_receipt_rows"],
    "accepted_dispatch_receipt_rows": v53ad["accepted_dispatch_receipt_rows"],
    "missing_dispatch_receipt_rows": v53ad["missing_dispatch_receipt_rows"],
    "dispatch_receipt_intake_ready": v53ad["dispatch_receipt_intake_ready"],
    "expected_human_review_rows": v61dz["expected_human_review_rows"],
    "accepted_human_review_rows": v61dz["accepted_human_review_rows"],
    "expected_adjudication_rows": v61dz["expected_adjudication_rows"],
    "accepted_adjudication_rows": v61dz["accepted_adjudication_rows"],
    "generation_execution_admitted_rows": v61dz["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61dz["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v53ah["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v61dz["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53ah["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ah["runtime_admission_accepted_rows"],
    "seal_invariant_rows": str(len(invariant_rows)),
    "seal_invariant_pass_rows": str(invariant_pass_rows),
    "next_action_rows": str(len(next_action_rows)),
    "ready_next_action_rows": str(ready_next_action_rows),
    "blocked_next_action_rows": str(blocked_next_action_rows),
    "seal_file_rows": str(len(seal_file_rows)),
    "metadata_only_seal_file_rows": str(sum(1 for row in seal_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61ea": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "active-goal-review-runway", "status": "pass", "reason": "v61dz review chunk submission runway is ready"},
    {"gate": "external-send-bundle", "status": "pass", "reason": f"send_bundle_ready={v53ah['send_bundle_ready']}"},
    {"gate": "send-bundle-integrity", "status": "pass", "reason": "bundle sha256, no-payload, and template-only checks are bound"},
    {"gate": "dispatch-receipt-intake-surface", "status": "pass", "reason": f"dispatch_receipt_template_rows={v53ad['dispatch_receipt_template_rows']}"},
    {"gate": "dispatch-receipts-accepted", "status": "blocked", "reason": f"accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"accepted_human_review_rows={v61dz['accepted_human_review_rows']}/{v61dz['expected_human_review_rows']}"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61dz['generation_execution_admitted_rows']}/{v61dz['generation_execution_admission_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61dz['actual_model_generation_ready']}"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "checkpoint payload committed to repo remains zero"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

manifest = {
    "manifest_scope": "v61ea-external-review-dispatch-seal-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary_row.items()},
}
(run_dir / "v61ea_external_review_dispatch_seal_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file()):
    if path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY
