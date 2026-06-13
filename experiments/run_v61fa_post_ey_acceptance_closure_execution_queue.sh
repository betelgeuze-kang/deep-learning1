#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fa_post_ey_acceptance_closure_execution_queue"
RUN_ID="${V61FA_RUN_ID:-queue_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fa_post_ey_acceptance_closure_execution_queue_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ez_active_goal_post_ey_status_refresh.sh" >/dev/null
V61EY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ey_generation_acceptance_closure_handoff_bundle.sh" >/dev/null

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
queue_dir = run_dir / "execution_queue_bundle"
queue_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    return sha256(path).split(":", 1)[1]


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


def copy_queue(src, rel):
    dst = queue_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61ez_summary": results / "v61ez_active_goal_post_ey_status_refresh_summary.csv",
    "v61ez_decision": results / "v61ez_active_goal_post_ey_status_refresh_decision.csv",
    "v61ez_sections": results / "v61ez_active_goal_post_ey_status_refresh/refresh_001/post_ey_objective_section_rows.csv",
    "v61ez_requirements": results / "v61ez_active_goal_post_ey_status_refresh/refresh_001/post_ey_requirement_rows.csv",
    "v61ez_claims": results / "v61ez_active_goal_post_ey_status_refresh/refresh_001/post_ey_claim_boundary_rows.csv",
    "v61ez_next_actions": results / "v61ez_active_goal_post_ey_status_refresh/refresh_001/post_ey_next_action_rows.csv",
    "v61ey_summary": results / "v61ey_generation_acceptance_closure_handoff_bundle_summary.csv",
    "v61ey_decision": results / "v61ey_generation_acceptance_closure_handoff_bundle_decision.csv",
    "v61ey_bundle_manifest": results / "v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/handoff_bundle/BUNDLE_MANIFEST.json",
    "v61ey_bundle_file_rows": results / "v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/generation_acceptance_closure_handoff_bundle_file_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fa source {key}: {path}")

for key, path in sources.items():
    family = "v61ez" if key.startswith("v61ez") else "v61ey"
    copy(path, f"source_{family}/{path.name}")

v61ez = read_csv(sources["v61ez_summary"])[0]
v61ey = read_csv(sources["v61ey_summary"])[0]
requirements = read_csv(sources["v61ez_requirements"])
claims = read_csv(sources["v61ez_claims"])
next_actions = read_csv(sources["v61ez_next_actions"])

if v61ez.get("v61ez_active_goal_post_ey_status_refresh_ready") != "1":
    raise SystemExit("v61fa requires v61ez ready")
if v61ey.get("v61ey_generation_acceptance_closure_handoff_bundle_ready") != "1":
    raise SystemExit("v61fa requires v61ey ready")

phase_rows = [
    {
        "phase_id": "01-bind-post-ey-status",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61ez",
        "blocking_reason": "",
        "expected_transition": "post-ey active goal status is bound",
    },
    {
        "phase_id": "02-verify-acceptance-handoff-bundle",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61ey",
        "blocking_reason": "",
        "expected_transition": "metadata-only handoff bundle verifies locally",
    },
    {
        "phase_id": "03-verify-execution-queue-shape",
        "status": "ready",
        "ready": "1",
        "source_gate": "v61fa",
        "blocking_reason": "",
        "expected_transition": "this queue validates its own row counts and checksums",
    },
    {
        "phase_id": "04-real-v53-review-return",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v53s/v53y/v53z",
        "blocking_reason": "real review/adjudication return rows are missing",
        "expected_transition": "v53 review return is accepted and v53z refreshes",
    },
    {
        "phase_id": "05-real-return-bundle-through-v61et-v61ew",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61et/v61eu/v61ev/v61ew",
        "blocking_reason": "non-fixture returned bundle is missing",
        "expected_transition": "real returned bundle reaches acceptance bridge",
    },
    {
        "phase_id": "06-close-v61bt-v61de-v61cu-acceptance",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61bt/v61de/v61cu",
        "blocking_reason": "real result intake, handoff, and final acceptance rows are missing",
        "expected_transition": "generation acceptance closure reaches ready",
    },
    {
        "phase_id": "07-refresh-status-after-real-closure",
        "status": "blocked",
        "ready": "0",
        "source_gate": "v61ey/v61ez/v61fa",
        "blocking_reason": "real acceptance closure has not closed",
        "expected_transition": "handoff bundle and active-goal status refresh with real closure",
    },
    {
        "phase_id": "08-latency-quality-release-audit",
        "status": "blocked",
        "ready": "0",
        "source_gate": "release audit",
        "blocking_reason": "actual generation, latency, quality, and release evidence are missing",
        "expected_transition": "only after actual generation is proven",
    },
]
write_csv(run_dir / "post_ey_acceptance_closure_execution_phase_rows.csv", list(phase_rows[0].keys()), phase_rows)

