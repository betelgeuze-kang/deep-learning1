#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fd_post_fc_real_return_closure_delta_ledger"
RUN_ID="${V61FD_RUN_ID:-ledger_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fd_post_fc_real_return_closure_delta_ledger_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null
V61EX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ex_generation_acceptance_closure_work_order.sh" >/dev/null
V53S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null
V53Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
V61CU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh" >/dev/null

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
ledger_dir = run_dir / "real_return_closure_delta_ledger"
ledger_dir.mkdir(parents=True, exist_ok=True)


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


def copy_ledger(src, rel):
    dst = ledger_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v61fc_summary": results / "v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "v61fc_decision": results / "v61fc_post_fb_dual_external_return_operator_packet_decision.csv",
    "v61fc_artifacts": results / "v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_required_artifact_rows.csv",
    "v61fc_families": results / "v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_family_rows.csv",
    "v61fc_stages": results / "v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_stage_rows.csv",
    "v61ex_summary": results / "v61ex_generation_acceptance_closure_work_order_summary.csv",
    "v61ex_blockers": results / "v61ex_generation_acceptance_closure_work_order/work_order_001/generation_acceptance_closure_blocker_rows.csv",
    "v61ex_commands": results / "v61ex_generation_acceptance_closure_work_order/work_order_001/generation_acceptance_closure_command_rows.csv",
    "v53s_summary": results / "v53s_complete_source_review_return_intake_summary.csv",
    "v53y_summary": results / "v53y_complete_source_review_return_refresh_gate_summary.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "v61cu_summary": results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fd source {key}: {path}")

for key, path in source_paths.items():
    if key.startswith("v61fc"):
        folder = "source_v61fc"
    elif key.startswith("v61ex"):
        folder = "source_v61ex"
    elif key.startswith("v53"):
        folder = "source_v53"
    else:
        folder = "source_v61_acceptance"
    copy(path, f"{folder}/{path.name}")

v61fc = read_csv(source_paths["v61fc_summary"])[0]
v61ex = read_csv(source_paths["v61ex_summary"])[0]
v53s = read_csv(source_paths["v53s_summary"])[0]
v53y = read_csv(source_paths["v53y_summary"])[0]
v61bt = read_csv(source_paths["v61bt_summary"])[0]
v61de = read_csv(source_paths["v61de_summary"])[0]
v61cu = read_csv(source_paths["v61cu_summary"])[0]
artifact_rows = read_csv(source_paths["v61fc_artifacts"])
blocker_rows = read_csv(source_paths["v61ex_blockers"])

if v61fc.get("v61fc_post_fb_dual_external_return_operator_packet_ready") != "1":
    raise SystemExit("v61fd requires v61fc ready")
if v61ex.get("v61ex_generation_acceptance_closure_work_order_ready") != "1":
    raise SystemExit("v61fd requires v61ex ready")

v53_artifact_rows = [row for row in artifact_rows if row["return_root_id"] == "v53_external_return_root"]
v61_artifact_rows = [row for row in artifact_rows if row["return_root_id"] == "v61_generation_intake_return_root"]

def delta(delta_id, family, required, accepted, source_gate, blocker, next_action, unit="rows"):
    missing = max(required - accepted, 0)
    return {
        "delta_id": delta_id,
        "family": family,
        "unit": unit,
        "required_count": str(required),
        "accepted_or_supplied_count": str(accepted),
        "missing_count": str(missing),
        "status": "closed" if missing == 0 else "open",
        "source_gate": source_gate,
        "closure_blocker": blocker,
        "next_action": next_action,
    }

