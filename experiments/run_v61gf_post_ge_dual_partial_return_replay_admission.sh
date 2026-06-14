#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gf_post_ge_dual_partial_return_replay_admission"
RUN_ID="${V61GF_RUN_ID:-admission_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V53_RETURN_ROOT="${V61GF_V53_RETURN_ROOT:-${V61GD_V53_RETURN_ROOT:-${V61FV_V53_RETURN_BUNDLE_DIR:-}}}"
V53_RETURN_PROVENANCE="${V61GF_V53_RETURN_PROVENANCE:-${V61GD_V53_RETURN_PROVENANCE:-${V61FV_V53_RETURN_PROVENANCE:-unspecified}}}"
V61_RETURN_ROOT="${V61GF_V61_RETURN_ROOT:-${V61GE_V61_RETURN_ROOT:-${V61FV_V61_RETURN_BUNDLE_DIR:-}}}"
V61_RETURN_PROVENANCE="${V61GF_V61_RETURN_PROVENANCE:-${V61GE_V61_RETURN_PROVENANCE:-${V61FV_V61_RETURN_PROVENANCE:-unspecified}}}"

if [[ "${V61GF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gf_post_ge_dual_partial_return_replay_admission_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fv_post_fu_dual_return_replay_entrypoint.sh" >/dev/null
V61GD_RUN_ID="${RUN_ID}_v53" \
V61GD_V53_RETURN_ROOT="$V53_RETURN_ROOT" \
V61GD_V53_RETURN_PROVENANCE="$V53_RETURN_PROVENANCE" \
V61GD_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gd_post_gc_v53_partial_external_return_slice_intake.sh" >/dev/null
V61GE_RUN_ID="${RUN_ID}_v61" \
V61GE_V61_RETURN_ROOT="$V61_RETURN_ROOT" \
V61GE_V61_RETURN_PROVENANCE="$V61_RETURN_PROVENANCE" \
V61GE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ge_post_gd_v61_partial_generation_intake_slice.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$V53_RETURN_ROOT" "$V61_RETURN_ROOT" <<'PY'
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
v53_root_arg = sys.argv[6].strip()
v61_root_arg = sys.argv[7].strip()
results = root / "results"
prefix = "v61gf_post_ge_dual_partial_return_replay_admission"
package_dir = run_dir / "dual_partial_return_replay_admission"
package_dir.mkdir(parents=True, exist_ok=True)
v53_run_id = f"{run_id}_v53"
v61_run_id = f"{run_id}_v61"

GD_PREFIX = "v61gd_post_gc_v53_partial_external_return_slice_intake"
GE_PREFIX = "v61ge_post_gd_v61_partial_generation_intake_slice"
FV_PREFIX = "v61fv_post_fu_dual_return_replay_entrypoint"


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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def status(flag):
    return "ready" if flag else "blocked"


def decision_status(flag):
    return "pass" if flag else "blocked"


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


source_paths = {
    "v61gd_summary": results / f"{GD_PREFIX}_summary.csv",
    "v61gd_decision": results / f"{GD_PREFIX}_decision.csv",
    "v61gd_acceptance_rows": results / GD_PREFIX / v53_run_id / "v53_partial_external_return_slice_answer_acceptance_rows.csv",
    "v61gd_validation_rows": results / GD_PREFIX / v53_run_id / "v53_partial_external_return_slice_validation_rows.csv",
    "v61ge_summary": results / f"{GE_PREFIX}_summary.csv",
    "v61ge_decision": results / f"{GE_PREFIX}_decision.csv",
    "v61ge_artifact_rows": results / GE_PREFIX / v61_run_id / "v61_partial_generation_intake_slice_artifact_status_rows.csv",
    "v61ge_query_rows": results / GE_PREFIX / v61_run_id / "v61_partial_generation_intake_slice_query_acceptance_rows.csv",
    "v61fv_summary": results / f"{FV_PREFIX}_summary.csv",
    "v61fv_decision": results / f"{FV_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gf source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61gd"):
        folder = "source_v61gd"
    elif label.startswith("v61ge"):
        folder = "source_v61ge"
    else:
        folder = "source_v61fv"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "dual_partial_return_replay_admission_source_rows.csv", list(source_rows[0].keys()), source_rows)

gd = read_csv(source_paths["v61gd_summary"])[0]
ge = read_csv(source_paths["v61ge_summary"])[0]
fv = read_csv(source_paths["v61fv_summary"])[0]
if gd.get("v61gd_post_gc_v53_partial_external_return_slice_intake_ready") != "1":
    raise SystemExit("v61gf requires v61gd ready")
if ge.get("v61ge_post_gd_v61_partial_generation_intake_slice_ready") != "1":
    raise SystemExit("v61gf requires v61ge ready")
if fv.get("v61fv_post_fu_dual_return_replay_entrypoint_ready") != "1":
    raise SystemExit("v61gf requires v61fv entrypoint ready")

v53_root_supplied = as_int(gd, "v53_return_root_supplied")
v53_root_exists = as_int(gd, "v53_return_root_exists")
v53_real_provenance_ready = as_int(gd, "v53_real_provenance_ready")
v53_candidate_answer_rows = as_int(gd, "candidate_answer_review_accepted_rows")
v53_real_review_rows = as_int(gd, "real_external_review_return_rows")
v53_adjudication_rows = as_int(gd, "real_adjudication_rows")
v53_answer_accepted_rows = as_int(gd, "slice_answer_review_accepted_rows")
v53_partial_ready = as_int(gd, "partial_real_slice_ready")

v61_root_supplied = as_int(ge, "v61_return_root_supplied")
v61_root_exists = as_int(ge, "v61_return_root_exists")
v61_real_provenance_ready = as_int(ge, "v61_real_provenance_ready")
v61_candidate_artifacts = as_int(ge, "candidate_generation_result_artifacts")
v61_candidate_rows = as_int(ge, "candidate_generation_result_accepted_rows")
v61_real_artifacts = as_int(ge, "real_generation_result_artifacts")
v61_accepted_artifacts = as_int(ge, "accepted_generation_result_artifacts")
v61_generation_rows = as_int(ge, "generation_result_accepted_rows")
v61_accepted_answer_rows = as_int(ge, "accepted_answer_rows")
v61_accepted_citation_rows = as_int(ge, "accepted_citation_rows")
v61_accepted_latency_rows = as_int(ge, "accepted_latency_rows")
v61_partial_ready = as_int(ge, "partial_real_generation_slice_ready")
entrypoint_ready = as_int(fv, "v61fv_post_fu_dual_return_replay_entrypoint_ready")

row_acceptance_ready = int(
    v53_partial_ready
    and v53_real_review_rows > 0
    and v53_adjudication_rows > 0
    and v53_answer_accepted_rows > 0
)
generation_execution_admission_ready = row_acceptance_ready
generation_result_row_acceptance_ready = int(
    v61_partial_ready
    and v61_real_artifacts > 0
    and v61_accepted_artifacts > 0
    and v61_generation_rows > 0
    and v61_accepted_answer_rows > 0
    and v61_accepted_citation_rows > 0
    and v61_accepted_latency_rows > 0
)
dual_external_return_real_ready = int(row_acceptance_ready and generation_result_row_acceptance_ready)
real_return_replay_admission_ready = int(dual_external_return_real_ready and entrypoint_ready)
generation_acceptance_closure_ready = int(real_return_replay_admission_ready and generation_result_row_acceptance_ready)

stage_rows = [
    {"stage_id": "01-v61gd-v53-slice-source", "status": "ready", "evidence": "v61gd receiver ready"},
    {"stage_id": "02-v61ge-generation-slice-source", "status": "ready", "evidence": "v61ge receiver ready"},
    {"stage_id": "03-v61fv-full-entrypoint-source", "status": "ready", "evidence": "v61fv guarded entrypoint ready"},
    {"stage_id": "04-v53-real-partial-slice", "status": status(v53_partial_ready), "evidence": f"v53_root_exists={v53_root_exists}; v53_real_provenance_ready={v53_real_provenance_ready}; accepted_rows={v53_answer_accepted_rows}"},
    {"stage_id": "05-v61-real-generation-slice", "status": status(v61_partial_ready), "evidence": f"v61_root_exists={v61_root_exists}; v61_real_provenance_ready={v61_real_provenance_ready}; generation_result_accepted_rows={v61_generation_rows}"},
    {"stage_id": "06-review-row-acceptance", "status": status(row_acceptance_ready), "evidence": f"real_review_rows={v53_real_review_rows}; adjudication_rows={v53_adjudication_rows}; answer_review_accepted_rows={v53_answer_accepted_rows}"},
    {"stage_id": "07-generation-execution-admission", "status": status(generation_execution_admission_ready), "evidence": "subset generation execution admission opens only after real v53 row acceptance"},
    {"stage_id": "08-dual-partial-replay-admission", "status": status(real_return_replay_admission_ready), "evidence": f"dual_external_return_real_ready={dual_external_return_real_ready}; entrypoint_ready={entrypoint_ready}"},
    {"stage_id": "09-generation-acceptance-closure", "status": status(generation_acceptance_closure_ready), "evidence": f"generation_result_row_acceptance_ready={generation_result_row_acceptance_ready}"},
    {"stage_id": "10-actual-generation-full-claim", "status": "blocked", "evidence": "subset replay admission does not prove full actual generation or production latency"},
]
write_csv(run_dir / "dual_partial_return_replay_admission_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-package", "ready_to_run_now": "1", "command": "results/v61gf_post_ge_dual_partial_return_replay_admission/admission_001/dual_partial_return_replay_admission/VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh", "purpose": "verify metadata-only package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gf_post_ge_dual_partial_return_replay_admission/admission_001/dual_partial_return_replay_admission/READY_NOW_COMMANDS.sh", "purpose": "show guarded subset replay command"},
    {"command_id": "03-run-dual-partial-return-replay", "ready_to_run_now": str(real_return_replay_admission_ready), "command": "V61GF_V53_RETURN_ROOT=<real-v53-root> V61GF_V53_RETURN_PROVENANCE=real-external-return-bundle V61GF_V61_RETURN_ROOT=<real-v61-root> V61GF_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle results/v61gf_post_ge_dual_partial_return_replay_admission/admission_001/dual_partial_return_replay_admission/RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh", "purpose": "run subset-scope admission replay over both return roots"},
]
write_csv(run_dir / "dual_partial_return_replay_admission_command_rows.csv", list(command_rows[0].keys()), command_rows)

