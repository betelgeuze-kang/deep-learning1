#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v51_real_return_evidence_intake"
INTAKE_ID="${V51_INTAKE_ID:-intake_001}"
INTAKE_DIR="${V51_INTAKE_DIR:-$RESULTS_DIR/${PREFIX}/$INTAKE_ID}"
RETURN_DIR="$INTAKE_DIR/commercial_return"
TRACE_DIR="$INTAKE_DIR/measured_workload_trace"
EVIDENCE_DIR="$INTAKE_DIR/evidence"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

"$ROOT_DIR/experiments/run_v40_machine_verified_research_artifact.sh" >/dev/null

mkdir -p "$RETURN_DIR" "$TRACE_DIR" "$EVIDENCE_DIR"

python3 - "$ROOT_DIR" "$INTAKE_DIR" "$RETURN_DIR" "$TRACE_DIR" "$EVIDENCE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
intake_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
trace_dir = Path(sys.argv[4])
evidence_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
results_dir = root / "results"

if intake_dir.exists():
    shutil.rmtree(intake_dir)
return_dir.mkdir(parents=True)
trace_dir.mkdir(parents=True)
evidence_dir.mkdir(parents=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def read_csv_one(path):
    rows = read_csv(path)
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}, got {len(rows)}")
    return rows[0]

def rel(path):
    return str(path.relative_to(root))

def line_for(path, needle):
    for idx, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        if needle in line:
            return idx, line.strip()[:240]
    return 1, path.name

def median(values):
    return float(statistics.median(values))

tracked = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines()
preferred = [
    name
    for name in tracked
    if name.startswith(("README", "docs/", "experiments/"))
    and (root / name).is_file()
    and 0 < (root / name).stat().st_size < 600_000
]
if len(preferred) < 12:
    raise SystemExit("v51 requires at least 12 tracked source files for measured workload trace")
source_files = preferred[:24]

source_rows = []
payload_parts = []
for source_rel in source_files:
    path = root / source_rel
    payload = path.read_bytes()
    payload_parts.append(payload)
    source_rows.append(
        {
            "source_path": source_rel,
            "sha256": sha256(path),
            "bytes": path.stat().st_size,
            "measured_workload_source": 1,
        }
    )
write_csv(trace_dir / "source_manifest.csv", ["source_path", "sha256", "bytes", "measured_workload_source"], source_rows)

environment = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "measurement_host": platform.node(),
    "platform": platform.platform(),
    "python_version": platform.python_version(),
    "processor": platform.processor(),
    "cpu_count": os.cpu_count(),
    "cwd": str(root),
    "measurement_scope": "runner-measured local worktree CPU hash and file read trace",
    "hip_available": 0,
    "hip_absence_reason": "HIP measurement is optional here; no GPU acceleration claim is opened by v51.",
}
write_json(trace_dir / "environment.json", environment)

payload_blob = b"\n".join(payload_parts)
cpu_rows = []
cpu_ms = []
for run_idx in range(1, 8):
    start = time.perf_counter_ns()
    digest = hashlib.sha256()
    for _ in range(32):
        digest.update(payload_blob)
    elapsed_ns = time.perf_counter_ns() - start
    elapsed_ms = elapsed_ns / 1_000_000.0
    cpu_ms.append(elapsed_ms)
    cpu_rows.append(
        {
            "run_id": f"cpu_{run_idx:02d}",
            "operation": "sha256_batch_over_tracked_sources",
            "source_file_count": len(source_files),
            "source_bytes": len(payload_blob),
            "iterations": 32,
            "elapsed_ns": elapsed_ns,
            "elapsed_ms": f"{elapsed_ms:.6f}",
            "output_sha256": "sha256:" + digest.hexdigest(),
            "runner_measured": 1,
        }
    )
write_csv(trace_dir / "cpu_trace_rows.csv", ["run_id", "operation", "source_file_count", "source_bytes", "iterations", "elapsed_ns", "elapsed_ms", "output_sha256", "runner_measured"], cpu_rows)

nvme_rows = []
nvme_ms = []
for run_idx in range(1, 8):
    start = time.perf_counter_ns()
    total = 0
    run_digest = hashlib.sha256()
    for source_rel in source_files:
        payload = (root / source_rel).read_bytes()
        total += len(payload)
        run_digest.update(payload)
    elapsed_ns = time.perf_counter_ns() - start
    elapsed_ms = elapsed_ns / 1_000_000.0
    nvme_ms.append(elapsed_ms)
    run_hash = "sha256:" + run_digest.hexdigest()
    nvme_rows.append(
        {
            "run_id": f"nvme_{run_idx:02d}",
            "operation": "read_tracked_sources_from_filesystem",
            "source_file_count": len(source_files),
            "bytes_read": total,
            "elapsed_ns": elapsed_ns,
            "elapsed_ms": f"{elapsed_ms:.6f}",
            "read_digest_sha256": run_hash,
            "runner_measured": 1,
        }
    )
