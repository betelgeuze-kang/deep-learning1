#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gv_post_gu_first_real_slice_workspace_gap_audit"
RUN_ID="${V61GV_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61GV_WORK_ROOT:-${V61GU_WORK_ROOT:-}}"

if [[ "${V61GV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gv_post_gu_first_real_slice_workspace_gap_audit_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gu_post_gt_first_real_slice_operator_workspace_initializer.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$WORK_ROOT" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
work_root_raw = sys.argv[6].strip()
results = root / "results"
prefix = "v61gv_post_gu_first_real_slice_workspace_gap_audit"
package_dir = run_dir / "first_real_slice_workspace_gap_audit"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

GU_PREFIX = "v61gu_post_gt_first_real_slice_operator_workspace_initializer"
WITNESS_FILES = [
    "review_comment.txt",
    "adjudication_reason.txt",
    "credential_statement.txt",
    "conflict_statement.txt",
    "answer_text.txt",
    "run_transcript.txt",
    "source_file.txt",
]
PATH_ENV = [
    "V61GI_CONTENT_WITNESS_DIR",
    "V61GI_MINIMAL_SLICE_ROWS_CSV",
    "V61GI_OPERATOR_INPUT_ROOT",
    "V61GI_OUTPUT_ROOT",
]
VALUE_ENV = [
    "V61GI_REVIEWER_ID",
    "V61GI_ADJUDICATOR_ID",
    "V61GI_GENERATION_ID",
    "V61GI_CITATION_ID",
    "V61GI_CHECKPOINT_ROOT",
    "V61GI_LATENCY_ROW_ID",
    "V61GI_PROMPT_TOKENS",
    "V61GI_OUTPUT_TOKENS",
    "V61GI_PREFILL_MS",
    "V61GI_DECODE_MS",
    "V61GI_TOTAL_MS",
    "V61GI_TOKENS_PER_SECOND",
    "V61GI_V53_AUTHORITY_STATEMENT",
    "V61GI_V61_AUTHORITY_STATEMENT",
    "V61GI_EXTERNAL_RETURN_ATTESTATION",
    "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT",
]
NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


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


def has_nonfinal_text(text):
    lowered = text.lower()
    return any(token in lowered for token in NONFINAL_TOKENS)


def unquote_env(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


source_paths = {
    "v61gu_summary": results / f"{GU_PREFIX}_summary.csv",
    "v61gu_decision": results / f"{GU_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gv source {label}: {path}")
source_rows = [copy_source(label, path, "source_v61gu") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_workspace_gap_source_rows.csv", list(source_rows[0].keys()), source_rows)

gu = read_csv(source_paths["v61gu_summary"])[0]
if gu.get("v61gu_post_gt_first_real_slice_operator_workspace_initializer_ready") != "1":
    raise SystemExit("v61gv requires v61gu ready")

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
expected_dirs = [
    "final_content_witness",
    "content_witness_templates",
    "minimal_slice",
    "operator_roots/operator_input_root",
    "operator_roots/output_root",
]
layout_rows = []
for rel in expected_dirs:
    path = work_root / rel if work_root else None
    exists = int(path is not None and path.is_dir())
    layout_rows.append({
        "layout_item": rel,
        "expected_path": str(path) if path else "",
        "exists": str(exists),
        "ready": str(exists),
    })
write_csv(run_dir / "first_real_slice_workspace_layout_rows.csv", list(layout_rows[0].keys()), layout_rows)
workspace_layout_ready = int(work_root_exists and work_root_outside_repo and all(row["ready"] == "1" for row in layout_rows))

witness_rows = []
for filename in WITNESS_FILES:
    path = work_root / "final_content_witness" / filename if work_root else None
    exists = int(path is not None and path.is_file())
    bytes_value = path.stat().st_size if exists else 0
    digest = sha256(path) if exists else ""
    nonfinal = 0
    if exists:
        try:
            nonfinal = int(has_nonfinal_text(path.read_text(encoding="utf-8", errors="replace")))
        except OSError:
            nonfinal = 1
    ready = int(exists and bytes_value > 0 and not nonfinal)
    witness_rows.append({
        "witness_file": filename,
        "expected_path": str(path) if path else "",
        "exists": str(exists),
        "bytes": str(bytes_value),
        "sha256": digest,
        "nonfinal_text_detected": str(nonfinal),
        "ready_for_preflight": str(ready),
        "accepted_as_real_evidence": "0",
    })
write_csv(run_dir / "first_real_slice_workspace_witness_rows.csv", list(witness_rows[0].keys()), witness_rows)
ready_witness_rows = sum(row["ready_for_preflight"] == "1" for row in witness_rows)
content_witness_gap_closed = int(ready_witness_rows == len(WITNESS_FILES))

env_values = {}
env_template_path = work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh" if work_root else None
env_template_exists = int(env_template_path is not None and env_template_path.is_file())
if env_template_exists:
    export_re = re.compile(r"^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
    for line in env_template_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = export_re.match(line.strip())
        if match:
            env_values[match.group(1)] = unquote_env(match.group(2))

env_rows = []
for key in PATH_ENV + VALUE_ENV:
    value = env_values.get(key, "")
    placeholder = int((not value) or "REPLACE_WITH" in value or has_nonfinal_text(value))
    path_ready = ""
    if key in PATH_ENV:
        path = Path(value).expanduser() if value else None
        if key == "V61GI_MINIMAL_SLICE_ROWS_CSV":
            path_ready = str(int(path is not None and path.parent.is_dir()))
        else:
            path_ready = str(int(path is not None and path.exists()))
    ready = int(not placeholder and (path_ready in {"", "1"}))
    env_rows.append({
        "env_var": key,
        "env_family": "path" if key in PATH_ENV else "value",
        "present_in_template": str(int(key in env_values)),
        "placeholder_or_nonfinal": str(placeholder),
        "path_ready": path_ready,
        "ready_for_preflight": str(ready),
    })
write_csv(run_dir / "first_real_slice_workspace_env_rows.csv", list(env_rows[0].keys()), env_rows)
ready_path_env_rows = sum(row["env_family"] == "path" and row["ready_for_preflight"] == "1" for row in env_rows)
ready_value_env_rows = sum(row["env_family"] == "value" and row["ready_for_preflight"] == "1" for row in env_rows)
env_gap_closed = int(ready_path_env_rows == len(PATH_ENV) and ready_value_env_rows == len(VALUE_ENV))

runner_path = work_root / "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh" if work_root else None
verifier_path = work_root / "VERIFY_FIRST_REAL_SLICE_WORKSPACE.sh" if work_root else None
runner_executable = int(runner_path is not None and runner_path.is_file() and runner_path.stat().st_mode & 0o111 != 0)
verifier_executable = int(verifier_path is not None and verifier_path.is_file() and verifier_path.stat().st_mode & 0o111 != 0)
workspace_gap_preflight_ready = int(workspace_layout_ready and content_witness_gap_closed and env_gap_closed and runner_executable and verifier_executable)

missing_rows = []
for row in layout_rows:
    if row["ready"] != "1":
        missing_rows.append({
            "item_id": f"layout:{row['layout_item']}",
            "item_family": "workspace-layout",
            "path_or_env": row["expected_path"],
            "status": "missing",
            "next_action": f"initialize workspace directory {row['layout_item']}",
        })
for row in witness_rows:
    if row["ready_for_preflight"] != "1":
        reason = "missing" if row["exists"] != "1" else "empty-or-nonfinal"
        missing_rows.append({
            "item_id": f"witness:{row['witness_file']}",
            "item_family": "content-witness",
            "path_or_env": row["expected_path"],
            "status": reason,
            "next_action": "write final external witness text; do not copy template text",
        })
for row in env_rows:
    if row["ready_for_preflight"] != "1":
        missing_rows.append({
            "item_id": f"env:{row['env_var']}",
            "item_family": "env-value",
            "path_or_env": row["env_var"],
            "status": "placeholder-or-path-not-ready",
            "next_action": "replace value in FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
        })
if not runner_executable:
    missing_rows.append({
        "item_id": "runner:RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh",
        "item_family": "workspace-runner",
        "path_or_env": str(runner_path) if runner_path else "",
        "status": "missing-or-not-executable",
        "next_action": "rerun v61gu workspace initializer",
    })
if not missing_rows:
    missing_rows.append({
        "item_id": "none",
        "item_family": "none",
        "path_or_env": "",
        "status": "no-gap-detected",
        "next_action": "run RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh after external finalization",
    })
write_csv(run_dir / "first_real_slice_workspace_missing_item_rows.csv", list(missing_rows[0].keys()), missing_rows)
open_gap_rows = sum(row["status"] != "no-gap-detected" for row in missing_rows)

stage_rows = [
    {"stage_id": "01-v61gu-source", "status": "ready", "evidence": "v61gu ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-workspace-layout", "status": "ready" if workspace_layout_ready else "blocked", "evidence": f"workspace_layout_ready={workspace_layout_ready}"},
    {"stage_id": "04-content-witness-gap", "status": "ready" if content_witness_gap_closed else "blocked", "evidence": f"ready_witness_rows={ready_witness_rows}/{len(WITNESS_FILES)}"},
    {"stage_id": "05-path-env-gap", "status": "ready" if ready_path_env_rows == len(PATH_ENV) else "blocked", "evidence": f"ready_path_env_rows={ready_path_env_rows}/{len(PATH_ENV)}"},
    {"stage_id": "06-value-env-gap", "status": "ready" if ready_value_env_rows == len(VALUE_ENV) else "blocked", "evidence": f"ready_value_env_rows={ready_value_env_rows}/{len(VALUE_ENV)}"},
    {"stage_id": "07-final-runner", "status": "ready" if runner_executable else "blocked", "evidence": f"runner_executable={runner_executable}"},
    {"stage_id": "08-workspace-gap-preflight", "status": "ready" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}; open_gap_rows={open_gap_rows}"},
    {"stage_id": "09-real-return-execution", "status": "blocked", "evidence": "audit never executes final replay"},
    {"stage_id": "10-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "first_real_slice_workspace_gap_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-gap-audit", "ready_to_run_now": "1", "command": "results/v61gv_post_gu_first_real_slice_workspace_gap_audit/audit_001/first_real_slice_workspace_gap_audit/VERIFY_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT.sh", "purpose": "verify this metadata audit package"},
    {"command_id": "02-print-missing-items", "ready_to_run_now": "1", "command": "results/v61gv_post_gu_first_real_slice_workspace_gap_audit/audit_001/first_real_slice_workspace_gap_audit/PRINT_MISSING_FIRST_REAL_SLICE_ITEMS.sh", "purpose": "print current missing witness/env items"},
    {"command_id": "03-run-final-witness-path", "ready_to_run_now": str(workspace_gap_preflight_ready), "command": "<work-root>/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR.sh", "purpose": "execute only after external finalization"},
]
write_csv(run_dir / "first_real_slice_workspace_gap_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_WORKSPACE_LAYOUT_ROWS.csv", run_dir / "first_real_slice_workspace_layout_rows.csv"),
    ("FIRST_REAL_SLICE_WORKSPACE_WITNESS_ROWS.csv", run_dir / "first_real_slice_workspace_witness_rows.csv"),
    ("FIRST_REAL_SLICE_WORKSPACE_ENV_ROWS.csv", run_dir / "first_real_slice_workspace_env_rows.csv"),
    ("FIRST_REAL_SLICE_WORKSPACE_MISSING_ITEM_ROWS.csv", run_dir / "first_real_slice_workspace_missing_item_rows.csv"),
    ("FIRST_REAL_SLICE_WORKSPACE_GAP_STAGE_ROWS.csv", run_dir / "first_real_slice_workspace_gap_stage_rows.csv"),
    ("FIRST_REAL_SLICE_WORKSPACE_GAP_COMMAND_ROWS.csv", run_dir / "first_real_slice_workspace_gap_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WORKSPACE_GAP_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WORKSPACE_LAYOUT_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WORKSPACE_WITNESS_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WORKSPACE_ENV_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WORKSPACE_MISSING_ITEM_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WORKSPACE_GAP_STAGE_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gv package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT.sh").chmod(0o755)

(package_dir / "PRINT_MISSING_FIRST_REAL_SLICE_ITEMS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "cat \"$DIR/FIRST_REAL_SLICE_WORKSPACE_MISSING_ITEM_ROWS.csv\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "PRINT_MISSING_FIRST_REAL_SLICE_ITEMS.sh").chmod(0o755)

summary = {
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "v61gu_post_gt_first_real_slice_operator_workspace_initializer_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "workspace_layout_ready": workspace_layout_ready,
    "env_template_exists": env_template_exists,
    "final_runner_executable": runner_executable,
    "workspace_verifier_executable": verifier_executable,
    "witness_rows": len(witness_rows),
    "ready_witness_rows": ready_witness_rows,
    "content_witness_gap_closed": content_witness_gap_closed,
    "env_rows": len(env_rows),
    "path_env_rows": len(PATH_ENV),
    "ready_path_env_rows": ready_path_env_rows,
    "value_env_rows": len(VALUE_ENV),
    "ready_value_env_rows": ready_value_env_rows,
    "env_gap_closed": env_gap_closed,
    "workspace_gap_preflight_ready": workspace_gap_preflight_ready,
    "missing_item_rows": len(missing_rows),
    "open_gap_rows": open_gap_rows,
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "row_acceptance_ready": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "authority_bound_replay_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gv": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows),
    "payload_like_package_file_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "work_root": str(work_root) if work_root else "",
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_WORKSPACE_GAP_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "first_real_slice_workspace_gap_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = len(package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gu-ready", "status": "pass", "evidence": "v61gu ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "workspace-layout", "status": "pass" if workspace_layout_ready else "blocked", "evidence": f"workspace_layout_ready={workspace_layout_ready}"},
    {"gate": "content-witness-gap", "status": "pass" if content_witness_gap_closed else "blocked", "evidence": f"ready_witness_rows={ready_witness_rows}/{len(WITNESS_FILES)}"},
    {"gate": "env-gap", "status": "pass" if env_gap_closed else "blocked", "evidence": f"ready_path_env_rows={ready_path_env_rows}/{len(PATH_ENV)}; ready_value_env_rows={ready_value_env_rows}/{len(VALUE_ENV)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if workspace_gap_preflight_ready else "blocked", "evidence": f"workspace_gap_preflight_ready={workspace_gap_preflight_ready}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "audit never executes final replay"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GV_POST_GU_FIRST_REAL_SLICE_WORKSPACE_GAP_AUDIT_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GV Post-GU First Real Slice Workspace Gap Audit",
        "",
        "- v61gv_post_gu_first_real_slice_workspace_gap_audit_ready=1",
        f"- workspace_gap_preflight_ready={workspace_gap_preflight_ready}",
        f"- open_gap_rows={open_gap_rows}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this audits the external workspace only. It does not execute final replay or count witness/env files as real evidence.",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gv": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gv_post_gu_first_real_slice_workspace_gap_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
