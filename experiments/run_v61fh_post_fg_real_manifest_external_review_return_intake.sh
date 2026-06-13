#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fh_post_fg_real_manifest_external_review_return_intake"
RUN_ID="${V61FH_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_DIR_ARG="${V61FH_EXTERNAL_REVIEW_RETURN_DIR:-}"

if [[ "${V61FH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fh_post_fg_real_manifest_external_review_return_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fg_post_ff_real_manifest_external_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_DIR_ARG" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
return_dir_arg = sys.argv[5].strip()
return_dir = Path(return_dir_arg).expanduser().resolve() if return_dir_arg else None
results = root / "results"
intake_dir = run_dir / "real_manifest_external_review_return_intake"
intake_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


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


def status(flag):
    return "pass" if flag else "blocked"


v61fg_summary_path = results / "v61fg_post_ff_real_manifest_external_review_packet_summary.csv"
v61fg_decision_path = results / "v61fg_post_ff_real_manifest_external_review_packet_decision.csv"
v61fg_dir = results / "v61fg_post_ff_real_manifest_external_review_packet" / "packet_001"
for src, rel in [
    (v61fg_summary_path, "source_v61fg/v61fg_post_ff_real_manifest_external_review_packet_summary.csv"),
    (v61fg_decision_path, "source_v61fg/v61fg_post_ff_real_manifest_external_review_packet_decision.csv"),
    (v61fg_dir / "post_ff_real_manifest_external_review_checklist_rows.csv", "source_v61fg/post_ff_real_manifest_external_review_checklist_rows.csv"),
    (v61fg_dir / "post_ff_real_manifest_external_review_claim_rows.csv", "source_v61fg/post_ff_real_manifest_external_review_claim_rows.csv"),
    (v61fg_dir / "real_manifest_external_review_packet/REVIEW_PACKET_MANIFEST.json", "source_v61fg/REVIEW_PACKET_MANIFEST.json"),
    (v61fg_dir / "real_manifest_external_review_packet/REVIEW_PACKET_SHA256SUMS.txt", "source_v61fg/REVIEW_PACKET_SHA256SUMS.txt"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61fh source artifact: {src}")
    copy(src, rel)

v61fg = read_csv(v61fg_summary_path)[0]
if v61fg.get("v61fg_post_ff_real_manifest_external_review_packet_ready") != "1":
    raise SystemExit("v61fh requires v61fg_post_ff_real_manifest_external_review_packet_ready=1")

checklist_rows = read_csv(v61fg_dir / "post_ff_real_manifest_external_review_checklist_rows.csv")
claim_rows = read_csv(v61fg_dir / "post_ff_real_manifest_external_review_claim_rows.csv")
packet_manifest = json.loads((v61fg_dir / "real_manifest_external_review_packet/REVIEW_PACKET_MANIFEST.json").read_text(encoding="utf-8"))

required_artifacts = [
    {
        "artifact_id": "reviewer_identity",
        "relative_path": "REAL_MANIFEST_REVIEWER_IDENTITY.json",
        "artifact_type": "json",
        "required_rows": "1",
        "required_fields": "reviewer_id;reviewer_role;independence_declaration;conflict_disclosure;review_timestamp_utc;review_packet_sha256",
    },
    {
        "artifact_id": "review_checklist",
        "relative_path": "REAL_MANIFEST_REVIEW_CHECKLIST.csv",
        "artifact_type": "csv",
        "required_rows": str(len(checklist_rows)),
        "required_fields": "review_item_id;review_status;reviewer_note;source_gate_verified;boundary_respected",
    },
    {
        "artifact_id": "claim_boundary_review",
        "relative_path": "REAL_MANIFEST_CLAIM_BOUNDARY_REVIEW.csv",
        "artifact_type": "csv",
        "required_rows": str(len(claim_rows)),
        "required_fields": "claim;review_status;boundary_accepted;reviewer_note",
    },
    {
        "artifact_id": "reproduction_receipt",
        "relative_path": "REAL_MANIFEST_REPRODUCTION_RECEIPT.json",
        "artifact_type": "json",
        "required_rows": "1",
        "required_fields": "reproduction_command;reproduction_status;v61fg_summary_sha256;v61ff_summary_sha256;verifier_exit_code;review_timestamp_utc",
    },
    {
        "artifact_id": "zero_payload_attestation",
        "relative_path": "ZERO_PAYLOAD_ATTESTATION.json",
        "artifact_type": "json",
        "required_rows": "1",
        "required_fields": "checkpoint_payload_bytes_observed;payload_like_files_observed;zero_payload_attested;attestation_timestamp_utc",
    },
    {
        "artifact_id": "acceptance_summary",
        "relative_path": "REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_SUMMARY.json",
        "artifact_type": "json",
        "required_rows": "1",
        "required_fields": "external_review_decision;accepted_review_items;blocked_review_items;accepted_claim_boundaries;actual_generation_claim_accepted;release_claim_accepted;review_timestamp_utc",
    },
]
write_csv(run_dir / "real_manifest_external_review_required_artifact_rows.csv", list(required_artifacts[0].keys()), required_artifacts)
write_csv(intake_dir / "REQUIRED_REVIEW_RETURN_ARTIFACTS.csv", list(required_artifacts[0].keys()), required_artifacts)

return_dir_supplied = int(return_dir is not None)
return_dir_exists = int(return_dir is not None and return_dir.is_dir())
artifact_status_rows = []
accepted_artifacts = 0
supplied_artifacts = 0
missing_artifacts = 0
invalid_artifacts = 0
accepted_review_items = 0
blocked_review_items = len([row for row in checklist_rows if row["status"] == "blocked"])
accepted_claim_boundaries = 0
external_review_decision = ""

expected_checklist_ids = {row["review_item_id"] for row in checklist_rows}
expected_claims = {row["claim"] for row in claim_rows}

for artifact in required_artifacts:
    rel = artifact["relative_path"]
    path = return_dir / rel if return_dir else None
    supplied = int(path is not None and path.is_file())
    supplied_artifacts += supplied
    missing_artifacts += int(not supplied)
    errors = []
    observed_rows = 0
    digest = sha256(path) if supplied else ""
    if supplied:
        if artifact["artifact_type"] == "csv":
            try:
                rows = read_csv(path)
                observed_rows = len(rows)
                fields = set(rows[0].keys()) if rows else set()
            except Exception:
                rows = []
                fields = set()
                errors.append("csv-read-error")
            required_fields = set(artifact["required_fields"].split(";"))
            missing_fields = sorted(required_fields - fields)
            if missing_fields:
                errors.append("missing-fields:" + ";".join(missing_fields))
            if observed_rows != int(artifact["required_rows"]):
                errors.append(f"row-count-mismatch:{observed_rows}")
            if artifact["artifact_id"] == "review_checklist":
                row_ids = {row.get("review_item_id", "") for row in rows}
                if row_ids != expected_checklist_ids:
                    errors.append("review-item-id-set-mismatch")
                accepted_review_items = sum(
                    1
                    for row in rows
                    if row.get("review_status") in {"accepted", "accepted-with-boundary"}
                    and row.get("source_gate_verified") == "1"
                    and row.get("boundary_respected") == "1"
                )
            if artifact["artifact_id"] == "claim_boundary_review":
                row_claims = {row.get("claim", "") for row in rows}
                if row_claims != expected_claims:
                    errors.append("claim-set-mismatch")
                accepted_claim_boundaries = sum(
                    1
                    for row in rows
                    if row.get("review_status") in {"accepted", "accepted-with-boundary"}
                    and row.get("boundary_accepted") == "1"
                )
        else:
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                observed_rows = 1
            except Exception:
                data = {}
                errors.append("json-read-error")
            required_fields = set(artifact["required_fields"].split(";"))
            missing_fields = sorted(field for field in required_fields if field not in data)
            if missing_fields:
                errors.append("missing-fields:" + ";".join(missing_fields))
            if artifact["artifact_id"] == "zero_payload_attestation":
                if str(data.get("checkpoint_payload_bytes_observed")) != "0":
                    errors.append("checkpoint-payload-observed")
                if str(data.get("payload_like_files_observed")) != "0":
                    errors.append("payload-like-files-observed")
                if data.get("zero_payload_attested") != 1:
                    errors.append("zero-payload-not-attested")
            if artifact["artifact_id"] == "reproduction_receipt":
                if str(data.get("verifier_exit_code")) != "0":
                    errors.append("verifier-exit-code-not-zero")
                if data.get("reproduction_status") != "passed":
                    errors.append("reproduction-status-not-passed")
            if artifact["artifact_id"] == "acceptance_summary":
                external_review_decision = str(data.get("external_review_decision", ""))
                if data.get("actual_generation_claim_accepted") != 0:
                    errors.append("actual-generation-claim-accepted")
                if data.get("release_claim_accepted") != 0:
                    errors.append("release-claim-accepted")
        copy(path, f"supplied_external_review_return/{rel}")
    passed = int(supplied and not errors)
    accepted_artifacts += passed
    invalid_artifacts += int(supplied and bool(errors))
    artifact_status_rows.append(
        {
            "artifact_id": artifact["artifact_id"],
            "relative_path": rel,
            "artifact_supplied": str(supplied),
            "artifact_preflight_pass": str(passed),
            "artifact_status": "pass" if passed else "missing" if not supplied else "invalid",
            "expected_rows": artifact["required_rows"],
            "observed_rows": str(observed_rows),
            "sha256": digest,
            "validation_errors": ";".join(errors),
            "counts_as_external_review_return": "0",
            "actual_model_generation_ready": "0",
        }
    )

write_csv(run_dir / "real_manifest_external_review_return_artifact_status_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)

all_artifacts_pass = int(accepted_artifacts == len(required_artifacts) and invalid_artifacts == 0)
candidate_external_review_return_ready = all_artifacts_pass
external_review_return_ready = 0

acceptance_rows = [
    {
        "acceptance_id": "review-return-artifact-preflight",
        "status": "ready" if all_artifacts_pass else "blocked",
        "observed": f"accepted_review_return_artifacts={accepted_artifacts}/{len(required_artifacts)}",
        "counts_as_real_external_review": "0",
    },
    {
        "acceptance_id": "review-checklist-coverage",
        "status": "ready" if accepted_review_items == len(checklist_rows) else "blocked",
        "observed": f"accepted_review_items={accepted_review_items}/{len(checklist_rows)}",
        "counts_as_real_external_review": "0",
    },
    {
        "acceptance_id": "claim-boundary-coverage",
        "status": "ready" if accepted_claim_boundaries == len(claim_rows) else "blocked",
        "observed": f"accepted_claim_boundaries={accepted_claim_boundaries}/{len(claim_rows)}",
        "counts_as_real_external_review": "0",
    },
    {
        "acceptance_id": "external-review-return-ready",
        "status": "blocked",
        "observed": f"external_review_decision={external_review_decision or 'missing'}",
        "counts_as_real_external_review": "0",
    },
]
write_csv(run_dir / "real_manifest_external_review_return_acceptance_rows.csv", list(acceptance_rows[0].keys()), acceptance_rows)

requirement_rows = [
    {"requirement_id": "v61fg-review-packet-input", "status": "pass", "required_value": "1", "actual_value": v61fg["v61fg_post_ff_real_manifest_external_review_packet_ready"], "reason": "v61fg review packet is ready"},
    {"requirement_id": "external-review-return-dir-supplied", "status": status(return_dir_exists), "required_value": "existing return directory", "actual_value": str(return_dir) if return_dir else "", "reason": "external review return directory is required for intake"},
    {"requirement_id": "review-return-artifact-preflight", "status": status(all_artifacts_pass), "required_value": str(len(required_artifacts)), "actual_value": str(accepted_artifacts), "reason": "all review return artifacts must validate"},
    {"requirement_id": "external-review-return-ready", "status": "blocked", "required_value": "accepted real external review", "actual_value": str(external_review_return_ready), "reason": "v61fh preflights return shape but does not certify external review"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains gated by replay, row acceptance, execution admission, and result acceptance"},
]
write_csv(run_dir / "real_manifest_external_review_return_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "external-review-return-artifact-preflight", "status": "ready" if all_artifacts_pass else "blocked", "reason": f"accepted_review_return_artifacts={accepted_artifacts}/{len(required_artifacts)}"},
    {"gap": "candidate-external-review-return", "status": "ready" if candidate_external_review_return_ready else "blocked", "reason": f"candidate_external_review_return_ready={candidate_external_review_return_ready}"},
    {"gap": "real-external-review-return", "status": "blocked", "reason": "v61fh does not certify non-fixture reviewer authority"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gap": "real-release-package", "status": "blocked", "reason": "release audit is not present"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

schema_rows = [
    {"schema_id": artifact["artifact_id"], "relative_path": artifact["relative_path"], "artifact_type": artifact["artifact_type"], "required_fields": artifact["required_fields"], "required_rows": artifact["required_rows"]}
    for artifact in required_artifacts
]
write_csv(intake_dir / "REVIEW_RETURN_SCHEMA_ROWS.csv", list(schema_rows[0].keys()), schema_rows)

env_template = intake_dir / "REVIEW_RETURN_ENV_TEMPLATE.sh"
env_template.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "export V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/real_manifest_external_review_return",
            "./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(env_template, 0o755)

summary_md = intake_dir / "REVIEW_RETURN_INTAKE.md"
summary_md.write_text(
    "\n".join(
        [
            "# v61fh Real Manifest External Review Return Intake",
            "",
            "This intake checks the return shape for the v61fg reviewer packet.",
            "It can establish candidate preflight readiness for returned artifacts,",
            "but it does not certify real external reviewer authority or actual generation.",
            "",
            f"- required_review_return_artifacts={len(required_artifacts)}",
            f"- supplied_review_return_artifacts={supplied_artifacts}",
            f"- accepted_review_return_artifacts={accepted_artifacts}",
            f"- candidate_external_review_return_ready={candidate_external_review_return_ready}",
            "- external_review_return_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = intake_dir / "VERIFY_REVIEW_RETURN_INTAKE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import hashlib",
            "import json",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'INTAKE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'INTAKE_MANIFEST.json').read_text(encoding='utf-8'))",
            "schema_rows = list(csv.DictReader((root / 'REVIEW_RETURN_SCHEMA_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(schema_rows) != manifest['required_review_return_artifacts']:",
            "    raise SystemExit('schema row count mismatch')",
            "if manifest['external_review_return_ready'] != 0:",
            "    raise SystemExit('real external review return must remain blocked')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "if manifest['checkpoint_payload_bytes_committed_to_repo'] != 0:",
            "    raise SystemExit('checkpoint payload must remain zero')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

intake_manifest = {
    "manifest_scope": "v61fh-post-fg-real-manifest-external-review-return-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "required_review_return_artifacts": len(required_artifacts),
    "supplied_review_return_artifacts": supplied_artifacts,
    "accepted_review_return_artifacts": accepted_artifacts,
    "candidate_external_review_return_ready": candidate_external_review_return_ready,
    "external_review_return_ready": external_review_return_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(intake_dir / "INTAKE_MANIFEST.json").write_text(json.dumps(intake_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

intake_files_for_list = sorted(
    path
    for path in intake_dir.rglob("*")
    if path.is_file() and path.name not in {"INTAKE_FILE_LIST.txt", "INTAKE_SHA256SUMS.txt"}
)
(intake_dir / "INTAKE_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(intake_dir)) for path in intake_files_for_list) + "\n",
    encoding="utf-8",
)
intake_files_for_hash = sorted(path for path in intake_dir.rglob("*") if path.is_file() and path.name != "INTAKE_SHA256SUMS.txt")
(intake_dir / "INTAKE_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(intake_dir)}\n" for path in intake_files_for_hash),
    encoding="utf-8",
)

intake_file_rows = sum(1 for path in intake_dir.rglob("*") if path.is_file())
summary = {
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fg_post_ff_real_manifest_external_review_packet_ready": v61fg["v61fg_post_ff_real_manifest_external_review_packet_ready"],
    "review_return_dir_supplied": str(return_dir_supplied),
    "review_return_dir_exists": str(return_dir_exists),
    "required_review_return_artifacts": str(len(required_artifacts)),
    "supplied_review_return_artifacts": str(supplied_artifacts),
    "accepted_review_return_artifacts": str(accepted_artifacts),
    "missing_review_return_artifacts": str(missing_artifacts),
    "invalid_review_return_artifacts": str(invalid_artifacts),
    "review_checklist_rows": str(len(checklist_rows)),
    "accepted_review_checklist_rows": str(accepted_review_items),
    "claim_boundary_rows": str(len(claim_rows)),
    "accepted_claim_boundary_rows": str(accepted_claim_boundaries),
    "acceptance_rows": str(len(acceptance_rows)),
    "candidate_external_review_return_ready": str(candidate_external_review_return_ready),
    "external_review_return_ready": str(external_review_return_ready),
    "review_return_intake_file_rows": str(intake_file_rows),
    "metadata_only_review_return_intake_file_rows": str(intake_file_rows),
    "page_manifest_external_review_packet_ready": v61fg["page_manifest_external_review_packet_ready"],
    "real_manifest_runtime_evidence_review_ready": v61fg["real_manifest_runtime_evidence_review_ready"],
    "real_return_replay_admission_ready": v61fg["real_return_replay_admission_ready"],
    "row_acceptance_ready": v61fg["row_acceptance_ready"],
    "generation_execution_admitted_rows": v61fg["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61fg["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61fg["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61fg["expected_generation_result_artifacts"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61fg-review-packet-input", "status": "pass", "reason": "v61fg review packet is ready"},
    {"gate": "external-review-return-directory", "status": status(return_dir_exists), "reason": f"review_return_dir_exists={return_dir_exists}"},
    {"gate": "review-return-artifact-preflight", "status": status(all_artifacts_pass), "reason": f"accepted_review_return_artifacts={accepted_artifacts}/{len(required_artifacts)}"},
    {"gate": "candidate-external-review-return", "status": status(candidate_external_review_return_ready), "reason": f"candidate_external_review_return_ready={candidate_external_review_return_ready}"},
    {"gate": "real-external-review-return", "status": "blocked", "reason": "v61fh does not certify reviewer authority"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only intake files"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FH_POST_FG_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_INTAKE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fh Post-v61fg Real Manifest External Review Return Intake Boundary",
            "",
            f"- review_return_dir_supplied={summary['review_return_dir_supplied']}",
            f"- review_return_dir_exists={summary['review_return_dir_exists']}",
            f"- required_review_return_artifacts={summary['required_review_return_artifacts']}",
            f"- supplied_review_return_artifacts={summary['supplied_review_return_artifacts']}",
            f"- accepted_review_return_artifacts={summary['accepted_review_return_artifacts']}",
            f"- missing_review_return_artifacts={summary['missing_review_return_artifacts']}",
            f"- invalid_review_return_artifacts={summary['invalid_review_return_artifacts']}",
            f"- accepted_review_checklist_rows={summary['accepted_review_checklist_rows']}/{summary['review_checklist_rows']}",
            f"- accepted_claim_boundary_rows={summary['accepted_claim_boundary_rows']}/{summary['claim_boundary_rows']}",
            f"- candidate_external_review_return_ready={summary['candidate_external_review_return_ready']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fh defines and preflights the v61fg external review return shape.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, row acceptance, actual generation, production latency, near-frontier quality, or release readiness from v61fh alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fh_post_fg_real_manifest_external_review_return_intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fh_post_fg_real_manifest_external_review_return_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
