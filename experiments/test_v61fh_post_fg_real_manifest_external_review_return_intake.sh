#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fh_post_fg_real_manifest_external_review_return_intake"
RUN_DIR="$RESULTS_DIR/$PREFIX/intake_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_intake_v61fh"
FIXTURE_RETURN_DIR="$RESULTS_DIR/$PREFIX/fixture_review_return"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
INTAKE_DIR="$RUN_DIR/real_manifest_external_review_return_intake"

V61FH_REUSE_EXISTING="${V61FH_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$FIXTURE_RETURN_DIR" <<'PY_FIXTURE'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
fixture_dir = Path(sys.argv[2])
if fixture_dir.exists():
    shutil.rmtree(fixture_dir)
fixture_dir.mkdir(parents=True)
results = root / "results"
v61fg_dir = results / "v61fg_post_ff_real_manifest_external_review_packet" / "packet_001"
checklist = list(csv.DictReader((v61fg_dir / "post_ff_real_manifest_external_review_checklist_rows.csv").open(newline="", encoding="utf-8")))
claims = list(csv.DictReader((v61fg_dir / "post_ff_real_manifest_external_review_claim_rows.csv").open(newline="", encoding="utf-8")))

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

now = datetime.now(timezone.utc).isoformat()
(fixture_dir / "REAL_MANIFEST_REVIEWER_IDENTITY.json").write_text(json.dumps({
    "reviewer_id": "fixture-reviewer-v61fh",
    "reviewer_role": "fixture-local-preflight",
    "independence_declaration": "fixture-only-not-real-external-review",
    "conflict_disclosure": "fixture-only",
    "review_timestamp_utc": now,
    "review_packet_sha256": sha(v61fg_dir / "v61fg_post_ff_real_manifest_external_review_packet_manifest.json"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (fixture_dir / "REAL_MANIFEST_REVIEW_CHECKLIST.csv").open("w", newline="", encoding="utf-8") as handle:
    fields = ["review_item_id", "review_status", "reviewer_note", "source_gate_verified", "boundary_respected"]
    writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    for row in checklist:
        writer.writerow({
            "review_item_id": row["review_item_id"],
            "review_status": "accepted-with-boundary" if row["status"] == "ready" else "blocked",
            "reviewer_note": "fixture preflight mirrors v61fg boundary",
            "source_gate_verified": "1",
            "boundary_respected": "1",
        })

with (fixture_dir / "REAL_MANIFEST_CLAIM_BOUNDARY_REVIEW.csv").open("w", newline="", encoding="utf-8") as handle:
    fields = ["claim", "review_status", "boundary_accepted", "reviewer_note"]
    writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    for row in claims:
        writer.writerow({
            "claim": row["claim"],
            "review_status": "accepted-with-boundary" if row["status"] != "blocked" else "blocked",
            "boundary_accepted": "1",
            "reviewer_note": "fixture preflight preserves claim boundary",
        })

(fixture_dir / "REAL_MANIFEST_REPRODUCTION_RECEIPT.json").write_text(json.dumps({
    "reproduction_command": "V61FG_REUSE_EXISTING=1 ./experiments/test_v61fg_post_ff_real_manifest_external_review_packet.sh",
    "reproduction_status": "passed",
    "v61fg_summary_sha256": sha(results / "v61fg_post_ff_real_manifest_external_review_packet_summary.csv"),
    "v61ff_summary_sha256": sha(results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv"),
    "verifier_exit_code": 0,
    "review_timestamp_utc": now,
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(fixture_dir / "ZERO_PAYLOAD_ATTESTATION.json").write_text(json.dumps({
    "checkpoint_payload_bytes_observed": 0,
    "payload_like_files_observed": 0,
    "zero_payload_attested": 1,
    "attestation_timestamp_utc": now,
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(fixture_dir / "REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_SUMMARY.json").write_text(json.dumps({
    "external_review_decision": "fixture-preflight-accepted-with-boundaries",
    "accepted_review_items": len(checklist),
    "blocked_review_items": sum(1 for row in checklist if row["status"] == "blocked"),
    "accepted_claim_boundaries": len(claims),
    "actual_generation_claim_accepted": 0,
    "release_claim_accepted": 0,
    "review_timestamp_utc": now,
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY_FIXTURE

V61FH_RUN_ID="fixture_intake_v61fh" \
V61FH_EXTERNAL_REVIEW_RETURN_DIR="$FIXTURE_RETURN_DIR" \
V61FH_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null

V61FH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$INTAKE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
fixture_run_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
intake_dir = Path(sys.argv[6])


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
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": "1",
    "v61fg_post_ff_real_manifest_external_review_packet_ready": "1",
    "review_return_dir_supplied": "0",
    "review_return_dir_exists": "0",
    "required_review_return_artifacts": "6",
    "supplied_review_return_artifacts": "0",
    "accepted_review_return_artifacts": "0",
    "missing_review_return_artifacts": "6",
    "invalid_review_return_artifacts": "0",
    "review_checklist_rows": "13",
    "accepted_review_checklist_rows": "0",
    "claim_boundary_rows": "5",
    "accepted_claim_boundary_rows": "0",
    "acceptance_rows": "4",
    "candidate_external_review_return_ready": "0",
    "external_review_return_ready": "0",
    "review_return_intake_file_rows": "8",
    "metadata_only_review_return_intake_file_rows": "8",
    "page_manifest_external_review_packet_ready": "1",
    "real_manifest_runtime_evidence_review_ready": "1",
    "real_return_replay_admission_ready": "0",
    "row_acceptance_ready": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "accepted_generation_result_artifacts": "0",
    "expected_generation_result_artifacts": "5",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fh {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_manifest_external_review_required_artifact_rows.csv",
    "real_manifest_external_review_return_artifact_status_rows.csv",
    "real_manifest_external_review_return_acceptance_rows.csv",
    "real_manifest_external_review_return_requirement_rows.csv",
    "runtime_gap_rows.csv",
    "V61FH_POST_FG_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_INTAKE_BOUNDARY.md",
    "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json",
    "real_manifest_external_review_return_intake/REQUIRED_REVIEW_RETURN_ARTIFACTS.csv",
    "real_manifest_external_review_return_intake/REVIEW_RETURN_SCHEMA_ROWS.csv",
    "real_manifest_external_review_return_intake/REVIEW_RETURN_ENV_TEMPLATE.sh",
    "real_manifest_external_review_return_intake/REVIEW_RETURN_INTAKE.md",
    "real_manifest_external_review_return_intake/VERIFY_REVIEW_RETURN_INTAKE.sh",
    "real_manifest_external_review_return_intake/INTAKE_MANIFEST.json",
    "real_manifest_external_review_return_intake/INTAKE_FILE_LIST.txt",
    "real_manifest_external_review_return_intake/INTAKE_SHA256SUMS.txt",
    "source_v61fg/v61fg_post_ff_real_manifest_external_review_packet_summary.csv",
    "source_v61fg/post_ff_real_manifest_external_review_checklist_rows.csv",
    "source_v61fg/post_ff_real_manifest_external_review_claim_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fh artifact: {rel}")

artifact_rows = read_csv(run_dir / "real_manifest_external_review_return_artifact_status_rows.csv")
if len(artifact_rows) != 6:
    raise SystemExit("v61fh expected six artifact rows")
if any(row["artifact_status"] != "missing" for row in artifact_rows):
    raise SystemExit("v61fh default path should mark artifacts missing")
if any(row["counts_as_external_review_return"] != "0" for row in artifact_rows):
    raise SystemExit("v61fh artifacts must not count as real external review by default")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "real_manifest_external_review_return_requirement_rows.csv")}
if requirements["v61fg-review-packet-input"] != "pass":
    raise SystemExit("v61fh should bind v61fg packet input")
for requirement_id in [
    "external-review-return-dir-supplied",
    "review-return-artifact-preflight",
    "external-review-return-ready",
    "actual-generation",
]:
    if requirements[requirement_id] != "blocked":
        raise SystemExit(f"v61fh requirement should stay blocked: {requirement_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["v61fg-review-packet-input"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61fh packet/repo gates should pass")
for gate in [
    "external-review-return-directory",
    "review-return-artifact-preflight",
    "candidate-external-review-return",
    "real-external-review-return",
    "actual-model-generation",
]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61fh default decision should stay blocked: {gate}")

fixture_summary = read_csv(root / "results/v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv")[0]
if fixture_summary["review_return_dir_supplied"] != "0":
    raise SystemExit("v61fh did not restore canonical no-return summary")
fixture_metric = read_csv(fixture_run_dir / "real_manifest_external_review_return_artifact_status_rows.csv")
if len(fixture_metric) != 6:
    raise SystemExit("v61fh fixture expected six artifact rows")
if any(row["artifact_preflight_pass"] != "1" for row in fixture_metric):
    raise SystemExit("v61fh fixture artifacts should pass preflight")
fixture_run_manifest = json.loads((fixture_run_dir / "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json").read_text(encoding="utf-8"))
if fixture_run_manifest.get("candidate_external_review_return_ready") != 1:
    raise SystemExit("v61fh fixture should open candidate review return readiness")
if fixture_run_manifest.get("external_review_return_ready") != 0:
    raise SystemExit("v61fh fixture must not certify real external review")
if fixture_run_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fh fixture must keep actual generation blocked")

boundary = (run_dir / "V61FH_POST_FG_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "review_return_dir_supplied=0",
    "review_return_dir_exists=0",
    "required_review_return_artifacts=6",
    "supplied_review_return_artifacts=0",
    "accepted_review_return_artifacts=0",
    "missing_review_return_artifacts=6",
    "candidate_external_review_return_ready=0",
    "external_review_return_ready=0",
    "real_return_replay_admission_ready=0",
    "row_acceptance_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fh boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fh_post_fg_real_manifest_external_review_return_intake_manifest.json").read_text(encoding="utf-8"))
for key in ["candidate_external_review_return_ready", "external_review_return_ready", "actual_model_generation_ready", "checkpoint_payload_bytes_committed_to_repo"]:
    if manifest.get(key) != 0:
        raise SystemExit(f"v61fh canonical manifest must keep {key}=0")

for script_name in ["VERIFY_REVIEW_RETURN_INTAKE.sh", "REVIEW_RETURN_ENV_TEMPLATE.sh"]:
    if not os.access(intake_dir / script_name, os.X_OK):
        raise SystemExit(f"v61fh script must be executable: {script_name}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fh sha256 mismatch: {rel}")
PY

"$INTAKE_DIR/VERIFY_REVIEW_RETURN_INTAKE.sh" >/dev/null

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fh produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fh post-fg real manifest external review return intake smoke passed"
