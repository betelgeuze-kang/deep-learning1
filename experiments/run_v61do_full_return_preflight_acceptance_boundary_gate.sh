#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61do_full_return_preflight_acceptance_boundary_gate"
RUN_ID="${V61DO_RUN_ID:-boundary_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V61DO_RETURN_BUNDLE_DIR:-}"

if [[ "${V61DO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61do_full_return_preflight_acceptance_boundary_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V61DN_RUN_ID="${RUN_ID}_v61dn" V61DN_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V61DN_REUSE_EXISTING=0 \
    "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null
  V53AL_RUN_ID="${RUN_ID}_v53al" V53AL_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AL_REUSE_EXISTING=0 \
    "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
  V53AM_RUN_ID="${RUN_ID}_v53am" V53AM_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AM_REUSE_EXISTING=0 \
    "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
else
  V61DN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dn_residual_return_completion_gate.sh" >/dev/null
  V53AL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
  V53AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61dn_summary": results / "v61dn_residual_return_completion_gate_summary.csv",
    "v61dn_decision": results / "v61dn_residual_return_completion_gate_decision.csv",
    "v53al_summary": results / "v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "v53al_decision": results / "v53al_complete_source_external_return_bundle_preflight_decision.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_decision": results / "v53am_complete_source_return_acceptance_replay_decision.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61do source {key}: {path}")

copy(sources["v61dn_summary"], "source_v61dn/v61dn_residual_return_completion_gate_summary.csv")
copy(sources["v61dn_decision"], "source_v61dn/v61dn_residual_return_completion_gate_decision.csv")
copy(sources["v53al_summary"], "source_v53al/v53al_complete_source_external_return_bundle_preflight_summary.csv")
copy(sources["v53al_decision"], "source_v53al/v53al_complete_source_external_return_bundle_preflight_decision.csv")
copy(sources["v53am_summary"], "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv")
copy(sources["v53am_decision"], "source_v53am/v53am_complete_source_return_acceptance_replay_decision.csv")

v61dn = read_csv(sources["v61dn_summary"])[0]
v53al = read_csv(sources["v53al_summary"])[0]
v53am = read_csv(sources["v53am_summary"])[0]
if v61dn.get("v61dn_residual_return_completion_gate_ready") != "1":
    raise SystemExit("v61do requires v61dn ready")
if v53al.get("v53al_complete_source_external_return_bundle_preflight_ready") != "1":
    raise SystemExit("v61do requires v53al ready")
if v53am.get("v53am_complete_source_return_acceptance_replay_ready") != "1":
    raise SystemExit("v61do requires v53am ready")

return_bundle_dir_supplied = int(return_bundle_dir is not None)
return_bundle_dir_exists = int(return_bundle_dir is not None and return_bundle_dir.is_dir())
critical_ready = as_int(v61dn, "critical_preflight_ready")
residual_ready = as_int(v61dn, "residual_completion_ready")
full_preflight_ready = as_int(v53al, "return_bundle_preflight_pass")
dispatch_ready = int(as_int(v53am, "accepted_dispatch_receipt_rows") == as_int(v53am, "dispatch_receipt_template_rows") and as_int(v53am, "dispatch_receipt_template_rows") > 0)
chunk_ready = int(as_int(v53am, "accepted_chunk_return_artifact_rows") == as_int(v53am, "review_chunk_return_artifact_rows") and as_int(v53am, "review_chunk_return_artifact_rows") > 0)
review_ready = int(as_int(v53am, "review_return_ready") == 1 and as_int(v53am, "v53_ready") == 1)
generation_execution_ready = int(as_int(v53am, "generation_execution_admitted_rows") == as_int(v53am, "generation_execution_admission_rows") and as_int(v53am, "generation_execution_admission_rows") > 0)
generation_result_ready = int(as_int(v53am, "generation_result_accepted_rows") == as_int(v53am, "generation_result_acceptance_rows") and as_int(v53am, "generation_result_acceptance_rows") > 0)
actual_ready = as_int(v53am, "actual_model_generation_ready")
preflight_only_gap = int(
    full_preflight_ready
    and not dispatch_ready
    and not chunk_ready
    and not review_ready
    and as_int(v53am, "answer_review_accepted_rows") == 0
    and as_int(v53am, "generation_result_accepted_rows") == 0
    and not actual_ready
)

stage_rows = [
    {"stage_id": "01-critical-preflight", "status": "ready" if critical_ready else "blocked", "actual_value": f"critical_preflight_pass_rows={v61dn['critical_preflight_pass_rows']}/{v61dn['critical_artifact_rows']}", "blocking_reason": "critical 10-file preflight has not passed"},
    {"stage_id": "02-residual-completion", "status": "ready" if residual_ready else "blocked", "actual_value": f"residual_preflight_pass_rows={v61dn['residual_preflight_pass_rows']}/{v61dn['residual_artifact_rows']}", "blocking_reason": "71 residual dispatch/review-chunk artifacts are not complete"},
    {"stage_id": "03-full-return-preflight", "status": "ready" if full_preflight_ready else "blocked", "actual_value": f"preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}", "blocking_reason": "full 81-artifact return preflight has not passed"},
    {"stage_id": "04-dispatch-receipt-acceptance", "status": "ready" if dispatch_ready else "blocked", "actual_value": f"accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}", "blocking_reason": "dispatch receipts are not accepted"},
    {"stage_id": "05-review-chunk-acceptance", "status": "ready" if chunk_ready else "blocked", "actual_value": f"accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}", "blocking_reason": "review chunk returns are not accepted"},
    {"stage_id": "06-review-row-acceptance", "status": "ready" if review_ready else "blocked", "actual_value": f"answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}; accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}", "blocking_reason": "human/source review and adjudication rows are not accepted"},
    {"stage_id": "07-generation-execution", "status": "ready" if generation_execution_ready else "blocked", "actual_value": f"generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}", "blocking_reason": "generation execution is not admitted"},
    {"stage_id": "08-generation-result-acceptance", "status": "ready" if generation_result_ready else "blocked", "actual_value": f"generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}", "blocking_reason": "generation result rows are not accepted"},
    {"stage_id": "09-actual-generation-ready", "status": "ready" if actual_ready else "blocked", "actual_value": f"actual_model_generation_ready={v53am['actual_model_generation_ready']}", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "full_return_preflight_acceptance_boundary_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(row["status"] == "ready" for row in stage_rows)

command_rows = [
    {"command_id": "01-run-full-preflight", "ready_to_run_now": "1", "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh", "expected_transition": "preflight_pass_rows=81"},
    {"command_id": "02-run-return-acceptance-replay", "ready_to_run_now": "1", "command": "V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh", "expected_transition": "row-level acceptance remains authoritative"},
    {"command_id": "03-run-generation-handoff", "ready_to_run_now": str(review_ready), "command": "V61DE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V61DE_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh", "expected_transition": "actual generation only after review/generation acceptance"},
]
write_csv(run_dir / "full_return_preflight_acceptance_boundary_command_rows.csv", list(command_rows[0].keys()), command_rows)

metric = {
    "metric_id": "v61do_full_return_preflight_acceptance_boundary_gate_metrics",
    "v61dn_residual_return_completion_gate_ready": v61dn["v61dn_residual_return_completion_gate_ready"],
    "v53al_complete_source_external_return_bundle_preflight_ready": v53al["v53al_complete_source_external_return_bundle_preflight_ready"],
    "v53am_complete_source_return_acceptance_replay_ready": v53am["v53am_complete_source_return_acceptance_replay_ready"],
    "source_gate_rows": "3",
    "return_bundle_dir_supplied": str(return_bundle_dir_supplied),
    "return_bundle_dir_exists": str(return_bundle_dir_exists),
    "boundary_stage_rows": str(len(stage_rows)),
    "ready_boundary_stage_rows": str(ready_stage_rows),
    "blocked_boundary_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "boundary_command_rows": str(len(command_rows)),
    "ready_boundary_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "critical_preflight_pass_rows": v61dn["critical_preflight_pass_rows"],
    "critical_artifact_rows": v61dn["critical_artifact_rows"],
    "critical_preflight_ready": v61dn["critical_preflight_ready"],
    "residual_preflight_pass_rows": v61dn["residual_preflight_pass_rows"],
    "residual_artifact_rows": v61dn["residual_artifact_rows"],
    "residual_completion_ready": v61dn["residual_completion_ready"],
    "full_preflight_rows": v53al["preflight_rows"],
    "full_preflight_pass_rows": v53al["preflight_pass_rows"],
    "return_bundle_preflight_pass": v53al["return_bundle_preflight_pass"],
    "preflight_only_gap_detected": str(preflight_only_gap),
    "accepted_dispatch_receipt_rows": v53am["accepted_dispatch_receipt_rows"],
    "dispatch_receipt_template_rows": v53am["dispatch_receipt_template_rows"],
    "accepted_chunk_return_artifact_rows": v53am["accepted_chunk_return_artifact_rows"],
    "review_chunk_return_artifact_rows": v53am["review_chunk_return_artifact_rows"],
    "answer_review_accepted_rows": v53am["answer_review_accepted_rows"],
    "expected_human_review_rows": v53am["expected_human_review_rows"],
    "accepted_adjudication_rows": v53am["accepted_adjudication_rows"],
    "expected_adjudication_rows": v53am["expected_adjudication_rows"],
    "review_return_ready": v53am["review_return_ready"],
    "v53_ready": v53am["v53_ready"],
    "generation_execution_admitted_rows": v53am["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v53am["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v53am["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v53am["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v53am["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v53am["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v53am["actual_model_generation_ready"],
    "acceptance_boundary_closed": str(int(all(row["status"] == "ready" for row in stage_rows))),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61do": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "full_return_preflight_acceptance_boundary_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61do_full_return_preflight_acceptance_boundary_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]}
    for row in stage_rows
]
decision_rows.append({"gate": "preflight-is-not-acceptance", "status": "pass" if (preflight_only_gap or not full_preflight_ready) else "blocked", "reason": f"preflight_only_gap_detected={preflight_only_gap}"})
decision_rows.append({"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["stage_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61do Full Return Preflight Acceptance Boundary Gate

This gate proves that full 81-artifact preflight is a logistics condition, not
row-level review/generation acceptance and not actual model generation.

Evidence emitted:

- boundary_stage_rows={len(stage_rows)}
- ready_boundary_stage_rows={ready_stage_rows}
- blocked_boundary_stage_rows={len(stage_rows) - ready_stage_rows}
- critical_preflight_pass_rows={v61dn['critical_preflight_pass_rows']}/{v61dn['critical_artifact_rows']}
- residual_preflight_pass_rows={v61dn['residual_preflight_pass_rows']}/{v61dn['residual_artifact_rows']}
- full_preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}
- return_bundle_preflight_pass={v53al['return_bundle_preflight_pass']}
- preflight_only_gap_detected={preflight_only_gap}
- accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}
- accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}
- answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}
- accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}
- generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}
- generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}
- actual_model_generation_ready={v53am['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61do=0

Allowed wording: full return preflight/acceptance boundary surface is ready.
Blocked wording: row-level review accepted, row-level generation accepted,
actual generation, v1.0 comparison, latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61DO_FULL_RETURN_PREFLIGHT_ACCEPTANCE_BOUNDARY_GATE.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61do-full-return-preflight-acceptance-boundary-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61do_full_return_preflight_acceptance_boundary_gate_ready": 1,
    "ready_boundary_stage_rows": ready_stage_rows,
    "blocked_boundary_stage_rows": len(stage_rows) - ready_stage_rows,
    "full_preflight_pass_rows": as_int(v53al, "preflight_pass_rows"),
    "return_bundle_preflight_pass": as_int(v53al, "return_bundle_preflight_pass"),
    "preflight_only_gap_detected": preflight_only_gap,
    "actual_model_generation_ready": as_int(v53am, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61do_full_return_preflight_acceptance_boundary_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61do_full_return_preflight_acceptance_boundary_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
