#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ga_post_fz_generation_unblock_runway"
RUN_ID="${V61GA_RUN_ID:-runway_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ga_post_fz_generation_unblock_runway_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fz_post_fy_active_goal_status_refresh.sh" >/dev/null
V53AO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ao_complete_source_actual_review_return_frontier_receipt.sh" >/dev/null
V61FU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fu_post_ft_external_return_closure_frontier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
results = root / "results"
prefix = "v61ga_post_fz_generation_unblock_runway"
package_dir = run_dir / "generation_unblock_runway"
package_dir.mkdir(parents=True, exist_ok=True)


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


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
    "v61fz_summary": results / "v61fz_post_fy_active_goal_status_refresh_summary.csv",
    "v61fz_requirements": results / "v61fz_post_fy_active_goal_status_refresh" / "refresh_001" / "post_fy_status_requirement_rows.csv",
    "v61fz_blockers": results / "v61fz_post_fy_active_goal_status_refresh" / "refresh_001" / "post_fy_status_blocker_rows.csv",
    "v61fz_next_actions": results / "v61fz_post_fy_active_goal_status_refresh" / "refresh_001" / "post_fy_status_next_action_rows.csv",
    "v61fu_summary": results / "v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "v61fu_deltas": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier_delta_rows.csv",
    "v53ao_summary": results / "v53ao_complete_source_actual_review_return_frontier_receipt_summary.csv",
    "v53ao_execution": results / "v53ao_complete_source_actual_review_return_frontier_receipt" / "receipt_001" / "actual_review_return_frontier_receipt_execution_rows.csv",
    "v53ao_stages": results / "v53ao_complete_source_actual_review_return_frontier_receipt" / "receipt_001" / "actual_review_return_frontier_receipt_stage_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ga source {source_id}: {path}")

source_rows = []
for source_id, path in source_paths.items():
    if source_id.startswith("v61fz"):
        folder = "source_v61fz"
    elif source_id.startswith("v61fu"):
        folder = "source_v61fu"
    else:
        folder = "source_v53ao"
    source_rows.append(copy_source(source_id, path, folder))
