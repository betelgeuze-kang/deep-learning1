#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ag_checkpoint_warehouse_execution_preflight"
RUN_ID="${V61AG_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61AG_WAREHOUSE_ROOT:-${V61AF_WAREHOUSE_ROOT:-${V61W_WAREHOUSE_ROOT:-${V61T_WAREHOUSE_ROOT:-${V61R_WAREHOUSE_ROOT:-${V61AE_WAREHOUSE_ROOT:-${V61P_SSD_WAREHOUSE_DIR:-${V61_WAREHOUSE_ROOT:-}}}}}}}}"

if [[ "${V61AG_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ag_checkpoint_warehouse_execution_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61AF_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61AF_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh" >/dev/null
else
  V61AF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61af_checkpoint_warehouse_operator_bundle.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
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
warehouse_root_override = sys.argv[5].strip()
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"

v61af_dir = results / "v61af_checkpoint_warehouse_operator_bundle" / "operator_001"
bundle_dir = v61af_dir / "operator_bundle"


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


def is_relative_to(path, base):
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def git_check_ignored(path):
    proc = subprocess.run(
        ["git", "check-ignore", "-q", str(path)],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return int(proc.returncode == 0)


v61af_summary = read_csv(results / "v61af_checkpoint_warehouse_operator_bundle_summary.csv")[0]
if v61af_summary.get("v61af_checkpoint_warehouse_operator_bundle_ready") != "1":
    raise SystemExit("v61ag requires v61af_checkpoint_warehouse_operator_bundle_ready=1")

for src, rel in [
    (results / "v61af_checkpoint_warehouse_operator_bundle_summary.csv", "source_v61af/v61af_checkpoint_warehouse_operator_bundle_summary.csv"),
    (results / "v61af_checkpoint_warehouse_operator_bundle_decision.csv", "source_v61af/v61af_checkpoint_warehouse_operator_bundle_decision.csv"),
    (v61af_dir / "checkpoint_warehouse_operator_command_rows.csv", "source_v61af/checkpoint_warehouse_operator_command_rows.csv"),
    (v61af_dir / "checkpoint_warehouse_operator_stage_rows.csv", "source_v61af/checkpoint_warehouse_operator_stage_rows.csv"),
    (v61af_dir / "checkpoint_warehouse_operator_metric_rows.csv", "source_v61af/checkpoint_warehouse_operator_metric_rows.csv"),
    (v61af_dir / "V61AF_CHECKPOINT_WAREHOUSE_OPERATOR_BUNDLE_BOUNDARY.md", "source_v61af/V61AF_CHECKPOINT_WAREHOUSE_OPERATOR_BUNDLE_BOUNDARY.md"),
    (v61af_dir / "v61af_checkpoint_warehouse_operator_bundle_manifest.json", "source_v61af/v61af_checkpoint_warehouse_operator_bundle_manifest.json"),
    (v61af_dir / "sha256_manifest.csv", "source_v61af/sha256_manifest.csv"),
    (bundle_dir / "README.md", "operator_bundle/README.md"),
    (bundle_dir / "operator_env.template", "operator_bundle/operator_env.template"),
    (bundle_dir / "download_priority_queue.sh", "operator_bundle/download_priority_queue.sh"),
    (bundle_dir / "verify_materialization.sh", "operator_bundle/verify_materialization.sh"),
    (bundle_dir / "run_full_page_hash_sweep.sh", "operator_bundle/run_full_page_hash_sweep.sh"),
    (bundle_dir / "recheck_real_generation_admission.sh", "operator_bundle/recheck_real_generation_admission.sh"),
]:
    copy(src, rel)

operator_command_rows = read_csv(v61af_dir / "checkpoint_warehouse_operator_command_rows.csv")
if len(operator_command_rows) != 62:
    raise SystemExit("v61ag expects 62 v61af operator command rows")

download_rows = [row for row in operator_command_rows if row["command_type"] == "download-resume"]
target_paths = [Path(row["target_path"]) for row in download_rows if row["target_path"]]
warehouse_path = target_paths[0].parent if target_paths else Path(v61af_summary.get("ssd_warehouse_path", ""))
warehouse_outside_repo = int(not is_relative_to(warehouse_path.resolve(), root))
operator_bundle_ignored_by_git = git_check_ignored(v61af_dir / "operator_bundle" / "download_priority_queue.sh")
hf_cli_path = shutil.which("huggingface-cli") or ""
hf_cli_available = int(bool(hf_cli_path))

script_names = [
    "download_priority_queue.sh",
    "verify_materialization.sh",
    "run_full_page_hash_sweep.sh",
    "recheck_real_generation_admission.sh",
]
script_probe_rows = []
syntax_pass_rows = 0
executable_rows = 0
for script_name in script_names:
    path = bundle_dir / script_name
    syntax = subprocess.run(["bash", "-n", str(path)], check=False, text=True, capture_output=True)
    syntax_pass = int(syntax.returncode == 0)
    executable = int(os.access(path, os.X_OK))
    syntax_pass_rows += syntax_pass
    executable_rows += executable
    content = path.read_text(encoding="utf-8")
    has_dry_run_guard = int("dry-run" in content or "V61AF_EXECUTE" in content)
    script_probe_rows.append(
        {
            "script_name": script_name,
            "script_path": str(path),
            "script_sha256": sha256(path),
            "bash_syntax_exit_code": str(syntax.returncode),
            "bash_syntax_pass": str(syntax_pass),
            "executable_bit_set": str(executable),
            "has_dry_run_guard": str(has_dry_run_guard),
            "writes_inside_repository": "0",
            "checkpoint_payload_bytes_downloaded_by_v61ag": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

dry_env = os.environ.copy()
dry_env["V61AF_EXECUTE_DOWNLOAD"] = "0"
dry_env["V61AF_MAX_DOWNLOAD_ROWS"] = "1"
dry_run = subprocess.run(
    ["bash", str(bundle_dir / "download_priority_queue.sh")],
    cwd=root,
    env=dry_env,
    text=True,
    capture_output=True,
    check=False,
    timeout=60,
)
dry_stdout = dry_run.stdout[-4000:]
dry_stderr = dry_run.stderr[-4000:]
dry_run_guard_seen = int("dry-run: set V61AF_EXECUTE_DOWNLOAD=1 to execute" in dry_stdout)
dry_run_processed_one = int("processed 1 planned download rows" in dry_stdout)
dry_run_payload_blocked = int(dry_run.returncode == 0 and dry_run_guard_seen and dry_run_processed_one)
dry_run_probe_rows = [
    {
        "probe_id": "v61ag-download-dry-run-one-row",
        "script_name": "download_priority_queue.sh",
        "exit_code": str(dry_run.returncode),
        "stdout_sha256": sha256_text(dry_stdout),
        "stderr_sha256": sha256_text(dry_stderr),
        "dry_run_guard_seen": str(dry_run_guard_seen),
        "planned_download_rows_processed": "1" if dry_run_processed_one else "0",
        "payload_execution_blocked": str(dry_run_payload_blocked),
        "checkpoint_payload_bytes_downloaded_by_v61ag": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]

environment_rows = [
    {
        "check": "huggingface-cli",
        "status": "ready" if hf_cli_available else "blocked",
        "value": hf_cli_path,
        "required_for_download_execution": "1",
    },
    {
        "check": "warehouse-outside-repository",
        "status": "ready" if warehouse_outside_repo else "blocked",
        "value": str(warehouse_path),
        "required_for_download_execution": "1",
    },
    {
        "check": "operator-bundle-ignored-by-git",
        "status": "ready" if operator_bundle_ignored_by_git else "blocked",
        "value": str(bundle_dir),
        "required_for_download_execution": "0",
    },
    {
        "check": "ssd-disk-budget",
        "status": "ready" if v61af_summary["ssd_disk_budget_pass"] == "1" else "blocked",
        "value": f"available={v61af_summary['available_ssd_bytes']}; required={v61af_summary['required_with_reserve_bytes']}",
        "required_for_download_execution": "1",
    },
    {
        "check": "operator-dry-run-guard",
        "status": "ready" if dry_run_payload_blocked else "blocked",
        "value": f"exit_code={dry_run.returncode}",
        "required_for_download_execution": "1",
    },
]

download_execution_ready = int(
    hf_cli_available
    and warehouse_outside_repo
    and v61af_summary["ssd_disk_budget_pass"] == "1"
    and dry_run_payload_blocked
)
operator_execution_preflight_ready = int(
    download_execution_ready
    and syntax_pass_rows == len(script_names)
    and executable_rows == len(script_names)
)

gate_rows = [
    {"gate": "v61af-operator-bundle-input", "status": "pass", "reason": "v61af operator bundle is ready"},
    {"gate": "operator-script-syntax", "status": "pass" if syntax_pass_rows == len(script_names) else "blocked", "reason": f"{syntax_pass_rows}/{len(script_names)} scripts pass bash -n"},
    {"gate": "operator-script-executable", "status": "pass" if executable_rows == len(script_names) else "blocked", "reason": f"{executable_rows}/{len(script_names)} scripts have executable bit"},
    {"gate": "download-dry-run-guard", "status": "pass" if dry_run_payload_blocked else "blocked", "reason": "one-row dry-run completed without payload execution"},
    {"gate": "warehouse-outside-repository", "status": "pass" if warehouse_outside_repo else "blocked", "reason": str(warehouse_path)},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61ag writes metadata only"},
    {"gate": "huggingface-cli-available", "status": "pass" if hf_cli_available else "blocked", "reason": hf_cli_path or "huggingface-cli not found on PATH"},
    {"gate": "ssd-disk-budget-admission", "status": "pass" if v61af_summary["ssd_disk_budget_pass"] == "1" else "blocked", "reason": f"available={v61af_summary['available_ssd_bytes']}; required={v61af_summary['required_with_reserve_bytes']}"},
    {"gate": "download-execution", "status": "pass" if download_execution_ready else "blocked", "reason": "requires CLI, SSD budget, outside-repo warehouse, and explicit execution"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "execution preflight is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "execution preflight is not release evidence"},
]

metric = {
    "metric_id": "v61ag_checkpoint_warehouse_execution_preflight_metrics",
    "model_id": model_id,
    "operator_command_rows": str(len(operator_command_rows)),
    "download_command_rows": str(len(download_rows)),
    "script_probe_rows": str(len(script_probe_rows)),
    "script_bash_syntax_pass_rows": str(syntax_pass_rows),
    "script_executable_rows": str(executable_rows),
    "dry_run_probe_rows": str(len(dry_run_probe_rows)),
    "download_dry_run_exit_code": str(dry_run.returncode),
    "download_dry_run_guard_ready": str(dry_run_payload_blocked),
    "huggingface_cli_available": str(hf_cli_available),
    "warehouse_outside_repo": str(warehouse_outside_repo),
    "operator_bundle_ignored_by_git": str(operator_bundle_ignored_by_git),
    "ssd_disk_budget_pass": v61af_summary["ssd_disk_budget_pass"],
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "ssd_warehouse_path": v61af_summary["ssd_warehouse_path"],
    "available_ssd_bytes": v61af_summary["available_ssd_bytes"],
    "required_with_reserve_bytes": v61af_summary["required_with_reserve_bytes"],
    "download_execution_ready": str(download_execution_ready),
    "operator_execution_preflight_ready": str(operator_execution_preflight_ready),
    "local_checkpoint_materialization_ready": v61af_summary["local_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61af_summary["full_safetensors_page_hash_binding_ready"],
    "generation_admitted_rows": v61af_summary["generation_admitted_rows"],
    "checkpoint_payload_bytes_downloaded_by_v61ag": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}

write_csv(run_dir / "checkpoint_warehouse_environment_rows.csv", list(environment_rows[0].keys()), environment_rows)
write_csv(run_dir / "checkpoint_warehouse_operator_script_probe_rows.csv", list(script_probe_rows[0].keys()), script_probe_rows)
write_csv(run_dir / "checkpoint_warehouse_dry_run_probe_rows.csv", list(dry_run_probe_rows[0].keys()), dry_run_probe_rows)
write_csv(run_dir / "checkpoint_warehouse_execution_gate_rows.csv", ["gate", "status", "reason"], gate_rows)
write_csv(run_dir / "checkpoint_warehouse_execution_preflight_metric_rows.csv", list(metric.keys()), [metric])
write_csv(decision_csv, ["gate", "status", "reason"], gate_rows)

summary = {
    "v61ag_checkpoint_warehouse_execution_preflight_ready": "1",
    "v61af_checkpoint_warehouse_operator_bundle_ready": v61af_summary["v61af_checkpoint_warehouse_operator_bundle_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61ag Checkpoint Warehouse Execution Preflight Boundary

This artifact verifies the v61af operator bundle before any real checkpoint
payload download. It executes only a one-row dry-run download probe.

Evidence emitted:

- operator_command_rows={len(operator_command_rows)}
- download_command_rows={len(download_rows)}
- script_probe_rows={len(script_probe_rows)}
- script_bash_syntax_pass_rows={syntax_pass_rows}
- script_executable_rows={executable_rows}
- download_dry_run_exit_code={dry_run.returncode}
- download_dry_run_guard_ready={dry_run_payload_blocked}
- huggingface_cli_available={hf_cli_available}
- warehouse_outside_repo={warehouse_outside_repo}
- operator_bundle_ignored_by_git={operator_bundle_ignored_by_git}
- ssd_disk_budget_pass={v61af_summary['ssd_disk_budget_pass']}
- warehouse_root_override_supplied={int(bool(warehouse_root_override))}
- ssd_warehouse_path={v61af_summary['ssd_warehouse_path']}
- download_execution_ready={download_execution_ready}
- operator_execution_preflight_ready={operator_execution_preflight_ready}
- checkpoint_payload_bytes_downloaded_by_v61ag=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- download_execution_ready=0 unless CLI, SSD budget, outside-repo warehouse, and
  explicit operator execution gates pass.
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AG_CHECKPOINT_WAREHOUSE_EXECUTION_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ag_checkpoint_warehouse_execution_preflight",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61ag_checkpoint_warehouse_execution_preflight_ready": 1,
    "download_dry_run_guard_ready": dry_run_payload_blocked,
    "download_execution_ready": download_execution_ready,
    "operator_execution_preflight_ready": operator_execution_preflight_ready,
    "warehouse_root_override_supplied": int(bool(warehouse_root_override)),
    "ssd_warehouse_path": v61af_summary["ssd_warehouse_path"],
    "checkpoint_payload_bytes_downloaded_by_v61ag": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ag_checkpoint_warehouse_execution_preflight_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ag_checkpoint_warehouse_execution_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
