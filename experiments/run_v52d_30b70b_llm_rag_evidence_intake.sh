#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52d_30b70b_llm_rag_evidence_intake"
RUN_ID="${V52D_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
D_EVIDENCE_DIR="${V52D_30B_LLM_RAG_EVIDENCE_DIR:-}"
E_EVIDENCE_DIR="${V52D_70B_LLM_RAG_EVIDENCE_DIR:-}"
V50_RUN_DIR="$RESULTS_DIR/v50_public_repo_auditor_3repo/audit_001"
V50_SUMMARY_CSV="$RESULTS_DIR/v50_public_repo_auditor_3repo_summary.csv"
V50_REQUIRED_FILES=(
  "$V50_SUMMARY_CSV"
  "$V50_RUN_DIR/public_repo_audit_case_rows.csv"
  "$V50_RUN_DIR/public_repo_source_span_rows.csv"
  "$V50_RUN_DIR/commercial_return/query_set.csv"
  "$V50_RUN_DIR/commercial_return/poc_result_rows.csv"
  "$V50_RUN_DIR/sha256_manifest.csv"
)

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

missing_v50_seed_files=()
for required_file in "${V50_REQUIRED_FILES[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    missing_v50_seed_files+=("$required_file")
  fi
done

v50_seed_ready=1
if [[ "${#missing_v50_seed_files[@]}" -gt 0 ]]; then
  v50_seed_ready=0
  if [[ "${V52D_ALLOW_V50_REFRESH:-0}" != "1" ]]; then
    python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$D_EVIDENCE_DIR" "$E_EVIDENCE_DIR" "${missing_v50_seed_files[@]}" <<'PY'
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
d_evidence_dir_arg = sys.argv[5]
e_evidence_dir_arg = sys.argv[6]
missing_paths = [Path(path) for path in sys.argv[7:]]


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


system_specs = [
    {"system_id": "D", "label": "30B open-weight LLM + RAG", "size_class": "30b", "min_b": 25.0, "max_b": 40.0, "env_name": "V52D_30B_LLM_RAG_EVIDENCE_DIR"},
    {"system_id": "E", "label": "70B open-weight LLM + RAG", "size_class": "70b", "min_b": 65.0, "max_b": 80.0, "env_name": "V52D_70B_LLM_RAG_EVIDENCE_DIR"},
]

schema_rows = []
for spec in system_specs:
    schema_rows.extend(
        [
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "system_id", "required": 1, "rule": f"must equal {spec['system_id']}"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "model_id", "required": 1, "rule": "stable open-weight model identifier; placeholders and fixture labels rejected"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "parameter_count_b", "required": 1, "rule": f"float in [{spec['min_b']}, {spec['max_b']}]"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "open_weight_license_uri", "required": 1, "rule": "public http(s) model/license reference; placeholders rejected"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "model_artifact_sha256", "required": 1, "rule": "sha256:<64 hex>; placeholder digests rejected"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "external_api_used", "required": 1, "rule": "must be 0 for open-weight D/E rows"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_answer_rows.csv", "field": "query_id", "required": 1, "rule": "must cover every v50 query id exactly once"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_answer_rows.csv", "field": "predicted_label", "required": 1, "rule": "scored against v50 expected_label"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_answer_rows.csv", "field": "raw_prompt_context_bytes", "required": 1, "rule": "positive integer"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_citation_rows.csv", "field": "case_id/kind/path/sha256/line", "required": 1, "rule": "must bind to v50 source spans"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_resource_rows.csv", "field": "latency_ns", "required": 1, "rule": "positive measured runtime"},
        ]
    )
write_csv(run_dir / "llm_rag_required_field_rows.csv", list(schema_rows[0].keys()), schema_rows)

template_fields = [
    "system_id",
    "query_id",
    "case_id",
    "size_class",
    "model_id",
    "expected_label",
    "predicted_label",
    "answer",
    "raw_prompt_context_bytes",
    "retrieved_span_rows",
    "prompt_context_sha256",
    "output_sha256",
    "latency_ns",
    "external_api_used",
    "route_memory_store_used",
    "compact_routehint_used",
]
write_csv(run_dir / "llm_rag_answer_template.csv", template_fields, [])

