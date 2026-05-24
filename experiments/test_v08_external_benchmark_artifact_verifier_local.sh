#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_fixture"
FIXTURE_CSV="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_fixture.csv"

mkdir -p "$FIXTURE_DIR"

printf 'ruler dev fixture\n' >"$FIXTURE_DIR/ruler_dataset.txt"
printf 'ruler result fixture\n' >"$FIXTURE_DIR/ruler_result.txt"
printf 'longbench dev fixture\n' >"$FIXTURE_DIR/longbench_dataset.txt"
printf 'longbench result fixture\n' >"$FIXTURE_DIR/longbench_result.txt"
printf 'codebase dev fixture\n' >"$FIXTURE_DIR/codebase_dataset.txt"
printf 'codebase result fixture\n' >"$FIXTURE_DIR/codebase_result.txt"
printf 'docqa dev fixture\n' >"$FIXTURE_DIR/docqa_dataset.txt"
printf 'docqa result fixture\n' >"$FIXTURE_DIR/docqa_result.txt"

ruler_source_hash="$(sha256sum "$FIXTURE_DIR/ruler_dataset.txt" | awk '{print $1}')"
ruler_result_hash="$(sha256sum "$FIXTURE_DIR/ruler_result.txt" | awk '{print $1}')"
longbench_source_hash="$(sha256sum "$FIXTURE_DIR/longbench_dataset.txt" | awk '{print $1}')"
longbench_result_hash="$(sha256sum "$FIXTURE_DIR/longbench_result.txt" | awk '{print $1}')"
codebase_source_hash="$(sha256sum "$FIXTURE_DIR/codebase_dataset.txt" | awk '{print $1}')"
codebase_result_hash="$(sha256sum "$FIXTURE_DIR/codebase_result.txt" | awk '{print $1}')"
docqa_source_hash="$(sha256sum "$FIXTURE_DIR/docqa_dataset.txt" | awk '{print $1}')"
docqa_result_hash="$(sha256sum "$FIXTURE_DIR/docqa_result.txt" | awk '{print $1}')"

cat >"$FIXTURE_CSV" <<CSV
benchmark_family,dataset_uri,split_name,license,source_hash,baseline_name,baseline_metric,route_memory_metric,result_uri,evaluator_version,provenance_hash,source_ready,result_ready,baseline_ready,license_ready,routing_trigger_rate,active_jump_rate
RULER,file://$FIXTURE_DIR/ruler_dataset.txt,dev,permissive,sha256:$ruler_source_hash,baseline-transformer,0.720000,0.710000,file://$FIXTURE_DIR/ruler_result.txt,v08-evidence-v1,sha256:$ruler_result_hash,1,1,1,1,0,0
LongBench,file://$FIXTURE_DIR/longbench_dataset.txt,dev,permissive,sha256:$longbench_source_hash,baseline-transformer,0.610000,0.590000,file://$FIXTURE_DIR/longbench_result.txt,v08-evidence-v1,sha256:$longbench_result_hash,1,1,1,1,0,0
codebase-retrieval,file://$FIXTURE_DIR/codebase_dataset.txt,dev,permissive,sha256:$codebase_source_hash,baseline-vector,0.540000,0.520000,file://$FIXTURE_DIR/codebase_result.txt,v08-evidence-v1,sha256:$codebase_result_hash,1,1,1,1,0,0
real-document-qa,file://$FIXTURE_DIR/docqa_dataset.txt,dev,permissive,sha256:$docqa_source_hash,baseline-rag,0.480000,0.470000,file://$FIXTURE_DIR/docqa_result.txt,v08-evidence-v1,sha256:$docqa_result_hash,1,1,1,1,0,0
CSV

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$FIXTURE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_artifact_verifier.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("evidence_source real_evidence_format_ready evidence_rows local_dataset_uri_rows local_result_uri_rows source_hash_verified_rows provenance_hash_verified_rows artifact_verifier_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 artifact verifier local summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["evidence_source"] != "provided-csv" ||
        ($idx["real_evidence_format_ready"] + 0) != 1 ||
        ($idx["evidence_rows"] + 0) != 4 ||
        ($idx["local_dataset_uri_rows"] + 0) != 4 ||
        ($idx["local_result_uri_rows"] + 0) != 4 ||
        ($idx["source_hash_verified_rows"] + 0) != 4 ||
        ($idx["provenance_hash_verified_rows"] + 0) != 4 ||
        ($idx["artifact_verifier_ready"] + 0) != 1 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "benchmark-authenticity-verifier-missing") {
      die("local v08 artifacts should verify hashes but still block benchmark authenticity", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for local v08 artifact verifier", 4)
    }
  }
  END {
    if (rows != 1) die("expected one local v08 artifact verifier summary row", 5)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    if ($idx["gate"] == "local-artifacts" && $idx["status"] != "pass") die("local artifacts should pass", 20)
    if ($idx["gate"] == "source-hash" && $idx["status"] != "pass") die("source hashes should pass", 21)
    if ($idx["gate"] == "provenance-hash" && $idx["status"] != "pass") die("provenance hashes should pass", 22)
    if ($idx["gate"] == "artifact-verifier" && $idx["status"] != "pass") die("artifact verifier should pass", 23)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should still block", 24)
  }
  END {
    if (rows != 6) die("expected local v08 artifact verifier decision rows", 25)
  }
' "$DECISION_CSV"

echo "v08 external benchmark artifact verifier local smoke passed"
