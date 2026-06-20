#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p0-ready-leakage-negative.XXXXXX")"
PM_RUN_DIR="$ROOT_DIR/results/v1_0_pm_pr_claim_slice_gate/gate_001"
PM_READY_LEDGER="$PM_RUN_DIR/pm_ready_semantic_rows.csv"
PM_LEAKAGE_LEDGER="$PM_RUN_DIR/pm_retrieval_leakage_guard_rows.csv"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ ! -s "$PM_READY_LEDGER" ] || [ ! -s "$PM_LEAKAGE_LEDGER" ]; then
  "$ROOT_DIR/experiments/test_v1_0_pm_pr_claim_slice_gate.sh" >/dev/null
fi

expect_fail_with() {
  local expected="$1"
  shift
  local out="$TMP_DIR/expect_fail.out"
  if "$@" >"$out" 2>&1; then
    echo "negative control unexpectedly passed: $*" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$out" >/dev/null; then
    echo "negative control failed for the wrong reason: $*" >&2
    echo "expected diagnostic: $expected" >&2
    echo "actual output:" >&2
    cat "$out" >&2
    exit 1
  fi
}

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_real_model_ready_bad.json"
python3 - "$TMP_DIR/typed_real_model_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["rows"][0]["real_model_execution_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "current contract must not mark real_model_execution_ready=true" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$TMP_DIR/typed_real_model_ready_bad.json" \
  --pm-ledger "$PM_READY_LEDGER"

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_human_review_ready_bad.json"
python3 - "$TMP_DIR/typed_human_review_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["rows"]:
    if row["replacement_flag"] == "operator_review_return_workflow_contract_ready":
        row["human_review_ready"] = True
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "human_review_ready expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$TMP_DIR/typed_human_review_ready_bad.json" \
  --pm-ledger "$PM_READY_LEDGER"

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_heldout_metric_ready_bad.json"
python3 - "$TMP_DIR/typed_heldout_metric_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["rows"]:
    if row["replacement_flag"] == "v58_blind_eval_protocol_contract_ready":
        row["heldout_metric_ready"] = True
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "heldout_metric_ready expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$TMP_DIR/typed_heldout_metric_ready_bad.json" \
  --pm-ledger "$PM_READY_LEDGER"

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_independent_reproduction_ready_bad.json"
python3 - "$TMP_DIR/typed_independent_reproduction_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["rows"]:
    if row["replacement_flag"] == "pr2_docs_claim_boundary_contract_ready":
        row["independent_reproduction_ready"] = True
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "independent_reproduction_ready expected False, got True" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$TMP_DIR/typed_independent_reproduction_ready_bad.json" \
  --pm-ledger "$PM_READY_LEDGER"

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_release_ready_bad.json"
python3 - "$TMP_DIR/typed_release_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["rows"]:
    if row["replacement_flag"] == "v60_release_contract_ready":
        row["release_ready"] = True
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "current contract must not mark release_ready=true" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$TMP_DIR/typed_release_ready_bad.json" \
  --pm-ledger "$PM_READY_LEDGER"

cp "$ROOT_DIR/readiness/typed_ready.json" "$TMP_DIR/typed_real_100b_bad.json"
python3 - "$TMP_DIR/typed_real_100b_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["rows"]:
    if row["replacement_flag"] == "real_100b_inference_ready":
        row["contract_ready"] = True
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "real_100b_inference_ready row must stay all-false until real inference exists" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$TMP_DIR/typed_real_100b_bad.json" \
  --pm-ledger "$PM_READY_LEDGER"

cp "$PM_READY_LEDGER" "$TMP_DIR/typed_ledger_human_review_bad.csv"
python3 - "$TMP_DIR/typed_ledger_human_review_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["replacement_flag"] == "operator_review_return_workflow_contract_ready":
        row["human_review_ready"] = "1"
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "operator_review_return_workflow_contract_ready.human_review_ready expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$ROOT_DIR/readiness/typed_ready.json" \
  --pm-ledger "$TMP_DIR/typed_ledger_human_review_bad.csv"

cp "$PM_READY_LEDGER" "$TMP_DIR/typed_ledger_release_bad.csv"
python3 - "$TMP_DIR/typed_ledger_release_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["replacement_flag"] == "v60_release_contract_ready":
        row["release_ready"] = "1"
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "v60_release_contract_ready.release_ready expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$ROOT_DIR/readiness/typed_ready.json" \
  --pm-ledger "$TMP_DIR/typed_ledger_release_bad.csv"

