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

PREFIX="v13_public_codebase_routeqa"
BINDER_PREFIX="v13_real_run_binder_manifest"
TRANSCRIPT_PREFIX="v13_real_nlg_transcript"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_public_codebase_routeqa_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  TRANSCRIPT_PREFIX="v13_real_nlg_transcript_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_public_codebase_routeqa_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  TRANSCRIPT_PREFIX="v13_real_nlg_transcript_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_PUBLIC_CODEBASE_ROUTEQA_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_PUBLIC_CODEBASE_ROUTEQA_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

ROUTEQA_PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
TRANSCRIPT_SUMMARY_CSV="$RESULTS_DIR/${TRANSCRIPT_PREFIX}_summary.csv"

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  "$ROOT_DIR/experiments/run_v13_real_nlg_transcript.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V13_REAL_NLG_TRANSCRIPT_RUN_DIR="$RUN_DIR" \
    "$ROOT_DIR/experiments/run_v13_real_nlg_transcript.sh" "${RUN_ARGS[@]}" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$RUN_SOURCE" "$ROUTEQA_PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$TRANSCRIPT_SUMMARY_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

root_dir = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
run_source = sys.argv[3]
packet_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
transcript_summary_csv = Path(sys.argv[7])

required_trace_files = [
    "runner_manifest.json",
    "evaluator_manifest.json",
    "query_trace.csv",
    "evaluator_output.csv",
    "metrics_recomputed.csv",
    "command_receipt.txt",
]
required_package_files = [
    "source_manifest.json",
    "dataset.jsonl",
    "split_manifest.json",
    "license.txt",
    "metric_spec.json",
    "baselines/bm25.csv",
    "baselines/symbolic_upper_bound.csv",
    "baselines/route_memory_student.csv",
    "results/route_memory_results.jsonl",
    "results/summary_metrics.csv",
]

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

def file_uri_to_path(uri):
    if not uri.startswith("file://"):
        return None
    return Path(unquote(uri[7:]))

def read_json(path):
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}

def read_jsonl(path):
    rows = []
    if not path.is_file():
        return rows
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    rows.append(json.loads(line))
    except Exception:
        return []
    return rows

def metric_map(path):
    rows = read_csv(path)
    out = {}
    for row in rows:
        try:
            out[row.get("metric", "")] = float(row.get("value", "0") or 0.0)
        except ValueError:
            out[row.get("metric", "")] = 0.0
    return out

run_hash_entries, run_hash_verified = verify_manifest(run_dir)
run_hash_manifest_ready = int(run_hash_entries > 0 and run_hash_entries == run_hash_verified)

benchmark_dir = run_dir / "benchmark"
trace_hash_entries, trace_hash_verified = verify_manifest(benchmark_dir)
trace_hash_manifest_ready = int(trace_hash_entries > 0 and trace_hash_entries == trace_hash_verified)
trace_required_found = sum(1 for rel in required_trace_files if (benchmark_dir / rel).is_file())

runner_manifest = read_json(benchmark_dir / "runner_manifest.json")
artifact_dir = Path(runner_manifest.get("artifact_dir", ""))
dataset_path = file_uri_to_path(runner_manifest.get("dataset_uri", "")) or (artifact_dir / "dataset.jsonl")
result_path = file_uri_to_path(runner_manifest.get("result_uri", "")) or (artifact_dir / "results" / "route_memory_results.jsonl")

package_hash_entries, package_hash_verified = verify_manifest(artifact_dir)
package_hash_manifest_ready = int(package_hash_entries > 0 and package_hash_entries == package_hash_verified)
package_required_found = sum(1 for rel in required_package_files if (artifact_dir / rel).is_file())

dataset_hash_match = 0
if dataset_path.is_file() and runner_manifest.get("dataset_hash", "").startswith("sha256:"):
    dataset_hash_match = int("sha256:" + sha256(dataset_path) == runner_manifest.get("dataset_hash"))
