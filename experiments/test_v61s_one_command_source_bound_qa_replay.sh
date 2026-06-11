#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61s_one_command_source_bound_qa_replay/replay_001"
SUMMARY_CSV="$RESULTS_DIR/v61s_one_command_source_bound_qa_replay_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61s_one_command_source_bound_qa_replay_decision.csv"

V61S_REUSE_EXISTING="${V61S_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61s_one_command_source_bound_qa_replay.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
    "v61s_one_command_source_bound_qa_replay_ready": "1",
    "v61j_one_command_ssd_resident_demo_ready": "1",
    "v61n_source_bound_qa_workload_ready": "1",
    "entrypoint": "./examples/v61_ssd_resident_moe_demo.sh",
    "entrypoint_mode": "--source-bound-qa",
    "one_command_exit_code": "0",
    "one_command_source_bound_qa_pass": "1",
    "source_bound_query_rows": "37",
    "source_bound_query_pass_rows": "37",
    "source_bound_citation_rows": "37",
    "source_bound_resource_rows": "37",
    "source_bound_abstain_rows": "10",
    "abstain_policy_pass_rows": "10",
    "runtime_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "complete_source_1000_query_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61s {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "one_command_replay_rows.csv",
    "source_bound_workload_pass_rows.csv",
    "runtime_gap_rows.csv",
    "one_command_stdout.txt",
    "one_command_stderr.txt",
    "one_command_entrypoint.sh",
    "V61S_ONE_COMMAND_SOURCE_BOUND_QA_REPLAY_BOUNDARY.md",
    "v61s_one_command_source_bound_qa_replay_manifest.json",
    "sha256_manifest.csv",
    "source_v61n/v61n_source_bound_qa_workload_summary.csv",
    "source_v61n/source_bound_query_rows.csv",
    "source_v61n/source_bound_answer_rows.csv",
    "source_v61n/source_bound_citation_rows.csv",
    "source_v61n/source_bound_abstain_rows.csv",
    "source_v61n/source_bound_resource_rows.csv",
    "source_v61j/runtime_summary.csv",
    "source_v61j/routehint_schedule_trace.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file():
        raise SystemExit(f"missing v61s artifact: {rel}")
    if rel not in {"one_command_stderr.txt"} and path.stat().st_size == 0:
        raise SystemExit(f"empty v61s artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61-one-command-source-bound-qa-entrypoint",
    "v61j-runtime-input",
    "v61n-source-bound-workload-input",
    "source-bound-query-pass",
    "abstain-policy-pass",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61s gate should pass: {gate}")
for gate in [
    "complete-source-1000-query-workload",
    "source-bound-model-generation",
    "full-safetensors-page-hash-binding",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61s gate should remain blocked: {gate}")

replay_rows = read_csv(run_dir / "one_command_replay_rows.csv")
if len(replay_rows) != 1:
    raise SystemExit("v61s expected one command replay row")
replay = replay_rows[0]
if replay["exit_code"] != "0" or replay["one_command_source_bound_qa_pass"] != "1":
    raise SystemExit("v61s command replay did not pass")
if replay["entrypoint_mode"] != "--source-bound-qa":
    raise SystemExit("v61s should exercise the --source-bound-qa entrypoint mode")

pass_rows = read_csv(run_dir / "source_bound_workload_pass_rows.csv")
if len(pass_rows) != 37:
    raise SystemExit("v61s workload pass row count mismatch")
if any(row["source_bound_query_pass"] != "1" for row in pass_rows):
    raise SystemExit("v61s every source-bound query should pass")
if sum(1 for row in pass_rows if row["requires_abstain"] == "1") != 10:
    raise SystemExit("v61s abstain row count mismatch")
if any(row["actual_model_generation_ready"] != "0" for row in pass_rows):
    raise SystemExit("v61s should not claim actual model generation")

manifest = json.loads((run_dir / "v61s_one_command_source_bound_qa_replay_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61s_one_command_source_bound_qa_replay_ready") != 1:
    raise SystemExit("v61s manifest readiness mismatch")
if manifest.get("one_command_source_bound_qa_pass") != 1 or manifest.get("source_bound_query_rows") != 37:
    raise SystemExit("v61s manifest source-bound pass mismatch")
if manifest.get("actual_model_generation_ready") != 0 or manifest.get("full_safetensors_page_hash_binding_ready") != 0:
    raise SystemExit("v61s manifest should keep generation/hash coverage blocked")

boundary = (run_dir / "V61S_ONE_COMMAND_SOURCE_BOUND_QA_REPLAY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61 one-command source-bound QA seed replay",
    "one_command_exit_code=0",
    "source_bound_query_pass_rows=37",
    "one_command_source_bound_qa_pass=1",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61s boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61s sha256 mismatch: {rel}")
PY

echo "v61s one-command source-bound QA replay smoke passed"