cp "$ROOT_DIR/leakage/retrieval_model_visible.json" "$TMP_DIR/leakage_policy_bad.json"
python3 - "$TMP_DIR/leakage_policy_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["allowed_model_visible_fields"].append("source_path")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.allowed_model_visible_fields must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$TMP_DIR/leakage_policy_bad.json" \
  --pm-ledger "$PM_LEAKAGE_LEDGER"

cp "$ROOT_DIR/leakage/retrieval_model_visible.json" "$TMP_DIR/leakage_stage_bad.json"
python3 - "$TMP_DIR/leakage_stage_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["stage_contracts"][0]["allowed_model_visible_fields"].append("source_line")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "allowed_model_visible_fields contains forbidden field(s): source_line" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$TMP_DIR/leakage_stage_bad.json" \
  --pm-ledger "$PM_LEAKAGE_LEDGER"

cp "$ROOT_DIR/leakage/retrieval_model_visible.json" "$TMP_DIR/leakage_v54_alias_summary_bad.json"
cp "$ROOT_DIR/results/v54c_complete_source_grounded_generation_1000_summary.csv" "$TMP_DIR/v54_alias_summary_bad.csv"
python3 - "$TMP_DIR/leakage_v54_alias_summary_bad.json" "$TMP_DIR/v54_alias_summary_bad.csv" <<'PY'
import csv
import json
import sys
from pathlib import Path

contract_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
data = json.loads(contract_path.read_text(encoding="utf-8"))
for stage in data["stage_contracts"]:
    if stage["stage_id"] == "v54c-grounded-generation-guard":
        stage["summary_path"] = str(summary_path)
        break
with summary_path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["compact_routehint_forbidden_alias_rows"] = "1"
with summary_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
contract_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "v54c-grounded-generation-guard.compact_routehint_forbidden_alias_rows expected 0, got 1" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$TMP_DIR/leakage_v54_alias_summary_bad.json" \
  --pm-ledger "$PM_LEAKAGE_LEDGER"

cp "$ROOT_DIR/leakage/retrieval_model_visible.json" "$TMP_DIR/leakage_alias_bad.json"
python3 - "$TMP_DIR/leakage_alias_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["forbidden_surfaces"]:
    if row["guard_id"] == "source-file-hash":
        row["field_names"].remove("source_file_hash")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "missing forbidden field coverage: source_file_hash" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$TMP_DIR/leakage_alias_bad.json" \
  --pm-ledger "$PM_LEAKAGE_LEDGER"

cp "$ROOT_DIR/leakage/retrieval_model_visible.json" "$TMP_DIR/leakage_query_alias_bad.json"
python3 - "$TMP_DIR/leakage_query_alias_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["forbidden_surfaces"]:
    if row["guard_id"] == "query-source-direct-binding":
        row["field_names"].remove("query_id")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "missing forbidden field coverage: query_id" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$TMP_DIR/leakage_query_alias_bad.json" \
  --pm-ledger "$PM_LEAKAGE_LEDGER"

cp "$ROOT_DIR/leakage/retrieval_model_visible.json" "$TMP_DIR/leakage_expected_answer_alias_bad.json"
python3 - "$TMP_DIR/leakage_expected_answer_alias_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["forbidden_surfaces"]:
    if row["guard_id"] == "expected-behavior":
        row["field_names"].remove("expected_answer")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "missing forbidden field coverage: expected_answer" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$TMP_DIR/leakage_expected_answer_alias_bad.json" \
  --pm-ledger "$PM_LEAKAGE_LEDGER"

cp "$PM_LEAKAGE_LEDGER" "$TMP_DIR/leakage_ledger_query_bad.csv"
python3 - "$TMP_DIR/leakage_ledger_query_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["guard_id"] == "query-source-direct-binding":
        fields = [field for field in row["field_names"].split(";") if field != "query_id"]
        row["field_names"] = ";".join(fields)
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "query-source-direct-binding.field_names must match contract aliases" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$ROOT_DIR/leakage/retrieval_model_visible.json" \
  --pm-ledger "$TMP_DIR/leakage_ledger_query_bad.csv"

cp "$PM_LEAKAGE_LEDGER" "$TMP_DIR/leakage_ledger_binding_flag_bad.csv"
python3 - "$TMP_DIR/leakage_ledger_binding_flag_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["guard_id"] == "query-source-direct-binding":
        row["direct_query_source_binding_forbidden"] = "0"
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "query-source-direct-binding.direct_query_source_binding_forbidden must be 1" \
  "$ROOT_DIR/tools/verify_artifact.py" leakage "$ROOT_DIR/leakage/retrieval_model_visible.json" \
  --pm-ledger "$TMP_DIR/leakage_ledger_binding_flag_bad.csv"

echo "p0 ready/leakage negative controls passed"
