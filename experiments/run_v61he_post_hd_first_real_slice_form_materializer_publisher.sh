#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61he_post_hd_first_real_slice_form_materializer_publisher"
RUN_ID="${V61HE_RUN_ID:-form_materializer_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HE_WORK_ROOT:-${V61GU_WORK_ROOT:-}}"
PUBLISH_MATERIALIZER="${V61HE_PUBLISH_MATERIALIZER:-0}"
GV_RUN_ID="${V61HE_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61HE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61he_post_hd_first_real_slice_form_materializer_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hd_post_hc_first_real_slice_external_return_form_publisher.sh" >/dev/null
V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_MATERIALIZER" <<'PY'
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
run_id = sys.argv[5]
gv_run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
publish_requested = int((sys.argv[8].strip() or "0") == "1")
results = root / "results"
prefix = "v61he_post_hd_first_real_slice_form_materializer_publisher"
package_dir = run_dir / "first_real_slice_form_materializer_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HD_PREFIX = "v61hd_post_hc_first_real_slice_external_return_form_publisher"
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
    "v61hd_summary": results / f"{HD_PREFIX}_summary.csv",
    "v61hd_decision": results / f"{HD_PREFIX}_decision.csv",
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61he source {label}: {path}")
source_rows = [copy_source(label, path, "source_v61hd" if label.startswith("v61hd") else "source_v61gv") for label, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_form_materializer_source_rows.csv", list(source_rows[0].keys()), source_rows)

hd = read_csv(source_paths["v61hd_summary"])[0]
gv = read_csv(source_paths["v61gv_summary"])[0]
if hd.get("v61hd_post_hc_first_real_slice_external_return_form_publisher_ready") != "1":
    raise SystemExit("v61he requires v61hd ready")
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61he requires v61gv ready")

materializer_text = r'''#!/usr/bin/env python3
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
WITNESS_TEXT_MAP = {
    "review_comment.txt": ("v53_review_return", "review_comment_text"),
    "adjudication_reason.txt": ("v53_review_return", "adjudication_reason_text"),
    "credential_statement.txt": ("v53_review_return", "credential_statement_text"),
    "conflict_statement.txt": ("v53_review_return", "conflict_statement_text"),
    "answer_text.txt": ("v61_generation_return", "answer_text"),
    "run_transcript.txt": ("v61_generation_return", "run_transcript_text"),
}
ENV_MAP = {
    "V61GI_REVIEWER_ID": ("v53_review_return", "reviewer_id"),
    "V61GI_ADJUDICATOR_ID": ("v53_review_return", "adjudicator_id"),
    "V61GI_GENERATION_ID": ("v61_generation_return", "generation_id"),
    "V61GI_CITATION_ID": ("v61_generation_return", "citation_id"),
    "V61GI_CHECKPOINT_ROOT": ("v61_generation_return", "checkpoint_root"),
    "V61GI_LATENCY_ROW_ID": ("v61_generation_return", "latency_row_id"),
    "V61GI_PROMPT_TOKENS": ("v61_generation_return", "prompt_tokens"),
    "V61GI_OUTPUT_TOKENS": ("v61_generation_return", "output_tokens"),
    "V61GI_PREFILL_MS": ("v61_generation_return", "prefill_ms"),
    "V61GI_DECODE_MS": ("v61_generation_return", "decode_ms"),
    "V61GI_TOTAL_MS": ("v61_generation_return", "total_ms"),
    "V61GI_TOKENS_PER_SECOND": ("v61_generation_return", "tokens_per_second"),
    "V61GI_V53_AUTHORITY_STATEMENT": ("v53_review_return", "reviewer_authority_statement"),
    "V61GI_V61_AUTHORITY_STATEMENT": ("v61_generation_return", "generation_operator_authority_statement"),
    "V61GI_EXTERNAL_RETURN_ATTESTATION": ("", "external_return_attestation"),
    "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT": ("", "operator_input_assembly_authority_statement"),
}

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)

def require_text(value, label):
    text = str(value).strip()
    if not text or has_nonfinal(text):
        raise SystemExit(f"nonfinal-materializer-value:{label}")
    return text

def replace_exports(env_path, updates):
    lines = env_path.read_text(encoding="utf-8").splitlines()
    seen = set()
    rendered = []
    for line in lines:
        if line.startswith("export ") and "=" in line:
            key = line.split(" ", 1)[1].split("=", 1)[0]
            if key in updates:
                rendered.append(f"export {key}={shlex.quote(str(updates[key]))}")
                seen.add(key)
                continue
        rendered.append(line)
    missing = sorted(set(updates) - seen)
    if missing:
        raise SystemExit("env-template-missing-exports:" + ";".join(missing))
    env_path.write_text("\n".join(rendered) + "\n", encoding="utf-8")

def main():
    script_dir = Path(__file__).resolve().parent
    work_root = script_dir.parent
    form_path = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else work_root / "external_return_form" / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json"
    report_path = work_root / "external_return_form" / "materialize.validation_rows.csv"
    validator = work_root / "external_return_form" / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py"
    if not validator.is_file():
        raise SystemExit("missing-form-validator")
    subprocess.run([str(validator), str(form_path), str(report_path)], check=True)
    payload = json.loads(form_path.read_text(encoding="utf-8"))
    witness_dir = work_root / "final_content_witness"
    env_path = work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh"
    if not witness_dir.is_dir() or not env_path.is_file():
        raise SystemExit("workspace-layout-missing")
    source_file = witness_dir / "source_file.txt"
    expected_source_sha = payload["locked_context"]["source_file_sha256"]
    if not source_file.is_file() or sha256(source_file) != expected_source_sha:
        raise SystemExit("source-witness-hash-mismatch")
    overwrite = os.environ.get("V61HE_OVERWRITE_FINAL_WITNESS", "0") == "1"
    written = []
    for filename, (section, field) in WITNESS_TEXT_MAP.items():
        path = witness_dir / filename
        if path.exists() and not overwrite:
            raise SystemExit(f"witness-exists-set-overwrite:{filename}")
        text = require_text(payload[section][field], f"{section}.{field}")
        path.write_text(text.rstrip() + "\n", encoding="utf-8")
        written.append({"path": str(path), "sha256": sha256(path), "bytes": path.stat().st_size})
    updates = {}
    for env_name, (section, field) in ENV_MAP.items():
        value = payload[field] if section == "" else payload[section][field]
        updates[env_name] = require_text(value, f"{section}.{field}" if section else field)
    replace_exports(env_path, updates)
    manifest = {
        "artifact": "v61he-filled-form-materialization",
        "form": str(form_path),
        "validation_report": str(report_path),
        "written_witness_files": written,
        "updated_env_vars": sorted(updates),
        "executes_dual_replay": 0,
        "accepted_as_real_evidence_by_materializer": 0,
    }
    manifest_path = work_root / "external_return_form" / "MATERIALIZED_FIRST_REAL_SLICE_FROM_FORM_MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"materialized witness/env from {form_path}")
    print(f"manifest: {manifest_path}")

if __name__ == "__main__":
    main()
'''

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
form_dir = work_root / "external_return_form" if work_root else None
form_dir_exists = int(form_dir is not None and form_dir.is_dir())
validator_exists = int(form_dir is not None and (form_dir / "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py").is_file())
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo and form_dir_exists and validator_exists)
published = 0
publish_errors = []
published_rows = []
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
    if not form_dir_exists:
        publish_errors.append("external-return-form-dir-missing")
    if not validator_exists:
        publish_errors.append("form-validator-missing")
