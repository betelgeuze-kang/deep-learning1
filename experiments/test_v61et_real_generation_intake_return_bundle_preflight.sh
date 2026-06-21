#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61et_real_generation_intake_return_bundle_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
FIXTURE_BUNDLE_DIR="$RESULTS_DIR/$PREFIX/fixture_return_bundle_input"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_return_bundle_preflight_v61et"
TMP_DIR="$RESULTS_DIR/$PREFIX/tmp_v61et"
SPOOF_BUNDLE_DIR="$TMP_DIR/operator_named_fixture_copy"
SPOOF_RUN_DIR="$RESULTS_DIR/$PREFIX/copied_fixture_spoof_v61et"
FORGED_MARKER_BUNDLE_DIR="$TMP_DIR/real_marker_forged_fixture_copy"
FORGED_MARKER_RUN_DIR="$RESULTS_DIR/$PREFIX/real_marker_forged_fixture_v61et"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$FIXTURE_BUNDLE_DIR" "$TMP_DIR" "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SPOOF_RUN_DIR" "$FORGED_MARKER_RUN_DIR"
mkdir -p \
  "$RESULTS_DIR/v61eh_real_generation_result_return_packet/packet_001/real_generation_result_return_packet" \
  "$RESULTS_DIR/v61eo_real_generation_intake_evidence_inbox_scaffold/scaffold_001/source" \
  "$FIXTURE_BUNDLE_DIR/dispatch_receipt" \
  "$FIXTURE_BUNDLE_DIR/generation_result_return" \
  "$FIXTURE_BUNDLE_DIR/prerequisite_binding" \
  "$FIXTURE_BUNDLE_DIR/review_return_provenance/operator_attestation" \
  "$FIXTURE_BUNDLE_DIR/review_return_provenance" \
  "$TMP_DIR"

python3 - "$ROOT_DIR" "$FIXTURE_BUNDLE_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
bundle = Path(sys.argv[2])
results = root / "results"
authority_rel = "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


summary_names = [
    "v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv",
    "v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv",
    "v61ej_real_generation_return_receiver_preflight_summary.csv",
    "v61el_real_prerequisite_binding_receiver_preflight_summary.csv",
    "v61eo_real_generation_intake_evidence_inbox_scaffold_summary.csv",
]
for name in summary_names:
    with (results / name).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["artifact", "ready"], lineterminator="\n")
        writer.writeheader()
        writer.writerow({"artifact": name.removesuffix("_summary.csv"), "ready": "1"})

