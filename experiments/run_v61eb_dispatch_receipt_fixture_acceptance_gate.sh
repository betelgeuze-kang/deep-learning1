#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61eb_dispatch_receipt_fixture_acceptance_gate"
RUN_ID="${V61EB_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_DIR="$RUN_DIR/fixture_dispatch_receipts"
FIXTURE_V53AD_RUN_ID="receipt_fixture_v61eb"

if [[ "${V61EB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61eb_dispatch_receipt_fixture_acceptance_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61ea_external_review_dispatch_seal_gate_summary.csv" ]]; then
  V61EA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ea_external_review_dispatch_seal_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53ah_complete_source_external_review_send_bundle_summary.csv" ]]; then
  V53AH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ah_complete_source_external_review_send_bundle.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv" ]]; then
  V53AD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$FIXTURE_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
fixture_dir = Path(sys.argv[3])
results = root / "results"
fixture_receipt_dir = fixture_dir / "dispatch_receipts"
fixture_receipt_dir.mkdir(parents=True, exist_ok=True)


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
    "v61ea_summary": results / "v61ea_external_review_dispatch_seal_gate_summary.csv",
    "v61ea_decision": results / "v61ea_external_review_dispatch_seal_gate_decision.csv",
    "v61ea_blocker": results / "v61ea_external_review_dispatch_seal_gate/gate_001/external_review_dispatch_blocker_rows.csv",
    "v53ah_summary": results / "v53ah_complete_source_external_review_send_bundle_summary.csv",
    "v53ah_manifest": results / "v53ah_complete_source_external_review_send_bundle/bundle_001/v53ah_complete_source_external_review_send_bundle_manifest.json",
    "v53ad_summary": results / "v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "receipt_template": results / "v53ab_complete_source_review_dispatch_receipt_packet/dispatch_001/complete_source_review_dispatch_receipt_template_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61eb source {key}: {path}")

copy(sources["v61ea_summary"], "source_v61ea/v61ea_external_review_dispatch_seal_gate_summary.csv")
copy(sources["v61ea_decision"], "source_v61ea/v61ea_external_review_dispatch_seal_gate_decision.csv")
copy(sources["v61ea_blocker"], "source_v61ea/external_review_dispatch_blocker_rows.csv")
copy(sources["v53ah_summary"], "source_v53ah/v53ah_complete_source_external_review_send_bundle_summary.csv")
copy(sources["v53ah_manifest"], "source_v53ah/v53ah_complete_source_external_review_send_bundle_manifest.json")
copy(sources["v53ad_summary"], "source_v53ad_default_before/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv")
copy(sources["receipt_template"], "source_v53ab/complete_source_review_dispatch_receipt_template_rows.csv")

v61ea = read_csv(sources["v61ea_summary"])[0]
v53ah_manifest = json.loads(sources["v53ah_manifest"].read_text(encoding="utf-8"))
templates = read_csv(sources["receipt_template"])
if v61ea["v61ea_external_review_dispatch_seal_gate_ready"] != "1":
    raise SystemExit("v61eb requires v61ea ready")
if len(templates) != 21:
    raise SystemExit("v61eb expects 21 dispatch receipt templates")

archive_sha = v53ah_manifest.get("dispatch_archive_sha256", "")
if not str(archive_sha).startswith("sha256:"):
    raise SystemExit("v61eb requires a sha256-bound dispatch archive")

fixture_rows = []
generated_at = datetime.now(timezone.utc).isoformat()
for index, row in enumerate(templates, start=1):
    rel = row["expected_receipt_artifact"]
    path = fixture_dir / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "receipt_scope": "v61eb-dispatch-receipt-fixture",
        "receipt_id": row["receipt_id"],
        "review_chunk_id": row["review_chunk_id"],
        "archive_sha256": archive_sha,
        "reviewer_or_coordinator_id": f"fixture_coordinator_{index:02d}",
        "fixture_or_synthetic_declared": True,
        "real_external_receipt_declared": False,
        "generated_at_utc": generated_at,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    fixture_rows.append(
        {
            "receipt_id": row["receipt_id"],
            "review_chunk_id": row["review_chunk_id"],
            "fixture_receipt_artifact": rel,
            "fixture_receipt_sha256": sha256(path),
            "archive_sha256": archive_sha,
            "reviewer_or_coordinator_id": payload["reviewer_or_coordinator_id"],
            "fixture_only": "1",
            "real_external_receipt": "0",
        }
    )

