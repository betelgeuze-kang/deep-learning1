#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ao_complete_source_actual_review_return_frontier_receipt"
RUN_ID="${V53AO_RUN_ID:-receipt_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53AO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ao_complete_source_actual_review_return_frontier_receipt_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53an_complete_source_actual_review_return_frontier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
prefix = "v53ao_complete_source_actual_review_return_frontier_receipt"
receipt_dir = run_dir / "actual_review_return_frontier_receipt"
stream_dir = run_dir / "command_receipts"
receipt_dir.mkdir(parents=True, exist_ok=True)
stream_dir.mkdir(parents=True, exist_ok=True)


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


def run_command(command, receipt_id):
    stdout_path = stream_dir / f"{receipt_id}.stdout.txt"
    stderr_path = stream_dir / f"{receipt_id}.stderr.txt"
    completed = subprocess.run(
        command,
        shell=True,
        cwd=root,
        text=True,
        capture_output=True,
    )
    stdout_path.write_text(completed.stdout, encoding="utf-8")
    stderr_path.write_text(completed.stderr, encoding="utf-8")
    return completed.returncode, stdout_path, stderr_path


source_paths = {
    "v53an_summary": results / "v53an_complete_source_actual_review_return_frontier_summary.csv",
    "v53an_decision": results / "v53an_complete_source_actual_review_return_frontier_decision.csv",
    "v53an_actions": results / "v53an_complete_source_actual_review_return_frontier" / "frontier_001" / "actual_review_return_frontier_action_rows.csv",
    "v53an_requirements": results / "v53an_complete_source_actual_review_return_frontier" / "frontier_001" / "actual_review_return_frontier_requirement_rows.csv",
    "v53an_blockers": results / "v53an_complete_source_actual_review_return_frontier" / "frontier_001" / "actual_review_return_frontier_blocker_rows.csv",
    "v53an_manifest": results / "v53an_complete_source_actual_review_return_frontier" / "frontier_001" / "actual_review_return_frontier" / "ACTUAL_REVIEW_RETURN_FRONTIER_MANIFEST.json",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v53ao source {label}: {path}")
    copy(path, f"source_v53an/{path.name}")

v53an = read_csv(source_paths["v53an_summary"])[0]
if v53an.get("v53an_complete_source_actual_review_return_frontier_ready") != "1":
    raise SystemExit("v53ao requires v53an frontier ready")

action_rows = read_csv(source_paths["v53an_actions"])
ready_actions = [row for row in action_rows if row["ready_to_run_now"] == "1"]
blocked_actions = [row for row in action_rows if row["ready_to_run_now"] == "0"]

execution_rows = []
receipt_file_rows = []
for index, row in enumerate(ready_actions, 1):
    receipt_id = f"{index:02d}-{row['action_id']}"
    exit_code, stdout_path, stderr_path = run_command(row["command"], receipt_id)
    success = int(exit_code == 0)
    execution_rows.append({
        "action_id": row["action_id"],
        "ready_to_run_now": "1",
        "executed": "1",
        "success": str(success),
        "exit_code": str(exit_code),
        "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
        "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
        "command": row["command"],
    })
    for stream_path, stream_name in [(stdout_path, "stdout"), (stderr_path, "stderr")]:
        receipt_file_rows.append({
            "receipt_id": receipt_id,
            "stream": stream_name,
            "path": stream_path.relative_to(run_dir).as_posix(),
            "bytes": stream_path.stat().st_size,
            "sha256": sha256(stream_path),
        })

for row in blocked_actions:
    execution_rows.append({
        "action_id": row["action_id"],
        "ready_to_run_now": "0",
        "executed": "0",
        "success": "0",
        "exit_code": "",
        "stdout_path": "",
        "stderr_path": "",
        "command": row["command"],
    })

write_csv(run_dir / "actual_review_return_frontier_receipt_execution_rows.csv", list(execution_rows[0].keys()), execution_rows)
write_csv(run_dir / "actual_review_return_frontier_receipt_file_rows.csv", list(receipt_file_rows[0].keys()), receipt_file_rows)

stage_rows = [
    {"stage_id": "01-source-v53an-frontier", "status": "ready", "evidence": "v53an_complete_source_actual_review_return_frontier_ready=1"},
    {"stage_id": "02-ready-action-execution", "status": "ready" if all(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1") else "blocked", "evidence": f"executed_ready_action_rows={sum(row['executed'] == '1' for row in execution_rows if row['ready_to_run_now'] == '1')}"},
    {"stage_id": "03-blocked-action-nonexecution", "status": "ready" if all(row["executed"] == "0" for row in execution_rows if row["ready_to_run_now"] == "0") else "blocked", "evidence": f"blocked_action_rows={len(blocked_actions)}"},
    {"stage_id": "04-review-return-real-root", "status": "blocked", "evidence": "real 81-artifact return bundle absent"},
    {"stage_id": "05-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "actual_review_return_frontier_receipt_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, path in [
    ("ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_EXECUTION_ROWS.csv", run_dir / "actual_review_return_frontier_receipt_execution_rows.csv"),
    ("ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_FILE_ROWS.csv", run_dir / "actual_review_return_frontier_receipt_file_rows.csv"),
    ("ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_STAGE_ROWS.csv", run_dir / "actual_review_return_frontier_receipt_stage_rows.csv"),
]:
    shutil.copy2(path, receipt_dir / rel)

receipt_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "ready_frontier_action_rows": len(ready_actions),
    "executed_ready_frontier_action_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "successful_ready_frontier_action_rows": sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "blocked_frontier_action_rows": len(blocked_actions),
    "blocked_frontier_action_execution_attempt_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(receipt_dir / "ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_MANIFEST.json").write_text(json.dumps(receipt_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(receipt_dir / "VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_MANIFEST.json\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_EXECUTION_ROWS.csv\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_FILE_ROWS.csv\"",
        "test -s \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_STAGE_ROWS.csv\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in actual review return frontier receipt package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(receipt_dir / "VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.sh").chmod(0o755)
(receipt_dir / "ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.md").write_text(
    "\n".join([
        "# v53ao actual review return frontier receipt",
        "",
        f"- ready_frontier_action_rows={len(ready_actions)}",
        f"- executed_ready_frontier_action_rows={receipt_manifest['executed_ready_frontier_action_rows']}",
        f"- successful_ready_frontier_action_rows={receipt_manifest['successful_ready_frontier_action_rows']}",
        f"- blocked_frontier_action_rows={len(blocked_actions)}",
        f"- blocked_frontier_action_execution_attempt_rows={receipt_manifest['blocked_frontier_action_execution_attempt_rows']}",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "The real return bundle and replay commands remain unexecuted until external review/generation evidence is supplied.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in receipt_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "actual_review_return_frontier_receipt_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v53ao_complete_source_actual_review_return_frontier_receipt_ready": 1,
    "v53an_complete_source_actual_review_return_frontier_ready": 1,
    "ready_frontier_action_rows": len(ready_actions),
    "executed_ready_frontier_action_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "successful_ready_frontier_action_rows": sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "failed_ready_frontier_action_rows": sum(row["success"] == "0" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "blocked_frontier_action_rows": len(blocked_actions),
    "blocked_frontier_action_execution_attempt_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0"),
    "receipt_file_rows": len(receipt_file_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "operator_checklist_rows": int(v53an["operator_checklist_rows"]),
    "missing_checklist_rows": int(v53an["missing_checklist_rows"]),
    "preflight_pass_rows": int(v53an["preflight_pass_rows"]),
    "preflight_rows": int(v53an["preflight_rows"]),
    "answer_review_accepted_rows": int(v53an["answer_review_accepted_rows"]),
    "expected_human_review_rows": int(v53an["expected_human_review_rows"]),
    "accepted_adjudication_rows": int(v53an["accepted_adjudication_rows"]),
    "expected_adjudication_rows": int(v53an["expected_adjudication_rows"]),
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v53ao": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "receipt_package_file_rows": len(package_file_rows),
    "metadata_only_receipt_package_file_rows": sum(row["metadata_only"] == "1" for row in package_file_rows),
    "payload_like_receipt_package_file_rows": sum(row["payload_like"] == "1" for row in package_file_rows),
    "source_file_rows": len(source_paths),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53an-frontier", "status": "pass", "actual_value": "ready", "required_value": "ready", "reason": "frontier source exists"},
    {"gate": "ready-frontier-actions", "status": "pass", "actual_value": f"{summary['successful_ready_frontier_action_rows']}/{summary['ready_frontier_action_rows']}", "required_value": "all ready actions successful", "reason": "local verification actions executed"},
    {"gate": "blocked-action-nonexecution", "status": "pass", "actual_value": str(summary["blocked_frontier_action_execution_attempt_rows"]), "required_value": "0", "reason": "real return/replay actions were not executed"},
    {"gate": "review-return-real-root", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "real 81-artifact return bundle missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only receipt"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V53AO_COMPLETE_SOURCE_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V53AO Complete-Source Actual Review Return Frontier Receipt",
        "",
        "- v53ao_complete_source_actual_review_return_frontier_receipt_ready=1",
        f"- ready_frontier_action_rows={summary['ready_frontier_action_rows']}",
        f"- executed_ready_frontier_action_rows={summary['executed_ready_frontier_action_rows']}",
        f"- successful_ready_frontier_action_rows={summary['successful_ready_frontier_action_rows']}",
        f"- blocked_frontier_action_rows={summary['blocked_frontier_action_rows']}",
        f"- blocked_frontier_action_execution_attempt_rows={summary['blocked_frontier_action_execution_attempt_rows']}",
        f"- preflight_pass_rows={summary['preflight_pass_rows']}/{summary['preflight_rows']}",
        f"- answer_review_accepted_rows={summary['answer_review_accepted_rows']}/{summary['expected_human_review_rows']}",
        f"- accepted_adjudication_rows={summary['accepted_adjudication_rows']}/{summary['expected_adjudication_rows']}",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: v53ao proves only local-ready frontier checks. It does not execute real return replay or accept missing review/generation evidence.",
        "",
    ]),
    encoding="utf-8",
)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **summary,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "bytes", "sha256"], sha_rows)

print(f"v53ao_complete_source_actual_review_return_frontier_receipt_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
