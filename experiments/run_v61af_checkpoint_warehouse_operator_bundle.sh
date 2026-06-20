#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61af_checkpoint_warehouse_operator_bundle"
RUN_ID="${V61AF_RUN_ID:-operator_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61AF_WAREHOUSE_ROOT:-${V61W_WAREHOUSE_ROOT:-${V61T_WAREHOUSE_ROOT:-${V61R_WAREHOUSE_ROOT:-${V61AE_WAREHOUSE_ROOT:-${V61P_SSD_WAREHOUSE_DIR:-${V61_WAREHOUSE_ROOT:-}}}}}}}"

if [[ "${V61AF_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61af_checkpoint_warehouse_operator_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61W_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null
  V61T_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
  V61R_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61R_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null
  V61AE_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ae_real_generation_admission_gate.sh" >/dev/null
else
  V61W_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null
  V61T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
  V61R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null
  V61AE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ae_real_generation_admission_gate.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
import csv
import hashlib
import json
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root_override = sys.argv[5].strip()
results = root / "results"
bundle_dir = run_dir / "operator_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)

model_id = "mistralai/Mixtral-8x22B-v0.1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


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


def rel_command(path):
    try:
        return "./" + str(path.resolve().relative_to(root))
    except ValueError:
        return str(path)


def env_prefix(assignments):
    parts = [f"{name}={shlex.quote(value)}" for name, value in assignments.items() if value]
    return " ".join(parts) + (" " if parts else "")


v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61r_dir = results / "v61r_full_page_hash_sweep_plan" / "plan_001"
v61ae_dir = results / "v61ae_real_generation_admission_gate" / "gate_001"

v61p_summary = read_csv(results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv")[0]
v61w_summary = read_csv(results / "v61w_materialization_admission_resume_plan_summary.csv")[0]
v61t_summary = read_csv(results / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
v61r_summary = read_csv(results / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
v61ae_summary = read_csv(results / "v61ae_real_generation_admission_gate_summary.csv")[0]

if v61w_summary.get("v61w_materialization_admission_resume_plan_ready") != "1":
    raise SystemExit("v61af requires v61w_materialization_admission_resume_plan_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61af requires v61t_local_checkpoint_materialization_verifier_ready=1")
if v61r_summary.get("v61r_full_page_hash_sweep_plan_ready") != "1":
    raise SystemExit("v61af requires v61r_full_page_hash_sweep_plan_ready=1")
if v61ae_summary.get("v61ae_real_generation_admission_gate_ready") != "1":
    raise SystemExit("v61af requires v61ae_real_generation_admission_gate_ready=1")

for src, rel in [
    (results / "v61p_local_ssd_checkpoint_residency_preflight_summary.csv", "source_v61p/v61p_local_ssd_checkpoint_residency_preflight_summary.csv"),
    (results / "v61w_materialization_admission_resume_plan_summary.csv", "source_v61w/v61w_materialization_admission_resume_plan_summary.csv"),
    (results / "v61w_materialization_admission_resume_plan_decision.csv", "source_v61w/v61w_materialization_admission_resume_plan_decision.csv"),
    (v61w_dir / "checkpoint_shard_priority_rows.csv", "source_v61w/checkpoint_shard_priority_rows.csv"),
    (v61w_dir / "checkpoint_download_resume_plan_rows.csv", "source_v61w/checkpoint_download_resume_plan_rows.csv"),
    (v61w_dir / "materialization_admission_metric_rows.csv", "source_v61w/materialization_admission_metric_rows.csv"),
    (v61w_dir / "materialization_runtime_gap_rows.csv", "source_v61w/materialization_runtime_gap_rows.csv"),
    (v61w_dir / "v61w_materialization_admission_resume_plan_manifest.json", "source_v61w/v61w_materialization_admission_resume_plan_manifest.json"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_summary.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "materialization_gap_rows.csv", "source_v61t/materialization_gap_rows.csv"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
    (results / "v61r_full_page_hash_sweep_plan_summary.csv", "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv"),
    (v61r_dir / "page_hash_sweep_metric_rows.csv", "source_v61r/page_hash_sweep_metric_rows.csv"),
    (v61r_dir / "shard_page_hash_sweep_status_rows.csv", "source_v61r/shard_page_hash_sweep_status_rows.csv"),
    (v61r_dir / "sha256_manifest.csv", "source_v61r/sha256_manifest.csv"),
    (results / "v61ae_real_generation_admission_gate_summary.csv", "source_v61ae/v61ae_real_generation_admission_gate_summary.csv"),
    (results / "v61ae_real_generation_admission_gate_decision.csv", "source_v61ae/v61ae_real_generation_admission_gate_decision.csv"),
    (v61ae_dir / "real_generation_admission_metric_rows.csv", "source_v61ae/real_generation_admission_metric_rows.csv"),
    (v61ae_dir / "runtime_gap_rows.csv", "source_v61ae/runtime_gap_rows.csv"),
    (v61ae_dir / "sha256_manifest.csv", "source_v61ae/sha256_manifest.csv"),
]:
    copy(src, rel)

resume_rows = read_csv(v61w_dir / "checkpoint_download_resume_plan_rows.csv")
priority_rows = read_csv(v61w_dir / "checkpoint_shard_priority_rows.csv")
if len(resume_rows) != 59 or len(priority_rows) != 59:
    raise SystemExit("v61af expects 59 v61w resume/priority rows")

verify_cmd = (
    env_prefix({"V61T_WAREHOUSE_ROOT": warehouse_root_override})
    + "V61T_REUSE_EXISTING=0 "
    + rel_command(root / "experiments" / "run_v61t_local_checkpoint_materialization_verifier.sh")
)
full_hash_cmd = (
    env_prefix({"V61R_WAREHOUSE_ROOT": warehouse_root_override})
    + "V61R_ENABLE_LOCAL_HASH_SWEEP=1 V61R_REUSE_EXISTING=0 "
    + rel_command(root / "experiments" / "run_v61r_full_page_hash_sweep_plan.sh")
)
admission_cmd = (
    env_prefix({"V61AE_WAREHOUSE_ROOT": warehouse_root_override})
    + "V61AE_REUSE_EXISTING=0 "
    + rel_command(root / "experiments" / "run_v61ae_real_generation_admission_gate.sh")
)

command_rows = []
for row in resume_rows:
    rank = int(row["priority_rank"])
    command_rows.append(
        {
            "operator_command_id": f"v61af-download-{rank:02d}",
            "stage": "download-priority-shard",
            "command_type": "download-resume",
            "priority_rank": row["priority_rank"],
            "shard_name": row["shard_name"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "shell_command": row["resume_command"],
            "dry_run_default": "1",
            "requires_explicit_execute": "1",
            "writes_inside_repository": row["writes_inside_repository"],
            "checkpoint_payload_bytes_downloaded_by_v61af": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "blocked_reason": row["blocked_reason"],
        }
    )

for command_id, stage, command_type, command, requires_execute, blocked_reason in [
    ("v61af-verify-materialization", "post-download-identity-verify", "verify", verify_cmd, "0", v61t_summary["local_checkpoint_materialization_ready"] == "1" and "" or "local-checkpoint-materialization-not-ready"),
    ("v61af-full-page-hash-sweep", "full-page-hash-sweep", "hash", full_hash_cmd, "1", v61r_summary["full_safetensors_page_hash_binding_ready"] == "1" and "" or "full-safetensors-page-hash-binding-not-ready"),
    ("v61af-recheck-generation-admission", "real-generation-admission-recheck", "admission", admission_cmd, "0", v61ae_summary["real_generation_admission_ready"] == "1" and "" or "real-generation-admission-not-ready"),
]:
    command_rows.append(
        {
            "operator_command_id": command_id,
            "stage": stage,
            "command_type": command_type,
            "priority_rank": "0",
            "shard_name": "",
            "target_path": "",
            "expected_bytes": "0",
            "shell_command": command,
            "dry_run_default": "1" if requires_execute == "1" else "0",
            "requires_explicit_execute": requires_execute,
            "writes_inside_repository": "0",
            "checkpoint_payload_bytes_downloaded_by_v61af": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "blocked_reason": blocked_reason,
        }
    )

stage_rows = [
    {
        "stage": "v61w-materialization-plan-input",
        "status": "ready",
        "evidence": "v61w download-resume and priority rows are copied",
    },
    {
        "stage": "operator-bundle-files",
        "status": "ready",
        "evidence": "dry-run guarded shell scripts and operator README are emitted",
    },
    {
        "stage": "download-dry-run-default",
        "status": "ready",
        "evidence": "download script requires V61AF_EXECUTE_DOWNLOAD=1 for payload download",
    },
    {
        "stage": "download-execution",
        "status": "blocked",
        "evidence": "current SSD budget admission remains blocked",
    },
    {
        "stage": "post-download-identity-verify",
        "status": "blocked",
        "evidence": "current host has zero identity-verified local checkpoint shards",
    },
    {
        "stage": "full-page-hash-sweep",
        "status": "blocked",
        "evidence": "full page-hash sweep requires identity-verified local shards and explicit hash execution",
    },
    {
        "stage": "real-generation-admission-recheck",
        "status": "blocked",
        "evidence": "v61ae admits zero generation rows until review/materialization/page-hash gates pass",
    },
    {
        "stage": "release-package",
        "status": "blocked",
        "evidence": "operator bundle is not release evidence",
    },
]

operator_files = [
    "README.md",
    "operator_env.template",
    "download_priority_queue.sh",
    "verify_materialization.sh",
    "run_full_page_hash_sweep.sh",
    "recheck_real_generation_admission.sh",
]

warehouse_env_lines = []
if warehouse_root_override:
    warehouse_env_lines.append(f"export V61AF_WAREHOUSE_ROOT={shlex.quote(warehouse_root_override)}")
warehouse_env_lines.extend(
    [
        'if [[ -n "${V61AF_WAREHOUSE_ROOT:-}" ]]; then',
        '  export V61_WAREHOUSE_ROOT="$V61AF_WAREHOUSE_ROOT"',
        '  export V61W_WAREHOUSE_ROOT="$V61AF_WAREHOUSE_ROOT"',
        '  export V61T_WAREHOUSE_ROOT="$V61AF_WAREHOUSE_ROOT"',
        '  export V61R_WAREHOUSE_ROOT="$V61AF_WAREHOUSE_ROOT"',
        '  export V61AE_WAREHOUSE_ROOT="$V61AF_WAREHOUSE_ROOT"',
        'elif [[ -n "${V61_WAREHOUSE_ROOT:-}" ]]; then',
        '  export V61W_WAREHOUSE_ROOT="${V61W_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
        '  export V61T_WAREHOUSE_ROOT="${V61T_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
        '  export V61R_WAREHOUSE_ROOT="${V61R_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
        '  export V61AE_WAREHOUSE_ROOT="${V61AE_WAREHOUSE_ROOT:-$V61_WAREHOUSE_ROOT}"',
        "fi",
    ]
)

download_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"',
    *warehouse_env_lines,
    ': "${V61AF_EXECUTE_DOWNLOAD:=0}"',
    ': "${V61AF_MAX_DOWNLOAD_ROWS:=0}"',
    'download_count=0',
    'run_download() {',
    '  local rank="$1"',
    '  local shard="$2"',
    '  local command="$3"',
    '  if [[ "$V61AF_MAX_DOWNLOAD_ROWS" != "0" && "$download_count" -ge "$V61AF_MAX_DOWNLOAD_ROWS" ]]; then',
    '    return 0',
    '  fi',
    '  download_count=$((download_count + 1))',
    '  echo "[v61af] rank=${rank} shard=${shard}"',
    '  echo "[v61af] ${command}"',
    '  if [[ "$V61AF_EXECUTE_DOWNLOAD" == "1" ]]; then',
    '    (cd "$ROOT_DIR" && bash -lc "$command")',
    '  else',
    '    echo "[v61af] dry-run: set V61AF_EXECUTE_DOWNLOAD=1 to execute"',
    '  fi',
    '}',
]
for row in resume_rows:
    download_lines.append(
        "run_download "
        + shlex.quote(row["priority_rank"])
        + " "
        + shlex.quote(row["shard_name"])
        + " "
        + shlex.quote(row["resume_command"])
    )
download_lines.append('echo "[v61af] processed ${download_count} planned download rows"')
(bundle_dir / "download_priority_queue.sh").write_text("\n".join(download_lines) + "\n", encoding="utf-8")

(bundle_dir / "verify_materialization.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"',
            *warehouse_env_lines,
            'cd "$ROOT_DIR"',
            verify_cmd,
            rel_command(root / "experiments" / "test_v61t_local_checkpoint_materialization_verifier.sh"),
        ]
    )
    + "\n",
    encoding="utf-8",
)

(bundle_dir / "run_full_page_hash_sweep.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"',
            *warehouse_env_lines,
            ': "${V61AF_EXECUTE_FULL_HASH:=0}"',
            'if [[ "$V61AF_EXECUTE_FULL_HASH" != "1" ]]; then',
            '  echo "[v61af] dry-run: set V61AF_EXECUTE_FULL_HASH=1 to hash every local checkpoint page"',
            "  exit 0",
            "fi",
            'cd "$ROOT_DIR"',
            full_hash_cmd,
            rel_command(root / "experiments" / "test_v61r_full_page_hash_sweep_plan.sh"),
        ]
    )
    + "\n",
    encoding="utf-8",
)

(bundle_dir / "recheck_real_generation_admission.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"',
            *warehouse_env_lines,
            'cd "$ROOT_DIR"',
            admission_cmd,
            rel_command(root / "experiments" / "test_v61ae_real_generation_admission_gate.sh"),
        ]
    )
    + "\n",
    encoding="utf-8",
)

