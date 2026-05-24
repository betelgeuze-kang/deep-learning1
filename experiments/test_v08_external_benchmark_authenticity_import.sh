#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_authenticity_fixture"
EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_authenticity_evidence_fixture.csv"
AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_authenticity_fixture.csv"

mkdir -p "$FIXTURE_DIR"

printf 'ruler dev fixture\n' >"$FIXTURE_DIR/ruler_dataset.txt"
printf 'ruler result fixture\n' >"$FIXTURE_DIR/ruler_result.txt"
printf 'longbench dev fixture\n' >"$FIXTURE_DIR/longbench_dataset.txt"
printf 'longbench result fixture\n' >"$FIXTURE_DIR/longbench_result.txt"
printf 'codebase dev fixture\n' >"$FIXTURE_DIR/codebase_dataset.txt"
printf 'codebase result fixture\n' >"$FIXTURE_DIR/codebase_result.txt"
printf 'docqa dev fixture\n' >"$FIXTURE_DIR/docqa_dataset.txt"
printf 'docqa result fixture\n' >"$FIXTURE_DIR/docqa_result.txt"
printf 'deterministic evaluator fixture\n' >"$FIXTURE_DIR/evaluator.txt"

ruler_source_hash="$(sha256sum "$FIXTURE_DIR/ruler_dataset.txt" | awk '{print $1}')"
ruler_result_hash="$(sha256sum "$FIXTURE_DIR/ruler_result.txt" | awk '{print $1}')"
longbench_source_hash="$(sha256sum "$FIXTURE_DIR/longbench_dataset.txt" | awk '{print $1}')"
longbench_result_hash="$(sha256sum "$FIXTURE_DIR/longbench_result.txt" | awk '{print $1}')"
codebase_source_hash="$(sha256sum "$FIXTURE_DIR/codebase_dataset.txt" | awk '{print $1}')"
codebase_result_hash="$(sha256sum "$FIXTURE_DIR/codebase_result.txt" | awk '{print $1}')"
docqa_source_hash="$(sha256sum "$FIXTURE_DIR/docqa_dataset.txt" | awk '{print $1}')"
docqa_result_hash="$(sha256sum "$FIXTURE_DIR/docqa_result.txt" | awk '{print $1}')"
evaluator_hash="$(sha256sum "$FIXTURE_DIR/evaluator.txt" | awk '{print $1}')"

cat >"$EVIDENCE_CSV" <<CSV
benchmark_family,dataset_uri,split_name,license,source_hash,baseline_name,baseline_metric,route_memory_metric,result_uri,evaluator_version,provenance_hash,source_ready,result_ready,baseline_ready,license_ready,routing_trigger_rate,active_jump_rate
RULER,file://$FIXTURE_DIR/ruler_dataset.txt,dev,permissive,sha256:$ruler_source_hash,baseline-transformer,0.720000,0.710000,file://$FIXTURE_DIR/ruler_result.txt,v08-evidence-v1,sha256:$ruler_result_hash,1,1,1,1,0,0
LongBench,file://$FIXTURE_DIR/longbench_dataset.txt,dev,permissive,sha256:$longbench_source_hash,baseline-transformer,0.610000,0.590000,file://$FIXTURE_DIR/longbench_result.txt,v08-evidence-v1,sha256:$longbench_result_hash,1,1,1,1,0,0
codebase-retrieval,file://$FIXTURE_DIR/codebase_dataset.txt,dev,permissive,sha256:$codebase_source_hash,baseline-vector,0.540000,0.520000,file://$FIXTURE_DIR/codebase_result.txt,v08-evidence-v1,sha256:$codebase_result_hash,1,1,1,1,0,0
real-document-qa,file://$FIXTURE_DIR/docqa_dataset.txt,dev,permissive,sha256:$docqa_source_hash,baseline-rag,0.480000,0.470000,file://$FIXTURE_DIR/docqa_result.txt,v08-evidence-v1,sha256:$docqa_result_hash,1,1,1,1,0,0
CSV

