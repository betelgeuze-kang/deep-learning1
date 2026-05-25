#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v10_teacher_external_label_source_fixture"
LABEL_CSV="$RESULTS_DIR/v10_teacher_external_label_source_import_labels.csv"
SOURCE_CSV="$RESULTS_DIR/v10_teacher_external_label_source_import_source.csv"
MISDECLARED_SOURCE_CSV="$RESULTS_DIR/v10_teacher_external_label_source_import_misdeclared_source.csv"

mkdir -p "$FIXTURE_DIR"

printf 'teacher source fixture\n' >"$FIXTURE_DIR/source.txt"
printf 'teacher identity fixture\n' >"$FIXTURE_DIR/identity.txt"
printf 'teacher policy fixture\n' >"$FIXTURE_DIR/policy.txt"
printf 'teacher license fixture\n' >"$FIXTURE_DIR/license.txt"

source_hash="$(sha256sum "$FIXTURE_DIR/source.txt" | awk '{print $1}')"
identity_hash="$(sha256sum "$FIXTURE_DIR/identity.txt" | awk '{print $1}')"
policy_hash="$(sha256sum "$FIXTURE_DIR/policy.txt" | awk '{print $1}')"
license_hash="$(sha256sum "$FIXTURE_DIR/license.txt" | awk '{print $1}')"

cat >"$LABEL_CSV" <<CSV
external_label_id,source_uri,teacher_id,query_key,candidate_key,teacher_label,expected_action,confidence,evidence_span_start,evidence_span_len,provenance_hash,license,routing_trigger_rate,active_jump_rate
ext-001,file://$FIXTURE_DIR/source.txt,teacher-fixture-v1,Q_ALPHA,C_ALPHA,correct,accept,0.990000,0,5,sha256:$source_hash,permissive,0,0
ext-002,file://$FIXTURE_DIR/source.txt,teacher-fixture-v1,Q_BETA,C_GAMMA,wrong,reject,0.940000,5,5,sha256:$source_hash,permissive,0,0
ext-003,file://$FIXTURE_DIR/source.txt,teacher-fixture-v1,Q_DELTA,C_DELTA_NEAR,near-miss,weak-hint,0.820000,10,5,sha256:$source_hash,permissive,0,0
ext-004,file://$FIXTURE_DIR/source.txt,teacher-fixture-v1,Q_MISSING,C_NONE,missing-query,abstain,0.910000,15,0,sha256:$source_hash,permissive,0,0
ext-005,file://$FIXTURE_DIR/source.txt,teacher-fixture-v1,Q_UNCERTAIN,C_UNCERTAIN,abstain,abstain,0.760000,15,5,sha256:$source_hash,permissive,0,0
CSV

label_export_hash="$(sha256sum "$LABEL_CSV" | awk '{print $1}')"

cat >"$SOURCE_CSV" <<CSV
teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_model_family,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,provenance_basis,real_teacher_source_declared,fixture_or_synthetic_declared,source_artifact_ready,label_export_ready,teacher_identity_ready,teacher_policy_ready,license_ready,routing_trigger_rate,active_jump_rate
teacher-fixture-v1,file://$FIXTURE_DIR/source.txt,sha256:$source_hash,file://$LABEL_CSV,sha256:$label_export_hash,file://$FIXTURE_DIR/identity.txt,sha256:$identity_hash,fixture-teacher,file://$FIXTURE_DIR/policy.txt,sha256:$policy_hash,file://$FIXTURE_DIR/license.txt,sha256:$license_hash,local-fixture-chain,0,1,1,1,1,1,1,0,0
CSV

