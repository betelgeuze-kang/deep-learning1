#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_PATH="$ROOT_DIR/data/routing_probe_fixture.txt"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" -j

run_case() {
  local csv_path="$1"
  shift
  "$BUILD_DIR/dmv02" "$@" --csv "$csv_path"
}

print_final_summary() {
  local label="$1"
  local csv_path="$2"

  awk -F, -v label="$label" '
    BEGIN {
      metric_names[1] = "byte_acc"
      metric_names[2] = "field_byte_acc"
      metric_names[3] = "joint_byte_acc"
      metric_labels[1] = "byte"
      metric_labels[2] = "field"
      metric_labels[3] = "joint"
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        headers[i] = $i
        idx[$i] = i
      }
      diag_start = idx["routing_trigger_rate"] + 0
      header_count = NF
      next
    }
    {
      last = $0
      data_rows++
    }
    END {
      if (data_rows == 0) {
        printf "%-24s final no-data\n", label
        exit 0
      }

      split(last, row, FS)
      printf "%-24s final", label

      for (i = 1; i <= 3; i++) {
        name = metric_names[i]
        if (name in idx) {
          printf " %s=%s", metric_labels[i], row[idx[name]]
        }
      }

      if (diag_start > 0) {
        for (i = diag_start; i <= header_count; i++) {
          name = headers[i]
          if (name != "") {
            printf " %s=%s", name, row[idx[name]]
          }
        }
      }

      printf "\n"
    }
  ' "$csv_path"
}

print_last10_summary() {
  local label="$1"
  local csv_path="$2"

  awk -F, -v label="$label" '
    BEGIN {
      metric_names[1] = "byte_acc"
      metric_names[2] = "field_byte_acc"
      metric_names[3] = "joint_byte_acc"
      metric_labels[1] = "byte"
      metric_labels[2] = "field"
      metric_labels[3] = "joint"
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        headers[i] = $i
        idx[$i] = i
      }
      diag_start = idx["routing_trigger_rate"] + 0
      header_count = NF
      next
    }
    {
      data[++data_rows] = $0
    }
    END {
      if (data_rows == 0) {
        printf "%-24s last-10 no-data\n", label
        exit 0
      }

      start = (data_rows > 10 ? data_rows - 9 : 1)
      count = data_rows - start + 1

      for (r = start; r <= data_rows; r++) {
        split(data[r], row, FS)

        for (i = 1; i <= 3; i++) {
          name = metric_names[i]
          if (name in idx) {
            sum[metric_labels[i]] += row[idx[name]] + 0
          }
        }

        if (diag_start > 0) {
          for (i = diag_start; i <= header_count; i++) {
            name = headers[i]
            if (name != "") {
              sum[name] += row[idx[name]] + 0
            }
          }
        }
      }

      printf "%-24s last-10", label

      for (i = 1; i <= 3; i++) {
        name = metric_names[i]
        if (name in idx) {
          printf " %s=%.6f", metric_labels[i], sum[metric_labels[i]] / count
        }
      }

      if (diag_start > 0) {
        for (i = diag_start; i <= header_count; i++) {
          name = headers[i]
          if (name != "") {
            printf " %s=%.6f", name, sum[name] / count
          }
        }
      }

      printf "\n"
    }
  ' "$csv_path"
}

BASE_ARGS=(
  --N 256
  --epochs 80
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
  --K-jump 2
  --route-reservoir-threshold 0.05
)

JOINT_PROBE_ARGS=(
  --route-source joint-code
)

INPUT_PROBE_ARGS=(
  --route-source input-byte
)

STATE_CYCLE_PROBE_ARGS=(
  --route-source state-code
  --route-refresh cycle
)

JOINT_GAP0_ARGS=(
  --route-source joint-code
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
)

INPUT_GAP0_ARGS=(
  --route-source input-byte
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
)

STATE_CYCLE_GAP0_ARGS=(
  --route-source state-code
  --route-refresh cycle
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
)

JOINT_ACCEPT_ARGS=(
  --route-source joint-code
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
  --route-accept-confidence-gain 0.20
)

INPUT_ACCEPT_ARGS=(
  --route-source input-byte
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
  --route-accept-confidence-gain 0.20
)

STATE_CYCLE_ACCEPT_ARGS=(
  --route-source state-code
  --route-refresh cycle
  --route-mode jump-neighbors
  --route-min-anchor-gap 0.0
  --route-accept-confidence-gain 0.20
)

run_suite_for_dataset() {
  local dataset_label="$1"
  shift
  local dataset_args=("$@")

  echo "candidate-source compare: ${dataset_label} joint-code probe"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_probe.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${JOINT_PROBE_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} input-byte probe"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_probe.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${INPUT_PROBE_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} state-code cycle probe"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_probe.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${STATE_CYCLE_PROBE_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} joint-code gap0 jump"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_gap0.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${JOINT_GAP0_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} input-byte gap0 jump"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_gap0.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${INPUT_GAP0_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} state-code cycle gap0 jump"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_gap0.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${STATE_CYCLE_GAP0_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} joint-code accepted jump"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_accept.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${JOINT_ACCEPT_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} input-byte accepted jump"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_accept.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${INPUT_ACCEPT_ARGS[@]}"

  echo "candidate-source compare: ${dataset_label} state-code cycle accepted jump"
  run_case "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_accept.csv" \
    "${dataset_args[@]}" "${BASE_ARGS[@]}" "${STATE_CYCLE_ACCEPT_ARGS[@]}"
}

print_suite_for_dataset() {
  local dataset_label="$1"

  print_final_summary "${dataset_label}-joint-probe" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_probe.csv"
  print_last10_summary "${dataset_label}-joint-probe" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_probe.csv"

  print_final_summary "${dataset_label}-input-probe" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_probe.csv"
  print_last10_summary "${dataset_label}-input-probe" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_probe.csv"

  print_final_summary "${dataset_label}-state-cycle-probe" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_probe.csv"
  print_last10_summary "${dataset_label}-state-cycle-probe" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_probe.csv"

  print_final_summary "${dataset_label}-joint-gap0" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_gap0.csv"
  print_last10_summary "${dataset_label}-joint-gap0" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_gap0.csv"

  print_final_summary "${dataset_label}-input-gap0" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_gap0.csv"
  print_last10_summary "${dataset_label}-input-gap0" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_gap0.csv"

  print_final_summary "${dataset_label}-state-cycle-gap0" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_gap0.csv"
  print_last10_summary "${dataset_label}-state-cycle-gap0" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_gap0.csv"

  print_final_summary "${dataset_label}-joint-accept" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_accept.csv"
  print_last10_summary "${dataset_label}-joint-accept" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_joint_accept.csv"

  print_final_summary "${dataset_label}-input-accept" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_accept.csv"
  print_last10_summary "${dataset_label}-input-accept" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_input_accept.csv"

  print_final_summary "${dataset_label}-state-cycle-accept" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_accept.csv"
  print_last10_summary "${dataset_label}-state-cycle-accept" \
    "$RESULTS_DIR/v03_input_byte_${dataset_label}_state_cycle_accept.csv"
}

# Diagnostic-only candidate-source probe: compare joint-code, input-byte, and
# state-code cycle bucket keys while keeping the learned joint-code route anchor
# for gap0 and confidence-accepted jump cases.
run_suite_for_dataset repeat --dataset repeating-text
run_suite_for_dataset fixture --input "$FIXTURE_PATH"

echo
print_suite_for_dataset repeat
print_suite_for_dataset fixture
