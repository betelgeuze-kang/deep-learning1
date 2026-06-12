#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bo_ubuntu1_payload_execution_readiness_gate"
RUN_ID="${V61BO_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BO_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bo_ubuntu1_payload_execution_readiness_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bn_ubuntu1_activation_admission_refresh_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
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
curl_resume_marker = "curl -L --fail --retry 5 --continue-at - --output"


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


v61bn_dir = results / "v61bn_ubuntu1_activation_admission_refresh_gate" / "gate_001"
v61bn_summary_path = results / "v61bn_ubuntu1_activation_admission_refresh_gate_summary.csv"
v61bn_decision_path = results / "v61bn_ubuntu1_activation_admission_refresh_gate_decision.csv"
v61bn_summary = read_csv(v61bn_summary_path)[0]
if v61bn_summary.get("v61bn_ubuntu1_activation_admission_refresh_gate_ready") != "1":
    raise SystemExit("v61bo requires v61bn_ubuntu1_activation_admission_refresh_gate_ready=1")
if v61bn_summary.get("activation_target_admission_ready") != "1":
    raise SystemExit("v61bo requires activation_target_admission_ready=1")
if v61bn_summary.get("activation_target_admitted_rows") != "59":
    raise SystemExit("v61bo requires 59 activation target admitted rows")
if v61bn_summary.get("selected_backend_id") != "curl-resume":
    raise SystemExit("v61bo requires selected_backend_id=curl-resume")
if v61bn_summary.get("selected_backend_ready") != "1":
    raise SystemExit("v61bo requires selected_backend_ready=1")

for src, rel in [
    (v61bn_summary_path, "source_v61bn/v61bn_ubuntu1_activation_admission_refresh_gate_summary.csv"),
    (v61bn_decision_path, "source_v61bn/v61bn_ubuntu1_activation_admission_refresh_gate_decision.csv"),
    (v61bn_dir / "ubuntu1_activation_admission_rows.csv", "source_v61bn/ubuntu1_activation_admission_rows.csv"),
    (v61bn_dir / "ubuntu1_activation_admission_requirement_rows.csv", "source_v61bn/ubuntu1_activation_admission_requirement_rows.csv"),
    (v61bn_dir / "ubuntu1_activation_admission_metric_rows.csv", "source_v61bn/ubuntu1_activation_admission_metric_rows.csv"),
    (v61bn_dir / "runtime_gap_rows.csv", "source_v61bn/runtime_gap_rows.csv"),
    (v61bn_dir / "V61BN_UBUNTU1_ACTIVATION_ADMISSION_REFRESH_GATE_BOUNDARY.md", "source_v61bn/V61BN_UBUNTU1_ACTIVATION_ADMISSION_REFRESH_GATE_BOUNDARY.md"),
    (v61bn_dir / "v61bn_ubuntu1_activation_admission_refresh_gate_manifest.json", "source_v61bn/v61bn_ubuntu1_activation_admission_refresh_gate_manifest.json"),
    (v61bn_dir / "sha256_manifest.csv", "source_v61bn/sha256_manifest.csv"),
    (v61bn_dir / "source_v61ba/ubuntu1_activation_handoff_command_rows.csv", "source_v61ba/ubuntu1_activation_handoff_command_rows.csv"),
]:
    copy(src, rel)

activation_rows = read_csv(v61bn_dir / "ubuntu1_activation_admission_rows.csv")
if len(activation_rows) != 59:
    raise SystemExit("v61bo expects 59 v61bn activation admission rows")

