#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v1_0_pm_pr_claim_slice_gate_decision.csv"

"$ROOT_DIR/experiments/run_v1_0_pm_pr_claim_slice_gate.sh" >/dev/null

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
    "v1_0_pm_pr_claim_slice_gate_ready": "1",
    "recommended_pr_slice_rows": "10",
    "merge_condition_defined_rows": "10",
    "merge_gate_rows": "30",
    "blocker_false_positive_pass_rows": "10",
    "pm_roadmap_requirement_rows": "19",
    "pm_roadmap_ready_rows": "13",
    "pm_roadmap_blocked_rows": "6",
    "pm_foundation_ready": "1",
    "v53_foundation_freeze_certificate_rows": "10",
    "v53_foundation_machine_freeze_ready": "1",
    "pm_pr_slice_file_rows": "39",
    "pm_pr_slice_file_existing_rows": "39",
    "pm_pr_slices_with_file_rows": "10",
    "pm_pr_slice_verification_rows": "16",
    "pm_pr_slices_with_verification_rows": "10",
    "pm_pr_claim_boundary_rows": "10",
    "pm_pr_claim_boundary_pass_rows": "10",
    "pm_pr_review_packet_rows": "10",
    "pm_pr_review_packet_files": "10",
    "pm_pr_review_packet_ready_rows": "10",
    "pm_pr_review_packet_blocked_slice_rows": "1",
    "pm_blocker_closure_queue_rows": "6",
    "pm_blocker_closure_deferred_rows": "6",
    "pm_blocker_closure_approval_required_rows": "6",
    "pm_blocker_closure_packet_rows": "6",
    "pm_blocker_closure_packet_files": "6",
    "pm_blocker_closure_packet_ready_rows": "6",
    "pm_blocker_closure_packet_approval_rows": "6",
    "pm_blocker_required_artifact_rows": "22",
    "pm_blocker_required_artifact_approval_rows": "22",
    "pm_blocker_required_artifact_fixture_allowed_rows": "0",
    "pm_execution_lock_rows": "10",
    "pm_execution_lock_active_rows": "10",
    "pm_scope_drift_allowed": "0",
    "pm_new_scaffold_default_allowed": "0",
    "pm_external_return_template_rows": "22",
    "pm_external_return_template_files": "22",
    "pm_external_return_template_ready_rows": "22",
    "pm_external_return_template_fixture_allowed_rows": "0",
    "pm_external_return_template_approval_rows": "22",
    "draft_pr_2_split_required": "1",
    "tests_only_merge_condition_rows": "0",
    "full_v1_release_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"PM PR slice gate {field}: expected {value}, got {summary.get(field)}")
if int(summary["current_merge_ready_rows"]) < 8:
    raise SystemExit("PM PR slice gate should make most current slices reviewable")
if int(summary["claim_boundary_pass_rows"]) < 9:
    raise SystemExit("PM PR slice gate should keep claim boundaries explicit")

slice_rows = read_csv(run_dir / "pm_pr_slice_rows.csv")
expected_order = [
    "docs/v1-roadmap",
    "v52-baseline-registry-contract",
    "v53-public-repo-source-manifest",
    "v53-query-instantiation-1000",
    "v53-system-a-b-g-h-measured",
    "v54-routehint-generation-contract",
    "v56-ruler-longbench-expanded",
    "v58-blind-eval-contract",
    "v59-one-command-demo",
    "v61-ssd-moe-runtime-roadmap",
]
if [row["slice_id"] for row in slice_rows] != expected_order:
    raise SystemExit("PM PR slice order mismatch")
if any(row["merge_condition_defined"] != "1" for row in slice_rows):
    raise SystemExit("every PM PR slice must define a merge condition")
if any(row["blocker_false_positive_closed"] != "1" for row in slice_rows):
    raise SystemExit("every PM PR slice must close false-positive blockers")
if any(row["merge_condition"].strip().lower() in {"tests pass", "test pass", "tests"} for row in slice_rows):
    raise SystemExit("tests-only merge conditions are forbidden")

claim_boundary_rows = read_csv(run_dir / "pm_pr_claim_boundary_rows.csv")
if len(claim_boundary_rows) != 10:
    raise SystemExit("PM PR claim boundary ledger should have ten rows")
