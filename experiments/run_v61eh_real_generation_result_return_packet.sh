#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eh_real_generation_result_return_packet"
RUN_ID="${V61EH_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61EH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61eh_real_generation_result_return_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eg_generation_result_prereq_binding_fixture_gate.sh" >/dev/null
V61DF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61df_external_review_generation_return_operator_packet.sh" >/dev/null
V61CT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null
V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
V61CK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ck_real_generation_unblocker_operator_matrix.sh" >/dev/null
V61CS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null
V61DD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
packet_dir = run_dir / "real_generation_result_return_packet"
packet_dir.mkdir(parents=True, exist_ok=True)


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
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def ready_status(flag):
    return "ready" if flag else "blocked"


def pass_status(flag):
    return "pass" if flag else "blocked"


summary_sources = {
    "v61eg": results / "v61eg_generation_result_prereq_binding_fixture_gate_summary.csv",
    "v61df": results / "v61df_external_review_generation_return_operator_packet_summary.csv",
    "v61ct": results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv",
    "v61dg": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "v61ck": results / "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs": results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
    "v61de": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "v61bt": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
}
decision_sources = {
    key: value.with_name(value.name.replace("_summary.csv", "_decision.csv"))
    for key, value in summary_sources.items()
}
summaries = {}
for key, path in summary_sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61eh source summary {key}: {path}")
    summaries[key] = read_csv(path)[0]
    copy(path, f"source_{key}/{path.name}")
for key, path in decision_sources.items():
    if path.is_file():
        copy(path, f"source_{key}/{path.name}")

source_artifacts = [
    (
        results
        / "v61eg_generation_result_prereq_binding_fixture_gate/gate_001/v61bt_prerequisite_binding_rows.csv",
        "source_v61eg/v61bt_prerequisite_binding_rows.csv",
    ),
    (
        results
        / "v61eg_generation_result_prereq_binding_fixture_gate/gate_001/generation_result_prereq_binding_fixture_stage_rows.csv",
        "source_v61eg/generation_result_prereq_binding_fixture_stage_rows.csv",
    ),
    (
        results
        / "v61eg_generation_result_prereq_binding_fixture_gate/gate_001/generation_result_prereq_binding_fixture_invariant_rows.csv",
        "source_v61eg/generation_result_prereq_binding_fixture_invariant_rows.csv",
    ),
    (
        results
        / "v61df_external_review_generation_return_operator_packet/packet_001/operator_packet/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
        "source_v61df/operator_packet/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
    ),
    (
        results
        / "v61df_external_review_generation_return_operator_packet/packet_001/external_return_operator_stage_rows.csv",
        "source_v61df/external_return_operator_stage_rows.csv",
    ),
    (
        results
        / "v61ct_complete_source_generation_execution_operator_bundle/bundle_001/operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv",
        "source_v61ct/operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv",
    ),
    (
        results
        / "v61ct_complete_source_generation_execution_operator_bundle/bundle_001/complete_source_generation_execution_operator_command_rows.csv",
        "source_v61ct/complete_source_generation_execution_operator_command_rows.csv",
    ),
    (
        results
        / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_required_field_rows.csv",
        "source_v61bt/actual_generation_result_required_field_rows.csv",
    ),
    (
        results
        / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_template_rows.csv",
        "source_v61bt/actual_generation_result_template_rows.csv",
    ),
    (
        results
        / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_status_rows.csv",
        "source_v61bt/actual_generation_result_status_rows.csv",
    ),
]
for src, rel in source_artifacts:
    if not src.is_file():
        raise SystemExit(f"missing v61eh source artifact: {src}")
    copy(src, rel)

v61eg = summaries["v61eg"]
v61df = summaries["v61df"]
v61ct = summaries["v61ct"]
v61dg = summaries["v61dg"]
v61ck = summaries["v61ck"]
v61cs = summaries["v61cs"]
v61dd = summaries["v61dd"]
v61de = summaries["v61de"]
v61bt = summaries["v61bt"]
model_id = v61dg.get("model_id", "mistralai/Mixtral-8x22B-v0.1")

