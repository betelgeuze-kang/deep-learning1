#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ff_post_fe_real_manifest_replay_readiness_matrix"
RUN_ID="${V61FF_RUN_ID:-matrix_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ff_post_fe_real_manifest_replay_readiness_matrix_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ch_real_model_page_manifest_release_index.sh" >/dev/null
V61CO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61co_real_manifest_runtime_execution_admission_bridge.sh" >/dev/null
V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
V61FE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh" >/dev/null

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
matrix_dir = run_dir / "real_manifest_replay_readiness_matrix"
matrix_dir.mkdir(parents=True, exist_ok=True)


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


def pass_block(flag):
    return "pass" if flag else "blocked"


def ready_blocked(flag):
    return "ready" if flag else "blocked"


source_specs = {
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
    "v61fe": {
        "summary": results / "v61fe_post_fd_real_return_replay_admission_guard_summary.csv",
        "decision": results / "v61fe_post_fd_real_return_replay_admission_guard_decision.csv",
        "dir": results / "v61fe_post_fd_real_return_replay_admission_guard" / "guard_001",
        "ready_field": "v61fe_post_fd_real_return_replay_admission_guard_ready",
    },
}

summaries = {}
for label, spec in source_specs.items():
    if not spec["summary"].is_file():
        raise SystemExit(f"missing v61ff source summary: {spec['summary']}")
    summaries[label] = read_csv(spec["summary"])[0]
    if summaries[label].get(spec["ready_field"]) != "1":
        raise SystemExit(f"v61ff requires {label} {spec['ready_field']}=1")
    copy(spec["summary"], f"source_{label}/{spec['summary'].name}")
    if spec["decision"].is_file():
        copy(spec["decision"], f"source_{label}/{spec['decision'].name}")

source_artifacts = [
    ("v61ch", "page_manifest_release_index_source_artifact_rows.csv"),
    ("v61ch", "page_manifest_release_index_file_rows.csv"),
    ("v61ch", "page_manifest_release_index_requirement_rows.csv"),
    ("v61ch", "release_index/MANIFEST_INDEX.csv"),
    ("v61ch", "release_index/ZERO_PAYLOAD_BOUNDARY.md"),
    ("v61co", "real_manifest_runtime_execution_admission_rows.csv"),
    ("v61co", "real_manifest_runtime_execution_admission_metric_rows.csv"),
    ("v61co", "real_manifest_runtime_execution_admission_requirement_rows.csv"),
    ("v61dg", "post_full_shard_runtime_evidence_rows.csv"),
    ("v61dg", "runtime_evidence_promotion_metric_rows.csv"),
    ("v61dg", "runtime_evidence_claim_boundary_rows.csv"),
    ("v61fe", "post_fd_real_return_replay_admission_guard_rows.csv"),
    ("v61fe", "post_fd_real_return_replay_chain_rows.csv"),
    ("v61fe", "post_fd_blocked_delta_snapshot_rows.csv"),
    ("v61fe", "real_return_replay_admission_guard/RUN_REAL_RETURN_REPLAY_IF_ADMITTED.sh"),
]
for label, rel in source_artifacts:
    src = source_specs[label]["dir"] / rel
    if not src.is_file():
        raise SystemExit(f"missing v61ff source artifact: {src}")
    copy(src, f"source_{label}/{rel}")

v61ch = summaries["v61ch"]
v61co = summaries["v61co"]
v61dg = summaries["v61dg"]
v61fe = summaries["v61fe"]

generation_execution_admitted = as_int(v61dg, "generation_execution_admitted_rows")
generation_execution_total = as_int(v61dg, "generation_execution_admission_rows")
accepted_generation_artifacts = as_int(v61dg, "accepted_generation_result_artifacts")
expected_generation_artifacts = as_int(v61dg, "expected_generation_result_artifacts")

