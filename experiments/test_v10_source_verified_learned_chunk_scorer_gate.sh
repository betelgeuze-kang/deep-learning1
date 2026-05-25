#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_fixture"
OUTSIDE_FIXTURE_DIR="/tmp/v10_source_verified_learned_chunk_scorer_outside_fixture"
LOCAL_LABELS_CSV="$RESULTS_DIR/v10_teacher_label_collection_harness_smoke_labels.csv"
FEATURE_LABELS_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_feature_labels.csv"
UNBOUND_FEATURE_LABELS_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_unbound_feature_labels.csv"
MALFORMED_FEATURE_LABELS_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_malformed_feature_labels.csv"
EXTERNAL_LABEL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_external_labels.csv"
MISMATCH_EXTERNAL_LABEL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_mismatch_external_labels.csv"
SOURCE_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_source.csv"
MISMATCH_SOURCE_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_mismatch_source.csv"
OUTSIDE_FEATURE_LABELS_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_outside_feature_labels.csv"
OUTSIDE_EXTERNAL_LABEL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_outside_external_labels.csv"
OUTSIDE_SOURCE_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_outside_source.csv"
CANONICAL_SCORER_SUMMARY_CSV="$RESULTS_DIR/v10_learned_chunk_quality_scorer_smoke_summary.csv"
SIDE_SCORER_SUMMARY_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_gate_smoke_scorer_summary.csv"

make_feature_labels() {
  local output_csv="$1"
  local teacher_id="$2"
  local source_uri="$3"
  local provenance_hash="$4"
  local include_binding="$5"

  awk -F, -v teacher_id="$teacher_id" -v source_uri="$source_uri" -v provenance_hash="$provenance_hash" -v include_binding="$include_binding" '
    BEGIN { OFS = "," }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!("label_source" in idx) || !("teacher_id" in idx)) {
        print "missing h10-l feature fixture columns" > "/dev/stderr"
        exit 20
      }
      if (include_binding == 1) {
        print $0, "source_uri", "provenance_hash"
      } else {
        print
      }
      next
    }
    {
      $(idx["label_source"]) = "provided-external-feature-csv"
      $(idx["teacher_id"]) = teacher_id
      if (include_binding == 1) {
        print $0, source_uri, provenance_hash
      } else {
        print
      }
    }
  ' "$LOCAL_LABELS_CSV" >"$output_csv"
}

make_external_labels() {
  local feature_csv="$1"
  local output_csv="$2"
  local mismatch_first="$3"

  awk -F, -v mismatch_first="$mismatch_first" '
    BEGIN {
      OFS = ","
      print "external_label_id,source_uri,teacher_id,query_key,candidate_key,teacher_label,expected_action,confidence,evidence_span_start,evidence_span_len,provenance_hash,license,routing_trigger_rate,active_jump_rate"
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("source_uri teacher_id query_key candidate_key teacher_label expected_action grounded_span_start grounded_span_len provenance_hash routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing h10-l bound external fixture column: " required[i] > "/dev/stderr"
          exit 30
        }
      }
      next
    }
    {
      rows++
      candidate_key = $idx["candidate_key"]
      if (mismatch_first == 1 && rows == 1) {
        candidate_key = candidate_key "-MISMATCH"
      }
      confidence = "0.900000"
      if ($idx["teacher_label"] == "correct") confidence = "0.990000"
      else if ($idx["teacher_label"] == "wrong") confidence = "0.940000"
      else if ($idx["teacher_label"] == "near-miss") confidence = "0.820000"
      else if ($idx["teacher_label"] == "missing-query") confidence = "0.910000"
      else if ($idx["teacher_label"] == "abstain") confidence = "0.760000"

      span_start = $idx["grounded_span_start"] + 0
      span_len = $idx["grounded_span_len"] + 0
      if (span_start < 0) span_start = 0
      if (span_len < 0) span_len = 0

      printf "ext-%03d,%s,%s,%s,%s,%s,%s,%s,%d,%d,%s,permissive,%s,%s\n",
        rows,
        $idx["source_uri"],
        $idx["teacher_id"],
        $idx["query_key"],
        candidate_key,
        $idx["teacher_label"],
        $idx["expected_action"],
        confidence,
        span_start,
        span_len,
        $idx["provenance_hash"],
        $idx["routing_trigger_rate"],
        $idx["active_jump_rate"]
    }
  ' "$feature_csv" >"$output_csv"
}

