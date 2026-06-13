#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53al_complete_source_external_return_bundle_preflight"
RUN_ID="${V53AL_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V53AL_RETURN_BUNDLE_DIR:-}"

if [[ "${V53AL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53al_complete_source_external_return_bundle_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  V53AK_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null
else
  V53AK_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" <<'PY'
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
return_bundle_arg = sys.argv[5]
return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
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


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v53ak_summary_path = results / "v53ak_complete_source_external_return_operator_checklist_summary.csv"
v53ak_decision_path = results / "v53ak_complete_source_external_return_operator_checklist_decision.csv"
v53ak_dir = results / "v53ak_complete_source_external_return_operator_checklist" / "checklist_001"
v53ak = read_csv(v53ak_summary_path)[0]
if v53ak["v53ak_complete_source_external_return_operator_checklist_ready"] != "1":
    raise SystemExit("v53al requires v53ak operator checklist readiness")

for src, rel in [
    (v53ak_summary_path, "source_v53ak/v53ak_complete_source_external_return_operator_checklist_summary.csv"),
    (v53ak_decision_path, "source_v53ak/v53ak_complete_source_external_return_operator_checklist_decision.csv"),
    (v53ak_dir / "external_return_operator_checklist_rows.csv", "source_v53ak/external_return_operator_checklist_rows.csv"),
    (v53ak_dir / "external_return_operator_family_checklist_rows.csv", "source_v53ak/external_return_operator_family_checklist_rows.csv"),
    (v53ak_dir / "external_return_operator_closure_checklist_rows.csv", "source_v53ak/external_return_operator_closure_checklist_rows.csv"),
    (v53ak_dir / "runtime_gap_rows.csv", "source_v53ak/runtime_gap_rows.csv"),
]:
    copy(src, rel)

checklist_rows = read_csv(v53ak_dir / "external_return_operator_checklist_rows.csv")
family_source_rows = read_csv(v53ak_dir / "external_return_operator_family_checklist_rows.csv")

preflight_rows = []
for row in checklist_rows:
    bundle_rel = row["final_return_bundle_relative_path"]
    candidate = return_bundle_dir / bundle_rel if return_bundle_dir else None
    file_exists = int(candidate is not None and candidate.is_file())
    bytes_size = candidate.stat().st_size if file_exists else 0
    template_named = int(candidate is not None and candidate.name.endswith(".template"))
    non_template_name = int(not bundle_rel.endswith(".template"))
    non_empty = int(file_exists and bytes_size > 0)
    preflight_pass = int(file_exists and non_template_name and not template_named and non_empty)
    preflight_rows.append(
        {
            "checklist_item_id": row["checklist_item_id"],
            "return_family": row["return_family"],
            "closure_item_id": row["closure_item_id"],
            "downstream_gate": row["downstream_gate"],
            "target_env_var": row["target_env_var"],
            "final_return_bundle_relative_path": bundle_rel,
            "expected_rows": row["expected_rows"],
            "preflight_file_exists": str(file_exists),
            "preflight_file_bytes": str(bytes_size),
            "preflight_non_empty_file": str(non_empty),
            "preflight_non_template_name": str(non_template_name),
            "preflight_template_named_supplied": str(template_named),
            "preflight_sha256": sha256(candidate) if file_exists else "",
            "preflight_pass": str(preflight_pass),
            "accepted_by_v53al": "0",
            "downstream_acceptance_required": "1",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "external_return_bundle_preflight_rows.csv", list(preflight_rows[0].keys()), preflight_rows)

family_rows = []
for family_source in family_source_rows:
    family = family_source["return_family"]
    related = [row for row in preflight_rows if row["return_family"] == family]
    family_rows.append(
        {
            "return_family": family,
            "bundle_subdir": family_source["bundle_subdir"],
            "downstream_gate": family_source["downstream_gate"],
            "expected_artifact_rows": str(len(related)),
            "preflight_pass_rows": str(sum(int(row["preflight_pass"]) for row in related)),
            "preflight_missing_rows": str(sum(1 - int(row["preflight_file_exists"]) for row in related)),
            "preflight_template_named_rows": str(sum(int(row["preflight_template_named_supplied"]) for row in related)),
            "preflight_non_empty_rows": str(sum(int(row["preflight_non_empty_file"]) for row in related)),
            "family_preflight_pass": str(int(related and all(row["preflight_pass"] == "1" for row in related))),
            "validation_command": family_source["validation_command"],
        }
    )
write_csv(run_dir / "external_return_bundle_preflight_family_rows.csv", list(family_rows[0].keys()), family_rows)

verify_script = run_dir / "VERIFY_EXTERNAL_RETURN_BUNDLE_PREFLIGHT.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"',
            'RETURN_BUNDLE_DIR="${1:-${V53AL_RETURN_BUNDLE_DIR:-}}"',
            'if [[ -z "$RETURN_BUNDLE_DIR" ]]; then',
            '  echo "usage: VERIFY_EXTERNAL_RETURN_BUNDLE_PREFLIGHT.sh /path/to/final_return_bundle" >&2',
            "  exit 2",
            "fi",
            'V53AL_RETURN_BUNDLE_DIR="$RETURN_BUNDLE_DIR" V53AL_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null',
            'python3 - "$ROOT_DIR/results/v53al_complete_source_external_return_bundle_preflight_summary.csv" <<\'PY_VERIFY\'',
            "import csv",
            "import sys",
            "with open(sys.argv[1], newline='', encoding='utf-8') as handle:",
            "    row = next(csv.DictReader(handle))",
            "if row.get('return_bundle_preflight_pass') != '1':",
            "    raise SystemExit('return bundle preflight did not pass')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

operator_readme = run_dir / "EXTERNAL_RETURN_BUNDLE_PREFLIGHT.md"
operator_readme.write_text(
    "\n".join(
        [
            "# v53al External Return Bundle Preflight",
            "",
            "Run this before downstream acceptance gates. It checks only presence, non-empty files, and template-name rejection for the 81 expected final return artifacts.",
            "",
            "```bash",
            "./results/v53al_complete_source_external_return_bundle_preflight/preflight_001/VERIFY_EXTERNAL_RETURN_BUNDLE_PREFLIGHT.sh /path/to/final_return_bundle",
            "```",
            "",
            "Passing this preflight does not mean review rows, generation rows, latency rows, or release evidence are accepted. Downstream gates remain authoritative.",
            "",
        ]
    ),
    encoding="utf-8",
)

preflight_rows_total = len(preflight_rows)
preflight_pass_rows = sum(int(row["preflight_pass"]) for row in preflight_rows)
preflight_file_exists_rows = sum(int(row["preflight_file_exists"]) for row in preflight_rows)
preflight_missing_rows = preflight_rows_total - preflight_file_exists_rows
preflight_non_empty_rows = sum(int(row["preflight_non_empty_file"]) for row in preflight_rows)
preflight_template_named_rows = sum(int(row["preflight_template_named_supplied"]) for row in preflight_rows)
accepted_by_v53al_rows = 0
return_bundle_dir_supplied = int(return_bundle_dir is not None)
return_bundle_dir_exists = int(return_bundle_dir is not None and return_bundle_dir.is_dir())
preflight_surface_ready = int(
    preflight_rows_total == int(v53ak["checklist_rows"])
    and int(v53ak["operator_checklist_ready"])
    and verify_script.is_file()
    and operator_readme.is_file()
)
return_bundle_preflight_pass = int(
    return_bundle_dir_exists
    and preflight_pass_rows == preflight_rows_total
    and preflight_template_named_rows == 0
)

requirement_rows = [
    {"requirement_id": "v53ak-checklist-input", "status": "pass", "required_value": "1", "actual_value": v53ak["v53ak_complete_source_external_return_operator_checklist_ready"], "reason": "operator checklist is ready"},
    {"requirement_id": "preflight-row-coverage", "status": "pass" if preflight_rows_total == int(v53ak["checklist_rows"]) else "blocked", "required_value": v53ak["checklist_rows"], "actual_value": str(preflight_rows_total), "reason": "one preflight row per checklist artifact"},
    {"requirement_id": "preflight-verifier", "status": "pass", "required_value": "1", "actual_value": "1", "reason": "verifier script emitted"},
    {"requirement_id": "return-bundle-directory", "status": "pass" if return_bundle_dir_exists else "blocked", "required_value": "existing return bundle directory", "actual_value": str(return_bundle_dir) if return_bundle_dir else "", "reason": "no returned bundle in default smoke"},
    {"requirement_id": "all-final-artifacts-present", "status": "pass" if preflight_file_exists_rows == preflight_rows_total else "blocked", "required_value": str(preflight_rows_total), "actual_value": str(preflight_file_exists_rows), "reason": "all final artifacts must exist"},
    {"requirement_id": "no-template-named-artifacts", "status": "pass" if preflight_template_named_rows == 0 else "blocked", "required_value": "0", "actual_value": str(preflight_template_named_rows), "reason": "template files are not accepted"},
    {"requirement_id": "non-empty-artifacts", "status": "pass" if preflight_non_empty_rows == preflight_rows_total else "blocked", "required_value": str(preflight_rows_total), "actual_value": str(preflight_non_empty_rows), "reason": "preflight requires non-empty final files"},
    {"requirement_id": "v53al-does-not-accept-evidence", "status": "pass", "required_value": "0", "actual_value": str(accepted_by_v53al_rows), "reason": "preflight does not accept evidence"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": "7000", "actual_value": v53ak["answer_review_accepted_rows"], "reason": "review acceptance remains downstream"},
    {"requirement_id": "generation-execution-admitted", "status": "blocked", "required_value": "1000", "actual_value": v53ak["generation_execution_admitted_rows"], "reason": "generation execution remains downstream"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v53ak["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "external_return_bundle_preflight_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "preflight-surface", "status": "ready" if preflight_surface_ready else "blocked", "reason": f"preflight_rows={preflight_rows_total}/{v53ak['checklist_rows']}"},
    {"gap": "return-bundle-directory", "status": "ready" if return_bundle_dir_exists else "blocked", "reason": f"return_bundle_dir_exists={return_bundle_dir_exists}"},
    {"gap": "all-final-artifacts-present", "status": "ready" if preflight_file_exists_rows == preflight_rows_total else "blocked", "reason": f"preflight_file_exists_rows={preflight_file_exists_rows}/{preflight_rows_total}"},
    {"gap": "return-bundle-preflight-pass", "status": "ready" if return_bundle_preflight_pass else "blocked", "reason": f"preflight_pass_rows={preflight_pass_rows}/{preflight_rows_total}"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ak['answer_review_accepted_rows']}/7000"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53ak['generation_execution_admitted_rows']}/1000"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ak['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53al_complete_source_external_return_bundle_preflight_metrics",
    "v53ak_complete_source_external_return_operator_checklist_ready": v53ak["v53ak_complete_source_external_return_operator_checklist_ready"],
    "return_bundle_dir_supplied": str(return_bundle_dir_supplied),
    "return_bundle_dir_exists": str(return_bundle_dir_exists),
    "preflight_surface_ready": str(preflight_surface_ready),
    "return_bundle_preflight_pass": str(return_bundle_preflight_pass),
    "preflight_rows": str(preflight_rows_total),
    "preflight_pass_rows": str(preflight_pass_rows),
    "preflight_file_exists_rows": str(preflight_file_exists_rows),
    "preflight_missing_rows": str(preflight_missing_rows),
    "preflight_non_empty_rows": str(preflight_non_empty_rows),
    "preflight_template_named_rows": str(preflight_template_named_rows),
    "accepted_by_v53al_rows": str(accepted_by_v53al_rows),
    "family_preflight_rows": str(len(family_rows)),
    "verifier_script_ready": "1",
    "operator_checklist_ready": v53ak["operator_checklist_ready"],
    "checklist_rows": v53ak["checklist_rows"],
    "supplied_checklist_rows": v53ak["supplied_checklist_rows"],
    "missing_checklist_rows": v53ak["missing_checklist_rows"],
    "accepted_by_v53ak_rows": v53ak["accepted_by_v53ak_rows"],
    "send_bundle_ready": v53ak["send_bundle_ready"],
    "return_bundle_mapping_ready": v53ak["return_bundle_mapping_ready"],
    "ready_closure_item_rows": v53ak["ready_closure_item_rows"],
    "blocked_closure_item_rows": v53ak["blocked_closure_item_rows"],
    "answer_review_accepted_rows": v53ak["answer_review_accepted_rows"],
    "generation_execution_admitted_rows": v53ak["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53ak["accepted_generation_result_artifacts"],
    "actual_model_generation_ready": v53ak["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53ak["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ak["runtime_admission_accepted_rows"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53al": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "external_return_bundle_preflight_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53al_complete_source_external_return_bundle_preflight_ready": str(preflight_surface_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53ak-checklist-input", "status": "pass", "reason": "v53ak checklist is ready"},
    {"gate": "preflight-surface", "status": "pass" if preflight_surface_ready else "blocked", "reason": f"preflight_rows={preflight_rows_total}/{v53ak['checklist_rows']}"},
    {"gate": "preflight-verifier", "status": "pass", "reason": "verifier script emitted"},
    {"gate": "no-template-named-artifacts", "status": "pass" if preflight_template_named_rows == 0 else "blocked", "reason": f"preflight_template_named_rows={preflight_template_named_rows}"},
    {"gate": "v53al-does-not-accept-evidence", "status": "pass", "reason": "accepted_by_v53al_rows=0"},
    {"gate": "return-bundle-directory", "status": "pass" if return_bundle_dir_exists else "blocked", "reason": f"return_bundle_dir_exists={return_bundle_dir_exists}"},
    {"gate": "all-final-artifacts-present", "status": "pass" if preflight_file_exists_rows == preflight_rows_total else "blocked", "reason": f"preflight_file_exists_rows={preflight_file_exists_rows}/{preflight_rows_total}"},
    {"gate": "return-bundle-preflight-pass", "status": "pass" if return_bundle_preflight_pass else "blocked", "reason": f"preflight_pass_rows={preflight_pass_rows}/{preflight_rows_total}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ak['answer_review_accepted_rows']}/7000"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53ak['generation_execution_admitted_rows']}/1000"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ak['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "preflight is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53al Complete-Source External Return Bundle Preflight Boundary

This artifact is a receiver-side preflight over the v53ak operator checklist.
It checks final artifact presence, non-empty files, and template-name rejection.
It does not accept evidence, does not execute generation, and does not create
review, latency, near-frontier, or release claims.

Evidence emitted:

- preflight_surface_ready={preflight_surface_ready}
- return_bundle_preflight_pass={return_bundle_preflight_pass}
- preflight_rows={preflight_rows_total}
- preflight_pass_rows={preflight_pass_rows}
- preflight_file_exists_rows={preflight_file_exists_rows}
- preflight_missing_rows={preflight_missing_rows}
- preflight_non_empty_rows={preflight_non_empty_rows}
- preflight_template_named_rows={preflight_template_named_rows}
- accepted_by_v53al_rows=0
- verifier_script_ready=1
- operator_checklist_ready={v53ak['operator_checklist_ready']}
- checklist_rows={v53ak['checklist_rows']}
- send_bundle_ready={v53ak['send_bundle_ready']}
- return_bundle_mapping_ready={v53ak['return_bundle_mapping_ready']}
- answer_review_accepted_rows={v53ak['answer_review_accepted_rows']}
- generation_execution_admitted_rows={v53ak['generation_execution_admitted_rows']}
- actual_model_generation_ready={v53ak['actual_model_generation_ready']}
- full_shard_prerequisites_closed={v53ak['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53ak['runtime_admission_accepted_rows']}
- checkpoint_payload_bytes_downloaded_by_v53al=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: external return bundle preflight surface is ready.
Blocked wording: returned evidence accepted, generation execution admitted,
actual generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V53AL_COMPLETE_SOURCE_EXTERNAL_RETURN_BUNDLE_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53al-complete-source-external-return-bundle-preflight",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53al_complete_source_external_return_bundle_preflight_ready": preflight_surface_ready,
    "return_bundle_preflight_pass": return_bundle_preflight_pass,
    "preflight_rows": preflight_rows_total,
    "preflight_pass_rows": preflight_pass_rows,
    "preflight_file_exists_rows": preflight_file_exists_rows,
    "preflight_missing_rows": preflight_missing_rows,
    "accepted_by_v53al_rows": accepted_by_v53al_rows,
    "answer_review_accepted_rows": int(v53ak["answer_review_accepted_rows"]),
    "generation_execution_admitted_rows": int(v53ak["generation_execution_admitted_rows"]),
    "actual_model_generation_ready": int(v53ak["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53ak["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53ak["runtime_admission_accepted_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v53al": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53al_complete_source_external_return_bundle_preflight_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53al_complete_source_external_return_bundle_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
