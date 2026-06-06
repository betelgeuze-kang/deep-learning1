#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v11_pc_routelm_prototype_artifact_fixture"
PROTOTYPE_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_artifact_import_prototype.csv"
ARTIFACT_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_artifact_import_artifacts.csv"
MISDECLARED_ARTIFACT_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_artifact_import_misdeclared_artifacts.csv"

mkdir -p "$FIXTURE_DIR"

printf 'generator model fixture\n' >"$FIXTURE_DIR/generator.bin"
printf 'route memory store fixture\n' >"$FIXTURE_DIR/route_memory.store"
printf 'candidate scorer fixture\n' >"$FIXTURE_DIR/candidate_scorer.bin"
printf 'decoder binding fixture\n' >"$FIXTURE_DIR/decoder_binding.bin"
printf 'nlg smoke output fixture\n' >"$FIXTURE_DIR/nlg_smoke.txt"
printf 'benchmark result fixture\n' >"$FIXTURE_DIR/benchmark_result.json"
printf 'license fixture\n' >"$FIXTURE_DIR/license.txt"
printf 'provenance fixture\n' >"$FIXTURE_DIR/provenance.json"

generator_hash="$(sha256sum "$FIXTURE_DIR/generator.bin" | awk '{print $1}')"
route_memory_hash="$(sha256sum "$FIXTURE_DIR/route_memory.store" | awk '{print $1}')"
scorer_hash="$(sha256sum "$FIXTURE_DIR/candidate_scorer.bin" | awk '{print $1}')"
decoder_hash="$(sha256sum "$FIXTURE_DIR/decoder_binding.bin" | awk '{print $1}')"
nlg_hash="$(sha256sum "$FIXTURE_DIR/nlg_smoke.txt" | awk '{print $1}')"
benchmark_hash="$(sha256sum "$FIXTURE_DIR/benchmark_result.json" | awk '{print $1}')"
license_hash="$(sha256sum "$FIXTURE_DIR/license.txt" | awk '{print $1}')"
provenance_hash="$(sha256sum "$FIXTURE_DIR/provenance.json" | awk '{print $1}')"

cat >"$PROTOTYPE_CSV" <<CSV
prototype_id,generator_model_uri,parameter_class,quantization,route_memory_store_uri,route_memory_residency,route_memory_index_policy,candidate_scoring_device,decoder_device,nlg_smoke_uri,nlg_smoke_ready,benchmark_result_uri,license,provenance_hash,routing_trigger_rate,active_jump_rate
h11-fixture,file://$FIXTURE_DIR/generator.bin,7b,int4,file://$FIXTURE_DIR/route_memory.store,cpu-ram,o-n-scan,gpu,gpu,file://$FIXTURE_DIR/nlg_smoke.txt,1,file://$FIXTURE_DIR/benchmark_result.json,permissive,sha256:$provenance_hash,0,0
CSV

cat >"$ARTIFACT_CSV" <<CSV
prototype_id,generator_model_uri,generator_model_hash,route_memory_store_uri,route_memory_store_hash,candidate_scoring_uri,candidate_scoring_hash,decoder_binding_uri,decoder_binding_hash,nlg_smoke_uri,nlg_smoke_hash,benchmark_result_uri,benchmark_result_hash,license_uri,license_hash,provenance_uri,provenance_hash,real_prototype_declared,fixture_or_synthetic_declared,artifact_bundle_ready,nlg_transcript_ready,benchmark_link_ready,license_ready,provenance_ready,routing_trigger_rate,active_jump_rate
h11-fixture,file://$FIXTURE_DIR/generator.bin,sha256:$generator_hash,file://$FIXTURE_DIR/route_memory.store,sha256:$route_memory_hash,file://$FIXTURE_DIR/candidate_scorer.bin,sha256:$scorer_hash,file://$FIXTURE_DIR/decoder_binding.bin,sha256:$decoder_hash,file://$FIXTURE_DIR/nlg_smoke.txt,sha256:$nlg_hash,file://$FIXTURE_DIR/benchmark_result.json,sha256:$benchmark_hash,file://$FIXTURE_DIR/license.txt,sha256:$license_hash,file://$FIXTURE_DIR/provenance.json,sha256:$provenance_hash,0,1,1,1,1,1,1,0,0
CSV