identity_templates = {}
for spec in system_specs:
    identity_templates[spec["system_id"]] = {
        "system_id": spec["system_id"],
        "model_id": f"replace-with-{spec['size_class']}-open-weight-model-id",
        "parameter_count_b": None,
        "size_class": spec["size_class"],
        "runner": "llama.cpp|vllm|transformers|tgi|sglang|other",
        "quantization": "record exact quantization or none",
        "model_artifact_uri": "local path or HTTPS model artifact identifier",
        "model_artifact_sha256": "sha256:<64 hex>",
        "open_weight_license_uri": "required",
        "rag_context_builder": "describe retrieval and prompt assembly",
        "context_length": None,
        "external_api_used": 0,
        "external_network_used": 0,
    }
(run_dir / "model_identity_templates.json").write_text(json.dumps(identity_templates, indent=2, sort_keys=True) + "\n", encoding="utf-8")

blocker_rows = [
    {
        "missing_seed_artifact": str(path),
        "dependency_stage": "v50-public-repo-seed",
        "required_for": "v52d-30b70b-llm-rag-evidence-intake",
        "implicit_refresh_allowed": "0",
        "approval_required": "1",
        "network_or_download_risk": "1",
        "fixture_allowed": "0",
        "tests_only_merge_condition": "0",
        "claim_boundary_status": "blocked-until-v50-seed-artifact-present",
        "validation_command": "V52D_ALLOW_V50_REFRESH=1 ./experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh",
    }
    for path in missing_paths
]
write_csv(
    run_dir / "v52d_v50_seed_dependency_blocker_rows.csv",
    list(blocker_rows[0].keys()) if blocker_rows else [
        "missing_seed_artifact",
        "dependency_stage",
        "required_for",
        "implicit_refresh_allowed",
        "approval_required",
        "network_or_download_risk",
        "fixture_allowed",
        "tests_only_merge_condition",
        "claim_boundary_status",
        "validation_command",
    ],
    blocker_rows,
)

validation_rows = [
    {
        "system_id": "v50",
        "check": "seed-artifacts",
        "status": "blocked",
        "reason": f"missing_v50_seed_artifact_rows={len(blocker_rows)}; set V52D_ALLOW_V50_REFRESH=1 only with explicit approval",
    },
    {
        "system_id": "D",
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52D_30B_LLM_RAG_EVIDENCE_DIR not supplied" if not d_evidence_dir_arg else "v50 seed artifacts missing before D evidence can validate",
    },
    {
        "system_id": "E",
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52D_70B_LLM_RAG_EVIDENCE_DIR not supplied" if not e_evidence_dir_arg else "v50 seed artifacts missing before E evidence can validate",
    },
]
write_csv(run_dir / "llm_rag_validation_rows.csv", ["system_id", "check", "status", "reason"], validation_rows)

