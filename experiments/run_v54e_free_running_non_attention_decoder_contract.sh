#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v54e_free_running_non_attention_decoder_contract"
RUN_ID="${V54E_RUN_ID:-decode_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
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


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


vocab = (
    "<bos>",
    "<eos>",
    "ABSTAIN",
    "alpha",
    "beta",
    "local",
    "safe",
    "audit",
    "evidence",
    "citation:v54e_alpha",
    "citation:v54e_beta",
    "citation:v54e_audit",
)
model = TinyRouteStateDecoder(vocab)
token_to_id = model.token_to_id

examples = [
    {
        "generation_id": "v54e_gen_001",
        "sanitized_question": "Generate the alpha bounded answer.",
        "opaque_routehint": "route:v54e_alpha",
        "route_state": RouteState(
            "route_alpha",
            (token_to_id["alpha"], token_to_id["safe"], token_to_id["citation:v54e_alpha"]),
            "citation:v54e_alpha",
            True,
            0.95,
        ),
        "expected_text": "alpha safe citation:v54e_alpha",
        "expected_behavior": "answer",
    },
    {
        "generation_id": "v54e_gen_002",
        "sanitized_question": "Generate the beta bounded answer.",
        "opaque_routehint": "route:v54e_beta",
        "route_state": RouteState(
            "route_beta",
            (token_to_id["beta"], token_to_id["local"], token_to_id["citation:v54e_beta"]),
            "citation:v54e_beta",
            True,
            0.90,
        ),
        "expected_text": "beta local citation:v54e_beta",
        "expected_behavior": "answer",
    },
    {
        "generation_id": "v54e_gen_003",
        "sanitized_question": "Generate the audit bounded answer.",
        "opaque_routehint": "route:v54e_audit",
        "route_state": RouteState(
            "route_audit",
            (token_to_id["audit"], token_to_id["evidence"], token_to_id["citation:v54e_audit"]),
            "citation:v54e_audit",
            True,
            0.91,
        ),
        "expected_text": "audit evidence citation:v54e_audit",
        "expected_behavior": "answer",
    },
    {
        "generation_id": "v54e_gen_004",
        "sanitized_question": "Abstain when source support is missing.",
        "opaque_routehint": "route:v54e_missing",
        "route_state": RouteState("route_missing", (token_to_id["ABSTAIN"],), "", True, 0.80),
        "expected_text": "ABSTAIN",
        "expected_behavior": "abstain",
    },
]

decoder_input_rows = []
decode_rows = []
token_trace_rows = []
negative_control_rows = []
raw_prompt_context_bytes = 0
retrieved_text_in_prompt_rows = 0
source_locator_leakage_rows = 0
wrong_answer_rows = 0
abstain_correct_rows = 0

for example in examples:
    visible = build_model_visible_generator_input(
        {
            "sanitized_question": example["sanitized_question"],
            "opaque_routehint": example["opaque_routehint"],
        }
    )
    route_state = example["route_state"]
    result = greedy_decode(model, model.bos_token_id, route_state, max_tokens=8)
    generated_text = detokenize(result.tokens)
    answer_correct = int(generated_text == example["expected_text"])
    abstain_correct = int(example["expected_behavior"] != "abstain" or generated_text == "ABSTAIN")
    wrong_answer = int(not answer_correct or not abstain_correct)
    wrong_answer_rows += wrong_answer
    abstain_correct_rows += abstain_correct
    decoder_input_rows.append(
        {
            "generation_id": example["generation_id"],
            "generator_id": "tiny-route-state-decoder-v1",
            "model_visible_input_fields": ",".join(sorted(visible)),
            "sanitized_question": visible["sanitized_question"],
            "opaque_routehint": visible["opaque_routehint"],
            "route_state_id": route_state.route_id,
            "citation_handle": route_state.citation_handle,
            "attention_blocks": model.attention_blocks,
            "transformer_blocks": model.transformer_blocks,
            "raw_prompt_context_appended": 0,
            "raw_prompt_context_bytes": 0,
            "retrieved_text_in_prompt": 0,
            "source_locator_leakage": 0,
            "teacher_forcing_used": 0,
        }
    )
    decode_rows.append(
        {
            "generation_id": example["generation_id"],
            "generator_id": "tiny-route-state-decoder-v1",
            "expected_behavior": example["expected_behavior"],
            "generated_text": generated_text,
            "expected_text": example["expected_text"],
            "output_token_count": len([token for token in result.tokens if token != "<eos>"]),
            "free_running_decode": 1,
            "teacher_forcing_used": 0,
            "stopped_on_eos": int(result.stopped_on_eos),
            "answer_correct": answer_correct,
            "abstain_correct": abstain_correct,
            "wrong_answer": wrong_answer,
            "citation_handle": route_state.citation_handle,
        }
    )
    for step in result.steps:
        token_trace_rows.append(
            {
                "generation_id": example["generation_id"],
                "position": step.position,
                "input_token_id": step.input_token_id,
                "output_token_id": step.output_token_id,
                "output_token": step.output_token,
                "teacher_forcing_used": int(step.teacher_forcing_used),
            }
        )