result_hash_match = 0
if result_path.is_file() and runner_manifest.get("result_hash", "").startswith("sha256:"):
    result_hash_match = int("sha256:" + sha256(result_path) == runner_manifest.get("result_hash"))

source_manifest = read_json(artifact_dir / "source_manifest.json")
source_rows = source_manifest.get("files", []) if isinstance(source_manifest.get("files", []), list) else []
source_file_rows = len(source_rows)
source_hash_verified_rows = 0
local_source_rows = 0
external_source_rows = 0
for row in source_rows:
    uri = str(row.get("source_uri", ""))
    if uri.startswith("file://"):
        local_source_rows += 1
        path = file_uri_to_path(uri)
        if path and path.is_file() and "sha256:" + sha256(path) == row.get("sha256"):
            source_hash_verified_rows += 1
    elif uri.startswith(("https://", "http://")):
        external_source_rows += 1

dataset_rows = read_jsonl(dataset_path)
result_rows = read_jsonl(result_path)
query_trace_rows = read_csv(benchmark_dir / "query_trace.csv")
evaluator_output_rows = read_csv(benchmark_dir / "evaluator_output.csv")
package_metrics = metric_map(artifact_dir / "results" / "summary_metrics.csv")
trace_metrics = metric_map(benchmark_dir / "metrics_recomputed.csv")

dataset_by_id = {row.get("query_id", ""): row for row in dataset_rows}
result_by_id = {row.get("query_id", ""): row for row in result_rows}
trace_by_id = {row.get("query_id", ""): row for row in query_trace_rows}
eval_by_id = {row.get("query_id", ""): row for row in evaluator_output_rows}
dataset_ids = set(dataset_by_id)
result_ids = set(result_by_id)
trace_ids = set(trace_by_id)
eval_ids = set(eval_by_id)
common_ids = dataset_ids & result_ids & trace_ids & eval_ids
all_ids_match = int(dataset_ids == result_ids == trace_ids == eval_ids and len(dataset_ids) > 0)

present_like_rows = sum(1 for row in dataset_rows if row.get("label_type") in {"present", "multi_hop"})
missing_rows = sum(1 for row in dataset_rows if row.get("label_type") == "missing")
near_miss_rows = sum(1 for row in dataset_rows if row.get("label_type") == "near_miss")
multi_hop_rows = sum(1 for row in dataset_rows if row.get("label_type") == "multi_hop")

dataset_bound_rows = sum(1 for row in query_trace_rows if str(row.get("dataset_bound", "")) == "1")
result_bound_rows = sum(1 for row in query_trace_rows if str(row.get("result_bound", "")) == "1")
runner_owned_evaluator_rows = sum(1 for row in query_trace_rows if str(row.get("runner_owned_evaluator", "")) == "1")
independent_evaluator_rows = sum(1 for row in query_trace_rows if str(row.get("independent_evaluator", "")) == "1")

