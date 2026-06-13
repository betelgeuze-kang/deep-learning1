#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61db_runtime_admission_acceptance_refresh_gate"
RUN_ID="${V61DB_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61db_runtime_admission_acceptance_refresh_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61da_runtime_admission_aggregate_return_handoff_gate.sh" >/dev/null
V61CR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null
V61CW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null
V61CS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null

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
model_id = "mistralai/Mixtral-8x22B-v0.1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61da": (
        results / "v61da_runtime_admission_aggregate_return_handoff_gate_summary.csv",
        results / "v61da_runtime_admission_aggregate_return_handoff_gate_decision.csv",
        results / "v61da_runtime_admission_aggregate_return_handoff_gate" / "gate_001",
        "v61da_runtime_admission_aggregate_return_handoff_gate_ready",
    ),
    "v61cr": (
        results / "v61cr_complete_source_runtime_admission_return_intake_summary.csv",
        results / "v61cr_complete_source_runtime_admission_return_intake_decision.csv",
        results / "v61cr_complete_source_runtime_admission_return_intake" / "intake_001",
        "v61cr_complete_source_runtime_admission_return_intake_ready",
    ),
    "v61cw": (
        results / "v61cw_complete_source_runtime_admission_acceptance_bridge_summary.csv",
        results / "v61cw_complete_source_runtime_admission_acceptance_bridge_decision.csv",
        results / "v61cw_complete_source_runtime_admission_acceptance_bridge" / "bridge_001",
        "v61cw_complete_source_runtime_admission_acceptance_bridge_ready",
    ),
    "v61cs": (
        results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
        results / "v61cs_complete_source_generation_execution_admission_gate_decision.csv",
        results / "v61cs_complete_source_generation_execution_admission_gate" / "gate_001",
        "v61cs_complete_source_generation_execution_admission_gate_ready",
    ),
}

summaries = {}
for key, (summary_path, decision_path, source_dir, ready_field) in sources.items():
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v61db requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

copy(sources["v61da"][2] / "runtime_admission_aggregate_return_handoff_rows.csv", "source_v61da/runtime_admission_aggregate_return_handoff_rows.csv")
copy(sources["v61da"][2] / "runtime_admission_aggregate_return_handoff_command_rows.csv", "source_v61da/runtime_admission_aggregate_return_handoff_command_rows.csv")
copy(sources["v61cr"][2] / "complete_source_runtime_admission_return_artifact_status_rows.csv", "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv")
copy(sources["v61cw"][2] / "complete_source_runtime_admission_acceptance_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv")
copy(sources["v61cs"][2] / "complete_source_generation_execution_admission_rows.csv", "source_v61cs/complete_source_generation_execution_admission_rows.csv")

v61da = summaries["v61da"]
v61cr = summaries["v61cr"]
v61cw = summaries["v61cw"]
v61cs = summaries["v61cs"]

refresh_rows = [
    {
        "refresh_stage_id": "01-aggregate-runtime-return-handoff",
        "source_gate": "v61da",
        "required_rows": v61da["handoff_artifact_rows"],
        "accepted_rows": v61da["handoff_ready_rows"],
        "missing_rows": str(as_int(v61da, "handoff_artifact_rows") - as_int(v61da, "handoff_ready_rows")),
        "current_ready": v61da["aggregate_runtime_return_handoff_ready"],
        "next_command": "results/v61da_runtime_admission_aggregate_return_handoff_gate/gate_001/aggregate_return_handoff/VERIFY_AGGREGATE_RUNTIME_RETURN.sh /path/to/runtime_admission_return",
        "blocking_reason": "aggregate runtime return handoff artifacts are not ready",
    },
    {
        "refresh_stage_id": "02-v61cr-aggregate-runtime-return-intake",
        "source_gate": "v61cr",
        "required_rows": v61cr["expected_runtime_admission_return_artifacts"],
        "accepted_rows": v61cr["accepted_runtime_admission_return_artifacts"],
        "missing_rows": v61cr["missing_runtime_admission_return_artifacts"],
        "current_ready": v61cr["runtime_admission_return_artifact_ready"],
        "next_command": "V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return V61CR_REUSE_EXISTING=0 ./experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh",
        "blocking_reason": "aggregate runtime return files have not been accepted by v61cr",
    },
    {
        "refresh_stage_id": "03-v61cw-per-query-runtime-acceptance",
        "source_gate": "v61cw",
        "required_rows": v61cw["runtime_admission_acceptance_rows"],
        "accepted_rows": v61cw["runtime_admission_accepted_rows"],
        "missing_rows": str(as_int(v61cw, "runtime_admission_acceptance_rows") - as_int(v61cw, "runtime_admission_accepted_rows")),
        "current_ready": v61cw["complete_source_runtime_admission_execution_ready"],
        "next_command": "V61CW_REUSE_EXISTING=0 ./experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh",
        "blocking_reason": "per-query runtime admission acceptance rows are not accepted",
    },
    {
        "refresh_stage_id": "04-v61cs-generation-admission-refresh",
        "source_gate": "v61cs",
        "required_rows": v61cs["generation_execution_admission_rows"],
        "accepted_rows": v61cs["generation_execution_admitted_rows"],
        "missing_rows": v61cs["generation_execution_blocked_rows"],
        "current_ready": v61cs["generation_execution_admission_ready"],
        "next_command": "V61CS_REUSE_EXISTING=0 ./experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh",
        "blocking_reason": "generation admission remains blocked by runtime/review/result gates",
    },
]
write_csv(run_dir / "runtime_admission_acceptance_refresh_stage_rows.csv", list(refresh_rows[0].keys()), refresh_rows)

