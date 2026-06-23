#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v54f_free_running_generation_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v54f_free_running_generation_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v54f_free_running_generation_evidence_intake_decision.csv"
SPOOF_DIR="$RESULTS_DIR/v54f_spoofed_generation_evidence"

"$ROOT_DIR/experiments/run_v54f_free_running_generation_evidence_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
    "v54f_free_running_generation_evidence_intake_ready": "1",
    "generation_evidence_dir_supplied": "0",
    "supplied_generation_evidence_ready": "0",
    "real_model_generation_ready": "0",
    "expected_generation_rows": "1000",
    "generation_rows": "0",
    "free_running_decode_rows": "0",
    "external_label_source_ready": "0",
    "heldout_metric_ready": "0",
    "network_or_download_used": "0",
    "gpu_execution_used": "0",
    "checkpoint_downloaded": "0",
    "external_api_used": "0",
    "v1_0_comparison_ready": "0",
    "public_comparison_claim_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "generation-evidence-dir-missing",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v54f default {field}: expected {value}, got {summary.get(field)}")
for rel in [
    "generation_required_field_rows.csv",
    "free_running_generation_template_rows.csv",
    "generation_validation_rows.csv",
    "source_v53i_complete_source_query_rows.csv",
    "V54F_FREE_RUNNING_GENERATION_EVIDENCE_INTAKE_BOUNDARY.md",
    "v54f_free_running_generation_evidence_intake_manifest.json",
    "sha256_manifest.csv",
]:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v54f artifact: {rel}")
templates = read_csv(run_dir / "free_running_generation_template_rows.csv")
if len(templates) != 1000:
    raise SystemExit("v54f should emit a 1000-row generation template")
fields = read_csv(run_dir / "generation_required_field_rows.csv")
for required in ["free_running_decode", "teacher_forcing_used", "raw_prompt_context_bytes", "external_label_source_ready", "heldout_metric_ready"]:
    if not any(row["field"] == required for row in fields):
        raise SystemExit(f"v54f required field rows missing {required}")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("v53i-frozen-query-input") != "pass":
    raise SystemExit("v54f should bind the frozen v53i query input")
