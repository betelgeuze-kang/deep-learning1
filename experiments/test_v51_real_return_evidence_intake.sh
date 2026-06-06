#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
INTAKE_DIR="$RESULTS_DIR/v51_real_return_evidence_intake/intake_001"
RETURN_DIR="$INTAKE_DIR/commercial_return"
TRACE_DIR="$INTAKE_DIR/measured_workload_trace"
SUMMARY_CSV="$RESULTS_DIR/v51_real_return_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v51_real_return_evidence_intake_decision.csv"

"$ROOT_DIR/experiments/run_v51_real_return_evidence_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$INTAKE_DIR" "$RETURN_DIR" "$TRACE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
intake_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
trace_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v51 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v51_real_return_evidence_intake_ready": "1",
    "external_or_buyer_return_supplied": "0",
    "real_teacher_source_import_candidate_supplied": "0",
    "measured_workload_trace_bound": "1",
    "real_return_evidence_axis_count": "1",
    "cpu_trace_rows": "7",
    "nvme_trace_rows": "7",
    "hip_trace_rows": "0",
    "hip_optional_missing": "1",
    "non_fixture_workload_trace_rows": "1",
    "measured_workload_trace_ready": "1",
    "v18_closed_corpus_poc_actual_ready": "1",
    "v40_machine_verified_research_artifact_ready": "1",
    "human_review_completed": "0",
    "real_release_package_ready": "0",
    "gpu_speedup_claim": "deferred",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v51 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("source_files", "0")) < 12:
    raise SystemExit("v51 should measure over tracked source files")
if float(summary.get("cpu_median_ms", "0")) <= 0:
    raise SystemExit("v51 CPU median must be positive")
if float(summary.get("nvme_read_median_ms", "0")) <= 0:
    raise SystemExit("v51 NVMe/filesystem read median must be positive")
if int(summary.get("artifact_rows", "0")) < 20:
    raise SystemExit("v51 should hash all evidence artifacts")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v51-real-return-evidence-intake",
    "measured-workload-trace",
    "real-return-axis-count",
    "v18-commercial-intake",
    "v40-evidence-ladder",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v51 gate should pass: {gate}")
for gate in [
    "external-or-buyer-return",
    "real-teacher-source-import-candidate",
    "gpu-speedup-claim",
    "real-release-package",
]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v51 gate should remain blocked: {gate}")

required_files = [
    "V51_REAL_RETURN_EVIDENCE_BOUNDARY.md",
    "v51_real_return_evidence_manifest.json",
    "measured_trace_artifact_rows.csv",
    "sha256_manifest.csv",
    "measured_workload_trace/source_manifest.csv",
    "measured_workload_trace/environment.json",
    "measured_workload_trace/cpu_trace_rows.csv",
    "measured_workload_trace/nvme_trace_rows.csv",
    "measured_workload_trace/workload_trace_rows.csv",
    "commercial_return/domain_manifest.json",
    "commercial_return/corpus_manifest.json",
    "commercial_return/query_set.csv",
    "commercial_return/poc_result_rows.csv",
    "commercial_return/audit_trail.csv",
    "commercial_return/resource_envelope.json",
    "commercial_return/privacy_review.json",
    "commercial_return/acceptance_review.csv",
    "evidence/v18_v51_measured_trace_summary.csv",
    "evidence/v18_v51_measured_trace_decision.csv",
    "evidence/v40_machine_verified_research_artifact_summary.csv",
    "evidence/v40_machine_verified_research_artifact_decision.csv",
    "evidence/v40_machine_verified_research_artifact_manifest.json",
]
for rel in required_files:
    path = intake_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v51 missing artifact: {rel}")

manifest = json.loads((intake_dir / "v51_real_return_evidence_manifest.json").read_text(encoding="utf-8"))
for field in [
    "v51_real_return_evidence_intake_ready",
    "measured_workload_trace_bound",
    "v18_closed_corpus_poc_actual_ready",
    "v40_machine_verified_research_artifact_ready",
]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v51 manifest {field} should be 1")
if manifest.get("external_or_buyer_return_supplied") != 0:
    raise SystemExit("v51 manifest should not pretend an external/buyer return was supplied")
if manifest.get("real_teacher_source_import_candidate_supplied") != 0:
    raise SystemExit("v51 manifest should not pretend a teacher-source import candidate was supplied")
if manifest.get("real_release_package_ready") != 0 or manifest.get("human_review_completed") != 0:
    raise SystemExit("v51 manifest should keep release and human-review completion blocked")
if manifest.get("gpu_speedup_claim") != "deferred":
    raise SystemExit("v51 manifest should defer GPU speedup claim")

