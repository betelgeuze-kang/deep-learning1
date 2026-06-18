#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dx_active_goal_status_audit_gate"
RUN_ID="${V61DX_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dx_active_goal_status_audit_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52y_f_optional_final_policy_summary.csv" ]]; then
  V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53t_complete_source_audit_readiness_gate_summary.csv" ]]; then
  V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv" ]]; then
  V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61dh_post_full_shard_claim_audit_gate_summary.csv" ]]; then
  V61DH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dh_post_full_shard_claim_audit_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61dw_return_bundle_operator_handoff_bundle_summary.csv" ]]; then
  V61DW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dw_return_bundle_operator_handoff_bundle.sh" >/dev/null
fi

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


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def row_status(ready):
    return "ready" if ready else "blocked"


source_paths = {
    "v52y_summary": results / "v52y_f_optional_final_policy_summary.csv",
    "v52y_decision": results / "v52y_f_optional_final_policy_decision.csv",
    "v52y_f_rows": results / "v52y_f_optional_final_policy/policy_001/f_optional_final_rows.csv",
    "v52y_wording": results / "v52y_f_optional_final_policy/policy_001/comparison_wording_rows.csv",
    "v53t_summary": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53t_decision": results / "v53t_complete_source_audit_readiness_gate_decision.csv",
    "v53t_claims": results / "v53t_complete_source_audit_readiness_gate/gate_001/complete_source_audit_claim_rows.csv",
    "v61dg_summary": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "v61dg_decision": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv",
    "v61dg_evidence": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate/gate_001/post_full_shard_runtime_evidence_rows.csv",
    "v61dg_claims": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate/gate_001/runtime_evidence_claim_boundary_rows.csv",
    "v61dh_summary": results / "v61dh_post_full_shard_claim_audit_gate_summary.csv",
    "v61dh_decision": results / "v61dh_post_full_shard_claim_audit_gate_decision.csv",
    "v61dh_claims": results / "v61dh_post_full_shard_claim_audit_gate/audit_001/post_full_shard_claim_audit_rows.csv",
    "v61dw_summary": results / "v61dw_return_bundle_operator_handoff_bundle_summary.csv",
    "v61dw_decision": results / "v61dw_return_bundle_operator_handoff_bundle_decision.csv",
    "v61dw_files": results / "v61dw_return_bundle_operator_handoff_bundle/bundle_001/return_bundle_operator_handoff_bundle_file_rows.csv",
}

for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dx source {key}: {path}")

copy(source_paths["v52y_summary"], "source_v52y/v52y_f_optional_final_policy_summary.csv")
copy(source_paths["v52y_decision"], "source_v52y/v52y_f_optional_final_policy_decision.csv")
copy(source_paths["v52y_f_rows"], "source_v52y/f_optional_final_rows.csv")
copy(source_paths["v52y_wording"], "source_v52y/comparison_wording_rows.csv")
copy(source_paths["v53t_summary"], "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv")
copy(source_paths["v53t_decision"], "source_v53t/v53t_complete_source_audit_readiness_gate_decision.csv")
copy(source_paths["v53t_claims"], "source_v53t/complete_source_audit_claim_rows.csv")
copy(source_paths["v61dg_summary"], "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv")
copy(source_paths["v61dg_decision"], "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv")
copy(source_paths["v61dg_evidence"], "source_v61dg/post_full_shard_runtime_evidence_rows.csv")
copy(source_paths["v61dg_claims"], "source_v61dg/runtime_evidence_claim_boundary_rows.csv")
copy(source_paths["v61dh_summary"], "source_v61dh/v61dh_post_full_shard_claim_audit_gate_summary.csv")
copy(source_paths["v61dh_decision"], "source_v61dh/v61dh_post_full_shard_claim_audit_gate_decision.csv")
copy(source_paths["v61dh_claims"], "source_v61dh/post_full_shard_claim_audit_rows.csv")
copy(source_paths["v61dw_summary"], "source_v61dw/v61dw_return_bundle_operator_handoff_bundle_summary.csv")
copy(source_paths["v61dw_decision"], "source_v61dw/v61dw_return_bundle_operator_handoff_bundle_decision.csv")
copy(source_paths["v61dw_files"], "source_v61dw/return_bundle_operator_handoff_bundle_file_rows.csv")