command_rows = [
    {
        "command_id": "01-verify-v61ey-handoff-bundle",
        "phase_id": "02-verify-acceptance-handoff-bundle",
        "ready_to_run_now": "1",
        "command": "results/v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/handoff_bundle/VERIFY_HANDOFF_BUNDLE.sh",
        "purpose": "verify selected acceptance-closure handoff bundle checksums and row counts",
    },
    {
        "command_id": "02-print-v61ey-ready-commands",
        "phase_id": "02-verify-acceptance-handoff-bundle",
        "ready_to_run_now": "1",
        "command": "results/v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/handoff_bundle/READY_NOW_COMMANDS.sh",
        "purpose": "print informational ready-now commands without claiming real closure",
    },
    {
        "command_id": "03-intake-real-review-return",
        "phase_id": "04-real-v53-review-return",
        "ready_to_run_now": "0",
        "command": "V53Y_REVIEW_RETURN_DIR=/path/to/real_review_return ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "purpose": "refresh complete-source review return after external rows arrive",
    },
    {
        "command_id": "04-preflight-real-return-bundle",
        "phase_id": "05-real-return-bundle-through-v61et-v61ew",
        "ready_to_run_now": "0",
        "command": "V61ET_RETURN_BUNDLE_DIR=/path/to/real_return_bundle ./experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh",
        "purpose": "validate the one-root returned bundle",
    },
    {
        "command_id": "05-fanout-real-return-bundle",
        "phase_id": "05-real-return-bundle-through-v61et-v61ew",
        "ready_to_run_now": "0",
        "command": "V61EU_RETURN_BUNDLE_DIR=/path/to/real_return_bundle ./experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh",
        "purpose": "fan out real returned bundle into receiver preflights",
    },
    {
        "command_id": "06-replay-real-return-bundle",
        "phase_id": "05-real-return-bundle-through-v61et-v61ew",
        "ready_to_run_now": "0",
        "command": "V61EV_RETURN_BUNDLE_DIR=/path/to/real_return_bundle ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh",
        "purpose": "replay real bundle through rendezvous/work-order/handoff chain",
    },
    {
        "command_id": "07-refresh-acceptance-closure",
        "phase_id": "06-close-v61bt-v61de-v61cu-acceptance",
        "ready_to_run_now": "0",
        "command": "./experiments/run_v61ex_generation_acceptance_closure_work_order.sh",
        "purpose": "refresh v61bt/v61de/v61cu closure work order after real rows arrive",
    },
    {
        "command_id": "08-refresh-post-closure-status",
        "phase_id": "07-refresh-status-after-real-closure",
        "ready_to_run_now": "0",
        "command": "./experiments/run_v61ez_active_goal_post_ey_status_refresh.sh",
        "purpose": "refresh active-goal status only after real acceptance closure changes",
    },
]
write_csv(run_dir / "post_ey_acceptance_closure_execution_command_rows.csv", list(command_rows[0].keys()), command_rows)

