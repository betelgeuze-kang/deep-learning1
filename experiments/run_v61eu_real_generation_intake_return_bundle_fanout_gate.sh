#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eu_real_generation_intake_return_bundle_fanout_gate"
RUN_ID="${V61EU_RUN_ID:-fanout_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR_ARG="${V61EU_RETURN_BUNDLE_DIR:-}"
RETURN_BUNDLE_PROVENANCE="${V61EU_RETURN_BUNDLE_PROVENANCE:-unspecified}"
RECEIPT_PROVENANCE="${V61EU_RECEIPT_PROVENANCE:-$RETURN_BUNDLE_PROVENANCE}"
BINDING_PROVENANCE="${V61EU_BINDING_PROVENANCE:-unspecified}"

if [[ "${V61EU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61eu_real_generation_intake_return_bundle_fanout_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61ET_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null
V61ER_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null
V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null

if [[ -n "$RETURN_BUNDLE_DIR_ARG" ]]; then
  V61ET_RUN_ID="fanout_return_bundle_preflight_v61eu" \
  V61ET_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR_ARG" \
  V61ET_RETURN_BUNDLE_PROVENANCE="$RETURN_BUNDLE_PROVENANCE" \
  V61ET_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh" >/dev/null

  V61ER_RUN_ID="fanout_receipt_preflight_v61eu" \
  V61ER_DISPATCH_RECEIPT_DIR="$RETURN_BUNDLE_DIR_ARG/dispatch_receipt" \
  V61ER_RECEIPT_PROVENANCE="$RECEIPT_PROVENANCE" \
  V61ER_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh" >/dev/null

  V61EJ_RUN_ID="fanout_generation_preflight_v61eu" \
  V61EJ_GENERATION_RESULT_DIR="$RETURN_BUNDLE_DIR_ARG/generation_result_return" \
  V61EJ_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null

  V61EL_RUN_ID="fanout_binding_preflight_v61eu" \
  V61EL_PREREQUISITE_BINDING_DIR="$RETURN_BUNDLE_DIR_ARG/prerequisite_binding" \
  V61EL_BINDING_PROVENANCE="$BINDING_PROVENANCE" \
  V61EL_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR_ARG" <<'PY'
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
bundle_arg = sys.argv[5].strip()
results = root / "results"
bundle_supplied = bool(bundle_arg)


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


def ready(flag):
    return "ready" if flag else "blocked"


selected = {
    "v61et": results / "v61et_real_generation_intake_return_bundle_preflight" / ("fanout_return_bundle_preflight_v61eu" if bundle_supplied else "preflight_001"),
    "v61er": results / "v61er_real_generation_intake_dispatch_receipt_preflight" / ("fanout_receipt_preflight_v61eu" if bundle_supplied else "preflight_001"),
    "v61ej": results / "v61ej_real_generation_return_receiver_preflight" / ("fanout_generation_preflight_v61eu" if bundle_supplied else "preflight_001"),
    "v61el": results / "v61el_real_prerequisite_binding_receiver_preflight" / ("fanout_binding_preflight_v61eu" if bundle_supplied else "preflight_001"),
}
required_selected = {
    "v61et_metric": selected["v61et"] / "real_generation_intake_return_bundle_requirement_rows.csv",
    "v61et_file_rows": selected["v61et"] / "real_generation_intake_return_bundle_file_rows.csv",
    "v61er_metric": selected["v61er"] / "real_generation_intake_dispatch_receipt_preflight_metric_rows.csv",
    "v61ej_metric": selected["v61ej"] / "receiver_preflight_metric_rows.csv",
    "v61el_metric": selected["v61el"] / "prerequisite_binding_preflight_metric_rows.csv",
}
for key, path in required_selected.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61eu artifact {key}: {path}")
    family = key.split("_", 1)[0]
    copy(path, f"selected_{family}/{path.name}")

for summary_path in [
    results / "v61et_real_generation_intake_return_bundle_preflight_summary.csv",
    results / "v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv",
    results / "v61ej_real_generation_return_receiver_preflight_summary.csv",
    results / "v61el_real_prerequisite_binding_receiver_preflight_summary.csv",
]:
    if not summary_path.is_file():
        raise SystemExit(f"missing v61eu source summary: {summary_path}")
    copy(summary_path, f"source_summaries/{summary_path.name}")

v61et_summary = read_csv(results / "v61et_real_generation_intake_return_bundle_preflight_summary.csv")[0]
v61er_summary = read_csv(results / "v61er_real_generation_intake_dispatch_receipt_preflight_summary.csv")[0]
v61ej_summary = read_csv(results / "v61ej_real_generation_return_receiver_preflight_summary.csv")[0]
v61el_summary = read_csv(results / "v61el_real_prerequisite_binding_receiver_preflight_summary.csv")[0]
if v61et_summary["v61et_real_generation_intake_return_bundle_preflight_ready"] != "1":
    raise SystemExit("v61eu requires v61et readiness")
if v61er_summary["v61er_real_generation_intake_dispatch_receipt_preflight_ready"] != "1":
    raise SystemExit("v61eu requires v61er readiness")
if v61ej_summary["v61ej_real_generation_return_receiver_preflight_ready"] != "1":
    raise SystemExit("v61eu requires v61ej readiness")
if v61el_summary["v61el_real_prerequisite_binding_receiver_preflight_ready"] != "1":
    raise SystemExit("v61eu requires v61el readiness")

v61et_requirements = {row["requirement_id"]: row["status"] for row in read_csv(required_selected["v61et_metric"])}
v61et_file_rows = read_csv(required_selected["v61et_file_rows"])
v61er_metric = read_csv(required_selected["v61er_metric"])[0]
v61ej_metric = read_csv(required_selected["v61ej_metric"])[0]
v61el_metric = read_csv(required_selected["v61el_metric"])[0]

return_bundle_candidate = int(v61et_requirements.get("return-bundle-candidate-preflight") == "pass")
real_return_bundle = int(v61et_requirements.get("real-return-bundle-preflight") == "pass")
receipt_candidate = as_int(v61er_metric, "dispatch_receipt_candidate_preflight_ready")
real_receipt = as_int(v61er_metric, "real_dispatch_receipt_ready")
generation_candidate = as_int(v61ej_metric, "generation_result_receiver_preflight_ready")
real_generation_artifacts = as_int(v61ej_metric, "real_generation_result_artifacts")
binding_candidate = as_int(v61el_metric, "binding_candidate_preflight_ready")
real_binding = as_int(v61el_metric, "real_prerequisite_binding_ready")
fanout_candidate_ready = int(return_bundle_candidate and receipt_candidate and generation_candidate and binding_candidate)
fanout_real_ready = int(real_return_bundle and real_receipt and real_generation_artifacts and real_binding)

stage_rows = [
    {"stage_id": "01-return-bundle-candidate", "status": ready(return_bundle_candidate), "ready": str(return_bundle_candidate), "actual_value": f"present_files={sum(row['file_exists'] == '1' for row in v61et_file_rows)}/{len(v61et_file_rows)}", "blocking_reason": "" if return_bundle_candidate else "return bundle shape is incomplete"},
    {"stage_id": "02-dispatch-receipt-preflight", "status": ready(receipt_candidate), "ready": str(receipt_candidate), "actual_value": f"receipt_candidate={receipt_candidate}; real_receipt={real_receipt}", "blocking_reason": "" if receipt_candidate else "dispatch receipt preflight is not ready"},
    {"stage_id": "03-generation-result-preflight", "status": ready(generation_candidate), "ready": str(generation_candidate), "actual_value": f"generation_candidate={generation_candidate}; real_artifacts={real_generation_artifacts}", "blocking_reason": "" if generation_candidate else "generation-result preflight is not ready"},
    {"stage_id": "04-prerequisite-binding-preflight", "status": ready(binding_candidate), "ready": str(binding_candidate), "actual_value": f"binding_candidate={binding_candidate}; real_binding={real_binding}", "blocking_reason": "" if binding_candidate else "prerequisite-binding preflight is not ready"},
    {"stage_id": "05-fanout-candidate-preflight", "status": ready(fanout_candidate_ready), "ready": str(fanout_candidate_ready), "actual_value": f"receipt={receipt_candidate}; generation={generation_candidate}; binding={binding_candidate}", "blocking_reason": "" if fanout_candidate_ready else "all three downstream candidate preflights must pass"},
    {"stage_id": "06-fanout-real-preflight", "status": ready(fanout_real_ready), "ready": str(fanout_real_ready), "actual_value": f"real_bundle={real_return_bundle}; real_receipt={real_receipt}; real_generation={real_generation_artifacts}; real_binding={real_binding}", "blocking_reason": "" if fanout_real_ready else "all downstream evidence must be non-fixture real evidence"},
    {"stage_id": "07-downstream-row-acceptance", "status": "blocked", "ready": "0", "actual_value": "downstream_row_acceptance_ready=0", "blocking_reason": "v61eu is fanout preflight only"},
    {"stage_id": "08-actual-generation", "status": "blocked", "ready": "0", "actual_value": "actual_model_generation_ready=0", "blocking_reason": "no generation row acceptance"},
]
write_csv(run_dir / "return_bundle_fanout_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "return-bundle-candidate-preflight", "status": status(return_bundle_candidate), "required_value": "1", "actual_value": str(return_bundle_candidate), "reason": "v61et candidate must pass"},
    {"requirement_id": "dispatch-receipt-candidate-preflight", "status": status(receipt_candidate), "required_value": "1", "actual_value": str(receipt_candidate), "reason": "v61er candidate must pass"},
    {"requirement_id": "generation-result-candidate-preflight", "status": status(generation_candidate), "required_value": "1", "actual_value": str(generation_candidate), "reason": "v61ej candidate must pass"},
    {"requirement_id": "prerequisite-binding-candidate-preflight", "status": status(binding_candidate), "required_value": "1", "actual_value": str(binding_candidate), "reason": "v61el candidate must pass"},
    {"requirement_id": "fanout-candidate-preflight", "status": status(fanout_candidate_ready), "required_value": "1", "actual_value": str(fanout_candidate_ready), "reason": "all candidate preflights must pass"},
    {"requirement_id": "fanout-real-preflight", "status": status(fanout_real_ready), "required_value": "1", "actual_value": str(fanout_real_ready), "reason": "all evidence must be real and non-fixture"},
    {"requirement_id": "downstream-row-acceptance", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "fanout does not run row acceptance"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "return_bundle_fanout_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

command_rows = [
    {"command_id": "run-v61et-return-bundle-preflight", "command": "V61ET_RETURN_BUNDLE_DIR=<bundle> ./experiments/run_v61et_real_generation_intake_return_bundle_preflight.sh", "ready_to_run_now": "1", "purpose": "validate one-root bundle shape"},
    {"command_id": "run-v61er-receipt-preflight", "command": "V61ER_DISPATCH_RECEIPT_DIR=<bundle>/dispatch_receipt ./experiments/run_v61er_real_generation_intake_dispatch_receipt_preflight.sh", "ready_to_run_now": str(return_bundle_candidate), "purpose": "fan out dispatch receipt"},
    {"command_id": "run-v61ej-generation-preflight", "command": "V61EJ_GENERATION_RESULT_DIR=<bundle>/generation_result_return ./experiments/run_v61ej_real_generation_return_receiver_preflight.sh", "ready_to_run_now": str(return_bundle_candidate), "purpose": "fan out generation artifacts"},
    {"command_id": "run-v61el-binding-preflight", "command": "V61EL_PREREQUISITE_BINDING_DIR=<bundle>/prerequisite_binding ./experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh", "ready_to_run_now": str(return_bundle_candidate), "purpose": "fan out prerequisite binding"},
    {"command_id": "run-real-intake-rendezvous", "command": "Run v61em/v61en/v61es after v61er/v61ej/v61el pass with real evidence", "ready_to_run_now": str(fanout_real_ready), "purpose": "open real intake only after real fanout"},
]
write_csv(run_dir / "return_bundle_fanout_command_rows.csv", list(command_rows[0].keys()), command_rows)

summary = {
    "v61eu_real_generation_intake_return_bundle_fanout_gate_ready": "1",
    "return_bundle_dir_supplied": str(int(bundle_supplied)),
    "selected_return_bundle_candidate_preflight_ready": str(return_bundle_candidate),
    "selected_real_return_bundle_preflight_ready": str(real_return_bundle),
    "selected_dispatch_receipt_candidate_preflight_ready": str(receipt_candidate),
    "selected_real_dispatch_receipt_ready": str(real_receipt),
    "selected_generation_result_receiver_preflight_ready": str(generation_candidate),
    "selected_real_generation_result_artifacts": str(real_generation_artifacts),
    "selected_binding_candidate_preflight_ready": str(binding_candidate),
    "selected_real_prerequisite_binding_ready": str(real_binding),
    "fanout_candidate_preflight_ready": str(fanout_candidate_ready),
    "fanout_real_preflight_ready": str(fanout_real_ready),
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61eu": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "return-bundle-candidate-preflight", "status": status(return_bundle_candidate), "reason": f"candidate={return_bundle_candidate}"},
    {"gate": "downstream-candidate-fanout", "status": status(fanout_candidate_ready), "reason": f"fanout_candidate={fanout_candidate_ready}"},
    {"gate": "real-evidence-fanout", "status": status(fanout_real_ready), "reason": f"fanout_real={fanout_real_ready}"},
    {"gate": "downstream-row-acceptance", "status": "blocked", "reason": "fanout gate does not accept rows"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata/evidence fanout only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EU_REAL_GENERATION_INTAKE_RETURN_BUNDLE_FANOUT_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61eu Real Generation Intake Return Bundle Fanout Boundary",
            "",
            f"- return_bundle_dir_supplied={int(bundle_supplied)}",
            f"- fanout_candidate_preflight_ready={fanout_candidate_ready}",
            f"- fanout_real_preflight_ready={fanout_real_ready}",
            "- downstream_row_acceptance_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- A one-root return bundle can be fanned out to v61er/v61ej/v61el preflights.",
            "- Fixture bundle fanout proves mechanics only.",
            "",
            "Blocked wording:",
            "- Do not claim downstream row acceptance, real generation intake, actual generation, latency, near-frontier quality, or release readiness from v61eu alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61eu-real-generation-intake-return-bundle-fanout-gate",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61eu_real_generation_intake_return_bundle_fanout_gate_ready": 1,
    "fanout_candidate_preflight_ready": fanout_candidate_ready,
    "fanout_real_preflight_ready": fanout_real_ready,
    "downstream_row_acceptance_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61eu_real_generation_intake_return_bundle_fanout_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61eu_real_generation_intake_return_bundle_fanout_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
