#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

LOCAL_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_evidence_fixture.csv"
LOCAL_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_authenticity_fixture.csv"
LOCAL_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_execution_fixture.csv"
LOCAL_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_attestation_fixture.csv"
LOCAL_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_fixture.csv"

REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"

"$ROOT_DIR/experiments/test_v08_external_benchmark_attestor_identity_import.sh" >/dev/null

awk -F, -v OFS=, '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family dataset_uri result_uri", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 lower-chain remote evidence column: " required[i] > "/dev/stderr"
        exit 2
      }
    }
    print $0, "source_hash_attested", "provenance_hash_attested"
    next
  }
  {
    family_slug = slugify($idx["benchmark_family"])
    $idx["dataset_uri"] = "https://benchmarks.example.invalid/v08/evidence/" family_slug "-dataset.jsonl"
    $idx["result_uri"] = "https://benchmarks.example.invalid/v08/evidence/" family_slug "-result.json"
    print $0, 1, 1
  }
' "$LOCAL_EVIDENCE_CSV" >"$REMOTE_EVIDENCE_CSV"

awk -F, -v OFS=, '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family canonical_dataset_uri canonical_result_uri", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 lower-chain remote authenticity column: " required[i] > "/dev/stderr"
        exit 3
      }
    }
    print $0
    next
  }
  {
    family_slug = slugify($idx["benchmark_family"])
    $idx["canonical_dataset_uri"] = "https://benchmarks.example.invalid/v08/evidence/" family_slug "-dataset.jsonl"
    $idx["canonical_result_uri"] = "https://benchmarks.example.invalid/v08/evidence/" family_slug "-result.json"
    print $0
  }
' "$LOCAL_AUTHENTICITY_CSV" >"$REMOTE_AUTHENTICITY_CSV"

awk -F, -v OFS=, '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family evaluator_output_uri run_log_uri", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 lower-chain remote execution column: " required[i] > "/dev/stderr"
        exit 4
      }
    }
    print $0, "evaluator_output_hash_attested", "run_log_hash_attested"
    next
  }
  {
    family_slug = slugify($idx["benchmark_family"])
    $idx["evaluator_output_uri"] = "https://benchmarks.example.invalid/v08/execution/" family_slug "-output.json"
    $idx["run_log_uri"] = "https://benchmarks.example.invalid/v08/execution/" family_slug "-run.log"
    print $0, 1, 1
  }
' "$LOCAL_EXECUTION_CSV" >"$REMOTE_EXECUTION_CSV"

awk -F, -v OFS=, '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family attestation_uri", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 lower-chain remote attestation column: " required[i] > "/dev/stderr"
        exit 5
      }
    }
    print $0, "attestation_hash_attested"
    next
  }
  {
    family_slug = slugify($idx["benchmark_family"])
    $idx["attestation_uri"] = "https://benchmarks.example.invalid/v08/attestation/" family_slug "-attestation.json"
    print $0, 1
  }
' "$LOCAL_ATTESTATION_CSV" >"$REMOTE_ATTESTATION_CSV"

awk -F, -v OFS=, '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family attestor_identity_uri attestor_registry_uri conflict_disclosure_uri", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 lower-chain remote identity column: " required[i] > "/dev/stderr"
        exit 6
      }
    }
    print $0, "attestor_identity_hash_attested", "attestor_registry_hash_attested", "conflict_disclosure_hash_attested"
    next
  }
  {
    family_slug = slugify($idx["benchmark_family"])
    $idx["attestor_identity_uri"] = "https://benchmarks.example.invalid/v08/attestor/" family_slug "-identity.json"
    $idx["attestor_registry_uri"] = "https://benchmarks.example.invalid/v08/attestor/" family_slug "-registry.json"
    $idx["conflict_disclosure_uri"] = "https://benchmarks.example.invalid/v08/attestor/" family_slug "-conflict.json"
    print $0, 1, 1, 1
  }
' "$LOCAL_IDENTITY_CSV" >"$REMOTE_IDENTITY_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_attestor_identity_gate.sh" --smoke

ARTIFACT_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_smoke_summary.csv"
EXECUTION_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_execution_gate_smoke_summary.csv"
ATTESTATION_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_gate_smoke_summary.csv"
IDENTITY_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_gate_smoke_summary.csv"
IDENTITY_DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("evidence_source dataset_artifact_rows local_dataset_uri_rows nonlocal_dataset_uri_rows result_artifact_rows local_result_uri_rows nonlocal_result_uri_rows source_hash_verified_rows provenance_hash_verified_rows artifact_verifier_ready real_external_benchmark_verified action", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 lower-chain remote artifact summary column: " required[i], 7)
    }
    next
  }
  {
    rows++
    if ($idx["evidence_source"] != "provided-csv" ||
        ($idx["dataset_artifact_rows"] + 0) != 4 ||
        ($idx["local_dataset_uri_rows"] + 0) != 0 ||
        ($idx["nonlocal_dataset_uri_rows"] + 0) != 4 ||
        ($idx["result_artifact_rows"] + 0) != 4 ||
        ($idx["local_result_uri_rows"] + 0) != 0 ||
        ($idx["nonlocal_result_uri_rows"] + 0) != 4 ||
        ($idx["source_hash_verified_rows"] + 0) != 4 ||
        ($idx["provenance_hash_verified_rows"] + 0) != 4 ||
        ($idx["artifact_verifier_ready"] + 0) != 1 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "benchmark-authenticity-verifier-missing") {
      die("remote evidence artifacts should hash-attest without local files", 8)
    }
  }
  END {
    if (rows != 1) die("expected one v08 lower-chain remote artifact summary row", 9)
  }
