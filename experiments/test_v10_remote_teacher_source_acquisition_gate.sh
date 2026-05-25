#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v10_remote_teacher_source_acquisition_fixture"
LOCAL_CSV="$RESULTS_DIR/v10_remote_teacher_source_acquisition_local_fixture.csv"
REMOTE_CSV="$RESULTS_DIR/v10_remote_teacher_source_acquisition_remote_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v10_remote_teacher_source_acquisition_malformed_fixture.csv"

sha_fixture() {
  local label="$1"
  printf 'sha256:%064x\n' "$label"
}

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing h10-m summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-m summary row", 4)
    }
  ' "$summary_csv"
}

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_acquisition_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_remote_teacher_source_acquisition_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_remote_teacher_source_acquisition_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("acquisition_source acquisition_rows required_uri_fields https_remote_uri_fields local_uri_fields placeholder_uri_fields insecure_uri_fields missing_uri_fields remote_uri_scheme_ready hash_manifest_ready remote_teacher_source_acquisition_ready real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10-m default summary column: " required[i], 10)
    }
    next
  }
  {
    rows++
    if ($idx["acquisition_source"] != "pending-fixture" ||
        ($idx["acquisition_rows"] + 0) != 0 ||
        ($idx["required_uri_fields"] + 0) != 0 ||
        ($idx["https_remote_uri_fields"] + 0) != 0 ||
        ($idx["local_uri_fields"] + 0) != 0 ||
        ($idx["placeholder_uri_fields"] + 0) != 0 ||
        ($idx["insecure_uri_fields"] + 0) != 0 ||
        ($idx["missing_uri_fields"] + 0) != 0 ||
        ($idx["remote_uri_scheme_ready"] + 0) != 0 ||
        ($idx["hash_manifest_ready"] + 0) != 0 ||
        ($idx["remote_teacher_source_acquisition_ready"] + 0) != 0 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["action"] != "remote-teacher-source-acquisition-missing") {
      die("default h10-m should block before remote acquisition evidence exists", 11)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for default h10-m", 12)
    }
  }
  END {
    if (rows != 1) die("expected one h10-m default summary row", 13)
  }
' "$SUMMARY_CSV"

mkdir -p "$FIXTURE_DIR"
for name in source labels identity policy license review; do
  printf '%s local acquisition fixture\n' "$name" >"$FIXTURE_DIR/${name}.txt"
done

source_hash="$(sha256sum "$FIXTURE_DIR/source.txt" | awk '{print $1}')"
label_hash="$(sha256sum "$FIXTURE_DIR/labels.txt" | awk '{print $1}')"
identity_hash="$(sha256sum "$FIXTURE_DIR/identity.txt" | awk '{print $1}')"
policy_hash="$(sha256sum "$FIXTURE_DIR/policy.txt" | awk '{print $1}')"
license_hash="$(sha256sum "$FIXTURE_DIR/license.txt" | awk '{print $1}')"
review_hash="$(sha256sum "$FIXTURE_DIR/review.txt" | awk '{print $1}')"

cat >"$LOCAL_CSV" <<CSV
teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,review_uri,review_hash,acquisition_method,retrieval_tool,content_hash_algorithm,teacher_model_family,provenance_basis,real_remote_source_declared,fixture_or_synthetic_declared,remote_acquisition_ready,review_ready,routing_trigger_rate,active_jump_rate
teacher-local-v1,file://$FIXTURE_DIR/source.txt,sha256:$source_hash,file://$FIXTURE_DIR/labels.txt,sha256:$label_hash,file://$FIXTURE_DIR/identity.txt,sha256:$identity_hash,file://$FIXTURE_DIR/policy.txt,sha256:$policy_hash,file://$FIXTURE_DIR/license.txt,sha256:$license_hash,file://$FIXTURE_DIR/review.txt,sha256:$review_hash,independent-remote-review,curl-8,sha256,fixture-teacher,local-fixture-chain,1,0,1,1,0,0
CSV

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$LOCAL_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_acquisition_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "acquisition_source" "provided-csv" "local fixture acquisition should be provided"
expect_summary_value "$SUMMARY_CSV" "acquisition_rows" "1" "local fixture acquisition should have one row"
expect_summary_value "$SUMMARY_CSV" "required_uri_fields" "6" "local fixture acquisition should expose six required URI fields"
expect_summary_value "$SUMMARY_CSV" "local_uri_fields" "6" "local file acquisition must be classified local"
expect_summary_value "$SUMMARY_CSV" "https_remote_uri_fields" "0" "local file acquisition must not count as remote"
expect_summary_value "$SUMMARY_CSV" "remote_uri_scheme_ready" "0" "local file acquisition must not pass remote URI scheme"
expect_summary_value "$SUMMARY_CSV" "hash_manifest_ready" "1" "local fixture can still exercise sha256 manifest mechanics"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_acquisition_ready" "0" "local fixture must not pass remote acquisition"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "local fixture must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-local-or-placeholder" "local fixture should block as local-or-placeholder"

