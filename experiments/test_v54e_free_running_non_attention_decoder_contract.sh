#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v54e_free_running_non_attention_decoder_contract/decode_001"
SUMMARY_CSV="$RESULTS_DIR/v54e_free_running_non_attention_decoder_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v54e_free_running_non_attention_decoder_contract_decision.csv"

"$ROOT_DIR/experiments/run_v54e_free_running_non_attention_decoder_contract.sh" >/dev/null

"$ROOT_DIR/tools/verify_artifact.py" v54-free-running-decoder \
  "$ROOT_DIR/v54/free_running_non_attention_decoder_contract.json" \
  --summary "$SUMMARY_CSV" \
  --decision "$DECISION_CSV" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
sys.path.insert(0, str(root / "scripts"))

from free_running_generator_contract import (  # noqa: E402
    RouteState,
    TinyRouteStateDecoder,
    build_model_visible_generator_input,
    detokenize,
    greedy_decode,
)


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
    "v54e_free_running_non_attention_decoder_contract_ready": "1",
    "generation_rows": "4",
    "free_running_decode_rows": "4",
    "teacher_forcing_used_rows": "0",
    "eos_stop_rows": "4",
    "attention_blocks": "0",
    "transformer_blocks": "0",
    "raw_prompt_context_bytes": "0",
    "retrieved_text_in_prompt_rows": "0",
    "source_locator_leakage_rows": "0",
    "answer_correct_rows": "4",
    "wrong_answer_rate": "0.000000",
    "unsupported_abstain_rows": "1",
    "unsupported_abstention_accuracy": "1.000000",
    "negative_control_rows": "3",
    "external_label_source_ready": "0",
    "heldout_metric_ready": "0",
    "real_model_generation_ready": "0",
    "public_comparison_claim_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v54e {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "free-running-decode",
    "non-attention-decoder",
    "no-raw-prompt-context",
    "source-locator-negative-control",
    "invalid-provenance-negative-control",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v54e gate should pass: {gate}")
for gate in ["real-model-generation", "public-comparison-claim", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54e gate should remain blocked: {gate}")

required_files = [
    "decoder_input_rows.csv",
    "free_running_decode_rows.csv",
    "token_trace_rows.csv",
    "negative_control_rows.csv",
    "v54e_free_running_non_attention_decoder_manifest.json",
    "V54E_FREE_RUNNING_NON_ATTENTION_DECODER_BOUNDARY.md",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v54e artifact: {rel}")

manifest = json.loads((run_dir / "v54e_free_running_non_attention_decoder_manifest.json").read_text(encoding="utf-8"))
if manifest.get("free_running_non_attention_decoder_contract_ready") != 1:
    raise SystemExit("v54e manifest should mark decoder contract ready")
for field in [
    "external_label_source_ready",
    "heldout_metric_ready",
    "real_model_generation_ready",
    "public_comparison_claim_ready",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v54e manifest should keep {field}=0")

inputs = read_csv(run_dir / "decoder_input_rows.csv")
decodes = read_csv(run_dir / "free_running_decode_rows.csv")
trace = read_csv(run_dir / "token_trace_rows.csv")
negative = read_csv(run_dir / "negative_control_rows.csv")
if len(inputs) != 4 or len(decodes) != 4 or len(negative) != 3:
    raise SystemExit("v54e row counts mismatch")
for row in inputs:
    if row["model_visible_input_fields"] != "opaque_routehint,sanitized_question":
        raise SystemExit("v54e model visible inputs should be sanitized question plus opaque routehint")
    for field in [
        "attention_blocks",
        "transformer_blocks",
        "raw_prompt_context_appended",
        "raw_prompt_context_bytes",
        "retrieved_text_in_prompt",
        "source_locator_leakage",
        "teacher_forcing_used",
    ]:
        if row[field] != "0":
            raise SystemExit(f"v54e decoder input should keep {field}=0")
for row in decodes:
    if row["free_running_decode"] != "1" or row["teacher_forcing_used"] != "0" or row["stopped_on_eos"] != "1":
        raise SystemExit("v54e decode rows should be free-running and eos-terminated")
    if row["answer_correct"] != "1" or row["abstain_correct"] != "1" or row["wrong_answer"] != "0":
        raise SystemExit("v54e decode rows should be locally correct with zero wrong answers")
if any(row["teacher_forcing_used"] != "0" for row in trace):
    raise SystemExit("v54e token trace must not use teacher forcing")
if any(row["status"] != "pass" for row in negative):
    raise SystemExit("v54e negative controls should pass")

vocab = ("<bos>", "<eos>", "A", "B")
model = TinyRouteStateDecoder(vocab)
route = RouteState("route", (model.token_to_id["A"], model.token_to_id["B"]), "citation:test", True, 1.0)
result = greedy_decode(model, model.bos_token_id, route, max_tokens=4)
if detokenize(result.tokens) != "A B":
    raise SystemExit("greedy_decode should feed predictions forward until eos")
if any(step.teacher_forcing_used for step in result.steps):
    raise SystemExit("greedy_decode must not mark teacher forcing")
try:
    build_model_visible_generator_input({"sanitized_question": "See src/main.cpp:44", "opaque_routehint": "route"})
except ValueError:
    pass
else:
    raise SystemExit("model-visible source locators must be rejected")
try:
    build_model_visible_generator_input({"sanitized_question": "Question", "opaque_routehint": "route", "expected_answer": "secret"})
except ValueError:
    pass
else:
    raise SystemExit("evaluator-only fields must be rejected")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v54e sha mismatch: {rel}")

boundary = (run_dir / "V54E_FREE_RUNNING_NON_ATTENTION_DECODER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "free_running_non_attention_decoder_contract_ready=1",
    "free_running_decode_rows=generation_rows",
    "teacher_forcing_used_rows=0",
    "real_model_generation_ready=0",
    "not a 1000-row real model generation claim",
]:
    if snippet not in boundary:
        raise SystemExit(f"v54e boundary missing: {snippet}")
PY

echo "v54e free-running non-attention decoder contract smoke passed"
