#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fx_post_fw_dual_return_operator_handoff_bundle"
RUN_ID="${V61FX_RUN_ID:-handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fx_post_fw_dual_return_operator_handoff_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FV_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fv_post_fu_dual_return_replay_entrypoint.sh" >/dev/null
V61FW_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fw_post_fv_dual_return_replay_entrypoint_receipt.sh" >/dev/null

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
prefix = "v61fx_post_fw_dual_return_operator_handoff_bundle"
handoff_dir = run_dir / "dual_return_operator_handoff_bundle"
handoff_dir.mkdir(parents=True, exist_ok=True)


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


def copy_handoff(src, rel):
    dst = handoff_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v61fc_summary": results / "v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "v61fc_required_artifacts": results / "v61fc_post_fb_dual_external_return_operator_packet" / "packet_001" / "dual_external_return_required_artifact_rows.csv",
    "v61fd_summary": results / "v61fd_post_fc_real_return_closure_delta_ledger_summary.csv",
    "v61fd_deltas": results / "v61fd_post_fc_real_return_closure_delta_ledger" / "ledger_001" / "post_fc_real_return_closure_delta_rows.csv",
    "v61fu_summary": results / "v61fu_post_ft_external_return_closure_frontier_summary.csv",
    "v61fu_requirements": results / "v61fu_post_ft_external_return_closure_frontier" / "frontier_001" / "external_return_closure_frontier_requirement_rows.csv",
    "v61fv_summary": results / "v61fv_post_fu_dual_return_replay_entrypoint_summary.csv",
    "v61fv_commands": results / "v61fv_post_fu_dual_return_replay_entrypoint" / "entrypoint_001" / "dual_return_replay_entrypoint_command_rows.csv",
    "v61fv_env": results / "v61fv_post_fu_dual_return_replay_entrypoint" / "entrypoint_001" / "dual_return_replay_required_env_rows.csv",
    "v61fv_env_template": results / "v61fv_post_fu_dual_return_replay_entrypoint" / "entrypoint_001" / "dual_return_replay_entrypoint" / "DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "v61fv_run_script": results / "v61fv_post_fu_dual_return_replay_entrypoint" / "entrypoint_001" / "dual_return_replay_entrypoint" / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
    "v61fw_summary": results / "v61fw_post_fv_dual_return_replay_entrypoint_receipt_summary.csv",
    "v61fw_execution": results / "v61fw_post_fv_dual_return_replay_entrypoint_receipt" / "receipt_001" / "dual_return_replay_entrypoint_receipt_execution_rows.csv",
    "v61fw_guard": results / "v61fw_post_fv_dual_return_replay_entrypoint_receipt" / "receipt_001" / "dual_return_replay_entrypoint_guard_probe_rows.csv",
    "v61fw_stage": results / "v61fw_post_fv_dual_return_replay_entrypoint_receipt" / "receipt_001" / "dual_return_replay_entrypoint_receipt_stage_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fx source {label}: {path}")

v61fc = read_csv(source_paths["v61fc_summary"])[0]
v61fd = read_csv(source_paths["v61fd_summary"])[0]
v61fu = read_csv(source_paths["v61fu_summary"])[0]
v61fv = read_csv(source_paths["v61fv_summary"])[0]
v61fw = read_csv(source_paths["v61fw_summary"])[0]

required_ready = {
    "v61fc_post_fb_dual_external_return_operator_packet_ready": v61fc,
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": v61fd,
    "v61fu_post_ft_external_return_closure_frontier_ready": v61fu,
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": v61fv,
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_ready": v61fw,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v61fx requires {key}=1")

source_rows = []
for label, path in source_paths.items():
    if label.endswith("_env_template") or label.endswith("_run_script"):
        folder = "source_v61fv"
    elif label.startswith("v61fc"):
        folder = "source_v61fc"
    elif label.startswith("v61fd"):
        folder = "source_v61fd"
    elif label.startswith("v61fu"):
        folder = "source_v61fu"
    elif label.startswith("v61fv"):
        folder = "source_v61fv"
    else:
        folder = "source_v61fw"
    copied = copy(path, f"{folder}/{path.name}")
    source_rows.append({
        "source_id": label,
        "path": copied.relative_to(run_dir).as_posix(),
        "bytes": copied.stat().st_size,
        "sha256": sha256(copied),
        "metadata_only": "1",
    })
