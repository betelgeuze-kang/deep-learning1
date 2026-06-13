#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ed_review_return_refresh_fixture_replay_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/gate_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

V61ED_REUSE_EXISTING="${V61ED_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ed_review_return_refresh_fixture_replay_gate.sh" >/dev/null

"$RUN_DIR/review_return_refresh_fixture_replay_bundle/VERIFY_V61ED_FIXTURE_REPLAY.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RESULTS_DIR/v53y_complete_source_review_return_refresh_gate_summary.csv" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
canonical_v53y_summary_csv = Path(sys.argv[4])


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
    "v61ed_review_return_refresh_fixture_replay_gate_ready": "1",
    "v61ec_review_chunk_return_fixture_acceptance_gate_ready": "1",
    "fixture_stage_rows": "10",
    "ready_fixture_stage_rows": "8",
    "blocked_fixture_stage_rows": "2",
    "fixture_family_rows": "5",
    "fixture_v53s_review_return_ready": "1",
    "fixture_v53v_answer_review_accepted_rows": "7000",
    "fixture_v53x_accepted_chunk_return_artifact_rows": "50",
    "fixture_v53x_accepted_aggregate_review_return_artifact_rows": "5",
    "fixture_answer_review_accepted_rows": "7000",
    "fixture_v61_review_unblock_ready": "1",
    "fixture_v53_ready": "0",
    "fixture_v1_0_comparison_ready": "0",
    "canonical_default_review_return_ready": "0",
    "canonical_default_answer_review_accepted_rows": "0",
    "canonical_default_accepted_chunk_return_artifact_rows": "0",
    "canonical_default_v61_review_unblock_ready": "0",
    "real_external_review_return_rows": "0",
    "real_external_human_review_rows": "0",
    "real_external_adjudication_rows": "0",
    "accepted_human_review_rows": "0",
    "accepted_adjudication_rows": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": "11",
    "fixture_invariant_pass_rows": "11",
    "fixture_bundle_file_rows": "8",
    "metadata_only_fixture_bundle_file_rows": "8",
    "checkpoint_payload_bytes_downloaded_by_v61ed": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ed {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "review_return_refresh_fixture_family_rows.csv",
    "review_return_refresh_fixture_file_rows.csv",
    "review_return_refresh_fixture_canonical_restore_rows.csv",
    "review_return_refresh_fixture_replay_stage_rows.csv",
    "review_return_refresh_fixture_replay_invariant_rows.csv",
    "review_return_refresh_fixture_replay_bundle_file_rows.csv",
    "runtime_gap_rows.csv",
    "V61ED_REVIEW_RETURN_REFRESH_FIXTURE_REPLAY_GATE_BOUNDARY.md",
    "v61ed_review_return_refresh_fixture_replay_gate_manifest.json",
    "review_return_refresh_fixture_replay_bundle/README.md",
    "review_return_refresh_fixture_replay_bundle/VERIFY_V61ED_FIXTURE_REPLAY.sh",
    "review_return_refresh_fixture_replay_bundle/REVIEW_RETURN_REFRESH_FIXTURE_FAMILY_ROWS.csv",
    "review_return_refresh_fixture_replay_bundle/REVIEW_RETURN_REFRESH_FIXTURE_FILE_ROWS.csv",
    "review_return_refresh_fixture_replay_bundle/CANONICAL_RESTORE_ROWS.csv",
    "review_return_refresh_fixture_replay_bundle/FIXTURE_REPLAY_STAGES.csv",
    "review_return_refresh_fixture_replay_bundle/FIXTURE_REPLAY_INVARIANTS.csv",
    "review_return_refresh_fixture_replay_bundle/FIXTURE_REPLAY_MANIFEST.json",
    "source_v61ec/v61ec_review_chunk_return_fixture_acceptance_gate_summary.csv",
    "source_v53y_fixture/v53y_complete_source_review_return_refresh_gate_summary.csv",
    "source_v53s_fixture/v53s_complete_source_review_return_intake_summary.csv",
    "source_v53v_fixture/v53v_complete_source_review_return_acceptance_bridge_summary.csv",
    "source_v53x_fixture/v53x_complete_source_review_chunk_return_intake_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ed artifact: {rel}")

