#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dh_post_full_shard_claim_audit_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/audit_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61DH_REUSE_EXISTING="${V61DH_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dh_post_full_shard_claim_audit_gate.sh" >/dev/null

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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v61dh summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v61dh_post_full_shard_claim_audit_gate_ready": "1",
    "claim_audit_ready": "1",
    "claim_rows": "15",
    "allowed_claim_rows": "7",
    "blocked_claim_rows": "8",
    "claim_invariant_rows": "6",
    "claim_invariant_pass_rows": "6",
    "v52_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "comparison_30b_150b_wording_status": "allowed-with-disclosure",
    "v53_machine_complete_source_surface_ready": "1",
    "complete_source_repo_count": "10",
    "complete_source_query_rows": "1000",
    "core_answer_rows": "7000",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "v53_ready": "0",
    "v61_post_full_shard_runtime_evidence_ready": "1",
    "ready_evidence_rows": "9",
    "blocked_evidence_rows": "7",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "runtime_admission_accepted_rows": "1000",
    "generation_execution_admitted_rows": "0",
    "actual_model_generation_ready": "0",
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dh {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_full_shard_claim_audit_rows.csv",
    "post_full_shard_claim_invariant_rows.csv",
    "V61DH_POST_FULL_SHARD_CLAIM_AUDIT_GATE_BOUNDARY.md",
    "v61dh_post_full_shard_claim_audit_gate_manifest.json",
    "source_v52y/v52y_f_optional_final_policy_summary.csv",
    "source_v52y/f_optional_final_rows.csv",
    "source_v52y/comparison_wording_rows.csv",
    "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv",
    "source_v53t/complete_source_audit_claim_rows.csv",
    "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "source_v61dg/runtime_evidence_claim_boundary_rows.csv",
    "source_v61dg/post_full_shard_runtime_evidence_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dh artifact: {rel}")

claim_rows = read_csv(run_dir / "post_full_shard_claim_audit_rows.csv")
if len(claim_rows) != 15:
    raise SystemExit("v61dh expected 15 claim rows")
allowed_statuses = {"allowed", "allowed-with-disclosure", "allowed-with-boundary"}
allowed_ids = {row["claim_id"] for row in claim_rows if row["status"] in allowed_statuses}
blocked_ids = {row["claim_id"] for row in claim_rows if row["status"] == "blocked"}
for claim_id in [
    "v52-measured-baseline-registry",
    "v52-30b-150b-class-comparison-surface",
    "v53-complete-source-machine-surface",
    "v61-full-shard-runtime-evidence",
    "v61-rocm-page-kernel-timing",
    "v61-kv-residency-policy",
    "v61-source-bound-qa-command-pass",
]:
    if claim_id not in allowed_ids:
        raise SystemExit(f"v61dh claim should be allowed/boundary: {claim_id}")
for claim_id in [
    "measured-100b-plus-hosted-baseline-result",
    "v53-ready",
    "actual-mixtral-generation",
    "production-latency",
    "near-frontier-quality",
    "v1-comparison-ready",
    "real-release-package",
    "route-memory-beats-30b-150b",
]:
    if claim_id not in blocked_ids:
        raise SystemExit(f"v61dh claim should stay blocked: {claim_id}")

invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "post_full_shard_claim_invariant_rows.csv")}
for invariant_id in [
    "f-optional-final-disposition",
    "v53-machine-surface-ready",
    "v53-human-review-not-accepted",
    "v61-runtime-evidence-ready",
    "actual-generation-not-claimed",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61dh invariant should pass: {invariant_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "claim-audit-ready",
    "allowed-claim-boundary",
    "blocked-claim-boundary",
    "v52-30b-150b-wording",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61dh decision should pass: {gate}")
for gate in [
    "v53-ready",
    "actual-model-generation",
    "v1-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61dh decision should stay blocked: {gate}")

boundary = (run_dir / "V61DH_POST_FULL_SHARD_CLAIM_AUDIT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "claim_rows=15",
    "allowed_claim_rows=7",
    "blocked_claim_rows=8",
    "claim_audit_ready=1",
    "f_optional_final_disposition=deferred-with-reason-final",
    "comparison_30b_150b_wording_status=allowed-with-disclosure",
    "v53_machine_complete_source_surface_ready=1",
    "accepted_human_review_rows=0/7000",
    "accepted_adjudication_rows=0/1000",
    "v61_post_full_shard_runtime_evidence_ready=1",
    "generation_execution_admitted_rows=0",
    "actual_model_generation_ready=0",
    "v1_0_comparison_ready=0",
    "real_release_package_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dh boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61dh_post_full_shard_claim_audit_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61dh_post_full_shard_claim_audit_gate_ready") != 1:
    raise SystemExit("v61dh manifest readiness mismatch")
if manifest.get("claim_audit_ready") != 1:
    raise SystemExit("v61dh manifest should mark claim audit ready")
if manifest.get("v53_ready") != 0 or manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61dh manifest must keep v53/generation blocked")
if manifest.get("v1_0_comparison_ready") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v61dh manifest must keep v1/release blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61dh manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dh sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dh produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dh post-full-shard claim audit gate smoke passed"
