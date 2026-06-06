#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v13_resource_envelope"
BINDER_PREFIX="v13_real_run_binder_manifest"
ROUTEQA_PREFIX="v13_public_codebase_routeqa"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_resource_envelope_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  ROUTEQA_PREFIX="v13_public_codebase_routeqa_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_resource_envelope_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  ROUTEQA_PREFIX="v13_public_codebase_routeqa_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_RESOURCE_ENVELOPE_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_RESOURCE_ENVELOPE_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

RESOURCE_PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ROUTEQA_SUMMARY_CSV="$RESULTS_DIR/${ROUTEQA_PREFIX}_summary.csv"
ROUTEQA_PACKET_DIR="$RESULTS_DIR/${ROUTEQA_PREFIX}_packet/$RUN_ID"

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  "$ROOT_DIR/experiments/run_v13_public_codebase_routeqa.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V13_PUBLIC_CODEBASE_ROUTEQA_RUN_DIR="$RUN_DIR" \
    "$ROOT_DIR/experiments/run_v13_public_codebase_routeqa.sh" "${RUN_ARGS[@]}" >/dev/null
fi

python3 - "$RUN_DIR" "$RUN_SOURCE" "$RESOURCE_PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ROUTEQA_SUMMARY_CSV" "$ROUTEQA_PACKET_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

run_dir = Path(sys.argv[1])
run_source = sys.argv[2]
packet_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
routeqa_summary_csv = Path(sys.argv[6])
routeqa_packet_dir = Path(sys.argv[7])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def verify_manifest(base_dir):
    manifest = base_dir / "sha256sums.txt"
    entries = 0
    verified = 0
    if not manifest.is_file():
        return entries, verified
    with manifest.open(encoding="utf-8") as handle:
        for line in handle:
            if "  " not in line:
                continue
            expected, rel = line.rstrip("\n").split("  ", 1)
            entries += 1
            path = base_dir / rel
            if path.is_file() and sha256(path) == expected:
                verified += 1
    return entries, verified

def read_csv(path):
    if not path.is_file():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def first_row(path):
    rows = read_csv(path)
    return rows[0] if rows else {}

def as_int(row, field, default=0):
    try:
        return int(float(row.get(field, default) or default))
    except ValueError:
        return default

def as_float(row, field, default=0.0):
    try:
        return float(row.get(field, default) or default)
    except ValueError:
        return default

def file_uri_to_path(uri):
    if not uri.startswith("file://"):
        return None
    return Path(unquote(uri[7:]))

def hash_matches(uri, expected):
    path = file_uri_to_path(uri)
    if not path or not path.is_file() or not expected.startswith("sha256:"):
        return 0
    return int("sha256:" + sha256(path) == expected)

run_hash_entries, run_hash_verified = verify_manifest(run_dir)
run_hash_manifest_ready = int(run_hash_entries > 0 and run_hash_entries == run_hash_verified)

routeqa = first_row(routeqa_summary_csv)
public_codebase_routeqa_ready = as_int(routeqa, "public_codebase_routeqa_ready")
routeqa_packet_hash_entries, routeqa_packet_hash_verified = verify_manifest(routeqa_packet_dir)
routeqa_packet_hash_ready = int(routeqa_packet_hash_entries > 0 and routeqa_packet_hash_entries == routeqa_packet_hash_verified)

h9h = first_row(run_dir / "evidence" / "h9h.csv")
h11d = first_row(run_dir / "evidence" / "h11d.csv")
v13_manifest = first_row(run_dir / "evidence" / "v13_run_manifest.csv")
workload_rows = read_csv(run_dir / "speed" / "workload.csv")
run_nlg_result = run_dir / "nlg" / "result_summary.json"

resource_rows = []
nlg_result_hash_verified_rows = 0
timing_artifact_hash_verified_rows = 0
environment_hash_verified_rows = 0
workload_artifact_rows = 0
run_nlg_result_hash_match_rows = 0
workload_ready_rows = 0
metrics_positive_rows = 0
speedup_positive_rows = 0
measurement_source_fixture_rows = 0
real_hip_measurement_rows = 0
real_nvme_measurement_rows = 0
non_fixture_workload_rows = 0
benchmark_or_product_trace_verified_rows = 0
routing_sum = 0.0
jump_sum = 0.0

