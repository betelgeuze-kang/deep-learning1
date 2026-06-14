#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gs_post_gr_external_ack_packet_builder"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/external_ack_packet_builder"
READY_WITNESS_DIR="${TMPDIR:-/tmp}/v61gs ready witness dir"
ACK_ROOT="${TMPDIR:-/tmp}/v61gs ack packet roots"

V61GR_RUN_ID="ack_001" V61GR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh" >/dev/null
V61GS_REUSE_EXISTING="${V61GS_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gs_post_gr_external_ack_packet_builder.sh" >/dev/null

"$PACKAGE_DIR/VERIFY_EXTERNAL_ACK_PACKET_BUILDER.sh" >/dev/null
"$PACKAGE_DIR/READY_NOW_COMMANDS.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
package_dir = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61gs_post_gr_external_ack_packet_builder_ready": "1",
    "v61gr_post_gq_receipt_bound_external_ack_gate_ready": "1",
    "contains_real_external_evidence": "0",
    "operator_input_root_supplied": "0",
    "operator_input_root_exists": "0",
    "operator_input_root_outside_repo": "0",
    "operator_input_receipt_exists": "0",
    "ack_file_supplied": "0",
    "ack_file_exists": "0",
    "ack_file_outside_repo": "0",
    "ack_file_preflight_ready": "0",
    "ack_template_bound_to_receipt": "0",
    "schema_file_rows": "1",
    "template_file_rows": "1",
    "command_rows": "4",
    "ready_command_rows": "2",
    "blocked_command_rows": "2",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "dual_external_return_real_ready": "0",
    "real_return_replay_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "payload_like_package_file_rows": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gs": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gs default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_ack_packet_builder_source_rows.csv",
    "external_ack_packet_preflight_rows.csv",
    "external_ack_packet_command_rows.csv",
    "external_ack_packet_package_file_rows.csv",
    "V61GS_POST_GR_EXTERNAL_ACK_PACKET_BUILDER_BOUNDARY.md",
    "v61gs_post_gr_external_ack_packet_builder_manifest.json",
    "v61gs_post_gr_external_ack_packet_builder_summary.csv",
    "v61gs_post_gr_external_ack_packet_builder_decision.csv",
    "external_ack_packet_builder/EXTERNAL_ACK_SCHEMA.json",
    "external_ack_packet_builder/EXTERNAL_ACK.json.template",
    "external_ack_packet_builder/VALIDATE_EXTERNAL_ACK_FILE.py",
    "external_ack_packet_builder/EXTERNAL_ACK_PACKET_PREFLIGHT_ROWS.csv",
    "external_ack_packet_builder/EXTERNAL_ACK_PACKET_COMMAND_ROWS.csv",
    "external_ack_packet_builder/EXTERNAL_ACK_PACKET_BUILDER_MANIFEST.json",
    "external_ack_packet_builder/VERIFY_EXTERNAL_ACK_PACKET_BUILDER.sh",
    "external_ack_packet_builder/READY_NOW_COMMANDS.sh",
    "source_v61gr/v61gr_post_gq_receipt_bound_external_ack_gate_summary.csv",
    "source_v61gr/v61gr_post_gq_receipt_bound_external_ack_gate_decision.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61gs artifact: {rel}")
    if path.stat().st_size == 0:
        raise SystemExit(f"empty v61gs artifact: {rel}")

for rel in ["VALIDATE_EXTERNAL_ACK_FILE.py", "VERIFY_EXTERNAL_ACK_PACKET_BUILDER.sh", "READY_NOW_COMMANDS.sh"]:
    if not os.access(package_dir / rel, os.X_OK):
        raise SystemExit(f"v61gs executable bit missing: {rel}")

template = json.loads((package_dir / "EXTERNAL_ACK.json.template").read_text(encoding="utf-8"))
if template.get("operator_input_receipt_sha256") != "REPLACE_WITH_OPERATOR_INPUT_RECEIPT_SHA256":
    raise SystemExit("v61gs default template should remain placeholder-bound")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gr-ready", "real-counter-unchanged", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gs default expected pass decision: {gate}")
