#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate/refresh_001"
SUMMARY_CSV="$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate_decision.csv"

V53Y_REUSE_EXISTING="${V53Y_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v53y_complete_source_review_return_refresh_gate.sh" >/dev/null

"$RUN_DIR/operator_bundle/VERIFY_REVIEW_RETURN_REFRESH.sh" >/dev/null

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
    "v53y_complete_source_review_return_refresh_gate_ready": "1",
    "return_dir_supplied": "0",
    "return_dir_exists": "0",
    "v53x_complete_source_review_chunk_return_intake_ready": "1",
    "v53s_complete_source_review_return_intake_ready": "1",
    "v53v_complete_source_review_return_acceptance_bridge_ready": "1",
    "v53t_complete_source_audit_readiness_gate_ready": "1",
    "machine_complete_source_surface_ready": "1",
    "refresh_stage_rows": "5",
    "ready_refresh_stage_rows": "1",
    "blocked_refresh_stage_rows": "4",
    "refresh_command_rows": "3",
    "ready_refresh_command_rows": "1",
    "review_chunk_rows": "21",
    "review_chunk_return_artifact_rows": "50",
    "accepted_chunk_return_artifact_rows": "0",
    "aggregate_review_return_artifact_rows": "5",
    "accepted_aggregate_review_return_artifact_rows": "0",
    "v53s_refresh_ready": "0",
    "expected_human_review_rows": "7000",
    "accepted_human_review_rows": "0",
    "expected_adjudication_rows": "1000",
    "accepted_adjudication_rows": "0",
    "expected_reviewer_identity_rows": "21",
    "accepted_reviewer_identity_rows": "0",
    "expected_conflict_disclosure_rows": "210",
    "accepted_conflict_disclosure_rows": "0",
    "acceptance_summary_ready": "0",
    "review_return_ready": "0",
    "review_return_acceptance_rows": "7000",
    "answer_review_accepted_rows": "0",
    "human_review_blocked_acceptance_rows": "7000",
    "adjudication_blocked_acceptance_rows": "1000",
    "v61_review_unblock_ready": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v53y {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "complete_source_review_return_refresh_stage_rows.csv",
    "complete_source_review_return_refresh_command_rows.csv",
    "complete_source_review_return_refresh_requirement_rows.csv",
    "complete_source_review_return_refresh_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V53Y_COMPLETE_SOURCE_REVIEW_RETURN_REFRESH_GATE_BOUNDARY.md",
    "v53y_complete_source_review_return_refresh_gate_manifest.json",
    "operator_bundle/README.md",
    "operator_bundle/VERIFY_REVIEW_RETURN_REFRESH.sh",
    "source_v53x/review_return_chunk_artifact_status_rows.csv",
    "source_v53x/review_return_aggregate_artifact_status_rows.csv",
    "source_v53s/review_return_metric_rows.csv",
    "source_v53v/complete_source_review_return_acceptance_metric_rows.csv",
    "source_v53t/complete_source_audit_readiness_requirement_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v53y artifact: {rel}")

stage_rows = read_csv(run_dir / "complete_source_review_return_refresh_stage_rows.csv")
command_rows = read_csv(run_dir / "complete_source_review_return_refresh_command_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "complete_source_review_return_refresh_requirement_rows.csv")}
metric = read_csv(run_dir / "complete_source_review_return_refresh_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(stage_rows) != 5:
    raise SystemExit("v53y expected five refresh stage rows")
if [row["stage_status"] for row in stage_rows] != ["ready", "blocked", "blocked", "blocked", "blocked"]:
    raise SystemExit("v53y stage status sequence mismatch")
if len(command_rows) != 3:
    raise SystemExit("v53y expected three command rows")
if [row["ready_to_run_now"] for row in command_rows] != ["1", "0", "0"]:
    raise SystemExit("v53y command readiness mismatch")

for field, value in expected.items():
    if field.startswith("v53y_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v53y metric {field}: expected {value}, got {metric[field]}")

if requirements["return-directory-supplied"]["status"] != "blocked":
    raise SystemExit("v53y return directory requirement should be blocked")
if requirements["v53x-chunk-intake"]["status"] != "blocked":
    raise SystemExit("v53y v53x chunk intake requirement should be blocked")
if requirements["v53s-aggregate-intake"]["status"] != "blocked":
    raise SystemExit("v53y v53s aggregate intake requirement should be blocked")
if requirements["v53v-per-answer-acceptance"]["status"] != "blocked":
    raise SystemExit("v53y v53v acceptance requirement should be blocked")
if requirements["v61-review-unblock"]["status"] != "blocked":
    raise SystemExit("v53y v61 review unblock requirement should be blocked")

if decisions["machine-complete-source-surface"] != "pass":
    raise SystemExit("v53y machine surface decision should pass")
for gate in [
    "return-directory-supplied",
    "chunk-return-intake",
    "aggregate-review-return-intake",
    "per-answer-review-acceptance",
    "v61-review-unblock",
    "v53-ready",
    "v1.0-comparison-ready",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v53y decision should stay blocked: {gate}")

for gap in [
    "review-return-directory",
    "chunk-return-intake",
    "aggregate-review-return-intake",
    "per-answer-review-acceptance",
    "v61-review-unblock",
    "v53-ready",
    "v1.0-comparison-ready",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v53y gap should stay blocked: {gap}")

boundary = (run_dir / "V53Y_COMPLETE_SOURCE_REVIEW_RETURN_REFRESH_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "return_dir_supplied=0",
    "machine_complete_source_surface_ready=1",
    "ready_refresh_stage_rows=1",
    "blocked_refresh_stage_rows=4",
    "accepted_chunk_return_artifact_rows=0",
    "accepted_aggregate_review_return_artifact_rows=0",
    "expected_human_review_rows=7000",
    "answer_review_accepted_rows=0",
    "v61_review_unblock_ready=0",
    "v53_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v53y boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v53y_complete_source_review_return_refresh_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v53y_complete_source_review_return_refresh_gate_ready") != 1:
    raise SystemExit("v53y manifest readiness mismatch")
if manifest.get("ready_refresh_stage_rows") != 1 or manifest.get("blocked_refresh_stage_rows") != 4:
    raise SystemExit("v53y manifest stage count mismatch")
if manifest.get("review_return_ready") != 0 or manifest.get("v61_review_unblock_ready") != 0:
    raise SystemExit("v53y manifest should keep review and v61 unblock blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v53y sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v53y produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v53y complete-source review return refresh gate smoke passed"
