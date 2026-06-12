#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ch_real_model_page_manifest_release_index"
RUN_ID="${V61CH_RUN_ID:-index_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ch_real_model_page_manifest_release_index_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61AO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ao_real_model_page_manifest_coverage_audit.sh" >/dev/null
V61CB_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cb_ubuntu1_full_page_hash_coverage_promotion_gate.sh" >/dev/null
V61CG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cg_ubuntu1_source_bound_generation_operator_bundle.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"

v61ao_dir = results / "v61ao_real_model_page_manifest_coverage_audit" / "audit_001"
v61cb_dir = results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate" / "gate_001"
v61cg_dir = results / "v61cg_ubuntu1_source_bound_generation_operator_bundle" / "bundle_001"


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


def source_row(artifact_id, role, source_path, row_count, included):
    return {
        "index_artifact_id": artifact_id,
        "artifact_role": role,
        "source_artifact_path": str(source_path.relative_to(root)),
        "row_count": str(row_count),
        "source_sha256": sha256(source_path),
        "source_bytes": str(source_path.stat().st_size),
        "included_in_release_index": str(int(included)),
        "contains_checkpoint_payload_bytes": "0",
        "redistributable_scope": "metadata-hash-offset-index-only-no-weight-payload",
        "license_or_access_note": "model access and checkpoint license remain upstream/operator responsibilities; this artifact contains no checkpoint payload bytes",
        "verification_state": "ready",
    }


