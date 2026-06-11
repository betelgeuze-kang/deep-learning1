#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52t_de_local_measured_deferral"
RUN_ID="${V52T_RUN_ID:-deferral_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v52s_local_llm_weight_tier_contract_summary.csv" ]]; then
  V52S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52s_local_llm_weight_tier_contract.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v52u_local_llm_weight_tier_mmap_reader_summary.csv" ]]; then
  V52U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52u_local_llm_weight_tier_mmap_reader.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv" ]]; then
  V52V_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52v_local_llm_weight_tier_rocm_decode_bind.sh" >/dev/null
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
v52d_summary = list(csv.DictReader((results / "v52d_30b70b_llm_rag_evidence_intake_summary.csv").open(newline="", encoding="utf-8")))[0]
v52s_summary = list(csv.DictReader((results / "v52s_local_llm_weight_tier_contract_summary.csv").open(newline="", encoding="utf-8")))[0]
v52u_summary = list(csv.DictReader((results / "v52u_local_llm_weight_tier_mmap_reader_summary.csv").open(newline="", encoding="utf-8")))[0]
v52v_summary = list(csv.DictReader((results / "v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv").open(newline="", encoding="utf-8")))[0]

if int(v52s_summary.get("v52s_local_llm_weight_tier_contract_ready", "0")) != 1:
    raise SystemExit("v52t requires v52s weight tier contract")
if int(v52u_summary.get("weight_tier_mmap_reader_ready", "0")) != 1:
    raise SystemExit("v52t requires v52u weight tier mmap reader")
if int(v52v_summary.get("rocm_kernel_bind_ready", "0")) != 1:
    raise SystemExit("v52t requires v52v ROCm kernel bind")


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


copy(results / "v52d_30b70b_llm_rag_evidence_intake_summary.csv", "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv")
copy(results / "v52s_local_llm_weight_tier_contract_summary.csv", "source_v52s/v52s_local_llm_weight_tier_contract_summary.csv")
copy(results / "v52u_local_llm_weight_tier_mmap_reader_summary.csv", "source_v52u/v52u_local_llm_weight_tier_mmap_reader_summary.csv")
copy(results / "v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv", "source_v52v/v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv")
v52s_dir = results / "v52s_local_llm_weight_tier_contract" / "contract_001"
v52u_dir = results / "v52u_local_llm_weight_tier_mmap_reader" / "reader_001"
v52v_dir = results / "v52v_local_llm_weight_tier_rocm_decode_bind" / "bind_001"
copy(v52u_dir / "V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md", "source_v52u/V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md")
copy(v52v_dir / "V52V_LOCAL_LLM_WEIGHT_TIER_ROCM_DECODE_BIND_BOUNDARY.md", "source_v52v/V52V_LOCAL_LLM_WEIGHT_TIER_ROCM_DECODE_BIND_BOUNDARY.md")
copy(v52v_dir / "rocm_decode_bind_rows.csv", "source_v52v/rocm_decode_bind_rows.csv")
for rel in [
    "weight_tier_policy_rows.csv",
    "local_host_profile.json",
    "V52S_LOCAL_LLM_WEIGHT_TIER_BOUNDARY.md",
    "v52s_local_llm_weight_tier_contract_manifest.json",
]:
    copy(v52s_dir / rel, f"source_v52s/{rel}")

deferral_rows = [
    {
        "system_id": "D",
        "measured_scope": "v50-9-query-seed-and-v53e-1000",
        "local_measured_status": "deferred-with-reason",
        "blocking_reason": "monolithic-ollama-32b-exceeds-16gb-vram-usable-speed",
        "replacement_path": "v52v-rocm-bind-then-tier-runtime-or-external-bake",
        "required_param_class_b": "25-40",
    },
    {
        "system_id": "E",
        "measured_scope": "v50-9-query-seed-and-v53e-1000",
        "local_measured_status": "deferred-with-reason",
        "blocking_reason": "monolithic-ollama-70b-exceeds-16gb-vram-usable-speed",
        "replacement_path": "v52v-rocm-bind-then-tier-runtime-or-external-bake",
        "required_param_class_b": "65-80",
    },
]
write_csv(run_dir / "de_local_measured_deferral_rows.csv", list(deferral_rows[0].keys()), deferral_rows)

aborted_rows = [
    {
        "experiment": "v52n_30b_open_weight_llm_rag_measured_seed",
        "status": "aborted-by-operator",
        "reason": "monolithic-32b-inference-too-slow-for-local-use",
        "partial_artifacts_removed": 1,
    },
]
write_csv(run_dir / "aborted_local_run_rows.csv", list(aborted_rows[0].keys()), aborted_rows)

