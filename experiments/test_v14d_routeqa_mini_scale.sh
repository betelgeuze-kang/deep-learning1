#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v14d_routeqa_mini_scale_summary.csv"
DECISION_CSV="$RESULTS_DIR/v14d_routeqa_mini_scale_decision.csv"
RUNS_DIR="$RESULTS_DIR/v14d_routeqa_mini_scale_runs"

"$ROOT_DIR/experiments/run_v14d_routeqa_mini_scale.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" "$RUNS_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
runs_dir = Path(sys.argv[3])

with summary_csv.open(newline="", encoding="utf-8") as handle:
    summary_rows = list(csv.DictReader(handle))

if len(summary_rows) != 2:
    raise SystemExit(f"expected two v14-d summary rows, got {len(summary_rows)}")

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

by_target = {as_int(row, "routeqa_mini_target_rows"): row for row in summary_rows}
if set(by_target) != {100, 150}:
    raise SystemExit(f"unexpected v14-d target set: {sorted(by_target)}")

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def jsonl_count(path):
    with path.open(encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())

required_artifacts = [
    "dataset/queries.jsonl",
    "dataset/dataset_manifest.json",
    "predictions/prediction_lineage.jsonl",
    "predictions/prediction_source_summary.json",
    "traces/mmap_prediction_trace.jsonl",
    "traces/selected_candidate_trace.jsonl",
    "nlg/generator_hint_transcript.jsonl",
    "evidence/grounding_rows.csv",
    "benchmark/baseline_comparison_rows.csv",
    "benchmark/baseline_negative_case_rows.csv",
    "metrics/baseline_comparison_metrics.json",
    "resource/baseline_latency_rows.csv",
    "resource/resource_envelope.json",
    "promotion/baseline_promotion_guard_rows.csv",
    "evidence/run_layout_manifest.json",
    "evidence/objective_requirements_manifest.json",
    "evidence/execution_chain_manifest.json",
]

