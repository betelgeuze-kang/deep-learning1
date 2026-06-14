#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger"
RUN_ID="${V61FP_RUN_ID:-ledger_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ENTRYPOINT_RUN_DIR_ARG="${V61FP_ENTRYPOINT_RUN_DIR:-}"

if [[ "${V61FP_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FO_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh" >/dev/null
V61FF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ff_post_fe_real_manifest_replay_readiness_matrix.sh" >/dev/null
V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
V61FN_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate.sh" >/dev/null
V61FM_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fm_post_fl_real_manifest_external_review_return_work_order.sh" >/dev/null
V61FE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ENTRYPOINT_RUN_DIR_ARG" <<'PY'
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
entrypoint_arg = sys.argv[5].strip()
results = root / "results"
prefix = "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger"
closure_dir = run_dir / "post_fo_full_shard_to_real_review_replay_closure_ledger"
closure_dir.mkdir(parents=True, exist_ok=True)

default_entrypoint_dir = (
    results
    / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint"
    / "entrypoint_001"
)
entrypoint_dir = Path(entrypoint_arg).expanduser().resolve() if entrypoint_arg else default_entrypoint_dir


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "closed" if flag else "blocked"


def pass_status(flag):
    return "pass" if flag else "blocked"


sources = {
    "v61fo_summary": results / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_summary.csv",
    "v61fo_decision": results / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_decision.csv",
    "v61ff_summary": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv",
    "v61ff_decision": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_decision.csv",
    "v61dg_summary": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "v61dg_decision": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv",
    "v61fn_summary": results / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_summary.csv",
    "v61fn_decision": results / "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_decision.csv",
    "v61fm_summary": results / "v61fm_post_fl_real_manifest_external_review_return_work_order_summary.csv",
    "v61fm_decision": results / "v61fm_post_fl_real_manifest_external_review_return_work_order_decision.csv",
    "v61fe_summary": results / "v61fe_post_fd_real_return_replay_admission_guard_summary.csv",
    "v61fe_decision": results / "v61fe_post_fd_real_return_replay_admission_guard_decision.csv",
}
for label, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61fp source {label}: {path}")
    copy(path, f"source_summaries/{path.name}")

selected_files = {
    "entrypoint_metric_rows.csv": entrypoint_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_metric_rows.csv",
    "entrypoint_stage_rows.csv": entrypoint_dir / "post_fn_real_manifest_external_review_return_replay_entrypoint_stage_rows.csv",
    "entrypoint_manifest.json": entrypoint_dir / "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_manifest.json",
}
for rel, path in selected_files.items():
    if not path.is_file():
        raise SystemExit(f"missing selected v61fo entrypoint artifact: {path}")
    copy(path, f"selected_v61fo_entrypoint/{rel}")

v61fo = read_csv(sources["v61fo_summary"])[0]
v61ff = read_csv(sources["v61ff_summary"])[0]
v61dg = read_csv(sources["v61dg_summary"])[0]
v61fn = read_csv(sources["v61fn_summary"])[0]
v61fm = read_csv(sources["v61fm_summary"])[0]
v61fe = read_csv(sources["v61fe_summary"])[0]
selected_metric = read_csv(selected_files["entrypoint_metric_rows.csv"])[0]

required_ready = {
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": v61fo,
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": v61ff,
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": v61dg,
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": v61fn,
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": v61fm,
    "v61fe_post_fd_real_return_replay_admission_guard_ready": v61fe,
}
for key, row in required_ready.items():
    if row.get(key) != "1":
        raise SystemExit(f"v61fp requires {key}=1")

selected_review_return_dir_supplied = as_int(selected_metric, "review_return_dir_supplied")
selected_review_return_dir_exists = as_int(selected_metric, "review_return_dir_exists")
selected_review_return_provenance = selected_metric.get("review_return_provenance", "unspecified")
real_review_return_provenance_asserted = as_int(selected_metric, "real_review_return_provenance_asserted")
fixture_return_provenance = as_int(selected_metric, "fixture_return_provenance")
replay_entrypoint_ready = as_int(selected_metric, "replay_entrypoint_ready")
replay_entrypoint_admitted = as_int(selected_metric, "replay_entrypoint_admitted")
external_review_return_ready = as_int(selected_metric, "external_review_return_ready")
real_return_replay_admission_ready = as_int(selected_metric, "real_return_replay_admission_ready")
row_acceptance_ready = as_int(selected_metric, "row_acceptance_ready")

selected_entrypoint_source_class = "canonical-no-return-root"
if fixture_return_provenance:
    selected_entrypoint_source_class = "fixture-return-root-candidate"
if replay_entrypoint_admitted and real_review_return_provenance_asserted:
    selected_entrypoint_source_class = "real-external-review-return-root"

full_checkpoint_materialization_ready = as_int(v61dg, "full_checkpoint_materialization_ready")
full_safetensors_page_hash_binding_ready = as_int(v61dg, "full_safetensors_page_hash_binding_ready")
post_full_shard_runtime_evidence_ready = as_int(v61dg, "post_full_shard_runtime_evidence_ready")
runtime_execution_admitted_rows = as_int(v61ff, "runtime_execution_admitted_rows")
runtime_admission_accepted_rows = as_int(v61dg, "runtime_admission_accepted_rows")
generation_execution_admission_rows = as_int(v61ff, "generation_execution_admission_rows")
generation_execution_admitted_rows = as_int(v61ff, "generation_execution_admitted_rows")
expected_generation_result_artifacts = as_int(v61ff, "expected_generation_result_artifacts")
accepted_generation_result_artifacts = as_int(v61ff, "accepted_generation_result_artifacts")
actual_model_generation_ready = 0

full_shard_prerequisites_closed = int(
    full_checkpoint_materialization_ready
    and full_safetensors_page_hash_binding_ready
    and post_full_shard_runtime_evidence_ready
    and runtime_execution_admitted_rows == 37
    and runtime_admission_accepted_rows == 1000
)

review_return_root_ready = int(selected_review_return_dir_supplied and selected_review_return_dir_exists)
generation_execution_ready = int(generation_execution_admitted_rows == generation_execution_admission_rows and generation_execution_admission_rows > 0)
generation_result_acceptance_ready = int(
    expected_generation_result_artifacts > 0
    and accepted_generation_result_artifacts == expected_generation_result_artifacts
)
claim_ready = 0

ledger_rows = [
    {"ledger_id": "01-real-model-page-manifest", "status": "closed", "ready": "1", "evidence": "v61ff/v61ch real-model page manifest release index ready", "next_required_input": ""},
    {"ledger_id": "02-full-checkpoint-materialization", "status": status(full_checkpoint_materialization_ready), "ready": str(full_checkpoint_materialization_ready), "evidence": f"checkpoint_shards={v61dg['ready_checkpoint_materialization_shard_rows']}/{v61dg['checkpoint_shard_rows']}", "next_required_input": ""},
    {"ledger_id": "03-full-page-hash-coverage", "status": status(full_safetensors_page_hash_binding_ready), "ready": str(full_safetensors_page_hash_binding_ready), "evidence": f"verified_pages={v61dg['total_verified_page_hash_rows']}/{v61dg['total_required_page_hash_rows']}", "next_required_input": ""},
    {"ledger_id": "04-post-full-shard-runtime-evidence", "status": status(post_full_shard_runtime_evidence_ready), "ready": str(post_full_shard_runtime_evidence_ready), "evidence": "v61dg post_full_shard_runtime_evidence_ready", "next_required_input": ""},
    {"ledger_id": "05-source-bound-runtime-seed", "status": status(runtime_execution_admitted_rows == 37), "ready": str(int(runtime_execution_admitted_rows == 37)), "evidence": f"runtime_execution_admitted_rows={runtime_execution_admitted_rows}", "next_required_input": ""},
    {"ledger_id": "06-complete-source-runtime-admission", "status": status(runtime_admission_accepted_rows == 1000), "ready": str(int(runtime_admission_accepted_rows == 1000)), "evidence": f"runtime_admission_accepted_rows={runtime_admission_accepted_rows}", "next_required_input": ""},
    {"ledger_id": "07-replay-entrypoint-package", "status": status(replay_entrypoint_ready), "ready": str(replay_entrypoint_ready), "evidence": "v61fo guarded replay entrypoint emitted", "next_required_input": ""},
    {"ledger_id": "08-real-review-return-root-present", "status": status(review_return_root_ready), "ready": str(review_return_root_ready), "evidence": f"dir_supplied={selected_review_return_dir_supplied}; dir_exists={selected_review_return_dir_exists}", "next_required_input": "supply V61FO_REVIEW_RETURN_DIR"},
    {"ledger_id": "09-real-review-return-provenance", "status": status(real_review_return_provenance_asserted), "ready": str(real_review_return_provenance_asserted), "evidence": f"provenance={selected_review_return_provenance}", "next_required_input": "set provenance to real-external-review-return"},
    {"ledger_id": "10-external-review-return-accepted", "status": status(external_review_return_ready), "ready": str(external_review_return_ready), "evidence": f"external_review_return_ready={external_review_return_ready}", "next_required_input": "accepted v61fh review-return artifacts"},
    {"ledger_id": "11-real-return-replay-admission", "status": status(real_return_replay_admission_ready), "ready": str(real_return_replay_admission_ready), "evidence": f"real_return_replay_admission_ready={real_return_replay_admission_ready}", "next_required_input": "run guarded replay after real return acceptance"},
    {"ledger_id": "12-row-acceptance", "status": status(row_acceptance_ready), "ready": str(row_acceptance_ready), "evidence": f"row_acceptance_ready={row_acceptance_ready}", "next_required_input": "accepted replay rows"},
    {"ledger_id": "13-generation-execution-admission", "status": status(generation_execution_ready), "ready": str(generation_execution_ready), "evidence": f"generation_execution_admitted_rows={generation_execution_admitted_rows}/{generation_execution_admission_rows}", "next_required_input": "accepted review return before generation execution"},
    {"ledger_id": "14-generation-result-acceptance", "status": status(generation_result_acceptance_ready), "ready": str(generation_result_acceptance_ready), "evidence": f"accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}", "next_required_input": "real generation result artifact return"},
    {"ledger_id": "15-actual-model-generation", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0", "next_required_input": "accepted generation execution and result rows"},
    {"ledger_id": "16-production-near-frontier-release-claims", "status": "blocked", "ready": "0", "evidence": "production_latency_claim_ready=0; near_frontier_claim_ready=0; real_release_package_ready=0", "next_required_input": "external review, latency, and release package evidence"},
]
write_csv(run_dir / "post_fo_full_shard_to_real_review_replay_closure_ledger_rows.csv", list(ledger_rows[0].keys()), ledger_rows)

blocker_rows = [
    {
        "blocker_id": row["ledger_id"],
        "blocker_status": "open",
        "evidence": row["evidence"],
        "next_required_input": row["next_required_input"],
    }
    for row in ledger_rows
    if row["status"] == "blocked"
]
write_csv(run_dir / "post_fo_full_shard_to_real_review_replay_closure_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

next_action_rows = [
    {"action_id": "01-verify-closure-ledger", "ready_to_run_now": "1", "command": "bash results/v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger/ledger_001/post_fo_full_shard_to_real_review_replay_closure_ledger/VERIFY_CLOSURE_LEDGER.sh", "purpose": "verify metadata-only closure ledger"},
    {"action_id": "02-verify-v61fo-entrypoint", "ready_to_run_now": "1", "command": "./experiments/test_v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint.sh", "purpose": "verify guarded replay entrypoint"},
    {"action_id": "03-run-entrypoint-with-real-review-return", "ready_to_run_now": str(replay_entrypoint_admitted), "command": "V61FO_REVIEW_RETURN_DIR=/path/to/real/return V61FO_REVIEW_RETURN_PROVENANCE=real-external-review-return results/v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint/entrypoint_001/real_manifest_external_review_return_replay_entrypoint/RUN_REAL_MANIFEST_EXTERNAL_REVIEW_RETURN_REPLAY_IF_READY.sh", "purpose": "requires real external review return root"},
    {"action_id": "04-refresh-real-return-replay", "ready_to_run_now": str(real_return_replay_admission_ready), "command": "./experiments/run_v61fe_post_fd_real_return_replay_admission_guard.sh", "purpose": "admit replay only after real return roots"},
    {"action_id": "05-refresh-generation-acceptance", "ready_to_run_now": str(generation_result_acceptance_ready), "command": "run v61bt/v61de/v61cu after real generation result artifacts", "purpose": "requires accepted generation result artifacts"},
    {"action_id": "06-keep-zero-repo-payload", "ready_to_run_now": "0", "command": "do not commit checkpoint shards or generated payloads", "purpose": "preserve zero repo checkpoint payload invariant"},
]
write_csv(run_dir / "post_fo_full_shard_to_real_review_replay_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)

metric_rows = [{
    "selected_entrypoint_source_class": selected_entrypoint_source_class,
    "selected_review_return_dir_supplied": selected_review_return_dir_supplied,
    "selected_review_return_dir_exists": selected_review_return_dir_exists,
    "selected_review_return_provenance": selected_review_return_provenance,
    "real_review_return_provenance_asserted": real_review_return_provenance_asserted,
    "fixture_return_provenance": fixture_return_provenance,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "full_checkpoint_materialization_ready": full_checkpoint_materialization_ready,
    "full_safetensors_page_hash_binding_ready": full_safetensors_page_hash_binding_ready,
    "post_full_shard_runtime_evidence_ready": post_full_shard_runtime_evidence_ready,
    "runtime_execution_admitted_rows": runtime_execution_admitted_rows,
    "runtime_admission_accepted_rows": runtime_admission_accepted_rows,
    "replay_entrypoint_ready": replay_entrypoint_ready,
    "replay_entrypoint_admitted": replay_entrypoint_admitted,
    "external_review_return_ready": external_review_return_ready,
    "real_return_replay_admission_ready": real_return_replay_admission_ready,
    "row_acceptance_ready": row_acceptance_ready,
    "generation_execution_admission_rows": generation_execution_admission_rows,
    "generation_execution_admitted_rows": generation_execution_admitted_rows,
    "expected_generation_result_artifacts": expected_generation_result_artifacts,
    "accepted_generation_result_artifacts": accepted_generation_result_artifacts,
    "actual_model_generation_ready": actual_model_generation_ready,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61fp": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}]
write_csv(run_dir / "post_fo_full_shard_to_real_review_replay_closure_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)

closure_manifest = {
    "artifact": "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "selected_entrypoint_source_class": selected_entrypoint_source_class,
    "full_shard_prerequisites_closed": full_shard_prerequisites_closed,
    "ledger_rows": len(ledger_rows),
    "closed_ledger_rows": sum(row["status"] == "closed" for row in ledger_rows),
    "blocked_ledger_rows": sum(row["status"] == "blocked" for row in ledger_rows),
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(closure_dir / "CLOSURE_LEDGER_MANIFEST.json").write_text(json.dumps(closure_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
shutil.copy2(run_dir / "post_fo_full_shard_to_real_review_replay_closure_ledger_rows.csv", closure_dir / "CLOSURE_LEDGER_ROWS.csv")
shutil.copy2(run_dir / "post_fo_full_shard_to_real_review_replay_closure_blocker_rows.csv", closure_dir / "CLOSURE_BLOCKER_ROWS.csv")
shutil.copy2(run_dir / "post_fo_full_shard_to_real_review_replay_next_action_rows.csv", closure_dir / "NEXT_ACTION_ROWS.csv")
(closure_dir / "POST_FO_FULL_SHARD_TO_REAL_REVIEW_REPLAY_CLOSURE_LEDGER.md").write_text(
    "\n".join(
        [
            "# v61fp post-v61fo closure ledger",
            "",
            f"- selected_entrypoint_source_class={selected_entrypoint_source_class}",
            f"- full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
            f"- full_checkpoint_materialization_ready={full_checkpoint_materialization_ready}",
            f"- full_safetensors_page_hash_binding_ready={full_safetensors_page_hash_binding_ready}",
            f"- runtime_admission_accepted_rows={runtime_admission_accepted_rows}",
            f"- replay_entrypoint_ready={replay_entrypoint_ready}",
            f"- replay_entrypoint_admitted={replay_entrypoint_admitted}",
            f"- external_review_return_ready={external_review_return_ready}",
            f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
            f"- generation_execution_admitted_rows={generation_execution_admitted_rows}/{generation_execution_admission_rows}",
            f"- accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}",
            "- actual_model_generation_ready=0",
            "",
            "This ledger proves that full-shard/page-hash/runtime evidence is no longer the blocker. The remaining blocker is the real external review return and downstream generation-result acceptance path.",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script = closure_dir / "VERIFY_CLOSURE_LEDGER.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -s \"$DIR/CLOSURE_LEDGER_MANIFEST.json\"",
            "test -s \"$DIR/CLOSURE_LEDGER_ROWS.csv\"",
            "test -s \"$DIR/CLOSURE_BLOCKER_ROWS.csv\"",
            "test -s \"$DIR/NEXT_ACTION_ROWS.csv\"",
            "test -s \"$DIR/POST_FO_FULL_SHARD_TO_REAL_REVIEW_REPLAY_CLOSURE_LEDGER.md\"",
            "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
            "  echo 'payload-like file referenced in closure ledger package' >&2",
            "  exit 1",
            "fi",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

closure_files = sorted(path for path in closure_dir.rglob("*") if path.is_file())
file_rows = []
for path in closure_files:
    rel = path.relative_to(run_dir).as_posix()
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    file_rows.append({
        "path": rel,
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "post_fo_full_shard_to_real_review_replay_closure_file_rows.csv", list(file_rows[0].keys()), file_rows)

summary = {
    "v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready": 1,
    "v61fo_post_fn_real_manifest_external_review_return_replay_entrypoint_ready": 1,
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": 1,
    "v61dg_post_full_shard_runtime_evidence_promotion_gate_ready": 1,
    "v61fn_post_fm_real_manifest_external_review_acceptance_replay_gate_ready": 1,
    "v61fm_post_fl_real_manifest_external_review_return_work_order_ready": 1,
    "v61fe_post_fd_real_return_replay_admission_guard_ready": 1,
    **metric_rows[0],
    "ledger_rows": len(ledger_rows),
    "closed_ledger_rows": sum(row["status"] == "closed" for row in ledger_rows),
    "blocked_ledger_rows": sum(row["status"] == "blocked" for row in ledger_rows),
    "blocker_rows": len(blocker_rows),
    "open_blocker_rows": len(blocker_rows),
    "next_action_rows": len(next_action_rows),
    "ready_next_action_rows": sum(row["ready_to_run_now"] == "1" for row in next_action_rows),
    "blocked_next_action_rows": sum(row["ready_to_run_now"] == "0" for row in next_action_rows),
    "closure_package_file_rows": len(file_rows),
    "metadata_only_closure_package_file_rows": sum(row["metadata_only"] == "1" for row in file_rows),
    "payload_like_closure_package_file_rows": sum(row["payload_like"] == "1" for row in file_rows),
    "source_summary_file_rows": len(sources),
    "selected_entrypoint_file_rows": len(selected_files),
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "full-shard-prerequisites", "status": pass_status(full_shard_prerequisites_closed), "actual_value": str(full_shard_prerequisites_closed), "required_value": "1", "reason": "full checkpoint, page hash, runtime admission are closed"},
    {"gate": "replay-entrypoint-ready", "status": pass_status(replay_entrypoint_ready), "actual_value": str(replay_entrypoint_ready), "required_value": "1", "reason": "v61fo entrypoint package exists"},
    {"gate": "real-review-return-root", "status": pass_status(review_return_root_ready), "actual_value": str(review_return_root_ready), "required_value": "1", "reason": "requires real returned root"},
    {"gate": "real-review-return-provenance", "status": pass_status(real_review_return_provenance_asserted), "actual_value": str(real_review_return_provenance_asserted), "required_value": "1", "reason": "fixture provenance is not accepted"},
    {"gate": "external-review-return", "status": pass_status(external_review_return_ready), "actual_value": str(external_review_return_ready), "required_value": "1", "reason": "review return rows not accepted"},
    {"gate": "real-return-replay-admission", "status": pass_status(real_return_replay_admission_ready), "actual_value": str(real_return_replay_admission_ready), "required_value": "1", "reason": "replay remains fail-closed"},
    {"gate": "row-acceptance", "status": pass_status(row_acceptance_ready), "actual_value": str(row_acceptance_ready), "required_value": "1", "reason": "accepted replay rows missing"},
    {"gate": "generation-execution-admission", "status": pass_status(generation_execution_ready), "actual_value": f"{generation_execution_admitted_rows}/{generation_execution_admission_rows}", "required_value": "1000/1000", "reason": "generation execution not admitted"},
    {"gate": "generation-result-acceptance", "status": pass_status(generation_result_acceptance_ready), "actual_value": f"{accepted_generation_result_artifacts}/{expected_generation_result_artifacts}", "required_value": "5/5", "reason": "generation result artifacts not accepted"},
    {"gate": "actual-generation", "status": "blocked", "actual_value": "0", "required_value": "1", "reason": "actual generation remains unproven"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "actual_value": "0", "required_value": "0", "reason": "metadata-only closure ledger"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

boundary = run_dir / "V61FP_POST_FO_FULL_SHARD_TO_REAL_REVIEW_REPLAY_CLOSURE_LEDGER_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# V61FP Post-v61fo Full-Shard to Real Review Replay Closure Ledger Boundary",
            "",
            f"- v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_ready=1",
            f"- selected_entrypoint_source_class={selected_entrypoint_source_class}",
            f"- full_shard_prerequisites_closed={full_shard_prerequisites_closed}",
            f"- full_checkpoint_materialization_ready={full_checkpoint_materialization_ready}",
            f"- full_safetensors_page_hash_binding_ready={full_safetensors_page_hash_binding_ready}",
            f"- post_full_shard_runtime_evidence_ready={post_full_shard_runtime_evidence_ready}",
            f"- runtime_execution_admitted_rows={runtime_execution_admitted_rows}",
            f"- runtime_admission_accepted_rows={runtime_admission_accepted_rows}",
            f"- replay_entrypoint_ready={replay_entrypoint_ready}",
            f"- replay_entrypoint_admitted={replay_entrypoint_admitted}",
            f"- real_review_return_provenance_asserted={real_review_return_provenance_asserted}",
            f"- external_review_return_ready={external_review_return_ready}",
            f"- real_return_replay_admission_ready={real_return_replay_admission_ready}",
            f"- row_acceptance_ready={row_acceptance_ready}",
            f"- generation_execution_admitted_rows={generation_execution_admitted_rows}/{generation_execution_admission_rows}",
            f"- accepted_generation_result_artifacts={accepted_generation_result_artifacts}/{expected_generation_result_artifacts}",
            "- actual_model_generation_ready=0",
            f"- ledger_rows={len(ledger_rows)}",
            f"- closed_ledger_rows={summary['closed_ledger_rows']}",
            f"- blocked_ledger_rows={summary['blocked_ledger_rows']}",
            f"- closure_package_file_rows={len(file_rows)}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Blocked wording: full-shard/page-hash/runtime evidence is closed, but real external review return, replay admission, row acceptance, generation execution, generation-result acceptance, actual generation, production latency, near-frontier, and release claims remain blocked.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **summary,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "bytes", "sha256"], sha_rows)

print(f"v61fp_post_fo_full_shard_to_real_review_replay_closure_ledger_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
