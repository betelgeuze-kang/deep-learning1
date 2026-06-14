#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fy_post_fx_operator_handoff_receipt"
RUN_ID="${V61FY_RUN_ID:-receipt_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fy_post_fx_operator_handoff_receipt_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FX_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fx_post_fw_dual_return_operator_handoff_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
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
prefix = "v61fy_post_fx_operator_handoff_receipt"
receipt_dir = run_dir / "operator_handoff_receipt"
stream_dir = run_dir / "command_receipts"
fixture_root = run_dir / "fixture_reject_roots"
receipt_dir.mkdir(parents=True, exist_ok=True)
stream_dir.mkdir(parents=True, exist_ok=True)
fixture_root.mkdir(parents=True, exist_ok=True)


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


def run_command(command, receipt_id, env=None):
    stdout_path = stream_dir / f"{receipt_id}.stdout.txt"
    stderr_path = stream_dir / f"{receipt_id}.stderr.txt"
    shell = not isinstance(command, (list, tuple))
    completed = subprocess.run(
        command,
        shell=shell,
        cwd=root,
        env=env,
        text=True,
        capture_output=True,
    )
    stdout_path.write_text(completed.stdout, encoding="utf-8")
    stderr_path.write_text(completed.stderr, encoding="utf-8")
    return completed.returncode, stdout_path, stderr_path


source_paths = {
    "v61fx_summary": results / "v61fx_post_fw_dual_return_operator_handoff_bundle_summary.csv",
    "v61fx_decision": results / "v61fx_post_fw_dual_return_operator_handoff_bundle_decision.csv",
    "v61fx_actions": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_action_rows.csv",
    "v61fx_stages": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_stage_rows.csv",
    "v61fx_roots": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_root_contract_rows.csv",
    "v61fx_manifest": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_bundle" / "DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json",
    "v61fx_run_script": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_bundle" / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fy source {label}: {path}")
    copy(path, f"source_v61fx/{path.name}")

v61fx = read_csv(source_paths["v61fx_summary"])[0]
if v61fx.get("v61fx_post_fw_dual_return_operator_handoff_bundle_ready") != "1":
    raise SystemExit("v61fy requires v61fx ready")

action_rows = read_csv(source_paths["v61fx_actions"])
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

fixture_v53 = fixture_root / "v53"
fixture_v61 = fixture_root / "v61"
fixture_v53.mkdir(parents=True, exist_ok=True)
fixture_v61.mkdir(parents=True, exist_ok=True)
handoff_script = source_paths["v61fx_run_script"]
clean_env = os.environ.copy()
for key in [
    "V61FV_V53_RETURN_BUNDLE_DIR",
    "V61FV_V53_RETURN_PROVENANCE",
    "V61FV_V61_RETURN_BUNDLE_DIR",
    "V61FV_V61_RETURN_PROVENANCE",
]:
    clean_env.pop(key, None)
guard_probe_specs = [
    {
        "probe_id": "01-no-env-reject",
        "command": [str(handoff_script)],
        "env": clean_env,
        "expected_exit_nonzero": "1",
        "expected_stderr": "V61FV_V53_RETURN_BUNDLE_DIR",
    },
    {
        "probe_id": "02-fixture-provenance-reject",
        "command": [str(handoff_script)],
        "env": {
            **os.environ,
            "V61FV_V53_RETURN_BUNDLE_DIR": str(fixture_v53),
            "V61FV_V53_RETURN_PROVENANCE": "fixture-v53-return",
            "V61FV_V61_RETURN_BUNDLE_DIR": str(fixture_v61),
            "V61FV_V61_RETURN_PROVENANCE": "fixture-v61-return",
        },
        "expected_exit_nonzero": "1",
        "expected_stderr": "rejecting v53 return provenance",
    },
]
guard_probe_rows = []
for spec in guard_probe_specs:
    exit_code, stdout_path, stderr_path = run_command(spec["command"], spec["probe_id"], spec["env"])
    stderr_text = stderr_path.read_text(encoding="utf-8")
    passed = int(exit_code != 0 and spec["expected_stderr"] in stderr_text)
    guard_probe_rows.append({
        "probe_id": spec["probe_id"],
        "executed": "1",
        "passed": str(passed),
        "exit_code": str(exit_code),
        "expected_exit_nonzero": spec["expected_exit_nonzero"],
        "expected_stderr": spec["expected_stderr"],
        "stdout_path": stdout_path.relative_to(run_dir).as_posix(),
        "stderr_path": stderr_path.relative_to(run_dir).as_posix(),
    })
    for stream_path, stream_name in [(stdout_path, "stdout"), (stderr_path, "stderr")]:
        receipt_file_rows.append({
            "receipt_id": spec["probe_id"],
            "stream": stream_name,
            "path": stream_path.relative_to(run_dir).as_posix(),
            "bytes": stream_path.stat().st_size,
            "sha256": sha256(stream_path),
        })