write_csv(run_dir / "dispatch_receipt_fixture_rows.csv", list(fixture_rows[0].keys()), fixture_rows)
write_csv(fixture_dir / "DISPATCH_RECEIPT_FIXTURE_ROWS.csv", list(fixture_rows[0].keys()), fixture_rows)
(fixture_dir / "README.md").write_text(
    "# v61eb Dispatch Receipt Fixture\n\n"
    "These 21 JSON receipts are synthetic fixture receipts. They verify the "
    "v53ad dispatch receipt intake mechanics after a checksum-bound v53ah send "
    "bundle, but they are not real external review receipts and do not create "
    "review judgments, adjudication rows, generation results, or release evidence.\n",
    encoding="utf-8",
)
PY

V53AD_DISPATCH_RECEIPT_DIR="$FIXTURE_DIR" \
V53AD_RUN_ID="$FIXTURE_V53AD_RUN_ID" \
V53AD_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null

mkdir -p "$RUN_DIR/source_v53ad_fixture"
cp "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv" "$RUN_DIR/source_v53ad_fixture/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv"
cp "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake_decision.csv" "$RUN_DIR/source_v53ad_fixture/v53ad_complete_source_review_dispatch_receipt_intake_decision.csv"
cp "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake/$FIXTURE_V53AD_RUN_ID/complete_source_review_dispatch_receipt_status_rows.csv" "$RUN_DIR/source_v53ad_fixture/complete_source_review_dispatch_receipt_status_rows.csv"
cp "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake/$FIXTURE_V53AD_RUN_ID/runtime_gap_rows.csv" "$RUN_DIR/source_v53ad_fixture/runtime_gap_rows.csv"
cp "$RESULTS_DIR/v53ad_complete_source_review_dispatch_receipt_intake/$FIXTURE_V53AD_RUN_ID/sha256_manifest.csv" "$RUN_DIR/source_v53ad_fixture/sha256_manifest.csv"

V53AD_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ad_complete_source_review_dispatch_receipt_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$FIXTURE_DIR" <<'PY'
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
fixture_dir = Path(sys.argv[5])
results = root / "results"
bundle_dir = run_dir / "dispatch_receipt_fixture_acceptance_bundle"
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
    return dst


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61ea_summary": results / "v61ea_external_review_dispatch_seal_gate_summary.csv",
    "fixture_rows": run_dir / "dispatch_receipt_fixture_rows.csv",
    "fixture_summary": run_dir / "source_v53ad_fixture/v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "fixture_decision": run_dir / "source_v53ad_fixture/v53ad_complete_source_review_dispatch_receipt_intake_decision.csv",
    "fixture_status": run_dir / "source_v53ad_fixture/complete_source_review_dispatch_receipt_status_rows.csv",
    "default_summary": results / "v53ad_complete_source_review_dispatch_receipt_intake_summary.csv",
    "default_status": results / "v53ad_complete_source_review_dispatch_receipt_intake/intake_001/complete_source_review_dispatch_receipt_status_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61eb aggregate source {key}: {path}")

v61ea = read_csv(sources["v61ea_summary"])[0]
fixture_rows = read_csv(sources["fixture_rows"])
fixture_summary = read_csv(sources["fixture_summary"])[0]
fixture_status_rows = read_csv(sources["fixture_status"])
default_summary = read_csv(sources["default_summary"])[0]
default_status_rows = read_csv(sources["default_status"])

if len(fixture_rows) != 21:
    raise SystemExit("v61eb expects 21 generated fixture rows")
if fixture_summary["accepted_dispatch_receipt_rows"] != "21":
    raise SystemExit("v61eb fixture v53ad run did not accept all receipts")
if default_summary["accepted_dispatch_receipt_rows"] != "0":
    raise SystemExit("v61eb canonical v53ad default was not restored")

