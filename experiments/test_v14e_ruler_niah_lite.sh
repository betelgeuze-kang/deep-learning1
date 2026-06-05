#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v14e_ruler_niah_lite_summary.csv"
DECISION_CSV="$RESULTS_DIR/v14e_ruler_niah_lite_decision.csv"
RUN_DIR="$RESULTS_DIR/v14e_ruler_niah_lite_runs/niah_lite_001"

"$ROOT_DIR/experiments/run_v14e_ruler_niah_lite.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
run_dir = Path(sys.argv[3])

with summary_csv.open(newline="", encoding="utf-8") as handle:
    summary_rows = list(csv.DictReader(handle))
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v14-e summary row, got {len(summary_rows)}")
summary = summary_rows[0]

def as_int(row, field):
    try:
        return int(float(row.get(field, "0") or 0))
    except ValueError:
        return 0

def as_float(row, field):
    try:
        return float(row.get(field, "0") or 0)
    except ValueError:
        return 0.0

expected = {
    "dataset_rows": 100,
    "routeqa_mini_target_rows": 100,
    "routeqa_mini_ready": 1,
    "prediction_lineage_ready": 1,
    "prediction_lineage_rows": 100,
    "no_extractor_prediction_ready": 1,
    "generator_hint_nlg_ready": 1,
    "generator_hint_nlg_rows": 100,
    "shortcut_negative_suite_ready": 1,
    "baseline_comparison_ready": 1,
    "baseline_rows": 6,
    "baseline_negative_case_rows": 66,
    "resource_envelope_ready": 1,
    "run_layout_ready": 1,
    "objective_requirements_ready": 1,
    "execution_chain_manifest_ready": 1,
    "ruler_compatible_rows": 1,
    "ruler_compatible_ready": 1,
    "ruler_compatible_benchmark_rows": 1,
    "ruler_compatible_benchmark_ready": 1,
    "ruler_compatible_prediction_provenance_rows": 1,
    "ruler_compatible_extracted_prediction_rows": 1,
    "ruler_compatible_mmap_read_rows": 1,
    "ruler_compatible_mmap_read_ready_rows": 1,
    "ruler_compatible_mmap_prediction_match_rows": 1,
    "ruler_compatible_mmap_verification_ready": 1,
    "external_benchmark_rows": 1,
    "external_benchmark_ready_rows": 1,
    "external_benchmark_dataset_rows": 1,
    "external_benchmark_raw_prediction_rows": 1,
    "external_benchmark_prediction_provenance_rows": 1,
    "external_benchmark_extracted_prediction_rows": 1,
    "external_benchmark_mmap_read_rows": 1,
    "external_benchmark_mmap_prediction_match_rows": 1,
    "external_benchmark_mmap_verification_ready_rows": 1,
    "external_benchmark_execution_chain_ready_rows": 1,
    "external_benchmark_execution_chain_ready": 1,
    "runner_owned_external_benchmark_result_ready": 1,
    "candidate_external_benchmark_result_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
}
for field, expected_value in expected.items():
    actual = as_int(summary, field)
    if actual != expected_value:
        raise SystemExit(f"v14-e {field}: expected {expected_value}, got {actual}")
if as_float(summary, "ruler_compatible_score") != 100.0:
    raise SystemExit("v14-e RULER-compatible score mismatch")
if as_float(summary, "routing_trigger_rate") != 0.0 or as_float(summary, "active_jump_rate") != 0.0:
    raise SystemExit("v14-e route/jump rates are not zero")

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