(run_dir / "V52T_DE_LOCAL_MEASURED_DEFERRAL_BOUNDARY.md").write_text(
    "# v52t D/E Local Measured Deferral Boundary\n\n"
    "This records an explicit deferral for local monolithic Ollama D/E measured rows on a 16GB VRAM host. "
    "It is not a waiver of the required D/E evidence contract and not a quality claim.\n\n"
    "- local_de_measured_status=deferred-with-reason\n"
    "- systems=D/E\n"
    "- v52s_weight_tier_contract_ready=1\n"
    "- weight_tier_mmap_reader_ready=1\n"
    "- rocm_kernel_bind_ready=1\n"
    "- d_30b_supplied_evidence_ready=0\n"
    "- e_70b_supplied_evidence_ready=0\n"
    "- required_30b_baseline_ready=0\n"
    "- required_70b_baseline_ready=0\n\n"
    "Next paths: extend v52v ROCm bind into full tiered matmul decode (v52w follow-up), "
    "or bake D/E measured rows once on a host with sufficient VRAM/tier runtime, then reuse.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52t-de-local-measured-deferral",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52t_de_local_measured_deferral_ready": 1,
    "local_de_measured_status": "deferred-with-reason",
    "v52s_local_llm_weight_tier_contract_ready": 1,
    "rocm_kernel_bind_ready": int(v52v_summary.get("rocm_kernel_bind_ready", "0")),
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_ready": 0,
}
(run_dir / "v52t_de_local_measured_deferral_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary = {
    "v52t_de_local_measured_deferral_ready": 1,
    "local_de_measured_status": "deferred-with-reason",
    "deferred_systems": "D/E",
    "aborted_local_run_rows": 1,
    "v52s_weight_tier_contract_ready": int(v52s_summary["v52s_local_llm_weight_tier_contract_ready"]),
    "weight_tier_mmap_reader_ready": int(v52u_summary.get("weight_tier_mmap_reader_ready", "0")),
    "rocm_kernel_bind_ready": int(v52v_summary.get("rocm_kernel_bind_ready", "0")),
    "weight_tier_runtime_ready": int(v52s_summary.get("weight_tier_runtime_ready", "0")),
    "d_30b_supplied_evidence_ready": 0,
    "e_70b_supplied_evidence_ready": 0,
    "required_30b_baseline_ready": 0,
    "required_70b_baseline_ready": 0,
    "v52_absorb_ready": int(v52d_summary.get("v52_absorb_ready", "0")),
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("de-local-measured-deferral", "pass", "D/E local monolithic measured runs are explicitly deferred with reason"),
    ("v52s-weight-tier-contract-linked", "pass", "deferral points to v52s NVMe shard tier contract"),
    ("v52u-mmap-reader-linked", "pass", "deferral points to v52u tiered mmap reader scaffold"),
    ("v52v-rocm-bind-linked", "pass", "deferral points to v52v ROCm HIP kernel bind scaffold"),
    ("v52d-intake-still-valid", "pass", "v52d D/E evidence intake contract remains in force"),
    ("30b-llm-rag-real-row", "blocked", "D measured rows still missing"),
    ("70b-llm-rag-real-row", "blocked", "E measured rows still missing"),
    ("v52-de-absorb-ready", "blocked", "D/E v53e measured packets are not absorbed"),
    ("v52-full-baseline-war", "blocked", "full v52 still needs D/E rows or tier-runtime bake"),
    ("real-release-package", "blocked", "deferral is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "de_local_measured_deferral_rows.csv",
    "aborted_local_run_rows.csv",
    "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv",
    "source_v52s/v52s_local_llm_weight_tier_contract_summary.csv",
    "source_v52s/weight_tier_policy_rows.csv",
    "source_v52s/local_host_profile.json",
    "source_v52u/v52u_local_llm_weight_tier_mmap_reader_summary.csv",
    "source_v52u/V52U_LOCAL_LLM_WEIGHT_TIER_MMAP_READER_BOUNDARY.md",
    "source_v52v/v52v_local_llm_weight_tier_rocm_decode_bind_summary.csv",
    "source_v52v/V52V_LOCAL_LLM_WEIGHT_TIER_ROCM_DECODE_BIND_BOUNDARY.md",
    "source_v52v/rocm_decode_bind_rows.csv",
    "V52T_DE_LOCAL_MEASURED_DEFERRAL_BOUNDARY.md",
    "v52t_de_local_measured_deferral_manifest.json",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v52t_de_local_measured_deferral_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
