#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fb_post_ey_external_return_readiness_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_external_return_readiness_v61fb"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_V53_BUNDLE_DIR="$RESULTS_DIR/$PREFIX/fixture_v53_return_bundle"
FIXTURE_V61_BUNDLE_DIR="$RESULTS_DIR/v61et_real_generation_intake_return_bundle_preflight/fixture_return_bundle_input"

V61FA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61fa_post_ey_acceptance_closure_execution_queue.sh" >/dev/null
V61ET_REUSE_EXISTING=1 "$ROOT_DIR/experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null
V53AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null

rm -rf "$FIXTURE_V53_BUNDLE_DIR"
python3 - "$ROOT_DIR" "$FIXTURE_V53_BUNDLE_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
bundle_dir = Path(sys.argv[2])
checklist = root / "results/v53ak_complete_source_external_return_operator_checklist/checklist_001/external_return_operator_checklist_rows.csv"
with checklist.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
for row in rows:
    rel = row["final_return_bundle_relative_path"]
    path = bundle_dir / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix == ".json":
        path.write_text(json.dumps({"fixture": True, "checklist_item_id": row["checklist_item_id"]}, sort_keys=True) + "\n", encoding="utf-8")
    else:
        path.write_text(
            "fixture_row_id,checklist_item_id,return_family\n"
            f"fixture-001,{row['checklist_item_id']},{row['return_family']}\n",
            encoding="utf-8",
        )
PY

V61FB_REUSE_EXISTING="${V61FB_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh" >/dev/null

V61FB_RUN_ID="fixture_external_return_readiness_v61fb" \
V61FB_V53_RETURN_BUNDLE_DIR="$FIXTURE_V53_BUNDLE_DIR" \
V61FB_V53_RETURN_PROVENANCE="fixture-external-return-bundle" \
V61FB_V61_RETURN_BUNDLE_DIR="$FIXTURE_V61_BUNDLE_DIR" \
V61FB_V61_RETURN_PROVENANCE="fixture-return-bundle" \
V61FB_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh" >/dev/null

V61FB_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61fb_post_ey_external_return_readiness_preflight.sh" >/dev/null

python3 - "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
fixture_run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])


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
    "v61fb_post_ey_external_return_readiness_preflight_ready": "1",
    "v61fa_post_ey_acceptance_closure_execution_queue_ready": "1",
    "v53al_complete_source_external_return_bundle_preflight_ready": "1",
    "v61et_real_generation_intake_return_bundle_preflight_ready": "1",
    "stage_rows": "10",
    "ready_stage_rows": "3",
    "blocked_stage_rows": "7",
    "requirement_rows": "12",
    "pass_requirement_rows": "1",
    "blocked_requirement_rows": "11",
    "command_rows": "6",
    "ready_command_rows": "2",
    "v53_return_bundle_dir_supplied": "0",
    "v53_return_bundle_dir_exists": "0",
    "v53_return_bundle_preflight_pass": "0",
    "v53_return_bundle_real_preflight_ready": "0",
    "v53_preflight_rows": "81",
    "v53_preflight_pass_rows": "0",
    "v61_return_bundle_dir_supplied": "0",
    "v61_return_bundle_dir_exists": "0",
    "v61_return_bundle_candidate_preflight_ready": "0",
    "v61_return_bundle_real_preflight_ready": "0",
    "v61_present_return_bundle_files": "0",
    "v61_required_return_bundle_files": "10",
    "dual_external_return_candidate_ready": "0",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fb {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_ey_external_return_readiness_stage_rows.csv",
    "post_ey_external_return_readiness_requirement_rows.csv",
    "post_ey_external_return_readiness_command_rows.csv",
    "runtime_gap_rows.csv",
    "V61FB_POST_EY_EXTERNAL_RETURN_READINESS_PREFLIGHT_BOUNDARY.md",
    "v61fb_post_ey_external_return_readiness_preflight_manifest.json",
    "source_v61fa/post_ey_acceptance_closure_execution_phase_rows.csv",
    "source_v53al/external_return_bundle_preflight_rows.csv",
    "source_v53al/external_return_bundle_preflight_family_rows.csv",
    "source_v61et/real_generation_intake_return_bundle_file_rows.csv",
    "source_v61et/real_generation_intake_return_bundle_family_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fb artifact: {rel}")

stages = {row["stage_id"]: row["ready"] for row in read_csv(run_dir / "post_ey_external_return_readiness_stage_rows.csv")}
for stage in ["01-source-v61fa-queue", "02-v53al-preflight-surface", "03-v61et-preflight-surface"]:
    if stages[stage] != "1":
        raise SystemExit(f"v61fb canonical stage should be ready: {stage}")
for stage in ["04-v53-external-return-candidate", "05-v53-external-return-real", "06-v61-generation-return-candidate", "07-v61-generation-return-real", "08-dual-external-return-candidate", "09-dual-external-return-real", "10-actual-generation"]:
    if stages[stage] != "0":
        raise SystemExit(f"v61fb canonical stage should stay blocked: {stage}")

fixture_summary_path = fixture_run_dir.parent.parent / f"{fixture_run_dir.parent.name}_summary.csv"
fixture_stages = {row["stage_id"]: row["ready"] for row in read_csv(fixture_run_dir / "post_ey_external_return_readiness_stage_rows.csv")}
for stage in ["04-v53-external-return-candidate", "06-v61-generation-return-candidate", "08-dual-external-return-candidate"]:
    if fixture_stages[stage] != "1":
        raise SystemExit(f"v61fb fixture candidate stage should be ready: {stage}")
for stage in ["05-v53-external-return-real", "07-v61-generation-return-real", "09-dual-external-return-real", "10-actual-generation"]:
    if fixture_stages[stage] != "0":
        raise SystemExit(f"v61fb fixture real stage should stay blocked: {stage}")

fixture_manifest = json.loads((fixture_run_dir / "v61fb_post_ey_external_return_readiness_preflight_manifest.json").read_text(encoding="utf-8"))
if fixture_manifest.get("dual_external_return_candidate_ready") != 1:
    raise SystemExit("v61fb fixture dual candidate should be ready")
if fixture_manifest.get("dual_external_return_real_ready") != 0:
    raise SystemExit("v61fb fixture dual real readiness must stay blocked")
if fixture_manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fb fixture actual generation must stay blocked")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61fa-ready", "v53al-preflight-surface", "v61et-preflight-surface", "repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fb expected pass decision: {gate}")
for gate in ["v53-return-bundle-candidate", "v53-return-bundle-real", "v61-return-bundle-candidate", "v61-return-bundle-real", "dual-external-return-candidate", "dual-external-return-real", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fb expected blocked decision: {gate}")

boundary = (run_dir / "V61FB_POST_EY_EXTERNAL_RETURN_READINESS_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v53_return_bundle_preflight_pass=0",
    "v61_return_bundle_candidate_preflight_ready=0",
    "dual_external_return_candidate_ready=0",
    "dual_external_return_real_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fb boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61fb_post_ey_external_return_readiness_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61fb_post_ey_external_return_readiness_preflight_ready") != 1:
    raise SystemExit("v61fb manifest readiness mismatch")
if manifest.get("dual_external_return_real_ready") != 0:
    raise SystemExit("v61fb manifest must keep dual real readiness blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61fb manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fb sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" "$FIXTURE_RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fb produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fb post-ey external return readiness preflight smoke passed"