if [row["slice_id"] for row in claim_boundary_rows] != expected_order:
    raise SystemExit("PM PR claim boundary order mismatch")
if any(row["claim_boundary_status"] != "pass" for row in claim_boundary_rows):
    raise SystemExit("every PM PR claim boundary row should pass")
claim_by_id = {row["slice_id"]: row for row in claim_boundary_rows}
for slice_id, forbidden in {
    "docs/v1-roadmap": "Transformer replacement",
    "v53-system-a-b-g-h-measured": "public comparison claim",
    "v56-ruler-longbench-expanded": "leaderboard claim",
    "v59-one-command-demo": "full v59 public challenge demo",
    "v61-ssd-moe-runtime-roadmap": "near-frontier quality",
}.items():
    if forbidden not in claim_by_id[slice_id]["blocked_claim"]:
        raise SystemExit(f"claim boundary should block {forbidden} for {slice_id}")

by_id = {row["slice_id"]: row for row in slice_rows}
if by_id["v53-system-a-b-g-h-measured"]["current_status"] != "ready-for-review":
    raise SystemExit("A/B/G/H slice should be ready for internal pre-baseline review")
if by_id["v59-one-command-demo"]["current_status"] != "pm-foundation-ready-full-demo-blocked":
    raise SystemExit("v59 slice should expose PM foundation readiness while blocking full demo")
if by_id["v61-ssd-moe-runtime-roadmap"]["current_status"] != "ready-for-rd-review":
    raise SystemExit("v61 slice should stay R&D-scoped")

gate_rows = read_csv(run_dir / "pm_pr_merge_gate_rows.csv")
if len(gate_rows) != 30:
    raise SystemExit("expected three gate rows per PR slice")
