#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ct_complete_source_generation_execution_operator_bundle"
RUN_ID="${V61CT_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CT_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ct_complete_source_generation_execution_operator_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

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


def status(flag):
    return "pass" if flag else "blocked"


v61cs_dir = results / "v61cs_complete_source_generation_execution_admission_gate" / "gate_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"
v61cs_summary_path = results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61cs_decision_path = results / "v61cs_complete_source_generation_execution_admission_gate_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"

v61cs = read_csv(v61cs_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]
if v61cs.get("v61cs_complete_source_generation_execution_admission_gate_ready") != "1":
    raise SystemExit("v61ct requires v61cs_complete_source_generation_execution_admission_gate_ready=1")
if v61bt.get("v61bt_ubuntu1_actual_generation_result_intake_ready") != "1":
    raise SystemExit("v61ct requires v61bt_ubuntu1_actual_generation_result_intake_ready=1")

for src, rel in [
    (v61cs_summary_path, "source_v61cs/v61cs_complete_source_generation_execution_admission_gate_summary.csv"),
    (v61cs_decision_path, "source_v61cs/v61cs_complete_source_generation_execution_admission_gate_decision.csv"),
    (v61cs_dir / "complete_source_generation_execution_admission_rows.csv", "source_v61cs/complete_source_generation_execution_admission_rows.csv"),
    (v61cs_dir / "complete_source_generation_execution_admission_requirement_rows.csv", "source_v61cs/complete_source_generation_execution_admission_requirement_rows.csv"),
    (v61cs_dir / "complete_source_generation_execution_admission_metric_rows.csv", "source_v61cs/complete_source_generation_execution_admission_metric_rows.csv"),
    (v61cs_dir / "runtime_gap_rows.csv", "source_v61cs/runtime_gap_rows.csv"),
    (v61cs_dir / "sha256_manifest.csv", "source_v61cs/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_result_status_rows.csv", "source_v61bt/actual_generation_result_status_rows.csv"),
    (v61bt_dir / "actual_generation_result_template_rows.csv", "source_v61bt/actual_generation_result_template_rows.csv"),
    (v61bt_dir / "actual_generation_result_required_field_rows.csv", "source_v61bt/actual_generation_result_required_field_rows.csv"),
    (v61bt_dir / "actual_generation_result_metric_rows.csv", "source_v61bt/actual_generation_result_metric_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
]:
    copy(src, rel)

admission_rows = read_csv(v61cs_dir / "complete_source_generation_execution_admission_rows.csv")
result_status_rows = read_csv(v61bt_dir / "actual_generation_result_status_rows.csv")
result_template_rows = read_csv(v61bt_dir / "actual_generation_result_template_rows.csv")
if len(admission_rows) != 1000:
    raise SystemExit("v61ct expects 1000 v61cs admission rows")
if len(result_status_rows) != 5 or len(result_template_rows) != 5:
    raise SystemExit("v61ct expects five v61bt result artifacts/templates")

admission_rows_count = int(v61cs["generation_execution_admission_rows"])
admitted_rows = int(v61cs["generation_execution_admitted_rows"])
blocked_rows = int(v61cs["generation_execution_blocked_rows"])
operator_handoff_ready = int(v61cs["generation_operator_bundle_handoff_ready"])
execution_packet_ready = int(v61cs["generation_execution_packet_ready"])
admission_ready = int(v61cs["generation_execution_admission_ready"])
accepted_generation_result_artifacts = int(v61bt["accepted_generation_result_artifacts"])
expected_generation_result_artifacts = int(v61bt["expected_generation_result_artifacts"])
generation_result_artifacts_ready = int(v61cs["generation_result_artifacts_ready"])
guarded_generation_command_ready = int(admission_ready and admitted_rows == admission_rows_count)
generation_operator_execution_ready = int(guarded_generation_command_ready and operator_handoff_ready and execution_packet_ready)
actual_model_generation_ready = int(generation_operator_execution_ready and generation_result_artifacts_ready)

operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)

(operator_dir / "README.md").write_text(
    "# v61ct Complete-Source Generation Execution Operator Bundle\n\n"
    "This bundle is bound to the v61cs final admission surface. It is safe to "
    "verify now, but the generation command remains blocked until v61cs reports "
    "1000/1000 admitted generation execution rows. Do not copy checkpoint payload "
    "bytes into this repository.\n\n"
    "Current default state: generation execution admission is blocked, and actual "
    "Mixtral generation is not claimed.\n",
    encoding="utf-8",
)

(operator_dir / "GENERATION_EXECUTION_ENV.template").write_text(
    "V61CS_ADMISSION_ROWS=results/v61cs_complete_source_generation_execution_admission_gate/gate_001/complete_source_generation_execution_admission_rows.csv\n"
    "V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return\n"
    "CHECKPOINT_ROOT=/path/to/external/checkpoint/root\n"
    "DRY_RUN=1\n",
    encoding="utf-8",
)

