#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53am_complete_source_return_acceptance_replay"
RUN_ID="${V53AM_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V53AM_RETURN_BUNDLE_DIR:-}"

if [[ "${V53AM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53am_complete_source_return_acceptance_replay_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V53AL_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
  V53AD_DISPATCH_RECEIPT_DIR="$RETURN_BUNDLE_DIR" V53AD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null
  V53X_REVIEW_CHUNK_RETURN_DIR="$RETURN_BUNDLE_DIR/review_chunk_returns" V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
  V53Y_REVIEW_RETURN_DIR="$RETURN_BUNDLE_DIR/aggregate_review_return" V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
  V53Z_REVIEW_CHUNK_RETURN_DIR="$RETURN_BUNDLE_DIR/review_chunk_returns" V53Z_REVIEW_RETURN_DIR="$RETURN_BUNDLE_DIR/aggregate_review_return" V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
  V61BT_GENERATION_RESULT_DIR="$RETURN_BUNDLE_DIR/generation_result_return" V61BT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
  V61DE_REVIEW_RETURN_DIR="$RETURN_BUNDLE_DIR/aggregate_review_return" V61DE_GENERATION_RESULT_DIR="$RETURN_BUNDLE_DIR/generation_result_return" V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
  V53AE_DISPATCH_RECEIPT_DIR="$RETURN_BUNDLE_DIR" V53AE_REVIEW_CHUNK_RETURN_DIR="$RETURN_BUNDLE_DIR/review_chunk_returns" V53AE_REVIEW_RETURN_DIR="$RETURN_BUNDLE_DIR/aggregate_review_return" V53AE_GENERATION_RESULT_DIR="$RETURN_BUNDLE_DIR/generation_result_return" V53AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh" >/dev/null
else
  V53AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
  V53AD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null
  V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
  V53Y_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
  V53Z_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53z_complete_source_review_return_v61_handoff_bridge.sh" >/dev/null
  V61BT_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
  V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
  V53AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" <<'PY'
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
return_bundle_arg = sys.argv[5]
return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
results = root / "results"


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


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v53al": ("v53al_complete_source_external_return_bundle_preflight", "preflight_001", "v53al_complete_source_external_return_bundle_preflight_ready"),
    "v53ad": ("v53ad_complete_source_review_dispatch_receipt_intake", "intake_001", "v53ad_complete_source_review_dispatch_receipt_intake_ready"),
    "v53x": ("v53x_complete_source_review_chunk_return_intake", "intake_001", "v53x_complete_source_review_chunk_return_intake_ready"),
    "v53y": ("v53y_complete_source_review_return_refresh_gate", "gate_001", "v53y_complete_source_review_return_refresh_gate_ready"),
    "v53z": ("v53z_complete_source_review_return_v61_handoff_bridge", "bridge_001", "v53z_complete_source_review_return_v61_handoff_bridge_ready"),
    "v53ae": ("v53ae_complete_source_review_return_generation_rendezvous_gate", "gate_001", "v53ae_complete_source_review_return_generation_rendezvous_gate_ready"),
    "v61bt": ("v61bt_ubuntu1_actual_generation_result_intake", "intake_001", "v61bt_ubuntu1_actual_generation_result_intake_ready"),
    "v61cu": ("v61cu_complete_source_generation_result_acceptance_bridge", "bridge_001", "v61cu_complete_source_generation_result_acceptance_bridge_ready"),
    "v61de": ("v61de_post_review_generation_result_handoff_bridge", "bridge_001", "v61de_post_review_generation_result_handoff_bridge_ready"),
}
summaries = {}
for key, (prefix, run_id, ready_field) in sources.items():
    summary_path = results / f"{prefix}_summary.csv"
    decision_path = results / f"{prefix}_decision.csv"
    source_dir = results / prefix / run_id
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v53am requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    if (source_dir / "sha256_manifest.csv").is_file():
        copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

for src, rel in [
    (results / "v53al_complete_source_external_return_bundle_preflight/preflight_001/external_return_bundle_preflight_rows.csv", "source_v53al/external_return_bundle_preflight_rows.csv"),
    (results / "v53ad_complete_source_review_dispatch_receipt_intake/intake_001/complete_source_review_dispatch_receipt_status_rows.csv", "source_v53ad/complete_source_review_dispatch_receipt_status_rows.csv"),
    (results / "v53x_complete_source_review_chunk_return_intake/intake_001/complete_source_review_chunk_return_artifact_status_rows.csv", "source_v53x/complete_source_review_chunk_return_artifact_status_rows.csv"),
    (results / "v53y_complete_source_review_return_refresh_gate/gate_001/complete_source_review_return_refresh_stage_rows.csv", "source_v53y/complete_source_review_return_refresh_stage_rows.csv"),
    (results / "v53ae_complete_source_review_return_generation_rendezvous_gate/gate_001/review_return_generation_rendezvous_stage_rows.csv", "source_v53ae/review_return_generation_rendezvous_stage_rows.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/generation_result_artifact_status_rows.csv", "source_v61bt/generation_result_artifact_status_rows.csv"),
    (results / "v61de_post_review_generation_result_handoff_bridge/bridge_001/post_review_generation_result_handoff_stage_rows.csv", "source_v61de/post_review_generation_result_handoff_stage_rows.csv"),
]:
    if src.is_file():
        copy(src, rel)

v53al = summaries["v53al"]
v53ad = summaries["v53ad"]
v53x = summaries["v53x"]
v53y = summaries["v53y"]
v53ae = summaries["v53ae"]
v61bt = summaries["v61bt"]
v61cu = summaries["v61cu"]
v61de = summaries["v61de"]

return_bundle_dir_supplied = int(return_bundle_dir is not None)
return_bundle_dir_exists = int(return_bundle_dir is not None and return_bundle_dir.is_dir())
preflight_ready = as_int(v53al, "preflight_surface_ready")
preflight_pass = as_int(v53al, "return_bundle_preflight_pass")
dispatch_ready = as_int(v53ad, "dispatch_receipt_intake_ready")
chunk_ready = as_int(v53x, "chunk_return_intake_ready")
aggregate_ready = as_int(v53y, "review_return_ready")
v53_ready = as_int(v53y, "v53_ready")
full_runtime_ready = int(as_int(v53ae, "full_shard_prerequisites_closed") and as_int(v53ae, "runtime_admission_accepted_rows") == 1000)
generation_intake_ready = int(as_int(v61bt, "accepted_generation_result_artifacts") == as_int(v61bt, "expected_generation_result_artifacts") and as_int(v61bt, "expected_generation_result_artifacts") > 0)
generation_acceptance_ready = int(as_int(v61cu, "generation_result_accepted_rows") == as_int(v61cu, "generation_result_acceptance_rows") and as_int(v61cu, "generation_result_acceptance_rows") > 0)
generation_execution_ready = int(as_int(v61de, "generation_execution_admitted_rows") == as_int(v61de, "generation_execution_admission_rows") and as_int(v61de, "generation_execution_admission_rows") > 0)
actual_generation_ready = as_int(v61de, "actual_model_generation_ready")

step_rows = [
    {"replay_step_id": "01-return-bundle-preflight-surface", "source_gate": "v53al", "status": "ready" if preflight_ready else "blocked", "actual_value": f"preflight_surface_ready={v53al['preflight_surface_ready']}", "blocking_reason": "ready" if preflight_ready else "preflight surface missing"},
    {"replay_step_id": "02-return-bundle-preflight-pass", "source_gate": "v53al", "status": "ready" if preflight_pass else "blocked", "actual_value": f"return_bundle_preflight_pass={v53al['return_bundle_preflight_pass']}; preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}", "blocking_reason": "return bundle preflight has not passed"},
    {"replay_step_id": "03-dispatch-receipt-intake", "source_gate": "v53ad", "status": "ready" if dispatch_ready else "blocked", "actual_value": f"accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}", "blocking_reason": "dispatch receipts are missing or invalid"},
    {"replay_step_id": "04-review-chunk-return-intake", "source_gate": "v53x", "status": "ready" if chunk_ready else "blocked", "actual_value": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}", "blocking_reason": "review chunk return artifacts are missing or invalid"},
    {"replay_step_id": "05-aggregate-review-refresh", "source_gate": "v53y", "status": "ready" if aggregate_ready else "blocked", "actual_value": f"answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}; accepted_adjudication_rows={v53y['accepted_adjudication_rows']}/{v53y['expected_adjudication_rows']}", "blocking_reason": "aggregate review return is not accepted"},
    {"replay_step_id": "06-v53-review-acceptance", "source_gate": "v53y/v53v", "status": "ready" if v53_ready else "blocked", "actual_value": f"review_return_ready={v53y['review_return_ready']}; v53_ready={v53y['v53_ready']}", "blocking_reason": "v53 review acceptance is blocked"},
    {"replay_step_id": "07-full-shard-runtime-closed", "source_gate": "v53ae/v61de", "status": "ready" if full_runtime_ready else "blocked", "actual_value": f"full_shard_prerequisites_closed={v53ae['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v53ae['runtime_admission_accepted_rows']}", "blocking_reason": "ready" if full_runtime_ready else "full-shard/runtime closure is incomplete"},
    {"replay_step_id": "08-generation-execution-admitted", "source_gate": "v61de", "status": "ready" if generation_execution_ready else "blocked", "actual_value": f"generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}", "blocking_reason": "generation execution is not admitted"},
    {"replay_step_id": "09-generation-result-intake", "source_gate": "v61bt", "status": "ready" if generation_intake_ready else "blocked", "actual_value": f"accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}", "blocking_reason": "generation result artifacts are missing or invalid"},
    {"replay_step_id": "10-generation-result-acceptance", "source_gate": "v61cu/v61de", "status": "ready" if generation_acceptance_ready else "blocked", "actual_value": f"generation_result_accepted_rows={v61cu['generation_result_accepted_rows']}/{v61cu['generation_result_acceptance_rows']}", "blocking_reason": "generation result rows are not accepted"},
    {"replay_step_id": "11-actual-model-generation-ready", "source_gate": "v61de", "status": "ready" if actual_generation_ready else "blocked", "actual_value": f"actual_model_generation_ready={v61de['actual_model_generation_ready']}", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "return_acceptance_replay_step_rows.csv", list(step_rows[0].keys()), step_rows)
ready_replay_step_rows = sum(1 for row in step_rows if row["status"] == "ready")
blocked_replay_step_rows = len(step_rows) - ready_replay_step_rows

command_rows = [
    {"command_id": "01-preflight", "ready_to_run_now": "1", "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh"},
    {"command_id": "02-dispatch-receipts", "ready_to_run_now": str(preflight_pass), "command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh"},
    {"command_id": "03-review-chunks", "ready_to_run_now": str(preflight_pass), "command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle/review_chunk_returns V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh"},
    {"command_id": "04-aggregate-review", "ready_to_run_now": str(preflight_pass), "command": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh"},
    {"command_id": "05-rendezvous", "ready_to_run_now": str(preflight_pass), "command": "V53AE_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AE_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle/review_chunk_returns V53AE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53AE_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh"},
    {"command_id": "06-generation-result-intake", "ready_to_run_now": str(int(preflight_pass and aggregate_ready)), "command": "V61BT_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh"},
    {"command_id": "07-post-review-generation-handoff", "ready_to_run_now": str(int(preflight_pass and aggregate_ready)), "command": "V61DE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V61DE_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh"},
]
write_csv(run_dir / "return_acceptance_replay_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_replay_command_rows = sum(int(row["ready_to_run_now"]) for row in command_rows)

replay_closed = int(all(row["status"] == "ready" for row in step_rows))
metric = {
    "metric_id": "v53am_complete_source_return_acceptance_replay_metrics",
    "return_bundle_dir_supplied": str(return_bundle_dir_supplied),
    "return_bundle_dir_exists": str(return_bundle_dir_exists),
    "v53al_complete_source_external_return_bundle_preflight_ready": v53al["v53al_complete_source_external_return_bundle_preflight_ready"],
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"],
    "v61de_post_review_generation_result_handoff_bridge_ready": v61de["v61de_post_review_generation_result_handoff_bridge_ready"],
    "return_acceptance_replay_ready": "1",
    "replay_step_rows": str(len(step_rows)),
    "ready_replay_step_rows": str(ready_replay_step_rows),
    "blocked_replay_step_rows": str(blocked_replay_step_rows),
    "replay_command_rows": str(len(command_rows)),
    "ready_replay_command_rows": str(ready_replay_command_rows),
    "return_bundle_preflight_pass": v53al["return_bundle_preflight_pass"],
    "preflight_pass_rows": v53al["preflight_pass_rows"],
    "preflight_rows": v53al["preflight_rows"],
    "accepted_dispatch_receipt_rows": v53ad["accepted_dispatch_receipt_rows"],
    "dispatch_receipt_template_rows": v53ad["dispatch_receipt_template_rows"],
    "accepted_chunk_return_artifact_rows": v53x["accepted_chunk_return_artifact_rows"],
    "review_chunk_return_artifact_rows": v53x["review_chunk_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53y["accepted_aggregate_review_return_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53y["aggregate_review_return_artifact_rows"],
    "answer_review_accepted_rows": v53y["answer_review_accepted_rows"],
    "expected_human_review_rows": v53y["expected_human_review_rows"],
    "accepted_adjudication_rows": v53y["accepted_adjudication_rows"],
    "expected_adjudication_rows": v53y["expected_adjudication_rows"],
    "review_return_ready": v53y["review_return_ready"],
    "v53_ready": v53y["v53_ready"],
    "full_shard_prerequisites_closed": v53ae["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ae["runtime_admission_accepted_rows"],
    "generation_execution_admitted_rows": v61de["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61de["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v61cu["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v61cu["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v61de["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "return_acceptance_replay_closed": str(replay_closed),
    "accepted_by_v53am_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v53am": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_acceptance_replay_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53am_complete_source_return_acceptance_replay_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["replay_step_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]}
    for row in step_rows
]
decision_rows.append({"gate": "v53am-does-not-accept-evidence", "status": "pass", "reason": "accepted_by_v53am_rows=0"})
decision_rows.append({"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["replay_step_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in step_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v53am Complete-Source Return Acceptance Replay Boundary

This artifact replays the downstream return acceptance chain after v53al
preflight. It does not accept evidence by itself, does not execute model
generation, and does not create latency, near-frontier, or release claims.

Evidence emitted:

- return_acceptance_replay_ready=1
- replay_step_rows={len(step_rows)}
- ready_replay_step_rows={ready_replay_step_rows}
- blocked_replay_step_rows={blocked_replay_step_rows}
- replay_command_rows={len(command_rows)}
- ready_replay_command_rows={ready_replay_command_rows}
- return_bundle_preflight_pass={v53al['return_bundle_preflight_pass']}
- preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}
- accepted_dispatch_receipt_rows={v53ad['accepted_dispatch_receipt_rows']}/{v53ad['dispatch_receipt_template_rows']}
- accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}
- answer_review_accepted_rows={v53y['answer_review_accepted_rows']}/{v53y['expected_human_review_rows']}
- accepted_adjudication_rows={v53y['accepted_adjudication_rows']}/{v53y['expected_adjudication_rows']}
- full_shard_prerequisites_closed={v53ae['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53ae['runtime_admission_accepted_rows']}
- generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v61cu['generation_result_accepted_rows']}/{v61cu['generation_result_acceptance_rows']}
- actual_model_generation_ready={v61de['actual_model_generation_ready']}
- return_acceptance_replay_closed={replay_closed}
- accepted_by_v53am_rows=0
- checkpoint_payload_bytes_downloaded_by_v53am=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: downstream return acceptance replay is ready and reports
current blockers.
Blocked wording: returned evidence accepted by v53am, actual generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AM_COMPLETE_SOURCE_RETURN_ACCEPTANCE_REPLAY_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53am-complete-source-return-acceptance-replay",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53am_complete_source_return_acceptance_replay_ready": 1,
    "replay_step_rows": len(step_rows),
    "ready_replay_step_rows": ready_replay_step_rows,
    "blocked_replay_step_rows": blocked_replay_step_rows,
    "return_bundle_preflight_pass": int(v53al["return_bundle_preflight_pass"]),
    "answer_review_accepted_rows": int(v53y["answer_review_accepted_rows"]),
    "generation_execution_admitted_rows": int(v61de["generation_execution_admitted_rows"]),
    "accepted_generation_result_artifacts": int(v61bt["accepted_generation_result_artifacts"]),
    "actual_model_generation_ready": int(v61de["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53ae["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53ae["runtime_admission_accepted_rows"]),
    "accepted_by_v53am_rows": 0,
    "checkpoint_payload_bytes_downloaded_by_v53am": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53am_complete_source_return_acceptance_replay_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53am_complete_source_return_acceptance_replay_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
