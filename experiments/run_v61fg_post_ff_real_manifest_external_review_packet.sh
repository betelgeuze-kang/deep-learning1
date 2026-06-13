#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fg_post_ff_real_manifest_external_review_packet"
RUN_ID="${V61FG_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fg_post_ff_real_manifest_external_review_packet_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ch_real_model_page_manifest_release_index.sh" >/dev/null
V61CO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61co_real_manifest_runtime_execution_admission_bridge.sh" >/dev/null
V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
V61FF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ff_post_fe_real_manifest_replay_readiness_matrix.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
packet_dir = run_dir / "real_manifest_external_review_packet"
packet_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61ch": {
        "summary": results / "v61ch_real_model_page_manifest_release_index_summary.csv",
        "decision": results / "v61ch_real_model_page_manifest_release_index_decision.csv",
        "dir": results / "v61ch_real_model_page_manifest_release_index" / "index_001",
        "ready_field": "v61ch_real_model_page_manifest_release_index_ready",
    },
    "v61co": {
        "summary": results / "v61co_real_manifest_runtime_execution_admission_bridge_summary.csv",
        "decision": results / "v61co_real_manifest_runtime_execution_admission_bridge_decision.csv",
        "dir": results / "v61co_real_manifest_runtime_execution_admission_bridge" / "bridge_001",
        "ready_field": "v61co_real_manifest_runtime_execution_admission_bridge_ready",
    },
    "v61dg": {
        "summary": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
        "decision": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv",
        "dir": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate" / "gate_001",
        "ready_field": "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready",
    },
    "v61ff": {
        "summary": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv",
        "decision": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_decision.csv",
        "dir": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix" / "matrix_001",
        "ready_field": "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready",
    },
}

summaries = {}
for label, spec in sources.items():
    if not spec["summary"].is_file():
        raise SystemExit(f"missing v61fg source summary: {spec['summary']}")
    summaries[label] = read_csv(spec["summary"])[0]
    if summaries[label].get(spec["ready_field"]) != "1":
        raise SystemExit(f"v61fg requires {label} {spec['ready_field']}=1")
    copy(spec["summary"], f"source_{label}/{spec['summary'].name}")
    if spec["decision"].is_file():
        copy(spec["decision"], f"source_{label}/{spec['decision'].name}")

source_artifacts = [
    ("v61ch", "release_index/MANIFEST_INDEX.csv"),
    ("v61ch", "release_index/ZERO_PAYLOAD_BOUNDARY.md"),
    ("v61ch", "page_manifest_release_index_source_artifact_rows.csv"),
    ("v61ch", "page_manifest_release_index_file_rows.csv"),
    ("v61co", "real_manifest_runtime_execution_admission_rows.csv"),
    ("v61co", "real_manifest_runtime_execution_admission_metric_rows.csv"),
    ("v61dg", "post_full_shard_runtime_evidence_rows.csv"),
    ("v61dg", "runtime_evidence_claim_boundary_rows.csv"),
    ("v61ff", "post_fe_real_manifest_replay_readiness_rows.csv"),
    ("v61ff", "post_fe_real_manifest_replay_blocker_rows.csv"),
    ("v61ff", "real_manifest_replay_readiness_matrix/REAL_MANIFEST_REPLAY_SUMMARY.md"),
]
for label, rel in source_artifacts:
    src = sources[label]["dir"] / rel
    if not src.is_file():
        raise SystemExit(f"missing v61fg source artifact: {src}")
    copy(src, f"source_{label}/{rel}")

v61ch = summaries["v61ch"]
v61co = summaries["v61co"]
v61dg = summaries["v61dg"]
v61ff = summaries["v61ff"]

