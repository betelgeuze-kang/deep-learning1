#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dy_active_goal_critical_path_runway"
RUN_DIR="$RESULTS_DIR/$PREFIX/runway_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DY_REUSE_EXISTING="${V61DY_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dy_active_goal_critical_path_runway.sh" >/dev/null

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
    raise SystemExit(f"expected one v61dy summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61dy_active_goal_critical_path_runway_ready": "1",
    "v61dx_active_goal_status_audit_gate_ready": "1",
    "v61dw_return_bundle_operator_handoff_bundle_ready": "1",
    "phase_rows": "8",
    "ready_phase_rows": "3",
    "blocked_phase_rows": "5",
    "artifact_family_rows": "4",
    "ready_artifact_family_rows": "3",
    "blocked_artifact_family_rows": "1",
    "return_artifact_rows": "81",
    "review_return_artifact_rows": "76",
    "generation_result_artifact_rows": "5",
    "ready_to_prepare_artifact_rows": "76",
    "blocked_artifact_rows": "5",
    "command_dependency_rows": "9",
    "ready_command_dependency_rows": "4",
    "blocked_command_dependency_rows": "5",
    "next_action_rows": "5",
    "blocked_next_action_rows": "5",
    "unlock_invariant_rows": "6",
    "unlock_invariant_pass_rows": "6",
    "runway_file_rows": "8",
    "metadata_only_runway_file_rows": "8",
    "v52_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "v53_machine_complete_source_surface_ready": "1",
    "v53_ready": "0",
    "accepted_human_review_rows": "0",
    "expected_human_review_rows": "7000",
    "accepted_adjudication_rows": "0",
    "expected_adjudication_rows": "1000",
    "v61_post_full_shard_runtime_evidence_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "runtime_admission_acceptance_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "actual_model_generation_ready": "0",
    "production_latency_claim_ready": "0",
    "near_frontier_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dy": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dy {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "critical_path_phase_rows.csv",
    "critical_path_artifact_family_rows.csv",
    "critical_path_command_dependency_rows.csv",
    "critical_path_next_action_rows.csv",
    "critical_path_unlock_invariant_rows.csv",
    "critical_path_runway_file_rows.csv",
    "critical_path_runway/CRITICAL_PATH_PHASE_ROWS.csv",
    "critical_path_runway/CRITICAL_PATH_ARTIFACT_FAMILIES.csv",
    "critical_path_runway/CRITICAL_PATH_COMMANDS.csv",
    "critical_path_runway/CRITICAL_PATH_NEXT_ACTIONS.csv",
    "critical_path_runway/CRITICAL_PATH_INVARIANTS.csv",
    "critical_path_runway/REVIEW_FIRST_CRITICAL_PATH.md",
    "critical_path_runway/READY_REVIEW_RETURN_COMMANDS.sh",
    "critical_path_runway/RUNWAY_MANIFEST.json",
    "v61dy_active_goal_critical_path_runway_manifest.json",
    "source_v61dx/v61dx_active_goal_status_audit_gate_summary.csv",
    "source_v61dx/active_goal_next_action_rows.csv",
    "source_v61dw/v61dw_return_bundle_operator_handoff_bundle_summary.csv",
    "source_v61dw/RETURN_BUNDLE_ARTIFACT_ROWS.csv",
    "source_v61dw/RETURN_BUNDLE_COMMAND_ROWS.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dy artifact: {rel}")

phases = read_csv(run_dir / "critical_path_phase_rows.csv")
if [row["phase_id"] for row in phases] != [
    "01-active-goal-audit-bound",
    "02-return-handoff-bundle-bound",
    "03-review-return-artifact-preparation",
    "04-full-return-schema-preflight",
    "05-v53-review-return-acceptance",
    "06-generation-execution-admission",
    "07-generation-result-return-acceptance",
    "08-actual-generation-latency-release-claims",
]:
    raise SystemExit("v61dy phase order mismatch")
if sum(row["status"] == "ready" for row in phases) != 3:
    raise SystemExit("v61dy expected three ready phases")
if phases[5]["status"] != "blocked" or phases[5]["required_next_evidence"].find("accepted review return") < 0:
    raise SystemExit("v61dy generation execution phase must be review-blocked")

families = {row["schema_family"]: row for row in read_csv(run_dir / "critical_path_artifact_family_rows.csv")}
expected_families = {
    "aggregate-review-return": ("5", "5", "0", "ready"),
    "dispatch-receipt-json": ("21", "21", "0", "ready"),
    "review-chunk-return-csv": ("50", "50", "0", "ready"),
    "generation-result-return": ("5", "0", "5", "blocked"),
}
for family, (total, ready, blocked, status) in expected_families.items():
    row = families.get(family)
    if not row:
        raise SystemExit(f"v61dy missing artifact family: {family}")
    if (row["artifact_rows"], row["ready_artifact_rows"], row["blocked_artifact_rows"], row["status"]) != (total, ready, blocked, status):
        raise SystemExit(f"v61dy artifact family mismatch: {family}: {row}")

commands = read_csv(run_dir / "critical_path_command_dependency_rows.csv")
if len(commands) != 9:
    raise SystemExit("v61dy expected nine command dependency rows")
if sum(row["status"] == "ready" for row in commands) != 4:
    raise SystemExit("v61dy expected four ready command rows")
if commands[-1]["status"] != "blocked" or "actual_model_generation_ready" not in commands[-1]["expected_transition"]:
    raise SystemExit("v61dy final command must keep actual generation blocked")

actions = read_csv(run_dir / "critical_path_next_action_rows.csv")
if [row["action_id"] for row in actions] != [
    "01-v53s-actual-review-return",
    "02-v61-generation-execution-admission",
    "03-v61-generation-result-return",
    "04-production-latency-report",
    "05-v60-release-audit",
]:
    raise SystemExit("v61dy next-action order mismatch")
if any(row["status"] == "ready" for row in actions):
    raise SystemExit("v61dy next actions should remain blocked/external")

invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "critical_path_unlock_invariant_rows.csv")}
for invariant_id in [
    "v52-f-final-disposition-present",
    "v53-machine-surface-ready-but-review-return-blocked",
    "review-return-precedes-generation-execution",
    "generation-results-precede-actual-generation",
    "review-artifacts-ready-before-generation-result-artifacts",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61dy invariant should pass: {invariant_id}")

runway_files = read_csv(run_dir / "critical_path_runway_file_rows.csv")
if len(runway_files) != 8:
    raise SystemExit("v61dy expected eight runway files")
if any(row["payload_class"] != "metadata-only" for row in runway_files):
    raise SystemExit("v61dy runway files must all be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "active-goal-critical-path-runway",
    "review-return-preparation",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dy decision should pass: {gate}")
for gate in [
    "generation-result-preparation",
    "v53-review-return-accepted",
    "generation-execution-admitted",
    "actual-model-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dy decision should stay blocked: {gate}")

readme = (run_dir / "critical_path_runway/REVIEW_FIRST_CRITICAL_PATH.md").read_text(encoding="utf-8")
for snippet in [
    "external v53 review return must close before generation execution",
    "review-side artifacts ready to prepare: 76",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "No model checkpoint payload",
]:
    if snippet not in readme:
        raise SystemExit(f"v61dy runway readme missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dy_active_goal_critical_path_runway_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dy_active_goal_critical_path_runway_ready") != 1:
    raise SystemExit("v61dy manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dy manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dy manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dy sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dy produced model/checkpoint payload-like files" >&2
  exit 1
fi

"$RUN_DIR/critical_path_runway/READY_REVIEW_RETURN_COMMANDS.sh" >/dev/null

echo "v61dy active goal critical path runway smoke passed"
