#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cu_complete_source_generation_result_acceptance_bridge"
RUN_ID="${V61CU_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CU_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cu_complete_source_generation_result_acceptance_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null
V61CT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ct_complete_source_generation_execution_operator_bundle.sh" >/dev/null
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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


v61cs_dir = results / "v61cs_complete_source_generation_execution_admission_gate" / "gate_001"
v61ct_dir = results / "v61ct_complete_source_generation_execution_operator_bundle" / "bundle_001"
v61bt_dir = results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001"

v61cs_summary_path = results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv"
v61ct_summary_path = results / "v61ct_complete_source_generation_execution_operator_bundle_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v61cs_decision_path = results / "v61cs_complete_source_generation_execution_admission_gate_decision.csv"
v61ct_decision_path = results / "v61ct_complete_source_generation_execution_operator_bundle_decision.csv"
v61bt_decision_path = results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv"

v61cs = read_csv(v61cs_summary_path)[0]
v61ct = read_csv(v61ct_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]

if v61cs.get("v61cs_complete_source_generation_execution_admission_gate_ready") != "1":
    raise SystemExit("v61cu requires v61cs_complete_source_generation_execution_admission_gate_ready=1")
if v61ct.get("v61ct_complete_source_generation_execution_operator_bundle_ready") != "1":
    raise SystemExit("v61cu requires v61ct_complete_source_generation_execution_operator_bundle_ready=1")
if v61bt.get("v61bt_ubuntu1_actual_generation_result_intake_ready") != "1":
    raise SystemExit("v61cu requires v61bt_ubuntu1_actual_generation_result_intake_ready=1")

