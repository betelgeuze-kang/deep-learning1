#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cq_complete_source_runtime_admission_expansion_packet"
RUN_ID="${V61CQ_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CQ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cq_complete_source_runtime_admission_expansion_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CP_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cp_complete_source_runtime_admission_coverage_gate.sh" >/dev/null
V61CF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cf_ubuntu1_source_bound_generation_execution_packet.sh" >/dev/null
V61CC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh" >/dev/null

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

v61cp_dir = results / "v61cp_complete_source_runtime_admission_coverage_gate" / "gate_001"
v61cf_dir = results / "v61cf_ubuntu1_source_bound_generation_execution_packet" / "packet_001"
v61cc_dir = results / "v61cc_ubuntu1_page_hash_generation_admission_bridge" / "bridge_001"


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


def pass_block(flag):
    return "pass" if flag else "blocked"


v61cp = read_csv(results / "v61cp_complete_source_runtime_admission_coverage_gate_summary.csv")[0]
v61cf = read_csv(results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv")[0]
v61cc = read_csv(results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv")[0]
if v61cp.get("v61cp_complete_source_runtime_admission_coverage_gate_ready") != "1":
    raise SystemExit("v61cq requires v61cp_complete_source_runtime_admission_coverage_gate_ready=1")
if v61cf.get("v61cf_ubuntu1_source_bound_generation_execution_packet_ready") != "1":
    raise SystemExit("v61cq requires v61cf_ubuntu1_source_bound_generation_execution_packet_ready=1")
if v61cc.get("v61cc_ubuntu1_page_hash_generation_admission_bridge_ready") != "1":
    raise SystemExit("v61cq requires v61cc_ubuntu1_page_hash_generation_admission_bridge_ready=1")

for src, rel in [
    (results / "v61cp_complete_source_runtime_admission_coverage_gate_summary.csv", "source_v61cp/v61cp_complete_source_runtime_admission_coverage_gate_summary.csv"),
    (results / "v61cp_complete_source_runtime_admission_coverage_gate_decision.csv", "source_v61cp/v61cp_complete_source_runtime_admission_coverage_gate_decision.csv"),
    (v61cp_dir / "complete_source_runtime_admission_coverage_rows.csv", "source_v61cp/complete_source_runtime_admission_coverage_rows.csv"),
    (v61cp_dir / "sha256_manifest.csv", "source_v61cp/sha256_manifest.csv"),
    (results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv", "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"),
    (results / "v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv", "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"),
    (v61cf_dir / "source_bound_generation_execution_packet_rows.csv", "source_v61cf/source_bound_generation_execution_packet_rows.csv"),
    (v61cf_dir / "source_bound_generation_return_manifest_rows.csv", "source_v61cf/source_bound_generation_return_manifest_rows.csv"),
    (v61cf_dir / "source_bound_generation_operator_command_rows.csv", "source_v61cf/source_bound_generation_operator_command_rows.csv"),
    (v61cf_dir / "sha256_manifest.csv", "source_v61cf/sha256_manifest.csv"),
    (results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv", "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"),
    (results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv", "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"),
    (v61cc_dir / "page_hash_generation_admission_bridge_rows.csv", "source_v61cc/page_hash_generation_admission_bridge_rows.csv"),
    (v61cc_dir / "sha256_manifest.csv", "source_v61cc/sha256_manifest.csv"),
]:
    copy(src, rel)

coverage_rows = read_csv(v61cp_dir / "complete_source_runtime_admission_coverage_rows.csv")
packet_rows = read_csv(v61cf_dir / "source_bound_generation_execution_packet_rows.csv")
generation_admission_rows = {
    row["query_id"]: row for row in read_csv(v61cc_dir / "page_hash_generation_admission_bridge_rows.csv")
}
coverage_by_query = {row["query_id"]: row for row in coverage_rows}

if len(packet_rows) != len(coverage_rows):
    raise SystemExit("v61cq requires one v61cp coverage row per v61cf packet row")

expansion_rows = []
for index, packet in enumerate(packet_rows):
    coverage = coverage_by_query.get(packet["query_id"])
    if coverage is None:
        raise SystemExit(f"missing v61cp coverage row for {packet['query_id']}")
    generation = generation_admission_rows.get(packet["query_id"], {})
    has_seed = coverage["has_direct_v61co_seed_runtime_row"] == "1"
    seed_admitted = coverage["v61co_seed_runtime_execution_admitted"] == "1"
    generation_admitted = (
        packet["execution_admitted"] == "1"
        and generation.get("generation_execution_admitted", "0") == "1"
    )
    needs_expansion = coverage["complete_source_runtime_execution_admitted"] != "1"
    if not has_seed:
        status = "planned-new-runtime-admission-required"
        blocking_gate = "v61cq-complete-source-runtime-admission-expansion"
        reason = "complete-source query requires its own real-manifest runtime admission row"
    elif not seed_admitted:
        status = "blocked-seed-runtime-admission"
        blocking_gate = "v61co-real-manifest-runtime-execution-admission"
        reason = coverage["blocking_reason"]
    elif not generation_admitted:
        status = "blocked-generation-admission"
        blocking_gate = "v61cc-v61cf-generation-admission"
        reason = packet["blocked_reason"]
    else:
        status = "already-covered"
        blocking_gate = "none"
        reason = "complete-source runtime and generation admissions are already available"
    expansion_rows.append(
        {
            "expansion_row_id": f"v61cq-runtime-expansion-{index:04d}",
            "query_id": packet["query_id"],
            "review_query_packet_id": packet["review_query_packet_id"],
            "generation_execution_packet_id": packet["generation_execution_packet_id"],
            "owner_repo": packet["owner_repo"],
            "audit_type": packet["audit_type"],
            "expected_behavior": packet["expected_behavior"],
            "negative_or_abstain": packet["negative_or_abstain"],
            "source_span_id": packet["source_span_id"],
            "source_path": packet["source_path"],
            "source_line_start": packet["source_line_start"],
            "source_line_end": packet["source_line_end"],
            "has_direct_v61co_seed_runtime_row": coverage["has_direct_v61co_seed_runtime_row"],
            "complete_source_runtime_execution_admitted": coverage["complete_source_runtime_execution_admitted"],
            "requires_new_runtime_admission_row": "1" if needs_expansion else "0",
            "runtime_admission_expansion_status": status,
            "blocking_gate": blocking_gate,
            "blocking_reason": reason,
            "model_id": packet["model_id"],
            "checkpoint_root": packet["checkpoint_root"],
            "checkpoint_payload_bytes_downloaded_by_v61cq": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "complete_source_runtime_admission_expansion_rows.csv", list(expansion_rows[0].keys()), expansion_rows)

complete_source_query_rows = len(expansion_rows)
expansion_required_rows = sum(1 for row in expansion_rows if row["requires_new_runtime_admission_row"] == "1")
seed_covered_rows = sum(1 for row in expansion_rows if row["has_direct_v61co_seed_runtime_row"] == "1")
already_admitted_rows = sum(1 for row in expansion_rows if row["complete_source_runtime_execution_admitted"] == "1")
new_runtime_admission_rows_required = expansion_required_rows
expansion_packet_ready = int(complete_source_query_rows > 0 and expansion_required_rows == complete_source_query_rows)
expansion_execution_ready = 0

operator_rows = [
    {
        "operator_step": "01-complete-checkpoint-materialization",
        "depends_on": "v61cm/v61cl/v61bq",
        "command": "return all 59 checkpoint shard materialization receipts, then rerun v61cm",
        "ready_to_run_now": "0",
        "expected_return": "full_checkpoint_materialization_ready=1",
    },
    {
        "operator_step": "02-complete-full-page-hash-coverage",
        "depends_on": "v61bz/v61ca/v61cb",
        "command": "execute remaining 286 page-hash chunks and return 131808 hash rows",
        "ready_to_run_now": "0",
        "expected_return": "full_safetensors_page_hash_binding_ready=1",
    },
    {
        "operator_step": "03-run-complete-source-runtime-admission",
        "depends_on": "v61cq/v61cp/v61cf",
        "command": "run real-manifest runtime admission over complete_source_runtime_admission_expansion_rows.csv",
        "ready_to_run_now": "0",
        "expected_return": "1000 complete-source runtime admission result rows",
    },
    {
        "operator_step": "04-return-runtime-admission-results",
        "depends_on": "external-runtime-execution",
        "command": "return the five v61cq runtime admission artifacts listed in the return manifest",
        "ready_to_run_now": "0",
        "expected_return": "complete_source_runtime_admission_return_artifact_rows=5",
    },
    {
        "operator_step": "05-recheck-complete-source-coverage",
        "depends_on": "v61cp",
        "command": "V61CP_REUSE_EXISTING=0 ./experiments/run_v61cp_complete_source_runtime_admission_coverage_gate.sh",
        "ready_to_run_now": "0",
        "expected_return": "complete_source_runtime_admission_coverage_ready=1 after accepted runtime return rows exist",
    },
]
write_csv(run_dir / "complete_source_runtime_admission_operator_command_rows.csv", list(operator_rows[0].keys()), operator_rows)

return_rows = [
    {
        "artifact_id": "complete-source-runtime-admission-result-rows",
        "path": "complete_source_runtime_admission_result_rows.csv",
        "required_rows": str(complete_source_query_rows),
        "accepted_rows": "0",
        "status": "missing",
        "reason": "no real runtime admission execution return has been supplied",
    },
    {
        "artifact_id": "complete-source-runtime-page-binding-rows",
        "path": "complete_source_runtime_page_binding_rows.csv",
        "required_rows": str(complete_source_query_rows),
        "accepted_rows": "0",
        "status": "missing",
        "reason": "no per-query runtime page binding return has been supplied",
    },
    {
        "artifact_id": "complete-source-runtime-budget-rows",
        "path": "complete_source_runtime_budget_rows.csv",
        "required_rows": str(complete_source_query_rows),
        "accepted_rows": "0",
        "status": "missing",
        "reason": "no per-query runtime budget return has been supplied",
    },
    {
        "artifact_id": "complete-source-runtime-identity-rows",
        "path": "complete_source_runtime_identity_rows.csv",
        "required_rows": "59",
        "accepted_rows": "0",
        "status": "missing",
        "reason": "no complete checkpoint identity return has been supplied",
    },
    {
        "artifact_id": "complete-source-runtime-abstain-fallback-rows",
        "path": "complete_source_runtime_abstain_fallback_rows.csv",
        "required_rows": str(complete_source_query_rows),
        "accepted_rows": "0",
        "status": "missing",
        "reason": "no runtime citation/abstain/fallback return has been supplied",
    },
]
write_csv(run_dir / "complete_source_runtime_admission_return_manifest_rows.csv", list(return_rows[0].keys()), return_rows)

requirement_rows = [
    {
        "requirement_id": "v61cp-complete-source-runtime-coverage-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61cp["v61cp_complete_source_runtime_admission_coverage_gate_ready"],
        "reason": "v61cp coverage gap evidence is bound",
    },
    {
        "requirement_id": "v61cf-complete-source-generation-packet-input",
        "status": "pass",
        "required_value": "1000",
        "actual_value": v61cf["execution_packet_rows"],
        "reason": "complete-source generation packet provides the 1000 query rows",
    },
    {
        "requirement_id": "v61cc-generation-admission-input",
        "status": "pass",
        "required_value": "1000",
        "actual_value": v61cc["generation_admission_bridge_rows"],
        "reason": "complete-source generation admission bridge is bound",
    },
    {
        "requirement_id": "complete-source-runtime-admission-expansion-packet",
        "status": pass_block(expansion_packet_ready == 1),
        "required_value": str(complete_source_query_rows),
        "actual_value": str(expansion_required_rows),
        "reason": "every complete-source row is represented as a runtime admission expansion candidate",
    },
    {
        "requirement_id": "complete-source-runtime-admission-execution",
        "status": pass_block(expansion_execution_ready == 1),
        "required_value": str(complete_source_query_rows),
        "actual_value": "0",
        "reason": "runtime admission expansion packet is ready, but real execution return rows are missing",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0",
        "actual_value": "0",
        "reason": "v61cq writes metadata and operator packet rows only",
    },
]
write_csv(run_dir / "complete_source_runtime_admission_expansion_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cq_complete_source_runtime_admission_expansion_metrics",
    "model_id": model_id,
    "v61cp_complete_source_runtime_admission_coverage_gate_ready": v61cp["v61cp_complete_source_runtime_admission_coverage_gate_ready"],
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": v61cf["v61cf_ubuntu1_source_bound_generation_execution_packet_ready"],
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": v61cc["v61cc_ubuntu1_page_hash_generation_admission_bridge_ready"],
    "complete_source_query_rows": str(complete_source_query_rows),
    "source_bound_seed_runtime_candidate_rows": v61cp["source_bound_seed_runtime_candidate_rows"],
    "source_bound_seed_query_pass_rows": v61cp["source_bound_seed_query_pass_rows"],
    "direct_query_overlap_rows": v61cp["direct_query_overlap_rows"],
    "runtime_seed_covered_complete_source_rows": str(seed_covered_rows),
    "runtime_seed_uncovered_complete_source_rows": v61cp["runtime_seed_uncovered_complete_source_rows"],
    "complete_source_runtime_execution_admitted_rows": str(already_admitted_rows),
    "complete_source_runtime_execution_blocked_rows": str(complete_source_query_rows - already_admitted_rows),
    "complete_source_runtime_admission_coverage_ready": v61cp["complete_source_runtime_admission_coverage_ready"],
    "runtime_admission_expansion_packet_rows": str(len(expansion_rows)),
    "runtime_admission_expansion_required_rows": str(expansion_required_rows),
    "new_runtime_admission_rows_required": str(new_runtime_admission_rows_required),
    "runtime_admission_operator_command_rows": str(len(operator_rows)),
    "runtime_admission_return_artifact_rows": str(len(return_rows)),
    "runtime_admission_expansion_packet_ready": str(expansion_packet_ready),
    "runtime_admission_expansion_execution_ready": str(expansion_execution_ready),
    "generation_execution_admitted_rows": v61cf["generation_execution_admitted_rows"],
    "blocked_execution_rows": v61cf["blocked_execution_rows"],
    "page_hash_blocked_rows": v61cc["page_hash_blocked_rows"],
    "review_return_blocked_rows": v61cc["review_return_blocked_rows"],
    "generation_result_artifact_blocked_rows": v61cc["generation_result_artifact_blocked_rows"],
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cq": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_runtime_admission_expansion_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61cp-complete-source-runtime-coverage-input", "status": "ready", "reason": "v61cp coverage rows are bound"},
    {"gap": "v61cf-complete-source-generation-packet-input", "status": "ready", "reason": "v61cf packet rows are bound"},
    {"gap": "v61cc-generation-admission-input", "status": "ready", "reason": "v61cc generation admission rows are bound"},
    {"gap": "complete-source-runtime-admission-expansion-packet", "status": "ready", "reason": f"runtime_admission_expansion_required_rows={expansion_required_rows}/{complete_source_query_rows}"},
    {"gap": "complete-source-runtime-admission-execution", "status": "blocked", "reason": "no real runtime admission return rows have been supplied"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "complete-source runtime admission execution is not ready"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61cp-complete-source-runtime-coverage-input", "status": "pass", "reason": "v61cp coverage gap evidence is bound"},
    {"gate": "v61cf-complete-source-generation-packet-input", "status": "pass", "reason": "v61cf 1000-row packet is bound"},
    {"gate": "v61cc-generation-admission-input", "status": "pass", "reason": "v61cc 1000-row generation admission surface is bound"},
    {"gate": "complete-source-runtime-admission-expansion-packet", "status": "pass" if expansion_packet_ready else "blocked", "reason": f"runtime_admission_expansion_required_rows={expansion_required_rows}/{complete_source_query_rows}"},
    {"gate": "complete-source-runtime-admission-execution", "status": "blocked", "reason": "accepted runtime admission return rows=0"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not external release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cq writes metadata and operator packet rows only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cq Complete-Source Runtime Admission Expansion Packet Boundary

This artifact converts the v61cp coverage gap into a complete-source runtime
admission expansion packet. It does not claim runtime execution. It lists every
1000-row complete-source query as a new real-manifest runtime admission target
because the 37-row seed workload has direct query overlap 0/1000.

Evidence emitted:

- complete_source_query_rows={complete_source_query_rows}
- source_bound_seed_runtime_candidate_rows={v61cp["source_bound_seed_runtime_candidate_rows"]}
- source_bound_seed_query_pass_rows={v61cp["source_bound_seed_query_pass_rows"]}
- direct_query_overlap_rows={v61cp["direct_query_overlap_rows"]}
- runtime_seed_covered_complete_source_rows={seed_covered_rows}
- runtime_seed_uncovered_complete_source_rows={v61cp["runtime_seed_uncovered_complete_source_rows"]}
- runtime_admission_expansion_packet_rows={len(expansion_rows)}
- runtime_admission_expansion_required_rows={expansion_required_rows}
- new_runtime_admission_rows_required={new_runtime_admission_rows_required}
- runtime_admission_operator_command_rows={len(operator_rows)}
- runtime_admission_return_artifact_rows={len(return_rows)}
- runtime_admission_expansion_packet_ready={expansion_packet_ready}
- runtime_admission_expansion_execution_ready={expansion_execution_ready}
- complete_source_runtime_admission_coverage_ready={v61cp["complete_source_runtime_admission_coverage_ready"]}
- page_hash_blocked_rows={v61cc["page_hash_blocked_rows"]}
- review_return_blocked_rows={v61cc["review_return_blocked_rows"]}
- generation_result_artifact_blocked_rows={v61cc["generation_result_artifact_blocked_rows"]}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cq=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source runtime admission expansion packet over the
1000-row source-bound generation packet. Blocked wording: completed
complete-source runtime execution, actual Mixtral generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CQ_COMPLETE_SOURCE_RUNTIME_ADMISSION_EXPANSION_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cq_complete_source_runtime_admission_expansion_packet",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": 1,
    "v61cp_summary_sha256": sha256(results / "v61cp_complete_source_runtime_admission_coverage_gate_summary.csv"),
    "v61cf_summary_sha256": sha256(results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"),
    "v61cc_summary_sha256": sha256(results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"),
    "complete_source_query_rows": complete_source_query_rows,
    "runtime_admission_expansion_required_rows": expansion_required_rows,
    "runtime_admission_operator_command_rows": len(operator_rows),
    "runtime_admission_return_artifact_rows": len(return_rows),
    "runtime_admission_expansion_packet_ready": expansion_packet_ready,
    "runtime_admission_expansion_execution_ready": expansion_execution_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61cq": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61cq_complete_source_runtime_admission_expansion_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cq_complete_source_runtime_admission_expansion_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
