#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gc_post_gb_dual_return_root_admission_snapshot"
RUN_DIR="$RESULTS_DIR/$PREFIX/snapshot_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SNAPSHOT_DIR="$RUN_DIR/dual_return_root_admission_snapshot"

V61GC_REUSE_EXISTING="${V61GC_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gc_post_gb_dual_return_root_admission_snapshot.sh" >/dev/null

"$SNAPSHOT_DIR/VERIFY_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SNAPSHOT_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
snapshot_dir = Path(sys.argv[4])


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
    "v61gc_post_gb_dual_return_root_admission_snapshot_ready": "1",
    "v61gb_post_ga_generation_unblock_runway_receipt_ready": "1",
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": "1",
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": "1",
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "root_contract_rows": "2",
    "required_env_rows": "4",
    "env_present_rows": "0",
    "env_value_match_rows": "0",
    "supplied_root_rows": "0",
    "existing_root_rows": "0",
    "provenance_match_rows": "0",
    "admitted_root_rows": "0",
    "required_artifact_rows": "91",
    "present_artifact_rows": "0",
    "missing_artifact_rows": "91",
    "artifact_family_rows": "8",
    "command_rows": "5",
    "ready_command_rows": "2",
    "executed_command_rows": "0",
    "stage_rows": "6",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "4",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "snapshot_package_file_rows": "8",
    "metadata_only_snapshot_package_file_rows": "8",
    "payload_like_snapshot_package_file_rows": "0",
    "source_file_rows": "11",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gc {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "dual_return_root_admission_snapshot_root_rows.csv",
    "dual_return_root_admission_snapshot_env_rows.csv",
    "dual_return_root_admission_snapshot_artifact_family_rows.csv",
    "dual_return_root_admission_snapshot_command_rows.csv",
    "dual_return_root_admission_snapshot_stage_rows.csv",
    "dual_return_root_admission_snapshot_package_file_rows.csv",
    "dual_return_root_admission_snapshot_source_rows.csv",
    "V61GC_POST_GB_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT_BOUNDARY.md",
    "v61gc_post_gb_dual_return_root_admission_snapshot_manifest.json",
    "v61gc_post_gb_dual_return_root_admission_snapshot_summary.csv",
    "v61gc_post_gb_dual_return_root_admission_snapshot_decision.csv",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_ROOT_ROWS.csv",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_ENV_ROWS.csv",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_ARTIFACT_FAMILY_ROWS.csv",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_COMMAND_ROWS.csv",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_STAGE_ROWS.csv",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_MANIFEST.json",
    "dual_return_root_admission_snapshot/DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.md",
    "dual_return_root_admission_snapshot/VERIFY_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.sh",
    "source_v61gb/v61gb_post_ga_generation_unblock_runway_receipt_summary.csv",
    "source_v61fx/dual_return_operator_handoff_root_contract_rows.csv",
    "source_v61fv/dual_return_replay_required_env_rows.csv",
    "source_v61fc/dual_external_return_required_artifact_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gc artifact: {rel}")

if not os.access(snapshot_dir / "VERIFY_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.sh", os.X_OK):
    raise SystemExit("v61gc verifier must be executable")

root_rows = read_csv(run_dir / "dual_return_root_admission_snapshot_root_rows.csv")
if len(root_rows) != 2:
    raise SystemExit("v61gc expected two root rows")
if {row["root_id"] for row in root_rows} != {"v53-external-return-root", "v61-generation-intake-return-root"}:
    raise SystemExit("v61gc root ids mismatch")
if sum(int(row["required_artifact_rows"]) for row in root_rows) != 91:
    raise SystemExit("v61gc root artifact requirement mismatch")
if any(row["root_supplied"] != "0" or row["admitted_for_replay"] != "0" for row in root_rows):
    raise SystemExit("v61gc default root rows must remain unadmitted")

env_rows = read_csv(run_dir / "dual_return_root_admission_snapshot_env_rows.csv")
if len(env_rows) != 4:
    raise SystemExit("v61gc expected four env rows")
if any(row["present"] != "0" or row["value_matches"] != "0" for row in env_rows):
    raise SystemExit("v61gc default env rows must be absent")

families = read_csv(run_dir / "dual_return_root_admission_snapshot_artifact_family_rows.csv")
if len(families) != 8:
    raise SystemExit("v61gc expected eight root-family artifact rows")