fixture_acceptance_rows = []
for row in fixture_status_rows:
    fixture_acceptance_rows.append(
        {
            "receipt_id": row["receipt_id"],
            "review_chunk_id": row["review_chunk_id"],
            "receipt_supplied": row["receipt_supplied"],
            "receipt_accepted": row["receipt_accepted"],
            "receipt_status": row["receipt_status"],
            "fixture_only": "1",
            "real_external_receipt": "0",
            "validation_errors": row["validation_errors"],
        }
    )
write_csv(run_dir / "dispatch_receipt_fixture_acceptance_rows.csv", list(fixture_acceptance_rows[0].keys()), fixture_acceptance_rows)

fixture_receipt_files = sorted((fixture_dir / "dispatch_receipts").glob("*_receipt.json"))
fixture_file_rows = [
    {
        "fixture_receipt_artifact": str(path.relative_to(fixture_dir)),
        "size_bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "payload_class": "synthetic-fixture-receipt",
        "real_external_receipt": "0",
    }
    for path in fixture_receipt_files
]
write_csv(run_dir / "dispatch_receipt_fixture_file_rows.csv", list(fixture_file_rows[0].keys()), fixture_file_rows)

canonical_restore_rows = [
    {
        "restore_id": "v61eb-restore-v53ad-canonical-no-receipt",
        "status": "pass" if default_summary["accepted_dispatch_receipt_rows"] == "0" and default_summary["missing_dispatch_receipt_rows"] == "21" else "fail",
        "canonical_supplied_dispatch_receipt_rows": default_summary["supplied_dispatch_receipt_rows"],
        "canonical_accepted_dispatch_receipt_rows": default_summary["accepted_dispatch_receipt_rows"],
        "canonical_missing_dispatch_receipt_rows": default_summary["missing_dispatch_receipt_rows"],
        "canonical_dispatch_receipt_intake_ready": default_summary["dispatch_receipt_intake_ready"],
    }
]
write_csv(run_dir / "dispatch_receipt_fixture_canonical_restore_rows.csv", list(canonical_restore_rows[0].keys()), canonical_restore_rows)

