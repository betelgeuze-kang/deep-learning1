#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53u_complete_source_de_open_weight_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v53u_complete_source_de_open_weight_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53u_complete_source_de_open_weight_evidence_intake_decision.csv"
SPOOF_D_DIR="$RESULTS_DIR/v53u_spoofed_30b_evidence"
SPOOF_E_DIR="$RESULTS_DIR/v53u_spoofed_70b_evidence"

"$ROOT_DIR/experiments/run_v53u_complete_source_de_open_weight_evidence_intake.sh" >/dev/null

"$ROOT_DIR/tools/verify_artifact.py" v53u-de-open-weight-intake \
  "$ROOT_DIR/baselines/v53u_de_open_weight_evidence_intake_contract.json" \
  --summary "$SUMMARY_CSV" \
  --decision "$DECISION_CSV" >/dev/null

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
    "v53u_complete_source_de_open_weight_evidence_intake_ready": "0",
    "required_systems": "D,E",
    "d_30b_evidence_dir_supplied": "0",
    "e_70b_evidence_dir_supplied": "0",
    "d_30b_supplied_evidence_ready": "0",
    "e_70b_supplied_evidence_ready": "0",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "same_query_set_de": "0",
    "same_source_manifest_de": "0",
    "same_context_budget_de": "0",
    "same_retrieval_budget_de": "0",
    "same_evaluator_version_de": "0",
    "raw_output_hash_bound_rate": "0.000000",
    "fixture_rows_in_measured_registry": "0",
    "v53i_query_rows": "1000",
    "v53i_source_span_rows": "1000",
    "unseen_repository_split_ready": "1",
    "v1_0_comparison_ready": "0",
    "public_comparison_claim_ready": "0",
    "real_release_package_ready": "0",
    "blocking_reason": "30b:evidence-dir-missing;70b:evidence-dir-missing",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53u default {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "de_required_field_rows.csv",
    "de_run_result_template_rows.csv",
    "de_validation_rows.csv",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53t/complete_source_unseen_repository_split_rows.csv",
    "V53U_COMPLETE_SOURCE_DE_EVIDENCE_BOUNDARY.md",
    "v53u_complete_source_de_open_weight_evidence_intake_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53u artifact: {rel}")

field_rows = read_csv(run_dir / "de_required_field_rows.csv")
if not any(row["field"] == "raw_output_sha256" for row in field_rows):
    raise SystemExit("v53u required field rows should require raw_output_sha256")
if not any(row["field"] == "evaluator_version" for row in field_rows):
    raise SystemExit("v53u required field rows should require evaluator_version")
if not any(row["artifact"] == "run_result_rows.csv" and row["field"] == "external_api_used" for row in field_rows):
    raise SystemExit("v53u required field rows should require external_api_used")

templates = read_csv(run_dir / "de_run_result_template_rows.csv")
if len(templates) != 2000:
    raise SystemExit("v53u should emit 2000 D/E template rows")
if sum(row["system_id"] == "D" for row in templates) != 1000:
    raise SystemExit("v53u should emit 1000 D template rows")
if sum(row["system_id"] == "E" for row in templates) != 1000:
    raise SystemExit("v53u should emit 1000 E template rows")
if any(row["corpus_snapshot_sha256"] != summary["v53i_query_rows_sha256"] for row in templates):
    raise SystemExit("v53u templates should bind the v53i corpus snapshot sha")
if any(row["external_api_used"] != "0" for row in templates):
    raise SystemExit("v53u templates should require external_api_used=0")

validation_rows = read_csv(run_dir / "de_validation_rows.csv")
if not any(row["system_id"] == "D" and row["status"] == "blocked" for row in validation_rows):
    raise SystemExit("v53u default should block D on missing evidence")
if not any(row["system_id"] == "E" and row["status"] == "blocked" for row in validation_rows):
    raise SystemExit("v53u default should block E on missing evidence")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("v53-foundation-input") != "pass":
    raise SystemExit("v53u should see the v53 foundation input")
