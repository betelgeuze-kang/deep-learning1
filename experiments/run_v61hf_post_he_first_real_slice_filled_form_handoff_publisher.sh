#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hf_post_he_first_real_slice_filled_form_handoff_publisher"
RUN_ID="${V61HF_RUN_ID:-filled_form_handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HF_WORK_ROOT:-${V61GU_WORK_ROOT:-}}"
PUBLISH_HANDOFF="${V61HF_PUBLISH_HANDOFF:-0}"
GV_RUN_ID="${V61HF_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61HF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hf_post_he_first_real_slice_filled_form_handoff_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61he_post_hd_first_real_slice_form_materializer_publisher.sh" >/dev/null
V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_HANDOFF" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
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
prefix = "v61hf_post_he_first_real_slice_filled_form_handoff_publisher"
package_dir = run_dir / "first_real_slice_filled_form_handoff_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HE_PREFIX = "v61he_post_hd_first_real_slice_form_materializer_publisher"
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
    "v61he_summary": results / f"{HE_PREFIX}_summary.csv",
    "v61he_decision": results / f"{HE_PREFIX}_decision.csv",
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hf source {label}: {path}")
source_rows = [copy_source(label, path, "source_v61he" if label.startswith("v61he") else "source_v61gv") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_filled_form_handoff_source_rows.csv", list(source_rows[0].keys()), source_rows)

he = read_csv(source_paths["v61he_summary"])[0]
gv = read_csv(source_paths["v61gv_summary"])[0]
if he.get("v61he_post_hd_first_real_slice_form_materializer_publisher_ready") != "1":
    raise SystemExit("v61hf requires v61he ready")
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61hf requires v61gv ready")

handoff_text = """#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=%(root)s
WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORM_PATH="${V61HF_FORM_PATH:-$WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json}"
AUDIT_RUN_ID="${V61HF_AUDIT_RUN_ID:-filled_form_handoff_gap_audit}"
if [[ ! -s "$FORM_PATH" ]]; then
  echo "filled external return form missing: $FORM_PATH" >&2
  exit 2
fi
"$WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" "$FORM_PATH"
"$WORK_ROOT/RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh" >/dev/null
V61GV_RUN_ID="$AUDIT_RUN_ID" \\
V61GV_WORK_ROOT="$WORK_ROOT" \\
V61GV_REUSE_EXISTING=0 \\
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null
SUMMARY="$ROOT_DIR/results/v61gv_post_gu_first_real_slice_workspace_gap_audit_summary.csv"
MISSING="$ROOT_DIR/results/v61gv_post_gu_first_real_slice_workspace_gap_audit/$AUDIT_RUN_ID/first_real_slice_workspace_missing_item_rows.csv"
python3 - "$SUMMARY" "$MISSING" <<'PY_CHECK'
import csv, sys
summary_path, missing_path = sys.argv[1:3]
with open(summary_path, newline='', encoding='utf-8') as handle:
    row = next(csv.DictReader(handle))
if row.get('workspace_gap_preflight_ready') != '1':
    print('filled-form materialized, but workspace_gap_preflight_ready=0', file=sys.stderr)
    print(f"open_gap_rows={row.get('open_gap_rows', 'unknown')}", file=sys.stderr)
    try:
        with open(missing_path, newline='', encoding='utf-8') as handle:
            for item in csv.DictReader(handle):
                if item.get('status') != 'no-gap-detected':
                    print(f"{item.get('item_id')}: {item.get('status')} -> {item.get('path_or_env')}", file=sys.stderr)
    except FileNotFoundError:
        pass
    raise SystemExit(2)
print('workspace_gap_preflight_ready=1 after filled-form materialization')
PY_CHECK
if [[ "${V61HF_EXECUTE_GUARDED_REPLAY:-0}" != "1" ]]; then
  echo "guarded replay not executed; set V61HF_EXECUTE_GUARDED_REPLAY=1 to call RUN_GAP_READY_FIRST_REAL_SLICE.sh" >&2
  exit 3
fi
exec "$WORK_ROOT/RUN_GAP_READY_FIRST_REAL_SLICE.sh"
""" % {"root": repr(str(root))}

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
materializer_exists = int(form_dir is not None and (form_dir / "MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py").is_file())
precheck_runner_exists = int(work_root is not None and (work_root / "RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh").is_file())
guarded_runner_exists = int(work_root is not None and (work_root / "RUN_GAP_READY_FIRST_REAL_SLICE.sh").is_file())
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo and materializer_exists and precheck_runner_exists and guarded_runner_exists)
published = 0
publish_errors = []
published_rows = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not materializer_exists:
        publish_errors.append("form-materializer-missing")
    if not precheck_runner_exists:
        publish_errors.append("precheck-runner-missing")
    if not guarded_runner_exists:
        publish_errors.append("guarded-runner-missing")
