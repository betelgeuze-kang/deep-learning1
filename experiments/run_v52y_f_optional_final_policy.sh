#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52y_f_optional_final_policy"
RUN_ID="${V52Y_RUN_ID:-policy_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V52Y_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52y_f_optional_final_policy_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52r_measured_registry_de_absorb_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52r_measured_registry_de_absorb.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v52e_100b_plus_hosted_llm_rag_optional_intake.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v52r_dir = results / "v52r_measured_registry_de_absorb" / "registry_001"
v52e_dir = results / "v52e_100b_plus_hosted_llm_rag_optional_intake" / "intake_001"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v52r_summary = read_csv(results / "v52r_measured_registry_de_absorb_summary.csv")[0]
v52e_summary = read_csv(results / "v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv")[0]
if v52r_summary.get("v52r_dependency_blocker_ready") == "1":
    for src, rel in [
        (results / "v52r_measured_registry_de_absorb_summary.csv", "source_v52r/v52r_measured_registry_de_absorb_summary.csv"),
        (results / "v52r_measured_registry_de_absorb_decision.csv", "source_v52r/v52r_measured_registry_de_absorb_decision.csv"),
        (v52r_dir / "v52r_dependency_blocker_rows.csv", "source_v52r/v52r_dependency_blocker_rows.csv"),
        (v52r_dir / "V52R_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md", "source_v52r/V52R_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md"),
    ]:
        if src.is_file():
            copy(src, rel)
    blocker_rows = [
        {
            "blocker_id": "v52y-v52r-dependency-blocker",
            "source_blocker": "v52r_dependency_blocker_ready",
            "required_for": "v52y-f-optional-final-policy",
            "fixture_allowed": "0",
            "status": "blocked",
        }
    ]
    write_csv(run_dir / "v52y_dependency_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)
    summary = {
        "v52y_f_optional_final_policy_ready": "0",
        "v52y_dependency_blocker_ready": "1",
        "f_optional_final_disposition_ready": "0",
        "required_30b_baseline_ready": "0",
        "required_70b_baseline_ready": "0",
        "required_measured_system_rows": "0",
        "v52_ready_condition_rows": "0",
        "v52_ready_condition_pass_rows": "0",
        "v52_ready": "0",
        "comparison_30b_150b_wording_status": "blocked",
        "complete_source_v53_ready": "0",
        "v1_0_comparison_ready": "0",
        "real_release_package_ready": "0",
    }
    write_csv(summary_csv, list(summary.keys()), [summary])
    decision_rows = [
        ("dependency-blocker-artifact", "pass", "v52y records the upstream v52r dependency blocker"),
        ("required-d-e-measured", "blocked", "v52r dependency blocker prevents D/E readiness"),
        ("v52-ready", "blocked", "v52y cannot close while v52r is blocked"),
        ("30b-150b-wording", "blocked", "comparison wording requires D/E PM/release readiness"),
        ("real-release-package", "blocked", "dependency blocker is not a release package"),
    ]
    write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])
    boundary = run_dir / "V52Y_F_OPTIONAL_FINAL_POLICY_DEPENDENCY_BLOCKER.md"
    boundary.write_text(
        "# v52y F Optional Final Policy Dependency Blocker\n\n"
        "v52y cannot resolve the optional F policy because v52r did not replay a measured registry. "
        "This is a fail-closed blocker and does not permit 30B-150B comparison wording.\n\n"
        "- v52y_dependency_blocker_ready=1\n"
        "- required_30b_baseline_ready=0\n"
        "- required_70b_baseline_ready=0\n"
        "- v52_ready=0\n",
        encoding="utf-8",
    )
    manifest = {
        "manifest_scope": "v52y-f-optional-final-policy-dependency-blocker",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "v52y_f_optional_final_policy_ready": 0,
        "v52y_dependency_blocker_ready": 1,
        "real_release_package_ready": 0,
        "source_v52r_summary_sha256": sha256(results / "v52r_measured_registry_de_absorb_summary.csv"),
    }
    manifest_file = run_dir / "v52y_f_optional_final_policy_manifest.json"
    manifest_file.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    artifact_rels = [
        "v52y_dependency_blocker_rows.csv",
        "V52Y_F_OPTIONAL_FINAL_POLICY_DEPENDENCY_BLOCKER.md",
        "v52y_f_optional_final_policy_manifest.json",
        "source_v52r/v52r_measured_registry_de_absorb_summary.csv",
        "source_v52r/v52r_measured_registry_de_absorb_decision.csv",
    ]
    sha_rows = [{"path": rel, "sha256": sha256(run_dir / rel), "bytes": (run_dir / rel).stat().st_size} for rel in artifact_rels if (run_dir / rel).is_file()]
    write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
    print(f"v52y_f_optional_final_policy_dir: {run_dir}")
    print(f"summary: {summary_csv}")
    print(f"decision: {decision_csv}")
    sys.exit(0)
