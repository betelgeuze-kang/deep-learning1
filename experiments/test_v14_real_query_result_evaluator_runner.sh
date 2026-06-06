#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v14_real_query_result_evaluator_runner_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v14_real_query_result_evaluator_runner_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v14_real_query_result_evaluator_runner_smoke_runs/live_001"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v14-a summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v14-a summary row", 4)
    }
  ' "$summary_csv"
}

expect_decision_status() {
  local decision_csv="$1"
  local gate="$2"
  local expected="$3"

  awk -F, -v gate="$gate" -v expected="$expected" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    $idx["gate"] == gate {
      found = 1
      if ($idx["status"] != expected) die("v14-a decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v14-a decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

verify_execution_chain_manifest() {
  local run_dir="$1"
  local expected_external_rows="$2"

  python3 - "$run_dir" "$expected_external_rows" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
expected_external_rows = int(sys.argv[2])
manifest_path = run_dir / "evidence" / "execution_chain_manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
sha_manifest_path = run_dir / "sha256sums.txt"
sha_manifest = {}
with sha_manifest_path.open(encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        digest, rel = line.split(None, 1)
        sha_manifest[rel] = "sha256:" + digest

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def csv_rows(rel):
    path = run_dir / rel
    if not path.is_file():
        return 0
    with path.open(newline="", encoding="utf-8") as handle:
        return sum(1 for _ in csv.DictReader(handle))

def jsonl_rows(rel):
    path = run_dir / rel
    if not path.is_file():
        return 0
    with path.open(encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())

required = {
    "run_invocation",
    "requested_outputs_manifest",
    "reproducibility_manifest",
    "run_layout_manifest",
    "objective_requirements_manifest",
    "official_source_acquisition",
    "source_seed_live_fetch",
    "runtime_fetch_provenance",
    "source_snapshot_rows",
    "source_snapshot_manifest",
    "source_manifest",
    "queries",
    "dataset",
    "dataset_manifest",
    "chunk_pages",
    "chunk_offsets",
    "route_index",
    "route_memory_store",
    "store_manifest",
    "mmap_reads",
    "raw_predictions",
    "prediction_status",
    "evaluator_output",
    "evaluator_status",
    "metrics",
    "routeqa_rows",
    "benchmark_rows",
    "external_benchmark_rows",
    "external_benchmark_metrics",
    "external_benchmark_manifest",
    "external_benchmark_execution_chain_manifest",
    "resource_rows",
    "evidence_packet",
    "promotion_rows",
}
artifacts = manifest.get("artifacts", [])
artifact_names = {row.get("artifact") for row in artifacts}
missing = sorted(required - artifact_names)
if missing:
    raise SystemExit(f"execution chain manifest missing artifacts: {missing}")
if not artifacts or artifacts[0].get("artifact") != "run_invocation":
    raise SystemExit("execution chain manifest must begin with run_invocation")
for row in artifacts:
    path = run_dir / row["path"]
    if row.get("ready") != 1 or not path.is_file():
        raise SystemExit(f"execution chain artifact not ready or missing: {row}")
    if row.get("sha256") != sha256(path):
        raise SystemExit(f"execution chain artifact hash mismatch: {row['artifact']}")
    if sha_manifest.get(row["path"]) != row.get("sha256"):
        raise SystemExit(f"sha256sums.txt does not bind execution artifact: {row['artifact']}")
for rel in [
    "evidence/run_invocation.json",
    "evidence/requested_outputs_manifest.json",
    "evidence/reproducibility_manifest.json",
    "evidence/run_layout_manifest.json",
    "evidence/objective_requirements_manifest.json",
    "evidence/execution_chain_manifest.json",
    "source/source_snapshot_manifest.json",
    "benchmark/external_benchmark_rows.csv",
    "benchmark/external_benchmark_execution_chain_manifest.json",
    "predictions/raw_predictions.jsonl",
    "evaluator/evaluator_output.csv",
    "promotion/promotion_rows.csv",
]:
    if rel not in sha_manifest:
        raise SystemExit(f"sha256sums.txt missing required run artifact: {rel}")

checks = {
    "query_rows": jsonl_rows("dataset/queries.jsonl"),
    "dataset_rows": jsonl_rows("dataset/dataset.jsonl"),
    "raw_prediction_rows": jsonl_rows("predictions/raw_predictions.jsonl"),
    "evaluator_output_rows": csv_rows("evaluator/evaluator_output.csv"),
    "routeqa_rows": csv_rows("routeqa/routeqa_rows.csv"),
    "benchmark_rows": csv_rows("benchmark/benchmark_rows.csv"),
    "external_benchmark_rows": csv_rows("benchmark/external_benchmark_rows.csv"),
    "promotion_rows": csv_rows("promotion/promotion_rows.csv"),
}
for key, actual in checks.items():
    if manifest.get(key) != actual:
        raise SystemExit(f"execution chain {key} mismatch: manifest={manifest.get(key)} actual={actual}")
if manifest.get("external_benchmark_rows") != expected_external_rows:
    raise SystemExit("execution chain external benchmark row count mismatch")
if manifest.get("runner_owned_query_result_evaluator_ready") != 1:
    raise SystemExit("execution chain runner readiness mismatch")
if manifest.get("candidate_external_benchmark_result_ready") != 0:
    raise SystemExit("execution chain promoted candidate unexpectedly")
if manifest.get("real_external_benchmark_verified") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("execution chain real/release flags promoted unexpectedly")

layout = json.loads((run_dir / "evidence" / "run_layout_manifest.json").read_text(encoding="utf-8"))
if layout.get("manifest_scope") != "v14-a-run-output-layout-contract":
    raise SystemExit("run layout manifest scope mismatch")
if layout.get("run_layout_ready") != 1:
    raise SystemExit("run layout manifest readiness mismatch")
if manifest.get("run_layout_ready") != 1 or manifest.get("run_layout_manifest_ready") != 1:
    raise SystemExit("execution chain did not bind run layout readiness")
layout_groups = layout.get("layout_groups", [])
layout_scopes = {group.get("layout_scope") for group in layout_groups}
required_layout_scopes = {
    "source",
    "dataset",
    "route_memory_mmap_store",
    "prediction_evaluator_metrics",
    "routeqa_benchmark_external",
    "evidence_promotion",
}
if layout_scopes != required_layout_scopes:
    raise SystemExit(f"run layout scopes mismatch: {layout_scopes}")
layout_artifacts = []
for group in layout_groups:
    artifacts_for_group = group.get("artifacts", [])
    if group.get("artifact_rows") != len(artifacts_for_group):
        raise SystemExit("run layout artifact row count mismatch")
    if group.get("ready_rows") != len(artifacts_for_group):
        raise SystemExit("run layout group readiness mismatch")
    layout_artifacts.extend(artifacts_for_group)
required_layout_paths = {
    "source/official_source_acquisition_rows.csv",
    "source/source_seed_live_fetch_rows.csv",
    "source/runtime_fetch_provenance_rows.csv",
    "source/source_snapshot_rows.csv",
    "source/source_snapshot_manifest.json",
    "source/source_manifest.json",
    "dataset/queries.jsonl",
    "dataset/dataset.jsonl",
    "dataset/dataset_manifest.json",
    "store/chunk_pages.bin",
    "store/chunk_offsets",
    "store/route_index.bin",
    "store/route_memory_store.bin",
    "store/store_manifest.csv",
    "store/mmap_read_rows.csv",
    "predictions/raw_predictions.jsonl",
    "predictions/prediction_status.json",
    "evaluator/evaluator_output.csv",
    "evaluator/evaluator_status.json",
    "metrics/metrics.json",
    "routeqa/routeqa_rows.csv",
    "benchmark/benchmark_rows.csv",
    "benchmark/external_benchmark_rows.csv",
    "benchmark/external_benchmark_metrics.json",
    "benchmark/external_benchmark_manifest.json",
    "benchmark/external_benchmark_execution_chain_manifest.json",
    "evidence/run_invocation.json",
    "evidence/requested_outputs_manifest.json",
    "evidence/reproducibility_manifest.json",
    "evidence/evidence_packet.csv",
    "resource/resource_rows.csv",
    "promotion/promotion_rows.csv",
}
if {row.get("path") for row in layout_artifacts} != required_layout_paths:
    raise SystemExit("run layout artifact path set mismatch")
for row in layout_artifacts:
    path = run_dir / row["path"]
    if row.get("ready") != 1 or not path.is_file():
        raise SystemExit(f"run layout artifact not ready or missing: {row}")
    if row.get("sha256") != sha256(path):
        raise SystemExit(f"run layout artifact hash mismatch: {row['artifact']}")
    if sha_manifest.get(row["path"]) != row.get("sha256"):
        raise SystemExit(f"sha256sums.txt does not bind layout artifact: {row['artifact']}")
if layout.get("artifact_rows") != len(layout_artifacts) or layout.get("ready_rows") != len(layout_artifacts):
    raise SystemExit("run layout manifest aggregate count mismatch")

objective = json.loads((run_dir / "evidence" / "objective_requirements_manifest.json").read_text(encoding="utf-8"))
if objective.get("manifest_scope") != "v14-a-objective-requirements-audit":
    raise SystemExit("objective requirements manifest scope mismatch")
if objective.get("objective_requirements_ready") != 1:
    raise SystemExit("objective requirements readiness mismatch")
if manifest.get("objective_requirements_ready") != 1 or manifest.get("objective_requirements_manifest_ready") != 1:
    raise SystemExit("execution chain did not bind objective requirements readiness")
if objective.get("candidate_external_benchmark_result_ready") != 0:
    raise SystemExit("objective requirements promoted candidate unexpectedly")
if objective.get("real_external_benchmark_verified") != 0 or objective.get("real_release_package_ready") != 0:
    raise SystemExit("objective requirements real/release flags promoted unexpectedly")
required_objective_stages = [
    "official_source_acquisition",
    "dataset_checkout_snapshot",
    "query_set_materialization",
    "route_memory_store_build",
    "mmap_evidence_read",
    "raw_prediction_generation",
    "evaluator_invocation",
    "metrics_json",
    "routeqa_benchmark_rows",
    "evidence_packet",
    "promotion_rows",
]
objective_stages = objective.get("stages", [])
if [stage.get("stage") for stage in objective_stages] != required_objective_stages:
    raise SystemExit("objective requirements stage order mismatch")
stage_rows = {stage.get("stage"): stage.get("row_count") for stage in objective_stages}
if stage_rows["query_set_materialization"] != jsonl_rows("dataset/queries.jsonl"):
    raise SystemExit("objective query stage row count mismatch")
if stage_rows["route_memory_store_build"] != jsonl_rows("dataset/dataset.jsonl"):
    raise SystemExit("objective store stage row count mismatch")
if stage_rows["mmap_evidence_read"] != csv_rows("store/mmap_read_rows.csv"):
    raise SystemExit("objective mmap stage row count mismatch")
if stage_rows["raw_prediction_generation"] != jsonl_rows("predictions/raw_predictions.jsonl"):
    raise SystemExit("objective prediction stage row count mismatch")
if stage_rows["evaluator_invocation"] != csv_rows("evaluator/evaluator_output.csv"):
    raise SystemExit("objective evaluator stage row count mismatch")
if stage_rows["routeqa_benchmark_rows"] != csv_rows("benchmark/benchmark_rows.csv"):
    raise SystemExit("objective benchmark stage row count mismatch")
if stage_rows["evidence_packet"] != csv_rows("evidence/evidence_packet.csv"):
    raise SystemExit("objective evidence packet stage row count mismatch")
if stage_rows["promotion_rows"] != csv_rows("promotion/promotion_rows.csv"):
    raise SystemExit("objective promotion stage row count mismatch")
objective_paths = set()
for stage in objective_stages:
    artifacts_for_stage = stage.get("artifacts", [])
    if stage.get("ready") != 1:
        raise SystemExit(f"objective stage not ready: {stage.get('stage')}")
    if stage.get("stage") == "mmap_evidence_read" and stage.get("ready_row_count") != stage.get("expected_ready_row_count"):
        raise SystemExit("objective mmap ready row count mismatch")
    if stage.get("artifact_rows") != len(artifacts_for_stage):
        raise SystemExit("objective stage artifact row count mismatch")
    if stage.get("ready_artifact_rows") != len(artifacts_for_stage):
        raise SystemExit("objective stage artifact readiness mismatch")
    for artifact in artifacts_for_stage:
        objective_paths.add(artifact.get("path"))
        path = run_dir / artifact["path"]
        if artifact.get("ready") != 1 or not path.is_file():
            raise SystemExit(f"objective artifact not ready or missing: {artifact}")
        if artifact.get("sha256") != sha256(path):
            raise SystemExit(f"objective artifact hash mismatch: {artifact['artifact']}")
        if sha_manifest.get(artifact["path"]) != artifact.get("sha256"):
            raise SystemExit(f"sha256sums.txt does not bind objective artifact: {artifact['artifact']}")
if "evidence/objective_requirements_manifest.json" not in sha_manifest:
    raise SystemExit("sha256sums.txt missing objective requirements manifest")
if "source/official_source_acquisition_rows.csv" not in objective_paths:
    raise SystemExit("objective manifest does not bind official source acquisition")
for source_rel, mirror_rel in [
    ("source/official_source_acquisition_rows.csv", "evidence/official_source_acquisition_rows.csv"),
    ("source/source_seed_live_fetch_rows.csv", "evidence/source_seed_live_fetch_rows.csv"),
    ("source/runtime_fetch_provenance_rows.csv", "evidence/runtime_fetch_provenance_rows.csv"),
]:
    if mirror_rel not in objective_paths:
        raise SystemExit(f"objective manifest does not bind evidence mirror: {mirror_rel}")
    if sha256(run_dir / source_rel) != sha256(run_dir / mirror_rel):
        raise SystemExit(f"evidence mirror hash mismatch: {mirror_rel}")
if "store/route_memory_store.bin" not in objective_paths or "store/chunk_offsets" not in objective_paths:
    raise SystemExit("objective manifest does not bind mmap RouteMemory store")
if "evaluator/evaluator_output.csv" not in objective_paths or "metrics/metrics.json" not in objective_paths:
    raise SystemExit("objective manifest does not bind evaluator/metrics")

invocation = json.loads((run_dir / "evidence" / "run_invocation.json").read_text(encoding="utf-8"))
if invocation.get("receipt_scope") != "v14-a-runner-invocation":
    raise SystemExit("run invocation receipt scope mismatch")
if invocation.get("no_jump_neighbor") != 1 or invocation.get("backend") != "cpu" or invocation.get("store_mode") != "mmap":
    raise SystemExit("run invocation invariant mismatch")
requested = json.loads((run_dir / "evidence" / "requested_outputs_manifest.json").read_text(encoding="utf-8"))
if requested.get("manifest_scope") != "v14-a-requested-output-contract":
    raise SystemExit("requested output manifest scope mismatch")
if requested.get("requested_outputs_ready") != 1:
    raise SystemExit("requested output manifest readiness mismatch")
for flag in [
    "emit_raw_predictions",
    "emit_evaluator_output",
    "emit_routeqa_rows",
    "emit_resource_rows",
    "emit_evidence_packet",
    "emit_promotion_rows",
]:
    if requested.get(flag) != 1:
        raise SystemExit(f"requested output flag not recorded: {flag}")
for artifact in requested.get("artifacts", []):
    if artifact.get("requested") == 1:
        path = run_dir / artifact["path"]
        if artifact.get("ready") != 1 or not path.is_file():
            raise SystemExit("requested output artifact not ready")
        if artifact.get("sha256") != sha256(path):
            raise SystemExit("requested output artifact hash mismatch")
repro = json.loads((run_dir / "evidence" / "reproducibility_manifest.json").read_text(encoding="utf-8"))
if repro.get("manifest_scope") != "v14-a-direct-runner-reproducibility":
    raise SystemExit("reproducibility manifest scope mismatch")
if not isinstance(repro.get("command"), list) or "--source-acquisition" not in repro.get("command", []):
    raise SystemExit("reproducibility manifest command missing source acquisition")
if repro.get("requested_outputs_ready") != 1:
    raise SystemExit("reproducibility manifest requested output readiness mismatch")
for artifact in repro.get("inputs", []):
    if artifact.get("ready") == 1:
        path = run_dir / artifact["path"] if not Path(artifact["path"]).is_absolute() else Path(artifact["path"])
        if not path.is_file():
            raise SystemExit("reproducibility input artifact missing")
        if artifact.get("sha256") != sha256(path):
            raise SystemExit("reproducibility input artifact hash mismatch")
PY
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v14_real_query_result_evaluator_runner.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_invocation_ready" "1" "v14-a run invocation"
expect_summary_value "$SUMMARY_CSV" "source_chain_evidence_mirror_ready" "1" "v14-a source evidence mirror"
expect_summary_value "$SUMMARY_CSV" "source_acquisition_copied" "1" "v14-a source acquisition copy"
expect_summary_value "$SUMMARY_CSV" "source_seed_live_fetch_copied" "1" "v14-a source seed live fetch copy"
expect_summary_value "$SUMMARY_CSV" "source_seed_live_fetch_autodiscovered" "0" "v14-a source seed live fetch autodiscovery"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_provenance_copied" "1" "v14-a runtime fetch provenance copy"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_provenance_autodiscovered" "0" "v14-a runtime fetch provenance autodiscovery"
expect_summary_value "$SUMMARY_CSV" "source_chain_autodiscovery_ready" "1" "v14-a source chain resolved"
expect_summary_value "$SUMMARY_CSV" "source_snapshot_mode" "manifest" "v14-a source snapshot mode"
expect_summary_value "$SUMMARY_CSV" "source_snapshot_rows" "2" "v14-a source snapshot rows"
expect_summary_value "$SUMMARY_CSV" "source_snapshot_ready_rows" "0" "v14-a source snapshot ready rows"
expect_summary_value "$SUMMARY_CSV" "runner_owned_live_source_snapshot_rows" "0" "v14-a live source snapshots"
expect_summary_value "$SUMMARY_CSV" "dataset_rows" "7" "v14-a dataset rows"
expect_summary_value "$SUMMARY_CSV" "queries_ready" "1" "v14-a queries ready"
expect_summary_value "$SUMMARY_CSV" "dataset_manifest_ready" "1" "v14-a dataset manifest"
expect_summary_value "$SUMMARY_CSV" "store_route_rows" "7" "v14-a store rows"
expect_summary_value "$SUMMARY_CSV" "chunk_offsets_ready" "1" "v14-a chunk offsets"
expect_summary_value "$SUMMARY_CSV" "route_index_ready" "1" "v14-a route index"
expect_summary_value "$SUMMARY_CSV" "route_memory_store_ready" "1" "v14-a route memory store"
expect_summary_value "$SUMMARY_CSV" "store_manifest_ready" "1" "v14-a store manifest"
expect_summary_value "$SUMMARY_CSV" "raw_prediction_rows" "7" "v14-a raw predictions"
expect_summary_value "$SUMMARY_CSV" "prediction_status_ready" "1" "v14-a prediction status"
expect_summary_value "$SUMMARY_CSV" "evaluator_output_rows" "7" "v14-a evaluator rows"
expect_summary_value "$SUMMARY_CSV" "evaluator_status_ready" "1" "v14-a evaluator status"
expect_summary_value "$SUMMARY_CSV" "metrics_ready" "1" "v14-a metrics"
expect_summary_value "$SUMMARY_CSV" "routeqa_rows" "7" "v14-a routeqa rows"
expect_summary_value "$SUMMARY_CSV" "routeqa_bound_rows" "7" "v14-a routeqa bound rows"
expect_summary_value "$SUMMARY_CSV" "benchmark_rows" "7" "v14-a benchmark rows"
expect_summary_value "$SUMMARY_CSV" "benchmark_bound_rows" "7" "v14-a benchmark bound rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_rows" "0" "v14-a external benchmark rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_ready_rows" "0" "v14-a external benchmark ready rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_metrics_ready" "1" "v14-a external benchmark metrics"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_manifest_ready" "1" "v14-a external benchmark manifest"
expect_summary_value "$SUMMARY_CSV" "runner_owned_external_benchmark_result_ready" "0" "v14-a runner external benchmark"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_rows" "50" "v14-a evidence packet rows"
expect_summary_value "$SUMMARY_CSV" "requested_outputs_manifest_ready" "1" "v14-a requested outputs manifest"
expect_summary_value "$SUMMARY_CSV" "requested_outputs_ready" "1" "v14-a requested outputs"
expect_summary_value "$SUMMARY_CSV" "reproducibility_manifest_ready" "1" "v14-a reproducibility manifest"
expect_summary_value "$SUMMARY_CSV" "direct_cli_shape_ready" "0" "v14-a direct CLI shape"
expect_summary_value "$SUMMARY_CSV" "run_layout_manifest_ready" "1" "v14-a run layout manifest"
expect_summary_value "$SUMMARY_CSV" "run_layout_ready" "1" "v14-a run layout"
expect_summary_value "$SUMMARY_CSV" "objective_requirements_manifest_ready" "1" "v14-a objective requirements manifest"
expect_summary_value "$SUMMARY_CSV" "objective_requirements_ready" "1" "v14-a objective requirements"
expect_summary_value "$SUMMARY_CSV" "execution_chain_manifest_ready" "1" "v14-a execution chain manifest"
expect_summary_value "$SUMMARY_CSV" "promotion_rows" "4" "v14-a promotion rows"
expect_summary_value "$SUMMARY_CSV" "runner_owned_query_result_evaluator_ready" "1" "v14-a runner ready"
expect_summary_value "$SUMMARY_CSV" "candidate_external_benchmark_result_ready" "0" "v14-a candidate external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v14-a real external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v14-a release"
expect_summary_value "$SUMMARY_CSV" "action" "v14-runner-ready-await-independent-external-benchmark-run" "v14-a action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v14-a routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v14-a jump"

expect_decision_status "$DECISION_CSV" "source-chain" "pass"
expect_decision_status "$DECISION_CSV" "source-snapshot" "pass"
expect_decision_status "$DECISION_CSV" "dataset-materialization" "pass"
expect_decision_status "$DECISION_CSV" "store-mmap-read" "pass"
expect_decision_status "$DECISION_CSV" "raw-predictions" "pass"
expect_decision_status "$DECISION_CSV" "evaluator-output" "pass"
expect_decision_status "$DECISION_CSV" "metrics" "pass"
expect_decision_status "$DECISION_CSV" "benchmark-rows" "pass"
expect_decision_status "$DECISION_CSV" "evidence-packet" "pass"
expect_decision_status "$DECISION_CSV" "promotion-rows" "pass"
expect_decision_status "$DECISION_CSV" "runner-owned-query-result-evaluator" "pass"
expect_decision_status "$DECISION_CSV" "candidate-external-benchmark-result" "blocked"
expect_decision_status "$DECISION_CSV" "real-release-package" "blocked"

for file in \
  evidence/run_invocation.json \
  evidence/requested_outputs_manifest.json \
  evidence/reproducibility_manifest.json \
  evidence/run_layout_manifest.json \
  evidence/objective_requirements_manifest.json \
  evidence/official_source_acquisition_rows.csv \
  evidence/source_seed_live_fetch_rows.csv \
  evidence/runtime_fetch_provenance_rows.csv \
  source/official_source_acquisition_rows.csv \
  source/source_seed_live_fetch_rows.csv \
  source/runtime_fetch_provenance_rows.csv \
  source/source_snapshot_rows.csv \
  source/source_snapshot_manifest.json \
  dataset/queries.jsonl \
  dataset/dataset.jsonl \
  dataset/dataset_manifest.json \
  store/chunk_pages.bin \
  store/chunk_offsets \
  store/route_index.bin \
  store/store_manifest.csv \
  store/route_memory_store.bin \
  store/mmap_read_rows.csv \
  predictions/raw_predictions.jsonl \
  predictions/prediction_status.json \
  evaluator/evaluator_output.csv \
  evaluator/evaluator_status.json \
  metrics/metrics.json \
  routeqa/routeqa_rows.csv \
  benchmark/benchmark_rows.csv \
  benchmark/external_benchmark_rows.csv \
  benchmark/external_benchmark_metrics.json \
  benchmark/external_benchmark_manifest.json \
  evidence/evidence_packet.csv \
  evidence/execution_chain_manifest.json \
  promotion/promotion_rows.csv \
  sha256sums.txt
do
  if [[ ! -s "$RUN_DIR/$file" ]]; then
    echo "missing v14-a run artifact: $file" >&2
    exit 20
	  fi
done
verify_execution_chain_manifest "$RUN_DIR" 0

CANONICAL_QUERY_FILE="$ROOT_DIR/benchmarks/public-codebase-routeqa-v1/queries.jsonl"
CUSTOM_RUN_DIR="$RESULTS_DIR/v14_real_query_result_evaluator_runner_smoke_runs/direct_canonical_queries_001"
if [[ ! -s "$CANONICAL_QUERY_FILE" ]]; then
  echo "missing canonical public-codebase RouteQA query file: $CANONICAL_QUERY_FILE" >&2
  exit 21
fi

PATH="$ROOT_DIR:$PATH" routelm_benchmark_run \
  --source-acquisition "$RUN_DIR/evidence/official_source_acquisition_rows.csv" \
  --source-snapshot-mode manifest \
  --task public-codebase-routeqa-v1 \
  --repo "$ROOT_DIR" \
  --queries "$CANONICAL_QUERY_FILE" \
  --out "$CUSTOM_RUN_DIR" \
  --backend cpu \
  --store-mode mmap \
  --no-jump-neighbor \
  --emit-raw-predictions \
  --emit-evaluator-output \
  --emit-routeqa-rows \
  --emit-resource-rows \
  --emit-evidence-packet \
  --emit-promotion-rows >/dev/null

expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "dataset_rows" "7" "custom v14-a dataset rows"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "run_invocation_ready" "1" "custom v14-a run invocation"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "source_chain_evidence_mirror_ready" "1" "custom v14-a source evidence mirror"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "source_seed_live_fetch_copied" "1" "custom v14-a source seed live fetch copy"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "source_seed_live_fetch_autodiscovered" "1" "custom v14-a source seed live fetch autodiscovery"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "runtime_fetch_provenance_copied" "1" "custom v14-a runtime fetch provenance copy"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "runtime_fetch_provenance_autodiscovered" "1" "custom v14-a runtime fetch provenance autodiscovery"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "source_chain_autodiscovery_ready" "1" "custom v14-a source chain autodiscovery"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "queries_ready" "1" "custom v14-a queries ready"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "dataset_manifest_ready" "1" "custom v14-a dataset manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "raw_prediction_rows" "7" "custom v14-a raw predictions"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "prediction_status_ready" "1" "custom v14-a prediction status"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "evaluator_output_rows" "7" "custom v14-a evaluator rows"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "evaluator_status_ready" "1" "custom v14-a evaluator status"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "routeqa_bound_rows" "7" "custom v14-a routeqa rows"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "benchmark_bound_rows" "7" "custom v14-a benchmark rows"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "external_benchmark_rows" "0" "custom v14-a external benchmark rows"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "external_benchmark_metrics_ready" "1" "custom v14-a external benchmark metrics"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "external_benchmark_manifest_ready" "1" "custom v14-a external benchmark manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "runner_owned_external_benchmark_result_ready" "0" "custom v14-a runner external benchmark"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "runner_owned_query_result_evaluator_ready" "1" "custom v14-a runner ready"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "execution_chain_manifest_ready" "1" "custom v14-a execution chain manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "requested_outputs_manifest_ready" "1" "custom v14-a requested outputs manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "requested_outputs_ready" "1" "custom v14-a requested outputs"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "reproducibility_manifest_ready" "1" "custom v14-a reproducibility manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "direct_cli_shape_ready" "1" "custom v14-a direct CLI shape"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "run_layout_manifest_ready" "1" "custom v14-a run layout manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "run_layout_ready" "1" "custom v14-a run layout"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "objective_requirements_manifest_ready" "1" "custom v14-a objective requirements manifest"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "objective_requirements_ready" "1" "custom v14-a objective requirements"
python3 - "$CUSTOM_RUN_DIR/evidence/reproducibility_manifest.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if manifest.get("command", [""])[0] != "routelm_benchmark_run":
    raise SystemExit("direct canonical query smoke did not invoke bare routelm_benchmark_run")
if not manifest.get("shell_command", "").startswith("routelm_benchmark_run "):
    raise SystemExit("direct canonical query smoke shell command is not bare routelm_benchmark_run")
command = manifest.get("command", [])
if "--source-acquisition" not in command:
    raise SystemExit("direct canonical query smoke command missing source acquisition")
source_arg = command[command.index("--source-acquisition") + 1]
if not source_arg.endswith("/evidence/official_source_acquisition_rows.csv"):
    raise SystemExit("direct canonical query smoke did not use evidence source-acquisition mirror")
PY
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "candidate_external_benchmark_result_ready" "0" "custom v14-a external benchmark"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "routing_trigger_rate" "0.000000" "custom v14-a routing"
expect_summary_value "$CUSTOM_RUN_DIR/run_summary.csv" "active_jump_rate" "0.000000" "custom v14-a jump"
verify_execution_chain_manifest "$CUSTOM_RUN_DIR" 0

if [[ "${V14_LIVE_SOURCE_SNAPSHOT_QUERY_TEST:-0}" == "1" ]]; then
  LIVE_QUERY_FILE="$RESULTS_DIR/v14_real_query_result_evaluator_runner_ruler_queries.jsonl"
  cat >"$LIVE_QUERY_FILE" <<'JSONL'
{"query_id":"ruler_readme_scope","query_type":"official_source_readme","label_type":"present","expected_file":"README.md","expected_symbol":"RULER","pattern":"RULER generates synthetic examples","query_text":"Find the RULER synthetic example description."}
{"query_id":"ruler_task_registry","query_type":"official_source_code","label_type":"present","expected_file":"scripts/data/synthetic/constants.py","expected_symbol":"TASKS","pattern":"TASKS = {","query_text":"Find the RULER synthetic task registry."}
{"query_id":"ruler_missing_symbol","query_type":"missing_symbol","label_type":"missing","expected_file":"","expected_symbol":"","pattern":"definitely_missing_ruler_symbol","query_text":"Confirm a missing RULER symbol is absent."}
JSONL
  V13_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_LIVE=1 \
  V14_SOURCE_SNAPSHOT_MODE=live \
  V14_REPO_FROM_SOURCE_SNAPSHOT=ruler_repo \
  V14_QUERIES="$LIVE_QUERY_FILE" \
  V14_RULER_SYNTHETIC_SMOKE=1 \
  V14_LONGBENCH_V2_SMOKE=1 \
  V14_LONGBENCH_V2_OFFICIAL_SAMPLE=1 \
  V14_REAL_QUERY_RESULT_RUN_ID=live_ruler_snapshot_queries_001 \
    "$ROOT_DIR/experiments/run_v14_real_query_result_evaluator_runner.sh" --full >/dev/null

  LIVE_RUN_DIR="$RESULTS_DIR/v14_real_query_result_evaluator_runner_full_runs/live_ruler_snapshot_queries_001"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "run_invocation_ready" "1" "live RULER run invocation"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "source_snapshot_mode" "live" "live RULER snapshot mode"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "source_snapshot_ready_rows" "2" "live RULER source snapshot rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "runner_owned_live_source_snapshot_rows" "2" "live RULER owned snapshot rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "dataset_rows" "3" "live RULER dataset rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "queries_ready" "1" "live RULER queries ready"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "dataset_manifest_ready" "1" "live RULER dataset manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "chunk_offsets_ready" "1" "live RULER chunk offsets"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "route_index_ready" "1" "live RULER route index"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "store_manifest_ready" "1" "live RULER store manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "raw_prediction_rows" "3" "live RULER raw predictions"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "prediction_status_ready" "1" "live RULER prediction status"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "evaluator_output_rows" "3" "live RULER evaluator rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "evaluator_status_ready" "1" "live RULER evaluator status"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "routeqa_bound_rows" "3" "live RULER routeqa rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "benchmark_bound_rows" "3" "live RULER benchmark rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "runner_owned_query_result_evaluator_ready" "1" "live RULER runner ready"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "ruler_compatible_rows" "1" "live RULER-compatible rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "ruler_compatible_score" "100.00" "live RULER-compatible score"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "ruler_compatible_ready" "1" "live RULER-compatible ready"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_evaluator_ready" "1" "live official RULER evaluator readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_evaluator_returncode" "0" "live official RULER evaluator return code"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_rows" "9" "live official RULER generator rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_ready" "1" "live official RULER generator readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_returncode" "0" "live official RULER generator return code"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_evaluator_ready" "1" "live official RULER generated evaluator readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_evaluator_returncode" "0" "live official RULER generated evaluator return code"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_evaluator_score" "77.78" "live official RULER generated evaluator score"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_benchmark_rows" "3" "live official RULER generated benchmark rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_benchmark_ready" "1" "live official RULER generated benchmark readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_prediction_provenance_rows" "9" "live official RULER prediction provenance rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_extracted_prediction_rows" "9" "live official RULER extracted prediction rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_mmap_read_rows" "9" "live official RULER mmap rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_mmap_read_ready_rows" "9" "live official RULER mmap ready rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_mmap_extracted_prediction_rows" "9" "live official RULER mmap extracted rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "official_ruler_generator_mmap_verification_ready" "1" "live official RULER mmap verification"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_rows" "6" "live LongBench v2 rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_ready" "1" "live LongBench v2 readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_returncode" "0" "live LongBench v2 return code"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_score" "100.00" "live LongBench v2 score"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_benchmark_rows" "2" "live LongBench v2 benchmark rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_benchmark_ready" "1" "live LongBench v2 benchmark readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_prediction_provenance_rows" "6" "live LongBench v2 provenance rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_schema_rows" "12" "live LongBench v2 schema rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_schema_ready" "1" "live LongBench v2 schema readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_status_ready" "1" "live LongBench v2 status readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_rows" "12" "live LongBench v2 official sample rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_ready" "1" "live LongBench v2 official sample readiness"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_score" "0.00" "live LongBench v2 official sample score"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_prediction_provenance_rows" "12" "live LongBench v2 official sample provenance rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_api_response_ready" "1" "live LongBench v2 official sample API response"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_mmap_read_rows" "12" "live LongBench v2 official sample mmap rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_mmap_read_ready_rows" "12" "live LongBench v2 official sample mmap ready rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_mmap_prediction_match_rows" "12" "live LongBench v2 official sample mmap prediction matches"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "longbench_v2_official_sample_mmap_verification_ready" "1" "live LongBench v2 official sample mmap verification"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_rows" "5" "live run-level external benchmark rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_ready_rows" "5" "live run-level external benchmark readiness rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_dataset_rows" "27" "live run-level external benchmark dataset rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_raw_prediction_rows" "27" "live run-level external benchmark raw predictions"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_prediction_provenance_rows" "27" "live run-level external benchmark provenance rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_extracted_prediction_rows" "9" "live run-level external benchmark extracted rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_mmap_read_rows" "21" "live run-level external benchmark mmap rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_mmap_prediction_match_rows" "21" "live run-level external benchmark mmap prediction matches"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_mmap_verification_ready_rows" "4" "live run-level external benchmark mmap ready rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_average_score" "66.67" "live run-level external benchmark average score"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_metrics_ready" "1" "live run-level external benchmark metrics"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_manifest_ready" "1" "live run-level external benchmark manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_execution_chain_ready_rows" "5" "live run-level external benchmark execution chain rows"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "external_benchmark_execution_chain_ready" "1" "live run-level external benchmark execution chain"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "runner_owned_external_benchmark_result_ready" "1" "live runner-owned external benchmark result"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "source_chain_evidence_mirror_ready" "1" "live source evidence mirror"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "execution_chain_manifest_ready" "1" "live execution chain manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "requested_outputs_manifest_ready" "1" "live requested outputs manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "requested_outputs_ready" "1" "live requested outputs"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "reproducibility_manifest_ready" "1" "live reproducibility manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "direct_cli_shape_ready" "1" "live direct CLI shape"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "run_layout_manifest_ready" "1" "live run layout manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "run_layout_ready" "1" "live run layout"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "objective_requirements_manifest_ready" "1" "live objective requirements manifest"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "objective_requirements_ready" "1" "live objective requirements"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "candidate_external_benchmark_result_ready" "0" "live RULER candidate external benchmark"
  expect_summary_value "$LIVE_RUN_DIR/run_summary.csv" "real_release_package_ready" "0" "live RULER release"
  for file in \
    evidence/run_invocation.json \
    evidence/requested_outputs_manifest.json \
    evidence/reproducibility_manifest.json \
    evidence/run_layout_manifest.json \
    evidence/objective_requirements_manifest.json \
    evidence/official_source_acquisition_rows.csv \
    evidence/source_seed_live_fetch_rows.csv \
    evidence/runtime_fetch_provenance_rows.csv \
    benchmark/ruler_synthetic/niah_dataset.jsonl \
    benchmark/ruler_synthetic/niah_single_1.jsonl \
    benchmark/ruler_synthetic/ruler_evaluator_rows.csv \
    benchmark/ruler_synthetic/official_evaluator_status.json \
    benchmark/ruler_synthetic/summary-niah_single_1.csv \
    benchmark/ruler_synthetic/submission.csv \
    benchmark/ruler_synthetic/official_generator/niah_single_1/validation.jsonl \
    benchmark/ruler_synthetic/official_generator/niah_multikey_2/validation.jsonl \
    benchmark/ruler_synthetic/official_generator/niah_multikey_3/validation.jsonl \
    benchmark/ruler_synthetic/official_generator_eval/niah_single_1.jsonl \
    benchmark/ruler_synthetic/official_generator_eval/niah_multikey_2.jsonl \
    benchmark/ruler_synthetic/official_generator_eval/niah_multikey_3.jsonl \
    benchmark/ruler_synthetic/official_generator_eval/summary.csv \
    benchmark/ruler_synthetic/official_generator_eval/submission.csv \
    benchmark/ruler_synthetic/official_generator_status.json \
    benchmark/ruler_synthetic/official_generator_benchmark_rows.csv \
    benchmark/ruler_synthetic/official_generator_metrics.json \
    benchmark/ruler_synthetic/official_generator_prediction_provenance.csv \
    benchmark/ruler_synthetic/official_generator_store/route_memory_store.bin \
    benchmark/ruler_synthetic/official_generator_store/route_index.bin \
    benchmark/ruler_synthetic/official_generator_store/chunk_offsets \
    benchmark/ruler_synthetic/official_generator_store/mmap_read_rows.csv \
    benchmark/ruler_synthetic/official_generator_store/store_status.json \
    dataset/dataset_manifest.json \
    store/route_index.bin \
    store/store_manifest.csv \
    predictions/prediction_status.json \
    evaluator/evaluator_status.json \
    evidence/execution_chain_manifest.json \
    benchmark/longbench_v2/longbench_v2_benchmark_rows.csv \
    benchmark/longbench_v2/longbench_v2_metrics.json \
    benchmark/longbench_v2/longbench_v2_manifest.json \
    benchmark/longbench_v2/longbench_v2_prediction_provenance.csv \
    benchmark/longbench_v2/longbench_v2_schema_rows.csv \
    benchmark/longbench_v2/longbench_v2_status.json \
    benchmark/longbench_v2/dataset/longbench_v2_official_sample_dataset.jsonl \
    benchmark/longbench_v2/results/routelm_longbench_v2_official_sample.jsonl \
    benchmark/longbench_v2/longbench_v2_official_sample_prediction_provenance.csv \
    benchmark/longbench_v2/official_sample/longbench_v2_official_sample_api_response.json \
    benchmark/longbench_v2/official_sample/longbench_v2_official_info.json \
    benchmark/longbench_v2/official_sample_store/route_memory_store.bin \
    benchmark/longbench_v2/official_sample_store/route_index.bin \
    benchmark/longbench_v2/official_sample_store/chunk_offsets \
    benchmark/longbench_v2/official_sample_store/mmap_read_rows.csv \
    benchmark/longbench_v2/official_sample_store/store_status.json \
    benchmark/longbench_v2/result.txt \
    benchmark/external_benchmark_rows.csv \
    benchmark/external_benchmark_metrics.json \
    benchmark/external_benchmark_manifest.json \
    benchmark/external_benchmark_execution_chain_manifest.json
  do
    if [[ ! -s "$LIVE_RUN_DIR/$file" ]]; then
      echo "missing live RULER-compatible artifact: $file" >&2
      exit 30
    fi
  done
  verify_execution_chain_manifest "$LIVE_RUN_DIR" 5
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      rows++
      if ($idx["oracle_prediction_used"] != "0") {
        print "official RULER generated prediction unexpectedly used oracle output" > "/dev/stderr"
        exit 31
      }
      if ($idx["input_extractor_prediction_used"] != "1" || $idx["extracted"] != "1") {
        print "official RULER generated prediction was not input-extracted" > "/dev/stderr"
        exit 32
      }
      if ($idx["mmap_read_ready"] != "1" || $idx["mmap_extracted_prediction_used"] != "1" || $idx["mmap_prediction_matches_raw"] != "1") {
        print "official RULER generated prediction was not mmap-verified" > "/dev/stderr"
        exit 39
      }
    }
    END {
      if (rows != 9) {
        print "expected nine official RULER generated prediction provenance rows" > "/dev/stderr"
        exit 33
      }
    }
  ' "$LIVE_RUN_DIR/benchmark/ruler_synthetic/official_generator_prediction_provenance.csv"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      rows++
      ready += ($idx["benchmark_result_ready"] == "1")
    }
    END {
      if (rows != 3 || ready != 3) {
        print "expected three ready official RULER generated benchmark rows" > "/dev/stderr"
        exit 34
      }
    }
  ' "$LIVE_RUN_DIR/benchmark/ruler_synthetic/official_generator_benchmark_rows.csv"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      rows++
      ready += ($idx["benchmark_result_ready"] == "1")
      candidate += ($idx["candidate_external_benchmark_result_ready"] == "1")
      real += ($idx["real_external_benchmark_verified"] == "1")
      if ($idx["oracle_prediction_used"] != "0" || $idx["runner_owned"] != "1" || $idx["independent"] != "0") {
        print "run-level external benchmark row has invalid provenance flags" > "/dev/stderr"
        exit 35
      }
    }
    END {
      if (rows != 5 || ready != 5 || candidate != 0 || real != 0) {
        print "expected five ready non-candidate run-level external benchmark rows" > "/dev/stderr"
        exit 36
      }
    }
  ' "$LIVE_RUN_DIR/benchmark/external_benchmark_rows.csv"
  python3 - "$LIVE_RUN_DIR/benchmark/external_benchmark_metrics.json" "$LIVE_RUN_DIR/benchmark/external_benchmark_manifest.json" "$LIVE_RUN_DIR/benchmark/external_benchmark_execution_chain_manifest.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

metrics = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
manifest = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
chain_path = Path(sys.argv[3])
chain = json.loads(chain_path.read_text(encoding="utf-8"))
run_dir = chain_path.parents[1]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

if metrics.get("external_benchmark_rows") != 5:
    raise SystemExit("external benchmark metrics row count mismatch")
if metrics.get("external_benchmark_dataset_rows") != 27:
    raise SystemExit("external benchmark metrics dataset count mismatch")
if metrics.get("external_benchmark_mmap_read_rows") != 21:
    raise SystemExit("external benchmark metrics mmap row count mismatch")
if metrics.get("external_benchmark_mmap_prediction_match_rows") != 21:
    raise SystemExit("external benchmark metrics mmap prediction match count mismatch")
if metrics.get("external_benchmark_mmap_verification_ready_rows") != 4:
    raise SystemExit("external benchmark metrics mmap readiness count mismatch")
if metrics.get("external_benchmark_execution_chain_ready_rows") != 5:
    raise SystemExit("external benchmark metrics execution-chain row count mismatch")
if metrics.get("external_benchmark_execution_chain_ready") != 1:
    raise SystemExit("external benchmark metrics execution-chain readiness mismatch")
if metrics.get("runner_owned_external_benchmark_result_ready") != 1:
    raise SystemExit("external benchmark metrics readiness mismatch")
if metrics.get("candidate_external_benchmark_result_ready") != 0 or metrics.get("real_external_benchmark_verified") != 0:
    raise SystemExit("external benchmark metrics promoted unexpectedly")
artifacts = manifest.get("artifacts", [])
if len(artifacts) < 7:
    raise SystemExit("external benchmark manifest missing artifact bindings")
if manifest.get("runner_owned_external_benchmark_result_ready") != 1:
    raise SystemExit("external benchmark manifest readiness mismatch")
if manifest.get("external_benchmark_execution_chain_ready") != 1:
    raise SystemExit("external benchmark manifest execution-chain readiness mismatch")
if chain.get("external_benchmark_rows") != 5 or chain.get("external_benchmark_execution_chain_ready_rows") != 5:
    raise SystemExit("external benchmark execution-chain row readiness mismatch")
if chain.get("external_benchmark_execution_chain_ready") != 1:
    raise SystemExit("external benchmark execution-chain readiness mismatch")
if chain.get("candidate_external_benchmark_result_ready") != 0 or chain.get("real_external_benchmark_verified") != 0:
    raise SystemExit("external benchmark execution-chain promoted unexpectedly")
for row in chain.get("rows", []):
    if row.get("execution_chain_ready") != 1:
        raise SystemExit("external benchmark execution-chain row not ready")
    if row.get("runner_owned") != 1 or row.get("independent") != 0 or row.get("oracle_prediction_used") != 0:
        raise SystemExit("external benchmark execution-chain provenance flags mismatch")
    artifact_names = {artifact.get("artifact") for artifact in row.get("artifacts", [])}
    for required in ["source_acquisition", "source_snapshot_rows", "dataset", "raw_predictions", "evaluator_summary", "metrics", "prediction_provenance"]:
        if required not in artifact_names:
            raise SystemExit(f"external benchmark execution-chain artifact missing: {required}")
    for artifact in row.get("artifacts", []):
        path = run_dir / artifact["path"]
        if artifact.get("ready") != 1 or not path.is_file():
            raise SystemExit("external benchmark execution-chain artifact not ready")
        if artifact.get("sha256") != sha256(path):
            raise SystemExit("external benchmark execution-chain artifact hash mismatch")
PY
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      rows++
      present += ($idx["present_in_all_dataset_rows"] == "1")
      mentioned += ($idx["mentioned_in_official_readme"] == "1")
    }
    END {
      if (rows != 12 || present != 12 || mentioned != 12) {
        print "LongBench v2 schema rows are not fully bound to dataset and README" > "/dev/stderr"
        exit 37
      }
    }
  ' "$LIVE_RUN_DIR/benchmark/longbench_v2/longbench_v2_schema_rows.csv"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      rows++
      official += ($idx["official_dataset_server_row_used"] == "1")
      oracle += ($idx["oracle_prediction_used"] == "1")
      mmap_ready += ($idx["mmap_read_ready"] == "1")
      mmap_pred += ($idx["mmap_baseline_prediction_used"] == "1")
      mmap_match += ($idx["mmap_prediction_matches_raw"] == "1")
    }
    END {
      if (rows != 12 || official != 12 || oracle != 0 || mmap_ready != 12 || mmap_pred != 12 || mmap_match != 12) {
        print "LongBench v2 official sample provenance is not bound to official rows without oracle prediction" > "/dev/stderr"
        exit 38
      }
    }
  ' "$LIVE_RUN_DIR/benchmark/longbench_v2/longbench_v2_official_sample_prediction_provenance.csv"
fi

echo "v14 real query/result/evaluator runner smoke passed"