for slice_id in expected_order:
    gates = {row["gate"]: row["status"] for row in gate_rows if row["slice_id"] == slice_id}
    if set(gates) != {"claim-boundary", "replay-artifact", "blocker-false-positive"}:
        raise SystemExit(f"missing PR merge gates for {slice_id}")
    if gates["blocker-false-positive"] != "pass":
        raise SystemExit(f"false-positive blocker should pass for {slice_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for slice_id in ["docs/v1-roadmap", "v53-query-instantiation-1000", "v53-system-a-b-g-h-measured", "v54-routehint-generation-contract", "v59-one-command-demo"]:
    if decisions.get(slice_id) != "pass":
        raise SystemExit(f"core PM slice should pass current review gate: {slice_id}")

roadmap_rows = read_csv(run_dir / "pm_roadmap_requirement_rows.csv")
if len(roadmap_rows) != 19:
    raise SystemExit("PM roadmap requirement ledger should cover 19 current requirements")
roadmap_by_id = {row["requirement_id"]: row for row in roadmap_rows}
for requirement_id in [
    "pr-split-ledger",
    "merge-condition-boundary",
    "pinned-public-repo-manifest",
    "source-span-query-freeze",
    "negative-and-conflict-controls",
    "answer-citation-separated",
    "abgh-same-query-measured",
    "internal-pre-baseline-boundary",
    "h10-readiness-ledger",
    "v54-grounded-generation-outputs",
    "no-raw-prompt-stuffing",
    "v58-blind-eval-blocker-ledger",
    "v59-one-command-foundation",
]:
    if roadmap_by_id.get(requirement_id, {}).get("status") != "ready":
        raise SystemExit(f"PM roadmap requirement should be ready: {requirement_id}")
expected_blocked = {
    "v56-replay-artifact": "v56-replay-artifact-missing",
    "de-30b70b-symmetric-baselines": "de-30b70b-baselines-missing",
    "h10-real-label-promotion": "external-human-label-evidence-missing",
    "v58c-blind-response-intake-artifact": "v58c-intake-artifact-missing",
    "v58-full-blind-eval": "v58-real-blind-eval-missing",
    "v60-public-release-gate": "v60-release-evidence-missing",
}
for requirement_id, blocker in expected_blocked.items():
    row = roadmap_by_id.get(requirement_id)
    if row is None:
        raise SystemExit(f"missing PM roadmap blocker row: {requirement_id}")
    if row["status"] != "blocked" or row["blocker_class"] != blocker:
        raise SystemExit(f"PM roadmap blocker mismatch for {requirement_id}: {row}")

file_rows = read_csv(run_dir / "pm_pr_slice_file_rows.csv")
if len(file_rows) != 39:
    raise SystemExit("PM PR file ledger should have 39 rows")
if len({row["slice_id"] for row in file_rows}) != 10:
    raise SystemExit("PM PR file ledger should cover all ten slices")
if any(row["exists"] != "1" for row in file_rows):
    missing = [row for row in file_rows if row["exists"] != "1"]
    raise SystemExit(f"PM PR file ledger should only reference existing files: {missing}")
file_key = {(row["slice_id"], row["file_path"]): row for row in file_rows}
for key in [
    ("docs/v1-roadmap", "docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md"),
    ("v53-query-instantiation-1000", "experiments/run_v53i_complete_source_query_instantiation.sh"),
    ("v53-system-a-b-g-h-measured", "experiments/run_v53ap_complete_source_abgh_same_query_measured.sh"),
    ("v54-routehint-generation-contract", "experiments/run_v54c_complete_source_grounded_generation_1000.sh"),
    ("v56-ruler-longbench-expanded", "experiments/run_v56b_ruler_longbench_expanded_scale.sh"),
    ("v59-one-command-demo", "examples/v1_0_architecture_challenge_pm_foundation_demo.sh"),
]:
    if key not in file_key:
        raise SystemExit(f"PM PR file ledger missing {key}")

verification_rows = read_csv(run_dir / "pm_pr_slice_verification_rows.csv")
if len(verification_rows) != 16:
    raise SystemExit("PM PR verification ledger should have 16 rows")
if len({row["slice_id"] for row in verification_rows}) != 10:
    raise SystemExit("PM PR verification ledger should cover all ten slices")
verification_key = {(row["slice_id"], row["command"]): row for row in verification_rows}
for key in [
    ("v53-system-a-b-g-h-measured", "experiments/test_v53ap_complete_source_abgh_same_query_measured.sh"),
    ("v54-routehint-generation-contract", "experiments/test_v54c_complete_source_grounded_generation_1000.sh"),
    ("v56-ruler-longbench-expanded", "experiments/test_v56b_ruler_longbench_expanded_scale.sh"),
    ("v59-one-command-demo", "experiments/test_v59e_one_command_pm_foundation_demo.sh"),
]:
    if key not in verification_key:
        raise SystemExit(f"PM PR verification ledger missing {key}")
if verification_key[("v58-blind-eval-contract", "experiments/test_v58c_blind_response_evidence_intake.sh")]["execution_policy"] != "defer-until-real-response-evidence":
    raise SystemExit("v58 real response intake should be marked deferred until real evidence exists")

review_packet_rows = read_csv(run_dir / "pm_pr_review_packet_rows.csv")
if len(review_packet_rows) != 10:
    raise SystemExit("PM PR review packet ledger should have ten rows")
if [row["slice_id"] for row in review_packet_rows] != expected_order:
    raise SystemExit("PM PR review packet order mismatch")
for row in review_packet_rows:
    if row["packet_ready"] != "1":
        raise SystemExit(f"PM PR review packet should be ready: {row}")
    packet_path = run_dir / row["packet_path"]
    if not packet_path.is_file() or packet_path.stat().st_size == 0:
        raise SystemExit(f"missing PM PR review packet file: {row['packet_path']}")
    packet_text = packet_path.read_text(encoding="utf-8")
    for snippet in [
        "## Merge Condition",
        "This is not a tests-only merge condition",
        "## Allowed Claim",
        "## Blocked Claim",
        "## Verification",
    ]:
        if snippet not in packet_text:
            raise SystemExit(f"PM PR review packet missing snippet {snippet}: {row['packet_path']}")
    if row["packet_sha256"] != sha256(packet_path):
        raise SystemExit(f"PM PR review packet sha mismatch: {row['packet_path']}")
review_packet_by_id = {row["slice_id"]: row for row in review_packet_rows}
if review_packet_by_id["v56-ruler-longbench-expanded"]["next_action"] != "hold-until-replay-artifact-or-real-evidence":
    raise SystemExit("v56 review packet should stay held until replay artifact exists")
if review_packet_by_id["v53-system-a-b-g-h-measured"]["next_action"] != "review-local-slice":
    raise SystemExit("A/B/G/H review packet should be reviewable")
if "experiments/test_v58c_blind_response_evidence_intake.sh" not in review_packet_by_id["v58-blind-eval-contract"]["deferred_commands"]:
    raise SystemExit("v58 review packet should carry the deferred real-response command")

closure_rows = read_csv(run_dir / "pm_blocker_closure_queue_rows.csv")
if len(closure_rows) != 6:
    raise SystemExit("PM blocker closure queue should cover the six current blockers")
closure_by_blocker = {row["blocker_class"]: row for row in closure_rows}
for blocker in expected_blocked.values():
    if blocker not in closure_by_blocker:
        raise SystemExit(f"missing blocker closure row: {blocker}")
for blocker, command_snippet in {
    "v56-replay-artifact-missing": "V56B_ALLOW_CONTRACT_REBUILD=1",
    "de-30b70b-baselines-missing": "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR>",
    "external-human-label-evidence-missing": "V10_H10_REAL_LABEL_EVIDENCE_CSV=<LABEL_CSV>",
    "v58c-intake-artifact-missing": "V58C_REUSE_EXISTING=0",
    "v58-real-blind-eval-missing": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR>",
    "v60-release-evidence-missing": "experiments/test_v60_architecture_challenge_release_contract.sh",
}.items():
    row = closure_by_blocker[blocker]
    if command_snippet not in row["local_intake_or_verification_command"]:
        raise SystemExit(f"blocker closure command mismatch for {blocker}: {row}")
    if not row["execution_policy"].startswith("defer-"):
        raise SystemExit(f"blocker closure should be deferred until real evidence: {blocker}")
    if "required" not in row["approval_required"]:
        raise SystemExit(f"blocker closure should require approval: {blocker}")
    if not row["claim_until_closed"]:
        raise SystemExit(f"blocker closure must state claim boundary: {blocker}")

blocker_packet_rows = read_csv(run_dir / "pm_blocker_closure_packet_rows.csv")
if len(blocker_packet_rows) != 6:
    raise SystemExit("PM blocker closure packet ledger should have six rows")
if [row["blocker_class"] for row in blocker_packet_rows] != list(expected_blocked.values()):
    raise SystemExit("PM blocker closure packet order mismatch")
for row in blocker_packet_rows:
    if row["packet_ready"] != "1":
        raise SystemExit(f"PM blocker closure packet should be ready: {row}")
    if not row["execution_policy"].startswith("defer-"):
        raise SystemExit(f"PM blocker closure packet should be deferred: {row}")
    if "required" not in row["approval_required"]:
        raise SystemExit(f"PM blocker closure packet should require approval: {row}")
    packet_path = run_dir / row["packet_path"]
    if not packet_path.is_file() or packet_path.stat().st_size == 0:
        raise SystemExit(f"missing PM blocker closure packet file: {row['packet_path']}")
    packet_text = packet_path.read_text(encoding="utf-8")
    for snippet in [
        "## Approval Required",
        "Do not execute automatically",
        "## Required Artifact Checklist",
        "## Local Intake Or Verification Command",
        "## Claim Until Closed",
    ]:
        if snippet not in packet_text:
            raise SystemExit(f"PM blocker closure packet missing snippet {snippet}: {row['packet_path']}")
    if row["packet_sha256"] != sha256(packet_path):
        raise SystemExit(f"PM blocker closure packet sha mismatch: {row['packet_path']}")
blocker_packet_by_id = {row["blocker_class"]: row for row in blocker_packet_rows}
if blocker_packet_by_id["de-30b70b-baselines-missing"]["required_artifact_rows"] != "4":
    raise SystemExit("D/E blocker packet should list four required artifact rows")
if blocker_packet_by_id["v60-release-evidence-missing"]["required_artifact_rows"] != "4":
    raise SystemExit("v60 blocker packet should list four required artifact rows")
if blocker_packet_by_id["v58c-intake-artifact-missing"]["required_artifact_rows"] != "3":
    raise SystemExit("v58c blocker packet should list three required artifact rows")
if "V58C_BLIND_RESPONSE_EVIDENCE_DIR" not in blocker_packet_by_id["v58-real-blind-eval-missing"]["local_intake_or_verification_command"]:
    raise SystemExit("v58 blocker packet should carry the real blind response intake command")
if "V58C_REUSE_EXISTING=0" not in blocker_packet_by_id["v58c-intake-artifact-missing"]["local_intake_or_verification_command"]:
    raise SystemExit("v58c blocker packet should carry the intake artifact rebuild command")

required_artifact_rows = read_csv(run_dir / "pm_blocker_required_artifact_rows.csv")
if len(required_artifact_rows) != 22:
    raise SystemExit("PM blocker required artifact ledger should have 22 rows")
if {row["blocker_class"] for row in required_artifact_rows} != set(expected_blocked.values()):
    raise SystemExit("PM blocker required artifact ledger should cover the six blocker classes")
if any(row["fixture_allowed"] != "0" for row in required_artifact_rows):
    raise SystemExit("PM blocker required artifacts should not allow fixture evidence")
if any(row["approval_required"] != "1" for row in required_artifact_rows):
    raise SystemExit("PM blocker required artifacts should require approval")
artifact_key = {(row["blocker_class"], row["artifact_id"]): row for row in required_artifact_rows}
for key in [
    ("v56-replay-artifact-missing", "v56b-scale-artifacts"),
    ("de-30b70b-baselines-missing", "d-model-identity"),
    ("de-30b70b-baselines-missing", "e-answer-citation-resource"),
    ("external-human-label-evidence-missing", "h10-label-evidence-csv"),
    ("v58c-intake-artifact-missing", "v58c-intake-summary"),
    ("v58c-intake-artifact-missing", "v58c-intake-artifacts"),
    ("v58c-intake-artifact-missing", "v58c-source-v58b-freeze"),
    ("v58-real-blind-eval-missing", "v58-blind-response-rows"),
    ("v60-release-evidence-missing", "v60-human-release-review"),
]:
    if key not in artifact_key:
        raise SystemExit(f"missing required artifact row: {key}")
if "llm_rag_answer_rows.csv" not in artifact_key[("de-30b70b-baselines-missing", "d-answer-citation-resource")]["artifact_path_or_env"]:
    raise SystemExit("D evidence artifact row should name answer/citation/resource files")
if "H10_EVIDENCE_FIELDS" not in artifact_key[("external-human-label-evidence-missing", "h10-label-evidence-csv")]["required_shape"]:
    raise SystemExit("h10 label evidence row should name the required H10 field contract")
if "blind_response_rows.csv" not in artifact_key[("v58-real-blind-eval-missing", "v58-blind-response-rows")]["artifact_path_or_env"]:
    raise SystemExit("v58 response artifact row should name blind_response_rows.csv")
if "v58c_blind_response_evidence_intake_summary.csv" not in artifact_key[("v58c-intake-artifact-missing", "v58c-intake-summary")]["artifact_path_or_env"]:
    raise SystemExit("v58c intake summary row should name the v58c summary")

execution_lock_rows = read_csv(run_dir / "pm_execution_lock_rows.csv")
if len(execution_lock_rows) != 10:
    raise SystemExit("PM execution lock should have ten rows")
expected_lock_ids = [
    "no-new-v62-v63-default",
    "v53-foundation-freeze-first",
    "abgh-internal-prebaseline-only",
    "de-baselines-real-evidence-only",
    "h10-real-label-only",
    "v54-grounded-generation-no-raw-context",
    "v56-replay-artifact-before-benchmark-claim",
    "v58-real-blind-eval-only",
    "v59-foundation-not-public-demo",
    "v60-release-gate-last",
]
if [row["lock_id"] for row in execution_lock_rows] != expected_lock_ids:
    raise SystemExit("PM execution lock order mismatch")
if any(row["status"] != "locked" for row in execution_lock_rows):
    raise SystemExit("every PM execution lock row should be locked")
lock_by_id = {row["lock_id"]: row for row in execution_lock_rows}
if "v62/v63" not in lock_by_id["no-new-v62-v63-default"]["forbidden_next_action"]:
    raise SystemExit("PM execution lock should forbid v62/v63 scope drift")
if "public comparison" not in lock_by_id["abgh-internal-prebaseline-only"]["forbidden_next_action"]:
    raise SystemExit("A/B/G/H execution lock should forbid public comparison")
if "external/human labels" not in lock_by_id["h10-real-label-only"]["required_focus"]:
    raise SystemExit("h10 execution lock should require external/human labels")
if "raw retrieved context prompt stuffing" not in lock_by_id["v54-grounded-generation-no-raw-context"]["forbidden_next_action"]:
    raise SystemExit("v54 execution lock should forbid raw prompt stuffing")
if "release" not in lock_by_id["v60-release-gate-last"]["scope"]:
    raise SystemExit("v60 execution lock should cover the release gate")

template_rows = read_csv(run_dir / "pm_external_return_template_rows.csv")
if len(template_rows) != 22:
    raise SystemExit("PM external return template ledger should have 22 rows")
if any(row["template_ready"] != "1" for row in template_rows):
    raise SystemExit("all PM external return templates should be ready")
if any(row["fixture_allowed"] != "0" for row in template_rows):
    raise SystemExit("PM external return templates should not allow fixture evidence")
if any(row["approval_required"] != "1" for row in template_rows):
    raise SystemExit("PM external return templates should require approval")
template_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in template_rows}
for key in artifact_key:
    if key not in template_by_key:
        raise SystemExit(f"missing return template for required artifact: {key}")