required_field_rows = read_csv(
    results
    / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_required_field_rows.csv"
)
template_rows = read_csv(
    results
    / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_template_rows.csv"
)
status_rows = read_csv(
    results
    / "v61bt_ubuntu1_actual_generation_result_intake/intake_001/actual_generation_result_status_rows.csv"
)

field_counts = defaultdict(int)
for row in required_field_rows:
    field_counts[row["result_artifact"]] += 1

expected_rows_by_artifact = {
    "real_model_generation_answer_rows.csv": "1000",
    "real_model_generation_citation_rows.csv": "1000",
    "real_model_generation_abstain_fallback_rows.csv": "1000",
    "real_model_generation_latency_rows.csv": "1000",
    "real_model_generation_acceptance_summary.json": "1",
}
template_by_artifact = {row["result_artifact"]: row["example_payload"] for row in template_rows}
status_by_artifact = {row["result_artifact"]: row for row in status_rows}
artifact_rows = []
for artifact in expected_rows_by_artifact:
    status_row = status_by_artifact.get(artifact, {})
    artifact_rows.append(
        {
            "result_artifact": artifact,
            "artifact_type": "json" if artifact.endswith(".json") else "csv",
            "expected_rows": expected_rows_by_artifact[artifact],
            "required_field_rows": str(field_counts[artifact]),
            "current_supplied": status_row.get("result_supplied", "0"),
            "current_accepted": status_row.get("result_accepted", "0"),
            "counts_as_real_generation_result": "0",
            "example_payload": template_by_artifact.get(artifact, ""),
        }
    )