command_rows = [
    {
        "command_id": "01-verify-aggregate-return",
        "command": refresh_rows[0]["next_command"],
        "ready_to_run_now": "1",
        "expected_return": "five aggregate runtime return files are present",
    },
    {
        "command_id": "02-run-v61cr-intake",
        "command": refresh_rows[1]["next_command"],
        "ready_to_run_now": v61da["aggregate_runtime_return_handoff_ready"],
        "expected_return": "accepted_runtime_admission_return_artifacts=5",
    },
    {
        "command_id": "03-refresh-v61cw-acceptance",
        "command": refresh_rows[2]["next_command"],
        "ready_to_run_now": v61cr["runtime_admission_return_artifact_ready"],
        "expected_return": "runtime_admission_accepted_rows=1000",
    },
    {
        "command_id": "04-refresh-v61cs-admission",
        "command": refresh_rows[3]["next_command"],
        "ready_to_run_now": v61cw["complete_source_runtime_admission_execution_ready"],
        "expected_return": "runtime_admission_blocked_generation_rows=0 if review/result gates also allow it",
    },
]
write_csv(run_dir / "runtime_admission_acceptance_refresh_command_rows.csv", list(command_rows[0].keys()), command_rows)

ready_refresh_stage_rows = sum(1 for row in refresh_rows if row["current_ready"] == "1")
blocked_refresh_stage_rows = len(refresh_rows) - ready_refresh_stage_rows
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")
runtime_refresh_ready = int(
    as_int(v61da, "aggregate_runtime_return_handoff_ready")
    and as_int(v61cr, "runtime_admission_return_artifact_ready")
    and as_int(v61cw, "complete_source_runtime_admission_execution_ready")
)