elif publish_admitted:
    materializer = form_dir / "MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py"
    readme = form_dir / "MATERIALIZER_README.md"
    materializer.write_text(materializer_text, encoding="utf-8")
    materializer.chmod(0o755)
    readme.write_text(
        "\n".join([
            "# First Real Slice Form Materializer",
            "",
            "This script consumes a filled `FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json`, reruns the form validator, writes final witness files, and replaces the final env placeholders.",
            "It does not build roots, execute dual replay, or count evidence by itself.",
            "",
            "Run only after an external reviewer/operator has filled and finalized the form:",
            "",
            "```bash",
            "external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json",
            "```",
            "",
        ]),
        encoding="utf-8",
    )
    published = 1
    for path in [materializer, readme]:
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "executes_dual_replay": "0",
        })
if not published_rows:
    published_rows.append({"path": "", "bytes": "0", "sha256": "", "metadata_only": "1", "executes_dual_replay": "0"})
write_csv(run_dir / "first_real_slice_form_materializer_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-v61hd-source", "status": "ready", "evidence": "v61hd ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-form-validator", "status": "ready" if validator_exists else "blocked", "evidence": f"validator_exists={validator_exists}"},
    {"stage_id": "04-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "05-materializer-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "06-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', 'unknown')}"},
    {"stage_id": "07-final-replay", "status": "blocked", "evidence": "publisher never executes replay"},
]
write_csv(run_dir / "first_real_slice_form_materializer_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-materialize-filled-form", "ready_to_run_now": str(published), "command": "external_return_form/MATERIALIZE_FIRST_REAL_SLICE_FROM_EXTERNAL_RETURN_FORM_IF_VALID.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "purpose": "write witness/env only after filled form validation"},
    {"command_id": "02-run-precheck-only", "ready_to_run_now": str(published), "command": "RUN_PRECHECK_FIRST_REAL_SLICE_INPUTS_ONLY.sh", "purpose": "confirm materialized witness/env values without replay"},
    {"command_id": "03-run-gap-guarded-final", "ready_to_run_now": str(int(gv.get("workspace_gap_preflight_ready") == "1")), "command": "RUN_GAP_READY_FIRST_REAL_SLICE.sh", "purpose": "execute only after real finalization and gap preflight ready"},
]
write_csv(run_dir / "first_real_slice_form_materializer_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_form_materializer_published_rows.csv"),
    ("FIRST_REAL_SLICE_FORM_MATERIALIZER_STAGE_ROWS.csv", run_dir / "first_real_slice_form_materializer_stage_rows.csv"),
    ("FIRST_REAL_SLICE_FORM_MATERIALIZER_COMMAND_ROWS.csv", run_dir / "first_real_slice_form_materializer_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FORM_MATERIALIZER_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHED_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FORM_MATERIALIZER_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_FORM_MATERIALIZER_COMMAND_ROWS.csv\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER.sh").chmod(0o755)