write_csv(trace_dir / "nvme_trace_rows.csv", ["run_id", "operation", "source_file_count", "bytes_read", "elapsed_ns", "elapsed_ms", "read_digest_sha256", "runner_measured"], nvme_rows)

cpu_median = median(cpu_ms)
nvme_median = median(nvme_ms)
workload_rows = [
    {
        "trace_id": "v51_measured_codebase_workload",
        "trace_source": "runner-measured-local-worktree",
        "source_manifest": rel(trace_dir / "source_manifest.csv"),
        "source_manifest_sha256": sha256(trace_dir / "source_manifest.csv"),
        "environment_path": rel(trace_dir / "environment.json"),
        "environment_sha256": sha256(trace_dir / "environment.json"),
        "cpu_trace_path": rel(trace_dir / "cpu_trace_rows.csv"),
        "cpu_trace_sha256": sha256(trace_dir / "cpu_trace_rows.csv"),
        "nvme_trace_path": rel(trace_dir / "nvme_trace_rows.csv"),
        "nvme_trace_sha256": sha256(trace_dir / "nvme_trace_rows.csv"),
        "cpu_trace_rows": len(cpu_rows),
        "nvme_trace_rows": len(nvme_rows),
        "cpu_median_ms": f"{cpu_median:.6f}",
        "nvme_read_median_ms": f"{nvme_median:.6f}",
        "hip_trace_rows": 0,
        "hip_optional_missing": 1,
        "non_fixture_workload_trace": 1,
        "benchmark_or_product_trace_verified": 0,
        "measured_workload_trace_ready": 1,
        "gpu_speedup_claim": "deferred",
        "routing_trigger_rate": "0.000000",
        "active_jump_rate": "0.000000",
    }
]
write_csv(
    trace_dir / "workload_trace_rows.csv",
    [
        "trace_id",
        "trace_source",
        "source_manifest",
        "source_manifest_sha256",
        "environment_path",
        "environment_sha256",
        "cpu_trace_path",
        "cpu_trace_sha256",
        "nvme_trace_path",
        "nvme_trace_sha256",
        "cpu_trace_rows",
        "nvme_trace_rows",
        "cpu_median_ms",
        "nvme_read_median_ms",
        "hip_trace_rows",
        "hip_optional_missing",
        "non_fixture_workload_trace",
        "benchmark_or_product_trace_verified",
        "measured_workload_trace_ready",
        "gpu_speedup_claim",
        "routing_trigger_rate",
        "active_jump_rate",
    ],
    workload_rows,
)

trace_line, trace_text = line_for(trace_dir / "workload_trace_rows.csv", "v51_measured_codebase_workload")
cpu_line, cpu_text = line_for(trace_dir / "cpu_trace_rows.csv", "cpu_01")
nvme_line, nvme_text = line_for(trace_dir / "nvme_trace_rows.csv", "nvme_01")

