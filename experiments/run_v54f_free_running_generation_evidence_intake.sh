#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v54f_free_running_generation_evidence_intake"
RUN_ID="${V54F_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EVIDENCE_DIR="${V54F_FREE_RUNNING_GENERATION_EVIDENCE_DIR:-${V54F_GENERATION_EVIDENCE_DIR:-}}"
V53I_DIR="$RESULTS_DIR/v53i_complete_source_query_instantiation/instantiate_001"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$EVIDENCE_DIR" "$V53I_DIR" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
evidence_arg = sys.argv[5]
v53i_dir = Path(sys.argv[6])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def good_text(value):
    text = str(value).strip()
    bad = {"", "fixture", "placeholder", "todo", "replace-me", "replace-with-value", "unknown", "none"}
    return text.lower() not in bad and not text.lower().startswith("replace-with")


def is_sha256(value):
    text = str(value)
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", text):
        return False
    digest = text.split(":", 1)[1]
    return len(set(digest)) > 1


def as_int(row, field, errors, minimum=None):
    try:
        value = int(row.get(field, ""))
    except (TypeError, ValueError):
        errors.append(f"{field}-not-int")
        return 0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-min")
    return value


def as_float(row, field, errors, minimum=None, maximum=None):
    try:
        value = float(row.get(field, ""))
    except (TypeError, ValueError):
        errors.append(f"{field}-not-float")
        return 0.0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-min")
    if maximum is not None and value > maximum:
        errors.append(f"{field}-above-max")
    return value


summary = {
    "v54f_free_running_generation_evidence_intake_ready": 1,
    "generation_evidence_dir_supplied": int(bool(evidence_arg)),
    "supplied_generation_evidence_ready": 0,
    "real_model_generation_ready": 0,
    "generation_rows": 0,
    "expected_generation_rows": 1000,
    "free_running_decode_rows": 0,
    "teacher_forcing_used_rows": 0,
    "raw_prompt_context_bytes": 0,
    "retrieved_text_in_prompt_rows": 0,
    "source_locator_leakage_rows": 0,
    "wrong_answer_rate": "0.000000",
    "unsupported_abstention_accuracy": "0.000000",
    "external_label_source_ready": 0,
    "heldout_metric_ready": 0,
    "thresholds_declared_ready": 0,
    "raw_output_hash_bound_rate": "0.000000",
    "fixture_rows_in_measured_registry": 0,
    "network_or_download_used": 0,
    "gpu_execution_used": 0,
    "checkpoint_downloaded": 0,
    "external_api_used": 0,
    "v53i_query_rows": 0,
    "v53i_query_rows_sha256": "",
    "v1_0_comparison_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": "",
}
validation_rows = []
artifact_rels = []

required_field_rows = []
for artifact, field, rule in [
    ("generator_identity.json", "generator_id", "stable generator id"),
    ("generator_identity.json", "model_revision", "exact immutable generator revision"),
    ("generator_identity.json", "model_artifact_sha256", "sha256:<64 hex>"),
    ("generator_identity.json", "decoder_contract_sha256", "sha256 of decoder contract source"),
    ("generator_identity.json", "runtime", "runtime implementation"),
    ("generator_identity.json", "runtime_version", "runtime version"),
    ("generator_identity.json", "hardware", "measured hardware"),
    ("generator_identity.json", "non_fixture_declared", "must be 1"),
    ("generator_identity.json", "external_api_used", "must be 0"),
    ("generator_identity.json", "training_or_checkpoint_download_used", "must be 0"),
    ("free_running_generation_rows.csv", "query_id", "must cover every frozen v53i query exactly once"),
    ("free_running_generation_rows.csv", "free_running_decode", "must be 1"),
    ("free_running_generation_rows.csv", "teacher_forcing_used", "must be 0"),
    ("free_running_generation_rows.csv", "raw_prompt_context_bytes", "must be 0"),
    ("free_running_generation_rows.csv", "retrieved_text_in_prompt", "must be 0"),
    ("free_running_generation_rows.csv", "source_locator_leakage", "must be 0"),
    ("free_running_generation_rows.csv", "raw_output_sha256", "sha256 over generated_text + newline + citation_handle"),
    ("label_source.json", "external_label_source_ready", "must be 1"),
    ("heldout_metric_rows.csv", "heldout_metric_ready", "must be 1"),
    ("metric_thresholds.json", "wrong_answer_rate_max", "agreed threshold"),
    ("metric_thresholds.json", "unsupported_abstention_accuracy_min", "agreed threshold"),
]:
    required_field_rows.append({"artifact": artifact, "field": field, "required": "1", "rule": rule})
write_csv(run_dir / "generation_required_field_rows.csv", list(required_field_rows[0]), required_field_rows)
artifact_rels.append("generation_required_field_rows.csv")

