#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61as_hotset_reuse_admission_gate"
RUN_ID="${V61AS_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61as_hotset_reuse_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AC_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ac_hotset_token_budget_replay.sh" >/dev/null
V61AD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ad_kv_weight_token_budget_replay.sh" >/dev/null
V61AR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ar_moe_remote_hash_result_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import math
import shutil
import sys
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"
page_bytes = 2 * 1024 * 1024


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


def fmt(value):
    if math.isfinite(value):
        return f"{value:.9f}"
    return str(value)


v61ac_dir = results / "v61ac_hotset_token_budget_replay" / "replay_001"
v61ad_dir = results / "v61ad_kv_weight_token_budget_replay" / "replay_001"
v61ar_dir = results / "v61ar_moe_remote_hash_result_intake" / "intake_001"

v61ac_summary = read_csv(results / "v61ac_hotset_token_budget_replay_summary.csv")[0]
v61ad_summary = read_csv(results / "v61ad_kv_weight_token_budget_replay_summary.csv")[0]
v61ar_summary = read_csv(results / "v61ar_moe_remote_hash_result_intake_summary.csv")[0]
if v61ac_summary.get("v61ac_hotset_token_budget_replay_ready") != "1":
    raise SystemExit("v61as requires v61ac_hotset_token_budget_replay_ready=1")
if v61ad_summary.get("v61ad_kv_weight_token_budget_replay_ready") != "1":
    raise SystemExit("v61as requires v61ad_kv_weight_token_budget_replay_ready=1")
if v61ar_summary.get("v61ar_moe_remote_hash_result_intake_ready") != "1":
    raise SystemExit("v61as requires v61ar_moe_remote_hash_result_intake_ready=1")

for src, rel in [
    (results / "v61ac_hotset_token_budget_replay_summary.csv", "source_v61ac/v61ac_hotset_token_budget_replay_summary.csv"),
    (results / "v61ac_hotset_token_budget_replay_decision.csv", "source_v61ac/v61ac_hotset_token_budget_replay_decision.csv"),
    (v61ac_dir / "hotset_token_budget_rows.csv", "source_v61ac/hotset_token_budget_rows.csv"),
    (v61ac_dir / "hotset_token_budget_page_schedule_rows.csv", "source_v61ac/hotset_token_budget_page_schedule_rows.csv"),
    (v61ac_dir / "hotset_token_budget_metric_rows.csv", "source_v61ac/hotset_token_budget_metric_rows.csv"),
    (v61ac_dir / "sha256_manifest.csv", "source_v61ac/sha256_manifest.csv"),
    (results / "v61ad_kv_weight_token_budget_replay_summary.csv", "source_v61ad/v61ad_kv_weight_token_budget_replay_summary.csv"),
    (results / "v61ad_kv_weight_token_budget_replay_decision.csv", "source_v61ad/v61ad_kv_weight_token_budget_replay_decision.csv"),
    (v61ad_dir / "kv_weight_token_budget_rows.csv", "source_v61ad/kv_weight_token_budget_rows.csv"),
    (v61ad_dir / "kv_weight_token_budget_metric_rows.csv", "source_v61ad/kv_weight_token_budget_metric_rows.csv"),
    (v61ad_dir / "sha256_manifest.csv", "source_v61ad/sha256_manifest.csv"),
    (results / "v61ar_moe_remote_hash_result_intake_summary.csv", "source_v61ar/v61ar_moe_remote_hash_result_intake_summary.csv"),
    (results / "v61ar_moe_remote_hash_result_intake_decision.csv", "source_v61ar/v61ar_moe_remote_hash_result_intake_decision.csv"),
    (v61ar_dir / "moe_remote_hash_combined_coverage_rows.csv", "source_v61ar/moe_remote_hash_combined_coverage_rows.csv"),
    (v61ar_dir / "moe_remote_hash_result_metric_rows.csv", "source_v61ar/moe_remote_hash_result_metric_rows.csv"),
    (v61ar_dir / "sha256_manifest.csv", "source_v61ar/sha256_manifest.csv"),
]:
    copy(src, rel)

