#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cp_complete_source_runtime_admission_coverage_gate"
RUN_ID="${V61CP_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cp_complete_source_runtime_admission_coverage_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61co_real_manifest_runtime_execution_admission_bridge.sh" >/dev/null
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

v61co_dir = results / "v61co_real_manifest_runtime_execution_admission_bridge" / "bridge_001"
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


v61co = read_csv(results / "v61co_real_manifest_runtime_execution_admission_bridge_summary.csv")[0]
v61cf = read_csv(results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv")[0]
v61cc = read_csv(results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv")[0]
if v61co.get("v61co_real_manifest_runtime_execution_admission_bridge_ready") != "1":
    raise SystemExit("v61cp requires v61co_real_manifest_runtime_execution_admission_bridge_ready=1")
if v61cf.get("v61cf_ubuntu1_source_bound_generation_execution_packet_ready") != "1":
    raise SystemExit("v61cp requires v61cf_ubuntu1_source_bound_generation_execution_packet_ready=1")
if v61cc.get("v61cc_ubuntu1_page_hash_generation_admission_bridge_ready") != "1":
    raise SystemExit("v61cp requires v61cc_ubuntu1_page_hash_generation_admission_bridge_ready=1")

for src, rel in [
    (results / "v61co_real_manifest_runtime_execution_admission_bridge_summary.csv", "source_v61co/v61co_real_manifest_runtime_execution_admission_bridge_summary.csv"),
    (results / "v61co_real_manifest_runtime_execution_admission_bridge_decision.csv", "source_v61co/v61co_real_manifest_runtime_execution_admission_bridge_decision.csv"),
    (v61co_dir / "real_manifest_runtime_execution_admission_rows.csv", "source_v61co/real_manifest_runtime_execution_admission_rows.csv"),
    (v61co_dir / "sha256_manifest.csv", "source_v61co/sha256_manifest.csv"),
    (results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv", "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"),
    (results / "v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv", "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"),
    (v61cf_dir / "source_bound_generation_execution_packet_rows.csv", "source_v61cf/source_bound_generation_execution_packet_rows.csv"),
    (v61cf_dir / "source_bound_generation_return_manifest_rows.csv", "source_v61cf/source_bound_generation_return_manifest_rows.csv"),
    (v61cf_dir / "sha256_manifest.csv", "source_v61cf/sha256_manifest.csv"),
    (results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv", "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"),
    (results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv", "source_v61cc/v61cc_ubuntu1_page_hash_generation_admission_bridge_decision.csv"),
    (v61cc_dir / "page_hash_generation_admission_bridge_rows.csv", "source_v61cc/page_hash_generation_admission_bridge_rows.csv"),
    (v61cc_dir / "sha256_manifest.csv", "source_v61cc/sha256_manifest.csv"),
]:
    copy(src, rel)

seed_rows = read_csv(v61co_dir / "real_manifest_runtime_execution_admission_rows.csv")
packet_rows = read_csv(v61cf_dir / "source_bound_generation_execution_packet_rows.csv")
admission_rows = {row["query_id"]: row for row in read_csv(v61cc_dir / "page_hash_generation_admission_bridge_rows.csv")}
seed_by_query = {row["query_id"]: row for row in seed_rows}

coverage_rows = []
for index, packet in enumerate(packet_rows):
    seed = seed_by_query.get(packet["query_id"])
    admission = admission_rows.get(packet["query_id"], {})
    has_seed = seed is not None
    seed_admitted = seed["runtime_execution_admitted"] if seed else "0"
    cc_admitted = admission.get("generation_execution_admitted", "0")
    cf_admitted = packet["execution_admitted"]
    if not has_seed:
        status = "blocked-no-direct-v61co-seed-runtime-coverage"
        blocking_gate = "v61cp-complete-source-runtime-seed-coverage"
        reason = "complete-source query_id has no direct v61co seed runtime admission row"
    elif seed_admitted != "1":
        status = "blocked-v61co-runtime-admission"
        blocking_gate = "v61co-real-manifest-runtime-execution-admission"
        reason = seed["blocking_reason"]
    elif cc_admitted != "1" or cf_admitted != "1":
        status = "blocked-generation-admission"
        blocking_gate = "v61cc-v61cf-generation-admission"
        reason = packet["blocked_reason"]
    else:
        status = "admitted"
        blocking_gate = "none"
        reason = "complete-source query has seed coverage and all runtime/generation admissions"
    coverage_rows.append(
        {
            "coverage_row_id": f"v61cp-complete-source-runtime-coverage-{index:04d}",
            "query_id": packet["query_id"],
            "review_query_packet_id": packet["review_query_packet_id"],
            "owner_repo": packet["owner_repo"],
            "source_span_id": packet["source_span_id"],
            "source_path": packet["source_path"],
            "has_direct_v61co_seed_runtime_row": "1" if has_seed else "0",
            "v61co_seed_runtime_execution_admitted": seed_admitted,
            "v61cc_generation_execution_admitted": cc_admitted,
            "v61cf_execution_admitted": cf_admitted,
            "complete_source_runtime_execution_admitted": "1" if status == "admitted" else "0",
            "runtime_admission_coverage_status": status,
            "blocking_gate": blocking_gate,
            "blocking_reason": reason,
            "checkpoint_payload_bytes_downloaded_by_v61cp": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "complete_source_runtime_admission_coverage_rows.csv", list(coverage_rows[0].keys()), coverage_rows)

complete_source_query_rows = len(coverage_rows)
seed_runtime_candidate_rows = len(seed_rows)
direct_overlap_rows = sum(1 for row in coverage_rows if row["has_direct_v61co_seed_runtime_row"] == "1")
uncovered_rows = complete_source_query_rows - direct_overlap_rows
seed_admitted_complete_source_rows = sum(1 for row in coverage_rows if row["v61co_seed_runtime_execution_admitted"] == "1")
complete_source_runtime_admitted_rows = sum(1 for row in coverage_rows if row["complete_source_runtime_execution_admitted"] == "1")
coverage_ready = int(complete_source_query_rows > 0 and complete_source_runtime_admitted_rows == complete_source_query_rows)

requirement_rows = [
    {
        "requirement_id": "v61co-seed-runtime-admission-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61co["v61co_real_manifest_runtime_execution_admission_bridge_ready"],
        "reason": "37-row real-manifest seed runtime admission bridge is bound",
    },
    {
        "requirement_id": "v61cf-complete-source-generation-packet-input",
        "status": "pass",
        "required_value": "1000",
        "actual_value": v61cf["execution_packet_rows"],
        "reason": "complete-source generation execution packet is bound",
    },
    {
        "requirement_id": "v61cc-complete-source-generation-admission-input",
        "status": "pass",
        "required_value": "1000",
        "actual_value": v61cc["generation_admission_bridge_rows"],
        "reason": "complete-source generation admission bridge is bound",
    },
    {
        "requirement_id": "complete-source-runtime-seed-coverage",
        "status": pass_block(direct_overlap_rows == complete_source_query_rows),
        "required_value": str(complete_source_query_rows),
        "actual_value": str(direct_overlap_rows),
        "reason": "v61co seed query IDs are distinct from the complete-source v53i query IDs",
    },
    {
        "requirement_id": "complete-source-runtime-execution-admission",
        "status": pass_block(coverage_ready == 1),
        "required_value": str(complete_source_query_rows),
        "actual_value": str(complete_source_runtime_admitted_rows),
        "reason": "complete-source rows lack seed runtime coverage and remain blocked by page-hash/review/generation gates",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0",
        "actual_value": "0",
        "reason": "v61cp writes metadata and coverage rows only",
    },
]
write_csv(run_dir / "complete_source_runtime_admission_coverage_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cp_complete_source_runtime_admission_coverage_metrics",
    "model_id": model_id,
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": v61co["v61co_real_manifest_runtime_execution_admission_bridge_ready"],
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": v61cf["v61cf_ubuntu1_source_bound_generation_execution_packet_ready"],
    "v61cc_ubuntu1_page_hash_generation_admission_bridge_ready": v61cc["v61cc_ubuntu1_page_hash_generation_admission_bridge_ready"],
    "complete_source_query_rows": str(complete_source_query_rows),
    "source_bound_seed_runtime_candidate_rows": str(seed_runtime_candidate_rows),
    "source_bound_seed_query_pass_rows": v61co["source_bound_query_pass_rows"],
    "direct_query_overlap_rows": str(direct_overlap_rows),
    "runtime_seed_covered_complete_source_rows": str(direct_overlap_rows),
    "runtime_seed_uncovered_complete_source_rows": str(uncovered_rows),
    "runtime_seed_admitted_complete_source_rows": str(seed_admitted_complete_source_rows),
    "complete_source_runtime_execution_admitted_rows": str(complete_source_runtime_admitted_rows),
    "complete_source_runtime_execution_blocked_rows": str(complete_source_query_rows - complete_source_runtime_admitted_rows),
    "complete_source_runtime_admission_coverage_ready": str(coverage_ready),
    "real_manifest_runtime_execution_admission_ready": v61co["real_manifest_runtime_execution_admission_ready"],
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
    "checkpoint_payload_bytes_downloaded_by_v61cp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_runtime_admission_coverage_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cp_complete_source_runtime_admission_coverage_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61co-seed-runtime-admission-input", "status": "ready", "reason": "v61co seed runtime admission bridge is bound"},
    {"gap": "v61cf-complete-source-generation-packet-input", "status": "ready", "reason": "v61cf 1000-row packet is bound"},
    {"gap": "v61cc-complete-source-generation-admission-input", "status": "ready", "reason": "v61cc 1000-row admission surface is bound"},
    {"gap": "complete-source-runtime-seed-coverage", "status": "ready" if direct_overlap_rows == complete_source_query_rows else "blocked", "reason": f"direct_query_overlap_rows={direct_overlap_rows}/{complete_source_query_rows}"},
    {"gap": "complete-source-runtime-execution-admission", "status": "ready" if coverage_ready else "blocked", "reason": f"complete_source_runtime_execution_admitted_rows={complete_source_runtime_admitted_rows}/{complete_source_query_rows}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "complete-source runtime admission coverage is not ready"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not external release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61co-seed-runtime-admission-input", "status": "pass", "reason": "v61co seed runtime admission bridge is bound"},
    {"gate": "v61cf-complete-source-generation-packet-input", "status": "pass", "reason": "v61cf complete-source packet is bound"},
    {"gate": "v61cc-complete-source-generation-admission-input", "status": "pass", "reason": "v61cc complete-source admission surface is bound"},
    {"gate": "complete-source-runtime-seed-coverage", "status": "pass" if direct_overlap_rows == complete_source_query_rows else "blocked", "reason": f"direct_query_overlap_rows={direct_overlap_rows}/{complete_source_query_rows}"},
    {"gate": "complete-source-runtime-execution-admission", "status": "pass" if coverage_ready else "blocked", "reason": f"complete_source_runtime_execution_admitted_rows={complete_source_runtime_admitted_rows}/{complete_source_query_rows}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not external release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cp writes metadata and coverage rows only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cp Complete-Source Runtime Admission Coverage Gate Boundary

This artifact prevents the 37-row v61co seed runtime admission bridge from being
treated as complete-source 1000-query runtime coverage. It binds v61co, v61cf,
and v61cc, then records direct query-ID coverage over every complete-source
generation packet row.

Evidence emitted:

- complete_source_query_rows={complete_source_query_rows}
- source_bound_seed_runtime_candidate_rows={seed_runtime_candidate_rows}
- source_bound_seed_query_pass_rows={v61co["source_bound_query_pass_rows"]}
- direct_query_overlap_rows={direct_overlap_rows}
- runtime_seed_covered_complete_source_rows={direct_overlap_rows}
- runtime_seed_uncovered_complete_source_rows={uncovered_rows}
- runtime_seed_admitted_complete_source_rows={seed_admitted_complete_source_rows}
- complete_source_runtime_execution_admitted_rows={complete_source_runtime_admitted_rows}
- complete_source_runtime_execution_blocked_rows={complete_source_query_rows - complete_source_runtime_admitted_rows}
- complete_source_runtime_admission_coverage_ready={coverage_ready}
- real_manifest_runtime_execution_admission_ready={v61co["real_manifest_runtime_execution_admission_ready"]}
- page_hash_blocked_rows={v61cc["page_hash_blocked_rows"]}
- review_return_blocked_rows={v61cc["review_return_blocked_rows"]}
- generation_result_artifact_blocked_rows={v61cc["generation_result_artifact_blocked_rows"]}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cp=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source runtime admission coverage gap between the
37-row v61 seed workload and the 1000-row complete-source generation packet.
Blocked wording: complete-source real-model generation coverage, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CP_COMPLETE_SOURCE_RUNTIME_ADMISSION_COVERAGE_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cp_complete_source_runtime_admission_coverage_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cp_complete_source_runtime_admission_coverage_gate_ready": 1,
    "v61co_summary_sha256": sha256(results / "v61co_real_manifest_runtime_execution_admission_bridge_summary.csv"),
    "v61cf_summary_sha256": sha256(results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"),
    "v61cc_summary_sha256": sha256(results / "v61cc_ubuntu1_page_hash_generation_admission_bridge_summary.csv"),
    "complete_source_query_rows": complete_source_query_rows,
    "source_bound_seed_runtime_candidate_rows": seed_runtime_candidate_rows,
    "direct_query_overlap_rows": direct_overlap_rows,
    "complete_source_runtime_admission_coverage_ready": coverage_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61cp": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61cp_complete_source_runtime_admission_coverage_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cp_complete_source_runtime_admission_coverage_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
