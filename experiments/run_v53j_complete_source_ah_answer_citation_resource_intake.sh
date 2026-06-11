#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53j_complete_source_ah_answer_citation_resource_intake"
RUN_ID="${V53J_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V53J_SUPPLIED_EVIDENCE_DIR:-}"

if [[ "${V53J_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53j_complete_source_ah_answer_citation_resource_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53I_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53i_complete_source_query_instantiation.sh" >/dev/null
V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
supplied_dir_arg = sys.argv[5]
supplied_dir = Path(supplied_dir_arg) if supplied_dir_arg else None
results = root / "results"
v53i_dir = results / "v53i_complete_source_query_instantiation" / "instantiate_001"
v52y_dir = results / "v52y_f_optional_final_policy" / "policy_001"

SYSTEMS = [
    ("A", "BM25 / lexical", "required-core", "lexical local retrieval baseline"),
    ("B", "small local RAG", "required-core", "small local RAG baseline"),
    ("C", "7B-14B local model + RAG", "required-core", "local open model plus RAG"),
    ("D", "30B open-weight LLM + RAG", "required-core", "required 30B-class open-weight LLM baseline"),
    ("E", "70B open-weight LLM + RAG", "required-core", "required 70B-class open-weight LLM baseline"),
    ("F", "100B+ hosted/API LLM + RAG", "optional-final-policy", "optional hosted/API frontier-scale row"),
    ("G", "RouteMemory + RouteHint", "required-core", "architecture candidate without scorer/policy"),
    ("H", "RouteMemory + RouteHint + source-verified scorer + domain policy", "required-core", "architecture candidate with scorer/policy"),
]
CORE_SYSTEMS = {system_id for system_id, _, requirement, _ in SYSTEMS if requirement == "required-core"}
ALL_SYSTEMS = {system_id for system_id, _, _, _ in SYSTEMS}


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


def safe_int(value, default=0):
    try:
        return int(str(value).strip())
    except Exception:
        return default


v53i_summary = read_csv(results / "v53i_complete_source_query_instantiation_summary.csv")[0]
v52y_summary = read_csv(results / "v52y_f_optional_final_policy_summary.csv")[0]
if v53i_summary.get("v53i_complete_source_query_instantiation_ready") != "1":
    raise SystemExit("v53j requires v53i_complete_source_query_instantiation_ready=1")
if v52y_summary.get("f_optional_final_disposition_ready") != "1":
    raise SystemExit("v53j requires v52y F optional final disposition")

for rel in [
    "complete_source_query_rows.csv",
    "complete_source_span_rows.csv",
    "complete_source_query_family_rows.csv",
    "complete_source_query_repo_rows.csv",
    "complete_source_query_gap_rows.csv",
    "V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md",
    "v53i_complete_source_query_instantiation_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53i_dir / rel, f"source_v53i/{rel}")
copy(results / "v53i_complete_source_query_instantiation_summary.csv", "source_v53i/v53i_complete_source_query_instantiation_summary.csv")
copy(results / "v53i_complete_source_query_instantiation_decision.csv", "source_v53i/v53i_complete_source_query_instantiation_decision.csv")

for rel in [
    "f_optional_final_rows.csv",
    "v52_ready_condition_rows.csv",
    "comparison_wording_rows.csv",
    "V52Y_F_OPTIONAL_FINAL_POLICY_BOUNDARY.md",
    "v52y_f_optional_final_policy_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v52y_dir / rel, f"source_v52y/{rel}")
copy(results / "v52y_f_optional_final_policy_summary.csv", "source_v52y/v52y_f_optional_final_policy_summary.csv")
copy(results / "v52y_f_optional_final_policy_decision.csv", "source_v52y/v52y_f_optional_final_policy_decision.csv")

queries = read_csv(v53i_dir / "complete_source_query_rows.csv")
spans = {row["source_span_id"]: row for row in read_csv(v53i_dir / "complete_source_span_rows.csv")}
query_by_id = {row["query_id"]: row for row in queries}
valid_query_ids = set(query_by_id)
valid_span_ids = set(spans)
f_final_rows = read_csv(v52y_dir / "f_optional_final_rows.csv")
f_final = f_final_rows[0]
f_final_disposition = v52y_summary["f_optional_final_disposition"]
f_supplied_ready = v52y_summary.get("optional_100b_plus_baseline_ready") == "1"

system_rows = []
for system_id, name, requirement, description in SYSTEMS:
    is_core = system_id in CORE_SYSTEMS
    target_answer_rows = len(queries) if is_core else (len(queries) if f_supplied_ready else 0)
    target_status = "awaiting-supplied-evidence" if is_core else f_final_disposition
    system_rows.append(
        {
            "system_id": system_id,
            "system_name": name,
            "requirement": requirement,
            "target_query_rows": str(len(queries)),
            "target_answer_rows": str(target_answer_rows),
            "target_resource_rows": str(target_answer_rows),
            "minimum_citation_rows": str(target_answer_rows),
            "required_for_core_close": str(int(is_core)),
            "description": description,
            "status": target_status,
        }
    )
write_csv(run_dir / "complete_source_ah_system_target_rows.csv", list(system_rows[0].keys()), system_rows)

answer_schema_rows = [
    ("answer_id", 1, "stable unique answer id, recommended format v53j_<system>_<query_id>"),
    ("system_id", 1, "one of A/B/C/D/E/F/G/H"),
    ("query_id", 1, "query id from v53i complete_source_query_rows.csv"),
    ("run_id", 1, "system run id for provenance"),
    ("model_identity_id", 1, "model or architecture identity row id"),
    ("answer_text", 1, "verbatim system answer"),
    ("answer_text_sha256", 1, "sha256: hash of answer_text"),
    ("expected_behavior", 1, "copied from frozen complete-source query row"),
    ("predicted_behavior", 1, "answer-with-citation or abstain"),
    ("abstained", 1, "1 when the system refuses/abstains"),
    ("resource_row_id", 1, "matching resource row id"),
    ("output_provenance_sha256", 1, "hash over raw output/provenance packet"),
]
citation_schema_rows = [
    ("citation_id", 1, "stable unique citation id"),
    ("answer_id", 1, "answer row id"),
    ("system_id", 1, "one of A/B/C/D/E/F/G/H"),
    ("query_id", 1, "query id from v53i"),
    ("source_span_id", 1, "source span id from v53i complete_source_span_rows.csv"),
    ("source_file_sha256", 1, "sha256 from the cited source span"),
    ("citation_text", 1, "short cited text or excerpt"),
    ("citation_text_sha256", 1, "sha256: hash of citation_text"),
]
resource_schema_rows = [
    ("resource_row_id", 1, "stable unique resource row id"),
    ("system_id", 1, "one of A/B/C/D/E/F/G/H"),
    ("query_id", 1, "query id from v53i"),
    ("run_id", 1, "system run id for provenance"),
    ("latency_ms", 1, "wall-clock latency in milliseconds"),
    ("input_tokens_or_bytes", 1, "input token count or byte count"),
    ("output_tokens_or_bytes", 1, "output token count or byte count"),
    ("external_model_used", 1, "1 for LLM/API/model systems, 0 for local lexical-only runs"),
    ("model_name", 1, "model or architecture name"),
    ("hardware_or_endpoint", 1, "local hardware descriptor or redacted hosted endpoint class"),
    ("run_started_at_utc", 1, "ISO-8601 UTC timestamp"),
]
write_csv(run_dir / "complete_source_answer_row_required_schema.csv", ["field", "required", "description"], [dict(zip(["field", "required", "description"], row)) for row in answer_schema_rows])
write_csv(run_dir / "complete_source_citation_row_required_schema.csv", ["field", "required", "description"], [dict(zip(["field", "required", "description"], row)) for row in citation_schema_rows])
write_csv(run_dir / "complete_source_resource_row_required_schema.csv", ["field", "required", "description"], [dict(zip(["field", "required", "description"], row)) for row in resource_schema_rows])

answer_template_rows = []
resource_template_rows = []
for system_id in sorted(CORE_SYSTEMS):
    for query in queries:
        answer_id = f"v53j_{system_id}_{query['query_id']}"
        resource_row_id = f"{answer_id}_resource"
        answer_template_rows.append(
            {
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "owner_repo": query["owner_repo"],
                "audit_type": query["audit_type"],
                "expected_behavior": query["expected_behavior"],
                "required_for_core_close": "1",
                "answer_text": "",
                "answer_text_sha256": "",
                "predicted_behavior": "",
                "abstained": "",
                "resource_row_id": resource_row_id,
                "status": "missing-supplied-output",
            }
        )
        resource_template_rows.append(
            {
                "resource_row_id": resource_row_id,
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "latency_ms": "",
                "input_tokens_or_bytes": "",
                "output_tokens_or_bytes": "",
                "external_model_used": "",
                "model_name": "",
                "hardware_or_endpoint": "",
                "status": "missing-supplied-resource",
            }
        )
write_csv(run_dir / "complete_source_core_answer_row_template.csv", list(answer_template_rows[0].keys()), answer_template_rows)
write_csv(run_dir / "complete_source_core_resource_row_template.csv", list(resource_template_rows[0].keys()), resource_template_rows)

f_policy_rows = [
    {
        "system_id": "F",
        "source_policy_layer": "v52y",
        "f_optional_final_disposition": f_final_disposition,
        "optional_100b_plus_baseline_ready": v52y_summary["optional_100b_plus_baseline_ready"],
        "required_for_core_close": "0",
        "target_answer_rows_required_for_v53j": "0" if not f_supplied_ready else str(len(queries)),
        "counts_as_measured_100b_plus_result": f_final["counts_as_measured_100b_plus_result"],
        "final_reason": f_final["final_reason"],
        "status": "final-deferred-not-required" if not f_supplied_ready else "optional-supplied-ready",
    }
]
write_csv(run_dir / "complete_source_optional_f_final_rows.csv", list(f_policy_rows[0].keys()), f_policy_rows)

supplied_answer_rows = []
supplied_citation_rows = []
supplied_resource_rows = []
validation_errors = []

if supplied_dir:
    answer_path = supplied_dir / "answer_rows.csv"
    citation_path = supplied_dir / "citation_rows.csv"
    resource_path = supplied_dir / "resource_rows.csv"
    if answer_path.is_file():
        supplied_answer_rows = read_csv(answer_path)
        copy(answer_path, "supplied/answer_rows.csv")
    else:
        validation_errors.append("missing supplied answer_rows.csv")
    if citation_path.is_file():
        supplied_citation_rows = read_csv(citation_path)
        copy(citation_path, "supplied/citation_rows.csv")
    else:
        validation_errors.append("missing supplied citation_rows.csv")
    if resource_path.is_file():
        supplied_resource_rows = read_csv(resource_path)
        copy(resource_path, "supplied/resource_rows.csv")
    else:
        validation_errors.append("missing supplied resource_rows.csv")

resource_by_id = {row.get("resource_row_id", ""): row for row in supplied_resource_rows}
citations_by_answer = Counter(row.get("answer_id", "") for row in supplied_citation_rows)
valid_answer_rows = 0
valid_resource_rows = 0
valid_citation_rows = 0
valid_answer_by_system = Counter()
valid_resource_by_system = Counter()
valid_citation_by_system = Counter()

for row in supplied_resource_rows:
    system_id = row.get("system_id", "")
    query_id = row.get("query_id", "")
    if system_id not in ALL_SYSTEMS:
        validation_errors.append(f"invalid resource system_id: {system_id}")
        continue
    if query_id not in valid_query_ids:
        validation_errors.append(f"invalid resource query_id: {query_id}")
        continue
    if safe_int(row.get("latency_ms", "0")) < 0:
        validation_errors.append(f"negative latency_ms: {row.get('resource_row_id', '')}")
        continue
    valid_resource_rows += 1
    valid_resource_by_system[system_id] += 1

for row in supplied_citation_rows:
    system_id = row.get("system_id", "")
    query_id = row.get("query_id", "")
    span_id = row.get("source_span_id", "")
    citation_text = row.get("citation_text", "")
    if system_id not in ALL_SYSTEMS:
        validation_errors.append(f"invalid citation system_id: {system_id}")
        continue
    if query_id not in valid_query_ids or span_id not in valid_span_ids:
        validation_errors.append(f"invalid citation binding: {row.get('citation_id', '')}")
        continue
    if row.get("source_file_sha256", "") != spans[span_id]["source_file_sha256"]:
        validation_errors.append(f"citation source hash mismatch: {row.get('citation_id', '')}")
        continue
    if citation_text and row.get("citation_text_sha256", "") != sha256_text(citation_text):
        validation_errors.append(f"citation text hash mismatch: {row.get('citation_id', '')}")
        continue
    valid_citation_rows += 1
    valid_citation_by_system[system_id] += 1

for row in supplied_answer_rows:
    system_id = row.get("system_id", "")
    query_id = row.get("query_id", "")
    answer_id = row.get("answer_id", "")
    answer_text = row.get("answer_text", "")
    resource_row_id = row.get("resource_row_id", "")
    if system_id not in ALL_SYSTEMS:
        validation_errors.append(f"invalid answer system_id: {system_id}")
        continue
    if query_id not in valid_query_ids:
        validation_errors.append(f"invalid answer query_id: {query_id}")
        continue
    if row.get("answer_text_sha256", "") != sha256_text(answer_text):
        validation_errors.append(f"answer hash mismatch: {answer_id}")
        continue
    if row.get("expected_behavior", "") != query_by_id[query_id]["expected_behavior"]:
        validation_errors.append(f"expected behavior mismatch: {answer_id}")
        continue
    if resource_row_id not in resource_by_id:
        validation_errors.append(f"missing matching resource row: {answer_id}")
        continue
    if citations_by_answer[answer_id] < 1:
        validation_errors.append(f"missing citation row: {answer_id}")
        continue
    valid_answer_rows += 1
    valid_answer_by_system[system_id] += 1

validation_rows = []
for system_id, name, requirement, _ in SYSTEMS:
    target = len(queries) if system_id in CORE_SYSTEMS else (len(queries) if f_supplied_ready else 0)
    valid = valid_answer_by_system.get(system_id, 0)
    supplied = sum(1 for row in supplied_answer_rows if row.get("system_id") == system_id)
    if system_id == "F" and not f_supplied_ready and target == 0:
        status = "final-deferred-not-required"
    else:
        status = "valid" if valid >= target and target > 0 else "missing-or-invalid"
    validation_rows.append(
        {
            "system_id": system_id,
            "system_name": name,
            "requirement": requirement,
            "target_answer_rows": str(target),
            "supplied_answer_rows": str(supplied),
            "valid_answer_rows": str(valid),
            "valid_citation_rows": str(valid_citation_by_system.get(system_id, 0)),
            "valid_resource_rows": str(valid_resource_by_system.get(system_id, 0)),
            "missing_valid_answer_rows": str(max(0, target - valid)),
            "status": status,
        }
    )
write_csv(run_dir / "complete_source_ah_supplied_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

validation_error_rows = [{"error_id": f"v53j_error_{idx:04d}", "message": message} for idx, message in enumerate(validation_errors, start=1)]
if not validation_error_rows:
    validation_error_rows = [{"error_id": "none", "message": "no supplied evidence errors recorded"}]
write_csv(run_dir / "complete_source_ah_validation_error_rows.csv", list(validation_error_rows[0].keys()), validation_error_rows)

required_core_systems_ready = int(all(valid_answer_by_system.get(system_id, 0) >= len(queries) for system_id in CORE_SYSTEMS))
required_core_citations_ready = int(all(valid_citation_by_system.get(system_id, 0) >= len(queries) for system_id in CORE_SYSTEMS))
required_core_resources_ready = int(all(valid_resource_by_system.get(system_id, 0) >= len(queries) for system_id in CORE_SYSTEMS))
answer_citation_resource_rows_ready = int(required_core_systems_ready and required_core_citations_ready and required_core_resources_ready)
core_target_answer_rows = len(queries) * len(CORE_SYSTEMS)
optional_f_target_answer_rows = len(queries) if f_supplied_ready else 0
valid_core_answer_rows = sum(valid_answer_by_system.get(system_id, 0) for system_id in CORE_SYSTEMS)
valid_core_citation_rows = sum(valid_citation_by_system.get(system_id, 0) for system_id in CORE_SYSTEMS)
valid_core_resource_rows = sum(valid_resource_by_system.get(system_id, 0) for system_id in CORE_SYSTEMS)

summary = {
    "v53j_complete_source_ah_intake_ready": "1",
    "v53_ready": "0",
    "v53i_complete_source_query_instantiation_ready": v53i_summary["v53i_complete_source_query_instantiation_ready"],
    "complete_source_query_rows_ready": v53i_summary["complete_source_query_rows_ready"],
    "complete_source_query_rows": str(len(queries)),
    "complete_source_span_rows": str(len(spans)),
    "target_system_count": str(len(SYSTEMS)),
    "required_core_system_count": str(len(CORE_SYSTEMS)),
    "optional_system_count": str(len(SYSTEMS) - len(CORE_SYSTEMS)),
    "core_target_answer_rows": str(core_target_answer_rows),
    "core_target_resource_rows": str(core_target_answer_rows),
    "core_minimum_target_citation_rows": str(core_target_answer_rows),
    "optional_f_target_answer_rows": str(optional_f_target_answer_rows),
    "f_optional_final_disposition": f_final_disposition,
    "f_required_for_core_close": "0",
    "supplied_evidence_dir_present": str(int(supplied_dir is not None)),
    "supplied_answer_rows": str(len(supplied_answer_rows)),
    "supplied_citation_rows": str(len(supplied_citation_rows)),
    "supplied_resource_rows": str(len(supplied_resource_rows)),
    "valid_answer_rows": str(valid_answer_rows),
    "valid_citation_rows": str(valid_citation_rows),
    "valid_resource_rows": str(valid_resource_rows),
    "valid_core_answer_rows": str(valid_core_answer_rows),
    "valid_core_citation_rows": str(valid_core_citation_rows),
    "valid_core_resource_rows": str(valid_core_resource_rows),
    "required_core_systems_ready": str(required_core_systems_ready),
    "required_core_citations_ready": str(required_core_citations_ready),
    "required_core_resources_ready": str(required_core_resources_ready),
    "answer_citation_resource_rows_ready": str(answer_citation_resource_rows_ready),
    "symmetric_scorer_policy_rows_ready": "0",
    "review_artifacts_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("complete-source-v53i-query-input", "pass", f"complete_source_query_rows={len(queries)}"),
    ("answer-citation-resource-intake-schema", "pass", "complete-source answer/citation/resource schemas and core templates are emitted"),
    ("a-b-c-d-e-g-h-system-target-matrix", "pass", f"core_target_answer_rows={core_target_answer_rows}"),
    ("f-optional-final-disposition", "pass", f_final_disposition),
    ("supplied-core-answer-rows", "pass" if required_core_systems_ready else "blocked", f"valid_core_answer_rows={valid_core_answer_rows}"),
    ("source-citation-coverage", "pass" if required_core_citations_ready else "blocked", f"valid_core_citation_rows={valid_core_citation_rows}"),
    ("resource-measurement-coverage", "pass" if required_core_resources_ready else "blocked", f"valid_core_resource_rows={valid_core_resource_rows}"),
    ("symmetric-scorer-policy-rows", "blocked", "symmetric scorer/policy rows over v53j are still absent"),
    ("human-review-artifacts", "blocked", "human/release review artifacts are not supplied"),
    ("v53-full-public-repo-audit", "blocked", "complete-source queries exist, but core A/B/C/D/E/G/H supplied rows and review evidence are still required"),
    ("real-release-package", "blocked", "v53j intake is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V53J_COMPLETE_SOURCE_AH_INTAKE_BOUNDARY.md").write_text(
    "# v53j Complete Source A-H Answer/Citation/Resource Intake Boundary\n\n"
    "This layer promotes v53f-style answer, citation, and resource intake onto the v53i complete-source 1000-query set. "
    "A/B/C/D/E/G/H are required core systems for v53 close. F is bound to the v52y optional final policy and is not required for core close in the default deferred-with-reason path.\n\n"
    f"- complete_source_query_rows={len(queries)}\n"
    f"- complete_source_span_rows={len(spans)}\n"
    f"- required_core_systems=A/B/C/D/E/G/H\n"
    f"- core_target_answer_rows={core_target_answer_rows}\n"
    f"- optional_f_target_answer_rows={optional_f_target_answer_rows}\n"
    f"- f_optional_final_disposition={f_final_disposition}\n"
    f"- valid_core_answer_rows={valid_core_answer_rows}\n"
    f"- answer_citation_resource_rows_ready={answer_citation_resource_rows_ready}\n"
    "- v53_ready=0\n\n"
    "Still blocked:\n\n"
    "- supplied A/B/C/D/E/G/H answer rows over the v53i complete-source query set\n"
    "- source citation coverage for every required answer\n"
    "- resource/latency/model identity measurements for every required answer\n"
    "- symmetric scorer/policy rows over the same query IDs\n"
    "- human/source review artifacts and release evidence\n\n"
    "Do not publish v53 completion, v1.0 comparison, superiority, or release claims from an intake template alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53j-complete-source-ah-answer-citation-resource-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53j_complete_source_ah_intake_ready": 1,
    "v53_ready": 0,
    "complete_source_query_rows": len(queries),
    "complete_source_span_rows": len(spans),
    "required_core_systems": sorted(CORE_SYSTEMS),
    "core_target_answer_rows": core_target_answer_rows,
    "optional_f_target_answer_rows": optional_f_target_answer_rows,
    "f_optional_final_disposition": f_final_disposition,
    "valid_core_answer_rows": valid_core_answer_rows,
    "answer_citation_resource_rows_ready": answer_citation_resource_rows_ready,
    "v53i_summary_sha256": sha256(results / "v53i_complete_source_query_instantiation_summary.csv"),
    "v52y_summary_sha256": sha256(results / "v52y_f_optional_final_policy_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53j_complete_source_ah_answer_citation_resource_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "complete_source_ah_system_target_rows.csv",
    "complete_source_answer_row_required_schema.csv",
    "complete_source_citation_row_required_schema.csv",
    "complete_source_resource_row_required_schema.csv",
    "complete_source_core_answer_row_template.csv",
    "complete_source_core_resource_row_template.csv",
    "complete_source_optional_f_final_rows.csv",
    "complete_source_ah_supplied_validation_rows.csv",
    "complete_source_ah_validation_error_rows.csv",
    "V53J_COMPLETE_SOURCE_AH_INTAKE_BOUNDARY.md",
    "v53j_complete_source_ah_answer_citation_resource_intake_manifest.json",
    "source_v53i/complete_source_query_rows.csv",
    "source_v53i/complete_source_span_rows.csv",
    "source_v53i/complete_source_query_family_rows.csv",
    "source_v53i/complete_source_query_repo_rows.csv",
    "source_v53i/complete_source_query_gap_rows.csv",
    "source_v53i/V53I_COMPLETE_SOURCE_QUERY_INSTANTIATION_BOUNDARY.md",
    "source_v53i/v53i_complete_source_query_instantiation_manifest.json",
    "source_v53i/sha256_manifest.csv",
    "source_v53i/v53i_complete_source_query_instantiation_summary.csv",
    "source_v53i/v53i_complete_source_query_instantiation_decision.csv",
    "source_v52y/f_optional_final_rows.csv",
    "source_v52y/v52_ready_condition_rows.csv",
    "source_v52y/comparison_wording_rows.csv",
    "source_v52y/V52Y_F_OPTIONAL_FINAL_POLICY_BOUNDARY.md",
    "source_v52y/v52y_f_optional_final_policy_manifest.json",
    "source_v52y/sha256_manifest.csv",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
    "source_v52y/v52y_f_optional_final_policy_decision.csv",
]
if supplied_answer_rows:
    artifact_rels.append("supplied/answer_rows.csv")
if supplied_citation_rows:
    artifact_rels.append("supplied/citation_rows.csv")
if supplied_resource_rows:
    artifact_rels.append("supplied/resource_rows.csv")

artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v53j_complete_source_ah_answer_citation_resource_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_CSV if False else decision_csv}")
PY
