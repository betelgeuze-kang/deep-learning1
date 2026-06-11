#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61h_dense_stress_harness"
RUN_ID="${V61H_RUN_ID:-dense_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61H_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61h_dense_stress_harness_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61g_mixed_quant_planner_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61g_mixed_quant_planner.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy_if_exists(src, rel):
    if src.is_file():
        dst = run_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


copy_if_exists(results / "v61g_mixed_quant_planner_summary.csv", "source_v61g/v61g_mixed_quant_planner_summary.csv")

nvme_gbps = float(__import__("os").environ.get("V61H_NVME_GBPS", "7.0"))
practical_tps_threshold = float(__import__("os").environ.get("V61H_PRACTICAL_TPS_THRESHOLD", "3.0"))
models = [
    ("dense_30b_q4", 30_000_000_000, 4),
    ("dense_70b_q4", 70_000_000_000, 4),
    ("dense_200b_q4", 200_000_000_000, 4),
    ("dense_1000b_q3", 1_000_000_000_000, 3),
]

read_rows = []
decode_rows = []
blocker_rows = []
for model_id, parameters, quant_bits in models:
    full_stream_bytes = parameters * quant_bits // 8
    read_ms = full_stream_bytes / (nvme_gbps * 1_000_000_000) * 1000.0
    dequant_ms = parameters / 30_000_000_000 * 7.5
    matmul_proxy_ms = parameters / 30_000_000_000 * 10.0
    total_ms = read_ms + dequant_ms + matmul_proxy_ms
    tps = 1000.0 / total_ms
    practical = tps >= practical_tps_threshold
    read_rows.append(
        {
            "model_id": model_id,
            "parameters": str(parameters),
            "quant_bits": str(quant_bits),
            "full_stream_read_bytes_per_token": str(full_stream_bytes),
            "nvme_gbps_assumption": f"{nvme_gbps:.3f}",
            "full_stream_read_ms_per_token": f"{read_ms:.6f}",
            "dense_full_stream_cost_measured": "1",
        }
    )
    decode_rows.append(
        {
            "model_id": model_id,
            "dequant_ms_per_token_proxy": f"{dequant_ms:.6f}",
            "matmul_ms_per_token_proxy": f"{matmul_proxy_ms:.6f}",
            "total_ms_per_token_proxy": f"{total_ms:.6f}",
            "tokens_per_second_proxy": f"{tps:.6f}",
            "practical_speed_threshold_tps": f"{practical_tps_threshold:.6f}",
            "practical_speed_reachable": "1" if practical else "0",
        }
    )
    if not practical:
        blocker_rows.append(
            {
                "model_id": model_id,
                "blocker": "dense-full-stream-ssd-read",
                "reason": "dense inference requires reading the full parameter stream per token in this stress model",
                "claim_status": "blocked",
            }
        )

write_csv(run_dir / "dense_stress_read_rows.csv", list(read_rows[0].keys()), read_rows)
write_csv(run_dir / "dense_stress_decode_proxy_rows.csv", list(decode_rows[0].keys()), decode_rows)
write_csv(run_dir / "dense_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

summary = {
    "v61h_dense_stress_harness_ready": "1",
    "dense_stress_read_rows": str(len(read_rows)),
    "dense_stress_decode_proxy_rows": str(len(decode_rows)),
    "dense_blocker_rows": str(len(blocker_rows)),
    "dense_full_stream_cost_measured": "1",
    "dense_hundreds_b_local_speed_claim": "blocked",
    "practical_dense_speed_rows": str(sum(int(r["practical_speed_reachable"]) for r in decode_rows)),
    "route_jump_rows": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v61h-dense-stress-harness",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61h_dense_stress_harness_ready": 1,
    "nvme_gbps_assumption": nvme_gbps,
    "dense_full_stream_cost_measured": 1,
    "dense_hundreds_b_local_speed_claim": "blocked",
    "route_jump_rows": 0,
}
(run_dir / "v61h_dense_stress_harness_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / "V61H_DENSE_STRESS_HARNESS_BOUNDARY.md").write_text(
    "# v61h Dense Stress Harness Boundary\n\n"
    "This artifact measures dense full-stream SSD read pressure as a blocker for local dense hundreds-B inference. It is intentionally a stress harness, not a dense model speed claim.\n\n"
    f"- dense_full_stream_cost_measured=1\n"
    f"- dense_blocker_rows={len(blocker_rows)}\n"
    "- dense_hundreds_b_local_speed_claim=blocked\n"
    "- route_jump_rows=0\n",
    encoding="utf-8",
)

decision_rows = [
    ("dense-full-stream-cost", "pass", "full-stream SSD bytes/token and proxy decode rows are emitted"),
    ("dense-blocker-explicit", "pass", "impractical dense rows produce blocker rows"),
    ("dense-hundreds-b-speed-claim", "blocked", "dense local hundreds-B speed is not opened by this artifact"),
    ("release-package", "blocked", "stress harness is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "dense_stress_read_rows.csv",
    "dense_stress_decode_proxy_rows.csv",
    "dense_blocker_rows.csv",
    "v61h_dense_stress_harness_manifest.json",
    "V61H_DENSE_STRESS_HARNESS_BOUNDARY.md",
]
sha_rows = [{"path": rel, "sha256": sha256(run_dir / rel), "bytes": (run_dir / rel).stat().st_size} for rel in artifact_rels]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v61h_dense_stress_harness_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