delta_rows = [
    delta(
        "01-v53-external-return-artifacts",
        "v53-return-root",
        len(v53_artifact_rows),
        sum(row["accepted_by_v61fc"] == "1" for row in v53_artifact_rows),
        "v61fc/v53ak",
        "real-v53-return-root",
        "supply the 81-artifact v53 external return root",
        "artifacts",
    ),
    delta(
        "02-v61-generation-intake-artifacts",
        "v61-return-root",
        len(v61_artifact_rows),
        sum(row["accepted_by_v61fc"] == "1" for row in v61_artifact_rows),
        "v61fc/v61et",
        "real-v61-return-root",
        "supply the 10-file v61 generation-intake return root",
        "artifacts",
    ),
    delta(
        "03-v53-human-review-rows",
        "v53-review-return",
        as_int(v53s, "expected_human_review_rows"),
        as_int(v53s, "accepted_human_review_rows"),
        "v53s/v53y",
        "v53-review-return-accepted",
        "return 7000 human/source review rows",
    ),
    delta(
        "04-v53-adjudication-rows",
        "v53-review-return",
        as_int(v53s, "expected_adjudication_rows"),
        as_int(v53s, "accepted_adjudication_rows"),
        "v53s/v53y",
        "v53-review-return-accepted",
        "return 1000 adjudication rows",
    ),
    delta(
        "05-v53-reviewer-identity-rows",
        "v53-review-return",
        as_int(v53s, "expected_reviewer_identity_rows"),
        as_int(v53s, "accepted_reviewer_identity_rows"),
        "v53s",
        "reviewer-identity-ready",
        "return reviewer identity assignment rows",
    ),
    delta(
        "06-v53-conflict-disclosure-rows",
        "v53-review-return",
        as_int(v53s, "expected_conflict_disclosure_rows"),
        as_int(v53s, "accepted_conflict_disclosure_rows"),
        "v53s",
        "conflict-disclosure-ready",
        "return assignment-repo conflict disclosure rows",
    ),
    delta(
        "07-v53-aggregate-review-artifacts",
        "v53-review-return",
        as_int(v53y, "aggregate_review_return_artifact_rows"),
        as_int(v53y, "accepted_aggregate_review_return_artifact_rows"),
        "v53y",
        "aggregate-review-return",
        "return five aggregate review artifacts",
        "artifacts",
    ),
    delta(
        "08-v61-prerequisite-binding-files",
        "v61-generation-intake",
        len([row for row in v61_artifact_rows if row["return_family"] == "prerequisite-binding"]),
        0,
        "v61et/v61el/v61bt",
        "04-v61bt-prerequisite-binding",
        "return three non-fixture prerequisite binding summaries",
        "artifacts",
    ),
    delta(
        "09-v61-generation-result-artifacts",
        "v61-generation-result",
        as_int(v61bt, "expected_generation_result_artifacts"),
        as_int(v61bt, "accepted_generation_result_artifacts"),
        "v61bt/v61de",
        "05-v61bt-result-artifacts",
        "return five real generation-result artifacts",
        "artifacts",
    ),
    delta(
        "10-v61-generation-result-rows",
        "v61-generation-result",
        as_int(v61bt, "expected_generation_rows"),
        as_int(v61bt, "accepted_generation_rows"),
        "v61bt",
        "06-v61bt-result-rows",
        "return 1000 accepted source-bound generation rows",
    ),
    delta(
        "11-v61-generation-execution-admission",
        "v61-generation-execution",
        as_int(v61de, "generation_execution_admission_rows"),
        as_int(v61de, "generation_execution_admitted_rows"),
        "v61de",
        "09-v61de-generation-execution",
        "admit generation execution after accepted review/result prerequisites",
    ),
    delta(
        "12-v61-final-result-acceptance",
        "v61-final-acceptance",
        as_int(v61cu, "generation_result_acceptance_rows"),
        as_int(v61cu, "generation_result_accepted_rows"),
        "v61cu",
        "12-v61cu-result-rows",
        "accept 1000 final generation result rows",
    ),
    delta(
        "13-dual-real-return-roots",
        "dual-real-preflight",
        2,
        as_int(v61fc, "dual_external_return_real_ready") * 2,
        "v61fb/v61fc",
        "dual-external-return-real",
        "supply both real roots with explicit provenance",
        "roots",
    ),
    delta(
        "14-actual-generation-claim",
        "claim",
        1,
        as_int(v61cu, "actual_model_generation_ready"),
        "v61cu",
        "actual-generation",
        "claim actual generation only after acceptance closure reaches ready",
        "claim",
    ),
]
write_csv(run_dir / "post_fc_real_return_closure_delta_rows.csv", list(delta_rows[0].keys()), delta_rows)
copy_ledger(run_dir / "post_fc_real_return_closure_delta_rows.csv", "REAL_RETURN_CLOSURE_DELTA_ROWS.csv")