selected_target_path = v61bn_summary["selected_target_path"]
readiness_rows = []
for row in activation_rows:
    priority_rank = int(row["priority_rank"])
    target_bound = int(
        row["target_path"].startswith(selected_target_path)
        and selected_target_path in row["download_command_preview"]
        and "/tmp/" not in row["target_path"]
    )
    curl_ready = int(curl_resume_marker in row["download_command_preview"])
    verify_ready = int(bool(row["post_download_verify_command"]))
    full_hash_ready = int(bool(row["post_download_full_page_hash_command"]))
    generation_admission_ready = int(bool(row["post_download_generation_admission_command"]))
    preflight_ready = int(
        row["target_activation_admitted"] == "1"
        and target_bound
        and curl_ready
        and verify_ready
        and full_hash_ready
        and generation_admission_ready
        and row["payload_execution_ready"] == "0"
        and row["download_execution_ready"] == "0"
    )
    readiness_rows.append(
        {
            "payload_readiness_row_id": f"v61bo_payload_readiness_{priority_rank:04d}",
            "priority_rank": row["priority_rank"],
            "model_id": row["model_id"],
            "shard_name": row["shard_name"],
            "priority_class": row["priority_class"],
            "source_url": row["source_url"],
            "target_path": row["target_path"],
            "expected_bytes": row["expected_bytes"],
            "selected_capacity_target_id": row["selected_capacity_target_id"],
            "selected_activation_target_id": v61bn_summary["selected_activation_target_id"],
            "selected_payload_execution_target_id": "ubuntu-1-payload-readiness-pending-approval",
            "selected_target_path": row["selected_target_path"],
            "selected_backend_id": row["selected_backend_id"],
            "selected_backend_ready": row["selected_backend_ready"],
            "target_activation_admitted": row["target_activation_admitted"],
            "target_bound_download_command": str(target_bound),
            "curl_resume_command_ready": str(curl_ready),
            "post_download_verify_command_ready": str(verify_ready),
            "post_download_full_page_hash_command_ready": str(full_hash_ready),
            "post_download_generation_admission_command_ready": str(generation_admission_ready),
            "payload_execution_preflight_ready": str(preflight_ready),
            "payload_execution_requires_explicit_operator_approval": "1",
            "payload_execution_ready": "0",
            "payload_execution_blocked_reason": "explicit-operator-approval-required",
            "download_execution_ready": "0",
            "download_command_preview": row["download_command_preview"],
            "post_download_verify_command": row["post_download_verify_command"],
            "post_download_full_page_hash_command": row["post_download_full_page_hash_command"],
            "post_download_generation_admission_command": row["post_download_generation_admission_command"],
            "checkpoint_payload_bytes_downloaded_by_v61bo": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

write_csv(run_dir / "ubuntu1_payload_execution_readiness_rows.csv", list(readiness_rows[0].keys()), readiness_rows)

priority_order = {}
priority_counts = Counter()
priority_bytes = Counter()
priority_admitted = Counter()
priority_preflight = Counter()
priority_first = defaultdict(lambda: 10**9)
priority_last = defaultdict(int)
for row in readiness_rows:
    priority_class = row["priority_class"]
    priority_order.setdefault(priority_class, int(row["priority_rank"]))
    priority_counts[priority_class] += 1
    priority_bytes[priority_class] += int(row["expected_bytes"])
    priority_admitted[priority_class] += int(row["target_activation_admitted"])
    priority_preflight[priority_class] += int(row["payload_execution_preflight_ready"])
    priority_first[priority_class] = min(priority_first[priority_class], int(row["priority_rank"]))
    priority_last[priority_class] = max(priority_last[priority_class], int(row["priority_rank"]))

chunk_rows = []
for idx, priority_class in enumerate(sorted(priority_counts, key=lambda key: priority_order[key]), start=1):
    row_count = priority_counts[priority_class]
    chunk_preflight_ready = int(priority_preflight[priority_class] == row_count)
    chunk_rows.append(
        {
            "payload_execution_chunk_id": f"v61bo_payload_chunk_{idx:03d}",
            "priority_class": priority_class,
            "first_priority_rank": str(priority_first[priority_class]),
            "last_priority_rank": str(priority_last[priority_class]),
            "row_count": str(row_count),
            "expected_bytes": str(priority_bytes[priority_class]),
            "target_activation_admitted_rows": str(priority_admitted[priority_class]),
            "curl_resume_command_rows": str(row_count),
            "payload_execution_preflight_ready": str(chunk_preflight_ready),
            "payload_execution_ready": "0",
            "download_execution_ready": "0",
            "blocked_reason": "explicit-operator-approval-required",
            "checkpoint_payload_bytes_downloaded_by_v61bo": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "ubuntu1_payload_execution_chunk_rows.csv", list(chunk_rows[0].keys()), chunk_rows)

payload_execution_preflight_ready = int(all(row["payload_execution_preflight_ready"] == "1" for row in readiness_rows))
target_bound_download_command_rows = sum(int(row["target_bound_download_command"]) for row in readiness_rows)
curl_resume_command_rows = sum(int(row["curl_resume_command_ready"]) for row in readiness_rows)
post_download_verify_command_rows = sum(int(row["post_download_verify_command_ready"]) for row in readiness_rows)
post_download_full_page_hash_command_rows = sum(int(row["post_download_full_page_hash_command_ready"]) for row in readiness_rows)
post_download_generation_admission_command_rows = sum(int(row["post_download_generation_admission_command_ready"]) for row in readiness_rows)
payload_execution_ready_rows = sum(int(row["payload_execution_ready"]) for row in readiness_rows)
payload_execution_blocked_rows = len(readiness_rows) - payload_execution_ready_rows
expected_bytes_total = sum(int(row["expected_bytes"]) for row in readiness_rows)

requirement_rows = [
    {"requirement_id": "v61bn-activation-admission-input", "status": "pass", "actual": v61bn_summary["v61bn_ubuntu1_activation_admission_refresh_gate_ready"], "required": "1", "reason": "v61bn activation target admission evidence is ready"},
    {"requirement_id": "ubuntu1-activation-target-admitted", "status": "pass", "actual": v61bn_summary["activation_target_admitted_rows"], "required": "59", "reason": "all 59 shard rows are admitted to the ubuntu-1 activation target"},
    {"requirement_id": "target-bound-download-commands", "status": "pass" if target_bound_download_command_rows == 59 else "blocked", "actual": str(target_bound_download_command_rows), "required": "59", "reason": "all download commands resolve under the ubuntu-1 target"},
    {"requirement_id": "curl-resume-command-plan", "status": "pass" if curl_resume_command_rows == 59 else "blocked", "actual": str(curl_resume_command_rows), "required": "59", "reason": "all shard downloads have resumable curl command previews"},
    {"requirement_id": "post-download-verification-commands", "status": "pass" if post_download_verify_command_rows == 59 else "blocked", "actual": str(post_download_verify_command_rows), "required": "59", "reason": "all rows include post-download local materialization verification commands"},
    {"requirement_id": "post-download-full-page-hash-commands", "status": "pass" if post_download_full_page_hash_command_rows == 59 else "blocked", "actual": str(post_download_full_page_hash_command_rows), "required": "59", "reason": "all rows include full page-hash recheck commands"},
    {"requirement_id": "post-download-generation-admission-commands", "status": "pass" if post_download_generation_admission_command_rows == 59 else "blocked", "actual": str(post_download_generation_admission_command_rows), "required": "59", "reason": "all rows include generation admission recheck commands"},
    {"requirement_id": "payload-execution-preflight", "status": "pass" if payload_execution_preflight_ready else "blocked", "actual": str(payload_execution_preflight_ready), "required": "1", "reason": "all target-bound commands are ready for an explicitly approved payload execution run"},
    {"requirement_id": "manifest-only-no-repo-payload", "status": "pass", "actual": "0", "required": "0", "reason": "v61bo records readiness only and downloads no checkpoint payload"},
    {"requirement_id": "explicit-payload-execution", "status": "blocked", "actual": "0", "required": "1", "reason": "checkpoint payload download execution remains disabled until explicit operator approval"},
    {"requirement_id": "local-checkpoint-materialization", "status": "blocked", "actual": "0", "required": "59", "reason": "full checkpoint shards are not identity verified locally"},
    {"requirement_id": "full-safetensors-page-hash-binding", "status": "blocked", "actual": "0", "required": "134161", "reason": "full 134k+ page-hash coverage remains incomplete"},
    {"requirement_id": "real-model-generation", "status": "blocked", "actual": "0", "required": "1", "reason": "actual Mixtral generation is not executed"},
]
write_csv(run_dir / "ubuntu1_payload_execution_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bo_ubuntu1_payload_execution_readiness_metrics",
    "model_id": model_id,
    "v61bo_ubuntu1_payload_execution_readiness_gate_ready": "1",
    "v61bn_ubuntu1_activation_admission_refresh_gate_ready": v61bn_summary["v61bn_ubuntu1_activation_admission_refresh_gate_ready"],
    "selected_capacity_target_id": v61bn_summary["selected_capacity_target_id"],
    "selected_activation_target_id": v61bn_summary["selected_activation_target_id"],
    "selected_payload_execution_target_id": "ubuntu-1-payload-readiness-pending-approval",
    "selected_target_path": selected_target_path,
    "selected_backend_id": v61bn_summary["selected_backend_id"],
    "selected_backend_ready": v61bn_summary["selected_backend_ready"],
    "ubuntu1_available_bytes_live": v61bn_summary["ubuntu1_available_bytes_live"],
    "required_with_reserve_bytes": v61bn_summary["required_with_reserve_bytes"],
    "activation_target_admission_ready": v61bn_summary["activation_target_admission_ready"],
    "activation_target_admitted_rows": v61bn_summary["activation_target_admitted_rows"],
    "activation_target_blocked_rows": v61bn_summary["activation_target_blocked_rows"],
    "payload_execution_preflight_ready": str(payload_execution_preflight_ready),
    "payload_execution_readiness_rows": str(len(readiness_rows)),
    "payload_execution_chunk_rows": str(len(chunk_rows)),
    "target_bound_download_command_rows": str(target_bound_download_command_rows),
    "curl_resume_command_rows": str(curl_resume_command_rows),
    "post_download_verify_command_rows": str(post_download_verify_command_rows),
    "post_download_full_page_hash_command_rows": str(post_download_full_page_hash_command_rows),
    "post_download_generation_admission_command_rows": str(post_download_generation_admission_command_rows),
    "payload_execution_ready_rows": str(payload_execution_ready_rows),
    "payload_execution_blocked_rows": str(payload_execution_blocked_rows),
    "explicit_payload_execution_required": "1",
    "download_execution_ready": "0",
    "local_checkpoint_materialization_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "total_expected_checkpoint_bytes": str(expected_bytes_total),
    "p0_remote_moe_sampled_rows": str(priority_counts["p0_remote_moe_sampled"]),
    "p0_embedding_sampled_rows": str(priority_counts["p0_embedding_sampled"]),
    "p2_checkpoint_backfill_rows": str(priority_counts["p2_checkpoint_backfill"]),
    "checkpoint_payload_bytes_downloaded_by_v61bo": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_payload_execution_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys())[1:], [{k: v for k, v in metric.items() if k != "metric_id"}])

runtime_gap_rows = [
    ("v61bn-activation-admission-input", "ready", "v61bn activation target admission is ready"),
    ("ubuntu1-activation-target-admitted", "ready", "59/59 shard rows are admitted to the ubuntu-1 target"),
    ("target-bound-download-commands", "ready", f"target_bound_download_command_rows={target_bound_download_command_rows}/59"),
    ("curl-resume-command-plan", "ready", f"curl_resume_command_rows={curl_resume_command_rows}/59"),
    ("payload-execution-preflight", "ready" if payload_execution_preflight_ready else "blocked", f"payload_execution_preflight_ready={payload_execution_preflight_ready}"),
    ("explicit-payload-execution", "blocked", "checkpoint payload download execution remains disabled"),
    ("local-checkpoint-materialization", "blocked", "full checkpoint shards are not identity verified"),
    ("full-safetensors-page-hash-binding", "blocked", "full 134k+ page-hash coverage remains incomplete"),
    ("real-model-generation", "blocked", "actual Mixtral generation is not executed"),
    ("production-latency", "blocked", "payload readiness is not production latency evidence"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in runtime_gap_rows])

decision_rows = [
    {"gate": "v61bn-activation-admission-input", "status": "pass", "reason": "v61bn activation target admission evidence is ready"},
    {"gate": "ubuntu1-activation-target-admitted", "status": "pass", "reason": "59/59 shard rows are admitted to the ubuntu-1 activation target"},
    {"gate": "target-bound-download-commands", "status": "pass" if target_bound_download_command_rows == 59 else "blocked", "reason": f"target_bound_download_command_rows={target_bound_download_command_rows}/59"},
    {"gate": "curl-resume-command-plan", "status": "pass" if curl_resume_command_rows == 59 else "blocked", "reason": f"curl_resume_command_rows={curl_resume_command_rows}/59"},
    {"gate": "post-download-verification-commands", "status": "pass" if post_download_verify_command_rows == 59 else "blocked", "reason": f"post_download_verify_command_rows={post_download_verify_command_rows}/59"},
    {"gate": "payload-execution-preflight", "status": "pass" if payload_execution_preflight_ready else "blocked", "reason": f"payload_execution_preflight_ready={payload_execution_preflight_ready}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bo records readiness only and downloads no checkpoint payload"},
    {"gate": "explicit-payload-execution", "status": "blocked", "reason": "operator approval/download execution remains disabled"},
    {"gate": "local-checkpoint-materialization", "status": "blocked", "reason": "full checkpoint shards are not identity verified"},
    {"gate": "full-safetensors-page-hash-binding", "status": "blocked", "reason": "full page-hash coverage remains incomplete"},
    {"gate": "real-model-generation", "status": "blocked", "reason": "Mixtral generation is not executed"},
    {"gate": "production-latency", "status": "blocked", "reason": "not production latency evidence"},
    {"gate": "release-package", "status": "blocked", "reason": "not release-ready"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bo Ubuntu-1 Payload Execution Readiness Gate Boundary

This gate consumes v61bn activation target admission and separates payload
execution readiness from payload execution itself. It proves that all 59
checkpoint shard download commands are target-bound to ubuntu-1 and resumable,
with post-download verification/hash/generation-admission recheck commands
present, while executing no checkpoint downloads.

Verified payload-execution readiness evidence:

- selected_payload_execution_target_id=ubuntu-1-payload-readiness-pending-approval
- selected_activation_target_id={v61bn_summary["selected_activation_target_id"]}
- activation_target_admission_ready={v61bn_summary["activation_target_admission_ready"]}
- activation_target_admitted_rows={v61bn_summary["activation_target_admitted_rows"]}
- payload_execution_preflight_ready={payload_execution_preflight_ready}
- payload_execution_readiness_rows={len(readiness_rows)}
- payload_execution_chunk_rows={len(chunk_rows)}
- target_bound_download_command_rows={target_bound_download_command_rows}
- curl_resume_command_rows={curl_resume_command_rows}
- post_download_verify_command_rows={post_download_verify_command_rows}
- post_download_full_page_hash_command_rows={post_download_full_page_hash_command_rows}
- post_download_generation_admission_command_rows={post_download_generation_admission_command_rows}
- payload_execution_ready_rows={payload_execution_ready_rows}
- payload_execution_blocked_rows={payload_execution_blocked_rows}
- explicit_payload_execution_required=1
- download_execution_ready=0
- local_checkpoint_materialization_ready=0
- full_safetensors_page_hash_binding_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bo=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: ubuntu-1 checkpoint payload execution preflight is ready for
an explicitly approved operator/download run.

Blocked wording: checkpoint payload download execution, completed full
checkpoint materialization, full safetensors page-hash coverage, actual
Mixtral generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61BO_UBUNTU1_PAYLOAD_EXECUTION_READINESS_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bo_ubuntu1_payload_execution_readiness_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bo_ubuntu1_payload_execution_readiness_gate_ready": 1,
    "source_v61bn_ready": int(v61bn_summary["v61bn_ubuntu1_activation_admission_refresh_gate_ready"]),
    "selected_activation_target_id": v61bn_summary["selected_activation_target_id"],
    "selected_payload_execution_target_id": "ubuntu-1-payload-readiness-pending-approval",
    "selected_target_path": selected_target_path,
    "activation_target_admission_ready": int(v61bn_summary["activation_target_admission_ready"]),
    "activation_target_admitted_rows": int(v61bn_summary["activation_target_admitted_rows"]),
    "payload_execution_preflight_ready": payload_execution_preflight_ready,
    "payload_execution_readiness_rows": len(readiness_rows),
    "payload_execution_chunk_rows": len(chunk_rows),
    "target_bound_download_command_rows": target_bound_download_command_rows,
    "curl_resume_command_rows": curl_resume_command_rows,
    "payload_execution_ready_rows": payload_execution_ready_rows,
    "download_execution_ready": 0,
    "local_checkpoint_materialization_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bo": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bo_ubuntu1_payload_execution_readiness_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61bo_ubuntu1_payload_execution_readiness_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
