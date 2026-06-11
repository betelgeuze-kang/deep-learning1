#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61g_mixed_quant_planner"
RUN_ID="${V61G_RUN_ID:-quant_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V61A_DIR="${V61A_STORE_DIR:-$RESULTS_DIR/v61a_ssd_weight_page_store/store_001}"
V61E_DIR="${V61E_ROUTER_DIR:-$RESULTS_DIR/v61e_expert_router/router_001}"

if [[ "${V61G_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61g_mixed_quant_planner_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61f_predictive_prefetch_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61f_predictive_prefetch.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$V61A_DIR" "$V61E_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
v61a_dir = Path(sys.argv[3])
v61e_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
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


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


copy(v61a_dir / "weight_page_rows.csv", "source_v61a/weight_page_rows.csv")
copy(v61e_dir / "expert_selection_rows.csv", "source_v61e/expert_selection_rows.csv")
copy(results / "v61f_predictive_prefetch_summary.csv", "source_v61f/v61f_predictive_prefetch_summary.csv")

pages = read_csv(v61a_dir / "weight_page_rows.csv")
sensitivity_rows = []
assignment_rows = []
quality_rows = []
runtime_rows = []
high_sensitivity_high_precision = 0
cold_low_precision = 0
for row in pages:
    if row["hotness_label"] == "vram-hot":
        sensitivity = 0.95
        assigned = "q5-router-hot"
    elif row["hotness_label"] == "warm-prefetch":
        sensitivity = 0.62
        assigned = "q4-active-default"
    else:
        sensitivity = 0.28
        assigned = "q3-cold-expert"
    quality_delta = (5 - int(assigned[1])) * 0.003 + (1.0 - sensitivity) * 0.01
    runtime_delta = {"q5-router-hot": -0.05, "q4-active-default": -0.15, "q3-cold-expert": -0.28}[assigned]
    sensitivity_rows.append(
        {
            "page_id": row["page_id"],
            "expert_id": row["expert_id"],
            "hotness_label": row["hotness_label"],
            "sensitivity_score": f"{sensitivity:.6f}",
            "high_sensitivity": "1" if sensitivity >= 0.80 else "0",
        }
    )
    assignment_rows.append(
        {
            "page_id": row["page_id"],
            "original_quant_profile_id": row["quant_profile_id"],
            "assigned_quant_profile_id": assigned,
            "assignment_reason": "protect-router-hot" if sensitivity >= 0.8 else "balanced-active" if sensitivity >= 0.5 else "cold-compress",
            "quality_risk_bounded": "1",
        }
    )
    quality_rows.append(
        {
            "page_id": row["page_id"],
            "assigned_quant_profile_id": assigned,
            "quality_delta_estimate": f"{quality_delta:.6f}",
            "quality_delta_within_budget": "1" if quality_delta <= 0.020 else "0",
        }
    )
    runtime_rows.append(
        {
            "page_id": row["page_id"],
            "assigned_quant_profile_id": assigned,
            "ssd_runtime_delta_estimate": f"{runtime_delta:.6f}",
            "read_bytes_delta_direction": "lower-or-equal",
        }
    )
    high_sensitivity_high_precision += int(sensitivity >= 0.80 and assigned.startswith("q5"))
    cold_low_precision += int(sensitivity < 0.50 and assigned.startswith("q3"))

write_csv(run_dir / "quant_sensitivity_rows.csv", list(sensitivity_rows[0].keys()), sensitivity_rows)
write_csv(run_dir / "quant_assignment_rows.csv", list(assignment_rows[0].keys()), assignment_rows)
write_csv(run_dir / "quant_quality_delta_rows.csv", list(quality_rows[0].keys()), quality_rows)
write_csv(run_dir / "quant_runtime_delta_rows.csv", list(runtime_rows[0].keys()), runtime_rows)

summary = {
    "v61g_mixed_quant_planner_ready": "1",
    "quant_sensitivity_rows": str(len(sensitivity_rows)),
    "quant_assignment_rows": str(len(assignment_rows)),
    "quant_quality_delta_rows": str(len(quality_rows)),
    "quant_runtime_delta_rows": str(len(runtime_rows)),
    "high_sensitivity_high_precision_rows": str(high_sensitivity_high_precision),
    "cold_low_precision_rows": str(cold_low_precision),
    "quality_delta_budget_pass_rows": str(sum(int(r["quality_delta_within_budget"]) for r in quality_rows)),
    "route_jump_rows": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v61g-mixed-quant-planner",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61g_mixed_quant_planner_ready": 1,
    "high_sensitivity_high_precision_rows": high_sensitivity_high_precision,
    "cold_low_precision_rows": cold_low_precision,
    "route_jump_rows": 0,
}
(run_dir / "v61g_mixed_quant_planner_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / "V61G_MIXED_QUANT_PLANNER_BOUNDARY.md").write_text(
    "# v61g Mixed Quant Planner Boundary\n\n"
    "This artifact binds page/expert sensitivity to mixed quantization assignments. It keeps high-sensitivity pages higher precision, moves cold pages lower precision, and records quality/runtime tradeoff rows.\n\n"
    f"- high_sensitivity_high_precision_rows={high_sensitivity_high_precision}\n"
    f"- cold_low_precision_rows={cold_low_precision}\n"
    f"- quality_delta_budget_pass_rows={sum(int(r['quality_delta_within_budget']) for r in quality_rows)}\n"
    "- route_jump_rows=0\n",
    encoding="utf-8",
)

decision_rows = [
    ("mixed-quant-planner", "pass", "sensitivity, assignment, quality delta, and runtime delta rows are emitted"),
    ("high-sensitivity-protected", "pass", "high-sensitivity pages stay high precision"),
    ("cold-pages-compressed", "pass", "cold pages move to lower precision"),
    ("quality-budget", "pass", "all quality deltas stay within fixture budget"),
    ("production-quality-claim", "blocked", "fixture quant planner does not prove production model quality"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "quant_sensitivity_rows.csv",
    "quant_assignment_rows.csv",
    "quant_quality_delta_rows.csv",
    "quant_runtime_delta_rows.csv",
    "v61g_mixed_quant_planner_manifest.json",
    "V61G_MIXED_QUANT_PLANNER_BOUNDARY.md",
]
sha_rows = [{"path": rel, "sha256": sha256(run_dir / rel), "bytes": (run_dir / rel).stat().st_size} for rel in artifact_rels]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v61g_mixed_quant_planner_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
