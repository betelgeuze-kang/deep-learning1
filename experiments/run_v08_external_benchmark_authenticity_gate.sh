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

PREFIX="v08_external_benchmark_authenticity_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
ARTIFACT_PREFIX="v08_external_benchmark_artifact_verifier"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_authenticity_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  ARTIFACT_PREFIX="v08_external_benchmark_artifact_verifier_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_artifact_verifier.sh" "${RUN_ARGS[@]}" >/dev/null

EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi

AUTHENTICITY_CSV="$RESULTS_DIR/${PREFIX}_authenticity.csv"
AUTHENTICITY_SOURCE="pending-fixture"
if [[ -n "${V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV:-}" ]]; then
  AUTHENTICITY_CSV="$V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV"
  AUTHENTICITY_SOURCE="provided-csv"
  if [[ ! -s "$AUTHENTICITY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  awk -F, -v out="$AUTHENTICITY_CSV" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!("benchmark_family" in idx)) {
        print "missing benchmark_family in v08 authenticity pending fixture" > "/dev/stderr"
        exit 2
      }
      print "benchmark_family,benchmark_id,benchmark_version,canonical_dataset_uri,canonical_result_uri,evaluator_name,evaluator_version,evaluator_hash,metric_name,metric_direction,metric_scale,authenticity_ready,evaluator_ready,metric_ready,routing_trigger_rate,active_jump_rate" > out
      next
    }
    {
      printf "%s,pending,pending,pending,pending,pending,pending,pending,pending,pending,pending,0,0,0,0,0\n", $idx["benchmark_family"] >> out
    }
  ' "$EVIDENCE_CSV"
fi

