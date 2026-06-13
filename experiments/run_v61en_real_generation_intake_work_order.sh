#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61en_real_generation_intake_work_order"
RUN_ID="${V61EN_RUN_ID:-work_order_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RENDEZVOUS_RUN_DIR_ARG="${V61EN_RENDEZVOUS_RUN_DIR:-}"

if [[ "${V61EN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61en_real_generation_intake_work_order_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null
V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RENDEZVOUS_RUN_DIR_ARG" <<'PY'
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
rendezvous_arg = sys.argv[5].strip()
results = root / "results"
default_rendezvous_dir = results / "v61em_generation_intake_dual_preflight_rendezvous" / "rendezvous_001"
rendezvous_dir = Path(rendezvous_arg).expanduser().resolve() if rendezvous_arg else default_rendezvous_dir


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


def ready_status(flag):
    return "ready" if flag else "blocked"


def pass_status(flag):
    return "pass" if flag else "blocked"


source_files = {
    "v61em_summary": results / "v61em_generation_intake_dual_preflight_rendezvous_summary.csv",
    "v61em_decision": results / "v61em_generation_intake_dual_preflight_rendezvous_decision.csv",
    "v61ej_summary": results / "v61ej_real_generation_return_receiver_preflight_summary.csv",
    "v61el_summary": results / "v61el_real_prerequisite_binding_receiver_preflight_summary.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
}
for key, path in source_files.items():
    if not path.is_file():
        raise SystemExit(f"missing v61en source {key}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_required_files = {
    "dual_preflight_rendezvous_stage_rows.csv": rendezvous_dir / "dual_preflight_rendezvous_stage_rows.csv",
    "dual_preflight_rendezvous_command_rows.csv": rendezvous_dir / "dual_preflight_rendezvous_command_rows.csv",
    "dual_preflight_rendezvous_requirement_rows.csv": rendezvous_dir / "dual_preflight_rendezvous_requirement_rows.csv",
    "v61em_generation_intake_dual_preflight_rendezvous_manifest.json": rendezvous_dir / "v61em_generation_intake_dual_preflight_rendezvous_manifest.json",
    "selected_generation_preflight/receiver_preflight_metric_rows.csv": rendezvous_dir / "selected_generation_preflight" / "receiver_preflight_metric_rows.csv",
    "selected_binding_preflight/prerequisite_binding_preflight_metric_rows.csv": rendezvous_dir / "selected_binding_preflight" / "prerequisite_binding_preflight_metric_rows.csv",
}
for rel, path in selected_required_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61em rendezvous artifact: {path}")
    copy(path, f"selected_rendezvous/{rel}")

v61em_manifest = json.loads((rendezvous_dir / "v61em_generation_intake_dual_preflight_rendezvous_manifest.json").read_text(encoding="utf-8"))
v61em_summary = read_csv(source_files["v61em_summary"])[0]
v61bt = read_csv(source_files["v61bt_summary"])[0]
v61de = read_csv(source_files["v61de_summary"])[0]
generation_metric = read_csv(rendezvous_dir / "selected_generation_preflight" / "receiver_preflight_metric_rows.csv")[0]
binding_metric = read_csv(rendezvous_dir / "selected_binding_preflight" / "prerequisite_binding_preflight_metric_rows.csv")[0]

selected_generation_ready = as_int(generation_metric, "generation_result_receiver_preflight_ready")
selected_generation_real_artifacts = as_int(generation_metric, "real_generation_result_artifacts")
selected_binding_candidate_ready = as_int(binding_metric, "binding_candidate_preflight_ready")
selected_non_fixture_binding = as_int(binding_metric, "non_fixture_binding_source")
selected_real_provenance = as_int(binding_metric, "real_review_return_provenance_asserted")
selected_real_binding_ready = as_int(binding_metric, "real_prerequisite_binding_ready")
dual_candidate_ready = int(v61em_manifest.get("dual_candidate_preflight_rendezvous_ready", 0))
real_intake_handoff_ready = int(v61em_manifest.get("real_generation_intake_handoff_ready", 0))
v61bt_handoff_ready = real_intake_handoff_ready
v61de_handoff_ready = int(real_intake_handoff_ready and as_int(binding_metric, "real_review_return_ready"))
actual_model_generation_ready = 0

work_rows = [
    {
        "work_item_id": "01-selected-v61em-rendezvous",
        "family": "rendezvous",
        "status": "ready",
        "ready": "1",
        "required_evidence": "v61em manifest and selected preflight rows",
        "actual_value": f"v61em_ready={v61em_manifest.get('v61em_generation_intake_dual_preflight_rendezvous_ready')}",
        "next_action": "inspect selected rendezvous rows",
    },
    {
        "work_item_id": "02-generation-result-preflight",
        "family": "generation-result",
        "status": ready_status(selected_generation_ready),
        "ready": str(selected_generation_ready),
        "required_evidence": "selected v61ej receiver preflight ready",
        "actual_value": f"ready={selected_generation_ready}; pass_artifacts={generation_metric['preflight_pass_generation_result_artifacts']}/{generation_metric['expected_generation_result_artifacts']}",
        "next_action": "supply real generation-result return and rerun v61ej",
    },
    {
        "work_item_id": "03-binding-candidate-preflight",
        "family": "prerequisite-binding",
        "status": ready_status(selected_binding_candidate_ready),
        "ready": str(selected_binding_candidate_ready),
        "required_evidence": "selected v61el binding candidate preflight ready",
        "actual_value": f"ready={selected_binding_candidate_ready}; checks={binding_metric['ready_check_pass_rows']}/{binding_metric['required_ready_check_rows']}",
        "next_action": "supply real prerequisite binding and rerun v61el",
    },
    {
        "work_item_id": "04-non-fixture-binding",
        "family": "prerequisite-binding",
        "status": ready_status(selected_non_fixture_binding),
        "ready": str(selected_non_fixture_binding),
        "required_evidence": "selected binding source is non-fixture",
        "actual_value": f"class={binding_metric['selected_binding_source_class']}",
        "next_action": "replace fixture binding with operator-supplied real binding",
    },
    {
        "work_item_id": "05-real-review-return-provenance",
        "family": "review-return",
        "status": ready_status(selected_real_provenance),
        "ready": str(selected_real_provenance),
        "required_evidence": "V61EL_BINDING_PROVENANCE=real-review-return",
        "actual_value": f"provenance={binding_metric['binding_provenance']}",
        "next_action": "bind prerequisite summaries to real review-return provenance",
    },
    {
        "work_item_id": "06-real-prerequisite-binding",
        "family": "prerequisite-binding",
        "status": ready_status(selected_real_binding_ready),
        "ready": str(selected_real_binding_ready),
        "required_evidence": "non-fixture binding plus real review-return provenance",
        "actual_value": f"real_binding={selected_real_binding_ready}",
        "next_action": "rerun v61em after real binding passes v61el",
    },
    {
        "work_item_id": "07-dual-candidate-rendezvous",
        "family": "rendezvous",
        "status": ready_status(dual_candidate_ready),
        "ready": str(dual_candidate_ready),
        "required_evidence": "generation preflight and binding candidate preflight both ready",
        "actual_value": f"dual_candidate={dual_candidate_ready}",
        "next_action": "promote only after real prerequisite binding is ready",
    },
    {
        "work_item_id": "08-real-generation-intake-handoff",
        "family": "intake",
        "status": ready_status(real_intake_handoff_ready),
        "ready": str(real_intake_handoff_ready),
        "required_evidence": "dual candidate plus real prerequisite binding",
        "actual_value": f"real_intake_handoff={real_intake_handoff_ready}",
        "next_action": "run v61bt/v61de real intake commands",
    },
    {
        "work_item_id": "09-v61bt-real-intake",
        "family": "intake",
        "status": ready_status(v61bt_handoff_ready),
        "ready": str(v61bt_handoff_ready),
        "required_evidence": "v61bt intake handoff ready",
        "actual_value": f"v61bt_handoff={v61bt_handoff_ready}; accepted_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}",
        "next_action": "run v61bt with real result and real binding dirs",
    },
    {
        "work_item_id": "10-v61de-real-handoff",
        "family": "intake",
        "status": ready_status(v61de_handoff_ready),
        "ready": str(v61de_handoff_ready),
        "required_evidence": "v61de handoff ready",
        "actual_value": f"v61de_handoff={v61de_handoff_ready}; generation_admitted={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}",
        "next_action": "run v61de with real review/result/binding dirs",
    },
    {
        "work_item_id": "11-actual-generation-acceptance",
        "family": "acceptance",
        "status": "blocked",
        "ready": "0",
        "required_evidence": "accepted v61bt/v61de generation result rows",
        "actual_value": "actual_model_generation_ready=0",
        "next_action": "do not claim actual generation from work order alone",
    },
]
write_csv(run_dir / "real_generation_intake_work_order_rows.csv", list(work_rows[0].keys()), work_rows)

command_rows = [
    {
        "command_id": "verify-selected-dual-rendezvous",
        "command": "V61EM_REUSE_EXISTING=1 ./experiments/test_v61em_generation_intake_dual_preflight_rendezvous.sh",
        "ready_to_run_now": "1",
        "purpose": "verify current dual preflight rendezvous mechanics",
    },
    {
        "command_id": "preflight-real-generation-results",
        "command": "V61EJ_GENERATION_RESULT_DIR=/path/to/real_generation_result_return ./experiments/run_v61ej_real_generation_return_receiver_preflight.sh",
        "ready_to_run_now": "0",
        "purpose": "create non-fixture generation-result receiver preflight",
    },
    {
        "command_id": "preflight-real-prerequisite-binding",
        "command": "V61EL_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding V61EL_BINDING_PROVENANCE=real-review-return ./experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh",
        "ready_to_run_now": "0",
        "purpose": "create non-fixture prerequisite-binding receiver preflight",
    },
    {
        "command_id": "rerun-real-dual-rendezvous",
        "command": "V61EM_GENERATION_PREFLIGHT_RUN_DIR=/path/to/real_v61ej_preflight V61EM_BINDING_PREFLIGHT_RUN_DIR=/path/to/real_v61el_preflight ./experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh",
        "ready_to_run_now": str(int(selected_generation_ready and selected_real_binding_ready)),
        "purpose": "open real-generation-intake handoff only after real binding",
    },
    {
        "command_id": "run-v61bt-real-intake",
        "command": "V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(v61bt_handoff_ready),
        "purpose": "accept actual generation result artifacts",
    },
    {
        "command_id": "run-v61de-real-handoff",
        "command": "V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": str(v61de_handoff_ready),
        "purpose": "refresh post-review generation result handoff",
    },
    {
        "command_id": "refresh-active-goal-status",
        "command": "./experiments/test_v61ei_active_goal_post_eh_status_refresh.sh",
        "ready_to_run_now": "1",
        "purpose": "confirm claim boundaries after work-order refresh",
    },
]
write_csv(run_dir / "real_generation_intake_command_rows.csv", list(command_rows[0].keys()), command_rows)

blocker_rows = [
    {
        "blocker_id": "real-generation-result-preflight",
        "blocked": str(int(not selected_generation_ready)),
        "current_value": str(selected_generation_ready),
        "required_value": "1",
        "resolution": "provide non-fixture generation-result directory and rerun v61ej",
    },
    {
        "blocker_id": "non-fixture-prerequisite-binding",
        "blocked": str(int(not selected_non_fixture_binding)),
        "current_value": str(selected_non_fixture_binding),
        "required_value": "1",
        "resolution": "replace v61eg fixture binding with operator-supplied real binding",
    },
    {
        "blocker_id": "real-review-return-provenance",
        "blocked": str(int(not selected_real_provenance)),
        "current_value": str(selected_real_provenance),
        "required_value": "1",
        "resolution": "assert real-review-return provenance only for non-fixture review return",
    },
    {
        "blocker_id": "real-prerequisite-binding",
        "blocked": str(int(not selected_real_binding_ready)),
        "current_value": str(selected_real_binding_ready),
        "required_value": "1",
        "resolution": "rerun v61el after non-fixture binding and provenance pass",
    },
    {
        "blocker_id": "real-generation-intake-handoff",
        "blocked": str(int(not real_intake_handoff_ready)),
        "current_value": str(real_intake_handoff_ready),
        "required_value": "1",
        "resolution": "rerun v61em with real v61ej/v61el preflight dirs",
    },
    {
        "blocker_id": "actual-generation-acceptance",
        "blocked": "1",
        "current_value": "0",
        "required_value": "1",
        "resolution": "accept v61bt/v61de real generation result rows before any actual generation claim",
    },
]
write_csv(run_dir / "real_generation_intake_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

ready_work_rows = sum(row["ready"] == "1" for row in work_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
open_blocker_rows = sum(row["blocked"] == "1" for row in blocker_rows)
summary = {
    "v61en_real_generation_intake_work_order_ready": "1",
    "selected_rendezvous_run_dir_supplied": str(int(bool(rendezvous_arg))),
    "selected_rendezvous_run_dir": str(rendezvous_dir),
    "v61em_generation_intake_dual_preflight_rendezvous_ready": str(v61em_manifest.get("v61em_generation_intake_dual_preflight_rendezvous_ready", 0)),
    "selected_generation_result_receiver_preflight_ready": str(selected_generation_ready),
    "selected_binding_candidate_preflight_ready": str(selected_binding_candidate_ready),
    "selected_non_fixture_binding_source": str(selected_non_fixture_binding),
    "selected_real_review_return_provenance_asserted": str(selected_real_provenance),
    "selected_real_prerequisite_binding_ready": str(selected_real_binding_ready),
    "dual_candidate_preflight_rendezvous_ready": str(dual_candidate_ready),
    "real_generation_intake_handoff_ready": str(real_intake_handoff_ready),
    "v61bt_intake_handoff_ready": str(v61bt_handoff_ready),
    "v61de_generation_result_handoff_ready": str(v61de_handoff_ready),
    "work_order_rows": str(len(work_rows)),
    "ready_work_order_rows": str(ready_work_rows),
    "blocked_work_order_rows": str(len(work_rows) - ready_work_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "blocker_rows": str(len(blocker_rows)),
    "open_blocker_rows": str(open_blocker_rows),
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61en": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "selected-rendezvous-present", "status": "pass", "reason": "selected v61em rendezvous artifacts are present"},
    {"gate": "selected-generation-preflight", "status": pass_status(selected_generation_ready), "reason": f"generation_preflight_ready={selected_generation_ready}"},
    {"gate": "selected-binding-candidate-preflight", "status": pass_status(selected_binding_candidate_ready), "reason": f"binding_candidate_preflight_ready={selected_binding_candidate_ready}"},
    {"gate": "non-fixture-binding-source", "status": pass_status(selected_non_fixture_binding), "reason": f"non_fixture_binding_source={selected_non_fixture_binding}"},
    {"gate": "real-review-return-provenance", "status": pass_status(selected_real_provenance), "reason": f"real_review_return_provenance={selected_real_provenance}"},
    {"gate": "real-prerequisite-binding", "status": pass_status(selected_real_binding_ready), "reason": f"real_prerequisite_binding_ready={selected_real_binding_ready}"},
    {"gate": "real-generation-intake-handoff", "status": pass_status(real_intake_handoff_ready), "reason": f"real_generation_intake_handoff_ready={real_intake_handoff_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "work order is not a generation acceptance gate"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only work order"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

work_order_md = f"""# v61en Real Generation Intake Work Order

This work order is the operational step after v61em. It lists the exact
non-fixture evidence required before v61bt/v61de real intake can run.

- selected_generation_result_receiver_preflight_ready={selected_generation_ready}
- selected_binding_candidate_preflight_ready={selected_binding_candidate_ready}
- selected_non_fixture_binding_source={selected_non_fixture_binding}
- selected_real_review_return_provenance_asserted={selected_real_provenance}
- selected_real_prerequisite_binding_ready={selected_real_binding_ready}
- dual_candidate_preflight_rendezvous_ready={dual_candidate_ready}
- real_generation_intake_handoff_ready={real_intake_handoff_ready}
- v61bt_intake_handoff_ready={v61bt_handoff_ready}
- v61de_generation_result_handoff_ready={v61de_handoff_ready}
- actual_model_generation_ready={actual_model_generation_ready}

Allowed wording: the real-intake work order is ready and identifies the missing
non-fixture evidence.

Blocked wording: this work order, fixture dual-candidate preflight, or metadata
commands do not imply actual generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61EN_REAL_GENERATION_INTAKE_WORK_ORDER.md").write_text(work_order_md, encoding="utf-8")

manifest = {
    "manifest_scope": "v61en-real-generation-intake-work-order",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61en_real_generation_intake_work_order_ready": 1,
    "real_generation_intake_handoff_ready": real_intake_handoff_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "open_blocker_rows": open_blocker_rows,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61en_real_generation_intake_work_order_manifest.json").write_text(
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

echo "v61en_real_generation_intake_work_order_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
