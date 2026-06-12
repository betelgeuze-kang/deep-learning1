#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ap_moe_coverage_remote_hash_plan"
RUN_ID="${V61AP_RUN_ID:-plan_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61AP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ap_moe_coverage_remote_hash_plan_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ao_real_model_page_manifest_coverage_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import re
import shutil
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

model_id = "mistralai/Mixtral-8x22B-v0.1"
expected_layers = 56
expected_experts = 8
expected_roles = ["moe_w1", "moe_w2", "moe_w3"]
page_size_bytes = 2 * 1024 * 1024

v61ao_dir = results / "v61ao_real_model_page_manifest_coverage_audit" / "audit_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61v_dir = results / "v61v_remote_page_tensor_binding" / "binding_001"


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


def tensor_role(tensor_name):
    match = re.search(r"\.experts\.\d+\.(w[123])\.weight$", tensor_name)
    if match:
        return f"moe_{match.group(1)}"
    return ""


def layer_expert(tensor_name):
    layer_match = re.search(r"model\.layers\.(\d+)\.", tensor_name)
    expert_match = re.search(r"\.experts\.(\d+)\.", tensor_name)
    layer = layer_match.group(1) if layer_match else ""
    expert = expert_match.group(1) if expert_match else ""
    return layer, expert


v61ao_summary = read_csv(results / "v61ao_real_model_page_manifest_coverage_audit_summary.csv")[0]
v61q_summary = read_csv(results / "v61q_real_checkpoint_page_map_summary.csv")[0]
v61v_summary = read_csv(results / "v61v_remote_page_tensor_binding_summary.csv")[0]
if v61ao_summary.get("v61ao_real_model_page_manifest_coverage_audit_ready") != "1":
    raise SystemExit("v61ap requires v61ao_real_model_page_manifest_coverage_audit_ready=1")
if v61ao_summary.get("real_model_page_manifest_coverage_ready") != "1":
    raise SystemExit("v61ap requires real_model_page_manifest_coverage_ready=1")

