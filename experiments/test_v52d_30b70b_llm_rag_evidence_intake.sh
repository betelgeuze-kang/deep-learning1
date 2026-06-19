#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_decision.csv"
SPOOFED_D_DIR="$RESULTS_DIR/v52d_spoofed_30b_evidence"
SPOOFED_E_DIR="$RESULTS_DIR/v52d_spoofed_70b_evidence"

V50_RUN_DIR="$RESULTS_DIR/v50_public_repo_auditor_3repo/audit_001"
V50_REQUIRED_FILES=(
  "$RESULTS_DIR/v50_public_repo_auditor_3repo_summary.csv"
  "$V50_RUN_DIR/public_repo_audit_case_rows.csv"
  "$V50_RUN_DIR/public_repo_source_span_rows.csv"
  "$V50_RUN_DIR/commercial_return/query_set.csv"
  "$V50_RUN_DIR/commercial_return/poc_result_rows.csv"
  "$V50_RUN_DIR/sha256_manifest.csv"
)

missing_v50_seed_files=()
for required_file in "${V50_REQUIRED_FILES[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    missing_v50_seed_files+=("$required_file")
  fi
done

if [[ "${#missing_v50_seed_files[@]}" -gt 0 && "${V52D_REQUIRE_READY_TEST:-0}" != "1" ]]; then
  "$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null

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
    "v52d_30b70b_llm_rag_intake_contract_ready": "0",
    "v52d_v50_seed_dependency_blocker_ready": "1",
    "required_systems": "D,E",
    "baseline_name": "30B/70B open-weight LLM + RAG",
    "d_30b_evidence_dir_supplied": "0",
    "e_70b_evidence_dir_supplied": "0",
    "d_30b_supplied_evidence_ready": "0",
    "e_70b_supplied_evidence_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "d_30b_query_rows": "0",
    "e_70b_query_rows": "0",
    "v50_seed_query_rows": "0",
    "v50_seed_reused": "0",
    "v50_public_refresh_allowed": "0",
    "v50_public_refresh_executed": "0",
    "v50_seed_refresh_approval_required": "1",
    "v52_absorb_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "v50-seed-artifacts-missing;30b:evidence-dir-missing;70b:evidence-dir-missing",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52d dependency blocker {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("missing_v50_seed_artifact_rows", "0")) <= 0:
    raise SystemExit("v52d dependency blocker should count missing v50 seed artifacts")

required_files = [
    "llm_rag_required_field_rows.csv",
    "llm_rag_answer_template.csv",
    "model_identity_templates.json",
    "llm_rag_validation_rows.csv",
    "v52d_v50_seed_dependency_blocker_rows.csv",
    "V52D_30B70B_LLM_RAG_BOUNDARY.md",
    "v52d_30b70b_llm_rag_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52d dependency blocker artifact: {rel}")

blocker_rows = read_csv(run_dir / "v52d_v50_seed_dependency_blocker_rows.csv")
if len(blocker_rows) != int(summary["missing_v50_seed_artifact_rows"]):
    raise SystemExit("v52d dependency blocker rows should match missing artifact count")
if any(row["implicit_refresh_allowed"] != "0" or row["approval_required"] != "1" for row in blocker_rows):
    raise SystemExit("v52d dependency blocker rows should require approval and forbid implicit refresh")
