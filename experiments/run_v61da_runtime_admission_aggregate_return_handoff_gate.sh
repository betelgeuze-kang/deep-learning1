#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61da_runtime_admission_aggregate_return_handoff_gate"
RUN_ID="${V61DA_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DA_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61da_runtime_admission_aggregate_return_handoff_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CZ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cz_runtime_admission_chunk_return_intake.sh" >/dev/null
V61CR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null
V61CW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh" >/dev/null

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
handoff_dir = run_dir / "aggregate_return_handoff"
handoff_dir.mkdir(parents=True, exist_ok=True)


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
    "v61cz": (
        results / "v61cz_runtime_admission_chunk_return_intake_summary.csv",
        results / "v61cz_runtime_admission_chunk_return_intake_decision.csv",
        results / "v61cz_runtime_admission_chunk_return_intake" / "intake_001",
        "v61cz_runtime_admission_chunk_return_intake_ready",
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
}

summaries = {}
for key, (summary_path, decision_path, source_dir, ready_field) in sources.items():
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v61da requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

copy(sources["v61cz"][2] / "runtime_admission_aggregate_return_merge_rows.csv", "source_v61cz/runtime_admission_aggregate_return_merge_rows.csv")
copy(sources["v61cz"][2] / "runtime_admission_chunk_return_artifact_status_rows.csv", "source_v61cz/runtime_admission_chunk_return_artifact_status_rows.csv")
copy(sources["v61cz"][2] / "runtime_admission_chunk_return_status_rows.csv", "source_v61cz/runtime_admission_chunk_return_status_rows.csv")
copy(sources["v61cr"][2] / "complete_source_runtime_admission_return_template_rows.csv", "source_v61cr/complete_source_runtime_admission_return_template_rows.csv")
copy(sources["v61cr"][2] / "complete_source_runtime_admission_return_required_field_rows.csv", "source_v61cr/complete_source_runtime_admission_return_required_field_rows.csv")
copy(sources["v61cw"][2] / "complete_source_runtime_admission_acceptance_rows.csv", "source_v61cw/complete_source_runtime_admission_acceptance_rows.csv")

v61cz = summaries["v61cz"]
v61cr = summaries["v61cr"]
v61cw = summaries["v61cw"]
merge_rows = read_csv(sources["v61cz"][2] / "runtime_admission_aggregate_return_merge_rows.csv")
template_rows = read_csv(sources["v61cr"][2] / "complete_source_runtime_admission_return_template_rows.csv")
if len(merge_rows) != 5 or len(template_rows) != 5:
    raise SystemExit("v61da expects five aggregate merge rows and five v61cr template rows")

