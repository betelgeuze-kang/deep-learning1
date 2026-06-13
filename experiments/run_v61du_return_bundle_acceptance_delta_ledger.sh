#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61du_return_bundle_acceptance_delta_ledger"
RUN_ID="${V61DU_RUN_ID:-delta_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61du_return_bundle_acceptance_delta_ledger_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dt_return_bundle_closure_replay_gate.sh" >/dev/null

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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def delta(target, observed):
    return max(0, int(target) - int(observed))


sources = {
    "v61dt_summary": results / "v61dt_return_bundle_closure_replay_gate_summary.csv",
    "v61dt_decision": results / "v61dt_return_bundle_closure_replay_gate_decision.csv",
    "v61dt_stages": results / "v61dt_return_bundle_closure_replay_gate/closure_001/return_bundle_closure_replay_stage_rows.csv",
    "v61dt_commands": results / "v61dt_return_bundle_closure_replay_gate/closure_001/return_bundle_closure_replay_command_rows.csv",
    "v61dr_families": results / "v61dr_return_bundle_schema_preflight_gate/preflight_001/return_bundle_schema_preflight_family_rows.csv",
    "v53am_summary": results / "v53am_complete_source_return_acceptance_replay_summary.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61du source {key}: {path}")

copy(sources["v61dt_summary"], "source_v61dt/v61dt_return_bundle_closure_replay_gate_summary.csv")
copy(sources["v61dt_decision"], "source_v61dt/v61dt_return_bundle_closure_replay_gate_decision.csv")
copy(sources["v61dt_stages"], "source_v61dt/return_bundle_closure_replay_stage_rows.csv")
copy(sources["v61dt_commands"], "source_v61dt/return_bundle_closure_replay_command_rows.csv")
copy(sources["v61dr_families"], "source_v61dr/return_bundle_schema_preflight_family_rows.csv")
copy(sources["v53am_summary"], "source_v53am/v53am_complete_source_return_acceptance_replay_summary.csv")

v61dt = read_csv(sources["v61dt_summary"])[0]
stage_source_rows = read_csv(sources["v61dt_stages"])
command_source_rows = read_csv(sources["v61dt_commands"])
family_source_rows = read_csv(sources["v61dr_families"])

if v61dt.get("v61dt_return_bundle_closure_replay_gate_ready") != "1":
    raise SystemExit("v61du requires v61dt ready")

stage_lookup = {row["closure_stage_id"]: row for row in stage_source_rows}
stage_specs = [
    ("01-return-bundle-supplied", "bundle-directory", 1, as_int(v61dt, "return_bundle_dir_exists"), "directory"),
    ("02-schema-preflight-surface", "schema-artifact-surface", 81, as_int(v61dt, "schema_preflight_artifact_rows"), "artifact"),
    ("03-schema-preflight-pass", "schema-artifact-pass", 81, as_int(v61dt, "schema_preflight_pass_rows"), "artifact"),
    ("04-schema-acceptance-handoff-audited", "handoff-stage-surface", 12, as_int(v61dt, "schema_handoff_stage_rows"), "stage"),
    ("05-acceptance-replay-surface", "acceptance-replay-surface", 1, 1 if as_int(v61dt, "v53am_complete_source_return_acceptance_replay_ready") else 0, "surface"),
    ("06-full-return-preflight-pass", "full-return-preflight-pass", 81, as_int(v61dt, "preflight_pass_rows"), "artifact"),
    ("07-dispatch-receipts-accepted", "dispatch-receipt-accepted", as_int(v61dt, "dispatch_receipt_template_rows"), as_int(v61dt, "accepted_dispatch_receipt_rows"), "receipt"),
    ("08-review-chunks-accepted", "review-chunk-artifact-accepted", as_int(v61dt, "review_chunk_return_artifact_rows"), as_int(v61dt, "accepted_chunk_return_artifact_rows"), "artifact"),
    ("09-aggregate-review-accepted", "aggregate-review-row-accepted", as_int(v61dt, "expected_human_review_rows") + as_int(v61dt, "expected_adjudication_rows"), as_int(v61dt, "answer_review_accepted_rows") + as_int(v61dt, "accepted_adjudication_rows"), "row"),
    ("10-v53-review-ready", "v53-review-ready", 1, as_int(v61dt, "v53_ready"), "gate"),
    ("11-full-shard-runtime-closed", "runtime-admission-accepted", 1000, as_int(v61dt, "runtime_admission_accepted_rows"), "row"),
    ("12-generation-execution-admitted", "generation-execution-admitted", as_int(v61dt, "generation_execution_admission_rows"), as_int(v61dt, "generation_execution_admitted_rows"), "row"),
    ("13-generation-result-artifacts-accepted", "generation-result-artifact-accepted", as_int(v61dt, "expected_generation_result_artifacts"), as_int(v61dt, "accepted_generation_result_artifacts"), "artifact"),
    ("14-generation-result-rows-accepted", "generation-result-row-accepted", as_int(v61dt, "generation_result_acceptance_rows"), as_int(v61dt, "generation_result_accepted_rows"), "row"),
    ("15-actual-generation-ready", "actual-generation-ready", 1, as_int(v61dt, "actual_model_generation_ready"), "gate"),
]
stage_rows = []
for stage_id, delta_name, target_count, observed_count, unit in stage_specs:
    source = stage_lookup[stage_id]
    missing_count = delta(target_count, observed_count)
    stage_rows.append(
        {
            "closure_stage_id": stage_id,
            "delta_name": delta_name,
            "source_gate": source["source_gate"],
            "source_status": source["status"],
            "target_count": str(target_count),
            "observed_count": str(observed_count),
            "missing_count": str(missing_count),
            "unit": unit,
            "delta_closed": "1" if missing_count == 0 else "0",
            "next_command": source["next_command"],
            "blocking_reason": source["blocking_reason"],
        }
    )