cat >"$REMOTE_CSV" <<CSV
teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,review_uri,review_hash,acquisition_method,retrieval_tool,content_hash_algorithm,teacher_model_family,provenance_basis,real_remote_source_declared,fixture_or_synthetic_declared,remote_acquisition_ready,review_ready,routing_trigger_rate,active_jump_rate
teacher-remote-v1,https://teacher.example.org/source.json,$(sha_fixture 1),https://teacher.example.org/labels.csv,$(sha_fixture 2),https://teacher.example.org/identity.json,$(sha_fixture 3),https://teacher.example.org/policy.json,$(sha_fixture 4),https://teacher.example.org/license.txt,$(sha_fixture 5),https://review.example.org/teacher-remote-v1.txt,$(sha_fixture 6),independent-remote-review,curl-8,sha256,remote-teacher-family,remote-source-chain,1,0,1,1,0,0
CSV

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_acquisition_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "acquisition_rows" "1" "remote acquisition should have one row"
expect_summary_value "$SUMMARY_CSV" "required_uri_fields" "6" "remote acquisition should expose six required URI fields"
expect_summary_value "$SUMMARY_CSV" "https_remote_uri_fields" "6" "remote acquisition should classify all URI fields as HTTPS remote"
expect_summary_value "$SUMMARY_CSV" "local_uri_fields" "0" "remote acquisition should not contain local URI fields"
expect_summary_value "$SUMMARY_CSV" "placeholder_uri_fields" "0" "remote acquisition should not contain placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "sha256_hash_fields" "6" "remote acquisition should carry all sha256 hashes"
expect_summary_value "$SUMMARY_CSV" "remote_uri_scheme_ready" "1" "remote acquisition should pass URI-scheme contract"
expect_summary_value "$SUMMARY_CSV" "hash_manifest_ready" "1" "remote acquisition should pass hash manifest contract"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_acquisition_ready" "1" "remote acquisition contract should be ready"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "remote acquisition contract alone must not claim real fetched source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-fetcher-missing" "remote acquisition should block at fetcher/content verification"

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
    if ($idx["gate"] == "remote-uri-scheme" && $idx["status"] != "pass") die("remote URI scheme should pass for HTTPS fixture", 30)
    if ($idx["gate"] == "hash-manifest" && $idx["status"] != "pass") die("hash manifest should pass for HTTPS fixture", 31)
    if ($idx["gate"] == "acquisition-method" && $idx["status"] != "pass") die("acquisition method should pass for HTTPS fixture", 32)
    if ($idx["gate"] == "review-evidence" && $idx["status"] != "pass") die("review evidence should pass for HTTPS fixture", 33)
    if ($idx["gate"] == "real-source-declaration" && $idx["status"] != "pass") die("real-source declaration should pass the contract for HTTPS fixture", 34)
    if ($idx["gate"] == "remote-teacher-source-acquisition" && $idx["status"] != "pass") die("remote teacher source acquisition should pass contract", 35)
    if ($idx["gate"] == "real-teacher-source-verification" && $idx["status"] != "blocked") die("real teacher source verification should still block without fetcher", 36)
  }
  END {
    if (rows != 7) die("expected seven h10-m decision rows", 37)
  }
' "$DECISION_CSV"

{
  head -n 1 "$REMOTE_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$REMOTE_CSV")"
} >"$MALFORMED_CSV"

if V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v10_remote_teacher_source_acquisition_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h10-m should reject malformed acquisition CSV row widths" >&2
  exit 40
fi

echo "v10 remote teacher-source acquisition gate smoke passed"