' "$ARTIFACT_SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("execution_source output_artifact_rows local_output_artifact_rows nonlocal_output_artifact_rows run_log_artifact_rows local_run_log_artifact_rows nonlocal_run_log_artifact_rows output_hash_verified_rows run_log_hash_verified_rows evaluator_execution_verified real_external_benchmark_verified action", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 lower-chain remote execution summary column: " required[i], 10)
    }
    next
  }
  {
    rows++
    if ($idx["execution_source"] != "provided-csv" ||
        ($idx["output_artifact_rows"] + 0) != 4 ||
        ($idx["local_output_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_output_artifact_rows"] + 0) != 4 ||
        ($idx["run_log_artifact_rows"] + 0) != 4 ||
        ($idx["local_run_log_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_run_log_artifact_rows"] + 0) != 4 ||
        ($idx["output_hash_verified_rows"] + 0) != 4 ||
        ($idx["run_log_hash_verified_rows"] + 0) != 4 ||
        ($idx["evaluator_execution_verified"] + 0) != 1 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-attestation-missing") {
      die("remote execution artifacts should hash-attest without local files", 11)
    }
  }
  END {
    if (rows != 1) die("expected one v08 lower-chain remote execution summary row", 12)
  }
' "$EXECUTION_SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("attestation_source attestation_artifact_rows local_attestation_artifact_rows nonlocal_attestation_artifact_rows attestation_hash_verified_rows independent_attestor_rows independent_attestation_verified real_external_benchmark_verified action", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 lower-chain remote attestation summary column: " required[i], 13)
    }
    next
  }
  {
    rows++
    if ($idx["attestation_source"] != "provided-csv" ||
        ($idx["attestation_artifact_rows"] + 0) != 4 ||
        ($idx["local_attestation_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_attestation_artifact_rows"] + 0) != 4 ||
        ($idx["attestation_hash_verified_rows"] + 0) != 4 ||
        ($idx["independent_attestor_rows"] + 0) != 4 ||
        ($idx["independent_attestation_verified"] + 0) != 1 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-final-review-missing") {
      die("remote attestation artifacts should hash-attest without local files", 14)
    }
  }
  END {
    if (rows != 1) die("expected one v08 lower-chain remote attestation summary row", 15)
  }
' "$ATTESTATION_SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("attestor_identity_source evaluator_execution_verified independent_attestation_verified identity_artifact_rows local_identity_artifact_rows nonlocal_identity_artifact_rows identity_hash_verified_rows registry_artifact_rows local_registry_artifact_rows nonlocal_registry_artifact_rows registry_hash_verified_rows conflict_disclosure_rows local_conflict_disclosure_rows nonlocal_conflict_disclosure_rows conflict_disclosure_hash_verified_rows attestor_identity_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 lower-chain remote identity summary column: " required[i], 16)
    }
    next
  }
  {
    rows++
    if ($idx["attestor_identity_source"] != "provided-csv" ||
        ($idx["evaluator_execution_verified"] + 0) != 1 ||
        ($idx["independent_attestation_verified"] + 0) != 1 ||
        ($idx["identity_artifact_rows"] + 0) != 4 ||
        ($idx["local_identity_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_identity_artifact_rows"] + 0) != 4 ||
        ($idx["identity_hash_verified_rows"] + 0) != 4 ||
        ($idx["registry_artifact_rows"] + 0) != 4 ||
        ($idx["local_registry_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_registry_artifact_rows"] + 0) != 4 ||
        ($idx["registry_hash_verified_rows"] + 0) != 4 ||
        ($idx["conflict_disclosure_rows"] + 0) != 4 ||
        ($idx["local_conflict_disclosure_rows"] + 0) != 0 ||
        ($idx["nonlocal_conflict_disclosure_rows"] + 0) != 4 ||
        ($idx["conflict_disclosure_hash_verified_rows"] + 0) != 4 ||
        ($idx["attestor_identity_verified"] + 0) != 1 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-final-review-missing") {
      die("remote identity artifacts should hash-attest without local files", 17)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 lower-chain remote artifacts", 18)
    }
  }
  END {
    if (rows != 1) die("expected one v08 lower-chain remote identity summary row", 19)
  }
' "$IDENTITY_SUMMARY_CSV"

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
    if ($idx["gate"] == "local-identity-artifacts" && $idx["status"] != "blocked") die("local identity artifacts should block for remote lower-chain fixture", 20)
    if ($idx["gate"] == "nonlocal-identity-artifacts" && $idx["status"] != "pass") die("nonlocal identity artifacts should pass", 21)
    if ($idx["gate"] == "attestor-identity" && $idx["status"] != "pass") die("attestor identity should pass", 22)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should remain blocked", 23)
  }
  END {
    if (rows != 10) die("expected v08 lower-chain remote identity decision rows", 24)
  }
' "$IDENTITY_DECISION_CSV"

echo "v08 external benchmark lower-chain remote artifacts smoke passed"
