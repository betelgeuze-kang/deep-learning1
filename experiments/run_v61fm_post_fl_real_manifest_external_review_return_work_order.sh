#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fm_post_fl_real_manifest_external_review_return_work_order"
RUN_ID="${V61FM_RUN_ID:-work_order_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
HANDOFF_RUN_DIR_ARG="${V61FM_HANDOFF_RUN_DIR:-}"

if [[ "${V61FM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fm_post_fl_real_manifest_external_review_return_work_order_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$HANDOFF_RUN_DIR_ARG" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
handoff_arg = sys.argv[5].strip()
results = root / "results"
default_handoff_dir = results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard" / "guard_001"
handoff_dir = Path(handoff_arg).expanduser().resolve() if handoff_arg else default_handoff_dir
work_package_dir = run_dir / "real_manifest_external_review_return_work_order"
work_package_dir.mkdir(parents=True, exist_ok=True)


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61fl_summary": results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_summary.csv",
    "v61fl_decision": results / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_decision.csv",
    "v61fh_summary": results / "v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
    "v61fh_decision": results / "v61fh_post_fg_real_manifest_external_review_return_intake_decision.csv",
    "v61fk_summary": results / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_summary.csv",
    "v61fk_decision": results / "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fm source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_handoff_files = {
    "handoff_metric_rows.csv": handoff_dir / "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv",
    "handoff_stage_rows.csv": handoff_dir / "post_fk_real_manifest_external_review_return_handoff_stage_rows.csv",
    "handoff_requirement_rows.csv": handoff_dir / "post_fk_real_manifest_external_review_return_handoff_requirement_rows.csv",
    "handoff_command_rows.csv": handoff_dir / "post_fk_real_manifest_external_review_return_handoff_command_rows.csv",
    "handoff_manifest.json": handoff_dir / "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_manifest.json",
}
for rel, path in selected_handoff_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61fm handoff artifact: {path}")
    copy(path, f"selected_handoff/{rel}")

v61fl = read_csv(sources["v61fl_summary"])[0]
v61fh = read_csv(sources["v61fh_summary"])[0]
v61fk = read_csv(sources["v61fk_summary"])[0]
if v61fl.get("v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready") != "1":
    raise SystemExit("v61fm requires v61fl readiness")
if v61fh.get("v61fh_post_fg_real_manifest_external_review_return_intake_ready") != "1":
    raise SystemExit("v61fm requires v61fh readiness")
if v61fk.get("v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready") != "1":
    raise SystemExit("v61fm requires v61fk readiness")

handoff_metric = read_csv(handoff_dir / "post_fk_real_manifest_external_review_return_handoff_metric_rows.csv")[0]
required_artifacts_path = results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001" / "real_manifest_external_review_required_artifact_rows.csv"
artifact_status_path = results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001" / "real_manifest_external_review_return_artifact_status_rows.csv"
template_rows_path = results / "v61fj_post_fi_real_manifest_external_review_send_return_bundle" / "bundle_001" / "post_fi_real_manifest_external_review_return_template_rows.csv"
for src, rel in [
    (required_artifacts_path, "source_v61fh/real_manifest_external_review_required_artifact_rows.csv"),
    (artifact_status_path, "source_v61fh/real_manifest_external_review_return_artifact_status_rows.csv"),
    (template_rows_path, "source_v61fj/post_fi_real_manifest_external_review_return_template_rows.csv"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61fm artifact source: {src}")
    copy(src, rel)

required_artifacts = read_csv(required_artifacts_path)
artifact_status = {row["artifact_id"]: row for row in read_csv(artifact_status_path)}
template_rows = {row["artifact_id"]: row for row in read_csv(template_rows_path)}

work_rows = []
for index, artifact in enumerate(required_artifacts, start=1):
    status_row = artifact_status.get(artifact["artifact_id"], {})
    template_row = template_rows.get(artifact["artifact_id"], {})
    accepted_now = status_row.get("accepted", "0") == "1"
    supplied_now = status_row.get("supplied", "0") == "1"
    work_rows.append(
        {
            "work_item_id": f"review_return_{index:02d}",
            "artifact_id": artifact["artifact_id"],
            "relative_path": artifact["relative_path"],
            "artifact_type": artifact["artifact_type"],
            "required_rows": artifact["required_rows"],
            "required_fields": artifact["required_fields"],
            "template_artifact": template_row.get("template_artifact", ""),
            "ready_to_prepare": "1",
            "supplied_now": str(int(supplied_now)),
            "accepted_now": str(int(accepted_now)),
            "acceptance_blocked": str(int(not accepted_now)),
            "blocks_replay": "1",
            "blocks_actual_generation": "1",
            "operator_action": "fill-real-review-evidence-and-rerun-v61fh",
        }
    )
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_rows.csv", list(work_rows[0].keys()), work_rows)
write_csv(work_package_dir / "REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.csv", list(work_rows[0].keys()), work_rows)

field_rows = []
for row in work_rows:
    fields = [field for field in row["required_fields"].split(";") if field]
    for field in fields:
        field_rows.append(
            {
                "artifact_id": row["artifact_id"],
                "relative_path": row["relative_path"],
                "required_field": field,
                "field_ready_to_collect": "1",
                "accepted_now": row["accepted_now"],
            }
        )
write_csv(run_dir / "post_fl_real_manifest_external_review_return_field_work_rows.csv", list(field_rows[0].keys()), field_rows)
write_csv(work_package_dir / "REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_FIELD_WORK_ROWS.csv", list(field_rows[0].keys()), field_rows)

readme = work_package_dir / "REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.md"
readme.write_text(
    "\n".join(
        [
            "# v61fm Real Manifest External Review Return Work Order",
            "",
            "This work order lists the six real review-return artifacts required by v61fh.",
            "It is a metadata-only operator checklist and is not accepted review evidence.",
            "",
            "Fill the artifacts outside this package, then run:",
            "",
            "```bash",
            "V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/real/review-return ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh",
            "./experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh",
            "./experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh",
            "```",
            "",
            "Dispatch receipts prove transfer logistics only. They do not replace the six review-return artifacts.",
            "actual_model_generation_ready=0 until accepted review return, replay admission, row acceptance, and generation-result evidence close.",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = work_package_dir / "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "from pathlib import Path",
            "root = Path('.')",
            "rows = list(csv.DictReader((root / 'REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.csv').open(newline='', encoding='utf-8')))",
            "if len(rows) != 6:",
            "    raise SystemExit(f'expected six work rows, got {len(rows)}')",
            "if any(row['ready_to_prepare'] != '1' for row in rows):",
            "    raise SystemExit('all review-return artifacts should be ready to prepare')",
            "if any(row['accepted_now'] != '0' for row in rows):",
            "    raise SystemExit('work order must not count accepted review evidence')",
            "fields = list(csv.DictReader((root / 'REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_FIELD_WORK_ROWS.csv').open(newline='', encoding='utf-8')))",
"if len(fields) != 32:",
"    raise SystemExit(f'expected 32 field rows, got {len(fields)}')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

command_rows = [
    {
        "command_id": "verify-work-order",
        "command": "bash results/v61fm_post_fl_real_manifest_external_review_return_work_order/work_order_001/real_manifest_external_review_return_work_order/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER.sh",
        "ready_to_run_now": "1",
        "purpose": "verify the metadata-only work order",
    },
    {
        "command_id": "verify-dispatch-handoff-guard",
        "command": "V61FL_REUSE_EXISTING=1 ./experiments/test_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh",
        "ready_to_run_now": "1",
        "purpose": "verify receipt cannot substitute for review return",
    },
    {
        "command_id": "submit-real-review-return",
        "command": "V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/real/review-return ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh",
        "ready_to_run_now": "0",
        "purpose": "requires six real review-return artifacts",
    },
    {
        "command_id": "refresh-review-acceptance",
        "command": "./experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh",
        "ready_to_run_now": "0",
        "purpose": "only after real review return is accepted",
    },
    {
        "command_id": "refresh-return-handoff",
        "command": "./experiments/run_v61fl_post_fk_real_manifest_external_review_return_handoff_guard.sh",
        "ready_to_run_now": "0",
        "purpose": "only after accepted review return and optional real dispatch receipt",
    },
    {
        "command_id": "replay-admission-chain",
        "command": "./experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh",
        "ready_to_run_now": "0",
        "purpose": "blocked until accepted real return evidence",
    },
]
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_command_rows.csv", list(command_rows[0].keys()), command_rows)

stage_rows = [
    {"stage_id": "01-dispatch-package", "status": "ready", "ready": "1", "reason": f"dispatch_archive_ready={handoff_metric['dispatch_archive_ready']}"},
    {"stage_id": "02-return-intake-contract", "status": "ready", "ready": "1", "reason": "v61fh contract exists"},
    {"stage_id": "03-work-order-issued", "status": "ready", "ready": "1", "reason": "six artifact rows emitted"},
    {"stage_id": "04-real-review-return-supplied", "status": "blocked", "ready": "0", "reason": f"accepted_review_return_artifacts={v61fh['accepted_review_return_artifacts']}/{v61fh['required_review_return_artifacts']}"},
    {"stage_id": "05-review-return-accepted", "status": "blocked", "ready": "0", "reason": f"external_review_return_ready={handoff_metric['external_review_return_ready']}"},
    {"stage_id": "06-replay-row-acceptance", "status": "blocked", "ready": "0", "reason": f"real_return_replay_admission_ready={handoff_metric['real_return_replay_admission_ready']}; row_acceptance_ready={handoff_metric['row_acceptance_ready']}"},
    {"stage_id": "07-actual-generation", "status": "blocked", "ready": "0", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "v61fl-handoff-guard", "status": "pass", "required_value": "1", "actual_value": v61fl["v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready"], "reason": "handoff guard is ready"},
    {"requirement_id": "v61fh-review-return-contract", "status": "pass", "required_value": "6", "actual_value": v61fh["required_review_return_artifacts"], "reason": "six review-return artifacts defined"},
    {"requirement_id": "work-order-issued", "status": "pass", "required_value": "6", "actual_value": str(len(work_rows)), "reason": "one work row per required artifact"},
    {"requirement_id": "all-work-ready-to-prepare", "status": "pass", "required_value": "6", "actual_value": str(sum(row["ready_to_prepare"] == "1" for row in work_rows)), "reason": "all reviewer work items are specified"},
    {"requirement_id": "accepted-review-return-artifacts", "status": "blocked", "required_value": v61fh["required_review_return_artifacts"], "actual_value": v61fh["accepted_review_return_artifacts"], "reason": "real review evidence not supplied"},
    {"requirement_id": "external-review-return", "status": "blocked", "required_value": "1", "actual_value": handoff_metric["external_review_return_ready"], "reason": "work order is not accepted evidence"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
    {"requirement_id": "repo-checkpoint-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "metadata-only work order"},
]
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

file_targets = sorted(path for path in work_package_dir.rglob("*") if path.is_file())
file_rows = []
for path in file_targets:
    rel = str(path.relative_to(work_package_dir))
    file_rows.append(
        {
            "work_package_file": rel,
            "size_bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only_file": "1",
            "payload_like_file": "1" if path.suffix in {".safetensors", ".bin", ".pt"} else "0",
        }
    )
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_file_rows.csv", list(file_rows[0].keys()), file_rows)

(work_package_dir / "WORK_ORDER_FILE_LIST.txt").write_text("\n".join(row["work_package_file"] for row in file_rows) + "\n", encoding="utf-8")
sha_targets = sorted(path for path in work_package_dir.rglob("*") if path.is_file() and path.name != "WORK_ORDER_SHA256SUMS.txt")
(work_package_dir / "WORK_ORDER_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(work_package_dir)}\n" for path in sha_targets),
    encoding="utf-8",
)
file_rows = []
for path in sorted(work_package_dir.rglob("*")):
    if path.is_file():
        rel = str(path.relative_to(work_package_dir))
        file_rows.append(
            {
                "work_package_file": rel,
                "size_bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "metadata_only_file": "1",
                "payload_like_file": "1" if path.suffix in {".safetensors", ".bin", ".pt"} else "0",
            }
        )
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_file_rows.csv", list(file_rows[0].keys()), file_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
accepted_work_rows = sum(row["accepted_now"] == "1" for row in work_rows)
summary = {
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": "1",
    "v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready": v61fl["v61fl_post_fk_real_manifest_external_review_return_handoff_guard_ready"],
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": v61fh["v61fh_post_fg_real_manifest_external_review_return_intake_ready"],
    "v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready": v61fk["v61fk_post_fj_real_manifest_external_review_dispatch_archive_receipt_gate_ready"],
    "selected_handoff_dispatch_source_class": handoff_metric["selected_dispatch_source_class"],
    "dispatch_archive_ready": handoff_metric["dispatch_archive_ready"],
    "dispatch_receipt_candidate_preflight_ready": handoff_metric["dispatch_receipt_candidate_preflight_ready"],
    "real_dispatch_receipt_ready": handoff_metric["real_dispatch_receipt_ready"],
    "required_review_return_artifacts": v61fh["required_review_return_artifacts"],
    "work_order_rows": str(len(work_rows)),
    "immediately_preparable_work_order_rows": str(sum(row["ready_to_prepare"] == "1" for row in work_rows)),
    "accepted_work_order_rows": str(accepted_work_rows),
    "acceptance_blocked_work_order_rows": str(sum(row["acceptance_blocked"] == "1" for row in work_rows)),
    "field_work_rows": str(len(field_rows)),
    "work_package_file_rows": str(len(file_rows)),
    "metadata_only_work_package_file_rows": str(sum(row["metadata_only_file"] == "1" for row in file_rows)),
    "payload_like_work_package_file_rows": str(sum(row["payload_like_file"] == "1" for row in file_rows)),
    "accepted_review_return_artifacts": v61fh["accepted_review_return_artifacts"],
    "missing_review_return_artifacts": v61fh["missing_review_return_artifacts"],
    "external_review_return_ready": handoff_metric["external_review_return_ready"],
    "receipt_to_review_return_handoff_ready": handoff_metric["receipt_to_review_return_handoff_ready"],
    "real_return_replay_admission_ready": handoff_metric["real_return_replay_admission_ready"],
    "row_acceptance_ready": handoff_metric["row_acceptance_ready"],
    "actual_model_generation_ready": "0",
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(ready_stage_rows),
    "blocked_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "blocked_command_rows": str(len(command_rows) - ready_command_rows),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fm": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_fl_real_manifest_external_review_return_work_order_metric_rows.csv", list(summary.keys()), [summary])
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["requirement_id"], "status": row["status"], "reason": row["reason"]}
    for row in requirement_rows
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FM_POST_FL_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_WORK_ORDER_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fm Post-v61fl Real Manifest External Review Return Work Order Boundary",
            "",
            f"- work_order_rows={summary['work_order_rows']}",
            f"- immediately_preparable_work_order_rows={summary['immediately_preparable_work_order_rows']}",
            f"- accepted_work_order_rows={summary['accepted_work_order_rows']}",
            f"- acceptance_blocked_work_order_rows={summary['acceptance_blocked_work_order_rows']}",
            f"- field_work_rows={summary['field_work_rows']}",
            f"- work_package_file_rows={summary['work_package_file_rows']}",
            f"- accepted_review_return_artifacts={summary['accepted_review_return_artifacts']}/{summary['required_review_return_artifacts']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- receipt_to_review_return_handoff_ready={summary['receipt_to_review_return_handoff_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fm issues a metadata-only six-artifact real review-return work order.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fm alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61fm_post_fl_real_manifest_external_review_return_work_order",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fm_post_fl_real_manifest_external_review_return_work_order_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fm_post_fl_real_manifest_external_review_return_work_order_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
