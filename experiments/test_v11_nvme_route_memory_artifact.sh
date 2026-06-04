#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" --smoke >/dev/null

GOOD_DIR="$RESULTS_DIR/v11_nvme_route_memory_store_smoke_artifacts/routelm/store"
BAD_DIR="$RESULTS_DIR/v11_nvme_route_memory_store_bad_hash_artifacts/routelm/store"

rm -rf "$RESULTS_DIR/v11_nvme_route_memory_store_bad_hash_artifacts"
mkdir -p "$(dirname "$BAD_DIR")"
cp -R "$GOOD_DIR" "$BAD_DIR"
printf '\ncorrupt-hash-fixture\n' >>"$BAD_DIR/chunk_credit.bin"

V11_NVME_ROUTE_MEMORY_STORE_DIR="$BAD_DIR" \
  "$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" --smoke >/dev/null

SUMMARY_CSV="$RESULTS_DIR/v11_nvme_route_memory_store_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v11_nvme_route_memory_store_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("artifact_source artifact_files_found hash_manifest_entries hash_verified_files route_lookup_works candidate_span_read_works route_memory_artifact_chain_verified real_pc_routelm_artifact_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11-c bad artifact summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11-c bad artifact summary row has wrong column count", 3)
    if ($idx["artifact_source"] != "provided-dir" ||
        ($idx["artifact_files_found"] + 0) != 7 ||
        ($idx["hash_manifest_entries"] + 0) != 7 ||
        ($idx["hash_verified_files"] + 0) != 6 ||
        ($idx["route_lookup_works"] + 0) != 1 ||
        ($idx["candidate_span_read_works"] + 0) != 1 ||
        ($idx["route_memory_artifact_chain_verified"] + 0) != 0 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "nvme-route-memory-artifact-hash-mismatch") {
      die("h11-c bad hash artifact should block artifact-chain verification", 4)
    }
    if (($idx["routing_trigger_rate"] + 0.0) != 0.0 ||
        ($idx["active_jump_rate"] + 0.0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11-c bad artifact", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11-c bad artifact summary row", 6)
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
    if ($idx["gate"] == "artifact-files" && $idx["status"] != "pass") die("artifact files should still pass", 20)
    if ($idx["gate"] == "artifact-hashes" && $idx["status"] != "blocked") die("artifact hashes should block", 21)
    if ($idx["gate"] == "route-lookup" && $idx["status"] != "pass") die("route lookup should still pass", 22)
    if ($idx["gate"] == "candidate-span-read" && $idx["status"] != "pass") die("span read should still pass", 23)
    if ($idx["gate"] == "real-pc-routelm" && $idx["status"] != "blocked") die("real PC RouteLM should stay blocked", 24)
  }
  END {
    if (rows != 7) die("expected h11-c bad artifact decision rows", 25)
  }
' "$DECISION_CSV"

echo "v11 NVMe RouteMemory artifact guard smoke passed"