if any(row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0" for row in blocker_rows):
    raise SystemExit("v52d dependency blocker rows should forbid fixtures and tests-only merge")

schema_rows = read_csv(run_dir / "llm_rag_required_field_rows.csv")
if len(schema_rows) < 22:
    raise SystemExit("v52d dependency blocker should still emit D/E schema rows")
if not any("placeholders rejected" in row["rule"] for row in schema_rows):
    raise SystemExit("v52d schema should document placeholder rejection")
templates = read_csv(run_dir / "llm_rag_answer_template.csv")
if templates:
    raise SystemExit("v52d dependency blocker must not fabricate answer template rows without v50 seed queries")

validation_rows = read_csv(run_dir / "llm_rag_validation_rows.csv")
if not any(row["system_id"] == "v50" and row["status"] == "blocked" for row in validation_rows):
    raise SystemExit("v52d dependency blocker should include a blocked v50 validation row")
if not any(row["system_id"] == "D" and row["status"] == "blocked" for row in validation_rows):
    raise SystemExit("v52d dependency blocker should keep D blocked")
if not any(row["system_id"] == "E" and row["status"] == "blocked" for row in validation_rows):
    raise SystemExit("v52d dependency blocker should keep E blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("v52d-v50-seed-dependency-blocker") != "pass":
    raise SystemExit("v52d dependency blocker gate should pass")
for gate in ["intake-contract", "public-repo-seed", "30b-llm-rag-real-row", "70b-llm-rag-real-row", "v52-d-e-absorb-ready"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52d dependency blocker should keep {gate} blocked")

manifest = json.loads((run_dir / "v52d_30b70b_llm_rag_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52d_v50_seed_dependency_blocker_ready") != 1:
    raise SystemExit("v52d dependency blocker manifest should be ready")
if manifest.get("v52d_30b70b_llm_rag_intake_contract_ready") != 0:
    raise SystemExit("v52d dependency blocker manifest must not claim intake contract readiness")
boundary = (run_dir / "V52D_30B70B_LLM_RAG_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "refuses implicit public refresh",
    "V52D_ALLOW_V50_REFRESH=1",
    "v52d_v50_seed_dependency_blocker_ready=1",
    "Blocked wording: D/E baseline ready",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52d dependency blocker boundary missing {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52d dependency blocker sha mismatch: {rel}")
PY

  echo "v52d 30B/70B LLM RAG missing-v50-seed guard smoke passed"
  exit 0
fi

"$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v52d summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v52d_30b70b_llm_rag_intake_contract_ready": "1",
    "v52d_v50_seed_dependency_blocker_ready": "0",
    "missing_v50_seed_artifact_rows": "0",
    "required_systems": "D,E",
    "baseline_name": "30B/70B open-weight LLM + RAG",
    "d_30b_evidence_dir_supplied": "0",
    "e_70b_evidence_dir_supplied": "0",
    "d_30b_supplied_evidence_ready": "0",
    "e_70b_supplied_evidence_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "d_30b_query_rows": "0",
    "e_70b_query_rows": "0",
    "d_30b_accuracy": "0.000000",
    "e_70b_accuracy": "0.000000",
    "d_30b_citation_accuracy": "0.000000",
    "e_70b_citation_accuracy": "0.000000",
    "d_30b_validation_error_rows": "0",
    "e_70b_validation_error_rows": "0",
    "external_api_used": "0",
    "route_memory_store_used": "0",
    "compact_routehint_used": "0",
    "v50_seed_query_rows": "9",
    "v50_seed_reused": "1",
    "v50_public_refresh_allowed": "0",
    "v50_public_refresh_executed": "0",
    "v50_seed_refresh_approval_required": "0",
    "v52_absorb_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "30b:evidence-dir-missing;70b:evidence-dir-missing",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52d {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["intake-contract", "public-repo-seed"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52d gate should pass: {gate}")
for gate in [
    "30b-llm-rag-real-row",
    "70b-llm-rag-real-row",
    "v52-d-e-absorb-ready",
    "v52-full-baseline-war",
    "100b-plus-optional-row",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52d gate should remain blocked: {gate}")

required_files = [
    "llm_rag_required_field_rows.csv",
    "llm_rag_answer_template.csv",
    "model_identity_templates.json",
    "llm_rag_validation_rows.csv",
    "V52D_30B70B_LLM_RAG_BOUNDARY.md",
    "v52d_30b70b_llm_rag_manifest.json",
    "sha256_manifest.csv",
    "source_v50/public_repo_audit_case_rows.csv",
    "source_v50/public_repo_source_span_rows.csv",
    "source_v50/query_set.csv",
    "source_v50/reference_poc_result_rows.csv",
    "source_v50/v50_public_repo_auditor_3repo_summary.csv",
    "source_v50/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52d artifact: {rel}")

schema_rows = read_csv(run_dir / "llm_rag_required_field_rows.csv")
if len(schema_rows) < 22:
    raise SystemExit("v52d should emit required field schema rows for D and E")
for system_id, size_rule in [("D", "float in [25.0, 40.0]"), ("E", "float in [65.0, 80.0]")]:
    if not any(row["system_id"] == system_id and row["field"] == "parameter_count_b" and row["rule"] == size_rule for row in schema_rows):
        raise SystemExit(f"v52d schema should require parameter range for {system_id}")
    if not any(row["system_id"] == system_id and row["field"] == "external_api_used" for row in schema_rows):
        raise SystemExit(f"v52d schema should require external_api_used=0 for {system_id}")
    for raw_field in ["raw_answer", "raw_citation", "raw_output_sha256", "generation_transcript_sha256"]:
        if not any(row["system_id"] == system_id and row["field"] == raw_field for row in schema_rows):
            raise SystemExit(f"v52d schema should require {raw_field} for {system_id}")

templates = read_csv(run_dir / "llm_rag_answer_template.csv")
if len(templates) != 18:
    raise SystemExit("v52d should emit eighteen answer template rows from v50 for D/E")
if sum(1 for row in templates if row["system_id"] == "D") != 9:
    raise SystemExit("v52d D template row count mismatch")
if sum(1 for row in templates if row["system_id"] == "E") != 9:
    raise SystemExit("v52d E template row count mismatch")
if any(row["external_api_used"] != "0" for row in templates):
    raise SystemExit("v52d D/E templates should forbid external API use")
if any(row["route_memory_store_used"] != "0" or row["compact_routehint_used"] != "0" for row in templates):
    raise SystemExit("v52d D/E templates should not use RouteMemory/RouteHint")

identity_templates = json.loads((run_dir / "model_identity_templates.json").read_text(encoding="utf-8"))
if sorted(identity_templates.keys()) != ["D", "E"]:
    raise SystemExit("v52d identity templates should cover D and E")
if identity_templates["D"].get("size_class") != "30b" or identity_templates["E"].get("size_class") != "70b":
    raise SystemExit("v52d identity templates should identify 30B and 70B classes")
if identity_templates["D"].get("external_api_used") != 0 or identity_templates["E"].get("external_api_used") != 0:
    raise SystemExit("v52d identity templates should default to open-weight/no external API")

validation_rows = read_csv(run_dir / "llm_rag_validation_rows.csv")
expected_validation = [
    {
        "system_id": "D",
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52D_30B_LLM_RAG_EVIDENCE_DIR not supplied",
    },
    {
        "system_id": "E",
        "check": "evidence-dir",
        "status": "blocked",
        "reason": "V52D_70B_LLM_RAG_EVIDENCE_DIR not supplied",
    },
]
if validation_rows != expected_validation:
    raise SystemExit("v52d no-env validation rows should block on missing D/E evidence dirs")

manifest = json.loads((run_dir / "v52d_30b70b_llm_rag_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52d_30b70b_llm_rag_intake_contract_ready") != 1:
    raise SystemExit("v52d manifest should mark intake contract ready")
if manifest.get("v52d_v50_seed_dependency_blocker_ready") != 0:
    raise SystemExit("v52d ready-path manifest should not mark the v50 dependency blocker ready")
if manifest.get("required_30b_baseline_ready") != 0 or manifest.get("required_70b_baseline_ready") != 0:
    raise SystemExit("v52d manifest should keep D/E baselines blocked by default")
if manifest.get("v52_absorb_ready") != 0:
    raise SystemExit("v52d manifest should not absorb no-env D/E evidence")
if (
    manifest.get("v50_seed_reused") != 1
    or manifest.get("v50_public_refresh_allowed") != 0
    or manifest.get("v50_public_refresh_executed") != 0
):
    raise SystemExit("v52d manifest should record default v50 seed reuse without public refresh")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52d sha256 mismatch: {rel}")

boundary = (run_dir / "V52D_30B70B_LLM_RAG_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "baselines D and E",
    "open-weight license URI",
    "v50 public-repo seed artifacts are reused by default",
    "llm_rag_answer_rows.csv",
    "Default/no-env execution intentionally remains blocked",
    "Do not publish D/E, 30B-150B, or v1.0 comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52d boundary missing {snippet}")
PY

rm -rf "$SPOOFED_D_DIR" "$SPOOFED_E_DIR"
mkdir -p "$SPOOFED_D_DIR" "$SPOOFED_E_DIR"

python3 - "$RESULTS_DIR" "$SPOOFED_D_DIR" "$SPOOFED_E_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

results = Path(sys.argv[1])
d_dir = Path(sys.argv[2])
e_dir = Path(sys.argv[3])
v50_dir = results / "v50_public_repo_auditor_3repo/audit_001"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


queries = read_csv(v50_dir / "commercial_return/query_set.csv")
cases = read_csv(v50_dir / "public_repo_audit_case_rows.csv")
spans = read_csv(v50_dir / "public_repo_source_span_rows.csv")
case_by_query = {f"v50_{idx:03d}": case for idx, case in enumerate(cases, start=1)}
span_by_case = {}
for span in spans:
    span_by_case.setdefault(span["case_id"], span)

answer_fields = [
    "system_id",
    "query_id",
    "case_id",
    "model_id",
    "predicted_label",
    "prompt_template_sha256",
    "context_budget",
    "retrieval_budget",
    "seed",
    "raw_answer",
    "raw_citation",
    "raw_output_sha256",
    "generation_transcript_sha256",
    "raw_prompt_context_bytes",
    "retrieved_span_rows",
    "prompt_context_sha256",
    "output_sha256",
    "latency_ns",
    "external_api_used",
    "route_memory_store_used",
    "compact_routehint_used",
]
citation_fields = ["query_id", "case_id", "kind", "path", "sha256", "line", "citation_correct"]
resource_fields = [
    "query_id",
    "model_id",
    "latency_ns",
    "raw_prompt_context_bytes",
    "retrieved_span_rows",
    "peak_memory_mb",
    "evaluator_version",
    "evaluator_artifact_sha256",
    "external_api_used",
]

for target_dir, system_id, size_class, parameter_count in [
    (d_dir, "D", "30b", 32.0),
    (e_dir, "E", "70b", 70.0),
]:
    model_id = f"replace-with-{size_class}-fixture-model"
    identity = {
        "system_id": system_id,
        "model_id": model_id,
        "model_repository": f"review.invalid/{size_class}-fixture",
        "model_revision": "fixture-revision",
        "parameter_count_b": parameter_count,
        "size_class": size_class,
        "runner": "fixture",
        "runtime": "fixture",
        "runtime_version": "fixture",
        "quantization": "fixture",
        "model_artifact_uri": "https://review.invalid/model",
        "model_artifact_sha256": "sha256:" + ("a" * 64),
        "open_weight_license_uri": "https://review.invalid/license",
        "hardware": "fixture",
        "rag_context_builder": "fixture",
        "context_length": 4096,
        "non_fixture_declared": 0,
        "external_api_used": 0,
        "external_network_used": 0,
    }
    (target_dir / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    answer_rows = []
    citation_rows = []
    resource_rows = []
    for query in queries:
        case = case_by_query[query["query_id"]]
        span = span_by_case[case["case_id"]]
        raw_answer = f"fixture answer for {query['query_id']}"
        raw_citation = f"fixture citation for {span['path']}:{span['line']}"
        raw_output = raw_answer + "\n" + raw_citation
        supplied_raw_answer = raw_answer
        if system_id == "D" and query["query_id"] == queries[0]["query_id"]:
            supplied_raw_answer = raw_answer + " tampered after hash"
        answer_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "case_id": case["case_id"],
                "model_id": model_id,
                "predicted_label": case["expected_label"],
                "prompt_template_sha256": "sha256:" + hashlib.sha256(("prompt:" + raw_output).encode("utf-8")).hexdigest(),
                "context_budget": "4096",
                "retrieval_budget": "1",
                "seed": "0",
                "raw_answer": supplied_raw_answer,
                "raw_citation": raw_citation,
                "raw_output_sha256": "sha256:" + hashlib.sha256(raw_output.encode("utf-8")).hexdigest(),
                "generation_transcript_sha256": "sha256:" + hashlib.sha256(("transcript:" + raw_output).encode("utf-8")).hexdigest(),
                "raw_prompt_context_bytes": "128",
                "retrieved_span_rows": "1",
                "prompt_context_sha256": "sha256:" + ("b" * 64),
                "output_sha256": "sha256:" + ("c" * 64),
                "latency_ns": "1",
                "external_api_used": "0",
                "route_memory_store_used": "0",
                "compact_routehint_used": "0",
            }
        )
        citation_rows.append(
            {
                "query_id": query["query_id"],
                "case_id": case["case_id"],
                "kind": span["kind"],
                "path": span["path"],
                "sha256": span["sha256"],
                "line": span["line"],
                "citation_correct": "1",
            }
        )
        resource_rows.append(
            {
                "query_id": query["query_id"],
                "model_id": model_id,
                "latency_ns": "1",
                "raw_prompt_context_bytes": "128",
                "retrieved_span_rows": "1",
                "peak_memory_mb": "1",
                "evaluator_version": "v52d-evaluator",
                "evaluator_artifact_sha256": "sha256:" + hashlib.sha256(b"v52d-evaluator").hexdigest(),
                "external_api_used": "0",
            }
        )
    write_csv(target_dir / "llm_rag_answer_rows.csv", answer_fields, answer_rows)
    write_csv(target_dir / "llm_rag_citation_rows.csv", citation_fields, citation_rows)
    write_csv(target_dir / "llm_rag_resource_rows.csv", resource_fields, resource_rows)
PY

V52D_30B_LLM_RAG_EVIDENCE_DIR="$SPOOFED_D_DIR" \
V52D_70B_LLM_RAG_EVIDENCE_DIR="$SPOOFED_E_DIR" \
  "$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null

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
if summary["d_30b_evidence_dir_supplied"] != "1" or summary["e_70b_evidence_dir_supplied"] != "1":
    raise SystemExit("spoofed D/E evidence dirs should be supplied")
for field in ["d_30b_supplied_evidence_ready", "e_70b_supplied_evidence_ready", "required_30b_baseline_ready", "required_70b_baseline_ready", "v52_absorb_ready"]:
    if summary[field] != "0":
        raise SystemExit(f"spoofed D/E evidence should not open {field}")

validation_rows = read_csv(run_dir / "llm_rag_validation_rows.csv")
reasons = "\n".join(row["reason"] for row in validation_rows)
for expected in [
    "identity-model-id-placeholder-or-missing",
    "identity-open-weight-license-uri-invalid-or-placeholder",
    "identity-model-artifact-sha256-invalid-or-placeholder",
    "answer-raw-output-sha256-mismatch",
]:
    if expected not in reasons:
        raise SystemExit(f"spoofed D/E evidence should fail {expected}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["30b-llm-rag-real-row"] != "blocked" or decisions["70b-llm-rag-real-row"] != "blocked":
    raise SystemExit("spoofed D/E evidence should keep real-row gates blocked")
PY

"$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null

echo "v52d 30B/70B LLM RAG evidence intake smoke passed"
