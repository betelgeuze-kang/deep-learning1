#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ht_post_hs_first_real_slice_env_repair_packet"
RUN_ID="${V61HT_RUN_ID:-env_repair_packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HT_WORK_ROOT:-}"
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HS_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HR_WORK_ROOT:-}"; fi
if [[ -z "$WORK_ROOT" ]]; then WORK_ROOT="${V61HM_WORK_ROOT:-}"; fi
PUBLISH_REPAIR="${V61HT_PUBLISH_REPAIR:-0}"

if [[ "${V61HT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ht_post_hs_first_real_slice_env_repair_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ROOT" "$PUBLISH_REPAIR" <<'V61HT_PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
work_root_raw = sys.argv[5].strip()
publish_requested = int((sys.argv[6].strip() or "0") == "1")
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
package_dir = run_dir / "first_real_slice_env_repair_packet"
package_dir.mkdir(parents=True, exist_ok=True)
prefix = "v61ht_post_hs_first_real_slice_env_repair_packet"

REQUIREMENTS = {
    "V61HO_EXTERNAL_RETURN_ATTESTATION": ("external return attestation", "replace with final real external return attestation, at least 40 chars"),
    "V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT": ("operator input authority", "replace with final operator authority to assemble the return into inputs, at least 40 chars"),
    "V61HO_REVIEWER_ID": ("reviewer identity", "replace with real reviewer identity, at least 3 chars"),
    "V61HO_ADJUDICATOR_ID": ("adjudicator identity", "replace with real adjudicator identity, at least 3 chars"),
    "V61HO_REVIEW_COMMENT_TEXT": ("review comment", "replace with real human/source review comment, at least 40 chars"),
    "V61HO_ADJUDICATION_REASON_TEXT": ("adjudication reason", "replace with real adjudication reason, at least 40 chars"),
    "V61HO_CREDENTIAL_STATEMENT_TEXT": ("credential statement", "replace with real reviewer credential statement, at least 40 chars"),
    "V61HO_CONFLICT_STATEMENT_TEXT": ("conflict statement", "replace with real conflict disclosure, at least 40 chars"),
    "V61HO_REVIEWER_AUTHORITY_STATEMENT": ("reviewer authority", "replace with final reviewer authority statement, at least 40 chars"),
    "V61HO_GENERATION_ID": ("generation identifier", "replace with real generation/result identifier, at least 3 chars"),
    "V61HO_CITATION_ID": ("citation identifier", "replace with real citation evidence identifier, at least 3 chars"),
    "V61HO_LATENCY_ROW_ID": ("latency identifier", "replace with real latency row identifier, at least 3 chars"),
    "V61HO_CHECKPOINT_ROOT": ("checkpoint root", "must point to the real 59-shard checkpoint root"),
    "V61HO_ANSWER_TEXT": ("answer text", "replace with real source-bound answer text, at least 40 chars"),
    "V61HO_RUN_TRANSCRIPT_TEXT": ("run transcript", "replace with real run transcript text, at least 40 chars"),
    "V61HO_PROMPT_TOKENS": ("prompt tokens", "replace with positive measured prompt token count"),
    "V61HO_OUTPUT_TOKENS": ("output tokens", "replace with positive measured output token count"),
    "V61HO_PREFILL_MS": ("prefill latency", "replace with positive measured prefill milliseconds"),
    "V61HO_DECODE_MS": ("decode latency", "replace with positive measured decode milliseconds"),
    "V61HO_TOTAL_MS": ("total latency", "replace with positive measured total milliseconds"),
    "V61HO_TOKENS_PER_SECOND": ("throughput", "replace with positive measured tokens per second"),
    "V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT": ("generation operator authority", "replace with final generation operator authority statement, at least 40 chars"),
    "V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT": ("dual replay authority", "replace with final external replay authority statement, at least 80 chars"),
    "V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN": ("operator attestation boolean", "set to true only after the external return values are real and final"),
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
preflight_report = form_dir / "FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv" if form_dir else None
env_file = form_dir / "FIRST_REAL_SLICE_VALUES.env" if form_dir else None
values_file = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json" if form_dir else None
filled_form = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
ack_file = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None

preflight_rows = read_csv(preflight_report) if preflight_report is not None and preflight_report.is_file() else []
repair_rows = []
for row in preflight_rows:
    env_name = row.get("env_name", "")
    status = row.get("status", "")
    if status == "pass":
        continue
    label, action = REQUIREMENTS.get(env_name, ("unknown", "inspect the preflight evidence and replace with a valid real value"))
    repair_rows.append({
        "env_name": env_name,
        "field_path": row.get("field_path", ""),
        "repair_label": label,
        "current_status": status,
        "evidence": row.get("evidence", ""),
        "required_action": action,
        "safe_to_publish": "1",
        "contains_value": "0",
    })
if not preflight_rows:
    repair_rows.append({
        "env_name": "FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv",
        "field_path": "preflight-report",
        "repair_label": "preflight report",
        "current_status": "blocked",
        "evidence": "preflight-report-missing",
        "required_action": "run RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh after creating the env workfile",
        "safe_to_publish": "1",
        "contains_value": "0",
    })
elif not repair_rows:
    repair_rows.append({
        "env_name": "",
        "field_path": "",
        "repair_label": "none",
        "current_status": "pass",
        "evidence": "preflight-ready",
        "required_action": "run env-file capture handoff",
        "safe_to_publish": "1",
        "contains_value": "0",
    })

repair_csv = run_dir / "first_real_slice_env_repair_todo_rows.csv"
write_csv(repair_csv, ["env_name", "field_path", "repair_label", "current_status", "evidence", "required_action", "safe_to_publish", "contains_value"], repair_rows)

blocked_rows = sum(1 for row in repair_rows if row["current_status"] != "pass")
pass_rows = sum(1 for row in preflight_rows if row.get("status") == "pass")
env_file_exists = int(env_file is not None and env_file.is_file())
values_file_exists = int(values_file is not None and values_file.is_file())
filled_form_exists = int(filled_form is not None and filled_form.is_file())
authority_ack_exists = int(ack_file is not None and ack_file.is_file())

commands_md = "\n".join([
    "# First Real Slice Env Repair",
    "",
    "This packet is redacted. It lists env variable names, field paths, status, and required actions only.",
    "It does not include the current env values.",
    "",
    "## Recommended Loop",
    "",
    "```bash",
    "$EDITOR external_return_form/FIRST_REAL_SLICE_VALUES.env",
    "external_return_form/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh",
    "./RUN_FIRST_REAL_SLICE_ENV_FILE_TO_READINESS_NO_REPLAY.sh",
    "```",
    "",
    "Do not enable subset dual replay until readiness has passed.",
    "",
])
commands_path = run_dir / "FIRST_REAL_SLICE_ENV_REPAIR_NEXT_COMMANDS.md"
commands_path.write_text(commands_md, encoding="utf-8")

published_rows = []
publish_errors = []
if publish_requested:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if form_dir is None or not form_dir.is_dir():
        publish_errors.append("external-return-form-dir-missing")
    if not publish_errors:
        destinations = [
            (repair_csv, form_dir / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv"),
            (commands_path, form_dir / "FIRST_REAL_SLICE_VALUES_ENV_REPAIR_NEXT_COMMANDS.md"),
        ]
        for src, dst in destinations:
            dst.write_bytes(src.read_bytes())
            published_rows.append({
                "path": str(dst),
                "bytes": str(dst.stat().st_size),
                "sha256": sha256(dst),
                "metadata_only": "1",
                "contains_value": "0",
                "executes_dual_replay": "0",
            })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "contains_value": "0", "executes_dual_replay": "0"})
write_csv(run_dir / "first_real_slice_env_repair_published_rows.csv", list(published_rows[0].keys()), published_rows)

if not work_root_supplied:
    next_action = "initialize-or-select-first-real-slice-workspace"
elif blocked_rows:
    next_action = "repair-first-real-slice-values-env-file"
elif not values_file_exists:
    next_action = "run-env-file-capture-handoff"
elif not filled_form_exists:
    next_action = "materialize-first-real-slice-filled-form"
elif not authority_ack_exists:
    next_action = "build-dual-replay-authority-ack"
else:
    next_action = "run-readiness-audit-before-explicit-subset-dual-replay"

gate_rows = [
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"supplied={work_root_supplied}; exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "env-file", "status": "pass" if env_file_exists else "blocked", "evidence": str(env_file) if env_file_exists else "missing"},
    {"gate": "preflight-report", "status": "pass" if preflight_rows else "blocked", "evidence": str(preflight_report) if preflight_rows else "missing"},
    {"gate": "repair-list", "status": "pass" if blocked_rows == 0 and preflight_rows else "blocked", "evidence": f"blocked_rows={blocked_rows}; pass_rows={pass_rows}"},
    {"gate": "form-values-file", "status": "pass" if values_file_exists else "blocked", "evidence": str(values_file) if values_file_exists else "missing"},
    {"gate": "filled-form", "status": "pass" if filled_form_exists else "blocked", "evidence": str(filled_form) if filled_form_exists else "missing"},
    {"gate": "authority-ack", "status": "pass" if authority_ack_exists else "blocked", "evidence": str(ack_file) if authority_ack_exists else "missing"},
    {"gate": "subset-dual-replay", "status": "blocked", "evidence": "v61ht never sets V61HG_EXECUTE_DUAL_REPLAY=1"},
    {"gate": "row-acceptance", "status": "blocked", "evidence": "row_acceptance_ready=0 until accepted subset replay rows exist"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0; repair packet does not run generation"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, ["gate", "status", "evidence"], gate_rows)
write_csv(run_dir / f"{prefix}_decision.csv", ["gate", "status", "evidence"], gate_rows)

manifest = {
    "prefix": prefix,
    "run_id": run_dir.name,
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "work_root": str(work_root) if work_root else "",
    "publish_requested": publish_requested,
    "contains_values": False,
    "writes_values": False,
    "executes_dual_replay": False,
    "next_real_subset_action": next_action,
}
manifest_path = package_dir / "FIRST_REAL_SLICE_ENV_REPAIR_PACKET_MANIFEST.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
verify_path = package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_REPAIR_PACKET.sh"
verify_path.write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "PACKET_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "RUN_DIR=\"$(cd \"$PACKET_DIR/..\" && pwd)\"",
        "test -s \"$RUN_DIR/first_real_slice_env_repair_todo_rows.csv\"",
        "test -s \"$RUN_DIR/first_real_slice_env_repair_published_rows.csv\"",
        "test -s \"$PACKET_DIR/FIRST_REAL_SLICE_ENV_REPAIR_PACKET_MANIFEST.json\"",
        "echo \"first real slice env repair packet verified\"",
        "",
    ]),
    encoding="utf-8",
)
verify_path.chmod(0o755)
boundary_path = run_dir / "V61HT_POST_HS_FIRST_REAL_SLICE_ENV_REPAIR_PACKET_BOUNDARY.md"
boundary_path.write_text(
    "\n".join([
        "# v61ht Boundary",
        "",
        "This step publishes a redacted repair TODO derived from the preflight report.",
        "It never prints env values, writes values JSON, materializes forms, builds acks, runs replay, or creates model-generation evidence.",
        "",
        f"- next_real_subset_action: {next_action}",
        "- row_acceptance_ready: 0",
        "- generation_acceptance_closure_ready: 0",
        "- actual_model_generation_ready: 0",
        "- checkpoint_payload_bytes_committed_to_repo: 0",
        "",
    ]),
    encoding="utf-8",
)
packet_files = [
    repair_csv,
    commands_path,
    run_dir / "first_real_slice_env_repair_published_rows.csv",
    manifest_path,
    verify_path,
    boundary_path,
    run_dir / f"{prefix}_decision.csv",
]
sha_rows = [{"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": str(path.stat().st_size)} for path in packet_files]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    f"{prefix}_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "repair_packet_published": int(publish_requested and not publish_errors),
    "publish_error_count": len(publish_errors),
    "env_file_exists": env_file_exists,
    "preflight_report_exists": int(bool(preflight_rows)),
    "preflight_pass_rows": pass_rows,
    "repair_blocked_rows": blocked_rows,
    "repair_rows_contain_values": 0,
    "form_values_supplied": values_file_exists,
    "filled_form_exists": filled_form_exists,
    "authority_ack_exists": authority_ack_exists,
    "next_real_subset_action": next_action,
    "row_acceptance_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ht": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "packet_file_rows": len(packet_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

print(f"v61ht_post_hs_first_real_slice_env_repair_packet_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
V61HT_PY