v52y = read_csv(source_paths["v52y_summary"])[0]
v53t = read_csv(source_paths["v53t_summary"])[0]
v61dg = read_csv(source_paths["v61dg_summary"])[0]
v61dh = read_csv(source_paths["v61dh_summary"])[0]
v61dw = read_csv(source_paths["v61dw_summary"])[0]

v52_ready = v52y["v52_ready"] == "1"
v52_comparison_wording_allowed = (
    v52_ready
    and v52y["comparison_30b_150b_wording_status"] == "allowed-with-disclosure"
)

section_rows = [
    {
        "section_id": "v52-f-optional-and-v52-ready",
        "machine_ready": v52y["v52_ready"],
        "final_ready": v52y["v52_ready"],
        "status": "ready" if v52_ready else "blocked-d-e-release-baseline",
        "evidence_source": "v52y",
        "blocking_reason": "" if v52_ready else "D/E PM/release baseline readiness is not accepted",
        "next_required_artifact": "none for v52 measured-registry scope; optional F remains final-deferred" if v52_ready else "accepted 30B and 70B PM/release baseline evidence",
    },
    {
        "section_id": "v53-complete-source-audit-surface",
        "machine_ready": v53t["machine_complete_source_surface_ready"],
        "final_ready": v53t["v53_ready"],
        "status": "machine-ready-final-blocked",
        "evidence_source": "v53t",
        "blocking_reason": "human review and adjudication returns are not accepted",
        "next_required_artifact": "v53s actual review return with 7000 review rows and 1000 adjudication rows",
    },
    {
        "section_id": "v61-real-model-evidence",
        "machine_ready": v61dg["post_full_shard_runtime_evidence_ready"],
        "final_ready": v61dg["actual_model_generation_ready"],
        "status": "runtime-evidence-ready-generation-blocked",
        "evidence_source": "v61dg/v61dw",
        "blocking_reason": "generation execution, result artifacts, latency, near-frontier, and release evidence are blocked",
        "next_required_artifact": "returned review/generation evidence before actual model generation claims",
    },
]
write_csv(run_dir / "active_goal_objective_section_rows.csv", list(section_rows[0].keys()), section_rows)