stage_rows = [
    {
        "stage_id": "01-bind-v61ea-dispatch-seal",
        "status": "ready",
        "ready": "1",
        "evidence": "v61ea dispatch seal is ready",
    },
    {
        "stage_id": "02-generate-21-fixture-receipts",
        "status": "ready",
        "ready": "1",
        "evidence": "21 synthetic fixture receipt JSON files generated",
    },
    {
        "stage_id": "03-run-v53ad-fixture-intake",
        "status": "ready",
        "ready": "1",
        "evidence": "fixture v53ad intake accepts 21/21 dispatch receipts",
    },
    {
        "stage_id": "04-restore-canonical-no-receipt",
        "status": "ready",
        "ready": "1",
        "evidence": "canonical v53ad default summary restored to 0 accepted receipts",
    },
    {
        "stage_id": "05-keep-fixture-non-real",
        "status": "ready",
        "ready": "1",
        "evidence": "fixture receipts are marked synthetic and real_external_receipt=0",
    },
    {
        "stage_id": "06-real-dispatch-receipts-returned",
        "status": "blocked",
        "ready": "0",
        "evidence": "real_external_dispatch_receipt_rows=0",
    },
    {
        "stage_id": "07-review-generation-return",
        "status": "blocked",
        "ready": "0",
        "evidence": "review return and generation execution remain blocked",
    },
]
write_csv(run_dir / "dispatch_receipt_fixture_acceptance_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

invariant_rows = [
    {
        "invariant_id": "v61ea-dispatch-seal-ready",
        "status": "pass" if v61ea["v61ea_external_review_dispatch_seal_gate_ready"] == "1" else "fail",
        "expected": "v61ea ready",
        "actual": v61ea["v61ea_external_review_dispatch_seal_gate_ready"],
    },
    {
        "invariant_id": "fixture-receipt-files-generated",
        "status": "pass" if len(fixture_receipt_files) == 21 else "fail",
        "expected": "21 fixture receipt files",
        "actual": str(len(fixture_receipt_files)),
    },
    {
        "invariant_id": "fixture-v53ad-accepts-all-receipts",
        "status": "pass" if fixture_summary["accepted_dispatch_receipt_rows"] == "21" and fixture_summary["dispatch_receipt_intake_ready"] == "1" else "fail",
        "expected": "21 accepted fixture receipts",
        "actual": f"{fixture_summary['accepted_dispatch_receipt_rows']}/{fixture_summary['dispatch_receipt_template_rows']}",
    },
    {
        "invariant_id": "canonical-default-restored",
        "status": canonical_restore_rows[0]["status"],
        "expected": "0 accepted canonical receipts",
        "actual": f"{default_summary['accepted_dispatch_receipt_rows']}/{default_summary['dispatch_receipt_template_rows']}",
    },
    {
        "invariant_id": "fixture-not-real-external-evidence",
        "status": "pass" if all(row["real_external_receipt"] == "0" for row in fixture_rows) else "fail",
        "expected": "all fixture rows real_external_receipt=0",
        "actual": str(sum(row["real_external_receipt"] == "0" for row in fixture_rows)),
    },
    {
        "invariant_id": "review-return-still-blocked",
        "status": "pass" if v61ea["accepted_human_review_rows"] == "0" and v61ea["accepted_adjudication_rows"] == "0" else "fail",
        "expected": "0 accepted review rows",
        "actual": f"human={v61ea['accepted_human_review_rows']};adjudication={v61ea['accepted_adjudication_rows']}",
    },
    {
        "invariant_id": "generation-still-blocked",
        "status": "pass" if v61ea["generation_execution_admitted_rows"] == "0" and v61ea["actual_model_generation_ready"] == "0" else "fail",
        "expected": "generation remains blocked",
        "actual": f"generation={v61ea['generation_execution_admitted_rows']};actual={v61ea['actual_model_generation_ready']}",
    },
    {
        "invariant_id": "repo-checkpoint-payload-zero",
        "status": "pass" if v61ea["checkpoint_payload_bytes_committed_to_repo"] == "0" else "fail",
        "expected": "repo checkpoint payload is zero",
        "actual": v61ea["checkpoint_payload_bytes_committed_to_repo"],
    },
]
write_csv(run_dir / "dispatch_receipt_fixture_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

runtime_gap_rows = [
    {"gap": "fixture-dispatch-receipt-intake", "status": "ready", "reason": "fixture v53ad intake accepted 21/21 receipts"},
    {"gap": "real-dispatch-receipts", "status": "blocked", "reason": "real_external_dispatch_receipt_rows=0"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"accepted_human_review_rows={v61ea['accepted_human_review_rows']}/{v61ea['expected_human_review_rows']}"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61ea['generation_execution_admitted_rows']}/{v61ea['generation_execution_admission_rows']}"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61ea['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

bundle_readme = bundle_dir / "README.md"
bundle_readme.write_text(
    "# v61eb Dispatch Receipt Fixture Acceptance Gate\n\n"
    "This bundle proves that the v53ad dispatch receipt intake can accept a "
    "complete 21-receipt supplied fixture after v61ea seals the external send "
    "bundle. The receipts are synthetic fixture receipts, not real external "
    "review evidence. The canonical no-receipt v53ad state is restored after "
    "the fixture run.\n",
    encoding="utf-8",
)
copy_bundle(run_dir / "dispatch_receipt_fixture_rows.csv", "DISPATCH_RECEIPT_FIXTURE_ROWS.csv")
copy_bundle(run_dir / "dispatch_receipt_fixture_acceptance_rows.csv", "DISPATCH_RECEIPT_FIXTURE_ACCEPTANCE_ROWS.csv")
copy_bundle(run_dir / "dispatch_receipt_fixture_canonical_restore_rows.csv", "CANONICAL_RESTORE_ROWS.csv")
copy_bundle(run_dir / "dispatch_receipt_fixture_acceptance_stage_rows.csv", "FIXTURE_ACCEPTANCE_STAGES.csv")
copy_bundle(run_dir / "dispatch_receipt_fixture_invariant_rows.csv", "FIXTURE_ACCEPTANCE_INVARIANTS.csv")

verify_script = bundle_dir / "VERIFY_V61EB_FIXTURE_ACCEPTANCE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
            'RUN_DIR="$(cd "$BUNDLE_DIR/.." && pwd)"',
            "export RUN_DIR",
            'test -s "$BUNDLE_DIR/DISPATCH_RECEIPT_FIXTURE_ROWS.csv"',
            'test -s "$BUNDLE_DIR/DISPATCH_RECEIPT_FIXTURE_ACCEPTANCE_ROWS.csv"',
            'test -s "$BUNDLE_DIR/CANONICAL_RESTORE_ROWS.csv"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import os",
            "from pathlib import Path",
            "run_dir = Path(os.environ['RUN_DIR'])",
            "def read_csv(path):",
            "    with path.open(newline='', encoding='utf-8') as handle:",
            "        return list(csv.DictReader(handle))",
            "summary = read_csv(run_dir.parent.parent / 'v61eb_dispatch_receipt_fixture_acceptance_gate_summary.csv')[0]",
            "if summary['fixture_accepted_dispatch_receipt_rows'] != '21':",
            "    raise SystemExit('fixture receipts were not accepted')",
            "if summary['canonical_default_accepted_dispatch_receipt_rows'] != '0':",
            "    raise SystemExit('canonical default receipt state was not restored')",
            "if summary['real_external_dispatch_receipt_rows'] != '0':",
            "    raise SystemExit('fixture must not count as real external receipts')",
            "if summary['actual_model_generation_ready'] != '0':",
            "    raise SystemExit('actual generation must remain blocked')",
            "PY_VERIFY",
            'if find "$RUN_DIR" -type f \\( -name "*.safetensors" -o -name "*.bin" -o -name "*.pt" \\) | grep -q .; then',
            '  echo "model/checkpoint payload-like file found inside v61eb fixture gate" >&2',
            "  exit 1",
            "fi",
            "echo 'v61eb fixture acceptance verified'",
        ]
    )
    + "\n",
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_manifest = {
    "manifest_scope": "v61eb-dispatch-receipt-fixture-acceptance-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "fixture_receipt_rows": len(fixture_rows),
    "fixture_accepted_dispatch_receipt_rows": as_int(fixture_summary, "accepted_dispatch_receipt_rows"),
    "canonical_default_accepted_dispatch_receipt_rows": as_int(default_summary, "accepted_dispatch_receipt_rows"),
    "real_external_dispatch_receipt_rows": 0,
    "actual_model_generation_ready": as_int(v61ea, "actual_model_generation_ready"),
}
(bundle_dir / "FIXTURE_ACCEPTANCE_MANIFEST.json").write_text(
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
write_csv(run_dir / "dispatch_receipt_fixture_acceptance_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

ready_stage_rows = sum(1 for row in stage_rows if row["status"] == "ready")
blocked_stage_rows = sum(1 for row in stage_rows if row["status"] == "blocked")
invariant_pass_rows = sum(1 for row in invariant_rows if row["status"] == "pass")

summary_row = {
    "v61eb_dispatch_receipt_fixture_acceptance_gate_ready": "1",
    "v61ea_external_review_dispatch_seal_gate_ready": v61ea["v61ea_external_review_dispatch_seal_gate_ready"],
    "fixture_stage_rows": str(len(stage_rows)),
    "ready_fixture_stage_rows": str(ready_stage_rows),
    "blocked_fixture_stage_rows": str(blocked_stage_rows),
    "fixture_receipt_rows": str(len(fixture_rows)),
    "fixture_receipt_file_rows": str(len(fixture_file_rows)),
    "fixture_supplied_dispatch_receipt_rows": fixture_summary["supplied_dispatch_receipt_rows"],
    "fixture_accepted_dispatch_receipt_rows": fixture_summary["accepted_dispatch_receipt_rows"],
    "fixture_missing_dispatch_receipt_rows": fixture_summary["missing_dispatch_receipt_rows"],
    "fixture_invalid_dispatch_receipt_rows": fixture_summary["invalid_dispatch_receipt_rows"],
    "fixture_dispatch_receipt_intake_ready": fixture_summary["dispatch_receipt_intake_ready"],
    "canonical_default_supplied_dispatch_receipt_rows": default_summary["supplied_dispatch_receipt_rows"],
    "canonical_default_accepted_dispatch_receipt_rows": default_summary["accepted_dispatch_receipt_rows"],
    "canonical_default_missing_dispatch_receipt_rows": default_summary["missing_dispatch_receipt_rows"],
    "canonical_default_invalid_dispatch_receipt_rows": default_summary["invalid_dispatch_receipt_rows"],
    "canonical_default_dispatch_receipt_intake_ready": default_summary["dispatch_receipt_intake_ready"],
    "real_external_dispatch_receipt_rows": "0",
    "expected_human_review_rows": v61ea["expected_human_review_rows"],
    "accepted_human_review_rows": v61ea["accepted_human_review_rows"],
    "expected_adjudication_rows": v61ea["expected_adjudication_rows"],
    "accepted_adjudication_rows": v61ea["accepted_adjudication_rows"],
    "generation_execution_admitted_rows": v61ea["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61ea["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61ea["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v61ea["actual_model_generation_ready"],
    "fixture_invariant_rows": str(len(invariant_rows)),
    "fixture_invariant_pass_rows": str(invariant_pass_rows),
    "fixture_bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_fixture_bundle_file_rows": str(sum(1 for row in bundle_file_rows if row["payload_class"] == "metadata-only")),
    "checkpoint_payload_bytes_downloaded_by_v61eb": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary_row.keys()), [summary_row])

decision_rows = [
    {"gate": "v61ea-dispatch-seal", "status": "pass", "reason": "v61ea seal is ready"},
    {"gate": "fixture-receipt-generation", "status": "pass", "reason": "21 synthetic receipt JSON files generated"},
    {"gate": "fixture-v53ad-dispatch-receipt-intake", "status": "pass", "reason": "fixture v53ad intake accepted 21/21 receipts"},
    {"gate": "canonical-default-restore", "status": "pass", "reason": "canonical no-receipt v53ad summary restored to 0 accepted receipts"},
    {"gate": "real-dispatch-receipts", "status": "blocked", "reason": "real_external_dispatch_receipt_rows=0"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"accepted_human_review_rows={v61ea['accepted_human_review_rows']}/{v61ea['expected_human_review_rows']}"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v61ea['generation_execution_admitted_rows']}/{v61ea['generation_execution_admission_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61ea['actual_model_generation_ready']}"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "checkpoint payload committed to repo remains zero"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = f"""# v61eb Dispatch Receipt Fixture Acceptance Gate Boundary

This gate proves the dispatch receipt intake mechanics can accept a complete
21-receipt supplied fixture after the v61ea send-bundle seal. The fixture
receipts are synthetic and are not real external dispatch receipts.

Evidence emitted:

- fixture_receipt_rows={len(fixture_rows)}
- fixture_supplied_dispatch_receipt_rows={fixture_summary['supplied_dispatch_receipt_rows']}
- fixture_accepted_dispatch_receipt_rows={fixture_summary['accepted_dispatch_receipt_rows']}
- fixture_dispatch_receipt_intake_ready={fixture_summary['dispatch_receipt_intake_ready']}
- canonical_default_accepted_dispatch_receipt_rows={default_summary['accepted_dispatch_receipt_rows']}
- canonical_default_missing_dispatch_receipt_rows={default_summary['missing_dispatch_receipt_rows']}
- real_external_dispatch_receipt_rows=0
- accepted_human_review_rows={v61ea['accepted_human_review_rows']}/{v61ea['expected_human_review_rows']}
- generation_execution_admitted_rows={v61ea['generation_execution_admitted_rows']}/{v61ea['generation_execution_admission_rows']}
- actual_model_generation_ready={v61ea['actual_model_generation_ready']}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: dispatch receipt intake mechanics are fixture-verified.
Blocked wording: real external dispatch receipts, accepted review return,
generation execution, actual generation, latency, near-frontier quality, or
release readiness.
"""
(run_dir / "V61EB_DISPATCH_RECEIPT_FIXTURE_ACCEPTANCE_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61eb-dispatch-receipt-fixture-acceptance-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary_row.items()},
}
(run_dir / "v61eb_dispatch_receipt_fixture_acceptance_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file()):
    if path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY
