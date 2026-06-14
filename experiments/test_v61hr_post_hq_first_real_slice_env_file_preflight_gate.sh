#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hr_post_hq_first_real_slice_env_file_preflight_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/env_file_preflight_gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_file_preflight_gate"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hr first real slice workspace"

V61HR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hr_post_hq_first_real_slice_env_file_preflight_gate.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


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
    "v61hr_post_hq_first_real_slice_env_file_preflight_gate_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "preflight_gate_published": "0",
    "env_file_exists": "0",
    "env_file_preflight_ready": "0",
    "form_values_supplied": "0",
    "filled_form_exists": "0",
    "authority_ack_exists": "0",
    "next_real_subset_action": "initialize-or-select-first-real-slice-workspace",
    "row_acceptance_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"v61hr default {key}: expected {value}, got {summary.get(key)}")
required = [
    "first_real_slice_env_file_preflight_published_rows.csv",
    "first_real_slice_values_env_file_preflight_rows.csv",
    "first_real_slice_env_file_preflight_gate/FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE_MANIFEST.json",
    "first_real_slice_env_file_preflight_gate/VERIFY_FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE.sh",
    "V61HR_POST_HQ_FIRST_REAL_SLICE_ENV_FILE_PREFLIGHT_GATE_BOUNDARY.md",
    "v61hr_post_hq_first_real_slice_env_file_preflight_gate_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61hr artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61hr sha256 mismatch: {rel}")
