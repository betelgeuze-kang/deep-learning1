#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher"
RUN_ID="${V61HG_RUN_ID:-operator_replay_handoff_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HG_WORK_ROOT:-${V61HF_WORK_ROOT:-${V61GU_WORK_ROOT:-}}}"
PUBLISH_HANDOFF="${V61HG_PUBLISH_HANDOFF:-0}"
GV_RUN_ID="${V61HG_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61HG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hf_post_he_first_real_slice_filled_form_handoff_publisher.sh" >/dev/null
V61GO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null
V61GP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh" >/dev/null
V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_HANDOFF" <<'PY'
import csv
import hashlib
import json
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
gv_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher"
package_dir = run_dir / "first_real_slice_operator_replay_handoff_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HF_PREFIX = "v61hf_post_he_first_real_slice_filled_form_handoff_publisher"
GO_PREFIX = "v61go_post_gn_first_real_slice_operator_input_materializer"
GP_PREFIX = "v61gp_post_go_first_real_slice_dual_replay_executor"
GV_PREFIX = "v61gv_post_gu_first_real_slice_workspace_gap_audit"


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


gv_run_dir = results / GV_PREFIX / gv_run_id
source_paths = {
    "v61hf_summary": results / f"{HF_PREFIX}_summary.csv",
    "v61hf_decision": results / f"{HF_PREFIX}_decision.csv",
    "v61go_summary": results / f"{GO_PREFIX}_summary.csv",
    "v61go_decision": results / f"{GO_PREFIX}_decision.csv",
    "v61gp_summary": results / f"{GP_PREFIX}_summary.csv",
    "v61gp_decision": results / f"{GP_PREFIX}_decision.csv",
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
    "v61go_runner": root / "experiments" / "run_v61go_post_gn_first_real_slice_operator_input_materializer.sh",
    "v61gp_runner": root / "experiments" / "run_v61gp_post_go_first_real_slice_dual_replay_executor.sh",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hg source {label}: {path}")
source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61hf"):
        folder = "source_v61hf"
    elif label.startswith("v61go"):
        folder = "source_v61go"
    elif label.startswith("v61gp"):
        folder = "source_v61gp"
    else:
        folder = "source_v61gv"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_operator_replay_handoff_source_rows.csv", list(source_rows[0].keys()), source_rows)

hf = read_csv(source_paths["v61hf_summary"])[0]
go = read_csv(source_paths["v61go_summary"])[0]
gp = read_csv(source_paths["v61gp_summary"])[0]
gv = read_csv(source_paths["v61gv_summary"])[0]
if hf.get("v61hf_post_he_first_real_slice_filled_form_handoff_publisher_ready") != "1":
    raise SystemExit("v61hg requires v61hf ready")
if go.get("v61go_post_gn_first_real_slice_operator_input_materializer_ready") != "1":
    raise SystemExit("v61hg requires v61go ready")
if gp.get("v61gp_post_go_first_real_slice_dual_replay_executor_ready") != "1":
    raise SystemExit("v61hg requires v61gp ready")
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61hg requires v61gv ready")

handoff_text = f"""#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR={shlex.quote(str(root))}
WORK_ROOT="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
FORM_PATH="${{V61HG_FORM_PATH:-$WORK_ROOT/external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json}}"
OPERATOR_WORK_ROOT="${{V61HG_OPERATOR_WORK_ROOT:-$WORK_ROOT/operator_partial_return}}"
MINIMAL_CSV="${{V61HG_MINIMAL_SLICE_ROWS_CSV:-$OPERATOR_WORK_ROOT/MINIMAL_SLICE_ROWS.csv}}"
OPERATOR_INPUT_ROOT="${{V61HG_OPERATOR_INPUT_ROOT:-$OPERATOR_WORK_ROOT/operator_input_root}}"
OUTPUT_ROOT="${{V61HG_OUTPUT_ROOT:-$OPERATOR_WORK_ROOT/output_root}}"
GO_RUN_ID="${{V61HG_V61GO_RUN_ID:-operator_replay_handoff_go}}"
GP_RUN_ID="${{V61HG_V61GP_RUN_ID:-operator_replay_handoff_gp}}"

if [[ ! -s "$FORM_PATH" ]]; then
  echo "filled external return form missing: $FORM_PATH" >&2
  exit 2
fi
if [[ ! -x "$WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" ]]; then
  echo "form materializer missing under workspace external_return_form/" >&2
  exit 2
fi
if [[ ! -s "$WORK_ROOT/FIRST_REAL_SLICE_ENV_TEMPLATE.sh" ]]; then
  echo "workspace env template missing" >&2
  exit 2
fi

"$WORK_ROOT/external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py" "$FORM_PATH"
set -a
source "$WORK_ROOT/FIRST_REAL_SLICE_ENV_TEMPLATE.sh"
set +a

if [[ "${{V61HG_OVERWRITE_OPERATOR_INPUT:-0}}" == "1" ]]; then
  rm -rf "$OPERATOR_INPUT_ROOT" "$OUTPUT_ROOT" "$MINIMAL_CSV"
fi
mkdir -p "$OPERATOR_WORK_ROOT"

export V61GI_CONTENT_WITNESS_DIR="$WORK_ROOT/final_content_witness"
export V61GI_MINIMAL_SLICE_ROWS_CSV="$MINIMAL_CSV"
export V61GI_MINIMAL_SLICE_ROWS_OVERWRITE="${{V61HG_MINIMAL_SLICE_ROWS_OVERWRITE:-1}}"
export V61GI_OPERATOR_INPUT_ROOT="$OPERATOR_INPUT_ROOT"
export V61GI_OUTPUT_ROOT="$OUTPUT_ROOT"

V61GO_RUN_ID="$GO_RUN_ID" \\
V61GO_EXECUTE_MATERIALIZE=1 \\
V61GO_REUSE_EXISTING=0 \\
"$ROOT_DIR/experiments/run_v61go_post_gn_first_real_slice_operator_input_materializer.sh" >/dev/null

GO_SUMMARY="$ROOT_DIR/results/v61go_post_gn_first_real_slice_operator_input_materializer_summary.csv"
python3 - "$GO_SUMMARY" <<'PY_GO_CHECK'
import csv
import sys
with open(sys.argv[1], newline='', encoding='utf-8') as handle:
    row = next(csv.DictReader(handle))
required = {{
    "final_operator_input_files_ready": "1",
    "receiver_preflight_executed": "1",
    "operator_input_receipt_ready": "1",
    "operator_input_preflight_ready": "1",
    "assembly_admitted": "0",
    "assembly_executed": "0",
}}
errors = [f"{{k}}={{row.get(k)}}" for k, v in required.items() if row.get(k) != v]
if errors:
    raise SystemExit("operator input preflight blocked: " + ";".join(errors))
print("operator_input_preflight_ready=1; dual replay still unexecuted")
PY_GO_CHECK

if [[ "${{V61HG_EXECUTE_DUAL_REPLAY:-0}}" != "1" ]]; then
  echo "operator input root is ready; set V61HG_EXECUTE_DUAL_REPLAY=1 with external authority ack to run dual replay" >&2
  exit 3
fi
if [[ "${{V61HG_EXTERNAL_RETURN_AUTHORITY_ACK:-}}" != "operator-confirmed-real-external-review-and-generation-return" ]]; then
  echo "missing V61HG_EXTERNAL_RETURN_AUTHORITY_ACK=operator-confirmed-real-external-review-and-generation-return" >&2
  exit 4
fi
AUTHORITY_STATEMENT="${{V61HG_EXTERNAL_RETURN_AUTHORITY_STATEMENT:-}}"
if [[ "${{#AUTHORITY_STATEMENT}}" -lt 80 ]]; then
  echo "V61HG_EXTERNAL_RETURN_AUTHORITY_STATEMENT must be at least 80 characters" >&2
  exit 4
fi

V61GP_RUN_ID="$GP_RUN_ID" \\
V61GP_OPERATOR_INPUT_ROOT="$OPERATOR_INPUT_ROOT" \\
V61GP_OUTPUT_ROOT="$OUTPUT_ROOT" \\
V61GP_EXTERNAL_RETURN_AUTHORITY_ACK="$V61HG_EXTERNAL_RETURN_AUTHORITY_ACK" \\
V61GP_EXTERNAL_RETURN_AUTHORITY_STATEMENT="$V61HG_EXTERNAL_RETURN_AUTHORITY_STATEMENT" \\
V61GP_EXECUTE_REPLAY=1 \\
V61GP_REUSE_EXISTING=0 \\
"$ROOT_DIR/experiments/run_v61gp_post_go_first_real_slice_dual_replay_executor.sh"
"""

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_materializer_exists = int(form_dir is not None and (form_dir / "MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py").is_file())
filled_form_handoff_exists = int(work_root is not None and (work_root / "RUN_FILLED_FORM_TO_GUARDED_FIRST_REAL_SLICE.sh").is_file())
env_template_exists = int(work_root is not None and (work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh").is_file())
source_witness_exists = int(work_root is not None and (work_root / "final_content_witness" / "source_file.txt").is_file())
publish_admitted = int(
    publish_requested
    and work_root_exists
    and work_root_outside_repo
    and form_materializer_exists
    and filled_form_handoff_exists
    and env_template_exists
    and source_witness_exists
)
published = 0
publish_errors = []
published_rows = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not form_materializer_exists:
        publish_errors.append("form-materializer-missing")
    if not filled_form_handoff_exists:
        publish_errors.append("filled-form-handoff-missing")
    if not env_template_exists:
        publish_errors.append("env-template-missing")
    if not source_witness_exists:
        publish_errors.append("source-witness-missing")
elif publish_admitted:
    handoff_path = work_root / "RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh"
    readme_path = form_dir / "OPERATOR_REPLAY_HANDOFF_README.md"
    handoff_path.write_text(handoff_text, encoding="utf-8")
    handoff_path.chmod(0o755)
    readme_path.write_text(
        "\n".join([
            "# Filled Form To Operator Input And Optional Dual Replay",
            "",
            "This handoff consumes a filled external return form, materializes witness/env values, builds the minimal-slice CSV, materializes the v61gj operator input root, and stops before replay by default.",
            "Dual replay requires `V61HG_EXECUTE_DUAL_REPLAY=1`, `V61HG_EXTERNAL_RETURN_AUTHORITY_ACK=operator-confirmed-real-external-review-and-generation-return`, and a final authority statement.",
            "The handoff delegates row acceptance to v61gp/v61gj/v61gf; it does not create evidence by itself.",
            "",
        ]),
        encoding="utf-8",
    )
    published = 1
    for path in [handoff_path, readme_path]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "executes_dual_replay_by_default": "0",
        })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_dual_replay_by_default": "0"})
write_csv(run_dir / "first_real_slice_operator_replay_handoff_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-v61hf-source", "status": "ready", "evidence": "v61hf ready"},
    {"stage_id": "02-v61go-source", "status": "ready", "evidence": "v61go ready"},
    {"stage_id": "03-v61gp-source", "status": "ready", "evidence": "v61gp ready"},
    {"stage_id": "04-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "05-form-materializer", "status": "ready" if form_materializer_exists else "blocked", "evidence": f"form_materializer_exists={form_materializer_exists}"},
    {"stage_id": "06-filled-form-handoff", "status": "ready" if filled_form_handoff_exists else "blocked", "evidence": f"filled_form_handoff_exists={filled_form_handoff_exists}"},
    {"stage_id": "07-env-template-and-source-witness", "status": "ready" if env_template_exists and source_witness_exists else "blocked", "evidence": f"env_template_exists={env_template_exists}; source_witness_exists={source_witness_exists}"},
    {"stage_id": "08-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "09-operator-replay-handoff-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "10-current-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', 'unknown')}"},
    {"stage_id": "11-operator-input-preflight-runtime", "status": "blocked", "evidence": "runtime handoff requires filled form execution"},
    {"stage_id": "12-dual-replay-runtime", "status": "blocked", "evidence": "dual replay requires explicit V61HG_EXECUTE_DUAL_REPLAY=1 plus external authority ack"},
]
write_csv(run_dir / "first_real_slice_operator_replay_handoff_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-run-operator-handoff-no-replay", "ready_to_run_now": str(published), "command": "RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh", "purpose": "materialize operator input root and stop before dual replay"},
    {"command_id": "02-run-operator-handoff-with-dual-replay", "ready_to_run_now": "0", "command": "V61HG_EXECUTE_DUAL_REPLAY=1 V61HG_EXTERNAL_RETURN_AUTHORITY_ACK=operator-confirmed-real-external-review-and-generation-return V61HG_EXTERNAL_RETURN_AUTHORITY_STATEMENT=<final> RUN_FILLED_FORM_TO_OPERATOR_INPUT_AND_OPTIONAL_DUAL_REPLAY.sh", "purpose": "execute v61gp only after explicit real authority ack"},
]
write_csv(run_dir / "first_real_slice_operator_replay_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_operator_replay_handoff_published_rows.csv"),
    ("FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_STAGE_ROWS.csv", run_dir / "first_real_slice_operator_replay_handoff_stage_rows.csv"),
    ("FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_COMMAND_ROWS.csv", run_dir / "first_real_slice_operator_replay_handoff_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_PUBLISHED_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_COMMAND_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61hg package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_PUBLISHER.sh").chmod(0o755)