for target, row in sorted(by_target.items()):
    run_dir = runs_dir / f"scale_{target}"
    if not run_dir.is_dir():
        raise SystemExit(f"missing v14-d run dir: {run_dir}")
    if not (run_dir / "sha256sums.txt").is_file() or (run_dir / "sha256sums.txt").stat().st_size == 0:
        raise SystemExit(f"missing v14-d sha256 manifest for target {target}")

    expected_equal = {
        "dataset_rows": target,
        "routeqa_mini_target_rows": target,
        "routeqa_mini_ready": 1,
        "prediction_lineage_ready": 1,
        "prediction_lineage_rows": target,
        "prediction_source_summary_ready": 1,
        "no_extractor_prediction_ready": 1,
        "promoted_prediction_rows": target,
        "promoted_route_memory_prediction_rows": target,
        "generator_hint_nlg_ready": 1,
        "generator_hint_nlg_rows": target,
        "proposal_hint_nlg_used_rows": target,
        "grounding_rows": target,
        "shortcut_negative_suite_ready": 1,
        "baseline_comparison_ready": 1,
        "baseline_rows": 6,
        "baseline_negative_case_rows": 66,
        "baseline_latency_rows": 6,
        "baseline_promotion_guard_rows": 6,
        "route_memory_safety_dominates_baselines": 1,
        "input_extractor_baseline_only": 1,
        "baseline_promotion_guard_ready": 1,
        "resource_envelope_ready": 1,
        "run_dir_under_5gb": 1,
        "cpu_canonical": 1,
        "hip_optional_parity": 1,
        "run_layout_ready": 1,
        "objective_requirements_ready": 1,
        "execution_chain_manifest_ready": 1,
        "requested_outputs_ready": 1,
        "runner_owned_query_result_evaluator_ready": 1,
        "candidate_external_benchmark_result_ready": 0,
        "real_external_benchmark_verified": 0,
        "real_release_package_ready": 0,
    }
    for field, expected in expected_equal.items():
        actual = as_int(row, field)
        if actual != expected:
            raise SystemExit(f"v14-d target {target} {field}: expected {expected}, got {actual}")
    if as_float(row, "routing_trigger_rate") != 0.0 or as_float(row, "active_jump_rate") != 0.0:
        raise SystemExit(f"v14-d target {target} route/jump rates are not zero")

    sha_manifest = {}
    with (run_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                digest, rel = line.strip().split(None, 1)
                sha_manifest[rel] = "sha256:" + digest

    for rel in required_artifacts:
        path = run_dir / rel
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing v14-d artifact for target {target}: {rel}")
        if sha_manifest.get(rel) != sha256(path):
            raise SystemExit(f"sha256 manifest does not bind v14-d target {target}: {rel}")

    if jsonl_count(run_dir / "dataset/queries.jsonl") != target:
        raise SystemExit(f"v14-d target {target} query count mismatch")
    if jsonl_count(run_dir / "predictions/prediction_lineage.jsonl") != target:
        raise SystemExit(f"v14-d target {target} prediction lineage count mismatch")
    if jsonl_count(run_dir / "nlg/generator_hint_transcript.jsonl") != target:
        raise SystemExit(f"v14-d target {target} generator transcript count mismatch")
    if len(read_csv(run_dir / "evidence/grounding_rows.csv")) != target:
        raise SystemExit(f"v14-d target {target} grounding row count mismatch")

    baseline_rows = read_csv(run_dir / "benchmark/baseline_comparison_rows.csv")
    negative_rows = read_csv(run_dir / "benchmark/baseline_negative_case_rows.csv")
    latency_rows = read_csv(run_dir / "resource/baseline_latency_rows.csv")
    guard_rows = read_csv(run_dir / "promotion/baseline_promotion_guard_rows.csv")
    if len(baseline_rows) != 6 or len(negative_rows) != 66 or len(latency_rows) != 6 or len(guard_rows) != 6:
        raise SystemExit(f"v14-d target {target} baseline artifact counts mismatch")
    baseline_ids = {row["baseline_id"] for row in baseline_rows}
    expected_baseline_ids = {
        "input_extractor",
        "bm25_lexical",
        "route_memory_retrieval_only",
        "route_memory_exact_value_read",
        "route_memory_proposal_hint",
        "tiny_generator_hint_nlg",
    }
    if baseline_ids != expected_baseline_ids:
        raise SystemExit(f"v14-d target {target} baseline ids mismatch")

    metrics = json.loads((run_dir / "metrics" / "baseline_comparison_metrics.json").read_text(encoding="utf-8"))
    for field in [
        "baseline_comparison_ready",
        "route_memory_safety_dominates_baselines",
        "input_extractor_baseline_only",
        "baseline_promotion_guard_ready",
    ]:
        if metrics.get(field) != 1:
            raise SystemExit(f"v14-d target {target} metrics field not ready: {field}")
    if metrics.get("candidate_external_benchmark_result_ready") != 0 or metrics.get("real_release_package_ready") != 0:
        raise SystemExit(f"v14-d target {target} external/release metrics promoted unexpectedly")

    resource = json.loads((run_dir / "resource" / "resource_envelope.json").read_text(encoding="utf-8"))
    if resource.get("query_count") != target or resource.get("run_dir_under_5gb") != 1 or resource.get("resource_envelope_ready") != 1:
        raise SystemExit(f"v14-d target {target} resource envelope mismatch")

    layout = json.loads((run_dir / "evidence" / "run_layout_manifest.json").read_text(encoding="utf-8"))
    objective = json.loads((run_dir / "evidence" / "objective_requirements_manifest.json").read_text(encoding="utf-8"))
    chain = json.loads((run_dir / "evidence" / "execution_chain_manifest.json").read_text(encoding="utf-8"))
    layout_scopes = {item.get("layout_scope") for item in layout.get("layout_groups", [])}
    if "baseline_comparison" not in layout_scopes or "resource_envelope" not in layout_scopes:
        raise SystemExit(f"v14-d target {target} layout manifest missing scale scopes")
    objective_stages = {item.get("stage"): item for item in objective.get("stages", [])}
    for stage in ["prediction_lineage", "shortcut_negative_suite", "baseline_comparison", "resource_envelope"]:
        if objective_stages.get(stage, {}).get("ready") != 1:
            raise SystemExit(f"v14-d target {target} objective stage not ready: {stage}")
    chain_artifacts = {item.get("artifact") for item in chain.get("artifacts", [])}
    for artifact in [
        "prediction_lineage",
        "baseline_comparison_rows",
        "baseline_comparison_metrics",
        "resource_envelope",
        "run_layout_manifest",
        "objective_requirements_manifest",
    ]:
        if artifact not in chain_artifacts:
            raise SystemExit(f"v14-d target {target} execution chain missing: {artifact}")
    if chain.get("candidate_external_benchmark_result_ready") != 0 or chain.get("real_release_package_ready") != 0:
        raise SystemExit(f"v14-d target {target} execution chain promoted external/release unexpectedly")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row["status"] for row in csv.DictReader(handle)}

for target in [100, 150]:
    for suffix in [
        "routeqa-mini",
        "lineage-contracts",
        "negative-nlg-resource",
        "baseline-comparison",
        "runtime-binding",
    ]:
        gate = f"v14-d-scale-{target}-{suffix}"
        if decisions.get(gate) != "pass":
            raise SystemExit(f"v14-d decision {gate} did not pass")
if decisions.get("v14-d-routeqa-mini-scale-set") != "pass":
    raise SystemExit("v14-d scale-set decision did not pass")
if decisions.get("candidate-external-benchmark-result") != "blocked":
    raise SystemExit("v14-d candidate external benchmark gate should remain blocked")
if decisions.get("real-release-package") != "blocked":
    raise SystemExit("v14-d real release gate should remain blocked")
PY

echo "v14-d RouteQA-mini scale smoke passed"