for row in template_rows:
    template_path = run_dir / row["template_path"]
    if not template_path.is_file() or template_path.stat().st_size == 0:
        raise SystemExit(f"missing PM external return template: {row['template_path']}")
    if row["template_sha256"] != sha256(template_path):
        raise SystemExit(f"PM external return template sha mismatch: {row['template_path']}")
d_model_template = (run_dir / template_by_key[("de-30b70b-baselines-missing", "d-model-identity")]["template_path"]).read_text(encoding="utf-8")
if '"system_id": "D"' not in d_model_template or '"external_api_used": 0' not in d_model_template:
    raise SystemExit("D model identity template should pin system_id D and external_api_used=0")
h10_template = (run_dir / template_by_key[("external-human-label-evidence-missing", "h10-label-evidence-csv")]["template_path"]).read_text(encoding="utf-8")
for header in ["human_reviewed", "external_source_verified", "non_fixture_declared", "acceptance_summary_sha256"]:
    if header not in h10_template:
        raise SystemExit(f"h10 label template missing header: {header}")
v58_template = (run_dir / template_by_key[("v58-real-blind-eval-missing", "v58-blind-response-rows")]["template_path"]).read_text(encoding="utf-8")
if "blind_response_id" not in v58_template or "identity_key_sha256" in v58_template:
    raise SystemExit("v58 blind response template should contain response fields without identity key")
