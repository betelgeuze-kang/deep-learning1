#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gm_post_gl_first_real_slice_env_preflight"
RUN_ID="${V61GM_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
CONTENT_WITNESS_DIR="${V61GM_CONTENT_WITNESS_DIR:-${V61GI_CONTENT_WITNESS_DIR:-}}"
if [[ -n "$CONTENT_WITNESS_DIR" && -z "${V61GI_CONTENT_WITNESS_DIR:-}" ]]; then
  export V61GI_CONTENT_WITNESS_DIR="$CONTENT_WITNESS_DIR"
fi

if [[ "${V61GM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gm_post_gl_first_real_slice_env_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GL_RUN_ID="${RUN_ID}_witness" \
V61GL_CONTENT_WITNESS_DIR="$CONTENT_WITNESS_DIR" \
V61GL_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh" >/dev/null
V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
prefix = "v61gm_post_gl_first_real_slice_env_preflight"
package_dir = run_dir / "first_real_slice_env_preflight"
package_dir.mkdir(parents=True, exist_ok=True)

GL_PREFIX = "v61gl_post_gk_first_real_slice_witness_preflight"
GK_PREFIX = "v61gk_post_gj_first_real_slice_closure_packet"
GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"
NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]

VALUE_ENVS = {
    "reviewer_id": "V61GI_REVIEWER_ID",
    "adjudicator_id": "V61GI_ADJUDICATOR_ID",
    "generation_id": "V61GI_GENERATION_ID",
    "citation_id": "V61GI_CITATION_ID",
    "checkpoint_root": "V61GI_CHECKPOINT_ROOT",
    "latency_row_id": "V61GI_LATENCY_ROW_ID",
    "prompt_tokens": "V61GI_PROMPT_TOKENS",
    "output_tokens": "V61GI_OUTPUT_TOKENS",
    "prefill_ms": "V61GI_PREFILL_MS",
    "decode_ms": "V61GI_DECODE_MS",
    "total_ms": "V61GI_TOTAL_MS",
    "tokens_per_second": "V61GI_TOKENS_PER_SECOND",
    "v53_authority_statement": "V61GI_V53_AUTHORITY_STATEMENT",
    "v61_authority_statement": "V61GI_V61_AUTHORITY_STATEMENT",
    "external_return_attestation": "V61GI_EXTERNAL_RETURN_ATTESTATION",
    "assembly_authority_statement": "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT",
}
NUMERIC_ENVS = {
    "V61GI_PROMPT_TOKENS",
    "V61GI_OUTPUT_TOKENS",
    "V61GI_PREFILL_MS",
    "V61GI_DECODE_MS",
    "V61GI_TOTAL_MS",
    "V61GI_TOKENS_PER_SECOND",
}
MIN_LENGTHS = {
    "V61GI_V53_AUTHORITY_STATEMENT": 40,
    "V61GI_V61_AUTHORITY_STATEMENT": 40,
    "V61GI_EXTERNAL_RETURN_ATTESTATION": 40,
    "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT": 40,
}
PATH_ENVS = {
    "content_witness_dir": "V61GI_CONTENT_WITNESS_DIR",
    "minimal_slice_rows_csv": "V61GI_MINIMAL_SLICE_ROWS_CSV",
    "operator_input_root": "V61GI_OPERATOR_INPUT_ROOT",
    "output_root": "V61GI_OUTPUT_ROOT",
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


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def has_nonfinal_text(value):
    lowered = str(value).lower()
    return any(token in lowered for token in NONFINAL_TOKENS)


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def env_value(name):
    return os.environ.get(name, "").strip()


source_paths = {
    "v61gl_summary": results / GL_PREFIX / f"{os.environ.get('V61GM_RUN_ID', 'preflight_001')}_witness" / f"{GL_PREFIX}_summary.csv",
    "v61gl_decision": results / GL_PREFIX / f"{os.environ.get('V61GM_RUN_ID', 'preflight_001')}_witness" / f"{GL_PREFIX}_decision.csv",
    "v61gl_witness_rows": results / GL_PREFIX / f"{os.environ.get('V61GM_RUN_ID', 'preflight_001')}_witness" / "first_real_slice_witness_preflight_rows.csv",
    "v61gk_summary": results / f"{GK_PREFIX}_summary.csv",
    "v61gk_target_counter_rows": results / GK_PREFIX / "packet_001" / "first_real_slice_closure_packet" / "FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_precheck": gi_scaffold / "CHECK_MINIMAL_SLICE_OPERATOR_INPUTS.py",
    "v61gi_build_wrapper": gi_scaffold / "RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh",
    "v61gk_final_runner": results / GK_PREFIX / "packet_001" / "first_real_slice_closure_packet" / "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gm source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    folder = "source_v61gl" if label.startswith("v61gl") else ("source_v61gk" if label.startswith("v61gk") else "source_v61gi")
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_env_preflight_source_rows.csv", list(source_rows[0].keys()), source_rows)

gl = read_csv(source_paths["v61gl_summary"])[0]
gk = read_csv(source_paths["v61gk_summary"])[0]
gi = read_csv(source_paths["v61gi_summary"])[0]
if gl.get("v61gl_post_gk_first_real_slice_witness_preflight_ready") != "1":
    raise SystemExit("v61gm requires v61gl ready")
if gk.get("v61gk_post_gj_first_real_slice_closure_packet_ready") != "1":
    raise SystemExit("v61gm requires v61gk ready")
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gm requires v61gi ready")

path_rows = []
for path_id, env_name in PATH_ENVS.items():
    value = env_value(env_name)
    supplied = int(bool(value))
    resolved = ""
    exists = 0
    outside_repo = 0
    admissible = 0
    errors = []
    if not supplied:
        errors.append(f"missing-env:{env_name}")
    else:
        path = Path(value).expanduser()
        resolved_path = path.resolve()
        resolved = str(resolved_path)
        outside_repo = int(not is_inside(resolved_path, root))
        if not outside_repo:
            errors.append(f"path-inside-repo:{env_name}")
        exists = int(resolved_path.exists())
        if path_id == "content_witness_dir":
            if not resolved_path.is_dir():
                errors.append("content-witness-dir-missing")
            elif as_int(gl, "content_witness_preflight_ready") != 1:
                errors.append("content-witness-preflight-blocked")
            else:
                admissible = 1
        elif path_id == "minimal_slice_rows_csv":
            parent = resolved_path.parent
            if parent.exists() and not parent.is_dir():
                errors.append("minimal-slice-parent-not-dir")
            if exists and os.environ.get("V61GI_MINIMAL_SLICE_ROWS_OVERWRITE", "0") != "1":
                errors.append("minimal-slice-csv-exists:set-overwrite")
            if not errors:
                admissible = 1
        elif path_id == "operator_input_root":
            if exists and resolved_path.is_dir() and any(resolved_path.iterdir()):
                errors.append("operator-input-root-not-empty")
            if exists and not resolved_path.is_dir():
                errors.append("operator-input-root-not-dir")
            if not errors:
                admissible = 1
        elif path_id == "output_root":
            if exists and not resolved_path.is_dir():
                errors.append("output-root-not-dir")
            if not errors:
                admissible = 1
    ready = int(supplied and outside_repo and admissible and not errors)
    path_rows.append({
        "path_id": path_id,
        "env_var": env_name,
        "supplied": str(supplied),
        "resolved_path": resolved,
        "exists": str(exists),
        "outside_repo": str(outside_repo),
        "admissible": str(admissible),
        "ready": str(ready),
        "errors": ";".join(errors),
    })
write_csv(run_dir / "first_real_slice_env_path_rows.csv", list(path_rows[0].keys()), path_rows)

value_rows = []
for field_name, env_name in VALUE_ENVS.items():
    value = env_value(env_name)
    supplied = int(bool(value))
    nonfinal_free = int(supplied and not has_nonfinal_text(value))
    positive_number = ""
    min_length_ready = ""
    errors = []
    if not supplied:
        errors.append(f"missing-env:{env_name}")
    if supplied and not nonfinal_free:
        errors.append(f"nonfinal-env:{env_name}")
    if env_name in NUMERIC_ENVS:
        try:
            numeric_ok = float(value) > 0
        except ValueError:
            numeric_ok = False
        positive_number = str(int(numeric_ok))
        if not numeric_ok:
            errors.append(f"invalid-positive-number:{env_name}")
    if env_name in MIN_LENGTHS:
        length_ok = len(value) >= MIN_LENGTHS[env_name]
        min_length_ready = str(int(length_ok))
        if not length_ok:
            errors.append(f"too-short-env:{env_name}")
    ready = int(supplied and nonfinal_free and not errors)
    value_rows.append({
        "field_name": field_name,
        "env_var": env_name,
        "supplied": str(supplied),
        "nonfinal_free": str(nonfinal_free),
        "positive_number": positive_number,
        "min_length_ready": min_length_ready,
        "ready": str(ready),
        "errors": ";".join(errors),
    })
write_csv(run_dir / "first_real_slice_env_value_rows.csv", list(value_rows[0].keys()), value_rows)

ready_path_rows = sum(row["ready"] == "1" for row in path_rows)
ready_value_rows = sum(row["ready"] == "1" for row in value_rows)
content_witness_preflight_ready = as_int(gl, "content_witness_preflight_ready")
env_path_preflight_ready = int(ready_path_rows == len(path_rows) and ready_value_rows == len(value_rows) and content_witness_preflight_ready == 1)

v61gi_minimal_slice_precheck_ready = 0
precheck_exit_code = ""
precheck_stdout_path = run_dir / "v61gi_minimal_slice_precheck_stdout.csv"
precheck_stderr_path = run_dir / "v61gi_minimal_slice_precheck_stderr.txt"
if env_path_preflight_ready:
    env = os.environ.copy()
    env["V61GI_MINIMAL_SLICE_PRECHECK_CSV"] = str(run_dir / "v61gi_minimal_slice_precheck_rows.csv")
    proc = subprocess.run(
        [str(source_paths["v61gi_precheck"])],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    precheck_exit_code = str(proc.returncode)
    precheck_stdout_path.write_text(proc.stdout, encoding="utf-8")
    precheck_stderr_path.write_text(proc.stderr, encoding="utf-8")
    v61gi_minimal_slice_precheck_ready = int(proc.returncode == 0)
else:
    precheck_stdout_path.write_text("", encoding="utf-8")
    precheck_stderr_path.write_text("env-path-preflight-blocked\n", encoding="utf-8")

stage_rows = [
    {"stage_id": "01-v61gl-source", "status": "ready", "evidence": "v61gl witness preflight runner ready"},
    {"stage_id": "02-content-witness-preflight", "status": "ready" if content_witness_preflight_ready else "blocked", "evidence": f"content_witness_preflight_ready={content_witness_preflight_ready}"},
    {"stage_id": "03-final-paths", "status": "ready" if ready_path_rows == len(path_rows) else "blocked", "evidence": f"ready_path_rows={ready_path_rows}/{len(path_rows)}"},
    {"stage_id": "04-final-env-values", "status": "ready" if ready_value_rows == len(value_rows) else "blocked", "evidence": f"ready_value_rows={ready_value_rows}/{len(value_rows)}"},
    {"stage_id": "05-v61gi-minimal-slice-precheck", "status": "ready" if v61gi_minimal_slice_precheck_ready else "blocked", "evidence": f"precheck_exit_code={precheck_exit_code or 'not-run'}"},
    {"stage_id": "06-first-real-slice-closure", "status": "ready" if as_int(gk, "first_real_slice_closure_ready") else "blocked", "evidence": f"first_real_slice_closure_ready={gk.get('first_real_slice_closure_ready', '0')}"},
    {"stage_id": "07-actual-generation-full-claim", "status": "blocked", "evidence": "env preflight does not prove actual generation"},
]
write_csv(run_dir / "first_real_slice_env_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-env-preflight-package", "ready_to_run_now": "1", "command": "results/v61gm_post_gl_first_real_slice_env_preflight/preflight_001/first_real_slice_env_preflight/VERIFY_FIRST_REAL_SLICE_ENV_PREFLIGHT.sh", "purpose": "verify this metadata-only env/path preflight package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gm_post_gl_first_real_slice_env_preflight/preflight_001/first_real_slice_env_preflight/READY_NOW_COMMANDS.sh", "purpose": "show env/path preflight and final commands"},
    {"command_id": "03-check-env-preflight-ready", "ready_to_run_now": str(env_path_preflight_ready), "command": "results/v61gm_post_gl_first_real_slice_env_preflight/preflight_001/first_real_slice_env_preflight/CHECK_ENV_PREFLIGHT_READY.py", "purpose": "assert witness, path, env, and v61gi minimal-slice precheck are ready"},
    {"command_id": "04-run-first-real-slice-final-path", "ready_to_run_now": "0", "command": "RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh", "purpose": "requires real operator approval because it writes final roots and runs replay"},
]
write_csv(run_dir / "first_real_slice_env_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_ENV_PATH_ROWS.csv", run_dir / "first_real_slice_env_path_rows.csv"),
    ("FIRST_REAL_SLICE_ENV_VALUE_ROWS.csv", run_dir / "first_real_slice_env_value_rows.csv"),
    ("FIRST_REAL_SLICE_ENV_STAGE_ROWS.csv", run_dir / "first_real_slice_env_stage_rows.csv"),
    ("FIRST_REAL_SLICE_ENV_COMMAND_ROWS.csv", run_dir / "first_real_slice_env_command_rows.csv"),
    ("FIRST_REAL_SLICE_WITNESS_PREFLIGHT_ROWS.csv", source_paths["v61gl_witness_rows"]),
    ("FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv", source_paths["v61gk_target_counter_rows"]),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "CHECK_ENV_PREFLIGHT_READY.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "from pathlib import Path",
        "",
        f"SUMMARY = Path({str(summary_csv)!r})",
        f"PATH_ROWS = Path({str(run_dir / 'first_real_slice_env_path_rows.csv')!r})",
        f"VALUE_ROWS = Path({str(run_dir / 'first_real_slice_env_value_rows.csv')!r})",
        "",
        "def read_csv(path):",
        "    with path.open(newline='', encoding='utf-8') as handle:",
        "        return list(csv.DictReader(handle))",
        "",
        "summary = read_csv(SUMMARY)[0]",
        "if summary.get('env_path_preflight_ready') != '1' or summary.get('v61gi_minimal_slice_precheck_ready') != '1':",
        "    blocked = []",
        "    for row in read_csv(PATH_ROWS):",
        "        if row.get('ready') != '1':",
        "            blocked.append(row['env_var'] + ':' + row.get('errors', ''))",
        "    for row in read_csv(VALUE_ROWS):",
        "        if row.get('ready') != '1':",
        "            blocked.append(row['env_var'] + ':' + row.get('errors', ''))",
        "    raise SystemExit('first real slice env preflight remains blocked: ' + '; '.join(blocked))",
        "print('first real slice env preflight ready')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_ENV_PREFLIGHT_READY.py").chmod(0o755)

(package_dir / "RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"ROOT_DIR={shlex.quote(str(root))}",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "\"$DIR/CHECK_ENV_PREFLIGHT_READY.py\"",
        "\"$ROOT_DIR/results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh").chmod(0o755)

(package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_PREFLIGHT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_ENV_PATH_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_ENV_VALUE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_ENV_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_ENV_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_ENV_PREFLIGHT_MANIFEST.json\"",
        "test -x \"$DIR/CHECK_ENV_PREFLIGHT_READY.py\"",
        "test -x \"$DIR/RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gm package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_ENV_PREFLIGHT.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gm validates final env/path readiness before building the minimal-slice CSV.'",
        "echo 'V61GI_CONTENT_WITNESS_DIR=<dir> V61GI_MINIMAL_SLICE_ROWS_CSV=<csv> V61GI_OPERATOR_INPUT_ROOT=<root> V61GI_OUTPUT_ROOT=<root> ... ./experiments/run_v61gm_post_gl_first_real_slice_env_preflight.sh'",
        "echo 'results/v61gm_post_gl_first_real_slice_env_preflight/preflight_001/first_real_slice_env_preflight/CHECK_ENV_PREFLIGHT_READY.py'",
        "echo 'Then run RUN_FIRST_REAL_SLICE_AFTER_ENV_PREFLIGHT_IF_FINAL.sh only after external final approval.'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

summary = {
    "v61gm_post_gl_first_real_slice_env_preflight_ready": 1,
    "v61gl_post_gk_first_real_slice_witness_preflight_ready": 1,
    "v61gk_post_gj_first_real_slice_closure_packet_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "contains_real_external_evidence": 0,
    "content_witness_preflight_ready": content_witness_preflight_ready,
    "path_rows": len(path_rows),
    "ready_path_rows": ready_path_rows,
    "value_env_rows": len(value_rows),
    "ready_value_env_rows": ready_value_rows,
    "env_path_preflight_ready": env_path_preflight_ready,
    "v61gi_minimal_slice_precheck_ready": v61gi_minimal_slice_precheck_ready,
    "v61gi_minimal_slice_precheck_exit_code": precheck_exit_code or "not-run",
    "first_real_slice_closure_ready": as_int(gk, "first_real_slice_closure_ready"),
    "real_external_review_return_rows": as_int(gk, "real_external_review_return_rows"),
    "real_adjudication_rows": as_int(gk, "real_adjudication_rows"),
    "slice_answer_review_accepted_rows": as_int(gk, "slice_answer_review_accepted_rows"),
    "real_generation_result_artifacts": as_int(gk, "real_generation_result_artifacts"),
    "accepted_generation_result_artifacts": as_int(gk, "accepted_generation_result_artifacts"),
    "generation_result_accepted_rows": as_int(gk, "generation_result_accepted_rows"),
    "dual_external_return_real_ready": as_int(gk, "dual_external_return_real_ready"),
    "real_return_replay_admission_ready": as_int(gk, "real_return_replay_admission_ready"),
    "generation_acceptance_closure_ready": as_int(gk, "generation_acceptance_closure_ready"),
    "actual_model_generation_ready": as_int(gk, "actual_model_generation_ready"),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "checkpoint_payload_bytes_downloaded_by_v61gm": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_ENV_PREFLIGHT_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "FIRST_REAL_SLICE_ENV_PREFLIGHT.md").write_text(
    "\n".join([
        "# v61gm first real slice env preflight",
        "",
        f"- content_witness_preflight_ready={content_witness_preflight_ready}",
        f"- ready_path_rows={ready_path_rows}/{len(path_rows)}",
        f"- ready_value_env_rows={ready_value_rows}/{len(value_rows)}",
        f"- env_path_preflight_ready={env_path_preflight_ready}",
        f"- v61gi_minimal_slice_precheck_ready={v61gi_minimal_slice_precheck_ready}",
        "- contains_real_external_evidence=0",
        "- actual_model_generation_ready=0",
        "",
        "This preflight validates final path/env readiness only. It does not write minimal-slice CSV rows unless the downstream final wrapper is run.",
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
write_csv(run_dir / "first_real_slice_env_preflight_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gl-ready", "status": "pass", "evidence": "v61gl ready"},
    {"gate": "content-witness-preflight", "status": "pass" if content_witness_preflight_ready else "blocked", "evidence": f"content_witness_preflight_ready={content_witness_preflight_ready}"},
    {"gate": "final-paths", "status": "pass" if ready_path_rows == len(path_rows) else "blocked", "evidence": f"ready_path_rows={ready_path_rows}/{len(path_rows)}"},
    {"gate": "final-env-values", "status": "pass" if ready_value_rows == len(value_rows) else "blocked", "evidence": f"ready_value_env_rows={ready_value_rows}/{len(value_rows)}"},
    {"gate": "v61gi-minimal-slice-precheck", "status": "pass" if v61gi_minimal_slice_precheck_ready else "blocked", "evidence": f"precheck_exit_code={precheck_exit_code or 'not-run'}"},
    {"gate": "first-real-slice-closure", "status": "pass" if as_int(gk, "first_real_slice_closure_ready") else "blocked", "evidence": f"first_real_slice_closure_ready={gk.get('first_real_slice_closure_ready', '0')}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={gk.get('actual_model_generation_ready', '0')}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GM Post-GL First Real Slice Env Preflight",
    "",
    "- v61gm_post_gl_first_real_slice_env_preflight_ready=1",
    "- contains_real_external_evidence=0",
    f"- content_witness_preflight_ready={content_witness_preflight_ready}",
    f"- env_path_preflight_ready={env_path_preflight_ready}",
    f"- v61gi_minimal_slice_precheck_ready={v61gi_minimal_slice_precheck_ready}",
    f"- real_external_review_return_rows={summary['real_external_review_return_rows']}",
    f"- real_adjudication_rows={summary['real_adjudication_rows']}",
    f"- generation_result_accepted_rows={summary['generation_result_accepted_rows']}",
    f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This gate validates final env/path readiness only; real counters stay blocked until final roots are materialized and accepted downstream.",
    "",
])
(run_dir / "V61GM_POST_GL_FIRST_REAL_SLICE_ENV_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gm": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gm_post_gl_first_real_slice_env_preflight_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
