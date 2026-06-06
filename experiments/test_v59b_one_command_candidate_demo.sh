#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v59b_one_command_candidate_demo/candidate_001"
SUMMARY_CSV="$RESULTS_DIR/v59b_one_command_candidate_demo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v59b_one_command_candidate_demo_decision.csv"

V59B_REUSE_EXISTING="${V59B_REUSE_EXISTING:-1}" "$ROOT_DIR/examples/v1_0_architecture_challenge_candidate_demo.sh" >/dev/null

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

STAGE_ORDER = ["v52b", "v52c", "v52d", "v52e", "v53e", "v53f", "v54b", "v55b", "v56b", "v57b", "v58b", "v58c"]
FULL_READY_ALLOWED = {"v54b", "v55b", "v56b"}


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
    raise SystemExit(f"expected one v59b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v59b_one_command_candidate_demo_ready": "1",
    "v59_ready": "0",
    "candidate_stage_rows": "12",
    "candidate_ready_stage_rows": "12",
    "full_ready_stage_rows": "3",
    "one_command_candidate_entrypoint_ready": "1",
    "candidate_bundle_ready": "1",
    "network_required": "0",
    "external_model_required_for_candidate": "0",
    "real_llm_rows_required_for_full_v1": "1",
    "missing_real_30b_70b_rows": "1",
    "missing_100b_plus_real_row_or_final_deferral": "1",
    "missing_complete_source_audit": "1",
    "missing_human_domain_review": "1",
    "missing_human_blind_review": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v59b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["candidate-chain-replay", "one-command-candidate-entrypoint", "candidate-bundle-hash-manifest", "claim-boundary-preserved"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v59b gate should pass: {gate}")
for gate in [
    "30b-70b-real-rows",
    "100b-plus-real-row",
    "complete-source-audit",
    "human-domain-and-blind-review",
    "v59-full-one-command-demo",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v59b gate should remain blocked: {gate}")

required_files = [
    "candidate_stage_replay_rows.csv",
    "candidate_one_command_rows.csv",
    "candidate_demo_gate_rows.csv",
    "candidate_demo.sh",
    "README_RESULT.md",
    "V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md",
    "v59b_one_command_candidate_demo_manifest.json",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v59b artifact: {rel}")
if not (root / "examples" / "v1_0_architecture_challenge_candidate_demo.sh").is_file():
    raise SystemExit("v59b repository one-command candidate entrypoint missing")

stage_rows = read_csv(run_dir / "candidate_stage_replay_rows.csv")
if [row["stage"] for row in stage_rows] != STAGE_ORDER:
    raise SystemExit("v59b stage rows should cover v52b-v58b in order")
if any(row["candidate_ready"] != "1" for row in stage_rows):
    raise SystemExit("v59b all candidate stages should be ready")
for row in stage_rows:
    expected_full_ready = "1" if row["stage"] in FULL_READY_ALLOWED else "0"
    if row["full_ready"] != expected_full_ready:
        raise SystemExit(f"v59b full-ready boundary mismatch for {row['stage']}: {row['full_ready']}")
    if int(row["copied_artifacts"]) < 5:
        raise SystemExit(f"v59b should copy enough artifacts for {row['stage']}")

command_rows = read_csv(run_dir / "candidate_one_command_rows.csv")
if len(command_rows) != 1:
    raise SystemExit("v59b should write one candidate command row")
command = command_rows[0]
if command["command"] != "./examples/v1_0_architecture_challenge_candidate_demo.sh":
    raise SystemExit("v59b one-command candidate entrypoint mismatch")
if command["real_llm_rows_required_for_full_v1"] != "1" or command["claim_boundary_required"] != "1":
    raise SystemExit("v59b command should preserve real-row and claim-boundary requirements")
if command["network_required"] != "0" or command["external_model_required_for_candidate"] != "0":
    raise SystemExit("v59b candidate demo should not require network/external model credentials")

manifest = json.loads((run_dir / "v59b_one_command_candidate_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v59b_one_command_candidate_demo_ready") != 1 or manifest.get("v59_ready") != 0:
    raise SystemExit("v59b manifest readiness mismatch")
if manifest.get("stage_order") != STAGE_ORDER:
    raise SystemExit("v59b manifest stage order mismatch")
if manifest.get("candidate_ready_stage_rows") != 12 or manifest.get("full_ready_stage_rows") != 3:
    raise SystemExit("v59b manifest stage count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v59b sha256 mismatch: {rel}")
for stage in STAGE_ORDER:
    if not any(path.startswith(f"source_{stage}/") for path in sha_rows):
        raise SystemExit(f"v59b sha manifest missing source artifacts for {stage}")

boundary = (run_dir / "V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "one-command replay of the current candidate/intake chain",
    "not the completed v1.0 Architecture Challenge demo",
    "real_30b_70b_rows_ready=0",
    "Do not publish 30B-150B comparison wins",
]:
    if snippet not in boundary:
        raise SystemExit(f"v59b boundary missing {snippet}")

readme = (run_dir / "README_RESULT.md").read_text(encoding="utf-8")
if "./examples/v1_0_architecture_challenge_candidate_demo.sh" not in readme:
    raise SystemExit("v59b README should show the one-command candidate invocation")
PY

echo "v59b one-command candidate demo smoke passed"
