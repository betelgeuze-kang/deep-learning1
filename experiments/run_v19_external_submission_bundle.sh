#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v19_external_submission_bundle"
BUNDLE_ID="${V19_BUNDLE_ID:-bundle_001}"
BUNDLE_DIR="${V19_BUNDLE_DIR:-$RESULTS_DIR/${PREFIX}/$BUNDLE_ID}"
V17_PACKAGE_DIR="${V17_PACKAGE_DIR:-$RESULTS_DIR/v17_post_v16_externalization_handoff/package_001}"
V18_INTAKE_DIR="${V18_INTAKE_DIR:-$RESULTS_DIR/v18_external_evidence_intake/intake_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$BUNDLE_DIR"

"$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$BUNDLE_DIR" "$V17_PACKAGE_DIR" "$V18_INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
bundle_dir = Path(sys.argv[2])
v17_package_dir = Path(sys.argv[3])
v18_intake_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
bundle_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in [
    "source_manifests",
    "third_party_submission",
    "official_benchmark_submission",
    "commercial_poc_submission",
    "roadmap",
    "verifier",
]:
    ensure(bundle_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

copy(v17_package_dir / "handoff_manifest.json", "source_manifests/v17_handoff_manifest.json")
copy(v17_package_dir / "artifact_manifest.csv", "source_manifests/v17_artifact_manifest.csv")
copy(v18_intake_dir / "intake_manifest.json", "source_manifests/v18_intake_manifest.json")
copy(v18_intake_dir / "track_intake_rows.csv", "source_manifests/v18_track_intake_rows.csv")
copy(root / "docs" / "POST_V18_RESEARCH_ROADMAP.md", "roadmap/POST_V18_RESEARCH_ROADMAP.md")
copy(v17_package_dir / "third_party_rerun" / "EXTERNAL_REPRODUCE.sh", "third_party_submission/EXTERNAL_REPRODUCE.sh")
(bundle_dir / "third_party_submission" / "EXTERNAL_REPRODUCE.sh").chmod(0o755)

(bundle_dir / "SUBMISSION_README.md").write_text(
    "\n".join(
        [
            "# v19 External Submission Bundle",
            "",
            "Purpose: close the current internal mode by preparing a package that an external reviewer, official benchmark runner, or commercial PoC owner can execute and return.",
            "",
            "This bundle does not claim external validation. It sets only submission-readiness flags. The actual flags remain blocked until non-fixture external artifacts are supplied through the v18 intake verifier.",
            "",
            "Tracks:",
            "1. Third-party rerun: turn local v15-b mechanics into `independent_rerun_actual_ready=1` with a non-local reviewer or clean-machine rerun.",
            "2. Official benchmark reconciliation: turn runner-owned RULER/LongBench smoke into `candidate_external_benchmark_result_ready=1` using official source snapshot, official evaluator/container, raw predictions, metrics, and provenance.",
            "3. Commercial local QA/audit PoC: test a local evidence-bound QA/audit system on a closed corpus before any product claim.",
            "",
            "Return flow:",
            "1. Send the relevant track directory to the reviewer or PoC owner.",
            "2. Receive the required return files in a non-fixture directory.",
            "3. Run `V18_THIRD_PARTY_RERUN_DIR=/path/to/rerun V18_OFFICIAL_BENCHMARK_DIR=/path/to/benchmark V18_COMMERCIAL_POC_DIR=/path/to/poc experiments/run_v18_external_evidence_intake.sh` with whichever directories are available.",
            "4. Inspect `results/v18_external_evidence_intake_summary.csv` and `results/v18_external_evidence_intake/intake_001/intake_manifest.json`.",
            "",
            "Default verifier smoke: `experiments/test_v18_external_evidence_intake.sh`.",
            "Submission bundle smoke: `experiments/test_v19_external_submission_bundle.sh`.",
            "",
        ]
    ),
    encoding="utf-8",
)

(bundle_dir / "third_party_submission" / "SUBMIT_THIRD_PARTY_RERUN.md").write_text(
    "\n".join(
        [
            "# Submit Third-Party Rerun",
            "",
            "Target flag: `independent_rerun_actual_ready=1`.",
            "",
            "Run requirement:",
            "- Use a clean machine or a non-local environment controlled by an independent reviewer.",
            "- Run `third_party_submission/EXTERNAL_REPRODUCE.sh` from the repository root.",
            "- Preserve stdout and stderr exactly.",
            "- Report command exit code, stdout/stderr sha256 hashes, metric deltas, reviewer identity, and environment identity.",
            "",
            "The returned directory is accepted by v18 only when all required files are present, hashes match, the package manifest hash matches, frozen queries and source snapshots are verified, metric deltas are within tolerance, and the reviewer/environment are independent.",
            "",
        ]
    ),
    encoding="utf-8",
)

(bundle_dir / "third_party_submission" / "CLEAN_MACHINE_RUNBOOK.md").write_text(
    "\n".join(
        [
            "# Clean-Machine Runbook",
            "",
            "1. Clone or unpack the exact repository revision supplied with this bundle.",
            "2. Record OS, kernel, CPU, memory, storage, Python, compiler, and git revision in `rerun_environment.json`.",
            "3. Execute `third_party_submission/EXTERNAL_REPRODUCE.sh` once from the repository root.",
            "4. Save stdout as `stdout.txt` and stderr as `stderr.txt`.",
            "5. Fill `rerun_commands.csv`, `rerun_manifest.json`, `metric_delta_rows.csv`, and `review_rows.csv`.",
            "6. Return the directory and its files without editing generated result artifacts.",
            "",
            "A successful local run is useful, but it is not enough. v18 requires the external independent reviewer or clean-machine declarations to be true before setting the actual rerun flag.",
            "",
        ]
    ),
    encoding="utf-8",
)

(bundle_dir / "third_party_submission" / "RETURN_MANIFEST_TEMPLATE.json").write_text(
    json.dumps(
        {
            "v15a_package_manifest_sha256": "",
            "reproducer_command": "third_party_submission/EXTERNAL_REPRODUCE.sh",
            "rerun_exit_code": 0,
            "metric_delta_tolerance": "",
            "frozen_queries_verified": 1,
            "source_snapshot_verified": 1,
            "external_independent_reviewer": 1,
            "notes": "",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

third_party_required = [
    ("reviewer_identity.json", "external reviewer identity; must include external_independent_reviewer=1"),
    ("rerun_environment.json", "clean machine or non-local environment; must include clean_machine=1 or external_independent_environment=1"),
    ("rerun_commands.csv", "exact command, exit_code=0, stdout_sha256, stderr_sha256"),
    ("rerun_manifest.json", "package hash, frozen query verification, source snapshot verification"),
    ("metric_delta_rows.csv", "one row per metric with delta_within_tolerance=1"),
    ("review_rows.csv", "one row per gate with status=pass"),
    ("stdout.txt", "captured stdout"),
    ("stderr.txt", "captured stderr"),
]
with (bundle_dir / "third_party_submission" / "REQUIRED_RETURN_FILES.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["path", "requirement"])
    writer.writerows(third_party_required)

(bundle_dir / "official_benchmark_submission" / "SUBMIT_OFFICIAL_BENCHMARK.md").write_text(
    "\n".join(
        [
            "# Submit Official Benchmark Reconciliation",
            "",
            "Target flag: `candidate_external_benchmark_result_ready=1`.",
            "",
            "Required boundary:",
            "- Use an official source snapshot and official evaluator/container.",
            "- Do not use oracle predictions.",
            "- Do not use a raw-input extractor as the prediction path.",
            "- Preserve RouteMemory-derived prediction lineage, raw predictions, metrics, provenance, and a reproducibility package manifest.",
            "",
            "This track is best started with a small official slice of RULER NIAH or LongBench v2. The point is not to maximize score yet; the point is to prove that the result is externally replayable and not a runner-owned smoke artifact.",
            "",
        ]
    ),
    encoding="utf-8",
)

official_requirements = [
    ("official_source_snapshot.json", "official_source_snapshot_ready=1 plus immutable source/dataset identity"),
    ("official_evaluator_status.json", "official_evaluator_ready=1 plus command/container digest"),
    ("raw_predictions.jsonl", "raw prediction rows emitted before evaluation"),
    ("prediction_lineage.jsonl", "RouteMemory-derived prediction lineage for every row"),
    ("metrics.json", "metrics_ready=1, raw_predictions_ready=1, oracle_prediction_used=0, raw_input_extractor_used=0"),
    ("provenance_manifest.json", "route_memory_prediction_lineage_ready=1, oracle_prediction_used=0, raw_input_extractor_used=0"),
    ("reproducibility_package_manifest.json", "reproducibility_package_ready=1"),
    ("candidate_result_rows.csv", "candidate_external_benchmark_result_ready=1 for accepted rows"),
]
with (bundle_dir / "official_benchmark_submission" / "OFFICIAL_SLICE_REQUIREMENTS.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["path", "requirement"])
    writer.writerows(official_requirements)
with (bundle_dir / "official_benchmark_submission" / "CANDIDATE_RESULT_TEMPLATE.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["benchmark_family", "task", "query_count", "metric_name", "metric_value", "official_evaluator_digest", "prediction_lineage_sha256", "candidate_external_benchmark_result_ready"])
    writer.writerow(["ruler_niah_or_longbench_v2", "", "", "", "", "", "", "0"])

(bundle_dir / "commercial_poc_submission" / "SUBMIT_COMMERCIAL_POC.md").write_text(
    "\n".join(
        [
            "# Submit Commercial Local QA/Audit PoC",
            "",
            "Target flag: `closed_corpus_poc_actual_ready=1`.",
            "",
            "Positioning: local evidence-bound QA/audit system, not an LLM replacement.",
            "",
            "Recommended order:",
            "1. Codebase QA.",
            "2. Internal document QA.",
            "3. Product manual QA.",
            "4. Log or incident root-cause evidence QA.",
            "",
            "Acceptance dimensions: wrong-answer guard, citation accuracy, abstain behavior, query-to-evidence latency, resource envelope, privacy review, and audit trail.",
            "",
        ]
    ),
    encoding="utf-8",
)

with (bundle_dir / "commercial_poc_submission" / "DOMAIN_INTAKE_TEMPLATE.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["domain", "corpus_uri", "corpus_sha256", "query_set_uri", "query_set_sha256", "privacy_review_uri", "acceptance_review_uri", "closed_corpus_poc_actual_ready"])
    writer.writerow(["codebase_qa|internal_docs|product_manual|incident_logs", "", "", "", "", "", "", "0"])
with (bundle_dir / "commercial_poc_submission" / "POC_ACCEPTANCE_CRITERIA.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["criterion", "required", "measurement"])
    writer.writerows(
        [
            ("wrong_answer_guard", 1, "unsupported answer rate and blocked unsupported rows"),
            ("citation_accuracy", 1, "exact evidence span citation review"),
            ("abstain_behavior", 1, "missing/ambiguous evidence abstention rows"),
            ("query_to_evidence_latency", 1, "per-query latency distribution"),
            ("resource_envelope", 1, "CPU/RAM/storage envelope"),
            ("privacy_review", 1, "local-first data handling and PII review"),
            ("audit_trail", 1, "query/evidence/prediction/review trace"),
        ]
    )

(bundle_dir / "verifier" / "V18_INTAKE_COMMANDS.md").write_text(
    "\n".join(
        [
            "# v18 Intake Commands",
            "",
            "Default blocked smoke:",
            "",
            "```bash",
            "experiments/test_v18_external_evidence_intake.sh",
            "```",
            "",
            "Verify supplied external directories:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_rerun \\",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_benchmark \\",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_poc \\",
            "experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "The fixture test is only a verifier smoke. It must not be cited as real external evidence.",
            "",
        ]
    ),
    encoding="utf-8",
)

track_rows = [
    {
        "track": "third_party_rerun",
        "submission_ready": 1,
        "actual_ready_flag": "independent_rerun_actual_ready",
        "actual_ready_value": 0,
        "next_evidence": "non-local reviewer or clean-machine rerun return directory",
        "recommended_order": 1,
    },
    {
        "track": "official_benchmark_reconciliation",
        "submission_ready": 1,
        "actual_ready_flag": "candidate_external_benchmark_result_ready",
        "actual_ready_value": 0,
        "next_evidence": "official source/evaluator slice with raw predictions, metrics, provenance, and RouteMemory lineage",
        "recommended_order": 2,
    },
    {
        "track": "commercial_local_poc",
        "submission_ready": 1,
        "actual_ready_flag": "closed_corpus_poc_actual_ready",
        "actual_ready_value": 0,
        "next_evidence": "closed-corpus local evidence-bound QA/audit PoC with privacy and acceptance review",
        "recommended_order": 3,
    },
]
with (bundle_dir / "track_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(track_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(track_rows)

manifest = {
    "manifest_scope": "v19-external-submission-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v17_handoff_manifest_sha256": sha256(v17_package_dir / "handoff_manifest.json"),
    "v18_intake_manifest_sha256": sha256(v18_intake_dir / "intake_manifest.json"),
    "submission_bundle_ready": 1,
    "third_party_submission_ready": 1,
    "official_benchmark_submission_ready": 1,
    "commercial_poc_submission_ready": 1,
    "independent_rerun_actual_ready": 0,
    "candidate_external_benchmark_result_ready": 0,
    "closed_corpus_poc_actual_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
    "claim": "external submission package ready; actual readiness requires non-fixture v18 intake evidence",
}
(bundle_dir / "submission_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "SUBMISSION_README.md",
    "source_manifests/v17_handoff_manifest.json",
    "source_manifests/v17_artifact_manifest.csv",
    "source_manifests/v18_intake_manifest.json",
    "source_manifests/v18_track_intake_rows.csv",
    "third_party_submission/EXTERNAL_REPRODUCE.sh",
    "third_party_submission/SUBMIT_THIRD_PARTY_RERUN.md",
    "third_party_submission/CLEAN_MACHINE_RUNBOOK.md",
    "third_party_submission/RETURN_MANIFEST_TEMPLATE.json",
    "third_party_submission/REQUIRED_RETURN_FILES.csv",
    "official_benchmark_submission/SUBMIT_OFFICIAL_BENCHMARK.md",
    "official_benchmark_submission/OFFICIAL_SLICE_REQUIREMENTS.csv",
    "official_benchmark_submission/CANDIDATE_RESULT_TEMPLATE.csv",
    "commercial_poc_submission/SUBMIT_COMMERCIAL_POC.md",
    "commercial_poc_submission/DOMAIN_INTAKE_TEMPLATE.csv",
    "commercial_poc_submission/POC_ACCEPTANCE_CRITERIA.csv",
    "roadmap/POST_V18_RESEARCH_ROADMAP.md",
    "verifier/V18_INTAKE_COMMANDS.md",
    "track_rows.csv",
    "submission_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = bundle_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (bundle_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "bundle_id": bundle_dir.name,
        "submission_bundle_ready": 1,
        "third_party_submission_ready": 1,
        "official_benchmark_submission_ready": 1,
        "commercial_poc_submission_ready": 1,
        "independent_rerun_actual_ready": 0,
        "candidate_external_benchmark_result_ready": 0,
        "closed_corpus_poc_actual_ready": 0,
        "real_external_benchmark_verified": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("external-submission-bundle", "pass", "v17 handoff and v18 intake verifier are packaged for external return flow"),
    ("third-party-submission-ready", "pass", "rerun command, required files, return manifest, and clean-machine runbook prepared"),
    ("official-benchmark-submission-ready", "pass", "official source/evaluator and candidate-result requirements prepared"),
    ("commercial-poc-submission-ready", "pass", "local evidence-bound QA/audit intake and acceptance criteria prepared"),
    ("independent-rerun-actual", "blocked", "no non-fixture external rerun has been supplied to v18"),
    ("candidate-external-benchmark-result", "blocked", "no official benchmark result directory has been supplied to v18"),
    ("closed-corpus-poc-actual", "blocked", "no closed-corpus commercial PoC directory has been supplied to v18"),
    ("real-release-package", "blocked", "submission bundle is not release evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v19_submission_bundle_dir: $BUNDLE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
