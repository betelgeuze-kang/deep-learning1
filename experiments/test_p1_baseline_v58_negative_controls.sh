#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p1-baseline-v58-negative.XXXXXX")"
PM_RUN_DIR="$ROOT_DIR/results/v1_0_pm_pr_claim_slice_gate/gate_001"
DE_REGISTRY_LEDGER="$PM_RUN_DIR/de_measured_registry_exclusion_rows.csv"
DE_ACCEPTANCE_LEDGER="$PM_RUN_DIR/de_30b70b_acceptance_evidence_rows.csv"
V58_READY_LEDGER="$PM_RUN_DIR/v58_real_execution_readiness_rows.csv"
V58_ARTIFACT_LEDGER="$ROOT_DIR/results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_required_artifact_rows.csv"
V58_TEMPLATE_LEDGER="$ROOT_DIR/results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_return_template_rows.csv"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ ! -s "$DE_REGISTRY_LEDGER" ] || [ ! -s "$DE_ACCEPTANCE_LEDGER" ] || [ ! -s "$V58_READY_LEDGER" ]; then
  "$ROOT_DIR/experiments/test_v1_0_pm_pr_claim_slice_gate.sh" >/dev/null
fi
if [ ! -s "$V58_ARTIFACT_LEDGER" ] || [ ! -s "$V58_TEMPLATE_LEDGER" ]; then
  "$ROOT_DIR/experiments/test_v59e_one_command_pm_foundation_demo.sh" >/dev/null
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

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_policy_bad.json"
python3 - "$TMP_DIR/de_policy_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["fixture_rows_in_measured_registry"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "fixture_rows_in_measured_registry must be false" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_policy_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_system_ready_bad.json"
python3 - "$TMP_DIR/de_system_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["systems"][0]["measured_registry_admission_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "measured_registry_admission_ready must be false until real evidence is supplied" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_system_ready_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_public_systems_bad.json"
python3 - "$TMP_DIR/de_public_systems_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["public_comparison_requires_all_systems"].remove("H")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "public_comparison_requires_all_systems must be A/B/C/D/E/G/H" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_public_systems_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_system_env_bad.json"
python3 - "$TMP_DIR/de_system_env_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["systems"][1]["evidence_env"] = "V52D_30B_LLM_RAG_EVIDENCE_DIR"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "system[E]: evidence_env must be V52D_70B_LLM_RAG_EVIDENCE_DIR" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_system_env_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_acceptance_command_bad.json"
python3 - "$TMP_DIR/de_acceptance_command_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["systems"][0]["acceptance_test"] = "./experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "acceptance_test must pin both D/E evidence envs and the v52d evidence intake" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_acceptance_command_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_required_evidence_bad.json"
python3 - "$TMP_DIR/de_required_evidence_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["required_real_evidence_fields"].remove("model_artifact_hash")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_real_evidence_fields must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_required_evidence_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_artifact_columns_bad.json"
python3 - "$TMP_DIR/de_artifact_columns_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "model-identity":
        row["required_columns"].remove("model_revision")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_artifact_columns_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_raw_output_prompt_column_bad.json"
python3 - "$TMP_DIR/de_raw_output_prompt_column_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "answer-citation-raw-output":
        row["required_columns"].remove("prompt_template_sha256")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_raw_output_prompt_column_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_raw_output_budget_seed_bad.json"
python3 - "$TMP_DIR/de_raw_output_budget_seed_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "answer-citation-raw-output":
        for column in ["context_budget", "retrieval_budget", "seed"]:
            row["required_columns"].remove(column)
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_raw_output_budget_seed_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$ROOT_DIR/baselines/de_30b70b_real.json" "$TMP_DIR/de_resource_evaluator_column_bad.json"
python3 - "$TMP_DIR/de_resource_evaluator_column_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "resource-evaluator-manifest":
        row["required_columns"].remove("evaluator_version")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$TMP_DIR/de_resource_evaluator_column_bad.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$DE_REGISTRY_LEDGER" "$TMP_DIR/de_registry_bad.csv"
python3 - "$TMP_DIR/de_registry_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["fixture_rows_in_measured_registry"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "fixture_rows_in_measured_registry must be 0" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$ROOT_DIR/baselines/de_30b70b_real.json" \
  --measured-registry-ledger "$TMP_DIR/de_registry_bad.csv" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$DE_REGISTRY_LEDGER" "$TMP_DIR/de_registry_missing_fields_bad.csv"
