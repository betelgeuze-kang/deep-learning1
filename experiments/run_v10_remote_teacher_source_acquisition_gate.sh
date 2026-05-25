#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v10_remote_teacher_source_acquisition_gate"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_remote_teacher_source_acquisition_gate_smoke"
fi

ACQUISITION_CSV="$RESULTS_DIR/${PREFIX}_acquisition.csv"
ACQUISITION_SOURCE="pending-fixture"
if [[ -n "${V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV:-}" ]]; then
  ACQUISITION_CSV="$V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV"
  ACQUISITION_SOURCE="provided-csv"
  if [[ ! -s "$ACQUISITION_CSV" ]]; then
    echo "V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  cat >"$ACQUISITION_CSV" <<'CSV'
teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,review_uri,review_hash,acquisition_method,retrieval_tool,content_hash_algorithm,teacher_model_family,provenance_basis,real_remote_source_declared,fixture_or_synthetic_declared,remote_acquisition_ready,review_ready,routing_trigger_rate,active_jump_rate
CSV
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v acquisition_csv="$ACQUISITION_CSV" -v acquisition_source="$ACQUISITION_SOURCE" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function is_sha256(value,   hex) {
    if (value !~ /^sha256:/) return 0
    hex = substr(value, 8)
    return length(hex) == 64 && hex !~ /[^0-9a-fA-F]/
  }
  function is_present(value) {
    return value != "" && value != "pending"
  }
  function uri_class(uri,   lowered) {
    lowered = tolower(uri)
    if (!is_present(uri)) return "missing"
    if (lowered ~ /^file:\/\//) return "local"
    if (lowered ~ /^https:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])([:\/]|$)/) return "local"
    if (lowered ~ /^http:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])([:\/]|$)/) return "local"
    if (lowered ~ /^(external|fixture|local):\/\//) return "placeholder"
    if (lowered ~ /^https:\/\//) return "remote"
    if (lowered ~ /^http:\/\//) return "insecure"
    return "placeholder"
  }
  function count_uri(uri,   cls) {
    cls = uri_class(uri)
    required_uri_fields++
    if (cls == "remote") https_remote_uri_fields++
    else if (cls == "local") local_uri_fields++
    else if (cls == "placeholder") placeholder_uri_fields++
    else if (cls == "insecure") insecure_uri_fields++
    else missing_uri_fields++
    return cls
  }
  function count_hash(value) {
    required_hash_fields++
    if (is_sha256(value)) sha256_hash_fields++
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("teacher_id source_uri source_hash label_export_uri label_export_hash teacher_identity_uri teacher_identity_hash teacher_policy_uri teacher_policy_hash license_uri license_hash review_uri review_hash acquisition_method retrieval_tool content_hash_algorithm teacher_model_family provenance_basis real_remote_source_declared fixture_or_synthetic_declared remote_acquisition_ready review_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 remote teacher source acquisition column: " required[i], 2)
    }
    next
  }
  {
    if (NF != header_fields) die("h10 remote teacher source acquisition row has wrong column count", 3)
    acquisition_rows++
    row_remote_uri_fields = 0

    if (count_uri($idx["source_uri"]) == "remote") row_remote_uri_fields++
    if (count_uri($idx["label_export_uri"]) == "remote") row_remote_uri_fields++
    if (count_uri($idx["teacher_identity_uri"]) == "remote") row_remote_uri_fields++
    if (count_uri($idx["teacher_policy_uri"]) == "remote") row_remote_uri_fields++
    if (count_uri($idx["license_uri"]) == "remote") row_remote_uri_fields++
    if (count_uri($idx["review_uri"]) == "remote") row_remote_uri_fields++

    count_hash($idx["source_hash"])
    count_hash($idx["label_export_hash"])
    count_hash($idx["teacher_identity_hash"])
    count_hash($idx["teacher_policy_hash"])
    count_hash($idx["license_hash"])
    count_hash($idx["review_hash"])

    if (row_remote_uri_fields == 6) all_remote_uri_rows++
    if (is_present($idx["teacher_id"]) &&
        is_present($idx["acquisition_method"]) &&
        $idx["acquisition_method"] !~ /^(local|fixture|pending)$/ &&
        is_present($idx["retrieval_tool"]) &&
        tolower($idx["content_hash_algorithm"]) == "sha256" &&
        is_present($idx["teacher_model_family"]) &&
        is_present($idx["provenance_basis"])) {
      acquisition_method_rows++
    }
    if (($idx["review_ready"] + 0) == 1 && is_present($idx["review_uri"]) && is_sha256($idx["review_hash"])) {
      review_ready_rows++
    }
    if (($idx["real_remote_source_declared"] + 0) == 1) declared_real_rows++
    if (($idx["fixture_or_synthetic_declared"] + 0) == 0) non_fixture_declared_rows++
    if (($idx["remote_acquisition_ready"] + 0) == 1) remote_acquisition_ready_rows++
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    remote_uri_scheme_ready = 0
    if (acquisition_rows > 0 &&
        all_remote_uri_rows == acquisition_rows &&
        https_remote_uri_fields == required_uri_fields &&
        local_uri_fields == 0 &&
        placeholder_uri_fields == 0 &&
        insecure_uri_fields == 0 &&
        missing_uri_fields == 0) {
      remote_uri_scheme_ready = 1
    }

    hash_manifest_ready = 0
    if (acquisition_rows > 0 &&
        required_hash_fields > 0 &&
        sha256_hash_fields == required_hash_fields) {
      hash_manifest_ready = 1
    }

    acquisition_contract_ready = 0
    if (remote_uri_scheme_ready &&
        hash_manifest_ready &&
        acquisition_method_rows == acquisition_rows &&
        review_ready_rows == acquisition_rows &&
        declared_real_rows == acquisition_rows &&
        non_fixture_declared_rows == acquisition_rows &&
        remote_acquisition_ready_rows == acquisition_rows &&
        routing == 0.0 &&
        jump == 0.0) {
      acquisition_contract_ready = 1
    }

    remote_teacher_source_acquisition_ready = acquisition_contract_ready
    real_teacher_source_verified = 0
    action = "remote-teacher-source-acquisition-missing"
    if (acquisition_rows > 0) {
      if (!remote_uri_scheme_ready) {
        action = "remote-teacher-source-local-or-placeholder"
      } else if (!hash_manifest_ready) {
        action = "remote-teacher-source-hash-manifest-missing"
      } else if (acquisition_method_rows != acquisition_rows ||
                 review_ready_rows != acquisition_rows ||
                 declared_real_rows != acquisition_rows ||
                 non_fixture_declared_rows != acquisition_rows ||
                 remote_acquisition_ready_rows != acquisition_rows) {
        action = "remote-teacher-source-contract-incomplete"
      } else if (remote_teacher_source_acquisition_ready) {
        action = "remote-teacher-source-fetcher-missing"
      }
    }

    print "teacher_source_scope,acquisition_source,acquisition_rows,required_uri_fields,https_remote_uri_fields,local_uri_fields,placeholder_uri_fields,insecure_uri_fields,missing_uri_fields,all_remote_uri_rows,required_hash_fields,sha256_hash_fields,acquisition_method_rows,review_ready_rows,declared_real_rows,non_fixture_declared_rows,remote_acquisition_ready_rows,remote_uri_scheme_ready,hash_manifest_ready,remote_teacher_source_acquisition_ready,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-h10m,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      acquisition_source,
      acquisition_rows,
      required_uri_fields,
      https_remote_uri_fields,
      local_uri_fields,
      placeholder_uri_fields,
      insecure_uri_fields,
      missing_uri_fields,
      all_remote_uri_rows,
      required_hash_fields,
      sha256_hash_fields,
      acquisition_method_rows,
      review_ready_rows,
      declared_real_rows,
      non_fixture_declared_rows,
      remote_acquisition_ready_rows,
      remote_uri_scheme_ready,
      hash_manifest_ready,
      remote_teacher_source_acquisition_ready,
      real_teacher_source_verified,
      action,
      routing,
      jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "remote-uri-scheme,%s,remote_uri_fields=%d/%d local=%d placeholder=%d insecure=%d missing=%d\n",
      (remote_uri_scheme_ready ? "pass" : "blocked"),
      https_remote_uri_fields,
      required_uri_fields,
      local_uri_fields,
      placeholder_uri_fields,
      insecure_uri_fields,
      missing_uri_fields >> decision_csv
    printf "hash-manifest,%s,sha256=%d/%d\n",
      (hash_manifest_ready ? "pass" : "blocked"),
      sha256_hash_fields,
      required_hash_fields >> decision_csv
    printf "acquisition-method,%s,method_rows=%d/%d ready_rows=%d/%d\n",
      ((acquisition_method_rows == acquisition_rows && acquisition_rows > 0) ? "pass" : "blocked"),
      acquisition_method_rows,
      acquisition_rows,
      remote_acquisition_ready_rows,
      acquisition_rows >> decision_csv
    printf "review-evidence,%s,review_ready=%d/%d\n",
      ((review_ready_rows == acquisition_rows && acquisition_rows > 0) ? "pass" : "blocked"),
      review_ready_rows,
      acquisition_rows >> decision_csv
    printf "real-source-declaration,%s,declared_real=%d/%d non_fixture=%d/%d\n",
      ((declared_real_rows == acquisition_rows && non_fixture_declared_rows == acquisition_rows && acquisition_rows > 0) ? "pass" : "blocked"),
      declared_real_rows,
      acquisition_rows,
      non_fixture_declared_rows,
      acquisition_rows >> decision_csv
    printf "remote-teacher-source-acquisition,%s,ready=%d action=%s\n",
      (remote_teacher_source_acquisition_ready ? "pass" : "blocked"),
      remote_teacher_source_acquisition_ready,
      action >> decision_csv
    printf "real-teacher-source-verification,%s,real_verified=%d action=%s\n",
      (real_teacher_source_verified ? "pass" : "blocked"),
      real_teacher_source_verified,
      action >> decision_csv
  }
' "$ACQUISITION_CSV"

echo "acquisition: $ACQUISITION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
