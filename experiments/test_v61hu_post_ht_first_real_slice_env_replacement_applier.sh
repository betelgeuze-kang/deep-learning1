#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hu_post_ht_first_real_slice_env_replacement_applier"
RUN_DIR="$RESULTS_DIR/$PREFIX/env_replacement_applier_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_env_replacement_applier"
TMP_WORK_ROOT="${TMPDIR:-/tmp}/v61hu first real slice workspace"

V61HU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61hu_post_ht_first_real_slice_env_replacement_applier.sh" >/dev/null
"$PACKAGE_DIR/VERIFY_FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER.sh" >/dev/null

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
    "v61hu_post_ht_first_real_slice_env_replacement_applier_ready": "1",
    "work_root_supplied": "0",
    "work_root_exists": "0",
    "replacement_applier_published": "0",
    "replacement_template_contains_values": "0",
    "apply_requested": "0",
    "replacement_apply_ready": "0",
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
        raise SystemExit(f"v61hu default {key}: expected {value}, got {summary.get(key)}")
required = [
    "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template",
    "first_real_slice_values_replacement_applier_published_rows.csv",
    "first_real_slice_env_replacement_applier/FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER_MANIFEST.json",
    "first_real_slice_env_replacement_applier/VERIFY_FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER.sh",
    "V61HU_POST_HT_FIRST_REAL_SLICE_ENV_REPLACEMENT_APPLIER_BOUNDARY.md",
    "v61hu_post_ht_first_real_slice_env_replacement_applier_decision.csv",
    "sha256_manifest.csv",
]
sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty v61hu artifact: {rel}")
    if rel != "sha256_manifest.csv" and sha_rows.get(rel) != sha256(path):
        raise SystemExit(f"v61hu sha256 mismatch: {rel}")
print("v61hu default no-workspace smoke passed")
PY

rm -rf "$TMP_WORK_ROOT"
mkdir -p "$TMP_WORK_ROOT/external_return_form"
FORM_DIR="$TMP_WORK_ROOT/external_return_form"
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env" <<'EOF'
export V61HO_REVIEWER_ID=REPLACE_WITH_REAL_REVIEWER_ID
export V61HO_PROMPT_TOKENS=REPLACE_WITH_REAL_PROMPT_TOKENS
EOF
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES_ENV_REPAIR_TODO.csv" <<'EOF'
env_name,field_path,repair_label,current_status,evidence,required_action,safe_to_publish,contains_value
V61HO_REVIEWER_ID,v53_review_return.reviewer_id,reviewer identity,blocked,nonfinal-token,"replace with real reviewer identity, at least 3 chars",1,0
V61HO_PROMPT_TOKENS,v61_generation_return.prompt_tokens,prompt tokens,blocked,nonfinal-token,replace with positive measured prompt token count,1,0
EOF
cat > "$FORM_DIR/VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py" <<'PY'
#!/usr/bin/env python3
import csv
import shlex
import sys
from pathlib import Path
env_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
values = {}
for raw in env_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if line.startswith("export "):
        line = line[len("export "):]
    if "=" in line:
        key, value = line.split("=", 1)
        tokens = shlex.split(value)
        values[key.strip()] = tokens[0] if tokens else ""
rows = []
reviewer = values.get("V61HO_REVIEWER_ID", "")
tokens = values.get("V61HO_PROMPT_TOKENS", "")
rows.append({"env_name": "V61HO_REVIEWER_ID", "field_path": "v53_review_return.reviewer_id", "status": "pass" if len(reviewer) >= 3 and "REPLACE_WITH" not in reviewer else "blocked", "required": "1", "evidence": "ready" if len(reviewer) >= 3 and "REPLACE_WITH" not in reviewer else "nonfinal-token"})
try:
    ok = float(tokens) > 0
except ValueError:
    ok = False
