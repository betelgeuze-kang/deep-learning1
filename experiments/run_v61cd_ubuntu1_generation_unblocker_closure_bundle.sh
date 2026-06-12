#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cd_ubuntu1_generation_unblocker_closure_bundle"
RUN_ID="${V61CD_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CD_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cd_ubuntu1_generation_unblocker_closure_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh" >/dev/null
V61CA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ca_ubuntu1_remaining_page_hash_result_intake.sh" >/dev/null
V53S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v61cc_dir = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge" / "bridge_001"
v61ca_dir = results / "v61ca_ubuntu1_remaining_page_hash_result_intake" / "intake_001"
v53s_dir = results / "v53s_complete_source_review_return_intake" / "intake_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"

v61cc_summary_path = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"
v61ca_summary_path = results / "v61ca_ubuntu1_remaining_page_hash_result_intake_summary.csv"
v53s_summary_path = results / "v53s_complete_source_review_return_intake_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61cc_decision_path = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"
v61ca_decision_path = results / "v61ca_ubuntu1_remaining_page_hash_result_intake_decision.csv"
v53s_decision_path = results / "v53s_complete_source_review_return_intake_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"

v61cc = read_csv(v61cc_summary_path)[0]
v61ca = read_csv(v61ca_summary_path)[0]
v53s = read_csv(v53s_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]
for field, summary in [
    ("v61cc_ubuntu1_page_hash_generation_admission_bridge_ready", v61cc),
    ("v61ca_ubuntu1_remaining_page_hash_result_intake_ready", v61ca),
    ("v53s_complete_source_review_return_intake_ready", v53s),
    ("v61bt_ubuntu1_actual_generation_result_intake_ready", v61bt),
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v61cd requires {field}=1")

for src, rel in [
    (v61cc_summary_path, "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"),
    (v61cc_decision_path, "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"),
    (v61cc_dir / "page_hash_generation_admission_bridge_rows.csv", "source_v61cc/page_hash_generation_admission_bridge_rows.csv"),
    (v61cc_dir / "page_hash_generation_admission_requirement_rows.csv", "source_v61cc/page_hash_generation_admission_requirement_rows.csv"),
    (v61cc_dir / "runtime_gap_rows.csv", "source_v61cc/runtime_gap_rows.csv"),
    (v61cc_dir / "sha256_manifest.csv", "source_v61cc/sha256_manifest.csv"),
    (v61ca_summary_path, "source_v61ca/v61ca_ubuntu1_remaining_page_hash_result_intake_summary.csv"),
    (v61ca_decision_path, "source_v61ca/v61ca_ubuntu1_remaining_page_hash_result_intake_decision.csv"),
    (v61ca_dir / "remaining_page_hash_result_required_field_rows.csv", "source_v61ca/remaining_page_hash_result_required_field_rows.csv"),
    (v61ca_dir / "remaining_page_hash_result_template_rows.csv", "source_v61ca/remaining_page_hash_result_template_rows.csv"),
    (v61ca_dir / "remaining_page_hash_result_chunk_status_rows.csv", "source_v61ca/remaining_page_hash_result_chunk_status_rows.csv"),
    (v61ca_dir / "sha256_manifest.csv", "source_v61ca/sha256_manifest.csv"),
    (v53s_summary_path, "source_v53s/v53s_complete_source_review_return_intake_summary.csv"),
    (v53s_decision_path, "source_v53s/v53s_complete_source_review_return_intake_decision.csv"),
    (v53s_dir / "review_return_required_field_rows.csv", "source_v53s/review_return_required_field_rows.csv"),
    (v53s_dir / "review_return_row_template.csv", "source_v53s/review_return_row_template.csv"),
    (v53s_dir / "sha256_manifest.csv", "source_v53s/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_result_required_field_rows.csv", "source_v61bt/actual_generation_result_required_field_rows.csv"),
    (v61bt_dir / "actual_generation_result_template_rows.csv", "source_v61bt/actual_generation_result_template_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
]:
    copy(src, rel)

target_root = v61cc["target_root_path"]
phase_rows = [
    {
        "phase_id": "phase-01-remaining-page-hash-return",
        "phase_order": "1",
        "phase_name": "remaining-page-hash-result-return",
        "required_input": "V61CA_PAGE_HASH_RESULT_DIR/remaining_page_hash_result_rows.csv",
        "required_rows": v61ca["expected_remaining_page_hash_result_rows"],
        "accepted_rows": v61ca["accepted_remaining_page_hash_result_rows"],
        "blocked_rows": v61cc["page_hash_blocked_rows"],
        "closure_ready": v61cc["full_safetensors_page_hash_binding_ready"],
        "reason": "full page-hash coverage remains incomplete",
    },
    {
        "phase_id": "phase-02-complete-source-review-return",
        "phase_order": "2",
        "phase_name": "complete-source-review-return",
        "required_input": "V53S_REVIEW_RETURN_DIR/{human_review_rows.csv,adjudication_rows.csv,reviewer_identity_rows.csv,reviewer_conflict_rows.csv,acceptance_summary.json}",
        "required_rows": str(int(v53s["expected_human_review_rows"]) + int(v53s["expected_adjudication_rows"]) + int(v53s["expected_reviewer_identity_rows"]) + int(v53s["expected_conflict_disclosure_rows"])),
        "accepted_rows": str(int(v53s["accepted_human_review_rows"]) + int(v53s["accepted_adjudication_rows"]) + int(v53s["accepted_reviewer_identity_rows"]) + int(v53s["accepted_conflict_disclosure_rows"])),
        "blocked_rows": v61cc["review_return_blocked_rows"],
        "closure_ready": v61cc["complete_source_review_return_ready"],
        "reason": "complete-source human/source review return is not accepted",
    },
    {
        "phase_id": "phase-03-actual-generation-result-return",
        "phase_order": "3",
        "phase_name": "actual-generation-result-return",
        "required_input": "V61BT_GENERATION_RESULT_DIR/{answer,citation,abstain_fallback,latency,acceptance}",
        "required_rows": v61bt["complete_source_query_rows"],
        "accepted_rows": v61bt["accepted_generation_rows"],
        "blocked_rows": v61cc["generation_result_artifact_blocked_rows"],
        "closure_ready": v61cc["actual_model_generation_ready"],
        "reason": "actual generation waits for page-hash/review closure and returned generation artifacts",
    },
]
write_csv(run_dir / "generation_unblocker_phase_rows.csv", list(phase_rows[0].keys()), phase_rows)

artifact_rows = [
    ("phase-01-remaining-page-hash-return", "remaining_page_hash_result_rows.csv", "csv", v61ca["expected_remaining_page_hash_result_rows"], v61ca["accepted_remaining_page_hash_result_rows"], "V61CA_PAGE_HASH_RESULT_DIR"),
    ("phase-02-complete-source-review-return", "human_review_rows.csv", "csv", v53s["expected_human_review_rows"], v53s["accepted_human_review_rows"], "V53S_REVIEW_RETURN_DIR"),
    ("phase-02-complete-source-review-return", "adjudication_rows.csv", "csv", v53s["expected_adjudication_rows"], v53s["accepted_adjudication_rows"], "V53S_REVIEW_RETURN_DIR"),
    ("phase-02-complete-source-review-return", "reviewer_identity_rows.csv", "csv", v53s["expected_reviewer_identity_rows"], v53s["accepted_reviewer_identity_rows"], "V53S_REVIEW_RETURN_DIR"),
    ("phase-02-complete-source-review-return", "reviewer_conflict_rows.csv", "csv", v53s["expected_conflict_disclosure_rows"], v53s["accepted_conflict_disclosure_rows"], "V53S_REVIEW_RETURN_DIR"),
    ("phase-02-complete-source-review-return", "acceptance_summary.json", "json", "1", v53s["acceptance_summary_ready"], "V53S_REVIEW_RETURN_DIR"),
    ("phase-03-actual-generation-result-return", "real_model_generation_answer_rows.csv", "csv", v61bt["complete_source_query_rows"], v61bt["accepted_answer_rows"], "V61BT_GENERATION_RESULT_DIR"),
    ("phase-03-actual-generation-result-return", "real_model_generation_citation_rows.csv", "csv", v61bt["complete_source_query_rows"], v61bt["accepted_citation_rows"], "V61BT_GENERATION_RESULT_DIR"),
    ("phase-03-actual-generation-result-return", "real_model_generation_abstain_fallback_rows.csv", "csv", v61bt["complete_source_query_rows"], "0", "V61BT_GENERATION_RESULT_DIR"),
    ("phase-03-actual-generation-result-return", "real_model_generation_latency_rows.csv", "csv", v61bt["complete_source_query_rows"], v61bt["accepted_latency_rows"], "V61BT_GENERATION_RESULT_DIR"),
    ("phase-03-actual-generation-result-return", "real_model_generation_acceptance_summary.json", "json", "1", "0", "V61BT_GENERATION_RESULT_DIR"),
]
artifact_dicts = [
    {
        "phase_id": phase_id,
        "artifact_name": artifact_name,
        "artifact_type": artifact_type,
        "required_rows": required_rows,
        "accepted_rows": accepted_rows,
        "return_env_var": env_var,
        "artifact_ready": str(int(required_rows == accepted_rows and required_rows != "0")),
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
    for phase_id, artifact_name, artifact_type, required_rows, accepted_rows, env_var in artifact_rows
]
write_csv(run_dir / "generation_unblocker_return_artifact_rows.csv", list(artifact_dicts[0].keys()), artifact_dicts)

command_rows = [
    {
        "command_id": "verify-return-bundle-shape",
        "phase_id": "all",
        "command": "./operator_bundle/VERIFY_RETURN_BUNDLE.sh",
        "purpose": "verify return directories contain required artifact filenames before intake reruns",
        "execution_ready": "0",
    },
    {
        "command_id": "intake-page-hash-return",
        "phase_id": "phase-01-remaining-page-hash-return",
        "command": "V61CA_REUSE_EXISTING=0 V61CA_PAGE_HASH_RESULT_DIR=$V61CA_PAGE_HASH_RESULT_DIR ./experiments/run_v61ca_ubuntu1_remaining_page_hash_result_intake.sh",
        "purpose": "accept executed remaining page-hash result rows",
        "execution_ready": "0",
    },
    {
        "command_id": "promote-page-hash-coverage",
        "phase_id": "phase-01-remaining-page-hash-return",
        "command": "V61CB_REUSE_EXISTING=0 ./experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh",
        "purpose": "promote accepted page-hash rows into full coverage if complete",
        "execution_ready": "0",
    },
    {
        "command_id": "intake-review-return",
        "phase_id": "phase-02-complete-source-review-return",
        "command": "V53S_REUSE_EXISTING=0 V53S_REVIEW_RETURN_DIR=$V53S_REVIEW_RETURN_DIR ./experiments/run_v53s_complete_source_review_return_intake.sh",
        "purpose": "accept complete-source human/source review return rows",
        "execution_ready": "0",
    },
    {
        "command_id": "refresh-audit-readiness",
        "phase_id": "phase-02-complete-source-review-return",
        "command": "V53T_REUSE_EXISTING=0 ./experiments/run_v53t_complete_source_audit_readiness_gate.sh",
        "purpose": "refresh complete-source audit readiness after review return",
        "execution_ready": "0",
    },
    {
        "command_id": "intake-generation-results",
        "phase_id": "phase-03-actual-generation-result-return",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=$V61BT_GENERATION_RESULT_DIR ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "purpose": "accept actual source-bound generation result artifacts",
        "execution_ready": "0",
    },
    {
        "command_id": "refresh-generation-admission-bridge",
        "phase_id": "phase-03-actual-generation-result-return",
        "command": "V61CC_REUSE_EXISTING=0 ./experiments/run_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh",
        "purpose": "recompute generation admission after page-hash/review/generation returns",
        "execution_ready": "0",
    },
]
write_csv(run_dir / "generation_unblocker_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)
(operator_dir / "README.md").write_text(
    "# v61cd Generation Unblocker Closure Bundle\n\n"
    "Return directories must stay outside the repository unless they contain only metadata/hash rows.\n"
    "The checkpoint payload itself must not be copied into the repository.\n\n"
    "Required environment variables for a real return:\n\n"
    "- V61CA_PAGE_HASH_RESULT_DIR\n"
    "- V53S_REVIEW_RETURN_DIR\n"
    "- V61BT_GENERATION_RESULT_DIR\n",
    encoding="utf-8",
)
return_manifest_rows = [
    {
        "return_env_var": env_var,
        "artifact_name": artifact_name,
        "required": "1",
        "phase_id": phase_id,
    }
    for phase_id, artifact_name, _artifact_type, _required_rows, _accepted_rows, env_var in artifact_rows
]
write_csv(operator_dir / "return_manifest_template.csv", list(return_manifest_rows[0].keys()), return_manifest_rows)
(operator_dir / "VERIFY_RETURN_BUNDLE.sh").write_text(
    """#!/usr/bin/env bash
set -euo pipefail

missing=0
check_file() {
  local root="$1"
  local rel="$2"
  if [[ -z "$root" || ! -s "$root/$rel" ]]; then
    echo "missing: $root/$rel" >&2
    missing=1
  fi
}

check_file "${V61CA_PAGE_HASH_RESULT_DIR:-}" "remaining_page_hash_result_rows.csv"
check_file "${V53S_REVIEW_RETURN_DIR:-}" "human_review_rows.csv"
check_file "${V53S_REVIEW_RETURN_DIR:-}" "adjudication_rows.csv"
check_file "${V53S_REVIEW_RETURN_DIR:-}" "reviewer_identity_rows.csv"
check_file "${V53S_REVIEW_RETURN_DIR:-}" "reviewer_conflict_rows.csv"
check_file "${V53S_REVIEW_RETURN_DIR:-}" "acceptance_summary.json"
check_file "${V61BT_GENERATION_RESULT_DIR:-}" "real_model_generation_answer_rows.csv"
check_file "${V61BT_GENERATION_RESULT_DIR:-}" "real_model_generation_citation_rows.csv"
check_file "${V61BT_GENERATION_RESULT_DIR:-}" "real_model_generation_abstain_fallback_rows.csv"
check_file "${V61BT_GENERATION_RESULT_DIR:-}" "real_model_generation_latency_rows.csv"
check_file "${V61BT_GENERATION_RESULT_DIR:-}" "real_model_generation_acceptance_summary.json"

if [[ "$missing" != "0" ]]; then
  exit 2
fi
echo "v61cd return bundle shape present"
""",
    encoding="utf-8",
)
(operator_dir / "VERIFY_RETURN_BUNDLE.sh").chmod(0o755)

page_hash_closure_ready = int(v61cc["full_safetensors_page_hash_binding_ready"])
review_closure_ready = int(v61cc["complete_source_review_return_ready"])
generation_artifact_closure_ready = int(v61bt["generation_packet_artifacts_ready"])
generation_unblocker_closure_ready = int(page_hash_closure_ready and review_closure_ready and generation_artifact_closure_ready)

metric = {
    "metric_id": "v61cd_ubuntu1_generation_unblocker_closure_bundle_metrics",
    "model_id": model_id,
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": v61cc["v61cc_ubuntu1_page_hash_generation_admission_bridge_ready"],
    "v61ca_ubuntu1_remaining_page_hash_result_intake_ready": v61ca["v61ca_ubuntu1_remaining_page_hash_result_intake_ready"],
    "v53s_complete_source_review_return_intake_ready": v53s["v53s_complete_source_review_return_intake_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "target_root_path": target_root,
    "closure_phase_rows": str(len(phase_rows)),
    "return_artifact_rows": str(len(artifact_dicts)),
    "operator_command_rows": str(len(command_rows)),
    "complete_source_query_rows": v61cc["complete_source_query_rows"],
    "generation_admission_bridge_rows": v61cc["generation_admission_bridge_rows"],
    "page_hash_return_required_rows": v61ca["expected_remaining_page_hash_result_rows"],
    "page_hash_return_accepted_rows": v61ca["accepted_remaining_page_hash_result_rows"],
    "total_required_page_hash_rows": v61cc["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61cc["total_verified_page_hash_rows"],
    "human_review_required_rows": v53s["expected_human_review_rows"],
    "human_review_accepted_rows": v53s["accepted_human_review_rows"],
    "adjudication_required_rows": v53s["expected_adjudication_rows"],
    "adjudication_accepted_rows": v53s["accepted_adjudication_rows"],
    "reviewer_identity_required_rows": v53s["expected_reviewer_identity_rows"],
    "reviewer_identity_accepted_rows": v53s["accepted_reviewer_identity_rows"],
    "conflict_disclosure_required_rows": v53s["expected_conflict_disclosure_rows"],
    "conflict_disclosure_accepted_rows": v53s["accepted_conflict_disclosure_rows"],
    "generation_result_required_artifacts": v61bt["expected_generation_result_artifacts"],
    "generation_result_accepted_artifacts": v61bt["accepted_generation_result_artifacts"],
    "generation_execution_admitted_rows": v61cc["generation_execution_admitted_rows"],
    "page_hash_blocked_rows": v61cc["page_hash_blocked_rows"],
    "review_return_blocked_rows": v61cc["review_return_blocked_rows"],
    "generation_result_artifact_blocked_rows": v61cc["generation_result_artifact_blocked_rows"],
    "page_hash_closure_ready": str(page_hash_closure_ready),
    "review_return_closure_ready": str(review_closure_ready),
    "generation_result_closure_ready": str(generation_artifact_closure_ready),
    "generation_unblocker_closure_ready": str(generation_unblocker_closure_ready),
    "actual_model_generation_ready": v61cc["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "generation_unblocker_metric_rows.csv", list(metric.keys()), [metric])

requirement_rows = [
    ("v61cc-admission-bridge-input", "pass", "v61cc ready", v61cc["v61cc_ubuntu1_page_hash_generation_admission_bridge_ready"], "generation admission bridge is bound"),
    ("remaining-page-hash-return", "blocked", v61ca["expected_remaining_page_hash_result_rows"], v61ca["accepted_remaining_page_hash_result_rows"], "remaining page-hash return rows are missing"),
    ("complete-source-review-return", "blocked", v53s["expected_human_review_rows"], v53s["accepted_human_review_rows"], "human/source review return is missing"),
    ("actual-generation-result-return", "blocked", v61bt["expected_generation_result_artifacts"], v61bt["accepted_generation_result_artifacts"], "actual generation artifacts are missing"),
    ("generation-unblocker-closure", "blocked", v61cc["complete_source_query_rows"], v61cc["generation_execution_admitted_rows"], "page-hash/review/generation returns are not complete"),
    ("manifest-only-no-repo-payload", "pass", "0 payload bytes", "0", "v61cd writes operator metadata only"),
]
write_csv(
    run_dir / "generation_unblocker_requirement_rows.csv",
    ["requirement_id", "status", "required_value", "actual_value", "reason"],
    [
        {
            "requirement_id": req,
            "status": status,
            "required_value": required,
            "actual_value": actual,
            "reason": reason,
        }
        for req, status, required, actual, reason in requirement_rows
    ],
)

gap_rows = [
    ("v61cc-admission-bridge-input", "ready", "v61cc admission bridge is bound"),
    ("remaining-page-hash-return", "blocked", f"accepted={v61ca['accepted_remaining_page_hash_result_rows']}/{v61ca['expected_remaining_page_hash_result_rows']}"),
    ("complete-source-review-return", "blocked", f"accepted={v53s['accepted_human_review_rows']}/{v53s['expected_human_review_rows']}"),
    ("actual-generation-result-return", "blocked", f"accepted_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"),
    ("actual-model-generation", "blocked", f"admitted={v61cc['generation_execution_admitted_rows']}/{v61cc['generation_admission_bridge_rows']}"),
    ("production-latency", "blocked", "not a production latency run"),
    ("near-frontier-quality", "blocked", "requires external comparison/review evidence"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61cd_ubuntu1_generation_unblocker_closure_bundle_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61cc-admission-bridge-input", "status": "pass", "reason": "v61cc admission bridge is bound"},
    {"gate": "operator-closure-bundle", "status": "pass", "reason": f"return_artifact_rows={len(artifact_dicts)}; operator_command_rows={len(command_rows)}"},
    {"gate": "remaining-page-hash-return", "status": "blocked", "reason": f"accepted={v61ca['accepted_remaining_page_hash_result_rows']}/{v61ca['expected_remaining_page_hash_result_rows']}"},
    {"gate": "complete-source-review-return", "status": "blocked", "reason": f"accepted={v53s['accepted_human_review_rows']}/{v53s['expected_human_review_rows']}"},
    {"gate": "actual-generation-result-return", "status": "blocked", "reason": f"accepted_artifacts={v61bt['accepted_generation_result_artifacts']}/{v61bt['expected_generation_result_artifacts']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"admitted={v61cc['generation_execution_admitted_rows']}/{v61cc['generation_admission_bridge_rows']}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cd writes metadata and operator templates only"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a production benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cd Ubuntu-1 Generation Unblocker Closure Bundle Boundary

This bundle converts the v61cc blockers into an operator return checklist. It
does not execute page hashing, does not execute generation, does not download
checkpoint payload bytes, and does not commit checkpoint payload bytes.

Evidence emitted:

- closure_phase_rows={len(phase_rows)}
- return_artifact_rows={len(artifact_dicts)}
- operator_command_rows={len(command_rows)}
- page_hash_return_required_rows={v61ca['expected_remaining_page_hash_result_rows']}
- page_hash_return_accepted_rows={v61ca['accepted_remaining_page_hash_result_rows']}
- human_review_required_rows={v53s['expected_human_review_rows']}
- human_review_accepted_rows={v53s['accepted_human_review_rows']}
- adjudication_required_rows={v53s['expected_adjudication_rows']}
- adjudication_accepted_rows={v53s['accepted_adjudication_rows']}
- generation_result_required_artifacts={v61bt['expected_generation_result_artifacts']}
- generation_result_accepted_artifacts={v61bt['accepted_generation_result_artifacts']}
- generation_execution_admitted_rows={v61cc['generation_execution_admitted_rows']}
- page_hash_blocked_rows={v61cc['page_hash_blocked_rows']}
- review_return_blocked_rows={v61cc['review_return_blocked_rows']}
- generation_result_artifact_blocked_rows={v61cc['generation_result_artifact_blocked_rows']}
- generation_unblocker_closure_ready={generation_unblocker_closure_ready}
- actual_model_generation_ready={v61cc['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61cd=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: v61 has an operator closure bundle for the remaining page-hash,
review-return, and generation-result blockers. Blocked wording: completed full
page-hash coverage, complete-source review return, actual model generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CD_UBUNTU1_GENERATION_UNBLOCKER_CLOSURE_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cd_ubuntu1_generation_unblocker_closure_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cd_ubuntu1_generation_unblocker_closure_bundle_ready": 1,
    "source_v61cc_summary_sha256": sha256(v61cc_summary_path),
    "source_v61ca_summary_sha256": sha256(v61ca_summary_path),
    "source_v53s_summary_sha256": sha256(v53s_summary_path),
    "source_v61bt_summary_sha256": sha256(v61bt_summary_path),
    "closure_phase_rows": len(phase_rows),
    "return_artifact_rows": len(artifact_dicts),
    "operator_command_rows": len(command_rows),
    "page_hash_return_required_rows": int(v61ca["expected_remaining_page_hash_result_rows"]),
    "human_review_required_rows": int(v53s["expected_human_review_rows"]),
    "generation_result_required_artifacts": int(v61bt["expected_generation_result_artifacts"]),
    "generation_unblocker_closure_ready": generation_unblocker_closure_ready,
    "actual_model_generation_ready": int(v61cc["actual_model_generation_ready"]),
    "checkpoint_payload_bytes_downloaded_by_v61cd": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cd_ubuntu1_generation_unblocker_closure_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cd_ubuntu1_generation_unblocker_closure_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
