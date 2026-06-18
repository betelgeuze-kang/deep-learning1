#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ez_active_goal_post_ey_status_refresh"
RUN_ID="${V61EZ_RUN_ID:-refresh_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ez_active_goal_post_ey_status_refresh_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ei_active_goal_post_eh_status_refresh.sh" >/dev/null
V61EY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ey_generation_acceptance_closure_handoff_bundle.sh" >/dev/null

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


def ready_status(flag):
    return "ready" if flag else "blocked"


sources = {
    "v61ei_summary": results / "v61ei_active_goal_post_eh_status_refresh_summary.csv",
    "v61ei_decision": results / "v61ei_active_goal_post_eh_status_refresh_decision.csv",
    "v61ei_sections": results / "v61ei_active_goal_post_eh_status_refresh/refresh_001/post_eh_objective_section_rows.csv",
    "v61ei_requirements": results / "v61ei_active_goal_post_eh_status_refresh/refresh_001/post_eh_requirement_rows.csv",
    "v61ei_claims": results / "v61ei_active_goal_post_eh_status_refresh/refresh_001/post_eh_claim_boundary_rows.csv",
    "v61ei_next_actions": results / "v61ei_active_goal_post_eh_status_refresh/refresh_001/post_eh_next_action_rows.csv",
    "v61ey_summary": results / "v61ey_generation_acceptance_closure_handoff_bundle_summary.csv",
    "v61ey_decision": results / "v61ey_generation_acceptance_closure_handoff_bundle_decision.csv",
    "v61ey_stage": results / "v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/generation_acceptance_closure_handoff_stage_rows.csv",
    "v61ey_metric": results / "v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/generation_acceptance_closure_handoff_metric_rows.csv",
    "v61ey_bundle_manifest": results / "v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/handoff_bundle/BUNDLE_MANIFEST.json",
    "v61ey_file_rows": results / "v61ey_generation_acceptance_closure_handoff_bundle/bundle_001/generation_acceptance_closure_handoff_bundle_file_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ez source {key}: {path}")

for key, path in sources.items():
    family = "v61ei" if key.startswith("v61ei") else "v61ey"
    copy(path, f"source_{family}/{path.name}")

v61ei = read_csv(sources["v61ei_summary"])[0]
v61ey = read_csv(sources["v61ey_summary"])[0]
v61ey_manifest = json.loads(sources["v61ey_bundle_manifest"].read_text(encoding="utf-8"))

acceptance_handoff_ready = int(v61ey["v61ey_generation_acceptance_closure_handoff_bundle_ready"] == "1")
metadata_bundle_ready = int(
    v61ey["handoff_bundle_file_rows"] == v61ey["metadata_only_bundle_file_rows"]
    and int(v61ey["handoff_bundle_file_rows"]) > 0
)
closure_ready = int(v61ey["generation_acceptance_closure_ready"])
actual_ready = 0
v52_ready = v61ei["v52_ready"] == "1"

section_rows = [
    {
        "section_id": "v52-f-optional-policy",
        "status": "ready" if v52_ready else "blocked-d-e-release-baseline",
        "evidence_source": "v61ei",
        "ready": v61ei["v52_ready"],
        "actual_value": v61ei["f_optional_final_disposition"],
        "next_required_artifact": "none for measured-registry wording scope" if v52_ready else "accepted 30B and 70B PM/release baseline evidence",
    },
    {
        "section_id": "v53-complete-source-machine-surface",
        "status": "ready",
        "evidence_source": "v61ei",
        "ready": v61ei["v53_machine_complete_source_surface_ready"],
        "actual_value": f"{v61ei['complete_source_repo_count']} repos / {v61ei['complete_source_query_rows']} queries",
        "next_required_artifact": "real review/adjudication return",
    },
    {
        "section_id": "v61-real-model-page-runtime-evidence",
        "status": "ready",
        "evidence_source": "v61ei",
        "ready": v61ei["real_manifest_runtime_evidence_ready"],
        "actual_value": f"{v61ei['ready_checkpoint_materialization_shard_rows']}/{v61ei['checkpoint_shard_rows']} shards and {v61ei['total_verified_page_hash_rows']}/{v61ei['total_required_page_hash_rows']} page hashes",
        "next_required_artifact": "real review return and generation return",
    },
    {
        "section_id": "v61-real-generation-return-surface",
        "status": "packet-ready-real-evidence-blocked",
        "evidence_source": "v61ei",
        "ready": v61ei["generation_return_packet_ready"],
        "actual_value": f"{v61ei['required_generation_result_artifact_rows']} artifacts / {v61ei['required_generation_result_field_rows']} fields",
        "next_required_artifact": "real generation-result artifacts",
    },
    {
        "section_id": "v61-acceptance-closure-handoff",
        "status": "handoff-ready-real-closure-blocked",
        "evidence_source": "v61ey",
        "ready": str(acceptance_handoff_ready),
        "actual_value": f"{v61ey['handoff_stage_rows']} handoff stages / {v61ey['ready_handoff_stage_rows']} ready / {v61ey['open_blocker_rows']} blockers",
        "next_required_artifact": "real v61bt/v61de/v61cu acceptance rows",
    },
]
write_csv(run_dir / "post_ey_objective_section_rows.csv", list(section_rows[0].keys()), section_rows)