python3 - "$TMP_DIR/de_registry_missing_fields_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["missing_real_evidence_fields"] = rows[0]["missing_real_evidence_fields"].replace(";evaluator_version", "")
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "missing_real_evidence_fields must list every required field while blocked" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$ROOT_DIR/baselines/de_30b70b_real.json" \
  --measured-registry-ledger "$TMP_DIR/de_registry_missing_fields_bad.csv" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$DE_REGISTRY_LEDGER" "$TMP_DIR/de_registry_same_query_bad.csv"
python3 - "$TMP_DIR/de_registry_same_query_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["same_query_set_required"] = "0"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "resource/evaluator/same-query requirements must be 1" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$ROOT_DIR/baselines/de_30b70b_real.json" \
  --measured-registry-ledger "$TMP_DIR/de_registry_same_query_bad.csv" \
  --acceptance-ledger "$DE_ACCEPTANCE_LEDGER"

cp "$DE_ACCEPTANCE_LEDGER" "$TMP_DIR/de_acceptance_artifact_present_bad.csv"
python3 - "$TMP_DIR/de_acceptance_artifact_present_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["artifact_present"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "artifact_present must be 0" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$ROOT_DIR/baselines/de_30b70b_real.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$TMP_DIR/de_acceptance_artifact_present_bad.csv"

cp "$DE_ACCEPTANCE_LEDGER" "$TMP_DIR/de_acceptance_ready_bad.csv"
python3 - "$TMP_DIR/de_acceptance_ready_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["acceptance_ready"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "must remain blocked" \
  "$ROOT_DIR/tools/verify_artifact.py" baseline-admission "$ROOT_DIR/baselines/de_30b70b_real.json" \
  --measured-registry-ledger "$DE_REGISTRY_LEDGER" \
  --acceptance-ledger "$TMP_DIR/de_acceptance_ready_bad.csv"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_fixture_bad.json"
python3 - "$TMP_DIR/v58_fixture_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["fixture_allowed"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.fixture_allowed must be false" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_fixture_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_real_ready_bad.json"
python3 - "$TMP_DIR/v58_real_ready_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["real_execution_ready"] = True
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.real_execution_ready must be false until real blind evidence is supplied" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_real_ready_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_reviewer_count_bad.json"
python3 - "$TMP_DIR/v58_reviewer_count_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["required_independent_reviewers_per_response"] = 1
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.required_independent_reviewers_per_response must be 2" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_reviewer_count_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_blind_identity_bad.json"
python3 - "$TMP_DIR/v58_blind_identity_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["blind_identity_required_until_adjudication"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.blind_identity_required_until_adjudication must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_blind_identity_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_response_identity_leakage_bad.json"
python3 - "$TMP_DIR/v58_response_identity_leakage_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["response_text_identity_leakage_forbidden"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.response_text_identity_leakage_forbidden must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_response_identity_leakage_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_adjudication_required_bad.json"
python3 - "$TMP_DIR/v58_adjudication_required_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["adjudication_required_for_disagreement"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.adjudication_required_for_disagreement must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_adjudication_required_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_required_systems_bad.json"
python3 - "$TMP_DIR/v58_required_systems_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["required_systems"].remove("H")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_systems must be A/B/C/D/E/G/H" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_required_systems_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_unseen_split_policy_bad.json"
python3 - "$TMP_DIR/v58_unseen_split_policy_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["unseen_repository_split_required"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.unseen_repository_split_required must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_unseen_split_policy_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_source_span_score_policy_bad.json"
python3 - "$TMP_DIR/v58_source_span_score_policy_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["source_span_exactness_separate_score"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.source_span_exactness_separate_score must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_source_span_score_policy_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_unsupported_abstention_policy_bad.json"
python3 - "$TMP_DIR/v58_unsupported_abstention_policy_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["unsupported_abstention_separate_score"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.unsupported_abstention_separate_score must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_unsupported_abstention_policy_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_latency_memory_policy_bad.json"
python3 - "$TMP_DIR/v58_latency_memory_policy_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["policy"]["latency_memory_quality_separated"] = False
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "policy.latency_memory_quality_separated must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_latency_memory_policy_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_same_budget_columns_bad.json"
python3 - "$TMP_DIR/v58_same_budget_columns_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-run-identity-rows":
        row["required_columns"].remove("context_budget")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_same_budget_columns_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_unseen_split_column_bad.json"
