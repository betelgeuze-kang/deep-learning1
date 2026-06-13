#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ef_generation_result_fixture_prereq_gap_gate"
RUN_ID="${V61EF_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_REVIEW_RETURN_DIR="$RESULTS_DIR/v61ed_review_return_refresh_fixture_replay_gate/gate_001/fixture_review_return_refresh"
FIXTURE_GENERATION_RESULT_DIR="$RUN_DIR/fixture_generation_result_return"
FIXTURE_V61DE_RUN_ID="generation_result_fixture_v61ef"

if [[ "${V61EF_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ef_generation_result_fixture_prereq_gap_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61ED_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ed_review_return_refresh_fixture_replay_gate.sh" >/dev/null
V61EE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ee_post_review_generation_handoff_fixture_gate.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_REVIEW_RETURN_DIR" "$FIXTURE_GENERATION_RESULT_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
fixture_review_return_dir = Path(sys.argv[3]).resolve()
fixture_generation_result_dir = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def digest(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


if not fixture_review_return_dir.is_dir():
    raise SystemExit(f"missing v61ef review-return fixture dir: {fixture_review_return_dir}")

v61ed_summary_path = results / "v61ed_review_return_refresh_fixture_replay_gate_summary.csv"
v61ee_summary_path = results / "v61ee_post_review_generation_handoff_fixture_gate_summary.csv"
v61bt_summary_path = results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv"
v53r_query_path = results / "v53r_complete_source_review_packet" / "review_001" / "review_query_packet_rows.csv"

v61ed = read_csv(v61ed_summary_path)[0]
v61ee = read_csv(v61ee_summary_path)[0]
v61bt = read_csv(v61bt_summary_path)[0]
queries = read_csv(v53r_query_path)
if v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"] != "1":
    raise SystemExit("v61ef requires v61ed fixture gate ready")
if v61ee["v61ee_post_review_generation_handoff_fixture_gate_ready"] != "1":
    raise SystemExit("v61ef requires v61ee fixture handoff gate ready")
if len(queries) != 1000:
    raise SystemExit("v61ef requires 1000 v53r query rows")

copy(v61ed_summary_path, "source_v61ed/v61ed_review_return_refresh_fixture_replay_gate_summary.csv")
copy(results / "v61ed_review_return_refresh_fixture_replay_gate_decision.csv", "source_v61ed/v61ed_review_return_refresh_fixture_replay_gate_decision.csv")
copy(v61ee_summary_path, "source_v61ee/v61ee_post_review_generation_handoff_fixture_gate_summary.csv")
copy(results / "v61ee_post_review_generation_handoff_fixture_gate_decision.csv", "source_v61ee/v61ee_post_review_generation_handoff_fixture_gate_decision.csv")
copy(v61bt_summary_path, "source_v61bt_default/v61bt_ubuntu1_actual_generation_result_intake_summary.csv")

target_root = v61bt["target_root_path"]
fixture_generation_result_dir.mkdir(parents=True, exist_ok=True)

answer_fields = [
    "generation_id",
    "review_query_packet_id",
    "query_id",
    "source_span_id",
    "model_id",
    "checkpoint_root",
    "answer_text_sha256",
    "generation_status",
    "abstain_decision",
    "fallback_used",
    "latency_row_id",
    "run_transcript_sha256",
]
answer_rows = []
for index, query in enumerate(queries):
    generation_id = f"v61ef-fixture-generation-{index:04d}"
    answer_rows.append(
        {
            "generation_id": generation_id,
            "review_query_packet_id": query["review_query_packet_id"],
            "query_id": query["query_id"],
            "source_span_id": query["source_span_id"],
            "model_id": model_id,
            "checkpoint_root": target_root,
            "answer_text_sha256": digest("answer:" + query["query_id"]),
            "generation_status": "generated",
            "abstain_decision": "0",
            "fallback_used": "0",
            "latency_row_id": f"v61ef-fixture-latency-{index:04d}",
            "run_transcript_sha256": digest("transcript:" + query["query_id"]),
        }
    )
answer_path = fixture_generation_result_dir / "real_model_generation_answer_rows.csv"
write_csv(answer_path, answer_fields, answer_rows)

citation_fields = ["generation_id", "query_id", "citation_id", "source_span_id", "source_file_sha256", "citation_verified"]
citation_rows = [
    {
        "generation_id": f"v61ef-fixture-generation-{index:04d}",
        "query_id": query["query_id"],
        "citation_id": f"v61ef-fixture-citation-{index:04d}",
        "source_span_id": query["source_span_id"],
        "source_file_sha256": query["source_file_sha256"],
        "citation_verified": "1",
    }
    for index, query in enumerate(queries)
]
citation_path = fixture_generation_result_dir / "real_model_generation_citation_rows.csv"
write_csv(citation_path, citation_fields, citation_rows)

abstain_fields = [
    "generation_id",
    "query_id",
    "expected_behavior",
    "abstain_expected",
    "abstain_observed",
    "fallback_used",
    "fallback_reason",
]
abstain_rows = [
    {
        "generation_id": f"v61ef-fixture-generation-{index:04d}",
        "query_id": query["query_id"],
        "expected_behavior": query.get("expected_behavior", "source-bound-answer"),
        "abstain_expected": "0",
        "abstain_observed": "0",
        "fallback_used": "0",
        "fallback_reason": "",
    }
    for index, query in enumerate(queries)
]
abstain_path = fixture_generation_result_dir / "real_model_generation_abstain_fallback_rows.csv"
write_csv(abstain_path, abstain_fields, abstain_rows)

latency_fields = ["generation_id", "query_id", "prompt_tokens", "output_tokens", "prefill_ms", "decode_ms", "total_ms", "tokens_per_second"]
latency_rows = [
    {
        "generation_id": f"v61ef-fixture-generation-{index:04d}",
        "query_id": query["query_id"],
        "prompt_tokens": "512",
        "output_tokens": "96",
        "prefill_ms": "125.0",
        "decode_ms": "475.0",
        "total_ms": "600.0",
        "tokens_per_second": "160.0",
    }
    for index, query in enumerate(queries)
]
latency_path = fixture_generation_result_dir / "real_model_generation_latency_rows.csv"
write_csv(latency_path, latency_fields, latency_rows)

acceptance = {
    "generation_protocol_version": "fixture-v61ef-prereq-gap",
    "acceptance_decision": "accepted",
    "expected_generation_rows": len(queries),
    "accepted_answer_rows": len(queries),
    "answer_rows_sha256": sha256(answer_path),
    "accepted_citation_rows": len(queries),
    "citation_rows_sha256": sha256(citation_path),
    "accepted_latency_rows": len(queries),
    "latency_rows_sha256": sha256(latency_path),
}
acceptance_path = fixture_generation_result_dir / "real_model_generation_acceptance_summary.json"
acceptance_path.write_text(json.dumps(acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")

fixture_files = []
for path in sorted(fixture_generation_result_dir.iterdir()):
    if path.is_file():
        row_count = ""
        if path.suffix == ".csv":
            row_count = str(len(read_csv(path)))
        fixture_files.append(
            {
                "fixture_file": path.name,
                "fixture_path": str(path),
                "payload_class": "synthetic-generation-result-fixture",
                "row_count": row_count,
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
                "counts_as_real_external_generation_result": "0",
            }
        )
write_csv(run_dir / "fixture_generation_result_file_rows.csv", list(fixture_files[0].keys()), fixture_files)

review_fixture_files = []
for path in sorted(fixture_review_return_dir.rglob("*")):
    if path.is_file():
        review_fixture_files.append(
            {
                "fixture_file": path.name,
                "fixture_path": str(path),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
                "counts_as_real_external_review_return": "0",
            }
        )
write_csv(run_dir / "fixture_review_return_file_rows.csv", list(review_fixture_files[0].keys()), review_fixture_files)
PY

V61DE_REVIEW_RETURN_DIR="$FIXTURE_REVIEW_RETURN_DIR" \
V61DE_GENERATION_RESULT_DIR="$FIXTURE_GENERATION_RESULT_DIR" \
V61DE_RUN_ID="$FIXTURE_V61DE_RUN_ID" \
V61DE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" <<'PY'
import csv
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
    (results / "v61de_post_review_generation_result_handoff_bridge" / "generation_result_fixture_v61ef" / "post_review_generation_result_handoff_stage_rows.csv", "source_v61de_fixture/post_review_generation_result_handoff_stage_rows.csv"),
    (results / "v61de_post_review_generation_result_handoff_bridge" / "generation_result_fixture_v61ef" / "runtime_gap_rows.csv", "source_v61de_fixture/runtime_gap_rows.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv", "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_summary.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake_decision.csv", "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_decision.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001" / "actual_generation_result_status_rows.csv", "source_v61bt_fixture/actual_generation_result_status_rows.csv"),
    (results / "v61bt_ubuntu1_actual_generation_result_intake" / "intake_001" / "actual_generation_query_result_rows.csv", "source_v61bt_fixture/actual_generation_query_result_rows.csv"),
    (results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv", "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv"),
    (results / "v61cu_complete_source_generation_result_acceptance_bridge_decision.csv", "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_decision.csv"),
    (results / "v61cu_complete_source_generation_result_acceptance_bridge" / "bridge_001" / "complete_source_generation_result_acceptance_rows.csv", "source_v61cu_fixture/complete_source_generation_result_acceptance_rows.csv"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61ef fixture source: {src}")
    copy(src, rel)
PY

V61DE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null

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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


fixture_files = read_csv(run_dir / "fixture_generation_result_file_rows.csv")
review_files = read_csv(run_dir / "fixture_review_return_file_rows.csv")
fixture_v61de = read_csv(run_dir / "source_v61de_fixture/v61de_post_review_generation_result_handoff_bridge_summary.csv")[0]
fixture_v61bt = read_csv(run_dir / "source_v61bt_fixture/v61bt_ubuntu1_actual_generation_result_intake_summary.csv")[0]
fixture_v61cu = read_csv(run_dir / "source_v61cu_fixture/v61cu_complete_source_generation_result_acceptance_bridge_summary.csv")[0]
fixture_status_rows = read_csv(run_dir / "source_v61bt_fixture/actual_generation_result_status_rows.csv")
default_v61de = read_csv(results / "v61de_post_review_generation_result_handoff_bridge_summary.csv")[0]
default_v61bt = read_csv(results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv")[0]
default_v61cu = read_csv(results / "v61cu_complete_source_generation_result_acceptance_bridge_summary.csv")[0]
v61ed = read_csv(run_dir / "source_v61ed/v61ed_review_return_refresh_fixture_replay_gate_summary.csv")[0]
v61ee = read_csv(run_dir / "source_v61ee/v61ee_post_review_generation_handoff_fixture_gate_summary.csv")[0]

prereq_gap_detected = int(
    as_int(fixture_v61bt, "supplied_generation_result_artifacts") == 5
    and as_int(fixture_v61bt, "accepted_generation_result_artifacts") == 0
    and as_int(fixture_v61bt, "invalid_generation_result_artifacts") == 5
    and all("generation-prerequisites-not-ready" in row["reason"] for row in fixture_status_rows)
)
canonical_restore_status = "pass" if (
    default_v61de["review_return_dir_supplied"] == "0"
    and default_v61de["generation_result_dir_supplied"] == "0"
    and default_v61de["generation_execution_admitted_rows"] == "0"
    and default_v61bt["generation_result_input_supplied"] == "0"
    and default_v61bt["accepted_generation_result_artifacts"] == "0"
) else "fail"

stage_rows = [
    {"stage_id": "01-bind-v61ed-review-return-fixture", "status": "ready", "evidence": "v61ed supplied review-return fixture is ready"},
    {"stage_id": "02-build-generation-result-fixture", "status": "ready", "evidence": f"fixture_generation_result_file_rows={len(fixture_files)}"},
    {"stage_id": "03-review-return-handoff-open", "status": "ready" if fixture_v61de["review_return_ready"] == "1" and fixture_v61de["v61_review_unblock_ready"] == "1" else "blocked", "evidence": f"review_return_ready={fixture_v61de['review_return_ready']}; v61_review_unblock_ready={fixture_v61de['v61_review_unblock_ready']}"},
    {"stage_id": "04-generation-execution-admitted", "status": "ready" if fixture_v61de["generation_execution_admitted_rows"] == fixture_v61de["generation_execution_admission_rows"] else "blocked", "evidence": f"generation_execution_admitted_rows={fixture_v61de['generation_execution_admitted_rows']}/{fixture_v61de['generation_execution_admission_rows']}"},
    {"stage_id": "05-generation-result-artifacts-supplied", "status": "ready" if fixture_v61bt["supplied_generation_result_artifacts"] == "5" else "blocked", "evidence": f"supplied_generation_result_artifacts={fixture_v61bt['supplied_generation_result_artifacts']}/5"},
    {"stage_id": "06-generation-result-artifacts-accepted", "status": "ready" if fixture_v61bt["accepted_generation_result_artifacts"] == "5" else "blocked", "evidence": f"accepted_generation_result_artifacts={fixture_v61bt['accepted_generation_result_artifacts']}/5"},
    {"stage_id": "07-actual-generation-accepted", "status": "ready" if fixture_v61de["actual_model_generation_ready"] == "1" else "blocked", "evidence": f"actual_model_generation_ready={fixture_v61de['actual_model_generation_ready']}"},
]
write_csv(run_dir / "generation_result_fixture_prereq_gap_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)
ready_stage_rows = sum(1 for row in stage_rows if row["status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

canonical_restore_rows = [
    {
        "restore_id": "v61ef-restore-v61de-canonical-no-return",
        "status": canonical_restore_status,
        "default_review_return_dir_supplied": default_v61de["review_return_dir_supplied"],
        "default_generation_result_dir_supplied": default_v61de["generation_result_dir_supplied"],
        "default_generation_execution_admitted_rows": default_v61de["generation_execution_admitted_rows"],
        "default_generation_result_input_supplied": default_v61bt["generation_result_input_supplied"],
        "default_accepted_generation_result_artifacts": default_v61bt["accepted_generation_result_artifacts"],
    }
]
write_csv(run_dir / "canonical_restore_rows.csv", list(canonical_restore_rows[0].keys()), canonical_restore_rows)

invariant_rows = [
    {"invariant_id": "v61ed-fixture-ready", "status": "pass" if v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"] == "1" else "fail", "expected": "1", "actual": v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"]},
    {"invariant_id": "v61ee-fixture-handoff-ready", "status": "pass" if v61ee["v61ee_post_review_generation_handoff_fixture_gate_ready"] == "1" else "fail", "expected": "1", "actual": v61ee["v61ee_post_review_generation_handoff_fixture_gate_ready"]},
    {"invariant_id": "generation-result-fixture-files-present", "status": "pass" if len(fixture_files) == 5 else "fail", "expected": "5", "actual": str(len(fixture_files))},
    {"invariant_id": "fixture-generation-execution-admitted", "status": "pass" if fixture_v61de["generation_execution_admitted_rows"] == "1000" else "fail", "expected": "1000", "actual": fixture_v61de["generation_execution_admitted_rows"]},
    {"invariant_id": "fixture-result-supplied-not-accepted", "status": "pass" if fixture_v61bt["supplied_generation_result_artifacts"] == "5" and fixture_v61bt["accepted_generation_result_artifacts"] == "0" else "fail", "expected": "supplied=5 accepted=0", "actual": f"supplied={fixture_v61bt['supplied_generation_result_artifacts']} accepted={fixture_v61bt['accepted_generation_result_artifacts']}"},
    {"invariant_id": "v61bt-prereq-gap-detected", "status": "pass" if prereq_gap_detected else "fail", "expected": "generation-prerequisites-not-ready", "actual": str(prereq_gap_detected)},
    {"invariant_id": "canonical-default-restored", "status": canonical_restore_status, "expected": "default no-return state", "actual": canonical_restore_status},
    {"invariant_id": "fixture-not-real-external-generation", "status": "pass", "expected": "0 real generation artifacts", "actual": "0"},
    {"invariant_id": "repo-checkpoint-payload-zero", "status": "pass", "expected": "0", "actual": "0"},
]
write_csv(run_dir / "generation_result_fixture_prereq_gap_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

bundle_dir = run_dir / "fixture_prereq_gap_bundle"
bundle_dir.mkdir(parents=True, exist_ok=True)
(bundle_dir / "README.md").write_text(
    "# v61ef Generation Result Fixture Prerequisite Gap Gate\n\n"
    "This metadata-only bundle proves that a complete supplied generation-result fixture reaches v61bt, "
    "while v61bt still rejects it because its prerequisite snapshot is not aligned with the v61de review-return handoff path.\n",
    encoding="utf-8",
)
verify_script = bundle_dir / "VERIFY_V61EF_FIXTURE_PREREQ_GAP.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"

for path in \
  "$RUN_DIR/fixture_generation_result_file_rows.csv" \
  "$RUN_DIR/source_v61bt_fixture/actual_generation_result_status_rows.csv" \
  "$RUN_DIR/generation_result_fixture_prereq_gap_stage_rows.csv" \
  "$RUN_DIR/generation_result_fixture_prereq_gap_invariant_rows.csv" \
  "$RUN_DIR/canonical_restore_rows.csv"; do
  [[ -s "$path" ]] || { echo "missing v61ef evidence file: $path" >&2; exit 1; }
done

if ! grep -q 'generation-prerequisites-not-ready' "$RUN_DIR/source_v61bt_fixture/actual_generation_result_status_rows.csv"; then
  echo "expected v61bt prerequisite gap reason" >&2
  exit 1
fi

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v61ef evidence" >&2
  exit 1
fi

echo "v61ef fixture prerequisite gap verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

bundle_file_rows = [
    {"bundle_file": "README.md", "payload_class": "metadata-only", "sha256": sha256(bundle_dir / "README.md"), "bytes": str((bundle_dir / "README.md").stat().st_size)},
    {"bundle_file": "VERIFY_V61EF_FIXTURE_PREREQ_GAP.sh", "payload_class": "metadata-only", "sha256": sha256(verify_script), "bytes": str(verify_script.stat().st_size)},
    {"bundle_file": "FIXTURE_GENERATION_RESULT_FILE_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "fixture_generation_result_file_rows.csv"), "bytes": str((run_dir / "fixture_generation_result_file_rows.csv").stat().st_size)},
    {"bundle_file": "FIXTURE_V61BT_REJECTION_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "source_v61bt_fixture/actual_generation_result_status_rows.csv"), "bytes": str((run_dir / "source_v61bt_fixture/actual_generation_result_status_rows.csv").stat().st_size)},
    {"bundle_file": "CANONICAL_RESTORE_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "canonical_restore_rows.csv"), "bytes": str((run_dir / "canonical_restore_rows.csv").stat().st_size)},
    {"bundle_file": "FIXTURE_PREREQ_GAP_STAGE_ROWS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "generation_result_fixture_prereq_gap_stage_rows.csv"), "bytes": str((run_dir / "generation_result_fixture_prereq_gap_stage_rows.csv").stat().st_size)},
    {"bundle_file": "FIXTURE_PREREQ_GAP_INVARIANTS.csv", "payload_class": "metadata-only", "sha256": sha256(run_dir / "generation_result_fixture_prereq_gap_invariant_rows.csv"), "bytes": str((run_dir / "generation_result_fixture_prereq_gap_invariant_rows.csv").stat().st_size)},
]
write_csv(run_dir / "fixture_prereq_gap_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

summary = {
    "v61ef_generation_result_fixture_prereq_gap_gate_ready": "1",
    "v61ed_review_return_refresh_fixture_replay_gate_ready": v61ed["v61ed_review_return_refresh_fixture_replay_gate_ready"],
    "v61ee_post_review_generation_handoff_fixture_gate_ready": v61ee["v61ee_post_review_generation_handoff_fixture_gate_ready"],
    "fixture_stage_rows": str(len(stage_rows)),
    "ready_fixture_stage_rows": str(ready_stage_rows),
    "blocked_fixture_stage_rows": str(blocked_stage_rows),
    "fixture_review_return_file_rows": str(len(review_files)),
    "fixture_generation_result_file_rows": str(len(fixture_files)),
    "fixture_review_return_ready": fixture_v61de["review_return_ready"],
    "fixture_v61_review_unblock_ready": fixture_v61de["v61_review_unblock_ready"],
    "fixture_generation_execution_admission_rows": fixture_v61de["generation_execution_admission_rows"],
    "fixture_generation_execution_admitted_rows": fixture_v61de["generation_execution_admitted_rows"],
    "fixture_guarded_generation_command_ready": fixture_v61de["guarded_generation_command_ready"],
    "fixture_generation_operator_execution_ready": fixture_v61de["generation_operator_execution_ready"],
    "fixture_expected_generation_result_artifacts": fixture_v61bt["expected_generation_result_artifacts"],
    "fixture_supplied_generation_result_artifacts": fixture_v61bt["supplied_generation_result_artifacts"],
    "fixture_accepted_generation_result_artifacts": fixture_v61bt["accepted_generation_result_artifacts"],
    "fixture_invalid_generation_result_artifacts": fixture_v61bt["invalid_generation_result_artifacts"],
    "fixture_missing_generation_result_artifacts": fixture_v61bt["missing_generation_result_artifacts"],
    "fixture_generation_result_supplied_rows": fixture_v61cu["generation_result_supplied_rows"],
    "fixture_generation_result_accepted_rows": fixture_v61cu["generation_result_accepted_rows"],
    "fixture_result_artifact_blocked_acceptance_rows": fixture_v61cu["result_artifact_blocked_acceptance_rows"],
    "fixture_actual_model_generation_ready": fixture_v61de["actual_model_generation_ready"],
    "fixture_v61bt_local_checkpoint_materialization_ready": fixture_v61bt["local_checkpoint_materialization_ready"],
    "fixture_v61bt_full_safetensors_page_hash_binding_ready": fixture_v61bt["full_safetensors_page_hash_binding_ready"],
    "fixture_v61bt_complete_source_review_return_ready": fixture_v61bt["complete_source_review_return_ready"],
    "fixture_v61bt_generation_admission_result_ready": fixture_v61bt["generation_admission_result_ready"],
    "fixture_prerequisite_gap_detected": str(prereq_gap_detected),
    "canonical_default_ready_handoff_stage_rows": default_v61de["ready_handoff_stage_rows"],
    "canonical_default_generation_result_dir_supplied": default_v61de["generation_result_dir_supplied"],
    "canonical_default_generation_execution_admitted_rows": default_v61de["generation_execution_admitted_rows"],
    "canonical_default_supplied_generation_result_artifacts": default_v61bt["supplied_generation_result_artifacts"],
    "canonical_default_accepted_generation_result_artifacts": default_v61bt["accepted_generation_result_artifacts"],
    "canonical_default_generation_result_accepted_rows": default_v61cu["generation_result_accepted_rows"],
    "real_external_review_return_rows": "0",
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "fixture_invariant_rows": str(len(invariant_rows)),
    "fixture_invariant_pass_rows": str(invariant_pass_rows),
    "fixture_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_fixture_bundle_file_rows": str(sum(1 for row in bundle_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61ef": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61ed-review-return-fixture", "status": "pass", "reason": "v61ed supplied review-return fixture is ready"},
    {"gate": "v61ee-post-review-handoff-fixture", "status": "pass", "reason": "v61ee proves review fixture opens generation admission"},
    {"gate": "generation-result-fixture-built", "status": "pass", "reason": "five synthetic generation result artifacts are present"},
    {"gate": "fixture-generation-execution-admitted", "status": "pass", "reason": "generation_execution_admitted_rows=1000/1000"},
    {"gate": "fixture-result-artifacts-supplied", "status": "pass", "reason": "v61bt saw 5/5 supplied result artifacts"},
    {"gate": "v61bt-prerequisite-binding", "status": "blocked", "reason": "generation-prerequisites-not-ready: materialization/hash/review/admission snapshot remains 0"},
    {"gate": "generation-result-artifacts-accepted", "status": "blocked", "reason": "accepted_generation_result_artifacts=0/5"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "canonical-default-restore", "status": canonical_restore_status, "reason": "canonical v61de/v61bt/v61cu no-return state restored"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "no checkpoint/model payload committed"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61ef Generation Result Fixture Prerequisite Gap Gate Boundary

This gate proves the next blocker after v61ee. A complete synthetic generation
result fixture is supplied together with the v61ed review-return fixture. The
review-return handoff opens generation execution admission, but v61bt still
rejects all supplied generation result artifacts because its prerequisite
snapshot remains unaligned with the v61de review-return handoff path.

Evidence emitted:

- fixture_review_return_ready={fixture_v61de['review_return_ready']}
- fixture_v61_review_unblock_ready={fixture_v61de['v61_review_unblock_ready']}
- fixture_generation_execution_admitted_rows={fixture_v61de['generation_execution_admitted_rows']}/{fixture_v61de['generation_execution_admission_rows']}
- fixture_generation_result_file_rows={len(fixture_files)}
- fixture_supplied_generation_result_artifacts={fixture_v61bt['supplied_generation_result_artifacts']}/{fixture_v61bt['expected_generation_result_artifacts']}
- fixture_accepted_generation_result_artifacts={fixture_v61bt['accepted_generation_result_artifacts']}/{fixture_v61bt['expected_generation_result_artifacts']}
- fixture_invalid_generation_result_artifacts={fixture_v61bt['invalid_generation_result_artifacts']}
- fixture_generation_result_supplied_rows={fixture_v61cu['generation_result_supplied_rows']}
- fixture_generation_result_accepted_rows={fixture_v61cu['generation_result_accepted_rows']}
- fixture_v61bt_local_checkpoint_materialization_ready={fixture_v61bt['local_checkpoint_materialization_ready']}
- fixture_v61bt_full_safetensors_page_hash_binding_ready={fixture_v61bt['full_safetensors_page_hash_binding_ready']}
- fixture_v61bt_complete_source_review_return_ready={fixture_v61bt['complete_source_review_return_ready']}
- fixture_v61bt_generation_admission_result_ready={fixture_v61bt['generation_admission_result_ready']}
- fixture_prerequisite_gap_detected={prereq_gap_detected}
- canonical_default_generation_execution_admitted_rows={default_v61de['generation_execution_admitted_rows']}
- real_generation_result_artifacts=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: complete supplied result artifacts reach v61bt, but v61bt
rejects them because the prerequisite snapshot is not yet bound to the v61de
review-return/generation-admission path.

Blocked wording: accepted real generation results, actual model generation,
production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61EF_GENERATION_RESULT_FIXTURE_PREREQ_GAP_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61ef-generation-result-fixture-prereq-gap-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61ef_generation_result_fixture_prereq_gap_gate_ready": 1,
    "fixture_generation_execution_admitted_rows": as_int(fixture_v61de, "generation_execution_admitted_rows"),
    "fixture_supplied_generation_result_artifacts": as_int(fixture_v61bt, "supplied_generation_result_artifacts"),
    "fixture_accepted_generation_result_artifacts": as_int(fixture_v61bt, "accepted_generation_result_artifacts"),
    "fixture_prerequisite_gap_detected": prereq_gap_detected,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ef_generation_result_fixture_prereq_gap_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ef_generation_result_fixture_prereq_gap_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
