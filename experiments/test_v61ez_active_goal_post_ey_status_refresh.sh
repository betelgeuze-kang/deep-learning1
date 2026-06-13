#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ez_active_goal_post_ey_status_refresh"
RUN_DIR="$RESULTS_DIR/$PREFIX/refresh_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61EZ_REUSE_EXISTING="${V61EZ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ez_active_goal_post_ey_status_refresh.sh" >/dev/null

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
    "v61ez_active_goal_post_ey_status_refresh_ready": "1",
    "v61ei_active_goal_post_eh_status_refresh_ready": "1",
    "v61ey_generation_acceptance_closure_handoff_bundle_ready": "1",
    "section_rows": "5",
    "ready_section_rows": "5",
    "requirement_rows": "12",
    "ready_requirement_rows": "6",
    "blocked_requirement_rows": "6",
    "claim_boundary_rows": "9",
    "allowed_claim_boundary_rows": "5",
    "blocked_claim_boundary_rows": "4",
    "next_action_rows": "5",
    "v52_ready": "1",
    "f_optional_final_disposition": "deferred-with-reason-final",
    "v53_machine_complete_source_surface_ready": "1",
    "v53_ready": "0",
    "real_manifest_runtime_evidence_ready": "1",
    "full_checkpoint_materialization_ready": "1",
    "full_safetensors_page_hash_binding_ready": "1",
    "generation_return_packet_ready": "1",
    "acceptance_closure_handoff_bundle_ready": "1",
    "handoff_bundle_file_rows": "11",
    "metadata_only_bundle_file_rows": "11",
    "ready_work_order_rows": "2",
    "open_blocker_rows": "11",
    "selected_acceptance_bridge_candidate_ready": "0",
    "selected_acceptance_bridge_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ez": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ez {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_ey_objective_section_rows.csv",
    "post_ey_requirement_rows.csv",
    "post_ey_claim_boundary_rows.csv",
    "post_ey_next_action_rows.csv",
    "V61EZ_ACTIVE_GOAL_POST_EY_STATUS_REFRESH_BOUNDARY.md",
    "v61ez_active_goal_post_ey_status_refresh_manifest.json",
    "source_v61ei/post_eh_requirement_rows.csv",
    "source_v61ei/post_eh_claim_boundary_rows.csv",
    "source_v61ei/post_eh_next_action_rows.csv",
    "source_v61ey/generation_acceptance_closure_handoff_stage_rows.csv",
    "source_v61ey/generation_acceptance_closure_handoff_metric_rows.csv",
    "source_v61ey/BUNDLE_MANIFEST.json",
    "source_v61ey/generation_acceptance_closure_handoff_bundle_file_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ez artifact: {rel}")

sections = read_csv(run_dir / "post_ey_objective_section_rows.csv")
if len(sections) != 5:
    raise SystemExit("v61ez expected five section rows")
if any(row["ready"] != "1" for row in sections):
    raise SystemExit("v61ez section rows should all be machine/operator ready")

requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "post_ey_requirement_rows.csv")}
for requirement_id in [
    "v52-f-optional-final-disposition",
    "v53-complete-source-machine-surface",
    "v61-real-model-page-runtime-evidence",
    "v61-real-generation-return-packet",
    "v61-acceptance-closure-handoff-bundle",
    "v61-acceptance-handoff-metadata-only",
]:
    if requirements[requirement_id]["status"] != "ready":
        raise SystemExit(f"v61ez requirement should be ready: {requirement_id}")
for requirement_id in [
    "v53-review-return-accepted",
    "v61-acceptance-bridge-candidate",
    "v61-acceptance-bridge-real",
    "v61-generation-acceptance-closure",
    "v61-actual-model-generation",
    "v1-release-and-quality-claims",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61ez requirement should remain blocked: {requirement_id}")

claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "post_ey_claim_boundary_rows.csv")}
for claim_id in [
    "v52-30b-150b-comparison-wording",
    "v53-complete-source-machine-surface",
    "v61-real-model-page-runtime-evidence",
    "v61-real-generation-return-packet",
    "v61-acceptance-closure-handoff-bundle",
]:
    if not claims[claim_id].startswith("allowed"):
        raise SystemExit(f"v61ez claim should be allowed/boundary: {claim_id}")
for claim_id in [
    "actual-mixtral-generation",
    "production-latency",
    "near-frontier-quality",
    "release-package",
]:
    if claims[claim_id] != "blocked":
        raise SystemExit(f"v61ez claim should be blocked: {claim_id}")

next_actions = read_csv(run_dir / "post_ey_next_action_rows.csv")
if [row["action_id"] for row in next_actions] != [
    "01-real-v53-review-return",
    "02-real-return-bundle-through-v61et-v61ew",
    "03-close-v61bt-v61de-v61cu-acceptance",
    "04-refresh-v61ey-v61ez",
    "05-latency-quality-release-audit",
]:
    raise SystemExit("v61ez next action sequence mismatch")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "post-ey-status-refresh",
    "v52-f-optional-policy",
    "v53-complete-source-machine-surface",
    "v61-real-model-page-runtime-evidence",
    "v61-generation-return-packet",
    "v61-acceptance-closure-handoff",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ez gate should pass: {gate}")
for gate in [
    "v53-review-return",
    "v61-generation-acceptance-closure",
    "actual-model-generation",
    "latency-quality-release",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ez gate should be blocked: {gate}")

boundary = (run_dir / "V61EZ_ACTIVE_GOAL_POST_EY_STATUS_REFRESH_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v52_ready=1",
    "v53_machine_complete_source_surface_ready=1",
    "v53_ready=0",
    "real_manifest_runtime_evidence_ready=1",
    "generation_return_packet_ready=1",
    "acceptance_closure_handoff_bundle_ready=1",
    "handoff_bundle_file_rows=11",
    "metadata_only_bundle_file_rows=11",
    "open_blocker_rows=11",
    "generation_acceptance_closure_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ez boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ez_active_goal_post_ey_status_refresh_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ez_active_goal_post_ey_status_refresh_ready") != 1:
    raise SystemExit("v61ez manifest readiness mismatch")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ez manifest must keep actual generation blocked")
if manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v61ez manifest must keep release blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ez manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ez sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ez produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ez active goal post-ey status refresh smoke passed"
