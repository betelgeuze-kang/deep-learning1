#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bp_ubuntu1_payload_execution_launch_bundle"
RUN_ID="${V61BP_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bp_ubuntu1_payload_execution_launch_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bo_ubuntu1_payload_execution_readiness_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shlex
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
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)
model_id = "mistralai/Mixtral-8x22B-v0.1"
approval_phrase = "execute-ubuntu1-checkpoint-payload"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def write_executable(path, content):
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


v61bo_dir = results / "v61bo_ubuntu1_payload_execution_readiness_gate" / "gate_001"
v61bo_summary_path = results / "v61bo_ubuntu1_payload_execution_readiness_gate_summary.csv"
v61bo_decision_path = results / "v61bo_ubuntu1_payload_execution_readiness_gate_decision.csv"
v61bo_summary = read_csv(v61bo_summary_path)[0]
if v61bo_summary.get("v61bo_ubuntu1_payload_execution_readiness_gate_ready") != "1":
    raise SystemExit("v61bp requires v61bo_ubuntu1_payload_execution_readiness_gate_ready=1")
if v61bo_summary.get("payload_execution_preflight_ready") != "1":
    raise SystemExit("v61bp requires payload_execution_preflight_ready=1")
if v61bo_summary.get("payload_execution_readiness_rows") != "59":
    raise SystemExit("v61bp requires 59 payload execution readiness rows")
if v61bo_summary.get("selected_backend_id") != "curl-resume":
    raise SystemExit("v61bp requires selected_backend_id=curl-resume")

for src, rel in [
    (v61bo_summary_path, "source_v61bo/v61bo_ubuntu1_payload_execution_readiness_gate_summary.csv"),
    (v61bo_decision_path, "source_v61bo/v61bo_ubuntu1_payload_execution_readiness_gate_decision.csv"),
    (v61bo_dir / "ubuntu1_payload_execution_readiness_rows.csv", "source_v61bo/ubuntu1_payload_execution_readiness_rows.csv"),
    (v61bo_dir / "ubuntu1_payload_execution_chunk_rows.csv", "source_v61bo/ubuntu1_payload_execution_chunk_rows.csv"),
    (v61bo_dir / "ubuntu1_payload_execution_requirement_rows.csv", "source_v61bo/ubuntu1_payload_execution_requirement_rows.csv"),
    (v61bo_dir / "ubuntu1_payload_execution_metric_rows.csv", "source_v61bo/ubuntu1_payload_execution_metric_rows.csv"),
    (v61bo_dir / "runtime_gap_rows.csv", "source_v61bo/runtime_gap_rows.csv"),
    (v61bo_dir / "V61BO_UBUNTU1_PAYLOAD_EXECUTION_READINESS_GATE_BOUNDARY.md", "source_v61bo/V61BO_UBUNTU1_PAYLOAD_EXECUTION_READINESS_GATE_BOUNDARY.md"),
    (v61bo_dir / "v61bo_ubuntu1_payload_execution_readiness_gate_manifest.json", "source_v61bo/v61bo_ubuntu1_payload_execution_readiness_gate_manifest.json"),
    (v61bo_dir / "sha256_manifest.csv", "source_v61bo/sha256_manifest.csv"),
]:
    copy(src, rel)

readiness_rows = read_csv(v61bo_dir / "ubuntu1_payload_execution_readiness_rows.csv")
chunk_rows = read_csv(v61bo_dir / "ubuntu1_payload_execution_chunk_rows.csv")
if len(readiness_rows) != 59:
    raise SystemExit("v61bp expects 59 readiness rows")
if len(chunk_rows) != 3:
    raise SystemExit("v61bp expects 3 chunk rows")

queue_csv = operator_dir / "ubuntu1_payload_execution_readiness_rows.csv"
write_csv(queue_csv, list(readiness_rows[0].keys()), readiness_rows)

selected_target_path = v61bo_summary["selected_target_path"]
download_script = operator_dir / "download_priority_chunks.sh"
verify_script = operator_dir / "verify_materialization_after_download.sh"
hash_script = operator_dir / "run_full_page_hash_after_download.sh"
generation_script = operator_dir / "recheck_generation_after_download.sh"
env_template = operator_dir / "operator_env.template"
readme_path = operator_dir / "README.md"

