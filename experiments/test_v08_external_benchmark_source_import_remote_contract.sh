#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"

"$ROOT_DIR/experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh" >/dev/null

awk -F, -v OFS=, -v execution_csv="$REMOTE_EXECUTION_CSV" '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  function constant_hash(seed) {
    return "sha256:" seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed seed
  }
  BEGIN {
    while ((getline line < execution_csv) > 0) {
      line_no++
      n = split(line, parts, ",")
      if (line_no == 1 && line ~ /^benchmark_family,/) {
        for (i = 1; i <= n; i++) eidx[parts[i]] = i
        continue
      }
      family = parts[eidx["benchmark_family"]]
      output_uri[family] = parts[eidx["evaluator_output_uri"]]
      run_log_uri[family] = parts[eidx["run_log_uri"]]
      output_hash[family] = parts[eidx["evaluator_output_hash"]]
      run_log_hash[family] = parts[eidx["run_log_hash"]]
    }
    close(execution_csv)
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family dataset_uri result_uri source_hash provenance_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 source import remote contract evidence column: " required[i] > "/dev/stderr"
        exit 2
      }
    }
    print "benchmark_family,source_import_id,dataset_uri,result_uri,evaluator_output_uri,run_log_uri,source_hash,provenance_hash,evaluator_output_hash,run_log_hash,import_manifest_uri,import_manifest_hash,import_fetch_log_uri,import_fetch_log_hash,import_reviewer_identity_uri,import_reviewer_identity_hash,source_import_protocol_version,live_network_import_performed,offline_replay_used,real_source_import_declared,fixture_or_synthetic_declared,independent_source_import_reviewed,routing_trigger_rate,active_jump_rate,import_manifest_hash_attested,import_fetch_log_hash_attested,import_reviewer_identity_hash_attested"
    next
  }
  {
    family = $idx["benchmark_family"]
    slug = slugify(family)
    print family,
      "source-import-" slug,
      $idx["dataset_uri"],
      $idx["result_uri"],
      output_uri[family],
      run_log_uri[family],
      $idx["source_hash"],
      $idx["provenance_hash"],
      output_hash[family],
      run_log_hash[family],
      "https://benchmarks.example.invalid/v08/source-import/" slug "-manifest.json",
      constant_hash("a"),
      "https://benchmarks.example.invalid/v08/source-import/" slug "-fetch.log",
      constant_hash("b"),
      "https://benchmarks.example.invalid/v08/source-import/" slug "-reviewer.json",
      constant_hash("c"),
      "v08-source-import-v1",
      1,
      0,
      1,
      0,
      1,
      "0.000000",
      "0.000000",
      1,
      1,
      1
  }
' "$REMOTE_EVIDENCE_CSV" >"$SOURCE_IMPORT_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("source_import_source attestor_identity_verified source_import_rows artifact_uri_match_rows critical_hash_match_rows import_ready_rows import_artifact_rows import_hash_verified_rows local_import_artifact_rows nonlocal_import_artifact_rows live_network_import_rows offline_replay_rows real_source_import_declared_rows non_fixture_declared_rows independent_import_reviewed_rows source_import_contract_ready source_import_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 source import remote contract summary column: " required[i], 3)
    }
    next
  }
  {
    rows++
    if ($idx["source_import_source"] != "provided-csv" ||
        ($idx["attestor_identity_verified"] + 0) != 1 ||
        ($idx["source_import_rows"] + 0) != 4 ||
        ($idx["artifact_uri_match_rows"] + 0) != 4 ||
        ($idx["critical_hash_match_rows"] + 0) != 4 ||
        ($idx["import_ready_rows"] + 0) != 4 ||
        ($idx["import_artifact_rows"] + 0) != 12 ||
        ($idx["import_hash_verified_rows"] + 0) != 12 ||
        ($idx["local_import_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_import_artifact_rows"] + 0) != 12 ||
        ($idx["live_network_import_rows"] + 0) != 4 ||
        ($idx["offline_replay_rows"] + 0) != 0 ||
        ($idx["real_source_import_declared_rows"] + 0) != 4 ||
        ($idx["non_fixture_declared_rows"] + 0) != 4 ||
        ($idx["independent_import_reviewed_rows"] + 0) != 4 ||
        ($idx["source_import_contract_ready"] + 0) != 1 ||
        ($idx["source_import_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-source-import-real-verifier-missing") {
      die("remote-style source import contract should pass mechanics but not verify real source", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 source import remote contract", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v08 source import remote contract summary row", 6)
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
    if ($idx["gate"] == "source-import-contract" && $idx["status"] != "pass") die("source import contract should pass for remote-style fixture", 20)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("source import verification should remain blocked", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should remain blocked", 22)
  }
  END {
    if (rows != 11) die("expected v08 source import remote contract decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark source import remote contract smoke passed"