write_csv(run_dir / "return_bundle_acceptance_delta_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

family_map = {
    row["schema_family"]: row for row in family_source_rows
}
family_rows = [
    {
        "delta_family": "bundle-logistics",
        "target_count": "1",
        "observed_count": v61dt["return_bundle_dir_exists"],
        "missing_count": str(delta(1, as_int(v61dt, "return_bundle_dir_exists"))),
        "unit": "directory",
        "validator_gate": "v61dt-input",
    },
    {
        "delta_family": "dispatch-receipt-json",
        "target_count": family_map["dispatch-receipt-json"]["expected_artifact_rows"],
        "observed_count": family_map["dispatch-receipt-json"]["schema_preflight_pass_artifact_rows"],
        "missing_count": family_map["dispatch-receipt-json"]["schema_preflight_missing_artifact_rows"],
        "unit": "artifact",
        "validator_gate": family_map["dispatch-receipt-json"]["validator_gate"],
    },
    {
        "delta_family": "review-chunk-return-csv",
        "target_count": family_map["review-chunk-return-csv"]["expected_artifact_rows"],
        "observed_count": family_map["review-chunk-return-csv"]["schema_preflight_pass_artifact_rows"],
        "missing_count": family_map["review-chunk-return-csv"]["schema_preflight_missing_artifact_rows"],
        "unit": "artifact",
        "validator_gate": family_map["review-chunk-return-csv"]["validator_gate"],
    },
    {
        "delta_family": "aggregate-review-return-artifacts",
        "target_count": family_map["aggregate-review-return"]["expected_artifact_rows"],
        "observed_count": family_map["aggregate-review-return"]["schema_preflight_pass_artifact_rows"],
        "missing_count": family_map["aggregate-review-return"]["schema_preflight_missing_artifact_rows"],
        "unit": "artifact",
        "validator_gate": family_map["aggregate-review-return"]["validator_gate"],
    },
    {
        "delta_family": "aggregate-review-return-rows",
        "target_count": str(as_int(v61dt, "expected_human_review_rows") + as_int(v61dt, "expected_adjudication_rows")),
        "observed_count": str(as_int(v61dt, "answer_review_accepted_rows") + as_int(v61dt, "accepted_adjudication_rows")),
        "missing_count": str(delta(as_int(v61dt, "expected_human_review_rows") + as_int(v61dt, "expected_adjudication_rows"), as_int(v61dt, "answer_review_accepted_rows") + as_int(v61dt, "accepted_adjudication_rows"))),
        "unit": "row",
        "validator_gate": "v53s/v53y/v53v",
    },
    {
        "delta_family": "generation-result-return-artifacts",
        "target_count": family_map["generation-result-return"]["expected_artifact_rows"],
        "observed_count": family_map["generation-result-return"]["schema_preflight_pass_artifact_rows"],
        "missing_count": family_map["generation-result-return"]["schema_preflight_missing_artifact_rows"],
        "unit": "artifact",
        "validator_gate": family_map["generation-result-return"]["validator_gate"],
    },
    {
        "delta_family": "generation-execution-admission",
        "target_count": v61dt["generation_execution_admission_rows"],
        "observed_count": v61dt["generation_execution_admitted_rows"],
        "missing_count": str(delta(as_int(v61dt, "generation_execution_admission_rows"), as_int(v61dt, "generation_execution_admitted_rows"))),
        "unit": "row",
        "validator_gate": "v61de",
    },
    {
        "delta_family": "generation-result-accepted-rows",
        "target_count": v61dt["generation_result_acceptance_rows"],
        "observed_count": v61dt["generation_result_accepted_rows"],
        "missing_count": str(delta(as_int(v61dt, "generation_result_acceptance_rows"), as_int(v61dt, "generation_result_accepted_rows"))),
        "unit": "row",
        "validator_gate": "v61cu/v61de",
    },
    {
        "delta_family": "full-shard-runtime",
        "target_count": "1000",
        "observed_count": v61dt["runtime_admission_accepted_rows"],
        "missing_count": str(delta(1000, as_int(v61dt, "runtime_admission_accepted_rows"))),
        "unit": "row",
        "validator_gate": "v61dg/v61cw",
    },
    {
        "delta_family": "actual-generation",
        "target_count": "1",
        "observed_count": v61dt["actual_model_generation_ready"],
        "missing_count": str(delta(1, as_int(v61dt, "actual_model_generation_ready"))),
        "unit": "gate",
        "validator_gate": "v61de",
    },
]
for row in family_rows:
    row["delta_closed"] = "1" if row["missing_count"] == "0" else "0"
write_csv(run_dir / "return_bundle_acceptance_delta_family_rows.csv", list(family_rows[0].keys()), family_rows)

command_rows = []
for row in command_source_rows:
    command_rows.append(
        {
            "command_id": row["command_id"],
            "ready_to_run_now": row["ready_to_run_now"],
            "closure_stage_id": row["closure_stage_id"],
            "command": row["command"],
            "expected_transition": row["expected_transition"],
        }
    )
write_csv(run_dir / "return_bundle_acceptance_delta_command_rows.csv", list(command_rows[0].keys()), command_rows)

missing_payload_rows = delta(as_int(v61dt, "expected_payload_rows"), as_int(v61dt, "accepted_payload_rows"))
metric = {
    "metric_id": "v61du_return_bundle_acceptance_delta_ledger_metrics",
    "v61dt_return_bundle_closure_replay_gate_ready": v61dt["v61dt_return_bundle_closure_replay_gate_ready"],
    "source_gate_rows": "3",
    "delta_stage_rows": str(len(stage_rows)),
    "ready_delta_stage_rows": str(sum(row["source_status"] == "ready" for row in stage_rows)),
    "blocked_delta_stage_rows": str(sum(row["source_status"] == "blocked" for row in stage_rows)),
    "closed_delta_stage_rows": str(sum(row["delta_closed"] == "1" for row in stage_rows)),
    "open_delta_stage_rows": str(sum(row["delta_closed"] == "0" for row in stage_rows)),
    "delta_family_rows": str(len(family_rows)),
    "closed_delta_family_rows": str(sum(row["delta_closed"] == "1" for row in family_rows)),
    "open_delta_family_rows": str(sum(row["delta_closed"] == "0" for row in family_rows)),
    "delta_command_rows": str(len(command_rows)),
    "ready_delta_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "return_bundle_dir_supplied": v61dt["return_bundle_dir_supplied"],
    "return_bundle_dir_exists": v61dt["return_bundle_dir_exists"],
    "schema_preflight_missing_artifact_rows": str(delta(as_int(v61dt, "schema_preflight_artifact_rows"), as_int(v61dt, "schema_preflight_pass_rows"))),
    "full_preflight_missing_artifact_rows": str(delta(as_int(v61dt, "preflight_rows"), as_int(v61dt, "preflight_pass_rows"))),
    "missing_payload_rows": str(missing_payload_rows),
    "missing_dispatch_receipt_rows": str(delta(as_int(v61dt, "dispatch_receipt_template_rows"), as_int(v61dt, "accepted_dispatch_receipt_rows"))),
    "missing_review_chunk_artifact_rows": str(delta(as_int(v61dt, "review_chunk_return_artifact_rows"), as_int(v61dt, "accepted_chunk_return_artifact_rows"))),
    "missing_answer_review_rows": str(delta(as_int(v61dt, "expected_human_review_rows"), as_int(v61dt, "answer_review_accepted_rows"))),
    "missing_adjudication_rows": str(delta(as_int(v61dt, "expected_adjudication_rows"), as_int(v61dt, "accepted_adjudication_rows"))),
    "missing_generation_execution_rows": str(delta(as_int(v61dt, "generation_execution_admission_rows"), as_int(v61dt, "generation_execution_admitted_rows"))),
    "missing_generation_result_artifacts": str(delta(as_int(v61dt, "expected_generation_result_artifacts"), as_int(v61dt, "accepted_generation_result_artifacts"))),
    "missing_generation_result_rows": str(delta(as_int(v61dt, "generation_result_acceptance_rows"), as_int(v61dt, "generation_result_accepted_rows"))),
    "schema_acceptance_ready": v61dt["schema_acceptance_ready"],
    "return_acceptance_replay_closed": v61dt["return_acceptance_replay_closed"],
    "actual_model_generation_ready": v61dt["actual_model_generation_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61du": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_bundle_acceptance_delta_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61du_return_bundle_acceptance_delta_ledger_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["closure_stage_id"], "status": "pass" if row["delta_closed"] == "1" else "blocked", "reason": f"missing_count={row['missing_count']} {row['unit']}"}
    for row in stage_rows
]
decision_rows.extend(
    [
        {"gate": "delta-ledger-ready", "status": "pass", "reason": "all v61dt closure stages have explicit target/observed/missing deltas"},
        {"gate": "payload-acceptance", "status": "blocked", "reason": f"missing_payload_rows={missing_payload_rows}"},
        {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
        {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": row["closure_stage_id"], "status": "closed" if row["delta_closed"] == "1" else "open", "reason": f"missing_count={row['missing_count']} {row['unit']}"}
    for row in stage_rows
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61du Return Bundle Acceptance Delta Ledger

This gate turns the v61dt closure replay into explicit target/observed/missing
deltas. It does not accept returned evidence and does not execute generation.

Evidence emitted:

- delta_stage_rows={len(stage_rows)}
- ready_delta_stage_rows={metric['ready_delta_stage_rows']}
- blocked_delta_stage_rows={metric['blocked_delta_stage_rows']}
- closed_delta_stage_rows={metric['closed_delta_stage_rows']}
- open_delta_stage_rows={metric['open_delta_stage_rows']}
- delta_family_rows={len(family_rows)}
- closed_delta_family_rows={metric['closed_delta_family_rows']}
- open_delta_family_rows={metric['open_delta_family_rows']}
- schema_preflight_missing_artifact_rows={metric['schema_preflight_missing_artifact_rows']}
- full_preflight_missing_artifact_rows={metric['full_preflight_missing_artifact_rows']}
- missing_payload_rows={missing_payload_rows}
- missing_dispatch_receipt_rows={metric['missing_dispatch_receipt_rows']}
- missing_review_chunk_artifact_rows={metric['missing_review_chunk_artifact_rows']}
- missing_answer_review_rows={metric['missing_answer_review_rows']}
- missing_adjudication_rows={metric['missing_adjudication_rows']}
- missing_generation_execution_rows={metric['missing_generation_execution_rows']}
- missing_generation_result_artifacts={metric['missing_generation_result_artifacts']}
- missing_generation_result_rows={metric['missing_generation_result_rows']}
- actual_model_generation_ready={v61dt['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61du=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: return-bundle acceptance deltas are explicit.
Blocked wording: returned evidence accepted, actual generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DU_RETURN_BUNDLE_ACCEPTANCE_DELTA_LEDGER_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61du-return-bundle-acceptance-delta-ledger",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61du_return_bundle_acceptance_delta_ledger_ready": 1,
    "delta_stage_rows": len(stage_rows),
    "closed_delta_stage_rows": int(metric["closed_delta_stage_rows"]),
    "open_delta_stage_rows": int(metric["open_delta_stage_rows"]),
    "delta_family_rows": len(family_rows),
    "closed_delta_family_rows": int(metric["closed_delta_family_rows"]),
    "open_delta_family_rows": int(metric["open_delta_family_rows"]),
    "missing_payload_rows": missing_payload_rows,
    "actual_model_generation_ready": as_int(v61dt, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_downloaded_by_v61du": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61du_return_bundle_acceptance_delta_ledger_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"v61du_return_bundle_acceptance_delta_ledger_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
