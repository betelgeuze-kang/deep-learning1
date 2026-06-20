#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier/verify_001"
SUMMARY_CSV="$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv"
DECISION_CSV="$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_decision.csv"

V61AA_REUSE_EXISTING="${V61AA_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v61aa_hotset_tensor_slice_verifier.sh" >/dev/null

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
    "v61aa_hotset_tensor_slice_verifier_ready": "1",
    "v61z_hotset_direct_io_replay_ready": "1",
    "v61v_remote_page_tensor_binding_ready": "1",
    "model_id": "mistralai/Mixtral-8x22B-v0.1",
    "tensor_slice_rows": "16",
    "moe_tensor_slice_rows": "15",
    "embedding_tensor_slice_rows": "1",
    "tensor_segment_bytes_bound": "33550832",
    "sampled_bf16_value_rows": "65536",
    "sampled_bf16_finite_rows": "65536",
    "sampled_bf16_nan_rows": "0",
    "sampled_bf16_inf_rows": "0",
    "slice_hash_match_rows": "16",
    "bf16_tensor_slice_stats_ready": "1",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "full_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61aa {field}: expected {value}, got {summary.get(field)}")
if int(summary["sampled_bf16_nonzero_rows"]) <= 0:
    raise SystemExit("v61aa should sample nonzero BF16 values")

required_files = [
    "hotset_tensor_slice_stat_rows.csv",
    "hotset_tensor_slice_sample_value_rows.csv",
    "hotset_tensor_slice_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61AA_HOTSET_TENSOR_SLICE_BOUNDARY.md",
    "v61aa_hotset_tensor_slice_verifier_manifest.json",
    "sha256_manifest.csv",
    "source_v61z/hotset_direct_io_read_rows.csv",
    "source_v61v/remote_sample_tensor_binding_rows.csv",
    "source_v61y/hotset_local_materialization_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61aa artifact: {rel}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v61z-direct-io-hotset-input",
    "v61v-tensor-binding-input",
    "bf16-tensor-slice-stats",
    "manifest-only-no-repo-payload",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61aa gate should pass: {gate}")
for gate in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "real-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61aa gate should stay blocked: {gate}")

slice_rows = read_csv(run_dir / "hotset_tensor_slice_stat_rows.csv")
sample_rows = read_csv(run_dir / "hotset_tensor_slice_sample_value_rows.csv")
metric = read_csv(run_dir / "hotset_tensor_slice_metric_rows.csv")[0]
gaps = {row["gap"]: row["status"] for row in read_csv(run_dir / "runtime_gap_rows.csv")}

if len(slice_rows) != 16:
    raise SystemExit("v61aa tensor slice row count mismatch")
if len(sample_rows) != 65536:
    raise SystemExit("v61aa sample row count mismatch")
if sum(1 for row in slice_rows if row["moe_expert_page"] == "1") != 15:
    raise SystemExit("v61aa MoE tensor slice count mismatch")
if sum(1 for row in slice_rows if row["embedding_page"] == "1") != 1:
    raise SystemExit("v61aa embedding tensor slice count mismatch")
if any(row["dtype"] != "BF16" for row in slice_rows):
    raise SystemExit("v61aa all tensor slices should be BF16")
if any(row["segment_hash_bound_to_remote_page"] != "1" for row in slice_rows):
    raise SystemExit("v61aa all tensor slices should be bound to remote page hashes")
if any(row["direct_read_hash_match"] != "1" for row in slice_rows):
    raise SystemExit("v61aa all tensor slices should inherit direct-read hash matches")
if any(row["sampled_bf16_values"] != "4096" for row in slice_rows):
    raise SystemExit("v61aa each tensor slice should sample 4096 BF16 values")
if any(row["sampled_finite_values"] != "4096" for row in slice_rows):
    raise SystemExit("v61aa all sampled BF16 values should be finite")
if any(row["sampled_nan_values"] != "0" or row["sampled_inf_values"] != "0" for row in slice_rows):
    raise SystemExit("v61aa should not sample NaN/Inf BF16 values")
if any(row["bf16_tensor_slice_stats_ready"] != "1" for row in slice_rows):
    raise SystemExit("v61aa tensor slice stats should be ready for all rows")
if any(row["checkpoint_payload_bytes_committed_to_repo"] != "0" for row in slice_rows + sample_rows):
    raise SystemExit("v61aa must not commit checkpoint payload")
if any(row["actual_model_generation_ready"] != "0" for row in slice_rows):
    raise SystemExit("v61aa must keep generation blocked")

if metric["bf16_tensor_slice_stats_ready"] != "1":
    raise SystemExit("v61aa metric readiness mismatch")
for field in [
    "full_checkpoint_materialization_ready",
    "full_safetensors_page_hash_binding_ready",
    "actual_model_generation_ready",
    "near_frontier_claim_ready",
    "production_latency_claim_ready",
    "real_release_package_ready",
]:
    if metric[field] != "0":
        raise SystemExit(f"v61aa metric should keep {field}=0")

for gap in ["v61z-direct-io-hotset-input", "v61v-tensor-binding-input", "bf16-tensor-slice-stats"]:
    if gaps.get(gap) != "ready":
        raise SystemExit(f"v61aa gap should be ready: {gap}")
for gap in [
    "full-checkpoint-materialization",
    "full-safetensors-page-hash-binding",
    "actual-model-generation",
    "near-frontier-quality",
    "production-latency",
    "release-package",
]:
    if gaps.get(gap) != "blocked":
        raise SystemExit(f"v61aa gap should stay blocked: {gap}")

manifest = json.loads((run_dir / "v61aa_hotset_tensor_slice_verifier_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v61aa_hotset_tensor_slice_verifier_ready") != 1:
    raise SystemExit("v61aa manifest readiness mismatch")
if manifest.get("tensor_slice_rows") != 16 or manifest.get("sampled_bf16_value_rows") != 65536:
    raise SystemExit("v61aa manifest row count mismatch")
if manifest.get("bf16_tensor_slice_stats_ready") != 1:
    raise SystemExit("v61aa manifest readiness should be 1")
if manifest.get("actual_model_generation_ready") != 0:
    raise SystemExit("v61aa manifest should keep generation blocked")

boundary = (run_dir / "V61AA_HOTSET_TENSOR_SLICE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "tensor_slice_rows=16",
    "tensor_segment_bytes_bound=33550832",
    "sampled_bf16_value_rows=65536",
    "sampled_bf16_finite_rows=65536",
    "bf16_tensor_slice_stats_ready=1",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61aa boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61aa sha256 mismatch: {rel}")
PY

echo "v61aa hotset tensor slice verifier smoke passed"
