#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dw_return_bundle_operator_handoff_bundle"
RUN_ID="${V61DW_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DW_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dw_return_bundle_operator_handoff_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dv_return_bundle_operator_work_order.sh" >/dev/null

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
    "v61dv_summary": results / "v61dv_return_bundle_operator_work_order_summary.csv",
    "v61dv_decision": results / "v61dv_return_bundle_operator_work_order_decision.csv",
    "v61dv_stage": results / "v61dv_return_bundle_operator_work_order/work_order_001/return_bundle_operator_work_order_stage_rows.csv",
    "v61dv_artifact": results / "v61dv_return_bundle_operator_work_order/work_order_001/return_bundle_operator_artifact_work_order_rows.csv",
    "v61dv_row": results / "v61dv_return_bundle_operator_work_order/work_order_001/return_bundle_operator_row_work_order_rows.csv",
    "v61dv_command": results / "v61dv_return_bundle_operator_work_order/work_order_001/return_bundle_operator_work_order_command_rows.csv",
    "v61dv_metric": results / "v61dv_return_bundle_operator_work_order/work_order_001/return_bundle_operator_work_order_metric_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dw source {key}: {path}")

copy(sources["v61dv_summary"], "source_v61dv/v61dv_return_bundle_operator_work_order_summary.csv")
copy(sources["v61dv_decision"], "source_v61dv/v61dv_return_bundle_operator_work_order_decision.csv")
copy(sources["v61dv_stage"], "source_v61dv/return_bundle_operator_work_order_stage_rows.csv")
copy(sources["v61dv_artifact"], "source_v61dv/return_bundle_operator_artifact_work_order_rows.csv")
copy(sources["v61dv_row"], "source_v61dv/return_bundle_operator_row_work_order_rows.csv")
copy(sources["v61dv_command"], "source_v61dv/return_bundle_operator_work_order_command_rows.csv")
copy(sources["v61dv_metric"], "source_v61dv/return_bundle_operator_work_order_metric_rows.csv")

v61dv = read_csv(sources["v61dv_summary"])[0]
stage_rows = read_csv(sources["v61dv_stage"])
artifact_rows = read_csv(sources["v61dv_artifact"])
row_rows = read_csv(sources["v61dv_row"])
command_rows = read_csv(sources["v61dv_command"])

if v61dv.get("v61dv_return_bundle_operator_work_order_ready") != "1":
    raise SystemExit("v61dw requires v61dv ready")

copy_bundle(sources["v61dv_stage"], "work_order/RETURN_BUNDLE_STAGE_ROWS.csv")
copy_bundle(sources["v61dv_artifact"], "work_order/RETURN_BUNDLE_ARTIFACT_ROWS.csv")
copy_bundle(sources["v61dv_row"], "work_order/RETURN_BUNDLE_ROW_DELTAS.csv")
copy_bundle(sources["v61dv_command"], "work_order/RETURN_BUNDLE_COMMAND_ROWS.csv")
copy_bundle(sources["v61dv_summary"], "evidence/v61dv_return_bundle_operator_work_order_summary.csv")

readme = bundle_dir / "RETURN_BUNDLE_WORK_ORDER.md"
readme.write_text(
    "\n".join(
        [
            "# v61dw Return Bundle Operator Handoff Bundle",
            "",
            "This bundle contains work-order metadata only. It contains no returned",
            "review evidence, no generation result evidence, and no model checkpoint",
            "payload.",
            "",
            "Primary files:",
            "",
            "- `work_order/RETURN_BUNDLE_STAGE_ROWS.csv`",
            "- `work_order/RETURN_BUNDLE_ARTIFACT_ROWS.csv`",
            "- `work_order/RETURN_BUNDLE_ROW_DELTAS.csv`",
            "- `work_order/RETURN_BUNDLE_COMMAND_ROWS.csv`",
            "- `READY_NOW_COMMANDS.sh`",
            "",
            "Current work-order posture:",
            "",
            f"- work_order_stage_rows={v61dv['work_order_stage_rows']}",
            f"- ready_work_order_stage_rows={v61dv['ready_work_order_stage_rows']}",
            f"- artifact_work_order_rows={v61dv['artifact_work_order_rows']}",
            f"- ready_artifact_work_order_rows={v61dv['ready_artifact_work_order_rows']}",
            f"- blocked_artifact_work_order_rows={v61dv['blocked_artifact_work_order_rows']}",
            f"- missing_payload_rows={v61dv['missing_payload_rows']}",
            f"- actual_model_generation_ready={v61dv['actual_model_generation_ready']}",
            "",
            "Generation-result artifacts remain blocked until generation execution is",
            "admitted. This bundle does not make production-latency, near-frontier,",
            "or release claims.",
            "",
        ]
    ),
    encoding="utf-8",
)

