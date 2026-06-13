#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dp_return_schema_acceptance_blocker_gate"
RUN_ID="${V61DP_RUN_ID:-schema_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V61DP_RETURN_BUNDLE_DIR:-}"

if [[ "${V61DP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dp_return_schema_acceptance_blocker_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V61DO_RUN_ID="${RUN_ID}_v61do" V61DO_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V61DO_REUSE_EXISTING=0 \
    "$ROOT_DIR/experiments/run_v61do_full_return_preflight_acceptance_boundary_gate.sh" >/dev/null
  V53AM_RUN_ID="${RUN_ID}_v53am" V53AM_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AM_REUSE_EXISTING=0 \
    "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
else
  V61DO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61do_full_return_preflight_acceptance_boundary_gate.sh" >/dev/null
  V53AM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53am_complete_source_return_acceptance_replay.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$RETURN_BUNDLE_DIR" <<'PY'
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
run_id = sys.argv[5]
return_bundle_arg = sys.argv[6]
return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
results = root / "results"
v53am_run_id = f"{run_id}_v53am" if return_bundle_dir else "replay_001"


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61do_summary": results / "v61do_full_return_preflight_acceptance_boundary_gate_summary.csv",
    "v61do_decision": results / "v61do_full_return_preflight_acceptance_boundary_gate_decision.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
    "v53am_decision": results / "v53am_complete_source_return_acceptance_replay_decision.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dp source {key}: {path}")

copy(sources["v61do_summary"], "source_v61do/v61do_full_return_preflight_acceptance_boundary_gate_summary.csv")
copy(sources["v61do_decision"], "source_v61do/v61do_full_return_preflight_acceptance_boundary_gate_decision.csv")
copy(sources["v53am_summary"], "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv")
copy(sources["v53am_decision"], "source_v53am/v53am_complete_source_return_acceptance_replay_decision.csv")

v61do = read_csv(sources["v61do_summary"])[0]
v53am = read_csv(sources["v53am_summary"])[0]
if v61do.get("v61do_full_return_preflight_acceptance_boundary_gate_ready") != "1":
    raise SystemExit("v61dp requires v61do ready")
if v53am.get("v53am_complete_source_return_acceptance_replay_ready") != "1":
    raise SystemExit("v61dp requires v53am ready")

v53am_run_dir = results / "v53am_complete_source_return_acceptance_replay" / v53am_run_id
source_paths = {
    "v53ad_summary": v53am_run_dir / "source_v53ad/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "v53x_summary": v53am_run_dir / "source_v53x/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "v53y_summary": v53am_run_dir / "source_v53y/v53y_complete_source_review_return_refresh_gate_summary.csv",
    "v61bt_summary": v53am_run_dir / "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing copied v53am source {key}: {path}")
    copy(path, f"source_{key}/{path.name}")

v53ad = read_csv(source_paths["v53ad_summary"])[0]
v53x = read_csv(source_paths["v53x_summary"])[0]
v53y = read_csv(source_paths["v53y_summary"])[0]
v61bt = read_csv(source_paths["v61bt_summary"])[0]

family_rows = [
    {
        "acceptance_family": "dispatch-receipt-json",
        "expected_artifact_rows": v53ad["dispatch_receipt_template_rows"],
        "supplied_artifact_rows": v53ad["supplied_dispatch_receipt_rows"],
        "accepted_artifact_rows": v53ad["accepted_dispatch_receipt_rows"],
        "missing_artifact_rows": v53ad["missing_dispatch_receipt_rows"],
        "invalid_artifact_rows": v53ad["invalid_dispatch_receipt_rows"],
        "accepted_payload_rows": v53ad["accepted_dispatch_receipt_rows"],
        "expected_payload_rows": v53ad["dispatch_receipt_template_rows"],
        "acceptance_ready": v53ad["dispatch_receipt_intake_ready"],
        "blocking_reason": "dispatch receipt JSON schema/chunk identity must validate",
    },
    {
        "acceptance_family": "review-chunk-return-csv",
        "expected_artifact_rows": v53x["review_chunk_return_artifact_rows"],
        "supplied_artifact_rows": v53x["supplied_chunk_return_artifact_rows"],
        "accepted_artifact_rows": v53x["accepted_chunk_return_artifact_rows"],
        "missing_artifact_rows": v53x["missing_chunk_return_artifact_rows"],
        "invalid_artifact_rows": v53x["invalid_chunk_return_artifact_rows"],
        "accepted_payload_rows": str(
            as_int(v53x, "accepted_human_review_rows")
            + as_int(v53x, "accepted_adjudication_rows")
            + as_int(v53x, "accepted_reviewer_identity_rows")
            + as_int(v53x, "accepted_conflict_disclosure_rows")
        ),
        "expected_payload_rows": str(
            as_int(v53x, "expected_human_review_rows")
            + as_int(v53x, "expected_adjudication_rows")
            + as_int(v53x, "expected_reviewer_identity_rows")
            + as_int(v53x, "expected_conflict_disclosure_rows")
        ),
        "acceptance_ready": v53x["chunk_return_intake_ready"],
        "blocking_reason": "review chunk CSV field sets and row counts must validate",
    },
    {
        "acceptance_family": "aggregate-review-return",
        "expected_artifact_rows": v53x["aggregate_review_return_artifact_rows"],
        "supplied_artifact_rows": v53x["supplied_aggregate_review_return_artifact_rows"],
        "accepted_artifact_rows": v53x["accepted_aggregate_review_return_artifact_rows"],
        "missing_artifact_rows": v53x["missing_aggregate_review_return_artifact_rows"],
        "invalid_artifact_rows": v53x["invalid_aggregate_review_return_artifact_rows"],
        "accepted_payload_rows": str(
            as_int(v53y, "answer_review_accepted_rows")
            + as_int(v53y, "accepted_adjudication_rows")
            + as_int(v53y, "accepted_reviewer_identity_rows")
            + as_int(v53y, "accepted_conflict_disclosure_rows")
        ),
        "expected_payload_rows": str(
            as_int(v53y, "expected_human_review_rows")
            + as_int(v53y, "expected_adjudication_rows")
            + as_int(v53y, "expected_reviewer_identity_rows")
            + as_int(v53y, "expected_conflict_disclosure_rows")
        ),
        "acceptance_ready": v53y["review_return_ready"],
        "blocking_reason": "aggregate human/source review and adjudication rows must validate",
    },
    {
        "acceptance_family": "generation-result-return",
        "expected_artifact_rows": v61bt["expected_generation_result_artifacts"],
        "supplied_artifact_rows": v61bt["supplied_generation_result_artifacts"],
        "accepted_artifact_rows": v61bt["accepted_generation_result_artifacts"],
        "missing_artifact_rows": v61bt["missing_generation_result_artifacts"],
        "invalid_artifact_rows": v61bt["invalid_generation_result_artifacts"],
        "accepted_payload_rows": v61bt["accepted_generation_rows"],
        "expected_payload_rows": v61bt["expected_generation_rows"],
        "acceptance_ready": v61bt["actual_model_generation_ready"],
        "blocking_reason": "generation result answer/citation/latency rows must validate",
    },
]
write_csv(run_dir / "return_schema_acceptance_blocker_family_rows.csv", list(family_rows[0].keys()), family_rows)

ready_family_rows = sum(row["acceptance_ready"] == "1" for row in family_rows)
accepted_artifact_rows = sum(as_int(row, "accepted_artifact_rows") for row in family_rows)
expected_artifact_rows = sum(as_int(row, "expected_artifact_rows") for row in family_rows)
supplied_artifact_rows = sum(as_int(row, "supplied_artifact_rows") for row in family_rows)
missing_artifact_rows = sum(as_int(row, "missing_artifact_rows") for row in family_rows)
invalid_artifact_rows = sum(as_int(row, "invalid_artifact_rows") for row in family_rows)
accepted_payload_rows = sum(as_int(row, "accepted_payload_rows") for row in family_rows)
expected_payload_rows = sum(as_int(row, "expected_payload_rows") for row in family_rows)

stage_rows = [
    {"stage_id": "01-full-file-preflight", "status": "ready" if as_int(v61do, "return_bundle_preflight_pass") else "blocked", "actual_value": f"full_preflight_pass_rows={v61do['full_preflight_pass_rows']}/{v61do['full_preflight_rows']}", "blocking_reason": "full 81-artifact file preflight has not passed"},
    {"stage_id": "02-schema-family-acceptance", "status": "ready" if ready_family_rows == len(family_rows) else "blocked", "actual_value": f"ready_schema_family_rows={ready_family_rows}/{len(family_rows)}", "blocking_reason": "one or more return families failed schema/row acceptance"},
    {"stage_id": "03-payload-row-acceptance", "status": "ready" if accepted_payload_rows == expected_payload_rows and expected_payload_rows > 0 else "blocked", "actual_value": f"accepted_payload_rows={accepted_payload_rows}/{expected_payload_rows}", "blocking_reason": "payload rows are not accepted"},
    {"stage_id": "04-actual-generation-ready", "status": "ready" if as_int(v53am, "actual_model_generation_ready") else "blocked", "actual_value": f"actual_model_generation_ready={v53am['actual_model_generation_ready']}", "blocking_reason": "actual generation remains unproven"},
]
write_csv(run_dir / "return_schema_acceptance_blocker_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(row["status"] == "ready" for row in stage_rows)

metric = {
    "metric_id": "v61dp_return_schema_acceptance_blocker_gate_metrics",
    "v61do_full_return_preflight_acceptance_boundary_gate_ready": v61do["v61do_full_return_preflight_acceptance_boundary_gate_ready"],
    "v53am_complete_source_return_acceptance_replay_ready": v53am["v53am_complete_source_return_acceptance_replay_ready"],
    "source_gate_rows": "2",
    "return_bundle_dir_supplied": str(int(return_bundle_dir is not None)),
    "return_bundle_dir_exists": str(int(return_bundle_dir is not None and return_bundle_dir.is_dir())),
    "schema_family_rows": str(len(family_rows)),
    "ready_schema_family_rows": str(ready_family_rows),
    "blocked_schema_family_rows": str(len(family_rows) - ready_family_rows),
    "schema_stage_rows": str(len(stage_rows)),
    "ready_schema_stage_rows": str(ready_stage_rows),
    "blocked_schema_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "expected_schema_artifact_rows": str(expected_artifact_rows),
    "supplied_schema_artifact_rows": str(supplied_artifact_rows),
    "accepted_schema_artifact_rows": str(accepted_artifact_rows),
    "missing_schema_artifact_rows": str(missing_artifact_rows),
    "invalid_schema_artifact_rows": str(invalid_artifact_rows),
    "expected_payload_rows": str(expected_payload_rows),
    "accepted_payload_rows": str(accepted_payload_rows),
    "full_preflight_rows": v61do["full_preflight_rows"],
    "full_preflight_pass_rows": v61do["full_preflight_pass_rows"],
    "return_bundle_preflight_pass": v61do["return_bundle_preflight_pass"],
    "preflight_only_gap_detected": v61do["preflight_only_gap_detected"],
    "accepted_dispatch_receipt_rows": v53am["accepted_dispatch_receipt_rows"],
    "dispatch_receipt_template_rows": v53am["dispatch_receipt_template_rows"],
    "accepted_chunk_return_artifact_rows": v53am["accepted_chunk_return_artifact_rows"],
    "review_chunk_return_artifact_rows": v53am["review_chunk_return_artifact_rows"],
    "answer_review_accepted_rows": v53am["answer_review_accepted_rows"],
    "expected_human_review_rows": v53am["expected_human_review_rows"],
    "accepted_adjudication_rows": v53am["accepted_adjudication_rows"],
    "expected_adjudication_rows": v53am["expected_adjudication_rows"],
    "generation_result_accepted_rows": v53am["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v53am["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v53am["actual_model_generation_ready"],
    "schema_acceptance_ready": str(int(ready_family_rows == len(family_rows) and accepted_payload_rows == expected_payload_rows and expected_payload_rows > 0)),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dp": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_schema_acceptance_blocker_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dp_return_schema_acceptance_blocker_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["stage_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["blocking_reason"]}
    for row in stage_rows
]
decision_rows.append({"gate": "preflight-is-not-schema-acceptance", "status": "pass" if (as_int(v61do, "preflight_only_gap_detected") or not as_int(v61do, "return_bundle_preflight_pass")) else "blocked", "reason": f"preflight_only_gap_detected={v61do['preflight_only_gap_detected']}"})
decision_rows.append({"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["stage_id"], "status": row["status"], "reason": row["blocking_reason"]}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dp Return Schema Acceptance Blocker Gate

This gate explains why a full file preflight does not imply row-level return
acceptance. It groups blocker evidence by dispatch receipt, review chunk,
aggregate review, and generation result families.

Evidence emitted:

- schema_family_rows={len(family_rows)}
- ready_schema_family_rows={ready_family_rows}
- blocked_schema_family_rows={len(family_rows) - ready_family_rows}
- full_preflight_pass_rows={v61do['full_preflight_pass_rows']}/{v61do['full_preflight_rows']}
- return_bundle_preflight_pass={v61do['return_bundle_preflight_pass']}
- preflight_only_gap_detected={v61do['preflight_only_gap_detected']}
- expected_schema_artifact_rows={expected_artifact_rows}
- supplied_schema_artifact_rows={supplied_artifact_rows}
- accepted_schema_artifact_rows={accepted_artifact_rows}
- missing_schema_artifact_rows={missing_artifact_rows}
- invalid_schema_artifact_rows={invalid_artifact_rows}
- expected_payload_rows={expected_payload_rows}
- accepted_payload_rows={accepted_payload_rows}
- accepted_dispatch_receipt_rows={v53am['accepted_dispatch_receipt_rows']}/{v53am['dispatch_receipt_template_rows']}
- accepted_chunk_return_artifact_rows={v53am['accepted_chunk_return_artifact_rows']}/{v53am['review_chunk_return_artifact_rows']}
- answer_review_accepted_rows={v53am['answer_review_accepted_rows']}/{v53am['expected_human_review_rows']}
- accepted_adjudication_rows={v53am['accepted_adjudication_rows']}/{v53am['expected_adjudication_rows']}
- generation_result_accepted_rows={v53am['generation_result_accepted_rows']}/{v53am['generation_result_acceptance_rows']}
- actual_model_generation_ready={v53am['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dp=0

Allowed wording: schema acceptance blocker ledger is ready.
Blocked wording: review accepted, generation accepted, actual generation,
v1.0 comparison, latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DP_RETURN_SCHEMA_ACCEPTANCE_BLOCKER_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dp-return-schema-acceptance-blocker-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dp_return_schema_acceptance_blocker_gate_ready": 1,
    "ready_schema_family_rows": ready_family_rows,
    "blocked_schema_family_rows": len(family_rows) - ready_family_rows,
    "accepted_schema_artifact_rows": accepted_artifact_rows,
    "accepted_payload_rows": accepted_payload_rows,
    "return_bundle_preflight_pass": as_int(v61do, "return_bundle_preflight_pass"),
    "preflight_only_gap_detected": as_int(v61do, "preflight_only_gap_detected"),
    "actual_model_generation_ready": as_int(v53am, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dp_return_schema_acceptance_blocker_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dp_return_schema_acceptance_blocker_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
