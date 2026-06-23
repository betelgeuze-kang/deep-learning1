#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53u_complete_source_de_open_weight_evidence_intake"
RUN_ID="${V53U_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
D_EVIDENCE_DIR="${V53U_30B_EVIDENCE_DIR:-}"
E_EVIDENCE_DIR="${V53U_70B_EVIDENCE_DIR:-}"
V53I_DIR="$RESULTS_DIR/v53i_complete_source_query_instantiation/instantiate_001"
V53T_DIR="$RESULTS_DIR/v53t_complete_source_audit_readiness_gate/gate_001"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$D_EVIDENCE_DIR" "$E_EVIDENCE_DIR" "$V53I_DIR" "$V53T_DIR" <<'PY'
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
d_evidence_arg = sys.argv[5]
e_evidence_arg = sys.argv[6]
v53i_dir = Path(sys.argv[7])
v53t_dir = Path(sys.argv[8])


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def is_sha256(value):
    text = str(value)
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", text):
        return False
    digest = text.split(":", 1)[1]
    return len(set(digest)) > 1


def good_text(value):
    text = str(value).strip()
    bad = {"", "fixture", "placeholder", "todo", "replace-me", "replace-with-value", "unknown", "none"}
    return text.lower() not in bad and not text.lower().startswith("replace-with")


def as_int(row, field, errors, minimum=None):
    try:
        value = int(row.get(field, ""))
    except ValueError:
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


required_v53_files = [
    v53i_dir / "complete_source_query_rows.csv",
    v53i_dir / "complete_source_span_rows.csv",
    v53i_dir / "sha256_manifest.csv",
    v53t_dir / "complete_source_unseen_repository_split_rows.csv",
]
missing_v53_files = [path for path in required_v53_files if not path.is_file() or path.stat().st_size == 0]

artifact_rels = []
summary = {
    "v53u_complete_source_de_open_weight_evidence_intake_ready": 1,
    "required_systems": "D,E",
    "d_30b_evidence_dir_supplied": int(bool(d_evidence_arg)),
    "e_70b_evidence_dir_supplied": int(bool(e_evidence_arg)),
    "d_30b_supplied_evidence_ready": 0,
    "e_70b_supplied_evidence_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "same_query_set_de": 0,
    "same_source_manifest_de": 0,
    "same_context_budget_de": 0,
    "same_retrieval_budget_de": 0,
    "same_evaluator_version_de": 0,
    "raw_output_hash_bound_rate": "0.000000",
    "fixture_rows_in_measured_registry": 0,
    "d_30b_query_rows": 0,
    "e_70b_query_rows": 0,
    "d_30b_validation_error_rows": 0,
    "e_70b_validation_error_rows": 0,
    "external_api_used": 0,
    "v53i_query_rows": 0,
    "v53i_source_span_rows": 0,
    "v53i_query_rows_sha256": "",
    "v53i_source_span_rows_sha256": "",
    "unseen_repository_split_ready": 0,
    "v1_0_comparison_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": "",
}
decision_rows = []
validation_rows = []

field_rows = []
for system_id in ("D", "E"):
    for artifact, field, rule in [
        ("model_identity.json", "system_id", f"must equal {system_id}"),
        ("model_identity.json", "model_id", "stable real open-weight model id; placeholders rejected"),
        ("model_identity.json", "model_repository", "model repository id"),
        ("model_identity.json", "model_revision", "exact immutable model revision"),
        ("model_identity.json", "parameter_count_b", "30B: [25,40], 70B: [65,80]"),
        ("model_identity.json", "quantization", "exact quantization or none"),
        ("model_identity.json", "model_artifact_sha256", "sha256:<64 hex>"),
        ("model_identity.json", "open_weight_license_uri", "public license URI"),
        ("model_identity.json", "runtime", "runtime implementation"),
        ("model_identity.json", "runtime_version", "runtime version"),
        ("model_identity.json", "hardware", "measured hardware"),
        ("model_identity.json", "non_fixture_declared", "must be 1"),
        ("run_result_rows.csv", "query_id", "must cover every v53i query exactly once"),
        ("run_result_rows.csv", "raw_answer", "raw model answer"),
        ("run_result_rows.csv", "raw_citation", "raw model citation"),
        ("run_result_rows.csv", "raw_output_sha256", "sha256 over raw_answer + newline + raw_citation"),
        ("run_result_rows.csv", "prompt_sha256", "sha256-bound prompt"),
        ("run_result_rows.csv", "output_sha256", "sha256-bound output"),
        ("run_result_rows.csv", "context_budget", "same positive integer across D/E"),
        ("run_result_rows.csv", "retrieval_budget", "same positive integer across D/E"),
        ("run_result_rows.csv", "latency_ns", "positive measured latency"),
        ("run_result_rows.csv", "peak_memory_mb", "positive measured peak memory"),
        ("run_result_rows.csv", "evaluator_version", "same exact evaluator version across D/E"),
    ]:
        field_rows.append({"system_id": system_id, "artifact": artifact, "field": field, "required": "1", "rule": rule})