warehouse_template_path = warehouse_root_override or v61p_summary["ssd_warehouse_path"]
(bundle_dir / "operator_env.template").write_text(
    "\n".join(
        [
            "export V61AF_EXECUTE_DOWNLOAD=0",
            "export V61AF_MAX_DOWNLOAD_ROWS=16",
            "export V61AF_EXECUTE_FULL_HASH=0",
            f"export V61_WAREHOUSE_ROOT={shlex.quote(warehouse_template_path)}",
            f"export V61AF_WAREHOUSE_ROOT={shlex.quote(warehouse_template_path)}",
            f"export V61W_WAREHOUSE_ROOT={shlex.quote(warehouse_template_path)}",
            f"export V61T_WAREHOUSE_ROOT={shlex.quote(warehouse_template_path)}",
            f"export V61R_WAREHOUSE_ROOT={shlex.quote(warehouse_template_path)}",
            f"export V61AE_WAREHOUSE_ROOT={shlex.quote(warehouse_template_path)}",
            f"export V61AF_WAREHOUSE_PATH={shlex.quote(warehouse_template_path)}",
        ]
    )
    + "\n",
    encoding="utf-8",
)

readme = f"""# v61af Checkpoint Warehouse Operator Bundle

This bundle turns the v61w materialization plan into guarded operator scripts.
It does not download checkpoint payload bytes by default.

Default state:

- model_id={model_id}
- checkpoint_shard_rows=59
- download_command_rows=59
- sampled_priority_shard_rows={v61w_summary['sampled_priority_shard_rows']}
- moe_priority_shard_rows={v61w_summary['moe_priority_shard_rows']}
- embedding_priority_shard_rows={v61w_summary['embedding_priority_shard_rows']}
- planned_remaining_bytes={v61w_summary['planned_remaining_bytes']}
- available_ssd_bytes={v61w_summary['available_ssd_bytes']}
- required_with_reserve_bytes={v61w_summary['required_with_reserve_bytes']}
- warehouse_root_override_supplied={int(bool(warehouse_root_override))}
- ssd_warehouse_path={v61p_summary['ssd_warehouse_path']}
- materialization_admission_ready={v61w_summary['materialization_admission_ready']}
- local_checkpoint_materialization_ready={v61t_summary['local_checkpoint_materialization_ready']}
- full_safetensors_page_hash_binding_ready={v61r_summary['full_safetensors_page_hash_binding_ready']}
- generation_admitted_rows={v61ae_summary['generation_admitted_rows']}
- checkpoint_payload_bytes_downloaded_by_v61af=0
- checkpoint_payload_bytes_committed_to_repo=0

Operator order:

1. Review `operator_env.template`.
2. Run `download_priority_queue.sh` in dry-run mode.
3. Set `V61AF_EXECUTE_DOWNLOAD=1` only on a machine with enough SSD budget.
4. Run `verify_materialization.sh`.
5. Set `V61AF_EXECUTE_FULL_HASH=1` and run `run_full_page_hash_sweep.sh`.
6. Run `recheck_real_generation_admission.sh`.

Blocked wording:

- download_execution=blocked until SSD budget admission is satisfied.
- local_checkpoint_materialization_ready=0 on the current host.
- full_safetensors_page_hash_binding_ready=0 on the current host.
- actual_model_generation_ready=0.
- near_frontier_claim_ready=0.
- production_latency_claim_ready=0.
- real_release_package_ready=0.
"""
(bundle_dir / "README.md").write_text(readme, encoding="utf-8")