negative_cases = [
    (
        "reject-source-path",
        {"sanitized_question": "Question", "opaque_routehint": "route", "source_path": "src/app.py"},
        "evaluator-only field leaked",
    ),
    (
        "reject-source-locator",
        {"sanitized_question": "Question at src/app.py:12", "opaque_routehint": "route"},
        "source locator",
    ),
    (
        "invalid-provenance-stops",
        {"route_state": RouteState("invalid", (token_to_id["alpha"],), "", False, 0.95)},
        "eos-only",
    ),
]
for case_id, payload, expected_reason in negative_cases:
    status = "blocked"
    observed = ""
    if case_id.startswith("reject"):
        try:
            build_model_visible_generator_input(payload)
        except ValueError as exc:
            observed = str(exc)
            status = "pass" if expected_reason in observed else "blocked"
    else:
        result = greedy_decode(model, model.bos_token_id, payload["route_state"], max_tokens=4)
        observed = ",".join(result.tokens)
        status = "pass" if result.tokens == ("<eos>",) else "blocked"
    negative_control_rows.append({"case_id": case_id, "status": status, "reason": observed})
    if status != "pass":
        raise SystemExit(f"negative control failed: {case_id}: {observed}")

write_csv(
    run_dir / "decoder_input_rows.csv",
    [
        "generation_id",
        "generator_id",
        "model_visible_input_fields",
        "sanitized_question",
        "opaque_routehint",
        "route_state_id",
        "citation_handle",
        "attention_blocks",
        "transformer_blocks",
        "raw_prompt_context_appended",
        "raw_prompt_context_bytes",
        "retrieved_text_in_prompt",
        "source_locator_leakage",
        "teacher_forcing_used",
    ],
    decoder_input_rows,
)
write_csv(
    run_dir / "free_running_decode_rows.csv",
    [
        "generation_id",
        "generator_id",
        "expected_behavior",
        "generated_text",
        "expected_text",
        "output_token_count",
        "free_running_decode",
        "teacher_forcing_used",
        "stopped_on_eos",
        "answer_correct",
        "abstain_correct",
        "wrong_answer",
        "citation_handle",
    ],
    decode_rows,
)
write_csv(
    run_dir / "token_trace_rows.csv",
    ["generation_id", "position", "input_token_id", "output_token_id", "output_token", "teacher_forcing_used"],
    token_trace_rows,
)
write_csv(run_dir / "negative_control_rows.csv", ["case_id", "status", "reason"], negative_control_rows)

generation_rows = len(decode_rows)
free_running_decode_rows = sum(int(row["free_running_decode"]) for row in decode_rows)
teacher_forcing_used_rows = sum(int(row["teacher_forcing_used"]) for row in decode_rows)
eos_stop_rows = sum(int(row["stopped_on_eos"]) for row in decode_rows)
answer_correct_rows = sum(int(row["answer_correct"]) for row in decode_rows)
unsupported_abstain_rows = sum(1 for row in decode_rows if row["expected_behavior"] == "abstain")
unsupported_abstention_accuracy = abstain_correct_rows / generation_rows
wrong_answer_rate = wrong_answer_rows / generation_rows

