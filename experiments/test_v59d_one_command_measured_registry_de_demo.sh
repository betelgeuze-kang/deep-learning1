#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v59d_one_command_measured_registry_de_demo/measured_registry_de_001"
SUMMARY_CSV="$RESULTS_DIR/v59d_one_command_measured_registry_de_demo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v59d_one_command_measured_registry_de_demo_decision.csv"

V59D_REUSE_EXISTING="${V59D_REUSE_EXISTING:-1}" "$ROOT_DIR/examples/v1_0_architecture_challenge_measured_registry_de_demo.sh" >/dev/null

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

STAGE_ORDER = ["v52r", "v53e", "v53f", "v54b", "v55b", "v56b", "v57b", "v58b", "v58c"]
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


summary = read_csv(summary_csv)[0]
if summary.get("v59d_dependency_blocker_ready") == "1":
    expected_blocked = {
        "v59d_one_command_measured_registry_de_demo_ready": "0",
        "v59_ready": "0",
        "stage_rows": "9",
        "candidate_ready_stage_rows": "0",
        "full_ready_stage_rows": "0",
        "measured_registry_ready": "0",
        "local_measured_systems": "A/B/C/D/E/G/H",
        "query_rows": "0",
        "answer_rows": "0",
        "citation_rows": "0",
        "abstain_rows": "0",
        "wrong_answer_guard_rows": "0",
        "resource_rows": "0",
        "routehint_rows": "0",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "implicit_stage_rebuild_allowed": "0",
        "stage_rebuild_approval_required": "1",
        "network_or_download_approval_required": "1",
        "missing_real_30b_70b_rows": "1",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v59d dependency blocker {field}: expected {value}, got {summary.get(field)}")
    if int(summary.get("missing_dependency_artifact_rows", "0")) <= 0:
        raise SystemExit("v59d dependency blocker should record missing artifacts")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    for gate in [
        "dependency-blocker-artifact",
        "one-command-measured-registry-entrypoint",
        "measured-registry-bundle-hash-manifest",
        "local-only-claim-boundary-preserved",
    ]:
        if decisions.get(gate) != "pass":
            raise SystemExit(f"v59d dependency blocker gate should pass: {gate}")
    for gate in [
        "measured-registry-replay",
        "same-query-source-local-systems",
        "7b14b-real-rows",
        "30b-70b-real-rows",
        "100b-plus-real-row",
        "complete-source-audit",
        "human-domain-and-blind-review",
        "v59-full-one-command-demo",
        "real-release-package",
    ]:
        if decisions.get(gate) != "blocked":
            raise SystemExit(f"v59d dependency blocker should keep {gate} blocked")

    required_files = [
        "v59d_dependency_blocker_rows.csv",
        "README_RESULT.md",
        "V59D_ONE_COMMAND_MEASURED_REGISTRY_DE_DEPENDENCY_BLOCKER.md",
        "v59d_one_command_measured_registry_de_demo_manifest.json",
        "sha256_manifest.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v59d dependency blocker artifact: {rel}")
    blocker_rows = read_csv(run_dir / "v59d_dependency_blocker_rows.csv")
    if len(blocker_rows) != int(summary["missing_dependency_artifact_rows"]):
        raise SystemExit("v59d dependency blocker row count mismatch")
    for row in blocker_rows:
        if row["implicit_rebuild_allowed"] != "0" or row["approval_required"] != "1":
            raise SystemExit("v59d dependency blocker should refuse implicit rebuild and require approval")
        if row["network_or_download_risk"] != "1" or row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
            raise SystemExit("v59d dependency blocker claim boundary mismatch")
    manifest = json.loads((run_dir / "v59d_one_command_measured_registry_de_demo_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v59d_one_command_measured_registry_de_demo_ready") != 0 or manifest.get("v59d_dependency_blocker_ready") != 1:
        raise SystemExit("v59d dependency blocker manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v59d dependency blocker sha256 mismatch: {rel}")
    boundary = (run_dir / "V59D_ONE_COMMAND_MEASURED_REGISTRY_DE_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
    for snippet in [
        "missing_dependency_artifact_rows=",
        "implicit_stage_rebuild_allowed=0",
        "stage_rebuild_approval_required=1",
        "Blocked wording: v59d D/E registry demo ready",
    ]:
        if snippet not in boundary:
            raise SystemExit(f"v59d dependency blocker boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v59d_one_command_measured_registry_de_demo_ready": "1",
    "v59_ready": "0",
    "stage_rows": "9",
    "candidate_ready_stage_rows": "9",
    "full_ready_stage_rows": "3",
    "measured_registry_ready": "1",
    "local_measured_systems": "A/B/C/D/E/G/H",
    "query_rows": "1000",
    "answer_rows": "7000",
    "citation_rows": "7000",
    "abstain_rows": "7000",
    "wrong_answer_guard_rows": "7000",
    "resource_rows": "7000",
    "routehint_rows": "2000",
    "required_30b_baseline_ready": "1",
    "required_70b_baseline_ready": "1",
    "missing_real_30b_70b_rows": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v59d {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "measured-registry-replay",
    "same-query-source-local-systems",
    "one-command-measured-registry-entrypoint",
    "30b-70b-real-rows",
    "7b14b-real-rows",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v59d gate should pass: {gate}")
for gate in ["v59-full-one-command-demo", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v59d gate should remain blocked: {gate}")

registry = read_csv(run_dir / "source_v52r" / "measured_baseline_registry.csv")
by_id = {row["system_id"]: row for row in registry}
for system_id in ["A", "B", "C", "D", "E", "G", "H"]:
    row = by_id[system_id]
    if row["measured_baseline_ready"] != "1":
        raise SystemExit(f"v59d should promote measured {system_id}")
if by_id["D"]["adapter_status"] != "measured-local-v52p":
    raise SystemExit("v59d should preserve v52p D adapter status")
if by_id["E"]["adapter_status"] != "measured-local-v52q":
    raise SystemExit("v59d should preserve v52q E adapter status")

stage_rows = read_csv(run_dir / "measured_registry_stage_replay_rows.csv")
if [row["stage"] for row in stage_rows] != STAGE_ORDER:
    raise SystemExit("v59d stage rows should start with v52r")

manifest = json.loads((run_dir / "v59d_one_command_measured_registry_de_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("local_measured_systems") != ["A", "B", "C", "D", "E", "G", "H"]:
    raise SystemExit("v59d manifest local systems mismatch")

boundary = (run_dir / "V59D_ONE_COMMAND_MEASURED_REGISTRY_DE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in ["local_measured_systems=A/B/C/D/E/G/H", "real_30b_70b_rows_ready=1", "answer_rows=7000"]:
    if snippet not in boundary:
        raise SystemExit(f"v59d boundary missing {snippet}")
PY

echo "v59d one-command measured registry D/E demo smoke passed"
