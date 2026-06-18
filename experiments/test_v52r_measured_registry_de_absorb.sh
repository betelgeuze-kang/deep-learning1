#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52r_measured_registry_de_absorb/registry_001"
SUMMARY_CSV="$RESULTS_DIR/v52r_measured_registry_de_absorb_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52r_measured_registry_de_absorb_decision.csv"

V52X_REUSE_EXISTING="${V52X_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v52x_de_external_measured_bake_import.sh" >/dev/null
V52R_REUSE_EXISTING="${V52R_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v52r_measured_registry_de_absorb.sh" >/dev/null

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
    raise SystemExit(f"expected one v52r summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v52r_dependency_blocker_ready") == "1":
    expected_blocker = {
        "v52r_measured_registry_de_absorb_ready": "0",
        "v52r_dependency_blocker_ready": "1",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocker.items():
        if summary.get(field) != value:
            raise SystemExit(f"v52r dependency blocker {field}: expected {value}, got {summary.get(field)}")
    blocker_rows = read_csv(run_dir / "v52r_dependency_blocker_rows.csv")
    if not blocker_rows or {row["status"] for row in blocker_rows} != {"missing"}:
        raise SystemExit("v52r dependency blocker should record missing artifacts")
    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    if decisions.get("dependency-blocker-artifact") != "pass":
        raise SystemExit("v52r dependency blocker artifact gate should pass")
    for gate in ["measured-registry-replay", "same-query-source-local-systems", "30b-llm-rag-real-row", "70b-llm-rag-real-row", "real-release-package"]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v52r dependency blocker gate should remain blocked: {gate}")
    for rel in [
        "v52r_dependency_blocker_rows.csv",
        "V52R_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md",
        "v52r_measured_registry_de_absorb_manifest.json",
        "sha256_manifest.csv",
    ]:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v52r dependency blocker artifact: {rel}")
    boundary = (run_dir / "V52R_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
    for snippet in ["v52r_dependency_blocker_ready=1", "required_30b_baseline_ready=0", "Do not publish 30B-150B comparison claims"]:
        if snippet not in boundary:
            raise SystemExit(f"v52r dependency blocker boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v52r_measured_registry_de_absorb_ready": "1",
    "v52_ready": "0",
    "baseline_system_rows": "8",
    "local_measured_system_rows": "7",
    "local_measured_systems": "A/B/C/D/E/G/H",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "query_rows": "1000",
    "answer_rows": "7000",
    "citation_rows": "7000",
    "abstain_rows": "7000",
    "wrong_answer_guard_rows": "7000",
    "resource_rows": "7000",
    "retrieval_rows_c": "1000",
    "transcript_rows_c": "1000",
    "routehint_rows": "2000",
    "same_query_set_local_systems": "1",
    "same_source_manifest_local_systems": "1",
    "required_7b14b_baseline_ready": "1",
    "c_strict_exact_label_accuracy": "0.000000",
    "d_v53e_absorb_ready": "1",
    "e_v53e_absorb_ready": "1",
    "de_external_bake_import_rows": "2",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "optional_100b_plus_baseline_status": "deferred-with-reason",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52r {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v52r-measured-registry-de-absorb",
    "same-query-source-local-systems",
    "local-answer-citation-resource-rows",
    "routehint-policy-local-rows",
    "7b14b-local-model-rag-real-row",
    "30b-llm-rag-artifact-absorbed",
    "70b-llm-rag-artifact-absorbed",
    "v52-de-artifact-absorb-ready",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52r gate should pass: {gate}")
for gate in [
    "100b-plus-llm-rag-real-row",
    "30b-llm-rag-real-row",
    "70b-llm-rag-real-row",
    "v52-de-release-baseline-ready",
    "v52-full-baseline-war",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52r gate should remain blocked: {gate}")

required_files = [
    "measured_baseline_registry.csv",
    "measured_artifact_absorb_rows.csv",
    "V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md",
    "v52r_measured_registry_de_absorb_manifest.json",
    "sha256_manifest.csv",
    "source_v52i/v52i_abgh_same_query_measured_1000_summary.csv",
    "source_v52i/frozen_query_rows.csv",
    "source_v52i/abgh_answer_rows.csv",
    "source_v52l/v52l_7b14b_local_model_rag_v53e_1000_summary.csv",
    "source_v52l/c_answer_rows.csv",
    "source_v52l/c_citation_rows.csv",
    "source_v52l/c_retrieval_rows.csv",
    "source_v52l/ollama_generation_transcript_rows.csv",
    "source_v52p/v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv",
    "source_v52p/d_answer_rows.csv",
    "source_v52p/d_citation_rows.csv",
    "source_v52p/d_retrieval_rows.csv",
    "source_v52p/ollama_generation_transcript_rows.csv",
    "source_v52p/model_identity.json",
    "source_v52q/v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv",
    "source_v52q/e_answer_rows.csv",
    "source_v52q/e_citation_rows.csv",
    "source_v52q/e_retrieval_rows.csv",
    "source_v52q/ollama_generation_transcript_rows.csv",
    "source_v52q/model_identity.json",
    "source_v52l/model_identity.json",
    "source_v52c/v52c_7b14b_local_model_rag_evidence_intake_summary.csv",
    "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv",
    "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52r artifact: {rel}")

registry = read_csv(run_dir / "measured_baseline_registry.csv")
if len(registry) != 8 or {row["system_id"] for row in registry} != set("ABCDEFGH"):
    raise SystemExit("v52r registry should cover A-H")
by_id = {row["system_id"]: row for row in registry}
for system_id in ["A", "B", "G", "H"]:
    row = by_id[system_id]
    if row["measured_baseline_ready"] != "1" or row["query_set_id"] != "v53e_canary_query_scale_1000_full":
        raise SystemExit(f"v52r {system_id} should be measured over v53e")
    if row["answer_rows"] != "1000" or row["citation_rows"] != "1000" or row["resource_rows"] != "1000":
        raise SystemExit(f"v52r {system_id} measured counts mismatch")
c_row = by_id["C"]
if c_row["measured_baseline_ready"] != "1" or c_row["adapter_status"] != "measured-local-v52l":
    raise SystemExit("v52r C should be measured from v52l")
if c_row["external_model_used"] != "1" or c_row["answer_rows"] != "1000":
    raise SystemExit("v52r C external model / row counts mismatch")
d_row = by_id["D"]
if d_row["measured_baseline_ready"] != "1" or d_row["adapter_status"] != "measured-local-v52p":
    raise SystemExit("v52r D should be measured from v52p")
e_row = by_id["E"]
if e_row["measured_baseline_ready"] != "1" or e_row["adapter_status"] != "measured-local-v52q":
    raise SystemExit("v52r E should be measured from v52q")
if by_id["F"]["adapter_status"] != "deferred-with-reason":
    raise SystemExit("v52r F should remain deferred with reason")

absorbed = read_csv(run_dir / "measured_artifact_absorb_rows.csv")
if {row["status"] for row in absorbed} != {"absorbed"}:
    raise SystemExit("v52r artifact rows should be absorbed")
absorbed_by_artifact = {row["artifact"]: row for row in absorbed}
for artifact, rows in [
    ("query_set", "1000"),
    ("answer_rows_abgh", "4000"),
    ("answer_rows_c", "1000"),
    ("answer_rows_d", "1000"),
    ("answer_rows_e", "1000"),
    ("citation_rows_c", "1000"),
    ("transcript_rows_c", "1000"),
    ("routehint_rows", "2000"),
]:
    if absorbed_by_artifact.get(artifact, {}).get("expected_rows") != rows:
        raise SystemExit(f"v52r absorbed row count mismatch: {artifact}")

manifest = json.loads((run_dir / "v52r_measured_registry_de_absorb_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52r_measured_registry_de_absorb_ready") != 1 or manifest.get("v52_ready") != 0:
    raise SystemExit("v52r manifest readiness mismatch")
if manifest.get("local_measured_systems") != ["A", "B", "C", "D", "E", "G", "H"]:
    raise SystemExit("v52r manifest should bind A/B/C/G/H")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v52r sha256 mismatch: {rel}")

boundary = (run_dir / "V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "absorbs the v52i A/B/G/H local measured packet, the v52l C measured packet, and the v52p/v52q D/E artifact packets",
    "local_measured_systems=A/B/C/D/E/G/H",
    "answer_rows=7000",
    "required_30b_baseline_ready=0",
    "required_70b_baseline_ready=0",
    "c_strict_exact_label_accuracy=0.000000",
    "Do not publish 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52r boundary missing {snippet}")
PY

echo "v52r measured registry C absorb smoke passed"
