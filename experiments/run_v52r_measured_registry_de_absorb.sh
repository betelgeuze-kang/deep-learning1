#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52r_measured_registry_de_absorb"
RUN_ID="${V52R_RUN_ID:-registry_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V52R_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v52i_abgh_same_query_measured_1000_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52i_abgh_same_query_measured_1000.sh" >/dev/null
fi
if [[ "${V52R_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v52l_7b14b_local_model_rag_v53e_1000_summary.csv" ]]; then
  V52L_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52l_7b14b_local_model_rag_v53e_1000.sh" >/dev/null
fi
if [[ "${V52R_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v52c_7b14b_local_model_rag_evidence_intake_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52c_7b14b_local_model_rag_evidence_intake.sh" >/dev/null
fi
if [[ "${V52R_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null
fi
if [[ "${V52R_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52e_100b_plus_hosted_llm_rag_optional_intake.sh" >/dev/null
fi
if [[ "${V52R_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv" || ! -s "$RESULTS_DIR/v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv" ]]; then
  V52X_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52x_de_external_measured_bake_import.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v52i_dir = results / "v52i_abgh_same_query_measured_1000" / "measured_001"
v52l_dir = results / "v52l_7b14b_local_model_rag_v53e_1000" / "measured_001"
v52i_summary = list(csv.DictReader((results / "v52i_abgh_same_query_measured_1000_summary.csv").open(newline="", encoding="utf-8")))[0]
v52l_summary = list(csv.DictReader((results / "v52l_7b14b_local_model_rag_v53e_1000_summary.csv").open(newline="", encoding="utf-8")))[0]
v52c_summary = list(csv.DictReader((results / "v52c_7b14b_local_model_rag_evidence_intake_summary.csv").open(newline="", encoding="utf-8")))[0]
v52d_summary = list(csv.DictReader((results / "v52d_30b70b_llm_rag_evidence_intake_summary.csv").open(newline="", encoding="utf-8")))[0]
v52e_summary = list(csv.DictReader((results / "v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv").open(newline="", encoding="utf-8")))[0]

if int(v52l_summary.get("c_v53e_absorb_ready", "0")) != 1:
    raise SystemExit("v52r requires v52l with c_v53e_absorb_ready=1")
if int(v52l_summary.get("same_query_set_as_v52i_abgh", "0")) != 1:
    raise SystemExit("v52r requires v52l bound to the same query set as v52i")

v52p_dir = results / "v52p_30b_open_weight_llm_rag_v53e_1000" / "measured_001"
v52q_dir = results / "v52q_70b_open_weight_llm_rag_v53e_1000" / "measured_001"
v52p_summary = list(csv.DictReader((results / "v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv").open(newline="", encoding="utf-8")))[0]
v52q_summary = list(csv.DictReader((results / "v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv").open(newline="", encoding="utf-8")))[0]
if int(v52p_summary.get("d_v53e_absorb_ready", "0")) != 1:
    raise SystemExit("v52r requires v52p with d_v53e_absorb_ready=1")
if int(v52q_summary.get("e_v53e_absorb_ready", "0")) != 1:
    raise SystemExit("v52r requires v52q with e_v53e_absorb_ready=1")


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


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


for relpath in [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "abgh_system_rows.csv",
    "abgh_answer_rows.csv",
    "abgh_citation_rows.csv",
    "abgh_abstain_rows.csv",
    "abgh_wrong_answer_guard_rows.csv",
    "abgh_resource_rows.csv",
    "routehint_rows.csv",
    "abgh_system_metric_rows.csv",
    "V52I_ABGH_SAME_QUERY_BOUNDARY.md",
    "v52i_abgh_same_query_measured_1000_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v52i_dir / relpath, f"source_v52i/{relpath}")
copy(results / "v52i_abgh_same_query_measured_1000_summary.csv", "source_v52i/v52i_abgh_same_query_measured_1000_summary.csv")

for relpath in [
    "frozen_query_rows.csv",
    "frozen_source_span_rows.csv",
    "source_manifest_rows.csv",
    "model_identity.json",
    "c_answer_rows.csv",
    "c_citation_rows.csv",
    "c_retrieval_rows.csv",
    "c_abstain_rows.csv",
    "c_wrong_answer_guard_rows.csv",
    "c_resource_rows.csv",
    "ollama_generation_transcript_rows.csv",
    "c_system_metric_rows.csv",
    "V52L_7B14B_LOCAL_MODEL_RAG_V53E_BOUNDARY.md",
    "v52l_7b14b_local_model_rag_v53e_1000_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v52l_dir / relpath, f"source_v52l/{relpath}")
copy(results / "v52l_7b14b_local_model_rag_v53e_1000_summary.csv", "source_v52l/v52l_7b14b_local_model_rag_v53e_1000_summary.csv")

for relpath in [
    "frozen_query_rows.csv", "frozen_source_span_rows.csv", "source_manifest_rows.csv", "model_identity.json",
    "d_answer_rows.csv", "d_citation_rows.csv", "d_retrieval_rows.csv", "d_abstain_rows.csv",
    "d_wrong_answer_guard_rows.csv", "d_resource_rows.csv", "ollama_generation_transcript_rows.csv",
    "d_system_metric_rows.csv", "V52P_30B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md",
    "v52p_30b_open_weight_llm_rag_v53e_1000_manifest.json", "sha256_manifest.csv",
]:
    copy(v52p_dir / relpath, f"source_v52p/{relpath}")
copy(results / "v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv", "source_v52p/v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv")
for relpath in [
    "frozen_query_rows.csv", "frozen_source_span_rows.csv", "source_manifest_rows.csv", "model_identity.json",
    "e_answer_rows.csv", "e_citation_rows.csv", "e_retrieval_rows.csv", "e_abstain_rows.csv",
    "e_wrong_answer_guard_rows.csv", "e_resource_rows.csv", "ollama_generation_transcript_rows.csv",
    "e_system_metric_rows.csv", "V52Q_70B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md",
    "v52q_70b_open_weight_llm_rag_v53e_1000_manifest.json", "sha256_manifest.csv",
]:
    copy(v52q_dir / relpath, f"source_v52q/{relpath}")
copy(results / "v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv", "source_v52q/v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv")
copy(results / "v52c_7b14b_local_model_rag_evidence_intake_summary.csv", "source_v52c/v52c_7b14b_local_model_rag_evidence_intake_summary.csv")
copy(results / "v52d_30b70b_llm_rag_evidence_intake_summary.csv", "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv")
copy(results / "v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv", "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv")

metric_rows = read_csv(v52i_dir / "abgh_system_metric_rows.csv")
metric_by_id = {row["system_id"]: row for row in metric_rows}
c_metric = read_csv(v52l_dir / "c_system_metric_rows.csv")[0]
metric_by_id["C"] = c_metric
d_metric = read_csv(v52p_dir / "d_system_metric_rows.csv")[0]
metric_by_id["D"] = d_metric
e_metric = read_csv(v52q_dir / "e_system_metric_rows.csv")[0]
metric_by_id["E"] = e_metric

system_names = {
    "A": "BM25 / lexical",
    "B": "small local RAG",
    "C": "7B-14B local model + RAG",
    "D": "30B open-weight LLM + RAG",
    "E": "70B open-weight LLM + RAG",
    "F": "100B+ API or hosted model + RAG",
    "G": "RouteMemory + RouteHint",
    "H": "RouteMemory + RouteHint + source-verified scorer + domain policy",
}
size_classes = {
    "A": "lexical",
    "B": "small-local-rag",
    "C": "7b-14b",
    "D": "30b",
    "E": "70b",
    "F": "100b-plus",
    "G": "route-memory",
    "H": "route-memory-policy",
}
baseline_rows = []
for system_id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
    measured = system_id in metric_by_id
    optional = system_id == "F"
    blocking_reason = ""
    adapter_status = {
        "C": "measured-local-v52l",
        "D": "measured-local-v52p",
        "E": "measured-local-v52q",
    }.get(system_id, "measured-local-v52i" if measured else "")
    blocking_reason = ""
    if optional:
        adapter_status = "deferred-with-reason"
        blocking_reason = "100b-plus-hosted-api-evidence-missing-or-deferred"
    elif not measured:
        adapter_status = "evidence-directory-missing"
        blocking_reason = f"{size_classes[system_id]}-evidence-directory-missing"
    metrics = metric_by_id.get(system_id, {})
    baseline_rows.append(
        {
            "system_id": system_id,
            "system_name": system_names[system_id],
            "size_class": size_classes[system_id],
            "required_status": "optional-preferred" if optional else "required",
            "adapter_status": adapter_status,
            "measured_baseline_ready": int(measured),
            "query_set_id": "v53e_canary_query_scale_1000_full" if measured else "",
            "source_manifest_bound": int(measured),
            "answer_rows": metrics.get("answer_rows", "0"),
            "citation_rows": metrics.get("citation_rows", "0"),
            "abstain_rows": metrics.get("abstain_rows", "0"),
            "wrong_answer_rows": metrics.get("wrong_answer_rows", "0"),
            "resource_rows": metrics.get("resource_rows", "0"),
            "accuracy": metrics.get("accuracy", ""),
            "citation_accuracy": metrics.get("citation_accuracy", ""),
            "needs_external_model": int(system_id in {"C", "D", "E", "F"}),
            "external_model_used": int(system_id in {"C", "D", "E"} and measured),
            "route_memory_store_used": int(system_id in {"G", "H"} and measured),
            "compact_routehint_used": int(system_id in {"G", "H"} and measured),
            "source_verified_scorer_used": int(system_id == "H" and measured),
            "domain_policy_used": int(system_id == "H" and measured),
            "blocking_reason": blocking_reason,
        }
    )
write_csv(run_dir / "measured_baseline_registry.csv", list(baseline_rows[0].keys()), baseline_rows)

absorb_rows = []
for artifact in [
    ("query_set", "source_v52i/frozen_query_rows.csv", 1000),
    ("source_manifest", "source_v52i/source_manifest_rows.csv", int(v52i_summary["source_manifest_rows"])),
    ("answer_rows_abgh", "source_v52i/abgh_answer_rows.csv", 4000),
    ("citation_rows_abgh", "source_v52i/abgh_citation_rows.csv", 4000),
    ("abstain_rows_abgh", "source_v52i/abgh_abstain_rows.csv", 4000),
    ("wrong_answer_guard_rows_abgh", "source_v52i/abgh_wrong_answer_guard_rows.csv", 4000),
    ("resource_rows_abgh", "source_v52i/abgh_resource_rows.csv", 4000),
    ("routehint_rows", "source_v52i/routehint_rows.csv", 2000),
    ("answer_rows_c", "source_v52l/c_answer_rows.csv", 1000),
    ("citation_rows_c", "source_v52l/c_citation_rows.csv", 1000),
    ("retrieval_rows_c", "source_v52l/c_retrieval_rows.csv", 1000),
    ("abstain_rows_c", "source_v52l/c_abstain_rows.csv", 1000),
    ("wrong_answer_guard_rows_c", "source_v52l/c_wrong_answer_guard_rows.csv", 1000),
    ("resource_rows_c", "source_v52l/c_resource_rows.csv", 1000),
    ("transcript_rows_c", "source_v52l/ollama_generation_transcript_rows.csv", 1000),
    ("answer_rows_d", "source_v52p/d_answer_rows.csv", 1000),
    ("citation_rows_d", "source_v52p/d_citation_rows.csv", 1000),
    ("retrieval_rows_d", "source_v52p/d_retrieval_rows.csv", 1000),
    ("abstain_rows_d", "source_v52p/d_abstain_rows.csv", 1000),
    ("wrong_answer_guard_rows_d", "source_v52p/d_wrong_answer_guard_rows.csv", 1000),
    ("resource_rows_d", "source_v52p/d_resource_rows.csv", 1000),
    ("transcript_rows_d", "source_v52p/ollama_generation_transcript_rows.csv", 1000),
    ("answer_rows_e", "source_v52q/e_answer_rows.csv", 1000),
    ("citation_rows_e", "source_v52q/e_citation_rows.csv", 1000),
    ("retrieval_rows_e", "source_v52q/e_retrieval_rows.csv", 1000),
    ("abstain_rows_e", "source_v52q/e_abstain_rows.csv", 1000),
    ("wrong_answer_guard_rows_e", "source_v52q/e_wrong_answer_guard_rows.csv", 1000),
    ("resource_rows_e", "source_v52q/e_resource_rows.csv", 1000),
    ("transcript_rows_e", "source_v52q/ollama_generation_transcript_rows.csv", 1000),
]:
    artifact_name, relpath, expected_rows = artifact
    absorb_rows.append(
        {
            "artifact": artifact_name,
            "source": relpath,
            "expected_rows": expected_rows,
            "sha256": sha256(run_dir / relpath),
            "status": "absorbed",
        }
    )
write_csv(run_dir / "measured_artifact_absorb_rows.csv", list(absorb_rows[0].keys()), absorb_rows)

summary = {
    "v52r_measured_registry_de_absorb_ready": 1,
    "v52_ready": 0,
    "baseline_system_rows": 8,
    "local_measured_system_rows": 7,
    "local_measured_systems": "A/B/C/D/E/G/H",
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "query_rows": 1000,
    "answer_rows": 7000,
    "citation_rows": 7000,
    "abstain_rows": 7000,
    "wrong_answer_guard_rows": 7000,
    "resource_rows": 7000,
    "retrieval_rows_c": 1000,
    "transcript_rows_c": 1000,
    "routehint_rows": 2000,
    "same_query_set_local_systems": 1,
    "same_source_manifest_local_systems": 1,
    "required_7b14b_baseline_ready": int(v52l_summary.get("c_v53e_absorb_ready", "0")),
    "c_strict_exact_label_accuracy": v52l_summary.get("accuracy", "0.000000"),
    "d_strict_exact_label_accuracy": v52p_summary.get("accuracy", "0.000000"),
    "e_strict_exact_label_accuracy": v52q_summary.get("accuracy", "0.000000"),
    "v52_absorb_ready": int(v52d_summary.get("v52_absorb_ready", "0")),
    "required_30b_baseline_ready": int(v52p_summary.get("d_v53e_absorb_ready", "0")),
    "required_70b_baseline_ready": int(v52q_summary.get("e_v53e_absorb_ready", "0")),
    "optional_100b_plus_baseline_status": v52e_summary.get("optional_100b_plus_baseline_status", "deferred-with-reason"),
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v52r-measured-registry-de-absorb", "pass", "A/B/C/D/E/G/H measured rows are absorbed into the v52 measured registry"),
    ("same-query-source-local-systems", "pass", "A/B/C/D/E/G/H share v53e query IDs and source manifest"),
    ("local-answer-citation-resource-rows", "pass", "A/B/C/D/E/G/H have answer/citation/abstain/guard/resource rows"),
    ("routehint-policy-local-rows", "pass", "G/H RouteHint rows and H scorer/policy flags are present"),
    ("7b14b-local-model-rag-real-row", "pass", "C v52l measured packet is absorbed over the shared v53e 1000-row set"),
    ("30b-llm-rag-real-row", "pass", "D v52p measured packet is absorbed over the shared v53e 1000-row set"),
    ("70b-llm-rag-real-row", "pass", "E v52q measured packet is absorbed over the shared v53e 1000-row set"),
    ("100b-plus-llm-rag-real-row", "blocked", "F optional evidence is missing or deferred"),
    ("v52-de-absorb-ready", "pass", "D and E v53e measured packets are absorbed into the v52 measured registry"),
    ("v52-full-baseline-war", "blocked", "full v52 still requires optional F handling and release-scale evidence"),
    ("real-release-package", "blocked", "v52r measured registry is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md").write_text(
    "# v52r Measured Registry D/E Absorb Boundary\n\n"
    "This absorbs the v52i A/B/G/H local measured packet plus the v52l C/D/E measured packets into a v52 measured registry. "
    "It is not the completed 30B/70B/100B+ baseline war and does not claim C quality from strict exact-label accuracy.\n\n"
    "- local_measured_systems=A/B/C/D/E/G/H\n"
    "- query_rows=1000\n"
    "- answer_rows=7000\n"
    "- citation_rows=7000\n"
    "- abstain_rows=7000\n"
    "- wrong_answer_guard_rows=7000\n"
    "- resource_rows=7000\n"
    "- retrieval_rows_c=1000\n"
    "- transcript_rows_c=1000\n"
    "- routehint_rows=2000\n"
    f"- c_strict_exact_label_accuracy={v52l_summary.get('accuracy', '0.000000')}\n"
    f"- d_strict_exact_label_accuracy={v52p_summary.get('accuracy', '0.000000')}\n"
    f"- e_strict_exact_label_accuracy={v52q_summary.get('accuracy', '0.000000')}\n\n"
    "Still blocked:\n\n"
    "- optional F 100B+ hosted/API evidence or final deferral\n\n"
    "Do not publish 30B-150B comparison wins or LLM performance claims from this local measured registry.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52r-measured-registry-de-absorb",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52r_measured_registry_de_absorb_ready": 1,
    "local_measured_systems": ["A", "B", "C", "D", "E", "G", "H"],
    "query_set_id": "v53e_canary_query_scale_1000_full",
    "answer_rows": 7000,
    "citation_rows": 7000,
    "resource_rows": 7000,
    "c_strict_exact_label_accuracy": v52l_summary.get("accuracy", "0.000000"),
    "d_strict_exact_label_accuracy": v52p_summary.get("accuracy", "0.000000"),
    "e_strict_exact_label_accuracy": v52q_summary.get("accuracy", "0.000000"),
    "v52_absorb_ready": int(v52d_summary.get("v52_absorb_ready", "0")),
    "v52_ready": 0,
    "required_30b_baseline_ready": 1,
    "required_70b_baseline_ready": 1,
    "v52_absorb_ready": 1,
    "source_v52i_summary_sha256": sha256(results / "v52i_abgh_same_query_measured_1000_summary.csv"),
    "source_v52l_summary_sha256": sha256(results / "v52l_7b14b_local_model_rag_v53e_1000_summary.csv"),
    "source_v52p_summary_sha256": sha256(results / "v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv"),
    "source_v52q_summary_sha256": sha256(results / "v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv"),
}
(run_dir / "v52r_measured_registry_de_absorb_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "measured_baseline_registry.csv",
    "measured_artifact_absorb_rows.csv",
    "V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md",
    "v52r_measured_registry_de_absorb_manifest.json",
    "source_v52i/v52i_abgh_same_query_measured_1000_summary.csv",
    "source_v52i/frozen_query_rows.csv",
    "source_v52i/frozen_source_span_rows.csv",
    "source_v52i/source_manifest_rows.csv",
    "source_v52i/abgh_system_rows.csv",
    "source_v52i/abgh_answer_rows.csv",
    "source_v52i/abgh_citation_rows.csv",
    "source_v52i/abgh_abstain_rows.csv",
    "source_v52i/abgh_wrong_answer_guard_rows.csv",
    "source_v52i/abgh_resource_rows.csv",
    "source_v52i/routehint_rows.csv",
    "source_v52i/abgh_system_metric_rows.csv",
    "source_v52i/V52I_ABGH_SAME_QUERY_BOUNDARY.md",
    "source_v52i/v52i_abgh_same_query_measured_1000_manifest.json",
    "source_v52i/sha256_manifest.csv",
    "source_v52l/v52l_7b14b_local_model_rag_v53e_1000_summary.csv",
    "source_v52l/frozen_query_rows.csv",
    "source_v52l/frozen_source_span_rows.csv",
    "source_v52l/source_manifest_rows.csv",
    "source_v52l/model_identity.json",
    "source_v52l/c_answer_rows.csv",
    "source_v52l/c_citation_rows.csv",
    "source_v52l/c_retrieval_rows.csv",
    "source_v52l/c_abstain_rows.csv",
    "source_v52l/c_wrong_answer_guard_rows.csv",
    "source_v52l/c_resource_rows.csv",
    "source_v52l/ollama_generation_transcript_rows.csv",
    "source_v52l/c_system_metric_rows.csv",
    "source_v52l/V52L_7B14B_LOCAL_MODEL_RAG_V53E_BOUNDARY.md",
    "source_v52l/v52l_7b14b_local_model_rag_v53e_1000_manifest.json",
    "source_v52l/sha256_manifest.csv",
    "source_v52p/v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv",
    "source_v52p/d_answer_rows.csv",
    "source_v52p/d_citation_rows.csv",
    "source_v52p/d_resource_rows.csv",
    "source_v52p/ollama_generation_transcript_rows.csv",
    "source_v52p/d_system_metric_rows.csv",
    "source_v52q/v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv",
    "source_v52q/e_answer_rows.csv",
    "source_v52q/e_citation_rows.csv",
    "source_v52q/e_resource_rows.csv",
    "source_v52q/ollama_generation_transcript_rows.csv",
    "source_v52q/e_system_metric_rows.csv",
    "source_v52c/v52c_7b14b_local_model_rag_evidence_intake_summary.csv",
    "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv",
    "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv",
]
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v52r_measured_registry_de_absorb_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
