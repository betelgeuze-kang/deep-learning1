#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v17_post_v16_externalization_handoff"
PACKAGE_ID="${V17_PACKAGE_ID:-package_001}"
PACKAGE_DIR="${V17_PACKAGE_DIR:-$RESULTS_DIR/${PREFIX}/$PACKAGE_ID}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$PACKAGE_DIR"

"$ROOT_DIR/experiments/run_v16_research_commercial_tracks.sh" >/dev/null

python3 - "$ROOT_DIR" "$PACKAGE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
package_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
package_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in [
    "baseline_inputs",
    "third_party_rerun",
    "official_benchmark_reconciliation",
    "commercial_local_poc",
    "docs",
]:
    ensure(package_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = package_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

baseline_files = [
    (results / "v15a_independent_reproduction_package" / "package_001" / "package_manifest.json", "baseline_inputs/v15a_package_manifest.json"),
    (results / "v15a_independent_reproduction_package" / "package_001" / "artifact_manifest.csv", "baseline_inputs/v15a_artifact_manifest.csv"),
    (results / "v15a_independent_reproduction_package" / "package_001" / "REPRODUCE.sh", "baseline_inputs/v15a_REPRODUCE.sh"),
    (results / "v15b_nonfixture_review_independent_rerun" / "review_001" / "review_manifest.json", "baseline_inputs/v15b_review_manifest.json"),
    (results / "v16_research_commercial_tracks" / "packet_001" / "v16_manifest.json", "baseline_inputs/v16_manifest.json"),
    (results / "v16_research_commercial_tracks" / "packet_001" / "claim_boundary_matrix.csv", "baseline_inputs/v16_claim_boundary_matrix.csv"),
    (results / "v16_research_commercial_tracks" / "packet_001" / "commercial_local_qa_audit_contract.md", "baseline_inputs/v16_commercial_contract.md"),
]
for src, rel in baseline_files:
    copy(src, rel)

external_reproduce = package_dir / "third_party_rerun" / "EXTERNAL_REPRODUCE.sh"
external_reproduce.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"',
            'cd "$ROOT_DIR"',
            "experiments/test_v15a_independent_reproduction_package.sh",
            "experiments/test_v15b_nonfixture_review_independent_rerun.sh",
            "experiments/test_v16_research_commercial_tracks.sh",
            "",
        ]
    ),
    encoding="utf-8",
)
external_reproduce.chmod(0o755)

(package_dir / "third_party_rerun" / "README.md").write_text(
    "\n".join(
        [
            "# Third-Party Rerun Handoff",
            "",
            "Goal: set `independent_rerun_actual_ready=1` only after a non-local reviewer or clean machine reruns the same package.",
            "",
            "Required evidence:",
            "- reviewer identity and conflict disclosure",
            "- clean-machine or non-local environment manifest",
            "- identical command path and stdout/stderr hashes",
            "- frozen query/source snapshot hashes",
            "- metric delta rows within tolerance",
            "- rerun manifest and pass/fail review rows",
            "",
            "Current package state: handoff ready, actual independent rerun not yet supplied.",
            "",
        ]
    ),
    encoding="utf-8",
)