ARTIFACT_SUMMARY_CSV="$RESULTS_DIR/${ARTIFACT_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v artifact_csv="$ARTIFACT_SUMMARY_CSV" -v evidence_csv="$EVIDENCE_CSV" \
  -v authenticity_csv="$AUTHENTICITY_CSV" -v authenticity_source="$AUTHENTICITY_SOURCE" \
  -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function is_present(value) {
    return value != "" && value != "pending"
  }
  function is_sha256(value, hex) {
    if (substr(value, 1, 7) != "sha256:") return 0
    hex = substr(value, 8)
    return length(hex) == 64 && hex !~ /[^0-9a-fA-F]/
  }
  FILENAME == artifact_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) aridx[$i] = i
    required_count = split("benchmark_families evidence_source artifact_verifier_ready real_external_benchmark_verified routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in aridx)) die("missing v08 authenticity artifact summary column: " required[i], 2)
    }
    next
  }
  FILENAME == artifact_csv {
    artifact_rows++
    benchmark_families = $aridx["benchmark_families"] + 0
    evidence_source = $aridx["evidence_source"]
    artifact_verifier_ready = $aridx["artifact_verifier_ready"] + 0
    prior_real_external_benchmark_verified = $aridx["real_external_benchmark_verified"] + 0
    artifact_routing = $aridx["routing_trigger_rate"] + 0
    artifact_jump = $aridx["active_jump_rate"] + 0
    next
  }
  FILENAME == evidence_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) eidx[$i] = i
    required_count = split("benchmark_family dataset_uri result_uri routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in eidx)) die("missing v08 authenticity evidence column: " required[i], 3)
    }
    next
  }
  FILENAME == evidence_csv {
    evidence_rows++
    family = $eidx["benchmark_family"]
    dataset_uri[family] = $eidx["dataset_uri"]
    result_uri[family] = $eidx["result_uri"]
    evidence_family_seen[family] = 1
    evidence_routing += $eidx["routing_trigger_rate"] + 0
    evidence_jump += $eidx["active_jump_rate"] + 0
    next
  }
  FILENAME == authenticity_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) auidx[$i] = i
    required_count = split("benchmark_family benchmark_id benchmark_version canonical_dataset_uri canonical_result_uri evaluator_name evaluator_version evaluator_hash metric_name metric_direction metric_scale authenticity_ready evaluator_ready metric_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in auidx)) die("missing v08 authenticity column: " required[i], 4)
    }
    next
  }
  FILENAME == authenticity_csv {
    authenticity_rows++
    family = $auidx["benchmark_family"]
    if (family in authenticity_seen) die("duplicate v08 authenticity family: " family, 5)
    authenticity_seen[family] = 1
    if (family in evidence_family_seen) matched_family_rows++
    if ($auidx["canonical_dataset_uri"] == dataset_uri[family] &&
        $auidx["canonical_result_uri"] == result_uri[family] &&
        is_present($auidx["canonical_dataset_uri"]) &&
        is_present($auidx["canonical_result_uri"])) {
      canonical_uri_match_rows++
    }
    if (($auidx["authenticity_ready"] + 0) == 1 &&
        is_present($auidx["benchmark_id"]) &&
        is_present($auidx["benchmark_version"])) {
      authenticity_ready_rows++
    }
    if (($auidx["evaluator_ready"] + 0) == 1 &&
        is_present($auidx["evaluator_name"]) &&
        is_present($auidx["evaluator_version"]) &&
        is_sha256($auidx["evaluator_hash"])) {
      evaluator_ready_rows++
      evaluator_hash_rows++
    }
    if (($auidx["metric_ready"] + 0) == 1 &&
        is_present($auidx["metric_name"]) &&
        ($auidx["metric_direction"] == "higher-is-better" || $auidx["metric_direction"] == "lower-is-better") &&
        is_present($auidx["metric_scale"])) {
      metric_ready_rows++
    }
    authenticity_routing += $auidx["routing_trigger_rate"] + 0
    authenticity_jump += $auidx["active_jump_rate"] + 0
    next
  }
  END {
    if (artifact_rows != 1) die("expected one v08 authenticity artifact summary row", 6)
    if (evidence_rows != 4) die("expected four v08 authenticity evidence rows", 7)
    if (authenticity_rows != 4) die("expected four v08 authenticity rows", 8)

    benchmark_authenticity_ready = 0
    if (artifact_verifier_ready == 1 &&
        matched_family_rows == benchmark_families &&
        canonical_uri_match_rows == benchmark_families &&
        authenticity_ready_rows == benchmark_families &&
        evidence_routing == 0.0 &&
        evidence_jump == 0.0 &&
        authenticity_routing == 0.0 &&
        authenticity_jump == 0.0) {
      benchmark_authenticity_ready = 1
    }

    evaluator_contract_ready = 0
    if (evaluator_ready_rows == benchmark_families &&
        metric_ready_rows == benchmark_families &&
        evaluator_hash_rows == benchmark_families) {
      evaluator_contract_ready = 1
    }

    benchmark_authenticity_verified = 0
    if (benchmark_authenticity_ready == 1 && evaluator_contract_ready == 1) {
      benchmark_authenticity_verified = 1
    }

    real_external_benchmark_verified = 0
    action = "artifact-verifier-missing"
    if (artifact_verifier_ready == 1 && benchmark_authenticity_ready == 0) {
      action = "benchmark-authenticity-evidence-missing"
    } else if (benchmark_authenticity_ready == 1 && evaluator_contract_ready == 0) {
      action = "benchmark-evaluator-evidence-missing"
    } else if (benchmark_authenticity_verified == 1) {
      action = "external-benchmark-execution-missing"
    }

    print "benchmark_scope,benchmark_families,evidence_source,authenticity_source,artifact_verifier_ready,authenticity_rows,matched_family_rows,canonical_uri_match_rows,authenticity_ready_rows,evaluator_ready_rows,evaluator_hash_rows,metric_ready_rows,benchmark_authenticity_ready,evaluator_contract_ready,benchmark_authenticity_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08h,%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      benchmark_families,
      evidence_source,
      authenticity_source,
      artifact_verifier_ready,
      authenticity_rows,
      matched_family_rows,
      canonical_uri_match_rows,
      authenticity_ready_rows,
      evaluator_ready_rows,
      evaluator_hash_rows,
      metric_ready_rows,
      benchmark_authenticity_ready,
      evaluator_contract_ready,
      benchmark_authenticity_verified,
      real_external_benchmark_verified,
      action,
      artifact_routing + evidence_routing + authenticity_routing,
      artifact_jump + evidence_jump + authenticity_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "artifact-verifier,%s,artifact_verifier_ready=%d\n",
      artifact_verifier_ready ? "pass" : "blocked",
      artifact_verifier_ready >> decision_csv
    printf "canonical-uri-match,%s,matched_rows=%d\n",
      canonical_uri_match_rows == benchmark_families ? "pass" : "blocked",
      canonical_uri_match_rows >> decision_csv
    printf "benchmark-authenticity,%s,authenticity_ready_rows=%d\n",
      benchmark_authenticity_ready ? "pass" : "blocked",
      authenticity_ready_rows >> decision_csv
    printf "evaluator-contract,%s,evaluator_rows=%d metric_rows=%d\n",
      evaluator_contract_ready ? "pass" : "blocked",
      evaluator_ready_rows,
      metric_ready_rows >> decision_csv
    printf "authenticity-verified,%s,verified=%d\n",
      benchmark_authenticity_verified ? "pass" : "blocked",
      benchmark_authenticity_verified >> decision_csv
    printf "real-external-benchmark,%s,action=%s\n",
      real_external_benchmark_verified ? "ready" : "blocked",
      action >> decision_csv
  }
' "$ARTIFACT_SUMMARY_CSV" "$EVIDENCE_CSV" "$AUTHENTICITY_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
