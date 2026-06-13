#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61di_post_claim_generation_unblock_audit_gate"
RUN_ID="${V61DI_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61di_post_claim_generation_unblock_audit_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dh_post_full_shard_claim_audit_gate.sh" >/dev/null
V53AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
V61DF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61df_external_review_generation_return_operator_packet.sh" >/dev/null

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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61dh_summary": results / "v61dh_post_full_shard_claim_audit_gate_summary.csv",
    "v61dh_decision": results / "v61dh_post_full_shard_claim_audit_gate_decision.csv",
    "v61dh_claims": results / "v61dh_post_full_shard_claim_audit_gate" / "audit_001" / "post_full_shard_claim_audit_rows.csv",
    "v61dh_invariants": results / "v61dh_post_full_shard_claim_audit_gate" / "audit_001" / "post_full_shard_claim_invariant_rows.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_decision": results / "v53am_complete_source_return_acceptance_replay_decision.csv",
    "v53am_steps": results / "v53am_complete_source_return_acceptance_replay" / "replay_001" / "return_acceptance_replay_step_rows.csv",
    "v53am_commands": results / "v53am_complete_source_return_acceptance_replay" / "replay_001" / "return_acceptance_replay_command_rows.csv",
    "v61df_summary": results / "v61df_external_review_generation_return_operator_packet_summary.csv",
    "v61df_decision": results / "v61df_external_review_generation_return_operator_packet_decision.csv",
    "v61df_stages": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "external_return_operator_stage_rows.csv",
    "v61df_requirements": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "external_return_operator_requirement_rows.csv",
    "v61df_review_artifacts": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "operator_packet" / "REVIEW_RETURN_REQUIRED_ARTIFACTS.csv",
    "v61df_generation_artifacts": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "operator_packet" / "GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61di source {key}: {path}")

copy(sources["v61dh_summary"], "source_v61dh/v61dh_post_full_shard_claim_audit_gate_summary.csv")
copy(sources["v61dh_decision"], "source_v61dh/v61dh_post_full_shard_claim_audit_gate_decision.csv")
copy(sources["v61dh_claims"], "source_v61dh/post_full_shard_claim_audit_rows.csv")
copy(sources["v61dh_invariants"], "source_v61dh/post_full_shard_claim_invariant_rows.csv")
copy(sources["v53am_summary"], "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv")
copy(sources["v53am_decision"], "source_v53am/v53am_complete_source_return_acceptance_replay_decision.csv")
copy(sources["v53am_steps"], "source_v53am/return_acceptance_replay_step_rows.csv")
copy(sources["v53am_commands"], "source_v53am/return_acceptance_replay_command_rows.csv")
copy(sources["v61df_summary"], "source_v61df/v61df_external_review_generation_return_operator_packet_summary.csv")
copy(sources["v61df_decision"], "source_v61df/v61df_external_review_generation_return_operator_packet_decision.csv")
copy(sources["v61df_stages"], "source_v61df/external_return_operator_stage_rows.csv")
copy(sources["v61df_requirements"], "source_v61df/external_return_operator_requirement_rows.csv")
copy(sources["v61df_review_artifacts"], "source_v61df/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv")
copy(sources["v61df_generation_artifacts"], "source_v61df/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv")

v61dh = read_csv(sources["v61dh_summary"])[0]
v53am = read_csv(sources["v53am_summary"])[0]
v61df = read_csv(sources["v61df_summary"])[0]

for field, row in [
    ("v61dh_post_full_shard_claim_audit_gate_ready", v61dh),
    ("v53am_complete_source_return_acceptance_replay_ready", v53am),
    ("v61df_external_review_generation_return_operator_packet_ready", v61df),
]:
    if row.get(field) != "1":
        raise SystemExit(f"v61di requires {field}=1")