third_party_required = [
    ("reviewer_identity.json", "reviewer_identity", "external reviewer identity, registry/contact, conflict disclosure", 1),
    ("rerun_environment.json", "environment", "clean machine or non-local environment manifest", 1),
    ("rerun_commands.csv", "command", "same command, exit code, stdout/stderr paths and hashes", 1),
    ("rerun_manifest.json", "manifest", "package hash, git revision, frozen query/source snapshot binding", 1),
    ("metric_delta_rows.csv", "metrics", "expected vs rerun metrics within tolerance", 1),
    ("review_rows.csv", "review", "pass/fail rows for every required gate", 1),
    ("stdout.txt", "logs", "captured stdout", 1),
    ("stderr.txt", "logs", "captured stderr", 1),
]
with (package_dir / "third_party_rerun" / "required_external_rerun_artifacts.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["path", "artifact_kind", "requirement", "required"])
    writer.writerows(third_party_required)

with (package_dir / "third_party_rerun" / "rerun_manifest_template.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["field", "required", "description"])
    writer.writerows(
        [
            ("v15a_package_manifest_sha256", 1, "sha256 of baseline v15-a package manifest"),
            ("reproducer_command", 1, "exact command executed"),
            ("rerun_exit_code", 1, "must be 0"),
            ("metric_delta_tolerance", 1, "numeric tolerance for summary metric deltas"),
            ("frozen_queries_verified", 1, "all frozen query hashes match package"),
            ("source_snapshot_verified", 1, "source snapshot rows/manifests match package"),
            ("external_independent_reviewer", 1, "must be 1 for actual readiness"),
        ]
    )

(package_dir / "official_benchmark_reconciliation" / "README.md").write_text(
    "\n".join(
        [
            "# Official Benchmark Reconciliation Handoff",
            "",
            "Goal: prepare a candidate external benchmark result only after official-source/evaluator evidence exists.",
            "",
            "Required evidence:",
            "- official source snapshot",
            "- official evaluator or container",
            "- no oracle and no raw-input extractor",
            "- RouteMemory-derived prediction lineage",
            "- raw predictions, metrics, provenance, and reproducibility package",
            "- independent or official result reconciliation rows",
            "",
            "Current package state: intake ready, candidate benchmark result not yet supplied.",
            "",
        ]
    ),
    encoding="utf-8",
)
official_required = [
    ("official_source_snapshot", "official source snapshot hash or immutable archive", 1),
    ("official_evaluator_container", "official evaluator command/container digest", 1),
    ("raw_predictions", "raw model/system predictions", 1),
    ("prediction_lineage", "RouteMemory mmap-derived prediction lineage", 1),
    ("metrics", "official metric outputs", 1),
    ("provenance", "source/dataset/evaluator/provenance manifest", 1),
    ("no_oracle", "oracle prediction use must be 0", 1),
    ("no_raw_input_extractor", "raw-input extractor promotion must be 0", 1),
    ("reconciliation_rows", "official/independent result reconciliation", 1),
]
with (package_dir / "official_benchmark_reconciliation" / "official_reconciliation_requirements.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["requirement", "description", "required"])
    writer.writerows(official_required)
with (package_dir / "official_benchmark_reconciliation" / "candidate_result_template.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["benchmark_family", "task", "query_count", "metric_name", "metric_value", "official_evaluator_digest", "prediction_lineage_sha256", "candidate_external_benchmark_result_ready"])
    writer.writerow(["ruler_or_longbench", "", "", "", "", "", "", "0"])

(package_dir / "commercial_local_poc" / "README.md").write_text(
    "\n".join(
        [
            "# Commercial Local QA/Audit PoC Handoff",
            "",
            "Positioning: local evidence-bound QA/audit system, not an LLM replacement.",
            "",
            "Recommended domains:",
            "- codebase QA",
            "- internal document QA",
            "- product manual QA",
            "- log / incident root-cause evidence QA",
            "",
            "Success criteria: wrong-answer guard, citation accuracy, abstain behavior, query-to-evidence latency, resource envelope, audit trail.",
            "",
            "Current package state: PoC intake/acceptance contract ready, closed-corpus customer PoC not yet supplied.",
            "",
        ]
    ),
    encoding="utf-8",
)
commercial_criteria = [
    ("wrong_answer_guard", "wrong-answer guard blocks unsupported answers", 1),
    ("citation_accuracy", "answers cite exact evidence spans/artifacts", 1),
    ("abstain_behavior", "missing evidence produces abstention", 1),
    ("query_to_evidence_latency", "latency recorded per query", 1),
    ("resource_envelope", "CPU/RAM/storage envelope recorded", 1),
    ("audit_trail", "query/evidence/prediction/review trail is retained", 1),
    ("local_first", "no cloud dependency by default", 1),
]
with (package_dir / "commercial_local_poc" / "poc_acceptance_criteria.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["criterion", "description", "required"])
    writer.writerows(commercial_criteria)
with (package_dir / "commercial_local_poc" / "domain_intake_template.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["domain", "corpus_uri", "corpus_sha256", "query_set_uri", "query_set_sha256", "privacy_review_uri", "success_thresholds_uri", "closed_corpus_poc_actual_ready"])
    writer.writerow(["codebase_qa|internal_docs|product_manual|incident_logs", "", "", "", "", "", "", "0"])

(package_dir / "docs" / "POST_V16_EXTERNALIZATION.md").write_text(
    "\n".join(
        [
            "# Post-v16 Externalization Plan",
            "",
            "This packet splits post-v16 work into three tracks:",
            "",
            "1. Third-party rerun package: turn local v15-b mechanics into actual independent rerun evidence.",
            "2. Official benchmark reconciliation: turn runner-owned RULER/LongBench smoke into candidate official-slice evidence.",
            "3. Commercial local QA/audit PoC: test closed-corpus evidence-bound QA without claiming LLM replacement.",
            "",
            "All actual/candidate flags remain blocked until corresponding external artifacts are supplied.",
            "",
        ]
    ),
    encoding="utf-8",
)

artifact_rels = [
    "baseline_inputs/v15a_package_manifest.json",
    "baseline_inputs/v15a_artifact_manifest.csv",
    "baseline_inputs/v15a_REPRODUCE.sh",
    "baseline_inputs/v15b_review_manifest.json",
    "baseline_inputs/v16_manifest.json",
    "baseline_inputs/v16_claim_boundary_matrix.csv",
    "baseline_inputs/v16_commercial_contract.md",
    "third_party_rerun/EXTERNAL_REPRODUCE.sh",
    "third_party_rerun/README.md",
    "third_party_rerun/required_external_rerun_artifacts.csv",
    "third_party_rerun/rerun_manifest_template.csv",
    "official_benchmark_reconciliation/README.md",
    "official_benchmark_reconciliation/official_reconciliation_requirements.csv",
    "official_benchmark_reconciliation/candidate_result_template.csv",
    "commercial_local_poc/README.md",
    "commercial_local_poc/poc_acceptance_criteria.csv",
    "commercial_local_poc/domain_intake_template.csv",
    "docs/POST_V16_EXTERNALIZATION.md",
]
artifact_rows = []
for rel in artifact_rels:
    path = package_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (package_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

third_party_rerun_handoff_ready = 1
official_benchmark_reconciliation_intake_ready = 1
commercial_local_poc_intake_ready = 1
handoff_ready = 1
manifest = {
    "manifest_scope": "v17-post-v16-externalization-handoff",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "third_party_rerun_handoff_ready": third_party_rerun_handoff_ready,
    "independent_rerun_actual_ready": 0,
    "official_benchmark_reconciliation_intake_ready": official_benchmark_reconciliation_intake_ready,
    "candidate_external_benchmark_result_ready": 0,
    "commercial_local_poc_intake_ready": commercial_local_poc_intake_ready,
    "closed_corpus_poc_actual_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
    "handoff_ready": handoff_ready,
    "claim": "post-v16 externalization handoff; actual external rerun, official benchmark candidate, and commercial closed-corpus PoC remain blocked until supplied",
}
(package_dir / "handoff_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary_rows = [
    {
        "package_id": package_dir.name,
        "handoff_ready": handoff_ready,
        "third_party_rerun_handoff_ready": third_party_rerun_handoff_ready,
        "independent_rerun_actual_ready": 0,
        "official_benchmark_reconciliation_intake_ready": official_benchmark_reconciliation_intake_ready,
        "candidate_external_benchmark_result_ready": 0,
        "commercial_local_poc_intake_ready": commercial_local_poc_intake_ready,
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
    ("third-party-rerun-handoff", "pass", "external rerun manifest/schema/command prepared"),
    ("independent-rerun-actual", "blocked", "no real external reviewer or clean-machine result supplied"),
    ("official-benchmark-reconciliation-intake", "pass", "official source/evaluator/provenance requirements prepared"),
    ("candidate-external-benchmark-result", "blocked", "no official/independent benchmark reconciliation supplied"),
    ("commercial-local-poc-intake", "pass", "domain intake and acceptance criteria prepared"),
    ("closed-corpus-poc-actual", "blocked", "no customer/domain closed corpus supplied"),
    ("real-release-package", "blocked", "post-v16 handoff is not release evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v17_externalization_handoff_dir: $PACKAGE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
