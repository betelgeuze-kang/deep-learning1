#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gt_post_gs_ack_packet_to_replay_handoff"
RUN_ID="${V61GT_RUN_ID:-handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXECUTE_HANDOFF="${V61GT_EXECUTE_HANDOFF:-0}"
VALIDATOR_RUN_ID="${V61GT_VALIDATOR_RUN_ID:-packet_001}"

if [[ "${V61GT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gt_post_gs_ack_packet_to_replay_handoff_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gs_post_gr_external_ack_packet_builder.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$EXECUTE_HANDOFF" "$VALIDATOR_RUN_ID" <<'PY'
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
run_id = sys.argv[5]
execute_handoff = int((sys.argv[6].strip() or "0") == "1")
validator_run_id = sys.argv[7]
results = root / "results"
prefix = "v61gt_post_gs_ack_packet_to_replay_handoff"
package_dir = run_dir / "ack_packet_to_replay_handoff"
package_dir.mkdir(parents=True, exist_ok=True)

GS_PREFIX = "v61gs_post_gr_external_ack_packet_builder"
GR_PREFIX = "v61gr_post_gq_receipt_bound_external_ack_gate"


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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


source_paths = {
    "v61gs_summary": results / f"{GS_PREFIX}_summary.csv",
    "v61gs_decision": results / f"{GS_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gt source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gs") for label, path in source_paths.items()]
write_csv(run_dir / "ack_packet_to_replay_handoff_source_rows.csv", list(source_rows[0].keys()), source_rows)

gs = read_csv(source_paths["v61gs_summary"])[0]
if gs.get("v61gs_post_gr_external_ack_packet_builder_ready") != "1":
    raise SystemExit("v61gt requires v61gs ready")

operator_root_raw = os.environ.get("V61GT_OPERATOR_INPUT_ROOT", os.environ.get("V61GS_OPERATOR_INPUT_ROOT", os.environ.get("V61GR_OPERATOR_INPUT_ROOT", os.environ.get("V61GI_OPERATOR_INPUT_ROOT", "")))).strip()
output_root_raw = os.environ.get("V61GT_OUTPUT_ROOT", os.environ.get("V61GR_OUTPUT_ROOT", os.environ.get("V61GI_OUTPUT_ROOT", ""))).strip()
ack_file_raw = os.environ.get("V61GT_EXTERNAL_ACK_FILE", os.environ.get("V61GS_EXTERNAL_ACK_FILE", os.environ.get("V61GR_EXTERNAL_ACK_FILE", ""))).strip()
operator_root = Path(operator_root_raw).expanduser().resolve() if operator_root_raw else None
output_root = Path(output_root_raw).expanduser().resolve() if output_root_raw else None
ack_file = Path(ack_file_raw).expanduser().resolve() if ack_file_raw else None

operator_root_supplied = int(operator_root is not None)
operator_root_exists = int(operator_root is not None and operator_root.is_dir())
operator_root_outside_repo = int(operator_root is not None and not is_inside(operator_root, root))
output_root_supplied = int(output_root is not None)
output_root_outside_repo = int(output_root is not None and not is_inside(output_root, root))
ack_file_supplied = int(ack_file is not None)
ack_file_exists = int(ack_file is not None and ack_file.is_file())
ack_file_outside_repo = int(ack_file is not None and not is_inside(ack_file, root))

validation_executed = 0
validation_exit_code = "not-run"
validation_ready = 0
validator_path = results / GS_PREFIX / validator_run_id / "external_ack_packet_builder" / "VALIDATE_EXTERNAL_ACK_FILE.py"
if operator_root_exists and ack_file_exists and ack_file_outside_repo and validator_path.is_file():
    env = os.environ.copy()
    env["V61GS_EXTERNAL_ACK_FILE"] = str(ack_file)
    proc = subprocess.run(
        [str(validator_path)],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    validation_executed = 1
    validation_exit_code = str(proc.returncode)
    validation_ready = int(proc.returncode == 0)
    (run_dir / "ack_packet_validation_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "ack_packet_validation_stderr.txt").write_text(proc.stderr, encoding="utf-8")
else:
    (run_dir / "ack_packet_validation_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "ack_packet_validation_stderr.txt").write_text("ack-validation-not-executed\n", encoding="utf-8")

handoff_admitted = int(validation_ready and output_root_supplied and output_root_outside_repo and operator_root_outside_repo)
handoff_executed = 0
handoff_exit_code = "not-run"
gr_summary = {}
if execute_handoff and handoff_admitted:
    env = os.environ.copy()
    env.update({
        "V61GR_RUN_ID": f"{run_id}_receipt_bound_replay",
        "V61GR_EXECUTE_REPLAY": "1",
        "V61GR_REUSE_EXISTING": "0",
        "V61GR_OPERATOR_INPUT_ROOT": str(operator_root),
        "V61GR_OUTPUT_ROOT": str(output_root),
        "V61GR_EXTERNAL_ACK_FILE": str(ack_file),
    })
    proc = subprocess.run(
        [str(root / "experiments" / "run_v61gr_post_gq_receipt_bound_external_ack_gate.sh")],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    handoff_executed = 1
    handoff_exit_code = str(proc.returncode)
    (run_dir / "receipt_bound_handoff_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "receipt_bound_handoff_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61gt handoff execution failed: {proc.returncode}")
    gr_summary_path = results / f"{GR_PREFIX}_summary.csv"
    gr_summary = read_csv(gr_summary_path)[0]
    for label, path in {
        "v61gr_handoff_summary": results / f"{GR_PREFIX}_summary.csv",
        "v61gr_handoff_decision": results / f"{GR_PREFIX}_decision.csv",
    }.items():
        if not path.is_file():
            raise SystemExit(f"missing v61gt handoff source {label}: {path}")
        source_rows.append(copy_source(label, path, "source_v61gr_handoff"))
    write_csv(run_dir / "ack_packet_to_replay_handoff_source_rows.csv", list(source_rows[0].keys()), source_rows)
else:
    (run_dir / "receipt_bound_handoff_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "receipt_bound_handoff_stderr.txt").write_text("handoff-not-executed\n", encoding="utf-8")

counter_source = gr_summary if handoff_executed else {}
real_external_review_return_rows = as_int(counter_source, "real_external_review_return_rows")
real_generation_result_artifacts = as_int(counter_source, "real_generation_result_artifacts")
real_return_replay_admission_ready = as_int(counter_source, "real_return_replay_admission_ready")
generation_acceptance_closure_ready = as_int(counter_source, "generation_acceptance_closure_ready")
actual_model_generation_ready = as_int(counter_source, "actual_model_generation_ready")

handoff_rows = [{
    "operator_input_root_supplied": str(operator_root_supplied),
    "operator_input_root_exists": str(operator_root_exists),
    "operator_input_root_outside_repo": str(operator_root_outside_repo),
    "output_root_supplied": str(output_root_supplied),
    "output_root_outside_repo": str(output_root_outside_repo),
    "ack_file_supplied": str(ack_file_supplied),
    "ack_file_exists": str(ack_file_exists),
    "ack_file_outside_repo": str(ack_file_outside_repo),
    "validation_executed": str(validation_executed),
    "validation_exit_code": validation_exit_code,
    "validation_ready": str(validation_ready),
    "handoff_admitted": str(handoff_admitted),
    "handoff_executed": str(handoff_executed),
    "handoff_exit_code": handoff_exit_code,
}]
write_csv(run_dir / "ack_packet_to_replay_handoff_rows.csv", list(handoff_rows[0].keys()), handoff_rows)

stage_rows = [
    {"stage_id": "01-v61gs-source", "status": "ready", "evidence": "v61gs ready"},
    {"stage_id": "02-operator-input-root", "status": "ready" if operator_root_exists and operator_root_outside_repo else "blocked", "evidence": f"exists={operator_root_exists}; outside_repo={operator_root_outside_repo}"},
    {"stage_id": "03-ack-file", "status": "ready" if ack_file_exists and ack_file_outside_repo else "blocked", "evidence": f"exists={ack_file_exists}; outside_repo={ack_file_outside_repo}"},
    {"stage_id": "04-ack-validation", "status": "ready" if validation_ready else "blocked", "evidence": f"validation_executed={validation_executed}; exit_code={validation_exit_code}"},
    {"stage_id": "05-output-root", "status": "ready" if output_root_supplied and output_root_outside_repo else "blocked", "evidence": f"supplied={output_root_supplied}; outside_repo={output_root_outside_repo}"},
    {"stage_id": "06-handoff-admitted", "status": "ready" if handoff_admitted else "blocked", "evidence": f"handoff_admitted={handoff_admitted}"},
    {"stage_id": "07-handoff-executed", "status": "ready" if handoff_executed else "blocked", "evidence": f"handoff_executed={handoff_executed}; exit_code={handoff_exit_code}"},
    {"stage_id": "08-dual-replay-opened", "status": "ready" if real_return_replay_admission_ready and generation_acceptance_closure_ready else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}; generation_acceptance_closure_ready={generation_acceptance_closure_ready}"},
    {"stage_id": "09-actual-generation-full-claim", "status": "blocked", "evidence": f"actual_model_generation_ready={actual_model_generation_ready}"},
]
write_csv(run_dir / "ack_packet_to_replay_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-ack-packet-handoff", "ready_to_run_now": "1", "command": "results/v61gt_post_gs_ack_packet_to_replay_handoff/handoff_001/ack_packet_to_replay_handoff/VERIFY_ACK_PACKET_TO_REPLAY_HANDOFF.sh", "purpose": "verify this handoff package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gt_post_gs_ack_packet_to_replay_handoff/handoff_001/ack_packet_to_replay_handoff/READY_NOW_COMMANDS.sh", "purpose": "show handoff command"},
    {"command_id": "03-run-validated-handoff", "ready_to_run_now": str(handoff_admitted), "command": "V61GT_EXECUTE_HANDOFF=1 V61GT_VALIDATOR_RUN_ID=<v61gs-run-id> V61GT_OPERATOR_INPUT_ROOT=<operator-input-root> V61GT_OUTPUT_ROOT=<output-root> V61GT_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gt_post_gs_ack_packet_to_replay_handoff.sh", "purpose": "validate ack packet then execute v61gr"},
]
write_csv(run_dir / "ack_packet_to_replay_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("ACK_PACKET_TO_REPLAY_HANDOFF_ROWS.csv", run_dir / "ack_packet_to_replay_handoff_rows.csv"),
    ("ACK_PACKET_TO_REPLAY_HANDOFF_STAGE_ROWS.csv", run_dir / "ack_packet_to_replay_handoff_stage_rows.csv"),
    ("ACK_PACKET_TO_REPLAY_HANDOFF_COMMAND_ROWS.csv", run_dir / "ack_packet_to_replay_handoff_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_ACK_PACKET_TO_REPLAY_HANDOFF.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/ACK_PACKET_TO_REPLAY_HANDOFF_ROWS.csv\"",
        "test -s \"$DIR/ACK_PACKET_TO_REPLAY_HANDOFF_STAGE_ROWS.csv\"",
        "test -s \"$DIR/ACK_PACKET_TO_REPLAY_HANDOFF_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/ACK_PACKET_TO_REPLAY_HANDOFF_MANIFEST.json\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gt package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_ACK_PACKET_TO_REPLAY_HANDOFF.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'Validate ack packet then execute receipt-bound replay:'",
        "echo 'V61GT_EXECUTE_HANDOFF=1 V61GT_VALIDATOR_RUN_ID=<v61gs-run-id> V61GT_OPERATOR_INPUT_ROOT=<operator-input-root> V61GT_OUTPUT_ROOT=<output-root> V61GT_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gt_post_gs_ack_packet_to_replay_handoff.sh'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

summary = {
    "v61gt_post_gs_ack_packet_to_replay_handoff_ready": 1,
    "v61gs_post_gr_external_ack_packet_builder_ready": 1,
    "contains_real_external_evidence": int(real_external_review_return_rows > 0 or real_generation_result_artifacts > 0 or real_return_replay_admission_ready),
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": operator_root_exists,
    "operator_input_root_outside_repo": operator_root_outside_repo,
    "output_root_supplied": output_root_supplied,
    "output_root_outside_repo": output_root_outside_repo,
    "ack_file_supplied": ack_file_supplied,
    "ack_file_exists": ack_file_exists,
    "ack_file_outside_repo": ack_file_outside_repo,
    "validation_executed": validation_executed,
    "validation_exit_code": validation_exit_code,
    "validation_ready": validation_ready,
    "validator_run_id": validator_run_id,
    "handoff_admitted": handoff_admitted,
    "handoff_requested": execute_handoff,
    "handoff_executed": handoff_executed,
    "handoff_exit_code": handoff_exit_code,
    "real_external_review_return_rows": real_external_review_return_rows,
    "real_generation_result_artifacts": real_generation_result_artifacts,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "generation_acceptance_closure_ready": generation_acceptance_closure_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "checkpoint_payload_bytes_downloaded_by_v61gt": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "ACK_PACKET_TO_REPLAY_HANDOFF_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "ack_packet_to_replay_handoff_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gs-ready", "status": "pass", "evidence": "v61gs ready"},
    {"gate": "operator-input-root", "status": "pass" if operator_root_exists and operator_root_outside_repo else "blocked", "evidence": f"exists={operator_root_exists}; outside_repo={operator_root_outside_repo}"},
    {"gate": "ack-file-validation", "status": "pass" if validation_ready else "blocked", "evidence": f"validation_executed={validation_executed}; exit_code={validation_exit_code}"},
    {"gate": "output-root", "status": "pass" if output_root_supplied and output_root_outside_repo else "blocked", "evidence": f"supplied={output_root_supplied}; outside_repo={output_root_outside_repo}"},
    {"gate": "handoff-admitted", "status": "pass" if handoff_admitted else "blocked", "evidence": f"handoff_admitted={handoff_admitted}"},
    {"gate": "handoff-executed", "status": "pass" if handoff_executed else "blocked", "evidence": f"handoff_executed={handoff_executed}; exit_code={handoff_exit_code}"},
    {"gate": "real-return-replay-admission", "status": "pass" if real_return_replay_admission_ready else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}"},
    {"gate": "generation-acceptance-closure", "status": "pass" if generation_acceptance_closure_ready else "blocked", "evidence": f"generation_acceptance_closure_ready={generation_acceptance_closure_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={actual_model_generation_ready}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GT_POST_GS_ACK_PACKET_TO_REPLAY_HANDOFF_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GT Post-GS Ack Packet To Replay Handoff",
        "",
        "- v61gt_post_gs_ack_packet_to_replay_handoff_ready=1",
        f"- validation_ready={validation_ready}",
        f"- handoff_admitted={handoff_admitted}",
        f"- handoff_executed={handoff_executed}",
        f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
        f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
        f"- actual_model_generation_ready={actual_model_generation_ready}",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gt": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gt_post_gs_ack_packet_to_replay_handoff_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
