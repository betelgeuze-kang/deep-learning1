#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52y_f_optional_final_policy/policy_001"
SUMMARY_CSV="$RESULTS_DIR/v52y_f_optional_final_policy_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52y_f_optional_final_policy_decision.csv"

"$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("v52y_dependency_blocker_ready") == "1":
    expected_blocker = {
        "v52y_f_optional_final_policy_ready": "0",
        "v52y_dependency_blocker_ready": "1",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "v52_ready": "0",
        "comparison_30b_150b_wording_status": "blocked",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocker.items():
        if summary.get(field) != value:
            raise SystemExit(f"v52y dependency blocker {field}: expected {value}, got {summary.get(field)}")
    for rel in [
        "v52y_dependency_blocker_rows.csv",
        "V52Y_F_OPTIONAL_FINAL_POLICY_DEPENDENCY_BLOCKER.md",
        "v52y_f_optional_final_policy_manifest.json",
        "sha256_manifest.csv",
    ]:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v52y dependency blocker artifact: {rel}")
    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    if decisions.get("dependency-blocker-artifact") != "pass":
        raise SystemExit("v52y dependency blocker artifact gate should pass")
    for gate in ["required-d-e-measured", "v52-ready", "30b-150b-wording", "real-release-package"]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v52y dependency blocker gate should remain blocked: {gate}")
    boundary = (run_dir / "V52Y_F_OPTIONAL_FINAL_POLICY_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
    for snippet in ["v52y_dependency_blocker_ready=1", "required_30b_baseline_ready=0", "v52_ready=0"]:
        if snippet not in boundary:
            raise SystemExit(f"v52y dependency blocker boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v52y_f_optional_final_policy_ready": "1",
    "f_optional_final_disposition_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "optional_100b_plus_baseline_status": "deferred-with-reason",
    "optional_100b_plus_baseline_ready": "0",
    "f_final_deferred_with_reason": "1",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "required_measured_systems": "A/B/C/D/E/G/H",
    "required_measured_system_rows": "7",
    "same_query_set_local_systems": "1",
    "same_source_manifest_local_systems": "1",
    "v52_ready_condition_rows": "8",
    "v52_ready_condition_pass_rows": "6",
    "v52_ready": "0",
    "v52_ready_scope": "measured-baseline-registry-with-f-final-disposition",
    "comparison_30b_150b_wording_status": "blocked",
    "complete_source_v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52y {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "f_optional_final_rows.csv",
    "v52_ready_condition_rows.csv",
    "comparison_wording_rows.csv",
    "V52Y_F_OPTIONAL_FINAL_POLICY_BOUNDARY.md",
    "v52y_f_optional_final_policy_manifest.json",
    "sha256_manifest.csv",
    "source_v52r/v52r_measured_registry_de_absorb_summary.csv",
    "source_v52r/measured_baseline_registry.csv",
    "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv",
    "source_v52e/hosted_llm_rag_validation_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v52y artifact: {rel}")

f_rows = read_csv(run_dir / "f_optional_final_rows.csv")
if len(f_rows) != 1:
    raise SystemExit("v52y should emit one F final row")
f_row = f_rows[0]
if f_row["system_id"] != "F" or f_row["can_replace_required_d_e"] != "0":
    raise SystemExit("v52y F final row should preserve optional-only semantics")
if f_row["counts_as_measured_100b_plus_result"] != "0":
    raise SystemExit("v52y default F final row should not count as measured 100B+")

conditions = read_csv(run_dir / "v52_ready_condition_rows.csv")
if len(conditions) != 8:
    raise SystemExit("v52y should emit eight v52_ready condition rows")
condition_status = {row["condition"]: row["status"] for row in conditions}
for condition in ["required_30b_d_ready", "required_70b_e_ready"]:
    if condition_status.get(condition) != "blocked":
        raise SystemExit(f"v52y should keep {condition} blocked")
for condition in [
    "v52r_registry_absorbed",
    "required_a_b_c_d_e_g_h_measured",
    "same_query_set_local_systems",
    "f_optional_final_disposition_ready",
    "f_cannot_replace_required_d_e",
    "v52_baseline_registry_ready_scope_declared",
]:
    if condition_status.get(condition) != "pass":
        raise SystemExit(f"v52y should pass {condition}")

claims = {row["claim"]: row["status"] for row in read_csv(run_dir / "comparison_wording_rows.csv")}
if claims.get("30B-150B-class comparison surface") != "blocked":
    raise SystemExit("v52y should block 30B-150B wording until D/E release readiness")
if claims.get("measured 100B+/150B hosted baseline result") != "blocked":
    raise SystemExit("v52y should block measured 100B+/150B result wording")
if claims.get("RouteMemory beats 30B-150B-class systems") != "blocked":
    raise SystemExit("v52y should block superiority wording")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["f-optional-final-disposition"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52y gate should pass: {gate}")
for gate in [
    "required-d-e-measured",
    "v52-ready",
    "30b-150b-wording",
    "f-measured-100b-plus-result",
    "v53-complete-source-audit",
    "v1-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v52y gate should remain blocked: {gate}")

manifest = json.loads((run_dir / "v52y_f_optional_final_policy_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v52_ready") != 0 or manifest.get("complete_source_v53_ready") != 0:
    raise SystemExit("v52y manifest should keep v52 and v53 complete-source blocked")

boundary = (run_dir / "V52Y_F_OPTIONAL_FINAL_POLICY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "F remains optional-preferred",
    "f_optional_final_disposition=deferred-with-reason-final",
    "v52_ready=0",
    "Do not claim a measured 100B+/150B baseline result",
]:
    if snippet not in boundary:
        raise SystemExit(f"v52y boundary missing {snippet}")
PY

echo "v52y F optional final policy smoke passed"
