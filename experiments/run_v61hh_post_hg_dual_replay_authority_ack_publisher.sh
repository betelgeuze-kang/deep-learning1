#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hh_post_hg_dual_replay_authority_ack_publisher"
RUN_ID="${V61HH_RUN_ID:-authority_ack_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HH_WORK_ROOT:-${V61HG_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}"
PUBLISH_ACK="${V61HH_PUBLISH_ACK:-0}"
GV_RUN_ID="${V61HH_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61HH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hh_post_hg_dual_replay_authority_ack_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher.sh" >/dev/null
V61GP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null
V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_ACK" <<'PY'
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
prefix = "v61hh_post_hg_dual_replay_authority_ack_publisher"
package_dir = run_dir / "dual_replay_authority_ack_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HG_PREFIX = "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher"
GP_PREFIX = "v61gp_post_go_first_real_slice_dual_replay_executor"
GV_PREFIX = "v61gv_post_gu_first_real_slice_workspace_gap_audit"
ACK_PROTOCOL = "v61hh-dual-replay-authority-ack-v1"
EXPECTED_ACK = "operator-confirmed-real-external-review-and-generation-return"


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
    "v61hg_summary": results / f"{HG_PREFIX}_summary.csv",
    "v61hg_decision": results / f"{HG_PREFIX}_decision.csv",
    "v61gp_summary": results / f"{GP_PREFIX}_summary.csv",
    "v61gp_decision": results / f"{GP_PREFIX}_decision.csv",
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hh source {label}: {path}")
source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61hg"):
        folder = "source_v61hg"
    elif label.startswith("v61gp"):
        folder = "source_v61gp"
    else:
        folder = "source_v61gv"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "dual_replay_authority_ack_source_rows.csv", list(source_rows[0].keys()), source_rows)

hg = read_csv(source_paths["v61hg_summary"])[0]
gp = read_csv(source_paths["v61gp_summary"])[0]
gv = read_csv(source_paths["v61gv_summary"])[0]
if hg.get("v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready") != "1":
    raise SystemExit("v61hh requires v61hg ready")
if gp.get("v61gp_post_go_first_real_slice_dual_replay_executor_ready") != "1":
    raise SystemExit("v61hh requires v61gp ready")
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61hh requires v61gv ready")

ack_template = {
    "ack_protocol_version": ACK_PROTOCOL,
    "finalized": False,
    "authority_ack": "REPLACE_WITH_operator-confirmed-real-external-review-and-generation-return",
    "authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_REPLAY_AUTHORITY_STATEMENT_80_CHARS_MIN",
    "replay_scope": "first-real-slice-subset",
    "operator_attests_real_external_return": False,
    "filled_form_relative_path": "external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json",
    "filled_form_sha256": "sha256:REPLACE_WITH_FILLED_FORM_HASH",
    "operator_input_root_relative_path": "operator_partial_return/operator_input_root",
    "output_root_relative_path": "operator_partial_return/output_root",
}

