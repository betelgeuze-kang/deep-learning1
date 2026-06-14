#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gc_post_gb_dual_return_root_admission_snapshot"
RUN_ID="${V61GC_RUN_ID:-snapshot_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gc_post_gb_dual_return_root_admission_snapshot_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gb_post_ga_generation_unblock_runway_receipt.sh" >/dev/null
V61FX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fx_post_fw_dual_return_operator_handoff_bundle.sh" >/dev/null
V61FC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null
V61FV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fv_post_fu_dual_return_replay_entrypoint.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
prefix = "v61gc_post_gb_dual_return_root_admission_snapshot"
snapshot_dir = run_dir / "dual_return_root_admission_snapshot"
snapshot_dir.mkdir(parents=True, exist_ok=True)

ROOT_ID_MAP = {
    "v53-external-return-root": "v53_external_return_root",
    "v61-generation-intake-return-root": "v61_generation_intake_return_root",
}
ROOT_ENV_TO_PROVENANCE_ENV = {
    "V61FV_V53_RETURN_BUNDLE_DIR": "V61FV_V53_RETURN_PROVENANCE",
    "V61FV_V61_RETURN_BUNDLE_DIR": "V61FV_V61_RETURN_PROVENANCE",
}


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


def copy_source(source_id, src, folder):
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    }


def existing_file_count(root_path):
    if not root_path or not root_path.is_dir():
        return 0
    return sum(1 for path in root_path.rglob("*") if path.is_file())


def present_required_artifacts(root_path, required_rows, contract_root_id):
    if not root_path or not root_path.is_dir():
        return 0
    present = 0
    for row in required_rows:
        if row["return_root_id"] != contract_root_id:
            continue
        rel = row["required_relative_path"]
        if (root_path / rel).is_file():
            present += 1
    return present