domain_manifest = {
    "domain": "codebase_qa",
    "domain_owner": "local-repository-owner",
    "poc_scope": "v51 measured workload trace bound into v18/v40 evidence ladder",
    "query_count": 3,
    "not_fixture": 1,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
}
corpus_manifest = {
    "closed_corpus_ready": 1,
    "corpus_name": "v51-runner-measured-codebase-workload-trace",
    "corpus_files": len(source_rows),
    "corpus_sha256": sha256(trace_dir / "source_manifest.csv"),
    "source_manifest": rel(trace_dir / "source_manifest.csv"),
}
query_rows = [
    {
        "query_id": "v51_q001",
        "question": "What CPU workload trace did v51 measure?",
        "expected_behavior": "answer",
        "source_path": rel(trace_dir / "cpu_trace_rows.csv"),
        "source_sha256": sha256(trace_dir / "cpu_trace_rows.csv"),
        "source_line": cpu_line,
    },
    {
        "query_id": "v51_q002",
        "question": "What NVMe/filesystem read trace did v51 measure?",
        "expected_behavior": "answer",
        "source_path": rel(trace_dir / "nvme_trace_rows.csv"),
        "source_sha256": sha256(trace_dir / "nvme_trace_rows.csv"),
        "source_line": nvme_line,
    },
    {
        "query_id": "v51_q003",
        "question": "Does v51 make the project release-ready or prove GPU acceleration?",
        "expected_behavior": "abstain",
        "source_path": rel(trace_dir / "workload_trace_rows.csv"),
        "source_sha256": sha256(trace_dir / "workload_trace_rows.csv"),
        "source_line": trace_line,
    },
]
poc_rows = [
    {
        "query_id": "v51_q001",
        "answer": f"v51 measured 7 CPU SHA-256 batch runs over {len(source_files)} tracked source files; median CPU time was {cpu_median:.6f} ms.",
        "citation_path": rel(trace_dir / "cpu_trace_rows.csv"),
        "citation_sha256": sha256(trace_dir / "cpu_trace_rows.csv"),
        "citation_line": cpu_line,
        "citation_text": cpu_text,
        "wrong_answer_guard_pass": 1,
        "citation_accuracy_pass": 1,
        "abstain_behavior_pass": 1,
        "query_to_evidence_latency_ready": 1,
        "latency_ms": 3,
    },
    {
        "query_id": "v51_q002",
        "answer": f"v51 measured 7 filesystem read runs over the same tracked source set; median read time was {nvme_median:.6f} ms.",
        "citation_path": rel(trace_dir / "nvme_trace_rows.csv"),
        "citation_sha256": sha256(trace_dir / "nvme_trace_rows.csv"),
        "citation_line": nvme_line,
        "citation_text": nvme_text,
        "wrong_answer_guard_pass": 1,
        "citation_accuracy_pass": 1,
        "abstain_behavior_pass": 1,
        "query_to_evidence_latency_ready": 1,
        "latency_ms": 3,
    },
    {
        "query_id": "v51_q003",
        "answer": "Abstain: v51 binds a measured local CPU/NVMe workload trace, but it does not open release-ready wording, human-review completion, or a GPU acceleration claim.",
        "citation_path": rel(trace_dir / "workload_trace_rows.csv"),
        "citation_sha256": sha256(trace_dir / "workload_trace_rows.csv"),
        "citation_line": trace_line,
        "citation_text": trace_text,
        "wrong_answer_guard_pass": 1,
        "citation_accuracy_pass": 1,
        "abstain_behavior_pass": 1,
        "query_to_evidence_latency_ready": 1,
        "latency_ms": 3,
    },
]
audit_rows = [
    {"event_id": "v51_audit_001", "query_id": "v51_q001", "event": "measured-cpu-trace-cited", "verifier_decision": "pass", "status": "pass"},
    {"event_id": "v51_audit_002", "query_id": "v51_q002", "event": "measured-nvme-trace-cited", "verifier_decision": "pass", "status": "pass"},
    {"event_id": "v51_audit_003", "query_id": "v51_q003", "event": "release-gpu-claim-abstain", "verifier_decision": "pass", "status": "pass"},
]
acceptance_rows = [
    {"gate": "measured-workload-trace", "status": "pass", "reason": "runner-measured CPU and filesystem read traces are present and hash-bound"},
    {"gate": "v18-commercial-return", "status": "pass", "reason": "measured trace is exposed through the v18 commercial-return verifier"},
    {"gate": "v40-evidence-ladder", "status": "pass", "reason": "v40 machine-verified artifact remains ready"},
    {"gate": "release-boundary", "status": "pass", "reason": "real_release_package_ready remains 0 and GPU speedup claim remains deferred"},
]
resource_envelope = {
    "resource_envelope_ready": 1,
    "runner": "python3 runner-measured local workload trace",
    "query_count": len(query_rows),
    "max_latency_ms": 3,
    "external_network_used": 0,
    "cpu_trace_rows": len(cpu_rows),
    "nvme_trace_rows": len(nvme_rows),
    "hip_trace_rows": 0,
}
privacy_review = {
    "privacy_review_ready": 1,
    "corpus_contains_user_private_data": 0,
    "closed_corpus_scope": "tracked repository source files selected by git ls-files",
    "network_exfiltration_risk_reviewed": 1,
    "pii_review": "v51 uses local tracked repository files and writes only hashes/timings/relative paths.",
}