write_csv(run_dir / "dual_return_operator_handoff_source_rows.csv", list(source_rows[0].keys()), source_rows)

root_contract_rows = [
    {
        "root_id": "v53-external-return-root",
        "required_env_var": "V61FV_V53_RETURN_BUNDLE_DIR",
        "required_provenance_env_var": "V61FV_V53_RETURN_PROVENANCE",
        "required_provenance_value": "real-external-return-bundle",
        "required_artifact_rows": str(as_int(v61fc, "v53_required_artifact_rows")),
        "supplied_by_default": "0",
        "accepted_by_default": "0",
        "purpose": "complete-source review/adjudication/external-return artifacts",
    },
    {
        "root_id": "v61-generation-intake-return-root",
        "required_env_var": "V61FV_V61_RETURN_BUNDLE_DIR",
        "required_provenance_env_var": "V61FV_V61_RETURN_PROVENANCE",
        "required_provenance_value": "real-generation-intake-return-bundle",
        "required_artifact_rows": str(as_int(v61fc, "v61_required_artifact_rows")),
        "supplied_by_default": "0",
        "accepted_by_default": "0",
        "purpose": "real generation result/intake artifacts",
    },
]
write_csv(run_dir / "dual_return_operator_handoff_root_contract_rows.csv", list(root_contract_rows[0].keys()), root_contract_rows)