matrix_rows = [
    {
        "matrix_id": "01-zero-payload-page-manifest-release-index",
        "source_gate": "v61ch",
        "status": ready_blocked(v61ch["redistributable_manifest_index_ready"] == "1"),
        "ready": v61ch["redistributable_manifest_index_ready"],
        "observed": f"source_artifact_rows={v61ch['source_artifact_rows']}; release_index_file_rows={v61ch['release_index_file_rows']}",
        "required_next": "keep zero checkpoint payload boundary",
    },
    {
        "matrix_id": "02-full-checkpoint-materialization",
        "source_gate": "v61dg",
        "status": ready_blocked(v61dg["full_checkpoint_materialization_ready"] == "1"),
        "ready": v61dg["full_checkpoint_materialization_ready"],
        "observed": f"ready_checkpoint_materialization_shard_rows={v61dg['ready_checkpoint_materialization_shard_rows']}/{v61dg['checkpoint_shard_rows']}",
        "required_next": "keep shards outside repo",
    },
    {
        "matrix_id": "03-full-safetensors-page-hash-binding",
        "source_gate": "v61dg",
        "status": ready_blocked(v61dg["full_safetensors_page_hash_binding_ready"] == "1"),
        "ready": v61dg["full_safetensors_page_hash_binding_ready"],
        "observed": f"total_verified_page_hash_rows={v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}",
        "required_next": "bind generation admission only through reviewed returns",
    },
    {
        "matrix_id": "04-rocm-page-kernel-measurement",
        "source_gate": "v61dg",
        "status": ready_blocked(v61dg["gpu_page_dequant_matmul_measurement_ready"] == "1"),
        "ready": v61dg["gpu_page_dequant_matmul_measurement_ready"],
        "observed": f"gpu_kernel_avg_ms={v61dg['gpu_kernel_avg_ms']}; gpu_page_dequant_gflops={v61dg['gpu_page_dequant_gflops']}",
        "required_next": "do not promote to production latency",
    },
    {
        "matrix_id": "05-kv-cache-residency-policy",
        "source_gate": "v61dg",
        "status": ready_blocked(v61dg["kv_cache_policy_ready"] == "1"),
        "ready": v61dg["kv_cache_policy_ready"],
        "observed": f"host_ram_kv_spill_enabled={v61dg['host_ram_kv_spill_enabled']}; max_evicted_nvme_bytes={v61dg['max_evicted_nvme_bytes']}",
        "required_next": "keep host RAM spill disabled",
    },
    {
        "matrix_id": "06-real-manifest-runtime-execution-admission",
        "source_gate": "v61co",
        "status": ready_blocked(v61co["real_manifest_runtime_execution_admission_ready"] == "1"),
        "ready": v61co["real_manifest_runtime_execution_admission_ready"],
        "observed": f"runtime_execution_admitted_rows={v61co['runtime_execution_admitted_rows']}/{v61co['runtime_execution_candidate_rows']}",
        "required_next": "do not confuse seed admission with actual generation",
    },
    {
        "matrix_id": "07-v61fe-replay-admission-guard-ready",
        "source_gate": "v61fe",
        "status": ready_blocked(v61fe["v61fe_post_fd_real_return_replay_admission_guard_ready"] == "1"),
        "ready": v61fe["v61fe_post_fd_real_return_replay_admission_guard_ready"],
        "observed": f"guard_rows={v61fe['guard_rows']}; ready_chain_rows={v61fe['ready_chain_rows']}/{v61fe['chain_rows']}",
        "required_next": "supply real v53/v61 return roots with provenance",
    },
    {
        "matrix_id": "08-dual-real-return-roots-supplied",
        "source_gate": "v61fe",
        "status": "blocked",
        "ready": v61fe["dual_roots_supplied"],
        "observed": f"dual_roots_supplied={v61fe['dual_roots_supplied']}; dual_real_provenance_ready={v61fe['dual_real_provenance_ready']}",
        "required_next": "provide real external return roots",
    },
    {
        "matrix_id": "09-real-return-replay-admission",
        "source_gate": "v61fe",
        "status": "blocked",
        "ready": v61fe["real_return_replay_admission_ready"],
        "observed": f"real_return_replay_admission_ready={v61fe['real_return_replay_admission_ready']}; open_delta_rows={v61fe['open_delta_rows']}",
        "required_next": "rerun guarded replay after roots exist",
    },
    {
        "matrix_id": "10-row-acceptance-ready",
        "source_gate": "v61fe",
        "status": "blocked",
        "ready": "0",
        "observed": "row_acceptance_ready=0",
        "required_next": "downstream v53/v61 row acceptance must close",
    },
    {
        "matrix_id": "11-generation-execution-admission",
        "source_gate": "v61dg",
        "status": "blocked",
        "ready": "0",
        "observed": f"generation_execution_admitted_rows={generation_execution_admitted}/{generation_execution_total}",
        "required_next": "admit 1000/1000 generation execution rows",
    },
    {
        "matrix_id": "12-generation-result-artifact-acceptance",
        "source_gate": "v61dg",
        "status": "blocked",
        "ready": "0",
        "observed": f"accepted_generation_result_artifacts={accepted_generation_artifacts}/{expected_generation_artifacts}",
        "required_next": "return five generation result artifacts",
    },
    {
        "matrix_id": "13-actual-model-generation",
        "source_gate": "v61dg",
        "status": "blocked",
        "ready": v61dg["actual_model_generation_ready"],
        "observed": f"actual_model_generation_ready={v61dg['actual_model_generation_ready']}",
        "required_next": "requires replay, row acceptance, execution admission, and result acceptance",
    },
    {
        "matrix_id": "14-production-latency-claim",
        "source_gate": "v61dg",
        "status": "blocked",
        "ready": v61dg["production_latency_claim_ready"],
        "observed": f"production_latency_claim_ready={v61dg['production_latency_claim_ready']}",
        "required_next": "requires production-ish latency report over actual generation",
    },
    {
        "matrix_id": "15-near-frontier-quality-claim",
        "source_gate": "v61dg",
        "status": "blocked",
        "ready": v61dg["near_frontier_claim_ready"],
        "observed": f"near_frontier_claim_ready={v61dg['near_frontier_claim_ready']}",
        "required_next": "requires accepted blind review/generation evidence",
    },
    {
        "matrix_id": "16-real-release-package",
        "source_gate": "v61dg",
        "status": "blocked",
        "ready": v61dg["real_release_package_ready"],
        "observed": f"real_release_package_ready={v61dg['real_release_package_ready']}",
        "required_next": "requires release audit and external review",
    },
]
write_csv(run_dir / "post_fe_real_manifest_replay_readiness_rows.csv", list(matrix_rows[0].keys()), matrix_rows)
write_csv(matrix_dir / "REAL_MANIFEST_REPLAY_READINESS_ROWS.csv", list(matrix_rows[0].keys()), matrix_rows)