env_rows = [
    {"env_var": "V61GF_V53_RETURN_ROOT", "required_value": "existing v53 external return root", "present": str(v53_root_supplied), "ready": str(v53_root_exists)},
    {"env_var": "V61GF_V53_RETURN_PROVENANCE", "required_value": "real-external-return-bundle", "present": str(int(v53_root_arg != "")), "ready": str(v53_real_provenance_ready)},
    {"env_var": "V61GF_V61_RETURN_ROOT", "required_value": "existing v61 generation-intake return root", "present": str(v61_root_supplied), "ready": str(v61_root_exists)},
    {"env_var": "V61GF_V61_RETURN_PROVENANCE", "required_value": "real-generation-intake-return-bundle", "present": str(int(v61_root_arg != "")), "ready": str(v61_real_provenance_ready)},
]
write_csv(run_dir / "dual_partial_return_replay_required_env_rows.csv", list(env_rows[0].keys()), env_rows)

summary = {
    "v61gf_post_ge_dual_partial_return_replay_admission_ready": 1,
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready": 1,
    "v61ge_post_gd_v61_partial_generation_intake_slice_ready": 1,
    "v61fv_post_fu_dual_return_replay_entrypoint_ready": 1,
    "v53_return_root_supplied": v53_root_supplied,
    "v53_return_root_exists": v53_root_exists,
    "v53_real_provenance_ready": v53_real_provenance_ready,
    "candidate_answer_review_accepted_rows": v53_candidate_answer_rows,
    "real_external_review_return_rows": v53_real_review_rows,
    "real_adjudication_rows": v53_adjudication_rows,
    "slice_answer_review_accepted_rows": v53_answer_accepted_rows,
    "partial_real_slice_ready": v53_partial_ready,
    "v61_return_root_supplied": v61_root_supplied,
    "v61_return_root_exists": v61_root_exists,
    "v61_real_provenance_ready": v61_real_provenance_ready,
    "candidate_generation_result_artifacts": v61_candidate_artifacts,
    "candidate_generation_result_accepted_rows": v61_candidate_rows,
    "real_generation_result_artifacts": v61_real_artifacts,
    "accepted_generation_result_artifacts": v61_accepted_artifacts,
    "generation_result_accepted_rows": v61_generation_rows,
    "accepted_answer_rows": v61_accepted_answer_rows,
    "accepted_citation_rows": v61_accepted_citation_rows,
    "accepted_latency_rows": v61_accepted_latency_rows,
    "partial_real_generation_slice_ready": v61_partial_ready,
    "row_acceptance_ready": row_acceptance_ready,
    "generation_execution_admission_ready": generation_execution_admission_ready,
    "generation_result_row_acceptance_ready": generation_result_row_acceptance_ready,
    "dual_external_return_real_ready": dual_external_return_real_ready,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "generation_acceptance_closure_ready": generation_acceptance_closure_ready,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "full_1000_query_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gf": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "required_env_rows": len(env_rows),
    "ready_required_env_rows": sum(row["ready"] == "1" for row in env_rows),
    "source_file_rows": len(source_rows),
    "package_file_rows": 0,
    "metadata_only_package_file_rows": 0,
    "payload_like_package_file_rows": 0,
}