source_rows = read_csv(trace_dir / "source_manifest.csv")
cpu_rows = read_csv(trace_dir / "cpu_trace_rows.csv")
nvme_rows = read_csv(trace_dir / "nvme_trace_rows.csv")
workload_rows = read_csv(trace_dir / "workload_trace_rows.csv")
if len(source_rows) < 12 or len(cpu_rows) != 7 or len(nvme_rows) != 7 or len(workload_rows) != 1:
    raise SystemExit("v51 trace row counts mismatch")
for row in source_rows:
    path = root / row["source_path"]
    if not path.is_file() or row["sha256"] != sha256(path):
        raise SystemExit(f"v51 source hash mismatch: {row['source_path']}")
    if row["measured_workload_source"] != "1":
        raise SystemExit("v51 source row should mark measured workload source")
for row in cpu_rows:
    if row["runner_measured"] != "1" or float(row["elapsed_ms"]) <= 0:
        raise SystemExit("v51 CPU trace rows should be positive runner measurements")
    if not row["output_sha256"].startswith("sha256:"):
        raise SystemExit("v51 CPU trace rows should include output hashes")
for row in nvme_rows:
    if row["runner_measured"] != "1" or float(row["elapsed_ms"]) <= 0:
        raise SystemExit("v51 NVMe trace rows should be positive runner measurements")
    if not row["read_digest_sha256"].startswith("sha256:"):
        raise SystemExit("v51 NVMe trace rows should include read digests")
workload = workload_rows[0]
if workload["non_fixture_workload_trace"] != "1" or workload["measured_workload_trace_ready"] != "1":
    raise SystemExit("v51 workload trace should be non-fixture and ready")
if workload["hip_trace_rows"] != "0" or workload["hip_optional_missing"] != "1":
    raise SystemExit("v51 workload should explicitly keep HIP optional/missing")
for path_field, hash_field in [
    ("source_manifest", "source_manifest_sha256"),
    ("environment_path", "environment_sha256"),
    ("cpu_trace_path", "cpu_trace_sha256"),
    ("nvme_trace_path", "nvme_trace_sha256"),
]:
    artifact_path = root / workload[path_field]
    if workload[hash_field] != sha256(artifact_path):
        raise SystemExit(f"v51 workload artifact hash mismatch: {path_field}")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
corpus = json.loads((return_dir / "corpus_manifest.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 3:
    raise SystemExit("v51 domain manifest should expose a 3-query codebase_qa return")
if corpus.get("closed_corpus_ready") != 1:
    raise SystemExit("v51 corpus manifest should be closed-corpus ready")
if privacy.get("privacy_review_ready") != 1 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v51 privacy/resource reviews should be ready")
if resource.get("cpu_trace_rows") != 7 or resource.get("nvme_trace_rows") != 7 or resource.get("hip_trace_rows") != 0:
    raise SystemExit("v51 resource envelope should record trace row counts")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 3 or len(poc_rows) != 3 or len(audit_rows) != 3:
    raise SystemExit("v51 commercial return should write three query/result/audit rows")
if not any(row["expected_behavior"] == "abstain" for row in query_rows):
    raise SystemExit("v51 query set should include release/GPU abstain row")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v51 result rows should pass {field}")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v51 audit rows should pass")
if len(acceptance_rows) < 4 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v51 acceptance rows should pass")

v18 = read_csv(intake_dir / "evidence" / "v18_v51_measured_trace_summary.csv")[0]
v40 = read_csv(intake_dir / "evidence" / "v40_machine_verified_research_artifact_summary.csv")[0]
if v18.get("closed_corpus_poc_actual_ready") != "1" or v18.get("commercial_poc_supplied") != "1":
    raise SystemExit("v51 copied v18 summary should verify measured trace return")
if v40.get("v40_machine_verified_research_artifact_ready") != "1":
    raise SystemExit("v51 copied v40 summary should keep the evidence ladder ready")
if v40.get("real_release_package_ready") != "0":
    raise SystemExit("v51 copied v40 summary should keep release blocked")

boundary = (intake_dir / "V51_REAL_RETURN_EVIDENCE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Runner-measured local CPU hash workload trace",
    "Runner-measured local filesystem/NVMe-style read trace",
    "External human or buyer PoC acceptance return",
    "Real teacher-source import candidate",
    "HIP/GPU speedup evidence",
    "Not GPU acceleration proof",
    "Not Transformer, LLM, or expert replacement",
]:
    if snippet not in boundary:
        raise SystemExit(f"v51 boundary missing: {snippet}")

with (intake_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v51 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(intake_dir / rel):
        raise SystemExit(f"v51 sha mismatch for {rel}")
PY

echo "v51 Real-return evidence intake smoke passed"