source_paths = {
    "v61gb_summary": results / "v61gb_post_ga_generation_unblock_runway_receipt_summary.csv",
    "v61gb_decision": results / "v61gb_post_ga_generation_unblock_runway_receipt_decision.csv",
    "v61gb_execution": results / "v61gb_post_ga_generation_unblock_runway_receipt" / "receipt_001" / "generation_unblock_runway_receipt_execution_rows.csv",
    "v61fx_summary": results / "v61fx_post_fw_dual_return_operator_handoff_bundle_summary.csv",
    "v61fx_root_contract": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_root_contract_rows.csv",
    "v61fx_stage": results / "v61fx_post_fw_dual_return_operator_handoff_bundle" / "handoff_001" / "dual_return_operator_handoff_stage_rows.csv",
    "v61fv_summary": results / "v61fv_post_fu_dual_return_replay_entrypoint_summary.csv",
    "v61fv_env": results / "v61fv_post_fu_dual_return_replay_entrypoint" / "entrypoint_001" / "dual_return_replay_required_env_rows.csv",
    "v61fv_commands": results / "v61fv_post_fu_dual_return_replay_entrypoint" / "entrypoint_001" / "dual_return_replay_entrypoint_command_rows.csv",
    "v61fc_summary": results / "v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "v61fc_artifacts": results / "v61fc_post_fb_dual_external_return_operator_packet" / "packet_001" / "dual_external_return_required_artifact_rows.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gc source {source_id}: {path}")

source_rows = []
for source_id, path in source_paths.items():
    if source_id.startswith("v61gb"):
        folder = "source_v61gb"
    elif source_id.startswith("v61fx"):
        folder = "source_v61fx"
    elif source_id.startswith("v61fv"):
        folder = "source_v61fv"
    else:
        folder = "source_v61fc"
    source_rows.append(copy_source(source_id, path, folder))
write_csv(run_dir / "dual_return_root_admission_snapshot_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gb = read_csv(source_paths["v61gb_summary"])[0]
v61fx = read_csv(source_paths["v61fx_summary"])[0]
v61fv = read_csv(source_paths["v61fv_summary"])[0]
v61fc = read_csv(source_paths["v61fc_summary"])[0]
root_contract_rows = read_csv(source_paths["v61fx_root_contract"])
required_env_rows = read_csv(source_paths["v61fv_env"])
required_artifact_rows = read_csv(source_paths["v61fc_artifacts"])

if v61gb.get("v61gb_post_ga_generation_unblock_runway_receipt_ready") != "1":
    raise SystemExit("v61gc requires v61gb ready")
if v61fx.get("v61fx_post_fw_dual_return_operator_handoff_bundle_ready") != "1":
    raise SystemExit("v61gc requires v61fx ready")
if v61fv.get("v61fv_post_fu_dual_return_replay_entrypoint_ready") != "1":
    raise SystemExit("v61gc requires v61fv ready")
if v61fc.get("v61fc_post_fb_dual_external_return_operator_packet_ready") != "1":
    raise SystemExit("v61gc requires v61fc ready")

artifact_root_counts = Counter(row["return_root_id"] for row in required_artifact_rows)
artifact_family_counts = Counter((row["return_root_id"], row["return_family"]) for row in required_artifact_rows)

env_snapshot_rows = []
for row in required_env_rows:
    env_var = row["env_var"]
    actual = os.environ.get(env_var, "")
    is_dir_requirement = row["required_value"] == "existing directory"
    exists = int(bool(actual) and Path(actual).expanduser().is_dir()) if is_dir_requirement else 0
    value_matches = int(actual == row["required_value"]) if not is_dir_requirement else exists
    env_snapshot_rows.append({
        "env_var": env_var,
        "required_value": row["required_value"],
        "present": str(int(bool(actual))),
        "value_matches": str(value_matches),
        "path_exists": str(exists),
        "actual_value_redacted": "<set>" if actual else "",
        "purpose": row["purpose"],
    })
write_csv(run_dir / "dual_return_root_admission_snapshot_env_rows.csv", list(env_snapshot_rows[0].keys()), env_snapshot_rows)

root_snapshot_rows = []
for row in root_contract_rows:
    root_id = row["root_id"]
    artifact_root_id = ROOT_ID_MAP[root_id]
    root_env = row["required_env_var"]
    provenance_env = row["required_provenance_env_var"]
    root_value = os.environ.get(root_env, "")
    provenance_value = os.environ.get(provenance_env, "")
    root_path = Path(root_value).expanduser() if root_value else None
    supplied = int(bool(root_value))
    exists = int(root_path is not None and root_path.is_dir())
    provenance_matches = int(provenance_value == row["required_provenance_value"])
    required_count = int(row["required_artifact_rows"])
    present_count = present_required_artifacts(root_path, required_artifact_rows, artifact_root_id)
    artifact_complete = int(present_count == required_count)
    admitted = int(supplied and exists and provenance_matches and artifact_complete)
    root_snapshot_rows.append({
        "root_id": root_id,
        "artifact_root_id": artifact_root_id,
        "required_env_var": root_env,
        "required_provenance_env_var": provenance_env,
        "required_provenance_value": row["required_provenance_value"],
        "root_supplied": str(supplied),
        "root_exists": str(exists),
        "provenance_supplied": str(int(bool(provenance_value))),
        "provenance_matches": str(provenance_matches),
        "required_artifact_rows": str(required_count),
        "present_artifact_rows": str(present_count),
        "missing_artifact_rows": str(required_count - present_count),
        "artifact_complete": str(artifact_complete),
        "existing_file_rows_under_root": str(existing_file_count(root_path)),
        "admitted_for_replay": str(admitted),
        "claim_boundary": "root admission snapshot only; no replay or generation executed",
    })
write_csv(run_dir / "dual_return_root_admission_snapshot_root_rows.csv", list(root_snapshot_rows[0].keys()), root_snapshot_rows)

family_rows = []
for (artifact_root_id, family), count in sorted(artifact_family_counts.items()):
    root_row = next(row for row in root_snapshot_rows if row["artifact_root_id"] == artifact_root_id)
    family_rows.append({
        "artifact_root_id": artifact_root_id,
        "return_family": family,
        "required_artifact_rows": str(count),
        "root_supplied": root_row["root_supplied"],
        "admitted_for_replay": root_row["admitted_for_replay"],
        "claim_boundary": "family count only; row content is not accepted here",
    })
write_csv(run_dir / "dual_return_root_admission_snapshot_artifact_family_rows.csv", list(family_rows[0].keys()), family_rows)

command_rows = [
    {
        "command_id": "01-verify-v61gb-runway-receipt",
        "ready_to_run_now": "1",
        "executed_by_v61gc": "0",
        "command": "results/v61gb_post_ga_generation_unblock_runway_receipt/receipt_001/generation_unblock_runway_receipt/VERIFY_GENERATION_UNBLOCK_RUNWAY_RECEIPT.sh",
        "purpose": "verify post-ga runway receipt mechanics",
    },
    {
        "command_id": "02-verify-v61fx-handoff",
        "ready_to_run_now": "1",
        "executed_by_v61gc": "0",
        "command": "results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/VERIFY_DUAL_RETURN_OPERATOR_HANDOFF.sh",
        "purpose": "verify dual return handoff package",
    },
    {
        "command_id": "03-supply-real-dual-roots",
        "ready_to_run_now": str(int(all(row["root_supplied"] == "1" for row in root_snapshot_rows))),
        "executed_by_v61gc": "0",
        "command": "export V61FV_V53_RETURN_BUNDLE_DIR=/path/to/v53_return_root V61FV_V53_RETURN_PROVENANCE=real-external-return-bundle V61FV_V61_RETURN_BUNDLE_DIR=/path/to/v61_return_root V61FV_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle",
        "purpose": "supply real external/generation-intake roots",
    },
    {
        "command_id": "04-run-root-pinned-dual-return-replay",
        "ready_to_run_now": str(int(all(row["admitted_for_replay"] == "1" for row in root_snapshot_rows))),
        "executed_by_v61gc": "0",
        "command": "results/v61fx_post_fw_dual_return_operator_handoff_bundle/handoff_001/dual_return_operator_handoff_bundle/RUN_DUAL_RETURN_REPLAY_IF_READY.sh",
        "purpose": "execute only after both roots are admitted",
    },
    {
        "command_id": "05-refresh-post-replay-runway",
        "ready_to_run_now": "0",
        "executed_by_v61gc": "0",
        "command": "./experiments/run_v61ga_post_fz_generation_unblock_runway.sh",
        "purpose": "refresh after real replay changes upstream status",
    },
]
write_csv(run_dir / "dual_return_root_admission_snapshot_command_rows.csv", list(command_rows[0].keys()), command_rows)

admitted_roots = sum(row["admitted_for_replay"] == "1" for row in root_snapshot_rows)
supplied_roots = sum(row["root_supplied"] == "1" for row in root_snapshot_rows)
existing_roots = sum(row["root_exists"] == "1" for row in root_snapshot_rows)
provenance_match_roots = sum(row["provenance_matches"] == "1" for row in root_snapshot_rows)
required_artifacts = sum(int(row["required_artifact_rows"]) for row in root_snapshot_rows)
present_artifacts = sum(int(row["present_artifact_rows"]) for row in root_snapshot_rows)
missing_artifacts = required_artifacts - present_artifacts
all_roots_admitted = int(admitted_roots == len(root_snapshot_rows))

stage_rows = [
    {"stage_id": "01-v61gb-runway-receipt", "status": "ready", "evidence": "v61gb_post_ga_generation_unblock_runway_receipt_ready=1"},
    {"stage_id": "02-root-contract-loaded", "status": "ready", "evidence": f"root_contract_rows={len(root_contract_rows)} required_env_rows={len(required_env_rows)}"},
    {"stage_id": "03-dual-return-root-supply", "status": "ready" if supplied_roots == len(root_snapshot_rows) else "blocked", "evidence": f"supplied_root_rows={supplied_roots}/{len(root_snapshot_rows)}"},
    {"stage_id": "04-dual-return-root-admission", "status": "ready" if all_roots_admitted else "blocked", "evidence": f"admitted_root_rows={admitted_roots}/{len(root_snapshot_rows)} missing_artifact_rows={missing_artifacts}"},
    {"stage_id": "05-root-pinned-replay", "status": "blocked", "evidence": "v61gc does not execute dual return replay"},
    {"stage_id": "06-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "dual_return_root_admission_snapshot_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

for rel, path in [
    ("DUAL_RETURN_ROOT_ADMISSION_ROOT_ROWS.csv", run_dir / "dual_return_root_admission_snapshot_root_rows.csv"),
    ("DUAL_RETURN_ROOT_ADMISSION_ENV_ROWS.csv", run_dir / "dual_return_root_admission_snapshot_env_rows.csv"),
    ("DUAL_RETURN_ROOT_ADMISSION_ARTIFACT_FAMILY_ROWS.csv", run_dir / "dual_return_root_admission_snapshot_artifact_family_rows.csv"),
    ("DUAL_RETURN_ROOT_ADMISSION_COMMAND_ROWS.csv", run_dir / "dual_return_root_admission_snapshot_command_rows.csv"),
    ("DUAL_RETURN_ROOT_ADMISSION_STAGE_ROWS.csv", run_dir / "dual_return_root_admission_snapshot_stage_rows.csv"),
]:
    shutil.copy2(path, snapshot_dir / rel)

snapshot_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "root_contract_rows": len(root_contract_rows),
    "required_env_rows": len(required_env_rows),
    "supplied_root_rows": supplied_roots,
    "existing_root_rows": existing_roots,
    "provenance_match_rows": provenance_match_roots,
    "admitted_root_rows": admitted_roots,
    "required_artifact_rows": required_artifacts,
    "present_artifact_rows": present_artifacts,
    "missing_artifact_rows": missing_artifacts,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(snapshot_dir / "DUAL_RETURN_ROOT_ADMISSION_MANIFEST.json").write_text(json.dumps(snapshot_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(snapshot_dir / "VERIFY_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_ADMISSION_MANIFEST.json\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_ADMISSION_ROOT_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_ADMISSION_ENV_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_ADMISSION_ARTIFACT_FAMILY_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_ADMISSION_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/DUAL_RETURN_ROOT_ADMISSION_STAGE_ROWS.csv\"",
        "grep -q 'actual_model_generation_ready' \"$DIR/DUAL_RETURN_ROOT_ADMISSION_MANIFEST.json\"",
        "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
        "  echo 'payload-like file referenced in root admission snapshot package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(snapshot_dir / "VERIFY_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.sh").chmod(0o755)
(snapshot_dir / "DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT.md").write_text(
    "\n".join([
        "# v61gc dual return root admission snapshot",
        "",
        f"- root_contract_rows={len(root_contract_rows)}",
        f"- required_env_rows={len(required_env_rows)}",
        f"- supplied_root_rows={supplied_roots}",
        f"- existing_root_rows={existing_roots}",
        f"- provenance_match_rows={provenance_match_roots}",
        f"- admitted_root_rows={admitted_roots}",
        f"- required_artifact_rows={required_artifacts}",
        f"- present_artifact_rows={present_artifacts}",
        f"- missing_artifact_rows={missing_artifacts}",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "This snapshot measures root admission readiness only. It does not execute root-pinned replay, row acceptance, actual model generation, production latency, near-frontier, or release evidence.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in snapshot_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "dual_return_root_admission_snapshot_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61gc_post_gb_dual_return_root_admission_snapshot_ready": "1",
    "v61gb_post_ga_generation_unblock_runway_receipt_ready": v61gb["v61gb_post_ga_generation_unblock_runway_receipt_ready"],
    "v61fx_post_fw_dual_return_operator_handoff_bundle_ready": v61fx["v61fx_post_fw_dual_return_operator_handoff_bundle_ready"],
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": v61fv["v61fv_post_fu_dual_return_replay_entrypoint_ready"],
    "v61fc_post_fb_dual_external_return_operator_packet_ready": v61fc["v61fc_post_fb_dual_external_return_operator_packet_ready"],
    "root_contract_rows": str(len(root_contract_rows)),
    "required_env_rows": str(len(required_env_rows)),
    "env_present_rows": str(sum(row["present"] == "1" for row in env_snapshot_rows)),
    "env_value_match_rows": str(sum(row["value_matches"] == "1" for row in env_snapshot_rows)),
    "supplied_root_rows": str(supplied_roots),
    "existing_root_rows": str(existing_roots),
    "provenance_match_rows": str(provenance_match_roots),
    "admitted_root_rows": str(admitted_roots),
    "required_artifact_rows": str(required_artifacts),
    "present_artifact_rows": str(present_artifacts),
    "missing_artifact_rows": str(missing_artifacts),
    "artifact_family_rows": str(len(family_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "executed_command_rows": str(sum(row["executed_by_v61gc"] == "1" for row in command_rows)),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(row["status"] == "ready" for row in stage_rows)),
    "blocked_stage_rows": str(sum(row["status"] == "blocked" for row in stage_rows)),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "snapshot_package_file_rows": str(len(package_file_rows)),
    "metadata_only_snapshot_package_file_rows": str(sum(row["metadata_only"] == "1" for row in package_file_rows)),
    "payload_like_snapshot_package_file_rows": str(sum(row["payload_like"] == "1" for row in package_file_rows)),
    "source_file_rows": str(len(source_rows)),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gb-ready", "status": "pass", "evidence": "v61gb_post_ga_generation_unblock_runway_receipt_ready=1"},
    {"gate": "source-root-contract", "status": "pass", "evidence": f"root_contract_rows={len(root_contract_rows)} required_env_rows={len(required_env_rows)}"},
    {"gate": "required-artifact-contract", "status": "pass", "evidence": f"required_artifact_rows={required_artifacts}"},
    {"gate": "dual-return-root-supply", "status": "pass" if supplied_roots == len(root_snapshot_rows) else "blocked", "evidence": f"supplied_root_rows={supplied_roots}/{len(root_snapshot_rows)}"},
    {"gate": "dual-return-root-admission", "status": "pass" if all_roots_admitted else "blocked", "evidence": f"admitted_root_rows={admitted_roots}/{len(root_snapshot_rows)} missing_artifact_rows={missing_artifacts}"},
    {"gate": "root-pinned-replay", "status": "blocked", "evidence": "v61gc does not execute replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GC Post-GB Dual Return Root Admission Snapshot Boundary",
    "",
    f"- v61gc_post_gb_dual_return_root_admission_snapshot_ready={summary['v61gc_post_gb_dual_return_root_admission_snapshot_ready']}",
    f"- v61gb_post_ga_generation_unblock_runway_receipt_ready={summary['v61gb_post_ga_generation_unblock_runway_receipt_ready']}",
    f"- root_contract_rows={summary['root_contract_rows']}",
    f"- required_env_rows={summary['required_env_rows']}",
    f"- supplied_root_rows={summary['supplied_root_rows']}",
    f"- existing_root_rows={summary['existing_root_rows']}",
    f"- provenance_match_rows={summary['provenance_match_rows']}",
    f"- admitted_root_rows={summary['admitted_root_rows']}",
    f"- required_artifact_rows={summary['required_artifact_rows']}",
    f"- present_artifact_rows={summary['present_artifact_rows']}",
    f"- missing_artifact_rows={summary['missing_artifact_rows']}",
    f"- command_rows={summary['command_rows']}",
    f"- ready_command_rows={summary['ready_command_rows']}",
    f"- executed_command_rows={summary['executed_command_rows']}",
    f"- stage_rows={summary['stage_rows']}",
    f"- ready_stage_rows={summary['ready_stage_rows']}",
    f"- blocked_stage_rows={summary['blocked_stage_rows']}",
    f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
    f"- checkpoint_payload_bytes_committed_to_repo={summary['checkpoint_payload_bytes_committed_to_repo']}",
    "",
    "Blocked wording: this is a root admission snapshot only. It does not execute dual return replay, row acceptance, actual model generation, near-frontier quality, production latency, or release evidence.",
    "",
])
(run_dir / "V61GC_POST_GB_DUAL_RETURN_ROOT_ADMISSION_SNAPSHOT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "snapshot_manifest": snapshot_manifest,
    "checkpoint_payload_bytes_downloaded_by_v61gc": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gc_post_gb_dual_return_root_admission_snapshot_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