summary = {
    "v52d_30b70b_llm_rag_intake_contract_ready": 0,
    "v52d_v50_seed_dependency_blocker_ready": 1,
    "missing_v50_seed_artifact_rows": len(blocker_rows),
    "required_systems": "D,E",
    "baseline_name": "30B/70B open-weight LLM + RAG",
    "d_30b_evidence_dir_supplied": int(bool(d_evidence_dir_arg)),
    "e_70b_evidence_dir_supplied": int(bool(e_evidence_dir_arg)),
    "d_30b_supplied_evidence_ready": 0,
    "e_70b_supplied_evidence_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "d_30b_query_rows": 0,
    "e_70b_query_rows": 0,
    "d_30b_accuracy": "0.000000",
    "e_70b_accuracy": "0.000000",
    "d_30b_citation_accuracy": "0.000000",
    "e_70b_citation_accuracy": "0.000000",
    "d_30b_validation_error_rows": 0,
    "e_70b_validation_error_rows": 0,
    "external_api_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v50_seed_query_rows": 0,
    "v50_seed_reused": 0,
    "v50_public_refresh_allowed": 0,
    "v50_public_refresh_executed": 0,
    "v50_seed_refresh_approval_required": 1,
    "v52_absorb_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": "v50-seed-artifacts-missing;30b:evidence-dir-missing;70b:evidence-dir-missing",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v52d-v50-seed-dependency-blocker", "status": "pass", "reason": f"missing_v50_seed_artifact_rows={len(blocker_rows)}; implicit public refresh refused"},
    {"gate": "intake-contract", "status": "blocked", "reason": "v50 seed artifacts are required before answer templates can bind to query IDs"},
    {"gate": "public-repo-seed", "status": "blocked", "reason": "V52D_ALLOW_V50_REFRESH=1 is required before v50 public-repo seed refresh"},
    {"gate": "30b-llm-rag-real-row", "status": "blocked", "reason": "v50-seed-artifacts-missing"},
    {"gate": "70b-llm-rag-real-row", "status": "blocked", "reason": "v50-seed-artifacts-missing"},
    {"gate": "v52-d-e-absorb-ready", "status": "blocked", "reason": "both D and E rows must validate after v50 seed artifacts are present"},
    {"gate": "v52-full-baseline-war", "status": "blocked", "reason": "v52 still needs the full A-H registry update and release-scale evidence"},
    {"gate": "100b-plus-optional-row", "status": "blocked", "reason": "F row is still optional/deferred unless hosted/API evidence is supplied"},
    {"gate": "real-release-package", "status": "blocked", "reason": "this dependency blocker is not a release package"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

(run_dir / "V52D_30B70B_LLM_RAG_BOUNDARY.md").write_text(
    "# v52d 30B/70B LLM+RAG Evidence Intake Boundary\n\n"
    "The v52d intake did not claim readiness because required v50 public-repo seed artifacts are missing. "
    "The runner refuses implicit public refresh so that network/download, source, and query-set changes cannot happen silently.\n\n"
    f"- v52d_30b70b_llm_rag_intake_contract_ready=0\n"
    f"- v52d_v50_seed_dependency_blocker_ready=1\n"
    f"- missing_v50_seed_artifact_rows={len(blocker_rows)}\n"
    "- implicit_v50_public_refresh_allowed=0\n"
    "- v50_seed_refresh_approval_required=1\n"
    "- required_30b_baseline_ready=0\n"
    "- required_70b_baseline_ready=0\n"
    "- v52_absorb_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Set `V52D_ALLOW_V50_REFRESH=1` only with explicit approval to regenerate the public-repo seed chain. "
    "Supplying D/E evidence directories cannot open D/E readiness until the v50 query/source-span seed exists.\n\n"
    "Allowed wording: v52d dependency blocker artifact for missing v50 seed replay evidence.\n\n"
    "Blocked wording: D/E baseline ready, 30B/70B measured comparison ready, v52 absorb ready, or v1.0 release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52d-v50-seed-dependency-blocker",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52d_30b70b_llm_rag_intake_contract_ready": 0,
    "v52d_v50_seed_dependency_blocker_ready": 1,
    "missing_v50_seed_artifact_rows": len(blocker_rows),
    "implicit_v50_public_refresh_allowed": 0,
    "v50_seed_refresh_approval_required": 1,
    "required_systems": ["D", "E"],
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_absorb_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": summary["blocking_reason"],
}
(run_dir / "v52d_30b70b_llm_rag_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52d_30b70b_llm_rag_evidence_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
print("v52d v50 seed dependency blocker emitted; no implicit public refresh performed", file=sys.stderr)
PY
    exit 0
  fi
  "$ROOT_DIR/experiments/run_v50_public_repo_auditor_3repo.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$D_EVIDENCE_DIR" "$E_EVIDENCE_DIR" "$v50_seed_ready" "${V52D_ALLOW_V50_REFRESH:-0}" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
d_evidence_dir_arg = sys.argv[5]
e_evidence_dir_arg = sys.argv[6]
v50_seed_ready_arg = sys.argv[7]
v50_refresh_allowed_arg = sys.argv[8]
results = root / "results"
v50_dir = results / "v50_public_repo_auditor_3repo" / "audit_001"
v50_summary = list(csv.DictReader((results / "v50_public_repo_auditor_3repo_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def is_sha256(value):
    if not isinstance(value, str) or re.fullmatch(r"sha256:[0-9a-f]{64}", value or "") is None:
        return False
    digest = value.split(":", 1)[1]
    return len(set(digest)) > 1 and digest != ("0" * 64)


def is_nonplaceholder_text(*values):
    text = " ".join(str(value or "") for value in values).lower()
    blocked_terms = [
        "fixture",
        "synthetic",
        "placeholder",
        "dummy",
        "example",
        "replace-with",
        "test-only",
        "review.invalid",
    ]
    return bool(text.strip()) and not any(term in text for term in blocked_terms)


def is_public_uri(value):
    return isinstance(value, str) and (value.startswith("https://") or value.startswith("http://")) and is_nonplaceholder_text(value)


def int_value(row, field, errors, minimum=None):
    try:
        value = int(row.get(field, ""))
    except (TypeError, ValueError):
        errors.append(f"{field}-not-integer")
        return 0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-{minimum}")
    return value


def float_value(row, field, errors, minimum=None, maximum=None):
    try:
        value = float(row.get(field, ""))
    except (TypeError, ValueError):
        errors.append(f"{field}-not-float")
        return 0.0
    if minimum is not None and value < minimum:
        errors.append(f"{field}-below-{minimum}")
    if maximum is not None and value > maximum:
        errors.append(f"{field}-above-{maximum}")
    return value


for src, rel in [
    (v50_dir / "public_repo_audit_case_rows.csv", "source_v50/public_repo_audit_case_rows.csv"),
    (v50_dir / "public_repo_source_span_rows.csv", "source_v50/public_repo_source_span_rows.csv"),
    (v50_dir / "commercial_return" / "query_set.csv", "source_v50/query_set.csv"),
    (v50_dir / "commercial_return" / "poc_result_rows.csv", "source_v50/reference_poc_result_rows.csv"),
    (results / "v50_public_repo_auditor_3repo_summary.csv", "source_v50/v50_public_repo_auditor_3repo_summary.csv"),
    (v50_dir / "sha256_manifest.csv", "source_v50/sha256_manifest.csv"),
]:
    copy(src, rel)

cases = read_csv(v50_dir / "public_repo_audit_case_rows.csv")
queries = read_csv(v50_dir / "commercial_return" / "query_set.csv")
spans = read_csv(v50_dir / "public_repo_source_span_rows.csv")
case_by_query = {f"v50_{idx:03d}": case for idx, case in enumerate(cases, start=1)}
span_keys = {(row["case_id"], row["kind"], row["path"], row["sha256"], row["line"]) for row in spans}
expected_query_ids = [row["query_id"] for row in queries]

system_specs = [
    {
        "system_id": "D",
        "label": "30B open-weight LLM + RAG",
        "size_class": "30b",
        "min_b": 25.0,
        "max_b": 40.0,
        "env_name": "V52D_30B_LLM_RAG_EVIDENCE_DIR",
        "evidence_dir_arg": d_evidence_dir_arg,
        "summary_prefix": "d_30b",
    },
    {
        "system_id": "E",
        "label": "70B open-weight LLM + RAG",
        "size_class": "70b",
        "min_b": 65.0,
        "max_b": 80.0,
        "env_name": "V52D_70B_LLM_RAG_EVIDENCE_DIR",
        "evidence_dir_arg": e_evidence_dir_arg,
        "summary_prefix": "e_70b",
    },
]

schema_rows = []
template_rows = []
for spec in system_specs:
    schema_rows.extend(
        [
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "system_id", "required": 1, "rule": f"must equal {spec['system_id']}"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "model_id", "required": 1, "rule": "stable open-weight model identifier; placeholders and fixture labels rejected"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "parameter_count_b", "required": 1, "rule": f"float in [{spec['min_b']}, {spec['max_b']}]"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "open_weight_license_uri", "required": 1, "rule": "public http(s) model/license reference; placeholders rejected"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "model_artifact_sha256", "required": 1, "rule": "sha256:<64 hex>; placeholder digests rejected"},
            {"system_id": spec["system_id"], "artifact": "model_identity.json", "field": "external_api_used", "required": 1, "rule": "must be 0 for open-weight D/E rows"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_answer_rows.csv", "field": "query_id", "required": 1, "rule": "must cover every v50 query id exactly once"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_answer_rows.csv", "field": "predicted_label", "required": 1, "rule": "scored against v50 expected_label"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_answer_rows.csv", "field": "raw_prompt_context_bytes", "required": 1, "rule": "positive integer"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_citation_rows.csv", "field": "case_id/kind/path/sha256/line", "required": 1, "rule": "must bind to v50 source spans"},
            {"system_id": spec["system_id"], "artifact": "llm_rag_resource_rows.csv", "field": "latency_ns", "required": 1, "rule": "positive measured runtime"},
        ]
    )
    for query in queries:
        case = case_by_query[query["query_id"]]
        template_rows.append(
            {
                "system_id": spec["system_id"],
                "query_id": query["query_id"],
                "case_id": case["case_id"],
                "size_class": spec["size_class"],
                "model_id": f"replace-with-{spec['size_class']}-open-weight-model-id",
                "expected_label": case["expected_label"],
                "predicted_label": "",
                "answer": "",
                "raw_prompt_context_bytes": "",
                "retrieved_span_rows": "",
                "prompt_context_sha256": "",
                "output_sha256": "",
                "latency_ns": "",
                "external_api_used": "0",
                "route_memory_store_used": "0",
                "compact_routehint_used": "0",
            }
        )
write_csv(run_dir / "llm_rag_required_field_rows.csv", list(schema_rows[0].keys()), schema_rows)
write_csv(run_dir / "llm_rag_answer_template.csv", list(template_rows[0].keys()), template_rows)

identity_templates = {}
for spec in system_specs:
    identity_templates[spec["system_id"]] = {
        "system_id": spec["system_id"],
        "model_id": f"replace-with-{spec['size_class']}-open-weight-model-id",
        "parameter_count_b": None,
        "size_class": spec["size_class"],
        "runner": "llama.cpp|vllm|transformers|tgi|sglang|other",
        "quantization": "record exact quantization or none",
        "model_artifact_uri": "local path or HTTPS model artifact identifier",
        "model_artifact_sha256": "sha256:<64 hex>",
        "open_weight_license_uri": "required",
        "rag_context_builder": "describe retrieval and prompt assembly",
        "context_length": None,
        "external_api_used": 0,
        "external_network_used": 0,
    }
(run_dir / "model_identity_templates.json").write_text(json.dumps(identity_templates, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary = {
    "v52d_30b70b_llm_rag_intake_contract_ready": 1,
    "v52d_v50_seed_dependency_blocker_ready": 0,
    "missing_v50_seed_artifact_rows": 0,
    "required_systems": "D,E",
    "baseline_name": "30B/70B open-weight LLM + RAG",
    "d_30b_evidence_dir_supplied": int(bool(d_evidence_dir_arg)),
    "e_70b_evidence_dir_supplied": int(bool(e_evidence_dir_arg)),
    "d_30b_supplied_evidence_ready": 0,
    "e_70b_supplied_evidence_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "d_30b_query_rows": 0,
    "e_70b_query_rows": 0,
    "d_30b_accuracy": "0.000000",
    "e_70b_accuracy": "0.000000",
    "d_30b_citation_accuracy": "0.000000",
    "e_70b_citation_accuracy": "0.000000",
    "d_30b_validation_error_rows": 0,
    "e_70b_validation_error_rows": 0,
    "external_api_used": 0,
    "route_memory_store_used": 0,
    "compact_routehint_used": 0,
    "v50_seed_query_rows": int(v50_summary.get("audit_case_rows", "0")),
    "v50_seed_reused": 1 if v50_seed_ready_arg == "1" else 0,
    "v50_public_refresh_allowed": int(v50_refresh_allowed_arg == "1"),
    "v50_public_refresh_executed": 0 if v50_seed_ready_arg == "1" else int(v50_refresh_allowed_arg == "1"),
    "v50_seed_refresh_approval_required": 0,
    "v52_absorb_ready": 0,
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": "30b-and-70b-llm-rag-evidence-dirs-missing",
}
decision_rows = [
    ("intake-contract", "pass", "D/E evidence schema and templates are emitted"),
    ("public-repo-seed", "pass", "uses existing v50 3-repo / 9-query seed without default public refresh"),
]
validation_rows = []


def validate_system(spec):
    prefix = spec["summary_prefix"]
    evidence_dir_arg = spec["evidence_dir_arg"]
    evidence_dir = Path(evidence_dir_arg) if evidence_dir_arg else None
    system_id = spec["system_id"]
    status_rows = []
    if not evidence_dir or not evidence_dir.is_dir():
        status_rows.append({"system_id": system_id, "check": "evidence-dir", "status": "blocked", "reason": f"{spec['env_name']} not supplied"})
        return False, status_rows, "evidence-dir-missing"

    required = {
        "identity": evidence_dir / "model_identity.json",
        "answers": evidence_dir / "llm_rag_answer_rows.csv",
        "citations": evidence_dir / "llm_rag_citation_rows.csv",
        "resources": evidence_dir / "llm_rag_resource_rows.csv",
    }
    for name, path in required.items():
        if path.is_file() and path.stat().st_size > 0:
            copy(path, f"supplied_evidence/{system_id}/{path.name}")
            status_rows.append({"system_id": system_id, "check": f"{name}-file", "status": "pass", "reason": "present"})
        else:
            status_rows.append({"system_id": system_id, "check": f"{name}-file", "status": "fail", "reason": "missing-or-empty"})
    if not all(path.is_file() and path.stat().st_size > 0 for path in required.values()):
        return False, status_rows, "required-files-missing"

    errors = []
    identity = json.loads(required["identity"].read_text(encoding="utf-8"))
    if identity.get("system_id") != system_id:
        errors.append("identity-system-id-mismatch")
    parameter_count_b = float_value(identity, "parameter_count_b", errors, minimum=spec["min_b"], maximum=spec["max_b"])
    if not is_nonplaceholder_text(identity.get("model_id", "")):
        errors.append("identity-model-id-placeholder-or-missing")
    if not is_public_uri(identity.get("open_weight_license_uri", "")):
        errors.append("identity-open-weight-license-uri-invalid-or-placeholder")
    if not is_sha256(identity.get("model_artifact_sha256", "")):
        errors.append("identity-model-artifact-sha256-invalid-or-placeholder")
    if int(identity.get("external_api_used", 0)) != 0:
        errors.append("identity-external-api-used-not-zero")
    model_id = identity.get("model_id", "")

    answers = read_csv(required["answers"])
    citations = read_csv(required["citations"])
    resources = read_csv(required["resources"])
    answer_query_ids = [row.get("query_id", "") for row in answers]
    if sorted(answer_query_ids) != sorted(expected_query_ids) or len(answer_query_ids) != len(set(answer_query_ids)):
        errors.append("answer-query-coverage-mismatch")
    correct_rows = 0
    raw_context_rows = 0
    latency_ns_total = 0
    for row in answers:
        query_id = row.get("query_id", "")
        case = case_by_query.get(query_id)
        row_errors = []
        if row.get("system_id") != system_id:
            row_errors.append("answer-system-id-mismatch")
        if row.get("model_id") != model_id:
            row_errors.append("answer-model-id-mismatch")
        if not case or row.get("case_id") != case["case_id"]:
            row_errors.append("answer-case-id-mismatch")
        if not row.get("predicted_label"):
            row_errors.append("answer-predicted-label-missing")
        if row.get("predicted_label") == (case or {}).get("expected_label"):
            correct_rows += 1
        if int_value(row, "raw_prompt_context_bytes", row_errors, minimum=1) > 0:
            raw_context_rows += 1
        int_value(row, "retrieved_span_rows", row_errors, minimum=1)
        latency_ns_total += int_value(row, "latency_ns", row_errors, minimum=1)
        if not is_sha256(row.get("prompt_context_sha256", "")):
            row_errors.append("answer-prompt-context-sha256-invalid")
        if not is_sha256(row.get("output_sha256", "")):
            row_errors.append("answer-output-sha256-invalid")
        if row.get("external_api_used") != "0":
            row_errors.append("answer-external-api-used-not-zero")
        if row.get("route_memory_store_used") != "0" or row.get("compact_routehint_used") != "0":
            row_errors.append("answer-route-memory-or-routehint-not-zero")
        errors.extend(f"{query_id}:{err}" for err in row_errors)

    citation_query_ids = {row.get("query_id", "") for row in citations}
    if citation_query_ids != set(expected_query_ids):
        errors.append("citation-query-coverage-mismatch")
    citation_correct_rows = 0
    for row in citations:
        row_errors = []
        key = (row.get("case_id", ""), row.get("kind", ""), row.get("path", ""), row.get("sha256", ""), row.get("line", ""))
        if key not in span_keys:
            row_errors.append("citation-source-span-mismatch")
        if row.get("query_id", "") not in case_by_query:
            row_errors.append("citation-query-id-unknown")
        if row.get("citation_correct") == "1":
            citation_correct_rows += 1
        elif row.get("citation_correct") != "0":
            row_errors.append("citation-correct-not-0-or-1")
        errors.extend(f"{row.get('query_id', '')}:citation:{err}" for err in row_errors)

    resource_query_ids = [row.get("query_id", "") for row in resources]
    if sorted(resource_query_ids) != sorted(expected_query_ids) or len(resource_query_ids) != len(set(resource_query_ids)):
        errors.append("resource-query-coverage-mismatch")
    for row in resources:
        row_errors = []
        if row.get("model_id") != model_id:
            row_errors.append("resource-model-id-mismatch")
        int_value(row, "latency_ns", row_errors, minimum=1)
        int_value(row, "raw_prompt_context_bytes", row_errors, minimum=1)
        int_value(row, "retrieved_span_rows", row_errors, minimum=1)
        if row.get("external_api_used") != "0":
            row_errors.append("resource-external-api-used-not-zero")
        errors.extend(f"{row.get('query_id', '')}:resource:{err}" for err in row_errors)

    if errors:
        for err in errors:
            status_rows.append({"system_id": system_id, "check": "supplied-evidence", "status": "fail", "reason": err})
        return False, status_rows, "supplied-evidence-invalid"

    query_rows = len(expected_query_ids)
    summary.update(
        {
            f"{prefix}_supplied_evidence_ready": 1,
            f"{prefix}_query_rows": query_rows,
            f"{prefix}_accuracy": f"{correct_rows / query_rows:.6f}",
            f"{prefix}_citation_accuracy": f"{citation_correct_rows / len(citations):.6f}" if citations else "0.000000",
            f"{prefix}_validation_error_rows": 0,
        }
    )
    if system_id == "D":
        summary["required_30b_baseline_ready"] = 1
    if system_id == "E":
        summary["required_70b_baseline_ready"] = 1
    status_rows.append({"system_id": system_id, "check": "supplied-evidence", "status": "pass", "reason": f"{spec['size_class']} evidence validates"})
    return True, status_rows, ""


blocking_reasons = []
for spec in system_specs:
    ready, rows, reason = validate_system(spec)
    validation_rows.extend(rows)
    if ready:
        decision_rows.append((f"{spec['size_class']}-llm-rag-real-row", "pass", f"{spec['system_id']} supplied evidence validates"))
    else:
        blocking_reasons.append(f"{spec['size_class']}:{reason}")
        decision_rows.append((f"{spec['size_class']}-llm-rag-real-row", "blocked", reason))
    summary[f"{spec['summary_prefix']}_validation_error_rows"] = sum(
        1 for row in rows if row["status"] == "fail"
    )

if summary["required_30b_baseline_ready"] and summary["required_70b_baseline_ready"]:
    summary["v52_absorb_ready"] = 1
    summary["blocking_reason"] = ""
    decision_rows.append(("v52-d-e-absorb-ready", "pass", "both D and E rows can be consumed by a later v52 registry update"))
else:
    summary["blocking_reason"] = ";".join(blocking_reasons) if blocking_reasons else "30b-or-70b-evidence-missing"
    decision_rows.append(("v52-d-e-absorb-ready", "blocked", "both D and E rows must validate before v52 absorb"))

decision_rows.extend(
    [
        ("v52-full-baseline-war", "blocked", "v52 still needs the full A-H registry update and release-scale evidence"),
        ("100b-plus-optional-row", "blocked", "F row is still optional/deferred unless hosted/API evidence is supplied"),
        ("real-release-package", "blocked", "this intake is not a release package"),
    ]
)
write_csv(run_dir / "llm_rag_validation_rows.csv", ["system_id", "check", "status", "reason"], validation_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V52D_30B70B_LLM_RAG_BOUNDARY.md").write_text(
    "# v52d 30B/70B LLM+RAG Evidence Intake Boundary\n\n"
    "This is the evidence intake gate for baselines D and E, not a completed v52 baseline war.\n\n"
    "Existing v50 public-repo seed artifacts are reused by default. A public refresh is blocked unless `V52D_ALLOW_V50_REFRESH=1` is explicitly set.\n\n"
    "A valid supplied evidence directory for each system must contain:\n\n"
    "- `model_identity.json` with the expected system ID, parameter-count class, open-weight license URI, and sha256-bound model artifact identity.\n"
    "- `llm_rag_answer_rows.csv` with one answer row for every v50 query ID.\n"
    "- `llm_rag_citation_rows.csv` with source-span-bound citations against the v50 source span registry.\n"
    "- `llm_rag_resource_rows.csv` with measured runtime/resource rows and `external_api_used=0`.\n\n"
    "Default/no-env execution intentionally remains blocked. Do not publish D/E, 30B-150B, or v1.0 comparison claims from this contract alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52d-30b70b-llm-rag-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "required_systems": ["D", "E"],
    "v52d_30b70b_llm_rag_intake_contract_ready": 1,
    "v52d_v50_seed_dependency_blocker_ready": 0,
    "missing_v50_seed_artifact_rows": 0,
    "required_30b_baseline_ready": summary["required_30b_baseline_ready"],
    "required_70b_baseline_ready": summary["required_70b_baseline_ready"],
    "v52_absorb_ready": summary["v52_absorb_ready"],
    "v52_ready": 0,
    "real_release_package_ready": 0,
    "blocking_reason": summary["blocking_reason"],
    "v50_summary_sha256": sha256(results / "v50_public_repo_auditor_3repo_summary.csv"),
    "v50_seed_reused": summary["v50_seed_reused"],
    "v50_public_refresh_allowed": summary["v50_public_refresh_allowed"],
    "v50_public_refresh_executed": summary["v50_public_refresh_executed"],
    "v50_seed_refresh_approval_required": summary["v50_seed_refresh_approval_required"],
}
(run_dir / "v52d_30b70b_llm_rag_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "llm_rag_required_field_rows.csv",
    "llm_rag_answer_template.csv",
    "model_identity_templates.json",
    "llm_rag_validation_rows.csv",
    "V52D_30B70B_LLM_RAG_BOUNDARY.md",
    "v52d_30b70b_llm_rag_manifest.json",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/query_set.csv",
    "source_v50/reference_poc_result_rows.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
    "source_v50/sha256_manifest.csv",
]
for spec in system_specs:
    if spec["evidence_dir_arg"]:
        for name in [
            "model_identity.json",
            "llm_rag_answer_rows.csv",
            "llm_rag_citation_rows.csv",
            "llm_rag_resource_rows.csv",
        ]:
            rel = f"supplied_evidence/{spec['system_id']}/{name}"
            if (run_dir / rel).is_file():
                artifact_rels.append(rel)

artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52d_30b70b_llm_rag_evidence_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