ready_commands = bundle_dir / "READY_NOW_COMMANDS.sh"
ready_lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "echo 'v61dw ready-now commands are informational; edit /path/to/final_return_bundle before running validators.'",
]
for row in stage_rows:
    if row["ready_to_execute_now"] == "1":
        ready_lines.append(f"echo {json.dumps(row['operator_command'])}")
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
            "artifact_rows = list(csv.DictReader((root / 'work_order/RETURN_BUNDLE_ARTIFACT_ROWS.csv').open(newline='', encoding='utf-8')))",
            "stage_rows = list(csv.DictReader((root / 'work_order/RETURN_BUNDLE_STAGE_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(artifact_rows) != 81:",
            "    raise SystemExit('expected 81 artifact work-order rows')",
            "if len(stage_rows) != 9:",
            "    raise SystemExit('expected 9 stage work-order rows')",
            "if sum(row['ready_to_prepare_now'] == '1' for row in artifact_rows) != 76:",
            "    raise SystemExit('expected 76 immediately preparable artifact rows')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_manifest = {
    "manifest_scope": "v61dw-return-bundle-operator-handoff-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "work_order_stage_rows": as_int(v61dv, "work_order_stage_rows"),
    "ready_work_order_stage_rows": as_int(v61dv, "ready_work_order_stage_rows"),
    "artifact_work_order_rows": as_int(v61dv, "artifact_work_order_rows"),
    "ready_artifact_work_order_rows": as_int(v61dv, "ready_artifact_work_order_rows"),
    "blocked_artifact_work_order_rows": as_int(v61dv, "blocked_artifact_work_order_rows"),
    "actual_model_generation_ready": as_int(v61dv, "actual_model_generation_ready"),
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
    rel = str(path.relative_to(bundle_dir))
    bundle_file_rows.append(
        {
            "bundle_relative_path": rel,
            "size_bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "payload_class": "metadata-only",
        }
    )
