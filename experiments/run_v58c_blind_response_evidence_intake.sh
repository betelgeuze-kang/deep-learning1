#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v58c_blind_response_evidence_intake"
RUN_ID="${V58C_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EVIDENCE_DIR="${V58C_BLIND_RESPONSE_EVIDENCE_DIR:-}"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V58C_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v58b_blind_eval_candidate_500_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v58b_blind_eval_candidate_500.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$EVIDENCE_DIR" <<'PY'
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
evidence_dir_arg = sys.argv[5]
results = root / "results"
v58b_dir = results / "v58b_blind_eval_candidate_500" / "candidate_001"
v58b_summary = list(csv.DictReader((results / "v58b_blind_eval_candidate_500_summary.csv").open(newline="", encoding="utf-8")))[0]

REQUIRED_SYSTEMS = {"D", "E", "G", "H"}
OPTIONAL_SYSTEMS = {"F"}
ALL_SYSTEMS = REQUIRED_SYSTEMS | OPTIONAL_SYSTEMS


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
    return dst


def is_sha256(value):
    return isinstance(value, str) and value.startswith("sha256:") and len(value) == 71


for relpath in [
    "blind_query_freeze_rows.csv",
    "sealed_answer_key_rows.csv",
    "blind_response_template_rows.csv",
    "blind_reviewer_packet_template_rows.csv",
    "blind_evidence_budget_rows.csv",
    "sealed_identity_key_rows.csv",
    "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md",
    "v58b_blind_eval_candidate_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v58b_dir / relpath, f"source_v58b/{relpath}")
copy(results / "v58b_blind_eval_candidate_500_summary.csv", "source_v58b/v58b_blind_eval_candidate_500_summary.csv")

templates = read_csv(v58b_dir / "blind_response_template_rows.csv")
query_rows = read_csv(v58b_dir / "blind_query_freeze_rows.csv")
identity_rows = read_csv(v58b_dir / "sealed_identity_key_rows.csv")
expected_response_ids = {row["blind_response_id"] for row in templates}
source_by_blind = {row["blind_system_id"]: row["source_system_id"] for row in identity_rows}

schema_rows = [
    ("blind_response_rows.csv", "blind_response_id", "must match v58b template id exactly once"),
    ("blind_response_rows.csv", "blind_eval_id", "must match v58b frozen query id"),
    ("blind_response_rows.csv", "blind_system_id", "must be one of blind_A..blind_E"),
    ("blind_response_rows.csv", "response_text", "non-empty unless abstained=1"),
    ("blind_response_rows.csv", "citation_source_span_id", "required for non-abstain answers"),
    ("blind_response_rows.csv", "abstained", "0 or 1"),
    ("blind_response_rows.csv", "output_sha256", "sha256:<64 hex> over response_text"),
    ("blind_response_rows.csv", "latency_ns", "positive integer measured runtime"),
    ("blind_response_rows.csv", "memory_peak_bytes", "non-negative integer"),
    ("blind_response_rows.csv", "cost_usd", "non-negative decimal; 0 for local systems if applicable"),
    ("blind_response_rows.csv", "model_run_id", "stable run id bound to model/system metadata"),
    ("blind_response_rows.csv", "credential_redacted", "must be 1 for hosted/API rows and allowed for all rows"),
    ("blind_response_rows.csv", "resource_trace_sha256", "sha256:<64 hex> or empty if copied trace not supplied"),
    ("run_identity_rows.csv", "blind_system_id", "must cover D/E/G/H and optional F if supplied"),
    ("run_identity_rows.csv", "source_system_id", "D/E/F/G/H mapping; reviewer packets remain blind"),
    ("run_identity_rows.csv", "model_or_architecture_id", "stable model/architecture identifier"),
    ("run_identity_rows.csv", "external_api_used", "0 for D/E/G/H, 0 or 1 for F"),
]
write_csv(
    run_dir / "blind_response_required_field_rows.csv",
    ["artifact", "field", "rule"],
    [{"artifact": artifact, "field": field, "rule": rule} for artifact, field, rule in schema_rows],
)

template_rows = []
for row in templates:
    template_rows.append(
        {
            "blind_response_id": row["blind_response_id"],
            "blind_eval_id": row["blind_eval_id"],
            "blind_system_id": row["blind_system_id"],
            "source_system_id": row["source_system_id"],
            "response_text": "",
            "citation_source_span_id": "",
            "abstained": "",
            "output_sha256": "",
            "latency_ns": "",
            "memory_peak_bytes": "",
            "cost_usd": "",
            "model_run_id": "",
            "credential_redacted": "",
            "resource_trace_sha256": "",
        }
    )
write_csv(run_dir / "blind_response_row_template.csv", list(template_rows[0].keys()), template_rows)

identity_template_rows = []
for row in identity_rows:
    identity_template_rows.append(
        {
            "blind_system_id": row["blind_system_id"],
            "source_system_id": row["source_system_id"],
            "model_or_architecture_id": "",
            "model_size_class": "30b" if row["source_system_id"] == "D" else "70b" if row["source_system_id"] == "E" else "100b-plus" if row["source_system_id"] == "F" else "routememory-routehint",
            "external_api_used": "",
            "credential_redacted": 1,
            "run_metadata_sha256": "",
        }
    )
write_csv(run_dir / "run_identity_template_rows.csv", list(identity_template_rows[0].keys()), identity_template_rows)

validation_rows = []
supplied_rows = []
identity_supplied_rows = []
evidence_dir = Path(evidence_dir_arg) if evidence_dir_arg else None
if not evidence_dir or not evidence_dir.is_dir():
    validation_rows.append({"check": "evidence-dir", "status": "blocked", "reason": "V58C_BLIND_RESPONSE_EVIDENCE_DIR not supplied"})
else:
    response_path = evidence_dir / "blind_response_rows.csv"
    identity_path = evidence_dir / "run_identity_rows.csv"
    for name, path in [("blind-response-file", response_path), ("run-identity-file", identity_path)]:
        if path.is_file() and path.stat().st_size > 0:
            copy(path, f"supplied_evidence/{path.name}")
            validation_rows.append({"check": name, "status": "pass", "reason": "present"})
        else:
            validation_rows.append({"check": name, "status": "fail", "reason": "missing-or-empty"})
    if response_path.is_file() and response_path.stat().st_size > 0:
        supplied_rows = read_csv(response_path)
    if identity_path.is_file() and identity_path.stat().st_size > 0:
        identity_supplied_rows = read_csv(identity_path)

errors = []
if supplied_rows:
    supplied_ids = [row.get("blind_response_id", "") for row in supplied_rows]
    supplied_id_set = set(supplied_ids)
    if len(supplied_ids) != len(supplied_id_set):
        errors.append("duplicate-blind-response-id")
    missing = expected_response_ids - supplied_id_set
    extra = supplied_id_set - expected_response_ids
    if missing:
        errors.append(f"missing-response-ids={len(missing)}")
    if extra:
        errors.append(f"extra-response-ids={len(extra)}")
    for row in supplied_rows:
        response_id = row.get("blind_response_id", "")
        if response_id not in expected_response_ids:
            continue
        if row.get("blind_eval_id", "") not in {q["blind_eval_id"] for q in query_rows}:
            errors.append("blind-eval-id-mismatch")
        if row.get("blind_system_id", "") not in source_by_blind:
            errors.append("blind-system-id-mismatch")
        abstained = row.get("abstained", "")
        if abstained not in {"0", "1"}:
            errors.append("abstained-not-binary")
        if abstained == "0" and not row.get("response_text", ""):
            errors.append("non-abstain-response-empty")
        if abstained == "0" and not row.get("citation_source_span_id", ""):
            errors.append("non-abstain-citation-empty")
        if row.get("output_sha256", "") != sha256_text(row.get("response_text", "")):
            errors.append("output-sha256-mismatch")
        for field in ["latency_ns", "memory_peak_bytes"]:
            try:
                value = int(row.get(field, ""))
            except ValueError:
                errors.append(f"{field}-not-integer")
                continue
            if value < 0 or (field == "latency_ns" and value == 0):
                errors.append(f"{field}-invalid")
        try:
            if float(row.get("cost_usd", "")) < 0:
                errors.append("cost-usd-negative")
        except ValueError:
            errors.append("cost-usd-not-float")
        if row.get("resource_trace_sha256") and not is_sha256(row.get("resource_trace_sha256")):
            errors.append("resource-trace-sha256-invalid")

if identity_supplied_rows:
    identity_systems = {row.get("source_system_id", "") for row in identity_supplied_rows}
    if not REQUIRED_SYSTEMS.issubset(identity_systems):
        errors.append("required-run-identities-missing")
    for row in identity_supplied_rows:
        source_system_id = row.get("source_system_id", "")
        if source_system_id not in ALL_SYSTEMS:
            errors.append("unexpected-source-system-id")
        if source_system_id in REQUIRED_SYSTEMS and row.get("external_api_used", "") != "0":
            errors.append("external-api-used-for-required-local-system")
        if source_system_id == "F" and row.get("credential_redacted", "") != "1":
            errors.append("hosted-credential-not-redacted")
        if row.get("run_metadata_sha256") and not is_sha256(row.get("run_metadata_sha256")):
            errors.append("run-metadata-sha256-invalid")

if errors:
    counts = Counter(errors)
    for error, count in sorted(counts.items()):
        validation_rows.append({"check": "supplied-evidence", "status": "fail", "reason": f"{error}:{count}"})

system_counts = Counter(row.get("source_system_id", "") for row in supplied_rows)
system_ready = {
    system_id: int(system_counts.get(system_id, 0) == 500 and not errors)
    for system_id in ALL_SYSTEMS
}
required_ready = all(system_ready[system_id] for system_id in REQUIRED_SYSTEMS)
optional_f_ready = system_ready["F"]
evidence_ready = int(required_ready and len(supplied_rows) >= 2000 and not errors)

summary = {
    "v58c_blind_response_evidence_intake_ready": 1,
    "v58_ready": 0,
    "evidence_dir_supplied": int(bool(evidence_dir_arg)),
    "expected_blind_response_rows": len(templates),
    "supplied_blind_response_rows": len(supplied_rows),
    "required_blind_response_rows": 2000,
    "required_blind_response_ready": int(required_ready),
    "d_30b_blind_response_ready": system_ready["D"],
    "e_70b_blind_response_ready": system_ready["E"],
    "g_routehint_blind_response_ready": system_ready["G"],
    "h_policy_blind_response_ready": system_ready["H"],
    "optional_100b_plus_blind_response_ready": optional_f_ready,
    "optional_100b_plus_blind_response_status": "ready" if optional_f_ready else "deferred-with-reason",
    "validation_error_rows": len(errors),
    "v58b_blind_eval_candidate_ready": int(v58b_summary.get("v58b_blind_eval_candidate_ready", "0")),
    "blind_response_absorb_ready": evidence_ready,
    "human_blind_review_ready": 0,
    "inter_rater_rows_ready": 0,
    "v58_full_blind_eval_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

if not validation_rows:
    validation_rows.append({"check": "supplied-evidence", "status": "pass", "reason": "required response rows validate"})
write_csv(run_dir / "blind_response_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

decision_rows = [
    ("intake-contract", "pass", "blind response schema and templates are emitted"),
    ("v58b-candidate-input", "pass", "500-row blind query freeze is present"),
    ("30b-blind-response-row", "pass" if system_ready["D"] else "blocked", "D rows ready" if system_ready["D"] else "30B blind responses missing"),
    ("70b-blind-response-row", "pass" if system_ready["E"] else "blocked", "E rows ready" if system_ready["E"] else "70B blind responses missing"),
    ("routehint-blind-response-row", "pass" if system_ready["G"] else "blocked", "G rows ready" if system_ready["G"] else "RouteMemory+RouteHint blind responses missing"),
    ("policy-blind-response-row", "pass" if system_ready["H"] else "blocked", "H rows ready" if system_ready["H"] else "policy/scorer blind responses missing"),
    ("100b-plus-blind-response-row", "pass" if optional_f_ready else "blocked", "F rows ready" if optional_f_ready else "100B+ hosted/API blind responses missing or deferred"),
    ("blind-response-absorb-ready", "pass" if evidence_ready else "blocked", "required blind responses validate" if evidence_ready else "required blind response rows are not supplied/valid"),
    ("human-blind-review", "blocked", "human blind review rows are not supplied"),
    ("v58-full-blind-eval", "blocked", "response rows alone do not include human blind review/adjudication"),
    ("real-release-package", "blocked", "v58c intake is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])
write_csv(run_dir / "blind_response_intake_gate_rows.csv", ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md").write_text(
    "# v58c Blind Response Evidence Intake Boundary\n\n"
    "This layer defines and validates the response evidence intake for the v58 blind evaluation. "
    "It is not a completed blind evaluation.\n\n"
    f"- expected_blind_response_rows={len(templates)}\n"
    f"- supplied_blind_response_rows={len(supplied_rows)}\n"
    f"- required_blind_response_ready={int(required_ready)}\n"
    "- human_blind_review_ready=0\n"
    "- inter_rater_rows_ready=0\n\n"
    "Still blocked by default:\n\n"
    "- real D/E/G/H blind response rows\n"
    "- optional F response rows or final deferral\n"
    "- human blind review and adjudication\n\n"
    "Do not publish blind-eval wins or 30B-150B comparison claims from response intake alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v58c-blind-response-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v58c_blind_response_evidence_intake_ready": 1,
    "v58_ready": 0,
    "expected_blind_response_rows": len(templates),
    "supplied_blind_response_rows": len(supplied_rows),
    "required_blind_response_ready": int(required_ready),
    "optional_100b_plus_blind_response_ready": optional_f_ready,
    "human_blind_review_ready": 0,
    "real_release_package_ready": 0,
    "source_v58b_summary_sha256": sha256(results / "v58b_blind_eval_candidate_500_summary.csv"),
}
(run_dir / "v58c_blind_response_evidence_intake_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "blind_response_required_field_rows.csv",
    "blind_response_row_template.csv",
    "run_identity_template_rows.csv",
    "blind_response_validation_rows.csv",
    "blind_response_intake_gate_rows.csv",
    "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md",
    "v58c_blind_response_evidence_intake_manifest.json",
    "source_v58b/blind_query_freeze_rows.csv",
    "source_v58b/sealed_answer_key_rows.csv",
    "source_v58b/blind_response_template_rows.csv",
    "source_v58b/blind_reviewer_packet_template_rows.csv",
    "source_v58b/blind_evidence_budget_rows.csv",
    "source_v58b/sealed_identity_key_rows.csv",
    "source_v58b/V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md",
    "source_v58b/v58b_blind_eval_candidate_manifest.json",
    "source_v58b/sha256_manifest.csv",
    "source_v58b/v58b_blind_eval_candidate_500_summary.csv",
]
if supplied_rows:
    artifact_rels.append("supplied_evidence/blind_response_rows.csv")
if identity_supplied_rows:
    artifact_rels.append("supplied_evidence/run_identity_rows.csv")
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v58c_blind_response_evidence_intake_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