routeqa_rows = []
span_sum = 0
chunk_sum = 0
wrong_sum = 0
missing_eval_rows = 0
missing_ok = 0
near_eval_rows = 0
near_fp_sum = 0
result_prediction_matches = 0
for query_id in sorted(common_ids):
    dataset = dataset_by_id[query_id]
    result = result_by_id[query_id]
    trace = trace_by_id[query_id]
    evaluation = eval_by_id[query_id]
    label_type = dataset.get("label_type", "")
    prediction = str(evaluation.get("prediction", ""))
    result_prediction = str(result.get("prediction", ""))
    if prediction == result_prediction:
        result_prediction_matches += 1
    span = int(float(evaluation.get("span_exact", "0") or 0))
    chunk = int(float(evaluation.get("chunk_exact", "0") or 0))
    missing_abstain = int(float(evaluation.get("missing_abstain", "0") or 0))
    near_fp = int(float(evaluation.get("near_miss_false_positive", "0") or 0))
    wrong = int(float(evaluation.get("wrong_answer", "1") or 1))
    span_sum += span
    chunk_sum += chunk
    wrong_sum += wrong
    if label_type == "missing":
        missing_eval_rows += 1
        missing_ok += missing_abstain
    if label_type == "near_miss":
        near_eval_rows += 1
        near_fp_sum += near_fp
    routeqa_bound = int(
        str(trace.get("dataset_bound", "")) == "1"
        and str(trace.get("result_bound", "")) == "1"
        and str(trace.get("runner_owned_evaluator", "")) == "1"
        and prediction == result_prediction
        and wrong == 0
    )
    routeqa_rows.append({
        "query_id": query_id,
        "label_type": label_type,
        "query_type": dataset.get("query_type", ""),
        "expected_file": dataset.get("expected_file", ""),
        "expected_symbol": dataset.get("expected_symbol", ""),
        "source_uri": dataset.get("source_uri", ""),
        "prediction": prediction,
        "dataset_bound": trace.get("dataset_bound", ""),
        "result_bound": trace.get("result_bound", ""),
        "runner_owned_evaluator": trace.get("runner_owned_evaluator", ""),
        "independent_evaluator": trace.get("independent_evaluator", ""),
        "span_exact": span,
        "chunk_exact": chunk,
        "missing_abstain": missing_abstain,
        "near_miss_false_positive": near_fp,
        "wrong_answer": wrong,
        "routeqa_bound": routeqa_bound,
    })

routeqa_count = len(routeqa_rows)
metric_rows = len(trace_metrics)
span_exact = span_sum / routeqa_count if routeqa_count else 0.0
chunk_exact = chunk_sum / routeqa_count if routeqa_count else 0.0
missing_abstain = missing_ok / missing_eval_rows if missing_eval_rows else 0.0
near_miss_false_positive = near_fp_sum / near_eval_rows if near_eval_rows else 0.0
wrong_answer_rate = wrong_sum / routeqa_count if routeqa_count else 1.0
recomputed_metrics = {
    "span_exact": span_exact,
    "chunk_exact": chunk_exact,
    "missing_abstain": missing_abstain,
    "near_miss_false_positive": near_miss_false_positive,
    "wrong_answer_rate": wrong_answer_rate,
}
metrics_match_rows = sum(
    1
    for key, value in recomputed_metrics.items()
    if key in trace_metrics and abs(trace_metrics[key] - value) < 0.000001
)
package_metrics_match_rows = sum(
    1
    for key in recomputed_metrics
    if key in package_metrics and key in trace_metrics and abs(package_metrics[key] - trace_metrics[key]) < 0.000001
)

v08_run = first_row(run_dir / "evidence" / "v08_run.csv")
transcript_summary = first_row(transcript_summary_csv)
v13_manifest = first_row(run_dir / "evidence" / "v13_run_manifest.csv")
v08_codebase_trace_ready = as_int(v08_run, "codebase_run_evaluator_trace_ready")
v13_real_nlg_transcript_ready = as_int(transcript_summary, "v13_real_nlg_transcript_ready")

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

routeqa_csv = packet_dir / "routeqa_rows.csv"
routeqa_fields = [
    "query_id",
    "label_type",
    "query_type",
    "expected_file",
    "expected_symbol",
    "source_uri",
    "prediction",
    "dataset_bound",
    "result_bound",
    "runner_owned_evaluator",
    "independent_evaluator",
    "span_exact",
    "chunk_exact",
    "missing_abstain",
    "near_miss_false_positive",
    "wrong_answer",
    "routeqa_bound",
]
with routeqa_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=routeqa_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(routeqa_rows)

