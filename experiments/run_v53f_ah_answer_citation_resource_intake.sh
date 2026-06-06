#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53f_ah_answer_citation_resource_intake"
RUN_ID="${V53F_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V53F_SUPPLIED_EVIDENCE_DIR:-}"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh" >/dev/null

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
v53e_dir = results / "v53e_canary_query_scale_1000" / "scale_001"
v53e_summary = list(csv.DictReader((results / "v53e_canary_query_scale_1000_summary.csv").open(newline="", encoding="utf-8")))[0]

SYSTEMS = [
    ("A", "BM25 / lexical", "required-core", "lexical local retrieval baseline"),
    ("B", "small local RAG", "required-core", "small local RAG baseline"),
    ("C", "7B-14B local model + RAG", "required-core", "local open model plus RAG"),
    ("D", "30B open-weight LLM + RAG", "required-core", "required 30B-class open-weight LLM baseline"),
    ("E", "70B open-weight LLM + RAG", "required-core", "required 70B-class open-weight LLM baseline"),
    ("F", "100B+ hosted/API LLM + RAG", "optional-if-policy-allows", "optional hosted/API frontier-scale row"),
    ("G", "RouteMemory + RouteHint", "required-core", "architecture candidate without scorer/policy"),
    ("H", "RouteMemory + RouteHint + source-verified scorer + domain policy", "required-core", "architecture candidate with scorer/policy"),
]
CORE_SYSTEMS = {system_id for system_id, _, requirement, _ in SYSTEMS if requirement == "required-core"}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def write_csv(path, fieldnames, rows):
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


def safe_int(value, default=0):
    try:
        return int(str(value).strip())
    except Exception:
        return default


for rel in [
    "scaled_canary_query_rows.csv",
    "scaled_canary_source_span_rows.csv",
    "scaled_canary_query_family_rows.csv",
    "scaled_canary_query_repo_rows.csv",
    "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "v53e_canary_query_scale_1000_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53e_dir / rel, f"source_v53e/{rel}")
copy(results / "v53e_canary_query_scale_1000_summary.csv", "source_v53e/v53e_canary_query_scale_1000_summary.csv")

queries = read_csv(v53e_dir / "scaled_canary_query_rows.csv")
spans = {row["source_span_id"]: row for row in read_csv(v53e_dir / "scaled_canary_source_span_rows.csv")}
query_by_id = {row["query_id"]: row for row in queries}
valid_query_ids = set(query_by_id)
valid_span_ids = set(spans)

system_rows = []
for system_id, name, requirement, description in SYSTEMS:
    system_rows.append(
        {
            "system_id": system_id,
            "system_name": name,
            "requirement": requirement,
            "target_query_rows": len(queries),
            "target_answer_rows": len(queries),
            "target_resource_rows": len(queries),
            "minimum_citation_rows": len(queries),
            "description": description,
            "status": "awaiting-supplied-evidence",
        }
    )
write_csv(run_dir / "ah_system_target_rows.csv", list(system_rows[0].keys()), system_rows)

answer_schema_rows = [
    ("answer_id", 1, "stable unique answer id, recommended format v53f_<system>_<query_id>"),
    ("system_id", 1, "one of A/B/C/D/E/F/G/H"),
    ("query_id", 1, "query id from v53e scaled_canary_query_rows.csv"),
    ("run_id", 1, "system run id for provenance"),
    ("model_identity_id", 1, "model or architecture identity row id"),
    ("answer_text", 1, "verbatim system answer"),
    ("answer_text_sha256", 1, "sha256: hash of answer_text"),
    ("expected_behavior", 1, "copied from frozen query row"),
    ("predicted_behavior", 1, "answer-with-citation or abstain"),
    ("abstained", 1, "1 when the system refuses/abstains"),
    ("resource_row_id", 1, "matching resource row id"),
    ("output_provenance_sha256", 1, "hash over raw output/provenance packet"),
]
citation_schema_rows = [
    ("citation_id", 1, "stable unique citation id"),
    ("answer_id", 1, "answer row id"),
    ("system_id", 1, "one of A/B/C/D/E/F/G/H"),
    ("query_id", 1, "query id from v53e"),
    ("source_span_id", 1, "source span id from v53e scaled_canary_source_span_rows.csv"),
    ("source_file_sha256", 1, "sha256 from the cited source span"),
    ("citation_text", 1, "short cited text or excerpt"),
    ("citation_text_sha256", 1, "sha256: hash of citation_text"),
]
resource_schema_rows = [
    ("resource_row_id", 1, "stable unique resource row id"),
    ("system_id", 1, "one of A/B/C/D/E/F/G/H"),
    ("query_id", 1, "query id from v53e"),
    ("run_id", 1, "system run id for provenance"),
    ("latency_ms", 1, "wall-clock latency in milliseconds"),
    ("input_tokens_or_bytes", 1, "input token count or byte count"),
    ("output_tokens_or_bytes", 1, "output token count or byte count"),
    ("external_model_used", 1, "1 for LLM/API/model systems, 0 for local lexical-only runs"),
    ("model_name", 1, "model or architecture name"),
    ("hardware_or_endpoint", 1, "local hardware descriptor or redacted hosted endpoint class"),
    ("run_started_at_utc", 1, "ISO-8601 UTC timestamp"),
]
write_csv(run_dir / "answer_row_required_schema.csv", ["field", "required", "description"], [dict(zip(["field", "required", "description"], row)) for row in answer_schema_rows])
write_csv(run_dir / "citation_row_required_schema.csv", ["field", "required", "description"], [dict(zip(["field", "required", "description"], row)) for row in citation_schema_rows])
write_csv(run_dir / "resource_row_required_schema.csv", ["field", "required", "description"], [dict(zip(["field", "required", "description"], row)) for row in resource_schema_rows])