download_content = f'''#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
QUEUE_CSV="${{V61BP_QUEUE_CSV:-$SCRIPT_DIR/ubuntu1_payload_execution_readiness_rows.csv}}"
MAX_ROWS="${{V61BP_MAX_ROWS:-0}}"
PRIORITY_CLASS="${{V61BP_PRIORITY_CLASS:-}}"
EXECUTE_PAYLOAD="${{V61BP_EXECUTE_PAYLOAD:-0}}"
APPROVAL_PHRASE="${{V61BP_APPROVAL_PHRASE:-}}"
EXPECTED_APPROVAL_PHRASE="{approval_phrase}"

python3 - "$QUEUE_CSV" "$MAX_ROWS" "$PRIORITY_CLASS" "$EXECUTE_PAYLOAD" "$APPROVAL_PHRASE" "$EXPECTED_APPROVAL_PHRASE" <<'PY_DOWNLOAD'
import csv
import subprocess
import sys
from pathlib import Path

queue_csv = Path(sys.argv[1])
max_rows = int(sys.argv[2])
priority_class = sys.argv[3]
execute_payload = sys.argv[4] == "1"
approval_phrase = sys.argv[5]
expected_approval_phrase = sys.argv[6]

if execute_payload and approval_phrase != expected_approval_phrase:
    raise SystemExit("blocked: V61BP_APPROVAL_PHRASE mismatch")

with queue_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

selected = []
for row in rows:
    if priority_class and row["priority_class"] != priority_class:
        continue
    selected.append(row)
    if max_rows and len(selected) >= max_rows:
        break

mode = "execute" if execute_payload else "dry-run"
print(f"v61bp mode={{mode}} selected_rows={{len(selected)}} priority_class={{priority_class or 'all'}}")
if not execute_payload:
    print("dry-run: set V61BP_EXECUTE_PAYLOAD=1 and V61BP_APPROVAL_PHRASE to execute-ubuntu1-checkpoint-payload to execute")

for row in selected:
    command = row["download_command_preview"]
    print(f"[{{mode}}] rank={{row['priority_rank']}} shard={{row['shard_name']}} target={{row['target_path']}}")
    print(command)
    if execute_payload:
        subprocess.run(command, shell=True, executable="/bin/bash", check=True)

print(f"processed {{len(selected)}} planned payload rows")
PY_DOWNLOAD
'''

repo_default = str(root)
target_default = selected_target_path
repo_q = shlex.quote(str(root))
target_q = shlex.quote(selected_target_path)
verify_content = f'''#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${{V61BP_REPO_ROOT:-{repo_default}}}"
WAREHOUSE_ROOT="${{V61BP_WAREHOUSE_ROOT:-{target_default}}}"
cd "$REPO_ROOT"
V61T_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61T_REUSE_EXISTING=0 ./experiments/run_v61t_local_checkpoint_materialization_verifier.sh
'''
hash_content = f'''#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${{V61BP_REPO_ROOT:-{repo_default}}}"
WAREHOUSE_ROOT="${{V61BP_WAREHOUSE_ROOT:-{target_default}}}"
cd "$REPO_ROOT"
V61R_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61R_ENABLE_LOCAL_HASH_SWEEP=1 V61R_REUSE_EXISTING=0 ./experiments/run_v61r_full_page_hash_sweep_plan.sh
'''
generation_content = f'''#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${{V61BP_REPO_ROOT:-{repo_default}}}"
WAREHOUSE_ROOT="${{V61BP_WAREHOUSE_ROOT:-{target_default}}}"
cd "$REPO_ROOT"
V61AE_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61AE_REUSE_EXISTING=0 ./experiments/run_v61ae_real_generation_admission_gate.sh
'''
env_content = f'''# v61bp ubuntu-1 payload execution launch environment
export V61BP_REPO_ROOT={repo_q}
export V61BP_WAREHOUSE_ROOT={target_q}
export V61BP_QUEUE_CSV="$V61BP_REPO_ROOT/results/v61bp_ubuntu1_payload_execution_launch_bundle/bundle_001/operator_bundle/ubuntu1_payload_execution_readiness_rows.csv"

# Dry-run by default. Set both variables below only for an intentional payload run.
export V61BP_EXECUTE_PAYLOAD=0
export V61BP_APPROVAL_PHRASE=
export V61BP_MAX_ROWS=0
export V61BP_PRIORITY_CLASS=

# Required phrase for payload execution:
# {approval_phrase}
'''

