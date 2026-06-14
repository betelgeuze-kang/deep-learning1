#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fv_post_fu_dual_return_replay_entrypoint"
RUN_ID="${V61FV_RUN_ID:-entrypoint_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fv_post_fu_dual_return_replay_entrypoint_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fu_post_ft_external_return_closure_frontier.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
prefix = "v61fv_post_fu_dual_return_replay_entrypoint"
entrypoint_dir = run_dir / "dual_return_replay_entrypoint"
entrypoint_dir.mkdir(parents=True, exist_ok=True)


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v61fu_summary": results / "v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "v61fu_decision": results / "v61fu_post_ft_external_return_closure_frontier_decision.csv",
    "v61fu_requirements": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier_requirement_rows.csv",
    "v61fu_deltas": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier_delta_rows.csv",
    "v61fu_actions": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier_action_rows.csv",
    "v61fu_manifest": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier" / "EXTERNAL_RETURN_CLOSURE_FRONTIER_MANIFEST.json",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fv source {label}: {path}")
    copy(path, f"source_v61fu/{path.name}")

v61fu = read_csv(source_paths["v61fu_summary"])[0]
if v61fu.get("v61fu_post_ft_external_return_closure_frontier_ready") != "1":
    raise SystemExit("v61fv requires v61fu frontier ready")

required_env_rows = [
    {"env_var": "V61FV_V53_RETURN_BUNDLE_DIR", "required_value": "existing directory", "present_by_default": "0", "purpose": "81-artifact v53 external return root"},
    {"env_var": "V61FV_V53_RETURN_PROVENANCE", "required_value": "real-external-return-bundle", "present_by_default": "0", "purpose": "reject fixture/candidate v53 returns"},
    {"env_var": "V61FV_V61_RETURN_BUNDLE_DIR", "required_value": "existing directory", "present_by_default": "0", "purpose": "10-file v61 generation-intake return root"},
    {"env_var": "V61FV_V61_RETURN_PROVENANCE", "required_value": "real-generation-intake-return-bundle", "present_by_default": "0", "purpose": "reject fixture/candidate v61 returns"},
]
write_csv(run_dir / "dual_return_replay_required_env_rows.csv", list(required_env_rows[0].keys()), required_env_rows)

stage_rows = [
    {"stage_id": "01-v61fu-frontier-ready", "status": "ready", "evidence": "v61fu_post_ft_external_return_closure_frontier_ready=1", "blocking_reason": ""},
    {"stage_id": "02-v53-return-root-env", "status": "blocked", "evidence": "V61FV_V53_RETURN_BUNDLE_DIR unset by default", "blocking_reason": "real v53 return root required"},
    {"stage_id": "03-v53-return-provenance", "status": "blocked", "evidence": "V61FV_V53_RETURN_PROVENANCE unset by default", "blocking_reason": "must equal real-external-return-bundle"},
    {"stage_id": "04-v61-return-root-env", "status": "blocked", "evidence": "V61FV_V61_RETURN_BUNDLE_DIR unset by default", "blocking_reason": "real v61 generation-intake return root required"},
    {"stage_id": "05-v61-return-provenance", "status": "blocked", "evidence": "V61FV_V61_RETURN_PROVENANCE unset by default", "blocking_reason": "must equal real-generation-intake-return-bundle"},
    {"stage_id": "06-dual-real-preflight", "status": "blocked", "evidence": "V61FB dual preflight not run", "blocking_reason": "requires both real roots"},
    {"stage_id": "07-v53-return-acceptance-replay", "status": "blocked", "evidence": "V53AM replay not run", "blocking_reason": "requires v53 real return root"},
    {"stage_id": "08-v61-generation-return-replay", "status": "blocked", "evidence": "V61EV replay not run", "blocking_reason": "requires v61 real generation-intake return root"},
    {"stage_id": "09-closure-refresh", "status": "blocked", "evidence": "v61ex/v61ey/v61ez/v61fd/v61fu refresh not run", "blocking_reason": "requires accepted upstream real return evidence"},
    {"stage_id": "10-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "dual_return_replay_entrypoint_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-entrypoint", "ready_to_run_now": "1", "command": "results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh", "purpose": "verify metadata-only entrypoint"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/READY_NOW_COMMANDS.sh", "purpose": "print guarded command"},
    {"command_id": "03-run-dual-return-replay", "ready_to_run_now": "0", "command": "V61FV_V53_RETURN_BUNDLE_DIR=<v53-return-root> V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle V61FV_V61_RETURN_BUNDLE_DIR=<v61-return-root> V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/RUN_DUAL_RETURN_REPLAY_IF_READY.sh", "purpose": "run fail-closed real return replay"},
]
write_csv(run_dir / "dual_return_replay_entrypoint_command_rows.csv", list(command_rows[0].keys()), command_rows)

