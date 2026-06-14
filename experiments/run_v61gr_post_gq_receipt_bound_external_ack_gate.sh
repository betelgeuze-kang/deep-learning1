#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gr_post_gq_receipt_bound_external_ack_gate"
RUN_ID="${V61GR_RUN_ID:-ack_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXECUTE_REPLAY="${V61GR_EXECUTE_REPLAY:-0}"

if [[ "${V61GR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gr_post_gq_receipt_bound_external_ack_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$EXECUTE_REPLAY" <<'PY'
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
execute_replay = int((sys.argv[6].strip() or "0") == "1")
results = root / "results"
prefix = "v61gr_post_gq_receipt_bound_external_ack_gate"
package_dir = run_dir / "receipt_bound_external_ack_gate"
package_dir.mkdir(parents=True, exist_ok=True)

GQ_PREFIX = "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain"
GP_PREFIX = "v61gp_post_go_first_real_slice_dual_replay_executor"
EXPECTED_ACK = "operator-confirmed-real-external-review-and-generation-return"
EXPECTED_SCOPE = "first-real-slice-dual-replay"
ALLOWED_SOURCE_CLASSES = {"external-operator-return-ack", "external-review-and-generation-return-ack"}
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


source_paths = {
    "v61gq_summary": results / f"{GQ_PREFIX}_summary.csv",
    "v61gq_decision": results / f"{GQ_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gr source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gq") for label, path in source_paths.items()]
write_csv(run_dir / "receipt_bound_external_ack_source_rows.csv", list(source_rows[0].keys()), source_rows)

gq = read_csv(source_paths["v61gq_summary"])[0]
if gq.get("v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_ready") != "1":
    raise SystemExit("v61gr requires v61gq ready")

operator_root_raw = os.environ.get("V61GR_OPERATOR_INPUT_ROOT", os.environ.get("V61GP_OPERATOR_INPUT_ROOT", os.environ.get("V61GI_OPERATOR_INPUT_ROOT", ""))).strip()
output_root_raw = os.environ.get("V61GR_OUTPUT_ROOT", os.environ.get("V61GP_OUTPUT_ROOT", os.environ.get("V61GI_OUTPUT_ROOT", ""))).strip()
ack_file_raw = os.environ.get("V61GR_EXTERNAL_ACK_FILE", "").strip()
operator_root = Path(operator_root_raw).expanduser().resolve() if operator_root_raw else None
output_root = Path(output_root_raw).expanduser().resolve() if output_root_raw else None
ack_file = Path(ack_file_raw).expanduser().resolve() if ack_file_raw else None

operator_root_supplied = int(operator_root is not None)
operator_root_exists = int(operator_root is not None and operator_root.is_dir())
operator_root_outside_repo = int(operator_root is not None and not is_inside(operator_root, root))
receipt_path = operator_root / "OPERATOR_INPUT_RECEIPT.json" if operator_root else None
receipt_exists = int(receipt_path is not None and receipt_path.is_file())
receipt_sha = sha256(receipt_path) if receipt_exists else ""
receipt_root_id = ""
if receipt_exists:
    try:
        receipt_root_id = json.loads(receipt_path.read_text(encoding="utf-8")).get("operator_input_root_id", "")
    except json.JSONDecodeError:
        receipt_root_id = ""

output_root_supplied = int(output_root is not None)
output_root_outside_repo = int(output_root is not None and not is_inside(output_root, root))
ack_file_supplied = int(ack_file is not None)
ack_file_exists = int(ack_file is not None and ack_file.is_file())
ack_file_outside_repo = int(ack_file is not None and not is_inside(ack_file, root))
ack_file_sha = sha256(ack_file) if ack_file_exists else ""

ack_payload = {}
ack_errors = []
if ack_file_exists:
    try:
        ack_payload = json.loads(ack_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        ack_errors.append("invalid-json")
else:
    ack_errors.append("missing-ack-file")

source_class = str(ack_payload.get("acknowledgement_source_class", ""))
ack_value = str(ack_payload.get("external_return_authority_ack", ""))
ack_statement = str(ack_payload.get("external_return_authority_statement", ""))
ack_scope = str(ack_payload.get("ack_scope", ""))
bound_receipt_sha = str(ack_payload.get("operator_input_receipt_sha256", ""))
bound_root_id = str(ack_payload.get("operator_input_root_id", ""))

ack_source_class_ready = int(source_class in ALLOWED_SOURCE_CLASSES and not has_nonfinal_text(source_class))
ack_value_ready = int(ack_value == EXPECTED_ACK)
ack_statement_ready = int(len(ack_statement) >= 80 and not has_nonfinal_text(ack_statement))
ack_scope_ready = int(ack_scope == EXPECTED_SCOPE)
ack_receipt_hash_binding_ready = int(receipt_exists and bound_receipt_sha == receipt_sha and bool(receipt_sha))
ack_root_id_binding_ready = int(not bound_root_id or (receipt_root_id and bound_root_id == receipt_root_id))
ack_json_ready = int(ack_file_exists and not ack_errors)
receipt_bound_ack_ready = int(
    ack_json_ready
    and ack_file_outside_repo
    and operator_root_exists
    and operator_root_outside_repo
    and receipt_exists
    and ack_source_class_ready
    and ack_value_ready
    and ack_statement_ready
    and ack_scope_ready
    and ack_receipt_hash_binding_ready
    and ack_root_id_binding_ready
)
receipt_bound_replay_admitted = int(receipt_bound_ack_ready and output_root_supplied and output_root_outside_repo)

ack_rows = [{
    "ack_file_supplied": str(ack_file_supplied),
    "ack_file_exists": str(ack_file_exists),
    "ack_file_outside_repo": str(ack_file_outside_repo),
    "ack_file_sha256": ack_file_sha,
    "ack_json_ready": str(ack_json_ready),
    "ack_source_class_ready": str(ack_source_class_ready),
    "ack_value_ready": str(ack_value_ready),
    "ack_statement_ready": str(ack_statement_ready),
    "ack_scope_ready": str(ack_scope_ready),
    "operator_input_receipt_exists": str(receipt_exists),
    "operator_input_receipt_sha256": receipt_sha,
    "ack_receipt_sha256": bound_receipt_sha,
    "ack_receipt_hash_binding_ready": str(ack_receipt_hash_binding_ready),
    "ack_root_id_binding_ready": str(ack_root_id_binding_ready),
    "receipt_bound_ack_ready": str(receipt_bound_ack_ready),
    "errors": ";".join(ack_errors),
}]
write_csv(run_dir / "receipt_bound_external_ack_rows.csv", list(ack_rows[0].keys()), ack_rows)

replay_executed = 0
replay_exit_code = "not-run"
gp_summary = {}
if execute_replay and receipt_bound_replay_admitted:
    env = os.environ.copy()
    env.update({
        "V61GP_RUN_ID": f"{run_id}_receipt_bound_replay",
        "V61GP_EXECUTE_REPLAY": "1",
        "V61GP_REUSE_EXISTING": "0",
        "V61GP_OPERATOR_INPUT_ROOT": str(operator_root),
        "V61GP_OUTPUT_ROOT": str(output_root),
        "V61GP_EXTERNAL_RETURN_AUTHORITY_ACK": ack_value,
        "V61GP_EXTERNAL_RETURN_AUTHORITY_STATEMENT": ack_statement,
    })
    proc = subprocess.run(
        [str(root / "experiments" / "run_v61gp_post_go_first_real_slice_dual_replay_executor.sh")],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    replay_executed = 1
    replay_exit_code = str(proc.returncode)
    (run_dir / "receipt_bound_replay_stdout.txt").write_text(proc.stdout, encoding="utf-8")
    (run_dir / "receipt_bound_replay_stderr.txt").write_text(proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61gr receipt-bound replay failed: {proc.returncode}")
    gp_summary_path = results / f"{GP_PREFIX}_summary.csv"
    gp_summary = read_csv(gp_summary_path)[0]
    for label, path in {
        "v61gp_receipt_bound_summary": results / f"{GP_PREFIX}_summary.csv",
        "v61gp_receipt_bound_decision": results / f"{GP_PREFIX}_decision.csv",
    }.items():
        if not path.is_file():
            raise SystemExit(f"missing v61gr replay source {label}: {path}")
        source_rows.append(copy_source(label, path, "source_v61gp_receipt_bound"))
    write_csv(run_dir / "receipt_bound_external_ack_source_rows.csv", list(source_rows[0].keys()), source_rows)
else:
    (run_dir / "receipt_bound_replay_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "receipt_bound_replay_stderr.txt").write_text("receipt-bound-replay-not-executed\n", encoding="utf-8")

counter_source = gp_summary if replay_executed else {}
real_external_review_return_rows = as_int(counter_source, "real_external_review_return_rows")
real_adjudication_rows = as_int(counter_source, "real_adjudication_rows")
slice_answer_review_accepted_rows = as_int(counter_source, "slice_answer_review_accepted_rows")
real_generation_result_artifacts = as_int(counter_source, "real_generation_result_artifacts")
accepted_generation_result_artifacts = as_int(counter_source, "accepted_generation_result_artifacts")
generation_result_accepted_rows = as_int(counter_source, "generation_result_accepted_rows")
row_acceptance_ready = as_int(counter_source, "row_acceptance_ready")
generation_execution_admission_ready = as_int(counter_source, "generation_execution_admission_ready")
generation_result_row_acceptance_ready = as_int(counter_source, "generation_result_row_acceptance_ready")
dual_external_return_real_ready = as_int(counter_source, "dual_external_return_real_ready")
real_return_replay_admission_ready = as_int(counter_source, "real_return_replay_admission_ready")
generation_acceptance_closure_ready = as_int(counter_source, "generation_acceptance_closure_ready")
authority_bound_replay_admission_ready = as_int(counter_source, "authority_bound_replay_admission_ready")
actual_model_generation_ready = as_int(counter_source, "actual_model_generation_ready")

root_rows = [
    {"root_id": "operator-input-root", "path": str(operator_root) if operator_root else "", "supplied": str(operator_root_supplied), "exists": str(operator_root_exists), "outside_repo": str(operator_root_outside_repo), "role": "receipt-bearing final operator input root"},
    {"root_id": "output-root", "path": str(output_root) if output_root else "", "supplied": str(output_root_supplied), "exists": str(int(output_root is not None and output_root.exists())), "outside_repo": str(output_root_outside_repo), "role": "dual replay output root"},
    {"root_id": "external-ack-file", "path": str(ack_file) if ack_file else "", "supplied": str(ack_file_supplied), "exists": str(ack_file_exists), "outside_repo": str(ack_file_outside_repo), "role": "receipt-bound external acknowledgement JSON"},
]
write_csv(run_dir / "receipt_bound_external_ack_root_rows.csv", list(root_rows[0].keys()), root_rows)

target_rows = [
    {"target_id": "receipt-bound-ack-ready", "current_value": str(receipt_bound_ack_ready), "target_condition": "1", "ready": str(receipt_bound_ack_ready)},
    {"target_id": "receipt-bound-replay-admitted", "current_value": str(receipt_bound_replay_admitted), "target_condition": "1", "ready": str(receipt_bound_replay_admitted)},
    {"target_id": "real-external-review-return", "current_value": str(real_external_review_return_rows), "target_condition": ">0", "ready": str(int(real_external_review_return_rows > 0))},
    {"target_id": "adjudication-rows", "current_value": str(real_adjudication_rows), "target_condition": ">0", "ready": str(int(real_adjudication_rows > 0))},
    {"target_id": "answer-review-accepted-rows", "current_value": str(slice_answer_review_accepted_rows), "target_condition": ">0", "ready": str(int(slice_answer_review_accepted_rows > 0))},
    {"target_id": "real-generation-result-artifacts", "current_value": str(real_generation_result_artifacts), "target_condition": ">0", "ready": str(int(real_generation_result_artifacts > 0))},
    {"target_id": "accepted-generation-result-artifacts", "current_value": str(accepted_generation_result_artifacts), "target_condition": ">0", "ready": str(int(accepted_generation_result_artifacts > 0))},
    {"target_id": "generation-result-accepted-rows", "current_value": str(generation_result_accepted_rows), "target_condition": ">0", "ready": str(int(generation_result_accepted_rows > 0))},
    {"target_id": "row-acceptance-ready", "current_value": str(row_acceptance_ready), "target_condition": "1", "ready": str(row_acceptance_ready)},
    {"target_id": "dual-external-return-real-ready", "current_value": str(dual_external_return_real_ready), "target_condition": "1", "ready": str(dual_external_return_real_ready)},
    {"target_id": "real-return-replay-admission-ready", "current_value": str(real_return_replay_admission_ready), "target_condition": "1", "ready": str(real_return_replay_admission_ready)},
    {"target_id": "generation-acceptance-closure-ready", "current_value": str(generation_acceptance_closure_ready), "target_condition": "1", "ready": str(generation_acceptance_closure_ready)},
    {"target_id": "actual-model-generation-ready", "current_value": str(actual_model_generation_ready), "target_condition": "1", "ready": str(actual_model_generation_ready)},
]
write_csv(run_dir / "receipt_bound_external_ack_target_rows.csv", list(target_rows[0].keys()), target_rows)

stage_rows = [
    {"stage_id": "01-v61gq-source", "status": "ready", "evidence": "v61gq ready"},
    {"stage_id": "02-operator-input-root", "status": "ready" if operator_root_exists and operator_root_outside_repo else "blocked", "evidence": f"exists={operator_root_exists}; outside_repo={operator_root_outside_repo}"},
    {"stage_id": "03-operator-input-receipt", "status": "ready" if receipt_exists else "blocked", "evidence": f"receipt_exists={receipt_exists}; sha={receipt_sha}"},
    {"stage_id": "04-external-ack-file", "status": "ready" if ack_json_ready and ack_file_outside_repo else "blocked", "evidence": f"ack_json_ready={ack_json_ready}; outside_repo={ack_file_outside_repo}"},
    {"stage_id": "05-receipt-hash-binding", "status": "ready" if ack_receipt_hash_binding_ready else "blocked", "evidence": f"ack_receipt_hash_binding_ready={ack_receipt_hash_binding_ready}"},
    {"stage_id": "06-ack-finality", "status": "ready" if ack_value_ready and ack_statement_ready and ack_scope_ready and ack_source_class_ready else "blocked", "evidence": f"ack_value={ack_value_ready}; statement={ack_statement_ready}; scope={ack_scope_ready}; source={ack_source_class_ready}"},
    {"stage_id": "07-receipt-bound-ack", "status": "ready" if receipt_bound_ack_ready else "blocked", "evidence": f"receipt_bound_ack_ready={receipt_bound_ack_ready}"},
    {"stage_id": "08-output-root", "status": "ready" if output_root_supplied and output_root_outside_repo else "blocked", "evidence": f"supplied={output_root_supplied}; outside_repo={output_root_outside_repo}"},
    {"stage_id": "09-replay-admitted", "status": "ready" if receipt_bound_replay_admitted else "blocked", "evidence": f"receipt_bound_replay_admitted={receipt_bound_replay_admitted}"},
    {"stage_id": "10-replay-executed", "status": "ready" if replay_executed else "blocked", "evidence": f"replay_executed={replay_executed}; exit_code={replay_exit_code}"},
    {"stage_id": "11-dual-replay-opened", "status": "ready" if real_return_replay_admission_ready and generation_acceptance_closure_ready else "blocked", "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}; generation_acceptance_closure_ready={generation_acceptance_closure_ready}"},
    {"stage_id": "12-actual-generation-full-claim", "status": "blocked", "evidence": f"actual_model_generation_ready={actual_model_generation_ready}"},
]
write_csv(run_dir / "receipt_bound_external_ack_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-receipt-bound-ack-package", "ready_to_run_now": "1", "command": "results/v61gr_post_gq_receipt_bound_external_ack_gate/ack_001/receipt_bound_external_ack_gate/VERIFY_RECEIPT_BOUND_EXTERNAL_ACK_GATE.sh", "purpose": "verify this receipt-bound ack package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gr_post_gq_receipt_bound_external_ack_gate/ack_001/receipt_bound_external_ack_gate/READY_NOW_COMMANDS.sh", "purpose": "show receipt-bound replay command"},
    {"command_id": "03-check-receipt-bound-ack", "ready_to_run_now": str(receipt_bound_ack_ready), "command": "results/v61gr_post_gq_receipt_bound_external_ack_gate/ack_001/receipt_bound_external_ack_gate/CHECK_RECEIPT_BOUND_ACK_READY.py", "purpose": "assert ack file is bound to the final operator input receipt"},
    {"command_id": "04-execute-receipt-bound-replay", "ready_to_run_now": str(receipt_bound_replay_admitted), "command": "V61GR_EXECUTE_REPLAY=1 V61GR_OPERATOR_INPUT_ROOT=<operator-input-root> V61GR_OUTPUT_ROOT=<output-root> V61GR_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh", "purpose": "execute guarded replay with ack statement loaded from receipt-bound file"},
]
write_csv(run_dir / "receipt_bound_external_ack_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("RECEIPT_BOUND_EXTERNAL_ACK_ROOT_ROWS.csv", run_dir / "receipt_bound_external_ack_root_rows.csv"),
    ("RECEIPT_BOUND_EXTERNAL_ACK_ROWS.csv", run_dir / "receipt_bound_external_ack_rows.csv"),
    ("RECEIPT_BOUND_EXTERNAL_ACK_TARGET_ROWS.csv", run_dir / "receipt_bound_external_ack_target_rows.csv"),
    ("RECEIPT_BOUND_EXTERNAL_ACK_STAGE_ROWS.csv", run_dir / "receipt_bound_external_ack_stage_rows.csv"),
    ("RECEIPT_BOUND_EXTERNAL_ACK_COMMAND_ROWS.csv", run_dir / "receipt_bound_external_ack_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "CHECK_RECEIPT_BOUND_ACK_READY.py").write_text(
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
        "    'receipt_bound_ack_ready': '1',",
        "    'ack_receipt_hash_binding_ready': '1',",
        "    'ack_statement_ready': '1',",
        "}",
        "errors = [f'{k}={row.get(k)}' for k, v in required.items() if row.get(k) != v]",
        "if errors:",
        "    raise SystemExit('receipt-bound ack remains blocked: ' + ';'.join(errors))",
        "print('receipt-bound external ack ready')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_RECEIPT_BOUND_ACK_READY.py").chmod(0o755)

(package_dir / "VERIFY_RECEIPT_BOUND_EXTERNAL_ACK_GATE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/RECEIPT_BOUND_EXTERNAL_ACK_ROOT_ROWS.csv\"",
        "test -s \"$DIR/RECEIPT_BOUND_EXTERNAL_ACK_ROWS.csv\"",
        "test -s \"$DIR/RECEIPT_BOUND_EXTERNAL_ACK_TARGET_ROWS.csv\"",
        "test -s \"$DIR/RECEIPT_BOUND_EXTERNAL_ACK_STAGE_ROWS.csv\"",
        "test -s \"$DIR/RECEIPT_BOUND_EXTERNAL_ACK_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/RECEIPT_BOUND_EXTERNAL_ACK_GATE_MANIFEST.json\"",
        "test -x \"$DIR/CHECK_RECEIPT_BOUND_ACK_READY.py\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gr package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_RECEIPT_BOUND_EXTERNAL_ACK_GATE.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'Receipt-bound ack preflight:'",
        "echo 'V61GR_OPERATOR_INPUT_ROOT=<operator-input-root> V61GR_OUTPUT_ROOT=<output-root> V61GR_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh'",
        "echo 'Receipt-bound replay execution:'",
        "echo 'V61GR_EXECUTE_REPLAY=1 V61GR_OPERATOR_INPUT_ROOT=<operator-input-root> V61GR_OUTPUT_ROOT=<output-root> V61GR_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

contains_real_external_evidence = int(real_external_review_return_rows > 0 or real_generation_result_artifacts > 0 or real_return_replay_admission_ready)
summary = {
    "v61gr_post_gq_receipt_bound_external_ack_gate_ready": 1,
    "v61gq_post_gp_first_real_slice_end_to_end_guarded_chain_ready": 1,
    "contains_real_external_evidence": contains_real_external_evidence,
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": operator_root_exists,
    "operator_input_root_outside_repo": operator_root_outside_repo,
    "operator_input_receipt_exists": receipt_exists,
    "operator_input_receipt_sha256": receipt_sha,
    "output_root_supplied": output_root_supplied,
    "output_root_outside_repo": output_root_outside_repo,
    "ack_file_supplied": ack_file_supplied,
    "ack_file_exists": ack_file_exists,
    "ack_file_outside_repo": ack_file_outside_repo,
    "ack_file_sha256": ack_file_sha,
    "ack_json_ready": ack_json_ready,
    "ack_source_class_ready": ack_source_class_ready,
    "ack_value_ready": ack_value_ready,
    "ack_statement_ready": ack_statement_ready,
    "ack_scope_ready": ack_scope_ready,
    "ack_receipt_hash_binding_ready": ack_receipt_hash_binding_ready,
    "ack_root_id_binding_ready": ack_root_id_binding_ready,
    "receipt_bound_ack_ready": receipt_bound_ack_ready,
    "receipt_bound_replay_admitted": receipt_bound_replay_admitted,
    "replay_requested": execute_replay,
    "replay_executed": replay_executed,
    "replay_exit_code": replay_exit_code,
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
    "checkpoint_payload_bytes_downloaded_by_v61gr": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "expected_external_ack": EXPECTED_ACK,
    "expected_scope": EXPECTED_SCOPE,
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "RECEIPT_BOUND_EXTERNAL_ACK_GATE_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "RECEIPT_BOUND_EXTERNAL_ACK_GATE.md").write_text(
    "\n".join([
        "# v61gr receipt-bound external ack gate",
        "",
        f"- receipt_bound_ack_ready={receipt_bound_ack_ready}",
        f"- receipt_bound_replay_admitted={receipt_bound_replay_admitted}",
        f"- replay_executed={replay_executed}",
        f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
        f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
        f"- actual_model_generation_ready={actual_model_generation_ready}",
        "",
        "This gate binds the external acknowledgement file to the final operator input receipt before replay execution.",
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
write_csv(run_dir / "receipt_bound_external_ack_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gq-ready", "status": "pass", "evidence": "v61gq ready"},
    {"gate": "operator-input-root", "status": "pass" if operator_root_exists and operator_root_outside_repo else "blocked", "evidence": f"exists={operator_root_exists}; outside_repo={operator_root_outside_repo}"},
    {"gate": "operator-input-receipt", "status": "pass" if receipt_exists else "blocked", "evidence": f"receipt_exists={receipt_exists}"},
    {"gate": "external-ack-file", "status": "pass" if ack_json_ready and ack_file_outside_repo else "blocked", "evidence": f"ack_json_ready={ack_json_ready}; outside_repo={ack_file_outside_repo}; errors={';'.join(ack_errors)}"},
    {"gate": "ack-finality", "status": "pass" if ack_value_ready and ack_statement_ready and ack_scope_ready and ack_source_class_ready else "blocked", "evidence": f"value={ack_value_ready}; statement={ack_statement_ready}; scope={ack_scope_ready}; source={ack_source_class_ready}"},
    {"gate": "receipt-hash-binding", "status": "pass" if ack_receipt_hash_binding_ready else "blocked", "evidence": f"ack_receipt_hash_binding_ready={ack_receipt_hash_binding_ready}"},
    {"gate": "receipt-bound-ack", "status": "pass" if receipt_bound_ack_ready else "blocked", "evidence": f"receipt_bound_ack_ready={receipt_bound_ack_ready}"},
    {"gate": "output-root", "status": "pass" if output_root_supplied and output_root_outside_repo else "blocked", "evidence": f"supplied={output_root_supplied}; outside_repo={output_root_outside_repo}"},
    {"gate": "receipt-bound-replay-admitted", "status": "pass" if receipt_bound_replay_admitted else "blocked", "evidence": f"receipt_bound_replay_admitted={receipt_bound_replay_admitted}"},
    {"gate": "replay-executed", "status": "pass" if replay_executed else "blocked", "evidence": f"replay_executed={replay_executed}; exit_code={replay_exit_code}"},
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
    "# V61GR Post-GQ Receipt-Bound External Ack Gate",
    "",
    "- v61gr_post_gq_receipt_bound_external_ack_gate_ready=1",
    f"- receipt_bound_ack_ready={receipt_bound_ack_ready}",
    f"- receipt_bound_replay_admitted={receipt_bound_replay_admitted}",
    f"- replay_executed={replay_executed}",
    f"- real_external_review_return_rows={real_external_review_return_rows}",
    f"- generation_result_accepted_rows={generation_result_accepted_rows}",
    f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
    f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
    f"- actual_model_generation_ready={actual_model_generation_ready}",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This gate accepts a durable ack JSON only when it is bound to the final operator input receipt hash.",
    "",
])
(run_dir / "V61GR_POST_GQ_RECEIPT_BOUND_EXTERNAL_ACK_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "expected_external_ack": EXPECTED_ACK,
    "expected_scope": EXPECTED_SCOPE,
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gr": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gr_post_gq_receipt_bound_external_ack_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