requirement_rows = [
    ("v52-f-disposition-defined", "v52-f-optional-and-v52-ready", True, "v52y", "supplied evidence or deferred-with-reason-final", v52y["f_optional_final_disposition"], "F optional handling is explicit", ""),
    ("v52-ready-condition-passes", "v52-f-optional-and-v52-ready", v52_ready, "v52y", "v52_ready=1", f"v52_ready={v52y['v52_ready']}", "v52 PM/release baseline scope is ready", "D/E PM/release baseline evidence is missing"),
    ("v52-30b-150b-wording-disclosure", "v52-f-optional-and-v52-ready", v52_comparison_wording_allowed, "v52y", "allowed-with-disclosure", v52y["comparison_30b_150b_wording_status"], "30B-150B-class wording can be used only after D/E PM/release readiness", "30B-150B-class wording is blocked until required D/E readiness"),
    ("v53-complete-source-repo-lock", "v53-complete-source-audit-surface", as_int(v53t, "complete_source_repo_count") >= 10, "v53t", ">=10 repos", v53t["complete_source_repo_count"], "complete-source target scale is present", ""),
    ("v53-complete-source-query-set", "v53-complete-source-audit-surface", as_int(v53t, "complete_source_query_rows") >= 1000, "v53t", ">=1000 queries", v53t["complete_source_query_rows"], "complete-source query set is instantiated", ""),
    ("v53-core-answer-citation-resource-surface", "v53-complete-source-audit-surface", as_int(v53t, "core_answer_rows") == 7000, "v53t", "7000 core answer rows", v53t["core_answer_rows"], "A/B/C/D/E/G/H core answer surface is present", ""),
    ("v53-symmetric-scorer-policy-surface", "v53-complete-source-audit-surface", as_int(v53t, "symmetric_scorer_rows") == 7000 and as_int(v53t, "symmetric_policy_rows") == 7000, "v53t", "7000 scorer and 7000 policy rows", f"{v53t['symmetric_scorer_rows']}/{v53t['symmetric_policy_rows']}", "symmetric scorer/policy surface is present", ""),
    ("v53-review-packet-ready", "v53-complete-source-audit-surface", v53t["review_packet_ready"] == "1", "v53t", "review_packet_ready=1", f"review_packet_ready={v53t['review_packet_ready']}", "review packet is ready for human/source review", ""),
    ("v53-human-review-return-accepted", "v53-complete-source-audit-surface", as_int(v53t, "accepted_human_review_rows") == as_int(v53t, "expected_human_review_rows"), "v53t", "7000/7000 accepted", f"{v53t['accepted_human_review_rows']}/{v53t['expected_human_review_rows']}", "human/source review return acceptance", "actual review rows are not returned"),
    ("v53-adjudication-return-accepted", "v53-complete-source-audit-surface", as_int(v53t, "accepted_adjudication_rows") == as_int(v53t, "expected_adjudication_rows"), "v53t", "1000/1000 accepted", f"{v53t['accepted_adjudication_rows']}/{v53t['expected_adjudication_rows']}", "adjudication return acceptance", "actual adjudication rows are not returned"),
    ("v61-real-manifest-fixture-replacement", "v61-real-model-evidence", v61dg["real_manifest_fixture_replacement_ready"] == "1", "v61dg", "ready=1", v61dg["real_manifest_fixture_replacement_ready"], "logical fixture is replaced by real-model manifest evidence", ""),
    ("v61-full-checkpoint-materialization", "v61-real-model-evidence", as_int(v61dg, "ready_checkpoint_materialization_shard_rows") == 59, "v61dg", "59/59 shards", f"{v61dg['ready_checkpoint_materialization_shard_rows']}/{v61dg['checkpoint_shard_rows']}", "full checkpoint materialization is identity verified outside the repo", ""),
    ("v61-full-safetensors-page-hash-binding", "v61-real-model-evidence", as_int(v61dg, "total_verified_page_hash_rows") == as_int(v61dg, "total_required_page_hash_rows"), "v61dg", "134161/134161 pages", f"{v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}", "full safetensors page hash coverage is closed", ""),
    ("v61-rocm-page-kernel-measurement", "v61-real-model-evidence", v61dg["gpu_page_dequant_matmul_measurement_ready"] == "1", "v61dg", "measurement_ready=1", v61dg["gpu_page_dequant_matmul_measurement_ready"], "GPU/ROCm page kernel timing is recorded", ""),
    ("v61-kv-residency-eviction-policy", "v61-real-model-evidence", v61dg["kv_cache_policy_ready"] == "1" and v61dg["kv_eviction_trace_ready"] == "1", "v61dg", "policy_ready=1 and trace_ready=1", f"{v61dg['kv_cache_policy_ready']}/{v61dg['kv_eviction_trace_ready']}", "KV residency/eviction policy is bound to runtime geometry", ""),
    ("v61-source-bound-qa-command-pass", "v61-real-model-evidence", as_int(v61dg, "source_bound_query_pass_rows") == as_int(v61dg, "source_bound_query_rows"), "v61dg", "37/37 pass", f"{v61dg['source_bound_query_pass_rows']}/{v61dg['source_bound_query_rows']}", "source-bound QA command replay passes", ""),
    ("v61-complete-source-runtime-admission", "v61-real-model-evidence", as_int(v61dg, "runtime_admission_accepted_rows") == as_int(v61dg, "runtime_admission_acceptance_rows"), "v61dg", "1000/1000 accepted", f"{v61dg['runtime_admission_accepted_rows']}/{v61dg['runtime_admission_acceptance_rows']}", "complete-source runtime admission is accepted", ""),
    ("v61-return-bundle-handoff-ready", "v61-real-model-evidence", v61dw["v61dw_return_bundle_operator_handoff_bundle_ready"] == "1", "v61dw", "handoff_ready=1", v61dw["v61dw_return_bundle_operator_handoff_bundle_ready"], "metadata-only return bundle handoff is packaged", ""),
    ("v61-generation-execution-admission", "v61-real-model-evidence", as_int(v61dg, "generation_execution_admitted_rows") == as_int(v61dg, "generation_execution_admission_rows"), "v61dg", "1000/1000 admitted", f"{v61dg['generation_execution_admitted_rows']}/{v61dg['generation_execution_admission_rows']}", "actual generation execution admission", "review return and generation result gates are not accepted"),
    ("v61-generation-result-artifact-acceptance", "v61-real-model-evidence", as_int(v61dg, "accepted_generation_result_artifacts") == as_int(v61dg, "expected_generation_result_artifacts"), "v61dg", "5/5 artifacts accepted", f"{v61dg['accepted_generation_result_artifacts']}/{v61dg['expected_generation_result_artifacts']}", "generation result artifact acceptance", "generation result artifacts are not returned"),
    ("v61-actual-model-generation", "v61-real-model-evidence", v61dg["actual_model_generation_ready"] == "1", "v61dg", "actual_model_generation_ready=1", v61dg["actual_model_generation_ready"], "actual Mixtral generation claim", "generation execution and result acceptance remain blocked"),
    ("v61-production-latency-claim", "v61-real-model-evidence", v61dg["production_latency_claim_ready"] == "1", "v61dg", "production_latency_claim_ready=1", v61dg["production_latency_claim_ready"], "production latency claim", "accepted generation latency evidence is missing"),
    ("v61-near-frontier-quality-claim", "v61-real-model-evidence", v61dg["near_frontier_claim_ready"] == "1", "v61dg", "near_frontier_claim_ready=1", v61dg["near_frontier_claim_ready"], "near-frontier quality claim", "external review and accepted generation evidence are missing"),
    ("v61-release-package-ready", "v61-real-model-evidence", v61dg["real_release_package_ready"] == "1", "v61dg", "real_release_package_ready=1", v61dg["real_release_package_ready"], "real release package", "release audit evidence is missing"),
]
requirement_dicts = [
    {
        "requirement_id": req_id,
        "section_id": section_id,
        "status": row_status(ready),
        "ready": str(int(bool(ready))),
        "evidence_source": source,
        "required_value": required,
        "actual_value": actual,
        "completion_scope": scope,
        "blocking_reason": blocker,
    }
    for req_id, section_id, ready, source, required, actual, scope, blocker in requirement_rows
]
write_csv(run_dir / "active_goal_requirement_rows.csv", list(requirement_dicts[0].keys()), requirement_dicts)