write_source_csv() {
  local output_csv="$1"
  local teacher_id="$2"
  local source_uri="$3"
  local source_hash="$4"
  local label_export_csv="$5"
  local identity_uri="$6"
  local identity_hash="$7"
  local policy_uri="$8"
  local policy_hash="$9"
  local license_uri="${10}"
  local license_hash="${11}"
  local model_family="${12}"
  local provenance_basis="${13}"
  local real_declared="${14}"
  local fixture_declared="${15}"
  local label_export_hash

  label_export_hash="$(sha256sum "$label_export_csv" | awk '{print $1}')"
  cat >"$output_csv" <<CSV
teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_model_family,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,provenance_basis,real_teacher_source_declared,fixture_or_synthetic_declared,source_artifact_ready,label_export_ready,teacher_identity_ready,teacher_policy_ready,license_ready,routing_trigger_rate,active_jump_rate
$teacher_id,$source_uri,$source_hash,file://$label_export_csv,sha256:$label_export_hash,$identity_uri,$identity_hash,$model_family,$policy_uri,$policy_hash,$license_uri,$license_hash,$provenance_basis,$real_declared,$fixture_declared,1,1,1,1,1,0,0
CSV
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
      if (!(field in idx)) die("missing summary column: " field, 60)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 61)
    }
    END {
      if (rows != 1) die("expected one summary row for " field, 62)
    }
  ' "$summary_csv"
}

