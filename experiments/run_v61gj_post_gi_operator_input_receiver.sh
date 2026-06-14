#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gj_post_gi_operator_input_receiver"
RUN_ID="${V61GJ_RUN_ID:-receiver_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
OPERATOR_INPUT_ROOT="${V61GJ_OPERATOR_INPUT_ROOT:-${V61GI_OPERATOR_INPUT_ROOT:-}}"
OUTPUT_ROOT="${V61GJ_OUTPUT_ROOT:-${V61GI_OUTPUT_ROOT:-}}"
EXECUTE_ASSEMBLY="${V61GJ_EXECUTE_ASSEMBLY:-0}"

if [[ "${V61GJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gj_post_gi_operator_input_receiver_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$OPERATOR_INPUT_ROOT" "$OUTPUT_ROOT" "$EXECUTE_ASSEMBLY" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
operator_input_arg = sys.argv[5].strip()
output_root_arg = sys.argv[6].strip()
execute_assembly = int((sys.argv[7].strip() or "0") == "1")
results = root / "results"
prefix = "v61gj_post_gi_operator_input_receiver"
receiver_dir = run_dir / "operator_input_receiver"
receiver_dir.mkdir(parents=True, exist_ok=True)
operator_input_root = Path(operator_input_arg).expanduser().resolve() if operator_input_arg else None
output_root = Path(output_root_arg).expanduser().resolve() if output_root_arg else None


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


source_paths = {
    "v61gi_summary": results / "v61gi_post_gh_authority_bound_operator_input_scaffold_summary.csv",
    "v61gi_decision": results / "v61gi_post_gh_authority_bound_operator_input_scaffold_decision.csv",
    "v61gi_required_rows": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_input_required_rows.csv",
    "v61gi_generated_marker_rows": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_generated_marker_rows.csv",
    "v61gi_command_rows": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_input_scaffold_command_rows.csv",
    "v61gi_assembly_wrapper": results / "v61gi_post_gh_authority_bound_operator_input_scaffold" / "scaffold_001" / "authority_bound_operator_input_scaffold" / "RUN_V61GH_ASSEMBLY_IF_OPERATOR_INPUT_READY.sh",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gj source {source_id}: {path}")

source_rows = [copy_source(source_id, path, "source_v61gi") for source_id, path in source_paths.items()]
write_csv(run_dir / "operator_input_receiver_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61gi = read_csv(source_paths["v61gi_summary"])[0]
if v61gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gj requires v61gi ready")

required_rows = read_csv(source_paths["v61gi_required_rows"])
marker_rows = read_csv(source_paths["v61gi_generated_marker_rows"])
operator_root_supplied = int(operator_input_root is not None)
operator_root_exists = int(operator_input_root is not None and operator_input_root.is_dir())
output_root_supplied = int(output_root is not None)
output_root_outside_repo = int(output_root is not None and not is_inside(output_root, root))

preflight_rows = []
for row in required_rows:
    rel = row["final_relative_path"]
    path = operator_input_root / rel if operator_root_exists else None
    exists = int(path is not None and path.is_file())
    non_empty = int(exists and path.stat().st_size > 0)
    has_template_suffix = int(exists and path.name.endswith(".template"))
    placeholder_or_fixture = 0
    digest = ""
    errors = []
    if not exists:
        errors.append("missing")
    else:
        digest = sha256(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        lowered = text.lower()
        placeholder_or_fixture = int("REPLACE_WITH" in text or "template" in lowered or "fixture" in lowered)
        if not non_empty:
            errors.append("empty")
        if has_template_suffix:
            errors.append("template-suffix")
        if placeholder_or_fixture:
            errors.append("placeholder-or-fixture-text")
    ready = int(exists and non_empty and not has_template_suffix and not placeholder_or_fixture)
    preflight_rows.append({
        "input_id": row["input_id"],
        "final_relative_path": rel,
        "required": row["required"],
        "authority_bound": row["authority_bound"],
        "exists": str(exists),
        "non_empty": str(non_empty),
        "has_template_suffix": str(has_template_suffix),
        "placeholder_or_fixture_text": str(placeholder_or_fixture),
        "ready": str(ready),
        "bytes": str(path.stat().st_size) if exists else "0",
        "sha256": digest,
        "errors": ";".join(errors),
    })
write_csv(run_dir / "operator_input_receiver_preflight_rows.csv", list(preflight_rows[0].keys()), preflight_rows)

present_operator_input_rows = sum(row["exists"] == "1" for row in preflight_rows)
ready_operator_input_rows = sum(row["ready"] == "1" for row in preflight_rows)
operator_input_preflight_ready = int(ready_operator_input_rows == len(required_rows) and len(required_rows) > 0)
assembly_admitted = int(operator_input_preflight_ready and output_root_supplied and output_root_outside_repo)
assembly_executed = 0
assembly_exit_code = ""
assembly_stdout = ""
assembly_stderr = ""
if execute_assembly and assembly_admitted:
    env = os.environ.copy()
    env.update({
        "V61GI_OPERATOR_INPUT_ROOT": str(operator_input_root),
        "V61GI_OUTPUT_ROOT": str(output_root),
    })
    proc = subprocess.run(
        [str(source_paths["v61gi_assembly_wrapper"])],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assembly_executed = 1
    assembly_exit_code = str(proc.returncode)
    assembly_stdout = proc.stdout
    assembly_stderr = proc.stderr
    (run_dir / "operator_input_receiver_assembly_stdout.txt").write_text(assembly_stdout, encoding="utf-8")
    (run_dir / "operator_input_receiver_assembly_stderr.txt").write_text(assembly_stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61gj assembly failed: {proc.returncode}")

assembled_v53_root_ready = int(output_root is not None and (output_root / "v53" / "REAL_EXTERNAL_RETURN_PROVENANCE.json").is_file())
assembled_v61_root_ready = int(output_root is not None and (output_root / "v61" / "review_return_provenance" / "REAL_REVIEW_RETURN_PROVENANCE.json").is_file())

v61gg_operator_summary = {}
v61gg_summary_path = results / "v61gg_post_gf_real_authority_binding_guard_summary.csv"
if assembly_executed and v61gg_summary_path.is_file():
    v61gg_operator_summary = read_csv(v61gg_summary_path)[0]

authority_bound_replay_admission_ready = int(v61gg_operator_summary.get("authority_bound_replay_admission_ready", "0") == "1")
real_external_review_return_rows = int(v61gg_operator_summary.get("v61gf_row_acceptance_ready", "0") == "1")
real_generation_result_artifacts = int(v61gg_operator_summary.get("v61gf_dual_external_return_real_ready", "0") == "1")

stage_rows = [
    {"stage_id": "01-v61gi-source-ready", "status": "ready", "evidence": "v61gi ready"},
    {"stage_id": "02-operator-input-root-supplied", "status": "ready" if operator_root_supplied else "blocked", "evidence": f"operator_input_root_supplied={operator_root_supplied}"},
    {"stage_id": "03-operator-input-root-exists", "status": "ready" if operator_root_exists else "blocked", "evidence": f"operator_root_exists={operator_root_exists}"},
    {"stage_id": "04-final-input-preflight", "status": "ready" if operator_input_preflight_ready else "blocked", "evidence": f"ready_operator_input_rows={ready_operator_input_rows}/{len(required_rows)}"},
    {"stage_id": "05-output-root-outside-repo", "status": "ready" if output_root_outside_repo else "blocked", "evidence": f"output_root_supplied={output_root_supplied}; output_root_outside_repo={output_root_outside_repo}"},
    {"stage_id": "06-assembly-admitted", "status": "ready" if assembly_admitted else "blocked", "evidence": f"assembly_admitted={assembly_admitted}"},
    {"stage_id": "07-assembly-executed", "status": "ready" if assembly_executed else "blocked", "evidence": f"assembly_executed={assembly_executed}; exit_code={assembly_exit_code}"},
    {"stage_id": "08-authority-bound-replay-admission", "status": "ready" if authority_bound_replay_admission_ready else "blocked", "evidence": f"authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}"},
    {"stage_id": "09-actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "operator_input_receiver_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-receiver-package", "ready_to_run_now": "1", "command": "results/v61gj_post_gi_operator_input_receiver/receiver_001/operator_input_receiver/VERIFY_OPERATOR_INPUT_RECEIVER.sh", "purpose": "verify metadata-only receiver output"},
    {"command_id": "02-run-with-operator-input", "ready_to_run_now": "0", "command": "V61GJ_OPERATOR_INPUT_ROOT=<operator-input-root> V61GJ_OUTPUT_ROOT=<external-output-root> V61GJ_EXECUTE_ASSEMBLY=1 ./experiments/run_v61gj_post_gi_operator_input_receiver.sh", "purpose": "preflight final files and assemble authority-bound roots"},
]
write_csv(run_dir / "operator_input_receiver_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("OPERATOR_INPUT_RECEIVER_PREFLIGHT_ROWS.csv", run_dir / "operator_input_receiver_preflight_rows.csv"),
    ("OPERATOR_INPUT_RECEIVER_STAGE_ROWS.csv", run_dir / "operator_input_receiver_stage_rows.csv"),
    ("OPERATOR_INPUT_RECEIVER_COMMAND_ROWS.csv", run_dir / "operator_input_receiver_command_rows.csv"),
]:
    shutil.copy2(src, receiver_dir / rel)

(receiver_dir / "VERIFY_OPERATOR_INPUT_RECEIVER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_PREFLIGHT_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_STAGE_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/OPERATOR_INPUT_RECEIVER_MANIFEST.json\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in operator input receiver' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(receiver_dir / "VERIFY_OPERATOR_INPUT_RECEIVER.sh").chmod(0o755)

summary = {
    "v61gj_post_gi_operator_input_receiver_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": operator_root_exists,
    "operator_input_required_rows": len(required_rows),
    "present_operator_input_rows": present_operator_input_rows,
    "ready_operator_input_rows": ready_operator_input_rows,
    "operator_input_preflight_ready": operator_input_preflight_ready,
    "generated_marker_contract_rows": len(marker_rows),
    "output_root_supplied": output_root_supplied,
    "output_root_outside_repo": output_root_outside_repo,
    "assembly_admitted": assembly_admitted,
    "assembly_executed": assembly_executed,
    "assembled_v53_root_ready": assembled_v53_root_ready,
    "assembled_v61_root_ready": assembled_v61_root_ready,
    "real_external_review_return_rows": real_external_review_return_rows,
    "real_adjudication_rows": int(v61gg_operator_summary.get("v61gf_row_acceptance_ready", "0") == "1"),
    "slice_answer_review_accepted_rows": int(v61gg_operator_summary.get("v61gf_row_acceptance_ready", "0") == "1"),
    "real_generation_result_artifacts": real_generation_result_artifacts,
    "accepted_generation_result_artifacts": real_generation_result_artifacts,
    "generation_result_accepted_rows": int(v61gg_operator_summary.get("v61gf_generation_acceptance_closure_ready", "0") == "1"),
    "authority_bound_replay_admission_ready": authority_bound_replay_admission_ready,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gj": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "package_file_rows": 0,
    "metadata_only_package_file_rows": 0,
    "payload_like_package_file_rows": 0,
}

package_files = sorted(path for path in receiver_dir.rglob("*") if path.is_file())
package_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "operator_input_receiver_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
summary["package_file_rows"] = len(package_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gi-ready", "status": "pass", "evidence": "v61gi ready"},
    {"gate": "operator-input-root-supplied", "status": "pass" if operator_root_supplied else "blocked", "evidence": f"operator_input_root_supplied={operator_root_supplied}"},
    {"gate": "operator-input-preflight", "status": "pass" if operator_input_preflight_ready else "blocked", "evidence": f"ready_operator_input_rows={ready_operator_input_rows}/{len(required_rows)}"},
    {"gate": "assembly-admitted", "status": "pass" if assembly_admitted else "blocked", "evidence": f"assembly_admitted={assembly_admitted}"},
    {"gate": "assembly-executed", "status": "pass" if assembly_executed else "blocked", "evidence": f"assembly_executed={assembly_executed}"},
    {"gate": "authority-bound-replay-admission", "status": "pass" if authority_bound_replay_admission_ready else "blocked", "evidence": f"authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}"},
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
}
(receiver_dir / "OPERATOR_INPUT_RECEIVER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = "\n".join([
    "# V61GJ Post-GI Operator Input Receiver",
    "",
    "- v61gj_post_gi_operator_input_receiver_ready=1",
    f"- operator_input_root_supplied={operator_root_supplied}",
    f"- present_operator_input_rows={present_operator_input_rows}",
    f"- ready_operator_input_rows={ready_operator_input_rows}",
    f"- operator_input_preflight_ready={operator_input_preflight_ready}",
    f"- assembly_admitted={assembly_admitted}",
    f"- assembly_executed={assembly_executed}",
    f"- assembled_v53_root_ready={assembled_v53_root_ready}",
    f"- assembled_v61_root_ready={assembled_v61_root_ready}",
    f"- authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this receiver can only preflight and optionally assemble supplied operator input files. It does not create review/adjudication/generation evidence by itself and does not claim production latency, near-frontier quality, v1.0 comparison, or release readiness.",
    "",
])
(run_dir / "V61GJ_POST_GI_OPERATOR_INPUT_RECEIVER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gj_post_gi_operator_input_receiver_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