for src, rel in [
    (v61cs_summary_path, "source_v61cs/v61cs_complete_source_generation_execution_admission_gate_summary.csv"),
    (v61cs_decision_path, "source_v61cs/v61cs_complete_source_generation_execution_admission_gate_decision.csv"),
    (v61cs_dir / "complete_source_generation_execution_admission_rows.csv", "source_v61cs/complete_source_generation_execution_admission_rows.csv"),
    (v61cs_dir / "complete_source_generation_execution_admission_requirement_rows.csv", "source_v61cs/complete_source_generation_execution_admission_requirement_rows.csv"),
    (v61cs_dir / "complete_source_generation_execution_admission_metric_rows.csv", "source_v61cs/complete_source_generation_execution_admission_metric_rows.csv"),
    (v61cs_dir / "runtime_gap_rows.csv", "source_v61cs/runtime_gap_rows.csv"),
    (v61cs_dir / "sha256_manifest.csv", "source_v61cs/sha256_manifest.csv"),
    (v61ct_summary_path, "source_v61ct/v61ct_complete_source_generation_execution_operator_bundle_summary.csv"),
    (v61ct_decision_path, "source_v61ct/v61ct_complete_source_generation_execution_operator_bundle_decision.csv"),
    (v61ct_dir / "complete_source_generation_execution_operator_command_rows.csv", "source_v61ct/complete_source_generation_execution_operator_command_rows.csv"),
    (v61ct_dir / "complete_source_generation_execution_operator_requirement_rows.csv", "source_v61ct/complete_source_generation_execution_operator_requirement_rows.csv"),
    (v61ct_dir / "complete_source_generation_execution_operator_metric_rows.csv", "source_v61ct/complete_source_generation_execution_operator_metric_rows.csv"),
    (v61ct_dir / "operator_bundle/GENERATION_RESULT_RETURN_TEMPLATE.csv", "source_v61ct/GENERATION_RESULT_RETURN_TEMPLATE.csv"),
    (v61ct_dir / "sha256_manifest.csv", "source_v61ct/sha256_manifest.csv"),
    (v61bt_summary_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (v61bt_decision_path, "source_v61bt/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (v61bt_dir / "actual_generation_query_result_rows.csv", "source_v61bt/actual_generation_query_result_rows.csv"),
    (v61bt_dir / "actual_generation_result_status_rows.csv", "source_v61bt/actual_generation_result_status_rows.csv"),
    (v61bt_dir / "actual_generation_result_validation_rows.csv", "source_v61bt/actual_generation_result_validation_rows.csv"),
    (v61bt_dir / "actual_generation_result_metric_rows.csv", "source_v61bt/actual_generation_result_metric_rows.csv"),
    (v61bt_dir / "sha256_manifest.csv", "source_v61bt/sha256_manifest.csv"),
]:
    copy(src, rel)

admission_rows = read_csv(v61cs_dir / "complete_source_generation_execution_admission_rows.csv")
query_result_rows = read_csv(v61bt_dir / "actual_generation_query_result_rows.csv")
result_status_rows = read_csv(v61bt_dir / "actual_generation_result_status_rows.csv")
validation_rows = read_csv(v61bt_dir / "actual_generation_result_validation_rows.csv")

if len(admission_rows) != 1000:
    raise SystemExit("v61cu expects 1000 v61cs admission rows")
if len(query_result_rows) != 1000:
    raise SystemExit("v61cu expects 1000 v61bt query result rows")
if len(result_status_rows) != 5 or len(validation_rows) != 5:
    raise SystemExit("v61cu expects five result status and validation rows")

result_by_query = {row["query_id"]: row for row in query_result_rows}
missing_query_ids = [row["query_id"] for row in admission_rows if row["query_id"] not in result_by_query]
if missing_query_ids:
    raise SystemExit(f"v61cu query id mismatch: first missing {missing_query_ids[0]}")

admission_ready = as_int(v61cs, "generation_execution_admission_ready")
operator_ready = as_int(v61ct, "generation_operator_execution_ready")
guard_ready = as_int(v61ct, "guarded_generation_command_ready")
result_artifacts_ready = as_int(v61bt, "generation_packet_artifacts_ready")
expected_generation_result_artifacts = as_int(v61bt, "expected_generation_result_artifacts")
accepted_generation_result_artifacts = as_int(v61bt, "accepted_generation_result_artifacts")
accepted_answer_rows = as_int(v61bt, "accepted_answer_rows")
accepted_citation_rows = as_int(v61bt, "accepted_citation_rows")
accepted_latency_rows = as_int(v61bt, "accepted_latency_rows")

accepted_generation_rows = 0
supplied_generation_rows = 0
answer_accepted_rows = 0
citation_accepted_rows = 0
latency_accepted_rows = 0
actual_ready_rows = 0
admission_blocked_rows = 0
operator_blocked_rows = 0
result_artifact_blocked_rows = 0
answer_blocked_rows = 0
citation_blocked_rows = 0
latency_blocked_rows = 0

acceptance_rows = []
for index, admission in enumerate(admission_rows):
    result = result_by_query[admission["query_id"]]
    execution_admitted = int(admission["generation_execution_admitted"])
    result_supplied = int(result["generation_result_supplied"])
    result_accepted = int(result["generation_result_accepted"])
    answer_accepted = int(result_accepted and accepted_answer_rows >= len(query_result_rows))
    citation_accepted = int(result_accepted and accepted_citation_rows >= len(query_result_rows))
    latency_accepted = int(result_accepted and accepted_latency_rows >= len(query_result_rows))

    admission_blocked = int(not execution_admitted or not admission_ready)
    operator_blocked = int(not operator_ready or not guard_ready)
    result_artifact_blocked = int(not result_artifacts_ready or not result_accepted)
    answer_blocked = int(not answer_accepted)
    citation_blocked = int(not citation_accepted)
    latency_blocked = int(not latency_accepted)
    actual_ready = int(
        execution_admitted
        and operator_ready
        and guard_ready
        and result_artifacts_ready
        and result_accepted
        and answer_accepted
        and citation_accepted
        and latency_accepted
    )

    supplied_generation_rows += result_supplied
    accepted_generation_rows += result_accepted
    answer_accepted_rows += answer_accepted
    citation_accepted_rows += citation_accepted
    latency_accepted_rows += latency_accepted
    actual_ready_rows += actual_ready
    admission_blocked_rows += admission_blocked
    operator_blocked_rows += operator_blocked
    result_artifact_blocked_rows += result_artifact_blocked
    answer_blocked_rows += answer_blocked
    citation_blocked_rows += citation_blocked
    latency_blocked_rows += latency_blocked

    blocking_reasons = []
    if admission_blocked:
        blocking_reasons.append("generation-execution-admission-blocked")
    if operator_blocked:
        blocking_reasons.append("generation-operator-execution-blocked")
    if result_artifact_blocked:
        blocking_reasons.append("generation-result-artifacts-missing")
    if answer_blocked:
        blocking_reasons.append("answer-rows-not-accepted")
    if citation_blocked:
        blocking_reasons.append("citation-rows-not-accepted")
    if latency_blocked:
        blocking_reasons.append("latency-rows-not-accepted")

    acceptance_rows.append(
        {
            "generation_result_acceptance_id": f"v61cu-generation-result-acceptance-{index:04d}",
            "generation_execution_admission_id": admission["generation_execution_admission_id"],
            "generation_query_result_id": result["generation_query_result_id"],
            "review_query_packet_id": admission["review_query_packet_id"],
            "query_id": admission["query_id"],
            "owner_repo": admission["owner_repo"],
            "source_span_id": admission["source_span_id"],
            "source_file_sha256": admission["source_file_sha256"],
            "model_id": admission["model_id"],
            "generation_execution_admitted": str(execution_admitted),
            "generation_operator_execution_ready": str(operator_ready),
            "guarded_generation_command_ready": str(guard_ready),
            "generation_result_supplied": str(result_supplied),
            "generation_result_accepted": str(result_accepted),
            "answer_artifact_accepted": str(answer_accepted),
            "citation_artifact_accepted": str(citation_accepted),
            "latency_artifact_accepted": str(latency_accepted),
            "actual_model_generation_ready": str(actual_ready),
            "admission_blocked": str(admission_blocked),
            "operator_blocked": str(operator_blocked),
            "result_artifact_blocked": str(result_artifact_blocked),
            "answer_blocked": str(answer_blocked),
            "citation_blocked": str(citation_blocked),
            "latency_blocked": str(latency_blocked),
            "generation_status": result["generation_status"],
            "blocking_reason": ";".join(blocking_reasons) if blocking_reasons else "accepted",
            "checkpoint_payload_bytes_downloaded_by_v61cu": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "route_jump_rows": "0",
        }
    )

write_csv(run_dir / "complete_source_generation_result_acceptance_rows.csv", list(acceptance_rows[0].keys()), acceptance_rows)

requirement_rows = [
    {"requirement_id": "v61cs-generation-execution-admission-input", "status": "pass", "required_value": "1", "actual_value": v61cs["v61cs_complete_source_generation_execution_admission_gate_ready"], "reason": "v61cs admission surface is bound"},
    {"requirement_id": "v61ct-generation-operator-bundle-input", "status": "pass", "required_value": "1", "actual_value": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"], "reason": "v61ct operator bundle is bound"},
    {"requirement_id": "v61bt-generation-result-intake-input", "status": "pass", "required_value": "1", "actual_value": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"], "reason": "v61bt result intake is bound"},
    {"requirement_id": "complete-source-generation-execution-admission", "status": status(admission_ready), "required_value": "1000", "actual_value": v61cs["generation_execution_admitted_rows"], "reason": "all generation rows must be execution-admitted before acceptance"},
    {"requirement_id": "generation-operator-execution", "status": status(operator_ready and guard_ready), "required_value": "1", "actual_value": str(int(operator_ready and guard_ready)), "reason": "guarded operator command must be open"},
    {"requirement_id": "generation-result-artifact-return", "status": status(result_artifacts_ready), "required_value": str(expected_generation_result_artifacts), "actual_value": str(accepted_generation_result_artifacts), "reason": "all real generation result artifacts must be accepted"},
    {"requirement_id": "answer-citation-latency-acceptance", "status": status(accepted_answer_rows == 1000 and accepted_citation_rows == 1000 and accepted_latency_rows == 1000), "required_value": "1000/1000/1000", "actual_value": f"{accepted_answer_rows}/{accepted_citation_rows}/{accepted_latency_rows}", "reason": "answer, citation, and latency rows must each cover the full query set"},
    {"requirement_id": "actual-model-generation", "status": status(actual_ready_rows == 1000), "required_value": "1000", "actual_value": str(actual_ready_rows), "reason": "actual generation readiness requires admitted execution and accepted returned artifacts"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "required_value": "0", "actual_value": "0", "reason": "v61cu writes metadata and copied evidence only"},
]
write_csv(run_dir / "complete_source_generation_result_acceptance_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cu_complete_source_generation_result_acceptance_bridge_metrics",
    "model_id": model_id,
    "v61cs_complete_source_generation_execution_admission_gate_ready": v61cs["v61cs_complete_source_generation_execution_admission_gate_ready"],
    "v61ct_complete_source_generation_execution_operator_bundle_ready": v61ct["v61ct_complete_source_generation_execution_operator_bundle_ready"],
    "v61bt_ubuntu1_actual_generation_result_intake_ready": v61bt["v61bt_ubuntu1_actual_generation_result_intake_ready"],
    "generation_result_acceptance_rows": str(len(acceptance_rows)),
    "generation_execution_admission_rows": v61cs["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61cs["generation_execution_admitted_rows"],
    "generation_execution_blocked_rows": v61cs["generation_execution_blocked_rows"],
    "generation_execution_admission_ready": str(admission_ready),
    "guarded_generation_command_ready": str(guard_ready),
    "generation_operator_execution_ready": str(operator_ready),
    "expected_generation_result_artifacts": str(expected_generation_result_artifacts),
    "accepted_generation_result_artifacts": str(accepted_generation_result_artifacts),
    "generation_result_supplied_rows": str(supplied_generation_rows),
    "generation_result_accepted_rows": str(accepted_generation_rows),
    "answer_accepted_rows": str(answer_accepted_rows),
    "citation_accepted_rows": str(citation_accepted_rows),
    "latency_accepted_rows": str(latency_accepted_rows),
    "admission_blocked_acceptance_rows": str(admission_blocked_rows),
    "operator_blocked_acceptance_rows": str(operator_blocked_rows),
    "result_artifact_blocked_acceptance_rows": str(result_artifact_blocked_rows),
    "answer_blocked_acceptance_rows": str(answer_blocked_rows),
    "citation_blocked_acceptance_rows": str(citation_blocked_rows),
    "latency_blocked_acceptance_rows": str(latency_blocked_rows),
    "actual_model_generation_ready_rows": str(actual_ready_rows),
    "actual_model_generation_ready": "1" if actual_ready_rows == len(acceptance_rows) else "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cu": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_generation_result_acceptance_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61cs-generation-execution-admission-input", "status": "ready", "reason": "v61cs final admission surface is bound"},
    {"gap": "v61ct-generation-operator-bundle-input", "status": "ready", "reason": "v61ct operator bundle is bound"},
    {"gap": "v61bt-generation-result-intake-input", "status": "ready", "reason": "v61bt result intake is bound"},
    {"gap": "complete-source-generation-execution-admission", "status": "ready" if admission_ready else "blocked", "reason": f"generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}/{v61cs['generation_execution_admission_rows']}"},
    {"gap": "generation-operator-execution", "status": "ready" if operator_ready and guard_ready else "blocked", "reason": f"guarded_generation_command_ready={guard_ready}, generation_operator_execution_ready={operator_ready}"},
    {"gap": "generation-result-artifact-return", "status": "ready" if result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}"},
    {"gap": "answer-citation-latency-acceptance", "status": "ready" if accepted_answer_rows == 1000 and accepted_citation_rows == 1000 and accepted_latency_rows == 1000 else "blocked", "reason": f"accepted answer/citation/latency rows={accepted_answer_rows}/{accepted_citation_rows}/{accepted_latency_rows}"},
    {"gap": "actual-model-generation", "status": "ready" if actual_ready_rows == 1000 else "blocked", "reason": f"actual_model_generation_ready_rows={actual_ready_rows}/1000"},
    {"gap": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not blind quality evidence"},
    {"gap": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61cs-generation-execution-admission-input", "status": "pass", "reason": "v61cs is ready"},
    {"gate": "v61ct-generation-operator-bundle-input", "status": "pass", "reason": "v61ct is ready"},
    {"gate": "v61bt-generation-result-intake-input", "status": "pass", "reason": "v61bt is ready"},
    {"gate": "complete-source-generation-execution-admission", "status": "pass" if admission_ready else "blocked", "reason": f"generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}/{v61cs['generation_execution_admission_rows']}"},
    {"gate": "generation-operator-execution", "status": "pass" if operator_ready and guard_ready else "blocked", "reason": f"guarded_generation_command_ready={guard_ready}; generation_operator_execution_ready={operator_ready}"},
    {"gate": "generation-result-artifact-return", "status": "pass" if result_artifacts_ready else "blocked", "reason": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}"},
    {"gate": "answer-citation-latency-acceptance", "status": "pass" if accepted_answer_rows == 1000 and accepted_citation_rows == 1000 and accepted_latency_rows == 1000 else "blocked", "reason": f"accepted answer/citation/latency rows={accepted_answer_rows}/{accepted_citation_rows}/{accepted_latency_rows}"},
    {"gate": "actual-model-generation", "status": "pass" if actual_ready_rows == 1000 else "blocked", "reason": f"actual_model_generation_ready_rows={actual_ready_rows}/1000"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "not blind quality evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61cu writes metadata only"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61cu Complete-Source Generation Result Acceptance Bridge Boundary

This artifact joins v61cs execution admission, v61ct operator bundling, and
v61bt generation result intake into the final 1000-row actual-generation
acceptance surface. It does not run the model. It refuses actual generation
readiness until execution admission, guarded operator execution, returned
answer/citation/latency artifacts, and per-query result acceptance all pass.

Evidence emitted:

- generation_result_acceptance_rows={len(acceptance_rows)}
- generation_execution_admitted_rows={v61cs['generation_execution_admitted_rows']}
- generation_execution_blocked_rows={v61cs['generation_execution_blocked_rows']}
- generation_execution_admission_ready={admission_ready}
- guarded_generation_command_ready={guard_ready}
- generation_operator_execution_ready={operator_ready}
- expected_generation_result_artifacts={expected_generation_result_artifacts}
- accepted_generation_result_artifacts={accepted_generation_result_artifacts}
- generation_result_supplied_rows={supplied_generation_rows}
- generation_result_accepted_rows={accepted_generation_rows}
- answer_accepted_rows={answer_accepted_rows}
- citation_accepted_rows={citation_accepted_rows}
- latency_accepted_rows={latency_accepted_rows}
- admission_blocked_acceptance_rows={admission_blocked_rows}
- result_artifact_blocked_acceptance_rows={result_artifact_blocked_rows}
- actual_model_generation_ready_rows={actual_ready_rows}
- actual_model_generation_ready={metric['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61cu=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete-source generation result acceptance bridge.
Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61CU_COMPLETE_SOURCE_GENERATION_RESULT_ACCEPTANCE_BRIDGE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61cu_complete_source_generation_result_acceptance_bridge",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61cu_complete_source_generation_result_acceptance_bridge_ready": 1,
    "source_v61cs_summary_sha256": sha256(v61cs_summary_path),
    "source_v61ct_summary_sha256": sha256(v61ct_summary_path),
    "source_v61bt_summary_sha256": sha256(v61bt_summary_path),
    "generation_result_acceptance_rows": len(acceptance_rows),
    "generation_execution_admitted_rows": int(v61cs["generation_execution_admitted_rows"]),
    "generation_result_accepted_rows": accepted_generation_rows,
    "actual_model_generation_ready_rows": actual_ready_rows,
    "actual_model_generation_ready": int(metric["actual_model_generation_ready"]),
    "checkpoint_payload_bytes_downloaded_by_v61cu": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61cu_complete_source_generation_result_acceptance_bridge_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61cu_complete_source_generation_result_acceptance_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
