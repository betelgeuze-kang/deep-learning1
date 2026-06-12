#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ax_async_io_backend_selection_gate"
RUN_ID="${V61AX_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AX_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ax_async_io_backend_selection_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AW_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61aw_io_uring_registered_buffer_preflight.sh" >/dev/null

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


v61av_dir = results / "v61av_async_prefetch_execution_probe" / "probe_001"
v61aw_dir = results / "v61aw_io_uring_registered_buffer_preflight" / "preflight_001"
v61av_summary = read_csv(results / "v61av_async_prefetch_execution_probe_summary.csv")[0]
v61aw_summary = read_csv(results / "v61aw_io_uring_registered_buffer_preflight_summary.csv")[0]

if v61av_summary.get("actual_async_prefetch_execution_ready") != "1":
    raise SystemExit("v61ax requires v61av actual_async_prefetch_execution_ready=1")
if v61aw_summary.get("v61aw_io_uring_registered_buffer_preflight_ready") != "1":
    raise SystemExit("v61ax requires v61aw_io_uring_registered_buffer_preflight_ready=1")
if v61aw_summary.get("threaded_odirect_fallback_ready") != "1":
    raise SystemExit("v61ax requires v61aw threaded_odirect_fallback_ready=1")

for src, rel in [
    (results / "v61av_async_prefetch_execution_probe_summary.csv", "source_v61av/v61av_async_prefetch_execution_probe_summary.csv"),
    (results / "v61av_async_prefetch_execution_probe_decision.csv", "source_v61av/v61av_async_prefetch_execution_probe_decision.csv"),
    (v61av_dir / "async_prefetch_execution_rows.csv", "source_v61av/async_prefetch_execution_rows.csv"),
    (v61av_dir / "async_prefetch_batch_rows.csv", "source_v61av/async_prefetch_batch_rows.csv"),
    (v61av_dir / "async_prefetch_metric_rows.csv", "source_v61av/async_prefetch_metric_rows.csv"),
    (v61av_dir / "sha256_manifest.csv", "source_v61av/sha256_manifest.csv"),
    (results / "v61aw_io_uring_registered_buffer_preflight_summary.csv", "source_v61aw/v61aw_io_uring_registered_buffer_preflight_summary.csv"),
    (results / "v61aw_io_uring_registered_buffer_preflight_decision.csv", "source_v61aw/v61aw_io_uring_registered_buffer_preflight_decision.csv"),
    (v61aw_dir / "io_uring_capability_rows.csv", "source_v61aw/io_uring_capability_rows.csv"),
    (v61aw_dir / "io_uring_setup_probe_rows.csv", "source_v61aw/io_uring_setup_probe_rows.csv"),
    (v61aw_dir / "registered_buffer_preflight_rows.csv", "source_v61aw/registered_buffer_preflight_rows.csv"),
    (v61aw_dir / "io_uring_fallback_binding_rows.csv", "source_v61aw/io_uring_fallback_binding_rows.csv"),
    (v61aw_dir / "io_uring_preflight_metric_rows.csv", "source_v61aw/io_uring_preflight_metric_rows.csv"),
    (v61aw_dir / "sha256_manifest.csv", "source_v61aw/sha256_manifest.csv"),
]:
    copy(src, rel)

io_uring_ready = v61aw_summary["actual_io_uring_execution_ready"]
registered_buffer_ready = v61aw_summary["registered_buffer_prefetch_ready"]
threaded_ready = v61av_summary["actual_async_prefetch_execution_ready"]
io_uring_blocker = v61aw_summary["io_uring_blocker_reason"]
selected_backend = "threaded_odirect" if threaded_ready == "1" and io_uring_ready != "1" else "io_uring_registered_buffer"
selected_backend_ready = "1" if selected_backend == "threaded_odirect" and threaded_ready == "1" else "0"
selected_reason = (
    f"io_uring_registered_buffer_blocked_by_{io_uring_blocker}; threaded_odirect_ready"
    if selected_backend == "threaded_odirect"
    else "io_uring_registered_buffer_ready"
)

candidate_rows = [
    {
        "backend_id": "io_uring_registered_buffer",
        "priority": "1",
        "candidate_status": "ready" if io_uring_ready == "1" and registered_buffer_ready == "1" else "blocked",
        "selectable": "1" if io_uring_ready == "1" and registered_buffer_ready == "1" else "0",
        "actual_async_execution_ready": io_uring_ready,
        "actual_io_uring_execution_ready": io_uring_ready,
        "registered_buffer_prefetch_ready": registered_buffer_ready,
        "configured_prefetch_queue_depth": v61av_summary["configured_prefetch_queue_depth"],
        "hash_match_rows": "0",
        "error_rows": "0",
        "source_artifact": "v61aw_io_uring_registered_buffer_preflight",
        "blocker_reason": io_uring_blocker,
    },
    {
        "backend_id": "threaded_odirect",
        "priority": "2",
        "candidate_status": "ready" if threaded_ready == "1" else "blocked",
        "selectable": "1" if threaded_ready == "1" else "0",
        "actual_async_execution_ready": threaded_ready,
        "actual_io_uring_execution_ready": "0",
        "registered_buffer_prefetch_ready": "0",
        "configured_prefetch_queue_depth": v61av_summary["configured_prefetch_queue_depth"],
        "hash_match_rows": v61av_summary["async_prefetch_hash_match_rows"],
        "error_rows": v61av_summary["async_prefetch_error_rows"],
        "source_artifact": "v61av_async_prefetch_execution_probe",
        "blocker_reason": "none" if threaded_ready == "1" else "v61av-threaded-odirect-not-ready",
    },
]
write_csv(run_dir / "async_io_backend_candidate_rows.csv", list(candidate_rows[0].keys()), candidate_rows)

