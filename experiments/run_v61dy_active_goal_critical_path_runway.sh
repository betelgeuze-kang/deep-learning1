#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dy_active_goal_critical_path_runway"
RUN_ID="${V61DY_RUN_ID:-runway_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dy_active_goal_critical_path_runway_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61dx_active_goal_status_audit_gate_summary.csv" ]]; then
  V61DX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dx_active_goal_status_audit_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61dw_return_bundle_operator_handoff_bundle_summary.csv" ]]; then
  V61DW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dw_return_bundle_operator_handoff_bundle.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
runway_dir = run_dir / "critical_path_runway"
runway_dir.mkdir(parents=True, exist_ok=True)


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


def copy_runway(src, rel):
    dst = runway_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def ready_status(flag):
    return "ready" if flag else "blocked"


sources = {
    "v61dx_summary": results / "v61dx_active_goal_status_audit_gate_summary.csv",
    "v61dx_decision": results / "v61dx_active_goal_status_audit_gate_decision.csv",
    "v61dx_sections": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_objective_section_rows.csv",
    "v61dx_requirements": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_requirement_rows.csv",
    "v61dx_claims": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_claim_boundary_rows.csv",
    "v61dx_next_actions": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_next_action_rows.csv",
    "v61dw_summary": results / "v61dw_return_bundle_operator_handoff_bundle_summary.csv",
    "v61dw_decision": results / "v61dw_return_bundle_operator_handoff_bundle_decision.csv",
    "v61dw_stage": results / "v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/work_order/RETURN_BUNDLE_STAGE_ROWS.csv",
    "v61dw_artifact": results / "v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/work_order/RETURN_BUNDLE_ARTIFACT_ROWS.csv",
    "v61dw_command": results / "v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/work_order/RETURN_BUNDLE_COMMAND_ROWS.csv",
    "v61dw_bundle_manifest": results / "v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/BUNDLE_MANIFEST.json",
    "v61dw_bundle_sha": results / "v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/BUNDLE_SHA256SUMS.txt",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dy source {key}: {path}")

copy(sources["v61dx_summary"], "source_v61dx/v61dx_active_goal_status_audit_gate_summary.csv")
copy(sources["v61dx_decision"], "source_v61dx/v61dx_active_goal_status_audit_gate_decision.csv")
copy(sources["v61dx_sections"], "source_v61dx/active_goal_objective_section_rows.csv")
copy(sources["v61dx_requirements"], "source_v61dx/active_goal_requirement_rows.csv")
copy(sources["v61dx_claims"], "source_v61dx/active_goal_claim_boundary_rows.csv")
copy(sources["v61dx_next_actions"], "source_v61dx/active_goal_next_action_rows.csv")
copy(sources["v61dw_summary"], "source_v61dw/v61dw_return_bundle_operator_handoff_bundle_summary.csv")
copy(sources["v61dw_decision"], "source_v61dw/v61dw_return_bundle_operator_handoff_bundle_decision.csv")
copy(sources["v61dw_stage"], "source_v61dw/RETURN_BUNDLE_STAGE_ROWS.csv")
copy(sources["v61dw_artifact"], "source_v61dw/RETURN_BUNDLE_ARTIFACT_ROWS.csv")
copy(sources["v61dw_command"], "source_v61dw/RETURN_BUNDLE_COMMAND_ROWS.csv")
copy(sources["v61dw_bundle_manifest"], "source_v61dw/BUNDLE_MANIFEST.json")
copy(sources["v61dw_bundle_sha"], "source_v61dw/BUNDLE_SHA256SUMS.txt")

v61dx = read_csv(sources["v61dx_summary"])[0]
v61dw = read_csv(sources["v61dw_summary"])[0]
next_actions = read_csv(sources["v61dx_next_actions"])
artifact_rows = read_csv(sources["v61dw_artifact"])
stage_rows = read_csv(sources["v61dw_stage"])
command_rows = read_csv(sources["v61dw_command"])

if v61dx.get("v61dx_active_goal_status_audit_gate_ready") != "1":
    raise SystemExit("v61dy requires v61dx ready")
if v61dw.get("v61dw_return_bundle_operator_handoff_bundle_ready") != "1":
    raise SystemExit("v61dy requires v61dw ready")

review_return_artifacts = [
    row for row in artifact_rows
    if row["schema_family"] in {
        "dispatch-receipt-json",
        "review-chunk-return-csv",
        "aggregate-review-return",
    }
]
generation_result_artifacts = [
    row for row in artifact_rows
    if row["schema_family"] == "generation-result-return"
]
ready_artifacts = [row for row in artifact_rows if row["ready_to_prepare_now"] == "1"]
blocked_artifacts = [row for row in artifact_rows if row["ready_to_prepare_now"] != "1"]

family_counts = defaultdict(lambda: {"total": 0, "ready": 0, "blocked": 0, "expected_rows": 0})
for row in artifact_rows:
    bucket = family_counts[row["schema_family"]]
    bucket["total"] += 1
    bucket["expected_rows"] += int(row["expected_rows"])
    if row["ready_to_prepare_now"] == "1":
        bucket["ready"] += 1
    else:
        bucket["blocked"] += 1

artifact_family_rows = []
for family, counts in sorted(family_counts.items()):
    ready = counts["ready"] == counts["total"]
    artifact_family_rows.append(
        {
            "schema_family": family,
            "artifact_rows": str(counts["total"]),
            "ready_artifact_rows": str(counts["ready"]),
            "blocked_artifact_rows": str(counts["blocked"]),
            "expected_payload_rows": str(counts["expected_rows"]),
            "status": ready_status(ready),
            "blocking_reason": "" if ready else "generation execution is not admitted yet",
        }
    )
write_csv(
    run_dir / "critical_path_artifact_family_rows.csv",
    list(artifact_family_rows[0].keys()),
    artifact_family_rows,
)
copy_runway(run_dir / "critical_path_artifact_family_rows.csv", "CRITICAL_PATH_ARTIFACT_FAMILIES.csv")

phase_rows = [
    {
        "phase_id": "01-active-goal-audit-bound",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61dx",
        "ready_count": v61dx["ready_objective_requirement_rows"],
        "blocked_count": v61dx["blocked_objective_requirement_rows"],
        "required_next_evidence": "none",
    },
    {
        "phase_id": "02-return-handoff-bundle-bound",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61dw",
        "ready_count": v61dw["metadata_only_bundle_file_rows"],
        "blocked_count": "0",
        "required_next_evidence": "none",
    },
    {
        "phase_id": "03-review-return-artifact-preparation",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61dw",
        "ready_count": str(len(review_return_artifacts)),
        "blocked_count": "0",
        "required_next_evidence": "prepare dispatch, review chunk, and aggregate review return artifacts",
    },
    {
        "phase_id": "04-full-return-schema-preflight",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61dt/v61dr",
        "ready_count": "0",
        "blocked_count": "81",
        "required_next_evidence": "supply all 81 return artifacts to the final return bundle",
    },
    {
        "phase_id": "05-v53-review-return-acceptance",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v53s/v53y/v53am",
        "ready_count": v61dx["accepted_human_review_rows"],
        "blocked_count": v61dx["expected_human_review_rows"],
        "required_next_evidence": "7000 human/source review rows and 1000 adjudication rows",
    },
    {
        "phase_id": "06-generation-execution-admission",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61cs/v61de",
        "ready_count": v61dx["generation_execution_admitted_rows"],
        "blocked_count": v61dx["generation_execution_admission_rows"],
        "required_next_evidence": "accepted review return before guarded generation execution can admit rows",
    },
    {
        "phase_id": "07-generation-result-return-acceptance",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61bt/v61cu",
        "ready_count": v61dx["accepted_generation_result_artifacts"],
        "blocked_count": v61dx["expected_generation_result_artifacts"],
        "required_next_evidence": "five generation result artifacts plus 1000 query result rows",
    },
    {
        "phase_id": "08-actual-generation-latency-release-claims",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61dg/v61dh/v60",
        "ready_count": "0",
        "blocked_count": "4",
        "required_next_evidence": "actual generation, accepted latency, near-frontier review, and release audit evidence",
    },
]
write_csv(run_dir / "critical_path_phase_rows.csv", list(phase_rows[0].keys()), phase_rows)
copy_runway(run_dir / "critical_path_phase_rows.csv", "CRITICAL_PATH_PHASE_ROWS.csv")

command_dependency_rows = []
for row in command_rows:
    command_dependency_rows.append(
        {
            "command_id": row["command_id"],
            "status": ready_status(row["ready_to_run_now"] == "1"),
            "ready_to_run_now": row["ready_to_run_now"],
            "closure_stage_id": row["closure_stage_id"],
            "command": row["command"],
            "expected_transition": row["expected_transition"],
        }
    )
write_csv(run_dir / "critical_path_command_dependency_rows.csv", list(command_dependency_rows[0].keys()), command_dependency_rows)
copy_runway(run_dir / "critical_path_command_dependency_rows.csv", "CRITICAL_PATH_COMMANDS.csv")

next_action_rows = []
for row in next_actions:
    next_action_rows.append(
        {
            "action_id": row["action_id"],
            "status": row["status"],
            "required_artifact": row["required_artifact"],
            "runway_position": str(len(next_action_rows) + 1),
        }
    )
write_csv(run_dir / "critical_path_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)
copy_runway(run_dir / "critical_path_next_action_rows.csv", "CRITICAL_PATH_NEXT_ACTIONS.csv")

unlock_invariant_rows = [
    {
        "invariant_id": "v52-f-final-disposition-present",
        "status": "pass" if v61dx["f_optional_final_disposition"] in {"deferred-with-reason-final", "supplied-evidence-final"} else "fail",
        "expected": "F has explicit final disposition",
        "actual": v61dx["f_optional_final_disposition"],
    },
    {
        "invariant_id": "v53-machine-surface-ready-but-review-return-blocked",
        "status": "pass" if v61dx["v53_machine_complete_source_surface_ready"] == "1" and v61dx["v53_ready"] == "0" else "fail",
        "expected": "machine surface ready and final v53 blocked",
        "actual": f"machine={v61dx['v53_machine_complete_source_surface_ready']};v53_ready={v61dx['v53_ready']}",
    },
    {
        "invariant_id": "review-return-precedes-generation-execution",
        "status": "pass" if v61dx["accepted_human_review_rows"] == "0" and v61dx["generation_execution_admitted_rows"] == "0" else "fail",
        "expected": "generation admission stays 0 until review rows are accepted",
        "actual": f"review={v61dx['accepted_human_review_rows']};generation={v61dx['generation_execution_admitted_rows']}",
    },
    {
        "invariant_id": "generation-results-precede-actual-generation",
        "status": "pass" if v61dx["accepted_generation_result_artifacts"] == "0" and v61dx["actual_model_generation_ready"] == "0" else "fail",
        "expected": "actual generation stays 0 until generation results are accepted",
        "actual": f"result_artifacts={v61dx['accepted_generation_result_artifacts']};actual={v61dx['actual_model_generation_ready']}",
    },
    {
        "invariant_id": "review-artifacts-ready-before-generation-result-artifacts",
        "status": "pass" if len(review_return_artifacts) == 76 and len(generation_result_artifacts) == 5 and len(ready_artifacts) == 76 else "fail",
        "expected": "76 review-side artifacts ready and 5 generation-result artifacts blocked",
        "actual": f"review={len(review_return_artifacts)};generation={len(generation_result_artifacts)};ready={len(ready_artifacts)}",
    },
    {
        "invariant_id": "repo-checkpoint-payload-zero",
        "status": "pass" if v61dx["checkpoint_payload_bytes_committed_to_repo"] == "0" and v61dw["checkpoint_payload_bytes_committed_to_repo"] == "0" else "fail",
        "expected": "no checkpoint payload committed",
        "actual": f"v61dx={v61dx['checkpoint_payload_bytes_committed_to_repo']};v61dw={v61dw['checkpoint_payload_bytes_committed_to_repo']}",
    },
]
write_csv(run_dir / "critical_path_unlock_invariant_rows.csv", list(unlock_invariant_rows[0].keys()), unlock_invariant_rows)
copy_runway(run_dir / "critical_path_unlock_invariant_rows.csv", "CRITICAL_PATH_INVARIANTS.csv")

readme = runway_dir / "REVIEW_FIRST_CRITICAL_PATH.md"
readme.write_text(
    "\n".join(
        [
            "# v61dy Review-First Critical Path",
            "",
            "This runway keeps the active goal ordered around the current blocker:",
            "external v53 review return must close before generation execution,",
            "generation result acceptance, latency, near-frontier, or release claims.",
            "",
            "Ready now:",
            "",
            f"- active goal status audit bound: {v61dx['v61dx_active_goal_status_audit_gate_ready']}",
            f"- return handoff bundle bound: {v61dw['v61dw_return_bundle_operator_handoff_bundle_ready']}",
            f"- review-side artifacts ready to prepare: {len(review_return_artifacts)}",
            "",
            "Blocked:",
            "",
            f"- accepted_human_review_rows={v61dx['accepted_human_review_rows']}/{v61dx['expected_human_review_rows']}",
            f"- accepted_adjudication_rows={v61dx['accepted_adjudication_rows']}/{v61dx['expected_adjudication_rows']}",
            f"- generation_execution_admitted_rows={v61dx['generation_execution_admitted_rows']}/{v61dx['generation_execution_admission_rows']}",
            f"- accepted_generation_result_artifacts={v61dx['accepted_generation_result_artifacts']}/{v61dx['expected_generation_result_artifacts']}",
            f"- actual_model_generation_ready={v61dx['actual_model_generation_ready']}",
            "",
            "No model checkpoint payload is included in this runway.",
            "",
        ]
    ),
    encoding="utf-8",
)

ready_script = runway_dir / "READY_REVIEW_RETURN_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61dy review-first ready commands are informational and require a real /path/to/final_return_bundle.'",
]
for row in command_dependency_rows:
    if row["ready_to_run_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['command'])}")
ready_script.write_text("\n".join(ready_lines) + "\n", encoding="utf-8")
os.chmod(ready_script, 0o755)

runway_manifest = {
    "manifest_scope": "v61dy-active-goal-critical-path-runway",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "phase_rows": len(phase_rows),
    "ready_phase_rows": sum(1 for row in phase_rows if row["status"] == "ready"),
    "blocked_phase_rows": sum(1 for row in phase_rows if row["status"] == "blocked"),
    "artifact_family_rows": len(artifact_family_rows),
    "review_return_artifact_rows": len(review_return_artifacts),
    "generation_result_artifact_rows": len(generation_result_artifacts),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(runway_dir / "RUNWAY_MANIFEST.json").write_text(
    json.dumps(runway_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

runway_files = sorted(path for path in runway_dir.rglob("*") if path.is_file())
write_csv(
    run_dir / "critical_path_runway_file_rows.csv",
    ["runway_relative_path", "size_bytes", "sha256", "payload_class"],
    [
        {
            "runway_relative_path": str(path.relative_to(runway_dir)),
            "size_bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "payload_class": "metadata-only",
        }
        for path in runway_files
    ],
)

ready_phase_rows = sum(1 for row in phase_rows if row["status"] == "ready")
blocked_phase_rows = sum(1 for row in phase_rows if row["status"] == "blocked")
ready_family_rows = sum(1 for row in artifact_family_rows if row["status"] == "ready")
blocked_family_rows = sum(1 for row in artifact_family_rows if row["status"] == "blocked")
ready_commands = sum(1 for row in command_dependency_rows if row["status"] == "ready")
blocked_commands = sum(1 for row in command_dependency_rows if row["status"] == "blocked")
invariant_pass_rows = sum(1 for row in unlock_invariant_rows if row["status"] == "pass")
runway_file_rows = read_csv(run_dir / "critical_path_runway_file_rows.csv")

summary_row = {
    "v61dy_active_goal_critical_path_runway_ready": "1",
    "v61dx_active_goal_status_audit_gate_ready": v61dx["v61dx_active_goal_status_audit_gate_ready"],
    "v61dw_return_bundle_operator_handoff_bundle_ready": v61dw["v61dw_return_bundle_operator_handoff_bundle_ready"],
    "phase_rows": str(len(phase_rows)),
    "ready_phase_rows": str(ready_phase_rows),
    "blocked_phase_rows": str(blocked_phase_rows),
    "artifact_family_rows": str(len(artifact_family_rows)),
    "ready_artifact_family_rows": str(ready_family_rows),
    "blocked_artifact_family_rows": str(blocked_family_rows),
    "return_artifact_rows": str(len(artifact_rows)),
    "review_return_artifact_rows": str(len(review_return_artifacts)),
    "generation_result_artifact_rows": str(len(generation_result_artifacts)),
    "ready_to_prepare_artifact_rows": str(len(ready_artifacts)),
    "blocked_artifact_rows": str(len(blocked_artifacts)),
    "command_dependency_rows": str(len(command_dependency_rows)),
    "ready_command_dependency_rows": str(ready_commands),
    "blocked_command_dependency_rows": str(blocked_commands),
    "next_action_rows": str(len(next_action_rows)),
    "blocked_next_action_rows": str(len(next_action_rows)),
    "unlock_invariant_rows": str(len(unlock_invariant_rows)),
    "unlock_invariant_pass_rows": str(invariant_pass_rows),
    "runway_file_rows": str(len(runway_file_rows)),
    "metadata_only_runway_file_rows": str(sum(1 for row in runway_file_rows if row["payload_class"] == "metadata-only")),
    "v52_ready": v61dx["v52_ready"],
    "f_optional_final_disposition": v61dx["f_optional_final_disposition"],
    "v53_machine_complete_source_surface_ready": v61dx["v53_machine_complete_source_surface_ready"],
    "v53_ready": v61dx["v53_ready"],
    "accepted_human_review_rows": v61dx["accepted_human_review_rows"],
    "expected_human_review_rows": v61dx["expected_human_review_rows"],
    "accepted_adjudication_rows": v61dx["accepted_adjudication_rows"],
    "expected_adjudication_rows": v61dx["expected_adjudication_rows"],
    "v61_post_full_shard_runtime_evidence_ready": v61dx["v61_post_full_shard_runtime_evidence_ready"],
    "runtime_admission_accepted_rows": v61dx["runtime_admission_accepted_rows"],
    "runtime_admission_acceptance_rows": v61dx["runtime_admission_acceptance_rows"],
    "generation_execution_admitted_rows": v61dx["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61dx["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61dx["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61dx["expected_generation_result_artifacts"],
    "actual_model_generation_ready": v61dx["actual_model_generation_ready"],
    "production_latency_claim_ready": v61dx["production_latency_claim_ready"],
    "near_frontier_claim_ready": v61dx["near_frontier_claim_ready"],
    "real_release_package_ready": v61dx["real_release_package_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61dy": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "active-goal-critical-path-runway", "status": "pass", "reason": "phase, artifact-family, command, next-action, and invariant rows emitted", "evidence_source": "v61dx/v61dw"},
    {"gate": "review-return-preparation", "status": "pass", "reason": f"{len(review_return_artifacts)} review-side artifacts are ready to prepare", "evidence_source": "v61dw"},
    {"gate": "generation-result-preparation", "status": "blocked", "reason": f"{len(generation_result_artifacts)} generation result artifacts remain blocked until generation execution is admitted", "evidence_source": "v61dw"},
    {"gate": "v53-review-return-accepted", "status": "blocked", "reason": f"accepted review/adjudication rows {v61dx['accepted_human_review_rows']}/{v61dx['expected_human_review_rows']} and {v61dx['accepted_adjudication_rows']}/{v61dx['expected_adjudication_rows']}", "evidence_source": "v61dx"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61dx['generation_execution_admitted_rows']}/{v61dx['generation_execution_admission_rows']}", "evidence_source": "v61dx"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "review return, generation execution, and generation result acceptance remain blocked", "evidence_source": "v61dx"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "checkpoint payload committed to repo remains zero", "evidence_source": "v61dx/v61dw"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

manifest = {
    "manifest_scope": "v61dy-active-goal-critical-path-runway",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary_row.items()},
}
(run_dir / "v61dy_active_goal_critical_path_runway_manifest.json").write_text(
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
