#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61aw_io_uring_registered_buffer_preflight"
RUN_ID="${V61AW_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AW_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61aw_io_uring_registered_buffer_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AV_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61av_async_prefetch_execution_probe.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import ctypes
import errno
import hashlib
import json
import os
import platform
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
entries = 4
sys_io_uring_setup_x86_64 = 425
sys_io_uring_enter_x86_64 = 426
sys_io_uring_register_x86_64 = 427


class IoSqringOffsets(ctypes.Structure):
    _fields_ = [
        ("head", ctypes.c_uint32),
        ("tail", ctypes.c_uint32),
        ("ring_mask", ctypes.c_uint32),
        ("ring_entries", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("dropped", ctypes.c_uint32),
        ("array", ctypes.c_uint32),
        ("resv1", ctypes.c_uint32),
        ("user_addr", ctypes.c_uint64),
    ]


class IoCqringOffsets(ctypes.Structure):
    _fields_ = [
        ("head", ctypes.c_uint32),
        ("tail", ctypes.c_uint32),
        ("ring_mask", ctypes.c_uint32),
        ("ring_entries", ctypes.c_uint32),
        ("overflow", ctypes.c_uint32),
        ("cqes", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("resv1", ctypes.c_uint32),
        ("user_addr", ctypes.c_uint64),
    ]


class IoUringParams(ctypes.Structure):
    _fields_ = [
        ("sq_entries", ctypes.c_uint32),
        ("cq_entries", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("sq_thread_cpu", ctypes.c_uint32),
        ("sq_thread_idle", ctypes.c_uint32),
        ("features", ctypes.c_uint32),
        ("wq_fd", ctypes.c_uint32),
        ("resv", ctypes.c_uint32 * 3),
        ("sq_off", IoSqringOffsets),
        ("cq_off", IoCqringOffsets),
    ]


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


def read_proc_value(path):
    p = Path(path)
    if not p.exists():
        return "missing"
    try:
        return p.read_text(encoding="utf-8").strip()
    except OSError as exc:
        return f"read-error:{exc.errno}:{exc.strerror}"


v61av_dir = results / "v61av_async_prefetch_execution_probe" / "probe_001"
v61av_summary = read_csv(results / "v61av_async_prefetch_execution_probe_summary.csv")[0]
if v61av_summary.get("v61av_async_prefetch_execution_probe_ready") != "1":
    raise SystemExit("v61aw requires v61av_async_prefetch_execution_probe_ready=1")
if v61av_summary.get("actual_async_prefetch_execution_ready") != "1":
    raise SystemExit("v61aw requires v61av actual_async_prefetch_execution_ready=1")

for src, rel in [
    (results / "v61av_async_prefetch_execution_probe_summary.csv", "source_v61av/v61av_async_prefetch_execution_probe_summary.csv"),
    (results / "v61av_async_prefetch_execution_probe_decision.csv", "source_v61av/v61av_async_prefetch_execution_probe_decision.csv"),
    (v61av_dir / "async_prefetch_execution_rows.csv", "source_v61av/async_prefetch_execution_rows.csv"),
    (v61av_dir / "async_prefetch_batch_rows.csv", "source_v61av/async_prefetch_batch_rows.csv"),
    (v61av_dir / "async_prefetch_requirement_rows.csv", "source_v61av/async_prefetch_requirement_rows.csv"),
    (v61av_dir / "sha256_manifest.csv", "source_v61av/sha256_manifest.csv"),
]:
    copy(src, rel)

linux_header = Path("/usr/include/linux/io_uring.h")
liburing_header = Path("/usr/include/liburing.h")
io_uring_disabled = read_proc_value("/proc/sys/kernel/io_uring_disabled")
io_uring_group = read_proc_value("/proc/sys/kernel/io_uring_group")
kernel_release = platform.release()

params = IoUringParams()
libc = ctypes.CDLL(None, use_errno=True)
ctypes.set_errno(0)
fd = libc.syscall(
    ctypes.c_long(sys_io_uring_setup_x86_64),
    ctypes.c_uint(entries),
    ctypes.byref(params),
)
setup_errno = ctypes.get_errno() if fd < 0 else 0
setup_errno_name = errno.errorcode.get(setup_errno, "OK" if setup_errno == 0 else f"ERRNO_{setup_errno}")
setup_errno_message = os.strerror(setup_errno) if setup_errno else "ok"
setup_ready = int(fd >= 0)
if fd >= 0:
    os.close(fd)

registered_buffer_ready = 0
actual_io_uring_ready = 0
io_uring_blocker_reason = "none" if setup_ready else f"io_uring_setup_errno_{setup_errno}_{setup_errno_name}"

capability_rows = [
    {
        "capability_id": "v61aw_host_io_uring_capability",
        "kernel_release": kernel_release,
        "linux_io_uring_header_path": str(linux_header),
        "linux_io_uring_header_ready": "1" if linux_header.is_file() else "0",
        "liburing_header_path": str(liburing_header),
        "liburing_header_ready": "1" if liburing_header.is_file() else "0",
        "io_uring_disabled_proc_value": io_uring_disabled,
        "io_uring_group_proc_value": io_uring_group,
        "sys_io_uring_setup_number": str(sys_io_uring_setup_x86_64),
        "sys_io_uring_enter_number": str(sys_io_uring_enter_x86_64),
        "sys_io_uring_register_number": str(sys_io_uring_register_x86_64),
        "probe_entries": str(entries),
        "v61av_threaded_odirect_fallback_ready": v61av_summary["actual_async_prefetch_execution_ready"],
    }
]
write_csv(run_dir / "io_uring_capability_rows.csv", list(capability_rows[0].keys()), capability_rows)

setup_rows = [
    {
        "setup_probe_id": "v61aw_io_uring_setup_probe_0001",
        "syscall_number": str(sys_io_uring_setup_x86_64),
        "entries": str(entries),
        "setup_fd": str(fd),
        "setup_errno": str(setup_errno),
        "setup_errno_name": setup_errno_name,
        "setup_errno_message": setup_errno_message,
        "io_uring_setup_ready": str(setup_ready),
        "actual_io_uring_execution_ready": str(actual_io_uring_ready),
        "registered_buffers_ready": str(registered_buffer_ready),
        "blocker_reason": io_uring_blocker_reason,
    }
]
write_csv(run_dir / "io_uring_setup_probe_rows.csv", list(setup_rows[0].keys()), setup_rows)

registered_buffer_rows = [
    {
        "registered_buffer_preflight_id": "v61aw_registered_buffer_preflight_0001",
        "io_uring_register_syscall_number": str(sys_io_uring_register_x86_64),
        "source_prefetch_backend": "v61av-threaded-odirect",
        "source_prefetch_issue_rows": v61av_summary["prefetch_issue_rows"],
        "source_async_prefetch_hash_match_rows": v61av_summary["async_prefetch_hash_match_rows"],
        "registered_buffer_prefetch_ready": str(registered_buffer_ready),
        "registered_buffers_ready": str(registered_buffer_ready),
        "io_uring_setup_ready": str(setup_ready),
        "actual_io_uring_execution_ready": str(actual_io_uring_ready),
        "blocker_reason": "requires-successful-io-uring-setup" if not setup_ready else "not-executed-by-preflight",
    }
]
write_csv(run_dir / "registered_buffer_preflight_rows.csv", list(registered_buffer_rows[0].keys()), registered_buffer_rows)

requirement_rows = [
    {"requirement_id": "v61av-threaded-odirect-fallback-input", "status": "pass", "actual": v61av_summary["actual_async_prefetch_execution_ready"], "required": "1", "reason": "v61av sampled threaded O_DIRECT fallback is ready"},
    {"requirement_id": "linux-io-uring-header", "status": "pass" if linux_header.is_file() else "blocked", "actual": "1" if linux_header.is_file() else "0", "required": "1", "reason": "kernel io_uring UAPI header availability"},
    {"requirement_id": "liburing-header", "status": "blocked" if not liburing_header.is_file() else "pass", "actual": "1" if liburing_header.is_file() else "0", "required": "1", "reason": "liburing development header is not required for raw syscall but blocks liburing-backed runtime"},
    {"requirement_id": "io-uring-setup-syscall", "status": "pass" if setup_ready else "blocked", "actual": setup_errno_name if not setup_ready else "fd-opened", "required": "fd-opened", "reason": "raw io_uring_setup syscall must succeed before SQ/CQ mmap or submission"},
    {"requirement_id": "registered-buffer-prefetch", "status": "blocked", "actual": str(registered_buffer_ready), "required": "1", "reason": "cannot register buffers until io_uring setup succeeds"},
    {"requirement_id": "actual-io-uring-prefetch-execution", "status": "blocked", "actual": str(actual_io_uring_ready), "required": "1", "reason": "io_uring execution remains blocked on this host"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61aw does not read or commit checkpoint payload bytes"},
]
write_csv(run_dir / "io_uring_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

fallback_rows = [
    {
        "fallback_id": "v61aw_threaded_odirect_fallback_binding",
        "source_artifact": "v61av_async_prefetch_execution_probe",
        "prefetch_issue_rows": v61av_summary["prefetch_issue_rows"],
        "async_prefetch_hash_match_rows": v61av_summary["async_prefetch_hash_match_rows"],
        "actual_async_prefetch_execution_ready": v61av_summary["actual_async_prefetch_execution_ready"],
        "actual_io_uring_execution_ready": str(actual_io_uring_ready),
        "registered_buffers_ready": str(registered_buffer_ready),
        "fallback_status": "ready-threaded-odirect-while-io-uring-blocked",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
]
write_csv(run_dir / "io_uring_fallback_binding_rows.csv", list(fallback_rows[0].keys()), fallback_rows)

metric = {
    "metric_id": "v61aw_io_uring_registered_buffer_preflight_metrics",
    "model_id": model_id,
    "v61aw_io_uring_registered_buffer_preflight_ready": "1",
    "v61av_async_prefetch_execution_probe_ready": v61av_summary["v61av_async_prefetch_execution_probe_ready"],
    "v61av_actual_async_prefetch_execution_ready": v61av_summary["actual_async_prefetch_execution_ready"],
    "kernel_release": kernel_release,
    "linux_io_uring_header_ready": "1" if linux_header.is_file() else "0",
    "liburing_header_ready": "1" if liburing_header.is_file() else "0",
    "io_uring_disabled_proc_value": io_uring_disabled,
    "io_uring_group_proc_value": io_uring_group,
    "io_uring_setup_syscall_number": str(sys_io_uring_setup_x86_64),
    "io_uring_enter_syscall_number": str(sys_io_uring_enter_x86_64),
    "io_uring_register_syscall_number": str(sys_io_uring_register_x86_64),
    "io_uring_setup_errno": str(setup_errno),
    "io_uring_setup_errno_name": setup_errno_name,
    "io_uring_setup_ready": str(setup_ready),
    "io_uring_enter_ready": "0",
    "io_uring_register_ready": "0",
    "actual_io_uring_execution_ready": str(actual_io_uring_ready),
    "registered_buffers_ready": str(registered_buffer_ready),
    "registered_buffer_prefetch_ready": str(registered_buffer_ready),
    "threaded_odirect_fallback_ready": v61av_summary["actual_async_prefetch_execution_ready"],
    "io_uring_blocker_reason": io_uring_blocker_reason,
    "checkpoint_payload_bytes_downloaded_by_v61aw": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "io_uring_preflight_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61av-threaded-odirect-fallback-input", "ready", "v61av threaded O_DIRECT async prefetch fallback is bound"),
    ("linux-io-uring-header", "ready" if linux_header.is_file() else "blocked", str(linux_header)),
    ("liburing-header", "ready" if liburing_header.is_file() else "blocked", str(liburing_header)),
    ("io-uring-setup-syscall", "ready" if setup_ready else "blocked", io_uring_blocker_reason),
    ("registered-buffer-prefetch", "blocked", "requires successful io_uring setup"),
    ("actual-io-uring-prefetch-execution", "blocked", "requires successful io_uring setup and SQ/CQ submission"),
    ("full-runtime-admission", "blocked", "io_uring preflight is not full runtime admission"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "io_uring preflight is not production latency"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61av-threaded-odirect-fallback-input", "status": "pass", "reason": "v61av fallback is ready"},
    {"gate": "linux-io-uring-header", "status": "pass" if linux_header.is_file() else "blocked", "reason": str(linux_header)},
    {"gate": "liburing-header", "status": "pass" if liburing_header.is_file() else "blocked", "reason": str(liburing_header)},
    {"gate": "io-uring-setup-syscall", "status": "pass" if setup_ready else "blocked", "reason": io_uring_blocker_reason},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain zero"},
    {"gate": "registered-buffer-prefetch", "status": "blocked", "reason": "requires successful io_uring setup"},
    {"gate": "actual-io-uring-prefetch-execution", "status": "blocked", "reason": "requires successful io_uring setup"},
    {"gate": "full-runtime-admission", "status": "blocked", "reason": "preflight only"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61aw io_uring Registered-Buffer Preflight Boundary

This preflight consumes v61av threaded O_DIRECT async prefetch evidence and
probes whether the current host can open an io_uring instance for the next
prefetch backend.

Current host evidence:

- kernel_release={kernel_release}
- linux_io_uring_header_ready={metric["linux_io_uring_header_ready"]}
- liburing_header_ready={metric["liburing_header_ready"]}
- io_uring_disabled_proc_value={io_uring_disabled}
- io_uring_group_proc_value={io_uring_group}
- io_uring_setup_syscall_number={sys_io_uring_setup_x86_64}
- io_uring_enter_syscall_number={sys_io_uring_enter_x86_64}
- io_uring_register_syscall_number={sys_io_uring_register_x86_64}
- io_uring_setup_errno={setup_errno}
- io_uring_setup_errno_name={setup_errno_name}
- io_uring_setup_ready={setup_ready}
- io_uring_enter_ready=0
- io_uring_register_ready=0
- actual_io_uring_execution_ready={actual_io_uring_ready}
- registered_buffers_ready={registered_buffer_ready}
- registered_buffer_prefetch_ready={registered_buffer_ready}
- threaded_odirect_fallback_ready={v61av_summary["actual_async_prefetch_execution_ready"]}
- io_uring_blocker_reason={io_uring_blocker_reason}
- checkpoint_payload_bytes_downloaded_by_v61aw=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: current-host io_uring/registered-buffer preflight with a
threaded O_DIRECT fallback already proven by v61av.

Blocked wording: io_uring SQ/CQ submission, registered-buffer prefetch, full
runtime admission, actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61AW_IO_URING_REGISTERED_BUFFER_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61aw_io_uring_registered_buffer_preflight",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61aw_io_uring_registered_buffer_preflight_ready": 1,
    "source_v61av_ready": int(v61av_summary["v61av_async_prefetch_execution_probe_ready"]),
    "source_v61av_actual_async_ready": int(v61av_summary["actual_async_prefetch_execution_ready"]),
    "kernel_release": kernel_release,
    "linux_io_uring_header_ready": int(linux_header.is_file()),
    "liburing_header_ready": int(liburing_header.is_file()),
    "io_uring_setup_errno": setup_errno,
    "io_uring_setup_errno_name": setup_errno_name,
    "io_uring_setup_ready": setup_ready,
    "io_uring_enter_syscall_number": sys_io_uring_enter_x86_64,
    "io_uring_register_syscall_number": sys_io_uring_register_x86_64,
    "io_uring_enter_ready": 0,
    "io_uring_register_ready": 0,
    "actual_io_uring_execution_ready": actual_io_uring_ready,
    "registered_buffers_ready": registered_buffer_ready,
    "registered_buffer_prefetch_ready": registered_buffer_ready,
    "threaded_odirect_fallback_ready": int(v61av_summary["actual_async_prefetch_execution_ready"]),
    "checkpoint_payload_bytes_downloaded_by_v61aw": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61aw_io_uring_registered_buffer_preflight_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61aw_io_uring_registered_buffer_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