rows.append({"env_name": "V61HO_PROMPT_TOKENS", "field_path": "v61_generation_return.prompt_tokens", "status": "pass" if ok and "REPLACE_WITH" not in tokens else "blocked", "required": "1", "evidence": "ready" if ok and "REPLACE_WITH" not in tokens else "not-positive"})
with report_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["env_name", "field_path", "status", "required", "evidence"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
raise SystemExit(0 if all(row["status"] == "pass" for row in rows) else 2)
PY
chmod +x "$FORM_DIR/VALIDATE_FIRST_REAL_SLICE_VALUES_ENV_FILE.py"

V61HU_RUN_ID="publish_only" \
V61HU_WORK_ROOT="$TMP_WORK_ROOT" \
V61HU_PUBLISH_APPLIER=1 \
V61HU_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61hu_post_ht_first_real_slice_env_replacement_applier.sh" >/dev/null

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
    "replacement_applier_published": "1",
    "replacement_template_rows": "2",
    "replacement_template_contains_values": "0",
    "replacements_file_exists": "0",
    "next_real_subset_action": "fill-first-real-slice-values-replacements-csv",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for key, value in expected.items():
    if row.get(key) != value:
        raise SystemExit(f"v61hu publish-only {key}: expected {value}, got {row.get(key)}")
form_dir = work_root / "external_return_form"
for name in [
    "APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py",
    "RUN_APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh",
    "FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template",
    "FIRST_REAL_SLICE_VALUES_REPLACEMENTS_README.md",
]:
    path = form_dir / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing replacement applier file: {name}")
for name in ["APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.py", "RUN_APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh"]:
    path = form_dir / name
    if not os.access(path, os.X_OK):
        raise SystemExit(f"replacement applier executable bit missing: {name}")
    check = subprocess.run(["python3", "-m", "py_compile", str(path)] if name.endswith(".py") else ["bash", "-n", str(path)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check.returncode != 0:
        raise SystemExit(f"replacement applier syntax failed for {name}: {check.stderr}")
print("v61hu publish-only smoke passed")
PY

cp "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv.template" "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv"
if "$FORM_DIR/RUN_APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh" >/tmp/v61hu_empty_apply.out 2>/tmp/v61hu_empty_apply.err; then
  echo "replacement applier accepted empty replacement values" >&2
  exit 1
fi
cat > "$FORM_DIR/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv" <<'EOF'
env_name,field_path,replacement_value,required_action
V61HO_REVIEWER_ID,v53_review_return.reviewer_id,reviewer-alpha,"replace with real reviewer identity"
V61HO_PROMPT_TOKENS,v61_generation_return.prompt_tokens,128,replace with positive measured prompt token count
EOF
"$FORM_DIR/RUN_APPLY_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh" >/tmp/v61hu_good_apply.out
test -s "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.bak"
test -s "$FORM_DIR/FIRST_REAL_SLICE_VALUES.env.replacement_preflight_rows.csv"

python3 - "$FORM_DIR" <<'PY'
import csv
import sys
from pathlib import Path
form_dir = Path(sys.argv[1])
report = form_dir / "FIRST_REAL_SLICE_VALUES.env.replacement_preflight_rows.csv"
with report.open(newline="", encoding="utf-8") as handle:
    blocked = [row for row in csv.DictReader(handle) if row["status"] != "pass"]
if blocked:
    raise SystemExit(f"replacement preflight blocked: {blocked}")
for forbidden in ["FIRST_REAL_SLICE_EXTERNAL_RETURN_VALUES.json", "FIRST_REAL_SLICE_EXTERNAL_RETURN_FORM.json", "DUAL_REPLAY_AUTHORITY_ACK.json"]:
    if (form_dir / forbidden).exists():
        raise SystemExit(f"replacement applier wrote forbidden artifact: {forbidden}")
print("v61hu transactional replacement apply smoke passed")
PY

echo "v61hu first real slice env replacement applier smoke passed"