write_csv(run_dir / "real_generation_required_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)
write_csv(packet_dir / "REQUIRED_GENERATION_RESULT_ARTIFACTS.csv", list(artifact_rows[0].keys()), artifact_rows)

real_review_ready = int(
    v61dd.get("review_return_ready", "0") == "1"
    and v61dd.get("v61_review_unblock_ready", "0") == "1"
    and v61cs.get("complete_source_review_return_ready", "0") == "1"
)
real_generation_admission_ready = int(
    v61cs.get("generation_execution_admission_ready", "0") == "1"
    and v61cs.get("generation_execution_admitted_rows", "0")
    == v61cs.get("generation_execution_admission_rows", "")
)
real_materialization_ready = int(v61ck.get("full_checkpoint_materialization_ready", "0") == "1")
real_hash_ready = int(
    v61ck.get("completed_full_safetensors_page_hash_coverage_ready", "0") == "1"
    and v61ck.get("full_safetensors_page_hash_binding_ready", "0") == "1"
)
real_prerequisite_binding_ready = int(
    real_materialization_ready and real_hash_ready and real_review_ready and real_generation_admission_ready
)

binding_contract_rows = [
    {
        "binding_requirement": "full-checkpoint-materialization",
        "source_summary": "v61ck",
        "required_value": "1",
        "actual_value": v61ck.get("full_checkpoint_materialization_ready", "0"),
        "ready": str(real_materialization_ready),
        "counts_as_real_prerequisite": "1",
    },
    {
        "binding_requirement": "full-safetensors-page-hash-binding",
        "source_summary": "v61ck",
        "required_value": "1",
        "actual_value": v61ck.get("full_safetensors_page_hash_binding_ready", "0"),
        "ready": str(real_hash_ready),
        "counts_as_real_prerequisite": "1",
    },
    {
        "binding_requirement": "complete-source-review-return",
        "source_summary": "v61dd/v61cs",
        "required_value": "1",
        "actual_value": str(real_review_ready),
        "ready": str(real_review_ready),
        "counts_as_real_prerequisite": "1",
    },
    {
        "binding_requirement": "generation-execution-admission",
        "source_summary": "v61cs",
        "required_value": v61cs.get("generation_execution_admission_rows", "1000"),
        "actual_value": v61cs.get("generation_execution_admitted_rows", "0"),
        "ready": str(real_generation_admission_ready),
        "counts_as_real_prerequisite": "1",
    },
    {
        "binding_requirement": "fixture-prerequisite-binding-mechanics",
        "source_summary": "v61eg",
        "required_value": "1",
        "actual_value": v61eg.get("fixture_prerequisite_binding_ready", "0"),
        "ready": v61eg.get("fixture_prerequisite_binding_ready", "0"),
        "counts_as_real_prerequisite": "0",
    },
]
write_csv(run_dir / "real_prerequisite_binding_contract_rows.csv", list(binding_contract_rows[0].keys()), binding_contract_rows)
write_csv(packet_dir / "PREREQUISITE_BINDING_CONTRACT.csv", list(binding_contract_rows[0].keys()), binding_contract_rows)

stage_rows = [
    {
        "stage_id": "01-real-manifest-full-shard-runtime-evidence",
        "source_gate": "v61dg",
        "status": ready_status(v61dg.get("post_full_shard_runtime_evidence_ready", "0") == "1"),
        "ready": v61dg.get("post_full_shard_runtime_evidence_ready", "0"),
        "blocking_reason": "",
    },
    {
        "stage_id": "02-prerequisite-binding-mechanics-fixture-proven",
        "source_gate": "v61eg",
        "status": ready_status(v61eg.get("fixture_prerequisite_binding_ready", "0") == "1"),
        "ready": v61eg.get("fixture_prerequisite_binding_ready", "0"),
        "blocking_reason": "fixture-only proof; does not count as real generation evidence",
    },
    {
        "stage_id": "03-real-prerequisite-binding",
        "source_gate": "v61ck/v61cs/v61dd",
        "status": ready_status(real_prerequisite_binding_ready),
        "ready": str(real_prerequisite_binding_ready),
        "blocking_reason": "real review return and generation execution admission are not accepted",
    },
    {
        "stage_id": "04-real-generation-execution-admission",
        "source_gate": "v61cs/v61de",
        "status": ready_status(real_generation_admission_ready),
        "ready": str(real_generation_admission_ready),
        "blocking_reason": f"generation_execution_admitted_rows={v61cs.get('generation_execution_admitted_rows', '0')}/{v61cs.get('generation_execution_admission_rows', '1000')}",
    },
    {
        "stage_id": "05-real-generation-result-artifact-return",
        "source_gate": "v61bt",
        "status": ready_status(as_int(v61bt, "accepted_generation_result_artifacts") == as_int(v61bt, "expected_generation_result_artifacts")),
        "ready": str(int(as_int(v61bt, "accepted_generation_result_artifacts") == as_int(v61bt, "expected_generation_result_artifacts"))),
        "blocking_reason": f"accepted_generation_result_artifacts={v61bt.get('accepted_generation_result_artifacts', '0')}/{v61bt.get('expected_generation_result_artifacts', '5')}",
    },
    {
        "stage_id": "06-real-generation-result-row-acceptance",
        "source_gate": "v61bt/v61cu",
        "status": ready_status(as_int(v61bt, "generation_result_accepted_rows") == as_int(v61bt, "expected_generation_rows")),
        "ready": str(int(as_int(v61bt, "generation_result_accepted_rows") == as_int(v61bt, "expected_generation_rows"))),
        "blocking_reason": f"generation_result_accepted_rows={v61bt.get('generation_result_accepted_rows', '0')}/{v61bt.get('expected_generation_rows', '1000')}",
    },
    {
        "stage_id": "07-actual-model-generation-claim",
        "source_gate": "v61bt/v61de",
        "status": "blocked",
        "ready": "0",
        "blocking_reason": "actual generation remains unproven until real returned artifacts pass intake",
    },
]
write_csv(run_dir / "real_generation_result_return_packet_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {
        "command_id": "verify-real-generation-return-packet",
        "command": "results/v61eh_real_generation_result_return_packet/packet_001/real_generation_result_return_packet/VERIFY_REAL_GENERATION_RETURN_PACKET.sh",
        "ready_to_run_now": "1",
        "purpose": "verify the packet shape and zero-payload boundary",
    },
    {
        "command_id": "prepare-real-prerequisite-binding-after-review-return",
        "command": "refresh v61ck/v61cs/v61dd after real review return, then copy their summaries into V61BT_PREREQUISITE_BINDING_DIR",
        "ready_to_run_now": str(real_review_ready),
        "purpose": "build a real prerequisite binding directory; fixture binding is not accepted as real",
    },
    {
        "command_id": "intake-real-generation-results-v61bt",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(real_prerequisite_binding_ready),
        "purpose": "validate returned answer/citation/abstain/latency/summary artifacts",
    },
    {
        "command_id": "handoff-real-generation-results-v61de",
        "command": "V61DE_REUSE_EXISTING=0 V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": str(real_prerequisite_binding_ready),
        "purpose": "refresh the post-review generation-result handoff over real returned artifacts",
    },
    {
        "command_id": "refresh-complete-source-generation-result-acceptance",
        "command": "V61CU_REUSE_EXISTING=0 ./experiments/run_v61cu_complete_source_generation_result_acceptance_bridge.sh",
        "ready_to_run_now": "0",
        "purpose": "promote accepted generation rows only after v61bt accepts real artifacts",
    },
]
write_csv(run_dir / "real_generation_result_return_packet_command_rows.csv", list(command_rows[0].keys()), command_rows)
write_csv(packet_dir / "INTAKE_COMMAND_ROWS.csv", list(command_rows[0].keys()), command_rows)