python3 - "$TMP_DIR/v58_unseen_split_column_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-query-split-rows":
        row["required_columns"].remove("unseen_repository")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_unseen_split_column_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_review_score_columns_bad.json"
python3 - "$TMP_DIR/v58_review_score_columns_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-human-review-rows":
        row["required_columns"].remove("source_span_exactness")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_review_score_columns_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_latency_memory_column_bad.json"
python3 - "$TMP_DIR/v58_latency_memory_column_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-blind-response-rows":
        row["required_columns"].remove("latency_memory_excluded_from_quality_score")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_latency_memory_column_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_response_query_binding_column_bad.json"
python3 - "$TMP_DIR/v58_response_query_binding_column_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-blind-response-rows":
        row["required_columns"].remove("query_id")
        row["required_columns"].remove("frozen_query_packet_sha256")
        row["required_columns"].remove("source_manifest_sha256")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_response_query_binding_column_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_resource_budget_binding_column_bad.json"
python3 - "$TMP_DIR/v58_resource_budget_binding_column_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-resource-rows":
        row["required_columns"].remove("context_budget")
        row["required_columns"].remove("retrieval_budget")
        row["required_columns"].remove("frozen_query_packet_sha256")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "required_columns must be exactly" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_resource_budget_binding_column_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_review_identity_bad.json"
python3 - "$TMP_DIR/v58_review_identity_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-human-review-rows":
        row["required_columns"].append("source_system_id")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "human review/adjudication rows must not reveal system identity columns: source_system_id" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_review_identity_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_review_resource_bad.json"
python3 - "$TMP_DIR/v58_review_resource_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-human-review-rows":
        row["required_columns"].append("latency_ns")
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "human review/adjudication rows must not include resource columns: latency_ns" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_review_resource_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_adjudication_min_rows_bad.json"
python3 - "$TMP_DIR/v58_adjudication_min_rows_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-adjudication-rows":
        row["min_rows"] = 0
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "min_rows must be a positive integer" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_adjudication_min_rows_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$ROOT_DIR/v58/blind_eval_real.json" "$TMP_DIR/v58_per_system_bad.json"
python3 - "$TMP_DIR/v58_per_system_bad.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "v58-blind-response-rows":
        row["per_system_min_rows"]["D"] = 0
        break
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
expect_fail_with \
  "per_system_min_rows must require 500 rows for each A/B/C/D/E/G/H system" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$TMP_DIR/v58_per_system_bad.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$V58_READY_LEDGER" "$TMP_DIR/v58_ready_ledger_bad.csv"
python3 - "$TMP_DIR/v58_ready_ledger_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["real_execution_ready"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "real_execution_ready must be 0 while blocked" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$ROOT_DIR/v58/blind_eval_real.json" \
  --readiness-ledger "$TMP_DIR/v58_ready_ledger_bad.csv" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$V58_ARTIFACT_LEDGER" "$TMP_DIR/v58_artifact_ledger_approval_bad.csv"
python3 - "$TMP_DIR/v58_artifact_ledger_approval_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["artifact_id"] == "v58-human-review-rows":
        row["approval_required"] = "0"
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "v58-human-review-rows.fixture_allowed must be 0 and approval_required must be 1" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$ROOT_DIR/v58/blind_eval_real.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$TMP_DIR/v58_artifact_ledger_approval_bad.csv" \
  --template-ledger "$V58_TEMPLATE_LEDGER"

cp "$V58_TEMPLATE_LEDGER" "$TMP_DIR/v58_template_ready_bad.csv"
python3 - "$TMP_DIR/v58_template_ready_bad.csv" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
for row in rows:
    if row["artifact_id"] == "v58-adjudication-rows":
        row["template_ready"] = "0"
        break
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "v58-adjudication-rows.template_ready must be 1" \
  "$ROOT_DIR/tools/verify_artifact.py" v58-blind-eval "$ROOT_DIR/v58/blind_eval_real.json" \
  --readiness-ledger "$V58_READY_LEDGER" \
  --artifact-ledger "$V58_ARTIFACT_LEDGER" \
  --template-ledger "$TMP_DIR/v58_template_ready_bad.csv"

echo "p1 baseline/v58 negative controls passed"
