#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gz_post_gy_first_real_slice_source_witness_candidate"
RUN_ID="${V61GZ_RUN_ID:-source_candidate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61GZ_WORK_ROOT:-${V61GY_WORK_ROOT:-${V61GX_WORK_ROOT:-${V61GW_WORK_ROOT:-${V61GV_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}}}"
PUBLISH_CANDIDATE="${V61GZ_PUBLISH_CANDIDATE:-0}"
GY_RUN_ID="${V61GZ_V61GY_RUN_ID:-${RUN_ID}_guard}"

if [[ "${V61GZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gz_post_gy_first_real_slice_source_witness_candidate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GY_RUN_ID="$GY_RUN_ID" \
V61GY_WORK_ROOT="$WORK_ROOT" \
V61GY_PUBLISH_GUARD="$PUBLISH_CANDIDATE" \
V61GY_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gy_post_gx_first_real_slice_guarded_execution_publisher.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GY_RUN_ID" "$WORK_ROOT" "$PUBLISH_CANDIDATE" <<'PY'
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
gy_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61gz_post_gy_first_real_slice_source_witness_candidate"
package_dir = run_dir / "first_real_slice_source_witness_candidate"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GY_PREFIX = "v61gy_post_gx_first_real_slice_guarded_execution_publisher"
GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
H_PREFIX = "v53h_complete_source_content_snapshot"
gy_run_dir = results / GY_PREFIX / gy_run_id
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"
snapshot_root = results / H_PREFIX / "snapshot_001"


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
    "v61gy_summary": results / f"{GY_PREFIX}_summary.csv",
    "v61gy_decision": results / f"{GY_PREFIX}_decision.csv",
    "v61gy_guard_summary": gy_run_dir / "first_real_slice_guarded_execution_summary_rows.csv",
    "v61gi_review_worksheet": gi_scaffold / "MINIMAL_SLICE_REVIEW_WORKSHEET.json",
    "v61gi_selected_context": gi_scaffold / "MINIMAL_SLICE_SELECTED_CONTEXT.json",
    "v53h_snapshot_rows": snapshot_root / "complete_source_content_snapshot_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gz source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    folder = "source_v61gy" if label.startswith("v61gy") else ("source_v61gi" if label.startswith("v61gi") else "source_v53h")
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_source_witness_candidate_source_rows.csv", list(source_rows[0].keys()), source_rows)

gy = read_csv(source_paths["v61gy_summary"])[0]
if gy.get("v61gy_post_gx_first_real_slice_guarded_execution_publisher_ready") != "1":
    raise SystemExit("v61gz requires v61gy ready")

worksheet = json.loads(source_paths["v61gi_review_worksheet"].read_text(encoding="utf-8"))
span = worksheet["selected_source_span_row"]
local_relpath = span["local_relpath"]
expected_sha = span["source_file_sha256"]
source_file = snapshot_root / local_relpath
if not source_file.is_file():
    raise SystemExit(f"missing selected source file: {source_file}")
actual_sha = sha256(source_file)
candidate_hash_matches = int(actual_sha == expected_sha)
if not candidate_hash_matches:
    raise SystemExit(f"selected source sha mismatch: expected {expected_sha}, got {actual_sha}")

candidate_dir = run_dir / "source_file_witness_candidate"
candidate_dir.mkdir(parents=True, exist_ok=True)
candidate_file = candidate_dir / "source_file.txt.candidate"
shutil.copy2(source_file, candidate_file)

candidate_rows = [{
    "candidate_id": "source_file_txt_candidate",
    "selected_path": span["path"],
    "selected_local_relpath": local_relpath,
    "source_span_id": span["source_span_id"],
    "line_start": span["line_start"],
    "line_end": span["line_end"],
    "expected_source_file_sha256": expected_sha,
    "candidate_sha256": sha256(candidate_file),
    "candidate_bytes": str(candidate_file.stat().st_size),
    "candidate_hash_matches": str(candidate_hash_matches),
    "published_to_workspace": "0",
    "promoted_to_final_witness_by_v61gz": "0",
    "counts_as_evidence": "0",
}]
write_csv(run_dir / "first_real_slice_source_witness_candidate_rows.csv", list(candidate_rows[0].keys()), candidate_rows)

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
source_candidate_published = 0
if publish_admitted:
    workspace_candidate_dir = work_root / "source_witness_candidate"
    workspace_candidate_dir.mkdir(parents=True, exist_ok=True)
    workspace_candidate = workspace_candidate_dir / "source_file.txt.candidate"
    shutil.copy2(candidate_file, workspace_candidate)
    published_rows.append(add_published(workspace_candidate, "selected source file candidate; not final witness"))

    manifest = workspace_candidate_dir / "SOURCE_FILE_WITNESS_CANDIDATE_MANIFEST.json"
    manifest.write_text(
        json.dumps({
            "artifact": "source-file-witness-candidate",
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "counts_as_evidence": 0,
            "selected_path": span["path"],
            "selected_local_relpath": local_relpath,
            "source_span_id": span["source_span_id"],
            "expected_source_file_sha256": expected_sha,
            "candidate_sha256": sha256(workspace_candidate),
            "candidate_hash_matches": 1,
            "final_witness_target": "../final_content_witness/source_file.txt",
            "promotion_requires": "V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION=promote-selected-source-file-witness",
        }, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    published_rows.append(add_published(manifest, "source witness candidate manifest"))

    verifier = workspace_candidate_dir / "VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh"
    verifier.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            f"EXPECTED={shlex.quote(expected_sha)}",
            "ACTUAL=\"$(python3 - \"$DIR/source_file.txt.candidate\" <<'PY_HASH'",
            "import hashlib, sys",
            "path = sys.argv[1]",
            "h = hashlib.sha256()",
            "with open(path, 'rb') as handle:",
            "    for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "        h.update(chunk)",
            "print('sha256:' + h.hexdigest())",
            "PY_HASH",
            ")\"",
            "test \"$ACTUAL\" = \"$EXPECTED\"",
            "echo \"$ACTUAL\"",
            "",
        ]),
        encoding="utf-8",
    )
    verifier.chmod(0o755)
    published_rows.append(add_published(verifier, "candidate hash verifier"))

    promote = workspace_candidate_dir / "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh"
    promote.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            ": \"${V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION:?set to promote-selected-source-file-witness}\"",
            "test \"$V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION\" = promote-selected-source-file-witness",
            "\"$DIR/VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh\" >/dev/null",
            "TARGET=\"$DIR/../final_content_witness/source_file.txt\"",
            "mkdir -p \"$(dirname \"$TARGET\")\"",
            "cp \"$DIR/source_file.txt.candidate\" \"$TARGET\"",
            "python3 - \"$TARGET\" <<'PY_FINAL'",
            "import hashlib, sys",
            "path = sys.argv[1]",
            "h = hashlib.sha256()",
            "with open(path, 'rb') as handle:",
            "    for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "        h.update(chunk)",
            "print('promoted source_file.txt sha256:' + h.hexdigest())",
            "PY_FINAL",
            "",
        ]),
        encoding="utf-8",
    )
    promote.chmod(0o755)
    published_rows.append(add_published(promote, "explicit source witness promotion helper"))

    readme = workspace_candidate_dir / "SOURCE_WITNESS_CANDIDATE_README.md"
    readme.write_text(
        "\n".join([
            "# Source File Witness Candidate",
            "",
            "This directory is not external review evidence. It contains the selected source file candidate whose hash matches the first-slice worksheet.",
            "",
            f"- selected_path: {span['path']}",
            f"- selected_local_relpath: {local_relpath}",
            f"- source_span_id: {span['source_span_id']}",
            f"- expected_source_file_sha256: {expected_sha}",
            "",
            "To promote only this mechanical source witness after operator inspection:",
            "",
            "`V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION=promote-selected-source-file-witness ./PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh`",
            "",
            "Promotion writes `../final_content_witness/source_file.txt`. It does not fill review, adjudication, identity, conflict, answer, transcript, env, or replay evidence.",
            "",
        ]),
        encoding="utf-8",
    )
    published_rows.append(add_published(readme, "source witness candidate readme"))
    source_candidate_published = 1

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
write_csv(run_dir / "first_real_slice_source_witness_published_file_rows.csv", list(published_rows[0].keys()), published_rows)