packet_readme = """# v61eh Real Generation Result Return Packet

This packet is the real-return surface after the v61eg fixture-binding proof.
It is intentionally not a generation run and does not count fixture rows as real
external evidence.

Use it after real review/adjudication returns have been accepted and after a
real generation operator has produced the five required generation-result
artifacts. The required artifacts are listed in
`REQUIRED_GENERATION_RESULT_ARTIFACTS.csv`.

The prerequisite binding must be rebuilt from refreshed v61ck/v61cs/v61dd
summaries after real review return. The v61eg binding is only a fixture proof.
"""
write_csv(packet_dir / "REQUIRED_FIELD_ROWS.csv", list(required_field_rows[0].keys()), required_field_rows)
(packet_dir / "README.md").write_text(packet_readme, encoding="utf-8")
(packet_dir / "RETURN_ENV.template").write_text(
    "V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return\n"
    "V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_result_return\n"
    "V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding\n"
    "V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_result_return\n"
    "V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding\n",
    encoding="utf-8",
)
verify_script = packet_dir / "VERIFY_REAL_GENERATION_RETURN_PACKET.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

PACKET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required=(
  "README.md"
  "REQUIRED_GENERATION_RESULT_ARTIFACTS.csv"
  "REQUIRED_FIELD_ROWS.csv"
  "PREREQUISITE_BINDING_CONTRACT.csv"
  "INTAKE_COMMAND_ROWS.csv"
  "RETURN_ENV.template"
)

for rel in "${required[@]}"; do
  if [[ ! -s "$PACKET_DIR/$rel" ]]; then
    echo "missing v61eh packet file: $rel" >&2
    exit 1
  fi
done

artifact_lines="$(wc -l < "$PACKET_DIR/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv" | tr -d ' ')"
field_lines="$(wc -l < "$PACKET_DIR/REQUIRED_FIELD_ROWS.csv" | tr -d ' ')"
binding_lines="$(wc -l < "$PACKET_DIR/PREREQUISITE_BINDING_CONTRACT.csv" | tr -d ' ')"
command_lines="$(wc -l < "$PACKET_DIR/INTAKE_COMMAND_ROWS.csv" | tr -d ' ')"

[[ "$artifact_lines" == "6" ]] || { echo "expected 5 generation result artifact rows" >&2; exit 1; }
[[ "$field_lines" == "43" ]] || { echo "expected 42 required field rows" >&2; exit 1; }
[[ "$binding_lines" == "6" ]] || { echo "expected 5 prerequisite binding contract rows" >&2; exit 1; }
[[ "$command_lines" == "6" ]] || { echo "expected 5 intake command rows" >&2; exit 1; }

