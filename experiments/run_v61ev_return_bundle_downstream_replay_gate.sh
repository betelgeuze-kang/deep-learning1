#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ev_return_bundle_downstream_replay_gate"
RUN_ID="${V61EV_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR_ARG="${V61EV_RETURN_BUNDLE_DIR:-}"
RETURN_BUNDLE_PROVENANCE="${V61EV_RETURN_BUNDLE_PROVENANCE:-unspecified}"
RECEIPT_PROVENANCE="${V61EV_RECEIPT_PROVENANCE:-$RETURN_BUNDLE_PROVENANCE}"
BINDING_PROVENANCE="${V61EV_BINDING_PROVENANCE:-unspecified}"

if [[ "${V61EV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ev_return_bundle_downstream_replay_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EU_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh" >/dev/null
V61EM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null
V61EN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null
V61ES_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null

if [[ -n "$RETURN_BUNDLE_DIR_ARG" ]]; then
  V61EU_RUN_ID="downstream_fanout_v61ev" \
  V61EU_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR_ARG" \
  V61EU_RETURN_BUNDLE_PROVENANCE="$RETURN_BUNDLE_PROVENANCE" \
  V61EU_RECEIPT_PROVENANCE="$RECEIPT_PROVENANCE" \
  V61EU_BINDING_PROVENANCE="$BINDING_PROVENANCE" \
  V61EU_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh" >/dev/null

  V61EM_RUN_ID="downstream_rendezvous_v61ev" \
  V61EM_GENERATION_PREFLIGHT_RUN_DIR="$RESULTS_DIR/v61ej_real_generation_return_receiver_preflight/fanout_generation_preflight_v61eu" \
  V61EM_BINDING_PREFLIGHT_RUN_DIR="$RESULTS_DIR/v61el_real_prerequisite_binding_receiver_preflight/fanout_binding_preflight_v61eu" \
  V61EM_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh" >/dev/null

  V61EN_RUN_ID="downstream_work_order_v61ev" \
  V61EN_RENDEZVOUS_RUN_DIR="$RESULTS_DIR/v61em_generation_intake_dual_preflight_rendezvous/downstream_rendezvous_v61ev" \
  V61EN_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61en_real_generation_intake_work_order.sh" >/dev/null

  V61ES_RUN_ID="downstream_handoff_guard_v61ev" \
  V61ES_RECEIPT_PREFLIGHT_RUN_DIR="$RESULTS_DIR/v61er_real_generation_intake_dispatch_receipt_preflight/fanout_receipt_preflight_v61eu" \
  V61ES_WORK_ORDER_RUN_DIR="$RESULTS_DIR/v61en_real_generation_intake_work_order/downstream_work_order_v61ev" \
  V61ES_REUSE_EXISTING=0 \
  "$ROOT_DIR/experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh" >/dev/null
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
    "v61eu": results / "v61eu_real_generation_intake_return_bundle_fanout_gate" / ("downstream_fanout_v61ev" if bundle_supplied else "fanout_001"),
    "v61em": results / "v61em_generation_intake_dual_preflight_rendezvous" / ("downstream_rendezvous_v61ev" if bundle_supplied else "rendezvous_001"),
    "v61en": results / "v61en_real_generation_intake_work_order" / ("downstream_work_order_v61ev" if bundle_supplied else "work_order_001"),
    "v61es": results / "v61es_dispatch_receipt_to_generation_intake_handoff_guard" / ("downstream_handoff_guard_v61ev" if bundle_supplied else "guard_001"),
}
selected_files = {
    "v61eu_stage_rows": selected["v61eu"] / "return_bundle_fanout_stage_rows.csv",
    "v61eu_summary_manifest": selected["v61eu"] / "v61eu_real_generation_intake_return_bundle_fanout_gate_manifest.json",
    "v61em_stage_rows": selected["v61em"] / "dual_preflight_rendezvous_stage_rows.csv",
    "v61em_manifest": selected["v61em"] / "v61em_generation_intake_dual_preflight_rendezvous_manifest.json",
    "v61en_work_rows": selected["v61en"] / "real_generation_intake_work_order_rows.csv",
    "v61en_manifest": selected["v61en"] / "v61en_real_generation_intake_work_order_manifest.json",
    "v61es_stage_rows": selected["v61es"] / "dispatch_receipt_to_generation_intake_stage_rows.csv",
    "v61es_manifest": selected["v61es"] / "v61es_dispatch_receipt_to_generation_intake_handoff_guard_manifest.json",
}
for key, path in selected_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61ev artifact {key}: {path}")
    family = key.split("_", 1)[0]
    copy(path, f"selected_{family}/{path.name}")

for summary_path in [
    results / "v61eu_real_generation_intake_return_bundle_fanout_gate_summary.csv",
    results / "v61em_generation_intake_dual_preflight_rendezvous_summary.csv",
    results / "v61en_real_generation_intake_work_order_summary.csv",
    results / "v61es_dispatch_receipt_to_generation_intake_handoff_guard_summary.csv",
]:
    if not summary_path.is_file():
        raise SystemExit(f"missing source summary: {summary_path}")
    copy(summary_path, f"source_summaries/{summary_path.name}")

v61eu_manifest = json.loads(selected_files["v61eu_summary_manifest"].read_text(encoding="utf-8"))
v61em_manifest = json.loads(selected_files["v61em_manifest"].read_text(encoding="utf-8"))
v61en_manifest = json.loads(selected_files["v61en_manifest"].read_text(encoding="utf-8"))
v61es_manifest = json.loads(selected_files["v61es_manifest"].read_text(encoding="utf-8"))
v61eu_stages = {row["stage_id"]: row for row in read_csv(selected_files["v61eu_stage_rows"])}
v61em_stages = {row["stage_id"]: row for row in read_csv(selected_files["v61em_stage_rows"])}
v61en_work = {row["work_item_id"]: row for row in read_csv(selected_files["v61en_work_rows"])}
v61es_stages = {row["stage_id"]: row for row in read_csv(selected_files["v61es_stage_rows"])}

fanout_candidate = int(v61eu_manifest.get("fanout_candidate_preflight_ready", 0))
fanout_real = int(v61eu_manifest.get("fanout_real_preflight_ready", 0))
dual_candidate = int(v61em_manifest.get("dual_candidate_preflight_rendezvous_ready", 0))
real_rendezvous = int(v61em_manifest.get("real_generation_intake_handoff_ready", 0))
ready_work_rows = sum(row["ready"] == "1" for row in v61en_work.values())
real_work_order_handoff = int(v61en_manifest.get("real_generation_intake_handoff_ready", 0))
receipt_to_intake = int(v61es_manifest.get("receipt_to_intake_handoff_ready", 0))
actual_model_generation_ready = 0

stage_rows = [
    {"stage_id": "01-return-bundle-fanout-candidate", "status": ready(fanout_candidate), "ready": str(fanout_candidate), "actual_value": f"fanout_candidate={fanout_candidate}", "blocking_reason": "" if fanout_candidate else "bundle has not opened all receiver candidate preflights"},
    {"stage_id": "02-return-bundle-fanout-real", "status": ready(fanout_real), "ready": str(fanout_real), "actual_value": f"fanout_real={fanout_real}", "blocking_reason": "" if fanout_real else "fanout evidence is not all real/non-fixture"},
    {"stage_id": "03-dual-preflight-rendezvous", "status": ready(dual_candidate), "ready": str(dual_candidate), "actual_value": f"dual_candidate={dual_candidate}", "blocking_reason": "" if dual_candidate else "v61em candidate rendezvous is not ready"},
    {"stage_id": "04-real-rendezvous-handoff", "status": ready(real_rendezvous), "ready": str(real_rendezvous), "actual_value": f"real_rendezvous={real_rendezvous}", "blocking_reason": "" if real_rendezvous else "requires real prerequisite binding"},
    {"stage_id": "05-work-order-progress", "status": ready(ready_work_rows > 1), "ready": str(int(ready_work_rows > 1)), "actual_value": f"ready_work_rows={ready_work_rows}", "blocking_reason": "" if ready_work_rows > 1 else "only baseline work row is ready"},
    {"stage_id": "06-real-work-order-handoff", "status": ready(real_work_order_handoff), "ready": str(real_work_order_handoff), "actual_value": f"real_work_order_handoff={real_work_order_handoff}", "blocking_reason": "" if real_work_order_handoff else "work order still has real-evidence blockers"},
    {"stage_id": "07-receipt-to-intake-handoff", "status": ready(receipt_to_intake), "ready": str(receipt_to_intake), "actual_value": f"receipt_to_intake={receipt_to_intake}", "blocking_reason": "" if receipt_to_intake else "receipt and intake are not both real"},
    {"stage_id": "08-actual-generation", "status": "blocked", "ready": "0", "actual_value": "actual_model_generation_ready=0", "blocking_reason": "downstream replay does not accept generation rows"},
]
write_csv(run_dir / "return_bundle_downstream_replay_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

requirement_rows = [
    {"requirement_id": "fanout-candidate-preflight", "status": status(fanout_candidate), "required_value": "1", "actual_value": str(fanout_candidate), "reason": "v61eu candidate fanout must pass"},
    {"requirement_id": "fanout-real-preflight", "status": status(fanout_real), "required_value": "1", "actual_value": str(fanout_real), "reason": "fanout evidence must be real/non-fixture"},
    {"requirement_id": "dual-candidate-rendezvous", "status": status(dual_candidate), "required_value": "1", "actual_value": str(dual_candidate), "reason": "v61em must join generation and binding candidates"},
    {"requirement_id": "real-rendezvous-handoff", "status": status(real_rendezvous), "required_value": "1", "actual_value": str(real_rendezvous), "reason": "v61em real handoff requires real binding"},
    {"requirement_id": "work-order-progress", "status": status(ready_work_rows > 1), "required_value": ">1", "actual_value": str(ready_work_rows), "reason": "v61en should reflect candidate progress"},
    {"requirement_id": "real-work-order-handoff", "status": status(real_work_order_handoff), "required_value": "1", "actual_value": str(real_work_order_handoff), "reason": "v61en real handoff requires real evidence"},
    {"requirement_id": "receipt-to-intake-handoff", "status": status(receipt_to_intake), "required_value": "1", "actual_value": str(receipt_to_intake), "reason": "v61es requires real receipt and real intake"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "return_bundle_downstream_replay_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

command_rows = [
    {"command_id": "run-bundle-fanout", "command": "V61EU_RETURN_BUNDLE_DIR=<bundle> ./experiments/run_v61eu_real_generation_intake_return_bundle_fanout_gate.sh", "ready_to_run_now": "1", "purpose": "fan out bundle to receiver preflights"},
    {"command_id": "run-dual-rendezvous", "command": "V61EM_GENERATION_PREFLIGHT_RUN_DIR=<v61ej_run> V61EM_BINDING_PREFLIGHT_RUN_DIR=<v61el_run> ./experiments/run_v61em_generation_intake_dual_preflight_rendezvous.sh", "ready_to_run_now": str(fanout_candidate), "purpose": "join generation and binding candidates"},
    {"command_id": "run-work-order", "command": "V61EN_RENDEZVOUS_RUN_DIR=<v61em_run> ./experiments/run_v61en_real_generation_intake_work_order.sh", "ready_to_run_now": str(dual_candidate), "purpose": "refresh work order from downstream rendezvous"},
    {"command_id": "run-receipt-to-intake-guard", "command": "V61ES_RECEIPT_PREFLIGHT_RUN_DIR=<v61er_run> V61ES_WORK_ORDER_RUN_DIR=<v61en_run> ./experiments/run_v61es_dispatch_receipt_to_generation_intake_handoff_guard.sh", "ready_to_run_now": str(ready_work_rows > 1), "purpose": "join receipt and intake readiness"},
    {"command_id": "run-real-generation-intake", "command": "Run v61bt/v61de only after real downstream replay closes", "ready_to_run_now": str(int(fanout_real and real_rendezvous and receipt_to_intake)), "purpose": "accept rows only after real evidence"},
]
write_csv(run_dir / "return_bundle_downstream_replay_command_rows.csv", list(command_rows[0].keys()), command_rows)

summary = {
    "v61ev_return_bundle_downstream_replay_gate_ready": "1",
    "return_bundle_dir_supplied": str(int(bundle_supplied)),
    "selected_fanout_candidate_preflight_ready": str(fanout_candidate),
    "selected_fanout_real_preflight_ready": str(fanout_real),
    "selected_dual_candidate_preflight_rendezvous_ready": str(dual_candidate),
    "selected_real_rendezvous_handoff_ready": str(real_rendezvous),
    "selected_ready_work_order_rows": str(ready_work_rows),
    "selected_real_work_order_handoff_ready": str(real_work_order_handoff),
    "selected_receipt_to_intake_handoff_ready": str(receipt_to_intake),
    "downstream_replay_candidate_ready": str(int(fanout_candidate and dual_candidate and ready_work_rows > 1)),
    "downstream_replay_real_ready": str(int(fanout_real and real_rendezvous and real_work_order_handoff and receipt_to_intake)),
    "downstream_row_acceptance_ready": "0",
    "real_generation_intake_handoff_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ev": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "downstream-candidate-replay", "status": status(summary["downstream_replay_candidate_ready"] == "1"), "reason": f"candidate={summary['downstream_replay_candidate_ready']}"},
    {"gate": "downstream-real-replay", "status": status(summary["downstream_replay_real_ready"] == "1"), "reason": f"real={summary['downstream_replay_real_ready']}"},
    {"gate": "receipt-to-intake-handoff", "status": status(receipt_to_intake), "reason": f"receipt_to_intake={receipt_to_intake}"},
    {"gate": "downstream-row-acceptance", "status": "blocked", "reason": "replay gate does not accept rows"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no accepted generation rows"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata/evidence replay only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61EV_RETURN_BUNDLE_DOWNSTREAM_REPLAY_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ev Return Bundle Downstream Replay Boundary",
            "",
            f"- return_bundle_dir_supplied={int(bundle_supplied)}",
            f"- downstream_replay_candidate_ready={summary['downstream_replay_candidate_ready']}",
            f"- downstream_replay_real_ready={summary['downstream_replay_real_ready']}",
            "- downstream_row_acceptance_ready=0",
            "- actual_model_generation_ready=0",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- A fanout bundle can be replayed through v61em, v61en, and v61es readiness gates.",
            "- Fixture replay proves downstream mechanics only.",
            "",
            "Blocked wording:",
            "- Do not claim real row acceptance, actual generation, latency, near-frontier quality, or release readiness from v61ev alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61ev-return-bundle-downstream-replay-gate",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61ev_return_bundle_downstream_replay_gate_ready": 1,
    "downstream_replay_candidate_ready": int(summary["downstream_replay_candidate_ready"]),
    "downstream_replay_real_ready": int(summary["downstream_replay_real_ready"]),
    "downstream_row_acceptance_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ev_return_bundle_downstream_replay_gate_manifest.json").write_text(
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

echo "v61ev_return_bundle_downstream_replay_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
