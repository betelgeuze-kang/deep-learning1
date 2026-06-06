#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v18_external_evidence_intake_fixtures"
THIRD_PARTY_DIR="$FIXTURE_DIR/third_party_rerun"
OFFICIAL_DIR="$FIXTURE_DIR/official_benchmark"
COMMERCIAL_DIR="$FIXTURE_DIR/commercial_poc"
INTAKE_DIR="$RESULTS_DIR/v18_external_evidence_intake/intake_001"
SUMMARY_CSV="$RESULTS_DIR/v18_external_evidence_intake_summary.csv"
DECISION_CSV="$RESULTS_DIR/v18_external_evidence_intake_decision.csv"

"$ROOT_DIR/experiments/run_v17_post_v16_externalization_handoff.sh" >/dev/null

rm -rf "$FIXTURE_DIR"
mkdir -p "$THIRD_PARTY_DIR" "$OFFICIAL_DIR" "$COMMERCIAL_DIR"

python3 - "$ROOT_DIR" "$THIRD_PARTY_DIR" "$OFFICIAL_DIR" "$COMMERCIAL_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
third = Path(sys.argv[2])
official = Path(sys.argv[3])
commercial = Path(sys.argv[4])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

v15a_manifest = root / "results" / "v15a_independent_reproduction_package" / "package_001" / "package_manifest.json"
write_json(third / "reviewer_identity.json", {"external_independent_reviewer": 1, "reviewer_id": "fixture-third-party", "conflict_disclosure": "fixture-only"})
write_json(third / "rerun_environment.json", {"external_independent_environment": 1, "clean_machine": 1, "environment_id": "fixture-clean-machine"})
write_json(
    third / "rerun_manifest.json",
    {
        "v15a_package_manifest_sha256": sha256(v15a_manifest),
        "frozen_queries_verified": 1,
        "source_snapshot_verified": 1,
        "metric_delta_tolerance": "0.000001",
    },
)
(third / "stdout.txt").write_text("fixture stdout\n", encoding="utf-8")
(third / "stderr.txt").write_text("", encoding="utf-8")
write_csv(
    third / "rerun_commands.csv",
    ["command", "exit_code", "stdout_sha256", "stderr_sha256"],
    [
        {
            "command": "fixture external reproduce",
            "exit_code": "0",
            "stdout_sha256": sha256(third / "stdout.txt"),
            "stderr_sha256": sha256(third / "stderr.txt"),
        }
    ],
)
write_csv(
    third / "metric_delta_rows.csv",
    ["stage", "field", "expected", "actual", "delta", "delta_within_tolerance"],
    [{"stage": "v16", "field": "v16_ready", "expected": "1", "actual": "1", "delta": "0.000000", "delta_within_tolerance": "1"}],
)
write_csv(
    third / "review_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": "fixture-external-rerun", "status": "pass", "reason": "fixture-only"}],
)

write_json(official / "official_source_snapshot.json", {"official_source_snapshot_ready": 1, "source": "fixture-official-slice"})
write_json(official / "official_evaluator_status.json", {"official_evaluator_ready": 1, "container_digest": "sha256:fixture"})
(official / "raw_predictions.jsonl").write_text(json.dumps({"id": "fixture", "prediction": "3141592"}) + "\n", encoding="utf-8")
(official / "prediction_lineage.jsonl").write_text(json.dumps({"id": "fixture", "route_memory_prediction_lineage_ready": 1}) + "\n", encoding="utf-8")
write_json(official / "metrics.json", {"metrics_ready": 1, "raw_predictions_ready": 1, "oracle_prediction_used": 0, "raw_input_extractor_used": 0})
write_json(official / "provenance_manifest.json", {"route_memory_prediction_lineage_ready": 1, "oracle_prediction_used": 0, "raw_input_extractor_used": 0})
write_json(official / "reproducibility_package_manifest.json", {"reproducibility_package_ready": 1})
write_csv(
    official / "candidate_result_rows.csv",
    ["benchmark_family", "task", "candidate_external_benchmark_result_ready"],
    [{"benchmark_family": "ruler", "task": "fixture_official_slice", "candidate_external_benchmark_result_ready": "1"}],
)

write_json(commercial / "domain_manifest.json", {"domain": "codebase_qa"})
write_json(commercial / "corpus_manifest.json", {"closed_corpus_ready": 1, "corpus_sha256": "sha256:fixture"})
write_csv(commercial / "query_set.csv", ["query_id", "query"], [{"query_id": "q1", "query": "fixture"}])
write_csv(
    commercial / "poc_result_rows.csv",
    [
        "query_id",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "query_to_evidence_latency_ready",
    ],
    [{"query_id": "q1", "wrong_answer_guard_pass": "1", "citation_accuracy_pass": "1", "abstain_behavior_pass": "1", "query_to_evidence_latency_ready": "1"}],
)
write_csv(commercial / "audit_trail.csv", ["query_id", "artifact"], [{"query_id": "q1", "artifact": "fixture"}])
write_json(commercial / "resource_envelope.json", {"resource_envelope_ready": 1})
write_json(commercial / "privacy_review.json", {"privacy_review_ready": 1})
write_csv(commercial / "acceptance_review.csv", ["gate", "status"], [{"gate": "fixture-commercial-poc", "status": "pass"}])
PY

V18_THIRD_PARTY_RERUN_DIR="$THIRD_PARTY_DIR" \
V18_OFFICIAL_BENCHMARK_DIR="$OFFICIAL_DIR" \
V18_COMMERCIAL_POC_DIR="$COMMERCIAL_DIR" \
  "$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import sys
from pathlib import Path

intake_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit("expected one fixture v18 summary row")
summary = rows[0]
expected = {
    "third_party_rerun_supplied": "1",
    "independent_rerun_actual_ready": "1",
    "official_benchmark_supplied": "1",
    "candidate_external_benchmark_result_ready": "1",
    "commercial_poc_supplied": "1",
    "closed_corpus_poc_actual_ready": "1",
    "real_external_benchmark_verified": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"fixture v18 {field}: expected {value}, got {summary.get(field)}")
with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in [
    "third-party-rerun-intake",
    "independent-rerun-actual",
    "official-benchmark-intake",
    "candidate-external-benchmark-result",
    "commercial-poc-intake",
    "closed-corpus-poc-actual",
    "real-external-benchmark",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"fixture v18 decision did not pass: {gate}")
if decisions.get("real-release-package") != "blocked":
    raise SystemExit("fixture v18 release should remain blocked")
for rel in [
    "evidence_copies/third_party_rerun/reviewer_identity.json",
    "evidence_copies/official_benchmark/candidate_result_rows.csv",
    "evidence_copies/commercial_poc/acceptance_review.csv",
]:
    if not (intake_dir / rel).is_file():
        raise SystemExit(f"fixture v18 missing copied artifact: {rel}")
PY

echo "v18 external evidence intake fixture smoke passed"
