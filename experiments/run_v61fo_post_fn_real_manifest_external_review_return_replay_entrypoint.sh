#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint"
RUN_ID="${V61FO_RUN_ID:-entrypoint_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
REVIEW_RETURN_DIR_ARG="${V61FO_REVIEW_RETURN_DIR:-}"
REVIEW_RETURN_PROVENANCE="${V61FO_REVIEW_RETURN_PROVENANCE:-unspecified}"

if [[ "${V61FO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh" >/dev/null
V61FM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh" >/dev/null
V61FL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$REVIEW_RETURN_DIR_ARG" "$REVIEW_RETURN_PROVENANCE" <<'PY'
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
return_arg = sys.argv[5].strip()
return_provenance = sys.argv[6].strip() or "unspecified"
results = root / "results"
entrypoint_dir = run_dir / "real_manifest_external_review_return_replay_entrypoint"
entrypoint_dir.mkdir(parents=True, exist_ok=True)
return_dir = Path(return_arg).expanduser().resolve() if return_arg else None


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


def status(flag):
    return "pass" if flag else "blocked"


def ready(flag):
    return "ready" if flag else "blocked"


sources = {
    "v61fn_summary": results / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_summary.csv",
    "v61fn_decision": results / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_decision.csv",
    "v61fm_summary": results / "v61fm_post_fl_real_manifest_external_review_return_work_order_summary.csv",
    "v61fm_decision": results / "v61fm_post_fl_real_manifest_external_review_return_work_order_decision.csv",
    "v61fh_summary": results / "v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
    "v61fh_decision": results / "v61fh_post_fg_real_manifest_external_review_return_intake_decision.csv",
    "v61fi_summary": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_summary.csv",
    "v61fi_decision": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_decision.csv",
    "v61fl_summary": results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_summary.csv",
    "v61fl_decision": results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fo source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

source_artifacts = {
    "v61fn_stage_rows.csv": results / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate" / "replay_001" / "post_fm_real_manifest_external_review_acceptance_replay_stage_rows.csv",
    "v61fn_requirement_rows.csv": results / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate" / "replay_001" / "post_fm_real_manifest_external_review_acceptance_replay_requirement_rows.csv",
    "v61fm_work_order_rows.csv": results / "v61fm_post_fl_real_manifest_external_review_return_work_order" / "work_order_001" / "post_fl_real_manifest_external_review_return_work_order_rows.csv",
    "v61fh_required_artifacts.csv": results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001" / "real_manifest_external_review_required_artifact_rows.csv",
}
for rel, path in source_artifacts.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fo source artifact: {path}")
    copy(path, f"source_artifacts/{rel}")

v61fn = read_csv(sources["v61fn_summary"])[0]
v61fm = read_csv(sources["v61fm_summary"])[0]
v61fh = read_csv(sources["v61fh_summary"])[0]
v61fi = read_csv(sources["v61fi_summary"])[0]
v61fl = read_csv(sources["v61fl_summary"])[0]
if v61fn.get("v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready") != "1":
    raise SystemExit("v61fo requires v61fn readiness")
if v61fm.get("v61fm_post_fl_real_manifest_external_review_return_work_order_ready") != "1":
    raise SystemExit("v61fo requires v61fm readiness")
if v61fh.get("v61fh_post_fg_real_manifest_external_review_return_intake_ready") != "1":
    raise SystemExit("v61fo requires v61fh readiness")
if v61fi.get("v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready") != "1":
    raise SystemExit("v61fo requires v61fi readiness")
if v61fl.get("v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready") != "1":
    raise SystemExit("v61fo requires v61fl readiness")

return_dir_supplied = int(return_dir is not None)
return_dir_exists = int(return_dir is not None and return_dir.is_dir())
real_review_return_provenance_asserted = int(return_provenance == "real-external-review-return")
fixture_return_provenance = int(return_provenance.startswith("fixture"))
replay_entrypoint_ready = 1
replay_entrypoint_admitted = int(
    return_dir_supplied
    and return_dir_exists
    and real_review_return_provenance_asserted
)

env_rows = [
    {"env_var": "V61FO_REVIEW_RETURN_DIR", "required": "1", "supplied": str(return_dir_supplied), "value_class": "directory", "accepted_default": "0"},
    {"env_var": "V61FO_REVIEW_RETURN_PROVENANCE", "required": "1", "supplied": str(int(bool(return_provenance and return_provenance != "unspecified"))), "value_class": "provenance", "accepted_default": "0"},
    {"env_var": "V61FO_RETURN_RUN_ID", "required": "0", "supplied": "0", "value_class": "run-id", "accepted_default": "real_review_return_v61fh"},
    {"env_var": "V61FO_HANDOFF_RUN_ID", "required": "0", "supplied": "0", "value_class": "run-id", "accepted_default": "real_review_return_v61fl"},
    {"env_var": "V61FO_REPLAY_RUN_ID", "required": "0", "supplied": "0", "value_class": "run-id", "accepted_default": "real_review_return_v61fn"},
]
write_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_env_rows.csv", list(env_rows[0].keys()), env_rows)

operator_script = entrypoint_dir / "RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh"
operator_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            ': "${V61FO_REVIEW_RETURN_DIR:?set V61FO_REVIEW_RETURN_DIR}"',
            ': "${V61FO_REVIEW_RETURN_PROVENANCE:?set V61FO_REVIEW_RETURN_PROVENANCE}"',
            'if [[ "$V61FO_REVIEW_RETURN_PROVENANCE" != "real-external-review-return" ]]; then',
            "  echo 'review return provenance must be real-external-review-return' >&2",
            "  exit 2",
            "fi",
            'if [[ ! -d "$V61FO_REVIEW_RETURN_DIR" ]]; then',
            "  echo 'review return directory must exist' >&2",
            "  exit 2",
            "fi",
            'V61FO_RETURN_RUN_ID="${V61FO_RETURN_RUN_ID:-real_review_return_v61fh}"',
            'V61FO_HANDOFF_RUN_ID="${V61FO_HANDOFF_RUN_ID:-real_review_return_v61fl}"',
            'V61FO_REPLAY_RUN_ID="${V61FO_REPLAY_RUN_ID:-real_review_return_v61fn}"',
            'V61FH_RUN_ID="$V61FO_RETURN_RUN_ID" V61FH_EXTERNAL_REVIEW_RETURN_DIR="$V61FO_REVIEW_RETURN_DIR" V61FH_REUSE_EXISTING=0 ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh',
            "V61FI_REUSE_EXISTING=0 ./experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh",
            'V61FL_RUN_ID="$V61FO_HANDOFF_RUN_ID" V61FL_RETURN_INTAKE_RUN_DIR="results/v61fh_post_fg_real_manifest_external_review_return_intake/$V61FO_RETURN_RUN_ID" V61FL_REUSE_EXISTING=0 ./experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh',
            'V61FN_RUN_ID="$V61FO_REPLAY_RUN_ID" V61FN_RETURN_INTAKE_RUN_DIR="results/v61fh_post_fg_real_manifest_external_review_return_intake/$V61FO_RETURN_RUN_ID" V61FN_HANDOFF_RUN_DIR="results/v61fl_post_fk_real_manifest_external_review_return_handoff_guard/$V61FO_HANDOFF_RUN_ID" V61FN_REUSE_EXISTING=0 ./experiments/run_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh',
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(operator_script, 0o755)

env_template = entrypoint_dir / "REPLAY_ENTRYPOINT_ENV.template"
env_template.write_text(
    "\n".join(
        [
            "export V61FO_REVIEW_RETURN_DIR=/path/to/real/review-return",
            "export V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return",
            "export V61FO_RETURN_RUN_ID=real_review_return_v61fh",
            "export V61FO_HANDOFF_RUN_ID=real_review_return_v61fl",
            "export V61FO_REPLAY_RUN_ID=real_review_return_v61fn",
            "",
        ]
    ),
    encoding="utf-8",
)

command_rows = [
    {"command_id": "verify-entrypoint-package", "command": "bash results/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/entrypoint_001/real_manifest_external_review_return_replay_entrypoint/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.sh", "ready_to_run_now": "1", "expected_effect": "verify metadata-only entrypoint package"},
    {"command_id": "verify-acceptance-replay-gate", "command": "V61FN_REUSE_EXISTING=1 ./experiments/test_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh", "ready_to_run_now": "1", "expected_effect": "verify acceptance replay boundary"},
    {"command_id": "run-real-review-return-replay-if-ready", "command": "real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh", "ready_to_run_now": str(replay_entrypoint_admitted), "expected_effect": "requires real review-return directory and provenance"},
    {"command_id": "refresh-generation-result-chain", "command": "run v61bt/v61de/v61cu only after accepted review return and replay admission", "ready_to_run_now": "0", "expected_effect": "generation remains blocked"},
]
write_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_command_rows.csv", list(command_rows[0].keys()), command_rows)

stage_rows = [
    {"stage_id": "01-entrypoint-package", "status": "ready", "ready": "1", "actual_value": "entrypoint files emitted", "blocking_reason": ""},
    {"stage_id": "02-work-order-ready", "status": "ready", "ready": "1", "actual_value": f"work_order_rows={v61fm['work_order_rows']}", "blocking_reason": ""},
    {"stage_id": "03-review-return-dir-supplied", "status": ready(return_dir_supplied), "ready": str(return_dir_supplied), "actual_value": f"return_dir_supplied={return_dir_supplied}", "blocking_reason": "" if return_dir_supplied else "set V61FO_REVIEW_RETURN_DIR"},
    {"stage_id": "04-review-return-dir-exists", "status": ready(return_dir_exists), "ready": str(return_dir_exists), "actual_value": f"return_dir_exists={return_dir_exists}", "blocking_reason": "" if return_dir_exists else "supplied return directory must exist"},
    {"stage_id": "05-real-review-return-provenance", "status": ready(real_review_return_provenance_asserted), "ready": str(real_review_return_provenance_asserted), "actual_value": f"provenance={return_provenance}", "blocking_reason": "" if real_review_return_provenance_asserted else "requires real-external-review-return provenance"},
    {"stage_id": "06-entrypoint-admitted", "status": ready(replay_entrypoint_admitted), "ready": str(replay_entrypoint_admitted), "actual_value": f"replay_entrypoint_admitted={replay_entrypoint_admitted}", "blocking_reason": "" if replay_entrypoint_admitted else "fail-closed until real return root and provenance are supplied"},
    {"stage_id": "07-accepted-external-review", "status": "blocked", "ready": "0", "actual_value": "external_review_return_ready=0", "blocking_reason": "entrypoint has not accepted real review evidence"},
    {"stage_id": "08-actual-generation", "status": "blocked", "ready": "0", "actual_value": "actual_model_generation_ready=0", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "v61fn-replay-gate", "status": "pass", "required_value": "1", "actual_value": v61fn["v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready"], "reason": "acceptance replay gate is ready"},
    {"requirement_id": "entrypoint-script", "status": "pass", "required_value": "1", "actual_value": "1", "reason": "guarded entrypoint script emitted"},
    {"requirement_id": "review-return-dir-supplied", "status": status(return_dir_supplied), "required_value": "1", "actual_value": str(return_dir_supplied), "reason": "operator must supply real review-return directory"},
    {"requirement_id": "review-return-dir-exists", "status": status(return_dir_exists), "required_value": "1", "actual_value": str(return_dir_exists), "reason": "supplied directory must exist"},
    {"requirement_id": "real-review-return-provenance", "status": status(real_review_return_provenance_asserted), "required_value": "real-external-review-return", "actual_value": return_provenance, "reason": "fixture or unspecified provenance is rejected"},
    {"requirement_id": "replay-entrypoint-admitted", "status": status(replay_entrypoint_admitted), "required_value": "1", "actual_value": str(replay_entrypoint_admitted), "reason": "requires real dir and real provenance"},
    {"requirement_id": "external-review-return", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "entrypoint package does not count as returned evidence"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
    {"requirement_id": "repo-checkpoint-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "metadata-only entrypoint"},
]
write_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

readme = entrypoint_dir / "REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.md"
readme.write_text(
    "\n".join(
        [
            "# v61fo Real Manifest External Review Return Replay Entrypoint",
            "",
            "This package provides a guarded operator entrypoint for real review-return roots.",
            "It is fail-closed: no real directory and explicit real provenance means no replay.",
            "",
            f"- review_return_dir_supplied={return_dir_supplied}",
            f"- review_return_dir_exists={return_dir_exists}",
            f"- real_review_return_provenance_asserted={real_review_return_provenance_asserted}",
            f"- replay_entrypoint_admitted={replay_entrypoint_admitted}",
            "- external_review_return_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fo defines a fail-closed one-command replay entrypoint for real review-return roots.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fo alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61fo-post-fn-real-manifest-external-review-return-replay-entrypoint",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "replay_entrypoint_ready": replay_entrypoint_ready,
    "replay_entrypoint_admitted": replay_entrypoint_admitted,
    "review_return_dir_supplied": return_dir_supplied,
    "review_return_dir_exists": return_dir_exists,
    "real_review_return_provenance_asserted": real_review_return_provenance_asserted,
    "fixture_return_provenance": fixture_return_provenance,
    "external_review_return_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(entrypoint_dir / "REPLAY_ENTRYPOINT_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = entrypoint_dir / "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import json",
            "from pathlib import Path",
            "root = Path('.')",
            "manifest = json.loads((root / 'REPLAY_ENTRYPOINT_MANIFEST.json').read_text(encoding='utf-8'))",
            "if manifest['replay_entrypoint_ready'] != 1:",
            "    raise SystemExit('entrypoint should be ready')",
            "if manifest['external_review_return_ready'] != 0:",
            "    raise SystemExit('entrypoint package must not accept external review')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('entrypoint package must not claim actual generation')",
            "if manifest['checkpoint_payload_bytes_committed_to_repo'] != 0:",
            "    raise SystemExit('repo checkpoint payload must remain zero')",
            "if not (root / 'RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh').is_file():",
            "    raise SystemExit('missing guarded entrypoint script')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

file_rows = []
for path in sorted(entrypoint_dir.rglob("*")):
    if path.is_file():
        rel = str(path.relative_to(entrypoint_dir))
        file_rows.append(
            {
                "entrypoint_file": rel,
                "size_bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only_file": "1",
                "payload_like_file": "1" if path.suffix in {".safetensors", ".bin", ".pt"} else "0",
            }
        )
write_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_file_rows.csv", list(file_rows[0].keys()), file_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
summary = {
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": "1",
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": v61fn["v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready"],
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": v61fm["v61fm_post_fl_real_manifest_external_review_return_work_order_ready"],
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": v61fh["v61fh_post_fg_real_manifest_external_review_return_intake_ready"],
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": v61fi["v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready"],
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": v61fl["v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready"],
    "review_return_dir_supplied": str(return_dir_supplied),
    "review_return_dir_exists": str(return_dir_exists),
    "review_return_provenance": return_provenance,
    "real_review_return_provenance_asserted": str(real_review_return_provenance_asserted),
    "fixture_return_provenance": str(fixture_return_provenance),
    "replay_entrypoint_ready": str(replay_entrypoint_ready),
    "replay_entrypoint_admitted": str(replay_entrypoint_admitted),
    "required_env_rows": str(len([row for row in env_rows if row["required"] == "1"])),
    "entrypoint_env_rows": str(len(env_rows)),
    "entrypoint_file_rows": str(len(file_rows)),
    "metadata_only_entrypoint_file_rows": str(sum(row["metadata_only_file"] == "1" for row in file_rows)),
    "payload_like_entrypoint_file_rows": str(sum(row["payload_like_file"] == "1" for row in file_rows)),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(ready_stage_rows),
    "blocked_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "blocked_command_rows": str(len(command_rows) - ready_command_rows),
    "external_review_return_ready": "0",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fo": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_metric_rows.csv", list(summary.keys()), [summary])
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["requirement_id"], "status": row["status"], "reason": row["reason"]}
    for row in requirement_rows
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FO_POST_FN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_ENTRYPOINT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fo Post-v61fn Real Manifest External Review Return Replay Entrypoint Boundary",
            "",
            f"- replay_entrypoint_ready={summary['replay_entrypoint_ready']}",
            f"- review_return_dir_supplied={summary['review_return_dir_supplied']}",
            f"- review_return_dir_exists={summary['review_return_dir_exists']}",
            f"- real_review_return_provenance_asserted={summary['real_review_return_provenance_asserted']}",
            f"- replay_entrypoint_admitted={summary['replay_entrypoint_admitted']}",
            f"- entrypoint_file_rows={summary['entrypoint_file_rows']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fo provides a fail-closed one-command replay entrypoint for real review-return roots.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fo alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