token_rows = read_csv(v61ac_dir / "hotset_token_budget_rows.csv")
schedule_rows = read_csv(v61ac_dir / "hotset_token_budget_page_schedule_rows.csv")
kv_rows = read_csv(v61ad_dir / "kv_weight_token_budget_rows.csv")
coverage_rows = read_csv(v61ar_dir / "moe_remote_hash_combined_coverage_rows.csv")
if len(token_rows) != 37:
    raise SystemExit("v61as expects 37 token rows")
if len(schedule_rows) != 148:
    raise SystemExit("v61as expects 148 scheduled page rows")
if len(kv_rows) != 185:
    raise SystemExit("v61as expects 185 KV+weight rows")
if len(coverage_rows) != 1344:
    raise SystemExit("v61as expects 1344 MoE hash coverage rows")
if any(row["direct_read_hash_match"] != "1" for row in schedule_rows):
    raise SystemExit("v61as requires every scheduled page read to be hash-matched")
if any(int(row["bytes_read"]) != page_bytes for row in schedule_rows):
    raise SystemExit("v61as requires every scheduled page read to be one 2 MiB page")

page_first = OrderedDict()
page_counts = {}
token_state = {}
seen = set()
for row in schedule_rows:
    key = row["remote_sample_id"]
    page_counts[key] = page_counts.get(key, 0) + 1
    if key not in page_first:
        page_first[key] = row
    token = token_state.setdefault(
        row["token_budget_id"] if "token_budget_id" in row else row["workload_binding_id"],
        {
            "workload_binding_id": row["workload_binding_id"],
            "query_id": row["query_id"],
            "query_family": row["query_family"],
            "scheduled_page_rows": 0,
            "cache_miss_page_rows": 0,
            "cache_hit_page_rows": 0,
        },
    )
    token["scheduled_page_rows"] += 1
    if key in seen:
        token["cache_hit_page_rows"] += 1
    else:
        token["cache_miss_page_rows"] += 1
        seen.add(key)

unique_pages = len(page_first)
cache_miss_rows = unique_pages
scheduled_rows = len(schedule_rows)
cache_hit_rows = scheduled_rows - cache_miss_rows
source_bound_rows = len(token_rows)
uncached_total_bytes = scheduled_rows * page_bytes
cold_fill_total_bytes = unique_pages * page_bytes
saved_bytes = uncached_total_bytes - cold_fill_total_bytes
uncached_per_token = int(v61ac_summary["ssd_read_bytes_per_token"])
amortized_cold_fill_per_token = cold_fill_total_bytes / source_bound_rows
amortized_saved_per_token = uncached_per_token - amortized_cold_fill_per_token
hit_rate = cache_hit_rows / scheduled_rows
reuse_factor = scheduled_rows / unique_pages

