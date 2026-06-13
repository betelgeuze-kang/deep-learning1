#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cf_ubuntu1_source_bound_generation_execution_packet"
RUN_ID="${V61CF_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cf_ubuntu1_source_bound_generation_execution_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61CE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ce_ubuntu1_generation_closure_return_intake.sh" >/dev/null

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


def status(flag):
    return "pass" if flag else "blocked"


v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"
v61ce_dir = results / "v61ce_ubuntu1_generation_closure_return_intake" / "intake_001"
v53r_summary_path = results / "v53r_complete_source_review_packet_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61ce_summary_path = results / "v61ce_ubuntu1_generation_closure_return_intake_summary.csv"
v53r_decision_path = results / "v53r_complete_source_review_packet_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"
v61ce_decision_path = results / "v61ce_ubuntu1_generation_closure_return_intake_decision.csv"

v53r = read_csv(v53r_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]
v61ce = read_csv(v61ce_summary_path)[0]
for field, summary in [
    ("v53r_complete_source_review_packet_ready", v53r),
    ("v61bt_ubuntu1_actual_generation_result_intake_ready", v61bt),
    ("v61ce_ubuntu1_generation_closure_return_intake_ready", v61ce),
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v61cf requires {field}=1")

for src, rel in [
    (v53r_summary_path, "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (v53r_decision_path, "source_v53r/v53r_complete_source_review_packet_decision.csv"),
    (v53r_dir / "review_query_packet_rows.csv", "source_v53r/review_query_packet_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53r_dir / "sha256_manifest.csv", "source_v53r/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_result_required_field_rows.csv", "source_v61bt/actual_generation_result_required_field_rows.csv"),
    (v61bt_dir / "actual_generation_result_template_rows.csv", "source_v61bt/actual_generation_result_template_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
    (v61ce_summary_path, "source_v61ce/v61ce_ubuntu1_generation_closure_return_intake_summary.csv"),
    (v61ce_decision_path, "source_v61ce/v61ce_ubuntu1_generation_closure_return_intake_decision.csv"),
    (v61ce_dir / "generation_closure_return_gate_rows.csv", "source_v61ce/generation_closure_return_gate_rows.csv"),
    (v61ce_dir / "generation_closure_return_admission_rows.csv", "source_v61ce/generation_closure_return_admission_rows.csv"),
    (v61ce_dir / "runtime_gap_rows.csv", "source_v61ce/runtime_gap_rows.csv"),
    (v61ce_dir / "sha256_manifest.csv", "source_v61ce/sha256_manifest.csv"),
]:
    copy(src, rel)

query_rows = read_csv(v53r_dir / "review_query_packet_rows.csv")
admission_rows = read_csv(v61ce_dir / "generation_closure_return_admission_rows.csv")
if len(query_rows) != 1000:
    raise SystemExit("v61cf expects 1000 v53r query rows")
if len(admission_rows) != 1000:
    raise SystemExit("v61cf expects 1000 v61ce admission rows")

query_by_id = {row["query_id"]: row for row in query_rows}
admission_by_query_id = {row["query_id"]: row for row in admission_rows}
if set(query_by_id) != set(admission_by_query_id):
    raise SystemExit("v61cf requires v53r/v61ce query id match")

generation_closure_return_intake_ready = int(v61ce["generation_closure_return_intake_ready"])
generation_execution_admission_ready = int(v61ce["generation_execution_admission_ready"])
page_hash_closure_ready = int(v61ce["page_hash_closure_ready"])
review_return_closure_ready = int(v61ce["review_return_closure_ready"])
generation_result_closure_ready = int(v61ce["generation_result_closure_ready"])
execution_ready = int(generation_closure_return_intake_ready and generation_execution_admission_ready)
execution_ready_rows = 1000 if execution_ready else 0
blocked_execution_rows = 0 if execution_ready else 1000
blocked_reasons = []
if not page_hash_closure_ready:
    blocked_reasons.append("page-hash-coverage-return")
if not review_return_closure_ready:
    blocked_reasons.append("complete-source-review-return")
if not generation_result_closure_ready:
    blocked_reasons.append("actual-generation-result-return")
if not generation_execution_admission_ready and not blocked_reasons:
    blocked_reasons.append("generation-execution-admission-blocked")
blocked_reason = "none" if execution_ready else ";".join(blocked_reasons)
target_root = v61ce["target_root_path"]

prompt_manifest_rows = [
    {
        "prompt_template_id": "source-bound-answer-contract",
        "required": "1",
        "contract": "answer only from supplied source span hashes and abstain when unsupported",
        "repo_payload_policy": "hashes-and-paths-only",
        "checkpoint_payload_policy": "external-target-root-only",
    },
    {
        "prompt_template_id": "citation-contract",
        "required": "1",
        "contract": "emit citation rows bound to source_span_id/source_file_sha256/source lines",
        "repo_payload_policy": "hashes-and-paths-only",
        "checkpoint_payload_policy": "external-target-root-only",
    },
    {
        "prompt_template_id": "abstain-fallback-contract",
        "required": "1",
        "contract": "emit abstain/fallback evidence for negative or unsupported queries",
        "repo_payload_policy": "hashes-and-paths-only",
        "checkpoint_payload_policy": "external-target-root-only",
    },
    {
        "prompt_template_id": "latency-contract",
        "required": "1",
        "contract": "emit prefill/decode/total latency and token-count rows",
        "repo_payload_policy": "hashes-and-paths-only",
        "checkpoint_payload_policy": "external-target-root-only",
    },
]
write_csv(run_dir / "source_bound_generation_prompt_manifest_rows.csv", list(prompt_manifest_rows[0].keys()), prompt_manifest_rows)

packet_rows = []
for index, admission in enumerate(admission_rows):
    query = query_by_id[admission["query_id"]]
    packet_rows.append(
        {
            "generation_execution_packet_id": f"v61cf-generation-execution-{index:04d}",
            "generation_closure_admission_id": admission["generation_closure_admission_id"],
            "review_query_packet_id": query["review_query_packet_id"],
            "query_id": query["query_id"],
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "expected_behavior": query["expected_behavior"],
            "negative_or_abstain": query["negative_or_abstain"],
            "question_sha256": query["question_sha256"],
            "source_span_id": query["source_span_id"],
            "source_path": query["source_path"],
            "source_line_start": query["source_line_start"],
            "source_line_end": query["source_line_end"],
            "source_file_sha256": query["source_file_sha256"],
            "evidence_text_sha256": query["evidence_text_sha256"],
            "model_id": model_id,
            "checkpoint_root": target_root,
            "prompt_template_count": str(len(prompt_manifest_rows)),
            "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
            "generation_closure_return_intake_ready": str(generation_closure_return_intake_ready),
            "generation_execution_admission_ready": str(generation_execution_admission_ready),
            "generation_execution_ready": str(execution_ready),
            "execution_admitted": str(execution_ready),
            "blocked_reason": blocked_reason,
            "checkpoint_payload_bytes_downloaded_by_v61cf": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "source_bound_generation_execution_packet_rows.csv", list(packet_rows[0].keys()), packet_rows)

return_manifest_rows = [
    ("real_model_generation_answer_rows.csv", "csv", "answer rows with answer hash and transcript hash"),
    ("real_model_generation_citation_rows.csv", "csv", "citation rows bound to source spans"),
    ("real_model_generation_abstain_fallback_rows.csv", "csv", "abstain and fallback evidence rows"),
    ("real_model_generation_latency_rows.csv", "csv", "latency and token-count rows"),
    ("real_model_generation_acceptance_summary.json", "json", "acceptance summary with artifact hashes"),
]
return_rows = [
    {
        "return_artifact": artifact,
        "artifact_type": artifact_type,
        "required": "1",
        "expected_rows": "1" if artifact_type == "json" else "1000",
        "purpose": purpose,
        "target_intake": "v61bt_ubuntu1_actual_generation_result_intake",
    }
    for artifact, artifact_type, purpose in return_manifest_rows
]
write_csv(run_dir / "source_bound_generation_return_manifest_rows.csv", list(return_rows[0].keys()), return_rows)

command_rows = [
    {
        "command_id": "refresh-generation-closure-return-intake",
        "command": "V61CE_REUSE_EXISTING=0 ./experiments/run_v61ce_ubuntu1_generation_closure_return_intake.sh",
        "purpose": "refresh closure gates before generation execution",
        "execution_ready": "0",
    },
    {
        "command_id": "verify-execution-packet-hashes",
        "command": "python3 -m json.tool results/v61cf_ubuntu1_source_bound_generation_execution_packet/packet_001/v61cf_ubuntu1_source_bound_generation_execution_packet_manifest.json >/dev/null",
        "purpose": "verify the packet manifest is parseable before handoff",
        "execution_ready": "0",
    },
    {
        "command_id": "run-source-bound-generation",
        "command": "V61CF_EXECUTE_GENERATION=1 V61CF_PACKET_DIR=results/v61cf_ubuntu1_source_bound_generation_execution_packet/packet_001 V61BT_GENERATION_RESULT_DIR=$V61BT_GENERATION_RESULT_DIR ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "purpose": "operator-side actual Mixtral generation and result capture after closures are ready",
        "execution_ready": "0",
    },
    {
        "command_id": "intake-generation-results",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=$V61BT_GENERATION_RESULT_DIR ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "purpose": "accept returned answer/citation/abstain/latency artifacts",
        "execution_ready": "0",
    },
    {
        "command_id": "refresh-generation-admission-bridge",
        "command": "V61CC_REUSE_EXISTING=0 ./experiments/run_v61cc_ubuntu1_page_hash_generation_admission_bridge.sh",
        "purpose": "recompute page-hash/review/generation admission bridge",
        "execution_ready": "0",
    },
    {
        "command_id": "refresh-generation-closure-intake",
        "command": "V61CE_REUSE_EXISTING=0 ./experiments/run_v61ce_ubuntu1_generation_closure_return_intake.sh",
        "purpose": "recompute generation closure return intake after returned generation artifacts",
        "execution_ready": "0",
    },
]
write_csv(run_dir / "source_bound_generation_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {
        "requirement_id": "v61ce-closure-return-intake-input",
        "required_value": "v61ce ready",
        "actual_value": v61ce["v61ce_ubuntu1_generation_closure_return_intake_ready"],
        "status": "pass",
        "reason": "v61ce closure intake evidence is bound",
    },
    {
        "requirement_id": "complete-source-query-packet",
        "required_value": "1000",
        "actual_value": str(len(query_rows)),
        "status": "pass",
        "reason": "v53r source-bound query rows are bound",
    },
    {
        "requirement_id": "generation-closure-return-intake-ready",
        "required_value": "1",
        "actual_value": str(generation_closure_return_intake_ready),
        "status": status(generation_closure_return_intake_ready),
        "reason": "page-hash, review, and generation result returns are not all closed",
    },
    {
        "requirement_id": "full-page-hash-closure",
        "required_value": "1",
        "actual_value": str(page_hash_closure_ready),
        "status": status(page_hash_closure_ready),
        "reason": "v61ce has closed full safetensors page-hash coverage",
    },
    {
        "requirement_id": "complete-source-review-return",
        "required_value": "1",
        "actual_value": str(review_return_closure_ready),
        "status": status(review_return_closure_ready),
        "reason": "complete-source review/adjudication returns are still absent",
    },
    {
        "requirement_id": "actual-generation-result-return",
        "required_value": "1",
        "actual_value": str(generation_result_closure_ready),
        "status": status(generation_result_closure_ready),
        "reason": "actual generation result artifacts are still absent",
    },
    {
        "requirement_id": "generation-execution-admission-ready",
        "required_value": "1",
        "actual_value": str(generation_execution_admission_ready),
        "status": status(generation_execution_admission_ready),
        "reason": "v61ce admits zero generation rows in the default path",
    },
    {
        "requirement_id": "source-bound-generation-execution-ready",
        "required_value": "1000 admitted rows",
        "actual_value": str(execution_ready_rows),
        "status": status(execution_ready),
        "reason": f"blocked_execution_rows={blocked_execution_rows}",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "required_value": "0",
        "actual_value": "0",
        "status": "pass",
        "reason": "v61cf writes prompts, hashes, command rows, and manifests only",
    },
]
write_csv(run_dir / "source_bound_generation_execution_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cf_ubuntu1_source_bound_generation_execution_packet_metrics",
    "model_id": model_id,
    "target_root_path": target_root,
    "execution_packet_rows": str(len(packet_rows)),
    "prompt_manifest_rows": str(len(prompt_manifest_rows)),
    "return_manifest_rows": str(len(return_rows)),
    "operator_command_rows": str(len(command_rows)),
    "complete_source_query_rows": str(len(query_rows)),
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "generation_closure_return_intake_ready": str(generation_closure_return_intake_ready),
    "generation_execution_admission_ready": str(generation_execution_admission_ready),
    "generation_execution_ready": str(execution_ready),
    "generation_execution_admitted_rows": str(execution_ready_rows),
    "blocked_execution_rows": str(blocked_execution_rows),
    "page_hash_closure_ready": str(page_hash_closure_ready),
    "review_return_closure_ready": str(review_return_closure_ready),
    "generation_result_closure_ready": str(generation_result_closure_ready),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cf": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "source_bound_generation_execution_metric_rows.csv", list(metric.keys()), [metric])

runtime_gap_rows = [
    ("v61ce-closure-return-intake-input", "ready", "v61ce evidence is bound"),
    ("complete-source-query-packet", "ready", "1000 v53r query rows are bound"),
    ("full-page-hash-closure", "ready" if page_hash_closure_ready else "blocked", f"page_hash_closure_ready={page_hash_closure_ready}"),
    ("complete-source-review-return", status(review_return_closure_ready), f"review_return_closure_ready={review_return_closure_ready}"),
    ("actual-generation-result-return", status(generation_result_closure_ready), f"generation_result_closure_ready={generation_result_closure_ready}"),
    ("source-bound-generation-execution", status(execution_ready), f"blocked_execution_rows={blocked_execution_rows}"),
    ("actual-model-generation", "blocked", "execution packet is not an executed generation run"),
    ("production-latency", "blocked", "not a production latency run"),
    ("near-frontier-quality", "blocked", "not an external quality review"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": state, "reason": reason} for gap, state, reason in runtime_gap_rows],
)

boundary = f"""# v61cf Ubuntu-1 Source-Bound Generation Execution Packet Boundary

This packet converts the v61ce generation closure return intake into a
source-bound execution handoff. It does not run the model and does not copy
checkpoint payload bytes into the repository.

Current state:

- execution_packet_rows={len(packet_rows)}
- prompt_manifest_rows={len(prompt_manifest_rows)}
- return_manifest_rows={len(return_rows)}
- operator_command_rows={len(command_rows)}
- complete_source_query_rows={len(query_rows)}
- expected_generation_result_artifacts={v61bt['expected_generation_result_artifacts']}
- generation_closure_return_intake_ready={generation_closure_return_intake_ready}
- generation_execution_admission_ready={generation_execution_admission_ready}
- generation_execution_ready={execution_ready}
- generation_execution_admitted_rows={execution_ready_rows}
- blocked_execution_rows={blocked_execution_rows}
- page_hash_closure_ready={page_hash_closure_ready}
- review_return_closure_ready={review_return_closure_ready}
- generation_result_closure_ready={generation_result_closure_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cf=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

v61cf is an execution packet and handoff contract only. It inherits the closed
full safetensors page-hash state from v61ce, but it does not execute Mixtral
generation and does not claim production latency, near-frontier quality, or a
release package.
"""
(run_dir / "V61CF_UBUNTU1_SOURCE_BOUND_GENERATION_EXECUTION_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

summary = {
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": "1",
    "model_id": model_id,
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "v61ce_ubuntu1_generation_closure_return_intake_ready": v61ce["v61ce_ubuntu1_generation_closure_return_intake_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decisions = [
    {"gate": "v61ce-closure-return-intake-input", "status": "pass", "reason": "v61ce evidence is bound"},
    {"gate": "complete-source-query-packet", "status": "pass", "reason": "1000 source-bound query rows are bound"},
    {"gate": "full-page-hash-closure", "status": status(page_hash_closure_ready), "reason": f"page_hash_closure_ready={page_hash_closure_ready}"},
    {"gate": "complete-source-review-return", "status": status(review_return_closure_ready), "reason": f"review_return_closure_ready={review_return_closure_ready}"},
    {"gate": "actual-generation-result-return", "status": status(generation_result_closure_ready), "reason": f"generation_result_closure_ready={generation_result_closure_ready}"},
    {"gate": "source-bound-generation-execution", "status": status(execution_ready), "reason": f"blocked_execution_rows={blocked_execution_rows}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "v61cf does not execute generation"},
    {"gate": "production-latency", "status": "blocked", "reason": "no production latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "no external near-frontier quality review"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not a release package"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "no checkpoint payload bytes are copied into the repository"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decisions)

manifest = {
    "artifact": "v61cf_ubuntu1_source_bound_generation_execution_packet",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "target_root_path": target_root,
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": 1,
    "source_v61ce_summary_sha256": sha256(v61ce_summary_path),
    "source_v53r_summary_sha256": sha256(v53r_summary_path),
    "execution_packet_rows": len(packet_rows),
    "prompt_manifest_rows": len(prompt_manifest_rows),
    "return_manifest_rows": len(return_rows),
    "operator_command_rows": len(command_rows),
    "complete_source_query_rows": len(query_rows),
    "generation_execution_ready": execution_ready,
    "generation_execution_admitted_rows": execution_ready_rows,
    "blocked_execution_rows": blocked_execution_rows,
    "page_hash_closure_ready": page_hash_closure_ready,
    "review_return_closure_ready": review_return_closure_ready,
    "generation_result_closure_ready": generation_result_closure_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61cf": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cf_ubuntu1_source_bound_generation_execution_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61cf_ubuntu1_source_bound_generation_execution_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