cpu_sum = hip_sum = nvme_sum = qe_sum = qft_sum = tps_sum = ssd_sum = ram_sum = vram_sum = 0.0
max_speedup = 0.0

for row in workload_rows:
    cpu = as_float(row, "cpu_median_ms")
    hip = as_float(row, "hip_median_ms")
    nvme = as_float(row, "nvme_read_median_ms")
    qe = as_float(row, "query_to_evidence_ms")
    qft = as_float(row, "query_to_first_token_ms")
    tps = as_float(row, "tokens_per_second_after_retrieval")
    ssd = as_float(row, "ssd_bytes_per_query")
    ram = as_float(row, "ram_used_gb")
    vram = as_float(row, "vram_used_gb")
    warmup = as_int(row, "warmup_runs")
    measured = as_int(row, "measured_runs")
    speedup = cpu / hip if cpu > 0 and hip > 0 else 0.0
    max_speedup = max(max_speedup, speedup)

    nlg_ok = hash_matches(row.get("nlg_result_uri", ""), row.get("nlg_result_hash", ""))
    timing_ok = hash_matches(row.get("timing_artifact_uri", ""), row.get("timing_artifact_hash", ""))
    env_ok = hash_matches(row.get("environment_uri", ""), row.get("environment_hash", ""))
    nlg_result_hash_verified_rows += nlg_ok
    timing_artifact_hash_verified_rows += timing_ok
    environment_hash_verified_rows += env_ok
    workload_artifact_rows += int(nlg_ok == 1 and timing_ok == 1 and env_ok == 1)

    run_nlg_hash_match = 0
    if run_nlg_result.is_file() and row.get("nlg_result_hash", "").startswith("sha256:"):
        run_nlg_hash_match = int("sha256:" + sha256(run_nlg_result) == row.get("nlg_result_hash"))
    run_nlg_result_hash_match_rows += run_nlg_hash_match

    ready = int(
        row.get("workload_ready") == "1"
        and row.get("workload_family") == "pc-routelm-nlg"
        and row.get("route_memory_residency") == "nvme"
        and warmup >= 1
        and measured >= 3
    )
    workload_ready_rows += ready
    metrics_positive = int(cpu > 0 and hip > 0 and nvme > 0 and qe > 0 and qft > 0 and tps > 0 and ssd > 0 and ram > 0 and vram >= 0)
    metrics_positive_rows += metrics_positive
    speedup_positive_rows += int(speedup > 1.0)
    measurement_source_fixture_rows += int(row.get("measurement_source") == "fixture")
    real_hip_measurement_rows += int(row.get("real_hip_measurement") == "1")
    real_nvme_measurement_rows += int(row.get("real_nvme_measurement") == "1")
    non_fixture_workload_rows += int(row.get("non_fixture_workload") == "1")
    benchmark_or_product_trace_verified_rows += int(row.get("benchmark_or_product_trace_verified") == "1")
    routing_sum += as_float(row, "routing_trigger_rate")
    jump_sum += as_float(row, "active_jump_rate")

    cpu_sum += cpu
    hip_sum += hip
    nvme_sum += nvme
    qe_sum += qe
    qft_sum += qft
    tps_sum += tps
    ssd_sum += ssd
    ram_sum += ram
    vram_sum += vram

    resource_rows.append({
        "workload_id": row.get("workload_id", ""),
        "workload_family": row.get("workload_family", ""),
        "route_memory_residency": row.get("route_memory_residency", ""),
        "measurement_source": row.get("measurement_source", ""),
        "cpu_median_ms": f"{cpu:.6f}",
        "hip_median_ms": f"{hip:.6f}",
        "median_speedup": f"{speedup:.6f}",
        "nvme_read_median_ms": f"{nvme:.6f}",
        "query_to_evidence_ms": f"{qe:.6f}",
        "query_to_first_token_ms": f"{qft:.6f}",
        "tokens_per_second_after_retrieval": f"{tps:.6f}",
        "ssd_bytes_per_query": f"{ssd:.6f}",
        "ram_used_gb": f"{ram:.6f}",
        "vram_used_gb": f"{vram:.6f}",
        "nlg_result_hash_verified": nlg_ok,
        "timing_artifact_hash_verified": timing_ok,
        "environment_hash_verified": env_ok,
        "run_nlg_result_hash_match": run_nlg_hash_match,
        "workload_ready": ready,
        "metrics_positive": metrics_positive,
        "speedup_positive": int(speedup > 1.0),
        "real_hip_measurement": as_int(row, "real_hip_measurement"),
        "real_nvme_measurement": as_int(row, "real_nvme_measurement"),
        "non_fixture_workload": as_int(row, "non_fixture_workload"),
        "benchmark_or_product_trace_verified": as_int(row, "benchmark_or_product_trace_verified"),
        "routing_trigger_rate": f"{as_float(row, 'routing_trigger_rate'):.6f}",
        "active_jump_rate": f"{as_float(row, 'active_jump_rate'):.6f}",
    })