decision_rows = [
    {"gate": "source-v61gd-ready", "status": "pass", "evidence": "v61gd ready"},
    {"gate": "source-v61ge-ready", "status": "pass", "evidence": "v61ge ready"},
    {"gate": "source-v61fv-entrypoint-ready", "status": "pass", "evidence": "v61fv ready"},
    {"gate": "v53-real-partial-slice", "status": decision_status(v53_partial_ready), "evidence": f"partial_real_slice_ready={v53_partial_ready}"},
    {"gate": "v61-real-generation-slice", "status": decision_status(v61_partial_ready), "evidence": f"partial_real_generation_slice_ready={v61_partial_ready}"},
    {"gate": "row-acceptance", "status": decision_status(row_acceptance_ready), "evidence": f"row_acceptance_ready={row_acceptance_ready}"},
    {"gate": "generation-execution-admission", "status": decision_status(generation_execution_admission_ready), "evidence": f"generation_execution_admission_ready={generation_execution_admission_ready}"},
    {"gate": "dual-external-return-real", "status": decision_status(dual_external_return_real_ready), "evidence": f"dual_external_return_real_ready={dual_external_return_real_ready}"},
    {"gate": "real-return-replay-admission", "status": decision_status(real_return_replay_admission_ready), "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}"},
    {"gate": "generation-acceptance-closure", "status": decision_status(generation_acceptance_closure_ready), "evidence": f"generation_acceptance_closure_ready={generation_acceptance_closure_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(package_dir / "DUAL_PARTIAL_RETURN_REPLAY_ENV_TEMPLATE.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "export V61GF_V53_RETURN_ROOT=/path/to/v53_external_return_root",
        "export V61GF_V53_RETURN_PROVENANCE=real-external-return-bundle",
        "export V61GF_V61_RETURN_ROOT=/path/to/v61_generation_intake_return_root",
        "export V61GF_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "DUAL_PARTIAL_RETURN_REPLAY_ENV_TEMPLATE.sh").chmod(0o755)

(package_dir / "RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"ROOT_DIR={shlex.quote(str(root))}",
        ": \"${V61GF_V53_RETURN_ROOT:?set V61GF_V53_RETURN_ROOT to the real v53 external return root}\"",
        ": \"${V61GF_V53_RETURN_PROVENANCE:?set V61GF_V53_RETURN_PROVENANCE=real-external-return-bundle}\"",
        ": \"${V61GF_V61_RETURN_ROOT:?set V61GF_V61_RETURN_ROOT to the real v61 generation-intake return root}\"",
        ": \"${V61GF_V61_RETURN_PROVENANCE:?set V61GF_V61_RETURN_PROVENANCE=real-generation-intake-return-bundle}\"",
        "V61GF_RUN_ID=\"${V61GF_RUN_ID:-operator_partial_replay}\" \\",
        "V61GF_V53_RETURN_ROOT=\"$V61GF_V53_RETURN_ROOT\" \\",
        "V61GF_V53_RETURN_PROVENANCE=\"$V61GF_V53_RETURN_PROVENANCE\" \\",
        "V61GF_V61_RETURN_ROOT=\"$V61GF_V61_RETURN_ROOT\" \\",
        "V61GF_V61_RETURN_PROVENANCE=\"$V61GF_V61_RETURN_PROVENANCE\" \\",
        "V61GF_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh\" >/dev/null",
        "python3 - \"$ROOT_DIR/results/v61gf_post_ge_dual_partial_return_replay_admission_summary.csv\" <<'PY_CHECK'",
        "import csv, sys",
        "with open(sys.argv[1], newline='', encoding='utf-8') as handle:",
        "    row = next(csv.DictReader(handle))",
        "if row.get('real_return_replay_admission_ready') != '1':",
        "    raise SystemExit('dual partial return replay admission remains blocked')",
        "print('dual partial return replay admission ready')",
        "PY_CHECK",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh").chmod(0o755)

(package_dir / "VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -x \"$DIR/RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh\"",
        "test -x \"$DIR/DUAL_PARTIAL_RETURN_REPLAY_ENV_TEMPLATE.sh\"",
        "test -s \"$DIR/DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_MANIFEST.json\"",
        "test -s \"$DIR/DUAL_PARTIAL_RETURN_REPLAY_STAGE_ROWS.csv\"",
        "test -s \"$DIR/DUAL_PARTIAL_RETURN_REPLAY_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/DUAL_PARTIAL_RETURN_REPLAY_REQUIRED_ENV_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gf package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gf ready-now commands verify the metadata package. Real subset replay requires both real partial return roots.'",
        "echo 'results/v61gf_post_ge_dual_partial_return_replay_admission/admission_001/dual_partial_return_replay_admission/VERIFY_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.sh'",
        "echo 'source results/v61gf_post_ge_dual_partial_return_replay_admission/admission_001/dual_partial_return_replay_admission/DUAL_PARTIAL_RETURN_REPLAY_ENV_TEMPLATE.sh'",
        "echo 'results/v61gf_post_ge_dual_partial_return_replay_admission/admission_001/dual_partial_return_replay_admission/RUN_DUAL_PARTIAL_RETURN_REPLAY_IF_READY.sh'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

for rel, src in [
    ("DUAL_PARTIAL_RETURN_REPLAY_STAGE_ROWS.csv", run_dir / "dual_partial_return_replay_admission_stage_rows.csv"),
    ("DUAL_PARTIAL_RETURN_REPLAY_COMMAND_ROWS.csv", run_dir / "dual_partial_return_replay_admission_command_rows.csv"),
    ("DUAL_PARTIAL_RETURN_REPLAY_REQUIRED_ENV_ROWS.csv", run_dir / "dual_partial_return_replay_required_env_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

package_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "subset_scope_only": 1,
    "dual_external_return_real_ready": dual_external_return_real_ready,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "row_acceptance_ready": row_acceptance_ready,
    "generation_acceptance_closure_ready": generation_acceptance_closure_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_MANIFEST.json").write_text(json.dumps(package_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "DUAL_PARTIAL_RETURN_REPLAY_ADMISSION.md").write_text(
    "\n".join([
        "# v61gf dual partial return replay admission",
        "",
        f"- dual_external_return_real_ready={dual_external_return_real_ready}",
        f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
        f"- row_acceptance_ready={row_acceptance_ready}",
        f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
        "- actual_model_generation_ready=0",
        "",
        "This is subset-scope admission only. It does not claim full 1000-query generation, production latency, near-frontier quality, v1.0 comparison, or release readiness.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "dual_partial_return_replay_admission_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

boundary = "\n".join([
    "# V61GF Post-GE Dual Partial Return Replay Admission",
    "",
    "- v61gf_post_ge_dual_partial_return_replay_admission_ready=1",
    f"- real_external_review_return_rows={v53_real_review_rows}",
    f"- real_adjudication_rows={v53_adjudication_rows}",
    f"- slice_answer_review_accepted_rows={v53_answer_accepted_rows}",
    f"- real_generation_result_artifacts={v61_real_artifacts}",
    f"- accepted_generation_result_artifacts={v61_accepted_artifacts}",
    f"- generation_result_accepted_rows={v61_generation_rows}",
    f"- row_acceptance_ready={row_acceptance_ready}",
    f"- generation_execution_admission_ready={generation_execution_admission_ready}",
    f"- dual_external_return_real_ready={dual_external_return_real_ready}",
    f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
    f"- generation_acceptance_closure_ready={generation_acceptance_closure_ready}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this gate can open only for subset-scope real returned rows from both roots. It does not claim full v53 return closure, full 1000-query generation, production latency, near-frontier quality, v1.0 comparison, or release readiness.",
    "",
])
(run_dir / "V61GF_POST_GE_DUAL_PARTIAL_RETURN_REPLAY_ADMISSION_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gf": 0,
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

print(f"v61gf_post_ge_dual_partial_return_replay_admission_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