for gate in ["operator-input-root", "operator-input-receipt", "ack-template-bound-to-receipt", "ack-file-preflight"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gs default expected blocked decision: {gate}")

validator = subprocess.run(
    [str(package_dir / "VALIDATE_EXTERNAL_ACK_FILE.py")],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if validator.returncode == 0:
    raise SystemExit("v61gs default validator must fail without ack env")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gs sha256 mismatch: {rel}")

print("v61gs default ack packet smoke passed")
PY

rm -rf "$READY_WITNESS_DIR" "$ACK_ROOT"
mkdir -p "$READY_WITNESS_DIR" "$ACK_ROOT"

python3 - "$READY_WITNESS_DIR" <<'PY'
import sys
from pathlib import Path

ready = Path(sys.argv[1])
texts = {
    "review_comment.txt": "External reviewer confirms selected answer support, citation alignment, and policy fitness for this bounded subset.\n",
    "adjudication_reason.txt": "Independent adjudicator accepts the selected p0 answer after comparing review notes and source evidence.\n",
    "credential_statement.txt": "Reviewer identity and credentials are declared for this bounded subset review with accountable scope.\n",
    "conflict_statement.txt": "Reviewer declares no blocking conflict for the selected repository, answer, source, and evaluation scope.\n",
    "answer_text.txt": "The generated answer is recorded as final operator output for the selected source-bound query.\n",
    "run_transcript.txt": "Operator transcript records checkpoint path, prompt, output, citation check, and latency observation.\n",
    "source_file.txt": "Cited source material for the selected span is recorded and bound to the returned citation row.\n",
}
for name, text in texts.items():
    (ready / name).write_text(text, encoding="utf-8")
PY

V61GO_RUN_ID="gs_ack_source" \
V61GO_EXECUTE_MATERIALIZE=1 \
V61GI_CONTENT_WITNESS_DIR="$READY_WITNESS_DIR" \
V61GI_MINIMAL_SLICE_ROWS_CSV="$ACK_ROOT/minimal_slice_rows.csv" \
V61GI_MINIMAL_SLICE_ROWS_OVERWRITE=1 \
V61GI_OPERATOR_INPUT_ROOT="$ACK_ROOT/operator_input_root" \
V61GI_OUTPUT_ROOT="$ACK_ROOT/output_root" \
V61GI_REVIEWER_ID="reviewer_alpha_001" \
V61GI_ADJUDICATOR_ID="adjudicator_alpha_001" \
V61GI_GENERATION_ID="generation_alpha_001" \
V61GI_CITATION_ID="citation_alpha_001" \
V61GI_CHECKPOINT_ROOT="$ACK_ROOT/checkpoint_root" \
V61GI_LATENCY_ROW_ID="latency_alpha_001" \
V61GI_PROMPT_TOKENS="128" \
V61GI_OUTPUT_TOKENS="32" \
V61GI_PREFILL_MS="11.5" \
V61GI_DECODE_MS="22.5" \
V61GI_TOTAL_MS="34.0" \
V61GI_TOKENS_PER_SECOND="940.0" \
V61GI_V53_AUTHORITY_STATEMENT="Final external reviewer authority statement for the bounded first return slice with accountable identity." \
V61GI_V61_AUTHORITY_STATEMENT="Final external generation authority statement for the bounded first return slice with checkpoint accountability." \
V61GI_EXTERNAL_RETURN_ATTESTATION="Final external return attestation binds review and generation artifacts to immutable hashes." \
V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT="Final external operator authority for first slice assembly with independent accountability." \
V61GO_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null

python3 - "$ACK_ROOT/operator_input_root" "$ACK_ROOT/ack_ready.json" "$ACK_ROOT/ack_bad_hash.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

operator_root = Path(sys.argv[1])
ack_ready = Path(sys.argv[2])
ack_bad = Path(sys.argv[3])
receipt = operator_root / "OPERATOR_INPUT_RECEIPT.json"
h = hashlib.sha256()
h.update(receipt.read_bytes())
receipt_sha = "sha256:" + h.hexdigest()
root_id = json.loads(receipt.read_text(encoding="utf-8")).get("operator_input_root_id", operator_root.name)
payload = {
    "acknowledgement_source_class": "external-operator-return-ack",
    "ack_scope": "first-real-slice-dual-replay",
    "external_return_authority_ack": "operator-confirmed-real-external-review-and-generation-return",
    "external_return_authority_statement": "Accountable external operator confirms the selected review and generation return files are final, source bound, receipt checked, and ready for the bounded dual replay gate.",
    "operator_input_receipt_sha256": receipt_sha,
    "operator_input_root_id": root_id,
}
ack_ready.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
payload["operator_input_receipt_sha256"] = "sha256:" + "0" * 64
ack_bad.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61GS_RUN_ID="ack_ready" \
V61GS_OPERATOR_INPUT_ROOT="$ACK_ROOT/operator_input_root" \
V61GS_EXTERNAL_ACK_FILE="$ACK_ROOT/ack_ready.json" \
V61GS_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gs_post_gr_external_ack_packet_builder.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/ack_ready" "$ACK_ROOT/ack_ready.json" <<'PY'
import csv
import json
import subprocess
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
run_dir = Path(sys.argv[3])
ack_file = Path(sys.argv[4])
package_dir = run_dir / "external_ack_packet_builder"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "operator_input_root_supplied": "1",
    "operator_input_root_exists": "1",
    "operator_input_root_outside_repo": "1",
    "operator_input_receipt_exists": "1",
    "ack_file_supplied": "1",
    "ack_file_exists": "1",
    "ack_file_outside_repo": "1",
    "ack_file_preflight_ready": "1",
    "ack_template_bound_to_receipt": "1",
    "ready_command_rows": "4",
    "blocked_command_rows": "0",
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gs ack-ready {field}: expected {value}, got {summary.get(field)}")

schema = json.loads((package_dir / "EXTERNAL_ACK_SCHEMA.json").read_text(encoding="utf-8"))
template = json.loads((package_dir / "EXTERNAL_ACK.json.template").read_text(encoding="utf-8"))
if schema.get("operator_input_receipt_sha256") != summary.get("operator_input_receipt_sha256"):
    raise SystemExit("v61gs ack-ready schema did not bind receipt sha")
if template.get("operator_input_receipt_sha256") != summary.get("operator_input_receipt_sha256"):
    raise SystemExit("v61gs ack-ready template did not prefill receipt sha")

validator = subprocess.run(
    [str(package_dir / "VALIDATE_EXTERNAL_ACK_FILE.py")],
    env={"V61GS_EXTERNAL_ACK_FILE": str(ack_file)},
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if validator.returncode != 0:
    raise SystemExit(f"v61gs ack-ready validator should pass: {validator.stdout} {validator.stderr}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["operator-input-root", "operator-input-receipt", "ack-template-bound-to-receipt", "ack-file-preflight"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gs ack-ready expected pass decision: {gate}")

print("v61gs receipt-bound ack packet ready smoke passed")
PY

V61GS_RUN_ID="ack_bad_hash" \
V61GS_OPERATOR_INPUT_ROOT="$ACK_ROOT/operator_input_root" \
V61GS_EXTERNAL_ACK_FILE="$ACK_ROOT/ack_bad_hash.json" \
V61GS_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gs_post_gr_external_ack_packet_builder.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/$PREFIX/ack_bad_hash" "$ACK_ROOT/ack_bad_hash.json" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
run_dir = Path(sys.argv[3])
ack_file = Path(sys.argv[4])
package_dir = run_dir / "external_ack_packet_builder"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("ack_file_exists") != "1" or summary.get("ack_file_preflight_ready") != "0":
    raise SystemExit("v61gs bad-hash should see ack file but block preflight")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("ack-file-preflight") != "blocked":
    raise SystemExit("v61gs bad-hash ack-file-preflight should be blocked")

validator = subprocess.run(
    [str(package_dir / "VALIDATE_EXTERNAL_ACK_FILE.py")],
    env={"V61GS_EXTERNAL_ACK_FILE": str(ack_file)},
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if validator.returncode == 0:
    raise SystemExit("v61gs bad-hash validator must fail")
if "receipt-sha-mismatch" not in (validator.stdout + validator.stderr):
    raise SystemExit(f"v61gs bad-hash validator did not report hash mismatch: {validator.stdout} {validator.stderr}")

print("v61gs receipt hash mismatch validation smoke passed")
PY

V61GO_RUN_ID="materialize_001" V61GO_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null
V61GJ_RUN_ID="receiver_001" V61GJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gj_post_gi_operator_input_receiver.sh" >/dev/null
V61GP_RUN_ID="replay_001" V61GP_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null
V61GQ_RUN_ID="chain_001" V61GQ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gq_post_gp_first_real_slice_end_to_end_guarded_chain.sh" >/dev/null
V61GR_RUN_ID="ack_001" V61GR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh" >/dev/null
V61GS_RUN_ID="packet_001" V61GS_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61gs_post_gr_external_ack_packet_builder.sh" >/dev/null
