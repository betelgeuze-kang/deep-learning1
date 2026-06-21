#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61et_real_generation_intake_return_bundle_preflight"
RUN_ID="${V61ET_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR_ARG="${V61ET_RETURN_BUNDLE_DIR:-}"
RETURN_BUNDLE_PROVENANCE="${V61ET_RETURN_BUNDLE_PROVENANCE:-unspecified}"

if [[ "${V61ET_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61et_real_generation_intake_return_bundle_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V61ET_REFRESH_SOURCES:-1}" == "1" ]]; then
  V61ES_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null
  V61ER_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null
  V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
  V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null
  V61EO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eo_real_generation_intake_evidence_inbox_scaffold.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR_ARG" "$RETURN_BUNDLE_PROVENANCE" <<'PY'
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
bundle_arg = sys.argv[5].strip()
bundle_provenance = sys.argv[6].strip() or "unspecified"
results = root / "results"
bundle_dir = Path(bundle_arg).expanduser().resolve() if bundle_arg else None
REAL_BUNDLE_PROVENANCE = "real-generation-intake-return-bundle"
DEFAULT_AUTHORITY_REL = "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt"
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def status(flag):
    return "pass" if flag else "blocked"


def valid_sha(value):
    return isinstance(value, str) and bool(SHA_RE.match(value))


def safe_relative(base, rel):
    rel_value = str(rel or "")
    if not rel_value:
        return None, "authority-path-missing"
    rel_path = Path(rel_value)
    if rel_path.is_absolute() or ".." in rel_path.parts:
        return None, "authority-path-unsafe"
    return base / rel_path, ""


source_paths = [
    (results / "v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv", "source_summaries/v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv"),
    (results / "v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv", "source_summaries/v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv"),
    (results / "v61ej_real_generation_return_receiver_preflight_summary.csv", "source_summaries/v61ej_real_generation_return_receiver_preflight_summary.csv"),
    (results / "v61el_real_prerequisite_binding_receiver_preflight_summary.csv", "source_summaries/v61el_real_prerequisite_binding_receiver_preflight_summary.csv"),
    (results / "v61eo_real_generation_intake_evidence_inbox_scaffold_summary.csv", "source_summaries/v61eo_real_generation_intake_evidence_inbox_scaffold_summary.csv"),
    (results / "v61eh_real_generation_result_return_packet" / "packet_001" / "real_generation_result_return_packet" / "REQUIRED_GENERATION_RESULT_ARTIFACTS.csv", "source_contracts/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv"),
    (results / "v61eh_real_generation_result_return_packet" / "packet_001" / "real_generation_result_return_packet" / "REQUIRED_FIELD_ROWS.csv", "source_contracts/REQUIRED_FIELD_ROWS.csv"),
    (results / "v61eo_real_generation_intake_evidence_inbox_scaffold" / "scaffold_001" / "source" / "PREREQUISITE_BINDING_CONTRACT.csv", "source_contracts/PREREQUISITE_BINDING_CONTRACT.csv"),
]
for src, rel in source_paths:
    if not src.is_file():
        raise SystemExit(f"missing v61et source artifact: {src}")
    copy(src, rel)

required_generation = [row["result_artifact"] for row in read_csv(source_paths[5][0])]
required_binding = [
    "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd_review_return_generation_refresh_bridge_summary.csv",
]
required_files = [
    ("dispatch-receipt", "dispatch_receipt/DISPATCH_RECEIPT.json"),
    *[("generation-result", f"generation_result_return/{name}") for name in required_generation],
    *[("prerequisite-binding", f"prerequisite_binding/{name}") for name in required_binding],
    ("review-return-provenance", "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json"),
    ("review-return-provenance", DEFAULT_AUTHORITY_REL),
]