v58c_template = (run_dir / template_by_key[("v58c-intake-artifact-missing", "v58c-intake-summary")]["template_path"]).read_text(encoding="utf-8")
if "v58c_blind_response_evidence_intake_ready" not in v58c_template or "human_blind_review_ready" not in v58c_template:
    raise SystemExit("v58c intake summary template should name readiness and review fields")
v60_template = (run_dir / template_by_key[("v60-release-evidence-missing", "v60-human-release-review")]["template_path"]).read_text(encoding="utf-8")
if "release_review_id" not in v60_template or "accepted_for_public_v1" not in v60_template:
    raise SystemExit("v60 release review template should name release review acceptance fields")

required_files = [
    "pm_pr_slice_rows.csv",
    "pm_pr_merge_gate_rows.csv",
    "pm_roadmap_requirement_rows.csv",
    "pm_execution_lock_rows.csv",
    "pm_external_return_template_rows.csv",
    "pm_pr_slice_file_rows.csv",
    "pm_pr_slice_verification_rows.csv",
    "pm_pr_claim_boundary_rows.csv",
    "pm_pr_review_packet_rows.csv",
    "pm_blocker_closure_queue_rows.csv",
    "pm_blocker_closure_packet_rows.csv",
    "pm_blocker_required_artifact_rows.csv",
    "source_summary_rows.csv",
    "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md",
    "v1_0_pm_pr_claim_slice_gate_manifest.json",
    "sha256_manifest.csv",
    "source_docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing PM PR slice gate artifact: {rel}")

