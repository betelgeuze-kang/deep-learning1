#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gx_post_gw_first_real_slice_context_bundle_publisher"
RUN_ID="${V61GX_RUN_ID:-context_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61GX_WORK_ROOT:-${V61GW_WORK_ROOT:-${V61GV_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}"
PUBLISH_CONTEXT="${V61GX_PUBLISH_CONTEXT:-0}"
GW_RUN_ID="${V61GX_V61GW_RUN_ID:-${RUN_ID}_live_checklist}"

if [[ "${V61GX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gx_post_gw_first_real_slice_context_bundle_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GI_REUSE_EXISTING=1 \
"$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

V61GW_RUN_ID="$GW_RUN_ID" \
V61GW_WORK_ROOT="$WORK_ROOT" \
V61GW_PUBLISH_CHECKLIST="$PUBLISH_CONTEXT" \
V61GW_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gw_post_gv_first_real_slice_live_checklist_publisher.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GW_RUN_ID" "$WORK_ROOT" "$PUBLISH_CONTEXT" <<'PY'
import csv
import hashlib
import json
import os
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
gw_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61gx_post_gw_first_real_slice_context_bundle_publisher"
package_dir = run_dir / "first_real_slice_context_bundle_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
GW_PREFIX = "v61gw_post_gv_first_real_slice_live_checklist_publisher"
gi_run_dir = results / GI_PREFIX / "scaffold_001"
gi_scaffold = gi_run_dir / "authority_bound_operator_input_scaffold"
gw_run_dir = results / GW_PREFIX / gw_run_id


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


def copy_publish(src, dst, description):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "published_path": str(dst),
        "relative_path": dst.relative_to(work_root).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "description": description,
        "metadata_only": "1",
        "counts_as_evidence": "0",
        "payload_like": "0",
    }


source_paths = {
    "v61gw_summary": results / f"{GW_PREFIX}_summary.csv",
    "v61gw_decision": results / f"{GW_PREFIX}_decision.csv",
    "v61gw_gap_summary": gw_run_dir / "first_real_slice_live_checklist_gap_summary_rows.csv",
    "v61gw_published_files": gw_run_dir / "first_real_slice_live_checklist_published_file_rows.csv",
    "v61gw_stage_rows": gw_run_dir / "first_real_slice_live_checklist_stage_rows.csv",
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_decision": results / f"{GI_PREFIX}_decision.csv",
    "v61gi_selected_context_json": gi_scaffold / "MINIMAL_SLICE_SELECTED_CONTEXT.json",
    "v61gi_selected_context_md": gi_scaffold / "MINIMAL_SLICE_SELECTED_CONTEXT.md",
    "v61gi_review_worksheet_json": gi_scaffold / "MINIMAL_SLICE_REVIEW_WORKSHEET.json",
    "v61gi_review_worksheet_md": gi_scaffold / "MINIMAL_SLICE_REVIEW_WORKSHEET.md",
    "v61gi_witness_manifest": gi_run_dir / "authority_bound_operator_content_witness_manifest_rows.csv",
    "v61gi_context_rows": gi_run_dir / "authority_bound_operator_minimal_slice_context_rows.csv",
    "v61gi_review_worksheet_rows": gi_run_dir / "authority_bound_operator_minimal_slice_review_worksheet_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gx source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    folder = "source_v61gw" if label.startswith("v61gw") else "source_v61gi"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_context_bundle_source_rows.csv", list(source_rows[0].keys()), source_rows)

gi = read_csv(source_paths["v61gi_summary"])[0]
gw = read_csv(source_paths["v61gw_summary"])[0]
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gx requires v61gi ready")
if gw.get("v61gw_post_gv_first_real_slice_live_checklist_publisher_ready") != "1":
    raise SystemExit("v61gx requires v61gw ready")

gw_gap = read_csv(source_paths["v61gw_gap_summary"])[0]
witness_manifest_rows = read_csv(source_paths["v61gi_witness_manifest"])
context_rows = read_csv(source_paths["v61gi_context_rows"])
worksheet_rows = read_csv(source_paths["v61gi_review_worksheet_rows"])
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
context_dir = work_root / "operator_context" if work_root else None
context_bundle_published = 0
if publish_admitted:
    context_dir.mkdir(parents=True, exist_ok=True)
    published_rows.extend([
        copy_publish(source_paths["v61gi_selected_context_json"], context_dir / "MINIMAL_SLICE_SELECTED_CONTEXT.json", "selected minimal slice context json"),
        copy_publish(source_paths["v61gi_selected_context_md"], context_dir / "MINIMAL_SLICE_SELECTED_CONTEXT.md", "selected minimal slice context markdown"),
        copy_publish(source_paths["v61gi_review_worksheet_json"], context_dir / "MINIMAL_SLICE_REVIEW_WORKSHEET.json", "review worksheet json"),
        copy_publish(source_paths["v61gi_review_worksheet_md"], context_dir / "MINIMAL_SLICE_REVIEW_WORKSHEET.md", "review worksheet markdown"),
        copy_publish(source_paths["v61gi_witness_manifest"], context_dir / "CONTENT_WITNESS_MANIFEST_ROWS.csv", "required final witness file manifest"),
        copy_publish(source_paths["v61gi_review_worksheet_rows"], context_dir / "MINIMAL_SLICE_REVIEW_WORKSHEET_ROWS.csv", "worksheet checksum rows"),
    ])

    map_rows = []
    for row in witness_manifest_rows:
        map_rows.append({
            "witness_id": row["witness_id"],
            "required_filename": row["required_filename"],
            "final_witness_path": f"../final_content_witness/{row['required_filename']}",
            "context_reference": "MINIMAL_SLICE_REVIEW_WORKSHEET.md",
            "csv_sha_field": row["csv_sha_field"],
            "csv_path_field": row["csv_path_field"],
            "counts_as_evidence_before_final_fill": "0",
        })
    witness_map = context_dir / "WITNESS_TO_CONTEXT_MAP.csv"
    write_csv(witness_map, list(map_rows[0].keys()), map_rows)
    published_rows.append({
        "published_path": str(witness_map),
        "relative_path": witness_map.relative_to(work_root).as_posix(),
        "bytes": str(witness_map.stat().st_size),
        "sha256": sha256(witness_map),
        "description": "maps required witness filenames to selected context",
        "metadata_only": "1",
        "counts_as_evidence": "0",
        "payload_like": "0",
    })

    readme = context_dir / "OPERATOR_CONTEXT_README.md"
    readme.write_text(
        "\n".join([
            "# First Real Slice Operator Context",
            "",
            "This directory is a non-evidence operator guide. It does not count as external review, adjudication, generation, latency, quality, comparison, release, or model-generation evidence.",
            "",
            "Read these files before filling final witness content:",
            "",
            "- `MINIMAL_SLICE_SELECTED_CONTEXT.md`",
            "- `MINIMAL_SLICE_REVIEW_WORKSHEET.md`",
            "- `CONTENT_WITNESS_MANIFEST_ROWS.csv`",
            "- `WITNESS_TO_CONTEXT_MAP.csv`",
            "",
            "The final witness files must be written under `../final_content_witness/`, not in this directory.",
            "After witness/env finalization, rerun `../live_gap_checklist/RERUN_FIRST_REAL_SLICE_GAP_AUDIT.sh` and only then run `../RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh` if the gap audit is ready.",
            "",
        ]),
        encoding="utf-8",
    )
    published_rows.append({
        "published_path": str(readme),
        "relative_path": readme.relative_to(work_root).as_posix(),
        "bytes": str(readme.stat().st_size),
        "sha256": sha256(readme),
        "description": "operator context readme",
        "metadata_only": "1",
        "counts_as_evidence": "0",
        "payload_like": "0",
    })

    rerun = context_dir / "RERUN_FIRST_REAL_SLICE_CONTEXT_BUNDLE.sh"
    rerun.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            f"WORK_ROOT={shlex.quote(str(work_root))}",
            "V61GX_RUN_ID=\"${V61GX_RUN_ID:-operator_context_refresh}\" \\",
            "V61GX_WORK_ROOT=\"$WORK_ROOT\" \\",
            "V61GX_PUBLISH_CONTEXT=1 \\",
            "V61GX_REUSE_EXISTING=0 \\",
            "\"$ROOT_DIR/experiments/run_v61gx_post_gw_first_real_slice_context_bundle_publisher.sh\"",
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
        "description": "rerun context bundle publisher",
        "metadata_only": "1",
        "counts_as_evidence": "0",
        "payload_like": "0",
    })
    context_bundle_published = 1

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
write_csv(run_dir / "first_real_slice_context_bundle_published_file_rows.csv", list(published_rows[0].keys()), published_rows)