registry_rows = read_csv(v52r_dir / "measured_baseline_registry.csv")
registry_by_id = {row["system_id"]: row for row in registry_rows}

for src, rel in [
    (results / "v52r_measured_registry_de_absorb_summary.csv", "source_v52r/v52r_measured_registry_de_absorb_summary.csv"),
    (results / "v52r_measured_registry_de_absorb_decision.csv", "source_v52r/v52r_measured_registry_de_absorb_decision.csv"),
    (v52r_dir / "measured_baseline_registry.csv", "source_v52r/measured_baseline_registry.csv"),
    (v52r_dir / "measured_artifact_absorb_rows.csv", "source_v52r/measured_artifact_absorb_rows.csv"),
    (v52r_dir / "V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md", "source_v52r/V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md"),
    (results / "v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv", "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv"),
    (results / "v52e_100b_plus_hosted_llm_rag_optional_intake_decision.csv", "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_decision.csv"),
    (v52e_dir / "hosted_llm_rag_validation_rows.csv", "source_v52e/hosted_llm_rag_validation_rows.csv"),
    (v52e_dir / "V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md", "source_v52e/V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md"),
]:
    copy(src, rel)

required_measured_systems = ["A", "B", "C", "D", "E", "G", "H"]
required_measured_ready = all(registry_by_id.get(system_id, {}).get("measured_baseline_ready") == "1" for system_id in required_measured_systems)
same_query_source_ready = (
    v52r_summary.get("same_query_set_local_systems") == "1"
    and v52r_summary.get("same_source_manifest_local_systems") == "1"
)
f_supplied_ready = v52e_summary.get("optional_100b_plus_baseline_ready") == "1"
f_deferred_with_reason = (
    v52e_summary.get("optional_100b_plus_baseline_status") == "deferred-with-reason"
    and v52e_summary.get("blocking_reason", "") != ""
)
f_final_status = "ready" if f_supplied_ready else "deferred-with-reason"
f_final_disposition = "supplied-evidence-row-final" if f_supplied_ready else "deferred-with-reason-final"
f_final_ready = f_supplied_ready or f_deferred_with_reason
v52_ready = (
    v52r_summary.get("v52r_measured_registry_de_absorb_ready") == "1"
    and v52r_summary.get("required_30b_baseline_ready") == "1"
    and v52r_summary.get("required_70b_baseline_ready") == "1"
    and required_measured_ready
    and same_query_source_ready
    and f_final_ready
)

f_rows = [
    {
        "system_id": "F",
        "baseline_name": "100B+ API or hosted model + RAG",
        "required_status": "optional-preferred",
        "source_policy_layer": "v52e",
        "evidence_dir_supplied": v52e_summary.get("evidence_dir_supplied", "0"),
        "supplied_evidence_ready": v52e_summary.get("supplied_evidence_ready", "0"),
        "optional_100b_plus_baseline_ready": v52e_summary.get("optional_100b_plus_baseline_ready", "0"),
        "optional_100b_plus_baseline_status": f_final_status,
        "f_optional_final_disposition": f_final_disposition,
        "f_optional_final_disposition_ready": "1" if f_final_ready else "0",
        "final_reason": "supplied F evidence validated" if f_supplied_ready else v52e_summary.get("blocking_reason", "100b-plus-hosted-api-evidence-dir-missing"),
        "can_replace_required_d_e": "0",
        "counts_as_measured_100b_plus_result": "1" if f_supplied_ready else "0",
    }
]
write_csv(run_dir / "f_optional_final_rows.csv", list(f_rows[0].keys()), f_rows)

condition_rows = [
    ("v52r_registry_absorbed", v52r_summary.get("v52r_measured_registry_de_absorb_ready") == "1", "v52r measured registry exists"),
    ("required_30b_d_ready", v52r_summary.get("required_30b_baseline_ready") == "1", "D 30B PM/release baseline acceptance evidence is present"),
    ("required_70b_e_ready", v52r_summary.get("required_70b_baseline_ready") == "1", "E 70B PM/release baseline acceptance evidence is present"),
    ("required_a_b_c_d_e_g_h_measured", required_measured_ready, "A/B/C/D/E/G/H are measured over the shared query set"),
    ("same_query_set_local_systems", same_query_source_ready, "A/B/C/D/E/G/H share v53e query IDs and source manifest"),
    ("f_optional_final_disposition_ready", f_final_ready, "F is either supplied and ready or explicitly final-deferred with reason"),
    ("f_cannot_replace_required_d_e", True, "F optional status cannot replace required D/E"),
    ("v52_baseline_registry_ready_scope_declared", True, "v52_ready is scoped to measured baseline registry, not full v1.0"),
]
condition_dicts = [
    {
        "condition": name,
        "status": "pass" if passed else "blocked",
        "required_for_v52_ready": "1",
        "reason": reason,
    }
    for name, passed, reason in condition_rows
]
write_csv(run_dir / "v52_ready_condition_rows.csv", list(condition_dicts[0].keys()), condition_dicts)

claim_rows = [
    {
        "claim": "measured 30B and 70B open-weight LLM+RAG baselines are present",
        "status": "allowed" if v52_ready else "blocked",
        "required_disclosure": "requires required_30b_baseline_ready=1 and required_70b_baseline_ready=1; absorbed artifacts alone are insufficient",
    },
    {
        "claim": "30B-150B-class comparison surface",
        "status": "allowed-with-disclosure" if v52_ready else "blocked",
        "required_disclosure": "requires PM/release-grade D/E readiness; optional F is final-deferred unless supplied evidence validates",
    },
    {
        "claim": "measured 100B+/150B hosted baseline result",
        "status": "allowed" if f_supplied_ready else "blocked",
        "required_disclosure": "requires F supplied evidence rows; current default is final deferred-with-reason",
    },
    {
        "claim": "RouteMemory beats 30B-150B-class systems",
        "status": "blocked",
        "required_disclosure": "requires complete-source v53, symmetric scoring, blind review, and release audit",
    },
    {
        "claim": "v1.0 comparison ready",
        "status": "blocked",
        "required_disclosure": "v53 complete-source audit and v58/v60 review gates remain open",
    },
]
write_csv(run_dir / "comparison_wording_rows.csv", list(claim_rows[0].keys()), claim_rows)

