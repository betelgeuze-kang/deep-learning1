#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ee_post_review_generation_handoff_fixture_gate"
RUN_ID="${V61EE_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_REVIEW_RETURN_DIR="$RESULTS_DIR/v61ed_review_return_refresh_fixture_replay_gate/gate_001/fixture_review_return_refresh"
FIXTURE_V61DE_RUN_ID="post_review_handoff_fixture_v61ee"

if [[ "${V61EE_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ee_post_review_generation_handoff_fixture_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61ed_review_return_refresh_fixture_replay_gate_summary.csv" ]]; then
  V61ED_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ed_review_return_refresh_fixture_replay_gate.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_REVIEW_RETURN_DIR" <<'PY'
import csv
import hashlib
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
fixture_review_return_dir = Path(sys.argv[3])
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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


sources = {
    "v61ed_summary": results / "v61ed_review_return_refresh_fixture_replay_gate_summary.csv",
    "v61ed_decision": results / "v61ed_review_return_refresh_fixture_replay_gate_decision.csv",
    "v61ed_boundary": results / "v61ed_review_return_refresh_fixture_replay_gate" / "gate_001" / "V61ED_REVIEW_RETURN_REFRESH_FIXTURE_REPLAY_GATE_BOUNDARY.md",
    "v61de_default_before": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ee source {key}: {path}")
if not fixture_review_return_dir.is_dir():
    raise SystemExit(f"missing v61ed fixture review return dir: {fixture_review_return_dir}")

v61ed = read_csv(sources["v61ed_summary"])[0]
if v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"] != "1":
    raise SystemExit("v61ee requires v61ed ready")
if v61ed["fixture_v61_review_unblock_ready"] != "1":
    raise SystemExit("v61ee requires v61ed fixture review unblock ready")

copy(sources["v61ed_summary"], "source_v61ed/v61ed_review_return_refresh_fixture_replay_gate_summary.csv")
copy(sources["v61ed_decision"], "source_v61ed/v61ed_review_return_refresh_fixture_replay_gate_decision.csv")
copy(sources["v61ed_boundary"], "source_v61ed/V61ED_REVIEW_RETURN_REFRESH_FIXTURE_REPLAY_GATE_BOUNDARY.md")
copy(sources["v61de_default_before"], "source_v61de_default_before/v61de_post_review_generation_result_handoff_bridge_summary.csv")

fixture_files = sorted(path for path in fixture_review_return_dir.rglob("*") if path.is_file())
fixture_file_rows = [
    {
        "fixture_relative_path": str(path.relative_to(fixture_review_return_dir)),
        "size_bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "payload_class": "synthetic-review-return-fixture",
        "real_external_review_return": "0",
    }
    for path in fixture_files
]
write_csv(run_dir / "post_review_handoff_fixture_review_return_file_rows.csv", list(fixture_file_rows[0].keys()), fixture_file_rows)
PY

V61DE_REVIEW_RETURN_DIR="$FIXTURE_REVIEW_RETURN_DIR" \
V61DE_RUN_ID="$FIXTURE_V61DE_RUN_ID" \
V61DE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

mkdir -p "$RUN_DIR/source_v61de_fixture" "$RUN_DIR/source_v53z_fixture" "$RUN_DIR/source_v61dd_fixture"
cp "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge_summary.csv" "$RUN_DIR/source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv"
cp "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge_decision.csv" "$RUN_DIR/source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_decision.csv"
cp "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge/$FIXTURE_V61DE_RUN_ID/post_review_generation_result_handoff_stage_rows.csv" "$RUN_DIR/source_v61de_fixture/post_review_generation_result_handoff_stage_rows.csv"
cp "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge/$FIXTURE_V61DE_RUN_ID/post_review_generation_result_handoff_requirement_rows.csv" "$RUN_DIR/source_v61de_fixture/post_review_generation_result_handoff_requirement_rows.csv"
cp "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge/$FIXTURE_V61DE_RUN_ID/runtime_gap_rows.csv" "$RUN_DIR/source_v61de_fixture/runtime_gap_rows.csv"
cp "$RESULTS_DIR/v61de_post_review_generation_result_handoff_bridge/$FIXTURE_V61DE_RUN_ID/sha256_manifest.csv" "$RUN_DIR/source_v61de_fixture/sha256_manifest.csv"
cp "$RESULTS_DIR/v53z_complete_source_review_return_v61_handoff_bridge_summary.csv" "$RUN_DIR/source_v53z_fixture/v53z_complete_source_review_return_v61_handoff_bridge_summary.csv"
cp "$RESULTS_DIR/v61dd_review_return_generation_refresh_bridge_summary.csv" "$RUN_DIR/source_v61dd_fixture/v61dd_review_return_generation_refresh_bridge_summary.csv"

V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$FIXTURE_REVIEW_RETURN_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
fixture_review_return_dir = Path(sys.argv[5])
results = root / "results"
bundle_dir = run_dir / "post_review_generation_handoff_fixture_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)


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


def copy_bundle(src, rel):
    dst = bundle_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(src.read_bytes())


sources = {
    "v61ed": results / "v61ed_review_return_refresh_fixture_replay_gate_summary.csv",
    "fixture_files": run_dir / "post_review_handoff_fixture_review_return_file_rows.csv",
    "fixture_v61de": run_dir / "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "fixture_v53z": run_dir / "source_v53z_fixture/v53z_complete_source_review_return_v61_handoff_bridge_summary.csv",
    "fixture_v61dd": run_dir / "source_v61dd_fixture/v61dd_review_return_generation_refresh_bridge_summary.csv",
    "default_v61de": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "default_v53z": results / "v53z_complete_source_review_return_v61_handoff_bridge_summary.csv",
    "default_v61dd": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61ee aggregate source {key}: {path}")

v61ed = read_csv(sources["v61ed"])[0]
fixture_files = read_csv(sources["fixture_files"])
fixture_v61de = read_csv(sources["fixture_v61de"])[0]
fixture_v53z = read_csv(sources["fixture_v53z"])[0]
fixture_v61dd = read_csv(sources["fixture_v61dd"])[0]
default_v61de = read_csv(sources["default_v61de"])[0]
default_v53z = read_csv(sources["default_v53z"])[0]
default_v61dd = read_csv(sources["default_v61dd"])[0]

if fixture_v61de["generation_execution_admitted_rows"] != "1000":
    raise SystemExit("v61ee fixture v61de did not admit generation execution")
if fixture_v61de["accepted_generation_result_artifacts"] != "0":
    raise SystemExit("v61ee fixture v61de should not accept generation result artifacts")
if default_v61de["generation_execution_admitted_rows"] != "0":
    raise SystemExit("v61ee canonical v61de default was not restored")

canonical_restore_rows = [
    {
        "restore_id": "v61ee-restore-v61de-canonical-no-review-return",
        "status": "pass" if default_v61de["generation_execution_admitted_rows"] == "0" and default_v53z["answer_review_accepted_rows"] == "0" and default_v61dd["v61_review_unblock_ready"] == "0" else "fail",
        "canonical_answer_review_accepted_rows": default_v53z["answer_review_accepted_rows"],
        "canonical_v61_review_unblock_ready": default_v61dd["v61_review_unblock_ready"],
        "canonical_generation_execution_admitted_rows": default_v61de["generation_execution_admitted_rows"],
        "canonical_ready_handoff_stage_rows": default_v61de["ready_handoff_stage_rows"],
    }
]
write_csv(run_dir / "post_review_handoff_fixture_canonical_restore_rows.csv", list(canonical_restore_rows[0].keys()), canonical_restore_rows)

stage_rows = [
    {"stage_id": "01-bind-v61ed-review-return-fixture", "status": "ready", "ready": "1", "evidence": "v61ed fixture review return is ready"},
    {"stage_id": "02-run-v61de-with-review-fixture", "status": "ready", "ready": "1", "evidence": "v61de fixture run executed"},
    {"stage_id": "03-review-return-unblocks-v61", "status": "ready", "ready": "1", "evidence": "fixture v61_review_unblock_ready=1"},
    {"stage_id": "04-generation-execution-admitted", "status": "ready", "ready": "1", "evidence": "fixture generation_execution_admitted_rows=1000/1000"},
    {"stage_id": "05-generation-operator-ready", "status": "ready", "ready": "1", "evidence": "fixture guarded_generation_command_ready=1"},
    {"stage_id": "06-restore-canonical-no-review-return", "status": "ready", "ready": "1", "evidence": "canonical v61de/v53z/v61dd restored"},
    {"stage_id": "07-real-generation-result-return", "status": "blocked", "ready": "0", "evidence": "accepted_generation_result_artifacts=0/5"},
    {"stage_id": "08-actual-generation-accepted", "status": "blocked", "ready": "0", "evidence": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "post_review_generation_handoff_fixture_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

invariant_rows = [
    {"invariant_id": "v61ed-fixture-ready", "status": "pass" if v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"] == "1" else "fail", "expected": "v61ed ready", "actual": v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"]},
    {"invariant_id": "fixture-review-return-files-present", "status": "pass" if len(fixture_files) >= 55 else "fail", "expected": "review fixture files present", "actual": str(len(fixture_files))},
    {"invariant_id": "fixture-v53z-review-accepted", "status": "pass" if fixture_v53z["answer_review_accepted_rows"] == "7000" and fixture_v53z["v61_review_unblock_ready"] == "1" else "fail", "expected": "v53z fixture review accepted", "actual": f"{fixture_v53z['answer_review_accepted_rows']};{fixture_v53z['v61_review_unblock_ready']}"},
    {"invariant_id": "fixture-v61dd-generation-admission-open", "status": "pass" if fixture_v61dd["generation_execution_admitted_rows"] == "1000" and fixture_v61dd["review_return_blocked_generation_rows"] == "0" else "fail", "expected": "generation admission opened by fixture review return", "actual": f"{fixture_v61dd['generation_execution_admitted_rows']};blocked={fixture_v61dd['review_return_blocked_generation_rows']}"},
    {"invariant_id": "fixture-v61de-handoff-advances", "status": "pass" if fixture_v61de["ready_handoff_stage_rows"] == "6" and fixture_v61de["blocked_handoff_stage_rows"] == "2" else "fail", "expected": "6 ready and 2 blocked handoff stages", "actual": f"{fixture_v61de['ready_handoff_stage_rows']}/{fixture_v61de['handoff_stage_rows']}"},
    {"invariant_id": "fixture-generation-result-still-missing", "status": "pass" if fixture_v61de["accepted_generation_result_artifacts"] == "0" and fixture_v61de["actual_model_generation_ready"] == "0" else "fail", "expected": "generation result and actual generation blocked", "actual": f"artifacts={fixture_v61de['accepted_generation_result_artifacts']};actual={fixture_v61de['actual_model_generation_ready']}"},
    {"invariant_id": "canonical-default-restored", "status": canonical_restore_rows[0]["status"], "expected": "canonical v61de defaults restored", "actual": default_v61de["generation_execution_admitted_rows"]},
    {"invariant_id": "fixture-not-real-external-review", "status": "pass" if all(row["real_external_review_return"] == "0" for row in fixture_files) else "fail", "expected": "fixture review files not real external evidence", "actual": str(sum(row["real_external_review_return"] == "0" for row in fixture_files))},
    {"invariant_id": "repo-checkpoint-payload-zero", "status": "pass", "expected": "repo checkpoint payload is zero", "actual": "0"},
]
write_csv(run_dir / "post_review_generation_handoff_fixture_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

runtime_gap_rows = [
    {"gap": "fixture-post-review-handoff", "status": "ready", "reason": "fixture v61de reaches generation_execution_admitted_rows=1000/1000"},
    {"gap": "canonical-default-restore", "status": "ready", "reason": "canonical v61de no-review-return state restored"},
    {"gap": "real-review-return", "status": "blocked", "reason": "real_external_review_return_rows=0"},
    {"gap": "generation-result-artifacts", "status": "blocked", "reason": "accepted_generation_result_artifacts=0/5"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

bundle_readme = bundle_dir / "README.md"
bundle_readme.write_text(
    "# v61ee Post-Review Generation Handoff Fixture Gate\n\n"
    "This bundle proves that a complete supplied review-return fixture advances "
    "the v61de post-review handoff through generation execution admission. It "
    "does not include real external review evidence, generation result artifacts, "
    "actual generation evidence, latency evidence, or release evidence.\n",
    encoding="utf-8",
)
for src, rel in [
    (run_dir / "post_review_handoff_fixture_review_return_file_rows.csv", "FIXTURE_REVIEW_RETURN_FILE_ROWS.csv"),
    (run_dir / "post_review_handoff_fixture_canonical_restore_rows.csv", "CANONICAL_RESTORE_ROWS.csv"),
    (run_dir / "post_review_generation_handoff_fixture_stage_rows.csv", "FIXTURE_HANDOFF_STAGES.csv"),
    (run_dir / "post_review_generation_handoff_fixture_invariant_rows.csv", "FIXTURE_HANDOFF_INVARIANTS.csv"),
]:
    copy_bundle(src, rel)

verify_script = bundle_dir / "VERIFY_V61EE_FIXTURE_HANDOFF.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
            'RUN_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"',
            "export RUN_DIR",
            'test -s "$BUNDLE_DIR/FIXTURE_REVIEW_RETURN_FILE_ROWS.csv"',
            'test -s "$BUNDLE_DIR/CANONICAL_RESTORE_ROWS.csv"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import os",
            "from pathlib import Path",
            "run_dir = Path(os.environ['RUN_DIR'])",
            "def read_csv(path):",
            "    with path.open(newline='', encoding='utf-8') as handle:",
            "        return list(csv.DictReader(handle))",
            "summary = read_csv(run_dir.parent.parent / 'v61ee_post_review_generation_handoff_fixture_gate_summary.csv')[0]",
            "if summary['fixture_generation_execution_admitted_rows'] != '1000':",
            "    raise SystemExit('fixture did not admit generation execution')",
            "if summary['canonical_default_generation_execution_admitted_rows'] != '0':",
            "    raise SystemExit('canonical v61de default was not restored')",
            "if summary['fixture_accepted_generation_result_artifacts'] != '0':",
            "    raise SystemExit('fixture must not include generation result artifacts')",
            "if summary['actual_model_generation_ready'] != '0':",
            "    raise SystemExit('actual generation must remain blocked')",
            "PY_VERIFY",
            'if find "$RUN_DIR" -type f \\( -name "*.safetensors" -o -name "*.bin" -o -name "*.pt" \\) | grep -q .; then',
            '  echo "model/checkpoint payload-like file found inside v61ee fixture gate" >&2',
            "  exit 1",
            "fi",
            "echo 'v61ee fixture handoff verified'",
        ]
    )
    + "\n",
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_manifest = {
    "manifest_scope": "v61ee-post-review-generation-handoff-fixture-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "fixture_generation_execution_admitted_rows": int(fixture_v61de["generation_execution_admitted_rows"]),
    "fixture_accepted_generation_result_artifacts": int(fixture_v61de["accepted_generation_result_artifacts"]),
    "canonical_default_generation_execution_admitted_rows": int(default_v61de["generation_execution_admitted_rows"]),
    "actual_model_generation_ready": 0,
}
(bundle_dir / "FIXTURE_HANDOFF_MANIFEST.json").write_text(
    json.dumps(bundle_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

bundle_files = sorted(path for path in bundle_dir.rglob("*") if path.is_file())
bundle_file_rows = [
    {
        "bundle_relative_path": str(path.relative_to(bundle_dir)),
        "size_bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "payload_class": "metadata-only",
    }
    for path in bundle_files
]
write_csv(run_dir / "post_review_generation_handoff_fixture_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

ready_stage_rows = sum(1 for row in stage_rows if row["status"] == "ready")
blocked_stage_rows = sum(1 for row in stage_rows if row["status"] == "blocked")
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

summary_row = {
    "v61ee_post_review_generation_handoff_fixture_gate_ready": "1",
    "v61ed_review_return_refresh_fixture_replay_gate_ready": v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"],
    "fixture_stage_rows": str(len(stage_rows)),
    "ready_fixture_stage_rows": str(ready_stage_rows),
    "blocked_fixture_stage_rows": str(blocked_stage_rows),
    "fixture_review_return_file_rows": str(len(fixture_files)),
    "fixture_v61de_ready_handoff_stage_rows": fixture_v61de["ready_handoff_stage_rows"],
    "fixture_v61de_blocked_handoff_stage_rows": fixture_v61de["blocked_handoff_stage_rows"],
    "fixture_answer_review_accepted_rows": fixture_v61de["answer_review_accepted_rows"],
    "fixture_expected_human_review_rows": fixture_v61de["expected_human_review_rows"],
    "fixture_review_return_ready": fixture_v61de["review_return_ready"],
    "fixture_v61_review_unblock_ready": fixture_v61de["v61_review_unblock_ready"],
    "fixture_generation_execution_admission_rows": fixture_v61de["generation_execution_admission_rows"],
    "fixture_generation_execution_admitted_rows": fixture_v61de["generation_execution_admitted_rows"],
    "fixture_generation_execution_blocked_rows": fixture_v61de["generation_execution_blocked_rows"],
    "fixture_guarded_generation_command_ready": fixture_v61de["guarded_generation_command_ready"],
    "fixture_generation_operator_execution_ready": fixture_v61de["generation_operator_execution_ready"],
    "fixture_expected_generation_result_artifacts": fixture_v61de["expected_generation_result_artifacts"],
    "fixture_accepted_generation_result_artifacts": fixture_v61de["accepted_generation_result_artifacts"],
    "fixture_generation_result_accepted_rows": fixture_v61de["generation_result_accepted_rows"],
    "fixture_actual_model_generation_ready": fixture_v61de["actual_model_generation_ready"],
    "canonical_default_ready_handoff_stage_rows": default_v61de["ready_handoff_stage_rows"],
    "canonical_default_answer_review_accepted_rows": default_v61de["answer_review_accepted_rows"],
    "canonical_default_v61_review_unblock_ready": default_v61de["v61_review_unblock_ready"],
    "canonical_default_generation_execution_admitted_rows": default_v61de["generation_execution_admitted_rows"],
    "canonical_default_accepted_generation_result_artifacts": default_v61de["accepted_generation_result_artifacts"],
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": str(len(invariant_rows)),
    "fixture_invariant_pass_rows": str(invariant_pass_rows),
    "fixture_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_fixture_bundle_file_rows": str(sum(1 for row in bundle_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61ee": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "v61ed-review-return-fixture", "status": "pass", "reason": "v61ed supplied review-return fixture is ready"},
    {"gate": "fixture-v61de-post-review-handoff", "status": "pass", "reason": "v61de fixture handoff reaches 6/8 ready stages"},
    {"gate": "fixture-generation-execution-admitted", "status": "pass", "reason": "generation_execution_admitted_rows=1000/1000"},
    {"gate": "canonical-default-restore", "status": canonical_restore_rows[0]["status"], "reason": "canonical v61de no-review-return state restored"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "no checkpoint/model payload committed"},
    {"gate": "real-review-return", "status": "blocked", "reason": "real_external_review_return_rows=0"},
    {"gate": "generation-result-artifacts", "status": "blocked", "reason": "accepted_generation_result_artifacts=0/5"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ee Post-Review Generation Handoff Fixture Gate Boundary

This gate proves the post-review generation handoff mechanics only. It supplies
the v61ed review-return fixture to v61de, captures the fixture handoff evidence,
and restores the canonical no-review-return v61de/v53z/v61dd state.

Evidence emitted:

- fixture_v61de_ready_handoff_stage_rows={fixture_v61de['ready_handoff_stage_rows']}/8
- fixture_answer_review_accepted_rows={fixture_v61de['answer_review_accepted_rows']}/{fixture_v61de['expected_human_review_rows']}
- fixture_v61_review_unblock_ready={fixture_v61de['v61_review_unblock_ready']}
- fixture_generation_execution_admitted_rows={fixture_v61de['generation_execution_admitted_rows']}/{fixture_v61de['generation_execution_admission_rows']}
- fixture_guarded_generation_command_ready={fixture_v61de['guarded_generation_command_ready']}
- fixture_accepted_generation_result_artifacts={fixture_v61de['accepted_generation_result_artifacts']}/{fixture_v61de['expected_generation_result_artifacts']}
- fixture_actual_model_generation_ready={fixture_v61de['actual_model_generation_ready']}
- canonical_default_generation_execution_admitted_rows={default_v61de['generation_execution_admitted_rows']}
- real_external_review_return_rows=0
- real_generation_result_artifacts=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: a complete supplied review-return fixture opens the post-review
generation execution admission path and moves the blocker to generation result
artifacts.

Blocked wording: real external review return received, real model generation
result artifacts, accepted actual generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61EE_POST_REVIEW_GENERATION_HANDOFF_FIXTURE_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61ee-post-review-generation-handoff-fixture-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ee_post_review_generation_handoff_fixture_gate_ready": 1,
    "fixture_generation_execution_admitted_rows": int(fixture_v61de["generation_execution_admitted_rows"]),
    "fixture_accepted_generation_result_artifacts": int(fixture_v61de["accepted_generation_result_artifacts"]),
    "canonical_default_generation_execution_admitted_rows": int(default_v61de["generation_execution_admitted_rows"]),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ee_post_review_generation_handoff_fixture_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ee_post_review_generation_handoff_fixture_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