validator_text = r'''#!/usr/bin/env python3
import csv
import hashlib
import json
import shlex
import sys
from pathlib import Path

PROTOCOL = "v61hh-dual-replay-authority-ack-v1"
EXPECTED_ACK = "operator-confirmed-real-external-review-and-generation-return"
NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)


def add(rows, check_id, status, evidence):
    rows.append({"check_id": check_id, "status": status, "evidence": evidence})


def main():
    args = list(sys.argv[1:])
    print_env = False
    if "--print-env" in args:
        print_env = True
        args.remove("--print-env")
    ack_path = Path(args[0]).expanduser().resolve() if len(args) > 0 else Path("DUAL_REPLAY_AUTHORITY_ACK.json").resolve()
    form_path = Path(args[1]).expanduser().resolve() if len(args) > 1 else ack_path.parent / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
    report_path = Path(args[2]).expanduser().resolve() if len(args) > 2 else ack_path.with_suffix(".validation_rows.csv")
    rows = []
    payload = {}
    if not ack_path.is_file():
        add(rows, "ack-file", "blocked", f"missing:{ack_path}")
    else:
        add(rows, "ack-file", "pass", str(ack_path))
        try:
            payload = json.loads(ack_path.read_text(encoding="utf-8"))
        except Exception as exc:
            add(rows, "ack-json", "blocked", f"json-unreadable:{exc}")
            payload = {}
        else:
            add(rows, "ack-json", "pass", "json-readable")
    if not isinstance(payload, dict):
        payload = {}
        add(rows, "ack-object", "blocked", "json-not-object")
    else:
        add(rows, "ack-object", "pass", "json-object")

    add(rows, "protocol", "pass" if payload.get("ack_protocol_version") == PROTOCOL else "blocked", str(payload.get("ack_protocol_version", "")))
    add(rows, "finalized", "pass" if payload.get("finalized") is True else "blocked", str(payload.get("finalized", "")))
    add(rows, "authority-ack", "pass" if payload.get("authority_ack") == EXPECTED_ACK else "blocked", str(payload.get("authority_ack", "")))
    statement = str(payload.get("authority_statement", ""))
    statement_ready = len(statement.strip()) >= 80 and not has_nonfinal(statement)
    add(rows, "authority-statement", "pass" if statement_ready else "blocked", f"len={len(statement.strip())}; nonfinal={has_nonfinal(statement)}")
    add(rows, "replay-scope", "pass" if payload.get("replay_scope") == "first-real-slice-subset" else "blocked", str(payload.get("replay_scope", "")))
    add(rows, "real-external-attestation", "pass" if payload.get("operator_attests_real_external_return") is True else "blocked", str(payload.get("operator_attests_real_external_return", "")))

    form_rel = payload.get("filled_form_relative_path", "")
    if form_rel and not Path(form_rel).is_absolute():
        form_path = ack_path.parent.parent / form_rel if ack_path.parent.name == "external_return_form" else ack_path.parent / form_rel
        form_path = form_path.resolve()
    form_exists = form_path.is_file()
    add(rows, "filled-form-file", "pass" if form_exists else "blocked", str(form_path))
    declared_form_sha = str(payload.get("filled_form_sha256", ""))
    actual_form_sha = sha256(form_path) if form_exists else ""
    add(rows, "filled-form-sha256", "pass" if declared_form_sha == actual_form_sha and actual_form_sha else "blocked", f"declared={declared_form_sha}; actual={actual_form_sha}")

    for key in ["operator_input_root_relative_path", "output_root_relative_path"]:
        value = str(payload.get(key, ""))
        ready = bool(value) and not Path(value).is_absolute() and not has_nonfinal(value)
        add(rows, key, "pass" if ready else "blocked", value)

    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["check_id", "status", "evidence"], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    blocked = [row for row in rows if row["status"] != "pass"]
    if blocked:
        if print_env:
            print(f"# authority ack blocked: {len(blocked)} checks", file=sys.stderr)
        raise SystemExit(f"dual-replay-authority-ack-blocked:{len(blocked)} checks; report={report_path}")
    if print_env:
        print("export V61HG_EXECUTE_DUAL_REPLAY=1")
        print("export V61HG_EXTERNAL_RETURN_AUTHORITY_ACK=" + shlex.quote(EXPECTED_ACK))
        print("export V61HG_EXTERNAL_RETURN_AUTHORITY_STATEMENT=" + shlex.quote(statement))
    else:
        print(f"dual replay authority ack ready: {ack_path}")
        print(f"report: {report_path}")


if __name__ == "__main__":
    main()
'''

