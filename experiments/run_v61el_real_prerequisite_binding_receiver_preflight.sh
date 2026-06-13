#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61el_real_prerequisite_binding_receiver_preflight"
RUN_ID="${V61EL_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BINDING_DIR_ARG="${V61EL_PREREQUISITE_BINDING_DIR:-}"
BINDING_PROVENANCE="${V61EL_BINDING_PROVENANCE:-unspecified}"

if [[ "${V61EL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61el_real_prerequisite_binding_receiver_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eh_real_generation_result_return_packet.sh" >/dev/null
V61EK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ek_preflight_to_generation_intake_handoff_guard.sh" >/dev/null
V61BT_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh" >/dev/null
V61DE_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61de_post_review_generation_result_handoff_bridge.sh" >/dev/null
V61CK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ck_real_generation_unblocker_operator_matrix.sh" >/dev/null
V61CS_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cs_complete_source_generation_execution_admission_gate.sh" >/dev/null
V61DD_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dd_review_return_generation_refresh_bridge.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$BINDING_DIR_ARG" "$BINDING_PROVENANCE" <<'PY'
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
binding_arg = sys.argv[5].strip()
binding_provenance = sys.argv[6].strip() or "unspecified"
results = root / "results"
binding_dir = Path(binding_arg).expanduser().resolve() if binding_arg else None
known_fixture_binding_dir = (
    results
    / "v61eg_generation_result_prereq_binding_fixture_gate"
    / "gate_001"
    / "v61bt_prerequisite_binding"
).resolve()


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


def pass_status(flag):
    return "pass" if flag else "blocked"


def ready_status(flag):
    return "ready" if flag else "blocked"


source_files = {
    "v61eh_summary": results / "v61eh_real_generation_result_return_packet_summary.csv",
    "v61ek_summary": results / "v61ek_preflight_to_generation_intake_handoff_guard_summary.csv",
    "v61bt_summary": results / "v61bt_ubuntu1_actual_generation_result_intake_summary.csv",
    "v61de_summary": results / "v61de_post_review_generation_result_handoff_bridge_summary.csv",
    "v61ck_summary": results / "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
    "v61cs_summary": results / "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
    "v61dd_summary": results / "v61dd_review_return_generation_refresh_bridge_summary.csv",
}
for key, path in source_files.items():
    if not path.is_file():
        raise SystemExit(f"missing v61el source {key}: {path}")
    copy(path, f"source_summaries/{path.name}")

v61eh = read_csv(source_files["v61eh_summary"])[0]
v61ek = read_csv(source_files["v61ek_summary"])[0]
v61bt = read_csv(source_files["v61bt_summary"])[0]
v61de = read_csv(source_files["v61de_summary"])[0]

model_id = v61bt["model_id"]
target_root = v61bt["target_root_path"]
expected_generation_rows = v61bt["expected_generation_rows"]

required_sources = {
    "v61ck": {
        "file": "v61ck_real_generation_unblocker_operator_matrix_summary.csv",
        "required_checks": [
            ("full_checkpoint_materialization_ready", "1"),
            ("completed_full_safetensors_page_hash_coverage_ready", "1"),
            ("full_safetensors_page_hash_binding_ready", "1"),
        ],
    },
    "v61cs": {
        "file": "v61cs_complete_source_generation_execution_admission_gate_summary.csv",
        "required_checks": [
            ("complete_source_review_return_ready", "1"),
            ("generation_execution_admission_ready", "1"),
            ("generation_execution_admitted_rows", expected_generation_rows),
            ("generation_execution_admission_rows", expected_generation_rows),
        ],
    },
    "v61dd": {
        "file": "v61dd_review_return_generation_refresh_bridge_summary.csv",
        "required_checks": [
            ("review_return_ready", "1"),
            ("v61_review_unblock_ready", "1"),
            ("generation_execution_admitted_rows", expected_generation_rows),
        ],
    },
}

binding_dir_supplied = int(binding_dir is not None)
binding_dir_exists = int(binding_dir is not None and binding_dir.is_dir())
if not binding_dir_supplied:
    selected_binding_source_class = "none"
elif binding_dir == known_fixture_binding_dir:
    selected_binding_source_class = "fixture-v61eg-prerequisite-binding"
else:
    selected_binding_source_class = "operator-supplied"

file_rows = []
source_rows = {}
for source_id, spec in required_sources.items():
    path = binding_dir / spec["file"] if binding_dir is not None else None
    exists = int(path is not None and path.is_file())
    readable = 0
    row_count = 0
    source_row = {}
    digest = ""
    if exists:
        source_rows_read = read_csv(path)
        row_count = len(source_rows_read)
        readable = int(row_count > 0)
        source_row = source_rows_read[0] if readable else {}
        digest = sha256(path)
        copy(path, f"selected_prerequisite_binding/{spec['file']}")
    source_rows[source_id] = source_row
    file_rows.append(
        {
            "source_id": source_id,
            "required_file": spec["file"],
            "binding_dir_supplied": str(binding_dir_supplied),
            "file_exists": str(exists),
            "csv_readable": str(readable),
            "row_count": str(row_count),
            "sha256": digest,
        }
    )
write_csv(run_dir / "prerequisite_binding_file_rows.csv", list(file_rows[0].keys()), file_rows)

required_file_rows = len(required_sources)
present_file_rows = sum(row["file_exists"] == "1" for row in file_rows)
readable_file_rows = sum(row["csv_readable"] == "1" for row in file_rows)

check_rows = [
    {
        "check_id": "binding-dir-supplied",
        "status": pass_status(binding_dir_supplied),
        "required_value": "1",
        "actual_value": str(binding_dir_supplied),
        "reason": "operator must supply V61EL_PREREQUISITE_BINDING_DIR",
    },
    {
        "check_id": "binding-dir-exists",
        "status": pass_status(binding_dir_exists),
        "required_value": "1",
        "actual_value": str(binding_dir_exists),
        "reason": "supplied binding directory must exist",
    },
    {
        "check_id": "required-binding-files-present",
        "status": pass_status(present_file_rows == required_file_rows),
        "required_value": str(required_file_rows),
        "actual_value": str(present_file_rows),
        "reason": "v61bt requires v61ck/v61cs/v61dd summary files",
    },
    {
        "check_id": "required-binding-files-readable",
        "status": pass_status(readable_file_rows == required_file_rows),
        "required_value": str(required_file_rows),
        "actual_value": str(readable_file_rows),
        "reason": "each supplied binding summary must have a readable data row",
    },
]

model_match_rows = 0
target_match = 0
required_ready_check_rows = 0
ready_check_pass_rows = 0
field_check_rows = []
for source_id, spec in required_sources.items():
    row = source_rows[source_id]
    model_match = int(row.get("model_id") == model_id)
    model_match_rows += model_match
    field_check_rows.append(
        {
            "source_id": source_id,
            "field": "model_id",
            "required_value": model_id,
            "actual_value": row.get("model_id", ""),
            "status": pass_status(model_match),
        }
    )
    if source_id == "v61ck":
        target_match = int(row.get("target_root_path") == target_root)
        field_check_rows.append(
            {
                "source_id": source_id,
                "field": "target_root_path",
                "required_value": target_root,
                "actual_value": row.get("target_root_path", ""),
                "status": pass_status(target_match),
            }
        )
    for field, required_value in spec["required_checks"]:
        required_ready_check_rows += 1
        actual_value = row.get(field, "")
        field_pass = int(actual_value == required_value)
        ready_check_pass_rows += field_pass
        field_check_rows.append(
            {
                "source_id": source_id,
                "field": field,
                "required_value": required_value,
                "actual_value": actual_value,
                "status": pass_status(field_pass),
            }
        )
write_csv(run_dir / "prerequisite_binding_field_check_rows.csv", list(field_check_rows[0].keys()), field_check_rows)

check_rows.extend(
    [
        {
            "check_id": "binding-model-match",
            "status": pass_status(model_match_rows == required_file_rows),
            "required_value": str(required_file_rows),
            "actual_value": str(model_match_rows),
            "reason": "all binding source summaries must match the target model",
        },
        {
            "check_id": "binding-target-match",
            "status": pass_status(target_match),
            "required_value": "1",
            "actual_value": str(target_match),
            "reason": "v61ck binding target_root_path must match v61bt target root",
        },
        {
            "check_id": "binding-ready-fields-pass",
            "status": pass_status(ready_check_pass_rows == required_ready_check_rows),
            "required_value": str(required_ready_check_rows),
            "actual_value": str(ready_check_pass_rows),
            "reason": "materialization, page hash, review return, and generation admission fields must all pass",
        },
    ]
)

binding_candidate_preflight_ready = int(
    binding_dir_supplied
    and binding_dir_exists
    and present_file_rows == required_file_rows
    and readable_file_rows == required_file_rows
    and model_match_rows == required_file_rows
    and target_match
    and ready_check_pass_rows == required_ready_check_rows
)
non_fixture_binding = int(selected_binding_source_class == "operator-supplied")
real_provenance_asserted = int(binding_provenance == "real-review-return")
real_prerequisite_binding_ready = int(
    binding_candidate_preflight_ready and non_fixture_binding and real_provenance_asserted
)

check_rows.extend(
    [
        {
            "check_id": "binding-candidate-preflight-ready",
            "status": pass_status(binding_candidate_preflight_ready),
            "required_value": "1",
            "actual_value": str(binding_candidate_preflight_ready),
            "reason": "schema and readiness checks for the selected binding candidate must pass",
        },
        {
            "check_id": "non-fixture-binding-source",
            "status": pass_status(non_fixture_binding),
            "required_value": "1",
            "actual_value": str(non_fixture_binding),
            "reason": "v61eg fixture binding mechanics are not accepted as real prerequisite binding",
        },
        {
            "check_id": "real-review-return-provenance",
            "status": pass_status(real_provenance_asserted),
            "required_value": "real-review-return",
            "actual_value": binding_provenance,
            "reason": "real binding admission requires explicit real review-return provenance",
        },
    ]
)
write_csv(run_dir / "prerequisite_binding_preflight_check_rows.csv", list(check_rows[0].keys()), check_rows)

v61bt_intake_handoff_ready = int(real_prerequisite_binding_ready)
v61de_generation_result_handoff_ready = int(
    real_prerequisite_binding_ready and as_int(v61eh, "real_review_return_ready")
)
actual_model_generation_ready = 0

command_rows = [
    {
        "command_id": "run-v61el-canonical-preflight",
        "command": "./experiments/test_v61el_real_prerequisite_binding_receiver_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "verify the no-binding canonical receiver-preflight state",
    },
    {
        "command_id": "run-v61el-with-real-binding-dir",
        "command": "V61EL_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding V61EL_BINDING_PROVENANCE=real-review-return ./experiments/run_v61el_real_prerequisite_binding_receiver_preflight.sh",
        "ready_to_run_now": "1",
        "purpose": "preflight a supplied real prerequisite binding directory",
    },
    {
        "command_id": "run-v61bt-after-real-binding",
        "command": "V61BT_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61BT_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "ready_to_run_now": str(v61bt_intake_handoff_ready),
        "purpose": "accept real generation-result artifacts only after real prerequisite binding passes",
    },
    {
        "command_id": "run-v61de-after-real-binding",
        "command": "V61DE_REVIEW_RETURN_DIR=/path/to/real_review_return V61DE_GENERATION_RESULT_DIR=/path/to/real_generation_result_return V61DE_PREREQUISITE_BINDING_DIR=/path/to/real_prerequisite_binding ./experiments/run_v61de_post_review_generation_result_handoff_bridge.sh",
        "ready_to_run_now": str(v61de_generation_result_handoff_ready),
        "purpose": "refresh post-review generation handoff after real binding and review return",
    },
    {
        "command_id": "refresh-v61ek-handoff",
        "command": "./experiments/test_v61ek_preflight_to_generation_intake_handoff_guard.sh",
        "ready_to_run_now": "1",
        "purpose": "confirm the generation-intake handoff boundary remains claim-safe",
    },
]
write_csv(run_dir / "prerequisite_binding_handoff_command_rows.csv", list(command_rows[0].keys()), command_rows)

metric = {
    "v61el_real_prerequisite_binding_receiver_preflight_ready": "1",
    "v61eh_real_generation_result_return_packet_ready": v61eh["v61eh_real_generation_result_return_packet_ready"],
    "v61ek_preflight_to_generation_intake_handoff_guard_ready": v61ek["v61ek_preflight_to_generation_intake_handoff_guard_ready"],
    "binding_dir_supplied": str(binding_dir_supplied),
    "binding_dir_exists": str(binding_dir_exists),
    "selected_binding_source_class": selected_binding_source_class,
    "binding_provenance": binding_provenance,
    "required_binding_source_files": str(required_file_rows),
    "present_binding_source_files": str(present_file_rows),
    "readable_binding_source_files": str(readable_file_rows),
    "model_match_rows": str(model_match_rows),
    "target_match": str(target_match),
    "required_ready_check_rows": str(required_ready_check_rows),
    "ready_check_pass_rows": str(ready_check_pass_rows),
    "binding_candidate_preflight_ready": str(binding_candidate_preflight_ready),
    "non_fixture_binding_source": str(non_fixture_binding),
    "real_review_return_provenance_asserted": str(real_provenance_asserted),
    "real_prerequisite_binding_ready": str(real_prerequisite_binding_ready),
    "v61bt_intake_handoff_ready": str(v61bt_intake_handoff_ready),
    "v61de_generation_result_handoff_ready": str(v61de_generation_result_handoff_ready),
    "real_review_return_ready": v61eh["real_review_return_ready"],
    "generation_execution_admitted_rows": v61eh["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61eh["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61bt["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61bt["expected_generation_result_artifacts"],
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61el": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "prerequisite_binding_preflight_metric_rows.csv", list(metric.keys()), [metric])
write_csv(summary_csv, list(metric.keys()), [metric])

decision_rows = [
    {"gate": "source-gates-ready", "status": "pass", "reason": "v61eh/v61ek/v61bt/v61de summaries are present"},
    {"gate": "binding-candidate-preflight", "status": pass_status(binding_candidate_preflight_ready), "reason": f"ready_checks={ready_check_pass_rows}/{required_ready_check_rows}; files={present_file_rows}/{required_file_rows}"},
    {"gate": "non-fixture-binding-source", "status": pass_status(non_fixture_binding), "reason": f"selected_binding_source_class={selected_binding_source_class}"},
    {"gate": "real-review-return-provenance", "status": pass_status(real_provenance_asserted), "reason": f"binding_provenance={binding_provenance}"},
    {"gate": "real-prerequisite-binding", "status": pass_status(real_prerequisite_binding_ready), "reason": f"real_prerequisite_binding_ready={real_prerequisite_binding_ready}"},
    {"gate": "v61bt-intake-handoff", "status": pass_status(v61bt_intake_handoff_ready), "reason": f"real_prerequisite_binding_ready={real_prerequisite_binding_ready}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "preflight does not accept generation results or claim generation"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only preflight"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = f"""# v61el Real Prerequisite Binding Receiver Preflight

This receiver preflights a supplied prerequisite binding directory for the
v61bt/v61de generation-result path. It validates the v61ck/v61cs/v61dd summary
shape and readiness fields but does not count a supplied directory as real
generation evidence.

- binding_dir_supplied={binding_dir_supplied}
- binding_dir_exists={binding_dir_exists}
- selected_binding_source_class={selected_binding_source_class}
- binding_candidate_preflight_ready={binding_candidate_preflight_ready}
- non_fixture_binding_source={non_fixture_binding}
- real_review_return_provenance_asserted={real_provenance_asserted}
- real_prerequisite_binding_ready={real_prerequisite_binding_ready}
- v61bt_intake_handoff_ready={v61bt_intake_handoff_ready}
- v61de_generation_result_handoff_ready={v61de_generation_result_handoff_ready}
- actual_model_generation_ready={actual_model_generation_ready}

Allowed wording: prerequisite binding receiver preflight is available, and a
fixture binding can prove the mechanics.

Blocked wording: fixture binding or schema-valid preflight alone is not real
prerequisite binding, actual generation, near-frontier quality, production
latency, or release readiness.
"""
(run_dir / "V61EL_REAL_PREREQUISITE_BINDING_RECEIVER_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61el-real-prerequisite-binding-receiver-preflight",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "v61el_real_prerequisite_binding_receiver_preflight_ready": 1,
    "binding_candidate_preflight_ready": binding_candidate_preflight_ready,
    "real_prerequisite_binding_ready": real_prerequisite_binding_ready,
    "actual_model_generation_ready": actual_model_generation_ready,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61el_real_prerequisite_binding_receiver_preflight_manifest.json").write_text(
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

echo "v61el_real_prerequisite_binding_receiver_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