env_template = entrypoint_dir / "DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh"
env_template.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "export V61FV_V53_RETURN_BUNDLE_DIR=/path/to/v53_external_return_root",
        "export V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle",
        "export V61FV_V61_RETURN_BUNDLE_DIR=/path/to/v61_generation_intake_return_root",
        "export V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle",
        "",
    ]),
    encoding="utf-8",
)
env_template.chmod(0o755)

run_script = entrypoint_dir / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh"
run_script.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "ROOT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/../../..\" && pwd)\"",
        ": \"${V61FV_V53_RETURN_BUNDLE_DIR:?set V61FV_V53_RETURN_BUNDLE_DIR to the real v53 external return root}\"",
        ": \"${V61FV_V53_RETURN_PROVENANCE:?set V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle}\"",
        ": \"${V61FV_V61_RETURN_BUNDLE_DIR:?set V61FV_V61_RETURN_BUNDLE_DIR to the real v61 generation-intake return root}\"",
        ": \"${V61FV_V61_RETURN_PROVENANCE:?set V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle}\"",
        "if [[ ! -d \"$V61FV_V53_RETURN_BUNDLE_DIR\" ]]; then",
        "  echo \"missing v53 return root: $V61FV_V53_RETURN_BUNDLE_DIR\" >&2",
        "  exit 2",
        "fi",
        "if [[ ! -d \"$V61FV_V61_RETURN_BUNDLE_DIR\" ]]; then",
        "  echo \"missing v61 return root: $V61FV_V61_RETURN_BUNDLE_DIR\" >&2",
        "  exit 2",
        "fi",
        "if [[ \"$V61FV_V53_RETURN_PROVENANCE\" != \"real-external-return-bundle\" ]]; then",
        "  echo \"rejecting v53 return provenance: $V61FV_V53_RETURN_PROVENANCE\" >&2",
        "  exit 3",
        "fi",
        "if [[ \"$V61FV_V61_RETURN_PROVENANCE\" != \"real-generation-intake-return-bundle\" ]]; then",
        "  echo \"rejecting v61 return provenance: $V61FV_V61_RETURN_PROVENANCE\" >&2",
        "  exit 3",
        "fi",
        "V61FB_V53_RETURN_BUNDLE_DIR=\"$V61FV_V53_RETURN_BUNDLE_DIR\" \\",
        "V61FB_V53_RETURN_PROVENANCE=\"$V61FV_V53_RETURN_PROVENANCE\" \\",
        "V61FB_V61_RETURN_BUNDLE_DIR=\"$V61FV_V61_RETURN_BUNDLE_DIR\" \\",
        "V61FB_V61_RETURN_PROVENANCE=\"$V61FV_V61_RETURN_PROVENANCE\" \\",
        "V61FB_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh\"",
        "V53AM_RETURN_BUNDLE_DIR=\"$V61FV_V53_RETURN_BUNDLE_DIR\" V53AM_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh\"",
        "V61EV_RETURN_BUNDLE_DIR=\"$V61FV_V61_RETURN_BUNDLE_DIR\" \\",
        "V61EV_RETURN_BUNDLE_PROVENANCE=\"$V61FV_V61_RETURN_PROVENANCE\" \\",
        "V61EV_RECEIPT_PROVENANCE=\"$V61FV_V61_RETURN_PROVENANCE\" \\",
        "V61EV_BINDING_PROVENANCE=\"real-external-return-bundle\" \\",
        "V61EV_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61ev_return_bundle_downstream_replay_gate.sh\"",
        "V61EX_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61ex_generation_acceptance_closure_work_order.sh\"",
        "V61EY_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61ey_generation_acceptance_closure_handoff_bundle.sh\"",
        "V61EZ_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61ez_active_goal_post_ey_status_refresh.sh\"",
        "V61FD_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh\"",
        "V61FU_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61fu_post_ft_external_return_closure_frontier.sh\"",
        "",
    ]),
    encoding="utf-8",
)
run_script.chmod(0o755)