checklist_rows = [
    {
        "review_item_id": "01-zero-payload-release-index",
        "source_gate": "v61ch",
        "status": "ready",
        "observed": f"source_artifact_rows={v61ch['source_artifact_rows']}; release_index_file_rows={v61ch['release_index_file_rows']}; redistributed_checkpoint_payload_bytes={v61ch['redistributed_checkpoint_payload_bytes']}",
        "review_instruction": "verify the release index contains metadata/hash/offset evidence only",
    },
    {
        "review_item_id": "02-checkpoint-shard-identity",
        "source_gate": "v61dg",
        "status": "ready",
        "observed": f"ready_checkpoint_materialization_shard_rows={v61dg['ready_checkpoint_materialization_shard_rows']}/{v61dg['checkpoint_shard_rows']}; promotion_identity_verified_bytes={v61dg['promotion_identity_verified_bytes']}",
        "review_instruction": "confirm full shard identity is external to the repository",
    },
    {
        "review_item_id": "03-full-page-hash-binding",
        "source_gate": "v61dg",
        "status": "ready",
        "observed": f"total_verified_page_hash_rows={v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}",
        "review_instruction": "confirm all safetensors pages have hash coverage",
    },
    {
        "review_item_id": "04-rocm-page-kernel-measurement",
        "source_gate": "v61dg",
        "status": "ready",
        "observed": f"gpu_kernel_avg_ms={v61dg['gpu_kernel_avg_ms']}; gpu_page_dequant_gflops={v61dg['gpu_page_dequant_gflops']}",
        "review_instruction": "treat page-kernel timing as kernel evidence, not production latency",
    },
    {
        "review_item_id": "05-kv-cache-residency-policy",
        "source_gate": "v61dg",
        "status": "ready",
        "observed": f"kv_cache_policy_ready={v61dg['kv_cache_policy_ready']}; host_ram_kv_spill_enabled={v61dg['host_ram_kv_spill_enabled']}",
        "review_instruction": "confirm KV policy keeps host RAM spill disabled",
    },
    {
        "review_item_id": "06-runtime-seed-admission",
        "source_gate": "v61co",
        "status": "ready",
        "observed": f"runtime_execution_admitted_rows={v61co['runtime_execution_admitted_rows']}/{v61co['runtime_execution_candidate_rows']}",
        "review_instruction": "treat the 37-row seed admission as runtime-path evidence only",
    },
    {
        "review_item_id": "07-v61ff-readiness-matrix",
        "source_gate": "v61ff",
        "status": "ready",
        "observed": f"ready_matrix_rows={v61ff['ready_matrix_rows']}; blocked_matrix_rows={v61ff['blocked_matrix_rows']}",
        "review_instruction": "confirm the matrix keeps return/generation blockers closed",
    },
    {
        "review_item_id": "08-review-packet-verifier",
        "source_gate": "v61fg",
        "status": "ready",
        "observed": "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh emitted",
        "review_instruction": "run the local verifier before accepting this packet",
    },
    {
        "review_item_id": "09-real-return-roots",
        "source_gate": "v61fe",
        "status": "blocked",
        "observed": f"dual_roots_supplied={v61ff['dual_roots_supplied']}; real_return_replay_admission_ready={v61ff['real_return_replay_admission_ready']}",
        "review_instruction": "real external return roots are required before replay",
    },
    {
        "review_item_id": "10-row-acceptance",
        "source_gate": "v61ff",
        "status": "blocked",
        "observed": f"row_acceptance_ready={v61ff['row_acceptance_ready']}; open_delta_rows={v61ff['open_delta_rows']}",
        "review_instruction": "row acceptance is downstream of real returned artifacts",
    },
    {
        "review_item_id": "11-generation-execution-admission",
        "source_gate": "v61dg",
        "status": "blocked",
        "observed": f"generation_execution_admitted_rows={v61ff['generation_execution_admitted_rows']}/{v61ff['generation_execution_admission_rows']}",
        "review_instruction": "1000/1000 generation execution rows must be admitted",
    },
    {
        "review_item_id": "12-generation-result-acceptance",
        "source_gate": "v61dg",
        "status": "blocked",
        "observed": f"accepted_generation_result_artifacts={v61ff['accepted_generation_result_artifacts']}/{v61ff['expected_generation_result_artifacts']}",
        "review_instruction": "five generation-result artifacts must be returned and accepted",
    },
    {
        "review_item_id": "13-actual-generation-release",
        "source_gate": "v61dg",
        "status": "blocked",
        "observed": f"actual_model_generation_ready={v61ff['actual_model_generation_ready']}; production_latency_claim_ready={v61ff['production_latency_claim_ready']}; near_frontier_claim_ready={v61ff['near_frontier_claim_ready']}; real_release_package_ready={v61ff['real_release_package_ready']}",
        "review_instruction": "do not accept actual generation, latency, quality, or release claims from this packet alone",
    },
]
write_csv(run_dir / "post_ff_real_manifest_external_review_checklist_rows.csv", list(checklist_rows[0].keys()), checklist_rows)
write_csv(packet_dir / "REVIEW_CHECKLIST.csv", list(checklist_rows[0].keys()), checklist_rows)

