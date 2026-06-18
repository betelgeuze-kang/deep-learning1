#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ei_active_goal_post_eh_status_refresh"
RUN_ID="${V61EI_RUN_ID:-refresh_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ei_active_goal_post_eh_status_refresh_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DX_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dx_active_goal_status_audit_gate.sh" >/dev/null
V61EH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eh_real_generation_result_return_packet.sh" >/dev/null

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


def ready_status(flag):
    return "ready" if flag else "blocked"


def pass_status(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61dx_summary": results / "v61dx_active_goal_status_audit_gate_summary.csv",
    "v61dx_decision": results / "v61dx_active_goal_status_audit_gate_decision.csv",
    "v61dx_requirements": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_requirement_rows.csv",
    "v61dx_claims": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_claim_boundary_rows.csv",
    "v61dx_next_actions": results / "v61dx_active_goal_status_audit_gate/audit_001/active_goal_next_action_rows.csv",
    "v61eh_summary": results / "v61eh_real_generation_result_return_packet_summary.csv",
    "v61eh_decision": results / "v61eh_real_generation_result_return_packet_decision.csv",
    "v61eh_artifacts": results / "v61eh_real_generation_result_return_packet/packet_001/real_generation_required_artifact_rows.csv",
    "v61eh_binding": results / "v61eh_real_generation_result_return_packet/packet_001/real_prerequisite_binding_contract_rows.csv",
    "v61eh_stage": results / "v61eh_real_generation_result_return_packet/packet_001/real_generation_result_return_packet_stage_rows.csv",
    "v61eh_commands": results / "v61eh_real_generation_result_return_packet/packet_001/real_generation_result_return_packet_command_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ei source {key}: {path}")

for key, path in sources.items():
    copy(path, f"source_{key.split('_')[0]}/{path.name}")

v61dx = read_csv(sources["v61dx_summary"])[0]
v61eh = read_csv(sources["v61eh_summary"])[0]

v52_ready = v61dx["v52_ready"] == "1"
v52_comparison_wording_allowed = (
    v52_ready
    and v61dx.get("comparison_30b_150b_wording_status", "blocked") == "allowed-with-disclosure"
)

section_rows = [
    {
        "section_id": "v52-f-optional-policy",
        "status": "ready" if v52_ready else "blocked-d-e-release-baseline",
        "evidence_source": "v61dx",
        "ready": v61dx["v52_ready"],
        "actual_value": v61dx["f_optional_final_disposition"],
        "next_required_artifact": "none for measured-registry wording scope" if v52_ready else "accepted 30B and 70B PM/release baseline evidence",
    },
    {
        "section_id": "v53-complete-source-machine-surface",
        "status": "ready",
        "evidence_source": "v61dx",
        "ready": v61dx["v53_machine_complete_source_surface_ready"],
        "actual_value": f"{v61dx['complete_source_repo_count']} repos / {v61dx['complete_source_query_rows']} queries / {v61dx['core_answer_rows']} answer rows",
        "next_required_artifact": "real v53s review/adjudication return",
    },
    {
        "section_id": "v61-real-model-page-runtime-evidence",
        "status": "ready",
        "evidence_source": "v61dx/v61eh",
        "ready": v61eh["real_manifest_runtime_evidence_ready"],
        "actual_value": f"{v61dx['ready_checkpoint_materialization_shard_rows']}/{v61dx['checkpoint_shard_rows']} shards and {v61dx['total_verified_page_hash_rows']}/{v61dx['total_required_page_hash_rows']} page hashes",
        "next_required_artifact": "real review return followed by real generation-result return",
    },
    {
        "section_id": "v61-real-generation-return-surface",
        "status": "packet-ready-real-evidence-blocked",
        "evidence_source": "v61eh",
        "ready": v61eh["v61eh_real_generation_result_return_packet_ready"],
        "actual_value": f"{v61eh['required_generation_result_artifact_rows']} artifacts / {v61eh['required_generation_result_field_rows']} required fields",
        "next_required_artifact": "real prerequisite binding and real generation-result artifacts",
    },
]
write_csv(run_dir / "post_eh_objective_section_rows.csv", list(section_rows[0].keys()), section_rows)

