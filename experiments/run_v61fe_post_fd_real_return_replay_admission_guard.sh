#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fe_post_fd_real_return_replay_admission_guard"
RUN_ID="${V61FE_RUN_ID:-guard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V53_RETURN_ROOT_ARG="${V61FE_V53_RETURN_ROOT:-}"
V61_RETURN_ROOT_ARG="${V61FE_V61_RETURN_ROOT:-}"
V53_RETURN_PROVENANCE="${V61FE_V53_RETURN_PROVENANCE:-unspecified}"
V61_RETURN_PROVENANCE="${V61FE_V61_RETURN_PROVENANCE:-unspecified}"

if [[ "${V61FE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fe_post_fd_real_return_replay_admission_guard_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh" >/dev/null
V61FC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null
V61FB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V53_RETURN_ROOT_ARG" "$V61_RETURN_ROOT_ARG" "$V53_RETURN_PROVENANCE" "$V61_RETURN_PROVENANCE" <<'PY'
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
v53_root_arg = sys.argv[5].strip()
v61_root_arg = sys.argv[6].strip()
v53_provenance = sys.argv[7].strip() or "unspecified"
v61_provenance = sys.argv[8].strip() or "unspecified"
results = root / "results"
guard_dir = run_dir / "real_return_replay_admission_guard"
guard_dir.mkdir(parents=True, exist_ok=True)
v53_root = Path(v53_root_arg).expanduser().resolve() if v53_root_arg else None
v61_root = Path(v61_root_arg).expanduser().resolve() if v61_root_arg else None


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


def copy_guard(src, rel):
    dst = guard_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def pass_block(flag):
    return "pass" if flag else "blocked"


source_paths = {
    "v61fd_summary": results / "v61fd_post_fc_real_return_closure_delta_ledger_summary.csv",
    "v61fd_decision": results / "v61fd_post_fc_real_return_closure_delta_ledger_decision.csv",
    "v61fd_delta": results / "v61fd_post_fc_real_return_closure_delta_ledger/ledger_001/post_fc_real_return_closure_delta_rows.csv",
    "v61fd_command": results / "v61fd_post_fc_real_return_closure_delta_ledger/ledger_001/post_fc_real_return_closure_command_rows.csv",
    "v61fc_summary": results / "v61fc_post_fb_dual_external_return_operator_packet_summary.csv",
    "v61fc_artifacts": results / "v61fc_post_fb_dual_external_return_operator_packet/packet_001/dual_external_return_required_artifact_rows.csv",
    "v61fb_summary": results / "v61fb_post_ey_external_return_readiness_preflight_summary.csv",
    "v61fb_decision": results / "v61fb_post_ey_external_return_readiness_preflight_decision.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fe source {key}: {path}")

for key, path in source_paths.items():
    if key.startswith("v61fd"):
        folder = "source_v61fd"
    elif key.startswith("v61fc"):
        folder = "source_v61fc"
    else:
        folder = "source_v61fb"
    copy(path, f"{folder}/{path.name}")

v61fd = read_csv(source_paths["v61fd_summary"])[0]
v61fc = read_csv(source_paths["v61fc_summary"])[0]
v61fb = read_csv(source_paths["v61fb_summary"])[0]
delta_rows = read_csv(source_paths["v61fd_delta"])

if v61fd.get("v61fd_post_fc_real_return_closure_delta_ledger_ready") != "1":
    raise SystemExit("v61fe requires v61fd ready")
if v61fc.get("v61fc_post_fb_dual_external_return_operator_packet_ready") != "1":
    raise SystemExit("v61fe requires v61fc ready")

v53_supplied = int(v53_root is not None)
v53_exists = int(v53_root is not None and v53_root.is_dir())
v61_supplied = int(v61_root is not None)
v61_exists = int(v61_root is not None and v61_root.is_dir())
v53_real_provenance = int(v53_provenance == "real-external-return-bundle")
v61_real_provenance = int(v61_provenance == "real-generation-intake-return-bundle")
dual_roots_supplied = int(v53_supplied and v53_exists and v61_supplied and v61_exists)
dual_real_provenance = int(v53_real_provenance and v61_real_provenance)
real_replay_admission_ready = int(dual_roots_supplied and dual_real_provenance)

guard_rows = [
    {
        "guard_id": "01-v61fd-delta-ledger-ready",
        "status": "pass",
        "ready": "1",
        "required_value": "1",
        "actual_value": v61fd["v61fd_post_fc_real_return_closure_delta_ledger_ready"],
        "blocking_reason": "",
    },
    {
        "guard_id": "02-v61fc-operator-packet-ready",
        "status": "pass",
        "ready": "1",
        "required_value": "1",
        "actual_value": v61fc["v61fc_post_fb_dual_external_return_operator_packet_ready"],
        "blocking_reason": "",
    },
    {
        "guard_id": "03-v53-return-root-supplied",
        "status": pass_block(v53_supplied),
        "ready": str(v53_supplied),
        "required_value": "1",
        "actual_value": str(v53_supplied),
        "blocking_reason": "" if v53_supplied else "V61FE_V53_RETURN_ROOT is not supplied",
    },
    {
        "guard_id": "04-v53-return-root-exists",
        "status": pass_block(v53_exists),
        "ready": str(v53_exists),
        "required_value": "1",
        "actual_value": str(v53_exists),
        "blocking_reason": "" if v53_exists else "v53 return root does not exist",
    },
    {
        "guard_id": "05-v53-real-provenance",
        "status": pass_block(v53_real_provenance),
        "ready": str(v53_real_provenance),
        "required_value": "real-external-return-bundle",
        "actual_value": v53_provenance,
        "blocking_reason": "" if v53_real_provenance else "v53 real provenance is not asserted",
    },
    {
        "guard_id": "06-v61-return-root-supplied",
        "status": pass_block(v61_supplied),
        "ready": str(v61_supplied),
        "required_value": "1",
        "actual_value": str(v61_supplied),
        "blocking_reason": "" if v61_supplied else "V61FE_V61_RETURN_ROOT is not supplied",
    },
    {
        "guard_id": "07-v61-return-root-exists",
        "status": pass_block(v61_exists),
        "ready": str(v61_exists),
        "required_value": "1",
        "actual_value": str(v61_exists),
        "blocking_reason": "" if v61_exists else "v61 return root does not exist",
    },
    {
        "guard_id": "08-v61-real-provenance",
        "status": pass_block(v61_real_provenance),
        "ready": str(v61_real_provenance),
        "required_value": "real-generation-intake-return-bundle",
        "actual_value": v61_provenance,
        "blocking_reason": "" if v61_real_provenance else "v61 real provenance is not asserted",
    },
    {
        "guard_id": "09-dual-root-admission",
        "status": pass_block(real_replay_admission_ready),
        "ready": str(real_replay_admission_ready),
        "required_value": "1",
        "actual_value": str(real_replay_admission_ready),
        "blocking_reason": "" if real_replay_admission_ready else "both real return roots and provenance are required",
    },
    {
        "guard_id": "10-actual-generation-claim",
        "status": "blocked",
        "ready": "0",
        "required_value": "1",
        "actual_value": "0",
        "blocking_reason": "replay admission does not prove row acceptance or actual generation",
    },
]
write_csv(run_dir / "post_fd_real_return_replay_admission_guard_rows.csv", list(guard_rows[0].keys()), guard_rows)
copy_guard(run_dir / "post_fd_real_return_replay_admission_guard_rows.csv", "REAL_RETURN_REPLAY_ADMISSION_GUARDS.csv")

chain_rows = [
    {
        "chain_step_id": "01-verify-v61fd-ledger",
        "ready_to_run_now": "1",
        "command": "results/v61fd_post_fc_real_return_closure_delta_ledger/ledger_001/real_return_closure_delta_ledger/VERIFY_DELTA_LEDGER.sh",
        "expected_transition": "ledger checksum and row counts verify",
        "claim_boundary": "metadata verification only",
    },
    {
        "chain_step_id": "02-dual-real-preflight",
        "ready_to_run_now": str(real_replay_admission_ready),
        "command": "V61FB_V53_RETURN_BUNDLE_DIR=\"$V61FE_V53_RETURN_ROOT\" V61FB_V53_RETURN_PROVENANCE=real-external-return-bundle V61FB_V61_RETURN_BUNDLE_DIR=\"$V61FE_V61_RETURN_ROOT\" V61FB_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle ./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh",
        "expected_transition": "dual external return real preflight can be evaluated",
        "claim_boundary": "file/provenance preflight only",
    },
    {
        "chain_step_id": "03-v53-return-acceptance-replay",
        "ready_to_run_now": str(real_replay_admission_ready),
        "command": "V53AM_RETURN_BUNDLE_DIR=\"$V61FE_V53_RETURN_ROOT\" ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
        "expected_transition": "v53 review/generation return acceptance replay can be evaluated",
        "claim_boundary": "row acceptance only if downstream accepts real rows",
    },
    {
        "chain_step_id": "04-v61-return-downstream-replay",
        "ready_to_run_now": str(real_replay_admission_ready),
        "command": "V61EV_RETURN_BUNDLE_DIR=\"$V61FE_V61_RETURN_ROOT\" ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh",
        "expected_transition": "v61 generation-intake return replay can be evaluated",
        "claim_boundary": "candidate/real replay only until row acceptance closes",
    },
    {
        "chain_step_id": "05-refresh-v61ex-closure",
        "ready_to_run_now": str(real_replay_admission_ready),
        "command": "./experiments/run_v61ex_generation_acceptance_closure_work_order.sh",
        "expected_transition": "closure blockers refresh after replay",
        "claim_boundary": "closure work order only",
    },
    {
        "chain_step_id": "06-refresh-v61fd-delta-ledger",
        "ready_to_run_now": str(real_replay_admission_ready),
        "command": "./experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh",
        "expected_transition": "missing deltas refresh after replay",
        "claim_boundary": "delta ledger only",
    },
    {
        "chain_step_id": "07-actual-generation-claim",
        "ready_to_run_now": "0",
        "command": "Do not claim actual generation until v61fd open_delta_rows=0 and v61cu actual_model_generation_ready=1",
        "expected_transition": "claim remains blocked",
        "claim_boundary": "blocked",
    },
]
write_csv(run_dir / "post_fd_real_return_replay_chain_rows.csv", list(chain_rows[0].keys()), chain_rows)
copy_guard(run_dir / "post_fd_real_return_replay_chain_rows.csv", "REAL_RETURN_REPLAY_CHAIN_ROWS.csv")

blocked_delta_rows = [
    {
        "delta_id": row["delta_id"],
        "family": row["family"],
        "missing_count": row["missing_count"],
        "next_action": row["next_action"],
    }
    for row in delta_rows
    if row["status"] == "open"
]
write_csv(run_dir / "post_fd_blocked_delta_snapshot_rows.csv", list(blocked_delta_rows[0].keys()), blocked_delta_rows)
copy_guard(run_dir / "post_fd_blocked_delta_snapshot_rows.csv", "BLOCKED_DELTA_SNAPSHOT_ROWS.csv")

operator_script = guard_dir / "RUN_REAL_RETURN_REPLAY_IF_ADMITTED.sh"
operator_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            ': "${V61FE_V53_RETURN_ROOT:?set V61FE_V53_RETURN_ROOT}"',
            ': "${V61FE_V61_RETURN_ROOT:?set V61FE_V61_RETURN_ROOT}"',
            ': "${V61FE_V53_RETURN_PROVENANCE:?set V61FE_V53_RETURN_PROVENANCE}"',
            ': "${V61FE_V61_RETURN_PROVENANCE:?set V61FE_V61_RETURN_PROVENANCE}"',
            'if [[ "$V61FE_V53_RETURN_PROVENANCE" != "real-external-return-bundle" ]]; then',
            "  echo 'v53 provenance must be real-external-return-bundle' >&2",
            "  exit 2",
            "fi",
            'if [[ "$V61FE_V61_RETURN_PROVENANCE" != "real-generation-intake-return-bundle" ]]; then',
            "  echo 'v61 provenance must be real-generation-intake-return-bundle' >&2",
            "  exit 2",
            "fi",
            'if [[ ! -d "$V61FE_V53_RETURN_ROOT" || ! -d "$V61FE_V61_RETURN_ROOT" ]]; then',
            "  echo 'both return roots must exist' >&2",
            "  exit 2",
            "fi",
            'V61FB_V53_RETURN_BUNDLE_DIR="$V61FE_V53_RETURN_ROOT" \\',
            'V61FB_V53_RETURN_PROVENANCE="$V61FE_V53_RETURN_PROVENANCE" \\',
            'V61FB_V61_RETURN_BUNDLE_DIR="$V61FE_V61_RETURN_ROOT" \\',
            'V61FB_V61_RETURN_PROVENANCE="$V61FE_V61_RETURN_PROVENANCE" \\',
            "./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh",
            'V53AM_RETURN_BUNDLE_DIR="$V61FE_V53_RETURN_ROOT" ./experiments/run_v53am_complete_source_return_acceptance_replay.sh',
            'V61EV_RETURN_BUNDLE_DIR="$V61FE_V61_RETURN_ROOT" ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh',
            "./experiments/run_v61ex_generation_acceptance_closure_work_order.sh",
            "./experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(operator_script, 0o755)

readme = guard_dir / "REAL_RETURN_REPLAY_ADMISSION_GUARD.md"
readme.write_text(
    "\n".join(
        [
            "# v61fe Real Return Replay Admission Guard",
            "",
            "This guard is metadata-only unless both real external return roots are",
            "supplied with explicit real provenance. It admits the replay command",
            "chain only after the v53 and v61 roots exist and are provenance-marked.",
            "",
            f"- v53_return_root_supplied={v53_supplied}",
            f"- v61_return_root_supplied={v61_supplied}",
            f"- dual_roots_supplied={dual_roots_supplied}",
            f"- dual_real_provenance_ready={dual_real_provenance}",
            f"- real_return_replay_admission_ready={real_replay_admission_ready}",
            f"- open_delta_rows={v61fd['open_delta_rows']}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fe defines the guarded replay order for real external return roots.",
            "",
            "Blocked wording:",
            "- Do not claim row acceptance, generation acceptance closure, actual generation, latency, quality, or release readiness from v61fe alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61fe-post-fd-real-return-replay-admission-guard",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "guard_rows": len(guard_rows),
    "pass_guard_rows": sum(row["status"] == "pass" for row in guard_rows),
    "blocked_guard_rows": sum(row["status"] == "blocked" for row in guard_rows),
    "chain_rows": len(chain_rows),
    "ready_chain_rows": sum(row["ready_to_run_now"] == "1" for row in chain_rows),
    "blocked_delta_rows": len(blocked_delta_rows),
    "real_return_replay_admission_ready": real_replay_admission_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(guard_dir / "GUARD_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = guard_dir / "VERIFY_REPLAY_ADMISSION_GUARD.sh"
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
            "for line in (root / 'GUARD_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'GUARD_MANIFEST.json').read_text(encoding='utf-8'))",
            "guard_rows = list(csv.DictReader((root / 'REAL_RETURN_REPLAY_ADMISSION_GUARDS.csv').open(newline='', encoding='utf-8')))",
            "chain_rows = list(csv.DictReader((root / 'REAL_RETURN_REPLAY_CHAIN_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(guard_rows) != manifest['guard_rows']:",
            "    raise SystemExit('guard row count mismatch')",
            "if len(chain_rows) != manifest['chain_rows']:",
            "    raise SystemExit('chain row count mismatch')",
            "if sum(row['ready_to_run_now'] == '1' for row in chain_rows) != manifest['ready_chain_rows']:",
            "    raise SystemExit('ready chain count mismatch')",
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

guard_files_for_hash = sorted(
    path
    for path in guard_dir.rglob("*")
    if path.is_file() and path.name not in {"GUARD_FILE_LIST.txt", "GUARD_SHA256SUMS.txt"}
)
(guard_dir / "GUARD_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(guard_dir)) for path in guard_files_for_hash) + "\n",
    encoding="utf-8",
)
guard_files_for_hash = sorted(path for path in guard_dir.rglob("*") if path.is_file() and path.name != "GUARD_SHA256SUMS.txt")
(guard_dir / "GUARD_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(guard_dir)}\n" for path in guard_files_for_hash),
    encoding="utf-8",
)

guard_file_rows = sum(1 for path in guard_dir.rglob("*") if path.is_file())
pass_guard_rows = sum(row["status"] == "pass" for row in guard_rows)
blocked_guard_rows = len(guard_rows) - pass_guard_rows
ready_chain_rows = sum(row["ready_to_run_now"] == "1" for row in chain_rows)

summary = {
    "v61fe_post_fd_real_return_replay_admission_guard_ready": "1",
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": v61fd["v61fd_post_fc_real_return_closure_delta_ledger_ready"],
    "v61fc_post_fb_dual_external_return_operator_packet_ready": v61fc["v61fc_post_fb_dual_external_return_operator_packet_ready"],
    "v61fb_post_ey_external_return_readiness_preflight_ready": v61fb["v61fb_post_ey_external_return_readiness_preflight_ready"],
    "guard_rows": str(len(guard_rows)),
    "pass_guard_rows": str(pass_guard_rows),
    "blocked_guard_rows": str(blocked_guard_rows),
    "chain_rows": str(len(chain_rows)),
    "ready_chain_rows": str(ready_chain_rows),
    "guard_file_rows": str(guard_file_rows),
    "metadata_only_guard_file_rows": str(guard_file_rows),
    "blocked_delta_rows": str(len(blocked_delta_rows)),
    "open_delta_rows": v61fd["open_delta_rows"],
    "v53_return_root_supplied": str(v53_supplied),
    "v53_return_root_exists": str(v53_exists),
    "v61_return_root_supplied": str(v61_supplied),
    "v61_return_root_exists": str(v61_exists),
    "dual_roots_supplied": str(dual_roots_supplied),
    "dual_real_provenance_ready": str(dual_real_provenance),
    "real_return_replay_admission_ready": str(real_replay_admission_ready),
    "dual_external_return_real_ready": v61fd["dual_external_return_real_ready"],
    "generation_acceptance_closure_ready": v61fd["generation_acceptance_closure_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fe": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61fd-ready", "status": "pass", "reason": "delta ledger exists"},
    {"gate": "source-v61fc-ready", "status": "pass", "reason": "operator packet exists"},
    {"gate": "guard-shape", "status": "pass", "reason": f"{len(guard_rows)} guard rows emitted"},
    {"gate": "operator-script", "status": "pass", "reason": "guarded replay script emitted"},
    {"gate": "v53-return-root", "status": pass_block(v53_exists), "reason": f"exists={v53_exists}; provenance={v53_provenance}"},
    {"gate": "v61-return-root", "status": pass_block(v61_exists), "reason": f"exists={v61_exists}; provenance={v61_provenance}"},
    {"gate": "real-return-replay-admission", "status": pass_block(real_replay_admission_ready), "reason": f"ready={real_replay_admission_ready}"},
    {"gate": "row-acceptance", "status": "blocked", "reason": "v61fe does not accept returned rows"},
    {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata guard only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FE_POST_FD_REAL_RETURN_REPLAY_ADMISSION_GUARD_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fe Post-v61fd Real Return Replay Admission Guard Boundary",
            "",
            f"- v53_return_root_supplied={v53_supplied}",
            f"- v61_return_root_supplied={v61_supplied}",
            f"- dual_roots_supplied={dual_roots_supplied}",
            f"- dual_real_provenance_ready={dual_real_provenance}",
            f"- real_return_replay_admission_ready={real_replay_admission_ready}",
            f"- open_delta_rows={v61fd['open_delta_rows']}",
            "- row_acceptance_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fe defines the guarded replay command order for real return roots.",
            "",
            "Blocked wording:",
            "- Do not claim row acceptance, generation acceptance closure, actual generation, latency, quality, or release readiness from v61fe alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fe_post_fd_real_return_replay_admission_guard",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fe_post_fd_real_return_replay_admission_guard_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fe_post_fd_real_return_replay_admission_guard_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