query_path = v53i_dir / "complete_source_query_rows.csv"
if not query_path.is_file() or query_path.stat().st_size == 0:
    validation_rows.append({"check": "v53i-query-rows", "status": "blocked", "reason": "v53i query rows missing"})
    summary["blocking_reason"] = "v53i-query-rows-missing"
else:
    query_rows = read_csv(query_path)
    qhash = sha256(query_path)
    summary["v53i_query_rows"] = len(query_rows)
    summary["v53i_query_rows_sha256"] = qhash
    shutil.copy2(query_path, run_dir / "source_v53i_complete_source_query_rows.csv")
    artifact_rels.append("source_v53i_complete_source_query_rows.csv")
    template_rows = []
    for row in query_rows:
        template_rows.append(
            {
                "generation_id": "",
                "query_id": row["query_id"],
                "corpus_snapshot_sha256": qhash,
                "sanitized_question_sha256": sha256_text(row["question"]),
                "generator_id": "",
                "free_running_decode": "",
                "teacher_forcing_used": "",
                "raw_prompt_context_bytes": "",
                "retrieved_text_in_prompt": "",
                "source_locator_leakage": "",
                "generated_text": "",
                "citation_handle": "",
                "raw_output_sha256": "",
                "output_token_count": "",
                "latency_ns": "",
                "peak_memory_mb": "",
                "answer_correct": "",
                "citation_correct": "",
                "abstain_correct": "",
                "wrong_answer": "",
                "evaluator_version": "",
                "external_api_used": "",
            }
        )
    write_csv(run_dir / "free_running_generation_template_rows.csv", list(template_rows[0]), template_rows)
    artifact_rels.append("free_running_generation_template_rows.csv")

    evidence_dir = Path(evidence_arg) if evidence_arg else None
    if not evidence_dir or not evidence_dir.is_dir():
        validation_rows.append({"check": "evidence-dir", "status": "blocked", "reason": "V54F_FREE_RUNNING_GENERATION_EVIDENCE_DIR not supplied"})
        summary["blocking_reason"] = "generation-evidence-dir-missing"
    else:
        identity_path = evidence_dir / "generator_identity.json"
        generation_path = evidence_dir / "free_running_generation_rows.csv"
        label_path = evidence_dir / "label_source.json"
        metric_path = evidence_dir / "heldout_metric_rows.csv"
        threshold_path = evidence_dir / "metric_thresholds.json"
        copied = []
        errors = []
        for name, path in [
            ("generator_identity", identity_path),
            ("free_running_generation_rows", generation_path),
            ("label_source", label_path),
            ("heldout_metric_rows", metric_path),
            ("metric_thresholds", threshold_path),
        ]:
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(f"{name}-missing")
                validation_rows.append({"check": name, "status": "blocked", "reason": "missing"})
            else:
                dst = run_dir / "supplied_generation_evidence" / path.name
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, dst)
                copied.append(f"supplied_generation_evidence/{path.name}")
        artifact_rels.extend(copied)
        identity = {}
        label_source = {}
        thresholds = {}
        metric_rows = []
        generation_rows = []
        if not errors:
            identity = json.loads(identity_path.read_text(encoding="utf-8"))
            label_source = json.loads(label_path.read_text(encoding="utf-8"))
            thresholds = json.loads(threshold_path.read_text(encoding="utf-8"))
            metric_rows = read_csv(metric_path)
            generation_rows = read_csv(generation_path)

            for field in ["generator_id", "model_revision", "runtime", "runtime_version", "hardware"]:
                if not good_text(identity.get(field, "")):
                    errors.append(f"identity-{field}-bad")
            for field in ["model_artifact_sha256", "decoder_contract_sha256"]:
                if not is_sha256(identity.get(field, "")):
                    errors.append(f"identity-{field}-bad")
            for field in ["non_fixture_declared"]:
                if int(identity.get(field, 0)) != 1:
                    errors.append(f"identity-{field}-not-1")
            for field in ["external_api_used", "training_or_checkpoint_download_used", "attention_blocks", "transformer_blocks"]:
                if int(identity.get(field, 1)) != 0:
                    errors.append(f"identity-{field}-not-0")

            external_label_ready = int(label_source.get("external_label_source_ready", 0) == 1)
            non_fixture_labels = int(label_source.get("non_fixture_declared", 0) == 1)
            label_rows = int(label_source.get("label_rows", 0) or 0)
            if not external_label_ready or not non_fixture_labels or label_rows < len(query_rows):
                errors.append("label-source-not-ready")
            summary["external_label_source_ready"] = int(not ("label-source-not-ready" in errors))

            try:
                wrong_threshold = float(thresholds.get("wrong_answer_rate_max", ""))
                abstain_threshold = float(thresholds.get("unsupported_abstention_accuracy_min", ""))
            except (TypeError, ValueError):
                wrong_threshold = 0.0
                abstain_threshold = 1.0
                errors.append("metric-thresholds-invalid")
            if not (0 <= wrong_threshold <= 1 and 0 <= abstain_threshold <= 1):
                errors.append("metric-thresholds-out-of-range")
            summary["thresholds_declared_ready"] = int("metric-thresholds-invalid" not in errors and "metric-thresholds-out-of-range" not in errors)

            expected_query_ids = {row["query_id"] for row in query_rows}
            observed_query_ids = [row.get("query_id", "") for row in generation_rows]
            duplicate_query_rows = len(observed_query_ids) - len(set(observed_query_ids))
            missing_query_rows = len(expected_query_ids.difference(observed_query_ids))
            extra_query_rows = len(set(observed_query_ids).difference(expected_query_ids))
            if len(generation_rows) != len(query_rows) or duplicate_query_rows or missing_query_rows or extra_query_rows:
                errors.append("query-coverage-invalid")
            summary["generation_rows"] = len(generation_rows)

            raw_hash_valid = 0
            raw_hash_total = 0
            free_running = 0
            teacher_forcing = 0
            raw_bytes = 0
            retrieved_rows = 0
            source_locator_rows = 0
            wrong_rows = 0
            abstain_correct = 0
            for index, row in enumerate(generation_rows, start=1):
                row_errors = []
                if row.get("corpus_snapshot_sha256") != qhash:
                    row_errors.append("corpus-sha-mismatch")
                free_running += int(row.get("free_running_decode") == "1")
                teacher_forcing += int(row.get("teacher_forcing_used") != "0")
                raw_bytes += as_int(row, "raw_prompt_context_bytes", row_errors, minimum=0)
                retrieved_rows += int(row.get("retrieved_text_in_prompt") != "0")
                source_locator_rows += int(row.get("source_locator_leakage") != "0")
                wrong_rows += int(row.get("wrong_answer") == "1")
                abstain_correct += int(row.get("abstain_correct") == "1")
                as_int(row, "output_token_count", row_errors, minimum=1)
                as_int(row, "latency_ns", row_errors, minimum=1)
                as_int(row, "peak_memory_mb", row_errors, minimum=1)
                if row.get("external_api_used") != "0":
                    row_errors.append("external-api-used")
                expected_raw_hash = sha256_text(row.get("generated_text", "") + "\n" + row.get("citation_handle", ""))
                raw_hash_total += 1
                if row.get("raw_output_sha256") == expected_raw_hash:
                    raw_hash_valid += 1
                else:
                    row_errors.append("raw-output-sha-mismatch")
                if row_errors:
                    errors.append(f"generation-row-{index}:{'|'.join(row_errors)}")
            summary["free_running_decode_rows"] = free_running
            summary["teacher_forcing_used_rows"] = teacher_forcing
            summary["raw_prompt_context_bytes"] = raw_bytes
            summary["retrieved_text_in_prompt_rows"] = retrieved_rows
            summary["source_locator_leakage_rows"] = source_locator_rows
            summary["wrong_answer_rate"] = f"{(wrong_rows / len(generation_rows)) if generation_rows else 0.0:.6f}"
            summary["unsupported_abstention_accuracy"] = f"{(abstain_correct / len(generation_rows)) if generation_rows else 0.0:.6f}"
            summary["raw_output_hash_bound_rate"] = f"{(raw_hash_valid / raw_hash_total) if raw_hash_total else 0.0:.6f}"

            metric = metric_rows[0] if len(metric_rows) == 1 else {}
            metric_errors = []
            if metric.get("heldout_metric_ready") != "1":
                metric_errors.append("heldout-metric-not-ready")
            if int(metric.get("generation_rows", "0") or 0) != len(query_rows):
                metric_errors.append("metric-generation-row-mismatch")
            observed_wrong = as_float(metric, "wrong_answer_rate", metric_errors, minimum=0.0, maximum=1.0)
            observed_abstain = as_float(metric, "unsupported_abstention_accuracy", metric_errors, minimum=0.0, maximum=1.0)
            if observed_wrong > wrong_threshold:
                metric_errors.append("wrong-rate-above-threshold")
            if observed_abstain < abstain_threshold:
                metric_errors.append("abstain-accuracy-below-threshold")
            if metric_errors:
                errors.extend(metric_errors)
            summary["heldout_metric_ready"] = int(not metric_errors)

            core_ready = (
                len(generation_rows) == len(query_rows) == 1000
                and free_running == len(generation_rows)
                and teacher_forcing == 0
                and raw_bytes == 0
                and retrieved_rows == 0
                and source_locator_rows == 0
                and raw_hash_valid == raw_hash_total
                and summary["external_label_source_ready"] == 1
                and summary["heldout_metric_ready"] == 1
                and summary["thresholds_declared_ready"] == 1
                and not errors
            )
            summary["supplied_generation_evidence_ready"] = int(core_ready)
            summary["real_model_generation_ready"] = int(core_ready)
            validation_rows.append(
                {
                    "check": "supplied-generation-evidence",
                    "status": "pass" if core_ready else "blocked",
                    "reason": "all required generation evidence validated" if core_ready else ";".join(errors[:40]),
                }
            )
        if errors and not any(row["check"] == "supplied-generation-evidence" for row in validation_rows):
            validation_rows.append({"check": "supplied-generation-evidence", "status": "blocked", "reason": ";".join(errors[:40])})
        summary["blocking_reason"] = "" if summary["real_model_generation_ready"] == 1 else ";".join(errors[:12]) or "generation-evidence-not-ready"

