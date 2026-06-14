#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hi_post_hh_real_subset_execution_readiness_audit"
RUN_ID="${V61HI_RUN_ID:-readiness_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HI_WORK_ROOT:-${V61HH_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}"
PUBLISH_AUDIT="${V61HI_PUBLISH_AUDIT:-0}"

if [[ "${V61HI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hi_post_hh_real_subset_execution_readiness_audit_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hh_post_hg_dual_replay_authority_ack_publisher.sh" >/dev/null
V61HG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher.sh" >/dev/null
V61GO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null
V61GP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$WORK_ROOT" "$PUBLISH_AUDIT" <<'PY'
import csv
import hashlib
import json
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
work_root_raw = sys.argv[6].strip()
publish_requested = int((sys.argv[7].strip() or "0") == "1")
results = root / "results"
prefix = "v61hi_post_hh_real_subset_execution_readiness_audit"
package_dir = run_dir / "real_subset_execution_readiness_audit"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HH_PREFIX = "v61hh_post_hg_dual_replay_authority_ack_publisher"
HG_PREFIX = "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher"
GO_PREFIX = "v61go_post_gn_first_real_slice_operator_input_materializer"
GP_PREFIX = "v61gp_post_go_first_real_slice_dual_replay_executor"
FINAL_OPERATOR_INPUT_RELS = [
    "v53/aggregate_review_return/human_review_rows.csv",
    "v53/aggregate_review_return/adjudication_rows.csv",
    "v53/aggregate_review_return/reviewer_identity_rows.csv",
    "v53/aggregate_review_return/reviewer_conflict_rows.csv",
    "v53/aggregate_review_return/acceptance_summary.json",
    "v53/operator_attestation/reviewer_authority_statement.txt",
    "v61/generation_result_return/real_model_generation_answer_rows.csv",
    "v61/generation_result_return/real_model_generation_citation_rows.csv",
    "v61/generation_result_return/real_model_generation_abstain_fallback_rows.csv",
    "v61/generation_result_return/real_model_generation_latency_rows.csv",
    "v61/generation_result_return/real_model_generation_acceptance_summary.json",
    "v61/review_return_provenance/operator_attestation/generation_operator_authority_statement.txt",
    "OPERATOR_INPUT_RECEIPT.json",
    "operator_content_witness/review_comment.txt",
    "operator_content_witness/adjudication_reason.txt",
    "operator_content_witness/credential_statement.txt",
    "operator_content_witness/conflict_statement.txt",
    "operator_content_witness/answer_text.txt",
    "operator_content_witness/run_transcript.txt",
    "operator_content_witness/source_file.txt",
]


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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


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
    "v61hh_summary": results / f"{HH_PREFIX}_summary.csv",
    "v61hh_decision": results / f"{HH_PREFIX}_decision.csv",
    "v61hg_summary": results / f"{HG_PREFIX}_summary.csv",
    "v61hg_decision": results / f"{HG_PREFIX}_decision.csv",
    "v61go_summary": results / f"{GO_PREFIX}_summary.csv",
    "v61go_decision": results / f"{GO_PREFIX}_decision.csv",
    "v61gp_summary": results / f"{GP_PREFIX}_summary.csv",
    "v61gp_decision": results / f"{GP_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hi source {label}: {path}")
source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61hh"):
        folder = "source_v61hh"
    elif label.startswith("v61hg"):
        folder = "source_v61hg"
    elif label.startswith("v61go"):
        folder = "source_v61go"
    else:
        folder = "source_v61gp"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "real_subset_execution_readiness_source_rows.csv", list(source_rows[0].keys()), source_rows)

hh = read_csv(source_paths["v61hh_summary"])[0]
hg = read_csv(source_paths["v61hg_summary"])[0]
go = read_csv(source_paths["v61go_summary"])[0]
gp = read_csv(source_paths["v61gp_summary"])[0]
if hh.get("v61hh_post_hg_dual_replay_authority_ack_publisher_ready") != "1":
    raise SystemExit("v61hi requires v61hh ready")
