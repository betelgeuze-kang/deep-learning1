#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hc_post_hb_first_real_slice_precheck_runner_publisher"
RUN_ID="${V61HC_RUN_ID:-precheck_runner_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HC_WORK_ROOT:-${V61GU_WORK_ROOT:-}}"
PUBLISH_PRECHECK_RUNNER="${V61HC_PUBLISH_PRECHECK_RUNNER:-0}"
GV_RUN_ID="${V61HC_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61HC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hc_post_hb_first_real_slice_precheck_runner_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh" >/dev/null
V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null
V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_PRECHECK_RUNNER" <<'PY'
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
run_id = sys.argv[5]
gv_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61hc_post_hb_first_real_slice_precheck_runner_publisher"
package_dir = run_dir / "first_real_slice_precheck_runner_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HB_PREFIX = "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit"
GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
GV_PREFIX = "v61gv_post_gu_first_real_slice_workspace_gap_audit"
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"
checker_path = gi_scaffold / "CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py"


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
    "v61hb_summary": results / f"{HB_PREFIX}_summary.csv",
    "v61hb_decision": results / f"{HB_PREFIX}_decision.csv",
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_checker": checker_path,
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hc source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61hb"):
        folder = "source_v61hb"
    elif label.startswith("v61gi"):
        folder = "source_v61gi"
    else:
        folder = "source_v61gv"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_precheck_runner_source_rows.csv", list(source_rows[0].keys()), source_rows)

hb = read_csv(source_paths["v61hb_summary"])[0]
gi = read_csv(source_paths["v61gi_summary"])[0]
gv = read_csv(source_paths["v61gv_summary"])[0]
if hb.get("v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_ready") != "1":
    raise SystemExit("v61hc requires v61hb ready")
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61hc requires v61gi ready")
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61hc requires v61gv ready")

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
env_template = work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh" if work_root else None
env_template_exists = int(env_template is not None and env_template.is_file())
checker_exists = int(checker_path.is_file())
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo and env_template_exists and checker_exists)

published = 0
publish_errors = []
published_rows = []
runner_rel = "RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh"
runner_path = work_root / runner_rel if work_root else None
precheck_dir = work_root / "precheck_runner" if work_root else None
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not env_template_exists:
        publish_errors.append("env-template-missing")
    if not checker_exists:
        publish_errors.append("v61gi-checker-missing")
