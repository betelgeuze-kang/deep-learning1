#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ew_downstream_replay_to_acceptance_bridge"
RUN_ID="${V61EW_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REPLAY_RUN_DIR_ARG="${V61EW_REPLAY_RUN_DIR:-}"

if [[ "${V61EW_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ew_downstream_replay_to_acceptance_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ev_return_bundle_downstream_replay_gate.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
V61CU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$REPLAY_RUN_DIR_ARG" <<'PY'
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
replay_arg = sys.argv[5].strip()
results = root / "results"
default_replay_dir = results / "v61ev_return_bundle_downstream_replay_gate" / "replay_001"
replay_dir = Path(replay_arg).expanduser().resolve() if replay_arg else default_replay_dir


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


source_paths = {
    "v61ev_summary": results / "v61ev_return_bundle_downstream_replay_gate_summary.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "v61cu_summary": results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
    "v61ev_stage_rows": replay_dir / "return_bundle_downstream_replay_stage_rows.csv",
    "v61ev_requirement_rows": replay_dir / "return_bundle_downstream_replay_requirement_rows.csv",
    "v61ev_manifest": replay_dir / "v61ev_return_bundle_downstream_replay_gate_manifest.json",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ew source {key}: {path}")
    folder = "selected_replay" if key.startswith("v61ev_") and key not in {"v61ev_summary"} else "source_summaries"
    copy(path, f"{folder}/{path.name}")

v61ev_manifest = json.loads(source_paths["v61ev_manifest"].read_text(encoding="utf-8"))
v61bt = read_csv(source_paths["v61bt_summary"])[0]
v61de = read_csv(source_paths["v61de_summary"])[0]
v61cu = read_csv(source_paths["v61cu_summary"])[0]

downstream_candidate = int(v61ev_manifest.get("downstream_replay_candidate_ready", 0))
downstream_real = int(v61ev_manifest.get("downstream_replay_real_ready", 0))
bt_prereq = as_int(v61bt, "prerequisite_binding_ready")
bt_artifacts = as_int(v61bt, "accepted_generation_result_artifacts")
bt_expected_artifacts = as_int(v61bt, "expected_generation_result_artifacts")
bt_rows = as_int(v61bt, "accepted_generation_rows")
bt_expected_rows = as_int(v61bt, "expected_generation_rows")
de_admitted = as_int(v61de, "generation_execution_admitted_rows")
de_admission_rows = as_int(v61de, "generation_execution_admission_rows")
de_accepted_artifacts = as_int(v61de, "accepted_generation_result_artifacts")
cu_result_accepted = as_int(v61cu, "generation_result_accepted_rows")
cu_acceptance_rows = as_int(v61cu, "generation_result_acceptance_rows")
cu_actual = as_int(v61cu, "actual_model_generation_ready")

bt_acceptance_ready = int(bt_prereq and bt_artifacts == bt_expected_artifacts and bt_rows == bt_expected_rows)
de_handoff_ready = int(de_admitted == de_admission_rows and de_accepted_artifacts == bt_expected_artifacts)
cu_acceptance_ready = int(cu_result_accepted == cu_acceptance_rows and cu_actual)
acceptance_bridge_candidate_ready = int(downstream_candidate)
acceptance_bridge_real_ready = int(downstream_real and bt_acceptance_ready and de_handoff_ready and cu_acceptance_ready)

stage_rows = [
    {"stage_id": "01-downstream-replay-candidate", "status": ready(downstream_candidate), "ready": str(downstream_candidate), "actual_value": f"downstream_candidate={downstream_candidate}", "blocking_reason": "" if downstream_candidate else "v61ev candidate replay is not ready"},
    {"stage_id": "02-downstream-replay-real", "status": ready(downstream_real), "ready": str(downstream_real), "actual_value": f"downstream_real={downstream_real}", "blocking_reason": "" if downstream_real else "v61ev replay is not real/non-fixture"},
    {"stage_id": "03-v61bt-result-intake", "status": ready(bt_acceptance_ready), "ready": str(bt_acceptance_ready), "actual_value": f"prereq={bt_prereq}; artifacts={bt_artifacts}/{bt_expected_artifacts}; rows={bt_rows}/{bt_expected_rows}", "blocking_reason": "" if bt_acceptance_ready else "v61bt has not accepted real result artifacts/rows"},
    {"stage_id": "04-v61de-post-review-handoff", "status": ready(de_handoff_ready), "ready": str(de_handoff_ready), "actual_value": f"admitted={de_admitted}/{de_admission_rows}; artifacts={de_accepted_artifacts}/{bt_expected_artifacts}", "blocking_reason": "" if de_handoff_ready else "v61de has not admitted generation execution/result handoff"},
    {"stage_id": "05-v61cu-result-acceptance", "status": ready(cu_acceptance_ready), "ready": str(cu_acceptance_ready), "actual_value": f"accepted={cu_result_accepted}/{cu_acceptance_rows}; actual={cu_actual}", "blocking_reason": "" if cu_acceptance_ready else "v61cu result acceptance and actual generation remain blocked"},
    {"stage_id": "06-acceptance-bridge-candidate", "status": ready(acceptance_bridge_candidate_ready), "ready": str(acceptance_bridge_candidate_ready), "actual_value": f"candidate={acceptance_bridge_candidate_ready}", "blocking_reason": "" if acceptance_bridge_candidate_ready else "requires downstream candidate replay"},
    {"stage_id": "07-acceptance-bridge-real", "status": ready(acceptance_bridge_real_ready), "ready": str(acceptance_bridge_real_ready), "actual_value": f"real={acceptance_bridge_real_ready}", "blocking_reason": "" if acceptance_bridge_real_ready else "requires real replay plus v61bt/v61de/v61cu acceptance"},
    {"stage_id": "08-actual-generation", "status": "blocked", "ready": "0", "actual_value": "actual_model_generation_ready=0", "blocking_reason": "bridge does not run generation"},
]
write_csv(run_dir / "downstream_replay_to_acceptance_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "downstream-replay-candidate", "status": status(downstream_candidate), "required_value": "1", "actual_value": str(downstream_candidate), "reason": "v61ev candidate replay must pass"},
    {"requirement_id": "downstream-replay-real", "status": status(downstream_real), "required_value": "1", "actual_value": str(downstream_real), "reason": "v61ev replay must be real/non-fixture"},
    {"requirement_id": "v61bt-result-intake", "status": status(bt_acceptance_ready), "required_value": "1", "actual_value": str(bt_acceptance_ready), "reason": "v61bt must accept result artifacts and rows"},
    {"requirement_id": "v61de-post-review-handoff", "status": status(de_handoff_ready), "required_value": "1", "actual_value": str(de_handoff_ready), "reason": "v61de must admit generation execution and handoff"},
    {"requirement_id": "v61cu-result-acceptance", "status": status(cu_acceptance_ready), "required_value": "1", "actual_value": str(cu_acceptance_ready), "reason": "v61cu must accept result rows and actual readiness"},
    {"requirement_id": "acceptance-bridge-candidate", "status": status(acceptance_bridge_candidate_ready), "required_value": "1", "actual_value": str(acceptance_bridge_candidate_ready), "reason": "candidate replay can reach acceptance bridge"},
    {"requirement_id": "acceptance-bridge-real", "status": status(acceptance_bridge_real_ready), "required_value": "1", "actual_value": str(acceptance_bridge_real_ready), "reason": "all acceptance stages must be real and complete"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "downstream_replay_to_acceptance_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

command_rows = [
    {"command_id": "replay-return-bundle-downstream", "command": "V61EV_RETURN_BUNDLE_DIR=<bundle> ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh", "ready_to_run_now": "1", "purpose": "refresh downstream replay"},
    {"command_id": "run-v61bt-result-intake", "command": "Run v61bt with real generation result and prerequisite binding dirs", "ready_to_run_now": str(downstream_real), "purpose": "accept real generation result artifacts"},
    {"command_id": "run-v61de-post-review-handoff", "command": "Run v61de with real review/generation/binding dirs", "ready_to_run_now": str(bt_acceptance_ready), "purpose": "refresh post-review handoff after intake"},
    {"command_id": "run-v61cu-result-acceptance", "command": "Run v61cu after v61bt/v61de accept real rows", "ready_to_run_now": str(de_handoff_ready), "purpose": "accept final result rows"},
    {"command_id": "claim-actual-generation", "command": "Do not claim until acceptance-bridge-real is ready", "ready_to_run_now": str(acceptance_bridge_real_ready), "purpose": "final claim boundary"},
]
write_csv(run_dir / "downstream_replay_to_acceptance_command_rows.csv", list(command_rows[0].keys()), command_rows)

summary = {
    "v61ew_downstream_replay_to_acceptance_bridge_ready": "1",
    "selected_downstream_replay_candidate_ready": str(downstream_candidate),
    "selected_downstream_replay_real_ready": str(downstream_real),
    "v61bt_result_intake_ready": str(bt_acceptance_ready),
    "v61de_post_review_handoff_ready": str(de_handoff_ready),
    "v61cu_result_acceptance_ready": str(cu_acceptance_ready),
    "acceptance_bridge_candidate_ready": str(acceptance_bridge_candidate_ready),
    "acceptance_bridge_real_ready": str(acceptance_bridge_real_ready),
    "accepted_generation_result_artifacts": str(bt_artifacts),
    "expected_generation_result_artifacts": str(bt_expected_artifacts),
    "generation_result_accepted_rows": str(cu_result_accepted),
    "generation_result_acceptance_rows": str(cu_acceptance_rows),
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ew": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "downstream-replay-candidate", "status": status(downstream_candidate), "reason": f"candidate={downstream_candidate}"},
    {"gate": "downstream-replay-real", "status": status(downstream_real), "reason": f"real={downstream_real}"},
    {"gate": "v61bt-result-intake", "status": status(bt_acceptance_ready), "reason": f"v61bt_ready={bt_acceptance_ready}"},
    {"gate": "v61de-post-review-handoff", "status": status(de_handoff_ready), "reason": f"v61de_ready={de_handoff_ready}"},
    {"gate": "v61cu-result-acceptance", "status": status(cu_acceptance_ready), "reason": f"v61cu_ready={cu_acceptance_ready}"},
    {"gate": "acceptance-bridge-real", "status": status(acceptance_bridge_real_ready), "reason": f"acceptance_real={acceptance_bridge_real_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted actual generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata acceptance bridge only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EW_DOWNSTREAM_REPLAY_TO_ACCEPTANCE_BRIDGE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ew Downstream Replay to Acceptance Bridge Boundary",
            "",
            f"- selected_downstream_replay_candidate_ready={downstream_candidate}",
            f"- selected_downstream_replay_real_ready={downstream_real}",
            f"- acceptance_bridge_candidate_ready={acceptance_bridge_candidate_ready}",
            f"- acceptance_bridge_real_ready={acceptance_bridge_real_ready}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- Candidate downstream replay can be compared against the acceptance bridge.",
            "- v61bt/v61de/v61cu blockers are explicitly named.",
            "",
            "Blocked wording:",
            "- Do not claim actual generation, latency, near-frontier quality, or release readiness from v61ew alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61ew-downstream-replay-to-acceptance-bridge",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61ew_downstream_replay_to_acceptance_bridge_ready": 1,
    "acceptance_bridge_candidate_ready": acceptance_bridge_candidate_ready,
    "acceptance_bridge_real_ready": acceptance_bridge_real_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ew_downstream_replay_to_acceptance_bridge_manifest.json").write_text(
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

echo "v61ew_downstream_replay_to_acceptance_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
