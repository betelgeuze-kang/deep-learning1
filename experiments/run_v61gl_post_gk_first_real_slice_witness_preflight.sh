#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gl_post_gk_first_real_slice_witness_preflight"
RUN_ID="${V61GL_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
CONTENT_WITNESS_DIR="${V61GL_CONTENT_WITNESS_DIR:-${V61GI_CONTENT_WITNESS_DIR:-}}"

if [[ "${V61GL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gl_post_gk_first_real_slice_witness_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gk_post_gj_first_real_slice_closure_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$CONTENT_WITNESS_DIR" <<'PY'
import csv
import hashlib
import json
import os
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
witness_dir_arg = sys.argv[5].strip()
results = root / "results"
prefix = "v61gl_post_gk_first_real_slice_witness_preflight"
package_dir = run_dir / "first_real_slice_witness_preflight"
package_dir.mkdir(parents=True, exist_ok=True)
witness_dir = Path(witness_dir_arg).expanduser().resolve() if witness_dir_arg else None

GK_PREFIX = "v61gk_post_gj_first_real_slice_closure_packet"
gk_packet = results / GK_PREFIX / "packet_001" / "first_real_slice_closure_packet"
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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def has_nonfinal_text(value):
    lowered = value.lower()
    return any(token in lowered for token in NONFINAL_TOKENS)


source_paths = {
    "v61gk_summary": results / f"{GK_PREFIX}_summary.csv",
    "v61gk_decision": results / f"{GK_PREFIX}_decision.csv",
    "v61gk_required_artifacts": gk_packet / "FIRST_REAL_SLICE_REQUIRED_ARTIFACT_ROWS.csv",
    "v61gk_content_witness_rows": gk_packet / "FIRST_REAL_SLICE_CONTENT_WITNESS_ROWS.csv",
    "v61gk_target_counter_rows": gk_packet / "FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv",
    "v61gk_selected_context": gk_packet / "MINIMAL_SLICE_SELECTED_CONTEXT.md",
    "v61gk_review_worksheet": gk_packet / "MINIMAL_SLICE_REVIEW_WORKSHEET.md",
    "v61gk_env_template": gk_packet / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh",
    "v61gk_final_runner": gk_packet / "RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gl source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gk") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_witness_preflight_source_rows.csv", list(source_rows[0].keys()), source_rows)

gk = read_csv(source_paths["v61gk_summary"])[0]
if gk.get("v61gk_post_gj_first_real_slice_closure_packet_ready") != "1":
    raise SystemExit("v61gl requires v61gk ready")

expected_witness_rows = read_csv(source_paths["v61gk_content_witness_rows"])
witness_dir_supplied = int(witness_dir is not None)
witness_dir_exists = int(witness_dir is not None and witness_dir.is_dir())
witness_dir_outside_repo = int(witness_dir is not None and not is_inside(witness_dir, root))

preflight_rows = []
for row in expected_witness_rows:
    rel = row["relative_path"]
    filename = Path(rel).name
    path = witness_dir / filename if witness_dir else None
    supplied = int(path is not None and path.is_file())
    exists = supplied
    nonempty = int(path is not None and path.is_file() and path.stat().st_size > 0)
    nonfinal_free = 0
    digest = ""
    errors = []
    if not witness_dir_supplied:
        errors.append("missing-env:V61GL_CONTENT_WITNESS_DIR")
    elif not witness_dir_exists:
        errors.append("missing-dir:V61GL_CONTENT_WITNESS_DIR")
    elif not witness_dir_outside_repo:
        errors.append("witness-dir-inside-repo")
    if witness_dir_exists:
        if not supplied:
            errors.append(f"missing-content-witness:{filename}")
        elif not nonempty:
            errors.append(f"empty-content-witness:{filename}")
        else:
            text = path.read_text(encoding="utf-8", errors="replace")
            if has_nonfinal_text(text):
                errors.append(f"nonfinal-content-witness:{filename}")
            else:
                nonfinal_free = 1
                digest = sha256(path)
    ready = int(not errors and exists and nonempty and nonfinal_free)
    preflight_rows.append({
        "witness_id": row["witness_id"],
        "required_filename": filename,
        "required_for": row["required_for"],
        "witness_dir_supplied": str(witness_dir_supplied),
        "witness_dir_exists": str(witness_dir_exists),
        "witness_dir_outside_repo": str(witness_dir_outside_repo),
        "exists": str(exists),
        "nonempty": str(nonempty),
        "nonfinal_content_free": str(nonfinal_free),
        "ready": str(ready),
        "sha256": digest,
        "errors": ";".join(errors),
    })
write_csv(run_dir / "first_real_slice_witness_preflight_rows.csv", list(preflight_rows[0].keys()), preflight_rows)

ready_witness_rows = sum(row["ready"] == "1" for row in preflight_rows)
missing_witness_rows = sum("missing-content-witness" in row["errors"] for row in preflight_rows)
nonfinal_witness_rows = sum("nonfinal-content-witness" in row["errors"] for row in preflight_rows)
content_witness_preflight_ready = int(
    witness_dir_supplied
    and witness_dir_exists
    and witness_dir_outside_repo
    and ready_witness_rows == len(expected_witness_rows)
)

gap_rows = [
    {"gap_id": "01-content-witness-dir", "status": "ready" if witness_dir_exists and witness_dir_outside_repo else "blocked", "evidence": f"supplied={witness_dir_supplied}; exists={witness_dir_exists}; outside_repo={witness_dir_outside_repo}", "next_action": "provide repo-external V61GL_CONTENT_WITNESS_DIR"},
    {"gap_id": "02-content-witness-files", "status": "ready" if ready_witness_rows == len(expected_witness_rows) else "blocked", "evidence": f"ready_witness_rows={ready_witness_rows}/{len(expected_witness_rows)}; missing={missing_witness_rows}; nonfinal={nonfinal_witness_rows}", "next_action": "write final non-placeholder witness text into all seven files"},
    {"gap_id": "03-minimal-slice-env", "status": "blocked", "evidence": "v61gl validates witness files only", "next_action": "fill V61GI reviewer/generation/latency/authority env vars"},
    {"gap_id": "04-final-replay", "status": "blocked", "evidence": f"first_real_slice_closure_ready={gk.get('first_real_slice_closure_ready', '0')}", "next_action": "run v61gk guarded final path after witness and env preflight"},
]
write_csv(run_dir / "first_real_slice_witness_gap_rows.csv", list(gap_rows[0].keys()), gap_rows)

stage_rows = [
    {"stage_id": "01-v61gk-source", "status": "ready", "evidence": "v61gk first-real-slice packet ready"},
    {"stage_id": "02-witness-dir-supplied", "status": "ready" if witness_dir_supplied else "blocked", "evidence": f"witness_dir_supplied={witness_dir_supplied}"},
    {"stage_id": "03-witness-dir-exists", "status": "ready" if witness_dir_exists else "blocked", "evidence": f"witness_dir_exists={witness_dir_exists}"},
    {"stage_id": "04-witness-dir-outside-repo", "status": "ready" if witness_dir_outside_repo else "blocked", "evidence": f"witness_dir_outside_repo={witness_dir_outside_repo}"},
    {"stage_id": "05-content-witness-preflight", "status": "ready" if content_witness_preflight_ready else "blocked", "evidence": f"ready_witness_rows={ready_witness_rows}/{len(expected_witness_rows)}"},
    {"stage_id": "06-first-real-slice-closure", "status": "ready" if as_int(gk, "first_real_slice_closure_ready") else "blocked", "evidence": f"first_real_slice_closure_ready={gk.get('first_real_slice_closure_ready', '0')}"},
    {"stage_id": "07-actual-generation-full-claim", "status": "blocked", "evidence": "witness preflight does not prove actual generation"},
]
write_csv(run_dir / "first_real_slice_witness_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-witness-preflight-package", "ready_to_run_now": "1", "command": "results/v61gl_post_gk_first_real_slice_witness_preflight/preflight_001/first_real_slice_witness_preflight/VERIFY_FIRST_REAL_SLICE_WITNESS_PREFLIGHT.sh", "purpose": "verify this metadata-only witness preflight package"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gl_post_gk_first_real_slice_witness_preflight/preflight_001/first_real_slice_witness_preflight/READY_NOW_COMMANDS.sh", "purpose": "show witness preflight and finalization commands"},
    {"command_id": "03-check-witness-preflight-ready", "ready_to_run_now": str(content_witness_preflight_ready), "command": "results/v61gl_post_gk_first_real_slice_witness_preflight/preflight_001/first_real_slice_witness_preflight/CHECK_WITNESS_PREFLIGHT_READY.py", "purpose": "assert all seven witness files are present, external, nonempty, and nonfinal-free"},
    {"command_id": "04-run-after-witness-preflight", "ready_to_run_now": "0", "command": "source FIRST_REAL_SLICE_ENV_TEMPLATE.sh && RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh", "purpose": "requires witness preflight plus full v61gi final env values"},
]
write_csv(run_dir / "first_real_slice_witness_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_WITNESS_PREFLIGHT_ROWS.csv", run_dir / "first_real_slice_witness_preflight_rows.csv"),
    ("FIRST_REAL_SLICE_WITNESS_GAP_ROWS.csv", run_dir / "first_real_slice_witness_gap_rows.csv"),
    ("FIRST_REAL_SLICE_WITNESS_STAGE_ROWS.csv", run_dir / "first_real_slice_witness_stage_rows.csv"),
    ("FIRST_REAL_SLICE_WITNESS_COMMAND_ROWS.csv", run_dir / "first_real_slice_witness_command_rows.csv"),
    ("FIRST_REAL_SLICE_REQUIRED_ARTIFACT_ROWS.csv", source_paths["v61gk_required_artifacts"]),
    ("FIRST_REAL_SLICE_TARGET_COUNTER_ROWS.csv", source_paths["v61gk_target_counter_rows"]),
    ("MINIMAL_SLICE_SELECTED_CONTEXT.md", source_paths["v61gk_selected_context"]),
    ("MINIMAL_SLICE_REVIEW_WORKSHEET.md", source_paths["v61gk_review_worksheet"]),
    ("FIRST_REAL_SLICE_ENV_TEMPLATE.sh", source_paths["v61gk_env_template"]),
]:
    shutil.copy2(src, package_dir / rel)
for rel in ["FIRST_REAL_SLICE_ENV_TEMPLATE.sh"]:
    (package_dir / rel).chmod(0o755)

(package_dir / "CHECK_WITNESS_PREFLIGHT_READY.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import csv",
        "from pathlib import Path",
        "",
        f"SUMMARY = Path({str(summary_csv)!r})",
        f"ROWS = Path({str(run_dir / 'first_real_slice_witness_preflight_rows.csv')!r})",
        "",
        "def read_csv(path):",
        "    with path.open(newline='', encoding='utf-8') as handle:",
        "        return list(csv.DictReader(handle))",
        "",
        "summary = read_csv(SUMMARY)[0]",
        "rows = read_csv(ROWS)",
        "if summary.get('content_witness_preflight_ready') != '1':",
        "    blocked = [row['required_filename'] + ':' + row['errors'] for row in rows if row.get('ready') != '1']",
        "    raise SystemExit('content witness preflight remains blocked: ' + '; '.join(blocked))",
        "print('content witness preflight ready')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "CHECK_WITNESS_PREFLIGHT_READY.py").chmod(0o755)

(package_dir / "RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"ROOT_DIR={shlex.quote(str(root))}",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        ": \"${V61GI_CONTENT_WITNESS_DIR:?set V61GI_CONTENT_WITNESS_DIR}\"",
        "V61GL_CONTENT_WITNESS_DIR=\"$V61GI_CONTENT_WITNESS_DIR\" V61GL_REUSE_EXISTING=0 \"$ROOT_DIR/experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh\" >/dev/null",
        "\"$DIR/CHECK_WITNESS_PREFLIGHT_READY.py\"",
        "\"$ROOT_DIR/results/v61gk_post_gj_first_real_slice_closure_packet/packet_001/first_real_slice_closure_packet/RUN_FIRST_REAL_SLICE_FROM_WITNESS_DIR_IF_FINAL.sh\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh").chmod(0o755)

(package_dir / "VERIFY_FIRST_REAL_SLICE_WITNESS_PREFLIGHT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WITNESS_PREFLIGHT_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WITNESS_GAP_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WITNESS_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WITNESS_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_WITNESS_PREFLIGHT_MANIFEST.json\"",
        "test -x \"$DIR/CHECK_WITNESS_PREFLIGHT_READY.py\"",
        "test -x \"$DIR/RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gl package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_WITNESS_PREFLIGHT.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'v61gl validates the seven first-slice witness files before the full v61gi/v61gk final path.'",
        "echo 'V61GL_CONTENT_WITNESS_DIR=<repo-external-witness-dir> ./experiments/run_v61gl_post_gk_first_real_slice_witness_preflight.sh'",
        "echo 'results/v61gl_post_gk_first_real_slice_witness_preflight/preflight_001/first_real_slice_witness_preflight/CHECK_WITNESS_PREFLIGHT_READY.py'",
        "echo 'Then fill FIRST_REAL_SLICE_ENV_TEMPLATE.sh values and run RUN_FIRST_REAL_SLICE_AFTER_WITNESS_PREFLIGHT_IF_FINAL.sh'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "contains_real_external_evidence": 0,
    "witness_dir_supplied": witness_dir_supplied,
    "witness_dir_exists": witness_dir_exists,
    "witness_dir_outside_repo": witness_dir_outside_repo,
    "content_witness_rows": len(expected_witness_rows),
    "ready_content_witness_rows": ready_witness_rows,
    "missing_content_witness_rows": missing_witness_rows,
    "nonfinal_content_witness_rows": nonfinal_witness_rows,
    "content_witness_preflight_ready": content_witness_preflight_ready,
    "first_real_slice_closure_ready": as_int(gk, "first_real_slice_closure_ready"),
    "actual_model_generation_ready": as_int(gk, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_WITNESS_PREFLIGHT_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(package_dir / "FIRST_REAL_SLICE_WITNESS_PREFLIGHT.md").write_text(
    "\n".join([
        "# v61gl first real slice witness preflight",
        "",
        f"- witness_dir_supplied={witness_dir_supplied}",
        f"- witness_dir_exists={witness_dir_exists}",
        f"- witness_dir_outside_repo={witness_dir_outside_repo}",
        f"- ready_content_witness_rows={ready_witness_rows}/{len(expected_witness_rows)}",
        f"- content_witness_preflight_ready={content_witness_preflight_ready}",
        "- contains_real_external_evidence=0",
        "- actual_model_generation_ready=0",
        "",
        "This preflight validates witness file readiness only. It does not count real review/adjudication/generation rows until v61gi/v61gj/v61gf accept the final assembled roots.",
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
write_csv(run_dir / "first_real_slice_witness_preflight_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

summary = {
    "v61gl_post_gk_first_real_slice_witness_preflight_ready": 1,
    "v61gk_post_gj_first_real_slice_closure_packet_ready": 1,
    "contains_real_external_evidence": 0,
    "witness_dir_supplied": witness_dir_supplied,
    "witness_dir_exists": witness_dir_exists,
    "witness_dir_outside_repo": witness_dir_outside_repo,
    "content_witness_rows": len(expected_witness_rows),
    "ready_content_witness_rows": ready_witness_rows,
    "missing_content_witness_rows": missing_witness_rows,
    "nonfinal_content_witness_rows": nonfinal_witness_rows,
    "content_witness_preflight_ready": content_witness_preflight_ready,
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
    "package_file_rows": len(package_file_rows),
    "metadata_only_package_file_rows": sum(row["metadata_only"] == "1" for row in package_file_rows),
    "payload_like_package_file_rows": sum(row["payload_like"] == "1" for row in package_file_rows),
    "checkpoint_payload_bytes_downloaded_by_v61gl": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gk-ready", "status": "pass", "evidence": "v61gk ready"},
    {"gate": "witness-dir-supplied", "status": "pass" if witness_dir_supplied else "blocked", "evidence": f"witness_dir_supplied={witness_dir_supplied}"},
    {"gate": "witness-dir-outside-repo", "status": "pass" if witness_dir_outside_repo else "blocked", "evidence": f"witness_dir_outside_repo={witness_dir_outside_repo}"},
    {"gate": "content-witness-preflight", "status": "pass" if content_witness_preflight_ready else "blocked", "evidence": f"ready_content_witness_rows={ready_witness_rows}/{len(expected_witness_rows)}"},
    {"gate": "first-real-slice-closure", "status": "pass" if as_int(gk, "first_real_slice_closure_ready") else "blocked", "evidence": f"first_real_slice_closure_ready={gk.get('first_real_slice_closure_ready', '0')}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": f"actual_model_generation_ready={gk.get('actual_model_generation_ready', '0')}"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = "\n".join([
    "# V61GL Post-GK First Real Slice Witness Preflight",
    "",
    "- v61gl_post_gk_first_real_slice_witness_preflight_ready=1",
    "- contains_real_external_evidence=0",
    f"- witness_dir_supplied={witness_dir_supplied}",
    f"- witness_dir_exists={witness_dir_exists}",
    f"- ready_content_witness_rows={ready_witness_rows}/{len(expected_witness_rows)}",
    f"- content_witness_preflight_ready={content_witness_preflight_ready}",
    f"- real_external_review_return_rows={summary['real_external_review_return_rows']}",
    f"- real_adjudication_rows={summary['real_adjudication_rows']}",
    f"- generation_result_accepted_rows={summary['generation_result_accepted_rows']}",
    f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "This gate validates witness text readiness only; real return and replay counters stay blocked until final roots are accepted downstream.",
    "",
])
(run_dir / "V61GL_POST_GK_FIRST_REAL_SLICE_WITNESS_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gl": 0,
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

print(f"v61gl_post_gk_first_real_slice_witness_preflight_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
