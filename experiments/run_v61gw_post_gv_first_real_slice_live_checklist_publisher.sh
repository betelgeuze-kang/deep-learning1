#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gw_post_gv_first_real_slice_live_checklist_publisher"
RUN_ID="${V61GW_RUN_ID:-publish_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61GW_WORK_ROOT:-${V61GV_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}"
PUBLISH_CHECKLIST="${V61GW_PUBLISH_CHECKLIST:-0}"
GV_RUN_ID="${V61GW_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61GW_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gw_post_gv_first_real_slice_live_checklist_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_CHECKLIST" <<'PY'
import csv
import hashlib
import json
import shlex
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
gv_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61gw_post_gv_first_real_slice_live_checklist_publisher"
package_dir = run_dir / "first_real_slice_live_checklist_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GV_PREFIX = "v61gv_post_gu_first_real_slice_workspace_gap_audit"


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


gv_run_dir = results / GV_PREFIX / gv_run_id
source_paths = {
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_decision": results / f"{GV_PREFIX}_decision.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
    "v61gv_witness_rows": gv_run_dir / "first_real_slice_workspace_witness_rows.csv",
    "v61gv_env_rows": gv_run_dir / "first_real_slice_workspace_env_rows.csv",
    "v61gv_stage_rows": gv_run_dir / "first_real_slice_workspace_gap_stage_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gw source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gv") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_live_checklist_source_rows.csv", list(source_rows[0].keys()), source_rows)

gv = read_csv(source_paths["v61gv_summary"])[0]
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61gw requires v61gv ready")

missing_rows = read_csv(source_paths["v61gv_missing_items"])
witness_rows = read_csv(source_paths["v61gv_witness_rows"])
env_rows = read_csv(source_paths["v61gv_env_rows"])
open_gap_rows = sum(row.get("status") != "no-gap-detected" for row in missing_rows)
gap_counts = Counter(row.get("item_family", "") for row in missing_rows if row.get("status") != "no-gap-detected")
work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo)
publish_errors = []
if publish_requested and not work_root_supplied:
    publish_errors.append("missing-work-root")
if work_root_supplied and not work_root_outside_repo:
    publish_errors.append("work-root-inside-repo")

published_rows = []
published = 0
if publish_admitted:
    checklist_dir = work_root / "live_gap_checklist"
    checklist_dir.mkdir(parents=True, exist_ok=True)
    copies = [
        ("FIRST_REAL_SLICE_MISSING_ITEMS.csv", source_paths["v61gv_missing_items"]),
        ("FIRST_REAL_SLICE_WITNESS_ROWS.csv", source_paths["v61gv_witness_rows"]),
        ("FIRST_REAL_SLICE_ENV_ROWS.csv", source_paths["v61gv_env_rows"]),
        ("FIRST_REAL_SLICE_GAP_STAGE_ROWS.csv", source_paths["v61gv_stage_rows"]),
    ]
    for name, src in copies:
        dst = checklist_dir / name
        shutil.copy2(src, dst)
        published_rows.append({
            "published_path": str(dst),
            "relative_path": dst.relative_to(work_root).as_posix(),
            "bytes": str(dst.stat().st_size),
            "sha256": sha256(dst),
            "metadata_only": "1",
            "payload_like": "0",
        })

    checklist_md = checklist_dir / "LIVE_FIRST_REAL_SLICE_GAP_CHECKLIST.md"
    lines = [
        "# Live First Real Slice Gap Checklist",
        "",
        f"- generated_at_utc: {datetime.now(timezone.utc).isoformat()}",
        f"- work_root: {work_root}",
        f"- workspace_gap_preflight_ready: {gv.get('workspace_gap_preflight_ready', '0')}",
        f"- open_gap_rows: {open_gap_rows}",
        f"- content_witness_gap_rows: {gap_counts.get('content-witness', 0)}",
        f"- env_value_gap_rows: {gap_counts.get('env-value', 0)}",
        "- real_external_review_return_rows: 0",
        "- real_generation_result_artifacts: 0",
        "- actual_model_generation_ready: 0",
        "",
        "This checklist is not evidence. Fill the listed witness files and env values, rerun the audit, and execute the final runner only after `workspace_gap_preflight_ready=1`.",
        "",
        "## Missing Items",
    ]
    for row in missing_rows:
        if row.get("status") == "no-gap-detected":
            continue
        lines.append(f"- {row.get('item_id')}: {row.get('status')} -> {row.get('path_or_env')}")
    checklist_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    published_rows.append({
        "published_path": str(checklist_md),
        "relative_path": checklist_md.relative_to(work_root).as_posix(),
        "bytes": str(checklist_md.stat().st_size),
        "sha256": sha256(checklist_md),
        "metadata_only": "1",
        "payload_like": "0",
    })

    rerun = checklist_dir / "RERUN_FIRST_REAL_SLICE_GAP_AUDIT.sh"
    rerun.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            f"WORK_ROOT={shlex.quote(str(work_root))}",
            "V61GV_RUN_ID=\"${V61GV_RUN_ID:-operator_live_gap_audit}\" \\",
            "V61GV_WORK_ROOT=\"$WORK_ROOT\" \\",
            "V61GV_REUSE_EXISTING=0 \\",
            "\"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh\"",
            "",
        ]),
        encoding="utf-8",
    )
    rerun.chmod(0o755)
    published_rows.append({
        "published_path": str(rerun),
        "relative_path": rerun.relative_to(work_root).as_posix(),
        "bytes": str(rerun.stat().st_size),
        "sha256": sha256(rerun),
        "metadata_only": "1",
        "payload_like": "0",
    })
    published = 1