contract_dir = results / "v61eh_real_generation_result_return_packet/packet_001/real_generation_result_return_packet"
generation_artifacts = [
    "real_model_generation_answer_rows.csv",
    "real_model_generation_citation_rows.csv",
    "real_model_generation_resource_rows.csv",
    "real_model_generation_guard_rows.csv",
    "sha256_manifest.csv",
]
with (contract_dir / "REQUIRED_GENERATION_RESULT_ARTIFACTS.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["result_artifact"], lineterminator="\n")
    writer.writeheader()
    for artifact in generation_artifacts:
        writer.writerow({"result_artifact": artifact})
with (contract_dir / "REQUIRED_FIELD_ROWS.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "field"], lineterminator="\n")
    writer.writeheader()
    writer.writerow({"artifact": "real_model_generation_answer_rows.csv", "field": "answer_id"})

binding_contract = results / "v61eo_real_generation_intake_evidence_inbox_scaffold/scaffold_001/source/PREREQUISITE_BINDING_CONTRACT.csv"
with binding_contract.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["binding_artifact"], lineterminator="\n")
    writer.writeheader()
    for artifact in [
        "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
        "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
        "v61dd_review_return_generation_refresh_bridge_summary.csv",
    ]:
        writer.writerow({"binding_artifact": artifact})

(bundle / "dispatch_receipt/DISPATCH_RECEIPT.json").write_text(
    json.dumps({"accepted_as_real": 0, "dispatch_id": "fixture-v61et"}, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
for artifact in generation_artifacts:
    (bundle / "generation_result_return" / artifact).write_text("row_id,value\nfixture,0\n", encoding="utf-8")
for artifact in [
    "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd_review_return_generation_refresh_bridge_summary.csv",
]:
    (bundle / "prerequisite_binding" / artifact).write_text("artifact,ready\nfixture,0\n", encoding="utf-8")
authority_path = bundle / authority_rel
authority_path.write_text("fixture generation operator authority statement\n", encoding="utf-8")
(bundle / "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json").write_text(
    json.dumps(
        {
            "accepted_as_real": 0,
            "generation_operator_authority_path": authority_rel,
            "generation_operator_authority_sha256": sha256(authority_path),
            "provenance_class": "fixture-v61et-return-bundle",
            "review_return_source": "fixture-v61ed",
            "source_class": "fixture-v61et-return-bundle",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY

V61ET_REFRESH_SOURCES=0 \
V61ET_REUSE_EXISTING="${V61ET_REUSE_EXISTING:-0}" \
"$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

V61ET_REFRESH_SOURCES=0 \
V61ET_RUN_ID="fixture_return_bundle_preflight_v61et" \
V61ET_RETURN_BUNDLE_DIR="$FIXTURE_BUNDLE_DIR" \
V61ET_RETURN_BUNDLE_PROVENANCE="fixture-v61et-return-bundle" \
V61ET_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

cp -a "$FIXTURE_BUNDLE_DIR" "$SPOOF_BUNDLE_DIR"
V61ET_REFRESH_SOURCES=0 \
V61ET_RUN_ID="copied_fixture_spoof_v61et" \
V61ET_RETURN_BUNDLE_DIR="$SPOOF_BUNDLE_DIR" \
V61ET_RETURN_BUNDLE_PROVENANCE="real-generation-intake-return-bundle" \
V61ET_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

cp -a "$FIXTURE_BUNDLE_DIR" "$FORGED_MARKER_BUNDLE_DIR"
python3 - "$FORGED_MARKER_BUNDLE_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
authority_rel = "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt"
authority_path = bundle / authority_rel
h = hashlib.sha256()
with authority_path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        h.update(chunk)
marker = {
    "accepted_as_real": 1,
    "generation_operator_authority_path": authority_rel,
    "generation_operator_authority_sha256": "sha256:" + h.hexdigest(),
    "provenance": "real-generation-intake-return-bundle",
    "source_class": "external-generation-intake-return",
}
(bundle / "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json").write_text(
    json.dumps(marker, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
V61ET_REFRESH_SOURCES=0 \
V61ET_RUN_ID="real_marker_forged_fixture_v61et" \
V61ET_RETURN_BUNDLE_DIR="$FORGED_MARKER_BUNDLE_DIR" \
V61ET_RETURN_BUNDLE_PROVENANCE="real-generation-intake-return-bundle" \
V61ET_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

V61ET_REFRESH_SOURCES=0 \
V61ET_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SPOOF_RUN_DIR" "$FORGED_MARKER_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
spoof_run_dir = Path(sys.argv[3])
forged_marker_run_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])


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
    "v61et_real_generation_intake_return_bundle_preflight_ready": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "selected_bundle_source_class": "none",
    "return_bundle_provenance_env_real": "0",
    "return_bundle_marker_supplied": "0",
    "return_bundle_marker_real_provenance": "0",
    "return_bundle_marker_errors": "missing-provenance-marker",
    "required_return_bundle_files": "11",
    "present_return_bundle_files": "0",
    "return_bundle_family_rows": "4",
    "ready_return_bundle_family_rows": "0",
    "template_named_return_bundle_files": "0",
    "payload_like_return_bundle_files": "0",
    "return_bundle_candidate_preflight_ready": "0",
    "non_fixture_return_bundle": "0",
    "real_return_bundle_provenance_asserted": "0",
    "real_return_bundle_preflight_ready": "0",
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61et": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61et {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_intake_return_bundle_file_rows.csv",
    "real_generation_intake_return_bundle_family_rows.csv",
    "real_generation_intake_return_bundle_requirement_rows.csv",
    "real_generation_intake_return_bundle_command_rows.csv",
    "runtime_gap_rows.csv",
    "V61ET_REAL_GENERATION_INTAKE_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md",
    "v61et_real_generation_intake_return_bundle_preflight_manifest.json",
    "source_summaries/v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv",
    "source_contracts/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv",
    "source_contracts/PREREQUISITE_BINDING_CONTRACT.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61et artifact: {rel}")

files = read_csv(run_dir / "real_generation_intake_return_bundle_file_rows.csv")
if len(files) != 11 or any(row["file_exists"] != "0" for row in files):
    raise SystemExit("v61et canonical file rows should show 0/11 present")

fixture_requirements = {
    row["requirement_id"]: row
    for row in read_csv(fixture_run_dir / "real_generation_intake_return_bundle_requirement_rows.csv")
}
for req in [
    "return-bundle-dir-supplied",
    "return-bundle-dir-exists",
    "required-files-present",
    "family-preflight-ready",
    "no-template-names",
    "no-payload-like-files",
    "return-bundle-candidate-preflight",
]:
    if fixture_requirements[req]["status"] != "pass":
        raise SystemExit(f"v61et fixture requirement should pass: {req}")
for req in [
    "non-fixture-return-bundle",
    "real-return-bundle-provenance",
    "real-return-bundle-preflight",
    "downstream-row-acceptance",
    "actual-generation",
]:
    if fixture_requirements[req]["status"] != "blocked":
        raise SystemExit(f"v61et fixture requirement should stay blocked: {req}")
if "fixture-source-class" not in fixture_requirements["real-return-bundle-provenance"]["actual_value"]:
    raise SystemExit("v61et fixture marker errors must expose fixture-source-class")
if "authority-file-fixture-text" not in fixture_requirements["real-return-bundle-provenance"]["actual_value"]:
    raise SystemExit("v61et fixture marker errors must expose authority-file-fixture-text")

spoof_requirements = {
    row["requirement_id"]: row
    for row in read_csv(spoof_run_dir / "real_generation_intake_return_bundle_requirement_rows.csv")
}
if spoof_requirements["return-bundle-candidate-preflight"]["status"] != "pass":
    raise SystemExit("v61et copied fixture spoof must pass only the mechanical bundle preflight")
for req in [
    "non-fixture-return-bundle",
    "real-return-bundle-provenance",
    "real-return-bundle-preflight",
]:
    if spoof_requirements[req]["status"] != "blocked":
        raise SystemExit(f"v61et copied fixture spoof must stay blocked: {req}")
spoof_provenance = spoof_requirements["real-return-bundle-provenance"]["actual_value"]
if "env=real-generation-intake-return-bundle" not in spoof_provenance or "fixture-source-class" not in spoof_provenance:
    raise SystemExit("v61et spoof must prove env-real cannot override fixture marker provenance")
spoof_manifest = json.loads((spoof_run_dir / "v61et_real_generation_intake_return_bundle_preflight_manifest.json").read_text(encoding="utf-8"))
if spoof_manifest.get("return_bundle_marker_real_provenance") != 0:
    raise SystemExit("v61et copied fixture spoof marker must remain non-real")
if spoof_manifest.get("real_return_bundle_preflight_ready") != 0:
    raise SystemExit("v61et copied fixture spoof must not become real-ready")

forged_marker_requirements = {
    row["requirement_id"]: row
    for row in read_csv(forged_marker_run_dir / "real_generation_intake_return_bundle_requirement_rows.csv")
}
if forged_marker_requirements["return-bundle-candidate-preflight"]["status"] != "pass":
    raise SystemExit("v61et forged-marker fixture must pass mechanical bundle preflight")
if forged_marker_requirements["non-fixture-return-bundle"]["status"] != "pass":
    raise SystemExit("v61et forged-marker fixture should isolate authority binding from source-class checks")
if forged_marker_requirements["real-return-bundle-provenance"]["status"] != "blocked":
    raise SystemExit("v61et forged-marker fixture must reject self-asserted real marker")
if "authority-file-fixture-text" not in forged_marker_requirements["real-return-bundle-provenance"]["actual_value"]:
    raise SystemExit("v61et forged-marker fixture must record fixture authority text rejection")
if forged_marker_requirements["real-return-bundle-preflight"]["status"] != "blocked":
    raise SystemExit("v61et forged-marker fixture must keep real bundle preflight blocked")
forged_marker_manifest = json.loads((forged_marker_run_dir / "v61et_real_generation_intake_return_bundle_preflight_manifest.json").read_text(encoding="utf-8"))
if forged_marker_manifest.get("return_bundle_marker_real_provenance") != 0:
    raise SystemExit("v61et forged-marker fixture marker must remain non-real")
if "authority-file-fixture-text" not in forged_marker_manifest.get("return_bundle_marker_errors", []):
    raise SystemExit("v61et forged-marker fixture manifest missing authority fixture rejection")

fixture_metric = read_csv(fixture_run_dir / "sha256_manifest.csv")
if not fixture_metric:
    raise SystemExit("v61et fixture did not produce hash rows")
fixture_selected = fixture_run_dir / "selected_return_bundle"
for rel in [
    "dispatch_receipt/DISPATCH_RECEIPT.json",
    "generation_result_return/real_model_generation_answer_rows.csv",
    "prerequisite_binding/v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json",
    "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt",
]:
    if not (fixture_selected / rel).is_file():
        raise SystemExit(f"v61et fixture did not copy selected bundle file: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61et repo payload decision should pass")
for gate in [
    "return-bundle-candidate-preflight",
    "non-fixture-return-bundle",
    "real-return-bundle-provenance",
    "real-return-bundle-preflight",
    "downstream-row-acceptance",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61et canonical decision should be blocked: {gate}")

boundary = (run_dir / "V61ET_REAL_GENERATION_INTAKE_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_bundle_dir_supplied=0",
    "present_return_bundle_files=0/11",
    "return_bundle_candidate_preflight_ready=0",
    "return_bundle_marker_real_provenance=0",
    "return_bundle_marker_errors=missing-provenance-marker",
    "real_return_bundle_preflight_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61et boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61et_real_generation_intake_return_bundle_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61et_real_generation_intake_return_bundle_preflight_ready") != 1:
    raise SystemExit("v61et manifest readiness mismatch")
if manifest.get("return_bundle_marker_real_provenance") != 0:
    raise SystemExit("v61et canonical manifest marker provenance must stay blocked")
if manifest.get("real_return_bundle_preflight_ready") != 0:
    raise SystemExit("v61et canonical manifest must keep real bundle blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61et manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61et sha256 mismatch: {rel}")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61et produced model/checkpoint payload-like files" >&2
  exit 1
fi

rm -rf "$TMP_DIR"

echo "v61et real generation intake return bundle preflight smoke passed"