return_template_rows = []
template_by_artifact = {row["result_artifact"]: row["example_payload"] for row in result_template_rows}
for row in result_status_rows:
    return_template_rows.append(
        {
            "result_artifact": row["result_artifact"],
            "required": "1",
            "current_status": row["result_status"],
            "result_accepted": row["result_accepted"],
            "example_payload": template_by_artifact.get(row["result_artifact"], ""),
            "artifact_sha256": "",
            "operator_note": "return after guarded real-model generation execution",
        }
    )
write_csv(operator_dir / "GENERATION_RESULT_RETURN_TEMPLATE.csv", list(return_template_rows[0].keys()), return_template_rows)

verify_script = operator_dir / "VERIFY_GENERATION_EXECUTION_BUNDLE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMISSION_ROWS="$BUNDLE_DIR/source_v61cs/complete_source_generation_execution_admission_rows.csv"
RESULT_TEMPLATE="$BUNDLE_DIR/operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv"
ENV_TEMPLATE="$BUNDLE_DIR/operator_bundle/GENERATION_EXECUTION_ENV.template"

for path in "$ADMISSION_ROWS" "$RESULT_TEMPLATE" "$ENV_TEMPLATE"; do
  if [[ ! -s "$path" ]]; then
    echo "missing required v61ct operator bundle file: $path" >&2
    exit 1
  fi
done

admission_line_count="$(wc -l < "$ADMISSION_ROWS" | tr -d ' ')"
result_template_line_count="$(wc -l < "$RESULT_TEMPLATE" | tr -d ' ')"