blocker_rows = [row for row in matrix_rows if row["status"] == "blocked"]
write_csv(run_dir / "post_fe_real_manifest_replay_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)
write_csv(matrix_dir / "REAL_MANIFEST_REPLAY_BLOCKER_ROWS.csv", list(blocker_rows[0].keys()), blocker_rows)

command_rows = [
    {
        "command_id": "01-verify-page-manifest-release-index",
        "command": "./experiments/test_v61ch_real_model_page_manifest_release_index.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify zero-payload release index",
    },
    {
        "command_id": "02-verify-runtime-admission-bridge",
        "command": "./experiments/test_v61co_real_manifest_runtime_execution_admission_bridge.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify 37/37 runtime seed admission rows",
    },
    {
        "command_id": "03-verify-post-full-shard-runtime-evidence",
        "command": "./experiments/test_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify full-shard runtime evidence boundary",
    },
    {
        "command_id": "04-verify-replay-admission-guard",
        "command": "./experiments/test_v61fe_post_fd_real_return_replay_admission_guard.sh",
        "ready_to_run_now": "1",
        "expected_effect": "verify fail-closed replay guard",
    },
    {
        "command_id": "05-run-real-replay-if-admitted",
        "command": "real_manifest_replay_readiness_matrix/RUN_REAL_MANIFEST_REPLAY_IF_ADMITTED.sh",
        "ready_to_run_now": "0",
        "expected_effect": "requires real return roots; fail closed without them",
    },
]
write_csv(run_dir / "post_fe_real_manifest_replay_command_rows.csv", list(command_rows[0].keys()), command_rows)
write_csv(matrix_dir / "REAL_MANIFEST_REPLAY_COMMAND_ROWS.csv", list(command_rows[0].keys()), command_rows)

operator_script = matrix_dir / "RUN_REAL_MANIFEST_REPLAY_IF_ADMITTED.sh"
operator_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            ': "${V61FF_V53_RETURN_ROOT:?set V61FF_V53_RETURN_ROOT}"',
            ': "${V61FF_V61_RETURN_ROOT:?set V61FF_V61_RETURN_ROOT}"',
            ': "${V61FF_V53_RETURN_PROVENANCE:?set V61FF_V53_RETURN_PROVENANCE}"',
            ': "${V61FF_V61_RETURN_PROVENANCE:?set V61FF_V61_RETURN_PROVENANCE}"',
            'if [[ "$V61FF_V53_RETURN_PROVENANCE" != "real-external-return-bundle" ]]; then',
            "  echo 'v53 provenance must be real-external-return-bundle' >&2",
            "  exit 2",
            "fi",
            'if [[ "$V61FF_V61_RETURN_PROVENANCE" != "real-generation-intake-return-bundle" ]]; then',
            "  echo 'v61 provenance must be real-generation-intake-return-bundle' >&2",
            "  exit 2",
            "fi",
            'if [[ ! -d "$V61FF_V53_RETURN_ROOT" || ! -d "$V61FF_V61_RETURN_ROOT" ]]; then',
            "  echo 'both real return roots must exist' >&2",
            "  exit 2",
            "fi",
            "V61CH_REUSE_EXISTING=1 ./experiments/run_v61ch_real_model_page_manifest_release_index.sh",
            "V61CO_REUSE_EXISTING=1 ./experiments/run_v61co_real_manifest_runtime_execution_admission_bridge.sh",
            "V61DG_REUSE_EXISTING=1 ./experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh",
            'V61FE_V53_RETURN_ROOT="$V61FF_V53_RETURN_ROOT" \\',
            'V61FE_V61_RETURN_ROOT="$V61FF_V61_RETURN_ROOT" \\',
            'V61FE_V53_RETURN_PROVENANCE="$V61FF_V53_RETURN_PROVENANCE" \\',
            'V61FE_V61_RETURN_PROVENANCE="$V61FF_V61_RETURN_PROVENANCE" \\',
            "./experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(operator_script, 0o755)

readme = matrix_dir / "REAL_MANIFEST_REPLAY_SUMMARY.md"
readme.write_text(
    "\n".join(
        [
            "# v61ff Real Manifest Replay Readiness Matrix",
            "",
            "This matrix binds the real-model page manifest and full-shard runtime evidence",
            "to the post-v61fe replay admission guard. It is intentionally fail-closed:",
            "without real external return roots, replay admission, row acceptance, actual",
            "generation, latency, quality, and release claims remain blocked.",
            "",
            f"- matrix_rows={len(matrix_rows)}",
            f"- ready_matrix_rows={sum(row['status'] == 'ready' for row in matrix_rows)}",
            f"- blocked_matrix_rows={sum(row['status'] == 'blocked' for row in matrix_rows)}",
            f"- checkpoint_shard_rows={v61dg['checkpoint_shard_rows']}",
            f"- total_verified_page_hash_rows={v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}",
            f"- runtime_execution_admitted_rows={v61co['runtime_execution_admitted_rows']}/{v61co['runtime_execution_candidate_rows']}",
            f"- real_return_replay_admission_ready={v61fe['real_return_replay_admission_ready']}",
            "- row_acceptance_ready=0",
            f"- actual_model_generation_ready={v61dg['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61ff proves the real page-manifest/runtime evidence is ready to be guarded by replay admission.",
            "",
            "Blocked wording:",
            "- Do not claim actual model generation, production latency, near-frontier quality, or release readiness from v61ff.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61ff-post-fe-real-manifest-replay-readiness-matrix",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "matrix_rows": len(matrix_rows),
    "ready_matrix_rows": sum(row["status"] == "ready" for row in matrix_rows),
    "blocked_matrix_rows": sum(row["status"] == "blocked" for row in matrix_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "real_return_replay_admission_ready": as_int(v61fe, "real_return_replay_admission_ready"),
    "actual_model_generation_ready": as_int(v61dg, "actual_model_generation_ready"),
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(matrix_dir / "MATRIX_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = matrix_dir / "VERIFY_REAL_MANIFEST_REPLAY_MATRIX.sh"
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
            "for line in (root / 'MATRIX_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'MATRIX_MANIFEST.json').read_text(encoding='utf-8'))",
            "rows = list(csv.DictReader((root / 'REAL_MANIFEST_REPLAY_READINESS_ROWS.csv').open(newline='', encoding='utf-8')))",
            "commands = list(csv.DictReader((root / 'REAL_MANIFEST_REPLAY_COMMAND_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(rows) != manifest['matrix_rows']:",
            "    raise SystemExit('matrix row count mismatch')",
            "if sum(row['status'] == 'ready' for row in rows) != manifest['ready_matrix_rows']:",
            "    raise SystemExit('ready matrix count mismatch')",
            "if sum(row['status'] == 'blocked' for row in rows) != manifest['blocked_matrix_rows']:",
            "    raise SystemExit('blocked matrix count mismatch')",
            "if sum(row['ready_to_run_now'] == '1' for row in commands) != manifest['ready_command_rows']:",
            "    raise SystemExit('ready command count mismatch')",
            "if manifest['real_return_replay_admission_ready'] != 0:",
            "    raise SystemExit('replay admission must remain blocked')",
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

matrix_files_for_list = sorted(
    path
    for path in matrix_dir.rglob("*")
    if path.is_file() and path.name not in {"MATRIX_FILE_LIST.txt", "MATRIX_SHA256SUMS.txt"}
)
(matrix_dir / "MATRIX_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(matrix_dir)) for path in matrix_files_for_list) + "\n",
    encoding="utf-8",
)
matrix_files_for_hash = sorted(path for path in matrix_dir.rglob("*") if path.is_file() and path.name != "MATRIX_SHA256SUMS.txt")
(matrix_dir / "MATRIX_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(matrix_dir)}\n" for path in matrix_files_for_hash),
    encoding="utf-8",
)

ready_matrix_rows = sum(row["status"] == "ready" for row in matrix_rows)
blocked_matrix_rows = len(matrix_rows) - ready_matrix_rows
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
blocked_command_rows = len(command_rows) - ready_command_rows
matrix_file_rows = sum(1 for path in matrix_dir.rglob("*") if path.is_file())

summary = {
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": "1",
    "v61ch_real_model_page_manifest_release_index_ready": v61ch["v61ch_real_model_page_manifest_release_index_ready"],
    "v61co_real_manifest_runtime_execution_admission_bridge_ready": v61co["v61co_real_manifest_runtime_execution_admission_bridge_ready"],
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": v61dg["v61dg_post_full_shard_runtime_evidence_promotion_gate_ready"],
    "v61fe_post_fd_real_return_replay_admission_guard_ready": v61fe["v61fe_post_fd_real_return_replay_admission_guard_ready"],
    "matrix_rows": str(len(matrix_rows)),
    "ready_matrix_rows": str(ready_matrix_rows),
    "blocked_matrix_rows": str(blocked_matrix_rows),
    "blocker_rows": str(len(blocker_rows)),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(ready_command_rows),
    "blocked_command_rows": str(blocked_command_rows),
    "matrix_file_rows": str(matrix_file_rows),
    "metadata_only_matrix_file_rows": str(matrix_file_rows),
    "source_artifact_rows": v61ch["source_artifact_rows"],
    "release_index_file_rows": v61ch["release_index_file_rows"],
    "checkpoint_shard_rows": v61dg["checkpoint_shard_rows"],
    "ready_checkpoint_materialization_shard_rows": v61dg["ready_checkpoint_materialization_shard_rows"],
    "promotion_identity_verified_bytes": v61dg["promotion_identity_verified_bytes"],
    "total_required_page_hash_rows": v61dg["total_required_page_hash_rows"],
    "total_verified_page_hash_rows": v61dg["total_verified_page_hash_rows"],
    "full_safetensors_page_hash_binding_ready": v61dg["full_safetensors_page_hash_binding_ready"],
    "post_full_shard_runtime_evidence_ready": v61dg["post_full_shard_runtime_evidence_ready"],
    "runtime_execution_candidate_rows": v61co["runtime_execution_candidate_rows"],
    "runtime_execution_admitted_rows": v61co["runtime_execution_admitted_rows"],
    "real_manifest_runtime_execution_admission_ready": v61co["real_manifest_runtime_execution_admission_ready"],
    "guard_rows": v61fe["guard_rows"],
    "pass_guard_rows": v61fe["pass_guard_rows"],
    "blocked_guard_rows": v61fe["blocked_guard_rows"],
    "open_delta_rows": v61fe["open_delta_rows"],
    "dual_roots_supplied": v61fe["dual_roots_supplied"],
    "real_return_replay_admission_ready": v61fe["real_return_replay_admission_ready"],
    "row_acceptance_ready": "0",
    "generation_execution_admission_rows": v61dg["generation_execution_admission_rows"],
    "generation_execution_admitted_rows": v61dg["generation_execution_admitted_rows"],
    "expected_generation_result_artifacts": v61dg["expected_generation_result_artifacts"],
    "accepted_generation_result_artifacts": v61dg["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ff": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["matrix_id"], "status": pass_block(row["status"] == "ready"), "reason": row["observed"]}
    for row in matrix_rows
]
decision_rows.append(
    {
        "gate": "real-manifest-replay-readiness-matrix",
        "status": "pass",
        "reason": f"ready_matrix_rows={ready_matrix_rows}; blocked_matrix_rows={blocked_matrix_rows}",
    }
)
decision_rows.append(
    {
        "gate": "repo-checkpoint-payload",
        "status": "pass",
        "reason": "v61ff emits metadata-only matrix files",
    }
)
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FF_POST_FE_REAL_MANIFEST_REPLAY_READINESS_MATRIX_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61ff Post-v61fe Real Manifest Replay Readiness Matrix Boundary",
            "",
            f"- matrix_rows={summary['matrix_rows']}",
            f"- ready_matrix_rows={summary['ready_matrix_rows']}",
            f"- blocked_matrix_rows={summary['blocked_matrix_rows']}",
            f"- checkpoint_shard_rows={summary['ready_checkpoint_materialization_shard_rows']}/{summary['checkpoint_shard_rows']}",
            f"- total_verified_page_hash_rows={summary['total_verified_page_hash_rows']}/{summary['total_required_page_hash_rows']}",
            f"- post_full_shard_runtime_evidence_ready={summary['post_full_shard_runtime_evidence_ready']}",
            f"- runtime_execution_admitted_rows={summary['runtime_execution_admitted_rows']}/{summary['runtime_execution_candidate_rows']}",
            f"- guard_rows={summary['guard_rows']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- open_delta_rows={summary['open_delta_rows']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}",
            f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61ff binds real page-manifest/full-shard runtime evidence to a fail-closed replay admission matrix.",
            "",
            "Blocked wording:",
            "- Do not claim row acceptance, actual generation, production latency, near-frontier quality, or release readiness from v61ff alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61ff_post_fe_real_manifest_replay_readiness_matrix",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61ff_post_fe_real_manifest_replay_readiness_matrix_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ff_post_fe_real_manifest_replay_readiness_matrix_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
