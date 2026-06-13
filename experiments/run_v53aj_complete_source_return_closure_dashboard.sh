#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53aj_complete_source_return_closure_dashboard"
RUN_ID="${V53AJ_RUN_ID:-dashboard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V53AJ_RETURN_BUNDLE_DIR:-}"

if [[ "${V53AJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53aj_complete_source_return_closure_dashboard_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V53AI_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ai_complete_source_external_return_bundle_intake.sh" >/dev/null
else
  V53AI_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ai_complete_source_external_return_bundle_intake.sh" >/dev/null
fi

V53V_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh" >/dev/null
V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" <<'PY'
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
return_bundle_arg = sys.argv[5]
return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
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


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


v53ai_summary_path = results / "v53ai_complete_source_external_return_bundle_intake_summary.csv"
v53ai_decision_path = results / "v53ai_complete_source_external_return_bundle_intake_decision.csv"
v53ai_dir = results / "v53ai_complete_source_external_return_bundle_intake" / "intake_001"
v53ae_summary_path = results / "v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv"
v53ae_decision_path = results / "v53ae_complete_source_review_return_generation_rendezvous_gate_decision.csv"
v53ae_dir = results / "v53ae_complete_source_review_return_generation_rendezvous_gate" / "gate_001"
v53v_summary_path = results / "v53v_complete_source_review_return_acceptance_bridge_summary.csv"
v53v_decision_path = results / "v53v_complete_source_review_return_acceptance_bridge_decision.csv"
v53v_dir = results / "v53v_complete_source_review_return_acceptance_bridge" / "bridge_001"
v61de_summary_path = results / "v61de_post_review_generation_result_handoff_bridge_summary.csv"
v61de_decision_path = results / "v61de_post_review_generation_result_handoff_bridge_decision.csv"
v61de_dir = results / "v61de_post_review_generation_result_handoff_bridge" / "bridge_001"

v53ai = read_csv(v53ai_summary_path)[0]
v53ae = read_csv(v53ae_summary_path)[0]
v53v = read_csv(v53v_summary_path)[0]
v61de = read_csv(v61de_summary_path)[0]

for row, field in [
    (v53ai, "v53ai_complete_source_external_return_bundle_intake_ready"),
    (v53ae, "v53ae_complete_source_review_return_generation_rendezvous_gate_ready"),
    (v53v, "v53v_complete_source_review_return_acceptance_bridge_ready"),
    (v61de, "v61de_post_review_generation_result_handoff_bridge_ready"),
]:
    if row.get(field) != "1":
        raise SystemExit(f"v53aj requires {field}=1")

for src, rel in [
    (v53ai_summary_path, "source_v53ai/v53ai_complete_source_external_return_bundle_intake_summary.csv"),
    (v53ai_decision_path, "source_v53ai/v53ai_complete_source_external_return_bundle_intake_decision.csv"),
    (v53ai_dir / "external_return_bundle_artifact_mapping_rows.csv", "source_v53ai/external_return_bundle_artifact_mapping_rows.csv"),
    (v53ai_dir / "external_return_bundle_family_rows.csv", "source_v53ai/external_return_bundle_family_rows.csv"),
    (v53ai_dir / "runtime_gap_rows.csv", "source_v53ai/runtime_gap_rows.csv"),
    (v53ae_summary_path, "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv"),
    (v53ae_decision_path, "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_decision.csv"),
    (v53ae_dir / "review_return_generation_rendezvous_stage_rows.csv", "source_v53ae/review_return_generation_rendezvous_stage_rows.csv"),
    (v53ae_dir / "review_return_generation_next_action_rows.csv", "source_v53ae/review_return_generation_next_action_rows.csv"),
    (v53v_summary_path, "source_v53v/v53v_complete_source_review_return_acceptance_bridge_summary.csv"),
    (v53v_decision_path, "source_v53v/v53v_complete_source_review_return_acceptance_bridge_decision.csv"),
    (v53v_dir / "complete_source_review_return_acceptance_rows.csv", "source_v53v/complete_source_review_return_acceptance_rows.csv"),
    (v61de_summary_path, "source_v61de/v61de_post_review_generation_result_handoff_bridge_summary.csv"),
    (v61de_decision_path, "source_v61de/v61de_post_review_generation_result_handoff_bridge_decision.csv"),
    (v61de_dir / "post_review_generation_result_handoff_stage_rows.csv", "source_v61de/post_review_generation_result_handoff_stage_rows.csv"),
]:
    copy(src, rel)

send_bundle_ready = as_int(v53ai, "send_bundle_ready")
return_bundle_mapping_ready = as_int(v53ai, "return_bundle_mapping_ready")
all_return_artifacts_present = as_int(v53ai, "all_return_artifacts_present")
dispatch_receipts_ready = int(as_int(v53ae, "accepted_dispatch_receipt_rows") == as_int(v53ae, "dispatch_receipt_template_rows") and as_int(v53ae, "dispatch_receipt_template_rows") > 0)
chunk_returns_ready = int(as_int(v53ae, "accepted_chunk_return_artifact_rows") == as_int(v53ae, "review_chunk_return_artifact_rows") and as_int(v53ae, "review_chunk_return_artifact_rows") > 0)
aggregate_review_ready = int(as_int(v53ae, "review_return_ready") and as_int(v53ae, "answer_review_accepted_rows") == as_int(v53ae, "expected_human_review_rows") and as_int(v53ae, "accepted_adjudication_rows") == as_int(v53ae, "expected_adjudication_rows"))
v53_review_ready = int(as_int(v53v, "review_return_ready") and as_int(v53v, "v53_ready"))
full_shard_runtime_ready = int(as_int(v53ae, "full_shard_prerequisites_closed") and as_int(v53ae, "complete_source_runtime_admission_execution_ready") and as_int(v53ae, "runtime_admission_accepted_rows") == 1000)
generation_execution_ready = int(as_int(v61de, "generation_execution_admitted_rows") == as_int(v61de, "generation_execution_admission_rows") and as_int(v61de, "generation_execution_admission_rows") > 0)
generation_result_ready = int(as_int(v61de, "accepted_generation_result_artifacts") == as_int(v61de, "expected_generation_result_artifacts") and as_int(v61de, "generation_result_accepted_rows") == as_int(v61de, "generation_result_acceptance_rows") and as_int(v61de, "generation_result_acceptance_rows") > 0)
actual_generation_ready = as_int(v61de, "actual_model_generation_ready")
release_ready = int(as_int(v61de, "near_frontier_claim_ready") and as_int(v61de, "production_latency_claim_ready") and as_int(v61de, "real_release_package_ready"))

closure_rows = [
    {"closure_item_id": "01-external-send-bundle-ready", "source_gate": "v53ai/v53ah", "status": "ready" if send_bundle_ready else "blocked", "required_value": "send_bundle_ready=1", "actual_value": f"send_bundle_ready={v53ai['send_bundle_ready']}", "blocking_reason": "ready" if send_bundle_ready else "send bundle is not ready"},
    {"closure_item_id": "02-return-bundle-mapping-surface", "source_gate": "v53ai", "status": "ready" if return_bundle_mapping_ready else "blocked", "required_value": "return_bundle_mapping_ready=1", "actual_value": f"return_bundle_mapping_ready={v53ai['return_bundle_mapping_ready']}", "blocking_reason": "ready" if return_bundle_mapping_ready else "return mapping index is not ready"},
    {"closure_item_id": "03-return-bundle-artifacts-present", "source_gate": "v53ai", "status": "ready" if all_return_artifacts_present else "blocked", "required_value": "supplied_return_artifact_rows=81", "actual_value": f"supplied_return_artifact_rows={v53ai['supplied_return_artifact_rows']}/{v53ai['required_return_artifact_rows']}", "blocking_reason": "returned external bundle is missing final artifacts"},
    {"closure_item_id": "04-dispatch-receipts-accepted", "source_gate": "v53ae/v53ad", "status": "ready" if dispatch_receipts_ready else "blocked", "required_value": "accepted_dispatch_receipt_rows=21", "actual_value": f"accepted_dispatch_receipt_rows={v53ae['accepted_dispatch_receipt_rows']}/{v53ae['dispatch_receipt_template_rows']}", "blocking_reason": "dispatch receipts are not accepted"},
    {"closure_item_id": "05-review-chunk-returns-accepted", "source_gate": "v53ae/v53x", "status": "ready" if chunk_returns_ready else "blocked", "required_value": "accepted_chunk_return_artifact_rows=50", "actual_value": f"accepted_chunk_return_artifact_rows={v53ae['accepted_chunk_return_artifact_rows']}/{v53ae['review_chunk_return_artifact_rows']}", "blocking_reason": "review chunk return artifacts are not accepted"},
    {"closure_item_id": "06-aggregate-review-return-accepted", "source_gate": "v53ae/v53y", "status": "ready" if aggregate_review_ready else "blocked", "required_value": "7000 human rows and 1000 adjudication rows accepted", "actual_value": f"answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}/{v53ae['expected_human_review_rows']}; accepted_adjudication_rows={v53ae['accepted_adjudication_rows']}/{v53ae['expected_adjudication_rows']}", "blocking_reason": "aggregate review return is not accepted"},
    {"closure_item_id": "07-complete-source-review-ready", "source_gate": "v53v", "status": "ready" if v53_review_ready else "blocked", "required_value": "review_return_ready=1 and v53_ready=1", "actual_value": f"review_return_ready={v53v['review_return_ready']}; v53_ready={v53v['v53_ready']}", "blocking_reason": "v53 review readiness is blocked"},
    {"closure_item_id": "08-full-shard-runtime-closed", "source_gate": "v53ae/v61de", "status": "ready" if full_shard_runtime_ready else "blocked", "required_value": "full_shard_prerequisites_closed=1 and runtime_admission_accepted_rows=1000", "actual_value": f"full_shard_prerequisites_closed={v53ae['full_shard_prerequisites_closed']}; runtime_admission_accepted_rows={v53ae['runtime_admission_accepted_rows']}", "blocking_reason": "ready" if full_shard_runtime_ready else "full-shard/runtime closure is incomplete"},
    {"closure_item_id": "09-generation-execution-admitted", "source_gate": "v61de", "status": "ready" if generation_execution_ready else "blocked", "required_value": "generation_execution_admitted_rows=1000", "actual_value": f"generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}/{v61de['generation_execution_admission_rows']}", "blocking_reason": "generation execution is not admitted"},
    {"closure_item_id": "10-generation-result-accepted", "source_gate": "v61de/v61cu", "status": "ready" if generation_result_ready else "blocked", "required_value": "5 result artifacts and 1000 rows accepted", "actual_value": f"accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}/{v61de['expected_generation_result_artifacts']}; generation_result_accepted_rows={v61de['generation_result_accepted_rows']}/{v61de['generation_result_acceptance_rows']}", "blocking_reason": "generation result is not accepted"},
    {"closure_item_id": "11-actual-model-generation-ready", "source_gate": "v61de", "status": "ready" if actual_generation_ready else "blocked", "required_value": "actual_model_generation_ready=1", "actual_value": f"actual_model_generation_ready={v61de['actual_model_generation_ready']}", "blocking_reason": "actual generation remains unproven"},
    {"closure_item_id": "12-release-claim-ready", "source_gate": "v61de/v60", "status": "ready" if release_ready else "blocked", "required_value": "near_frontier=1 production_latency=1 release=1", "actual_value": f"near_frontier_claim_ready={v61de['near_frontier_claim_ready']}; production_latency_claim_ready={v61de['production_latency_claim_ready']}; real_release_package_ready={v61de['real_release_package_ready']}", "blocking_reason": "release claims remain blocked"},
]
write_csv(run_dir / "complete_source_return_closure_dashboard_rows.csv", list(closure_rows[0].keys()), closure_rows)
ready_closure_item_rows = sum(1 for row in closure_rows if row["status"] == "ready")
blocked_closure_item_rows = len(closure_rows) - ready_closure_item_rows

next_action_rows = [
    {"action_id": "01-send-external-review-bundle", "action_status": "ready" if send_bundle_ready else "blocked", "command": "results/v53ah_complete_source_external_review_send_bundle/bundle_001/send_bundle/VERIFY_SEND_BUNDLE.sh", "expected_effect": "external reviewers receive dispatch packet and return inbox shape"},
    {"action_id": "02-wait-for-final-return-bundle", "action_status": "blocked", "command": "external operator returns dispatch_receipts/, review_chunk_returns/, aggregate_review_return/, generation_result_return/", "expected_effect": "all 81 final return artifacts are present"},
    {"action_id": "03-intake-return-bundle", "action_status": "blocked", "command": "V53AI_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AI_REUSE_EXISTING=0 ./experiments/run_v53ai_complete_source_external_return_bundle_intake.sh", "expected_effect": "v53ae refreshes returned review/generation paths"},
    {"action_id": "04-refresh-review-generation-acceptance", "action_status": "blocked", "command": "V53AE_REUSE_EXISTING=0 ./experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh", "expected_effect": "accepted review return can unlock generation admission"},
    {"action_id": "05-run-generation-result-acceptance", "action_status": "blocked", "command": "V61DE_REVIEW_RETURN_DIR=/path/to/aggregate_review_return V61DE_GENERATION_RESULT_DIR=/path/to/generation_result_return V61DE_REUSE_EXISTING=0 ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh", "expected_effect": "actual generation can be accepted only after returned generation rows validate"},
]
write_csv(run_dir / "complete_source_return_closure_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)
ready_next_action_rows = sum(1 for row in next_action_rows if row["action_status"] == "ready")

metric = {
    "metric_id": "v53aj_complete_source_return_closure_dashboard_metrics",
    "v53ai_complete_source_external_return_bundle_intake_ready": v53ai["v53ai_complete_source_external_return_bundle_intake_ready"],
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"],
    "v53v_complete_source_review_return_acceptance_bridge_ready": v53v["v53v_complete_source_review_return_acceptance_bridge_ready"],
    "v61de_post_review_generation_result_handoff_bridge_ready": v61de["v61de_post_review_generation_result_handoff_bridge_ready"],
    "return_bundle_dir_supplied": str(int(return_bundle_dir is not None)),
    "return_bundle_dir_exists": str(int(return_bundle_dir is not None and return_bundle_dir.is_dir())),
    "closure_dashboard_ready": "1",
    "closure_item_rows": str(len(closure_rows)),
    "ready_closure_item_rows": str(ready_closure_item_rows),
    "blocked_closure_item_rows": str(blocked_closure_item_rows),
    "next_action_rows": str(len(next_action_rows)),
    "ready_next_action_rows": str(ready_next_action_rows),
    "send_bundle_ready": v53ai["send_bundle_ready"],
    "return_bundle_mapping_ready": v53ai["return_bundle_mapping_ready"],
    "required_return_artifact_rows": v53ai["required_return_artifact_rows"],
    "supplied_return_artifact_rows": v53ai["supplied_return_artifact_rows"],
    "missing_return_artifact_rows": v53ai["missing_return_artifact_rows"],
    "all_return_artifacts_present": v53ai["all_return_artifacts_present"],
    "accepted_by_v53ai_rows": v53ai["accepted_by_v53ai_rows"],
    "accepted_dispatch_receipt_rows": v53ae["accepted_dispatch_receipt_rows"],
    "dispatch_receipt_template_rows": v53ae["dispatch_receipt_template_rows"],
    "accepted_chunk_return_artifact_rows": v53ae["accepted_chunk_return_artifact_rows"],
    "review_chunk_return_artifact_rows": v53ae["review_chunk_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53ae["accepted_aggregate_review_return_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53ae["aggregate_review_return_artifact_rows"],
    "expected_human_review_rows": v53ae["expected_human_review_rows"],
    "answer_review_accepted_rows": v53ae["answer_review_accepted_rows"],
    "expected_adjudication_rows": v53ae["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53ae["accepted_adjudication_rows"],
    "review_return_ready": v53ae["review_return_ready"],
    "v53_ready": v53v["v53_ready"],
    "full_shard_prerequisites_closed": v53ae["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ae["runtime_admission_accepted_rows"],
    "generation_execution_admitted_rows": v61de["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61de["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61de["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61de["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v61de["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v61de["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v61de["actual_model_generation_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "return_loop_closed": str(int(all(row["status"] == "ready" for row in closure_rows[:10]))),
    "v53_review_closed": str(v53_review_ready),
    "v61_generation_closed": str(actual_generation_ready),
    "checkpoint_payload_bytes_downloaded_by_v53aj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_return_closure_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53aj_complete_source_return_closure_dashboard_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = []
for row in closure_rows:
    decision_rows.append({"gate": row["closure_item_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]})
decision_rows.append({"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["closure_item_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in closure_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v53aj Complete-Source Return Closure Dashboard Boundary

This artifact is a dashboard over v53ai, v53ae, v53v, and v61de. It does not
accept returned evidence, execute generation, or create comparison/release
claims. It only records which post-send closure items are ready or blocked.

Evidence emitted:

- closure_item_rows={len(closure_rows)}
- ready_closure_item_rows={ready_closure_item_rows}
- blocked_closure_item_rows={blocked_closure_item_rows}
- next_action_rows={len(next_action_rows)}
- ready_next_action_rows={ready_next_action_rows}
- send_bundle_ready={v53ai['send_bundle_ready']}
- return_bundle_mapping_ready={v53ai['return_bundle_mapping_ready']}
- required_return_artifact_rows={v53ai['required_return_artifact_rows']}
- supplied_return_artifact_rows={v53ai['supplied_return_artifact_rows']}
- missing_return_artifact_rows={v53ai['missing_return_artifact_rows']}
- all_return_artifacts_present={v53ai['all_return_artifacts_present']}
- accepted_by_v53ai_rows={v53ai['accepted_by_v53ai_rows']}
- accepted_dispatch_receipt_rows={v53ae['accepted_dispatch_receipt_rows']}
- accepted_chunk_return_artifact_rows={v53ae['accepted_chunk_return_artifact_rows']}
- answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}
- accepted_adjudication_rows={v53ae['accepted_adjudication_rows']}
- review_return_ready={v53ae['review_return_ready']}
- v53_ready={v53v['v53_ready']}
- full_shard_prerequisites_closed={v53ae['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53ae['runtime_admission_accepted_rows']}
- generation_execution_admitted_rows={v61de['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v61de['accepted_generation_result_artifacts']}
- generation_result_accepted_rows={v61de['generation_result_accepted_rows']}
- actual_model_generation_ready={v61de['actual_model_generation_ready']}
- return_loop_closed={metric['return_loop_closed']}
- v53_review_closed={metric['v53_review_closed']}
- v61_generation_closed={metric['v61_generation_closed']}
- checkpoint_payload_bytes_downloaded_by_v53aj=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: return closure dashboard is ready and shows current blockers.
Blocked wording: accepted returned review, generation execution, actual
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V53AJ_COMPLETE_SOURCE_RETURN_CLOSURE_DASHBOARD_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53aj-complete-source-return-closure-dashboard",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53aj_complete_source_return_closure_dashboard_ready": 1,
    "closure_item_rows": len(closure_rows),
    "ready_closure_item_rows": ready_closure_item_rows,
    "blocked_closure_item_rows": blocked_closure_item_rows,
    "send_bundle_ready": int(v53ai["send_bundle_ready"]),
    "return_bundle_mapping_ready": int(v53ai["return_bundle_mapping_ready"]),
    "supplied_return_artifact_rows": int(v53ai["supplied_return_artifact_rows"]),
    "missing_return_artifact_rows": int(v53ai["missing_return_artifact_rows"]),
    "answer_review_accepted_rows": int(v53ae["answer_review_accepted_rows"]),
    "generation_execution_admitted_rows": int(v61de["generation_execution_admitted_rows"]),
    "accepted_generation_result_artifacts": int(v61de["accepted_generation_result_artifacts"]),
    "actual_model_generation_ready": int(v61de["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53ae["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53ae["runtime_admission_accepted_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v53aj": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53aj_complete_source_return_closure_dashboard_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53aj_complete_source_return_closure_dashboard_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