write_csv(run_dir / "de_required_field_rows.csv", list(field_rows[0].keys()), field_rows)
artifact_rels.append("de_required_field_rows.csv")

template_fields = [
    "system_id", "query_id", "sanitized_question", "corpus_snapshot_sha256",
    "context_budget", "retrieval_budget", "model_id", "raw_answer",
    "raw_citation", "abstained", "latency_ns", "peak_memory_mb",
    "prompt_sha256", "output_sha256", "raw_output_sha256",
    "prompt_template_sha256", "seed", "evaluator_version",
]

if missing_v53_files:
    for path in missing_v53_files:
        validation_rows.append({"system_id": "v53", "check": "required-file", "status": "blocked", "reason": str(path)})
    summary["blocking_reason"] = "v53-foundation-artifacts-missing"
else:
    query_rows = read_csv(v53i_dir / "complete_source_query_rows.csv")
    span_rows = read_csv(v53i_dir / "complete_source_span_rows.csv")
    split_rows = read_csv(v53t_dir / "complete_source_unseen_repository_split_rows.csv")
    copy(v53i_dir / "complete_source_query_rows.csv", "source_v53i/complete_source_query_rows.csv")
    copy(v53i_dir / "complete_source_span_rows.csv", "source_v53i/complete_source_span_rows.csv")
    copy(v53t_dir / "complete_source_unseen_repository_split_rows.csv", "source_v53t/complete_source_unseen_repository_split_rows.csv")
    artifact_rels.extend([
        "source_v53i/complete_source_query_rows.csv",
        "source_v53i/complete_source_span_rows.csv",
        "source_v53t/complete_source_unseen_repository_split_rows.csv",
    ])
    qhash = sha256(v53i_dir / "complete_source_query_rows.csv")
    shash = sha256(v53i_dir / "complete_source_span_rows.csv")
    summary.update({
        "v53i_query_rows": len(query_rows),
        "v53i_source_span_rows": len(span_rows),
        "v53i_query_rows_sha256": qhash,
        "v53i_source_span_rows_sha256": shash,
        "unseen_repository_split_ready": int(
            len(split_rows) == 10
            and sum(row.get("split_name") == "unseen_holdout" for row in split_rows) == 2
            and all(row.get("split_status") == "pass" for row in split_rows)
        ),
    })
    template_rows = []
    for system_id in ("D", "E"):
        for row in query_rows:
            template_rows.append({
                "system_id": system_id,
                "query_id": row["query_id"],
                "sanitized_question": re.sub(r"\s+at\s+[^?,]+:[0-9]+\b", " at relevant source location", row["question"]),
                "corpus_snapshot_sha256": qhash,
                "context_budget": "",
                "retrieval_budget": "",
                "model_id": "",
                "raw_answer": "",
                "raw_citation": "",
                "abstained": "",
                "latency_ns": "",
                "peak_memory_mb": "",
                "prompt_sha256": "",
                "output_sha256": "",
                "raw_output_sha256": "",
                "prompt_template_sha256": "",
                "seed": "",
                "evaluator_version": "",
            })
    write_csv(run_dir / "de_run_result_template_rows.csv", template_fields, template_rows)
    artifact_rels.append("de_run_result_template_rows.csv")

    expected_query_ids = [row["query_id"] for row in query_rows]
    query_id_set = set(expected_query_ids)
    context_budgets = {}
    retrieval_budgets = {}
    evaluator_versions = {}
    raw_hash_counts = {"valid": 0, "total": 0}
    ready_by_system = {}

    def validate_system(system_id, evidence_arg, min_b, max_b):
        evidence_dir = Path(evidence_arg) if evidence_arg else None
        if not evidence_dir or not evidence_dir.is_dir():
            validation_rows.append({"system_id": system_id, "check": "evidence-dir", "status": "blocked", "reason": "evidence dir not supplied"})
            return False, "evidence-dir-missing"
        identity_path = evidence_dir / "model_identity.json"
        run_path = evidence_dir / "run_result_rows.csv"
        for name, path in [("identity", identity_path), ("run-results", run_path)]:
            if not path.is_file() or path.stat().st_size == 0:
                validation_rows.append({"system_id": system_id, "check": name, "status": "fail", "reason": "missing-or-empty"})
                return False, "required-files-missing"
            copy(path, f"supplied_evidence/{system_id}/{path.name}")
            artifact_rels.append(f"supplied_evidence/{system_id}/{path.name}")

        errors = []
        identity = json.loads(identity_path.read_text(encoding="utf-8"))
        if identity.get("system_id") != system_id:
            errors.append("identity-system-id-mismatch")
        model_id = identity.get("model_id", "")
        if not good_text(model_id):
            errors.append("identity-model-id-placeholder-or-missing")
        for field in ["model_repository", "model_revision", "quantization", "runtime", "runtime_version", "hardware"]:
            if not good_text(identity.get(field, "")):
                errors.append(f"identity-{field}-placeholder-or-missing")
        as_float(identity, "parameter_count_b", errors, minimum=min_b, maximum=max_b)
        if not is_sha256(identity.get("model_artifact_sha256", "")):
            errors.append("identity-model-artifact-sha256-invalid")
        if not re.fullmatch(r"https?://[^\s]+", str(identity.get("open_weight_license_uri", ""))):
            errors.append("identity-open-weight-license-uri-invalid")
        if str(identity.get("non_fixture_declared", "")).lower() not in {"1", "true"}:
            errors.append("identity-non-fixture-declared-not-true")
        if str(identity.get("external_api_used", "0")) != "0":
            errors.append("identity-external-api-used-not-zero")

        rows = read_csv(run_path)
        summary[f"{'d_30b' if system_id == 'D' else 'e_70b'}_query_rows"] = len(rows)
        ids = [row.get("query_id", "") for row in rows]
        if sorted(ids) != sorted(expected_query_ids) or len(ids) != len(set(ids)):
            errors.append("run-query-coverage-mismatch")
        c_budget_values = set()
        r_budget_values = set()
        evaluator_values = set()
        for row in rows:
            row_errors = []
            qid = row.get("query_id", "")
            if row.get("system_id") != system_id:
                row_errors.append("system-id-mismatch")
            if row.get("model_id") != model_id:
                row_errors.append("model-id-mismatch")
            if qid not in query_id_set:
                row_errors.append("query-id-unknown")
            if row.get("corpus_snapshot_sha256") != qhash:
                row_errors.append("corpus-snapshot-sha256-mismatch")
            for text_field in ["raw_answer", "raw_citation"]:
                if not good_text(row.get(text_field, "")):
                    row_errors.append(f"{text_field}-placeholder-or-missing")
            raw_hash_counts["total"] += 1
            raw_expected = sha256_text(row.get("raw_answer", "") + "\n" + row.get("raw_citation", ""))
            if row.get("raw_output_sha256") == raw_expected:
                raw_hash_counts["valid"] += 1
            else:
                row_errors.append("raw-output-sha256-mismatch")
            for hash_field in ["prompt_sha256", "output_sha256", "prompt_template_sha256"]:
                if not is_sha256(row.get(hash_field, "")):
                    row_errors.append(f"{hash_field}-invalid")
            c_budget_values.add(as_int(row, "context_budget", row_errors, minimum=1))
            r_budget_values.add(as_int(row, "retrieval_budget", row_errors, minimum=1))
            as_int(row, "seed", row_errors, minimum=0)
            as_int(row, "latency_ns", row_errors, minimum=1)
            as_int(row, "peak_memory_mb", row_errors, minimum=1)
            if row.get("abstained") not in {"0", "1"}:
                row_errors.append("abstained-not-0-or-1")
            if not good_text(row.get("evaluator_version", "")):
                row_errors.append("evaluator-version-placeholder-or-missing")
            else:
                evaluator_values.add(row["evaluator_version"])
            if str(row.get("external_api_used", "0")) != "0":
                row_errors.append("external-api-used-not-zero")
            errors.extend(f"{qid}:{err}" for err in row_errors)
        context_budgets[system_id] = c_budget_values
        retrieval_budgets[system_id] = r_budget_values
        evaluator_versions[system_id] = evaluator_values
        if errors:
            for error in errors[:200]:
                validation_rows.append({"system_id": system_id, "check": "supplied-evidence", "status": "fail", "reason": error})
            if len(errors) > 200:
                validation_rows.append({"system_id": system_id, "check": "supplied-evidence", "status": "fail", "reason": f"additional-error-rows={len(errors)-200}"})
            return False, "supplied-evidence-invalid"
        validation_rows.append({"system_id": system_id, "check": "supplied-evidence", "status": "pass", "reason": f"{system_id} v53 frozen evidence validates"})
        return True, ""

    d_ready, d_reason = validate_system("D", d_evidence_arg, 25.0, 40.0)
    e_ready, e_reason = validate_system("E", e_evidence_arg, 65.0, 80.0)
    ready_by_system["D"] = d_ready
    ready_by_system["E"] = e_ready
    summary["d_30b_supplied_evidence_ready"] = int(d_ready)
    summary["e_70b_supplied_evidence_ready"] = int(e_ready)
    summary["d_30b_validation_error_rows"] = sum(1 for row in validation_rows if row["system_id"] == "D" and row["status"] == "fail")
    summary["e_70b_validation_error_rows"] = sum(1 for row in validation_rows if row["system_id"] == "E" and row["status"] == "fail")
    summary["required_30b_baseline_ready"] = int(d_ready)
    summary["required_70b_baseline_ready"] = int(e_ready)
    summary["same_query_set_de"] = int(d_ready and e_ready and summary["d_30b_query_rows"] == 1000 and summary["e_70b_query_rows"] == 1000)
    summary["same_source_manifest_de"] = int(d_ready and e_ready and summary["v53i_source_span_rows"] == 1000)
    summary["same_context_budget_de"] = int(d_ready and e_ready and len(context_budgets.get("D", set()) | context_budgets.get("E", set())) == 1)
    summary["same_retrieval_budget_de"] = int(d_ready and e_ready and len(retrieval_budgets.get("D", set()) | retrieval_budgets.get("E", set())) == 1)
    summary["same_evaluator_version_de"] = int(d_ready and e_ready and len(evaluator_versions.get("D", set()) | evaluator_versions.get("E", set())) == 1)
    summary["raw_output_hash_bound_rate"] = f"{(raw_hash_counts['valid'] / raw_hash_counts['total']) if raw_hash_counts['total'] else 0.0:.6f}"
    blockers = []
    if not d_ready:
        blockers.append(f"30b:{d_reason or 'not-ready'}")
    if not e_ready:
        blockers.append(f"70b:{e_reason or 'not-ready'}")
    summary["blocking_reason"] = ";".join(blockers)

