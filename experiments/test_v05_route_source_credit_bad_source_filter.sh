#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_bad_source_filter_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_bad_source_filter.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 6 }
  NR == 1 {
    split("scenario arm fallback_source source_filter_mode key_count seed qacc fallback_recall fallback_qacc source_gap noisy_mean noisy_slashed noisy_selected selected_fallback strength_mean source_filter_filtered source_filter_abstain lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    scenario = $idx["scenario"]
    arm = $idx["arm"]
    source = $idx["fallback_source"]
    filter_mode = $idx["source_filter_mode"]
    key_count = metric("key_count")
    seed = metric("seed")
    qacc = metric("qacc")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    source_gap = metric("source_gap")
    noisy_mean = metric("noisy_mean")
    noisy_slashed = metric("noisy_slashed")
    noisy_selected = metric("noisy_selected")
    selected_fallback = metric("selected_fallback")
    strength_mean = metric("strength_mean")
    filtered = metric("source_filter_filtered")
    abstain = metric("source_filter_abstain")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (key_count != 128 || seed != 1) {
      die("smoke should run key_count=128 seed=1: " scenario, 3)
    }
    if (qacc < 0 || qacc > 1 || fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 || noisy_slashed < 0 ||
        noisy_slashed > 1 || noisy_selected < 0 || noisy_selected > 1 ||
        selected_fallback < 0 || selected_fallback > 1 || filtered < 0 ||
        filtered > 1 || abstain < 0 || abstain > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("bad-source filtering must not activate jump-neighbor routing: " scenario, 6)
    }

    rows++
    if (arm == "raw-filter") {
      raw_seen = 1
      if (source != "raw-key" || filter_mode != "negative-credit") {
        die("raw-filter configuration mismatch: " scenario, 7)
      }
      raw_qacc = qacc
      raw_filtered = filtered
      if (source_gap <= 0 || fallback_recall <= 0 || qacc < 0.85) {
        die("raw symbolic fallback should remain usable under filter: " scenario, 8)
      }
    } else if (arm == "keyshape-filter") {
      shape_seen = 1
      if (source != "key-shape" || filter_mode != "negative-credit") {
        die("keyshape-filter configuration mismatch: " scenario, 9)
      }
      shape_qacc = qacc
      shape_filtered = filtered
      if (source_gap <= 0 || fallback_recall <= 0 || qacc < 0.85) {
        die("key-shape symbolic fallback should remain usable under filter: " scenario, 10)
      }
    } else if (arm == "noisy-unfiltered") {
      noisy_unfiltered_seen = 1
      if (source != "noisy-route-code" || filter_mode != "off") {
        die("noisy-unfiltered configuration mismatch: " scenario, 11)
      }
      noisy_unfiltered_qacc = qacc
      noisy_unfiltered_filtered = filtered
      if (source_gap >= 0 || noisy_mean >= 0 || noisy_slashed <= 0 ||
          fallback_recall != 0) {
        die("unfiltered noisy fallback should be detected as bad but unrecovered: " scenario, 12)
      }
    } else if (arm == "noisy-filter") {
      noisy_filter_seen = 1
      if (source != "noisy-route-code" || filter_mode != "negative-credit") {
        die("noisy-filter configuration mismatch: " scenario, 13)
      }
      noisy_filter_qacc = qacc
      noisy_filter_filtered = filtered
      noisy_filter_abstain = abstain
      if (source_gap >= 0 || noisy_mean >= 0 || noisy_slashed <= 0 ||
          fallback_recall != 0 || strength_mean > 1.000001) {
        die("filtered noisy fallback should stay detected and unamplified: " scenario, 14)
      }
      if (filtered <= 0) {
        die("filtered noisy fallback should drop negative-credit candidates", 15)
      }
    } else if (arm == "noisy-abstain") {
      noisy_abstain_seen = 1
      if (source != "noisy-route-code" || filter_mode != "negative-credit") {
        die("noisy-abstain configuration mismatch: " scenario, 16)
      }
      noisy_abstain_filtered = filtered
      noisy_abstain_abstain = abstain
      if (filtered <= 0 || abstain <= 0) {
        die("strict noisy filter should expose abstention", 17)
      }
    } else if (arm == "off-control") {
      off_seen = 1
      if (source != "off" || filter_mode != "off") {
        die("off-control configuration mismatch: " scenario, 18)
      }
      off_qacc = qacc
      if (filtered != 0 || abstain != 0) {
        die("filter should be inert when no fallback/source candidates are available", 19)
      }
    } else {
      die("unexpected arm: " arm, 20)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 21)
    }
    if (!(raw_seen && shape_seen && noisy_unfiltered_seen && noisy_filter_seen &&
          noisy_abstain_seen && off_seen)) {
      die("missing one or more bad-source filter arms", 22)
    }
    if (noisy_filter_filtered <= noisy_unfiltered_filtered) {
      die("negative-credit filter should increase filtered rate on noisy source", 24)
    }
    if (noisy_abstain_abstain < noisy_filter_abstain) {
      die("strict noisy abstain arm should not reduce abstention", 25)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit bad-source filter smoke passed"