write_csv(run_dir / "generation_validation_rows.csv", ["check", "status", "reason"], validation_rows)
artifact_rels.append("generation_validation_rows.csv")

boundary_lines = [
    "# v54f Free-Running Generation Evidence Intake Boundary",
    "",
    "Purpose:",
    "",
    "- Validate user-supplied local 1000-row free-running generation evidence without network, GPU, or downloads.",
    "",
    "Default:",
    "",
    f"- real_model_generation_ready={summary['real_model_generation_ready']}",
    f"- external_label_source_ready={summary['external_label_source_ready']}",
    f"- heldout_metric_ready={summary['heldout_metric_ready']}",
    f"- free_running_decode_rows={summary['free_running_decode_rows']}",
    f"- raw_prompt_context_bytes={summary['raw_prompt_context_bytes']}",
    f"- retrieved_text_in_prompt_rows={summary['retrieved_text_in_prompt_rows']}",
    f"- source_locator_leakage_rows={summary['source_locator_leakage_rows']}",
    f"- network_or_download_used={summary['network_or_download_used']}",
    f"- gpu_execution_used={summary['gpu_execution_used']}",
    f"- checkpoint_downloaded={summary['checkpoint_downloaded']}",
    f"- external_api_used={summary['external_api_used']}",
    f"- v1_0_comparison_ready={summary['v1_0_comparison_ready']}",
    f"- public_comparison_claim_ready={summary['public_comparison_claim_ready']}",
    f"- real_release_package_ready={summary['real_release_package_ready']}",
    "",
    "Blocked wording: public comparison, release readiness, or real generation quality without accepted external labels and heldout metrics.",
]
(run_dir / "V54F_FREE_RUNNING_GENERATION_EVIDENCE_INTAKE_BOUNDARY.md").write_text("\n".join(boundary_lines) + "\n", encoding="utf-8")
artifact_rels.append("V54F_FREE_RUNNING_GENERATION_EVIDENCE_INTAKE_BOUNDARY.md")