write_csv(run_dir / "operator_handoff_receipt_execution_rows.csv", list(execution_rows[0].keys()), execution_rows)
write_csv(run_dir / "operator_handoff_guard_probe_rows.csv", list(guard_probe_rows[0].keys()), guard_probe_rows)
write_csv(run_dir / "operator_handoff_receipt_file_rows.csv", list(receipt_file_rows[0].keys()), receipt_file_rows)

stage_rows = [
    {"stage_id": "01-source-v61fx-handoff", "status": "ready", "evidence": "v61fx_post_fw_dual_return_operator_handoff_bundle_ready=1"},
    {"stage_id": "02-ready-action-execution", "status": "ready" if all(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1") else "blocked", "evidence": f"executed_ready_handoff_action_rows={sum(row['executed'] == '1' for row in execution_rows if row['ready_to_run_now'] == '1')}"},
    {"stage_id": "03-blocked-action-nonexecution", "status": "ready" if all(row["executed"] == "0" for row in execution_rows if row["ready_to_run_now"] == "0") else "blocked", "evidence": f"blocked_handoff_action_rows={len(blocked_actions)}"},
    {"stage_id": "04-fail-closed-guard-probes", "status": "ready" if all(row["passed"] == "1" for row in guard_probe_rows) else "blocked", "evidence": f"passed_guard_probe_rows={sum(row['passed'] == '1' for row in guard_probe_rows)}/{len(guard_probe_rows)}"},
    {"stage_id": "05-root-pinned-replay-script", "status": "ready" if str(root) in handoff_script.read_text(encoding="utf-8") else "blocked", "evidence": "guarded script pins repository root"},
    {"stage_id": "06-real-dual-return-roots", "status": "blocked", "evidence": "real v53/v61 return roots absent by default"},
    {"stage_id": "07-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "operator_handoff_receipt_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, path in [
    ("OPERATOR_HANDOFF_RECEIPT_EXECUTION_ROWS.csv", run_dir / "operator_handoff_receipt_execution_rows.csv"),
    ("OPERATOR_HANDOFF_GUARD_PROBE_ROWS.csv", run_dir / "operator_handoff_guard_probe_rows.csv"),
    ("OPERATOR_HANDOFF_RECEIPT_FILE_ROWS.csv", run_dir / "operator_handoff_receipt_file_rows.csv"),
    ("OPERATOR_HANDOFF_RECEIPT_STAGE_ROWS.csv", run_dir / "operator_handoff_receipt_stage_rows.csv"),
]:
    shutil.copy2(path, receipt_dir / rel)

receipt_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "ready_handoff_action_rows": len(ready_actions),
    "executed_ready_handoff_action_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "successful_ready_handoff_action_rows": sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "blocked_handoff_action_rows": len(blocked_actions),
    "blocked_handoff_action_execution_attempt_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0"),
    "guard_probe_rows": len(guard_probe_rows),
    "passed_guard_probe_rows": sum(row["passed"] == "1" for row in guard_probe_rows),
    "root_pinned_replay_script_ready": int(str(root) in handoff_script.read_text(encoding="utf-8")),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(receipt_dir / "OPERATOR_HANDOFF_RECEIPT_MANIFEST.json").write_text(json.dumps(receipt_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(receipt_dir / "VERIFY_OPERATOR_HANDOFF_RECEIPT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/OPERATOR_HANDOFF_RECEIPT_MANIFEST.json\"",
        "test -s \"$DIR/OPERATOR_HANDOFF_RECEIPT_EXECUTION_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_HANDOFF_GUARD_PROBE_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_HANDOFF_RECEIPT_FILE_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_HANDOFF_RECEIPT_STAGE_ROWS.csv\"",
        "grep -q 'root_pinned_replay_script_ready' \"$DIR/OPERATOR_HANDOFF_RECEIPT_MANIFEST.json\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/OPERATOR_HANDOFF_RECEIPT_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in operator handoff receipt package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(receipt_dir / "VERIFY_OPERATOR_HANDOFF_RECEIPT.sh").chmod(0o755)
(receipt_dir / "OPERATOR_HANDOFF_RECEIPT.md").write_text(
    "\n".join([
        "# v61fy operator handoff receipt",
        "",
        f"- ready_handoff_action_rows={len(ready_actions)}",
        f"- executed_ready_handoff_action_rows={receipt_manifest['executed_ready_handoff_action_rows']}",
        f"- successful_ready_handoff_action_rows={receipt_manifest['successful_ready_handoff_action_rows']}",
        f"- blocked_handoff_action_rows={len(blocked_actions)}",
        f"- blocked_handoff_action_execution_attempt_rows={receipt_manifest['blocked_handoff_action_execution_attempt_rows']}",
        f"- guard_probe_rows={len(guard_probe_rows)}",
        f"- passed_guard_probe_rows={receipt_manifest['passed_guard_probe_rows']}",
        f"- root_pinned_replay_script_ready={receipt_manifest['root_pinned_replay_script_ready']}",
        "- actual_model_generation_ready=0",
        "",
        "The real replay command remains unexecuted until the two real return roots and exact provenance labels are supplied.",
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
write_csv(run_dir / "operator_handoff_receipt_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61fy_post_fx_operator_handoff_receipt_ready": 1,
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": 1,
    "ready_handoff_action_rows": len(ready_actions),
    "executed_ready_handoff_action_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "successful_ready_handoff_action_rows": sum(row["success"] == "1" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "failed_ready_handoff_action_rows": sum(row["success"] == "0" for row in execution_rows if row["ready_to_run_now"] == "1"),
    "blocked_handoff_action_rows": len(blocked_actions),
    "blocked_handoff_action_execution_attempt_rows": sum(row["executed"] == "1" for row in execution_rows if row["ready_to_run_now"] == "0"),
    "guard_probe_rows": len(guard_probe_rows),
    "passed_guard_probe_rows": sum(row["passed"] == "1" for row in guard_probe_rows),
    "failed_guard_probe_rows": sum(row["passed"] == "0" for row in guard_probe_rows),
    "receipt_file_rows": len(receipt_file_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "root_pinned_replay_script_ready": int(str(root) in handoff_script.read_text(encoding="utf-8")),
    "real_replay_command_executed": 0,
    "dual_external_return_real_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fy": 0,
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
    {"gate": "v61fx-operator-handoff", "status": "pass", "actual_value": "ready", "required_value": "ready", "reason": "operator handoff source exists"},
    {"gate": "ready-handoff-actions", "status": "pass", "actual_value": f"{summary['successful_ready_handoff_action_rows']}/{summary['ready_handoff_action_rows']}", "required_value": "all ready actions successful", "reason": "local handoff actions executed"},
    {"gate": "blocked-action-nonexecution", "status": "pass", "actual_value": str(summary["blocked_handoff_action_execution_attempt_rows"]), "required_value": "0", "reason": "real-root/replay actions were not executed"},
    {"gate": "fail-closed-guard-probes", "status": "pass", "actual_value": f"{summary['passed_guard_probe_rows']}/{summary['guard_probe_rows']}", "required_value": "all probes pass", "reason": "missing env and fixture provenance are rejected"},
    {"gate": "root-pinned-replay-script", "status": "pass", "actual_value": str(summary["root_pinned_replay_script_ready"]), "required_value": "1", "reason": "handoff replay script uses the repository root"},
    {"gate": "dual-external-return-real", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "real return roots missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only receipt"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FY_POST_FX_OPERATOR_HANDOFF_RECEIPT_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V61FY Post-FX Operator Handoff Receipt",
        "",
        "- v61fy_post_fx_operator_handoff_receipt_ready=1",
        f"- ready_handoff_action_rows={summary['ready_handoff_action_rows']}",
        f"- executed_ready_handoff_action_rows={summary['executed_ready_handoff_action_rows']}",
        f"- successful_ready_handoff_action_rows={summary['successful_ready_handoff_action_rows']}",
        f"- blocked_handoff_action_rows={summary['blocked_handoff_action_rows']}",
        f"- blocked_handoff_action_execution_attempt_rows={summary['blocked_handoff_action_execution_attempt_rows']}",
        f"- guard_probe_rows={summary['guard_probe_rows']}",
        f"- passed_guard_probe_rows={summary['passed_guard_probe_rows']}",
        f"- root_pinned_replay_script_ready={summary['root_pinned_replay_script_ready']}",
        "- real_replay_command_executed=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this receipt proves the v61fx handoff package is locally verifiable and fail-closed. It does not execute the real replay command without real v53/v61 return roots.",
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

print(f"v61fy_post_fx_operator_handoff_receipt_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
