#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dh_post_full_shard_claim_audit_gate"
RUN_ID="${V61DH_RUN_ID:-audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DH_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dh_post_full_shard_claim_audit_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v52y_f_optional_final_policy_summary.csv" ]]; then
  V52Y_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52y_f_optional_final_policy.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53t_complete_source_audit_readiness_gate_summary.csv" ]]; then
  V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv" ]]; then
  V61DG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dg_post_full_shard_runtime_evidence_promotion_gate.sh" >/dev/null
fi

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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_paths = {
    "v52y_summary": results / "v52y_f_optional_final_policy_summary.csv",
    "v52y_decision": results / "v52y_f_optional_final_policy_decision.csv",
    "v53t_summary": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53t_decision": results / "v53t_complete_source_audit_readiness_gate_decision.csv",
    "v61dg_summary": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv",
    "v61dg_decision": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv",
    "v52y_f_rows": results / "v52y_f_optional_final_policy" / "policy_001" / "f_optional_final_rows.csv",
    "v52y_wording": results / "v52y_f_optional_final_policy" / "policy_001" / "comparison_wording_rows.csv",
    "v53t_claims": results / "v53t_complete_source_audit_readiness_gate" / "gate_001" / "complete_source_audit_claim_rows.csv",
    "v61dg_claims": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate" / "gate_001" / "runtime_evidence_claim_boundary_rows.csv",
    "v61dg_evidence": results / "v61dg_post_full_shard_runtime_evidence_promotion_gate" / "gate_001" / "post_full_shard_runtime_evidence_rows.csv",
}
for key, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dh source: {key} -> {path}")

copy(source_paths["v52y_summary"], "source_v52y/v52y_f_optional_final_policy_summary.csv")
copy(source_paths["v52y_decision"], "source_v52y/v52y_f_optional_final_policy_decision.csv")
copy(source_paths["v52y_f_rows"], "source_v52y/f_optional_final_rows.csv")
copy(source_paths["v52y_wording"], "source_v52y/comparison_wording_rows.csv")
copy(source_paths["v53t_summary"], "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv")
copy(source_paths["v53t_decision"], "source_v53t/v53t_complete_source_audit_readiness_gate_decision.csv")
copy(source_paths["v53t_claims"], "source_v53t/complete_source_audit_claim_rows.csv")
copy(source_paths["v61dg_summary"], "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_summary.csv")
copy(source_paths["v61dg_decision"], "source_v61dg/v61dg_post_full_shard_runtime_evidence_promotion_gate_decision.csv")
copy(source_paths["v61dg_claims"], "source_v61dg/runtime_evidence_claim_boundary_rows.csv")
copy(source_paths["v61dg_evidence"], "source_v61dg/post_full_shard_runtime_evidence_rows.csv")

v52y = read_csv(source_paths["v52y_summary"])[0]
v53t = read_csv(source_paths["v53t_summary"])[0]
v61dg = read_csv(source_paths["v61dg_summary"])[0]

v52_comparison_wording_status = v52y.get("comparison_30b_150b_wording_status", "blocked")
v52_comparison_wording_allowed = (
    v52y.get("v52_ready", "0") == "1"
    and v52_comparison_wording_status == "allowed-with-disclosure"
)

