#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ah_checkpoint_download_backend_fallback_plan"
RUN_ID="${V61AH_RUN_ID:-plan_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61AH_WAREHOUSE_ROOT:-${V61AG_WAREHOUSE_ROOT:-${V61AF_WAREHOUSE_ROOT:-${V61W_WAREHOUSE_ROOT:-${V61T_WAREHOUSE_ROOT:-${V61R_WAREHOUSE_ROOT:-${V61AE_WAREHOUSE_ROOT:-${V61P_SSD_WAREHOUSE_DIR:-${V61_WAREHOUSE_ROOT:-}}}}}}}}}"

if [[ "${V61AH_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ah_checkpoint_download_backend_fallback_plan_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61AG_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61AG_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh" >/dev/null
else
  V61AG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ag_checkpoint_warehouse_execution_preflight.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
import csv
import hashlib
import json
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
warehouse_root_override = sys.argv[5].strip()
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"
bundle_dir = run_dir / "operator_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)


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


def version_line(command):
    if not command:
        return ""
    try:
        out = subprocess.check_output(command, text=True, stderr=subprocess.STDOUT, timeout=15)
        return out.splitlines()[0] if out.splitlines() else ""
    except Exception as exc:
        return f"version-probe-error:{type(exc).__name__}"


def shell_quote(value):
    return shlex.quote(str(value))


v61ag_dir = results / "v61ag_checkpoint_warehouse_execution_preflight" / "preflight_001"
v61af_dir = results / "v61af_checkpoint_warehouse_operator_bundle" / "operator_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

v61ag_summary = read_csv(results / "v61ag_checkpoint_warehouse_execution_preflight_summary.csv")[0]
v61af_summary = read_csv(results / "v61af_checkpoint_warehouse_operator_bundle_summary.csv")[0]
if v61ag_summary.get("v61ag_checkpoint_warehouse_execution_preflight_ready") != "1":
    raise SystemExit("v61ah requires v61ag_checkpoint_warehouse_execution_preflight_ready=1")
if v61af_summary.get("v61af_checkpoint_warehouse_operator_bundle_ready") != "1":
    raise SystemExit("v61ah requires v61af_checkpoint_warehouse_operator_bundle_ready=1")

for src, rel in [
    (results / "v61ag_checkpoint_warehouse_execution_preflight_summary.csv", "source_v61ag/v61ag_checkpoint_warehouse_execution_preflight_summary.csv"),
    (results / "v61ag_checkpoint_warehouse_execution_preflight_decision.csv", "source_v61ag/v61ag_checkpoint_warehouse_execution_preflight_decision.csv"),
    (v61ag_dir / "checkpoint_warehouse_environment_rows.csv", "source_v61ag/checkpoint_warehouse_environment_rows.csv"),
    (v61ag_dir / "checkpoint_warehouse_execution_gate_rows.csv", "source_v61ag/checkpoint_warehouse_execution_gate_rows.csv"),
    (v61ag_dir / "checkpoint_warehouse_execution_preflight_metric_rows.csv", "source_v61ag/checkpoint_warehouse_execution_preflight_metric_rows.csv"),
    (v61ag_dir / "V61AG_CHECKPOINT_WAREHOUSE_EXECUTION_PREFLIGHT_BOUNDARY.md", "source_v61ag/V61AG_CHECKPOINT_WAREHOUSE_EXECUTION_PREFLIGHT_BOUNDARY.md"),
    (v61ag_dir / "sha256_manifest.csv", "source_v61ag/sha256_manifest.csv"),
    (results / "v61af_checkpoint_warehouse_operator_bundle_summary.csv", "source_v61af/v61af_checkpoint_warehouse_operator_bundle_summary.csv"),
    (v61af_dir / "checkpoint_warehouse_operator_command_rows.csv", "source_v61af/checkpoint_warehouse_operator_command_rows.csv"),
    (v61af_dir / "sha256_manifest.csv", "source_v61af/sha256_manifest.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "checkpoint_download_resume_plan_rows.csv", "source_v61w/checkpoint_download_resume_plan_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

priority_rows = read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")
if len(priority_rows) != 59:
    raise SystemExit("v61ah expects 59 v61w priority rows")

curl_path = shutil.which("curl") or ""
wget_path = shutil.which("wget") or ""
aria2c_path = shutil.which("aria2c") or ""
hf_cli_path = shutil.which("huggingface-cli") or ""
try:
    import huggingface_hub  # type: ignore

    hf_hub_available = 1
    hf_hub_version = getattr(huggingface_hub, "__version__", "unknown")
except Exception as exc:
    hf_hub_available = 0
    hf_hub_version = f"import-error:{type(exc).__name__}"

backend_candidates = [
    {
        "backend_id": "curl-resume",
        "backend_kind": "direct-url",
        "available": str(int(bool(curl_path))),
        "version": version_line([curl_path, "--version"]) if curl_path else "",
        "resume_supported": "1",
        "redirect_supported": "1",
        "auth_env_supported": "1",
        "selection_rank": "1",
        "command_template": "curl -L --fail --retry 5 --continue-at - --output {target_path} {source_url}",
    },
    {
        "backend_id": "python-huggingface-hub",
        "backend_kind": "hf-api",
        "available": str(hf_hub_available),
        "version": hf_hub_version,
        "resume_supported": "1",
        "redirect_supported": "1",
        "auth_env_supported": "1",
        "selection_rank": "2",
        "command_template": "python3 -c 'from huggingface_hub import hf_hub_download; hf_hub_download(...)'",
    },
    {
        "backend_id": "wget-continue",
        "backend_kind": "direct-url",
        "available": str(int(bool(wget_path))),
        "version": version_line([wget_path, "--version"]) if wget_path else "",
        "resume_supported": "1",
        "redirect_supported": "1",
        "auth_env_supported": "1",
        "selection_rank": "3",
        "command_template": "wget -c -O {target_path} {source_url}",
    },
    {
        "backend_id": "huggingface-cli",
        "backend_kind": "hf-cli",
        "available": str(int(bool(hf_cli_path))),
        "version": version_line([hf_cli_path, "--version"]) if hf_cli_path else "",
        "resume_supported": "1",
        "redirect_supported": "1",
        "auth_env_supported": "1",
        "selection_rank": "4",
        "command_template": "huggingface-cli download {model_id} {shard_name} --local-dir {warehouse_path} --resume-download",
    },
    {
        "backend_id": "aria2c-continue",
        "backend_kind": "direct-url",
        "available": str(int(bool(aria2c_path))),
        "version": version_line([aria2c_path, "--version"]) if aria2c_path else "",
        "resume_supported": "1",
        "redirect_supported": "1",
        "auth_env_supported": "1",
        "selection_rank": "5",
        "command_template": "aria2c -c -x 4 -s 4 -o {filename} -d {target_dir} {source_url}",
    },
]

ready_backends = [row for row in backend_candidates if row["available"] == "1"]
if not ready_backends:
    selected_backend = ""
else:
    selected_backend = sorted(ready_backends, key=lambda row: int(row["selection_rank"]))[0]["backend_id"]

for row in backend_candidates:
    row["selected_backend"] = "1" if row["backend_id"] == selected_backend else "0"
    row["blocked_reason"] = "" if row["available"] == "1" else "backend-unavailable"

def command_for(row):
    source_url = row["source_url"]
    target_path = row["target_path"]
    target = Path(target_path)
    if selected_backend == "curl-resume":
        return (
            "mkdir -p "
            + shell_quote(target.parent)
            + " && curl -L --fail --retry 5 --continue-at - --output "
            + shell_quote(target)
            + " "
            + shell_quote(source_url)
        )
    if selected_backend == "wget-continue":
        return (
            "mkdir -p "
            + shell_quote(target.parent)
            + " && wget -c -O "
            + shell_quote(target)
            + " "
            + shell_quote(source_url)
        )
    if selected_backend == "huggingface-cli":
        return row["resume_command"]
    if selected_backend == "python-huggingface-hub":
        shard = row["shard_name"]
        target_dir = target.parent
        return (
            "python3 -c "
            + shell_quote(
                "from huggingface_hub import hf_hub_download; "
                f"hf_hub_download(repo_id='{model_id}', filename='{shard}', local_dir='{target_dir}', resume_download=True)"
            )
        )
    if selected_backend == "aria2c-continue":
        return (
            "mkdir -p "
            + shell_quote(target.parent)
            + " && aria2c -c -x 4 -s 4 -o "
            + shell_quote(target.name)
            + " -d "
            + shell_quote(target.parent)
            + " "
            + shell_quote(source_url)
        )
    return ""

backend_plan_rows = []
selected_backend_ready = int(bool(selected_backend))
download_execution_ready = int(
    selected_backend_ready
    and v61ag_summary["ssd_disk_budget_pass"] == "1"
    and v61ag_summary["warehouse_outside_repo"] == "1"
)
for row in priority_rows:
    command = command_for(row)
    backend_plan_rows.append(
        {
            "priority_rank": row["priority_rank"],
            "model_id": model_id,
            "shard_name": row["shard_name"],
            "source_url": row["source_url"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "selected_backend_id": selected_backend,
            "selected_backend_ready": str(selected_backend_ready),
            "download_command": command,
            "dry_run_default": "1",
            "requires_explicit_execute": "1",
            "download_execution_ready": str(download_execution_ready),
            "blocked_reason": "" if download_execution_ready else "ssd-disk-budget",
            "checkpoint_payload_bytes_downloaded_by_v61ah": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

write_csv(run_dir / "checkpoint_download_backend_candidate_rows.csv", list(backend_candidates[0].keys()), backend_candidates)
write_csv(run_dir / "checkpoint_download_backend_plan_rows.csv", list(backend_plan_rows[0].keys()), backend_plan_rows)

download_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"',
    *( [f"export V61AH_WAREHOUSE_ROOT={shell_quote(warehouse_root_override)}"] if warehouse_root_override else [] ),
    'if [[ -n "${V61AH_WAREHOUSE_ROOT:-}" ]]; then',
    '  export V61_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    '  export V61AG_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    '  export V61AF_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    '  export V61W_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    '  export V61T_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    '  export V61R_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    '  export V61AE_WAREHOUSE_ROOT="$V61AH_WAREHOUSE_ROOT"',
    'elif [[ -n "${V61_WAREHOUSE_ROOT:-}" ]]; then',
    '  export V61AG_WAREHOUSE_ROOT="${V61AG_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
    '  export V61AF_WAREHOUSE_ROOT="${V61AF_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
    '  export V61W_WAREHOUSE_ROOT="${V61W_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
    '  export V61T_WAREHOUSE_ROOT="${V61T_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
    '  export V61R_WAREHOUSE_ROOT="${V61R_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
    '  export V61AE_WAREHOUSE_ROOT="${V61AE_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
    "fi",
    ': "${V61AH_EXECUTE_DOWNLOAD:=0}"',
    ': "${V61AH_MAX_DOWNLOAD_ROWS:=0}"',
    'download_count=0',
    'run_download() {',
    '  local rank="$1"',
    '  local shard="$2"',
    '  local command="$3"',
    '  if [[ "$V61AH_MAX_DOWNLOAD_ROWS" != "0" && "$download_count" -ge "$V61AH_MAX_DOWNLOAD_ROWS" ]]; then',
    '    return 0',
    '  fi',
    '  download_count=$((download_count + 1))',
    '  echo "[v61ah] rank=${rank} shard=${shard}"',
    '  echo "[v61ah] ${command}"',
    '  if [[ "$V61AH_EXECUTE_DOWNLOAD" == "1" ]]; then',
    '    (cd "$ROOT_DIR" && bash -lc "$command")',
    '  else',
    '    echo "[v61ah] dry-run: set V61AH_EXECUTE_DOWNLOAD=1 to execute"',
    '  fi',
    '}',
]
for row in backend_plan_rows:
    download_lines.append(
        "run_download "
        + shell_quote(row["priority_rank"])
        + " "
        + shell_quote(row["shard_name"])
        + " "
        + shell_quote(row["download_command"])
    )
download_lines.append('echo "[v61ah] processed ${download_count} backend download rows"')
(bundle_dir / "download_priority_queue_backend.sh").write_text("\n".join(download_lines) + "\n", encoding="utf-8")
(bundle_dir / "download_priority_queue_backend.sh").chmod(0o755)

dry_env = dict(**__import__("os").environ)
dry_env["V61AH_EXECUTE_DOWNLOAD"] = "0"
dry_env["V61AH_MAX_DOWNLOAD_ROWS"] = "1"
dry_run = subprocess.run(
    ["bash", str(bundle_dir / "download_priority_queue_backend.sh")],
    cwd=root,
    env=dry_env,
    text=True,
    capture_output=True,
    check=False,
    timeout=60,
)
dry_stdout = dry_run.stdout[-4000:]
dry_run_guard_seen = int("dry-run: set V61AH_EXECUTE_DOWNLOAD=1 to execute" in dry_stdout)
dry_run_processed_one = int("processed 1 backend download rows" in dry_stdout)
dry_run_probe_ready = int(dry_run.returncode == 0 and dry_run_guard_seen and dry_run_processed_one)

dry_run_rows = [
    {
        "probe_id": "v61ah-backend-dry-run-one-row",
        "selected_backend_id": selected_backend,
        "exit_code": str(dry_run.returncode),
        "stdout_sha256": sha256_text(dry_stdout),
        "dry_run_guard_seen": str(dry_run_guard_seen),
        "planned_download_rows_processed": "1" if dry_run_processed_one else "0",
        "payload_execution_blocked": str(dry_run_probe_ready),
        "checkpoint_payload_bytes_downloaded_by_v61ah": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "checkpoint_download_backend_dry_run_rows.csv", list(dry_run_rows[0].keys()), dry_run_rows)

metric = {
    "metric_id": "v61ah_checkpoint_download_backend_fallback_plan_metrics",
    "model_id": model_id,
    "backend_candidate_rows": str(len(backend_candidates)),
    "ready_backend_rows": str(sum(1 for row in backend_candidates if row["available"] == "1")),
    "selected_backend_id": selected_backend,
    "selected_backend_ready": str(selected_backend_ready),
    "download_backend_plan_rows": str(len(backend_plan_rows)),
    "download_backend_dry_run_exit_code": str(dry_run.returncode),
    "download_backend_dry_run_guard_ready": str(dry_run_probe_ready),
    "huggingface_cli_available": str(int(bool(hf_cli_path))),
    "python_huggingface_hub_available": str(hf_hub_available),
    "curl_available": str(int(bool(curl_path))),
    "wget_available": str(int(bool(wget_path))),
    "aria2c_available": str(int(bool(aria2c_path))),
    "ssd_disk_budget_pass": v61ag_summary["ssd_disk_budget_pass"],
    "warehouse_outside_repo": v61ag_summary["warehouse_outside_repo"],
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "ssd_warehouse_path": v61af_summary["ssd_warehouse_path"],
    "download_execution_ready": str(download_execution_ready),
    "local_checkpoint_materialization_ready": v61ag_summary["local_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61ag_summary["full_safetensors_page_hash_binding_ready"],
    "generation_admitted_rows": v61ag_summary["generation_admitted_rows"],
    "checkpoint_payload_bytes_downloaded_by_v61ah": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "checkpoint_download_backend_metric_rows.csv", list(metric.keys()), [metric])

decision_rows = [
    {"gate": "v61ag-execution-preflight-input", "status": "pass", "reason": "v61ag preflight is ready"},
    {"gate": "download-backend-probe", "status": "pass", "reason": f"{metric['ready_backend_rows']}/5 backend candidates are available"},
    {"gate": "selected-download-backend", "status": "pass" if selected_backend_ready else "blocked", "reason": selected_backend or "no backend selected"},
    {"gate": "backend-dry-run-guard", "status": "pass" if dry_run_probe_ready else "blocked", "reason": "one-row backend dry-run completed without payload execution"},
    {"gate": "huggingface-cli-primary", "status": "blocked" if not hf_cli_path else "pass", "reason": hf_cli_path or "huggingface-cli not found, fallback backend selected"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61ah emits metadata and dry-run scripts only"},
    {"gate": "ssd-disk-budget-admission", "status": "pass" if v61ag_summary["ssd_disk_budget_pass"] == "1" else "blocked", "reason": "download execution still requires SSD budget admission"},
    {"gate": "download-execution", "status": "pass" if download_execution_ready else "blocked", "reason": "selected backend is ready but execution still requires SSD budget and explicit execution"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "backend fallback plan is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "backend fallback plan is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61ah_checkpoint_download_backend_fallback_plan_ready": "1",
    "v61ag_checkpoint_warehouse_execution_preflight_ready": v61ag_summary["v61ag_checkpoint_warehouse_execution_preflight_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

boundary = f"""# v61ah Checkpoint Download Backend Fallback Plan Boundary

This artifact removes the hard dependency on `huggingface-cli` by selecting an
available fallback download backend for the v61 checkpoint warehouse. It does
not download checkpoint payload bytes.

Evidence emitted:

- backend_candidate_rows={len(backend_candidates)}
- ready_backend_rows={metric['ready_backend_rows']}
- selected_backend_id={selected_backend}
- selected_backend_ready={selected_backend_ready}
- download_backend_plan_rows={len(backend_plan_rows)}
- download_backend_dry_run_guard_ready={dry_run_probe_ready}
- huggingface_cli_available={int(bool(hf_cli_path))}
- python_huggingface_hub_available={hf_hub_available}
- curl_available={int(bool(curl_path))}
- wget_available={int(bool(wget_path))}
- aria2c_available={int(bool(aria2c_path))}
- ssd_disk_budget_pass={v61ag_summary['ssd_disk_budget_pass']}
- warehouse_root_override_supplied={int(bool(warehouse_root_override))}
- ssd_warehouse_path={v61af_summary['ssd_warehouse_path']}
- download_execution_ready={download_execution_ready}
- checkpoint_payload_bytes_downloaded_by_v61ah=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- download_execution_ready=0 until SSD budget admission and explicit execution
  gates pass.
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AH_CHECKPOINT_DOWNLOAD_BACKEND_FALLBACK_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ah_checkpoint_download_backend_fallback_plan",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61ah_checkpoint_download_backend_fallback_plan_ready": 1,
    "selected_backend_id": selected_backend,
    "download_backend_dry_run_guard_ready": dry_run_probe_ready,
    "download_execution_ready": download_execution_ready,
    "warehouse_root_override_supplied": int(bool(warehouse_root_override)),
    "ssd_warehouse_path": v61af_summary["ssd_warehouse_path"],
    "checkpoint_payload_bytes_downloaded_by_v61ah": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ah_checkpoint_download_backend_fallback_plan_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ah_checkpoint_download_backend_fallback_plan_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