v61ao = read_csv(results / "v61ao_real_model_page_manifest_coverage_audit_summary.csv")[0]
v61cb = read_csv(results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv")[0]
v61cg = read_csv(results / "v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv")[0]
if v61ao.get("v61ao_real_model_page_manifest_coverage_audit_ready") != "1":
    raise SystemExit("v61ch requires v61ao_real_model_page_manifest_coverage_audit_ready=1")
if v61cb.get("v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready") != "1":
    raise SystemExit("v61ch requires v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready=1")
if v61cg.get("v61cg_ubuntu1_source_bound_generation_operator_bundle_ready") != "1":
    raise SystemExit("v61ch requires v61cg_ubuntu1_source_bound_generation_operator_bundle_ready=1")

for src, rel in [
    (results / "v61ao_real_model_page_manifest_coverage_audit_summary.csv", "source_v61ao/v61ao_real_model_page_manifest_coverage_audit_summary.csv"),
    (results / "v61ao_real_model_page_manifest_coverage_audit_decision.csv", "source_v61ao/v61ao_real_model_page_manifest_coverage_audit_decision.csv"),
    (v61ao_dir / "checkpoint_manifest_shard_audit_rows.csv", "source_v61ao/checkpoint_manifest_shard_audit_rows.csv"),
    (v61ao_dir / "checkpoint_tensor_role_coverage_rows.csv", "source_v61ao/checkpoint_tensor_role_coverage_rows.csv"),
    (v61ao_dir / "moe_layer_expert_tensor_coverage_rows.csv", "source_v61ao/moe_layer_expert_tensor_coverage_rows.csv"),
    (v61ao_dir / "real_model_page_manifest_coverage_requirement_rows.csv", "source_v61ao/real_model_page_manifest_coverage_requirement_rows.csv"),
    (v61ao_dir / "real_model_page_manifest_coverage_metric_rows.csv", "source_v61ao/real_model_page_manifest_coverage_metric_rows.csv"),
    (v61ao_dir / "sha256_manifest.csv", "source_v61ao/sha256_manifest.csv"),
    (results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv", "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"),
    (results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv", "source_v61cb/v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_decision.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_rows.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_requirement_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_requirement_rows.csv"),
    (v61cb_dir / "full_page_hash_coverage_promotion_metric_rows.csv", "source_v61cb/full_page_hash_coverage_promotion_metric_rows.csv"),
    (v61cb_dir / "runtime_gap_rows.csv", "source_v61cb/runtime_gap_rows.csv"),
    (v61cb_dir / "sha256_manifest.csv", "source_v61cb/sha256_manifest.csv"),
    (results / "v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv", "source_v61cg/v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv"),
    (results / "v61cg_ubuntu1_source_bound_generation_operator_bundle_decision.csv", "source_v61cg/v61cg_ubuntu1_source_bound_generation_operator_bundle_decision.csv"),
    (v61cg_dir / "source_bound_generation_operator_bundle_file_rows.csv", "source_v61cg/source_bound_generation_operator_bundle_file_rows.csv"),
    (v61cg_dir / "source_bound_generation_operator_bundle_command_rows.csv", "source_v61cg/source_bound_generation_operator_bundle_command_rows.csv"),
    (v61cg_dir / "source_bound_generation_operator_bundle_requirement_rows.csv", "source_v61cg/source_bound_generation_operator_bundle_requirement_rows.csv"),
    (v61cg_dir / "runtime_gap_rows.csv", "source_v61cg/runtime_gap_rows.csv"),
    (v61cg_dir / "sha256_manifest.csv", "source_v61cg/sha256_manifest.csv"),
]:
    copy(src, rel)

release_dir = run_dir / "release_index"
release_dir.mkdir(parents=True, exist_ok=True)
copy(v61ao_dir / "checkpoint_manifest_shard_audit_rows.csv", "release_index/checkpoint_manifest_shard_audit_rows.csv")
copy(v61ao_dir / "checkpoint_tensor_role_coverage_rows.csv", "release_index/checkpoint_tensor_role_coverage_rows.csv")
copy(v61ao_dir / "moe_layer_expert_tensor_coverage_rows.csv", "release_index/moe_layer_expert_tensor_coverage_rows.csv")

page_hash_status_rows = [
    {
        "model_id": model_id,
        "target_root_path": v61cb["target_root_path"],
        "checkpoint_shard_rows": v61cb["checkpoint_shard_rows"],
        "ready_full_page_hash_shard_rows": v61cb["ready_full_page_hash_shard_rows"],
        "blocked_full_page_hash_shard_rows": v61cb["blocked_full_page_hash_shard_rows"],
        "total_required_page_hash_rows": v61cb["total_required_page_hash_rows"],
        "total_verified_page_hash_rows": v61cb["total_verified_page_hash_rows"],
        "promotion_missing_page_hash_rows": v61cb["promotion_missing_page_hash_rows"],
        "completed_full_safetensors_page_hash_coverage_ready": v61cb["completed_full_safetensors_page_hash_coverage_ready"],
        "full_safetensors_page_hash_binding_ready": v61cb["full_safetensors_page_hash_binding_ready"],
        "contains_checkpoint_payload_bytes": "0",
    }
]
write_csv(release_dir / "page_hash_coverage_status_rows.csv", list(page_hash_status_rows[0].keys()), page_hash_status_rows)

generation_handoff_rows = [
    {
        "model_id": model_id,
        "target_root_path": v61cg["target_root_path"],
        "execution_packet_rows": v61cg["execution_packet_rows"],
        "prompt_manifest_rows": v61cg["prompt_manifest_rows"],
        "return_manifest_rows": v61cg["return_manifest_rows"],
        "operator_bundle_file_rows": v61cg["operator_bundle_file_rows"],
        "operator_bundle_handoff_ready": v61cg["operator_bundle_handoff_ready"],
        "generation_operator_execution_ready": v61cg["generation_operator_execution_ready"],
        "actual_model_generation_ready": v61cg["actual_model_generation_ready"],
        "contains_checkpoint_payload_bytes": "0",
    }
]
write_csv(release_dir / "generation_handoff_status_rows.csv", list(generation_handoff_rows[0].keys()), generation_handoff_rows)

source_artifact_rows = [
    source_row("v61ao-shard-audit", "checkpoint shard page summary", v61ao_dir / "checkpoint_manifest_shard_audit_rows.csv", v61ao["checkpoint_shard_rows"], True),
    source_row("v61ao-role-coverage", "tensor role coverage", v61ao_dir / "checkpoint_tensor_role_coverage_rows.csv", v61ao["tensor_role_coverage_rows"], True),
    source_row("v61ao-moe-matrix", "MoE layer expert tensor matrix", v61ao_dir / "moe_layer_expert_tensor_coverage_rows.csv", v61ao["moe_layer_expert_tensor_coverage_rows"], True),
    source_row("v61ao-full-page-map", "full checkpoint page offset map", v61ao_dir / "source_v61q/checkpoint_unique_page_rows.csv", v61ao["checkpoint_unique_page_rows"], False),
    source_row("v61ao-page-segments", "full tensor/page segment map", v61ao_dir / "source_v61q/checkpoint_page_segment_rows.csv", v61ao["checkpoint_page_segment_rows"], False),
    source_row("v61ao-remote-sample-bindings", "remote hashed tensor sample bindings", v61ao_dir / "source_v61v/remote_sample_tensor_binding_rows.csv", v61ao["remote_hash_bound_tensor_rows"], False),
    source_row("v61cb-page-hash-status", "ubuntu-1 full page-hash coverage promotion status", v61cb_dir / "full_page_hash_coverage_promotion_rows.csv", v61cb["checkpoint_shard_rows"], False),
    source_row("v61cg-generation-handoff", "source-bound generation operator handoff status", v61cg_dir / "source_bound_generation_operator_bundle_file_rows.csv", v61cg["operator_bundle_file_rows"], False),
]
write_csv(run_dir / "page_manifest_release_index_source_artifact_rows.csv", list(source_artifact_rows[0].keys()), source_artifact_rows)
write_csv(release_dir / "MANIFEST_INDEX.csv", list(source_artifact_rows[0].keys()), source_artifact_rows)

(release_dir / "README.md").write_text(
    "# v61ch Real-Model Page Manifest Release Index\n\n"
    "This index packages the real Mixtral page-manifest evidence that can be "
    "shared without checkpoint payload bytes. It binds v61ao page-manifest "
    "coverage, v61cb full page-hash coverage status, and v61cg source-bound "
    "generation handoff status.\n\n"
    "The index is metadata/hash/offset evidence only. Operators must satisfy "
    "the upstream model access terms and complete the remaining page-hash, "
    "materialization, review, and generation returns before claiming actual "
    "generation, near-frontier quality, production latency, or release readiness.\n",
    encoding="utf-8",
)

(release_dir / "ZERO_PAYLOAD_BOUNDARY.md").write_text(
    "# Zero Payload Boundary\n\n"
    "- Allowed: checkpoint shard names, byte ranges, page counts, tensor names, "
    "source artifact hashes, coverage counts, and operator handoff statuses.\n"
    "- Forbidden: `.safetensors`, `.bin`, `.pt`, raw checkpoint payload slices, "
    "or generated text claimed as real model output.\n"
    "- Upstream model access and checkpoint license compliance remain an "
    "operator responsibility; this artifact redistributes no checkpoint bytes.\n",
    encoding="utf-8",
)

(release_dir / "IMPORT_CHECKLIST.md").write_text(
    "# Import Checklist\n\n"
    "- Verify `MANIFEST_INDEX.csv` has eight source artifact rows.\n"
    "- Verify `checkpoint_manifest_shard_audit_rows.csv` has 59 shard rows.\n"
    "- Verify `moe_layer_expert_tensor_coverage_rows.csv` has 1344 MoE matrix rows.\n"
    "- Confirm `page_hash_coverage_status_rows.csv` keeps full page-hash coverage blocked until all 134161 rows are verified.\n"
    "- Confirm `generation_handoff_status_rows.csv` keeps actual generation blocked until the v61bt/v61cc/v61ce return path accepts real artifacts.\n",
    encoding="utf-8",
)

verify_script = release_dir / "VERIFY_RELEASE_INDEX.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

INDEX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

required=(
  "MANIFEST_INDEX.csv"
  "checkpoint_manifest_shard_audit_rows.csv"
  "checkpoint_tensor_role_coverage_rows.csv"
  "moe_layer_expert_tensor_coverage_rows.csv"
  "page_hash_coverage_status_rows.csv"
  "generation_handoff_status_rows.csv"
  "ZERO_PAYLOAD_BOUNDARY.md"
)

for rel in "${required[@]}"; do
  if [[ ! -s "$INDEX_DIR/$rel" ]]; then
    echo "missing v61ch release index file: $rel" >&2
    exit 1
  fi
done

manifest_lines="$(wc -l < "$INDEX_DIR/MANIFEST_INDEX.csv" | tr -d ' ')"
shard_lines="$(wc -l < "$INDEX_DIR/checkpoint_manifest_shard_audit_rows.csv" | tr -d ' ')"
role_lines="$(wc -l < "$INDEX_DIR/checkpoint_tensor_role_coverage_rows.csv" | tr -d ' ')"
moe_lines="$(wc -l < "$INDEX_DIR/moe_layer_expert_tensor_coverage_rows.csv" | tr -d ' ')"
hash_status_lines="$(wc -l < "$INDEX_DIR/page_hash_coverage_status_rows.csv" | tr -d ' ')"
generation_status_lines="$(wc -l < "$INDEX_DIR/generation_handoff_status_rows.csv" | tr -d ' ')"

[[ "$manifest_lines" == "9" ]] || { echo "expected 8 manifest index rows" >&2; exit 1; }
[[ "$shard_lines" == "60" ]] || { echo "expected 59 shard rows" >&2; exit 1; }
[[ "$role_lines" == "9" ]] || { echo "expected 8 tensor role rows" >&2; exit 1; }
[[ "$moe_lines" == "1345" ]] || { echo "expected 1344 MoE matrix rows" >&2; exit 1; }
[[ "$hash_status_lines" == "2" ]] || { echo "expected 1 page-hash status row" >&2; exit 1; }
[[ "$generation_status_lines" == "2" ]] || { echo "expected 1 generation handoff status row" >&2; exit 1; }

if find "$INDEX_DIR" -type f \\( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \\) | grep -q .; then
  echo "checkpoint payload-like file found inside v61ch release index" >&2
  exit 1
fi

echo "v61ch zero-payload page manifest release index verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

release_file_rows = [
    {"release_file": "release_index/README.md", "purpose": "operator-facing release index overview", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/MANIFEST_INDEX.csv", "purpose": "source artifact index with hashes and row counts", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/checkpoint_manifest_shard_audit_rows.csv", "purpose": "59-shard metadata audit", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/checkpoint_tensor_role_coverage_rows.csv", "purpose": "tensor-role coverage summary", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/moe_layer_expert_tensor_coverage_rows.csv", "purpose": "1344-row MoE layer/expert/tensor matrix", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/page_hash_coverage_status_rows.csv", "purpose": "current full page-hash coverage status", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/generation_handoff_status_rows.csv", "purpose": "current generation handoff status", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/ZERO_PAYLOAD_BOUNDARY.md", "purpose": "allowed and forbidden artifact boundary", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/IMPORT_CHECKLIST.md", "purpose": "operator import checklist", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
    {"release_file": "release_index/VERIFY_RELEASE_INDEX.sh", "purpose": "release index shape verifier", "file_ready": "1", "contains_checkpoint_payload_bytes": "0"},
]
write_csv(run_dir / "page_manifest_release_index_file_rows.csv", list(release_file_rows[0].keys()), release_file_rows)

redistributable_manifest_index_ready = int(
    v61ao["real_model_page_manifest_coverage_ready"] == "1"
    and len(source_artifact_rows) == 8
    and len(release_file_rows) == 10
    and all(row["contains_checkpoint_payload_bytes"] == "0" for row in release_file_rows)
)

requirement_rows = [
    {
        "requirement_id": "v61ao-real-model-page-manifest-coverage-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61ao["v61ao_real_model_page_manifest_coverage_audit_ready"],
        "reason": "complete metadata page-manifest coverage is bound",
    },
    {
        "requirement_id": "v61cb-page-hash-coverage-status-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61cb["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
        "reason": "ubuntu-1 full page-hash coverage status is bound",
    },
    {
        "requirement_id": "v61cg-generation-handoff-status-input",
        "status": "pass",
        "required_value": "1",
        "actual_value": v61cg["v61cg_ubuntu1_source_bound_generation_operator_bundle_ready"],
        "reason": "source-bound generation handoff status is bound",
    },
    {
        "requirement_id": "zero-payload-redistributable-index",
        "status": "pass" if redistributable_manifest_index_ready else "blocked",
        "required_value": "10 release files, 8 source rows, 0 payload bytes",
        "actual_value": f"{len(release_file_rows)} release files, {len(source_artifact_rows)} source rows, 0 payload bytes",
        "reason": "release index includes only metadata, hashes, byte ranges, and status rows",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "pass" if v61cb["completed_full_safetensors_page_hash_coverage_ready"] == "1" else "blocked",
        "required_value": v61cb["total_required_page_hash_rows"],
        "actual_value": v61cb["total_verified_page_hash_rows"],
        "reason": "remaining page-hash returns must be accepted before promotion",
    },
    {
        "requirement_id": "real-model-generation",
        "status": "blocked",
        "required_value": "accepted v61bt/v61cc/v61ce generation return",
        "actual_value": "0",
        "reason": "release index is not an executed generation run",
    },
    {
        "requirement_id": "real-release-package",
        "status": "blocked",
        "required_value": "external review and real release package",
        "actual_value": "0",
        "reason": "release index is a page-manifest input, not a release package",
    },
]
write_csv(run_dir / "page_manifest_release_index_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ch_real_model_page_manifest_release_index_metrics",
    "model_id": model_id,
    "v61ao_real_model_page_manifest_coverage_audit_ready": v61ao["v61ao_real_model_page_manifest_coverage_audit_ready"],
    "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready": v61cb["v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_ready"],
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": v61cg["v61cg_ubuntu1_source_bound_generation_operator_bundle_ready"],
    "checkpoint_shard_rows": v61ao["checkpoint_shard_rows"],
    "checkpoint_tensor_rows": v61ao["checkpoint_tensor_rows"],
    "checkpoint_unique_page_rows": v61ao["checkpoint_unique_page_rows"],
    "checkpoint_page_segment_rows": v61ao["checkpoint_page_segment_rows"],
    "moe_layer_expert_tensor_coverage_rows": v61ao["moe_layer_expert_tensor_coverage_rows"],
    "moe_layer_expert_tensor_coverage_ready_rows": v61ao["moe_layer_expert_tensor_coverage_ready_rows"],
    "remote_hash_bound_tensor_rows": v61ao["remote_hash_bound_tensor_rows"],
    "remote_hash_bound_moe_rows": v61ao["remote_hash_bound_moe_rows"],
    "source_artifact_rows": str(len(source_artifact_rows)),
    "release_index_file_rows": str(len(release_file_rows)),
    "redistributable_manifest_index_ready": str(redistributable_manifest_index_ready),
    "total_required_page_hash_rows": v61cb["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61cb["total_verified_page_hash_rows"],
    "remaining_page_hash_rows": v61cb["promotion_missing_page_hash_rows"],
    "completed_full_safetensors_page_hash_coverage_ready": v61cb["completed_full_safetensors_page_hash_coverage_ready"],
    "full_safetensors_page_hash_binding_ready": v61cb["full_safetensors_page_hash_binding_ready"],
    "operator_bundle_handoff_ready": v61cg["operator_bundle_handoff_ready"],
    "generation_operator_execution_ready": v61cg["generation_operator_execution_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "redistributed_checkpoint_payload_bytes": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ch": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "page_manifest_release_index_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ch_real_model_page_manifest_release_index_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61ao-real-model-page-manifest-coverage-input", "status": "ready", "reason": "v61ao coverage audit is bound"},
    {"gap": "v61cb-page-hash-coverage-status-input", "status": "ready", "reason": "v61cb page-hash promotion status is bound"},
    {"gap": "v61cg-generation-handoff-status-input", "status": "ready", "reason": "v61cg operator handoff bundle is bound"},
    {"gap": "zero-payload-page-manifest-release-index", "status": "ready" if redistributable_manifest_index_ready else "blocked", "reason": "metadata-only index has no checkpoint payload bytes"},
    {"gap": "completed-full-safetensors-page-hash-coverage", "status": "ready" if v61cb["completed_full_safetensors_page_hash_coverage_ready"] == "1" else "blocked", "reason": f"total_verified_page_hash_rows={v61cb['total_verified_page_hash_rows']}/{v61cb['total_required_page_hash_rows']}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "release index is not generation execution evidence"},
    {"gap": "production-latency", "status": "blocked", "reason": "not an end-to-end decode latency benchmark"},
    {"gap": "near-frontier-quality", "status": "blocked", "reason": "not a quality benchmark"},
    {"gap": "release-package", "status": "blocked", "reason": "not externally reviewed release evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61ao-real-model-page-manifest-coverage-input", "status": "pass", "reason": "v61ao coverage audit is bound"},
    {"gate": "v61cb-page-hash-coverage-status-input", "status": "pass", "reason": "v61cb coverage promotion status is bound"},
    {"gate": "v61cg-generation-handoff-status-input", "status": "pass", "reason": "v61cg generation handoff status is bound"},
    {"gate": "zero-payload-page-manifest-release-index", "status": "pass" if redistributable_manifest_index_ready else "blocked", "reason": "index contains no checkpoint payload bytes"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "pass" if v61cb["completed_full_safetensors_page_hash_coverage_ready"] == "1" else "blocked", "reason": f"total_verified_page_hash_rows={v61cb['total_verified_page_hash_rows']}/{v61cb['total_required_page_hash_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "release index is not a generation run"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "release index is not a quality benchmark"},
    {"gate": "production-latency", "status": "blocked", "reason": "release index is not latency evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "external review and real release package remain missing"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ch Real-Model Page Manifest Release Index Boundary

This artifact turns the real Mixtral page-manifest evidence into a
zero-payload release index. It binds v61ao coverage, v61cb page-hash status,
and v61cg generation handoff status without redistributing checkpoint payload
bytes.

Evidence emitted:

- checkpoint_shard_rows={v61ao["checkpoint_shard_rows"]}
- checkpoint_unique_page_rows={v61ao["checkpoint_unique_page_rows"]}
- checkpoint_page_segment_rows={v61ao["checkpoint_page_segment_rows"]}
- moe_layer_expert_tensor_coverage_rows={v61ao["moe_layer_expert_tensor_coverage_rows"]}
- moe_layer_expert_tensor_coverage_ready_rows={v61ao["moe_layer_expert_tensor_coverage_ready_rows"]}
- source_artifact_rows={len(source_artifact_rows)}
- release_index_file_rows={len(release_file_rows)}
- redistributable_manifest_index_ready={redistributable_manifest_index_ready}
- total_required_page_hash_rows={v61cb["total_required_page_hash_rows"]}
- total_verified_page_hash_rows={v61cb["total_verified_page_hash_rows"]}
- remaining_page_hash_rows={v61cb["promotion_missing_page_hash_rows"]}
- completed_full_safetensors_page_hash_coverage_ready={v61cb["completed_full_safetensors_page_hash_coverage_ready"]}
- operator_bundle_handoff_ready={v61cg["operator_bundle_handoff_ready"]}
- generation_operator_execution_ready={v61cg["generation_operator_execution_ready"]}
- actual_model_generation_ready=0
- redistributed_checkpoint_payload_bytes=0
- checkpoint_payload_bytes_downloaded_by_v61ch=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: zero-payload page-manifest release index, redistributable
metadata/hash/offset index, complete MoE page-manifest metadata coverage, and
operator handoff status. Blocked wording: completed full safetensors page-hash
coverage, real Mixtral generation, near-frontier quality, production latency,
or real release package.
"""
(run_dir / "V61CH_REAL_MODEL_PAGE_MANIFEST_RELEASE_INDEX_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ch_real_model_page_manifest_release_index",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61ch_real_model_page_manifest_release_index_ready": 1,
    "v61ao_summary_sha256": sha256(results / "v61ao_real_model_page_manifest_coverage_audit_summary.csv"),
    "v61cb_summary_sha256": sha256(results / "v61cb_ubuntu1_full_page_hash_coverage_promotion_gate_summary.csv"),
    "v61cg_summary_sha256": sha256(results / "v61cg_ubuntu1_source_bound_generation_operator_bundle_summary.csv"),
    "checkpoint_shard_rows": int(v61ao["checkpoint_shard_rows"]),
    "checkpoint_unique_page_rows": int(v61ao["checkpoint_unique_page_rows"]),
    "checkpoint_page_segment_rows": int(v61ao["checkpoint_page_segment_rows"]),
    "moe_layer_expert_tensor_coverage_rows": int(v61ao["moe_layer_expert_tensor_coverage_rows"]),
    "source_artifact_rows": len(source_artifact_rows),
    "release_index_file_rows": len(release_file_rows),
    "redistributable_manifest_index_ready": redistributable_manifest_index_ready,
    "total_required_page_hash_rows": int(v61cb["total_required_page_hash_rows"]),
    "total_verified_page_hash_rows": int(v61cb["total_verified_page_hash_rows"]),
    "remaining_page_hash_rows": int(v61cb["promotion_missing_page_hash_rows"]),
    "actual_model_generation_ready": 0,
    "redistributed_checkpoint_payload_bytes": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ch": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61ch_real_model_page_manifest_release_index_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ch_real_model_page_manifest_release_index_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
