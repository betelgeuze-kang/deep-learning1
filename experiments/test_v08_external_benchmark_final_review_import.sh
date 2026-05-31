#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_attestor_identity_fixture"
EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_evidence_fixture.csv"
AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_authenticity_fixture.csv"
EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_execution_fixture.csv"
ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_attestation_fixture.csv"
IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_fixture.csv"
REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_fixture.csv"

"$ROOT_DIR/experiments/test_v08_external_benchmark_attestor_identity_import.sh" >/dev/null

csv_lookup() {
  local csv="$1"
  local family="$2"
  local column="$3"

  awk -F, -v family="$family" -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!("benchmark_family" in idx)) exit 2
      if (!(column in idx)) exit 3
      next
    }
    $idx["benchmark_family"] == family {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) exit 4
    }
  ' "$csv"
}

write_review_files() {
  local short="$1"

  printf '%s local final review fixture\n' "$short" >"$FIXTURE_DIR/${short}_final_review.txt"
  printf '%s local final reviewer identity fixture\n' "$short" >"$FIXTURE_DIR/${short}_reviewer_identity.txt"
  printf '%s local final reviewer conflict fixture\n' "$short" >"$FIXTURE_DIR/${short}_reviewer_conflict.txt"
}

for short in ruler longbench codebase docqa; do
  write_review_files "$short"
done