published_count = len([row for row in published_rows if row["published_path"]])
open_gap_rows = int(gw.get("open_gap_rows", gw_gap.get("open_gap_rows", "0")))
content_witness_gap_rows = int(gw.get("content_witness_gap_rows", gw_gap.get("content_witness_gap_rows", "0")))
env_value_gap_rows = int(gw.get("env_value_gap_rows", gw_gap.get("env_value_gap_rows", "0")))
workspace_gap_preflight_ready = int(gw.get("workspace_gap_preflight_ready", gw_gap.get("workspace_gap_preflight_ready", "0")) == "1")

context_summary_rows = [{
    "selected_context_file_rows": str(len(context_rows)),
    "review_worksheet_file_rows": str(len(worksheet_rows)),
    "witness_manifest_rows": str(len(witness_manifest_rows)),
    "published_context_file_rows": str(published_count),
    "context_bundle_published": str(context_bundle_published),
    "accepted_as_real_evidence": "0",
}]
write_csv(run_dir / "first_real_slice_context_bundle_summary_rows.csv", list(context_summary_rows[0].keys()), context_summary_rows)

stage_rows = [
    {"stage_id": "01-v61gi-source", "status": "ready", "evidence": "v61gi operator input scaffold ready"},
    {"stage_id": "02-v61gw-source", "status": "ready", "evidence": "v61gw live checklist publisher ready"},
    {"stage_id": "03-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "04-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "05-operator-context-published", "status": "ready" if context_bundle_published else "blocked", "evidence": f"context_bundle_published={context_bundle_published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "06-workspace-gap-preflight", "status": "ready" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}; open_gap_rows={open_gap_rows}"},
    {"stage_id": "07-real-return-execution", "status": "blocked", "evidence": "context publisher never executes final replay"},
    {"stage_id": "08-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_context_bundle_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-context-bundle", "ready_to_run_now": "1", "command": "results/v61gx_post_gw_first_real_slice_context_bundle_publisher/context_001/first_real_slice_context_bundle_publisher/VERIFY_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER.sh", "purpose": "verify this metadata package"},
    {"command_id": "02-print-operator-context-location", "ready_to_run_now": "1", "command": "results/v61gx_post_gw_first_real_slice_context_bundle_publisher/context_001/first_real_slice_context_bundle_publisher/PRINT_OPERATOR_CONTEXT_LOCATION.sh", "purpose": "print operator context path"},
    {"command_id": "03-rerun-context-publisher", "ready_to_run_now": str(context_bundle_published), "command": "<work-root>/operator_context/RERUN_FIRST_REAL_SLICE_CONTEXT_BUNDLE.sh", "purpose": "refresh context bundle after upstream scaffold changes"},
    {"command_id": "04-run-first-real-slice", "ready_to_run_now": "0", "command": "<work-root>/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh", "purpose": "execute only after final external witness/env preflight is ready"},
]
write_csv(run_dir / "first_real_slice_context_bundle_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_CONTEXT_BUNDLE_SOURCE_ROWS.csv", run_dir / "first_real_slice_context_bundle_source_rows.csv"),
    ("FIRST_REAL_SLICE_CONTEXT_BUNDLE_SUMMARY_ROWS.csv", run_dir / "first_real_slice_context_bundle_summary_rows.csv"),
    ("FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHED_FILE_ROWS.csv", run_dir / "first_real_slice_context_bundle_published_file_rows.csv"),
    ("FIRST_REAL_SLICE_CONTEXT_BUNDLE_STAGE_ROWS.csv", run_dir / "first_real_slice_context_bundle_stage_rows.csv"),
    ("FIRST_REAL_SLICE_CONTEXT_BUNDLE_COMMAND_ROWS.csv", run_dir / "first_real_slice_context_bundle_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CONTEXT_BUNDLE_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CONTEXT_BUNDLE_SOURCE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CONTEXT_BUNDLE_SUMMARY_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHED_FILE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CONTEXT_BUNDLE_STAGE_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gx package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER.sh").chmod(0o755)

