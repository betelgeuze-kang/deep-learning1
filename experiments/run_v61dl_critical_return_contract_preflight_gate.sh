#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dl_critical_return_contract_preflight_gate"
RUN_ID="${V61DL_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V61DL_RETURN_BUNDLE_DIR:-}"

if [[ "${V61DL_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dl_critical_return_contract_preflight_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DK_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dk_return_contract_final_bundle_crosswalk_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" <<'PY'
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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


sources = {
    "v61dk_summary": results / "v61dk_return_contract_final_bundle_crosswalk_gate_summary.csv",
    "v61dk_decision": results / "v61dk_return_contract_final_bundle_crosswalk_gate_decision.csv",
    "v61dk_crosswalk": results / "v61dk_return_contract_final_bundle_crosswalk_gate" / "crosswalk_001" / "return_contract_final_bundle_crosswalk_rows.csv",
    "v61dk_scope": results / "v61dk_return_contract_final_bundle_crosswalk_gate" / "crosswalk_001" / "return_contract_final_bundle_preflight_scope_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dl source {key}: {path}")

copy(sources["v61dk_summary"], "source_v61dk/v61dk_return_contract_final_bundle_crosswalk_gate_summary.csv")
copy(sources["v61dk_decision"], "source_v61dk/v61dk_return_contract_final_bundle_crosswalk_gate_decision.csv")
copy(sources["v61dk_crosswalk"], "source_v61dk/return_contract_final_bundle_crosswalk_rows.csv")
copy(sources["v61dk_scope"], "source_v61dk/return_contract_final_bundle_preflight_scope_rows.csv")

v61dk = read_csv(sources["v61dk_summary"])[0]
crosswalk = read_csv(sources["v61dk_crosswalk"])
if v61dk.get("v61dk_return_contract_final_bundle_crosswalk_gate_ready") != "1":
    raise SystemExit("v61dl requires v61dk ready")

bundle_supplied = int(return_bundle_dir is not None)
bundle_exists = int(return_bundle_dir is not None and return_bundle_dir.is_dir())
preflight_rows = []
for row in crosswalk:
    rel_path = row["final_return_bundle_relative_path"]
    candidate = return_bundle_dir / rel_path if return_bundle_dir else None
    file_exists = int(candidate is not None and candidate.is_file())
    file_bytes = candidate.stat().st_size if file_exists else 0
    non_empty = int(file_bytes > 0)
    non_template_name = int(not rel_path.endswith(".template") and ".template." not in rel_path)
    pass_row = int(file_exists and non_empty and non_template_name)
    preflight_rows.append(
        {
            "contract_family": row["contract_family"],
            "contract_artifact": row["contract_artifact"],
            "final_return_bundle_relative_path": rel_path,
            "expected_rows": row["contract_expected_rows"],
            "target_env_var": row["target_env_var"],
            "downstream_gate": row["downstream_gate"],
            "return_bundle_dir_supplied": str(bundle_supplied),
            "return_bundle_dir_exists": str(bundle_exists),
            "file_exists": str(file_exists),
            "file_bytes": str(file_bytes),
            "non_empty_file": str(non_empty),
            "non_template_name": str(non_template_name),
            "critical_preflight_pass": str(pass_row),
            "sha256": sha256(candidate) if file_exists else "",
            "blocking_reason": "ready" if pass_row else "critical return artifact missing or empty",
        }
    )
write_csv(run_dir / "critical_return_contract_preflight_rows.csv", list(preflight_rows[0].keys()), preflight_rows)

family_rows = []
for family in ["aggregate-review-return", "generation-result-return"]:
    rows = [row for row in preflight_rows if row["contract_family"] == family]
    family_rows.append(
        {
            "contract_family": family,
            "critical_artifact_rows": str(len(rows)),
            "critical_preflight_pass_rows": str(sum(row["critical_preflight_pass"] == "1" for row in rows)),
            "critical_preflight_missing_rows": str(sum(row["file_exists"] == "0" for row in rows)),
            "critical_preflight_ready": str(int(all(row["critical_preflight_pass"] == "1" for row in rows))),
        }
    )
write_csv(run_dir / "critical_return_contract_preflight_family_rows.csv", list(family_rows[0].keys()), family_rows)

verifier = run_dir / "VERIFY_CRITICAL_RETURN_CONTRACT.sh"
verifier.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/final_return_bundle" >&2
  exit 2
fi

ROOT="$1"
required=(
  "aggregate_review_return/human_review_rows.csv"
  "aggregate_review_return/adjudication_rows.csv"
  "aggregate_review_return/reviewer_identity_rows.csv"
  "aggregate_review_return/reviewer_conflict_rows.csv"
  "aggregate_review_return/acceptance_summary.json"
  "generation_result_return/real_model_generation_answer_rows.csv"
  "generation_result_return/real_model_generation_citation_rows.csv"
  "generation_result_return/real_model_generation_abstain_fallback_rows.csv"
  "generation_result_return/real_model_generation_latency_rows.csv"
  "generation_result_return/real_model_generation_acceptance_summary.json"
)

for rel in "${required[@]}"; do
  path="$ROOT/$rel"
  if [[ ! -s "$path" ]]; then
    echo "missing or empty critical return artifact: $rel" >&2
    exit 1
  fi
  case "$rel" in
    *.template|*.template.*)
      echo "template-named critical return artifact is not allowed: $rel" >&2
      exit 1
      ;;
  esac
done

echo "critical return contract preflight passed"
""",
    encoding="utf-8",
)
verifier.chmod(0o755)

command_rows = [
    {
        "command_id": "verify-critical-return-contract",
        "ready_to_run_now": "1",
        "command": "results/v61dl_critical_return_contract_preflight_gate/preflight_001/VERIFY_CRITICAL_RETURN_CONTRACT.sh /path/to/final_return_bundle",
        "expected_transition": "critical_preflight_pass_rows=10",
    },
    {
        "command_id": "run-critical-preflight-gate",
        "ready_to_run_now": "1",
        "command": "V61DL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DL_REUSE_EXISTING=0 ./experiments/run_v61dl_critical_return_contract_preflight_gate.sh",
        "expected_transition": "critical_return_contract_preflight_ready=1 when all 10 critical artifacts pass",
    },
    {
        "command_id": "run-full-return-preflight",
        "ready_to_run_now": "0",
        "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh",
        "expected_transition": "return_bundle_preflight_pass=1 only when all 81 artifacts pass",
    },
]
write_csv(run_dir / "critical_return_contract_preflight_command_rows.csv", list(command_rows[0].keys()), command_rows)

pass_rows = sum(row["critical_preflight_pass"] == "1" for row in preflight_rows)
missing_rows = sum(row["file_exists"] == "0" for row in preflight_rows)
critical_ready = int(pass_rows == len(preflight_rows))
runtime_gap_rows = [
    {"gap": "critical-preflight-surface", "status": "ready", "reason": f"critical_artifact_rows={len(preflight_rows)}"},
    {"gap": "critical-return-contract-preflight", "status": "ready" if critical_ready else "blocked", "reason": f"critical_preflight_pass_rows={pass_rows}/{len(preflight_rows)}"},
    {"gap": "full-return-bundle-preflight", "status": "blocked", "reason": f"return_bundle_preflight_pass={v61dk['return_bundle_preflight_pass']}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61dk['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v61dl_critical_return_contract_preflight_gate_metrics",
    "v61dk_return_contract_final_bundle_crosswalk_gate_ready": v61dk["v61dk_return_contract_final_bundle_crosswalk_gate_ready"],
    "source_gate_rows": "1",
    "critical_preflight_surface_ready": "1",
    "return_bundle_dir_supplied": str(bundle_supplied),
    "return_bundle_dir_exists": str(bundle_exists),
    "critical_artifact_rows": str(len(preflight_rows)),
    "critical_preflight_pass_rows": str(pass_rows),
    "critical_preflight_missing_rows": str(missing_rows),
    "critical_preflight_non_empty_rows": str(sum(row["non_empty_file"] == "1" for row in preflight_rows)),
    "critical_preflight_ready": str(critical_ready),
    "critical_family_rows": str(len(family_rows)),
    "critical_command_rows": str(len(command_rows)),
    "ready_critical_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "full_preflight_rows": v61dk["full_preflight_rows"],
    "full_preflight_pass_rows": v61dk["full_preflight_pass_rows"],
    "return_bundle_preflight_pass": v61dk["return_bundle_preflight_pass"],
    "operator_checklist_rows": v61dk["operator_checklist_rows"],
    "review_return_expected_rows": v61dk["review_return_expected_rows"],
    "generation_result_expected_rows": v61dk["generation_result_expected_rows"],
    "accepted_human_review_rows": v61dk["accepted_human_review_rows"],
    "expected_human_review_rows": v61dk["expected_human_review_rows"],
    "accepted_adjudication_rows": v61dk["accepted_adjudication_rows"],
    "expected_adjudication_rows": v61dk["expected_adjudication_rows"],
    "generation_execution_admitted_rows": v61dk["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61dk["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61dk["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61dk["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v61dk["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v61dk["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v61dk["actual_model_generation_ready"],
    "v1_0_comparison_ready": v61dk["v1_0_comparison_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dl": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "critical_return_contract_preflight_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dl_critical_return_contract_preflight_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "critical-preflight-surface-ready", "status": "pass", "reason": "critical preflight rows and verifier emitted"},
    {"gate": "critical-return-contract-preflight", "status": "pass" if critical_ready else "blocked", "reason": f"critical_preflight_pass_rows={pass_rows}/{len(preflight_rows)}"},
    {"gate": "full-return-bundle-preflight", "status": "blocked", "reason": f"return_bundle_preflight_pass={v61dk['return_bundle_preflight_pass']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61dl Critical Return Contract Preflight Gate

This gate emits and optionally runs a verifier for the 10 critical return
artifacts mapped by v61dk. It does not create review rows, generation rows,
latency evidence, or release evidence.

Evidence emitted:

- critical_artifact_rows={len(preflight_rows)}
- critical_preflight_pass_rows={pass_rows}
- critical_preflight_missing_rows={missing_rows}
- critical_preflight_ready={critical_ready}
- return_bundle_dir_supplied={bundle_supplied}
- return_bundle_dir_exists={bundle_exists}
- critical_command_rows={len(command_rows)}
- ready_critical_command_rows={metric['ready_critical_command_rows']}
- full_preflight_rows={v61dk['full_preflight_rows']}
- full_preflight_pass_rows={v61dk['full_preflight_pass_rows']}
- return_bundle_preflight_pass={v61dk['return_bundle_preflight_pass']}
- review_return_expected_rows={v61dk['review_return_expected_rows']}
- generation_result_expected_rows={v61dk['generation_result_expected_rows']}
- accepted_human_review_rows={v61dk['accepted_human_review_rows']}/{v61dk['expected_human_review_rows']}
- accepted_adjudication_rows={v61dk['accepted_adjudication_rows']}/{v61dk['expected_adjudication_rows']}
- generation_execution_admitted_rows={v61dk['generation_execution_admitted_rows']}/{v61dk['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={v61dk['accepted_generation_result_artifacts']}/{v61dk['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v61dk['generation_result_accepted_rows']}/{v61dk['generation_result_acceptance_rows']}
- actual_model_generation_ready={v61dk['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dl=0

Allowed wording: critical return contract preflight surface is ready.
Blocked wording: critical return artifacts accepted, full final return bundle
accepted, actual generation, v1.0 comparison, latency, near-frontier quality,
or release readiness.
"""
(run_dir / "V61DL_CRITICAL_RETURN_CONTRACT_PREFLIGHT_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dl-critical-return-contract-preflight-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dl_critical_return_contract_preflight_gate_ready": 1,
    "critical_preflight_surface_ready": 1,
    "return_bundle_dir_supplied": bundle_supplied,
    "return_bundle_dir_exists": bundle_exists,
    "critical_artifact_rows": len(preflight_rows),
    "critical_preflight_pass_rows": pass_rows,
    "critical_preflight_ready": critical_ready,
    "actual_model_generation_ready": as_int(v61dk, "actual_model_generation_ready"),
    "v1_0_comparison_ready": as_int(v61dk, "v1_0_comparison_ready"),
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dl_critical_return_contract_preflight_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dl_critical_return_contract_preflight_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
