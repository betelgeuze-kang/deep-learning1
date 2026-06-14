#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gy_post_gx_first_real_slice_guarded_execution_publisher"
RUN_ID="${V61GY_RUN_ID:-guard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61GY_WORK_ROOT:-${V61GX_WORK_ROOT:-${V61GW_WORK_ROOT:-${V61GV_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}}"
PUBLISH_GUARD="${V61GY_PUBLISH_GUARD:-0}"
GX_RUN_ID="${V61GY_V61GX_RUN_ID:-${RUN_ID}_context_bundle}"

if [[ "${V61GY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gy_post_gx_first_real_slice_guarded_execution_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GX_RUN_ID="$GX_RUN_ID" \
V61GX_WORK_ROOT="$WORK_ROOT" \
V61GX_PUBLISH_CONTEXT="$PUBLISH_GUARD" \
V61GX_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gx_post_gw_first_real_slice_context_bundle_publisher.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GX_RUN_ID" "$WORK_ROOT" "$PUBLISH_GUARD" <<'PY'
import csv
import hashlib
import json
import os
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
gx_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61gy_post_gx_first_real_slice_guarded_execution_publisher"
package_dir = run_dir / "first_real_slice_guarded_execution_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GX_PREFIX = "v61gx_post_gw_first_real_slice_context_bundle_publisher"
gx_run_dir = results / GX_PREFIX / gx_run_id


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


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


def add_published(path, description):
    return {
        "published_path": str(path),
        "relative_path": path.relative_to(work_root).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "description": description,
        "metadata_only": "1",
        "counts_as_evidence": "0",
        "payload_like": "0",
    }


source_paths = {
    "v61gx_summary": results / f"{GX_PREFIX}_summary.csv",
    "v61gx_decision": results / f"{GX_PREFIX}_decision.csv",
    "v61gx_context_summary": gx_run_dir / "first_real_slice_context_bundle_summary_rows.csv",
    "v61gx_published_files": gx_run_dir / "first_real_slice_context_bundle_published_file_rows.csv",
    "v61gx_stage_rows": gx_run_dir / "first_real_slice_context_bundle_stage_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gy source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gx") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_guarded_execution_source_rows.csv", list(source_rows[0].keys()), source_rows)

gx = read_csv(source_paths["v61gx_summary"])[0]
if gx.get("v61gx_post_gw_first_real_slice_context_bundle_publisher_ready") != "1":
    raise SystemExit("v61gy requires v61gx ready")

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo)
publish_errors = []
if publish_requested and not work_root_supplied:
    publish_errors.append("missing-work-root")
if work_root_supplied and not work_root_outside_repo:
    publish_errors.append("work-root-inside-repo")

workspace_gap_preflight_ready = int(gx.get("workspace_gap_preflight_ready", "0") == "1")
open_gap_rows = int(gx.get("open_gap_rows", "0") or "0")
content_witness_gap_rows = int(gx.get("content_witness_gap_rows", "0") or "0")
env_value_gap_rows = int(gx.get("env_value_gap_rows", "0") or "0")
context_bundle_published = int(gx.get("context_bundle_published", "0") == "1")

published_rows = []
guarded_runner_published = 0
if publish_admitted:
    guard_dir = work_root / "guarded_execution"
    guard_dir.mkdir(parents=True, exist_ok=True)

    runner = work_root / "RUN_GAP_READY_FIRST_REAL_SLICE.sh"
    runner.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            "WORK_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "AUDIT_RUN_ID=\"${V61GY_AUDIT_RUN_ID:-operator_gap_ready_audit}\"",
            "V61GV_RUN_ID=\"$AUDIT_RUN_ID\" \\",
            "V61GV_WORK_ROOT=\"$WORK_ROOT\" \\",
            "V61GV_REUSE_EXISTING=0 \\",
            "\"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh\" >/dev/null",
            "SUMMARY=\"$ROOT_DIR/results/v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv\"",
            "MISSING=\"$ROOT_DIR/results/v61gv_post_gu_first_real_slice_workspace_gap_audit/$AUDIT_RUN_ID/first_real_slice_workspace_missing_item_rows.csv\"",
            "python3 - \"$SUMMARY\" \"$MISSING\" <<'PY_CHECK'",
            "import csv, sys",
            "summary_path, missing_path = sys.argv[1:3]",
            "with open(summary_path, newline='', encoding='utf-8') as handle:",
            "    row = next(csv.DictReader(handle))",
            "if row.get('workspace_gap_preflight_ready') != '1':",
            "    print('workspace_gap_preflight_ready=0; final replay is blocked', file=sys.stderr)",
            "    print(f\"open_gap_rows={row.get('open_gap_rows', 'unknown')}\", file=sys.stderr)",
            "    try:",
            "        with open(missing_path, newline='', encoding='utf-8') as handle:",
            "            for item in csv.DictReader(handle):",
            "                if item.get('status') != 'no-gap-detected':",
            "                    print(f\"{item.get('item_id')}: {item.get('status')} -> {item.get('path_or_env')}\", file=sys.stderr)",
            "    except FileNotFoundError:",
            "        pass",
            "    raise SystemExit(2)",
            "print('workspace_gap_preflight_ready=1; executing first-real-slice runner')",
            "PY_CHECK",
            "source \"$WORK_ROOT/FIRST_REAL_SLICE_ENV_TEMPLATE.sh\"",
            "exec \"$WORK_ROOT/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh\"",
            "",
        ]),
        encoding="utf-8",
    )
    runner.chmod(0o755)
    published_rows.append(add_published(runner, "gap-ready guarded first-real-slice runner"))

    audit_only = guard_dir / "RUN_GAP_READY_AUDIT_ONLY.sh"
    audit_only.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            "WORK_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/..\" && pwd)\"",
            "V61GV_RUN_ID=\"${V61GV_RUN_ID:-operator_guard_audit_only}\" \\",
            "V61GV_WORK_ROOT=\"$WORK_ROOT\" \\",
            "V61GV_REUSE_EXISTING=0 \\",
            "\"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh\"",
            "",
        ]),
        encoding="utf-8",
    )
    audit_only.chmod(0o755)
    published_rows.append(add_published(audit_only, "audit-only guarded execution preflight"))

    readme = guard_dir / "GUARDED_EXECUTION_README.md"
    readme.write_text(
        "\n".join([
            "# First Real Slice Guarded Execution",
            "",
            "This directory is not evidence. It contains the final guard for running the first-real-slice path only after the live workspace gap audit is closed.",
            "",
            "Run order after external finalization:",
            "",
            "1. Fill the seven files under `../final_content_witness/` with final external content.",
            "2. Replace every `REPLACE_WITH_*` value in `../FIRST_REAL_SLICE_ENV_TEMPLATE.sh`.",
            "3. Run `./RUN_GAP_READY_AUDIT_ONLY.sh` from this directory until the audit reports `workspace_gap_preflight_ready=1`.",
            "4. Run `../RUN_GAP_READY_FIRST_REAL_SLICE.sh`.",
            "",
            "The guarded runner exits before sourcing env or executing replay when witness/env gaps remain.",
            "",
        ]),
        encoding="utf-8",
    )
    published_rows.append(add_published(readme, "guarded execution readme"))

    manifest = guard_dir / "GUARDED_EXECUTION_MANIFEST.json"
    manifest.write_text(
        json.dumps({
            "artifact": "first-real-slice-guarded-execution-workspace-files",
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "counts_as_evidence": 0,
            "runner": "../RUN_GAP_READY_FIRST_REAL_SLICE.sh",
            "audit_only": "RUN_GAP_READY_AUDIT_ONLY.sh",
            "requires_workspace_gap_preflight_ready": 1,
            "actual_model_generation_ready": 0,
        }, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    published_rows.append(add_published(manifest, "guarded execution workspace manifest"))
    guarded_runner_published = 1

if not published_rows:
    published_rows.append({
        "published_path": "",
        "relative_path": "",
        "bytes": "0",
        "sha256": "",
        "description": "",
        "metadata_only": "1",
        "counts_as_evidence": "0",
        "payload_like": "0",
    })
write_csv(run_dir / "first_real_slice_guarded_execution_published_file_rows.csv", list(published_rows[0].keys()), published_rows)

published_count = len([row for row in published_rows if row["published_path"]])
guard_summary_rows = [{
    "guarded_runner_published": str(guarded_runner_published),
    "published_guard_file_rows": str(published_count),
    "context_bundle_published": str(context_bundle_published),
    "workspace_gap_preflight_ready": str(workspace_gap_preflight_ready),
    "open_gap_rows": str(open_gap_rows),
    "accepted_as_real_evidence": "0",
}]
write_csv(run_dir / "first_real_slice_guarded_execution_summary_rows.csv", list(guard_summary_rows[0].keys()), guard_summary_rows)

stage_rows = [
    {"stage_id": "01-v61gx-source", "status": "ready", "evidence": "v61gx context bundle publisher ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "04-guarded-runner-published", "status": "ready" if guarded_runner_published else "blocked", "evidence": f"guarded_runner_published={guarded_runner_published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "05-workspace-gap-preflight", "status": "ready" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}; open_gap_rows={open_gap_rows}"},
    {"stage_id": "06-guarded-execution", "status": "blocked", "evidence": "publisher writes runner but does not execute final replay"},
    {"stage_id": "07-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_guarded_execution_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-guard-package", "ready_to_run_now": "1", "command": "results/v61gy_post_gx_first_real_slice_guarded_execution_publisher/guard_001/first_real_slice_guarded_execution_publisher/VERIFY_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER.sh", "purpose": "verify this metadata package"},
    {"command_id": "02-print-guarded-command", "ready_to_run_now": "1", "command": "results/v61gy_post_gx_first_real_slice_guarded_execution_publisher/guard_001/first_real_slice_guarded_execution_publisher/PRINT_GUARDED_EXECUTION_COMMAND.sh", "purpose": "print guarded execution command"},
    {"command_id": "03-run-gap-ready-audit-only", "ready_to_run_now": str(guarded_runner_published), "command": "<work-root>/guarded_execution/RUN_GAP_READY_AUDIT_ONLY.sh", "purpose": "rerun workspace gap audit without final replay"},
    {"command_id": "04-run-gap-ready-first-real-slice", "ready_to_run_now": str(int(guarded_runner_published and workspace_gap_preflight_ready)), "command": "<work-root>/RUN_GAP_READY_FIRST_REAL_SLICE.sh", "purpose": "execute only after workspace_gap_preflight_ready=1"},
]
write_csv(run_dir / "first_real_slice_guarded_execution_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_GUARDED_EXECUTION_SOURCE_ROWS.csv", run_dir / "first_real_slice_guarded_execution_source_rows.csv"),
    ("FIRST_REAL_SLICE_GUARDED_EXECUTION_SUMMARY_ROWS.csv", run_dir / "first_real_slice_guarded_execution_summary_rows.csv"),
    ("FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHED_FILE_ROWS.csv", run_dir / "first_real_slice_guarded_execution_published_file_rows.csv"),
    ("FIRST_REAL_SLICE_GUARDED_EXECUTION_STAGE_ROWS.csv", run_dir / "first_real_slice_guarded_execution_stage_rows.csv"),
    ("FIRST_REAL_SLICE_GUARDED_EXECUTION_COMMAND_ROWS.csv", run_dir / "first_real_slice_guarded_execution_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_GUARDED_EXECUTION_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_GUARDED_EXECUTION_SOURCE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_GUARDED_EXECUTION_SUMMARY_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHED_FILE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_GUARDED_EXECUTION_STAGE_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gy package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER.sh").chmod(0o755)

guarded_command = work_root / "RUN_GAP_READY_FIRST_REAL_SLICE.sh" if work_root else None
(package_dir / "PRINT_GUARDED_EXECUTION_COMMAND.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"echo {shlex.quote(str(guarded_command) if guarded_command else '')}",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "PRINT_GUARDED_EXECUTION_COMMAND.sh").chmod(0o755)

summary = {
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_ready": 1,
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "guarded_runner_published": guarded_runner_published,
    "published_guard_file_rows": published_count,
    "context_bundle_published": context_bundle_published,
    "open_gap_rows": open_gap_rows,
    "content_witness_gap_rows": content_witness_gap_rows,
    "env_value_gap_rows": env_value_gap_rows,
    "workspace_gap_preflight_ready": workspace_gap_preflight_ready,
    "guarded_execution_ready_now": int(guarded_runner_published and workspace_gap_preflight_ready),
    "guarded_execution_attempted_by_v61gy": 0,
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "row_acceptance_ready": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "authority_bound_replay_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gy": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows),
    "payload_like_package_file_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "work_root": str(work_root) if work_root else "",
    "guarded_command": str(guarded_command) if guarded_command else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_GUARDED_EXECUTION_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "first_real_slice_guarded_execution_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gx-ready", "status": "pass", "evidence": "v61gx ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "guarded-runner-published", "status": "pass" if guarded_runner_published else "blocked", "evidence": f"guarded_runner_published={guarded_runner_published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}"},
    {"gate": "guarded-execution", "status": "blocked", "evidence": "publisher never executes final replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GY_POST_GX_FIRST_REAL_SLICE_GUARDED_EXECUTION_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GY Post-GX First Real Slice Guarded Execution Publisher",
        "",
        "- v61gy_post_gx_first_real_slice_guarded_execution_publisher_ready=1",
        f"- guarded_runner_published={guarded_runner_published}",
        f"- guarded_execution_ready_now={summary['guarded_execution_ready_now']}",
        f"- open_gap_rows={open_gap_rows}",
        "- guarded_execution_attempted_by_v61gy=0",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this publishes a fail-closed execution runner only. It does not execute final replay or count workspace files as real evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gy": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gy_post_gx_first_real_slice_guarded_execution_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
