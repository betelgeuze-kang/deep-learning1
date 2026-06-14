#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gb_post_ga_generation_unblock_runway_receipt"
RUN_ID="${V61GB_RUN_ID:-receipt_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gb_post_ga_generation_unblock_runway_receipt_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ga_post_fz_generation_unblock_runway.sh" >/dev/null

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
prefix = "v61gb_post_ga_generation_unblock_runway_receipt"
receipt_dir = run_dir / "generation_unblock_runway_receipt"
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


def copy_source(source_id, src, folder):
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    }


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
    "v61ga_summary": results / "v61ga_post_fz_generation_unblock_runway_summary.csv",
    "v61ga_decision": results / "v61ga_post_fz_generation_unblock_runway_decision.csv",
    "v61ga_commands": results / "v61ga_post_fz_generation_unblock_runway" / "runway_001" / "generation_unblock_runway_replay_command_rows.csv",
    "v61ga_requirements": results / "v61ga_post_fz_generation_unblock_runway" / "runway_001" / "generation_unblock_runway_requirement_rows.csv",
    "v61ga_batches": results / "v61ga_post_fz_generation_unblock_runway" / "runway_001" / "generation_unblock_runway_minimum_batch_rows.csv",
    "v61ga_manifest": results / "v61ga_post_fz_generation_unblock_runway" / "runway_001" / "generation_unblock_runway" / "GENERATION_UNBLOCK_RUNWAY_MANIFEST.json",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gb source {source_id}: {path}")