cat >"$AUTHENTICITY_CSV" <<CSV
benchmark_family,benchmark_id,benchmark_version,canonical_dataset_uri,canonical_result_uri,evaluator_name,evaluator_version,evaluator_hash,metric_name,metric_direction,metric_scale,authenticity_ready,evaluator_ready,metric_ready,routing_trigger_rate,active_jump_rate
RULER,ruler,ruler-fixture-v1,file://$FIXTURE_DIR/ruler_dataset.txt,file://$FIXTURE_DIR/ruler_result.txt,v08-fixture-evaluator,v1,sha256:$evaluator_hash,accuracy,higher-is-better,0..1,1,1,1,0,0
LongBench,longbench,longbench-fixture-v1,file://$FIXTURE_DIR/longbench_dataset.txt,file://$FIXTURE_DIR/longbench_result.txt,v08-fixture-evaluator,v1,sha256:$evaluator_hash,f1,higher-is-better,0..1,1,1,1,0,0
codebase-retrieval,codebase-retrieval,codebase-fixture-v1,file://$FIXTURE_DIR/codebase_dataset.txt,file://$FIXTURE_DIR/codebase_result.txt,v08-fixture-evaluator,v1,sha256:$evaluator_hash,recall-at-k,higher-is-better,0..1,1,1,1,0,0
real-document-qa,real-document-qa,docqa-fixture-v1,file://$FIXTURE_DIR/docqa_dataset.txt,file://$FIXTURE_DIR/docqa_result.txt,v08-fixture-evaluator,v1,sha256:$evaluator_hash,exact-match,higher-is-better,0..1,1,1,1,0,0
CSV

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$AUTHENTICITY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_authenticity_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_authenticity_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_authenticity_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("evidence_source authenticity_source artifact_verifier_ready authenticity_rows matched_family_rows canonical_uri_match_rows authenticity_ready_rows evaluator_ready_rows evaluator_hash_rows metric_ready_rows benchmark_authenticity_ready evaluator_contract_ready benchmark_authenticity_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 authenticity import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["evidence_source"] != "provided-csv" ||
        $idx["authenticity_source"] != "provided-csv" ||
        ($idx["artifact_verifier_ready"] + 0) != 1 ||
        ($idx["authenticity_rows"] + 0) != 4 ||
        ($idx["matched_family_rows"] + 0) != 4 ||
        ($idx["canonical_uri_match_rows"] + 0) != 4 ||
        ($idx["authenticity_ready_rows"] + 0) != 4 ||
        ($idx["evaluator_ready_rows"] + 0) != 4 ||
        ($idx["evaluator_hash_rows"] + 0) != 4 ||
        ($idx["metric_ready_rows"] + 0) != 4 ||
        ($idx["benchmark_authenticity_ready"] + 0) != 1 ||
        ($idx["evaluator_contract_ready"] + 0) != 1 ||
        ($idx["benchmark_authenticity_verified"] + 0) != 1 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-execution-missing") {
      die("supplied v08 authenticity evidence should verify contract but block execution", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 authenticity import", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 authenticity import summary row", 5)
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
    if ($idx["gate"] == "artifact-verifier" && $idx["status"] != "pass") die("artifact verifier should pass", 20)
    if ($idx["gate"] == "canonical-uri-match" && $idx["status"] != "pass") die("canonical URI match should pass", 21)
    if ($idx["gate"] == "benchmark-authenticity" && $idx["status"] != "pass") die("benchmark authenticity should pass", 22)
    if ($idx["gate"] == "evaluator-contract" && $idx["status"] != "pass") die("evaluator contract should pass", 23)
    if ($idx["gate"] == "authenticity-verified" && $idx["status"] != "pass") die("authenticity verified should pass", 24)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should still block", 25)
  }
  END {
    if (rows != 6) die("expected v08 authenticity import decision rows", 26)
  }
' "$DECISION_CSV"

echo "v08 external benchmark authenticity import smoke passed"
