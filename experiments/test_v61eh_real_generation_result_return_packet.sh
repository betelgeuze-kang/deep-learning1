#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eh_real_generation_result_return_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EH_REUSE_EXISTING="${V61EH_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61eh_real_generation_result_return_packet.sh" >/dev/null

"$RUN_DIR/real_generation_result_return_packet/VERIFY_REAL_GENERATION_RETURN_PACKET.sh" >/dev/null

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


summary = read_csv(summary_csv)[0]
expected = {
    "v61eh_real_generation_result_return_packet_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "v61eg_generation_result_prereq_binding_fixture_gate_ready": "1",
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": "1",
    "real_manifest_runtime_evidence_ready": "1",
    "fixture_prerequisite_binding_ready": "1",
    "fixture_accepted_generation_result_artifacts": "5",
    "fixture_generation_result_accepted_rows": "1000",
    "real_prerequisite_binding_ready": "0",
    "real_review_return_ready": "0",
    "real_generation_execution_admission_ready": "0",
    "generation_execution_admitted_rows": "0",
    "generation_execution_admission_rows": "1000",
    "expected_generation_result_artifacts": "5",
    "accepted_generation_result_artifacts": "0",
    "real_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "expected_generation_rows": "1000",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "packet_stage_rows": "7",
    "ready_packet_stage_rows": "2",
    "blocked_packet_stage_rows": "5",
    "required_generation_result_artifact_rows": "5",
    "required_generation_result_field_rows": "42",
    "prerequisite_binding_contract_rows": "5",
    "packet_command_rows": "5",
    "ready_packet_command_rows": "1",
    "packet_file_rows": "7",
    "metadata_only_packet_file_rows": "7",
    "packet_invariant_rows": "6",
    "packet_invariant_pass_rows": "6",
    "checkpoint_payload_bytes_downloaded_by_v61eh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61eh {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_required_artifact_rows.csv",
    "real_prerequisite_binding_contract_rows.csv",
    "real_generation_result_return_packet_stage_rows.csv",
    "real_generation_result_return_packet_command_rows.csv",
    "real_generation_result_return_packet_file_rows.csv",
    "real_generation_result_return_packet_invariant_rows.csv",
    "V61EH_REAL_GENERATION_RESULT_RETURN_PACKET_BOUNDARY.md",
    "v61eh_real_generation_result_return_packet_manifest.json",
    "real_generation_result_return_packet/README.md",
    "real_generation_result_return_packet/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv",
    "real_generation_result_return_packet/REQUIRED_FIELD_ROWS.csv",
    "real_generation_result_return_packet/PREREQUISITE_BINDING_CONTRACT.csv",
    "real_generation_result_return_packet/INTAKE_COMMAND_ROWS.csv",
    "real_generation_result_return_packet/RETURN_ENV.template",
    "real_generation_result_return_packet/VERIFY_REAL_GENERATION_RETURN_PACKET.sh",
    "source_v61eg/v61bt_prerequisite_binding_rows.csv",
    "source_v61bt/actual_generation_result_required_field_rows.csv",
    "source_v61bt/actual_generation_result_status_rows.csv",
    "source_v61ct/operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv",
    "source_v61df/operator_packet/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61eh artifact: {rel}")

artifact_rows = read_csv(run_dir / "real_generation_required_artifact_rows.csv")
if len(artifact_rows) != 5:
    raise SystemExit("v61eh expected five required generation artifacts")
if any(row["counts_as_real_generation_result"] != "0" for row in artifact_rows):
    raise SystemExit("v61eh current artifact rows must not count as real generation")
if sum(int(row["required_field_rows"]) for row in artifact_rows) != 42:
    raise SystemExit("v61eh required field count mismatch")

binding_rows = read_csv(run_dir / "real_prerequisite_binding_contract_rows.csv")
if len(binding_rows) != 5:
    raise SystemExit("v61eh expected five prerequisite binding contract rows")
binding_by_id = {row["binding_requirement"]: row for row in binding_rows}
for binding_id in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "fixture-prerequisite-binding-mechanics",
]:
    if binding_by_id[binding_id]["ready"] != "1":
        raise SystemExit(f"v61eh binding row should be ready: {binding_id}")
for binding_id in ["complete-source-review-return", "generation-execution-admission"]:
    if binding_by_id[binding_id]["ready"] != "0":
        raise SystemExit(f"v61eh binding row should remain blocked: {binding_id}")
if binding_by_id["fixture-prerequisite-binding-mechanics"]["counts_as_real_prerequisite"] != "0":
    raise SystemExit("v61eh fixture binding must not count as a real prerequisite")

stages = read_csv(run_dir / "real_generation_result_return_packet_stage_rows.csv")
if [row["status"] for row in stages] != ["ready", "ready", "blocked", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v61eh stage status sequence mismatch")

commands = read_csv(run_dir / "real_generation_result_return_packet_command_rows.csv")
if len(commands) != 5:
    raise SystemExit("v61eh command row count mismatch")
if sum(row["ready_to_run_now"] == "1" for row in commands) != 1:
    raise SystemExit("v61eh should have only the packet verifier ready now")

invariants = read_csv(run_dir / "real_generation_result_return_packet_invariant_rows.csv")
if len(invariants) != 6 or any(row["status"] != "pass" for row in invariants):
    raise SystemExit("v61eh invariants should all pass")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "real-manifest-runtime-evidence",
    "fixture-prerequisite-binding-mechanics",
    "real-generation-result-return-packet",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61eh decision should pass: {gate}")
for gate in [
    "real-prerequisite-binding",
    "real-generation-result-artifacts",
    "actual-model-generation",
    "production-latency",
    "near-frontier-quality",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61eh decision should stay blocked: {gate}")

boundary = (run_dir / "V61EH_REAL_GENERATION_RESULT_RETURN_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real_manifest_runtime_evidence_ready=1",
    "fixture_prerequisite_binding_ready=1",
    "fixture_accepted_generation_result_artifacts=5/5",
    "fixture_generation_result_accepted_rows=1000/1000",
    "real_prerequisite_binding_ready=0",
    "generation_execution_admitted_rows=0/1000",
    "accepted_generation_result_artifacts=0/5",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61eh boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61eh_real_generation_result_return_packet_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61eh_real_generation_result_return_packet_ready") != 1:
    raise SystemExit("v61eh manifest readiness mismatch")
if manifest.get("real_prerequisite_binding_ready") != 0:
    raise SystemExit("v61eh manifest must keep real prerequisite binding blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61eh manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61eh manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61eh sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61eh produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61eh real generation result return packet smoke passed"