family_counts = {
    (row["artifact_root_id"], row["return_family"]): int(row["required_artifact_rows"])
    for row in families
}
for key, count in {
    ("v53_external_return_root", "dispatch-receipt"): 21,
    ("v53_external_return_root", "review-chunk-return"): 50,
    ("v53_external_return_root", "aggregate-review-return"): 5,
    ("v53_external_return_root", "generation-result-return"): 5,
    ("v61_generation_intake_return_root", "dispatch-receipt"): 1,
    ("v61_generation_intake_return_root", "generation-result"): 5,
    ("v61_generation_intake_return_root", "prerequisite-binding"): 3,
    ("v61_generation_intake_return_root", "review-return-provenance"): 1,
}.items():
    if family_counts.get(key) != count:
        raise SystemExit(f"v61gc family count mismatch: {key}")

commands = read_csv(run_dir / "dual_return_root_admission_snapshot_command_rows.csv")
if len(commands) != 5:
    raise SystemExit("v61gc expected five command rows")
if sum(row["ready_to_run_now"] == "1" for row in commands) != 2:
    raise SystemExit("v61gc expected two ready command rows")
if any(row["executed_by_v61gc"] != "0" for row in commands):
    raise SystemExit("v61gc must not execute replay or verifier commands")
if not any("RUN_DUAL_RETURN_REPLAY_IF_READY.sh" in row["command"] for row in commands):
    raise SystemExit("v61gc must point at root-pinned replay command")
if not any("V61FV_V53_RETURN_BUNDLE_DIR" in row["command"] for row in commands):
    raise SystemExit("v61gc must document V61FV root supply env")

stages = read_csv(run_dir / "dual_return_root_admission_snapshot_stage_rows.csv")
if len(stages) != 6:
    raise SystemExit("v61gc expected six stage rows")
if sum(row["status"] == "ready" for row in stages) != 2:
    raise SystemExit("v61gc expected two ready stages")
if sum(row["status"] == "blocked" for row in stages) != 4:
    raise SystemExit("v61gc expected four blocked stages")

package_rows = read_csv(run_dir / "dual_return_root_admission_snapshot_package_file_rows.csv")
if len(package_rows) != 8:
    raise SystemExit("v61gc expected eight package files")
if any(row["metadata_only"] != "1" or row["payload_like"] != "0" for row in package_rows):
    raise SystemExit("v61gc package rows must be metadata-only and non-payload")

source_rows = read_csv(run_dir / "dual_return_root_admission_snapshot_source_rows.csv")
if len(source_rows) != 11:
    raise SystemExit("v61gc expected eleven source rows")
if any(row["metadata_only"] != "1" for row in source_rows):
    raise SystemExit("v61gc source rows must be metadata-only")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gb-ready", "source-root-contract", "required-artifact-contract", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gc expected pass decision: {gate}")
for gate in ["dual-return-root-supply", "dual-return-root-admission", "root-pinned-replay", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gc expected blocked decision: {gate}")

manifest = json.loads((run_dir / "v61gc_post_gb_dual_return_root_admission_snapshot_manifest.json").read_text(encoding="utf-8"))
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61gc manifest must keep repo checkpoint payload zero")
if manifest.get("summary", {}).get("actual_model_generation_ready") != "0":
    raise SystemExit("v61gc manifest must keep actual generation blocked")

snapshot_manifest = json.loads((snapshot_dir / "DUAL_RETURN_ROOT_ADMISSION_MANIFEST.json").read_text(encoding="utf-8"))
if snapshot_manifest.get("admitted_root_rows") != 0:
    raise SystemExit("v61gc default snapshot must admit zero roots")
if snapshot_manifest.get("missing_artifact_rows") != 91:
    raise SystemExit("v61gc default snapshot must show 91 missing artifacts")

boundary = (run_dir / "V61GC_POST_GB_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gc_post_gb_dual_return_root_admission_snapshot_ready=1",
    "v61gb_post_ga_generation_unblock_runway_receipt_ready=1",
    "root_contract_rows=2",
    "required_env_rows=4",
    "supplied_root_rows=0",
    "admitted_root_rows=0",
    "required_artifact_rows=91",
    "missing_artifact_rows=91",
    "command_rows=5",
    "ready_command_rows=2",
    "executed_command_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gc boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gc sha256 mismatch: {rel}")

if any(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"} for path in run_dir.rglob("*") if path.is_file()):
    raise SystemExit("v61gc must not emit payload-like files")

print("v61gc post-gb dual return root admission snapshot smoke passed")
PY