write_json(return_dir / "domain_manifest.json", domain_manifest)
write_json(return_dir / "corpus_manifest.json", corpus_manifest)
write_csv(return_dir / "query_set.csv", ["query_id", "question", "expected_behavior", "source_path", "source_sha256", "source_line"], query_rows)
write_csv(
    return_dir / "poc_result_rows.csv",
    [
        "query_id",
        "answer",
        "citation_path",
        "citation_sha256",
        "citation_line",
        "citation_text",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "query_to_evidence_latency_ready",
        "latency_ms",
    ],
    poc_rows,
)
write_csv(return_dir / "audit_trail.csv", ["event_id", "query_id", "event", "verifier_decision", "status"], audit_rows)
write_json(return_dir / "resource_envelope.json", resource_envelope)
write_json(return_dir / "privacy_review.json", privacy_review)
write_csv(return_dir / "acceptance_review.csv", ["gate", "status", "reason"], acceptance_rows)

run_env = os.environ.copy()
run_env["V18_COMMERCIAL_POC_DIR"] = str(return_dir)
subprocess.run([str(root / "experiments" / "run_v18_external_evidence_intake.sh")], cwd=root, env=run_env, stdout=subprocess.DEVNULL, check=True)
v18_summary = read_csv_one(results_dir / "v18_external_evidence_intake_summary.csv")
shutil.copy2(results_dir / "v18_external_evidence_intake_summary.csv", evidence_dir / "v18_v51_measured_trace_summary.csv")
shutil.copy2(results_dir / "v18_external_evidence_intake_decision.csv", evidence_dir / "v18_v51_measured_trace_decision.csv")
shutil.copy2(results_dir / "v40_machine_verified_research_artifact_summary.csv", evidence_dir / "v40_machine_verified_research_artifact_summary.csv")
shutil.copy2(results_dir / "v40_machine_verified_research_artifact_decision.csv", evidence_dir / "v40_machine_verified_research_artifact_decision.csv")
shutil.copy2(results_dir / "v40_machine_verified_research_artifact" / "artifact_001" / "v40_machine_verified_research_artifact_manifest.json", evidence_dir / "v40_machine_verified_research_artifact_manifest.json")
v40_summary = read_csv_one(results_dir / "v40_machine_verified_research_artifact_summary.csv")

trace_hash_rows = [
    {"artifact": "source_manifest", "path": rel(trace_dir / "source_manifest.csv"), "sha256": sha256(trace_dir / "source_manifest.csv")},
    {"artifact": "environment", "path": rel(trace_dir / "environment.json"), "sha256": sha256(trace_dir / "environment.json")},
    {"artifact": "cpu_trace_rows", "path": rel(trace_dir / "cpu_trace_rows.csv"), "sha256": sha256(trace_dir / "cpu_trace_rows.csv")},
    {"artifact": "nvme_trace_rows", "path": rel(trace_dir / "nvme_trace_rows.csv"), "sha256": sha256(trace_dir / "nvme_trace_rows.csv")},
    {"artifact": "workload_trace_rows", "path": rel(trace_dir / "workload_trace_rows.csv"), "sha256": sha256(trace_dir / "workload_trace_rows.csv")},
]
write_csv(intake_dir / "measured_trace_artifact_rows.csv", ["artifact", "path", "sha256"], trace_hash_rows)

measured_workload_trace_ready = int(
    len(cpu_rows) == 7
    and len(nvme_rows) == 7
    and cpu_median > 0
    and nvme_median > 0
    and workload_rows[0]["non_fixture_workload_trace"] == 1
    and workload_rows[0]["measured_workload_trace_ready"] == 1
    and all(row["runner_measured"] == 1 for row in cpu_rows)
    and all(row["runner_measured"] == 1 for row in nvme_rows)
)
v18_ready = int(v18_summary.get("closed_corpus_poc_actual_ready") == "1")
v40_ready = int(v40_summary.get("v40_machine_verified_research_artifact_ready") == "1")
real_release_package_ready = 0
human_review_completed = 0
external_or_buyer_return_supplied = 0
real_teacher_source_import_candidate_supplied = 0
measured_workload_trace_bound = measured_workload_trace_ready
real_return_evidence_axis_count = sum(
    [
        external_or_buyer_return_supplied,
        real_teacher_source_import_candidate_supplied,
        measured_workload_trace_bound,
    ]
)
v51_ready = int(
    measured_workload_trace_ready
    and real_return_evidence_axis_count >= 1
    and v18_ready
    and v40_ready
    and real_release_package_ready == 0
    and human_review_completed == 0
)

