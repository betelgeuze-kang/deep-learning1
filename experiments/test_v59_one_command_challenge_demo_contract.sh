#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v59_one_command_challenge_demo_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v59_one_command_challenge_demo_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v59_one_command_challenge_demo_contract_decision.csv"

if { [ ! -s "$RESULTS_DIR/v56_ruler_longbench_expanded_contract_summary.csv" ] || [ ! -s "$RESULTS_DIR/v57_domain_expert_packs_contract_summary.csv" ] || [ ! -s "$RESULTS_DIR/v58_blind_eval_contract_summary.csv" ]; } && [ "${V59_REQUIRE_READY_TEST:-0}" != "1" ]; then
  set +e
  output="$("$ROOT_DIR/examples/v1_0_architecture_challenge_demo.sh" 2>&1 >/dev/null)"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "v59 should fail closed when stage artifacts are missing" >&2
    exit 1
  fi
  if ! grep -q "Refusing implicit stage regeneration" <<<"$output"; then
    echo "v59 missing-stage guard did not explain the refusal" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
  echo "v59 one-command missing-stage guard smoke passed"
  exit 0
fi

"$ROOT_DIR/examples/v1_0_architecture_challenge_demo.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v59 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v59_one_command_challenge_demo_contract_ready": "1",
    "v59_ready": "0",
    "stage_contract_rows": "7",
    "contract_ready_stage_rows": "7",
    "full_ready_stage_rows": "0",
    "one_command_entrypoint_ready": "1",
    "challenge_bundle_ready": "1",
    "network_required": "0",
    "external_model_required_for_contract": "0",
    "external_model_rows_deferred_explicitly": "1",
    "stage_artifacts_reused": "1",
    "stage_rebuild_allowed": "0",
    "stage_rebuild_executed": "0",
    "missing_real_30b_70b_rows": "1",
    "missing_public_repo_query_scale": "1",
    "missing_generation_main_rows": "1",
    "missing_scaling_main_rows": "1",
    "missing_expanded_benchmark_rows": "1",
    "missing_domain_expert_pack_rows": "1",
    "missing_blind_eval_rows": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v59 {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v52-v58-contracts", "one-command-entrypoint", "bundle-hash-manifest", "offline-demo-boundary", "stage-rebuild-policy"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v59 gate should pass: {gate}")
for gate in [
    "30b-70b-real-rows",
    "public-repo-query-scale",
    "generation-scaling-benchmark-domain-blind-main-runs",
    "v59-full-one-command-demo",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v59 gate should remain blocked: {gate}")

required_files = [
    "challenge_stage_contract_rows.csv",
    "one_command_demo_rows.csv",
    "one_command_demo_gate_rows.csv",
    "challenge_demo.sh",
    "README_RESULT.md",
    "V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md",
    "v59_one_command_challenge_demo_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v59 artifact: {rel}")
if not (root / "examples" / "v1_0_architecture_challenge_demo.sh").is_file():
    raise SystemExit("v59 repository one-command entrypoint missing")

stage_rows = read_csv(run_dir / "challenge_stage_contract_rows.csv")
if [row["stage"] for row in stage_rows] != ["v52", "v53", "v54", "v55", "v56", "v57", "v58"]:
    raise SystemExit("v59 stage rows should cover v52-v58 in order")
if any(row["contract_ready"] != "1" for row in stage_rows):
    raise SystemExit("v59 all stage contracts should be ready")
if any(row["full_ready"] != "0" for row in stage_rows):
    raise SystemExit("v59 should not mark any v52-v58 full stage ready")

command_rows = read_csv(run_dir / "one_command_demo_rows.csv")
if len(command_rows) != 1:
    raise SystemExit("v59 should write one command row")
command = command_rows[0]
if command["command"] != "./examples/v1_0_architecture_challenge_demo.sh":
    raise SystemExit("v59 one-command entrypoint mismatch")
for field in ["external_model_rows_deferred_explicitly", "claim_boundary_required"]:
    if command[field] != "1":
        raise SystemExit(f"v59 command row should require {field}")
if command["network_required"] != "0" or command["external_model_required"] != "0":
    raise SystemExit("v59 contract demo should not require network/external model credentials")

manifest = json.loads((run_dir / "v59_one_command_challenge_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v59_one_command_challenge_demo_contract_ready") != 1 or manifest.get("v59_ready") != 0:
    raise SystemExit("v59 manifest readiness boundary mismatch")
if manifest.get("full_ready_stage_rows") != 0:
    raise SystemExit("v59 manifest should keep full-ready stage rows at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v59 sha256 mismatch: {rel}")
for stage in ["v52", "v53", "v54", "v55", "v56", "v57", "v58"]:
    if not any(path.startswith(f"source_{stage}/") for path in sha_rows):
        raise SystemExit(f"v59 sha manifest missing source artifacts for {stage}")

boundary = (run_dir / "V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed v1.0 Architecture Challenge demo",
    "one command entrypoint exists",
    "real 30B/70B/100B+ LLM+RAG rows",
    "Do not publish one-command challenge or v1.0 release claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v59 boundary missing {snippet}")

readme = (run_dir / "README_RESULT.md").read_text(encoding="utf-8")
if "./examples/v1_0_architecture_challenge_demo.sh" not in readme:
    raise SystemExit("v59 README should show the one-command invocation")
PY

echo "v59 one-command challenge demo contract smoke passed"