ledger_blocker_rows = [
    {
        "blocker_id": row["blocker_id"],
        "family": row["family"],
        "blocking_reason": row["blocking_reason"],
        "actual_value": row["actual_value"],
        "source_gate": "v61ex",
    }
    for row in blocker_rows
]
write_csv(run_dir / "post_fc_real_return_closure_blocker_rows.csv", list(ledger_blocker_rows[0].keys()), ledger_blocker_rows)
copy_ledger(run_dir / "post_fc_real_return_closure_blocker_rows.csv", "REAL_RETURN_CLOSURE_BLOCKER_ROWS.csv")

command_rows = [
    {
        "command_id": "01-verify-v61fc-packet",
        "ready_to_run_now": "1",
        "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/VERIFY_DUAL_RETURN_PACKET.sh",
        "purpose": "verify the 91-artifact operator packet",
    },
    {
        "command_id": "02-print-v61fc-ready-commands",
        "ready_to_run_now": "1",
        "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/READY_NOW_COMMANDS.sh",
        "purpose": "print metadata-only ready commands",
    },
    {
        "command_id": "03-run-dual-real-preflight",
        "ready_to_run_now": "0",
        "command": "V61FB_V53_RETURN_BUNDLE_DIR=<v53-return-root> V61FB_V53_RETURN_PROVENANCE=real-external-return-bundle V61FB_V61_RETURN_BUNDLE_DIR=<v61-return-root> V61FB_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle ./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh",
        "purpose": "prove both external roots are real and mechanically complete",
    },
    {
        "command_id": "04-replay-v53-return-acceptance",
        "ready_to_run_now": "0",
        "command": "V53AM_RETURN_BUNDLE_DIR=<v53-return-root> ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
        "purpose": "replay complete-source return acceptance after real rows arrive",
    },
    {
        "command_id": "05-replay-v61-return-acceptance",
        "ready_to_run_now": "0",
        "command": "V61EV_RETURN_BUNDLE_DIR=<v61-return-root> ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh",
        "purpose": "replay v61 generation-intake return downstream",
    },
    {
        "command_id": "06-refresh-v61ex-closure",
        "ready_to_run_now": "0",
        "command": "./experiments/run_v61ex_generation_acceptance_closure_work_order.sh",
        "purpose": "refresh closure deltas after real rows change",
    },
    {
        "command_id": "07-refresh-v61fd-ledger",
        "ready_to_run_now": "1",
        "command": "./experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh",
        "purpose": "refresh this ledger after any upstream return/preflight rerun",
    },
]
write_csv(run_dir / "post_fc_real_return_closure_command_rows.csv", list(command_rows[0].keys()), command_rows)
copy_ledger(run_dir / "post_fc_real_return_closure_command_rows.csv", "REAL_RETURN_CLOSURE_COMMAND_ROWS.csv")