elif publish_admitted:
    precheck_dir.mkdir(parents=True, exist_ok=True)
    runner_text = "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"ROOT_DIR={shlex.quote(str(root))}",
        "WORK_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "REPORT=\"${V61HC_PRECHECK_REPORT_CSV:-$WORK_ROOT/precheck_runner/FIRST_REAL_SLICE_INPUT_PRECHECK_ROWS.csv}\"",
        "mkdir -p \"$(dirname \"$REPORT\")\"",
        "source \"$WORK_ROOT/FIRST_REAL_SLICE_ENV_TEMPLATE.sh\"",
        "export V61GI_MINIMAL_SLICE_PRECHECK_CSV=\"$REPORT\"",
        "\"$ROOT_DIR/results/v61gi_post_gh_authority_bound_operator_input_scaffold/scaffold_001/authority_bound_operator_input_scaffold/CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py\"",
        "echo \"first-real-slice input precheck report: $REPORT\"",
        "",
    ])
    runner_path.write_text(runner_text, encoding="utf-8")
    runner_path.chmod(0o755)
    readme = precheck_dir / "PRECHECK_RUNNER_README.md"
    readme.write_text(
        "\n".join([
            "# First Real Slice Precheck Runner",
            "",
            "This runner sources `FIRST_REAL_SLICE_ENV_TEMPLATE.sh` and executes only the v61gi minimal-slice input precheck.",
            "It does not build the minimal slice CSV, assemble return roots, execute replay, or count any real review/generation evidence.",
            "",
            "Run from the workspace root after editing witness files and env values:",
            "",
            "```bash",
            "./RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh",
            "```",
            "",
            "The CSV report is written to `precheck_runner/FIRST_REAL_SLICE_INPUT_PRECHECK_ROWS.csv` by default.",
            "",
        ]),
        encoding="utf-8",
    )
    manifest = precheck_dir / "PRECHECK_RUNNER_MANIFEST.json"
    manifest.write_text(
        json.dumps(
            {
                "artifact": prefix,
                "generated_at_utc": datetime.now(timezone.utc).isoformat(),
                "runner": runner_rel,
                "precheck_only": 1,
                "executes_minimal_csv_build": 0,
                "executes_dual_replay": 0,
                "accepted_as_real_evidence": 0,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    published = 1
    for path in [runner_path, readme, manifest]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "precheck_only": "1",
        })

if not published_rows:
    published_rows.append({
        "path": "",
        "bytes": "0",
        "sha256": "",
        "metadata_only": "1",
        "precheck_only": "1",
    })
write_csv(run_dir / "first_real_slice_precheck_runner_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-v61hb-source", "status": "ready", "evidence": "v61hb ready"},
    {"stage_id": "02-v61gi-checker", "status": "ready" if checker_exists else "blocked", "evidence": f"checker_exists={checker_exists}"},
    {"stage_id": "03-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "04-env-template", "status": "ready" if env_template_exists else "blocked", "evidence": f"env_template_exists={env_template_exists}"},
    {"stage_id": "05-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "06-precheck-runner-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "07-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', 'unknown')}"},
    {"stage_id": "08-final-replay", "status": "blocked", "evidence": "precheck runner never executes final replay"},
    {"stage_id": "09-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_precheck_runner_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-run-precheck-only", "ready_to_run_now": str(published), "command": "<work-root>/RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh", "purpose": "lint witness/env values without building roots or executing replay"},
    {"command_id": "02-run-gap-guarded-final", "ready_to_run_now": str(int(gv.get("workspace_gap_preflight_ready") == "1")), "command": "<work-root>/RUN_GAP_READY_FIRST_REAL_SLICE.sh", "purpose": "execute only after gap preflight becomes ready"},
]
write_csv(run_dir / "first_real_slice_precheck_runner_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_precheck_runner_published_rows.csv"),
    ("FIRST_REAL_SLICE_PRECHECK_RUNNER_STAGE_ROWS.csv", run_dir / "first_real_slice_precheck_runner_stage_rows.csv"),
    ("FIRST_REAL_SLICE_PRECHECK_RUNNER_COMMAND_ROWS.csv", run_dir / "first_real_slice_precheck_runner_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_PRECHECK_RUNNER_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHED_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_PRECHECK_RUNNER_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_PRECHECK_RUNNER_COMMAND_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61hc package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER.sh").chmod(0o755)

summary = {
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_ready": 1,
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "env_template_exists": env_template_exists,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "precheck_runner_published": published,
    "precheck_runner_executable": int(runner_path is not None and runner_path.is_file() and runner_path.stat().st_mode & 0o111 != 0),
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
    "authority_bound_replay_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hc": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
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
    {"gate": "source-v61hb-ready", "status": "pass", "evidence": "v61hb ready"},
    {"gate": "source-v61gi-ready", "status": "pass", "evidence": "v61gi ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "env-template", "status": "pass" if env_template_exists else "blocked", "evidence": f"env_template_exists={env_template_exists}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "precheck-runner-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "precheck runner never executes final replay"},
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
    "precheck_only": 1,
    "executes_minimal_csv_build": 0,
    "executes_dual_replay": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hc": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_PRECHECK_RUNNER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HC_POST_HB_FIRST_REAL_SLICE_PRECHECK_RUNNER_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HC Post-HB First Real Slice Precheck Runner Publisher",
        "",
        "- v61hc_post_hb_first_real_slice_precheck_runner_publisher_ready=1",
        f"- precheck_runner_published={published}",
        f"- open_gap_rows={summary['open_gap_rows']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this publishes a precheck-only runner. It does not build roots, execute replay, or accept review/generation evidence.",
        "",
    ]),
    encoding="utf-8",
)

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
write_csv(run_dir / "first_real_slice_precheck_runner_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hc_post_hb_first_real_slice_precheck_runner_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