claim_rows = [
    {
        "claim_id": "v52-measured-baseline-registry",
        "claim_text": "local artifact-absorbed A/B/C/D/E/G/H baseline registry with F final disposition",
        "status": "allowed-with-boundary",
        "evidence_source": "v52y",
        "required_disclosure": "D/E artifacts are absorbed locally; required D/E PM/release baseline readiness remains separate",
        "blocking_reason": "",
    },
    {
        "claim_id": "v52-30b-150b-class-comparison-surface",
        "claim_text": "30B-150B-class comparison surface",
        "status": "allowed-with-disclosure" if v52_comparison_wording_allowed else "blocked",
        "evidence_source": "v52y",
        "required_disclosure": "requires required_30b_baseline_ready=1 and required_70b_baseline_ready=1; absorbed artifacts alone are insufficient",
        "blocking_reason": "" if v52_comparison_wording_allowed else "D/E PM/release baseline readiness is not accepted",
    },
    {
        "claim_id": "v53-complete-source-machine-surface",
        "claim_text": "10-repo 1000-query complete-source machine audit surface",
        "status": "allowed-with-disclosure",
        "evidence_source": "v53t",
        "required_disclosure": "machine surface is ready but human review/adjudication is not accepted",
        "blocking_reason": "",
    },
    {
        "claim_id": "v61-full-shard-runtime-evidence",
        "claim_text": "full-shard SSD-resident runtime evidence surface",
        "status": "allowed",
        "evidence_source": "v61dg",
        "required_disclosure": "runtime evidence ready; actual generation is not accepted",
        "blocking_reason": "",
    },
    {
        "claim_id": "v61-rocm-page-kernel-timing",
        "claim_text": "ROCm page-kernel timing",
        "status": "allowed-with-boundary",
        "evidence_source": "v61dg",
        "required_disclosure": "synthetic q4 page geometry timing, not full model generation latency",
        "blocking_reason": "",
    },
    {
        "claim_id": "v61-kv-residency-policy",
        "claim_text": "KV residency/eviction policy",
        "status": "allowed-with-boundary",
        "evidence_source": "v61dg",
        "required_disclosure": "VRAM hot plus NVMe cold policy, host RAM spill disabled",
        "blocking_reason": "",
    },
    {
        "claim_id": "v61-source-bound-qa-command-pass",
        "claim_text": "source-bound QA command pass",
        "status": "allowed-with-boundary",
        "evidence_source": "v61dg",
        "required_disclosure": "37-row source-bound replay, not 1000-query actual generation",
        "blocking_reason": "",
    },
    {
        "claim_id": "measured-100b-plus-hosted-baseline-result",
        "claim_text": "measured 100B+/150B hosted baseline result",
        "status": "blocked",
        "evidence_source": "v52y",
        "required_disclosure": "requires supplied F evidence rows",
        "blocking_reason": "optional F is deferred-with-reason-final",
    },
    {
        "claim_id": "v53-ready",
        "claim_text": "v53 complete-source audit ready",
        "status": "blocked",
        "evidence_source": "v53t",
        "required_disclosure": "requires accepted review return",
        "blocking_reason": "human review 0/7000 and adjudication 0/1000",
    },
    {
        "claim_id": "actual-mixtral-generation",
        "claim_text": "actual Mixtral generation ready",
        "status": "blocked",
        "evidence_source": "v61dg",
        "required_disclosure": "requires review return, admitted execution, generation artifacts, and query acceptance",
        "blocking_reason": "generation execution 0/1000 and generation artifacts 0/5",
    },
    {
        "claim_id": "production-latency",
        "claim_text": "production latency claim",
        "status": "blocked",
        "evidence_source": "v61dg",
        "required_disclosure": "requires accepted generation latency rows and release audit",
        "blocking_reason": "latency evidence is not returned or accepted",
    },
    {
        "claim_id": "near-frontier-quality",
        "claim_text": "near-frontier quality claim",
        "status": "blocked",
        "evidence_source": "v61dg",
        "required_disclosure": "requires external review and accepted generation evidence",
        "blocking_reason": "review/generation evidence is not accepted",
    },
    {
        "claim_id": "v1-comparison-ready",
        "claim_text": "v1.0 comparison ready",
        "status": "blocked",
        "evidence_source": "v52y/v53t/v61dg",
        "required_disclosure": "requires v53 review return plus v58/v60 review/release gates",
        "blocking_reason": "v53_ready=0 and v1_0_comparison_ready=0",
    },
    {
        "claim_id": "real-release-package",
        "claim_text": "real release package ready",
        "status": "blocked",
        "evidence_source": "v52y/v53t/v61dg",
        "required_disclosure": "requires release package and release review evidence",
        "blocking_reason": "real_release_package_ready=0",
    },
    {
        "claim_id": "route-memory-beats-30b-150b",
        "claim_text": "RouteMemory beats 30B-150B-class systems",
        "status": "blocked",
        "evidence_source": "v52y/v53t/v61dg",
        "required_disclosure": "requires symmetric scoring, blind review, accepted generation, and release audit",
        "blocking_reason": "superiority claim has no accepted review/release evidence",
    },
]
write_csv(
    run_dir / "post_full_shard_claim_audit_rows.csv",
    ["claim_id", "claim_text", "status", "evidence_source", "required_disclosure", "blocking_reason"],
    claim_rows,
)

allowed_statuses = {"allowed", "allowed-with-disclosure", "allowed-with-boundary"}
allowed_claim_rows = sum(row["status"] in allowed_statuses for row in claim_rows)
blocked_claim_rows = sum(row["status"] == "blocked" for row in claim_rows)