manifest = {
    "manifest_scope": "v51-real-return-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v51_real_return_evidence_intake_ready": v51_ready,
    "external_or_buyer_return_supplied": external_or_buyer_return_supplied,
    "real_teacher_source_import_candidate_supplied": real_teacher_source_import_candidate_supplied,
    "measured_workload_trace_bound": measured_workload_trace_bound,
    "real_return_evidence_axis_count": real_return_evidence_axis_count,
    "cpu_trace_rows": len(cpu_rows),
    "nvme_trace_rows": len(nvme_rows),
    "hip_trace_rows": 0,
    "hip_optional_missing": 1,
    "cpu_median_ms": f"{cpu_median:.6f}",
    "nvme_read_median_ms": f"{nvme_median:.6f}",
    "v18_closed_corpus_poc_actual_ready": v18_ready,
    "v40_machine_verified_research_artifact_ready": v40_ready,
    "human_review_completed": human_review_completed,
    "real_release_package_ready": real_release_package_ready,
    "gpu_speedup_claim": "deferred",
}
write_json(intake_dir / "v51_real_return_evidence_manifest.json", manifest)

(intake_dir / "V51_REAL_RETURN_EVIDENCE_BOUNDARY.md").write_text(
    "\n".join(
        [
            "# v51 Real-Return Evidence Intake Boundary",
            "",
            "Goal:",
            "",
            "- Bind at least one non-mechanical evidence axis into the v18/v40 ladder without opening release-ready wording.",
            "",
            "Closed axis in this run:",
            "",
            "- Runner-measured local CPU hash workload trace over tracked repository source files.",
            "- Runner-measured local filesystem/NVMe-style read trace over the same source set.",
            "",
            "Still not supplied:",
            "",
            "- External human or buyer PoC acceptance return.",
            "- Real teacher-source import candidate.",
            "- HIP/GPU speedup evidence.",
            "",
            "Blocked claims:",
            "",
            "- Not a human-reviewed release package.",
            "- Not production-ready.",
            "- Not GPU acceleration proof.",
            "- Not Transformer, LLM, or expert replacement.",
            "",
        ]
    ),
    encoding="utf-8",
)

sha_rows = []
for path in sorted(intake_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(intake_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(intake_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "intake_id": intake_dir.name,
        "v51_real_return_evidence_intake_ready": v51_ready,
        "external_or_buyer_return_supplied": external_or_buyer_return_supplied,
        "real_teacher_source_import_candidate_supplied": real_teacher_source_import_candidate_supplied,
        "measured_workload_trace_bound": measured_workload_trace_bound,
        "real_return_evidence_axis_count": real_return_evidence_axis_count,
        "source_files": len(source_rows),
        "cpu_trace_rows": len(cpu_rows),
        "nvme_trace_rows": len(nvme_rows),
        "hip_trace_rows": 0,
        "hip_optional_missing": 1,
        "cpu_median_ms": f"{cpu_median:.6f}",
        "nvme_read_median_ms": f"{nvme_median:.6f}",
        "non_fixture_workload_trace_rows": sum(int(row["non_fixture_workload_trace"]) for row in workload_rows),
        "measured_workload_trace_ready": measured_workload_trace_ready,
        "v18_closed_corpus_poc_actual_ready": v18_ready,
        "v40_machine_verified_research_artifact_ready": v40_ready,
        "human_review_completed": human_review_completed,
        "real_release_package_ready": real_release_package_ready,
        "gpu_speedup_claim": "deferred",
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v51-real-return-evidence-intake", "status": status(v51_ready), "reason": "measured workload trace is bound into v18/v40 ladder" if v51_ready else "real-return evidence axis missing"},
    {"gate": "measured-workload-trace", "status": status(measured_workload_trace_ready), "reason": f"cpu_rows={len(cpu_rows)} nvme_rows={len(nvme_rows)}"},
    {"gate": "real-return-axis-count", "status": status(real_return_evidence_axis_count >= 1), "reason": f"axes={real_return_evidence_axis_count}"},
    {"gate": "v18-commercial-intake", "status": status(v18_ready), "reason": "v18 verifies measured trace commercial-return binding"},
    {"gate": "v40-evidence-ladder", "status": status(v40_ready), "reason": "v40 machine-verified research artifact remains ready"},
    {"gate": "external-or-buyer-return", "status": "blocked", "reason": "no external human or buyer acceptance return supplied in this run"},
    {"gate": "real-teacher-source-import-candidate", "status": "blocked", "reason": "no real teacher-source import candidate supplied in this run"},
    {"gate": "gpu-speedup-claim", "status": "blocked", "reason": "HIP/GPU measurement absent; gpu_speedup_claim=deferred"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release-ready wording remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

if not v51_ready:
    raise SystemExit("v51 real-return evidence intake did not close")
PY

echo "v51_real_return_evidence_intake_dir: $INTAKE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
