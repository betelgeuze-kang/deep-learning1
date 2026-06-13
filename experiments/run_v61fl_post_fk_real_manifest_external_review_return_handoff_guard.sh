#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fl_post_fk_real_manifest_external_review_return_handoff_guard"
RUN_ID="${V61FL_RUN_ID:-guard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
DISPATCH_RUN_DIR_ARG="${V61FL_DISPATCH_RUN_DIR:-}"
RETURN_INTAKE_RUN_DIR_ARG="${V61FL_RETURN_INTAKE_RUN_DIR:-}"

if [[ "${V61FL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$DISPATCH_RUN_DIR_ARG" "$RETURN_INTAKE_RUN_DIR_ARG" <<'PY'
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
dispatch_arg = sys.argv[5].strip()
return_arg = sys.argv[6].strip()
results = root / "results"
default_dispatch_dir = results / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate" / "dispatch_001"
default_return_dir = results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001"
dispatch_dir = Path(dispatch_arg).expanduser().resolve() if dispatch_arg else default_dispatch_dir
return_dir = Path(return_arg).expanduser().resolve() if return_arg else default_return_dir


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


def ready(flag):
    return "ready" if flag else "blocked"


sources = {
    "v61fk_summary": results / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_summary.csv",
    "v61fk_decision": results / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_decision.csv",
    "v61fh_summary": results / "v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
    "v61fh_decision": results / "v61fh_post_fg_real_manifest_external_review_return_intake_decision.csv",
    "v61fi_summary": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_summary.csv",
    "v61fi_decision": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fl source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_dispatch_files = {
    "dispatch_metric_rows.csv": dispatch_dir / "post_fj_real_manifest_external_review_dispatch_receipt_metric_rows.csv",
    "dispatch_check_rows.csv": dispatch_dir / "post_fj_real_manifest_external_review_dispatch_receipt_preflight_check_rows.csv",
    "dispatch_command_rows.csv": dispatch_dir / "post_fj_real_manifest_external_review_dispatch_command_rows.csv",
    "dispatch_manifest.json": dispatch_dir / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_manifest.json",
}
for rel, path in selected_dispatch_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61fl dispatch artifact: {path}")
    copy(path, f"selected_dispatch/{rel}")

selected_return_files = {
    "review_return_artifact_status_rows.csv": return_dir / "real_manifest_external_review_return_artifact_status_rows.csv",
    "review_return_acceptance_rows.csv": return_dir / "real_manifest_external_review_return_acceptance_rows.csv",
    "review_return_requirement_rows.csv": return_dir / "real_manifest_external_review_return_requirement_rows.csv",
    "review_return_manifest.json": return_dir / "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json",
}
for rel, path in selected_return_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61fl return artifact: {path}")
    copy(path, f"selected_review_return/{rel}")

v61fk = read_csv(sources["v61fk_summary"])[0]
v61fh = read_csv(sources["v61fh_summary"])[0]
v61fi = read_csv(sources["v61fi_summary"])[0]
if v61fk.get("v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready") != "1":
    raise SystemExit("v61fl requires v61fk readiness")
if v61fh.get("v61fh_post_fg_real_manifest_external_review_return_intake_ready") != "1":
    raise SystemExit("v61fl requires v61fh readiness")
if v61fi.get("v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready") != "1":
    raise SystemExit("v61fl requires v61fi readiness")

dispatch_metric = read_csv(dispatch_dir / "post_fj_real_manifest_external_review_dispatch_receipt_metric_rows.csv")[0]
return_status_rows = read_csv(return_dir / "real_manifest_external_review_return_artifact_status_rows.csv")
fi_blocker_rows = read_csv(results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge" / "bridge_001" / "post_fh_real_manifest_external_review_acceptance_blocker_rows.csv")
copy(results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge" / "bridge_001" / "post_fh_real_manifest_external_review_acceptance_bridge_rows.csv", "source_v61fi/post_fh_real_manifest_external_review_acceptance_bridge_rows.csv")
copy(results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge" / "bridge_001" / "post_fh_real_manifest_external_review_acceptance_blocker_rows.csv", "source_v61fi/post_fh_real_manifest_external_review_acceptance_blocker_rows.csv")

dispatch_archive_ready = as_int(dispatch_metric, "dispatch_archive_ready")
dispatch_receipt_candidate_ready = as_int(dispatch_metric, "dispatch_receipt_candidate_preflight_ready")
real_dispatch_receipt_ready = as_int(dispatch_metric, "real_dispatch_receipt_ready")
accepted_dispatch_receipt_rows = as_int(dispatch_metric, "accepted_dispatch_receipt_rows")
candidate_external_review_return_ready = as_int(v61fh, "candidate_external_review_return_ready")
external_review_return_ready = as_int(v61fi, "external_review_return_ready")
real_return_replay_admission_ready = as_int(v61fi, "real_return_replay_admission_ready")
row_acceptance_ready = as_int(v61fi, "row_acceptance_ready")
receipt_to_review_return_handoff_ready = int(real_dispatch_receipt_ready and external_review_return_ready)
review_return_intake_contract_ready = 1
actual_model_generation_ready = 0

stage_rows = [
    {
        "stage_id": "01-dispatch-archive",
        "status": ready(dispatch_archive_ready),
        "ready": str(dispatch_archive_ready),
        "actual_value": f"dispatch_archive_ready={dispatch_archive_ready}",
        "blocking_reason": "" if dispatch_archive_ready else "v61fk dispatch archive is not ready",
    },
    {
        "stage_id": "02-dispatch-receipt-candidate",
        "status": ready(dispatch_receipt_candidate_ready),
        "ready": str(dispatch_receipt_candidate_ready),
        "actual_value": f"candidate={dispatch_receipt_candidate_ready}; class={dispatch_metric['selected_receipt_source_class']}",
        "blocking_reason": "" if dispatch_receipt_candidate_ready else "no dispatch receipt candidate passed v61fk preflight",
    },
    {
        "stage_id": "03-real-dispatch-receipt",
        "status": ready(real_dispatch_receipt_ready),
        "ready": str(real_dispatch_receipt_ready),
        "actual_value": f"real_dispatch_receipt_ready={real_dispatch_receipt_ready}; accepted_rows={accepted_dispatch_receipt_rows}",
        "blocking_reason": "" if real_dispatch_receipt_ready else "requires non-fixture receipt with real-external-dispatch provenance",
    },
    {
        "stage_id": "04-review-return-intake-contract",
        "status": "ready",
        "ready": "1",
        "actual_value": f"required_review_return_artifacts={v61fh['required_review_return_artifacts']}",
        "blocking_reason": "",
    },
    {
        "stage_id": "05-review-return-candidate",
        "status": ready(candidate_external_review_return_ready),
        "ready": str(candidate_external_review_return_ready),
        "actual_value": f"candidate_external_review_return_ready={candidate_external_review_return_ready}",
        "blocking_reason": "" if candidate_external_review_return_ready else "no review-return root passed intake preflight",
    },
    {
        "stage_id": "06-external-review-return-accepted",
        "status": ready(external_review_return_ready),
        "ready": str(external_review_return_ready),
        "actual_value": f"external_review_return_ready={external_review_return_ready}",
        "blocking_reason": "" if external_review_return_ready else "real external review return not accepted",
    },
    {
        "stage_id": "07-receipt-to-review-return-handoff",
        "status": ready(receipt_to_review_return_handoff_ready),
        "ready": str(receipt_to_review_return_handoff_ready),
        "actual_value": f"real_receipt={real_dispatch_receipt_ready}; external_review_return={external_review_return_ready}",
        "blocking_reason": "" if receipt_to_review_return_handoff_ready else "dispatch receipt and review-return evidence are separate gates",
    },
    {
        "stage_id": "08-replay-row-acceptance",
        "status": ready(real_return_replay_admission_ready and row_acceptance_ready),
        "ready": str(int(real_return_replay_admission_ready and row_acceptance_ready)),
        "actual_value": f"real_return_replay_admission_ready={real_return_replay_admission_ready}; row_acceptance_ready={row_acceptance_ready}",
        "blocking_reason": "requires accepted review return before replay and row acceptance",
    },
    {
        "stage_id": "09-actual-generation",
        "status": "blocked",
        "ready": "0",
        "actual_value": "actual_model_generation_ready=0",
        "blocking_reason": "handoff guard does not run or accept generation",
    },
]
write_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "v61fk-dispatch-archive", "status": status(dispatch_archive_ready), "required_value": "1", "actual_value": str(dispatch_archive_ready), "reason": "dispatch archive must be sealed"},
    {"requirement_id": "dispatch-receipt-candidate", "status": status(dispatch_receipt_candidate_ready), "required_value": "1", "actual_value": str(dispatch_receipt_candidate_ready), "reason": "receipt candidate may be supplied but is not review evidence"},
    {"requirement_id": "real-dispatch-receipt", "status": status(real_dispatch_receipt_ready), "required_value": "1", "actual_value": str(real_dispatch_receipt_ready), "reason": "fixture receipts do not count"},
    {"requirement_id": "v61fh-review-return-intake-contract", "status": "pass", "required_value": "1", "actual_value": "1", "reason": "review-return intake contract exists"},
    {"requirement_id": "external-review-return", "status": status(external_review_return_ready), "required_value": "1", "actual_value": str(external_review_return_ready), "reason": "real review-return evidence must be supplied and accepted"},
    {"requirement_id": "receipt-to-review-return-handoff", "status": status(receipt_to_review_return_handoff_ready), "required_value": "1", "actual_value": str(receipt_to_review_return_handoff_ready), "reason": "requires real receipt plus accepted review return"},
    {"requirement_id": "replay-row-acceptance", "status": status(real_return_replay_admission_ready and row_acceptance_ready), "required_value": "1", "actual_value": str(int(real_return_replay_admission_ready and row_acceptance_ready)), "reason": "review return must close before replay"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
    {"requirement_id": "repo-checkpoint-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "metadata-only handoff guard"},
]
write_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

blocker_rows = [
    {
        "blocker_id": "dispatch-receipt-real-provenance",
        "source_family": "v61fk",
        "status": "closed" if real_dispatch_receipt_ready else "open",
        "reason": "requires non-fixture DISPATCH_RECEIPT.json with real-external-dispatch provenance",
        "unblocked_by_dispatch_receipt_alone": str(real_dispatch_receipt_ready),
    },
    {
        "blocker_id": "external-review-return-artifacts",
        "source_family": "v61fh",
        "status": "closed" if external_review_return_ready else "open",
        "reason": f"accepted_review_return_artifacts={v61fh['accepted_review_return_artifacts']}/{v61fh['required_review_return_artifacts']}",
        "unblocked_by_dispatch_receipt_alone": "0",
    },
]
for row in fi_blocker_rows:
    blocker_rows.append(
        {
            "blocker_id": row.get("blocker_id", row.get("bridge_id", "v61fi-blocker")),
            "source_family": "v61fi",
            "status": "open" if row.get("status", "blocked") == "blocked" else "closed",
            "reason": row.get("reason", ""),
            "unblocked_by_dispatch_receipt_alone": "0",
        }
    )
write_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

command_rows = [
    {
        "command_id": "verify-dispatch-archive-receipt-gate",
        "command": "V61FK_REUSE_EXISTING=1 ./experiments/test_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh",
        "ready_to_run_now": "1",
        "purpose": "verify dispatch archive and receipt mechanics",
    },
    {
        "command_id": "verify-review-return-intake-contract",
        "command": "V61FH_REUSE_EXISTING=1 ./experiments/test_v61fh_post_fg_real_manifest_external_review_return_intake.sh",
        "ready_to_run_now": "1",
        "purpose": "verify review-return intake contract",
    },
    {
        "command_id": "supply-real-review-return",
        "command": "V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/real/review-return ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh",
        "ready_to_run_now": str(real_dispatch_receipt_ready),
        "purpose": "receipt may precede but cannot replace review-return evidence",
    },
    {
        "command_id": "refresh-review-acceptance-bridge",
        "command": "./experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh",
        "ready_to_run_now": str(external_review_return_ready),
        "purpose": "refresh acceptance bridge after real review return is accepted",
    },
    {
        "command_id": "replay-real-return-chain",
        "command": "./experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh",
        "ready_to_run_now": str(real_return_replay_admission_ready),
        "purpose": "only after accepted review return and replay admission",
    },
]
write_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

runtime_gap_rows = [
    {"gap": "dispatch-archive", "status": ready(dispatch_archive_ready), "reason": f"dispatch_archive_member_files={dispatch_metric['dispatch_archive_member_files']}"},
    {"gap": "dispatch-receipt-candidate", "status": ready(dispatch_receipt_candidate_ready), "reason": "optional receipt preflight"},
    {"gap": "real-dispatch-receipt", "status": ready(real_dispatch_receipt_ready), "reason": "requires real-external-dispatch provenance"},
    {"gap": "external-review-return", "status": ready(external_review_return_ready), "reason": "requires accepted v61fh/v61fi return evidence"},
    {"gap": "receipt-to-review-return-handoff", "status": ready(receipt_to_review_return_handoff_ready), "reason": "receipt and review return must both be real"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
open_blocker_rows = sum(row["status"] == "open" for row in blocker_rows)
summary = {
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": "1",
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready": v61fk["v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready"],
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": v61fh["v61fh_post_fg_real_manifest_external_review_return_intake_ready"],
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": v61fi["v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready"],
    "selected_dispatch_source_class": dispatch_metric["selected_receipt_source_class"],
    "dispatch_archive_ready": str(dispatch_archive_ready),
    "dispatch_archive_member_files": dispatch_metric["dispatch_archive_member_files"],
    "dispatch_receipt_candidate_preflight_ready": str(dispatch_receipt_candidate_ready),
    "real_dispatch_receipt_ready": str(real_dispatch_receipt_ready),
    "accepted_dispatch_receipt_rows": str(accepted_dispatch_receipt_rows),
    "review_return_intake_contract_ready": str(review_return_intake_contract_ready),
    "required_review_return_artifacts": v61fh["required_review_return_artifacts"],
    "accepted_review_return_artifacts": v61fh["accepted_review_return_artifacts"],
    "missing_review_return_artifacts": v61fh["missing_review_return_artifacts"],
    "candidate_external_review_return_ready": str(candidate_external_review_return_ready),
    "external_review_return_ready": str(external_review_return_ready),
    "receipt_to_review_return_handoff_ready": str(receipt_to_review_return_handoff_ready),
    "real_return_replay_admission_ready": str(real_return_replay_admission_ready),
    "row_acceptance_ready": str(row_acceptance_ready),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(ready_stage_rows),
    "blocked_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "blocker_rows": str(len(blocker_rows)),
    "open_blocker_rows": str(open_blocker_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "blocked_command_rows": str(len(command_rows) - ready_command_rows),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv", list(summary.keys()), [summary])
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["requirement_id"], "status": row["status"], "reason": row["reason"]}
    for row in requirement_rows
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FL_POST_FK_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_HANDOFF_GUARD_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fl Post-v61fk Real Manifest External Review Return Handoff Guard Boundary",
            "",
            f"- dispatch_archive_ready={summary['dispatch_archive_ready']}",
            f"- dispatch_receipt_candidate_preflight_ready={summary['dispatch_receipt_candidate_preflight_ready']}",
            f"- real_dispatch_receipt_ready={summary['real_dispatch_receipt_ready']}",
            f"- review_return_intake_contract_ready={summary['review_return_intake_contract_ready']}",
            f"- required_review_return_artifacts={summary['required_review_return_artifacts']}",
            f"- accepted_review_return_artifacts={summary['accepted_review_return_artifacts']}/{summary['required_review_return_artifacts']}",
            f"- candidate_external_review_return_ready={summary['candidate_external_review_return_ready']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- receipt_to_review_return_handoff_ready={summary['receipt_to_review_return_handoff_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fl proves dispatch logistics and review-return acceptance remain separate gates.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fl alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61fl_post_fk_real_manifest_external_review_return_handoff_guard",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