summary = {
    "v61he_post_hd_first_real_slice_form_materializer_publisher_ready": 1,
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "form_dir_exists": form_dir_exists,
    "form_validator_exists": validator_exists,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "form_materializer_published": published,
    "open_gap_rows": int(gv.get("open_gap_rows", "0") or "0"),
    "workspace_gap_preflight_ready": int(gv.get("workspace_gap_preflight_ready", "0") or "0"),
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
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61he": 0,
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
    {"gate": "source-v61hd-ready", "status": "pass", "evidence": "v61hd ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "form-validator", "status": "pass" if validator_exists else "blocked", "evidence": f"validator_exists={validator_exists}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "form-materializer-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "publisher never executes replay"},
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
    "executes_dual_replay": 0,
    "accepted_as_real_evidence": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_FORM_MATERIALIZER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HE_POST_HD_FIRST_REAL_SLICE_FORM_MATERIALIZER_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HE Post-HD First Real Slice Form Materializer Publisher",
        "",
        "- v61he_post_hd_first_real_slice_form_materializer_publisher_ready=1",
        f"- form_materializer_published={published}",
        f"- open_gap_rows={summary['open_gap_rows']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "Blocked wording: this publishes a filled-form materializer. It does not execute replay or accept evidence by itself.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path), "metadata_only": "1", "payload_like": "0"})
write_csv(run_dir / "first_real_slice_form_materializer_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61he_post_hd_first_real_slice_form_materializer_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