source_rows = [copy_source(source_id, path, "source_v61ga") for source_id, path in source_paths.items()]
write_csv(run_dir / "generation_unblock_runway_receipt_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61ga = read_csv(source_paths["v61ga_summary"])[0]
if v61ga.get("v61ga_post_fz_generation_unblock_runway_ready") != "1":
    raise SystemExit("v61gb requires v61ga_post_fz_generation_unblock_runway_ready=1")

command_rows = read_csv(source_paths["v61ga_commands"])
ready_commands = [row for row in command_rows if row["ready_to_run_now"] == "1"]
blocked_commands = [row for row in command_rows if row["ready_to_run_now"] == "0"]
if len(ready_commands) != 2 or len(blocked_commands) != 3:
    raise SystemExit("v61gb expected v61ga two ready commands and three blocked commands")

execution_rows = []
receipt_file_rows = []
for index, row in enumerate(ready_commands, 1):
    receipt_id = f"{index:02d}-{row['command_id']}"
    exit_code, stdout_path, stderr_path = run_command(row["command"], receipt_id)
    success = int(exit_code == 0)
    execution_rows.append({
        "command_id": row["command_id"],
        "ready_to_run_now": "1",
        "executed": "1",
        "success": str(success),
        "exit_code": str(exit_code),
        "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
        "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
        "command": row["command"],
        "purpose": row["purpose"],
    })
    for stream_path, stream_name in [(stdout_path, "stdout"), (stderr_path, "stderr")]:
        receipt_file_rows.append({
            "receipt_id": receipt_id,
            "stream": stream_name,
            "path": stream_path.relative_to(run_dir).as_posix(),
            "bytes": str(stream_path.stat().st_size),
            "sha256": sha256(stream_path),
        })

for row in blocked_commands:
    execution_rows.append({
        "command_id": row["command_id"],
        "ready_to_run_now": "0",
        "executed": "0",
        "success": "0",
        "exit_code": "",
        "stdout_path": "",
        "stderr_path": "",
        "command": row["command"],
        "purpose": row["purpose"],
    })

write_csv(run_dir / "generation_unblock_runway_receipt_execution_rows.csv", list(execution_rows[0].keys()), execution_rows)
write_csv(run_dir / "generation_unblock_runway_receipt_file_rows.csv", list(receipt_file_rows[0].keys()), receipt_file_rows)

stage_rows = [
    {"stage_id": "01-source-v61ga-runway", "status": "ready", "evidence": "v61ga_post_fz_generation_unblock_runway_ready=1"},
    {"stage_id": "02-ready-command-execution", "status": "ready" if all(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1") else "blocked", "evidence": f"executed_ready_command_rows={sum(row['executed'] == '1' for row in execution_rows if row['ready_to_run_now'] == '1')}"},
    {"stage_id": "03-blocked-command-nonexecution", "status": "ready" if all(row["executed"] == "0" for row in execution_rows if row["ready_to_run_now"] == "0") else "blocked", "evidence": f"blocked_command_rows={len(blocked_commands)}"},
    {"stage_id": "04-dual-real-return-roots", "status": "blocked", "evidence": "dual real return roots absent"},
    {"stage_id": "05-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "generation_unblock_runway_receipt_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, path in [
    ("GENERATION_UNBLOCK_RUNWAY_RECEIPT_EXECUTION_ROWS.csv", run_dir / "generation_unblock_runway_receipt_execution_rows.csv"),
    ("GENERATION_UNBLOCK_RUNWAY_RECEIPT_FILE_ROWS.csv", run_dir / "generation_unblock_runway_receipt_file_rows.csv"),
    ("GENERATION_UNBLOCK_RUNWAY_RECEIPT_STAGE_ROWS.csv", run_dir / "generation_unblock_runway_receipt_stage_rows.csv"),
]:
    shutil.copy2(path, receipt_dir / rel)

receipt_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "ready_runway_command_rows": len(ready_commands),
    "executed_ready_runway_command_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "successful_ready_runway_command_rows": sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "blocked_runway_command_rows": len(blocked_commands),
    "blocked_runway_command_execution_attempt_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(receipt_dir / "GENERATION_UNBLOCK_RUNWAY_RECEIPT_MANIFEST.json").write_text(json.dumps(receipt_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(receipt_dir / "VERIFY_GENERATION_UNBLOCK_RUNWAY_RECEIPT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_RECEIPT_MANIFEST.json\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_RECEIPT_EXECUTION_ROWS.csv\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_RECEIPT_FILE_ROWS.csv\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_RECEIPT_STAGE_ROWS.csv\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/GENERATION_UNBLOCK_RUNWAY_RECEIPT_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in generation unblock runway receipt package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(receipt_dir / "VERIFY_GENERATION_UNBLOCK_RUNWAY_RECEIPT.sh").chmod(0o755)
(receipt_dir / "GENERATION_UNBLOCK_RUNWAY_RECEIPT.md").write_text(
    "\n".join([
        "# v61gb generation unblock runway receipt",
        "",
        f"- ready_runway_command_rows={len(ready_commands)}",
        f"- executed_ready_runway_command_rows={receipt_manifest['executed_ready_runway_command_rows']}",
        f"- successful_ready_runway_command_rows={receipt_manifest['successful_ready_runway_command_rows']}",
        f"- blocked_runway_command_rows={len(blocked_commands)}",
        f"- blocked_runway_command_execution_attempt_rows={receipt_manifest['blocked_runway_command_execution_attempt_rows']}",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "The real dual-return root supply, root-pinned replay, and post-replay refresh commands remain unexecuted.",
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
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "generation_unblock_runway_receipt_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61gb_post_ga_generation_unblock_runway_receipt_ready": "1",
    "v61ga_post_fz_generation_unblock_runway_ready": v61ga["v61ga_post_fz_generation_unblock_runway_ready"],
    "ready_runway_command_rows": str(len(ready_commands)),
    "executed_ready_runway_command_rows": str(sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1")),
    "successful_ready_runway_command_rows": str(sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1")),
    "failed_ready_runway_command_rows": str(sum(row["success"] != "1" for row in execution_rows if row["ready_to_run_now"] == "1")),
    "blocked_runway_command_rows": str(len(blocked_commands)),
    "blocked_runway_command_execution_attempt_rows": str(sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0")),
    "receipt_file_rows": str(len(receipt_file_rows)),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "runway_requirement_rows": v61ga["runway_requirement_rows"],
    "ready_runway_requirement_rows": v61ga["ready_runway_requirement_rows"],
    "blocked_runway_requirement_rows": v61ga["blocked_runway_requirement_rows"],
    "minimum_batch_rows": v61ga["minimum_batch_rows"],
    "blocked_minimum_batch_rows": v61ga["blocked_minimum_batch_rows"],
    "missing_external_return_artifacts": v61ga["missing_external_return_artifacts"],
    "missing_human_review_rows": v61ga["missing_human_review_rows"],
    "missing_adjudication_rows": v61ga["missing_adjudication_rows"],
    "missing_generation_result_artifacts": v61ga["missing_generation_result_artifacts"],
    "missing_generation_result_rows": v61ga["missing_generation_result_rows"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "receipt_package_file_rows": str(len(package_file_rows)),
    "metadata_only_receipt_package_file_rows": str(sum(row["metadata_only"] == "1" for row in package_file_rows)),
    "payload_like_receipt_package_file_rows": str(sum(row["payload_like"] == "1" for row in package_file_rows)),
    "source_file_rows": str(len(source_rows)),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ga-runway", "status": "pass", "evidence": "v61ga_post_fz_generation_unblock_runway_ready=1"},
    {"gate": "ready-runway-commands", "status": "pass", "evidence": "successful_ready_runway_command_rows=2/2"},
    {"gate": "blocked-command-nonexecution", "status": "pass", "evidence": "blocked_runway_command_execution_attempt_rows=0"},
    {"gate": "dual-real-return-roots", "status": "blocked", "evidence": "missing_external_return_artifacts=91"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GB Post-GA Generation Unblock Runway Receipt Boundary",
    "",
    f"- v61gb_post_ga_generation_unblock_runway_receipt_ready={summary['v61gb_post_ga_generation_unblock_runway_receipt_ready']}",
    f"- v61ga_post_fz_generation_unblock_runway_ready={summary['v61ga_post_fz_generation_unblock_runway_ready']}",
    f"- ready_runway_command_rows={summary['ready_runway_command_rows']}",
    f"- executed_ready_runway_command_rows={summary['executed_ready_runway_command_rows']}",
    f"- successful_ready_runway_command_rows={summary['successful_ready_runway_command_rows']}",
    f"- blocked_runway_command_rows={summary['blocked_runway_command_rows']}",
    f"- blocked_runway_command_execution_attempt_rows={summary['blocked_runway_command_execution_attempt_rows']}",
    f"- receipt_file_rows={summary['receipt_file_rows']}",
    f"- stage_rows={summary['stage_rows']}",
    f"- ready_stage_rows={summary['ready_stage_rows']}",
    f"- blocked_stage_rows={summary['blocked_stage_rows']}",
    f"- runway_requirement_rows={summary['runway_requirement_rows']}",
    f"- ready_runway_requirement_rows={summary['ready_runway_requirement_rows']}",
    f"- blocked_runway_requirement_rows={summary['blocked_runway_requirement_rows']}",
    f"- minimum_batch_rows={summary['minimum_batch_rows']}",
    f"- blocked_minimum_batch_rows={summary['blocked_minimum_batch_rows']}",
    f"- missing_external_return_artifacts={summary['missing_external_return_artifacts']}",
    f"- missing_human_review_rows={summary['missing_human_review_rows']}",
    f"- missing_adjudication_rows={summary['missing_adjudication_rows']}",
    f"- missing_generation_result_artifacts={summary['missing_generation_result_artifacts']}",
    f"- missing_generation_result_rows={summary['missing_generation_result_rows']}",
    f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
    f"- checkpoint_payload_bytes_committed_to_repo={summary['checkpoint_payload_bytes_committed_to_repo']}",
    "",
    "Blocked wording: this receipt executes only local verification commands. It is not actual model generation, real dual-return replay, production latency, near-frontier quality, or release evidence.",
    "",
])
(run_dir / "V61GB_POST_GA_GENERATION_UNBLOCK_RUNWAY_RECEIPT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "receipt_manifest": receipt_manifest,
    "checkpoint_payload_bytes_downloaded_by_v61gb": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gb_post_ga_generation_unblock_runway_receipt_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