summary = {
    "v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready": 1,
    "v61hf_post_he_first_real_slice_filled_form_handoff_publisher_ready": 1,
    "v61go_post_gn_first_real_slice_operator_input_materializer_ready": 1,
    "v61gp_post_go_first_real_slice_dual_replay_executor_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "form_materializer_exists": form_materializer_exists,
    "filled_form_handoff_exists": filled_form_handoff_exists,
    "env_template_exists": env_template_exists,
    "source_witness_exists": source_witness_exists,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "operator_replay_handoff_published": published,
    "open_gap_rows": int(gv.get("open_gap_rows", "0") or "0"),
    "workspace_gap_preflight_ready": int(gv.get("workspace_gap_preflight_ready", "0") or "0"),
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "accepted_answer_rows": 0,
    "accepted_citation_rows": 0,
    "accepted_latency_rows": 0,
    "row_acceptance_ready": 0,
    "generation_execution_admission_ready": 0,
    "generation_result_row_acceptance_ready": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hg": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows),
    "published_file_rows": 0 if not published else len(published_rows),
    "payload_like_package_file_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61hf-ready", "status": "pass", "evidence": "v61hf ready"},
    {"gate": "source-v61go-ready", "status": "pass", "evidence": "v61go ready"},
    {"gate": "source-v61gp-ready", "status": "pass", "evidence": "v61gp ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "form-materializer", "status": "pass" if form_materializer_exists else "blocked", "evidence": f"form_materializer_exists={form_materializer_exists}"},
    {"gate": "filled-form-handoff", "status": "pass" if filled_form_handoff_exists else "blocked", "evidence": f"filled_form_handoff_exists={filled_form_handoff_exists}"},
    {"gate": "env-template-and-source-witness", "status": "pass" if env_template_exists and source_witness_exists else "blocked", "evidence": f"env_template_exists={env_template_exists}; source_witness_exists={source_witness_exists}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "operator-replay-handoff-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "operator-input-preflight-runtime", "status": "blocked", "evidence": "requires filled form execution"},
    {"gate": "dual-replay-runtime", "status": "blocked", "evidence": "requires explicit replay env and authority ack"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "work_root": str(work_root) if work_root else "",
    "executes_dual_replay_by_default": 0,
    "requires_explicit_replay_env": "V61HG_EXECUTE_DUAL_REPLAY=1",
    "requires_external_authority_ack": "operator-confirmed-real-external-review-and-generation-return",
    "accepted_as_real_evidence": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HG_POST_HF_FIRST_REAL_SLICE_OPERATOR_REPLAY_HANDOFF_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HG Post-HF First Real Slice Operator Replay Handoff Publisher",
        "",
        "- v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_ready=1",
        f"- operator_replay_handoff_published={published}",
        f"- open_gap_rows={summary['open_gap_rows']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- real_return_replay_admission_ready=0",
        "- generation_acceptance_closure_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "Blocked wording: this publishes a handoff from filled form to operator-input preflight and optional dual replay. It never executes replay by default.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path), "metadata_only": "1", "payload_like": "0"})
write_csv(run_dir / "first_real_slice_operator_replay_handoff_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hg_post_hf_first_real_slice_operator_replay_handoff_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