if not validation_rows:
    validation_rows.append({"system_id": "D", "check": "evidence-dir", "status": "blocked", "reason": "evidence dir not supplied"})
    validation_rows.append({"system_id": "E", "check": "evidence-dir", "status": "blocked", "reason": "evidence dir not supplied"})

write_csv(run_dir / "de_validation_rows.csv", ["system_id", "check", "status", "reason"], validation_rows)
artifact_rels.append("de_validation_rows.csv")

summary["v53u_complete_source_de_open_weight_evidence_intake_ready"] = int(
    summary["required_30b_baseline_ready"]
    and summary["required_70b_baseline_ready"]
    and summary["same_query_set_de"]
    and summary["same_source_manifest_de"]
    and summary["same_context_budget_de"]
    and summary["same_retrieval_budget_de"]
    and summary["same_evaluator_version_de"]
    and summary["raw_output_hash_bound_rate"] == "1.000000"
    and summary["fixture_rows_in_measured_registry"] == 0
)

decision_rows = [
    {"gate": "v53-foundation-input", "status": "pass" if not missing_v53_files else "blocked", "reason": f"missing_v53_files={len(missing_v53_files)}"},
    {"gate": "30b-real-evidence", "status": "pass" if summary["required_30b_baseline_ready"] else "blocked", "reason": f"d_30b_query_rows={summary['d_30b_query_rows']}; errors={summary['d_30b_validation_error_rows']}"},
    {"gate": "70b-real-evidence", "status": "pass" if summary["required_70b_baseline_ready"] else "blocked", "reason": f"e_70b_query_rows={summary['e_70b_query_rows']}; errors={summary['e_70b_validation_error_rows']}"},
    {"gate": "same-condition-de", "status": "pass" if summary["same_query_set_de"] and summary["same_context_budget_de"] and summary["same_retrieval_budget_de"] and summary["same_evaluator_version_de"] else "blocked", "reason": f"same_query_set_de={summary['same_query_set_de']}; same_context_budget_de={summary['same_context_budget_de']}; same_retrieval_budget_de={summary['same_retrieval_budget_de']}; same_evaluator_version_de={summary['same_evaluator_version_de']}"},
    {"gate": "public-comparison", "status": "blocked", "reason": "A-H registry, review, and public comparison gates remain separate"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
write_csv(summary_csv, list(summary.keys()), [{key: str(value) for key, value in summary.items()}])

boundary = (
    "# v53u Complete Source D/E Evidence Intake Boundary\n\n"
    "This runner validates user-supplied D/E 30B and 70B open-weight evidence over the frozen v53i 1000-query source-bound surface. "
    "It does not download models, run GPUs, or fabricate measured rows.\n\n"
    f"- required_30b_baseline_ready={summary['required_30b_baseline_ready']}\n"
    f"- required_70b_baseline_ready={summary['required_70b_baseline_ready']}\n"
    f"- same_query_set_de={summary['same_query_set_de']}\n"
    f"- same_source_manifest_de={summary['same_source_manifest_de']}\n"
    f"- same_context_budget_de={summary['same_context_budget_de']}\n"
    f"- same_retrieval_budget_de={summary['same_retrieval_budget_de']}\n"
    f"- same_evaluator_version_de={summary['same_evaluator_version_de']}\n"
    f"- raw_output_hash_bound_rate={summary['raw_output_hash_bound_rate']}\n"
    f"- fixture_rows_in_measured_registry={summary['fixture_rows_in_measured_registry']}\n"
    "- public_comparison_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Blocked wording: public A-H comparison, v1.0 comparison readiness, release readiness, or heldout quality claims.\n"
)
(run_dir / "V53U_COMPLETE_SOURCE_DE_EVIDENCE_BOUNDARY.md").write_text(boundary, encoding="utf-8")
artifact_rels.append("V53U_COMPLETE_SOURCE_DE_EVIDENCE_BOUNDARY.md")

manifest = {
    "manifest_scope": "v53u-complete-source-de-open-weight-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: value for key, value in summary.items() if key not in {"blocking_reason"}},
    "blocking_reason": summary["blocking_reason"],
}
(run_dir / "v53u_complete_source_de_open_weight_evidence_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
artifact_rels.append("v53u_complete_source_de_open_weight_evidence_intake_manifest.json")

sha_rows = []
for rel in sorted(dict.fromkeys(artifact_rels)):
    path = run_dir / rel
    if path.is_file():
        sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53u_complete_source_de_open_weight_evidence_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