invariant_rows = [
    {
        "invariant_id": "f-optional-final-disposition",
        "status": "pass" if v52y.get("f_optional_final_disposition_ready") == "1" else "blocked",
        "required_value": "1",
        "actual_value": v52y.get("f_optional_final_disposition_ready", "0"),
        "reason": v52y.get("f_optional_final_disposition", ""),
    },
    {
        "invariant_id": "v53-machine-surface-ready",
        "status": "pass" if v53t.get("machine_complete_source_surface_ready") == "1" else "blocked",
        "required_value": "1",
        "actual_value": v53t.get("machine_complete_source_surface_ready", "0"),
        "reason": "10 repos, 1000 queries, 7000 core answer rows",
    },
    {
        "invariant_id": "v53-human-review-not-accepted",
        "status": "pass" if v53t.get("review_return_ready") == "0" else "blocked",
        "required_value": "0",
        "actual_value": v53t.get("review_return_ready", "0"),
        "reason": "keeps v53_ready and v1 comparison blocked",
    },
    {
        "invariant_id": "v61-runtime-evidence-ready",
        "status": "pass" if v61dg.get("post_full_shard_runtime_evidence_ready") == "1" else "blocked",
        "required_value": "1",
        "actual_value": v61dg.get("post_full_shard_runtime_evidence_ready", "0"),
        "reason": "real manifest, full shard, page hash, ROCm, KV, QA, runtime admission",
    },
    {
        "invariant_id": "actual-generation-not-claimed",
        "status": "pass" if v61dg.get("actual_model_generation_ready") == "0" else "blocked",
        "required_value": "0",
        "actual_value": v61dg.get("actual_model_generation_ready", "0"),
        "reason": "generation stays blocked until review and result returns are accepted",
    },
    {
        "invariant_id": "repo-checkpoint-payload-zero",
        "status": "pass" if v61dg.get("checkpoint_payload_bytes_committed_to_repo") == "0" else "blocked",
        "required_value": "0",
        "actual_value": v61dg.get("checkpoint_payload_bytes_committed_to_repo", "0"),
        "reason": "checkpoint payload remains outside repository",
    },
]
write_csv(run_dir / "post_full_shard_claim_invariant_rows.csv", list(invariant_rows[0].keys()), invariant_rows)

