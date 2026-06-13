#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cv_complete_source_runtime_admission_operator_bundle"
RUN_ID="${V61CV_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CV_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cv_complete_source_runtime_admission_operator_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cq_complete_source_runtime_admission_expansion_packet.sh" >/dev/null
V61CR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh" >/dev/null
V61CM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate.sh" >/dev/null
V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
V61CO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61co_real_manifest_runtime_execution_admission_bridge.sh" >/dev/null

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
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)
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


source_specs = {
    "v61cq": (
        results / "v61cq_complete_source_runtime_admission_expansion_packet_summary.csv",
        results / "v61cq_complete_source_runtime_admission_expansion_packet_decision.csv",
        results / "v61cq_complete_source_runtime_admission_expansion_packet" / "packet_001",
        "v61cq_complete_source_runtime_admission_expansion_packet_ready",
    ),
    "v61cr": (
        results / "v61cr_complete_source_runtime_admission_return_intake_summary.csv",
        results / "v61cr_complete_source_runtime_admission_return_intake_decision.csv",
        results / "v61cr_complete_source_runtime_admission_return_intake" / "intake_001",
        "v61cr_complete_source_runtime_admission_return_intake_ready",
    ),
    "v61cm": (
        results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_summary.csv",
        results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_decision.csv",
        results / "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate" / "gate_001",
        "v61cm_ubuntu1_full_checkpoint_materialization_promotion_gate_ready",
    ),
    "v61cb": (
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv",
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv",
        results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate" / "gate_001",
        "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready",
    ),
    "v61co": (
        results / "v61co_real_manifest_runtime_execution_admission_bridge_summary.csv",
        results / "v61co_real_manifest_runtime_execution_admission_bridge_decision.csv",
        results / "v61co_real_manifest_runtime_execution_admission_bridge" / "bridge_001",
        "v61co_real_manifest_runtime_execution_admission_bridge_ready",
    ),
}

summaries = {}
for key, (summary_path, decision_path, source_dir, ready_field) in source_specs.items():
    row = read_csv(summary_path)[0]
    if row.get(ready_field) != "1":
        raise SystemExit(f"v61cv requires {ready_field}=1")
    summaries[key] = row
    copy(summary_path, f"source_{key}/{summary_path.name}")
    copy(decision_path, f"source_{key}/{decision_path.name}")
    copy(source_dir / "sha256_manifest.csv", f"source_{key}/sha256_manifest.csv")

v61cq_dir = source_specs["v61cq"][2]
v61cr_dir = source_specs["v61cr"][2]
copy(v61cq_dir / "complete_source_runtime_admission_expansion_rows.csv", "source_v61cq/complete_source_runtime_admission_expansion_rows.csv")
copy(v61cq_dir / "complete_source_runtime_admission_operator_command_rows.csv", "source_v61cq/complete_source_runtime_admission_operator_command_rows.csv")
copy(v61cq_dir / "complete_source_runtime_admission_return_manifest_rows.csv", "source_v61cq/complete_source_runtime_admission_return_manifest_rows.csv")
copy(v61cr_dir / "complete_source_runtime_admission_return_required_field_rows.csv", "source_v61cr/complete_source_runtime_admission_return_required_field_rows.csv")
copy(v61cr_dir / "complete_source_runtime_admission_return_template_rows.csv", "source_v61cr/complete_source_runtime_admission_return_template_rows.csv")
copy(v61cr_dir / "complete_source_runtime_admission_return_artifact_status_rows.csv", "source_v61cr/complete_source_runtime_admission_return_artifact_status_rows.csv")
copy(v61cr_dir / "complete_source_runtime_admission_return_requirement_rows.csv", "source_v61cr/complete_source_runtime_admission_return_requirement_rows.csv")

v61cq = summaries["v61cq"]
v61cr = summaries["v61cr"]
v61cm = summaries["v61cm"]
v61cb = summaries["v61cb"]
v61co = summaries["v61co"]

