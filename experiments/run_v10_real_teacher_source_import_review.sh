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

PREFIX="v10_real_teacher_source_import_review"
LIVE_IMPORT_PREFIX="v10_remote_teacher_source_live_network_import_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_real_teacher_source_import_review_smoke"
  LIVE_IMPORT_PREFIX="v10_remote_teacher_source_live_network_import_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_network_import_gate.sh" "${RUN_ARGS[@]}" >/dev/null

LIVE_IMPORT_SUMMARY_CSV="$RESULTS_DIR/${LIVE_IMPORT_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EMPTY_ACQUISITION_CSV="$RESULTS_DIR/${PREFIX}_expected_acquisition.csv"

REVIEW_CSV="$RESULTS_DIR/${PREFIX}_review.csv"
REVIEW_SOURCE="pending-fixture"
if [[ -n "${V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV:-}" ]]; then
  REVIEW_CSV="$V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV"
  REVIEW_SOURCE="provided-csv"
  if [[ ! -s "$REVIEW_CSV" ]]; then
    echo "V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  {
    echo "teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,import_manifest_uri,import_manifest_hash,review_report_uri,review_report_hash,reviewer_identity_uri,reviewer_identity_hash,conflict_disclosure_uri,conflict_disclosure_hash,source_registry_uri,source_registry_hash,source_import_id,live_network_import_observed,independent_review_ready,authoritative_review_ready,registry_entry_ready,real_source_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  } >"$REVIEW_CSV"
fi

if [[ -n "${V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV:-}" ]]; then
  ACQUISITION_CSV="$V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV"
else
  echo "teacher_id,source_uri" >"$EMPTY_ACQUISITION_CSV"
  ACQUISITION_CSV="$EMPTY_ACQUISITION_CSV"
fi

LIVE_IMPORT_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("runtime_fetch_source action remote_teacher_source_live_network_import_ready real_teacher_source_verified routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-r live import summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%s,%s,%d,%d,%.6f,%.6f\n",
        $idx["runtime_fetch_source"],
        $idx["action"],
        $idx["remote_teacher_source_live_network_import_ready"] + 0,
        $idx["real_teacher_source_verified"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h10-r live import summary row", 3)
    }
  ' "$LIVE_IMPORT_SUMMARY_CSV"
)"

IFS=, read -r runtime_fetch_source h10q_action live_network_import_ready h10q_real_verified live_import_routing live_import_jump <<<"$LIVE_IMPORT_VALUES"

