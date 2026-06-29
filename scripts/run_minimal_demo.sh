#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
DEMO_DIR="$RESULTS_DIR/minimal_demo"
V54_SUMMARY="$RESULTS_DIR/v54_minimal_real_model_smoke_summary.csv"
V54_DECISION="$RESULTS_DIR/v54_minimal_real_model_smoke_decision.csv"
V54_RUN_DIR="$RESULTS_DIR/v54_minimal_real_model_smoke/smoke_001"

mkdir -p "$DEMO_DIR"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build" -DDLE_ENABLE_HIP=OFF >/dev/null
cmake --build "$ROOT_DIR/build" --target dmv02 -j "${AI_VERIFY_JOBS:-2}" >/dev/null

"$ROOT_DIR/build/dmv02" \
  --dataset counter \
  --N 32 \
  --epochs 1 \
  --cycles-per-epoch 2 \
  --seed 1 \
  --csv "$DEMO_DIR/dmv02_counter_smoke.csv" >/dev/null

python3 "$ROOT_DIR/scripts/v54_minimal_real_model_smoke.py" \
  --out "$V54_RUN_DIR" \
  --summary "$V54_SUMMARY" \
  --decision "$V54_DECISION" >/dev/null

"$ROOT_DIR/tools/verify_artifact.py" typed-readiness "$ROOT_DIR/readiness/typed_ready.json" >/dev/null

python3 - "$DEMO_DIR" "$V54_SUMMARY" "$V54_DECISION" "$V54_RUN_DIR" <<'PY'
import csv
import sys
from pathlib import Path

demo_dir = Path(sys.argv[1])
v54_summary = Path(sys.argv[2])
v54_decision = Path(sys.argv[3])
v54_run_dir = Path(sys.argv[4])

rows = [
    {
        "artifact": "cpp_dmv02_counter_smoke",
        "path": str(demo_dir / "dmv02_counter_smoke.csv"),
        "claim": "C++ executable built and ran a tiny deterministic counter smoke",
    },
    {
        "artifact": "v54_minimal_real_model_summary",
        "path": str(v54_summary),
        "claim": "tiny local model executed on heldout split; release remains blocked",
    },
    {
        "artifact": "v54_minimal_real_model_decision",
        "path": str(v54_decision),
        "claim": "real-model and heldout gates pass; human, independent, release gates block",
    },
    {
        "artifact": "v54_minimal_real_model_packet",
        "path": str(v54_run_dir),
        "claim": "hash-bound run packet with split rows, checkpoint manifest, generation rows, and metric rows",
    },
]
summary_path = demo_dir / "minimal_demo_summary.csv"
with summary_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "claim"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
print(summary_path)
PY

cat <<EOF
minimal demo complete

C++ smoke:
  $DEMO_DIR/dmv02_counter_smoke.csv

Real-model heldout smoke:
  $V54_SUMMARY
  $V54_DECISION
  $V54_RUN_DIR

Demo summary:
  $DEMO_DIR/minimal_demo_summary.csv

Boundary:
  This demo proves local execution and a minimal heldout metric only.
  human_review_ready, independent_reproduction_ready, and release_ready remain 0.
EOF