metric = {
    "metric_id": "v61db_runtime_admission_acceptance_refresh_gate_metrics",
    "model_id": model_id,
    "v61da_runtime_admission_aggregate_return_handoff_gate_ready": v61da["v61da_runtime_admission_aggregate_return_handoff_gate_ready"],
    "v61cr_complete_source_runtime_admission_return_intake_ready": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"],
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": v61cw["v61cw_complete_source_runtime_admission_acceptance_bridge_ready"],
    "v61cs_complete_source_generation_execution_admission_gate_ready": v61cs["v61cs_complete_source_generation_execution_admission_gate_ready"],
    "refresh_stage_rows": str(len(refresh_rows)),
    "ready_refresh_stage_rows": str(ready_refresh_stage_rows),
    "blocked_refresh_stage_rows": str(blocked_refresh_stage_rows),
    "refresh_command_rows": str(len(command_rows)),
    "ready_refresh_command_rows": str(ready_command_rows),
    "handoff_artifact_rows": v61da["handoff_artifact_rows"],
    "handoff_ready_rows": v61da["handoff_ready_rows"],
    "aggregate_runtime_return_handoff_ready": v61da["aggregate_runtime_return_handoff_ready"],
    "expected_runtime_admission_return_artifacts": v61cr["expected_runtime_admission_return_artifacts"],
    "accepted_runtime_admission_return_artifacts": v61cr["accepted_runtime_admission_return_artifacts"],
    "runtime_admission_return_artifact_ready": v61cr["runtime_admission_return_artifact_ready"],
    "runtime_admission_acceptance_rows": v61cw["runtime_admission_acceptance_rows"],
    "runtime_admission_accepted_rows": v61cw["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61cw["complete_source_runtime_admission_execution_ready"],
    "generation_execution_admission_rows": v61cs["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61cs["generation_execution_admitted_rows"],
    "runtime_admission_blocked_generation_rows": v61cs["runtime_admission_blocked_generation_rows"],
    "generation_execution_admission_ready": v61cs["generation_execution_admission_ready"],
    "runtime_admission_acceptance_refresh_ready": str(runtime_refresh_ready),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61db": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "runtime_admission_acceptance_refresh_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61db_runtime_admission_acceptance_refresh_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "aggregate-runtime-return-handoff", "status": status(as_int(v61da, "aggregate_runtime_return_handoff_ready")), "reason": f"handoff_ready_rows={v61da['handoff_ready_rows']}/{v61da['handoff_artifact_rows']}"},
    {"gate": "v61cr-aggregate-runtime-return-intake", "status": status(as_int(v61cr, "runtime_admission_return_artifact_ready")), "reason": f"accepted_runtime_admission_return_artifacts={v61cr['accepted_runtime_admission_return_artifacts']}/{v61cr['expected_runtime_admission_return_artifacts']}"},
    {"gate": "v61cw-per-query-runtime-acceptance", "status": status(as_int(v61cw, "complete_source_runtime_admission_execution_ready")), "reason": f"runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}/{v61cw['runtime_admission_acceptance_rows']}"},
    {"gate": "v61cs-generation-admission-refresh", "status": status(as_int(v61cs, "generation_execution_admission_ready")), "reason": f"generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}/{v61cs['generation_execution_admission_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run and review/result gates remain blocked"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61db writes metadata and copied evidence only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61db Runtime Admission Acceptance Refresh Gate Boundary

This artifact checks the refresh chain after aggregate runtime return handoff:
v61da handoff, v61cr aggregate intake, v61cw per-query acceptance, and v61cs
generation admission refresh. It does not fabricate return rows and does not
claim actual generation.

Evidence emitted:

- refresh_stage_rows={len(refresh_rows)}
- ready_refresh_stage_rows={ready_refresh_stage_rows}
- blocked_refresh_stage_rows={blocked_refresh_stage_rows}
- refresh_command_rows={len(command_rows)}
- ready_refresh_command_rows={ready_command_rows}
- handoff_artifact_rows={v61da['handoff_artifact_rows']}
- handoff_ready_rows={v61da['handoff_ready_rows']}
- aggregate_runtime_return_handoff_ready={v61da['aggregate_runtime_return_handoff_ready']}
- expected_runtime_admission_return_artifacts={v61cr['expected_runtime_admission_return_artifacts']}
- accepted_runtime_admission_return_artifacts={v61cr['accepted_runtime_admission_return_artifacts']}
- runtime_admission_return_artifact_ready={v61cr['runtime_admission_return_artifact_ready']}
- runtime_admission_acceptance_rows={v61cw['runtime_admission_acceptance_rows']}
- runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}
- complete_source_runtime_admission_execution_ready={v61cw['complete_source_runtime_admission_execution_ready']}
- generation_execution_admission_rows={v61cs['generation_execution_admission_rows']}
- generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}
- runtime_admission_blocked_generation_rows={v61cs['runtime_admission_blocked_generation_rows']}
- generation_execution_admission_ready={v61cs['generation_execution_admission_ready']}
- runtime_admission_acceptance_refresh_ready={runtime_refresh_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61db=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: runtime admission acceptance refresh gate. Blocked wording:
actual Mixtral generation, production latency, near-frontier quality, or
release readiness.
"""
(run_dir / "V61DB_RUNTIME_ADMISSION_ACCEPTANCE_REFRESH_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61db_runtime_admission_acceptance_refresh_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61db_runtime_admission_acceptance_refresh_gate_ready": 1,
    "refresh_stage_rows": len(refresh_rows),
    "ready_refresh_stage_rows": ready_refresh_stage_rows,
    "blocked_refresh_stage_rows": blocked_refresh_stage_rows,
    "runtime_admission_acceptance_refresh_ready": runtime_refresh_ready,
    "actual_model_generation_ready": 0,
    "source_v61da_summary_sha256": sha256(sources["v61da"][0]),
    "source_v61cr_summary_sha256": sha256(sources["v61cr"][0]),
    "source_v61cw_summary_sha256": sha256(sources["v61cw"][0]),
    "source_v61cs_summary_sha256": sha256(sources["v61cs"][0]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61db_runtime_admission_acceptance_refresh_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61db_runtime_admission_acceptance_refresh_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