count = len(workload_rows)
avg = lambda total: total / count if count else 0.0

h9h_diagnostic_workload_speed_ready = as_int(h9h, "diagnostic_workload_speed_ready")
h9h_real_workload_speed_evidence_ready = as_int(h9h, "real_workload_speed_evidence_ready")
h9h_gpu_speedup_claim = h9h.get("gpu_speedup_claim", "deferred") or "deferred"
h11d_real_pc_routelm_nlg_verified = as_int(h11d, "real_pc_routelm_nlg_verified")

diagnostic_resource_envelope_ready = int(
    run_hash_manifest_ready == 1
    and public_codebase_routeqa_ready == 1
    and routeqa_packet_hash_ready == 1
    and count > 0
    and workload_artifact_rows == count
    and nlg_result_hash_verified_rows == count
    and timing_artifact_hash_verified_rows == count
    and environment_hash_verified_rows == count
    and run_nlg_result_hash_match_rows == count
    and workload_ready_rows == count
    and metrics_positive_rows == count
    and speedup_positive_rows == count
    and h9h_diagnostic_workload_speed_ready == 1
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
real_workload_speed_evidence_ready = int(
    diagnostic_resource_envelope_ready == 1
    and h9h_real_workload_speed_evidence_ready == 1
    and h11d_real_pc_routelm_nlg_verified == 1
    and real_hip_measurement_rows == count
    and real_nvme_measurement_rows == count
    and non_fixture_workload_rows == count
    and benchmark_or_product_trace_verified_rows == count
)
gpu_speedup_claim = "measured-pc-routelm-workload-candidate" if real_workload_speed_evidence_ready else "deferred"
actual_nonfixture = 0 if v13_manifest.get("fixture_or_generated_declared", "1") == "1" else 1

action = "v13-resource-envelope-bound-await-real-measurements"
if run_hash_manifest_ready != 1:
    action = "v13-resource-envelope-run-hash-mismatch"
elif public_codebase_routeqa_ready != 1 or routeqa_packet_hash_ready != 1:
    action = "v13-resource-envelope-routeqa-not-ready"
elif count <= 0:
    action = "v13-resource-envelope-workload-rows-missing"
elif workload_artifact_rows != count:
    action = "v13-resource-envelope-artifact-hash-mismatch"
elif run_nlg_result_hash_match_rows != count:
    action = "v13-resource-envelope-run-nlg-hash-mismatch"
elif workload_ready_rows != count or metrics_positive_rows != count:
    action = "v13-resource-envelope-workload-contract-incomplete"
elif speedup_positive_rows != count:
    action = "v13-resource-envelope-speedup-not-demonstrated"
elif h9h_diagnostic_workload_speed_ready != 1:
    action = "v13-resource-envelope-h9h-not-ready"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-resource-envelope-jump-guardrail-active"
elif real_workload_speed_evidence_ready == 1:
    action = "v13-resource-envelope-real-speed-ready"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

rows_csv = packet_dir / "resource_rows.csv"
fieldnames = [
    "workload_id",
    "workload_family",
    "route_memory_residency",
    "measurement_source",
    "cpu_median_ms",
    "hip_median_ms",
    "median_speedup",
    "nvme_read_median_ms",
    "query_to_evidence_ms",
    "query_to_first_token_ms",
    "tokens_per_second_after_retrieval",
    "ssd_bytes_per_query",
    "ram_used_gb",
    "vram_used_gb",
    "nlg_result_hash_verified",
    "timing_artifact_hash_verified",
    "environment_hash_verified",
    "run_nlg_result_hash_match",
    "workload_ready",
    "metrics_positive",
    "speedup_positive",
    "real_hip_measurement",
    "real_nvme_measurement",
    "non_fixture_workload",
    "benchmark_or_product_trace_verified",
    "routing_trigger_rate",
    "active_jump_rate",
]
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(resource_rows)

manifest = {
    "artifact_scope": "v13-f-resource-envelope",
    "run_source": run_source,
    "run_dir": str(run_dir),
    "routeqa_packet_dir": str(routeqa_packet_dir),
    "workload_csv": "speed/workload.csv",
    "resource_rows": len(resource_rows),
    "claim": "binds workload/resource rows to the v13 run; diagnostic envelope only until real HIP/NVMe/nonfixture measurements exist",
}
(packet_dir / "resource_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

resource_packet_hash_entries, resource_packet_hash_verified = verify_manifest(packet_dir)
resource_packet_hash_ready = int(resource_packet_hash_entries > 0 and resource_packet_hash_entries == resource_packet_hash_verified)
resource_envelope_ready = int(diagnostic_resource_envelope_ready == 1 and resource_packet_hash_ready == 1)

summary_fields = [
    "resource_scope",
    "run_source",
    "run_id",
    "run_dir",
    "resource_packet_dir",
    "routeqa_packet_dir",
    "run_hash_entries",
    "run_hash_verified",
    "run_hash_manifest_ready",
    "routeqa_packet_hash_entries",
    "routeqa_packet_hash_verified",
    "routeqa_packet_hash_ready",
    "public_codebase_routeqa_ready",
    "workload_rows",
    "resource_rows",
    "workload_artifact_rows",
    "nlg_result_hash_verified_rows",
    "timing_artifact_hash_verified_rows",
    "environment_hash_verified_rows",
    "run_nlg_result_hash_match_rows",
    "workload_ready_rows",
    "metrics_positive_rows",
    "speedup_positive_rows",
    "measurement_source_fixture_rows",
    "real_hip_measurement_rows",
    "real_nvme_measurement_rows",
    "non_fixture_workload_rows",
    "benchmark_or_product_trace_verified_rows",
    "cpu_median_ms",
    "hip_median_ms",
    "median_speedup",
    "nvme_read_median_ms",
    "query_to_evidence_ms",
    "query_to_first_token_ms",
    "tokens_per_second_after_retrieval",
    "ssd_bytes_per_query",
    "ram_used_gb",
    "vram_used_gb",
    "h9h_diagnostic_workload_speed_ready",
    "h9h_real_workload_speed_evidence_ready",
    "h11d_real_pc_routelm_nlg_verified",
    "resource_packet_hash_entries",
    "resource_packet_hash_verified",
    "resource_packet_hash_ready",
    "diagnostic_resource_envelope_ready",
    "resource_envelope_ready",
    "actual_nonfixture_run_verified",
    "real_workload_speed_evidence_ready",
    "gpu_speedup_claim",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "resource_scope": "v13-f-resource-envelope",
    "run_source": run_source,
    "run_id": run_dir.name,
    "run_dir": str(run_dir),
    "resource_packet_dir": str(packet_dir),
    "routeqa_packet_dir": str(routeqa_packet_dir),
    "run_hash_entries": run_hash_entries,
    "run_hash_verified": run_hash_verified,
    "run_hash_manifest_ready": run_hash_manifest_ready,
    "routeqa_packet_hash_entries": routeqa_packet_hash_entries,
    "routeqa_packet_hash_verified": routeqa_packet_hash_verified,
    "routeqa_packet_hash_ready": routeqa_packet_hash_ready,
    "public_codebase_routeqa_ready": public_codebase_routeqa_ready,
    "workload_rows": count,
    "resource_rows": len(resource_rows),
    "workload_artifact_rows": workload_artifact_rows,
    "nlg_result_hash_verified_rows": nlg_result_hash_verified_rows,
    "timing_artifact_hash_verified_rows": timing_artifact_hash_verified_rows,
    "environment_hash_verified_rows": environment_hash_verified_rows,
    "run_nlg_result_hash_match_rows": run_nlg_result_hash_match_rows,
    "workload_ready_rows": workload_ready_rows,
    "metrics_positive_rows": metrics_positive_rows,
    "speedup_positive_rows": speedup_positive_rows,
    "measurement_source_fixture_rows": measurement_source_fixture_rows,
    "real_hip_measurement_rows": real_hip_measurement_rows,
    "real_nvme_measurement_rows": real_nvme_measurement_rows,
    "non_fixture_workload_rows": non_fixture_workload_rows,
    "benchmark_or_product_trace_verified_rows": benchmark_or_product_trace_verified_rows,
    "cpu_median_ms": f"{avg(cpu_sum):.6f}",
    "hip_median_ms": f"{avg(hip_sum):.6f}",
    "median_speedup": f"{max_speedup:.6f}",
    "nvme_read_median_ms": f"{avg(nvme_sum):.6f}",
    "query_to_evidence_ms": f"{avg(qe_sum):.6f}",
    "query_to_first_token_ms": f"{avg(qft_sum):.6f}",
    "tokens_per_second_after_retrieval": f"{avg(tps_sum):.6f}",
    "ssd_bytes_per_query": f"{avg(ssd_sum):.6f}",
    "ram_used_gb": f"{avg(ram_sum):.6f}",
    "vram_used_gb": f"{avg(vram_sum):.6f}",
    "h9h_diagnostic_workload_speed_ready": h9h_diagnostic_workload_speed_ready,
    "h9h_real_workload_speed_evidence_ready": h9h_real_workload_speed_evidence_ready,
    "h11d_real_pc_routelm_nlg_verified": h11d_real_pc_routelm_nlg_verified,
    "resource_packet_hash_entries": resource_packet_hash_entries,
    "resource_packet_hash_verified": resource_packet_hash_verified,
    "resource_packet_hash_ready": resource_packet_hash_ready,
    "diagnostic_resource_envelope_ready": diagnostic_resource_envelope_ready,
    "resource_envelope_ready": resource_envelope_ready,
    "actual_nonfixture_run_verified": actual_nonfixture if resource_envelope_ready and actual_nonfixture else 0,
    "real_workload_speed_evidence_ready": real_workload_speed_evidence_ready,
    "gpu_speedup_claim": gpu_speedup_claim,
    "real_release_package_ready": 0,
    "action": action,
    "routing_trigger_rate": f"{routing_sum:.6f}",
    "active_jump_rate": f"{jump_sum:.6f}",
}
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=summary_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary_row)

def status(condition):
    return "pass" if condition else "blocked"

decision_rows = [
    ("run-hash-manifest", status(run_hash_manifest_ready == 1), f"verified={run_hash_verified}/{run_hash_entries}"),
    ("routeqa-chain", status(public_codebase_routeqa_ready == 1 and routeqa_packet_hash_ready == 1), f"ready={public_codebase_routeqa_ready} hash={routeqa_packet_hash_verified}/{routeqa_packet_hash_entries}"),
    ("workload-artifact-hashes", status(workload_artifact_rows == count and count > 0), f"artifact_rows={workload_artifact_rows}/{count}"),
    ("run-nlg-result-binding", status(run_nlg_result_hash_match_rows == count and count > 0), f"run_nlg={run_nlg_result_hash_match_rows}/{count}"),
    ("workload-contract", status(workload_ready_rows == count and metrics_positive_rows == count and count > 0), f"ready={workload_ready_rows}/{count} metrics={metrics_positive_rows}/{count}"),
    ("diagnostic-speed-envelope", status(speedup_positive_rows == count and h9h_diagnostic_workload_speed_ready == 1 and count > 0), f"speedup={speedup_positive_rows}/{count} h9h={h9h_diagnostic_workload_speed_ready} median={max_speedup:.6f}"),
    ("real-measurement-source", status(real_workload_speed_evidence_ready == 1), f"real_hip={real_hip_measurement_rows}/{count} real_nvme={real_nvme_measurement_rows}/{count} nonfixture={non_fixture_workload_rows}/{count} trace={benchmark_or_product_trace_verified_rows}/{count}"),
    ("resource-packet-hash", status(resource_packet_hash_ready == 1), f"verified={resource_packet_hash_verified}/{resource_packet_hash_entries}"),
    ("v13-resource-envelope", status(resource_envelope_ready == 1), f"ready={resource_envelope_ready} action={action}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "resource_packet_dir: $RESOURCE_PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
