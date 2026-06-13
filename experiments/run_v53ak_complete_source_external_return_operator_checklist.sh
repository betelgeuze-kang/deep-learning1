#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ak_complete_source_external_return_operator_checklist"
RUN_ID="${V53AK_RUN_ID:-checklist_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V53AK_RETURN_BUNDLE_DIR:-}"

if [[ "${V53AK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ak_complete_source_external_return_operator_checklist_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V53AJ_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53aj_complete_source_return_closure_dashboard.sh" >/dev/null
else
  V53AJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53aj_complete_source_return_closure_dashboard.sh" >/dev/null
fi

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


v53aj_summary_path = results / "v53aj_complete_source_return_closure_dashboard_summary.csv"
v53aj_decision_path = results / "v53aj_complete_source_return_closure_dashboard_decision.csv"
v53aj_dir = results / "v53aj_complete_source_return_closure_dashboard" / "dashboard_001"
v53ai_summary_path = results / "v53ai_complete_source_external_return_bundle_intake_summary.csv"
v53ai_decision_path = results / "v53ai_complete_source_external_return_bundle_intake_decision.csv"
v53ai_dir = results / "v53ai_complete_source_external_return_bundle_intake" / "intake_001"

v53aj = read_csv(v53aj_summary_path)[0]
v53ai = read_csv(v53ai_summary_path)[0]
if v53aj["v53aj_complete_source_return_closure_dashboard_ready"] != "1":
    raise SystemExit("v53ak requires v53aj closure dashboard readiness")
if v53ai["v53ai_complete_source_external_return_bundle_intake_ready"] != "1":
    raise SystemExit("v53ak requires v53ai return bundle intake readiness")

for src, rel in [
    (v53aj_summary_path, "source_v53aj/v53aj_complete_source_return_closure_dashboard_summary.csv"),
    (v53aj_decision_path, "source_v53aj/v53aj_complete_source_return_closure_dashboard_decision.csv"),
    (v53aj_dir / "complete_source_return_closure_dashboard_rows.csv", "source_v53aj/complete_source_return_closure_dashboard_rows.csv"),
    (v53aj_dir / "complete_source_return_closure_next_action_rows.csv", "source_v53aj/complete_source_return_closure_next_action_rows.csv"),
    (v53aj_dir / "runtime_gap_rows.csv", "source_v53aj/runtime_gap_rows.csv"),
    (v53ai_summary_path, "source_v53ai/v53ai_complete_source_external_return_bundle_intake_summary.csv"),
    (v53ai_decision_path, "source_v53ai/v53ai_complete_source_external_return_bundle_intake_decision.csv"),
    (v53ai_dir / "external_return_bundle_artifact_mapping_rows.csv", "source_v53ai/external_return_bundle_artifact_mapping_rows.csv"),
    (v53ai_dir / "external_return_bundle_family_rows.csv", "source_v53ai/external_return_bundle_family_rows.csv"),
]:
    copy(src, rel)

mapping_rows = read_csv(v53ai_dir / "external_return_bundle_artifact_mapping_rows.csv")
family_rows = read_csv(v53ai_dir / "external_return_bundle_family_rows.csv")
closure_rows = read_csv(v53aj_dir / "complete_source_return_closure_dashboard_rows.csv")

family_bundle_prefix = {
    "dispatch-receipt": "",
    "review-chunk-return": "review_chunk_returns",
    "aggregate-review-return": "aggregate_review_return",
    "generation-result-return": "generation_result_return",
}
family_closure_item = {
    "dispatch-receipt": "04-dispatch-receipts-accepted",
    "review-chunk-return": "05-review-chunk-returns-accepted",
    "aggregate-review-return": "06-aggregate-review-return-accepted",
    "generation-result-return": "10-generation-result-accepted",
}
family_downstream_gate = {
    "dispatch-receipt": "v53ad",
    "review-chunk-return": "v53x",
    "aggregate-review-return": "v53s/v53y/v53v",
    "generation-result-return": "v61bt/v61cu/v61de",
}
family_validation_command = {
    "dispatch-receipt": "V53AD_DISPATCH_RECEIPT_DIR=/path/to/final_return_bundle V53AD_REUSE_EXISTING=0 ./experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh",
    "review-chunk-return": "V53X_REVIEW_CHUNK_RETURN_DIR=/path/to/final_return_bundle/review_chunk_returns V53X_REUSE_EXISTING=0 ./experiments/run_v53x_complete_source_review_chunk_return_intake.sh",
    "aggregate-review-return": "V53Y_REVIEW_RETURN_DIR=/path/to/final_return_bundle/aggregate_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
    "generation-result-return": "V61BT_GENERATION_RESULT_DIR=/path/to/final_return_bundle/generation_result_return V61BT_REUSE_EXISTING=0 ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
}

checklist_rows = []
for index, row in enumerate(mapping_rows, start=1):
    family = row["return_family"]
    prefix = family_bundle_prefix[family]
    expected_rel = row["expected_final_artifact"]
    bundle_rel = str(Path(prefix) / expected_rel) if prefix else expected_rel
    bundle_path = return_bundle_dir / bundle_rel if return_bundle_dir else None
    supplied = int(bundle_path is not None and bundle_path.is_file())
    checklist_rows.append(
        {
            "checklist_item_id": f"return_artifact_{index:03d}",
            "return_family": family,
            "closure_item_id": family_closure_item[family],
            "downstream_gate": family_downstream_gate[family],
            "target_env_var": row["target_env_var"],
            "final_return_bundle_relative_path": bundle_rel,
            "gate_relative_artifact_path": expected_rel,
            "expected_rows": row["expected_rows"],
            "artifact_supplied": str(supplied),
            "artifact_missing": str(int(not supplied)),
            "template_named_supplied": row["template_named_supplied"],
            "accepted_by_v53ak": "0",
            "accepted_by_downstream_required": "1",
            "validation_command": family_validation_command[family],
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "external_return_operator_checklist_rows.csv", list(checklist_rows[0].keys()), checklist_rows)

closure_status = {row["closure_item_id"]: row for row in closure_rows}
closure_checklist_rows = []
for closure_item_id in [
    "03-return-bundle-artifacts-present",
    "04-dispatch-receipts-accepted",
    "05-review-chunk-returns-accepted",
    "06-aggregate-review-return-accepted",
    "07-complete-source-review-ready",
    "09-generation-execution-admitted",
    "10-generation-result-accepted",
    "11-actual-model-generation-ready",
    "12-release-claim-ready",
]:
    source = closure_status[closure_item_id]
    related_items = [row for row in checklist_rows if row["closure_item_id"] == closure_item_id]
    closure_checklist_rows.append(
        {
            "closure_item_id": closure_item_id,
            "current_status": source["status"],
            "current_actual_value": source["actual_value"],
            "related_checklist_rows": str(len(related_items)),
            "related_supplied_rows": str(sum(int(row["artifact_supplied"]) for row in related_items)),
            "operator_action": source["blocking_reason"],
        }
    )
write_csv(run_dir / "external_return_operator_closure_checklist_rows.csv", list(closure_checklist_rows[0].keys()), closure_checklist_rows)

family_checklist_rows = []
for row in family_rows:
    family = row["return_family"]
    related = [item for item in checklist_rows if item["return_family"] == family]
    family_checklist_rows.append(
        {
            "return_family": family,
            "target_env_var": row["target_env_var"],
            "bundle_subdir": family_bundle_prefix[family] or ".",
            "expected_artifact_rows": row["expected_artifact_rows"],
            "checklist_rows": str(len(related)),
            "supplied_artifact_rows": str(sum(int(item["artifact_supplied"]) for item in related)),
            "missing_artifact_rows": str(sum(int(item["artifact_missing"]) for item in related)),
            "downstream_gate": family_downstream_gate[family],
            "validation_command": family_validation_command[family],
        }
    )
write_csv(run_dir / "external_return_operator_family_checklist_rows.csv", list(family_checklist_rows[0].keys()), family_checklist_rows)

operator_readme = run_dir / "EXTERNAL_RETURN_OPERATOR_CHECKLIST.md"
operator_readme.write_text(
    "\n".join(
        [
            "# v53ak External Return Operator Checklist",
            "",
            "This checklist is for the external operator who fills the final return bundle.",
            "It is not accepted evidence and does not make review or generation claims.",
            "",
            "Expected final bundle shape:",
            "",
            "- `dispatch_receipts/*.json`",
            "- `review_chunk_returns/chunks/.../*.csv`",
            "- `aggregate_review_return/{human_review_rows.csv,adjudication_rows.csv,reviewer_identity_rows.csv,reviewer_conflict_rows.csv,acceptance_summary.json}`",
            "- `generation_result_return/{real_model_generation_answer_rows.csv,real_model_generation_citation_rows.csv,real_model_generation_abstain_fallback_rows.csv,real_model_generation_latency_rows.csv,real_model_generation_acceptance_summary.json}`",
            "",
            "After the bundle is filled, run:",
            "",
            "```bash",
            "V53AI_RETURN_BUNDLE_DIR=/path/to/final_return_bundle \\",
            "V53AI_REUSE_EXISTING=0 \\",
            "./experiments/run_v53ai_complete_source_external_return_bundle_intake.sh",
            "",
            "V53AJ_RETURN_BUNDLE_DIR=/path/to/final_return_bundle \\",
            "V53AJ_REUSE_EXISTING=0 \\",
            "./experiments/run_v53aj_complete_source_return_closure_dashboard.sh",
            "```",
            "",
            "Only downstream gates accept evidence: v53ad/v53x/v53y/v53v and v61bt/v61cu/v61de.",
            "",
        ]
    ),
    encoding="utf-8",
)

checklist_rows_total = len(checklist_rows)
supplied_checklist_rows = sum(int(row["artifact_supplied"]) for row in checklist_rows)
missing_checklist_rows = sum(int(row["artifact_missing"]) for row in checklist_rows)
template_named_supplied_rows = sum(int(row["template_named_supplied"]) for row in checklist_rows)
accepted_by_v53ak_rows = 0
return_bundle_dir_supplied = int(return_bundle_dir is not None)
return_bundle_dir_exists = int(return_bundle_dir is not None and return_bundle_dir.is_dir())
operator_checklist_ready = int(
    as_int(v53aj, "v53aj_complete_source_return_closure_dashboard_ready")
    and checklist_rows_total == as_int(v53ai, "required_return_artifact_rows")
    and template_named_supplied_rows == 0
)

requirement_rows = [
    {"requirement_id": "v53aj-dashboard-input", "status": "pass", "required_value": "1", "actual_value": v53aj["v53aj_complete_source_return_closure_dashboard_ready"], "reason": "closure dashboard is ready"},
    {"requirement_id": "checklist-row-coverage", "status": "pass" if checklist_rows_total == as_int(v53ai, "required_return_artifact_rows") else "blocked", "required_value": v53ai["required_return_artifact_rows"], "actual_value": str(checklist_rows_total), "reason": "one checklist row per required return artifact"},
    {"requirement_id": "template-files-not-accepted", "status": "pass" if template_named_supplied_rows == 0 else "blocked", "required_value": "0", "actual_value": str(template_named_supplied_rows), "reason": "template-named files are not evidence"},
    {"requirement_id": "return-bundle-directory", "status": "pass" if return_bundle_dir_exists else "blocked", "required_value": "existing return bundle directory", "actual_value": str(return_bundle_dir) if return_bundle_dir else "", "reason": "no real returned bundle in default smoke"},
    {"requirement_id": "all-artifacts-supplied", "status": "pass" if supplied_checklist_rows == checklist_rows_total else "blocked", "required_value": str(checklist_rows_total), "actual_value": str(supplied_checklist_rows), "reason": "all final artifacts must be supplied before downstream acceptance can pass"},
    {"requirement_id": "v53ak-does-not-accept-evidence", "status": "pass", "required_value": "0", "actual_value": str(accepted_by_v53ak_rows), "reason": "checklist is logistics only"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": "7000", "actual_value": v53aj["answer_review_accepted_rows"], "reason": "review acceptance remains downstream"},
    {"requirement_id": "generation-execution-admitted", "status": "blocked", "required_value": "1000", "actual_value": v53aj["generation_execution_admitted_rows"], "reason": "generation execution remains downstream"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v53aj["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "external_return_operator_checklist_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "operator-checklist", "status": "ready" if operator_checklist_ready else "blocked", "reason": f"checklist_rows={checklist_rows_total}/{v53ai['required_return_artifact_rows']}"},
    {"gap": "return-bundle-directory", "status": "ready" if return_bundle_dir_exists else "blocked", "reason": f"return_bundle_dir_exists={return_bundle_dir_exists}"},
    {"gap": "all-artifacts-supplied", "status": "ready" if supplied_checklist_rows == checklist_rows_total else "blocked", "reason": f"supplied_checklist_rows={supplied_checklist_rows}/{checklist_rows_total}"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53aj['answer_review_accepted_rows']}/7000"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53aj['generation_execution_admitted_rows']}/1000"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53aj['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ak_complete_source_external_return_operator_checklist_metrics",
    "v53aj_complete_source_return_closure_dashboard_ready": v53aj["v53aj_complete_source_return_closure_dashboard_ready"],
    "v53ai_complete_source_external_return_bundle_intake_ready": v53ai["v53ai_complete_source_external_return_bundle_intake_ready"],
    "return_bundle_dir_supplied": str(return_bundle_dir_supplied),
    "return_bundle_dir_exists": str(return_bundle_dir_exists),
    "operator_checklist_ready": str(operator_checklist_ready),
    "checklist_rows": str(checklist_rows_total),
    "dispatch_receipt_checklist_rows": str(sum(1 for row in checklist_rows if row["return_family"] == "dispatch-receipt")),
    "review_chunk_return_checklist_rows": str(sum(1 for row in checklist_rows if row["return_family"] == "review-chunk-return")),
    "aggregate_review_return_checklist_rows": str(sum(1 for row in checklist_rows if row["return_family"] == "aggregate-review-return")),
    "generation_result_return_checklist_rows": str(sum(1 for row in checklist_rows if row["return_family"] == "generation-result-return")),
    "supplied_checklist_rows": str(supplied_checklist_rows),
    "missing_checklist_rows": str(missing_checklist_rows),
    "template_named_supplied_rows": str(template_named_supplied_rows),
    "accepted_by_v53ak_rows": str(accepted_by_v53ak_rows),
    "closure_checklist_rows": str(len(closure_checklist_rows)),
    "family_checklist_rows": str(len(family_checklist_rows)),
    "send_bundle_ready": v53aj["send_bundle_ready"],
    "return_bundle_mapping_ready": v53aj["return_bundle_mapping_ready"],
    "closure_item_rows": v53aj["closure_item_rows"],
    "ready_closure_item_rows": v53aj["ready_closure_item_rows"],
    "blocked_closure_item_rows": v53aj["blocked_closure_item_rows"],
    "answer_review_accepted_rows": v53aj["answer_review_accepted_rows"],
    "accepted_adjudication_rows": v53aj["accepted_adjudication_rows"],
    "generation_execution_admitted_rows": v53aj["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53aj["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v53aj["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53aj["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53aj["runtime_admission_accepted_rows"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ak": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "external_return_operator_checklist_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ak_complete_source_external_return_operator_checklist_ready": str(operator_checklist_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53aj-dashboard-input", "status": "pass", "reason": "v53aj dashboard is ready"},
    {"gate": "operator-checklist", "status": "pass" if operator_checklist_ready else "blocked", "reason": f"checklist_rows={checklist_rows_total}/{v53ai['required_return_artifact_rows']}"},
    {"gate": "template-files-not-accepted", "status": "pass" if template_named_supplied_rows == 0 else "blocked", "reason": f"template_named_supplied_rows={template_named_supplied_rows}"},
    {"gate": "v53ak-does-not-accept-evidence", "status": "pass", "reason": "accepted_by_v53ak_rows=0"},
    {"gate": "return-bundle-directory", "status": "pass" if return_bundle_dir_exists else "blocked", "reason": f"return_bundle_dir_exists={return_bundle_dir_exists}"},
    {"gate": "all-artifacts-supplied", "status": "pass" if supplied_checklist_rows == checklist_rows_total else "blocked", "reason": f"supplied_checklist_rows={supplied_checklist_rows}/{checklist_rows_total}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53aj['answer_review_accepted_rows']}/7000"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53aj['generation_execution_admitted_rows']}/1000"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53aj['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "operator checklist is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ak Complete-Source External Return Operator Checklist Boundary

This artifact converts v53ai/v53aj state into an operator checklist. It does
not accept evidence, does not execute generation, and does not create review,
quality, latency, near-frontier, or release claims.

Evidence emitted:

- operator_checklist_ready={operator_checklist_ready}
- checklist_rows={checklist_rows_total}
- dispatch_receipt_checklist_rows={metric['dispatch_receipt_checklist_rows']}
- review_chunk_return_checklist_rows={metric['review_chunk_return_checklist_rows']}
- aggregate_review_return_checklist_rows={metric['aggregate_review_return_checklist_rows']}
- generation_result_return_checklist_rows={metric['generation_result_return_checklist_rows']}
- supplied_checklist_rows={supplied_checklist_rows}
- missing_checklist_rows={missing_checklist_rows}
- template_named_supplied_rows={template_named_supplied_rows}
- accepted_by_v53ak_rows=0
- closure_checklist_rows={len(closure_checklist_rows)}
- family_checklist_rows={len(family_checklist_rows)}
- send_bundle_ready={v53aj['send_bundle_ready']}
- return_bundle_mapping_ready={v53aj['return_bundle_mapping_ready']}
- ready_closure_item_rows={v53aj['ready_closure_item_rows']}
- blocked_closure_item_rows={v53aj['blocked_closure_item_rows']}
- answer_review_accepted_rows={v53aj['answer_review_accepted_rows']}
- accepted_adjudication_rows={v53aj['accepted_adjudication_rows']}
- generation_execution_admitted_rows={v53aj['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v53aj['accepted_generation_result_artifacts']}
- actual_model_generation_ready={v53aj['actual_model_generation_ready']}
- full_shard_prerequisites_closed={v53aj['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53aj['runtime_admission_accepted_rows']}
- checkpoint_payload_bytes_downloaded_by_v53ak=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: external return operator checklist is ready.
Blocked wording: returned evidence accepted, generation execution admitted,
actual generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V53AK_COMPLETE_SOURCE_EXTERNAL_RETURN_OPERATOR_CHECKLIST_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ak-complete-source-external-return-operator-checklist",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ak_complete_source_external_return_operator_checklist_ready": operator_checklist_ready,
    "checklist_rows": checklist_rows_total,
    "supplied_checklist_rows": supplied_checklist_rows,
    "missing_checklist_rows": missing_checklist_rows,
    "accepted_by_v53ak_rows": accepted_by_v53ak_rows,
    "ready_closure_item_rows": int(v53aj["ready_closure_item_rows"]),
    "blocked_closure_item_rows": int(v53aj["blocked_closure_item_rows"]),
    "answer_review_accepted_rows": int(v53aj["answer_review_accepted_rows"]),
    "generation_execution_admitted_rows": int(v53aj["generation_execution_admitted_rows"]),
    "actual_model_generation_ready": int(v53aj["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53aj["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53aj["runtime_admission_accepted_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v53ak": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53ak_complete_source_external_return_operator_checklist_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ak_complete_source_external_return_operator_checklist_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
