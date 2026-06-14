#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ae_real_generation_admission_gate"
RUN_ID="${V61AE_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT_OVERRIDE="${V61AE_WAREHOUSE_ROOT:-${V61W_WAREHOUSE_ROOT:-${V61T_WAREHOUSE_ROOT:-${V61R_WAREHOUSE_ROOT:-${V61P_SSD_WAREHOUSE_DIR:-${V61_WAREHOUSE_ROOT:-}}}}}}"

if [[ "${V61AE_REUSE_EXISTING:-0}" == "1" && -z "$WAREHOUSE_ROOT_OVERRIDE" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ae_real_generation_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ad_kv_weight_token_budget_replay.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null
if [[ -n "$WAREHOUSE_ROOT_OVERRIDE" ]]; then
  V61R_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61R_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null
  V61T_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
  V61W_WAREHOUSE_ROOT="$WAREHOUSE_ROOT_OVERRIDE" V61W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null
else
  V61R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null
  V61T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61t_local_checkpoint_materialization_verifier.sh" >/dev/null
  V61W_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61w_materialization_admission_resume_plan.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT_OVERRIDE" <<'PY'
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
warehouse_root_override = sys.argv[5].strip()
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


v61ad_dir = results / "v61ad_kv_weight_token_budget_replay" / "replay_001"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v61r_dir = results / "v61r_full_page_hash_sweep_plan" / "plan_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61w_dir = results / "v61w_materialization_admission_resume_plan" / "plan_001"

v61ad_summary = read_csv(results / "v61ad_kv_weight_token_budget_replay_summary.csv")[0]
v53r_summary = read_csv(results / "v53r_complete_source_review_packet_summary.csv")[0]
v61r_summary = read_csv(results / "v61r_full_page_hash_sweep_plan_summary.csv")[0]
v61t_summary = read_csv(results / "v61t_local_checkpoint_materialization_verifier_summary.csv")[0]
v61w_summary = read_csv(results / "v61w_materialization_admission_resume_plan_summary.csv")[0]

if v61ad_summary.get("v61ad_kv_weight_token_budget_replay_ready") != "1":
    raise SystemExit("v61ae requires v61ad_kv_weight_token_budget_replay_ready=1")
if v53r_summary.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v61ae requires v53r_complete_source_review_packet_ready=1")
if v61r_summary.get("v61r_full_page_hash_sweep_plan_ready") != "1":
    raise SystemExit("v61ae requires v61r_full_page_hash_sweep_plan_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61ae requires v61t_local_checkpoint_materialization_verifier_ready=1")
if v61w_summary.get("v61w_materialization_admission_resume_plan_ready") != "1":
    raise SystemExit("v61ae requires v61w_materialization_admission_resume_plan_ready=1")

for src, rel in [
    (results / "v61ad_kv_weight_token_budget_replay_summary.csv", "source_v61ad/v61ad_kv_weight_token_budget_replay_summary.csv"),
    (v61ad_dir / "kv_weight_token_budget_rows.csv", "source_v61ad/kv_weight_token_budget_rows.csv"),
    (v61ad_dir / "kv_weight_token_budget_metric_rows.csv", "source_v61ad/kv_weight_token_budget_metric_rows.csv"),
    (v61ad_dir / "sha256_manifest.csv", "source_v61ad/sha256_manifest.csv"),
    (results / "v53r_complete_source_review_packet_summary.csv", "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (v53r_dir / "review_query_packet_rows.csv", "source_v53r/review_query_packet_rows.csv"),
    (v53r_dir / "review_queue_rows.csv", "source_v53r/review_queue_rows.csv"),
    (v53r_dir / "review_packet_metric_rows.csv", "source_v53r/review_packet_metric_rows.csv"),
    (v53r_dir / "sha256_manifest.csv", "source_v53r/sha256_manifest.csv"),
    (results / "v61r_full_page_hash_sweep_plan_summary.csv", "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv"),
    (v61r_dir / "page_hash_sweep_metric_rows.csv", "source_v61r/page_hash_sweep_metric_rows.csv"),
    (v61r_dir / "sha256_manifest.csv", "source_v61r/sha256_manifest.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_summary.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61t_dir / "materialization_gap_rows.csv", "source_v61t/materialization_gap_rows.csv"),
    (v61t_dir / "sha256_manifest.csv", "source_v61t/sha256_manifest.csv"),
    (results / "v61w_materialization_admission_resume_plan_summary.csv", "source_v61w/v61w_materialization_admission_resume_plan_summary.csv"),
    (v61w_dir / "materialization_admission_rows.csv", "source_v61w/materialization_admission_rows.csv"),
    (v61w_dir / "sha256_manifest.csv", "source_v61w/sha256_manifest.csv"),
]:
    copy(src, rel)

query_packets = read_csv(v53r_dir / "review_query_packet_rows.csv")
runtime_budget_rows = read_csv(v61ad_dir / "kv_weight_token_budget_rows.csv")
if len(query_packets) != 1000:
    raise SystemExit("v61ae expects 1000 review query packet rows")
expected_runtime_budget_rows = int(v61ad_summary["combined_kv_weight_budget_rows"])
if len(runtime_budget_rows) != expected_runtime_budget_rows:
    raise SystemExit(f"v61ae expects {expected_runtime_budget_rows} v61ad runtime budget rows")

materialization_ready = int(v61t_summary["local_checkpoint_materialization_ready"])
page_hash_ready = int(v61r_summary["full_safetensors_page_hash_binding_ready"])
materialization_admission_ready = int(v61w_summary["materialization_admission_ready"])
human_review_ready = int(v53r_summary["review_artifacts_ready"]) and int(v53r_summary["human_review_completed"])
local_identity_verified_shard_rows = int(v61t_summary["local_identity_verified_shard_rows"])
checkpoint_shard_rows = int(v61t_summary["checkpoint_shard_rows"])
verified_page_hash_rows = int(v61r_summary["verified_page_hash_rows"])
page_hash_sweep_plan_rows = int(v61r_summary["page_hash_sweep_plan_rows"])
local_checkpoint_status = "ready" if materialization_ready else "blocked"
full_page_hash_status = "ready" if page_hash_ready else "blocked"

candidate_rows = []
runtime_budget_ready_rows = 0
source_review_blocked_rows = 0
materialization_blocked_rows = 0
page_hash_blocked_rows = 0
admitted_rows = 0

for index, query in enumerate(query_packets):
    budget = runtime_budget_rows[index % len(runtime_budget_rows)]
    runtime_ready = int(budget["combined_kv_weight_budget_ready"])
    source_review_blocked = int(not human_review_ready)
    materialization_blocked = int(not materialization_ready or not materialization_admission_ready)
    page_hash_blocked = int(not page_hash_ready)
    admitted = int(runtime_ready and not source_review_blocked and not materialization_blocked and not page_hash_blocked)
    runtime_budget_ready_rows += runtime_ready
    source_review_blocked_rows += source_review_blocked
    materialization_blocked_rows += materialization_blocked
    page_hash_blocked_rows += page_hash_blocked
    admitted_rows += admitted
    candidate_rows.append(
        {
            "generation_candidate_id": f"v61ae_generation_candidate_{index:04d}",
            "review_query_packet_id": query["review_query_packet_id"],
            "query_id": query["query_id"],
            "owner_repo": query["owner_repo"],
            "audit_type": query["audit_type"],
            "expected_behavior": query["expected_behavior"],
            "negative_or_abstain": query["negative_or_abstain"],
            "source_span_id": query["source_span_id"],
            "source_file_sha256": query["source_file_sha256"],
            "runtime_budget_id": budget["combined_budget_id"],
            "context_profile_id": budget["context_profile_id"],
            "context_tokens": budget["context_tokens"],
            "runtime_budget_ready": str(runtime_ready),
            "source_review_artifacts_ready": str(int(human_review_ready)),
            "local_checkpoint_materialization_ready": str(materialization_ready),
            "materialization_admission_ready": str(materialization_admission_ready),
            "full_safetensors_page_hash_binding_ready": str(page_hash_ready),
            "generation_admitted": str(admitted),
            "source_review_blocked": str(source_review_blocked),
            "materialization_blocked": str(materialization_blocked),
            "page_hash_blocked": str(page_hash_blocked),
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "near_frontier_claim_ready": "0",
            "production_latency_claim_ready": "0",
            "real_release_package_ready": "0",
            "route_jump_rows": "0",
        }
    )

requirement_rows = [
    {
        "requirement": "runtime-budget-shape",
        "status": "ready",
        "evidence": "v61ad combined KV+weight token budget replay is ready",
        "ready_rows": str(int(v61ad_summary["combined_kv_weight_budget_ready_rows"])),
        "blocked_rows": "0",
    },
    {
        "requirement": "complete-source-generation-candidate-surface",
        "status": "ready",
        "evidence": "v53r supplies 1000 complete-source review query packets",
        "ready_rows": str(len(candidate_rows)),
        "blocked_rows": "0",
    },
    {
        "requirement": "human-source-review-artifacts",
        "status": "blocked",
        "evidence": "v53r review artifacts and human review are not returned",
        "ready_rows": "0",
        "blocked_rows": str(len(candidate_rows)),
    },
    {
        "requirement": "materialization-admission",
        "status": "blocked",
        "evidence": "v61w materialization admission remains blocked on SSD budget/local shards",
        "ready_rows": "0",
        "blocked_rows": str(len(candidate_rows)),
    },
    {
        "requirement": "local-checkpoint-materialization",
        "status": local_checkpoint_status,
        "evidence": f"v61t records {local_identity_verified_shard_rows}/{checkpoint_shard_rows} identity-verified local checkpoint shards",
        "ready_rows": str(len(candidate_rows) if materialization_ready else 0),
        "blocked_rows": str(0 if materialization_ready else len(candidate_rows)),
    },
    {
        "requirement": "full-safetensors-page-hash-binding",
        "status": full_page_hash_status,
        "evidence": f"v61r records {verified_page_hash_rows}/{page_hash_sweep_plan_rows} verified local page hashes",
        "ready_rows": str(len(candidate_rows) if page_hash_ready else 0),
        "blocked_rows": str(0 if page_hash_ready else len(candidate_rows)),
    },
    {
        "requirement": "real-model-generation",
        "status": "blocked",
        "evidence": "generation is not admitted until review, materialization, and full page-hash gates pass",
        "ready_rows": "0",
        "blocked_rows": str(len(candidate_rows)),
    },
]

metric_rows = [
    {
        "metric_id": "v61ae_real_generation_admission_metrics",
        "complete_source_query_rows": v53r_summary["complete_source_query_rows"],
        "core_answer_rows": v53r_summary["core_answer_rows"],
        "review_packet_ready": v53r_summary["review_packet_ready"],
        "review_artifacts_ready": v53r_summary["review_artifacts_ready"],
        "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
        "pending_review_queue_rows": v53r_summary["review_queue_rows"],
        "generation_candidate_rows": str(len(candidate_rows)),
        "generation_admitted_rows": str(admitted_rows),
        "runtime_budget_ready_rows": str(runtime_budget_ready_rows),
        "source_review_blocked_rows": str(source_review_blocked_rows),
        "materialization_blocked_rows": str(materialization_blocked_rows),
        "page_hash_blocked_rows": str(page_hash_blocked_rows),
        "local_identity_verified_shard_rows": v61t_summary["local_identity_verified_shard_rows"],
        "full_page_hash_verified_rows": v61r_summary["verified_page_hash_rows"],
        "page_hash_sweep_plan_rows": v61r_summary["page_hash_sweep_plan_rows"],
        "materialization_admission_ready": v61w_summary["materialization_admission_ready"],
        "local_checkpoint_materialization_ready": v61t_summary["local_checkpoint_materialization_ready"],
        "full_safetensors_page_hash_binding_ready": v61r_summary["full_safetensors_page_hash_binding_ready"],
        "real_generation_admission_ready": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "route_jump_rows": "0",
    }
]

runtime_gap_rows = [
    {"gap": "v61ad-runtime-budget-input", "status": "ready", "evidence": "combined KV+weight token-budget replay is ready"},
    {"gap": "v53r-complete-source-review-packet-input", "status": "ready", "evidence": "1000 complete-source query packets and 7000 answer review packets are prepared"},
    {"gap": "generation-candidate-surface", "status": "ready", "evidence": "1000 generation candidate rows are emitted"},
    {"gap": "human-source-review-artifacts", "status": "blocked", "evidence": "review_artifacts_ready=0 and human_review_completed=0"},
    {"gap": "materialization-admission", "status": "blocked", "evidence": "materialization_admission_ready=0"},
    {
        "gap": "local-checkpoint-materialization",
        "status": local_checkpoint_status,
        "evidence": f"local_identity_verified_shard_rows={local_identity_verified_shard_rows}/{checkpoint_shard_rows}",
    },
    {
        "gap": "full-safetensors-page-hash-binding",
        "status": full_page_hash_status,
        "evidence": f"verified_page_hash_rows={verified_page_hash_rows}/{page_hash_sweep_plan_rows}",
    },
    {"gap": "actual-model-generation", "status": "blocked", "evidence": "generation admission has 0 admitted candidate rows"},
    {"gap": "near-frontier-quality", "status": "blocked", "evidence": "quality claims require real generation and review"},
    {"gap": "production-latency", "status": "blocked", "evidence": "admission gate is not production latency evidence"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]

decision_rows = [
    {"gate": "v61ad-runtime-budget-input", "status": "pass", "reason": "v61ad budget replay is ready"},
    {"gate": "v53r-complete-source-review-packet-input", "status": "pass", "reason": "v53r review packet is ready"},
    {"gate": "generation-candidate-surface", "status": "pass", "reason": "1000 generation candidate rows are emitted"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "metadata only; checkpoint payload bytes remain outside the repository"},
    {"gate": "human-source-review-artifacts", "status": "blocked", "reason": "human/source review artifacts are not returned"},
    {"gate": "materialization-admission", "status": "blocked", "reason": "SSD budget and local shard requirements are not met"},
    {
        "gate": "local-checkpoint-materialization",
        "status": "pass" if materialization_ready else "blocked",
        "reason": f"{local_identity_verified_shard_rows}/{checkpoint_shard_rows} local shards are identity verified",
    },
    {
        "gate": "full-safetensors-page-hash-binding",
        "status": "pass" if page_hash_ready else "blocked",
        "reason": f"{verified_page_hash_rows}/{page_hash_sweep_plan_rows} local page hashes are verified",
    },
    {"gate": "real-model-generation", "status": "blocked", "reason": "generation admission has 0 admitted candidate rows"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "near-frontier quality requires real generation and review"},
    {"gate": "production-latency", "status": "blocked", "reason": "admission gate is not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]

write_csv(run_dir / "real_generation_candidate_rows.csv", list(candidate_rows[0].keys()), candidate_rows)
write_csv(run_dir / "real_generation_admission_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)
write_csv(run_dir / "real_generation_admission_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

summary = {
    "v61ae_real_generation_admission_gate_ready": "1",
    "v61ad_kv_weight_token_budget_replay_ready": v61ad_summary["v61ad_kv_weight_token_budget_replay_ready"],
    "v53r_complete_source_review_packet_ready": v53r_summary["v53r_complete_source_review_packet_ready"],
    "v61r_full_page_hash_sweep_plan_ready": v61r_summary["v61r_full_page_hash_sweep_plan_ready"],
    "v61t_local_checkpoint_materialization_verifier_ready": v61t_summary["v61t_local_checkpoint_materialization_verifier_ready"],
    "v61w_materialization_admission_resume_plan_ready": v61w_summary["v61w_materialization_admission_resume_plan_ready"],
    "model_id": model_id,
    "complete_source_query_rows": v53r_summary["complete_source_query_rows"],
    "core_answer_rows": v53r_summary["core_answer_rows"],
    "review_packet_ready": v53r_summary["review_packet_ready"],
    "review_artifacts_ready": v53r_summary["review_artifacts_ready"],
    "warehouse_root_override_supplied": str(int(bool(warehouse_root_override))),
    "pending_review_queue_rows": v53r_summary["review_queue_rows"],
    "generation_candidate_rows": str(len(candidate_rows)),
    "generation_admitted_rows": str(admitted_rows),
    "runtime_budget_ready_rows": str(runtime_budget_ready_rows),
    "source_review_blocked_rows": str(source_review_blocked_rows),
    "materialization_blocked_rows": str(materialization_blocked_rows),
    "page_hash_blocked_rows": str(page_hash_blocked_rows),
    "local_identity_verified_shard_rows": v61t_summary["local_identity_verified_shard_rows"],
    "checkpoint_shard_rows": v61t_summary["checkpoint_shard_rows"],
    "full_page_hash_verified_rows": v61r_summary["verified_page_hash_rows"],
    "page_hash_sweep_plan_rows": v61r_summary["page_hash_sweep_plan_rows"],
    "materialization_admission_ready": v61w_summary["materialization_admission_ready"],
    "local_checkpoint_materialization_ready": v61t_summary["local_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61r_summary["full_safetensors_page_hash_binding_ready"],
    "real_generation_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

manifest = {
    "artifact": "v61ae_real_generation_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "v61ae_real_generation_admission_gate_ready": 1,
    "generation_candidate_rows": len(candidate_rows),
    "generation_admitted_rows": admitted_rows,
    "runtime_budget_ready_rows": runtime_budget_ready_rows,
    "source_review_blocked_rows": source_review_blocked_rows,
    "materialization_blocked_rows": materialization_blocked_rows,
    "page_hash_blocked_rows": page_hash_blocked_rows,
    "warehouse_root_override_supplied": int(bool(warehouse_root_override)),
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "human_source_review_artifacts",
        "materialization_admission",
        "local_checkpoint_materialization",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "near_frontier_quality",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61ae_real_generation_admission_gate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61ae Real Generation Admission Gate Boundary

This artifact binds v61ad runtime-budget evidence, v53r complete-source review
packets, and v61r/v61t/v61w materialization/page-hash state into a real
generation admission gate. It does not execute Mixtral generation.

Evidence emitted:

- complete_source_query_rows={v53r_summary['complete_source_query_rows']}
- core_answer_rows={v53r_summary['core_answer_rows']}
- review_packet_ready={v53r_summary['review_packet_ready']}
- review_artifacts_ready={v53r_summary['review_artifacts_ready']}
- warehouse_root_override_supplied={int(bool(warehouse_root_override))}
- pending_review_queue_rows={v53r_summary['review_queue_rows']}
- generation_candidate_rows={len(candidate_rows)}
- generation_admitted_rows={admitted_rows}
- runtime_budget_ready_rows={runtime_budget_ready_rows}
- source_review_blocked_rows={source_review_blocked_rows}
- materialization_blocked_rows={materialization_blocked_rows}
- page_hash_blocked_rows={page_hash_blocked_rows}
- local_identity_verified_shard_rows={v61t_summary['local_identity_verified_shard_rows']}
- checkpoint_shard_rows={v61t_summary['checkpoint_shard_rows']}
- full_page_hash_verified_rows={v61r_summary['verified_page_hash_rows']}
- page_hash_sweep_plan_rows={v61r_summary['page_hash_sweep_plan_rows']}
- real_generation_admission_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- human_source_review_artifacts=blocked
- materialization_admission_ready=0
- local_checkpoint_materialization_ready={v61t_summary['local_checkpoint_materialization_ready']}
- full_safetensors_page_hash_binding_ready={v61r_summary['full_safetensors_page_hash_binding_ready']}
- actual_model_generation_ready=0
- near_frontier_claim_ready=0
- production_latency_claim_ready=0
- real_release_package_ready=0

This is an admission gate over existing evidence. It is not full checkpoint
materialization, full page-hash coverage, real Mixtral generation,
near-frontier quality, production latency, or release evidence.
"""
(run_dir / "V61AE_REAL_GENERATION_ADMISSION_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ae_real_generation_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