answer_template_rows = []
resource_template_rows = []
for system_id, _, requirement, _ in SYSTEMS:
    for query in queries:
        answer_id = f"v53f_{system_id}_{query['query_id']}"
        resource_row_id = f"{answer_id}_resource"
        answer_template_rows.append(
            {
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "owner_repo": query["owner_repo"],
                "audit_type": query["audit_type"],
                "expected_behavior": query["expected_behavior"],
                "required_for_core_close": int(requirement == "required-core"),
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
write_csv(run_dir / "ah_answer_row_template.csv", list(answer_template_rows[0].keys()), answer_template_rows)
write_csv(run_dir / "ah_resource_row_template.csv", list(resource_template_rows[0].keys()), resource_template_rows)

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

for row in supplied_resource_rows:
    system_id = row.get("system_id", "")
    query_id = row.get("query_id", "")
    if system_id not in {item[0] for item in SYSTEMS}:
        validation_errors.append(f"invalid resource system_id: {system_id}")
        continue
    if query_id not in valid_query_ids:
        validation_errors.append(f"invalid resource query_id: {query_id}")
        continue
    if safe_int(row.get("latency_ms", "0")) < 0:
        validation_errors.append(f"negative latency_ms: {row.get('resource_row_id', '')}")
        continue
    valid_resource_rows += 1

for row in supplied_citation_rows:
    system_id = row.get("system_id", "")
    query_id = row.get("query_id", "")
    span_id = row.get("source_span_id", "")
    citation_text = row.get("citation_text", "")
    if system_id not in {item[0] for item in SYSTEMS}:
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

for row in supplied_answer_rows:
    system_id = row.get("system_id", "")
    query_id = row.get("query_id", "")
    answer_id = row.get("answer_id", "")
    answer_text = row.get("answer_text", "")
    resource_row_id = row.get("resource_row_id", "")
    if system_id not in {item[0] for item in SYSTEMS}:
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
    supplied = sum(1 for row in supplied_answer_rows if row.get("system_id") == system_id)
    valid = valid_answer_by_system.get(system_id, 0)
    validation_rows.append(
        {
            "system_id": system_id,
            "system_name": name,
            "requirement": requirement,
            "target_answer_rows": len(queries),
            "supplied_answer_rows": supplied,
            "valid_answer_rows": valid,
            "missing_valid_answer_rows": max(0, len(queries) - valid),
            "status": "valid" if valid >= len(queries) else "missing-or-invalid",
        }
    )
write_csv(run_dir / "ah_supplied_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

validation_error_rows = [{"error_id": f"v53f_error_{idx:04d}", "message": message} for idx, message in enumerate(validation_errors, start=1)]
if not validation_error_rows:
    validation_error_rows = [{"error_id": "none", "message": "no supplied evidence errors recorded"}]
write_csv(run_dir / "ah_validation_error_rows.csv", list(validation_error_rows[0].keys()), validation_error_rows)

target_answer_rows = len(queries) * len(SYSTEMS)
required_core_systems_ready = int(all(valid_answer_by_system.get(system_id, 0) >= len(queries) for system_id in CORE_SYSTEMS))
optional_system_f_ready = int(valid_answer_by_system.get("F", 0) >= len(queries))
answer_citation_resource_rows_ready = int(required_core_systems_ready and valid_citation_rows >= len(queries) * len(CORE_SYSTEMS) and valid_resource_rows >= len(queries) * len(CORE_SYSTEMS))
supplied_dir_present = int(supplied_dir is not None)

summary = {
    "v53f_ah_answer_citation_resource_intake_ready": 1,
    "v53_ready": 0,
    "frozen_query_rows": len(queries),
    "target_system_count": len(SYSTEMS),
    "required_core_system_count": len(CORE_SYSTEMS),
    "optional_system_count": len(SYSTEMS) - len(CORE_SYSTEMS),
    "target_answer_rows": target_answer_rows,
    "target_resource_rows": target_answer_rows,
    "minimum_target_citation_rows": target_answer_rows,
    "supplied_evidence_dir_present": supplied_dir_present,
    "supplied_answer_rows": len(supplied_answer_rows),
    "supplied_citation_rows": len(supplied_citation_rows),
    "supplied_resource_rows": len(supplied_resource_rows),
    "valid_answer_rows": valid_answer_rows,
    "valid_citation_rows": valid_citation_rows,
    "valid_resource_rows": valid_resource_rows,
    "required_core_systems_ready": required_core_systems_ready,
    "optional_system_f_ready": optional_system_f_ready,
    "answer_citation_resource_rows_ready": answer_citation_resource_rows_ready,
    "v53e_canary_query_scale_ready": int(v53e_summary.get("v53e_canary_query_scale_ready", "0")),
    "complete_source_snapshot_ready": 0,
    "review_artifacts_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("answer-citation-resource-intake-schema", "pass", "A-H answer/citation/resource schemas and templates are emitted"),
    ("frozen-v53e-query-input", "pass" if summary["v53e_canary_query_scale_ready"] else "blocked", f"frozen_query_rows={len(queries)}"),
    ("a-h-system-target-matrix", "pass", f"target_system_count={len(SYSTEMS)}; target_answer_rows={target_answer_rows}"),
    ("supplied-a-h-answer-rows", "pass" if required_core_systems_ready else "blocked", f"valid_answer_rows={valid_answer_rows}; required_core_systems_ready={required_core_systems_ready}"),
    ("source-citation-coverage", "pass" if answer_citation_resource_rows_ready else "blocked", f"valid_citation_rows={valid_citation_rows}"),
    ("resource-measurement-coverage", "pass" if answer_citation_resource_rows_ready else "blocked", f"valid_resource_rows={valid_resource_rows}"),
    ("full-source-snapshot-scale", "blocked", "v53f validates answers over v53e canary queries, not complete source snapshots"),
    ("human-review-artifacts", "blocked", "human/release review artifacts are not supplied"),
    ("v53-full-public-repo-audit", "blocked", "A-H supplied rows and complete source snapshots are still required"),
    ("real-release-package", "blocked", "v53f intake is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md").write_text(
    "# v53f A-H Answer/Citation/Resource Intake Boundary\n\n"
    "This layer defines and validates the answer, citation, and resource evidence required to run A-H systems over the frozen v53e 1000-query canary set. "
    "It is an intake and validation layer, not a completed A-H comparison.\n\n"
    f"- frozen_query_rows={len(queries)}\n"
    f"- target_system_count={len(SYSTEMS)}\n"
    f"- target_answer_rows={target_answer_rows}\n"
    f"- supplied_answer_rows={len(supplied_answer_rows)}\n"
    f"- valid_answer_rows={valid_answer_rows}\n"
    f"- answer_citation_resource_rows_ready={answer_citation_resource_rows_ready}\n\n"
    "Still blocked:\n\n"
    "- supplied A-H answer rows over the frozen query set\n"
    "- source citation coverage for every non-abstain answer\n"
    "- resource/latency/model identity measurements for every answer\n"
    "- complete source snapshots beyond canary source files\n"
    "- human/release review artifacts\n\n"
    "Do not publish v53 safety/grounding superiority or 30B-150B comparison claims from an intake template alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v53f-ah-answer-citation-resource-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53f_ah_answer_citation_resource_intake_ready": 1,
    "v53_ready": 0,
    "frozen_query_rows": len(queries),
    "target_system_count": len(SYSTEMS),
    "target_answer_rows": target_answer_rows,
    "valid_answer_rows": valid_answer_rows,
    "answer_citation_resource_rows_ready": answer_citation_resource_rows_ready,
    "v53e_summary_sha256": sha256(results / "v53e_canary_query_scale_1000_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v53f_ah_answer_citation_resource_intake_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "ah_system_target_rows.csv",
    "answer_row_required_schema.csv",
    "citation_row_required_schema.csv",
    "resource_row_required_schema.csv",
    "ah_answer_row_template.csv",
    "ah_resource_row_template.csv",
    "ah_supplied_validation_rows.csv",
    "ah_validation_error_rows.csv",
    "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md",
    "v53f_ah_answer_citation_resource_intake_manifest.json",
    "source_v53e/scaled_canary_query_rows.csv",
    "source_v53e/scaled_canary_source_span_rows.csv",
    "source_v53e/scaled_canary_query_family_rows.csv",
    "source_v53e/scaled_canary_query_repo_rows.csv",
    "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
    "source_v53e/v53e_canary_query_scale_1000_manifest.json",
    "source_v53e/sha256_manifest.csv",
    "source_v53e/v53e_canary_query_scale_1000_summary.csv",
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

print(f"v53f_ah_answer_citation_resource_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