invariant_rows = [
    {"invariant_id": "01-v61fc-ready", "status": "pass", "required_value": "1", "actual_value": v61fc["v61fc_post_fb_dual_external_return_operator_packet_ready"], "reason": "operator packet exists"},
    {"invariant_id": "02-v61ex-ready", "status": "pass", "required_value": "1", "actual_value": v61ex["v61ex_generation_acceptance_closure_work_order_ready"], "reason": "closure blocker work order exists"},
    {"invariant_id": "03-no-row-acceptance-by-v61fd", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "ledger is metadata-only"},
    {"invariant_id": "04-actual-generation-blocked", "status": "pass", "required_value": "0", "actual_value": v61cu["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
    {"invariant_id": "05-repo-payload-zero", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "ledger contains no checkpoint payload"},
]
write_csv(run_dir / "post_fc_real_return_closure_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)
copy_ledger(run_dir / "post_fc_real_return_closure_invariant_rows.csv", "REAL_RETURN_CLOSURE_INVARIANTS.csv")

frontier = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "next_frontier": "real external return rows",
    "v53_required_artifact_rows": len(v53_artifact_rows),
    "v61_required_artifact_rows": len(v61_artifact_rows),
    "dual_required_artifact_rows": len(artifact_rows),
    "open_delta_rows": sum(row["status"] == "open" for row in delta_rows),
    "open_closure_blocker_rows": len(ledger_blocker_rows),
    "missing_human_review_rows": as_int(v53s, "expected_human_review_rows") - as_int(v53s, "accepted_human_review_rows"),
    "missing_adjudication_rows": as_int(v53s, "expected_adjudication_rows") - as_int(v53s, "accepted_adjudication_rows"),
    "missing_generation_result_artifacts": as_int(v61bt, "expected_generation_result_artifacts") - as_int(v61bt, "accepted_generation_result_artifacts"),
    "missing_generation_result_rows": as_int(v61bt, "expected_generation_rows") - as_int(v61bt, "accepted_generation_rows"),
    "missing_generation_execution_admission_rows": as_int(v61de, "generation_execution_admission_rows") - as_int(v61de, "generation_execution_admitted_rows"),
    "missing_final_acceptance_rows": as_int(v61cu, "generation_result_acceptance_rows") - as_int(v61cu, "generation_result_accepted_rows"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(ledger_dir / "REAL_RETURN_CLOSURE_FRONTIER.json").write_text(json.dumps(frontier, indent=2, sort_keys=True) + "\n", encoding="utf-8")

readme = ledger_dir / "REAL_RETURN_CLOSURE_DELTA_LEDGER.md"
readme.write_text(
    "\n".join(
        [
            "# v61fd Real Return Closure Delta Ledger",
            "",
            "This ledger is metadata-only. It joins the v61fc 91-artifact",
            "operator packet to the v61ex acceptance-closure blockers and records",
            "the exact missing rows/files before actual generation can move.",
            "",
            f"- delta_rows={len(delta_rows)}",
            f"- open_delta_rows={frontier['open_delta_rows']}",
            f"- v53_required_artifact_rows={len(v53_artifact_rows)}",
            f"- v61_required_artifact_rows={len(v61_artifact_rows)}",
            f"- dual_required_artifact_rows={len(artifact_rows)}",
            f"- open_closure_blocker_rows={len(ledger_blocker_rows)}",
            f"- missing_human_review_rows={frontier['missing_human_review_rows']}",
            f"- missing_adjudication_rows={frontier['missing_adjudication_rows']}",
            f"- missing_generation_result_artifacts={frontier['missing_generation_result_artifacts']}",
            f"- missing_generation_result_rows={frontier['missing_generation_result_rows']}",
            f"- missing_generation_execution_admission_rows={frontier['missing_generation_execution_admission_rows']}",
            f"- missing_final_acceptance_rows={frontier['missing_final_acceptance_rows']}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fd identifies the exact remaining real-return closure deltas.",
            "",
            "Blocked wording:",
            "- Do not claim row acceptance, actual generation, latency, quality, or release readiness from v61fd.",
            "",
        ]
    ),
    encoding="utf-8",
)

ready_commands = ledger_dir / "READY_NOW_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61fd ready-now commands are verification/ledger refresh only; real closure requires supplied external return roots.'",
]
for row in command_rows:
    if row["ready_to_run_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['command'])}")
ready_commands.write_text("\n".join(ready_lines) + "\n", encoding="utf-8")
os.chmod(ready_commands, 0o755)

env_template = ledger_dir / "REAL_RETURN_REPLAY_ENV_TEMPLATE.sh"
env_template.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "export V61FB_V53_RETURN_BUNDLE_DIR=/path/to/v53_external_return_root",
            "export V61FB_V53_RETURN_PROVENANCE=real-external-return-bundle",
            "export V61FB_V61_RETURN_BUNDLE_DIR=/path/to/v61_generation_intake_return_root",
            "export V61FB_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle",
            "export V53AM_RETURN_BUNDLE_DIR=\"$V61FB_V53_RETURN_BUNDLE_DIR\"",
            "export V61EV_RETURN_BUNDLE_DIR=\"$V61FB_V61_RETURN_BUNDLE_DIR\"",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(env_template, 0o755)

manifest = {
    "manifest_scope": "v61fd-post-fc-real-return-closure-delta-ledger",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "delta_rows": len(delta_rows),
    "open_delta_rows": frontier["open_delta_rows"],
    "closed_delta_rows": len(delta_rows) - frontier["open_delta_rows"],
    "v53_required_artifact_rows": len(v53_artifact_rows),
    "v61_required_artifact_rows": len(v61_artifact_rows),
    "dual_required_artifact_rows": len(artifact_rows),
    "open_closure_blocker_rows": len(ledger_blocker_rows),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(ledger_dir / "DELTA_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = ledger_dir / "VERIFY_DELTA_LEDGER.sh"
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
            "for line in (root / 'DELTA_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'DELTA_MANIFEST.json').read_text(encoding='utf-8'))",
            "frontier = json.loads((root / 'REAL_RETURN_CLOSURE_FRONTIER.json').read_text(encoding='utf-8'))",
            "delta_rows = list(csv.DictReader((root / 'REAL_RETURN_CLOSURE_DELTA_ROWS.csv').open(newline='', encoding='utf-8')))",
            "blocker_rows = list(csv.DictReader((root / 'REAL_RETURN_CLOSURE_BLOCKER_ROWS.csv').open(newline='', encoding='utf-8')))",
            "command_rows = list(csv.DictReader((root / 'REAL_RETURN_CLOSURE_COMMAND_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(delta_rows) != manifest['delta_rows']:",
            "    raise SystemExit('delta row count mismatch')",
            "if sum(row['status'] == 'open' for row in delta_rows) != manifest['open_delta_rows']:",
            "    raise SystemExit('open delta row count mismatch')",
            "if len(blocker_rows) != manifest['open_closure_blocker_rows']:",
            "    raise SystemExit('blocker row count mismatch')",
            "if frontier['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "if manifest['checkpoint_payload_bytes_committed_to_repo'] != 0:",
            "    raise SystemExit('checkpoint payload must remain zero')",
            "if sum(row['ready_to_run_now'] == '1' for row in command_rows) < 1:",
            "    raise SystemExit('expected at least one safe ready command')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

ledger_files_for_hash = sorted(
    path
    for path in ledger_dir.rglob("*")
    if path.is_file() and path.name not in {"DELTA_FILE_LIST.txt", "DELTA_SHA256SUMS.txt"}
)
(ledger_dir / "DELTA_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(ledger_dir)) for path in ledger_files_for_hash) + "\n",
    encoding="utf-8",
)
ledger_files_for_hash = sorted(
    path
    for path in ledger_dir.rglob("*")
    if path.is_file() and path.name != "DELTA_SHA256SUMS.txt"
)
(ledger_dir / "DELTA_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(ledger_dir)}\n" for path in ledger_files_for_hash),
    encoding="utf-8",
)

ledger_file_rows = len(ledger_files_for_hash)
metadata_only_ledger_file_rows = ledger_file_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
open_delta_rows = frontier["open_delta_rows"]
missing_external_return_artifacts = len(artifact_rows)

summary = {
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": "1",
    "v61fc_post_fb_dual_external_return_operator_packet_ready": v61fc["v61fc_post_fb_dual_external_return_operator_packet_ready"],
    "v61ex_generation_acceptance_closure_work_order_ready": v61ex["v61ex_generation_acceptance_closure_work_order_ready"],
    "delta_rows": str(len(delta_rows)),
    "open_delta_rows": str(open_delta_rows),
    "closed_delta_rows": str(len(delta_rows) - open_delta_rows),
    "v53_required_artifact_rows": str(len(v53_artifact_rows)),
    "v61_required_artifact_rows": str(len(v61_artifact_rows)),
    "dual_required_artifact_rows": str(len(artifact_rows)),
    "missing_external_return_artifacts": str(missing_external_return_artifacts),
    "open_closure_blocker_rows": str(len(ledger_blocker_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "ledger_file_rows": str(ledger_file_rows),
    "metadata_only_ledger_file_rows": str(metadata_only_ledger_file_rows),
    "missing_human_review_rows": str(frontier["missing_human_review_rows"]),
    "missing_adjudication_rows": str(frontier["missing_adjudication_rows"]),
    "missing_reviewer_identity_rows": str(as_int(v53s, "expected_reviewer_identity_rows") - as_int(v53s, "accepted_reviewer_identity_rows")),
    "missing_conflict_disclosure_rows": str(as_int(v53s, "expected_conflict_disclosure_rows") - as_int(v53s, "accepted_conflict_disclosure_rows")),
    "missing_generation_result_artifacts": str(frontier["missing_generation_result_artifacts"]),
    "missing_generation_result_rows": str(frontier["missing_generation_result_rows"]),
    "missing_generation_execution_admission_rows": str(frontier["missing_generation_execution_admission_rows"]),
    "missing_final_acceptance_rows": str(frontier["missing_final_acceptance_rows"]),
    "dual_external_return_real_ready": v61fc["dual_external_return_real_ready"],
    "generation_acceptance_closure_ready": v61ex["generation_acceptance_closure_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61fc-ready", "status": "pass", "reason": "operator packet exists"},
    {"gate": "source-v61ex-ready", "status": "pass", "reason": "acceptance closure work order exists"},
    {"gate": "delta-ledger-shape", "status": "pass", "reason": f"{len(delta_rows)} delta rows emitted"},
    {"gate": "ledger-packet", "status": "pass", "reason": f"{ledger_file_rows} metadata-only ledger files emitted"},
    {"gate": "dual-external-return-real", "status": "blocked", "reason": "real external roots are missing"},
    {"gate": "v53-review-return", "status": "blocked", "reason": f"missing_human_review_rows={frontier['missing_human_review_rows']}"},
    {"gate": "v61-generation-result-return", "status": "blocked", "reason": f"missing_generation_result_rows={frontier['missing_generation_result_rows']}"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "reason": "closure blockers remain open"},
    {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata ledger only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FD_POST_FC_REAL_RETURN_CLOSURE_DELTA_LEDGER_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fd Post-v61fc Real Return Closure Delta Ledger Boundary",
            "",
            f"- delta_rows={len(delta_rows)}",
            f"- open_delta_rows={open_delta_rows}",
            f"- dual_required_artifact_rows={len(artifact_rows)}",
            f"- missing_external_return_artifacts={missing_external_return_artifacts}",
            f"- missing_human_review_rows={frontier['missing_human_review_rows']}",
            f"- missing_adjudication_rows={frontier['missing_adjudication_rows']}",
            f"- missing_generation_result_artifacts={frontier['missing_generation_result_artifacts']}",
            f"- missing_generation_result_rows={frontier['missing_generation_result_rows']}",
            f"- missing_generation_execution_admission_rows={frontier['missing_generation_execution_admission_rows']}",
            f"- missing_final_acceptance_rows={frontier['missing_final_acceptance_rows']}",
            "- generation_acceptance_closure_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fd identifies the real-return closure deltas that remain after v61fc.",
            "",
            "Blocked wording:",
            "- Do not claim row acceptance, actual generation, latency, quality, or release readiness from v61fd alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fd_post_fc_real_return_closure_delta_ledger",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fd_post_fc_real_return_closure_delta_ledger_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fd_post_fc_real_return_closure_delta_ledger_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
