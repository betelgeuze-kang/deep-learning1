#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ey_generation_acceptance_closure_handoff_bundle"
RUN_ID="${V61EY_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ORDER_RUN_DIR_ARG="${V61EY_WORK_ORDER_RUN_DIR:-}"

if [[ "${V61EY_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ey_generation_acceptance_closure_handoff_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ex_generation_acceptance_closure_work_order.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WORK_ORDER_RUN_DIR_ARG" <<'PY'
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
work_order_arg = sys.argv[5].strip()
results = root / "results"
default_work_order_dir = results / "v61ex_generation_acceptance_closure_work_order" / "work_order_001"
work_order_dir = Path(work_order_arg).expanduser().resolve() if work_order_arg else default_work_order_dir
bundle_dir = run_dir / "handoff_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)


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


def copy_bundle(src, rel):
    dst = bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61ex_summary": results / "v61ex_generation_acceptance_closure_work_order_summary.csv",
    "v61ex_decision": results / "v61ex_generation_acceptance_closure_work_order_decision.csv",
    "selected_work_order_rows": work_order_dir / "generation_acceptance_closure_work_order_rows.csv",
    "selected_blocker_rows": work_order_dir / "generation_acceptance_closure_blocker_rows.csv",
    "selected_command_rows": work_order_dir / "generation_acceptance_closure_command_rows.csv",
    "selected_manifest": work_order_dir / "v61ex_generation_acceptance_closure_work_order_manifest.json",
    "selected_boundary": work_order_dir / "V61EX_GENERATION_ACCEPTANCE_CLOSURE_WORK_ORDER_BOUNDARY.md",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ey source {key}: {path}")

copy(sources["v61ex_summary"], "source_v61ex/v61ex_generation_acceptance_closure_work_order_summary.csv")
copy(sources["v61ex_decision"], "source_v61ex/v61ex_generation_acceptance_closure_work_order_decision.csv")
copy(sources["selected_work_order_rows"], "selected_work_order/generation_acceptance_closure_work_order_rows.csv")
copy(sources["selected_blocker_rows"], "selected_work_order/generation_acceptance_closure_blocker_rows.csv")
copy(sources["selected_command_rows"], "selected_work_order/generation_acceptance_closure_command_rows.csv")
copy(sources["selected_manifest"], "selected_work_order/v61ex_generation_acceptance_closure_work_order_manifest.json")
copy(sources["selected_boundary"], "selected_work_order/V61EX_GENERATION_ACCEPTANCE_CLOSURE_WORK_ORDER_BOUNDARY.md")

work_rows = read_csv(sources["selected_work_order_rows"])
blocker_rows = read_csv(sources["selected_blocker_rows"])
command_rows = read_csv(sources["selected_command_rows"])
selected_manifest = json.loads(sources["selected_manifest"].read_text(encoding="utf-8"))
v61ex_summary = read_csv(sources["v61ex_summary"])[0]

if v61ex_summary.get("v61ex_generation_acceptance_closure_work_order_ready") != "1":
    raise SystemExit("v61ey requires v61ex work order readiness")
if len(work_rows) != 13:
    raise SystemExit(f"v61ey expects 13 work rows, got {len(work_rows)}")
if len(command_rows) != 8:
    raise SystemExit(f"v61ey expects 8 command rows, got {len(command_rows)}")

ready_work_rows = sum(row["ready"] == "1" for row in work_rows)
open_blocker_rows = len(blocker_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
selected_bridge_candidate = int(selected_manifest.get("selected_acceptance_bridge_candidate_ready", 0))
selected_bridge_real = int(selected_manifest.get("selected_acceptance_bridge_real_ready", 0))
closure_ready = int(selected_manifest.get("generation_acceptance_closure_ready", 0))

copy_bundle(sources["selected_work_order_rows"], "work_order/GENERATION_ACCEPTANCE_WORK_ROWS.csv")
copy_bundle(sources["selected_blocker_rows"], "work_order/GENERATION_ACCEPTANCE_BLOCKERS.csv")
copy_bundle(sources["selected_command_rows"], "work_order/GENERATION_ACCEPTANCE_COMMANDS.csv")
copy_bundle(sources["selected_manifest"], "evidence/V61EX_SELECTED_MANIFEST.json")
copy_bundle(sources["v61ex_summary"], "evidence/v61ex_generation_acceptance_closure_work_order_summary.csv")

readme = bundle_dir / "GENERATION_ACCEPTANCE_CLOSURE_HANDOFF.md"
readme.write_text(
    "\n".join(
        [
            "# v61ey Generation Acceptance Closure Handoff Bundle",
            "",
            "This bundle is metadata-only. It packages the selected v61ex work order",
            "for the final v61bt/v61de/v61cu acceptance closure path. It contains no",
            "returned generation evidence, review evidence, or checkpoint payload.",
            "",
            "Primary files:",
            "",
            "- `work_order/GENERATION_ACCEPTANCE_WORK_ROWS.csv`",
            "- `work_order/GENERATION_ACCEPTANCE_BLOCKERS.csv`",
            "- `work_order/GENERATION_ACCEPTANCE_COMMANDS.csv`",
            "- `READY_NOW_COMMANDS.sh`",
            "- `VERIFY_HANDOFF_BUNDLE.sh`",
            "",
            "Current selected work-order posture:",
            "",
            f"- ready_work_order_rows={ready_work_rows}",
            f"- open_blocker_rows={open_blocker_rows}",
            f"- closure_command_rows={len(command_rows)}",
            f"- ready_closure_command_rows={ready_command_rows}",
            f"- selected_acceptance_bridge_candidate_ready={selected_bridge_candidate}",
            f"- selected_acceptance_bridge_real_ready={selected_bridge_real}",
            f"- generation_acceptance_closure_ready={closure_ready}",
            "- actual_model_generation_ready=0",
            "",
            "The bundle may be used to inspect and validate the closure path, but it",
            "does not make actual generation, production-latency, near-frontier, or",
            "release claims.",
            "",
        ]
    ),
    encoding="utf-8",
)

ready_commands = bundle_dir / "READY_NOW_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61ey ready-now commands are informational; supply real return paths before running closure commands.'",
]
for row in command_rows:
    if row["ready_to_run_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['command'])}")
ready_commands.write_text("\n".join(ready_lines) + "\n", encoding="utf-8")
os.chmod(ready_commands, 0o755)

verify_script = bundle_dir / "VERIFY_HANDOFF_BUNDLE.sh"
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
            "for line in (root / 'BUNDLE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "work_rows = list(csv.DictReader((root / 'work_order/GENERATION_ACCEPTANCE_WORK_ROWS.csv').open(newline='', encoding='utf-8')))",
            "blocker_rows = list(csv.DictReader((root / 'work_order/GENERATION_ACCEPTANCE_BLOCKERS.csv').open(newline='', encoding='utf-8')))",
            "command_rows = list(csv.DictReader((root / 'work_order/GENERATION_ACCEPTANCE_COMMANDS.csv').open(newline='', encoding='utf-8')))",
            "manifest = json.loads((root / 'BUNDLE_MANIFEST.json').read_text(encoding='utf-8'))",
            "if len(work_rows) != 13:",
            "    raise SystemExit('expected 13 acceptance closure work rows')",
            "if len(command_rows) != 8:",
            "    raise SystemExit('expected 8 acceptance closure command rows')",
            "if len(blocker_rows) != manifest['open_blocker_rows']:",
            "    raise SystemExit('blocker row count does not match bundle manifest')",
            "if sum(row['ready'] == '1' for row in work_rows) != manifest['ready_work_order_rows']:",
            "    raise SystemExit('ready work row count does not match bundle manifest')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_manifest = {
    "manifest_scope": "v61ey-generation-acceptance-closure-handoff-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "selected_acceptance_bridge_candidate_ready": selected_bridge_candidate,
    "selected_acceptance_bridge_real_ready": selected_bridge_real,
    "ready_work_order_rows": ready_work_rows,
    "open_blocker_rows": open_blocker_rows,
    "closure_command_rows": len(command_rows),
    "ready_closure_command_rows": ready_command_rows,
    "generation_acceptance_closure_ready": closure_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(bundle_dir / "BUNDLE_MANIFEST.json").write_text(json.dumps(bundle_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

bundle_files_for_hash = sorted(
    path
    for path in bundle_dir.rglob("*")
    if path.is_file() and path.name not in {"BUNDLE_FILE_LIST.txt", "BUNDLE_SHA256SUMS.txt"}
)
(bundle_dir / "BUNDLE_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(bundle_dir)) for path in bundle_files_for_hash) + "\n",
    encoding="utf-8",
)
(bundle_dir / "BUNDLE_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(bundle_dir)}\n" for path in bundle_files_for_hash),
    encoding="utf-8",
)

bundle_file_rows = []
for path in sorted(bundle_dir.rglob("*")):
    if not path.is_file():
        continue
    bundle_file_rows.append(
        {
            "bundle_relative_path": str(path.relative_to(bundle_dir)),
            "size_bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "payload_class": "metadata-only",
        }
    )
write_csv(run_dir / "generation_acceptance_closure_handoff_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

validation_rows = [
    {
        "validation_id": "01-verify-handoff-bundle",
        "ready_to_run_now": "1",
        "command": "results/v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/handoff_bundle/VERIFY_HANDOFF_BUNDLE.sh",
        "expected_transition": "bundle checksum and closure row-count checks pass",
    },
    {
        "validation_id": "02-print-ready-commands",
        "ready_to_run_now": "1",
        "command": "results/v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/handoff_bundle/READY_NOW_COMMANDS.sh",
        "expected_transition": "operator sees informational ready-now commands",
    },
    {
        "validation_id": "03-run-after-real-return",
        "ready_to_run_now": "0",
        "command": "V61BT/V61DE/V61CU real return env vars plus v61ex/v61ey refresh",
        "expected_transition": "acceptance closure progresses only after real return rows are supplied",
    },
]
write_csv(run_dir / "generation_acceptance_closure_handoff_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

handoff_stage_rows = [
    {"handoff_stage_id": "01-work-order-source", "status": "ready", "evidence": "v61ex work order rows copied"},
    {"handoff_stage_id": "02-bundle-metadata", "status": "ready", "evidence": f"handoff_bundle_file_rows={len(bundle_file_rows)}"},
    {"handoff_stage_id": "03-bundle-verifier", "status": "ready", "evidence": "VERIFY_HANDOFF_BUNDLE.sh"},
    {"handoff_stage_id": "04-real-acceptance-closure", "status": "blocked", "evidence": f"generation_acceptance_closure_ready={closure_ready}"},
    {"handoff_stage_id": "05-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "generation_acceptance_closure_handoff_stage_rows.csv", list(handoff_stage_rows[0].keys()), handoff_stage_rows)

runtime_gap_rows = [
    {"gap": row["handoff_stage_id"], "status": row["status"], "evidence": row["evidence"]}
    for row in handoff_stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61ey_generation_acceptance_closure_handoff_bundle_metrics",
    "v61ex_generation_acceptance_closure_work_order_ready": "1",
    "source_gate_rows": "1",
    "handoff_stage_rows": str(len(handoff_stage_rows)),
    "ready_handoff_stage_rows": str(sum(row["status"] == "ready" for row in handoff_stage_rows)),
    "blocked_handoff_stage_rows": str(sum(row["status"] == "blocked" for row in handoff_stage_rows)),
    "handoff_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_bundle_file_rows": str(sum(row["payload_class"] == "metadata-only" for row in bundle_file_rows)),
    "validation_rows": str(len(validation_rows)),
    "ready_validation_rows": str(sum(row["ready_to_run_now"] == "1" for row in validation_rows)),
    "work_order_rows": str(len(work_rows)),
    "ready_work_order_rows": str(ready_work_rows),
    "open_blocker_rows": str(open_blocker_rows),
    "closure_command_rows": str(len(command_rows)),
    "ready_closure_command_rows": str(ready_command_rows),
    "selected_acceptance_bridge_candidate_ready": str(selected_bridge_candidate),
    "selected_acceptance_bridge_real_ready": str(selected_bridge_real),
    "generation_acceptance_closure_ready": str(closure_ready),
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ey": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "generation_acceptance_closure_handoff_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ey_generation_acceptance_closure_handoff_bundle_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["handoff_stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["evidence"]}
    for row in handoff_stage_rows
]
decision_rows.extend(
    [
        {"gate": "operator-handoff-bundle-ready", "status": "pass", "reason": "metadata-only acceptance closure bundle emitted"},
        {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "bundle file rows are metadata-only"},
        {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    ]
)
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EY_GENERATION_ACCEPTANCE_CLOSURE_HANDOFF_BUNDLE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ey Generation Acceptance Closure Handoff Bundle Boundary",
            "",
            f"- handoff_stage_rows={len(handoff_stage_rows)}",
            f"- ready_handoff_stage_rows={sum(row['status'] == 'ready' for row in handoff_stage_rows)}",
            f"- blocked_handoff_stage_rows={sum(row['status'] == 'blocked' for row in handoff_stage_rows)}",
            f"- ready_work_order_rows={ready_work_rows}",
            f"- open_blocker_rows={open_blocker_rows}",
            f"- selected_acceptance_bridge_candidate_ready={selected_bridge_candidate}",
            f"- selected_acceptance_bridge_real_ready={selected_bridge_real}",
            f"- generation_acceptance_closure_ready={closure_ready}",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- The v61ex acceptance-closure work order is packaged as a metadata-only handoff bundle.",
            "",
            "Blocked wording:",
            "- Do not claim actual generation, production latency, near-frontier quality, or release readiness from v61ey alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61ey-generation-acceptance-closure-handoff-bundle",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61ey_generation_acceptance_closure_handoff_bundle_ready": 1,
    "ready_work_order_rows": ready_work_rows,
    "open_blocker_rows": open_blocker_rows,
    "generation_acceptance_closure_ready": closure_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ey_generation_acceptance_closure_handoff_bundle_manifest.json").write_text(
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

echo "v61ey_generation_acceptance_closure_handoff_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
