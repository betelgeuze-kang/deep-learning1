#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v59c_one_command_measured_registry_demo/measured_registry_001"
SUMMARY_CSV="$RESULTS_DIR/v59c_one_command_measured_registry_demo_summary.csv"
DECISION_CSV="$RESULTS_DIR/v59c_one_command_measured_registry_demo_decision.csv"

V59C_REUSE_EXISTING="${V59C_REUSE_EXISTING:-1}" "$ROOT_DIR/examples/v1_0_architecture_challenge_measured_registry_demo.sh" >/dev/null

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

STAGE_ORDER = ["v52m", "v53e", "v53f", "v54b", "v55b", "v56b", "v57b", "v58b", "v58c"]
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
    raise SystemExit(f"expected one v59c summary row, got {len(summary_rows)}")
summary = summary_rows[0]
if summary.get("v59c_dependency_blocker_ready") == "1":
    expected_blocked = {
        "v59c_one_command_measured_registry_demo_ready": "0",
        "v59_ready": "0",
        "stage_rows": "9",
        "candidate_ready_stage_rows": "0",
        "full_ready_stage_rows": "0",
        "measured_registry_ready": "0",
        "local_measured_systems": "A/B/C/G/H",
        "query_rows": "0",
        "answer_rows": "0",
        "citation_rows": "0",
        "abstain_rows": "0",
        "wrong_answer_guard_rows": "0",
        "resource_rows": "0",
        "routehint_rows": "0",
        "one_command_measured_registry_entrypoint_ready": "1",
        "measured_registry_bundle_ready": "0",
        "network_required": "0",
        "external_model_required_for_local_registry": "0",
        "real_llm_rows_required_for_full_v1": "1",
        "required_7b14b_baseline_ready": "0",
        "c_strict_exact_label_accuracy": "0.000000",
        "implicit_stage_rebuild_allowed": "0",
        "stage_rebuild_approval_required": "1",
        "network_or_download_approval_required": "1",
        "missing_7b14b_real_rows": "1",
        "missing_real_30b_70b_rows": "1",
        "missing_100b_plus_real_row_or_final_deferral": "1",
        "missing_complete_source_audit": "1",
        "missing_human_domain_review": "1",
        "missing_human_blind_review": "1",
        "real_release_package_ready": "0",
    }
    for field, value in expected_blocked.items():
        if summary.get(field) != value:
            raise SystemExit(f"v59c dependency blocker {field}: expected {value}, got {summary.get(field)}")
    if int(summary.get("missing_dependency_artifact_rows", "0")) <= 0:
        raise SystemExit("v59c dependency blocker should record missing artifacts")

    decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
    for gate in [
        "dependency-blocker-artifact",
        "one-command-measured-registry-entrypoint",
        "measured-registry-bundle-hash-manifest",
        "local-only-claim-boundary-preserved",
    ]:
        if decisions.get(gate) != "pass":
            raise SystemExit(f"v59c dependency blocker gate should pass: {gate}")
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
            raise SystemExit(f"v59c dependency blocker should keep {gate} blocked")

    required_files = [
        "v59c_dependency_blocker_rows.csv",
        "README_RESULT.md",
        "V59C_ONE_COMMAND_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md",
        "v59c_one_command_measured_registry_demo_manifest.json",
        "sha256_manifest.csv",
    ]
    for rel in required_files:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v59c dependency blocker artifact: {rel}")
    blocker_rows = read_csv(run_dir / "v59c_dependency_blocker_rows.csv")
    if len(blocker_rows) != int(summary["missing_dependency_artifact_rows"]):
        raise SystemExit("v59c dependency blocker row count mismatch")
    for row in blocker_rows:
        if row["implicit_rebuild_allowed"] != "0" or row["approval_required"] != "1":
            raise SystemExit("v59c dependency blocker should refuse implicit rebuild and require approval")
        if row["network_or_download_risk"] != "1" or row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0":
            raise SystemExit("v59c dependency blocker claim boundary mismatch")
    manifest = json.loads((run_dir / "v59c_one_command_measured_registry_demo_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("v59c_one_command_measured_registry_demo_ready") != 0 or manifest.get("v59c_dependency_blocker_ready") != 1:
        raise SystemExit("v59c dependency blocker manifest readiness mismatch")
    sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
    for rel in required_files:
        if rel == "sha256_manifest.csv":
            continue
        if sha_rows.get(rel) != sha256(run_dir / rel):
            raise SystemExit(f"v59c dependency blocker sha256 mismatch: {rel}")
    boundary = (run_dir / "V59C_ONE_COMMAND_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
    for snippet in [
        "missing_dependency_artifact_rows=",
        "implicit_stage_rebuild_allowed=0",
        "stage_rebuild_approval_required=1",
        "Blocked wording: v59c measured registry demo ready",
    ]:
        if snippet not in boundary:
            raise SystemExit(f"v59c dependency blocker boundary missing {snippet}")
    sys.exit(0)

expected = {
    "v59c_one_command_measured_registry_demo_ready": "1",
    "v59_ready": "0",
    "stage_rows": "9",
    "candidate_ready_stage_rows": "9",
    "full_ready_stage_rows": "3",
    "measured_registry_ready": "1",
    "local_measured_systems": "A/B/C/G/H",
    "query_rows": "1000",
    "answer_rows": "5000",
    "citation_rows": "5000",
    "abstain_rows": "5000",
    "wrong_answer_guard_rows": "5000",
    "resource_rows": "5000",
    "routehint_rows": "2000",
    "one_command_measured_registry_entrypoint_ready": "1",
    "measured_registry_bundle_ready": "1",
    "network_required": "0",
    "external_model_required_for_local_registry": "0",
    "real_llm_rows_required_for_full_v1": "1",
    "required_7b14b_baseline_ready": "1",
    "c_strict_exact_label_accuracy": "0.000000",
    "missing_7b14b_real_rows": "0",
    "missing_real_30b_70b_rows": "1",
    "missing_100b_plus_real_row_or_final_deferral": "1",
    "missing_complete_source_audit": "1",
    "missing_human_domain_review": "1",
    "missing_human_blind_review": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v59c {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "measured-registry-replay",
    "same-query-source-local-systems",
    "one-command-measured-registry-entrypoint",
    "measured-registry-bundle-hash-manifest",
    "local-only-claim-boundary-preserved",
    "7b14b-real-rows",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v59c gate should pass: {gate}")
for gate in [
    "30b-70b-real-rows",
    "100b-plus-real-row",
    "complete-source-audit",
    "human-domain-and-blind-review",
    "v59-full-one-command-demo",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v59c gate should remain blocked: {gate}")

required_files = [
    "measured_registry_stage_replay_rows.csv",
    "measured_registry_one_command_rows.csv",
    "measured_registry_demo_gate_rows.csv",
    "measured_registry_demo.sh",
    "README_RESULT.md",
    "V59C_ONE_COMMAND_MEASURED_REGISTRY_BOUNDARY.md",
    "v59c_one_command_measured_registry_demo_manifest.json",
    "sha256_manifest.csv",
    "source_v52m/measured_baseline_registry.csv",
    "source_v52m/measured_artifact_absorb_rows.csv",
    "source_v52m/source_v52i/abgh_answer_rows.csv",
    "source_v52m/source_v52i/abgh_citation_rows.csv",
    "source_v52m/source_v52i/abgh_abstain_rows.csv",
    "source_v52m/source_v52i/abgh_wrong_answer_guard_rows.csv",
    "source_v52m/source_v52i/abgh_resource_rows.csv",
    "source_v52m/source_v52i/routehint_rows.csv",
    "source_v52m/source_v52l/c_answer_rows.csv",
    "source_v52m/source_v52l/c_citation_rows.csv",
    "source_v52m/source_v52l/ollama_generation_transcript_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v59c artifact: {rel}")
if not (root / "examples" / "v1_0_architecture_challenge_measured_registry_demo.sh").is_file():
    raise SystemExit("v59c repository one-command measured-registry entrypoint missing")

stage_rows = read_csv(run_dir / "measured_registry_stage_replay_rows.csv")
if [row["stage"] for row in stage_rows] != STAGE_ORDER:
    raise SystemExit("v59c stage rows should cover v52m and v53e-v58c in order")
if any(row["candidate_ready"] != "1" for row in stage_rows):
    raise SystemExit("v59c all measured-registry/candidate stages should be ready")
for row in stage_rows:
    expected_full_ready = "1" if row["stage"] in FULL_READY_ALLOWED else "0"
    if row["full_ready"] != expected_full_ready:
        raise SystemExit(f"v59c full-ready boundary mismatch for {row['stage']}: {row['full_ready']}")
    if int(row["copied_artifacts"]) < 5:
        raise SystemExit(f"v59c should copy enough artifacts for {row['stage']}")

registry = read_csv(run_dir / "source_v52m" / "measured_baseline_registry.csv")
by_id = {row["system_id"]: row for row in registry}
for system_id in ["A", "B", "C", "G", "H"]:
    row = by_id[system_id]
    if row["measured_baseline_ready"] != "1" or row["query_set_id"] != "v53e_canary_query_scale_1000_full":
        raise SystemExit(f"v59c should preserve measured v52m registry for {system_id}")
if by_id["C"]["adapter_status"] != "measured-local-v52l":
    raise SystemExit("v59c should preserve v52l C adapter status")
for system_id in ["D", "E"]:
    if by_id[system_id]["measured_baseline_ready"] != "0":
        raise SystemExit(f"v59c should not promote missing {system_id} evidence")

command_rows = read_csv(run_dir / "measured_registry_one_command_rows.csv")
if len(command_rows) != 1:
    raise SystemExit("v59c should write one measured-registry command row")
command = command_rows[0]
if command["command"] != "./examples/v1_0_architecture_challenge_measured_registry_demo.sh":
    raise SystemExit("v59c one-command measured-registry entrypoint mismatch")
if command["real_llm_rows_required_for_full_v1"] != "1" or command["claim_boundary_required"] != "1":
    raise SystemExit("v59c command should preserve real-row and claim-boundary requirements")
if command["network_required"] != "0" or command["external_model_required_for_local_registry"] != "0":
    raise SystemExit("v59c local measured-registry demo should not require network/external model credentials")

manifest = json.loads((run_dir / "v59c_one_command_measured_registry_demo_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v59c_one_command_measured_registry_demo_ready") != 1 or manifest.get("v59_ready") != 0:
    raise SystemExit("v59c manifest readiness mismatch")
if manifest.get("stage_order") != STAGE_ORDER:
    raise SystemExit("v59c manifest stage order mismatch")
if manifest.get("candidate_ready_stage_rows") != 9 or manifest.get("full_ready_stage_rows") != 3:
    raise SystemExit("v59c manifest stage count mismatch")
if manifest.get("local_measured_systems") != ["A", "B", "C", "G", "H"]:
    raise SystemExit("v59c manifest local systems mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v59c sha256 mismatch: {rel}")
for stage in STAGE_ORDER:
    if not any(path.startswith(f"source_{stage}/") for path in sha_rows):
        raise SystemExit(f"v59c sha manifest missing source artifacts for {stage}")

boundary = (run_dir / "V59C_ONE_COMMAND_MEASURED_REGISTRY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "one-command replay of the v52m local measured registry",
    "not the completed v1.0 Architecture Challenge demo",
    "local_measured_systems=A/B/C/G/H",
    "answer_rows=5000",
    "required_7b14b_baseline_ready=1",
    "real_30b_70b_rows_ready=0",
    "Do not publish 30B-150B comparison wins",
]:
    if snippet not in boundary:
        raise SystemExit(f"v59c boundary missing {snippet}")

readme = (run_dir / "README_RESULT.md").read_text(encoding="utf-8")
if "./examples/v1_0_architecture_challenge_measured_registry_demo.sh" not in readme:
    raise SystemExit("v59c README should show the one-command measured-registry invocation")
PY

echo "v59c one-command measured registry demo smoke passed"