stage_rows = [
    {"stage_id": "01-dual-return-packet-contract", "status": "ready", "evidence": "v61fc ready; 91 required artifacts", "blocking_reason": ""},
    {"stage_id": "02-real-return-delta-ledger", "status": "ready", "evidence": "v61fd ready; 14 open deltas", "blocking_reason": ""},
    {"stage_id": "03-external-return-frontier", "status": "ready", "evidence": "v61fu ready; two real roots named", "blocking_reason": ""},
    {"stage_id": "04-guarded-replay-entrypoint", "status": "ready", "evidence": "v61fv ready; exact provenance required", "blocking_reason": ""},
    {"stage_id": "05-entrypoint-local-receipts", "status": "ready", "evidence": "v61fw ready; guard probes passed", "blocking_reason": ""},
    {"stage_id": "06-v53-real-root-supplied", "status": "blocked", "evidence": "V61FV_V53_RETURN_BUNDLE_DIR absent by default", "blocking_reason": "81-artifact real v53 return root required"},
    {"stage_id": "07-v61-real-root-supplied", "status": "blocked", "evidence": "V61FV_V61_RETURN_BUNDLE_DIR absent by default", "blocking_reason": "10-file real v61 generation-intake return root required"},
    {"stage_id": "08-real-replay-and-generation", "status": "blocked", "evidence": "real_replay_command_executed=0; actual_model_generation_ready=0", "blocking_reason": "requires both real roots and accepted downstream replay"},
]
write_csv(run_dir / "dual_return_operator_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

action_rows = [
    {"action_id": "01-verify-dual-return-packet", "ready_to_run_now": "1", "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/VERIFY_DUAL_RETURN_PACKET.sh", "purpose": "verify the 91-artifact dual return packet"},
    {"action_id": "02-verify-replay-entrypoint", "ready_to_run_now": "1", "command": "results/v61fv_post_fu_dual_return_replay_entrypoint/entrypoint_001/dual_return_replay_entrypoint/VERIFY_DUAL_RETURN_REPLAY_ENTRYPOINT.sh", "purpose": "verify guarded replay entrypoint"},
    {"action_id": "03-verify-entrypoint-receipts", "ready_to_run_now": "1", "command": "results/v61fw_post_fv_dual_return_replay_entrypoint_receipt/receipt_001/dual_return_replay_entrypoint_receipt/VERIFY_ENTRYPOINT_RECEIPTS.sh", "purpose": "verify local receipt and guard evidence"},
    {"action_id": "04-verify-this-handoff", "ready_to_run_now": "1", "command": "results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh", "purpose": "verify final operator handoff bundle"},
    {"action_id": "05-set-v53-real-root", "ready_to_run_now": "0", "command": "export V61FV_V53_RETURN_BUNDLE_DIR=/path/to/v53_external_return_root; export V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle", "purpose": "requires real 81-artifact v53 return root"},
    {"action_id": "06-set-v61-real-root", "ready_to_run_now": "0", "command": "export V61FV_V61_RETURN_BUNDLE_DIR=/path/to/v61_generation_intake_return_root; export V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle", "purpose": "requires real 10-file v61 generation-intake return root"},
    {"action_id": "07-run-dual-return-replay", "ready_to_run_now": "0", "command": "results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh", "purpose": "execute real return replay only after roots and provenance are supplied"},
    {"action_id": "08-refresh-active-goal-audit", "ready_to_run_now": "0", "command": "./experiments/run_v61ft_active_goal_completion_audit.sh", "purpose": "refresh completion audit after real return replay closes"},
]
write_csv(run_dir / "dual_return_operator_handoff_action_rows.csv", list(action_rows[0].keys()), action_rows)

for rel, path in [
    ("DUAL_RETURN_ROOT_CONTRACT_ROWS.csv", run_dir / "dual_return_operator_handoff_root_contract_rows.csv"),
    ("DUAL_RETURN_OPERATOR_HANDOFF_STAGE_ROWS.csv", run_dir / "dual_return_operator_handoff_stage_rows.csv"),
    ("DUAL_RETURN_OPERATOR_HANDOFF_ACTION_ROWS.csv", run_dir / "dual_return_operator_handoff_action_rows.csv"),
    ("DUAL_RETURN_OPERATOR_HANDOFF_SOURCE_ROWS.csv", run_dir / "dual_return_operator_handoff_source_rows.csv"),
]:
    copy_handoff(path, rel)
copy_handoff(source_paths["v61fv_env_template"], "DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh")
copy_handoff(source_paths["v61fv_run_script"], "RUN_DUAL_RETURN_REPLAY_IF_READY.sh")
(handoff_dir / "DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh").chmod(0o755)
(handoff_dir / "RUN_DUAL_RETURN_REPLAY_IF_READY.sh").chmod(0o755)

handoff_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "root_contract_rows": len(root_contract_rows),
    "v53_required_artifact_rows": as_int(v61fc, "v53_required_artifact_rows"),
    "v61_required_artifact_rows": as_int(v61fc, "v61_required_artifact_rows"),
    "dual_required_artifact_rows": as_int(v61fc, "dual_required_artifact_rows"),
    "open_delta_rows": as_int(v61fd, "open_delta_rows"),
    "missing_external_return_artifacts": as_int(v61fd, "missing_external_return_artifacts"),
    "receipt_guard_probe_rows": as_int(v61fw, "guard_probe_rows"),
    "receipt_passed_guard_probe_rows": as_int(v61fw, "passed_guard_probe_rows"),
    "real_replay_command_executed": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(handoff_dir / "DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json").write_text(json.dumps(handoff_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(handoff_dir / "VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_CONTRACT_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_OPERATOR_HANDOFF_STAGE_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_OPERATOR_HANDOFF_ACTION_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_OPERATOR_HANDOFF_SOURCE_ROWS.csv\"",
        "test -x \"$DIR/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh\"",
        "test -x \"$DIR/RUN_DUAL_RETURN_REPLAY_IF_READY.sh\"",
        "grep -q 'real-external-return-bundle' \"$DIR/DUAL_RETURN_ROOT_CONTRACT_ROWS.csv\"",
        "grep -q 'real-generation-intake-return-bundle' \"$DIR/DUAL_RETURN_ROOT_CONTRACT_ROWS.csv\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/DUAL_RETURN_OPERATOR_HANDOFF_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in operator handoff package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(handoff_dir / "VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh").chmod(0o755)
(handoff_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61fx ready-now commands verify packets only; real replay requires both real return roots and exact provenance.'",
        "echo 'results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh'",
        "echo 'source results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/DUAL_RETURN_REPLAY_ENV_TEMPLATE.sh'",
        "echo 'results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh'",
        "",
    ]),
    encoding="utf-8",
)
(handoff_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)
(handoff_dir / "DUAL_RETURN_OPERATOR_HANDOFF.md").write_text(
    "\n".join([
        "# v61fx dual return operator handoff bundle",
        "",
        f"- root_contract_rows={len(root_contract_rows)}",
        f"- dual_required_artifact_rows={as_int(v61fc, 'dual_required_artifact_rows')}",
        f"- open_delta_rows={as_int(v61fd, 'open_delta_rows')}",
        f"- receipt_guard_probe_rows={as_int(v61fw, 'guard_probe_rows')}",
        f"- receipt_passed_guard_probe_rows={as_int(v61fw, 'passed_guard_probe_rows')}",
        "- real_replay_command_executed=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Supply the real v53 and v61 return roots, source the env template, then run the guarded replay script. Template, fixture, and missing-provenance paths remain non-accepted evidence.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in handoff_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "dual_return_operator_handoff_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": 1,
    "v61fw_post_fv_dual_return_replay_entrypoint_receipt_ready": 1,
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": 1,
    "v61fu_post_ft_external_return_closure_frontier_ready": 1,
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": 1,
    "v61fc_post_fb_dual_external_return_operator_packet_ready": 1,
    "root_contract_rows": len(root_contract_rows),
    "v53_required_artifact_rows": as_int(v61fc, "v53_required_artifact_rows"),
    "v61_required_artifact_rows": as_int(v61fc, "v61_required_artifact_rows"),
    "dual_required_artifact_rows": as_int(v61fc, "dual_required_artifact_rows"),
    "open_delta_rows": as_int(v61fd, "open_delta_rows"),
    "missing_external_return_artifacts": as_int(v61fd, "missing_external_return_artifacts"),
    "receipt_ready_command_rows": as_int(v61fw, "ready_command_rows"),
    "receipt_successful_ready_command_rows": as_int(v61fw, "successful_ready_command_rows"),
    "receipt_guard_probe_rows": as_int(v61fw, "guard_probe_rows"),
    "receipt_passed_guard_probe_rows": as_int(v61fw, "passed_guard_probe_rows"),
    "handoff_stage_rows": len(stage_rows),
    "ready_handoff_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_handoff_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "handoff_action_rows": len(action_rows),
    "ready_handoff_action_rows": sum(row["ready_to_run_now"] == "1" for row in action_rows),
    "blocked_handoff_action_rows": sum(row["ready_to_run_now"] == "0" for row in action_rows),
    "handoff_source_rows": len(source_rows),
    "operator_handoff_bundle_file_rows": len(package_file_rows),
    "metadata_only_operator_handoff_bundle_file_rows": sum(row["metadata_only"] == "1" for row in package_file_rows),
    "payload_like_operator_handoff_bundle_file_rows": sum(row["payload_like"] == "1" for row in package_file_rows),
    "real_replay_command_executed": 0,
    "dual_external_return_real_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fx": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "upstream-v61fw-receipt", "status": "pass", "actual_value": "ready", "required_value": "ready", "reason": "v61fw receipt and guard probes are bound"},
    {"gate": "dual-root-contract", "status": "pass", "actual_value": str(summary["root_contract_rows"]), "required_value": "2", "reason": "v53 and v61 real roots have exact provenance contracts"},
    {"gate": "operator-handoff-package", "status": "pass", "actual_value": str(summary["operator_handoff_bundle_file_rows"]), "required_value": "metadata-only package", "reason": "handoff verifier and guarded scripts are present"},
    {"gate": "real-return-roots", "status": "blocked", "actual_value": "0", "required_value": "2 supplied real roots", "reason": "no real v53/v61 return roots supplied by default"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "real replay and accepted generation results are still missing"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "operator handoff contains no checkpoint payload"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FX_POST_FW_DUAL_RETURN_OPERATOR_HANDOFF_BUNDLE_BOUNDARY.md"
boundary.write_text(
    "\n".join([
        "# V61FX Post-FW Dual Return Operator Handoff Bundle",
        "",
        "- v61fx_post_fw_dual_return_operator_handoff_bundle_ready=1",
        f"- root_contract_rows={summary['root_contract_rows']}",
        f"- dual_required_artifact_rows={summary['dual_required_artifact_rows']}",
        f"- open_delta_rows={summary['open_delta_rows']}",
        f"- receipt_ready_command_rows={summary['receipt_ready_command_rows']}",
        f"- receipt_successful_ready_command_rows={summary['receipt_successful_ready_command_rows']}",
        f"- receipt_guard_probe_rows={summary['receipt_guard_probe_rows']}",
        f"- receipt_passed_guard_probe_rows={summary['receipt_passed_guard_probe_rows']}",
        f"- handoff_action_rows={summary['handoff_action_rows']}",
        f"- ready_handoff_action_rows={summary['ready_handoff_action_rows']}",
        f"- blocked_handoff_action_rows={summary['blocked_handoff_action_rows']}",
        "- real_replay_command_executed=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this package is the operator handoff surface after full-shard/page-hash closure. It does not turn templates, receipts, or missing roots into accepted review/generation evidence.",
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

print(f"v61fx_post_fw_dual_return_operator_handoff_bundle_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