awk -F, \
  -v acquisition_csv="$ACQUISITION_CSV" \
  -v review_csv="$REVIEW_CSV" \
  -v review_source="$REVIEW_SOURCE" \
  -v runtime_fetch_source="$runtime_fetch_source" \
  -v h10q_action="$h10q_action" \
  -v live_network_import_ready="$live_network_import_ready" \
  -v live_import_routing="$live_import_routing" \
  -v live_import_jump="$live_import_jump" \
  -v summary_csv="$SUMMARY_CSV" \
  -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function is_present(value) {
    return value != "" && value != "pending"
  }
  function is_sha256(value,   hex) {
    if (value !~ /^sha256:/) return 0
    hex = substr(value, 8)
    return length(hex) == 64 && hex !~ /[^0-9a-fA-F]/
  }
  function is_placeholder_uri(uri,   lowered) {
    lowered = tolower(uri)
    if (lowered ~ /(^|[.:\/])example\.invalid([:\/]|$)/) return 1
    if (lowered ~ /(^|[.:\/])teacher-source\.invalid([:\/]|$)/) return 1
    if (lowered ~ /(^|[.:\/])invalid([:\/]|$)/) return 1
    if (lowered ~ /^https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])([:\/]|$)/) return 1
    if (lowered ~ /^(fixture|local|external):\/\//) return 1
    return 0
  }
  function uri_class(uri,   lowered) {
    lowered = tolower(uri)
    if (!is_present(uri)) return "missing"
    if (lowered ~ /^file:\/\//) return "local"
    if (lowered ~ /^https:\/\//) return "remote"
    if (lowered ~ /^http:\/\//) return "insecure"
    return "placeholder"
  }
  function count_uri(uri,   cls) {
    cls = uri_class(uri)
    required_review_uri_fields++
    if (cls == "remote") remote_review_uri_fields++
    else if (cls == "local") local_review_uri_fields++
    else if (cls == "insecure") insecure_review_uri_fields++
    else if (cls == "missing") missing_review_uri_fields++
    else placeholder_review_uri_fields++
    if (is_placeholder_uri(uri)) placeholder_review_uri_fields++
    return cls
  }
  function count_hash(value) {
    required_review_hash_fields++
    if (is_sha256(value)) sha256_review_hash_fields++
  }
  FILENAME == acquisition_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) aidx[$i] = i
    if (!("teacher_id" in aidx) || !("source_uri" in aidx)) {
      die("missing h10-r acquisition binding column", 4)
    }
    next
  }
  FILENAME == acquisition_csv {
    expected_source_by_teacher[$aidx["teacher_id"]] = $aidx["source_uri"]
    expected_teacher_rows++
    next
  }
  FILENAME == review_csv && FNR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) ridx[$i] = i
    required_count = split("teacher_id source_uri source_hash label_export_uri label_export_hash teacher_identity_uri teacher_identity_hash teacher_policy_uri teacher_policy_hash license_uri license_hash import_manifest_uri import_manifest_hash review_report_uri review_report_hash reviewer_identity_uri reviewer_identity_hash conflict_disclosure_uri conflict_disclosure_hash source_registry_uri source_registry_hash source_import_id live_network_import_observed independent_review_ready authoritative_review_ready registry_entry_ready real_source_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in ridx)) die("missing h10-r review column: " required[i], 5)
    }
    next
  }
  FILENAME == review_csv {
    if (NF != header_fields) die("h10-r review row has wrong column count", 6)
    review_rows++
    teacher_id = $ridx["teacher_id"]
    source_uri = $ridx["source_uri"]

    if (is_present(teacher_id) &&
        is_present(source_uri) &&
        (teacher_id in expected_source_by_teacher) &&
        expected_source_by_teacher[teacher_id] == source_uri) {
      matched_teacher_rows++
    }

    count_uri($ridx["source_uri"])
    count_uri($ridx["label_export_uri"])
    count_uri($ridx["teacher_identity_uri"])
    count_uri($ridx["teacher_policy_uri"])
    count_uri($ridx["license_uri"])
    count_uri($ridx["import_manifest_uri"])
    count_uri($ridx["review_report_uri"])
    count_uri($ridx["reviewer_identity_uri"])
    count_uri($ridx["conflict_disclosure_uri"])
    count_uri($ridx["source_registry_uri"])

    count_hash($ridx["source_hash"])
    count_hash($ridx["label_export_hash"])
    count_hash($ridx["teacher_identity_hash"])
    count_hash($ridx["teacher_policy_hash"])
    count_hash($ridx["license_hash"])
    count_hash($ridx["import_manifest_hash"])
    count_hash($ridx["review_report_hash"])
    count_hash($ridx["reviewer_identity_hash"])
    count_hash($ridx["conflict_disclosure_hash"])
    count_hash($ridx["source_registry_hash"])

    if (is_present($ridx["import_manifest_uri"]) && is_sha256($ridx["import_manifest_hash"])) import_manifest_rows++
    if (is_present($ridx["review_report_uri"]) && is_sha256($ridx["review_report_hash"])) review_report_rows++
    if (is_present($ridx["reviewer_identity_uri"]) && is_sha256($ridx["reviewer_identity_hash"])) reviewer_identity_rows++
    if (is_present($ridx["conflict_disclosure_uri"]) && is_sha256($ridx["conflict_disclosure_hash"])) conflict_disclosure_rows++
    if (is_present($ridx["source_registry_uri"]) && is_sha256($ridx["source_registry_hash"])) source_registry_rows++
    if (($ridx["live_network_import_observed"] + 0) == 1) live_network_import_observed_rows++
    if (($ridx["independent_review_ready"] + 0) == 1) independent_review_ready_rows++
    if (($ridx["authoritative_review_ready"] + 0) == 1) authoritative_review_ready_rows++
    if (($ridx["registry_entry_ready"] + 0) == 1) registry_entry_ready_rows++
    if (($ridx["real_source_declared"] + 0) == 1) declared_real_rows++
    if (($ridx["fixture_or_synthetic_declared"] + 0) == 0) non_fixture_declared_rows++
    review_routing += $ridx["routing_trigger_rate"] + 0
    review_jump += $ridx["active_jump_rate"] + 0
    next
  }
  END {
    total_routing = live_import_routing + review_routing
    total_jump = live_import_jump + review_jump

    review_artifacts_complete = 0
    if (review_rows > 0 &&
        matched_teacher_rows == review_rows &&
        import_manifest_rows == review_rows &&
        review_report_rows == review_rows &&
        reviewer_identity_rows == review_rows &&
        conflict_disclosure_rows == review_rows &&
        source_registry_rows == review_rows &&
        live_network_import_observed_rows == review_rows &&
        independent_review_ready_rows == review_rows &&
        authoritative_review_ready_rows == review_rows &&
        registry_entry_ready_rows == review_rows &&
        declared_real_rows == review_rows &&
        non_fixture_declared_rows == review_rows) {
      review_artifacts_complete = 1
    }

    review_uri_scheme_ready = 0
    if (review_rows > 0 &&
        required_review_uri_fields > 0 &&
        remote_review_uri_fields == required_review_uri_fields &&
        local_review_uri_fields == 0 &&
        insecure_review_uri_fields == 0 &&
        missing_review_uri_fields == 0) {
      review_uri_scheme_ready = 1
    }

    review_hash_manifest_ready = 0
    if (review_rows > 0 &&
        required_review_hash_fields > 0 &&
        sha256_review_hash_fields == required_review_hash_fields) {
      review_hash_manifest_ready = 1
    }

    teacher_source_import_review_contract_ready = 0
    if (live_network_import_ready &&
        review_artifacts_complete &&
        review_uri_scheme_ready &&
        review_hash_manifest_ready &&
        total_routing == 0.0 &&
        total_jump == 0.0) {
      teacher_source_import_review_contract_ready = 1
    }

    real_teacher_source_import_review_ready = 0
    if (teacher_source_import_review_contract_ready &&
        placeholder_review_uri_fields == 0) {
      real_teacher_source_import_review_ready = 1
    }

    real_teacher_source_verified = 0
    action = "real-teacher-source-live-network-import-missing"
    if (live_network_import_ready) {
      if (review_rows == 0) {
        action = "real-teacher-source-import-review-missing"
      } else if (matched_teacher_rows != review_rows) {
        action = "real-teacher-source-import-review-teacher-mismatch"
      } else if (local_review_uri_fields > 0) {
        action = "real-teacher-source-local-import-artifact"
      } else if (remote_review_uri_fields != required_review_uri_fields ||
                 insecure_review_uri_fields > 0 ||
                 missing_review_uri_fields > 0) {
        action = "real-teacher-source-import-review-uri-mismatch"
      } else if (!review_hash_manifest_ready) {
        action = "real-teacher-source-import-review-hash-mismatch"
      } else if (!review_artifacts_complete) {
        action = "real-teacher-source-import-review-incomplete"
      } else if (placeholder_review_uri_fields > 0) {
        action = "real-teacher-source-placeholder-import-artifact"
      } else if (real_teacher_source_import_review_ready) {
        action = "real-teacher-source-official-authority-missing"
      }
    }

    print "teacher_source_real_import_scope,review_source,runtime_fetch_source,h10q_action,remote_teacher_source_live_network_import_ready,review_rows,matched_teacher_rows,expected_teacher_rows,required_review_uri_fields,remote_review_uri_fields,local_review_uri_fields,placeholder_review_uri_fields,insecure_review_uri_fields,missing_review_uri_fields,required_review_hash_fields,sha256_review_hash_fields,import_manifest_rows,review_report_rows,reviewer_identity_rows,conflict_disclosure_rows,source_registry_rows,live_network_import_observed_rows,independent_review_ready_rows,authoritative_review_ready_rows,registry_entry_ready_rows,declared_real_rows,non_fixture_declared_rows,teacher_source_import_review_contract_ready,real_teacher_source_import_review_ready,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-h10r,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      review_source,
      runtime_fetch_source,
      h10q_action,
      live_network_import_ready,
      review_rows,
      matched_teacher_rows,
      expected_teacher_rows,
      required_review_uri_fields,
      remote_review_uri_fields,
      local_review_uri_fields,
      placeholder_review_uri_fields,
      insecure_review_uri_fields,
      missing_review_uri_fields,
      required_review_hash_fields,
      sha256_review_hash_fields,
      import_manifest_rows,
      review_report_rows,
      reviewer_identity_rows,
      conflict_disclosure_rows,
      source_registry_rows,
      live_network_import_observed_rows,
      independent_review_ready_rows,
      authoritative_review_ready_rows,
      registry_entry_ready_rows,
      declared_real_rows,
      non_fixture_declared_rows,
      teacher_source_import_review_contract_ready,
      real_teacher_source_import_review_ready,
      real_teacher_source_verified,
      action,
      total_routing,
      total_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "live-network-import,%s,ready=%d h10q_action=%s\n",
      (live_network_import_ready ? "pass" : "blocked"),
      live_network_import_ready,
      h10q_action >> decision_csv
    printf "import-review-artifacts,%s,rows=%d matched=%d manifest=%d review=%d registry=%d\n",
      (review_artifacts_complete ? "pass" : "blocked"),
      review_rows,
      matched_teacher_rows,
      import_manifest_rows,
      review_report_rows,
      source_registry_rows >> decision_csv
    printf "review-uri-scheme,%s,remote=%d/%d local=%d placeholder=%d insecure=%d missing=%d\n",
      (review_uri_scheme_ready ? "pass" : "blocked"),
      remote_review_uri_fields,
      required_review_uri_fields,
      local_review_uri_fields,
      placeholder_review_uri_fields,
      insecure_review_uri_fields,
      missing_review_uri_fields >> decision_csv
    printf "review-hashes,%s,sha256=%d/%d\n",
      (review_hash_manifest_ready ? "pass" : "blocked"),
      sha256_review_hash_fields,
      required_review_hash_fields >> decision_csv
    printf "import-review-contract,%s,contract_ready=%d action=%s\n",
      (teacher_source_import_review_contract_ready ? "pass" : "blocked"),
      teacher_source_import_review_contract_ready,
      action >> decision_csv
    printf "real-teacher-source-import-review,%s,real_review_ready=%d placeholders=%d\n",
      (real_teacher_source_import_review_ready ? "pass" : "blocked"),
      real_teacher_source_import_review_ready,
      placeholder_review_uri_fields >> decision_csv
    printf "real-teacher-source-verification,%s,real_verified=%d action=%s\n",
      (real_teacher_source_verified ? "pass" : "blocked"),
      real_teacher_source_verified,
      action >> decision_csv
    printf "jump-guardrail,%s,routing=%.6f jump=%.6f\n",
      ((total_routing == 0.0 && total_jump == 0.0) ? "pass" : "blocked"),
      total_routing,
      total_jump >> decision_csv
  }
' "$ACQUISITION_CSV" "$REVIEW_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