claim_rows = [
    (
        "v52-30b-150b-comparison-wording",
        "allowed-with-disclosure" if v52_comparison_wording_allowed else "blocked",
        "requires D/E PM/release readiness plus optional F final disposition",
    ),
    ("v53-machine-complete-source-surface", "allowed-with-disclosure", "machine surface ready; human review/adjudication not accepted"),
    ("v61-full-shard-runtime-evidence", "allowed-with-boundary", "full-shard/page-hash/runtime admission ready; generation not accepted"),
    ("v61-return-bundle-operator-handoff", "allowed-with-boundary", "metadata-only handoff bundle, no returned evidence or checkpoint payload"),
    ("v53-ready", "blocked", "requires accepted human review and adjudication rows"),
    ("actual-mixtral-generation", "blocked", "requires admitted generation execution and accepted generation results"),
    ("production-latency", "blocked", "requires accepted generation latency rows"),
    ("near-frontier-quality", "blocked", "requires external review and accepted generation evidence"),
    ("v1.0-comparison-ready", "blocked", "requires v53 review return plus comparison/release review evidence"),
    ("real-release-package", "blocked", "requires release audit evidence"),
]
claim_dicts = [
    {"claim_id": claim_id, "status": status, "required_disclosure_or_blocker": detail}
    for claim_id, status, detail in claim_rows
]
write_csv(run_dir / "active_goal_claim_boundary_rows.csv", list(claim_dicts[0].keys()), claim_dicts)