expansion_rows = read_csv(v61cq_dir / "complete_source_runtime_admission_expansion_rows.csv")
return_manifest_rows = read_csv(v61cq_dir / "complete_source_runtime_admission_return_manifest_rows.csv")
required_field_rows = read_csv(v61cr_dir / "complete_source_runtime_admission_return_required_field_rows.csv")
if len(expansion_rows) != 1000:
    raise SystemExit("v61cv expects 1000 runtime admission expansion rows")
if len(return_manifest_rows) != 5:
    raise SystemExit("v61cv expects five runtime admission return artifacts")

full_checkpoint_materialization_ready = int(v61cm["full_checkpoint_materialization_ready"] == "1")
full_page_hash_ready = int(v61cb["completed_full_safetensors_page_hash_coverage_ready"] == "1" and v61cb["full_safetensors_page_hash_binding_ready"] == "1")
seed_runtime_ready = int(v61co["real_manifest_runtime_execution_admission_ready"] == "1")
runtime_expansion_packet_ready = int(v61cq["runtime_admission_expansion_packet_ready"] == "1")
runtime_return_schema_ready = int(v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"] == "1")
guarded_runtime_admission_command_ready = int(
    full_checkpoint_materialization_ready
    and full_page_hash_ready
    and seed_runtime_ready
    and runtime_expansion_packet_ready
    and runtime_return_schema_ready
)
runtime_operator_execution_ready = 0
complete_source_runtime_admission_execution_ready = int(v61cr["complete_source_runtime_admission_execution_ready"] == "1")

(operator_dir / "README.md").write_text(
    "# v61cv Complete-Source Runtime Admission Operator Bundle\n\n"
    "This bundle turns the v61cq 1000-row runtime admission expansion packet into "
    "a dry-run-first operator handoff. It can verify prerequisites and package "
    "return templates now, but it does not execute Mixtral inference or fabricate "
    "runtime admission returns.\n",
    encoding="utf-8",
)

(operator_dir / "RUNTIME_ADMISSION_ENV.template").write_text(
    "V61CQ_EXPANSION_ROWS=results/v61cq_complete_source_runtime_admission_expansion_packet/packet_001/complete_source_runtime_admission_expansion_rows.csv\n"
    "V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return\n"
    "CHECKPOINT_ROOT=/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse\n"
    "DRY_RUN=1\n",
    encoding="utf-8",
)

return_template_rows = []
field_counts = {}
for row in required_field_rows:
    field_counts[row["result_artifact"]] = field_counts.get(row["result_artifact"], 0) + 1
for row in return_manifest_rows:
    return_template_rows.append(
        {
            "result_artifact": row["artifact_id"],
            "path": row["path"],
            "required_rows": row["required_rows"],
            "current_status": row["status"],
            "accepted_rows": row["accepted_rows"],
            "required_field_rows": str(field_counts.get(row["path"], 0)),
            "artifact_sha256": "",
            "operator_note": "return after complete-source runtime admission execution",
        }
    )
write_csv(operator_dir / "RUNTIME_ADMISSION_RETURN_TEMPLATE.csv", list(return_template_rows[0].keys()), return_template_rows)

verify_script = operator_dir / "VERIFY_RUNTIME_ADMISSION_BUNDLE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPANSION_ROWS="$BUNDLE_DIR/source_v61cq/complete_source_runtime_admission_expansion_rows.csv"
RETURN_TEMPLATE="$BUNDLE_DIR/operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv"
ENV_TEMPLATE="$BUNDLE_DIR/operator_bundle/RUNTIME_ADMISSION_ENV.template"

for path in "$EXPANSION_ROWS" "$RETURN_TEMPLATE" "$ENV_TEMPLATE"; do
  if [[ ! -s "$path" ]]; then
    echo "missing required v61cv operator bundle file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$EXPANSION_ROWS" | tr -d ' ')" == "1001" ]] || { echo "expected 1000 runtime expansion rows" >&2; exit 1; }
