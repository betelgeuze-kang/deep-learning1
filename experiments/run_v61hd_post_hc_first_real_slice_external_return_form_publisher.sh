#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hd_post_hc_first_real_slice_external_return_form_publisher"
RUN_ID="${V61HD_RUN_ID:-external_return_form_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WORK_ROOT="${V61HD_WORK_ROOT:-${V61GU_WORK_ROOT:-}}"
PUBLISH_FORM="${V61HD_PUBLISH_FORM:-0}"
GV_RUN_ID="${V61HD_V61GV_RUN_ID:-${RUN_ID}_gap_audit}"

if [[ "${V61HD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hd_post_hc_first_real_slice_external_return_form_publisher_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61hc_post_hb_first_real_slice_precheck_runner_publisher.sh" >/dev/null
V61GI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gi_post_gh_authority_bound_operator_input_scaffold.sh" >/dev/null
V61GV_RUN_ID="$GV_RUN_ID" \
V61GV_WORK_ROOT="$WORK_ROOT" \
V61GV_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$GV_RUN_ID" "$WORK_ROOT" "$PUBLISH_FORM" <<'PY'
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
prefix = "v61hd_post_hc_first_real_slice_external_return_form_publisher"
package_dir = run_dir / "first_real_slice_external_return_form_publisher"
package_dir.mkdir(parents=True, exist_ok=True)
work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None

HC_PREFIX = "v61hc_post_hb_first_real_slice_precheck_runner_publisher"
GI_PREFIX = "v61gi_post_gh_authority_bound_operator_input_scaffold"
GV_PREFIX = "v61gv_post_gu_first_real_slice_workspace_gap_audit"
gi_scaffold = results / GI_PREFIX / "scaffold_001" / "authority_bound_operator_input_scaffold"
worksheet_path = gi_scaffold / "MINIMAL_SLICE_REVIEW_WORKSHEET.json"


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
    "v61hc_summary": results / f"{HC_PREFIX}_summary.csv",
    "v61hc_decision": results / f"{HC_PREFIX}_decision.csv",
    "v61gi_summary": results / f"{GI_PREFIX}_summary.csv",
    "v61gi_worksheet": worksheet_path,
    "v61gv_summary": results / f"{GV_PREFIX}_summary.csv",
    "v61gv_missing_items": gv_run_dir / "first_real_slice_workspace_missing_item_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hd source {label}: {path}")

source_rows = []
for label, path in source_paths.items():
    if label.startswith("v61hc"):
        folder = "source_v61hc"
    elif label.startswith("v61gi"):
        folder = "source_v61gi"
    else:
        folder = "source_v61gv"
    source_rows.append(copy_source(label, path, folder))
write_csv(run_dir / "first_real_slice_external_return_form_source_rows.csv", list(source_rows[0].keys()), source_rows)

hc = read_csv(source_paths["v61hc_summary"])[0]
gi = read_csv(source_paths["v61gi_summary"])[0]
gv = read_csv(source_paths["v61gv_summary"])[0]
if hc.get("v61hc_post_hb_first_real_slice_precheck_runner_publisher_ready") != "1":
    raise SystemExit("v61hd requires v61hc ready")
if gi.get("v61gi_post_gh_authority_bound_operator_input_scaffold_ready") != "1":
    raise SystemExit("v61hd requires v61gi ready")
if gv.get("v61gv_post_gu_first_real_slice_workspace_gap_audit_ready") != "1":
    raise SystemExit("v61hd requires v61gv ready")

worksheet = json.loads(worksheet_path.read_text(encoding="utf-8"))
query = worksheet["selected_query_row"]
answer = worksheet["selected_answer_row"]
citation = worksheet["selected_citation_row"]
span = worksheet["selected_source_span_row"]
source_hash = span["source_file_sha256"]

form_template = {
    "form_protocol_version": "v61hd-first-real-slice-external-return-form-v1",
    "source_class": "REPLACE_WITH_real-external-review-and-generation-return",
    "finalized": False,
    "selected_slice_ids": {
        "v53": "v53-partial-review-slice",
        "v61": "v61-partial-generation-slice",
    },
    "locked_context": {
        "query_id": query["query_id"],
        "question": query["question"],
        "expected_behavior": query["expected_behavior"],
        "source_span_id": span["source_span_id"],
        "source_path": span["path"],
        "source_line_start": span["line_start"],
        "source_line_end": span["line_end"],
        "source_file_sha256": source_hash,
        "evidence_text": span["evidence_text"],
        "review_answer_packet_id": answer["answer_id"],
        "review_system_id": answer["system_id"],
        "review_answer_text": answer["answer_text"],
        "review_citation_id": citation["citation_id"],
    },
    "v53_review_return": {
        "reviewer_id": "REPLACE_WITH_FINAL_REVIEWER_ID",
        "review_decision": "accept",
        "source_support_verified": 1,
        "citation_verified": 1,
        "policy_verified": 1,
        "review_comment_text": "REPLACE_WITH_FINAL_REVIEW_COMMENT_TEXT",
        "adjudicator_id": "REPLACE_WITH_FINAL_ADJUDICATOR_ID",
        "adjudication_decision": "accept",
        "adjudication_reason_text": "REPLACE_WITH_FINAL_ADJUDICATION_REASON_TEXT",
        "credential_statement_text": "REPLACE_WITH_FINAL_CREDENTIAL_STATEMENT_TEXT",
        "conflict_declared": 0,
        "conflict_statement_text": "REPLACE_WITH_FINAL_CONFLICT_STATEMENT_TEXT",
        "reviewer_authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_REVIEWER_AUTHORITY_STATEMENT",
    },
    "v61_generation_return": {
        "generation_id": "REPLACE_WITH_FINAL_GENERATION_ID",
        "citation_id": "REPLACE_WITH_FINAL_CITATION_ID",
        "model_id": "mistralai/Mixtral-8x22B-v0.1",
        "checkpoint_root": "REPLACE_WITH_FINAL_CHECKPOINT_ROOT",
        "answer_text": "REPLACE_WITH_FINAL_GENERATION_ANSWER_TEXT",
        "run_transcript_text": "REPLACE_WITH_FINAL_RUN_TRANSCRIPT_TEXT",
        "generation_status": "completed",
        "abstain_decision": "answer",
        "fallback_used": 0,
        "latency_row_id": "REPLACE_WITH_FINAL_LATENCY_ROW_ID",
        "prompt_tokens": "REPLACE_WITH_FINAL_PROMPT_TOKENS",
        "output_tokens": "REPLACE_WITH_FINAL_OUTPUT_TOKENS",
        "prefill_ms": "REPLACE_WITH_FINAL_PREFILL_MS",
        "decode_ms": "REPLACE_WITH_FINAL_DECODE_MS",
        "total_ms": "REPLACE_WITH_FINAL_TOTAL_MS",
        "tokens_per_second": "REPLACE_WITH_FINAL_TOKENS_PER_SECOND",
        "source_file_sha256": source_hash,
        "generation_operator_authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_GENERATION_OPERATOR_AUTHORITY_STATEMENT",
    },
    "external_return_attestation": "REPLACE_WITH_FINAL_EXTERNAL_RETURN_ATTESTATION",
    "operator_input_assembly_authority_statement": "REPLACE_WITH_FINAL_OPERATOR_ASSEMBLY_AUTHORITY_STATEMENT",
}

validator_text = r'''#!/usr/bin/env python3
import csv
import json
import re
import sys
from pathlib import Path

NONFINAL = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]
ALLOWED_SOURCE_CLASS = "real-external-review-and-generation-return"
PROTOCOL = "v61hd-first-real-slice-external-return-form-v1"
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
LOCKED_SOURCE_SHA = "''' + source_hash + r'''"

def has_nonfinal(value):
    return any(token in str(value).lower() for token in NONFINAL)

def positive(value):
    try:
        return float(value) > 0
    except (TypeError, ValueError):
        return False

def add(rows, check_id, status, evidence):
    rows.append({"check_id": check_id, "status": status, "evidence": evidence})

def text_ready(value, min_len=20):
    if not isinstance(value, str) or len(value.strip()) < min_len:
        return False, "too-short"
    if has_nonfinal(value):
        return False, "nonfinal-text"
    return True, "supplied"

def main():
    form_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json")
    report_path = Path(sys.argv[2]) if len(sys.argv) > 2 else form_path.with_suffix(".validation_rows.csv")
    rows = []
    try:
        payload = json.loads(form_path.read_text(encoding="utf-8"))
    except Exception as exc:
        add(rows, "form-json", "blocked", f"json-unreadable:{exc}")
        payload = {}
    if isinstance(payload, dict):
        add(rows, "form-json", "pass", "json-readable")
    else:
        add(rows, "form-json", "blocked", "json-not-object")
        payload = {}

    add(rows, "protocol", "pass" if payload.get("form_protocol_version") == PROTOCOL else "blocked", str(payload.get("form_protocol_version", "")))
    add(rows, "source-class", "pass" if payload.get("source_class") == ALLOWED_SOURCE_CLASS else "blocked", str(payload.get("source_class", "")))
    add(rows, "finalized", "pass" if payload.get("finalized") is True else "blocked", str(payload.get("finalized", "")))
    selected = payload.get("selected_slice_ids", {})
    add(rows, "selected-v53-slice", "pass" if isinstance(selected, dict) and selected.get("v53") == "v53-partial-review-slice" else "blocked", str(selected))
    add(rows, "selected-v61-slice", "pass" if isinstance(selected, dict) and selected.get("v61") == "v61-partial-generation-slice" else "blocked", str(selected))
    locked = payload.get("locked_context", {})
    add(rows, "locked-source-sha", "pass" if isinstance(locked, dict) and locked.get("source_file_sha256") == LOCKED_SOURCE_SHA else "blocked", str(locked.get("source_file_sha256", "")) if isinstance(locked, dict) else "")

    review = payload.get("v53_review_return", {})
    generation = payload.get("v61_generation_return", {})
    if not isinstance(review, dict):
        review = {}
        add(rows, "v53-review-object", "blocked", "missing-or-not-object")
    else:
        add(rows, "v53-review-object", "pass", "object")
    if not isinstance(generation, dict):
        generation = {}
        add(rows, "v61-generation-object", "blocked", "missing-or-not-object")
    else:
        add(rows, "v61-generation-object", "pass", "object")

    for field in ["reviewer_id", "adjudicator_id"]:
        ok, evidence = text_ready(review.get(field, ""), 3)
        add(rows, f"v53:{field}", "pass" if ok else "blocked", evidence)
    for field in ["review_comment_text", "adjudication_reason_text", "credential_statement_text", "conflict_statement_text", "reviewer_authority_statement"]:
        ok, evidence = text_ready(review.get(field, ""), 40)
        add(rows, f"v53:{field}", "pass" if ok else "blocked", evidence)
    for field in ["source_support_verified", "citation_verified", "policy_verified"]:
        add(rows, f"v53:{field}", "pass" if review.get(field) == 1 else "blocked", str(review.get(field, "")))

    for field in ["generation_id", "citation_id", "latency_row_id"]:
        ok, evidence = text_ready(generation.get(field, ""), 3)
        add(rows, f"v61:{field}", "pass" if ok else "blocked", evidence)
    model_id = generation.get("model_id", "")
    add(rows, "v61:model_id", "pass" if model_id == "mistralai/Mixtral-8x22B-v0.1" and not has_nonfinal(model_id) else "blocked", str(model_id))
    checkpoint_root = generation.get("checkpoint_root", "")
    checkpoint_text_ready, checkpoint_evidence = text_ready(checkpoint_root, 3)
    if checkpoint_text_ready:
        checkpoint_path = Path(checkpoint_root).expanduser()
        shard_rows = len(list(checkpoint_path.glob("model-*-of-00059.safetensors"))) if checkpoint_path.is_dir() else 0
        add(rows, "v61:checkpoint_root", "pass" if checkpoint_path.is_dir() and shard_rows == 59 else "blocked", f"exists={checkpoint_path.is_dir()}; safetensors={shard_rows}")
    else:
        add(rows, "v61:checkpoint_root", "blocked", checkpoint_evidence)
    for field in ["answer_text", "run_transcript_text", "generation_operator_authority_statement"]:
        ok, evidence = text_ready(generation.get(field, ""), 40)
        add(rows, f"v61:{field}", "pass" if ok else "blocked", evidence)
    for field in ["prompt_tokens", "output_tokens", "prefill_ms", "decode_ms", "total_ms", "tokens_per_second"]:
        add(rows, f"v61:{field}", "pass" if positive(generation.get(field)) else "blocked", str(generation.get(field, "")))
    source_sha = generation.get("source_file_sha256", "")
    add(rows, "v61:source_file_sha256", "pass" if source_sha == LOCKED_SOURCE_SHA and SHA_RE.match(source_sha) else "blocked", str(source_sha))

    for field in ["external_return_attestation", "operator_input_assembly_authority_statement"]:
        ok, evidence = text_ready(payload.get(field, ""), 40)
        add(rows, field, "pass" if ok else "blocked", evidence)

    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["check_id", "status", "evidence"], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    blocked = [row for row in rows if row["status"] != "pass"]
    if blocked:
        print(f"external-return-form-blocked:{len(blocked)} checks; report={report_path}", file=sys.stderr)
        raise SystemExit(2)
    print(f"external-return-form-ready; report={report_path}")

if __name__ == "__main__":
    main()
'''

work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
publish_admitted = int(publish_requested and work_root_exists and work_root_outside_repo)
published = 0
published_rows = []
publish_errors = []
form_dir = work_root / "external_return_form" if work_root else None
if publish_requested and not publish_admitted:
    if not work_root_exists:
        publish_errors.append("work-root-missing")
    if not work_root_outside_repo:
        publish_errors.append("work-root-inside-repo-or-missing")
elif publish_admitted:
    form_dir.mkdir(parents=True, exist_ok=True)
    files = {
        "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template": json.dumps(form_template, indent=2, sort_keys=True) + "\n",
        "VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py": validator_text,
        "EXTERNAL_RETURN_FORM_README.md": "\n".join([
            "# First Real Slice External Return Form",
            "",
            "Copy `FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template` to `FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json` outside the repo and replace every `REPLACE_WITH_*` value with final external review/generation content.",
            "Run `./VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json` before using the guarded first-slice runner.",
            "",
            "This form is not evidence until filled by an external reviewer/operator and validated as final. The validator does not build roots or execute replay.",
            "",
        ]),
    }
    for name, text in files.items():
        path = form_dir / name
        path.write_text(text, encoding="utf-8")
        if name.endswith(".py"):
            path.chmod(0o755)
        published_rows.append({
            "path": str(path),
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "counts_as_evidence": "0",
        })
    published = 1

if not published_rows:
    published_rows.append({
        "path": "",
        "bytes": "0",
        "sha256": "",
        "metadata_only": "1",
        "counts_as_evidence": "0",
    })
write_csv(run_dir / "first_real_slice_external_return_form_published_rows.csv", list(published_rows[0].keys()), published_rows)

stage_rows = [
    {"stage_id": "01-v61hc-source", "status": "ready", "evidence": "v61hc ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-publish-request", "status": "ready" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"stage_id": "04-form-published", "status": "ready" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"stage_id": "05-workspace-gap-preflight", "status": "ready" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}; open_gap_rows={gv.get('open_gap_rows', 'unknown')}"},
    {"stage_id": "06-form-validation", "status": "blocked", "evidence": "template is not a filled external return"},
    {"stage_id": "07-final-replay", "status": "blocked", "evidence": "form publisher never executes replay"},
]
write_csv(run_dir / "first_real_slice_external_return_form_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-copy-fill-form", "ready_to_run_now": str(published), "command": "cp external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json.template external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "purpose": "create the one-file external return form to fill outside the repo"},
    {"command_id": "02-validate-form", "ready_to_run_now": str(published), "command": "external_return_form/VALIDATE_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.py external_return_form/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "purpose": "validate form finality before materialization or replay"},
]
write_csv(run_dir / "first_real_slice_external_return_form_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHED_ROWS.csv", run_dir / "first_real_slice_external_return_form_published_rows.csv"),
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_STAGE_ROWS.csv", run_dir / "first_real_slice_external_return_form_stage_rows.csv"),
    ("FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_COMMAND_ROWS.csv", run_dir / "first_real_slice_external_return_form_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHED_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_COMMAND_ROWS.csv\"",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER.sh").chmod(0o755)

summary = {
    "v61hd_post_hc_first_real_slice_external_return_form_publisher_ready": 1,
    "v61hc_post_hb_first_real_slice_precheck_runner_publisher_ready": 1,
    "v61gi_post_gh_authority_bound_operator_input_scaffold_ready": 1,
    "v61gv_post_gu_first_real_slice_workspace_gap_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "publish_requested": publish_requested,
    "publish_admitted": publish_admitted,
    "external_return_form_published": published,
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
    "checkpoint_payload_bytes_downloaded_by_v61hd": 0,
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
    {"gate": "source-v61hc-ready", "status": "pass", "evidence": "v61hc ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "publish-request", "status": "pass" if publish_requested else "blocked", "evidence": f"publish_requested={publish_requested}"},
    {"gate": "external-return-form-published", "status": "pass" if published else "blocked", "evidence": f"published={published}; errors={';'.join(publish_errors)}"},
    {"gate": "workspace-gap-preflight", "status": "pass" if gv.get("workspace_gap_preflight_ready") == "1" else "blocked", "evidence": f"workspace_gap_preflight_ready={gv.get('workspace_gap_preflight_ready', '0')}"},
    {"gate": "real-return-execution", "status": "blocked", "evidence": "form publisher never executes replay"},
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
    "form_protocol_version": form_template["form_protocol_version"],
    "accepted_as_real_evidence": 0,
    "executes_dual_replay": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HD_POST_HC_FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM_PUBLISHER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HD Post-HC First Real Slice External Return Form Publisher",
        "",
        "- v61hd_post_hc_first_real_slice_external_return_form_publisher_ready=1",
        f"- external_return_form_published={published}",
        f"- open_gap_rows={summary['open_gap_rows']}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "",
        "Blocked wording: this publishes a one-file external return form and validator. It does not create evidence, materialize roots, or execute replay.",
        "",
    ]),
    encoding="utf-8",
)

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
write_csv(run_dir / "first_real_slice_external_return_form_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hd_post_hc_first_real_slice_external_return_form_publisher_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