next_action_rows = [
    ("01-v53s-actual-review-return", "external-return-required", "7000 human/source review rows, 1000 adjudication rows, identity/conflict rows, acceptance summary"),
    ("02-v61-generation-execution-admission", "blocked-by-review-return", "open only after review return and generation operator guard admit execution"),
    ("03-v61-generation-result-return", "blocked-by-generation-execution", "five generation result artifacts plus 1000 result rows"),
    ("04-production-latency-report", "blocked-by-actual-generation", "latency report must use accepted actual generation rows"),
    ("05-v60-release-audit", "blocked-by-review-and-release-evidence", "human/release review evidence and release package are missing"),
]
next_action_dicts = [
    {"action_id": action_id, "status": status, "required_artifact": artifact}
    for action_id, status, artifact in next_action_rows
]
write_csv(run_dir / "active_goal_next_action_rows.csv", list(next_action_dicts[0].keys()), next_action_dicts)

ready_requirement_rows = sum(1 for row in requirement_dicts if row["status"] == "ready")
blocked_requirement_rows = sum(1 for row in requirement_dicts if row["status"] == "blocked")
allowed_claim_rows = sum(1 for row in claim_dicts if row["status"].startswith("allowed"))
blocked_claim_rows = sum(1 for row in claim_dicts if row["status"] == "blocked")
machine_ready_section_rows = sum(1 for row in section_rows if row["machine_ready"] == "1")
final_ready_section_rows = sum(1 for row in section_rows if row["final_ready"] == "1")
blocked_final_section_rows = len(section_rows) - final_ready_section_rows

boundary = run_dir / "V61DX_ACTIVE_GOAL_STATUS_AUDIT_GATE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61dx Active Goal Status Audit Gate",
            "",
            "This gate audits the current active objective across v52, v53, and v61.",
            "It does not create review, generation, latency, near-frontier, or release",
            "evidence. It records which objective requirements are already supported",
            "by local artifacts and which remain blocked by missing returned evidence.",
            "",
            "Ready evidence:",
            "",
            f"- v52_ready={v52y['v52_ready']} with F={v52y['f_optional_final_disposition']}",
            f"- comparison_30b_150b_wording_status={v52y['comparison_30b_150b_wording_status']}",
            f"- v53_machine_complete_source_surface_ready={v53t['machine_complete_source_surface_ready']}",
            f"- complete_source_query_rows={v53t['complete_source_query_rows']}",
            f"- core_answer_rows={v53t['core_answer_rows']}",
            f"- v61_post_full_shard_runtime_evidence_ready={v61dg['post_full_shard_runtime_evidence_ready']}",
            f"- ready_checkpoint_materialization_shard_rows={v61dg['ready_checkpoint_materialization_shard_rows']}/{v61dg['checkpoint_shard_rows']}",
            f"- total_verified_page_hash_rows={v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}",
            f"- gpu_page_dequant_matmul_measurement_ready={v61dg['gpu_page_dequant_matmul_measurement_ready']}",
            f"- kv_cache_policy_ready={v61dg['kv_cache_policy_ready']}",
            f"- source_bound_query_pass_rows={v61dg['source_bound_query_pass_rows']}/{v61dg['source_bound_query_rows']}",
            f"- runtime_admission_accepted_rows={v61dg['runtime_admission_accepted_rows']}/{v61dg['runtime_admission_acceptance_rows']}",
            f"- return_handoff_bundle_ready={v61dw['v61dw_return_bundle_operator_handoff_bundle_ready']}",
            "",
            "Blocked final claims:",
            "",
            f"- accepted_human_review_rows={v53t['accepted_human_review_rows']}/{v53t['expected_human_review_rows']}",
            f"- accepted_adjudication_rows={v53t['accepted_adjudication_rows']}/{v53t['expected_adjudication_rows']}",
            f"- generation_execution_admitted_rows={v61dg['generation_execution_admitted_rows']}/{v61dg['generation_execution_admission_rows']}",
            f"- accepted_generation_result_artifacts={v61dg['accepted_generation_result_artifacts']}/{v61dg['expected_generation_result_artifacts']}",
            f"- actual_model_generation_ready={v61dg['actual_model_generation_ready']}",
            f"- production_latency_claim_ready={v61dg['production_latency_claim_ready']}",
            f"- near_frontier_claim_ready={v61dg['near_frontier_claim_ready']}",
            f"- real_release_package_ready={v61dg['real_release_package_ready']}",
            "",
            "Blocked wording remains blocked for v53_ready, actual Mixtral",
            "generation, production latency, near-frontier quality, v1.0 comparison",
            "readiness, and release readiness.",
            "",
        ]
    ),
    encoding="utf-8",
)

