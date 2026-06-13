#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61em_generation_intake_dual_preflight_rendezvous"
RUN_ID="${V61EM_RUN_ID:-rendezvous_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
GENERATION_PREFLIGHT_RUN_DIR_ARG="${V61EM_GENERATION_PREFLIGHT_RUN_DIR:-}"
BINDING_PREFLIGHT_RUN_DIR_ARG="${V61EM_BINDING_PREFLIGHT_RUN_DIR:-}"

if [[ "${V61EM_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61em_generation_intake_dual_preflight_rendezvous_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ej_real_generation_return_receiver_preflight.sh" >/dev/null
V61EL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh" >/dev/null
V61EK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ek_preflight_to_generation_intake_handoff_guard.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$GENERATION_PREFLIGHT_RUN_DIR_ARG" "$BINDING_PREFLIGHT_RUN_DIR_ARG" <<'PY'
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
generation_arg = sys.argv[5].strip()
binding_arg = sys.argv[6].strip()
results = root / "results"
default_generation_preflight_dir = results / "v61ej_real_generation_return_receiver_preflight" / "preflight_001"
default_binding_preflight_dir = results / "v61el_real_prerequisite_binding_receiver_preflight" / "preflight_001"
generation_preflight_dir = Path(generation_arg).expanduser().resolve() if generation_arg else default_generation_preflight_dir
binding_preflight_dir = Path(binding_arg).expanduser().resolve() if binding_arg else default_binding_preflight_dir


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


def ready_status(flag):
    return "ready" if flag else "blocked"


def pass_status(flag):
    return "pass" if flag else "blocked"


source_files = {
    "v61ej_summary": results / "v61ej_real_generation_return_receiver_preflight_summary.csv",
    "v61el_summary": results / "v61el_real_prerequisite_binding_receiver_preflight_summary.csv",
    "v61ek_summary": results / "v61ek_preflight_to_generation_intake_handoff_guard_summary.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
}
for key, path in source_files.items():
    if not path.is_file():
        raise SystemExit(f"missing v61em source {key}: {path}")
    copy(path, f"source_summaries/{path.name}")

v61ej = read_csv(source_files["v61ej_summary"])[0]
v61el = read_csv(source_files["v61el_summary"])[0]
v61ek = read_csv(source_files["v61ek_summary"])[0]
v61bt = read_csv(source_files["v61bt_summary"])[0]
v61de = read_csv(source_files["v61de_summary"])[0]

generation_metric_path = generation_preflight_dir / "receiver_preflight_metric_rows.csv"
generation_artifact_path = generation_preflight_dir / "receiver_preflight_artifact_rows.csv"
generation_query_path = generation_preflight_dir / "receiver_preflight_query_rows.csv"
binding_metric_path = binding_preflight_dir / "prerequisite_binding_preflight_metric_rows.csv"
binding_file_path = binding_preflight_dir / "prerequisite_binding_file_rows.csv"
binding_field_path = binding_preflight_dir / "prerequisite_binding_field_check_rows.csv"

selected_files = [
    generation_metric_path,
    generation_artifact_path,
    generation_query_path,
    binding_metric_path,
    binding_file_path,
    binding_field_path,
]
for path in selected_files:
    if not path.is_file():
        raise SystemExit(f"missing selected v61em preflight artifact: {path}")

copy(generation_metric_path, "selected_generation_preflight/receiver_preflight_metric_rows.csv")
copy(generation_artifact_path, "selected_generation_preflight/receiver_preflight_artifact_rows.csv")
copy(generation_query_path, "selected_generation_preflight/receiver_preflight_query_rows.csv")
copy(binding_metric_path, "selected_binding_preflight/prerequisite_binding_preflight_metric_rows.csv")
copy(binding_file_path, "selected_binding_preflight/prerequisite_binding_file_rows.csv")
copy(binding_field_path, "selected_binding_preflight/prerequisite_binding_field_check_rows.csv")

generation_metric = read_csv(generation_metric_path)[0]
binding_metric = read_csv(binding_metric_path)[0]

selected_generation_ready = as_int(generation_metric, "generation_result_receiver_preflight_ready")
selected_generation_real_artifacts = as_int(generation_metric, "real_generation_result_artifacts")
selected_binding_candidate_ready = as_int(binding_metric, "binding_candidate_preflight_ready")
selected_real_binding_ready = as_int(binding_metric, "real_prerequisite_binding_ready")
selected_non_fixture_binding = as_int(binding_metric, "non_fixture_binding_source")
selected_real_provenance = as_int(binding_metric, "real_review_return_provenance_asserted")
selected_review_ready = as_int(binding_metric, "real_review_return_ready")
dual_candidate_ready = int(selected_generation_ready and selected_binding_candidate_ready)
real_generation_intake_handoff_ready = int(selected_generation_ready and selected_real_binding_ready)
v61bt_handoff_ready = real_generation_intake_handoff_ready
v61de_handoff_ready = int(real_generation_intake_handoff_ready and selected_review_ready)
actual_model_generation_ready = 0

stage_rows = [
    {
        "stage_id": "01-source-gates-ready",
        "status": "ready",
        "ready": "1",
        "actual_value": f"v61ej={v61ej['v61ej_real_generation_return_receiver_preflight_ready']}; v61el={v61el['v61el_real_prerequisite_binding_receiver_preflight_ready']}; v61ek={v61ek['v61ek_preflight_to_generation_intake_handoff_guard_ready']}",
        "blocking_reason": "",
    },
    {
        "stage_id": "02-selected-generation-result-preflight",
        "status": ready_status(selected_generation_ready),
        "ready": str(selected_generation_ready),
        "actual_value": f"{generation_metric['preflight_pass_generation_result_artifacts']}/{generation_metric['expected_generation_result_artifacts']} artifacts; {generation_metric['receiver_preflight_query_pass_rows']}/{generation_metric['receiver_preflight_query_rows']} queries",
        "blocking_reason": "" if selected_generation_ready else "selected generation-result receiver preflight is not ready",
    },
    {
        "stage_id": "03-selected-binding-candidate-preflight",
        "status": ready_status(selected_binding_candidate_ready),
        "ready": str(selected_binding_candidate_ready),
        "actual_value": f"{binding_metric['present_binding_source_files']}/{binding_metric['required_binding_source_files']} files; {binding_metric['ready_check_pass_rows']}/{binding_metric['required_ready_check_rows']} readiness checks",
        "blocking_reason": "" if selected_binding_candidate_ready else "selected prerequisite binding candidate preflight is not ready",
    },
    {
        "stage_id": "04-real-prerequisite-binding",
        "status": ready_status(selected_real_binding_ready),
        "ready": str(selected_real_binding_ready),
        "actual_value": f"real_binding={selected_real_binding_ready}; non_fixture={selected_non_fixture_binding}; provenance={selected_real_provenance}",
        "blocking_reason": "" if selected_real_binding_ready else "binding candidate is not real prerequisite binding",
    },
    {
        "stage_id": "05-dual-candidate-rendezvous",
        "status": ready_status(dual_candidate_ready),
        "ready": str(dual_candidate_ready),
        "actual_value": f"generation_preflight={selected_generation_ready}; binding_candidate={selected_binding_candidate_ready}",
        "blocking_reason": "" if dual_candidate_ready else "requires both selected candidate preflights",
    },
    {
        "stage_id": "06-real-generation-intake-handoff",
        "status": ready_status(real_generation_intake_handoff_ready),
        "ready": str(real_generation_intake_handoff_ready),
        "actual_value": f"generation_preflight={selected_generation_ready}; real_binding={selected_real_binding_ready}",
        "blocking_reason": "" if real_generation_intake_handoff_ready else "requires selected generation preflight and real prerequisite binding",
    },
    {
        "stage_id": "07-actual-generation-acceptance",
        "status": "blocked",
        "ready": "0",
        "actual_value": f"v61bt_actual={v61bt['actual_model_generation_ready']}; v61de_actual={v61de['actual_model_generation_ready']}",
        "blocking_reason": "rendezvous does not accept generation results",
    },
]
write_csv(run_dir / "dual_preflight_rendezvous_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {
        "command_id": "verify-generation-result-preflight",
        "command": "V61EJ_REUSE_EXISTING=1 ./experiments/test_v61ej_real_generation_return_receiver_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "verify returned generation-result schema/hash/query preflight",
    },
    {
        "command_id": "verify-prerequisite-binding-preflight",
        "command": "V61EL_REUSE_EXISTING=1 ./experiments/test_v61el_real_prerequisite_binding_receiver_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "verify prerequisite binding receiver preflight",
    },
    {
        "command_id": "run-v61bt-real-intake",
        "command": "V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(v61bt_handoff_ready),
        "purpose": "run actual generation-result intake after dual preflight and real binding",
    },
    {
        "command_id": "run-v61de-real-handoff",
        "command": "V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": str(v61de_handoff_ready),
        "purpose": "refresh post-review generation handoff after real intake prerequisites",
    },
    {
        "command_id": "refresh-active-goal-status",
        "command": "./experiments/test_v61ei_active_goal_post_eh_status_refresh.sh",
        "ready_to_run_now": "1",
        "purpose": "confirm claim boundaries after rendezvous",
    },
]
write_csv(run_dir / "dual_preflight_rendezvous_command_rows.csv", list(command_rows[0].keys()), command_rows)

requirement_rows = [
    {"requirement_id": "v61ej-preflight-gate", "status": "pass", "required_value": "1", "actual_value": v61ej["v61ej_real_generation_return_receiver_preflight_ready"], "reason": "v61ej receiver preflight gate exists"},
    {"requirement_id": "v61el-binding-preflight-gate", "status": "pass", "required_value": "1", "actual_value": v61el["v61el_real_prerequisite_binding_receiver_preflight_ready"], "reason": "v61el prerequisite binding preflight gate exists"},
    {"requirement_id": "selected-generation-preflight-ready", "status": pass_status(selected_generation_ready), "required_value": "1", "actual_value": str(selected_generation_ready), "reason": "selected returned generation-result preflight must pass"},
    {"requirement_id": "selected-binding-candidate-ready", "status": pass_status(selected_binding_candidate_ready), "required_value": "1", "actual_value": str(selected_binding_candidate_ready), "reason": "selected prerequisite binding candidate preflight must pass"},
    {"requirement_id": "real-prerequisite-binding-ready", "status": pass_status(selected_real_binding_ready), "required_value": "1", "actual_value": str(selected_real_binding_ready), "reason": "fixture binding is not accepted as real prerequisite binding"},
    {"requirement_id": "dual-candidate-rendezvous-ready", "status": pass_status(dual_candidate_ready), "required_value": "1", "actual_value": str(dual_candidate_ready), "reason": "both candidate preflights must be ready"},
    {"requirement_id": "real-generation-intake-handoff-ready", "status": pass_status(real_generation_intake_handoff_ready), "required_value": "1", "actual_value": str(real_generation_intake_handoff_ready), "reason": "requires candidate generation preflight plus real prerequisite binding"},
    {"requirement_id": "actual-model-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "rendezvous is not an acceptance gate"},
]
write_csv(run_dir / "dual_preflight_rendezvous_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

ready_stage_rows = sum(row["ready"] == "1" for row in stage_rows)
ready_command_rows = sum(row["ready_to_run_now"] == "1" for row in command_rows)
summary = {
    "v61em_generation_intake_dual_preflight_rendezvous_ready": "1",
    "v61ej_real_generation_return_receiver_preflight_ready": v61ej["v61ej_real_generation_return_receiver_preflight_ready"],
    "v61el_real_prerequisite_binding_receiver_preflight_ready": v61el["v61el_real_prerequisite_binding_receiver_preflight_ready"],
    "v61ek_preflight_to_generation_intake_handoff_guard_ready": v61ek["v61ek_preflight_to_generation_intake_handoff_guard_ready"],
    "selected_generation_preflight_run_dir_supplied": str(int(bool(generation_arg))),
    "selected_generation_preflight_run_dir": str(generation_preflight_dir),
    "selected_generation_result_receiver_preflight_ready": str(selected_generation_ready),
    "selected_preflight_pass_generation_result_artifacts": generation_metric["preflight_pass_generation_result_artifacts"],
    "selected_expected_generation_result_artifacts": generation_metric["expected_generation_result_artifacts"],
    "selected_receiver_preflight_query_pass_rows": generation_metric["receiver_preflight_query_pass_rows"],
    "selected_receiver_preflight_query_rows": generation_metric["receiver_preflight_query_rows"],
    "selected_real_generation_result_artifacts": str(selected_generation_real_artifacts),
    "selected_binding_preflight_run_dir_supplied": str(int(bool(binding_arg))),
    "selected_binding_preflight_run_dir": str(binding_preflight_dir),
    "selected_binding_candidate_preflight_ready": str(selected_binding_candidate_ready),
    "selected_binding_source_class": binding_metric["selected_binding_source_class"],
    "selected_non_fixture_binding_source": str(selected_non_fixture_binding),
    "selected_real_review_return_provenance_asserted": str(selected_real_provenance),
    "selected_real_prerequisite_binding_ready": str(selected_real_binding_ready),
    "dual_candidate_preflight_rendezvous_ready": str(dual_candidate_ready),
    "real_generation_intake_handoff_ready": str(real_generation_intake_handoff_ready),
    "v61bt_intake_handoff_ready": str(v61bt_handoff_ready),
    "v61de_generation_result_handoff_ready": str(v61de_handoff_ready),
    "rendezvous_stage_rows": str(len(stage_rows)),
    "ready_rendezvous_stage_rows": str(ready_stage_rows),
    "blocked_rendezvous_stage_rows": str(len(stage_rows) - ready_stage_rows),
    "rendezvous_command_rows": str(len(command_rows)),
    "ready_rendezvous_command_rows": str(ready_command_rows),
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61em": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-gates-ready", "status": "pass", "reason": "v61ej/v61el/v61ek gates are present"},
    {"gate": "selected-generation-preflight", "status": pass_status(selected_generation_ready), "reason": f"generation_preflight_ready={selected_generation_ready}"},
    {"gate": "selected-binding-candidate-preflight", "status": pass_status(selected_binding_candidate_ready), "reason": f"binding_candidate_preflight_ready={selected_binding_candidate_ready}"},
    {"gate": "real-prerequisite-binding", "status": pass_status(selected_real_binding_ready), "reason": f"real_prerequisite_binding_ready={selected_real_binding_ready}"},
    {"gate": "dual-candidate-rendezvous", "status": pass_status(dual_candidate_ready), "reason": f"generation={selected_generation_ready}; binding_candidate={selected_binding_candidate_ready}"},
    {"gate": "real-generation-intake-handoff", "status": pass_status(real_generation_intake_handoff_ready), "reason": f"generation={selected_generation_ready}; real_binding={selected_real_binding_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "rendezvous does not accept generation"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only rendezvous"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = f"""# v61em Generation Intake Dual Preflight Rendezvous

This rendezvous combines the selected v61ej generation-result receiver preflight
and the selected v61el prerequisite-binding receiver preflight. It can prove
that both candidate preflights are ready, but it only opens the real v61bt/v61de
intake handoff when the prerequisite binding is non-fixture and real.

- selected_generation_result_receiver_preflight_ready={selected_generation_ready}
- selected_binding_candidate_preflight_ready={selected_binding_candidate_ready}
- selected_real_prerequisite_binding_ready={selected_real_binding_ready}
- dual_candidate_preflight_rendezvous_ready={dual_candidate_ready}
- real_generation_intake_handoff_ready={real_generation_intake_handoff_ready}
- v61bt_intake_handoff_ready={v61bt_handoff_ready}
- v61de_generation_result_handoff_ready={v61de_handoff_ready}
- actual_model_generation_ready={actual_model_generation_ready}

Allowed wording: dual candidate preflight can be checked before actual intake.

Blocked wording: dual candidate preflight, fixture generation results, or
fixture prerequisite binding do not imply actual generation, near-frontier
quality, production latency, or release readiness.
"""
(run_dir / "V61EM_GENERATION_INTAKE_DUAL_PREFLIGHT_RENDEZVOUS_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61em-generation-intake-dual-preflight-rendezvous",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61em_generation_intake_dual_preflight_rendezvous_ready": 1,
    "dual_candidate_preflight_rendezvous_ready": dual_candidate_ready,
    "real_generation_intake_handoff_ready": real_generation_intake_handoff_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61em_generation_intake_dual_preflight_rendezvous_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61em_generation_intake_dual_preflight_rendezvous_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
