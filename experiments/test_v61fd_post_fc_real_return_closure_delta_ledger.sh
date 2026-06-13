#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fd_post_fc_real_return_closure_delta_ledger"
RUN_DIR="$RESULTS_DIR/$PREFIX/ledger_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
LEDGER_DIR="$RUN_DIR/real_return_closure_delta_ledger"

V61FC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fc_post_fb_dual_external_return_operator_packet.sh" >/dev/null
V61FD_REUSE_EXISTING="${V61FD_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh" >/dev/null
V61FD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$LEDGER_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ledger_dir = Path(sys.argv[4])


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
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": "1",
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "v61ex_generation_acceptance_closure_work_order_ready": "1",
    "delta_rows": "14",
    "open_delta_rows": "14",
    "closed_delta_rows": "0",
    "v53_required_artifact_rows": "81",
    "v61_required_artifact_rows": "10",
    "dual_required_artifact_rows": "91",
    "missing_external_return_artifacts": "91",
    "open_closure_blocker_rows": "11",
    "command_rows": "7",
    "ready_command_rows": "3",
    "ledger_file_rows": "11",
    "metadata_only_ledger_file_rows": "11",
    "missing_human_review_rows": "7000",
    "missing_adjudication_rows": "1000",
    "missing_reviewer_identity_rows": "21",
    "missing_conflict_disclosure_rows": "210",
    "missing_generation_result_artifacts": "5",
    "missing_generation_result_rows": "1000",
    "missing_generation_execution_admission_rows": "1000",
    "missing_final_acceptance_rows": "1000",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fd": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fd {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fc_real_return_closure_delta_rows.csv",
    "post_fc_real_return_closure_blocker_rows.csv",
    "post_fc_real_return_closure_command_rows.csv",
    "post_fc_real_return_closure_invariant_rows.csv",
    "V61FD_POST_FC_REAL_RETURN_CLOSURE_DELTA_LEDGER_BOUNDARY.md",
    "v61fd_post_fc_real_return_closure_delta_ledger_manifest.json",
    "real_return_closure_delta_ledger/REAL_RETURN_CLOSURE_DELTA_ROWS.csv",
    "real_return_closure_delta_ledger/REAL_RETURN_CLOSURE_BLOCKER_ROWS.csv",
    "real_return_closure_delta_ledger/REAL_RETURN_CLOSURE_COMMAND_ROWS.csv",
    "real_return_closure_delta_ledger/REAL_RETURN_CLOSURE_INVARIANTS.csv",
    "real_return_closure_delta_ledger/REAL_RETURN_CLOSURE_FRONTIER.json",
    "real_return_closure_delta_ledger/REAL_RETURN_CLOSURE_DELTA_LEDGER.md",
    "real_return_closure_delta_ledger/REAL_RETURN_REPLAY_ENV_TEMPLATE.sh",
    "real_return_closure_delta_ledger/READY_NOW_COMMANDS.sh",
    "real_return_closure_delta_ledger/VERIFY_DELTA_LEDGER.sh",
    "real_return_closure_delta_ledger/DELTA_MANIFEST.json",
    "real_return_closure_delta_ledger/DELTA_FILE_LIST.txt",
    "real_return_closure_delta_ledger/DELTA_SHA256SUMS.txt",
    "source_v61fc/dual_external_return_required_artifact_rows.csv",
    "source_v61ex/generation_acceptance_closure_blocker_rows.csv",
    "source_v53/v53s_complete_source_review_return_intake_summary.csv",
    "source_v61_acceptance/v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fd artifact: {rel}")

delta_rows = read_csv(run_dir / "post_fc_real_return_closure_delta_rows.csv")
if len(delta_rows) != 14:
    raise SystemExit("v61fd delta row count mismatch")
if sum(row["status"] == "open" for row in delta_rows) != 14:
    raise SystemExit("v61fd all deltas should remain open in canonical path")
missing_by_id = {row["delta_id"]: row["missing_count"] for row in delta_rows}
expected_missing = {
    "01-v53-external-return-artifacts": "81",
    "02-v61-generation-intake-artifacts": "10",
    "03-v53-human-review-rows": "7000",
    "04-v53-adjudication-rows": "1000",
    "09-v61-generation-result-artifacts": "5",
    "10-v61-generation-result-rows": "1000",
    "11-v61-generation-execution-admission": "1000",
    "12-v61-final-result-acceptance": "1000",
    "13-dual-real-return-roots": "2",
    "14-actual-generation-claim": "1",
}
for key, value in expected_missing.items():
    if missing_by_id.get(key) != value:
        raise SystemExit(f"v61fd {key} missing_count expected {value}, got {missing_by_id.get(key)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61fc-ready", "source-v61ex-ready", "delta-ledger-shape", "ledger-packet", "repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fd expected pass decision: {gate}")
for gate in ["dual-external-return-real", "v53-review-return", "v61-generation-result-return", "generation-acceptance-closure", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fd expected blocked decision: {gate}")

frontier = json.loads((ledger_dir / "REAL_RETURN_CLOSURE_FRONTIER.json").read_text(encoding="utf-8"))
if frontier.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fd frontier must keep actual generation blocked")
if frontier.get("missing_generation_result_rows") != 1000:
    raise SystemExit("v61fd frontier generation row delta mismatch")

boundary = (run_dir / "V61FD_POST_FC_REAL_RETURN_CLOSURE_DELTA_LEDGER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "open_delta_rows=14",
    "missing_external_return_artifacts=91",
    "missing_human_review_rows=7000",
    "missing_generation_result_rows=1000",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fd boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fd sha256 mismatch: {rel}")
PY

"$LEDGER_DIR/VERIFY_DELTA_LEDGER.sh" >/dev/null
"$LEDGER_DIR/READY_NOW_COMMANDS.sh" >/dev/null

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fd produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fd post-fc real return closure delta ledger smoke passed"