elif publish_admitted:
    handoff_path = work_root / "RUN_FILLED_FORM_TO_GUARDED_FIRST_REAL_SLICE.sh"
    readme_path = form_dir / "FILLED_FORM_HANDOFF_README.md"
    handoff_path.write_text(handoff_text, encoding="utf-8")
    handoff_path.chmod(0o755)
    readme_path.write_text(
        "\n".join([
            "# Filled Form To Guarded First Real Slice",
            "",
            "This handoff consumes a filled external return form, runs the form materializer, reruns the precheck and gap audit, and then stops unless `V61HF_EXECUTE_GUARDED_REPLAY=1` is set.",
            "It does not bypass the existing `RUN_GAP_READY_FIRST_REAL_SLICE.sh` guard.",
            "",
        ]),
        encoding="utf-8",
    )
    published = 1
    for path in [handoff_path, readme_path]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "executes_dual_replay_by_default": "0",
        })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_dual_replay_by_default": "0"})
write_csv(run_dir / "first_real_slice_filled_form_handoff_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-v61he-source", "status": "ready", "evidence": "v61he ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-form-materializer", "status": "ready" if materializer_exists else "blocked", "evidence": f"materializer_exists={materializer_exists}"},
    {"stage_id": "04-precheck-runner", "status": "ready" if precheck_runner_exists else "blocked", "evidence": f"precheck_runner_exists={precheck_runner_exists}"},
    {"stage_id": "05-guarded-runner", "status": "ready" if guarded_runner_exists else "blocked", "evidence": f"guarded_runner_exists={guarded_runner_exists}"},
    {"stage_id": "06-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "07-handoff-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "08-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', 'unknown')}"},
    {"stage_id": "09-final-replay", "status": "blocked", "evidence": "handoff requires V61HF_EXECUTE_GUARDED_REPLAY=1"},
]
write_csv(run_dir / "first_real_slice_filled_form_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-run-filled-form-handoff-no-replay", "ready_to_run_now": str(published), "command": "RUN_FILLED_FORM_TO_GUARDED_FIRST_REAL_SLICE.sh", "purpose": "materialize and verify a filled form, then stop before replay"},
    {"command_id": "02-run-filled-form-handoff-with-guarded-replay", "ready_to_run_now": "0", "command": "V61HF_EXECUTE_GUARDED_REPLAY=1 RUN_FILLED_FORM_TO_GUARDED_FIRST_REAL_SLICE.sh", "purpose": "call the existing guarded final runner only after real form readiness"},
]
write_csv(run_dir / "first_real_slice_filled_form_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_filled_form_handoff_published_rows.csv"),
    ("FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_STAGE_ROWS.csv", run_dir / "first_real_slice_filled_form_handoff_stage_rows.csv"),
    ("FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_COMMAND_ROWS.csv", run_dir / "first_real_slice_filled_form_handoff_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_PUBLISHED_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_COMMAND_ROWS.csv\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_PUBLISHER.sh").chmod(0o755)

summary = {
    "v61hf_post_he_first_real_slice_filled_form_handoff_publisher_ready": 1,
    "v61he_post_hd_first_real_slice_form_materializer_publisher_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "form_materializer_exists": materializer_exists,
    "precheck_runner_exists": precheck_runner_exists,
    "guarded_runner_exists": guarded_runner_exists,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "filled_form_handoff_published": published,
    "open_gap_rows": int(gv.get("open_gap_rows", "0") or "0"),
    "workspace_gap_preflight_ready": int(gv.get("workspace_gap_preflight_ready", "0") or "0"),
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
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hf": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows),
    "published_file_rows": 0 if not published else len(published_rows),
    "payload_like_package_file_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61he-ready", "status": "pass", "evidence": "v61he ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "form-materializer", "status": "pass" if materializer_exists else "blocked", "evidence": f"materializer_exists={materializer_exists}"},
    {"gate": "precheck-runner", "status": "pass" if precheck_runner_exists else "blocked", "evidence": f"precheck_runner_exists={precheck_runner_exists}"},
    {"gate": "guarded-runner", "status": "pass" if guarded_runner_exists else "blocked", "evidence": f"guarded_runner_exists={guarded_runner_exists}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "filled-form-handoff-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "handoff requires explicit replay env and real filled form"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "work_root": str(work_root) if work_root else "",
    "executes_dual_replay_by_default": 0,
    "requires_explicit_replay_env": "V61HF_EXECUTE_GUARDED_REPLAY=1",
    "accepted_as_real_evidence": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HF_POST_HE_FIRST_REAL_SLICE_FILLED_FORM_HANDOFF_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HF Post-HE First Real Slice Filled Form Handoff Publisher",
        "",
        "- v61hf_post_he_first_real_slice_filled_form_handoff_publisher_ready=1",
        f"- filled_form_handoff_published={published}",
        f"- open_gap_rows={summary['open_gap_rows']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "Blocked wording: this publishes a handoff. It does not execute guarded replay unless explicitly requested with a filled form.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path), "metadata_only": "1", "payload_like": "0"})
write_csv(run_dir / "first_real_slice_filled_form_handoff_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hf_post_he_first_real_slice_filled_form_handoff_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