for src, rel in [
    (results / "v61ao_real_model_page_manifest_coverage_audit_summary.csv", "source_v61ao/v61ao_real_model_page_manifest_coverage_audit_summary.csv"),
    (results / "v61ao_real_model_page_manifest_coverage_audit_decision.csv", "source_v61ao/v61ao_real_model_page_manifest_coverage_audit_decision.csv"),
    (v61ao_dir / "moe_layer_expert_tensor_coverage_rows.csv", "source_v61ao/moe_layer_expert_tensor_coverage_rows.csv"),
    (v61ao_dir / "checkpoint_tensor_role_coverage_rows.csv", "source_v61ao/checkpoint_tensor_role_coverage_rows.csv"),
    (v61ao_dir / "real_model_page_manifest_coverage_requirement_rows.csv", "source_v61ao/real_model_page_manifest_coverage_requirement_rows.csv"),
    (v61ao_dir / "real_model_page_manifest_coverage_metric_rows.csv", "source_v61ao/real_model_page_manifest_coverage_metric_rows.csv"),
    (v61ao_dir / "v61ao_real_model_page_manifest_coverage_audit_manifest.json", "source_v61ao/v61ao_real_model_page_manifest_coverage_audit_manifest.json"),
    (v61ao_dir / "sha256_manifest.csv", "source_v61ao/sha256_manifest.csv"),
    (results / "v61q_real_checkpoint_page_map_summary.csv", "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (v61q_dir / "checkpoint_page_segment_rows.csv", "source_v61q/checkpoint_page_segment_rows.csv"),
    (v61q_dir / "source_v61o/checkpoint_shard_http_identity_rows.csv", "source_v61q/source_v61o/checkpoint_shard_http_identity_rows.csv"),
    (results / "v61v_remote_page_tensor_binding_summary.csv", "source_v61v/v61v_remote_page_tensor_binding_summary.csv"),
    (v61v_dir / "remote_sample_tensor_binding_rows.csv", "source_v61v/remote_sample_tensor_binding_rows.csv"),
    (v61v_dir / "sha256_manifest.csv", "source_v61v/sha256_manifest.csv"),
]:
    copy(src, rel)

coverage_rows = read_csv(v61ao_dir / "moe_layer_expert_tensor_coverage_rows.csv")
segment_rows = read_csv(v61q_dir / "checkpoint_page_segment_rows.csv")
http_rows = read_csv(v61q_dir / "source_v61o/checkpoint_shard_http_identity_rows.csv")
remote_bindings = read_csv(v61v_dir / "remote_sample_tensor_binding_rows.csv")

if len(coverage_rows) != expected_layers * expected_experts * len(expected_roles):
    raise SystemExit("v61ap expected 1344 v61ao MoE coverage rows")
if len(segment_rows) != int(v61q_summary["checkpoint_page_segment_rows"]):
    raise SystemExit("v61ap segment row count differs from v61q summary")

http_by_shard = {row["shard_name"]: row for row in http_rows}
remote_by_cell = {}
for row in remote_bindings:
    if row["tensor_role"] in expected_roles and row["remote_hash_bound"] == "1":
        key = (row["layer_index"], row["expert_index"], row["tensor_role"])
        remote_by_cell[key] = row

segments_by_cell = defaultdict(list)
for row in segment_rows:
    role = tensor_role(row["tensor_name"])
    if role not in expected_roles:
        continue
    layer, expert = layer_expert(row["tensor_name"])
    if not layer or not expert:
        continue
    segments_by_cell[(layer, expert, role)].append(row)

plan_rows = []
existing_rows = []
role_total = Counter()
role_existing = Counter()
shard_plan = Counter()
shard_existing = Counter()

for layer in range(expected_layers):
    for expert in range(expected_experts):
        for role in expected_roles:
            key = (str(layer), str(expert), role)
            segments = segments_by_cell.get(key, [])
            if not segments:
                raise SystemExit(f"v61ap missing segments for cell {key}")
            existing = remote_by_cell.get(key)
            if existing:
                selected = next((row for row in segments if row["page_id"] == existing["source_page_id"]), None)
                if selected is None:
                    raise SystemExit(f"v61ap remote binding page not found in v61q segments for {key}")
                status = "already-remote-hash-bound"
                remote_sample_id = existing["remote_sample_id"]
                remote_page_sha256 = existing["remote_page_sha256"]
                role_existing[role] += 1
            else:
                selected = sorted(
                    segments,
                    key=lambda item: (
                        int(item["tensor_segment_bytes"]) != page_size_bytes,
                        int(item["tensor_offset_start_in_tensor"]),
                        int(item["shard_page_index"]),
                    ),
                )[0]
                status = "planned-remote-range-hash"
                remote_sample_id = ""
                remote_page_sha256 = ""
            source_url = http_by_shard[selected["shard_name"]]["source_url"]
            plan_id = f"v61ap:l{layer:02d}:e{expert}:role:{role}"
            row = {
                "remote_hash_plan_id": plan_id,
                "model_id": model_id,
                "layer_index": str(layer),
                "expert_index": str(expert),
                "tensor_role": role,
                "source_page_id": selected["page_id"],
                "shard_name": selected["shard_name"],
                "shard_page_index": selected["shard_page_index"],
                "page_start_byte": selected["page_start_byte"],
                "page_end_byte_exclusive": selected["page_end_byte_exclusive"],
                "planned_range_bytes": str(int(selected["page_end_byte_exclusive"]) - int(selected["page_start_byte"])),
                "source_url": source_url,
                "tensor_name": selected["tensor_name"],
                "dtype": selected["dtype"],
                "tensor_segment_bytes": selected["tensor_segment_bytes"],
                "page_offset_start": selected["page_offset_start"],
                "page_offset_end": selected["page_offset_end"],
                "plan_status": status,
                "remote_sample_id": remote_sample_id,
                "remote_page_sha256": remote_page_sha256,
                "sample_selection_method": "existing-remote-hash-else-first-full-cell-page",
                "remote_hash_execution_enabled": "0",
                "full_moe_coverage_remote_hash_ready": "0",
                "checkpoint_payload_bytes_downloaded_by_v61ap": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
                "route_jump_rows": "0",
            }
            plan_rows.append(row)
            role_total[role] += 1
            shard_plan[selected["shard_name"]] += 1
            if status == "already-remote-hash-bound":
                existing_rows.append(row)
                shard_existing[selected["shard_name"]] += 1

write_csv(run_dir / "moe_coverage_remote_hash_plan_rows.csv", list(plan_rows[0].keys()), plan_rows)
write_csv(run_dir / "moe_coverage_existing_remote_hash_rows.csv", list(plan_rows[0].keys()), existing_rows)

role_rows = []
for role in expected_roles:
    existing = role_existing[role]
    total = role_total[role]
    planned = total - existing
    role_rows.append(
        {
            "tensor_role": role,
            "coverage_cell_rows": str(total),
            "already_remote_hash_bound_rows": str(existing),
            "planned_remote_hash_rows": str(planned),
            "already_remote_hash_bound_bytes": str(existing * page_size_bytes),
            "planned_remote_hash_bytes": str(planned * page_size_bytes),
            "full_role_remote_hash_ready": str(int(existing == total)),
        }
    )
write_csv(run_dir / "moe_coverage_remote_hash_role_rows.csv", list(role_rows[0].keys()), role_rows)

shard_rows = []
for shard_name in sorted(shard_plan):
    shard_rows.append(
        {
            "shard_name": shard_name,
            "planned_cell_rows": str(shard_plan[shard_name]),
            "already_remote_hash_bound_rows": str(shard_existing[shard_name]),
            "planned_remote_hash_rows": str(shard_plan[shard_name] - shard_existing[shard_name]),
            "planned_range_bytes": str(shard_plan[shard_name] * page_size_bytes),
            "source_url": http_by_shard[shard_name]["source_url"],
        }
    )
write_csv(run_dir / "moe_coverage_remote_hash_shard_rows.csv", list(shard_rows[0].keys()), shard_rows)

total_rows = len(plan_rows)
already_rows = len(existing_rows)
planned_rows = total_rows - already_rows
full_moe_remote_hash_ready = int(already_rows == total_rows)
remote_hash_expansion_execution_ready = 0

requirement_rows = [
    {
        "requirement_id": "v61ao-real-model-page-manifest-coverage-input",
        "status": "pass",
        "required_rows": "1",
        "actual_rows": v61ao_summary["real_model_page_manifest_coverage_ready"],
        "reason": "v61ao manifest coverage must be ready before planning remote hash expansion",
    },
    {
        "requirement_id": "moe-cell-remote-hash-plan-complete",
        "status": "pass" if total_rows == 1344 else "blocked",
        "required_rows": "1344",
        "actual_rows": str(total_rows),
        "reason": "one representative full-page hash plan row is required for each layer/expert/w1-w2-w3 cell",
    },
    {
        "requirement_id": "existing-remote-hash-bindings-preserved",
        "status": "pass" if already_rows == int(v61v_summary["moe_expert_binding_rows"]) else "blocked",
        "required_rows": v61v_summary["moe_expert_binding_rows"],
        "actual_rows": str(already_rows),
        "reason": "existing v61v MoE remote hashes should be preserved as already-bound plan rows",
    },
    {
        "requirement_id": "full-moe-coverage-remote-hash",
        "status": "pass" if full_moe_remote_hash_ready else "blocked",
        "required_rows": str(total_rows),
        "actual_rows": str(already_rows),
        "reason": "all 1344 planned MoE cell pages must be remotely hash-bound before this can pass",
    },
    {
        "requirement_id": "remote-hash-expansion-execution",
        "status": "blocked",
        "required_rows": str(planned_rows),
        "actual_rows": "0",
        "reason": "v61ap is a deterministic plan only; no new HTTP range payload is fetched",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_rows": "0",
        "actual_rows": "0",
        "reason": "v61ap writes metadata and existing hashes only",
    },
]
write_csv(run_dir / "moe_coverage_remote_hash_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ap_moe_coverage_remote_hash_plan_metrics",
    "model_id": model_id,
    "v61ao_real_model_page_manifest_coverage_audit_ready": v61ao_summary["v61ao_real_model_page_manifest_coverage_audit_ready"],
    "real_model_page_manifest_coverage_ready": v61ao_summary["real_model_page_manifest_coverage_ready"],
    "moe_layer_expert_tensor_coverage_rows": v61ao_summary["moe_layer_expert_tensor_coverage_rows"],
    "remote_hash_plan_rows": str(total_rows),
    "already_remote_hash_bound_rows": str(already_rows),
    "planned_remote_hash_rows": str(planned_rows),
    "remote_hash_plan_shard_rows": str(len(shard_rows)),
    "planned_remote_hash_bytes": str(total_rows * page_size_bytes),
    "already_remote_hash_bound_bytes": str(already_rows * page_size_bytes),
    "remaining_remote_hash_bytes": str(planned_rows * page_size_bytes),
    "full_moe_coverage_remote_hash_ready": str(full_moe_remote_hash_ready),
    "remote_hash_expansion_execution_ready": str(remote_hash_expansion_execution_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ap": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "moe_coverage_remote_hash_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61ao-manifest-coverage-input", "ready", "v61ao complete metadata coverage is bound"),
    ("moe-cell-remote-hash-plan", "ready", "1344 MoE layer/expert/tensor cells have deterministic representative page hash plans"),
    ("existing-remote-hash-bindings", "ready", f"{already_rows} v61v MoE remote hashes are preserved"),
    ("full-moe-coverage-remote-hash", "blocked", f"{already_rows}/{total_rows} MoE cell pages are already remotely hash-bound"),
    ("remote-hash-expansion-execution", "blocked", "v61ap does not perform new HTTP range reads"),
    ("full-safetensors-page-hash-binding", "blocked", "a 1344-cell MoE plan is not full 134161-page safetensors coverage"),
    ("real-model-generation", "blocked", "real Mixtral generation waits for local materialization and page-hash gates"),
    ("production-latency", "blocked", "not an end-to-end decode benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61ap_moe_coverage_remote_hash_plan_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ao-real-model-page-manifest-coverage-input", "status": "pass", "reason": "v61ao coverage audit is bound"},
    {"gate": "moe-cell-remote-hash-plan", "status": "pass", "reason": f"remote_hash_plan_rows={total_rows}"},
    {"gate": "existing-remote-hash-bindings-preserved", "status": "pass" if already_rows == int(v61v_summary["moe_expert_binding_rows"]) else "blocked", "reason": f"already_remote_hash_bound_rows={already_rows}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "metadata/hash plan only"},
    {"gate": "full-moe-coverage-remote-hash", "status": "pass" if full_moe_remote_hash_ready else "blocked", "reason": f"already_remote_hash_bound_rows={already_rows}/{total_rows}"},
    {"gate": "remote-hash-expansion-execution", "status": "blocked", "reason": "no new remote ranges are fetched by v61ap"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "requires all 134161 checkpoint pages, not only 1344 MoE cell representatives"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "real Mixtral generation is still gated"},
    {"gate": "production-latency", "status": "blocked", "reason": "not a decode latency benchmark"},
    {"gate": "release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ap MoE Coverage Remote Hash Plan Boundary

This artifact turns the v61ao complete metadata coverage audit into a
deterministic remote hash expansion plan for one representative checkpoint page
per Mixtral MoE layer/expert/tensor cell. It preserves existing v61v remote
hashes and plans the remaining cells without fetching new payload bytes.

Evidence emitted:

- moe_layer_expert_tensor_coverage_rows={v61ao_summary["moe_layer_expert_tensor_coverage_rows"]}
- remote_hash_plan_rows={total_rows}
- already_remote_hash_bound_rows={already_rows}
- planned_remote_hash_rows={planned_rows}
- planned_remote_hash_bytes={total_rows * page_size_bytes}
- already_remote_hash_bound_bytes={already_rows * page_size_bytes}
- remaining_remote_hash_bytes={planned_rows * page_size_bytes}
- full_moe_coverage_remote_hash_ready={full_moe_remote_hash_ready}
- remote_hash_expansion_execution_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ap=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: deterministic MoE coverage remote-hash expansion plan and
preserved remote-hash-bound sampled cells.
Blocked wording: executed remote hash expansion, full MoE remote hash coverage,
full safetensors page-hash coverage, local materialization, real Mixtral
generation, production latency, or release readiness.
"""
(run_dir / "V61AP_MOE_COVERAGE_REMOTE_HASH_PLAN_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ap_moe_coverage_remote_hash_plan",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ap_moe_coverage_remote_hash_plan_ready": 1,
    "v61ao_summary_sha256": sha256(results / "v61ao_real_model_page_manifest_coverage_audit_summary.csv"),
    "v61q_segment_source_sha256": sha256(v61q_dir / "checkpoint_page_segment_rows.csv"),
    "v61v_binding_source_sha256": sha256(v61v_dir / "remote_sample_tensor_binding_rows.csv"),
    "remote_hash_plan_rows": total_rows,
    "already_remote_hash_bound_rows": already_rows,
    "planned_remote_hash_rows": planned_rows,
    "planned_remote_hash_bytes": total_rows * page_size_bytes,
    "remaining_remote_hash_bytes": planned_rows * page_size_bytes,
    "full_moe_coverage_remote_hash_ready": full_moe_remote_hash_ready,
    "remote_hash_expansion_execution_ready": remote_hash_expansion_execution_ready,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ap": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "actual_model_generation_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61ap_moe_coverage_remote_hash_plan_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ap_moe_coverage_remote_hash_plan_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
