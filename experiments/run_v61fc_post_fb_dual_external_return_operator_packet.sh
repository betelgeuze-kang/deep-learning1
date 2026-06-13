#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fc_post_fb_dual_external_return_operator_packet"
RUN_ID="${V61FC_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FC_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fc_post_fb_dual_external_return_operator_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh" >/dev/null
V53AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null
V61ET_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
results = root / "results"
packet_dir = run_dir / "dual_external_return_operator_packet"
packet_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    return sha256(path).split(":", 1)[1]


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


def copy_packet(src, rel):
    dst = packet_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v61fb_summary": results / "v61fb_post_ey_external_return_readiness_preflight_summary.csv",
    "v61fb_decision": results / "v61fb_post_ey_external_return_readiness_preflight_decision.csv",
    "v61fb_stage": results / "v61fb_post_ey_external_return_readiness_preflight/preflight_001/post_ey_external_return_readiness_stage_rows.csv",
    "v61fb_requirement": results / "v61fb_post_ey_external_return_readiness_preflight/preflight_001/post_ey_external_return_readiness_requirement_rows.csv",
    "v61fb_command": results / "v61fb_post_ey_external_return_readiness_preflight/preflight_001/post_ey_external_return_readiness_command_rows.csv",
    "v53ak_summary": results / "v53ak_complete_source_external_return_operator_checklist_summary.csv",
    "v53ak_decision": results / "v53ak_complete_source_external_return_operator_checklist_decision.csv",
    "v53ak_checklist": results / "v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_checklist_rows.csv",
    "v53ak_family": results / "v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_family_checklist_rows.csv",
    "v61et_summary": results / "v61et_real_generation_intake_return_bundle_preflight_summary.csv",
    "v61et_decision": results / "v61et_real_generation_intake_return_bundle_preflight_decision.csv",
    "v61et_files": results / "v61et_real_generation_intake_return_bundle_preflight/preflight_001/real_generation_intake_return_bundle_file_rows.csv",
    "v61et_family": results / "v61et_real_generation_intake_return_bundle_preflight/preflight_001/real_generation_intake_return_bundle_family_rows.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fc source {key}: {path}")

for key, path in source_paths.items():
    if key.startswith("v61fb"):
        folder = "source_v61fb"
    elif key.startswith("v53ak"):
        folder = "source_v53ak"
    else:
        folder = "source_v61et"
    copy(path, f"{folder}/{path.name}")

v61fb = read_csv(source_paths["v61fb_summary"])[0]
v53ak = read_csv(source_paths["v53ak_summary"])[0]
v61et = read_csv(source_paths["v61et_summary"])[0]
v53_checklist = read_csv(source_paths["v53ak_checklist"])
v61_files = read_csv(source_paths["v61et_files"])

if v61fb.get("v61fb_post_ey_external_return_readiness_preflight_ready") != "1":
    raise SystemExit("v61fc requires v61fb readiness")
if v53ak.get("v53ak_complete_source_external_return_operator_checklist_ready") != "1":
    raise SystemExit("v61fc requires v53ak checklist readiness")
if v61et.get("v61et_real_generation_intake_return_bundle_preflight_ready") != "1":
    raise SystemExit("v61fc requires v61et preflight readiness")

v61_downstream_gate = {
    "dispatch-receipt": "v61er/v61es",
    "generation-result": "v61ej/v61bt/v61cu",
    "prerequisite-binding": "v61el/v61de",
    "review-return-provenance": "v53y/v61de",
}
v61_validation_command = {
    "dispatch-receipt": "V61ER_DISPATCH_RECEIPT_DIR=<v61-return-root>/dispatch_receipt ./experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh",
    "generation-result": "V61EJ_GENERATION_RESULT_DIR=<v61-return-root>/generation_result_return ./experiments/run_v61ej_real_generation_return_receiver_preflight.sh",
    "prerequisite-binding": "V61EL_PREREQUISITE_BINDING_DIR=<v61-return-root>/prerequisite_binding ./experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh",
    "review-return-provenance": "V61ET_RETURN_BUNDLE_DIR=<v61-return-root> V61ET_RETURN_BUNDLE_PROVENANCE=real-generation-intake-return-bundle ./experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh",
}