"$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("feature_csv_provided feature_has_binding_fields feature_bound_rows matched_feature_label_rows external_label_rows feature_external_label_link_ready feature_label_source feature_source_link_ready learned_chunk_scorer_ready source_verified_feature_labels_ready source_verified_learned_chunk_scorer_ready default_promotion status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10-l default summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (($idx["feature_csv_provided"] + 0) != 0 ||
        ($idx["feature_has_binding_fields"] + 0) != 0 ||
        ($idx["feature_bound_rows"] + 0) != 0 ||
        ($idx["matched_feature_label_rows"] + 0) != 0 ||
        ($idx["external_label_rows"] + 0) != 0 ||
        ($idx["feature_external_label_link_ready"] + 0) != 0 ||
        $idx["feature_label_source"] != "local-teacher-harness" ||
        ($idx["feature_source_link_ready"] + 0) != 0 ||
        ($idx["learned_chunk_scorer_ready"] + 0) != 1 ||
        ($idx["source_verified_feature_labels_ready"] + 0) != 0 ||
        ($idx["source_verified_learned_chunk_scorer_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "source-verified-feature-labels-missing") {
      die("default h10-l should keep local scorer diagnostic-only and source-unverified", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for default h10-l", 4)
    }
  }
  END {
    if (rows != 1) die("expected one default h10-l summary row", 5)
  }
' "$SUMMARY_CSV"

"$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" --smoke >/dev/null
"$ROOT_DIR/experiments/run_v10_learned_chunk_quality_scorer.sh" --smoke >/dev/null
mkdir -p "$FIXTURE_DIR" "$OUTSIDE_FIXTURE_DIR"

printf 'teacher source fixture\n' >"$FIXTURE_DIR/source.txt"
printf 'teacher identity fixture\n' >"$FIXTURE_DIR/identity.txt"
printf 'teacher policy fixture\n' >"$FIXTURE_DIR/policy.txt"
printf 'teacher license fixture\n' >"$FIXTURE_DIR/license.txt"
printf 'outside teacher source fixture\n' >"$OUTSIDE_FIXTURE_DIR/source.txt"
printf 'outside teacher identity fixture\n' >"$OUTSIDE_FIXTURE_DIR/identity.txt"
printf 'outside teacher policy fixture\n' >"$OUTSIDE_FIXTURE_DIR/policy.txt"
printf 'outside teacher license fixture\n' >"$OUTSIDE_FIXTURE_DIR/license.txt"

source_hash="$(sha256sum "$FIXTURE_DIR/source.txt" | awk '{print $1}')"
identity_hash="$(sha256sum "$FIXTURE_DIR/identity.txt" | awk '{print $1}')"
policy_hash="$(sha256sum "$FIXTURE_DIR/policy.txt" | awk '{print $1}')"
license_hash="$(sha256sum "$FIXTURE_DIR/license.txt" | awk '{print $1}')"
outside_source_hash="$(sha256sum "$OUTSIDE_FIXTURE_DIR/source.txt" | awk '{print $1}')"
outside_identity_hash="$(sha256sum "$OUTSIDE_FIXTURE_DIR/identity.txt" | awk '{print $1}')"
outside_policy_hash="$(sha256sum "$OUTSIDE_FIXTURE_DIR/policy.txt" | awk '{print $1}')"
outside_license_hash="$(sha256sum "$OUTSIDE_FIXTURE_DIR/license.txt" | awk '{print $1}')"

make_feature_labels "$FEATURE_LABELS_CSV" "teacher-fixture-v1" "file://$FIXTURE_DIR/source.txt" "sha256:$source_hash" 1
make_feature_labels "$UNBOUND_FEATURE_LABELS_CSV" "teacher-fixture-v1" "file://$FIXTURE_DIR/source.txt" "sha256:$source_hash" 0
make_external_labels "$FEATURE_LABELS_CSV" "$EXTERNAL_LABEL_CSV" 0
make_external_labels "$FEATURE_LABELS_CSV" "$MISMATCH_EXTERNAL_LABEL_CSV" 1
write_source_csv "$SOURCE_CSV" "teacher-fixture-v1" "file://$FIXTURE_DIR/source.txt" "sha256:$source_hash" "$EXTERNAL_LABEL_CSV" "file://$FIXTURE_DIR/identity.txt" "sha256:$identity_hash" "file://$FIXTURE_DIR/policy.txt" "sha256:$policy_hash" "file://$FIXTURE_DIR/license.txt" "sha256:$license_hash" "fixture-teacher" "local-fixture-chain" 0 1
write_source_csv "$MISMATCH_SOURCE_CSV" "teacher-fixture-v1" "file://$FIXTURE_DIR/source.txt" "sha256:$source_hash" "$MISMATCH_EXTERNAL_LABEL_CSV" "file://$FIXTURE_DIR/identity.txt" "sha256:$identity_hash" "file://$FIXTURE_DIR/policy.txt" "sha256:$policy_hash" "file://$FIXTURE_DIR/license.txt" "sha256:$license_hash" "fixture-teacher" "local-fixture-chain" 0 1

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" --smoke

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("feature_csv_provided feature_rows feature_teacher_rows matched_feature_teacher_rows feature_has_binding_fields feature_bound_rows matched_feature_label_rows external_label_rows feature_external_label_link_ready feature_label_source feature_source_link_ready learned_chunk_scorer_ready source_verified_feature_labels_ready external_label_source_ready teacher_external_labels_ready teacher_source_chain_verified real_teacher_source_verified source_verified_learned_chunk_scorer_ready status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10-l fixture summary column: " required[i], 30)
    }
    next
  }
  {
    rows++
    if (($idx["feature_csv_provided"] + 0) != 1 ||
        ($idx["feature_rows"] + 0) != 6 ||
        ($idx["feature_teacher_rows"] + 0) != 1 ||
        ($idx["matched_feature_teacher_rows"] + 0) != 1 ||
        ($idx["feature_has_binding_fields"] + 0) != 1 ||
        ($idx["feature_bound_rows"] + 0) != 6 ||
        ($idx["matched_feature_label_rows"] + 0) != 6 ||
        ($idx["external_label_rows"] + 0) != 6 ||
        ($idx["feature_external_label_link_ready"] + 0) != 1 ||
        $idx["feature_label_source"] != "provided-external-feature-csv" ||
        ($idx["feature_source_link_ready"] + 0) != 1 ||
        ($idx["learned_chunk_scorer_ready"] + 0) != 1 ||
        ($idx["source_verified_feature_labels_ready"] + 0) != 1 ||
        ($idx["external_label_source_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 1 ||
        ($idx["teacher_source_chain_verified"] + 0) != 1 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        ($idx["source_verified_learned_chunk_scorer_ready"] + 0) != 0 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "teacher-real-external-label-source-missing") {
      die("h10-l fixture should row-bind feature labels but block before real source", 31)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for fixture h10-l", 32)
    }
  }
  END {
    if (rows != 1) die("expected one h10-l fixture summary row", 33)
  }
' "$SUMMARY_CSV"

expect_summary_value "$CANONICAL_SCORER_SUMMARY_CSV" "label_source" "local-teacher-harness" "canonical h10-k scorer summary should not be overwritten by h10-l"
expect_summary_value "$SIDE_SCORER_SUMMARY_CSV" "label_source" "provided-external-feature-csv" "h10-l side scorer should use supplied feature labels"

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
    if ($idx["gate"] == "learned-chunk-scorer" && $idx["status"] != "pass") die("learned scorer should pass", 40)
    if ($idx["gate"] == "source-feature-link" && $idx["status"] != "pass") die("feature link should pass for row-bound fixture", 41)
    if ($idx["gate"] == "teacher-source-chain" && $idx["status"] != "pass") die("source chain should pass for fixture", 42)
    if ($idx["gate"] == "real-teacher-source" && $idx["status"] != "blocked") die("real source should block for fixture", 43)
    if ($idx["gate"] == "source-verified-learned-scorer" && $idx["status"] != "blocked") die("source verified scorer should block for fixture", 44)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("default promotion should stay blocked", 45)
  }
  END {
    if (rows != 6) die("expected h10-l decision rows", 46)
  }
' "$DECISION_CSV"

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$UNBOUND_FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "feature_has_binding_fields" "0" "unbound relabeled feature rows should not expose binding fields"
expect_summary_value "$SUMMARY_CSV" "feature_external_label_link_ready" "0" "unbound relabeled feature rows should not link to external labels"
expect_summary_value "$SUMMARY_CSV" "feature_source_link_ready" "0" "unbound relabeled feature rows should not pass source link"
expect_summary_value "$SUMMARY_CSV" "source_verified_feature_labels_ready" "0" "unbound relabeled feature rows should not become source verified"
expect_summary_value "$SUMMARY_CSV" "reason" "source-verified-feature-labels-missing" "unbound relabeled feature rows should keep source-verified feature blocker"

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$MISMATCH_EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$MISMATCH_SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "feature_has_binding_fields" "1" "mismatch fixture should expose binding fields"
expect_summary_value "$SUMMARY_CSV" "matched_feature_label_rows" "5" "mismatch fixture should lose exactly one row-level match"
expect_summary_value "$SUMMARY_CSV" "feature_external_label_link_ready" "0" "mismatch fixture should block row-level external label binding"
expect_summary_value "$SUMMARY_CSV" "feature_source_link_ready" "0" "mismatch fixture should block source feature link"
expect_summary_value "$SUMMARY_CSV" "source_verified_feature_labels_ready" "0" "mismatch fixture should not become source verified"

{
  head -n 1 "$FEATURE_LABELS_CSV"
  sed -n '2p' "$FEATURE_LABELS_CSV"
  sed -n '3p' "$FEATURE_LABELS_CSV"
  sed -n '4p' "$FEATURE_LABELS_CSV"
  sed -n '5p' "$FEATURE_LABELS_CSV"
  sed -n '6p' "$FEATURE_LABELS_CSV"
  printf '%s,extra-field\n' "$(sed -n '7p' "$FEATURE_LABELS_CSV")"
} >"$MALFORMED_FEATURE_LABELS_CSV"

if V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$MALFORMED_FEATURE_LABELS_CSV" \
   V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
   V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
     "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h10-l should reject malformed feature-label CSV row widths" >&2
  exit 70
fi

make_feature_labels "$OUTSIDE_FEATURE_LABELS_CSV" "teacher-outside-local-v1" "file://$OUTSIDE_FIXTURE_DIR/source.txt" "sha256:$outside_source_hash" 1
make_external_labels "$OUTSIDE_FEATURE_LABELS_CSV" "$OUTSIDE_EXTERNAL_LABEL_CSV" 0
write_source_csv "$OUTSIDE_SOURCE_CSV" "teacher-outside-local-v1" "file://$OUTSIDE_FIXTURE_DIR/source.txt" "sha256:$outside_source_hash" "$OUTSIDE_EXTERNAL_LABEL_CSV" "file://$OUTSIDE_FIXTURE_DIR/identity.txt" "sha256:$outside_identity_hash" "file://$OUTSIDE_FIXTURE_DIR/policy.txt" "sha256:$outside_policy_hash" "file://$OUTSIDE_FIXTURE_DIR/license.txt" "sha256:$outside_license_hash" "claimed-real-file-teacher" "outside-local-file-chain" 1 0

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$OUTSIDE_FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$OUTSIDE_EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$OUTSIDE_SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "feature_source_link_ready" "1" "outside local fixture should still exercise feature/source mechanics"
expect_summary_value "$SUMMARY_CSV" "teacher_source_chain_verified" "1" "outside local fixture should verify hash-chain mechanics"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "outside local file URI must not become real source evidence"
expect_summary_value "$SUMMARY_CSV" "teacher_source_action" "teacher-real-source-review-missing" "outside local file URI should require real source review"
expect_summary_value "$SUMMARY_CSV" "source_verified_learned_chunk_scorer_ready" "0" "outside local fixture should not unlock source-verified scorer"
expect_summary_value "$SUMMARY_CSV" "reason" "teacher-real-external-label-source-missing" "outside local fixture should keep real-source blocker"

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
  "$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" --smoke >/dev/null

DISTILLATION_SUMMARY_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_summary.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("source_verified_feature_labels_ready source_verified_learned_chunk_scorer_ready real_teacher_source_verified distillation_ready default_promotion status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10-l distillation summary column: " required[i], 80)
    }
    next
  }
  {
    rows++
    if (($idx["source_verified_feature_labels_ready"] + 0) != 1 ||
        ($idx["source_verified_learned_chunk_scorer_ready"] + 0) != 0 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        ($idx["distillation_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "teacher-real-external-label-source-missing") {
      die("distillation gate should require source-verified learned chunk scorer", 81)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10-l distillation", 82)
    }
  }
  END {
    if (rows != 1) die("expected one h10-l distillation summary row", 83)
  }
' "$DISTILLATION_SUMMARY_CSV"

echo "v10 source-verified learned chunk scorer gate smoke passed"