for gate in ["30b-real-evidence", "70b-real-evidence", "same-condition-de", "public-comparison"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53u default should keep {gate} blocked")

manifest = json.loads((run_dir / "v53u_complete_source_de_open_weight_evidence_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("required_30b_baseline_ready") != 0 or manifest.get("required_70b_baseline_ready") != 0:
    raise SystemExit("v53u manifest must keep D/E readiness closed by default")

boundary = (run_dir / "V53U_COMPLETE_SOURCE_DE_EVIDENCE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "required_30b_baseline_ready=0",
    "required_70b_baseline_ready=0",
    "raw_output_hash_bound_rate=0.000000",
    "public_comparison_claim_ready=0",
    "Blocked wording: public A-H comparison",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53u boundary missing {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53u sha mismatch: {rel}")
PY

rm -rf "$SPOOF_D_DIR" "$SPOOF_E_DIR"
mkdir -p "$SPOOF_D_DIR" "$SPOOF_E_DIR"

python3 - "$RESULTS_DIR" "$SPOOF_D_DIR" "$SPOOF_E_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

results = Path(sys.argv[1])
d_dir = Path(sys.argv[2])
e_dir = Path(sys.argv[3])
query_path = results / "v53i_complete_source_query_instantiation/instantiate_001/complete_source_query_rows.csv"
query_hash = "sha256:" + hashlib.sha256(query_path.read_bytes()).hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


queries = read_csv(query_path)
fields = [
    "system_id",
    "query_id",
    "corpus_snapshot_sha256",
    "context_budget",
    "retrieval_budget",
    "model_id",
    "raw_answer",
    "raw_citation",
    "abstained",
    "latency_ns",
    "peak_memory_mb",
    "prompt_sha256",
    "output_sha256",
    "raw_output_sha256",
    "prompt_template_sha256",
    "seed",
    "evaluator_version",
    "external_api_used",
]
for target, system_id, parameter_count in [(d_dir, "D", 32.0), (e_dir, "E", 70.0)]:
    identity = {
        "system_id": system_id,
        "model_id": f"replace-with-{system_id}-model",
        "model_repository": "placeholder",
        "model_revision": "placeholder",
        "parameter_count_b": parameter_count,
        "quantization": "placeholder",
        "model_artifact_sha256": "sha256:" + "a" * 64,
        "open_weight_license_uri": "not-a-uri",
        "runtime": "placeholder",
        "runtime_version": "placeholder",
        "hardware": "placeholder",
        "non_fixture_declared": 0,
        "external_api_used": 0,
    }
    (target / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    rows = []
    for index, query in enumerate(queries):
        raw_answer = f"fixture answer {query['query_id']}"
        raw_citation = f"fixture citation {query['source_path']}:{query['source_line_start']}"
        raw_output = raw_answer + "\n" + raw_citation
        if index == 0:
            raw_answer = raw_answer + " tampered"
        rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "corpus_snapshot_sha256": query_hash,
                "context_budget": "4096",
                "retrieval_budget": "4",
                "model_id": identity["model_id"],
                "raw_answer": raw_answer,
                "raw_citation": raw_citation,
                "abstained": "0",
                "latency_ns": "1",
                "peak_memory_mb": "1",
                "prompt_sha256": "sha256:" + hashlib.sha256(("prompt" + query["query_id"]).encode()).hexdigest(),
                "output_sha256": "sha256:" + hashlib.sha256(("output" + query["query_id"]).encode()).hexdigest(),
                "raw_output_sha256": "sha256:" + hashlib.sha256(raw_output.encode()).hexdigest(),
                "prompt_template_sha256": "sha256:" + hashlib.sha256(b"template").hexdigest(),
                "seed": "0",
                "evaluator_version": "v53u-evaluator",
                "external_api_used": "0",
            }
        )
    write_csv(target / "run_result_rows.csv", fields, rows)
PY

V53U_30B_EVIDENCE_DIR="$SPOOF_D_DIR" \
V53U_70B_EVIDENCE_DIR="$SPOOF_E_DIR" \
  "$ROOT_DIR/experiments/run_v53u_complete_source_de_open_weight_evidence_intake.sh" >/dev/null

"$ROOT_DIR/tools/verify_artifact.py" v53u-de-open-weight-intake \
  "$ROOT_DIR/baselines/v53u_de_open_weight_evidence_intake_contract.json" \
  --summary "$SUMMARY_CSV" \
  --decision "$DECISION_CSV" >/dev/null

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
    raise SystemExit("v53u spoofed evidence dirs should be supplied")
for field in [
    "d_30b_supplied_evidence_ready",
    "e_70b_supplied_evidence_ready",
    "required_30b_baseline_ready",
    "required_70b_baseline_ready",
    "same_query_set_de",
    "same_context_budget_de",
    "same_retrieval_budget_de",
    "same_evaluator_version_de",
]:
    if summary[field] != "0":
        raise SystemExit(f"v53u spoofed evidence must keep {field}=0")
if summary["d_30b_query_rows"] != "1000" or summary["e_70b_query_rows"] != "1000":
    raise SystemExit("v53u spoofed evidence should still count supplied query rows")

reasons = "\n".join(row["reason"] for row in read_csv(run_dir / "de_validation_rows.csv"))
for expected in [
    "identity-model-id-placeholder-or-missing",
    "identity-model-artifact-sha256-invalid",
    "identity-open-weight-license-uri-invalid",
    "identity-non-fixture-declared-not-true",
    "raw-output-sha256-mismatch",
]:
    if expected not in reasons:
        raise SystemExit(f"v53u spoofed evidence should fail {expected}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["30b-real-evidence", "70b-real-evidence", "same-condition-de", "public-comparison"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53u spoofed evidence should keep {gate} blocked")
PY

"$ROOT_DIR/experiments/run_v53u_complete_source_de_open_weight_evidence_intake.sh" >/dev/null

echo "v53u complete-source D/E open-weight evidence intake smoke passed"