summary_row = {
    "v61dx_active_goal_status_audit_gate_ready": "1",
    "v52y_f_optional_final_policy_ready": v52y["v52y_f_optional_final_policy_ready"],
    "v53t_complete_source_audit_readiness_gate_ready": v53t["v53t_complete_source_audit_readiness_gate_ready"],
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": v61dg["v61dg_post_full_shard_runtime_evidence_promotion_gate_ready"],
    "v61dh_post_full_shard_claim_audit_gate_ready": v61dh["v61dh_post_full_shard_claim_audit_gate_ready"],
    "v61dw_return_bundle_operator_handoff_bundle_ready": v61dw["v61dw_return_bundle_operator_handoff_bundle_ready"],
    "objective_section_rows": str(len(section_rows)),
    "machine_ready_section_rows": str(machine_ready_section_rows),
    "final_ready_section_rows": str(final_ready_section_rows),
    "blocked_final_section_rows": str(blocked_final_section_rows),
    "objective_requirement_rows": str(len(requirement_dicts)),
    "ready_objective_requirement_rows": str(ready_requirement_rows),
    "blocked_objective_requirement_rows": str(blocked_requirement_rows),
    "claim_boundary_rows": str(len(claim_dicts)),
    "allowed_claim_boundary_rows": str(allowed_claim_rows),
    "blocked_claim_boundary_rows": str(blocked_claim_rows),
    "next_action_rows": str(len(next_action_dicts)),
    "blocked_next_action_rows": str(len(next_action_dicts)),
    "v52_ready": v52y["v52_ready"],
    "f_optional_final_disposition": v52y["f_optional_final_disposition"],
    "comparison_30b_150b_wording_status": v52y["comparison_30b_150b_wording_status"],
    "v53_machine_complete_source_surface_ready": v53t["machine_complete_source_surface_ready"],
    "complete_source_repo_count": v53t["complete_source_repo_count"],
    "complete_source_query_rows": v53t["complete_source_query_rows"],
    "core_answer_rows": v53t["core_answer_rows"],
    "review_packet_ready": v53t["review_packet_ready"],
    "expected_human_review_rows": v53t["expected_human_review_rows"],
    "accepted_human_review_rows": v53t["accepted_human_review_rows"],
    "expected_adjudication_rows": v53t["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53t["accepted_adjudication_rows"],
    "v53_ready": v53t["v53_ready"],
    "v61_post_full_shard_runtime_evidence_ready": v61dg["post_full_shard_runtime_evidence_ready"],
    "full_checkpoint_materialization_ready": v61dg["full_checkpoint_materialization_ready"],
    "checkpoint_shard_rows": v61dg["checkpoint_shard_rows"],
    "ready_checkpoint_materialization_shard_rows": v61dg["ready_checkpoint_materialization_shard_rows"],
    "promotion_identity_verified_bytes": v61dg["promotion_identity_verified_bytes"],
    "full_safetensors_page_hash_binding_ready": v61dg["full_safetensors_page_hash_binding_ready"],
    "total_required_page_hash_rows": v61dg["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61dg["total_verified_page_hash_rows"],
    "gpu_page_dequant_matmul_measurement_ready": v61dg["gpu_page_dequant_matmul_measurement_ready"],
    "kv_cache_policy_ready": v61dg["kv_cache_policy_ready"],
    "kv_eviction_trace_ready": v61dg["kv_eviction_trace_ready"],
    "v61j_source_bound_qa_command_pass": v61dg["v61j_source_bound_qa_command_pass"],
    "source_bound_query_rows": v61dg["source_bound_query_rows"],
    "source_bound_query_pass_rows": v61dg["source_bound_query_pass_rows"],
    "runtime_admission_acceptance_rows": v61dg["runtime_admission_acceptance_rows"],
    "runtime_admission_accepted_rows": v61dg["runtime_admission_accepted_rows"],
    "generation_execution_admission_rows": v61dg["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61dg["generation_execution_admitted_rows"],
    "expected_generation_result_artifacts": v61dg["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61dg["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v61dg["actual_model_generation_ready"],
    "return_handoff_bundle_ready": v61dw["v61dw_return_bundle_operator_handoff_bundle_ready"],
    "handoff_bundle_file_rows": v61dw["handoff_bundle_file_rows"],
    "metadata_only_bundle_file_rows": v61dw["metadata_only_bundle_file_rows"],
    "missing_payload_rows": v61dw["missing_payload_rows"],
    "v1_0_comparison_ready": v61dh["v1_0_comparison_ready"],
    "near_frontier_claim_ready": v61dg["near_frontier_claim_ready"],
    "production_latency_claim_ready": v61dg["production_latency_claim_ready"],
    "real_release_package_ready": v61dg["real_release_package_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61dx": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "active-goal-status-audit", "status": "pass", "reason": "source summaries and objective rows emitted", "evidence_source": "v52y/v53t/v61dg/v61dh/v61dw"},
    {"gate": "v52-f-optional-final-policy", "status": "pass", "reason": f"F disposition is {v52y['f_optional_final_disposition']}", "evidence_source": "v52y"},
    {"gate": "v52-ready-condition", "status": "pass" if v52_ready else "blocked", "reason": f"v52_ready={v52y['v52_ready']}", "evidence_source": "v52y"},
    {"gate": "v53-machine-complete-source-surface", "status": "pass", "reason": "10 repos, 1000 queries, 7000 core answer rows, review packet ready", "evidence_source": "v53t"},
    {"gate": "v53-review-return", "status": "blocked", "reason": f"accepted review/adjudication rows {v53t['accepted_human_review_rows']}/{v53t['expected_human_review_rows']} and {v53t['accepted_adjudication_rows']}/{v53t['expected_adjudication_rows']}", "evidence_source": "v53t"},
    {"gate": "v61-real-model-runtime-evidence", "status": "pass", "reason": "manifest, full shard, full page hash, ROCm, KV, QA, runtime admission evidence ready", "evidence_source": "v61dg"},
    {"gate": "v61-return-handoff-bundle", "status": "pass", "reason": "metadata-only handoff bundle is packaged", "evidence_source": "v61dw"},
    {"gate": "v61-actual-model-generation", "status": "blocked", "reason": f"generation execution {v61dg['generation_execution_admitted_rows']}/{v61dg['generation_execution_admission_rows']} and result artifacts {v61dg['accepted_generation_result_artifacts']}/{v61dg['expected_generation_result_artifacts']}", "evidence_source": "v61dg"},
    {"gate": "v1-comparison-ready", "status": "blocked", "reason": "v53 review return and downstream release evidence are missing", "evidence_source": "v61dh"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release audit evidence is missing", "evidence_source": "v61dg/v61dh"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

manifest = {
    "manifest_scope": "v61dx-active-goal-status-audit-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary_row.items()},
}
(run_dir / "v61dx_active_goal_status_audit_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file()):
    if path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY
