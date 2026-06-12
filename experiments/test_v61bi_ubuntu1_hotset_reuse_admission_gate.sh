#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61bi_ubuntu1_hotset_reuse_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61bi_ubuntu1_hotset_reuse_admission_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61bi_ubuntu1_hotset_reuse_admission_gate_decision.csv"

V61BI_REUSE_EXISTING="${V61BI_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61bi_ubuntu1_hotset_reuse_admission_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
ubuntu1_target = "/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse"
ubuntu1_hotset_root = ubuntu1_target + "/.v61_sampled_hotset_pages"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
source_v61bg_summary = read_csv(run_dir / "source_v61bg" / "v61bg_ubuntu1_token_budget_replay_summary.csv")[0]
source_v61bh_summary = read_csv(run_dir / "source_v61bh" / "v61bh_ubuntu1_kv_weight_token_budget_replay_summary.csv")[0]
expected = {
    "v61bi_ubuntu1_hotset_reuse_admission_gate_ready": "1",
    "v61bg_ubuntu1_token_budget_replay_ready": "1",
    "v61bh_ubuntu1_kv_weight_token_budget_replay_ready": "1",
    "v61ar_moe_remote_hash_result_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "selected_target_path": ubuntu1_target,
    "ubuntu1_hotset_root": ubuntu1_hotset_root,
    "source_bound_token_budget_rows": "37",
    "scheduled_hotset_page_read_rows": "148",
    "unique_hotset_page_rows": "15",
    "cache_miss_page_rows": "15",
    "cache_hit_page_rows": "133",
    "cache_hit_rate": "0.898648649",
    "reuse_factor": "9.866666667",
    "page_bytes": "2097152",
    "uncached_ssd_read_bytes_total": "310378496",
    "persistent_hotset_cold_fill_bytes": "31457280",
    "persistent_hotset_saved_bytes": "278921216",
    "uncached_ssd_read_bytes_per_token": "8388608",
    "amortized_cold_fill_bytes_per_token": "850196.756756757",
    "amortized_saved_bytes_per_token": "7538411.243243244",
    "ubuntu1_token_direct_io_latency_ms_p50": source_v61bg_summary["ubuntu1_token_direct_io_latency_ms_p50"],
    "ubuntu1_token_direct_io_latency_ms_p95": source_v61bg_summary["ubuntu1_token_direct_io_latency_ms_p95"],
    "weight_plus_new_kv_bytes_per_token": source_v61bh_summary["weight_plus_new_kv_bytes_per_token"],
    "host_ram_spill_bytes_total": "0",
    "ubuntu1_sampled_hotset_reuse_ready": "1",
    "remote_hash_result_intake_ready": "0",
    "full_moe_coverage_remote_hash_ready": "0",
    "full_runtime_ubuntu1_hotset_reuse_admission_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bi": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61bi {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "ubuntu1_hotset_reuse_page_rows.csv",
    "ubuntu1_hotset_reuse_token_rows.csv",
    "ubuntu1_hotset_reuse_window_rows.csv",
    "ubuntu1_hotset_reuse_requirement_rows.csv",
    "ubuntu1_hotset_reuse_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61BI_UBUNTU1_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md",
    "v61bi_ubuntu1_hotset_reuse_admission_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61bg/ubuntu1_token_budget_page_schedule_rows.csv",
    "source_v61bh/kv_weight_token_budget_rows.csv",
    "source_v61ar/moe_remote_hash_combined_coverage_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61bi artifact: {rel}")

page_rows = read_csv(run_dir / "ubuntu1_hotset_reuse_page_rows.csv")
token_rows = read_csv(run_dir / "ubuntu1_hotset_reuse_token_rows.csv")
window_rows = read_csv(run_dir / "ubuntu1_hotset_reuse_window_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "ubuntu1_hotset_reuse_requirement_rows.csv")}
metric = read_csv(run_dir / "ubuntu1_hotset_reuse_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(page_rows) != 15 or len(token_rows) != 37 or len(window_rows) != 1:
    raise SystemExit("v61bi row count mismatch")
if sum(int(row["scheduled_page_read_rows"]) for row in page_rows) != 148:
    raise SystemExit("v61bi page rows should cover 148 scheduled reads")
if sum(int(row["cache_miss_page_rows"]) for row in page_rows) != 15:
    raise SystemExit("v61bi page rows should record 15 cold fills")
if sum(int(row["cache_hit_page_rows"]) for row in page_rows) != 133:
    raise SystemExit("v61bi page rows should record 133 cache hits")
if min(int(row["scheduled_page_read_rows"]) for row in page_rows) < 8:
    raise SystemExit("v61bi every reused page should be touched at least 8 times")
if max(int(row["scheduled_page_read_rows"]) for row in page_rows) > 12:
    raise SystemExit("v61bi reused page touch count should be bounded by the replay window")
if any(not row["ubuntu1_page_path"].startswith(ubuntu1_hotset_root + "/") for row in page_rows):
    raise SystemExit("v61bi page rows must point under the ubuntu-1 hotset root")
if any(row["direct_io_used"] != "1" or row["direct_read_hash_match"] != "1" for row in page_rows):
    raise SystemExit("v61bi page rows must be direct-I/O hash-matched")
if any(row["ubuntu1_hotset_page_reuse_ready"] != "1" for row in page_rows):
    raise SystemExit("v61bi page reuse rows should be ready")
if any(row["checkpoint_payload_bytes_downloaded_by_v61bi"] != "0" for row in page_rows + token_rows):
    raise SystemExit("v61bi must not download checkpoint payload")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in page_rows + token_rows):
    raise SystemExit("v61bi must not commit checkpoint payload")
if any(row["actual_model_generation_ready"] != "0" for row in page_rows + token_rows):
    raise SystemExit("v61bi must keep generation blocked")

if sum(int(row["scheduled_page_rows"]) for row in token_rows) != 148:
    raise SystemExit("v61bi token rows should cover all scheduled rows")
if sum(int(row["cache_miss_page_rows"]) for row in token_rows) != 15:
    raise SystemExit("v61bi token rows should record 15 misses")
if sum(int(row["cache_hit_page_rows"]) for row in token_rows) != 133:
    raise SystemExit("v61bi token rows should record 133 hits")
if token_rows[0]["cache_miss_page_rows"] != "4" or token_rows[0]["cache_hit_page_rows"] != "0":
    raise SystemExit("v61bi first token should cold-fill four pages")
if any(row["ubuntu1_token_reuse_ready"] != "1" for row in token_rows):
    raise SystemExit("v61bi token reuse rows should be ready")

for field, value in expected.items():
    if field.startswith("v61bi_") or field.startswith("v61bg_") or field.startswith("v61bh_") or field.startswith("v61ar_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61bi metric {field}: expected {value}, got {metric[field]}")
for field, value in expected.items():
    if field in window_rows[0] and window_rows[0][field] != value:
        raise SystemExit(f"v61bi window {field}: expected {value}, got {window_rows[0][field]}")

for requirement_id in [
    "v61bg-ubuntu1-token-budget-input",
    "v61bh-ubuntu1-kv-weight-budget-input",
    "v61ar-remote-hash-result-input",
    "ubuntu1-sampled-hotset-reuse",
    "no-network-download-by-v61bi",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61bi requirement should pass: {requirement_id}")
for requirement_id in [
    "full-moe-remote-hash-coverage",
    "remote-hash-result-artifacts",
    "full-runtime-ubuntu1-hotset-reuse-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61bi requirement should remain blocked: {requirement_id}")

for gate in [
    "v61bg-ubuntu1-token-budget-input",
    "v61bh-ubuntu1-kv-weight-budget-input",
    "v61ar-remote-hash-result-input",
    "ubuntu1-sampled-hotset-reuse",
    "no-network-download-by-v61bi",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61bi gate should pass: {gate}")
for gate in [
    "full-moe-remote-hash-coverage",
    "remote-hash-result-artifacts",
    "full-runtime-ubuntu1-hotset-reuse-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61bi gate should remain blocked: {gate}")

for gap in [
    "v61bg-ubuntu1-token-budget-input",
    "v61bh-ubuntu1-kv-weight-budget-input",
    "ubuntu1-sampled-hotset-reuse",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61bi gap should be ready: {gap}")
for gap in [
    "full-moe-remote-hash-coverage",
    "remote-hash-result-artifacts",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61bi gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61bi_ubuntu1_hotset_reuse_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61bi_ubuntu1_hotset_reuse_admission_gate_ready") != 1:
    raise SystemExit("v61bi manifest readiness mismatch")
if manifest.get("cache_hit_page_rows") != 133 or manifest.get("unique_hotset_page_rows") != 15:
    raise SystemExit("v61bi manifest reuse count mismatch")
if manifest.get("full_runtime_ubuntu1_hotset_reuse_admission_ready") != 0:
    raise SystemExit("v61bi manifest should keep full runtime admission blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61bi") != 0:
    raise SystemExit("v61bi manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61BI_UBUNTU1_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "scheduled_hotset_page_read_rows=148",
    "unique_hotset_page_rows=15",
    "cache_miss_page_rows=15",
    "cache_hit_page_rows=133",
    "persistent_hotset_cold_fill_bytes=31457280",
    "persistent_hotset_saved_bytes=278921216",
    "ubuntu1_sampled_hotset_reuse_ready=1",
    "full_runtime_ubuntu1_hotset_reuse_admission_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61bi=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61bi boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61bi sha256 mismatch: {rel}")
PY

echo "v61bi ubuntu-1 hotset reuse admission gate smoke passed"
