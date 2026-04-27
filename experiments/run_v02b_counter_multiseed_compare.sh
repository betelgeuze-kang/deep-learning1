#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
BUILD_DIR="$ROOT_DIR/build"
SEEDS=(1 2 3 4 5)

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" -j

COMMON_ARGS=(
  --dataset counter
  --N 128
  --epochs 200
  --cycles-per-epoch 20
  --lambda-v 0
)

CONTROL_FILES=()
WEAK_FILES=()

run_mode() {
  local mode="$1"
  local seed="$2"
  local csv_path
  local mode_args=()

  case "$mode" in
    control)
      csv_path="$RESULTS_DIR/v02b_counter_off_seed${seed}.csv"
      mode_args=(--lambda-b 0 --eta-b 0)
      CONTROL_FILES+=("$csv_path")
      ;;
    weak)
      csv_path="$RESULTS_DIR/v02b_counter_lv0_lb010_eb002_seed${seed}.csv"
      mode_args=(--lambda-b 0.1 --eta-b 0.02)
      WEAK_FILES+=("$csv_path")
      ;;
    *)
      echo "unknown mode: $mode" >&2
      return 1
      ;;
  esac

  echo "counter: ${mode} seed=${seed} -> $(basename "$csv_path")"
  "$BUILD_DIR/dmv02" "${COMMON_ARGS[@]}" --seed "$seed" "${mode_args[@]}" --csv "$csv_path"
}

summarize_csv() {
  local mode="$1"
  local seed="$2"
  local csv_path="$3"

  awk -F, -v mode="$mode" -v seed="$seed" '
    NR > 1 {
      epoch = $1
      byte = $3
      field = $4
      oracle = $5
      joint = $19
      margin = $10
    }

    END {
      printf "%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f\n",
             mode, seed, epoch, byte, field, joint, oracle, margin
    }
  ' "$csv_path"
}

print_summary() {
  local idx

  {
    for idx in "${!CONTROL_FILES[@]}"; do
      summarize_csv control "${SEEDS[$idx]}" "${CONTROL_FILES[$idx]}"
      summarize_csv weak "${SEEDS[$idx]}" "${WEAK_FILES[$idx]}"
    done
  } | awk -F, '
    {
      mode = $1
      seed = $2
      epoch = $3
      byte = $4 + 0
      field = $5 + 0
      joint = $6 + 0
      oracle = $7 + 0
      margin = $8 + 0

      printf "%-7s seed=%s epoch=%s byte=%.6f field=%.6f joint=%.6f oracle1=%.6f field_margin=%.6f\n",
             mode, seed, epoch, byte, field, joint, oracle, margin

      if (mode == "control") {
        control_count++
        control_byte += byte
        control_field += field
        control_joint += joint
        control_oracle += oracle
        control_margin += margin
        control_seed_byte[seed] = byte
        control_seed_field[seed] = field
        control_seed_joint[seed] = joint
      } else if (mode == "weak") {
        weak_count++
        weak_byte += byte
        weak_field += field
        weak_joint += joint
        weak_oracle += oracle
        weak_margin += margin
        weak_seed_byte[seed] = byte
        weak_seed_field[seed] = field
        weak_seed_joint[seed] = joint
      }
    }

    END {
      if (control_count > 0) {
        printf "avg     control byte=%.6f field=%.6f joint=%.6f oracle1=%.6f field_margin=%.6f n=%d\n",
               control_byte / control_count, control_field / control_count,
               control_joint / control_count, control_oracle / control_count,
               control_margin / control_count, control_count
      }

      if (weak_count > 0) {
        printf "avg     weak    byte=%.6f field=%.6f joint=%.6f oracle1=%.6f field_margin=%.6f n=%d\n",
               weak_byte / weak_count, weak_field / weak_count,
               weak_joint / weak_count, weak_oracle / weak_count,
               weak_margin / weak_count, weak_count
      }

      for (seed = 1; seed <= 5; ++seed) {
        if ((seed in control_seed_byte) && (seed in weak_seed_byte)) {
          byte_delta = weak_seed_byte[seed] - control_seed_byte[seed]
          field_delta = weak_seed_field[seed] - control_seed_field[seed]
          joint_delta = weak_seed_joint[seed] - control_seed_joint[seed]
          delta_count++
          delta_byte += byte_delta
          delta_field += field_delta
          delta_joint += joint_delta
          printf "delta   seed=%d byte=%.6f field=%.6f joint=%.6f\n",
                 seed, byte_delta, field_delta, joint_delta
        }
      }

      if (delta_count > 0) {
        printf "delta   avg     byte=%.6f field=%.6f joint=%.6f n=%d\n",
               delta_byte / delta_count, delta_field / delta_count,
               delta_joint / delta_count, delta_count
      }
    }
  '
}

for seed in "${SEEDS[@]}"; do
  run_mode control "$seed"
  run_mode weak "$seed"
done

echo
echo "counter multiseed summary (default proposal count, seeds 1..5)"
print_summary "${CONTROL_FILES[@]}" "${WEAK_FILES[@]}"
