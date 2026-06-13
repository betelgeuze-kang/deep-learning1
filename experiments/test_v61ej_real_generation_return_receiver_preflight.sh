#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ej_real_generation_return_receiver_preflight"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
FIXTURE_RUN_DIR="$RESULTS_DIR/$PREFIX/fixture_preflight_v61ej"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_GENERATION_RESULT_DIR="$RESULTS_DIR/v61ef_generation_result_fixture_prereq_gap_gate/gate_001/fixture_generation_result_return"

V61EJ_REUSE_EXISTING="${V61EJ_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null

V61EJ_RUN_ID="fixture_preflight_v61ej" \
V61EJ_GENERATION_RESULT_DIR="$FIXTURE_GENERATION_RESULT_DIR" \
V61EJ_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null

V61EJ_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
fixture_run_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61ej_real_generation_return_receiver_preflight_ready": "1",
    "v61eh_real_generation_result_return_packet_ready": "1",
    "generation_result_dir_supplied": "0",
    "generation_result_dir_exists": "0",
    "expected_generation_result_artifacts": "5",
    "supplied_generation_result_artifacts": "0",
    "preflight_pass_generation_result_artifacts": "0",
    "invalid_generation_result_artifacts": "0",
    "missing_generation_result_artifacts": "5",
    "required_generation_result_field_rows": "42",
    "preflight_field_pass_rows": "0",
    "preflight_field_missing_rows": "42",
    "expected_generation_rows": "1000",
    "receiver_preflight_query_rows": "1000",
    "receiver_preflight_query_pass_rows": "0",
    "generation_result_receiver_preflight_ready": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ej": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ej {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "receiver_preflight_artifact_rows.csv",
    "receiver_preflight_query_rows.csv",
    "receiver_preflight_requirement_rows.csv",
    "receiver_preflight_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61EJ_REAL_GENERATION_RETURN_RECEIVER_PREFLIGHT_BOUNDARY.md",
    "v61ej_real_generation_return_receiver_preflight_manifest.json",
    "source_v61eh/v61eh_real_generation_result_return_packet_summary.csv",
    "source_v61eh/real_generation_required_artifact_rows.csv",
    "source_v61eh/REQUIRED_FIELD_ROWS.csv",
    "source_v53r/review_query_packet_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ej artifact: {rel}")

artifact_rows = read_csv(run_dir / "receiver_preflight_artifact_rows.csv")
if len(artifact_rows) != 5:
    raise SystemExit("v61ej expected five artifact rows")
if any(row["artifact_supplied"] != "0" or row["artifact_preflight_pass"] != "0" for row in artifact_rows):
    raise SystemExit("v61ej default path should not pass artifact preflight")
if any(row["counts_as_real_generation_result"] != "0" for row in artifact_rows):
    raise SystemExit("v61ej default artifact rows must not count as real generation")

requirements = {row["requirement_id"]: row["status"] for row in read_csv(run_dir / "receiver_preflight_requirement_rows.csv")}
if requirements["v61eh-return-packet-input"] != "pass":
    raise SystemExit("v61ej should bind v61eh packet input")
for requirement_id in [
    "generation-result-dir-supplied",
    "generation-result-dir-exists",
    "generation-result-artifact-preflight",
    "actual-model-generation",
]:
    if requirements[requirement_id] != "blocked":
        raise SystemExit(f"v61ej requirement should stay blocked: {requirement_id}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions["v61eh-return-packet-input"] != "pass" or decisions["repo-checkpoint-payload"] != "pass":
    raise SystemExit("v61ej packet/repo gates should pass")
for gate in ["generation-result-dir", "generation-result-artifact-preflight", "actual-model-generation"]:
    if decisions[gate] != "blocked":
        raise SystemExit(f"v61ej default decision should be blocked: {gate}")

fixture_metric = read_csv(fixture_run_dir / "receiver_preflight_metric_rows.csv")[0]
fixture_expected = {
    "generation_result_dir_supplied": "1",
    "generation_result_dir_exists": "1",
    "supplied_generation_result_artifacts": "5",
    "preflight_pass_generation_result_artifacts": "5",
    "invalid_generation_result_artifacts": "0",
    "missing_generation_result_artifacts": "0",
    "required_generation_result_field_rows": "42",
    "preflight_field_pass_rows": "42",
    "preflight_field_missing_rows": "0",
    "receiver_preflight_query_rows": "1000",
    "receiver_preflight_query_pass_rows": "1000",
    "generation_result_receiver_preflight_ready": "1",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
}
for field, value in fixture_expected.items():
    if fixture_metric.get(field) != value:
        raise SystemExit(f"v61ej fixture {field}: expected {value}, got {fixture_metric.get(field)}")

fixture_artifact_rows = read_csv(fixture_run_dir / "receiver_preflight_artifact_rows.csv")
if any(row["artifact_preflight_pass"] != "1" for row in fixture_artifact_rows):
    raise SystemExit("v61ej fixture artifacts should pass receiver preflight")
if any(row["counts_as_real_generation_result"] != "0" for row in fixture_artifact_rows):
    raise SystemExit("v61ej fixture artifacts must not count as real generation")

boundary = (run_dir / "V61EJ_REAL_GENERATION_RETURN_RECEIVER_PREFLIGHT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "generation_result_dir_supplied=0",
    "expected_generation_result_artifacts=5",
    "preflight_pass_generation_result_artifacts=0",
    "required_generation_result_field_rows=42",
    "generation_result_receiver_preflight_ready=0",
    "real_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ej boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ej_real_generation_return_receiver_preflight_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ej_real_generation_return_receiver_preflight_ready") != 1:
    raise SystemExit("v61ej manifest readiness mismatch")
if manifest.get("generation_result_receiver_preflight_ready") != 0:
    raise SystemExit("v61ej canonical default must keep preflight blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ej manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v61ej manifest must keep repo payload at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ej sha256 mismatch: {rel}")

canonical_summary = read_csv(root / "results/v61ej_real_generation_return_receiver_preflight_summary.csv")[0]
if canonical_summary["generation_result_dir_supplied"] != "0":
    raise SystemExit("v61ej did not restore canonical no-return summary")
PY

if find "$RESULTS_DIR/$PREFIX" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ej produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ej real generation return receiver preflight smoke passed"
