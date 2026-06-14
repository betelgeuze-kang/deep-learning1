#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fr_post_fq_v1_ready_command_handoff"
RUN_ID="${V61FR_RUN_ID:-handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fr_post_fq_v1_ready_command_handoff_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fq_post_fp_v1_comparison_readiness_refresh.sh" >/dev/null
V53AH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ah_complete_source_external_review_send_bundle.sh" >/dev/null
V53AL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
V61FO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh" >/dev/null

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
prefix = "v61fr_post_fq_v1_ready_command_handoff"
handoff_dir = run_dir / "post_fq_v1_ready_command_handoff"
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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def pass_or_blocked(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61fq_summary": results / "v61fq_post_fp_v1_comparison_readiness_refresh_summary.csv",
    "v61fq_decision": results / "v61fq_post_fp_v1_comparison_readiness_refresh_decision.csv",
    "v53ah_summary": results / "v53ah_complete_source_external_review_send_bundle_summary.csv",
    "v53ah_decision": results / "v53ah_complete_source_external_review_send_bundle_decision.csv",
    "v53al_summary": results / "v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "v53al_decision": results / "v53al_complete_source_external_return_bundle_preflight_decision.csv",
    "v61fo_summary": results / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_summary.csv",
    "v61fo_decision": results / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fr source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

source_artifacts = {
    "v61fq_readiness_rows.csv": results / "v61fq_post_fp_v1_comparison_readiness_refresh" / "refresh_001" / "post_fp_v1_comparison_readiness_rows.csv",
    "v61fq_next_action_rows.csv": results / "v61fq_post_fp_v1_comparison_readiness_refresh" / "refresh_001" / "post_fp_v1_comparison_next_action_rows.csv",
    "v53ah_send_bundle_file_rows.csv": results / "v53ah_complete_source_external_review_send_bundle" / "bundle_001" / "complete_source_external_review_send_bundle_file_rows.csv",
    "v53ah_send_bundle_requirement_rows.csv": results / "v53ah_complete_source_external_review_send_bundle" / "bundle_001" / "complete_source_external_review_send_bundle_requirement_rows.csv",
    "v53al_preflight_rows.csv": results / "v53al_complete_source_external_return_bundle_preflight" / "preflight_001" / "external_return_bundle_preflight_rows.csv",
    "v61fo_entrypoint_command_rows.csv": results / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint" / "entrypoint_001" / "post_fn_real_manifest_external_review_return_replay_entrypoint_command_rows.csv",
}
for rel, path in source_artifacts.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fr source artifact: {path}")
    copy(path, f"source_artifacts/{rel}")

v61fq = read_csv(sources["v61fq_summary"])[0]
v53ah = read_csv(sources["v53ah_summary"])[0]
v53al = read_csv(sources["v53al_summary"])[0]
v61fo = read_csv(sources["v61fo_summary"])[0]

if v61fq.get("v61fq_post_fp_v1_comparison_readiness_refresh_ready") != "1":
    raise SystemExit("v61fr requires v61fq readiness")
if v53ah.get("v53ah_complete_source_external_review_send_bundle_ready") != "1":
    raise SystemExit("v61fr requires v53ah readiness")
if v53al.get("v53al_complete_source_external_return_bundle_preflight_ready") != "1":
    raise SystemExit("v61fr requires v53al readiness")
if v61fo.get("v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready") != "1":
    raise SystemExit("v61fr requires v61fo readiness")

v52_ready = as_int(v61fq, "v52_ready")
comparison_wording_claim_ready = as_int(v61fq, "comparison_wording_claim_ready")
v53_machine_complete_source_surface_ready = as_int(v61fq, "v53_machine_complete_source_surface_ready")
full_shard_prerequisites_closed = as_int(v61fq, "full_shard_prerequisites_closed")
v1_0_comparison_ready = as_int(v61fq, "v1_0_comparison_ready")
actual_model_generation_ready = 0
send_bundle_ready = as_int(v53ah, "send_bundle_ready")
send_bundle_archive_files = as_int(v53ah, "send_bundle_archive_files")
return_artifact_template_archive_member_rows = as_int(v53ah, "return_artifact_template_archive_member_rows")
accepted_dispatch_receipt_rows = as_int(v53ah, "accepted_dispatch_receipt_rows")
return_bundle_preflight_pass = as_int(v53al, "return_bundle_preflight_pass")
preflight_pass_rows = as_int(v53al, "preflight_pass_rows")
preflight_rows = as_int(v53al, "preflight_rows")
replay_entrypoint_ready = as_int(v61fo, "replay_entrypoint_ready")
replay_entrypoint_admitted = as_int(v61fo, "replay_entrypoint_admitted")
external_review_return_ready = as_int(v61fo, "external_review_return_ready")

stage_rows = [
    {"stage_id": "01-v61fq-refresh-ready", "status": "ready", "ready": "1", "evidence": "v61fq readiness refresh ready", "blocked_reason": ""},
    {"stage_id": "02-v53-send-bundle-ready", "status": "ready", "ready": str(send_bundle_ready), "evidence": f"send_bundle_ready={send_bundle_ready}; archives={send_bundle_archive_files}", "blocked_reason": ""},
    {"stage_id": "03-ready-command-handoff-package", "status": "ready", "ready": "1", "evidence": "metadata-only handoff emitted", "blocked_reason": ""},
    {"stage_id": "04-v53-return-bundle-preflight", "status": "blocked", "ready": str(return_bundle_preflight_pass), "evidence": f"preflight_pass_rows={preflight_pass_rows}/{preflight_rows}", "blocked_reason": "requires real returned 81-artifact bundle"},
    {"stage_id": "05-v61-real-review-return", "status": "blocked", "ready": str(external_review_return_ready), "evidence": f"external_review_return_ready={external_review_return_ready}", "blocked_reason": "requires real review-return root and provenance"},
    {"stage_id": "06-generation-result-acceptance", "status": "blocked", "ready": "0", "evidence": "accepted_generation_result_artifacts=0/5", "blocked_reason": "requires real generation result artifacts after execution"},
    {"stage_id": "07-v1-comparison-ready", "status": "blocked", "ready": str(v1_0_comparison_ready), "evidence": f"v1_0_comparison_ready={v1_0_comparison_ready}", "blocked_reason": "requires review/adjudication and generation evidence"},
]
write_csv(run_dir / "post_fq_v1_ready_command_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

external_input_rows = [
    {"input_id": "01-v53-return-bundle-dir", "required": "1", "present": "0", "target_env": "V53AL_RETURN_BUNDLE_DIR", "expected_shape": "81 final return artifacts", "downstream_gate": "v53al/v53am"},
    {"input_id": "02-v61-review-return-dir", "required": "1", "present": "0", "target_env": "V61FO_REVIEW_RETURN_DIR", "expected_shape": "six real manifest external review return artifacts", "downstream_gate": "v61fo/v61fh/v61fn"},
    {"input_id": "03-v61-review-return-provenance", "required": "1", "present": "0", "target_env": "V61FO_REVIEW_RETURN_PROVENANCE", "expected_shape": "real-external-review-return", "downstream_gate": "v61fo"},
    {"input_id": "04-generation-result-artifacts", "required": "1", "present": "0", "target_env": "V61BT_GENERATION_RESULT_DIR", "expected_shape": "five generation result artifacts", "downstream_gate": "v61bt/v61de/v61cu"},
    {"input_id": "05-release-review-evidence", "required": "1", "present": "0", "target_env": "V60_RELEASE_REVIEW_DIR", "expected_shape": "latency, near-frontier quality, release review package", "downstream_gate": "v60/release"},
]
write_csv(run_dir / "post_fq_v1_ready_command_handoff_external_input_rows.csv", list(external_input_rows[0].keys()), external_input_rows)

command_rows = [
    {"command_id": "01-verify-v61fr-handoff-package", "ready_to_run_now": "1", "command": "bash results/v61fr_post_fq_v1_ready_command_handoff/handoff_001/post_fq_v1_ready_command_handoff/VERIFY_HANDOFF.sh", "purpose": "verify metadata-only handoff package"},
    {"command_id": "02-verify-v61fq-refresh", "ready_to_run_now": "1", "command": "./experiments/test_v61fq_post_fp_v1_comparison_readiness_refresh.sh", "purpose": "verify v1 comparison readiness boundary"},
    {"command_id": "03-verify-v53ah-send-bundle", "ready_to_run_now": "1", "command": "bash results/v53ah_complete_source_external_review_send_bundle/bundle_001/send_bundle/VERIFY_SEND_BUNDLE.sh", "purpose": "verify complete-source external send bundle"},
    {"command_id": "04-print-ready-now-commands", "ready_to_run_now": "1", "command": "results/v61fr_post_fq_v1_ready_command_handoff/handoff_001/post_fq_v1_ready_command_handoff/READY_NOW_COMMANDS.sh", "purpose": "print safe local verification commands and blocked external inputs"},
    {"command_id": "05-preflight-v53-return-bundle", "ready_to_run_now": "0", "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh", "purpose": "requires real 81-artifact returned bundle"},
    {"command_id": "06-replay-v53-return-acceptance", "ready_to_run_now": "0", "command": "V53AM_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53am_complete_source_return_acceptance_replay.sh", "purpose": "requires passing v53al preflight"},
    {"command_id": "07-run-v61-real-review-return-entrypoint", "ready_to_run_now": "0", "command": "V61FO_REVIEW_RETURN_DIR=/path/to/real-review-return V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return results/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/entrypoint_001/real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh", "purpose": "requires real v61 review-return root and provenance"},
    {"command_id": "08-refresh-v1-comparison-after-evidence", "ready_to_run_now": "0", "command": "./experiments/run_v61fq_post_fp_v1_comparison_readiness_refresh.sh", "purpose": "run after accepted review/generation evidence closes"},
]
write_csv(run_dir / "post_fq_v1_ready_command_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

metric_rows = [{
    "v52_ready": v52_ready,
    "comparison_wording_claim_ready": comparison_wording_claim_ready,
    "v53_machine_complete_source_surface_ready": v53_machine_complete_source_surface_ready,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "send_bundle_ready": send_bundle_ready,
    "send_bundle_archive_files": send_bundle_archive_files,
    "return_artifact_template_archive_member_rows": return_artifact_template_archive_member_rows,
    "accepted_dispatch_receipt_rows": accepted_dispatch_receipt_rows,
    "return_bundle_preflight_pass": return_bundle_preflight_pass,
    "preflight_pass_rows": preflight_pass_rows,
    "preflight_rows": preflight_rows,
    "replay_entrypoint_ready": replay_entrypoint_ready,
    "replay_entrypoint_admitted": replay_entrypoint_admitted,
    "external_review_return_ready": external_review_return_ready,
    "v1_0_comparison_ready": v1_0_comparison_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fr": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}]
write_csv(run_dir / "post_fq_v1_ready_command_handoff_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

shutil.copy2(run_dir / "post_fq_v1_ready_command_handoff_stage_rows.csv", handoff_dir / "HANDOFF_STAGE_ROWS.csv")
shutil.copy2(run_dir / "post_fq_v1_ready_command_handoff_command_rows.csv", handoff_dir / "HANDOFF_COMMAND_ROWS.csv")
shutil.copy2(run_dir / "post_fq_v1_ready_command_handoff_external_input_rows.csv", handoff_dir / "REQUIRED_EXTERNAL_INPUT_ROWS.csv")
handoff_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "send_bundle_ready": send_bundle_ready,
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "required_external_input_rows": len(external_input_rows),
    "present_external_input_rows": sum(row["present"] == "1" for row in external_input_rows),
    "v1_0_comparison_ready": v1_0_comparison_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(handoff_dir / "HANDOFF_MANIFEST.json").write_text(json.dumps(handoff_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(handoff_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "cat <<'COMMANDS'",
            "# Ready local verification commands",
            "bash results/v61fr_post_fq_v1_ready_command_handoff/handoff_001/post_fq_v1_ready_command_handoff/VERIFY_HANDOFF.sh",
            "./experiments/test_v61fq_post_fp_v1_comparison_readiness_refresh.sh",
            "bash results/v53ah_complete_source_external_review_send_bundle/bundle_001/send_bundle/VERIFY_SEND_BUNDLE.sh",
            "",
            "# Blocked until external inputs exist",
            "V53AL_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh",
            "V53AM_RETURN_BUNDLE_DIR=/path/to/returned-bundle ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
            "V61FO_REVIEW_RETURN_DIR=/path/to/real-review-return V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return results/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/entrypoint_001/real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh",
            "COMMANDS",
            "",
        ]
    ),
    encoding="utf-8",
)
(handoff_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)
(handoff_dir / "VERIFY_HANDOFF.sh").write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -s \"$DIR/HANDOFF_MANIFEST.json\"",
            "test -s \"$DIR/HANDOFF_STAGE_ROWS.csv\"",
            "test -s \"$DIR/HANDOFF_COMMAND_ROWS.csv\"",
            "test -s \"$DIR/REQUIRED_EXTERNAL_INPUT_ROWS.csv\"",
            "test -x \"$DIR/READY_NOW_COMMANDS.sh\"",
            "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
            "  echo 'payload-like file referenced in handoff package' >&2",
            "  exit 1",
            "fi",
            "",
        ]
    ),
    encoding="utf-8",
)
(handoff_dir / "VERIFY_HANDOFF.sh").chmod(0o755)
(handoff_dir / "V1_READY_COMMAND_HANDOFF.md").write_text(
    "\n".join(
        [
            "# v61fr post-v61fq ready command handoff",
            "",
            f"- send_bundle_ready={send_bundle_ready}",
            f"- v52_ready={v52_ready}",
            f"- comparison_wording_claim_ready={comparison_wording_claim_ready}",
            f"- v53_machine_complete_source_surface_ready={v53_machine_complete_source_surface_ready}",
            f"- full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
            f"- return_bundle_preflight_pass={return_bundle_preflight_pass}",
            f"- external_review_return_ready={external_review_return_ready}",
            f"- v1_0_comparison_ready={v1_0_comparison_ready}",
            "- actual_model_generation_ready=0",
            "",
            "Only local verification and send-bundle checks are ready now. Real return preflight, replay, generation-result acceptance, and v1.0 comparison remain blocked until external return roots are supplied.",
            "",
        ]
    ),
    encoding="utf-8",
)

package_files = sorted(path for path in handoff_dir.rglob("*") if path.is_file())
file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "post_fq_v1_ready_command_handoff_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61fr_post_fq_v1_ready_command_handoff_ready": 1,
    "v61fq_post_fp_v1_comparison_readiness_refresh_ready": 1,
    "v53ah_complete_source_external_review_send_bundle_ready": 1,
    "v53al_complete_source_external_return_bundle_preflight_ready": 1,
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": 1,
    **metric_rows[0],
    "handoff_stage_rows": len(stage_rows),
    "ready_handoff_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_handoff_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "handoff_command_rows": len(command_rows),
    "ready_handoff_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_handoff_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "required_external_input_rows": len(external_input_rows),
    "present_external_input_rows": sum(row["present"] == "1" for row in external_input_rows),
    "missing_external_input_rows": sum(row["present"] == "0" for row in external_input_rows),
    "handoff_package_file_rows": len(file_rows),
    "metadata_only_handoff_package_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_handoff_package_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": len(sources),
    "source_artifact_file_rows": len(source_artifacts),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61fq-refresh", "status": "pass", "actual_value": "1", "required_value": "1", "reason": "v1 comparison readiness refresh exists"},
    {"gate": "v53-send-bundle", "status": pass_or_blocked(send_bundle_ready), "actual_value": str(send_bundle_ready), "required_value": "1", "reason": "external review send bundle is ready"},
    {"gate": "local-ready-commands", "status": "pass", "actual_value": str(summary["ready_handoff_command_rows"]), "required_value": "4", "reason": "local verification commands are listed"},
    {"gate": "required-external-inputs", "status": "blocked", "actual_value": f"{summary['present_external_input_rows']}/{summary['required_external_input_rows']}", "required_value": "5/5", "reason": "real returned roots are missing"},
    {"gate": "v53-return-preflight", "status": pass_or_blocked(return_bundle_preflight_pass), "actual_value": f"{preflight_pass_rows}/{preflight_rows}", "required_value": "81/81", "reason": "returned bundle missing"},
    {"gate": "v61-real-review-return", "status": pass_or_blocked(external_review_return_ready), "actual_value": str(external_review_return_ready), "required_value": "1", "reason": "real v61 review return missing"},
    {"gate": "v1-comparison", "status": pass_or_blocked(v1_0_comparison_ready), "actual_value": str(v1_0_comparison_ready), "required_value": "1", "reason": "review/generation evidence missing"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual model generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only handoff"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FR_POST_FQ_V1_READY_COMMAND_HANDOFF_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# V61FR Post-v61fq V1 Ready Command Handoff Boundary",
            "",
            "- v61fr_post_fq_v1_ready_command_handoff_ready=1",
            f"- send_bundle_ready={send_bundle_ready}",
            f"- send_bundle_archive_files={send_bundle_archive_files}",
            f"- return_artifact_template_archive_member_rows={return_artifact_template_archive_member_rows}",
            f"- v52_ready={v52_ready}",
            f"- comparison_wording_claim_ready={comparison_wording_claim_ready}",
            f"- v53_machine_complete_source_surface_ready={v53_machine_complete_source_surface_ready}",
            f"- full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
            f"- return_bundle_preflight_pass={return_bundle_preflight_pass}",
            f"- external_review_return_ready={external_review_return_ready}",
            f"- replay_entrypoint_admitted={replay_entrypoint_admitted}",
            f"- v1_0_comparison_ready={v1_0_comparison_ready}",
            "- actual_model_generation_ready=0",
            f"- handoff_stage_rows={len(stage_rows)}",
            f"- ready_handoff_stage_rows={summary['ready_handoff_stage_rows']}",
            f"- blocked_handoff_stage_rows={summary['blocked_handoff_stage_rows']}",
            f"- handoff_command_rows={len(command_rows)}",
            f"- ready_handoff_command_rows={summary['ready_handoff_command_rows']}",
            f"- blocked_handoff_command_rows={summary['blocked_handoff_command_rows']}",
            f"- required_external_input_rows={len(external_input_rows)}",
            f"- missing_external_input_rows={summary['missing_external_input_rows']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Blocked wording: ready-now commands are local verification and send-bundle checks only. Real return preflight, replay, generation-result acceptance, v1.0 comparison, production latency, near-frontier, and release claims remain blocked until external returned evidence is supplied.",
            "",
        ]
    ),
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

print(f"v61fr_post_fq_v1_ready_command_handoff_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