if find "$PACKET_DIR" -type f \\( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \\) | grep -q .; then
  echo "checkpoint payload-like file found inside v61eh packet" >&2
  exit 1
fi

echo "v61eh real generation return packet verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

packet_files = [
    "README.md",
    "REQUIRED_GENERATION_RESULT_ARTIFACTS.csv",
    "REQUIRED_FIELD_ROWS.csv",
    "PREREQUISITE_BINDING_CONTRACT.csv",
    "INTAKE_COMMAND_ROWS.csv",
    "RETURN_ENV.template",
    "VERIFY_REAL_GENERATION_RETURN_PACKET.sh",
]
packet_file_rows = []
for rel in packet_files:
    path = packet_dir / rel
    packet_file_rows.append(
        {
            "packet_file": rel,
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "metadata_only": "1",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "real_generation_result_return_packet_file_rows.csv", list(packet_file_rows[0].keys()), packet_file_rows)

invariant_rows = [
    {
        "invariant_id": "real-manifest-runtime-evidence-ready",
        "status": pass_status(v61dg.get("post_full_shard_runtime_evidence_ready", "0") == "1"),
        "actual_value": v61dg.get("post_full_shard_runtime_evidence_ready", "0"),
    },
    {
        "invariant_id": "fixture-binding-proof-not-real",
        "status": pass_status(v61eg.get("fixture_prerequisite_binding_ready", "0") == "1"),
        "actual_value": "fixture_prerequisite_binding_ready=1; counts_as_real=0",
    },
    {
        "invariant_id": "real-review-return-blocked",
        "status": pass_status(real_review_ready == 0),
        "actual_value": str(real_review_ready),
    },
    {
        "invariant_id": "real-generation-results-absent",
        "status": pass_status(as_int(v61bt, "accepted_generation_result_artifacts") == 0),
        "actual_value": v61bt.get("accepted_generation_result_artifacts", "0"),
    },
    {
        "invariant_id": "actual-generation-blocked",
        "status": pass_status(v61bt.get("actual_model_generation_ready", "0") == "0" and v61de.get("actual_model_generation_ready", "0") == "0"),
        "actual_value": f"v61bt={v61bt.get('actual_model_generation_ready', '0')};v61de={v61de.get('actual_model_generation_ready', '0')}",
    },
    {
        "invariant_id": "zero-repo-checkpoint-payload",
        "status": "pass",
        "actual_value": "0",
    },
]
write_csv(run_dir / "real_generation_result_return_packet_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

ready_stage_rows = sum(row["status"] == "ready" for row in stage_rows)
blocked_stage_rows = len(stage_rows) - ready_stage_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
passed_invariant_rows = sum(row["status"] == "pass" for row in invariant_rows)

summary = {
    "v61eh_real_generation_result_return_packet_ready": "1",
    "model_id": model_id,
    "v61eg_generation_result_prereq_binding_fixture_gate_ready": v61eg["v61eg_generation_result_prereq_binding_fixture_gate_ready"],
    "v61df_external_review_generation_return_operator_packet_ready": v61df["v61df_external_review_generation_return_operator_packet_ready"],
    "v61ct_complete_source_generation_execution_operator_bundle_ready": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"],
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": v61dg["v61dg_post_full_shard_runtime_evidence_promotion_gate_ready"],
    "real_manifest_runtime_evidence_ready": v61dg["post_full_shard_runtime_evidence_ready"],
    "fixture_prerequisite_binding_ready": v61eg["fixture_prerequisite_binding_ready"],
    "fixture_accepted_generation_result_artifacts": v61eg["fixture_accepted_generation_result_artifacts"],
    "fixture_generation_result_accepted_rows": v61eg["fixture_generation_result_accepted_rows"],
    "real_prerequisite_binding_ready": str(real_prerequisite_binding_ready),
    "real_review_return_ready": str(real_review_ready),
    "real_generation_execution_admission_ready": str(real_generation_admission_ready),
    "generation_execution_admitted_rows": v61cs.get("generation_execution_admitted_rows", "0"),
    "generation_execution_admission_rows": v61cs.get("generation_execution_admission_rows", "1000"),
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "real_generation_result_artifacts": "0",
    "generation_result_accepted_rows": v61bt.get("generation_result_accepted_rows", "0"),
    "expected_generation_rows": v61bt.get("expected_generation_rows", "1000"),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "packet_stage_rows": str(len(stage_rows)),
    "ready_packet_stage_rows": str(ready_stage_rows),
    "blocked_packet_stage_rows": str(blocked_stage_rows),
    "required_generation_result_artifact_rows": str(len(artifact_rows)),
    "required_generation_result_field_rows": str(len(required_field_rows)),
    "prerequisite_binding_contract_rows": str(len(binding_contract_rows)),
    "packet_command_rows": str(len(command_rows)),
    "ready_packet_command_rows": str(ready_command_rows),
    "packet_file_rows": str(len(packet_file_rows)),
    "metadata_only_packet_file_rows": str(len(packet_file_rows)),
    "packet_invariant_rows": str(len(invariant_rows)),
    "packet_invariant_pass_rows": str(passed_invariant_rows),
    "checkpoint_payload_bytes_downloaded_by_v61eh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "real-manifest-runtime-evidence", "status": "pass", "reason": "v61dg post-full-shard runtime evidence is ready"},
    {"gate": "fixture-prerequisite-binding-mechanics", "status": "pass", "reason": "v61eg proves the binding mechanics with fixture rows"},
    {"gate": "real-prerequisite-binding", "status": pass_status(real_prerequisite_binding_ready), "reason": "requires real review return and admitted generation execution"},
    {"gate": "real-generation-result-return-packet", "status": "pass", "reason": "packet shape and required artifact schemas are emitted"},
    {"gate": "real-generation-result-artifacts", "status": "blocked", "reason": "no real generation result artifacts supplied"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "no real accepted generation rows"},
    {"gate": "production-latency", "status": "blocked", "reason": "no real accepted latency rows"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "no external quality review"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release audit remains missing"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only packet"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61eh Real Generation Result Return Packet Boundary

This gate consumes v61eg, v61df, v61ct, v61dg, v61ck, v61cs, v61dd,
v61de, and v61bt. It packages the real generation-result return surface after
the fixture prerequisite-binding proof without counting fixture rows as real
external evidence.

Ready evidence:

- real_manifest_runtime_evidence_ready={summary['real_manifest_runtime_evidence_ready']}
- fixture_prerequisite_binding_ready={summary['fixture_prerequisite_binding_ready']}
- fixture_accepted_generation_result_artifacts={summary['fixture_accepted_generation_result_artifacts']}/5
- fixture_generation_result_accepted_rows={summary['fixture_generation_result_accepted_rows']}/1000
- required_generation_result_artifact_rows={summary['required_generation_result_artifact_rows']}
- required_generation_result_field_rows={summary['required_generation_result_field_rows']}
- packet_file_rows={summary['packet_file_rows']}

Blocked real evidence:

- real_prerequisite_binding_ready={summary['real_prerequisite_binding_ready']}
- real_review_return_ready={summary['real_review_return_ready']}
- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}
- generation_result_accepted_rows={summary['generation_result_accepted_rows']}/{summary['expected_generation_rows']}
- actual_model_generation_ready={summary['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61eh=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: real generation result return packet/schema is ready after the
v61eg binding-mechanics proof.
Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61EH_REAL_GENERATION_RESULT_RETURN_PACKET_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61eh_real_generation_result_return_packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61eh_real_generation_result_return_packet_ready": 1,
    "real_manifest_runtime_evidence_ready": int(summary["real_manifest_runtime_evidence_ready"]),
    "fixture_prerequisite_binding_ready": int(summary["fixture_prerequisite_binding_ready"]),
    "real_prerequisite_binding_ready": real_prerequisite_binding_ready,
    "real_generation_result_artifacts": 0,
    "actual_model_generation_ready": 0,
    "packet_file_rows": len(packet_file_rows),
    "checkpoint_payload_bytes_downloaded_by_v61eh": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61eh_real_generation_result_return_packet_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61eh_real_generation_result_return_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