V11_PC_ROUTELM_PROTOTYPE_CSV="$PROTOTYPE_CSV" \
V11_PC_ROUTELM_PROTOTYPE_ARTIFACT_CSV="$ARTIFACT_CSV" \
  "$ROOT_DIR/experiments/run_v11_pc_routelm_prototype_artifact_verifier.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_artifact_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_artifact_verifier_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("prototype_source artifact_source prototype_rows artifact_rows matched_prototype_rows generator_hash_verified_rows route_memory_hash_verified_rows candidate_scorer_hash_verified_rows decoder_binding_hash_verified_rows nlg_smoke_hash_verified_rows benchmark_result_hash_verified_rows license_hash_verified_rows provenance_hash_verified_rows ready_rows local_fixture_uri_rows real_prototype_declared_rows non_fixture_declared_rows prototype_artifact_chain_verified real_pc_routelm_artifact_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11 artifact import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11 artifact import summary row has wrong column count", 3)
    if ($idx["prototype_source"] != "provided-csv" ||
        $idx["artifact_source"] != "provided-csv" ||
        ($idx["prototype_rows"] + 0) != 1 ||
        ($idx["artifact_rows"] + 0) != 1 ||
        ($idx["matched_prototype_rows"] + 0) != 1 ||
        ($idx["generator_hash_verified_rows"] + 0) != 1 ||
        ($idx["route_memory_hash_verified_rows"] + 0) != 1 ||
        ($idx["candidate_scorer_hash_verified_rows"] + 0) != 1 ||
        ($idx["decoder_binding_hash_verified_rows"] + 0) != 1 ||
        ($idx["nlg_smoke_hash_verified_rows"] + 0) != 1 ||
        ($idx["benchmark_result_hash_verified_rows"] + 0) != 1 ||
        ($idx["license_hash_verified_rows"] + 0) != 1 ||
        ($idx["provenance_hash_verified_rows"] + 0) != 1 ||
        ($idx["ready_rows"] + 0) != 1 ||
        ($idx["local_fixture_uri_rows"] + 0) != 1 ||
        ($idx["real_prototype_declared_rows"] + 0) != 0 ||
        ($idx["non_fixture_declared_rows"] + 0) != 0 ||
        ($idx["prototype_artifact_chain_verified"] + 0) != 1 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        $idx["action"] != "pc-routelm-real-artifact-review-missing") {
      die("supplied h11 artifact fixture should verify mechanics but keep real prototype blocked", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11 artifact import", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11 artifact import summary row", 6)
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
    if ($idx["gate"] == "prototype-evidence" && $idx["status"] != "pass") die("prototype evidence should pass", 20)
    if ($idx["gate"] == "artifact-chain" && $idx["status"] != "pass") die("artifact chain should pass", 21)
    if ($idx["gate"] == "real-pc-routelm-artifacts" && $idx["status"] != "blocked") die("real prototype artifacts should block for local fixture", 22)
  }
  END {
    if (rows != 9) die("expected h11 artifact import decision rows", 23)
  }
' "$DECISION_CSV"

cat >"$MISDECLARED_ARTIFACT_CSV" <<CSV
prototype_id,generator_model_uri,generator_model_hash,route_memory_store_uri,route_memory_store_hash,candidate_scoring_uri,candidate_scoring_hash,decoder_binding_uri,decoder_binding_hash,nlg_smoke_uri,nlg_smoke_hash,benchmark_result_uri,benchmark_result_hash,license_uri,license_hash,provenance_uri,provenance_hash,real_prototype_declared,fixture_or_synthetic_declared,artifact_bundle_ready,nlg_transcript_ready,benchmark_link_ready,license_ready,provenance_ready,routing_trigger_rate,active_jump_rate
h11-fixture,file://$FIXTURE_DIR/generator.bin,sha256:$generator_hash,file://$FIXTURE_DIR/route_memory.store,sha256:$route_memory_hash,file://$FIXTURE_DIR/candidate_scorer.bin,sha256:$scorer_hash,file://$FIXTURE_DIR/decoder_binding.bin,sha256:$decoder_hash,file://$FIXTURE_DIR/nlg_smoke.txt,sha256:$nlg_hash,file://$FIXTURE_DIR/benchmark_result.json,sha256:$benchmark_hash,file://$FIXTURE_DIR/license.txt,sha256:$license_hash,file://$FIXTURE_DIR/provenance.json,sha256:$provenance_hash,1,0,1,1,1,1,1,0,0
CSV

V11_PC_ROUTELM_PROTOTYPE_CSV="$PROTOTYPE_CSV" \
V11_PC_ROUTELM_PROTOTYPE_ARTIFACT_CSV="$MISDECLARED_ARTIFACT_CSV" \
  "$ROOT_DIR/experiments/run_v11_pc_routelm_prototype_artifact_verifier.sh" --smoke

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("local_fixture_uri_rows real_prototype_declared_rows non_fixture_declared_rows prototype_artifact_chain_verified real_pc_routelm_artifact_verified action", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11 misdeclared artifact summary column: " required[i], 30)
    }
    next
  }
  {
    rows++
    if (($idx["local_fixture_uri_rows"] + 0) != 1 ||
        ($idx["real_prototype_declared_rows"] + 0) != 1 ||
        ($idx["non_fixture_declared_rows"] + 0) != 1 ||
        ($idx["prototype_artifact_chain_verified"] + 0) != 1 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        $idx["action"] != "pc-routelm-real-artifact-review-missing") {
      die("local prototype fixture must not become real by declaration flags", 31)
    }
  }
  END {
    if (rows != 1) die("expected one h11 misdeclared artifact summary row", 32)
  }
' "$SUMMARY_CSV"

echo "v11 PC RouteLM prototype artifact import smoke passed"