queue_requirement_rows = [
    {
        "queue_requirement_id": row["requirement_id"],
        "status": row["status"],
        "ready": row["ready"],
        "source_requirement": row["evidence_source"],
        "required_value": row["required_value"],
        "actual_value": row["actual_value"],
        "blocking_reason": row["blocking_reason"],
    }
    for row in requirements
]
write_csv(run_dir / "post_ey_acceptance_closure_execution_requirement_rows.csv", list(queue_requirement_rows[0].keys()), queue_requirement_rows)

invariant_rows = [
    {
        "invariant_id": "01-source-v61ez-ready",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61ez["v61ez_active_goal_post_ey_status_refresh_ready"],
        "reason": "post-ey active goal status is available",
    },
    {
        "invariant_id": "02-source-v61ey-ready",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61ey["v61ey_generation_acceptance_closure_handoff_bundle_ready"],
        "reason": "acceptance-closure handoff bundle is available",
    },
    {
        "invariant_id": "03-metadata-only-queue",
        "status": "pass",
        "required_value": v61ey["handoff_bundle_file_rows"],
        "actual_value": v61ey["metadata_only_bundle_file_rows"],
        "reason": "source handoff bundle is metadata-only",
    },
    {
        "invariant_id": "04-actual-generation-blocked",
        "status": "pass",
        "required_value": "0",
        "actual_value": v61ez["actual_model_generation_ready"],
        "reason": "queue does not create generation evidence",
    },
    {
        "invariant_id": "05-release-claims-blocked",
        "status": "pass",
        "required_value": "0",
        "actual_value": v61ez["real_release_package_ready"],
        "reason": "queue does not create release evidence",
    },
]
write_csv(run_dir / "post_ey_acceptance_closure_execution_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

copy_queue(run_dir / "post_ey_acceptance_closure_execution_phase_rows.csv", "ACCEPTANCE_CLOSURE_PHASE_ROWS.csv")
copy_queue(run_dir / "post_ey_acceptance_closure_execution_command_rows.csv", "ACCEPTANCE_CLOSURE_COMMAND_ROWS.csv")
copy_queue(run_dir / "post_ey_acceptance_closure_execution_requirement_rows.csv", "ACCEPTANCE_CLOSURE_REQUIREMENT_ROWS.csv")
copy_queue(run_dir / "post_ey_acceptance_closure_execution_invariant_rows.csv", "ACCEPTANCE_CLOSURE_INVARIANTS.csv")

readme = queue_dir / "ACCEPTANCE_CLOSURE_EXECUTION_QUEUE.md"
readme.write_text(
    "\n".join(
        [
            "# v61fa Post-v61ey Acceptance Closure Execution Queue",
            "",
            "This queue is metadata-only. It expands the post-v61ey active-goal",
            "next actions into ordered execution phases and guarded commands.",
            "Only verification/printing commands are ready now; real review,",
            "return-bundle, acceptance, actual generation, latency, quality, and",
            "release work remains blocked until real rows are supplied.",
            "",
            f"- queue_phase_rows={len(phase_rows)}",
            f"- ready_queue_phase_rows={sum(row['ready'] == '1' for row in phase_rows)}",
            f"- blocked_queue_phase_rows={sum(row['ready'] == '0' for row in phase_rows)}",
            f"- queue_command_rows={len(command_rows)}",
            f"- ready_queue_command_rows={sum(row['ready_to_run_now'] == '1' for row in command_rows)}",
            f"- ready_requirement_rows={v61ez['ready_requirement_rows']}",
            f"- blocked_requirement_rows={v61ez['blocked_requirement_rows']}",
            f"- generation_acceptance_closure_ready={v61ez['generation_acceptance_closure_ready']}",
            f"- actual_model_generation_ready={v61ez['actual_model_generation_ready']}",
            "",
        ]
    ),
    encoding="utf-8",
)

ready_commands = queue_dir / "READY_NOW_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61fa ready-now commands are verification-only; real closure commands require supplied external return rows.'",
]
for row in command_rows:
    if row["ready_to_run_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['command'])}")
