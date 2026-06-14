#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ha_post_gz_first_real_slice_source_witness_promotion_audit"
RUN_ID="${V61HA_RUN_ID:-promotion_audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HA_WORK_ROOT:-${V61GZ_WORK_ROOT:-${V61GY_WORK_ROOT:-${V61GX_WORK_ROOT:-${V61GW_WORK_ROOT:-${V61GV_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}}}}}"
EXECUTE_PROMOTION="${V61HA_EXECUTE_PROMOTION:-0}"
PUBLISH_CANDIDATE="${V61HA_PUBLISH_CANDIDATE:-$EXECUTE_PROMOTION}"
GZ_RUN_ID="${V61HA_V61GZ_RUN_ID:-${RUN_ID}_source_candidate}"
GV_RUN_ID="${V61HA_V61GV_RUN_ID:-${RUN_ID}_post_promotion_gap_audit}"

if [[ "${V61HA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GZ_RUN_ID="$GZ_RUN_ID" \
V61GZ_WORK_ROOT="$WORK_ROOT" \
V61GZ_PUBLISH_CANDIDATE="$PUBLISH_CANDIDATE" \
V61GZ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gz_post_gy_first_real_slice_source_witness_candidate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GZ_RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$EXECUTE_PROMOTION" "$PUBLISH_CANDIDATE" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
gz_run_id = sys.argv[6]
gv_run_id = sys.argv[7]
work_root_raw = sys.argv[8].strip()
execute_promotion = int((sys.argv[9].strip() or "0") == "1")
publish_candidate = int((sys.argv[10].strip() or "0") == "1")
results = root / "results"
prefix = "v61ha_post_gz_first_real_slice_source_witness_promotion_audit"
package_dir = run_dir / "first_real_slice_source_witness_promotion_audit"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GZ_PREFIX = "v61gz_post_gy_first_real_slice_source_witness_candidate"
GV_PREFIX = "v61gv_post_gu_first_real_slice_workspace_gap_audit"
gz_run_dir = results / GZ_PREFIX / gz_run_id


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


source_paths = {
    "v61gz_summary": results / f"{GZ_PREFIX}_summary.csv",
    "v61gz_decision": results / f"{GZ_PREFIX}_decision.csv",
    "v61gz_candidate_rows": gz_run_dir / "first_real_slice_source_witness_candidate_rows.csv",
    "v61gz_published_rows": gz_run_dir / "first_real_slice_source_witness_published_file_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ha source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gz") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_source_witness_promotion_audit_source_rows.csv", list(source_rows[0].keys()), source_rows)

gz = read_csv(source_paths["v61gz_summary"])[0]
candidate = read_csv(source_paths["v61gz_candidate_rows"])[0]
if gz.get("v61gz_post_gy_first_real_slice_source_witness_candidate_ready") != "1":
    raise SystemExit("v61ha requires v61gz ready")

expected_sha = candidate["expected_source_file_sha256"]
work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
candidate_dir = work_root / "source_witness_candidate" if work_root else None
candidate_helper_exists = int(candidate_dir is not None and (candidate_dir / "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh").is_file())
candidate_verifier_exists = int(candidate_dir is not None and (candidate_dir / "VERIFY_SOURCE_FILE_WITNESS_CANDIDATE.sh").is_file())
final_witness = work_root / "final_content_witness" / "source_file.txt" if work_root else None
final_witness_preexists = int(final_witness is not None and final_witness.exists())
allow_overwrite = int(os.environ.get("V61HA_ALLOW_OVERWRITE_FINAL_SOURCE_WITNESS", "0") == "1")
promotion_admitted = int(execute_promotion and work_root_exists and work_root_outside_repo and candidate_helper_exists and candidate_verifier_exists and (not final_witness_preexists or allow_overwrite))

stdout_path = run_dir / "source_witness_promotion_stdout.txt"
stderr_path = run_dir / "source_witness_promotion_stderr.txt"
stdout_path.write_text("", encoding="utf-8")
stderr_path.write_text("", encoding="utf-8")
promotion_exit_code = ""
promoted_by_v61ha = 0
promotion_error = ""
if execute_promotion and not promotion_admitted:
    reasons = []
    if not work_root_exists:
        reasons.append("missing-work-root")
    if work_root is not None and not work_root_outside_repo:
        reasons.append("work-root-inside-repo")
    if not candidate_helper_exists:
        reasons.append("missing-promotion-helper")
    if not candidate_verifier_exists:
        reasons.append("missing-candidate-verifier")
    if final_witness_preexists and not allow_overwrite:
        reasons.append("final-source-witness-exists")
    promotion_error = ";".join(reasons)
if promotion_admitted:
    env = dict(os.environ)
    env["V61GZ_CONFIRM_SOURCE_WITNESS_PROMOTION"] = "promote-selected-source-file-witness"
    completed = subprocess.run(
        [str(candidate_dir / "PROMOTE_SOURCE_FILE_WITNESS_IF_CONFIRMED.sh")],
        cwd=str(candidate_dir),
        text=True,
        capture_output=True,
        env=env,
    )
    stdout_path.write_text(completed.stdout, encoding="utf-8")
    stderr_path.write_text(completed.stderr, encoding="utf-8")
    promotion_exit_code = str(completed.returncode)
    if completed.returncode != 0:
        raise SystemExit(f"source witness promotion failed: {completed.stderr}")
    if not final_witness.is_file():
        raise SystemExit("source witness promotion did not create final witness")
    if sha256(final_witness) != expected_sha:
        raise SystemExit(f"promoted source witness hash mismatch: {sha256(final_witness)} != {expected_sha}")
    promoted_by_v61ha = 1

if work_root:
    env = dict(os.environ)
    env.update({
        "V61GV_RUN_ID": gv_run_id,
        "V61GV_WORK_ROOT": str(work_root),
        "V61GV_REUSE_EXISTING": "0",
    })
    subprocess.run(
        [str(root / "experiments" / "run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh")],
        cwd=str(root),
        text=True,
        stdout=subprocess.DEVNULL,
        check=True,
        env=env,
    )
else:
    env = dict(os.environ)
    env.update({"V61GV_RUN_ID": gv_run_id, "V61GV_REUSE_EXISTING": "0"})
    subprocess.run(
        [str(root / "experiments" / "run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh")],
        cwd=str(root),
        text=True,
        stdout=subprocess.DEVNULL,
        check=True,
        env=env,
    )

gv_run_dir = results / GV_PREFIX / gv_run_id
gv_source_paths = {
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_decision": results / f"{GV_PREFIX}_decision.csv",
    "v61gv_witness_rows": gv_run_dir / "first_real_slice_workspace_witness_rows.csv",
    "v61gv_missing_rows": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
}
for label, path in gv_source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing post-promotion audit source {label}: {path}")
gv_source_rows = [copy_source(label, path, "source_v61gv_post_promotion") for label, path in gv_source_paths.items()]
write_csv(run_dir / "first_real_slice_source_witness_promotion_audit_post_gv_source_rows.csv", list(gv_source_rows[0].keys()), gv_source_rows)

gv = read_csv(gv_source_paths["v61gv_summary"])[0]
witness_rows = read_csv(gv_source_paths["v61gv_witness_rows"])
missing_rows = read_csv(gv_source_paths["v61gv_missing_rows"])
gap_counts = Counter(row.get("item_family", "") for row in missing_rows if row.get("status") != "no-gap-detected")
source_witness_rows = [row for row in witness_rows if row.get("witness_file") == "source_file.txt"]
if len(source_witness_rows) != 1:
    raise SystemExit("expected one source_file.txt witness row in post-promotion audit")
source_witness = source_witness_rows[0]
source_witness_ready_after_audit = int(source_witness.get("ready_for_preflight") == "1")
source_witness_sha_matches_after_audit = int(source_witness.get("sha256") == expected_sha)

audit_rows = [{
    "promotion_requested": str(execute_promotion),
    "promotion_admitted": str(promotion_admitted),
    "promotion_exit_code": promotion_exit_code,
    "promotion_error": promotion_error,
    "promoted_by_v61ha": str(promoted_by_v61ha),
    "final_witness_preexists": str(final_witness_preexists),
    "source_witness_ready_after_audit": str(source_witness_ready_after_audit),
    "source_witness_sha_matches_after_audit": str(source_witness_sha_matches_after_audit),
    "ready_witness_rows_after_audit": gv.get("ready_witness_rows", "0"),
    "open_gap_rows_after_audit": gv.get("open_gap_rows", "0"),
    "content_witness_gap_rows_after_audit": str(gap_counts.get("content-witness", 0)),
    "env_value_gap_rows_after_audit": str(gap_counts.get("env-value", 0)),
    "workspace_gap_preflight_ready_after_audit": gv.get("workspace_gap_preflight_ready", "0"),
    "accepted_as_real_evidence": "0",
}]
write_csv(run_dir / "first_real_slice_source_witness_promotion_audit_rows.csv", list(audit_rows[0].keys()), audit_rows)

stage_rows = [
    {"stage_id": "01-v61gz-source", "status": "ready", "evidence": "v61gz source candidate ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-source-candidate-helper", "status": "ready" if candidate_helper_exists and candidate_verifier_exists else "blocked", "evidence": f"helper={candidate_helper_exists}; verifier={candidate_verifier_exists}"},
    {"stage_id": "04-promotion-request", "status": "ready" if execute_promotion else "blocked", "evidence": f"execute_promotion={execute_promotion}"},
    {"stage_id": "05-promotion-admitted", "status": "ready" if promotion_admitted else "blocked", "evidence": f"promotion_admitted={promotion_admitted}; error={promotion_error}"},
    {"stage_id": "06-source-witness-ready", "status": "ready" if source_witness_ready_after_audit and source_witness_sha_matches_after_audit else "blocked", "evidence": f"ready={source_witness_ready_after_audit}; sha_match={source_witness_sha_matches_after_audit}"},
    {"stage_id": "07-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', '0')}"},
    {"stage_id": "08-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_source_witness_promotion_audit_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-promotion-audit-package", "ready_to_run_now": "1", "command": "results/v61ha_post_gz_first_real_slice_source_witness_promotion_audit/promotion_audit_001/first_real_slice_source_witness_promotion_audit/VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT.sh", "purpose": "verify this metadata package"},
    {"command_id": "02-print-promotion-audit-summary", "ready_to_run_now": "1", "command": "results/v61ha_post_gz_first_real_slice_source_witness_promotion_audit/promotion_audit_001/first_real_slice_source_witness_promotion_audit/PRINT_SOURCE_WITNESS_PROMOTION_AUDIT_SUMMARY.sh", "purpose": "print source witness promotion audit rows"},
    {"command_id": "03-run-gap-ready-first-real-slice", "ready_to_run_now": str(int(gv.get("workspace_gap_preflight_ready") == "1")), "command": "<work-root>/RUN_GAP_READY_FIRST_REAL_SLICE.sh", "purpose": "still blocked until every witness/env gap closes"},
]
write_csv(run_dir / "first_real_slice_source_witness_promotion_audit_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_ROWS.csv", run_dir / "first_real_slice_source_witness_promotion_audit_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_STAGE_ROWS.csv", run_dir / "first_real_slice_source_witness_promotion_audit_stage_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_COMMAND_ROWS.csv", run_dir / "first_real_slice_source_witness_promotion_audit_command_rows.csv"),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_STDOUT.txt", stdout_path),
    ("FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_STDERR.txt", stderr_path),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_STAGE_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61ha package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT.sh").chmod(0o755)

(package_dir / "PRINT_SOURCE_WITNESS_PROMOTION_AUDIT_SUMMARY.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "cat \"$DIR/FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_ROWS.csv\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "PRINT_SOURCE_WITNESS_PROMOTION_AUDIT_SUMMARY.sh").chmod(0o755)

summary = {
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_ready": 1,
    "v61gz_post_gy_first_real_slice_source_witness_candidate_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "source_candidate_hash_matches": int(gz.get("source_candidate_hash_matches", "0") == "1"),
    "source_candidate_published": int(gz.get("source_candidate_published", "0") == "1"),
    "promotion_requested": execute_promotion,
    "promotion_admitted": promotion_admitted,
    "promoted_by_v61ha": promoted_by_v61ha,
    "source_witness_ready_after_audit": source_witness_ready_after_audit,
    "source_witness_sha_matches_after_audit": source_witness_sha_matches_after_audit,
    "ready_witness_rows_after_audit": int(gv.get("ready_witness_rows", "0") or "0"),
    "open_gap_rows_after_audit": int(gv.get("open_gap_rows", "0") or "0"),
    "content_witness_gap_rows_after_audit": gap_counts.get("content-witness", 0),
    "env_value_gap_rows_after_audit": gap_counts.get("env-value", 0),
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
    "checkpoint_payload_bytes_downloaded_by_v61ha": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows) + len(gv_source_rows),
    "payload_like_package_file_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "promotion_audit": audit_rows[0],
    "work_root": str(work_root) if work_root else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

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
write_csv(run_dir / "first_real_slice_source_witness_promotion_audit_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gz-ready", "status": "pass", "evidence": "v61gz ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "source-candidate-helper", "status": "pass" if candidate_helper_exists and candidate_verifier_exists else "blocked", "evidence": f"helper={candidate_helper_exists}; verifier={candidate_verifier_exists}"},
    {"gate": "promotion-request", "status": "pass" if execute_promotion else "blocked", "evidence": f"execute_promotion={execute_promotion}"},
    {"gate": "promotion-admitted", "status": "pass" if promotion_admitted else "blocked", "evidence": f"promotion_admitted={promotion_admitted}; error={promotion_error}"},
    {"gate": "source-witness-ready", "status": "pass" if source_witness_ready_after_audit and source_witness_sha_matches_after_audit else "blocked", "evidence": f"ready={source_witness_ready_after_audit}; sha_match={source_witness_sha_matches_after_audit}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "source witness promotion alone is not review/generation evidence"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61HA_POST_GZ_FIRST_REAL_SLICE_SOURCE_WITNESS_PROMOTION_AUDIT_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HA Post-GZ First Real Slice Source Witness Promotion Audit",
        "",
        "- v61ha_post_gz_first_real_slice_source_witness_promotion_audit_ready=1",
        f"- promoted_by_v61ha={promoted_by_v61ha}",
        f"- source_witness_ready_after_audit={source_witness_ready_after_audit}",
        f"- ready_witness_rows_after_audit={summary['ready_witness_rows_after_audit']}",
        f"- open_gap_rows_after_audit={summary['open_gap_rows_after_audit']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: source witness promotion can close only the mechanical source-file witness gap. It does not create human review, adjudication, generation, row-acceptance, replay, latency, quality, or release evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61ha": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61ha_post_gz_first_real_slice_source_witness_promotion_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
