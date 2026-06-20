#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v56_ruler_longbench_expanded_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v56_ruler_longbench_expanded_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v56_ruler_longbench_expanded_contract_decision.csv"
V49_DIR="$RESULTS_DIR/v49_ruler_niah_200_500_scale/scale_001"
V45_DIR="$RESULTS_DIR/v45_longbench_v2_small_slice/slice_001"

required_seed_files=(
  "$RESULTS_DIR/v49_ruler_niah_200_500_scale_summary.csv"
  "$V49_DIR/V49_RULER_NIAH_200_500_BOUNDARY.md"
  "$V49_DIR/scale_rows.csv"
  "$V49_DIR/v49_ruler_niah_200_500_scale_manifest.json"
  "$V49_DIR/sha256_manifest.csv"
  "$V49_DIR/evidence/expanded_result_rows_200.csv"
  "$V49_DIR/evidence/expanded_result_rows_500.csv"
  "$V49_DIR/evidence/candidate_result_rows_200.csv"
  "$V49_DIR/evidence/candidate_result_rows_500.csv"
  "$RESULTS_DIR/v45_longbench_v2_small_slice_summary.csv"
  "$V45_DIR/V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md"
  "$V45_DIR/v45_longbench_v2_small_slice_manifest.json"
  "$V45_DIR/sha256_manifest.csv"
  "$V45_DIR/official_return/raw_predictions.jsonl"
  "$V45_DIR/official_return/prediction_lineage.jsonl"
  "$V45_DIR/official_return/metrics.json"
  "$V45_DIR/official_return/provenance_manifest.json"
  "$V45_DIR/official_return/official_source_snapshot.json"
  "$V45_DIR/official_return/official_evaluator_status.json"
  "$V45_DIR/official_return/candidate_result_rows.csv"
  "$V45_DIR/official_source_snapshot/download_rows.csv"
)

missing_seed_files=()
for path in "${required_seed_files[@]}"; do
  if [ ! -s "$path" ]; then
    missing_seed_files+=("$path")
  fi
done

if [ "${#missing_seed_files[@]}" -gt 0 ] && [ "${V56_REQUIRE_READY_TEST:-0}" != "1" ]; then
  set +e
  output="$("$ROOT_DIR/experiments/run_v56_ruler_longbench_expanded_contract.sh" 2>&1 >/dev/null)"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "v56 should fail closed when seed artifacts are missing" >&2
    exit 1
  fi
  if ! grep -q "refusing implicit v49/v45 regeneration" <<<"$output"; then
    echo "v56 missing-seed guard did not explain the refusal" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
  python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
if summary.get("v56_seed_dependency_blocker_ready") != "1":
    raise SystemExit("v56 missing-seed path should emit a dependency blocker summary")
if summary.get("v56_ruler_longbench_expanded_contract_ready") != "0":
    raise SystemExit("v56 missing-seed path must not claim contract readiness")
if int(summary.get("missing_seed_artifact_rows", "0")) <= 0:
    raise SystemExit("v56 missing-seed summary should count missing artifacts")
if summary.get("implicit_seed_rebuild_allowed") != "0" or summary.get("seed_rebuild_approval_required") != "1":
    raise SystemExit("v56 missing-seed summary should block implicit seed rebuild")

rows = read_csv(run_dir / "v56_seed_dependency_blocker_rows.csv")
if len(rows) != int(summary["missing_seed_artifact_rows"]):
    raise SystemExit("v56 missing-seed blocker rows should match the summary count")
if any(row["implicit_rebuild_allowed"] != "0" or row["approval_required"] != "1" for row in rows):
    raise SystemExit("v56 missing-seed blocker rows should require approval and forbid implicit rebuild")
if any(row["fixture_allowed"] != "0" or row["tests_only_merge_condition"] != "0" for row in rows):
    raise SystemExit("v56 missing-seed blocker rows should forbid fixtures and tests-only merge")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("v56-seed-dependency-blocker") != "pass":
    raise SystemExit("v56 dependency blocker gate should pass")
if decisions.get("implicit-seed-rebuild") != "blocked" or decisions.get("v56-expanded-benchmark-contract") != "blocked":
    raise SystemExit("v56 missing-seed path should keep rebuild and contract blocked")