bundle_dir_supplied = int(bundle_dir is not None)
bundle_dir_exists = int(bundle_dir is not None and bundle_dir.is_dir())
env_real_provenance = int(bundle_provenance == REAL_BUNDLE_PROVENANCE)
marker_rel = "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json"
marker_path = bundle_dir / marker_rel if bundle_dir is not None else None
marker_supplied = int(marker_path is not None and marker_path.is_file())
marker_payload = {}
marker_errors = []
marker_sha = ""
marker_source_class = ""
marker_authority_sha = ""
marker_authority_path = ""
marker_authority_file_sha = ""
marker_authority_file_bytes = 0
marker_authority_file_exists = 0
marker_accepted_as_real = 0
if marker_supplied:
    marker_sha = sha256(marker_path)
    try:
        marker_payload = json.loads(marker_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        marker_errors.append("invalid-json")
    provenance_value = marker_payload.get("provenance") or marker_payload.get("provenance_class")
    if provenance_value != REAL_BUNDLE_PROVENANCE:
        marker_errors.append("provenance-mismatch")
    marker_source_class = str(marker_payload.get("source_class") or marker_payload.get("provenance_class", ""))
    if marker_source_class.startswith("fixture"):
        marker_errors.append("fixture-source-class")
    if marker_source_class not in {"external-generation-intake-return", "external-operator-return", REAL_BUNDLE_PROVENANCE}:
        marker_errors.append("source-class-not-external-generation-intake")
    marker_authority_sha = str(
        marker_payload.get(
            "generation_operator_authority_sha256",
            marker_payload.get("reviewer_authority_sha256", ""),
        )
    )
    if not valid_sha(marker_authority_sha):
        marker_errors.append("operator-authority-sha256-missing")
    marker_authority_path = str(
        marker_payload.get(
            "generation_operator_authority_path",
            marker_payload.get("reviewer_authority_path", marker_payload.get("authority_statement_path", DEFAULT_AUTHORITY_REL)),
        )
    )
    authority_path, authority_error = safe_relative(bundle_dir, marker_authority_path)
    if authority_error:
        marker_errors.append(authority_error)
    marker_authority_file_exists = int(authority_path is not None and authority_path.is_file())
    if marker_authority_file_exists:
        marker_authority_file_sha = sha256(authority_path)
        marker_authority_file_bytes = authority_path.stat().st_size
        if marker_authority_file_bytes <= 0:
            marker_errors.append("authority-file-empty")
        if marker_authority_sha and marker_authority_file_sha != marker_authority_sha:
            marker_errors.append("authority-sha-mismatch")
        try:
            authority_text = authority_path.read_text(encoding="utf-8", errors="replace").lower()
        except OSError:
            authority_text = ""
            marker_errors.append("authority-file-unreadable")
        if "fixture" in authority_text or "synthetic" in authority_text:
            marker_errors.append("authority-file-fixture-text")
    else:
        marker_errors.append("authority-file-missing")
    marker_accepted_as_real = int(marker_payload.get("accepted_as_real") in {1, True, "1", "true", "True"})
    if not marker_accepted_as_real:
        marker_errors.append("accepted-as-real-missing")
else:
    marker_errors.append("missing-provenance-marker")
marker_real_provenance = int(marker_supplied and not marker_errors)

if not bundle_dir_supplied:
    selected_bundle_source_class = "none"
elif marker_source_class.startswith("fixture"):
    selected_bundle_source_class = "fixture-v61et-return-bundle"
else:
    selected_bundle_source_class = "operator-supplied"

file_rows = []
family_counts = {}
present_rows = 0
template_named_rows = 0
payload_like_rows = 0
json_readable_rows = 0
for family, rel in required_files:
    path = bundle_dir / rel if bundle_dir is not None else None
    exists = int(path is not None and path.is_file())
    present_rows += exists
    template_named = int(path is not None and path.name.endswith(".template"))
    payload_like = int(path is not None and path.name.endswith((".safetensors", ".bin", ".pt")))
    template_named_rows += template_named
    payload_like_rows += payload_like
    digest = sha256(path) if exists else ""
    bytes_value = path.stat().st_size if exists else 0
    json_readable = 0
    if exists and path.name.endswith(".json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            json_readable = int(isinstance(data, dict))
        except json.JSONDecodeError:
            json_readable = 0
    if exists:
        copy(path, f"selected_return_bundle/{rel}")
    family_counts.setdefault(family, {"required": 0, "present": 0})
    family_counts[family]["required"] += 1
    family_counts[family]["present"] += exists
    file_rows.append(
        {
            "family": family,
            "required_path": rel,
            "bundle_dir_supplied": str(bundle_dir_supplied),
            "file_exists": str(exists),
            "template_named": str(template_named),
            "payload_like_file": str(payload_like),
            "json_readable": str(json_readable),
            "bytes": str(bytes_value),
            "sha256": digest,
        }
    )
    json_readable_rows += json_readable
write_csv(run_dir / "real_generation_intake_return_bundle_file_rows.csv", list(file_rows[0].keys()), file_rows)

family_rows = [
    {
        "family": family,
        "required_files": str(counts["required"]),
        "present_files": str(counts["present"]),
        "family_preflight_ready": str(int(counts["required"] == counts["present"])),
    }
    for family, counts in sorted(family_counts.items())
]
write_csv(run_dir / "real_generation_intake_return_bundle_family_rows.csv", list(family_rows[0].keys()), family_rows)

required_file_rows = len(required_files)
family_ready_rows = sum(row["family_preflight_ready"] == "1" for row in family_rows)
candidate_preflight_ready = int(
    bundle_dir_supplied
    and bundle_dir_exists
    and present_rows == required_file_rows
    and family_ready_rows == len(family_rows)
    and template_named_rows == 0
    and payload_like_rows == 0
)
non_fixture_return_bundle = int(bundle_dir_supplied and selected_bundle_source_class == "operator-supplied")
real_return_bundle_provenance_asserted = int(env_real_provenance and marker_real_provenance)
real_return_bundle_preflight_ready = int(
    candidate_preflight_ready
    and non_fixture_return_bundle
    and real_return_bundle_provenance_asserted
)

requirement_rows = [
    {"requirement_id": "return-bundle-dir-supplied", "status": status(bundle_dir_supplied), "required_value": "1", "actual_value": str(bundle_dir_supplied), "reason": "operator must supply V61ET_RETURN_BUNDLE_DIR"},
    {"requirement_id": "return-bundle-dir-exists", "status": status(bundle_dir_exists), "required_value": "1", "actual_value": str(bundle_dir_exists), "reason": "supplied return bundle directory must exist"},
    {"requirement_id": "required-files-present", "status": status(present_rows == required_file_rows), "required_value": str(required_file_rows), "actual_value": str(present_rows), "reason": "receipt, generation, binding, and provenance files must all be present"},
    {"requirement_id": "family-preflight-ready", "status": status(family_ready_rows == len(family_rows)), "required_value": str(len(family_rows)), "actual_value": str(family_ready_rows), "reason": "all return families must be complete"},
    {"requirement_id": "no-template-names", "status": status(template_named_rows == 0), "required_value": "0", "actual_value": str(template_named_rows), "reason": "final return bundle must not contain .template evidence names"},
    {"requirement_id": "no-payload-like-files", "status": status(payload_like_rows == 0), "required_value": "0", "actual_value": str(payload_like_rows), "reason": "return bundle must not contain checkpoint payload files"},
    {"requirement_id": "return-bundle-candidate-preflight", "status": status(candidate_preflight_ready), "required_value": "1", "actual_value": str(candidate_preflight_ready), "reason": "mechanical one-root bundle preflight"},
    {"requirement_id": "non-fixture-return-bundle", "status": status(non_fixture_return_bundle), "required_value": "1", "actual_value": str(non_fixture_return_bundle), "reason": "fixture bundle does not count as real evidence"},
    {"requirement_id": "real-return-bundle-provenance", "status": status(real_return_bundle_provenance_asserted), "required_value": "env=real-generation-intake-return-bundle;marker=real-generation-intake-return-bundle", "actual_value": f"env={bundle_provenance};marker_real={marker_real_provenance};errors={';'.join(marker_errors)}", "reason": "real provenance must be backed by bundle provenance marker evidence"},
    {"requirement_id": "real-return-bundle-preflight", "status": status(real_return_bundle_preflight_ready), "required_value": "1", "actual_value": str(real_return_bundle_preflight_ready), "reason": "candidate plus non-fixture marker-backed provenance required"},
    {"requirement_id": "downstream-row-acceptance", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "v61et is bundle preflight only"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "real_generation_intake_return_bundle_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

command_rows = [
    {
        "command_id": "preflight-return-bundle",
        "command": "V61ET_RETURN_BUNDLE_DIR=<returned_bundle_root> ./experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "validate one-root returned bundle shape",
    },
    {
        "command_id": "preflight-dispatch-receipt",
        "command": "V61ER_DISPATCH_RECEIPT_DIR=<returned_bundle_root>/dispatch_receipt ./experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh",
        "ready_to_run_now": str(candidate_preflight_ready),
        "purpose": "fan out receipt to v61er after bundle preflight",
    },
    {
        "command_id": "preflight-generation-result",
        "command": "V61EJ_GENERATION_RESULT_DIR=<returned_bundle_root>/generation_result_return ./experiments/run_v61ej_real_generation_return_receiver_preflight.sh",
        "ready_to_run_now": str(candidate_preflight_ready),
        "purpose": "fan out generation result artifacts to v61ej",
    },
    {
        "command_id": "preflight-prerequisite-binding",
        "command": "V61EL_PREREQUISITE_BINDING_DIR=<returned_bundle_root>/prerequisite_binding V61EL_BINDING_PROVENANCE=real-review-return ./experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh",
        "ready_to_run_now": str(candidate_preflight_ready),
        "purpose": "fan out prerequisite binding to v61el",
    },
    {
        "command_id": "run-downstream-intake",
        "command": "Run v61em/v61en/v61es after v61er/v61ej/v61el pass on real non-fixture evidence",
        "ready_to_run_now": str(real_return_bundle_preflight_ready),
        "purpose": "open downstream intake only after real bundle preflight",
    },
]
write_csv(run_dir / "real_generation_intake_return_bundle_command_rows.csv", list(command_rows[0].keys()), command_rows)

runtime_gap_rows = [
    {"gap": "return-bundle-candidate", "status": "ready" if candidate_preflight_ready else "blocked", "reason": f"present_files={present_rows}/{required_file_rows}"},
    {"gap": "real-return-bundle", "status": "ready" if real_return_bundle_preflight_ready else "blocked", "reason": "requires non-fixture bundle and explicit provenance"},
    {"gap": "downstream-row-acceptance", "status": "blocked", "reason": "v61et does not run v61er/v61ej/v61el acceptance"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

summary = {
    "v61et_real_generation_intake_return_bundle_preflight_ready": "1",
    "return_bundle_dir_supplied": str(bundle_dir_supplied),
    "return_bundle_dir_exists": str(bundle_dir_exists),
    "selected_bundle_source_class": selected_bundle_source_class,
    "return_bundle_provenance_env_real": str(env_real_provenance),
    "return_bundle_marker_supplied": str(marker_supplied),
    "return_bundle_marker_real_provenance": str(marker_real_provenance),
    "return_bundle_marker_source_class": marker_source_class,
    "return_bundle_marker_authority_path": marker_authority_path,
    "return_bundle_marker_authority_sha256": marker_authority_sha,
    "return_bundle_marker_authority_file_exists": str(marker_authority_file_exists),
    "return_bundle_marker_authority_file_sha256": marker_authority_file_sha,
    "return_bundle_marker_authority_file_bytes": str(marker_authority_file_bytes),
    "return_bundle_marker_accepted_as_real": str(marker_accepted_as_real),
    "return_bundle_marker_sha256": marker_sha,
    "return_bundle_marker_errors": ";".join(marker_errors),
    "required_return_bundle_files": str(required_file_rows),
    "present_return_bundle_files": str(present_rows),
    "return_bundle_family_rows": str(len(family_rows)),
    "ready_return_bundle_family_rows": str(family_ready_rows),
    "template_named_return_bundle_files": str(template_named_rows),
    "payload_like_return_bundle_files": str(payload_like_rows),
    "return_bundle_candidate_preflight_ready": str(candidate_preflight_ready),
    "non_fixture_return_bundle": str(non_fixture_return_bundle),
    "real_return_bundle_provenance_asserted": str(real_return_bundle_provenance_asserted),
    "real_return_bundle_preflight_ready": str(real_return_bundle_preflight_ready),
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61et": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "return-bundle-candidate-preflight", "status": status(candidate_preflight_ready), "reason": f"candidate={candidate_preflight_ready}"},
    {"gate": "non-fixture-return-bundle", "status": status(non_fixture_return_bundle), "reason": f"class={selected_bundle_source_class}"},
    {"gate": "real-return-bundle-provenance", "status": status(real_return_bundle_provenance_asserted), "reason": f"env={bundle_provenance}; marker_real={marker_real_provenance}; errors={';'.join(marker_errors)}"},
    {"gate": "real-return-bundle-preflight", "status": status(real_return_bundle_preflight_ready), "reason": f"real_bundle={real_return_bundle_preflight_ready}"},
    {"gate": "downstream-row-acceptance", "status": "blocked", "reason": "bundle preflight only"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata/evidence bundle preflight only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61ET_REAL_GENERATION_INTAKE_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61et Real Generation Intake Return Bundle Preflight Boundary",
            "",
            f"- return_bundle_dir_supplied={bundle_dir_supplied}",
            f"- present_return_bundle_files={present_rows}/{required_file_rows}",
            f"- return_bundle_candidate_preflight_ready={candidate_preflight_ready}",
            f"- return_bundle_marker_real_provenance={marker_real_provenance}",
            f"- return_bundle_marker_errors={';'.join(marker_errors)}",
            f"- real_return_bundle_preflight_ready={real_return_bundle_preflight_ready}",
            "- downstream_row_acceptance_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- A one-root return bundle shape can be preflighted before downstream intake.",
            "- Fixture bundle success proves logistics only.",
            "",
            "Blocked wording:",
            "- Do not claim downstream row acceptance, real generation intake, actual generation, latency, near-frontier quality, or release readiness from v61et alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61et-real-generation-intake-return-bundle-preflight",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61et_real_generation_intake_return_bundle_preflight_ready": 1,
    "return_bundle_candidate_preflight_ready": candidate_preflight_ready,
    "return_bundle_marker_real_provenance": marker_real_provenance,
    "return_bundle_marker_errors": marker_errors,
    "real_return_bundle_preflight_ready": real_return_bundle_preflight_ready,
    "downstream_row_acceptance_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61et_real_generation_intake_return_bundle_preflight_manifest.json").write_text(
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

echo "v61et_real_generation_intake_return_bundle_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