sha_manifest = {}
with (run_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            digest, rel = line.strip().split(None, 1)
            sha_manifest[rel] = "sha256:" + digest

required_artifacts = [
    "benchmark/ruler_synthetic/niah_dataset.jsonl",
    "benchmark/ruler_synthetic/niah_single_1.jsonl",
    "benchmark/ruler_synthetic/ruler_evaluator_rows.csv",
    "benchmark/ruler_synthetic/ruler_compatible_benchmark_rows.csv",
    "benchmark/ruler_synthetic/ruler_compatible_metrics.json",
    "benchmark/ruler_synthetic/ruler_compatible_prediction_provenance.csv",
    "benchmark/ruler_synthetic/compatible_niah_store/route_memory_store.bin",
    "benchmark/ruler_synthetic/compatible_niah_store/route_index.bin",
    "benchmark/ruler_synthetic/compatible_niah_store/chunk_offsets",
    "benchmark/ruler_synthetic/compatible_niah_store/mmap_read_rows.csv",
    "benchmark/ruler_synthetic/compatible_niah_store/store_status.json",
    "benchmark/external_benchmark_rows.csv",
    "benchmark/external_benchmark_metrics.json",
    "benchmark/external_benchmark_manifest.json",
    "benchmark/external_benchmark_execution_chain_manifest.json",
    "evidence/execution_chain_manifest.json",
    "evidence/objective_requirements_manifest.json",
    "evidence/run_layout_manifest.json",
    "resource/resource_envelope.json",
    "sha256sums.txt",
]
for rel in required_artifacts:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v14-e artifact: {rel}")
    if rel != "sha256sums.txt" and sha_manifest.get(rel) != sha256(path):
        raise SystemExit(f"sha256 manifest does not bind v14-e artifact: {rel}")

def read_csv(rel):
    with (run_dir / rel).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def jsonl_count(rel):
    with (run_dir / rel).open(encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())

if jsonl_count("benchmark/ruler_synthetic/niah_dataset.jsonl") != 1:
    raise SystemExit("v14-e NIAH dataset count mismatch")
if jsonl_count("benchmark/ruler_synthetic/niah_single_1.jsonl") != 1:
    raise SystemExit("v14-e NIAH prediction count mismatch")

compatible_rows = read_csv("benchmark/ruler_synthetic/ruler_compatible_benchmark_rows.csv")
external_rows = read_csv("benchmark/external_benchmark_rows.csv")
provenance_rows = read_csv("benchmark/ruler_synthetic/ruler_compatible_prediction_provenance.csv")
mmap_rows = read_csv("benchmark/ruler_synthetic/compatible_niah_store/mmap_read_rows.csv")
if len(compatible_rows) != 1 or len(external_rows) != 1 or len(provenance_rows) != 1 or len(mmap_rows) != 1:
    raise SystemExit("v14-e RULER-compatible artifact row count mismatch")
row = compatible_rows[0]
if row["external_benchmark_family"] != "ruler-compatible-niah-lite" or row["benchmark_result_ready"] != "1":
    raise SystemExit("v14-e compatible benchmark row mismatch")
if row["runner_owned"] != "1" or row["independent"] != "0" or row["oracle_prediction_used"] != "0":
    raise SystemExit("v14-e compatible benchmark claim flags mismatch")
if row["input_extractor_prediction_used"] != "0" or row["mmap_prediction_match_rows"] != "1":
    raise SystemExit("v14-e compatible benchmark provenance flags mismatch")
external = external_rows[0]
if external["external_benchmark_family"] != "ruler-compatible-niah-lite":
    raise SystemExit("v14-e external benchmark row did not use compatible NIAH-lite family")
if external["runner_owned"] != "1" or external["independent"] != "0" or external["benchmark_result_ready"] != "1":
    raise SystemExit("v14-e external benchmark readiness flags mismatch")
if external["candidate_external_benchmark_result_ready"] != "0" or external["real_external_benchmark_verified"] != "0":
    raise SystemExit("v14-e external benchmark promoted real/candidate unexpectedly")
prov = provenance_rows[0]
if prov["prediction"] != prov["mmap_extracted_pred"] or prov["mmap_prediction_matches_raw"] != "1":
    raise SystemExit("v14-e compatible prediction was not mmap-derived")
if prov["input_extractor_prediction_used"] != "0" or prov["oracle_prediction_used"] != "0":
    raise SystemExit("v14-e compatible prediction provenance flags mismatch")

metrics = json.loads((run_dir / "benchmark" / "ruler_synthetic" / "ruler_compatible_metrics.json").read_text(encoding="utf-8"))
if metrics.get("benchmark_result_ready") != 1 or metrics.get("mmap_verification_ready") != 1:
    raise SystemExit("v14-e compatible metrics readiness mismatch")
resource = json.loads((run_dir / "resource" / "resource_envelope.json").read_text(encoding="utf-8"))
if resource.get("query_count") != 100 or resource.get("resource_envelope_ready") != 1:
    raise SystemExit("v14-e resource envelope mismatch")

chain = json.loads((run_dir / "evidence" / "execution_chain_manifest.json").read_text(encoding="utf-8"))
artifact_names = {row.get("artifact") for row in chain.get("artifacts", [])}
for artifact in [
    "ruler_compatible_benchmark_rows",
    "ruler_compatible_metrics",
    "ruler_compatible_prediction_provenance",
    "ruler_compatible_mmap_store",
    "ruler_compatible_mmap_reads",
    "external_benchmark_rows",
    "external_benchmark_execution_chain_manifest",
]:
    if artifact not in artifact_names:
        raise SystemExit(f"v14-e execution chain missing artifact: {artifact}")
if chain.get("runner_owned_external_benchmark_result_ready") != 1:
    raise SystemExit("v14-e execution chain runner-owned external readiness mismatch")
if chain.get("candidate_external_benchmark_result_ready") != 0 or chain.get("real_release_package_ready") != 0:
    raise SystemExit("v14-e execution chain promoted candidate/release unexpectedly")

external_chain = json.loads((run_dir / "benchmark" / "external_benchmark_execution_chain_manifest.json").read_text(encoding="utf-8"))
if external_chain.get("external_benchmark_execution_chain_ready") != 1:
    raise SystemExit("v14-e external execution chain is not ready")
if external_chain.get("external_benchmark_rows") != 1:
    raise SystemExit("v14-e external execution chain row count mismatch")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}
for gate in [
    "v14-d-scale-contract-inherited",
    "v14-e-ruler-compatible-niah-lite",
    "v14-e-mmap-provenance",
    "v14-e-runner-owned-external-smoke",
    "v14-e-no-route-jump",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v14-e decision did not pass: {gate}")
for gate in ["candidate-external-benchmark-result", "real-external-benchmark", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v14-e decision should remain blocked: {gate}")
PY

echo "v14-e RULER NIAH-lite smoke passed"
