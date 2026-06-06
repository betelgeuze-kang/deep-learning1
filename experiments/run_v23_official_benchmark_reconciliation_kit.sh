#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v23_official_benchmark_reconciliation_kit"
KIT_ID="${V23_KIT_ID:-kit_001}"
KIT_DIR="${V23_KIT_DIR:-$RESULTS_DIR/${PREFIX}/$KIT_ID}"
V22_KIT_DIR="${V22_KIT_DIR:-$RESULTS_DIR/v22_clean_machine_execution_kit/kit_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$KIT_DIR"

"$ROOT_DIR/experiments/run_v22_clean_machine_execution_kit.sh" >/dev/null

python3 - "$ROOT_DIR" "$KIT_DIR" "$V22_KIT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
kit_dir = Path(sys.argv[2])
v22_kit_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
kit_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["official_benchmark", "templates", "source_manifests", "verification"]:
    ensure(kit_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = kit_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v22_manifest = read_json(v22_kit_dir / "clean_machine_execution_manifest.json")
copy(v22_kit_dir / "clean_machine_execution_manifest.json", "source_manifests/v22_clean_machine_execution_manifest.json")
copy(v22_kit_dir / "clean_machine" / "OFFICIAL_BENCHMARK_EXECUTION_NOTES.md", "source_manifests/v22_official_benchmark_execution_notes.md")
copy(v22_kit_dir / "source_manifests" / "v21_official_benchmark_request.md", "source_manifests/v21_official_benchmark_request.md")

(kit_dir / "official_benchmark" / "OFFICIAL_SLICE_RECONCILIATION_RUNBOOK.md").write_text(
    "\n".join(
        [
            "# Official Slice Reconciliation Runbook",
            "",
            "Target: `candidate_external_benchmark_result_ready=1`.",
            "",
            "Use this kit for a small but official-source RULER NIAH or LongBench v2 slice. The goal is not to maximize score; the goal is to prove that a result can be replayed and reconciled without runner-owned smoke assumptions.",
            "",
            "Required invariants:",
            "- official source snapshot is immutable and hash-bound",
            "- official evaluator/container is identified by command, version, and digest",
            "- `oracle_prediction_used=0`",
            "- `raw_input_extractor_used=0`",
            "- raw predictions are captured before metric aggregation",
            "- RouteMemory-derived prediction lineage exists for every prediction row",
            "- metrics, provenance, and reproducibility package are returned",
            "",
            "Validation after return:",
            "",
            "```bash",
            "V20_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "official_benchmark" / "RETURN_DIRECTORY_LAYOUT.md").write_text(
    "\n".join(
        [
            "# Official Benchmark Return Directory Layout",
            "",
            "The return directory must contain these files:",
            "",
            "- `official_source_snapshot.json`",
            "- `official_evaluator_status.json`",
            "- `raw_predictions.jsonl`",
            "- `prediction_lineage.jsonl`",
            "- `metrics.json`",
            "- `provenance_manifest.json`",
            "- `reproducibility_package_manifest.json`",
            "- `candidate_result_rows.csv`",
            "",
            "The v18 verifier checks the actual file names above. Templates are provided under `templates/`.",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "official_benchmark" / "NO_ORACLE_NO_EXTRACTOR_CONTRACT.md").write_text(
    "\n".join(
        [
            "# No-Oracle / No-Extractor Contract",
            "",
            "A candidate external benchmark result must not be produced by copying the answer from benchmark outputs or by extracting the answer directly from the raw input.",
            "",
            "Required declarations:",
            "- `oracle_prediction_used=0` in `metrics.json`",
            "- `oracle_prediction_used=0` in `provenance_manifest.json`",
            "- `raw_input_extractor_used=0` in `metrics.json`",
            "- `raw_input_extractor_used=0` in `provenance_manifest.json`",
            "- `route_memory_prediction_lineage_ready=1` in `provenance_manifest.json`",
            "",
            "The prediction path must be represented by raw prediction rows and RouteMemory-derived prediction lineage rows. A benchmark smoke that is runner-owned or extractor-assisted remains blocked.",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "official_benchmark" / "EVALUATOR_CONTAINER_CONTRACT.json").write_text(
    json.dumps(
        {
            "official_evaluator_ready": 0,
            "benchmark_family": "ruler_niah_or_longbench_v2",
            "evaluator_name": "",
            "evaluator_version": "",
            "evaluator_command": "",
            "container_image": "",
            "container_digest": "",
            "source_snapshot_sha256": "",
            "metric_spec_sha256": "",
            "notes": "fill with official evaluator/container identity before submission",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

templates = {
    "official_source_snapshot.json": {
        "official_source_snapshot_ready": 0,
        "benchmark_family": "ruler_niah_or_longbench_v2",
        "source_uri": "",
        "source_revision": "",
        "dataset_split": "",
        "dataset_sha256": "",
        "license_uri": "",
        "snapshot_created_at_utc": "",
    },
    "official_evaluator_status.json": {
        "official_evaluator_ready": 0,
        "evaluator_name": "",
        "evaluator_version": "",
        "evaluator_command": "",
        "container_digest": "",
        "exit_code": "",
        "stdout_sha256": "",
        "stderr_sha256": "",
    },
    "metrics.json": {
        "metrics_ready": 0,
        "raw_predictions_ready": 0,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
        "metric_name": "",
        "metric_value": "",
        "query_count": "",
    },
    "provenance_manifest.json": {
        "route_memory_prediction_lineage_ready": 0,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
        "official_source_snapshot_sha256": "",
        "official_evaluator_status_sha256": "",
        "raw_predictions_sha256": "",
        "prediction_lineage_sha256": "",
        "metrics_sha256": "",
    },
    "reproducibility_package_manifest.json": {
        "reproducibility_package_ready": 0,
        "package_uri": "",
        "package_sha256": "",
        "rerun_command": "",
        "environment_uri": "",
        "reviewer": "",
    },
}
for filename, payload in templates.items():
    (kit_dir / "templates" / filename).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(kit_dir / "templates" / "raw_predictions.jsonl").write_text(
    json.dumps(
        {
            "prediction_id": "fill",
            "benchmark_family": "ruler_niah_or_longbench_v2",
            "task": "fill",
            "query_id": "fill",
            "prediction_text": "fill",
            "created_before_evaluation": 1,
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

(kit_dir / "templates" / "prediction_lineage.jsonl").write_text(
    json.dumps(
        {
            "prediction_id": "fill",
            "query_id": "fill",
            "route_memory_store_sha256": "fill",
            "route_index_sha256": "fill",
            "chunk_offsets_sha256": "fill",
            "mmap_read_row_id": "fill",
            "candidate_row_id": "fill",
            "lineage_ready": 0,
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

with (kit_dir / "templates" / "candidate_result_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["benchmark_family", "task", "query_count", "metric_name", "metric_value", "official_evaluator_digest", "prediction_lineage_sha256", "candidate_external_benchmark_result_ready"])
    writer.writerow(["ruler_niah_or_longbench_v2", "", "", "", "", "", "", "0"])

check_script = kit_dir / "verification" / "CHECK_OFFICIAL_RETURN_FILES.sh"
check_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'RETURN_DIR="${1:?usage: CHECK_OFFICIAL_RETURN_FILES.sh /path/to/official_return}"',
            "required=(",
            "  official_source_snapshot.json",
            "  official_evaluator_status.json",
            "  raw_predictions.jsonl",
            "  prediction_lineage.jsonl",
            "  metrics.json",
            "  provenance_manifest.json",
            "  reproducibility_package_manifest.json",
            "  candidate_result_rows.csv",
            ")",
            "missing=0",
            'for rel in "${required[@]}"; do',
            '  if [ ! -s "$RETURN_DIR/$rel" ]; then',
            '    echo "missing_or_empty:$rel"',
            "    missing=1",
            "  fi",
            "done",
            'if [ "$missing" -ne 0 ]; then exit 2; fi',
            'python3 - "$RETURN_DIR" <<\'PY\'',
            "import json",
            "import sys",
            "from pathlib import Path",
            "root = Path(sys.argv[1])",
            "metrics = json.loads((root / 'metrics.json').read_text(encoding='utf-8'))",
            "provenance = json.loads((root / 'provenance_manifest.json').read_text(encoding='utf-8'))",
            "checks = {",
            "    'metrics.oracle_prediction_used': metrics.get('oracle_prediction_used'),",
            "    'metrics.raw_input_extractor_used': metrics.get('raw_input_extractor_used'),",
            "    'provenance.oracle_prediction_used': provenance.get('oracle_prediction_used'),",
            "    'provenance.raw_input_extractor_used': provenance.get('raw_input_extractor_used'),",
            "}",
            "bad = [name for name, value in checks.items() if str(value) != '0']",
            "if bad:",
            "    raise SystemExit('nonzero_guard:' + ','.join(bad))",
            "print('official_return_file_preflight_pass')",
            "PY",
            "",
        ]
    ),
    encoding="utf-8",
)
check_script.chmod(0o755)

(kit_dir / "verification" / "VERIFY_WITH_V20.md").write_text(
    "\n".join(
        [
            "# Verify Official Return With v20/v18",
            "",
            "After an official benchmark return directory passes the file preflight, run:",
            "",
            "```bash",
            "V20_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
            "A real candidate requires `candidate_external_benchmark_result_ready=1` in the v20/v18 summary and manifest. This kit alone keeps that flag at 0.",
            "",
        ]
    ),
    encoding="utf-8",
)

official_benchmark_reconciliation_kit_ready = 1
manifest = {
    "manifest_scope": "v23-official-benchmark-reconciliation-kit",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v22_clean_machine_execution_manifest_sha256": sha256(v22_kit_dir / "clean_machine_execution_manifest.json"),
    "official_benchmark_reconciliation_kit_ready": official_benchmark_reconciliation_kit_ready,
    "official_source_snapshot_template_ready": 1,
    "official_evaluator_container_contract_ready": 1,
    "no_oracle_no_extractor_contract_ready": 1,
    "raw_predictions_template_ready": 1,
    "prediction_lineage_template_ready": 1,
    "metrics_provenance_templates_ready": 1,
    "official_return_preflight_ready": 1,
    "candidate_external_benchmark_result_ready": bool_int(v22_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "independent_rerun_actual_ready": bool_int(v22_manifest.get("independent_rerun_actual_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v22_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v22_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v22_manifest.get("real_release_package_ready", 0)),
    "claim": "official benchmark reconciliation kit ready; candidate readiness requires returned official evidence",
}
(kit_dir / "official_benchmark_reconciliation_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "official_benchmark/OFFICIAL_SLICE_RECONCILIATION_RUNBOOK.md",
    "official_benchmark/RETURN_DIRECTORY_LAYOUT.md",
    "official_benchmark/NO_ORACLE_NO_EXTRACTOR_CONTRACT.md",
    "official_benchmark/EVALUATOR_CONTAINER_CONTRACT.json",
    "templates/official_source_snapshot.json",
    "templates/official_evaluator_status.json",
    "templates/raw_predictions.jsonl",
    "templates/prediction_lineage.jsonl",
    "templates/metrics.json",
    "templates/provenance_manifest.json",
    "templates/reproducibility_package_manifest.json",
    "templates/candidate_result_rows.csv",
    "source_manifests/v22_clean_machine_execution_manifest.json",
    "source_manifests/v22_official_benchmark_execution_notes.md",
    "source_manifests/v21_official_benchmark_request.md",
    "verification/CHECK_OFFICIAL_RETURN_FILES.sh",
    "verification/VERIFY_WITH_V20.md",
    "official_benchmark_reconciliation_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = kit_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (kit_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "kit_id": kit_dir.name,
        "official_benchmark_reconciliation_kit_ready": official_benchmark_reconciliation_kit_ready,
        "official_source_snapshot_template_ready": 1,
        "official_evaluator_container_contract_ready": 1,
        "no_oracle_no_extractor_contract_ready": 1,
        "raw_predictions_template_ready": 1,
        "prediction_lineage_template_ready": 1,
        "metrics_provenance_templates_ready": 1,
        "official_return_preflight_ready": 1,
        "candidate_external_benchmark_result_ready": bool_int(v22_manifest.get("candidate_external_benchmark_result_ready", 0)),
        "independent_rerun_actual_ready": bool_int(v22_manifest.get("independent_rerun_actual_ready", 0)),
        "closed_corpus_poc_actual_ready": bool_int(v22_manifest.get("closed_corpus_poc_actual_ready", 0)),
        "real_external_benchmark_verified": bool_int(v22_manifest.get("real_external_benchmark_verified", 0)),
        "real_release_package_ready": bool_int(v22_manifest.get("real_release_package_ready", 0)),
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("official-benchmark-reconciliation-kit", "pass", "official source/evaluator/no-oracle/lineage/templates and preflight are packaged"),
    ("candidate-external-benchmark-result", "blocked", "requires returned official benchmark reconciliation evidence verified by v20/v18"),
    ("real-external-benchmark", "blocked", "requires candidate benchmark plus independent rerun actual"),
    ("real-release-package", "blocked", "official benchmark kit is not release evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v23_official_benchmark_reconciliation_kit_dir: $KIT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
