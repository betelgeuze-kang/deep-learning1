#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61ar_moe_remote_hash_result_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v61ar_moe_remote_hash_result_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61ar_moe_remote_hash_result_intake_decision.csv"

V61AR_REUSE_EXISTING="${V61AR_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61ar_moe_remote_hash_result_intake.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
    "v61ar_moe_remote_hash_result_intake_ready": "1",
    "v61aq_moe_remote_hash_execution_gate_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "remote_hash_result_input_supplied": "0",
    "expected_remote_hash_result_rows": "1329",
    "supplied_remote_hash_result_rows": "0",
    "accepted_remote_hash_result_rows": "0",
    "invalid_remote_hash_result_rows": "0",
    "missing_remote_hash_result_rows": "1329",
    "existing_remote_hash_rows": "15",
    "required_moe_remote_hash_rows": "1344",
    "verified_remote_hash_rows": "15",
    "result_schema_ready": "0",
    "result_artifact_ready": "0",
    "remote_hash_result_intake_ready": "0",
    "full_moe_coverage_remote_hash_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ar": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ar {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "moe_remote_hash_result_required_field_rows.csv",
    "moe_remote_hash_result_template_rows.csv",
    "moe_remote_hash_result_validation_rows.csv",
    "moe_remote_hash_result_invalid_rows.csv",
    "moe_remote_hash_combined_coverage_rows.csv",
    "moe_remote_hash_result_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AR_MOE_REMOTE_HASH_RESULT_INTAKE_BOUNDARY.md",
    "v61ar_moe_remote_hash_result_intake_manifest.json",
    "sha256_manifest.csv",
    "source_v61aq/moe_remote_hash_execution_command_rows.csv",
    "source_v61aq/moe_remote_hash_existing_hash_rows.csv",
    "source_v61aq/moe_remote_hash_execution_chunk_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ar artifact: {rel}")

required_fields = read_csv(run_dir / "moe_remote_hash_result_required_field_rows.csv")
templates = read_csv(run_dir / "moe_remote_hash_result_template_rows.csv")
validation_rows = {row["validation_id"]: row for row in read_csv(run_dir / "moe_remote_hash_result_validation_rows.csv")}
invalid_rows = read_csv(run_dir / "moe_remote_hash_result_invalid_rows.csv")
coverage_rows = read_csv(run_dir / "moe_remote_hash_combined_coverage_rows.csv")
metric = read_csv(run_dir / "moe_remote_hash_result_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(required_fields) != 10 or len(templates) != 2:
    raise SystemExit("v61ar required field/template row count mismatch")
if len(coverage_rows) != 1344:
    raise SystemExit("v61ar coverage rows should cover all 1344 representative MoE cells")
if invalid_rows[0]["status"] != "none":
    raise SystemExit("v61ar default path should not create invalid supplied rows")

coverage_counts = Counter(row["coverage_source"] for row in coverage_rows)
if coverage_counts["existing-v61v-remote-hash"] != 15:
    raise SystemExit(f"v61ar existing coverage mismatch: {coverage_counts}")
if coverage_counts["missing-supplied-result"] != 1329:
    raise SystemExit(f"v61ar missing coverage mismatch: {coverage_counts}")
if any(row["remote_hash_verified"] != "1" for row in coverage_rows if row["coverage_source"] == "existing-v61v-remote-hash"):
    raise SystemExit("v61ar existing rows should stay verified")
if any(row["remote_hash_verified"] != "0" for row in coverage_rows if row["coverage_source"] == "missing-supplied-result"):
    raise SystemExit("v61ar missing rows should stay unverified")
if any(row["checkpoint_payload_bytes_downloaded_by_v61ar"] != "0" for row in coverage_rows):
    raise SystemExit("v61ar must not download checkpoint payload bytes")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in coverage_rows):
    raise SystemExit("v61ar must not commit checkpoint payload bytes")
if any(row["route_jump_rows"] != "0" for row in coverage_rows):
    raise SystemExit("v61ar must keep route jumps at zero")

if validation_rows["remote-hash-result-input"]["status"] != "blocked":
    raise SystemExit("v61ar result input should be blocked without supplied rows")
if validation_rows["remote-hash-result-schema"]["status"] != "blocked":
    raise SystemExit("v61ar result schema should be blocked without supplied rows")
if validation_rows["final-deferred-default"]["status"] != "pass":
    raise SystemExit("v61ar default deferral should pass")
if validation_rows["final-deferred-default"]["missing_rows"] != "1329":
    raise SystemExit("v61ar default deferral should record all missing result rows")

for field, value in expected.items():
    if field.startswith("v61ar_") or field.startswith("v61aq_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61ar metric {field}: expected {value}, got {metric[field]}")

for gate in [
    "v61aq-execution-gate-input",
    "result-intake-schema-template",
    "existing-remote-hash-preservation",
    "default-no-env-deferral",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ar gate should pass: {gate}")
for gate in [
    "remote-hash-result-artifacts",
    "full-moe-coverage-remote-hash",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ar gate should remain blocked: {gate}")

manifest = json.loads((run_dir / "v61ar_moe_remote_hash_result_intake_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ar_moe_remote_hash_result_intake_ready") != 1:
    raise SystemExit("v61ar manifest readiness mismatch")
if manifest.get("accepted_remote_hash_result_rows") != 0 or manifest.get("missing_remote_hash_result_rows") != 1329:
    raise SystemExit("v61ar manifest result count mismatch")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61ar") != 0:
    raise SystemExit("v61ar manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61AR_MOE_REMOTE_HASH_RESULT_INTAKE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "expected_remote_hash_result_rows=1329",
    "accepted_remote_hash_result_rows=0",
    "missing_remote_hash_result_rows=1329",
    "existing_remote_hash_rows=15",
    "verified_remote_hash_rows=15",
    "remote_hash_result_input_supplied=0",
    "remote_hash_result_intake_ready=0",
    "full_moe_coverage_remote_hash_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61ar=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ar boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ar sha256 mismatch: {rel}")
PY

echo "v61ar MoE remote hash result intake smoke passed"
