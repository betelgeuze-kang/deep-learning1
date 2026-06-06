#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" --smoke

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
    required_count = split("route_memory_scope artifact_source artifact_files_found hash_manifest_entries hash_verified_files route_memory_store_size_bytes route_memory_chunk_count route_memory_page_count route_memory_index_rows ssd_page_read_count ssd_bytes_per_query ssd_read_latency_ms ram_cache_hit_rate prefetch_hit_rate route_lookup_latency_ms candidate_scoring_latency_ms query_to_evidence_ms span_exact chunk_exact missing_abstain wrong_answer_rate route_lookup_works candidate_span_read_works route_memory_artifact_chain_verified real_pc_routelm_artifact_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11-c NVMe RouteMemory summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11-c NVMe RouteMemory summary row has wrong column count", 3)
    if ($idx["route_memory_scope"] != "h11c-nvme-route-memory" ||
        $idx["artifact_source"] != "generated-fixture" ||
        ($idx["artifact_files_found"] + 0) != 7 ||
        ($idx["hash_manifest_entries"] + 0) != 7 ||
        ($idx["hash_verified_files"] + 0) != 7 ||
        ($idx["route_memory_store_size_bytes"] + 0) <= 0 ||
        ($idx["route_memory_chunk_count"] + 0) != 3 ||
        ($idx["route_memory_page_count"] + 0) < 2 ||
        ($idx["route_memory_index_rows"] + 0) != 3 ||
        ($idx["ssd_page_read_count"] + 0) < 1 ||
        ($idx["ssd_bytes_per_query"] + 0.0) <= 0.0 ||
        ($idx["ssd_read_latency_ms"] + 0.0) <= 0.0 ||
        ($idx["ram_cache_hit_rate"] + 0.0) < 0.0 ||
        ($idx["prefetch_hit_rate"] + 0.0) < 0.0 ||
        ($idx["route_lookup_latency_ms"] + 0.0) <= 0.0 ||
        ($idx["candidate_scoring_latency_ms"] + 0.0) <= 0.0 ||
        ($idx["query_to_evidence_ms"] + 0.0) <= 0.0 ||
        ($idx["span_exact"] + 0.0) != 1.0 ||
        ($idx["chunk_exact"] + 0.0) != 1.0 ||
        ($idx["missing_abstain"] + 0.0) != 1.0 ||
        ($idx["wrong_answer_rate"] + 0.0) != 0.0 ||
        ($idx["route_lookup_works"] + 0) != 1 ||
        ($idx["candidate_span_read_works"] + 0) != 1 ||
        ($idx["route_memory_artifact_chain_verified"] + 0) != 1 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "nvme-route-memory-artifact-ready") {
      die("h11-c NVMe RouteMemory artifact smoke should verify store mechanics only", 4)
    }
    if (($idx["routing_trigger_rate"] + 0.0) != 0.0 ||
        ($idx["active_jump_rate"] + 0.0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11-c NVMe RouteMemory", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11-c NVMe RouteMemory summary row", 6)
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
    if ($idx["gate"] == "artifact-files" && $idx["status"] != "pass") die("artifact files should pass", 20)
    if ($idx["gate"] == "artifact-hashes" && $idx["status"] != "pass") die("artifact hashes should pass", 21)
    if ($idx["gate"] == "route-lookup" && $idx["status"] != "pass") die("route lookup should pass", 22)
    if ($idx["gate"] == "candidate-span-read" && $idx["status"] != "pass") die("candidate span read should pass", 23)
    if ($idx["gate"] == "retrieval-quality" && $idx["status"] != "pass") die("retrieval quality should pass", 24)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("jump guardrail should pass", 25)
    if ($idx["gate"] == "real-pc-routelm" && $idx["status"] != "blocked") die("real PC RouteLM should stay blocked", 26)
  }
  END {
    if (rows != 7) die("expected h11-c NVMe RouteMemory decision rows", 27)
  }
' "$DECISION_CSV"

echo "v11 NVMe RouteMemory store smoke passed"