wrapper_text = """#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACK_FILE="${V61HH_ACK_FILE:-$WORK_ROOT/external_return_form/DUAL_REPLAY_AUTHORITY_ACK.json}"
FORM_FILE="${V61HH_FORM_FILE:-$WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json}"
REPORT_FILE="${V61HH_REPORT_FILE:-$WORK_ROOT/external_return_form/dual_replay_authority_ack.validation_rows.csv}"
VALIDATOR="$WORK_ROOT/external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py"
if [[ ! -x "$VALIDATOR" ]]; then
  echo "dual replay authority ack validator missing: $VALIDATOR" >&2
  exit 2
fi
eval "$("$VALIDATOR" "$ACK_FILE" "$FORM_FILE" "$REPORT_FILE" --print-env)"
exec "$WORK_ROOT/RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh"
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_dir_exists = int(form_dir is not None and form_dir.is_dir())
operator_handoff_exists = int(work_root is not None and (work_root / "RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh").is_file())
publish_admitted = int(
    publish_requested
    and work_root_exists
    and work_root_outside_repo
    and form_dir_exists
    and operator_handoff_exists
)
published = 0
publish_errors = []
published_rows = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not form_dir_exists:
        publish_errors.append("external-return-form-dir-missing")
    if not operator_handoff_exists:
        publish_errors.append("operator-replay-handoff-missing")
elif publish_admitted:
    ack_template_path = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json.template"
    validator_path = form_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py"
    wrapper_path = work_root / "RUN_OPERATOR_REPLAY_WITH_AUTHORITY_ACK_FILE.sh"
    readme_path = form_dir / "DUAL_REPLAY_AUTHORITY_ACK_README.md"
    ack_template_path.write_text(json.dumps(ack_template, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    validator_path.write_text(validator_text, encoding="utf-8")
    validator_path.chmod(0o755)
    wrapper_path.write_text(wrapper_text, encoding="utf-8")
    wrapper_path.chmod(0o755)
    readme_path.write_text(
        "\n".join([
            "# Dual Replay Authority Ack",
            "",
            "Fill `DUAL_REPLAY_AUTHORITY_ACK.json` from the template only after the external return form is final.",
            "The ack binds the replay authority to the filled form sha256 and is validated before v61hg is armed.",
            "The wrapper runs `RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh` only after the ack validates.",
            "",
        ]),
        encoding="utf-8",
    )
    published = 1
    for path in [ack_template_path, validator_path, wrapper_path, readme_path]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "executes_dual_replay_by_default": "0",
        })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_dual_replay_by_default": "0"})
write_csv(run_dir / "dual_replay_authority_ack_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-v61hg-source", "status": "ready", "evidence": "v61hg ready"},
    {"stage_id": "02-v61gp-source", "status": "ready", "evidence": "v61gp ready"},
    {"stage_id": "03-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "04-external-return-form-dir", "status": "ready" if form_dir_exists else "blocked", "evidence": f"form_dir_exists={form_dir_exists}"},
    {"stage_id": "05-operator-replay-handoff", "status": "ready" if operator_handoff_exists else "blocked", "evidence": f"operator_handoff_exists={operator_handoff_exists}"},
    {"stage_id": "06-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "07-authority-ack-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "08-current-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', 'unknown')}"},
    {"stage_id": "09-dual-replay-runtime", "status": "blocked", "evidence": "requires filled DUAL_REPLAY_AUTHORITY_ACK.json"},
]
write_csv(run_dir / "dual_replay_authority_ack_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-validate-authority-ack", "ready_to_run_now": str(published), "command": "external_return_form/VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py external_return_form/DUAL_REPLAY_AUTHORITY_ACK.json external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "purpose": "validate durable authority ack before replay"},
    {"command_id": "02-run-replay-with-ack-file", "ready_to_run_now": "0", "command": "RUN_OPERATOR_REPLAY_WITH_AUTHORITY_ACK_FILE.sh", "purpose": "arm v61hg/v61gp only after ack file validation"},
]
write_csv(run_dir / "dual_replay_authority_ack_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("DUAL_REPLAY_AUTHORITY_ACK_PUBLISHED_ROWS.csv", run_dir / "dual_replay_authority_ack_published_rows.csv"),
    ("DUAL_REPLAY_AUTHORITY_ACK_STAGE_ROWS.csv", run_dir / "dual_replay_authority_ack_stage_rows.csv"),
    ("DUAL_REPLAY_AUTHORITY_ACK_COMMAND_ROWS.csv", run_dir / "dual_replay_authority_ack_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_MANIFEST.json\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_PUBLISHED_ROWS.csv\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_STAGE_ROWS.csv\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_COMMAND_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61hh package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER.sh").chmod(0o755)

summary = {
    "v61hh_post_hg_dual_replay_authority_ack_publisher_ready": 1,
    "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready": 1,
    "v61gp_post_go_first_real_slice_dual_replay_executor_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "form_dir_exists": form_dir_exists,
    "operator_replay_handoff_exists": operator_handoff_exists,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "authority_ack_published": published,
    "open_gap_rows": int(gv.get("open_gap_rows", "0") or "0"),
    "workspace_gap_preflight_ready": int(gv.get("workspace_gap_preflight_ready", "0") or "0"),
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "row_acceptance_ready": 0,
    "generation_execution_admission_ready": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hh": 0,
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
    {"gate": "source-v61hg-ready", "status": "pass", "evidence": "v61hg ready"},
    {"gate": "source-v61gp-ready", "status": "pass", "evidence": "v61gp ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "external-return-form-dir", "status": "pass" if form_dir_exists else "blocked", "evidence": f"form_dir_exists={form_dir_exists}"},
    {"gate": "operator-replay-handoff", "status": "pass" if operator_handoff_exists else "blocked", "evidence": f"operator_handoff_exists={operator_handoff_exists}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "authority-ack-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "dual-replay-runtime", "status": "blocked", "evidence": "requires filled DUAL_REPLAY_AUTHORITY_ACK.json"},
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
    "requires_ack_file": "external_return_form/DUAL_REPLAY_AUTHORITY_ACK.json",
    "accepted_as_real_evidence": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "DUAL_REPLAY_AUTHORITY_ACK_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HH_POST_HG_DUAL_REPLAY_AUTHORITY_ACK_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HH Post-HG Dual Replay Authority Ack Publisher",
        "",
        "- v61hh_post_hg_dual_replay_authority_ack_publisher_ready=1",
        f"- authority_ack_published={published}",
        f"- open_gap_rows={summary['open_gap_rows']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "Blocked wording: this publishes a durable authority ack file contract. It never executes replay by default.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path), "metadata_only": "1", "payload_like": "0"})
write_csv(run_dir / "dual_replay_authority_ack_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hh_post_hg_dual_replay_authority_ack_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
