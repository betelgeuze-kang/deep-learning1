#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fe_post_fd_real_return_replay_admission_guard"
RUN_DIR="$RESULTS_DIR/$PREFIX/guard_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
GUARD_DIR="$RUN_DIR/real_return_replay_admission_guard"

V61FD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fd_post_fc_real_return_closure_delta_ledger.sh" >/dev/null
V61FE_REUSE_EXISTING="${V61FE_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh" >/dev/null
V61FE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$GUARD_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
guard_dir = Path(sys.argv[4])


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
    "v61fe_post_fd_real_return_replay_admission_guard_ready": "1",
    "v61fd_post_fc_real_return_closure_delta_ledger_ready": "1",
    "v61fc_post_fb_dual_external_return_operator_packet_ready": "1",
    "v61fb_post_ey_external_return_readiness_preflight_ready": "1",
    "guard_rows": "10",
    "pass_guard_rows": "2",
    "blocked_guard_rows": "8",
    "chain_rows": "7",
    "ready_chain_rows": "1",
    "guard_file_rows": "9",
    "metadata_only_guard_file_rows": "9",
    "blocked_delta_rows": "14",
    "open_delta_rows": "14",
    "v53_return_root_supplied": "0",
    "v53_return_root_exists": "0",
    "v61_return_root_supplied": "0",
    "v61_return_root_exists": "0",
    "dual_roots_supplied": "0",
    "dual_real_provenance_ready": "0",
    "real_return_replay_admission_ready": "0",
    "dual_external_return_real_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fe": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61fe {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "post_fd_real_return_replay_admission_guard_rows.csv",
    "post_fd_real_return_replay_chain_rows.csv",
    "post_fd_blocked_delta_snapshot_rows.csv",
    "V61FE_POST_FD_REAL_RETURN_REPLAY_ADMISSION_GUARD_BOUNDARY.md",
    "v61fe_post_fd_real_return_replay_admission_guard_manifest.json",
    "real_return_replay_admission_guard/REAL_RETURN_REPLAY_ADMISSION_GUARDS.csv",
    "real_return_replay_admission_guard/REAL_RETURN_REPLAY_CHAIN_ROWS.csv",
    "real_return_replay_admission_guard/BLOCKED_DELTA_SNAPSHOT_ROWS.csv",
    "real_return_replay_admission_guard/RUN_REAL_RETURN_REPLAY_IF_ADMITTED.sh",
    "real_return_replay_admission_guard/REAL_RETURN_REPLAY_ADMISSION_GUARD.md",
    "real_return_replay_admission_guard/VERIFY_REPLAY_ADMISSION_GUARD.sh",
    "real_return_replay_admission_guard/GUARD_MANIFEST.json",
    "real_return_replay_admission_guard/GUARD_FILE_LIST.txt",
    "real_return_replay_admission_guard/GUARD_SHA256SUMS.txt",
    "source_v61fd/post_fc_real_return_closure_delta_rows.csv",
    "source_v61fc/dual_external_return_required_artifact_rows.csv",
    "source_v61fb/v61fb_post_ey_external_return_readiness_preflight_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61fe artifact: {rel}")

guards = {row["guard_id"]: row for row in read_csv(run_dir / "post_fd_real_return_replay_admission_guard_rows.csv")}
for guard in ["01-v61fd-delta-ledger-ready", "02-v61fc-operator-packet-ready"]:
    if guards[guard]["status"] != "pass":
        raise SystemExit(f"v61fe expected pass guard: {guard}")
for guard in ["03-v53-return-root-supplied", "05-v53-real-provenance", "06-v61-return-root-supplied", "08-v61-real-provenance", "09-dual-root-admission", "10-actual-generation-claim"]:
    if guards[guard]["status"] != "blocked":
        raise SystemExit(f"v61fe expected blocked guard: {guard}")

chain_rows = read_csv(run_dir / "post_fd_real_return_replay_chain_rows.csv")
if len(chain_rows) != 7:
    raise SystemExit("v61fe chain row count mismatch")
if sum(row["ready_to_run_now"] == "1" for row in chain_rows) != 1:
    raise SystemExit("v61fe canonical path should have one ready chain row")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61fd-ready", "source-v61fc-ready", "guard-shape", "operator-script", "repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61fe expected pass decision: {gate}")
for gate in ["v53-return-root", "v61-return-root", "real-return-replay-admission", "row-acceptance", "actual-generation"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61fe expected blocked decision: {gate}")

manifest = json.loads((guard_dir / "GUARD_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("real_return_replay_admission_ready") != 0:
    raise SystemExit("v61fe manifest must keep replay admission blocked")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61fe manifest must keep actual generation blocked")

boundary = (run_dir / "V61FE_POST_FD_REAL_RETURN_REPLAY_ADMISSION_GUARD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "real_return_replay_admission_ready=0",
    "open_delta_rows=14",
    "row_acceptance_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61fe boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61fe sha256 mismatch: {rel}")
PY

"$GUARD_DIR/VERIFY_REPLAY_ADMISSION_GUARD.sh" >/dev/null

if "$GUARD_DIR/RUN_REAL_RETURN_REPLAY_IF_ADMITTED.sh" >/tmp/v61fe_should_not_run.out 2>/tmp/v61fe_should_not_run.err; then
  echo "v61fe guarded operator script unexpectedly ran without roots" >&2
  exit 1
fi

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61fe produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61fe post-fd real return replay admission guard smoke passed"