family_rows = read_csv(run_dir / "review_return_refresh_fixture_family_rows.csv")
fixture_files = read_csv(run_dir / "review_return_refresh_fixture_file_rows.csv")
restore_rows = read_csv(run_dir / "review_return_refresh_fixture_canonical_restore_rows.csv")
stages = read_csv(run_dir / "review_return_refresh_fixture_replay_stage_rows.csv")
invariants = {row["invariant_id"]: row for row in read_csv(run_dir / "review_return_refresh_fixture_replay_invariant_rows.csv")}
bundle_files = read_csv(run_dir / "review_return_refresh_fixture_replay_bundle_file_rows.csv")
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(family_rows) != 5:
    raise SystemExit("v61ed expected five fixture family rows")
if any(row["fixture_only"] != "1" or row["real_external_review_return"] != "0" for row in family_rows):
    raise SystemExit("v61ed fixture family rows must be synthetic only")
if len([row for row in fixture_files if row["fixture_relative_path"].startswith("chunks/")]) != 50:
    raise SystemExit("v61ed expected 50 chunk fixture files")
if any(row["payload_class"] != "synthetic-review-refresh-fixture" for row in fixture_files):
    raise SystemExit("v61ed fixture file payload class mismatch")
for row in fixture_files:
    path = run_dir / "fixture_review_return_refresh" / row["fixture_relative_path"]
    if not path.is_file() or row["sha256"] != sha256(path):
        raise SystemExit(f"v61ed fixture file hash mismatch: {row['fixture_relative_path']}")

if restore_rows[0]["status"] != "pass":
    raise SystemExit("v61ed canonical restore should pass")
canonical = read_csv(canonical_v53y_summary_csv)[0]
if canonical["answer_review_accepted_rows"] != "0" or canonical["v61_review_unblock_ready"] != "0":
    raise SystemExit("v61ed did not leave canonical v53y summary restored")

if sum(row["status"] == "ready" for row in stages) != 8:
    raise SystemExit("v61ed expected eight ready stages")
if sum(row["status"] == "blocked" for row in stages) != 2:
    raise SystemExit("v61ed expected two blocked stages")

for invariant_id in [
    "v61ec-ready",
    "fixture-family-rows",
    "fixture-files-include-chunks-and-root",
    "fixture-v53s-review-return-ready",
    "fixture-v53v-answer-review-accepted",
    "fixture-v53x-chunk-return-accepted",
    "fixture-v53y-review-unblock-ready",
    "canonical-default-restored",
    "fixture-not-real-external-evidence",
    "actual-generation-still-blocked",
    "repo-checkpoint-payload-zero",
]:
    if invariants[invariant_id]["status"] != "pass":
        raise SystemExit(f"v61ed invariant should pass: {invariant_id}")

if len(bundle_files) != 8:
    raise SystemExit("v61ed expected eight bundle files")
if any(row["payload_class"] != "metadata-only" for row in bundle_files):
    raise SystemExit("v61ed bundle files must be metadata-only")

for gate in [
    "v61ec-chunk-fixture",
    "fixture-v53s-aggregate-intake",
    "fixture-v53v-per-answer-acceptance",
    "fixture-v53x-chunk-intake",
    "fixture-v53y-review-unblock",
    "canonical-default-restore",
    "repo-checkpoint-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ed decision should pass: {gate}")
for gate in ["real-review-return", "actual-model-generation", "release"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ed decision should stay blocked: {gate}")

for gap in ["fixture-review-return-refresh", "canonical-default-restore"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61ed gap should be ready: {gap}")
for gap in ["real-review-return", "actual-generation", "release"]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61ed gap should stay blocked: {gap}")

boundary = (run_dir / "V61ED_REVIEW_RETURN_REFRESH_FIXTURE_REPLAY_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "fixture_v53s_review_return_ready=1",
    "fixture_v53v_answer_review_accepted_rows=7000/7000",
    "fixture_v53x_accepted_chunk_return_artifact_rows=50/50",
    "fixture_v61_review_unblock_ready=1",
    "canonical_default_answer_review_accepted_rows=0",
    "real_external_review_return_rows=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ed boundary missing snippet: {snippet}")

manifest = json.loads((run_dir / "v61ed_review_return_refresh_fixture_replay_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61ed_review_return_refresh_fixture_replay_gate_ready") != 1:
    raise SystemExit("v61ed manifest readiness mismatch")
if manifest.get("fixture_answer_review_accepted_rows") != 7000:
    raise SystemExit("v61ed manifest fixture acceptance mismatch")
if manifest.get("real_external_review_return_rows") != 0:
    raise SystemExit("v61ed manifest must keep real external review rows at zero")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61ed manifest must keep actual generation blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ed sha256 mismatch: {rel}")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61ed produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61ed review return refresh fixture replay gate smoke passed"