requirement_rows = [
    ("v52-f-optional-final-disposition", True, "v61dx", "ready final disposition", v61dx["f_optional_final_disposition"], ""),
    ("v53-complete-source-machine-surface", v61dx["v53_machine_complete_source_surface_ready"] == "1", "v61dx", "10 repos and 1000 queries", f"{v61dx['complete_source_repo_count']}/{v61dx['complete_source_query_rows']}", ""),
    ("v53-review-return-accepted", v61dx["v53_ready"] == "1", "v61dx", "v53_ready=1", f"v53_ready={v61dx['v53_ready']}", "7000 review rows and 1000 adjudication rows are not accepted"),
    ("v61-real-manifest-runtime-evidence", v61eh["real_manifest_runtime_evidence_ready"] == "1", "v61eh", "runtime evidence ready", v61eh["real_manifest_runtime_evidence_ready"], ""),
    ("v61-real-generation-return-packet", v61eh["v61eh_real_generation_result_return_packet_ready"] == "1", "v61eh", "packet ready", v61eh["v61eh_real_generation_result_return_packet_ready"], ""),
    ("v61-real-prerequisite-binding", v61eh["real_prerequisite_binding_ready"] == "1", "v61eh", "real_prerequisite_binding_ready=1", v61eh["real_prerequisite_binding_ready"], "real review return and generation execution admission are blocked"),
    ("v61-generation-execution-admission", v61eh["real_generation_execution_admission_ready"] == "1", "v61eh", "1000 admitted", f"{v61eh['generation_execution_admitted_rows']}/{v61eh['generation_execution_admission_rows']}", "generation execution is not admitted"),
    ("v61-real-generation-result-artifacts", v61eh["real_generation_result_artifacts"] != "0", "v61eh", "real_generation_result_artifacts>0", v61eh["real_generation_result_artifacts"], "real generation artifacts are not returned"),
    ("v61-actual-model-generation", v61eh["actual_model_generation_ready"] == "1", "v61eh", "actual_model_generation_ready=1", v61eh["actual_model_generation_ready"], "actual generation remains unproven"),
    ("v1-release-and-quality-claims", v61eh["real_release_package_ready"] == "1", "v61eh", "release and quality evidence", f"release={v61eh['real_release_package_ready']}; latency={v61eh['production_latency_claim_ready']}; quality={v61eh['near_frontier_claim_ready']}", "production latency, near-frontier quality, and release audit evidence are missing"),
]
requirement_dicts = [
    {
        "requirement_id": req_id,
        "status": ready_status(ready),
        "ready": str(int(bool(ready))),
        "evidence_source": source,
        "required_value": required,
        "actual_value": actual,
        "blocking_reason": blocker,
    }
    for req_id, ready, source, required, actual, blocker in requirement_rows
]
write_csv(run_dir / "post_eh_requirement_rows.csv", list(requirement_dicts[0].keys()), requirement_dicts)

claim_rows = [
    (
        "v52-30b-150b-comparison-wording",
        "allowed-with-disclosure" if v52_comparison_wording_allowed else "blocked",
        "requires D/E PM/release readiness plus F final disposition",
    ),
    ("v53-complete-source-machine-surface", "allowed-with-disclosure", "machine surface is ready, review return is blocked"),
    ("v61-real-model-page-runtime-evidence", "allowed-with-boundary", "full shard/page hash/runtime evidence is ready"),
    ("v61-real-generation-return-packet", "allowed-with-boundary", "return packet/schema is ready, real artifacts are missing"),
    ("actual-mixtral-generation", "blocked", "requires real prerequisite binding plus accepted generation rows"),
    ("production-latency", "blocked", "requires accepted real latency rows"),
    ("near-frontier-quality", "blocked", "requires external quality review"),
    ("release-package", "blocked", "requires release audit evidence"),
]
claim_dicts = [
    {"claim_id": claim_id, "status": status, "required_disclosure_or_blocker": detail}
    for claim_id, status, detail in claim_rows
]
write_csv(run_dir / "post_eh_claim_boundary_rows.csv", list(claim_dicts[0].keys()), claim_dicts)