if not published_rows:
    published_rows.append({
        "published_path": "",
        "relative_path": "",
        "bytes": "0",
        "sha256": "",
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "first_real_slice_live_checklist_published_file_rows.csv", list(published_rows[0].keys()), published_rows)

gap_summary_rows = [{
    "open_gap_rows": str(open_gap_rows),
    "content_witness_gap_rows": str(gap_counts.get("content-witness", 0)),
    "env_value_gap_rows": str(gap_counts.get("env-value", 0)),
    "workspace_gap_preflight_ready": gv.get("workspace_gap_preflight_ready", "0"),
    "published_to_workspace": str(published),
    "accepted_as_real_evidence": "0",
}]
write_csv(run_dir / "first_real_slice_live_checklist_gap_summary_rows.csv", list(gap_summary_rows[0].keys()), gap_summary_rows)

stage_rows = [
    {"stage_id": "01-v61gv-source", "status": "ready", "evidence": "v61gv gap audit ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "04-live-checklist-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "05-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={open_gap_rows}"},
    {"stage_id": "06-real-return-execution", "status": "blocked", "evidence": "publisher never executes final replay"},
    {"stage_id": "07-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_live_checklist_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-publisher-package", "ready_to_run_now": "1", "command": "results/v61gw_post_gv_first_real_slice_live_checklist_publisher/publish_001/first_real_slice_live_checklist_publisher/VERIFY_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER.sh", "purpose": "verify metadata package"},
    {"command_id": "02-print-live-checklist-location", "ready_to_run_now": "1", "command": "results/v61gw_post_gv_first_real_slice_live_checklist_publisher/publish_001/first_real_slice_live_checklist_publisher/PRINT_LIVE_CHECKLIST_LOCATION.sh", "purpose": "print live checklist path"},
    {"command_id": "03-rerun-workspace-gap-audit", "ready_to_run_now": str(published), "command": "<work-root>/live_gap_checklist/RERUN_FIRST_REAL_SLICE_GAP_AUDIT.sh", "purpose": "rerun after witness/env edits"},
]
write_csv(run_dir / "first_real_slice_live_checklist_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_LIVE_CHECKLIST_GAP_SUMMARY_ROWS.csv", run_dir / "first_real_slice_live_checklist_gap_summary_rows.csv"),
    ("FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHED_FILE_ROWS.csv", run_dir / "first_real_slice_live_checklist_published_file_rows.csv"),
    ("FIRST_REAL_SLICE_LIVE_CHECKLIST_STAGE_ROWS.csv", run_dir / "first_real_slice_live_checklist_stage_rows.csv"),
    ("FIRST_REAL_SLICE_LIVE_CHECKLIST_COMMAND_ROWS.csv", run_dir / "first_real_slice_live_checklist_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_LIVE_CHECKLIST_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_LIVE_CHECKLIST_GAP_SUMMARY_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHED_FILE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_LIVE_CHECKLIST_STAGE_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gw package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER.sh").chmod(0o755)

live_path = work_root / "live_gap_checklist" / "LIVE_FIRST_REAL_SLICE_GAP_CHECKLIST.md" if work_root else None
(package_dir / "PRINT_LIVE_CHECKLIST_LOCATION.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"echo {shlex.quote(str(live_path) if live_path else '')}",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "PRINT_LIVE_CHECKLIST_LOCATION.sh").chmod(0o755)

summary = {
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "live_checklist_published": published,
    "published_file_rows": len([row for row in published_rows if row["published_path"]]),
    "open_gap_rows": open_gap_rows,
    "content_witness_gap_rows": gap_counts.get("content-witness", 0),
    "env_value_gap_rows": gap_counts.get("env-value", 0),
    "workspace_gap_preflight_ready": int(gv.get("workspace_gap_preflight_ready", "0") == "1"),
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
    "checkpoint_payload_bytes_downloaded_by_v61gw": 0,
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
    "live_checklist_path": str(live_path) if live_path else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_LIVE_CHECKLIST_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

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
write_csv(run_dir / "first_real_slice_live_checklist_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gv-ready", "status": "pass", "evidence": "v61gv ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "live-checklist-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "publisher never executes final replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GW_POST_GV_FIRST_REAL_SLICE_LIVE_CHECKLIST_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GW Post-GV First Real Slice Live Checklist Publisher",
        "",
        "- v61gw_post_gv_first_real_slice_live_checklist_publisher_ready=1",
        f"- live_checklist_published={published}",
        f"- open_gap_rows={open_gap_rows}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this publishes a non-evidence checklist only. It does not execute final replay or count witness/env files as real evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gw": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gw_post_gv_first_real_slice_live_checklist_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