manifest = json.loads((run_dir / "v1_0_pm_pr_claim_slice_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("recommended_pr_slice_rows") != 10 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("PM PR manifest readiness mismatch")
if manifest.get("slice_ids") != expected_order:
    raise SystemExit("PM PR manifest slice order mismatch")
if manifest.get("pm_roadmap_requirement_rows") != 19 or manifest.get("pm_foundation_ready") != 1:
    raise SystemExit("PM PR manifest roadmap audit mismatch")
if manifest.get("v53_foundation_freeze_certificate_rows") != 10 or manifest.get("v53_foundation_machine_freeze_ready") != 1:
    raise SystemExit("PM PR manifest v53 foundation freeze mismatch")
if manifest.get("pm_pr_slice_file_rows") != 39 or manifest.get("pm_pr_slice_verification_rows") != 16:
    raise SystemExit("PM PR manifest file/verification ledger mismatch")
if manifest.get("pm_pr_claim_boundary_rows") != 10 or manifest.get("pm_pr_claim_boundary_pass_rows") != 10:
    raise SystemExit("PM PR manifest claim boundary ledger mismatch")
if manifest.get("pm_pr_review_packet_rows") != 10 or manifest.get("pm_pr_review_packet_files") != 10:
    raise SystemExit("PM PR manifest review packet ledger mismatch")
if manifest.get("pm_pr_review_packet_ready_rows") != 10 or manifest.get("pm_pr_review_packet_blocked_slice_rows") != 1:
    raise SystemExit("PM PR manifest review packet readiness mismatch")
if manifest.get("pm_blocker_closure_queue_rows") != 6:
    raise SystemExit("PM PR manifest blocker closure queue mismatch")
if manifest.get("pm_blocker_closure_packet_rows") != 6 or manifest.get("pm_blocker_closure_packet_files") != 6:
    raise SystemExit("PM PR manifest blocker closure packet mismatch")
if manifest.get("pm_blocker_closure_packet_ready_rows") != 6 or manifest.get("pm_blocker_closure_packet_approval_rows") != 6:
    raise SystemExit("PM PR manifest blocker closure packet readiness mismatch")
if manifest.get("pm_blocker_required_artifact_rows") != 22 or manifest.get("pm_blocker_required_artifact_fixture_allowed_rows") != 0:
    raise SystemExit("PM PR manifest blocker required artifact mismatch")
if manifest.get("pm_execution_lock_rows") != 10 or manifest.get("pm_execution_lock_active_rows") != 10:
    raise SystemExit("PM PR manifest execution lock row mismatch")
if manifest.get("pm_scope_drift_allowed") != 0 or manifest.get("pm_new_scaffold_default_allowed") != 0:
    raise SystemExit("PM PR manifest should disallow scope drift and default new scaffolds")
if manifest.get("pm_external_return_template_rows") != 22 or manifest.get("pm_external_return_template_files") != 22:
    raise SystemExit("PM PR manifest external return template count mismatch")
if manifest.get("pm_external_return_template_ready_rows") != 22 or manifest.get("pm_external_return_template_fixture_allowed_rows") != 0:
    raise SystemExit("PM PR manifest external return template readiness mismatch")
if manifest.get("pm_external_return_template_approval_rows") != 22:
    raise SystemExit("PM PR manifest external return templates should require approval")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"PM PR slice gate sha mismatch: {rel}")

boundary = (run_dir / "V1_0_PM_PR_CLAIM_SLICE_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "recommended_pr_slice_rows=10",
    "merge_condition_defined_rows=10",
    "pm_roadmap_requirement_rows=19",
    "pm_foundation_ready=1",
    "v53_foundation_freeze_certificate_rows=10",
    "v53_foundation_machine_freeze_ready=1",
    "pm_pr_slice_file_rows=39",
    "pm_pr_slice_verification_rows=16",
    "pm_pr_claim_boundary_rows=10",
    "pm_pr_review_packet_rows=10",
    "pm_pr_review_packet_files=10",
    "pm_blocker_closure_queue_rows=6",
    "pm_blocker_closure_packet_rows=6",
    "pm_blocker_closure_packet_files=6",
    "pm_blocker_required_artifact_rows=22",
    "pm_execution_lock_rows=10",
    "pm_scope_drift_allowed=0",
    "pm_new_scaffold_default_allowed=0",
    "pm_external_return_template_rows=22",
    "pm_external_return_template_files=22",
    "tests_only_merge_condition_rows=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"PM PR slice gate boundary missing: {snippet}")
PY

echo "v1.0 PM PR claim slice gate smoke passed"