write_csv(run_dir / "generation_unblock_runway_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61fz = read_csv(source_paths["v61fz_summary"])[0]
v61fu = read_csv(source_paths["v61fu_summary"])[0]
v53ao = read_csv(source_paths["v53ao_summary"])[0]
delta_rows = read_csv(source_paths["v61fu_deltas"])

if v61fz.get("v61fz_post_fy_active_goal_status_refresh_ready") != "1":
    raise SystemExit("v61ga requires v61fz_post_fy_active_goal_status_refresh_ready=1")
if v53ao.get("v53ao_complete_source_actual_review_return_frontier_receipt_ready") != "1":
    raise SystemExit("v61ga requires v53ao_complete_source_actual_review_return_frontier_receipt_ready=1")
if v61fu.get("active_goal_complete") != "0":
    raise SystemExit("v61ga expects active goal to remain incomplete before real returns")

requirement_specs = [
    ("01-v52-f-optional-final-disposition", "v52", 1, "F optional final disposition exists", ""),
    ("02-v53-complete-source-machine-surface", "v53", as_int(v61fz, "v53_machine_complete_source_surface_ready"), f"repos={v61fz['complete_source_repo_count']}; queries={v61fz['complete_source_query_rows']}; answers={v61fz['core_answer_rows']}", ""),
    ("03-v61-full-shard-runtime-evidence", "v61", as_int(v61fz, "post_full_shard_runtime_evidence_ready"), f"full_checkpoint={v61fz['full_checkpoint_materialization_ready']}; page_hash={v61fz['full_safetensors_page_hash_binding_ready']}; runtime_admission={v61fz['runtime_admission_accepted_rows']}", ""),
    ("04-v61-root-pinned-replay-script", "v61", as_int(v61fz, "root_pinned_replay_script_ready"), "root_pinned_replay_script_ready=1", ""),
    ("05-v53ao-frontier-receipt", "v53", as_int(v53ao, "v53ao_complete_source_actual_review_return_frontier_receipt_ready"), f"ready_actions={v53ao['successful_ready_frontier_action_rows']}/{v53ao['ready_frontier_action_rows']}; blocked_actions={v53ao['blocked_frontier_action_rows']}", ""),
    ("06-v53-return-artifact-presence", "v53-return", 0, f"preflight_pass_rows={v53ao['preflight_pass_rows']}/{v53ao['preflight_rows']}; missing_checklist_rows={v53ao['missing_checklist_rows']}", "supply all 81 final return artifacts"),
    ("07-v53-human-review-rows", "v53-return", 0, f"accepted_human_review_rows={v53ao['answer_review_accepted_rows']}/{v53ao['expected_human_review_rows']}", "return 7000 accepted human/source review rows"),
    ("08-v53-adjudication-rows", "v53-return", 0, f"accepted_adjudication_rows={v53ao['accepted_adjudication_rows']}/{v53ao['expected_adjudication_rows']}", "return 1000 accepted adjudication rows"),
    ("09-v53-reviewer-identity-conflict", "v53-return", 0, f"missing_reviewer_identity_rows={v61fu['missing_reviewer_identity_rows']}; missing_conflict_disclosure_rows={v61fu['missing_conflict_disclosure_rows']}", "return reviewer identity/conflict rows"),
    ("10-v61-generation-intake-root", "v61-return", 0, "v61 generation-intake return root absent", "supply real 10-file v61 return root"),
    ("11-v61-generation-result-artifacts", "v61-return", 0, f"missing_generation_result_artifacts={v61fz['missing_generation_result_artifacts']}", "return five generation-result artifacts"),
    ("12-v61-generation-result-rows", "v61-return", 0, f"missing_generation_result_rows={v61fz['missing_generation_result_rows']}", "return 1000 accepted source-bound generation rows"),
    ("13-dual-real-return-provenance", "dual-return", 0, "dual_external_return_real_ready=0", "supply both roots with exact real provenance labels"),
    ("14-dual-return-replay-execution", "dual-return", 0, "real replay command remains unexecuted", "run root-pinned replay after both real roots exist"),
    ("15-generation-acceptance-closure", "v61-return", 0, "generation_acceptance_closure_ready=0", "close v61bt/v61de/v61cu acceptance"),
    ("16-actual-model-generation", "v61", 0, "actual_model_generation_ready=0", "requires accepted review and generation returns"),
    ("17-v1-comparison-readiness", "v1.0", 0, "v1_0_comparison_ready=0", "requires real review/adjudication and generation evidence"),
    ("18-latency-quality-release", "release", 0, "near_frontier=0; production_latency=0; release=0", "requires actual generation plus external review"),
]
requirement_rows = []
for req_id, section, ready, evidence, remaining in requirement_specs:
    requirement_rows.append({
        "requirement_id": req_id,
        "section": section,
        "status": "ready" if ready else "blocked",
        "ready": str(int(bool(ready))),
        "evidence": evidence,
        "remaining_work": remaining,
    })
write_csv(run_dir / "generation_unblock_runway_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

blocker_rows = [
    {
        "blocker_id": row["requirement_id"],
        "section": row["section"],
        "evidence": row["evidence"],
        "remaining_work": row["remaining_work"],
    }
    for row in requirement_rows
    if row["status"] == "blocked"
]
write_csv(run_dir / "generation_unblock_runway_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

batch_rows = [
    {
        "batch_id": "01-v53-final-return-artifacts",
        "root": "v53-return-root",
        "artifact_rows_required": "81",
        "payload_rows_required": "0",
        "accepted_artifact_rows": "0",
        "accepted_payload_rows": "0",
        "status": "blocked",
        "source_delta_ids": "01,07",
        "unblocks": "v53al preflight and v53am replay input",
    },
    {
        "batch_id": "02-v53-review-row-payloads",
        "root": "v53-return-root",
        "artifact_rows_required": "0",
        "payload_rows_required": "8231",
        "accepted_artifact_rows": "0",
        "accepted_payload_rows": "0",
        "status": "blocked",
        "source_delta_ids": "03,04,05,06",
        "unblocks": "v53s/v53y accepted review return",
    },
    {
        "batch_id": "03-v61-generation-intake-root",
        "root": "v61-return-root",
        "artifact_rows_required": "10",
        "payload_rows_required": "0",
        "accepted_artifact_rows": "0",
        "accepted_payload_rows": "0",
        "status": "blocked",
        "source_delta_ids": "02,08,09",
        "unblocks": "v61 generation-intake preflight",
    },
    {
        "batch_id": "04-v61-generation-result-rows",
        "root": "v61-return-root",
        "artifact_rows_required": "0",
        "payload_rows_required": "1000",
        "accepted_artifact_rows": "0",
        "accepted_payload_rows": "0",
        "status": "blocked",
        "source_delta_ids": "10",
        "unblocks": "v61bt accepted source-bound generation rows",
    },
    {
        "batch_id": "05-v61-generation-execution-and-final-acceptance",
        "root": "v61-return-root",
        "artifact_rows_required": "0",
        "payload_rows_required": "2000",
        "accepted_artifact_rows": "0",
        "accepted_payload_rows": "0",
        "status": "blocked",
        "source_delta_ids": "11,12",
        "unblocks": "v61de/v61cu generation execution and final acceptance",
    },
    {
        "batch_id": "06-dual-root-provenance-labels",
        "root": "dual-return",
        "artifact_rows_required": "2",
        "payload_rows_required": "0",
        "accepted_artifact_rows": "0",
        "accepted_payload_rows": "0",
        "status": "blocked",
        "source_delta_ids": "13",
        "unblocks": "root-pinned dual return replay admission",
    },
]
write_csv(run_dir / "generation_unblock_runway_minimum_batch_rows.csv", list(batch_rows[0].keys()), batch_rows)

replay_command_rows = [
    {
        "command_id": "01-verify-v53ao-receipt",
        "ready_to_run_now": "1",
        "command": "results/v53ao_complete_source_actual_review_return_frontier_receipt/receipt_001/actual_review_return_frontier_receipt/VERIFY_ACTUAL_REVIEW_RETURN_FRONTIER_RECEIPT.sh",
        "purpose": "verify v53ao receipt mechanics",
    },
    {
        "command_id": "02-verify-v61fz-refresh",
        "ready_to_run_now": "1",
        "command": "results/v61fz_post_fy_active_goal_status_refresh/refresh_001/post_fy_active_goal_status_refresh/VERIFY_POST_FY_STATUS_REFRESH.sh",
        "purpose": "verify current active-goal status refresh",
    },
    {
        "command_id": "03-supply-dual-return-roots",
        "ready_to_run_now": "0",
        "command": "export V61FV_V53_RETURN_BUNDLE_DIR=/path/to/v53_return_root V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle V61FV_V61_RETURN_BUNDLE_DIR=/path/to/v61_return_root V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle",
        "purpose": "requires real v53 and v61 return roots",
    },
    {
        "command_id": "04-run-root-pinned-dual-return-replay",
        "ready_to_run_now": "0",
        "command": "results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
        "purpose": "blocked until command 03 is satisfied",
    },
    {
        "command_id": "05-refresh-v61ga-runway",
        "ready_to_run_now": "0",
        "command": "./experiments/run_v61ga_post_fz_generation_unblock_runway.sh",
        "purpose": "run after real replay changes upstream status",
    },
]
write_csv(run_dir / "generation_unblock_runway_replay_command_rows.csv", list(replay_command_rows[0].keys()), replay_command_rows)

delta_focus_rows = []
for row in delta_rows:
    delta_focus_rows.append({
        "delta_id": row["delta_id"],
        "family": row["family"],
        "unit": row["unit"],
        "required_count": row["required_count"],
        "accepted_or_supplied_count": row["accepted_or_supplied_count"],
        "missing_count": row["missing_count"],
        "status": row["status"],
        "runway_scope": "required-before-actual-generation" if row["status"] == "open" else "closed",
    })
write_csv(run_dir / "generation_unblock_runway_delta_focus_rows.csv", list(delta_focus_rows[0].keys()), delta_focus_rows)

metric_rows = [{
    "v61ga_post_fz_generation_unblock_runway_ready": "1",
    "v61fz_post_fy_active_goal_status_refresh_ready": v61fz["v61fz_post_fy_active_goal_status_refresh_ready"],
    "v53ao_complete_source_actual_review_return_frontier_receipt_ready": v53ao["v53ao_complete_source_actual_review_return_frontier_receipt_ready"],
    "active_goal_complete": "0",
    "v52_ready": v61fz["v52_ready"],
    "v53_machine_complete_source_surface_ready": v61fz["v53_machine_complete_source_surface_ready"],
    "post_full_shard_runtime_evidence_ready": v61fz["post_full_shard_runtime_evidence_ready"],
    "full_checkpoint_materialization_ready": v61fz["full_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61fz["full_safetensors_page_hash_binding_ready"],
    "runtime_admission_accepted_rows": v61fz["runtime_admission_accepted_rows"],
    "root_pinned_replay_script_ready": v61fz["root_pinned_replay_script_ready"],
    "successful_v53ao_ready_action_rows": v53ao["successful_ready_frontier_action_rows"],
    "blocked_v53ao_action_rows": v53ao["blocked_frontier_action_rows"],
    "missing_external_return_artifacts": v61fz["missing_external_return_artifacts"],
    "missing_human_review_rows": v61fz["missing_human_review_rows"],
    "missing_adjudication_rows": v61fz["missing_adjudication_rows"],
    "missing_generation_result_artifacts": v61fz["missing_generation_result_artifacts"],
    "missing_generation_result_rows": v61fz["missing_generation_result_rows"],
    "runway_requirement_rows": str(len(requirement_rows)),
    "ready_runway_requirement_rows": str(sum(row["status"] == "ready" for row in requirement_rows)),
    "blocked_runway_requirement_rows": str(sum(row["status"] == "blocked" for row in requirement_rows)),
    "minimum_batch_rows": str(len(batch_rows)),
    "blocked_minimum_batch_rows": str(sum(row["status"] == "blocked" for row in batch_rows)),
    "replay_command_rows": str(len(replay_command_rows)),
    "ready_replay_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in replay_command_rows)),
    "blocked_replay_command_rows": str(sum(row["ready_to_run_now"] == "0" for row in replay_command_rows)),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ga": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}]
write_csv(run_dir / "generation_unblock_runway_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

for name in [
    "generation_unblock_runway_requirement_rows.csv",
    "generation_unblock_runway_blocker_rows.csv",
    "generation_unblock_runway_minimum_batch_rows.csv",
    "generation_unblock_runway_replay_command_rows.csv",
    "generation_unblock_runway_delta_focus_rows.csv",
    "generation_unblock_runway_metric_rows.csv",
]:
    shutil.copy2(run_dir / name, package_dir / name.upper())

package_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "requirement_rows": len(requirement_rows),
    "ready_requirement_rows": sum(row["status"] == "ready" for row in requirement_rows),
    "blocked_requirement_rows": sum(row["status"] == "blocked" for row in requirement_rows),
    "minimum_batch_rows": len(batch_rows),
    "blocked_minimum_batch_rows": sum(row["status"] == "blocked" for row in batch_rows),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "GENERATION_UNBLOCK_RUNWAY_MANIFEST.json").write_text(json.dumps(package_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "VERIFY_GENERATION_UNBLOCK_RUNWAY.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_MANIFEST.json\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_REQUIREMENT_ROWS.CSV\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_BLOCKER_ROWS.CSV\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_MINIMUM_BATCH_ROWS.CSV\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_REPLAY_COMMAND_ROWS.CSV\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_DELTA_FOCUS_ROWS.CSV\"",
        "test -s \"$DIR/GENERATION_UNBLOCK_RUNWAY_METRIC_ROWS.CSV\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/GENERATION_UNBLOCK_RUNWAY_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in generation unblock runway package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_GENERATION_UNBLOCK_RUNWAY.sh").chmod(0o755)
(package_dir / "GENERATION_UNBLOCK_RUNWAY.md").write_text(
    "\n".join([
        "# v61ga post-fz generation unblock runway",
        "",
        "- v61fz status refresh is ready.",
        "- v53ao actual review-return frontier receipt is ready.",
        "- Full checkpoint materialization, full safetensors page-hash binding, and runtime admission remain ready.",
        f"- missing_external_return_artifacts={v61fz['missing_external_return_artifacts']}",
        f"- missing_human_review_rows={v61fz['missing_human_review_rows']}",
        f"- missing_adjudication_rows={v61fz['missing_adjudication_rows']}",
        f"- missing_generation_result_artifacts={v61fz['missing_generation_result_artifacts']}",
        f"- missing_generation_result_rows={v61fz['missing_generation_result_rows']}",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "This runway is metadata-only. It does not accept templates, fixture provenance, or model checkpoint payloads as real return evidence.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "generation_unblock_runway_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = metric_rows[0].copy()
summary.update({
    "blocker_rows": str(len(blocker_rows)),
    "delta_focus_rows": str(len(delta_focus_rows)),
    "source_file_rows": str(len(source_rows)),
    "runway_package_file_rows": str(len(package_file_rows)),
    "metadata_only_runway_package_file_rows": str(sum(row["metadata_only"] == "1" for row in package_file_rows)),
    "payload_like_runway_package_file_rows": str(sum(row["payload_like"] == "1" for row in package_file_rows)),
})
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61fz-status-refresh", "status": "pass", "evidence": "v61fz_post_fy_active_goal_status_refresh_ready=1"},
    {"gate": "v53ao-frontier-receipt", "status": "pass", "evidence": "v53ao_complete_source_actual_review_return_frontier_receipt_ready=1"},
    {"gate": "real-model-runtime-evidence", "status": "pass", "evidence": "full_checkpoint/page_hash/runtime_admission ready"},
    {"gate": "dual-real-return-roots", "status": "blocked", "evidence": "missing_external_return_artifacts=91"},
    {"gate": "human-review-return", "status": "blocked", "evidence": "accepted_human_review_rows=0/7000"},
    {"gate": "generation-result-return", "status": "blocked", "evidence": "accepted generation-result artifacts/rows are 0"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GA Post-FZ Generation Unblock Runway Boundary",
    "",
    f"- v61ga_post_fz_generation_unblock_runway_ready={summary['v61ga_post_fz_generation_unblock_runway_ready']}",
    f"- v61fz_post_fy_active_goal_status_refresh_ready={summary['v61fz_post_fy_active_goal_status_refresh_ready']}",
    f"- v53ao_complete_source_actual_review_return_frontier_receipt_ready={summary['v53ao_complete_source_actual_review_return_frontier_receipt_ready']}",
    f"- v52_ready={summary['v52_ready']}",
    f"- v53_machine_complete_source_surface_ready={summary['v53_machine_complete_source_surface_ready']}",
    f"- post_full_shard_runtime_evidence_ready={summary['post_full_shard_runtime_evidence_ready']}",
    f"- full_checkpoint_materialization_ready={summary['full_checkpoint_materialization_ready']}",
    f"- full_safetensors_page_hash_binding_ready={summary['full_safetensors_page_hash_binding_ready']}",
    f"- runtime_admission_accepted_rows={summary['runtime_admission_accepted_rows']}",
    f"- root_pinned_replay_script_ready={summary['root_pinned_replay_script_ready']}",
    f"- successful_v53ao_ready_action_rows={summary['successful_v53ao_ready_action_rows']}",
    f"- blocked_v53ao_action_rows={summary['blocked_v53ao_action_rows']}",
    f"- missing_external_return_artifacts={summary['missing_external_return_artifacts']}",
    f"- missing_human_review_rows={summary['missing_human_review_rows']}",
    f"- missing_adjudication_rows={summary['missing_adjudication_rows']}",
    f"- missing_generation_result_artifacts={summary['missing_generation_result_artifacts']}",
    f"- missing_generation_result_rows={summary['missing_generation_result_rows']}",
    f"- runway_requirement_rows={summary['runway_requirement_rows']}",
    f"- ready_runway_requirement_rows={summary['ready_runway_requirement_rows']}",
    f"- blocked_runway_requirement_rows={summary['blocked_runway_requirement_rows']}",
    f"- minimum_batch_rows={summary['minimum_batch_rows']}",
    f"- blocked_minimum_batch_rows={summary['blocked_minimum_batch_rows']}",
    f"- ready_replay_command_rows={summary['ready_replay_command_rows']}",
    f"- blocked_replay_command_rows={summary['blocked_replay_command_rows']}",
    f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
    f"- checkpoint_payload_bytes_committed_to_repo={summary['checkpoint_payload_bytes_committed_to_repo']}",
    "",
    "Blocked wording: this is a generation-unblock runway, not actual model generation, near-frontier quality, production latency, or release evidence.",
    "",
])
(run_dir / "V61GA_POST_FZ_GENERATION_UNBLOCK_RUNWAY_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "package_manifest": package_manifest,
    "source_rows": len(source_rows),
    "checkpoint_payload_bytes_downloaded_by_v61ga": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61ga_post_fz_generation_unblock_runway_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