audit_ready = int(all(row["status"] == "pass" for row in invariant_rows))
summary = {
    "v61dh_post_full_shard_claim_audit_gate_ready": "1",
    "claim_audit_ready": str(audit_ready),
    "claim_rows": str(len(claim_rows)),
    "allowed_claim_rows": str(allowed_claim_rows),
    "blocked_claim_rows": str(blocked_claim_rows),
    "claim_invariant_rows": str(len(invariant_rows)),
    "claim_invariant_pass_rows": str(sum(row["status"] == "pass" for row in invariant_rows)),
    "v52_ready": v52y.get("v52_ready", "0"),
    "f_optional_final_disposition": v52y.get("f_optional_final_disposition", ""),
    "comparison_30b_150b_wording_status": v52y.get("comparison_30b_150b_wording_status", ""),
    "v53_machine_complete_source_surface_ready": v53t.get("machine_complete_source_surface_ready", "0"),
    "complete_source_repo_count": v53t.get("complete_source_repo_count", "0"),
    "complete_source_query_rows": v53t.get("complete_source_query_rows", "0"),
    "core_answer_rows": v53t.get("core_answer_rows", "0"),
    "expected_human_review_rows": v53t.get("expected_human_review_rows", "0"),
    "accepted_human_review_rows": v53t.get("accepted_human_review_rows", "0"),
    "expected_adjudication_rows": v53t.get("expected_adjudication_rows", "0"),
    "accepted_adjudication_rows": v53t.get("accepted_adjudication_rows", "0"),
    "v53_ready": v53t.get("v53_ready", "0"),
    "v61_post_full_shard_runtime_evidence_ready": v61dg.get("post_full_shard_runtime_evidence_ready", "0"),
    "ready_evidence_rows": v61dg.get("ready_evidence_rows", "0"),
    "blocked_evidence_rows": v61dg.get("blocked_evidence_rows", "0"),
    "full_checkpoint_materialization_ready": v61dg.get("full_checkpoint_materialization_ready", "0"),
    "full_safetensors_page_hash_binding_ready": v61dg.get("full_safetensors_page_hash_binding_ready", "0"),
    "runtime_admission_accepted_rows": v61dg.get("runtime_admission_accepted_rows", "0"),
    "generation_execution_admitted_rows": v61dg.get("generation_execution_admitted_rows", "0"),
    "actual_model_generation_ready": v61dg.get("actual_model_generation_ready", "0"),
    "v1_0_comparison_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dh": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "claim-audit-ready", "status": "pass" if audit_ready else "blocked", "reason": "claim invariants are explicit"},
    {"gate": "allowed-claim-boundary", "status": "pass", "reason": f"{allowed_claim_rows} allowed/boundary claims"},
    {"gate": "blocked-claim-boundary", "status": "pass", "reason": f"{blocked_claim_rows} blocked claims remain blocked"},
    {"gate": "v52-30b-150b-wording", "status": "pass" if v52_comparison_wording_allowed else "blocked", "reason": v52_comparison_wording_status},
    {"gate": "v53-ready", "status": "blocked", "reason": "accepted human review and adjudication are absent"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "generation execution and result acceptance are absent"},
    {"gate": "v1-comparison-ready", "status": "blocked", "reason": "requires v53/v58/v60 review and release gates"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release package evidence is absent"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

(run_dir / "V61DH_POST_FULL_SHARD_CLAIM_AUDIT_GATE_BOUNDARY.md").write_text(
    "# v61dh Post-Full-Shard Claim Audit Gate\n\n"
    "This gate turns the v52/v53/v61 evidence boundary into an auditable claim posture. "
    "It does not add review rows, generation rows, latency evidence, or release evidence.\n\n"
    f"- claim_rows={summary['claim_rows']}\n"
    f"- allowed_claim_rows={summary['allowed_claim_rows']}\n"
    f"- blocked_claim_rows={summary['blocked_claim_rows']}\n"
    f"- claim_audit_ready={summary['claim_audit_ready']}\n"
    f"- f_optional_final_disposition={summary['f_optional_final_disposition']}\n"
    f"- comparison_30b_150b_wording_status={summary['comparison_30b_150b_wording_status']}\n"
    f"- v53_machine_complete_source_surface_ready={summary['v53_machine_complete_source_surface_ready']}\n"
    f"- accepted_human_review_rows={summary['accepted_human_review_rows']}/{summary['expected_human_review_rows']}\n"
    f"- accepted_adjudication_rows={summary['accepted_adjudication_rows']}/{summary['expected_adjudication_rows']}\n"
    f"- v61_post_full_shard_runtime_evidence_ready={summary['v61_post_full_shard_runtime_evidence_ready']}\n"
    f"- runtime_admission_accepted_rows={summary['runtime_admission_accepted_rows']}\n"
    f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}\n"
    f"- actual_model_generation_ready={summary['actual_model_generation_ready']}\n"
    f"- v1_0_comparison_ready={summary['v1_0_comparison_ready']}\n"
    f"- real_release_package_ready={summary['real_release_package_ready']}\n\n"
    "Allowed wording: local artifact-absorbed baseline registry with D/E readiness disclosure, complete-source machine surface, full-shard runtime evidence, ROCm page-kernel timing, KV policy, source-bound QA command pass. "
    "Blocked wording: 30B-150B comparison surface, measured 100B+/150B hosted result, v53 ready, actual Mixtral generation, production latency, near-frontier quality, v1.0 comparison ready, release readiness, and superiority claims.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61dh-post-full-shard-claim-audit-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dh_post_full_shard_claim_audit_gate_ready": 1,
    "claim_audit_ready": audit_ready,
    "allowed_claim_rows": allowed_claim_rows,
    "blocked_claim_rows": blocked_claim_rows,
    "v52_ready": as_int(v52y, "v52_ready"),
    "v53_ready": as_int(v53t, "v53_ready"),
    "v61_post_full_shard_runtime_evidence_ready": as_int(v61dg, "post_full_shard_runtime_evidence_ready"),
    "actual_model_generation_ready": as_int(v61dg, "actual_model_generation_ready"),
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dh_post_full_shard_claim_audit_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "post_full_shard_claim_audit_rows.csv",
    "post_full_shard_claim_invariant_rows.csv",
    "V61DH_POST_FULL_SHARD_CLAIM_AUDIT_GATE_BOUNDARY.md",
    "v61dh_post_full_shard_claim_audit_gate_manifest.json",
]
for rel in sorted(p.relative_to(run_dir).as_posix() for p in run_dir.rglob("*") if p.is_file()):
    if rel not in artifact_rels:
        artifact_rels.append(rel)
sha_rows = []
for rel in artifact_rels:
    if rel == "sha256_manifest.csv":
        continue
    path = run_dir / rel
    if path.is_file():
        sha_rows.append({"path": rel, "sha256": sha256(path), "size_bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "size_bytes"], sha_rows)

print(f"v61dh_post_full_shard_claim_audit_gate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