summary = {
    "v52y_f_optional_final_policy_ready": "1",
    "f_optional_final_disposition_ready": "1" if f_final_ready else "0",
    "f_optional_final_disposition": f_final_disposition,
    "optional_100b_plus_baseline_status": f_final_status,
    "optional_100b_plus_baseline_ready": "1" if f_supplied_ready else "0",
    "f_final_deferred_with_reason": "0" if f_supplied_ready else "1",
    "required_30b_baseline_ready": v52r_summary.get("required_30b_baseline_ready", "0"),
    "required_70b_baseline_ready": v52r_summary.get("required_70b_baseline_ready", "0"),
    "required_measured_systems": "/".join(required_measured_systems),
    "required_measured_system_rows": str(len(required_measured_systems)),
    "same_query_set_local_systems": v52r_summary.get("same_query_set_local_systems", "0"),
    "same_source_manifest_local_systems": v52r_summary.get("same_source_manifest_local_systems", "0"),
    "v52_ready_condition_rows": str(len(condition_dicts)),
    "v52_ready_condition_pass_rows": str(sum(row["status"] == "pass" for row in condition_dicts)),
    "v52_ready": "1" if v52_ready else "0",
    "v52_ready_scope": "measured-baseline-registry-with-f-final-disposition",
    "comparison_30b_150b_wording_status": "allowed-with-disclosure" if v52_ready else "blocked",
    "complete_source_v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("f-optional-final-disposition", "pass" if f_final_ready else "blocked", f_final_disposition),
    ("required-d-e-measured", "pass" if summary["required_30b_baseline_ready"] == "1" and summary["required_70b_baseline_ready"] == "1" else "blocked", "D/E required baselines"),
    ("v52-ready", "pass" if v52_ready else "blocked", summary["v52_ready_scope"]),
    ("30b-150b-wording", "pass" if v52_ready else "blocked", "allowed only with D/E measured and F final status disclosure"),
    ("f-measured-100b-plus-result", "pass" if f_supplied_ready else "blocked", "F supplied evidence is absent in default no-env path"),
    ("v53-complete-source-audit", "blocked", "v52 readiness does not close v53 complete-source audit"),
    ("v1-comparison-ready", "blocked", "requires v53/v58/v60 review gates"),
    ("real-release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V52Y_F_OPTIONAL_FINAL_POLICY_BOUNDARY.md").write_text(
    "# v52y F Optional Final Policy Boundary\n\n"
    "This artifact resolves F after v52r. F remains optional-preferred: it can be counted as ready only when supplied evidence validates, or it can be explicitly final-deferred with reason, but it cannot replace the required D/E PM/release baseline evidence.\n\n"
    f"- f_optional_final_disposition={f_final_disposition}\n"
    f"- optional_100b_plus_baseline_status={f_final_status}\n"
    f"- required_30b_baseline_ready={summary['required_30b_baseline_ready']}\n"
    f"- required_70b_baseline_ready={summary['required_70b_baseline_ready']}\n"
    f"- v52_ready={summary['v52_ready']}\n"
    "- v52_ready_scope=measured-baseline-registry-with-f-final-disposition\n\n"
    "Allowed wording is limited: 30B-150B-class wording stays blocked until D/E PM/release baseline readiness is present, and F remains optional/final-deferred unless supplied evidence is present. Do not claim a measured 100B+/150B baseline result, v1.0 comparison readiness, or release readiness from v52y alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52y-f-optional-final-policy",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52y_f_optional_final_policy_ready": 1,
    "f_optional_final_disposition": f_final_disposition,
    "optional_100b_plus_baseline_status": f_final_status,
    "required_measured_systems": required_measured_systems,
    "v52_ready": int(v52_ready),
    "v52_ready_scope": summary["v52_ready_scope"],
    "complete_source_v53_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "source_v52r_summary_sha256": sha256(results / "v52r_measured_registry_de_absorb_summary.csv"),
    "source_v52e_summary_sha256": sha256(results / "v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv"),
}
(run_dir / "v52y_f_optional_final_policy_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "f_optional_final_rows.csv",
    "v52_ready_condition_rows.csv",
    "comparison_wording_rows.csv",
    "V52Y_F_OPTIONAL_FINAL_POLICY_BOUNDARY.md",
    "v52y_f_optional_final_policy_manifest.json",
    "source_v52r/v52r_measured_registry_de_absorb_summary.csv",
    "source_v52r/v52r_measured_registry_de_absorb_decision.csv",
    "source_v52r/measured_baseline_registry.csv",
    "source_v52r/measured_artifact_absorb_rows.csv",
    "source_v52r/V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md",
    "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv",
    "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_decision.csv",
    "source_v52e/hosted_llm_rag_validation_rows.csv",
    "source_v52e/V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md",
]
sha_rows = [{"path": rel, "sha256": sha256(run_dir / rel), "bytes": (run_dir / rel).stat().st_size} for rel in artifact_rels]
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v52y_f_optional_final_policy_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
