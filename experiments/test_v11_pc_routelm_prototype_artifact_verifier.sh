#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

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
    required_count = split("prototype_artifact_scope prototype_source artifact_source prototype_rows artifact_rows matched_prototype_rows generator_hash_verified_rows route_memory_hash_verified_rows candidate_scorer_hash_verified_rows decoder_binding_hash_verified_rows nlg_smoke_hash_verified_rows benchmark_result_hash_verified_rows license_hash_verified_rows provenance_hash_verified_rows ready_rows local_fixture_uri_rows real_prototype_declared_rows non_fixture_declared_rows prototype_artifact_chain_verified real_pc_routelm_artifact_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11 artifact verifier summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11 artifact verifier summary row has wrong column count", 3)
    if ($idx["prototype_artifact_scope"] != "h11b-pc-routelm-artifacts" ||
        $idx["prototype_source"] != "pending-fixture" ||
        $idx["artifact_source"] != "pending-fixture" ||
        ($idx["prototype_rows"] + 0) != 0 ||
        ($idx["artifact_rows"] + 0) != 0 ||
        ($idx["matched_prototype_rows"] + 0) != 0 ||
        ($idx["generator_hash_verified_rows"] + 0) != 0 ||
        ($idx["route_memory_hash_verified_rows"] + 0) != 0 ||
        ($idx["candidate_scorer_hash_verified_rows"] + 0) != 0 ||
        ($idx["decoder_binding_hash_verified_rows"] + 0) != 0 ||
        ($idx["nlg_smoke_hash_verified_rows"] + 0) != 0 ||
        ($idx["benchmark_result_hash_verified_rows"] + 0) != 0 ||
        ($idx["license_hash_verified_rows"] + 0) != 0 ||
        ($idx["provenance_hash_verified_rows"] + 0) != 0 ||
        ($idx["ready_rows"] + 0) != 0 ||
        ($idx["local_fixture_uri_rows"] + 0) != 0 ||
        ($idx["real_prototype_declared_rows"] + 0) != 0 ||
        ($idx["non_fixture_declared_rows"] + 0) != 0 ||
        ($idx["prototype_artifact_chain_verified"] + 0) != 0 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        $idx["action"] != "pc-routelm-components-missing") {
      die("default h11 artifact verifier should stay component-blocked", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11 artifact verifier", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11 artifact verifier summary row", 6)
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
    if ($idx["gate"] == "prototype-evidence" && $idx["status"] != "blocked") die("prototype evidence should block by default", 20)
    if ($idx["gate"] == "artifact-chain" && $idx["status"] != "blocked") die("artifact chain should block by default", 21)
    if ($idx["gate"] == "real-pc-routelm-artifacts" && $idx["status"] != "blocked") die("real prototype artifacts should block by default", 22)
  }
  END {
    if (rows != 9) die("expected h11 artifact verifier decision rows", 23)
  }
' "$DECISION_CSV"

echo "v11 PC RouteLM prototype artifact verifier smoke passed"
