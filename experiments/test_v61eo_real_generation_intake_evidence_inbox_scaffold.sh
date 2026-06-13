#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eo_real_generation_intake_evidence_inbox_scaffold"
RUN_DIR="$RESULTS_DIR/$PREFIX/scaffold_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61en_real_generation_intake_work_order.sh" >/dev/null

V61EO_REUSE_EXISTING="${V61EO_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61eo_real_generation_intake_evidence_inbox_scaffold.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61eo_real_generation_intake_evidence_inbox_scaffold_ready": "1",
    "v61en_real_generation_intake_work_order_ready": "1",
    "inbox_template_rows": "9",
    "ready_inbox_template_rows": "9",
    "generation_result_template_rows": "5",
    "prerequisite_binding_template_rows": "3",
    "review_return_provenance_template_rows": "1",
    "path_contract_rows": "5",
    "command_rows": "4",
    "ready_command_rows": "0",
    "accepted_by_default_rows": "0",
    "real_generation_result_artifacts": "0",
    "real_prerequisite_binding_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61eo": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61eo {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_generation_intake_inbox_template_rows.csv",
    "real_generation_intake_path_contract_rows.csv",
    "real_generation_intake_inbox_command_rows.csv",
    "RETURN_ENV.template",
    "VERIFY_REAL_GENERATION_INTAKE_INBOX.sh",
    "README.md",
    "v61eo_real_generation_intake_evidence_inbox_scaffold_manifest.json",
    "source/v61en_real_generation_intake_work_order_summary.csv",
    "source/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv",
    "source/REQUIRED_FIELD_ROWS.csv",
    "source/PREREQUISITE_BINDING_CONTRACT.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61eo artifact: {rel}")

template_rows = read_csv(run_dir / "real_generation_intake_inbox_template_rows.csv")
if len(template_rows) != 9:
    raise SystemExit("v61eo expected 9 template rows")
if any(row["accepted_by_default"] != "0" for row in template_rows):
    raise SystemExit("v61eo templates must not be accepted by default")
if any(row["file_ready"] != "1" for row in template_rows):
    raise SystemExit("v61eo template files should all be ready")

for row in template_rows:
    path = run_dir / row["template_artifact"]
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v61eo missing template artifact: {row['template_artifact']}")
    if not path.name.endswith(".template"):
        raise SystemExit(f"v61eo template artifact must end with .template: {path}")

final_forbidden = {
    "real_model_generation_answer_rows.csv",
    "real_model_generation_citation_rows.csv",
    "real_model_generation_abstain_fallback_rows.csv",
    "real_model_generation_latency_rows.csv",
    "real_model_generation_acceptance_summary.json",
    "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd_review_return_generation_refresh_bridge_summary.csv",
    "REAL_REVIEW_RETURN_PROVENANCE.json",
}
for path in (run_dir / "real_generation_intake_inbox").rglob("*"):
    if path.is_file() and path.name in final_forbidden:
        raise SystemExit(f"v61eo inbox contains final evidence filename: {path.name}")

env_text = (run_dir / "RETURN_ENV.template").read_text(encoding="utf-8")
for snippet in [
    "V61EJ_GENERATION_RESULT_DIR",
    "V61EL_PREREQUISITE_BINDING_DIR",
    "V61EL_BINDING_PROVENANCE=real-review-return",
    "V61EM_GENERATION_PREFLIGHT_RUN_DIR",
    "V61EM_BINDING_PREFLIGHT_RUN_DIR",
]:
    if snippet not in env_text:
        raise SystemExit(f"v61eo env template missing {snippet}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v61en-work-order", "template-inbox-written", "no-default-evidence", "repo-checkpoint-payload"]:
    if decisions[gate] != "pass":
        raise SystemExit(f"v61eo decision should pass: {gate}")
for gate in ["real-generation-intake-handoff", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61eo decision should be blocked: {gate}")

manifest = json.loads((run_dir / "v61eo_real_generation_intake_evidence_inbox_scaffold_manifest.json").read_text(encoding="utf-8"))
if manifest.get("inbox_template_rows") != 9:
    raise SystemExit("v61eo manifest template count mismatch")
if manifest.get("accepted_by_default_rows") != 0:
    raise SystemExit("v61eo manifest must keep accepted_by_default_rows at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61eo manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61eo sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61eo produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61eo real generation intake evidence inbox scaffold smoke passed"