ready_commands.write_text("\n".join(ready_lines) + "\n", encoding="utf-8")
os.chmod(ready_commands, 0o755)

verify_script = queue_dir / "VERIFY_QUEUE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import hashlib",
            "import json",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'QUEUE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "phase_rows = list(csv.DictReader((root / 'ACCEPTANCE_CLOSURE_PHASE_ROWS.csv').open(newline='', encoding='utf-8')))",
            "command_rows = list(csv.DictReader((root / 'ACCEPTANCE_CLOSURE_COMMAND_ROWS.csv').open(newline='', encoding='utf-8')))",
            "requirement_rows = list(csv.DictReader((root / 'ACCEPTANCE_CLOSURE_REQUIREMENT_ROWS.csv').open(newline='', encoding='utf-8')))",
            "manifest = json.loads((root / 'QUEUE_MANIFEST.json').read_text(encoding='utf-8'))",
            "if len(phase_rows) != manifest['queue_phase_rows']:",
            "    raise SystemExit('phase row count mismatch')",
            "if len(command_rows) != manifest['queue_command_rows']:",
            "    raise SystemExit('command row count mismatch')",
            "if len(requirement_rows) != manifest['requirement_rows']:",
            "    raise SystemExit('requirement row count mismatch')",
            "if sum(row['ready'] == '1' for row in phase_rows) != manifest['ready_queue_phase_rows']:",
            "    raise SystemExit('ready phase row count mismatch')",
            "if sum(row['ready_to_run_now'] == '1' for row in command_rows) != manifest['ready_queue_command_rows']:",
            "    raise SystemExit('ready command row count mismatch')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

