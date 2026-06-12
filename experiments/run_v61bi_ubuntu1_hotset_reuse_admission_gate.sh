#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bi_ubuntu1_hotset_reuse_admission_gate"
RUN_ID="${V61BI_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bi_ubuntu1_hotset_reuse_admission_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bg_ubuntu1_token_budget_replay.sh" >/dev/null
V61BH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bh_ubuntu1_kv_weight_token_budget_replay.sh" >/dev/null
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


v61bg_dir = results / "v61bg_ubuntu1_token_budget_replay" / "replay_001"
v61bh_dir = results / "v61bh_ubuntu1_kv_weight_token_budget_replay" / "replay_001"
v61ar_dir = results / "v61ar_moe_remote_hash_result_intake" / "intake_001"

v61bg_summary = read_csv(results / "v61bg_ubuntu1_token_budget_replay_summary.csv")[0]
v61bh_summary = read_csv(results / "v61bh_ubuntu1_kv_weight_token_budget_replay_summary.csv")[0]
v61ar_summary = read_csv(results / "v61ar_moe_remote_hash_result_intake_summary.csv")[0]
if v61bg_summary.get("v61bg_ubuntu1_token_budget_replay_ready") != "1":
    raise SystemExit("v61bi requires v61bg_ubuntu1_token_budget_replay_ready=1")
if v61bh_summary.get("v61bh_ubuntu1_kv_weight_token_budget_replay_ready") != "1":
    raise SystemExit("v61bi requires v61bh_ubuntu1_kv_weight_token_budget_replay_ready=1")
if v61ar_summary.get("v61ar_moe_remote_hash_result_intake_ready") != "1":
    raise SystemExit("v61bi requires v61ar_moe_remote_hash_result_intake_ready=1")

selected_target_path = v61bg_summary["selected_target_path"]
ubuntu1_hotset_root = v61bg_summary["ubuntu1_hotset_root"]

for src, rel in [
    (results / "v61bg_ubuntu1_token_budget_replay_summary.csv", "source_v61bg/v61bg_ubuntu1_token_budget_replay_summary.csv"),
    (results / "v61bg_ubuntu1_token_budget_replay_decision.csv", "source_v61bg/v61bg_ubuntu1_token_budget_replay_decision.csv"),
    (v61bg_dir / "ubuntu1_token_budget_rows.csv", "source_v61bg/ubuntu1_token_budget_rows.csv"),
    (v61bg_dir / "ubuntu1_token_budget_page_schedule_rows.csv", "source_v61bg/ubuntu1_token_budget_page_schedule_rows.csv"),
    (v61bg_dir / "ubuntu1_token_budget_metric_rows.csv", "source_v61bg/ubuntu1_token_budget_metric_rows.csv"),
    (v61bg_dir / "sha256_manifest.csv", "source_v61bg/sha256_manifest.csv"),
    (results / "v61bh_ubuntu1_kv_weight_token_budget_replay_summary.csv", "source_v61bh/v61bh_ubuntu1_kv_weight_token_budget_replay_summary.csv"),
    (results / "v61bh_ubuntu1_kv_weight_token_budget_replay_decision.csv", "source_v61bh/v61bh_ubuntu1_kv_weight_token_budget_replay_decision.csv"),
    (v61bh_dir / "kv_weight_token_budget_rows.csv", "source_v61bh/kv_weight_token_budget_rows.csv"),
    (v61bh_dir / "kv_weight_token_budget_metric_rows.csv", "source_v61bh/kv_weight_token_budget_metric_rows.csv"),
    (v61bh_dir / "sha256_manifest.csv", "source_v61bh/sha256_manifest.csv"),
    (results / "v61ar_moe_remote_hash_result_intake_summary.csv", "source_v61ar/v61ar_moe_remote_hash_result_intake_summary.csv"),
    (results / "v61ar_moe_remote_hash_result_intake_decision.csv", "source_v61ar/v61ar_moe_remote_hash_result_intake_decision.csv"),
    (v61ar_dir / "moe_remote_hash_combined_coverage_rows.csv", "source_v61ar/moe_remote_hash_combined_coverage_rows.csv"),
    (v61ar_dir / "moe_remote_hash_result_metric_rows.csv", "source_v61ar/moe_remote_hash_result_metric_rows.csv"),
    (v61ar_dir / "sha256_manifest.csv", "source_v61ar/sha256_manifest.csv"),
]:
    copy(src, rel)

