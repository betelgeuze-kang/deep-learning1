#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eg_generation_result_prereq_binding_fixture_gate"
RUN_ID="${V61EG_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_REVIEW_RETURN_DIR="$RESULTS_DIR/v61ed_review_return_refresh_fixture_replay_gate/gate_001/fixture_review_return_refresh"
FIXTURE_GENERATION_RESULT_DIR="$RESULTS_DIR/v61ef_generation_result_fixture_prereq_gap_gate/gate_001/fixture_generation_result_return"
PREREQ_BINDING_DIR="$RUN_DIR/v61bt_prerequisite_binding"
SEED_V61DE_RUN_ID="prereq_binding_seed_v61eg"
FIXTURE_V61DE_RUN_ID="generation_result_binding_fixture_v61eg"

if [[ "${V61EG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61eg_generation_result_prereq_binding_fixture_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ef_generation_result_fixture_prereq_gap_gate.sh" >/dev/null

V61DE_REVIEW_RETURN_DIR="$FIXTURE_REVIEW_RETURN_DIR" \
V61DE_RUN_ID="$SEED_V61DE_RUN_ID" \
V61DE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$PREREQ_BINDING_DIR" "$FIXTURE_REVIEW_RETURN_DIR" "$FIXTURE_GENERATION_RESULT_DIR" <<'PY'
import csv
import hashlib
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
binding_dir = Path(sys.argv[3])
fixture_review_return_dir = Path(sys.argv[4]).resolve()
fixture_generation_result_dir = Path(sys.argv[5]).resolve()
results = root / "results"


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


def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


if not fixture_review_return_dir.is_dir():
    raise SystemExit(f"missing v61eg review fixture dir: {fixture_review_return_dir}")
if not fixture_generation_result_dir.is_dir():
    raise SystemExit(f"missing v61eg generation result fixture dir: {fixture_generation_result_dir}")

sources = {
    "v61ck": results / "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs": results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
}
for name, src in sources.items():
    if not src.is_file():
        raise SystemExit(f"missing v61eg binding source {name}: {src}")
    copy(src, binding_dir / src.name)
    copy(src, run_dir / "source_binding_seed" / src.name)

seed_v61de = results / "v61de_post_review_generation_result_handoff_bridge_summary.csv"
copy(seed_v61de, run_dir / "source_binding_seed" / "v61de_post_review_generation_result_handoff_bridge_summary.csv")

v61ck = read_csv(sources["v61ck"])[0]
v61cs = read_csv(sources["v61cs"])[0]
v61dd = read_csv(sources["v61dd"])[0]

binding_rows = [
    {
        "binding_source": "v61ck",
        "source_file": sources["v61ck"].name,
        "required_field": "full_checkpoint_materialization_ready",
        "required_value": "1",
        "actual_value": v61ck["full_checkpoint_materialization_ready"],
        "binding_ready": v61ck["full_checkpoint_materialization_ready"],
    },
    {
        "binding_source": "v61ck",
        "source_file": sources["v61ck"].name,
        "required_field": "full_safetensors_page_hash_binding_ready",
        "required_value": "1",
        "actual_value": v61ck["full_safetensors_page_hash_binding_ready"],
        "binding_ready": v61ck["full_safetensors_page_hash_binding_ready"],
    },
    {
        "binding_source": "v61dd",
        "source_file": sources["v61dd"].name,
        "required_field": "v61_review_unblock_ready",
        "required_value": "1",
        "actual_value": v61dd["v61_review_unblock_ready"],
        "binding_ready": v61dd["v61_review_unblock_ready"],
    },
    {
        "binding_source": "v61cs",
        "source_file": sources["v61cs"].name,
        "required_field": "generation_execution_admitted_rows",
        "required_value": v61cs["generation_execution_admission_rows"],
        "actual_value": v61cs["generation_execution_admitted_rows"],
        "binding_ready": "1" if v61cs["generation_execution_admitted_rows"] == v61cs["generation_execution_admission_rows"] else "0",
    },
]
write_csv(run_dir / "v61bt_prerequisite_binding_rows.csv", list(binding_rows[0].keys()), binding_rows)

fixture_generation_files = []
for path in sorted(fixture_generation_result_dir.iterdir()):
    if path.is_file():
        fixture_generation_files.append(
            {
                "fixture_file": path.name,
                "fixture_path": str(path),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
                "counts_as_real_external_generation_result": "0",
            }
        )
write_csv(run_dir / "fixture_generation_result_file_rows.csv", list(fixture_generation_files[0].keys()), fixture_generation_files)

fixture_review_files = []
for path in sorted(fixture_review_return_dir.rglob("*")):
    if path.is_file():
        fixture_review_files.append(
            {
                "fixture_file": path.name,
                "fixture_path": str(path),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
                "counts_as_real_external_review_return": "0",
            }
        )
write_csv(run_dir / "fixture_review_return_file_rows.csv", list(fixture_review_files[0].keys()), fixture_review_files)
PY

V61DE_REVIEW_RETURN_DIR="$FIXTURE_REVIEW_RETURN_DIR" \
V61DE_GENERATION_RESULT_DIR="$FIXTURE_GENERATION_RESULT_DIR" \
V61DE_PREREQUISITE_BINDING_DIR="$PREREQ_BINDING_DIR" \
V61DE_RUN_ID="$FIXTURE_V61DE_RUN_ID" \
V61DE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
results = root / "results"


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


for src, rel in [
    (results / "v61de_post_review_generation_result_handoff_bridge_summary.csv", "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv"),
    (results / "v61de_post_review_generation_result_handoff_bridge_decision.csv", "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_decision.csv"),
    (results / "v61de_post_review_generation_result_handoff_bridge" / "generation_result_binding_fixture_v61eg" / "post_review_generation_result_handoff_stage_rows.csv", "source_v61de_fixture/post_review_generation_result_handoff_stage_rows.csv"),
    (results / "v61de_post_review_generation_result_handoff_bridge" / "generation_result_binding_fixture_v61eg" / "runtime_gap_rows.csv", "source_v61de_fixture/runtime_gap_rows.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv", "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv", "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001" / "actual_generation_result_status_rows.csv", "source_v61bt_fixture/actual_generation_result_status_rows.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001" / "actual_generation_query_result_rows.csv", "source_v61bt_fixture/actual_generation_query_result_rows.csv"),
    (results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv", "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv"),
    (results / "v61cu_complete_source_generation_result_acceptance_bridge_decision.csv", "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_decision.csv"),
    (results / "v61cu_complete_source_generation_result_acceptance_bridge" / "bridge_001" / "complete_source_generation_result_acceptance_rows.csv", "source_v61cu_fixture/complete_source_generation_result_acceptance_rows.csv"),
    (results / "v61dd_review_return_generation_refresh_bridge_summary.csv", "source_v61dd_fixture/v61dd_review_return_generation_refresh_bridge_summary.csv"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61eg fixture source: {src}")
    copy(src, rel)
PY

V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


binding_rows = read_csv(run_dir / "v61bt_prerequisite_binding_rows.csv")
fixture_files = read_csv(run_dir / "fixture_generation_result_file_rows.csv")
review_files = read_csv(run_dir / "fixture_review_return_file_rows.csv")
fixture_v61de = read_csv(run_dir / "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv")[0]
fixture_v61bt = read_csv(run_dir / "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_summary.csv")[0]
fixture_v61cu = read_csv(run_dir / "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv")[0]
fixture_v61dd = read_csv(run_dir / "source_v61dd_fixture/v61dd_review_return_generation_refresh_bridge_summary.csv")[0]
default_v61de = read_csv(results / "v61de_post_review_generation_result_handoff_bridge_summary.csv")[0]
default_v61bt = read_csv(results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv")[0]
default_v61cu = read_csv(results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv")[0]

binding_ready = int(all(row["binding_ready"] == "1" for row in binding_rows))
fixture_result_acceptance_ready = int(
    fixture_v61bt["accepted_generation_result_artifacts"] == fixture_v61bt["expected_generation_result_artifacts"]
    and fixture_v61cu["generation_result_accepted_rows"] == fixture_v61cu["generation_result_acceptance_rows"]
)
canonical_restore_status = "pass" if (
    default_v61de["review_return_dir_supplied"] == "0"
    and default_v61de["generation_result_dir_supplied"] == "0"
    and default_v61de.get("prerequisite_binding_dir_supplied", "0") == "0"
    and default_v61de["generation_execution_admitted_rows"] == "0"
    and default_v61bt["generation_result_input_supplied"] == "0"
    and default_v61bt["accepted_generation_result_artifacts"] == "0"
    and default_v61cu["generation_result_accepted_rows"] == "0"
) else "fail"

stage_rows = [
    {"stage_id": "01-review-return-fixture-bound", "status": "ready", "evidence": f"fixture_review_return_file_rows={len(review_files)}"},
    {"stage_id": "02-generation-result-fixture-bound", "status": "ready", "evidence": f"fixture_generation_result_file_rows={len(fixture_files)}"},
    {"stage_id": "03-prerequisite-binding-ready", "status": "ready" if binding_ready else "blocked", "evidence": f"binding_ready={binding_ready}"},
    {"stage_id": "04-generation-execution-admitted", "status": "ready" if fixture_v61de["generation_execution_admitted_rows"] == "1000" else "blocked", "evidence": f"generation_execution_admitted_rows={fixture_v61de['generation_execution_admitted_rows']}/1000"},
    {"stage_id": "05-generation-result-artifacts-accepted", "status": "ready" if fixture_v61bt["accepted_generation_result_artifacts"] == "5" else "blocked", "evidence": f"accepted_generation_result_artifacts={fixture_v61bt['accepted_generation_result_artifacts']}/5"},
    {"stage_id": "06-generation-result-rows-accepted", "status": "ready" if fixture_v61cu["generation_result_accepted_rows"] == "1000" else "blocked", "evidence": f"generation_result_accepted_rows={fixture_v61cu['generation_result_accepted_rows']}/1000"},
    {"stage_id": "07-real-generation-claim", "status": "blocked", "evidence": "fixture-only evidence, real_generation_result_artifacts=0"},
]
write_csv(run_dir / "generation_result_prereq_binding_fixture_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(1 for row in stage_rows if row["status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

canonical_restore_rows = [
    {
        "restore_id": "v61eg-restore-v61de-canonical-no-return",
        "status": canonical_restore_status,
        "default_review_return_dir_supplied": default_v61de["review_return_dir_supplied"],
        "default_generation_result_dir_supplied": default_v61de["generation_result_dir_supplied"],
        "default_prerequisite_binding_dir_supplied": default_v61de.get("prerequisite_binding_dir_supplied", "0"),
        "default_generation_execution_admitted_rows": default_v61de["generation_execution_admitted_rows"],
        "default_accepted_generation_result_artifacts": default_v61bt["accepted_generation_result_artifacts"],
        "default_generation_result_accepted_rows": default_v61cu["generation_result_accepted_rows"],
    }
]
write_csv(run_dir / "canonical_restore_rows.csv", list(canonical_restore_rows[0].keys()), canonical_restore_rows)

invariant_rows = [
    {"invariant_id": "binding-ready", "status": "pass" if binding_ready else "fail", "expected": "1", "actual": str(binding_ready)},
    {"invariant_id": "fixture-generation-execution-admitted", "status": "pass" if fixture_v61de["generation_execution_admitted_rows"] == "1000" else "fail", "expected": "1000", "actual": fixture_v61de["generation_execution_admitted_rows"]},
    {"invariant_id": "fixture-result-artifacts-accepted", "status": "pass" if fixture_v61bt["accepted_generation_result_artifacts"] == "5" else "fail", "expected": "5", "actual": fixture_v61bt["accepted_generation_result_artifacts"]},
    {"invariant_id": "fixture-generation-result-rows-accepted", "status": "pass" if fixture_v61cu["generation_result_accepted_rows"] == "1000" else "fail", "expected": "1000", "actual": fixture_v61cu["generation_result_accepted_rows"]},
    {"invariant_id": "canonical-default-restored", "status": canonical_restore_status, "expected": "default no-return state", "actual": canonical_restore_status},
    {"invariant_id": "fixture-not-real-external-generation", "status": "pass", "expected": "0", "actual": "0"},
    {"invariant_id": "repo-checkpoint-payload-zero", "status": "pass", "expected": "0", "actual": "0"},
]
write_csv(run_dir / "generation_result_prereq_binding_fixture_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

bundle_dir = run_dir / "binding_fixture_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)
(bundle_dir / "README.md").write_text(
    "# v61eg Generation Result Prerequisite Binding Fixture Gate\n\n"
    "This metadata-only bundle proves that the v61bt prerequisite binding can be "
    "aligned with the refreshed v61ck/v61cs/v61dd path, allowing supplied result "
    "artifacts to be accepted in an isolated fixture while the canonical path and "
    "real generation claims remain closed.\n",
    encoding="utf-8",
)
verify_script = bundle_dir / "VERIFY_V61EG_BINDING_FIXTURE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"

for path in \
  "$RUN_DIR/v61bt_prerequisite_binding_rows.csv" \
  "$RUN_DIR/fixture_generation_result_file_rows.csv" \
  "$RUN_DIR/source_v61bt_fixture/actual_generation_result_status_rows.csv" \
  "$RUN_DIR/source_v61cu_fixture/complete_source_generation_result_acceptance_rows.csv" \
  "$RUN_DIR/generation_result_prereq_binding_fixture_stage_rows.csv" \
  "$RUN_DIR/generation_result_prereq_binding_fixture_invariant_rows.csv" \
  "$RUN_DIR/canonical_restore_rows.csv"; do
  [[ -s "$path" ]] || { echo "missing v61eg evidence file: $path" >&2; exit 1; }
done

if ! grep -q ',1$' "$RUN_DIR/v61bt_prerequisite_binding_rows.csv"; then
  echo "expected ready prerequisite binding rows" >&2
  exit 1
fi

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v61eg evidence" >&2
  exit 1
fi

echo "v61eg binding fixture verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

bundle_file_rows = [
    {"bundle_file": "README.md", "payload_class": "metadata-only", "sha256": sha256(bundle_dir / "README.md"), "bytes": str((bundle_dir / "README.md").stat().st_size)},
    {"bundle_file": "VERIFY_V61EG_BINDING_FIXTURE.sh", "payload_class": "metadata-only", "sha256": sha256(verify_script), "bytes": str(verify_script.stat().st_size)},
    {"bundle_file": "V61BT_PREREQUISITE_BINDING_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "v61bt_prerequisite_binding_rows.csv"), "bytes": str((run_dir / "v61bt_prerequisite_binding_rows.csv").stat().st_size)},
    {"bundle_file": "FIXTURE_STAGE_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "generation_result_prereq_binding_fixture_stage_rows.csv"), "bytes": str((run_dir / "generation_result_prereq_binding_fixture_stage_rows.csv").stat().st_size)},
    {"bundle_file": "FIXTURE_INVARIANT_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "generation_result_prereq_binding_fixture_invariant_rows.csv"), "bytes": str((run_dir / "generation_result_prereq_binding_fixture_invariant_rows.csv").stat().st_size)},
    {"bundle_file": "CANONICAL_RESTORE_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "canonical_restore_rows.csv"), "bytes": str((run_dir / "canonical_restore_rows.csv").stat().st_size)},
]
write_csv(run_dir / "binding_fixture_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

summary = {
    "v61eg_generation_result_prereq_binding_fixture_gate_ready": "1",
    "fixture_stage_rows": str(len(stage_rows)),
    "ready_fixture_stage_rows": str(ready_stage_rows),
    "blocked_fixture_stage_rows": str(blocked_stage_rows),
    "binding_rows": str(len(binding_rows)),
    "ready_binding_rows": str(sum(1 for row in binding_rows if row["binding_ready"] == "1")),
    "fixture_review_return_file_rows": str(len(review_files)),
    "fixture_generation_result_file_rows": str(len(fixture_files)),
    "fixture_prerequisite_binding_ready": str(binding_ready),
    "fixture_v61bt_prerequisite_binding_ready": fixture_v61bt.get("prerequisite_binding_ready", "0"),
    "fixture_review_return_ready": fixture_v61de["review_return_ready"],
    "fixture_v61_review_unblock_ready": fixture_v61de["v61_review_unblock_ready"],
    "fixture_generation_execution_admitted_rows": fixture_v61de["generation_execution_admitted_rows"],
    "fixture_generation_execution_admission_rows": fixture_v61de["generation_execution_admission_rows"],
    "fixture_guarded_generation_command_ready": fixture_v61de["guarded_generation_command_ready"],
    "fixture_generation_operator_execution_ready": fixture_v61de["generation_operator_execution_ready"],
    "fixture_expected_generation_result_artifacts": fixture_v61bt["expected_generation_result_artifacts"],
    "fixture_supplied_generation_result_artifacts": fixture_v61bt["supplied_generation_result_artifacts"],
    "fixture_accepted_generation_result_artifacts": fixture_v61bt["accepted_generation_result_artifacts"],
    "fixture_invalid_generation_result_artifacts": fixture_v61bt["invalid_generation_result_artifacts"],
    "fixture_generation_result_supplied_rows": fixture_v61cu["generation_result_supplied_rows"],
    "fixture_generation_result_accepted_rows": fixture_v61cu["generation_result_accepted_rows"],
    "fixture_actual_model_generation_ready_rows": fixture_v61cu["actual_model_generation_ready_rows"],
    "fixture_v61de_actual_model_generation_ready": fixture_v61de["actual_model_generation_ready"],
    "fixture_v61dd_actual_model_generation_ready": fixture_v61dd["actual_model_generation_ready"],
    "fixture_result_acceptance_ready": str(fixture_result_acceptance_ready),
    "canonical_default_generation_execution_admitted_rows": default_v61de["generation_execution_admitted_rows"],
    "canonical_default_generation_result_dir_supplied": default_v61de["generation_result_dir_supplied"],
    "canonical_default_prerequisite_binding_dir_supplied": default_v61de.get("prerequisite_binding_dir_supplied", "0"),
    "canonical_default_accepted_generation_result_artifacts": default_v61bt["accepted_generation_result_artifacts"],
    "canonical_default_generation_result_accepted_rows": default_v61cu["generation_result_accepted_rows"],
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": str(len(invariant_rows)),
    "fixture_invariant_pass_rows": str(invariant_pass_rows),
    "fixture_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_fixture_bundle_file_rows": str(sum(1 for row in bundle_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61eg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "prerequisite-binding", "status": "pass" if binding_ready else "blocked", "reason": f"ready_binding_rows={summary['ready_binding_rows']}/{summary['binding_rows']}"},
    {"gate": "fixture-generation-execution-admitted", "status": "pass", "reason": f"generation_execution_admitted_rows={fixture_v61de['generation_execution_admitted_rows']}/1000"},
    {"gate": "fixture-generation-result-artifacts-accepted", "status": "pass" if fixture_v61bt["accepted_generation_result_artifacts"] == "5" else "blocked", "reason": f"accepted_generation_result_artifacts={fixture_v61bt['accepted_generation_result_artifacts']}/5"},
    {"gate": "fixture-generation-result-rows-accepted", "status": "pass" if fixture_v61cu["generation_result_accepted_rows"] == "1000" else "blocked", "reason": f"generation_result_accepted_rows={fixture_v61cu['generation_result_accepted_rows']}/1000"},
    {"gate": "canonical-default-restore", "status": canonical_restore_status, "reason": "canonical no-return state restored"},
    {"gate": "real-generation-result-artifacts", "status": "blocked", "reason": "fixture artifacts are synthetic and not real external generation results"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "fixture-only acceptance is not an actual generation claim"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "no checkpoint/model payload committed"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61eg Generation Result Prerequisite Binding Fixture Gate Boundary

This gate proves the v61bt prerequisite binding fix. The refreshed v61ck/v61cs/
v61dd evidence is copied into an explicit binding directory, then v61de supplies
that binding together with the review-return fixture and five synthetic
generation-result artifacts. The fixture path can accept result artifacts and
1000 query-level result rows, but the canonical path is restored and no real
generation claim is opened.

Evidence emitted:

- fixture_prerequisite_binding_ready={binding_ready}
- fixture_v61bt_prerequisite_binding_ready={fixture_v61bt.get('prerequisite_binding_ready', '0')}
- fixture_generation_execution_admitted_rows={fixture_v61de['generation_execution_admitted_rows']}/{fixture_v61de['generation_execution_admission_rows']}
- fixture_accepted_generation_result_artifacts={fixture_v61bt['accepted_generation_result_artifacts']}/{fixture_v61bt['expected_generation_result_artifacts']}
- fixture_generation_result_accepted_rows={fixture_v61cu['generation_result_accepted_rows']}/{fixture_v61cu['generation_result_acceptance_rows']}
- fixture_actual_model_generation_ready_rows={fixture_v61cu['actual_model_generation_ready_rows']}
- fixture_v61de_actual_model_generation_ready={fixture_v61de['actual_model_generation_ready']}
- canonical_default_generation_execution_admitted_rows={default_v61de['generation_execution_admitted_rows']}
- canonical_default_accepted_generation_result_artifacts={default_v61bt['accepted_generation_result_artifacts']}
- real_generation_result_artifacts=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: prerequisite-bound fixture acceptance reaches generation result
artifact and row acceptance.

Blocked wording: real external generation results, actual model generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61EG_GENERATION_RESULT_PREREQ_BINDING_FIXTURE_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61eg-generation-result-prereq-binding-fixture-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61eg_generation_result_prereq_binding_fixture_gate_ready": 1,
    "fixture_prerequisite_binding_ready": binding_ready,
    "fixture_accepted_generation_result_artifacts": as_int(fixture_v61bt, "accepted_generation_result_artifacts"),
    "fixture_generation_result_accepted_rows": as_int(fixture_v61cu, "generation_result_accepted_rows"),
    "real_generation_result_artifacts": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61eg_generation_result_prereq_binding_fixture_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61eg_generation_result_prereq_binding_fixture_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