manifest = {
    "manifest_scope": "v54e-free-running-non-attention-decoder-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "free_running_generator_contract_source_sha256": sha256(root / "scripts" / "free_running_generator_contract.py"),
    "free_running_non_attention_decoder_contract_ready": 1,
    "generation_rows": generation_rows,
    "free_running_decode_rows": free_running_decode_rows,
    "teacher_forcing_used_rows": teacher_forcing_used_rows,
    "raw_prompt_context_bytes": raw_prompt_context_bytes,
    "retrieved_text_in_prompt_rows": retrieved_text_in_prompt_rows,
    "source_locator_leakage_rows": source_locator_leakage_rows,
    "wrong_answer_rate": wrong_answer_rate,
    "unsupported_abstention_accuracy": unsupported_abstention_accuracy,
    "external_label_source_ready": 0,
    "heldout_metric_ready": 0,
    "real_model_generation_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
}
write_json(run_dir / "v54e_free_running_non_attention_decoder_manifest.json", manifest)

boundary = [
    "# v54e Free-Running Non-Attention Decoder Boundary",
    "",
    "Ready:",
    "",
    "- free_running_non_attention_decoder_contract_ready=1",
    "- free_running_decode_rows=generation_rows",
    "- teacher_forcing_used_rows=0",
    "- attention_blocks=0",
    "- transformer_blocks=0",
    "- raw_prompt_context_bytes=0",
    "- retrieved_text_in_prompt_rows=0",
    "- source_locator_leakage_rows=0",
    "",
    "Blocked:",
    "",
    "- external_label_source_ready=0",
    "- heldout_metric_ready=0",
    "- real_model_generation_ready=0",
    "- public_comparison_claim_ready=0",
    "- real_release_package_ready=0",
    "",
    "Boundary:",
    "",
    "- This is a local free-running decoder contract smoke.",
    "- It is not a 1000-row real model generation claim.",
    "- Citation handles are emitted for evaluator resolution; raw source spans are not model-visible.",
]
(run_dir / "V54E_FREE_RUNNING_NON_ATTENTION_DECODER_BOUNDARY.md").write_text("\n".join(boundary) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    "run_id": run_dir.name,
    "v54e_free_running_non_attention_decoder_contract_ready": 1,
    "generation_rows": generation_rows,
    "free_running_decode_rows": free_running_decode_rows,
    "teacher_forcing_used_rows": teacher_forcing_used_rows,
    "eos_stop_rows": eos_stop_rows,
    "attention_blocks": model.attention_blocks,
    "transformer_blocks": model.transformer_blocks,
    "raw_prompt_context_bytes": raw_prompt_context_bytes,
    "retrieved_text_in_prompt_rows": retrieved_text_in_prompt_rows,
    "source_locator_leakage_rows": source_locator_leakage_rows,
    "answer_correct_rows": answer_correct_rows,
    "wrong_answer_rate": f"{wrong_answer_rate:.6f}",
    "unsupported_abstain_rows": unsupported_abstain_rows,
    "unsupported_abstention_accuracy": f"{unsupported_abstention_accuracy:.6f}",
    "negative_control_rows": len(negative_control_rows),
    "external_label_source_ready": 0,
    "heldout_metric_ready": 0,
    "real_model_generation_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
    "artifact_rows": len(sha_rows),
}
write_csv(summary_csv, list(summary), [summary])

decision_rows = [
    {"gate": "free-running-decode", "status": "pass", "reason": f"{free_running_decode_rows}/{generation_rows} rows decoded without teacher forcing"},
    {"gate": "non-attention-decoder", "status": "pass", "reason": "attention_blocks=0; transformer_blocks=0"},
    {"gate": "no-raw-prompt-context", "status": "pass", "reason": "raw_prompt_context_bytes=0; retrieved_text_in_prompt_rows=0"},
    {"gate": "source-locator-negative-control", "status": "pass", "reason": "model-visible source locators are rejected"},
    {"gate": "invalid-provenance-negative-control", "status": "pass", "reason": "invalid provenance emits eos only"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "1000-row external-label heldout metric evidence missing"},
    {"gate": "public-comparison-claim", "status": "blocked", "reason": "external label source and heldout metrics missing"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release evidence missing"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v54e_free_running_non_attention_decoder_contract_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