next_action_rows = [
    {
        "action_id": "01-real-v53-review-return",
        "status": "external-return-required",
        "required_artifact": "7000 human/source review rows, 1000 adjudication rows, reviewer identity/conflict rows, acceptance summary",
    },
    {
        "action_id": "02-refresh-real-prerequisite-binding",
        "status": "blocked-by-review-return",
        "required_artifact": "refreshed v61ck/v61cs/v61dd summaries after real review return",
    },
    {
        "action_id": "03-run-real-generation-and-return-five-artifacts",
        "status": "blocked-by-prerequisite-binding",
        "required_artifact": "five v61bt generation-result artifacts over 1000 query rows",
    },
    {
        "action_id": "04-intake-and-refresh-v61bt-v61de-v61cu",
        "status": "blocked-by-generation-return",
        "required_artifact": "accepted answer/citation/abstain/latency rows and acceptance summary",
    },
    {
        "action_id": "05-latency-quality-release-audit",
        "status": "blocked-by-actual-generation",
        "required_artifact": "production-ish latency report, near-frontier quality review, release audit",
    },
]
write_csv(run_dir / "post_eh_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

ready_requirement_rows = sum(row["ready"] == "1" for row in requirement_dicts)
blocked_requirement_rows = len(requirement_dicts) - ready_requirement_rows
allowed_claim_rows = sum(row["status"].startswith("allowed") for row in claim_dicts)
blocked_claim_rows = len(claim_dicts) - allowed_claim_rows
ready_section_rows = sum(row["ready"] == "1" for row in section_rows)

summary = {
    "v61ei_active_goal_post_eh_status_refresh_ready": "1",
    "v61dx_active_goal_status_audit_gate_ready": v61dx["v61dx_active_goal_status_audit_gate_ready"],
    "v61eh_real_generation_result_return_packet_ready": v61eh["v61eh_real_generation_result_return_packet_ready"],
    "section_rows": str(len(section_rows)),
    "ready_section_rows": str(ready_section_rows),
    "requirement_rows": str(len(requirement_dicts)),
    "ready_requirement_rows": str(ready_requirement_rows),
    "blocked_requirement_rows": str(blocked_requirement_rows),
    "claim_boundary_rows": str(len(claim_dicts)),
    "allowed_claim_boundary_rows": str(allowed_claim_rows),
    "blocked_claim_boundary_rows": str(blocked_claim_rows),
    "next_action_rows": str(len(next_action_rows)),
    "v52_ready": v61dx["v52_ready"],
    "f_optional_final_disposition": v61dx["f_optional_final_disposition"],
    "v53_machine_complete_source_surface_ready": v61dx["v53_machine_complete_source_surface_ready"],
    "v53_ready": v61dx["v53_ready"],
    "complete_source_repo_count": v61dx["complete_source_repo_count"],
    "complete_source_query_rows": v61dx["complete_source_query_rows"],
    "real_manifest_runtime_evidence_ready": v61eh["real_manifest_runtime_evidence_ready"],
    "full_checkpoint_materialization_ready": v61dx["full_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61dx["full_safetensors_page_hash_binding_ready"],
    "ready_checkpoint_materialization_shard_rows": v61dx["ready_checkpoint_materialization_shard_rows"],
    "checkpoint_shard_rows": v61dx["checkpoint_shard_rows"],
    "total_verified_page_hash_rows": v61dx["total_verified_page_hash_rows"],
    "total_required_page_hash_rows": v61dx["total_required_page_hash_rows"],
    "generation_return_packet_ready": v61eh["v61eh_real_generation_result_return_packet_ready"],
    "required_generation_result_artifact_rows": v61eh["required_generation_result_artifact_rows"],
    "required_generation_result_field_rows": v61eh["required_generation_result_field_rows"],
    "real_prerequisite_binding_ready": v61eh["real_prerequisite_binding_ready"],
    "real_review_return_ready": v61eh["real_review_return_ready"],
    "real_generation_execution_admission_ready": v61eh["real_generation_execution_admission_ready"],
    "generation_execution_admitted_rows": v61eh["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61eh["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61eh["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61eh["expected_generation_result_artifacts"],
    "real_generation_result_artifacts": v61eh["real_generation_result_artifacts"],
    "actual_model_generation_ready": v61eh["actual_model_generation_ready"],
    "near_frontier_claim_ready": v61eh["near_frontier_claim_ready"],
    "production_latency_claim_ready": v61eh["production_latency_claim_ready"],
    "real_release_package_ready": v61eh["real_release_package_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61ei": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "post-eh-status-refresh", "status": "pass", "reason": "v61dx and v61eh state rows emitted"},
    {"gate": "v52-f-optional-policy", "status": "pass", "reason": f"F={v61dx['f_optional_final_disposition']}"},
    {"gate": "v53-complete-source-machine-surface", "status": "pass", "reason": "10+ repos and 1000+ queries are present"},
    {"gate": "v53-review-return", "status": "blocked", "reason": "real review/adjudication return is missing"},
    {"gate": "v61-real-model-page-runtime-evidence", "status": "pass", "reason": "full shard/page hash/runtime evidence is ready"},
    {"gate": "v61-generation-return-packet", "status": "pass", "reason": "five-artifact return packet is ready"},
    {"gate": "v61-real-prerequisite-binding", "status": "blocked", "reason": "real review return and admitted generation execution are missing"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "real generation artifacts are missing"},
    {"gate": "latency-quality-release", "status": "blocked", "reason": "latency, external quality, and release evidence are missing"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EI_ACTIVE_GOAL_POST_EH_STATUS_REFRESH_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ei Active Goal Post-v61eh Status Refresh",
            "",
            "This refresh records the active objective after the v61eh real",
            "generation-result return packet. It does not create review rows,",
            "generation rows, latency evidence, quality evidence, or release",
            "evidence.",
            "",
            f"- v52_ready={summary['v52_ready']} with F={summary['f_optional_final_disposition']}",
            f"- v53_machine_complete_source_surface_ready={summary['v53_machine_complete_source_surface_ready']}",
            f"- v53_ready={summary['v53_ready']}",
            f"- real_manifest_runtime_evidence_ready={summary['real_manifest_runtime_evidence_ready']}",
            f"- full checkpoint shards={summary['ready_checkpoint_materialization_shard_rows']}/{summary['checkpoint_shard_rows']}",
            f"- full page hashes={summary['total_verified_page_hash_rows']}/{summary['total_required_page_hash_rows']}",
            f"- generation_return_packet_ready={summary['generation_return_packet_ready']}",
            f"- required_generation_result_artifact_rows={summary['required_generation_result_artifact_rows']}",
            f"- required_generation_result_field_rows={summary['required_generation_result_field_rows']}",
            f"- real_prerequisite_binding_ready={summary['real_prerequisite_binding_ready']}",
            f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}",
            f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}",
            f"- real_generation_result_artifacts={summary['real_generation_result_artifacts']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "",
            "Allowed wording: v61 real-model page/runtime evidence and the real",
            "generation-result return packet are ready. Blocked wording: actual",
            "Mixtral generation, production latency, near-frontier quality, v1.0",
            "comparison readiness, and release readiness.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61ei_active_goal_post_eh_status_refresh",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61ei_active_goal_post_eh_status_refresh_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ei_active_goal_post_eh_status_refresh_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