artifact_rows = []
for index, row in enumerate(v53_checklist, start=1):
    artifact_rows.append(
        {
            "artifact_id": f"v53_artifact_{index:03d}",
            "return_root_id": "v53_external_return_root",
            "source_gate": "v53ak",
            "return_family": row["return_family"],
            "required_relative_path": row["final_return_bundle_relative_path"],
            "expected_rows": row["expected_rows"],
            "target_env_var": "V61FB_V53_RETURN_BUNDLE_DIR",
            "downstream_gate": row["downstream_gate"],
            "validation_command": row["validation_command"],
            "supplied_by_default": "0",
            "accepted_by_v61fc": "0",
            "claim_boundary": "candidate preflight only until real external provenance is supplied",
        }
    )

for index, row in enumerate(v61_files, start=1):
    family = row["family"]
    artifact_rows.append(
        {
            "artifact_id": f"v61_artifact_{index:03d}",
            "return_root_id": "v61_generation_intake_return_root",
            "source_gate": "v61et",
            "return_family": family,
            "required_relative_path": row["required_path"],
            "expected_rows": "contract-bound",
            "target_env_var": "V61FB_V61_RETURN_BUNDLE_DIR",
            "downstream_gate": v61_downstream_gate[family],
            "validation_command": v61_validation_command[family],
            "supplied_by_default": "0",
            "accepted_by_v61fc": "0",
            "claim_boundary": "candidate preflight only until real generation-intake provenance is supplied",
        }
    )
