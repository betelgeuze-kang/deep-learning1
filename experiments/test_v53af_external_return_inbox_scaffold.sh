#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53af_external_return_inbox_scaffold"
RUN_DIR="$RESULTS_DIR/$PREFIX/scaffold_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V53AF_REUSE_EXISTING="${V53AF_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53af_external_return_inbox_scaffold.sh" >/dev/null

"$RUN_DIR/return_inbox/VERIFY_RETURN_INBOX_SHAPE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
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
    "v53af_external_return_inbox_scaffold_ready": "1",
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": "1",
    "v61df_external_review_generation_return_operator_packet_ready": "1",
    "return_inbox_scaffold_ready": "1",
    "return_inbox_file_rows": "84",
    "required_return_artifact_rows": "81",
    "dispatch_receipt_template_files": "21",
    "review_chunk_return_template_files": "50",
    "aggregate_review_return_template_files": "5",
    "generation_result_template_files": "5",
    "template_files_accepted_by_default": "0",
    "answer_review_accepted_rows": "0",
    "accepted_chunk_return_artifact_rows": "0",
    "accepted_dispatch_receipt_rows": "0",
    "generation_execution_admitted_rows": "0",
    "accepted_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "full_shard_prerequisites_closed": "1",
    "runtime_admission_accepted_rows": "1000",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53af": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53af {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "external_return_receipt_template_rows.csv",
    "external_return_chunk_template_rows.csv",
    "external_return_aggregate_review_template_rows.csv",
    "external_return_generation_result_template_rows.csv",
    "external_return_required_artifact_index_rows.csv",
    "external_return_inbox_file_rows.csv",
    "external_return_inbox_requirement_rows.csv",
    "external_return_inbox_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53AF_EXTERNAL_RETURN_INBOX_SCAFFOLD_BOUNDARY.md",
    "v53af_external_return_inbox_scaffold_manifest.json",
    "return_inbox/RETURN_INBOX_README.md",
    "return_inbox/VERIFY_RETURN_INBOX_SHAPE.sh",
    "return_inbox/RUN_V53AE_WITH_FINAL_RETURNS.sh.template",
    "source/v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv",
    "source/v61df_external_review_generation_return_operator_packet_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53af artifact: {rel}")

receipt_rows = read_csv(run_dir / "external_return_receipt_template_rows.csv")
chunk_rows = read_csv(run_dir / "external_return_chunk_template_rows.csv")
aggregate_rows = read_csv(run_dir / "external_return_aggregate_review_template_rows.csv")
generation_rows = read_csv(run_dir / "external_return_generation_result_template_rows.csv")
index_rows = read_csv(run_dir / "external_return_required_artifact_index_rows.csv")
file_rows = read_csv(run_dir / "external_return_inbox_file_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "external_return_inbox_requirement_rows.csv")}
metric = read_csv(run_dir / "external_return_inbox_metric_rows.csv")[0]
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(receipt_rows) != 21 or len(chunk_rows) != 50 or len(aggregate_rows) != 5 or len(generation_rows) != 5:
    raise SystemExit("v53af template row count mismatch")
if len(index_rows) != 81:
    raise SystemExit("v53af required artifact index count mismatch")
if len(file_rows) != 84:
    raise SystemExit("v53af return inbox file count mismatch")
if any(row["accepted_by_default"] != "0" for row in index_rows):
    raise SystemExit("v53af templates must not be accepted by default")
if any(not row["template_artifact"].startswith("return_inbox/") for row in index_rows):
    raise SystemExit("v53af template paths must stay under return_inbox")
if any(not row["template_artifact"].endswith(".template") for row in index_rows):
    raise SystemExit("v53af template artifacts must use .template suffix")

for field, value in expected.items():
    if field.startswith("v53af_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53af metric {field}: expected {value}, got {metric[field]}")

for requirement_id in [
    "v53ae-rendezvous-input",
    "v61df-operator-packet-input",
    "return-inbox-template-shape",
    "template-zero-evidence-boundary",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v53af requirement should pass: {requirement_id}")
for requirement_id in [
    "review-return-accepted",
    "generation-result-accepted",
    "actual-model-generation",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v53af requirement should stay blocked: {requirement_id}")

for gate in [
    "v53ae-rendezvous-input",
    "v61df-operator-packet-input",
    "return-inbox-template-shape",
    "template-zero-evidence-boundary",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v53af decision should pass: {gate}")
for gate in [
    "review-return-accepted",
    "generation-result-accepted",
    "actual-model-generation",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53af decision should stay blocked: {gate}")

if gaps.get("return-inbox-scaffold") != "ready":
    raise SystemExit("v53af scaffold gap should be ready")
for gap in [
    "dispatch-receipt-return",
    "review-chunk-return",
    "aggregate-review-return",
    "generation-result-return",
    "actual-model-generation",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53af gap should stay blocked: {gap}")

boundary = (run_dir / "V53AF_EXTERNAL_RETURN_INBOX_SCAFFOLD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_inbox_scaffold_ready=1",
    "required_return_artifact_rows=81",
    "dispatch_receipt_template_files=21",
    "review_chunk_return_template_files=50",
    "aggregate_review_return_template_files=5",
    "generation_result_template_files=5",
    "template_files_accepted_by_default=0",
    "answer_review_accepted_rows=0",
    "generation_execution_admitted_rows=0",
    "accepted_generation_result_artifacts=0",
    "actual_model_generation_ready=0",
    "full_shard_prerequisites_closed=1",
    "runtime_admission_accepted_rows=1000",
    "checkpoint_payload_bytes_downloaded_by_v53af=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53af boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53af_external_return_inbox_scaffold_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53af_external_return_inbox_scaffold_ready") != 1:
    raise SystemExit("v53af manifest readiness mismatch")
if manifest.get("required_return_artifact_rows") != 81:
    raise SystemExit("v53af manifest required artifact count mismatch")
if manifest.get("template_files_accepted_by_default") != 0:
    raise SystemExit("v53af templates must not be accepted evidence")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v53af manifest must keep actual generation blocked")
if manifest.get("checkpoint_payload_bytes_committed_to_repo") != 0:
    raise SystemExit("v53af manifest must keep repo payload bytes at zero")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53af sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53af produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53af external return inbox scaffold smoke passed"
