#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fc_post_fb_dual_external_return_operator_packet"
RUN_DIR="$RESULTS_DIR/$PREFIX/packet_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKET_DIR="$RUN_DIR/dual_external_return_operator_packet"

V61FB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fb_post_ey_external_return_readiness_preflight.sh" >/dev/null
V61FC_REUSE_EXISTING="${V61FC_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null
V61FC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKET_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
packet_dir = Path(sys.argv[4])


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
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "v61fb_post_ey_external_return_readiness_preflight_ready": "1",
    "v53ak_complete_source_external_return_operator_checklist_ready": "1",
    "v61et_real_generation_intake_return_bundle_preflight_ready": "1",
    "v53_required_artifact_rows": "81",
    "v61_required_artifact_rows": "10",
    "dual_required_artifact_rows": "91",
    "dual_external_return_family_rows": "8",
    "provenance_contract_rows": "2",
    "packet_stage_rows": "9",
    "ready_packet_stage_rows": "4",
    "blocked_packet_stage_rows": "5",
    "command_rows": "6",
    "ready_command_rows": "2",
    "packet_file_rows": "11",
    "metadata_only_packet_file_rows": "11",
    "accepted_by_v61fc_rows": "0",
    "dual_external_return_candidate_ready": "0",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fc {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_external_return_required_artifact_rows.csv",
    "dual_external_return_family_rows.csv",
    "dual_external_return_provenance_contract_rows.csv",
    "dual_external_return_operator_stage_rows.csv",
    "dual_external_return_operator_command_rows.csv",
    "V61FC_POST_FB_DUAL_EXTERNAL_RETURN_OPERATOR_PACKET_BOUNDARY.md",
    "v61fc_post_fb_dual_external_return_operator_packet_manifest.json",
    "dual_external_return_operator_packet/DUAL_EXTERNAL_RETURN_OPERATOR_PACKET.md",
    "dual_external_return_operator_packet/DUAL_EXTERNAL_RETURN_REQUIRED_ARTIFACT_ROWS.csv",
    "dual_external_return_operator_packet/DUAL_EXTERNAL_RETURN_FAMILY_ROWS.csv",
    "dual_external_return_operator_packet/DUAL_EXTERNAL_RETURN_PROVENANCE_ROWS.csv",
    "dual_external_return_operator_packet/DUAL_EXTERNAL_RETURN_STAGE_ROWS.csv",
    "dual_external_return_operator_packet/DUAL_EXTERNAL_RETURN_COMMAND_ROWS.csv",
    "dual_external_return_operator_packet/DUAL_RETURN_ENV_TEMPLATE.sh",
    "dual_external_return_operator_packet/VERIFY_DUAL_RETURN_PACKET.sh",
    "dual_external_return_operator_packet/READY_NOW_COMMANDS.sh",
    "dual_external_return_operator_packet/PACKET_MANIFEST.json",
    "dual_external_return_operator_packet/PACKET_FILE_LIST.txt",
    "dual_external_return_operator_packet/PACKET_SHA256SUMS.txt",
    "source_v61fb/post_ey_external_return_readiness_stage_rows.csv",
    "source_v53ak/external_return_operator_checklist_rows.csv",
    "source_v61et/real_generation_intake_return_bundle_file_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fc artifact: {rel}")

artifact_rows = read_csv(run_dir / "dual_external_return_required_artifact_rows.csv")
if len(artifact_rows) != 91:
    raise SystemExit("v61fc artifact row count mismatch")
if sum(row["return_root_id"] == "v53_external_return_root" for row in artifact_rows) != 81:
    raise SystemExit("v61fc v53 artifact row count mismatch")
if sum(row["return_root_id"] == "v61_generation_intake_return_root" for row in artifact_rows) != 10:
    raise SystemExit("v61fc v61 artifact row count mismatch")
if sum(row["accepted_by_v61fc"] == "1" for row in artifact_rows) != 0:
    raise SystemExit("v61fc must not accept returned evidence rows")

stages = {row["stage_id"]: row["ready"] for row in read_csv(run_dir / "dual_external_return_operator_stage_rows.csv")}
for stage in ["01-source-v61fb-preflight", "02-source-v53ak-checklist", "03-source-v61et-contract", "04-dual-operator-packet"]:
    if stages.get(stage) != "1":
        raise SystemExit(f"v61fc expected ready stage: {stage}")
for stage in ["05-real-v53-return-root", "06-real-v61-return-root", "07-dual-real-preflight", "08-generation-acceptance-closure", "09-actual-generation"]:
    if stages.get(stage) != "0":
        raise SystemExit(f"v61fc expected blocked stage: {stage}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61fb-ready", "source-v53ak-checklist-ready", "source-v61et-contract-ready", "dual-artifact-matrix", "operator-packet", "repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fc expected pass decision: {gate}")
for gate in ["v53-real-return-root", "v61-real-return-root", "dual-external-return-real", "generation-acceptance-closure", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fc expected blocked decision: {gate}")

packet_manifest = json.loads((packet_dir / "PACKET_MANIFEST.json").read_text(encoding="utf-8"))
if packet_manifest.get("dual_required_artifact_rows") != 91:
    raise SystemExit("v61fc packet manifest artifact rows mismatch")
if packet_manifest.get("dual_external_return_real_ready") != 0:
    raise SystemExit("v61fc packet manifest must keep dual real readiness blocked")
if packet_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fc packet manifest must keep actual generation blocked")

boundary = (run_dir / "V61FC_POST_FB_DUAL_EXTERNAL_RETURN_OPERATOR_PACKET_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "dual_required_artifact_rows=91",
    "accepted_by_v61fc_rows=0",
    "dual_external_return_real_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fc boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fc sha256 mismatch: {rel}")
PY

"$PACKET_DIR/VERIFY_DUAL_RETURN_PACKET.sh" >/dev/null
"$PACKET_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fc produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fc post-fb dual external return operator packet smoke passed"
