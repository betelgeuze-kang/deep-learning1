#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_attestation_fixture"
EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_evidence_fixture.csv"
AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_authenticity_fixture.csv"
EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_execution_fixture.csv"
ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_fixture.csv"

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

for family in ruler longbench codebase docqa; do
  printf '%s evaluator output\n' "$family" >"$FIXTURE_DIR/${family}_output.json"
  printf '%s evaluator run log\n' "$family" >"$FIXTURE_DIR/${family}_run.log"
  printf '%s local attestation fixture\n' "$family" >"$FIXTURE_DIR/${family}_attestation.txt"
done

ruler_source_hash="$(sha256sum "$FIXTURE_DIR/ruler_dataset.txt" | awk '{print $1}')"
ruler_result_hash="$(sha256sum "$FIXTURE_DIR/ruler_result.txt" | awk '{print $1}')"
longbench_source_hash="$(sha256sum "$FIXTURE_DIR/longbench_dataset.txt" | awk '{print $1}')"
longbench_result_hash="$(sha256sum "$FIXTURE_DIR/longbench_result.txt" | awk '{print $1}')"
codebase_source_hash="$(sha256sum "$FIXTURE_DIR/codebase_dataset.txt" | awk '{print $1}')"
codebase_result_hash="$(sha256sum "$FIXTURE_DIR/codebase_result.txt" | awk '{print $1}')"
docqa_source_hash="$(sha256sum "$FIXTURE_DIR/docqa_dataset.txt" | awk '{print $1}')"
docqa_result_hash="$(sha256sum "$FIXTURE_DIR/docqa_result.txt" | awk '{print $1}')"
evaluator_hash="$(sha256sum "$FIXTURE_DIR/evaluator.txt" | awk '{print $1}')"

ruler_output_hash="$(sha256sum "$FIXTURE_DIR/ruler_output.json" | awk '{print $1}')"
ruler_log_hash="$(sha256sum "$FIXTURE_DIR/ruler_run.log" | awk '{print $1}')"
ruler_attestation_hash="$(sha256sum "$FIXTURE_DIR/ruler_attestation.txt" | awk '{print $1}')"
longbench_output_hash="$(sha256sum "$FIXTURE_DIR/longbench_output.json" | awk '{print $1}')"
longbench_log_hash="$(sha256sum "$FIXTURE_DIR/longbench_run.log" | awk '{print $1}')"
longbench_attestation_hash="$(sha256sum "$FIXTURE_DIR/longbench_attestation.txt" | awk '{print $1}')"
codebase_output_hash="$(sha256sum "$FIXTURE_DIR/codebase_output.json" | awk '{print $1}')"
codebase_log_hash="$(sha256sum "$FIXTURE_DIR/codebase_run.log" | awk '{print $1}')"
codebase_attestation_hash="$(sha256sum "$FIXTURE_DIR/codebase_attestation.txt" | awk '{print $1}')"
docqa_output_hash="$(sha256sum "$FIXTURE_DIR/docqa_output.json" | awk '{print $1}')"
docqa_log_hash="$(sha256sum "$FIXTURE_DIR/docqa_run.log" | awk '{print $1}')"
docqa_attestation_hash="$(sha256sum "$FIXTURE_DIR/docqa_attestation.txt" | awk '{print $1}')"

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

cat >"$EXECUTION_CSV" <<CSV
benchmark_family,execution_id,evaluator_output_uri,evaluator_output_hash,run_log_uri,run_log_hash,metric_value,sample_count,execution_ready,evaluator_output_ready,run_log_ready,metric_output_ready,routing_trigger_rate,active_jump_rate
RULER,ruler-run-fixture,file://$FIXTURE_DIR/ruler_output.json,sha256:$ruler_output_hash,file://$FIXTURE_DIR/ruler_run.log,sha256:$ruler_log_hash,0.710000,128,1,1,1,1,0,0
LongBench,longbench-run-fixture,file://$FIXTURE_DIR/longbench_output.json,sha256:$longbench_output_hash,file://$FIXTURE_DIR/longbench_run.log,sha256:$longbench_log_hash,0.590000,128,1,1,1,1,0,0
codebase-retrieval,codebase-run-fixture,file://$FIXTURE_DIR/codebase_output.json,sha256:$codebase_output_hash,file://$FIXTURE_DIR/codebase_run.log,sha256:$codebase_log_hash,0.520000,128,1,1,1,1,0,0
real-document-qa,docqa-run-fixture,file://$FIXTURE_DIR/docqa_output.json,sha256:$docqa_output_hash,file://$FIXTURE_DIR/docqa_run.log,sha256:$docqa_log_hash,0.470000,128,1,1,1,1,0,0
CSV