token_rows = read_csv(v61bg_dir / "ubuntu1_token_budget_rows.csv")
schedule_rows = read_csv(v61bg_dir / "ubuntu1_token_budget_page_schedule_rows.csv")
kv_rows = read_csv(v61bh_dir / "kv_weight_token_budget_rows.csv")
coverage_rows = read_csv(v61ar_dir / "moe_remote_hash_combined_coverage_rows.csv")
if len(token_rows) != 37:
    raise SystemExit("v61bi expects 37 ubuntu-1 token rows")
if len(schedule_rows) != 148:
    raise SystemExit("v61bi expects 148 scheduled ubuntu-1 page rows")
if len(kv_rows) != 185:
    raise SystemExit("v61bi expects 185 ubuntu-1 KV+weight rows")
if len(coverage_rows) != 1344:
    raise SystemExit("v61bi expects 1344 MoE hash coverage rows")
for row in schedule_rows:
    if row["direct_read_hash_match"] != "1" or row["direct_io_used"] != "1":
        raise SystemExit("v61bi requires every scheduled ubuntu-1 page read to use direct I/O and hash-match")
    if int(row["bytes_read"]) != page_bytes:
        raise SystemExit("v61bi requires every scheduled page read to be one 2 MiB page")
    if not row["ubuntu1_page_path"].startswith(ubuntu1_hotset_root + "/"):
        raise SystemExit("v61bi requires scheduled pages under the ubuntu-1 hotset root")

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
        row["workload_binding_id"],
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
uncached_per_token = int(v61bg_summary["ssd_read_bytes_per_token"])
amortized_cold_fill_per_token = cold_fill_total_bytes / source_bound_rows
amortized_saved_per_token = uncached_per_token - amortized_cold_fill_per_token
hit_rate = cache_hit_rows / scheduled_rows
reuse_factor = scheduled_rows / unique_pages