requirements = [
    ("v52-f-optional-final-disposition", v61ei["v52_ready"] == "1", "v61ei", "F supplied or deferred-with-reason final", v61ei["f_optional_final_disposition"], ""),
    ("v53-complete-source-machine-surface", v61ei["v53_machine_complete_source_surface_ready"] == "1", "v61ei", "10+ repos and 1000+ queries", f"{v61ei['complete_source_repo_count']}/{v61ei['complete_source_query_rows']}", ""),
    ("v53-review-return-accepted", v61ei["v53_ready"] == "1", "v61ei", "v53_ready=1", v61ei["v53_ready"], "review/adjudication return rows are missing"),
    ("v61-real-model-page-runtime-evidence", v61ei["real_manifest_runtime_evidence_ready"] == "1", "v61ei", "runtime evidence ready", v61ei["real_manifest_runtime_evidence_ready"], ""),
    ("v61-real-generation-return-packet", v61ei["generation_return_packet_ready"] == "1", "v61ei", "return packet ready", v61ei["generation_return_packet_ready"], ""),
    ("v61-acceptance-closure-handoff-bundle", acceptance_handoff_ready == 1, "v61ey", "handoff bundle ready", v61ey["v61ey_generation_acceptance_closure_handoff_bundle_ready"], ""),
    ("v61-acceptance-handoff-metadata-only", metadata_bundle_ready == 1, "v61ey", "all bundle files metadata-only", f"{v61ey['metadata_only_bundle_file_rows']}/{v61ey['handoff_bundle_file_rows']}", ""),
    ("v61-acceptance-bridge-candidate", v61ey["selected_acceptance_bridge_candidate_ready"] == "1", "v61ey", "candidate bridge ready", v61ey["selected_acceptance_bridge_candidate_ready"], "no real return bundle selected in canonical path"),
    ("v61-acceptance-bridge-real", v61ey["selected_acceptance_bridge_real_ready"] == "1", "v61ey", "real bridge ready", v61ey["selected_acceptance_bridge_real_ready"], "fixture/canonical logistics are not real acceptance"),
    ("v61-generation-acceptance-closure", closure_ready == 1, "v61ey", "closure ready", v61ey["generation_acceptance_closure_ready"], "v61bt/v61de/v61cu acceptance rows remain open"),
    ("v61-actual-model-generation", actual_ready == 1, "v61ey", "actual_model_generation_ready=1", "0", "actual generation remains unproven"),
    ("v1-release-and-quality-claims", v61ei["real_release_package_ready"] == "1", "v61ei/v61ey", "release/latency/quality evidence", f"release={v61ei['real_release_package_ready']}; latency={v61ei['production_latency_claim_ready']}; quality={v61ei['near_frontier_claim_ready']}", "production latency, near-frontier quality, and release evidence are missing"),
]
requirement_rows = [
    {
        "requirement_id": req_id,
        "status": ready_status(ready),
        "ready": str(int(bool(ready))),
        "evidence_source": source,
        "required_value": required,
        "actual_value": actual,
        "blocking_reason": blocker,
    }
    for req_id, ready, source, required, actual, blocker in requirements
]
write_csv(run_dir / "post_ey_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

claim_rows = [
    (
        "v52-30b-150b-comparison-wording",
        "allowed-with-disclosure" if v52_ready else "blocked",
        "requires D/E PM/release readiness plus F final disposition",
    ),
    ("v53-complete-source-machine-surface", "allowed-with-disclosure", "machine surface is ready; review return remains blocked"),
    ("v61-real-model-page-runtime-evidence", "allowed-with-boundary", "full shard/page hash/runtime evidence is ready"),
    ("v61-real-generation-return-packet", "allowed-with-boundary", "return packet/schema is ready; real artifacts are missing"),
    ("v61-acceptance-closure-handoff-bundle", "allowed-with-boundary", "metadata-only handoff bundle is ready"),
    ("actual-mixtral-generation", "blocked", "requires accepted real v61bt/v61de/v61cu rows"),
    ("production-latency", "blocked", "requires accepted real latency rows"),
    ("near-frontier-quality", "blocked", "requires external quality review"),
    ("release-package", "blocked", "requires release audit evidence"),
]
claim_dicts = [
    {"claim_id": claim_id, "status": status, "required_disclosure_or_blocker": detail}
    for claim_id, status, detail in claim_rows
]
write_csv(run_dir / "post_ey_claim_boundary_rows.csv", list(claim_dicts[0].keys()), claim_dicts)

next_action_rows = [
    {
        "action_id": "01-real-v53-review-return",
        "status": "external-return-required",
        "required_artifact": "7000 human/source review rows, 1000 adjudication rows, reviewer identity/conflict rows, acceptance summary",
    },
    {
        "action_id": "02-real-return-bundle-through-v61et-v61ew",
        "status": "blocked-by-review-return",
        "required_artifact": "non-fixture returned bundle with dispatch receipt, generation artifacts, prerequisite binding, and provenance",
    },
    {
        "action_id": "03-close-v61bt-v61de-v61cu-acceptance",
        "status": "blocked-by-real-return-bundle",
        "required_artifact": "accepted v61bt result rows, v61de post-review handoff, and v61cu final acceptance rows",
    },
    {
        "action_id": "04-refresh-v61ey-v61ez",
        "status": "blocked-by-acceptance-closure",
        "required_artifact": "updated handoff bundle and post-ey status after real closure",
    },
    {
        "action_id": "05-latency-quality-release-audit",
        "status": "blocked-by-actual-generation",
        "required_artifact": "production-ish latency report, near-frontier quality review, and release audit evidence",
    },
]
write_csv(run_dir / "post_ey_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

ready_requirement_rows = sum(row["ready"] == "1" for row in requirement_rows)
blocked_requirement_rows = len(requirement_rows) - ready_requirement_rows
allowed_claim_rows = sum(row["status"].startswith("allowed") for row in claim_dicts)
blocked_claim_rows = len(claim_dicts) - allowed_claim_rows
ready_section_rows = sum(row["ready"] == "1" for row in section_rows)

summary = {
    "v61ez_active_goal_post_ey_status_refresh_ready": "1",
    "v61ei_active_goal_post_eh_status_refresh_ready": v61ei["v61ei_active_goal_post_eh_status_refresh_ready"],
    "v61ey_generation_acceptance_closure_handoff_bundle_ready": v61ey["v61ey_generation_acceptance_closure_handoff_bundle_ready"],
    "section_rows": str(len(section_rows)),
    "ready_section_rows": str(ready_section_rows),
    "requirement_rows": str(len(requirement_rows)),
    "ready_requirement_rows": str(ready_requirement_rows),
    "blocked_requirement_rows": str(blocked_requirement_rows),
    "claim_boundary_rows": str(len(claim_dicts)),
    "allowed_claim_boundary_rows": str(allowed_claim_rows),
    "blocked_claim_boundary_rows": str(blocked_claim_rows),
    "next_action_rows": str(len(next_action_rows)),
    "v52_ready": v61ei["v52_ready"],
    "f_optional_final_disposition": v61ei["f_optional_final_disposition"],
    "v53_machine_complete_source_surface_ready": v61ei["v53_machine_complete_source_surface_ready"],
    "v53_ready": v61ei["v53_ready"],
    "real_manifest_runtime_evidence_ready": v61ei["real_manifest_runtime_evidence_ready"],
    "full_checkpoint_materialization_ready": v61ei["full_checkpoint_materialization_ready"],
    "full_safetensors_page_hash_binding_ready": v61ei["full_safetensors_page_hash_binding_ready"],
    "generation_return_packet_ready": v61ei["generation_return_packet_ready"],
    "acceptance_closure_handoff_bundle_ready": str(acceptance_handoff_ready),
    "handoff_bundle_file_rows": v61ey["handoff_bundle_file_rows"],
    "metadata_only_bundle_file_rows": v61ey["metadata_only_bundle_file_rows"],
    "ready_work_order_rows": v61ey["ready_work_order_rows"],
    "open_blocker_rows": v61ey["open_blocker_rows"],
    "selected_acceptance_bridge_candidate_ready": v61ey["selected_acceptance_bridge_candidate_ready"],
    "selected_acceptance_bridge_real_ready": v61ey["selected_acceptance_bridge_real_ready"],
    "generation_acceptance_closure_ready": v61ey["generation_acceptance_closure_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ez": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "post-ey-status-refresh", "status": "pass", "reason": "v61ei and v61ey state rows emitted"},
    {"gate": "v52-f-optional-policy", "status": "pass", "reason": f"F={v61ei['f_optional_final_disposition']}"},
    {"gate": "v53-complete-source-machine-surface", "status": "pass", "reason": "machine surface ready"},
    {"gate": "v53-review-return", "status": "blocked", "reason": "real review/adjudication return is missing"},
    {"gate": "v61-real-model-page-runtime-evidence", "status": "pass", "reason": "full shard/page hash/runtime evidence ready"},
    {"gate": "v61-generation-return-packet", "status": "pass", "reason": "five-artifact return packet ready"},
    {"gate": "v61-acceptance-closure-handoff", "status": "pass", "reason": "metadata-only handoff bundle ready"},
    {"gate": "v61-generation-acceptance-closure", "status": "blocked", "reason": "real v61bt/v61de/v61cu acceptance rows are missing"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual generation remains unproven"},
    {"gate": "latency-quality-release", "status": "blocked", "reason": "latency, quality, and release evidence are missing"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EZ_ACTIVE_GOAL_POST_EY_STATUS_REFRESH_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ez Active Goal Post-v61ey Status Refresh",
            "",
            "This refresh records the active objective after the v61ey generation",
            "acceptance closure handoff bundle. It does not create review rows,",
            "generation rows, latency evidence, quality evidence, or release",
            "evidence.",
            "",
            f"- v52_ready={summary['v52_ready']} with F={summary['f_optional_final_disposition']}",
            f"- v53_machine_complete_source_surface_ready={summary['v53_machine_complete_source_surface_ready']}",
            f"- v53_ready={summary['v53_ready']}",
            f"- real_manifest_runtime_evidence_ready={summary['real_manifest_runtime_evidence_ready']}",
            f"- full_checkpoint_materialization_ready={summary['full_checkpoint_materialization_ready']}",
            f"- full_safetensors_page_hash_binding_ready={summary['full_safetensors_page_hash_binding_ready']}",
            f"- generation_return_packet_ready={summary['generation_return_packet_ready']}",
            f"- acceptance_closure_handoff_bundle_ready={summary['acceptance_closure_handoff_bundle_ready']}",
            f"- handoff_bundle_file_rows={summary['handoff_bundle_file_rows']}",
            f"- metadata_only_bundle_file_rows={summary['metadata_only_bundle_file_rows']}",
            f"- ready_work_order_rows={summary['ready_work_order_rows']}",
            f"- open_blocker_rows={summary['open_blocker_rows']}",
            f"- selected_acceptance_bridge_candidate_ready={summary['selected_acceptance_bridge_candidate_ready']}",
            f"- selected_acceptance_bridge_real_ready={summary['selected_acceptance_bridge_real_ready']}",
            f"- generation_acceptance_closure_ready={summary['generation_acceptance_closure_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "",
            "Allowed wording: v61 acceptance-closure handoff bundle is ready as",
            "metadata-only operator evidence. Blocked wording: actual Mixtral",
            "generation, production latency, near-frontier quality, v1.0 comparison",
            "readiness, and release readiness.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61ez_active_goal_post_ey_status_refresh",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
    "source_v61ey_bundle_manifest": v61ey_manifest,
}
(run_dir / "v61ez_active_goal_post_ey_status_refresh_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ez_active_goal_post_ey_status_refresh_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