published_count = len([row for row in published_rows if row["published_path"]])
open_gap_rows = int(gy.get("open_gap_rows", "0") or "0")
workspace_gap_preflight_ready = int(gy.get("workspace_gap_preflight_ready", "0") == "1")
summary_rows = [{
    "source_candidate_hash_matches": str(candidate_hash_matches),
    "source_candidate_published": str(source_candidate_published),
    "published_source_candidate_file_rows": str(published_count),
    "promoted_to_final_witness_by_v61gz": "0",
    "workspace_gap_preflight_ready": str(workspace_gap_preflight_ready),
    "open_gap_rows": str(open_gap_rows),
    "accepted_as_real_evidence": "0",
}]
write_csv(run_dir / "first_real_slice_source_witness_summary_rows.csv", list(summary_rows[0].keys()), summary_rows)

stage_rows = [
    {"stage_id": "01-v61gy-source", "status": "ready", "evidence": "v61gy guarded execution publisher ready"},
    {"stage_id": "02-source-snapshot", "status": "ready" if candidate_hash_matches else "blocked", "evidence": f"candidate_hash_matches={candidate_hash_matches}"},
    {"stage_id": "03-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "04-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "05-source-candidate-published", "status": "ready" if source_candidate_published else "blocked", "evidence": f"source_candidate_published={source_candidate_published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "06-promotion", "status": "blocked", "evidence": "promotion requires operator confirmation and is not run by v61gz"},
    {"stage_id": "07-workspace-gap-preflight", "status": "ready" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}; open_gap_rows={open_gap_rows}"},
    {"stage_id": "08-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_source_witness_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-source-candidate-package", "ready_to_run_now": "1", "command": "results/v61gz_post_gy_first_real_slice_source_witness_candidate/source_candidate_001/first_real_slice_source_witness_candidate/VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE.sh", "purpose": "verify this metadata package"},
    {"command_id": "02-print-source-candidate-location", "ready_to_run_now": "1", "command": "results/v61gz_post_gy_first_real_slice_source_witness_candidate/source_candidate_001/first_real_slice_source_witness_candidate/PRINT_SOURCE_WITNESS_CANDIDATE_LOCATION.sh", "purpose": "print workspace candidate directory"},
    {"command_id": "03-verify-workspace-source-candidate", "ready_to_run_now": str(source_candidate_published), "command": "<work-root>/source_witness_candidate/VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh", "purpose": "verify selected source candidate hash"},
    {"command_id": "04-promote-source-candidate", "ready_to_run_now": "0", "command": "V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION=promote-selected-source-file-witness <work-root>/source_witness_candidate/PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh", "purpose": "operator-confirmed mechanical promotion to final_content_witness/source_file.txt"},
]
write_csv(run_dir / "first_real_slice_source_witness_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE_ROWS.csv", run_dir / "first_real_slice_source_witness_candidate_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_SUMMARY_ROWS.csv", run_dir / "first_real_slice_source_witness_summary_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_PUBLISHED_FILE_ROWS.csv", run_dir / "first_real_slice_source_witness_published_file_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_STAGE_ROWS.csv", run_dir / "first_real_slice_source_witness_stage_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_COMMAND_ROWS.csv", run_dir / "first_real_slice_source_witness_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)
shutil.copy2(candidate_file, package_dir / "source_file.txt.candidate")

(package_dir / "VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_SOURCE_WITNESS_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE_ROWS.csv\"",
        "test -s \"$DIR/source_file.txt.candidate\"",
        f"EXPECTED={shlex.quote(expected_sha)}",
        "ACTUAL=\"$(python3 - \"$DIR/source_file.txt.candidate\" <<'PY_HASH'",
        "import hashlib, sys",
        "path = sys.argv[1]",
        "h = hashlib.sha256()",
        "with open(path, 'rb') as handle:",
        "    for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
        "        h.update(chunk)",
        "print('sha256:' + h.hexdigest())",
        "PY_HASH",
        ")\"",
        "test \"$ACTUAL\" = \"$EXPECTED\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE.sh").chmod(0o755)

candidate_location = work_root / "source_witness_candidate" if work_root else None
(package_dir / "PRINT_SOURCE_WITNESS_CANDIDATE_LOCATION.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"echo {shlex.quote(str(candidate_location) if candidate_location else '')}",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "PRINT_SOURCE_WITNESS_CANDIDATE_LOCATION.sh").chmod(0o755)

summary = {
    "v61gz_post_gy_first_real_slice_source_witness_candidate_ready": 1,
    "v61gy_post_gx_first_real_slice_guarded_execution_publisher_ready": 1,
    "source_candidate_hash_matches": candidate_hash_matches,
    "source_candidate_published": source_candidate_published,
    "published_source_candidate_file_rows": published_count,
    "promoted_to_final_witness_by_v61gz": 0,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "open_gap_rows": open_gap_rows,
    "workspace_gap_preflight_ready": workspace_gap_preflight_ready,
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
    "checkpoint_payload_bytes_downloaded_by_v61gz": 0,
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
    "candidate": candidate_rows[0],
    "work_root": str(work_root) if work_root else "",
    "candidate_location": str(candidate_location) if candidate_location else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_SOURCE_WITNESS_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

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
write_csv(run_dir / "first_real_slice_source_witness_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gy-ready", "status": "pass", "evidence": "v61gy ready"},
    {"gate": "source-snapshot-hash", "status": "pass" if candidate_hash_matches else "blocked", "evidence": f"candidate_hash_matches={candidate_hash_matches}"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "source-candidate-published", "status": "pass" if source_candidate_published else "blocked", "evidence": f"source_candidate_published={source_candidate_published}; errors={';'.join(publish_errors)}"},
    {"gate": "promotion", "status": "blocked", "evidence": "promotion requires explicit operator confirmation and is not run by v61gz"},
    {"gate": "workspace-gap-preflight", "status": "pass" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GZ_POST_GY_FIRST_REAL_SLICE_SOURCE_WITNESS_CANDIDATE_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GZ Post-GY First Real Slice Source Witness Candidate",
        "",
        "- v61gz_post_gy_first_real_slice_source_witness_candidate_ready=1",
        f"- source_candidate_hash_matches={candidate_hash_matches}",
        f"- source_candidate_published={source_candidate_published}",
        "- promoted_to_final_witness_by_v61gz=0",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this publishes a selected source-file candidate only. It does not promote the candidate, fill review/adjudication/generation witnesses, execute final replay, or count the candidate as real evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gz": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gz_post_gy_first_real_slice_source_witness_candidate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