page_rows = []
for index, (remote_sample_id, row) in enumerate(page_first.items()):
    scheduled_count = page_counts[remote_sample_id]
    page_rows.append(
        {
            "ubuntu1_reuse_page_id": f"v61bi_ubuntu1_hotset_reuse_page_{index:04d}",
            "remote_sample_id": remote_sample_id,
            "runtime_node_id": row["runtime_node_id"],
            "tensor_role": row["tensor_role"],
            "layer_index": row["layer_index"],
            "expert_index": row["expert_index"],
            "first_schedule_id": row["schedule_id"],
            "first_query_id": row["query_id"],
            "ubuntu1_page_path": row["ubuntu1_page_path"],
            "scheduled_page_read_rows": str(scheduled_count),
            "cache_miss_page_rows": "1",
            "cache_hit_page_rows": str(scheduled_count - 1),
            "page_bytes": str(page_bytes),
            "uncached_read_bytes": str(scheduled_count * page_bytes),
            "persistent_hotset_cold_fill_bytes": str(page_bytes),
            "persistent_hotset_saved_bytes": str((scheduled_count - 1) * page_bytes),
            "direct_io_used": row["direct_io_used"],
            "direct_read_hash_match": row["direct_read_hash_match"],
            "ubuntu1_hotset_page_reuse_ready": "1",
            "checkpoint_payload_bytes_downloaded_by_v61bi": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "ubuntu1_hotset_reuse_page_rows.csv", list(page_rows[0].keys()), page_rows)

token_by_workload = {row["workload_binding_id"]: row for row in token_rows}
token_reuse_rows = []
for index, token in enumerate(token_state.values()):
    source = token_by_workload[token["workload_binding_id"]]
    miss_bytes = token["cache_miss_page_rows"] * page_bytes
    hit_bytes_saved = token["cache_hit_page_rows"] * page_bytes
    token_reuse_rows.append(
        {
            "ubuntu1_reuse_token_id": f"v61bi_ubuntu1_hotset_reuse_token_{index:04d}",
            "ubuntu1_token_budget_id": source["ubuntu1_token_budget_id"],
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
            "ubuntu1_token_reuse_ready": "1",
            "checkpoint_payload_bytes_downloaded_by_v61bi": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
            "actual_model_generation_ready": "0",
            "production_latency_claim_ready": "0",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "ubuntu1_hotset_reuse_token_rows.csv", list(token_reuse_rows[0].keys()), token_reuse_rows)

window_rows = [
    {
        "ubuntu1_reuse_window_id": "v61bi_ubuntu1_source_bound_37_query_window",
        "selected_target_path": selected_target_path,
        "ubuntu1_hotset_root": ubuntu1_hotset_root,
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
        "ubuntu1_sampled_hotset_reuse_ready": "1",
    }
]
write_csv(run_dir / "ubuntu1_hotset_reuse_window_rows.csv", list(window_rows[0].keys()), window_rows)

ubuntu1_sampled_hotset_reuse_ready = int(
    source_bound_rows == 37
    and scheduled_rows == 148
    and unique_pages == 15
    and cache_hit_rows == 133
    and cache_miss_rows == 15
    and all(row["ubuntu1_token_reuse_ready"] == "1" for row in token_reuse_rows)
)
full_moe_coverage_remote_hash_ready = int(v61ar_summary["full_moe_coverage_remote_hash_ready"])
remote_hash_result_intake_ready = int(v61ar_summary["remote_hash_result_intake_ready"])
full_runtime_ubuntu1_hotset_reuse_admission_ready = int(
    ubuntu1_sampled_hotset_reuse_ready
    and full_moe_coverage_remote_hash_ready
    and remote_hash_result_intake_ready
    and v61bh_summary["full_safetensors_page_hash_binding_ready"] == "1"
)

requirement_rows = [
    {"requirement_id": "v61bg-ubuntu1-token-budget-input", "status": "pass", "actual": str(source_bound_rows), "required": "37", "reason": "source-bound ubuntu-1 token rows are present"},
    {"requirement_id": "v61bh-ubuntu1-kv-weight-budget-input", "status": "pass", "actual": str(len(kv_rows)), "required": "185", "reason": "ubuntu-1 KV+weight sampled budget rows are present"},
    {"requirement_id": "v61ar-remote-hash-result-input", "status": "pass", "actual": v61ar_summary["v61ar_moe_remote_hash_result_intake_ready"], "required": "1", "reason": "remote-hash result intake boundary is bound"},
    {"requirement_id": "ubuntu1-sampled-hotset-reuse", "status": "pass" if ubuntu1_sampled_hotset_reuse_ready else "blocked", "actual": str(cache_hit_rows), "required": "133", "reason": "ubuntu-1 scheduled reads collapse to unique hotset cold fills plus cache hits"},
    {"requirement_id": "full-moe-remote-hash-coverage", "status": "pass" if full_moe_coverage_remote_hash_ready else "blocked", "actual": v61ar_summary["verified_remote_hash_rows"], "required": v61ar_summary["required_moe_remote_hash_rows"], "reason": "default v61ar has no supplied hash result rows"},
    {"requirement_id": "remote-hash-result-artifacts", "status": "pass" if remote_hash_result_intake_ready else "blocked", "actual": v61ar_summary["accepted_remote_hash_result_rows"], "required": v61ar_summary["expected_remote_hash_result_rows"], "reason": "hash-only result rows are final-deferred by default"},
    {"requirement_id": "full-runtime-ubuntu1-hotset-reuse-admission", "status": "pass" if full_runtime_ubuntu1_hotset_reuse_admission_ready else "blocked", "actual": "0", "required": "1", "reason": "sampled ubuntu-1 reuse is ready but full MoE hash/page coverage is not"},
    {"requirement_id": "no-network-download-by-v61bi", "status": "pass", "actual": "0", "required": "0", "reason": "v61bi emits derived cache-reuse rows only"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "checkpoint payload bytes stay outside the repository"},
]
write_csv(run_dir / "ubuntu1_hotset_reuse_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bi_ubuntu1_hotset_reuse_admission_metrics",
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
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
    "ubuntu1_token_direct_io_latency_ms_p50": v61bg_summary["ubuntu1_token_direct_io_latency_ms_p50"],
    "ubuntu1_token_direct_io_latency_ms_p95": v61bg_summary["ubuntu1_token_direct_io_latency_ms_p95"],
    "weight_plus_new_kv_bytes_per_token": v61bh_summary["weight_plus_new_kv_bytes_per_token"],
    "host_ram_spill_bytes_total": v61bh_summary["host_ram_spill_bytes_total"],
    "ubuntu1_sampled_hotset_reuse_ready": str(ubuntu1_sampled_hotset_reuse_ready),
    "remote_hash_result_intake_ready": str(remote_hash_result_intake_ready),
    "full_moe_coverage_remote_hash_ready": str(full_moe_coverage_remote_hash_ready),
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": str(full_runtime_ubuntu1_hotset_reuse_admission_ready),
    "full_safetensors_page_hash_binding_ready": v61bh_summary["full_safetensors_page_hash_binding_ready"],
    "checkpoint_payload_bytes_downloaded_by_v61bi": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_hotset_reuse_metric_rows.csv", list(metric.keys()), [metric])

runtime_gap_rows = [
    {"gap": "v61bg-ubuntu1-token-budget-input", "status": "ready", "evidence": "37 ubuntu-1 source-bound token rows are ready"},
    {"gap": "v61bh-ubuntu1-kv-weight-budget-input", "status": "ready", "evidence": "185 ubuntu-1 KV+weight token budget rows are ready"},
    {"gap": "ubuntu1-sampled-hotset-reuse", "status": "ready" if ubuntu1_sampled_hotset_reuse_ready else "blocked", "evidence": f"{cache_hit_rows}/{scheduled_rows} scheduled ubuntu-1 page reads are cache hits after {cache_miss_rows} cold fills"},
    {"gap": "full-moe-remote-hash-coverage", "status": "ready" if full_moe_coverage_remote_hash_ready else "blocked", "evidence": f"{v61ar_summary['verified_remote_hash_rows']}/{v61ar_summary['required_moe_remote_hash_rows']} MoE remote hashes are verified"},
    {"gap": "remote-hash-result-artifacts", "status": "ready" if remote_hash_result_intake_ready else "blocked", "evidence": f"{v61ar_summary['accepted_remote_hash_result_rows']}/{v61ar_summary['expected_remote_hash_result_rows']} supplied remote-hash rows accepted"},
    {"gap": "full-safetensors-page-hash-binding", "status": "blocked", "evidence": "full checkpoint page-hash coverage remains incomplete"},
    {"gap": "real-model-generation", "status": "blocked", "evidence": "reuse admission does not execute Mixtral generation"},
    {"gap": "production-latency", "status": "blocked", "evidence": "sampled reuse admission is not production-latency evidence"},
    {"gap": "release-package", "status": "blocked", "evidence": "release requires full materialization, generation, and review"},
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "evidence"], runtime_gap_rows)

decision_rows = [
    {"gate": "v61bg-ubuntu1-token-budget-input", "status": "pass", "reason": "source-bound ubuntu-1 token-budget replay is ready"},
    {"gate": "v61bh-ubuntu1-kv-weight-budget-input", "status": "pass", "reason": "ubuntu-1 KV+weight budget replay is ready"},
    {"gate": "v61ar-remote-hash-result-input", "status": "pass", "reason": "remote-hash result intake boundary is bound"},
    {"gate": "ubuntu1-sampled-hotset-reuse", "status": "pass" if ubuntu1_sampled_hotset_reuse_ready else "blocked", "reason": f"{cache_hit_rows} cache hits after {cache_miss_rows} cold fills"},
    {"gate": "no-network-download-by-v61bi", "status": "pass", "reason": "derived rows only; no checkpoint download executed by v61bi"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes remain outside the repository"},
    {"gate": "full-moe-remote-hash-coverage", "status": "blocked", "reason": "full MoE remote hash coverage remains incomplete"},
    {"gate": "remote-hash-result-artifacts", "status": "blocked", "reason": "no supplied hash-only result rows are accepted by default"},
    {"gate": "full-runtime-ubuntu1-hotset-reuse-admission", "status": "blocked", "reason": "sampled reuse is ready but full hash/page coverage is not"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "sampled reuse admission is not production-latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "release requires full materialization, generation, and review"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

summary = {
    "v61bi_ubuntu1_hotset_reuse_admission_gate_ready": str(ubuntu1_sampled_hotset_reuse_ready),
    "v61bg_ubuntu1_token_budget_replay_ready": v61bg_summary["v61bg_ubuntu1_token_budget_replay_ready"],
    "v61bh_ubuntu1_kv_weight_token_budget_replay_ready": v61bh_summary["v61bh_ubuntu1_kv_weight_token_budget_replay_ready"],
    "v61ar_moe_remote_hash_result_intake_ready": v61ar_summary["v61ar_moe_remote_hash_result_intake_ready"],
    "model_id": model_id,
    **{key: metric[key] for key in [
        "selected_target_path",
        "ubuntu1_hotset_root",
        "source_bound_token_budget_rows",
        "scheduled_hotset_page_read_rows",
        "unique_hotset_page_rows",
        "cache_miss_page_rows",
        "cache_hit_page_rows",
        "cache_hit_rate",
        "reuse_factor",
        "page_bytes",
        "uncached_ssd_read_bytes_total",
        "persistent_hotset_cold_fill_bytes",
        "persistent_hotset_saved_bytes",
        "uncached_ssd_read_bytes_per_token",
        "amortized_cold_fill_bytes_per_token",
        "amortized_saved_bytes_per_token",
        "ubuntu1_token_direct_io_latency_ms_p50",
        "ubuntu1_token_direct_io_latency_ms_p95",
        "weight_plus_new_kv_bytes_per_token",
        "host_ram_spill_bytes_total",
        "ubuntu1_sampled_hotset_reuse_ready",
        "remote_hash_result_intake_ready",
        "full_moe_coverage_remote_hash_ready",
        "full_runtime_ubuntu1_hotset_reuse_admission_ready",
        "full_safetensors_page_hash_binding_ready",
        "checkpoint_payload_bytes_downloaded_by_v61bi",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "near_frontier_claim_ready",
        "production_latency_claim_ready",
        "real_release_package_ready",
        "route_jump_rows",
    ]},
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "artifact": "v61bi_ubuntu1_hotset_reuse_admission_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "run_dir": str(run_dir),
    "selected_target_path": selected_target_path,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "v61bi_ubuntu1_hotset_reuse_admission_gate_ready": ubuntu1_sampled_hotset_reuse_ready,
    "source_bound_token_budget_rows": source_bound_rows,
    "scheduled_hotset_page_read_rows": scheduled_rows,
    "unique_hotset_page_rows": unique_pages,
    "cache_hit_page_rows": cache_hit_rows,
    "persistent_hotset_cold_fill_bytes": cold_fill_total_bytes,
    "persistent_hotset_saved_bytes": saved_bytes,
    "checkpoint_payload_bytes_downloaded_by_v61bi": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": full_runtime_ubuntu1_hotset_reuse_admission_ready,
    "actual_model_generation_ready": 0,
    "blocked_claims": [
        "full_moe_remote_hash_coverage",
        "remote_hash_result_artifacts",
        "full_safetensors_page_hash_binding",
        "real_model_generation",
        "production_latency",
        "release_package",
    ],
}
(run_dir / "v61bi_ubuntu1_hotset_reuse_admission_gate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

boundary = f"""# v61bi Ubuntu-1 Hotset Reuse Admission Gate Boundary

This artifact binds v61bg ubuntu-1 source-bound token schedules and v61bh
ubuntu-1 KV+weight budget rows to a persistent-hotset reuse ledger. It verifies
that the bounded ubuntu-1 sampled hotset collapses repeated source-bound page
reads into cold fills plus cache hits. It does not execute full checkpoint
payload activation, full page-hash coverage, or Mixtral generation.

Evidence emitted:

- selected_target_path={selected_target_path}
- ubuntu1_hotset_root={ubuntu1_hotset_root}
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
- amortized_saved_bytes_per_token={fmt(amortized_saved_per_token)}
- ubuntu1_sampled_hotset_reuse_ready={ubuntu1_sampled_hotset_reuse_ready}
- full_runtime_ubuntu1_hotset_reuse_admission_ready={full_runtime_ubuntu1_hotset_reuse_admission_ready}
- checkpoint_payload_bytes_downloaded_by_v61bi=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

- full_moe_remote_hash_coverage=blocked
- remote_hash_result_artifacts=blocked
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- production_latency_claim_ready=0
- near_frontier_claim_ready=0
- real_release_package_ready=0

This is sampled ubuntu-1 hotset reuse evidence over bounded resident checkpoint
pages. It is not full checkpoint materialization, full page-hash coverage,
real Mixtral generation, production-latency evidence, or release evidence.
"""
(run_dir / "V61BI_UBUNTU1_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bi_ubuntu1_hotset_reuse_admission_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