{
  echo "benchmark_family,attestation_id,review_id,review_report_uri,review_report_hash,reviewer_name,reviewer_org,reviewer_role,reviewer_independent,reviewer_identity_uri,reviewer_identity_hash,reviewer_conflict_disclosure_uri,reviewer_conflict_disclosure_hash,review_scope,review_protocol_version,reviewed_source_hash,reviewed_provenance_hash,reviewed_evaluator_output_hash,reviewed_run_log_hash,reviewed_metric_value,reviewed_attestor_registry_id,real_benchmark_source_declared,fixture_or_synthetic_declared,license_review_ready,metric_review_ready,execution_review_ready,attestation_review_ready,identity_review_ready,conflict_review_ready,reproducibility_review_ready,review_approved,routing_trigger_rate,active_jump_rate"

  for pair in \
    "RULER ruler" \
    "LongBench longbench" \
    "codebase-retrieval codebase" \
    "real-document-qa docqa"; do
    set -- $pair
    family="$1"
    short="$2"

    attestation_id="$(csv_lookup "$ATTESTATION_CSV" "$family" attestation_id)"
    source_hash="$(csv_lookup "$EVIDENCE_CSV" "$family" source_hash)"
    provenance_hash="$(csv_lookup "$EVIDENCE_CSV" "$family" provenance_hash)"
    output_hash="$(csv_lookup "$EXECUTION_CSV" "$family" evaluator_output_hash)"
    run_log_hash="$(csv_lookup "$EXECUTION_CSV" "$family" run_log_hash)"
    metric_value="$(csv_lookup "$EXECUTION_CSV" "$family" metric_value)"
    registry_id="$(csv_lookup "$IDENTITY_CSV" "$family" attestor_registry_id)"
    review_hash="$(sha256sum "$FIXTURE_DIR/${short}_final_review.txt" | awk '{print $1}')"
    reviewer_identity_hash="$(sha256sum "$FIXTURE_DIR/${short}_reviewer_identity.txt" | awk '{print $1}')"
    reviewer_conflict_hash="$(sha256sum "$FIXTURE_DIR/${short}_reviewer_conflict.txt" | awk '{print $1}')"

    printf "%s,%s,%s-final-review-fixture,file://%s,sha256:%s,v08-fixture-final-reviewer,fixture-review-org,fixture-review-role,1,file://%s,sha256:%s,file://%s,sha256:%s,full-chain,v08-final-review-v1,%s,%s,%s,%s,%s,%s,0,1,1,1,1,1,1,1,1,1,0,0\n" \
      "$family" \
      "$attestation_id" \
      "$short" \
      "$FIXTURE_DIR/${short}_final_review.txt" \
      "$review_hash" \
      "$FIXTURE_DIR/${short}_reviewer_identity.txt" \
      "$reviewer_identity_hash" \
      "$FIXTURE_DIR/${short}_reviewer_conflict.txt" \
      "$reviewer_conflict_hash" \
      "$source_hash" \
      "$provenance_hash" \
      "$output_hash" \
      "$run_log_hash" \
      "$metric_value" \
      "$registry_id"
  done
} >"$REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV="$REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_final_review_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("final_review_source evaluator_execution_verified independent_attestation_verified attestor_identity_verified review_rows matched_attestation_rows review_artifact_rows review_hash_verified_rows local_final_review_artifact_rows nonlocal_final_review_artifact_rows reviewer_identity_rows reviewer_identity_hash_verified_rows local_reviewer_identity_rows nonlocal_reviewer_identity_rows reviewer_conflict_rows reviewer_conflict_hash_verified_rows local_reviewer_conflict_rows nonlocal_reviewer_conflict_rows local_upstream_evidence_artifact_rows local_upstream_execution_artifact_rows local_upstream_attestation_artifact_rows local_upstream_identity_artifact_rows local_upstream_artifact_rows critical_hash_match_rows metric_match_rows review_ready_rows review_approved_rows real_source_declared_rows non_fixture_declared_rows final_review_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 final review import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["final_review_source"] != "provided-csv" ||
        ($idx["evaluator_execution_verified"] + 0) != 1 ||
        ($idx["independent_attestation_verified"] + 0) != 1 ||
        ($idx["attestor_identity_verified"] + 0) != 1 ||
        ($idx["review_rows"] + 0) != 4 ||
        ($idx["matched_attestation_rows"] + 0) != 4 ||
        ($idx["review_artifact_rows"] + 0) != 4 ||
        ($idx["review_hash_verified_rows"] + 0) != 4 ||
        ($idx["local_final_review_artifact_rows"] + 0) != 4 ||
        ($idx["nonlocal_final_review_artifact_rows"] + 0) != 0 ||
        ($idx["reviewer_identity_rows"] + 0) != 4 ||
        ($idx["reviewer_identity_hash_verified_rows"] + 0) != 4 ||
        ($idx["local_reviewer_identity_rows"] + 0) != 4 ||
        ($idx["nonlocal_reviewer_identity_rows"] + 0) != 0 ||
        ($idx["reviewer_conflict_rows"] + 0) != 4 ||
        ($idx["reviewer_conflict_hash_verified_rows"] + 0) != 4 ||
        ($idx["local_reviewer_conflict_rows"] + 0) != 4 ||
        ($idx["nonlocal_reviewer_conflict_rows"] + 0) != 0 ||
        ($idx["local_upstream_evidence_artifact_rows"] + 0) != 8 ||
        ($idx["local_upstream_execution_artifact_rows"] + 0) != 8 ||
        ($idx["local_upstream_attestation_artifact_rows"] + 0) != 4 ||
        ($idx["local_upstream_identity_artifact_rows"] + 0) != 12 ||
        ($idx["local_upstream_artifact_rows"] + 0) != 32 ||
        ($idx["critical_hash_match_rows"] + 0) != 4 ||
        ($idx["metric_match_rows"] + 0) != 4 ||
        ($idx["review_ready_rows"] + 0) != 4 ||
        ($idx["review_approved_rows"] + 0) != 4 ||
        ($idx["real_source_declared_rows"] + 0) != 0 ||
        ($idx["non_fixture_declared_rows"] + 0) != 0 ||
        ($idx["final_review_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-real-source-review-missing") {
      die("supplied v08 final review fixture should verify review mechanics but keep real benchmark claim blocked", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 final review import", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 final review import summary row", 5)
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
    if ($idx["gate"] == "prior-attestor-identity" && $idx["status"] != "pass") die("prior attestor identity should pass", 20)
    if ($idx["gate"] == "review-rows" && $idx["status"] != "pass") die("review rows should pass", 21)
    if ($idx["gate"] == "review-artifact-hash" && $idx["status"] != "pass") die("review artifact hashes should pass", 22)
    if ($idx["gate"] == "reviewer-identity" && $idx["status"] != "pass") die("reviewer identity should pass", 23)
    if ($idx["gate"] == "reviewer-conflict-disclosure" && $idx["status"] != "pass") die("reviewer conflict disclosure should pass", 24)
    if ($idx["gate"] == "critical-hash-match" && $idx["status"] != "pass") die("critical hash match should pass", 25)
    if ($idx["gate"] == "metric-match" && $idx["status"] != "pass") die("metric match should pass", 26)
    if ($idx["gate"] == "real-source-declaration" && $idx["status"] != "blocked") die("real-source declaration should block for local fixture", 27)
    if ($idx["gate"] == "review-approval" && $idx["status"] != "pass") die("review approval should pass", 28)
    if ($idx["gate"] == "local-final-review-artifact" && $idx["status"] != "blocked") die("local final-review artifacts should block for local fixture", 29)
    if ($idx["gate"] == "nonlocal-final-review-artifact" && $idx["status"] != "blocked") die("nonlocal final-review artifacts should block for local fixture", 30)
    if ($idx["gate"] == "local-upstream-artifact" && $idx["status"] != "blocked") die("local upstream artifacts should block for local fixture", 31)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block", 32)
  }
  END {
    if (rows != 13) die("expected v08 final review import decision rows", 33)
  }
' "$DECISION_CSV"

echo "v08 external benchmark final review import smoke passed"