write_csv(run_dir / "return_bundle_operator_handoff_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

validation_rows = [
    {
        "validation_id": "01-verify-bundle-checksums",
        "ready_to_run_now": "1",
        "command": "results/v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/VERIFY_HANDOFF_BUNDLE.sh",
        "expected_transition": "bundle checksum and row-count checks pass",
    },
    {
        "validation_id": "02-print-ready-commands",
        "ready_to_run_now": "1",
        "command": "results/v61dw_return_bundle_operator_handoff_bundle/bundle_001/handoff_bundle/READY_NOW_COMMANDS.sh",
        "expected_transition": "operator sees ready-now command list without executing validators",
    },
    {
        "validation_id": "03-run-work-order-after-return",
        "ready_to_run_now": "0",
        "command": "V61DT_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DT_REUSE_EXISTING=0 ./experiments/run_v61dt_return_bundle_closure_replay_gate.sh",
        "expected_transition": "schema/full preflight progresses only after returned artifacts are supplied",
    },
]
write_csv(run_dir / "return_bundle_operator_handoff_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

handoff_stage_rows = [
    {"handoff_stage_id": "01-work-order-source", "status": "ready", "evidence": "v61dv_return_bundle_operator_work_order_ready=1"},
    {"handoff_stage_id": "02-bundle-metadata", "status": "ready", "evidence": f"handoff_bundle_file_rows={len(bundle_file_rows)}"},
    {"handoff_stage_id": "03-bundle-verifier", "status": "ready", "evidence": "VERIFY_HANDOFF_BUNDLE.sh"},
    {"handoff_stage_id": "04-return-evidence", "status": "blocked", "evidence": "no returned review/generation evidence included"},
    {"handoff_stage_id": "05-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "return_bundle_operator_handoff_stage_rows.csv", list(handoff_stage_rows[0].keys()), handoff_stage_rows)

metric = {
    "metric_id": "v61dw_return_bundle_operator_handoff_bundle_metrics",
    "v61dv_return_bundle_operator_work_order_ready": v61dv["v61dv_return_bundle_operator_work_order_ready"],
    "source_gate_rows": "1",
    "handoff_stage_rows": str(len(handoff_stage_rows)),
    "ready_handoff_stage_rows": str(sum(row["status"] == "ready" for row in handoff_stage_rows)),
    "blocked_handoff_stage_rows": str(sum(row["status"] == "blocked" for row in handoff_stage_rows)),
    "handoff_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_bundle_file_rows": str(sum(row["payload_class"] == "metadata-only" for row in bundle_file_rows)),
    "validation_rows": str(len(validation_rows)),
    "ready_validation_rows": str(sum(row["ready_to_run_now"] == "1" for row in validation_rows)),
    "work_order_stage_rows": v61dv["work_order_stage_rows"],
    "ready_work_order_stage_rows": v61dv["ready_work_order_stage_rows"],
    "artifact_work_order_rows": v61dv["artifact_work_order_rows"],
    "ready_artifact_work_order_rows": v61dv["ready_artifact_work_order_rows"],
    "blocked_artifact_work_order_rows": v61dv["blocked_artifact_work_order_rows"],
    "missing_payload_rows": v61dv["missing_payload_rows"],
    "actual_model_generation_ready": v61dv["actual_model_generation_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61dw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_bundle_operator_handoff_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dw_return_bundle_operator_handoff_bundle_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["handoff_stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["evidence"]}
    for row in handoff_stage_rows
]
decision_rows.extend(
    [
        {"gate": "operator-handoff-bundle-ready", "status": "pass", "reason": "metadata-only bundle and verifier emitted"},
        {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
        {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["handoff_stage_id"], "status": row["status"], "reason": row["evidence"]}
    for row in handoff_stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dw Return Bundle Operator Handoff Bundle

This gate packages the v61dv operator work order as a metadata-only handoff
bundle. It ships checksums, CSV ledgers, a verifier, and a ready-command
printer. It does not include returned review evidence, generation result
evidence, or model checkpoint payloads.

Evidence emitted:

- handoff_stage_rows={len(handoff_stage_rows)}
- ready_handoff_stage_rows={metric['ready_handoff_stage_rows']}
- blocked_handoff_stage_rows={metric['blocked_handoff_stage_rows']}
- handoff_bundle_file_rows={len(bundle_file_rows)}
- metadata_only_bundle_file_rows={metric['metadata_only_bundle_file_rows']}
- validation_rows={len(validation_rows)}
- ready_validation_rows={metric['ready_validation_rows']}
- artifact_work_order_rows={v61dv['artifact_work_order_rows']}
- ready_artifact_work_order_rows={v61dv['ready_artifact_work_order_rows']}
- blocked_artifact_work_order_rows={v61dv['blocked_artifact_work_order_rows']}
- missing_payload_rows={v61dv['missing_payload_rows']}
- actual_model_generation_ready={v61dv['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dw=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: metadata-only operator handoff bundle is ready.
Blocked wording: returned evidence accepted, actual generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DW_RETURN_BUNDLE_OPERATOR_HANDOFF_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dw-return-bundle-operator-handoff-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dw_return_bundle_operator_handoff_bundle_ready": 1,
    "handoff_bundle_file_rows": len(bundle_file_rows),
    "metadata_only_bundle_file_rows": len(bundle_file_rows),
    "validation_rows": len(validation_rows),
    "ready_validation_rows": int(metric["ready_validation_rows"]),
    "actual_model_generation_ready": as_int(v61dv, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_downloaded_by_v61dw": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dw_return_bundle_operator_handoff_bundle_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"v61dw_return_bundle_operator_handoff_bundle_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