(entrypoint_dir / "VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -x \"$DIR/RUN_DUAL_RETURN_REPLAY_IF_READY.sh\"",
        "test -x \"$DIR/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh\"",
        "test -s \"$DIR/DUAL_RETURN_REPLAY_ENTRYPOINT_MANIFEST.json\"",
        "test -s \"$DIR/DUAL_RETURN_REPLAY_STAGE_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_REPLAY_COMMAND_ROWS.csv\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in entrypoint package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(entrypoint_dir / "VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh").chmod(0o755)

(entrypoint_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61fv ready-now commands are entrypoint verification only; real replay requires both real return roots and exact provenance.'",
        "echo 'results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh'",
        "echo 'source results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh'",
        "echo 'results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/RUN_DUAL_RETURN_REPLAY_IF_READY.sh'",
        "",
    ]),
    encoding="utf-8",
)
(entrypoint_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

shutil.copy2(run_dir / "dual_return_replay_entrypoint_stage_rows.csv", entrypoint_dir / "DUAL_RETURN_REPLAY_STAGE_ROWS.csv")
shutil.copy2(run_dir / "dual_return_replay_entrypoint_command_rows.csv", entrypoint_dir / "DUAL_RETURN_REPLAY_COMMAND_ROWS.csv")
shutil.copy2(run_dir / "dual_return_replay_required_env_rows.csv", entrypoint_dir / "DUAL_RETURN_REPLAY_REQUIRED_ENV_ROWS.csv")

entrypoint_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "entrypoint_admitted_by_default": 0,
    "required_env_rows": len(required_env_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(entrypoint_dir / "DUAL_RETURN_REPLAY_ENTRYPOINT_MANIFEST.json").write_text(json.dumps(entrypoint_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(entrypoint_dir / "DUAL_RETURN_REPLAY_ENTRYPOINT.md").write_text(
    "\n".join([
        "# v61fv dual return replay entrypoint",
        "",
        "- entrypoint_admitted_by_default=0",
        f"- required_env_rows={len(required_env_rows)}",
        f"- stage_rows={len(stage_rows)}",
        f"- ready_stage_rows={entrypoint_manifest['ready_stage_rows']}",
        f"- blocked_stage_rows={entrypoint_manifest['blocked_stage_rows']}",
        "- actual_model_generation_ready=0",
        "",
        "The script fails closed unless both real return roots and exact real provenance labels are supplied.",
        "",
    ]),
    encoding="utf-8",
)

entrypoint_files = sorted(path for path in entrypoint_dir.rglob("*") if path.is_file())
file_rows = []
for path in entrypoint_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "dual_return_replay_entrypoint_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": 1,
    "v61fu_post_ft_external_return_closure_frontier_ready": 1,
    "entrypoint_admitted_by_default": 0,
    "required_env_rows": len(required_env_rows),
    "present_required_env_rows_by_default": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "frontier_requirement_rows": as_int(v61fu, "frontier_requirement_rows"),
    "blocked_frontier_requirement_rows": as_int(v61fu, "blocked_frontier_requirement_rows"),
    "open_frontier_delta_rows": as_int(v61fu, "open_frontier_delta_rows"),
    "missing_external_return_artifacts": as_int(v61fu, "missing_external_return_artifacts"),
    "dual_external_return_real_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fv": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "entrypoint_file_rows": len(file_rows),
    "metadata_only_entrypoint_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_entrypoint_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": 2,
    "source_artifact_file_rows": 4,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61fu-frontier", "status": "pass", "actual_value": "ready", "required_value": "ready", "reason": "frontier source exists"},
    {"gate": "entrypoint-files", "status": "pass", "actual_value": str(len(file_rows)), "required_value": "metadata files", "reason": "entrypoint package emitted"},
    {"gate": "default-admission", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "no real return roots supplied by default"},
    {"gate": "real-v53-return-root", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "requires V61FV_V53_RETURN_BUNDLE_DIR and real provenance"},
    {"gate": "real-v61-return-root", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "requires V61FV_V61_RETURN_BUNDLE_DIR and real provenance"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only entrypoint"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FV_POST_FU_DUAL_RETURN_REPLAY_ENTRYPOINT_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V61FV Post-FU Dual Return Replay Entrypoint",
        "",
        "- v61fv_post_fu_dual_return_replay_entrypoint_ready=1",
        "- entrypoint_admitted_by_default=0",
        f"- required_env_rows={len(required_env_rows)}",
        f"- stage_rows={len(stage_rows)}",
        f"- ready_stage_rows={summary['ready_stage_rows']}",
        f"- blocked_stage_rows={summary['blocked_stage_rows']}",
        f"- command_rows={summary['command_rows']}",
        f"- ready_command_rows={summary['ready_command_rows']}",
        f"- missing_external_return_artifacts={summary['missing_external_return_artifacts']}",
        "- dual_external_return_real_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: the entrypoint is fail-closed by default. It does not replay acceptance or generation without both real return roots and exact real provenance labels.",
        "",
    ]),
    encoding="utf-8",
)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **summary,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "bytes", "sha256"], sha_rows)

print(f"v61fv_post_fu_dual_return_replay_entrypoint_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