write_csv(run_dir / "dual_external_return_required_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)
copy_packet(run_dir / "dual_external_return_required_artifact_rows.csv", "DUAL_EXTERNAL_RETURN_REQUIRED_ARTIFACT_ROWS.csv")

family_rows = []
for root_id in ["v53_external_return_root", "v61_generation_intake_return_root"]:
    families = sorted({row["return_family"] for row in artifact_rows if row["return_root_id"] == root_id})
    for family in families:
        related = [row for row in artifact_rows if row["return_root_id"] == root_id and row["return_family"] == family]
        family_rows.append(
            {
                "return_root_id": root_id,
                "return_family": family,
                "required_artifact_rows": str(len(related)),
                "supplied_by_default_rows": "0",
                "accepted_by_v61fc_rows": "0",
                "downstream_gates": ";".join(sorted({row["downstream_gate"] for row in related})),
                "claim_boundary": "metadata-only operator packet",
            }
        )
write_csv(run_dir / "dual_external_return_family_rows.csv", list(family_rows[0].keys()), family_rows)
copy_packet(run_dir / "dual_external_return_family_rows.csv", "DUAL_EXTERNAL_RETURN_FAMILY_ROWS.csv")

provenance_rows = [
    {
        "return_root_id": "v53_external_return_root",
        "required_provenance_value": "real-external-return-bundle",
        "target_env_var": "V61FB_V53_RETURN_PROVENANCE",
        "current_value": v61fb["v53_return_provenance"],
        "real_ready": v61fb["v53_return_bundle_real_preflight_ready"],
        "blocking_reason": "explicit real-external-return-bundle provenance is required",
    },
    {
        "return_root_id": "v61_generation_intake_return_root",
        "required_provenance_value": "real-generation-intake-return-bundle",
        "target_env_var": "V61FB_V61_RETURN_PROVENANCE",
        "current_value": v61fb["v61_return_provenance"],
        "real_ready": v61fb["v61_return_bundle_real_preflight_ready"],
        "blocking_reason": "explicit real-generation-intake-return-bundle provenance is required",
    },
]
write_csv(run_dir / "dual_external_return_provenance_contract_rows.csv", list(provenance_rows[0].keys()), provenance_rows)
copy_packet(run_dir / "dual_external_return_provenance_contract_rows.csv", "DUAL_EXTERNAL_RETURN_PROVENANCE_ROWS.csv")

stage_rows = [
    {"stage_id": "01-source-v61fb-preflight", "status": "ready", "ready": "1", "evidence": "v61fb ready", "blocking_reason": ""},
    {"stage_id": "02-source-v53ak-checklist", "status": "ready", "ready": "1", "evidence": f"v53_required_artifact_rows={len(v53_checklist)}", "blocking_reason": ""},
    {"stage_id": "03-source-v61et-contract", "status": "ready", "ready": "1", "evidence": f"v61_required_artifact_rows={len(v61_files)}", "blocking_reason": ""},
    {"stage_id": "04-dual-operator-packet", "status": "ready", "ready": "1", "evidence": f"dual_required_artifact_rows={len(artifact_rows)}", "blocking_reason": ""},
    {"stage_id": "05-real-v53-return-root", "status": "blocked", "ready": "0", "evidence": f"v53_real={v61fb['v53_return_bundle_real_preflight_ready']}", "blocking_reason": "real v53 external return root is not supplied"},
    {"stage_id": "06-real-v61-return-root", "status": "blocked", "ready": "0", "evidence": f"v61_real={v61fb['v61_return_bundle_real_preflight_ready']}", "blocking_reason": "real v61 generation-intake return root is not supplied"},
    {"stage_id": "07-dual-real-preflight", "status": "blocked", "ready": "0", "evidence": f"dual_real={v61fb['dual_external_return_real_ready']}", "blocking_reason": "both roots must pass real preflight"},
    {"stage_id": "08-generation-acceptance-closure", "status": "blocked", "ready": "0", "evidence": "generation_acceptance_closure_ready=0", "blocking_reason": "v61bt/v61de/v61cu acceptance rows are not closed"},
    {"stage_id": "09-actual-generation", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0", "blocking_reason": "actual generation evidence is not present"},
]
write_csv(run_dir / "dual_external_return_operator_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
copy_packet(run_dir / "dual_external_return_operator_stage_rows.csv", "DUAL_EXTERNAL_RETURN_STAGE_ROWS.csv")

command_rows = [
    {
        "command_id": "01-verify-dual-return-packet",
        "ready_to_run_now": "1",
        "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/VERIFY_DUAL_RETURN_PACKET.sh",
        "purpose": "verify the metadata-only operator packet",
    },
    {
        "command_id": "02-print-ready-commands",
        "ready_to_run_now": "1",
        "command": "results/v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_operator_packet/READY_NOW_COMMANDS.sh",
        "purpose": "print currently safe commands and required roots",
    },
    {
        "command_id": "03-run-dual-external-return-preflight",
        "ready_to_run_now": "0",
        "command": "V61FB_V53_RETURN_BUNDLE_DIR=<v53-return-root> V61FB_V53_RETURN_PROVENANCE=real-external-return-bundle V61FB_V61_RETURN_BUNDLE_DIR=<v61-return-root> V61FB_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle ./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh",
        "purpose": "prove both external return roots are real and mechanically complete",
    },
    {
        "command_id": "04-replay-v53-return-acceptance",
        "ready_to_run_now": "0",
        "command": "V53AM_RETURN_BUNDLE_DIR=<v53-return-root> ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
        "purpose": "replay complete-source review/generation return acceptance",
    },
    {
        "command_id": "05-replay-v61-generation-return",
        "ready_to_run_now": "0",
        "command": "V61EV_RETURN_BUNDLE_DIR=<v61-return-root> ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh",
        "purpose": "replay v61 generation-intake return downstream",
    },
    {
        "command_id": "06-refresh-generation-acceptance-closure",
        "ready_to_run_now": "0",
        "command": "./experiments/run_v61ex_generation_acceptance_closure_work_order.sh",
        "purpose": "refresh closure after real return acceptance changes",
    },
]
write_csv(run_dir / "dual_external_return_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)
copy_packet(run_dir / "dual_external_return_operator_command_rows.csv", "DUAL_EXTERNAL_RETURN_COMMAND_ROWS.csv")

readme = packet_dir / "DUAL_EXTERNAL_RETURN_OPERATOR_PACKET.md"
readme.write_text(
    "\n".join(
        [
            "# v61fc Dual External Return Operator Packet",
            "",
            "This packet is metadata-only. It joins the v53 81-artifact external",
            "return surface and the v61 10-file generation-intake return surface",
            "after v61fb, so an operator has one auditable checklist for the next",
            "real return attempt.",
            "",
            f"- v53_required_artifact_rows={len(v53_checklist)}",
            f"- v61_required_artifact_rows={len(v61_files)}",
            f"- dual_required_artifact_rows={len(artifact_rows)}",
            f"- provenance_contract_rows={len(provenance_rows)}",
            "- accepted_by_v61fc_rows=0",
            "- dual_external_return_real_ready=0",
            "- generation_acceptance_closure_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fc provides a checksum-bound operator packet for the two external return roots.",
            "",
            "Blocked wording:",
            "- Do not claim real return acceptance, generation acceptance closure, actual generation, latency, quality, or release readiness from this packet.",
            "",
        ]
    ),
    encoding="utf-8",
)

env_template = packet_dir / "DUAL_RETURN_ENV_TEMPLATE.sh"
env_template.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "export V61FB_V53_RETURN_BUNDLE_DIR=/path/to/v53_external_return_root",
            "export V61FB_V53_RETURN_PROVENANCE=real-external-return-bundle",
            "export V61FB_V61_RETURN_BUNDLE_DIR=/path/to/v61_generation_intake_return_root",
            "export V61FB_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(env_template, 0o755)

ready_commands = packet_dir / "READY_NOW_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61fc ready-now commands are metadata verification only; real replay commands require supplied external roots.'",
]
for row in command_rows:
    if row["ready_to_run_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['command'])}")
ready_commands.write_text("\n".join(ready_lines) + "\n", encoding="utf-8")
os.chmod(ready_commands, 0o755)

packet_manifest = {
    "manifest_scope": "v61fc-post-fb-dual-external-return-operator-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61fb_post_ey_external_return_readiness_preflight_ready": as_int(v61fb, "v61fb_post_ey_external_return_readiness_preflight_ready"),
    "v53ak_complete_source_external_return_operator_checklist_ready": as_int(v53ak, "v53ak_complete_source_external_return_operator_checklist_ready"),
    "v61et_real_generation_intake_return_bundle_preflight_ready": as_int(v61et, "v61et_real_generation_intake_return_bundle_preflight_ready"),
    "v53_required_artifact_rows": len(v53_checklist),
    "v61_required_artifact_rows": len(v61_files),
    "dual_required_artifact_rows": len(artifact_rows),
    "dual_external_return_family_rows": len(family_rows),
    "provenance_contract_rows": len(provenance_rows),
    "packet_stage_rows": len(stage_rows),
    "ready_packet_stage_rows": sum(row["ready"] == "1" for row in stage_rows),
    "blocked_packet_stage_rows": sum(row["ready"] == "0" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "accepted_by_v61fc_rows": 0,
    "dual_external_return_candidate_ready": as_int(v61fb, "dual_external_return_candidate_ready"),
    "dual_external_return_real_ready": as_int(v61fb, "dual_external_return_real_ready"),
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(packet_dir / "PACKET_MANIFEST.json").write_text(json.dumps(packet_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = packet_dir / "VERIFY_DUAL_RETURN_PACKET.sh"
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
            "for line in (root / 'PACKET_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'PACKET_MANIFEST.json').read_text(encoding='utf-8'))",
            "artifact_rows = list(csv.DictReader((root / 'DUAL_EXTERNAL_RETURN_REQUIRED_ARTIFACT_ROWS.csv').open(newline='', encoding='utf-8')))",
            "family_rows = list(csv.DictReader((root / 'DUAL_EXTERNAL_RETURN_FAMILY_ROWS.csv').open(newline='', encoding='utf-8')))",
            "stage_rows = list(csv.DictReader((root / 'DUAL_EXTERNAL_RETURN_STAGE_ROWS.csv').open(newline='', encoding='utf-8')))",
            "command_rows = list(csv.DictReader((root / 'DUAL_EXTERNAL_RETURN_COMMAND_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(artifact_rows) != manifest['dual_required_artifact_rows']:",
            "    raise SystemExit('artifact row count mismatch')",
            "if len([r for r in artifact_rows if r['return_root_id'] == 'v53_external_return_root']) != manifest['v53_required_artifact_rows']:",
            "    raise SystemExit('v53 artifact row count mismatch')",
            "if len([r for r in artifact_rows if r['return_root_id'] == 'v61_generation_intake_return_root']) != manifest['v61_required_artifact_rows']:",
            "    raise SystemExit('v61 artifact row count mismatch')",
            "if len(family_rows) != manifest['dual_external_return_family_rows']:",
            "    raise SystemExit('family row count mismatch')",
            "if len(stage_rows) != manifest['packet_stage_rows']:",
            "    raise SystemExit('stage row count mismatch')",
            "if sum(row['ready'] == '1' for row in stage_rows) != manifest['ready_packet_stage_rows']:",
            "    raise SystemExit('ready stage count mismatch')",
            "if len(command_rows) != manifest['command_rows']:",
            "    raise SystemExit('command row count mismatch')",
            "if sum(row['ready_to_run_now'] == '1' for row in command_rows) != manifest['ready_command_rows']:",
            "    raise SystemExit('ready command count mismatch')",
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

packet_files_for_hash = sorted(
    path
    for path in packet_dir.rglob("*")
    if path.is_file() and path.name not in {"PACKET_FILE_LIST.txt", "PACKET_SHA256SUMS.txt"}
)
(packet_dir / "PACKET_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(packet_dir)) for path in packet_files_for_hash) + "\n",
    encoding="utf-8",
)
packet_files_for_hash = sorted(
    path
    for path in packet_dir.rglob("*")
    if path.is_file() and path.name != "PACKET_SHA256SUMS.txt"
)
(packet_dir / "PACKET_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(packet_dir)}\n" for path in packet_files_for_hash),
    encoding="utf-8",
)

packet_file_rows = len(packet_files_for_hash)
metadata_only_packet_file_rows = packet_file_rows
ready_packet_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)

summary = {
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "v61fb_post_ey_external_return_readiness_preflight_ready": v61fb["v61fb_post_ey_external_return_readiness_preflight_ready"],
    "v53ak_complete_source_external_return_operator_checklist_ready": v53ak["v53ak_complete_source_external_return_operator_checklist_ready"],
    "v61et_real_generation_intake_return_bundle_preflight_ready": v61et["v61et_real_generation_intake_return_bundle_preflight_ready"],
    "v53_required_artifact_rows": str(len(v53_checklist)),
    "v61_required_artifact_rows": str(len(v61_files)),
    "dual_required_artifact_rows": str(len(artifact_rows)),
    "dual_external_return_family_rows": str(len(family_rows)),
    "provenance_contract_rows": str(len(provenance_rows)),
    "packet_stage_rows": str(len(stage_rows)),
    "ready_packet_stage_rows": str(ready_packet_stage_rows),
    "blocked_packet_stage_rows": str(len(stage_rows) - ready_packet_stage_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "packet_file_rows": str(packet_file_rows),
    "metadata_only_packet_file_rows": str(metadata_only_packet_file_rows),
    "accepted_by_v61fc_rows": "0",
    "dual_external_return_candidate_ready": v61fb["dual_external_return_candidate_ready"],
    "dual_external_return_real_ready": v61fb["dual_external_return_real_ready"],
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fc": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61fb-ready", "status": "pass", "reason": "dual external return readiness preflight exists"},
    {"gate": "source-v53ak-checklist-ready", "status": "pass", "reason": "v53 81-artifact checklist exists"},
    {"gate": "source-v61et-contract-ready", "status": "pass", "reason": "v61 10-file return contract exists"},
    {"gate": "dual-artifact-matrix", "status": "pass", "reason": f"{len(artifact_rows)} required artifact rows emitted"},
    {"gate": "operator-packet", "status": "pass", "reason": f"{packet_file_rows} metadata-only packet files emitted"},
    {"gate": "v53-real-return-root", "status": "blocked", "reason": "real v53 external return root is missing"},
    {"gate": "v61-real-return-root", "status": "blocked", "reason": "real v61 generation-intake return root is missing"},
    {"gate": "dual-external-return-real", "status": "blocked", "reason": "both real roots must pass v61fb"},
    {"gate": "generation-acceptance-closure", "status": "blocked", "reason": "v61bt/v61de/v61cu acceptance remains open"},
    {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata packet only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FC_POST_FB_DUAL_EXTERNAL_RETURN_OPERATOR_PACKET_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fc Post-v61fb Dual External Return Operator Packet Boundary",
            "",
            f"- v53_required_artifact_rows={len(v53_checklist)}",
            f"- v61_required_artifact_rows={len(v61_files)}",
            f"- dual_required_artifact_rows={len(artifact_rows)}",
            "- accepted_by_v61fc_rows=0",
            f"- dual_external_return_candidate_ready={v61fb['dual_external_return_candidate_ready']}",
            f"- dual_external_return_real_ready={v61fb['dual_external_return_real_ready']}",
            "- generation_acceptance_closure_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fc provides a metadata-only, checksum-bound operator packet for the v53 and v61 external return roots.",
            "",
            "Blocked wording:",
            "- Do not claim real return acceptance, generation acceptance closure, actual generation, latency, quality, or release readiness from v61fc alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61fc_post_fb_dual_external_return_operator_packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fc_post_fb_dual_external_return_operator_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fc_post_fb_dual_external_return_operator_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