print("v61hr default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
cat > "$TMP_WORK_ROOT/external_return_form/FIRST_REAL_SLICE_VALUES.env.template" <<'EOF'
export V61HO_EXTERNAL_RETURN_ATTESTATION=REPLACE_WITH_REAL_EXTERNAL_RETURN_ATTESTATION
export V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT=REPLACE_WITH_REAL_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT
export V61HO_REVIEWER_ID=REPLACE_WITH_REAL_REVIEWER_ID
export V61HO_ADJUDICATOR_ID=REPLACE_WITH_REAL_ADJUDICATOR_ID
export V61HO_REVIEW_COMMENT_TEXT=REPLACE_WITH_REAL_REVIEW_COMMENT_TEXT
export V61HO_ADJUDICATION_REASON_TEXT=REPLACE_WITH_REAL_ADJUDICATION_REASON_TEXT
export V61HO_CREDENTIAL_STATEMENT_TEXT=REPLACE_WITH_REAL_CREDENTIAL_STATEMENT_TEXT
export V61HO_CONFLICT_STATEMENT_TEXT=REPLACE_WITH_REAL_CONFLICT_STATEMENT_TEXT
export V61HO_REVIEWER_AUTHORITY_STATEMENT=REPLACE_WITH_REAL_REVIEWER_AUTHORITY_STATEMENT
export V61HO_GENERATION_ID=REPLACE_WITH_REAL_GENERATION_ID
export V61HO_CITATION_ID=REPLACE_WITH_REAL_CITATION_ID
export V61HO_LATENCY_ROW_ID=REPLACE_WITH_REAL_LATENCY_ROW_ID
export V61HO_CHECKPOINT_ROOT=REPLACE_WITH_REAL_CHECKPOINT_ROOT
export V61HO_ANSWER_TEXT=REPLACE_WITH_REAL_ANSWER_TEXT
export V61HO_RUN_TRANSCRIPT_TEXT=REPLACE_WITH_REAL_RUN_TRANSCRIPT_TEXT
export V61HO_PROMPT_TOKENS=REPLACE_WITH_REAL_PROMPT_TOKENS
export V61HO_OUTPUT_TOKENS=REPLACE_WITH_REAL_OUTPUT_TOKENS
export V61HO_PREFILL_MS=REPLACE_WITH_REAL_PREFILL_MS
export V61HO_DECODE_MS=REPLACE_WITH_REAL_DECODE_MS
export V61HO_TOTAL_MS=REPLACE_WITH_REAL_TOTAL_MS
export V61HO_TOKENS_PER_SECOND=REPLACE_WITH_REAL_TOKENS_PER_SECOND
export V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT=REPLACE_WITH_REAL_GENERATION_OPERATOR_AUTHORITY_STATEMENT
export V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT=REPLACE_WITH_REAL_DUAL_REPLAY_AUTHORITY_STATEMENT
export V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN=false
EOF

V61HR_RUN_ID="publish_only" \
V61HR_WORK_ROOT="$TMP_WORK_ROOT" \
V61HR_PUBLISH_PREFLIGHT=1 \
V61HR_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hr_post_hq_first_real_slice_env_file_preflight_gate.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$TMP_WORK_ROOT" <<'PY'
import csv
import os
import subprocess
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
work_root = Path(sys.argv[2])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    row = next(csv.DictReader(handle))
expected = {
    "work_root_supplied": "1",
    "work_root_exists": "1",
    "work_root_outside_repo": "1",
    "publish_requested": "1",
    "preflight_gate_published": "1",
    "env_file_exists": "0",
    "env_template_exists": "1",
    "env_file_preflight_ready": "0",
    "next_real_subset_action": "fill-first-real-slice-values-env-file",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hr publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
for name in [
    "VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py",
    "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh",
    "FIRST_REAL_SLICE_VALUES_ENV_FILE_PREFLIGHT_README.md",
]:
    path = form_dir / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing preflight file: {name}")
for name in ["VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py", "RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh"]:
    path = form_dir / name
    if not os.access(path, os.X_OK):
        raise SystemExit(f"preflight executable bit missing: {name}")
    check = subprocess.run(["python3", "-m", "py_compile", str(path)] if name.endswith(".py") else ["bash", "-n", str(path)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check.returncode != 0:
        raise SystemExit(f"preflight syntax failed for {name}: {check.stderr}")
print("v61hr publish-only smoke passed")
PY

FORM_DIR="$TMP_WORK_ROOT/external_return_form"
cp "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.template" "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env"
if "$FORM_DIR/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh" >/tmp/v61hr_placeholder.out 2>/tmp/v61hr_placeholder.err; then
  echo "preflight accepted placeholder env file" >&2
  exit 1
fi
CHECKPOINT_ROOT="$TMP_WORK_ROOT/checkpoint_root"
mkdir -p "$CHECKPOINT_ROOT"
python3 - "$CHECKPOINT_ROOT" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for idx in range(1, 60):
    (root / f"model-{idx:05d}-of-00059.safetensors").write_text("not a real checkpoint shard\n", encoding="utf-8")
PY
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env" <<EOF
export V61HO_EXTERNAL_RETURN_ATTESTATION="Operator attests this closed test return is a real reviewed value set."
export V61HO_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT="Operator authorizes assembly of this checked one row return into inputs."
export V61HO_REVIEWER_ID="reviewer-alpha"
export V61HO_ADJUDICATOR_ID="adjudicator-alpha"
export V61HO_REVIEW_COMMENT_TEXT="Reviewer confirms the cited source row supports the first slice answer."
export V61HO_ADJUDICATION_REASON_TEXT="Adjudicator accepts the first slice because source and policy checks passed."
export V61HO_CREDENTIAL_STATEMENT_TEXT="Reviewer identity is authorized for this controlled local return path."
export V61HO_CONFLICT_STATEMENT_TEXT="Reviewer declares no conflict for this controlled local return path."
export V61HO_REVIEWER_AUTHORITY_STATEMENT="Reviewer authority is final for this one row controlled local return."
export V61HO_GENERATION_ID="generation-alpha"
export V61HO_CITATION_ID="citation-alpha"
export V61HO_LATENCY_ROW_ID="latency-alpha"
export V61HO_CHECKPOINT_ROOT="$CHECKPOINT_ROOT"
export V61HO_ANSWER_TEXT="The first slice answer is source bound and cites the selected local file."
export V61HO_RUN_TRANSCRIPT_TEXT="Run transcript records the controlled first slice generation return path."
export V61HO_PROMPT_TOKENS="128"
export V61HO_OUTPUT_TOKENS="64"
export V61HO_PREFILL_MS="12.5"
export V61HO_DECODE_MS="25.5"
export V61HO_TOTAL_MS="38.0"
export V61HO_TOKENS_PER_SECOND="1.68"
export V61HO_GENERATION_OPERATOR_AUTHORITY_STATEMENT="Generation operator authorizes this controlled first slice value return."
export V61HO_DUAL_REPLAY_AUTHORITY_STATEMENT="This final external replay authority statement is long enough for the controlled local test path."
export V61HO_OPERATOR_ATTESTS_REAL_EXTERNAL_RETURN="true"
EOF
"$FORM_DIR/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.sh" >/tmp/v61hr_good_preflight.out

python3 - "$FORM_DIR" <<'PY'
import csv
import sys
from pathlib import Path
form_dir = Path(sys.argv[1])
report = form_dir / "FIRST_REAL_SLICE_VALUES.env.preflight_rows.csv"
if not report.is_file():
    raise SystemExit("missing preflight report")
with report.open(newline="", encoding="utf-8") as handle:
    blocked = [row for row in csv.DictReader(handle) if row["status"] != "pass"]
if blocked:
    raise SystemExit(f"preflight has blocked rows: {blocked}")
for forbidden in ["FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json", "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "DUAL_REPLAY_AUTHORITY_ACK.json"]:
    if (form_dir / forbidden).exists():
        raise SystemExit(f"preflight wrote forbidden artifact: {forbidden}")
print("v61hr env preflight pass smoke passed")
PY

V61HR_RUN_ID="preflight_good" \
V61HR_WORK_ROOT="$TMP_WORK_ROOT" \
V61HR_PUBLISH_PREFLIGHT=1 \
V61HR_RUN_PREFLIGHT=1 \
V61HR_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hr_post_hq_first_real_slice_env_file_preflight_gate.sh" >/dev/null

python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path
summary_csv = Path(sys.argv[1])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    row = next(csv.DictReader(handle))
if row["env_file_preflight_ready"] != "1":
    raise SystemExit("v61hr summary did not report preflight ready")
if row["form_values_supplied"] != "0" or row["actual_model_generation_ready"] != "0":
    raise SystemExit("v61hr opened forbidden claims")
print("v61hr summary preflight smoke passed")
PY

echo "v61hr first real slice env-file preflight gate smoke passed"