[[ "$(wc -l < "$RETURN_TEMPLATE" | tr -d ' ')" == "6" ]] || { echo "expected five runtime admission return template rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "checkpoint payload-like file found inside v61cv bundle" >&2
  exit 1
fi

echo "v61cv runtime admission operator bundle shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

guard_script = operator_dir / "RUN_RUNTIME_ADMISSION_GUARD.sh"
guard_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY="$BUNDLE_DIR/v61cv_complete_source_runtime_admission_operator_bundle_manifest.json"

python3 - "$SUMMARY" <<'INNER_PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding='utf-8'))
if manifest.get('guarded_runtime_admission_command_ready') != 1:
    raise SystemExit('runtime admission guard prerequisites are not ready')
print('runtime admission guard prerequisites ready; keep DRY_RUN=1 unless executing externally')
INNER_PY
""",
    encoding="utf-8",
)
guard_script.chmod(0o755)

file_rows = [
    {"bundle_file": "operator_bundle/README.md", "purpose": "operator overview", "file_ready": "1"},
    {"bundle_file": "operator_bundle/RUNTIME_ADMISSION_ENV.template", "purpose": "runtime admission environment template", "file_ready": "1"},
    {"bundle_file": "operator_bundle/RUNTIME_ADMISSION_RETURN_TEMPLATE.csv", "purpose": "five-artifact return template", "file_ready": "1"},
    {"bundle_file": "operator_bundle/VERIFY_RUNTIME_ADMISSION_BUNDLE.sh", "purpose": "shape verifier", "file_ready": "1"},
    {"bundle_file": "operator_bundle/RUN_RUNTIME_ADMISSION_GUARD.sh", "purpose": "prerequisite guard", "file_ready": "1"},
]
write_csv(run_dir / "complete_source_runtime_admission_operator_bundle_file_rows.csv", list(file_rows[0].keys()), file_rows)

command_rows = [
    {"command_id": "verify-v61cv-bundle", "command": "results/v61cv_complete_source_runtime_admission_operator_bundle/bundle_001/operator_bundle/VERIFY_RUNTIME_ADMISSION_BUNDLE.sh", "purpose": "verify runtime admission bundle shape", "ready_to_run_now": "1"},
    {"command_id": "check-runtime-admission-prerequisites", "command": "results/v61cv_complete_source_runtime_admission_operator_bundle/bundle_001/operator_bundle/RUN_RUNTIME_ADMISSION_GUARD.sh", "purpose": "verify full checkpoint/page-hash/runtime seed prerequisites", "ready_to_run_now": str(guarded_runtime_admission_command_ready)},
    {"command_id": "run-complete-source-runtime-admission", "command": "DRY_RUN=0 V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return ./operator/run_complete_source_runtime_admission.sh", "purpose": "external runtime admission execution over 1000 expansion rows", "ready_to_run_now": "0"},
    {"command_id": "intake-runtime-admission-return", "command": "V61CR_REUSE_EXISTING=0 V61CR_RUNTIME_ADMISSION_RETURN_DIR=/path/to/runtime_admission_return ./experiments/run_v61cr_complete_source_runtime_admission_return_intake.sh", "purpose": "validate returned runtime admission artifacts", "ready_to_run_now": "0"},
    {"command_id": "refresh-final-generation-admission", "command": "V61CS_REUSE_EXISTING=0 ./experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh", "purpose": "refresh generation admission after runtime return intake", "ready_to_run_now": "1"},
]
write_csv(run_dir / "complete_source_runtime_admission_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {"requirement_id": "v61cq-runtime-admission-expansion-input", "status": "pass", "required_value": "1", "actual_value": v61cq["v61cq_complete_source_runtime_admission_expansion_packet_ready"], "reason": "runtime expansion packet is bound"},
    {"requirement_id": "v61cr-runtime-admission-return-schema-input", "status": "pass", "required_value": "1", "actual_value": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"], "reason": "return intake schema is bound"},
    {"requirement_id": "full-checkpoint-materialization", "status": status(full_checkpoint_materialization_ready), "required_value": "1", "actual_value": str(full_checkpoint_materialization_ready), "reason": "all checkpoint shards are identity verified"},
    {"requirement_id": "full-page-hash-coverage", "status": status(full_page_hash_ready), "required_value": "1", "actual_value": str(full_page_hash_ready), "reason": "all checkpoint pages are hash verified"},
    {"requirement_id": "source-bound-runtime-seed-admission", "status": status(seed_runtime_ready), "required_value": "1", "actual_value": str(seed_runtime_ready), "reason": "37/37 seed runtime rows are admitted"},
    {"requirement_id": "operator-bundle-shape", "status": "pass", "required_value": "5", "actual_value": str(len(file_rows)), "reason": "operator files are present"},
    {"requirement_id": "guarded-runtime-admission-command", "status": status(guarded_runtime_admission_command_ready), "required_value": "1", "actual_value": str(guarded_runtime_admission_command_ready), "reason": "operator guard prerequisites are ready"},
    {"requirement_id": "runtime-admission-return", "status": "blocked", "required_value": v61cr["expected_runtime_admission_result_rows"], "actual_value": v61cr["accepted_runtime_admission_result_rows"], "reason": "real runtime admission return artifacts are still absent"},
    {"requirement_id": "complete-source-runtime-admission-execution", "status": status(complete_source_runtime_admission_execution_ready), "required_value": v61cr["expected_runtime_admission_result_rows"], "actual_value": v61cr["accepted_runtime_admission_result_rows"], "reason": "execution remains blocked until returned rows validate"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61cv writes operator metadata only"},
]
write_csv(run_dir / "complete_source_runtime_admission_operator_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cv_complete_source_runtime_admission_operator_bundle_metrics",
    "model_id": model_id,
    "v61cq_complete_source_runtime_admission_expansion_packet_ready": v61cq["v61cq_complete_source_runtime_admission_expansion_packet_ready"],
    "v61cr_complete_source_runtime_admission_return_intake_ready": v61cr["v61cr_complete_source_runtime_admission_return_intake_ready"],
    "full_checkpoint_materialization_ready": str(full_checkpoint_materialization_ready),
    "completed_full_safetensors_page_hash_coverage_ready": str(full_page_hash_ready),
    "real_manifest_runtime_execution_admission_ready": str(seed_runtime_ready),
    "runtime_admission_expansion_packet_rows": v61cq["runtime_admission_expansion_packet_rows"],
    "runtime_admission_expansion_required_rows": v61cq["runtime_admission_expansion_required_rows"],
    "runtime_admission_return_artifact_rows": str(len(return_manifest_rows)),
    "expected_runtime_admission_result_rows": v61cr["expected_runtime_admission_result_rows"],
    "accepted_runtime_admission_result_rows": v61cr["accepted_runtime_admission_result_rows"],
    "operator_bundle_file_rows": str(len(file_rows)),
    "operator_command_rows": str(len(command_rows)),
    "ready_operator_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "runtime_admission_return_template_rows": str(len(return_template_rows)),
    "guarded_runtime_admission_command_ready": str(guarded_runtime_admission_command_ready),
    "runtime_operator_execution_ready": str(runtime_operator_execution_ready),
    "complete_source_runtime_admission_execution_ready": str(complete_source_runtime_admission_execution_ready),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cv": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_runtime_admission_operator_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "runtime-admission-expansion-input", "status": "ready", "reason": "v61cq expansion packet is bound"},
    {"gap": "runtime-admission-return-schema", "status": "ready", "reason": "v61cr return schema is bound"},
    {"gap": "operator-bundle-shape", "status": "ready", "reason": "five bundle files are present"},
    {"gap": "guarded-runtime-admission-command", "status": "ready" if guarded_runtime_admission_command_ready else "blocked", "reason": f"guarded_runtime_admission_command_ready={guarded_runtime_admission_command_ready}"},
    {"gap": "runtime-admission-return", "status": "blocked", "reason": f"accepted_runtime_admission_result_rows={v61cr['accepted_runtime_admission_result_rows']}/{v61cr['expected_runtime_admission_result_rows']}"},
    {"gap": "complete-source-runtime-admission-execution", "status": "blocked", "reason": "real runtime admission return artifacts are absent"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gap": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gap": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "runtime-admission-expansion-input", "status": "pass", "reason": "v61cq is ready"},
    {"gate": "runtime-admission-return-schema", "status": "pass", "reason": "v61cr schema is ready"},
    {"gate": "operator-bundle-shape", "status": "pass", "reason": "operator files are present"},
    {"gate": "guarded-runtime-admission-command", "status": "pass" if guarded_runtime_admission_command_ready else "blocked", "reason": f"guarded_runtime_admission_command_ready={guarded_runtime_admission_command_ready}"},
    {"gate": "runtime-admission-return", "status": "blocked", "reason": f"accepted_runtime_admission_result_rows={v61cr['accepted_runtime_admission_result_rows']}/{v61cr['expected_runtime_admission_result_rows']}"},
    {"gate": "complete-source-runtime-admission-execution", "status": "blocked", "reason": "returned runtime admission artifacts are absent"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation run"},
    {"gate": "production-latency", "status": "blocked", "reason": "not latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cv writes metadata only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cv Complete-Source Runtime Admission Operator Bundle Boundary

This artifact packages a dry-run-first runtime admission operator bundle over
the v61cq 1000-row expansion packet. It verifies that full checkpoint
materialization, full page-hash coverage, and seed runtime admission are ready,
but it does not claim complete-source runtime admission execution until v61cr
accepts returned runtime rows.

Evidence emitted:

- runtime_admission_expansion_packet_rows={v61cq['runtime_admission_expansion_packet_rows']}
- runtime_admission_expansion_required_rows={v61cq['runtime_admission_expansion_required_rows']}
- runtime_admission_return_artifact_rows={len(return_manifest_rows)}
- expected_runtime_admission_result_rows={v61cr['expected_runtime_admission_result_rows']}
- accepted_runtime_admission_result_rows={v61cr['accepted_runtime_admission_result_rows']}
- operator_bundle_file_rows={len(file_rows)}
- operator_command_rows={len(command_rows)}
- ready_operator_command_rows={sum(row['ready_to_run_now'] == '1' for row in command_rows)}
- runtime_admission_return_template_rows={len(return_template_rows)}
- full_checkpoint_materialization_ready={full_checkpoint_materialization_ready}
- completed_full_safetensors_page_hash_coverage_ready={full_page_hash_ready}
- real_manifest_runtime_execution_admission_ready={seed_runtime_ready}
- guarded_runtime_admission_command_ready={guarded_runtime_admission_command_ready}
- runtime_operator_execution_ready={runtime_operator_execution_ready}
- complete_source_runtime_admission_execution_ready={complete_source_runtime_admission_execution_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cv=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: dry-run-first complete-source runtime admission operator bundle.
Blocked wording: accepted runtime admission return, actual Mixtral generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61CV_COMPLETE_SOURCE_RUNTIME_ADMISSION_OPERATOR_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cv_complete_source_runtime_admission_operator_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cv_complete_source_runtime_admission_operator_bundle_ready": 1,
    "source_v61cq_summary_sha256": sha256(source_specs["v61cq"][0]),
    "source_v61cr_summary_sha256": sha256(source_specs["v61cr"][0]),
    "source_v61cm_summary_sha256": sha256(source_specs["v61cm"][0]),
    "source_v61cb_summary_sha256": sha256(source_specs["v61cb"][0]),
    "source_v61co_summary_sha256": sha256(source_specs["v61co"][0]),
    "runtime_admission_expansion_packet_rows": int(v61cq["runtime_admission_expansion_packet_rows"]),
    "runtime_admission_return_artifact_rows": len(return_manifest_rows),
    "guarded_runtime_admission_command_ready": guarded_runtime_admission_command_ready,
    "complete_source_runtime_admission_execution_ready": complete_source_runtime_admission_execution_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cv_complete_source_runtime_admission_operator_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cv_complete_source_runtime_admission_operator_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
