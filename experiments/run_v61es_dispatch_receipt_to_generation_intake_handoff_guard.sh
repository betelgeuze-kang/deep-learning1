#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61es_dispatch_receipt_to_generation_intake_handoff_guard"
RUN_ID="${V61ES_RUN_ID:-guard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RECEIPT_PREFLIGHT_RUN_DIR_ARG="${V61ES_RECEIPT_PREFLIGHT_RUN_DIR:-}"
WORK_ORDER_RUN_DIR_ARG="${V61ES_WORK_ORDER_RUN_DIR:-}"

if [[ "${V61ES_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61es_dispatch_receipt_to_generation_intake_handoff_guard_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61ER_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null
V61EN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null
V61EM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RECEIPT_PREFLIGHT_RUN_DIR_ARG" "$WORK_ORDER_RUN_DIR_ARG" <<'PY'
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
work_order_arg = sys.argv[6].strip()
results = root / "results"
default_receipt_dir = results / "v61er_real_generation_intake_dispatch_receipt_preflight" / "preflight_001"
default_work_order_dir = results / "v61en_real_generation_intake_work_order" / "work_order_001"
receipt_dir = Path(receipt_arg).expanduser().resolve() if receipt_arg else default_receipt_dir
work_order_dir = Path(work_order_arg).expanduser().resolve() if work_order_arg else default_work_order_dir


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


summary_paths = {
    "v61er_summary": results / "v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv",
    "v61er_decision": results / "v61er_real_generation_intake_dispatch_receipt_preflight_decision.csv",
    "v61en_summary": results / "v61en_real_generation_intake_work_order_summary.csv",
    "v61en_decision": results / "v61en_real_generation_intake_work_order_decision.csv",
    "v61em_summary": results / "v61em_generation_intake_dual_preflight_rendezvous_summary.csv",
    "v61em_decision": results / "v61em_generation_intake_dual_preflight_rendezvous_decision.csv",
}
for key, path in summary_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61es source {key}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_files = {
    "receipt_preflight_metric_rows.csv": receipt_dir / "real_generation_intake_dispatch_receipt_preflight_metric_rows.csv",
    "receipt_preflight_check_rows.csv": receipt_dir / "real_generation_intake_dispatch_receipt_preflight_check_rows.csv",
    "receipt_command_rows.csv": receipt_dir / "real_generation_intake_dispatch_receipt_command_rows.csv",
    "receipt_manifest.json": receipt_dir / "v61er_real_generation_intake_dispatch_receipt_preflight_manifest.json",
    "work_order_rows.csv": work_order_dir / "real_generation_intake_work_order_rows.csv",
    "work_order_command_rows.csv": work_order_dir / "real_generation_intake_command_rows.csv",
    "work_order_blocker_rows.csv": work_order_dir / "real_generation_intake_blocker_rows.csv",
    "work_order_manifest.json": work_order_dir / "v61en_real_generation_intake_work_order_manifest.json",
}
for rel, path in selected_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61es artifact: {path}")
    prefix = "selected_receipt_preflight" if rel.startswith("receipt") else "selected_work_order"
    copy(path, f"{prefix}/{rel}")

v61er_summary = read_csv(summary_paths["v61er_summary"])[0]
v61en_summary = read_csv(summary_paths["v61en_summary"])[0]
v61em_summary = read_csv(summary_paths["v61em_summary"])[0]
if v61er_summary.get("v61er_real_generation_intake_dispatch_receipt_preflight_ready") != "1":
    raise SystemExit("v61es requires v61er readiness")
if v61en_summary.get("v61en_real_generation_intake_work_order_ready") != "1":
    raise SystemExit("v61es requires v61en readiness")
if v61em_summary.get("v61em_generation_intake_dual_preflight_rendezvous_ready") != "1":
    raise SystemExit("v61es requires v61em readiness")

receipt_metric = read_csv(receipt_dir / "real_generation_intake_dispatch_receipt_preflight_metric_rows.csv")[0]
work_rows = read_csv(work_order_dir / "real_generation_intake_work_order_rows.csv")
blocker_rows = read_csv(work_order_dir / "real_generation_intake_blocker_rows.csv")
work_rows_by_id = {row["work_item_id"]: row for row in work_rows}

receipt_candidate_ready = as_int(receipt_metric, "dispatch_receipt_candidate_preflight_ready")
real_dispatch_receipt_ready = as_int(receipt_metric, "real_dispatch_receipt_ready")
accepted_dispatch_receipt_rows = as_int(receipt_metric, "accepted_dispatch_receipt_rows")
real_generation_intake_handoff_ready = as_int(work_rows_by_id["08-real-generation-intake-handoff"], "ready")
dual_candidate_ready = as_int(work_rows_by_id["07-dual-candidate-rendezvous"], "ready")
ready_work_order_rows = sum(row["ready"] == "1" for row in work_rows)
open_blocker_rows = sum(row["blocked"] == "1" for row in blocker_rows)
receipt_to_intake_handoff_ready = int(real_dispatch_receipt_ready and real_generation_intake_handoff_ready)
actual_model_generation_ready = 0

stage_rows = [
    {
        "stage_id": "01-v61er-receipt-preflight-surface",
        "status": "ready",
        "ready": "1",
        "actual_value": "v61er_real_generation_intake_dispatch_receipt_preflight_ready=1",
        "blocking_reason": "",
    },
    {
        "stage_id": "02-dispatch-receipt-candidate",
        "status": ready(receipt_candidate_ready),
        "ready": str(receipt_candidate_ready),
        "actual_value": f"candidate={receipt_candidate_ready}; class={receipt_metric['selected_receipt_source_class']}",
        "blocking_reason": "" if receipt_candidate_ready else "no returned receipt candidate passed preflight",
    },
    {
        "stage_id": "03-real-dispatch-receipt",
        "status": ready(real_dispatch_receipt_ready),
        "ready": str(real_dispatch_receipt_ready),
        "actual_value": f"real_receipt={real_dispatch_receipt_ready}; accepted_rows={accepted_dispatch_receipt_rows}",
        "blocking_reason": "" if real_dispatch_receipt_ready else "requires non-fixture receipt and real-external-dispatch provenance",
    },
    {
        "stage_id": "04-v61en-intake-work-order",
        "status": "ready",
        "ready": "1",
        "actual_value": f"ready_work_order_rows={ready_work_order_rows}; open_blocker_rows={open_blocker_rows}",
        "blocking_reason": "",
    },
    {
        "stage_id": "05-dual-candidate-generation-intake",
        "status": ready(dual_candidate_ready),
        "ready": str(dual_candidate_ready),
        "actual_value": f"dual_candidate_preflight_rendezvous_ready={dual_candidate_ready}",
        "blocking_reason": "" if dual_candidate_ready else "requires generation-result and prerequisite-binding candidate preflights",
    },
    {
        "stage_id": "06-real-generation-intake-handoff",
        "status": ready(real_generation_intake_handoff_ready),
        "ready": str(real_generation_intake_handoff_ready),
        "actual_value": f"real_generation_intake_handoff_ready={real_generation_intake_handoff_ready}",
        "blocking_reason": "" if real_generation_intake_handoff_ready else "requires real generation-result artifacts and real prerequisite binding",
    },
    {
        "stage_id": "07-receipt-to-intake-handoff",
        "status": ready(receipt_to_intake_handoff_ready),
        "ready": str(receipt_to_intake_handoff_ready),
        "actual_value": f"real_receipt={real_dispatch_receipt_ready}; real_intake={real_generation_intake_handoff_ready}",
        "blocking_reason": "" if receipt_to_intake_handoff_ready else "receipt logistics and generation evidence must both be real",
    },
    {
        "stage_id": "08-actual-generation",
        "status": "blocked",
        "ready": "0",
        "actual_value": "actual_model_generation_ready=0",
        "blocking_reason": "handoff guard does not run or accept generation",
    },
]
write_csv(run_dir / "dispatch_receipt_to_generation_intake_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "v61er-preflight-surface", "status": "pass", "required_value": "1", "actual_value": "1", "reason": "receipt preflight gate exists"},
    {"requirement_id": "dispatch-receipt-candidate", "status": status(receipt_candidate_ready), "required_value": "1", "actual_value": str(receipt_candidate_ready), "reason": "returned receipt must pass mechanical preflight"},
    {"requirement_id": "real-dispatch-receipt", "status": status(real_dispatch_receipt_ready), "required_value": "1", "actual_value": str(real_dispatch_receipt_ready), "reason": "fixture receipts do not count"},
    {"requirement_id": "v61en-work-order", "status": "pass", "required_value": "1", "actual_value": "1", "reason": "real generation intake work order exists"},
    {"requirement_id": "real-generation-intake-handoff", "status": status(real_generation_intake_handoff_ready), "required_value": "1", "actual_value": str(real_generation_intake_handoff_ready), "reason": "requires real generation evidence, not just receipt"},
    {"requirement_id": "receipt-to-intake-handoff", "status": status(receipt_to_intake_handoff_ready), "required_value": "1", "actual_value": str(receipt_to_intake_handoff_ready), "reason": "requires real receipt and real intake"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
    {"requirement_id": "repo-checkpoint-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "metadata-only handoff guard"},
]
write_csv(run_dir / "dispatch_receipt_to_generation_intake_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

blocker_summary_rows = [
    {
        "blocker_id": row["blocker_id"],
        "source_family": "v61en",
        "status": "open" if row["blocked"] == "1" else "closed",
        "reason": row["resolution"],
        "unblocked_by_receipt": "0",
    }
    for row in blocker_rows
]
blocker_summary_rows.append(
    {
        "blocker_id": "dispatch-receipt-real-provenance",
        "source_family": "v61er",
        "status": "open" if not real_dispatch_receipt_ready else "closed",
        "reason": "requires non-fixture DISPATCH_RECEIPT.json with real-external-dispatch provenance",
        "unblocked_by_receipt": str(real_dispatch_receipt_ready),
    }
)
write_csv(run_dir / "dispatch_receipt_to_generation_intake_blocker_rows.csv", list(blocker_summary_rows[0].keys()), blocker_summary_rows)

command_rows = [
    {
        "command_id": "verify-dispatch-receipt-preflight",
        "command": "V61ER_REUSE_EXISTING=1 ./experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "verify dispatch receipt preflight mechanics",
    },
    {
        "command_id": "verify-generation-intake-work-order",
        "command": "V61EN_REUSE_EXISTING=1 ./experiments/test_v61en_real_generation_intake_work_order.sh",
        "ready_to_run_now": "1",
        "purpose": "verify remaining generation intake work rows",
    },
    {
        "command_id": "promote-real-dispatch-receipt",
        "command": "V61ER_RECEIPT_PROVENANCE=real-external-dispatch V61ER_DISPATCH_RECEIPT_DIR=<returned_receipt_dir> ./experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh",
        "ready_to_run_now": str(receipt_candidate_ready),
        "purpose": "promote a non-fixture real dispatch receipt only after receipt preflight",
    },
    {
        "command_id": "supply-real-generation-intake-evidence",
        "command": "Use v61ej/v61el with real generation-result artifacts and real prerequisite binding, then rerun v61em/v61en",
        "ready_to_run_now": "0",
        "purpose": "receipt alone cannot open generation intake",
    },
    {
        "command_id": "run-real-generation-intake",
        "command": "Run v61bt/v61de only after receipt-to-intake handoff is ready",
        "ready_to_run_now": str(receipt_to_intake_handoff_ready),
        "purpose": "accept real generation rows after all evidence is present",
    },
]
write_csv(run_dir / "dispatch_receipt_to_generation_intake_command_rows.csv", list(command_rows[0].keys()), command_rows)

summary = {
    "v61es_dispatch_receipt_to_generation_intake_handoff_guard_ready": "1",
    "selected_dispatch_receipt_candidate_preflight_ready": str(receipt_candidate_ready),
    "selected_real_dispatch_receipt_ready": str(real_dispatch_receipt_ready),
    "selected_accepted_dispatch_receipt_rows": str(accepted_dispatch_receipt_rows),
    "selected_dual_candidate_preflight_rendezvous_ready": str(dual_candidate_ready),
    "selected_ready_work_order_rows": str(ready_work_order_rows),
    "selected_open_blocker_rows": str(open_blocker_rows),
    "selected_real_generation_intake_handoff_ready": str(real_generation_intake_handoff_ready),
    "receipt_to_intake_handoff_ready": str(receipt_to_intake_handoff_ready),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61es": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61er-preflight-surface", "status": "pass", "reason": "v61er gate ready"},
    {"gate": "dispatch-receipt-candidate", "status": status(receipt_candidate_ready), "reason": f"candidate={receipt_candidate_ready}"},
    {"gate": "real-dispatch-receipt", "status": status(real_dispatch_receipt_ready), "reason": f"real_receipt={real_dispatch_receipt_ready}"},
    {"gate": "v61en-work-order", "status": "pass", "reason": "work order ready"},
    {"gate": "real-generation-intake", "status": status(real_generation_intake_handoff_ready), "reason": f"real_intake={real_generation_intake_handoff_ready}"},
    {"gate": "receipt-to-intake-handoff", "status": status(receipt_to_intake_handoff_ready), "reason": f"handoff={receipt_to_intake_handoff_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only handoff guard"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61ES_DISPATCH_RECEIPT_TO_GENERATION_INTAKE_HANDOFF_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61es Dispatch Receipt to Generation Intake Handoff Boundary",
            "",
            f"- selected_dispatch_receipt_candidate_preflight_ready={receipt_candidate_ready}",
            f"- selected_real_dispatch_receipt_ready={real_dispatch_receipt_ready}",
            f"- selected_real_generation_intake_handoff_ready={real_generation_intake_handoff_ready}",
            f"- receipt_to_intake_handoff_ready={receipt_to_intake_handoff_ready}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- Dispatch receipt preflight and generation intake work order can be reviewed together.",
            "- A receipt can close only logistics/provenance work, not generation-result evidence.",
            "",
            "Blocked wording:",
            "- Do not claim real generation intake from a dispatch receipt alone.",
            "- Do not claim actual generation, production latency, near-frontier quality, or release readiness from this guard.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61es-dispatch-receipt-to-generation-intake-handoff-guard",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61es_dispatch_receipt_to_generation_intake_handoff_guard_ready": 1,
    "selected_real_dispatch_receipt_ready": real_dispatch_receipt_ready,
    "selected_real_generation_intake_handoff_ready": real_generation_intake_handoff_ready,
    "receipt_to_intake_handoff_ready": receipt_to_intake_handoff_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61es_dispatch_receipt_to_generation_intake_handoff_guard_manifest.json").write_text(
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

echo "v61es_dispatch_receipt_to_generation_intake_handoff_guard_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