for gate in ["generation-evidence-dir", "free-running-generation-evidence", "real-model-generation", "public-comparison-claim", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54f default should keep {gate} blocked")
manifest = json.loads((run_dir / "v54f_free_running_generation_evidence_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("real_model_generation_ready") != 0:
    raise SystemExit("v54f manifest must keep real model generation closed by default")
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in [
    "generation_required_field_rows.csv",
    "free_running_generation_template_rows.csv",
    "generation_validation_rows.csv",
    "source_v53i_complete_source_query_rows.csv",
    "V54F_FREE_RUNNING_GENERATION_EVIDENCE_INTAKE_BOUNDARY.md",
    "v54f_free_running_generation_evidence_intake_manifest.json",
]:
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v54f sha mismatch: {rel}")
PY

rm -rf "$SPOOF_DIR"
mkdir -p "$SPOOF_DIR"

python3 - "$RESULTS_DIR" "$SPOOF_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

results = Path(sys.argv[1])
spoof = Path(sys.argv[2])
query_path = results / "v53i_complete_source_query_instantiation/instantiate_001/complete_source_query_rows.csv"
query_rows = list(csv.DictReader(query_path.open(newline="", encoding="utf-8")))
qhash = "sha256:" + hashlib.sha256(query_path.read_bytes()).hexdigest()

identity = {
    "generator_id": "replace-with-generator",
    "model_revision": "placeholder",
    "model_artifact_sha256": "sha256:" + "a" * 64,
    "decoder_contract_sha256": "sha256:" + "b" * 64,
    "runtime": "placeholder",
    "runtime_version": "placeholder",
    "hardware": "placeholder",
    "non_fixture_declared": 0,
    "external_api_used": 0,
    "training_or_checkpoint_download_used": 0,
    "attention_blocks": 0,
    "transformer_blocks": 0,
}
(spoof / "generator_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(spoof / "label_source.json").write_text(json.dumps({"external_label_source_ready": 0, "non_fixture_declared": 0, "label_rows": 0}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(spoof / "metric_thresholds.json").write_text(json.dumps({"wrong_answer_rate_max": 0.05, "unsupported_abstention_accuracy_min": 0.95}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
with (spoof / "heldout_metric_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["heldout_metric_ready", "generation_rows", "wrong_answer_rate", "unsupported_abstention_accuracy"], lineterminator="\n")
    writer.writeheader()
    writer.writerow({"heldout_metric_ready": "0", "generation_rows": "1", "wrong_answer_rate": "1.0", "unsupported_abstention_accuracy": "0.0"})
fields = [
    "generation_id", "query_id", "corpus_snapshot_sha256", "sanitized_question_sha256", "generator_id",
    "free_running_decode", "teacher_forcing_used", "raw_prompt_context_bytes", "retrieved_text_in_prompt",
    "source_locator_leakage", "generated_text", "citation_handle", "raw_output_sha256", "output_token_count",
    "latency_ns", "peak_memory_mb", "answer_correct", "citation_correct", "abstain_correct", "wrong_answer",
    "evaluator_version", "external_api_used",
]
row = query_rows[0]
raw_text = "fixture answer\nsrc/app.py:12"
with (spoof / "free_running_generation_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    writer.writerow({
        "generation_id": "spoof-001",
        "query_id": row["query_id"],
        "corpus_snapshot_sha256": qhash,
        "sanitized_question_sha256": "sha256:" + hashlib.sha256(row["question"].encode()).hexdigest(),
        "generator_id": identity["generator_id"],
        "free_running_decode": "0",
        "teacher_forcing_used": "1",
        "raw_prompt_context_bytes": "128",
        "retrieved_text_in_prompt": "1",
        "source_locator_leakage": "1",
        "generated_text": "fixture answer",
        "citation_handle": "src/app.py:12",
        "raw_output_sha256": "sha256:" + hashlib.sha256(raw_text.encode()).hexdigest(),
        "output_token_count": "0",
        "latency_ns": "0",
        "peak_memory_mb": "0",
        "answer_correct": "0",
        "citation_correct": "0",
        "abstain_correct": "0",
        "wrong_answer": "1",
        "evaluator_version": "placeholder",
        "external_api_used": "0",
    })
PY

V54F_FREE_RUNNING_GENERATION_EVIDENCE_DIR="$SPOOF_DIR" "$ROOT_DIR/experiments/run_v54f_free_running_generation_evidence_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary["generation_evidence_dir_supplied"] != "1":
    raise SystemExit("v54f spoof should record supplied evidence dir")
for field in [
    "supplied_generation_evidence_ready",
    "real_model_generation_ready",
    "external_label_source_ready",
    "heldout_metric_ready",
    "public_comparison_claim_ready",
    "real_release_package_ready",
]:
    if summary[field] != "0":
        raise SystemExit(f"v54f spoof must keep {field}=0")
if summary["generation_rows"] != "1" or summary["free_running_decode_rows"] != "0":
    raise SystemExit("v54f spoof should not count one-row teacher-forced output as free-running evidence")
if summary["teacher_forcing_used_rows"] != "1" or summary["raw_prompt_context_bytes"] != "128":
    raise SystemExit("v54f spoof should expose teacher forcing and raw context")
for field in ["network_or_download_used", "gpu_execution_used", "checkpoint_downloaded", "external_api_used", "v1_0_comparison_ready"]:
    if summary[field] != "0":
        raise SystemExit(f"v54f spoof must keep {field}=0")
if summary["source_locator_leakage_rows"] != "1" or summary["retrieved_text_in_prompt_rows"] != "1":
    raise SystemExit("v54f spoof should expose source locator/retrieved text leakage")
validation = read_csv(run_dir / "generation_validation_rows.csv")
if not any(row["check"] == "supplied-generation-evidence" and row["status"] == "blocked" for row in validation):
    raise SystemExit("v54f spoof should block supplied generation evidence")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("generation-evidence-dir") != "pass":
    raise SystemExit("v54f spoof evidence dir gate should pass")
for gate in ["free-running-generation-evidence", "real-model-generation", "public-comparison-claim", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54f spoof should keep {gate} blocked")
PY

"$ROOT_DIR/experiments/run_v54f_free_running_generation_evidence_intake.sh" >/dev/null

echo "v54f free-running generation evidence intake smoke passed"