[[ "$admission_line_count" == "1001" ]] || { echo "expected 1000 admission rows" >&2; exit 1; }
[[ "$result_template_line_count" == "6" ]] || { echo "expected 5 generation result template rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "checkpoint payload-like file found inside v61ct bundle" >&2
  exit 1
fi

echo "v61ct generation execution operator bundle shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

run_guard = operator_dir / "RUN_GENERATION_GUARD.sh"
run_guard.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY="$BUNDLE_DIR/source_v61cs/v61cs_complete_source_generation_execution_admission_gate_summary.csv"

python3 - "$SUMMARY" <<'INNER_PY'
import csv
import sys

with open(sys.argv[1], newline='', encoding='utf-8') as handle:
    row = next(csv.DictReader(handle))

admitted = int(row['generation_execution_admitted_rows'])
expected = int(row['generation_execution_admission_rows'])
ready = int(row['generation_execution_admission_ready'])
if ready != 1 or admitted != expected:
    raise SystemExit(f"generation execution remains blocked: admitted={admitted}/{expected}, ready={ready}")
print("generation execution admission ready")
INNER_PY
""",
    encoding="utf-8",
)
run_guard.chmod(0o755)

bundle_file_rows = [
    ("operator_bundle/README.md", "operator instructions", "1"),
    ("operator_bundle/GENERATION_EXECUTION_ENV.template", "operator environment template", "1"),
    ("operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv", "generation result return template", "1"),
    ("operator_bundle/VERIFY_GENERATION_EXECUTION_BUNDLE.sh", "shape verifier", "1"),
    ("operator_bundle/RUN_GENERATION_GUARD.sh", "guarded execution admission checker", "1"),
]
bundle_file_dicts = [
    {
        "bundle_file": rel,
        "purpose": purpose,
        "required": required,
        "file_ready": "1",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
    for rel, purpose, required in bundle_file_rows
]
write_csv(run_dir / "complete_source_generation_execution_operator_bundle_file_rows.csv", list(bundle_file_dicts[0].keys()), bundle_file_dicts)

command_rows = [
    {
        "command_id": "verify-v61ct-bundle",
        "command": "results/v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/VERIFY_GENERATION_EXECUTION_BUNDLE.sh",
        "purpose": "verify operator bundle shape and zero-payload boundary",
        "ready_to_run_now": "1",
    },
    {
        "command_id": "check-generation-admission",
        "command": "results/v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/RUN_GENERATION_GUARD.sh",
        "purpose": "refuse generation until v61cs has 1000 admitted rows",
        "ready_to_run_now": "1",
    },
    {
        "command_id": "run-real-model-generation",
        "command": "DRY_RUN=0 V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return ./operator/run_complete_source_generation.sh",
        "purpose": "external real-model generation execution after admission opens",
        "ready_to_run_now": str(guarded_generation_command_ready),
    },
    {
        "command_id": "intake-generation-result-return",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=/path/to/generation_result_return ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "purpose": "validate returned generation answer/citation/abstain/latency artifacts",
        "ready_to_run_now": "0",
    },
    {
        "command_id": "refresh-final-generation-admission",
        "command": "V61CS_REUSE_EXISTING=0 ./experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh",
        "purpose": "refresh final admission after materialization, review, runtime, and result returns",
        "ready_to_run_now": "1",
    },
]
write_csv(run_dir / "complete_source_generation_execution_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {"requirement_id": "v61cs-generation-execution-admission-input", "status": "pass", "required_value": "1", "actual_value": v61cs["v61cs_complete_source_generation_execution_admission_gate_ready"], "reason": "v61cs final admission surface is bound"},
    {"requirement_id": "v61bt-generation-result-intake-input", "status": "pass", "required_value": "1", "actual_value": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"], "reason": "v61bt result intake schema is bound"},
    {"requirement_id": "operator-bundle-shape", "status": "pass", "required_value": "5", "actual_value": str(len(bundle_file_dicts)), "reason": "operator files are present"},
    {"requirement_id": "generation-execution-admission", "status": status(guarded_generation_command_ready), "required_value": str(admission_rows_count), "actual_value": str(admitted_rows), "reason": "guarded generation can run only after v61cs admits every row"},
    {"requirement_id": "generation-result-return", "status": status(generation_result_artifacts_ready), "required_value": str(expected_generation_result_artifacts), "actual_value": str(accepted_generation_result_artifacts), "reason": "returned generation artifacts must be accepted"},
    {"requirement_id": "actual-model-generation", "status": status(actual_model_generation_ready), "required_value": str(admission_rows_count), "actual_value": "0", "reason": "not a generation run and no accepted artifacts"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61ct writes operator metadata only"},
]
write_csv(run_dir / "complete_source_generation_execution_operator_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ct_complete_source_generation_execution_operator_bundle_metrics",
    "model_id": model_id,
    "v61cs_complete_source_generation_execution_admission_gate_ready": v61cs["v61cs_complete_source_generation_execution_admission_gate_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "generation_execution_admission_rows": str(admission_rows_count),
    "generation_execution_admitted_rows": str(admitted_rows),
    "generation_execution_blocked_rows": str(blocked_rows),
    "generation_execution_admission_ready": str(admission_ready),
    "operator_bundle_file_rows": str(len(bundle_file_dicts)),
    "operator_command_rows": str(len(command_rows)),
    "ready_operator_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "generation_result_return_template_rows": str(len(return_template_rows)),
    "expected_generation_result_artifacts": str(expected_generation_result_artifacts),
    "accepted_generation_result_artifacts": str(accepted_generation_result_artifacts),
    "guarded_generation_command_ready": str(guarded_generation_command_ready),
    "generation_operator_execution_ready": str(generation_operator_execution_ready),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ct": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_generation_execution_operator_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ct_complete_source_generation_execution_operator_bundle_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61cs-generation-execution-admission-input", "status": "ready", "reason": "v61cs final admission surface is bound"},
    {"gap": "operator-bundle-shape", "status": "ready", "reason": "five bundle files are present"},
    {"gap": "generation-execution-admission", "status": "ready" if guarded_generation_command_ready else "blocked", "reason": f"generation_execution_admitted_rows={admitted_rows}/{admission_rows_count}"},
    {"gap": "generation-result-return", "status": "ready" if generation_result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gap": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gap": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61cs-generation-execution-admission-input", "status": "pass", "reason": "v61cs is ready"},
    {"gate": "v61bt-generation-result-intake-input", "status": "pass", "reason": "v61bt schema is ready"},
    {"gate": "operator-bundle-shape", "status": "pass", "reason": "operator files are present"},
    {"gate": "generation-execution-admission", "status": "pass" if guarded_generation_command_ready else "blocked", "reason": f"generation_execution_admitted_rows={admitted_rows}/{admission_rows_count}"},
    {"gate": "generation-result-return", "status": "pass" if generation_result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61ct writes metadata only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ct Complete-Source Generation Execution Operator Bundle Boundary

This artifact packages a dry-run-first operator bundle over the v61cs final
generation execution admission surface. It can verify and refresh the bundle now,
but the guarded real-generation command remains blocked until v61cs admits all
1000 execution rows and v61bt accepts returned result artifacts.

Evidence emitted:

- generation_execution_admission_rows={admission_rows_count}
- generation_execution_admitted_rows={admitted_rows}
- generation_execution_blocked_rows={blocked_rows}
- operator_bundle_file_rows={len(bundle_file_dicts)}
- operator_command_rows={len(command_rows)}
- ready_operator_command_rows={sum(row["ready_to_run_now"] == "1" for row in command_rows)}
- generation_result_return_template_rows={len(return_template_rows)}
- guarded_generation_command_ready={guarded_generation_command_ready}
- generation_operator_execution_ready={generation_operator_execution_ready}
- actual_model_generation_ready={actual_model_generation_ready}
- checkpoint_payload_bytes_downloaded_by_v61ct=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: dry-run-first generation execution operator bundle over v61cs.
Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61CT_COMPLETE_SOURCE_GENERATION_EXECUTION_OPERATOR_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ct_complete_source_generation_execution_operator_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ct_complete_source_generation_execution_operator_bundle_ready": 1,
    "source_v61cs_summary_sha256": sha256(v61cs_summary_path),
    "source_v61bt_summary_sha256": sha256(v61bt_summary_path),
    "generation_execution_admission_rows": admission_rows_count,
    "generation_execution_admitted_rows": admitted_rows,
    "operator_bundle_file_rows": len(bundle_file_dicts),
    "operator_command_rows": len(command_rows),
    "guarded_generation_command_ready": guarded_generation_command_ready,
    "generation_operator_execution_ready": generation_operator_execution_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_downloaded_by_v61ct": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61ct_complete_source_generation_execution_operator_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ct_complete_source_generation_execution_operator_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