if hg.get("v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready") != "1":
    raise SystemExit("v61hi requires v61hg ready")
if go.get("v61go_post_gn_first_real_slice_operator_input_materializer_ready") != "1":
    raise SystemExit("v61hi requires v61go ready")
if gp.get("v61gp_post_go_first_real_slice_dual_replay_executor_ready") != "1":
    raise SystemExit("v61hi requires v61gp ready")

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_path = form_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json" if form_dir else None
form_validator = form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py" if form_dir else None
ack_path = form_dir / "DUAL_REPLAY_AUTHORITY_ACK.json" if form_dir else None
ack_validator = form_dir / "VALIDATE_DUAL_REPLAY_AUTHORITY_ACK.py" if form_dir else None
operator_handoff = work_root / "RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh" if work_root else None
ack_wrapper = work_root / "RUN_OPERATOR_REPLAY_WITH_AUTHORITY_ACK_FILE.sh" if work_root else None
operator_root = work_root / "operator_partial_return" / "operator_input_root" if work_root else None
output_root = work_root / "operator_partial_return" / "output_root" if work_root else None

form_supplied = int(form_path is not None and form_path.is_file())
form_validation_ready = 0
form_validation_exit_code = "not-run"
form_validation_report = run_dir / "filled_form.validation_rows.csv"
if form_supplied and form_validator is not None and form_validator.is_file():
    proc = subprocess.run(
        [str(form_validator), str(form_path), str(form_validation_report)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    form_validation_exit_code = str(proc.returncode)
    (run_dir / "filled_form.validation_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "filled_form.validation_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    form_validation_ready = int(proc.returncode == 0)
else:
    form_validation_report.write_text("check_id,status,evidence\nfilled-form,blocked,missing\n", encoding="utf-8")
    (run_dir / "filled_form.validation_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "filled_form.validation_stderr.txt").write_text("filled-form-not-supplied-or-validator-missing\n", encoding="utf-8")

ack_supplied = int(ack_path is not None and ack_path.is_file())
ack_validation_ready = 0
ack_validation_exit_code = "not-run"
ack_validation_report = run_dir / "dual_replay_authority_ack.validation_rows.csv"
if ack_supplied and form_supplied and ack_validator is not None and ack_validator.is_file():
    proc = subprocess.run(
        [str(ack_validator), str(ack_path), str(form_path), str(ack_validation_report)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    ack_validation_exit_code = str(proc.returncode)
    (run_dir / "dual_replay_authority_ack.validation_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "dual_replay_authority_ack.validation_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    ack_validation_ready = int(proc.returncode == 0)
else:
    ack_validation_report.write_text("check_id,status,evidence\nauthority-ack,blocked,missing\n", encoding="utf-8")
    (run_dir / "dual_replay_authority_ack.validation_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "dual_replay_authority_ack.validation_stderr.txt").write_text("authority-ack-not-supplied-or-validator-missing\n", encoding="utf-8")

operator_file_rows = []
for rel in FINAL_OPERATOR_INPUT_RELS:
    path = operator_root / rel if operator_root else None
    exists = int(path is not None and path.is_file())
    operator_file_rows.append({
        "relative_path": rel,
        "exists": str(exists),
        "bytes": str(path.stat().st_size) if exists else "0",
        "sha256": sha256(path) if exists else "",
    })
write_csv(run_dir / "real_subset_operator_input_file_rows.csv", list(operator_file_rows[0].keys()), operator_file_rows)
operator_input_file_rows = len(operator_file_rows)
operator_input_present_rows = sum(row["exists"] == "1" for row in operator_file_rows)
operator_input_files_ready = int(operator_input_present_rows == operator_input_file_rows and operator_input_file_rows > 0)

output_root_exists = int(output_root is not None and output_root.is_dir())
output_v53_marker = output_root / "v53" / "REAL_EXTERNAL_RETURN_PROVENANCE.json" if output_root else None
output_v61_marker = output_root / "v61" / "review_return_provenance" / "REAL_REVIEW_RETURN_PROVENANCE.json" if output_root else None
output_v53_root_ready = int(output_v53_marker is not None and output_v53_marker.is_file())
output_v61_root_ready = int(output_v61_marker is not None and output_v61_marker.is_file())
dual_output_roots_ready = int(output_v53_root_ready and output_v61_root_ready)
output_rows = [
    {"root_id": "operator-input-root", "path": str(operator_root) if operator_root else "", "exists": str(int(operator_root is not None and operator_root.is_dir())), "ready": str(operator_input_files_ready)},
    {"root_id": "dual-output-root", "path": str(output_root) if output_root else "", "exists": str(output_root_exists), "ready": str(dual_output_roots_ready)},
    {"root_id": "v53-output-root", "path": str(output_root / "v53") if output_root else "", "exists": str(int(output_root is not None and (output_root / "v53").is_dir())), "ready": str(output_v53_root_ready)},
    {"root_id": "v61-output-root", "path": str(output_root / "v61") if output_root else "", "exists": str(int(output_root is not None and (output_root / "v61").is_dir())), "ready": str(output_v61_root_ready)},
]
write_csv(run_dir / "real_subset_execution_root_rows.csv", list(output_rows[0].keys()), output_rows)

gp_real_external_review_rows = as_int(gp, "real_external_review_return_rows")
gp_real_generation_result_artifacts = as_int(gp, "real_generation_result_artifacts")
gp_row_acceptance_ready = as_int(gp, "row_acceptance_ready")
gp_real_return_replay_admission_ready = as_int(gp, "real_return_replay_admission_ready")
gp_generation_acceptance_closure_ready = as_int(gp, "generation_acceptance_closure_ready")
gp_actual_model_generation_ready = as_int(gp, "actual_model_generation_ready")

if not form_validation_ready:
    next_action = "fill-and-validate-first-real-slice-external-return-form"
elif not ack_validation_ready:
    next_action = "fill-and-validate-dual-replay-authority-ack"
elif not operator_input_files_ready:
    next_action = "run-filled-form-to-operator-input-no-replay"
elif not dual_output_roots_ready:
    next_action = "run-operator-replay-with-authority-ack-file"
elif not gp_real_return_replay_admission_ready:
    next_action = "rerun-v61gp-and-check-dual-replay-opened"
else:
    next_action = "subset-real-return-replay-opened"

readiness_rows = [
    {"item_id": "01-work-root", "ready": str(int(work_root_exists and work_root_outside_repo)), "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"item_id": "02-filled-form-supplied", "ready": str(form_supplied), "evidence": str(form_path) if form_path else ""},
    {"item_id": "03-filled-form-validation", "ready": str(form_validation_ready), "evidence": f"exit={form_validation_exit_code}; report={form_validation_report}"},
    {"item_id": "04-authority-ack-supplied", "ready": str(ack_supplied), "evidence": str(ack_path) if ack_path else ""},
    {"item_id": "05-authority-ack-validation", "ready": str(ack_validation_ready), "evidence": f"exit={ack_validation_exit_code}; report={ack_validation_report}"},
    {"item_id": "06-operator-handoff-runner", "ready": str(int(operator_handoff is not None and operator_handoff.is_file())), "evidence": str(operator_handoff) if operator_handoff else ""},
    {"item_id": "07-authority-ack-wrapper", "ready": str(int(ack_wrapper is not None and ack_wrapper.is_file())), "evidence": str(ack_wrapper) if ack_wrapper else ""},
    {"item_id": "08-operator-input-root-files", "ready": str(operator_input_files_ready), "evidence": f"present={operator_input_present_rows}/{operator_input_file_rows}"},
    {"item_id": "09-dual-output-roots", "ready": str(dual_output_roots_ready), "evidence": f"v53={output_v53_root_ready}; v61={output_v61_root_ready}"},
    {"item_id": "10-v61gp-real-return-replay-admission", "ready": str(gp_real_return_replay_admission_ready), "evidence": f"real_external_review_return_rows={gp_real_external_review_rows}; real_generation_result_artifacts={gp_real_generation_result_artifacts}"},
    {"item_id": "11-v61gp-generation-acceptance-closure", "ready": str(gp_generation_acceptance_closure_ready), "evidence": f"generation_acceptance_closure_ready={gp_generation_acceptance_closure_ready}"},
    {"item_id": "12-actual-model-generation", "ready": str(gp_actual_model_generation_ready), "evidence": f"actual_model_generation_ready={gp_actual_model_generation_ready}"},
]
write_csv(run_dir / "real_subset_execution_readiness_rows.csv", list(readiness_rows[0].keys()), readiness_rows)

publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo)
published = 0
publish_errors = []
published_rows = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
elif publish_admitted:
    runner = work_root / "RUN_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh"
    runner.write_text(
        "\n".join([
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            "WORK_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "V61HI_WORK_ROOT=\"$WORK_ROOT\" V61HI_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61hi_post_hh_real_subset_execution_readiness_audit.sh\"",
            "",
        ]),
        encoding="utf-8",
    )
    runner.chmod(0o755)
    published = 1
    published_rows.append({"path": str(runner), "bytes": str(runner.stat().st_size), "sha256": sha256(runner), "metadata_only": "1"})
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1"})
write_csv(run_dir / "real_subset_execution_readiness_published_rows.csv", list(published_rows[0].keys()), published_rows)

for rel, src in [
    ("REAL_SUBSET_EXECUTION_READINESS_ROWS.csv", run_dir / "real_subset_execution_readiness_rows.csv"),
    ("REAL_SUBSET_EXECUTION_ROOT_ROWS.csv", run_dir / "real_subset_execution_root_rows.csv"),
    ("REAL_SUBSET_OPERATOR_INPUT_FILE_ROWS.csv", run_dir / "real_subset_operator_input_file_rows.csv"),
    ("FILLED_FORM_VALIDATION_ROWS.csv", form_validation_report),
    ("DUAL_REPLAY_AUTHORITY_ACK_VALIDATION_ROWS.csv", ack_validation_report),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/REAL_SUBSET_EXECUTION_READINESS_MANIFEST.json\"",
        "test -s \"$DIR/REAL_SUBSET_EXECUTION_READINESS_ROWS.csv\"",
        "test -s \"$DIR/REAL_SUBSET_EXECUTION_ROOT_ROWS.csv\"",
        "test -s \"$DIR/REAL_SUBSET_OPERATOR_INPUT_FILE_ROWS.csv\"",
        "test -s \"$DIR/FILLED_FORM_VALIDATION_ROWS.csv\"",
        "test -s \"$DIR/DUAL_REPLAY_AUTHORITY_ACK_VALIDATION_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61hi package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_REAL_SUBSET_EXECUTION_READINESS_AUDIT.sh").chmod(0o755)

(package_dir / "NEXT_REAL_SUBSET_ACTION.txt").write_text(next_action + "\n", encoding="utf-8")

summary = {
    "v61hi_post_hh_real_subset_execution_readiness_audit_ready": 1,
    "v61hh_post_hg_dual_replay_authority_ack_publisher_ready": 1,
    "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready": 1,
    "v61go_post_gn_first_real_slice_operator_input_materializer_ready": 1,
    "v61gp_post_go_first_real_slice_dual_replay_executor_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "filled_form_supplied": form_supplied,
    "filled_form_validation_ready": form_validation_ready,
    "filled_form_validation_exit_code": form_validation_exit_code,
    "authority_ack_supplied": ack_supplied,
    "authority_ack_validation_ready": ack_validation_ready,
    "authority_ack_validation_exit_code": ack_validation_exit_code,
    "operator_handoff_runner_exists": int(operator_handoff is not None and operator_handoff.is_file()),
    "authority_ack_wrapper_exists": int(ack_wrapper is not None and ack_wrapper.is_file()),
    "operator_input_file_rows": operator_input_file_rows,
    "operator_input_present_rows": operator_input_present_rows,
    "operator_input_files_ready": operator_input_files_ready,
    "dual_output_roots_ready": dual_output_roots_ready,
    "next_real_subset_action": next_action,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "readiness_audit_runner_published": published,
    "real_external_review_return_rows": gp_real_external_review_rows,
    "real_adjudication_rows": as_int(gp, "real_adjudication_rows"),
    "slice_answer_review_accepted_rows": as_int(gp, "slice_answer_review_accepted_rows"),
    "real_generation_result_artifacts": gp_real_generation_result_artifacts,
    "accepted_generation_result_artifacts": as_int(gp, "accepted_generation_result_artifacts"),
    "generation_result_accepted_rows": as_int(gp, "generation_result_accepted_rows"),
    "row_acceptance_ready": gp_row_acceptance_ready,
    "real_return_replay_admission_ready": gp_real_return_replay_admission_ready,
    "generation_acceptance_closure_ready": gp_generation_acceptance_closure_ready,
    "actual_model_generation_ready": gp_actual_model_generation_ready,
    "ready_readiness_rows": sum(row["ready"] == "1" for row in readiness_rows),
    "readiness_rows": len(readiness_rows),
    "source_file_rows": len(source_rows),
    "published_file_rows": 0 if not published else len(published_rows),
    "checkpoint_payload_bytes_downloaded_by_v61hi": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "payload_like_package_file_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61hh-ready", "status": "pass", "evidence": "v61hh ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "filled-form-validation", "status": "pass" if form_validation_ready else "blocked", "evidence": f"exit={form_validation_exit_code}"},
    {"gate": "authority-ack-validation", "status": "pass" if ack_validation_ready else "blocked", "evidence": f"exit={ack_validation_exit_code}"},
    {"gate": "operator-input-files", "status": "pass" if operator_input_files_ready else "blocked", "evidence": f"present={operator_input_present_rows}/{operator_input_file_rows}"},
    {"gate": "dual-output-roots", "status": "pass" if dual_output_roots_ready else "blocked", "evidence": f"v53={output_v53_root_ready}; v61={output_v61_root_ready}"},
    {"gate": "real-return-replay-admission", "status": "pass" if gp_real_return_replay_admission_ready else "blocked", "evidence": f"real_return_replay_admission_ready={gp_real_return_replay_admission_ready}"},
    {"gate": "generation-acceptance-closure", "status": "pass" if gp_generation_acceptance_closure_ready else "blocked", "evidence": f"generation_acceptance_closure_ready={gp_generation_acceptance_closure_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={gp_actual_model_generation_ready}"},
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
    "next_real_subset_action": next_action,
    "executes_dual_replay": 0,
    "accepted_as_real_evidence": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "REAL_SUBSET_EXECUTION_READINESS_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HI_POST_HH_REAL_SUBSET_EXECUTION_READINESS_AUDIT_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HI Post-HH Real Subset Execution Readiness Audit",
        "",
        "- v61hi_post_hh_real_subset_execution_readiness_audit_ready=1",
        f"- filled_form_validation_ready={form_validation_ready}",
        f"- authority_ack_validation_ready={ack_validation_ready}",
        f"- operator_input_files_ready={operator_input_files_ready}",
        f"- dual_output_roots_ready={dual_output_roots_ready}",
        f"- next_real_subset_action={next_action}",
        f"- real_external_review_return_rows={gp_real_external_review_rows}",
        f"- real_generation_result_artifacts={gp_real_generation_result_artifacts}",
        f"- real_return_replay_admission_ready={gp_real_return_replay_admission_ready}",
        f"- generation_acceptance_closure_ready={gp_generation_acceptance_closure_ready}",
        f"- actual_model_generation_ready={gp_actual_model_generation_ready}",
        "",
        "This audit does not create or accept evidence; it reports the next concrete blocker for the subset real-return path.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path), "metadata_only": "1", "payload_like": "0"})
write_csv(run_dir / "real_subset_execution_readiness_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hi_post_hh_real_subset_execution_readiness_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