stage_rows = [
    {
        "unblock_stage_id": "01-v52-f-optional-final",
        "source_gate": "v61dh/v52y",
        "status": "ready" if v61dh["v52_ready"] == "1" else "blocked",
        "actual_value": f"v52_ready={v61dh['v52_ready']}; f_optional_final_disposition={v61dh['f_optional_final_disposition']}",
        "required_next_evidence": "none for default F-final posture",
        "blocking_reason": "ready",
    },
    {
        "unblock_stage_id": "02-v53-machine-surface",
        "source_gate": "v61dh/v53t",
        "status": "ready" if v61dh["v53_machine_complete_source_surface_ready"] == "1" else "blocked",
        "actual_value": f"repos={v61dh['complete_source_repo_count']}; queries={v61dh['complete_source_query_rows']}; core_answer_rows={v61dh['core_answer_rows']}",
        "required_next_evidence": "human/source review return",
        "blocking_reason": "ready",
    },
    {
        "unblock_stage_id": "03-v61-runtime-evidence",
        "source_gate": "v61dh/v61dg",
        "status": "ready" if v61dh["v61_post_full_shard_runtime_evidence_ready"] == "1" else "blocked",
        "actual_value": f"full_checkpoint={v61dh['full_checkpoint_materialization_ready']}; page_hash={v61dh['full_safetensors_page_hash_binding_ready']}; runtime_admission={v61dh['runtime_admission_accepted_rows']}",
        "required_next_evidence": "review/generation returns",
        "blocking_reason": "ready",
    },
    {
        "unblock_stage_id": "04-claim-posture-audited",
        "source_gate": "v61dh",
        "status": "ready" if v61dh["claim_audit_ready"] == "1" else "blocked",
        "actual_value": f"allowed_claim_rows={v61dh['allowed_claim_rows']}; blocked_claim_rows={v61dh['blocked_claim_rows']}",
        "required_next_evidence": "accepted returned evidence before blocked claims can open",
        "blocking_reason": "ready",
    },
    {
        "unblock_stage_id": "05-external-return-packet-ready",
        "source_gate": "v61df",
        "status": "ready" if v61df["ready_operator_packet_file_rows"] == v61df["operator_packet_file_rows"] else "blocked",
        "actual_value": f"operator_packet_file_rows={v61df['ready_operator_packet_file_rows']}/{v61df['operator_packet_file_rows']}",
        "required_next_evidence": "operators fill review return artifacts first",
        "blocking_reason": "ready",
    },
    {
        "unblock_stage_id": "06-return-acceptance-replay-surface",
        "source_gate": "v53am",
        "status": "ready" if v53am["return_acceptance_replay_ready"] == "1" else "blocked",
        "actual_value": f"ready_replay_step_rows={v53am['ready_replay_step_rows']}; blocked_replay_step_rows={v53am['blocked_replay_step_rows']}",
        "required_next_evidence": "returned bundle preflight pass",
        "blocking_reason": "ready",
    },
    {
        "unblock_stage_id": "07-return-bundle-preflight-pass",
        "source_gate": "v53am/v53al",
        "status": "ready" if v53am["return_bundle_preflight_pass"] == "1" else "blocked",
        "actual_value": f"preflight_pass_rows={v53am['preflight_pass_rows']}/{v53am['preflight_rows']}",
        "required_next_evidence": "81/81 final return artifacts present, non-empty, non-template",
        "blocking_reason": "return bundle preflight has not passed",
    },
    {
        "unblock_stage_id": "08-dispatch-and-review-chunk-returns",
        "source_gate": "v53am/v53ad/v53x",
        "status": "ready" if v53am["accepted_dispatch_receipt_rows"] == v53am["dispatch_receipt_template_rows"] and v53am["accepted_chunk_return_artifact_rows"] == v53am["review_chunk_return_artifact_rows"] else "blocked",
        "actual_value": f"dispatch={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}; chunk_artifacts={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}",
        "required_next_evidence": "dispatch receipts and review chunk returns",
        "blocking_reason": "dispatch/chunk returns are absent",
    },
    {
        "unblock_stage_id": "09-aggregate-review-and-adjudication",
        "source_gate": "v53am/v53y",
        "status": "ready" if v53am["review_return_ready"] == "1" and v53am["v53_ready"] == "1" else "blocked",
        "actual_value": f"answer_review={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}; adjudication={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}; v53_ready={v53am['v53_ready']}",
        "required_next_evidence": "accepted human review rows, adjudication rows, reviewer identity/conflict, acceptance summary",
        "blocking_reason": "aggregate review return is not accepted",
    },
    {
        "unblock_stage_id": "10-generation-execution-admission",
        "source_gate": "v53am/v61de",
        "status": "ready" if v53am["generation_execution_admitted_rows"] == v53am["generation_execution_admission_rows"] and v53am["generation_execution_admission_rows"] != "0" else "blocked",
        "actual_value": f"generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}",
        "required_next_evidence": "review return accepted, then guarded generation execution admitted",
        "blocking_reason": "generation execution admission remains closed",
    },
    {
        "unblock_stage_id": "11-generation-result-acceptance",
        "source_gate": "v53am/v61bt/v61cu",
        "status": "ready" if v53am["generation_result_accepted_rows"] == v53am["generation_result_acceptance_rows"] and v53am["generation_result_acceptance_rows"] != "0" else "blocked",
        "actual_value": f"generation_artifacts={v53am['accepted_generation_result_artifacts']}/{v53am['expected_generation_result_artifacts']}; generation_result_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}",
        "required_next_evidence": "accepted answer/citation/abstain/latency/acceptance result artifacts",
        "blocking_reason": "generation result artifacts are not accepted",
    },
    {
        "unblock_stage_id": "12-actual-generation-and-v1-claims",
        "source_gate": "v61dh/v53am",
        "status": "ready" if v53am["actual_model_generation_ready"] == "1" and v61dh["v1_0_comparison_ready"] == "1" else "blocked",
        "actual_value": f"actual_model_generation_ready={v53am['actual_model_generation_ready']}; v1_0_comparison_ready={v61dh['v1_0_comparison_ready']}; release={v61dh['real_release_package_ready']}",
        "required_next_evidence": "actual generation accepted, production latency, near-frontier quality, release review",
        "blocking_reason": "actual generation, v1.0 comparison, and release remain unproven",
    },
]
write_csv(run_dir / "post_claim_generation_unblock_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(row["status"] == "ready" for row in stage_rows)
blocked_stage_rows = len(stage_rows) - ready_stage_rows

command_rows = [
    {
        "command_id": "01-verify-external-return-packet",
        "ready_to_run_now": "1",
        "command": "results/v61df_external_review_generation_return_operator_packet/packet_001/operator_packet/VERIFY_EXTERNAL_RETURN_PACKET.sh",
        "expected_transition": "operator packet shape remains valid",
    },
    {
        "command_id": "02-preflight-return-bundle",
        "ready_to_run_now": "1",
        "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh",
        "expected_transition": "return_bundle_preflight_pass=1",
    },
    {
        "command_id": "03-intake-dispatch-receipts",
        "ready_to_run_now": "0",
        "command": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
        "expected_transition": "accepted_dispatch_receipt_rows=21",
    },
    {
        "command_id": "04-intake-review-chunks",
        "ready_to_run_now": "0",
        "command": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle/review_chunk_returns V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
        "expected_transition": "accepted_chunk_return_artifact_rows=50",
    },
    {
        "command_id": "05-refresh-aggregate-review",
        "ready_to_run_now": "0",
        "command": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "expected_transition": "answer_review_accepted_rows=7000 and accepted_adjudication_rows=1000",
    },
    {
        "command_id": "06-refresh-v53-v61-rendezvous",
        "ready_to_run_now": "0",
        "command": "V53AE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53AE_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh",
        "expected_transition": "v53 review return propagates into post-full-shard rendezvous",
    },
    {
        "command_id": "07-refresh-post-review-generation",
        "ready_to_run_now": "0",
        "command": "V61DE_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "expected_transition": "generation_execution_admitted_rows can be rechecked",
    },
    {
        "command_id": "08-intake-generation-results",
        "ready_to_run_now": "0",
        "command": "V61DE_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "expected_transition": "generation_result_accepted_rows=1000",
    },
    {
        "command_id": "09-rerun-claim-audit",
        "ready_to_run_now": "0",
        "command": "V61DI_REUSE_EXISTING=0 ./experiments/run_v61di_post_claim_generation_unblock_audit_gate.sh",
        "expected_transition": "recompute actual-generation and claim boundaries after returns",
    },
]
write_csv(run_dir / "post_claim_generation_unblock_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)

runtime_gap_rows = [
    {"gap": row["unblock_stage_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61di_post_claim_generation_unblock_audit_gate_metrics",
    "v61dh_post_full_shard_claim_audit_gate_ready": v61dh["v61dh_post_full_shard_claim_audit_gate_ready"],
    "v53am_complete_source_return_acceptance_replay_ready": v53am["v53am_complete_source_return_acceptance_replay_ready"],
    "v61df_external_review_generation_return_operator_packet_ready": v61df["v61df_external_review_generation_return_operator_packet_ready"],
    "source_gate_rows": "3",
    "unblock_audit_ready": "1",
    "unblock_stage_rows": str(len(stage_rows)),
    "ready_unblock_stage_rows": str(ready_stage_rows),
    "blocked_unblock_stage_rows": str(blocked_stage_rows),
    "unblock_command_rows": str(len(command_rows)),
    "ready_unblock_command_rows": str(ready_command_rows),
    "claim_audit_ready": v61dh["claim_audit_ready"],
    "allowed_claim_rows": v61dh["allowed_claim_rows"],
    "blocked_claim_rows": v61dh["blocked_claim_rows"],
    "v52_ready": v61dh["v52_ready"],
    "comparison_30b_150b_wording_status": v61dh["comparison_30b_150b_wording_status"],
    "v53_machine_complete_source_surface_ready": v61dh["v53_machine_complete_source_surface_ready"],
    "complete_source_repo_count": v61dh["complete_source_repo_count"],
    "complete_source_query_rows": v61dh["complete_source_query_rows"],
    "core_answer_rows": v61dh["core_answer_rows"],
    "return_acceptance_replay_ready": v53am["return_acceptance_replay_ready"],
    "return_acceptance_replay_closed": v53am["return_acceptance_replay_closed"],
    "ready_replay_step_rows": v53am["ready_replay_step_rows"],
    "blocked_replay_step_rows": v53am["blocked_replay_step_rows"],
    "return_bundle_preflight_pass": v53am["return_bundle_preflight_pass"],
    "preflight_pass_rows": v53am["preflight_pass_rows"],
    "preflight_rows": v53am["preflight_rows"],
    "accepted_dispatch_receipt_rows": v53am["accepted_dispatch_receipt_rows"],
    "dispatch_receipt_template_rows": v53am["dispatch_receipt_template_rows"],
    "accepted_chunk_return_artifact_rows": v53am["accepted_chunk_return_artifact_rows"],
    "review_chunk_return_artifact_rows": v53am["review_chunk_return_artifact_rows"],
    "accepted_human_review_rows": v61dh["accepted_human_review_rows"],
    "expected_human_review_rows": v61dh["expected_human_review_rows"],
    "accepted_adjudication_rows": v61dh["accepted_adjudication_rows"],
    "expected_adjudication_rows": v61dh["expected_adjudication_rows"],
    "review_return_ready": v53am["review_return_ready"],
    "v53_ready": v53am["v53_ready"],
    "v61_post_full_shard_runtime_evidence_ready": v61dh["v61_post_full_shard_runtime_evidence_ready"],
    "full_checkpoint_materialization_ready": v61dh["full_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61dh["full_safetensors_page_hash_binding_ready"],
    "runtime_admission_accepted_rows": v61dh["runtime_admission_accepted_rows"],
    "operator_packet_ready": v61df["v61df_external_review_generation_return_operator_packet_ready"],
    "operator_packet_file_rows": v61df["operator_packet_file_rows"],
    "ready_operator_packet_file_rows": v61df["ready_operator_packet_file_rows"],
    "ready_operator_stage_rows": v61df["ready_operator_stage_rows"],
    "blocked_operator_stage_rows": v61df["blocked_operator_stage_rows"],
    "review_return_required_artifacts": v61df["review_return_required_artifacts"],
    "generation_result_required_artifacts": v61df["generation_result_required_artifacts"],
    "generation_execution_admission_rows": v53am["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v53am["generation_execution_admitted_rows"],
    "expected_generation_result_artifacts": v53am["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v53am["accepted_generation_result_artifacts"],
    "generation_result_acceptance_rows": v53am["generation_result_acceptance_rows"],
    "generation_result_accepted_rows": v53am["generation_result_accepted_rows"],
    "actual_model_generation_ready": v53am["actual_model_generation_ready"],
    "v1_0_comparison_ready": v61dh["v1_0_comparison_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "generation_unblock_closure_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61di": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_claim_generation_unblock_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61di_post_claim_generation_unblock_audit_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-claim-audit", "status": "pass", "reason": "v61dh claim audit is ready"},
    {"gate": "source-return-replay", "status": "pass", "reason": "v53am return replay surface is ready"},
    {"gate": "source-external-return-packet", "status": "pass", "reason": "v61df operator packet is ready"},
    {"gate": "full-shard-runtime-evidence", "status": "pass", "reason": "full checkpoint, page hash, and runtime admission are ready"},
    {"gate": "return-bundle-preflight-pass", "status": "blocked", "reason": "return_bundle_preflight_pass=0"},
    {"gate": "v53-ready", "status": "blocked", "reason": "accepted human review/adjudication rows are absent"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": "generation_execution_admitted_rows=0/1000"},
    {"gate": "generation-result-accepted", "status": "blocked", "reason": "generation result artifacts and rows are absent"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "v1-comparison-ready", "status": "blocked", "reason": "v1_0_comparison_ready=0"},
    {"gate": "real-release-package", "status": "blocked", "reason": "real_release_package_ready=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61di Post-Claim Generation Unblock Audit Gate

This gate combines the v61dh claim audit, v53am return acceptance replay, and
v61df external return operator packet into one post-full-shard generation
unblock audit. It does not create review rows, generation rows, latency rows, or
release evidence.

Evidence emitted:

- unblock_stage_rows={len(stage_rows)}
- ready_unblock_stage_rows={ready_stage_rows}
- blocked_unblock_stage_rows={blocked_stage_rows}
- unblock_command_rows={len(command_rows)}
- ready_unblock_command_rows={ready_command_rows}
- claim_audit_ready={v61dh['claim_audit_ready']}
- allowed_claim_rows={v61dh['allowed_claim_rows']}
- blocked_claim_rows={v61dh['blocked_claim_rows']}
- return_acceptance_replay_ready={v53am['return_acceptance_replay_ready']}
- return_acceptance_replay_closed={v53am['return_acceptance_replay_closed']}
- operator_packet_file_rows={v61df['ready_operator_packet_file_rows']}/{v61df['operator_packet_file_rows']}
- return_bundle_preflight_pass={v53am['return_bundle_preflight_pass']}
- preflight_pass_rows={v53am['preflight_pass_rows']}/{v53am['preflight_rows']}
- accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}
- accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}
- accepted_human_review_rows={v61dh['accepted_human_review_rows']}/{v61dh['expected_human_review_rows']}
- accepted_adjudication_rows={v61dh['accepted_adjudication_rows']}/{v61dh['expected_adjudication_rows']}
- runtime_admission_accepted_rows={v61dh['runtime_admission_accepted_rows']}
- generation_execution_admitted_rows={v53am['generation_execution_admitted_rows']}/{v53am['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={v53am['accepted_generation_result_artifacts']}/{v53am['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}
- actual_model_generation_ready={v53am['actual_model_generation_ready']}
- v1_0_comparison_ready={v61dh['v1_0_comparison_ready']}
- real_release_package_ready=0
- checkpoint_payload_bytes_downloaded_by_v61di=0

Allowed wording: post-full-shard generation unblock audit is ready and names
the exact remaining returned-evidence blockers.
Blocked wording: returned review evidence accepted, generation execution
admitted, actual generation, v1.0 comparison, production latency,
near-frontier quality, or release readiness.
"""
(run_dir / "V61DI_POST_CLAIM_GENERATION_UNBLOCK_AUDIT_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61di-post-claim-generation-unblock-audit-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61di_post_claim_generation_unblock_audit_gate_ready": 1,
    "unblock_stage_rows": len(stage_rows),
    "ready_unblock_stage_rows": ready_stage_rows,
    "blocked_unblock_stage_rows": blocked_stage_rows,
    "claim_audit_ready": as_int(v61dh, "claim_audit_ready"),
    "return_acceptance_replay_ready": as_int(v53am, "return_acceptance_replay_ready"),
    "return_acceptance_replay_closed": as_int(v53am, "return_acceptance_replay_closed"),
    "operator_packet_ready": as_int(v61df, "v61df_external_review_generation_return_operator_packet_ready"),
    "v53_ready": as_int(v53am, "v53_ready"),
    "actual_model_generation_ready": as_int(v53am, "actual_model_generation_ready"),
    "v1_0_comparison_ready": as_int(v61dh, "v1_0_comparison_ready"),
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61di_post_claim_generation_unblock_audit_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61di_post_claim_generation_unblock_audit_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