manifest = json.loads((run_dir / "v56_seed_dependency_blocker_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v56_seed_dependency_blocker_ready") != 1:
    raise SystemExit("v56 dependency blocker manifest should be ready")
boundary = (run_dir / "V56_RULER_LONGBENCH_DEPENDENCY_BLOCKER.md").read_text(encoding="utf-8")
for snippet in [
    "refuses implicit regeneration",
    "seed_rebuild_approval_required=1",
    "real_external_benchmark_verified=0",
    "Blocked wording: v56 expanded benchmark ready",
]:
    if snippet not in boundary:
        raise SystemExit(f"v56 dependency blocker boundary missing {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in [
    "v56_seed_dependency_blocker_rows.csv",
    "V56_RULER_LONGBENCH_DEPENDENCY_BLOCKER.md",
    "v56_seed_dependency_blocker_manifest.json",
]:
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v56 dependency blocker sha mismatch: {rel}")
PY
  echo "v56 RULER/LongBench missing-seed guard smoke passed"
  exit 0
fi

"$ROOT_DIR/experiments/run_v56_ruler_longbench_expanded_contract.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

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
    raise SystemExit(f"expected one v56 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v56_ruler_longbench_expanded_contract_ready": "1",
    "v56_ruler_longbench_expanded_ready": "0",
    "benchmark_family_rows": "2",
    "target_total_rows": "1500",
    "seed_total_rows": "506",
    "missing_total_rows": "994",
    "ruler_target_rows": "1000",
    "ruler_seed_rows": "500",
    "ruler_missing_rows": "500",
    "longbench_target_rows": "500",
    "longbench_seed_rows": "6",
    "longbench_missing_rows": "494",
    "official_source_hash_bound": "1",
    "official_evaluator_hash_bound": "1",
    "oracle_prediction_used": "0",
    "raw_input_extractor_used": "0",
    "route_memory_prediction_lineage_ready": "1",
    "llm_rag_baseline_rows_ready": "0",
    "real_external_benchmark_verified": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v56 {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v56-expanded-benchmark-contract", "v49-ruler-seed", "v45-longbench-seed"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v56 gate should pass: {gate}")
for gate in ["ruler-expanded-row-target", "longbench-expanded-row-target", "llm-rag-baseline-rows", "real-external-benchmark", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v56 gate should remain blocked: {gate}")

required_files = [
    "benchmark_family_target_rows.csv",
    "expanded_benchmark_artifact_contract_rows.csv",
    "benchmark_invariant_rows.csv",
    "V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md",
    "v56_ruler_longbench_expanded_manifest.json",
    "sha256_manifest.csv",
    "source_v49/V49_RULER_NIAH_200_500_BOUNDARY.md",
    "source_v49/scale_rows.csv",
    "source_v49/v49_ruler_niah_200_500_scale_manifest.json",
    "source_v49/sha256_manifest.csv",
    "source_v49/evidence/expanded_result_rows_200.csv",
    "source_v49/evidence/expanded_result_rows_500.csv",
    "source_v49/evidence/candidate_result_rows_200.csv",
    "source_v49/evidence/candidate_result_rows_500.csv",
    "source_v45/V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md",
    "source_v45/v45_longbench_v2_small_slice_manifest.json",
    "source_v45/sha256_manifest.csv",
    "source_v45/official_return/raw_predictions.jsonl",
    "source_v45/official_return/prediction_lineage.jsonl",
    "source_v45/official_return/metrics.json",
    "source_v45/official_return/provenance_manifest.json",
    "source_v45/official_return/official_source_snapshot.json",
    "source_v45/official_return/official_evaluator_status.json",
    "source_v45/official_return/candidate_result_rows.csv",
    "source_v45/official_source_snapshot/download_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v56 artifact: {rel}")

families = read_csv(run_dir / "benchmark_family_target_rows.csv")
if len(families) != 2:
    raise SystemExit("v56 should cover two benchmark families")
by_family = {row["benchmark_family"]: row for row in families}
if by_family["RULER"]["seed_rows"] != "500" or by_family["RULER"]["missing_rows"] != "500":
    raise SystemExit("v56 RULER seed/missing rows mismatch")
if by_family["LongBench"]["seed_rows"] != "6" or by_family["LongBench"]["missing_rows"] != "494":
    raise SystemExit("v56 LongBench seed/missing rows mismatch")
for row in families:
    for field in ["official_source_hash_bound", "official_evaluator_hash_bound", "route_memory_lineage_ready"]:
        if row[field] != "1":
            raise SystemExit(f"v56 family should bind {field}: {row['benchmark_family']}")
    if row["oracle_prediction_used"] != "0" or row["raw_input_extractor_used"] != "0":
        raise SystemExit(f"v56 family should stay no-oracle/no-extractor: {row['benchmark_family']}")

artifact_contract = {row["artifact"] for row in read_csv(run_dir / "expanded_benchmark_artifact_contract_rows.csv")}
for artifact in ["official_source_snapshot", "official_evaluator_status", "raw_predictions", "prediction_lineage", "metrics", "provenance_manifest", "reproducibility_package", "candidate_result_rows", "llm_rag_baseline_rows", "sha256_manifest"]:
    if artifact not in artifact_contract:
        raise SystemExit(f"v56 artifact contract missing {artifact}")

invariants = read_csv(run_dir / "benchmark_invariant_rows.csv")
if len(invariants) != 7 or any(row["status"] != "pass" for row in invariants):
    raise SystemExit("v56 invariants should all pass on seed evidence")

manifest = json.loads((run_dir / "v56_ruler_longbench_expanded_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v56_ruler_longbench_expanded_contract_ready") != 1 or manifest.get("v56_ruler_longbench_expanded_ready") != 0:
    raise SystemExit("v56 manifest readiness boundary mismatch")
if manifest.get("missing_total_rows") != 994:
    raise SystemExit("v56 manifest missing-total mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v56 sha256 mismatch: {rel}")

boundary = (run_dir / "V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed RULER/LongBench main run",
    "RULER missing rows=500",
    "LongBench missing rows=494",
    "LLM+RAG benchmark-format baseline rows",
    "Do not publish expanded benchmark claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v56 boundary missing {snippet}")
PY

echo "v56 RULER/LongBench expanded benchmark contract smoke passed"
