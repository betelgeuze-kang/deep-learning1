#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gn_post_gm_first_real_slice_minimal_csv_builder"
RUN_ID="${V61GN_RUN_ID:-builder_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXECUTE_BUILD="${V61GN_EXECUTE_BUILD:-0}"

if [[ "${V61GN_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gn_post_gm_first_real_slice_minimal_csv_builder_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GM_RUN_ID="${RUN_ID}_env" \
V61GM_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gm_post_gl_first_real_slice_env_preflight.sh" >/dev/null
V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$EXECUTE_BUILD" <<'PY'
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
execute_build = int((sys.argv[6].strip() or "0") == "1")
results = root / "results"
prefix = "v61gn_post_gm_first_real_slice_minimal_csv_builder"
package_dir = run_dir / "first_real_slice_minimal_csv_builder"
package_dir.mkdir(parents=True, exist_ok=True)

GM_PREFIX = "v61gm_post_gl_first_real_slice_env_preflight"
GK_PREFIX = "v61gk_post_gj_first_real_slice_closure_packet"
GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"
NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_csv_with_fields(path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        return rows, reader.fieldnames or []


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


def positive_number(value):
    try:
        return float(value) > 0
    except (TypeError, ValueError):
        return False


source_paths = {
    "v61gm_summary": results / GM_PREFIX / f"{run_id}_env" / f"{GM_PREFIX}_summary.csv",
    "v61gm_decision": results / GM_PREFIX / f"{run_id}_env" / f"{GM_PREFIX}_decision.csv",
    "v61gm_env_path_rows": results / GM_PREFIX / f"{run_id}_env" / "first_real_slice_env_path_rows.csv",
    "v61gm_env_value_rows": results / GM_PREFIX / f"{run_id}_env" / "first_real_slice_env_value_rows.csv",
    "v61gk_target_counter_rows": results / GK_PREFIX / "packet_001" / "first_real_slice_closure_packet" / "FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_build_wrapper": gi_scaffold / "RUN_PRECHECK_AND_BUILD_MINIMAL_SLICE_IF_READY.sh",
    "minimal_slice_template": gi_scaffold / "MINIMAL_SLICE_ROWS.csv.template",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gn source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    folder = "source_v61gm" if label.startswith("v61gm") else ("source_v61gk" if label.startswith("v61gk") else "source_v61gi")
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_minimal_csv_builder_source_rows.csv", list(source_rows[0].keys()), source_rows)

gm = read_csv(source_paths["v61gm_summary"])[0]
gi = read_csv(source_paths["v61gi_summary"])[0]
if gm.get("v61gm_post_gl_first_real_slice_env_preflight_ready") != "1":
    raise SystemExit("v61gn requires v61gm ready")
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61gn requires v61gi ready")

minimal_csv_raw = os.environ.get("V61GI_MINIMAL_SLICE_ROWS_CSV", "").strip()
minimal_csv = Path(minimal_csv_raw).expanduser().resolve() if minimal_csv_raw else None
build_admitted = int(as_int(gm, "env_path_preflight_ready") and as_int(gm, "v61gi_minimal_slice_precheck_ready"))
build_executed = 0
build_exit_code = "not-run"
build_stdout = ""
build_stderr = ""
if execute_build and build_admitted:
    proc = subprocess.run(
        [str(source_paths["v61gi_build_wrapper"])],
        env=os.environ.copy(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    build_executed = 1
    build_exit_code = str(proc.returncode)
    build_stdout = proc.stdout
    build_stderr = proc.stderr
    (run_dir / "minimal_slice_build_stdout.txt").write_text(build_stdout, encoding="utf-8")
    (run_dir / "minimal_slice_build_stderr.txt").write_text(build_stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"v61gn minimal-slice build failed: {proc.returncode}")
else:
    (run_dir / "minimal_slice_build_stdout.txt").write_text("", encoding="utf-8")
    (run_dir / "minimal_slice_build_stderr.txt").write_text("build-not-executed\n", encoding="utf-8")

template_rows, template_fields = read_csv_with_fields(source_paths["minimal_slice_template"])
expected_fields = template_fields
csv_supplied = int(minimal_csv is not None)
csv_exists = int(minimal_csv is not None and minimal_csv.is_file())
csv_rows = []
csv_fields = []
csv_errors = []
if not csv_supplied:
    csv_errors.append("missing-env:V61GI_MINIMAL_SLICE_ROWS_CSV")
elif not csv_exists:
    csv_errors.append("minimal-slice-csv-missing")
else:
    csv_rows, csv_fields = read_csv_with_fields(minimal_csv)

schema_ready = 0
row_count_ready = 0
hash_binding_ready = 0
nonfinal_free_ready = 0
numeric_ready = 0
witness_path_ready = 0
if csv_exists:
    missing_fields = sorted(set(expected_fields) - set(csv_fields))
    if missing_fields:
        csv_errors.append("missing-fields:" + ";".join(missing_fields))
    schema_ready = int(not missing_fields)
    row_count_ready = int(len(csv_rows) == 1)
    if not row_count_ready:
        csv_errors.append(f"minimal-slice-row-count:{len(csv_rows)}")
    if csv_rows:
        row = csv_rows[0]
        nonfinal_fields = [field for field, value in row.items() if has_nonfinal_text(value)]
        if nonfinal_fields:
            csv_errors.append("nonfinal-fields:" + ";".join(nonfinal_fields))
        nonfinal_free_ready = int(not nonfinal_fields)
        numeric_fields = ["prompt_tokens", "output_tokens", "prefill_ms", "decode_ms", "total_ms", "tokens_per_second"]
        bad_numeric = [field for field in numeric_fields if not positive_number(row.get(field))]
        if bad_numeric:
            csv_errors.append("invalid-positive-number:" + ";".join(bad_numeric))
        numeric_ready = int(not bad_numeric)
        sha_fields = [
            "review_comment_sha256",
            "adjudication_reason_sha256",
            "credential_statement_sha256",
            "conflict_statement_sha256",
            "answer_text_sha256",
            "run_transcript_sha256",
            "source_file_sha256",
        ]
        path_fields = {
            "review_comment_sha256": "review_comment_content_path",
            "adjudication_reason_sha256": "adjudication_reason_content_path",
            "credential_statement_sha256": "credential_statement_content_path",
            "conflict_statement_sha256": "conflict_statement_content_path",
            "answer_text_sha256": "answer_text_content_path",
            "run_transcript_sha256": "run_transcript_content_path",
            "source_file_sha256": "source_file_content_path",
        }
        bad_hash = []
        bad_path = []
        mismatch = []
        for sha_field in sha_fields:
            value = row.get(sha_field, "")
            if not SHA_RE.match(value):
                bad_hash.append(sha_field)
                continue
            path_value = row.get(path_fields[sha_field], "")
            path = Path(path_value).expanduser() if path_value else None
            if path is None or not path.is_file() or path.stat().st_size == 0:
                bad_path.append(path_fields[sha_field])
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if has_nonfinal_text(text):
                bad_path.append(path_fields[sha_field] + ":nonfinal")
                continue
            if sha256(path) != value:
                mismatch.append(sha_field)
        if bad_hash:
            csv_errors.append("invalid-sha:" + ";".join(bad_hash))
        if bad_path:
            csv_errors.append("invalid-witness-path:" + ";".join(bad_path))
        if mismatch:
            csv_errors.append("witness-hash-mismatch:" + ";".join(mismatch))
        hash_binding_ready = int(not bad_hash and not mismatch)
        witness_path_ready = int(not bad_path)

minimal_slice_csv_ready = int(
    csv_exists
    and schema_ready
    and row_count_ready
    and hash_binding_ready
    and witness_path_ready
    and nonfinal_free_ready
    and numeric_ready
)

csv_status_rows = [{
    "csv_supplied": str(csv_supplied),
    "csv_path": str(minimal_csv) if minimal_csv else "",
    "csv_exists": str(csv_exists),
    "build_admitted": str(build_admitted),
    "build_requested": str(execute_build),
    "build_executed": str(build_executed),
    "build_exit_code": build_exit_code,
    "row_count": str(len(csv_rows)),
    "schema_ready": str(schema_ready),
    "row_count_ready": str(row_count_ready),
    "hash_binding_ready": str(hash_binding_ready),
    "witness_path_ready": str(witness_path_ready),
    "nonfinal_free_ready": str(nonfinal_free_ready),
    "numeric_ready": str(numeric_ready),
    "minimal_slice_csv_ready": str(minimal_slice_csv_ready),
    "errors": ";".join(csv_errors),
}]
write_csv(run_dir / "first_real_slice_minimal_csv_status_rows.csv", list(csv_status_rows[0].keys()), csv_status_rows)

stage_rows = [
    {"stage_id": "01-v61gm-source", "status": "ready", "evidence": "v61gm env preflight runner ready"},
    {"stage_id": "02-env-path-preflight", "status": "ready" if build_admitted else "blocked", "evidence": f"env_path_preflight_ready={gm.get('env_path_preflight_ready')}; v61gi_minimal_slice_precheck_ready={gm.get('v61gi_minimal_slice_precheck_ready')}"},
    {"stage_id": "03-build-requested", "status": "ready" if execute_build else "blocked", "evidence": f"execute_build={execute_build}"},
    {"stage_id": "04-minimal-slice-build", "status": "ready" if build_executed else "blocked", "evidence": f"build_executed={build_executed}; exit_code={build_exit_code}"},
    {"stage_id": "05-minimal-slice-csv-ready", "status": "ready" if minimal_slice_csv_ready else "blocked", "evidence": f"minimal_slice_csv_ready={minimal_slice_csv_ready}; errors={';'.join(csv_errors)}"},
    {"stage_id": "06-first-real-slice-closure", "status": "ready" if as_int(gm, "first_real_slice_closure_ready") else "blocked", "evidence": f"first_real_slice_closure_ready={gm.get('first_real_slice_closure_ready', '0')}"},
    {"stage_id": "07-actual-generation-full-claim", "status": "blocked", "evidence": "minimal CSV build does not prove actual generation"},
]
write_csv(run_dir / "first_real_slice_minimal_csv_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-minimal-csv-package", "ready_to_run_now": "1", "command": "results/v61gn_post_gm_first_real_slice_minimal_csv_builder/builder_001/first_real_slice_minimal_csv_builder/VERIFY_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.sh", "purpose": "verify this metadata-only minimal CSV builder package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gn_post_gm_first_real_slice_minimal_csv_builder/builder_001/first_real_slice_minimal_csv_builder/READY_NOW_COMMANDS.sh", "purpose": "show minimal CSV builder/finalization commands"},
    {"command_id": "03-run-builder", "ready_to_run_now": str(build_admitted), "command": "V61GN_EXECUTE_BUILD=1 ./experiments/run_v61gn_post_gm_first_real_slice_minimal_csv_builder.sh", "purpose": "write the one-row minimal-slice CSV after env/witness preflight"},
    {"command_id": "04-check-minimal-csv-ready", "ready_to_run_now": str(minimal_slice_csv_ready), "command": "results/v61gn_post_gm_first_real_slice_minimal_csv_builder/builder_001/first_real_slice_minimal_csv_builder/CHECK_MINIMAL_CSV_READY.py", "purpose": "assert the generated CSV is ready for materialization"},
]
write_csv(run_dir / "first_real_slice_minimal_csv_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_MINIMAL_CSV_STATUS_ROWS.csv", run_dir / "first_real_slice_minimal_csv_status_rows.csv"),
    ("FIRST_REAL_SLICE_MINIMAL_CSV_STAGE_ROWS.csv", run_dir / "first_real_slice_minimal_csv_stage_rows.csv"),
    ("FIRST_REAL_SLICE_MINIMAL_CSV_COMMAND_ROWS.csv", run_dir / "first_real_slice_minimal_csv_command_rows.csv"),
    ("FIRST_REAL_SLICE_ENV_PATH_ROWS.csv", source_paths["v61gm_env_path_rows"]),
    ("FIRST_REAL_SLICE_ENV_VALUE_ROWS.csv", source_paths["v61gm_env_value_rows"]),
    ("FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv", source_paths["v61gk_target_counter_rows"]),
    ("MINIMAL_SLICE_ROWS.csv.template", source_paths["minimal_slice_template"]),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "CHECK_MINIMAL_CSV_READY.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "from pathlib import Path",
        "",
        f"SUMMARY = Path({str(summary_csv)!r})",
        f"STATUS = Path({str(run_dir / 'first_real_slice_minimal_csv_status_rows.csv')!r})",
        "",
        "def read_csv(path):",
        "    with path.open(newline='', encoding='utf-8') as handle:",
        "        return list(csv.DictReader(handle))",
        "",
        "summary = read_csv(SUMMARY)[0]",
        "status = read_csv(STATUS)[0]",
        "if summary.get('minimal_slice_csv_ready') != '1':",
        "    raise SystemExit('minimal slice CSV remains blocked: ' + status.get('errors', ''))",
        "print('minimal slice CSV ready')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_MINIMAL_CSV_READY.py").chmod(0o755)

(package_dir / "VERIFY_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_MINIMAL_CSV_STATUS_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_MINIMAL_CSV_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_MINIMAL_CSV_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER_MANIFEST.json\"",
        "test -x \"$DIR/CHECK_MINIMAL_CSV_READY.py\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gn package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gn builds and verifies the one-row minimal-slice CSV after v61gm is ready.'",
        "echo 'V61GN_EXECUTE_BUILD=1 ./experiments/run_v61gn_post_gm_first_real_slice_minimal_csv_builder.sh'",
        "echo 'results/v61gn_post_gm_first_real_slice_minimal_csv_builder/builder_001/first_real_slice_minimal_csv_builder/CHECK_MINIMAL_CSV_READY.py'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

summary = {
    "v61gn_post_gm_first_real_slice_minimal_csv_builder_ready": 1,
    "v61gm_post_gl_first_real_slice_env_preflight_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "contains_real_external_evidence": 0,
    "env_path_preflight_ready": as_int(gm, "env_path_preflight_ready"),
    "v61gi_minimal_slice_precheck_ready": as_int(gm, "v61gi_minimal_slice_precheck_ready"),
    "build_admitted": build_admitted,
    "build_requested": execute_build,
    "build_executed": build_executed,
    "build_exit_code": build_exit_code,
    "minimal_slice_csv_supplied": csv_supplied,
    "minimal_slice_csv_exists": csv_exists,
    "minimal_slice_csv_row_count": len(csv_rows),
    "minimal_slice_csv_schema_ready": schema_ready,
    "minimal_slice_csv_hash_binding_ready": hash_binding_ready,
    "minimal_slice_csv_witness_path_ready": witness_path_ready,
    "minimal_slice_csv_nonfinal_free_ready": nonfinal_free_ready,
    "minimal_slice_csv_numeric_ready": numeric_ready,
    "minimal_slice_csv_ready": minimal_slice_csv_ready,
    "first_real_slice_closure_ready": as_int(gm, "first_real_slice_closure_ready"),
    "real_external_review_return_rows": as_int(gm, "real_external_review_return_rows"),
    "real_adjudication_rows": as_int(gm, "real_adjudication_rows"),
    "slice_answer_review_accepted_rows": as_int(gm, "slice_answer_review_accepted_rows"),
    "real_generation_result_artifacts": as_int(gm, "real_generation_result_artifacts"),
    "accepted_generation_result_artifacts": as_int(gm, "accepted_generation_result_artifacts"),
    "generation_result_accepted_rows": as_int(gm, "generation_result_accepted_rows"),
    "dual_external_return_real_ready": as_int(gm, "dual_external_return_real_ready"),
    "real_return_replay_admission_ready": as_int(gm, "real_return_replay_admission_ready"),
    "generation_acceptance_closure_ready": as_int(gm, "generation_acceptance_closure_ready"),
    "actual_model_generation_ready": as_int(gm, "actual_model_generation_ready"),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "source_file_rows": len(source_rows),
    "checkpoint_payload_bytes_downloaded_by_v61gn": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER.md").write_text(
    "\n".join([
        "# v61gn first real slice minimal CSV builder",
        "",
        f"- env_path_preflight_ready={summary['env_path_preflight_ready']}",
        f"- build_admitted={build_admitted}",
        f"- build_executed={build_executed}",
        f"- minimal_slice_csv_ready={minimal_slice_csv_ready}",
        "- contains_real_external_evidence=0",
        "- actual_model_generation_ready=0",
        "",
        "This gate can write the one-row minimal-slice CSV, but it does not materialize final roots or count real evidence.",
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
write_csv(run_dir / "first_real_slice_minimal_csv_builder_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gm-ready", "status": "pass", "evidence": "v61gm ready"},
    {"gate": "env-path-preflight", "status": "pass" if build_admitted else "blocked", "evidence": f"build_admitted={build_admitted}"},
    {"gate": "minimal-csv-build-requested", "status": "pass" if execute_build else "blocked", "evidence": f"execute_build={execute_build}"},
    {"gate": "minimal-csv-build-executed", "status": "pass" if build_executed else "blocked", "evidence": f"build_executed={build_executed}; exit_code={build_exit_code}"},
    {"gate": "minimal-csv-ready", "status": "pass" if minimal_slice_csv_ready else "blocked", "evidence": f"minimal_slice_csv_ready={minimal_slice_csv_ready}; errors={';'.join(csv_errors)}"},
    {"gate": "first-real-slice-closure", "status": "pass" if as_int(gm, "first_real_slice_closure_ready") else "blocked", "evidence": f"first_real_slice_closure_ready={gm.get('first_real_slice_closure_ready', '0')}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={gm.get('actual_model_generation_ready', '0')}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GN Post-GM First Real Slice Minimal CSV Builder",
    "",
    "- v61gn_post_gm_first_real_slice_minimal_csv_builder_ready=1",
    "- contains_real_external_evidence=0",
    f"- build_admitted={build_admitted}",
    f"- build_executed={build_executed}",
    f"- minimal_slice_csv_ready={minimal_slice_csv_ready}",
    f"- real_external_review_return_rows={summary['real_external_review_return_rows']}",
    f"- real_adjudication_rows={summary['real_adjudication_rows']}",
    f"- generation_result_accepted_rows={summary['generation_result_accepted_rows']}",
    f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This gate validates the one-row minimal CSV only; real counters stay blocked until final roots are materialized and accepted downstream.",
    "",
])
(run_dir / "V61GN_POST_GM_FIRST_REAL_SLICE_MINIMAL_CSV_BUILDER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gn": 0,
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

print(f"v61gn_post_gm_first_real_slice_minimal_csv_builder_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