manifest = {
    "artifact_scope": "v13-e-public-codebase-routeqa",
    "run_source": run_source,
    "run_dir": str(run_dir),
    "artifact_dir": str(artifact_dir),
    "dataset_uri": runner_manifest.get("dataset_uri", ""),
    "result_uri": runner_manifest.get("result_uri", ""),
    "routeqa_rows": routeqa_count,
    "claim": "binds local codebase RouteQA rows to runner trace and evaluator output; does not establish an independent external benchmark",
}
(packet_dir / "routeqa_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

routeqa_packet_hash_entries, routeqa_packet_hash_verified = verify_manifest(packet_dir)
routeqa_packet_hash_ready = int(
    routeqa_packet_hash_entries > 0 and routeqa_packet_hash_entries == routeqa_packet_hash_verified
)

routeqa_bound_rows = sum(1 for row in routeqa_rows if row["routeqa_bound"] == 1)
routeqa_binding_ready = int(
    run_hash_manifest_ready == 1
    and trace_hash_manifest_ready == 1
    and trace_required_found == len(required_trace_files)
    and package_hash_manifest_ready == 1
    and package_required_found == len(required_package_files)
    and dataset_hash_match == 1
    and result_hash_match == 1
    and source_file_rows >= 4
    and source_hash_verified_rows == source_file_rows
    and local_source_rows == source_file_rows
    and external_source_rows == 0
    and len(dataset_rows) == 7
    and len(result_rows) == 7
    and len(query_trace_rows) == 7
    and len(evaluator_output_rows) == 7
    and all_ids_match == 1
    and routeqa_count == 7
    and routeqa_bound_rows == 7
    and present_like_rows >= 5
    and missing_rows >= 1
    and near_miss_rows >= 1
    and multi_hop_rows >= 1
    and dataset_bound_rows == 7
    and result_bound_rows == 7
    and runner_owned_evaluator_rows == 7
    and independent_evaluator_rows == 0
    and metric_rows >= 5
    and metrics_match_rows == 5
    and package_metrics_match_rows == 5
    and abs(span_exact - 1.0) < 0.000001
    and abs(chunk_exact - 1.0) < 0.000001
    and abs(missing_abstain - 1.0) < 0.000001
    and abs(near_miss_false_positive - 0.0) < 0.000001
    and abs(wrong_answer_rate - 0.0) < 0.000001
    and v08_codebase_trace_ready == 1
    and v13_real_nlg_transcript_ready == 1
    and routeqa_packet_hash_ready == 1
)

actual_nonfixture = 0 if v13_manifest.get("fixture_or_generated_declared", "1") == "1" else 1
independent_external_routeqa_verified = 0
real_external_benchmark_verified = 0
real_release_package_ready = 0
public_codebase_routeqa_ready = routeqa_binding_ready

action = "v13-public-codebase-routeqa-ready-await-nonfixture-public-source"
if run_hash_manifest_ready != 1:
    action = "v13-public-codebase-routeqa-run-hash-mismatch"
elif trace_hash_manifest_ready != 1 or trace_required_found != len(required_trace_files):
    action = "v13-public-codebase-routeqa-trace-hash-mismatch"
elif package_hash_manifest_ready != 1 or package_required_found != len(required_package_files):
    action = "v13-public-codebase-routeqa-package-hash-mismatch"
elif dataset_hash_match != 1 or result_hash_match != 1:
    action = "v13-public-codebase-routeqa-runner-manifest-hash-mismatch"
elif source_hash_verified_rows != source_file_rows or source_file_rows < 4:
    action = "v13-public-codebase-routeqa-source-hash-mismatch"
elif external_source_rows != 0 or local_source_rows != source_file_rows:
    action = "v13-public-codebase-routeqa-source-boundary-mismatch"
elif all_ids_match != 1 or routeqa_count != 7:
    action = "v13-public-codebase-routeqa-query-id-mismatch"
elif routeqa_bound_rows != 7 or result_prediction_matches != 7:
    action = "v13-public-codebase-routeqa-evaluator-mismatch"
elif metrics_match_rows != 5 or package_metrics_match_rows != 5:
    action = "v13-public-codebase-routeqa-metric-mismatch"
elif v08_codebase_trace_ready != 1:
    action = "v13-public-codebase-routeqa-v08-trace-not-ready"
elif v13_real_nlg_transcript_ready != 1:
    action = "v13-public-codebase-routeqa-transcript-not-ready"
elif routeqa_packet_hash_ready != 1:
    action = "v13-public-codebase-routeqa-packet-hash-mismatch"

summary_fields = [
    "routeqa_scope",
    "run_source",
    "run_id",
    "run_dir",
    "routeqa_packet_dir",
    "artifact_dir",
    "run_hash_entries",
    "run_hash_verified",
    "run_hash_manifest_ready",
    "trace_hash_entries",
    "trace_hash_verified",
    "trace_hash_manifest_ready",
    "trace_required_found",
    "package_hash_entries",
    "package_hash_verified",
    "package_hash_manifest_ready",
    "package_required_found",
    "dataset_hash_match",
    "result_hash_match",
    "source_file_rows",
    "source_hash_verified_rows",
    "local_source_rows",
    "external_source_rows",
    "dataset_rows",
    "result_rows",
    "query_trace_rows",
    "evaluator_output_rows",
    "routeqa_rows",
    "query_id_matches",
    "routeqa_bound_rows",
    "present_like_rows",
    "missing_rows",
    "near_miss_rows",
    "multi_hop_rows",
    "dataset_bound_rows",
    "result_bound_rows",
    "runner_owned_evaluator_rows",
    "independent_evaluator_rows",
    "metric_rows",
    "metrics_match_rows",
    "package_metrics_match_rows",
    "span_exact",
    "chunk_exact",
    "missing_abstain",
    "near_miss_false_positive",
    "wrong_answer_rate",
    "v08_codebase_trace_ready",
    "v13_real_nlg_transcript_ready",
    "routeqa_packet_hash_entries",
    "routeqa_packet_hash_verified",
    "routeqa_packet_hash_ready",
    "public_codebase_routeqa_ready",
    "actual_nonfixture_run_verified",
    "independent_external_routeqa_verified",
    "real_external_benchmark_verified",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "routeqa_scope": "v13-e-public-codebase-routeqa",
    "run_source": run_source,
    "run_id": run_dir.name,
    "run_dir": str(run_dir),
    "routeqa_packet_dir": str(packet_dir),
    "artifact_dir": str(artifact_dir),
    "run_hash_entries": run_hash_entries,
    "run_hash_verified": run_hash_verified,
    "run_hash_manifest_ready": run_hash_manifest_ready,
    "trace_hash_entries": trace_hash_entries,
    "trace_hash_verified": trace_hash_verified,
    "trace_hash_manifest_ready": trace_hash_manifest_ready,
    "trace_required_found": trace_required_found,
    "package_hash_entries": package_hash_entries,
    "package_hash_verified": package_hash_verified,
    "package_hash_manifest_ready": package_hash_manifest_ready,
    "package_required_found": package_required_found,
    "dataset_hash_match": dataset_hash_match,
    "result_hash_match": result_hash_match,
    "source_file_rows": source_file_rows,
    "source_hash_verified_rows": source_hash_verified_rows,
    "local_source_rows": local_source_rows,
    "external_source_rows": external_source_rows,
    "dataset_rows": len(dataset_rows),
    "result_rows": len(result_rows),
    "query_trace_rows": len(query_trace_rows),
    "evaluator_output_rows": len(evaluator_output_rows),
    "routeqa_rows": routeqa_count,
    "query_id_matches": all_ids_match,
    "routeqa_bound_rows": routeqa_bound_rows,
    "present_like_rows": present_like_rows,
    "missing_rows": missing_rows,
    "near_miss_rows": near_miss_rows,
    "multi_hop_rows": multi_hop_rows,
    "dataset_bound_rows": dataset_bound_rows,
    "result_bound_rows": result_bound_rows,
    "runner_owned_evaluator_rows": runner_owned_evaluator_rows,
    "independent_evaluator_rows": independent_evaluator_rows,
    "metric_rows": metric_rows,
    "metrics_match_rows": metrics_match_rows,
    "package_metrics_match_rows": package_metrics_match_rows,
    "span_exact": f"{span_exact:.6f}",
    "chunk_exact": f"{chunk_exact:.6f}",
    "missing_abstain": f"{missing_abstain:.6f}",
    "near_miss_false_positive": f"{near_miss_false_positive:.6f}",
    "wrong_answer_rate": f"{wrong_answer_rate:.6f}",
    "v08_codebase_trace_ready": v08_codebase_trace_ready,
    "v13_real_nlg_transcript_ready": v13_real_nlg_transcript_ready,
    "routeqa_packet_hash_entries": routeqa_packet_hash_entries,
    "routeqa_packet_hash_verified": routeqa_packet_hash_verified,
    "routeqa_packet_hash_ready": routeqa_packet_hash_ready,
    "public_codebase_routeqa_ready": public_codebase_routeqa_ready,
    "actual_nonfixture_run_verified": actual_nonfixture if public_codebase_routeqa_ready and actual_nonfixture else 0,
    "independent_external_routeqa_verified": independent_external_routeqa_verified,
    "real_external_benchmark_verified": real_external_benchmark_verified,
    "real_release_package_ready": real_release_package_ready,
    "action": action,
    "routing_trigger_rate": "0.000000",
    "active_jump_rate": "0.000000",
}
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=summary_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary_row)