selection_rows = [
    {
        "selection_id": "v61ax_async_io_backend_selection_0001",
        "selected_backend_id": selected_backend,
        "selected_backend_priority": "2" if selected_backend == "threaded_odirect" else "1",
        "selected_backend_ready": selected_backend_ready,
        "selected_backend_actual_execution_ready": threaded_ready if selected_backend == "threaded_odirect" else io_uring_ready,
        "selected_backend_queue_depth": v61av_summary["configured_prefetch_queue_depth"],
        "selected_backend_hash_match_rows": v61av_summary["async_prefetch_hash_match_rows"] if selected_backend == "threaded_odirect" else "0",
        "selected_backend_error_rows": v61av_summary["async_prefetch_error_rows"] if selected_backend == "threaded_odirect" else "0",
        "selection_reason": selected_reason,
        "io_uring_registered_buffer_candidate_ready": "1" if io_uring_ready == "1" and registered_buffer_ready == "1" else "0",
        "threaded_odirect_candidate_ready": threaded_ready,
        "bootstrap_prefetch_admission_ready": v61av_summary["bootstrap_prefetch_admission_ready"],
        "full_runtime_async_io_admission_ready": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "async_io_backend_selection_rows.csv", list(selection_rows[0].keys()), selection_rows)

policy_rows = [
    {
        "policy_id": "prefer-io-uring-registered-buffer",
        "status": "blocked" if selected_backend != "io_uring_registered_buffer" else "pass",
        "backend_id": "io_uring_registered_buffer",
        "reason": io_uring_blocker if selected_backend != "io_uring_registered_buffer" else "preferred backend ready",
    },
    {
        "policy_id": "fallback-threaded-odirect-when-io-uring-blocked",
        "status": "pass" if selected_backend == "threaded_odirect" and selected_backend_ready == "1" else "blocked",
        "backend_id": "threaded_odirect",
        "reason": selected_reason,
    },
    {
        "policy_id": "keep-production-claim-blocked",
        "status": "blocked",
        "backend_id": selected_backend,
        "reason": "backend selection is not production latency evidence",
    },
]
write_csv(run_dir / "async_io_backend_policy_rows.csv", list(policy_rows[0].keys()), policy_rows)

requirement_rows = [
    {"requirement_id": "v61aw-preflight-input", "status": "pass", "actual": v61aw_summary["v61aw_io_uring_registered_buffer_preflight_ready"], "required": "1", "reason": "io_uring preflight evidence is available"},
    {"requirement_id": "v61av-threaded-odirect-input", "status": "pass", "actual": v61av_summary["actual_async_prefetch_execution_ready"], "required": "1", "reason": "threaded O_DIRECT async execution evidence is available"},
    {"requirement_id": "io-uring-registered-buffer-preferred-backend", "status": "blocked", "actual": registered_buffer_ready, "required": "1", "reason": io_uring_blocker},
    {"requirement_id": "selected-async-io-backend", "status": "pass" if selected_backend_ready == "1" else "blocked", "actual": selected_backend, "required": "ready backend", "reason": selected_reason},
    {"requirement_id": "bootstrap-prefetch-admission", "status": "blocked", "actual": v61av_summary["bootstrap_prefetch_admission_ready"], "required": "1", "reason": "backend selection does not solve bootstrap cold-start"},
    {"requirement_id": "full-runtime-async-io-admission", "status": "blocked", "actual": "0", "required": "1", "reason": "full runtime still requires materialization/full page hash/generation"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61ax does not read or commit checkpoint payload bytes"},
]
write_csv(run_dir / "async_io_backend_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ax_async_io_backend_selection_metrics",
    "model_id": model_id,
    "v61ax_async_io_backend_selection_gate_ready": "1",
    "v61aw_io_uring_registered_buffer_preflight_ready": v61aw_summary["v61aw_io_uring_registered_buffer_preflight_ready"],
    "v61av_async_prefetch_execution_probe_ready": v61av_summary["v61av_async_prefetch_execution_probe_ready"],
    "io_uring_registered_buffer_candidate_ready": "1" if io_uring_ready == "1" and registered_buffer_ready == "1" else "0",
    "threaded_odirect_candidate_ready": threaded_ready,
    "selected_async_io_backend": selected_backend,
    "selected_backend_ready": selected_backend_ready,
    "selected_backend_queue_depth": v61av_summary["configured_prefetch_queue_depth"],
    "selected_backend_hash_match_rows": v61av_summary["async_prefetch_hash_match_rows"] if selected_backend == "threaded_odirect" else "0",
    "selected_backend_error_rows": v61av_summary["async_prefetch_error_rows"] if selected_backend == "threaded_odirect" else "0",
    "steady_state_selected_backend_ready": v61av_summary["steady_state_actual_async_prefetch_ready"] if selected_backend == "threaded_odirect" else "0",
    "bootstrap_prefetch_admission_ready": v61av_summary["bootstrap_prefetch_admission_ready"],
    "actual_io_uring_execution_ready": io_uring_ready,
    "registered_buffer_prefetch_ready": registered_buffer_ready,
    "full_runtime_async_io_admission_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ax": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "async_io_backend_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61aw-io-uring-preflight-input", "ready", "v61aw preflight evidence is bound"),
    ("v61av-threaded-odirect-input", "ready", "v61av execution evidence is bound"),
    ("selected-threaded-odirect-backend", "ready" if selected_backend == "threaded_odirect" and selected_backend_ready == "1" else "blocked", selected_reason),
    ("io-uring-registered-buffer-backend", "blocked" if selected_backend != "io_uring_registered_buffer" else "ready", io_uring_blocker),
    ("registered-buffer-prefetch", "blocked", "registered buffers remain unavailable on this host"),
    ("bootstrap-prefetch-admission", "blocked", "selected backend does not solve bootstrap cold-start"),
    ("full-runtime-async-io-admission", "blocked", "requires full materialization/page-hash/generation gates"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "backend selection is not production latency evidence"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61aw-io-uring-preflight-input", "status": "pass", "reason": "v61aw ready"},
    {"gate": "v61av-threaded-odirect-input", "status": "pass", "reason": "v61av actual async execution ready"},
    {"gate": "selected-async-io-backend", "status": "pass" if selected_backend_ready == "1" else "blocked", "reason": selected_reason},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain zero"},
    {"gate": "io-uring-registered-buffer-backend", "status": "blocked" if selected_backend != "io_uring_registered_buffer" else "pass", "reason": io_uring_blocker},
    {"gate": "registered-buffer-prefetch", "status": "blocked", "reason": "requires successful io_uring setup/register path"},
    {"gate": "bootstrap-prefetch-admission", "status": "blocked", "reason": "backend selection does not solve cold start"},
    {"gate": "full-runtime-async-io-admission", "status": "blocked", "reason": "not a full runtime admission gate"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ax Async-I/O Backend Selection Gate Boundary

This gate consumes v61aw io_uring/registered-buffer preflight evidence and
v61av threaded O_DIRECT async execution evidence, then selects the current-host
async-I/O backend for sampled prefetch execution.

Current selection:

- selected_async_io_backend={selected_backend}
- selected_backend_ready={selected_backend_ready}
- selected_backend_queue_depth={v61av_summary["configured_prefetch_queue_depth"]}
- selected_backend_hash_match_rows={metric["selected_backend_hash_match_rows"]}
- selected_backend_error_rows={metric["selected_backend_error_rows"]}
- io_uring_registered_buffer_candidate_ready={metric["io_uring_registered_buffer_candidate_ready"]}
- actual_io_uring_execution_ready={io_uring_ready}
- registered_buffer_prefetch_ready={registered_buffer_ready}
- io_uring_blocker_reason={io_uring_blocker}
- threaded_odirect_candidate_ready={threaded_ready}
- steady_state_selected_backend_ready={metric["steady_state_selected_backend_ready"]}
- bootstrap_prefetch_admission_ready={metric["bootstrap_prefetch_admission_ready"]}
- full_runtime_async_io_admission_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ax=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: current-host async-I/O backend selection chooses the v61av
threaded O_DIRECT fallback while io_uring registered-buffer prefetch is blocked.

Blocked wording: actual io_uring SQ/CQ submission, registered-buffer prefetch,
bootstrap admission, full runtime admission, actual Mixtral generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61AX_ASYNC_IO_BACKEND_SELECTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ax_async_io_backend_selection_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ax_async_io_backend_selection_gate_ready": 1,
    "source_v61aw_ready": int(v61aw_summary["v61aw_io_uring_registered_buffer_preflight_ready"]),
    "source_v61av_ready": int(v61av_summary["v61av_async_prefetch_execution_probe_ready"]),
    "selected_async_io_backend": selected_backend,
    "selected_backend_ready": int(selected_backend_ready),
    "selected_backend_queue_depth": int(v61av_summary["configured_prefetch_queue_depth"]),
    "selected_backend_hash_match_rows": int(metric["selected_backend_hash_match_rows"]),
    "selected_backend_error_rows": int(metric["selected_backend_error_rows"]),
    "io_uring_registered_buffer_candidate_ready": int(metric["io_uring_registered_buffer_candidate_ready"]),
    "actual_io_uring_execution_ready": int(io_uring_ready),
    "registered_buffer_prefetch_ready": int(registered_buffer_ready),
    "full_runtime_async_io_admission_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ax": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ax_async_io_backend_selection_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61ax_async_io_backend_selection_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