manifest = {
    "manifest_scope": "v54f-free-running-generation-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if isinstance(value, bool) else value) for key, value in summary.items()},
}
write_json(run_dir / "v54f_free_running_generation_evidence_intake_manifest.json", manifest)
artifact_rels.append("v54f_free_running_generation_evidence_intake_manifest.json")

sha_rows = []
for rel in sorted(set(artifact_rels)):
    path = run_dir / rel
    if path.is_file():
        sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary["artifact_rows"] = len(sha_rows)
write_csv(summary_csv, list(summary), [summary])

decision_rows = [
    {"gate": "v53i-frozen-query-input", "status": "pass" if summary["v53i_query_rows"] == 1000 else "blocked", "reason": f"v53i_query_rows={summary['v53i_query_rows']}"},
    {"gate": "generation-evidence-dir", "status": "pass" if summary["generation_evidence_dir_supplied"] else "blocked", "reason": "V54F_GENERATION_EVIDENCE_DIR supplied" if summary["generation_evidence_dir_supplied"] else "not supplied"},
    {"gate": "free-running-generation-evidence", "status": "pass" if summary["supplied_generation_evidence_ready"] else "blocked", "reason": summary["blocking_reason"] or "accepted"},
    {"gate": "real-model-generation", "status": "pass" if summary["real_model_generation_ready"] else "blocked", "reason": "1000-row external-label heldout evidence accepted" if summary["real_model_generation_ready"] else "external labels and heldout metrics not accepted"},
    {"gate": "public-comparison-claim", "status": "blocked", "reason": "D/E and human/public comparison evidence remain outside this intake"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release evidence missing"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v54f_free_running_generation_evidence_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
