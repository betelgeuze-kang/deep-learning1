#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gq_post_gp_first_real_slice_end_to_end_guarded_chain"
RUN_ID="${V61GQ_RUN_ID:-chain_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXECUTE_CHAIN="${V61GQ_EXECUTE_CHAIN:-0}"

if [[ "${V61GQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$EXECUTE_CHAIN" <<'PY'
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
execute_chain = int((sys.argv[6].strip() or "0") == "1")
results = root / "results"
prefix = "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain"
package_dir = run_dir / "first_real_slice_end_to_end_guarded_chain"
package_dir.mkdir(parents=True, exist_ok=True)

GO_PREFIX = "v61go_post_gn_first_real_slice_operator_input_materializer"
GP_PREFIX = "v61gp_post_go_first_real_slice_dual_replay_executor"
GJ_PREFIX = "v61gj_post_gi_operator_input_receiver"
EXPECTED_ACK = "operator-confirmed-real-external-review-and-generation-return"
NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


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


def has_nonfinal_text(value):
    lowered = str(value).lower()
    return any(token in lowered for token in NONFINAL_TOKENS)


def run_step(step_id, env_updates, command):
    env = os.environ.copy()
    env.update(env_updates)
    proc = subprocess.run(
        [str(root / "experiments" / command)],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    (run_dir / f"{step_id}_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / f"{step_id}_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    return proc


source_paths = {
    "v61gp_source_summary": results / f"{GP_PREFIX}_summary.csv",
    "v61gp_source_decision": results / f"{GP_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gq source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gp_initial") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_end_to_end_chain_source_rows.csv", list(source_rows[0].keys()), source_rows)

gp_source = read_csv(source_paths["v61gp_source_summary"])[0]
if gp_source.get("v61gp_post_go_first_real_slice_dual_replay_executor_ready") != "1":
    raise SystemExit("v61gq requires v61gp ready")

operator_root_raw = os.environ.get("V61GQ_OPERATOR_INPUT_ROOT", os.environ.get("V61GI_OPERATOR_INPUT_ROOT", "")).strip()
output_root_raw = os.environ.get("V61GQ_OUTPUT_ROOT", os.environ.get("V61GP_OUTPUT_ROOT", os.environ.get("V61GI_OUTPUT_ROOT", ""))).strip()
operator_root = Path(operator_root_raw).expanduser().resolve() if operator_root_raw else None
output_root = Path(output_root_raw).expanduser().resolve() if output_root_raw else None
operator_root_supplied = int(operator_root is not None)
operator_root_exists_initial = int(operator_root is not None and operator_root.is_dir())
operator_root_outside_repo = int(operator_root is not None and not is_inside(operator_root, root))
output_root_supplied = int(output_root is not None)
output_root_outside_repo = int(output_root is not None and not is_inside(output_root, root))

content_witness_raw = os.environ.get("V61GQ_CONTENT_WITNESS_DIR", os.environ.get("V61GI_CONTENT_WITNESS_DIR", "")).strip()
minimal_csv_raw = os.environ.get("V61GQ_MINIMAL_SLICE_ROWS_CSV", os.environ.get("V61GI_MINIMAL_SLICE_ROWS_CSV", "")).strip()
content_witness_dir = Path(content_witness_raw).expanduser().resolve() if content_witness_raw else None
minimal_csv = Path(minimal_csv_raw).expanduser().resolve() if minimal_csv_raw else None
content_witness_supplied = int(content_witness_dir is not None)
content_witness_exists = int(content_witness_dir is not None and content_witness_dir.is_dir())
content_witness_outside_repo = int(content_witness_dir is not None and not is_inside(content_witness_dir, root))
minimal_csv_supplied = int(minimal_csv is not None)
minimal_csv_outside_repo = int(minimal_csv is not None and not is_inside(minimal_csv, root))

ack = os.environ.get("V61GQ_EXTERNAL_RETURN_AUTHORITY_ACK", os.environ.get("V61GP_EXTERNAL_RETURN_AUTHORITY_ACK", "")).strip()
ack_statement = os.environ.get("V61GQ_EXTERNAL_RETURN_AUTHORITY_STATEMENT", os.environ.get("V61GP_EXTERNAL_RETURN_AUTHORITY_STATEMENT", "")).strip()
external_real_ack_ready = int(
    ack == EXPECTED_ACK
    and len(ack_statement) >= 80
    and not has_nonfinal_text(ack_statement)
)

materialize_step_executed = 0
materialize_step_exit_code = "not-run"
replay_step_executed = 0
replay_step_exit_code = "not-run"
if execute_chain:
    materialize_env = {
        "V61GO_RUN_ID": f"{run_id}_materialize",
        "V61GO_EXECUTE_MATERIALIZE": "1",
        "V61GO_REUSE_EXISTING": "0",
    }
    if content_witness_dir is not None:
        materialize_env["V61GI_CONTENT_WITNESS_DIR"] = str(content_witness_dir)
    if minimal_csv is not None:
        materialize_env["V61GI_MINIMAL_SLICE_ROWS_CSV"] = str(minimal_csv)
    if operator_root is not None:
        materialize_env["V61GI_OPERATOR_INPUT_ROOT"] = str(operator_root)
    if output_root is not None:
        materialize_env["V61GI_OUTPUT_ROOT"] = str(output_root)
    proc = run_step("01_v61go_materialize", materialize_env, "run_v61go_post_gn_first_real_slice_operator_input_materializer.sh")
    materialize_step_executed = 1
    materialize_step_exit_code = str(proc.returncode)
    if proc.returncode != 0:
        raise SystemExit(f"v61gq materialize step failed: {proc.returncode}")

    replay_env = {
        "V61GP_RUN_ID": f"{run_id}_replay",
        "V61GP_EXECUTE_REPLAY": "1",
        "V61GP_REUSE_EXISTING": "0",
        "V61GP_EXTERNAL_RETURN_AUTHORITY_ACK": ack,
        "V61GP_EXTERNAL_RETURN_AUTHORITY_STATEMENT": ack_statement,
    }
    if operator_root is not None:
        replay_env["V61GP_OPERATOR_INPUT_ROOT"] = str(operator_root)
    if output_root is not None:
        replay_env["V61GP_OUTPUT_ROOT"] = str(output_root)
    proc = run_step("02_v61gp_replay", replay_env, "run_v61gp_post_go_first_real_slice_dual_replay_executor.sh")
    replay_step_executed = 1
    replay_step_exit_code = str(proc.returncode)
    if proc.returncode != 0:
        raise SystemExit(f"v61gq replay step failed: {proc.returncode}")
else:
    (run_dir / "01_v61go_materialize_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "01_v61go_materialize_stderr.txt").write_text("chain-not-executed\n", encoding="utf-8")
    (run_dir / "02_v61gp_replay_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "02_v61gp_replay_stderr.txt").write_text("chain-not-executed\n", encoding="utf-8")

go_summary_path = results / f"{GO_PREFIX}_summary.csv"
gp_summary_path = results / f"{GP_PREFIX}_summary.csv"
go_decision_path = results / f"{GO_PREFIX}_decision.csv"
gp_decision_path = results / f"{GP_PREFIX}_decision.csv"
for label, path, folder in [
    ("v61go_final_summary", go_summary_path, "source_v61go_final"),
    ("v61go_final_decision", go_decision_path, "source_v61go_final"),
    ("v61gp_final_summary", gp_summary_path, "source_v61gp_final"),
    ("v61gp_final_decision", gp_decision_path, "source_v61gp_final"),
]:
    if not path.is_file():
        raise SystemExit(f"missing v61gq final source {label}: {path}")
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_end_to_end_chain_source_rows.csv", list(source_rows[0].keys()), source_rows)

go = read_csv(go_summary_path)[0]
gp = read_csv(gp_summary_path)[0]

root_rows = [
    {"root_id": "content-witness-dir", "path": str(content_witness_dir) if content_witness_dir else "", "supplied": str(content_witness_supplied), "exists": str(content_witness_exists), "outside_repo": str(content_witness_outside_repo), "role": "seven real content witness files"},
    {"root_id": "minimal-slice-csv", "path": str(minimal_csv) if minimal_csv else "", "supplied": str(minimal_csv_supplied), "exists": str(int(minimal_csv is not None and minimal_csv.is_file())), "outside_repo": str(minimal_csv_outside_repo), "role": "one-row minimal slice CSV"},
    {"root_id": "operator-input-root", "path": str(operator_root) if operator_root else "", "supplied": str(operator_root_supplied), "exists": str(int(operator_root is not None and operator_root.is_dir())), "outside_repo": str(operator_root_outside_repo), "role": "final operator input root"},
    {"root_id": "output-root", "path": str(output_root) if output_root else "", "supplied": str(output_root_supplied), "exists": str(int(output_root is not None and output_root.exists())), "outside_repo": str(output_root_outside_repo), "role": "dual replay output root"},
]
write_csv(run_dir / "first_real_slice_end_to_end_chain_root_rows.csv", list(root_rows[0].keys()), root_rows)

real_external_review_return_rows = as_int(gp, "real_external_review_return_rows")
real_adjudication_rows = as_int(gp, "real_adjudication_rows")
slice_answer_review_accepted_rows = as_int(gp, "slice_answer_review_accepted_rows")
real_generation_result_artifacts = as_int(gp, "real_generation_result_artifacts")
accepted_generation_result_artifacts = as_int(gp, "accepted_generation_result_artifacts")
generation_result_accepted_rows = as_int(gp, "generation_result_accepted_rows")
row_acceptance_ready = as_int(gp, "row_acceptance_ready")
generation_execution_admission_ready = as_int(gp, "generation_execution_admission_ready")
generation_result_row_acceptance_ready = as_int(gp, "generation_result_row_acceptance_ready")
dual_external_return_real_ready = as_int(gp, "dual_external_return_real_ready")
real_return_replay_admission_ready = as_int(gp, "real_return_replay_admission_ready")
generation_acceptance_closure_ready = as_int(gp, "generation_acceptance_closure_ready")
authority_bound_replay_admission_ready = as_int(gp, "authority_bound_replay_admission_ready")
actual_model_generation_ready = as_int(gp, "actual_model_generation_ready")

target_rows = [
    {"target_id": "real-external-review-return", "current_value": str(real_external_review_return_rows), "target_condition": ">0", "ready": str(int(real_external_review_return_rows > 0))},
    {"target_id": "answer-review-accepted-rows", "current_value": str(slice_answer_review_accepted_rows), "target_condition": ">0", "ready": str(int(slice_answer_review_accepted_rows > 0))},
    {"target_id": "adjudication-rows", "current_value": str(real_adjudication_rows), "target_condition": ">0", "ready": str(int(real_adjudication_rows > 0))},
    {"target_id": "real-generation-result-artifacts", "current_value": str(real_generation_result_artifacts), "target_condition": ">0", "ready": str(int(real_generation_result_artifacts > 0))},
    {"target_id": "accepted-generation-result-artifacts", "current_value": str(accepted_generation_result_artifacts), "target_condition": ">0", "ready": str(int(accepted_generation_result_artifacts > 0))},
    {"target_id": "generation-result-accepted-rows", "current_value": str(generation_result_accepted_rows), "target_condition": ">0", "ready": str(int(generation_result_accepted_rows > 0))},
    {"target_id": "row-acceptance-ready", "current_value": str(row_acceptance_ready), "target_condition": "1", "ready": str(row_acceptance_ready)},
    {"target_id": "generation-execution-admission-ready", "current_value": str(generation_execution_admission_ready), "target_condition": "1", "ready": str(generation_execution_admission_ready)},
    {"target_id": "dual-external-return-real-ready", "current_value": str(dual_external_return_real_ready), "target_condition": "1", "ready": str(dual_external_return_real_ready)},
    {"target_id": "real-return-replay-admission-ready", "current_value": str(real_return_replay_admission_ready), "target_condition": "1", "ready": str(real_return_replay_admission_ready)},
    {"target_id": "generation-acceptance-closure-ready", "current_value": str(generation_acceptance_closure_ready), "target_condition": "1", "ready": str(generation_acceptance_closure_ready)},
    {"target_id": "actual-model-generation-ready", "current_value": str(actual_model_generation_ready), "target_condition": "1", "ready": str(actual_model_generation_ready)},
]
write_csv(run_dir / "first_real_slice_end_to_end_chain_target_rows.csv", list(target_rows[0].keys()), target_rows)

chain_opened = int(real_return_replay_admission_ready and generation_acceptance_closure_ready)
stage_rows = [
    {"stage_id": "01-v61gp-source", "status": "ready", "evidence": "v61gp ready"},
    {"stage_id": "02-chain-execute-requested", "status": "ready" if execute_chain else "blocked", "evidence": f"execute_chain={execute_chain}"},
    {"stage_id": "03-witness-dir", "status": "ready" if content_witness_exists and content_witness_outside_repo else "blocked", "evidence": f"exists={content_witness_exists}; outside_repo={content_witness_outside_repo}"},
    {"stage_id": "04-operator-input-root", "status": "ready" if operator_root_supplied and operator_root_outside_repo else "blocked", "evidence": f"supplied={operator_root_supplied}; initial_exists={operator_root_exists_initial}; outside_repo={operator_root_outside_repo}"},
    {"stage_id": "05-output-root", "status": "ready" if output_root_supplied and output_root_outside_repo else "blocked", "evidence": f"supplied={output_root_supplied}; outside_repo={output_root_outside_repo}"},
    {"stage_id": "06-external-real-ack", "status": "ready" if external_real_ack_ready else "blocked", "evidence": f"ack_ready={external_real_ack_ready}"},
    {"stage_id": "07-v61go-materialize-step", "status": "ready" if as_int(go, "materialize_executed") else "blocked", "evidence": f"executed={as_int(go, 'materialize_executed')}; final_input_ready={as_int(go, 'operator_input_preflight_ready')}"},
    {"stage_id": "08-v61gp-replay-step", "status": "ready" if as_int(gp, "replay_executed") else "blocked", "evidence": f"replay_admitted={as_int(gp, 'replay_admitted')}; replay_executed={as_int(gp, 'replay_executed')}"},
    {"stage_id": "09-dual-replay-opened", "status": "ready" if chain_opened else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}; generation_acceptance_closure_ready={generation_acceptance_closure_ready}"},
    {"stage_id": "10-actual-generation-full-claim", "status": "blocked", "evidence": f"actual_model_generation_ready={actual_model_generation_ready}"},
]
write_csv(run_dir / "first_real_slice_end_to_end_chain_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-end-to-end-chain-package", "ready_to_run_now": "1", "command": "results/v61gq_post_gp_first_real_slice_end_to_end_guarded_chain/chain_001/first_real_slice_end_to_end_guarded_chain/VERIFY_FIRST_REAL_SLICE_END_TO_END_CHAIN.sh", "purpose": "verify this end-to-end chain package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gq_post_gp_first_real_slice_end_to_end_guarded_chain/chain_001/first_real_slice_end_to_end_guarded_chain/READY_NOW_COMMANDS.sh", "purpose": "show guarded chain command"},
    {"command_id": "03-run-end-to-end-chain", "ready_to_run_now": str(int(content_witness_exists and operator_root_supplied and output_root_supplied and external_real_ack_ready)), "command": "V61GQ_EXECUTE_CHAIN=1 V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OUTPUT_ROOT=<output-root> V61GQ_EXTERNAL_RETURN_AUTHORITY_ACK=operator-confirmed-real-external-review-and-generation-return V61GQ_EXTERNAL_RETURN_AUTHORITY_STATEMENT=<final-statement> ./experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh", "purpose": "build minimal CSV, materialize final input, and execute guarded dual replay"},
    {"command_id": "04-check-chain-opened", "ready_to_run_now": str(chain_opened), "command": "results/v61gq_post_gp_first_real_slice_end_to_end_guarded_chain/chain_001/first_real_slice_end_to_end_guarded_chain/CHECK_END_TO_END_CHAIN_OPENED.py", "purpose": "assert requested subset counters opened"},
]
write_csv(run_dir / "first_real_slice_end_to_end_chain_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_END_TO_END_CHAIN_ROOT_ROWS.csv", run_dir / "first_real_slice_end_to_end_chain_root_rows.csv"),
    ("FIRST_REAL_SLICE_END_TO_END_CHAIN_TARGET_ROWS.csv", run_dir / "first_real_slice_end_to_end_chain_target_rows.csv"),
    ("FIRST_REAL_SLICE_END_TO_END_CHAIN_STAGE_ROWS.csv", run_dir / "first_real_slice_end_to_end_chain_stage_rows.csv"),
    ("FIRST_REAL_SLICE_END_TO_END_CHAIN_COMMAND_ROWS.csv", run_dir / "first_real_slice_end_to_end_chain_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "CHECK_END_TO_END_CHAIN_OPENED.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "from pathlib import Path",
        "",
        f"SUMMARY = Path({str(summary_csv)!r})",
        "",
        "with SUMMARY.open(newline='', encoding='utf-8') as handle:",
        "    row = next(csv.DictReader(handle))",
        "positive = ['real_external_review_return_rows','real_adjudication_rows','slice_answer_review_accepted_rows','real_generation_result_artifacts','accepted_generation_result_artifacts','generation_result_accepted_rows']",
        "ready = ['row_acceptance_ready','generation_execution_admission_ready','generation_result_row_acceptance_ready','dual_external_return_real_ready','real_return_replay_admission_ready','generation_acceptance_closure_ready','authority_bound_replay_admission_ready']",
        "errors = []",
        "for key in positive:",
        "    if int(row.get(key, '0') or '0') <= 0:",
        "        errors.append(f'{key}={row.get(key)}')",
        "for key in ready:",
        "    if row.get(key) != '1':",
        "        errors.append(f'{key}={row.get(key)}')",
        "if errors:",
        "    raise SystemExit('end-to-end chain remains blocked: ' + ';'.join(errors))",
        "print('end-to-end first-slice chain opened')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_END_TO_END_CHAIN_OPENED.py").chmod(0o755)

(package_dir / "VERIFY_FIRST_REAL_SLICE_END_TO_END_CHAIN.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_END_TO_END_CHAIN_ROOT_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_END_TO_END_CHAIN_TARGET_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_END_TO_END_CHAIN_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_END_TO_END_CHAIN_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_END_TO_END_CHAIN_MANIFEST.json\"",
        "test -x \"$DIR/CHECK_END_TO_END_CHAIN_OPENED.py\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gq package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_END_TO_END_CHAIN.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'End-to-end guarded first-slice chain:'",
        "echo 'V61GQ_EXECUTE_CHAIN=1 V61GI_CONTENT_WITNESS_DIR=<witness-dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<minimal-slice.csv> V61GI_OPERATOR_INPUT_ROOT=<operator-input-root> V61GI_OUTPUT_ROOT=<output-root> V61GQ_EXTERNAL_RETURN_AUTHORITY_ACK=operator-confirmed-real-external-review-and-generation-return V61GQ_EXTERNAL_RETURN_AUTHORITY_STATEMENT=<final-statement> ./experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh'",
        "echo 'Then check:'",
        "echo 'results/v61gq_post_gp_first_real_slice_end_to_end_guarded_chain/chain_001/first_real_slice_end_to_end_guarded_chain/CHECK_END_TO_END_CHAIN_OPENED.py'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

contains_real_external_evidence = int(real_external_review_return_rows > 0 or real_generation_result_artifacts > 0 or chain_opened)
summary = {
    "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_ready": 1,
    "v61gp_post_go_first_real_slice_dual_replay_executor_ready": 1,
    "contains_real_external_evidence": contains_real_external_evidence,
    "execute_chain_requested": execute_chain,
    "materialize_step_executed": materialize_step_executed,
    "materialize_step_exit_code": materialize_step_exit_code,
    "replay_step_executed": replay_step_executed,
    "replay_step_exit_code": replay_step_exit_code,
    "content_witness_dir_supplied": content_witness_supplied,
    "content_witness_dir_exists": content_witness_exists,
    "content_witness_dir_outside_repo": content_witness_outside_repo,
    "minimal_slice_csv_supplied": minimal_csv_supplied,
    "minimal_slice_csv_outside_repo": minimal_csv_outside_repo,
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": int(operator_root is not None and operator_root.is_dir()),
    "operator_input_root_outside_repo": operator_root_outside_repo,
    "output_root_supplied": output_root_supplied,
    "output_root_outside_repo": output_root_outside_repo,
    "external_real_ack_ready": external_real_ack_ready,
    "v61go_minimal_slice_csv_ready": as_int(go, "minimal_slice_csv_ready"),
    "v61go_materialize_executed": as_int(go, "materialize_executed"),
    "v61go_operator_input_preflight_ready": as_int(go, "operator_input_preflight_ready"),
    "v61gp_operator_input_preflight_ready": as_int(gp, "operator_input_preflight_ready"),
    "v61gp_replay_admitted": as_int(gp, "replay_admitted"),
    "v61gp_replay_requested": as_int(gp, "replay_requested"),
    "v61gp_replay_executed": as_int(gp, "replay_executed"),
    "real_external_review_return_rows": real_external_review_return_rows,
    "real_adjudication_rows": real_adjudication_rows,
    "slice_answer_review_accepted_rows": slice_answer_review_accepted_rows,
    "real_generation_result_artifacts": real_generation_result_artifacts,
    "accepted_generation_result_artifacts": accepted_generation_result_artifacts,
    "generation_result_accepted_rows": generation_result_accepted_rows,
    "row_acceptance_ready": row_acceptance_ready,
    "generation_execution_admission_ready": generation_execution_admission_ready,
    "generation_result_row_acceptance_ready": generation_result_row_acceptance_ready,
    "dual_external_return_real_ready": dual_external_return_real_ready,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "generation_acceptance_closure_ready": generation_acceptance_closure_ready,
    "authority_bound_replay_admission_ready": authority_bound_replay_admission_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "target_rows": len(target_rows),
    "ready_target_rows": sum(row["ready"] == "1" for row in target_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "checkpoint_payload_bytes_downloaded_by_v61gq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "expected_external_ack": EXPECTED_ACK,
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_END_TO_END_CHAIN_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "FIRST_REAL_SLICE_END_TO_END_CHAIN.md").write_text(
    "\n".join([
        "# v61gq first real slice end-to-end guarded chain",
        "",
        f"- execute_chain_requested={execute_chain}",
        f"- v61go_materialize_executed={summary['v61go_materialize_executed']}",
        f"- v61gp_operator_input_preflight_ready={summary['v61gp_operator_input_preflight_ready']}",
        f"- v61gp_replay_admitted={summary['v61gp_replay_admitted']}",
        f"- v61gp_replay_executed={summary['v61gp_replay_executed']}",
        f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
        f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
        f"- actual_model_generation_ready={actual_model_generation_ready}",
        "",
        "This chain is the one-command operator path. It still fails closed unless the external final inputs and acknowledgement are supplied.",
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
write_csv(run_dir / "first_real_slice_end_to_end_chain_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gp-ready", "status": "pass", "evidence": "v61gp ready"},
    {"gate": "execute-chain-requested", "status": "pass" if execute_chain else "blocked", "evidence": f"execute_chain_requested={execute_chain}"},
    {"gate": "content-witness-dir", "status": "pass" if content_witness_exists and content_witness_outside_repo else "blocked", "evidence": f"exists={content_witness_exists}; outside_repo={content_witness_outside_repo}"},
    {"gate": "operator-input-root", "status": "pass" if operator_root_supplied and operator_root_outside_repo else "blocked", "evidence": f"supplied={operator_root_supplied}; outside_repo={operator_root_outside_repo}"},
    {"gate": "output-root", "status": "pass" if output_root_supplied and output_root_outside_repo else "blocked", "evidence": f"supplied={output_root_supplied}; outside_repo={output_root_outside_repo}"},
    {"gate": "external-real-ack", "status": "pass" if external_real_ack_ready else "blocked", "evidence": f"external_real_ack_ready={external_real_ack_ready}"},
    {"gate": "materialize-step", "status": "pass" if as_int(go, "materialize_executed") else "blocked", "evidence": f"v61go_materialize_executed={as_int(go, 'materialize_executed')}"},
    {"gate": "replay-step", "status": "pass" if as_int(gp, "replay_executed") else "blocked", "evidence": f"v61gp_replay_executed={as_int(gp, 'replay_executed')}"},
    {"gate": "row-acceptance", "status": "pass" if row_acceptance_ready else "blocked", "evidence": f"row_acceptance_ready={row_acceptance_ready}"},
    {"gate": "dual-external-return-real", "status": "pass" if dual_external_return_real_ready else "blocked", "evidence": f"dual_external_return_real_ready={dual_external_return_real_ready}"},
    {"gate": "real-return-replay-admission", "status": "pass" if real_return_replay_admission_ready else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}"},
    {"gate": "generation-acceptance-closure", "status": "pass" if generation_acceptance_closure_ready else "blocked", "evidence": f"generation_acceptance_closure_ready={generation_acceptance_closure_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={actual_model_generation_ready}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GQ Post-GP First Real Slice End-to-End Guarded Chain",
    "",
    "- v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_ready=1",
    f"- execute_chain_requested={execute_chain}",
    f"- v61go_materialize_executed={summary['v61go_materialize_executed']}",
    f"- v61gp_replay_executed={summary['v61gp_replay_executed']}",
    f"- real_external_review_return_rows={real_external_review_return_rows}",
    f"- generation_result_accepted_rows={generation_result_accepted_rows}",
    f"- dual_external_return_real_ready={dual_external_return_real_ready}",
    f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
    f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
    f"- actual_model_generation_ready={actual_model_generation_ready}",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This gate provides the one-command real operator path but keeps canonical counters blocked without final external inputs.",
    "",
])
(run_dir / "V61GQ_POST_GP_FIRST_REAL_SLICE_END_TO_END_GUARDED_CHAIN_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "expected_external_ack": EXPECTED_ACK,
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