def status(condition):
    return "pass" if condition else "blocked"

decision_rows = [
    ("run-hash-manifest", status(run_hash_manifest_ready == 1), f"verified={run_hash_verified}/{run_hash_entries}"),
    ("trace-hash-manifest", status(trace_hash_manifest_ready == 1 and trace_required_found == len(required_trace_files)), f"verified={trace_hash_verified}/{trace_hash_entries} files={trace_required_found}/{len(required_trace_files)}"),
    ("package-hash-manifest", status(package_hash_manifest_ready == 1 and package_required_found == len(required_package_files)), f"verified={package_hash_verified}/{package_hash_entries} files={package_required_found}/{len(required_package_files)}"),
    ("runner-manifest-hashes", status(dataset_hash_match == 1 and result_hash_match == 1), f"dataset={dataset_hash_match} result={result_hash_match}"),
    ("source-binding", status(source_hash_verified_rows == source_file_rows and local_source_rows == source_file_rows and external_source_rows == 0 and source_file_rows >= 4), f"source={source_hash_verified_rows}/{source_file_rows} local={local_source_rows} external={external_source_rows}"),
    ("query-id-binding", status(all_ids_match == 1 and routeqa_count == 7), f"rows={routeqa_count} matched={all_ids_match}"),
    ("label-coverage", status(present_like_rows >= 5 and missing_rows >= 1 and near_miss_rows >= 1 and multi_hop_rows >= 1), f"present_like={present_like_rows} missing={missing_rows} near_miss={near_miss_rows} multi_hop={multi_hop_rows}"),
    ("evaluator-binding", status(routeqa_bound_rows == 7 and result_prediction_matches == 7), f"bound={routeqa_bound_rows}/7 prediction={result_prediction_matches}/7"),
    ("metric-recompute", status(metrics_match_rows == 5 and package_metrics_match_rows == 5), f"trace={metrics_match_rows}/5 package={package_metrics_match_rows}/5 wrong={wrong_answer_rate:.6f}"),
    ("transcript-chain", status(v08_codebase_trace_ready == 1 and v13_real_nlg_transcript_ready == 1), f"v08={v08_codebase_trace_ready} v13d={v13_real_nlg_transcript_ready}"),
    ("routeqa-packet-hash", status(routeqa_packet_hash_ready == 1), f"verified={routeqa_packet_hash_verified}/{routeqa_packet_hash_entries}"),
    ("independent-external-routeqa", "blocked", f"independent={independent_external_routeqa_verified} external={real_external_benchmark_verified}"),
    ("v13-public-codebase-routeqa", status(public_codebase_routeqa_ready == 1), f"ready={public_codebase_routeqa_ready} action={action}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "routeqa_packet_dir: $ROUTEQA_PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
