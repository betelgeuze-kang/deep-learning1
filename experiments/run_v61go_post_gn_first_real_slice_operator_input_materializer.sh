#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61go_post_gn_first_real_slice_operator_input_materializer"
RUN_ID="${V61GO_RUN_ID:-materialize_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXECUTE_MATERIALIZE="${V61GO_EXECUTE_MATERIALIZE:-0}"

if [[ "${V61GO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61go_post_gn_first_real_slice_operator_input_materializer_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GN_RUN_ID="${RUN_ID}_csv" \
V61GN_EXECUTE_BUILD="$EXECUTE_MATERIALIZE" \
V61GN_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gn_post_gm_first_real_slice_minimal_csv_builder.sh" >/dev/null
V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$EXECUTE_MATERIALIZE" <<'PY'
import csv
import hashlib
import json
import os
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
execute_materialize = int((sys.argv[6].strip() or "0") == "1")
results = root / "results"
prefix = "v61go_post_gn_first_real_slice_operator_input_materializer"
package_dir = run_dir / "first_real_slice_operator_input_materializer"
package_dir.mkdir(parents=True, exist_ok=True)

GN_PREFIX = "v61gn_post_gm_first_real_slice_minimal_csv_builder"
GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
GJ_PREFIX = "v61gj_post_gi_operator_input_receiver"
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"
FINAL_RELS = [
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
]
WITNESS_RELS = [
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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


source_paths = {
    "v61gn_summary": results / GN_PREFIX / f"{run_id}_csv" / f"{GN_PREFIX}_summary.csv",
    "v61gn_decision": results / GN_PREFIX / f"{run_id}_csv" / f"{GN_PREFIX}_decision.csv",
    "v61gn_csv_status": results / GN_PREFIX / f"{run_id}_csv" / "first_real_slice_minimal_csv_status_rows.csv",
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_materializer": gi_scaffold / "MATERIALIZE_OPERATOR_INPUT_FROM_MINIMAL_SLICE.py",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61go source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    folder = "source_v61gn" if label.startswith("v61gn") else "source_v61gi"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_operator_input_materializer_source_rows.csv", list(source_rows[0].keys()), source_rows)

gn = read_csv(source_paths["v61gn_summary"])[0]
gi = read_csv(source_paths["v61gi_summary"])[0]
if gn.get("v61gn_post_gm_first_real_slice_minimal_csv_builder_ready") != "1":
    raise SystemExit("v61go requires v61gn ready")
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61go requires v61gi ready")

operator_root_raw = os.environ.get("V61GI_OPERATOR_INPUT_ROOT", "").strip()
operator_root = Path(operator_root_raw).expanduser().resolve() if operator_root_raw else None
operator_root_supplied = int(operator_root is not None)
operator_root_outside_repo = int(operator_root is not None and not is_inside(operator_root, root))
minimal_slice_csv_ready = as_int(gn, "minimal_slice_csv_ready")
materialize_admitted = int(minimal_slice_csv_ready and operator_root_supplied and operator_root_outside_repo)
materialize_executed = 0
materialize_exit_code = "not-run"
if execute_materialize and materialize_admitted:
    env = os.environ.copy()
    env.setdefault("V61GI_OPERATOR_INPUT_RECEIPT_SOURCE_CLASS", "real-external-review-and-generation-return")
    env["V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY"] = "operator-final-real-return"
    proc = subprocess.run(
        [str(source_paths["v61gi_materializer"])],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    materialize_executed = 1
    materialize_exit_code = str(proc.returncode)
    (run_dir / "operator_input_materialize_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "operator_input_materialize_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61go operator input materialization failed: {proc.returncode}")
else:
    (run_dir / "operator_input_materialize_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "operator_input_materialize_stderr.txt").write_text("materialize-not-executed\n", encoding="utf-8")

operator_root_exists = int(operator_root is not None and operator_root.is_dir())
final_file_rows = []
for rel in FINAL_RELS + ["OPERATOR_INPUT_RECEIPT.json"] + WITNESS_RELS:
    path = operator_root / rel if operator_root else None
    exists = int(path is not None and path.is_file())
    final_file_rows.append({
        "relative_path": rel,
        "exists": str(exists),
        "bytes": str(path.stat().st_size) if exists else "0",
        "sha256": sha256(path) if exists else "",
    })
write_csv(run_dir / "first_real_slice_operator_input_file_rows.csv", list(final_file_rows[0].keys()), final_file_rows)
final_operator_input_files_ready = int(all(row["exists"] == "1" for row in final_file_rows))

receiver_preflight_executed = 0
receiver_preflight_exit_code = "not-run"
v61gj_summary = {}
if materialize_executed and final_operator_input_files_ready:
    env = os.environ.copy()
    env.update({
        "V61GJ_RUN_ID": f"{run_id}_receiver_preflight",
        "V61GJ_OPERATOR_INPUT_ROOT": str(operator_root),
        "V61GJ_OUTPUT_ROOT": "",
        "V61GI_OUTPUT_ROOT": "",
        "V61GJ_EXECUTE_ASSEMBLY": "0",
        "V61GJ_REUSE_EXISTING": "0",
    })
    proc = subprocess.run(
        [str(root / "experiments" / "run_v61gj_post_gi_operator_input_receiver.sh")],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    receiver_preflight_executed = 1
    receiver_preflight_exit_code = str(proc.returncode)
    (run_dir / "v61gj_receiver_preflight_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "v61gj_receiver_preflight_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61go v61gj receiver preflight failed: {proc.returncode}")
    v61gj_summary_path = results / f"{GJ_PREFIX}_summary.csv"
    v61gj_summary = read_csv(v61gj_summary_path)[0]
    for label, path in {
        "v61gj_receiver_summary": results / f"{GJ_PREFIX}_summary.csv",
        "v61gj_receiver_decision": results / f"{GJ_PREFIX}_decision.csv",
        "v61gj_receiver_preflight_rows": results / GJ_PREFIX / f"{run_id}_receiver_preflight" / "operator_input_receiver_preflight_rows.csv",
        "v61gj_receiver_receipt_rows": results / GJ_PREFIX / f"{run_id}_receiver_preflight" / "operator_input_receiver_receipt_rows.csv",
    }.items():
        if not path.is_file():
            raise SystemExit(f"v61go missing receiver evidence {label}: {path}")
        source_rows.append(copy_source(label, path, "source_v61gj"))
    write_csv(run_dir / "first_real_slice_operator_input_materializer_source_rows.csv", list(source_rows[0].keys()), source_rows)
else:
    (run_dir / "v61gj_receiver_preflight_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "v61gj_receiver_preflight_stderr.txt").write_text("receiver-preflight-not-executed\n", encoding="utf-8")

operator_input_receipt_ready = as_int(v61gj_summary, "operator_input_receipt_ready")
operator_input_preflight_ready = as_int(v61gj_summary, "operator_input_preflight_ready")
ready_operator_input_rows = as_int(v61gj_summary, "ready_operator_input_rows")
assembly_admitted = as_int(v61gj_summary, "assembly_admitted")
assembly_executed = as_int(v61gj_summary, "assembly_executed")

stage_rows = [
    {"stage_id": "01-v61gn-source", "status": "ready", "evidence": "v61gn minimal CSV builder ready"},
    {"stage_id": "02-minimal-csv-ready", "status": "ready" if minimal_slice_csv_ready else "blocked", "evidence": f"minimal_slice_csv_ready={minimal_slice_csv_ready}"},
    {"stage_id": "03-materialize-admitted", "status": "ready" if materialize_admitted else "blocked", "evidence": f"materialize_admitted={materialize_admitted}; operator_root_outside_repo={operator_root_outside_repo}"},
    {"stage_id": "04-materialize-executed", "status": "ready" if materialize_executed else "blocked", "evidence": f"materialize_executed={materialize_executed}; exit_code={materialize_exit_code}"},
    {"stage_id": "05-final-operator-input-files", "status": "ready" if final_operator_input_files_ready else "blocked", "evidence": f"final_operator_input_files_ready={final_operator_input_files_ready}"},
    {"stage_id": "06-v61gj-preflight-only", "status": "ready" if operator_input_preflight_ready else "blocked", "evidence": f"operator_input_preflight_ready={operator_input_preflight_ready}; ready_rows={ready_operator_input_rows}"},
    {"stage_id": "07-assembly-and-replay", "status": "blocked", "evidence": f"assembly_admitted={assembly_admitted}; assembly_executed={assembly_executed}"},
    {"stage_id": "08-actual-generation-full-claim", "status": "blocked", "evidence": "operator input materialization does not prove actual generation"},
]
write_csv(run_dir / "first_real_slice_operator_input_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-materializer-package", "ready_to_run_now": "1", "command": "results/v61go_post_gn_first_real_slice_operator_input_materializer/materialize_001/first_real_slice_operator_input_materializer/VERIFY_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.sh", "purpose": "verify this materializer package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61go_post_gn_first_real_slice_operator_input_materializer/materialize_001/first_real_slice_operator_input_materializer/READY_NOW_COMMANDS.sh", "purpose": "show materialization and receiver preflight commands"},
    {"command_id": "03-run-materializer", "ready_to_run_now": str(materialize_admitted), "command": "V61GO_EXECUTE_MATERIALIZE=1 ./experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh", "purpose": "materialize final operator input root and run v61gj preflight-only"},
    {"command_id": "04-check-operator-input-ready", "ready_to_run_now": str(operator_input_preflight_ready), "command": "results/v61go_post_gn_first_real_slice_operator_input_materializer/materialize_001/first_real_slice_operator_input_materializer/CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py", "purpose": "assert final input root passes v61gj preflight without assembly"},
]
write_csv(run_dir / "first_real_slice_operator_input_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_OPERATOR_INPUT_FILE_ROWS.csv", run_dir / "first_real_slice_operator_input_file_rows.csv"),
    ("FIRST_REAL_SLICE_OPERATOR_INPUT_STAGE_ROWS.csv", run_dir / "first_real_slice_operator_input_stage_rows.csv"),
    ("FIRST_REAL_SLICE_OPERATOR_INPUT_COMMAND_ROWS.csv", run_dir / "first_real_slice_operator_input_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "from pathlib import Path",
        "",
        f"SUMMARY = Path({str(summary_csv)!r})",
        "",
        "with SUMMARY.open(newline='', encoding='utf-8') as handle:",
        "    row = next(csv.DictReader(handle))",
        "required = {",
        "    'final_operator_input_files_ready': '1',",
        "    'receiver_preflight_executed': '1',",
        "    'operator_input_receipt_ready': '1',",
        "    'operator_input_preflight_ready': '1',",
        "    'assembly_admitted': '0',",
        "    'assembly_executed': '0',",
        "}",
        "errors = [f'{k}={row.get(k)}' for k, v in required.items() if row.get(k) != v]",
        "if errors:",
        "    raise SystemExit('operator input preflight remains blocked: ' + ';'.join(errors))",
        "print('operator input preflight ready without assembly')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py").chmod(0o755)

(package_dir / "VERIFY_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_INPUT_FILE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_INPUT_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_INPUT_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER_MANIFEST.json\"",
        "test -x \"$DIR/CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61go package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61go materializes the operator input root and runs v61gj preflight-only.'",
        "echo 'V61GO_EXECUTE_MATERIALIZE=1 ./experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh'",
        "echo 'results/v61go_post_gn_first_real_slice_operator_input_materializer/materialize_001/first_real_slice_operator_input_materializer/CHECK_OPERATOR_INPUT_PREFLIGHT_READY.py'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

summary = {
    "v61go_post_gn_first_real_slice_operator_input_materializer_ready": 1,
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "contains_real_external_evidence": 0,
    "minimal_slice_csv_ready": minimal_slice_csv_ready,
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": operator_root_exists,
    "operator_input_root_outside_repo": operator_root_outside_repo,
    "materialize_admitted": materialize_admitted,
    "materialize_requested": execute_materialize,
    "materialize_executed": materialize_executed,
    "materialize_exit_code": materialize_exit_code,
    "final_operator_input_files_ready": final_operator_input_files_ready,
    "receiver_preflight_executed": receiver_preflight_executed,
    "receiver_preflight_exit_code": receiver_preflight_exit_code,
    "ready_operator_input_rows": ready_operator_input_rows,
    "operator_input_receipt_ready": operator_input_receipt_ready,
    "operator_input_preflight_ready": operator_input_preflight_ready,
    "assembly_admitted": assembly_admitted,
    "assembly_executed": assembly_executed,
    "real_external_review_return_rows": as_int(v61gj_summary, "real_external_review_return_rows"),
    "real_adjudication_rows": as_int(v61gj_summary, "real_adjudication_rows"),
    "slice_answer_review_accepted_rows": as_int(v61gj_summary, "slice_answer_review_accepted_rows"),
    "real_generation_result_artifacts": as_int(v61gj_summary, "real_generation_result_artifacts"),
    "accepted_generation_result_artifacts": as_int(v61gj_summary, "accepted_generation_result_artifacts"),
    "generation_result_accepted_rows": as_int(v61gj_summary, "generation_result_accepted_rows"),
    "dual_external_return_real_ready": as_int(v61gj_summary, "dual_external_return_real_ready"),
    "real_return_replay_admission_ready": as_int(v61gj_summary, "real_return_replay_admission_ready"),
    "generation_acceptance_closure_ready": as_int(v61gj_summary, "generation_acceptance_closure_ready"),
    "actual_model_generation_ready": as_int(v61gj_summary, "actual_model_generation_ready"),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "checkpoint_payload_bytes_downloaded_by_v61go": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER.md").write_text(
    "\n".join([
        "# v61go first real slice operator input materializer",
        "",
        f"- materialize_admitted={materialize_admitted}",
        f"- materialize_executed={materialize_executed}",
        f"- final_operator_input_files_ready={final_operator_input_files_ready}",
        f"- operator_input_preflight_ready={operator_input_preflight_ready}",
        f"- assembly_admitted={assembly_admitted}",
        "- contains_real_external_evidence=0",
        "- actual_model_generation_ready=0",
        "",
        "This gate materializes and preflights the operator input root only. It deliberately withholds output-root assembly and dual replay.",
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
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "first_real_slice_operator_input_materializer_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gn-ready", "status": "pass", "evidence": "v61gn ready"},
    {"gate": "minimal-csv-ready", "status": "pass" if minimal_slice_csv_ready else "blocked", "evidence": f"minimal_slice_csv_ready={minimal_slice_csv_ready}"},
    {"gate": "materialize-admitted", "status": "pass" if materialize_admitted else "blocked", "evidence": f"materialize_admitted={materialize_admitted}"},
    {"gate": "materialize-executed", "status": "pass" if materialize_executed else "blocked", "evidence": f"materialize_executed={materialize_executed}; exit_code={materialize_exit_code}"},
    {"gate": "operator-input-preflight", "status": "pass" if operator_input_preflight_ready else "blocked", "evidence": f"operator_input_preflight_ready={operator_input_preflight_ready}; ready_rows={ready_operator_input_rows}"},
    {"gate": "assembly-admitted", "status": "blocked", "evidence": f"assembly_admitted={assembly_admitted}; output root intentionally withheld"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={summary['actual_model_generation_ready']}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GO Post-GN First Real Slice Operator Input Materializer",
    "",
    "- v61go_post_gn_first_real_slice_operator_input_materializer_ready=1",
    "- contains_real_external_evidence=0",
    f"- materialize_admitted={materialize_admitted}",
    f"- materialize_executed={materialize_executed}",
    f"- final_operator_input_files_ready={final_operator_input_files_ready}",
    f"- operator_input_preflight_ready={operator_input_preflight_ready}",
    f"- assembly_admitted={assembly_admitted}",
    f"- real_external_review_return_rows={summary['real_external_review_return_rows']}",
    f"- generation_result_accepted_rows={summary['generation_result_accepted_rows']}",
    f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This gate stops at operator-input preflight. Real counters stay blocked until output-root assembly and dual replay are explicitly executed downstream.",
    "",
])
(run_dir / "V61GO_POST_GN_FIRST_REAL_SLICE_OPERATOR_INPUT_MATERIALIZER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61go": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61go_post_gn_first_real_slice_operator_input_materializer_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
