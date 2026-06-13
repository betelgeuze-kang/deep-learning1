#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fb_post_ey_external_return_readiness_preflight"
RUN_ID="${V61FB_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V53_RETURN_BUNDLE_DIR="${V61FB_V53_RETURN_BUNDLE_DIR:-}"
V61_RETURN_BUNDLE_DIR="${V61FB_V61_RETURN_BUNDLE_DIR:-}"
V53_RETURN_PROVENANCE="${V61FB_V53_RETURN_PROVENANCE:-unspecified}"
V61_RETURN_PROVENANCE="${V61FB_V61_RETURN_PROVENANCE:-unspecified}"

if [[ "${V61FB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fb_post_ey_external_return_readiness_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fa_post_ey_acceptance_closure_execution_queue.sh" >/dev/null

if [[ -n "$V53_RETURN_BUNDLE_DIR" ]]; then
  V53AL_RETURN_BUNDLE_DIR="$V53_RETURN_BUNDLE_DIR" V53AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
else
  V53AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null
fi

if [[ -n "$V61_RETURN_BUNDLE_DIR" ]]; then
  V61ET_RETURN_BUNDLE_DIR="$V61_RETURN_BUNDLE_DIR" V61ET_RETURN_BUNDLE_PROVENANCE="$V61_RETURN_PROVENANCE" V61ET_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null
else
  V61ET_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V53_RETURN_BUNDLE_DIR" "$V61_RETURN_BUNDLE_DIR" "$V53_RETURN_PROVENANCE" "$V61_RETURN_PROVENANCE" <<'PY'
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
v53_bundle_arg = sys.argv[5].strip()
v61_bundle_arg = sys.argv[6].strip()
v53_provenance = sys.argv[7].strip() or "unspecified"
v61_provenance = sys.argv[8].strip() or "unspecified"
results = root / "results"
v53_bundle_dir = Path(v53_bundle_arg).expanduser().resolve() if v53_bundle_arg else None
v61_bundle_dir = Path(v61_bundle_arg).expanduser().resolve() if v61_bundle_arg else None


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


def status(flag):
    return "pass" if flag else "blocked"


source_paths = {
    "v61fa_summary": results / "v61fa_post_ey_acceptance_closure_execution_queue_summary.csv",
    "v61fa_decision": results / "v61fa_post_ey_acceptance_closure_execution_queue_decision.csv",
    "v61fa_phase": results / "v61fa_post_ey_acceptance_closure_execution_queue/queue_001/post_ey_acceptance_closure_execution_phase_rows.csv",
    "v61fa_command": results / "v61fa_post_ey_acceptance_closure_execution_queue/queue_001/post_ey_acceptance_closure_execution_command_rows.csv",
    "v53al_summary": results / "v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "v53al_decision": results / "v53al_complete_source_external_return_bundle_preflight_decision.csv",
    "v53al_rows": results / "v53al_complete_source_external_return_bundle_preflight/preflight_001/external_return_bundle_preflight_rows.csv",
    "v53al_family": results / "v53al_complete_source_external_return_bundle_preflight/preflight_001/external_return_bundle_preflight_family_rows.csv",
    "v61et_summary": results / "v61et_real_generation_intake_return_bundle_preflight_summary.csv",
    "v61et_decision": results / "v61et_real_generation_intake_return_bundle_preflight_decision.csv",
    "v61et_files": results / "v61et_real_generation_intake_return_bundle_preflight/preflight_001/real_generation_intake_return_bundle_file_rows.csv",
    "v61et_family": results / "v61et_real_generation_intake_return_bundle_preflight/preflight_001/real_generation_intake_return_bundle_family_rows.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fb source {key}: {path}")

for key, path in source_paths.items():
    if key.startswith("v61fa"):
        folder = "source_v61fa"
    elif key.startswith("v53al"):
        folder = "source_v53al"
    else:
        folder = "source_v61et"
    copy(path, f"{folder}/{path.name}")

v61fa = read_csv(source_paths["v61fa_summary"])[0]
v53al = read_csv(source_paths["v53al_summary"])[0]
v61et = read_csv(source_paths["v61et_summary"])[0]

v53_dir_supplied = int(v53_bundle_dir is not None)
v53_dir_exists = int(v53_bundle_dir is not None and v53_bundle_dir.is_dir())
v61_dir_supplied = int(v61_bundle_dir is not None)
v61_dir_exists = int(v61_bundle_dir is not None and v61_bundle_dir.is_dir())

v53_candidate = as_int(v53al, "return_bundle_preflight_pass")
v61_candidate = as_int(v61et, "return_bundle_candidate_preflight_ready")
v53_real = int(v53_candidate and v53_provenance == "real-external-return-bundle")
v61_real = as_int(v61et, "real_return_bundle_preflight_ready")
dual_candidate = int(v53_candidate and v61_candidate)
dual_real = int(v53_real and v61_real)

stage_rows = [
    {
        "stage_id": "01-source-v61fa-queue",
        "status": "ready",
        "ready": "1",
        "evidence": f"v61fa_ready={v61fa['v61fa_post_ey_acceptance_closure_execution_queue_ready']}",
        "blocking_reason": "",
    },
    {
        "stage_id": "02-v53al-preflight-surface",
        "status": "ready",
        "ready": "1",
        "evidence": f"preflight_surface_ready={v53al['preflight_surface_ready']}; rows={v53al['preflight_rows']}",
        "blocking_reason": "",
    },
    {
        "stage_id": "03-v61et-preflight-surface",
        "status": "ready",
        "ready": "1",
        "evidence": f"v61et_ready={v61et['v61et_real_generation_intake_return_bundle_preflight_ready']}; files={v61et['present_return_bundle_files']}/{v61et['required_return_bundle_files']}",
        "blocking_reason": "",
    },
    {
        "stage_id": "04-v53-external-return-candidate",
        "status": "ready" if v53_candidate else "blocked",
        "ready": str(v53_candidate),
        "evidence": f"return_bundle_preflight_pass={v53_candidate}",
        "blocking_reason": "" if v53_candidate else "v53 external return bundle has not passed preflight",
    },
    {
        "stage_id": "05-v53-external-return-real",
        "status": "ready" if v53_real else "blocked",
        "ready": str(v53_real),
        "evidence": f"v53_provenance={v53_provenance}",
        "blocking_reason": "" if v53_real else "v53 preflight needs explicit real-external-return-bundle provenance",
    },
    {
        "stage_id": "06-v61-generation-return-candidate",
        "status": "ready" if v61_candidate else "blocked",
        "ready": str(v61_candidate),
        "evidence": f"return_bundle_candidate_preflight_ready={v61_candidate}",
        "blocking_reason": "" if v61_candidate else "v61 generation return bundle has not passed candidate preflight",
    },
    {
        "stage_id": "07-v61-generation-return-real",
        "status": "ready" if v61_real else "blocked",
        "ready": str(v61_real),
        "evidence": f"real_return_bundle_preflight_ready={v61_real}; provenance={v61_provenance}",
        "blocking_reason": "" if v61_real else "v61 generation return bundle is not real/non-fixture",
    },
    {
        "stage_id": "08-dual-external-return-candidate",
        "status": "ready" if dual_candidate else "blocked",
        "ready": str(dual_candidate),
        "evidence": f"v53_candidate={v53_candidate}; v61_candidate={v61_candidate}",
        "blocking_reason": "" if dual_candidate else "both v53 and v61 return candidates must pass",
    },
    {
        "stage_id": "09-dual-external-return-real",
        "status": "ready" if dual_real else "blocked",
        "ready": str(dual_real),
        "evidence": f"v53_real={v53_real}; v61_real={v61_real}",
        "blocking_reason": "" if dual_real else "both v53 and v61 return bundles must be real",
    },
    {
        "stage_id": "10-actual-generation",
        "status": "blocked",
        "ready": "0",
        "evidence": "actual_model_generation_ready=0",
        "blocking_reason": "external return readiness preflight does not create generation evidence",
    },
]
write_csv(run_dir / "post_ey_external_return_readiness_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "source-v61fa-ready", "status": "pass", "required_value": "1", "actual_value": v61fa["v61fa_post_ey_acceptance_closure_execution_queue_ready"], "reason": "execution queue must exist"},
    {"requirement_id": "v53-return-bundle-dir-supplied", "status": status(v53_dir_supplied), "required_value": "1", "actual_value": str(v53_dir_supplied), "reason": "V61FB_V53_RETURN_BUNDLE_DIR must be supplied"},
    {"requirement_id": "v53-return-bundle-dir-exists", "status": status(v53_dir_exists), "required_value": "1", "actual_value": str(v53_dir_exists), "reason": "v53 return bundle directory must exist"},
    {"requirement_id": "v53-return-bundle-candidate", "status": status(v53_candidate), "required_value": "1", "actual_value": str(v53_candidate), "reason": "v53al preflight must pass"},
    {"requirement_id": "v53-return-bundle-real-provenance", "status": status(v53_real), "required_value": "real-external-return-bundle", "actual_value": v53_provenance, "reason": "fixture or unspecified provenance does not count as real"},
    {"requirement_id": "v61-return-bundle-dir-supplied", "status": status(v61_dir_supplied), "required_value": "1", "actual_value": str(v61_dir_supplied), "reason": "V61FB_V61_RETURN_BUNDLE_DIR must be supplied"},
    {"requirement_id": "v61-return-bundle-dir-exists", "status": status(v61_dir_exists), "required_value": "1", "actual_value": str(v61_dir_exists), "reason": "v61 return bundle directory must exist"},
    {"requirement_id": "v61-return-bundle-candidate", "status": status(v61_candidate), "required_value": "1", "actual_value": str(v61_candidate), "reason": "v61et candidate preflight must pass"},
    {"requirement_id": "v61-return-bundle-real", "status": status(v61_real), "required_value": "1", "actual_value": str(v61_real), "reason": "v61et real preflight requires non-fixture provenance"},
    {"requirement_id": "dual-candidate-preflight", "status": status(dual_candidate), "required_value": "1", "actual_value": str(dual_candidate), "reason": "both v53 and v61 candidates must pass"},
    {"requirement_id": "dual-real-preflight", "status": status(dual_real), "required_value": "1", "actual_value": str(dual_real), "reason": "both sides must be real before downstream closure"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "post_ey_external_return_readiness_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

command_rows = [
    {
        "command_id": "01-run-v53al-preflight",
        "ready_to_run_now": "1",
        "command": "V61FB_V53_RETURN_BUNDLE_DIR=<v53-return-bundle> ./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh",
        "purpose": "validate v53 external return bundle surface",
    },
    {
        "command_id": "02-run-v61et-preflight",
        "ready_to_run_now": "1",
        "command": "V61FB_V61_RETURN_BUNDLE_DIR=<v61-return-bundle> ./experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh",
        "purpose": "validate v61 generation-intake return bundle surface",
    },
    {
        "command_id": "03-refresh-v53-review-return",
        "ready_to_run_now": str(v53_real),
        "command": "V53Y_REVIEW_RETURN_DIR=<real-review-return> ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "purpose": "refresh review return after real v53 bundle is proven",
    },
    {
        "command_id": "04-fanout-v61-return-bundle",
        "ready_to_run_now": str(v61_real),
        "command": "V61EU_RETURN_BUNDLE_DIR=<real-v61-return-bundle> ./experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh",
        "purpose": "fan out real v61 return bundle",
    },
    {
        "command_id": "05-replay-v61-return-bundle",
        "ready_to_run_now": str(v61_real),
        "command": "V61EV_RETURN_BUNDLE_DIR=<real-v61-return-bundle> ./experiments/run_v61ev_return_bundle_downstream_replay_gate.sh",
        "purpose": "replay real v61 bundle downstream",
    },
    {
        "command_id": "06-refresh-acceptance-closure",
        "ready_to_run_now": str(dual_real),
        "command": "./experiments/run_v61ex_generation_acceptance_closure_work_order.sh",
        "purpose": "refresh closure only after both real return surfaces are ready",
    },
]
write_csv(run_dir / "post_ey_external_return_readiness_command_rows.csv", list(command_rows[0].keys()), command_rows)

runtime_gap_rows = [
    {"gap": row["stage_id"], "status": row["status"], "reason": row["blocking_reason"] or row["evidence"]}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
blocked_stage_rows = len(stage_rows) - ready_stage_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
pass_requirement_rows = sum(row["status"] == "pass" for row in requirement_rows)
blocked_requirement_rows = len(requirement_rows) - pass_requirement_rows

summary = {
    "v61fb_post_ey_external_return_readiness_preflight_ready": "1",
    "v61fa_post_ey_acceptance_closure_execution_queue_ready": v61fa["v61fa_post_ey_acceptance_closure_execution_queue_ready"],
    "v53al_complete_source_external_return_bundle_preflight_ready": v53al["v53al_complete_source_external_return_bundle_preflight_ready"],
    "v61et_real_generation_intake_return_bundle_preflight_ready": v61et["v61et_real_generation_intake_return_bundle_preflight_ready"],
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(ready_stage_rows),
    "blocked_stage_rows": str(blocked_stage_rows),
    "requirement_rows": str(len(requirement_rows)),
    "pass_requirement_rows": str(pass_requirement_rows),
    "blocked_requirement_rows": str(blocked_requirement_rows),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "v53_return_bundle_dir_supplied": str(v53_dir_supplied),
    "v53_return_bundle_dir_exists": str(v53_dir_exists),
    "v53_return_bundle_preflight_pass": str(v53_candidate),
    "v53_return_bundle_real_preflight_ready": str(v53_real),
    "v53_return_provenance": v53_provenance,
    "v53_preflight_rows": v53al["preflight_rows"],
    "v53_preflight_pass_rows": v53al["preflight_pass_rows"],
    "v61_return_bundle_dir_supplied": str(v61_dir_supplied),
    "v61_return_bundle_dir_exists": str(v61_dir_exists),
    "v61_return_bundle_candidate_preflight_ready": str(v61_candidate),
    "v61_return_bundle_real_preflight_ready": str(v61_real),
    "v61_return_provenance": v61_provenance,
    "v61_present_return_bundle_files": v61et["present_return_bundle_files"],
    "v61_required_return_bundle_files": v61et["required_return_bundle_files"],
    "dual_external_return_candidate_ready": str(dual_candidate),
    "dual_external_return_real_ready": str(dual_real),
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61fa-ready", "status": "pass", "reason": "execution queue is ready"},
    {"gate": "v53al-preflight-surface", "status": "pass", "reason": "v53al preflight surface emitted"},
    {"gate": "v61et-preflight-surface", "status": "pass", "reason": "v61et preflight surface emitted"},
    {"gate": "v53-return-bundle-candidate", "status": status(v53_candidate), "reason": f"v53_candidate={v53_candidate}"},
    {"gate": "v53-return-bundle-real", "status": status(v53_real), "reason": f"v53_real={v53_real}; provenance={v53_provenance}"},
    {"gate": "v61-return-bundle-candidate", "status": status(v61_candidate), "reason": f"v61_candidate={v61_candidate}"},
    {"gate": "v61-return-bundle-real", "status": status(v61_real), "reason": f"v61_real={v61_real}; provenance={v61_provenance}"},
    {"gate": "dual-external-return-candidate", "status": status(dual_candidate), "reason": f"dual_candidate={dual_candidate}"},
    {"gate": "dual-external-return-real", "status": status(dual_real), "reason": f"dual_real={dual_real}"},
    {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata preflight only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FB_POST_EY_EXTERNAL_RETURN_READINESS_PREFLIGHT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fb Post-v61ey External Return Readiness Preflight Boundary",
            "",
            f"- v53_return_bundle_preflight_pass={v53_candidate}",
            f"- v53_return_bundle_real_preflight_ready={v53_real}",
            f"- v61_return_bundle_candidate_preflight_ready={v61_candidate}",
            f"- v61_return_bundle_real_preflight_ready={v61_real}",
            f"- dual_external_return_candidate_ready={dual_candidate}",
            f"- dual_external_return_real_ready={dual_real}",
            "- generation_acceptance_closure_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fb can report whether supplied v53/v61 return roots pass candidate preflight.",
            "",
            "Blocked wording:",
            "- Do not claim review acceptance, generation acceptance closure, actual generation, latency, quality, or release readiness from v61fb alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": "v61fb_post_ey_external_return_readiness_preflight",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fb_post_ey_external_return_readiness_preflight_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fb_post_ey_external_return_readiness_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
