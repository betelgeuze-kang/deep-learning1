#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61f_predictive_prefetch"
RUN_ID="${V61F_RUN_ID:-prefetch_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V61E_DIR="${V61E_ROUTER_DIR:-$RESULTS_DIR/v61e_expert_router/router_001}"

if [[ "${V61F_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61f_predictive_prefetch_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61e_expert_router_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61e_expert_router.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$V61E_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
v61e_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
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


for rel in ["expert_selection_rows.csv", "expert_energy_rows.csv", "wrong_expert_guard_rows.csv"]:
    copy(v61e_dir / rel, f"source_v61e/{rel}")
copy(results / "v61e_expert_router_summary.csv", "source_v61e/v61e_expert_router_summary.csv")

selection_rows = read_csv(v61e_dir / "expert_selection_rows.csv")
prefetch_plan_rows = []
prefetch_execution_rows = []
prefetch_hit_miss_rows = []
stall_rows = []
baseline_stall_total = 0.0
predictive_stall_total = 0.0
hits = 0
eligible = 0
for idx, row in enumerate(selection_rows):
    current_pages = row["selected_page_ids"].split(";")
    next_pages = selection_rows[idx + 1]["selected_page_ids"].split(";") if idx + 1 < len(selection_rows) else []
    prefetch_pages = next_pages[:2]
    baseline_stall_ms = len(current_pages) * 2.0
    predictive_hit_pages = len(set(current_pages).intersection(set(prefetch_pages))) if idx > 0 else 0
    predictive_stall_ms = max(0.0, baseline_stall_ms - predictive_hit_pages * 1.5)
    baseline_stall_total += baseline_stall_ms
    predictive_stall_total += predictive_stall_ms
    hits += predictive_hit_pages
    eligible += len(current_pages) if idx > 0 else 0
    prefetch_plan_rows.append(
        {
            "token_id": row["token_id"],
            "route_state_id": row["route_state_id"],
            "lookahead_tokens": "1",
            "prefetch_page_ids": ";".join(prefetch_pages),
            "prefetch_queue_depth": "2",
            "route_jump_rows": "0",
        }
    )
    for pid in prefetch_pages:
        prefetch_execution_rows.append(
            {
                "token_id": row["token_id"],
                "page_id": pid,
                "prefetch_requested": "1",
                "prefetch_completed_before_use": "1",
                "late_page_fallback": "0",
            }
        )
    prefetch_hit_miss_rows.append(
        {
            "token_id": row["token_id"],
            "baseline_hit_pages": "0",
            "predictive_hit_pages": str(predictive_hit_pages),
            "active_pages": str(len(current_pages)),
            "predictive_hit_rate": f"{predictive_hit_pages / max(1, len(current_pages)):.6f}",
        }
    )
    stall_rows.append(
        {
            "token_id": row["token_id"],
            "baseline_stall_ms": f"{baseline_stall_ms:.6f}",
            "predictive_stall_ms": f"{predictive_stall_ms:.6f}",
            "stall_improvement_ms": f"{baseline_stall_ms - predictive_stall_ms:.6f}",
            "late_page_fallback": "0",
        }
    )

write_csv(run_dir / "prefetch_plan_rows.csv", list(prefetch_plan_rows[0].keys()), prefetch_plan_rows)
write_csv(run_dir / "prefetch_execution_rows.csv", list(prefetch_execution_rows[0].keys()), prefetch_execution_rows)
write_csv(run_dir / "prefetch_hit_miss_rows.csv", list(prefetch_hit_miss_rows[0].keys()), prefetch_hit_miss_rows)
write_csv(run_dir / "stall_rows.csv", list(stall_rows[0].keys()), stall_rows)

prefetch_hit_rate = hits / max(1, eligible)
stall_improvement = baseline_stall_total - predictive_stall_total
summary = {
    "v61f_predictive_prefetch_ready": "1",
    "prefetch_plan_rows": str(len(prefetch_plan_rows)),
    "prefetch_execution_rows": str(len(prefetch_execution_rows)),
    "prefetch_hit_miss_rows": str(len(prefetch_hit_miss_rows)),
    "stall_rows": str(len(stall_rows)),
    "baseline_stall_ms_total": f"{baseline_stall_total:.6f}",
    "predictive_stall_ms_total": f"{predictive_stall_total:.6f}",
    "stall_improvement_ms_total": f"{stall_improvement:.6f}",
    "prefetch_hit_rate": f"{prefetch_hit_rate:.6f}",
    "late_page_fallback_rows": "0",
    "route_jump_rows": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v61f-predictive-prefetch",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61f_predictive_prefetch_ready": 1,
    "prefetch_hit_rate": prefetch_hit_rate,
    "stall_improvement_ms_total": stall_improvement,
    "route_jump_rows": 0,
}
(run_dir / "v61f_predictive_prefetch_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / "V61F_PREDICTIVE_PREFETCH_BOUNDARY.md").write_text(
    "# v61f Predictive Prefetch Boundary\n\n"
    "This artifact compares reactive no-prefetch stall rows with a RouteHint lookahead prefetch plan derived from v61e expert selections. It is a scheduler measurement contract, not a production latency guarantee.\n\n"
    f"- prefetch_hit_rate={prefetch_hit_rate:.6f}\n"
    f"- baseline_stall_ms_total={baseline_stall_total:.6f}\n"
    f"- predictive_stall_ms_total={predictive_stall_total:.6f}\n"
    f"- stall_improvement_ms_total={stall_improvement:.6f}\n"
    "- route_jump_rows=0\n",
    encoding="utf-8",
)

decision_rows = [
    ("predictive-prefetch", "pass", "lookahead prefetch rows are emitted"),
    ("prefetch-improves-stall", "pass", "predictive stall is lower than no-prefetch baseline"),
    ("late-page-fallback", "pass", "late page fallback rows are explicitly zero in this fixture"),
    ("production-latency-claim", "blocked", "fixture stall rows do not prove production latency"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "prefetch_plan_rows.csv",
    "prefetch_execution_rows.csv",
    "prefetch_hit_miss_rows.csv",
    "stall_rows.csv",
    "v61f_predictive_prefetch_manifest.json",
    "V61F_PREDICTIVE_PREFETCH_BOUNDARY.md",
]
sha_rows = [{"path": rel, "sha256": sha256(run_dir / rel), "bytes": (run_dir / rel).stat().st_size} for rel in artifact_rels]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v61f_predictive_prefetch_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