page_rows = []
for index, (remote_sample_id, row) in enumerate(page_first.items()):
    scheduled_count = page_counts[remote_sample_id]
    page_rows.append(
        {
            "reuse_page_id": f"v61as_hotset_reuse_page_{index:04d}",
            "remote_sample_id": remote_sample_id,
            "runtime_node_id": row["runtime_node_id"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "first_schedule_id": row["schedule_id"],
            "first_query_id": row["query_id"],
            "scheduled_page_read_rows": str(scheduled_count),
            "cache_miss_page_rows": "1",
            "cache_hit_page_rows": str(scheduled_count - 1),
            "page_bytes": str(page_bytes),
            "uncached_read_bytes": str(scheduled_count * page_bytes),
            "persistent_hotset_cold_fill_bytes": str(page_bytes),
            "persistent_hotset_saved_bytes": str((scheduled_count - 1) * page_bytes),
            "direct_read_hash_match": row["direct_read_hash_match"],
            "sampled_hotset_page_reuse_ready": "1",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "hotset_reuse_page_rows.csv", list(page_rows[0].keys()), page_rows)

token_reuse_rows = []
token_by_workload = {row["workload_binding_id"]: row for row in token_rows}
for index, token in enumerate(token_state.values()):
    source = token_by_workload[token["workload_binding_id"]]
    miss_bytes = token["cache_miss_page_rows"] * page_bytes
    hit_bytes_saved = token["cache_hit_page_rows"] * page_bytes
    token_reuse_rows.append(
        {
            "reuse_token_id": f"v61as_hotset_reuse_token_{index:04d}",
            "token_budget_id": source["token_budget_id"],
            "workload_binding_id": token["workload_binding_id"],
            "query_id": token["query_id"],
            "query_family": token["query_family"],
            "scheduled_page_rows": str(token["scheduled_page_rows"]),
            "cache_miss_page_rows": str(token["cache_miss_page_rows"]),
            "cache_hit_page_rows": str(token["cache_hit_page_rows"]),
            "uncached_ssd_read_bytes": source["ssd_read_bytes_per_token"],
            "persistent_hotset_cold_fill_bytes": str(miss_bytes),
            "persistent_hotset_saved_bytes": str(hit_bytes_saved),
            "source_bound_query_pass": source["source_bound_query_pass"],
            "token_reuse_ready": "1",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "production_latency_claim_ready": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "hotset_reuse_token_rows.csv", list(token_reuse_rows[0].keys()), token_reuse_rows)

window_rows = [
    {
        "reuse_window_id": "v61as_source_bound_37_query_window",
        "source_bound_token_budget_rows": str(source_bound_rows),
        "scheduled_hotset_page_read_rows": str(scheduled_rows),
        "unique_hotset_page_rows": str(unique_pages),
        "cache_miss_page_rows": str(cache_miss_rows),
        "cache_hit_page_rows": str(cache_hit_rows),
        "cache_hit_rate": fmt(hit_rate),
        "reuse_factor": fmt(reuse_factor),
        "uncached_ssd_read_bytes_total": str(uncached_total_bytes),
        "persistent_hotset_cold_fill_bytes": str(cold_fill_total_bytes),
        "persistent_hotset_saved_bytes": str(saved_bytes),
        "uncached_ssd_read_bytes_per_token": str(uncached_per_token),
        "amortized_cold_fill_bytes_per_token": fmt(amortized_cold_fill_per_token),
        "amortized_saved_bytes_per_token": fmt(amortized_saved_per_token),
        "sampled_hotset_reuse_ready": "1",
    }
]
write_csv(run_dir / "hotset_reuse_window_rows.csv", list(window_rows[0].keys()), window_rows)

sampled_hotset_reuse_ready = int(
    source_bound_rows == 37
    and scheduled_rows == 148
    and unique_pages == 15
    and cache_hit_rows == 133
    and cache_miss_rows == 15
    and all(row["token_reuse_ready"] == "1" for row in token_reuse_rows)
)
full_moe_coverage_remote_hash_ready = int(v61ar_summary["full_moe_coverage_remote_hash_ready"])
remote_hash_result_intake_ready = int(v61ar_summary["remote_hash_result_intake_ready"])
full_runtime_hotset_reuse_admission_ready = int(
    sampled_hotset_reuse_ready
    and full_moe_coverage_remote_hash_ready
    and remote_hash_result_intake_ready
    and v61ad_summary["full_safetensors_page_hash_binding_ready"] == "1"
)

requirement_rows = [
    {"requirement_id": "v61ac-hotset-token-budget-input", "status": "pass", "actual": str(source_bound_rows), "required": "37", "reason": "source-bound sampled token rows are present"},
    {"requirement_id": "v61ad-kv-weight-budget-input", "status": "pass", "actual": str(len(kv_rows)), "required": "185", "reason": "KV+weight sampled budget rows are present"},
    {"requirement_id": "v61ar-remote-hash-result-input", "status": "pass", "actual": v61ar_summary["v61ar_moe_remote_hash_result_intake_ready"], "required": "1", "reason": "remote-hash result intake boundary is bound"},
    {"requirement_id": "sampled-hotset-reuse", "status": "pass" if sampled_hotset_reuse_ready else "blocked", "actual": str(cache_hit_rows), "required": "133", "reason": "scheduled reads collapse to unique hotset page cold fills plus cache hits"},
    {"requirement_id": "full-moe-remote-hash-coverage", "status": "pass" if full_moe_coverage_remote_hash_ready else "blocked", "actual": v61ar_summary["verified_remote_hash_rows"], "required": v61ar_summary["required_moe_remote_hash_rows"], "reason": "default v61ar has no supplied hash result rows"},
    {"requirement_id": "remote-hash-result-artifacts", "status": "pass" if remote_hash_result_intake_ready else "blocked", "actual": v61ar_summary["accepted_remote_hash_result_rows"], "required": v61ar_summary["expected_remote_hash_result_rows"], "reason": "hash-only result rows are final-deferred by default"},
    {"requirement_id": "full-runtime-hotset-reuse-admission", "status": "pass" if full_runtime_hotset_reuse_admission_ready else "blocked", "actual": "0", "required": "1", "reason": "sampled reuse is ready but full MoE hash/page coverage is not"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61as emits derived cache-reuse rows only"},
]
write_csv(run_dir / "hotset_reuse_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61as_hotset_reuse_admission_metrics",
    "model_id": model_id,
    "v61ac_hotset_token_budget_replay_ready": v61ac_summary["v61ac_hotset_token_budget_replay_ready"],
    "v61ad_kv_weight_token_budget_replay_ready": v61ad_summary["v61ad_kv_weight_token_budget_replay_ready"],
    "v61ar_moe_remote_hash_result_intake_ready": v61ar_summary["v61ar_moe_remote_hash_result_intake_ready"],
    "source_bound_token_budget_rows": str(source_bound_rows),
    "scheduled_hotset_page_read_rows": str(scheduled_rows),
    "unique_hotset_page_rows": str(unique_pages),
    "cache_miss_page_rows": str(cache_miss_rows),
    "cache_hit_page_rows": str(cache_hit_rows),
    "cache_hit_rate": fmt(hit_rate),
    "reuse_factor": fmt(reuse_factor),
    "page_bytes": str(page_bytes),
    "uncached_ssd_read_bytes_total": str(uncached_total_bytes),
    "persistent_hotset_cold_fill_bytes": str(cold_fill_total_bytes),
    "persistent_hotset_saved_bytes": str(saved_bytes),
    "uncached_ssd_read_bytes_per_token": str(uncached_per_token),
    "amortized_cold_fill_bytes_per_token": fmt(amortized_cold_fill_per_token),
    "amortized_saved_bytes_per_token": fmt(amortized_saved_per_token),
    "sampled_hotset_reuse_ready": str(sampled_hotset_reuse_ready),
    "remote_hash_result_intake_ready": v61ar_summary["remote_hash_result_intake_ready"],
    "full_moe_coverage_remote_hash_ready": v61ar_summary["full_moe_coverage_remote_hash_ready"],
    "full_runtime_hotset_reuse_admission_ready": str(full_runtime_hotset_reuse_admission_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61as": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "hotset_reuse_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61ac-hotset-token-budget-input", "ready", "37 sampled source-bound token rows are bound"),
    ("v61ad-kv-weight-budget-input", "ready", "185 KV+weight budget rows are bound"),
    ("sampled-hotset-reuse", "ready" if sampled_hotset_reuse_ready else "blocked", f"{cache_hit_rows}/{scheduled_rows} scheduled page reads become cache hits after {unique_pages} cold fills"),
    ("full-moe-remote-hash-coverage", "blocked", f"{v61ar_summary['verified_remote_hash_rows']}/{v61ar_summary['required_moe_remote_hash_rows']} representative cells hash-verified"),
    ("remote-hash-result-artifacts", "blocked", f"{v61ar_summary['accepted_remote_hash_result_rows']}/{v61ar_summary['expected_remote_hash_result_rows']} supplied result rows accepted"),
    ("full-safetensors-page-hash-binding", "blocked", "full checkpoint page-hash coverage remains incomplete"),
    ("real-model-generation", "blocked", "hotset reuse admission does not execute Mixtral generation"),
    ("production-latency", "blocked", "reuse admission is not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61as_hotset_reuse_admission_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ac-hotset-token-budget-input", "status": "pass", "reason": "token budget replay is bound"},
    {"gate": "v61ad-kv-weight-budget-input", "status": "pass", "reason": "KV+weight budget replay is bound"},
    {"gate": "v61ar-remote-hash-result-input", "status": "pass", "reason": "remote hash result intake boundary is bound"},
    {"gate": "sampled-hotset-reuse", "status": "pass" if sampled_hotset_reuse_ready else "blocked", "reason": f"cache_hit_page_rows={cache_hit_rows}/{scheduled_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "derived rows only"},
    {"gate": "full-moe-remote-hash-coverage", "status": "blocked", "reason": f"verified_remote_hash_rows={v61ar_summary['verified_remote_hash_rows']}/{v61ar_summary['required_moe_remote_hash_rows']}"},
    {"gate": "remote-hash-result-artifacts", "status": "blocked", "reason": f"accepted_remote_hash_result_rows={v61ar_summary['accepted_remote_hash_result_rows']}/{v61ar_summary['expected_remote_hash_result_rows']}"},
    {"gate": "full-runtime-hotset-reuse-admission", "status": "blocked", "reason": "sampled reuse is ready but full MoE/page-hash coverage is not"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61as Hotset Reuse Admission Gate Boundary

This artifact turns the sampled v61ac/v61ad token-budget rows into an explicit
persistent-hotset reuse admission ledger. It shows the sampled workload can reuse
15 hash-matched MoE pages across 148 scheduled page touches, but it does not
promote full MoE coverage, full page-hash coverage, or real generation.

Evidence emitted:

- source_bound_token_budget_rows={source_bound_rows}
- scheduled_hotset_page_read_rows={scheduled_rows}
- unique_hotset_page_rows={unique_pages}
- cache_miss_page_rows={cache_miss_rows}
- cache_hit_page_rows={cache_hit_rows}
- cache_hit_rate={fmt(hit_rate)}
- reuse_factor={fmt(reuse_factor)}
- uncached_ssd_read_bytes_total={uncached_total_bytes}
- persistent_hotset_cold_fill_bytes={cold_fill_total_bytes}
- persistent_hotset_saved_bytes={saved_bytes}
- uncached_ssd_read_bytes_per_token={uncached_per_token}
- amortized_cold_fill_bytes_per_token={fmt(amortized_cold_fill_per_token)}
- sampled_hotset_reuse_ready={sampled_hotset_reuse_ready}
- remote_hash_result_intake_ready={v61ar_summary['remote_hash_result_intake_ready']}
- full_moe_coverage_remote_hash_ready={v61ar_summary['full_moe_coverage_remote_hash_ready']}
- full_runtime_hotset_reuse_admission_ready={full_runtime_hotset_reuse_admission_ready}
- checkpoint_payload_bytes_downloaded_by_v61as=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: sampled persistent-hotset reuse admission over source-bound
token budget rows.
Blocked wording: full MoE remote-hash coverage, full safetensors page-hash
coverage, full runtime hotset admission, real Mixtral generation, production
latency, or release readiness.
"""
(run_dir / "V61AS_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61as_hotset_reuse_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61as_hotset_reuse_admission_gate_ready": 1,
    "source_v61ac_summary_sha256": sha256(results / "v61ac_hotset_token_budget_replay_summary.csv"),
    "source_v61ad_summary_sha256": sha256(results / "v61ad_kv_weight_token_budget_replay_summary.csv"),
    "source_v61ar_summary_sha256": sha256(results / "v61ar_moe_remote_hash_result_intake_summary.csv"),
    "source_bound_token_budget_rows": source_bound_rows,
    "scheduled_hotset_page_read_rows": scheduled_rows,
    "unique_hotset_page_rows": unique_pages,
    "cache_miss_page_rows": cache_miss_rows,
    "cache_hit_page_rows": cache_hit_rows,
    "cache_hit_rate": hit_rate,
    "reuse_factor": reuse_factor,
    "uncached_ssd_read_bytes_total": uncached_total_bytes,
    "persistent_hotset_cold_fill_bytes": cold_fill_total_bytes,
    "persistent_hotset_saved_bytes": saved_bytes,
    "sampled_hotset_reuse_ready": sampled_hotset_reuse_ready,
    "full_runtime_hotset_reuse_admission_ready": full_runtime_hotset_reuse_admission_ready,
    "checkpoint_payload_bytes_downloaded_by_v61as": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61as_hotset_reuse_admission_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61as_hotset_reuse_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