operator_context_path = context_dir if context_dir else None
(package_dir / "PRINT_OPERATOR_CONTEXT_LOCATION.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"echo {shlex.quote(str(operator_context_path) if operator_context_path else '')}",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "PRINT_OPERATOR_CONTEXT_LOCATION.sh").chmod(0o755)

summary = {
    "v61gx_post_gw_first_real_slice_context_bundle_publisher_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "v61gw_post_gv_first_real_slice_live_checklist_publisher_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "context_bundle_published": context_bundle_published,
    "published_context_file_rows": published_count,
    "selected_context_file_rows": len(context_rows),
    "review_worksheet_file_rows": len(worksheet_rows),
    "witness_manifest_rows": len(witness_manifest_rows),
    "open_gap_rows": open_gap_rows,
    "content_witness_gap_rows": content_witness_gap_rows,
    "env_value_gap_rows": env_value_gap_rows,
    "workspace_gap_preflight_ready": workspace_gap_preflight_ready,
    "final_witness_files_written_by_v61gx": 0,
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
    "checkpoint_payload_bytes_downloaded_by_v61gx": 0,
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
    "operator_context_path": str(operator_context_path) if operator_context_path else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_CONTEXT_BUNDLE_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
payload_like_ext = {".safetensors", ".gguf", ".bin", ".pt", ".pth"}
for path in package_files:
    payload_like = int(path.suffix.lower() in payload_like_ext)
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "first_real_slice_context_bundle_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gi-ready", "status": "pass", "evidence": "v61gi ready"},
    {"gate": "source-v61gw-ready", "status": "pass", "evidence": "v61gw ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "operator-context-published", "status": "pass" if context_bundle_published else "blocked", "evidence": f"context_bundle_published={context_bundle_published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "context publisher never executes final replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-final-witness-created-by-v61gx", "status": "pass", "evidence": "final_witness_files_written_by_v61gx=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GX_POST_GW_FIRST_REAL_SLICE_CONTEXT_BUNDLE_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GX Post-GW First Real Slice Context Bundle Publisher",
        "",
        "- v61gx_post_gw_first_real_slice_context_bundle_publisher_ready=1",
        f"- context_bundle_published={context_bundle_published}",
        f"- published_context_file_rows={published_count}",
        f"- open_gap_rows={open_gap_rows}",
        "- final_witness_files_written_by_v61gx=0",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this publishes non-evidence operator context only. It does not write final witness files, execute final replay, or count context files as real evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gx": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gx_post_gw_first_real_slice_context_bundle_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