cat >"$ATTESTATION_CSV" <<CSV
benchmark_family,execution_id,attestation_id,attestation_uri,attestation_hash,attestor_name,attestor_org,attestor_role,attestor_independent,attested_evaluator_output_hash,attested_run_log_hash,attested_metric_value,attestation_ready,attestor_ready,execution_hash_attested,metric_attested,routing_trigger_rate,active_jump_rate
RULER,ruler-run-fixture,ruler-attestation-fixture,file://$FIXTURE_DIR/ruler_attestation.txt,sha256:$ruler_attestation_hash,v08-fixture-attestor,fixture-org,fixture-role,0,sha256:$ruler_output_hash,sha256:$ruler_log_hash,0.710000,1,1,1,1,0,0
LongBench,longbench-run-fixture,longbench-attestation-fixture,file://$FIXTURE_DIR/longbench_attestation.txt,sha256:$longbench_attestation_hash,v08-fixture-attestor,fixture-org,fixture-role,0,sha256:$longbench_output_hash,sha256:$longbench_log_hash,0.590000,1,1,1,1,0,0
codebase-retrieval,codebase-run-fixture,codebase-attestation-fixture,file://$FIXTURE_DIR/codebase_attestation.txt,sha256:$codebase_attestation_hash,v08-fixture-attestor,fixture-org,fixture-role,0,sha256:$codebase_output_hash,sha256:$codebase_log_hash,0.520000,1,1,1,1,0,0
real-document-qa,docqa-run-fixture,docqa-attestation-fixture,file://$FIXTURE_DIR/docqa_attestation.txt,sha256:$docqa_attestation_hash,v08-fixture-attestor,fixture-org,fixture-role,0,sha256:$docqa_output_hash,sha256:$docqa_log_hash,0.470000,1,1,1,1,0,0
CSV

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$ATTESTATION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_attestation_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("evidence_source authenticity_source execution_source attestation_source benchmark_authenticity_verified evaluator_execution_verified attestation_rows matched_family_rows attestation_artifact_rows local_attestation_artifact_rows nonlocal_attestation_artifact_rows attestation_hash_verified_rows independent_attestor_rows execution_hash_attested_rows metric_attested_rows independent_attestation_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 attestation import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["evidence_source"] != "provided-csv" ||
        $idx["authenticity_source"] != "provided-csv" ||
        $idx["execution_source"] != "provided-csv" ||
        $idx["attestation_source"] != "provided-csv" ||
        ($idx["benchmark_authenticity_verified"] + 0) != 1 ||
        ($idx["evaluator_execution_verified"] + 0) != 1 ||
        ($idx["attestation_rows"] + 0) != 4 ||
        ($idx["matched_family_rows"] + 0) != 4 ||
        ($idx["attestation_artifact_rows"] + 0) != 4 ||
        ($idx["local_attestation_artifact_rows"] + 0) != 4 ||
        ($idx["nonlocal_attestation_artifact_rows"] + 0) != 0 ||
        ($idx["attestation_hash_verified_rows"] + 0) != 4 ||
        ($idx["independent_attestor_rows"] + 0) != 0 ||
        ($idx["execution_hash_attested_rows"] + 0) != 4 ||
        ($idx["metric_attested_rows"] + 0) != 4 ||
        ($idx["independent_attestation_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-independent-attestor-missing") {
      die("supplied v08 fixture attestation should verify local files but block independent attestation", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 attestation import", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 attestation import summary row", 5)
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
    if ($idx["gate"] == "evaluator-execution" && $idx["status"] != "pass") die("evaluator execution should pass", 20)
    if ($idx["gate"] == "attestation-rows" && $idx["status"] != "pass") die("attestation rows should pass", 21)
    if ($idx["gate"] == "execution-id-match" && $idx["status"] != "pass") die("execution ids should pass", 22)
    if ($idx["gate"] == "attestation-ready" && $idx["status"] != "pass") die("attestation readiness should pass", 23)
    if ($idx["gate"] == "local-attestation-artifacts" && $idx["status"] != "pass") die("local attestation artifacts should pass", 24)
    if ($idx["gate"] == "nonlocal-attestation-artifacts" && $idx["status"] != "blocked") die("nonlocal attestation artifacts should block for local fixture", 25)
    if ($idx["gate"] == "attestation-hashes" && $idx["status"] != "pass") die("attestation hashes should pass", 24)
    if ($idx["gate"] == "independent-attestor" && $idx["status"] != "blocked") die("fixture attestor should block independence", 25)
    if ($idx["gate"] == "execution-attested" && $idx["status"] != "pass") die("execution attestation should pass", 26)
    if ($idx["gate"] == "independent-attestation" && $idx["status"] != "blocked") die("independent attestation should block for fixture attestor", 27)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should still block", 28)
  }
  END {
    if (rows != 11) die("expected v08 attestation import decision rows", 29)
  }
' "$DECISION_CSV"

echo "v08 external benchmark attestation import smoke passed"