write_executable(download_script, download_content)
write_executable(verify_script, verify_content)
write_executable(hash_script, hash_content)
write_executable(generation_script, generation_content)
env_template.write_text(env_content, encoding="utf-8")

launch_command_rows = []
for row in readiness_rows:
    rank = int(row["priority_rank"])
    launch_command_rows.append(
        {
            "launch_command_id": f"v61bp-launch-{rank:04d}",
            "priority_rank": row["priority_rank"],
            "model_id": row["model_id"],
            "shard_name": row["shard_name"],
            "priority_class": row["priority_class"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "selected_backend_id": row["selected_backend_id"],
            "payload_execution_preflight_ready": row["payload_execution_preflight_ready"],
            "dry_run_default": "1",
            "requires_execute_flag": "1",
            "requires_approval_phrase": "1",
            "approval_phrase_id": "execute-ubuntu1-checkpoint-payload",
            "launch_script": str(download_script),
            "download_command_preview": row["download_command_preview"],
            "payload_execution_launch_ready": "0",
            "download_execution_ready": "0",
            "blocked_reason": "explicit-operator-approval-required",
            "checkpoint_payload_bytes_downloaded_by_v61bp": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "ubuntu1_payload_execution_launch_command_rows.csv", list(launch_command_rows[0].keys()), launch_command_rows)

chunk_launch_rows = []
for idx, chunk in enumerate(chunk_rows, start=1):
    priority_class = chunk["priority_class"]
    command = (
        f"V61BP_PRIORITY_CLASS={shlex.quote(priority_class)} "
        f"V61BP_EXECUTE_PAYLOAD=0 {shlex.quote(str(download_script))}"
    )
    chunk_launch_rows.append(
        {
            "chunk_launch_id": f"v61bp-chunk-launch-{idx:03d}",
            "priority_class": priority_class,
            "row_count": chunk["row_count"],
            "expected_bytes": chunk["expected_bytes"],
            "payload_execution_preflight_ready": chunk["payload_execution_preflight_ready"],
            "dry_run_default": "1",
            "requires_execute_flag": "1",
            "requires_approval_phrase": "1",
            "launch_command": command,
            "payload_execution_launch_ready": "0",
            "download_execution_ready": "0",
            "blocked_reason": "explicit-operator-approval-required",
            "checkpoint_payload_bytes_downloaded_by_v61bp": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "ubuntu1_payload_execution_chunk_launch_rows.csv", list(chunk_launch_rows[0].keys()), chunk_launch_rows)

approval_supplied = int(
    os.environ.get("V61BP_EXECUTE_PAYLOAD") == "1"
    and os.environ.get("V61BP_APPROVAL_PHRASE") == approval_phrase
)
approval_rows = [
    {
        "approval_requirement_id": "execute-flag",
        "required_value": "V61BP_EXECUTE_PAYLOAD=1",
        "supplied": "1" if os.environ.get("V61BP_EXECUTE_PAYLOAD") == "1" else "0",
        "status": "pass" if os.environ.get("V61BP_EXECUTE_PAYLOAD") == "1" else "blocked",
        "reason": "payload execution requires an explicit execute flag",
    },
    {
        "approval_requirement_id": "approval-phrase",
        "required_value": f"V61BP_APPROVAL_PHRASE={approval_phrase}",
        "supplied": "1" if os.environ.get("V61BP_APPROVAL_PHRASE") == approval_phrase else "0",
        "status": "pass" if os.environ.get("V61BP_APPROVAL_PHRASE") == approval_phrase else "blocked",
        "reason": "payload execution requires the exact approval phrase",
    },
]
write_csv(run_dir / "ubuntu1_payload_execution_approval_rows.csv", list(approval_rows[0].keys()), approval_rows)

readme_content = f"""# v61bp Ubuntu-1 Payload Execution Launch Bundle

This bundle turns v61bo payload-execution readiness rows into dry-run-first
operator scripts for the ubuntu-1 checkpoint warehouse.

Key rows:

- launch_command_rows=59
- priority_chunk_launch_rows=3
- payload_execution_preflight_ready=1
- payload_execution_launch_ready=0
- download_execution_ready=0
- approval_required_rows=2
- checkpoint_payload_bytes_downloaded_by_v61bp=0
- checkpoint_payload_bytes_committed_to_repo=0

Payload execution stays blocked until both are set:

- V61BP_EXECUTE_PAYLOAD=1
- V61BP_APPROVAL_PHRASE={approval_phrase}

Typical dry-run:

```bash
V61BP_MAX_ROWS=1 ./download_priority_chunks.sh
```
"""
readme_path.write_text(readme_content, encoding="utf-8")

bundle_files = [
    readme_path,
    env_template,
    queue_csv,
    download_script,
    verify_script,
    hash_script,
    generation_script,
]

script_probe_rows = []
syntax_pass_rows = 0
executable_rows = 0
for script in [download_script, verify_script, hash_script, generation_script]:
    proc = subprocess.run(["bash", "-n", str(script)], text=True, capture_output=True, check=False)
    syntax_pass = int(proc.returncode == 0)
    executable = int(os.access(script, os.X_OK))
    syntax_pass_rows += syntax_pass
    executable_rows += executable
    script_probe_rows.append(
        {
            "script_name": script.name,
            "script_path": str(script),
            "script_sha256": sha256(script),
            "bash_syntax_exit_code": str(proc.returncode),
            "bash_syntax_pass": str(syntax_pass),
            "executable_bit_set": str(executable),
            "dry_run_default": "1" if script == download_script else "0",
            "checkpoint_payload_bytes_downloaded_by_v61bp": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "ubuntu1_payload_execution_script_probe_rows.csv", list(script_probe_rows[0].keys()), script_probe_rows)

dry_env = os.environ.copy()
dry_env["V61BP_EXECUTE_PAYLOAD"] = "0"
dry_env["V61BP_MAX_ROWS"] = "1"
dry_run = subprocess.run(
    ["bash", str(download_script)],
    cwd=root,
    env=dry_env,
    text=True,
    capture_output=True,
    check=False,
    timeout=60,
)
dry_stdout = dry_run.stdout[-4000:]
dry_stderr = dry_run.stderr[-4000:]
dry_run_guard_seen = int("dry-run: set V61BP_EXECUTE_PAYLOAD=1" in dry_stdout)
dry_run_processed_one = int("processed 1 planned payload rows" in dry_stdout)
dry_run_guard_ready = int(dry_run.returncode == 0 and dry_run_guard_seen and dry_run_processed_one)
dry_run_rows = [
    {
        "probe_id": "v61bp-download-dry-run-one-row",
        "script_name": download_script.name,
        "exit_code": str(dry_run.returncode),
        "stdout_sha256": sha256_text(dry_stdout),
        "stderr_sha256": sha256_text(dry_stderr),
        "dry_run_guard_seen": str(dry_run_guard_seen),
        "planned_payload_rows_processed": "1" if dry_run_processed_one else "0",
        "payload_execution_blocked": str(dry_run_guard_ready),
        "checkpoint_payload_bytes_downloaded_by_v61bp": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "ubuntu1_payload_execution_dry_run_probe_rows.csv", list(dry_run_rows[0].keys()), dry_run_rows)

write_csv(
    run_dir / "ubuntu1_payload_execution_operator_bundle_file_rows.csv",
    ["file_id", "relative_path", "sha256", "executable_bit_set"],
    [
        {
            "file_id": f"v61bp-bundle-file-{idx:02d}",
            "relative_path": path.relative_to(run_dir).as_posix(),
            "sha256": sha256(path),
            "executable_bit_set": str(int(os.access(path, os.X_OK))),
        }
        for idx, path in enumerate(bundle_files, start=1)
    ],
)

requirement_rows = [
    {"requirement_id": "v61bo-readiness-input", "status": "pass", "actual": v61bo_summary["v61bo_ubuntu1_payload_execution_readiness_gate_ready"], "required": "1", "reason": "v61bo payload execution readiness evidence is ready"},
    {"requirement_id": "launch-command-rows", "status": "pass", "actual": str(len(launch_command_rows)), "required": "59", "reason": "one launch row exists per checkpoint shard"},
    {"requirement_id": "priority-chunk-launch-rows", "status": "pass", "actual": str(len(chunk_launch_rows)), "required": "3", "reason": "priority-class chunk launch rows are emitted"},
    {"requirement_id": "operator-bundle-files", "status": "pass", "actual": str(len(bundle_files)), "required": "7", "reason": "operator scripts and queue CSV are emitted"},
    {"requirement_id": "operator-script-syntax", "status": "pass" if syntax_pass_rows == 4 else "blocked", "actual": str(syntax_pass_rows), "required": "4", "reason": "all operator scripts pass bash syntax"},
    {"requirement_id": "download-dry-run-guard", "status": "pass" if dry_run_guard_ready else "blocked", "actual": str(dry_run_guard_ready), "required": "1", "reason": "download script blocks payload execution in dry-run mode"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61bp records launch readiness only and downloads no checkpoint payload"},
    {"requirement_id": "explicit-payload-execution-approval", "status": "pass" if approval_supplied else "blocked", "actual": str(approval_supplied), "required": "1", "reason": "execute flag and exact approval phrase are required before payload download"},
    {"requirement_id": "download-execution", "status": "blocked", "actual": "0", "required": "1", "reason": "checkpoint payload download execution is not performed"},
    {"requirement_id": "local-checkpoint-materialization", "status": "blocked", "actual": "0", "required": "59", "reason": "full checkpoint shards are not identity verified locally"},
    {"requirement_id": "full-safetensors-page-hash-binding", "status": "blocked", "actual": "0", "required": "134161", "reason": "full page-hash coverage remains incomplete"},
    {"requirement_id": "real-model-generation", "status": "blocked", "actual": "0", "required": "1", "reason": "actual Mixtral generation is not executed"},
]
write_csv(run_dir / "ubuntu1_payload_execution_launch_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

payload_execution_launch_ready = 0
download_execution_ready = 0
metric = {
    "metric_id": "v61bp_ubuntu1_payload_execution_launch_metrics",
    "model_id": model_id,
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": "1",
    "v61bo_ubuntu1_payload_execution_readiness_gate_ready": v61bo_summary["v61bo_ubuntu1_payload_execution_readiness_gate_ready"],
    "selected_activation_target_id": v61bo_summary["selected_activation_target_id"],
    "selected_payload_execution_target_id": v61bo_summary["selected_payload_execution_target_id"],
    "selected_launch_bundle_id": "ubuntu-1-payload-launch-bundle-dry-run-default",
    "selected_target_path": selected_target_path,
    "selected_backend_id": v61bo_summary["selected_backend_id"],
    "selected_backend_ready": v61bo_summary["selected_backend_ready"],
    "payload_execution_preflight_ready": v61bo_summary["payload_execution_preflight_ready"],
    "payload_execution_readiness_rows": v61bo_summary["payload_execution_readiness_rows"],
    "launch_command_rows": str(len(launch_command_rows)),
    "priority_chunk_launch_rows": str(len(chunk_launch_rows)),
    "operator_bundle_file_rows": str(len(bundle_files)),
    "script_probe_rows": str(len(script_probe_rows)),
    "script_bash_syntax_pass_rows": str(syntax_pass_rows),
    "script_executable_rows": str(executable_rows),
    "dry_run_probe_rows": str(len(dry_run_rows)),
    "dry_run_guard_ready": str(dry_run_guard_ready),
    "approval_required_rows": str(len(approval_rows)),
    "approval_supplied_rows": str(sum(1 for row in approval_rows if row["status"] == "pass")),
    "payload_execution_approval_ready": str(approval_supplied),
    "payload_execution_launch_ready": str(payload_execution_launch_ready),
    "payload_execution_ready_rows": "0",
    "payload_execution_blocked_rows": "59",
    "download_execution_ready": str(download_execution_ready),
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": v61bo_summary["total_expected_checkpoint_bytes"],
    "p0_remote_moe_sampled_rows": v61bo_summary["p0_remote_moe_sampled_rows"],
    "p0_embedding_sampled_rows": v61bo_summary["p0_embedding_sampled_rows"],
    "p2_checkpoint_backfill_rows": v61bo_summary["p2_checkpoint_backfill_rows"],
    "checkpoint_payload_bytes_downloaded_by_v61bp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_payload_execution_launch_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61bo-readiness-input", "ready", "v61bo payload execution readiness evidence is ready"),
    ("launch-command-rows", "ready", "59 launch rows are available"),
    ("priority-chunk-launch-rows", "ready", "three priority chunk launch rows are available"),
    ("operator-bundle-files", "ready", "operator launch scripts and queue CSV are available"),
    ("download-dry-run-guard", "ready" if dry_run_guard_ready else "blocked", f"dry_run_guard_ready={dry_run_guard_ready}"),
    ("explicit-payload-execution-approval", "blocked", "execute flag and exact approval phrase are not supplied"),
    ("download-execution", "blocked", "checkpoint payload download execution is not performed"),
    ("local-checkpoint-materialization", "blocked", "full checkpoint shards are not identity verified"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage remains incomplete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "launch bundle is not production latency evidence"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61bo-readiness-input", "status": "pass", "reason": "v61bo payload execution readiness evidence is ready"},
    {"gate": "launch-command-rows", "status": "pass", "reason": "59 launch rows are available"},
    {"gate": "priority-chunk-launch-rows", "status": "pass", "reason": "three priority chunk launch rows are available"},
    {"gate": "operator-bundle-files", "status": "pass", "reason": "operator launch scripts and queue CSV are available"},
    {"gate": "operator-script-syntax", "status": "pass" if syntax_pass_rows == 4 else "blocked", "reason": f"script_bash_syntax_pass_rows={syntax_pass_rows}/4"},
    {"gate": "download-dry-run-guard", "status": "pass" if dry_run_guard_ready else "blocked", "reason": f"dry_run_guard_ready={dry_run_guard_ready}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bp downloads no checkpoint payload"},
    {"gate": "explicit-payload-execution-approval", "status": "blocked", "reason": "execute flag and exact approval phrase are not supplied"},
    {"gate": "download-execution", "status": "blocked", "reason": "payload download execution is not performed"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "full checkpoint shards are not identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bp Ubuntu-1 Payload Execution Launch Bundle Boundary

This bundle consumes v61bo payload-execution readiness rows and emits a
dry-run-first operator launch bundle for ubuntu-1 checkpoint payload execution.
It does not execute checkpoint downloads.

Verified launch-bundle evidence:

- selected_launch_bundle_id=ubuntu-1-payload-launch-bundle-dry-run-default
- selected_payload_execution_target_id={v61bo_summary["selected_payload_execution_target_id"]}
- payload_execution_preflight_ready={v61bo_summary["payload_execution_preflight_ready"]}
- launch_command_rows={len(launch_command_rows)}
- priority_chunk_launch_rows={len(chunk_launch_rows)}
- operator_bundle_file_rows={len(bundle_files)}
- script_probe_rows={len(script_probe_rows)}
- script_bash_syntax_pass_rows={syntax_pass_rows}
- script_executable_rows={executable_rows}
- dry_run_guard_ready={dry_run_guard_ready}
- approval_required_rows={len(approval_rows)}
- approval_supplied_rows={sum(1 for row in approval_rows if row["status"] == "pass")}
- payload_execution_approval_ready={approval_supplied}
- payload_execution_launch_ready={payload_execution_launch_ready}
- download_execution_ready=0
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bp=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 payload execution launch bundle is ready in dry-run
mode and requires explicit operator approval before payload execution.

Blocked wording: checkpoint payload download execution, completed full
checkpoint materialization, full safetensors page-hash coverage, actual
Mixtral generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61BP_UBUNTU1_PAYLOAD_EXECUTION_LAUNCH_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bp_ubuntu1_payload_execution_launch_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bp_ubuntu1_payload_execution_launch_bundle_ready": 1,
    "source_v61bo_ready": int(v61bo_summary["v61bo_ubuntu1_payload_execution_readiness_gate_ready"]),
    "selected_payload_execution_target_id": v61bo_summary["selected_payload_execution_target_id"],
    "selected_launch_bundle_id": "ubuntu-1-payload-launch-bundle-dry-run-default",
    "selected_target_path": selected_target_path,
    "payload_execution_preflight_ready": int(v61bo_summary["payload_execution_preflight_ready"]),
    "launch_command_rows": len(launch_command_rows),
    "priority_chunk_launch_rows": len(chunk_launch_rows),
    "operator_bundle_file_rows": len(bundle_files),
    "dry_run_guard_ready": dry_run_guard_ready,
    "payload_execution_approval_ready": approval_supplied,
    "payload_execution_launch_ready": payload_execution_launch_ready,
    "download_execution_ready": download_execution_ready,
    "local_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bp": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bp_ubuntu1_payload_execution_launch_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bp_ubuntu1_payload_execution_launch_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
