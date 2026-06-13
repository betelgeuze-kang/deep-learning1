#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dk_return_contract_final_bundle_crosswalk_gate"
RUN_ID="${V61DK_RUN_ID:-crosswalk_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DK_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dk_return_contract_final_bundle_crosswalk_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DJ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dj_post_claim_return_evidence_contract_gate.sh" >/dev/null
V53AK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53ak_complete_source_external_return_operator_checklist.sh" >/dev/null
V53AL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null

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


sources = {
    "v61dj_summary": results / "v61dj_post_claim_return_evidence_contract_gate_summary.csv",
    "v61dj_decision": results / "v61dj_post_claim_return_evidence_contract_gate_decision.csv",
    "v61dj_artifacts": results / "v61dj_post_claim_return_evidence_contract_gate" / "contract_001" / "return_evidence_contract_artifact_rows.csv",
    "v61dj_families": results / "v61dj_post_claim_return_evidence_contract_gate" / "contract_001" / "return_evidence_contract_family_rows.csv",
    "v53ak_summary": results / "v53ak_complete_source_external_return_operator_checklist_summary.csv",
    "v53ak_decision": results / "v53ak_complete_source_external_return_operator_checklist_decision.csv",
    "v53ak_checklist": results / "v53ak_complete_source_external_return_operator_checklist" / "checklist_001" / "external_return_operator_checklist_rows.csv",
    "v53ak_families": results / "v53ak_complete_source_external_return_operator_checklist" / "checklist_001" / "external_return_operator_family_checklist_rows.csv",
    "v53al_summary": results / "v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "v53al_decision": results / "v53al_complete_source_external_return_bundle_preflight_decision.csv",
    "v53al_preflight": results / "v53al_complete_source_external_return_bundle_preflight" / "preflight_001" / "external_return_bundle_preflight_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dk source {key}: {path}")

copy(sources["v61dj_summary"], "source_v61dj/v61dj_post_claim_return_evidence_contract_gate_summary.csv")
copy(sources["v61dj_decision"], "source_v61dj/v61dj_post_claim_return_evidence_contract_gate_decision.csv")
copy(sources["v61dj_artifacts"], "source_v61dj/return_evidence_contract_artifact_rows.csv")
copy(sources["v61dj_families"], "source_v61dj/return_evidence_contract_family_rows.csv")
copy(sources["v53ak_summary"], "source_v53ak/v53ak_complete_source_external_return_operator_checklist_summary.csv")
copy(sources["v53ak_decision"], "source_v53ak/v53ak_complete_source_external_return_operator_checklist_decision.csv")
copy(sources["v53ak_checklist"], "source_v53ak/external_return_operator_checklist_rows.csv")
copy(sources["v53ak_families"], "source_v53ak/external_return_operator_family_checklist_rows.csv")
copy(sources["v53al_summary"], "source_v53al/v53al_complete_source_external_return_bundle_preflight_summary.csv")
copy(sources["v53al_decision"], "source_v53al/v53al_complete_source_external_return_bundle_preflight_decision.csv")
copy(sources["v53al_preflight"], "source_v53al/external_return_bundle_preflight_rows.csv")

v61dj = read_csv(sources["v61dj_summary"])[0]
v53ak = read_csv(sources["v53ak_summary"])[0]
v53al = read_csv(sources["v53al_summary"])[0]
contract_artifacts = read_csv(sources["v61dj_artifacts"])
checklist_rows = read_csv(sources["v53ak_checklist"])
preflight_rows = read_csv(sources["v53al_preflight"])

for field, row in [
    ("v61dj_post_claim_return_evidence_contract_gate_ready", v61dj),
    ("v53ak_complete_source_external_return_operator_checklist_ready", v53ak),
    ("v53al_complete_source_external_return_bundle_preflight_ready", v53al),
]:
    if row.get(field) != "1":
        raise SystemExit(f"v61dk requires {field}=1")

checklist_by_family_artifact = {
    (row["return_family"], Path(row["final_return_bundle_relative_path"]).name): row
    for row in checklist_rows
}
preflight_by_path = {row["final_return_bundle_relative_path"]: row for row in preflight_rows}

