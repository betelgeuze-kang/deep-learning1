#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dn_residual_return_completion_gate"
RUN_ID="${V61DN_RUN_ID:-residual_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V61DN_RETURN_BUNDLE_DIR:-}"

if [[ "${V61DN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dn_residual_return_completion_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null
V61DK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dk_return_contract_final_bundle_crosswalk_gate.sh" >/dev/null
if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V61DM_RUN_ID="${RUN_ID}_v61dm" V61DM_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V61DM_REUSE_EXISTING=0 \
    "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null
else
  V61DM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dm_critical_return_acceptance_bridge_gate.sh" >/dev/null
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
    "v61dm_summary": results / "v61dm_critical_return_acceptance_bridge_gate_summary.csv",
    "v61dm_decision": results / "v61dm_critical_return_acceptance_bridge_gate_decision.csv",
    "v53ak_summary": results / "v53ak_complete_source_external_return_operator_checklist_summary.csv",
    "v53ak_checklist": results / "v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_checklist_rows.csv",
    "v53ak_family": results / "v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_family_checklist_rows.csv",
    "v61dk_crosswalk": results / "v61dk_return_contract_final_bundle_crosswalk_gate/crosswalk_001/return_contract_final_bundle_crosswalk_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dn source {key}: {path}")

copy(sources["v61dm_summary"], "source_v61dm/v61dm_critical_return_acceptance_bridge_gate_summary.csv")
copy(sources["v61dm_decision"], "source_v61dm/v61dm_critical_return_acceptance_bridge_gate_decision.csv")
copy(sources["v53ak_summary"], "source_v53ak/v53ak_complete_source_external_return_operator_checklist_summary.csv")
copy(sources["v53ak_checklist"], "source_v53ak/external_return_operator_checklist_rows.csv")
copy(sources["v53ak_family"], "source_v53ak/external_return_operator_family_checklist_rows.csv")
copy(sources["v61dk_crosswalk"], "source_v61dk/return_contract_final_bundle_crosswalk_rows.csv")

v61dm = read_csv(sources["v61dm_summary"])[0]
v53ak = read_csv(sources["v53ak_summary"])[0]
checklist = read_csv(sources["v53ak_checklist"])
crosswalk = read_csv(sources["v61dk_crosswalk"])
if v61dm.get("v61dm_critical_return_acceptance_bridge_gate_ready") != "1":
    raise SystemExit("v61dn requires v61dm ready")
if v53ak.get("v53ak_complete_source_external_return_operator_checklist_ready") != "1":
    raise SystemExit("v61dn requires v53ak ready")

critical_ids = {row["checklist_item_id"] for row in crosswalk}
residual_rows = []
for row in checklist:
    if row["checklist_item_id"] in critical_ids:
        continue
    candidate = return_bundle_dir / row["final_return_bundle_relative_path"] if return_bundle_dir else None
    file_exists = int(candidate is not None and candidate.is_file())
    file_bytes = candidate.stat().st_size if file_exists else 0
    non_empty = int(file_bytes > 0)
    pass_row = int(file_exists and non_empty)
    residual_rows.append(
        {
            "checklist_item_id": row["checklist_item_id"],
            "return_family": row["return_family"],
            "closure_item_id": row["closure_item_id"],
            "downstream_gate": row["downstream_gate"],
            "target_env_var": row["target_env_var"],
            "final_return_bundle_relative_path": row["final_return_bundle_relative_path"],
            "expected_rows": row["expected_rows"],
            "residual_after_critical": "1",
            "file_exists": str(file_exists),
            "file_bytes": str(file_bytes),
            "non_empty_file": str(non_empty),
            "residual_preflight_pass": str(pass_row),
            "sha256": sha256(candidate) if file_exists else "",
            "blocking_reason": "ready" if pass_row else "residual dispatch/review-chunk artifact missing or empty",
        }
    )
write_csv(run_dir / "residual_return_completion_rows.csv", list(residual_rows[0].keys()), residual_rows)

family_rows = []
for family in ["dispatch-receipt", "review-chunk-return"]:
    rows = [row for row in residual_rows if row["return_family"] == family]
    family_rows.append(
        {
            "return_family": family,
            "residual_artifact_rows": str(len(rows)),
            "residual_preflight_pass_rows": str(sum(row["residual_preflight_pass"] == "1" for row in rows)),
            "residual_missing_rows": str(sum(row["file_exists"] == "0" for row in rows)),
            "residual_completion_ready": str(int(rows and all(row["residual_preflight_pass"] == "1" for row in rows))),
        }
    )
write_csv(run_dir / "residual_return_completion_family_rows.csv", list(family_rows[0].keys()), family_rows)

residual_pass_rows = sum(row["residual_preflight_pass"] == "1" for row in residual_rows)
residual_missing_rows = sum(row["file_exists"] == "0" for row in residual_rows)
residual_ready = int(residual_pass_rows == len(residual_rows))
critical_ready = as_int(v61dm, "critical_preflight_ready")
full_preflight_ready = as_int(v61dm, "return_bundle_preflight_pass")
acceptance_ready = as_int(v61dm, "acceptance_bridge_closed")
actual_ready = as_int(v61dm, "actual_model_generation_ready")

stage_rows = [
    {"stage_id": "01-critical-surface", "status": "ready", "actual_value": f"critical_artifact_rows={v61dm['critical_artifact_rows']}", "blocking_reason": "ready"},
    {"stage_id": "02-critical-preflight-pass", "status": "ready" if critical_ready else "blocked", "actual_value": f"critical_preflight_pass_rows={v61dm['critical_preflight_pass_rows']}/{v61dm['critical_artifact_rows']}", "blocking_reason": "critical 10-file preflight has not passed"},
    {"stage_id": "03-residual-surface", "status": "ready", "actual_value": f"residual_artifact_rows={len(residual_rows)}", "blocking_reason": "ready"},
    {"stage_id": "04-residual-completion", "status": "ready" if residual_ready else "blocked", "actual_value": f"residual_preflight_pass_rows={residual_pass_rows}/{len(residual_rows)}", "blocking_reason": "71 residual dispatch/review-chunk artifacts are not complete"},
    {"stage_id": "05-full-return-preflight", "status": "ready" if full_preflight_ready else "blocked", "actual_value": f"full_preflight_pass_rows={v61dm['full_preflight_pass_rows']}/{v61dm['full_preflight_rows']}", "blocking_reason": "full 81-artifact return preflight has not passed"},
    {"stage_id": "06-row-level-acceptance", "status": "ready" if acceptance_ready else "blocked", "actual_value": f"answer_review_accepted_rows={v61dm['answer_review_accepted_rows']}/{v61dm['expected_human_review_rows']}; generation_result_accepted_rows={v61dm['generation_result_accepted_rows']}/{v61dm['generation_result_acceptance_rows']}", "blocking_reason": "review/adjudication/generation rows are not accepted"},
    {"stage_id": "07-actual-generation-ready", "status": "ready" if actual_ready else "blocked", "actual_value": f"actual_model_generation_ready={v61dm['actual_model_generation_ready']}", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "residual_return_completion_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-generate-dispatch-receipts", "ready_to_run_now": "1", "command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh", "expected_transition": "accepted_dispatch_receipt_rows=21"},
    {"command_id": "02-generate-review-chunk-returns", "ready_to_run_now": "1", "command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle/review_chunk_returns V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh", "expected_transition": "accepted_chunk_return_artifact_rows=50"},
    {"command_id": "03-rerun-full-return-preflight", "ready_to_run_now": "1", "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh", "expected_transition": "preflight_pass_rows=81"},
    {"command_id": "04-rerun-acceptance-bridge", "ready_to_run_now": "1", "command": "V61DN_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DN_REUSE_EXISTING=0 ./experiments/run_v61dn_residual_return_completion_gate.sh", "expected_transition": "residual_preflight_pass_rows=71 and full_preflight_pass_rows=81"},
]
write_csv(run_dir / "residual_return_completion_command_rows.csv", list(command_rows[0].keys()), command_rows)

ready_stage_rows = sum(row["status"] == "ready" for row in stage_rows)
metric = {
    "metric_id": "v61dn_residual_return_completion_gate_metrics",
    "v61dm_critical_return_acceptance_bridge_gate_ready": v61dm["v61dm_critical_return_acceptance_bridge_gate_ready"],
    "v53ak_complete_source_external_return_operator_checklist_ready": v53ak["v53ak_complete_source_external_return_operator_checklist_ready"],
    "source_gate_rows": "2",
    "return_bundle_dir_supplied": str(int(return_bundle_dir is not None)),
    "return_bundle_dir_exists": str(int(return_bundle_dir is not None and return_bundle_dir.is_dir())),
    "completion_stage_rows": str(len(stage_rows)),
    "ready_completion_stage_rows": str(ready_stage_rows),
    "blocked_completion_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "completion_command_rows": str(len(command_rows)),
    "ready_completion_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "full_return_artifact_rows": v53ak["checklist_rows"],
    "critical_artifact_rows": v61dm["critical_artifact_rows"],
    "residual_artifact_rows": str(len(residual_rows)),
    "dispatch_receipt_residual_rows": str(sum(row["return_family"] == "dispatch-receipt" for row in residual_rows)),
    "review_chunk_residual_rows": str(sum(row["return_family"] == "review-chunk-return" for row in residual_rows)),
    "residual_preflight_pass_rows": str(residual_pass_rows),
    "residual_missing_rows": str(residual_missing_rows),
    "residual_completion_ready": str(residual_ready),
    "critical_preflight_pass_rows": v61dm["critical_preflight_pass_rows"],
    "critical_preflight_ready": v61dm["critical_preflight_ready"],
    "full_preflight_rows": v61dm["full_preflight_rows"],
    "full_preflight_pass_rows": v61dm["full_preflight_pass_rows"],
    "return_bundle_preflight_pass": v61dm["return_bundle_preflight_pass"],
    "critical_only_gap_detected": v61dm["critical_only_gap_detected"],
    "answer_review_accepted_rows": v61dm["answer_review_accepted_rows"],
    "expected_human_review_rows": v61dm["expected_human_review_rows"],
    "accepted_adjudication_rows": v61dm["accepted_adjudication_rows"],
    "expected_adjudication_rows": v61dm["expected_adjudication_rows"],
    "generation_result_accepted_rows": v61dm["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v61dm["generation_result_acceptance_rows"],
    "acceptance_bridge_closed": v61dm["acceptance_bridge_closed"],
    "actual_model_generation_ready": v61dm["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dn": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "residual_return_completion_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dn_residual_return_completion_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]}
    for row in stage_rows
]
decision_rows.append({"gate": "residual-scope-is-71", "status": "pass" if len(residual_rows) == 71 else "blocked", "reason": f"residual_artifact_rows={len(residual_rows)}"})
decision_rows.append({"gate": "critical-only-is-still-incomplete", "status": "pass" if (as_int(v61dm, "critical_only_gap_detected") or not critical_ready) else "blocked", "reason": f"critical_only_gap_detected={v61dm['critical_only_gap_detected']}"})
decision_rows.append({"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["stage_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dn Residual Return Completion Gate

This gate isolates the residual 71 final-return artifacts that remain after the
10 critical aggregate-review and generation-result artifacts. It does not
accept review rows, generation rows, latency evidence, near-frontier quality, or
release readiness.

Evidence emitted:

- completion_stage_rows={len(stage_rows)}
- ready_completion_stage_rows={ready_stage_rows}
- blocked_completion_stage_rows={len(stage_rows) - ready_stage_rows}
- full_return_artifact_rows={v53ak['checklist_rows']}
- critical_artifact_rows={v61dm['critical_artifact_rows']}
- residual_artifact_rows={len(residual_rows)}
- dispatch_receipt_residual_rows={metric['dispatch_receipt_residual_rows']}
- review_chunk_residual_rows={metric['review_chunk_residual_rows']}
- residual_preflight_pass_rows={residual_pass_rows}/{len(residual_rows)}
- residual_missing_rows={residual_missing_rows}
- residual_completion_ready={residual_ready}
- critical_preflight_pass_rows={v61dm['critical_preflight_pass_rows']}/{v61dm['critical_artifact_rows']}
- full_preflight_pass_rows={v61dm['full_preflight_pass_rows']}/{v61dm['full_preflight_rows']}
- critical_only_gap_detected={v61dm['critical_only_gap_detected']}
- answer_review_accepted_rows={v61dm['answer_review_accepted_rows']}/{v61dm['expected_human_review_rows']}
- accepted_adjudication_rows={v61dm['accepted_adjudication_rows']}/{v61dm['expected_adjudication_rows']}
- generation_result_accepted_rows={v61dm['generation_result_accepted_rows']}/{v61dm['generation_result_acceptance_rows']}
- actual_model_generation_ready={v61dm['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dn=0

Allowed wording: residual return completion queue is defined.
Blocked wording: full return bundle accepted, human/source review accepted,
actual generation, v1.0 comparison, latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61DN_RESIDUAL_RETURN_COMPLETION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dn-residual-return-completion-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dn_residual_return_completion_gate_ready": 1,
    "residual_artifact_rows": len(residual_rows),
    "residual_preflight_pass_rows": residual_pass_rows,
    "residual_completion_ready": residual_ready,
    "critical_preflight_pass_rows": as_int(v61dm, "critical_preflight_pass_rows"),
    "full_preflight_pass_rows": as_int(v61dm, "full_preflight_pass_rows"),
    "acceptance_bridge_closed": as_int(v61dm, "acceptance_bridge_closed"),
    "actual_model_generation_ready": as_int(v61dm, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dn_residual_return_completion_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dn_residual_return_completion_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