blocker_rows = [row for row in checklist_rows if row["status"] == "blocked"]
write_csv(run_dir / "post_ff_real_manifest_external_review_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)
write_csv(packet_dir / "REVIEW_BLOCKER_ROWS.csv", list(blocker_rows[0].keys()), blocker_rows)

claim_rows = [
    {
        "claim": "zero-payload real page-manifest release index",
        "status": "allowed",
        "required_disclosure": "metadata/hash/offset evidence only; no checkpoint payload is redistributed",
    },
    {
        "claim": "full-shard and full-page-hash runtime evidence",
        "status": "allowed-with-boundary",
        "required_disclosure": "59/59 shards and 134161/134161 page hashes are evidence, not generation output",
    },
    {
        "claim": "ROCm page-kernel timing and KV residency policy",
        "status": "allowed-with-boundary",
        "required_disclosure": "kernel/policy evidence cannot be promoted to production latency",
    },
    {
        "claim": "37-row source-bound runtime seed admission",
        "status": "allowed-with-boundary",
        "required_disclosure": "seed runtime admission is not the 1000-query generation run",
    },
    {
        "claim": "actual Mixtral generation, near-frontier quality, production latency, or release readiness",
        "status": "blocked",
        "required_disclosure": "requires real return roots, row acceptance, execution admission, generation result acceptance, and release audit",
    },
]
write_csv(run_dir / "post_ff_real_manifest_external_review_claim_rows.csv", list(claim_rows[0].keys()), claim_rows)
write_csv(packet_dir / "REVIEW_CLAIM_BOUNDARY_ROWS.csv", list(claim_rows[0].keys()), claim_rows)

command_rows = [
    {
        "command_id": "01-verify-v61ch-release-index",
        "command": "V61CH_REUSE_EXISTING=1 ./experiments/test_v61ch_real_model_page_manifest_release_index.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify zero-payload release index",
    },
    {
        "command_id": "02-verify-v61co-runtime-admission",
        "command": "V61CO_REUSE_EXISTING=1 ./experiments/test_v61co_real_manifest_runtime_execution_admission_bridge.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify 37/37 runtime seed admission",
    },
    {
        "command_id": "03-verify-v61dg-runtime-evidence",
        "command": "V61DG_REUSE_EXISTING=1 ./experiments/test_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify full-shard runtime evidence",
    },
    {
        "command_id": "04-verify-v61ff-readiness-matrix",
        "command": "V61FF_REUSE_EXISTING=1 ./experiments/test_v61ff_post_fe_real_manifest_replay_readiness_matrix.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify fail-closed replay matrix",
    },
    {
        "command_id": "05-verify-review-packet",
        "command": "real_manifest_external_review_packet/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify packet checksums and row counts",
    },
    {
        "command_id": "06-run-real-replay-if-admitted",
        "command": "results/v61ff_post_fe_real_manifest_replay_readiness_matrix/matrix_001/real_manifest_replay_readiness_matrix/RUN_REAL_MANIFEST_REPLAY_IF_ADMITTED.sh",
        "ready_to_run_now": "0",
        "expected_effect": "blocked until real return roots exist",
    },
]
write_csv(run_dir / "post_ff_real_manifest_external_review_command_rows.csv", list(command_rows[0].keys()), command_rows)
write_csv(packet_dir / "REVIEW_REPRODUCE_COMMAND_ROWS.csv", list(command_rows[0].keys()), command_rows)

reproduce_script = packet_dir / "REPRODUCE_REVIEW_PACKET.sh"
reproduce_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "ROOT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/../../../..\" && pwd)\"",
            "cd \"$ROOT_DIR\"",
            "V61CH_REUSE_EXISTING=1 ./experiments/test_v61ch_real_model_page_manifest_release_index.sh",
            "V61CO_REUSE_EXISTING=1 ./experiments/test_v61co_real_manifest_runtime_execution_admission_bridge.sh",
            "V61DG_REUSE_EXISTING=1 ./experiments/test_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh",
            "V61FF_REUSE_EXISTING=1 ./experiments/test_v61ff_post_fe_real_manifest_replay_readiness_matrix.sh",
            "results/v61fg_post_ff_real_manifest_external_review_packet/packet_001/real_manifest_external_review_packet/VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh",
            "echo 'v61fg review packet reproduction completed; actual generation remains blocked'",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(reproduce_script, 0o755)

summary_md = packet_dir / "REVIEW_PACKET_SUMMARY.md"
summary_md.write_text(
    "\n".join(
        [
            "# v61fg Real Manifest External Review Packet",
            "",
            "This packet packages the zero-payload real page-manifest and full-shard",
            "runtime evidence for reviewer inspection. It is not a release package and",
            "does not contain checkpoint payload bytes or actual model generations.",
            "",
            f"- review_packet_rows={len(checklist_rows)}",
            f"- ready_review_packet_rows={sum(row['status'] == 'ready' for row in checklist_rows)}",
            f"- blocked_review_packet_rows={sum(row['status'] == 'blocked' for row in checklist_rows)}",
            f"- checkpoint_shard_rows={v61dg['ready_checkpoint_materialization_shard_rows']}/{v61dg['checkpoint_shard_rows']}",
            f"- total_verified_page_hash_rows={v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}",
            f"- runtime_execution_admitted_rows={v61co['runtime_execution_admitted_rows']}/{v61co['runtime_execution_candidate_rows']}",
            f"- real_return_replay_admission_ready={v61ff['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={v61ff['row_acceptance_ready']}",
            f"- actual_model_generation_ready={v61ff['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- reviewer-ready zero-payload real page-manifest evidence packet.",
            "",
            "Blocked wording:",
            "- actual generation, production latency, near-frontier quality, and release readiness remain blocked.",
            "",
        ]
    ),
    encoding="utf-8",
)

source_pointer_rows = [
    {"source_id": "v61ch-summary", "path": "source_v61ch/v61ch_real_model_page_manifest_release_index_summary.csv", "sha256": sha256(run_dir / "source_v61ch/v61ch_real_model_page_manifest_release_index_summary.csv")},
    {"source_id": "v61co-summary", "path": "source_v61co/v61co_real_manifest_runtime_execution_admission_bridge_summary.csv", "sha256": sha256(run_dir / "source_v61co/v61co_real_manifest_runtime_execution_admission_bridge_summary.csv")},
    {"source_id": "v61dg-summary", "path": "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv", "sha256": sha256(run_dir / "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv")},
    {"source_id": "v61ff-summary", "path": "source_v61ff/v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv", "sha256": sha256(run_dir / "source_v61ff/v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv")},
]
write_csv(packet_dir / "REVIEW_SOURCE_POINTERS.csv", list(source_pointer_rows[0].keys()), source_pointer_rows)

packet_manifest = {
    "manifest_scope": "v61fg-post-ff-real-manifest-external-review-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "review_packet_rows": len(checklist_rows),
    "ready_review_packet_rows": sum(row["status"] == "ready" for row in checklist_rows),
    "blocked_review_packet_rows": sum(row["status"] == "blocked" for row in checklist_rows),
    "review_command_rows": len(command_rows),
    "ready_review_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "real_return_replay_admission_ready": as_int(v61ff, "real_return_replay_admission_ready"),
    "row_acceptance_ready": as_int(v61ff, "row_acceptance_ready"),
    "actual_model_generation_ready": as_int(v61ff, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(packet_dir / "REVIEW_PACKET_MANIFEST.json").write_text(json.dumps(packet_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = packet_dir / "VERIFY_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import hashlib",
            "import json",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'REVIEW_PACKET_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'REVIEW_PACKET_MANIFEST.json').read_text(encoding='utf-8'))",
            "checklist = list(csv.DictReader((root / 'REVIEW_CHECKLIST.csv').open(newline='', encoding='utf-8')))",
            "commands = list(csv.DictReader((root / 'REVIEW_REPRODUCE_COMMAND_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(checklist) != manifest['review_packet_rows']:",
            "    raise SystemExit('review checklist row count mismatch')",
            "if sum(row['status'] == 'ready' for row in checklist) != manifest['ready_review_packet_rows']:",
            "    raise SystemExit('ready review row count mismatch')",
            "if sum(row['status'] == 'blocked' for row in checklist) != manifest['blocked_review_packet_rows']:",
            "    raise SystemExit('blocked review row count mismatch')",
            "if sum(row['ready_to_run_now'] == '1' for row in commands) != manifest['ready_review_command_rows']:",
            "    raise SystemExit('ready review command count mismatch')",
            "if manifest['real_return_replay_admission_ready'] != 0:",
            "    raise SystemExit('replay admission must remain blocked')",
            "if manifest['row_acceptance_ready'] != 0:",
            "    raise SystemExit('row acceptance must remain blocked')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "if manifest['checkpoint_payload_bytes_committed_to_repo'] != 0:",
            "    raise SystemExit('checkpoint payload must remain zero')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

packet_files_for_list = sorted(
    path
    for path in packet_dir.rglob("*")
    if path.is_file() and path.name not in {"REVIEW_PACKET_FILE_LIST.txt", "REVIEW_PACKET_SHA256SUMS.txt"}
)
(packet_dir / "REVIEW_PACKET_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(packet_dir)) for path in packet_files_for_list) + "\n",
    encoding="utf-8",
)
packet_files_for_hash = sorted(path for path in packet_dir.rglob("*") if path.is_file() and path.name != "REVIEW_PACKET_SHA256SUMS.txt")
(packet_dir / "REVIEW_PACKET_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(packet_dir)}\n" for path in packet_files_for_hash),
    encoding="utf-8",
)

review_packet_rows = len(checklist_rows)
ready_review_packet_rows = sum(row["status"] == "ready" for row in checklist_rows)
blocked_review_packet_rows = review_packet_rows - ready_review_packet_rows
review_command_rows = len(command_rows)
ready_review_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
blocked_review_command_rows = review_command_rows - ready_review_command_rows
packet_file_rows = sum(1 for path in packet_dir.rglob("*") if path.is_file())

summary = {
    "v61fg_post_ff_real_manifest_external_review_packet_ready": "1",
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": v61ff["v61ff_post_fe_real_manifest_replay_readiness_matrix_ready"],
    "v61ch_real_model_page_manifest_release_index_ready": v61ch["v61ch_real_model_page_manifest_release_index_ready"],
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": v61co["v61co_real_manifest_runtime_execution_admission_bridge_ready"],
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": v61dg["v61dg_post_full_shard_runtime_evidence_promotion_gate_ready"],
    "review_packet_rows": str(review_packet_rows),
    "ready_review_packet_rows": str(ready_review_packet_rows),
    "blocked_review_packet_rows": str(blocked_review_packet_rows),
    "claim_boundary_rows": str(len(claim_rows)),
    "blocked_claim_boundary_rows": str(sum(row["status"] == "blocked" for row in claim_rows)),
    "review_command_rows": str(review_command_rows),
    "ready_review_command_rows": str(ready_review_command_rows),
    "blocked_review_command_rows": str(blocked_review_command_rows),
    "packet_file_rows": str(packet_file_rows),
    "metadata_only_packet_file_rows": str(packet_file_rows),
    "source_pointer_rows": str(len(source_pointer_rows)),
    "page_manifest_external_review_packet_ready": "1",
    "real_manifest_runtime_evidence_review_ready": "1",
    "checkpoint_shard_rows": v61dg["checkpoint_shard_rows"],
    "ready_checkpoint_materialization_shard_rows": v61dg["ready_checkpoint_materialization_shard_rows"],
    "promotion_identity_verified_bytes": v61dg["promotion_identity_verified_bytes"],
    "total_required_page_hash_rows": v61dg["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61dg["total_verified_page_hash_rows"],
    "runtime_execution_candidate_rows": v61co["runtime_execution_candidate_rows"],
    "runtime_execution_admitted_rows": v61co["runtime_execution_admitted_rows"],
    "real_manifest_runtime_execution_admission_ready": v61co["real_manifest_runtime_execution_admission_ready"],
    "real_return_replay_admission_ready": v61ff["real_return_replay_admission_ready"],
    "row_acceptance_ready": v61ff["row_acceptance_ready"],
    "open_delta_rows": v61ff["open_delta_rows"],
    "generation_execution_admission_rows": v61ff["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61ff["generation_execution_admitted_rows"],
    "expected_generation_result_artifacts": v61ff["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61ff["accepted_generation_result_artifacts"],
    "external_review_return_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {
        "gate": row["review_item_id"],
        "status": "pass" if row["status"] == "ready" else "blocked",
        "reason": row["observed"],
    }
    for row in checklist_rows
]
decision_rows.extend(
    [
        {
            "gate": "external-review-packet-shape",
            "status": "pass",
            "reason": f"packet_file_rows={packet_file_rows}; review_packet_rows={review_packet_rows}",
        },
        {
            "gate": "repo-checkpoint-payload",
            "status": "pass",
            "reason": "v61fg emits metadata-only review packet files",
        },
    ]
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FG_POST_FF_REAL_MANIFEST_EXTERNAL_REVIEW_PACKET_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fg Post-v61ff Real Manifest External Review Packet Boundary",
            "",
            f"- review_packet_rows={summary['review_packet_rows']}",
            f"- ready_review_packet_rows={summary['ready_review_packet_rows']}",
            f"- blocked_review_packet_rows={summary['blocked_review_packet_rows']}",
            f"- page_manifest_external_review_packet_ready={summary['page_manifest_external_review_packet_ready']}",
            f"- checkpoint_shard_rows={summary['ready_checkpoint_materialization_shard_rows']}/{summary['checkpoint_shard_rows']}",
            f"- total_verified_page_hash_rows={summary['total_verified_page_hash_rows']}/{summary['total_required_page_hash_rows']}",
            f"- runtime_execution_admitted_rows={summary['runtime_execution_admitted_rows']}/{summary['runtime_execution_candidate_rows']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}",
            f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fg is a reviewer-ready zero-payload real page-manifest evidence packet.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, actual generation, production latency, near-frontier quality, or release readiness from v61fg alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fg_post_ff_real_manifest_external_review_packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fg_post_ff_real_manifest_external_review_packet_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fg_post_ff_real_manifest_external_review_packet_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
