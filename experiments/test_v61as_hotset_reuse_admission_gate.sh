#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61as_hotset_reuse_admission_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v61as_hotset_reuse_admission_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61as_hotset_reuse_admission_gate_decision.csv"

V61AS_REUSE_EXISTING="${V61AS_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61as_hotset_reuse_admission_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


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
expected = {
    "v61as_hotset_reuse_admission_gate_ready": "1",
    "v61ac_hotset_token_budget_replay_ready": "1",
    "v61ad_kv_weight_token_budget_replay_ready": "1",
    "v61ar_moe_remote_hash_result_intake_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
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
    "sampled_hotset_reuse_ready": "1",
    "remote_hash_result_intake_ready": "0",
    "full_moe_coverage_remote_hash_ready": "0",
    "full_runtime_hotset_reuse_admission_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61as": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61as {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "hotset_reuse_page_rows.csv",
    "hotset_reuse_token_rows.csv",
    "hotset_reuse_window_rows.csv",
    "hotset_reuse_requirement_rows.csv",
    "hotset_reuse_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AS_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md",
    "v61as_hotset_reuse_admission_gate_manifest.json",
    "sha256_manifest.csv",
    "source_v61ac/hotset_token_budget_page_schedule_rows.csv",
    "source_v61ad/kv_weight_token_budget_rows.csv",
    "source_v61ar/moe_remote_hash_combined_coverage_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61as artifact: {rel}")

page_rows = read_csv(run_dir / "hotset_reuse_page_rows.csv")
token_rows = read_csv(run_dir / "hotset_reuse_token_rows.csv")
window_rows = read_csv(run_dir / "hotset_reuse_window_rows.csv")
requirements = {row["requirement_id"]: row for row in read_csv(run_dir / "hotset_reuse_requirement_rows.csv")}
metric = read_csv(run_dir / "hotset_reuse_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}

if len(page_rows) != 15 or len(token_rows) != 37 or len(window_rows) != 1:
    raise SystemExit("v61as row count mismatch")
if sum(int(row["scheduled_page_read_rows"]) for row in page_rows) != 148:
    raise SystemExit("v61as page rows should cover 148 scheduled reads")
if sum(int(row["cache_miss_page_rows"]) for row in page_rows) != 15:
    raise SystemExit("v61as page rows should record 15 cold fills")
if sum(int(row["cache_hit_page_rows"]) for row in page_rows) != 133:
    raise SystemExit("v61as page rows should record 133 cache hits")
if min(int(row["scheduled_page_read_rows"]) for row in page_rows) < 8:
    raise SystemExit("v61as every reused page should be touched at least 8 times")
if max(int(row["scheduled_page_read_rows"]) for row in page_rows) > 12:
    raise SystemExit("v61as reused page touch count should be bounded by the replay window")
if any(row["direct_read_hash_match"] != "1" for row in page_rows):
    raise SystemExit("v61as page rows must be hash-matched")
if any(row["sampled_hotset_page_reuse_ready"] != "1" for row in page_rows):
    raise SystemExit("v61as page reuse rows should be ready")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in page_rows + token_rows):
    raise SystemExit("v61as must not commit checkpoint payload bytes")
if any(row["actual_model_generation_ready"] != "0" for row in page_rows + token_rows):
    raise SystemExit("v61as must keep generation blocked")

if sum(int(row["scheduled_page_rows"]) for row in token_rows) != 148:
    raise SystemExit("v61as token rows should cover all scheduled rows")
if sum(int(row["cache_miss_page_rows"]) for row in token_rows) != 15:
    raise SystemExit("v61as token rows should record 15 misses")
if sum(int(row["cache_hit_page_rows"]) for row in token_rows) != 133:
    raise SystemExit("v61as token rows should record 133 hits")
if token_rows[0]["cache_miss_page_rows"] != "4" or token_rows[0]["cache_hit_page_rows"] != "0":
    raise SystemExit("v61as first token should cold-fill four pages")
if any(row["token_reuse_ready"] != "1" for row in token_rows):
    raise SystemExit("v61as token reuse rows should be ready")

for field, value in expected.items():
    if field.startswith("v61as_") or field.startswith("v61ac_") or field.startswith("v61ad_") or field.startswith("v61ar_"):
        continue
    if field in metric and metric[field] != value:
        raise SystemExit(f"v61as metric {field}: expected {value}, got {metric[field]}")
for field, value in expected.items():
    if field in window_rows[0] and window_rows[0][field] != value:
        raise SystemExit(f"v61as window {field}: expected {value}, got {window_rows[0][field]}")

for requirement_id in [
    "v61ac-hotset-token-budget-input",
    "v61ad-kv-weight-budget-input",
    "v61ar-remote-hash-result-input",
    "sampled-hotset-reuse",
    "manifest-only-no-repo-payload",
]:
    if requirements[requirement_id]["status"] != "pass":
        raise SystemExit(f"v61as requirement should pass: {requirement_id}")
for requirement_id in [
    "full-moe-remote-hash-coverage",
    "remote-hash-result-artifacts",
    "full-runtime-hotset-reuse-admission",
]:
    if requirements[requirement_id]["status"] != "blocked":
        raise SystemExit(f"v61as requirement should remain blocked: {requirement_id}")

for gate in [
    "v61ac-hotset-token-budget-input",
    "v61ad-kv-weight-budget-input",
    "v61ar-remote-hash-result-input",
    "sampled-hotset-reuse",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61as gate should pass: {gate}")
for gate in [
    "full-moe-remote-hash-coverage",
    "remote-hash-result-artifacts",
    "full-runtime-hotset-reuse-admission",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61as gate should remain blocked: {gate}")

for gap in [
    "v61ac-hotset-token-budget-input",
    "v61ad-kv-weight-budget-input",
    "sampled-hotset-reuse",
]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61as gap should be ready: {gap}")
for gap in [
    "full-moe-remote-hash-coverage",
    "remote-hash-result-artifacts",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61as gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61as_hotset_reuse_admission_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61as_hotset_reuse_admission_gate_ready") != 1:
    raise SystemExit("v61as manifest readiness mismatch")
if manifest.get("cache_hit_page_rows") != 133 or manifest.get("unique_hotset_page_rows") != 15:
    raise SystemExit("v61as manifest reuse count mismatch")
if manifest.get("full_runtime_hotset_reuse_admission_ready") != 0:
    raise SystemExit("v61as manifest should keep full runtime admission blocked")
if manifest.get("checkpoint_payload_bytes_downloaded_by_v61as") != 0:
    raise SystemExit("v61as manifest must keep downloaded bytes at zero")

boundary = (run_dir / "V61AS_HOTSET_REUSE_ADMISSION_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "scheduled_hotset_page_read_rows=148",
    "unique_hotset_page_rows=15",
    "cache_miss_page_rows=15",
    "cache_hit_page_rows=133",
    "persistent_hotset_cold_fill_bytes=31457280",
    "persistent_hotset_saved_bytes=278921216",
    "sampled_hotset_reuse_ready=1",
    "full_runtime_hotset_reuse_admission_ready=0",
    "checkpoint_payload_bytes_downloaded_by_v61as=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61as boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61as sha256 mismatch: {rel}")
PY

echo "v61as hotset reuse admission gate smoke passed"