for rel in operator_files:
    path = bundle_dir / rel
    if rel.endswith(".sh"):
        path.chmod(0o755)

write_csv(run_dir / "checkpoint_warehouse_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)
write_csv(run_dir / "checkpoint_warehouse_operator_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

metric = {
    "metric_id": "v61af_checkpoint_warehouse_operator_bundle_metrics",
    "model_id": model_id,
    "checkpoint_shard_rows": "59",
    "download_command_rows": "59",
    "operator_command_rows": str(len(command_rows)),
    "operator_bundle_file_rows": str(len(operator_files)),
    "sampled_priority_shard_rows": v61w_summary["sampled_priority_shard_rows"],
    "moe_priority_shard_rows": v61w_summary["moe_priority_shard_rows"],
    "embedding_priority_shard_rows": v61w_summary["embedding_priority_shard_rows"],
    "planned_remaining_bytes": v61w_summary["planned_remaining_bytes"],
    "available_ssd_bytes": v61w_summary["available_ssd_bytes"],
    "required_with_reserve_bytes": v61w_summary["required_with_reserve_bytes"],
    "ssd_disk_budget_pass": v61w_summary["ssd_disk_budget_pass"],
    "ssd_warehouse_outside_repo": v61w_summary["ssd_warehouse_outside_repo"],
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
    "download_dry_run_default": "1",
    "full_hash_dry_run_default": "1",
    "materialization_admission_ready": v61w_summary["materialization_admission_ready"],
    "local_checkpoint_materialization_ready": v61t_summary["local_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61r_summary["full_safetensors_page_hash_binding_ready"],
    "generation_candidate_rows": v61ae_summary["generation_candidate_rows"],
    "generation_admitted_rows": v61ae_summary["generation_admitted_rows"],
    "checkpoint_payload_bytes_downloaded_by_v61af": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "checkpoint_warehouse_operator_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61af_checkpoint_warehouse_operator_bundle_ready": "1",
    "v61w_materialization_admission_resume_plan_ready": v61w_summary["v61w_materialization_admission_resume_plan_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "v61r_full_page_hash_sweep_plan_ready": v61r_summary["v61r_full_page_hash_sweep_plan_ready"],
    "v61ae_real_generation_admission_gate_ready": v61ae_summary["v61ae_real_generation_admission_gate_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61w-materialization-plan-input", "status": "pass", "reason": "v61w plan is ready"},
    {"gate": "v61t-materialization-verifier-input", "status": "pass", "reason": "v61t verifier is ready"},
    {"gate": "v61r-page-hash-sweep-input", "status": "pass", "reason": "v61r sweep plan is ready"},
    {"gate": "v61ae-generation-admission-input", "status": "pass", "reason": "v61ae admission gate is ready"},
    {"gate": "operator-bundle-files", "status": "pass", "reason": "guarded scripts and README are emitted"},
    {"gate": "download-dry-run-default", "status": "pass", "reason": "payload download requires V61AF_EXECUTE_DOWNLOAD=1"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61af emits metadata and scripts only"},
    {"gate": "ssd-disk-budget-admission", "status": "blocked", "reason": "current SSD budget is below required reserve"},
    {"gate": "download-execution", "status": "blocked", "reason": "operator execution is guarded and current admission is blocked"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "0/59 local shards are identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "0/134161 local page hashes are verified"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "v61ae admits 0 generation rows"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "quality claims require real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "operator bundle is not a decode benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "operator bundle is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61af Checkpoint Warehouse Operator Bundle Boundary

This artifact turns the v61w materialization plan into guarded operator scripts
for a repo-outside NVMe checkpoint warehouse. It does not download checkpoint
payload bytes or execute full page hashing by default.

Evidence emitted:

- checkpoint_shard_rows=59
- download_command_rows=59
- operator_command_rows={len(command_rows)}
- operator_bundle_file_rows={len(operator_files)}
- sampled_priority_shard_rows={v61w_summary['sampled_priority_shard_rows']}
- moe_priority_shard_rows={v61w_summary['moe_priority_shard_rows']}
- embedding_priority_shard_rows={v61w_summary['embedding_priority_shard_rows']}
- planned_remaining_bytes={v61w_summary['planned_remaining_bytes']}
- available_ssd_bytes={v61w_summary['available_ssd_bytes']}
- required_with_reserve_bytes={v61w_summary['required_with_reserve_bytes']}
- warehouse_root_override_supplied={int(bool(warehouse_root_override))}
- ssd_warehouse_path={v61p_summary['ssd_warehouse_path']}
- download_dry_run_default=1
- full_hash_dry_run_default=1
- materialization_admission_ready={v61w_summary['materialization_admission_ready']}
- local_checkpoint_materialization_ready={v61t_summary['local_checkpoint_materialization_ready']}
- full_safetensors_page_hash_binding_ready={v61r_summary['full_safetensors_page_hash_binding_ready']}
- generation_admitted_rows={v61ae_summary['generation_admitted_rows']}
- checkpoint_payload_bytes_downloaded_by_v61af=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- ssd_disk_budget_admission=blocked
- download_execution=blocked
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0
"""
(run_dir / "V61AF_CHECKPOINT_WAREHOUSE_OPERATOR_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61af_checkpoint_warehouse_operator_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61af_checkpoint_warehouse_operator_bundle_ready": 1,
    "checkpoint_shard_rows": 59,
    "download_command_rows": 59,
    "operator_command_rows": len(command_rows),
    "operator_bundle_file_rows": len(operator_files),
    "warehouse_root_override_supplied": int(bool(warehouse_root_override)),
    "ssd_warehouse_path": v61p_summary["ssd_warehouse_path"],
    "download_dry_run_default": 1,
    "full_hash_dry_run_default": 1,
    "checkpoint_payload_bytes_downloaded_by_v61af": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
}
(run_dir / "v61af_checkpoint_warehouse_operator_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61af_checkpoint_warehouse_operator_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