V10_TEACHER_EXTERNAL_LABEL_CSV="$LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_teacher_external_label_source_verifier.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_teacher_external_label_source_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_teacher_external_label_source_verifier_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("external_label_source_ready teacher_external_labels_ready teacher_source_source external_label_rows label_teacher_rows label_provenance_hash_rows source_rows matched_teacher_rows source_artifact_rows source_hash_verified_rows label_export_rows label_export_hash_verified_rows teacher_identity_rows teacher_identity_hash_verified_rows teacher_policy_rows teacher_policy_hash_verified_rows license_rows license_hash_verified_rows provenance_basis_rows ready_rows local_fixture_uri_rows real_source_declared_rows non_fixture_declared_rows teacher_source_chain_verified real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher source import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (($idx["external_label_source_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 1 ||
        $idx["teacher_source_source"] != "provided-csv" ||
        ($idx["external_label_rows"] + 0) != 5 ||
        ($idx["label_teacher_rows"] + 0) != 1 ||
        ($idx["label_provenance_hash_rows"] + 0) != 5 ||
        ($idx["source_rows"] + 0) != 1 ||
        ($idx["matched_teacher_rows"] + 0) != 1 ||
        ($idx["source_artifact_rows"] + 0) != 1 ||
        ($idx["source_hash_verified_rows"] + 0) != 1 ||
        ($idx["label_export_rows"] + 0) != 1 ||
        ($idx["label_export_hash_verified_rows"] + 0) != 1 ||
        ($idx["teacher_identity_rows"] + 0) != 1 ||
        ($idx["teacher_identity_hash_verified_rows"] + 0) != 1 ||
        ($idx["teacher_policy_rows"] + 0) != 1 ||
        ($idx["teacher_policy_hash_verified_rows"] + 0) != 1 ||
        ($idx["license_rows"] + 0) != 1 ||
        ($idx["license_hash_verified_rows"] + 0) != 1 ||
        ($idx["provenance_basis_rows"] + 0) != 1 ||
        ($idx["ready_rows"] + 0) != 1 ||
        ($idx["local_fixture_uri_rows"] + 0) != 1 ||
        ($idx["real_source_declared_rows"] + 0) != 0 ||
        ($idx["non_fixture_declared_rows"] + 0) != 0 ||
        ($idx["teacher_source_chain_verified"] + 0) != 1 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["action"] != "teacher-real-source-review-missing") {
      die("supplied h10 teacher source fixture should verify mechanics but keep real source blocked", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 teacher source import", 4)
    }
  }
  END {
    if (rows != 1) die("expected one h10 teacher source import summary row", 5)
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
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "pass") die("external label ingestion should pass", 20)
    if ($idx["gate"] == "teacher-source-chain" && $idx["status"] != "pass") die("teacher source chain should pass", 21)
    if ($idx["gate"] == "real-teacher-source" && $idx["status"] != "blocked") die("real teacher source should block for local fixture", 22)
  }
  END {
    if (rows != 9) die("expected h10 teacher source import decision rows", 23)
  }
' "$DECISION_CSV"

cat >"$MISDECLARED_SOURCE_CSV" <<CSV
teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_model_family,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,provenance_basis,real_teacher_source_declared,fixture_or_synthetic_declared,source_artifact_ready,label_export_ready,teacher_identity_ready,teacher_policy_ready,license_ready,routing_trigger_rate,active_jump_rate
teacher-fixture-v1,file://$FIXTURE_DIR/source.txt,sha256:$source_hash,file://$LABEL_CSV,sha256:$label_export_hash,file://$FIXTURE_DIR/identity.txt,sha256:$identity_hash,fixture-teacher,file://$FIXTURE_DIR/policy.txt,sha256:$policy_hash,file://$FIXTURE_DIR/license.txt,sha256:$license_hash,local-fixture-chain,1,0,1,1,1,1,1,0,0
CSV

V10_TEACHER_EXTERNAL_LABEL_CSV="$LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$MISDECLARED_SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_teacher_external_label_source_verifier.sh" --smoke

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("local_fixture_uri_rows real_source_declared_rows non_fixture_declared_rows teacher_source_chain_verified real_teacher_source_verified action", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 misdeclared source summary column: " required[i], 30)
    }
    next
  }
  {
    rows++
    if (($idx["local_fixture_uri_rows"] + 0) != 1 ||
        ($idx["real_source_declared_rows"] + 0) != 1 ||
        ($idx["non_fixture_declared_rows"] + 0) != 1 ||
        ($idx["teacher_source_chain_verified"] + 0) != 1 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["action"] != "teacher-real-source-review-missing") {
      die("local fixture source must not become real teacher source by declaration flags", 31)
    }
  }
  END {
    if (rows != 1) die("expected one h10 misdeclared source summary row", 32)
  }
' "$SUMMARY_CSV"

V10_TEACHER_EXTERNAL_LABEL_CSV="$LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" --smoke

DISTILLATION_SUMMARY_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_summary.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("teacher_external_label_source_ready teacher_external_labels_ready teacher_source_chain_verified real_teacher_source_verified teacher_source_action distillation_ready default_promotion diagnostic_only status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 source import distillation column: " required[i], 40)
    }
    next
  }
  {
    rows++
    if (($idx["teacher_external_label_source_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 1 ||
        ($idx["teacher_source_chain_verified"] + 0) != 1 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["teacher_source_action"] != "teacher-real-source-review-missing" ||
        ($idx["distillation_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        ($idx["diagnostic_only"] + 0) != 1 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "teacher-real-external-label-source-missing") {
      die("h10 distillation should stay blocked until real teacher source is verified", 41)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 source import distillation", 42)
    }
  }
  END {
    if (rows != 1) die("expected one h10 source import distillation row", 43)
  }
' "$DISTILLATION_SUMMARY_CSV"

echo "v10 teacher external-label source import smoke passed"
