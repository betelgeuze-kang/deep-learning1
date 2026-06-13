#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eo_real_generation_intake_evidence_inbox_scaffold"
RUN_ID="${V61EO_RUN_ID:-scaffold_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61eo_real_generation_intake_evidence_inbox_scaffold_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null
V61EH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eh_real_generation_result_return_packet.sh" >/dev/null
V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
inbox_dir = run_dir / "real_generation_intake_inbox"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_empty_csv(path, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(fieldnames)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


source_paths = {
    "v61en_summary": results / "v61en_real_generation_intake_work_order_summary.csv",
    "v61en_decision": results / "v61en_real_generation_intake_work_order_decision.csv",
    "v61en_work_rows": results / "v61en_real_generation_intake_work_order" / "work_order_001" / "real_generation_intake_work_order_rows.csv",
    "v61en_command_rows": results / "v61en_real_generation_intake_work_order" / "work_order_001" / "real_generation_intake_command_rows.csv",
    "v61en_blocker_rows": results / "v61en_real_generation_intake_work_order" / "work_order_001" / "real_generation_intake_blocker_rows.csv",
    "v61eh_required_artifacts": results / "v61eh_real_generation_result_return_packet" / "packet_001" / "real_generation_result_return_packet" / "REQUIRED_GENERATION_RESULT_ARTIFACTS.csv",
    "v61eh_required_fields": results / "v61eh_real_generation_result_return_packet" / "packet_001" / "real_generation_result_return_packet" / "REQUIRED_FIELD_ROWS.csv",
    "v61eh_binding_contract": results / "v61eh_real_generation_result_return_packet" / "packet_001" / "real_generation_result_return_packet" / "PREREQUISITE_BINDING_CONTRACT.csv",
    "v61ck_summary": results / "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs_summary": results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd_summary": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61eo source {key}: {path}")
    copy(path, f"source/{path.name}")

v61en = read_csv(source_paths["v61en_summary"])[0]
if v61en["v61en_real_generation_intake_work_order_ready"] != "1":
    raise SystemExit("v61eo requires v61en_real_generation_intake_work_order_ready=1")

required_artifacts = read_csv(source_paths["v61eh_required_artifacts"])
required_fields = read_csv(source_paths["v61eh_required_fields"])
fields_by_artifact = {}
for row in required_fields:
    fields_by_artifact.setdefault(row["result_artifact"], []).append(row["field_name"])

template_rows = []
for row in required_artifacts:
    artifact = row["result_artifact"]
    artifact_type = row["artifact_type"]
    template_rel = Path("generation_result_return_templates") / (artifact + ".template")
    path = inbox_dir / template_rel
    if artifact_type == "csv":
        write_empty_csv(path, fields_by_artifact[artifact])
        template_kind = "csv-header-only"
    else:
        payload = {
            field: "fill-with-real-" + field.replace("_", "-")
            for field in fields_by_artifact[artifact]
        }
        payload["template_warning"] = "template-not-evidence"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        template_kind = "json-template"
    template_rows.append(
        {
            "template_id": "generation_result_" + artifact.replace(".", "_"),
            "template_family": "generation-result-return",
            "expected_final_artifact": artifact,
            "template_artifact": str(Path("real_generation_intake_inbox") / template_rel),
            "template_kind": template_kind,
            "expected_rows": row["expected_rows"],
            "required_field_rows": row["required_field_rows"],
            "file_ready": "1",
            "accepted_by_default": "0",
            "counts_as_real_generation_result": "0",
        }
    )

binding_sources = [
    ("v61ck", source_paths["v61ck_summary"].name, source_paths["v61ck_summary"]),
    ("v61cs", source_paths["v61cs_summary"].name, source_paths["v61cs_summary"]),
    ("v61dd", source_paths["v61dd_summary"].name, source_paths["v61dd_summary"]),
]
for source_id, final_name, source_path in binding_sources:
    header = read_csv(source_path)[0].keys()
    template_rel = Path("prerequisite_binding_templates") / (final_name + ".template")
    write_empty_csv(inbox_dir / template_rel, list(header))
    template_rows.append(
        {
            "template_id": "prerequisite_binding_" + source_id,
            "template_family": "prerequisite-binding",
            "expected_final_artifact": final_name,
            "template_artifact": str(Path("real_generation_intake_inbox") / template_rel),
            "template_kind": "csv-header-only",
            "expected_rows": "1",
            "required_field_rows": str(len(list(header))),
            "file_ready": "1",
            "accepted_by_default": "0",
            "counts_as_real_generation_result": "0",
        }
    )

provenance_rel = Path("review_return_provenance_templates") / "REAL_REVIEW_RETURN_PROVENANCE.json.template"
provenance_payload = {
    "binding_provenance": "real-review-return",
    "review_return_dir": "fill-with-real-review-return-dir",
    "review_return_summary_sha256": "fill-with-real-sha256",
    "operator_identity": "fill-with-real-operator-identity",
    "template_warning": "template-not-evidence",
}
(inbox_dir / provenance_rel).parent.mkdir(parents=True, exist_ok=True)
(inbox_dir / provenance_rel).write_text(json.dumps(provenance_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
template_rows.append(
    {
        "template_id": "review_return_provenance",
        "template_family": "review-return-provenance",
        "expected_final_artifact": "REAL_REVIEW_RETURN_PROVENANCE.json",
        "template_artifact": str(Path("real_generation_intake_inbox") / provenance_rel),
        "template_kind": "json-template",
        "expected_rows": "1",
        "required_field_rows": "4",
        "file_ready": "1",
        "accepted_by_default": "0",
        "counts_as_real_generation_result": "0",
    }
)
write_csv(run_dir / "real_generation_intake_inbox_template_rows.csv", list(template_rows[0].keys()), template_rows)

path_contract_rows = [
    {
        "contract_id": "real-generation-result-dir",
        "env_var": "V61EJ_GENERATION_RESULT_DIR",
        "template_source": "real_generation_intake_inbox/generation_result_return_templates",
        "expected_real_path": "/path/to/real_generation_result_return",
        "downstream_gate": "v61ej",
        "ready_now": "0",
    },
    {
        "contract_id": "real-prerequisite-binding-dir",
        "env_var": "V61EL_PREREQUISITE_BINDING_DIR",
        "template_source": "real_generation_intake_inbox/prerequisite_binding_templates",
        "expected_real_path": "/path/to/real_prerequisite_binding",
        "downstream_gate": "v61el",
        "ready_now": "0",
    },
    {
        "contract_id": "real-review-return-provenance",
        "env_var": "V61EL_BINDING_PROVENANCE",
        "template_source": "real_generation_intake_inbox/review_return_provenance_templates",
        "expected_real_path": "real-review-return",
        "downstream_gate": "v61el",
        "ready_now": "0",
    },
    {
        "contract_id": "real-dual-rendezvous-generation-preflight",
        "env_var": "V61EM_GENERATION_PREFLIGHT_RUN_DIR",
        "template_source": "results/v61ej_real_generation_return_receiver_preflight/<real-run>",
        "expected_real_path": "/path/to/real_v61ej_preflight",
        "downstream_gate": "v61em",
        "ready_now": "0",
    },
    {
        "contract_id": "real-dual-rendezvous-binding-preflight",
        "env_var": "V61EM_BINDING_PREFLIGHT_RUN_DIR",
        "template_source": "results/v61el_real_prerequisite_binding_receiver_preflight/<real-run>",
        "expected_real_path": "/path/to/real_v61el_preflight",
        "downstream_gate": "v61em",
        "ready_now": "0",
    },
]
write_csv(run_dir / "real_generation_intake_path_contract_rows.csv", list(path_contract_rows[0].keys()), path_contract_rows)

env_template = """# v61eo template-only environment
# Replace every /path/to/... value with non-fixture evidence before running.

export V61EJ_GENERATION_RESULT_DIR=/path/to/real_generation_result_return
export V61EL_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding
export V61EL_BINDING_PROVENANCE=real-review-return
export V61EM_GENERATION_PREFLIGHT_RUN_DIR=/path/to/real_v61ej_preflight
export V61EM_BINDING_PREFLIGHT_RUN_DIR=/path/to/real_v61el_preflight
"""
(run_dir / "RETURN_ENV.template").write_text(env_template, encoding="utf-8")

verify_script = """#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
test -d "$ROOT/real_generation_result_return" || { echo "missing real_generation_result_return" >&2; exit 1; }
test -d "$ROOT/real_prerequisite_binding" || { echo "missing real_prerequisite_binding" >&2; exit 1; }
test -f "$ROOT/REAL_REVIEW_RETURN_PROVENANCE.json" || { echo "missing REAL_REVIEW_RETURN_PROVENANCE.json" >&2; exit 1; }
for name in real_model_generation_answer_rows.csv real_model_generation_citation_rows.csv real_model_generation_abstain_fallback_rows.csv real_model_generation_latency_rows.csv real_model_generation_acceptance_summary.json; do
  test -s "$ROOT/real_generation_result_return/$name" || { echo "missing generation result $name" >&2; exit 1; }
done
for name in v61ck_real_generation_unblocker_operator_matrix_summary.csv v61cs_complete_source_generation_execution_admission_gate_summary.csv v61dd_review_return_generation_refresh_bridge_summary.csv; do
  test -s "$ROOT/real_prerequisite_binding/$name" || { echo "missing prerequisite binding $name" >&2; exit 1; }
done
echo "v61eo real generation intake evidence inbox shape verified"
"""
(run_dir / "VERIFY_REAL_GENERATION_INTAKE_INBOX.sh").write_text(verify_script, encoding="utf-8")

command_rows = [
    {
        "command_id": "verify-template-inbox-shape",
        "command": "bash results/v61eo_real_generation_intake_evidence_inbox_scaffold/scaffold_001/VERIFY_REAL_GENERATION_INTAKE_INBOX.sh /path/to/filled_real_intake_inbox",
        "ready_to_run_now": "0",
        "purpose": "verify a filled non-fixture intake inbox before downstream gates",
    },
    {
        "command_id": "preflight-filled-generation-results",
        "command": "V61EJ_GENERATION_RESULT_DIR=/path/to/real_generation_result_return ./experiments/run_v61ej_real_generation_return_receiver_preflight.sh",
        "ready_to_run_now": "0",
        "purpose": "convert filled generation-result inbox into v61ej preflight rows",
    },
    {
        "command_id": "preflight-filled-prerequisite-binding",
        "command": "V61EL_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding V61EL_BINDING_PROVENANCE=real-review-return ./experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh",
        "ready_to_run_now": "0",
        "purpose": "convert filled binding inbox into v61el preflight rows",
    },
    {
        "command_id": "run-real-dual-rendezvous",
        "command": "V61EM_GENERATION_PREFLIGHT_RUN_DIR=/path/to/real_v61ej_preflight V61EM_BINDING_PREFLIGHT_RUN_DIR=/path/to/real_v61el_preflight ./experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh",
        "ready_to_run_now": "0",
        "purpose": "open real intake handoff after both real preflights pass",
    },
]
write_csv(run_dir / "real_generation_intake_inbox_command_rows.csv", list(command_rows[0].keys()), command_rows)

template_file_rows = len(template_rows)
ready_template_rows = sum(row["file_ready"] == "1" for row in template_rows)
accepted_by_default_rows = sum(row["accepted_by_default"] == "1" for row in template_rows)
summary = {
    "v61eo_real_generation_intake_evidence_inbox_scaffold_ready": "1",
    "v61en_real_generation_intake_work_order_ready": v61en["v61en_real_generation_intake_work_order_ready"],
    "inbox_template_rows": str(template_file_rows),
    "ready_inbox_template_rows": str(ready_template_rows),
    "generation_result_template_rows": "5",
    "prerequisite_binding_template_rows": "3",
    "review_return_provenance_template_rows": "1",
    "path_contract_rows": str(len(path_contract_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": "0",
    "accepted_by_default_rows": str(accepted_by_default_rows),
    "real_generation_result_artifacts": "0",
    "real_prerequisite_binding_ready": "0",
    "real_generation_intake_handoff_ready": v61en["real_generation_intake_handoff_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61eo": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61en-work-order", "status": "pass", "reason": "v61en work order is ready"},
    {"gate": "template-inbox-written", "status": "pass", "reason": f"templates={ready_template_rows}/{template_file_rows}"},
    {"gate": "no-default-evidence", "status": "pass", "reason": f"accepted_by_default_rows={accepted_by_default_rows}"},
    {"gate": "real-generation-intake-handoff", "status": "blocked", "reason": "inbox scaffold contains templates only"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted real generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only scaffold"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

readme = """# v61eo Real Generation Intake Evidence Inbox Scaffold

This directory is template-only. Files ending in `.template` are not accepted
evidence and must be copied to a separate real intake directory after real
review/generation work is completed.

Use `RETURN_ENV.template` as the shape for environment variables, then run
`VERIFY_REAL_GENERATION_INTAKE_INBOX.sh /path/to/filled_real_intake_inbox`
before rerunning v61ej/v61el/v61em.
"""
(run_dir / "README.md").write_text(readme, encoding="utf-8")

manifest = {
    "manifest_scope": "v61eo-real-generation-intake-evidence-inbox-scaffold",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61eo_real_generation_intake_evidence_inbox_scaffold_ready": 1,
    "inbox_template_rows": template_file_rows,
    "accepted_by_default_rows": accepted_by_default_rows,
    "real_generation_intake_handoff_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61eo_real_generation_intake_evidence_inbox_scaffold_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61eo_real_generation_intake_evidence_inbox_scaffold_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