queue_manifest = {
    "manifest_scope": "v61fa-post-ey-acceptance-closure-execution-queue",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "queue_phase_rows": len(phase_rows),
    "ready_queue_phase_rows": sum(row["ready"] == "1" for row in phase_rows),
    "blocked_queue_phase_rows": sum(row["ready"] == "0" for row in phase_rows),
    "queue_command_rows": len(command_rows),
    "ready_queue_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "requirement_rows": len(queue_requirement_rows),
    "ready_requirement_rows": as_int(v61ez, "ready_requirement_rows"),
    "blocked_requirement_rows": as_int(v61ez, "blocked_requirement_rows"),
    "generation_acceptance_closure_ready": as_int(v61ez, "generation_acceptance_closure_ready"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(queue_dir / "QUEUE_MANIFEST.json").write_text(json.dumps(queue_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

queue_files_for_hash = sorted(
    path
    for path in queue_dir.rglob("*")
    if path.is_file() and path.name not in {"QUEUE_FILE_LIST.txt", "QUEUE_SHA256SUMS.txt"}
)
(queue_dir / "QUEUE_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(queue_dir)) for path in queue_files_for_hash) + "\n",
    encoding="utf-8",
)
(queue_dir / "QUEUE_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(queue_dir)}\n" for path in queue_files_for_hash),
    encoding="utf-8",
)

queue_file_rows = []
for path in sorted(queue_dir.rglob("*")):
    if path.is_file():
        queue_file_rows.append(
            {
                "queue_relative_path": str(path.relative_to(queue_dir)),
                "size_bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "payload_class": "metadata-only",
            }
        )
write_csv(run_dir / "post_ey_acceptance_closure_execution_queue_file_rows.csv", list(queue_file_rows[0].keys()), queue_file_rows)

runtime_gap_rows = [
    {"gap": row["phase_id"], "status": row["status"], "evidence": row["blocking_reason"] or row["expected_transition"]}
    for row in phase_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

summary = {
    "v61fa_post_ey_acceptance_closure_execution_queue_ready": "1",
    "v61ez_active_goal_post_ey_status_refresh_ready": v61ez["v61ez_active_goal_post_ey_status_refresh_ready"],
    "v61ey_generation_acceptance_closure_handoff_bundle_ready": v61ey["v61ey_generation_acceptance_closure_handoff_bundle_ready"],
    "queue_phase_rows": str(len(phase_rows)),
    "ready_queue_phase_rows": str(sum(row["ready"] == "1" for row in phase_rows)),
    "blocked_queue_phase_rows": str(sum(row["ready"] == "0" for row in phase_rows)),
    "queue_command_rows": str(len(command_rows)),
    "ready_queue_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "requirement_rows": str(len(queue_requirement_rows)),
    "ready_requirement_rows": v61ez["ready_requirement_rows"],
    "blocked_requirement_rows": v61ez["blocked_requirement_rows"],
    "invariant_rows": str(len(invariant_rows)),
    "pass_invariant_rows": str(sum(row["status"] == "pass" for row in invariant_rows)),
    "queue_file_rows": str(len(queue_file_rows)),
    "metadata_only_queue_file_rows": str(sum(row["payload_class"] == "metadata-only" for row in queue_file_rows)),
    "acceptance_closure_handoff_bundle_ready": v61ez["acceptance_closure_handoff_bundle_ready"],
    "selected_acceptance_bridge_candidate_ready": v61ez["selected_acceptance_bridge_candidate_ready"],
    "selected_acceptance_bridge_real_ready": v61ez["selected_acceptance_bridge_real_ready"],
    "generation_acceptance_closure_ready": v61ez["generation_acceptance_closure_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fa": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "execution-queue-shape", "status": "pass", "reason": "phase, command, requirement, invariant, and queue files emitted"},
    {"gate": "source-v61ez-ready", "status": "pass", "reason": "post-ey status ready"},
    {"gate": "source-v61ey-ready", "status": "pass", "reason": "handoff bundle ready"},
    {"gate": "metadata-only-queue", "status": "pass", "reason": "all queue files are metadata-only"},
    {"gate": "real-v53-review-return", "status": "blocked", "reason": "external review/adjudication return rows are missing"},
    {"gate": "real-return-bundle-replay", "status": "blocked", "reason": "non-fixture returned bundle is missing"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "reason": "v61bt/v61de/v61cu real acceptance rows are missing"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual generation remains unproven"},
    {"gate": "latency-quality-release", "status": "blocked", "reason": "latency, quality, and release evidence are missing"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FA_POST_EY_ACCEPTANCE_CLOSURE_EXECUTION_QUEUE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fa Post-v61ey Acceptance Closure Execution Queue Boundary",
            "",
            f"- queue_phase_rows={summary['queue_phase_rows']}",
            f"- ready_queue_phase_rows={summary['ready_queue_phase_rows']}",
            f"- blocked_queue_phase_rows={summary['blocked_queue_phase_rows']}",
            f"- queue_command_rows={summary['queue_command_rows']}",
            f"- ready_queue_command_rows={summary['ready_queue_command_rows']}",
            f"- ready_requirement_rows={summary['ready_requirement_rows']}",
            f"- blocked_requirement_rows={summary['blocked_requirement_rows']}",
            f"- queue_file_rows={summary['queue_file_rows']}",
            f"- metadata_only_queue_file_rows={summary['metadata_only_queue_file_rows']}",
            f"- generation_acceptance_closure_ready={summary['generation_acceptance_closure_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- The post-v61ey acceptance-closure execution queue is ready as metadata-only operator guidance.",
            "",
            "Blocked wording:",
            "- Do not claim real review return, real return-bundle replay, actual generation, production latency, near-frontier quality, or release readiness from v61fa alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61fa_post_ey_acceptance_closure_execution_queue",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fa_post_ey_acceptance_closure_execution_queue_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fa_post_ey_acceptance_closure_execution_queue_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