template_by_path = {row["result_artifact"]: row for row in template_rows}
handoff_rows = []
handoff_ready_rows = 0
for row in merge_rows:
    template = template_by_path.get(row["aggregate_return_path"], {})
    merge_ready = as_int(row, "merge_ready")
    handoff_ready = int(merge_ready and row["accepted_rows_from_chunks"] == row["required_rows"])
    handoff_ready_rows += handoff_ready
    handoff_rows.append(
        {
            "handoff_artifact_id": f"v61da::{row['result_artifact']}",
            "result_artifact": row["result_artifact"],
            "aggregate_return_path": row["aggregate_return_path"],
            "required_rows": row["required_rows"],
            "accepted_rows_from_chunks": row["accepted_rows_from_chunks"],
            "source_chunk_artifacts_required": row["source_chunk_artifacts_required"],
            "source_chunk_artifacts_accepted": row["source_chunk_artifacts_accepted"],
            "merge_ready": row["merge_ready"],
            "handoff_ready": str(handoff_ready),
            "v61cr_template_payload": template.get("example_payload", ""),
            "operator_note": "ready for v61cr intake" if handoff_ready else "aggregate runtime return is not merge-ready",
            "checkpoint_payload_bytes_downloaded_by_v61da": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "runtime_admission_aggregate_return_handoff_rows.csv", list(handoff_rows[0].keys()), handoff_rows)
write_csv(handoff_dir / "EXPECTED_RUNTIME_ADMISSION_RETURN_FILES.csv", list(handoff_rows[0].keys()), handoff_rows)

aggregate_handoff_ready = int(handoff_ready_rows == len(handoff_rows))
runtime_acceptance_ready = int(aggregate_handoff_ready and as_int(v61cw, "complete_source_runtime_admission_execution_ready"))

command_rows = [
    {
        "command_id": "verify-aggregate-return-handoff",
        "command": "results/v61da_runtime_admission_aggregate_return_handoff_gate/gate_001/aggregate_return_handoff/VERIFY_AGGREGATE_RUNTIME_RETURN.sh /path/to/runtime_admission_return",
        "purpose": "verify five aggregate runtime admission return files before v61cr intake",
        "ready_to_run_now": "1",
    },
    {
        "command_id": "run-v61cr-aggregate-return-intake",
        "command": "V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return V61CR_REUSE_EXISTING=0 ./experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh",
        "purpose": "validate aggregate runtime return files",
        "ready_to_run_now": str(aggregate_handoff_ready),
    },
    {
        "command_id": "refresh-v61cw-runtime-acceptance",
        "command": "V61CW_REUSE_EXISTING=0 ./experiments/run_v61cw_complete_source_runtime_admission_acceptance_bridge.sh",
        "purpose": "refresh per-query runtime admission acceptance after v61cr intake",
        "ready_to_run_now": str(aggregate_handoff_ready),
    },
    {
        "command_id": "refresh-v61cs-generation-admission",
        "command": "V61CS_REUSE_EXISTING=0 ./experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh",
        "purpose": "refresh generation admission after runtime acceptance",
        "ready_to_run_now": str(runtime_acceptance_ready),
    },
]
write_csv(run_dir / "runtime_admission_aggregate_return_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

(handoff_dir / "README.md").write_text(
    "# v61da Runtime Admission Aggregate Return Handoff Gate\n\n"
    "This handoff verifies the five aggregate runtime admission return files "
    "expected by v61cr after v61cz marks chunk returns merge-ready. It does not "
    "fabricate missing returns and does not claim runtime admission acceptance.\n",
    encoding="utf-8",
)
(handoff_dir / "RUNTIME_ADMISSION_RETURN_ENV.template").write_text(
    "V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return\n"
    "V61DA_EXPECTED_FILES=results/v61da_runtime_admission_aggregate_return_handoff_gate/gate_001/aggregate_return_handoff/EXPECTED_RUNTIME_ADMISSION_RETURN_FILES.csv\n"
    "DRY_RUN=1\n",
    encoding="utf-8",
)
verify_script = handoff_dir / "VERIFY_AGGREGATE_RUNTIME_RETURN.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 <runtime_admission_return_dir>" >&2
  exit 2
fi

RETURN_DIR="$1"
HANDOFF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED="$HANDOFF_DIR/EXPECTED_RUNTIME_ADMISSION_RETURN_FILES.csv"

if [[ ! -s "$EXPECTED" ]]; then
  echo "missing expected file manifest: $EXPECTED" >&2
  exit 1
fi
if [[ ! -d "$RETURN_DIR" ]]; then
  echo "runtime admission return dir does not exist: $RETURN_DIR" >&2
  exit 1
fi

python3 - "$EXPECTED" "$RETURN_DIR" <<'INNER_PY'
import csv
import sys
from pathlib import Path

expected_path = Path(sys.argv[1])
return_dir = Path(sys.argv[2])
missing = []
for row in csv.DictReader(expected_path.open(newline='', encoding='utf-8')):
    target = return_dir / row["aggregate_return_path"]
    if not target.is_file():
        missing.append(str(target))
if missing:
    raise SystemExit("missing aggregate runtime return files: " + ", ".join(missing[:3]))
print("aggregate runtime return files are present")
INNER_PY
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

file_rows = [
    {"handoff_file": "aggregate_return_handoff/README.md", "purpose": "handoff overview", "file_ready": "1"},
    {"handoff_file": "aggregate_return_handoff/RUNTIME_ADMISSION_RETURN_ENV.template", "purpose": "operator environment template", "file_ready": "1"},
    {"handoff_file": "aggregate_return_handoff/EXPECTED_RUNTIME_ADMISSION_RETURN_FILES.csv", "purpose": "five aggregate return file manifest", "file_ready": "1"},
    {"handoff_file": "aggregate_return_handoff/VERIFY_AGGREGATE_RUNTIME_RETURN.sh", "purpose": "presence verifier before v61cr intake", "file_ready": "1"},
]
write_csv(run_dir / "runtime_admission_aggregate_return_handoff_file_rows.csv", list(file_rows[0].keys()), file_rows)

ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

metric = {
    "metric_id": "v61da_runtime_admission_aggregate_return_handoff_gate_metrics",
    "model_id": model_id,
    "v61cz_runtime_admission_chunk_return_intake_ready": v61cz["v61cz_runtime_admission_chunk_return_intake_ready"],
    "v61cr_complete_source_runtime_admission_return_intake_ready": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"],
    "v61cw_complete_source_runtime_admission_acceptance_bridge_ready": v61cw["v61cw_complete_source_runtime_admission_acceptance_bridge_ready"],
    "runtime_admission_chunk_rows": v61cz["runtime_admission_chunk_rows"],
    "accepted_runtime_admission_chunk_rows": v61cz["accepted_runtime_admission_chunk_rows"],
    "runtime_admission_aggregate_return_artifact_rows": v61cz["runtime_admission_aggregate_return_artifact_rows"],
    "aggregate_runtime_return_merge_ready_rows": v61cz["aggregate_runtime_return_merge_ready_rows"],
    "aggregate_runtime_return_merge_ready": v61cz["aggregate_runtime_return_merge_ready"],
    "handoff_artifact_rows": str(len(handoff_rows)),
    "handoff_ready_rows": str(handoff_ready_rows),
    "aggregate_runtime_return_handoff_ready": str(aggregate_handoff_ready),
    "handoff_command_rows": str(len(command_rows)),
    "ready_handoff_command_rows": str(ready_command_rows),
    "handoff_file_rows": str(len(file_rows)),
    "runtime_admission_accepted_rows": v61cw["runtime_admission_accepted_rows"],
    "complete_source_runtime_admission_execution_ready": v61cw["complete_source_runtime_admission_execution_ready"],
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61da": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "runtime_admission_aggregate_return_handoff_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61da_runtime_admission_aggregate_return_handoff_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "runtime-admission-chunk-return-input", "status": "pass", "reason": "v61cz is ready"},
    {"gate": "aggregate-runtime-return-merge", "status": status(as_int(v61cz, "aggregate_runtime_return_merge_ready")), "reason": f"aggregate_runtime_return_merge_ready_rows={v61cz['aggregate_runtime_return_merge_ready_rows']}/{v61cz['runtime_admission_aggregate_return_artifact_rows']}"},
    {"gate": "aggregate-runtime-return-handoff", "status": status(aggregate_handoff_ready), "reason": f"handoff_ready_rows={handoff_ready_rows}/{len(handoff_rows)}"},
    {"gate": "complete-source-runtime-admission-acceptance", "status": status(runtime_acceptance_ready), "reason": f"runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}/{v61cw['runtime_admission_acceptance_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61da writes metadata and copied evidence only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61da Runtime Admission Aggregate Return Handoff Gate Boundary

This artifact creates the handoff surface between v61cz chunk return intake and
v61cr/v61cw aggregate runtime admission intake. It does not fabricate aggregate
return files and does not claim runtime admission acceptance.

Evidence emitted:

- runtime_admission_chunk_rows={v61cz['runtime_admission_chunk_rows']}
- accepted_runtime_admission_chunk_rows={v61cz['accepted_runtime_admission_chunk_rows']}
- runtime_admission_aggregate_return_artifact_rows={v61cz['runtime_admission_aggregate_return_artifact_rows']}
- aggregate_runtime_return_merge_ready_rows={v61cz['aggregate_runtime_return_merge_ready_rows']}
- aggregate_runtime_return_merge_ready={v61cz['aggregate_runtime_return_merge_ready']}
- handoff_artifact_rows={len(handoff_rows)}
- handoff_ready_rows={handoff_ready_rows}
- aggregate_runtime_return_handoff_ready={aggregate_handoff_ready}
- handoff_command_rows={len(command_rows)}
- ready_handoff_command_rows={ready_command_rows}
- runtime_admission_accepted_rows={v61cw['runtime_admission_accepted_rows']}
- complete_source_runtime_admission_execution_ready={v61cw['complete_source_runtime_admission_execution_ready']}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61da=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: aggregate runtime admission return handoff gate. Blocked
wording: completed runtime admission, actual Mixtral generation, production
latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61DA_RUNTIME_ADMISSION_AGGREGATE_RETURN_HANDOFF_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61da_runtime_admission_aggregate_return_handoff_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61da_runtime_admission_aggregate_return_handoff_gate_ready": 1,
    "aggregate_runtime_return_handoff_ready": aggregate_handoff_ready,
    "handoff_artifact_rows": len(handoff_rows),
    "handoff_ready_rows": handoff_ready_rows,
    "complete_source_runtime_admission_execution_ready": runtime_acceptance_ready,
    "actual_model_generation_ready": 0,
    "source_v61cz_summary_sha256": sha256(sources["v61cz"][0]),
    "source_v61cr_summary_sha256": sha256(sources["v61cr"][0]),
    "source_v61cw_summary_sha256": sha256(sources["v61cw"][0]),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61da_runtime_admission_aggregate_return_handoff_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61da_runtime_admission_aggregate_return_handoff_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
