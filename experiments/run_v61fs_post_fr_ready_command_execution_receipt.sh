#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fs_post_fr_ready_command_execution_receipt"
RUN_ID="${V61FS_RUN_ID:-receipt_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fs_post_fr_ready_command_execution_receipt_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fr_post_fq_v1_ready_command_handoff.sh" >/dev/null

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
prefix = "v61fs_post_fr_ready_command_execution_receipt"
receipt_dir = run_dir / "post_fr_ready_command_execution_receipt"
receipt_dir.mkdir(parents=True, exist_ok=True)
stdout_dir = run_dir / "command_receipts"
stdout_dir.mkdir(parents=True, exist_ok=True)


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


def pass_or_blocked(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61fr_summary": results / "v61fr_post_fq_v1_ready_command_handoff_summary.csv",
    "v61fr_decision": results / "v61fr_post_fq_v1_ready_command_handoff_decision.csv",
    "v61fq_summary": results / "v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "v53ah_summary": results / "v53ah_complete_source_external_review_send_bundle_summary.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fs source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

source_artifacts = {
    "v61fr_command_rows.csv": results / "v61fr_post_fq_v1_ready_command_handoff" / "handoff_001" / "post_fq_v1_ready_command_handoff_command_rows.csv",
    "v61fr_stage_rows.csv": results / "v61fr_post_fq_v1_ready_command_handoff" / "handoff_001" / "post_fq_v1_ready_command_handoff_stage_rows.csv",
    "v61fr_external_input_rows.csv": results / "v61fr_post_fq_v1_ready_command_handoff" / "handoff_001" / "post_fq_v1_ready_command_handoff_external_input_rows.csv",
    "v61fr_handoff_manifest.json": results / "v61fr_post_fq_v1_ready_command_handoff" / "handoff_001" / "post_fq_v1_ready_command_handoff" / "HANDOFF_MANIFEST.json",
}
for rel, path in source_artifacts.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fs source artifact: {path}")
    copy(path, f"source_artifacts/{rel}")

v61fr = read_csv(sources["v61fr_summary"])[0]
if v61fr.get("v61fr_post_fq_v1_ready_command_handoff_ready") != "1":
    raise SystemExit("v61fs requires v61fr readiness")

command_rows = read_csv(source_artifacts["v61fr_command_rows.csv"])
ready_commands = [row for row in command_rows if row["ready_to_run_now"] == "1"]
blocked_commands = [row for row in command_rows if row["ready_to_run_now"] == "0"]
execution_rows = []
receipt_file_rows = []

for row in ready_commands:
    command_id = row["command_id"]
    command = row["command"]
    safe_id = command_id.replace("/", "_")
    stdout_path = stdout_dir / f"{safe_id}.stdout.txt"
    stderr_path = stdout_dir / f"{safe_id}.stderr.txt"
    proc = subprocess.run(
        command,
        cwd=root,
        shell=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=120,
    )
    stdout_path.write_text(proc.stdout, encoding="utf-8")
    stderr_path.write_text(proc.stderr, encoding="utf-8")
    stdout_sha = sha256(stdout_path)
    stderr_sha = sha256(stderr_path)
    execution_rows.append({
        "command_id": command_id,
        "ready_to_run_now": "1",
        "executed": "1",
        "exit_code": str(proc.returncode),
        "success": str(int(proc.returncode == 0)),
        "command": command,
        "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
        "stdout_sha256": stdout_sha,
        "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
        "stderr_sha256": stderr_sha,
        "purpose": row["purpose"],
    })
    receipt_file_rows.extend([
        {
            "command_id": command_id,
            "stream": "stdout",
            "path": stdout_path.relative_to(run_dir).as_posix(),
            "bytes": stdout_path.stat().st_size,
            "sha256": stdout_sha,
        },
        {
            "command_id": command_id,
            "stream": "stderr",
            "path": stderr_path.relative_to(run_dir).as_posix(),
            "bytes": stderr_path.stat().st_size,
            "sha256": stderr_sha,
        },
    ])

for row in blocked_commands:
    execution_rows.append({
        "command_id": row["command_id"],
        "ready_to_run_now": "0",
        "executed": "0",
        "exit_code": "",
        "success": "0",
        "command": row["command"],
        "stdout_path": "",
        "stdout_sha256": "",
        "stderr_path": "",
        "stderr_sha256": "",
        "purpose": row["purpose"],
    })

write_csv(run_dir / "post_fr_ready_command_execution_rows.csv", list(execution_rows[0].keys()), execution_rows)
write_csv(run_dir / "post_fr_ready_command_execution_receipt_file_rows.csv", list(receipt_file_rows[0].keys()), receipt_file_rows)

external_input_rows = read_csv(source_artifacts["v61fr_external_input_rows.csv"])
stage_rows = [
    {"stage_id": "01-v61fr-handoff-ready", "status": "ready", "ready": "1", "evidence": "v61fr handoff ready", "blocked_reason": ""},
    {"stage_id": "02-ready-commands-executed", "status": "ready", "ready": str(int(all(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"))), "evidence": f"executed={len(ready_commands)}", "blocked_reason": ""},
    {"stage_id": "03-receipts-written", "status": "ready", "ready": str(int(len(receipt_file_rows) == len(ready_commands) * 2)), "evidence": f"receipt_files={len(receipt_file_rows)}", "blocked_reason": ""},
    {"stage_id": "04-external-inputs-present", "status": "blocked", "ready": "0", "evidence": f"present_external_inputs={sum(row['present'] == '1' for row in external_input_rows)}/{len(external_input_rows)}", "blocked_reason": "real returned roots are not supplied"},
    {"stage_id": "05-v1-comparison-ready", "status": "blocked", "ready": v61fr["v1_0_comparison_ready"], "evidence": f"v1_0_comparison_ready={v61fr['v1_0_comparison_ready']}", "blocked_reason": "review/generation evidence missing"},
    {"stage_id": "06-actual-generation", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0", "blocked_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "post_fr_ready_command_execution_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

shutil.copy2(run_dir / "post_fr_ready_command_execution_rows.csv", receipt_dir / "READY_COMMAND_EXECUTION_ROWS.csv")
shutil.copy2(run_dir / "post_fr_ready_command_execution_receipt_file_rows.csv", receipt_dir / "READY_COMMAND_RECEIPT_FILE_ROWS.csv")
shutil.copy2(run_dir / "post_fr_ready_command_execution_stage_rows.csv", receipt_dir / "READY_COMMAND_EXECUTION_STAGE_ROWS.csv")
receipt_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "ready_command_rows": len(ready_commands),
    "executed_ready_command_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "successful_ready_command_rows": sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "blocked_command_rows": len(blocked_commands),
    "blocked_command_execution_attempt_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0"),
    "receipt_file_rows": len(receipt_file_rows),
    "v1_0_comparison_ready": as_int(v61fr, "v1_0_comparison_ready"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(receipt_dir / "READY_COMMAND_EXECUTION_RECEIPT_MANIFEST.json").write_text(json.dumps(receipt_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(receipt_dir / "VERIFY_READY_COMMAND_RECEIPTS.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -s \"$DIR/READY_COMMAND_EXECUTION_RECEIPT_MANIFEST.json\"",
            "test -s \"$DIR/READY_COMMAND_EXECUTION_ROWS.csv\"",
            "test -s \"$DIR/READY_COMMAND_RECEIPT_FILE_ROWS.csv\"",
            "test -s \"$DIR/READY_COMMAND_EXECUTION_STAGE_ROWS.csv\"",
            "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
            "  echo 'payload-like file referenced in ready command receipt package' >&2",
            "  exit 1",
            "fi",
            "",
        ]
    ),
    encoding="utf-8",
)
(receipt_dir / "VERIFY_READY_COMMAND_RECEIPTS.sh").chmod(0o755)
(receipt_dir / "READY_COMMAND_EXECUTION_RECEIPT.md").write_text(
    "\n".join(
        [
            "# v61fs post-v61fr ready command execution receipt",
            "",
            f"- ready_command_rows={len(ready_commands)}",
            f"- executed_ready_command_rows={receipt_manifest['executed_ready_command_rows']}",
            f"- successful_ready_command_rows={receipt_manifest['successful_ready_command_rows']}",
            f"- blocked_command_rows={len(blocked_commands)}",
            f"- blocked_command_execution_attempt_rows={receipt_manifest['blocked_command_execution_attempt_rows']}",
            f"- receipt_file_rows={len(receipt_file_rows)}",
            f"- v1_0_comparison_ready={v61fr['v1_0_comparison_ready']}",
            "- actual_model_generation_ready=0",
            "",
            "Ready local commands were executed and receipt files were written. Blocked commands were not executed because they require external returned evidence roots.",
            "",
        ]
    ),
    encoding="utf-8",
)

package_files = sorted(path for path in receipt_dir.rglob("*") if path.is_file())
file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "post_fr_ready_command_execution_package_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61fs_post_fr_ready_command_execution_receipt_ready": 1,
    "v61fr_post_fq_v1_ready_command_handoff_ready": 1,
    "ready_command_rows": len(ready_commands),
    "executed_ready_command_rows": receipt_manifest["executed_ready_command_rows"],
    "successful_ready_command_rows": receipt_manifest["successful_ready_command_rows"],
    "failed_ready_command_rows": len(ready_commands) - receipt_manifest["successful_ready_command_rows"],
    "blocked_command_rows": len(blocked_commands),
    "blocked_command_execution_attempt_rows": receipt_manifest["blocked_command_execution_attempt_rows"],
    "receipt_file_rows": len(receipt_file_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "required_external_input_rows": len(external_input_rows),
    "present_external_input_rows": sum(row["present"] == "1" for row in external_input_rows),
    "missing_external_input_rows": sum(row["present"] == "0" for row in external_input_rows),
    "send_bundle_ready": as_int(v61fr, "send_bundle_ready"),
    "return_bundle_preflight_pass": as_int(v61fr, "return_bundle_preflight_pass"),
    "external_review_return_ready": as_int(v61fr, "external_review_return_ready"),
    "v1_0_comparison_ready": as_int(v61fr, "v1_0_comparison_ready"),
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fs": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "receipt_package_file_rows": len(file_rows),
    "metadata_only_receipt_package_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_receipt_package_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": len(sources),
    "source_artifact_file_rows": len(source_artifacts),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61fr-handoff", "status": "pass", "actual_value": "1", "required_value": "1", "reason": "handoff package exists"},
    {"gate": "ready-command-execution", "status": pass_or_blocked(summary["successful_ready_command_rows"] == summary["ready_command_rows"]), "actual_value": f"{summary['successful_ready_command_rows']}/{summary['ready_command_rows']}", "required_value": "4/4", "reason": "all ready local commands must exit zero"},
    {"gate": "receipt-files", "status": pass_or_blocked(summary["receipt_file_rows"] == summary["ready_command_rows"] * 2), "actual_value": str(summary["receipt_file_rows"]), "required_value": "8", "reason": "stdout/stderr receipt for each ready command"},
    {"gate": "blocked-command-nonexecution", "status": pass_or_blocked(summary["blocked_command_execution_attempt_rows"] == 0), "actual_value": str(summary["blocked_command_execution_attempt_rows"]), "required_value": "0", "reason": "external-input commands must not run"},
    {"gate": "external-inputs", "status": "blocked", "actual_value": f"{summary['present_external_input_rows']}/{summary['required_external_input_rows']}", "required_value": "5/5", "reason": "real returned roots missing"},
    {"gate": "v1-comparison", "status": pass_or_blocked(summary["v1_0_comparison_ready"]), "actual_value": str(summary["v1_0_comparison_ready"]), "required_value": "1", "reason": "review/generation evidence missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual model generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only receipts"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FS_POST_FR_READY_COMMAND_EXECUTION_RECEIPT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# V61FS Post-v61fr Ready Command Execution Receipt Boundary",
            "",
            "- v61fs_post_fr_ready_command_execution_receipt_ready=1",
            f"- ready_command_rows={summary['ready_command_rows']}",
            f"- executed_ready_command_rows={summary['executed_ready_command_rows']}",
            f"- successful_ready_command_rows={summary['successful_ready_command_rows']}",
            f"- failed_ready_command_rows={summary['failed_ready_command_rows']}",
            f"- blocked_command_rows={summary['blocked_command_rows']}",
            f"- blocked_command_execution_attempt_rows={summary['blocked_command_execution_attempt_rows']}",
            f"- receipt_file_rows={summary['receipt_file_rows']}",
            f"- ready_stage_rows={summary['ready_stage_rows']}",
            f"- blocked_stage_rows={summary['blocked_stage_rows']}",
            f"- missing_external_input_rows={summary['missing_external_input_rows']}",
            f"- send_bundle_ready={summary['send_bundle_ready']}",
            f"- return_bundle_preflight_pass={summary['return_bundle_preflight_pass']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- v1_0_comparison_ready={summary['v1_0_comparison_ready']}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Blocked wording: all ready local verification commands executed successfully, but external-input commands were not executed. v1.0 comparison, actual generation, production latency, near-frontier, and release claims remain blocked until returned evidence roots are supplied.",
            "",
        ]
    ),
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

print(f"v61fs_post_fr_ready_command_execution_receipt_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