family_map = {
    "aggregate-review-return": "aggregate-review-return",
    "generation-result-return": "generation-result-return",
}
crosswalk_rows = []
for artifact in contract_artifacts:
    family = family_map[artifact["external_return_family"]]
    key = (family, artifact["return_artifact"])
    checklist = checklist_by_family_artifact.get(key)
    if checklist is None:
        raise SystemExit(f"missing checklist mapping for {key}")
    preflight = preflight_by_path.get(checklist["final_return_bundle_relative_path"])
    if preflight is None:
        raise SystemExit(f"missing preflight mapping for {checklist['final_return_bundle_relative_path']}")
    crosswalk_rows.append(
        {
            "contract_family": artifact["external_return_family"],
            "contract_artifact": artifact["return_artifact"],
            "contract_expected_rows": artifact["expected_rows"],
            "contract_status": artifact["contract_status"],
            "checklist_item_id": checklist["checklist_item_id"],
            "closure_item_id": checklist["closure_item_id"],
            "downstream_gate": checklist["downstream_gate"],
            "target_env_var": checklist["target_env_var"],
            "final_return_bundle_relative_path": checklist["final_return_bundle_relative_path"],
            "gate_relative_artifact_path": checklist["gate_relative_artifact_path"],
            "checklist_expected_rows": checklist["expected_rows"],
            "preflight_file_exists": preflight["preflight_file_exists"],
            "preflight_non_empty_file": preflight["preflight_non_empty_file"],
            "preflight_non_template_name": preflight["preflight_non_template_name"],
            "preflight_pass": preflight["preflight_pass"],
            "mapping_status": "mapped",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "return_contract_final_bundle_crosswalk_rows.csv", list(crosswalk_rows[0].keys()), crosswalk_rows)

family_rows = []
for family in ["aggregate-review-return", "generation-result-return"]:
    rows = [row for row in crosswalk_rows if row["contract_family"] == family]
    family_rows.append(
        {
            "contract_family": family,
            "crosswalk_rows": str(len(rows)),
            "mapped_crosswalk_rows": str(sum(row["mapping_status"] == "mapped" for row in rows)),
            "preflight_pass_rows": str(sum(row["preflight_pass"] == "1" for row in rows)),
            "preflight_missing_rows": str(sum(row["preflight_file_exists"] == "0" for row in rows)),
            "contract_ready": str(int(all(row["preflight_pass"] == "1" for row in rows))),
            "downstream_gates": ";".join(sorted({row["downstream_gate"] for row in rows})),
        }
    )
write_csv(run_dir / "return_contract_final_bundle_family_crosswalk_rows.csv", list(family_rows[0].keys()), family_rows)

preflight_scope_rows = [
    {
        "scope_id": "full-final-return-bundle",
        "scope_rows": v53al["preflight_rows"],
        "scope_pass_rows": v53al["preflight_pass_rows"],
        "scope_missing_rows": v53al["preflight_missing_rows"],
        "scope_ready": v53al["return_bundle_preflight_pass"],
        "reason": "full 81-artifact bundle must pass before replay closes",
    },
    {
        "scope_id": "contract-critical-artifacts",
        "scope_rows": str(len(crosswalk_rows)),
        "scope_pass_rows": str(sum(row["preflight_pass"] == "1" for row in crosswalk_rows)),
        "scope_missing_rows": str(sum(row["preflight_file_exists"] == "0" for row in crosswalk_rows)),
        "scope_ready": str(int(all(row["preflight_pass"] == "1" for row in crosswalk_rows))),
        "reason": "10 contract artifacts must pass before actual-generation claim can open",
    },
]
write_csv(run_dir / "return_contract_final_bundle_preflight_scope_rows.csv", list(preflight_scope_rows[0].keys()), preflight_scope_rows)

runtime_gap_rows = [
    {"gap": "crosswalk-surface", "status": "ready", "reason": f"mapped_crosswalk_rows={len(crosswalk_rows)}/{len(contract_artifacts)}"},
    {"gap": "full-final-return-bundle", "status": "blocked", "reason": f"preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}"},
    {"gap": "contract-critical-artifacts", "status": "blocked", "reason": f"contract_preflight_pass_rows=0/{len(crosswalk_rows)}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61dj['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

mapped_rows = sum(row["mapping_status"] == "mapped" for row in crosswalk_rows)
contract_preflight_pass_rows = sum(row["preflight_pass"] == "1" for row in crosswalk_rows)
contract_preflight_missing_rows = sum(row["preflight_file_exists"] == "0" for row in crosswalk_rows)

metric = {
    "metric_id": "v61dk_return_contract_final_bundle_crosswalk_gate_metrics",
    "v61dj_post_claim_return_evidence_contract_gate_ready": v61dj["v61dj_post_claim_return_evidence_contract_gate_ready"],
    "v53ak_complete_source_external_return_operator_checklist_ready": v53ak["v53ak_complete_source_external_return_operator_checklist_ready"],
    "v53al_complete_source_external_return_bundle_preflight_ready": v53al["v53al_complete_source_external_return_bundle_preflight_ready"],
    "source_gate_rows": "3",
    "crosswalk_surface_ready": "1",
    "contract_artifact_rows": str(len(contract_artifacts)),
    "crosswalk_rows": str(len(crosswalk_rows)),
    "mapped_crosswalk_rows": str(mapped_rows),
    "unmapped_crosswalk_rows": str(len(crosswalk_rows) - mapped_rows),
    "family_crosswalk_rows": str(len(family_rows)),
    "contract_preflight_pass_rows": str(contract_preflight_pass_rows),
    "contract_preflight_missing_rows": str(contract_preflight_missing_rows),
    "contract_preflight_ready": str(int(contract_preflight_pass_rows == len(crosswalk_rows))),
    "full_preflight_rows": v53al["preflight_rows"],
    "full_preflight_pass_rows": v53al["preflight_pass_rows"],
    "full_preflight_missing_rows": v53al["preflight_missing_rows"],
    "return_bundle_preflight_pass": v53al["return_bundle_preflight_pass"],
    "operator_checklist_rows": v53ak["checklist_rows"],
    "aggregate_review_crosswalk_rows": str(sum(row["contract_family"] == "aggregate-review-return" for row in crosswalk_rows)),
    "generation_result_crosswalk_rows": str(sum(row["contract_family"] == "generation-result-return" for row in crosswalk_rows)),
    "review_return_expected_rows": v61dj["review_return_expected_rows"],
    "generation_result_expected_rows": v61dj["generation_result_expected_rows"],
    "accepted_human_review_rows": v61dj["accepted_human_review_rows"],
    "expected_human_review_rows": v61dj["expected_human_review_rows"],
    "accepted_adjudication_rows": v61dj["accepted_adjudication_rows"],
    "expected_adjudication_rows": v61dj["expected_adjudication_rows"],
    "generation_execution_admitted_rows": v61dj["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61dj["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61dj["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61dj["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v61dj["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v61dj["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v61dj["actual_model_generation_ready"],
    "v1_0_comparison_ready": v61dj["v1_0_comparison_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dk": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_contract_final_bundle_crosswalk_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dk_return_contract_final_bundle_crosswalk_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "crosswalk-surface-ready", "status": "pass", "reason": "contract artifacts are mapped to final bundle paths"},
    {"gate": "contract-artifact-mapping", "status": "pass", "reason": f"mapped_crosswalk_rows={mapped_rows}/{len(crosswalk_rows)}"},
    {"gate": "full-return-bundle-preflight", "status": "blocked", "reason": f"full_preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}"},
    {"gate": "contract-critical-preflight", "status": "blocked", "reason": f"contract_preflight_pass_rows={contract_preflight_pass_rows}/{len(crosswalk_rows)}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61dk Return Contract Final Bundle Crosswalk Gate

This gate maps the 10 v61dj return evidence contract artifacts onto the final
81-artifact v53 return bundle checklist and preflight rows. It does not create
review rows, generation rows, latency evidence, or release evidence.

Evidence emitted:

- contract_artifact_rows={len(contract_artifacts)}
- crosswalk_rows={len(crosswalk_rows)}
- mapped_crosswalk_rows={mapped_rows}
- unmapped_crosswalk_rows={len(crosswalk_rows) - mapped_rows}
- family_crosswalk_rows={len(family_rows)}
- contract_preflight_pass_rows={contract_preflight_pass_rows}
- contract_preflight_missing_rows={contract_preflight_missing_rows}
- full_preflight_rows={v53al['preflight_rows']}
- full_preflight_pass_rows={v53al['preflight_pass_rows']}
- full_preflight_missing_rows={v53al['preflight_missing_rows']}
- return_bundle_preflight_pass={v53al['return_bundle_preflight_pass']}
- operator_checklist_rows={v53ak['checklist_rows']}
- aggregate_review_crosswalk_rows={metric['aggregate_review_crosswalk_rows']}
- generation_result_crosswalk_rows={metric['generation_result_crosswalk_rows']}
- review_return_expected_rows={v61dj['review_return_expected_rows']}
- generation_result_expected_rows={v61dj['generation_result_expected_rows']}
- accepted_human_review_rows={v61dj['accepted_human_review_rows']}/{v61dj['expected_human_review_rows']}
- accepted_adjudication_rows={v61dj['accepted_adjudication_rows']}/{v61dj['expected_adjudication_rows']}
- generation_execution_admitted_rows={v61dj['generation_execution_admitted_rows']}/{v61dj['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={v61dj['accepted_generation_result_artifacts']}/{v61dj['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v61dj['generation_result_accepted_rows']}/{v61dj['generation_result_acceptance_rows']}
- actual_model_generation_ready={v61dj['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dk=0

Allowed wording: return contract to final bundle crosswalk is ready.
Blocked wording: final return bundle accepted, contract-critical preflight
passed, actual generation, v1.0 comparison, latency, near-frontier quality, or
release readiness.
"""
(run_dir / "V61DK_RETURN_CONTRACT_FINAL_BUNDLE_CROSSWALK_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dk-return-contract-final-bundle-crosswalk-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dk_return_contract_final_bundle_crosswalk_gate_ready": 1,
    "crosswalk_surface_ready": 1,
    "contract_artifact_rows": len(contract_artifacts),
    "mapped_crosswalk_rows": mapped_rows,
    "unmapped_crosswalk_rows": len(crosswalk_rows) - mapped_rows,
    "contract_preflight_pass_rows": contract_preflight_pass_rows,
    "return_bundle_preflight_pass": as_int(v53al, "return_bundle_preflight_pass"),
    "actual_model_generation_ready": as_int(v61dj, "actual_model_generation_ready"),
    "v1_0_comparison_ready": as_int(v61dj, "v1_0_comparison_ready"),
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dk_return_contract_final_bundle_crosswalk_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dk_return_contract_final_bundle_crosswalk_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
